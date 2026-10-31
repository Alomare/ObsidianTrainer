# Obsidian Trainer

An in-game window for HELLDIVERS (2015) that changes your character, weapons, stratagems, enemies, missions and game data. Use it with the mouse or the keys, and move or resize it.

Missions add nothing to your save while it's on, and it only offers the base game and the DLC you own. It stays out of the Galactic War. As a session mod, it follows the same multiplayer rules as any other.

## How to Use

Obsidian Trainer comes with [Obsidian](https://github.com/Alomare/ObsidianModManager), in the Obsidian Kit folder, switched off. It updates from this repository.

1. Switch on Obsidian Trainer in the Mods tab. [Obsidian API](https://github.com/Alomare/ObsidianAPI), the mod it's built on, turns on with it.
2. Deploy, then start the game.
3. Press F6 to open the window. The Keys tab of the mod changes the key.

The Obsidian Trainer page in the Wiki lists every key and page.

## Releasing

Set `version` in `obsidian.json`, commit, then push a tag with the same version:

```
git tag v1.0.1
git push origin v1.0.1
```

The Release workflow packs the mod into a `.zip` and publishes it, and Obsidian offers it as an update.

## License

[MIT](LICENSE)
