-- World: time, camera, HUD and the look of the mission.
local U = obsidian.module("pages/ui")
local api, t = U.api, U.t
local world = api.world

local BLAST_POWER, BLAST_RADIUS = 500, 8
local blast = { power = BLAST_POWER, radius = BLAST_RADIUS }

local FOG = {
	{ id = false, key = "tint_planet" },
	{ id = { 0.5, 0.45, 0.3 }, key = "tint_dust" },
	{ id = { 0.25, 0.25, 0.28 }, key = "tint_ash" },
	{ id = { 0.6, 0.1, 0.1 }, key = "tint_blood" },
	{ id = { 0.2, 0.5, 0.2 }, key = "tint_toxic" },
}
local SUN = {
	{ id = false, key = "tint_planet" },
	{ id = { 8, 5, 3 }, key = "tint_warm" },
	{ id = { 2, 3, 8 }, key = "tint_cold" },
	{ id = { 8, 1, 1 }, key = "tint_blood" },
}

local function tint(page, key, name, list)
	local choices = {}
	for i, c in ipairs(list) do choices[i] = { id = c.id, label = t(c.key) } end
	page:choice(t(key), {
		choices = choices, help = U.help(key), default = false,
		get = function() return api.effects.get("shading_" .. name) end,
		set = function(v) world.shading(name, "vector3", v or nil) end,
	})
end

local function spectate(page)
	page:action(t("spectate_self"), U.act(world.camera.spectate, nil), { help = U.help("spectate_self") })
	for _, p in ipairs(api.game.all_avatars()) do
		if not p.owned then
			page:action(tostring(p.record.player_go:get("name")), U.act(world.camera.spectate, p.unit))
		end
	end
end

local function volume(page, key, bus)
	page:number(t(key), {
		min = -60, max = 12, step = 3, format = "%+d dB", default = 0, help = U.help(key),
		get = function() return api.effects.get("bus_" .. bus) or 0 end,
		set = function(v) api.audio.bus(bus, v ~= 0 and v or false) end,
	})
end

local function track_name(track)
	local key = "track_" .. track
	local text = t(key)
	if text ~= key then return text end
	return track
end

-- The soundtrack: the tracks this screen has, held until given back to the game.
local function soundtrack(page)
	local music = api.music
	page:label(function()
		local now = music.now()
		local what = now.track and track_name(now.track) or t(now.held and "music_silence" or "music_game")
		return t(now.paused and "music_now_paused" or "music_now", what)
	end)
	page:toggle(t("music_pause"), {
		default = false, help = U.help("music_pause"),
		get = function() return music.now().paused end,
		set = function(on) if on then music.pause() else music.resume() end end,
	})
	page:action(t("music_stop"), U.act(music.stop), { help = U.help("music_stop") })
	page:action(t("music_release"), U.act(music.release), { help = U.help("music_release") })
	page:header(t("music_tracks"))
	local tracks = music.tracks()
	if #tracks == 0 then page:label(t("music_none")) end
	for _, track in ipairs(tracks) do
		page:action(track_name(track), U.act(music.play, track))
	end
end

return function(page)
	page:header(t("time"))
	U.effect_number(page, "time_scale", "time_scale", { off = 1, min = 0.1, max = 4, step = 0.1, format = "x%.1f" })
	U.effect(page, "pause", "pause")

	page:header(t("camera"))
	-- The default of each is what the game set on this screen (a mission and the ship differ), from
	-- Obsidian API 1.25.0; an older one gives a mission's.
	local game_camera = world.camera.defaults and world.camera.defaults() or {}
	local function own(field, fallback)
		local v = game_camera[field]
		return type(v) == "number" and math.floor(v + 0.5) or fallback
	end
	U.effect_number(page, "camera_distance", "camera_distance", { off = own("distance", 17), min = 5, max = 60, step = 1 })
	U.effect_number(page, "camera_angle", "camera_angle", { off = own("angle", 65), min = 20, max = 90, step = 5 })
	U.effect(page, "free_camera_bounds", "free_camera_bounds")
	U.effect(page, "no_camera_shake", "no_camera_shake")
	U.effect_number(page, "camera_fov", "camera_fov", { off = own("fov", 60), min = 20, max = 120, step = 5 })
	U.effect_number(page, "camera_spin", "camera_spin", { off = -45, min = -180, max = 180, step = 15 })
	page:page(t("spectate"), spectate, { help = U.help("spectate") })
	U.effect(page, "photo_mode", "photo_mode")

	page:header(t("screen"))
	U.effect(page, "hide_hud", "hide_hud")
	U.effect(page, "show_patrols", "show_patrols")
	U.effect(page, "test_info", "test_info")

	page:header(t("look"))
	U.effect(page, "no_fog", "no_fog")
	U.effect(page, "no_dof", "no_dof")
	U.effect_number(page, "exposure", "exposure", { off = 1, min = 0.2, max = 3, step = 0.1, format = "%.1f" })
	U.effect_choice(page, "time_of_day", "time_of_day", {
		{ id = false, label = t("time_of_day_auto") }, { id = "dawn", label = t("seed_dawn") }, { id = "day", label = t("seed_day") },
		{ id = "dusk", label = t("seed_dusk") }, { id = "night", label = t("seed_night") },
	})
	tint(page, "fog_color", "fog_color", FOG)
	tint(page, "sun_color", "sun_color", SUN)
	U.effect_number(page, "gravity", "gravity", { off = -18, min = -60, max = -1, step = 1 })
	U.action(page, "clear_decals", world.clear_decals)

	page:header(t("sound"))
	if api.music then page:page(t("soundtrack"), soundtrack, { help = U.help("soundtrack") }) end
	U.effect(page, "mute_music", "mute_music")
	volume(page, "volume_sfx", "sfx_master")
	volume(page, "volume_voices", "vo_master")
	volume(page, "volume_music", "music_master")

	page:header(t("blast"))
	page:number(t("blast_power"), { min = 10, max = 20000, step = 50, default = BLAST_POWER, help = U.help("blast_power"), get = function() return blast.power end, set = function(v) blast.power = v end })
	page:number(t("blast_radius"), { min = 1, max = 30, step = 1, default = BLAST_RADIUS, help = U.help("blast_radius"), get = function() return blast.radius end, set = function(v) blast.radius = v end })
	page:action(t("blast_cursor"), function()
		local ok, why = world.explode(world.cursor(), blast.power, blast.radius)
		if ok then return t("done") end
		return U.why(why)
	end, { enabled = U.in_mission, help = U.help("blast_cursor") })
end
