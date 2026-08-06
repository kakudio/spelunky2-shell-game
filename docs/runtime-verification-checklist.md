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
| Excalibur Stone | Visit Tide Pool with Crown/Hedjet, then enter Tide Pool holding Excalibur. | Stone reward is shuffled; carried Excalibur remains untouched. |
| Kali Altar 1 | Earn Kali's first normal reward, die, then repeat on a new run. | The check rewards on both runs; log includes `Kali first-gift candidate`. |
| Kali Present | Read its target group in `kir_spoiler()`, then find the first level at or after that group with both Kali and a pet. | The pet becomes a Present once; its mapped reward appears at the altar. |
| Kali Altar 2 | Earn Kapala. | `DROP.ALTAR_KAPALA` is replaced by the mapped reward. |
| Sun Challenge supplies | Complete the Sun Challenge. | Its separate supplies Player Bag is replaced by the mapped reward; the Arrow of Light reward remains independent. |
| Humphead | Kill Humphead. | No crash; the native Camera and Hired Hand remain, while only the Present becomes the mapped reward; log includes `Humphead native Present replaced`. |
| Quillback | Kill Quillback with a seed mapping it to Eggplant. | Eggplant is placed directly into the active player's hands rather than breaking as a drop. |
| DROP-table Eggplant | Test a DROP-table reward (for example Kingu) mapped to Eggplant. | Confirm its game-specific adapter; no global Eggplant listener is used, since unrelated native Eggplants must remain untouched. |
| Black Market | Reach the Black Market and buy the Hedjet slot. | The mapped reward remains a purchasable shop item. |
| Tusk Dice House | Win the fifth prize. | Only the fifth prize is replaced. |
| Mothership Plasma Cannon | Reach the Ice Caves Mothership back layer. | Only its back-layer Plasma Cannon is replaced. |
| Lahamu | Defeat Lahamu in the Mothership. | The mapped reward appears at Lahamu's death position; forcefields still disable normally. |
| True Crown recovery | Complete Beg's True Crown check while cursed and below four health; repeat while uncursed. | A cursed player is cured and restored to at least 4 HP; uncursed players' health is unchanged. |
| Tusk Palace | Visit Tusk's Palace in Neo Babylon 6-3. | Its back-layer Royal Jelly is the mapped reward. |
| Sparrow Vault | Open exactly four vault chests in Neo Babylon 6-3, then speak to Sparrow. | Her quest-completion Player Bag is the mapped reward. |
| Eggplant King | Defeat Yama in Eggplant World. | The Eggplant Crown death drop is replaced with the mapped reward. |

If an adapter fails, capture the lines beginning `[KeyItemRandomizer]` from
the moment the level loads through the reward appearing. Include the randomizer
seed shown by `kir_spoiler()`.
