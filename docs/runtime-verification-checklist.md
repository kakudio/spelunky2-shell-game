# Runtime verification checklist

This is the procedure for testing check adapters in-game. It records no
results: those belong in the [verification ledger](verified-checks.md).

## Before a run

Run `kir_tests()` in the Overlunky console after installing a build. It runs
pure policy and lifecycle tests, fixed-seed determinism checks, mapping
uniqueness checks, and 100 generated victory-route validations.
`kir_tests(1000)` is the longer pre-release check.

Useful tools during a run:

- `kir_spoiler()` prints the randomizer seed, every check's mapped reward, and
  the Kali Present target group and placement.
- `kir_status()` prints the seed, logic version, level epoch, and any adapter
  failure.
- The run report (`kir_report_path()`) holds the seed, logic version, mapping,
  and mod log for the run, when **Generate Spoiler** and **Generate Logs** are
  enabled.
- The developer build's **Test Resources** option grants a debug loadout.

All delayed adapter work is level-epoch guarded. An adapter failure in
`kir_status()` means the native item was deliberately left untouched rather
than silently claiming the check. If an adapter fails, capture the lines
beginning `[ShellGame]` from the moment the level loads through the reward
appearing, and include the randomizer seed.

Two rules apply to every check:

- A shuffled item the player is carrying is never treated as a check's native
  source; the log says `Ignored player_carried source` if a scan sees it.
- A mapped Eggplant arrives inside a Present, so it survives drops and tosses.

## Final pass

One row per check in `logic.lua`'s `CHECK_GROUPS`, in rough route order, then
the run-level items. The two route pairs (Jungle/Volcana, Tide Pool/Temple)
need more than one run to cover.

Report each row by its ID, one per line, as
`<ID>: verified | failed | not reached — <note>`; for example
`CHECK_YANG: failed — reward spawned inside the wall`. Fill the Result column
in your own copy or report, not in this file; the ledger records the outcome.

| ID | Test | Expected result | Result |
|---|---|---|---|
| `CHECK_UDJAT_CHEST` | In Dwelling, open the Udjat Eye chest with its key. | The mapped reward appears in place of the Udjat Eye. | |
| `CHECK_YANG` | In Dwelling, find Yang's pen and complete his turkey event; note whether the reward could be taken before the pen opened. | The mapped reward is in the back layer one tile past Yang's locked pen door, on the side away from Yang. The log says `Yang reward anchor uses native locked pen`. | |
| `CHECK_QUILLBACK` | Kill Quillback. | His Bomb Bag drop is replaced by the mapped reward. | |
| `CHECK_BLACK_MARKET` | Reach the Black Market in Jungle and buy the Hedjet slot. | The slot holds the mapped reward as a purchasable item owned by the native Shopkeeper; the log says `CHECK CHECK_BLACK_MARKET -> ... owned by native Shopkeeper`. | |
| `CHECK_QUEEN_BEE` | Kill Queen Bee. | Her Royal Jelly drop is replaced by the mapped reward, which is never a key item; the log says `Queen Bee reward observed: mapped reward`. | |
| `CHECK_SISTERS_OLMEC_REWARD` | Rescue all three Sisters, then reach Olmec. | The Sisters' Bomb Box reward at Olmec is replaced by the mapped reward. | |
| `CHECK_VAN_HORSING_RESCUE` | In Volcana, free Van Horsing. | His Diamond reward is replaced by the mapped reward. | |
| `CHECK_VLADS_CASTLE` | Enter Vlad's Castle in Volcana. | The Crown in the statue is replaced by the mapped reward, resting on the ground in the back layer rather than inside the statue. | |
| `CHECK_VLAD` | Kill Vlad. | His Cape drop is replaced by the mapped reward. | |
| `CHECK_MOON_CHALLENGE_JUNGLE` | Complete the Jungle Moon Challenge and collect the reward. | The native Bow is hidden and its arrow removed; the mapped reward sits at the Bow's location and can be collected after the challenge without a crash. | |
| `CHECK_MOON_CHALLENGE_VOLCANA` | Complete the Volcana Moon Challenge; on another visit, enter carrying a Bow. | As for Jungle; a carried Bow stays unchanged and the log says `Moon Challenge ignored player-carried Bow`. | |
| `CHECK_OLMEC_ANKH` | Defeat Olmec. | His Ankh reward is replaced by the mapped reward. | |
| `CHECK_KALI_ALTAR_1` | Earn Kali's first normal gift; then die, start a new run on the same seed, and earn it again. | The first gift is the mapped reward on both runs, with no extra native gift left at the altar; the log says `Kali first-gift candidate`. | |
| `CHECK_KALI_PRESENT` | Read the target group from `kir_spoiler()`; on the first level at or after it with a Kali altar and a pet, sacrifice the Present at the altar. | The pet becomes one Present (a shop item if the pet was for sale). Sacrificing it produces the mapped reward at the altar, and Kali's first normal gift is still available afterwards. | |
| `CHECK_BEG_FIRST_MEETING` | Complete Beg's first meeting. | His Bomb Bag reward is replaced by the mapped reward. | |
| `CHECK_SPARROW` | Complete Sparrow's first meeting. | Her Rope Pile reward is replaced by the mapped reward. | |
| `CHECK_TUSK_DICE_HOUSE` | Win all five prizes at Tusk's Dice House. | The first four prizes are vanilla; only the fifth is the mapped reward, and the VIP invitation is still granted. | |
| `CHECK_HUMPHEAD_CAVE_IDOL` | In Tide Pool 4-2, enter Great Humphead's cave. | The cave's Golden Idol is replaced by the mapped reward in the back layer. | |
| `CHECK_EXCALIBUR_STONE` | Reach Tide Pool 4-2 with a Crown or Hedjet; on another visit, enter holding Excalibur. | The sword-in-stone is replaced by the mapped reward. Without a Crown or Hedjet the log says `Excalibur gate is closed` and the sword stays native; a carried Excalibur stays unchanged. | |
| `CHECK_TUSK_IDOL` | In Tide Pool 4-1, open Tusk's Idol room. | Tusk's Idol is replaced by the mapped reward at the Idol's position. | |
| `CHECK_ANUBIS_SCEPTER` | In Temple, kill Anubis. | His Scepter drop is replaced by the mapped reward. | |
| `CHECK_ALIEN_COMPASS` | After rescuing Van Horsing and killing Vlad, meet Van Horsing in Temple. | His Alien Compass reward is replaced by the mapped reward. | |
| `CHECK_STARS_CHALLENGE_TIDE_POOL` | Complete the Tide Pool Stars Challenge. | Its Clone Gun reward is replaced by the mapped reward. | |
| `CHECK_STARS_CHALLENGE_TEMPLE` | Complete the Temple Stars Challenge. | Its Elixir reward is replaced by the mapped reward. | |
| `CHECK_HUMPHEAD` | Kill Humphead. | No crash; the native Camera and Hired Hand remain, and only the Present becomes the mapped reward. The log says `Humphead native Present replaced`. | |
| `CHECK_YETI_QUEEN` | In Ice Caves, kill the Yeti Queen. | Her Spike Shoes drop is replaced by the mapped reward. | |
| `CHECK_YETI_KING` | In Ice Caves, kill the Yeti King. | His Compass drop is replaced by the mapped reward. | |
| `CHECK_KINGU` | In Abzu, defeat Kingu. | His Tablet drop is replaced by the mapped reward. | |
| `CHECK_OSIRIS` | In Duat, defeat Osiris. | His Tablet drop is replaced by the mapped reward. | |
| `CHECK_ANUBIS_II` | In Duat, kill Anubis II. | His Jetpack drop is replaced by the mapped reward. | |
| `CHECK_LAHAMU` | In the Mothership, defeat Lahamu. | The mapped reward appears at Lahamu's death position, and the forcefields still disable normally. | |
| `CHECK_MOTHERSHIP_PLASMA_CANNON` | Reach the Mothership's back layer in Ice Caves. | Only its back-layer Plasma Cannon is replaced by the mapped reward. | |
| `CHECK_TUSK_PALACE_VISIT` | Visit Tusk's Palace in Neo Babylon 6-3. | Its back-layer Royal Jelly is replaced by the mapped reward. | |
| `CHECK_SPARROW_VAULT` | In Neo Babylon 6-3, open exactly four vault chests, then speak to Sparrow. | Her Player Bag is replaced by the mapped reward, visible, one tile left of where the bag would appear. | |
| `CHECK_KALI_ALTAR_2` | Keep gaining Kali favor until she gives the Kapala. | The Kapala is replaced by the mapped reward, once per run. | |
| `CHECK_BEG_TRUE_CROWN` | Complete Beg's True Crown encounter. | His True Crown reward is replaced by the mapped reward. | |
| `CHECK_TIAMAT` | Defeat Tiamat. | The mapped reward appears at her death position. | |
| `CHECK_SUN_CHALLENGE` | Complete the Sun Challenge. | Its Arrow of Light reward is replaced by the mapped reward. | |
| `CHECK_SUN_CHALLENGE_SUPPLIES` | Complete the Sun Challenge. | Its separate supplies Player Bag is replaced by the mapped reward, independently of the Arrow of Light reward. | |
| `CHECK_EGGPLANT_KING` | In Eggplant World, defeat Yama. | His Eggplant Crown drop is replaced by the mapped reward. | |
| `RUN_SAVE_RELOAD` | Leave a mapped reward uncollected on the ground, save and quit, then reload. | The reward is still there, once: it neither vanishes nor duplicates. | |
| `RUN_DUAT_ALTAR_COPIES` | With **Kali Item Recovery** on, leave a back item and a durable tool (for example Excalibur or a Shotgun) lying just above the City of Gold Kali altar, not held, and enter Duat. | A copy of each appears on the Duat altar; the log says `Duat recovery restored`. The Ankh used to enter stays consumed. | |
| `RUN_TRUE_CROWN_RECOVERY` | With **True Crown Restoration** on, complete Beg's True Crown encounter while cursed and below 4 HP; repeat while uncursed. | Cursed: the curse is removed and HP is at least 4; the log says `Beg True Crown quest completion detected`. Uncursed: health is unchanged. | |
