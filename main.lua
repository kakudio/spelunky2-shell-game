-- Key Item Randomizer entry point: options, persistent mapping, save/load, UI commands.
local logic=require "logic"
local checks=require "checks"
local placements=require "placements"
local tests=require "tests"
local runtime=require "runtime_state"

register_option_bool("enabled","Enable Key Item Randomizer",true)
register_option_int("seed","Randomizer Seed (0 = generate new layout)",0,0,999999)
register_option_bool("test_resources","Test: Start with resources, progression items, and Excalibur",true)
local options=options or {enabled=true,seed=0,test_resources=true}

local randomizer_state={seed=0,mapping=nil,initialized=false,level_materialized={},saved_mapping_version=0}
local runtime_context=nil
local function log(message) print("[KeyItemRandomizer] "..message) end
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
if saved_seed_for_menu then options.seed=saved_seed_for_menu end
local function initialize()
    if randomizer_state.initialized then return end
    randomizer_state.seed=tonumber(options.seed) or 0
    if randomizer_state.seed==0 then
        randomizer_state.seed=now_seed()
        options.seed=randomizer_state.seed
        log("Seed 0 selected; generated new layout seed "..randomizer_state.seed)
    end
    persist_seed(randomizer_state.seed)
    randomizer_state.mapping=logic.generate(randomizer_state.seed)
    randomizer_state.initialized=true
    randomizer_state.saved_mapping_version=logic.LOGIC_VERSION
    log(string.format("Initialized logic v%d, randomizer seed %d (%d checks / %d rewards)",logic.LOGIC_VERSION,randomizer_state.seed,logic.check_count(),logic.reward_count()))
end
runtime_context=runtime.new(randomizer_state,initialize,log)
set_callback(function()
    if not options.enabled then return end
    -- A menu edit is applied just before the next dungeon is generated. This
    -- lets the player choose a seed (or 0 for a fresh one) before entering.
    local requested_seed=tonumber(options.seed) or 0
    if randomizer_state.initialized and (requested_seed==0 or requested_seed~=randomizer_state.seed) then
        randomizer_state.initialized=false
        randomizer_state.mapping=nil
    end
    initialize()
    checks.on_pre_level_generation(runtime_context)
end,ON.PRE_LEVEL_GENERATION)
local function on_post_level_generation()
    if not options.enabled then return end
    initialize()
    runtime.reset_level(runtime_context)
    checks.on_post_level_generation(runtime_context)
end
checks.register_spawn_hooks(runtime_context)
set_callback(on_post_level_generation,ON.POST_LEVEL_GENERATION)
set_callback(function(ctx)
    if options.enabled and randomizer_state.initialized then
        local data=runtime.save_data(runtime_context)
        data.logic_version=logic.LOGIC_VERSION; data.seed=randomizer_state.seed; data.mapping=randomizer_state.mapping
        ctx:save(json.encode(data))
    end
end,ON.SAVE)
set_callback(function(ctx)
    if not options.enabled then return end
    local raw=ctx:load()
    if raw and raw~="" then
        local data=json.decode(raw)
        if data and data.logic_version==logic.LOGIC_VERSION and data.mapping then
            randomizer_state.seed=data.seed; randomizer_state.mapping=data.mapping; randomizer_state.initialized=true; randomizer_state.saved_mapping_version=data.logic_version
            runtime.restore_data(runtime_context,data)
            log("Restored randomizer seed "..randomizer_state.seed.." and its saved mapping")
        end
    end
end,ON.LOAD)
set_callback(function() if options.enabled and not randomizer_state.initialized then initialize() end end,ON.START)
set_callback(function()
    if not options.enabled then return end
    -- The mapping is seed-stable, but collected progression belongs to one
    -- run only. ON.START is also used by shortcuts/debug starts, which may
    -- not begin in 1-1, so reset unconditionally here.
    runtime.reset_run(runtime_context)
    log("Reset Crown/Hedjet progression for new run")
    if options.test_resources then
        for _,player in ipairs(players) do
            player.health=50
            player.inventory.bombs=50
            player.inventory.ropes=50
            player.inventory.money=1000000
            -- Do not route test inventory through the randomizer's native-spawn
            -- hooks (the Udjat hook would otherwise turn this Eye into its mapped reward).
            local eye=spawn_entity_nonreplaceable(ENT_TYPE.ITEM_PICKUP_UDJATEYE,player.x,player.y,player.layer,0,0)
            local ankh=spawn_entity_nonreplaceable(ENT_TYPE.ITEM_PICKUP_ANKH,player.x,player.y,player.layer,0,0)
            local crown=spawn_entity_nonreplaceable(ENT_TYPE.ITEM_PICKUP_CROWN,player.x,player.y,player.layer,0,0)
            local skeleton_key=spawn_entity_nonreplaceable(ENT_TYPE.ITEM_PICKUP_SKELETON_KEY,player.x,player.y,player.layer,0,0)
            local alien_compass=spawn_entity_nonreplaceable(ENT_TYPE.ITEM_PICKUP_SPECIALCOMPASS,player.x,player.y,player.layer,0,0)
            local excalibur_type=placements.type_of("ITEM_EXCALIBUR")
            local vlads_cape_type=placements.type_of("ITEM_VLADS_CAPE")
            local excalibur=excalibur_type and spawn_entity_nonreplaceable(excalibur_type,player.x,player.y,player.layer,0,0) or nil
            local vlads_cape=vlads_cape_type and spawn_entity_nonreplaceable(vlads_cape_type,player.x,player.y,player.layer,0,0) or nil
            pick_up(player.uid,eye)
            pick_up(player.uid,ankh)
            pick_up(player.uid,crown)
            pick_up(player.uid,skeleton_key)
            pick_up(player.uid,alien_compass)
            if excalibur then pick_up(player.uid,excalibur) end
            if vlads_cape then pick_up(player.uid,vlads_cape) end
            runtime_context.progression.crown=true
        end
        log("Test resources granted: $1,000,000, 50 health/bombs/ropes, Udjat Eye, Ankh, Crown, Skeleton Key, Alien Compass, Excalibur, and Vlad's Cape")
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
    options.seed=seed; persist_seed(seed); randomizer_state.initialized=false; randomizer_state.mapping=nil
    print("[KIR] Randomizer seed set and persisted; use kir_spoiler() to apply it now."); return true
end)
register_console_command("kir_new_seed",function()
    local seed=now_seed()
    if seed==randomizer_state.seed then seed=(seed%999999)+1 end
    options.seed=seed; persist_seed(seed); randomizer_state.initialized=false; randomizer_state.mapping=nil
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
register_console_command("kir_status",function() initialize(); print(string.format("[KIR] seed=%d logic=%d mapping=%s",randomizer_state.seed,logic.LOGIC_VERSION,randomizer_state.mapping and "ready" or "missing")); return true end)
register_console_command("kir_where",function()
    local player=players and players[1]
    if not player then print("[KIR] No player is active."); return false end
    local x,y,layer=get_position(player.uid); local name=layer==LAYER.BACK and "BACK" or "FRONT"
    print(string.format("[KIR] Player: x=%.1f y=%.1f layer=%s (%d), world=%d level=%d theme=%d",x,y,name,layer,state.world,state.level,state.theme)); return true
end)
register_console_command("kir_anchors",function() placements.print_missing_anchors(); return true end)
register_console_command("kir_help",function() print("[KIR] kir_validate(seed), kir_fuzz(count, first), kir_seed(seed), kir_new_seed(), kir_spoiler(), kir_where(), kir_status(), kir_anchors()"); return true end)
log("Key Item Randomizer logic v"..logic.LOGIC_VERSION.." loaded")
