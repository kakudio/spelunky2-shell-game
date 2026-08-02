# Check verification ledger

Last updated: 2026-08-01

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
| `CHECK_MOTHERSHIP_PLASMA_CANNON` | The Mothership's back-layer Plasma Cannon is replaced by the mapped reward. |
| `CHECK_LAHAMU` | Lahamu's reward is replaced by the mapped reward on defeat. |
| `CHECK_BEG_TRUE_CROWN` | Beg's True Crown reward is replaced by the mapped reward. |
| `CHECK_KALI_ALTAR_2` | Kali's second reward is replaced by the mapped reward. |
| `CHECK_ANUBIS_SCEPTER` | Anubis's Scepter drop is replaced by the mapped reward on defeat. |
| `CHECK_TUSK_PALACE_VISIT` | Tusk's Palace reward is replaced by the mapped reward. |
| `CHECK_HUMPHEAD_CAVE_IDOL` | Great Humphead's cave Idol is replaced by the mapped reward. |
| `CHECK_STARS_CHALLENGE_TEMPLE` | The Temple Stars Challenge reward is replaced by the mapped reward. |
| `CHECK_OSIRIS` | Osiris's Tablet drop is replaced by the mapped reward on defeat. |
| `CHECK_TIAMAT` | Tiamat's reward is replaced by the mapped reward on defeat. |
| `CHECK_ANUBIS_II` | Anubis II's reward is replaced by the mapped reward on defeat. |
| `CHECK_ALIEN_COMPASS` | Van Horsing's Alien Compass reward is replaced by the mapped reward. |

## Known regression

| Check | Status |
|---|---|
| `CHECK_KALI_ALTAR_1` | Previously verified, but currently reported as buggy; needs diagnosis and a fresh in-game verification. |

## Implemented, not yet verified in-game

| Check(s) | Test to perform |
|---|---|
| `CHECK_SPARROW_VAULT` | Open exactly four vault chests and speak to Sparrow; only her completion Player Bag should change. |
| `CHECK_EGGPLANT_KING` | Complete the Eggplant chain and defeat Yama; his native Eggplant Crown should be replaced. Moai remains a vanilla interaction, not a randomizer check. |
| `CHECK_SUN_CHALLENGE` | Complete the Sun Challenge and verify its mapped reward. |

## Run-level verification

- `kir_fuzz(1000, 1)` must pass after every logic change.
- `kir_validate(seed)` must report a victory route for each selected seed.
- `kir_spoiler()` must remain stable for the same non-zero randomizer seed.
- Save/quit/reload with an uncollected mapped item still on the ground; verify
  it neither vanishes nor duplicates.
- Enter Duat while holding an item and wearing a back item; verify both copies
  appear on Duat's Kali altar, while the Ankh remains consumed.
- If the City of Gold self-sacrifice triggers a Kali check reward, verify that
  mapped reward is also placed on Duat's Kali altar, even with Duat Item
  Recovery disabled.
- Complete Beg's True Crown check while cursed; verify the player is cured and
  restored to at least 4 HP, while uncursed players' health is unchanged.
