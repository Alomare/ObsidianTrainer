-- Enemies: stopping them, getting rid of them, bringing more.
local U = obsidian.module("pages/ui")
local api, t = U.api, U.t
local enemies, catalog = api.enemies, api.catalog

local amount, where = 1, "ahead"

local FACTIONS = { { id = "bugs", key = "faction_bugs" }, { id = "cyborgs", key = "faction_cyborgs" }, { id = "illuminates", key = "faction_illuminates" } }

-- A map packed far past what the game ever puts on it can take the mission down, so spawning stops
-- short of that.
local function if_room(run)
	return function()
		if enemies.room() < 1 then return U.why("map_full") end
		return run()
	end
end

local function spawn_list(faction)
	return function(page)
		page:choice(t("spawn_where"), {
			choices = { { id = "ahead", label = t("where_ahead") }, { id = "cursor", label = t("where_cursor") } },
			default = "ahead", help = U.help("spawn_where"),
			get = function() return where end,
			set = function(v) where = v end,
		})
		page:number(t("spawn_amount"), { min = 1, max = 30, step = 1, default = 1, help = U.help("spawn_amount"), get = function() return amount end, set = function(v) amount = v end })
		for _, enemy in ipairs(catalog.enemies(faction)) do
			if not enemy.boss and enemies.available(enemy) then
				page:action(enemy.name, if_room(function()
					local room = enemies.room()
					local ok, why = enemies.spawn(enemy.key, math.min(amount, room), where ~= "ahead" and where or nil)
					if not ok then return U.why(why) end
					if amount > room then return t("spawned_some", room) end
					return t("done")
				end))
			end
		end
	end
end

-- A toast for each enemy that starts aiming before a shot (the Hunter's beam, the Cyborg IFV's laser
-- sight), with how long until it fires: what bots that get out of shots react to.
local watching = false
local told = setmetatable({}, { __mode = "k" })
local look = 0

local function toast(text)
	local m = api.menu or obsidian
	return m.toast(text)
end

obsidian.on_frame(function()
	if not (watching and enemies.charging) then return end
	look = look - (rawget(_G, "ENGINE_DT") or 0.016)
	if look > 0 then return end
	look = 0.1
	for _, e in ipairs(enemies.near(60)) do
		local c = enemies.charging(e)
		if c and not told[e] then
			local info = enemies.info(e) or {}
			toast(t("enemy_charging", info.name or "?", string.format("%.1f", c.time)))
		end
		told[e] = c and true or nil
	end
end)

-- What the player's weapons do to the enemy nearest the cursor, after armor.
local function armor_at_cursor()
	local pos = api.world.cursor()
	if not pos then return U.why("no_position") end
	local e, d = enemies.nearest(pos)
	if not e or (d or 0) > 8 then return U.why("no_enemy_here") end
	local info = enemies.info(e) or {}
	local lines = { t("enemy_armor", info.name or "?", info.armor_min or 0, info.armor_max or 0) }
	for _, w in ipairs(api.gear.weapons_of()) do
		local s, g, weak = api.gear.hurts(w.unit, e)
		if s then lines[#lines + 1] = t("hurts_line", t("slot_" .. w.slot:gsub("_weapon$", "")), math.floor(s), math.floor(g), math.floor(weak)) end
	end
	return table.concat(lines, "\n")
end

local function group_list(page)
	for _, key in ipairs(catalog.enemy_groups()) do
		page:action(catalog.text(key), if_room(U.act(enemies.spawn_group, key)), { enabled = U.host_only })
	end
end

local function wave_list(page)
	local names = enemies.waves()
	if #names == 0 then page:label(t("no_waves")) end
	for _, name in ipairs(names) do
		page:action(catalog.text(name), if_room(U.act(enemies.force_wave, name)), { enabled = U.host_only })
	end
end

return function(page)
	page:label(function() return t("enemy_count", enemies.count()) end)
	page:header(t("control"))
	page:toggle(t("no_spawns"), {
		help = U.help("no_spawns"), enabled = U.host_only, default = false,
		get = function() return api.effects.is_on("no_spawns") end,
		set = function(v) api.effects.set("no_spawns", v) end,
	})
	U.effect(page, "freeze", "freeze")
	U.effect(page, "blind", "blind")
	U.effect(page, "host_owns_enemies", "host_owns_enemies")
	U.action(page, "stun_near", enemies.stun_near, 20)
	U.effect_number(page, "damage_to_enemies", "damage_to_enemies", { off = 1, min = 0, max = 10, step = 0.25, format = "x%.2f" })
	if enemies.charging then
		page:toggle(t("watch_charging"), {
			default = false, help = U.help("watch_charging"),
			get = function() return watching end,
			set = function(on) watching = on end,
		})
	end
	if api.gear.hurts then page:action(t("enemy_armor_cursor"), armor_at_cursor, { help = U.help("enemy_armor_cursor") }) end

	page:header(t("pressure"))
	U.effect_number(page, "max_enemies", "enemy_cap", { off = 16, min = 1, max = enemies.MAX_CAP, step = 1, enabled = U.host_only })
	U.effect_number(page, "enemy_difficulty", "enemy_difficulty", { off = 0, min = 0, max = 15, step = 1, enabled = U.host_only })
	U.effect_number(page, "patrol_count", "patrol_count", { off = 0, min = 0, max = 60, step = 2, enabled = U.host_only })
	U.effect_number(page, "patrol_interval", "patrol_interval", { off = 0, min = 0, max = 120, step = 1, enabled = U.host_only })

	page:header(t("remove"))
	U.action(page, "kill_all", enemies.kill_all)
	U.action(page, "kill_near", enemies.kill_near, 20)
	U.action(page, "despawn_all", enemies.despawn_all)

	page:header(t("bring"))
	for _, f in ipairs(FACTIONS) do
		page:page(t("spawn_faction", t(f.key)), spawn_list(f.id), { help = U.help("spawn_faction") })
	end
	page:page(t("spawn_group"), group_list, { help = U.help("spawn_group") })
	page:page(t("spawn_wave"), wave_list, { help = U.help("spawn_wave") })
	U.action(page, "call_encounter", enemies.call_encounter)
	U.action(page, "add_patrol", enemies.add_patrol)
end
