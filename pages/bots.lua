-- Bots: Helldivers this machine plays, to fight beside or to test against.
local U = obsidian.module("pages/ui")
local api, t = U.api, U.t
local bots, catalog, world = api.bots, api.catalog, api.world

-- Making and ordering bots is for the host in a mission.
local function ready()
	local ok, why = U.in_mission()
	if not ok then return ok, why end
	return U.host_only()
end

-- The toast for a new bot, and the list again with it.
local function added(page, bot, why)
	if not bot then return U.why(why) end
	page:refresh()
	return t("bot_added", bot.name)
end

-- The toast for what a bot answered: a bot without a body isn't the player off the field.
local function result(ok, why)
	if ok ~= false then return t("done") end
	if why == "no_avatar" then return t("bot_no_body") end
	return U.why(why)
end

-- The same order to every bot. fn(bot) may answer false and a reason; the first one is the toast.
local function to_all(fn)
	return function()
		local list = bots.all()
		if #list == 0 then return t("bots_none") end
		for _, b in ipairs(list) do
			local ok, why = fn(b)
			if ok == false then return result(ok, why) end
		end
		return t("done")
	end
end

local function to_one(bot, fn)
	return function() return result(fn(bot)) end
end

local function orders(page, run)
	page:action(t("bot_follow"), run(function(b) b:follow() end), { enabled = ready, help = U.help("bot_follow") })
	page:action(t("bot_hold"), run(function(b) b:hold() end), { enabled = ready, help = U.help("bot_hold") })
	page:action(t("bot_go_cursor"), run(function(b)
		local pos = world.cursor()
		if not pos then return false, "no_position" end
		b:go_to(pos)
	end), { enabled = ready, help = U.help("bot_go_cursor") })
	page:action(t("bot_come"), run(function(b) return b:teleport(world.ahead(2)) end), { enabled = ready, help = U.help("bot_come") })
	page:action(t("bot_heal"), run(function(b) return b:heal() end), { enabled = ready, help = U.help("bot_heal") })
	page:action(t("bot_revive"), run(function(b)
		if not b.revive then return false, "not_available" end
		return b:revive()
	end), { enabled = ready, help = U.help("bot_revive") })
	page:action(t("bot_heal_target"), run(function(b)
		if not b.heal_target then return false, "not_available" end
		return b:heal_target()
	end), { enabled = ready, help = U.help("bot_heal_target") })
	page:action(t("bot_heal_me"), run(function(b)
		if not b.heal_target then return false, "not_available" end
		local me = api.game.my_unit()
		if not me then return false, "no_avatar" end
		return b:heal_target(me)
	end), { enabled = ready, help = U.help("bot_heal_me") })
end

-- Helping each other on their own: getting up, helping up and healing with the REP-80.
local function help_toggles(page, b)
	if not b.auto_revive then return end
	page:toggle(t("bot_get_up_own"), {
		default = true, help = U.help("bot_get_up_own"),
		get = function() return b.get_up ~= false end,
		set = function(on) b:auto_get_up(on) end,
	})
	page:toggle(t("bot_revive_own"), {
		default = false, help = U.help("bot_revive_own"),
		get = function() return (b:auto_helping()) ~= false end,
		set = function(on) b:auto_revive(on and 15 or false) end,
	})
	page:toggle(t("bot_heal_own"), {
		default = false, help = U.help("bot_heal_own"),
		get = function() return select(2, b:auto_helping()) ~= false end,
		set = function(on) b:auto_heal(on and 20 or false) end,
	})
	page:action(t("bot_help_stop"), to_one(b, function()
		if not b:stop_helping() then return false, "not_helping" end
	end), { help = U.help("bot_help_stop") })
end

-- icons: true for a list of stratagems, whose HUD icons are square; others have none here.
local function list_page(items, run, icons)
	return function(sub)
		for _, item in ipairs(items()) do
			sub:action(catalog.text(item.name), function() return result(run(item)) end, { icon = icons and item.icon or nil })
		end
	end
end

-- Entering a code takes a moment, so how it ended comes as a toast of its own, named after the bot.
local function enter(b, name)
	if not b.use_stratagem then return false, "not_available" end
	local pos = world.cursor()
	if not pos then return false, "no_position" end
	return b:use_stratagem(name, pos, function(ok, why)
		if not ok then (api.menu or obsidian).toast(t("bot_enter_failed", b.name, U.why(why))) end
	end)
end

local function entered(ok, why)
	if ok then return t("bot_entering") end
	return result(ok, why)
end

-- The stratagems the bot carries, read when the page opens.
local function enter_page(b)
	return function(sub)
		local held = b:stratagems()
		if #held == 0 then sub:label(t(b:alive() and "bot_enter_none" or "bot_no_body")) end
		for _, h in ipairs(held) do
			local s = catalog.stratagem(h.name)
			sub:action(catalog.text(h.name), function() return entered(enter(b, h.name)) end, { icon = s and s.icon or nil })
		end
	end
end

-- Every bot that carries the stratagem enters it.
local function enter_all(s)
	local list = bots.all()
	if #list == 0 then return t("bots_none") end
	local started, first_why = 0, nil
	for _, b in ipairs(list) do
		local ok, why = enter(b, s.name)
		if ok then
			started = started + 1
		elseif why ~= "not_held" then
			first_why = first_why or why
		end
	end
	if started > 0 then return t("bot_entering") end
	if first_why then return result(false, first_why) end
	return t("bots_none_carry")
end

-- How a longer order ended, as a toast named after the bot: what it did, or why it stopped.
local function toast(text)
	local m = api.menu or obsidian
	return m.toast(text)
end

local function told(b, done_key)
	return function(ok, why)
		local text = (ok and done_key) and t(done_key) or U.why(why)
		toast(t("bot_enter_failed", b.name, text))
	end
end

-- The enemy nearest the cursor, within 8 meters of it.
local function enemy_at_cursor()
	local pos = world.cursor()
	if not pos then return nil, "no_position" end
	local e, d = api.enemies.nearest(pos)
	if not e or (d or 0) > 8 then return nil, "no_target" end
	return e
end

local function vehicle_at_cursor()
	local pos = world.cursor()
	if not pos then return nil, "no_position" end
	local v = api.vehicles.nearest(pos, 6)
	if not v then return nil, "no_vehicle" end
	return v
end

-- What fight is set to, as the Trainer set it: off, the nearest enemy, each weapon for what it can hurt,
-- a seat's both weapons, or a mech's gun for what it can hurt and rockets for the rest.
local fight_mode = setmetatable({}, { __mode = "k" })
-- Bots firing the support weapon by themselves at what the primary can't hurt: bot -> seconds to wait.
local heavy_wait = setmetatable({}, { __mode = "k" })
-- The toggles set here, by bot: riding along, a mech that spares Helldivers, getting out of shots.
local riding, sparing, avoiding = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local HEAVY_LOOK, HEAVY_AFTER = 1, 5

local function hurt(b, e, slot)
	return (b:hurts(e, slot)) or 0
end

-- Through the gun of the vehicle the bot sits in: nil when that seat has no gun.
local function gun_hurts(b, e)
	local v = b:seat()
	if not v then return nil end
	return (api.gear.hurts(v, e))
end

local FIGHT = {
	off = function(b) b:fight(false) end,
	nearest = function(b) b:fight(25) end,
	smart = function(b)
		b:fight(25, { weapon = "primary", only = function(e) return hurt(b, e, "primary") > 0 end })
		heavy_wait[b] = 0
	end,
	vehicle = function(b) b:fight(25, { secondary = true }) end,
	mech = function(b)
		b:fight(25, {
			only = function(e) return (gun_hurts(b, e) or 1) > 0 end,
			secondary = { only = function(e) return (gun_hurts(b, e) or 0) == 0 end },
		})
	end,
}

local function set_fight(b, mode)
	heavy_wait[b] = nil
	fight_mode[b] = mode
	if not (b.hurts or mode == "off" or mode == "nearest" or mode == "vehicle") then return false, "not_available" end
	FIGHT[mode](b)
	return true
end

-- Each second, a bot set to "each weapon for what it can hurt" looks for an enemy it sees that the
-- primary can't hurt and the support weapon can, fires the support weapon at it, and looks again 5
-- seconds after.
obsidian.on_frame(function()
	local dt = rawget(_G, "ENGINE_DT") or 0.016
	for b, wait in pairs(heavy_wait) do
		if fight_mode[b] ~= "smart" then
			heavy_wait[b] = nil
		elseif wait > dt then
			heavy_wait[b] = wait - dt
		elseif b:alive() and not b:using_weapon() then
			heavy_wait[b] = HEAVY_LOOK
			local heavy = b:enemies_in_sight(30, function(e) return hurt(b, e, "primary") == 0 and hurt(b, e, "support") > 0 end)[1]
			if heavy and b:use_weapon("support", heavy, told(b, "bot_fired")) then heavy_wait[b] = HEAVY_AFTER end
		else
			heavy_wait[b] = HEAVY_LOOK
		end
	end
end)

local function fight_row(page, b)
	page:choice(t("bot_fight"), {
		choices = {
			{ id = "off", label = t("bot_fight_off") }, { id = "nearest", label = t("bot_fight_nearest") },
			{ id = "smart", label = t("bot_fight_smart") }, { id = "vehicle", label = t("bot_fight_vehicle") },
			{ id = "mech", label = t("bot_fight_mech") },
		},
		default = "off", help = U.help("bot_fight"),
		get = function()
			if b:fighting() == false then return "off" end
			return fight_mode[b] or "nearest"
		end,
		set = function(mode)
			local ok, why = set_fight(b, mode)
			if not ok then toast(U.why(why)) end
		end,
	})
end

-- One line per weapon slot: what one hit costs the target, square, glancing and on the weak spot.
local function hurts_text(rows)
	local lines = {}
	for _, r in ipairs(rows) do
		if r.square then
			lines[#lines + 1] = t("hurts_line", r.name, math.floor(r.square), math.floor(r.glancing), math.floor(r.weak))
		end
	end
	if #lines == 0 then return U.why("no_weapon") end
	return table.concat(lines, "\n")
end

local function weapon_rows(page, b)
	if not b.wield then return end
	page:header(t("bot_weapons"))
	page:page(t("bot_wield"), function(sub)
		for _, slot in ipairs({ "primary", "sidearm", "support" }) do
			sub:action(t("slot_" .. slot), to_one(b, function() return b:wield(slot) end))
		end
	end, { help = U.help("bot_wield") })
	page:action(t("bot_use_support"), to_one(b, function()
		local e, why = enemy_at_cursor()
		if not e then return false, why end
		return b:use_weapon("support", e, told(b, "bot_fired"))
	end), { help = U.help("bot_use_support") })
	page:action(t("bot_cancel_weapon"), to_one(b, function()
		if not b:cancel_weapon() then return false, "not_available" end
	end), { help = U.help("bot_cancel_weapon") })
	if b.hurts then
		page:action(t("bot_hurts"), function()
			local e, why = enemy_at_cursor()
			if not e then return U.why(why) end
			local rows = {}
			for _, slot in ipairs({ "primary", "sidearm", "support" }) do
				local s, g, w = b:hurts(e, slot)
				rows[#rows + 1] = { name = t("slot_" .. slot), square = s, glancing = g, weak = w }
			end
			return hurts_text(rows)
		end, { help = U.help("bot_hurts") })
	end
	page:action(t("bot_refill_backpack"), to_one(b, function() return b:refill_backpack() end), { help = U.help("bot_refill_backpack") })
end

local function vehicle_rows(page, b)
	if not b.enter_vehicle then return end
	page:header(t("bot_vehicles"))
	page:action(t("bot_enter_vehicle"), to_one(b, function()
		local v, why = vehicle_at_cursor()
		if not v then return false, why end
		return b:enter_vehicle(v, nil, told(b, "bot_seated"))
	end), { help = U.help("bot_enter_vehicle") })
	page:action(t("bot_enter_driver"), to_one(b, function()
		local v, why = vehicle_at_cursor()
		if not v then return false, why end
		for _, s in ipairs(api.vehicles.seats(v)) do
			if s.drives then return b:enter_vehicle(v, s.index, told(b, "bot_seated")) end
		end
		return false, "no_seat"
	end), { help = U.help("bot_enter_driver") })
	page:action(t("bot_leave_vehicle"), to_one(b, function() return b:leave_vehicle() end), { help = U.help("bot_leave_vehicle") })
	page:toggle(t("bot_ride_along"), {
		default = false, help = U.help("bot_ride_along"),
		get = function() return riding[b] == true end,
		set = function(on)
			riding[b] = on or nil
			b:ride_along(on)
		end,
	})
	if b.mech_friendly_fire then
		page:toggle(t("bot_mech_spares"), {
			default = false, help = U.help("bot_mech_spares"),
			get = function() return sparing[b] == true end,
			set = function(on)
				sparing[b] = on or nil
				b:mech_friendly_fire(not on)
			end,
		})
	end
end

local WORDS = { "yes", "no", "stay", "move", "taunt" }

local function thing_rows(page, b)
	if not b.use then return end
	page:header(t("bot_things"))
	page:action(t("bot_use_cursor"), to_one(b, function()
		local pos = world.cursor()
		if not pos then return false, "no_position" end
		local thing = bots.usables(pos, 5)[1]
		if not thing then return false, "no_target" end
		return b:use(thing.unit, told(b, "bot_used"))
	end), { help = U.help("bot_use_cursor") })
	page:action(t("bot_use_near"), to_one(b, function()
		if not b.position then return false, "not_available" end
		local pos = b:position()
		if not pos then return false, "no_avatar" end
		local thing = bots.usables(pos, 15)[1]
		if not thing then return false, "no_target" end
		return b:use(thing.unit, told(b, "bot_used"))
	end), { help = U.help("bot_use_near") })
	page:action(t("bot_cancel_use"), to_one(b, function()
		if not b:cancel_use() then return false, "not_available" end
	end), { help = U.help("bot_cancel_use") })
	page:action(t("bot_drop"), to_one(b, function() return b:drop() end), { help = U.help("bot_drop") })
	page:page(t("bot_say"), function(sub)
		for _, word in ipairs(WORDS) do
			sub:action(t("say_" .. word), to_one(b, function() return b:say(word) end))
		end
	end, { help = U.help("bot_say") })
	page:action(t("bot_jump"), to_one(b, function()
		if not b.position then return false, "not_available" end
		local to, from = world.cursor(), b:position()
		if not to then return false, "no_position" end
		if not from then return false, "no_avatar" end
		return b:jump({ x = to.x - from.x, y = to.y - from.y }, told(b, "bot_landed"))
	end), { help = U.help("bot_jump") })
end

local function danger_rows(page, b)
	if not b.avoid_shots then return end
	page:toggle(t("bot_avoid"), {
		default = false, help = U.help("bot_avoid"),
		get = function() return avoiding[b] == true end,
		set = function(on)
			avoiding[b] = on or nil
			b:avoid_shots(on)
		end,
	})
end

local function gear(page, b)
	page:page(t("give_primary"), list_page(catalog.primaries, function(w) return b:give_weapon("primary_weapon", w.unit_path) end), { help = U.help("give_primary") })
	page:page(t("give_sidearm"), list_page(catalog.sidearms, function(w) return b:give_weapon("sidearm_weapon", w.unit_path) end), { help = U.help("give_sidearm") })
	page:page(t("give_support"), list_page(catalog.support_weapons, function(w) return b:give_weapon("support_weapon", w.unit_path) end), { help = U.help("give_support") })
	page:page(t("give_backpack"), list_page(catalog.backpacks, function(p) return b:give_backpack(p.unit_path) end), { help = U.help("give_backpack") })
	page:page(t("give_perk"), list_page(catalog.perks, function(p) return b:give_perk(p.name) end), { help = U.help("give_perk") })
	page:page(t("bot_give_stratagem"), list_page(catalog.stratagems, function(s) return b:give_stratagem(s.name) end, true), { help = U.help("bot_give_stratagem") })
	page:action(t("bot_remove_perk"), to_one(b, function() return b:remove_perk() end), { help = U.help("bot_remove_perk") })
	page:action(t("bot_refill"), to_one(b, function() return b:refill() end), { help = U.help("bot_refill") })
end

local function one(b)
	return function(page)
		page:label(function() return t(b:alive() and "bot_alive" or "bot_no_body") end)
		page:header(t("bot_orders"))
		orders(page, function(fn) return to_one(b, fn) end)
		fight_row(page, b)
		danger_rows(page, b)
		help_toggles(page, b)
		page:action(t("bot_aim_cursor"), to_one(b, function()
			local pos = world.cursor()
			if not pos then return false, "no_position" end
			b:aim_at(pos)
		end), { help = U.help("bot_aim_cursor") })
		page:action(t("bot_aim_free"), to_one(b, function() b:aim_at(nil) end), { help = U.help("bot_aim_free") })
		page:toggle(t("bot_shoot"), { default = false, help = U.help("bot_shoot"), get = function() return b:firing() end, set = function(on) b:fire(on) end })
		page:action(t("bot_throw"), to_one(b, function() b:throw() end), { help = U.help("bot_throw") })
		page:action(t("bot_switch"), to_one(b, function() b:switch() end), { help = U.help("bot_switch") })
		page:action(t("bot_reload"), to_one(b, function() b:reload() end), { help = U.help("bot_reload") })
		page:page(t("bot_enter"), enter_page(b), { help = U.help("bot_enter") })
		page:action(t("bot_enter_stop"), to_one(b, function()
			if not (b.cancel_stratagem and b:cancel_stratagem()) then return false, "not_entering" end
		end), { help = U.help("bot_enter_stop") })
		page:page(t("bot_call"), list_page(catalog.stratagems, function(s) return b:call(s.name, world.cursor()) end, true), { help = U.help("bot_call") })

		weapon_rows(page, b)
		vehicle_rows(page, b)
		thing_rows(page, b)

		page:header(t("bot_gear"))
		gear(page, b)

		page:header(t("bot_leave"))
		page:action(t("bot_remove"), to_one(b, function() b:remove() end), { help = U.help("bot_remove") })
	end
end

return function(page)
	page:action(t("bot_add"), function() return added(page, bots.add()) end, { enabled = ready, help = U.help("bot_add") })
	page:input(t("bot_add_named"), function(name) return added(page, bots.add({ name = name })) end, { enabled = ready, help = U.help("bot_add_named") })
	page:action(t("bot_add_bare"), function() return added(page, bots.add({ bare = true })) end, { enabled = ready, help = U.help("bot_add_bare") })

	local list = bots.all()
	page:header(t("bots_all"))
	if #list == 0 then page:label(t("bots_none")) end
	orders(page, to_all)
	page:action(t("bot_fight_all"), to_all(function(b) return set_fight(b, "nearest") end), { enabled = ready, help = U.help("bot_fight_all") })
	page:action(t("bot_fight_smart_all"), to_all(function(b) return set_fight(b, "smart") end), { enabled = ready, help = U.help("bot_fight_smart_all") })
	page:action(t("bot_calm_all"), to_all(function(b) return set_fight(b, "off") end), { enabled = ready, help = U.help("bot_calm_all") })
	page:action(t("bot_avoid_all"), to_all(function(b)
		if not b.avoid_shots then return false, "not_available" end
		avoiding[b] = true
		b:avoid_shots(true)
	end), { enabled = ready, help = U.help("bot_avoid_all") })
	page:action(t("bot_mech_spares_all"), to_all(function(b)
		if not b.mech_friendly_fire then return false, "not_available" end
		sparing[b] = true
		b:mech_friendly_fire(false)
	end), { enabled = ready, help = U.help("bot_mech_spares_all") })
	page:action(t("bot_help_all"), to_all(function(b)
		if not b.auto_revive then return false, "not_available" end
		b:auto_revive(15):auto_heal(20)
	end), { enabled = ready, help = U.help("bot_help_all") })
	page:action(t("bot_help_none"), to_all(function(b)
		if not b.auto_revive then return false, "not_available" end
		b:auto_revive(false):auto_heal(false)
	end), { enabled = ready, help = U.help("bot_help_none") })
	page:page(t("bot_enter_all"), U.stratagem_list(enter_all), { enabled = ready, help = U.help("bot_enter_all") })
	page:action(t("bot_remove_all"), function()
		bots.remove_all()
		page:refresh()
		return t("done")
	end, { help = U.help("bot_remove_all") })

	if #list > 0 then page:header(t("bots_each")) end
	for _, b in ipairs(list) do
		page:page(b.name, one(b))
	end
end
