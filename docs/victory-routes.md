# Dry-run victory routes

Logic version: `2`. The deterministic generator has 38 checks and 38 unique
pool rewards. Its progression construction puts the required Tablet, Bow, and
Arrow at the three guaranteed world checks in a seeded order. Therefore each
route below is independent of optional NPC/event room generation.

## Seed 1

```text
CHECK_QUILLBACK  -> REWARD_TABLET_OF_DESTINY
CHECK_OLMEC_ANKH -> REWARD_HOU_YIS_BOW
CHECK_UDJAT_CHEST -> REWARD_ARROW_OF_LIGHT

Dwelling: collect Udjat Chest and defeat Quillback.
Choose Jungle or Volcana, then reach Olmec and collect the Olmec reward.
Choose Tide Pool or Temple, then reach Ice Caves.
Neo Babylon is open because Tablet is held.
Proceed Neo Babylon -> Tiamat -> Sunken City -> Hundun.
At Hundun: Tablet + Bow + Arrow satisfies VICTORY_COSMIC_OCEAN.
```

## Seed 42

```text
CHECK_UDJAT_CHEST -> REWARD_TABLET_OF_DESTINY
CHECK_QUILLBACK -> REWARD_HOU_YIS_BOW
CHECK_OLMEC_ANKH -> REWARD_ARROW_OF_LIGHT

Dwelling: collect the Udjat Chest reward and defeat Quillback.
Take either early route, reach Olmec, and collect its reward.
Continue through either Tide Pool or Temple -> Ice Caves -> Neo Babylon
-> Tiamat -> Sunken City -> Hundun.
At Hundun: Tablet + Bow + Arrow satisfies VICTORY_COSMIC_OCEAN.
```

## Seed 424242

```text
CHECK_UDJAT_CHEST -> REWARD_TABLET_OF_DESTINY
CHECK_OLMEC_ANKH -> REWARD_HOU_YIS_BOW
CHECK_QUILLBACK -> REWARD_ARROW_OF_LIGHT

Dwelling: collect the Udjat Chest reward and defeat Quillback.
Take either early route, reach Olmec, and collect its reward.
Continue through either Tide Pool or Temple -> Ice Caves -> Neo Babylon
-> Tiamat -> Sunken City -> Hundun.
At Hundun: Tablet + Bow + Arrow satisfies VICTORY_COSMIC_OCEAN.
```

These are dry-run logic routes. They do not certify the event-specific anchor
adapters listed in `implementation-review.md`; those need in-game smoke tests.
