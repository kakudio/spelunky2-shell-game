-- Key Item Randomizer entry point: options, seed persistence, runtime lifecycle, UI commands.
local logic=require "logic"
local checks=require "checks"
local placements=require "placements"
local tests=require "tests"
local runtime=require "runtime_state"
local logger=require "logger"
local persisted_options=options
local options

-- Option registration takes both a short label and a long description. Keep
-- the default as the final argument; otherwise Playlunky treats it as the
-- description and the option can be absent or unset in the overlay.
local function saved_option(name, legacy_name, default)
    if persisted_options and persisted_options[name]~=nil then return persisted_options[name] end
    if persisted_options and persisted_options[legacy_name]~=nil then return persisted_options[legacy_name] end
    return default
end
-- Playlunky orders settings by their internal names. Prefixing those names
-- gives the overlay a stable, player-oriented order while saved legacy values
-- are migrated through the defaults above.
register_option_bool("a_enabled","Enable Key Item Randomizer","Enable or disable all Key Item Randomizer replacements.",saved_option("a_enabled","enabled",true))
register_option_int("b_seed","Randomizer Seed (0 = generate new layout)","Choose a fixed layout seed. Set 0 to generate a new layout when the run starts.",saved_option("b_seed","seed",0),0,999999)
register_option_bool("d_duat_item_recovery","Duat Item Recovery and Kali Rewards","Restore held, equipped, and altar-dropped player items consumed by the City of Gold to Duat, and improve the special Duat altar's favor rewards.",saved_option("d_duat_item_recovery","duat_item_recovery",true))
register_option_bool("e_run_reports","Generate Spoiler and Logs","Generate a per-run spoiler and log file with seeds and mod logs in Mods/Data/KeyItemRandomizer/run_reports.",saved_option("e_run_reports","run_reports",true))
register_option_bool("f_test_resources","Test: Start with resources and progression items","Give each player the test loadout used for check verification.",saved_option("f_test_resources","test_resources",true))
options=_G.options or persisted_options or {}
register_option_button("c_new_seed","New Seed","Set the seed to 0 so the next run generates a fresh layout.",function() options.b_seed=0 end)

local randomizer_state={seed=0,mapping=nil,initialized=false,level_materialized={}}
local runtime_context=nil
local log=logger.log
local function grant_test_item(player,entity_type,label)
    if not entity_type or entity_has_item_type(player.uid,entity_type) then return false end
    local uid=spawn_entity_nonreplaceable(entity_type,player.x,player.y,player.layer,0,0)
    if uid then pick_up(player.uid,uid); log("Granted test "..label.." to player uid "..player.uid) end
    return uid~=nil
end
local function grant_test_scepter(player)
    local scepter_type=ENT_TYPE.ITEM_SCEPTER
    if not scepter_type then return false end
    -- ON.START can be observed more than once in some debug/start flows.
    -- A nearby existing test Scepter makes this grant idempotent without
    -- treating an unrelated Scepter elsewhere in the level as this loadout.
    for _,uid in ipairs(get_entities_by_type(scepter_type) or {}) do
        local scepter=get_entity(uid)
        if scepter and scepter.layer==player.layer and math.abs(scepter.x-player.x)+math.abs(scepter.y-player.y)<=3 then return false end
    end
    local uid=spawn_entity_snapped_to_floor(scepter_type,player.x,player.y,player.layer)
    if uid then log("Granted test Scepter at player uid "..player.uid.."'s position") end
    return uid~=nil
end
local function grant_test_floor_item(player,entity_type,label)
    if not entity_type then return false end
    for _,uid in ipairs(get_entities_by_type(entity_type) or {}) do
        local item=get_entity(uid)
        if item and item.layer==player.layer and math.abs(item.x-player.x)+math.abs(item.y-player.y)<=3 then return false end
    end
    local uid=spawn_entity_snapped_to_floor(entity_type,player.x,player.y,player.layer)
    if uid then log("Granted test "..label.." at player uid "..player.uid.."'s position") end
    return uid~=nil
end
local function grant_test_tusk_idol(player)
    -- An Idol is a held item, so place it at the player's feet instead of
    -- displacing the test Excalibur. Limit the duplicate check to the start
    -- position, as other Idols in a level are unrelated.
    return grant_test_floor_item(player,placements.type_of("ITEM_MADAMETUSK_IDOL"),"Tusk Idol")
end
local function now_seed() local value=math.floor(os.time()*1000)%999999; return value==0 and 1 or value end
local function load_persisted_seed()
    local file=io.open_data("randomizer_seed.txt","r")
    if not file then return nil end
    local seed=tonumber(file:read("a")); file:close()
    return seed and seed>0 and seed<=999999 and math.floor(seed) or nil
end
local function persist_seed(seed)
    local file=io.open_data("randomizer_seed.txt","w")
    if file then file:write(tostring(seed)); file:close() end
end
-- The options menu is the seed selector. On opening the mod it shows the
-- saved layout seed; choosing 0 explicitly requests a new one at run start.
local saved_seed_for_menu=load_persisted_seed()
if saved_seed_for_menu then options.b_seed=saved_seed_for_menu end
local function initialize()
    if randomizer_state.initialized then return end
    randomizer_state.seed=tonumber(options.b_seed) or 0
    if randomizer_state.seed==0 then
        randomizer_state.seed=now_seed()
        options.b_seed=randomizer_state.seed
        log("Seed 0 selected; generated new layout seed "..randomizer_state.seed)
    end
    persist_seed(randomizer_state.seed)
    randomizer_state.mapping=logic.generate(randomizer_state.seed)
    randomizer_state.initialized=true
    log(string.format("Initialized logic v%d, randomizer seed %d (%d checks / %d rewards)",logic.LOGIC_VERSION,randomizer_state.seed,logic.check_count(),logic.reward_count()))
end
runtime_context=runtime.new(randomizer_state,initialize,log,function() return options.d_duat_item_recovery end)
set_callback(function()
    if not options.a_enabled then return end
    -- A menu edit is applied just before the next dungeon is generated. This
    -- lets the player choose a seed (or 0 for a fresh one) before entering.
    local requested_seed=tonumber(options.b_seed) or 0
    if randomizer_state.initialized and (requested_seed==0 or requested_seed~=randomizer_state.seed) then
        randomizer_state.initialized=false
        randomizer_state.mapping=nil
    end
    initialize()
    -- Spawn hooks can schedule deferred work while the level is generating.
    -- Begin the new epoch before that work exists; doing this in POST level
    -- generation cancelled valid callbacks such as Moon Challenge's Bow
    -- handoff as soon as the level finished building.
    runtime.reset_level(runtime_context)
    checks.on_pre_level_generation(runtime_context)
end,ON.PRE_LEVEL_GENERATION)
local function on_post_level_generation()
    if not options.a_enabled then return end
    initialize()
    checks.on_post_level_generation(runtime_context)
end
checks.register_spawn_hooks(runtime_context)
set_callback(on_post_level_generation,ON.POST_LEVEL_GENERATION)
set_callback(function() if options.a_enabled and not randomizer_state.initialized then initialize() end end,ON.START)
set_callback(function()
    if not options.a_enabled then return end
    -- The mapping is seed-stable, but collected progression belongs to one
    -- run only. ON.START is also used by shortcuts/debug starts, which may
    -- not begin in 1-1, so reset unconditionally here.
    runtime.reset_run(runtime_context)
    local report_path=logger.begin_run(randomizer_state,logic,options.e_run_reports)
    if report_path then log("Run report started: Mods/Data/KeyItemRandomizer/"..report_path)
    elseif options.e_run_reports then log("WARNING: could not create this run's report file") end
    log("Reset Crown/Hedjet progression for new run")
    if options.f_test_resources then
        for _,player in ipairs(players) do
            player.health=50
            player.inventory.bombs=50
            player.inventory.ropes=50
            player.inventory.money=1000000
            -- Do not route test inventory through the randomizer's native-spawn
            -- hooks (the Udjat hook would otherwise turn this Eye into its mapped reward).
            grant_test_item(player,ENT_TYPE.ITEM_PICKUP_UDJATEYE,"Udjat Eye")
            grant_test_item(player,ENT_TYPE.ITEM_PICKUP_ANKH,"Ankh")
            grant_test_item(player,ENT_TYPE.ITEM_PICKUP_CROWN,"Crown")
            grant_test_item(player,ENT_TYPE.ITEM_PICKUP_SKELETON_KEY,"Skeleton Key")
            grant_test_item(player,ENT_TYPE.ITEM_PICKUP_SPECIALCOMPASS,"Alien Compass")
            grant_test_floor_item(player,ENT_TYPE.ITEM_PICKUP_TABLETOFDESTINY,"Tablet of Destiny")
            grant_test_item(player,ENT_TYPE.ITEM_PICKUP_SPIKESHOES,"Spike Shoes")
            local excalibur_type=placements.type_of("ITEM_EXCALIBUR")
            local vlads_cape_type=placements.type_of("ITEM_VLADS_CAPE")
            grant_test_item(player,excalibur_type,"Excalibur")
            grant_test_item(player,vlads_cape_type,"Vlad's Cape")
            grant_test_scepter(player)
            grant_test_tusk_idol(player)
            runtime_context.progression.crown=true
        end
        log("Test resources granted: $1,000,000, 50 health/bombs/ropes, Udjat Eye, Ankh, Crown, Skeleton Key, Alien Compass, Tablet of Destiny, Spike Shoes, Excalibur, Vlad's Cape, and a Scepter and Tusk Idol at each player's position")
    end
    checks.replace_excalibur_if_gated(runtime_context)
end,ON.START)

local function console_argument(args,position,fallback)
    if type(args)=="table" then return tonumber(args[position]) or fallback end
    if position==1 then return tonumber(args) or fallback end
    return fallback
end
register_console_command("kir_validate",function(args)
    local seed=console_argument(args,1,randomizer_state.seed or now_seed())
    local ok,route=logic.validate(logic.generate(seed))
    print(string.format("[KIR] seed=%d checks=%d rewards=%d victory=%s",seed,logic.check_count(),logic.reward_count(),ok and "YES" or "NO"))
    if ok then print(logic.format_route(route)) end
    return ok
end)
register_console_command("kir_fuzz",function(args,first_argument)
    local count=math.max(1,math.min(console_argument(args,1,100),10000))
    local first=type(args)=="table" and console_argument(args,2,1) or tonumber(first_argument) or 1
    local ok,message=logic.self_test(count,first); print("[KIR] fuzz "..(ok and "passed: " or "FAILED: ")..message); return ok
end)
register_console_command("kir_tests",function(args)
    local count=math.max(1,math.min(console_argument(args,1,100),10000))
    local ok,message=tests.run(count)
    print("[KIR] tests "..(ok and "passed: " or "FAILED: ")..message)
    return ok
end)
register_console_command("kir_seed",function(args)
    local seed=console_argument(args,1,nil)
    if not seed or seed<0 or seed>999999 then print("Usage: kir_seed(seed)"); return false end
    options.b_seed=seed; persist_seed(seed); randomizer_state.initialized=false; randomizer_state.mapping=nil
    print("[KIR] Randomizer seed set and persisted; use kir_spoiler() to apply it now."); return true
end)
register_console_command("kir_new_seed",function()
    local seed=now_seed()
    if seed==randomizer_state.seed then seed=(seed%999999)+1 end
    options.b_seed=seed; persist_seed(seed); randomizer_state.initialized=false; randomizer_state.mapping=nil
    initialize()
    print("[KIR] New randomizer seed generated and persisted: "..seed)
    return seed
end)
register_console_command("kir_spoiler",function()
    initialize(); print(string.format("[KIR] Full check mapping for randomizer seed %d:",randomizer_state.seed))
    local target_group=logic.kali_present_target_group(randomizer_state.seed)
    local source=runtime_context.kali_present_source_location
    if source then
        print(string.format("[KIR] Kali Present: target group %d; placed at %d-%d theme %s (%.1f, %.1f, layer %s)",target_group,source.world,source.level,tostring(source.theme),source.x,source.y,tostring(source.layer)))
    else
        print(string.format("[KIR] Kali Present: target group %d; not placed yet (first Kali altar with a pet at/after this group)",target_group))
    end
    for _,check in ipairs(logic.CHECKS) do
        if check.shuffle~=false then print(string.format("[KIR] %-38s -> %s",check.id,randomizer_state.mapping[check.id] or "NONE")) end
    end
    return true
end)
register_console_command("kir_status",function()
    initialize()
    local epoch,materialized,failed,failures=runtime_context.lifecycle:summary()
    print(string.format("[KIR] seed=%d logic=%d mapping=%s level_epoch=%d materialized=%d failures=%d",randomizer_state.seed,logic.LOGIC_VERSION,randomizer_state.mapping and "ready" or "missing",epoch,materialized,failed))
    local sparrow_state=state.quests and state.quests.sparrow_state
    print(string.format("[KIR] Sparrow quest state=%s; last observed transition=%s",tostring(sparrow_state),runtime_context.sparrow_last_transition and (tostring(runtime_context.sparrow_last_transition.from).." -> "..tostring(runtime_context.sparrow_last_transition.to)) or "none"))
    for check,detail in pairs(failures) do print("[KIR] FAILED "..check..": "..detail) end
    return true
end)
register_console_command("kir_report_path",function()
    local path=logger.report_path()
    print(path and "[KIR] Current run report: Mods/Data/KeyItemRandomizer/"..path or "[KIR] No active run report (start a run or enable Write Run Reports).")
    return path or false
end)
register_console_command("kir_where",function()
    local player=players and players[1]
    if not player then print("[KIR] No player is active."); return false end
    local x,y,layer=get_position(player.uid); local name=layer==LAYER.BACK and "BACK" or "FRONT"
    print(string.format("[KIR] Player: x=%.1f y=%.1f layer=%s (%d), world=%d level=%d theme=%d",x,y,name,layer,state.world,state.level,state.theme)); return true
end)
register_console_command("kir_anchors",function() placements.print_missing_anchors(); return true end)
register_console_command("kir_help",function() print("[KIR] kir_validate(seed), kir_fuzz(count, first), kir_seed(seed), kir_new_seed(), kir_spoiler(), kir_where(), kir_status(), kir_anchors() -- kir_status includes Sparrow quest state"); return true end)
log("Key Item Randomizer logic v"..logic.LOGIC_VERSION.." loaded")
