# Shell Game — a key item randomizer for Spelunky 2

Shell Game is a key item randomizer for Spelunky 2 that shuffles key progression items to create unique paths to Hundun and Cosmic Ocean.

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
1. Download `Spelunky2-ShellGame-vX.Y.Z.zip` from the [latest GitHub release](../../releases/latest)
2. Open Modlunky 2
3. Go to **Mods** tab → **Open Mods Folder**
4. Extract the downloaded archive into the Mods folder
5. In Modlunky 2, go to **Playlunky** tab
6. Find **Shell Game** in the mod list and enable it
7. Click **Play!** to launch Spelunky 2 with the mod

## Configuration

Access options via Modlunky 2's options menu or Overlunky (F8) → Options:

| Option | Description |
|--------|-------------|
| **Enable Shell Game** | Master toggle |
| **Randomizer Seed** | Choose a fixed seed; `0` generates a new layout at run start |
| **New Seed** | Sets the seed to `0`, causing the next run to generate a new layout |
| **Kali Item Recovery** | Restores held and allowed altar-dropped items from City of Gold to Duat |
| **Balanced Duat Kali Rewards** | Replaces Duat altar favor rewards with cumulative Player Bag and Royal Jelly rewards |
| **True Crown Restoration** | Removes Kali's curse and restores the player to at least 4 HP after the True Crown encounter |
| **Generate Spoiler** | Includes the spoiler mapping in the per-run report |
| **Generate Logs** | Includes mod logs in the same per-run report |
| **Test Resources** | Grants a debug loadout for adapter verification |

## Reporting an Issue

Leave **Generate Spoiler** and **Generate Logs** enabled. At the start of every
run, the mod writes one report to the `run_reports/` folder in its data folder;
for an install extracted from the release archive, that is
`Mods/Data/ShellGame/run_reports/`.
Either option can create that same file, containing its enabled section(s).
Attach the newest `.txt` file when reporting a problem; with both enabled, it
includes the randomizer seed, the game adventure seed, the full spoiler mapping,
and all Shell Game logs.
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
2. Run `powershell -ExecutionPolicy Bypass -File .\scripts\package.ps1` to create `dist/Spelunky2-ShellGame-vX.Y.Z.zip` and `dist/Spelunky2-ShellGame-vX.Y.Z-dev.zip`, each holding a single `ShellGame` folder.
3. Reload scripts in Overlunky (Ctrl+F5) or restart game, then check the console (`~`) for logs.

### Running the tests

The logic suite runs outside the game and needs Lua 5.4 (use `lua` in place of `lua5.4` if that is how your install names it). From the repository root:

```sh
lua5.4 scripts/run_tests.lua
```

It fuzzes 1,000 seeds by default (pass a different count as the first argument), prints which test and seed failed, and exits non-zero on failure. Every pull request and push to `main` runs this same command in the `tests` check.

The same command runs the `adapters` suite: scenarios in `tests/adapter_tests.lua` that load the shipped adapter modules against a stand-in for the game (`tests/stand_in.lua`). The stand-in records spawns, destroys and callbacks; nothing happens unless a scenario fires it. The in-game `kir_tests` command runs only the logic suite.

To add a scenario for a check:

1. Add `scenario("what the player sees", function(game) ... end, {CHECK_ID="REWARD_ID"})` to `tests/adapter_tests.lua`. The mapping is fixed for that scenario, and each scenario starts with freshly loaded mod modules.
2. Set up the level with `game:start_level{theme=THEME.X, world=w, level=l, entities={{"ENT_NAME", x=..., y=..., layer=...}}}`. It runs the same pre/post level-generation sequence as `main.lua`. Entity fields are free-form, so stage whatever the adapter reads (`abs_x`, `inside`, `health`, `set_pre_destroy`...). Use `game:add_player{...}` and `game:place("ENT_NAME", {holder=player})` for inventory.
3. Fire what the game would: `game:native_spawn("ENT_NAME", {...})` for a spawn, `game:drop("DROP_NAME", "NATIVE_ENT_NAME", {...})` for an engine drop, `game:kill(entity)` for a boss death, and `game:frames(n)` to run `ON.FRAME` and deferred work.
4. Assert on `game:spawned_of("ENT_NAME")`, `game:entity(uid)` (nil once destroyed), `game.destroyed`, `game:materialized("CHECK_ID")` and `game:logged("text")`.

A pull request that adds or changes a check's adapter includes a stand-in scenario for that check, alongside the in-game verification [`docs/verified-checks.md`](docs/verified-checks.md) requires.

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
