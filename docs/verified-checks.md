# Check verification ledger

Last updated: 2026-07-31

Status is intentionally based on observed in-game behavior, not merely on the
presence of an adapter in code. A fresh logic-version change requires a new
run before treating a previous result as current.

## Verified working in-game

| Check | What was verified |
|---|---|
| `CHECK_UDJAT_CHEST` | The native Udjat Eye spawn is replaced by the mapped reward. |
| `CHECK_YANG` | The mapped reward is placed at Yang's back-layer reward-door anchor. |
| `CHECK_QUILLBACK` | Quillback's native Bomb Bag drop is replaced after his death. |
| `CHECK_MOON_CHALLENGE_JUNGLE` / `CHECK_MOON_CHALLENGE_VOLCANA` | The native Bow is safely hidden, its arrow removed, and the mapped reward can be collected after challenge completion. |
| `CHECK_VLADS_CASTLE` | The Castle reward is replaced in the intended back-layer area. |
| `CHECK_VLAD` | Vlad's death reward is replaced. |
| `CHECK_VAN_HORSING_RESCUE` | Van Horsing's rescue reward is replaced. |
| `CHECK_TUSK_DICE_HOUSE` | The fifth/final Dice House prize is replaced. |
| `CHECK_SISTERS_OLMEC_REWARD` | The combined Sisters reward at Olmec is replaced. |
| `CHECK_OLMEC_ANKH` | Olmec's native Ankh reward is replaced. |
| `CHECK_EXCALIBUR_STONE` | With collected Crown/Hedjet progression, the late-spawned sword-in-stone is replaced by the mapped reward. |
| `CHECK_BEG_FIRST_MEETING` | Beg's first-meeting Bomb Bag reward is replaced by the mapped reward. |
| `CHECK_KALI_PRESENT` | Earlier implementation: sacrificing a Present at a Kali altar produced the mapped reward. The new dog-to-Present source needs re-verification. |
| `CHECK_TUSK_IDOL` | Tusk's Idol is replaced by the mapped reward at its intended room anchor. |
| `CHECK_SPARROW` | Sparrow's Rope Pile reward is replaced by the mapped reward. |
| `CHECK_KINGU` | Kingu's Tablet drop is replaced by the mapped reward on defeat. |
| `CHECK_STARS_CHALLENGE_TIDE_POOL` | The Tide Pool Stars Challenge reward is replaced by the mapped reward. |
| `CHECK_HUMPHEAD` | Humphead's present is replaced by the mapped reward on defeat. |
| `CHECK_YETI_QUEEN` / `CHECK_YETI_KING` | Each Yeti royal reward is replaced by its mapped reward. |

## Adapter fired; needs a final player-facing confirmation

| Check | Evidence to date | Remaining check |
|---|---|---|
| `CHECK_KALI_ALTAR_1` | Logs show a mapped item materialized after the first gift. | Confirm that only the mapped item remains and no vanilla first-gift item survives. |

## Implemented, not yet verified in-game

| Check(s) | Test to perform |
|---|---|
| `CHECK_TUSK_PALACE_VISIT`, `CHECK_SPARROW_VAULT` | Exercise each Neo Babylon 6-3 quest step. For Sparrow, open exactly four vault chests and speak to her; only her completion Player Bag should change. |
| `CHECK_HUMPHEAD_CAVE_IDOL` | Enter Great Humphead's Tide Pool 4-2 cave and verify its back-layer Idol is replaced by the mapped reward. |
| `CHECK_ANUBIS_SCEPTER`, `CHECK_ALIEN_COMPASS`, `CHECK_STARS_CHALLENGE_TEMPLE` | Defeat Anubis and enter the Temple Stars Challenge/Van route. |
| `CHECK_OSIRIS`, `CHECK_ANUBIS_II` | Defeat Osiris and Anubis II in Duat. |
| `CHECK_EGGPLANT_KING` | Complete the Eggplant chain and defeat Yama; his native Eggplant Crown should be replaced. Moai remains a vanilla interaction, not a randomizer check. |
| `CHECK_LAHAMU`, `CHECK_MOTHERSHIP_PLASMA_CANNON` | Visit the Mothership route, defeat Lahamu, and verify the back-layer Plasma Cannon. |
| `CHECK_TIAMAT`, `CHECK_SUN_CHALLENGE` | Defeat Tiamat and complete the Sun Challenge. |
| `CHECK_KALI_ALTAR_2`, `CHECK_BEG_TRUE_CROWN` | Complete their dialogue/action events. |

## Run-level verification

- `kir_fuzz(1000, 1)` must pass after every logic change.
- `kir_validate(seed)` must report a victory route for each selected seed.
- `kir_spoiler()` must remain stable for the same non-zero randomizer seed.
- Save/quit/reload with an uncollected mapped item still on the ground; verify
  it neither vanishes nor duplicates.
