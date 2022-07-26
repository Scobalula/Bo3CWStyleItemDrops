// -------------------------------------------------------------------------------
// Cold War Style Item Drops for Black Ops III - Marv Edition
// Copyright (c) 2022 Philip/Scobalula
// -------------------------------------------------------------------------------
// Licensed under the "Do whatever you want thx hun bun" license.
// -------------------------------------------------------------------------------
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\flagsys_shared;

#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_devgui;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_weapons;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_item_drops.gsh;
#insert scripts\zm\_zm_utility.gsh;

#namespace zm_item_drops;

REGISTER_SYSTEM_EX("zm_item_drops", &__init__, &__main__, undefined)

// Init
function __init__()
{
    // Global Settings
    DEFAULT(level.zm_item_drops_requires_player, 			ZM_ITEM_DROPS_REQUIRES_PLAYER);
    DEFAULT(level.zm_item_drops_chance, 					ZM_ITEM_DROPS_CHANCE);
    DEFAULT(level.zm_item_drops_min_round, 					ZM_ITEM_DROPS_MIN_ROUND);
    DEFAULT(level.zm_item_drops_requires_valid_zone, 		ZM_ITEM_DROPS_REQUIRES_VALID_ZONE);
    DEFAULT(level.zm_item_drops_requires_line_of_sight, 	ZM_ITEM_DROPS_REQUIRES_LINE_OF_SIGHT);
    DEFAULT(level.zm_item_drops_requires_no_overlaps, 		ZM_ITEM_DROPS_REQUIRES_LINE_OF_SIGHT);
    DEFAULT(level.zm_item_drops_max_items, 					ZM_ITEM_DROPS_MAX_ITEMS);
    DEFAULT(level.zm_item_drops_max_items_per_round, 		ZM_ITEM_DROPS_MAX_ITEMS_PER_ROUND);
    DEFAULT(level.zm_item_drops_kills_required_min, 		ZM_ITEM_DROPS_KILLS_REQUIRED_MIN);
    DEFAULT(level.zm_item_drops_kills_required_max,			ZM_ITEM_DROPS_KILLS_REQUIRED_MAX);
    DEFAULT(level.zm_item_drops_round_based_drop_rate, 		ZM_ITEM_DROPS_ROUND_BASED_DROP_RATE);
    DEFAULT(level.zm_item_drops_range_squared, 				ZM_ITEM_DROPS_RANGE_SQUARED);
    DEFAULT(level.zm_item_drops_drop_calc_min_radius, 		ZM_ITEM_DROPS_DROP_CALC_MIN_RADIUS);
    DEFAULT(level.zm_item_drops_drop_calc_max_radius, 		ZM_ITEM_DROPS_DROP_CALC_MAX_RADIUS);
    DEFAULT(level.zm_item_drops_drop_calc_half_height, 		ZM_ITEM_DROPS_DROP_CALC_HALF_HEIGHT);
    DEFAULT(level.zm_item_drops_drop_calc_inner_spacing, 	ZM_ITEM_DROPS_DROP_CALC_INNER_SPACING);
    // Trackers
    level.zm_item_drops_dropped_this_round		 = 0;
    level.zm_item_drops_dropped					 = 0;
    level.zm_item_drops_current_kill_count		 = 0;
    level.zm_item_drops_kills_for_next_drop		 = 0;
    // Clientfields
    clientfield::register("scriptmover", ZM_ITEM_DROPS_FX_CF_NAME, VERSION_SHIP, GetMinBitCountForNum(ZM_ITEM_DROPS_FX_VARIANTS), "int");
}

// Main
function __main__()
{
    zm_spawner::register_zombie_death_event_callback(&drop_item_callback);
    level thread item_drop_monitor();
}

// Registers a given weapon with the given details. If the weapon doesn't exist, the item will not be added.
function register_weapon_drop(weapon, rarity, chance)
{
    if(!isdefined(weapon))
        return undefined;
    if(weapon === level.weaponNone)
        return undefined;

    return register_item_drop(weapon.name, weapon, rarity, chance, &on_weapon_picked_up, ZM_ITEM_DROP_PICK_UP_UNITRIGGER);
}

// Creates a given weapon drop with the given details.
function create_weapon_drop(weapon, rarity)
{
    if(!isdefined(weapon))
        return undefined;
    if(weapon === level.weaponNone)
        return undefined;

    return create_item_drop(weapon.name, weapon, rarity, &on_weapon_picked_up, ZM_ITEM_DROP_PICK_UP_UNITRIGGER);
}

// Registers an item of the given name with the given information.
function register_item_drop(item_name,
                            item,
                            rarity,
                            chance,
                            on_item_picked_up_func,
                            pickup_type                 = ZM_ITEM_DROP_PICK_UP_TOUCH,
                            pickup_hint                 = undefined,
                            on_spawn_item_model_func    = &on_spawn_item_model_default,
                            on_item_dropped_func        = &on_item_dropped_default,
                            on_item_cleaned_up_func     = &on_item_cleaned_up_default,
                            on_drop_sound               = ZM_ITEM_DROPS_DEFAULT_LAND_SOUND,
                            on_land_sound               = ZM_ITEM_DROPS_DEFAULT_LAND_SOUND,
                            on_pick_up_sound            = ZM_ITEM_DROPS_DEFAULT_PICK_UP_SOUND)
{
    if(!isdefined(item_name))
        return undefined;
    if(!isdefined(item))
        return undefined;

    DEFAULT(level.zm_item_drop_registered_items, []);
    DEFAULT(level.zm_item_drop_registered_items_weight, 0);

    if(isdefined(level.zm_item_drop_registered_items[item_name]))
        return undefined;

    new_item = SpawnStruct();

    new_item.item_name                   = item_name;
    new_item.item                        = item;
    new_item.pickup_type                 = pickup_type;
    new_item.pickup_hint                 = pickup_hint;
    new_item.rarity                      = rarity;
    new_item.chance                      = chance;
    new_item.on_spawn_item_model_func    = on_spawn_item_model_func;
    new_item.on_item_dropped_func        = on_item_dropped_func;
    new_item.on_item_picked_up_func      = on_item_picked_up_func;
    new_item.on_item_cleaned_up_func     = on_item_cleaned_up_func;
    new_item.is_weapon                   = IsWeapon(item);
    new_item.on_drop_sound               = on_drop_sound;
    new_item.on_land_sound               = on_land_sound;
    new_item.on_pick_up_sound            = on_pick_up_sound;

    level.zm_item_drop_registered_items[item_name] = new_item;
    level.zm_item_drop_registered_items_weight += chance;

    return new_item;
}

// Creates an item of the given name with the given information.
function create_item_drop(item_name,
                          item,
                          rarity,
                          on_item_picked_up_func,
                          pickup_type               = ZM_ITEM_DROP_PICK_UP_TOUCH,
                          pickup_hint               = undefined,
                          on_spawn_item_model_func  = &on_spawn_item_model_default,
                          on_item_dropped_func      = &on_item_dropped_default,
                          on_item_cleaned_up_func   = &on_item_cleaned_up_default,
                          on_drop_sound             = ZM_ITEM_DROPS_DEFAULT_DROP_SOUND,
                          on_land_sound             = ZM_ITEM_DROPS_DEFAULT_LAND_SOUND,
                          on_pick_up_sound          = ZM_ITEM_DROPS_DEFAULT_PICK_UP_SOUND)
{
    if(!isdefined(item_name))
        return undefined;
    if(!isdefined(item))
        return undefined;

    new_item = SpawnStruct();

    new_item.item_name                   = item_name;
    new_item.item                        = item;
    new_item.pickup_type                 = pickup_type;
    new_item.pickup_hint                 = pickup_hint;
    new_item.rarity                      = rarity;
    new_item.on_spawn_item_model_func    = on_spawn_item_model_func;
    new_item.on_item_dropped_func        = on_item_dropped_func;
    new_item.on_item_picked_up_func      = on_item_picked_up_func;
    new_item.on_item_cleaned_up_func     = on_item_cleaned_up_func;
    new_item.is_weapon                   = IsWeapon(item);
    new_item.on_drop_sound               = on_drop_sound;
    new_item.on_land_sound               = on_land_sound;
    new_item.on_pick_up_sound            = on_pick_up_sound;

    return new_item;
}

// Runs general per-round initializations and value resets.
function item_drop_monitor()
{
    for(;;)
    {
        level waittill("start_of_round");
        level.zm_item_drops_dropped_this_round = 0;
    }
}

// Creates a generic unitrigger for a given item drop based off the item and details provided.
function create_item_drop_unitrigger()
{
    self.unitrigger_stub                          = SpawnStruct();
    self.unitrigger_stub.origin                   = self.origin;
    self.unitrigger_stub.angles                   = self.angles;
    self.unitrigger_stub.radius                   = self.range_squared;
    self.unitrigger_stub.height                   = 40;
    self.unitrigger_stub.script_unitrigger_type   = "unitrigger_radius_use";
    self.unitrigger_stub.require_look_at          = false;
    self.unitrigger_stub.trigger_target           = self;

    // If we're a weapon we can pass in the weapon along with a stock string
    // to handle pushing the name to the hint, otherwise we'll use user or default.
    if(self.drop_type.is_weapon && !isdefined(self.drop_type.pickup_hint))
    {
        self.unitrigger_stub.weapon_to_give       = self.drop_type.item;
        self.unitrigger_stub.cursor_hint_weapon   = self.drop_type.item;
        self.unitrigger_stub.cursor_hint          = "HINT_WEAPON";
        self.unitrigger_stub.hint_string          = &"ZOMBIE_TRADE_WEAPON_FILL";
    }
    else if(isdefined(self.drop_type.pickup_hint))
    {
        self.unitrigger_stub.cursor_hint          = "HINT_NO_ICON";
        self.unitrigger_stub.hint_string          = self.drop_type.pickup_hint;
    }
    else
    {
        self.unitrigger_stub.cursor_hint          = "HINT_NO_ICON";
        self.unitrigger_stub.hint_string          = &"WEAPON_GENERIC_PICKUP";
    }
    
    zm_unitrigger::unitrigger_force_per_player_triggers(self.unitrigger_stub, true);
    zm_unitrigger::register_static_unitrigger(self.unitrigger_stub, &dropped_item_trigger_think);
}

// Runs general logic for a trigger drop.
function dropped_item_trigger_think()
{
    target = self.stub.trigger_target;

    if(isdefined(target) && !IS_TRUE(target.item_picked_up))
    {
        target 	endon("death");
        target 	endon("zm_dropped_item_picked_up");
        target 	endon("zm_dropped_item_timed_out");
        self 	endon("kill_trigger");

        for(;;)
        {
            self waittill("trigger", player);

            if(!isdefined(target))
                break;
            if(IS_TRUE(target.item_picked_up))
                break;

            // Check if the pick up was successful, if not, let's run again!
            r_val = target [[target.drop_type.on_item_picked_up_func]](target.drop_type, player);

            if(!IS_TRUE(r_val))
                continue;

            if(isdefined(target.drop_type.on_pick_up_sound))
                target PlaySound(target.drop_type.on_pick_up_sound);

            target.item_picked_up = true;
            target notify("zm_dropped_item_picked_up");
            break;
        }
    }
}

// Monitors nearby players for proximity for touch item types.
function dropped_item_touch_think()
{
    self endon("death");
    self endon("zm_dropped_item_picked_up");
    self endon("zm_dropped_item_timed_out");

    range_squared = self.range_squared;

    while (isdefined(self))
    {
        players = GetPlayers();

        for (i = 0; i < players.size; i++)
        {
            player = players[i];

            if(DistanceSquared(player.origin, self.origin) > range_squared)
                continue;

            // Check if the pick up was successful, if not, let's run again!
            r_val = self [[self.drop_type.on_item_picked_up_func]](self.drop_type, player);

            if(!IS_TRUE(r_val))
                continue;

            if(isdefined(self.drop_type.on_pick_up_sound))
                self PlaySound(self.drop_type.on_pick_up_sound);

            self notify("zm_dropped_item_picked_up");
            return;
        }

        wait 0.1;
    }
}

// Runs clean up for when an item is picked up or times out.
function dropped_item_cleanup_monitor()
{
    self endon("death");

    while(true)
    {
        result = self util::waittill_any_timeout(self.time_to_live, "zm_dropped_item_picked_up");

        self [[self.drop_type.on_item_cleaned_up_func]](self.drop_type);

        if(result == "zm_dropped_item_picked_up" && isdefined(self.drop_type.collect_sound))
            self PlaySound(self.drop_type.collect_sound);
        else
            self notify("zm_dropped_item_timed_out");

        WAIT_SERVER_FRAME;
        self Delete();
    }
}

// Runs default spawning model logic for an item.
function on_spawn_item_model_default(drop_type, origin, angles)
{
    ent = undefined;

    if(IsWeapon(drop_type.item))
    {
        ent = util::spawn_model("tag_origin", origin, angles);
        ent UseWeaponModel(drop_type.item, drop_type.item.worldModel);
        ent UseWeaponHideTags(drop_type.item);
    }
    else if(IsString(drop_type.item))
    {
        ent = util::spawn_model(drop_type.item, origin, angles);
    }

    return ent;
}

// Runs default item logic for a dropped item.
function on_item_dropped_default(drop_type)
{
    // For now we only have 2 pickup types, we can extend in future
    // or people can override the dropped function.
    if(drop_type.pickup_type == ZM_ITEM_DROP_PICK_UP_UNITRIGGER)
    {
        self create_item_drop_unitrigger();
    }
    else 
    {
        self thread dropped_item_touch_think();
    }
}

// Runs generic notifys and weapon pick ups.
function on_weapon_picked_up(drop_type, player)
{
    if(player zm_utility::in_revive_trigger())
        return false;
    if(IS_DRINKING(player.is_drinking))
        return false;
    if(!zm_utility::is_player_valid(player))
        return false;

    if(drop_type.is_weapon)
    {
        weapon = drop_type.item;

        if (!player zm_weapons::has_weapon_or_upgrade(weapon))
        {
            // TODO: Drop current weapon?
            player zm_weapons::weapon_give(weapon);
        }
        else
        {
            player GiveMaxAmmo(weapon);

            if(!zm_utility::is_offhand_weapon(weapon))
            {
                player SetWeaponAmmoClip(weapon, weapon.clipSize);
                player SetWeaponAmmoStock(weapon, weapon.maxAmmo);

                if(weapon.dualWieldWeapon != level.weaponNone)
                {
                    player SetWeaponAmmoClip(weapon.dualWieldWeapon, weapon.dualWieldWeapon.clipSize);
                }

                if(weapon.altWeapon != level.weaponNone)
                {
                    player SetWeaponAmmoClip(weapon.altWeapon, weapon.altWeapon.clipSize);
                }
            }
        }
    }

    return true;
}

// Runs default cleanup logic for a dropped item.
function on_item_cleaned_up_default(drop_type)
{
    if(isdefined(self.unitrigger_stub))
    {
        zm_unitrigger::unregister_unitrigger(self.unitrigger_stub);
        self.unitrigger_stub = undefined;
    }
}

// Gets the total number of items within the level.
function current_drop_count(v_to)
{
    if(IsFunctionPtr(level.zm_item_drops_current_drop_count_override))
    {
        return [[level.zm_item_drops_current_drop_count_override]]();
    }

    return GetEntArray(ZM_ITEM_DROPS_TARGET_NAME, "targetname").size;
}

// Checks to see if a given point would overlap other items dropped
// within the level.
function drop_point_overlaps(v_to)
{
    if(IsFunctionPtr(level.zm_item_drops_drop_point_overlaps_override))
    {
        return [[level.zm_item_drops_drop_point_overlaps_override]](v_to);
    }

    foreach(item in GetEntArray(ZM_ITEM_DROPS_TARGET_NAME, "targetname"))
    {
        // Check if this location is taken, we don't want to drop 2 items to the same location
        if(isdefined(item) && DistanceSquared(item.origin, v_to) < item.range_squared)
        {
            return true;
        }
    }

    return false;
}

// Checks if the point from a to b is valid to drop an item at based off
// defined checks such as sight and overlaps if enabled.
function drop_point_is_valid(v_from, v_to)
{
    if(IsFunctionPtr(level.zm_item_drops_drop_point_is_valid_callback) && !self [[level.zm_item_drops_drop_point_is_valid_callback]](v_from, v_to))
        return false;
    if(level.zm_item_drops_requires_line_of_sight && !BulletTracePassed(v_from + (0, 0, ZM_ITEM_DROPS_VIS_HEIGHT), v_to + (0, 0, ZM_ITEM_DROPS_VIS_HEIGHT), false, self))
        return false;
    if(level.zm_item_drops_requires_valid_zone && !zm_utility::check_point_in_enabled_zone(v_to, true, level.active_zones))
        return false;
    if(level.zm_item_drops_requires_no_overlaps && drop_point_overlaps(v_to))
        return false;

    return true;
}

// Calculates the drop location given an origin and optional desired angles.
// The result is not guaranteed to be the direction of the desired angles if 
// no valid point the given direction could be found, and may return undefined
// if no valid point could be found at all.
function try_calc_drop_location(v_origin, v_angles)
{
    // Check for overrides if a custom drop location system is desired.
    if(IsFunctionPtr(level.zm_item_drops_try_calc_drop_location_override))
    {
        return self [[level.zm_item_drops_try_calc_drop_location_override]](v_origin, v_angles);
    }

    query_result = PositionQuery_Source_Navigation(
        self.origin,
        level.zm_item_drops_drop_calc_min_radius,
        level.zm_item_drops_drop_calc_max_radius,
        level.zm_item_drops_drop_calc_half_height,
        level.zm_item_drops_drop_calc_inner_spacing);
    query_result   = array::randomize(query_result.data);
    fall_back      = undefined;

    foreach(point in query_result)
    {
        result = zm_utility::groundpos_ignore_water_new(point.origin) + (0, 0, 8);

        if(self drop_point_is_valid(v_origin, result))
        {
            // Store this as a valid fall back if further checks don't check out.
            fall_back    = result;
            dir          = VectorNormalize(result - self.origin);
            dot          = VectorDot(dir, AnglesToForward(self.angles));

            // Check if the point is in front, if it is, this is a good
            // bet as it passed all our checks.
            if(dot > 0.6)
            {
                return fall_back;
            }
        }
    }

    return fall_back;
}

// Attempts to get a random item by weights.
function try_get_weighted_item_drop_info()
{
    if(IsFunctionPtr(level.zm_item_drops_try_get_weighted_item_drop_info_override))
    {
        return [[level.zm_item_drops_try_get_weighted_item_drop_info_override]]();
    }

    // TODO: Even with a lot of items this doesn't pose any issues in-game, but I would
    // like to optimize this at some point, maybe pre-sorting the list of items by weight, etc.
    // But considering it's only run 99% of time on zombie death, it's not a major issue.
    if(!isdefined(level.zm_item_drop_registered_items))
        return undefined;
    if(!isdefined(level.zm_item_drop_registered_items_weight) || level.zm_item_drop_registered_items_weight == 0)
        return undefined;

    drop_types = array::randomize(level.zm_item_drop_registered_items);
    fallback = undefined;

    if(IsFunctionPtr(level.zm_item_drops_calculate_custom_weights))
    {
        weight = [[level.zm_item_drops_calculate_custom_weights]]();
    }
    else
    {
        weight = RandomIntRange(0, level.zm_item_drop_registered_items_weight);
    }

    foreach(drop_type in drop_types)
    {
        weight -= drop_type.chance;

        if(weight > 0)
            continue;

        return drop_type;
    }

    return undefined;
}

// Drops a weapon from the given location to the given location.
function drop_weapon_to_location(weapon, v_from, v_to)
{
    drop_type = create_weapon_drop(weapon, ZM_ITEM_DROPS_COMMON);

    if(!isdefined(drop_type))
        return;

    drop_item_by_type_to_location(drop_type, v_from, v_to);
}

// Drops the provided item type to from the given location to the given location.
function drop_item_by_name_to_location(drop_type_name, v_from, v_to)
{
    if(!isdefined(level.zm_item_drop_registered_items))
        return;

    drop_type = level.zm_item_drop_registered_items[drop_type_name];

    if(!isdefined(drop_type))
        return;

    drop_item_by_type_to_location(drop_type, v_from, v_to);
}

// Drops the provided item type to from the given location to the given location.
function drop_item_by_type_to_location(drop_type, v_from, v_to)
{
    ang = VectorToAngles(VectorNormalize(v_from - v_to));
    ent = [[drop_type.on_spawn_item_model_func]](drop_type, v_from, (0, ang[1], ang[2]));

    if(!isdefined(ent))
        return;

    ent endon("death");
    ent.range_squared = level.zm_item_drops_range_squared;
    ent.drop_type = drop_type;
    ent.targetname = ZM_ITEM_DROPS_TARGET_NAME;
    ent.spawn_time = GetTime();

    if(isdefined(drop_type.time_to_live))
        ent.time_to_live = drop_type.time_to_live;
    else
        ent.time_to_live = ZM_ITEM_DROPS_DEFAULT_TIME_TO_LIVE;

    util::wait_network_frame();

    ent clientfield::set(ZM_ITEM_DROPS_FX_CF_NAME, drop_type.rarity);

    if(isdefined(ent.drop_type.on_drop_sound))
        ent PlaySound(ent.drop_type.on_drop_sound);

    v_dest = v_to + (0, 0, 8);
    n_time = ent zm_utility::fake_physicslaunch(v_dest, 200);
    wait(n_time);
    ent.origin = v_dest;

    if(isdefined(ent.drop_type.on_land_sound))
        ent PlaySound(ent.drop_type.on_land_sound);

    ent thread dropped_item_cleanup_monitor();
    util::wait_network_frame();
    ent [[ent.drop_type.on_item_dropped_func]](ent.drop_type);
}

// Runs item callbacks on death of an enemy.
function drop_item_callback(e_attacker) 
{
    // self = actor
    level.zm_item_drops_current_kill_count++;

    if(!isdefined(self))
        return;

    // Allow complete overriding of the checks.
    if(IsFunctionPtr(level.zm_item_drops_should_drop_item_override))
    {
        if(!self [[level.zm_item_drops_should_drop_item_override]](e_attacker))
            return;
    }
    else
    {
        if(level.zm_item_drops_current_kill_count < level.zm_item_drops_kills_for_next_drop)
            return;
        if(!isdefined(self))
            return;
        if(IS_TRUE(level.zm_item_drops_disabled))
            return;
        if(!isdefined(level.zm_item_drop_registered_items))
            return;
        if(current_drop_count() >= level.zm_item_drops_max_items)
            return;
        if(level.zm_item_drops_dropped_this_round >= level.zm_item_drops_max_items_per_round)
            return;
        if(level.round_number < level.zm_item_drops_min_round)
            return;
        if(!zm_spawner::zombie_can_drop_powerups(self))
            return;
        if(level.zm_item_drops_requires_player && !zm_utility::is_player_valid(e_attacker))
            return;

        rand = RandomInt(100);

        if(rand > level.zm_item_drops_chance)
            return;
    }

    drop_type = try_get_weighted_item_drop_info();

    if(!isdefined(drop_type))
        return;

    calced = self try_calc_drop_location(self.origin, self.angles);

    if(!isdefined(calced))
        return;

    // A further callback for when a valid item, etc. is determined.
    if(IsFunctionPtr(level.zm_item_drops_should_drop_item_callback))
        if(!self [[level.zm_item_drops_should_drop_item_callback]](e_attacker, drop_type, calced))
            return;

    level thread drop_item_by_type_to_location(drop_type, self GetEye(), calced);

    // Add to round count.
    level.zm_item_drops_dropped_this_round++;

    // Reset our kill counts.
    level.zm_item_drops_current_kill_count = 0;
    level.zm_item_drops_kills_for_next_drop = RandomIntRange(level.zm_item_drops_kills_required_min, level.zm_item_drops_kills_required_max);

    // If we're above round 20 and using round based drop rate, increase the rate.
    if(level.zm_item_drops_round_based_drop_rate && level.round_number > 20)
    {
        level.zm_item_drops_kills_for_next_drop /= 2;
    }
}