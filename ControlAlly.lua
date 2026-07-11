--[[
    Control Ally
    Smart combo for controllable allied heroes (disconnect / shared control).
    Script by 花曇り hanagumori
--]]

local Script = {}
local Core = {
    RuntimeAdapter = {},
    Snapshot = {},
    Targeting = {},
    AoeSolver = {},
    Catalog = {},
    GenericPlanner = {},
    InvokerController = {},
    ActionRunner = {},
    MovementController = {},
    OrderGateway = {},
    Settings = {},
    Overlay = {},
}

--#region Constants

local LOG_PREFIX = "[ControlAlly] "
local CONFIG_SECTION = "control_ally"
local CONFIG_SECTION_LEGACY = "leaked_ally_combo"
local ORDER_PREFIX = "control_ally:"

local UPDATE_INTERVAL = 0.04
local ALLY_SCAN_INTERVAL = 0.5
local TARGET_RESOLVE_INTERVAL = 0.12
local MULTISELECT_SYNC_INTERVAL = 0.35
local BUILTIN_MENU_SYNC_INTERVAL = 1.0
local MOVE_ORDER_INTERVAL = 0.10
local ATTACK_ORDER_INTERVAL = 0.22
local MELEE_ATTACK_ORDER_INTERVAL = 0.50
local RANGE_ATTACK_BUFFER = 35
local RANGE_CAST_BUFFER = 90
local RANGE_TOLERANCE = 25
local DEBUG_VERBOSE_INTERVAL = 0.12
local EXTEND_BUFFER = 0.15
local BLINK_SETTLE = 0.12
local ACTION_TIMEOUT = 1.8
local ACTION_RETRY_INTERVAL = 0.08
local ORDER_ACK_RETRY_DELAY = 0.40
local INVOKER_ORB_ACK_SETTLE = 0.02
local MAX_ACTION_ATTEMPTS = 8
local INVOKER_SPELL_GAP = 0.02
local INVOKER_INVOKE_SETTLE = 0.03
local INVOKER_SLOT_WAIT = 0.30
local COMBO_RELEASE_GRACE = 0.22
local FAIL_SKIP_DURATION = 4.0
local TARGET_LOCK_BONUS = 2500
-- World-space hover radius for Cursor mode (not hero search radius).
local CURSOR_WORLD_PICK_MIN = 100
local CURSOR_WORLD_PICK_MAX = 300
local CURSOR_MAX_SCREEN_DIST = 80
local FALLBACK_ABILITY_SLOTS = 24
local FALLBACK_ITEM_SLOTS = 9
-- Trample stomps after ~140 travel; orbit radius keeps PB near the target.
local TRAMPLE_ORBIT_RADIUS = 175
local TRAMPLE_ORBIT_STEP = 1.15
local TRAMPLE_ORBIT_INTERVAL = 0.10

local TARGET_STYLE_CURSOR = 0
local TARGET_STYLE_SCORE = 1
local SCAN_RADIUS_BUFFER = 200

local O_CAST_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local O_CAST_POSITION = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
local O_CAST_NO_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
local O_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
local O_ATTACK = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
local O_STOP = Enum.UnitOrder.DOTA_UNIT_ORDER_STOP
local ORDER_ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

local TEAM_ENEMY = Enum.TeamType.TEAM_ENEMY

local BEH = Enum.AbilityBehavior
local ABILITY_CAST_READY = Enum.AbilityCastResult.READY
local TT = Enum.TargetTeam
local TARGET_MODE_ITEMS = { "Cursor", "Auto Score" }

Core.Catalog.SkipItems = {
    item_tpscroll = true,
    item_flask = true,
    item_clarity = true,
    item_enchanted_mango = true,
    item_famango = true,
    item_famango_single = true,
    item_royale_with_cheese = true,
    item_ward_observer = true,
    item_ward_sentry = true,
    item_ward_dispenser = true,
    item_dust = true,
    item_smoke_of_deceit = true,
    item_tango = true,
    item_tango_single = true,
    item_blood_grenade = true,
    item_furion_teleport_scroll = true,
    item_tome_of_knowledge = true,
    item_aghanims_shard = true,
    item_aghanims_shard_roshan = true,
    item_refresher_shard = true,
    item_infused_raindrop = true,
    item_bottle = true,
    item_branches = true,
    item_magic_stick = true,
    item_magic_wand = true,
    item_quelling_blade = true,
    item_orb_of_venom = true,
    item_blight_stone = true,
    item_wind_lace = true,
    item_ring_of_protection = true,
    item_sobi_mask = true,
    item_ring_of_regen = true,
    item_circlet = true,
    item_gauntlets = true,
    item_slippers = true,
    item_mantle = true,
}

Core.Catalog.BlinkItems = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

Core.Catalog.LinkbreakItems = {
    "item_cyclone",
    "item_wind_waker",
    "item_dagon",
    "item_orchid",
    "item_bloodthorn",
    "item_sheepstick",
    "item_abyssal_blade",
    "item_heavens_halberd",
    "item_rod_of_atos",
    "item_gungir",
    "item_nullifier",
    "item_ethereal_blade",
    "item_diffusal_blade",
    "item_disperser",
    "item_spirit_vessel",
    "item_urn_of_shadows",
}

Core.Catalog.SelfItems = {
    item_manta = true,
    item_lotus_orb = true,
    item_glimmer_cape = true,
    item_force_staff = true,
    item_hurricane_pike = true,
    item_cyclone = true,
    item_wind_waker = true,
    item_ghost = true,
    item_essence_ring = true,
    item_faerie_fire = true,
    item_greater_faerie_fire = true,
    item_cheese = true,
    item_phase_boots = true,
}

Core.Catalog.SelfNoTargetItems = {
    item_black_king_bar = true,
    item_crimson_guard = true,
    item_mekansm = true,
    item_guardian_greaves = true,
    item_pipe = true,
    item_ancient_janggo = true,
    item_boots_of_bearing = true,
}

Core.Catalog.MagicImmuneModifiers = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
    "modifier_item_sphere_target",
}

Core.Catalog.DispellableModifiers = {
    "modifier_rod_of_atos_debuff",
    "modifier_gungir_root",
    "modifier_ensnare",
    "modifier_naga_siren_ensnare",
    "modifier_meepo_earthbind",
    "modifier_treant_overgrowth",
    "modifier_cage_trap",
    "modifier_silencer_curse_of_the_silent",
    "modifier_orchid_malevolence_debuff",
    "modifier_bloodthorn_debuff",
}

Core.Catalog.LocalBuffModifiers = {
    "modifier_earth_spirit_geomagnetic_grip",
    "modifier_bane_fiends_grip",
    "modifier_shadow_shaman_shackles",
    "modifier_pudge_dismember",
    "modifier_batrider_flaming_lasso",
    "modifier_legion_commander_duel",
    "modifier_faceless_void_chronosphere_freeze",
    "modifier_winter_wyvern_winters_curse",
}

Core.Catalog.DisableModifiers = {
    tidehunter_ravage = { "modifier_tidehunter_ravage" },
    enigma_black_hole = { "modifier_enigma_black_hole_pull" },
    faceless_void_chronosphere = { "modifier_faceless_void_chronosphere_freeze" },
    magnataur_reverse_polarity = { "modifier_magnataur_reverse_polarity" },
    axe_berserkers_call = { "modifier_axe_berserkers_call" },
    bane_fiends_grip = { "modifier_bane_fiends_grip" },
    shadow_shaman_shackles = { "modifier_shadow_shaman_shackles" },
    batrider_flaming_lasso = { "modifier_batrider_flaming_lasso" },
    earthshaker_fissure = { "modifier_earthshaker_fissure_stun" },
    crystal_maiden_crystal_nova = { "modifier_crystal_maiden_crystal_nova_slow" },
    crystal_maiden_freezing_field = { "modifier_crystal_maiden_freezing_field_slow" },
    lion_impale = { "modifier_lion_impale" },
    lion_voodoo = { "modifier_lion_voodoo" },
    witch_strike = { "modifier_witch_strike_debuff" },
    invoker_cold_snap = { "modifier_invoker_cold_snap" },
    ogre_magi_fireblast = { "modifier_stunned" },
    ogre_magi_ignite = { "modifier_ogre_magi_ignite" },
    rubick_telekinesis = { "modifier_rubick_telekinesis_stun" },
    beastmaster_primal_roar = { "modifier_beastmaster_primal_roar_slow" },
    warlock_rain_of_chaos = { "modifier_warlock_rain_of_chaos_debuff" },
    jakiro_macropyre = { "modifier_jakiro_macropyre_burn" },
    lina_laguna_blade = {},
    item_rod_of_atos = { "modifier_rod_of_atos_debuff" },
    item_gungir = { "modifier_gungir_root" },
    item_sheepstick = { "modifier_sheepstick_debuff" },
    item_orchid = { "modifier_orchid_malevolence_debuff" },
    item_bloodthorn = { "modifier_bloodthorn_debuff" },
    item_abyssal_blade = { "modifier_abyssal_blade_stun" },
    item_heavens_halberd = { "modifier_heavens_halberd_debuff" },
}

Core.Catalog.AbilityMeta = {
    magnataur_reverse_polarity = { radiusSpecial = "pull_radius", defaultRadius = 430, noTarget = true },
    enigma_black_hole = { radiusSpecial = "radius", defaultRadius = 420, point = true, channel = true },
    tidehunter_ravage = { radiusSpecial = "radius", defaultRadius = 1250, noTarget = true },
    -- avoidAllies: place so teammates stay outside and can hit frozen enemies.
    -- L25 right (+140): special_bonus_unique_faceless_void_2 / TALENT_8.
    faceless_void_chronosphere = {
        radiusSpecial = "radius",
        defaultRadius = 500,
        point = true,
        avoidAllies = true,
        radiusTalent = "special_bonus_unique_faceless_void_2",
        radiusTalentBonus = 140,
        radiusTalentSlot = Enum.TalentTypes.TALENT_8,
    },
    -- Point dash; cast gate is CastRangeFallback (max travel), not AoE radius.
    faceless_void_time_walk = { point = true, allowSingle = true },
    axe_berserkers_call = { radiusSpecial = "radius", defaultRadius = 315, noTarget = true, allowSingle = true },
    earthshaker_echo_slam = { radiusSpecial = "echo_slam_damage_range", defaultRadius = 700, noTarget = true, allowSingle = true },
    earthshaker_fissure = { radiusSpecial = "fissure_radius", defaultRadius = 225, point = true, allowSingle = true },
    -- Scepter leap is point-cast; non-scepter stays self buff (live POINT still uses bestPosition).
    earthshaker_enchant_totem = { point = true, allowSingle = true },
    crystal_maiden_freezing_field = { radiusSpecial = "radius", defaultRadius = 810, noTarget = true, channel = true },
    warlock_rain_of_chaos = { radiusSpecial = "aoe", defaultRadius = 600, point = true },
    nevermore_requiem = { radiusSpecial = "requiem_radius", defaultRadius = 1000, noTarget = true },
    -- path_width is the damaging AoE; cast length lives in CastRangeFallback.
    jakiro_macropyre = { radiusSpecial = "path_width", defaultRadius = 500, point = true, channel = true },
    lina_light_strike_array = { radiusSpecial = "light_strike_array_aoe", defaultRadius = 250, point = true },
    invoker_sun_strike = { radiusSpecial = "area_of_effect", defaultRadius = 175, point = true },
    invoker_emp = { defaultRadius = 675, point = true, predictionTime = 1.0 },
    sniper_shrapnel = {
        radiusSpecial = "radius",
        defaultRadius = 475,
        point = true,
        debuffMods = { "modifier_sniper_shrapnel_slow", "modifier_sniper_shrapnel" },
    },
    -- Onslaught reports global/0 cast range in API; charge reaches up to 2000.
    primal_beast_onslaught = { defaultRadius = 190, point = true, channel = true, allowSingle = true },
    primal_beast_rock_throw = { defaultRadius = 225, point = true, allowSingle = true },
    -- HeroKits wave-1 AoE / gap-close meta (radii from assets/data/npc_abilities.json).
    centaur_hoof_stomp = { defaultRadius = 325, noTarget = true },
    sandking_epicenter = { defaultRadius = 500, noTarget = true, channel = true },
    sandking_burrowstrike = { defaultRadius = 150, point = true, allowSingle = true },
    slardar_slithereen_crush = { defaultRadius = 325, noTarget = true },
    rattletrap_battery_assault = { defaultRadius = 275, noTarget = true },
    rattletrap_hookshot = { defaultRadius = 125, point = true, allowSingle = true },
    mars_arena_of_blood = { defaultRadius = 550, point = true },
    mars_spear = { defaultRadius = 125, point = true, allowSingle = true },
    -- Cone / frontal slam: cast point within radius of self.
    mars_gods_rebuke = { defaultRadius = 500, point = true, allowSingle = true },
    skywrath_mage_mystic_flare = { defaultRadius = 170, point = true, allowSingle = true },
    nyx_assassin_impale = { defaultRadius = 140, point = true, allowSingle = true },
    witch_doctor_death_ward = { defaultRadius = 600, point = true, channel = true },
    shadow_shaman_mass_serpent_ward = { defaultRadius = 150, point = true },
    morphling_waveform = { defaultRadius = 200, point = true, allowSingle = true },
    -- Point field: AS for allies + enemy miss. Cast under self/local, not on enemy.
    arc_warden_magnetic_field = {
        radiusSpecial = "radius",
        defaultRadius = 300,
        point = true,
        positionPolicy = "selfOrLocal",
        allowSingle = true,
    },
}

Core.Catalog.FriendlyBuffAbilities = {
    oracle_fates_edict = true,
    oracle_purifying_flames = true,
    oracle_false_promise = true,
    dazzle_shallow_grave = true,
    dazzle_shadow_wave = true,
    ogre_magi_bloodlust = true,
    abaddon_aphotic_shield = true,
    abaddon_borrowed_time = true,
    treant_living_armor = true,
    witch_doctor_voodoo_restoration = true,
    omniknight_repel = true,
    omniknight_guardian_angel = true,
    chen_hand_of_god = true,
    enchantress_enchant = true,
    io_overcharge = true,
    io_tether = true,
    shadow_demon_disruption = true,
    shadow_demon_purge = true,
}

Core.Catalog.AbilityKindOverrides = {
    ogre_magi_ignite = "lockedEnemy",
    -- assets: NO_TARGET; Morph/live often reports POINT|UNIT|AOE — CAST_POSITION only works.
    earthshaker_enchant_totem = "bestPosition",
    -- Keep bestPosition issue path; AbilityMeta.positionPolicy = selfOrLocal.
    arc_warden_magnetic_field = "bestPosition",
}

Core.Catalog.HexAbilities = {
    lion_voodoo = true,
    shadow_shaman_voodoo = true,
    item_sheepstick = true,
}

-- +250 Hex Radius talent (Lion): area point-cast radius when Hex is converted.
Core.Catalog.HexAoeRadius = {
    lion_voodoo = 250,
}

Core.Catalog.PriorityOverrides = {
    sniper_take_aim = 985,
    sniper_shrapnel = 775,
    sniper_concussive_grenade = 770,
    sniper_assassinate = 710,
    lion_voodoo = 930,
    shadow_shaman_voodoo = 930,
    item_sheepstick = 925,
    lion_impale = 780,
    lion_finger_of_death = 700,
    -- Primal Beast: open with Trample/Uproar, gap-close Onslaught, then Rock/Pulverize.
    primal_beast_trample = 910,
    primal_beast_uproar = 900,
    primal_beast_onslaught = 870,
    primal_beast_rock_throw = 760,
    primal_beast_pulverize = 720,
    arc_warden_magnetic_field = 720,
}

Core.Catalog.CastRangeFallback = {
    item_bloodthorn = 900,
    item_orchid = 900,
    item_rod_of_atos = 1100,
    item_gungir = 1100,
    -- assets AbilityCastRange=150; hull-aware IsEntityInRange handles melee contact.
    item_abyssal_blade = 150,
    item_heavens_halberd = 750,
    item_nullifier = 900,
    item_ethereal_blade = 800,
    item_dagon = 640,
    item_spirit_vessel = 750,
    item_urn_of_shadows = 750,
    sniper_shrapnel = 1800,
    sniper_assassinate = 3000,
    invoker_cold_snap = 1000,
    invoker_tornado = 2000,
    invoker_chaos_meteor = 700,
    invoker_sun_strike = 99999,
    invoker_deafening_blast = 1000,
    invoker_alacrity = 700,
    invoker_emp = 950,
    invoker_ice_wall = 300,
    item_blink = 1200,
    item_arcane_blink = 1400,
    item_overwhelming_blink = 1200,
    item_swift_blink = 1200,
    lion_voodoo = 650,
    lion_impale = 650,
    lion_finger_of_death = 900,
    item_sheepstick = 800,
    primal_beast_onslaught = 2000,
    primal_beast_rock_throw = 1800,
    primal_beast_pulverize = 200,
    -- Max travel / cast from npc_abilities AbilityValues (API often returns 0).
    morphling_waveform = 925,
    morphling_adaptive_strike_agi = 825,
    morphling_replicate = 1000,
    faceless_void_time_walk = 800,
    mars_spear = 1200,
    mars_gods_rebuke = 500,
    magnataur_skewer = 1100,
    sandking_burrowstrike = 775,
    jakiro_macropyre = 1400,
    earthshaker_fissure = 1600,
    earthshaker_enchant_totem = 950,
}

Core.Catalog.InvokerSteps = {
    { q = 0, w = 2, e = 1, id = "invoker_alacrity", kind = "localHero", tag = "invoker_alacrity_ally" },
    { q = 1, w = 0, e = 2, id = "invoker_forge_spirit", kind = "auto", tag = "invoker_forge_spirit" },
    {
        q = 3,
        w = 0,
        e = 0,
        id = "invoker_cold_snap",
        kind = "lockedEnemy",
        tag = "invoker_cold_snap",
        linkBreak = true,
        skipMods = { "modifier_invoker_cold_snap" },
    },
    { q = 1, w = 2, e = 0, id = "invoker_tornado", kind = "auto", tag = "invoker_tornado" },
    { q = 0, w = 3, e = 0, id = "invoker_emp", kind = "auto", tag = "invoker_emp" },
    { q = 0, w = 1, e = 2, id = "invoker_chaos_meteor", kind = "bestPosition", tag = "invoker_meteor" },
    { q = 0, w = 0, e = 3, id = "invoker_sun_strike", kind = "bestPosition", tag = "invoker_sun_strike" },
    { q = 1, w = 1, e = 1, id = "invoker_deafening_blast", kind = "auto", tag = "invoker_deafening_blast" },
    { q = 2, w = 0, e = 1, id = "invoker_ice_wall", kind = "auto", tag = "invoker_ice_wall" },
    { q = 2, w = 1, e = 0, id = "invoker_ghost_walk", kind = "auto", tag = "invoker_ghost_walk" },
}

Core.Catalog.FriendlyOnlyAbilities = {
    oracle_fates_edict = true,
    oracle_purifying_flames = true,
    oracle_false_promise = true,
    dazzle_shallow_grave = true,
    abaddon_aphotic_shield = true,
    ogre_magi_bloodlust = true,
    treant_living_armor = true,
    omniknight_repel = true,
    chen_hand_of_god = true,
    io_overcharge = true,
    io_tether = true,
    shadow_demon_disruption = true,
}

Core.Catalog.SupportSelfAbilities = {
    "oracle_false_promise",
    "oracle_fates_edict",
    "oracle_purifying_flames",
    "dazzle_shallow_grave",
    "abaddon_aphotic_shield",
    "abaddon_borrowed_time",
    "ogre_magi_bloodlust",
    "treant_living_armor",
    "omniknight_repel",
    "omniknight_guardian_angel",
    "chen_hand_of_god",
    "shadow_demon_disruption",
    "io_overcharge",
    "io_tether",
}
Core.Catalog.OwnerTriggeredAbilities = {
    abaddon_borrowed_time = true,
    io_overcharge = true,
}
Core.Catalog.SkipAbilities = {
    crystal_maiden_freezing_field_stop = true,
    -- Invoker orbs/invoke are driven by the planner; only invoked spells stay in Abilities.
    invoker_quas = true,
    invoker_wex = true,
    invoker_exort = true,
    invoker_invoke = true,
    -- Charge release is cast only via Onslaught flow, not as a standalone combo ability.
    primal_beast_onslaught_release = true,
    -- Morph ult / Morph Replicate toggle: profile-owned (generic must not spam).
    morphling_morph = true,
    morphling_replicate = true,
    morphling_morph_replicate = true,
    -- Post–Time Walk escape; generic must not reverse an engage mid-combo.
    faceless_void_time_walk_reverse = true,
}

-- Confirmed once per bind normally; these may be re-queued while still castable.
Core.Catalog.ReusableComboAbilities = {
    morphling_adaptive_strike_agi = true,
    nevermore_shadowraze1 = true,
    nevermore_shadowraze2 = true,
    nevermore_shadowraze3 = true,
}

Core.Catalog.Shadowraze = {
    { id = "nevermore_shadowraze1", range = 200 },
    { id = "nevermore_shadowraze2", range = 450 },
    { id = "nevermore_shadowraze3", range = 700 },
}
Core.Catalog.ShadowrazeRadius = 250
-- Align budget: prefer closing in; avoid backing out of a fight for a farther raze.
Core.Catalog.ShadowrazeMaxClose = 140
Core.Catalog.ShadowrazeMaxBack = 100

Core.CanAlignShadowraze = function(dist, range)
    if type(dist) ~= "number" or type(range) ~= "number" then
        return false
    end
    local err = math.abs(dist - range)
    if dist < range then
        return err <= (Core.Catalog.ShadowrazeMaxBack or 100)
    end
    return err <= (Core.Catalog.ShadowrazeMaxClose or 140)
end

Core.PickBestShadowraze = function(dist)
    if type(dist) ~= "number" or dist < 0 then
        return nil
    end
    local best = nil
    local bestScore = math.huge
    for i = 1, #Core.Catalog.Shadowraze do
        local raze = Core.Catalog.Shadowraze[i]
        if Core.CanAlignShadowraze(dist, raze.range) then
            local err = math.abs(dist - raze.range)
            -- Prefer closing in over backing up.
            if dist < raze.range then
                err = err + 35
            end
            if err < bestScore then
                bestScore = err
                best = raze
            end
        end
    end
    return best
end

-- Silence/root/disarm: do not treat as hard CC for hex/sheep extend gating.
Core.Catalog.SoftDisableAbilities = {
    item_orchid = true,
    item_bloodthorn = true,
    item_rod_of_atos = true,
    item_gungir = true,
    item_heavens_halberd = true,
}

Core.Catalog.InvokerEndItems = {
    { id = "item_sheepstick", targetPolicy = "enemy" },
    { id = "item_ethereal_blade", targetPolicy = "enemy" },
    { id = "item_lotus_orb", targetPolicy = "localHero" },
}
Core.Catalog.InvokerEndItemRoles = {
    hex = Core.Catalog.InvokerEndItems[1],
    ethereal = Core.Catalog.InvokerEndItems[2],
    support = Core.Catalog.InvokerEndItems[3],
}

local Icons = {
    enable = "\u{f00c}",
    hero = "\u{f007}",
    abilities = "\u{f890}",
    items = "\u{e196}",
    gear = "\u{f013}",
    target = "\u{f05b}",
    hits = "\u{f0c0}",
    mana = "\u{f043}",
    extend = "\u{f021}",
    link = "\u{f127}",
    draw = "\u{f2d0}",
    bug = "\u{f188}",
}

--#endregion

--#region State

local Persistent = {
    logger = nil,
    overlayFont = nil,
    menuReady = false,
    ui = {},
    builtin = {
        comboKey = nil,
        lastHeroMenuName = nil,
        targetSearchRange = nil,
        unitsSearchRange = nil,
        targetStyle = nil,
        moveToCursor = nil,
    },
}
local UI = Persistent.ui
local BuiltIn = Persistent.builtin

local Runtime = {
    lastUpdateAt = -math.huge,
    lastAllyScanAt = -math.huge,
    lastTargetResolveAt = -math.huge,
    lastMultiSyncAt = -math.huge,
    lastBuiltinSyncAt = -math.huge,
    controllableAllies = {},
    selectedPlayerId = nil,
    sessionHero = nil,
    localHero = nil,
    localPlayer = nil,
    localPlayerId = nil,
    lockedEnemy = nil,
    lockedEnemyScore = nil,
    actionQueue = {},
    pending = nil,
    comboActive = false,
    comboKeyHeldPrev = false,
    comboForceResolve = false,
    syncedHeroName = nil,
    syncedAllyPlayerId = nil,
    syncedAllyRosterSig = nil,
    syncedInventorySig = nil,
    lastMoveOrderAt = -math.huge,
    lastAttackOrderAt = -math.huge,
    lastAttackTarget = nil,
    lastFollowOrderAt = -math.huge,
    lastFollowPos = nil,
    failedActions = {},
    usedActions = {},
    sfUltBurstActive = false,
    sfUltSetupId = nil,
    debugVerboseAt = {},
    shrapnelLastCastAt = 0,
    shrapnelLastPos = nil,
    shrapnelLastEnemy = nil,
    nextComboAt = 0,
    invokerComboEnemy = nil,
    invokerLastInvokeAt = 0,
    invokerAwaitSpell = nil,
    comboReleaseAt = nil,
    renderSnapshot = nil,
    orderSequence = 0,
    invokerFsm = { phase = "selectStep", spellId = nil },
    combatSnapshot = nil,
    catalogCache = nil,
    lastCatalogRefreshAt = -math.huge,
    snapshotInvalidated = true,
    emptyPlanUntil = 0,
    lastMovePos = nil,
    debugTransitions = {},
    comboTrace = {},
    comboStartedAt = nil,
    trampleOrbitAngle = nil,
    lastTrampleOrbitAt = -math.huge,
    morphSourceUnitName = nil,
    morphAwaitReplicate = false,
    morphWasReplicated = false,
    morphFormPending = false,
    morphAwaitReplicateAt = nil,
    morphFormPendingAt = nil,
    controlLostSince = nil,
}

--#endregion

--#region Helpers

local function TryCall(fn, ...)
    if type(fn) ~= "function" then
        return false, "expected a callable function"
    end
    return pcall(fn, ...)
end

---@generic T
---@param fn fun(...): T
---@param ... any
---@return T|nil
local function SafeValue(fn, ...)
    local ok, value = TryCall(fn, ...)
    if not ok then
        return nil
    end
    return value
end

local function DbgWrite(message)
    if Persistent.logger then
        Persistent.logger:info(message)
    end
end

local function IsDebugEnabled()
    return Persistent.menuReady and UI.Debug and SafeValue(UI.Debug.Get, UI.Debug) == true
end

local function IsDebugVerbose()
    return IsDebugEnabled() and UI.DebugVerbose and SafeValue(UI.DebugVerbose.Get, UI.DebugVerbose) == true
end

local function DbgVerbose(key, message, ...)
    if not IsDebugVerbose() then
        return
    end

    local now = GameRules and SafeValue(GameRules.GetGameTime) or 0
    key = key or "default"
    local lastAt = Runtime.debugVerboseAt[key] or -math.huge
    if now - lastAt < DEBUG_VERBOSE_INTERVAL then
        return
    end
    Runtime.debugVerboseAt[key] = now

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    DbgWrite((key == "event" and "[event] " or "[verbose] ") .. message)
end

-- Unthrottled verbose: plan rebuilds, queue drops, hero-profile decisions.
Core.DbgEvent = function(message, ...)
    if not IsDebugVerbose() then
        return
    end
    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    DbgWrite("[event] " .. message)
end

local function DbgTransition(key, state, message, ...)
    if not IsDebugVerbose() or Runtime.debugTransitions[key] == state then
        return
    end
    Runtime.debugTransitions[key] = state
    DbgVerbose("transition_" .. key, message, ...)
end

local function DbgImportant(message, ...)
    if not IsDebugEnabled() then
        return
    end

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    DbgWrite(message)
end

Core.FormatActionPreview = function(action)
    if not action then
        return "?"
    end
    local id = action.abilityId or action.tag or "?"
    local kind = action.kind or "?"
    local prio = type(action.priority) == "number" and action.priority or 0
    return string.format("%s:%s@%d", id, kind, prio)
end

Core.FormatPlanPreview = function(queue, limit)
    if not queue or #queue == 0 then
        return ""
    end
    limit = type(limit) == "number" and limit or 8
    local preview = {}
    for i = 1, math.min(#queue, limit) do
        preview[#preview + 1] = Core.FormatActionPreview(queue[i])
    end
    if #queue > limit then
        preview[#preview + 1] = string.format("+%d", #queue - limit)
    end
    return table.concat(preview, ", ")
end

local function OrderTag(suffix)
    return ORDER_PREFIX .. tostring(suffix)
end

local function IsOurOrder(data)
    if not data then
        return false
    end
    local id = data.identifier
    return type(id) == "string" and id:sub(1, #ORDER_PREFIX) == ORDER_PREFIX
end

local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
    return (b - a):Length2D()
end

local function HasAbilityBehaviorFlag(behavior, flag)
    if type(behavior) ~= "number" or type(flag) ~= "number" then
        return false
    end
    return (behavior & flag) ~= 0
end

local function GetAbilityId(ability)
    if not ability then
        return nil
    end
    local id = SafeValue(Ability.GetName, ability)
    if type(id) ~= "string" or id == "" then
        id = SafeValue(Ability.GetBaseName, ability)
    end
    return type(id) == "string" and id ~= "" and id or nil
end

local function NormalizeItemId(rawId)
    if type(rawId) ~= "string" or rawId == "" then
        return nil
    end

    local id = rawId:lower()
    while id:sub(1, 5) == "item_" and id:sub(6, 10) == "item_" do
        id = id:sub(6)
    end
    if id:sub(1, 5) ~= "item_" then
        id = "item_" .. id
    end
    return id
end

local function GetItemId(item)
    return NormalizeItemId(GetAbilityId(item))
end

local function IsLinkBreakItem(id)
    if not id then
        return false
    end
    for i = 1, #Core.Catalog.LinkbreakItems do
        local popId = Core.Catalog.LinkbreakItems[i]
        if popId == id then
            return true
        end
        if popId == "item_dagon" and id:match("^item_dagon") then
            return true
        end
    end
    return false
end

local function MarkActionFailed(actionKey, now)
    if actionKey then
        Runtime.failedActions[actionKey] = now + FAIL_SKIP_DURATION
    end
end

local function IsActionBlocked(actionKey, now)
    local untilTime = Runtime.failedActions[actionKey]
    return untilTime ~= nil and now < untilTime
end

local function MarkActionUsed(abilityId)
    if abilityId then
        Runtime.usedActions[abilityId] = true
    end
end

local function IsActionUsed(abilityId)
    return abilityId ~= nil and Runtime.usedActions[abilityId] == true
end

local function ShouldSkipComboItem(id)
    if not id then
        return true
    end
    if Core.Catalog.SkipItems[id] then
        return true
    end
    if id:find("recipe", 1, true) then
        return true
    end
    if id:find("ability_capture", 1, true) then
        return true
    end
    if id:find("^item_ability_") then
        return true
    end
    return false
end

local function IsKnownComboItem(id)
    if id == "item_refresher" then
        return true
    end
    if Core.Catalog.SelfItems[id] or Core.Catalog.SelfNoTargetItems[id] then
        return true
    end
    if IsLinkBreakItem(id) then
        return true
    end
    for i = 1, #Core.Catalog.BlinkItems do
        if Core.Catalog.BlinkItems[i] == id then
            return true
        end
    end
    return false
end

local function IsRealHeroItem(ability, id)
    if not ability or not id or id:sub(1, 5) ~= "item_" then
        return false
    end
    if ShouldSkipComboItem(id) then
        return false
    end
    if SafeValue(Ability.IsHidden, ability) then
        return false
    end

    local behavior = SafeValue(Ability.GetBehavior, ability, true)
        or SafeValue(Ability.GetBehavior, ability, false)
        or 0
    local isItemBehavior = HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_ITEM)
    if not isItemBehavior and not IsKnownComboItem(id) then
        return false
    end

    if Item and Item.GetCost then
        local cost = SafeValue(Item.GetCost, ability)
        if type(cost) == "number" and cost > 0 then
            return true
        end
    end

    if Item and Item.IsPermanent and SafeValue(Item.IsPermanent, ability) then
        return true
    end

    return IsKnownComboItem(id)
end

local function ActionTag(prefix, id)
    if not id then
        return prefix
    end
    return prefix .. id:gsub("^item_", "")
end

local function GetGameTime()
    return SafeValue(GameRules.GetGameTime) or 0
end

local function SaveConfigInt(key, value)
    SafeValue(Config.WriteInt, CONFIG_SECTION, key, value)
end

local function LoadConfigInt(key, defaultValue)
    local sentinel = 2147483646
    local value = SafeValue(Config.ReadInt, CONFIG_SECTION, key, sentinel)
    if value == sentinel then
        value = SafeValue(Config.ReadInt, CONFIG_SECTION_LEGACY, key, sentinel)
        if type(value) == "number" and value ~= sentinel then
            SaveConfigInt(key, value)
        end
    end
    if type(value) ~= "number" or value == sentinel then
        return defaultValue
    end
    return value
end

local function MenuIcon(widget, icon)
    if widget and icon and widget.Icon then
        SafeValue(widget.Icon, widget, icon)
    end
end

local function L(en, _)
    return en
end

local function IsValidHero(unit)
    return unit
        and SafeValue(Entity.IsAlive, unit)
        and SafeValue(Entity.IsDormant, unit) ~= true
        and SafeValue(NPC.IsIllusion, unit) ~= true
end

local function IsMagicImmune(unit)
    if not IsValidHero(unit) then
        return true
    end
    if SafeValue(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
        return true
    end
    for _, mod in ipairs(Core.Catalog.MagicImmuneModifiers) do
        if SafeValue(NPC.HasModifier, unit, mod) then
            return true
        end
    end
    return false
end

local function HasAnyModifier(unit, mods)
    if not unit or not mods then
        return false
    end
    for i = 1, #mods do
        if SafeValue(NPC.HasModifier, unit, mods[i]) then
            return true
        end
    end
    return false
end

local function GetUnitStatusResistance(unit)
    if not unit or not NPC.GetModifierPropertyHighest then
        return 0
    end
    local base = SafeValue(
        NPC.GetModifierPropertyHighest,
        unit,
        Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE
    ) or 0
    local stacking = SafeValue(
        NPC.GetModifierPropertyHighest,
        unit,
        Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING
    ) or 0
    return math.min(0.85, math.max(0, base + stacking))
end

local function GetModifierRemaining(mod, now)
    now = now or GetGameTime()

    local dieTime = SafeValue(Modifier.GetDieTime, mod)
    if type(dieTime) == "number" and dieTime > now then
        return dieTime - now
    end

    local duration = SafeValue(Modifier.GetDuration, mod)
    local created = SafeValue(Modifier.GetCreationTime, mod)
    if type(duration) == "number" and duration > 0 and type(created) == "number" and created > 0 then
        local remaining = duration - (now - created)
        if remaining > 0 then
            return remaining
        end
    end

    local lastApplied = SafeValue(Modifier.GetLastAppliedTime, mod)
    if type(duration) == "number" and duration > 0 and type(lastApplied) == "number" and lastApplied > 0 then
        local remaining = duration - (now - lastApplied)
        if remaining > 0 then
            return remaining
        end
    end

    return nil
end

local function GetActiveDisableRemaining(unit, abilityId, now)
    local mods = Core.Catalog.DisableModifiers[abilityId]
    if not unit or not mods then
        return nil
    end

    local best = nil
    for i = 1, #mods do
        if SafeValue(NPC.HasModifier, unit, mods[i]) then
            local mod = SafeValue(NPC.GetModifier, unit, mods[i])
            if mod then
                local remaining = GetModifierRemaining(mod, now)
                if remaining and (not best or remaining > best) then
                    best = remaining
                end
            end
        end
    end

    return best
end

-- Best remaining hard CC (hex/stun) across known disable modifiers.
-- Soft disables (silence/root/disarm) are excluded so sheep/hex can still land.
local function GetHardCcRemaining(unit, now)
    if not unit then
        return nil
    end
    now = now or GetGameTime()
    local best = nil
    for abilityId, mods in pairs(Core.Catalog.DisableModifiers) do
        if type(mods) == "table" and not Core.Catalog.SoftDisableAbilities[abilityId] then
            for i = 1, #mods do
                local modName = mods[i]
                if SafeValue(NPC.HasModifier, unit, modName) then
                    local mod = SafeValue(NPC.GetModifier, unit, modName)
                    if mod then
                        local remaining = GetModifierRemaining(mod, now)
                        if remaining and (not best or remaining > best) then
                            best = remaining
                        end
                    end
                end
            end
        end
    end
    return best
end

local function GetHeroDisplayName(unitName)
    if not unitName then
        return "Unknown"
    end
    if GameLocalizer and GameLocalizer.FindNPC then
        local localized = SafeValue(GameLocalizer.FindNPC, unitName)
        if type(localized) == "string" and localized ~= "" then
            return localized
        end
    end
    local short = unitName:gsub("^npc_dota_hero_", ""):gsub("_", " ")
    return short:sub(1, 1):upper() .. short:sub(2)
end

local function GetAbilityIconPath(abilityId)
    if not abilityId then
        return ""
    end
    if abilityId:sub(1, 5) == "item_" then
        return "panorama/images/items/" .. abilityId:gsub("item_", "") .. "_png.vtex_c"
    end
    return "panorama/images/spellicons/" .. abilityId .. "_png.vtex_c"
end

Core.AllyWidgetId = function(playerId)
    return "ally_" .. tostring(playerId)
end

Core.ParseAllyWidgetId = function(itemId)
    if type(itemId) ~= "string" then
        return nil
    end
    local id = itemId:match("^ally_(%-?%d+)$")
    return id and tonumber(id) or nil
end

Core.GetHeroIconPath = function(unitName)
    if not unitName or unitName == "" then
        return ""
    end
    return "panorama/images/heroes/" .. unitName .. "_png.vtex_c"
end

Core.GetSelectedAllyPlayerIdFromUI = function()
    if not UI.AllyHero or not UI.AllyHero.ListEnabled then
        return nil
    end
    local enabled = SafeValue(UI.AllyHero.ListEnabled, UI.AllyHero)
    if type(enabled) ~= "table" then
        return nil
    end
    for i = 1, #enabled do
        local playerId = Core.ParseAllyWidgetId(enabled[i])
        if type(playerId) == "number" then
            return playerId
        end
    end
    return nil
end

local function CanAct(unit)
    if not IsValidHero(unit) then
        return false
    end
    return SafeValue(NPC.IsStunned, unit) ~= true
        and SafeValue(NPC.IsSilenced, unit) ~= true
end

-- Static AbilityBehavior from assets/data/cast_catalog.lua (on Core to avoid local-limit).
do
    local ok, mod = pcall(require, "assets.data.cast_catalog")
    if ok and type(mod) == "table" then
        Core.Catalog.AssetCast = mod
    end
end

Core.Catalog.GetAssetCastInfo = function(abilityId)
    local catalog = Core.Catalog.AssetCast
    if not catalog or type(abilityId) ~= "string" then
        return nil
    end
    if abilityId:sub(1, 5) == "item_" then
        return catalog.items and catalog.items[abilityId] or nil
    end
    return catalog.abilities and catalog.abilities[abilityId] or nil
end

local function GetCastRange(unit, ability)
    if not ability then
        return 0
    end
    local range = SafeValue(Ability.GetCastRange, ability) or 0
    if range <= 0 then
        local id = GetAbilityId(ability)
        if id then
            range = Core.Catalog.CastRangeFallback[id]
            if not range and id:match("^item_dagon") then
                range = Core.Catalog.CastRangeFallback.item_dagon
            end
            if not range then
                local asset = Core.Catalog.GetAssetCastInfo(id)
                if asset then
                    range = asset.castRange or asset.scepterRange
                end
            end
            if not range and id:find("blink", 1, true) then
                range = id:find("arcane", 1, true) and 1400 or 1200
            end
        end
    end
    return (range or 0) + (SafeValue(NPC.GetCastRangeBonus, unit) or 0)
end

local function GetAttackRange(unit)
    if not unit then
        return 150
    end
    local base = SafeValue(NPC.GetAttackRange, unit) or 150
    local bonus = SafeValue(NPC.GetAttackRangeBonus, unit) or 0
    return base + bonus
end

local function IsRangedAttacker(unit)
    return SafeValue(NPC.IsRanged, unit) == true
end

local function IsWithinRange2D(fromPos, toPos, range)
    if not fromPos or not toPos then
        return false
    end
    if type(range) ~= "number" or range <= 0 then
        return false
    end
    return Dist2D(fromPos, toPos) <= range + RANGE_TOLERANCE
end

local function FormatRangeContext(ctx)
    if not IsDebugVerbose() then
        return ""
    end
    if not ctx or not ctx.controlled then
        return "ctx=nil"
    end

    local unit = ctx.controlled
    local unitName = SafeValue(NPC.GetUnitName, unit) or "?"
    local ranged = IsRangedAttacker(unit)
    local atkBase = SafeValue(NPC.GetAttackRange, unit) or 0
    local atkBonus = SafeValue(NPC.GetAttackRangeBonus, unit) or 0
    local atkTotal = GetAttackRange(unit)
    local myPos = SafeValue(Entity.GetAbsOrigin, unit)
    local running = SafeValue(NPC.IsRunning, unit)
    local attacking = SafeValue(NPC.IsAttacking, unit)

    local parts = {
        string.format("unit=%s", unitName),
        string.format("ranged=%s", tostring(ranged)),
        string.format("atk=%d(base=%d+bonus=%d)", atkTotal, atkBase, atkBonus),
        string.format("running=%s attacking=%s", tostring(running), tostring(attacking)),
        string.format("queue=%d", #Runtime.actionQueue),
        string.format("pending=%s", Runtime.pending and (Runtime.pending.tag or Runtime.pending.kind or "?") or "-"),
    }

    if ctx.enemy and myPos then
        local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
        if enemyPos then
            local dist = Dist2D(myPos, enemyPos)
            parts[#parts + 1] = string.format(
                "enemy=%s dist=%.0f inAtk=%s",
                GetHeroDisplayName(SafeValue(NPC.GetUnitName, ctx.enemy)) or "?",
                dist,
                tostring(IsWithinRange2D(myPos, enemyPos, atkTotal))
            )
        end
    elseif Runtime.lockedEnemy and myPos then
        local enemyPos = SafeValue(Entity.GetAbsOrigin, Runtime.lockedEnemy)
        if enemyPos then
            local dist = Dist2D(myPos, enemyPos)
            parts[#parts + 1] = string.format(
                "lock=%s dist=%.0f inAtk=%s",
                GetHeroDisplayName(SafeValue(NPC.GetUnitName, Runtime.lockedEnemy)) or "?",
                dist,
                tostring(IsWithinRange2D(myPos, enemyPos, atkTotal))
            )
        end
    end

    parts[#parts + 1] = string.format("combo=%s", tostring(Runtime.comboActive))

    if type(ctx.mana) == "number" then
        parts[#parts + 1] = string.format("mana=%.0f", ctx.mana)
    end

    if Runtime.lockedEnemy and ctx.enemy then
        parts[#parts + 1] = string.format(
            "lockSame=%s",
            tostring(Runtime.lockedEnemy == ctx.enemy)
        )
    end

    return table.concat(parts, " | ")
end

local function GetManaPct(unit)
    local maxMana = SafeValue(NPC.GetMaxMana, unit) or 0
    if maxMana <= 0 then
        return 100
    end
    return ((SafeValue(NPC.GetMana, unit) or 0) / maxMana) * 100
end

local function GetScreenXY(point)
    if point == nil or type(point) == "number" then
        return nil, nil
    end

    local x = point.x
    local y = point.y
    if type(x) == "number" and type(y) == "number" then
        return x, y
    end

    return nil, nil
end

local function WorldToScreen(world)
    if not Render or not Render.WorldToScreen or not world then
        return nil, nil, false
    end

    local ok, a, b, c = TryCall(Render.WorldToScreen, world)
    if not ok then
        return nil, nil, false
    end

    if type(a) == "number" and type(b) == "number" then
        return a, b, c ~= false
    end

    if a ~= nil then
        local x, y = GetScreenXY(a)
        return x, y, b ~= false
    end

    return nil, nil, false
end

local function GetCursorPosXY()
    if not Input or not Input.GetCursorPos then
        return nil, nil
    end

    local ok, a, b = TryCall(Input.GetCursorPos)
    if not ok then
        return nil, nil
    end

    if type(a) == "number" and type(b) == "number" then
        return a, b
    end

    return GetScreenXY(a)
end

local function TargetNeedsLinkBreak(target)
    return target and SafeValue(NPC.IsLinkensProtected, target) == true
end

--#endregion

--#region Orders

function Core.OrderGateway.Issue(player, orderType, target, pos, ability, issuerUnit, identifier)
    if not player or not issuerUnit then
        return false
    end

    pos = pos or SafeValue(Entity.GetAbsOrigin, issuerUnit) or Vector(0, 0, 0)

    if Player and Player.PrepareUnitOrders then
        local ok = TryCall(
            Player.PrepareUnitOrders,
            player,
            orderType,
            target,
            pos,
            ability,
            ORDER_ISSUER,
            issuerUnit,
            false,
            false,
            ability ~= nil,
            true,
            identifier,
            false
        )
        if ok then
            if orderType ~= O_MOVE then
                Runtime.lastMovePos = nil
            end
            if IsDebugVerbose() then
                local myPos = SafeValue(Entity.GetAbsOrigin, issuerUnit)
                local moveDist = myPos and pos and Dist2D(myPos, pos) or -1
                DbgVerbose("event",
                    "order | %s id=%s moveDist=%.0f ability=%s",
                    orderType == O_ATTACK and "ATTACK"
                        or orderType == O_MOVE and "MOVE"
                        or orderType == O_CAST_TARGET and "CAST_TARGET"
                        or orderType == O_CAST_POSITION and "CAST_POSITION"
                        or orderType == O_CAST_NO_TARGET and "CAST_NO_TARGET"
                        or tostring(orderType),
                    identifier or "?",
                    moveDist,
                    ability and (GetAbilityId(ability) or "?") or "-"
                )
            end
            return true
        end
    end

    return false
end

local function GetAbilityBehaviorFlags(ability)
    local live = SafeValue(Ability.GetBehavior, ability, false)
    if type(live) == "number" then
        return live
    end
    local static = SafeValue(Ability.GetBehavior, ability, true)
    return type(static) == "number" and static or 0
end

local function AbilityNeedsPointCast(ability, abilityId)
    if not ability then
        return false
    end
    local behavior = GetAbilityBehaviorFlags(ability)
    local hasPoint = HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_POINT)
    local hasUnit = HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
    -- Enchant Totem live form is POINT|UNIT|AOE; only CAST_POSITION executes.
    if abilityId == "earthshaker_enchant_totem" and hasPoint then
        return true
    end
    -- Lion/SS Hex +25 talent: unit-target becomes area/point-targeted.
    if Core.Catalog.HexAbilities[abilityId] and hasPoint and not hasUnit then
        return true
    end
    if hasPoint and not hasUnit then
        return true
    end
    return false
end

-- Defined after AOE helpers; used by CastDisableOnEnemy for talent hex.
local FindHexPointCastPosition

local function CastOnTarget(ctx, ability, target, tag, identifier)
    local pos = SafeValue(Entity.GetAbsOrigin, target) or SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    return Core.OrderGateway.Issue(
        ctx.player,
        O_CAST_TARGET,
        target,
        pos,
        ability,
        ctx.controlled,
        identifier or OrderTag(tag)
    )
end

local function CastAtPosition(ctx, ability, pos, tag, identifier)
    return Core.OrderGateway.Issue(
        ctx.player,
        O_CAST_POSITION,
        nil,
        pos,
        ability,
        ctx.controlled,
        identifier or OrderTag(tag)
    )
end

local function CastDisableOnEnemy(ctx, ability, abilityId, target, tag, identifier)
    if AbilityNeedsPointCast(ability, abilityId) then
        local pos = FindHexPointCastPosition
            and FindHexPointCastPosition(ctx, ability, abilityId, target)
            or SafeValue(Entity.GetAbsOrigin, target)
        if not pos then
            return false
        end
        DbgImportant("point cast | %s", abilityId or tag or "?")
        return CastAtPosition(ctx, ability, pos, tag, identifier)
    end
    return CastOnTarget(ctx, ability, target, tag, identifier)
end

local function CastNoTarget(ctx, ability, tag, identifier)
    local pos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    if Player and Player.PrepareUnitOrders then
        return Core.OrderGateway.Issue(
            ctx.player,
            O_CAST_NO_TARGET,
            nil,
            pos,
            ability,
            ctx.controlled,
            identifier or OrderTag(tag)
        )
    end
    return false
end

--#endregion

--#region Inventory scan

local function CollectHeroAbilities(hero)
    local out = {}
    local seen = {}

    for index = 0, FALLBACK_ABILITY_SLOTS - 1 do
        local ability = SafeValue(NPC.GetAbilityByIndex, hero, index)
        if ability then
            local id = GetAbilityId(ability)
                if id and not seen[id] then
                    seen[id] = true
                    if id:sub(1, 14) ~= "invoker_empty"
                        and not Core.Catalog.SkipAbilities[id]
                        and SafeValue(Ability.IsHidden, ability) ~= true
                    and SafeValue(Ability.IsPassive, ability, true) ~= true
                    and SafeValue(Ability.IsAttributes, ability) ~= true
                    and id:sub(1, 5) ~= "item_" then
                    out[#out + 1] = { ability = ability, id = id }
                end
            end
        end
    end

    table.sort(out, function(a, b)
        local ua = SafeValue(Ability.IsUltimate, a.ability) and 1 or 0
        local ub = SafeValue(Ability.IsUltimate, b.ability) and 1 or 0
        if ua ~= ub then
            return ua > ub
        end
        return a.id < b.id
    end)

    return out
end

local function CollectHeroItems(hero)
    local out = {}
    local seenIds = {}
    local seenHandles = {}

    local function AddItem(item)
        if not item or seenHandles[item] then
            return
        end
        seenHandles[item] = true

        local id = GetItemId(item)
        if not id or not IsRealHeroItem(item, id) or seenIds[id] then
            return
        end

        seenIds[id] = true
        out[#out + 1] = { item = item, id = id }
    end

    for index = 0, FALLBACK_ITEM_SLOTS - 1 do
        AddItem(SafeValue(NPC.GetItemByIndex, hero, index))
    end

    for _, id in ipairs(Core.Catalog.LinkbreakItems) do
        if not seenIds[id] then
            AddItem(SafeValue(NPC.GetItem, hero, id, true))
        end
    end

    for _, id in ipairs(Core.Catalog.BlinkItems) do
        if not seenIds[id] then
            AddItem(SafeValue(NPC.GetItem, hero, id, true))
        end
    end
    if not seenIds.item_refresher then
        AddItem(SafeValue(NPC.GetItem, hero, "item_refresher", true))
    end

    table.sort(out, function(a, b)
        return a.id < b.id
    end)

    return out
end

local function GetInventorySignature(hero)
    local parts = {}
    for _, entry in ipairs(CollectHeroItems(hero)) do
        parts[#parts + 1] = "i:" .. entry.id
    end
    for _, entry in ipairs(CollectHeroAbilities(hero)) do
        parts[#parts + 1] = "a:" .. entry.id
    end
    return table.concat(parts, ",")
end

local function FindAbilityEntry(hero, abilityId)
    local snapshot = Runtime.combatSnapshot
    if snapshot and snapshot.controlled == hero and snapshot.abilitiesById then
        local cached = snapshot.abilitiesById[abilityId]
        if cached then
            return cached
        end
    end
    for _, entry in ipairs(CollectHeroAbilities(hero)) do
        if entry.id == abilityId then
            return entry.ability
        end
    end
    return SafeValue(NPC.GetAbility, hero, abilityId)
end

local function FindInvokerBarSpell(hero, abilityId)
    if not hero or not abilityId then
        return nil
    end
    local snapshot = Runtime.combatSnapshot
    if snapshot and snapshot.controlled == hero and snapshot.abilitiesById then
        local cached = snapshot.abilitiesById[abilityId]
        if cached and SafeValue(Ability.IsHidden, cached) ~= true then
            return cached
        end
    end
    for index = 0, FALLBACK_ABILITY_SLOTS - 1 do
        local ability = SafeValue(NPC.GetAbilityByIndex, hero, index)
        if ability then
            local id = GetAbilityId(ability)
            if id == abilityId and SafeValue(Ability.IsHidden, ability) ~= true then
                return ability
            end
        end
    end
    return nil
end

local function FindItemEntry(hero, itemId)
    local snapshot = Runtime.combatSnapshot
    if snapshot and snapshot.controlled == hero and snapshot.itemsById then
        local cached = snapshot.itemsById[itemId]
        if cached then
            return cached
        end
    end
    local item = SafeValue(NPC.GetItem, hero, itemId, true)
    if item then
        return item
    end
    for _, entry in ipairs(CollectHeroItems(hero)) do
        if entry.id == itemId then
            return entry.item
        end
    end
    return nil
end

-- usedActions blocks re-queue within one cast cycle; once CD is up again, allow reuse
-- while the combo bind stays held (do not wait for bind release / EndSession).
local function ClearUsedActionsWhenReady(ctx)
    if not ctx or not ctx.controlled then
        return
    end
    local mana = ctx.mana or 0
    for abilityId, used in pairs(Runtime.usedActions) do
        if used == true and type(abilityId) == "string" then
            local ability = FindAbilityEntry(ctx.controlled, abilityId)
            if not ability and abilityId:sub(1, 5) == "item_" then
                ability = FindItemEntry(ctx.controlled, abilityId)
            end
            if not ability then
                Runtime.usedActions[abilityId] = nil
            elseif SafeValue(Ability.IsCastable, ability, mana) then
                Runtime.usedActions[abilityId] = nil
            end
        end
    end
end

local function GetBlink(hero)
    for _, id in ipairs(Core.Catalog.BlinkItems) do
        if IsActionUsed(id) then
            goto continue_blink_item
        end
        local blink = SafeValue(NPC.GetItem, hero, id, true)
        if blink then
            return blink, id
        end
        ::continue_blink_item::
    end
    return nil, nil
end

--#endregion

--#region Classifier

local function ClassifyAbilityPolicy(ability, abilityId)
    local kindOverride = Core.Catalog.AbilityKindOverrides[abilityId]
    if kindOverride then
        return kindOverride, Core.Catalog.AbilityMeta[abilityId]
    end

    local meta = Core.Catalog.AbilityMeta[abilityId]
    local asset = Core.Catalog.GetAssetCastInfo(abilityId)
    local behavior = GetAbilityBehaviorFlags(ability)
    local liveHasPoint = HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_POINT)
    local liveHasNoTarget = HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_NO_TARGET)

    -- Asset KV kind first. Live POINT without NO_TARGET (Morph Totem / Aghs leap) overrides
    -- static noTarget when we have point meta or asset hasScepter leap.
    if asset and asset.kind then
        if asset.kind == "noTarget"
            and liveHasPoint
            and not liveHasNoTarget
            and (asset.hasScepter or (meta and meta.point))
        then
            return "bestPosition", meta
        end
        return asset.kind, meta
    end

    local team = SafeValue(Ability.GetTargetTeam, ability, false)
        or SafeValue(Ability.GetTargetTeam, ability, true)
        or TT.DOTA_UNIT_TARGET_TEAM_NONE

    -- Live POINT wins over static NO_TARGET (Enchant Totem Morph/Aghs leap bits).
    if liveHasPoint
        and not liveHasNoTarget
        and meta
        and meta.point then
        return "bestPosition", meta
    end

    if HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
        return "noTarget", meta
    end

    -- Talent-converted Hex is point-targeted; keep it as lockedEnemy so disable
    -- gating still applies, and cast path switches to CAST_POSITION.
    if Core.Catalog.HexAbilities[abilityId] then
        return "lockedEnemy", meta
    end

    if Core.Catalog.FriendlyOnlyAbilities[abilityId]
        or Core.Catalog.FriendlyBuffAbilities[abilityId] == true
        or team == TT.DOTA_UNIT_TARGET_TEAM_FRIENDLY then
        return "localHero"
    end

    if HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
        if team == TT.DOTA_UNIT_TARGET_TEAM_ENEMY or team == TT.DOTA_UNIT_TARGET_TEAM_BOTH then
            return "lockedEnemy"
        end
        if team == TT.DOTA_UNIT_TARGET_TEAM_FRIENDLY then
            return "localHero"
        end
    end

    if meta then
        return "bestPosition", meta
    end

    if HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_POINT)
        or HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_AOE) then
        return "bestPosition", meta
    end

    return nil
end

local function ClassifyItemPolicy(item, itemId)
    if ShouldSkipComboItem(itemId) then
        return nil
    end
    if itemId == "item_refresher" then
        return "noTarget"
    end
    if Core.Catalog.SelfNoTargetItems[itemId] then
        return "noTarget"
    end
    local asset = Core.Catalog.GetAssetCastInfo(itemId)
    if asset and asset.kind then
        if itemId:find("blink", 1, true) then
            return "bestPosition"
        end
        if IsLinkBreakItem(itemId) and asset.kind == "lockedEnemy" then
            return "linkbreak"
        end
        return asset.kind
    end
    local behavior = item and (
        SafeValue(Ability.GetBehavior, item, true)
        or SafeValue(Ability.GetBehavior, item, false)
    ) or 0
    local team = item and (
        SafeValue(Ability.GetTargetTeam, item, true)
        or SafeValue(Ability.GetTargetTeam, item, false)
    ) or TT.DOTA_UNIT_TARGET_TEAM_NONE
    if HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
        return "noTarget"
    end
    if IsLinkBreakItem(itemId) then
        return "linkbreak"
    end
    if Core.Catalog.SelfItems[itemId] then
        return "localHero"
    end
    if itemId:find("blink", 1, true) then
        return "bestPosition"
    end
    if HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
        if team == TT.DOTA_UNIT_TARGET_TEAM_FRIENDLY then
            return "localHero"
        end
        if team == TT.DOTA_UNIT_TARGET_TEAM_ENEMY or team == TT.DOTA_UNIT_TARGET_TEAM_BOTH then
            return "lockedEnemy"
        end
        return nil
    end
    if HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_POINT) then
        return "bestPosition"
    end
    return nil
end

local function GetAoeRadius(ability, abilityId, meta)
    meta = meta or Core.Catalog.AbilityMeta[abilityId]
    if not meta then
        return 0
    end
    -- Ability.GetLevelSpecialValueFor is contradictory in the 1.2.3 stubs.
    -- Keep core planning on the verified catalog fallback until runtime proves it.
    local radius = meta.defaultRadius or 0
    if meta.radiusTalent and type(meta.radiusTalentBonus) == "number" and ability then
        local owner = SafeValue(Ability.GetOwner, ability)
        if owner and Core.HeroHasLearnedTalent(owner, meta.radiusTalent, meta.radiusTalentSlot) then
            radius = radius + meta.radiusTalentBonus
        end
    end
    return radius
end

-- Talent learned? Prefer ability level; optional Enum.TalentTypes slot as fallback.
function Core.HeroHasLearnedTalent(hero, talentId, talentSlot)
    if not hero or type(talentId) ~= "string" then
        return false
    end
    local talent = SafeValue(NPC.GetAbility, hero, talentId)
    if talent then
        local level = SafeValue(Ability.GetLevel, talent)
        if type(level) == "number" and level > 0 then
            return true
        end
    end
    if talentSlot ~= nil then
        return SafeValue(Hero.TalentIsLearned, hero, talentSlot) == true
    end
    return false
end

local function IsAbilityEnabled(abilityId)
    local snapshot = Runtime.combatSnapshot
    if snapshot and snapshot.enabledAbilitiesById
        and snapshot.enabledAbilitiesById[abilityId] ~= nil then
        return snapshot.enabledAbilitiesById[abilityId]
    end
    if not UI.Abilities or not UI.Abilities.Get then
        return true
    end
    local listed = SafeValue(UI.Abilities.List, UI.Abilities)
    if type(listed) ~= "table" or #listed == 0 then
        return true
    end
    return UI.Abilities:Get(abilityId) == true
end

local function IsItemEnabled(itemId)
    local snapshot = Runtime.combatSnapshot
    if snapshot and snapshot.enabledItemsById
        and snapshot.enabledItemsById[itemId] ~= nil then
        return snapshot.enabledItemsById[itemId]
    end
    if not UI.Items or not UI.Items.Get then
        return true
    end
    local listed = SafeValue(UI.Items.List, UI.Items)
    if type(listed) ~= "table" or #listed == 0 then
        return true
    end
    return UI.Items:Get(itemId) == true
end

local function LocalHeroNeedsHelp(localHero)
    if not IsValidHero(localHero) then
        return false
    end
    if HasAnyModifier(localHero, Core.Catalog.LocalBuffModifiers) then
        return true
    end
    if HasAnyModifier(localHero, Core.Catalog.DispellableModifiers) then
        return true
    end
    local hp = SafeValue(Entity.GetHealth, localHero) or 0
    local maxHp = SafeValue(Entity.GetMaxHealth, localHero) or 1
    if maxHp > 0 and (hp / maxHp) < 0.45 then
        return true
    end
    return SafeValue(NPC.IsSilenced, localHero) == true
        or SafeValue(NPC.HasState, localHero, Enum.ModifierState.MODIFIER_STATE_ROOTED) == true
end

--#endregion

--#region AOE / cluster

local function GetEnemiesNear(origin, radius, controlled)
    if not origin or not controlled then
        return {}
    end
    local teamNum = SafeValue(Entity.GetTeamNum, controlled)
    if teamNum == nil then
        return {}
    end
    return SafeValue(Heroes.InRadius, origin, radius, teamNum, TEAM_ENEMY, true, true) or {}
end

-- Allied heroes near origin; excludes `controlled` (Void is immune to his Chronosphere).
-- On Core to avoid the chunk local/upvalue limit.
function Core.GetAlliesNear(origin, radius, controlled)
    if not origin or not controlled then
        return {}
    end
    local teamNum = SafeValue(Entity.GetTeamNum, controlled)
    if teamNum == nil then
        return {}
    end
    local raw = SafeValue(
        Heroes.InRadius,
        origin,
        radius,
        teamNum,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    ) or {}
    local out = {}
    for i = 1, #raw do
        local ally = raw[i]
        if ally ~= controlled and IsValidHero(ally) then
            out[#out + 1] = ally
        end
    end
    return out
end

local function CountHitsAt(origin, entries, radius)
    local count = 0
    for i = 1, #entries do
        local entry = entries[i]
        local pos = IsValidHero(entry) and SafeValue(Entity.GetAbsOrigin, entry) or entry
        if pos and Dist2D(origin, pos) <= radius then
            count = count + 1
        end
    end
    return count
end

-- Optional `allies`: prefer centers that freeze 0 teammates (Chronosphere, etc.).
local function FindBestAoePosition(origin, enemies, radius, minHits, predictionTime, allies)
    minHits = minHits or 1
    local bestPos = nil
    local bestHits = 0
    local bestAllyHits = math.huge
    local positions = {}
    local allyPositions = {}

    if #enemies == 0 then
        return nil, 0
    end

    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsValidHero(enemy) and not IsMagicImmune(enemy) then
            local pos = SafeValue(Entity.GetAbsOrigin, enemy)
            if pos then
                if predictionTime and predictionTime > 0 and SafeValue(NPC.IsRunning, enemy) then
                    local rotation = SafeValue(Entity.GetRotation, enemy)
                    local forward = rotation and rotation:GetForward()
                    local speed = SafeValue(NPC.GetMoveSpeed, enemy) or 0
                    if forward and speed > 0 then
                        pos = Vector(
                            pos.x + forward.x * speed * predictionTime,
                            pos.y + forward.y * speed * predictionTime,
                            pos.z
                        )
                    end
                end
                positions[#positions + 1] = pos
            end
        end
    end

    if allies then
        for i = 1, #allies do
            local ally = allies[i]
            local pos = IsValidHero(ally) and SafeValue(Entity.GetAbsOrigin, ally) or nil
            if pos then
                allyPositions[#allyPositions + 1] = pos
            end
        end
    end

    -- Slightly larger clear radius so allies can stand just outside and attack in.
    -- Extra pad for hull / talent AoE growth not fully reflected in catalog.
    local allyClear = (#allyPositions > 0) and (radius + 80) or radius

    local function consider(pos)
        if not pos then
            return
        end
        local hits = CountHitsAt(pos, positions, radius)
        if hits <= 0 then
            return
        end
        local allyHits = (#allyPositions > 0) and CountHitsAt(pos, allyPositions, allyClear) or 0
        if allyHits < bestAllyHits
            or (allyHits == bestAllyHits and hits > bestHits)
            or (allyHits == bestAllyHits and hits == bestHits and origin and bestPos
                and Dist2D(origin, pos) < Dist2D(origin, bestPos)) then
            bestAllyHits = allyHits
            bestHits = hits
            bestPos = pos
        end
    end

    for i = 1, #positions do
        consider(positions[i])
    end

    for i = 1, #positions do
        local aPos = positions[i]
        for j = i + 1, #positions do
            local bPos = positions[j]
            local mid = Vector(
                (aPos.x + bPos.x) * 0.5,
                (aPos.y + bPos.y) * 0.5,
                (aPos.z + bPos.z) * 0.5
            )
            consider(mid)

            local dx = bPos.x - aPos.x
            local dy = bPos.y - aPos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > 0.001 and distance <= radius * 2 then
                local height = math.sqrt(math.max(0, radius * radius - distance * distance * 0.25))
                local nx = -dy / distance
                local ny = dx / distance
                consider(Vector(mid.x + nx * height, mid.y + ny * height, mid.z))
                consider(Vector(mid.x - nx * height, mid.y - ny * height, mid.z))
            end
        end
    end

    -- Push candidate centers away from nearby allies so enemies stay in and teammates out.
    if #allyPositions > 0 then
        for i = 1, #positions do
            local ePos = positions[i]
            local nearest = nil
            local nearestDist = math.huge
            for j = 1, #allyPositions do
                local d = Dist2D(ePos, allyPositions[j])
                if d < nearestDist then
                    nearestDist = d
                    nearest = allyPositions[j]
                end
            end
            if nearest and nearestDist < allyClear * 2 then
                local dx = ePos.x - nearest.x
                local dy = ePos.y - nearest.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 0.001 then
                    local ux, uy = dx / len, dy / len
                    -- Need Dist(center, ally) > allyClear and Dist(center, enemy) <= radius.
                    local needT = allyClear - nearestDist
                    if needT < 0 then
                        needT = 0
                    end
                    if needT <= radius then
                        consider(Vector(ePos.x + ux * needT, ePos.y + uy * needT, ePos.z))
                        local t2 = math.min(radius * 0.92, needT + 90)
                        consider(Vector(ePos.x + ux * t2, ePos.y + uy * t2, ePos.z))
                    end
                end
            end
        end
    end

    if not bestPos or bestHits < minHits then
        return nil, bestHits
    end

    return bestPos, bestHits
end

local function FindBlinkPositionForAoe(controlled, enemies, radius, minHits, allies)
    local blink, blinkId = GetBlink(controlled)
    if not blink or not blinkId then
        return nil, nil, 0
    end
    if IsActionBlocked(blinkId, GetGameTime()) then
        return nil, nil, 0
    end

    local mana = SafeValue(NPC.GetMana, controlled) or 0
    if not SafeValue(Ability.IsCastable, blink, mana) then
        return nil, nil, 0
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, controlled)
    if not myPos then
        return nil, nil, 0
    end

    local blinkRange = GetCastRange(controlled, blink)
    local scanRadius = blinkRange + radius + SCAN_RADIUS_BUFFER
    local allEnemies = GetEnemiesNear(myPos, scanRadius, controlled)
    if #allEnemies == 0 then
        allEnemies = enemies
    end

    local bestPos, bestHits = FindBestAoePosition(myPos, allEnemies, radius, minHits, nil, allies)
    if not bestPos or Dist2D(myPos, bestPos) > blinkRange then
        return nil, blink, bestHits
    end

    return bestPos, blink, bestHits
end

-- Land near a single enemy for unit-target initiation (e.g. Pulverize).
local function FindBlinkLandNearEnemy(controlled, enemy, landDist)
    local blink, blinkId = GetBlink(controlled)
    if not blink or not blinkId then
        return nil, nil, nil
    end
    if IsActionUsed(blinkId) or IsActionBlocked(blinkId, GetGameTime()) then
        return nil, nil, nil
    end

    local mana = SafeValue(NPC.GetMana, controlled) or 0
    if not SafeValue(Ability.IsCastable, blink, mana) then
        return nil, nil, nil
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, controlled)
    local enemyPos = enemy and SafeValue(Entity.GetAbsOrigin, enemy)
    if not myPos or not enemyPos then
        return nil, nil, nil
    end

    local dist = Dist2D(myPos, enemyPos)
    local wantLand = type(landDist) == "number" and landDist or 140
    if dist <= wantLand + 40 then
        return nil, blink, blinkId
    end

    local blinkRange = GetCastRange(controlled, blink)
    if blinkRange <= 0 then
        blinkRange = 1200
    end

    local landPos = enemyPos:Extend2D(myPos, wantLand)
    local need = Dist2D(myPos, landPos)
    if need > blinkRange then
        landPos = myPos:Extend2D(enemyPos, blinkRange - 25)
    end

    return landPos, blink, blinkId
end

-- Gap-close first: blink toward locked enemy when still far.
local function TryAppendInitiateBlink(ctx, actions, opts)
    opts = opts or {}
    if not ctx or not ctx.controlled or not ctx.enemy or not actions then
        return false
    end

    local minDist = type(opts.minDist) == "number" and opts.minDist or 450
    local landDist = type(opts.landDist) == "number" and opts.landDist or 140
    local priority = type(opts.priority) == "number" and opts.priority or 980

    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
    if not myPos or not enemyPos then
        return false
    end
    local dist = Dist2D(myPos, enemyPos)
    if dist < minDist then
        DbgVerbose("initiate_blink_skip",
            "initiate_blink | skip tooClose dist=%.0f min=%.0f landWant=%.0f | %s",
            dist,
            minDist,
            landDist,
            FormatRangeContext(ctx)
        )
        return false
    end

    local landPos, blink, blinkId = FindBlinkLandNearEnemy(ctx.controlled, ctx.enemy, landDist)
    if not blink or not landPos or not blinkId then
        DbgVerbose("initiate_blink_skip",
            "initiate_blink | skip noLand dist=%.0f landWant=%.0f | %s",
            dist,
            landDist,
            FormatRangeContext(ctx)
        )
        return false
    end
    if not IsItemEnabled(blinkId) then
        DbgVerbose("initiate_blink_skip",
            "initiate_blink | skip disabled id=%s | %s",
            blinkId,
            FormatRangeContext(ctx)
        )
        return false
    end

    actions[#actions + 1] = {
        kind = "bestPosition",
        ability = blink,
        abilityId = blinkId,
        position = landPos,
        positionTtl = 0.12,
        positionMaxRange = GetCastRange(ctx.controlled, blink),
        priority = priority,
        tag = opts.tag or "initiate_blink",
    }
    Core.DbgEvent(
        "initiate_blink | queue id=%s dist=%.0f -> land=%.0f prio=%d | %s",
        blinkId,
        dist,
        landDist,
        priority,
        FormatRangeContext(ctx)
    )
    return true
end

--#endregion

--#region Target resolver

local function CanTargetEnemy(enemy, controlled)
    return IsValidHero(enemy)
        and SafeValue(Entity.IsSameTeam, enemy, controlled) ~= true
        and SafeValue(NPC.IsVisible, enemy) ~= false
        and not IsMagicImmune(enemy)
end

local function GetHexAoeRadius(abilityId)
    if not abilityId then
        return 0
    end
    return Core.Catalog.HexAoeRadius[abilityId] or 0
end

FindHexPointCastPosition = function(ctx, ability, abilityId, preferTarget)
    local aoeRadius = GetHexAoeRadius(abilityId)
    local preferPos = preferTarget and SafeValue(Entity.GetAbsOrigin, preferTarget) or nil
    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    if not myPos then
        return preferPos
    end
    if aoeRadius <= 0 then
        return preferPos
    end

    local castRange = GetCastRange(ctx.controlled, ability)
    if castRange <= 0 then
        return preferPos
    end

    local scan = GetEnemiesNear(myPos, castRange + aoeRadius, ctx.controlled)
    local candidates = {}
    for i = 1, #scan do
        local enemy = scan[i]
        if CanTargetEnemy(enemy, ctx.controlled) then
            candidates[#candidates + 1] = enemy
        end
    end

    local minCluster = UI.MinClusterHits and SafeValue(UI.MinClusterHits.Get, UI.MinClusterHits) or 2
    local bestPos, bestHits = FindBestAoePosition(myPos, candidates, aoeRadius, 1, 0)
    if not bestPos then
        return preferPos
    end

    local function inCastRange(pos)
        return pos and Dist2D(myPos, pos) <= castRange + RANGE_TOLERANCE
    end

    -- Prefer a cluster that still covers the locked enemy when one is locked.
    if preferPos then
        local coversPreferred = Dist2D(bestPos, preferPos) <= aoeRadius
        if not coversPreferred or (bestHits < minCluster and #candidates >= minCluster) then
            local nearPreferred = GetEnemiesNear(preferPos, aoeRadius * 2, ctx.controlled)
            local clustered = {}
            for i = 1, #nearPreferred do
                local enemy = nearPreferred[i]
                if CanTargetEnemy(enemy, ctx.controlled) then
                    clustered[#clustered + 1] = enemy
                end
            end
            local altPos, altHits = FindBestAoePosition(preferPos, clustered, aoeRadius, 1, 0)
            if altPos and inCastRange(altPos) and Dist2D(altPos, preferPos) <= aoeRadius then
                if altHits >= bestHits or coversPreferred == false then
                    bestPos, bestHits = altPos, altHits
                end
            elseif inCastRange(preferPos) then
                bestPos, bestHits = preferPos, CountHitsAt(preferPos, clustered, aoeRadius)
            end
        end
    end

    if not inCastRange(bestPos) then
        return inCastRange(preferPos) and preferPos or nil
    end

    if IsDebugVerbose() and bestHits > 1 then
        DbgVerbose("event", "hex aoe | hits=%d radius=%d | %s",
            bestHits, aoeRadius, abilityId or "?")
    end
    return bestPos
end

local function InvalidateLostTarget(controlled)
    if Runtime.lockedEnemy and not CanTargetEnemy(Runtime.lockedEnemy, controlled) then
        Runtime.lockedEnemy = nil
        Runtime.lockedEnemyScore = nil
        Runtime.actionQueue = {}
        if Runtime.pending and (Runtime.pending.kind == "lockedEnemy" or Runtime.pending.kind == "linkbreak") then
            Runtime.pending = nil
        end
    end
end

local function GetTargetSearchRadius()
    local widget = BuiltIn.unitsSearchRange or BuiltIn.targetSearchRange
    if widget and widget.Get then
        local value = SafeValue(widget.Get, widget)
        if type(value) == "number" and value > 0 then
            return value
        end
    end
    return 1600
end

local function GetTargetStyleMode()
    -- ControlAlly Target Mode is the script authority; BuiltIn Style is only a fallback.
    if UI.TargetMode and UI.TargetMode.Get then
        local idx = SafeValue(UI.TargetMode.Get, UI.TargetMode)
        if type(idx) == "number" then
            return idx == TARGET_STYLE_SCORE and TARGET_STYLE_SCORE or TARGET_STYLE_CURSOR
        end
    end

    local widget = BuiltIn.targetStyle
    if widget and widget.Get and widget.List then
        local idx = SafeValue(widget.Get, widget) or 0
        local items = SafeValue(widget.List, widget)
        if type(items) == "table" and items[idx + 1] then
            local label = string.lower(tostring(items[idx + 1]))
            if label:find("cursor", 1, true) then
                return TARGET_STYLE_CURSOR
            end
            if label:find("score", 1, true) or label:find("smart", 1, true) or label:find("auto", 1, true) then
                return TARGET_STYLE_SCORE
            end
        end
        return idx == 0 and TARGET_STYLE_CURSOR or TARGET_STYLE_SCORE
    end

    return TARGET_STYLE_CURSOR
end

local function GetMovementEnemy(ctx)
    if not ctx or not ctx.controlled then
        return nil
    end
    if ctx.enemy and CanTargetEnemy(ctx.enemy, ctx.controlled) then
        return ctx.enemy
    end
    if Runtime.lockedEnemy and CanTargetEnemy(Runtime.lockedEnemy, ctx.controlled) then
        return Runtime.lockedEnemy
    end
    return nil
end

local function ShouldFollowCursor(ctx)
    local widget = BuiltIn.moveToCursor
    if widget and widget.Get and SafeValue(widget.Get, widget) == false then
        return false
    end
    if Runtime.comboActive then
        if ctx and GetMovementEnemy(ctx) then
            return false
        end
        return true
    end
    return true
end

local function WithMovementEnemy(ctx, fn)
    if not ctx or type(fn) ~= "function" then
        return false
    end
    local enemy = GetMovementEnemy(ctx)
    if not enemy then
        return false
    end
    local prev = ctx.enemy
    ctx.enemy = enemy
    local ok = fn(ctx)
    ctx.enemy = prev
    return ok
end

local function ScoreEnemy(enemy, controlled, clusterRadius, minCluster)
    if not CanTargetEnemy(enemy, controlled) then
        return -math.huge
    end

    local score = 1000
    if SafeValue(NPC.IsHero, enemy) then
        score = score + 500
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, enemy)
    if myPos and enemyPos then
        local dist = Dist2D(myPos, enemyPos)
        score = score - dist * 0.35
    end

    if TargetNeedsLinkBreak(enemy) then
        score = score - 200
    end
    if IsMagicImmune(enemy) then
        score = score - 5000
    end

    if clusterRadius and clusterRadius > 0 and enemyPos then
        local nearby = GetEnemiesNear(enemyPos, clusterRadius * 1.5, controlled)
        local hits = CountHitsAt(enemyPos, nearby, clusterRadius)
        if hits >= (minCluster or 2) then
            score = score + hits * 400
        end
    end

    return score
end

local function ResolveTargetByCursor(controlled, enemies, searchRadius)
    local myPos = SafeValue(Entity.GetAbsOrigin, controlled)
    local cursorWorld = Input and SafeValue(Input.GetWorldCursorPos) or nil
    local best = nil
    local bestDist = math.huge

    -- Prefer world distance to cursor (100–300). Screen fallback only if world pos missing.
    local cx, cy = nil, nil
    if not cursorWorld then
        if not Input or not Input.GetCursorPos or not Render then
            return nil
        end
        cx, cy = GetCursorPosXY()
        if not cx or not cy then
            return nil
        end
    end

    for i = 1, #enemies do
        local enemy = enemies[i]
        if CanTargetEnemy(enemy, controlled) then
            local pos = SafeValue(Entity.GetAbsOrigin, enemy)
            if pos then
                if myPos and searchRadius and Dist2D(myPos, pos) > searchRadius then
                    goto continue_cursor
                end
                local dist
                if cursorWorld then
                    dist = Dist2D(cursorWorld, pos)
                    if dist > CURSOR_WORLD_PICK_MAX then
                        goto continue_cursor
                    end
                else
                    local sx, sy, visible = WorldToScreen(pos)
                    if not (sx and sy and visible) then
                        goto continue_cursor
                    end
                    local dx = sx - cx
                    local dy = sy - cy
                    dist = math.sqrt(dx * dx + dy * dy)
                    if dist > CURSOR_MAX_SCREEN_DIST then
                        goto continue_cursor
                    end
                end
                if dist < bestDist then
                    bestDist = dist
                    best = enemy
                end
            end
            ::continue_cursor::
        end
    end

    -- Prefer a tight hover (≤ min) when several heroes sit in the 300 ring.
    if best and cursorWorld and bestDist > CURSOR_WORLD_PICK_MIN then
        local tight = nil
        local tightDist = math.huge
        for i = 1, #enemies do
            local enemy = enemies[i]
            if CanTargetEnemy(enemy, controlled) then
                local pos = SafeValue(Entity.GetAbsOrigin, enemy)
                if pos then
                    local d = Dist2D(cursorWorld, pos)
                    if d <= CURSOR_WORLD_PICK_MIN and d < tightDist then
                        tightDist = d
                        tight = enemy
                    end
                end
            end
        end
        if tight then
            return tight
        end
    end

    return best
end

local function CursorPickWithinWorldRadius(controlled, candidate)
    if not candidate or not CanTargetEnemy(candidate, controlled) then
        return nil
    end
    local cursorWorld = Input and SafeValue(Input.GetWorldCursorPos) or nil
    local enemyPos = SafeValue(Entity.GetAbsOrigin, candidate)
    if not cursorWorld or not enemyPos then
        return nil
    end
    if Dist2D(cursorWorld, enemyPos) <= CURSOR_WORLD_PICK_MAX then
        return candidate
    end
    return nil
end

local function ResolveTargetByNearest(controlled, searchRadius, allowFar)
    local teamNum = SafeValue(Entity.GetTeamNum, controlled)
    if not (Input and Input.GetNearestHeroToCursor and teamNum) then
        return nil
    end
    local enemy = SafeValue(Input.GetNearestHeroToCursor, teamNum, TEAM_ENEMY)
    if not enemy or not CanTargetEnemy(enemy, controlled) then
        return nil
    end
    -- Require cursor world proximity (never accept a max-search-radius pick).
    if not CursorPickWithinWorldRadius(controlled, enemy) then
        return nil
    end
    if allowFar then
        return enemy
    end
    local myPos = SafeValue(Entity.GetAbsOrigin, controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, enemy)
    if myPos and enemyPos and Dist2D(myPos, enemyPos) <= searchRadius then
        return enemy
    end
    return nil
end

local function ResolveTargetByScore(controlled, enemies, clusterRadius, minCluster)
    local best = nil
    local bestScore = -math.huge

    for i = 1, #enemies do
        local enemy = enemies[i]
        local score = ScoreEnemy(enemy, controlled, clusterRadius, minCluster)
        if score > bestScore then
            bestScore = score
            best = enemy
        end
    end

    return best, bestScore
end

local function ResolveLockedEnemy(ctx, force)
    local now = ctx.now
    local controlled = ctx.controlled
    local styleMode = GetTargetStyleMode()

    InvalidateLostTarget(controlled)

    local searchRadius = GetTargetSearchRadius()
    local myPos = SafeValue(Entity.GetAbsOrigin, controlled)
    local minCluster = UI.MinClusterHits and SafeValue(UI.MinClusterHits.Get, UI.MinClusterHits) or 2
    local clusterRadius = 450

    -- Cursor intent overrides sticky lock in both modes (HUD under mouse = combat target).
    if myPos then
        local enemies = GetEnemiesNear(myPos, searchRadius, controlled)
        if #enemies == 0 then
            local localHero = Runtime.localHero or SafeValue(Heroes.GetLocal)
            if localHero then
                local lhPos = SafeValue(Entity.GetAbsOrigin, localHero)
                if lhPos then
                    enemies = GetEnemiesNear(lhPos, searchRadius, controlled)
                end
            end
        end
        if #enemies > 0 then
            local cursorPick = ResolveTargetByCursor(controlled, enemies, searchRadius)
                or ResolveTargetByNearest(controlled, searchRadius, false)
            if cursorPick and Runtime.lockedEnemy ~= cursorPick then
                local score = ScoreEnemy(cursorPick, controlled, clusterRadius, minCluster)
                if Runtime.lockedEnemy and IsDebugEnabled() then
                    DbgImportant(
                        "target switch | %s -> %s",
                        GetHeroDisplayName(SafeValue(NPC.GetUnitName, Runtime.lockedEnemy)) or "?",
                        GetHeroDisplayName(SafeValue(NPC.GetUnitName, cursorPick)) or "?"
                    )
                end
                Runtime.lockedEnemy = cursorPick
                Runtime.lockedEnemyScore = score
                Runtime.lastTargetResolveAt = now
                Runtime.actionQueue = {}
                if Runtime.pending
                    and Runtime.pending.target
                    and Runtime.pending.target ~= cursorPick
                    and (Runtime.pending.kind == "lockedEnemy"
                        or Runtime.pending.kind == "linkbreak"
                        or Runtime.pending.kind == "bestPosition")
                then
                    Runtime.pending = nil
                end
                return cursorPick, score
            end
        end
    end

    -- Score mode: sticky lock while combo is held and target stays in range.
    -- Cursor mode: re-resolve on interval so the lock follows the cursor.
    if styleMode == TARGET_STYLE_SCORE
        and Runtime.comboActive
        and Runtime.lockedEnemy
        and CanTargetEnemy(Runtime.lockedEnemy, controlled)
    then
        local enemyPos = SafeValue(Entity.GetAbsOrigin, Runtime.lockedEnemy)
        if myPos and enemyPos and Dist2D(myPos, enemyPos) <= searchRadius + SCAN_RADIUS_BUFFER then
            if not force and now - Runtime.lastTargetResolveAt < TARGET_RESOLVE_INTERVAL then
                return Runtime.lockedEnemy, Runtime.lockedEnemyScore
            end
            Runtime.lastTargetResolveAt = now
            return Runtime.lockedEnemy, Runtime.lockedEnemyScore
        end
    end

    if not force and Runtime.lockedEnemy and now - Runtime.lastTargetResolveAt < TARGET_RESOLVE_INTERVAL then
        if CanTargetEnemy(Runtime.lockedEnemy, controlled) then
            return Runtime.lockedEnemy, Runtime.lockedEnemyScore
        end
    end

    Runtime.lastTargetResolveAt = now

    if not myPos then
        Runtime.lockedEnemy = nil
        Runtime.lockedEnemyScore = nil
        return nil, nil
    end

    local enemies = GetEnemiesNear(myPos, searchRadius, controlled)
    if #enemies == 0 then
        local localHero = Runtime.localHero or SafeValue(Heroes.GetLocal)
        if localHero then
            local lhPos = SafeValue(Entity.GetAbsOrigin, localHero)
            if lhPos then
                enemies = GetEnemiesNear(lhPos, searchRadius, controlled)
            end
        end
    end
    if #enemies == 0 then
        if Runtime.lockedEnemy and CanTargetEnemy(Runtime.lockedEnemy, controlled) then
            return Runtime.lockedEnemy, Runtime.lockedEnemyScore
        end
        Runtime.lockedEnemy = nil
        Runtime.lockedEnemyScore = nil
        Runtime.actionQueue = {}
        return nil, nil
    end

    local picked, score
    if styleMode == TARGET_STYLE_SCORE then
        picked, score = ResolveTargetByScore(controlled, enemies, clusterRadius, minCluster)
    else
        -- Cursor: only lock/switch when a hero is within 100–300 of the world cursor.
        -- Do not fall back to nearest-to-self (that felt like max search-radius targeting).
        picked = ResolveTargetByCursor(controlled, enemies, searchRadius)
            or ResolveTargetByNearest(controlled, searchRadius, false)
        if not picked then
            if Runtime.lockedEnemy and CanTargetEnemy(Runtime.lockedEnemy, controlled) then
                return Runtime.lockedEnemy, Runtime.lockedEnemyScore
            end
            Runtime.lockedEnemy = nil
            Runtime.lockedEnemyScore = nil
            return nil, nil
        end
        score = ScoreEnemy(picked, controlled, clusterRadius, minCluster)
    end

    if not picked or not CanTargetEnemy(picked, controlled) then
        Runtime.lockedEnemy = nil
        Runtime.lockedEnemyScore = nil
        return nil, nil
    end

    if styleMode == TARGET_STYLE_SCORE
        and Runtime.lockedEnemy
        and picked
        and Runtime.lockedEnemy ~= picked
    then
        local oldScore = Runtime.lockedEnemyScore or ScoreEnemy(Runtime.lockedEnemy, controlled, clusterRadius, minCluster)
        local newScore = score or -math.huge
        if oldScore + TARGET_LOCK_BONUS >= newScore and CanTargetEnemy(Runtime.lockedEnemy, controlled) then
            return Runtime.lockedEnemy, oldScore
        end
    end

    Runtime.lockedEnemy = picked
    Runtime.lockedEnemyScore = score
    return picked, score
end

local function EnsureCtxEnemy(ctx)
    if not ctx or not ctx.controlled then
        return
    end
    if ctx.enemy and CanTargetEnemy(ctx.enemy, ctx.controlled) then
        return
    end

    local enemy = GetMovementEnemy(ctx)
    if enemy then
        ctx.enemy = enemy
        return
    end

    if Runtime.comboActive then
        local picked = ResolveLockedEnemy(ctx, true)
        if picked then
            ctx.enemy = picked
        end
    end
end

--#endregion

--#region Ally discovery

local function RefreshControllableAllies(now)
    if now - Runtime.lastAllyScanAt < ALLY_SCAN_INTERVAL then
        return
    end
    Runtime.lastAllyScanAt = now

    local localPlayer = SafeValue(Players.GetLocal)
    if not localPlayer then
        return
    end

    Runtime.localPlayer = localPlayer
    Runtime.localPlayerId = SafeValue(Player.GetPlayerID, localPlayer)
    Runtime.localHero = SafeValue(Heroes.GetLocal)

    local allies = {}
    local rosterParts = {}
    local allPlayers = SafeValue(Players.GetAll) or {}

    for i = 1, #allPlayers do
        local pl = allPlayers[i]
        local playerId = SafeValue(Player.GetPlayerID, pl)
        local hero = SafeValue(Player.GetAssignedHero, pl)
        if hero
            and Runtime.localHero
            and hero ~= Runtime.localHero
            and IsValidHero(hero)
            and SafeValue(Entity.IsSameTeam, hero, Runtime.localHero)
            and Runtime.localPlayerId
            and SafeValue(Entity.IsControllableByPlayer, hero, Runtime.localPlayerId) then
            local unitName = SafeValue(NPC.GetUnitName, hero) or "unknown"
            local display = GetHeroDisplayName(unitName)
            local slot = type(playerId) == "number" and (playerId + 1) or i
            local label = string.format("%s (P%d)", display, slot)
            allies[#allies + 1] = {
                player = pl,
                playerId = playerId,
                hero = hero,
                unitName = unitName,
                label = label,
            }
            rosterParts[#rosterParts + 1] = Core.AllyWidgetId(playerId) .. ":" .. unitName
        end
    end

    -- During Morph/transform the ally can briefly leave the controllable list.
    -- Keep the previous sticky entry so ResolveControlledHero does not jump allies.
    if Runtime.comboActive and type(Runtime.selectedPlayerId) == "number" then
        local stillListed = false
        for i = 1, #allies do
            if allies[i].playerId == Runtime.selectedPlayerId then
                stillListed = true
                break
            end
        end
        if not stillListed then
            local prev = nil
            for i = 1, #Runtime.controllableAllies do
                local entry = Runtime.controllableAllies[i]
                if entry and entry.playerId == Runtime.selectedPlayerId then
                    prev = entry
                    break
                end
            end
            if prev then
                allies[#allies + 1] = prev
            else
                return
            end
        end
    end

    table.sort(allies, function(a, b)
        return (a.playerId or 0) < (b.playerId or 0)
    end)
    rosterParts = {}
    for i = 1, #allies do
        local entry = allies[i]
        rosterParts[#rosterParts + 1] = Core.AllyWidgetId(entry.playerId)
            .. ":"
            .. tostring(entry.unitName or "")
    end

    Runtime.controllableAllies = allies

    if UI.AllyHero and UI.AllyHero.Update then
        local savedId = LoadConfigInt("ally_player_id", -1)
        if type(Runtime.selectedPlayerId) == "number" then
            savedId = Runtime.selectedPlayerId
        end

        local selectedId = nil
        if savedId >= 0 then
            for i = 1, #allies do
                if allies[i].playerId == savedId then
                    selectedId = savedId
                    break
                end
            end
        end
        if selectedId == nil and allies[1] then
            selectedId = allies[1].playerId
        end

        table.sort(rosterParts)
        local identitySig = table.concat(rosterParts, "|")
        if identitySig ~= Runtime.syncedAllyRosterSig then
            Runtime.syncedAllyRosterSig = identitySig
            local items = {}
            local tips = {}
            for i = 1, #allies do
                local entry = allies[i]
                local itemId = Core.AllyWidgetId(entry.playerId)
                items[#items + 1] = {
                    itemId,
                    Core.GetHeroIconPath(entry.unitName),
                    entry.playerId == selectedId,
                }
                tips[itemId] = entry.label
            end
            if #items == 0 then
                items[1] = { "none", "", false }
                tips.none = L("No controllable ally", "Нет доступного союзника")
            end
            -- expanded=false avoids reopen animation on roster rebuild.
            SafeValue(UI.AllyHero.Update, UI.AllyHero, items, false, false)
            if UI.AllyHero.UpdateToolTips then
                SafeValue(UI.AllyHero.UpdateToolTips, UI.AllyHero, tips)
            end
        elseif selectedId ~= nil and UI.AllyHero.Set then
            local uiSelected = Core.GetSelectedAllyPlayerIdFromUI()
            if uiSelected ~= selectedId then
                SafeValue(UI.AllyHero.Set, UI.AllyHero, Core.AllyWidgetId(selectedId), true)
            end
        end
    end
end

local function ResolveAllyEntryByPlayerId(playerId)
    if playerId == nil then
        return nil
    end
    for i = 1, #Runtime.controllableAllies do
        local entry = Runtime.controllableAllies[i]
        if entry and entry.playerId == playerId then
            return entry
        end
    end
    return nil
end

local function RefreshAllyEntryHero(entry)
    if not entry then
        return nil
    end
    if entry.player then
        local live = SafeValue(Player.GetAssignedHero, entry.player)
        if live then
            entry.hero = live
            local name = SafeValue(NPC.GetUnitName, live)
            if name then
                entry.unitName = name
            end
        end
    end
    return entry.hero
end

local function ResolveControlledHero()
    if #Runtime.controllableAllies == 0 then
        return nil
    end

    local uiPlayerId = Core.GetSelectedAllyPlayerIdFromUI()
    local uiEntry = ResolveAllyEntryByPlayerId(uiPlayerId)

    -- Sticky slot: never jump to another ally when the selected hero flickers (Morph / transform).
    local preferredId = Runtime.selectedPlayerId
    if preferredId == nil then
        preferredId = uiPlayerId
    end

    local entry = ResolveAllyEntryByPlayerId(preferredId) or uiEntry
    if not entry then
        return nil
    end

    local hero = RefreshAllyEntryHero(entry)
    if hero and SafeValue(NPC.IsIllusion, hero) == true then
        -- Scepter Morph illusion is controllable but must not steal the combo session.
        hero = nil
    end

    if not hero or SafeValue(Entity.IsDormant, hero) == true then
        if Runtime.comboActive or Runtime.sessionHero then
            return nil
        end
        -- Menu idle only: fall back to first listed ally.
        entry = Runtime.controllableAllies[1]
        hero = RefreshAllyEntryHero(entry)
        if hero and SafeValue(NPC.IsIllusion, hero) == true then
            hero = nil
        end
    end

    if not entry or not hero then
        return nil
    end

    if type(entry.playerId) == "number" and Runtime.selectedPlayerId ~= entry.playerId then
        SaveConfigInt("ally_player_id", entry.playerId)
    end
    Runtime.selectedPlayerId = entry.playerId
    return hero
end

--#endregion

--#region Multiselect sync

local function SyncAbilityItemWidgets(hero, force)
    if not hero then
        return
    end

    local playerId = Runtime.selectedPlayerId
    local sig = GetInventorySignature(hero)
    if not force
        and playerId == Runtime.syncedAllyPlayerId
        and sig == Runtime.syncedInventorySig then
        return
    end
    if sig ~= Runtime.syncedInventorySig then
        Runtime.snapshotInvalidated = true
        Runtime.catalogCache = nil
    end

    Runtime.syncedAllyPlayerId = playerId
    Runtime.syncedInventorySig = sig
    Runtime.syncedHeroName = SafeValue(NPC.GetUnitName, hero)

    if UI.Abilities and UI.Abilities.Update then
        local abilityItems = {}
        for _, entry in ipairs(CollectHeroAbilities(hero)) do
            abilityItems[#abilityItems + 1] = {
                entry.id,
                GetAbilityIconPath(entry.id),
                LoadConfigInt("abl_" .. entry.id, 1) == 1,
            }
        end
        if #abilityItems == 0 then
            abilityItems[1] = { "none", "", false }
        end
        SafeValue(UI.Abilities.Update, UI.Abilities, abilityItems, true, false)
        local seenIds = {}
        for i = 1, #abilityItems do
            seenIds[abilityItems[i][1]] = true
        end
        if Runtime.syncedHeroName == "npc_dota_hero_invoker" then
            for i = 1, #Core.Catalog.InvokerSteps do
                local spellId = Core.Catalog.InvokerSteps[i].id
                if not seenIds[spellId] then
                    abilityItems[#abilityItems + 1] = {
                        spellId,
                        GetAbilityIconPath(spellId),
                        LoadConfigInt("abl_" .. spellId, 1) == 1,
                    }
                    seenIds[spellId] = true
                end
            end
            SafeValue(UI.Abilities.Update, UI.Abilities, abilityItems, true, false)
        elseif Runtime.syncedHeroName == "npc_dota_hero_morphling" then
            -- Ult is SkipAbilities (profile-cast); still expose a toggle in Abilities.
            local morphUltIds = { "morphling_replicate", "morphling_morph" }
            local added = false
            for i = 1, #morphUltIds do
                local spellId = morphUltIds[i]
                if not seenIds[spellId] and SafeValue(NPC.GetAbility, hero, spellId) then
                    abilityItems[#abilityItems + 1] = {
                        spellId,
                        GetAbilityIconPath(spellId),
                        LoadConfigInt("abl_" .. spellId, 1) == 1,
                    }
                    seenIds[spellId] = true
                    added = true
                end
            end
            if added then
                SafeValue(UI.Abilities.Update, UI.Abilities, abilityItems, true, false)
            end
        end
    end

    if UI.Items and UI.Items.Update then
        local itemWidgets = {}
        for _, entry in ipairs(CollectHeroItems(hero)) do
            itemWidgets[#itemWidgets + 1] = {
                entry.id,
                GetAbilityIconPath(entry.id),
                LoadConfigInt("itm_" .. entry.id, 1) == 1,
            }
        end
        local widgetSeen = {}
        for wi = 1, #itemWidgets do
            widgetSeen[itemWidgets[wi][1]] = true
        end
        for _, ensureId in ipairs(Core.Catalog.LinkbreakItems) do
            if not widgetSeen[ensureId] and SafeValue(NPC.GetItem, hero, ensureId, true) then
                itemWidgets[#itemWidgets + 1] = {
                    ensureId,
                    GetAbilityIconPath(ensureId),
                    LoadConfigInt("itm_" .. ensureId, 1) == 1,
                }
                widgetSeen[ensureId] = true
            end
        end
        if #itemWidgets == 0 then
            itemWidgets[1] = { "none", "", false }
        end
        SafeValue(UI.Items.Update, UI.Items, itemWidgets, true, false)
    end
end

--#endregion

--#region Hero profiles

local function ShouldCastDisable(ctx, enemy, abilityId, ability)
    if not enemy then
        return false
    end

    local remaining = GetActiveDisableRemaining(enemy, abilityId, ctx.now)
    if not remaining then
        remaining = GetHardCcRemaining(enemy, ctx.now)
    end
    if not remaining or remaining <= 0 then
        -- Unknown duration but still hard-CC'd: wait instead of stacking hex on stun.
        if SafeValue(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_HEXED)
            or SafeValue(NPC.IsStunned, enemy) then
            return false
        end
        return true
    end

    local extendEnabled = UI.ExtendDisables and SafeValue(UI.ExtendDisables.Get, UI.ExtendDisables)
    if not extendEnabled then
        return false
    end

    local castPoint = SafeValue(Ability.GetCastPoint, ability, true) or 0.2
    return remaining <= castPoint + EXTEND_BUFFER
end

local function BuildGenericAoeUltPlan(ctx, actions, abilityId)
    if not IsAbilityEnabled(abilityId) then
        return
    end

    if IsActionUsed(abilityId) or IsActionBlocked(abilityId, ctx.now) then
        return
    end

    local ability = FindAbilityEntry(ctx.controlled, abilityId)
    if not ability then
        return
    end
    if not SafeValue(Ability.IsCastable, ability, ctx.mana) then
        return
    end

    local meta = Core.Catalog.AbilityMeta[abilityId]
    local radius = GetAoeRadius(ability, abilityId, meta)
    local minHits = UI.MinClusterHits and SafeValue(UI.MinClusterHits.Get, UI.MinClusterHits) or 2
    -- Combo on a locked target: allow single-hero AOE when that enemy is already in radius.
    if Runtime.comboActive and ctx.enemy and (meta == nil or meta.allowSingle ~= false) then
        local myCheck = ctx.snapshot and ctx.snapshot.positions.controlled
            or SafeValue(Entity.GetAbsOrigin, ctx.controlled)
        local enemyCheck = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
        if myCheck and enemyCheck and Dist2D(myCheck, enemyCheck) <= radius then
            minHits = 1
        end
    end
    local myPos = ctx.snapshot and ctx.snapshot.positions.controlled
        or SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemies = GetEnemiesNear(myPos, radius + 900, ctx.controlled)
    local allies = nil
    if meta and meta.avoidAllies then
        allies = Core.GetAlliesNear(myPos, radius + 900, ctx.controlled)
    end
    local blinkPlanned = nil

    local blinkPos, blink = FindBlinkPositionForAoe(ctx.controlled, enemies, radius, minHits, allies)
    if blink and blinkPos then
        local blinkId = GetAbilityId(blink)
        if blinkId and not IsActionUsed(blinkId) and not IsActionBlocked(blinkId, ctx.now)
            and SafeValue(Ability.IsCastable, blink, ctx.mana) then
            actions[#actions + 1] = {
                kind = "bestPosition",
                ability = blink,
                abilityId = blinkId,
                position = blinkPos,
                positionTtl = 0.12,
                resolverAbility = ability,
                resolverAbilityId = abilityId,
                meta = meta,
                requiredHits = minHits,
                positionMaxRange = GetCastRange(ctx.controlled, blink),
                priority = 860,
                tag = abilityId .. "_blink",
            }
            blinkPlanned = blinkId
        end
    end

    if meta and meta.noTarget then
        local hits = CountHitsAt(myPos, enemies, radius)
        local lockedInRadius = false
        if ctx.enemy then
            local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
            lockedInRadius = enemyPos ~= nil and Dist2D(myPos, enemyPos) <= radius
        end
        -- Combo with a locked hero: never fire Call/Stomp on creep clusters far from the lock.
        local comboOk = true
        if Runtime.comboActive and ctx.enemy then
            comboOk = lockedInRadius or blinkPlanned ~= nil
        end
        if comboOk and (hits >= minHits or blinkPlanned or (Runtime.comboActive and lockedInRadius and minHits <= 1)) then
            actions[#actions + 1] = {
                kind = "noTarget",
                ability = ability,
                abilityId = abilityId,
                priority = 840,
                tag = abilityId,
                requiredHits = minHits,
                aoeRadius = radius,
                requiresAction = blinkPlanned,
            }
        end
        return
    end

    local pos, hits = FindBestAoePosition(myPos, enemies, radius, minHits, nil, allies)
    if pos and hits >= minHits then
        actions[#actions + 1] = {
            kind = "bestPosition",
            ability = ability,
            abilityId = abilityId,
            position = pos,
            priority = 840,
            tag = abilityId,
            minHits = hits,
            requiredHits = minHits,
            requiresAction = blinkPlanned,
            meta = meta,
        }
    end
end

local function BuildChanneledDisablePlan(ctx, actions, abilityId)
    if not IsAbilityEnabled(abilityId) or not ctx.enemy then
        return
    end
    local ability = FindAbilityEntry(ctx.controlled, abilityId)
    if not ability or not SafeValue(Ability.IsCastable, ability, ctx.mana) then
        return
    end
    if not ShouldCastDisable(ctx, ctx.enemy, abilityId, ability) then
        return
    end
    actions[#actions + 1] = {
        kind = "lockedEnemy",
        ability = ability,
        abilityId = abilityId,
        priority = 780,
        tag = abilityId,
    }
end

local function GetModifierStacks(unit, modName)
    if not unit or not modName then
        return 0
    end
    local mod = SafeValue(NPC.GetModifier, unit, modName)
    if not mod then
        return 0
    end
    return SafeValue(Modifier.GetStackCount, mod) or 0
end

local function IsPrimalBeastTrampling(controlled)
    return controlled
        and SafeValue(NPC.HasModifier, controlled, "modifier_primal_beast_trample") == true
end

-- Trample while moving; Uproar needs stacks; Onslaught gap-closes before Pulverize.
local function BuildPrimalBeastPlan(ctx, actions)
    if not ctx.enemy or not ctx.controlled then
        return
    end

    local trampling = IsPrimalBeastTrampling(ctx.controlled)
    if trampling then
        MarkActionUsed("primal_beast_trample")
    end

    local uproarStacks = GetModifierStacks(ctx.controlled, "modifier_primal_beast_uproar")
    if uproarStacks <= 0 then
        MarkActionUsed("primal_beast_uproar")
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
    local dist = myPos and enemyPos and Dist2D(myPos, enemyPos) or 0

    -- #1 initiate: blink in, else shard Rock Throw when still far.
    local rockAsInitiate = false
    local initiated = TryAppendInitiateBlink(ctx, actions, {
        minDist = 450,
        landDist = 140,
        priority = 980,
        tag = "primal_beast_initiate_blink",
    })
    if not initiated
        and dist >= 450
        and IsAbilityEnabled("primal_beast_rock_throw")
        and not IsActionUsed("primal_beast_rock_throw")
        and not IsActionBlocked("primal_beast_rock_throw", ctx.now)
    then
        local rock = FindAbilityEntry(ctx.controlled, "primal_beast_rock_throw")
        if rock and SafeValue(Ability.IsCastable, rock, ctx.mana) then
            actions[#actions + 1] = {
                kind = "bestPosition",
                ability = rock,
                abilityId = "primal_beast_rock_throw",
                meta = Core.Catalog.AbilityMeta.primal_beast_rock_throw,
                allowSingle = true,
                priority = 975,
                tag = "primal_beast_initiate_rock",
            }
            rockAsInitiate = true
        end
    end

    if IsAbilityEnabled("primal_beast_trample") and not IsActionUsed("primal_beast_trample")
        and not IsActionBlocked("primal_beast_trample", ctx.now) then
        local trample = FindAbilityEntry(ctx.controlled, "primal_beast_trample")
        if trample and SafeValue(Ability.IsCastable, trample, ctx.mana) then
            actions[#actions + 1] = {
                kind = "noTarget",
                ability = trample,
                abilityId = "primal_beast_trample",
                priority = 910,
                tag = "ability_primal_beast_trample",
            }
        end
    end

    if IsAbilityEnabled("primal_beast_uproar") and not IsActionUsed("primal_beast_uproar")
        and not IsActionBlocked("primal_beast_uproar", ctx.now)
        and uproarStacks > 0 then
        local uproar = FindAbilityEntry(ctx.controlled, "primal_beast_uproar")
        if uproar and SafeValue(Ability.IsCastable, uproar, ctx.mana) then
            actions[#actions + 1] = {
                kind = "noTarget",
                ability = uproar,
                abilityId = "primal_beast_uproar",
                priority = 900,
                tag = "ability_primal_beast_uproar",
            }
        end
    end

    if IsAbilityEnabled("primal_beast_onslaught") and not IsActionUsed("primal_beast_onslaught")
        and not IsActionBlocked("primal_beast_onslaught", ctx.now) then
        local onslaught = FindAbilityEntry(ctx.controlled, "primal_beast_onslaught")
        if onslaught and SafeValue(Ability.IsCastable, onslaught, ctx.mana) then
            actions[#actions + 1] = {
                kind = "bestPosition",
                ability = onslaught,
                abilityId = "primal_beast_onslaught",
                meta = Core.Catalog.AbilityMeta.primal_beast_onslaught,
                allowSingle = true,
                priority = 870,
                tag = "ability_primal_beast_onslaught",
            }
        end
    end

    -- Rock as normal nuke when it was not the initiate gap-close.
    if not rockAsInitiate
        and IsAbilityEnabled("primal_beast_rock_throw")
        and not IsActionUsed("primal_beast_rock_throw")
        and not IsActionBlocked("primal_beast_rock_throw", ctx.now)
    then
        local rock = FindAbilityEntry(ctx.controlled, "primal_beast_rock_throw")
        if rock and SafeValue(Ability.IsCastable, rock, ctx.mana) then
            actions[#actions + 1] = {
                kind = "bestPosition",
                ability = rock,
                abilityId = "primal_beast_rock_throw",
                meta = Core.Catalog.AbilityMeta.primal_beast_rock_throw,
                allowSingle = true,
                priority = 760,
                tag = "ability_primal_beast_rock_throw",
            }
        end
    end

    -- Pulverize after Trample; blink-for-ult only as ProcessCombo fallback.
    if not trampling
        and IsAbilityEnabled("primal_beast_pulverize")
        and not IsActionUsed("primal_beast_pulverize")
        and not IsActionBlocked("primal_beast_pulverize", ctx.now) then
        local ult = FindAbilityEntry(ctx.controlled, "primal_beast_pulverize")
        if ult and SafeValue(Ability.IsCastable, ult, ctx.mana) then
            actions[#actions + 1] = {
                kind = "lockedEnemy",
                ability = ult,
                abilityId = "primal_beast_pulverize",
                priority = 720,
                tag = "ability_primal_beast_pulverize",
            }
        end
    end
end

local MORPH_AGI_SHIFT_IDS = {
    "morphling_morph_agi",
    "morphling_attribute_shift_agility",
}
local MORPH_STR_SHIFT_IDS = {
    "morphling_morph_str",
    "morphling_attribute_shift_strength",
}
local MORPH_ULT_IDS = {
    "morphling_replicate",
    "morphling_morph",
}
local MORPH_REPLICATE_MOD = "modifier_morphling_replicate"

local function FindFirstAbilityByIds(hero, ids)
    for i = 1, #ids do
        local ability = FindAbilityEntry(hero, ids[i])
        if ability then
            return ability, ids[i]
        end
    end
    return nil, nil
end

local function IsMorphlingReplicated(hero)
    return hero and SafeValue(NPC.HasModifier, hero, MORPH_REPLICATE_MOD) == true
end

local function InferMorphSourceUnitName(controlled)
    if not controlled then
        return nil
    end
    local abilities = CollectHeroAbilities(controlled)
    if #abilities == 0 then
        return nil
    end
    local scores = {}
    for unitName, kit in pairs(Core.Catalog.HeroKits) do
        local steps = kit and kit.steps
        if type(steps) == "table" then
            for si = 1, #steps do
                local stepId = steps[si] and steps[si].id
                if stepId then
                    for ai = 1, #abilities do
                        if abilities[ai].id == stepId then
                            scores[unitName] = (scores[unitName] or 0) + 1
                        end
                    end
                end
            end
        end
    end
    local bestName, bestScore = nil, 0
    for unitName, score in pairs(scores) do
        if score > bestScore then
            bestName = unitName
            bestScore = score
        end
    end
    return bestName
end

local function ResolveMorphSourceUnitName(ctx)
    if Runtime.morphSourceUnitName then
        return Runtime.morphSourceUnitName
    end
    local inferred = InferMorphSourceUnitName(ctx and ctx.controlled)
    if inferred then
        Runtime.morphSourceUnitName = inferred
        return inferred
    end
    if ctx and ctx.enemy then
        return SafeValue(NPC.GetUnitName, ctx.enemy)
    end
    return nil
end

local function MorphWaveformLandPos(controlled, enemy)
    local myPos = SafeValue(Entity.GetAbsOrigin, controlled)
    local enemyPos = enemy and SafeValue(Entity.GetAbsOrigin, enemy)
    if not myPos or not enemyPos then
        return nil
    end
    local dist = Dist2D(myPos, enemyPos)
    if dist < 1 then
        return enemyPos
    end
    -- Surf through the target so Waveform actually closes and deals path damage.
    local overshoot = 120
    local castRange = 925
    local waveform = FindAbilityEntry(controlled, "morphling_waveform")
    if waveform then
        local ranged = GetCastRange(controlled, waveform)
        if ranged and ranged > 0 then
            castRange = ranged
        end
    end
    local travel = math.min(castRange, dist + overshoot)
    return myPos:Extend2D(enemyPos, travel)
end

-- Native form: Waveform → Ethereal → Adaptive → Morph.
-- Morphed form: steal target kit/profile; generic planner casts remaining stolen spells.
local function BuildMorphlingPlan(ctx, actions)
    if not ctx.controlled then
        return
    end

    if IsMorphlingReplicated(ctx.controlled) then
        Runtime.morphAwaitReplicate = false
        Runtime.morphFormPending = false
        Runtime.morphFormPendingAt = nil
        Runtime.morphWasReplicated = true
        if IsItemEnabled("item_ethereal_blade")
            and not IsActionUsed("item_ethereal_blade")
            and not IsActionBlocked("item_ethereal_blade", ctx.now)
            and ctx.enemy
        then
            local eblade = FindItemEntry(ctx.controlled, "item_ethereal_blade")
            if eblade and SafeValue(Ability.IsCastable, eblade, ctx.mana) then
                actions[#actions + 1] = {
                    kind = "lockedEnemy",
                    ability = eblade,
                    abilityId = "item_ethereal_blade",
                    priority = 915,
                    tag = "morph_ethereal",
                }
            end
        end
        -- Stolen kit/profile is layered in BuildActionPlan while replicate is active.
        return
    end

    -- Keep Morph source while the Morph timer is still up (native ↔ stolen toggle window).
    local morphWindow = SafeValue(NPC.HasModifier, ctx.controlled, "modifier_morphling_replicate_manager") == true
    if Runtime.morphWasReplicated
        and not Runtime.morphAwaitReplicate
        and not Runtime.morphFormPending
        and not morphWindow
    then
        Runtime.morphWasReplicated = false
        Runtime.morphSourceUnitName = nil
    end

    if not ctx.enemy then
        return
    end

    local morphToggle = FindAbilityEntry(ctx.controlled, "morphling_morph_replicate")
    if morphToggle and SafeValue(Ability.IsHidden, morphToggle) == true then
        morphToggle = nil
    end
    if not morphToggle then
        for index = 0, FALLBACK_ABILITY_SLOTS - 1 do
            local ability = SafeValue(NPC.GetAbilityByIndex, ctx.controlled, index)
            if ability and SafeValue(Ability.IsHidden, ability) ~= true then
                local id = GetAbilityId(ability)
                if id == "morphling_morph_replicate" then
                    morphToggle = ability
                    break
                end
            end
        end
    end

    -- Scepter alt-cast Morph spawns an illusion; absorb via Morph Replicate to take form.
    if Runtime.morphAwaitReplicate then
        Runtime.usedActions["morphling_morph_replicate"] = nil
        Runtime.failedActions["morphling_morph_replicate"] = nil
        if morphToggle and SafeValue(Ability.IsCastable, morphToggle, ctx.mana) then
            actions[#actions + 1] = {
                kind = "noTarget",
                ability = morphToggle,
                abilityId = "morphling_morph_replicate",
                priority = 990,
                tag = "morph_absorb_replicate",
            }
        else
            local waited = Runtime.morphAwaitReplicateAt
                and (ctx.now - Runtime.morphAwaitReplicateAt) or 0
            -- Illusion dead / absorb unavailable: stop blocking the combo forever.
            if waited > 2.5 then
                DbgImportant("morph absorb timeout | waited=%.2f clear await", waited)
                Runtime.morphAwaitReplicate = false
                Runtime.morphAwaitReplicateAt = nil
            end
        end
        return
    end

    -- Direct Morph / toggle confirmed; wait for stolen-form modifier.
    if Runtime.morphFormPending then
        local pendingAge = Runtime.morphFormPendingAt
            and (ctx.now - Runtime.morphFormPendingAt) or 0
        if pendingAge > 1.5 and morphWindow then
            -- Stuck pending while already in native Morph window (manual toggle-out).
            Runtime.morphFormPending = false
            Runtime.morphFormPendingAt = nil
        else
            return
        end
    end

    -- Morph timer still active on native model: Morph Replicate toggles back into the enemy.
    -- This is not a fresh Morph cast — morphling_replicate stays on CD for the window.
    if morphWindow then
        Runtime.usedActions["morphling_morph_replicate"] = nil
        Runtime.failedActions["morphling_morph_replicate"] = nil
        if morphToggle and SafeValue(Ability.IsCastable, morphToggle, ctx.mana) then
            actions[#actions + 1] = {
                kind = "noTarget",
                ability = morphToggle,
                abilityId = "morphling_morph_replicate",
                priority = 990,
                tag = "morph_toggle_reenter",
            }
            return
        end
    end

    local hp = SafeValue(NPC.GetHealth, ctx.controlled) or 0
    local maxHp = SafeValue(NPC.GetMaxHealth, ctx.controlled) or 1
    local hpPct = maxHp > 0 and (hp / maxHp) * 100 or 100
    local agi = SafeValue(Hero.GetAgilityTotal, ctx.controlled) or 0
    local str = SafeValue(Hero.GetStrengthTotal, ctx.controlled) or 0

    -- Prefer AGI shift for Adaptive damage when not desperately low / already AGI-maxed.
    if hpPct >= 32 and agi < str * 1.5 then
        local shiftingAgi = SafeValue(NPC.HasModifier, ctx.controlled, "modifier_morphling_morph_agi") == true
        if not shiftingAgi then
            local shift, shiftId = FindFirstAbilityByIds(ctx.controlled, MORPH_AGI_SHIFT_IDS)
            if shift and IsAbilityEnabled(shiftId)
                and not IsActionUsed(shiftId)
                and not IsActionBlocked(shiftId, ctx.now)
                and SafeValue(Ability.IsCastable, shift, ctx.mana)
            then
                local toggled = SafeValue(Ability.GetToggleState, shift)
                if toggled ~= true then
                    actions[#actions + 1] = {
                        kind = "noTarget",
                        ability = shift,
                        abilityId = shiftId,
                        priority = 985,
                        tag = "morph_shift_agi",
                    }
                end
            end
        end
    elseif hpPct < 28 then
        local shiftingStr = SafeValue(NPC.HasModifier, ctx.controlled, "modifier_morphling_morph_str") == true
        if not shiftingStr then
            local shift, shiftId = FindFirstAbilityByIds(ctx.controlled, MORPH_STR_SHIFT_IDS)
            if shift and IsAbilityEnabled(shiftId)
                and not IsActionUsed(shiftId)
                and not IsActionBlocked(shiftId, ctx.now)
                and SafeValue(Ability.IsCastable, shift, ctx.mana)
            then
                local toggled = SafeValue(Ability.GetToggleState, shift)
                if toggled ~= true then
                    actions[#actions + 1] = {
                        kind = "noTarget",
                        ability = shift,
                        abilityId = shiftId,
                        priority = 985,
                        tag = "morph_shift_str",
                    }
                end
            end
        end
    end

    local waveform = FindAbilityEntry(ctx.controlled, "morphling_waveform")
    local waveformReady = waveform
        and IsAbilityEnabled("morphling_waveform")
        and not IsActionUsed("morphling_waveform")
        and not IsActionBlocked("morphling_waveform", ctx.now)
        and SafeValue(Ability.IsCastable, waveform, ctx.mana)

    -- Blink only when Waveform cannot initiate.
    if not waveformReady then
        TryAppendInitiateBlink(ctx, actions, {
            minDist = 500,
            landDist = 250,
            priority = 980,
            tag = "morphling_initiate_blink",
        })
    end

    if waveformReady then
        local land = MorphWaveformLandPos(ctx.controlled, ctx.enemy)
        actions[#actions + 1] = {
            kind = "bestPosition",
            ability = waveform,
            abilityId = "morphling_waveform",
            meta = Core.Catalog.AbilityMeta.morphling_waveform,
            allowSingle = true,
            position = land,
            positionTtl = 0.15,
            positionMaxRange = GetCastRange(ctx.controlled, waveform),
            priority = 970,
            tag = "ability_morphling_waveform",
        }
    end

    if IsItemEnabled("item_ethereal_blade")
        and not IsActionUsed("item_ethereal_blade")
        and not IsActionBlocked("item_ethereal_blade", ctx.now)
    then
        local eblade = FindItemEntry(ctx.controlled, "item_ethereal_blade")
        if eblade and SafeValue(Ability.IsCastable, eblade, ctx.mana) then
            actions[#actions + 1] = {
                kind = "lockedEnemy",
                ability = eblade,
                abilityId = "item_ethereal_blade",
                priority = 915,
                tag = "morph_ethereal",
            }
        end
    end

    -- Adaptive Strike (AGI) — STR variant no longer exists in npc_abilities.
    local strikeId = "morphling_adaptive_strike_agi"
    if IsAbilityEnabled(strikeId)
        and not IsActionBlocked(strikeId, ctx.now)
    then
        local strike = FindAbilityEntry(ctx.controlled, strikeId)
        if strike and SafeValue(Ability.IsCastable, strike, ctx.mana) then
            Runtime.usedActions[strikeId] = nil
            actions[#actions + 1] = {
                kind = "lockedEnemy",
                ability = strike,
                abilityId = strikeId,
                priority = 900,
                tag = "ability_" .. strikeId,
            }
        end
    end

    -- Morph after dump Adaptive / gap-close so stolen spells take over the bar.
    local morphUlt, morphUltId = FindFirstAbilityByIds(ctx.controlled, MORPH_ULT_IDS)
    if morphUlt and morphUltId
        and IsAbilityEnabled(morphUltId)
        and not IsActionUsed(morphUltId)
        and not IsActionBlocked(morphUltId, ctx.now)
        and SafeValue(Ability.IsCastable, morphUlt, ctx.mana)
    then
        actions[#actions + 1] = {
            kind = "lockedEnemy",
            ability = morphUlt,
            abilityId = morphUltId,
            priority = 860,
            tag = "ability_" .. morphUltId,
        }
    end
end

Core.Catalog.NevermoreUltSetup = {
    { id = "item_abyssal_blade", priority = 760 },
    { id = "item_sheepstick", priority = 755 },
}
Core.Catalog.NevermoreUltSetupIds = {
    item_abyssal_blade = true,
    item_sheepstick = true,
}
Core.Catalog.NevermoreFeastId = "nevermore_frenzy"
Core.Catalog.NevermoreFeastMod = "modifier_nevermore_frenzy"
Core.Catalog.NevermoreFeastCastTalent = "special_bonus_unique_nevermore_frenzy_castspeed"

-- L25 left: Feast of Souls +30% cast speed (needed to land Requiem under Abyssal).
Core.HasNevermoreFeastCastSpeedTalent = function(hero)
    if not hero then
        return false
    end
    local talent = SafeValue(NPC.GetAbility, hero, Core.Catalog.NevermoreFeastCastTalent)
    if talent then
        local level = SafeValue(Ability.GetLevel, talent)
        if type(level) == "number" and level > 0 then
            return true
        end
    end
    -- Ability16 on Nevermore = TALENT_7 (25 left).
    return SafeValue(Hero.TalentIsLearned, hero, Enum.TalentTypes.TALENT_7) == true
end

Core.BuildNevermorePlan = function(ctx, actions)
    if not ctx or not ctx.controlled or not ctx.enemy or not actions then
        Runtime.sfUltBurstActive = false
        Runtime.sfUltSetupId = nil
        return
    end

    local myPos = ctx.snapshot and ctx.snapshot.positions.controlled
        or SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
    if not myPos or not enemyPos then
        Runtime.sfUltBurstActive = false
        Runtime.sfUltSetupId = nil
        return
    end
    local dist = Dist2D(myPos, enemyPos)

    local blinkQueued = false
    for i = 1, #actions do
        local a = actions[i]
        if a and ((a.tag == "initiate_blink")
            or (a.abilityId and a.abilityId:find("blink", 1, true)))
        then
            blinkQueued = true
            break
        end
    end

    -- Ult burst: blink → land → (Feast?) → abyssal|hex → Requiem → refresher.
    -- Abyssal only with L25 Feast cast-speed talent; otherwise prefer hex (longer disable).
    -- Feast is post-blink only (never while blink is still queued).
    local requiemId = "nevermore_requiem"
    local requiemMaxDist = 280
    local requiemNote = "skip"
    local requiemReady = false
    local setupNote = "-"
    local feastNote = "-"
    local refreshNote = "-"
    local hasCastTalent = Core.HasNevermoreFeastCastSpeedTalent(ctx.controlled)

    if not IsAbilityEnabled(requiemId) then
        requiemNote = "disabled"
    elseif IsActionUsed(requiemId) then
        requiemNote = "used"
    elseif IsActionBlocked(requiemId, ctx.now) then
        requiemNote = "blocked"
    else
        local requiem = FindAbilityEntry(ctx.controlled, requiemId)
        if not requiem then
            requiemNote = "missing"
        elseif not SafeValue(Ability.IsCastable, requiem, ctx.mana) then
            requiemNote = "notCastable"
        else
            requiemReady = true
        end
    end

    local inUltPocket = dist <= requiemMaxDist
    local waitingBlink = blinkQueued and not inUltPocket
    local ultSoon = requiemReady and (inUltPocket or blinkQueued)
    Runtime.sfUltBurstActive = ultSoon == true
    Runtime.sfUltSetupId = nil

    -- While blink is still in flight, queue ONLY blink. Setup/Feast/Requiem must
    -- replan after land — otherwise the stale [abyssal, requiem] queue skips Feast.
    if waitingBlink then
        setupNote = "defer:postBlink"
        feastNote = "defer:postBlink"
        if requiemReady then
            requiemNote = "defer:postBlink"
        end
    elseif ultSoon then
        -- With talent: abyssal first. Without: hex first (abyssal window is too tight).
        local setups = hasCastTalent
            and Core.Catalog.NevermoreUltSetup
            or {
                Core.Catalog.NevermoreUltSetup[2],
                Core.Catalog.NevermoreUltSetup[1],
            }
        for si = 1, #setups do
            local setup = setups[si]
            local setupId = setup.id
            if setupId == "item_abyssal_blade" and not hasCastTalent then
                goto continue_sf_setup
            end
            if IsItemEnabled(setupId)
                and not IsActionUsed(setupId)
                and not IsActionBlocked(setupId, ctx.now)
            then
                local item = FindItemEntry(ctx.controlled, setupId)
                if item
                    and SafeValue(Ability.IsCastable, item, ctx.mana)
                    and ShouldCastDisable(ctx, ctx.enemy, setupId, item)
                then
                    Runtime.sfUltSetupId = setupId
                    actions[#actions + 1] = {
                        kind = "lockedEnemy",
                        ability = item,
                        abilityId = setupId,
                        priority = setup.priority,
                        tag = "sf_ult_setup_" .. setupId,
                    }
                    setupNote = string.format("%s@%d", setupId, setup.priority)

                    -- Feast only with L25 cast-speed talent, post-blink / in pocket,
                    -- immediately before Abyssal→Requiem.
                    if setupId == "item_abyssal_blade" and hasCastTalent then
                        local feastId = Core.Catalog.NevermoreFeastId
                        local feastMod = Core.Catalog.NevermoreFeastMod
                        if SafeValue(NPC.HasModifier, ctx.controlled, feastMod) == true then
                            feastNote = "active"
                        elseif IsActionUsed(feastId) or IsActionBlocked(feastId, ctx.now) then
                            feastNote = "used"
                        else
                            local feast = FindAbilityEntry(ctx.controlled, feastId)
                            if not feast then
                                feastNote = "missing"
                            elseif not SafeValue(Ability.IsCastable, feast, ctx.mana) then
                                feastNote = "notCastable"
                            else
                                actions[#actions + 1] = {
                                    kind = "noTarget",
                                    ability = feast,
                                    abilityId = feastId,
                                    priority = 770,
                                    tag = "sf_ult_feast",
                                }
                                feastNote = "queue@770"
                            end
                        end
                    end
                    break
                end
            end
            ::continue_sf_setup::
        end
        if setupNote == "-" then
            setupNote = "noneReady"
        end
    end

    -- Queue Requiem only when already in pocket (after blink or walk-in).
    if requiemReady and not waitingBlink then
        if not inUltPocket then
            requiemNote = string.format("tooFar dist=%.0f>%.0f", dist, requiemMaxDist)
        else
            local requiem = FindAbilityEntry(ctx.controlled, requiemId)
            if requiem then
                actions[#actions + 1] = {
                    kind = "noTarget",
                    ability = requiem,
                    abilityId = requiemId,
                    priority = 745,
                    tag = "ability_" .. requiemId,
                }
                requiemNote = "queue@745"
            end
        end
    end

    -- After Requiem: refresh immediately so blink/hex/ult can chain again.
    if IsActionUsed(requiemId)
        and IsItemEnabled("item_refresher")
        and not IsActionUsed("item_refresher")
        and not IsActionBlocked("item_refresher", ctx.now)
    then
        local refresher = FindItemEntry(ctx.controlled, "item_refresher")
        if refresher and SafeValue(Ability.IsCastable, refresher, ctx.mana) then
            actions[#actions + 1] = {
                kind = "noTarget",
                ability = refresher,
                abilityId = "item_refresher",
                priority = 700,
                tag = "item_refresher_sf_ult_chain",
            }
            refreshNote = "queue@700"
        else
            refreshNote = "notCastable"
        end
    end

    local pick = Core.PickBestShadowraze(dist)
    local razeNote = "noneInBand"
    local queuedRaze = false
    local holdRazes = ultSoon or refreshNote:find("queue", 1, true)
    if blinkQueued then
        razeNote = "defer:blinkQueued"
    elseif holdRazes then
        razeNote = ultSoon and "defer:ultBurst" or "defer:refresh"
    elseif not pick then
        DbgVerbose("sf_plan",
            "sf_plan | dist=%.0f requiem=%s setup=%s feast=%s talent=%s refresh=%s raze=%s | %s",
            dist, requiemNote, setupNote, feastNote, tostring(hasCastTalent),
            refreshNote, razeNote, FormatRangeContext(ctx))
        return
    elseif not IsAbilityEnabled(pick.id) then
        razeNote = pick.id .. ":disabled"
    elseif IsActionUsed(pick.id) then
        razeNote = pick.id .. ":used"
    elseif IsActionBlocked(pick.id, ctx.now) then
        razeNote = pick.id .. ":blocked"
    else
        local raze = FindAbilityEntry(ctx.controlled, pick.id)
        if not raze then
            razeNote = pick.id .. ":missing"
        elseif not SafeValue(Ability.IsCastable, raze, ctx.mana) then
            razeNote = pick.id .. ":notCastable"
        else
            actions[#actions + 1] = {
                kind = "noTarget",
                ability = raze,
                abilityId = pick.id,
                razeRange = pick.range,
                targetPolicy = "lockedEnemy",
                priority = 690,
                tag = "kit_" .. pick.id,
            }
            razeNote = string.format("%s:queue@690 want=%.0f", pick.id, pick.range)
            queuedRaze = true
        end
    end

    local msg = string.format(
        "sf_plan | dist=%.0f requiem=%s setup=%s feast=%s talent=%s refresh=%s raze=%s | %s",
        dist, requiemNote, setupNote, feastNote, tostring(hasCastTalent),
        refreshNote, razeNote, FormatRangeContext(ctx)
    )
    if requiemNote:find("queue", 1, true)
        or setupNote:find("@", 1, true)
        or feastNote:find("queue", 1, true)
        or refreshNote:find("queue", 1, true)
        or queuedRaze
    then
        Core.DbgEvent("%s", msg)
    else
        DbgVerbose("sf_plan", "%s", msg)
    end
end

local function BuildSupportSelfPlan(ctx, actions)
    for _, id in ipairs(Core.Catalog.SupportSelfAbilities) do
        if IsAbilityEnabled(id) then
            local ability = FindAbilityEntry(ctx.controlled, id)
            if ability and SafeValue(Ability.IsCastable, ability, ctx.mana) then
                local policy = ClassifyAbilityPolicy(ability, id)
                local shouldUse = LocalHeroNeedsHelp(ctx.localHero)
                if Core.Catalog.OwnerTriggeredAbilities[id] then
                    shouldUse = LocalHeroNeedsHelp(ctx.controlled)
                end
                if shouldUse then
                    actions[#actions + 1] = {
                        kind = policy == "noTarget" and "noTarget" or "localHero",
                        ability = ability,
                        abilityId = id,
                        priority = 980 - (#actions),
                        tag = "support_" .. id,
                    }
                end
            end
        end
    end
end

local function AppendKitAbility(ctx, actions, step)
    if not step then
        return
    end
    local builder = step.builder
    if builder == "supportSelf" then
        BuildSupportSelfPlan(ctx, actions)
        return
    end

    local abilityId = step.id
    if not abilityId then
        return
    end
    if builder == "aoeUlt" then
        BuildGenericAoeUltPlan(ctx, actions, abilityId)
        return
    end
    if builder == "channeledDisable" then
        BuildChanneledDisablePlan(ctx, actions, abilityId)
        return
    end

    if not IsAbilityEnabled(abilityId) or IsActionUsed(abilityId)
        or IsActionBlocked(abilityId, ctx.now) then
        return
    end
    local ability = FindAbilityEntry(ctx.controlled, abilityId)
    if not ability or not SafeValue(Ability.IsCastable, ability, ctx.mana) then
        return
    end

    local priority = type(step.priority) == "number" and step.priority or 700
    local meta = Core.Catalog.AbilityMeta[abilityId]
    if builder == "lockedEnemy" then
        if not ctx.enemy then
            return
        end
        if (Core.Catalog.DisableModifiers[abilityId] or Core.Catalog.HexAbilities[abilityId])
            and not ShouldCastDisable(ctx, ctx.enemy, abilityId, ability) then
            return
        end
        actions[#actions + 1] = {
            kind = "lockedEnemy",
            ability = ability,
            abilityId = abilityId,
            priority = priority,
            tag = "kit_" .. abilityId,
        }
    elseif builder == "noTarget" then
        -- Live POINT/UNIT overrides static NO_TARGET (Enchant Totem: CAST_NO_TARGET never
        -- executes while liveBeh has POINT). Prefer CAST_POSITION when POINT is set.
        local liveBeh = GetAbilityBehaviorFlags(ability)
        local hasPoint = HasAbilityBehaviorFlag(liveBeh, BEH.DOTA_ABILITY_BEHAVIOR_POINT)
        local hasUnit = HasAbilityBehaviorFlag(liveBeh, BEH.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
        local liveNoTarget = HasAbilityBehaviorFlag(liveBeh, BEH.DOTA_ABILITY_BEHAVIOR_NO_TARGET)
        if hasPoint and not liveNoTarget then
            if not ctx.enemy then
                return
            end
            actions[#actions + 1] = {
                kind = "bestPosition",
                ability = ability,
                abilityId = abilityId,
                meta = meta or { point = true, allowSingle = true },
                allowSingle = true,
                priority = priority,
                tag = "kit_" .. abilityId,
            }
            return
        end
        if hasUnit and not liveNoTarget and not hasPoint then
            if not ctx.enemy then
                return
            end
            actions[#actions + 1] = {
                kind = "lockedEnemy",
                ability = ability,
                abilityId = abilityId,
                priority = priority,
                tag = "kit_" .. abilityId,
            }
            return
        end
        actions[#actions + 1] = {
            kind = "noTarget",
            ability = ability,
            abilityId = abilityId,
            priority = priority,
            tag = "kit_" .. abilityId,
        }
    elseif builder == "bestPosition" then
        if not ctx.enemy then
            return
        end
        actions[#actions + 1] = {
            kind = "bestPosition",
            ability = ability,
            abilityId = abilityId,
            meta = meta,
            allowSingle = true,
            priority = priority,
            tag = "kit_" .. abilityId,
        }
    end
end

local function ApplyHeroKit(ctx, actions, kit)
    if not kit or not ctx or not actions then
        return
    end
    if kit.initiate and kit.initiate.blink then
        TryAppendInitiateBlink(ctx, actions, kit.initiate)
    end
    local steps = kit.steps
    if type(steps) ~= "table" then
        return
    end
    for i = 1, #steps do
        AppendKitAbility(ctx, actions, steps[i])
    end
end

-- Declarative combo recipes for simple/medium heroes (see ApplyHeroKit).
Core.Catalog.HeroKits = {
    npc_dota_hero_axe = {
        initiate = { blink = true, landDist = 120, minDist = 400, priority = 980 },
        steps = {
            { id = "axe_berserkers_call", builder = "aoeUlt" },
            { id = "axe_battle_hunger", builder = "lockedEnemy", priority = 700 },
        },
    },
    npc_dota_hero_tidehunter = {
        initiate = { blink = true, landDist = 200, minDist = 500, priority = 980 },
        steps = {
            { id = "tidehunter_ravage", builder = "aoeUlt" },
            { id = "tidehunter_gush", builder = "lockedEnemy", priority = 720 },
        },
    },
    npc_dota_hero_magnataur = {
        initiate = { blink = true, landDist = 150, minDist = 450, priority = 980 },
        steps = {
            { id = "magnataur_reverse_polarity", builder = "aoeUlt" },
            { id = "magnataur_skewer", builder = "bestPosition", priority = 780 },
            { id = "magnataur_shockwave", builder = "bestPosition", priority = 700 },
        },
    },
    npc_dota_hero_earthshaker = {
        initiate = { blink = true, landDist = 180, minDist = 450, priority = 980 },
        steps = {
            { id = "earthshaker_echo_slam", builder = "aoeUlt" },
            { id = "earthshaker_fissure", builder = "aoeUlt" },
            { id = "earthshaker_enchant_totem", builder = "bestPosition", priority = 720 },
        },
    },
    npc_dota_hero_enigma = {
        initiate = { blink = true, landDist = 200, minDist = 500, priority = 980 },
        steps = {
            { id = "enigma_black_hole", builder = "aoeUlt" },
            { id = "enigma_malefice", builder = "lockedEnemy", priority = 760 },
        },
    },
    npc_dota_hero_faceless_void = {
        initiate = { blink = true, landDist = 200, minDist = 500, priority = 980 },
        steps = {
            -- Time Walk first (860) then Chronosphere (840) when both ready.
            { id = "faceless_void_time_walk", builder = "bestPosition", priority = 860 },
            { id = "faceless_void_chronosphere", builder = "aoeUlt" },
        },
    },
    npc_dota_hero_centaur = {
        initiate = { blink = true, landDist = 120, minDist = 400, priority = 980 },
        steps = {
            { id = "centaur_hoof_stomp", builder = "aoeUlt" },
            { id = "centaur_double_edge", builder = "lockedEnemy", priority = 740 },
        },
    },
    npc_dota_hero_sand_king = {
        initiate = { blink = true, landDist = 180, minDist = 450, priority = 980 },
        steps = {
            { id = "sandking_burrowstrike", builder = "bestPosition", priority = 900 },
            { id = "sandking_epicenter", builder = "aoeUlt" },
            { id = "sandking_sand_storm", builder = "noTarget", priority = 720 },
        },
    },
    npc_dota_hero_slardar = {
        initiate = { blink = true, landDist = 120, minDist = 400, priority = 980 },
        steps = {
            { id = "slardar_slithereen_crush", builder = "aoeUlt" },
            { id = "slardar_sprint", builder = "noTarget", priority = 860 },
            { id = "slardar_amplify_damage", builder = "lockedEnemy", priority = 700 },
        },
    },
    npc_dota_hero_rattletrap = {
        initiate = { blink = true, landDist = 150, minDist = 500, priority = 980 },
        steps = {
            { id = "rattletrap_hookshot", builder = "bestPosition", priority = 900 },
            { id = "rattletrap_battery_assault", builder = "aoeUlt" },
            { id = "rattletrap_power_cogs", builder = "noTarget", priority = 760 },
        },
    },
    npc_dota_hero_mars = {
        initiate = { blink = true, landDist = 200, minDist = 450, priority = 980 },
        steps = {
            { id = "mars_spear", builder = "bestPosition", priority = 880 },
            { id = "mars_arena_of_blood", builder = "aoeUlt" },
            { id = "mars_gods_rebuke", builder = "bestPosition", priority = 740 },
        },
    },
    npc_dota_hero_legion_commander = {
        initiate = { blink = true, landDist = 100, minDist = 350, priority = 980 },
        steps = {
            { id = "legion_commander_press_the_attack", builder = "noTarget", priority = 860 },
            { id = "legion_commander_duel", builder = "channeledDisable" },
            { id = "legion_commander_overwhelming_odds", builder = "bestPosition", priority = 720 },
        },
    },
    npc_dota_hero_batrider = {
        initiate = { blink = true, landDist = 120, minDist = 400, priority = 980 },
        steps = {
            { id = "batrider_flaming_lasso", builder = "channeledDisable" },
            { id = "batrider_firefly", builder = "noTarget", priority = 860 },
            { id = "batrider_sticky_napalm", builder = "bestPosition", priority = 720 },
        },
    },
    npc_dota_hero_beastmaster = {
        initiate = { blink = true, landDist = 140, minDist = 400, priority = 980 },
        steps = {
            { id = "beastmaster_primal_roar", builder = "channeledDisable" },
            { id = "beastmaster_wild_axes", builder = "bestPosition", priority = 740 },
        },
    },
    npc_dota_hero_lion = {
        initiate = { blink = true, landDist = 140, minDist = 500, priority = 980 },
        steps = {
            { id = "lion_voodoo", builder = "lockedEnemy", priority = 930 },
            { id = "lion_impale", builder = "bestPosition", priority = 780 },
            { id = "lion_finger_of_death", builder = "lockedEnemy", priority = 700 },
        },
    },
    npc_dota_hero_shadow_shaman = {
        initiate = { blink = true, landDist = 140, minDist = 500, priority = 980 },
        steps = {
            { id = "shadow_shaman_voodoo", builder = "lockedEnemy", priority = 930 },
            { id = "shadow_shaman_shackles", builder = "channeledDisable" },
            { id = "shadow_shaman_mass_serpent_ward", builder = "aoeUlt" },
        },
    },
    npc_dota_hero_bane = {
        initiate = { blink = true, landDist = 120, minDist = 450, priority = 980 },
        steps = {
            { id = "bane_fiends_grip", builder = "channeledDisable" },
            { id = "bane_nightmare", builder = "channeledDisable" },
            { id = "bane_brain_sap", builder = "lockedEnemy", priority = 740 },
        },
    },
    npc_dota_hero_crystal_maiden = {
        initiate = { blink = true, landDist = 200, minDist = 500, priority = 980 },
        steps = {
            { id = "crystal_maiden_frostbite", builder = "lockedEnemy", priority = 860 },
            { id = "crystal_maiden_freezing_field", builder = "aoeUlt" },
            { id = "crystal_maiden_crystal_nova", builder = "bestPosition", priority = 720 },
        },
    },
    npc_dota_hero_witch_doctor = {
        initiate = { blink = true, landDist = 180, minDist = 450, priority = 980 },
        steps = {
            { builder = "supportSelf" },
            { id = "witch_doctor_paralyzing_cask", builder = "lockedEnemy", priority = 860 },
            { id = "witch_doctor_maledict", builder = "bestPosition", priority = 780 },
            { id = "witch_doctor_death_ward", builder = "aoeUlt" },
        },
    },
    npc_dota_hero_lich = {
        initiate = { blink = true, landDist = 160, minDist = 500, priority = 980 },
        steps = {
            { id = "lich_sinister_gaze", builder = "channeledDisable" },
            { id = "lich_chain_frost", builder = "lockedEnemy", priority = 840 },
            { id = "lich_frost_nova", builder = "bestPosition", priority = 720 },
        },
    },
    npc_dota_hero_warlock = {
        initiate = { blink = true, landDist = 200, minDist = 500, priority = 980 },
        steps = {
            { id = "warlock_fatal_bonds", builder = "lockedEnemy", priority = 860 },
            { id = "warlock_shadow_word", builder = "lockedEnemy", priority = 780 },
            { id = "warlock_rain_of_chaos", builder = "aoeUlt" },
        },
    },
    npc_dota_hero_nyx_assassin = {
        initiate = { blink = true, landDist = 140, minDist = 450, priority = 980 },
        steps = {
            { id = "nyx_assassin_impale", builder = "bestPosition", priority = 880 },
            { id = "nyx_assassin_mana_burn", builder = "lockedEnemy", priority = 760 },
            { id = "nyx_assassin_vendetta", builder = "noTarget", priority = 900 },
        },
    },
    npc_dota_hero_skywrath_mage = {
        initiate = { blink = true, landDist = 160, minDist = 500, priority = 980 },
        steps = {
            { id = "skywrath_mage_ancient_seal", builder = "lockedEnemy", priority = 900 },
            { id = "skywrath_mage_mystic_flare", builder = "bestPosition", priority = 840 },
            { id = "skywrath_mage_arcane_bolt", builder = "lockedEnemy", priority = 720 },
        },
    },
    npc_dota_hero_jakiro = {
        initiate = { blink = true, landDist = 180, minDist = 450, priority = 980 },
        steps = {
            { id = "jakiro_ice_path", builder = "bestPosition", priority = 880 },
            { id = "jakiro_macropyre", builder = "aoeUlt" },
            { id = "jakiro_dual_breath", builder = "bestPosition", priority = 720 },
        },
    },
    npc_dota_hero_lina = {
        initiate = { blink = true, landDist = 160, minDist = 500, priority = 980 },
        steps = {
            { id = "lina_light_strike_array", builder = "aoeUlt" },
            { id = "lina_dragon_slave", builder = "bestPosition", priority = 780 },
            { id = "lina_laguna_blade", builder = "lockedEnemy", priority = 850 },
        },
    },
    npc_dota_hero_nevermore = {
        -- Blink whenever outside Requiem pocket so combo is blink → items → ult.
        initiate = { blink = true, landDist = 200, minDist = 320, priority = 980 },
        -- Razes + Requiem are owned by BuildNevermorePlan (face/align + ult timing).
        steps = {},
    },
    npc_dota_hero_ogre_magi = {
        initiate = { blink = true, landDist = 120, minDist = 400, priority = 980 },
        steps = {
            { builder = "supportSelf" },
            { id = "ogre_magi_fireblast", builder = "lockedEnemy", priority = 880 },
            { id = "ogre_magi_ignite", builder = "lockedEnemy", priority = 760 },
        },
    },
    npc_dota_hero_oracle = {
        steps = {
            { builder = "supportSelf" },
            { id = "oracle_fortunes_end", builder = "lockedEnemy", priority = 780 },
        },
    },
    npc_dota_hero_dazzle = {
        steps = {
            { builder = "supportSelf" },
            { id = "dazzle_poison_touch", builder = "lockedEnemy", priority = 760 },
        },
    },
    npc_dota_hero_abaddon = {
        steps = {
            { builder = "supportSelf" },
            { id = "abaddon_death_coil", builder = "lockedEnemy", priority = 760 },
        },
    },
}

Core.Catalog.HeroProfiles = {
    -- Custom / heavy logic only; simple heroes live in HeroKits.
    npc_dota_hero_primal_beast = BuildPrimalBeastPlan,
    npc_dota_hero_morphling = BuildMorphlingPlan,
    npc_dota_hero_nevermore = Core.BuildNevermorePlan,
    npc_dota_hero_treant = BuildSupportSelfPlan,
    npc_dota_hero_omniknight = BuildSupportSelfPlan,
    npc_dota_hero_chen = BuildSupportSelfPlan,
    npc_dota_hero_shadow_demon = BuildSupportSelfPlan,
    npc_dota_hero_wisp = BuildSupportSelfPlan,
    npc_dota_hero_invoker = function(ctx, actions)
        if not ctx.enemy then
            return
        end
        if Runtime.invokerAwaitSpell and not IsAbilityEnabled(Runtime.invokerAwaitSpell) then
            Runtime.invokerAwaitSpell = nil
        end
        for si = 1, #Core.Catalog.InvokerSteps do
            local preStep = Core.Catalog.InvokerSteps[si]
            if not IsAbilityEnabled(preStep.id) then
                -- skip disabled combo steps
            elseif preStep.id == "invoker_alacrity" and ctx.localHero
                and SafeValue(NPC.HasModifier, ctx.localHero, "modifier_invoker_alacrity") then
                MarkActionUsed(preStep.id)
            elseif preStep.skipMods and ctx.enemy and HasAnyModifier(ctx.enemy, preStep.skipMods) then
                MarkActionUsed(preStep.id)
            end
        end
        if ctx.now - (Runtime.invokerLastInvokeAt or 0) < INVOKER_INVOKE_SETTLE
            and not Runtime.invokerAwaitSpell then
            return
        end
        if Runtime.invokerComboEnemy ~= ctx.enemy then
            Runtime.invokerComboEnemy = ctx.enemy
            Runtime.invokerLastInvokeAt = 0
            Runtime.invokerAwaitSpell = nil
            for si = 1, #Core.Catalog.InvokerSteps do
                Runtime.usedActions[Core.Catalog.InvokerSteps[si].id] = nil
            end
        end
        local quas = FindAbilityEntry(ctx.controlled, "invoker_quas")
        local wex = FindAbilityEntry(ctx.controlled, "invoker_wex")
        local exort = FindAbilityEntry(ctx.controlled, "invoker_exort")
        local invoke = FindAbilityEntry(ctx.controlled, "invoker_invoke")
        local etherealId = Core.Catalog.InvokerEndItemRoles.ethereal.id
        local hexId = Core.Catalog.InvokerEndItemRoles.hex.id
        local supportItemId = Core.Catalog.InvokerEndItemRoles.support.id
        if not quas or not wex or not exort or not invoke then
            return
        end
        if IsActionUsed("invoker_cold_snap") and not IsActionUsed(etherealId)
            and IsItemEnabled(etherealId) and ctx.enemy
            and not IsActionBlocked(etherealId, ctx.now) then
            local ethItem = FindItemEntry(ctx.controlled, etherealId)
            if ethItem and SafeValue(Ability.IsCastable, ethItem, ctx.mana) then
                local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
                local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
                local ethRange = GetCastRange(ctx.controlled, ethItem)
                if myPos and enemyPos and IsWithinRange2D(myPos, enemyPos, ethRange) then
                    actions[#actions + 1] = {
                        kind = "lockedEnemy",
                        ability = ethItem,
                        abilityId = etherealId,
                        priority = 958,
                        tag = "link_" .. etherealId,
                    }
                    return
                end
            end
        end
        if Runtime.invokerAwaitSpell then
            local awaitId = Runtime.invokerAwaitSpell
            local awaitStep
            for ai = 1, #Core.Catalog.InvokerSteps do
                if Core.Catalog.InvokerSteps[ai].id == awaitId then
                    awaitStep = Core.Catalog.InvokerSteps[ai]
                    break
                end
            end
            if not awaitStep then
                Runtime.invokerAwaitSpell = nil
            else
                local awaitKind = awaitStep.kind
                if awaitStep.linkBreak and ctx.enemy and TargetNeedsLinkBreak(ctx.enemy) then
                    awaitKind = "linkbreak"
                end
                local awaitSpell = FindInvokerBarSpell(ctx.controlled, awaitId)
                local invokeAge = Runtime.invokerLastInvokeAt > 0
                    and (ctx.now - Runtime.invokerLastInvokeAt) or math.huge
                if awaitSpell and GetAbilityId(awaitSpell) == awaitId then
                    if invokeAge >= INVOKER_INVOKE_SETTLE then
                        if awaitKind == "auto" then
                            local classified = ClassifyAbilityPolicy(awaitSpell, awaitId)
                            if not classified then
                                MarkActionUsed(awaitId)
                                Runtime.invokerAwaitSpell = nil
                                return
                            end
                            awaitKind = classified
                        end
                        if awaitId == "invoker_ice_wall" and awaitKind == "noTarget" then
                            awaitKind = "iceWall"
                        end
                        if SafeValue(Ability.CanBeExecuted, awaitSpell) == ABILITY_CAST_READY
                            or SafeValue(Ability.IsCastable, awaitSpell, ctx.mana) then
                            actions[#actions + 1] = {
                                kind = awaitKind,
                                ability = awaitSpell,
                                abilityId = awaitId,
                                priority = 960,
                                tag = awaitStep.tag,
                                meta = Core.Catalog.AbilityMeta[awaitId],
                                allowSingle = true,
                            }
                            return
                        end
                        DbgImportant("invoker skip | %s not castable", awaitId)
                        MarkActionUsed(awaitId)
                        Runtime.invokerAwaitSpell = nil
                    end
                    return
                end
                if invokeAge < INVOKER_SLOT_WAIT then
                    return
                end
                Runtime.invokerAwaitSpell = nil
            end
        end
        for i = 1, #Core.Catalog.InvokerSteps do
            local step = Core.Catalog.InvokerSteps[i]
            if not IsAbilityEnabled(step.id) then
                goto invoker_continue_step
            end
            if not IsActionUsed(step.id) and not IsActionBlocked(step.id, ctx.now) then
                if step.skipMods and HasAnyModifier(ctx.enemy, step.skipMods) then
                    MarkActionUsed(step.id)
                    goto invoker_continue_step
                end
                if step.kind == "localHero" and not ctx.localHero then
                    MarkActionUsed(step.id)
                    goto invoker_continue_step
                end
                local kind = step.kind
                if step.linkBreak and ctx.enemy and TargetNeedsLinkBreak(ctx.enemy) then
                    kind = "linkbreak"
                end
                local spell = FindInvokerBarSpell(ctx.controlled, step.id)
                if spell and GetAbilityId(spell) == step.id then
                    if kind == "auto" then
                        local classified = ClassifyAbilityPolicy(spell, step.id)
                        if not classified then
                            MarkActionUsed(step.id)
                            goto invoker_continue_step
                        end
                        kind = classified
                    end
                    if step.id == "invoker_ice_wall" and kind == "noTarget" then
                        kind = "iceWall"
                    end
                    if SafeValue(Ability.CanBeExecuted, spell) == ABILITY_CAST_READY
                        or SafeValue(Ability.IsCastable, spell, ctx.mana) then
                        actions[#actions + 1] = {
                            kind = kind,
                            ability = spell,
                            abilityId = step.id,
                            priority = 960,
                            tag = step.tag,
                            meta = Core.Catalog.AbilityMeta[step.id],
                            allowSingle = true,
                        }
                        return
                    end
                    DbgImportant("invoker skip | %s not castable", step.id)
                    MarkActionUsed(step.id)
                    goto invoker_continue_step
                end
                if Runtime.invokerAwaitSpell == step.id then
                    return
                end
                Runtime.invokerAwaitSpell = step.id
                local band = 960
                local seq = 0
                local orbPlan = {
                    { orb = wex, id = "invoker_wex", count = step.w or 0 },
                    { orb = quas, id = "invoker_quas", count = step.q or 0 },
                    { orb = exort, id = "invoker_exort", count = step.e or 0 },
                }
                for oi = 1, #orbPlan do
                    local entry = orbPlan[oi]
                    for _ = 1, entry.count do
                        seq = seq + 1
                        actions[#actions + 1] = {
                            kind = "noTarget",
                            ability = entry.orb,
                            abilityId = entry.id,
                            priority = band,
                            tag = "invoker_orb_" .. entry.id .. "_" .. seq,
                        }
                        band = band - 1
                    end
                end
                actions[#actions + 1] = {
                    kind = "noTarget",
                    ability = invoke,
                    abilityId = "invoker_invoke",
                    priority = band,
                    tag = "ability_invoker_invoke",
                }
                return
            end
            ::invoker_continue_step::
        end
        if ctx.enemy and IsItemEnabled(hexId) and not IsActionUsed(hexId)
            and not IsActionBlocked(hexId, ctx.now) then
            local hex = FindItemEntry(ctx.controlled, hexId)
            if hex and SafeValue(Ability.IsCastable, hex, ctx.mana) then
                local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
                local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
                local hexRange = GetCastRange(ctx.controlled, hex)
                if myPos and enemyPos and IsWithinRange2D(myPos, enemyPos, hexRange)
                    and ShouldCastDisable(ctx, ctx.enemy, hexId, hex) then
                    actions[#actions + 1] = {
                        kind = "lockedEnemy",
                        ability = hex,
                        abilityId = hexId,
                        priority = 956,
                        tag = hexId,
                    }
                    return
                end
            end
        end
        if ctx.localHero and IsItemEnabled(supportItemId) and not IsActionUsed(supportItemId)
            and not IsActionBlocked(supportItemId, ctx.now) then
            local lotus = FindItemEntry(ctx.controlled, supportItemId)
            if lotus and SafeValue(Ability.IsCastable, lotus, ctx.mana) then
                local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
                local allyPos = SafeValue(Entity.GetAbsOrigin, ctx.localHero)
                local lotusRange = GetCastRange(ctx.controlled, lotus)
                if myPos and allyPos and IsWithinRange2D(myPos, allyPos, lotusRange) then
                    actions[#actions + 1] = {
                        kind = "localHero",
                        ability = lotus,
                        abilityId = supportItemId,
                        priority = 955,
                        tag = ActionTag("self.", supportItemId),
                    }
                    return
                end
            end
        end
    end,
}
Core.InvokerController.Build = Core.Catalog.HeroProfiles.npc_dota_hero_invoker

--#endregion

--#region Action planning

local function AppendGenericActions(ctx, actions)
    local function canCastOnEnemyNow(ability, kind)
        -- Range is enforced at execute/approach time. Filtering here dropped short-range
        -- disables (Lion Hex) from the plan while longer skills were still queued.
        if not ability then
            return false
        end
        if kind == "localHero" then
            return ctx.localHero ~= nil
        end
        if kind == "noTarget" then
            return true
        end
        return ctx.enemy ~= nil
    end

    for _, entry in ipairs(ctx.snapshot and ctx.snapshot.items or CollectHeroItems(ctx.controlled)) do
        if IsItemEnabled(entry.id) and Core.Catalog.SelfNoTargetItems[entry.id] then
            if IsActionBlocked(entry.id, ctx.now) or IsActionUsed(entry.id) then
                goto continue_team_item
            end
            if SafeValue(Ability.IsCastable, entry.item, ctx.mana) then
                actions[#actions + 1] = {
                    kind = "noTarget",
                    ability = entry.item,
                    abilityId = entry.id,
                    priority = 925,
                    tag = ActionTag("team.", entry.id),
                }
            end
        end
        ::continue_team_item::
    end

    for _, entry in ipairs(ctx.snapshot and ctx.snapshot.items or CollectHeroItems(ctx.controlled)) do
        if entry.id ~= "item_refresher"
            and IsItemEnabled(entry.id) and not ShouldSkipComboItem(entry.id) then
            if Core.Catalog.SelfNoTargetItems[entry.id] then
                goto continue_self_item
            end
            if IsActionBlocked(entry.id, ctx.now) or IsActionUsed(entry.id) then
                goto continue_self_item
            end
            local policy = ClassifyItemPolicy(entry.item, entry.id)
            local shouldUse = policy == "localHero" and LocalHeroNeedsHelp(ctx.localHero)
                or (policy == "noTarget" and Core.Catalog.SelfItems[entry.id]
                    and LocalHeroNeedsHelp(ctx.controlled))
            if shouldUse and SafeValue(Ability.IsCastable, entry.item, ctx.mana) then
                actions[#actions + 1] = {
                    kind = policy,
                    ability = entry.item,
                    abilityId = entry.id,
                    priority = 960,
                    tag = ActionTag("self.", entry.id),
                }
            end
        end
        ::continue_self_item::
    end

    for _, entry in ipairs(ctx.snapshot and ctx.snapshot.abilities or CollectHeroAbilities(ctx.controlled)) do
        if SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_invoker" then
            goto continue_ability
        end
        -- Morphling kit/profile owns Waveform / Adaptive / Attribute Shift.
        if SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_morphling"
            and entry.id
            and entry.id:find("morphling_", 1, true)
        then
            goto continue_ability
        end
        -- Nevermore profile owns razes + Requiem + Feast (Feast only in ult burst with L25 talent).
        if SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_nevermore"
            and entry.id
            and (entry.id:find("nevermore_shadowraze", 1, true)
                or entry.id == "nevermore_requiem"
                or entry.id == Core.Catalog.NevermoreFeastId)
        then
            goto continue_ability
        end
        if IsAbilityEnabled(entry.id) and SafeValue(Ability.IsCastable, entry.ability, ctx.mana) then
            if IsActionBlocked(entry.id, ctx.now) then
                goto continue_ability
            end
            if IsActionUsed(entry.id) then
                goto continue_ability
            end
            -- Defer Pulverize while Trample is active (orbit first, ult after).
            if entry.id == "primal_beast_pulverize"
                and IsPrimalBeastTrampling(ctx.controlled) then
                goto continue_ability
            end
            local policy, meta = ClassifyAbilityPolicy(entry.ability, entry.id)
            if not policy then
                goto continue_ability
            end
            local behavior = SafeValue(Ability.GetBehavior, entry.ability, true)
                or SafeValue(Ability.GetBehavior, entry.ability, false) or 0
            if policy == "noTarget"
                and HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_TOGGLE)
                and SafeValue(Ability.GetToggleState, entry.ability) == true then
                MarkActionUsed(entry.id)
                goto continue_ability
            end
            local priority = Core.Catalog.PriorityOverrides[entry.id] or 700
            if not Core.Catalog.PriorityOverrides[entry.id] then
                if policy == "localHero" then
                    priority = LocalHeroNeedsHelp(ctx.localHero) and 940 or 300
                elseif policy == "bestPosition" then
                    priority = SafeValue(Ability.IsUltimate, entry.ability) and 820 or 650
                elseif policy == "noTarget" then
                    priority = SafeValue(Ability.IsUltimate, entry.ability) and 830 or 640
                elseif Core.Catalog.DisableModifiers[entry.id] then
                    priority = 760
                end
            end

            if policy == "localHero" and not LocalHeroNeedsHelp(ctx.localHero)
                and Core.Catalog.FriendlyOnlyAbilities[entry.id] then
                goto continue_ability
            end

            if policy == "noTarget" and Runtime.comboActive and not ctx.enemy then
                goto continue_ability
            end

            -- Pointless no-target AOE (Call, Stomp, …) outside radius — wait / blink instead.
            if policy == "noTarget" and meta and meta.noTarget and ctx.enemy then
                local aoeRadius = GetAoeRadius(entry.ability, entry.id, meta)
                if aoeRadius and aoeRadius > 0 then
                    local myPos = ctx.snapshot and ctx.snapshot.positions.controlled
                        or SafeValue(Entity.GetAbsOrigin, ctx.controlled)
                    local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
                    if myPos and enemyPos and Dist2D(myPos, enemyPos) > aoeRadius then
                        goto continue_ability
                    end
                end
            end

            if policy == "lockedEnemy" or policy == "bestPosition" then
                if not ctx.enemy then
                    goto continue_ability
                end
                if entry.id == "sniper_shrapnel" then
                    local shMeta = meta or Core.Catalog.AbilityMeta.sniper_shrapnel
                    if shMeta and shMeta.debuffMods and HasAnyModifier(ctx.enemy, shMeta.debuffMods) then
                        goto continue_ability
                    end
                    if Runtime.shrapnelLastEnemy == ctx.enemy and Runtime.shrapnelLastCastAt then
                        local elapsed = ctx.now - Runtime.shrapnelLastCastAt
                        local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
                        if elapsed < 9.0 and enemyPos and Runtime.shrapnelLastPos then
                            if Dist2D(enemyPos, Runtime.shrapnelLastPos) < 350 then
                                goto continue_ability
                            end
                        end
                    end
                end
                if policy == "lockedEnemy" and Core.Catalog.DisableModifiers[entry.id]
                    and not ShouldCastDisable(ctx, ctx.enemy, entry.id, entry.ability) then
                    goto continue_ability
                end
                if policy == "lockedEnemy"
                    and Core.Catalog.HexAbilities[entry.id]
                    and not IsLinkBreakItem(entry.id)
                    and TargetNeedsLinkBreak(ctx.enemy) then
                    local hasLinkItem = false
                    for _, popId in ipairs(Core.Catalog.LinkbreakItems) do
                        if IsItemEnabled(popId) and not IsActionUsed(popId)
                            and not IsActionBlocked(popId, ctx.now) then
                            local pop = FindItemEntry(ctx.controlled, popId)
                            if pop and SafeValue(Ability.IsCastable, pop, ctx.mana) then
                                hasLinkItem = true
                                break
                            end
                        end
                    end
                    if hasLinkItem then
                        goto continue_ability
                    end
                end
                if not canCastOnEnemyNow(entry.ability, policy) then
                    goto continue_ability
                end
            end

            actions[#actions + 1] = {
                kind = policy,
                ability = entry.ability,
                abilityId = entry.id,
                meta = meta,
                allowSingle = policy == "bestPosition" and (meta == nil or meta.allowSingle == true),
                priority = priority,
                tag = "ability_" .. entry.id,
            }
        end
        ::continue_ability::
    end

    for _, entry in ipairs(ctx.snapshot and ctx.snapshot.items or CollectHeroItems(ctx.controlled)) do
        if IsItemEnabled(entry.id) and not ShouldSkipComboItem(entry.id) then
            if entry.id == "item_refresher" or IsActionBlocked(entry.id, ctx.now)
                or IsActionUsed(entry.id) then
                goto continue_item
            end
            local policy = ClassifyItemPolicy(entry.item, entry.id)
            if not policy then
                goto continue_item
            end
            -- SF ult burst: only the chosen setup item (abyssal XOR hex), nothing else.
            if Runtime.sfUltBurstActive
                and (policy == "linkbreak" or policy == "lockedEnemy")
                and entry.id ~= Runtime.sfUltSetupId
            then
                goto continue_item
            end
            if Core.Catalog.SelfItems[entry.id] and not IsLinkBreakItem(entry.id) then
                goto continue_item
            end
            local behavior = SafeValue(Ability.GetBehavior, entry.item, true)
                or SafeValue(Ability.GetBehavior, entry.item, false) or 0
            if HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_TOGGLE)
                and SafeValue(Ability.GetToggleState, entry.item) == true then
                MarkActionUsed(entry.id)
                goto continue_item
            end
            if policy == "linkbreak" then
                if IsActionUsed(entry.id) then
                    goto continue_item
                end
                if SafeValue(Ability.IsCastable, entry.item, ctx.mana) then
                    local invokerCombo = SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_invoker"
                    if invokerCombo
                        and entry.id == Core.Catalog.InvokerEndItemRoles.ethereal.id and ctx.enemy
                        and not IsActionUsed(entry.id)
                        and canCastOnEnemyNow(entry.item, "lockedEnemy") then
                        actions[#actions + 1] = {
                            kind = "lockedEnemy",
                            ability = entry.item,
                            abilityId = entry.id,
                            priority = 950,
                            tag = "link_" .. entry.id,
                        }
                    elseif UI.UseLinkBreak and SafeValue(UI.UseLinkBreak.Get, UI.UseLinkBreak) and ctx.enemy and TargetNeedsLinkBreak(ctx.enemy)
                        and canCastOnEnemyNow(entry.item, "linkbreak") then
                        actions[#actions + 1] = {
                            kind = "linkbreak",
                            ability = entry.item,
                            abilityId = entry.id,
                            priority = 950,
                            tag = "link_" .. entry.id,
                        }
                    elseif ctx.enemy and ShouldCastDisable(ctx, ctx.enemy, entry.id, entry.item)
                        and canCastOnEnemyNow(entry.item, "lockedEnemy") then
                        actions[#actions + 1] = {
                            kind = "lockedEnemy",
                            ability = entry.item,
                            abilityId = entry.id,
                            priority = 735,
                            tag = entry.id,
                        }
                    end
                end
            elseif policy == "lockedEnemy" and ctx.enemy then
                if IsActionUsed(entry.id) then
                    goto continue_item
                end
                if SafeValue(Ability.IsCastable, entry.item, ctx.mana) then
                    if ShouldCastDisable(ctx, ctx.enemy, entry.id, entry.item)
                        and canCastOnEnemyNow(entry.item, policy) then
                        actions[#actions + 1] = {
                            kind = "lockedEnemy",
                            ability = entry.item,
                            abilityId = entry.id,
                            priority = 740,
                            tag = entry.id,
                        }
                    end
                end
            elseif policy == "noTarget" and not Core.Catalog.SelfNoTargetItems[entry.id]
                and SafeValue(Ability.IsCastable, entry.item, ctx.mana) then
                actions[#actions + 1] = {
                    kind = "noTarget",
                    ability = entry.item,
                    abilityId = entry.id,
                    priority = 620,
                    tag = entry.id,
                }
            elseif policy == "bestPosition" and ctx.enemy
                and not entry.id:find("blink", 1, true)
                and SafeValue(Ability.IsCastable, entry.item, ctx.mana)
                and canCastOnEnemyNow(entry.item, policy) then
                actions[#actions + 1] = {
                    kind = "bestPosition",
                    ability = entry.item,
                    abilityId = entry.id,
                    allowSingle = true,
                    priority = 620,
                    tag = entry.id,
                }
            end
            ::continue_item::
        end
    end

    if IsItemEnabled("item_refresher") and not IsActionUsed("item_refresher")
        and not IsActionBlocked("item_refresher", ctx.now) then
        -- Nevermore: refresher is owned by BuildNevermorePlan after Requiem (ult chain).
        if SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_nevermore" then
            goto skip_generic_refresher
        end
        local refresher = FindItemEntry(ctx.controlled, "item_refresher")
        if refresher and SafeValue(Ability.IsCastable, refresher, ctx.mana) then
            local allOnCooldown = true
            local sawEnabledAbility = false
            if SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_invoker" then
                for ri = 1, #Core.Catalog.InvokerSteps do
                    local step = Core.Catalog.InvokerSteps[ri]
                    if IsAbilityEnabled(step.id) then
                        sawEnabledAbility = true
                        local spell = SafeValue(NPC.GetAbility, ctx.controlled, step.id)
                        local cooldown = spell and SafeValue(Ability.GetCooldown, spell)
                        if type(cooldown) ~= "number" or cooldown <= 0 then
                            allOnCooldown = false
                            break
                        end
                    end
                end
            else
                for _, entry in ipairs(ctx.snapshot and ctx.snapshot.abilities or CollectHeroAbilities(ctx.controlled)) do
                    if IsAbilityEnabled(entry.id) then
                        sawEnabledAbility = true
                        local cooldown = SafeValue(Ability.GetCooldown, entry.ability)
                        if type(cooldown) ~= "number" or cooldown <= 0 then
                            allOnCooldown = false
                            break
                        end
                    end
                end
            end
            if sawEnabledAbility and allOnCooldown then
                actions[#actions + 1] = {
                    kind = "noTarget",
                    ability = refresher,
                    abilityId = "item_refresher",
                    priority = 500,
                    tag = "item_refresher_all_skills_cd",
                }
                DbgVerbose("refresher_ready", "refresher ready | all enabled abilities on cooldown")
            end
        end
        ::skip_generic_refresher::
    end
end

Core.ResolveFriendlyFieldPosition = function(ctx, action)
    if not ctx or not ctx.controlled then
        return nil
    end
    local myPos = ctx.snapshot and ctx.snapshot.positions.controlled
        or SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    if not myPos then
        return nil
    end
    local meta = action and (action.meta or Core.Catalog.AbilityMeta[action.abilityId])
    local radius = GetAoeRadius(
        action and (action.resolverAbility or action.ability),
        action and (action.resolverAbilityId or action.abilityId),
        meta
    )
    if not radius or radius <= 0 then
        radius = (meta and meta.defaultRadius) or 300
    end
    local localPos = ctx.localHero and SafeValue(Entity.GetAbsOrigin, ctx.localHero) or nil
    if localPos and Dist2D(myPos, localPos) <= radius * 2 + RANGE_TOLERANCE then
        local mid = Vector(
            (myPos.x + localPos.x) * 0.5,
            (myPos.y + localPos.y) * 0.5,
            myPos.z
        )
        if Dist2D(mid, myPos) <= radius + RANGE_TOLERANCE
            and Dist2D(mid, localPos) <= radius + RANGE_TOLERANCE then
            return mid
        end
    end
    return myPos
end

local function ResolveActionPosition(ctx, action)
    local meta = action.meta or Core.Catalog.AbilityMeta[action.abilityId]
    if (action.positionPolicy or (meta and meta.positionPolicy)) == "selfOrLocal" then
        return Core.ResolveFriendlyFieldPosition(ctx, action), 1
    end
    local resolverAbility = action.resolverAbility or action.ability
    local resolverAbilityId = action.resolverAbilityId or action.abilityId
    local radius = GetAoeRadius(resolverAbility, resolverAbilityId, meta)
    local minHits = action.requiredHits
        or (UI.MinClusterHits and SafeValue(UI.MinClusterHits.Get, UI.MinClusterHits) or 2)
    local myPos = ctx.snapshot and ctx.snapshot.positions.controlled
        or SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local preferTarget = ctx.enemy
    local preferPos = preferTarget and SafeValue(Entity.GetAbsOrigin, preferTarget) or nil
    local enemies = GetEnemiesNear(myPos, radius + 800, ctx.controlled)
    local allies = nil
    if meta and meta.avoidAllies then
        allies = Core.GetAlliesNear(myPos, radius + 800, ctx.controlled)
    end
    local pos, hits = FindBestAoePosition(
        myPos,
        enemies,
        radius,
        minHits,
        meta and meta.predictionTime,
        allies
    )

    -- Locked target wins over densest nearby cluster (HUD target ≠ random pack).
    if preferPos then
        local coversPreferred = pos and Dist2D(pos, preferPos) <= radius + RANGE_TOLERANCE
        if not coversPreferred or (hits or 0) < minHits then
            local nearPreferred = GetEnemiesNear(preferPos, radius * 2, ctx.controlled)
            local clustered = {}
            for i = 1, #nearPreferred do
                local enemy = nearPreferred[i]
                if CanTargetEnemy(enemy, ctx.controlled) then
                    clustered[#clustered + 1] = enemy
                end
            end
            local altAllies = allies
            if meta and meta.avoidAllies then
                altAllies = Core.GetAlliesNear(preferPos, radius * 2, ctx.controlled)
            end
            local altPos, altHits = FindBestAoePosition(
                preferPos,
                clustered,
                radius,
                1,
                meta and meta.predictionTime,
                altAllies
            )
            if altPos and Dist2D(altPos, preferPos) <= radius + RANGE_TOLERANCE then
                pos, hits = altPos, altHits
                coversPreferred = true
            elseif action.allowSingle or minHits <= 1 then
                -- Still prefer an ally-clear offset over raw enemy feet.
                local soloPos, soloHits = FindBestAoePosition(
                    preferPos,
                    { preferTarget },
                    radius,
                    1,
                    meta and meta.predictionTime,
                    altAllies
                )
                if soloPos and Dist2D(soloPos, preferPos) <= radius + RANGE_TOLERANCE then
                    pos, hits = soloPos, soloHits
                else
                    pos, hits = preferPos, CountHitsAt(preferPos, clustered, radius)
                end
                coversPreferred = true
            end
        end
        if pos and action.positionMaxRange and myPos
            and Dist2D(myPos, pos) > action.positionMaxRange + RANGE_TOLERANCE then
            if Dist2D(myPos, preferPos) <= (action.positionMaxRange or 0) + RANGE_TOLERANCE then
                if meta and meta.avoidAllies and preferTarget then
                    local soloPos = FindBestAoePosition(
                        preferPos,
                        { preferTarget },
                        radius,
                        1,
                        meta and meta.predictionTime,
                        allies
                    )
                    if soloPos and Dist2D(myPos, soloPos) <= (action.positionMaxRange or 0) + RANGE_TOLERANCE then
                        return soloPos, 1
                    end
                end
                return preferPos, 1
            end
            return nil, 0
        end
        if pos and coversPreferred then
            return pos, hits or 1
        end
        if action.allowSingle or minHits <= 1 then
            if meta and meta.avoidAllies and preferTarget then
                local soloPos = FindBestAoePosition(
                    preferPos,
                    { preferTarget },
                    radius,
                    1,
                    meta and meta.predictionTime,
                    allies
                )
                if soloPos then
                    return soloPos, 1
                end
            end
            return preferPos, 1
        end
        return nil, 0
    end

    if pos and hits >= minHits then
        if action.positionMaxRange and myPos
            and Dist2D(myPos, pos) > action.positionMaxRange + RANGE_TOLERANCE then
            return nil, 0
        end
        return pos, hits
    end

    if action.allowSingle and preferPos then
        if meta and meta.avoidAllies and preferTarget then
            local soloPos = FindBestAoePosition(
                preferPos,
                { preferTarget },
                radius,
                1,
                meta and meta.predictionTime,
                allies
            )
            if soloPos then
                return soloPos, 1
            end
        end
        return preferPos, 1
    end

    return nil, 0
end

function Core.InvokerController.Status(ctx)
    if Runtime.pending then
        return {
            busy = true,
            phase = "confirm",
            spellId = Runtime.pending.abilityId,
        }
    end
    if #Runtime.actionQueue > 0 then
        local head = Runtime.actionQueue[1]
        local tag = head and head.tag or ""
        local phase = tag:sub(1, 12) == "invoker_orb_" and "prepareOrbs"
            or (head and head.abilityId == "invoker_invoke" and "invoke" or "cast")
        return {
            busy = true,
            phase = phase,
            spellId = Runtime.invokerAwaitSpell or (head and head.abilityId),
        }
    end
    if Runtime.invokerAwaitSpell then
        return {
            busy = true,
            phase = "waitSlot",
            spellId = Runtime.invokerAwaitSpell,
        }
    end
    for si = 1, #Core.Catalog.InvokerSteps do
        local step = Core.Catalog.InvokerSteps[si]
        if IsAbilityEnabled(step.id) and not IsActionUsed(step.id)
            and not IsActionBlocked(step.id, ctx.now) then
            return {
                busy = true,
                phase = "selectStep",
                spellId = step.id,
            }
        end
    end
    for i = 1, #Core.Catalog.InvokerEndItems do
        local entry = Core.Catalog.InvokerEndItems[i]
        local target = entry.targetPolicy == "localHero" and ctx.localHero or ctx.enemy
        if target and IsItemEnabled(entry.id) and not IsActionUsed(entry.id)
            and not IsActionBlocked(entry.id, ctx.now) then
            local item = FindItemEntry(ctx.controlled, entry.id)
            if item and SafeValue(Ability.IsCastable, item, ctx.mana) then
                local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
                local targetPos = SafeValue(Entity.GetAbsOrigin, target)
                if myPos and targetPos
                    and IsWithinRange2D(myPos, targetPos, GetCastRange(ctx.controlled, item)) then
                    return {
                        busy = true,
                        phase = "cast",
                        spellId = entry.id,
                    }
                end
            end
        end
    end
    return {
        busy = false,
        phase = "complete",
        spellId = nil,
    }
end

local function BuildActionPlan(ctx)
    local actions = {}
    Runtime.sfUltBurstActive = false
    Runtime.sfUltSetupId = nil

    local unitName = SafeValue(NPC.GetUnitName, ctx.controlled)
    local morphSource = nil
    if unitName == "npc_dota_hero_morphling" and IsMorphlingReplicated(ctx.controlled) then
        morphSource = ResolveMorphSourceUnitName(ctx)
    end

    local kitName = morphSource or unitName
    if kitName and kitName ~= "npc_dota_hero_invoker" then
        local kit = Core.Catalog.HeroKits[kitName]
        if kit then
            ApplyHeroKit(ctx, actions, kit)
        end
    end

    local profileFn = unitName == "npc_dota_hero_invoker"
        and Core.InvokerController.Build or (unitName and Core.Catalog.HeroProfiles[unitName])
    if profileFn then
        profileFn(ctx, actions)
    end

    -- While Morphling is replicated, also run the copied hero's custom profile.
    if morphSource
        and morphSource ~= "npc_dota_hero_invoker"
        and morphSource ~= unitName
    then
        local stolenProfile = Core.Catalog.HeroProfiles[morphSource]
        if stolenProfile then
            stolenProfile(ctx, actions)
        end
    end

    if unitName == "npc_dota_hero_invoker" then
        local status = Core.InvokerController.Status(ctx)
        Runtime.invokerFsm = status
        if not status.busy then
            AppendGenericActions(ctx, actions)
        end
        return actions
    end

    AppendGenericActions(ctx, actions)

    table.sort(actions, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return (a.abilityId or "") < (b.abilityId or "")
    end)

    local filtered = {}
    local seen = {}
    for i = 1, #actions do
        local action = actions[i]
        local key = action.abilityId or action.tag or ((action.kind or "") .. ":?")
        if not seen[key] then
            seen[key] = true
            filtered[#filtered + 1] = action
        end
    end

    return filtered
end

--#endregion

--#region Combo executor

local function ResetPending()
    Runtime.pending = nil
end

local function EndSession(reason)
    if IsDebugEnabled() and #Runtime.comboTrace > 0 then
        DbgImportant(
            "combo trace | reason=%s duration=%.2f actions=[%s]",
            reason or "unknown",
            Runtime.comboStartedAt and math.max(0, GetGameTime() - Runtime.comboStartedAt) or 0,
            table.concat(Runtime.comboTrace, " > ")
        )
    end
    DbgImportant("abort | %s", reason or "unknown")
    ResetPending()
    Runtime.actionQueue = {}
    Runtime.comboActive = false
    Runtime.comboKeyHeldPrev = false
    Runtime.comboForceResolve = false
    Runtime.failedActions = {}
    Runtime.usedActions = {}
    Runtime.sfUltBurstActive = false
    Runtime.sfUltSetupId = nil
    Runtime.shrapnelLastCastAt = 0
    Runtime.shrapnelLastPos = nil
    Runtime.shrapnelLastEnemy = nil
    Runtime.nextComboAt = 0
    Runtime.invokerComboEnemy = nil
    Runtime.invokerLastInvokeAt = 0
    Runtime.invokerAwaitSpell = nil
    Runtime.invokerFsm = { phase = "selectStep", spellId = nil }
    Runtime.lastAttackOrderAt = -math.huge
    Runtime.lastAttackTarget = nil
    Runtime.lastFollowOrderAt = -math.huge
    Runtime.lastFollowPos = nil
    Runtime.comboReleaseAt = nil
    Runtime.lockedEnemy = nil
    Runtime.lockedEnemyScore = nil
    Runtime.sessionHero = nil
    Runtime.renderSnapshot = nil
    Runtime.combatSnapshot = nil
    Runtime.catalogCache = nil
    Runtime.lastCatalogRefreshAt = -math.huge
    Runtime.snapshotInvalidated = true
    Runtime.emptyPlanUntil = 0
    Runtime.comboTrace = {}
    Runtime.comboStartedAt = nil
    Runtime.trampleOrbitAngle = nil
    Runtime.lastTrampleOrbitAt = -math.huge
    Runtime.morphSourceUnitName = nil
    Runtime.morphAwaitReplicate = false
    Runtime.morphWasReplicated = false
    Runtime.morphFormPending = false
    Runtime.morphAwaitReplicateAt = nil
    Runtime.morphFormPendingAt = nil
    Runtime.controlLostSince = nil
end

local function SyncBuiltinWidgets(force)
    local function menuFind(...)
        if not Menu or not Menu.Find then
            return nil
        end
        local ok, result = TryCall(Menu.Find, ...)
        if ok then
            return result
        end
        return nil
    end

    local now = GetGameTime()
    if not force and now - Runtime.lastBuiltinSyncAt < BUILTIN_MENU_SYNC_INTERVAL then
        return
    end
    Runtime.lastBuiltinSyncAt = now

    BuiltIn.unitsSearchRange = menuFind(
        "Heroes", "", "Settings", "General", "Units Controller", "Search Range"
    )
    BuiltIn.targetSearchRange = menuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Search Range"
    )
    BuiltIn.targetStyle = menuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Style"
    )
    BuiltIn.moveToCursor = menuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Move to Cursor"
    )

    local hero = Runtime.localHero or SafeValue(Heroes.GetLocal)
    local unitName = hero and SafeValue(NPC.GetUnitName, hero)
    local heroName = unitName
    if unitName and GameLocalizer and GameLocalizer.FindNPC then
        local localized = SafeValue(GameLocalizer.FindNPC, unitName)
        if type(localized) == "string" and localized ~= "" then
            heroName = localized
        else
            heroName = GetHeroDisplayName(unitName)
        end
    end

    if heroName and heroName == BuiltIn.lastHeroMenuName and BuiltIn.comboKey then
        return
    end

    BuiltIn.lastHeroMenuName = heroName
    BuiltIn.comboKey = nil

    if not heroName then
        return
    end

    BuiltIn.comboKey = menuFind(
        "Heroes", "Hero List", heroName, "Main Settings", "Hero Settings", "Combo Key"
    ) or menuFind(
        "Heroes", "Hero List", heroName, "Main Settings", "General", "Combo Key"
    ) or menuFind(
        "Heroes", "Hero List", heroName, "Main Settings", "Combo Key"
    )

    if BuiltIn.comboKey then
        DbgImportant("combo key linked | hero=%s", heroName)
    end
end

local function IsComboKeyHeld()
    SyncBuiltinWidgets(false)
    local widget = BuiltIn.comboKey
    if not widget or type(widget.IsDown) ~= "function" then
        return false
    end
    return SafeValue(widget.IsDown, widget) == true
end

local function BuildContext(now)
    local controlled = ResolveControlledHero()
    if not controlled or not IsValidHero(controlled) then
        -- Morph / transform can briefly invalidate the assigned hero; keep the session sticky.
        if Runtime.comboActive and Runtime.selectedPlayerId ~= nil then
            Runtime.controlLostSince = Runtime.controlLostSince or now
            if now - Runtime.controlLostSince < 1.25 then
                return nil
            end
        end
        if Runtime.comboActive or Runtime.pending then
            EndSession("controlled hero unavailable")
        end
        return nil
    end
    Runtime.controlLostSince = nil

    if Runtime.sessionHero and Runtime.sessionHero ~= controlled then
        -- Morph (and some engine refreshes) replace hero userdata while the ally slot stays the same.
        local oldValid = IsValidHero(Runtime.sessionHero)
        local oldName = oldValid and SafeValue(NPC.GetUnitName, Runtime.sessionHero) or nil
        local newName = SafeValue(NPC.GetUnitName, controlled)
        local selectedEntry = ResolveAllyEntryByPlayerId(Runtime.selectedPlayerId)
        local liveAssigned = selectedEntry and RefreshAllyEntryHero(selectedEntry) or nil
        local controlledEntry = nil
        for i = 1, #Runtime.controllableAllies do
            local entry = Runtime.controllableAllies[i]
            if entry and (entry.hero == controlled
                or (entry.player and SafeValue(Player.GetAssignedHero, entry.player) == controlled))
            then
                controlledEntry = entry
                break
            end
        end
        local sameAllySlot = controlledEntry ~= nil
            and Runtime.selectedPlayerId ~= nil
            and controlledEntry.playerId == Runtime.selectedPlayerId
        local sameHeroIdentity = oldName ~= nil and oldName == newName
        local assignedMatch = liveAssigned ~= nil and controlled == liveAssigned
        if sameAllySlot and assignedMatch and (sameHeroIdentity or not oldValid) then
            DbgImportant(
                "session hero handle refresh | %s -> %s (P%s)",
                oldName or "invalid",
                newName or "?",
                tostring(Runtime.selectedPlayerId)
            )
            Runtime.sessionHero = controlled
            Runtime.snapshotInvalidated = true
            Runtime.syncedInventorySig = nil
            Runtime.catalogCache = nil
        elseif Runtime.comboActive and not oldValid and liveAssigned and IsValidHero(liveAssigned) then
            -- Prefer sticky assigned hero over a wrong ResolveControlledHero flicker.
            controlled = liveAssigned
            Runtime.sessionHero = liveAssigned
            Runtime.snapshotInvalidated = true
            Runtime.syncedInventorySig = nil
            Runtime.catalogCache = nil
            DbgImportant(
                "session hero sticky recover | %s (P%s)",
                SafeValue(NPC.GetUnitName, liveAssigned) or "?",
                tostring(Runtime.selectedPlayerId)
            )
        else
            EndSession("controlled hero changed")
            return nil
        end
    end
    Runtime.sessionHero = controlled

    Runtime.combatSnapshot = nil
    local catalog = Runtime.catalogCache
    if Runtime.snapshotInvalidated or not catalog or catalog.controlled ~= controlled
        or now - (Runtime.lastCatalogRefreshAt or -math.huge) >= 0.35 then
        local abilityEntries = CollectHeroAbilities(controlled)
        local itemEntries = CollectHeroItems(controlled)
        catalog = {
            controlled = controlled,
            abilities = abilityEntries,
            items = itemEntries,
            abilitiesById = {},
            itemsById = {},
            enabledAbilitiesById = {},
            enabledItemsById = {},
        }
        for i = 1, #abilityEntries do
            local entry = abilityEntries[i]
            catalog.abilitiesById[entry.id] = entry.ability
            catalog.enabledAbilitiesById[entry.id] = IsAbilityEnabled(entry.id)
        end
        for i = 1, #itemEntries do
            local entry = itemEntries[i]
            catalog.itemsById[entry.id] = entry.item
            catalog.enabledItemsById[entry.id] = IsItemEnabled(entry.id)
        end
        Runtime.catalogCache = catalog
        Runtime.lastCatalogRefreshAt = now
    end
    for i = 1, #catalog.abilities do
        local id = catalog.abilities[i].id
        catalog.enabledAbilitiesById[id] = IsAbilityEnabled(id)
    end
    for i = 1, #catalog.items do
        local id = catalog.items[i].id
        catalog.enabledItemsById[id] = IsItemEnabled(id)
    end
    local snapshot = {
        now = now,
        controlled = controlled,
        localHero = Runtime.localHero,
        abilities = catalog.abilities,
        items = catalog.items,
        abilitiesById = catalog.abilitiesById,
        itemsById = catalog.itemsById,
        enabledAbilitiesById = catalog.enabledAbilitiesById,
        enabledItemsById = catalog.enabledItemsById,
        enabled = UI.Enabled and SafeValue(UI.Enabled.Get, UI.Enabled) == true,
        helpEnabled = Runtime.localPlayerId
            and SafeValue(Entity.IsControllableByPlayer, controlled, Runtime.localPlayerId) == true or false,
        positions = {},
    }
    Runtime.combatSnapshot = snapshot
    Runtime.snapshotInvalidated = false

    InvalidateLostTarget(controlled)

    local manaThreshold = UI.ManaThreshold and SafeValue(UI.ManaThreshold.Get, UI.ManaThreshold) or 15
    local mana = SafeValue(NPC.GetMana, controlled) or 0

    local enemy = ResolveLockedEnemy({
        controlled = controlled,
        now = now,
    }, Runtime.comboForceResolve or (Runtime.comboActive and not Runtime.lockedEnemy))

    if not enemy and Runtime.comboActive and Runtime.lockedEnemy and CanTargetEnemy(Runtime.lockedEnemy, controlled) then
        enemy = Runtime.lockedEnemy
    end
    snapshot.positions.controlled = SafeValue(Entity.GetAbsOrigin, controlled)
    snapshot.positions.localHero = Runtime.localHero and SafeValue(Entity.GetAbsOrigin, Runtime.localHero) or nil
    snapshot.positions.enemy = enemy and SafeValue(Entity.GetAbsOrigin, enemy) or nil

    local ctx = {
        now = now,
        player = Runtime.localPlayer,
        controlled = controlled,
        localHero = Runtime.localHero,
        enemy = enemy,
        mana = mana,
        canCast = snapshot.enabled and snapshot.helpEnabled
            and CanAct(controlled) and GetManaPct(controlled) >= manaThreshold,
        snapshot = snapshot,
    }
    EnsureCtxEnemy(ctx)
    snapshot.enemy = ctx.enemy
    snapshot.mana = mana
    snapshot.canCast = ctx.canCast
    snapshot.positions.enemy = ctx.enemy and SafeValue(Entity.GetAbsOrigin, ctx.enemy) or nil
    return ctx
end

function Core.ActionRunner.NextIdentifier(tag)
    Runtime.orderSequence = (Runtime.orderSequence or 0) + 1
    return OrderTag((tag or "action") .. "#" .. tostring(Runtime.orderSequence))
end

function Core.ActionRunner.Normalize(action)
    if not action then
        return nil
    end
    local kind = action.kind
    if kind ~= "localHero" and kind ~= "linkbreak" and kind ~= "lockedEnemy"
        and kind ~= "bestPosition" and kind ~= "noTarget" and kind ~= "iceWall" then
        return nil
    end
    local meta = action.meta or Core.Catalog.AbilityMeta[action.abilityId]
    action.meta = meta
    action.targetPolicy = action.targetPolicy
        or (kind == "localHero" and "localHero"
            or ((kind == "lockedEnemy" or kind == "linkbreak" or kind == "iceWall") and "lockedEnemy" or "none"))
    action.positionPolicy = action.positionPolicy
        or (meta and meta.positionPolicy)
        or (kind == "bestPosition" and "dynamicAoe"
            or (kind == "iceWall" and "sideFacing" or "none"))
    action.rangePolicy = action.rangePolicy
        or ((kind == "noTarget" or kind == "iceWall") and kind or "castRange")
    action.issuePolicy = action.issuePolicy or kind
    if not action.confirmationPolicy then
        local tag = action.tag or ""
        local abilityId = action.abilityId
        local isInvokerStep = false
        if abilityId then
            for ci = 1, #Core.Catalog.InvokerSteps do
                if Core.Catalog.InvokerSteps[ci].id == abilityId then
                    isInvokerStep = true
                    break
                end
            end
        end
        if tag:sub(1, 12) == "invoker_orb_" then
            action.confirmationPolicy = "orbAck"
        elseif abilityId == "invoker_invoke" then
            action.confirmationPolicy = "invokeSlot"
        elseif abilityId == "item_refresher" then
            action.confirmationPolicy = "cooldown"
        elseif kind == "linkbreak" then
            action.confirmationPolicy = "linkenState"
        elseif isInvokerStep then
            action.confirmationPolicy = "usageEvidence"
        else
            action.confirmationPolicy = "usageOrAck"
        end
    end
    return action
end

function Core.ActionRunner.PreparePending(ctx, action)
    local behavior = SafeValue(Ability.GetBehavior, action.ability, true)
        or SafeValue(Ability.GetBehavior, action.ability, false) or 0
    local isChanneled = HasAbilityBehaviorFlag(behavior, BEH.DOTA_ABILITY_BEHAVIOR_CHANNELLED)
    local timeout = isChanneled and 4.0 or ACTION_TIMEOUT
    local absoluteTimeout = isChanneled and 12.0 or ACTION_TIMEOUT
    local charges = SafeValue(Ability.GetCurrentCharges, action.ability)
    local identifier = Core.ActionRunner.NextIdentifier(action.tag)
    return {
        status = "prepared",
        kind = action.kind,
        targetPolicy = action.targetPolicy,
        positionPolicy = action.positionPolicy,
        rangePolicy = action.rangePolicy,
        issuePolicy = action.issuePolicy,
        confirmationPolicy = action.confirmationPolicy,
        ability = action.ability,
        abilityId = action.abilityId,
        target = action.targetPolicy == "localHero" and ctx.localHero
            or (action.targetPolicy == "lockedEnemy" and ctx.enemy or nil),
        position = action.position,
        positionAt = action.positionAt,
        positionTtl = action.positionTtl,
        resolverAbility = action.resolverAbility,
        resolverAbilityId = action.resolverAbilityId,
        positionMaxRange = action.positionMaxRange,
        meta = action.meta,
        allowSingle = action.allowSingle,
        requiredHits = action.requiredHits,
        aoeRadius = action.aoeRadius,
        requiresAction = action.requiresAction,
        tag = action.tag,
        identifier = identifier,
        attemptIdentifiers = { [identifier] = true },
        startedAt = ctx.now,
        lastAttempt = ctx.now,
        attempts = 1,
        deadline = ctx.now + timeout,
        absoluteDeadline = ctx.now + absoluteTimeout,
        cooldownAtStart = SafeValue(Ability.GetCooldown, action.ability),
        chargesAtStart = type(charges) == "number" and charges or nil,
        toggleAtStart = SafeValue(Ability.GetToggleState, action.ability),
        secondsSinceAtStart = SafeValue(Ability.SecondsSinceLastUse, action.ability),
        originAtStart = SafeValue(Entity.GetAbsOrigin, ctx.controlled),
        phaseObserved = false,
        channelObserved = false,
    }
end

function Core.ActionRunner.PrepareRetry(pending, now)
    pending.status = "retrying"
    pending.attempts = (pending.attempts or 0) + 1
    pending.lastAttempt = now
    pending.identifier = Core.ActionRunner.NextIdentifier(pending.tag)
    pending.attemptIdentifiers = pending.attemptIdentifiers or {}
    pending.attemptIdentifiers[pending.identifier] = true
end

function Core.ActionRunner.DropDependents(abilityId)
    if not abilityId then
        return
    end
    for i = #Runtime.actionQueue, 1, -1 do
        if Runtime.actionQueue[i].requiresAction == abilityId then
            table.remove(Runtime.actionQueue, i)
        end
    end
end

local function ConfirmAction(ctx, pending)
    if not pending or not pending.ability then
        return true
    end

    local function abilityWasUsedRecently(ability, startedAt, now)
        if not ability then
            return false
        end
        local since = SafeValue(Ability.SecondsSinceLastUse, ability)
        if type(since) ~= "number" or since < 0 then
            return false
        end
        local elapsed = type(startedAt) == "number" and now - startedAt or 0
        if elapsed < 0.03 then
            return false
        end
        local atStart = pending.secondsSinceAtStart
        if type(atStart) == "number" then
            if atStart < 0 then
                return since <= elapsed + 0.12
            end
            return since + 0.02 < atStart
        end
        return since <= elapsed + 0.12
    end

    local function isInvokerCastSpell(abilityId)
        if not abilityId then
            return false
        end
        for ci = 1, #Core.Catalog.InvokerSteps do
            if Core.Catalog.InvokerSteps[ci].id == abilityId then
                return true
            end
        end
        return false
    end

    local function hasUsageEvidence()
        if abilityWasUsedRecently(pending.ability, pending.startedAt, ctx.now) then
            return true
        end
        local cooldown = SafeValue(Ability.GetCooldown, pending.ability)
        if type(pending.cooldownAtStart) == "number"
            and pending.cooldownAtStart <= 0.05
            and type(cooldown) == "number" and cooldown > 0.1 then
            return true
        end
        local charges = SafeValue(Ability.GetCurrentCharges, pending.ability)
        if type(pending.chargesAtStart) == "number"
            and type(charges) == "number" and charges < pending.chargesAtStart then
            return true
        end
        local toggle = SafeValue(Ability.GetToggleState, pending.ability)
        if type(pending.toggleAtStart) == "boolean"
            and type(toggle) == "boolean" and toggle ~= pending.toggleAtStart then
            return true
        end
        if pending.abilityId and pending.abilityId:find("blink", 1, true)
            and pending.originAtStart and ctx.controlled then
            local currentOrigin = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
            if currentOrigin and Dist2D(currentOrigin, pending.originAtStart) >= 80 then
                return true
            end
        end
        return false
    end

    if SafeValue(Ability.IsInAbilityPhase, pending.ability) then
        pending.phaseObserved = true
        return false
    end

    local function hasOrderAckSettled()
        if not pending.orderAck then
            return false
        end
        local ackAt = pending.ackAt or pending.startedAt
        return type(ackAt) == "number" and ctx.now - ackAt >= INVOKER_ORB_ACK_SETTLE
    end

    local function isNoLongerCastable()
        if not pending.ability then
            return false
        end
        if ctx.mana ~= nil then
            local castable = SafeValue(Ability.IsCastable, pending.ability, ctx.mana)
            if castable == false then
                return true
            end
        end
        return SafeValue(Ability.CanBeExecuted, pending.ability) ~= ABILITY_CAST_READY
    end

    local function hasAckCastEvidence()
        if not hasOrderAckSettled() then
            return false
        end
        if hasUsageEvidence() then
            return true
        end
        if pending.phaseObserved or pending.channelObserved then
            return isNoLongerCastable()
        end
        return isNoLongerCastable()
    end

    local function confirmDefault()
        local confirmationPolicy = pending.confirmationPolicy or "usageOrAck"
        if confirmationPolicy == "usageEvidence" then
            return hasUsageEvidence()
        end
        return hasUsageEvidence() or hasAckCastEvidence()
    end

    local confirmationPolicy = pending.confirmationPolicy or "usageOrAck"
    if confirmationPolicy == "orbAck" then
        return hasOrderAckSettled() or hasUsageEvidence()
    end
    if confirmationPolicy == "cooldown" then
        return hasUsageEvidence()
    end

    if confirmationPolicy == "linkenState" and ctx.enemy then
        if isInvokerCastSpell(pending.abilityId) then
            return not TargetNeedsLinkBreak(ctx.enemy) or hasUsageEvidence()
        end
        return not TargetNeedsLinkBreak(ctx.enemy)
    end

    if pending.kind == "lockedEnemy" and pending.target then
        if Core.Catalog.DisableModifiers[pending.abilityId] then
            local remaining = GetActiveDisableRemaining(pending.target, pending.abilityId, ctx.now)
            if remaining and remaining > 0.05 then
                return true
            end
        end
        if Core.Catalog.HexAbilities[pending.abilityId]
            and SafeValue(NPC.HasState, pending.target, Enum.ModifierState.MODIFIER_STATE_HEXED)
            and hasOrderAckSettled() then
            return true
        end
        local chBehavior = SafeValue(Ability.GetBehavior, pending.ability, true)
            or SafeValue(Ability.GetBehavior, pending.ability, false) or 0
        local isChanneled = HasAbilityBehaviorFlag(chBehavior, BEH.DOTA_ABILITY_BEHAVIOR_CHANNELLED)
        if isChanneled then
            if SafeValue(Ability.IsChannelling, pending.ability)
                or SafeValue(NPC.IsChannellingAbility, ctx.controlled) then
                local channel = SafeValue(NPC.GetChannellingAbility, ctx.controlled)
                if channel == pending.ability or SafeValue(Ability.IsChannelling, pending.ability) then
                    pending.channelObserved = true
                    return false
                end
            end
            return pending.channelObserved and confirmDefault()
        end
        if SafeValue(NPC.IsChannellingAbility, ctx.controlled) then
            local channel = SafeValue(NPC.GetChannellingAbility, ctx.controlled)
            if channel == pending.ability then
                return false
            end
        end
        return confirmDefault()
    end

    if pending.kind == "localHero" then
        if pending.target and pending.abilityId == "invoker_alacrity"
            and SafeValue(NPC.HasModifier, pending.target, "modifier_invoker_alacrity") then
            return true
        end
        return confirmDefault()
    end

    if pending.kind == "noTarget" or pending.kind == "bestPosition" or pending.kind == "iceWall" then
        if confirmationPolicy == "invokeSlot" then
            local awaitId = Runtime.invokerAwaitSpell
            if awaitId and ctx.controlled then
                local spell = FindInvokerBarSpell(ctx.controlled, awaitId)
                if spell and GetAbilityId(spell) == awaitId then
                    return true
                end
            end
            return hasUsageEvidence()
        end
        if isInvokerCastSpell(pending.abilityId) then
            return hasUsageEvidence()
        end
        local chBehavior = SafeValue(Ability.GetBehavior, pending.ability, true)
            or SafeValue(Ability.GetBehavior, pending.ability, false) or 0
        local isChanneled = HasAbilityBehaviorFlag(chBehavior, BEH.DOTA_ABILITY_BEHAVIOR_CHANNELLED)
        if isChanneled then
            if SafeValue(Ability.IsChannelling, pending.ability)
                or SafeValue(NPC.IsChannellingAbility, ctx.controlled) then
                local channel = SafeValue(NPC.GetChannellingAbility, ctx.controlled)
                if channel == pending.ability or SafeValue(Ability.IsChannelling, pending.ability) then
                    pending.channelObserved = true
                    return false
                end
            end
            return pending.channelObserved and confirmDefault()
        end
        return confirmDefault()
    end

    return confirmDefault()
end

local function IssueMoveToPosition(ctx, pos, tag)
    if not ctx or not ctx.controlled or not pos then
        return false
    end
    if Runtime.lastMovePos and ctx.now
        and Dist2D(Runtime.lastMovePos, pos) <= 18
        and ctx.now - (Runtime.lastMoveOrderAt or -math.huge) < 0.18 then
        return false
    end

    local issued = Core.OrderGateway.Issue(
        ctx.player,
        O_MOVE,
        nil,
        pos,
        nil,
        ctx.controlled,
        OrderTag(tag)
    )

    if issued and IsDebugVerbose() then
        local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
        local moveDist = myPos and Dist2D(myPos, pos) or -1
        DbgVerbose("move_order","move | tag=%s moveDist=%.0f | %s", tag or "?", moveDist, FormatRangeContext(ctx))
    end
    if issued then
        Runtime.lastMovePos = pos
        if ctx.now then
            Runtime.lastMoveOrderAt = ctx.now
        end
    end

    return issued
end

-- Face + short align so Shadowraze (forward cone) lands on the locked enemy.
-- Returns true (ready), false (wait/align), or "drop" (stale/wrong-range — remove from queue).
Core.EnsureNevermoreRazeReady = function(ctx, action)
    if not ctx or not ctx.controlled or not ctx.enemy or not action then
        return false
    end
    local range = action.razeRange
    if type(range) ~= "number" then
        for i = 1, #Core.Catalog.Shadowraze do
            if Core.Catalog.Shadowraze[i].id == action.abilityId then
                range = Core.Catalog.Shadowraze[i].range
                break
            end
        end
    end
    if type(range) ~= "number" then
        return true
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
    if not myPos or not enemyPos then
        return false
    end
    local dist = Dist2D(myPos, enemyPos)
    local err = math.abs(dist - range)
    local maxWalk = dist < range
        and (Core.Catalog.ShadowrazeMaxBack or 100)
        or (Core.Catalog.ShadowrazeMaxClose or 140)

    -- After blink/items the queued raze is often the pre-blink pick (e.g. raze3@700
    -- while standing at 80). Retarget or drop instead of walking across the map.
    if err > maxWalk then
        local pick = Core.PickBestShadowraze(dist)
        if pick and (pick.id ~= action.abilityId or math.abs(dist - pick.range) + 1 < err) then
            local ability = FindAbilityEntry(ctx.controlled, pick.id)
            if ability
                and IsAbilityEnabled(pick.id)
                and not IsActionUsed(pick.id)
                and not IsActionBlocked(pick.id, ctx.now)
                and SafeValue(Ability.IsCastable, ability, ctx.mana)
            then
                Core.DbgEvent(
                    "sf_raze_retarget | %s@%.0f -> %s@%.0f dist=%.0f | %s",
                    action.abilityId or "?",
                    range,
                    pick.id,
                    pick.range,
                    dist,
                    FormatRangeContext(ctx)
                )
                action.ability = ability
                action.abilityId = pick.id
                action.razeRange = pick.range
                action.tag = "kit_" .. pick.id
                range = pick.range
                err = math.abs(dist - range)
                maxWalk = dist < range
                    and (Core.Catalog.ShadowrazeMaxBack or 100)
                    or (Core.Catalog.ShadowrazeMaxClose or 140)
            end
        end
        if err > maxWalk then
            Core.DbgEvent(
                "sf_raze_drop | id=%s dist=%.0f want=%.0f err=%.0f maxWalk=%.0f | %s",
                action.abilityId or "?",
                dist,
                range,
                err,
                maxWalk,
                FormatRangeContext(ctx)
            )
            -- Brief block so planner does not re-queue/drop every tick while approaching.
            if action.abilityId and ctx.now then
                Runtime.failedActions[action.abilityId] = ctx.now + 0.45
            end
            return "drop"
        end
    end

    local alignTol = 55
    local standPos = enemyPos:Extend2D(myPos, range)
    local needAlign = err > alignTol
    local faceTime = SafeValue(NPC.GetTimeToFacePosition, ctx.controlled, enemyPos)
    local needFace = type(faceTime) == "number" and faceTime > 0.12
    local hitTol = 120

    if needAlign and standPos then
        DbgVerbose("sf_raze",
            "sf_raze_align | id=%s dist=%.0f want=%.0f err=%.0f face=%.2f | %s",
            action.abilityId or "?",
            dist,
            range,
            err,
            type(faceTime) == "number" and faceTime or -1,
            FormatRangeContext(ctx)
        )
        IssueMoveToPosition(ctx, standPos, "sf_raze_align")
        return false
    end
    if needFace then
        local nudge = myPos:Extend2D(enemyPos, math.min(55, math.max(20, dist * 0.08)))
        DbgVerbose("sf_raze",
            "sf_raze_face | id=%s dist=%.0f want=%.0f face=%.2f | %s",
            action.abilityId or "?",
            dist,
            range,
            faceTime,
            FormatRangeContext(ctx)
        )
        IssueMoveToPosition(ctx, nudge, "sf_raze_face")
        return false
    end
    if dist < range - hitTol or dist > range + hitTol then
        DbgVerbose("sf_raze",
            "sf_raze_wait | id=%s dist=%.0f want=%.0f hitTol=%.0f face=%.2f | %s",
            action.abilityId or "?",
            dist,
            range,
            hitTol,
            type(faceTime) == "number" and faceTime or -1,
            FormatRangeContext(ctx)
        )
        if standPos then
            IssueMoveToPosition(ctx, standPos, "sf_raze_align")
        end
        return false
    end
    Core.DbgEvent(
        "sf_raze_ready | id=%s dist=%.0f want=%.0f face=%.2f | %s",
        action.abilityId or "?",
        dist,
        range,
        type(faceTime) == "number" and faceTime or -1,
        FormatRangeContext(ctx)
    )
    return true
end

Core.DropNevermoreRazesFromQueue = function(reason)
    local removed = 0
    for i = #Runtime.actionQueue, 1, -1 do
        local a = Runtime.actionQueue[i]
        if a and a.abilityId and a.abilityId:find("nevermore_shadowraze", 1, true) then
            table.remove(Runtime.actionQueue, i)
            removed = removed + 1
        end
    end
    if removed > 0 then
        Core.DbgEvent("sf_raze_queue_clear | reason=%s removed=%d", reason or "?", removed)
    end
end

local function GetActionTargetPos(ctx, ref)
    if not ref or not ctx then
        return nil
    end
    local positionPolicy = ref.positionPolicy
        or (ref.kind == "bestPosition" and "dynamicAoe")
        or (ref.kind == "iceWall" and "sideFacing")
        or "none"
    local targetPolicy = ref.targetPolicy
        or (ref.kind == "localHero" and "localHero")
        or ((ref.kind == "lockedEnemy" or ref.kind == "linkbreak" or ref.kind == "iceWall")
            and "lockedEnemy")
        or "none"
    if positionPolicy == "dynamicAoe" then
        return ref.position
    end
    if positionPolicy == "selfOrLocal" then
        return ref.position or Core.ResolveFriendlyFieldPosition(ctx, ref)
    end
    if positionPolicy == "sideFacing" then
        local target = ref.target or ctx.enemy
        local enemyPos = target and SafeValue(Entity.GetAbsOrigin, target)
        local myPos = ctx.controlled and SafeValue(Entity.GetAbsOrigin, ctx.controlled)
        if not enemyPos or not myPos then
            return nil
        end
        local dx = enemyPos.x - myPos.x
        local dy = enemyPos.y - myPos.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= 300 or distance <= 0.001 then
            return enemyPos
        end

        local ux = dx / distance
        local uy = dy / distance
        local forwardRatio = math.min(1, 200 / distance)
        local sideRatio = math.sqrt(math.max(0, 1 - forwardRatio * forwardRatio))
        local faceX = ux * forwardRatio - uy * sideRatio
        local faceY = uy * forwardRatio + ux * sideRatio
        local alternateX = ux * forwardRatio + uy * sideRatio
        local alternateY = uy * forwardRatio - ux * sideRatio
        local rotation = SafeValue(Entity.GetRotation, ctx.controlled)
        local currentForward = rotation and rotation:GetForward()
        if currentForward
            and currentForward.x * alternateX + currentForward.y * alternateY
                > currentForward.x * faceX + currentForward.y * faceY then
            faceX = alternateX
            faceY = alternateY
        end
        return Vector(myPos.x + faceX * 800, myPos.y + faceY * 800, myPos.z)
    end
    if targetPolicy == "lockedEnemy" then
        local target = ref.target or ctx.enemy
        return target and SafeValue(Entity.GetAbsOrigin, target) or nil
    end
    if targetPolicy == "localHero" then
        return ctx.localHero and SafeValue(Entity.GetAbsOrigin, ctx.localHero) or nil
    end
    return nil
end

local function GetFaceTimeToAction(ctx, ref)
    if not ctx or not ctx.controlled or not ref then
        return 0
    end
    local targetPos = GetActionTargetPos(ctx, ref)
    if not targetPos then
        return 0
    end
    local faceTime = SafeValue(NPC.GetTimeToFacePosition, ctx.controlled, targetPos)
    return type(faceTime) == "number" and math.max(0, faceTime) or 0
end

local function PrepareActionForExecution(ctx, action)
    if not action then
        return false
    end
    local rangePolicy = action.rangePolicy or action.kind
    local positionPolicy = action.positionPolicy
        or (action.kind == "bestPosition" and "dynamicAoe")
        or "none"
    if rangePolicy == "noTarget" and action.requiredHits and action.aoeRadius then
        local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
        local enemies = GetEnemiesNear(myPos, action.aoeRadius + 50, ctx.controlled)
        return CountHitsAt(myPos, enemies, action.aoeRadius) >= action.requiredHits
    end
    if positionPolicy ~= "dynamicAoe" and positionPolicy ~= "selfOrLocal" then
        return true
    end
    if action.position and ctx.now - (action.positionAt or 0) < (action.positionTtl or 0.12) then
        return true
    end
    local pos = ResolveActionPosition(ctx, action)
    if not pos then
        return false
    end
    action.position = pos
    action.positionAt = ctx.now
    return true
end

local function IsWithinCastRange(ctx, ref)
    if not ref then
        return false
    end
    local rangePolicy = ref.rangePolicy or ref.kind
    if rangePolicy == "noTarget" then
        return true
    end
    if not PrepareActionForExecution(ctx, ref) then
        return false
    end
    local targetPos = GetActionTargetPos(ctx, ref)
    if not targetPos or not ref.ability then
        return false
    end
    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    if rangePolicy == "iceWall" then
        local target = ref.target or ctx.enemy
        local enemyPos = target and SafeValue(Entity.GetAbsOrigin, target)
        local distance = myPos and enemyPos and Dist2D(myPos, enemyPos) or math.huge
        local faceTime = SafeValue(NPC.GetTimeToFacePosition, ctx.controlled, targetPos)
        return distance >= 95 and distance <= 620
            and type(faceTime) == "number" and faceTime <= 0.08
    end
    local castRange = GetCastRange(ctx.controlled, ref.ability)
    if castRange <= 0 then
        return false
    end
    local target = ref.target
        or ((rangePolicy == "lockedEnemy" or ref.kind == "lockedEnemy" or ref.kind == "linkbreak")
            and ctx.enemy)
        or (ref.kind == "localHero" and ctx.localHero)
        or nil
    if target then
        local inRange = SafeValue(NPC.IsEntityInRange, ctx.controlled, target, castRange)
        if inRange == true then
            return true
        end
        -- Hull-aware API said no; Dist2D with buffer can still lie near the edge.
        return false
    end
    return IsWithinRange2D(myPos, targetPos, castRange)
end

local function EnsureUnitIdleForCast(ctx)
    if SafeValue(NPC.IsAttacking, ctx.controlled) or SafeValue(NPC.IsRunning, ctx.controlled) then
        Core.OrderGateway.Issue(
            ctx.player,
            O_STOP,
            nil,
            nil,
            nil,
            ctx.controlled,
            OrderTag(((Runtime.pending and Runtime.pending.tag) or "cast") .. "_stop")
        )
        return false
    end
    return true
end

local function ExecuteAction(ctx, action)
    if not action or not action.ability then
        return false
    end
    local issuePolicy = action.issuePolicy or action.kind

    if issuePolicy == "localHero" and ctx.localHero then
        return CastOnTarget(ctx, action.ability, ctx.localHero, action.tag, action.identifier)
    end

    if issuePolicy == "linkbreak" and (action.target or ctx.enemy) then
        local target = action.target or ctx.enemy
        if not Humanizer or not Humanizer.IsSafeTarget then
            return false
        end
        local ok, safe = TryCall(Humanizer.IsSafeTarget, target)
        if not ok or safe ~= true then
            return false
        end
        return CastDisableOnEnemy(
            ctx,
            action.ability,
            action.abilityId,
            target,
            action.tag,
            action.identifier
        )
    end

    if issuePolicy == "lockedEnemy" and (action.target or ctx.enemy) then
        local target = action.target or ctx.enemy
        if not Humanizer or not Humanizer.IsSafeTarget then
            return false
        end
        local ok, safe = TryCall(Humanizer.IsSafeTarget, target)
        if not ok or safe ~= true then
            return false
        end
        if action.forcePointCast then
            local pos = FindHexPointCastPosition
                and FindHexPointCastPosition(ctx, action.ability, action.abilityId, target)
                or SafeValue(Entity.GetAbsOrigin, target)
            if not pos then
                return false
            end
            DbgImportant("point cast retry | %s", action.abilityId or action.tag or "?")
            return CastAtPosition(ctx, action.ability, pos, action.tag, action.identifier)
        end
        return CastDisableOnEnemy(
            ctx,
            action.ability,
            action.abilityId,
            target,
            action.tag,
            action.identifier
        )
    end

    if issuePolicy == "bestPosition" then
        local pos = action.position
        if not pos then
            pos = ResolveActionPosition(ctx, action)
        end
        if not pos then
            return false
        end
        return CastAtPosition(ctx, action.ability, pos, action.tag, action.identifier)
    end

    if issuePolicy == "noTarget" then
        return CastNoTarget(ctx, action.ability, action.tag, action.identifier)
    end

    if issuePolicy == "iceWall" then
        return CastNoTarget(ctx, action.ability, action.tag, action.identifier)
    end

    return false
end

local function IssueAttackEnemy(ctx, tag)
    if not ctx or not ctx.controlled or not ctx.enemy then
        return false
    end

    if SafeValue(NPC.IsAttacking, ctx.controlled) then
        return true
    end
    if ctx.now and ctx.now - (Runtime.lastAttackOrderAt or 0) < (
        IsRangedAttacker(ctx.controlled)
            and (Runtime.comboActive and 0.12 or ATTACK_ORDER_INTERVAL)
            or MELEE_ATTACK_ORDER_INTERVAL
    ) and Runtime.lastAttackTarget == ctx.enemy then
        return true
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
    local dist = myPos and enemyPos and Dist2D(myPos, enemyPos) or -1
    DbgVerbose("event",
        "attack_target | tag=%s dist=%.0f atk=%d | %s",
        tag or "?",
        dist,
        GetAttackRange(ctx.controlled),
        FormatRangeContext(ctx)
    )

    local pos = enemyPos or SafeValue(Entity.GetAbsOrigin, ctx.enemy)
    local issued = Core.OrderGateway.Issue(
        ctx.player,
        O_ATTACK,
        ctx.enemy,
        pos,
        nil,
        ctx.controlled,
        OrderTag(tag)
    )
    if issued then
        Runtime.lastAttackOrderAt = ctx.now
        Runtime.lastAttackTarget = ctx.enemy
    end
    return issued
end

local function IssueRangedAttackEnemy(ctx, tag)
    if not ctx or not ctx.controlled or not ctx.enemy then
        return false
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
    if not myPos or not enemyPos then
        return false
    end

    local attackRange = GetAttackRange(ctx.controlled)
    local dist = Dist2D(myPos, enemyPos)
    local inRange = IsWithinRange2D(myPos, enemyPos, attackRange)

    if inRange then
        if SafeValue(NPC.IsAttacking, ctx.controlled) then
            DbgVerbose(
                "ranged_atk",
                "hold | already attacking dist=%.0f atk=%d | %s",
                dist,
                attackRange,
                FormatRangeContext(ctx)
            )
            return true
        end
        if ctx.now - (Runtime.lastAttackOrderAt or 0) < (Runtime.comboActive and 0.12 or ATTACK_ORDER_INTERVAL) and Runtime.lastAttackTarget == ctx.enemy then
            return true
        end
        DbgVerbose("event",
            "ranged_atk | ATTACK dist=%.0f atk=%d tol=%d | %s",
            dist,
            attackRange,
            RANGE_TOLERANCE,
            FormatRangeContext(ctx)
        )
        return IssueAttackEnemy(ctx, tag)
    end

    local enterDist = math.max(attackRange - RANGE_ATTACK_BUFFER, 80)
    DbgVerbose("event",
        "ranged_atk | MOVE dist=%.0f atk=%d need<=%d enterDist=%.0f | %s",
        dist,
        attackRange,
        attackRange + RANGE_TOLERANCE,
        enterDist,
        FormatRangeContext(ctx)
    )
    local standPos = enemyPos:Extend2D(myPos, enterDist)
    return IssueMoveToPosition(ctx, standPos, tag .. "_range")
end

local function IssueEnemyAttack(ctx, tag)
    local path = IsRangedAttacker(ctx.controlled) and "ranged" or "melee"
    DbgVerbose("enemy_atk", "path=%s tag=%s | %s", path, tag or "?", FormatRangeContext(ctx))
    if path == "ranged" then
        return IssueRangedAttackEnemy(ctx, tag)
    end
    return IssueAttackEnemy(ctx, tag)
end

-- Circle the target while Trample is up so movement distance procs stomps.
local function IssueTrampleOrbit(ctx, tag)
    local enemy = ctx.enemy
    local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
    local enemyPos = enemy and SafeValue(Entity.GetAbsOrigin, enemy)
    if not myPos or not enemyPos then
        return false
    end

    local dist = Dist2D(myPos, enemyPos)
    if dist > TRAMPLE_ORBIT_RADIUS + 120 then
        local approach = enemyPos:Extend2D(myPos, TRAMPLE_ORBIT_RADIUS)
        return IssueMoveToPosition(ctx, approach, (tag or "trample") .. "_close")
    end

    local moving = SafeValue(NPC.IsRunning, ctx.controlled) == true
    -- Keep issuing waypoints for the full Trample duration; only throttle while
    -- already running toward the previous orbit point.
    if moving and ctx.now - (Runtime.lastTrampleOrbitAt or 0) < TRAMPLE_ORBIT_INTERVAL then
        return true
    end

    local dx = myPos.x - enemyPos.x
    local dy = myPos.y - enemyPos.y
    local current = math.atan(dy, dx)
    local angle = (Runtime.trampleOrbitAngle or current) + TRAMPLE_ORBIT_STEP
    Runtime.trampleOrbitAngle = angle
    local dest = Vector(
        enemyPos.x + math.cos(angle) * TRAMPLE_ORBIT_RADIUS,
        enemyPos.y + math.sin(angle) * TRAMPLE_ORBIT_RADIUS,
        enemyPos.z
    )
    local issued = IssueMoveToPosition(ctx, dest, tag or "trample_orbit")
    if issued then
        Runtime.lastTrampleOrbitAt = ctx.now
        if IsDebugVerbose() then
            DbgVerbose("event", "trample orbit | dist=%.0f angle=%.2f | %s",
                dist, angle, FormatRangeContext(ctx))
        end
    end
    return issued
end

local function ProcessMovement(ctx)
    EnsureCtxEnemy(ctx)
    local moveEnemy = GetMovementEnemy(ctx)
    if Runtime.comboActive and not moveEnemy and Runtime.lockedEnemy then
        Runtime.lockedEnemy = nil
        Runtime.lockedEnemyScore = nil
        Runtime.actionQueue = {}
    end
    local hasEnemy = moveEnemy ~= nil

    if Runtime.comboActive and not hasEnemy then
        local chase = ResolveTargetByNearest(ctx.controlled, GetTargetSearchRadius(), true)
        if chase then
            Runtime.lockedEnemy = chase
            ctx.enemy = chase
            moveEnemy = chase
            hasEnemy = true
        end
    end

    if Runtime.pending then
        -- Never STOP here after a cast was issued: STOP in the same update cancels CAST_TARGET (Lion Hex).
        if IsDebugVerbose() then
            DbgTransition("move_block", "pending:" .. (Runtime.pending.tag or "?"),
                "pending=%s | %s", Runtime.pending.tag or "?", FormatRangeContext(ctx))
        end
        return
    end

    if SafeValue(NPC.IsChannellingAbility, ctx.controlled) then
        if IsDebugVerbose() then
            DbgTransition("move_block", "channeling", "channeling | %s", FormatRangeContext(ctx))
        end
        return
    end

    local queueBlocksMove = false
    if Runtime.comboActive and hasEnemy and #Runtime.actionQueue > 0 then
        EnsureCtxEnemy(ctx)
        local head = Runtime.actionQueue[1]
        if head and head.ability then
            local headReady = SafeValue(Ability.IsCastable, head.ability, ctx.mana)
                or SafeValue(Ability.CanBeExecuted, head.ability) == ABILITY_CAST_READY
            if headReady then
                if head.kind == "iceWall" then
                    queueBlocksMove = IsWithinCastRange(ctx, head)
                elseif head.kind == "noTarget" then
                    local headTag = head.tag or ""
                    if headTag:sub(1, 12) ~= "invoker_orb_" then
                        queueBlocksMove = true
                    end
                elseif head.kind == "localHero" then
                    if IsWithinCastRange(ctx, head) then
                        queueBlocksMove = true
                    end
                elseif head.kind ~= "lockedEnemy" and head.kind ~= "linkbreak" and head.kind ~= "bestPosition" then
                    queueBlocksMove = false
                elseif ctx.enemy and IsWithinCastRange(ctx, head) then
                    queueBlocksMove = true
                end
            end
        end
    end

    -- While Trample is active, never freeze movement for a "ready" Pulverize —
    -- orbit must continue for the full buff duration.
    local tramplingForMove = Runtime.comboActive and IsPrimalBeastTrampling(ctx.controlled)
    if queueBlocksMove and not tramplingForMove then
        if IsDebugVerbose() then
            DbgTransition("move_block", "queue:" .. tostring(#Runtime.actionQueue),
                "combo ready cast queue=%d | %s", #Runtime.actionQueue, FormatRangeContext(ctx))
        end
        return
    end
    if queueBlocksMove and tramplingForMove and IsDebugVerbose() then
        DbgVerbose("move_tick",
            "trample overrides ready cast | queue=%d | %s",
            #Runtime.actionQueue,
            FormatRangeContext(ctx)
        )
    end
    Runtime.debugTransitions.move_block = nil

    local moveInterval = Runtime.comboActive and 0.04 or MOVE_ORDER_INTERVAL
    if ctx.now - Runtime.lastMoveOrderAt < moveInterval then
        return
    end

    local invokerQueueHold = Runtime.pending ~= nil or #Runtime.actionQueue > 0
    if SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_invoker" then
        local status = Core.InvokerController.Status(ctx)
        Runtime.invokerFsm = status
        if Runtime.invokerAwaitSpell and status.phase == "waitSlot" then
            invokerQueueHold = true
        end
    end

    local issued = false
    if Runtime.comboActive and hasEnemy and #Runtime.actionQueue > 0 then
        EnsureCtxEnemy(ctx)
        local head = Runtime.actionQueue[1]
        if head then
            PrepareActionForExecution(ctx, head)
        end
        local targetPos = head and GetActionTargetPos(ctx, head) or nil
        if not targetPos and moveEnemy then
            targetPos = SafeValue(Entity.GetAbsOrigin, moveEnemy)
        end
        if targetPos then
            local range = head and head.ability and GetCastRange(ctx.controlled, head.ability) or GetAttackRange(ctx.controlled)
            local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
            if myPos then
                local dist = Dist2D(myPos, targetPos)
                if head and head.kind == "iceWall" then
                    local enemyPos = ctx.enemy and SafeValue(Entity.GetAbsOrigin, ctx.enemy)
                    local enemyDist = enemyPos and Dist2D(myPos, enemyPos) or math.huge
                    local faceTime = SafeValue(NPC.GetTimeToFacePosition, ctx.controlled, targetPos)
                    if enemyPos and (enemyDist < 95 or enemyDist > 620) then
                        local setupPos
                        if enemyDist > 0.001 then
                            setupPos = enemyPos:Extend2D(myPos, enemyDist < 95 and 220 or 550)
                        else
                            local rotation = SafeValue(Entity.GetRotation, ctx.controlled)
                            local forward = rotation and rotation:GetForward()
                            if forward then
                                setupPos = Vector(
                                    enemyPos.x - forward.x * 220,
                                    enemyPos.y - forward.y * 220,
                                    enemyPos.z
                                )
                            end
                        end
                        if setupPos then
                            DbgVerbose("event", "ice_wall setup | enemyDist=%.0f | %s",
                                enemyDist, FormatRangeContext(ctx))
                            issued = IssueMoveToPosition(ctx, setupPos, "ice_wall_setup")
                        end
                    elseif type(faceTime) ~= "number" or faceTime > 0.08 then
                        DbgVerbose("event", "ice_wall side face | enemyDist=%.0f face=%.3f | %s",
                            enemyDist, type(faceTime) == "number" and faceTime or -1, FormatRangeContext(ctx))
                        issued = IssueMoveToPosition(ctx, targetPos, "ice_wall_face")
                    end
                else
                    local deferUltForTrample = head
                        and head.abilityId == "primal_beast_pulverize"
                        and IsPrimalBeastTrampling(ctx.controlled)
                    local enterDist = math.max(range - RANGE_CAST_BUFFER, 80)
                    if not deferUltForTrample and dist > enterDist + RANGE_TOLERANCE then
                        DbgVerbose("event",
                            "combo_approach | dist=%.0f need<=%d action=%s | %s",
                            dist,
                            math.floor(enterDist + RANGE_TOLERANCE),
                            head and head.abilityId or "?",
                            FormatRangeContext(ctx)
                        )
                        issued = IssueMoveToPosition(ctx, targetPos:Extend2D(myPos, enterDist), "combo_approach")
                    end
                end
            end
        end
    end

    if not issued and hasEnemy then
        local trampling = IsPrimalBeastTrampling(ctx.controlled)
        local head = Runtime.actionQueue[1]
        local deferUltForTrample = trampling
            and head
            and head.abilityId == "primal_beast_pulverize"
        local blockAttack = Runtime.comboActive
            and (Runtime.pending
                or SafeValue(NPC.IsChannellingAbility, ctx.controlled)
                or invokerQueueHold
                or (queueBlocksMove and not trampling and not deferUltForTrample))
        if trampling and Runtime.comboActive and (not blockAttack or deferUltForTrample) then
            DbgVerbose("move_tick", "trample orbit | %s", FormatRangeContext(ctx))
            issued = WithMovementEnemy(ctx, function(moveCtx)
                return IssueTrampleOrbit(moveCtx, "trample_orbit")
            end)
        elseif not blockAttack then
            DbgVerbose("move_tick", "attack enemy | %s", FormatRangeContext(ctx))
            issued = WithMovementEnemy(ctx, function(moveCtx)
                return IssueEnemyAttack(moveCtx, "attack")
            end)
        elseif IsDebugVerbose() then
            DbgVerbose("move_skip", "combo blocks attack | %s", FormatRangeContext(ctx))
        end
    elseif ShouldFollowCursor(ctx) and not invokerQueueHold then
        local cursorPos = Input and SafeValue(Input.GetWorldCursorPos)
        if cursorPos then
            local followReady = ctx.now - (Runtime.lastFollowOrderAt or 0) >= 0.12
            local followPos = Runtime.lastFollowPos
            if followPos and Dist2D(followPos, cursorPos) < 90 then
                followReady = false
            end
            if followReady then
                DbgVerbose("move_tick", "follow cursor | %s", FormatRangeContext(ctx))
                issued = IssueMoveToPosition(ctx, cursorPos, "follow")
                if issued then
                    Runtime.lastFollowOrderAt = ctx.now
                    Runtime.lastFollowPos = cursorPos
                end
            end
        end
    elseif Runtime.comboActive and IsDebugVerbose() then
        DbgVerbose("move_idle", "combo hold (no follow) | %s", FormatRangeContext(ctx))
    end

    if issued then
        Runtime.lastMoveOrderAt = ctx.now
    end
end

local function ProcessCombo(ctx)
    EnsureCtxEnemy(ctx)

    local pending = Runtime.pending
    local invokerChain = false
    if pending then
        local deadline = pending.deadline
        local lastAttempt = pending.lastAttempt
        local attempts = pending.attempts or 0
        local tag = pending.tag
        local abilityId = pending.abilityId

        if deadline and ctx.now >= deadline then
            local stillChanneling = false
            if pending.ability and ctx.controlled then
                local chBehavior = SafeValue(Ability.GetBehavior, pending.ability, true)
                    or SafeValue(Ability.GetBehavior, pending.ability, false) or 0
                if HasAbilityBehaviorFlag(chBehavior, BEH.DOTA_ABILITY_BEHAVIOR_CHANNELLED) then
                    if SafeValue(Ability.IsChannelling, pending.ability)
                        or SafeValue(NPC.IsChannellingAbility, ctx.controlled) then
                        local channel = SafeValue(NPC.GetChannellingAbility, ctx.controlled)
                        if channel == pending.ability or SafeValue(Ability.IsChannelling, pending.ability) then
                            stillChanneling = true
                        end
                    end
                end
            end
            if stillChanneling and ctx.now < (pending.absoluteDeadline or deadline) then
                pending.deadline = math.min(ctx.now + 0.75, pending.absoluteDeadline or (ctx.now + 0.75))
            else
                local recoveredInvoke = false
                if abilityId == "invoker_invoke" and ctx.controlled and Runtime.invokerAwaitSpell then
                    local spell = FindInvokerBarSpell(ctx.controlled, Runtime.invokerAwaitSpell)
                    if spell and GetAbilityId(spell) == Runtime.invokerAwaitSpell then
                        recoveredInvoke = true
                        Runtime.invokerLastInvokeAt = ctx.now
                        Runtime.nextComboAt = ctx.now + INVOKER_SPELL_GAP
                        ResetPending()
                    else
                        Runtime.invokerAwaitSpell = nil
                    end
                end
                if not recoveredInvoke then
                    local isOrbTag = tag and tag:sub(1, 12) == "invoker_orb_"
                    local linkBlocked = ctx.enemy
                        and TargetNeedsLinkBreak(ctx.enemy)
                        and (
                            Core.Catalog.DisableModifiers[abilityId]
                            or Core.Catalog.HexAbilities[abilityId]
                        )
                    DbgImportant("action timeout | %s", tag or "?")
                    if abilityId and pending.ability then
                        local liveBeh = SafeValue(Ability.GetBehavior, pending.ability, false)
                        local staticBeh = SafeValue(Ability.GetBehavior, pending.ability, true)
                        local cd = SafeValue(Ability.GetCooldown, pending.ability)
                        local exec = SafeValue(Ability.CanBeExecuted, pending.ability)
                        local execLabel = tostring(exec)
                        if exec == ABILITY_CAST_READY then
                            execLabel = "READY"
                        end
                        DbgImportant(
                            "timeout detail | %s liveBeh=%s staticBeh=%s cd=%.2f exec=%s point=%s",
                            abilityId,
                            tostring(liveBeh),
                            tostring(staticBeh),
                            type(cd) == "number" and cd or -1,
                            execLabel,
                            tostring(AbilityNeedsPointCast(pending.ability, abilityId))
                        )
                    end
                    if not isOrbTag and not linkBlocked then
                        MarkActionFailed(abilityId or tag, ctx.now)
                        Core.ActionRunner.DropDependents(abilityId)
                    elseif linkBlocked then
                        DbgImportant("skip fail mark | linkens blocked %s", abilityId or tag or "?")
                    end
                    if abilityId == "invoker_invoke" then
                        Runtime.invokerAwaitSpell = nil
                    end
                    ResetPending()
                end
            end
        elseif ConfirmAction(ctx, pending) then
            DbgImportant("confirmed | %s", tag or "?")
            Runtime.comboTrace[#Runtime.comboTrace + 1] = abilityId or tag or "?"
            if abilityId then
                local isInvokerOrb = abilityId == "invoker_quas" or abilityId == "invoker_wex"
                    or abilityId == "invoker_exort" or abilityId == "invoker_invoke"
                if not isInvokerOrb then
                    if abilityId == "item_refresher" then
                        Runtime.usedActions = { item_refresher = true }
                        Runtime.failedActions = {}
                        Runtime.actionQueue = {}
                        Runtime.invokerAwaitSpell = nil
                        DbgImportant("refresher confirmed | combo actions reset")
                    else
                        if not Core.Catalog.ReusableComboAbilities[abilityId] then
                            MarkActionUsed(abilityId)
                        end
                        if abilityId:find("blink", 1, true) then
                            Runtime.nextComboAt = ctx.now + BLINK_SETTLE
                            Core.DropNevermoreRazesFromQueue("post_blink")
                        end
                    end
                    if abilityId == Runtime.invokerAwaitSpell then
                        Runtime.invokerAwaitSpell = nil
                    end
                end
            end
            if abilityId == "invoker_invoke" then
                Runtime.invokerLastInvokeAt = ctx.now
                Runtime.actionQueue = {}
                Runtime.snapshotInvalidated = true
            end
            if abilityId == "morphling_replicate" or abilityId == "morphling_morph" then
                if ctx.enemy then
                    Runtime.morphSourceUnitName = SafeValue(NPC.GetUnitName, ctx.enemy)
                end
                local morphAbility = pending.ability
                local altCast = morphAbility and SafeValue(Ability.GetAltCastState, morphAbility) == true
                Runtime.morphAwaitReplicate = altCast == true
                Runtime.morphFormPending = not altCast
                Runtime.morphFormPendingAt = (not altCast) and ctx.now or nil
                Runtime.morphAwaitReplicateAt = altCast and ctx.now or nil
                Runtime.usedActions["morphling_morph_replicate"] = nil
                Runtime.failedActions["morphling_morph_replicate"] = nil
                Runtime.actionQueue = {}
                Runtime.snapshotInvalidated = true
                Runtime.syncedInventorySig = nil
                DbgImportant(
                    "morph cast | source=%s alt=%s awaitAbsorb=%s",
                    Runtime.morphSourceUnitName or "?",
                    tostring(altCast),
                    tostring(Runtime.morphAwaitReplicate)
                )
            end
            if abilityId == "morphling_morph_replicate" then
                Runtime.morphAwaitReplicate = false
                Runtime.morphAwaitReplicateAt = nil
                Runtime.morphFormPending = true
                Runtime.morphFormPendingAt = ctx.now
                Runtime.actionQueue = {}
                Runtime.snapshotInvalidated = true
                Runtime.syncedInventorySig = nil
                DbgImportant(
                    "morph toggle | tag=%s source=%s",
                    pending.tag or "morphling_morph_replicate",
                    Runtime.morphSourceUnitName or "?"
                )
            end
            if SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_invoker" then
                local prepTag = pending.tag or ""
                local prep = prepTag:sub(1, 12) == "invoker_orb_"
                local fastChain = abilityId == "invoker_invoke"
                if not fastChain and abilityId then
                    for ci = 1, #Core.Catalog.InvokerSteps do
                        if Core.Catalog.InvokerSteps[ci].id == abilityId then
                            fastChain = true
                            break
                        end
                    end
                end
                if prep or fastChain then
                    Runtime.nextComboAt = nil
                    invokerChain = true
                else
                    Runtime.nextComboAt = ctx.now + INVOKER_SPELL_GAP
                end
            end
            if abilityId == "sniper_shrapnel" and ctx.enemy then
                Runtime.shrapnelLastCastAt = ctx.now
                Runtime.shrapnelLastEnemy = ctx.enemy
                Runtime.shrapnelLastPos = pending.position
                    or SafeValue(Entity.GetAbsOrigin, ctx.enemy)
            end
            ResetPending()
        elseif pending.orderAck then
            local castPoint = SafeValue(Ability.GetCastPoint, pending.ability, true) or 0
            local faceTime = GetFaceTimeToAction(ctx, pending)
            local settleFor = math.max(
                ORDER_ACK_RETRY_DELAY,
                castPoint + faceTime + 0.25
            )
            if ctx.now - (pending.ackAt or pending.startedAt) < settleFor then
                DbgVerbose("cast_wait", "order ack settle | %s | %s", tag or "?", FormatRangeContext(ctx))
            elseif faceTime > 0.05
                or SafeValue(NPC.IsRunning, ctx.controlled)
                or SafeValue(NPC.IsAttacking, ctx.controlled)
            then
                -- Re-issuing CAST while turning/moving cancels zero-cast-point hexes.
                DbgVerbose("cast_wait", "face/move settle | %s face=%.2f | %s",
                    tag or "?", faceTime, FormatRangeContext(ctx))
                if pending.deadline and pending.deadline < ctx.now + faceTime + 0.35 then
                    pending.deadline = math.min(
                        (pending.absoluteDeadline or (ctx.now + ACTION_TIMEOUT)),
                        ctx.now + faceTime + 0.45
                    )
                end
            elseif pending.ability and (
                SafeValue(Ability.IsInAbilityPhase, pending.ability)
                or (SafeValue(NPC.IsChannellingAbility, ctx.controlled)
                    and SafeValue(NPC.GetChannellingAbility, ctx.controlled) == pending.ability)
            ) then
                DbgVerbose("cast_wait", "phase/channel | %s | %s", tag or "?", FormatRangeContext(ctx))
            elseif ctx.canCast and lastAttempt
                and ctx.now - lastAttempt >= ACTION_RETRY_INTERVAL and attempts < MAX_ACTION_ATTEMPTS then
                if IsWithinCastRange(ctx, pending) then
                    if Core.Catalog.HexAbilities[abilityId] and attempts >= 1 then
                        pending.forcePointCast = true
                    end
                    Core.ActionRunner.PrepareRetry(pending, ctx.now)
                    local retryResult = ExecuteAction(ctx, pending)
                    if retryResult == true then
                        pending.status = "issued"
                    end
                end
            end
        elseif pending.ability and (
            SafeValue(Ability.IsInAbilityPhase, pending.ability)
            or (SafeValue(NPC.IsChannellingAbility, ctx.controlled)
                and SafeValue(NPC.GetChannellingAbility, ctx.controlled) == pending.ability)
        ) then
            DbgVerbose("cast_wait", "phase/channel | %s | %s", tag or "?", FormatRangeContext(ctx))
        elseif ctx.canCast and lastAttempt
            and ctx.now - lastAttempt >= ACTION_RETRY_INTERVAL and attempts < MAX_ACTION_ATTEMPTS then
            if IsWithinCastRange(ctx, pending) then
                if Core.Catalog.HexAbilities[abilityId] and attempts >= 1 then
                    pending.forcePointCast = true
                end
                Core.ActionRunner.PrepareRetry(pending, ctx.now)
                local retryResult = ExecuteAction(ctx, pending)
                if retryResult == true then
                    pending.status = "issued"
                end
            end
        end
        if not invokerChain then
            return
        end
    end

    if not ctx.canCast then
        return
    end

    if Runtime.nextComboAt and ctx.now < Runtime.nextComboAt then
        return
    end

    if SafeValue(NPC.IsChannellingAbility, ctx.controlled) and not Runtime.pending and not invokerChain then
        return
    end

    if #Runtime.actionQueue == 0 then
        local unitName = SafeValue(NPC.GetUnitName, ctx.controlled)
        ClearUsedActionsWhenReady(ctx)
        if unitName ~= "npc_dota_hero_invoker" and ctx.now < (Runtime.emptyPlanUntil or 0) then
            return
        end
        Runtime.actionQueue = Core.GenericPlanner.Build(ctx)
        if #Runtime.actionQueue == 0 and unitName ~= "npc_dota_hero_invoker" then
            Runtime.emptyPlanUntil = ctx.now + 0.12
        else
            Runtime.emptyPlanUntil = 0
        end
        if IsDebugVerbose() then
            Core.DbgEvent(
                "plan | count=%d [%s] | %s",
                #Runtime.actionQueue,
                Core.FormatPlanPreview(Runtime.actionQueue, 8),
                FormatRangeContext(ctx)
            )
        end
    end

    while #Runtime.actionQueue > 0 do
        local action = Runtime.actionQueue[1]
        action = Core.ActionRunner.Normalize(action)
        if not action or not action.ability then
            Core.DbgEvent("queue drop | invalid head %s | %s",
                Core.FormatActionPreview(action), FormatRangeContext(ctx))
            table.remove(Runtime.actionQueue, 1)
            goto continue_queue
        end
        local castable = SafeValue(Ability.IsCastable, action.ability, ctx.mana)
            or SafeValue(Ability.CanBeExecuted, action.ability) == ABILITY_CAST_READY
        if not castable and action.abilityId and ctx.controlled and Runtime.invokerLastInvokeAt
            and Runtime.invokerLastInvokeAt > 0 then
            local invokeAge = ctx.now - Runtime.invokerLastInvokeAt
            if invokeAge >= INVOKER_INVOKE_SETTLE and invokeAge < 0.45 then
                for ci = 1, #Core.Catalog.InvokerSteps do
                    if Core.Catalog.InvokerSteps[ci].id == action.abilityId then
                        local slotSpell = FindInvokerBarSpell(ctx.controlled, action.abilityId)
                        if slotSpell and GetAbilityId(slotSpell) == action.abilityId then
                            action.ability = slotSpell
                            castable = true
                        end
                        break
                    end
                end
            end
        end
        if not castable then
            local keepQueued = false
            local tag = action.tag or ""
            if tag:sub(1, 12) == "invoker_orb_" or action.abilityId == "invoker_invoke" then
                keepQueued = true
            elseif action.abilityId then
                for ci = 1, #Core.Catalog.InvokerSteps do
                    if Core.Catalog.InvokerSteps[ci].id == action.abilityId then
                        keepQueued = true
                        break
                    end
                end
            end
            if not keepQueued then
                local cd = SafeValue(Ability.GetCooldown, action.ability)
                Core.DbgEvent(
                    "queue drop | notCastable %s cd=%.1f | %s",
                    Core.FormatActionPreview(action),
                    type(cd) == "number" and cd or -1,
                    FormatRangeContext(ctx)
                )
                if action.abilityId and action.abilityId:find("blink", 1, true) then
                    MarkActionUsed(action.abilityId)
                    Core.ActionRunner.DropDependents(action.abilityId)
                end
                table.remove(Runtime.actionQueue, 1)
                goto continue_queue
            end
            break
        end
        if action.kind == "lockedEnemy" and not ctx.enemy then
            EnsureCtxEnemy(ctx)
            if not ctx.enemy then
                table.remove(Runtime.actionQueue, 1)
                goto continue_queue
            end
        end
        if action.kind == "linkbreak" and (not ctx.enemy or not TargetNeedsLinkBreak(ctx.enemy)) then
            if action.abilityId then
                MarkActionUsed(action.abilityId)
            end
            table.remove(Runtime.actionQueue, 1)
            goto continue_queue
        end
        if not PrepareActionForExecution(ctx, action) then
            table.remove(Runtime.actionQueue, 1)
            goto continue_queue
        end
        if action.kind ~= "noTarget" and not IsWithinCastRange(ctx, action) then
            -- Blink in for Pulverize when still out of grab range.
            if action.abilityId == "primal_beast_pulverize"
                and not IsPrimalBeastTrampling(ctx.controlled)
                and ctx.enemy
            then
                local landPos, blink, blinkId = FindBlinkLandNearEnemy(ctx.controlled, ctx.enemy, 140)
                if blink and landPos and blinkId then
                    local blinkAction = {
                        kind = "bestPosition",
                        ability = blink,
                        abilityId = blinkId,
                        position = landPos,
                        tag = "primal_beast_pulverize_blink",
                    }
                    if PrepareActionForExecution(ctx, blinkAction) then
                        local pendingBlink = Core.ActionRunner.PreparePending(ctx, blinkAction)
                        blinkAction.identifier = pendingBlink.identifier
                        Runtime.pending = pendingBlink
                        local blinkResult = ExecuteAction(ctx, blinkAction)
                        if blinkResult then
                            pendingBlink.status = "issued"
                            DbgImportant("cast | %s | kind=bestPosition (ult initiate)", blinkId)
                            DbgVerbose("event",
                                "pulverize_blink | landDist=140 | %s",
                                FormatRangeContext(ctx)
                            )
                            return
                        end
                        Runtime.pending = nil
                        MarkActionFailed(blinkId, ctx.now)
                    end
                end
            end
            local targetPos = GetActionTargetPos(ctx, action)
            local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
            local castRange = GetCastRange(ctx.controlled, action.ability)
            local dist = myPos and targetPos and Dist2D(myPos, targetPos) or -1
            if action.kind == "iceWall" then
                local enemyPos = ctx.enemy and SafeValue(Entity.GetAbsOrigin, ctx.enemy)
                dist = myPos and enemyPos and Dist2D(myPos, enemyPos) or -1
                castRange = 620
            end
            DbgVerbose("event",
                "skip_range | %s kind=%s dist=%.0f castRange=%d | %s",
                action.abilityId or "?",
                action.kind or "?",
                dist,
                castRange,
                FormatRangeContext(ctx)
            )
            break
        end

        -- Finish Trample orbit before Pulverize channel.
        -- If still far, blink closer first so stomps and the eventual grab land.
        if action.abilityId == "primal_beast_pulverize"
            and IsPrimalBeastTrampling(ctx.controlled) then
            if ctx.enemy then
                local myPos = SafeValue(Entity.GetAbsOrigin, ctx.controlled)
                local enemyPos = SafeValue(Entity.GetAbsOrigin, ctx.enemy)
                local castRange = GetCastRange(ctx.controlled, action.ability)
                if castRange <= 0 then
                    castRange = 200
                end
                local dist = myPos and enemyPos and Dist2D(myPos, enemyPos) or 0
                if dist > castRange + 80 then
                    local landPos, blink, blinkId = FindBlinkLandNearEnemy(ctx.controlled, ctx.enemy, 140)
                    if blink and landPos and blinkId then
                        local blinkAction = {
                            kind = "bestPosition",
                            ability = blink,
                            abilityId = blinkId,
                            position = landPos,
                            tag = "primal_beast_pulverize_blink",
                        }
                        if PrepareActionForExecution(ctx, blinkAction) then
                            local pendingBlink = Core.ActionRunner.PreparePending(ctx, blinkAction)
                            blinkAction.identifier = pendingBlink.identifier
                            Runtime.pending = pendingBlink
                            local blinkResult = ExecuteAction(ctx, blinkAction)
                            if blinkResult then
                                pendingBlink.status = "issued"
                                DbgImportant("cast | %s | kind=bestPosition (trample close)", blinkId)
                                return
                            end
                            Runtime.pending = nil
                            MarkActionFailed(blinkId, ctx.now)
                        end
                    end
                end
            end
            DbgVerbose("event",
                "skip_ult | pulverize waits for trample end | %s",
                FormatRangeContext(ctx)
            )
            break
        end

        if (action.kind == "lockedEnemy" or action.kind == "linkbreak")
            and ctx.enemy
            and action.abilityId
            and (Core.Catalog.DisableModifiers[action.abilityId]
                or Core.Catalog.HexAbilities[action.abilityId])
            and not ShouldCastDisable(ctx, ctx.enemy, action.abilityId, action.ability)
        then
            DbgVerbose("event",
                "skip_disable | %s | wait/extend active cc | %s",
                action.abilityId or "?",
                FormatRangeContext(ctx)
            )
            break
        end
        if (action.kind == "lockedEnemy" or action.kind == "linkbreak")
            and not EnsureUnitIdleForCast(ctx)
        then
            DbgImportant("cast wait idle | %s", action.abilityId or "?")
            return
        end
        local pendingAction = Core.ActionRunner.PreparePending(ctx, action)
        action.identifier = pendingAction.identifier
        Runtime.pending = pendingAction
        if action.abilityId
            and action.abilityId:find("nevermore_shadowraze", 1, true)
        then
            local razeReady = Core.EnsureNevermoreRazeReady(ctx, action)
            if razeReady == "drop" then
                Runtime.pending = nil
                table.remove(Runtime.actionQueue, 1)
                return
            end
            if razeReady ~= true then
                Runtime.pending = nil
                return
            end
        end
        local result = ExecuteAction(ctx, action)
        if result then
            pendingAction.status = "issued"
            table.remove(Runtime.actionQueue, 1)
            DbgImportant("cast | %s | kind=%s prio=%d",
                action.abilityId or "?",
                action.kind or "?",
                type(action.priority) == "number" and action.priority or 0)
            Core.DbgEvent("cast_detail | %s | %s", Core.FormatActionPreview(action), FormatRangeContext(ctx))
            return
        end
        Runtime.pending = nil
        MarkActionFailed(action.abilityId or action.tag, ctx.now)
        Core.ActionRunner.DropDependents(action.abilityId)
        table.remove(Runtime.actionQueue, 1)
        ::continue_queue::
    end
end

--#endregion

--#region Menu

local function UpdateControlStates()
    local enabled = UI.Enabled and UI.Enabled:Get()
    local widgets = {
        UI.AllyHero,
        UI.Abilities,
        UI.Items,
        UI.TargetMode,
        UI.MinClusterHits,
        UI.ManaThreshold,
        UI.ExtendDisables,
        UI.UseLinkBreak,
        UI.Debug,
        UI.DebugVerbose,
        UI.DrawOverlay,
    }

    for i = 1, #widgets do
        local widget = widgets[i]
        if widget and widget.Disabled then
            widget:Disabled(not enabled)
        end
    end

    if UI.DebugVerbose and UI.DebugVerbose.Disabled then
        local debugOn = UI.Debug and UI.Debug:Get()
        UI.DebugVerbose:Disabled(not enabled or not debugOn)
    end
end

local function InitializeMenu()
    local group = Menu.Find("Heroes", "", "Settings", "General", "Units Controller")
    if not group then
        error(LOG_PREFIX .. "Units Controller menu group not found")
    end

    local ui = {}

    ui.Enabled = group:Switch(L("Control Ally", "Control Ally"), LoadConfigInt("enabled", 0) == 1, Icons.enable)
    ui.Enabled:ToolTip(L(
        "Control a controllable allied hero while your hero Combo Key is held.",
        "Управление союзником при удержании Combo Key вашего героя (Heroes > Settings > Units Controller)."
    ))

    ui.AllyHero = group:MultiSelect(L("Ally Hero", "Союзный герой"), {}, true)
    MenuIcon(ui.AllyHero, Icons.hero)
    if ui.AllyHero.OneItemSelection then
        ui.AllyHero:OneItemSelection(true)
    end
    if ui.AllyHero.DragAllowed then
        ui.AllyHero:DragAllowed(false)
    end
    ui.AllyHero:ToolTip(L(
        "Pick which controllable allied hero to command.",
        "Выберите союзного героя под вашим контролем."
    ))

    ui.Abilities = group:MultiSelect(L("Abilities", "Способности"), {}, true)
    MenuIcon(ui.Abilities, Icons.abilities)
    ui.Abilities:ToolTip(L(
        "Toggle which abilities the ally may cast in combo.",
        "Какие способности союзник может использовать в комбо."
    ))

    ui.Items = group:MultiSelect(L("Items", "Предметы"), {}, true)
    MenuIcon(ui.Items, Icons.items)
    ui.Items:ToolTip(L(
        "Toggle which items the ally may use. Buffs/dispels go to your hero.",
        "Какие предметы использовать. Бафы/развеивание — на вашего героя."
    ))

    ui.Abilities:SetCallback(function()
        local widget = UI.Abilities
        if not widget or not widget.List then
            return
        end
        local listed = SafeValue(widget.List, widget)
        if type(listed) ~= "table" then
            return
        end
        for i = 1, #listed do
            local id = listed[i]
            if id and id ~= "none" then
                local val = SafeValue(widget.Get, widget, id)
                if val ~= nil then
                    SaveConfigInt("abl_" .. id, val == true and 1 or 0)
                end
            end
        end
    end, false)

    ui.Items:SetCallback(function()
        local widget = UI.Items
        if not widget or not widget.List then
            return
        end
        local listed = SafeValue(widget.List, widget)
        if type(listed) ~= "table" then
            return
        end
        for i = 1, #listed do
            local id = listed[i]
            if id and id ~= "none" then
                local val = SafeValue(widget.Get, widget, id)
                if val ~= nil then
                    SaveConfigInt("itm_" .. id, val == true and 1 or 0)
                end
            end
        end
    end, false)

    local gear = ui.Enabled:Gear(L("Settings", "Настройки"), Icons.gear, true)

    ui.TargetMode = gear:Combo(L("Target Mode", "Режим цели"), TARGET_MODE_ITEMS, LoadConfigInt("target_mode", 0))
    MenuIcon(ui.TargetMode, Icons.target)
    ui.TargetMode:ToolTip(L(
        "Cursor: lock/switch only within 100–300 of mouse (world). Auto Score: threat/cluster. Overrides Heroes Style.",
        "Cursor: лок/смена только в радиусе 100–300 от мыши (мир). Auto Score: угроза/кластер. Приоритет над Style в Heroes."
    ))

    ui.MinClusterHits = gear:Slider(L("Min AOE hits", "Мин. AOE попаданий"), 1, 5, LoadConfigInt("min_cluster", 2), "%d")
    MenuIcon(ui.MinClusterHits, Icons.hits)

    ui.ManaThreshold = gear:Slider(L("Min Mana %", "Мин. MP %"), 0, 100, LoadConfigInt("mana_pct", 15), "%d%%")
    MenuIcon(ui.ManaThreshold, Icons.mana)

    ui.ExtendDisables = gear:Switch(L("Extend disables", "Продлевать контроль"), LoadConfigInt("extend", 1) == 1, Icons.extend)
    ui.ExtendDisables:ToolTip(L(
        "Chain disables when remaining CC is about to expire.",
        "Кастовать следующий контроль перед окончанием текущего."
    ))

    ui.UseLinkBreak = gear:Switch(L("Use Linken's break", "Сбивать Linken's"), LoadConfigInt("linkbreak", 1) == 1, Icons.link)

    ui.Debug = gear:Switch(L("Debug logs", "Debug логи"), LoadConfigInt("debug", 0) == 1)
    MenuIcon(ui.Debug, Icons.bug)

    ui.DebugVerbose = gear:Switch(L("Verbose range debug", "Подробный debug дистанции"), LoadConfigInt("debug_verbose", 0) == 1)
    MenuIcon(ui.DebugVerbose, Icons.bug)
    ui.DebugVerbose:ToolTip(L(
        "Requires Debug logs. Unthrottled plan/cast events with priorities (@N), skip reasons (sf_plan, initiate_blink, queue drop), plus throttled move/attack range ticks.",
        "Нужен Debug логи. Без троттла: plan/cast с приоритетами (@N), причины skip (sf_plan, initiate_blink, queue drop); плюс троттл-тики атаки/дистанции."
    ))

    ui.DrawOverlay = gear:Switch(L("Draw overlay", "Оверлей"), LoadConfigInt("draw_overlay", 1) == 1, Icons.draw)

    ui.Enabled:SetCallback(function()
        if not ui.Enabled then
            return
        end
        SaveConfigInt("enabled", ui.Enabled:Get() and 1 or 0)
        UpdateControlStates()
    end, true)

    ui.TargetMode:SetCallback(function()
        if not ui.TargetMode then
            return
        end
        SaveConfigInt("target_mode", ui.TargetMode:Get())
    end, true)

    ui.MinClusterHits:SetCallback(function()
        if not ui.MinClusterHits then
            return
        end
        SaveConfigInt("min_cluster", ui.MinClusterHits:Get())
    end, true)

    ui.ManaThreshold:SetCallback(function()
        if not ui.ManaThreshold then
            return
        end
        SaveConfigInt("mana_pct", ui.ManaThreshold:Get())
    end, true)

    ui.ExtendDisables:SetCallback(function()
        if not ui.ExtendDisables then
            return
        end
        SaveConfigInt("extend", ui.ExtendDisables:Get() and 1 or 0)
    end, true)

    ui.UseLinkBreak:SetCallback(function()
        if not ui.UseLinkBreak then
            return
        end
        SaveConfigInt("linkbreak", ui.UseLinkBreak:Get() and 1 or 0)
    end, true)

    ui.Debug:SetCallback(function()
        if not ui.Debug then
            return
        end
        SaveConfigInt("debug", ui.Debug:Get() and 1 or 0)
        UpdateControlStates()
    end, true)

    ui.DebugVerbose:SetCallback(function()
        if not ui.DebugVerbose then
            return
        end
        SaveConfigInt("debug_verbose", ui.DebugVerbose:Get() and 1 or 0)
    end, true)

    ui.DrawOverlay:SetCallback(function()
        if not ui.DrawOverlay then
            return
        end
        SaveConfigInt("draw_overlay", ui.DrawOverlay:Get() and 1 or 0)
    end, true)

    ui.AllyHero:SetCallback(function()
        local playerId = Core.GetSelectedAllyPlayerIdFromUI()
        local entry = ResolveAllyEntryByPlayerId(playerId)
        local samePlayer = entry
            and type(entry.playerId) == "number"
            and entry.playerId == Runtime.selectedPlayerId
        -- Combo sticky: ignore AllyHero flicker onto another ally during Morph/transform.
        if Runtime.comboActive
            and type(Runtime.selectedPlayerId) == "number"
            and entry
            and type(entry.playerId) == "number"
            and entry.playerId ~= Runtime.selectedPlayerId
        then
            DbgImportant(
                "ally selection ignored during combo | keep=P%s ignore=P%s",
                tostring(Runtime.selectedPlayerId),
                tostring(entry.playerId)
            )
            if UI.AllyHero and UI.AllyHero.Set then
                SafeValue(UI.AllyHero.Set, UI.AllyHero, Core.AllyWidgetId(Runtime.selectedPlayerId), true)
            end
            return
        end
        if Runtime.sessionHero and entry and entry.hero ~= Runtime.sessionHero and not samePlayer then
            EndSession("ally selection changed")
        end
        if entry and type(entry.playerId) == "number" then
            SaveConfigInt("ally_player_id", entry.playerId)
            Runtime.selectedPlayerId = entry.playerId
        end
        if samePlayer and entry and entry.hero and Runtime.sessionHero ~= entry.hero then
            Runtime.sessionHero = entry.hero
            Runtime.snapshotInvalidated = true
        end
        Runtime.syncedAllyPlayerId = nil
        Runtime.syncedInventorySig = nil
        Runtime.syncedHeroName = nil
        Runtime.snapshotInvalidated = true
        Runtime.catalogCache = nil
        if entry and entry.hero then
            SyncAbilityItemWidgets(entry.hero, true)
        end
    end, false)

    UI = ui
    Persistent.ui = ui
    Persistent.menuReady = true
    UpdateControlStates()
end

local function EnsureMenu()
    if Persistent.menuReady then
        return
    end
    if not Menu or not Menu.Create then
        return
    end
    InitializeMenu()
end

--#endregion

--#region Overlay

local function DrawOverlay(snapshot)
    if not UI.DrawOverlay or not SafeValue(UI.DrawOverlay.Get, UI.DrawOverlay) then
        return
    end
    if not Render or not Render.Text or not Render.LoadFont then
        return
    end

    Persistent.overlayFont = Persistent.overlayFont or SafeValue(Render.LoadFont, "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500) or 0
    if Persistent.overlayFont == 0 then
        Persistent.overlayFont = SafeValue(Render.LoadFont, "Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500) or 0
    end
    local font = Persistent.overlayFont
    if not font or font == 0 then
        return
    end

    local lines = {}
    lines[#lines + 1] = string.format("Ally: %s", snapshot.allyName or "Unknown")
    if snapshot.targetName then
        lines[#lines + 1] = string.format("Target: %s", snapshot.targetName)
    end
    if snapshot.currentAction and snapshot.currentAction ~= "" then
        lines[#lines + 1] = "Current: " .. snapshot.currentAction
    end
    if snapshot.nextAction and snapshot.nextAction ~= "" then
        lines[#lines + 1] = "Next: " .. snapshot.nextAction
    end
    if snapshot.invokerPhase then
        lines[#lines + 1] = "Invoker: " .. snapshot.invokerPhase
    end

    local y = 120
    for i = 1, #lines do
        SafeValue(Render.Text, font, 14, lines[i], Vec2(20, y), Color(220, 230, 255, 230))
        y = y + 18
    end
end

Core.RuntimeAdapter.TryCall = TryCall
Core.RuntimeAdapter.SafeValue = SafeValue
Core.Snapshot.Build = BuildContext
Core.Targeting.Resolve = ResolveLockedEnemy
Core.Targeting.EnemiesNear = GetEnemiesNear
Core.AoeSolver.CountHits = CountHitsAt
Core.AoeSolver.FindBestPosition = FindBestAoePosition
Core.AoeSolver.FindBlinkPosition = FindBlinkPositionForAoe
Core.Catalog.GetAbilityId = GetAbilityId
Core.Catalog.GetAoeRadius = GetAoeRadius
Core.GenericPlanner.Build = BuildActionPlan
Core.ActionRunner.Confirm = ConfirmAction
Core.ActionRunner.Process = ProcessCombo
Core.MovementController.Process = ProcessMovement
Core.Settings.LoadInt = LoadConfigInt
Core.Settings.SaveInt = SaveConfigInt
Core.Settings.GetUI = function()
    return UI
end
Core.Overlay.Draw = DrawOverlay

--#endregion

--#region Lifecycle

function Script.OnGameEnd()
    EndSession("game end")
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastAllyScanAt = -math.huge
    Runtime.lastTargetResolveAt = -math.huge
    Runtime.lastMultiSyncAt = -math.huge
    Runtime.lastBuiltinSyncAt = -math.huge
    Runtime.controllableAllies = {}
    Runtime.sessionHero = nil
    Runtime.localHero = nil
    Runtime.localPlayer = nil
    Runtime.localPlayerId = nil
    Runtime.selectedPlayerId = nil
    Runtime.lockedEnemy = nil
    Runtime.lockedEnemyScore = nil
    Runtime.actionQueue = {}
    Runtime.syncedHeroName = nil
    Runtime.syncedAllyPlayerId = nil
    Runtime.syncedAllyRosterSig = nil
    Runtime.syncedInventorySig = nil
    Runtime.lastMoveOrderAt = -math.huge
    Runtime.lastAttackOrderAt = -math.huge
    Runtime.lastAttackTarget = nil
    Runtime.lastFollowOrderAt = -math.huge
    Runtime.lastFollowPos = nil
    Runtime.failedActions = {}
    Runtime.usedActions = {}
    Runtime.debugVerboseAt = {}
    Runtime.shrapnelLastCastAt = 0
    Runtime.shrapnelLastPos = nil
    Runtime.shrapnelLastEnemy = nil
    Runtime.comboReleaseAt = nil
    Runtime.nextComboAt = 0
    Runtime.invokerComboEnemy = nil
    Runtime.invokerLastInvokeAt = 0
    Runtime.invokerAwaitSpell = nil
    Runtime.invokerFsm = { phase = "selectStep", spellId = nil }
    Runtime.renderSnapshot = nil
    BuiltIn.comboKey = nil
    BuiltIn.lastHeroMenuName = nil
end

function Script.OnScriptsLoaded()
    Persistent.logger = Logger("ControlAlly")
    EnsureMenu()
    Persistent.logger:info("loaded")
end

function Script.OnUpdate()
    if not SafeValue(Engine.IsInGame) then
        if Runtime.comboActive or Runtime.pending then
            EndSession("not in game")
        end
        return
    end

    EnsureMenu()
    if not UI.Enabled or not UI.Enabled:Get() then
        if Runtime.comboActive or Runtime.pending then
            EndSession("disabled")
        end
        return
    end
    if SafeValue(Input.IsInputCaptured) then
        if Runtime.comboActive or Runtime.pending then
            EndSession("input captured")
        end
        return
    end

    local now = GetGameTime()
    local comboHeldEarly = IsComboKeyHeld()
    local tickInterval = comboHeldEarly and (UPDATE_INTERVAL * 0.75) or UPDATE_INTERVAL
    if now - Runtime.lastUpdateAt < tickInterval then
        return
    end
    Runtime.lastUpdateAt = now

    RefreshControllableAllies(now)
    SyncBuiltinWidgets(false)

    local comboHeld = IsComboKeyHeld()
    if not comboHeld then
        if Runtime.comboActive then
            if not Runtime.comboReleaseAt then
                Runtime.comboReleaseAt = now
            elseif now - Runtime.comboReleaseAt >= COMBO_RELEASE_GRACE then
                EndSession("bind released")
            end
        else
            Runtime.comboReleaseAt = nil
        end
        Runtime.comboKeyHeldPrev = false
        return
    end

    Runtime.comboReleaseAt = nil
    Runtime.comboForceResolve = not Runtime.comboKeyHeldPrev
    if not Runtime.comboKeyHeldPrev then
        Runtime.comboTrace = {}
        Runtime.comboStartedAt = now
        Runtime.emptyPlanUntil = 0
    end
    Runtime.comboKeyHeldPrev = true
    Runtime.comboActive = true

    local ctx = Core.Snapshot.Build(now)
    Runtime.comboForceResolve = false
    if not ctx then
        Runtime.renderSnapshot = nil
        return
    end

    if Runtime.syncedAllyPlayerId ~= Runtime.selectedPlayerId then
        SyncAbilityItemWidgets(ctx.controlled, true)
    elseif now - Runtime.lastMultiSyncAt >= MULTISELECT_SYNC_INTERVAL then
        Runtime.lastMultiSyncAt = now
        SyncAbilityItemWidgets(ctx.controlled, false)
    end

    Core.ActionRunner.Process(ctx)
    Core.MovementController.Process(ctx)
    Runtime.renderSnapshot = {
        allyName = GetHeroDisplayName(SafeValue(NPC.GetUnitName, ctx.controlled)),
        targetName = ctx.enemy and GetHeroDisplayName(SafeValue(NPC.GetUnitName, ctx.enemy)) or nil,
        currentAction = Runtime.pending and string.format(
            "%s [%s%s]",
            Runtime.pending.tag or "?",
            Runtime.pending.status or "pending",
            Runtime.pending.orderAck and ", ack" or ""
        ) or "",
        nextAction = Runtime.actionQueue[1] and Runtime.actionQueue[1].tag or "",
        invokerPhase = SafeValue(NPC.GetUnitName, ctx.controlled) == "npc_dota_hero_invoker"
            and Runtime.invokerFsm.phase or nil,
    }
end

function Script.OnDraw()
    if not Persistent.menuReady or not UI.Enabled or not UI.Enabled:Get() then
        return
    end
    if not Runtime.comboActive then
        return
    end

    local snapshot = Runtime.renderSnapshot
    if snapshot then
        Core.Overlay.Draw(snapshot)
    end
end

function Script.OnEntityDestroy(entity)
    if entity == Runtime.sessionHero or entity == Runtime.localHero then
        EndSession("controlled entity destroyed")
    elseif entity == Runtime.lockedEnemy then
        if Runtime.pending and Runtime.pending.target == entity then
            EndSession("pending target destroyed")
        else
            Runtime.lockedEnemy = nil
            Runtime.lockedEnemyScore = nil
        end
    end
end

function Script.OnUnitInventoryUpdated(data)
    Runtime.snapshotInvalidated = true
    Runtime.catalogCache = nil
    Runtime.syncedInventorySig = nil
    Runtime.emptyPlanUntil = 0
end

function Script.OnSetDormant(npc, type)
    if type == Enum.DormancyType.ENTITY_NOT_DORMANT then
        return
    end
    if npc == Runtime.sessionHero then
        EndSession("controlled hero dormant")
    elseif npc == Runtime.localHero and Runtime.pending and Runtime.pending.target == npc then
        EndSession("local target dormant")
    elseif npc == Runtime.lockedEnemy then
        if Runtime.pending and Runtime.pending.target == npc then
            EndSession("pending target dormant")
        else
            Runtime.lockedEnemy = nil
            Runtime.lockedEnemyScore = nil
        end
    end
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    if IsOurOrder(data) then
        local id = data.identifier
        if Runtime.pending and id then
            local matches = id == Runtime.pending.identifier
                or (Runtime.pending.attemptIdentifiers
                    and Runtime.pending.attemptIdentifiers[id])
            if matches then
                Runtime.pending.orderAck = true
                if not Runtime.pending.ackAt then
                    Runtime.pending.ackAt = GetGameTime()
                end
            end
        end
        if IsDebugVerbose() and data then
            DbgVerbose("event","order_callback | id=%s", id or "?")
        end
    end
    return true
end

--#endregion

return Script
