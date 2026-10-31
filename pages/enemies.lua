-- Enemies: stopping them, getting rid of them, bringing more.
local U = obsidian.module("pages/ui")
local api, t = U.api, U.t
local enemies, catalog = api.enemies, api.catalog

local amount, where = 1, "ahead"

local FACTIONS = { { id = "bugs", key = "faction_bugs" }, { id = "cyborgs", key = "faction_cyborgs" }, { id = "illuminates", key = "faction_illuminates" } }

local function spawn_list(faction)
	return function(page)
		page:choice(t("spawn_where"), {
			choices = { { id = "ahead", label = t("where_ahead") }, { id = "cursor", label = t("where_cursor") } },
			get = function() return where end,
			set = function(v) where = v end,
		})
		page:number(t("spawn_amount"), { min = 1, max = 30, step = 1, get = function() return amount end, set = function(v) amount = v end })
		for _, enemy in ipairs(catalog.enemies(faction)) do
			if not enemy.boss and enemies.available(enemy) then
				page:action(enemy.name, function()
					local ok, why = enemies.spawn(enemy.key, amount, where ~= "ahead" and where or nil)
					if ok then return t("done") end
					return U.why(why)
				end)
			end
		end
	end
end

local function group_list(page)
	for _, key in ipairs(catalog.enemy_groups()) do
		page:action(key, U.act(enemies.spawn_group, key), { enabled = U.host_only })
	end
end

return function(page)
	page:label(function() return t("enemy_count", enemies.count()) end)
	page:header(t("control"))
	page:toggle(t("no_spawns"), {
		help = U.help("no_spawns"), enabled = U.host_only,
		get = function() return api.effects.is_on("no_spawns") end,
		set = function(v) api.effects.set("no_spawns", v) end,
	})
	U.effect(page, "freeze", "freeze")
	U.effect(page, "blind", "blind")
	U.effect(page, "host_owns_enemies", "host_owns_enemies")
	U.effect_number(page, "max_enemies", "enemy_cap", { off = 16, min = 1, max = enemies.MAX_CAP, step = 1, enabled = U.host_only })

	page:header(t("remove"))
	U.action(page, "kill_all", enemies.kill_all)
	U.action(page, "kill_near", enemies.kill_near, 20)
	U.action(page, "despawn_all", enemies.despawn_all)

	page:header(t("bring"))
	for _, f in ipairs(FACTIONS) do
		page:page(t("spawn_faction", t(f.key)), spawn_list(f.id))
	end
	page:page(t("spawn_group"), group_list)
	U.action(page, "call_encounter", enemies.call_encounter)
	U.action(page, "add_patrol", enemies.add_patrol)
end
