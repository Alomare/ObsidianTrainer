# Changelog

New, changed or removed options, one line each, brief and direct. A release's section becomes its release notes.

## 1.15.0

- New: Move speed while aiming and Move speed while reloading on the Player page, which let weapons that hold the player in place be walked with.
- Fixed: on a loader without `obsidian.save_data` the Mission page rows stay open, as before saves came in.

## 1.14.0

- Changed: the Mission page rows that award progression (spawn and collect samples) need a Sandbox save. On an Official save they stay locked and point to the Saves tab.

## 1.13.0

- New: each bot's page has **Objectives**: work the terminal at the cursor (codes and presses to the end), stop working it, deliver the nearest thing to carry, reinforce at the cursor, board the shuttle, load my launcher, take ammo from my backpack or from the bot's own, and set off satchel charges.
- New: **In the camera** for each bot. Off, the camera no longer frames the bot and it can walk anywhere on the map.
- New: **Support weapon at the cursor, on the move** for each bot: the bot keeps walking while it fires, then puts the weapon away for 10 seconds.
- New: **Use the thing at the cursor, forced** for each bot.
- These rows show with the next Obsidian API.

## 1.12.1

- Changed: with **Each weapon for what it can hurt**, the bot fires the support weapon until the target dies or the weapon is spent, and looks again a second later: a launcher with several rockets, such as the Commando, fires them all.
- Changed: an order given on the **Bots** page stops a support weapon shot the bot started by itself, and holds those back for 8 seconds. A shot that came to nothing waits 5 seconds before the next.
- Fixed: messages on how a bot's order ended showed "bot_enter_failed" in place of the text.

## 1.12.0

- Changed: on the **Bots** page, **Fight** is a choice for each bot: **Off**, **Nearest enemy**, **Each weapon for what it can hurt** (the primary for what it gets through the armor of, the support weapon for the rest), **In a vehicle: both weapons**, and **In a mech: gun, then rockets**. All of this release's rows show in full with Obsidian API 1.38.0.
- New: each bot's page has **Weapons** (take out a weapon, the support weapon at the enemy at the cursor, the damage each weapon does to that enemy, refill the backpack), **Vehicles** (get in, take the driver's seat, get out, ride along, a mech that spares Helldivers) and **Using things** (the thing at the cursor or the nearest one, put it down, voice lines, a jump pack jump to the cursor).
- New: **Get out of enemy shots** for each bot and for every bot: the bot walks out of a Hunter's, a Cyborg IFV's or a Hulk's aim before the shot.
- New: on the **Bots** page, **Fight with each weapon for what it can hurt** and **Mechs spare Helldivers** for every bot.
- New: on the **Enemies** page, **Tell me when an enemy aims** and **Armor of the enemy**, with what each of your weapons does to it.
- Changed: a bot that can't follow an order says why in words about the bot: busy, in a seat, a seat someone else took.
- Changed: on the **Bots** page, **Help up the nearest** and **Heal the most hurt** say when another bot is already on the way to everyone who needs it. Needs Obsidian API 1.34.0.

## 1.11.0

- New: on the **Bots** page, **Help up the nearest**, **Heal the most hurt** and **Heal me** for every bot or one, and **Help each other** and **Stop helping each other** for every bot. Healing uses the REP-80 in the bot's slots. Needs Obsidian API 1.33.0.
- New: each bot's page has **Get up when downed** (on by default), **Help others up**, **Heal others** and **Stop helping**.

## 1.10.0

- Changed: **Practice mission** is now **Custom mission**, which drops into a real mission. XP, samples and unlocks count. Before, it started a training mission that paid no XP. The campaign stays as it was: no planet progress, and no Galactic War or leaderboard report.

## 1.9.2

- Changed: **Field of view**, **Camera distance** and **Camera angle** reset to the game's own values for the current screen, on the ship as in missions. They reset to a mission's values before, which left the ship's camera wrong.

## 1.9.1

- Changed: a new image beside the mod in Obsidian's mod list.

## 1.9.0

- New: Enter a stratagem on each bot's page: the bot holds the stratagem key, enters the code of a stratagem it carries and throws the flare at the cursor. Stop entering ends it.
- New: Enter a stratagem under Every bot: each bot carrying the chosen stratagem enters it.

## 1.8.0

- New: the mod's image, shown beside it in Obsidian's mod list.

## 1.7.0

- New: Auto-respawn on the Mission page, under Reinforcements: a dead player drops back in after 3 seconds, even with no reinforcements left.
- New: Look and Layout for practice missions: one of the planet's terrain sets or a faction's world, and which of the 215 maps the choices can make.
