// -------------------------------------------------------------------------------
// Cold War Style Item Drops for Black Ops III - Marv Edition
// Copyright (c) 2022 Philip/Scobalula
// -------------------------------------------------------------------------------
// Licensed under the "Do whatever you want thx hun bun" license.
// -------------------------------------------------------------------------------
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\flag_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_item_drops.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache("client_fx", ZM_ITEM_DROPS_COMMON_FX_NAME);
#precache("client_fx", ZM_ITEM_DROPS_RARE_FX_NAME);
#precache("client_fx", ZM_ITEM_DROPS_LEGENDARY_FX_NAME);
#precache("client_fx", ZM_ITEM_DROPS_ULTRA_FX_NAME);

#namespace zm_item_drops;

REGISTER_SYSTEM_EX("zm_item_drops", &__init__, &__main__, undefined)

function __init__()
{
    // Effects
    level._effect["zm_item_drop_common"]    = ZM_ITEM_DROPS_COMMON_FX_NAME;
    level._effect["zm_item_drop_uncommon"]  = ZM_ITEM_DROPS_RARE_FX_NAME;
    level._effect["zm_item_drop_rare"]      = ZM_ITEM_DROPS_LEGENDARY_FX_NAME;
    level._effect["zm_item_drop_legendary"] = ZM_ITEM_DROPS_ULTRA_FX_NAME;
    // Clientfields
    clientfield::register("scriptmover", ZM_ITEM_DROPS_FX_CF_NAME, VERSION_SHIP, GetMinBitCountForNum(ZM_ITEM_DROPS_FX_VARIANTS), "int", &do_dropped_item_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
    // Duplicate Renders
    duplicate_render::set_dr_filter_offscreen("dr_zm_item_drop_common",     99, "zm_item_drop_common",      undefined, DR_TYPE_OFFSCREEN, ZM_ITEM_DROPS_COMMON_MTL_NAME,        DR_CULL_NEVER);
    duplicate_render::set_dr_filter_offscreen("dr_zm_item_drop_uncommon",   99, "zm_item_drop_uncommon",    undefined, DR_TYPE_OFFSCREEN, ZM_ITEM_DROPS_RARE_MTL_NAME,          DR_CULL_NEVER);
    duplicate_render::set_dr_filter_offscreen("dr_zm_item_drop_rare",       99, "zm_item_drop_rare",        undefined, DR_TYPE_OFFSCREEN, ZM_ITEM_DROPS_LEGENDARY_MTL_NAME,     DR_CULL_NEVER);
    duplicate_render::set_dr_filter_offscreen("dr_zm_item_drop_legendary",  99, "zm_item_drop_legendary",   undefined, DR_TYPE_OFFSCREEN, ZM_ITEM_DROPS_ULTRA_MTL_NAME,         DR_CULL_NEVER);
    // Callbacks
    callback::on_localplayer_spawned(&on_spawned);
}

function __main__()
{
    
}

// Runs the OED sitrep loop. (thanks naptroes)
function on_spawned(localClientNum)
{
    self thread oed_sitrep_loop(localClientNum);
}

// Runs the OED sitrep loop. (thanks naptroes)
function private oed_sitrep_loop(localClientNum)
{
    self endon("entityshutdown");
    self endon("disconnect");
    self endon("death");
    self endon("bled_out");

    self notify("oed_sitrep_loop");
    self endon("oed_sitrep_loop");

    // Beast Mode is referenced in "scripts/zm/_zm.csc", which has 
    // the "best of both worlds" in terms of supporting on- and off-screen keylines

    // Loop until they die
    while(isdefined(self) && IsAlive(self))
    {
        // This NEEDS to be 3 for "best of both worlds" effect
        self OED_SitRepScan_Enable(3);
        self OED_SitRepScan_SetOutline(1);
        self OED_SitRepScan_SetSolid(1);
        self OED_SitRepScan_SetLineWidth(1);
        self OED_SitRepScan_SetRadius(1800);
        self OED_SitRepScan_SetFalloff(1);
        self OED_SitRepScan_SetDesat(1);

        wait(0.05);
    }
}

// Handles fx for a dropped item.
function private do_dropped_item_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
    self endon("entityshutdown");

    if(isdefined(self.trailing_drop_fx))
    {
        StopFX(localClientNum, self.trailing_drop_fx);
    }

    switch(newVal)
    {
    case ZM_ITEM_DROPS_COMMON:
        self.trailing_drop_fx = PlayFXOnTag(localClientNum, level._effect["zm_item_drop_common"], self, "tag_origin");
        self duplicate_render::set_dr_flag("zm_item_drop_common", 1);
        self duplicate_render::update_dr_filters(localClientNum);
        break;
    case ZM_ITEM_DROPS_RARE:
        self.trailing_drop_fx = PlayFXOnTag(localClientNum, level._effect["zm_item_drop_uncommon"], self, "tag_origin");
        self duplicate_render::set_dr_flag("zm_item_drop_uncommon", 1);
        self duplicate_render::update_dr_filters(localClientNum);
        break;
    case ZM_ITEM_DROPS_LEGENDARY:
        self.trailing_drop_fx = PlayFXOnTag(localClientNum, level._effect["zm_item_drop_rare"], self, "tag_origin");
        self duplicate_render::set_dr_flag("zm_item_drop_rare", 1);
        self duplicate_render::update_dr_filters(localClientNum);	
        break;
    case ZM_ITEM_DROPS_ULTRA:
        self.trailing_drop_fx = PlayFXOnTag(localClientNum, level._effect["zm_item_drop_legendary"], self, "tag_origin");
        self duplicate_render::set_dr_flag("zm_item_drop_legendary", 1);
        self duplicate_render::update_dr_filters(localClientNum);
        break;
    default:
        break;
    }
}