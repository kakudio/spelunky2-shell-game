-- Centralized transient and run-scoped state for gameplay adapters.

local lifecycle=require "check_lifecycle"
local M={}

local LEVEL_TABLES={
    "quillback_hooks", "beg_hooks", "anubis_hooks",
    "humphead_hooks", "yeti_hooks", "lahamu_hooks", "vlad_hooks", "tiamat_hooks", "eggplant_king_hooks",
    "moon_bows", "moon_hidden_bows",
    "sun_challenge_bags",
}

function M.new(randomizer_state, initialize, log, is_duat_recovery_enabled, is_improved_duat_kali_rewards_enabled)
    local ctx={
        randomizer_state=randomizer_state,
        quillback_hooks={}, beg_hooks={}, anubis_hooks={},
        humphead_hooks={}, yeti_hooks={}, lahamu_hooks={}, vlad_hooks={}, tiamat_hooks={}, eggplant_king_hooks={},
        pending_yeti_drops={}, spawn_replacements={}, moon_bows={}, moon_hidden_bows={}, sun_challenge_bags={},
        lahamu_diagnostic_logged=false,
        moon_handoff_spawning=false, kali_last_gifts=nil, kali_known_items={},
        kali_presents={}, kali_present_source_placed=false, kali_present_completed=false,
        kali_present_sacrifice_pending=false, kali_present_source_uid=nil, kali_present_source_seen=false, kali_present_source_location=nil,
        duat_recovery=nil, duat_recovery_spawned=false,
        beg_true_crown_healed=false,
        duat_recovery_signature=nil, duat_recovery_empty_logged=false,
        sparrow_last_state=nil, sparrow_last_transition=nil,
        drop_configured={}, humphead_drop_configured=false,
        progression={crown=false,hedjet=false,pending_gate_items={}},
        initialize=initialize, log=log, is_duat_recovery_enabled=is_duat_recovery_enabled,
        is_improved_duat_kali_rewards_enabled=is_improved_duat_kali_rewards_enabled,
    }
    ctx.lifecycle=lifecycle.new(log)
    -- Keep timeout ownership in one place. All adapters should use this
    -- instead of calling set_timeout directly.
    ctx.defer=function(frames,label,callback) ctx.lifecycle:defer(frames,label,callback) end
    return ctx
end

function M.reset_level(ctx)
    ctx.lifecycle:begin_level()
    ctx.randomizer_state.level_materialized={}
    for _,name in ipairs(LEVEL_TABLES) do ctx[name]={} end
    ctx.pending_yeti_drops={}
    ctx.pending_quillback_drop=nil
    ctx.pending_vlad_cape=nil
    ctx.pending_eggplant_crown=nil
    ctx.pending_anubis_scepter_drop=nil
    ctx.pending_humphead_present=nil
    ctx.pending_tiamat_reward=nil
    ctx.pending_kali_present_payload=nil
    ctx.spawn_replacements={}
    ctx.moon_handoff_spawning=false
    ctx.lahamu_diagnostic_logged=false
    ctx.duat_recovery_spawned=false
    ctx.beg_true_crown_healed=false
end

function M.reset_run(ctx)
    ctx.progression.crown=false
    ctx.progression.hedjet=false
    ctx.progression.pending_gate_items={}
    ctx.kali_last_gifts=nil
    ctx.kali_known_items={}
    ctx.kali_presents={}
    ctx.kali_present_source_placed=false
    ctx.kali_present_completed=false
    ctx.kali_present_sacrifice_pending=false
    ctx.kali_present_source_uid=nil
    ctx.kali_present_source_seen=false
    ctx.kali_present_source_location=nil
    ctx.pending_humphead_present=nil
    ctx.pending_kali_present_payload=nil
    ctx.duat_recovery=nil
    ctx.duat_recovery_spawned=false
    ctx.beg_true_crown_healed=false
    ctx.duat_recovery_signature=nil
    ctx.duat_recovery_empty_logged=false
    ctx.sparrow_last_state=nil
    ctx.sparrow_last_transition=nil
end

return M
