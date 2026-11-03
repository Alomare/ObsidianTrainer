# Obsidian Trainer

An in-game window for HELLDIVERS (2015) that changes the character, weapons, stratagems, enemies, missions and game data. It works with the mouse or the keys, and the window can be moved and resized.

Missions add nothing to the save while it's on, and it only offers the base game and owned DLC. It stays out of the Galactic War. As a session mod, it follows the same multiplayer rules as any other.

## How to Use

Obsidian Trainer comes with [Obsidian](https://github.com/Alomare/ObsidianModManager), in the Obsidian Kit folder, switched off. It updates from this repository.

1. Switch on Obsidian Trainer in the Mods tab. [Obsidian API](https://github.com/Alomare/ObsidianAPI), the mod it's built on, turns on with it.
2. Deploy, then start the game.
3. Press F6 to open the window. The Trainer's pages are in the **Obsidian Trainer** folder. The key belongs to Obsidian API, and the Keys tab of Obsidian API changes it.

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
