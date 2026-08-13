-- Key Item Randomizer entry point: options, seed persistence, runtime lifecycle, UI commands.
local logic=require "logic"
local checks=require "checks"
local placements=require "placements"
local tests=require "tests"
local runtime=require "runtime_state"
local logger=require "logger"
local build_config=require "build_config"
local persisted_options=options
local options

-- Option registration takes both a short label and a long description. Keep
-- the default as the final argument; otherwise Playlunky treats it as the
-- description and the option can be absent or unset in the overlay.
local function saved_option(name, default, ...)
    if persisted_options and persisted_options[name]~=nil then return persisted_options[name] end
    for _,legacy_name in ipairs({...}) do
        if persisted_options and persisted_options[legacy_name]~=nil then return persisted_options[legacy_name] end
    end
    return default
end
-- Playlunky orders settings by their internal names. Header callbacks and
-- prefixed names create stable visual groups while retaining old values.
local function register_group(name, title)
    register_option_callback(name,false,function(draw_ctx)
        draw_ctx:win_separator_text(title)
        return false
    end)
end
register_group("a_randomizer_group","Randomizer")
register_option_bool("b_enabled","Enable Key Item Randomizer","Enable or disable all Key Item Randomizer replacements.",saved_option("b_enabled",true,"a_enabled","enabled"))
register_option_int("d_seed","Randomizer Seed (0 = new logic)","",saved_option("d_seed",0,"c_seed","b_seed","seed"),0,999999)
register_group("e_balance_group","Balance")
register_option_bool("f_kali_item_recovery","Kali Item Recovery","Restore held, equipped, and allowed altar-dropped items from the City of Gold to Duat.",saved_option("f_kali_item_recovery",true,"f_duat_item_recovery","d_duat_item_recovery","duat_item_recovery"))
register_option_bool("g_balanced_duat_kali_rewards","Balanced Duat Kali Rewards","Replace the special Duat altar's favor rewards with balanced Player Bag and Royal Jelly rewards.",saved_option("g_balanced_duat_kali_rewards",true,"f_duat_item_recovery","d_duat_item_recovery","duat_item_recovery"))
register_option_bool("h_true_crown_restoration","True Crown Restoration","Remove Kali's curse and restore the player to at least 4 HP after the True Crown encounter.",saved_option("h_true_crown_restoration",true))
local developer_options=build_config.developer_options==true
if developer_options then
    register_group("i_logging_group","Logging")
    register_option_bool("j_generate_spoiler","Generate Spoiler","Include the full randomized check mapping in the per-run report.",saved_option("j_generate_spoiler",true,"i_generate_spoiler","i_run_reports","e_run_reports","run_reports"))
    register_option_bool("k_generate_logs","Generate Logs","Include Key Item Randomizer logs in the same per-run report.",saved_option("k_generate_logs",true,"j_generate_logs","i_run_reports","e_run_reports","run_reports"))
    register_group("m_developer_group","Developer")
    register_option_bool("n_dev_use_adventure_seed","Use Adventure Run Seed","Apply the seed pair below immediately before each new run starts.",saved_option("n_dev_use_adventure_seed",false))
    register_option_string("o_dev_adventure_seed","Adventure Run Seed","Two signed integers from a run report, in the form first,second.",saved_option("o_dev_adventure_seed",""))
    register_option_bool("p_dev_in_game_logging","In-Game Logging","Show Key Item Randomizer runtime logs in the Playlunky overlay.",saved_option("p_dev_in_game_logging",build_config.default_overlay_runtime_logs==true))
    register_option_bool("q_dev_test_resources","Test: Start with resources and progression items","Give each player the test loadout used for check verification.",saved_option("q_dev_test_resources",true,"l_test_resources","k_test_resources","g_test_resources","f_test_resources","test_resources"))
    register_option_int("r_dev_beg_start_state","Beg Starting Quest State","Developer only. Apply this state to Beg's quest at the start of every run. Use 0 for normal behavior; use 3 to prepare the True Crown completion transition.",saved_option("r_dev_beg_start_state",0),0,5)
end
options=_G.options or persisted_options or {}
register_option_button("c_new_seed","New Seed","",function() options.d_seed=0 end)

local function sync_developer_options()
    logger.set_overlay_runtime_logs(developer_options and options.p_dev_in_game_logging)
end
local function parse_adventure_seed(value)
    local first,second=tostring(value or ""):match("^%s*([%-]?%d+)%s*,%s*([%-]?%d+)%s*$")
    return first and tonumber(first) or nil,second and tonumber(second) or nil
end

local runtime_context
local log=logger.log
local function apply_developer_beg_start_state()
    if not developer_options then return end
    local quests=state.quests
    if not quests then
        log("Developer Beg Starting Quest State unavailable: quest state is not initialized")
        return
    end
    local requested=math.max(0,math.min(5,math.floor(tonumber(options.r_dev_beg_start_state) or 0)))
    quests.beg_state=requested
    runtime_context.beg_last_state=requested
    log("Developer Beg Starting Quest State applied: "..requested)
end
sync_developer_options()

local randomizer_state={seed=0,mapping=nil,initialized=false,level_materialized={}}
runtime_context=nil
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

local function load_persisted_adventure_seed()
    if not developer_options then return nil end
    local file=io.open_data("adventure_run_seed.txt","r")
    if not file then return nil end
    local value=file:read("a"); file:close()
    local first,second=parse_adventure_seed(value)
    return first and (tostring(first)..","..tostring(second)) or nil
end

local function persist_adventure_seed(value)
    if not developer_options then return end
    local first,second=parse_adventure_seed(value)
    if not first then return end
    local seed=tostring(first)..","..tostring(second)
    local file=io.open_data("adventure_run_seed.txt","w")
    if file then file:write(seed); file:close() end
    options.o_dev_adventure_seed=seed
    log("Developer Adventure Run Seed saved: "..seed)
end

-- The options menu is the seed selector. On opening the mod it shows the
-- saved layout seed; choosing 0 explicitly requests a new one at run start.
local saved_seed_for_menu=load_persisted_seed()
if saved_seed_for_menu then options.d_seed=saved_seed_for_menu end
local saved_adventure_seed_for_menu=load_persisted_adventure_seed()
if saved_adventure_seed_for_menu then
    options.o_dev_adventure_seed=saved_adventure_seed_for_menu
    -- A recorded run seed is for replaying after a relaunch. The toggle used
    -- to remain false by default, making the restored field look saved while
    -- silently allowing a different new adventure seed to be generated.
    options.n_dev_use_adventure_seed=true
end
local function initialize()
    if randomizer_state.initialized then return end
    randomizer_state.seed=tonumber(options.d_seed) or 0
    if randomizer_state.seed==0 then
        randomizer_state.seed=now_seed()
        options.d_seed=randomizer_state.seed
        log("Seed 0 selected; generated new layout seed "..randomizer_state.seed)
    end
    persist_seed(randomizer_state.seed)
    randomizer_state.mapping=logic.generate(randomizer_state.seed)
    randomizer_state.initialized=true
    log(string.format("Initialized logic v%d, randomizer seed %d (%d checks / %d rewards)",logic.LOGIC_VERSION,randomizer_state.seed,logic.check_count(),logic.reward_count()))
end
runtime_context=runtime.new(randomizer_state,initialize,log,
    function() return options.f_kali_item_recovery end,
    function() return options.g_balanced_duat_kali_rewards end,
    function() return options.h_true_crown_restoration end)
set_callback(function()
    runtime.reset_level(runtime_context)
    if not options.b_enabled then return end
    -- A menu edit is applied just before the next dungeon is generated. This
    -- lets the player choose a seed (or 0 for a fresh one) before entering.
    local requested_seed=tonumber(options.d_seed) or 0
    if randomizer_state.initialized and (requested_seed==0 or requested_seed~=randomizer_state.seed) then
        randomizer_state.initialized=false
        randomizer_state.mapping=nil
    end
    initialize()
    -- Spawn hooks can schedule deferred work while the level is generating.
    -- Begin the new epoch before that work exists; doing this in POST level
    -- generation cancelled valid callbacks such as Moon Challenge's Bow
    -- handoff as soon as the level finished building.
    checks.on_pre_level_generation(runtime_context)
end,ON.PRE_LEVEL_GENERATION)
local function on_post_level_generation()
    checks.on_balance_post_level_generation(runtime_context)
    if not options.b_enabled then return end
    initialize()
    checks.on_post_level_generation(runtime_context)
end
checks.register_spawn_hooks(runtime_context)
set_callback(on_post_level_generation,ON.POST_LEVEL_GENERATION)
set_callback(sync_developer_options,ON.GAMEFRAME)
if developer_options then
    set_callback(function()
        if not options.n_dev_use_adventure_seed then return end
        local first,second=parse_adventure_seed(options.o_dev_adventure_seed)
        if not first or not second then
            log("Developer Adventure Run Seed ignored: enter two signed integers as first,second")
            return
        end
        if not set_adventure_seed then
            log("Developer Adventure Run Seed unavailable: this Playlunky version has no set_adventure_seed API")
            return
        end
        set_adventure_seed(first,second)
        log("Developer Adventure Run Seed applied: "..tostring(first)..","..tostring(second))
    end,ON.RESET)
end
set_callback(function() if options.b_enabled and not randomizer_state.initialized then initialize() end end,ON.START)
set_callback(function()
    -- The mapping is seed-stable, but collected progression belongs to one
    -- run only. ON.START is also used by shortcuts/debug starts, which may
    -- not begin in 1-1, so reset unconditionally here.
    runtime.reset_run(runtime_context)
    apply_developer_beg_start_state()
    if developer_options and get_adventure_seed then
        local ok,first,second=pcall(get_adventure_seed,true)
        if ok and first~=nil and second~=nil then
            persist_adventure_seed(tostring(first)..","..tostring(second))
        else
            log("Developer Adventure Run Seed could not be read at run start")
        end
    end
    if not options.b_enabled then return end
    -- Release builds always retain a complete report so players can attach it
    -- when reporting an issue. The developer archive exposes the two controls
    -- above for focused testing.
    local generate_spoiler=not developer_options or options.j_generate_spoiler
    local generate_logs=not developer_options or options.k_generate_logs
    local report_path=logger.begin_run(randomizer_state,logic,generate_spoiler,generate_logs)
    if report_path then log("Run report started: Mods/Data/KeyItemRandomizer/"..report_path)
    elseif generate_spoiler or generate_logs then log("WARNING: could not create this run's report file") end
    log("Reset Crown/Hedjet progression for new run")
    if developer_options and options.q_dev_test_resources then
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
            grant_test_floor_item(player,placements.type_of("ITEM_EGGPLANT"),"Eggplant")
            runtime_context.progression.crown=true
        end
        log("Test resources granted: $1,000,000, 50 health/bombs/ropes, Udjat Eye, Ankh, Crown, Skeleton Key, Alien Compass, Tablet of Destiny, Spike Shoes, Excalibur, Vlad's Cape, and a Scepter, Tusk Idol, and Eggplant at each player's position")
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
    options.d_seed=seed; persist_seed(seed); randomizer_state.initialized=false; randomizer_state.mapping=nil
    print("[KIR] Randomizer seed set and persisted; use kir_spoiler() to apply it now."); return true
end)
register_console_command("kir_new_seed",function()
    local seed=now_seed()
    if seed==randomizer_state.seed then seed=(seed%999999)+1 end
    options.d_seed=seed; persist_seed(seed); randomizer_state.initialized=false; randomizer_state.mapping=nil
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
