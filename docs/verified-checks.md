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

Results come from the final pass in the
[runtime verification checklist](runtime-verification-checklist.md#final-pass).
Each result is one of **verified**, **failed**, or **not reached**, with the
date of the run and the tester's note. **Pending** means the check has no
result on the current adapters.

Adapters changed after the previous in-game pass (2026-08-04), so none of its
observations are carried forward.

## Checks

| Check | Result | Run date | Note |
|---|---|---|---|
| `CHECK_UDJAT_CHEST` | Pending | | |
| `CHECK_YANG` | Pending | | |
| `CHECK_QUILLBACK` | Pending | | |
| `CHECK_BLACK_MARKET` | Pending | | |
| `CHECK_QUEEN_BEE` | Pending | | |
| `CHECK_SISTERS_OLMEC_REWARD` | Pending | | |
| `CHECK_VAN_HORSING_RESCUE` | Pending | | |
| `CHECK_VLADS_CASTLE` | Pending | | |
| `CHECK_VLAD` | Pending | | |
| `CHECK_MOON_CHALLENGE_JUNGLE` | Pending | | |
| `CHECK_MOON_CHALLENGE_VOLCANA` | Pending | | |
| `CHECK_OLMEC_ANKH` | Pending | | |
| `CHECK_KALI_ALTAR_1` | Pending | | |
| `CHECK_KALI_PRESENT` | Pending | | |
| `CHECK_BEG_FIRST_MEETING` | Pending | | |
| `CHECK_SPARROW` | Pending | | |
| `CHECK_TUSK_DICE_HOUSE` | Pending | | |
| `CHECK_HUMPHEAD_CAVE_IDOL` | Pending | | |
| `CHECK_EXCALIBUR_STONE` | Pending | | |
| `CHECK_TUSK_IDOL` | Pending | | |
| `CHECK_ANUBIS_SCEPTER` | Pending | | |
| `CHECK_ALIEN_COMPASS` | Pending | | |
| `CHECK_STARS_CHALLENGE_TIDE_POOL` | Pending | | |
| `CHECK_STARS_CHALLENGE_TEMPLE` | Pending | | |
| `CHECK_HUMPHEAD` | Pending | | |
| `CHECK_YETI_QUEEN` | Pending | | |
| `CHECK_YETI_KING` | Pending | | |
| `CHECK_KINGU` | Pending | | |
| `CHECK_OSIRIS` | Pending | | |
| `CHECK_ANUBIS_II` | Pending | | |
| `CHECK_LAHAMU` | Pending | | |
| `CHECK_MOTHERSHIP_PLASMA_CANNON` | Pending | | |
| `CHECK_TUSK_PALACE_VISIT` | Pending | | |
| `CHECK_SPARROW_VAULT` | Pending | | |
| `CHECK_KALI_ALTAR_2` | Pending | | |
| `CHECK_BEG_TRUE_CROWN` | Pending | | |
| `CHECK_TIAMAT` | Pending | | |
| `CHECK_SUN_CHALLENGE` | Pending | | |
| `CHECK_SUN_CHALLENGE_SUPPLIES` | Pending | | |
| `CHECK_EGGPLANT_KING` | Pending | | |

## Run-level items

| Item | Result | Run date | Note |
|---|---|---|---|
| `RUN_SAVE_RELOAD` | Pending | | |
| `RUN_DUAT_ALTAR_COPIES` | Pending | | |
| `RUN_TRUE_CROWN_RECOVERY` | Pending | | |
