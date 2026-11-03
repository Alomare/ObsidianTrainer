-- Obsidian Trainer: an in-game menu built only on the public Obsidian API.
local t = obsidian.text
local api = obsidian.import("obsidian.api")
local player = obsidian.module("pages/player")
local weapons = obsidian.module("pages/weapons")
local stratagems = obsidian.module("pages/stratagems")
local vehicles = obsidian.module("pages/vehicles")
local bots = obsidian.module("pages/bots")
local custom = obsidian.module("pages/custom")
local spawn = obsidian.module("pages/spawn")
local enemies = obsidian.module("pages/enemies")
local mission = obsidian.module("pages/mission")
local world = obsidian.module("pages/world")
local editor = obsidian.module("pages/editor")
local console = obsidian.module("pages/console")
local changes = obsidian.module("pages/changes")
local tuning = obsidian.module("pages/tuning")

-- The window is Obsidian API's from 1.15.0, opened with the API's key. An older API has none, and the pages go
-- to the loader's own window.
local menu = api.menu or obsidian.menu

-- A short message beside the window.
local function toast(text, seconds)
	if api.menu then return api.menu.toast(text, seconds) end
	return obsidian.toast(text, seconds)
end

-- The title is a function: at boot the game's language isn't known yet.
local function page(key, build, icon)
	menu.add(function() return t(key) end, build, { icon = icon })
end

-- An icon the loader has, or another: one it lacks draws nothing.
local function icon(name, fallback)
	local ok, list = pcall(obsidian.ui.glyphs)
	for _, have in ipairs(ok and list or {}) do
		if have == name then return name end
	end
	return fallback
end

obsidian.after_startup(function()
	page("page_player", player, "player")
	page("page_weapons", weapons, "weapons")
	page("page_stratagems", stratagems, "stratagems")
	page("page_vehicles", vehicles, "vehicles")
	-- Bot orders and gear came with Obsidian API 1.10, with api.music.
	if api.music then page("page_bots", bots, icon("bots", "player")) end
	page("page_spawn", spawn, "spawn")
	page("page_enemies", enemies, "enemies")
	page("page_mission", mission, "mission")
	page("page_world", world, "world")
	page("page_editor", editor.build, "editor")
	page("page_console", console, "console")
	page("page_changes", changes.build, "changes")
end)

-- The custom stratagems made here, made again before the save's loadout is read.
if api.stratagems.define and not custom.load() then obsidian.on_frame(custom.load) end

-- A session that stops being cleared switches everything off, and the player should hear why.
obsidian.on_session(function(on)
	if on then
		toast(t("session_on"))
	else
		tuning.clear()
		toast(t("session_off"), 8)
	end
end)

obsidian.on_frame(function() tuning.sync() end)

if obsidian.settings.get("keep_edits") then
	obsidian.on_frame(function() return changes.load_saved() end)
end

-- For tests.
return { tuning = tuning }
