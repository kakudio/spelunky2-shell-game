# Implementation review and playtest checklist

Which checks work in-game is recorded only in the
[verification ledger](verified-checks.md).

## Design notes

- `logic.lua` is the authoritative check/reward graph, deterministic
  Park-Miller seeded generator, and fixed-point route validator.
- The generator deliberately assigns Tablet, Bow, and Arrow to the three
  guaranteed early world checks (`Udjat Chest`, `Quillback`, `Olmec Ankh`), in
  a seeded order. This is conservative but proves every generated mapping has
  a physical progression route without relying on optional-room generation.
- `main.lua` persists only the selected seed and rebuilds its deterministic
  mapping on launch. Per-run state is never serialized.
- Event-specific checks are replaced at their completion event, never because
  the level loads; replacing a generic item entity would either miss the event
  or place a reward before the intended completion condition.

| Check(s) | Design constraint |
|---|---|
| `CHECK_YANG` | The pen's treasure room can be empty or contain ordinary loot, so the reward is anchored to Yang's native locked pen door instead. |
| Moon Challenge checks | Replacing Hou Yi's Bow at its spawn point crashes on pickup because Tun keeps a reference to the native Bow. The native Bow stays alive but hidden and non-interactive; the mapped reward is spawned at its location. |
| `CHECK_SISTERS_OLMEC_REWARD` | The reward happens only after rescuing all three Sisters and reaching Olmec, so it uses the native Sisters drop. |
| `CHECK_TUSK_DICE_HOUSE` | Only the fifth dice prize is replaced; the native VIP invitation is preserved. |
| `CHECK_TUSK_IDOL`, `CHECK_TUSK_PALACE_VISIT`, `CHECK_SPARROW_VAULT` | Each uses its quest-state or room-specific anchor. |
| `CHECK_ALIEN_COMPASS`, `CHECK_LAHAMU`, `CHECK_MOTHERSHIP_PLASMA_CANNON` | Mothership access is a quest state, not a standalone level location. |
| `CHECK_EGGPLANT_KING` | Yama's Eggplant Crown is replaced at its death-reward event. Eggplant Child is excluded because spawning it crashes the game. |
| Kali and Beg checks | They are player-action or dialogue-state checks, handled through sacrifice, quest-state, and drop callbacks. |
| Boss checks | Rewards come from death or drop callbacks so an uncleared boss cannot be bypassed. |

## Entity-name audit

Run `kir_anchors` in the Overlunky console. It prints any reward entity-name
constant unavailable in the installed API. Correct missing names in
`REWARD_ENTITY_NAMES` before attempting that reward in a run.

## Recommended acceptance test

1. Run `kir_fuzz 1000 1`; it must report success.
2. For seeds 1, 42, and 424242, run `kir_validate <seed>` and compare the
   output to `docs/victory-routes.md`.
3. Use `kir_anchors`; resolve every reported missing constant.
4. Start a run with a fixed randomizer seed, transition a level, and die/restart.
   `kir_status` must show the same seed and mapping within that session.
5. Play the [final pass](runtime-verification-checklist.md#final-pass) and
   record each result in the [verification ledger](verified-checks.md).
