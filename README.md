# Key Item Randomizer - Spelunky 2

A Spelunky 2 randomizer mod that shuffles key progression items to create unique paths to Hundun and Cosmic Ocean.

## Current implementation

The randomizer creates a deterministic `CHECK_ID -> REWARD_ID` mapping rather
than taking items from a pool in entity-spawn order. Its selected randomizer
seed persists between launches; all run progress remains runtime-only.

Runtime code is split by responsibility: `main.lua` manages lifecycle and
console commands, `placements.lua` materializes mapped rewards, and `checks.lua`
contains individual in-game check adapters.

- `kir_validate [seed]` prints a validated Cosmic Ocean route.
- `kir_fuzz [count] [first_seed]` checks determinism, one-to-one reward
  assignment, and victory reachability across a seed range.
- `kir_anchors` reports unavailable Overlunky entity-name constants.
- `kir_status` reports the current level epoch and any adapter failures.

See [the logic plan](docs/randomizer-logic-plan.md),
[dry-run victory routes](docs/victory-routes.md), and the
[implementation review checklist](docs/implementation-review.md). The review
document identifies event-specific checks that require a live callback smoke
test before a release build should enable them.

## Overview

This mod randomizes the locations of key progression items in Spelunky 2, forcing players to take different quest paths than normal to reach the final bosses and unlock Cosmic Ocean. Instead of the standard Ankh → City of Gold → Duat → Hundun path, you might find the Ankh in Tide Pool, the Crown in Volcana, or Excalibur in the Temple.

## Key Items Randomized

### Tier 1 (Early Game - Dwelling/Jungle/Volcana)
- **Ankh** - Required for City of Gold, Duat, Hundun
- **Crown** - Required for Excalibur, City of Gold, Kingu, Tiamat
- **Hedjet** - Required for Excalibur, City of Gold
- **Udjat Eye** - Required for Black Market, City of Gold
- **Skeleton Key** - Opens locked doors, City of Gold door

### Tier 2 (Mid Game - Olmec/Tide Pool/Temple/Ice Caves)
- **Excalibur** - Required for Kingu, Tiamat (pulled from Excalibur Stone)
- **Tablet of Destiny** - Required for Hundun fight
- **Kapala** - Blood healing for sustainability

### Tier 3 (Late Game - Neo Babylon/Sunken City/Duat/Abzu/Tiamat/Hundun)
- **Elixir** - Critical for Hundun survival and Cosmic Ocean
- **Arrow of Light** - Required for Hundun → Cosmic Ocean (from Sun Challenge)
- **Hou Yi's Bow** - Required for Hundun → Cosmic Ocean (from Moon Challenge)

## Progression Paths Created

The randomizer can create paths like:

1. **Classic Path**: Ankh (Dwelling) → Crown (Vlad) → Excalibur (Tide Pool) → Tablet (Duat) → Elixir/Arrow/Bow (Hundun)
2. **Sunken City Rush**: Ankh (Black Market) → Hedjet (Jungle) → Excalibur (Temple) → Elixir (Sunken City) → Arrow/Bow (Challenges)
3. **Volcana Route**: Crown (Vlad) → Ankh (Volcana) → Excalibur (Ice Caves) → Tablet (Olmec) → Elixir (Neo Babylon)
4. **Mixed Paths**: Any combination based on seed

## Installation

### Prerequisites
1. **Spelunky 2** (Steam version)
2. **Modlunky 2** - [Download](https://github.com/spelunky-fyi/modlunky2/releases)
3. **Playlunky** - Installed via Modlunky 2's "Playlunky" tab

### Steps
1. Open Modlunky 2
2. Go to **Mods** tab → **Open Mods Folder**
3. Create a new folder: `KeyItemRandomizer`
4. Copy `main.lua` into this folder
5. In Modlunky 2, go to **Playlunky** tab
6. Find "KeyItemRandomizer" in the mod list and enable it
7. Click **Play!** to launch Spelunky 2 with the mod

Release downloads are available from the [latest GitHub release](../../releases/latest). Extract the downloaded archive into a `KeyItemRandomizer` folder in Modlunky 2's **Mods** folder, then enable it in Playlunky.

## Configuration

Access options via Modlunky 2's options menu or Overlunky (F8) → Options:

| Option | Description |
|--------|-------------|
| **Enable Key Item Randomizer** | Master toggle |
| **Randomizer Seed** | Choose a fixed seed; `0` generates a new layout at run start |
| **Test Resources** | Grants a debug loadout for adapter verification |
| **Duat Item Recovery and Kali Rewards** | Restores held and back items at Duat's Kali altar, and replaces its favor rewards with cumulative Player Bag and Royal Jelly rewards |
| **Write Run Reports** | Writes seeds, spoiler mapping, and all mod logs for each run |

## Reporting an Issue

Leave **Write Run Reports** enabled. At the start of every run, the mod writes
a report to `Mods/Data/KeyItemRandomizer/run_reports/`. Attach the newest `.txt`
file when reporting a problem; it includes the randomizer seed, the game
adventure seed, the full spoiler mapping, and all Key Item Randomizer logs.
Use `kir_report_path()` in the Overlunky console to print the current report's
location. The mod retains the newest 30 reports and deletes older reports
automatically.

## Gameplay Tips

1. **Check Journal**: The journal will show discovered items as you find them
2. **Explore Thoroughly**: Key items can be in unexpected places
3. **Use Logic Mode**: Ensures you won't get stuck with unbeatable seeds
4. **Spoiler Log**: Enable for debugging or race planning
5. **Multiple Runs**: Same seed gives same item locations for practice

## Compatibility

- ✅ Works with Overlunky overlay
- ✅ Compatible with most quality-of-life mods
- ⚠️ May conflict with other randomizers (Dregu's Randomizer, etc.)
- ⚠️ Requires Playlunky (DLL injection) for script mods

## Technical Details

### API Usage
- Uses Overlunky/Playlunky Lua API (Lua 5.4 with Sol2)
- Callbacks: `ON.PRE_ENTITY_SPAWN`, `ON.POST_ENTITY_SPAWN`
- Entity manipulation: `get_entities_by`, `spawn_entity`, `kill_entity`
- PRNG: Game's seeded random for deterministic results

### Entity Types Used
```lua
ENT_TYPE.ITEM_PICKUP_ANKH
ENT_TYPE.ITEM_PICKUP_CROWN
ENT_TYPE.ITEM_PICKUP_HEDJET
ENT_TYPE.ITEM_EXCALIBUR
ENT_TYPE.FLOOR_EXCALIBUR_STONE
ENT_TYPE.ITEM_PICKUP_ELIXIR
ENT_TYPE.ITEM_ARROW_OF_LIGHT
ENT_TYPE.ITEM_HOUYIS_BOW
ENT_TYPE.ITEM_TABLET_OF_DESTINY
ENT_TYPE.ITEM_PICKUP_UDJATEYE
ENT_TYPE.ITEM_PICKUP_KAPALA
ENT_TYPE.ITEM_PICKUP_SKELETON_KEY
```

## Building/Development

To modify the mod:
1. Edit the mod files.
2. Run `powershell -ExecutionPolicy Bypass -File .\scripts\package.ps1` to create `dist/KeyItemRandomizer-vX.Y.Z.zip`.
3. Reload scripts in Overlunky (Ctrl+F5) or restart game, then check the console (`~`) for logs.

## Releasing

GitHub automatically packages the mod and publishes its zip when a version tag is pushed. Update `mod.json` first, commit it, then create and push a matching tag:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

The tag must exactly match the `version` in `mod.json` (for example, `0.1.0` requires `v0.1.0`). A manual run from the Actions page saves the zip as a downloadable workflow artifact without publishing a release.

## Known Issues

- Multiplayer event attribution is not yet verified; Kali's first-gift adapter
  currently uses the first active player.

## Credits

- **Overlunky/Playlunky Team** - Modding framework
- **Dregu** - Original Randomizer mod inspiration
- **Spelunky.fyi Community** - Documentation and entity data
- **Spelunky 2 Wiki** - Progression path documentation

## License

MIT License - Feel free to modify and distribute.

## Support

- Report issues on GitHub
- Join [Spelunky Community Discord](https://discord.gg/spelunky-community) for help
- Check [Spelunky.fyi](https://spelunky.fyi) for modding resources
