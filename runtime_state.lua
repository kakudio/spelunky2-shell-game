-- Centralized transient and run-scoped state for gameplay adapters.

local M={}

local LEVEL_TABLES={
    "quillback_hooks", "beg_hooks", "anubis_hooks", "anubis2_hooks",
    "humphead_hooks", "yeti_hooks", "lahamu_hooks", "eggplant_king_hooks",
    "moon_bows", "moon_hidden_bows",
}

function M.new(randomizer_state, initialize, log)
    return {
        randomizer_state=randomizer_state,
        quillback_hooks={}, beg_hooks={}, anubis_hooks={}, anubis2_hooks={},
        humphead_hooks={}, yeti_hooks={}, lahamu_hooks={}, eggplant_king_hooks={},
        pending_yeti_drops={}, spawn_replacements={}, moon_bows={}, moon_hidden_bows={},
        moon_handoff_spawning=false, kali_last_gifts=nil, kali_known_items={},
        kali_presents={}, kali_present_source_placed=false, kali_present_completed=false,
        kali_present_sacrifice_pending=false, kali_present_source_uid=nil, kali_present_source_seen=false, kali_present_source_location=nil,
        drop_configured={}, humphead_drop_configured=false,
        progression={crown=false,hedjet=false,pending_gate_items={}},
        initialize=initialize, log=log,
    }
end

function M.reset_level(ctx)
    ctx.randomizer_state.level_materialized={}
    for _,name in ipairs(LEVEL_TABLES) do ctx[name]={} end
    ctx.pending_yeti_drops={}
    ctx.pending_quillback_drop=nil
    ctx.pending_lahamu_drop=nil
    ctx.pending_eggplant_crown=nil
    ctx.pending_anubis_scepter_drop=nil
    ctx.pending_anubis2_drop=nil
    ctx.pending_humphead_present=nil
    ctx.pending_kali_present_payload=nil
    ctx.spawn_replacements={}
    ctx.moon_handoff_spawning=false
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
end

function M.save_data(ctx)
    return {
        progression={crown=ctx.progression.crown,hedjet=ctx.progression.hedjet},
        kali_present_source_placed=ctx.kali_present_source_placed,
        kali_present_source_uid=ctx.kali_present_source_uid,
        kali_present_completed=ctx.kali_present_completed,
        kali_present_source_location=ctx.kali_present_source_location,
    }
end

function M.restore_data(ctx, data)
    ctx.progression.crown=data.progression and data.progression.crown or false
    ctx.progression.hedjet=data.progression and data.progression.hedjet or false
    ctx.kali_present_source_placed=data.kali_present_source_placed or false
    ctx.kali_present_source_uid=data.kali_present_source_uid
    ctx.kali_present_completed=data.kali_present_completed or false
    ctx.kali_present_source_location=data.kali_present_source_location
end

return M
