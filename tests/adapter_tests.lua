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

local function expect_spawn(game,type_name,x,y,layer,message)
    local spawns=game:spawned_of(type_name)
    local spawn=spawns[1]
    expect(#spawns==1 and spawn.x==x and spawn.y==y and spawn.layer==layer,
        message.." (got "..#spawns.." "..type_name..(spawn and string.format(" first at %s, %s layer %s",spawn.x,spawn.y,spawn.layer) or "")..")")
    return spawn
end

local function neo_babylon(game,level,entities)
    return game:start_level{theme=THEME.NEO_BABYLON,world=6,level=level,entities=entities}
end

scenario("an item anchor replaces only its source in its theme, level and layer",function(game)
    local placed=neo_babylon(game,3,{
        {"ITEM_PICKUP_ROYALJELLY",x=12,y=40,layer=LAYER.BACK},
        {"ITEM_PICKUP_ROYALJELLY",x=30,y=40,layer=LAYER.FRONT},
    })
    expect(not game:entity(placed[1].uid),"the back-layer Royal Jelly in Tusk's palace was not removed")
    expect(game:entity(placed[2].uid),"a front-layer Royal Jelly was replaced")
    local spawn=expect_spawn(game,"ITEM_PICKUP_SKELETON_KEY",12,40,LAYER.BACK,"the mapped reward was not spawned at the palace Royal Jelly")
    expect(spawn.api=="spawn_entity_snapped_to_floor","the palace reward was not snapped to the floor")
    expect(game:materialized("CHECK_TUSK_PALACE_VISIT"),"the palace check was not marked materialized")

    local jelly=neo_babylon(game,2,{{"ITEM_PICKUP_ROYALJELLY",x=12,y=40,layer=LAYER.BACK}})[1]
    expect(game:entity(jelly.uid),"a back-layer Royal Jelly on Neo Babylon 6-2 was replaced")
    jelly=game:start_level{theme=THEME.JUNGLE,world=2,level=3,entities={{"ITEM_PICKUP_ROYALJELLY",x=12,y=40,layer=LAYER.BACK}}}[1]
    expect(game:entity(jelly.uid),"a back-layer Royal Jelly in the Jungle was replaced")
    expect(#game:spawned_of("ITEM_PICKUP_SKELETON_KEY")==1,"a reward was spawned outside the anchor's theme or level")
end,{CHECK_TUSK_PALACE_VISIT="REWARD_SKELETON_KEY"})

scenario("an item anchor replaces its source when the game spawns it after generation",function(game)
    neo_babylon(game,2)
    local wrong_level=game:native_spawn("ITEM_PICKUP_ROYALJELLY",{x=12,y=40,layer=LAYER.BACK})
    expect(game:entity(wrong_level).type.id==game.ENT_TYPE.ITEM_PICKUP_ROYALJELLY,"a Royal Jelly spawned on 6-2 was replaced")

    neo_babylon(game,3)
    local front=game:native_spawn("ITEM_PICKUP_ROYALJELLY",{x=30,y=40,layer=LAYER.FRONT})
    expect(game:entity(front).type.id==game.ENT_TYPE.ITEM_PICKUP_ROYALJELLY,"a front-layer Royal Jelly spawn was replaced")
    local back=game:native_spawn("ITEM_PICKUP_ROYALJELLY",{x=12,y=40,layer=LAYER.BACK})
    expect(game:entity(back).type.id==game.ENT_TYPE.ITEM_PICKUP_SKELETON_KEY,"the palace Royal Jelly spawn was not replaced by the mapped reward")
    expect_spawn(game,"ITEM_PICKUP_SKELETON_KEY",12,40,LAYER.BACK,"the palace reward was not spawned in place of the Royal Jelly")
    expect(game:materialized("CHECK_TUSK_PALACE_VISIT"),"the palace check was not marked materialized")
end,{CHECK_TUSK_PALACE_VISIT="REWARD_SKELETON_KEY"})

local function olmec_drop(game)
    return game:entity(game:drop("OLMEC_SISTERS_BOMBBOX","ITEM_PICKUP_BOMBBOX",{x=5,y=5})).type.id
end

scenario("an engine drop is substituted only in its theme",function(game)
    olmec(game)
    expect(olmec_drop(game)==game.ENT_TYPE.ITEM_PICKUP_SKELETON_KEY,"the Sisters' Bomb Box drop was not substituted at Olmec")
    expect(game:logged("Sisters Bomb Box drop configured: CHECK_SISTERS_OLMEC_REWARD -> REWARD_SKELETON_KEY"),"the substitution was not reported")

    game:start_level{theme=THEME.TIDE_POOL,world=4,level=1}
    expect(olmec_drop(game)==game.ENT_TYPE.ITEM_PICKUP_BOMBBOX,"the Sisters' substitution stayed armed outside Olmec")
    local jelly=game:drop("QUEENBEE_ROYALJELLY","ITEM_PICKUP_ROYALJELLY",{x=5,y=5})
    expect(game:entity(jelly).type.id==game.ENT_TYPE.ITEM_PICKUP_CROWN,"the theme-free Queen Bee substitution was disarmed outside the Jungle")
end,{CHECK_SISTERS_OLMEC_REWARD="REWARD_SKELETON_KEY",CHECK_QUEEN_BEE="REWARD_CROWN"})

scenario("a run-flagged engine drop is disarmed once its flag is set",function(game)
    local function kapala() return game:entity(game:drop("ALTAR_KAPALA","ITEM_PICKUP_KAPALA",{x=5,y=5})).type.id end
    game:start_level{theme=THEME.DWELLING,world=1,level=2}
    expect(kapala()==game.ENT_TYPE.ITEM_PICKUP_ANKH,"the Kapala drop was not substituted before its flag was set")
    game.ctx.kali_second_gift_completed=true
    game:start_level{theme=THEME.DWELLING,world=1,level=3}
    expect(kapala()==game.ENT_TYPE.ITEM_PICKUP_KAPALA,"the Kapala substitution stayed armed after its run flag was set")
end,{CHECK_KALI_ALTAR_2="REWARD_ANKH"})

local function quillback_level(game)
    return game:start_level{theme=THEME.DWELLING,world=1,level=4,entities={{"MONS_CAVEMAN_BOSS",x=10,y=20}}}[1]
end

scenario("a boss's native death drop is replaced once, and the fallback does not add another",function(game)
    local boss=quillback_level(game)
    boss.x,boss.y=14,22
    boss:kill()
    local reward=game:native_spawn("ITEM_PICKUP_BOMBBAG",{x=14,y=21})
    expect(game:entity(reward).type.id==game.ENT_TYPE.ITEM_PICKUP_ANKH,"Quillback's native Bomb Bag was not replaced")
    game:frames(10)
    expect(#game:spawned_of("ITEM_PICKUP_ANKH")==1,"the fallback delivered a second reward after the native drop")
    expect(#game:spawned_of("ITEM_PICKUP_BOMBBAG")==0 and #get_entities_by_type(game.ENT_TYPE.ITEM_PICKUP_BOMBBAG)==0,"a native Bomb Bag remains beside the reward")
    expect(game:materialized("CHECK_QUILLBACK"),"the check was not marked materialized")
end,{CHECK_QUILLBACK="REWARD_ANKH"})

scenario("a boss reward falls back to the boss's last position when no native drop appears",function(game)
    local boss=quillback_level(game)
    boss.x,boss.y=14,22
    boss:kill()
    game:frames(1)
    expect(#game:spawned_of("ITEM_PICKUP_ANKH")==0,"the fallback fired before the native drop could arrive")
    game:frames(10)
    expect_spawn(game,"ITEM_PICKUP_ANKH",14,22,LAYER.FRONT,"the fallback reward was not placed at Quillback's last position")
    expect(game:materialized("CHECK_QUILLBACK"),"the check was not marked materialized")
    local late=game:native_spawn("ITEM_PICKUP_BOMBBAG",{x=14,y=21})
    expect(game:entity(late).type.id==game.ENT_TYPE.ITEM_PICKUP_BOMBBAG,"a Bomb Bag after the fallback was replaced again")
    expect(#game:spawned_of("ITEM_PICKUP_ANKH")==1,"the reward was delivered twice")
end,{CHECK_QUILLBACK="REWARD_ANKH"})

local function yang_level(game,entities)
    table.insert(entities,1,{"MONS_YANG",x=20,y=30})
    return game:start_level{theme=THEME.DWELLING,world=1,level=2,entities=entities}
end

scenario("Yang's reward is anchored beside the locked-pen door nearest him horizontally",function(game)
    yang_level(game,{
        {"FLOOR_DOOR_LOCKED_PEN",x=23,y=30},
        {"FLOOR_DOOR_LOCKED_PEN",x=18,y=12},
    })
    local spawn=expect_spawn(game,"ITEM_PICKUP_ANKH",17,12,LAYER.BACK,"Yang's reward is not beside the horizontally nearest locked-pen door")
    expect(spawn.api=="spawn_entity_snapped_to_floor","Yang's reward was not snapped to the floor")
    expect(game:materialized("CHECK_YANG"),"the Yang check was not marked materialized")
end,{CHECK_YANG="REWARD_ANKH"})

-- Regression for 283ea67 and 1312e60: Yang's pen is not always five rows
-- below him, and generic doors on that row are not his reward door.
scenario("Yang's reward follows his locked-pen door, not the doors on the row five below him",function(game)
    yang_level(game,{
        {"FLOOR_DOOR_LAYER",x=21,y=25},
        {"BG_DOOR_BACK_LAYER",x=21,y=25,layer=LAYER.BACK},
        {"FLOOR_DOOR_LOCKED",x=19,y=25},
        {"FLOOR_DOOR_LOCKED_PEN",x=26,y=23},
    })
    expect_spawn(game,"ITEM_PICKUP_ANKH",27,23,LAYER.BACK,"Yang's reward is not beside his locked-pen door")
end,{CHECK_YANG="REWARD_ANKH"})

-- Regression for 61a51c6: without the pen, Yang's own position is not a
-- safe anchor, so the check is left unplaced.
scenario("Yang's check is not placed without a locked-pen door, and the failure is logged",function(game)
    yang_level(game,{{"FLOOR_DOOR_LAYER",x=21,y=25}})
    expect(#game.spawned==0,"a Yang reward was placed without a locked-pen door")
    expect(not game:materialized("CHECK_YANG"),"the Yang check was marked materialized")
    expect(game:logged("Yang reward anchor found no native locked-pen door; Yang check was not placed"),"the missing anchor was not logged")
    expect(game:logged("Yang anchor diagnostic FLOOR_DOOR_LAYER"),"the nearby doors were not reported")
end,{CHECK_YANG="REWARD_ANKH"})

local function excalibur_level(game,level,entities)
    return game:start_level{theme=THEME.TIDE_POOL,world=4,level=level or 2,entities=entities or {{"ITEM_EXCALIBUR",x=0.5,y=1,abs_x=31,abs_y=44}}}
end

-- Regression for 1fa7a93: a Crown the mod did not place opens the gate.
scenario("Excalibur's gate opens when a player holds a Crown",function(game)
    local player=game:add_player{x=1,y=1}
    game:place("ITEM_PICKUP_CROWN",{holder=player})
    local sword=excalibur_level(game)[1]
    game:frames(10)
    expect(not game:entity(sword.uid),"the sword-in-stone was not removed")
    expect_spawn(game,"ITEM_PICKUP_ANKH",31,44,LAYER.FRONT,"the mapped reward was not placed at the sword's absolute position")
    expect(game:materialized("CHECK_EXCALIBUR_STONE"),"the Excalibur check was not marked materialized")
end,{CHECK_EXCALIBUR_STONE="REWARD_ANKH"})

scenario("Excalibur's gate opens when a player holds a Hedjet, checked again at the start of a run",function(game)
    local sword=excalibur_level(game)[1]
    game.checks.replace_excalibur_if_gated(game.ctx)
    expect(game:entity(sword.uid),"the sword was replaced before any player held a Crown or Hedjet")
    game:place("ITEM_PICKUP_HEDJET",{holder=game:add_player{x=1,y=1}})
    game.checks.replace_excalibur_if_gated(game.ctx)
    expect(not game:entity(sword.uid),"the sword was not replaced once a player held a Hedjet")
    expect_spawn(game,"ITEM_PICKUP_ANKH",31,44,LAYER.FRONT,"the mapped reward was not placed at the sword")
end,{CHECK_EXCALIBUR_STONE="REWARD_ANKH"})

scenario("Excalibur's gate stays closed unless a player's inventory holds a Crown or Hedjet",function(game)
    game:place("ITEM_PICKUP_ANKH",{holder=game:add_player{x=1,y=1}})
    local sword=excalibur_level(game,2,{
        {"ITEM_EXCALIBUR",x=0.5,y=1,abs_x=31,abs_y=44},
        {"ITEM_PICKUP_CROWN",x=8,y=8},
        {"ITEM_PICKUP_HEDJET",x=9,y=8},
    })[1]
    game:frames(200)
    expect(game:entity(sword.uid) and #game.spawned==0,"the sword was replaced with no Crown or Hedjet in a player's inventory")
    expect(game:logged("Excalibur gate is closed: no player holds a Crown or Hedjet"),"the closed gate was not reported")
end,{CHECK_EXCALIBUR_STONE="REWARD_ANKH"})

scenario("Excalibur does nothing outside Tide Pool 4-2",function(game)
    game:place("ITEM_PICKUP_CROWN",{holder=game:add_player{x=1,y=1}})
    for _,level in ipairs({1,3}) do
        local sword=excalibur_level(game,level)[1]
        game:frames(200)
        game.checks.replace_excalibur_if_gated(game.ctx)
        expect(game:entity(sword.uid),"a sword on Tide Pool 4-"..level.." was replaced")
    end
    expect(#game.spawned==0 and not game:logged("Excalibur gate"),"Excalibur ran outside Tide Pool 4-2")
end,{CHECK_EXCALIBUR_STONE="REWARD_ANKH"})

scenario("Excalibur leaves a carried sword alone and replaces the sword-in-stone",function(game)
    local player=game:add_player{x=1,y=1}
    game:place("ITEM_PICKUP_CROWN",{holder=player})
    local carried=game:place("ITEM_EXCALIBUR",{holder=player})
    local stone=excalibur_level(game)[1]
    game:frames(10)
    expect(game:entity(carried.uid) and carried.holder==player,"the carried sword was replaced")
    expect(game:logged("Ignored player_carried source uid "..carried.uid),"the carried sword was not reported")
    expect(not game:entity(stone.uid),"the sword-in-stone beside a carried sword was not replaced")
    expect_spawn(game,"ITEM_PICKUP_ANKH",31,44,LAYER.FRONT,"the mapped reward was not placed at the sword-in-stone")
end,{CHECK_EXCALIBUR_STONE="REWARD_ANKH"})

scenario("Excalibur retries until the sword-in-stone spawns",function(game)
    game:place("ITEM_PICKUP_CROWN",{holder=game:add_player{x=1,y=1}})
    excalibur_level(game,2,{})
    game:frames(30)
    expect(game:logged("Excalibur gate is open, but the sword has not spawned yet; retrying"),"the missing sword was not reported")
    local sword=game:place("ITEM_EXCALIBUR",{x=0.5,y=1,abs_x=31,abs_y=44})
    game:frames(5)
    expect(not game:entity(sword.uid),"a late sword-in-stone was not replaced by a retry")
    expect_spawn(game,"ITEM_PICKUP_ANKH",31,44,LAYER.FRONT,"the retry did not place the mapped reward at the sword")
end,{CHECK_EXCALIBUR_STONE="REWARD_ANKH"})

scenario("Excalibur fails its check once its retries are exhausted",function(game)
    game:place("ITEM_PICKUP_CROWN",{holder=game:add_player{x=1,y=1}})
    excalibur_level(game,2,{})
    game:frames(150)
    expect(not game.ctx.lifecycle.failures.CHECK_EXCALIBUR_STONE,"the check failed before its retries were exhausted")
    game:frames(20)
    expect(game.ctx.lifecycle.failures.CHECK_EXCALIBUR_STONE,"the check did not fail after its retries were exhausted")
    expect(game:logged("CHECK CHECK_EXCALIBUR_STONE failed: gate was open but no native sword-in-stone appeared after retries"),"the failure was not logged")
    expect(#game.timeouts==0,"Excalibur kept retrying after failing")
    expect(#game.spawned==0,"a reward was spawned without a sword")
end,{CHECK_EXCALIBUR_STONE="REWARD_ANKH"})

local ALTAR_X,ALTAR_Y=20,10

-- A Dwelling level with a Kali altar; the run's player stands beside it.
local function altar_level(game,level,entities)
    if #game.players==0 then game:add_player{x=ALTAR_X+1,y=ALTAR_Y+1} end
    local placed=game:start_level{theme=THEME.DWELLING,world=1,level=level,entities={{"FLOOR_ALTAR",x=ALTAR_X,y=ALTAR_Y},table.unpack(entities or {})}}
    game:frames(1)
    return placed
end

-- Kali raises the gift counter and emits her native items at the altar in
-- the same frame; the adapter sees both on that frame's ON.FRAME.
local function kali_gift(game,gifts,emitted)
    game.state.kali_gifts=gifts
    local uids={}
    for index,name in ipairs(emitted or {}) do
        table.insert(uids,game:native_spawn(name,{x=ALTAR_X+index-1,y=ALTAR_Y+1}))
    end
    game:frames(1)
    return table.unpack(uids)
end

scenario("Kali's first gift is replaced by the mapped reward one frame later",function(game)
    altar_level(game,2,{{"ITEM_PICKUP_BOMBBAG",x=ALTAR_X+10,y=ALTAR_Y+1}})
    local gift,extra=kali_gift(game,1,{"ITEM_PICKUP_ROPEPILE","ITEM_PICKUP_BOMBBAG"})
    expect(game:entity(gift) and #game:spawned_of("ITEM_JETPACK")==0,"the first gift was replaced before the next frame")
    game:frames(1)
    local rewards=game:spawned_of("ITEM_JETPACK")
    expect(not game:entity(gift),"the native first gift was not removed")
    expect(#rewards==1 and rewards[1].x==ALTAR_X and rewards[1].y==ALTAR_Y+1,"the mapped reward was not spawned at the native gift")
    expect(game:materialized("CHECK_KALI_ALTAR_1"),"the first altar check was not marked materialized")
    expect(not game:entity(extra),"an extra native item emitted with the gift was left at the altar")
    game:frames(3)
    expect(#get_entities_by_type(game.ENT_TYPE.ITEM_PICKUP_BOMBBAG)==1,"an item away from the altar was removed")
    expect(#game:spawned_of("ITEM_JETPACK")==1,"the first altar check materialized more than once")
end,{CHECK_KALI_ALTAR_1="REWARD_JETPACK"})

local function deliver_first_gift(game)
    local delivered=#game:spawned_of("ITEM_JETPACK")
    local gift=kali_gift(game,game.state.kali_gifts+1,{"ITEM_PICKUP_ROPEPILE"})
    game:frames(4)
    expect(not game:entity(gift) and #game:spawned_of("ITEM_JETPACK")==delivered+1,"the first gift was not replaced")
end

-- Regression for f1fc59f: the first altar check was guarded per level, so a
-- later gift on another altar level was replaced a second time.
scenario("Kali's first altar check is delivered once per run",function(game)
    altar_level(game,2)
    deliver_first_gift(game)
    local second=kali_gift(game,2,{"ITEM_PICKUP_BOMBBAG"})
    game:frames(4)
    expect(game:entity(second),"a later gift on the same level was replaced")

    altar_level(game,3)
    local later=kali_gift(game,3,{"ITEM_PICKUP_BOMBBAG"})
    game:frames(4)
    expect(game:entity(later),"a gift on a later altar level was replaced")
    expect(#game:spawned_of("ITEM_JETPACK")==1,"the first altar reward was delivered twice in one run")

    game.state.kali_gifts=0
    game:fire(ON.START)
    altar_level(game,1)
    deliver_first_gift(game)
end,{CHECK_KALI_ALTAR_1="REWARD_JETPACK"})

-- Regression for f1fc59f: a counter jump across the Kapala threshold made
-- the first-gift scan claim the Kapala.
scenario("Kali's first altar check never claims the Kapala",function(game)
    altar_level(game,2)
    expect(game.drops.ALTAR_KAPALA==game.ENT_TYPE.ITEM_PICKUP_KAPALA,"the Kapala drop was not armed")
    game.state.kali_gifts=3
    local kapala=game:drop("ALTAR_KAPALA","ITEM_PICKUP_KAPALA",{x=ALTAR_X,y=ALTAR_Y+1})
    game:frames(4)
    expect(game:entity(kapala),"the first altar check claimed the Kapala")
    expect(not game:materialized("CHECK_KALI_ALTAR_1") and #game:spawned_of("ITEM_JETPACK")==0,"the Kapala materialized the first altar check")

    local gift=kali_gift(game,4,{"ITEM_PICKUP_ROPEPILE"})
    game:frames(1)
    expect(not game:entity(gift) and #game:spawned_of("ITEM_JETPACK")==1,"the first altar check was not available after the Kapala")
    expect(game:entity(kapala),"the Kapala was removed as an extra first-gift item")
end,{CHECK_KALI_ALTAR_1="REWARD_JETPACK",CHECK_KALI_ALTAR_2="REWARD_KAPALA"})

-- Regression for c0391b7: the Kapala drop stayed armed after the counter
-- crossed its threshold, so a later level's Kapala was replaced again.
scenario("Kali's Kapala is substituted once and disarmed for the run",function(game)
    altar_level(game,2)
    expect(game.drops.ALTAR_KAPALA==game.ENT_TYPE.ITEM_PICKUP_CROWN,"the Kapala drop was not armed with the mapped reward")
    deliver_first_gift(game)
    game.state.kali_gifts=3
    local reward=game:drop("ALTAR_KAPALA","ITEM_PICKUP_KAPALA",{x=ALTAR_X,y=ALTAR_Y+1})
    game:frames(4)
    expect(game:entity(reward).type.id==game.ENT_TYPE.ITEM_PICKUP_CROWN,"the Kapala was not substituted by the mapped reward")
    expect(game:entity(reward),"the first-gift scan removed the substituted Kapala")
    expect(game:logged("Kali Kapala check completed"),"crossing the Kapala threshold was not recorded")

    altar_level(game,3)
    expect(game.drops.ALTAR_KAPALA==nil,"the Kapala drop is still armed on a later level")
    local native=game:drop("ALTAR_KAPALA","ITEM_PICKUP_KAPALA",{x=ALTAR_X,y=ALTAR_Y+1})
    expect(game:entity(native).type.id==game.ENT_TYPE.ITEM_PICKUP_KAPALA,"a later Kapala was substituted again")

    game:fire(ON.START)
    altar_level(game,1)
    expect(game.drops.ALTAR_KAPALA==game.ENT_TYPE.ITEM_PICKUP_CROWN,"a new run did not rearm the Kapala drop")
end,{CHECK_KALI_ALTAR_1="REWARD_JETPACK",CHECK_KALI_ALTAR_2="REWARD_CROWN"})

local function kali_present(game)
    local presents=game:spawned_of("ITEM_PRESENT")
    return presents[#presents] and game:entity(presents[#presents].uid)
end

-- Kali turns a Present sacrificed on her altar into an Eggplant at the same
-- spot.
local function sacrifice(game,present)
    present.x,present.y=ALTAR_X,ALTAR_Y+1
    present:destroy()
    local eggplant=game:native_spawn("ITEM_EGGPLANT",{x=present.x,y=present.y})
    game:frames(1)
    return eggplant
end

scenario("Kali's Present is placed on the first altar level with a pet",function(game)
    altar_level(game,2)
    expect(#game:spawned_of("ITEM_PRESENT")==0,"a Present was placed without a pet to replace")
    expect(game:logged("Kali Present altar level has no pet"),"the missing pet was not reported")

    game:start_level{theme=THEME.DWELLING,world=1,level=3,entities={{"MONS_PET_DOG",x=5,y=6}}}
    expect(#game:spawned_of("ITEM_PRESENT")==0,"a Present was placed on a level without an altar")

    local dog=altar_level(game,4,{{"MONS_PET_DOG",x=5,y=6}})[2]
    local present=kali_present(game)
    expect(present and present.x==5 and present.y==6,"the Present was not placed at the pet")
    expect(not game:entity(dog.uid),"the pet was left beside its Present")
    expect(present.inside==game.ENT_TYPE.ITEM_DIAMOND,"the Present source does not hold a Diamond")
end,{CHECK_KALI_PRESENT="REWARD_CLONE_GUN"})

scenario("sacrificing Kali's Present delivers the mapped reward once per run",function(game)
    altar_level(game,2,{{"MONS_PET_CAT",x=5,y=6}})
    local eggplant=sacrifice(game,kali_present(game))
    game:frames(1)
    local rewards=game:spawned_of("ITEM_CLONEGUN")
    expect(not game:entity(eggplant),"the native Eggplant payload was left at the altar")
    expect(#rewards==1 and rewards[1].x==ALTAR_X and rewards[1].y==ALTAR_Y+1,"the mapped reward was not delivered in place of the Eggplant")
    expect(game:entity(rewards[1].uid),"the Present's reward was removed after delivery")
    expect(game:materialized("CHECK_KALI_PRESENT"),"the Present check was not marked materialized")
    game:frames(5)
    expect(game:entity(rewards[1].uid),"the Present's reward was removed after delivery")
    expect(not game:materialized("CHECK_KALI_ALTAR_1"),"the Present's Eggplant materialized the first altar check")

    altar_level(game,3,{{"MONS_PET_DOG",x=5,y=6}})
    expect(#game:spawned_of("ITEM_PRESENT")==1,"a second Present was placed after delivery")
end,{CHECK_KALI_PRESENT="REWARD_CLONE_GUN",CHECK_KALI_ALTAR_1="REWARD_JETPACK"})

scenario("a Present broken away from Kali's altar delivers nothing",function(game)
    altar_level(game,2,{{"MONS_PET_CAT",x=5,y=6}})
    local present=kali_present(game)
    present:destroy()
    game:frames(12)
    expect(#game:spawned_of("ITEM_CLONEGUN")==0,"a Present broken away from the altar delivered its reward")

    altar_level(game,3,{{"MONS_PET_DOG",x=5,y=6}})
    expect(#game:spawned_of("ITEM_PRESENT")==2,"no fresh Present was offered on the next altar level")
end,{CHECK_KALI_PRESENT="REWARD_CLONE_GUN"})

-- The Present is sacrificed while an ordinary gift's replacement is pending,
-- so its Eggplant is new at the altar when the first-gift scan runs.
scenario("Kali's first gift never claims a sacrificed Present's Eggplant",function(game)
    altar_level(game,2,{{"MONS_PET_CAT",x=5,y=6}})
    local present=kali_present(game)
    local gift=kali_gift(game,1,{"ITEM_PICKUP_ROPEPILE"})
    local eggplant=sacrifice(game,present)
    expect(game:materialized("CHECK_KALI_ALTAR_1"),"the first gift was not replaced")
    expect(not game:entity(gift) and #game:spawned_of("ITEM_JETPACK")==1,"the ordinary gift was not delivered as the first altar reward")
    game:frames(1)
    local rewards=game:spawned_of("ITEM_CLONEGUN")
    expect(not game:entity(eggplant) and #rewards==1,"the Present's Eggplant was not delivered as the Present reward")
    expect(rewards[1].x==ALTAR_X and rewards[1].y==ALTAR_Y+1 and game:entity(rewards[1].uid),"the Present reward is not where its Eggplant was")
end,{CHECK_KALI_PRESENT="REWARD_CLONE_GUN",CHECK_KALI_ALTAR_1="REWARD_JETPACK"})

-- Regression for 7c6f992: the first altar check fired only on the counter's
-- first increase, so a Present sacrificed first used it up.
scenario("Kali's first altar check is still awarded after the Present",function(game)
    altar_level(game,2,{{"MONS_PET_CAT",x=5,y=6}})
    sacrifice(game,kali_present(game))
    game:frames(5)
    expect(#game:spawned_of("ITEM_CLONEGUN")==1,"the Present reward was not delivered")

    altar_level(game,3)
    local gift=kali_gift(game,1,{"ITEM_PICKUP_ROPEPILE"})
    game:frames(1)
    expect(not game:entity(gift) and #game:spawned_of("ITEM_JETPACK")==1,"the first altar check was not awarded after the Present")
end,{CHECK_KALI_PRESENT="REWARD_CLONE_GUN",CHECK_KALI_ALTAR_1="REWARD_JETPACK"})

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
