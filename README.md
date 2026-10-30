# Obsidian Trainer

An in-game window for HELLDIVERS (2015): your character, weapons, stratagems, enemies, missions and the game's numbers. It works with the mouse or the keys, and you can move and resize it.

It doesn't change XP or rank, doesn't unlock paid DLC and doesn't touch the Galactic War. It's a session mod, so it follows the same multiplayer rules as any other. It has been tested solo and offline, but not yet with a second player.

## How to Use

Obsidian Trainer comes with [Obsidian](https://github.com/Alomare/ObsidianModManager), in the STARTER PACK folder, switched off. It updates from this repository.

1. Switch on Obsidian Trainer in the Mods tab. [Obsidian API](https://github.com/Alomare/ObsidianAPI), the mod it's built on, turns on with it.
2. Deploy, then start the game.
3. Press F6 to open the window. You can change the key in the mod's Keys tab.

The Obsidian Trainer page in the app's Wiki has every key and page.

## Releasing

Set `version` in `obsidian.json`, commit, then push a tag with the same version:

```
git tag v1.0.1
git push origin v1.0.1
```

The Release workflow packs the mod into a `.zip` and publishes it, and Obsidian offers it as an update.

## License

[MIT](LICENSE)
