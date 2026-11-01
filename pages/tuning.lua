-- One weapon's stats: for each weapon the player holds, nobody else's. They stay through a respawn, and
-- on whichever weapon takes that slot.
local U = obsidian.module("pages/ui")
local api, t = U.api, U.t
local gear = api.gear

local M = {}

local SLOTS = {
	{ id = "primary_weapon", key = "tune_primary" },
	{ id = "sidearm_weapon", key = "tune_sidearm" },
	{ id = "support_weapon", key = "tune_support" },
}

local NUMBERS = {
	{ id = "firerate", key = "tune_firerate", min = 0.25, max = 5 },
	{ id = "power", key = "tune_power", min = 0.25, max = 10 },
	{ id = "capacity", key = "tune_capacity", min = 0.5, max = 5 },
	{ id = "reload", key = "tune_reload", min = 0.25, max = 5 },
	{ id = "spread", key = "tune_spread", min = 0, max = 2 },
}

M.state = {}
for _, slot in ipairs(SLOTS) do M.state[slot.id] = { firerate = 1, power = 1, capacity = 1, reload = 1, spread = 1, pierce = false } end

-- Which of the game's fields each number moves. A weapon has only the ones of its kind.
local function changes_of(s)
	local c = {}
	local function set(by, keys)
		if by ~= 1 then
			for _, key in ipairs(keys) do c[key] = by end
		end
	end
	set(s.firerate, { "firerate", "rounds_per_second" })
	if s.firerate ~= 1 then set(1 / s.firerate, { "heat_increase", "heat_per_second" }) end
	set(s.power, { "power", "power_crit", "min_power", "max_power" })
	set(s.capacity, { "magazine_capacity", "heat_capacity" })
	if s.reload ~= 1 then set(1 / s.reload, { "reload_duration", "reload_duration_fast" }) end
	set(s.reload, { "heat_dissipation_per_second" })
	set(s.spread, { "spread", "spread_min", "spread_max" })
	if s.pierce then c.armorpiercing = true end
	return c
end

local function signature(changes)
	local keys = {}
	for key in pairs(changes) do keys[#keys + 1] = key end
	table.sort(keys)
	for i, key in ipairs(keys) do keys[i] = key .. "=" .. tostring(changes[key]) end
	return table.concat(keys, ";")
end

local applied = {}

-- Every frame: a new weapon in a slot takes that slot's numbers.
function M.sync()
	if not (gear.tune and api.game.in_mission()) then return end
	for _, w in ipairs(gear.weapons_of()) do
		local changes = changes_of(M.state[w.slot])
		local sign = signature(changes)
		if (applied[w.unit] or "") ~= sign then
			applied[w.unit] = sign
			gear.tune(w.unit, w.component, changes)
		end
	end
end

-- The slots with something changed, for the Changes page.
function M.active()
	local out = {}
	for _, slot in ipairs(SLOTS) do
		if signature(changes_of(M.state[slot.id])) ~= "" then out[#out + 1] = t(slot.key) end
	end
	return out
end

local function reset(s)
	for _, n in ipairs(NUMBERS) do s[n.id] = 1 end
	s.pierce = false
end

function M.clear()
	for _, s in pairs(M.state) do reset(s) end
	M.sync()
end

local function slot_page(slot)
	return function(page)
		local s = M.state[slot.id]
		for _, n in ipairs(NUMBERS) do
			page:number(t(n.key), {
				min = n.min, max = n.max, step = 0.25, default = 1, format = "x%.2f", help = U.help(n.key),
				get = function() return s[n.id] end,
				set = function(v) s[n.id] = v end,
			})
		end
		page:toggle(t("tune_pierce"), { default = false, help = U.help("tune_pierce"), get = function() return s.pierce end, set = function(v) s.pierce = v end })
		page:action(t("tune_reset"), function()
			reset(s)
			page:refresh()
			return t("done")
		end)
	end
end

function M.rows(page)
	if not gear.tune then return end
	page:header(t("tune_header"))
	for _, slot in ipairs(SLOTS) do page:page(t(slot.key), slot_page(slot), { help = U.help("tune_page") }) end
end

return M
