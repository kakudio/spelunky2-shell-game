# Randomizer Logic Plan

## Objective

The only completion objective is **entering Cosmic Ocean**. A valid seed must
provide a reachable route to all of the following:

- `TABLET_OF_DESTINY` (to identify the correct Ushabti and obtain Qilin)
- `HOU_YIS_BOW` (Moon Challenge)
- `ARROW_OF_LIGHT` (Sun Challenge)

## Additional shuffle-pool items

Add these utility/combat items to the randomized item pool. They are optional:
the current intended logic does not require any of them to reach
`VICTORY_COSMIC_OCEAN`.

- `REWARD_CLIMBING_GLOVES`
- `REWARD_SPRING_SHOES`
- `REWARD_TELEPORTER`
- `REWARD_POWERPACK`
- `REWARD_HOVERPACK`
- `REWARD_FREEZE_RAY`
- `REWARD_SHOTGUN`
- `REWARD_SPECTACLES`
- `REWARD_TELEPACK`
- `REWARD_MATTOCK`

## Check catalogue

This is the source of truth for placement and reachability. It has three ID
namespaces:

- `LOCATION_*`: an area or sub-area in the world graph.
- `CHECK_*`: a named encounter, challenge, or reward location.
- `REWARD_*`: the base-game reward at a check, and the inventory state used by
  requirements.

### Locations

The two route pairs are mutually exclusive: `LOCATION_JUNGLE` /
`LOCATION_VOLCANA`, and `LOCATION_TIDE_POOL` / `LOCATION_TEMPLE`.

| Location ID | Parent location ID(s) | Requirements |
|---|---|---|
| `LOCATION_DWELLING` | `NONE` | [] |
| `LOCATION_JUNGLE` | `LOCATION_DWELLING` | [] |
| `LOCATION_VOLCANA` | `LOCATION_DWELLING` | [] |
| `LOCATION_OLMEC` | `LOCATION_JUNGLE` or `LOCATION_VOLCANA` | [] |
| `LOCATION_TIDE_POOL` | `LOCATION_OLMEC` | [] |
| `LOCATION_TEMPLE` | `LOCATION_OLMEC` | [] |
| `LOCATION_ABZU` | `LOCATION_TIDE_POOL` | [`REWARD_ANKH`] |
| `LOCATION_CITY_OF_GOLD` | `LOCATION_TEMPLE` | [`REWARD_SCEPTER`, `REWARD_HEDJET` or `REWARD_CROWN`] |
| `LOCATION_DUAT` | `LOCATION_CITY_OF_GOLD` | [`REWARD_ANKH`] |
| `LOCATION_ICE_CAVES` | `LOCATION_TIDE_POOL`, `LOCATION_TEMPLE`, `LOCATION_ABZU`, or `LOCATION_DUAT` | [] |
| `LOCATION_NEO_BABYLON` | `LOCATION_ICE_CAVES` | [`REWARD_TABLET_OF_DESTINY`] |
| `LOCATION_TIAMAT` | `LOCATION_NEO_BABYLON` | [] |
| `LOCATION_SUNKEN_CITY` | `LOCATION_TIAMAT` | [] |
| `LOCATION_EGGPLANT_WORLD` | `LOCATION_SUNKEN_CITY` | [`REWARD_EGGPLANT`] |
| `LOCATION_HUNDUN` | `LOCATION_SUNKEN_CITY` | [] |
| `LOCATION_NONE` | `NONE` | [] |

### Checks

Requirements are ID-only lists. An empty list (`[]`) has no requirements; the
check's `Location ID` supplies its world access. `Layer` controls where the
randomized reward may be materialized: `FOREGROUND`, `BACKGROUND`, `EITHER`,
or `NONE` for an abstract/non-spatial check.

| Check ID | Location ID | Layer | Requirements | Base-game reward ID |
|---|---|---|---|---|
| `CHECK_UDJAT_CHEST` | `LOCATION_DWELLING` | `BACKGROUND` | `[]` | `REWARD_UDJAT_EYE` |
| `CHECK_YANG` | `LOCATION_DWELLING` | `BACKGROUND` | `[]` | `NONE` |
| `CHECK_QUILLBACK` | `LOCATION_DWELLING` | `FOREGROUND` | `[]` | `REWARD_BOMB_BAG` |
| `CHECK_BLACK_MARKET` | `LOCATION_JUNGLE` | `BACKGROUND` | [`REWARD_UDJAT_EYE`] | `REWARD_HEDJET` |
| `CHECK_SISTERS_OLMEC_REWARD` | `LOCATION_JUNGLE` -> `LOCATION_OLMEC` | `FOREGROUND` | [] | `REWARD_BOMB_BOX` |
| `CHECK_VAN_HORSING_RESCUE` | `LOCATION_VOLCANA` | `BACKGROUND` | [] | `REWARD_DIAMOND` |
| `CHECK_VLADS_CASTLE` | `LOCATION_VOLCANA` | `BACKGROUND` | [`REWARD_UDJAT_EYE`] | `REWARD_CROWN` |
| `CHECK_VLAD` | `LOCATION_VOLCANA` | `BACKGROUND` | [`REWARD_UDJAT_EYE`] | `REWARD_VLADS_CAPE` |
| `CHECK_MOON_CHALLENGE_JUNGLE` | `LOCATION_JUNGLE` | `BACKGROUND` | [] | `REWARD_HOU_YIS_BOW` |
| `CHECK_MOON_CHALLENGE_VOLCANA` | `LOCATION_VOLCANA` | `BACKGROUND` | [] | `REWARD_HOU_YIS_BOW` |
| `CHECK_OLMEC_ANKH` | `LOCATION_OLMEC` | `BACKGROUND` | [] | `REWARD_ANKH` |
| `CHECK_TUSK_DICE_HOUSE` | `LOCATION_TIDE_POOL` | `BACKGROUND` | [] | `NONE` |
| `CHECK_HUMPHEAD_CAVE_IDOL` | `LOCATION_TIDE_POOL` | `BACKGROUND` | [] | `REWARD_IDOL` |
| `CHECK_EXCALIBUR_STONE` | `LOCATION_TIDE_POOL` | `FOREGROUND` | [`REWARD_HEDJET` or `REWARD_CROWN`] | `REWARD_EXCALIBUR` |
| `CHECK_TUSK_IDOL` | `LOCATION_TIDE_POOL` | `BACKGROUND` | [`REWARD_SKELETON_KEY`] | `REWARD_TUSK_IDOL` |
| `CHECK_KINGU` | `LOCATION_ABZU` | `FOREGROUND` | [`REWARD_EXCALIBUR`] | `REWARD_TABLET_OF_DESTINY` |
| `CHECK_ANUBIS_SCEPTER` | `LOCATION_TEMPLE` | `FOREGROUND` | [] | `REWARD_SCEPTER` |
| `CHECK_ALIEN_COMPASS` | `LOCATION_TEMPLE` | `BACKGROUND` | [`CHECK_VAN_HORSING_RESCUE`, `CHECK_VLAD`] | `REWARD_ALIEN_COMPASS` |
| `CHECK_OSIRIS` | `LOCATION_DUAT` | `BACKGROUND` | [] | `REWARD_TABLET_OF_DESTINY` |
| `CHECK_ANUBIS_II` | `LOCATION_DUAT` | `BACKGROUND` | [] | `REWARD_JETPACK` |
| `CHECK_STARS_CHALLENGE_TIDE_POOL` | `LOCATION_TIDE_POOL` | `BACKGROUND` | [] | `REWARD_CLONE_GUN` |
| `CHECK_STARS_CHALLENGE_TEMPLE` | `LOCATION_TEMPLE` | `BACKGROUND` | [] | `REWARD_ELIXIR` |
| `CHECK_YETI_QUEEN` | `LOCATION_ICE_CAVES` | `BACKGROUND` | [] | `REWARD_SPIKE_SHOES` |
| `CHECK_YETI_KING` | `LOCATION_ICE_CAVES` | `BACKGROUND` | [] | `REWARD_COMPASS` |
| `CHECK_LAHAMU` | `LOCATION_ICE_CAVES` | `BACKGROUND` | [`REWARD_ALIEN_COMPASS`] | `NONE` |
| `CHECK_MOTHERSHIP_PLASMA_CANNON` | `LOCATION_ICE_CAVES` | `BACKGROUND` | [`REWARD_ALIEN_COMPASS`] | `REWARD_PLASMA_CANNON` |
| `CHECK_TUSK_PALACE_VISIT` | `LOCATION_NEO_BABYLON` | `BACKGROUND` | [`CHECK_TUSK_DICE_HOUSE`] | `REWARD_ROYAL_JELLY` |
| `CHECK_SPARROW_VAULT` | `LOCATION_NEO_BABYLON` | `BACKGROUND` | [] | `REWARD_PLAYER_BAG_ROPES` |
| `CHECK_TIAMAT` | `LOCATION_TIAMAT` | `FOREGROUND` | [] | `NONE` |
| `CHECK_SUN_CHALLENGE` | `LOCATION_SUNKEN_CITY` | `BACKGROUND` | [] | `REWARD_ARROW_OF_LIGHT` |
| `CHECK_EGGPLANT_KING` | `LOCATION_EGGPLANT_WORLD` | `FOREGROUND` | [] | `REWARD_EGGPLANT_CROWN` |
| `CHECK_SPARROW` | `LOCATION_NONE` | `NONE` | [] | `REWARD_ROPE_PILE` |
| `CHECK_HUMPHEAD` | `LOCATION_TIDE_POOL` | `FOREGROUND` | [] | `REWARD_EGGPLANT` |
| `CHECK_KALI_ALTAR_1` | `LOCATION_NONE` | `FOREGROUND` | [] | `NONE` |
| `CHECK_KALI_PRESENT` | `LOCATION_NONE` | `FOREGROUND` | [] | `NONE` |
| `CHECK_KALI_ALTAR_2` | `LOCATION_NONE` | `FOREGROUND` | [`CHECK_KALI_ALTAR_1`] | `REWARD_KAPALA` |
| `CHECK_BEG_FIRST_MEETING` | `LOCATION_NONE` | `FOREGROUND` | [] | `REWARD_BOMB_BAG` |
| `CHECK_BEG_TRUE_CROWN` | `LOCATION_NONE` | `FOREGROUND` | [`CHECK_BEG_FIRST_MEETING`] | `REWARD_TRUE_CROWN` |

`LOCATION_ABZU` and `LOCATION_DUAT` each consume `REWARD_ANKH`. They are
mutually exclusive in a single intended-logic route unless the randomizer
deliberately places an additional Ankh.

`CHECK_KALI_PRESENT` is assigned a seed-stable target group (1 through 6).
The Present source is generated from the first pet on a level with a Kali altar
in that group or any later group. Its effective group is used by the item
placer, so required items are never assigned to this check earlier than the
source can appear.

### Scripted reward anchors

`CHECK_YANG` must not depend on the generated contents of Yang's treasure
room. In vanilla, the room can contain ordinary treasure, a chest, a crate, or
no useful item at all. When Yang's pen generates, create a fixed background
anchor in the treasure room and associate it with the run's assigned
`CHECK_YANG` reward. The assigned item is therefore always present in the room
and becomes normally obtainable when the player completes Yang's turkey event
and receives the key.

This is a check-specific spawn rule, not crate/chest-content randomization. It
must be persisted with the check mapping so the item does not duplicate after
a reload.

`CHECK_TUSK_DICE_HOUSE` uses the fifth and final Dice House prize as its
scripted anchor. Replace that prize with the check's assigned item, but do not
replace or model the VIP invitation: the base game grants it automatically
after the fifth successful prize. `CHECK_TUSK_PALACE_VISIT` therefore remains
unlocked by completion of `CHECK_TUSK_DICE_HOUSE`, not by an inventory reward.

## Victory condition

`VICTORY_COSMIC_OCEAN` is not a check and never receives a randomized reward.
It is satisfied at `LOCATION_HUNDUN` when the final reachable state contains:

```text
REWARD_TABLET_OF_DESTINY
REWARD_HOU_YIS_BOW
REWARD_ARROW_OF_LIGHT
```

## Placement and validation

1. Build a static table of named checks, each with its prerequisites and a
   reward slot. Do not assign items by entity-spawn order.
2. Place every deadline-bound key reward first. A key reward may use an unused
   compatible check from its group or an earlier group. Keys cannot be placed
   behind themselves or in an inaccessible branch.
3. Shuffle the fill pool and use only as many distinct fill rewards as remain
   necessary to fill the unassigned checks. Extra fill rewards are deliberately
   absent from that seed.
4. Run a fixed-point search from `LOCATION_DWELLING`:
   - enter locations whose parent route and requirements are satisfied;
   - visit checks whose location and requirements are satisfied;
   - add each placed reward and consume rewards required by a location gate;
   - repeat until no new state is reachable.
5. A seed is valid only when `VICTORY_COSMIC_OCEAN` is satisfied with
   `REWARD_TABLET_OF_DESTINY`, `REWARD_HOU_YIS_BOW`, and
   `REWARD_ARROW_OF_LIGHT` in the final state.
6. Validate every route independently: at least one route must reach Cosmic
   Ocean and every included check must be reachable on at least one route.

## Separate randomizer seed and stable mapping

The randomizer must have a seed that is **independent from Spelunky level
generation**. A game level seed determines room layouts and which optional
rooms physically generate; it must never determine which randomized item is at
a named check.

```text
new run
  -> choose/generate RandomizerSeed once
  -> build and validate the complete { check_id -> item_id } mapping once
  -> save RandomizerSeed, mapping, and logic-version
  -> materialize that mapping whenever its check appears in a level
```

- A nonzero `RandomizerSeed` always creates the same mapping for the same
  logic version and enabled item/location pools, regardless of game seed.
- Seed `0` generates a new `RandomizerSeed` once when starting a *new run*,
  displays it, and then persists it. It must not reroll on a level transition,
  reload, or death.
- Save the mapping itself, not only the seed, so an update to placement logic
  cannot change an in-progress run.
- Generate the full mapping before entering Dwelling. Runtime code should look
  up `mapping[check_id]`; it must not consume a shuffled item pool according to
  entity spawn order.
- A spoiler log and UI should display both `Game seed` and `Randomizer seed`.

This replaces the current behavior of rebuilding/shuffling the item pool during
level lifecycle callbacks. It also makes a shared randomizer seed suitable for
races even when participants use different level seeds.
