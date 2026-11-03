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
	page:action(t("bot_follow"), run(function(b) b:follow() end), { enabled = ready })
	page:action(t("bot_hold"), run(function(b) b:hold() end), { enabled = ready })
	page:action(t("bot_go_cursor"), run(function(b)
		local pos = world.cursor()
		if not pos then return false, "no_position" end
		b:go_to(pos)
	end), { enabled = ready, help = U.help("bot_go_cursor") })
	page:action(t("bot_come"), run(function(b) return b:teleport(world.ahead(2)) end), { enabled = ready })
	page:action(t("bot_heal"), run(function(b) return b:heal() end), { enabled = ready, help = U.help("bot_heal") })
end

local function list_page(items, run)
	return function(sub)
		for _, item in ipairs(items()) do
			sub:action(catalog.text(item.name), function() return result(run(item)) end)
		end
	end
end

local function gear(page, b)
	page:page(t("give_primary"), list_page(catalog.primaries, function(w) return b:give_weapon("primary_weapon", w.unit_path) end))
	page:page(t("give_sidearm"), list_page(catalog.sidearms, function(w) return b:give_weapon("sidearm_weapon", w.unit_path) end))
	page:page(t("give_support"), list_page(catalog.support_weapons, function(w) return b:give_weapon("support_weapon", w.unit_path) end))
	page:page(t("give_backpack"), list_page(catalog.backpacks, function(p) return b:give_backpack(p.unit_path) end))
	page:page(t("give_perk"), list_page(catalog.perks, function(p) return b:give_perk(p.name) end))
	page:page(t("bot_give_stratagem"), list_page(catalog.stratagems, function(s) return b:give_stratagem(s.name) end))
	page:action(t("bot_remove_perk"), to_one(b, function() return b:remove_perk() end))
	page:action(t("bot_refill"), to_one(b, function() return b:refill() end))
end

local function one(b)
	return function(page)
		page:label(function() return t(b:alive() and "bot_alive" or "bot_no_body") end)
		page:header(t("bot_orders"))
		orders(page, function(fn) return to_one(b, fn) end)
		page:toggle(t("bot_fight"), {
			default = false, help = U.help("bot_fight"),
			get = function() return b:fighting() ~= false end,
			set = function(on) b:fight(on and 25 or false) end,
		})
		page:action(t("bot_aim_cursor"), to_one(b, function()
			local pos = world.cursor()
			if not pos then return false, "no_position" end
			b:aim_at(pos)
		end), { help = U.help("bot_aim_cursor") })
		page:action(t("bot_aim_free"), to_one(b, function() b:aim_at(nil) end))
		page:toggle(t("bot_shoot"), { default = false, get = function() return b:firing() end, set = function(on) b:fire(on) end })
		page:action(t("bot_throw"), to_one(b, function() b:throw() end))
		page:action(t("bot_switch"), to_one(b, function() b:switch() end))
		page:action(t("bot_reload"), to_one(b, function() b:reload() end))
		page:page(t("bot_call"), list_page(catalog.stratagems, function(s) return b:call(s.name, world.cursor()) end), { help = U.help("bot_call") })

		page:header(t("bot_gear"))
		gear(page, b)

		page:header(t("bot_leave"))
		page:action(t("bot_remove"), to_one(b, function() b:remove() end))
	end
end

return function(page)
	page:action(t("bot_add"), function() return added(page, bots.add()) end, { enabled = ready, help = U.help("bot_add") })
	page:input(t("bot_add_named"), function(name) return added(page, bots.add({ name = name })) end, { enabled = ready })
	page:action(t("bot_add_bare"), function() return added(page, bots.add({ bare = true })) end, { enabled = ready, help = U.help("bot_add_bare") })

	local list = bots.all()
	page:header(t("bots_all"))
	if #list == 0 then page:label(t("bots_none")) end
	orders(page, to_all)
	page:action(t("bot_fight_all"), to_all(function(b) b:fight(25) end), { enabled = ready })
	page:action(t("bot_calm_all"), to_all(function(b) b:fight(false) end), { enabled = ready })
	page:action(t("bot_remove_all"), function()
		bots.remove_all()
		page:refresh()
		return t("done")
	end)

	if #list > 0 then page:header(t("bots_each")) end
	for _, b in ipairs(list) do
		page:page(b.name, one(b))
	end
end
