-- Adapter scenarios driven through the game stand-in. Each scenario gets a
-- fresh stand-in, so mod modules and their registered hooks never carry over.

local stand_in=require "tests.stand_in"
local THEME,LAYER=stand_in.THEME,stand_in.LAYER
local M={}

local function expect(condition,message)
    if not condition then error(message,2) end
end

local scenarios={}
local function scenario(name,run,mapping) table.insert(scenarios,{name=name,run=run,mapping=mapping}) end

local function olmec(game,entities)
    return game:start_level{theme=THEME.OLMEC,world=3,level=1,entities=entities}
end

scenario("stand-in loads checks.lua and arms its engine drops",function(game)
    game:start_level{theme=THEME.ABZU,world=4,level=4}
    local tablet=game.ENT_TYPE.ITEM_PICKUP_TABLETOFDESTINY
    expect(game.drops.KINGU_TABLETOFDESTINY==game.ENT_TYPE.ITEM_PICKUP_ANKH,"Kingu's drop was not replaced by the mapped reward")
    local uid=game:drop("KINGU_TABLETOFDESTINY","ITEM_PICKUP_TABLETOFDESTINY",{x=5,y=5})
    expect(game:entity(uid).type.id~=tablet,"the native Tablet dropped despite the configured replacement")
end,{CHECK_KINGU="REWARD_ANKH"})

scenario("each scenario starts from fresh mod state",function(game)
    local hooks=#game.pre_spawn_hooks
    local other=stand_in.new{mapping={}}
    local fresh=other.checks~=game.checks and other.ctx~=game.ctx and #other.pre_spawn_hooks==hooks
    other:close()
    expect(fresh,"a second stand-in reused the first one's modules or hooks")
end)

scenario("a mapped reward replaces its native source",function(game)
    local ankh=olmec(game,{{"ITEM_PICKUP_ANKH",x=10,y=20}})[1]
    expect(not game:entity(ankh.uid),"the native Ankh was not removed")
    local keys=game:spawned_of("ITEM_PICKUP_SKELETON_KEY")
    expect(#keys==1 and keys[1].x==10 and keys[1].y==20,"the mapped Skeleton Key was not spawned at the Ankh")
    expect(game:materialized("CHECK_OLMEC_ANKH"),"the check was not marked materialized")

    game:start_level{theme=THEME.DWELLING,world=1,level=2}
    local uid=game:native_spawn("ITEM_PICKUP_UDJATEYE",{x=3,y=4,layer=LAYER.BACK})
    expect(game:entity(uid).type.id==game.ENT_TYPE.ITEM_PICKUP_CROWN,"the native Udjat Eye spawn was not replaced")
    expect(#get_entities_by_type(game.ENT_TYPE.ITEM_PICKUP_UDJATEYE)==0,"a native Udjat Eye remains in the level")
    expect(game:materialized("CHECK_UDJAT_CHEST"),"the native-spawn check was not marked materialized")
end,{CHECK_OLMEC_ANKH="REWARD_SKELETON_KEY",CHECK_UDJAT_CHEST="REWARD_CROWN"})

scenario("a second trigger for a check in the same level does nothing",function(game)
    local placed=olmec(game,{{"ITEM_PICKUP_ANKH",x=10,y=20},{"ITEM_PICKUP_ANKH",x=30,y=20}})
    expect(not game:entity(placed[1].uid),"the first Ankh was not replaced")
    expect(game:entity(placed[2].uid),"the second Ankh in the same level was replaced too")
    expect(#game:spawned_of("ITEM_PICKUP_SKELETON_KEY")==1,"the check materialized twice in one level")

    olmec(game,{{"ITEM_PICKUP_ANKH",x=10,y=20}})
    expect(#game:spawned_of("ITEM_PICKUP_SKELETON_KEY")==2,"the check did not materialize again on a new level")

    game.randomizer_state.mapping.CHECK_OLMEC_ANKH="REWARD_EGGPLANT"
    placed=olmec(game,{{"ITEM_PICKUP_ANKH",x=10,y=20},{"ITEM_PICKUP_ANKH",x=30,y=20}})
    expect(game:entity(placed[2].uid) and #game:spawned_of("ITEM_PRESENT")==1,"an Eggplant check materialized twice in one level")
end,{CHECK_OLMEC_ANKH="REWARD_SKELETON_KEY"})

scenario("a source a player is carrying is never replaced",function(game)
    local player=game:add_player{x=1,y=1}
    local carried=game:place("ITEM_PICKUP_ANKH",{holder=player})
    olmec(game)
    expect(game:entity(carried.uid) and carried.holder==player,"the carried Ankh was removed")
    expect(#game.spawned==0,"a reward was spawned for a carried source")
    expect(not game:materialized("CHECK_OLMEC_ANKH"),"a carried source materialized the check")
    expect(game:logged("Ignored player_carried source uid "..carried.uid),"the carried source was not reported")

    local native=olmec(game,{{"ITEM_PICKUP_ANKH",x=10,y=20}})[1]
    expect(game:entity(carried.uid),"the carried Ankh was removed beside a native one")
    expect(not game:entity(native.uid) and #game:spawned_of("ITEM_PICKUP_SKELETON_KEY")==1,"the native Ankh beside a carried one was not replaced")
end,{CHECK_OLMEC_ANKH="REWARD_SKELETON_KEY"})

scenario("a reward the mod spawns is not taken for another check's native reward",function(game)
    -- The Humphead Idol's Clone Gun passes through the Tide Pool Stars
    -- Challenge's Clone Gun spawn hook while it is being materialized.
    game:start_level{theme=THEME.TIDE_POOL,world=4,level=2,entities={{"ITEM_IDOL",x=8,y=9,layer=LAYER.BACK}}}
    expect(#game:spawned_of("ITEM_CLONEGUN")==1,"the mapped Clone Gun was not spawned")
    expect(#game:spawned_of("ITEM_PICKUP_ANKH")==0,"the mod's Clone Gun was replaced by the Stars Challenge reward")
    expect(game:materialized("CHECK_HUMPHEAD_CAVE_IDOL"),"the Idol check was not marked materialized")
    expect(not game:materialized("CHECK_STARS_CHALLENGE_TIDE_POOL"),"the Stars Challenge materialized from the mod's own spawn")
end,{CHECK_HUMPHEAD_CAVE_IDOL="REWARD_CLONE_GUN",CHECK_STARS_CHALLENGE_TIDE_POOL="REWARD_ANKH"})

local function expect_eggplant_present(game,uid)
    local present=game:entity(uid)
    expect(present and present.type.id==game.ENT_TYPE.ITEM_PRESENT,"the Eggplant reward was not a Present")
    expect(present.inside==game.ENT_TYPE.ITEM_EGGPLANT,"the Present does not hold an Eggplant")
    expect(#game:spawned_of("ITEM_EGGPLANT")==0,"a bare Eggplant was spawned")
end

scenario("an Eggplant reward arrives inside a Present",function(game)
    local ankh=olmec(game,{{"ITEM_PICKUP_ANKH",x=10,y=20}})[1]
    local presents=game:spawned_of("ITEM_PRESENT")
    expect(#presents==1,"no Present was spawned for the scanned source")
    expect_eggplant_present(game,presents[1].uid)
    expect(not game:entity(ankh.uid) and game:materialized("CHECK_OLMEC_ANKH"),"the scanned source was not replaced")

    game:start_level{theme=THEME.DWELLING,world=1,level=2}
    expect_eggplant_present(game,game:native_spawn("ITEM_PICKUP_UDJATEYE",{x=3,y=4,layer=LAYER.BACK}))
end,{CHECK_OLMEC_ANKH="REWARD_EGGPLANT",CHECK_UDJAT_CHEST="REWARD_EGGPLANT"})

local function tide_pool(game,level,entities)
    return game:start_level{theme=THEME.TIDE_POOL,world=4,level=level,entities=entities}
end

scenario("deferred adapter work runs within its own level",function(game)
    tide_pool(game,2)
    game:frames(5)
    local idol=game:place("ITEM_IDOL",{x=8,y=9,layer=LAYER.BACK})
    game:frames(15)
    expect(not game:entity(idol.uid) and game:materialized("CHECK_HUMPHEAD_CAVE_IDOL"),"the deferred Idol retry did not replace a late Idol")
end,{CHECK_HUMPHEAD_CAVE_IDOL="REWARD_SKELETON_KEY"})

scenario("deferred adapter work from a previous level does nothing",function(game)
    tide_pool(game,2)
    game:frames(10)
    local idol=tide_pool(game,3,{{"ITEM_IDOL",x=8,y=9,layer=LAYER.BACK}})[1]
    game:frames(30)
    expect(game:entity(idol.uid),"a stale deferred retry replaced an Idol on the next level")
    expect(#game.spawned==0,"a stale deferred retry spawned a reward")
    expect(game:logged("Cancelled stale deferred action Humphead cave Idol retry"),"the stale retry was not cancelled")
end,{CHECK_HUMPHEAD_CAVE_IDOL="REWARD_SKELETON_KEY"})

function M.run()
    local failures={}
    for _,entry in ipairs(scenarios) do
        local ok,game=pcall(stand_in.new,{mapping=entry.mapping})
        local message=game
        if ok then
            ok,message=pcall(entry.run,game)
            game:close()
        end
        if not ok then table.insert(failures,entry.name..": "..tostring(message)) end
    end
    if #failures>0 then return false,#failures.." of "..#scenarios.." scenarios failed\n  "..table.concat(failures,"\n  ") end
    return true,"passed "..#scenarios.." scenarios"
end

return M
