# Check verification ledger

This ledger is the only place that records whether a check works in-game.
Other documents describe how checks are built and tested, and link here for
results.

## Rules

- A result is an observation from a real in-game run, not the presence of an
  adapter in code.
- A change to a check's adapter requires a new in-game run before that check's
  previous result counts again.
- A logic-version change alone does not demote a check.
- `kir_fuzz(1000, 1)` and `kir_validate(seed)` remain required after every
  logic change.

Each row is either **verified** or **not yet verified**. Statuses come from
the final pass in the
[runtime verification checklist](runtime-verification-checklist.md#final-pass):
exactly the rows the tester ticked on the pull request are verified, with the
session date and the row's expected result as what was observed. Every other
row is not yet verified.

Adapters changed after the previous in-game pass (2026-08-04), so none of its
observations are carried forward.

## Checks

| Check | Status | Verified on | Observed |
|---|---|---|---|
| `CHECK_UDJAT_CHEST` | Not yet verified | | |
| `CHECK_YANG` | Not yet verified | | |
| `CHECK_QUILLBACK` | Not yet verified | | |
| `CHECK_BLACK_MARKET` | Not yet verified | | |
| `CHECK_QUEEN_BEE` | Not yet verified | | |
| `CHECK_SISTERS_OLMEC_REWARD` | Not yet verified | | |
| `CHECK_VAN_HORSING_RESCUE` | Not yet verified | | |
| `CHECK_VLADS_CASTLE` | Not yet verified | | |
| `CHECK_VLAD` | Not yet verified | | |
| `CHECK_MOON_CHALLENGE_JUNGLE` | Not yet verified | | |
| `CHECK_MOON_CHALLENGE_VOLCANA` | Not yet verified | | |
| `CHECK_OLMEC_ANKH` | Not yet verified | | |
| `CHECK_KALI_ALTAR_1` | Not yet verified | | |
| `CHECK_KALI_PRESENT` | Not yet verified | | |
| `CHECK_BEG_FIRST_MEETING` | Not yet verified | | |
| `CHECK_SPARROW` | Not yet verified | | |
| `CHECK_TUSK_DICE_HOUSE` | Not yet verified | | |
| `CHECK_HUMPHEAD_CAVE_IDOL` | Not yet verified | | |
| `CHECK_EXCALIBUR_STONE` | Not yet verified | | |
| `CHECK_TUSK_IDOL` | Not yet verified | | |
| `CHECK_ANUBIS_SCEPTER` | Not yet verified | | |
| `CHECK_ALIEN_COMPASS` | Not yet verified | | |
| `CHECK_STARS_CHALLENGE_TIDE_POOL` | Not yet verified | | |
| `CHECK_STARS_CHALLENGE_TEMPLE` | Not yet verified | | |
| `CHECK_HUMPHEAD` | Not yet verified | | |
| `CHECK_YETI_QUEEN` | Not yet verified | | |
| `CHECK_YETI_KING` | Not yet verified | | |
| `CHECK_KINGU` | Not yet verified | | |
| `CHECK_OSIRIS` | Not yet verified | | |
| `CHECK_ANUBIS_II` | Not yet verified | | |
| `CHECK_LAHAMU` | Not yet verified | | |
| `CHECK_MOTHERSHIP_PLASMA_CANNON` | Not yet verified | | |
| `CHECK_TUSK_PALACE_VISIT` | Not yet verified | | |
| `CHECK_SPARROW_VAULT` | Not yet verified | | |
| `CHECK_KALI_ALTAR_2` | Not yet verified | | |
| `CHECK_BEG_TRUE_CROWN` | Not yet verified | | |
| `CHECK_TIAMAT` | Not yet verified | | |
| `CHECK_SUN_CHALLENGE` | Not yet verified | | |
| `CHECK_SUN_CHALLENGE_SUPPLIES` | Not yet verified | | |
| `CHECK_EGGPLANT_KING` | Not yet verified | | |

## Run-level items

| Item | Status | Verified on | Observed |
|---|---|---|---|
| `RUN_SAVE_RELOAD` | Not yet verified | | |
| `RUN_DUAT_ALTAR_COPIES` | Not yet verified | | |
| `RUN_TRUE_CROWN_RECOVERY` | Not yet verified | | |
