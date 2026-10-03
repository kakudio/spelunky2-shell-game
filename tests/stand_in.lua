-- Scripted stand-in for the Overlunky API, used to drive the shipped adapter
-- modules outside the game. It records spawns, destroys and callbacks; it
-- never simulates the game, so callbacks run only when a scenario fires them.

local M={}

local MOD_MODULES={
    "logic", "placements", "replacement_policy", "adapters", "check_lifecycle",
    "runtime_state", "sparrow_adapter", "duat_adapter", "checks",
}

M.THEME={
    DWELLING=1, JUNGLE=2, VOLCANA=3, OLMEC=4, TIDE_POOL=5, TEMPLE=6, ICE_CAVES=7,
    NEO_BABYLON=8, SUNKEN_CITY=9, COSMIC_OCEAN=10, CITY_OF_GOLD=11, DUAT=12,
    ABZU=13, TIAMAT=14, EGGPLANT_WORLD=15, HUNDUN=16, BASE_CAMP=17, ARENA=18,
}
M.LAYER={FRONT=0, BACK=1, BOTH=-128}
M.MASK={
    ANY=0, PLAYER=1, MOUNT=2, MONSTER=4, ITEM=8, EXPLOSION=16, ROPE=32, FX=64,
    ACTIVEFLOOR=128, FLOOR=256, DECORATION=512, BG=1024, SHADOW=2048,
    LOGICAL=4096, WATER=8192, LAVA=16384,
}
M.SPAWN_TYPE={LEVEL_GEN=1, LEVEL_GEN_TILE_CODE=2, LEVEL_GEN_PROCEDURAL=4, LEVEL_GEN_FLOOR_SPREADING=8, LEVEL_GEN_GENERAL=16, SCRIPT=32, SYSTEMIC=64, ANY=127}

local MASK_BY_PREFIX={
    {"CHAR_","PLAYER"}, {"MOUNT_","MOUNT"}, {"MONS_","MONSTER"}, {"ITEM_","ITEM"},
    {"FX_","FX"}, {"ACTIVEFLOOR_","ACTIVEFLOOR"}, {"FLOOR_","FLOOR"},
    {"DECORATION_","DECORATION"}, {"BG_","BG"}, {"LOGICAL_","LOGICAL"},
}

-- Unknown names resolve to fresh ids or to their own name, so a module may
-- name any constant without the stand-in listing it.
local function numbered(start)
    local next_id=start
    return setmetatable({},{__index=function(t,name)
        if type(name)~="string" then return nil end
        rawset(t,name,next_id)
        next_id=next_id+1
        return next_id-1
    end})
end
local function named()
    return setmetatable({},{__index=function(t,name) rawset(t,name,name); return name end})
end

local Entity={}
Entity.__index=Entity

function Entity:destroy() self.game:_remove(self,"destroy") end
function Entity:remove() self.game:_remove(self,"remove") end
function Entity:kill(destroy_corpse,responsible) return self.game:kill(self,destroy_corpse,responsible) end
function Entity:set_pre_kill(callback) table.insert(self.pre_kill_hooks,callback) end
function Entity:set_pre_destroy(callback) table.insert(self.pre_destroy_hooks,callback) end
function Entity:get_items()
    local uids={}
    for _,item in ipairs(self.items) do table.insert(uids,item.uid) end
    return uids
end
function Entity:has_powerup(powerup_type) return self.powerups[powerup_type]==true end
function Entity:give_powerup(powerup_type) self.powerups[powerup_type]=true end
function Entity:get_held_entity() return self.held end
function Entity:as_playerbag() return self end
function Entity:is_cursed() return self.cursed==true end
function Entity:set_cursed(cursed) self.cursed=cursed end

local Game={}
Game.__index=Game

function M.new(config)
    config=config or {}
    local game=setmetatable({
        frame_count=0, next_uid=1, entities={}, order={},
        callbacks={}, pre_spawn_hooks={}, post_spawn_hooks={}, timeouts={},
        spawned={}, destroyed={}, killed={}, drops={}, shop_items={}, picked_up={}, logs={},
        saved_globals={}, players={},
    },Game)
    game.state={
        theme=config.theme or M.THEME.DWELLING, world=config.world or 1, level=config.level or 1,
        theme_next=0, quests={}, logic={}, kali_gifts=0, kali_favor=0, room_owners={owned_items={}},
    }
    game.ENT_TYPE=numbered(1000)
    for _,name in ipairs(config.missing_types or {}) do rawset(game.ENT_TYPE,name,false) end
    game:_install(config.globals or {})
    local ok,message=pcall(game._load_mod,game,config)
    if not ok then
        game:close()
        error(message,0)
    end
    return game
end

function Game:_install(overrides)
    local game=self
    local ENT_TYPE=setmetatable({},{__index=function(_,name)
        local id=game.ENT_TYPE[name]
        return id or nil
    end})
    local globals={
        state=self.state, players=self.players,
        ENT_TYPE=ENT_TYPE, THEME=M.THEME, LAYER=M.LAYER, MASK=M.MASK, SPAWN_TYPE=M.SPAWN_TYPE,
        ON=named(), DROP=named(), ENT_FLAG=numbered(1),
        get_entity=function(uid) return game:entity(uid) end,
        get_position=function(uid)
            local entity=game:entity(uid)
            if entity then return entity.x,entity.y,entity.layer end
        end,
        get_entities_by=function(types,mask,layer) return game:_query(types,mask,layer) end,
        get_entities_by_type=function(first,...)
            local types=type(first)=="table" and first or {first,...}
            return game:_query(types,M.MASK.ANY,M.LAYER.BOTH)
        end,
        get_entity_name=function(entity_type) return game:type_name(entity_type) end,
        entity_has_item_uid=function(holder_uid,item_uid)
            local holder=game:entity(holder_uid)
            for _,item in ipairs(holder and holder.items or {}) do
                if item.uid==item_uid then return true end
            end
            return false
        end,
        entity_has_item_type=function(holder_uid,entity_type)
            local holder=game:entity(holder_uid)
            for _,item in ipairs(holder and holder.items or {}) do
                if item.type.id==entity_type then return true end
            end
            return false
        end,
        spawn_entity=function(entity_type,x,y,layer) return game:_spawn("spawn_entity",entity_type,x,y,layer,true) end,
        spawn_entity_snapped_to_floor=function(entity_type,x,y,layer) return game:_spawn("spawn_entity_snapped_to_floor",entity_type,x,y,layer,true) end,
        spawn_entity_nonreplaceable=function(entity_type,x,y,layer) return game:_spawn("spawn_entity_nonreplaceable",entity_type,x,y,layer,false) end,
        set_pre_entity_spawn=function(callback,_,mask,...) return game:_hook(game.pre_spawn_hooks,callback,mask,...) end,
        set_post_entity_spawn=function(callback,_,mask,...) return game:_hook(game.post_spawn_hooks,callback,mask,...) end,
        set_callback=function(callback,event)
            game.callbacks[event]=game.callbacks[event] or {}
            table.insert(game.callbacks[event],callback)
        end,
        set_timeout=function(callback,frames)
            table.insert(game.timeouts,{due=game.frame_count+math.max(frames or 1,1),callback=callback})
        end,
        get_frame=function() return game.frame_count end,
        replace_drop=function(drop,entity_type) game.drops[drop]=entity_type~=0 and entity_type or nil end,
        add_item_to_shop=function(item_uid,owner_uid) table.insert(game.shop_items,{uid=item_uid,owner=owner_uid}) end,
        pick_up=function(who,what) table.insert(game.picked_up,{who=who,what=what}) end,
        is_inside_active_shop_room=function() return false end,
        test_flag=function(flags,index) return (flags or 0)&(1<<(index-1))~=0 end,
        set_flag=function(flags,index) return (flags or 0)|(1<<(index-1)) end,
        clr_flag=function(flags,index) return (flags or 0)&~(1<<(index-1)) end,
    }
    for name,value in pairs(overrides) do globals[name]=value end
    for name,value in pairs(globals) do
        self.saved_globals[name]={value=rawget(_G,name)}
        rawset(_G,name,value)
    end
end

local function unload_mod()
    for _,name in ipairs(MOD_MODULES) do package.loaded[name]=nil end
end

-- Mirrors main.lua's runtime wiring without its options or console commands.
function Game:_load_mod(config)
    unload_mod()
    local game=self
    self.placements=require "placements"
    self.adapters=require "adapters"
    self.lifecycle=require "check_lifecycle"
    self.runtime=require "runtime_state"
    self.checks=require "checks"
    self.randomizer_state={seed=config.seed or 1,mapping=config.mapping or {},initialized=true,level_materialized={}}
    local enabled=function(name) return function() return config[name]~=false end end
    self.ctx=self.runtime.new(self.randomizer_state,function() end,function(message) table.insert(game.logs,message) end,
        enabled("kali_item_recovery"),enabled("balanced_duat_kali_rewards"),enabled("true_crown_restoration"))
    set_callback(function()
        game.runtime.reset_level(game.ctx)
        game.checks.on_pre_level_generation(game.ctx)
    end,ON.PRE_LEVEL_GENERATION)
    self.checks.register_spawn_hooks(self.ctx)
    set_callback(function()
        game.runtime.reset_run(game.ctx)
        game.checks.replace_excalibur_if_gated(game.ctx)
    end,ON.START)
    set_callback(function()
        game.checks.on_balance_post_level_generation(game.ctx)
        game.checks.on_post_level_generation(game.ctx)
    end,ON.POST_LEVEL_GENERATION)
end

function Game:close()
    unload_mod()
    for name,saved in pairs(self.saved_globals) do rawset(_G,name,saved.value) end
    self.saved_globals={}
end

function Game:type_id(name_or_id)
    if type(name_or_id)=="number" then return name_or_id end
    return self.ENT_TYPE[name_or_id] or error("entity type "..tostring(name_or_id).." is missing in this scenario",3)
end

function Game:type_name(entity_type)
    for name,id in pairs(self.ENT_TYPE) do
        if id==entity_type then return name end
    end
    return tostring(entity_type)
end

function Game:mask_of(entity_type)
    local name=self:type_name(entity_type)
    for _,entry in ipairs(MASK_BY_PREFIX) do
        if name:sub(1,#entry[1])==entry[1] then return M.MASK[entry[2]] end
    end
    return 0
end

function Game:entity(uid)
    local entity=uid and self.entities[uid]
    return entity and entity.alive and entity or nil
end

-- Stages an entity silently, as level generation would have left it. Any
-- field (abs_x, inside, health, set_pre_destroy, as_playerbag...) may be set.
function Game:place(type_name,fields)
    fields=fields or {}
    local entity_type=self:type_id(type_name)
    local uid=self.next_uid
    self.next_uid=uid+1
    local x,y=fields.x or 0,fields.y or 0
    local entity=setmetatable({
        game=self, uid=uid, type={id=entity_type}, alive=true,
        x=x, y=y, abs_x=x, abs_y=y, layer=M.LAYER.FRONT, flags=0,
        items={}, powerups={}, pre_kill_hooks={}, pre_destroy_hooks={},
    },Entity)
    for key,value in pairs(fields) do
        if key~="holder" then entity[key]=value end
    end
    self.entities[uid]=entity
    table.insert(self.order,uid)
    if fields.holder then self:give(fields.holder,entity) end
    return entity
end

function Game:add_player(fields)
    local player=self:place("CHAR_ANA_SPELUNKY",fields)
    table.insert(self.players,player)
    return player
end

function Game:give(holder,item)
    table.insert(holder.items,item)
    item.holder=holder
    item.x,item.y,item.layer=holder.x,holder.y,holder.layer
    return item
end

-- A worn pickup (Crown, Hedjet...) is a powerup on its wearer, not an item.
function Game:wear(player,powerup_name)
    player:give_powerup(self:type_id(powerup_name))
end

function Game:_remove(entity,how)
    if not entity.alive then return end
    for _,hook in ipairs(entity.pre_destroy_hooks) do hook(entity) end
    entity.alive=false
    if entity.holder then
        for index,item in ipairs(entity.holder.items) do
            if item==entity then table.remove(entity.holder.items,index) break end
        end
    end
    table.insert(self.destroyed,{uid=entity.uid,type=entity.type.id,name=self:type_name(entity.type.id),how=how})
end

function Game:_query(types,mask,layer)
    local wanted
    if type(types)=="table" and #types>0 then
        wanted={}
        for _,entity_type in ipairs(types) do wanted[entity_type]=true end
    elseif type(types)=="number" and types~=0 then
        wanted={[types]=true}
    end
    local uids={}
    for _,uid in ipairs(self.order) do
        local entity=self.entities[uid]
        if entity.alive and (not wanted or wanted[entity.type.id])
            and (not mask or mask==0 or self:mask_of(entity.type.id)&mask~=0)
            and (not layer or layer==M.LAYER.BOTH or entity.layer==layer) then
            table.insert(uids,uid)
        end
    end
    return uids
end

function Game:_hook(list,callback,mask,...)
    local types={...}
    local wanted
    if #types>0 then
        wanted={}
        for _,entity_type in ipairs(types) do wanted[entity_type]=true end
    end
    table.insert(list,{callback=callback,mask=mask or 0,wanted=wanted})
end

function Game:_matches(hook,entity_type)
    if hook.wanted and not hook.wanted[entity_type] then return false end
    return hook.mask==0 or self:mask_of(entity_type)&hook.mask~=0
end

-- Pre-spawn hooks may replace a replaceable spawn by returning a uid, as the
-- game's own spawns and spawn_entity do; post-spawn hooks see every spawn.
function Game:_spawn(api,entity_type,x,y,layer,replaceable,fields)
    if replaceable then
        for _,hook in ipairs(self.pre_spawn_hooks) do
            if self:_matches(hook,entity_type) then
                local replacement=hook.callback(entity_type,x,y,layer)
                if replacement then return replacement end
            end
        end
    end
    local staged={x=x,y=y,layer=layer}
    for key,value in pairs(fields or {}) do staged[key]=value end
    local entity=self:place(entity_type,staged)
    entity.spawned_by=api
    if api~="native" then
        table.insert(self.spawned,{uid=entity.uid,type=entity_type,name=self:type_name(entity_type),x=x,y=y,layer=layer,api=api})
    end
    for _,hook in ipairs(self.post_spawn_hooks) do
        if self:_matches(hook,entity_type) then hook.callback(entity) end
    end
    return entity.uid
end

-- The game spawning an entity of its own: pre/post spawn hooks run, and a
-- hook may replace it. Returns the uid that ended up in the level.
function Game:native_spawn(type_name,fields)
    fields=fields or {}
    return self:_spawn("native",self:type_id(type_name),fields.x or 0,fields.y or 0,fields.layer or M.LAYER.FRONT,true,fields)
end

-- An engine DROP: the configured replace_drop type if any, else the native one.
function Game:drop(drop_name,native_type_name,fields)
    local entity_type=self.drops[drop_name] or self:type_id(native_type_name)
    return self:native_spawn(entity_type,fields)
end

function Game:kill(entity,destroy_corpse,responsible)
    for _,hook in ipairs(entity.pre_kill_hooks) do
        if hook(entity,destroy_corpse,responsible)==true then return false end
    end
    table.insert(self.killed,entity.uid)
    entity.health=0
    self:_remove(entity,"kill")
    return true
end

function Game:fire(event,...)
    for _,callback in ipairs(self.callbacks[event] or {}) do callback(...) end
end

-- Each frame runs the timeouts that have come due, then ON.FRAME callbacks.
function Game:frames(count)
    for _=1,count or 1 do
        self.frame_count=self.frame_count+1
        local ran=true
        while ran do
            ran=false
            for index,timeout in ipairs(self.timeouts) do
                if timeout.due<=self.frame_count then
                    table.remove(self.timeouts,index)
                    timeout.callback()
                    ran=true
                    break
                end
            end
        end
        self:fire(ON.FRAME)
    end
end

-- Starts a level the way the game drives main.lua: the previous level's
-- entities (except players and what they hold) are gone, PRE generation runs,
-- the scenario's entities are placed, `generate` may fire spawns, and POST
-- generation runs.
function Game:start_level(level)
    level=level or {}
    for _,uid in ipairs(self.order) do
        local entity=self.entities[uid]
        if entity.alive and not self:_carried_by_player(entity) then entity.alive=false end
    end
    self.state.theme=level.theme or self.state.theme
    self.state.world=level.world or self.state.world
    self.state.level=level.level or self.state.level
    self:fire(ON.PRE_LEVEL_GENERATION)
    local placed={}
    for _,spec in ipairs(level.entities or {}) do
        local fields={}
        for key,value in pairs(spec) do if key~=1 then fields[key]=value end end
        table.insert(placed,self:place(spec[1],fields))
    end
    if level.generate then level.generate(self,placed) end
    self:fire(ON.POST_LEVEL_GENERATION)
    return placed
end

function Game:_carried_by_player(entity)
    for _,player in ipairs(self.players) do
        if entity==player or entity.holder==player then return true end
    end
    return false
end

function Game:spawned_of(type_name)
    local entity_type=self:type_id(type_name)
    local found={}
    for _,record in ipairs(self.spawned) do
        if record.type==entity_type then table.insert(found,record) end
    end
    return found
end

function Game:materialized(check)
    local entry=self.ctx.lifecycle.states[check]
    return entry~=nil and entry.state=="materialized"
end

function Game:logged(pattern)
    for _,message in ipairs(self.logs) do
        if message:find(pattern,1,true) then return true end
    end
    return false
end

-- Tusk's Dice House as the game runs it: a prize is staged behind the
-- forcefield before it is won, and the next is staged once the player takes
-- it. A win advances won_prizes_count, so prize n spawns at count n-1. The
-- dispenser generates six prizes; the run in #22 shows it still emits an
-- item after the fifth is taken, at count five, so the sixth is staged too.
local DICE_PRIZES={
    "ITEM_PICKUP_BOMBBAG", "ITEM_PICKUP_ROPEPILE", "ITEM_PICKUP_PARACHUTE",
    "ITEM_PICKUP_SPECTACLES", "ITEM_PICKUP_CLIMBINGGLOVES", "ITEM_PICKUP_PITCHERSMITT",
}

function Game:dice_house(fields)
    local dispenser=self:place("ITEM_DICE_PRIZE_DISPENSER",fields)
    self.state.logic.diceshop={prize_dispenser=dispenser.uid,won_prizes_count=0,prize=-1}
    self.dice_prizes={}
    self:_stage_dice_prize()
    return dispenser
end

function Game:_stage_dice_prize()
    local dice=self.state.logic.diceshop
    local dispenser=self:entity(dice.prize_dispenser)
    local native=DICE_PRIZES[#self.dice_prizes+1]
    dice.prize=self:native_spawn(native,{x=dispenser.x,y=dispenser.y+1,layer=dispenser.layer})
    table.insert(self.dice_prizes,{uid=dice.prize,native=self:type_id(native),count=dice.won_prizes_count})
end

-- Rolls a seven, then the player takes the prize it opened.
function Game:win_dice_prize(player)
    local dice=self.state.logic.diceshop
    dice.won_prizes_count=dice.won_prizes_count+1
    local prize=self:entity(dice.prize)
    self:give(player,prize)
    self:_stage_dice_prize()
    return prize
end

return M
