-- Custom stratagems: made here from one of the game's, kept for the next launch, and remade at boot
-- before the save's loadout is read, so one left in a loadout stays there.
local U = obsidian.module("pages/ui")
local api, t = U.api, U.t
local stratagems, catalog, world = api.stratagems, api.catalog, api.world

local M = {}

local PREFIX = "custom."
local ARROWS = { u = "up", d = "down", l = "left", r = "right", up = "up", down = "down", left = "left", right = "right" }
local BEHAVIOURS = { "none", "explosion", "stun", "heal", "also" }

local draft = { behaviour = "none" }

-- "down left up", "d l u" or "dlu".
local function parse_code(text)
	local code = {}
	for word in string.gmatch(string.lower(text or ""), "%a+") do
		if ARROWS[word] then
			code[#code + 1] = ARROWS[word]
		else
			for letter in string.gmatch(word, ".") do
				if not ARROWS[letter] then return nil end
				code[#code + 1] = ARROWS[letter]
			end
		end
	end
	if #code == 0 or #code > 10 then return nil end
	return code
end

local SHORT = { up = "U", down = "D", left = "L", right = "R" }

local function code_text(code)
	local out = {}
	for i, arrow in ipairs(code or {}) do out[i] = SHORT[arrow] end
	return table.concat(out, " ")
end

-- What it does when it's called down, as a function for api.stratagems.define.
local function behaviour(d)
	local kind, also, nothing = d.behaviour, d.also, d.drop_nothing
	if kind == "none" and not nothing then return nil end
	return function(ctx)
		local pos = ctx.position
		if kind == "explosion" then
			world.explode(pos, 2000, 8)
		elseif kind == "stun" then
			for _, enemy in ipairs(api.enemies.near(12, pos)) do api.enemies.apply_status(enemy, "flashbang_stun") end
		elseif kind == "heal" then
			api.player.heal_everyone()
		elseif kind == "also" and also then
			stratagems.call(also, { x = pos.x, y = pos.y, z = pos.z }, 0)
		end
		if nothing then return false end
	end
end

local function definition(d)
	local stats = {}
	if d.cooldown then stats.cooldown_time = d.cooldown end
	if d.uses and d.uses > 0 then stats.num_uses = d.uses end
	if d.call_in then stats.activation_time = d.call_in end
	return { name = d.name, base = d.base, title = d.title, code = d.code, icon = d.icon, stats = stats, on_activate = behaviour(d) }
end

-- One stored line per stratagem. Words lose any "|".
local function encode(d)
	local function plain(v) return (string.gsub(tostring(v == nil and "" or v), "|", "/")) end
	return table.concat({ plain(d.name), plain(d.base), plain(d.title), code_text(d.code), plain(d.icon), plain(d.cooldown), plain(d.uses),
		plain(d.call_in), plain(d.behaviour), plain(d.also), d.drop_nothing and "1" or "" }, "|")
end

local function decode(text)
	local f = {}
	for field in string.gmatch(text .. "|", "([^|]*)|") do f[#f + 1] = field end
	if #f < 11 or f[1] == "" or f[2] == "" then return nil end
	local function opt(s) return s ~= "" and s or nil end
	return { name = f[1], base = f[2], title = f[3], code = parse_code(f[4]), icon = opt(f[5]), cooldown = tonumber(f[6]), uses = tonumber(f[7]),
		call_in = tonumber(f[8]), behaviour = opt(f[9]) or "none", also = opt(f[10]), drop_nothing = f[11] == "1" }
end

local made = {}

local function stored()
	local list = {}
	for key, text in pairs(obsidian.storage.all()) do
		if string.sub(key, 1, #PREFIX) == PREFIX then
			local d = decode(text)
			if d then list[#list + 1] = d end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

-- At boot, from main.lua. true once the game's list exists and every kept one has been made.
function M.load()
	for _, d in ipairs(stored()) do
		if not made[d.name] then
			local ok, why = stratagems.define(definition(d))
			if not ok and why == "not_ready" then return false end
			if ok then
				made[d.name] = d
			else
				obsidian.log("custom stratagem " .. d.name .. " not made: " .. tostring(why))
			end
		end
	end
	return true
end

local function next_name()
	local n = 1
	for _, d in ipairs(stored()) do
		local i = tonumber(string.match(d.name, "^trainer_custom_(%d+)$"))
		if i and i >= n then n = i + 1 end
	end
	return "trainer_custom_" .. n
end

local function base_name()
	return draft.base and catalog.text(draft.base) or t("custom_no_base")
end

local function pick_base(page)
	for _, s in ipairs(catalog.stratagems()) do
		if not made[s.name] then
			page:action(catalog.text(s.name), function()
				draft.base, draft.icon = s.name, nil
				draft.cooldown, draft.uses, draft.call_in = s.cooldown_time, s.num_uses, s.activation_time
				draft.code = draft.code or s.combo
				return t("custom_base_set", catalog.text(s.name))
			end)
		end
	end
end

local function pick_icon(page)
	for _, s in ipairs(catalog.stratagems()) do
		page:action(catalog.text(s.name), function()
			draft.icon = s.icon
			return t("custom_icon_set", catalog.text(s.name))
		end)
	end
end

local function pick_also(page)
	for _, s in ipairs(catalog.stratagems()) do
		page:action(catalog.text(s.name), function()
			draft.behaviour, draft.also = "also", s.name
			return t("custom_also_set", catalog.text(s.name))
		end)
	end
end

local function workshop(page)
	page:label(function() return t("custom_base_now", base_name()) end)
	page:page(t("custom_base"), pick_base, { help = U.help("custom_base") })
	page:input(t("custom_title"), function(text)
		if text == "" or #text > 40 then return U.why("bad_type") end
		draft.title = text
		return t("custom_title_set", text)
	end)
	page:input(t("custom_code"), function(text)
		local code = parse_code(text)
		if not code then return t("custom_code_bad") end
		draft.code = code
		return t("custom_code_set", code_text(code))
	end, { help = U.help("custom_code") })
	page:label(function() return t("custom_code_now", draft.code and code_text(draft.code) or "-") end)
	page:page(t("custom_icon"), pick_icon, { help = U.help("custom_icon") })
	page:number(t("custom_cooldown"), { min = 0, max = 600, step = 5, default = 0, get = function() return draft.cooldown or 0 end, set = function(v) draft.cooldown = v end })
	page:number(t("custom_uses"), { min = 0, max = 20, step = 1, default = 0, help = U.help("custom_uses"), get = function() return draft.uses or 0 end, set = function(v) draft.uses = v end })
	page:number(t("custom_call_in"), { min = 0.5, max = 30, step = 0.5, default = 3, format = "%.1f s", get = function() return draft.call_in or 3 end, set = function(v) draft.call_in = v end })
	local choices = {}
	for i, kind in ipairs(BEHAVIOURS) do choices[i] = { id = kind, label = t("custom_does_" .. kind) } end
	page:choice(t("custom_does"), { choices = choices, default = "none", get = function() return draft.behaviour end, set = function(v) draft.behaviour = v end })
	page:page(t("custom_also"), pick_also, { help = U.help("custom_also") })
	page:toggle(t("custom_drop_nothing"), { default = false, help = U.help("custom_drop_nothing"), get = function() return draft.drop_nothing == true end, set = function(on) draft.drop_nothing = on end })
	page:action(t("custom_make"), function()
		if not draft.base then return t("custom_no_base") end
		if not draft.title then return t("custom_no_title") end
		if draft.behaviour == "also" and not draft.also then return t("custom_no_also") end
		local d = {}
		for k, v in pairs(draft) do d[k] = v end
		d.name = next_name()
		local ok, why = stratagems.define(definition(d))
		if not ok then return U.why(why) end
		made[d.name] = d
		obsidian.storage.set(PREFIX .. d.name, encode(d))
		draft = { behaviour = "none" }
		page:refresh()
		return t("custom_made", d.title)
	end, { help = U.help("custom_make") })
end

local function one(d)
	return function(page)
		page:label(t("custom_from", catalog.text(d.base)))
		page:label(t("custom_code_now", code_text(d.code or (catalog.stratagem(d.name) or {}).combo)))
		page:action(t("give_stratagem"), U.act(stratagems.give, d.name))
		page:action(t("custom_call"), function() return U.result(stratagems.call(d.name, world.cursor(), 0)) end, { enabled = U.in_mission })
		page:action(t("custom_forget"), function()
			obsidian.storage.set(PREFIX .. d.name, nil)
			return t("custom_forgotten")
		end, { help = U.help("custom_forget") })
	end
end

function M.rows(page)
	page:header(t("custom"))
	page:page(t("custom_workshop"), workshop, { help = U.help("custom_workshop") })
	for _, d in ipairs(stored()) do
		if made[d.name] then page:page(d.title, one(d)) end
	end
end

return M
