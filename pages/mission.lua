-- Mission: objectives, extraction, waits, samples, modifiers, and a custom mission from the ship.
local U = obsidian.module("pages/ui")
local api, t = U.api, U.t
local mission = api.mission

-- look 0 and layout 0 are random. Obsidian API before 1.18.0 takes neither.
local PRACTICE = { time = 2, environment = 1, enemy = 1, kind = 1, difficulty = 5, look = 0, layout = 0 }
local practice = {}
for field, value in pairs(PRACTICE) do practice[field] = value end

-- What practice() gets: random parts left out.
local function practice_choice()
	local c = {}
	for field, value in pairs(practice) do c[field] = value end
	if c.look == 0 then c.look = nil end
	if c.layout == 0 then c.layout = nil end
	return c
end

-- A real mission that leaves the campaign alone. Obsidian API before 1.30.0 has only the training one.
local function start_practice()
	local ok, why = (mission.drop or mission.practice)(practice_choice())
	if ok then return t("done") end
	return U.why(why)
end

local function choices(list)
	local out = {}
	for i, id in ipairs(list) do out[i] = { id = i, label = t("seed_" .. id) } end
	return out
end

local function pick(page, key, field, list)
	page:choice(t(key), { choices = choices(list), default = PRACTICE[field], help = U.help(key), get = function() return practice[field] end, set = function(v) practice[field] = v end })
end

local function practice_page(page)
	pick(page, "seed_time", "time", mission.TIMES)
	pick(page, "seed_environment", "environment", mission.ENVIRONMENTS)
	if mission.LOOKS then
		local looks = { { id = 0, label = t("seed_random") } }
		for i, id in ipairs(mission.LOOKS) do looks[#looks + 1] = { id = i, label = t("seed_" .. id) } end
		page:choice(t("seed_look"), { choices = looks, default = 0, help = U.help("seed_look"), get = function() return practice.look end, set = function(v) practice.look = v end })
	end
	pick(page, "seed_enemy", "enemy", mission.FACTIONS)
	pick(page, "seed_kind", "kind", mission.TYPES)
	page:number(t("seed_difficulty"), { min = 1, max = 15, step = 1, default = PRACTICE.difficulty, help = U.help("seed_difficulty"), get = function() return practice.difficulty end, set = function(v) practice.difficulty = v end })
	if mission.LAYOUTS then
		page:number(t("seed_layout"), { min = 0, max = mission.LAYOUTS, step = 1, default = 0, help = U.help("seed_layout"), get = function() return practice.layout end, set = function(v) practice.layout = v end })
	end
	page:action(t("practice_start"), start_practice, { help = U.help("practice_start") })
end

local function objective_page(page)
	local list = mission.objectives()
	if #list == 0 then page:label(t("no_mission")) end
	for _, o in ipairs(list) do
		local name = o.text
		if o.total and o.total > 1 then name = string.format("%s (%s/%s)", name, tostring(o.done), tostring(o.total)) end
		page:label(t("objective_row", name, t("objective_" .. tostring(o.state))))
	end
end

local function players_page(page)
	for _, p in ipairs(api.lobby.players()) do
		local name = p.name or t("player_joining")
		if p.host then name = t("player_host", name) end
		page:label(p.ping and t("player_ping", name, tostring(p.ping)) or name)
	end
end

local function modifier_choices()
	local out = { { id = false, label = t("mutator_off") } }
	for _, name in ipairs(mission.MUTATORS) do
		out[#out + 1] = { id = name, label = api.catalog.text("provinggrounds_" .. name) }
	end
	return out
end

-- What the modifier on now does, or what modifiers are with none on.
local function modifier_help()
	local on = api.effects.get("mutator")
	return on and U.help("mutator_" .. tostring(on)) or t("mutator_help")
end

return function(page)
	page:label(function()
		local params, seed = mission.params()
		if not params then return t("no_mission") end
		return t("mission_info", tostring(seed), tostring(params.difficulty or "?"), tostring(params.enemy or "?"))
	end)

	page:header(t("objectives"))
	page:page(t("objective_list"), objective_page, { help = U.help("objective_list") })
	U.action(page, "finish_objectives", mission.finish_objectives)
	U.action(page, "restart_objectives", mission.restart_objectives)
	U.effect(page, "protect_objectives", "protect_objectives")
	U.effect(page, "fast_extract", "fast_extract")
	U.action(page, "win", mission.win)
	U.action(page, "abort", mission.abort)

	page:header(t("waits"))
	U.effect(page, "skip_waits", "skip_waits")
	U.effect(page, "fast_mission_start", "fast_mission_start")

	page:header(t("reinforcements"))
	U.effect(page, "infinite_respawns", "infinite_respawns")
	-- From Obsidian API 1.18.0.
	if (api.effects.defs or {}).auto_respawn then U.effect(page, "auto_respawn", "auto_respawn") end
	U.effect(page, "no_game_over", "no_game_over")

	page:header(t("modifiers"))
	page:choice(t("mutator"), {
		choices = modifier_choices(), help = modifier_help, default = false,
		get = function() return api.effects.get("mutator") end,
		set = function(v) api.effects.set("mutator", v) end,
	})

	page:header(t("players_header"))
	page:page(t("players_here"), players_page, { help = U.help("players_here") })

	page:header(t("samples"))
	if not U.progression_open() then page:label(t("progression_locked")) end
	U.progression_action(page, "spawn_samples", mission.spawn_samples)
	U.progression_action(page, "collect_samples", mission.collect_samples)
	U.action(page, "reveal_map", mission.reveal_map)

	page:header(t("practice"))
	page:page(t("practice_setup"), practice_page, { help = U.help("practice_setup") })
end
