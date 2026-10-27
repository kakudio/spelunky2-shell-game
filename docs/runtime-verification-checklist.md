# Runtime verification checklist

Run `kir_tests()` in the Overlunky console after installing a build. It runs
pure policy and lifecycle tests, fixed-seed determinism checks, mapping
uniqueness checks, and 100 generated victory-route validations.
`kir_tests(1000)` is the longer pre-release check.

All delayed adapter work is level-epoch guarded. If `kir_status` reports an
adapter failure, capture that output with the normal randomizer log; a failure
means the native item was deliberately left untouched rather than silently
claiming the check succeeded.

The following adapters also need one in-game test whenever their code changes:

| Adapter | Action | Expected result / log |
| --- | --- | --- |
| Player-owned source guard | Carry a shuffled item through a route transition. | The item remains owned; console says `Ignored player_carried source` only if a scan sees it. |
| Moon Challenge | Enter Jungle or Volcana Moon Challenge; also enter Volcana carrying a Bow. | Native back-layer Bow is replaced; a carried foreground Bow remains unchanged. |
| Excalibur Stone | Reach Tide Pool 4-2 wearing a Hedjet from a randomized reward; repeat with a Crown, and with the developer test resources' Crown. Also put one on partway through 4-2, and arrive wearing neither. Carry Excalibur in once. | Wearing either on arrival, or once one is put on in 4-2, the stone becomes its mapped reward; wearing neither, it stays native and `Excalibur gate is closed` is logged; a carried Excalibur remains untouched. |
| Kali Altar 1 | Earn Kali's first normal reward, die, then repeat on a new run. | The check rewards on both runs; log includes `Kali first-gift candidate`. |
| Kali Present | Read its target group in `kir_spoiler()`, then find the first level at or after that group with both Kali and a pet. | The pet becomes a Present once; its mapped reward appears at the altar. |
| Kali Altar 2 | Earn Kapala. | `DROP.ALTAR_KAPALA` is replaced by the mapped reward. |
| Sun Challenge supplies | Complete the Sun Challenge. | Its separate supplies Player Bag is replaced by the mapped reward; the Arrow of Light reward remains independent. |
| Humphead | Kill Humphead. | No crash; the native Camera and Hired Hand remain, while only the Present becomes the mapped reward; log includes `Humphead native Present replaced`. |
| Quillback | Kill Quillback with a seed mapping it to Eggplant. | Eggplant is placed directly into the active player's hands rather than breaking as a drop. |
| DROP-table Eggplant | Test a DROP-table reward (for example Kingu) mapped to Eggplant. | Confirm its game-specific adapter; no global Eggplant listener is used, since unrelated native Eggplants must remain untouched. |
| Black Market | Reach the Black Market and buy the Hedjet slot. | The mapped reward remains a purchasable shop item. |
| Tusk Dice House | Win the fifth prize, then take whatever the dispenser offers next. | Only the fifth prize is replaced. In the run report, `Dice House item #1`–`#4` each say `left native: prize count is N, not 4`, and `Dice House prize count N -> N+1` follows each win. `Dice House item #5 … (prize count 4) replaced with <reward>` names the native prize it replaced, beside `CHECK CHECK_TUSK_DICE_HOUSE -> <reward>`. Anything staged after it (a sixth prize, the VIP invitation) is logged as `item #6`+ with `already materialized`. If item #5 is logged at another count, or a later item is the one replaced, the staging model is wrong. |
| Mothership Plasma Cannon | Reach the Ice Caves Mothership back layer. | Only its back-layer Plasma Cannon is replaced. |
| Lahamu | Defeat Lahamu in the Mothership. | The mapped reward appears at Lahamu's death position; forcefields still disable normally. |
| True Crown recovery | Complete Beg's True Crown check while cursed and below four health; repeat while uncursed. | A cursed player is cured and restored to at least 4 HP; uncursed players' health is unchanged. |
| Tusk Palace | Visit Tusk's Palace in Neo Babylon 6-3. | Its back-layer Royal Jelly is the mapped reward. |
| Sparrow Vault | Open exactly four vault chests in Neo Babylon 6-3, then speak to Sparrow. | Her quest-completion Player Bag is the mapped reward. |
| Eggplant King | Defeat Yama in Eggplant World. | The Eggplant Crown death drop is replaced with the mapped reward. |

If an adapter fails, capture the lines beginning `[ShellGame]` from
the moment the level loads through the reward appearing. Include the randomizer
seed shown by `kir_spoiler()`.
