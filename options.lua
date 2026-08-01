-- Options configuration for Key Item Randomizer

-- Master toggle
register_option_bool("enabled", "Enable Key Item Randomizer", true)

-- Individual item toggles
register_option_bool("shuffle_ankh", "Shuffle Ankh", true)
register_option_bool("shuffle_crown", "Shuffle Crown/Hedjet", true)
register_option_bool("shuffle_excalibur", "Shuffle Excalibur", true)
register_option_bool("shuffle_elixir", "Shuffle Elixir", true)
register_option_bool("shuffle_arrow_of_light", "Shuffle Arrow of Light", true)
register_option_bool("shuffle_hou_yi_bow", "Shuffle Hou Yi's Bow", true)
register_option_bool("shuffle_tablet", "Shuffle Tablet of Destiny", true)
register_option_bool("shuffle_udjat", "Shuffle Udjat Eye", true)
register_option_bool("shuffle_kapala", "Shuffle Kapala", true)
register_option_bool("shuffle_skeleton_key", "Shuffle Skeleton Key", true)

-- Logic and progression
register_option_bool("logic_mode", "Logic Mode (Ensure Beatable)", true)
register_option_bool("progressive_mode", "Progressive Item Placement", true)

-- Seed
register_option_int("seed", "Random Seed (0 = random)", 0, 0, 999999)

-- Difficulty presets
local difficulties = {"Easy", "Normal", "Hard", "Expert"}
register_option_combo("difficulty", "Difficulty", 2, difficulties)

-- Spoiler log
register_option_bool("spoiler_log", "Generate Spoiler Log (Console)", false)

-- Advanced options
register_option_bool("allow_duplicates", "Allow Duplicate Items", false)
register_option_bool("replace_shop_items", "Replace Shop Items", false)
register_option_bool("replace_crate_contents", "Replace Crate Contents", false)
register_option_bool("replace_challenge_rewards", "Replace Challenge Rewards", true)
register_option_bool("replace_kali_rewards", "Replace Kali Rewards", false)

-- Return options table for require()
return options