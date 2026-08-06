# Implementation review and playtest checklist

## What is complete in code

- `logic.lua` is the authoritative 38-check / 38-reward graph, deterministic
  Park-Miller seeded generator, and fixed-point route validator.
- The generator deliberately assigns Tablet, Bow, and Arrow to the three
  guaranteed early world checks (`Udjat Chest`, `Quillback`, `Olmec Ankh`), in
  a seeded order. This is conservative but proves every generated mapping has
  a physical progression route without relying on optional-room generation.
- `main.lua` persists only the selected seed and rebuilds its deterministic
  mapping on launch. Per-run state is never serialized.
- Generic item and NPC adapters have been added for the reliable vanilla
  entities listed in `main.lua`.

## Required in-game review

The following are deliberately **not** claimed complete until they have a
real-game smoke test. They need event-specific callbacks or a stable room
marker; replacing a generic item entity would either miss the event or place a
reward before the intended completion condition.

| Check(s) | Why it needs review | Intended implementation |
|---|---|---|
| `CHECK_YANG` | The pen's treasure room can be empty or contain ordinary loot. | Find Yang's pen/treasure room and spawn a fixed background anchor after generation. Gate pickup behind its normal key/event. |
| Moon Challenge checks | Replacing the Hou Yi's Bow at its spawn point crashes when it is picked up because Tun retains a reference to the native Bow even after the challenge is complete. | Keep the native Bow entity alive but invisible and non-interactive in the back layer; spawn the mapped reward at its original Moon Challenge location. Do not use a pre-spawn replacement. |
| `CHECK_SISTERS_OLMEC_REWARD` | Reward happens only after rescuing all three Sisters and reaching Olmec. | Track each Sister rescue and place the one mapped reward at the Olmec reward event. |
| `CHECK_TUSK_DICE_HOUSE` | The fifth dice prize must be replaced, not any arbitrary Tusk item. | Hook the fifth prize spawn only. Preserve the native automatic VIP invitation. |
| `CHECK_TUSK_IDOL`, `CHECK_TUSK_PALACE_VISIT`, `CHECK_SPARROW_VAULT` | Each has a quest-state / room-specific anchor. | Add their exact room/event anchors after examining generated entities. |
| `CHECK_ALIEN_COMPASS`, `CHECK_LAHAMU`, `CHECK_MOTHERSHIP_PLASMA_CANNON` | Mothership access is a quest state, not a standalone level location. | Hook Van/Vlad state and the two Mothership reward entities. |
| `CHECK_EGGPLANT_KING` | Yama's Eggplant Crown reward needs foreground-safe, room-specific handling. | Identify and replace its exact death-reward event. Eggplant Child is intentionally excluded because spawning it crashes the game. |
| Kali and Beg checks | They are player-action / dialogue-state checks rather than ordinary static items. | Use sacrifice and dialogue/death callbacks; do not materialize merely because the level loads. |
| Boss checks | Current NPC adapter places a visible reward near Quillback, Kingu, and Tiamat at generation. | Prefer a verified death/reward callback so an uncleared boss cannot be bypassed. |

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
5. Playtest every row in the table above before enabling those checks in a
   release build. The present implementation has safe logic but intentionally
   does not fake completion of these event gates.
