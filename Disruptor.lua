--[[
    Disruptor Combo — Blink → Thunder Strike → Kinetic Field → Static Storm
    Glimpse is manual only (Glimpse Helper key). AOE + Target combo, items + Linkbreaker + Refresher.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local NAME = "Disruptor"
local HERO_TAB = "Disruptor"
local HERO_UNIT = "npc_dota_hero_disruptor"
local HERO_ICON = "panorama/images/heroes/icons/npc_dota_hero_disruptor_png.vtex_c"
local ORDER_PREFIX = "disruptor:"

local ABILITY = {
    thunder = "disruptor_thunder_strike",
    glimpse = "disruptor_glimpse",
    field = "disruptor_kinetic_field",
    fence = "disruptor_kinetic_fence",
    storm = "disruptor_static_storm",
    innate = "disruptor_electromagnetic_repulsion",
}

-- Disruptor combo helpers/constants (table methods avoid Lua 200-local chunk limit).
local DC = {
    Q_RANGE = 800,
    W_RANGE = 600,
    E_RANGE = 900,
    R_RANGE = 800,
    FIELD_RADIUS = 350,
    ---Fallback when Kinetic Field formation_time special is unavailable.
    PREDICT_LEAD = 1.05,
    Q_RANGE_MARGIN = 40,
    ---Default blink stand-off inside Thunder Strike range (slider absolute 550).
    BLINK_STANDOFF_DEFAULT = 550,
    GLIMPSE_LOOKBACK = 4.0,
    GLIMPSE_HISTORY_INTERVAL = 0.10,
    GLIMPSE_HISTORY_MAX = 50,
    DRAW_GLIMPSE_MARKER = 18,
    DRAW_GLIMPSE_ICON = 28,
    DRAW_CIRCLE_SEGMENTS = 64,
    DRAW_FENCE_ARC_DEG = 70,
    COMBO_STAGE_TIMEOUT = 8.0,
    BLINK_SETTLE_DEFAULT = 0.18,
    GLIMPSE_MANUAL_TIMEOUT = 6.0,
    ---Start 2nd cycle this many seconds before Kinetic Field timer ends (Q→E cast lead).
    FIELD_SECOND_CYCLE_LEAD = 0.85,
    ---GridNav.IsTraversable default masks (engine BLOCKED only).
    GRID_FLAG = 0x1,
    GRID_EXCLUDED = 0x002,
    ---Escape rays for wall-bias Field scoring.
    WALL_RAYS = 8,
    ---Target-mode nudge toward impassable (keeps target inside radius).
    TARGET_WALL_NUDGE = 0.35,
    ---Fence on Field rim (radius - margin).
    FENCE_RIM_MARGIN = 40,
}

local CAST_GAP = 0.08
local GLOBAL_ORDER_GAP = 0.06
local ATTACK_GAP = 0.35
local ORDER_QUEUE_MAX = 1
local DEBUG_HEARTBEAT = 0.50
---Throttle noisy wait/skip lines (cast/consumed stay one-shot).
local DEBUG_WAIT_HEARTBEAT = 1.0
-- Start combo this many seconds before Eul / invuln ends.
local TIMING_COMBO_LEAD = 0.55

-- Active damage-return effects checked when "Combo in Damage Return" is off.
local DAMAGE_RETURN_MODS = {
    "modifier_item_blade_mail_reflect",
    "modifier_nyx_assassin_spiked_carapace",
}

local I = {
    enable = "\u{f00c}",
    gear = "\u{f013}",
    comboKey = "\u{e1c1}",
    kissesAim = "\u{e59f}",
    aoeKey = "\u{e1c1}",
    targetKey = "\u{f05b}",
    glimpse = "\u{f06e}",
    drawGlimpse = "\u{f3c5}",
    drawTrajectory = "\u{f689}",
    onlyCastable = "\u{e2ca}",
    hits = "\u{f007}",
    abilities = "\u{f890}",
    itemsUsage = "\u{e196}",
    comboIndicator = "\u{e0c9}",
    itemsIndicator = "\u{f71c}",
    support = "\u{e05c}",
    conditions = "\u{f1de}",
    bars = "\u{f0c9}",
    onlyAttack = "\u{e41b}",
    useInStun = "\u{e3a5}",
    debug = "\u{f188}",
    damageReturn = "\u{f7a9}",
}

local LINKENS_ICON = "panorama/images/items/sphere_png.vtex_c"
local BLINK_ICON = "panorama/images/items/blink_png.vtex_c"
local NULLIFIER_ICON = "panorama/images/items/nullifier_png.vtex_c"

local ABILITY_ENTRIES = {
    { ABILITY.thunder, true },
    { ABILITY.field, true },
    { ABILITY.fence, true },
    { ABILITY.storm, true },
}

local ITEM_USAGE_GROUPS = {
    {
        widget = "Important Items",
        items = {
            "item_black_king_bar",
            "item_sheepstick",
            "item_nullifier",
            "item_abyssal_blade",
            "item_orchid",
            "item_bloodthorn",
            "item_satanic",
            "item_blink",
            "item_fallen_sky",
            "item_refresher",
        },
        defaultEnabled = {
            item_black_king_bar = true,
            item_sheepstick = true,
            item_nullifier = true,
            item_abyssal_blade = true,
            item_orchid = true,
            item_bloodthorn = true,
            item_satanic = true,
            item_blink = true,
            item_fallen_sky = true,
            item_refresher = true,
        },
    },
    {
        widget = "Semi-Important Items",
        items = {
            "item_bloodstone",
            "item_rod_of_atos",
            "item_gungir",
            "item_heavens_halberd",
            "item_harpoon",
            "item_veil_of_discord",
            "item_ethereal_blade",
            "item_dagon",
            "item_shivas_guard",
        },
        defaultEnabled = {
            item_bloodstone = true,
            item_rod_of_atos = true,
            item_gungir = true,
            item_heavens_halberd = true,
            item_harpoon = true,
            item_veil_of_discord = true,
            item_ethereal_blade = true,
            item_dagon = true,
            item_shivas_guard = true,
        },
    },
    {
        widget = "Other Items",
        items = {
            "item_diffusal_blade",
            "item_disperser",
            "item_mjollnir",
            "item_mask_of_madness",
            "item_armlet",
            "item_manta",
            "item_blade_mail",
            "item_silver_edge",
            "item_invis_sword",
            "item_phase_boots",
            "item_meteor_hammer",
            "item_blood_grenade",
        },
        defaultEnabled = {
            item_diffusal_blade = true,
            item_disperser = true,
            item_mjollnir = true,
            item_mask_of_madness = true,
            item_armlet = true,
            item_manta = true,
            item_blade_mail = true,
            item_silver_edge = true,
            item_invis_sword = true,
            item_phase_boots = true,
            item_meteor_hammer = true,
            item_blood_grenade = true,
        },
    },
    {
        widget = "Utility Items",
        items = {
            "item_soul_ring",
            "item_hurricane_pike",
            "item_ancient_janggo",
            "item_boots_of_bearing",
            "item_crimson_guard",
            "item_pipe",
            "item_urn_of_shadows",
            "item_essence_distiller",
            "item_spirit_vessel",
            "item_solar_crest",
            "item_mekansm",
            "item_guardian_greaves",
        },
        defaultEnabled = {
            item_soul_ring = true,
            item_hurricane_pike = true,
            item_ancient_janggo = true,
            item_boots_of_bearing = true,
            item_crimson_guard = true,
            item_pipe = true,
            item_urn_of_shadows = true,
            item_essence_distiller = true,
            item_spirit_vessel = true,
            item_solar_crest = true,
            item_mekansm = true,
            item_guardian_greaves = true,
        },
    },
    {
        widget = "Neutral Items",
        items = {
            "item_demonicon",
            "item_minotaur_horn",
            "item_heavy_blade",
            "item_spider_legs",
            "item_crippling_crossbow",
            "item_medallion_of_courage",
            "item_dagger_of_ristul",
            "item_essence_ring",
            "item_polliwog_charm",
            "item_kobold_cup",
            "item_jidi_pollen_bag",
            "item_flayers_bota",
            "item_ash_legion_shield",
            "item_idol_of_screeauk",
            "item_riftshadow_prism",
        },
        defaultEnabled = {
            item_demonicon = true,
            item_minotaur_horn = true,
            item_heavy_blade = true,
            item_spider_legs = true,
            item_crippling_crossbow = true,
            item_medallion_of_courage = true,
            item_dagger_of_ristul = true,
            item_essence_ring = true,
            item_polliwog_charm = true,
            item_kobold_cup = true,
            item_jidi_pollen_bag = true,
            item_flayers_bota = true,
            item_ash_legion_shield = true,
            item_idol_of_screeauk = true,
            item_riftshadow_prism = true,
        },
    },
}

local SUPPORT_ITEMS = {
    { id = "item_guardian_greaves", key = "Support Greaves" },
    { id = "item_boots_of_bearing", key = "Support Boots of Bearing" },
    { id = "item_pipe", key = "Support Pipe" },
    { id = "item_crimson_guard", key = "Support Crimson" },
}

local ONLY_ATTACK_WHEN_ACTIVE = {
    { "modifier_item_silver_edge_windwalk", true },
    { "modifier_item_invisibility_edge_windwalk", false },
    { "bounty_hunter_wind_walk_ally", false },
    { "modifier_rune_invis", false },
}

local USE_IN_STUN = {
    { "item_bloodthorn", true },
    { "item_orchid", false },
}

-- Hero skills first (cost 0), then items — cheapest ready pop wins.
local LINKBREAKER_ITEMS = {
    { "disruptor_thunder_strike", true },
    { "disruptor_glimpse", true },
    { "item_force_staff", true },
    { "item_rod_of_atos", true },
    { "item_diffusal_blade", true },
    { "item_cyclone", true },
    { "item_dagon", true },
    { "item_orchid", true },
    { "item_heavens_halberd", true },
    { "item_nullifier", true },
    { "item_hurricane_pike", true },
    { "item_gungir", true },
    { "item_harpoon", true },
    { "item_ethereal_blade", true },
    { "item_sheepstick", true },
    { "item_disperser", true },
    { "item_abyssal_blade", true },
    { "item_bloodthorn", true },
    { "item_wind_waker", true },
}

-- Skill pops are free so they beat item gold cost when ready.
local LINKBREAKER_ABILITIES = {
    disruptor_thunder_strike = true,
    disruptor_glimpse = true,
}

-- Total gold cost (assets/data/items.json) — pick cheapest ready pop.
local LINKBREAKER_POP_COST = {
    disruptor_thunder_strike = 0,
    disruptor_glimpse = 0,
    item_force_staff = 2200,
    item_rod_of_atos = 2250,
    item_diffusal_blade = 2500,
    item_diffusal_blade_2 = 2500,
    item_cyclone = 2600,
    item_dagon = 3050,
    item_orchid = 3275,
    item_heavens_halberd = 3400,
    item_dagon_2 = 4200,
    item_nullifier = 4350,
    item_hurricane_pike = 4450,
    item_gungir = 4650,
    item_harpoon = 4700,
    item_ethereal_blade = 5200,
    item_sheepstick = 5200,
    item_dagon_3 = 5350,
    item_disperser = 6100,
    item_abyssal_blade = 6250,
    item_bloodthorn = 6400,
    item_dagon_4 = 6500,
    item_wind_waker = 6800,
    item_dagon_5 = 7650,
}

-- Point-target pops (cast on enemy position).
local LINKBREAKER_POINT_CAST = {
    item_gungir = true,
}

-- Spell-immunity blocks these pops (Force / Pike / Abyssal still work).
local LINKBREAKER_BLOCKED_BY_BKB = {
    disruptor_thunder_strike = true,
    disruptor_glimpse = true,
    item_rod_of_atos = true,
    item_diffusal_blade = true,
    item_cyclone = true,
    item_dagon = true,
    item_orchid = true,
    item_heavens_halberd = true,
    item_nullifier = true,
    item_gungir = true,
    item_harpoon = true,
    item_ethereal_blade = true,
    item_sheepstick = true,
    item_disperser = true,
    item_bloodthorn = true,
    item_wind_waker = true,
}

local DIFFUSAL_ITEMS = {
    "item_diffusal_blade",
    "item_diffusal_blade_2",
}

-- Dagger upgrades share the Important Items `item_blink` toggle.
local BLINK_DAGGER_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local DAGON_ITEMS = {
    "item_dagon",
    "item_dagon_2",
    "item_dagon_3",
    "item_dagon_4",
    "item_dagon_5",
}

local HEX_MODIFIERS = {
    "modifier_sheepstick_debuff",
}

local SILENCE_ITEM_MODIFIERS = {
    "modifier_orchid_malevolence_debuff",
    "modifier_bloodthorn_debuff",
}

local NULLIFIER_MUTE_MOD = "modifier_item_nullifier_mute"
local SATANIC_ACTIVE_MOD = "modifier_item_satanic_unholy"
local BKB_ACTIVE_MOD = "modifier_black_king_bar_immune"
local ARMLET_UNHOLY_MOD = "modifier_item_armlet_unholy_strength"
local MJOLLNIR_STATIC_MOD = "modifier_item_mjollnir_static"
local MOM_BERSERK_MOD = "modifier_item_mask_of_madness_berserk"
local BLADE_MAIL_ACTIVE_MOD = "modifier_item_blade_mail_reflect"
local PHASE_BOOTS_MOD = "modifier_item_phase_boots_active"
local DIFFUSAL_SLOW_MOD = "modifier_item_diffusal_blade_slow"
local JANGGO_ACTIVE_MOD = "modifier_item_ancient_janggo_active"
local BEARING_ACTIVE_MOD = "modifier_item_boots_of_bearing_active"
local SOLAR_CREST_SELF_MOD = "modifier_item_solar_crest_armor_addition"
local URN_DAMAGE_MOD = "modifier_item_urn_damage"
local VESSEL_DAMAGE_MOD = "modifier_item_spirit_vessel_damage"
local PIKE_RANGE_MOD = "modifier_item_hurricane_pike_active"
local SUPPORT_AURA_RADIUS = 1200
local SUPPORT_EMERGENCY_HP = 35

-- Runtime Enum has no modifierState table; detect immunity via known modifiers.
local MAGIC_IMMUNE_MODS = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
}

---Without Aghanim mute: these states walk through Kinetic Field / shrug Static Storm.
local FIELD_ESCAPE_MODS = {
    "modifier_black_king_bar_immune",
    "modifier_juggernaut_blade_fury",
    "modifier_life_stealer_rage",
    "modifier_omninight_martyr",
    "modifier_omniknight_martyr",
    "modifier_omninight_repel",
    "modifier_omniknight_repel",
    "modifier_legion_commander_press_the_attack",
    "modifier_huskar_life_break_charge",
    "modifier_phoenix_supernova_hiding",
    "modifier_puck_phase_shift",
    "modifier_obsidian_destroyer_astral_imprisonment",
    "modifier_shadow_demon_disruption",
    "modifier_eul_cyclone",
    "modifier_wind_waker",
    "modifier_brewmaster_storm_cyclone",
    "modifier_invoker_tornado",
    "modifier_bane_nightmare",
    "modifier_winter_wyvern_winters_curse_aura",
    "modifier_winter_wyvern_winters_curse",
    "modifier_dazzle_shallow_grave",
    "modifier_abaddon_borrowed_time",
    "modifier_tusk_snowball_movement",
    "modifier_morphling_waveform",
    "modifier_storm_spirit_ball_lightning",
    "modifier_ember_spirit_fire_remnant",
    "modifier_slark_pounce",
    "modifier_mirana_leap",
    "modifier_spirit_breaker_charge_of_darkness",
    "modifier_faceless_void_time_walk",
    "modifier_antimage_blink",
    "modifier_queenofpain_blink",
    "modifier_phantom_assassin_phantom_strike",
    "modifier_riki_blink_strike",
}

---Abilities that, when ready, will walk out of Field before Aghs mute matters.
local FIELD_ESCAPE_READY_ABILITIES = {
    "juggernaut_blade_fury",
    "life_stealer_rage",
    "phoenix_supernova",
}

-- Smart Usage: Nullifier only when the target has something worth strong-dispelling.
local NULLIFIER_DISPEL_MODS = {
    "modifier_item_glimmer_cape_fade",
    "modifier_item_lotus_orb_active",
    "modifier_ghost_state",
    "modifier_item_ethereal_blade_ethereal",
    "modifier_item_pipe_barrier",
    "modifier_item_crimson_guard_extra",
    "modifier_omninight_guardian_angel",
    "modifier_item_satanic_unholy",
    "modifier_item_blade_mail_reflect",
    "modifier_nyx_assassin_spiked_carapace",
    "modifier_eul_cyclone",
    "modifier_wind_waker",
    "modifier_item_invisibility_edge_windwalk",
    "modifier_item_silver_edge_windwalk",
    "modifier_rune_invis",
    "modifier_invisible",
    "modifier_bounty_hunter_wind_walk",
    "modifier_clinkz_wind_walk",
    "modifier_weaver_shukuchi",
    "modifier_windrunner_windrun_invis",
}

local NULLIFIER_DISPEL_ITEMS = {
    "item_glimmer_cape",
    "item_ghost",
    "item_ethereal_blade",
    "item_lotus_orb",
    "item_aeon_disk",
    "item_satanic",
    "item_pipe",
    "item_crimson_guard",
    "item_sphere",
    "item_eternal_shroud",
}

local BLINK_CLOSE_MARGIN = 50
local BLINK_RANGE_MARGIN = 25

--#endregion

--#region State

local UI = {}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type table<string, integer>
    heroIcons = {},
}

local Runtime = {
    comboTarget = nil,
    lastCastAt = -math.huge,
    lastAnyOrderAt = -math.huge,
    lastOrderTag = nil,
    lastAimPos = nil,
    busyUntil = -math.huge,
    heldForCastAt = -math.huge,
    prevComboHeld = false,
    debugHeartbeatAt = -math.huge,
    ---@type table<string, boolean>
    abilityIssued = {},
    ---@type table<string, number>
    abilityIssuedAt = {},
    ---@type table<string, number|nil>
    abilityIssuedCharges = {},
    ---One blink/Fallen Sky per Combo Key hold.
    blinkUsed = false,
    ---After first hero ability cast, stop inserting engage items mid-chain.
    abilityChainStarted = false,
    ---When Lil' Shredder buff first appeared this hold (for refresh delay).
    ---Cookie orders that never entered phase (MoM cancel / interrupt). Back off to attacks.
    ---One Refresher/Shard per Combo Key hold (second Cookie→Blast→Shredder cycle).
    refresherUsed = false,
    ---Throttle Move-to-Cursor while hunting a target.
    lastFollowCursorAt = -math.huge,
    ---Cached for OnDraw target mark (me / enemy / pulse).
    ---@type userdata|nil
    drawMe = nil,
    ---@type userdata|nil
    drawTarget = nil,
    drawActive = false,
    ---Re-assert Main Settings visibility after Built-in Disruptor hides it.
    menuShowAsserts = 0,
    ---Sticky lock: entity index + last world pos (re-acquire near corpse, not cursor thrash).
    lockEntIndex = nil,
    ---@type Vector|nil
    lockWorldPos = nil,
    lockLostAt = -math.huge,
    comboMode = nil,
    comboStage = "idle",
    fieldPos = nil,
    fieldHits = 0,
    fieldLocked = false,
    comboCompleteLogged = false,
    stageStartedAt = -math.huge,
    blinkSettleUntil = -math.huge,
    fieldCastAt = -math.huge,
    fieldEndsAt = -math.huge,
    stormCastAt = -math.huge,
    stormEndsAt = -math.huge,
    secondCycleAt = -math.huge,
    secondCycleWaitReason = nil,
    trapCenter = nil,
    trapFieldRadius = nil,
    qDone = false,
    wDone = false,
    eDone = false,
    fenceDone = false,
    rDone = false,
    ---@type Vector|nil
    fencePos = nil,
    prevAoeHeld = false,
    prevTargetHeld = false,
    prevGlimpseKeyDown = false,
    debugWaitHeartbeatAt = -math.huge,
    debugSkipAttackAt = -math.huge,
    ---@type table<integer, {t: number, x: number, y: number, z: number}[]>
    glimpseHistory = {},
    ---@type {pos: Vector, current: Vector, unitName: string}[]|nil
    glimpseDrawList = nil,
    ---Manual Glimpse Key: W on enemy → E on return position.
    ---@type {stage: string, enemy: userdata|nil, returnPos: Vector|nil, startedAt: number}|nil
    glimpseManual = nil,
    glimpseKeyUpAt = nil,
}

--#endregion

--#region Helpers

---@generic T
---@param fn fun(...): T
---@param ... any
---@return boolean ok
---@return T|string ...
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

---@param tag string
---@return string
local function OrderId(tag)
    return ORDER_PREFIX .. tag
end

local function ResetRuntime()
    Runtime.comboTarget = nil
    Runtime.lastCastAt = -math.huge
    Runtime.lastAnyOrderAt = -math.huge
    Runtime.lastOrderTag = nil
    Runtime.lastAimPos = nil
    Runtime.busyUntil = -math.huge
    Runtime.heldForCastAt = -math.huge
    Runtime.prevComboHeld = false
    Runtime.debugHeartbeatAt = -math.huge
    Runtime.abilityIssued = {}
    Runtime.abilityIssuedAt = {}
    Runtime.abilityIssuedCharges = {}
    Runtime.abilityConsumed = {}
    Runtime.blinkUsed = false
    Runtime.abilityChainStarted = false
    Runtime.refresherUsed = false
    Runtime.lastFollowCursorAt = -math.huge
    Runtime.drawMe = nil
    Runtime.drawTarget = nil
    Runtime.drawActive = false
    Runtime.menuShowAsserts = 0
    Runtime.lockEntIndex = nil
    Runtime.lockWorldPos = nil
    Runtime.lockLostAt = -math.huge
    Runtime.comboMode = nil
    Runtime.comboStage = "idle"
    Runtime.fieldPos = nil
    Runtime.fieldHits = 0
    Runtime.fieldLocked = false
    Runtime.comboCompleteLogged = false
    Runtime.qDone = false
    Runtime.wDone = false
    Runtime.eDone = false
    Runtime.fenceDone = false
    Runtime.rDone = false
    Runtime.fieldCastAt = -math.huge
    Runtime.fieldEndsAt = -math.huge
    Runtime.stormCastAt = -math.huge
    Runtime.stormEndsAt = -math.huge
    Runtime.secondCycleAt = -math.huge
    Runtime.secondCycleWaitReason = nil
    Runtime.trapCenter = nil
    Runtime.trapFieldRadius = nil
    Runtime.glimpseHistory = {}
    Runtime.glimpseDrawList = nil
    Runtime.glimpseManual = nil
end

local function ResetComboSession()
    Runtime.heldForCastAt = -math.huge
    Runtime.lastAimPos = nil
    Runtime.busyUntil = -math.huge
    Runtime.lastOrderTag = nil
    Runtime.abilityIssued = {}
    Runtime.abilityIssuedAt = {}
    Runtime.abilityIssuedCharges = {}
    Runtime.abilityConsumed = {}
    Runtime.blinkUsed = false
    Runtime.abilityChainStarted = false
    Runtime.refresherUsed = false
    Runtime.lastFollowCursorAt = -math.huge
    Runtime.lockEntIndex = nil
    Runtime.lockWorldPos = nil
    Runtime.lockLostAt = -math.huge
end

---@param fmt string
---@param ... any
local function Dbg(fmt, ...)
    if not UI.Debug or not UI.Debug.Get or UI.Debug:Get() ~= true then
        return
    end
    local msg = fmt
    if select("#", ...) > 0 then
        msg = string.format(fmt, ...)
    end
    if Persistent.logger then
        Persistent.logger:info(msg)
    else
        print("[Disruptor] " .. msg)
    end
end

---@param now number
---@param fmt string
---@param ... any
local function DbgThrottledSkipAttack(now, fmt, ...)
    if (now - (Runtime.debugSkipAttackAt or -math.huge)) < DEBUG_WAIT_HEARTBEAT then
        return
    end
    Runtime.debugSkipAttackAt = now
    Dbg(fmt, ...)
end

---@param a Vector|nil
---@param b Vector|nil
---@return number
local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
    return (b - a):Length2D()
end

---@return integer
local function GetOrderQueueCount()
    local queue = SafeValue(Humanizer.GetOrderQueue)
    if type(queue) ~= "table" then
        return 0
    end
    return #queue
end

---@param unit userdata|nil
---@return string
local function FmtUnit(unit)
    if not unit then
        return "nil"
    end
    local name = SafeValue(NPC.GetUnitName, unit) or "?"
    local short = name:gsub("^npc_dota_hero_", ""):gsub("^npc_dota_", "")
    return short
end

---@param pos Vector|nil
---@return string
local function FmtPos(pos)
    if not pos then
        return "?"
    end
    return string.format("%.0f,%.0f", pos.x or 0, pos.y or 0)
end

---Hold-only: physical key state via Input.IsKeyDown. Never latch on IsToggled.
---@param bind CMenuBind|nil
---@return boolean
local function IsBindHeld(bind)
    if not bind then
        return false
    end

    local key1, key2 = nil, nil
    if bind.Buttons then
        local ok, a, b = TryCall(bind.Buttons, bind)
        if ok then
            key1, key2 = a, b
        end
    end
    if key1 == nil and bind.Get then
        key1 = SafeValue(bind.Get, bind, 0)
    end

    local held = false
    local none = Enum.ButtonCode.KEY_NONE
    if key1 ~= nil and key1 ~= none and SafeValue(Input.IsKeyDown, key1) == true then
        held = true
    elseif key2 ~= nil and key2 ~= none and SafeValue(Input.IsKeyDown, key2) == true then
        held = true
    end

    -- Clear any bind-island toggle latch so the script cannot stick "on".
    if not held and bind.SetToggled then
        TryCall(bind.SetToggled, bind, false)
    end

    return held
end

---@param now number
---@param tag string
---@param gap number|nil
---@return boolean
local function CanIssue(now, tag, gap)
    gap = gap or CAST_GAP
    if (now - Runtime.lastAnyOrderAt) < GLOBAL_ORDER_GAP then
        return false
    end
    if Runtime.lastOrderTag == tag and (now - Runtime.lastCastAt) < gap then
        return false
    end
    return true
end

---@param now number
---@param tag string
---@param busyFor number|nil
local function MarkIssued(now, tag, busyFor)
    Runtime.lastCastAt = now
    Runtime.lastAnyOrderAt = now
    Runtime.lastOrderTag = tag
    if busyFor and busyFor > 0 then
        local untilAt = now + busyFor
        if untilAt > Runtime.busyUntil then
            Runtime.busyUntil = untilAt
        end
    end
end

---@param ability userdata|nil
---@return number
local function GetBusyDuration(ability)
    local castPoint = ability and (SafeValue(Ability.GetCastPoint, ability, true) or 0) or 0
    return math.max(0.12, castPoint + 0.05)
end

---Blocks new orders while cast-locked or Humanizer queue is backed up.
---@param now number
---@param me userdata
---@param allowWhileChanneling boolean|nil
---@return boolean ok
---@return string|nil reason
local function CanSendOrder(now, me, allowWhileChanneling)
    if now < Runtime.busyUntil then
        return false, string.format("busy=%.2f", Runtime.busyUntil - now)
    end

    local queueCount = GetOrderQueueCount()
    if queueCount > ORDER_QUEUE_MAX then
        return false, "queue=" .. tostring(queueCount)
    end

    if SafeValue(NPC.IsStunned, me) == true then
        return false, "stunned"
    end

    if not allowWhileChanneling and SafeValue(NPC.IsChannellingAbility, me) == true then
        return false, "channeling"
    end

    return true, nil
end

local ICON_OVERRIDES = {
    modifier_item_silver_edge_windwalk = "panorama/images/items/silver_edge_png.vtex_c",
    modifier_item_invisibility_edge_windwalk = "panorama/images/items/invis_sword_png.vtex_c",
    bounty_hunter_wind_walk_ally = "panorama/images/spellicons/bounty_hunter_wind_walk_ally_png.vtex_c",
    modifier_rune_invis = "panorama/images/spellicons/rune_invis_png.vtex_c",
}

---@param name string|nil
---@return string
local function GetPanoramaIconPath(name)
    if not name or name == "" then
        return "panorama/images/items/recipe_png.vtex_c"
    end

    local override = ICON_OVERRIDES[name]
    if override then
        return override
    end

    if name:find("^item_", 1) then
        if name:find("recipe", 1, true) then
            return "panorama/images/items/recipe_png.vtex_c"
        end
        return "panorama/images/items/" .. name:gsub("^item_", "") .. "_png.vtex_c"
    end

    return "panorama/images/spellicons/" .. name .. "_png.vtex_c"
end

---@param entries table[]
---@return table[]
local function BuildMultiSelectItems(entries)
    local items = {}
    for _, entry in ipairs(entries) do
        local nameId = entry[1]
        local enabled = entry[2] == true
        items[#items + 1] = {
            nameId,
            GetPanoramaIconPath(nameId),
            enabled,
        }
    end
    return items
end

---@param names string[]
---@param defaultEnabled table<string, boolean>
---@return table[]
local function BuildUsageMultiSelectItems(names, defaultEnabled)
    local items = {}
    for _, nameId in ipairs(names) do
        items[#items + 1] = {
            nameId,
            GetPanoramaIconPath(nameId),
            defaultEnabled[nameId] == true,
        }
    end
    return items
end

---@param widget any
---@param imagePath string
local function MenuImage(widget, imagePath)
    if widget and widget.Image then
        widget:Image(imagePath)
    end
end

---@param value integer
---@return string
local function FormatBlinkDistance(value)
    -- Umbrella draws slider values through printf-style formatting, so every
    -- literal "%" in the returned string must be escaped as "%%".
    --
    -- Internal range 1..1100:
    --   1..100    → ATK 1% .. ATK 100%
    --   101..400  → ATK 100% + 1 .. +300
    --   401..1100 → absolute 1 .. 700
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value <= 100 then
        if value < 1 then
            value = 1
        end
        return "ATK " .. tostring(value) .. "%%"
    end
    if value <= 400 then
        return "ATK 100%% + " .. tostring(value - 100)
    end
    local absolute = value - 400
    if absolute < 1 then
        absolute = 1
    elseif absolute > 700 then
        absolute = 700
    end
    return tostring(absolute)
end

---@param value integer
---@return string
local function FormatNearby(value)
    return string.format("%d nearby", value)
end

--#endregion

--#region Menu

---@param snapfireTab CSecondTab|nil
local function ApplyHeroTabIcon(snapfireTab)
    if not snapfireTab then
        return
    end

    snapfireTab:Image(HERO_ICON)

    local heroId = Engine.GetHeroIDByName(HERO_UNIT)
    if heroId then
        snapfireTab:LinkHero(heroId, Enum.Attributes.DOTA_ATTRIBUTE_INTELLECT)
    end
end

---Built-in Disruptor hides Main Settings when disabled; force it back on.
---@param node CThirdTab|CMenuGroup|nil
local function EnsureMenuVisible(node)
    if node and node.Visible then
        node:Visible(true)
    end
end

---Heroes → Hero List → Snapfire
---@return CSecondTab|nil
local function FindOrCreateHeroTab()
    ---@type CTabSection|nil
    local heroList = Menu.Find("Heroes", "Hero List")
    if not heroList then
        return nil
    end

    ---@type CSecondTab|nil
    local snapfireTab = Menu.Find("Heroes", "Hero List", HERO_TAB)
    if not snapfireTab and heroList.Find then
        snapfireTab = heroList:Find(HERO_TAB)
    end
    if not snapfireTab and heroList.Create then
        snapfireTab = heroList:Create(HERO_TAB)
    end
    if not snapfireTab then
        snapfireTab = Menu.Create("Heroes", "Hero List", HERO_TAB)
    end
    if not snapfireTab then
        return nil
    end

    ApplyHeroTabIcon(snapfireTab)
    return snapfireTab
end

---Heroes → Hero List → Snapfire → <thirdTabName>
---@param snapfireTab CSecondTab
---@param thirdTabName string
---@return CThirdTab|nil
local function FindOrCreateThirdTab(snapfireTab, thirdTabName)
    ---@type CThirdTab|nil
    local tab = Menu.Find("Heroes", "Hero List", HERO_TAB, thirdTabName)
    if not tab and snapfireTab.Find then
        tab = snapfireTab:Find(thirdTabName)
    end
    if not tab and snapfireTab.Create then
        tab = snapfireTab:Create(thirdTabName)
    end
    if not tab then
        tab = Menu.Create("Heroes", "Hero List", HERO_TAB, thirdTabName)
    end
    if not tab then
        return nil
    end

    EnsureMenuVisible(tab)
    return tab
end

---Heroes → Hero List → Snapfire → Main Settings (same layout as Abaddon/etc.).
---@return CThirdTab|nil
local function FindOrCreateMainSettings()
    local snapfireTab = FindOrCreateHeroTab()
    if not snapfireTab then
        return nil
    end
    return FindOrCreateThirdTab(snapfireTab, "Main Settings")
end

---Heroes → Hero List → Snapfire → Extra Settings (framework tab + our Combo Indicator group).
---@return CThirdTab|nil
local function FindOrCreateExtraSettings()
    local snapfireTab = FindOrCreateHeroTab()
    if not snapfireTab then
        return nil
    end
    return FindOrCreateThirdTab(snapfireTab, "Extra Settings")
end

---@param thirdTab CThirdTab
---@param thirdTabName string
---@param groupName string
---@param side Enum.GroupSide
---@return CMenuGroup|nil
local function FindOrCreateGroup(thirdTab, thirdTabName, groupName, side)
    ---@type CMenuGroup|nil
    local existing = Menu.Find("Heroes", "Hero List", HERO_TAB, thirdTabName, groupName)
    if not existing and thirdTab and thirdTab.Find then
        existing = thirdTab:Find(groupName)
    end
    if existing then
        EnsureMenuVisible(existing)
        return existing
    end
    ---@type CMenuGroup|nil
    local created = nil
    if thirdTab and thirdTab.Create then
        created = thirdTab:Create(groupName, side)
    end
    if not created then
        created = Menu.Create("Heroes", "Hero List", HERO_TAB, thirdTabName, groupName)
    end
    EnsureMenuVisible(created)
    return created
end

local function UpdateControlsDisabled(ui)
    local enabled = ui.Enabled:Get()
    local disabled = not enabled

    ui.AoeComboKey:Disabled(disabled)
    ui.TargetComboKey:Disabled(disabled)
    if ui.GlimpseKey then
        ui.GlimpseKey:Disabled(disabled)
    end
    if ui.MinEnemies then
        ui.MinEnemies:Disabled(disabled)
    end
    if ui.DrawGlimpse then
        ui.DrawGlimpse:Disabled(disabled)
    end
    if ui.DrawTrajectory then
        ui.DrawTrajectory:Disabled(disabled)
    end
    if ui.GlimpseOnlyCastable then
        ui.GlimpseOnlyCastable:Disabled(disabled)
    end
    ui.ComboInDamageReturn:Disabled(disabled)
    ui.Debug:Disabled(disabled)
    if ui.ComboIndicator then
        ui.ComboIndicator:Disabled(disabled)
    end
    if ui.AbilitiesIndicator then
        ui.AbilitiesIndicator:Disabled(disabled)
    end
    if ui.ItemsIndicator then
        ui.ItemsIndicator:Disabled(disabled)
    end
    if ui.MmbOnIcon then
        ui.MmbOnIcon:Disabled(disabled)
    end
    -- Legacy Overlay Mode widget (removed): keep hidden if config still has it.
    if ui.OverlayMode and ui.OverlayMode.Visible then
        ui.OverlayMode:Visible(false)
    end
    ui.AbilitySelect:Disabled(disabled)
    ui.ItemUsageRow:Disabled(disabled)
    ui.DistanceFromTarget:Disabled(disabled)
    for _, widget in pairs(ui.ItemUsageWidgets) do
        widget:Disabled(disabled)
    end
    ui.SupportRow:Disabled(disabled)
    for _, slider in ipairs(ui.SupportSliders) do
        slider:Disabled(disabled)
    end
    ui.ConditionsRow:Disabled(disabled)
    ui.OnlyAttackWhenActive:Disabled(disabled)
    ui.SmartUsage:Disabled(disabled)
    ui.UseInStun:Disabled(disabled)
    ui.SatanicHp:Disabled(disabled)
    ui.BloodstoneHp:Disabled(disabled)
    ui.SoulRingHp:Disabled(disabled)
    if ui.SelfSaveHp then
        ui.SelfSaveHp:Disabled(disabled)
    end
    ui.LinkbreakerItems:Disabled(disabled)
end

local function InitializeUI()
    local main = FindOrCreateMainSettings()
    if not main then
        error("[Disruptor] Failed to find/create Main Settings")
    end

    local extra = FindOrCreateExtraSettings()
    if not extra then
        error("[Disruptor] Failed to find/create Extra Settings")
    end

    local heroGroup = FindOrCreateGroup(main, "Main Settings", "Hero Settings", Enum.GroupSide.Left)
    local itemsGroup = FindOrCreateGroup(main, "Main Settings", "Items Settings", Enum.GroupSide.Right)
    local glimpseGroup = FindOrCreateGroup(main, "Main Settings", "Glimpse Helper", Enum.GroupSide.Left)
    local indicatorGroup = FindOrCreateGroup(
        extra,
        "Extra Settings",
        "Combo Indicator",
        Enum.GroupSide.Left
    )
    if not heroGroup or not itemsGroup or not indicatorGroup or not glimpseGroup then
        error("[Disruptor] Failed to create Hero/Items/Combo Indicator/Glimpse Helper groups")
    end

    EnsureMenuVisible(main)
    EnsureMenuVisible(extra)
    EnsureMenuVisible(heroGroup)
    EnsureMenuVisible(itemsGroup)
    EnsureMenuVisible(indicatorGroup)
    EnsureMenuVisible(glimpseGroup)

    -- Hide leftover Glimpse Helper under Extra Settings from earlier builds.
    local staleExtraGlimpse = Menu.Find("Heroes", "Hero List", HERO_TAB, "Extra Settings", "Glimpse Helper")
    if staleExtraGlimpse and staleExtraGlimpse.Visible then
        staleExtraGlimpse:Visible(false)
    end

    local ui = {
        MainSettings = main,
        ExtraSettings = extra,
        HeroSettings = heroGroup,
        ItemsSettings = itemsGroup,
        IndicatorSettings = indicatorGroup,
        GlimpseSettings = glimpseGroup,
    }

    ui.Enabled = heroGroup:Switch("Enable", true, I.enable)
    -- Stable gear id stays "Settings"; display title matches built-in Enable → Extra Settings.
    ui.EnableGear = ui.Enabled:Gear("Settings", I.gear, true)
    ui.EnableGear:ForceLocalization("Extra Settings")

    -- Hide leftover widgets from earlier UI iterations.
    local staleDamageReturn = heroGroup:Find("Combo in Damage Return")
    if staleDamageReturn and staleDamageReturn.Visible then
        staleDamageReturn:Visible(false)
    end
    local staleDamageReturnGear = ui.EnableGear:Find("Combo in Damage Return Gear")
    if staleDamageReturnGear and staleDamageReturnGear.Visible then
        staleDamageReturnGear:Visible(false)
    end
    local staleExtraLabel = ui.EnableGear:Find("Extra Settings")
    if staleExtraLabel and staleExtraLabel.Visible then
        staleExtraLabel:Visible(false)
    end
    -- Old location: Combo Indicator lived under Enable gear; hide leftovers.
    for _, staleName in ipairs({
        "Combo Indicator",
        "Overlay Mode",
        "Abilities Indicator",
        "Items Indicator",
        "MMB on Icon",
    }) do
        local stale = ui.EnableGear:Find(staleName)
        if stale and stale.Visible then
            stale:Visible(false)
        end
    end

    ui.ComboInDamageReturn = ui.EnableGear:Switch(
        "Combo in Damage Return",
        false,
        I.damageReturn
    )
    ui.ComboInDamageReturn:ToolTip("Blade Mail, Nyx Spiked Carapace")

    ui.Debug = ui.EnableGear:Switch("Debug logs", false, I.debug)
    ui.Debug:ToolTip(
        "Combat logs to Umbrella console (combo steps, casts, target picks, skips)."
    )

    -- Extra Settings → Combo Indicator (sibling tab to Main Settings under Snapfire).
    ui.ComboIndicator = indicatorGroup:Switch("Enable", true, I.comboIndicator)
    ui.ComboIndicator:ForceLocalization("Combo Indicator")
    ui.ComboIndicator:ToolTip(
        "ON/OFF badges on native HUD ability/item icons. Click an icon to toggle; clicks are blocked from casting."
    )
    -- Hide leftover Overlay Mode from older builds.
    local staleOverlay = indicatorGroup:Find("Overlay Mode")
    if staleOverlay and staleOverlay.Visible then
        staleOverlay:Visible(false)
    end
    ui.OverlayMode = nil
    ui.AbilitiesIndicator = indicatorGroup:Switch("Abilities Indicator", true, I.abilities)
    ui.ItemsIndicator = indicatorGroup:Switch("Items Indicator", true, I.itemsIndicator)
    ui.MmbOnIcon = indicatorGroup:Switch("MMB on Icon", true, I.gear)
    ui.MmbOnIcon:ToolTip(
        "Middle-click toggles ON/OFF and blocks that MMB cast bind. Left-click casts; right-click sells/disassembles."
    )

    ui.AoeComboKey = heroGroup:Bind("AOE Combo Key", Enum.ButtonCode.KEY_MOUSE4, I.aoeKey or I.comboKey)
    ui.AoeComboKey:Properties("AOE Combo Key", "Hold", false)
    ui.AoeComboKey:SetToggled(false)
    ui.AoeComboKey:ToolTip(
        "Hold: Field on the densest enemy cluster, then Thunder Strike → Field → Fence → Storm on that center."
    )

    ui.TargetComboKey = heroGroup:Bind("Target Combo Key", Enum.ButtonCode.KEY_NONE, I.targetKey or I.comboKey)
    ui.TargetComboKey:Properties("Target Combo Key", "Hold", false)
    ui.TargetComboKey:SetToggled(false)
    ui.TargetComboKey:ToolTip(
        "Hold: sticky cursor target. Blink into Q range, then Q → Field → Fence → Storm on that hero."
    )

    -- Hide leftover Snapfire binds if present from older menus.
    local staleCombo = heroGroup:Find("Combo Key")
    if staleCombo and staleCombo.Visible then
        staleCombo:Visible(false)
    end
    local staleKisses = heroGroup:Find("Kisses Aim Key")
    if staleKisses and staleKisses.Visible then
        staleKisses:Visible(false)
    end
    ui.ComboKey = ui.AoeComboKey
    ui.KissesAimKey = ui.TargetComboKey

    local abilityItems = {}
    for _, entry in ipairs(ABILITY_ENTRIES) do
        abilityItems[#abilityItems + 1] = {
            entry[1],
            GetPanoramaIconPath(entry[1]),
            entry[2] == true,
        }
    end
    ui.AbilitySelect = heroGroup:MultiSelect("Abilities", abilityItems, true)
    ui.AbilitySelect:Icon(I.abilities)
    ui.AbilitySelect:ToolTip(
        "Combo: Thunder Strike → Kinetic Field → Fence (Shard) → Static Storm. Glimpse is only on Glimpse Key."
    )

    ui.MinEnemies = heroGroup:Slider("Enemies to Use", 1, 5, 2, "%d")
    ui.MinEnemies:Icon(I.hits or I.abilities)
    ui.MinEnemies:ToolTip("AOE combo: minimum enemies inside Kinetic Field when scoring placement.")

    ui.ItemUsageRow = itemsGroup:Label("Items Usage", I.itemsUsage)
    local itemGear = ui.ItemUsageRow:Gear("Items Usage", I.bars, true)

    ui.ItemUsageWidgets = {}
    for _, itemGroup in ipairs(ITEM_USAGE_GROUPS) do
        local usageItems = BuildUsageMultiSelectItems(itemGroup.items, itemGroup.defaultEnabled)
        local widget = itemGear:MultiSelect(itemGroup.widget, usageItems, true)
        widget:Update(usageItems, true, true)
        ui.ItemUsageWidgets[itemGroup.widget] = widget
    end

    -- Blink stand-off into Thunder Strike range (absolute 1–700 via formatter).
    for _, staleName in ipairs({ "Distance from Target", "Blink Distance", "Blink Distance From Target" }) do
        local stale = itemGear:Find(staleName)
        if stale and stale.Visible then
            stale:Visible(false)
        end
    end

    -- Absolute stand-off 550 → slider value 950 (401..1100 maps to 1..700).
    ui.DistanceFromTarget = itemGear:Slider(
        "Blink Distance From Target",
        1,
        1100,
        950,
        FormatBlinkDistance
    )
    ui.DistanceFromTarget:ForceLocalization("Distance from Target")
    ui.DistanceFromTarget:Update(1, 1100, 950)
    MenuImage(ui.DistanceFromTarget, BLINK_ICON)
    ui.DistanceFromTarget:ToolTip(
        "Blink stand-off from the combo target (into Thunder Strike range). Absolute values 1–700."
    )
    if ui.DistanceFromTarget.Visible then
        ui.DistanceFromTarget:Visible(true)
    end
    if ui.DistanceFromTarget.Visible then
        ui.DistanceFromTarget:Visible(true)
    end

    ui.SupportRow = itemsGroup:Label("Support Settings", I.support)
    local supportGear = ui.SupportRow:Gear("Support Settings", I.bars, true)

    -- Hide leftover Mekansm slider from earlier UI iteration.
    local staleMek = supportGear:Find("Support Mekansm")
    if staleMek and staleMek.Visible then
        staleMek:Visible(false)
    end

    ui.SupportSliders = {}
    for _, entry in ipairs(SUPPORT_ITEMS) do
        local slider = supportGear:Slider(entry.key, 1, 5, 3, FormatNearby)
        slider:ForceLocalization("Use if Teammates")
        MenuImage(slider, GetPanoramaIconPath(entry.id))
        ui.SupportSliders[#ui.SupportSliders + 1] = slider
    end

    ui.ConditionsRow = itemsGroup:Label("Items Conditions", I.conditions)
    local condGear = ui.ConditionsRow:Gear("Items Conditions", I.bars, true)

    ui.OnlyAttackWhenActive = condGear:MultiSelect(
        "Only Attack when Active",
        BuildMultiSelectItems(ONLY_ATTACK_WHEN_ACTIVE),
        true
    )
    ui.OnlyAttackWhenActive:Icon(I.onlyAttack)

    ui.SmartUsage = condGear:Switch("Smart Usage", true)
    MenuImage(ui.SmartUsage, NULLIFIER_ICON)
    ui.SmartUsage:ToolTip("Will Use Nullifier only if Target has Items / Modifiers to Dispel")

    ui.UseInStun = condGear:MultiSelect(
        "Use in Stun",
        BuildMultiSelectItems(USE_IN_STUN),
        true
    )
    ui.UseInStun:Icon(I.useInStun)

    ui.SatanicHp = condGear:Slider("Satanic HP Threshold", 0, 100, 25, "%d%%")
    ui.SatanicHp:ForceLocalization("Use if HP Lower than")
    MenuImage(ui.SatanicHp, GetPanoramaIconPath("item_satanic"))

    ui.BloodstoneHp = condGear:Slider("Bloodstone HP Threshold", 0, 100, 25, "%d%%")
    ui.BloodstoneHp:ForceLocalization("Use if HP Lower than")
    MenuImage(ui.BloodstoneHp, GetPanoramaIconPath("item_bloodstone"))

    ui.SoulRingHp = condGear:Slider("Soul Ring HP Threshold", 0, 100, 30, "%d%%")
    ui.SoulRingHp:ForceLocalization("Use if HP Bigger than")
    MenuImage(ui.SoulRingHp, GetPanoramaIconPath("item_soul_ring"))

    ui.SelfSaveHp = condGear:Slider("Self Save HP Threshold", 0, 100, 35, "%d%%")
    ui.SelfSaveHp:ForceLocalization("Use if HP Lower than")
    MenuImage(ui.SelfSaveHp, GetPanoramaIconPath("item_glimmer_cape"))
    ui.SelfSaveHp:ToolTip(
        "At or below this HP: Glimmer Cape → Force Staff → Lotus Orb on self (combo openers unchanged)."
    )

    ui.LinkbreakerItems = itemsGroup:MultiSelect(
        "Linkbreaker Items",
        BuildMultiSelectItems(LINKBREAKER_ITEMS),
        false
    )
    ui.LinkbreakerItems:ForceLocalization("Linkbreaker Items")
    MenuImage(ui.LinkbreakerItems, LINKENS_ICON)
    ui.LinkbreakerItems:ToolTip(
        "Cheapest ready pop for Linken's / Sphere: Thunder Strike, Glimpse, then items."
    )


    ui.DrawGlimpse = glimpseGroup:Switch("Draw Glimpse Position", true, I.drawGlimpse)
    ui.DrawGlimpse:ToolTip(
        "Shows each enemy hero icon at their Glimpse return position (world + minimap)."
    )
    ui.DrawTrajectory = glimpseGroup:Switch("Draw Trajectory Line", false, I.drawTrajectory)
    ui.GlimpseOnlyCastable = glimpseGroup:Switch("Only When Castable", true, I.onlyCastable)
    ui.GlimpseKey = glimpseGroup:Bind("Glimpse Key", Enum.ButtonCode.KEY_NONE, I.glimpse or I.comboKey)
    ui.GlimpseKey:Properties("Glimpse Key", "Hold", false)
    ui.GlimpseKey:SetToggled(false)
    ui.GlimpseKey:ToolTip(
        "Hold: Glimpse nearest enemy to cursor, then Kinetic Field on their return position."
    )

    ui.Enabled:SetCallback(function()
        UpdateControlsDisabled(ui)
    end, true)

    ui.ready = true
    return ui
end

--#endregion

--#region Combo Logic

---@param abilityName string
---@return boolean
local function IsAbilityEnabled(abilityName)
    if not UI.AbilitySelect or not UI.AbilitySelect.Get then
        return true
    end
    return UI.AbilitySelect:Get(abilityName) == true
end

---@param itemId string
---@return boolean
local function GetDefaultItemUsage(itemId)
    for i = 1, #ITEM_USAGE_GROUPS do
        local group = ITEM_USAGE_GROUPS[i]
        for j = 1, #group.items do
            if group.items[j] == itemId then
                return group.defaultEnabled[itemId] == true
            end
        end
    end
    return false
end

---@param itemId string
---@return boolean
local function IsItemUsageEnabled(itemId)
    if not itemId then
        return false
    end

    for i = 1, #ITEM_USAGE_GROUPS do
        local group = ITEM_USAGE_GROUPS[i]
        local groupContainsItem = false
        for j = 1, #group.items do
            if group.items[j] == itemId then
                groupContainsItem = true
                break
            end
        end

        if groupContainsItem then
            local widget = UI.ItemUsageWidgets and UI.ItemUsageWidgets[group.widget]
            if widget and widget.Get then
                local ok, enabled = TryCall(widget.Get, widget, itemId)
                if ok and enabled ~= nil then
                    return enabled == true
                end
            end
            return group.defaultEnabled[itemId] == true
        end
    end

    return GetDefaultItemUsage(itemId)
end

---@param itemId string
---@return boolean
local function IsUseInStunEnabled(itemId)
    if not UI.UseInStun or not UI.UseInStun.Get then
        for i = 1, #USE_IN_STUN do
            if USE_IN_STUN[i][1] == itemId then
                return USE_IN_STUN[i][2] == true
            end
        end
        return false
    end
    return UI.UseInStun:Get(itemId) == true
end

---@param itemId string
---@return string
local function NormalizeLinkbreakerUiId(itemId)
    if itemId == "item_dagon_2"
        or itemId == "item_dagon_3"
        or itemId == "item_dagon_4"
        or itemId == "item_dagon_5"
    then
        return "item_dagon"
    end
    return itemId
end

---@param itemId string
---@return boolean
local function GetDefaultLinkbreakerEnabled(itemId)
    local uiId = NormalizeLinkbreakerUiId(itemId)
    for i = 1, #LINKBREAKER_ITEMS do
        if LINKBREAKER_ITEMS[i][1] == uiId then
            return LINKBREAKER_ITEMS[i][2] == true
        end
    end
    return false
end

---Linkbreaker MultiSelect only — independent from Items Usage toggles.
---@param itemId string
---@return boolean
local function IsLinkbreakerEnabled(itemId)
    if not itemId then
        return false
    end
    local uiId = NormalizeLinkbreakerUiId(itemId)
    if not UI.LinkbreakerItems or not UI.LinkbreakerItems.Get then
        return GetDefaultLinkbreakerEnabled(uiId)
    end
    local ok, enabled = TryCall(UI.LinkbreakerItems.Get, UI.LinkbreakerItems, uiId)
    if ok and enabled ~= nil then
        return enabled == true
    end
    return GetDefaultLinkbreakerEnabled(uiId)
end

---@return boolean
local function IsSmartUsageEnabled()
    return UI.SmartUsage == nil or UI.SmartUsage:Get() == true
end

---@param me userdata
---@param itemId string
---@return userdata|nil
local function GetItem(me, itemId)
    return SafeValue(NPC.GetItem, me, itemId, true)
end

---Items often report level 0 via GetLevel; rely on IsCastable.
---@param item userdata|nil
---@param me userdata
---@return boolean
local function CanCastItem(item, me)
    if not item then
        return false
    end
    if SafeValue(Ability.IsHidden, item) == true then
        return false
    end
    if SafeValue(Ability.IsInAbilityPhase, item) == true then
        return false
    end
    local mana = SafeValue(NPC.GetMana, me) or 0
    return SafeValue(Ability.IsCastable, item, mana) == true
end

---@param unit userdata|nil
---@param mods string[]
---@return boolean
local function HasAnyModifier(unit, mods)
    if not unit or not mods then
        return false
    end
    for i = 1, #mods do
        if SafeValue(NPC.HasModifier, unit, mods[i]) == true then
            return true
        end
    end
    return false
end

---@param unit userdata|nil
---@return boolean
local function IsMagicImmune(unit)
    if not unit then
        return true
    end
    return HasAnyModifier(unit, MAGIC_IMMUNE_MODS)
end

---@param unit userdata|nil
---@return boolean
local function TargetNeedsLinkBreak(unit)
    return unit ~= nil and SafeValue(NPC.IsLinkensProtected, unit) == true
end

---@param unit userdata|nil
---@return number
local function GetHealthPct(unit)
    local hp = SafeValue(Entity.GetHealth, unit) or 0
    local maxHp = SafeValue(Entity.GetMaxHealth, unit) or 1
    if maxHp <= 0 then
        return 100
    end
    return (hp / maxHp) * 100
end

---@param me userdata
---@param ability userdata|nil
---@param fallback number|nil
---@return number
local function GetItemCastRange(me, ability, fallback)
    local bonus = SafeValue(NPC.GetCastRangeBonus, me) or 0
    if not ability then
        return (fallback or 0) + bonus
    end
    local base = SafeValue(Ability.GetCastRange, ability)
    if type(base) ~= "number" or base <= 0 then
        local name = SafeValue(Ability.GetName, ability)
        base = (name and Script.ItemRange and Script.ItemRange[name]) or fallback or 0
    end
    if type(base) ~= "number" or base < 0 then
        base = fallback or 0
    end
    return base + bonus
end



---True when target is within cast range (Ability.GetCastRange is often 0 on items).
---@param me userdata
---@param target userdata|nil
---@param castRange number
---@return boolean
local function IsTargetInCastRange(me, target, castRange)
    if not target then
        return false
    end
    if type(castRange) ~= "number" or castRange <= 0 then
        return false
    end
    local slack = 40
    if SafeValue(NPC.IsEntityInRange, me, target, castRange + slack) == true then
        return true
    end
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not myPos or not targetPos then
        return false
    end
    return Dist2D(myPos, targetPos) <= (castRange + slack)
end

---@param me userdata
---@param myPos Vector
---@param targetPos Vector
---@param blink userdata
---@return Vector|nil
---@return number desired
local function ComputeBlinkLandPos(me, myPos, targetPos, blink)
    -- Blink into Thunder Strike range (stand-off from target; default ~550).
    local thunder = SafeValue(NPC.GetAbility, me, ABILITY.thunder)
    local qRange = DC.GetAbilityCastRange(me, thunder, DC.Q_RANGE)
    local standOff = math.min(qRange - DC.Q_RANGE_MARGIN, DC.BLINK_STANDOFF_DEFAULT)
    if UI.DistanceFromTarget and UI.DistanceFromTarget.Get then
        local raw = UI.DistanceFromTarget:Get()
        if type(raw) == "number" then
            -- absolute mode: 401..1100 → 1..700; low legacy values fall back to default
            if raw > 400 then
                standOff = raw - 400
            elseif raw > 100 then
                standOff = math.min(qRange - DC.Q_RANGE_MARGIN, 100 + (raw - 100))
            end
        end
    end
    if standOff < 150 then
        standOff = math.min(qRange - DC.Q_RANGE_MARGIN, DC.BLINK_STANDOFF_DEFAULT)
    end
    if standOff > qRange - DC.Q_RANGE_MARGIN then
        standOff = math.max(150, qRange - DC.Q_RANGE_MARGIN)
    end

    local desired = standOff
    local dist = Dist2D(myPos, targetPos)
    if dist <= desired + BLINK_CLOSE_MARGIN then
        return nil, desired
    end

    local landPos = targetPos:Extend2D(myPos, desired)
    local blinkRange = GetItemCastRange(me, blink, 1200) - BLINK_RANGE_MARGIN
    local travel = Dist2D(myPos, landPos)
    if blinkRange > 0 and travel > blinkRange then
        landPos = myPos:Extend2D(landPos, blinkRange)
        if Dist2D(landPos, targetPos) > dist - 25 then
            return nil, desired
        end
    end

    return landPos, desired
end

---@param target userdata
---@return boolean
local function TargetNeedsNullifierDispel(target)
    if HasAnyModifier(target, NULLIFIER_DISPEL_MODS) then
        return true
    end
    for i = 1, #NULLIFIER_DISPEL_ITEMS do
        if GetItem(target, NULLIFIER_DISPEL_ITEMS[i]) ~= nil then
            return true
        end
    end
    return false
end

---@return boolean
local function IsComboInDamageReturnEnabled()
    return UI.ComboInDamageReturn ~= nil and UI.ComboInDamageReturn:Get() == true
end

---True if target currently reflects damage (Blade Mail active / Nyx carapace).
---@param target userdata
---@return boolean
---@return string|nil modName
local function TargetHasDamageReturn(target)
    for i = 1, #DAMAGE_RETURN_MODS do
        local modName = DAMAGE_RETURN_MODS[i]
        if SafeValue(NPC.HasModifier, target, modName) == true then
            return true, modName
        end
    end
    return false, nil
end

---When the switch is OFF, skip abilities into Blade Mail / Nyx — attacks still allowed.
---@param now number
---@param target userdata
---@return boolean skipAbilities
local function ShouldSkipAbilitiesForDamageReturn(now, target)
    if IsComboInDamageReturnEnabled() then
        return false
    end
    local has, modName = TargetHasDamageReturn(target)
    if not has then
        return false
    end
    if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
        Runtime.debugHeartbeatAt = now
        Dbg(
            "damage return: abilities skipped, attacks only (%s)",
            tostring(modName)
        )
    end
    return true
end

---@param me userdata|nil
---@return boolean
local function IsLocalDisruptor(me)
    return me ~= nil and SafeValue(NPC.GetUnitName, me) == HERO_UNIT
end

---@param unit userdata|nil
---@return boolean
local function IsValidUnit(unit)
    return unit ~= nil
        and SafeValue(Entity.IsAlive, unit) == true
        and SafeValue(Entity.IsDormant, unit) ~= true
end

---@param unit userdata|nil
---@return boolean
local function IsValidEnemyHero(unit)
    return IsValidUnit(unit)
        and SafeValue(Entity.IsHero, unit) == true
        and SafeValue(NPC.IsIllusion, unit) ~= true
end

---Keep a locked combo target while the key is held (alive, or Aegis rebirth).
---@param unit userdata|nil
---@return boolean
local function IsValidLockedEnemy(unit)
    if unit == nil or SafeValue(NPC.IsIllusion, unit) == true then
        return false
    end
    if SafeValue(Entity.IsAlive, unit) == true then
        return true
    end
    -- Aegis: stay locked through death → reincarnate window.
    if SafeValue(NPC.HasAegis, unit) == true then
        return true
    end
    if SafeValue(NPC.IsWaitingToSpawn, unit) == true then
        return true
    end
    return false
end

---Remaining time on a named modifier, or nil.
---@param unit userdata
---@param modName string
---@param now number
---@return number|nil
function Script.GetModRemaining(unit, modName, now)
    local mod = SafeValue(NPC.GetModifier, unit, modName)
    if not mod then
        return nil
    end
    local dieTime = SafeValue(Modifier.GetDieTime, mod)
    if type(dieTime) == "number" and dieTime > now then
        return dieTime - now
    end
    local duration = SafeValue(Modifier.GetDuration, mod)
    local created = SafeValue(Modifier.GetCreationTime, mod)
    if type(duration) == "number" and duration > 0 and type(created) == "number" then
        local remaining = duration - (now - created)
        if remaining > 0 then
            return remaining
        end
    end
    return nil
end

---Longest remaining invuln / cyclone-style window.
---@param unit userdata
---@param now number
---@return number|nil
function Script.GetInvulnRemaining(unit, now)
    local best = nil
    local mods = Script.Timing and Script.Timing.INVULN_MODS
    if not mods then
        return nil
    end
    for i = 1, #mods do
        local rem = Script.GetModRemaining(unit, mods[i], now)
        if rem ~= nil and (best == nil or rem > best) then
            best = rem
        end
    end
    return best
end

---True when right-clicks cannot connect (Ethereal / Ghost / similar).
---Runtime Enum has no modifierState — detect via known modifiers only.
---@param unit userdata
---@return boolean
function Script.IsAttackBlocked(unit)
    local mods = Script.Timing and Script.Timing.ATTACK_BLOCK_MODS
    return mods ~= nil and HasAnyModifier(unit, mods)
end

---True when the full combo should wait (Eul / astral / Aegis wait).
---@param unit userdata
---@param now number
---@return boolean paused
---@return number|nil remaining
---@return string|nil reason
function Script.IsComboWindowClosed(unit, now)
    if SafeValue(Entity.IsAlive, unit) ~= true then
        if SafeValue(NPC.HasAegis, unit) == true or SafeValue(NPC.IsWaitingToSpawn, unit) == true then
            return true, nil, "aegis"
        end
        return false, nil, nil
    end

    local rem = Script.GetInvulnRemaining(unit, now)
    if rem ~= nil and rem > 0 then
        return true, rem, "invuln"
    end

    return false, nil, nil
end

---True when we should still wait (outside the timing lead-in).
---@param remaining number|nil
---@return boolean
function Script.ShouldHoldForTiming(remaining)
    if remaining == nil then
        -- Aegis / unknown duration: keep following until the unit is attackable again.
        return true
    end
    return remaining > TIMING_COMBO_LEAD
end

---True while a Linkbreaker cast was issued and not yet spent/timed out.
---@return boolean
function Script.HasPendingLinkbreak()
    for i = 1, #LINKBREAKER_ITEMS do
        local id = LINKBREAKER_ITEMS[i][1]
        if Runtime.abilityIssued[id] then
            return true
        end
    end
    if Runtime.abilityIssued["item_diffusal_blade_2"] then
        return true
    end
    for i = 1, #DAGON_ITEMS do
        if Runtime.abilityIssued[DAGON_ITEMS[i]] then
            return true
        end
    end
    return false
end

-- Heroes → Settings → General → Target Selection (global). Packed on Script to stay under local limit.
Script.ItemRange = {
    item_force_staff = 550,
    item_hurricane_pike = 550,
    item_cyclone = 550,
    item_wind_waker = 550,
    item_rod_of_atos = 1100,
    item_diffusal_blade = 650,
    item_diffusal_blade_2 = 650,
    item_dagon = 700,
    item_dagon_2 = 700,
    item_dagon_3 = 700,
    item_dagon_4 = 700,
    item_dagon_5 = 700,
    item_orchid = 900,
    item_heavens_halberd = 600,
    item_nullifier = 600,
    item_gungir = 550,
    item_harpoon = 700,
    item_ethereal_blade = 800,
    item_sheepstick = 800,
    item_disperser = 600,
    item_abyssal_blade = 150,
    item_bloodthorn = 900,
    item_blood_grenade = 850,
    item_meteor_hammer = 600,
    item_spirit_vessel = 950,
    item_urn_of_shadows = 950,
    item_essence_distiller = 950,
    item_medallion_of_courage = 1000,
    item_solar_crest = 1000,
    item_crippling_crossbow = 800,
    item_heavy_blade = 550,
    item_mjollnir = 800,
}

-- Self-pulse / AOE items: only use when locked target is inside radius.
Script.ItemAoe = {
    item_shivas_guard = 900,
    item_veil_of_discord = 1200,
    item_jidi_pollen_bag = 700,
}

-- Invuln / ethereal windows used for follow + combo timing.
Script.Timing = {
    INVULN_MODS = {
        "modifier_eul_cyclone",
        "modifier_wind_waker",
        "modifier_shadow_demon_disruption",
        "modifier_obsidian_destroyer_astral_imprisonment",
        "modifier_brewmaster_storm_cyclone",
        "modifier_invoker_tornado",
    },
    ATTACK_BLOCK_MODS = {
        "modifier_item_ethereal_blade_ethereal",
        "modifier_ghost_state",
        "modifier_pugna_decrepify",
        "modifier_necrolyte_sadist_active",
    },
    -- After lock dies: wait before re-picking (cursor thrash).
    LOCK_REACQUIRE_DELAY = 0.28,
    LOCK_REACQUIRE_RADIUS_MUL = 1.75,
}

Script.Target = {
    STYLE_CURSOR = 0,
    STYLE_LOCKED = 1,
    STYLE_SCORE = 2,
    SYNC_INTERVAL = 1.0,
    lastSyncAt = -math.huge,
    searchRange = nil,
    style = nil,
    moveToCursor = nil,
    drawParticle = nil,
    particleColor = nil,
    drawStyle = nil,
    targetMark = nil,
}

function Script.Target.MenuFind(...)
    if not Menu or not Menu.Find then
        return nil
    end
    local ok, result = TryCall(Menu.Find, ...)
    if ok then
        return result
    end
    return nil
end

function Script.Target.Sync(force)
    local now = SafeValue(GameRules.GetGameTime) or 0
    local T = Script.Target
    if not force and (now - (T.lastSyncAt or -math.huge)) < T.SYNC_INTERVAL then
        return
    end
    T.lastSyncAt = now
    T.searchRange = T.MenuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Search Range"
    )
    T.style = T.MenuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Style"
    )
    T.moveToCursor = T.MenuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Move to Cursor"
    )
    T.drawParticle = T.MenuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Draw Particle"
    )
    T.particleColor = T.MenuFind(
        "Heroes",
        "",
        "Settings",
        "General",
        "Target Selection",
        "Draw Particle",
        "Draw Particle",
        "Particle Color"
    )
    T.drawStyle = T.MenuFind(
        "Heroes",
        "",
        "Settings",
        "General",
        "Target Selection",
        "Draw Particle",
        "Draw Particle",
        "Style"
    )
    T.targetMark = T.MenuFind(
        "Heroes",
        "",
        "Settings",
        "General",
        "Target Selection",
        "Draw Particle",
        "Draw Particle",
        "Target Mark"
    )
end

---@return number
function Script.Target.GetSearchRadius()
    Script.Target.Sync(false)
    local widget = Script.Target.searchRange
    if widget and widget.Get then
        local value = SafeValue(widget.Get, widget)
        if type(value) == "number" and value > 0 then
            return value
        end
    end
    return 800
end

---@return integer
function Script.Target.GetStyleMode()
    Script.Target.Sync(false)
    local widget = Script.Target.style
    if widget and widget.Get then
        local idx = SafeValue(widget.Get, widget)
        if widget.List then
            local items = SafeValue(widget.List, widget)
            if type(items) == "table" and type(idx) == "number" and items[idx + 1] then
                local label = string.lower(tostring(items[idx + 1]))
                if label:find("score", 1, true)
                    or label:find("smart", 1, true)
                    or label:find("auto", 1, true)
                then
                    return Script.Target.STYLE_SCORE
                end
                if label:find("lock", 1, true) then
                    return Script.Target.STYLE_LOCKED
                end
                return Script.Target.STYLE_CURSOR
            end
        end
        if type(idx) == "number" then
            if idx == 0 then
                return Script.Target.STYLE_CURSOR
            end
            if idx == 2 then
                return Script.Target.STYLE_SCORE
            end
            return Script.Target.STYLE_LOCKED
        end
        if type(idx) == "string" then
            local label = string.lower(idx)
            if label:find("score", 1, true) or label:find("smart", 1, true) then
                return Script.Target.STYLE_SCORE
            end
            if label:find("lock", 1, true) then
                return Script.Target.STYLE_LOCKED
            end
        end
    end
    return Script.Target.STYLE_LOCKED
end

---@return boolean
function Script.Target.ShouldMoveToCursor()
    Script.Target.Sync(false)
    local widget = Script.Target.moveToCursor
    if widget and widget.Get and SafeValue(widget.Get, widget) == false then
        return false
    end
    return true
end

---@return boolean
function Script.Target.ShouldDrawMark()
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return false
    end
    Script.Target.Sync(false)
    local widget = Script.Target.drawParticle
    if widget and widget.Get and SafeValue(widget.Get, widget) == false then
        return false
    end
    return true
end

---@param alpha? number
---@return Color
function Script.Target.GetMarkColor(alpha)
    Script.Target.Sync(false)
    local a = alpha or 220
    local widget = Script.Target.particleColor
    if widget and widget.Get then
        ---@type Color|table|nil
        local value = SafeValue(widget.Get, widget)
        if type(value) == "table" then
            local r = value.r or value[1]
            local g = value.g or value[2]
            local b = value.b or value[3]
            if type(r) == "number" and type(g) == "number" and type(b) == "number" then
                return Color(r, g, b, a)
            end
        elseif value ~= nil and type(value) ~= "number" and type(value) ~= "boolean" then
            ---@cast value Color
            if type(value.r) == "number" and type(value.g) == "number" and type(value.b) == "number" then
                return Color(value.r, value.g, value.b, a)
            end
        end
    end
    -- Chat / Menu theme primary.
    local Ind = Script.Indicator
    if Ind and Ind.themePr then
        return Color(Ind.themePr, Ind.themePg, Ind.themePb, a)
    end
    return Color(255, 148, 64, a)
end

---@param unit userdata|nil
---@param radius number
---@return boolean
function Script.Target.NearCursor(unit, radius)
    if not unit then
        return false
    end
    local cursor = SafeValue(Input.GetWorldCursorPos)
    local pos = SafeValue(Entity.GetAbsOrigin, unit)
    if not cursor or not pos then
        return false
    end
    return Dist2D(cursor, pos) <= radius
end

---@param me userdata
---@param unit userdata|nil
---@return number
function Script.Target.ScoreEnemy(me, unit)
    if not IsValidEnemyHero(unit) then
        return -math.huge
    end
    local score = 1000
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, unit)
    if myPos and enemyPos then
        score = score - Dist2D(myPos, enemyPos) * 0.20
    end
    local cursor = SafeValue(Input.GetWorldCursorPos)
    if cursor and enemyPos then
        score = score - Dist2D(cursor, enemyPos) * 0.85
    end
    local hp = SafeValue(Entity.GetHealth, unit) or 0
    local maxHp = SafeValue(Entity.GetMaxHealth, unit) or 1
    if maxHp > 0 then
        score = score + (1 - (hp / maxHp)) * 180
    end
    return score
end

---Search Range = world radius around a point (cursor or last lock).
---@param me userdata
---@param center Vector
---@param searchRadius number
---@return userdata|nil
function Script.Target.PickNearPos(me, center, searchRadius)
    local team = SafeValue(Entity.GetTeamNum, me)
    if team == nil or not center or type(searchRadius) ~= "number" then
        return nil
    end

    if not Heroes or not Heroes.InRadius then
        return nil
    end

    local heroes = SafeValue(
        Heroes.InRadius,
        center,
        searchRadius,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )
    if type(heroes) ~= "table" then
        return nil
    end

    local best, bestDist = nil, math.huge
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemyHero(enemy) then
            local pos = SafeValue(Entity.GetAbsOrigin, enemy)
            if pos then
                local d = Dist2D(center, pos)
                if d < bestDist then
                    bestDist = d
                    best = enemy
                end
            end
        end
    end
    return best
end

---Search Range = world radius around the CURSOR (not around the hero).
---@param me userdata
---@param searchRadius number
---@return userdata|nil
function Script.Target.PickNearCursor(me, searchRadius)
    local team = SafeValue(Entity.GetTeamNum, me)
    if team == nil then
        return nil
    end

    local nearest = SafeValue(Input.GetNearestHeroToCursor, team, Enum.TeamType.TEAM_ENEMY)
    if IsValidEnemyHero(nearest) and Script.Target.NearCursor(nearest, searchRadius) then
        return nearest
    end

    local cursor = SafeValue(Input.GetWorldCursorPos)
    if not cursor then
        return nil
    end
    return Script.Target.PickNearPos(me, cursor, searchRadius)
end

---@param me userdata
---@param searchRadius number
---@return userdata|nil
function Script.Target.PickByScore(me, searchRadius)
    local team = SafeValue(Entity.GetTeamNum, me)
    local cursor = SafeValue(Input.GetWorldCursorPos)
    if not cursor or team == nil or not Heroes or not Heroes.InRadius then
        return Script.Target.PickNearCursor(me, searchRadius)
    end
    local heroes = SafeValue(
        Heroes.InRadius,
        cursor,
        searchRadius,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )
    if type(heroes) ~= "table" or #heroes == 0 then
        return nil
    end
    local best, bestScore = nil, -math.huge
    for i = 1, #heroes do
        local enemy = heroes[i]
        local score = Script.Target.ScoreEnemy(me, enemy)
        if score > bestScore then
            bestScore = score
            best = enemy
        end
    end
    return best
end

---@param entIndex number|nil
---@return userdata|nil
function Script.Target.FindByEntIndex(entIndex)
    if type(entIndex) ~= "number" or not Heroes then
        return nil
    end
    if Heroes.GetAll then
        local all = SafeValue(Heroes.GetAll)
        if type(all) == "table" then
            for i = 1, #all do
                local hero = all[i]
                if hero and SafeValue(Entity.GetIndex, hero) == entIndex then
                    return hero
                end
            end
        end
    end
    local count = SafeValue(Heroes.Count)
    if type(count) == "number" and Heroes.Get then
        for i = 0, count - 1 do
            local hero = SafeValue(Heroes.Get, i)
            if hero and SafeValue(Entity.GetIndex, hero) == entIndex then
                return hero
            end
        end
    end
    return nil
end

---@param unit userdata|nil
function Script.Target.RememberLock(unit)
    if not unit then
        return
    end
    local idx = SafeValue(Entity.GetIndex, unit)
    if type(idx) == "number" then
        Runtime.lockEntIndex = idx
    end
    local pos = SafeValue(Entity.GetAbsOrigin, unit)
    if pos then
        Runtime.lockWorldPos = pos
    end
    Runtime.lockLostAt = -math.huge
end

---@param now number
---@param me userdata
---@param locked userdata|nil
---@param label string
---@return userdata|nil
function Script.Target.ResolveOrKeep(now, me, locked, label)
    if locked == nil and type(Runtime.lockEntIndex) == "number" then
        locked = Script.Target.FindByEntIndex(Runtime.lockEntIndex)
    end

    -- Alive lock sticks — cursor must not steal mid-combo.
    if IsValidLockedEnemy(locked) then
        Script.Target.RememberLock(locked)
        return locked
    end

    -- Target died / invalid: short pause, then continue on the next enemy (same combo state).
    if locked ~= nil or type(Runtime.lockEntIndex) == "number" then
        if Runtime.lockLostAt < 0 then
            Runtime.lockLostAt = now
            Dbg("%s target lost → next enemy", label)
        end
        local delay = (Script.Timing and Script.Timing.LOCK_REACQUIRE_DELAY) or 0.28
        if (now - Runtime.lockLostAt) < delay then
            return nil
        end
    end

    local searchRadius = Script.Target.GetSearchRadius()
    local style = Script.Target.GetStyleMode()

    -- Prefer fight cluster around the corpse, then cursor.
    local pick = nil
    if Runtime.lockWorldPos then
        local mul = (Script.Timing and Script.Timing.LOCK_REACQUIRE_RADIUS_MUL) or 1.75
        pick = Script.Target.PickNearPos(me, Runtime.lockWorldPos, searchRadius * mul)
    end
    if not pick then
        pick = Script.Target.PickNearCursor(me, searchRadius)
    end

    -- Never re-lock the same dead index; Prefer a different living hero when possible.
    if pick and type(Runtime.lockEntIndex) == "number" then
        local pickIdx = SafeValue(Entity.GetIndex, pick)
        if pickIdx == Runtime.lockEntIndex and not IsValidLockedEnemy(pick) then
            pick = nil
        end
    end

    if pick then
        Script.Target.RememberLock(pick)
        Dbg("%s lock target=%s", label, FmtUnit(pick))
        return pick
    end

    if style == Script.Target.STYLE_SCORE then
        local scored = Script.Target.PickByScore(me, searchRadius)
        if scored then
            Script.Target.RememberLock(scored)
            Dbg("%s lock target=%s (score)", label, FmtUnit(scored))
            return scored
        end
    end

    if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
        Runtime.debugHeartbeatAt = now
        Dbg("%s: no enemy near cursor (range=%.0f)", label, searchRadius)
    end
    return nil
end

---@param now number
---@param me userdata
---@param force? boolean  when true, ignore global Move to Cursor (combo wait windows)
---@return boolean
function Script.Target.FollowCursor(now, me, force)
    if not force and not Script.Target.ShouldMoveToCursor() then
        return false
    end
    local cursor = SafeValue(Input.GetWorldCursorPos)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not cursor or not myPos then
        return false
    end
    if Dist2D(myPos, cursor) < 90 then
        return false
    end
    if (now - (Runtime.lastFollowCursorAt or -math.huge)) < 0.18 then
        return false
    end
    local okSend = CanSendOrder(now, me, false)
    if not okSend then
        return false
    end
    if not CanIssue(now, "follow", 0.20) then
        return false
    end
    local ok, err = TryCall(NPC.MoveTo, me, cursor, false, false, false, true, OrderId("follow"), false)
    if ok then
        Runtime.lastFollowCursorAt = now
        MarkIssued(now, "follow", 0.05)
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("follow cursor @ %s", FmtPos(cursor))
        end
        return true
    end
    Dbg("FAIL follow: %s", tostring(err))
    return false
end

---@param widget any
---@return string
function Script.Target.ReadComboLabel(widget)
    if not widget or not widget.Get then
        return ""
    end
    local idx = SafeValue(widget.Get, widget)
    if widget.List then
        local items = SafeValue(widget.List, widget)
        if type(items) == "table" and type(idx) == "number" and items[idx + 1] then
            return string.lower(tostring(items[idx + 1]))
        end
    end
    if type(idx) == "string" then
        return string.lower(idx)
    end
    return ""
end

---@return boolean wantBeam
---@return string markKind  "complex"|"simple"|"none"
function Script.Target.GetDrawOptions()
    Script.Target.Sync(false)
    local styleLabel = Script.Target.ReadComboLabel(Script.Target.drawStyle)
    local markLabel = Script.Target.ReadComboLabel(Script.Target.targetMark)
    local styleWidget = Script.Target.drawStyle
    local markWidget = Script.Target.targetMark

    local wantBeam = true
    if styleLabel ~= "" then
        if styleLabel:find("none", 1, true) or styleLabel:find("off", 1, true) then
            wantBeam = false
        elseif styleLabel:find("beam", 1, true)
            or styleLabel:find("line", 1, true)
            or styleLabel:find("particle", 1, true)
        then
            wantBeam = true
        end
    elseif styleWidget and styleWidget.Get then
        local idx = SafeValue(styleWidget.Get, styleWidget)
        -- Common Umbrella order: 0 = None, 1 = Beam/Particle.
        if type(idx) == "number" and idx <= 0 then
            wantBeam = false
        end
    end

    local markKind = "complex"
    if markLabel ~= "" then
        if markLabel:find("none", 1, true) or markLabel:find("off", 1, true) then
            markKind = "none"
        elseif markLabel:find("simple", 1, true) or markLabel:find("circle", 1, true) then
            markKind = "simple"
        elseif markLabel:find("complex", 1, true) or markLabel:find("scope", 1, true) then
            markKind = "complex"
        end
    elseif markWidget and markWidget.Get then
        local idx = SafeValue(markWidget.Get, markWidget)
        if type(idx) == "number" then
            if idx <= 0 then
                markKind = "none"
            elseif idx == 1 then
                markKind = "simple"
            else
                markKind = "complex"
            end
        end
    end
    return wantBeam, markKind
end

---@param x number
---@param y number
---@param half number
---@param arm number
---@param color Color
---@param thickness number
function Script.Target.DrawCornerBrackets(x, y, half, arm, color, thickness)
    if not Render or not Render.Line then
        return
    end
    -- Top-left
    TryCall(Render.Line, Vec2(x - half, y - half), Vec2(x - half + arm, y - half), color, thickness)
    TryCall(Render.Line, Vec2(x - half, y - half), Vec2(x - half, y - half + arm), color, thickness)
    -- Top-right
    TryCall(Render.Line, Vec2(x + half, y - half), Vec2(x + half - arm, y - half), color, thickness)
    TryCall(Render.Line, Vec2(x + half, y - half), Vec2(x + half, y - half + arm), color, thickness)
    -- Bottom-left
    TryCall(Render.Line, Vec2(x - half, y + half), Vec2(x - half + arm, y + half), color, thickness)
    TryCall(Render.Line, Vec2(x - half, y + half), Vec2(x - half, y + half - arm), color, thickness)
    -- Bottom-right
    TryCall(Render.Line, Vec2(x + half, y + half), Vec2(x + half - arm, y + half), color, thickness)
    TryCall(Render.Line, Vec2(x + half, y + half), Vec2(x + half, y + half - arm), color, thickness)
end

function Script.Target.DrawMark()
    if not Runtime.drawActive or not Script.Target.ShouldDrawMark() then
        return
    end
    local me = Runtime.drawMe
    local target = Runtime.drawTarget
    if not IsValidUnit(me) or not IsValidLockedEnemy(target) then
        return
    end
    if not Render or not Render.WorldToScreen then
        return
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, target)
    if not myPos or not enemyPos then
        return
    end

    local okMe, screenMe, visMe = TryCall(Render.WorldToScreen, myPos)
    local okEn, screenEn, visEn = TryCall(Render.WorldToScreen, enemyPos)
    if not (okEn and visEn and screenEn) then
        return
    end

    local now = SafeValue(GameRules.GetGameTime) or 0
    local breathe = 0.5 + 0.5 * math.sin(now * 2.35)
    local wantBeam, markKind = Script.Target.GetDrawOptions()
    local core = Script.Target.GetMarkColor(math.floor(215 + 40 * breathe))
    local soft = Script.Target.GetMarkColor(math.floor(110 + 55 * breathe))
    local mist = Script.Target.GetMarkColor(math.floor(36 + 28 * breathe))
    local hi = Script.Target.GetMarkColor(math.floor(240 + 15 * breathe))

    -- Thin themed link with a soft shadow underlay.
    if wantBeam and okMe and visMe and screenMe and Render.Line then
        TryCall(Render.Line, screenMe, screenEn, mist, 3.6)
        TryCall(Render.Line, screenMe, screenEn, soft, 1.7)
        TryCall(Render.Line, screenMe, screenEn, core, 1.05)
        if Render.FilledCircle then
            TryCall(Render.FilledCircle, screenMe, 2.6 + 0.5 * breathe, soft)
            TryCall(Render.FilledCircle, screenMe, 1.3, hi)
        end
        if Render.ShadowCircle then
            TryCall(Render.ShadowCircle, screenMe, 3.5, mist, 8 + 2 * breathe, 12)
        end
    end

    if markKind == "none" then
        return
    end

    local x, y = screenEn.x, screenEn.y
    local base = (markKind == "complex") and 23 or 17
    local half = base + 3.0 * breathe
    local arm = half * 0.44
    if arm < 8 then
        arm = 8
    end

    if Render.ShadowCircle then
        TryCall(
            Render.ShadowCircle,
            screenEn,
            half * 0.7,
            Script.Target.GetMarkColor(math.floor(40 + 40 * breathe)),
            half * 1.45,
            20
        )
        TryCall(
            Render.ShadowCircle,
            screenEn,
            half * 0.28,
            Script.Target.GetMarkColor(math.floor(55 + 45 * breathe)),
            half * 0.75,
            14
        )
    end

    -- Shadow brackets → soft → crisp highlight.
    Script.Target.DrawCornerBrackets(x, y, half + 3.2, arm + 2.0, mist, 4.4)
    Script.Target.DrawCornerBrackets(x, y, half + 1.2, arm + 0.8, soft, 2.6)
    Script.Target.DrawCornerBrackets(x, y, half, arm, core, 1.55)
    Script.Target.DrawCornerBrackets(x, y, half - 0.6, arm - 0.4, hi, 0.95)

    if markKind == "complex" then
        local gap = 3.0
        local tip = 6.2 + breathe
        TryCall(Render.Line, Vec2(x - tip, y), Vec2(x - gap, y), mist, 2.4)
        TryCall(Render.Line, Vec2(x + gap, y), Vec2(x + tip, y), mist, 2.4)
        TryCall(Render.Line, Vec2(x, y - tip), Vec2(x, y - gap), mist, 2.4)
        TryCall(Render.Line, Vec2(x, y + gap), Vec2(x, y + tip), mist, 2.4)
        TryCall(Render.Line, Vec2(x - tip, y), Vec2(x - gap, y), soft, 1.35)
        TryCall(Render.Line, Vec2(x + gap, y), Vec2(x + tip, y), soft, 1.35)
        TryCall(Render.Line, Vec2(x, y - tip), Vec2(x, y - gap), soft, 1.35)
        TryCall(Render.Line, Vec2(x, y + gap), Vec2(x, y + tip), soft, 1.35)
        if Render.FilledCircle then
            TryCall(Render.FilledCircle, screenEn, 2.0, soft)
            TryCall(Render.FilledCircle, screenEn, 1.15, hi)
        end
    end
end

--#region Combo Indicator (native HUD ON/OFF badges)

Script.Indicator = {
    CONFIG = "Disruptor",
    ABILITY_SLOTS = 6,
    ITEM_SLOTS = 6,
    -- HUD layout is stable; refresh rarely (GetBounds / GetPanelInfo are expensive).
    BOUNDS_TTL = 2.5,
    BOUNDS_MISS_TTL = 1.25,
    SANITIZE_TTL = 3.0,
    ICON_CHROME_Y = 12,
    ---@type table<string, { uiId: string, widget: string }>|nil
    usageMap = nil,
    ---@type table<string, boolean>|nil
    abilityTracked = nil,
    ---@type { x: number, y: number, w: number, h: number, widget: any, id: string }[]
    hits = {},
    font = 0,
    ---@type Color|nil
    colorOn = nil,
    ---@type Color|nil
    colorOff = nil,
    ---@type Color|nil
    colorShadow = nil,
    ---Chat / Menu.Style primary RGB (for Draw sync).
    themePr = 255,
    themePg = 148,
    themePb = 64,
    ---Chat / Menu.Style secondary RGB.
    themeSr = 175,
    themeSg = 178,
    themeSb = 185,
    ---@type boolean|nil
    hudReady = nil,
    hudProbeAt = -math.huge,
    ---@type string[]|nil
    hudAbilityPrefix = nil,
    ---@type string[]|nil
    hudItemPrefix = nil,
    ---@type string[]|nil
    hudNeutralPath = nil,
    ---Cached UIPanel handles (resolved once).
    ---@type table<integer, UIPanel>
    abilityPanels = {},
    ---@type table<integer, UIPanel>
    itemPanels = {},
    ---@type UIPanel|nil
    neutralPanel = nil,
    ---Throttled bounds from UIPanel:GetBounds / GetPanelInfo.
    ---@type table<string, { x: number, y: number, w: number, h: number, at: number, miss?: boolean }>
    boundsCache = {},
    ---@type boolean|nil
    boundsUseJs = nil,
    ---@type number|nil
    slotPitch = nil,
    ---Optional paths for GetPanelInfo fallback (Ability0 / inventory_slot_N).
    ---@type table<string, string[]>
    panelPaths = {},
    toggleAt = -math.huge,
    blockUntil = -math.huge,
    ---@type string|nil
    blockAbilityId = nil,
    ptrMmb = false,
    ---Leftover click-shield panels from older builds (disabled on restore).
    ---@type table<string, UIPanel>
    shields = {},
    sanitizeAt = -math.huge,
    itemBoundsAt = -math.huge,
    ---@type table<integer, { x: number, y: number, w: number, h: number }>|nil
    itemSlotBounds = nil,
    screenCacheAt = -math.huge,
    screenW = 1920,
    screenH = 1080,
    ---@type table<string, { w: number, h: number }>
    badgeTextSize = {},
    shieldsRestored = false,
    abilityNamesAt = -math.huge,
    ---@type table<integer, string|false>
    abilityNamesByHud = {},
    restoreAt = -math.huge,
}

function Script.Indicator.EnsureMaps()
    local Ind = Script.Indicator
    if not Ind.usageMap then
        local map = {}
        for i = 1, #ITEM_USAGE_GROUPS do
            local group = ITEM_USAGE_GROUPS[i]
            for j = 1, #group.items do
                local id = group.items[j]
                map[id] = { uiId = id, widget = group.widget }
            end
        end
        for i = 1, #BLINK_DAGGER_ITEMS do
            map[BLINK_DAGGER_ITEMS[i]] = { uiId = "item_blink", widget = "Important Items" }
        end
        for i = 1, #DAGON_ITEMS do
            map[DAGON_ITEMS[i]] = { uiId = "item_dagon", widget = "Semi-Important Items" }
        end
        map.item_diffusal_blade_2 = { uiId = "item_diffusal_blade", widget = "Other Items" }
        map.item_refresher_shard = { uiId = "item_refresher", widget = "Important Items" }
        Ind.usageMap = map
    end

    -- Always refresh ability tracking so Multiselect/shard ability stays in sync.
    local tracked = {}
    for i = 1, #ABILITY_ENTRIES do
        tracked[ABILITY_ENTRIES[i][1]] = true
    end
    -- Never badge the innate passive even if HUD parsing is ambiguous.
    tracked[ABILITY.innate] = nil
    Ind.abilityTracked = tracked
    -- Slot map must be rebuilt after innate-inclusion change.
    Ind.abilityNamesAt = -math.huge
end

function Script.Indicator.EnsureFont()
    local Ind = Script.Indicator
    if Ind.font ~= 0 then
        return Ind.font
    end
    if not Render or not Render.LoadFont then
        return 0
    end
    local ok, handle = TryCall(
        Render.LoadFont,
        "Segoe UI",
        Enum.FontCreate.FONTFLAG_ANTIALIAS,
        700
    )
    if (not ok or type(handle) ~= "number" or handle == 0) then
        ok, handle = TryCall(
            Render.LoadFont,
            "Arial",
            Enum.FontCreate.FONTFLAG_ANTIALIAS,
            700
        )
    end
    if ok and type(handle) == "number" and handle ~= 0 then
        Ind.font = handle
        return handle
    end
    return 0
end

function Script.Indicator.RefreshTheme()
    local Ind = Script.Indicator
    Ind.themePr, Ind.themePg, Ind.themePb = 255, 148, 64
    Ind.themeSr, Ind.themeSg, Ind.themeSb = 175, 178, 185
    Ind.colorShadow = Color(0, 0, 0, 210)
    Ind.colorOn = Color(Ind.themePr, Ind.themePg, Ind.themePb, 245)
    Ind.colorOff = Color(Ind.themeSr, Ind.themeSg, Ind.themeSb, 230)
    if not Menu or not Menu.Style then
        return
    end
    local ok, primary = TryCall(Menu.Style, "primary")
    if ok and primary and type(primary.r) == "number" then
        Ind.themePr = primary.r
        Ind.themePg = primary.g
        Ind.themePb = primary.b
        Ind.colorOn = Color(primary.r, primary.g, primary.b, 245)
    end
    local ok2, secondary = TryCall(Menu.Style, "secondary")
    if ok2 and secondary and type(secondary.r) == "number" then
        Ind.themeSr = secondary.r
        Ind.themeSg = secondary.g
        Ind.themeSb = secondary.b
        Ind.colorOff = Color(secondary.r, secondary.g, secondary.b, 230)
    end
end

---Menu / chat theme primary as Color (alpha override).
---@param alpha number|nil
---@return Color
function DC.ThemePrimary(alpha)
    local Ind = Script.Indicator
    if not Ind.colorOn then
        Script.Indicator.RefreshTheme()
    end
    return Color(Ind.themePr or 255, Ind.themePg or 148, Ind.themePb or 64, alpha or 220)
end

---Menu / chat theme secondary as Color (alpha override).
---@param alpha number|nil
---@return Color
function DC.ThemeSecondary(alpha)
    local Ind = Script.Indicator
    if not Ind.colorOn then
        Script.Indicator.RefreshTheme()
    end
    return Color(Ind.themeSr or 175, Ind.themeSg or 178, Ind.themeSb or 185, alpha or 200)
end

---Lighter mix of primary toward white (crosshair / highlights).
---@param alpha number|nil
---@param mix number|nil 0..1 toward white
---@return Color
function DC.ThemePrimaryLite(alpha, mix)
    local Ind = Script.Indicator
    if not Ind.colorOn then
        Script.Indicator.RefreshTheme()
    end
    mix = mix or 0.45
    local r = Ind.themePr or 255
    local g = Ind.themePg or 148
    local b = Ind.themePb or 64
    return Color(
        math.floor(r + (255 - r) * mix),
        math.floor(g + (255 - g) * mix),
        math.floor(b + (255 - b) * mix),
        alpha or 220
    )
end

function Script.Indicator.ResetHudProbe()
    local Ind = Script.Indicator
    Ind.hudReady = nil
    Ind.hudProbeAt = -math.huge
    Ind.hudAbilityPrefix = nil
    Ind.hudItemPrefix = nil
    Ind.hudNeutralPath = nil
    Ind.abilityPanels = {}
    Ind.itemPanels = {}
    Ind.neutralPanel = nil
    Ind.boundsCache = {}
    Ind.boundsUseJs = nil
    Ind.slotPitch = nil
    Ind.panelPaths = {}
    Ind.shields = {}
    Ind.sanitizeAt = -math.huge
    Ind.itemBoundsAt = -math.huge
    Ind.itemSlotBounds = nil
    Ind.shieldsRestored = false
    Ind.abilityNamesAt = -math.huge
    Ind.abilityNamesByHud = {}
    Ind.restoreAt = -math.huge
    Ind.blockUntil = -math.huge
    Ind.blockAbilityId = nil
end

---@param panel any
---@return boolean
function Script.Indicator.PanelOk(panel)
    if panel == nil or type(panel) == "string" or type(panel) == "boolean" then
        return false
    end
    -- Soft valid check: missing IsValid is OK; explicit false rejects.
    if panel.IsValid then
        local ok, valid = TryCall(panel.IsValid, panel)
        if ok and valid == false then
            return false
        end
    end
    return true
end

---Narrow TryCall/pcall results to UIPanel after PanelOk.
---@param panel any
---@return UIPanel|nil
function Script.Indicator.AsPanel(panel)
    if not Script.Indicator.PanelOk(panel) then
        return nil
    end
    ---@cast panel UIPanel
    return panel
end

---@param id string
---@param isType? boolean
---@return UIPanel|nil
---@return string detail
function Script.Indicator.TryGetByName(id, isType)
    if not Panorama or not Panorama.GetPanelByName then
        return nil, "no-api"
    end
    local ok, panel = TryCall(Panorama.GetPanelByName, id, isType == true)
    if not ok then
        return nil, "err:" .. tostring(panel)
    end
    local typed = Script.Indicator.AsPanel(panel)
    if not typed then
        return nil, panel == nil and "nil" or "invalid"
    end
    return typed, "ok"
end

---@param id string
---@return UIPanel|nil
function Script.Indicator.ResolveByName(id)
    if not id then
        return nil
    end
    local panel = Script.Indicator.TryGetByName(id, false)
    if panel then
        return panel
    end
    panel = Script.Indicator.TryGetByName(id, true)
    if panel then
        return panel
    end
    if Panorama and Panorama.GetPanelByPath then
        local ok, found = TryCall(Panorama.GetPanelByPath, { id }, false)
        if ok then
            local typed = Script.Indicator.AsPanel(found)
            if typed then
                return typed
            end
        end
    end
    return nil
end

---@param parent UIPanel|nil
---@param id string
---@return UIPanel|nil
function Script.Indicator.FindIn(parent, id)
    if not parent or not id or not Script.Indicator.PanelOk(parent) then
        return nil
    end
    ---@cast parent UIPanel
    if parent.FindChildTraverse then
        local ok, child = TryCall(parent.FindChildTraverse, parent, id)
        if ok then
            local typed = Script.Indicator.AsPanel(child)
            if typed then
                return typed
            end
        end
    end
    if parent.FindChild then
        local ok, child = TryCall(parent.FindChild, parent, id)
        if ok then
            local typed = Script.Indicator.AsPanel(child)
            if typed then
                return typed
            end
        end
    end
    return nil
end

---Walk path: GetPanelByName(first), then FindChild / FindChildTraverse per segment.
---@param path string[]
---@return UIPanel|nil
function Script.Indicator.WalkPath(path)
    if type(path) ~= "table" or #path < 1 then
        return nil
    end
    local panel = Script.Indicator.TryGetByName(path[1], false)
    if not panel then
        panel = Script.Indicator.TryGetByName(path[1], true)
    end
    if not panel and Panorama and Panorama.GetPanelByPath then
        local ok, found = TryCall(Panorama.GetPanelByPath, path, false)
        if ok then
            local typed = Script.Indicator.AsPanel(found)
            if typed then
                return typed
            end
        end
    end
    if not panel then
        return nil
    end
    for i = 2, #path do
        local nextPanel = Script.Indicator.FindIn(panel, path[i])
        if not nextPanel then
            return nil
        end
        panel = nextPanel
    end
    return panel
end

---@param path string[]
---@return UIPanel|nil
function Script.Indicator.ResolvePanel(path)
    if type(path) ~= "table" or #path < 1 then
        return nil
    end
    if #path == 1 then
        return Script.Indicator.ResolveByName(path[1])
    end
    local viaWalk = Script.Indicator.WalkPath(path)
    if viaWalk then
        return viaWalk
    end
    if not Panorama or not Panorama.GetPanelByPath then
        return nil
    end
    local ok, panel = TryCall(Panorama.GetPanelByPath, path, false)
    if ok then
        return Script.Indicator.AsPanel(panel)
    end
    return nil
end

---@param bounds any
---@return number|nil, number|nil, number|nil, number|nil
function Script.Indicator.UnpackBounds(bounds)
    if bounds == nil or type(bounds) == "boolean" or type(bounds) == "string" or type(bounds) == "number" then
        return nil, nil, nil, nil
    end
    local x = bounds.x
    local y = bounds.y
    local w = bounds.w
    local h = bounds.h
    if type(x) ~= "number" or type(y) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then
        return nil, nil, nil, nil
    end
    return x, y, w, h
end

---@param abilityPanel UIPanel
---@return UIPanel
function Script.Indicator.AbilityDrawPanel(abilityPanel)
    local button = Script.Indicator.FindIn(abilityPanel, "ButtonAndLevel") or abilityPanel
    local image = Script.Indicator.FindIn(button, "AbilityButton")
        or Script.Indicator.FindIn(button, "AbilityImage")
        or Script.Indicator.FindIn(button, "Button")
    if image then
        return image
    end
    return button
end

---Collapse tall ability panels (hotkey/level chrome) to the icon square.
---@param x number
---@param y number
---@param w number
---@param h number
---@return number, number, number
function Script.Indicator.IconSquare(x, y, w, h)
    local Ind = Script.Indicator
    local side = w
    if h > 0 and h < side then
        side = h
    end
    local pitch = Ind.slotPitch
    if type(pitch) == "number" and pitch >= 24 and pitch < side * 1.35 then
        side = math.min(side, pitch)
    end
    if side < 18 then
        side = math.max(w, 18)
    end
    -- Tall ButtonAndLevel: icon is the top square; slight inset past hotkey chrome.
    local iy = y
    if h > side * 1.25 then
        iy = y + math.min(Ind.ICON_CHROME_Y or 12, math.floor((h - side) * 0.25))
    end
    return x, iy, side
end

---True when bounds look like lower-HUD screen coordinates (not parent-relative).
---@param x number|nil
---@param y number|nil
---@param w number|nil
---@param h number|nil
---@param minYFrac number|nil bottom fraction gate; inventory uses a stricter value than abilities
---@return boolean
function Script.Indicator.BoundsOnLowerHud(x, y, w, h, minYFrac)
    if type(x) ~= "number" or type(y) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then
        return false
    end
    if w < 8 or h < 8 then
        return false
    end
    local Ind = Script.Indicator
    local now = SafeValue(GameRules.GetGameTime) or 0
    if (now - (Ind.screenCacheAt or -math.huge)) >= 2.0 then
        Ind.screenCacheAt = now
        local screen = SafeValue(Render.ScreenSize)
        if screen and type(screen.x) == "number" and screen.x > 1 then
            Ind.screenW = screen.x
        end
        if screen and type(screen.y) == "number" and screen.y > 1 then
            Ind.screenH = screen.y
        end
    end
    local sh = Ind.screenH or 1080
    local sw = Ind.screenW or 1920
    local gate = minYFrac or 0.35
    return x > -20 and y > sh * gate and x < sw and y < sh - 4
end

---Reject stash / depot panels (same inventory_slot_* ids as the hero inventory).
---@param panel UIPanel|nil
---@return boolean
function Script.Indicator.IsStashRelated(panel)
    local cur = Script.Indicator.AsPanel(panel)
    for _ = 1, 14 do
        if not cur then
            break
        end
        if cur.GetID then
            local id = SafeValue(cur.GetID, cur)
            if type(id) == "string" then
                local low = string.lower(id)
                if string.find(low, "stash", 1, true)
                    or string.find(low, "depot", 1, true)
                    or string.find(low, "treasure", 1, true)
                then
                    return true
                end
            end
        end
        if not cur.GetParent then
            break
        end
        cur = Script.Indicator.AsPanel(SafeValue(cur.GetParent, cur))
    end
    return false
end

---Item-slot bounds must sit on the bottom inventory row band (stash is higher on screen).
---@param cacheKey string
---@return number
function Script.Indicator.BoundsMinYFrac(cacheKey)
    if type(cacheKey) == "string"
        and (
            string.sub(cacheKey, 1, 2) == "it"
            or cacheKey == "neutral"
        )
    then
        return 0.55
    end
    return 0.35
end

---Fast bounds with positive + negative cache. Avoids per-frame GetPanelInfo storms.
---@param cacheKey string
---@param panel UIPanel|nil
---@return { x: number, y: number, w: number, h: number }|nil
function Script.Indicator.GetPanelBoundsCached(cacheKey, panel)
    local Ind = Script.Indicator
    local now = SafeValue(GameRules.GetGameTime) or 0
    local minY = Script.Indicator.BoundsMinYFrac(cacheKey)
    local cached = Ind.boundsCache[cacheKey]
    if cached then
        if cached.miss then
            if (now - cached.at) < Ind.BOUNDS_MISS_TTL then
                return nil
            end
        elseif (now - cached.at) < Ind.BOUNDS_TTL then
            return cached
        end
    end

    if panel ~= nil then
        if not Script.Indicator.PanelOk(panel) or Script.Indicator.IsStashRelated(panel) then
            Ind.boundsCache[cacheKey] = { miss = true, at = now, x = 0, y = 0, w = 0, h = 0 }
            return nil
        end
    end

    ---@type number|nil, number|nil, number|nil, number|nil
    local x, y, w, h = nil, nil, nil, nil
    local preferJs = Ind.boundsUseJs == true

    if panel and panel.GetBounds then
        local ok1, b1 = TryCall(panel.GetBounds, panel, preferJs)
        x, y, w, h = Script.Indicator.UnpackBounds(ok1 and b1 or nil)
        if not Script.Indicator.BoundsOnLowerHud(x, y, w, h, minY) then
            local ok2, b2 = TryCall(panel.GetBounds, panel, not preferJs)
            local x2, y2, w2, h2 = Script.Indicator.UnpackBounds(ok2 and b2 or nil)
            if Script.Indicator.BoundsOnLowerHud(x2, y2, w2, h2, minY) then
                x, y, w, h = x2, y2, w2, h2
                Ind.boundsUseJs = not preferJs
            end
        elseif Ind.boundsUseJs == nil then
            Ind.boundsUseJs = preferJs
        end
    end

    if not Script.Indicator.BoundsOnLowerHud(x, y, w, h, minY) and Panorama and Panorama.GetPanelInfo then
        ---@type string[]|nil
        local path = Ind.panelPaths[cacheKey]
        -- Never resolve bare inventory_slot_* via GetPanelInfo: stash shares those ids.
        if path and #path == 1 and string.find(path[1], "inventory_slot_", 1, true) == 1 then
            path = nil
        end
        if (not path or #path == 0) and Ind.hudItemPrefix and type(cacheKey) == "string" then
            if string.sub(cacheKey, 1, 2) == "it" then
                local slot = tonumber(string.sub(cacheKey, 3))
                if slot ~= nil then
                    path = Script.Indicator.JoinPath(
                        Ind.hudItemPrefix,
                        "inventory_slot_" .. tostring(slot)
                    )
                end
            elseif cacheKey == "neutral" then
                path = Script.Indicator.JoinPath(Ind.hudItemPrefix, "inventory_neutral_slot")
            end
        end
        if path and #path > 0 then
            local preferInfoJs = Ind.boundsUseJs == true
            local okInfo, info = TryCall(Panorama.GetPanelInfo, path, false, preferInfoJs)
            local ix, iy, iw, ih = Script.Indicator.UnpackBounds(okInfo and info or nil)
            if not Script.Indicator.BoundsOnLowerHud(ix, iy, iw, ih, minY) then
                okInfo, info = TryCall(Panorama.GetPanelInfo, path, false, not preferInfoJs)
                ix, iy, iw, ih = Script.Indicator.UnpackBounds(okInfo and info or nil)
                if Script.Indicator.BoundsOnLowerHud(ix, iy, iw, ih, minY) then
                    Ind.boundsUseJs = not preferInfoJs
                end
            end
            if Script.Indicator.BoundsOnLowerHud(ix, iy, iw, ih, minY) then
                x, y, w, h = ix, iy, iw, ih
            end
        end
    end

    if not Script.Indicator.BoundsOnLowerHud(x, y, w, h, minY) then
        Ind.boundsCache[cacheKey] = { miss = true, at = now, x = 0, y = 0, w = 0, h = 0 }
        return nil
    end

    local entry = { x = x, y = y, w = w, h = h, at = now }
    Ind.boundsCache[cacheKey] = entry
    return entry
end

---@param prefix string[]|nil
---@param leaf string
---@return string[]
function Script.Indicator.JoinPath(prefix, leaf)
    if not prefix or #prefix == 0 then
        return { leaf }
    end
    local path = {}
    for i = 1, #prefix do
        path[i] = prefix[i]
    end
    path[#path + 1] = leaf
    return path
end

---Climb from a slot panel to a root that contains both inventory rows.
---@param panel UIPanel|nil
---@return UIPanel|nil
function Script.Indicator.InventoryRootFrom(panel)
    local cur = Script.Indicator.AsPanel(panel)
    for _ = 1, 10 do
        if not cur then
            break
        end
        local id = nil
        if cur.GetID then
            id = SafeValue(cur.GetID, cur)
        end
        if id == "inventory_items"
            or id == "inventory"
            or id == "InventoryContainer"
            or id == "inventory_composition_layer_container"
        then
            return cur
        end
        local hasTop = Script.Indicator.FindIn(cur, "inventory_slot_0")
        local hasBot = Script.Indicator.FindIn(cur, "inventory_slot_3")
        if hasTop and hasBot then
            return cur
        end
        if not cur.GetParent then
            break
        end
        cur = Script.Indicator.AsPanel(SafeValue(cur.GetParent, cur))
    end
    return Script.Indicator.ResolveByName("inventory_items")
        or Script.Indicator.ResolveByName("inventory")
        or Script.Indicator.ResolveByName("inventory_list_container")
end

---Fill missing inventory slot bounds from a 2x3 grid anchored on known good slots.
---@param boundsBySlot table<integer, { x: number, y: number, w: number, h: number }>
function Script.Indicator.FillItemGridBounds(boundsBySlot)
    local anchorSlot, anchor = nil, nil
    for slot = 0, Script.Indicator.ITEM_SLOTS - 1 do
        local b = boundsBySlot[slot]
        if b then
            anchorSlot = slot
            anchor = b
        end
    end
    if anchorSlot == nil or not anchor then
        return
    end

    local pitchX, pitchY = nil, nil
    for a = 0, Script.Indicator.ITEM_SLOTS - 1 do
        for b = a + 1, Script.Indicator.ITEM_SLOTS - 1 do
            local ba = boundsBySlot[a]
            local bb = boundsBySlot[b]
            if ba and bb then
                local ca, ra = a % 3, math.floor(a / 3)
                local cb, rb = b % 3, math.floor(b / 3)
                if ra == rb and ca ~= cb then
                    local px = math.abs(bb.x - ba.x) / math.abs(cb - ca)
                    if px >= 20 then
                        pitchX = px
                    end
                end
                if ca == cb and ra ~= rb then
                    local py = math.abs(bb.y - ba.y) / math.abs(rb - ra)
                    if py >= 20 then
                        pitchY = py
                    end
                end
            end
        end
    end
    if not pitchX then
        pitchX = math.max(anchor.w + 4, 36)
    end
    if not pitchY then
        pitchY = math.max(anchor.h + 4, 36)
    end

    local ac = anchorSlot % 3
    local ar = math.floor(anchorSlot / 3)
    local originX = anchor.x - ac * pitchX
    local originY = anchor.y - ar * pitchY
    local now = SafeValue(GameRules.GetGameTime) or 0
    for slot = 0, Script.Indicator.ITEM_SLOTS - 1 do
        if not boundsBySlot[slot] then
            local c = slot % 3
            local r = math.floor(slot / 3)
            boundsBySlot[slot] = {
                x = originX + c * pitchX,
                y = originY + r * pitchY,
                w = anchor.w,
                h = anchor.h,
                at = now,
            }
        end
    end
end

---Re-bind inventory_slot_* under lower_hud only (never stash — same slot ids).
function Script.Indicator.SanitizeItemPanels()
    local Ind = Script.Indicator
    local prefixes = {
        {
            "HUDElements",
            "lower_hud",
            "center_with_stats",
            "center_block",
            "inventory",
            "inventory_items",
        },
        {
            "DotaHud",
            "HUDElements",
            "lower_hud",
            "center_with_stats",
            "center_block",
            "inventory",
            "inventory_items",
        },
        {
            "HUDElements",
            "lower_hud",
            "center_with_stats",
            "center_block",
            "inventory",
            "inventory_items",
            "inventory_list",
        },
        {
            "HUDElements",
            "lower_hud",
            "center_with_stats",
            "center_block",
            "inventory",
            "inventory_items",
            "inventory_list2",
        },
        Ind.hudItemPrefix,
    }

    for slot = 0, Ind.ITEM_SLOTS - 1 do
        local leaf = "inventory_slot_" .. tostring(slot)
        local cacheKey = "it" .. tostring(slot)
        local panel = nil
        -- Prefer explicit lower_hud paths first. Bare GetPanelByName often hits stash.
        for pi = 1, #prefixes do
            local prefix = prefixes[pi]
            if prefix then
                local path = Script.Indicator.JoinPath(prefix, leaf)
                local cand = Script.Indicator.WalkPath(path) or Script.Indicator.ResolvePanel(path)
                if cand
                    and not Script.Indicator.IsStashRelated(cand)
                then
                    local b = nil
                    Ind.boundsCache[cacheKey] = nil
                    Ind.panelPaths[cacheKey] = path
                    b = Script.Indicator.GetPanelBoundsCached(cacheKey, cand)
                    if b then
                        panel = cand
                        Ind.hudItemPrefix = prefix
                        break
                    end
                end
            end
        end
        if not panel then
            local byName = Script.Indicator.ResolveByName(leaf)
            if byName and not Script.Indicator.IsStashRelated(byName) then
                Ind.panelPaths[cacheKey] = Ind.hudItemPrefix
                        and Script.Indicator.JoinPath(Ind.hudItemPrefix, leaf)
                    or { leaf }
                Ind.boundsCache[cacheKey] = nil
                if Script.Indicator.GetPanelBoundsCached(cacheKey, byName) then
                    panel = byName
                end
            end
        end
        if panel then
            Ind.itemPanels[slot] = panel
            Ind.boundsCache[cacheKey] = nil
        else
            Ind.itemPanels[slot] = nil
            Ind.boundsCache[cacheKey] = nil
        end
    end

    -- Drop duplicate panel handles (same object bound to multiple slots).
    for slot = 0, Ind.ITEM_SLOTS - 1 do
        local p = Ind.itemPanels[slot]
        if p then
            for other = slot + 1, Ind.ITEM_SLOTS - 1 do
                if Ind.itemPanels[other] == p then
                    Ind.itemPanels[other] = nil
                    Ind.boundsCache["it" .. tostring(other)] = nil
                end
            end
        end
    end

    local neutral = nil
    if Ind.hudItemPrefix then
        local npath = Script.Indicator.JoinPath(Ind.hudItemPrefix, "inventory_neutral_slot")
        neutral = Script.Indicator.WalkPath(npath) or Script.Indicator.ResolvePanel(npath)
        if neutral and Script.Indicator.IsStashRelated(neutral) then
            neutral = nil
        end
        if neutral then
            Ind.panelPaths.neutral = npath
        end
    end
    if not neutral then
        local byName = Script.Indicator.ResolveByName("inventory_neutral_slot")
        if byName and not Script.Indicator.IsStashRelated(byName) then
            neutral = byName
            Ind.panelPaths.neutral = { "inventory_neutral_slot" }
        end
    end
    if neutral then
        Ind.neutralPanel = neutral
        Ind.boundsCache.neutral = nil
    end

    Ind.itemSlotBounds = nil
    Ind.itemBoundsAt = -math.huge
end

---Discover any reachable HUD root, then FindChildTraverse Ability0 / inventory_slot_0.
---@return boolean
function Script.Indicator.ProbeDiscover()
    local Ind = Script.Indicator
    local rootIds = {
        "DotaHud",
        "HUDElements",
        "Hud",
        "hud",
        "DOTAHud",
        "lower_hud",
        "center_with_stats",
        "center_block",
        "AbilitiesAndStatBranch",
        "abilities",
        "inventory",
        "inventory_items",
        "inventory_list",
        "inventory_list_container",
        "AbilityDraftHitTarget",
        "PagePlay",
    }
    local leafAbility = { "Ability0", "AbilityButton0", "ability0", "ButtonAndLevel" }
    local leafItem = { "inventory_slot_0", "InventorySlot0", "inventory_slot0" }
    local typeNames = {
        "DOTAAbilityPanel",
        "DOTAAbilityButton",
        "AbilityPanel",
        "DOTAItemImage",
        "DOTAInventoryItem",
    }

    local roots = {}
    for i = 1, #rootIds do
        local id = rootIds[i]
        local panel = Script.Indicator.TryGetByName(id, false)
        if not panel then
            panel = Script.Indicator.TryGetByName(id, true)
        end
        if panel then
            roots[#roots + 1] = { id = id, panel = panel }
        end
    end

    -- Type-name probe: first panel of that type, walk to AbilityN siblings.
    for i = 1, #typeNames do
        local panel = Script.Indicator.TryGetByName(typeNames[i], true)
        if panel then
            local id = panel.GetID and SafeValue(panel.GetID, panel) or "?"
            local parent = panel.GetParent and SafeValue(panel.GetParent, panel) or nil
            local parentPanel = Script.Indicator.AsPanel(parent)
            if parentPanel then
                local ab0 = Script.Indicator.FindIn(parentPanel, "Ability0")
                if ab0 then
                    Ind.abilityPanels[0] = ab0
                    Ind.panelPaths.ab0 = { "Ability0" }
                end
            end
            -- If this panel itself is Ability0 container:
            if tostring(id) == "Ability0" then
                Ind.abilityPanels[0] = panel
                Ind.panelPaths.ab0 = { "Ability0" }
            end
        end
    end

    for r = 1, #roots do
        local root = roots[r]
        for a = 1, #leafAbility do
            local leaf = leafAbility[a]
            local found = Script.Indicator.FindIn(root.panel, leaf)
            if found then
                if leaf == "Ability0" or leaf == "AbilityButton0" or leaf == "ability0" then
                    Ind.abilityPanels[0] = found
                    Ind.panelPaths.ab0 = { leaf }
                elseif leaf == "ButtonAndLevel" then
                    -- Prefer parent AbilityN if present.
                    local parent = found.GetParent and SafeValue(found.GetParent, found) or nil
                    local pid = parent and parent.GetID and SafeValue(parent.GetID, parent) or nil
                    if type(pid) == "string" and string.match(pid, "^Ability%d+$") then
                        Ind.abilityPanels[0] = parent
                        Ind.panelPaths.ab0 = { pid }
                    else
                        Ind.abilityPanels[0] = found
                        Ind.panelPaths.ab0 = { leaf }
                    end
                end
                break
            end
        end
        for a = 1, #leafItem do
            local leaf = leafItem[a]
            local found = Script.Indicator.FindIn(root.panel, leaf)
            if found then
                Ind.itemPanels[0] = found
                Ind.panelPaths.it0 = { leaf }
                break
            end
        end
        if Ind.abilityPanels[0] and Ind.itemPanels[0] then
            break
        end
    end

    -- Fill Ability1.. / inventory_slot_1.. from parent of slot 0.
    if Ind.abilityPanels[0] then
        local ab0 = Ind.abilityPanels[0]
        local parent = ab0.GetParent and SafeValue(ab0.GetParent, ab0) or nil
        local b0 = Script.Indicator.GetPanelBoundsCached("ab0", ab0)
        for slot = 1, Ind.ABILITY_SLOTS - 1 do
            local leaf = "Ability" .. tostring(slot)
            local panel = (parent and Script.Indicator.FindIn(parent, leaf))
                or Script.Indicator.ResolveByName(leaf)
            if not panel then
                for r = 1, #roots do
                    panel = Script.Indicator.FindIn(roots[r].panel, leaf)
                    if panel then
                        break
                    end
                end
            end
            if panel then
                Ind.abilityPanels[slot] = panel
                Ind.panelPaths["ab" .. tostring(slot)] = { leaf }
            end
        end
        local ab1 = Ind.abilityPanels[1]
        if b0 and ab1 then
            local b1 = Script.Indicator.GetPanelBoundsCached("ab1", ab1)
            if b1 and b1.x > b0.x then
                Ind.slotPitch = b1.x - b0.x
            end
        end
    end

    if Ind.itemPanels[0] then
        local it0 = Ind.itemPanels[0]
        local parent = Script.Indicator.InventoryRootFrom(it0)
            or (it0.GetParent and Script.Indicator.AsPanel(SafeValue(it0.GetParent, it0)))
        Script.Indicator.GetPanelBoundsCached("it0", it0)
        for slot = 1, Ind.ITEM_SLOTS - 1 do
            local leaf = "inventory_slot_" .. tostring(slot)
            local panel = (parent and Script.Indicator.FindIn(parent, leaf))
                or Script.Indicator.ResolveByName(leaf)
            if not panel then
                for r = 1, #roots do
                    panel = Script.Indicator.FindIn(roots[r].panel, leaf)
                    if panel then
                        break
                    end
                end
            end
            if panel then
                Ind.itemPanels[slot] = panel
                Ind.panelPaths["it" .. tostring(slot)] = { leaf }
            end
        end
        local neutral = (parent and Script.Indicator.FindIn(parent, "inventory_neutral_slot"))
            or Script.Indicator.ResolveByName("inventory_neutral_slot")
        if neutral then
            Ind.neutralPanel = neutral
            Ind.panelPaths.neutral = { "inventory_neutral_slot" }
        end
    end

    return next(Ind.abilityPanels) ~= nil or next(Ind.itemPanels) ~= nil
end

---Fill Ability0..N / inventory_slot_0..N via GetPanelByName (hint-style).
---@return boolean
function Script.Indicator.ProbeByName()
    local Ind = Script.Indicator
    local ab0 = Script.Indicator.ResolveByName("Ability0")
    if ab0 then
        Ind.panelPaths.ab0 = { "Ability0", "ButtonAndLevel" }
        local draw0 = Script.Indicator.AbilityDrawPanel(ab0)
        Ind.abilityPanels[0] = draw0
        Script.Indicator.GetPanelBoundsCached("ab0", draw0)
        for slot = 1, Ind.ABILITY_SLOTS - 1 do
            local leaf = "Ability" .. tostring(slot)
            local panel = Script.Indicator.ResolveByName(leaf)
            if panel then
                Ind.abilityPanels[slot] = Script.Indicator.AbilityDrawPanel(panel)
                Ind.panelPaths["ab" .. tostring(slot)] = { leaf, "ButtonAndLevel" }
            end
        end
        local ab1 = Ind.abilityPanels[1]
        local b0b = Ind.boundsCache.ab0
        if b0b and ab1 then
            local b1 = Script.Indicator.GetPanelBoundsCached("ab1", ab1)
            if b1 and b1.x > b0b.x then
                Ind.slotPitch = b1.x - b0b.x
            end
        end
    end

    local it0 = Script.Indicator.ResolveByName("inventory_slot_0")
    if it0 then
        Ind.itemPanels[0] = it0
        Ind.panelPaths.it0 = { "inventory_slot_0" }
        Script.Indicator.GetPanelBoundsCached("it0", it0)
        for slot = 1, Ind.ITEM_SLOTS - 1 do
            local leaf = "inventory_slot_" .. tostring(slot)
            local panel = Script.Indicator.ResolveByName(leaf)
            if panel then
                Ind.itemPanels[slot] = panel
                Ind.panelPaths["it" .. tostring(slot)] = { leaf }
            end
        end
        Ind.neutralPanel = Script.Indicator.ResolveByName("inventory_neutral_slot")
        if Ind.neutralPanel then
            Ind.panelPaths.neutral = { "inventory_neutral_slot" }
        end
    end

    return next(Ind.abilityPanels) ~= nil or next(Ind.itemPanels) ~= nil
end

function Script.Indicator.ProbeHud()
    local Ind = Script.Indicator
    local now = SafeValue(GameRules.GetGameTime) or 0
    if Ind.hudReady == true then
        return true
    end
    if Ind.hudReady == false and (now - Ind.hudProbeAt) < 3.0 then
        return false
    end
    Ind.hudProbeAt = now
    Ind.abilityPanels = {}
    Ind.itemPanels = {}
    Ind.neutralPanel = nil
    Ind.boundsCache = {}
    Ind.boundsUseJs = nil
    Ind.slotPitch = nil
    Ind.panelPaths = {}

    if not Panorama then
        Ind.hudReady = false
        return false
    end

    local ok = Script.Indicator.ProbeByName()
    if not ok then
        ok = Script.Indicator.ProbeDiscover()
    end

    -- Fallback: classic HUD paths with WalkPath (FindChildTraverse per segment).
    if not ok then
        local abilityPrefixes = {
            {
                "HUDElements",
                "lower_hud",
                "center_with_stats",
                "center_block",
                "AbilitiesAndStatBranch",
                "abilities",
            },
            {
                "DotaHud",
                "HUDElements",
                "lower_hud",
                "center_with_stats",
                "center_block",
                "AbilitiesAndStatBranch",
                "abilities",
            },
            {
                "Hud",
                "lower_hud",
                "center_with_stats",
                "center_block",
                "AbilitiesAndStatBranch",
                "abilities",
            },
        }
        for i = 1, #abilityPrefixes do
            local prefix = abilityPrefixes[i]
            local path0 = Script.Indicator.JoinPath(prefix, "Ability0")
            local panel = Script.Indicator.WalkPath(path0)
            if panel then
                Ind.hudAbilityPrefix = prefix
                Ind.abilityPanels[0] = panel
                Ind.panelPaths.ab0 = path0
                for slot = 1, Ind.ABILITY_SLOTS - 1 do
                    local path = Script.Indicator.JoinPath(prefix, "Ability" .. tostring(slot))
                    Ind.abilityPanels[slot] = Script.Indicator.WalkPath(path)
                    Ind.panelPaths["ab" .. tostring(slot)] = path
                end
                ok = true
                break
            end
        end

        local itemPrefixes = {
            {
                "HUDElements",
                "lower_hud",
                "center_with_stats",
                "center_block",
                "inventory",
                "inventory_items",
            },
            {
                "DotaHud",
                "HUDElements",
                "lower_hud",
                "center_with_stats",
                "center_block",
                "inventory",
                "inventory_items",
            },
            {
                "HUDElements",
                "lower_hud",
                "inventory_items",
            },
        }
        for i = 1, #itemPrefixes do
            local prefix = itemPrefixes[i]
            local path0 = Script.Indicator.JoinPath(prefix, "inventory_slot_0")
            local panel = Script.Indicator.WalkPath(path0)
            if panel then
                Ind.hudItemPrefix = prefix
                Ind.itemPanels[0] = panel
                Ind.panelPaths.it0 = path0
                for slot = 1, Ind.ITEM_SLOTS - 1 do
                    local path = Script.Indicator.JoinPath(
                        prefix,
                        "inventory_slot_" .. tostring(slot)
                    )
                    Ind.itemPanels[slot] = Script.Indicator.WalkPath(path)
                    Ind.panelPaths["it" .. tostring(slot)] = path
                end
                local npath = Script.Indicator.JoinPath(prefix, "inventory_neutral_slot")
                Ind.neutralPanel = Script.Indicator.WalkPath(npath)
                if Ind.neutralPanel then
                    Ind.panelPaths.neutral = npath
                end
                ok = true
                break
            end
        end
    end

    Ind.hudReady = ok
    if ok then
        Script.Indicator.SanitizeItemPanels()
    end
    return ok
end

---@param me userdata
---@return boolean drew
function Script.Indicator.DrawNative(me)
    local Ind = Script.Indicator
    if not Script.Indicator.ProbeHud() then
        return false
    end

    local now = SafeValue(GameRules.GetGameTime) or 0
    -- Single restore after panels exist (ResolveByName spam caused the start hitch).
    if not Ind.shieldsRestored and (now - (Ind.restoreAt or -math.huge)) >= 0.2 then
        Ind.restoreAt = now
        Script.Indicator.ForceRestoreHudHitTest()
    end
    -- Re-bind inventory panels rarely (GetPanelByName is not free).
    local missingItemPanel = false
    local stashHit = false
    for slot = 0, Ind.ITEM_SLOTS - 1 do
        local p = Ind.itemPanels[slot]
        if not p then
            missingItemPanel = true
            break
        end
        if Script.Indicator.IsStashRelated(p) then
            stashHit = true
            break
        end
    end
    if Ind.neutralPanel and Script.Indicator.IsStashRelated(Ind.neutralPanel) then
        stashHit = true
    end
    if (missingItemPanel or stashHit) and (now - (Ind.sanitizeAt or -math.huge)) >= 0.25 then
        Ind.sanitizeAt = now
        Script.Indicator.SanitizeItemPanels()
        Ind.itemBoundsAt = -math.huge
        Ind.itemSlotBounds = nil
    end

    Script.Indicator.EnsureMaps()
    local drew = false
    local tracked = Ind.abilityTracked or {}

    if (not UI.AbilitiesIndicator or not UI.AbilitiesIndicator.Get or UI.AbilitiesIndicator:Get() == true) then
        for slot = 0, Ind.ABILITY_SLOTS - 1 do
            local panel = Ind.abilityPanels[slot]
            local bounds = Script.Indicator.GetPanelBoundsCached("ab" .. tostring(slot), panel)
            -- Panel image first; slot map is aligned 1:1 with Ability0..N (includes innate).
            -- Never badge the innate panel. Fall back to slot name for Field/Ult when
            -- AbilityImage src cannot be read.
            local panelName = Script.Indicator.AbilityNameFromPanel(panel)
            local slotName = Script.Indicator.HudAbilityName(me, slot)
            local name = nil
            if panelName == ABILITY.innate or slotName == ABILITY.innate then
                name = nil
            elseif panelName and tracked[panelName] then
                name = panelName
            elseif slotName and tracked[slotName] then
                name = slotName
            end
            if bounds and name and tracked[name] then
                local ix, iy, side = Script.Indicator.IconSquare(
                    bounds.x, bounds.y, bounds.w, bounds.h
                )
                drew = true
                local widget = UI.AbilitySelect
                local enabled = Script.Indicator.IsEnabled(widget, name)
                Script.Indicator.DrawBadge(ix, iy, side, enabled, widget, name)
            end
        end
    end

    if (not UI.ItemsIndicator or not UI.ItemsIndicator.Get or UI.ItemsIndicator:Get() == true) then
        local map = Ind.usageMap or {}
        ---@type table<integer, { x: number, y: number, w: number, h: number }>
        local slotBounds = Ind.itemSlotBounds
        if not slotBounds or (now - (Ind.itemBoundsAt or -math.huge)) >= Ind.BOUNDS_TTL then
            slotBounds = {}
            local goodCount = 0
            for slot = 0, Ind.ITEM_SLOTS - 1 do
                local bounds = Script.Indicator.GetPanelBoundsCached(
                    "it" .. tostring(slot),
                    Ind.itemPanels[slot]
                )
                if bounds then
                    slotBounds[slot] = bounds
                    goodCount = goodCount + 1
                end
            end
            if goodCount > 0 and goodCount < Ind.ITEM_SLOTS then
                Script.Indicator.FillItemGridBounds(slotBounds)
            end
            -- Persist synthetic cells into bounds cache so hit tests stay coherent.
            for slot = 0, Ind.ITEM_SLOTS - 1 do
                local b = slotBounds[slot]
                if b then
                    Ind.boundsCache["it" .. tostring(slot)] = {
                        x = b.x,
                        y = b.y,
                        w = b.w,
                        h = b.h,
                        at = now,
                    }
                end
            end
            Ind.itemSlotBounds = slotBounds
            Ind.itemBoundsAt = now
        end

        for slot = 0, Ind.ITEM_SLOTS - 1 do
            local panel = Ind.itemPanels[slot]
            local bounds = slotBounds[slot]
            local name = Script.Indicator.ItemNameFromPanel(panel)
            if not name then
                local item = SafeValue(NPC.GetItemByIndex, me, slot)
                if item then
                    name = SafeValue(Ability.GetName, item)
                end
            end
            local entry = (type(name) == "string" and map[name]) or nil
            if entry and bounds then
                local ix, iy, side = Script.Indicator.ItemIconSquare(bounds)
                drew = true
                local widget = UI.ItemUsageWidgets and UI.ItemUsageWidgets[entry.widget]
                local enabled = Script.Indicator.IsEnabled(widget, entry.uiId)
                Script.Indicator.DrawBadge(ix, iy, side, enabled, widget, entry.uiId)
            end
        end
        local neutral = SafeValue(NPC.GetItemByIndex, me, 16)
        if neutral then
            local name = SafeValue(Ability.GetName, neutral)
            local entry = (type(name) == "string" and map[name]) or nil
            local bounds = Script.Indicator.GetPanelBoundsCached("neutral", Ind.neutralPanel)
            if entry and bounds then
                local ix, iy, side = Script.Indicator.ItemIconSquare(bounds)
                drew = true
                local widget = UI.ItemUsageWidgets and UI.ItemUsageWidgets[entry.widget]
                local enabled = Script.Indicator.IsEnabled(widget, entry.uiId)
                Script.Indicator.DrawBadge(ix, iy, side, enabled, widget, entry.uiId)
            end
        end
    end

    return drew
end

---@return boolean
function Script.Indicator.IsVisibleWanted()
    if not UI.ready or not UI.Enabled or UI.Enabled:Get() ~= true then
        return false
    end
    if UI.ComboIndicator and UI.ComboIndicator.Get and UI.ComboIndicator:Get() ~= true then
        return false
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return false
    end
    return true
end

---@param widget any
---@param id string
---@return boolean
function Script.Indicator.IsEnabled(widget, id)
    if not widget or not widget.Get then
        return true
    end
    local ok, enabled = TryCall(widget.Get, widget, id)
    if ok and enabled ~= nil then
        return enabled == true
    end
    return true
end

---@param widget any
---@param id string
function Script.Indicator.Toggle(widget, id)
    if not widget or not widget.Set or not widget.Get then
        return
    end
    local ok, enabled = TryCall(widget.Get, widget, id)
    if not ok then
        return
    end
    TryCall(widget.Set, widget, id, enabled ~= true)
end

---@param me userdata
---@param hudSlot integer
---@return string|nil
function Script.Indicator.HudAbilityName(me, hudSlot)
    local Ind = Script.Indicator
    local now = SafeValue(GameRules.GetGameTime) or 0
    if (now - (Ind.abilityNamesAt or -math.huge)) >= 0.35 then
        Ind.abilityNamesAt = now
        ---@type table<integer, string|false>
        local map = {}
        local actual = 0
        local visible = 0
        while actual <= 40 and visible < Ind.ABILITY_SLOTS do
            local ability = SafeValue(NPC.GetAbilityByIndex, me, actual)
            actual = actual + 1
            if ability then
                local name = SafeValue(Ability.GetName, ability)
                -- Keep HUD slot indices aligned with Ability0..N panels (include innate).
                -- Badges still only draw for Multiselect-tracked abilities.
                local skip = SafeValue(Ability.IsHidden, ability) == true
                    or SafeValue(Ability.IsAttributes, ability) == true
                if type(name) == "string" then
                    if string.find(name, "special_bonus", 1, true)
                        or string.find(name, "generic_hidden", 1, true)
                        or string.sub(name, 1, 5) == "item_"
                    then
                        skip = true
                    end
                end
                if not skip then
                    if type(name) == "string" and name ~= "" then
                        map[visible] = name
                    else
                        map[visible] = false
                    end
                    visible = visible + 1
                end
            end
        end
        Ind.abilityNamesByHud = map
    end
    local cached = Ind.abilityNamesByHud[hudSlot]
    if cached == false or cached == nil then
        return nil
    end
    return cached
end

---Read panorama image path only from Image-typed panels (avoids host ERROR spam).
---@param panel UIPanel|nil
---@return string|nil
function Script.Indicator.SafeImageSrc(panel)
    local typed = Script.Indicator.AsPanel(panel)
    if not typed or not typed.GetImageSrc or not typed.GetPanelType then
        return nil
    end
    local okType, ptype = TryCall(typed.GetPanelType, typed)
    if not okType or type(ptype) ~= "string" then
        return nil
    end
    if not string.find(string.lower(ptype), "image", 1, true) then
        return nil
    end
    local src = SafeValue(typed.GetImageSrc, typed)
    if type(src) == "string" and src ~= "" then
        return src
    end
    return nil
end

---Read ability id from the HUD icon itself (avoids slot-shift / enemy-HUD mismatches).
---@param panel UIPanel|nil
---@return string|nil
function Script.Indicator.AbilityNameFromPanel(panel)
    local typed = Script.Indicator.AsPanel(panel)
    if not typed then
        return nil
    end
    local src = Script.Indicator.SafeImageSrc(typed)
    if not src then
        src = Script.Indicator.SafeImageSrc(Script.Indicator.FindIn(typed, "AbilityImage"))
    end
    if type(src) ~= "string" or src == "" then
        return nil
    end
    local name = string.match(src, "spellicons/([%w_]+)_png")
    if not name then
        name = string.match(src, "spellicons/([%w_]+)")
    end
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

---Read item id from the HUD ItemImage (keeps badges aligned to the visible slot).
---@param panel UIPanel|nil
---@return string|nil
function Script.Indicator.ItemNameFromPanel(panel)
    local typed = Script.Indicator.AsPanel(panel)
    if not typed then
        return nil
    end
    local src = Script.Indicator.SafeImageSrc(typed)
    if not src then
        src = Script.Indicator.SafeImageSrc(Script.Indicator.FindIn(typed, "ItemImage"))
    end
    if type(src) ~= "string" or src == "" then
        return nil
    end
    local leaf = string.match(src, "items/([%w_]+)_png")
    if not leaf then
        leaf = string.match(src, "items/([%w_]+)")
    end
    if type(leaf) ~= "string" or leaf == "" then
        return nil
    end
    if string.sub(leaf, 1, 5) == "item_" then
        return leaf
    end
    return "item_" .. leaf
end

---True when local Snapfire is in the current selection (enemy inspect must not keep badges).
---@param me userdata
---@return boolean
function Script.Indicator.IsLocalHeroSelected(me)
    if not Players or not Player or not Player.GetSelectedUnits then
        return true
    end
    local player = SafeValue(Players.GetLocal)
    if not player then
        return true
    end
    local selected = SafeValue(Player.GetSelectedUnits, player)
    if type(selected) ~= "table" then
        return true
    end
    local count = 0
    for i = 1, 16 do
        local unit = selected[i]
        if unit == nil then
            break
        end
        count = count + 1
        if unit == me then
            return true
        end
    end
    -- Some builds expose 0-based arrays.
    if count == 0 then
        for i = 0, 15 do
            local unit = selected[i]
            if unit == nil and i > 0 then
                break
            end
            if unit == me then
                return true
            end
            if unit ~= nil then
                count = count + 1
            end
        end
    end
    -- Empty selection: keep drawing on the local HUD.
    return count == 0
end

---@param iconX number
---@param iconY number
---@param iconW number
---@param enabled boolean
---@param widget any
---@param toggleId string
function Script.Indicator.DrawBadge(iconX, iconY, iconW, enabled, widget, toggleId)
    local Ind = Script.Indicator
    local font = Script.Indicator.EnsureFont()
    local label = enabled and "ON" or "OFF"
    local fontSize = 11
    if iconW >= 48 then
        fontSize = 12
    elseif iconW < 32 then
        fontSize = 10
    end

    local sizeKey = label .. tostring(fontSize)
    local cachedSize = Ind.badgeTextSize[sizeKey]
    local tw, th
    if cachedSize then
        tw, th = cachedSize.w, cachedSize.h
    else
        tw = fontSize * (#label * 0.62)
        th = fontSize
        if font ~= 0 and Render and Render.TextSize then
            local okSize, size = TryCall(Render.TextSize, font, fontSize, label)
            if okSize and size and type(size.x) == "number" and type(size.y) == "number" then
                tw, th = size.x, size.y
            end
        end
        Ind.badgeTextSize[sizeKey] = { w = tw, h = th }
    end

    -- Top-right of icon; text only (no background plate).
    local bx = iconX + iconW - tw - 2
    local by = iconY + 1
    if bx < iconX then
        bx = iconX
    end
    local color = enabled and (Ind.colorOn or Color(255, 148, 64, 245))
        or (Ind.colorOff or Color(175, 178, 185, 230))
    local shadow = Ind.colorShadow or Color(0, 0, 0, 220)

    if font ~= 0 and Render and Render.Text then
        TryCall(Render.Text, font, fontSize, label, Vec2(bx + 1, by + 1), shadow)
        TryCall(Render.Text, font, fontSize, label, Vec2(bx, by), color)
    end

    Ind.hits[#Ind.hits + 1] = {
        x = iconX,
        y = iconY,
        w = iconW,
        h = iconW,
        widget = widget,
        id = toggleId,
    }
end

---@param slotPanel UIPanel
---@return UIPanel
function Script.Indicator.ItemDrawPanel(slotPanel)
    local image = Script.Indicator.FindIn(slotPanel, "ItemImage")
        or Script.Indicator.FindIn(slotPanel, "AbilityButton")
        or Script.Indicator.FindIn(slotPanel, "Button")
    if image then
        return image
    end
    return slotPanel
end

---Clickable inventory child (Button eats use; ItemImage alone often does not).
---@param slotPanel UIPanel
---@return UIPanel
function Script.Indicator.ItemClickPanel(slotPanel)
    local button = Script.Indicator.FindIn(slotPanel, "Button")
        or Script.Indicator.FindIn(slotPanel, "AbilityButton")
        or Script.Indicator.FindIn(slotPanel, "ItemImage")
    if button then
        return button
    end
    return slotPanel
end

---Right-align icon square inside panel bounds (inventory slots often include left chrome).
---@param bounds { x: number, y: number, w: number, h: number }
---@return number, number, number
function Script.Indicator.ItemIconSquare(bounds)
    local ix, iy, side = Script.Indicator.IconSquare(bounds.x, bounds.y, bounds.w, bounds.h)
    if bounds.w > side + 1 then
        ix = bounds.x + bounds.w - side
    end
    return ix, iy, side
end

---@return number|nil, number|nil
function Script.Indicator.CursorXY()
    -- Prefer Input (two returns); fall back to Render like other HUD scripts.
    if Input and Input.GetCursorPos then
        local ok, a, b = TryCall(Input.GetCursorPos)
        if ok and type(a) == "number" and type(b) == "number" then
            return a, b
        end
        if ok and a ~= nil and type(a) ~= "number" and type(a) ~= "string" then
            local ox, x = TryCall(function()
                return a.x
            end)
            local oy, y = TryCall(function()
                return a.y
            end)
            if ox and oy and type(x) == "number" and type(y) == "number" then
                return x, y
            end
        end
    end
    if Render and Render.GetCursorPos then
        local ok, a, b = TryCall(Render.GetCursorPos)
        if ok and type(a) == "number" and type(b) == "number" then
            return a, b
        end
        if ok and a ~= nil and type(a) ~= "number" and type(a) ~= "string" then
            local ox, x = TryCall(function()
                return a.x
            end)
            local oy, y = TryCall(function()
                return a.y
            end)
            if ox and oy and type(x) == "number" and type(y) == "number" then
                return x, y
            end
        end
    end
    return nil, nil
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param mx number
---@param my number
---@return boolean
function Script.Indicator.PointInRect(x, y, w, h, mx, my)
    return mx >= x and my >= y and mx <= (x + w) and my <= (y + h)
end

---@return { x: number, y: number, w: number, h: number, widget: any, id: string }|nil
function Script.Indicator.HitAtCursor()
    local Ind = Script.Indicator
    local mx, my = Script.Indicator.CursorXY()
    if not mx or not my then
        return nil
    end
    for i = #Ind.hits, 1, -1 do
        local hit = Ind.hits[i]
        if Script.Indicator.PointInRect(hit.x, hit.y, hit.w, hit.h, mx, my) then
            return hit
        end
    end
    return nil
end

---@param panel UIPanel|nil
---@param enabled boolean
function Script.Indicator.SetPanelHitTest(panel, enabled)
    local typed = Script.Indicator.AsPanel(panel)
    if not typed or not typed.BSetProperty then
        return
    end
    TryCall(typed.BSetProperty, typed, "hittest", enabled and "true" or "false")
end

---Disable a leftover click-shield panel (old builds created these; they eat LMB/RMB).
---@param shield UIPanel|nil
function Script.Indicator.DisableShieldPanel(shield)
    local typed = Script.Indicator.AsPanel(shield)
    if not typed then
        return
    end
    if typed.BSetProperty then
        TryCall(typed.BSetProperty, typed, "hittest", "false")
    end
    if typed.SetVisible then
        TryCall(typed.SetVisible, typed, false)
    end
    if typed.SetStyle then
        TryCall(typed.SetStyle, typed, "width:0px;height:0px;hittest:false;")
    end
end

---Re-enable HUD clickability and kill leftover sf_ind_* shields.
function Script.Indicator.ForceRestoreHudHitTest()
    local Ind = Script.Indicator

    ---@param panel UIPanel|nil
    ---@param shieldKey string|nil
    local function restoreOne(panel, shieldKey)
        local typed = Script.Indicator.AsPanel(panel)
        if not typed then
            return
        end
        Script.Indicator.SetPanelHitTest(typed, true)
        if shieldKey then
            Script.Indicator.DisableShieldPanel(Script.Indicator.ResolveByName("sf_ind_" .. shieldKey))
            Script.Indicator.DisableShieldPanel(
                Script.Indicator.FindIn(typed, "sf_ind_" .. shieldKey)
            )
        end
    end

    for slot = 0, Ind.ABILITY_SLOTS - 1 do
        restoreOne(Ind.abilityPanels[slot], "ab" .. tostring(slot))
    end
    for slot = 0, Ind.ITEM_SLOTS - 1 do
        local key = "it" .. tostring(slot)
        local panel = Ind.itemPanels[slot]
        restoreOne(panel, key)
        if Script.Indicator.PanelOk(panel) then
            local click = Script.Indicator.ItemClickPanel(panel)
            if click then
                Script.Indicator.SetPanelHitTest(click, true)
            end
        end
    end
    restoreOne(Ind.neutralPanel, "neutral")
    if Script.Indicator.PanelOk(Ind.neutralPanel) then
        local click = Script.Indicator.ItemClickPanel(Ind.neutralPanel)
        if click then
            Script.Indicator.SetPanelHitTest(click, true)
        end
    end

    for key, shield in pairs(Ind.shields) do
        Script.Indicator.DisableShieldPanel(shield)
        Ind.shields[key] = nil
    end
    Ind.shields = {}
    if next(Ind.abilityPanels) ~= nil or next(Ind.itemPanels) ~= nil then
        Ind.shieldsRestored = true
    end
end

---Arm a short cast-veto window for the badged ability/item under the cursor.
---@param hit { id: string }|nil
function Script.Indicator.ArmMmbCastBlock(hit)
    if not hit or type(hit.id) ~= "string" or hit.id == "" then
        return
    end
    local now = SafeValue(GameRules.GetGameTime) or 0
    Script.Indicator.blockUntil = now + 0.6
    Script.Indicator.blockAbilityId = hit.id
end

---MMB-only: toggle + block the in-game MMB cast bind. LMB/RMB never intercepted.
function Script.Indicator.ProcessPointer()
    local Ind = Script.Indicator
    if not Script.Indicator.IsVisibleWanted() then
        Ind.ptrMmb = false
        return
    end
    local hit = Script.Indicator.HitAtCursor()

    local overMenu = Menu and Menu.Opened and SafeValue(Menu.Opened) == true
    local mmb = false
    if Input and Input.IsKeyDown then
        mmb = SafeValue(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE3, true) == true
    end

    local mmbOk = not UI.MmbOnIcon or not UI.MmbOnIcon.Get or UI.MmbOnIcon:Get() == true
    if mmbOk and hit and hit.widget and hit.id and not overMenu then
        local now = SafeValue(GameRules.GetGameTime) or 0
        local cool = (now - (Ind.toggleAt or -math.huge)) >= 0.15
        if cool and mmb and not Ind.ptrMmb then
            Ind.toggleAt = now
            Script.Indicator.Toggle(hit.widget, hit.id)
            Script.Indicator.ArmMmbCastBlock(hit)
        elseif mmb then
            -- Keep veto alive while MMB is held over the badge (order may fire late).
            Script.Indicator.ArmMmbCastBlock(hit)
        end
    end

    Ind.ptrMmb = mmb
end

---Swallow only MMB while cursor is over a badged icon. Never touch LMB/RMB.
---@param key Enum.ButtonCode
---@param event Enum.EKeyEvent|nil
---@return boolean|nil
function Script.Indicator.OnKeyEvent(key, event)
    if key ~= Enum.ButtonCode.KEY_MOUSE3 then
        return
    end
    if not Script.Indicator.IsVisibleWanted() then
        return
    end
    local mmbOk = not UI.MmbOnIcon or not UI.MmbOnIcon.Get or UI.MmbOnIcon:Get() == true
    if not mmbOk then
        return
    end
    local hit = Script.Indicator.HitAtCursor()
    if hit == nil then
        return
    end

    local isDown = event == nil or event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN
    if isDown then
        local overMenu = Menu and Menu.Opened and SafeValue(Menu.Opened) == true
        if not overMenu and hit.widget and hit.id then
            local now = SafeValue(GameRules.GetGameTime) or 0
            local cool = (now - (Script.Indicator.toggleAt or -math.huge)) >= 0.15
            if cool then
                Script.Indicator.toggleAt = now
                Script.Indicator.Toggle(hit.widget, hit.id)
            end
        end
    end
    -- Arm on down and up so late HUD cast orders still get vetoed.
    Script.Indicator.ArmMmbCastBlock(hit)

    return false
end

---Veto MMB-driven ability/item casts on badged icons. Never touches LMB/RMB sell/cast.
---@param order Enum.UnitOrder|nil
---@param ability userdata|nil
---@return boolean
function Script.Indicator.ShouldBlockOrder(order, ability)
    if not Script.Indicator.IsVisibleWanted() then
        return false
    end
    local mmbOk = not UI.MmbOnIcon or not UI.MmbOnIcon.Get or UI.MmbOnIcon:Get() == true
    if not mmbOk then
        return false
    end
    if not Input or not Input.IsKeyDown then
        return false
    end
    -- Never interfere with left-click cast or right-click sell/disassemble.
    if SafeValue(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1, true) == true then
        return false
    end
    if SafeValue(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE2, true) == true then
        return false
    end

    local UO = Enum.UnitOrder
    if order == UO.DOTA_UNIT_ORDER_SELL_ITEM
        or order == UO.DOTA_UNIT_ORDER_DISASSEMBLE_ITEM
        or order == UO.DOTA_UNIT_ORDER_MOVE_ITEM
        or order == UO.DOTA_UNIT_ORDER_DROP_ITEM
        or order == UO.DOTA_UNIT_ORDER_GIVE_ITEM
        or order == UO.DOTA_UNIT_ORDER_PICKUP_ITEM
        or order == UO.DOTA_UNIT_ORDER_PURCHASE_ITEM
    then
        return false
    end

    local isCast = order == UO.DOTA_UNIT_ORDER_CAST_POSITION
        or order == UO.DOTA_UNIT_ORDER_CAST_TARGET
        or order == UO.DOTA_UNIT_ORDER_CAST_TARGET_TREE
        or order == UO.DOTA_UNIT_ORDER_CAST_NO_TARGET
        or order == UO.DOTA_UNIT_ORDER_CAST_TOGGLE
        or order == UO.DOTA_UNIT_ORDER_CAST_TOGGLE_AUTO
        or order == UO.DOTA_UNIT_ORDER_CAST_TOGGLE_ALT
        or order == UO.DOTA_UNIT_ORDER_CONSUME_ITEM
    if order ~= nil and not isCast then
        return false
    end

    local Ind = Script.Indicator
    local now = SafeValue(GameRules.GetGameTime) or 0
    local armed = now < (Ind.blockUntil or -math.huge)
    local mmb = SafeValue(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE3, true) == true
    local hit = Script.Indicator.HitAtCursor()
    if not armed and not (mmb and hit ~= nil) then
        return false
    end

    local castName = nil
    if ability ~= nil and Ability and Ability.GetName then
        castName = SafeValue(Ability.GetName, ability)
    end
    local blockId = Ind.blockAbilityId
    if type(blockId) == "string" and castName and castName ~= "" then
        return castName == blockId
    end
    if hit and castName and castName ~= "" then
        return hit.id == castName
    end
    -- Ability missing from the order: still veto while MMB owns the badge click.
    return armed or (mmb and hit ~= nil)
end

function Script.Indicator.Draw()
    local Ind = Script.Indicator
    Ind.hits = {}

    if not Script.Indicator.IsVisibleWanted() then
        return
    end
    if not SafeValue(Engine.IsInGame) then
        return
    end
    if not Render or not Render.ScreenSize then
        return
    end

    local me = SafeValue(Heroes.GetLocal)
    if me == nil or not IsLocalDisruptor(me) or not IsValidUnit(me) then
        return
    end
    -- Enemy/ally inspect: HUD icons change but Heroes.GetLocal stays Snapfire.
    if not Script.Indicator.IsLocalHeroSelected(me) then
        return
    end

    local screen = SafeValue(Render.ScreenSize)
    if not screen or type(screen.x) ~= "number" or screen.x <= 1 or type(screen.y) ~= "number" or screen.y <= 1 then
        return
    end

    if not Ind.colorOn then
        Script.Indicator.RefreshTheme()
    end

    Script.Indicator.DrawNative(me)
end

--#endregion



---@param me userdata
---@param abilityName string
---@return userdata|nil
local function GetAbility(me, abilityName)
    return SafeValue(NPC.GetAbility, me, abilityName)
end

---@param ability userdata|nil
---@param me userdata
---@return boolean
local function CanCastAbility(ability, me)
    if not ability then
        return false
    end
    local level = SafeValue(Ability.GetLevel, ability) or 0
    if level <= 0 then
        return false
    end
    if SafeValue(Ability.IsHidden, ability) == true then
        return false
    end
    local exec = SafeValue(Ability.CanBeExecuted, ability)
    if exec ~= nil and exec ~= Enum.AbilityCastResult.READY then
        return false
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return false
    end
    if SafeValue(Ability.IsChannelling, ability) == true then
        return false
    end
    local mana = SafeValue(NPC.GetMana, me) or 0
    return SafeValue(Ability.IsCastable, ability, mana) == true
end



---@param ability userdata|nil
---@param key string
---@param fallback number
---@return number
local function GetSpecial(ability, key, fallback)
    if not ability then
        return fallback
    end
    local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, key)
    if type(value) == "number" then
        return value
    end
    return fallback
end

---Remaining stun time on unit (cookie lands as modifier_stunned).
---@param unit userdata
---@param now number
---@return number|nil
local function GetStunRemaining(unit, now)
    local mod = SafeValue(NPC.GetModifier, unit, "modifier_stunned")
    if not mod then
        return nil
    end
    local dieTime = SafeValue(Modifier.GetDieTime, mod)
    if type(dieTime) == "number" and dieTime > now then
        return dieTime - now
    end
    local duration = SafeValue(Modifier.GetDuration, mod)
    local created = SafeValue(Modifier.GetCreationTime, mod)
    if type(duration) == "number" and duration > 0 and type(created) == "number" then
        local remaining = duration - (now - created)
        if remaining > 0 then
            return remaining
        end
    end
    return nil
end



---True while Field/Storm still need to fire in the Disruptor chain.
---@param me userdata
---@return boolean
local function IsComboFollowupPending(me)
    if IsAbilityEnabled(ABILITY.field) then
        local field = GetAbility(me, ABILITY.field)
        if field and (Runtime.abilityIssued[ABILITY.field] or CanCastAbility(field, me)) then
            return true
        end
    end
    if IsAbilityEnabled(ABILITY.storm) then
        local storm = GetAbility(me, ABILITY.storm)
        if storm and (Runtime.abilityIssued[ABILITY.storm] or CanCastAbility(storm, me)) then
            return true
        end
    end
    return false
end

local ABILITY_ISSUE_TIMEOUT = 2.0
-- Interrupted casts (still ready, not in phase, queue empty) retry after this.
local ABILITY_ISSUE_CANCEL_TIMEOUT = 0.85

---True after the game accepted the cast: cooldown started, or a charge was spent.
---@param abilityName string
---@param ability userdata|nil
---@return boolean
local function IsAbilitySpent(abilityName, ability)
    if not ability then
        return true
    end
    if SafeValue(Ability.IsHidden, ability) == true then
        return true
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return false
    end
    local cd = SafeValue(Ability.GetCooldown, ability) or 0
    if cd > 0.05 then
        return true
    end

    -- Charge skills (Glimpse): CD stays 0 while charges remain.
    local chargesBefore = Runtime.abilityIssuedCharges[abilityName]
    local chargesNow = SafeValue(Ability.GetCurrentCharges, ability)
    if type(chargesBefore) == "number" and type(chargesNow) == "number" and chargesNow < chargesBefore then
        return true
    end

    -- Charge Glimpse: SecondsSinceLastUse is often -1 while charges remain.
    -- After cast point, treat the issued cast as spent so we never double-cast.
    if Runtime.abilityIssued[abilityName]
        and (
            abilityName == ABILITY.glimpse
            or (type(chargesBefore) == "number" and chargesBefore > 0)
        )
    then
        local now = SafeValue(GameRules.GetGameTime) or 0
        local issuedAt = Runtime.abilityIssuedAt[abilityName] or now
        local elapsed = now - issuedAt
        local inPhase = SafeValue(Ability.IsInAbilityPhase, ability) == true
        local castPoint = SafeValue(Ability.GetCastPoint, ability, true)
        if type(castPoint) ~= "number" or castPoint ~= castPoint or castPoint < 0.05 then
            castPoint = SafeValue(Ability.GetCastPoint, ability) or 0.2
        end
        if type(castPoint) ~= "number" or castPoint < 0.05 then
            castPoint = 0.2
        end
        if not inPhase and elapsed >= (castPoint + 0.12) then
            return true
        end
    end

    -- Cast accepted but CD/charges lag: SecondsSinceLastUse resets on successful issue.
    if Runtime.abilityIssued[abilityName] then
        local now = SafeValue(GameRules.GetGameTime) or 0
        local issuedAt = Runtime.abilityIssuedAt[abilityName] or now
        local elapsed = now - issuedAt
        local since = SafeValue(Ability.SecondsSinceLastUse, ability)
        if type(since) == "number"
            and since >= 0
            and elapsed >= 0.08
            and since <= (elapsed + 0.25)
            and since < 2.0
        then
            return true
        end
    end

    return false
end

local function ClearAbilityIssued(abilityName)
    Runtime.abilityIssued[abilityName] = nil
    Runtime.abilityIssuedAt[abilityName] = nil
    Runtime.abilityIssuedCharges[abilityName] = nil
end

---After Refresher/Shard lands: wait until Field and Storm fully end, then 2nd Q→E→R.
---@param me userdata|nil
function Script.ReArmAfterRefresher(me)
    local now = SafeValue(GameRules.GetGameTime) or 0
    me = me or SafeValue(Heroes.GetLocal)

    local field = me and GetAbility(me, ABILITY.field) or nil
    local storm = me and GetAbility(me, ABILITY.storm) or nil
    local formation, duration, total = DC.GetFieldLifetime(field)
    local stormDur = DC.GetStormDuration(storm)

    local fieldEnds = nil
    if type(Runtime.fieldEndsAt) == "number" and Runtime.fieldEndsAt > now then
        fieldEnds = Runtime.fieldEndsAt
    elseif type(Runtime.fieldCastAt) == "number" and Runtime.fieldCastAt > 0 then
        fieldEnds = Runtime.fieldCastAt + total
        Runtime.fieldEndsAt = fieldEnds
    end

    local stormEnds = nil
    if type(Runtime.stormEndsAt) == "number" and Runtime.stormEndsAt > now then
        stormEnds = Runtime.stormEndsAt
    elseif type(Runtime.stormCastAt) == "number" and Runtime.stormCastAt > 0 then
        stormEnds = Runtime.stormCastAt + stormDur
        Runtime.stormEndsAt = stormEnds
    end

    local waitUntil = nil
    if fieldEnds and stormEnds then
        waitUntil = math.max(fieldEnds, stormEnds)
    else
        waitUntil = fieldEnds or stormEnds
    end

    ClearAbilityIssued(ABILITY.thunder)
    ClearAbilityIssued(ABILITY.glimpse)
    ClearAbilityIssued(ABILITY.field)
    ClearAbilityIssued(ABILITY.fence)
    ClearAbilityIssued(ABILITY.storm)
    Runtime.blinkUsed = false
    Runtime.abilityChainStarted = false
    Runtime.refresherUsed = true
    -- Keep trapCenter / fieldEndsAt / stormEndsAt for wait; clear aim so 2nd cycle re-solves placement.
    if Runtime.fieldPos then
        Runtime.trapCenter = Runtime.fieldPos
    end
    Runtime.trapFieldRadius = DC.GetFieldRadius(field)
    Runtime.fieldLocked = false
    Runtime.fieldPos = nil
    Runtime.fencePos = nil
    Runtime.comboCompleteLogged = false
    Runtime.qDone = false
    Runtime.wDone = false
    Runtime.eDone = false
    Runtime.fenceDone = false
    Runtime.rDone = false
    Runtime.stageStartedAt = now
    Runtime.secondCycleWaitReason = "field_storm"

    if waitUntil and waitUntil > now + 0.05 then
        -- Open 2nd cycle slightly before the later of Field/Storm ends.
        local lead = DC.FIELD_SECOND_CYCLE_LEAD or 0.45
        Runtime.secondCycleAt = waitUntil - lead
        if Runtime.secondCycleAt < now then
            Runtime.secondCycleAt = now
        end
        Runtime.comboStage = "wait_trap"
        Dbg(
            "refresher: wait field/storm end then 2nd cycle (in %.2fs, field=%.2fs storm=%.2fs lead=%.2f)",
            Runtime.secondCycleAt - now,
            fieldEnds and (fieldEnds - now) or -1,
            stormEnds and (stormEnds - now) or -1,
            lead
        )
    else
        Runtime.secondCycleAt = now
        Runtime.comboStage = "idle"
        Dbg("refresher: second disruptor cycle armed (field/storm already ended)")
    end
end



---One-shot until the ability is truly spent (cooldown / charge spent / hidden).
---@param abilityName string
---@param ability userdata|nil
---@param me userdata
---@param readyOverride boolean|nil
---@return boolean
local function CanUseAbilityOnce(abilityName, ability, me, readyOverride)
    local now = SafeValue(GameRules.GetGameTime) or 0

    if Runtime.abilityIssued[abilityName] then
        if IsAbilitySpent(abilityName, ability) then
            local chargesNow = ability and SafeValue(Ability.GetCurrentCharges, ability) or nil
            ClearAbilityIssued(abilityName)
            Runtime.abilityConsumed = Runtime.abilityConsumed or {}
            Runtime.abilityConsumed[abilityName] = true
            Dbg(
                "ability consumed: %s cd=%.2f charges=%s",
                abilityName,
                ability and (SafeValue(Ability.GetCooldown, ability) or -1) or -1,
                tostring(chargesNow)
            )
            if abilityName == "item_refresher" or abilityName == "item_refresher_shard" then
                Script.ReArmAfterRefresher(me)
            end
            -- Toggle-on items: do not immediately re-arm and flip back off.
            if abilityName == "item_armlet" then
                return false
            end
            -- Charge Glimpse (and similar): still "ready" with charges left — do not re-arm this frame.
            if type(chargesNow) == "number" and chargesNow > 0 then
                return false
            end
        else
            local issuedAt = Runtime.abilityIssuedAt[abilityName] or now
            local stillReady = readyOverride
            if stillReady == nil then
                stillReady = ability ~= nil and CanCastAbility(ability, me)
            end
            local inPhase = ability ~= nil and SafeValue(Ability.IsInAbilityPhase, ability) == true
            local queueEmpty = GetOrderQueueCount() <= 0
            -- Charge skills stay CanCast after spend — never use the short cancel timeout.
            local chargesBefore = Runtime.abilityIssuedCharges[abilityName]
            local chargeSkill = (type(chargesBefore) == "number" and chargesBefore > 0)
                or abilityName == ABILITY.glimpse
            local timeout = (stillReady and not inPhase and queueEmpty and not chargeSkill)
                and ABILITY_ISSUE_CANCEL_TIMEOUT
                or ABILITY_ISSUE_TIMEOUT
            if (now - issuedAt) >= timeout then
                -- Charge Glimpse: never retry after a settled issue — prevents double-spend.
                if chargeSkill then
                    ClearAbilityIssued(abilityName)
                    Runtime.abilityConsumed = Runtime.abilityConsumed or {}
                    Runtime.abilityConsumed[abilityName] = true
                    Dbg(
                        "ability consumed: %s (charge settled, ready=%s)",
                        abilityName,
                        tostring(stillReady)
                    )
                    return false
                end
                ClearAbilityIssued(abilityName)
                Dbg(
                    "ability issue timeout: %s (ready=%s phase=%s queue=%d)",
                    abilityName,
                    tostring(stillReady),
                    tostring(inPhase),
                    GetOrderQueueCount()
                )
            else
                return false
            end
        end
    end

    local ready = readyOverride
    if ready == nil then
        ready = ability ~= nil and CanCastAbility(ability, me)
    end
    return ready == true
end

---@param abilityName string
---@param ability userdata|nil
---@param chargesBefore number|nil
---@param startChain boolean|nil  false = linkbreak / non-combo cast (do not arm ability chain)
local function MarkAbilityIssued(abilityName, ability, chargesBefore, startChain)
    Runtime.abilityIssued[abilityName] = true
    Runtime.abilityIssuedAt[abilityName] = SafeValue(GameRules.GetGameTime) or 0
    if chargesBefore ~= nil then
        Runtime.abilityIssuedCharges[abilityName] = chargesBefore
    else
        Runtime.abilityIssuedCharges[abilityName] = ability and SafeValue(Ability.GetCurrentCharges, ability) or nil
    end
    if startChain == false then
        return
    end
    if abilityName == ABILITY.thunder
        or abilityName == ABILITY.field
        or abilityName == ABILITY.fence
        or abilityName == ABILITY.storm
    then
        Runtime.abilityChainStarted = true
    end
end

---@param tag string|nil
---@return boolean
local function TagStartsComboChain(tag)
    if type(tag) ~= "string" then
        return true
    end
    -- Linkbreaker pops must not arm the Disruptor Q→E→R chain / skip items.
    if string.find(tag, "linkbreak_", 1, true) == 1 then
        return false
    end
    return true
end

---@param now number
---@param me userdata
---@param ability userdata|nil
---@param target userdata|nil
---@param tag string
---@return boolean
local function CastTarget(now, me, ability, target, tag)
    if not ability or not target then
        return false
    end
    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag) then
        return false
    end
    local chargesBefore = SafeValue(Ability.GetCurrentCharges, ability)
    local ok, err = TryCall(Ability.CastTarget, ability, target, false, true, true, OrderId(tag))
    if ok then
        MarkIssued(now, tag, GetBusyDuration(ability))
        local abilityName = SafeValue(Ability.GetName, ability)
        if abilityName then
            MarkAbilityIssued(abilityName, ability, chargesBefore, TagStartsComboChain(tag))
        end
        Dbg(
            "cast %s -> %s queue=%d busy=%.2f charges=%s",
            tag,
            FmtUnit(target),
            GetOrderQueueCount(),
            GetBusyDuration(ability),
            tostring(chargesBefore)
        )
        return true
    end
    Dbg("FAIL %s: %s", tag, tostring(err))
    return false
end

---@param now number
---@param me userdata
---@param ability userdata|nil
---@param pos Vector|nil
---@param tag string
---@param allowWhileChanneling boolean|nil
---@return boolean
local function CastPosition(now, me, ability, pos, tag, allowWhileChanneling)
    if not ability or not pos then
        return false
    end
    local okSend, reason = CanSendOrder(now, me, allowWhileChanneling == true)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag, CAST_GAP) then
        return false
    end
    local chargesBefore = SafeValue(Ability.GetCurrentCharges, ability)
    local ok, err = TryCall(Ability.CastPosition, ability, pos, false, true, true, OrderId(tag), true)
    if ok then
        local busy = allowWhileChanneling and 0.05 or GetBusyDuration(ability)
        MarkIssued(now, tag, busy)
        if not allowWhileChanneling then
            local abilityName = SafeValue(Ability.GetName, ability)
            if abilityName then
                MarkAbilityIssued(abilityName, ability, chargesBefore, TagStartsComboChain(tag))
            end
        end
        Dbg("cast %s @ %s queue=%d", tag, FmtPos(pos), GetOrderQueueCount())
        return true
    end
    Dbg("FAIL %s: %s", tag, tostring(err))
    return false
end

---@param now number
---@param me userdata
---@param ability userdata
---@param tag string
---@return boolean
local function CastNoTarget(now, me, ability, tag)
    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag) then
        return false
    end
    local chargesBefore = SafeValue(Ability.GetCurrentCharges, ability)
    local ok, err = TryCall(Ability.CastNoTarget, ability, false, true, true, OrderId(tag))
    if ok then
        MarkIssued(now, tag, GetBusyDuration(ability))
        local abilityName = SafeValue(Ability.GetName, ability)
        if abilityName then
            MarkAbilityIssued(abilityName, ability, chargesBefore)
        end
        Dbg("cast %s queue=%d", tag, GetOrderQueueCount())
        return true
    end
    Dbg("FAIL %s: %s", tag, tostring(err))
    return false
end

---@param now number
---@param me userdata
---@return boolean issuedHold
local function HoldForAbilityCast(now, me)
    -- Only stop an active attack swing.
    if SafeValue(NPC.IsAttacking, me) ~= true then
        return false
    end
    -- One hold is enough — next ticks cast cookie while buffs are still up.
    if (now - (Runtime.heldForCastAt or -math.huge)) < 0.22 then
        return false
    end
    local okSend = CanSendOrder(now, me, false)
    if not okSend then
        return false
    end
    if not CanIssue(now, "hold", 0.12) then
        return false
    end
    local player = SafeValue(Players.GetLocal)
    if not player then
        return false
    end
    local ok, err = TryCall(Player.HoldPosition, player, me, false, true, true, OrderId("hold"))
    if ok then
        Runtime.heldForCastAt = now
        MarkIssued(now, "hold", 0.05)
        Dbg("hold (stop attacks for cast)")
        return true
    end
    Dbg("FAIL hold: %s", tostring(err))
    return false
end

---Cancel MoveTo orbit (FaceToward chase) so close-range blast/cookie can cast.
---@param now number
---@param me userdata
---@return boolean issuedHold
local function StopOrbitIfRunning(now, me)
    -- Never cancel intentional step-back / micro-face walks.
    if SafeValue(NPC.IsRunning, me) ~= true then
        return false
    end
    if (now - (Runtime.heldForCastAt or -math.huge)) < 0.18 then
        return false
    end
    local okSend = CanSendOrder(now, me, false)
    if not okSend then
        return false
    end
    if not CanIssue(now, "hold", 0.10) then
        return false
    end
    local player = SafeValue(Players.GetLocal)
    if not player then
        return false
    end
    local ok, err = TryCall(Player.HoldPosition, player, me, false, true, true, OrderId("hold_orbit"))
    if ok then
        Runtime.heldForCastAt = now
        MarkIssued(now, "hold", 0.05)
        Dbg("hold (stop orbit for cast)")
        return true
    end
    Dbg("FAIL hold_orbit: %s", tostring(err))
    return false
end

---@param now number
---@param me userdata
---@param target userdata
---@return boolean
local function AttackEnemy(now, me, target)
    local tag = "attack"
    if SafeValue(NPC.IsAttacking, me) == true then
        return false
    end
    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        DbgThrottledSkipAttack(now, "skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag, ATTACK_GAP) then
        return false
    end
    local player = SafeValue(Players.GetLocal)
    if not player then
        DbgThrottledSkipAttack(now, "skip attack: no player")
        return false
    end
    local ok, err = TryCall(Player.AttackTarget, player, me, target, false, true, true, OrderId(tag), false)
    if ok then
        MarkIssued(now, tag, 0.15)
        Dbg("attack -> %s", FmtUnit(target))
        return true
    end
    Dbg("FAIL attack: %s", tostring(err))
    return false
end



---@param now number
---@param me userdata
---@param targetPos Vector
---@return boolean
local function FaceToward(now, me, targetPos)
    local tag = "face"
    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag, 0.25) then
        return false
    end
    local ok, err = TryCall(NPC.MoveTo, me, targetPos, false, false, false, true, OrderId(tag), false)
    if ok then
        MarkIssued(now, tag, 0.08)
        Dbg("face @ %s", FmtPos(targetPos))
        return true
    end
    Dbg("FAIL face: %s", tostring(err))
    return false
end



---True while Disruptor Q→E→Fence→R still owns the cast slot.
---@param me userdata
---@return boolean
function Script.IsMainComboBusy(me)
    if Runtime.comboStage == "wait_trap" then
        return true
    end
    if Runtime.comboStage == "cast" then
        if not (Runtime.qDone and Runtime.wDone and Runtime.eDone and Runtime.fenceDone and Runtime.rDone) then
            return true
        end
    end
    if Runtime.abilityChainStarted
        and Runtime.comboStage ~= "done"
        and Runtime.comboStage ~= "idle"
        and Runtime.comboStage ~= "wait_trap"
    then
        if not (Runtime.qDone and Runtime.wDone and Runtime.eDone and Runtime.fenceDone and Runtime.rDone) then
            return true
        end
    end
    if not Runtime.abilityChainStarted then
        return false
    end
    if Runtime.abilityIssued[ABILITY.thunder]
        or Runtime.abilityIssued[ABILITY.field]
        or Runtime.abilityIssued[ABILITY.fence]
        or Runtime.abilityIssued[ABILITY.storm]
    then
        return true
    end
    local function mainReady(abilityName)
        if not IsAbilityEnabled(abilityName) then
            return false
        end
        local ability = GetAbility(me, abilityName)
        return ability ~= nil and CanCastAbility(ability, me) == true
    end
    if mainReady(ABILITY.thunder)
        or mainReady(ABILITY.field)
        or mainReady(ABILITY.storm)
    then
        return true
    end
    return false
end



---@param me userdata
---@param aimPos Vector
---@param loose? boolean  urgent refresh: cast sooner when almost facing
---@return boolean
local function NeedsFaceForCookie(me, aimPos, loose)
    local limit = loose and 0.05 or 0.08
    local faceTime = SafeValue(NPC.GetTimeToFacePosition, me, aimPos)
    if type(faceTime) == "number" and faceTime > limit then
        return true
    end
    if SafeValue(NPC.IsTurning, me) == true then
        return true
    end
    return false
end



---@param now number
---@param me userdata
---@param itemId string
---@param tag string
---@return boolean
local function TryCastNoTargetItem(now, me, itemId, tag)
    if not IsItemUsageEnabled(itemId) then
        return false
    end
    local item = GetItem(me, itemId)
    if not item or not CanUseAbilityOnce(itemId, item, me, CanCastItem(item, me)) then
        return false
    end
    return CastNoTarget(now, me, item, tag)
end

---@param now number
---@param me userdata
---@param target userdata
---@param itemId string
---@param tag string
---@return boolean
local function TryCastTargetItem(now, me, target, itemId, tag)
    if not IsItemUsageEnabled(itemId) then
        return false
    end
    local item = GetItem(me, itemId)
    if not item or not CanUseAbilityOnce(itemId, item, me, CanCastItem(item, me)) then
        return false
    end
    local castRange = GetItemCastRange(me, item, Script.ItemRange[itemId] or 0)
    if not IsTargetInCastRange(me, target, castRange) then
        return false
    end
    return CastTarget(now, me, item, target, tag)
end

---@param now number
---@param me userdata
---@param pos Vector
---@param itemId string
---@param tag string
---@return boolean
local function TryCastPositionItem(now, me, pos, itemId, tag)
    if not IsItemUsageEnabled(itemId) then
        return false
    end
    local item = GetItem(me, itemId)
    if not item or not CanUseAbilityOnce(itemId, item, me, CanCastItem(item, me)) then
        return false
    end
    local castRange = GetItemCastRange(me, item, Script.ItemRange[itemId] or 0)
    if castRange <= 0 then
        return false
    end
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos or Dist2D(myPos, pos) > (castRange + 40) then
        return false
    end
    return CastPosition(now, me, item, pos, tag, false)
end

---Toggle an item ON (Armlet). Uses Ability.Toggle, not CastNoTarget.
---@param now number
---@param me userdata
---@param itemId string
---@param tag string
---@return boolean
local function TryToggleItemOn(now, me, itemId, tag)
    if not IsItemUsageEnabled(itemId) then
        return false
    end
    local item = GetItem(me, itemId)
    if not item or not CanCastItem(item, me) then
        return false
    end
    if SafeValue(Ability.GetToggleState, item) == true then
        return false
    end
    if itemId == "item_armlet" and SafeValue(NPC.HasModifier, me, ARMLET_UNHOLY_MOD) == true then
        return false
    end
    if not CanUseAbilityOnce(itemId, item, me, true) then
        return false
    end

    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag) then
        return false
    end

    local ok, err = TryCall(Ability.Toggle, item, false, true, true, OrderId(tag))
    if ok then
        MarkIssued(now, tag, 0.08)
        MarkAbilityIssued(itemId, item, nil)
        Dbg("toggle %s on queue=%d", tag, GetOrderQueueCount())
        return true
    end
    Dbg("FAIL %s: %s", tag, tostring(err))
    return false
end

---@param me userdata
---@return boolean
local function IsMainComboAbilityPending(me)
    if IsAbilityEnabled(ABILITY.thunder) then
        local thunder = GetAbility(me, ABILITY.thunder)
        if thunder and (Runtime.abilityIssued[ABILITY.thunder] or CanCastAbility(thunder, me)) then
            return true
        end
    end
    return IsComboFollowupPending(me)
end

---@param me userdata
---@param requireUsageEnabled boolean|nil
---@return userdata|nil
---@return string|nil
local function GetDagonItem(me, requireUsageEnabled)
    if requireUsageEnabled ~= false and not IsItemUsageEnabled("item_dagon") then
        return nil, nil
    end
    for i = #DAGON_ITEMS, 1, -1 do
        local id = DAGON_ITEMS[i]
        local item = GetItem(me, id)
        if item and CanCastItem(item, me) then
            return item, id
        end
    end
    return nil, nil
end

---@param me userdata
---@return userdata|nil
---@return string|nil
local function GetDiffusalItem(me)
    for i = 1, #DIFFUSAL_ITEMS do
        local id = DIFFUSAL_ITEMS[i]
        local item = GetItem(me, id)
        if item and CanCastItem(item, me) then
            return item, id
        end
    end
    return nil, nil
end

---@param me userdata
---@param itemId string
---@return userdata|nil
---@return string|nil
local function ResolveLinkbreakItem(me, itemId)
    if LINKBREAKER_ABILITIES[itemId] == true then
        local ability = GetAbility(me, itemId)
        if ability and CanCastAbility(ability, me) then
            return ability, itemId
        end
        return nil, nil
    end
    if itemId == "item_dagon" then
        return GetDagonItem(me, false)
    end
    if itemId == "item_diffusal_blade" then
        return GetDiffusalItem(me)
    end
    local item = GetItem(me, itemId)
    if item and CanCastItem(item, me) then
        return item, itemId
    end
    return nil, nil
end

---Resolve linkbreak ability/item even while on CD (for consume polling after issue).
---@param me userdata
---@param itemId string
---@return userdata|nil
---@return string|nil
local function ResolveLinkbreakIssued(me, itemId)
    if LINKBREAKER_ABILITIES[itemId] == true then
        local ability = GetAbility(me, itemId)
        if ability then
            return ability, itemId
        end
        return nil, nil
    end
    if itemId == "item_dagon" then
        for i = #DAGON_ITEMS, 1, -1 do
            local id = DAGON_ITEMS[i]
            local item = GetItem(me, id)
            if item then
                return item, id
            end
        end
        return nil, nil
    end
    if itemId == "item_diffusal_blade" then
        for i = 1, #DIFFUSAL_ITEMS do
            local id = DIFFUSAL_ITEMS[i]
            local item = GetItem(me, id)
            if item then
                return item, id
            end
        end
        return nil, nil
    end
    local item = GetItem(me, itemId)
    if item then
        return item, itemId
    end
    return nil, nil
end

---Confirm pending Linkbreaker casts so abilityIssued cannot stick forever.
---@param me userdata
function DC.PollLinkbreakConsume(me)
    for i = 1, #LINKBREAKER_ITEMS do
        local id = LINKBREAKER_ITEMS[i][1]
        if Runtime.abilityIssued[id] then
            local ab, resolvedId = ResolveLinkbreakIssued(me, id)
            local ready = false
            if ab and resolvedId then
                if LINKBREAKER_ABILITIES[resolvedId] == true then
                    ready = CanCastAbility(ab, me) == true
                else
                    ready = CanCastItem(ab, me) == true
                end
                CanUseAbilityOnce(resolvedId, ab, me, ready)
            else
                ClearAbilityIssued(id)
            end
            return
        end
    end
    if Runtime.abilityIssued["item_diffusal_blade_2"] then
        local item = GetItem(me, "item_diffusal_blade_2")
        CanUseAbilityOnce(
            "item_diffusal_blade_2",
            item,
            me,
            item ~= nil and CanCastItem(item, me)
        )
        return
    end
    for i = 1, #DAGON_ITEMS do
        local id = DAGON_ITEMS[i]
        if Runtime.abilityIssued[id] then
            local item = GetItem(me, id)
            CanUseAbilityOnce(id, item, me, item ~= nil and CanCastItem(item, me))
            return
        end
    end
end

---@param item userdata|nil
---@param itemId string
---@return number
local function GetLinkbreakPopCost(item, itemId)
    if LINKBREAKER_ABILITIES[itemId] == true then
        return LINKBREAKER_POP_COST[itemId] or 0
    end
    if item then
        local ok, cost = TryCall(Item.GetCost, item)
        if ok and type(cost) == "number" and cost > 0 then
            return cost
        end
    end
    return LINKBREAKER_POP_COST[itemId] or 99999
end

---@param itemId string
---@return boolean
local function IsLinkbreakBlockedByBkb(itemId)
    local uiId = NormalizeLinkbreakerUiId(itemId)
    if LINKBREAKER_BLOCKED_BY_BKB[itemId] or LINKBREAKER_BLOCKED_BY_BKB[uiId] then
        return true
    end
    if itemId == "item_diffusal_blade_2" then
        return true
    end
    if uiId == "item_dagon" then
        return true
    end
    return false
end

---Pop Linken's with the cheapest ready skill/item from Linkbreaker MultiSelect.
---@param now number
---@param me userdata
---@param target userdata|nil
---@return boolean
local function TryLinkbreaker(now, me, target)
    if not target or not TargetNeedsLinkBreak(target) then
        return false
    end
    -- Never pop while the Disruptor ability chain still owns the cast slot.
    if Script.IsMainComboBusy(me) then
        return false
    end
    -- Invulnerable / Eul: targeted pops fail and only produce issue-timeouts.
    if Script.IsComboWindowClosed(target, now) then
        return false
    end
    if Runtime.abilityIssued[ABILITY.thunder]
        or Runtime.abilityIssued[ABILITY.glimpse]
        or Runtime.abilityIssued[ABILITY.field]
        or Runtime.abilityIssued[ABILITY.storm]
    then
        return false
    end

    local magicImmune = IsMagicImmune(target)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    ---@type userdata|nil
    local bestItem = nil
    ---@type string|nil
    local bestId = nil
    local bestCost = math.huge
    local bestPoint = false

    for i = 1, #LINKBREAKER_ITEMS do
        local itemId = LINKBREAKER_ITEMS[i][1]
        if IsLinkbreakerEnabled(itemId)
            and not (magicImmune and IsLinkbreakBlockedByBkb(itemId))
        then
            local item, resolvedId = ResolveLinkbreakItem(me, itemId)
            if item and resolvedId then
                local readyOverride
                if LINKBREAKER_ABILITIES[resolvedId] == true then
                    readyOverride = CanCastAbility(item, me)
                else
                    readyOverride = CanCastItem(item, me)
                end
                if CanUseAbilityOnce(resolvedId, item, me, readyOverride) then
                    local castRange
                    if LINKBREAKER_ABILITIES[resolvedId] == true then
                        local fallback = resolvedId == ABILITY.glimpse and DC.W_RANGE or DC.Q_RANGE
                        castRange = DC.GetAbilityCastRange(me, item, fallback)
                    else
                        castRange = GetItemCastRange(
                            me,
                            item,
                            Script.ItemRange[resolvedId] or Script.ItemRange[itemId] or 0
                        )
                    end
                    if IsTargetInCastRange(me, target, castRange) then
                        local cost = GetLinkbreakPopCost(item, resolvedId)
                        if cost < bestCost then
                            bestItem = item
                            bestId = resolvedId
                            bestCost = cost
                            bestPoint = LINKBREAKER_POINT_CAST[itemId] == true
                                or LINKBREAKER_POINT_CAST[resolvedId] == true
                        end
                    end
                end
            end
        end
    end

    if not bestItem or not bestId then
        return false
    end

    local tag = "linkbreak_" .. tostring(bestId):gsub("^item_", ""):gsub("^disruptor_", "")
    if bestPoint then
        if not targetPos then
            return false
        end
        if CastPosition(now, me, bestItem, targetPos, tag, false) then
            Dbg("linkbreak %s @ %s cost=%d", bestId, FmtPos(targetPos), bestCost)
            return true
        end
        return false
    end

    if CastTarget(now, me, bestItem, target, tag) then
        Dbg("linkbreak %s -> %s cost=%d", bestId, FmtUnit(target), bestCost)
        return true
    end
    return false
end

---Refresher Orb / Shard: second Thunder → Glimpse → Field → Storm cycle.
---@param now number
---@param me userdata
---@return boolean
function Script.TryRefresher(now, me)
    if Runtime.comboStage ~= "done" and not Runtime.abilityChainStarted then
        return false
    end
    -- Only after a real Kinetic Field cast this cycle (not linkbreak-only / skills-on-CD abort).
    if type(Runtime.fieldCastAt) ~= "number" or Runtime.fieldCastAt <= 0 then
        return false
    end
    if Runtime.abilityIssued[ABILITY.thunder]
        or Runtime.abilityIssued[ABILITY.glimpse]
        or Runtime.abilityIssued[ABILITY.field]
        or Runtime.abilityIssued[ABILITY.fence]
        or Runtime.abilityIssued[ABILITY.storm]
    then
        return false
    end

    local function stillReady(abilityName)
        if not IsAbilityEnabled(abilityName) then
            return false
        end
        local ability = GetAbility(me, abilityName)
        return ability ~= nil and CanCastAbility(ability, me) == true
    end

    -- Wait until the main trap skills are spent (or disabled).
    if stillReady(ABILITY.thunder)
        or stillReady(ABILITY.field)
        or stillReady(ABILITY.storm)
    then
        return false
    end
    if IsAbilityEnabled(ABILITY.fence) and DC.HasShard(me) and stillReady(ABILITY.fence) then
        return false
    end

    if not IsItemUsageEnabled("item_refresher") then
        return false
    end

    local refresherIds = { "item_refresher_shard", "item_refresher" }
    ---@type userdata|nil
    local item = nil
    ---@type string|nil
    local itemId = nil
    for i = 1, #refresherIds do
        local id = refresherIds[i]
        local candidate = GetItem(me, id)
        if candidate and CanCastItem(candidate, me) then
            item = candidate
            itemId = id
            break
        end
    end
    if not item or not itemId then
        return false
    end
    if Runtime.refresherUsed then
        Runtime.refresherUsed = false
    end
    if not CanUseAbilityOnce(itemId, item, me, CanCastItem(item, me)) then
        return false
    end

    if HoldForAbilityCast(now, me) then
        return true
    end

    if CastNoTarget(now, me, item, "refresher") then
        Dbg("refresher cast %s (arming 2nd disruptor cycle)", itemId)
        return true
    end
    return false
end

---@param now number
---@param me userdata
---@return boolean
local function TryBloodstone(now, me)
    if SafeValue(NPC.HasModifier, me, "modifier_item_bloodstone_active") == true then
        return false
    end
    local threshold = 25
    if UI.BloodstoneHp and UI.BloodstoneHp.Get then
        threshold = tonumber(UI.BloodstoneHp:Get()) or 25
    end
    if GetHealthPct(me) > threshold then
        return false
    end
    return TryCastNoTargetItem(now, me, "item_bloodstone", "bloodstone")
end

---Emergency self-save: Glimmer → Force/Pike → Lotus when HP ≤ Self Save threshold.
---@param now number
---@param me userdata
---@return boolean
function DC.TrySelfSave(now, me)
    if not me then
        return false
    end
    local threshold = 35
    if UI.SelfSaveHp and UI.SelfSaveHp.Get then
        threshold = tonumber(UI.SelfSaveHp:Get()) or 35
    end
    if GetHealthPct(me) > threshold then
        return false
    end
    local okSend = select(1, CanSendOrder(now, me, false))
    if not okSend then
        return false
    end

    if SafeValue(NPC.HasModifier, me, "modifier_item_glimmer_cape_fade") ~= true then
        local glimmer = GetItem(me, "item_glimmer_cape")
        if glimmer and CanUseAbilityOnce("item_glimmer_cape", glimmer, me, CanCastItem(glimmer, me)) then
            if CastTarget(now, me, glimmer, me, "self_glimmer") then
                Dbg("self-save glimmer (hp<=%.0f)", threshold)
                return true
            end
        end
    end

    local force = GetItem(me, "item_force_staff") or GetItem(me, "item_hurricane_pike")
    if force then
        local forceId = SafeValue(Ability.GetName, force) or "item_force_staff"
        if CanUseAbilityOnce(forceId, force, me, CanCastItem(force, me)) then
            if CastTarget(now, me, force, me, "self_force") then
                Dbg("self-save force (hp<=%.0f)", threshold)
                return true
            end
        end
    end

    if SafeValue(NPC.HasModifier, me, "modifier_item_lotus_orb_active") ~= true then
        local lotus = GetItem(me, "item_lotus_orb")
        if lotus and CanUseAbilityOnce("item_lotus_orb", lotus, me, CanCastItem(lotus, me)) then
            if CastTarget(now, me, lotus, me, "self_lotus") then
                Dbg("self-save lotus (hp<=%.0f)", threshold)
                return true
            end
        end
    end
    return false
end

---@param now number
---@param me userdata
---@param targetPos Vector
---@return boolean
local function TryBlinkEngage(now, me, targetPos)
    if Runtime.blinkUsed then
        return false
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos or not targetPos then
        return false
    end

    ---@type userdata|nil
    local blink = nil
    ---@type string|nil
    local blinkId = nil

    -- Prefer dagger (no self-stun) over Fallen Sky when both are available.
    if IsItemUsageEnabled("item_blink") then
        for i = 1, #BLINK_DAGGER_ITEMS do
            local id = BLINK_DAGGER_ITEMS[i]
            local candidate = GetItem(me, id)
            if candidate and CanUseAbilityOnce(id, candidate, me, CanCastItem(candidate, me)) then
                blink = candidate
                blinkId = id
                break
            end
        end
    end

    if not blink and IsItemUsageEnabled("item_fallen_sky") then
        local fallen = GetItem(me, "item_fallen_sky")
        if fallen and CanUseAbilityOnce("item_fallen_sky", fallen, me, CanCastItem(fallen, me)) then
            blink = fallen
            blinkId = "item_fallen_sky"
        end
    end

    if not blink or not blinkId then
        return false
    end

    local landPos, desired = ComputeBlinkLandPos(me, myPos, targetPos, blink)
    if not landPos then
        return false
    end

    if CastPosition(now, me, blink, landPos, "blink_" .. blinkId, false) then
        Runtime.blinkUsed = true
        Dbg(
            "blink %s dist=%.0f desired=%.0f (q) -> %s",
            blinkId,
            Dist2D(myPos, targetPos),
            desired or -1,
            FmtPos(landPos)
        )
        return true
    end
    return false
end

---Important Items before ability chain. One order per call.
---@param now number
---@param me userdata
---@param target userdata
---@param targetPos Vector
---@return boolean
local function TryImportantItems(now, me, target, targetPos)
    -- While Cookie→Blast→Shredder still needs the cast slot, only Satanic.
    -- When those skills are on CD, allow Important items again (CD recycle).
    if Script.IsMainComboBusy(me) then
        if SafeValue(NPC.HasModifier, me, SATANIC_ACTIVE_MOD) ~= true then
            local threshold = 25
            if UI.SatanicHp and UI.SatanicHp.Get then
                threshold = tonumber(UI.SatanicHp:Get()) or 25
            end
            if GetHealthPct(me) <= threshold then
                if TryCastNoTargetItem(now, me, "item_satanic", "satanic") then
                    return true
                end
            end
        end
        return false
    end

    -- Linkens pop is handled separately by Linkbreaker Items — not here.
    local linkens = TargetNeedsLinkBreak(target)

    if TryBlinkEngage(now, me, targetPos) then
        return true
    end

    if SafeValue(NPC.HasModifier, me, BKB_ACTIVE_MOD) ~= true then
        if TryCastNoTargetItem(now, me, "item_black_king_bar", "bkb") then
            return true
        end
    end

    local magicImmune = IsMagicImmune(target)
    local hexed = HasAnyModifier(target, HEX_MODIFIERS)
    local stunned = SafeValue(NPC.IsStunned, target) == true
        or GetStunRemaining(target, now) ~= nil
    local hardDisabled = stunned or hexed
    local silenced = SafeValue(NPC.IsSilenced, target) == true
        or HasAnyModifier(target, SILENCE_ITEM_MODIFIERS)

    -- Silence before Hex so Bloodthorn/Orchid are not blocked by hex-as-stun
    -- when "Use in Stun" is off for that item.
    if not linkens and not magicImmune and not silenced then
        local allowBloodthorn = (not hardDisabled) or IsUseInStunEnabled("item_bloodthorn")
        local allowOrchid = (not hardDisabled) or IsUseInStunEnabled("item_orchid")
        if allowBloodthorn and TryCastTargetItem(now, me, target, "item_bloodthorn", "bloodthorn") then
            return true
        end
        if allowOrchid and TryCastTargetItem(now, me, target, "item_orchid", "orchid") then
            return true
        end
    end

    -- Targeted disables wait for Linkbreaker when Linkens is up (do not spend Hex on the bubble).
    if not linkens and not magicImmune and not hexed then
        if TryCastTargetItem(now, me, target, "item_sheepstick", "sheep") then
            return true
        end
    end

    -- Skip Abyssal if already stunned or hexed (hex is not always NPC.IsStunned).
    if not linkens and not hardDisabled then
        if TryCastTargetItem(now, me, target, "item_abyssal_blade", "abyssal") then
            return true
        end
    end

    if not linkens
        and not magicImmune
        and SafeValue(NPC.HasModifier, target, NULLIFIER_MUTE_MOD) ~= true
    then
        local smartOk = (not IsSmartUsageEnabled()) or TargetNeedsNullifierDispel(target)
        if smartOk and TryCastTargetItem(now, me, target, "item_nullifier", "nullifier") then
            return true
        end
    end

    if SafeValue(NPC.HasModifier, me, SATANIC_ACTIVE_MOD) ~= true then
        local threshold = 25
        if UI.SatanicHp and UI.SatanicHp.Get then
            threshold = tonumber(UI.SatanicHp:Get()) or 25
        end
        if GetHealthPct(me) <= threshold then
            if TryCastNoTargetItem(now, me, "item_satanic", "satanic") then
                return true
            end
        end
    end

    return false
end

---Semi-Important Items after Important, before ability chain (Bloodstone also mid-chain).
---@param now number
---@param me userdata
---@param target userdata
---@param targetPos Vector
---@return boolean
local function TrySemiImportantItems(now, me, target, targetPos)
    if Script.IsMainComboBusy(me) then
        return TryBloodstone(now, me)
    end

    local linkens = TargetNeedsLinkBreak(target)
    local magicImmune = IsMagicImmune(target)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local distToTarget = (myPos and targetPos) and Dist2D(myPos, targetPos) or math.huge

    -- Amp / nuke setup first.
    if not linkens and not magicImmune then
        -- Current Veil is a no-target pulse; CastPosition never spends CD (timeout spam).
        local veilRadius = (Script.ItemAoe and Script.ItemAoe.item_veil_of_discord) or 1200
        if distToTarget <= veilRadius then
            if TryCastNoTargetItem(now, me, "item_veil_of_discord", "veil") then
                return true
            end
        end
    end

    if not linkens
        and not magicImmune
        and SafeValue(NPC.HasModifier, target, "modifier_item_ethereal_blade_ethereal") ~= true
    then
        if TryCastTargetItem(now, me, target, "item_ethereal_blade", "eblade") then
            return true
        end
    end

    if not linkens and not magicImmune then
        local dagon, dagonId = GetDagonItem(me)
        if dagon and dagonId and CanUseAbilityOnce(dagonId, dagon, me, CanCastItem(dagon, me)) then
            local castRange = GetItemCastRange(me, dagon, Script.ItemRange[dagonId] or 700)
            if IsTargetInCastRange(me, target, castRange) then
                if CastTarget(now, me, dagon, target, "dagon") then
                    return true
                end
            end
        end
    end

    if not linkens
        and not magicImmune
        and SafeValue(NPC.HasModifier, target, "modifier_rod_of_atos_debuff") ~= true
    then
        if TryCastTargetItem(now, me, target, "item_rod_of_atos", "atos") then
            return true
        end
    end

    if not linkens
        and not magicImmune
        and SafeValue(NPC.HasModifier, target, "modifier_gungir_root") ~= true
    then
        if TryCastPositionItem(now, me, targetPos, "item_gungir", "gleipnir") then
            return true
        end
    end

    if not linkens and SafeValue(NPC.HasModifier, target, "modifier_heavens_halberd_debuff") ~= true then
        if TryCastTargetItem(now, me, target, "item_heavens_halberd", "halberd") then
            return true
        end
    end

    if not linkens then
        if TryCastTargetItem(now, me, target, "item_harpoon", "harpoon") then
            return true
        end
    end

    local shivasRadius = (Script.ItemAoe and Script.ItemAoe.item_shivas_guard) or 900
    if distToTarget <= shivasRadius then
        if TryCastNoTargetItem(now, me, "item_shivas_guard", "shivas") then
            return true
        end
    end

    if TryBloodstone(now, me) then
        return true
    end

    return false
end

---True only while the cast is actually happening (phase / hop / channel), not a dead issued flag.
---@param abilityName string
---@param ability userdata|nil
---@param me userdata
---@return boolean
local function IsOrderActivelyResolving(abilityName, ability, me)
    if not Runtime.abilityIssued[abilityName] then
        return false
    end
    if ability and SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return true
    end
    if abilityName == "item_meteor_hammer" and SafeValue(NPC.IsChannellingAbility, me) == true then
        return true
    end
    -- Brief grace so phase/hop can register after Humanizer accepts the order.
    local now = SafeValue(GameRules.GetGameTime) or 0
    local issuedAt = Runtime.abilityIssuedAt[abilityName] or now
    return (now - issuedAt) < 0.22
end



---Other Items before ability chain only. Mid-chain buffs run after Shredder (see UpdateCombo).
---@param now number
---@param me userdata
---@param target userdata
---@param targetPos Vector
---@return boolean
local function TryOtherItems(now, me, target, targetPos)
    if Script.IsMainComboBusy(me) then
        return false
    end

    local linkens = TargetNeedsLinkBreak(target)
    local magicImmune = IsMagicImmune(target)

    if SafeValue(NPC.HasModifier, me, PHASE_BOOTS_MOD) ~= true then
        if TryCastNoTargetItem(now, me, "item_phase_boots", "phase") then
            return true
        end
    end

    if not magicImmune then
        if TryCastPositionItem(now, me, targetPos, "item_blood_grenade", "grenade") then
            return true
        end
    end

    -- Disperser upgrades Diffusal; prefer Disperser when both would resolve to one item.
    if not linkens and not magicImmune then
        if SafeValue(NPC.HasModifier, target, DIFFUSAL_SLOW_MOD) ~= true then
            if TryCastTargetItem(now, me, target, "item_disperser", "disperser") then
                return true
            end
            if TryCastTargetItem(now, me, target, "item_diffusal_blade", "diffusal") then
                return true
            end
        end
    end

    if SafeValue(NPC.HasModifier, me, BLADE_MAIL_ACTIVE_MOD) ~= true then
        if TryCastNoTargetItem(now, me, "item_blade_mail", "blade_mail") then
            return true
        end
    end

    if SafeValue(NPC.HasModifier, me, MJOLLNIR_STATIC_MOD) ~= true then
        if TryCastTargetItem(now, me, me, "item_mjollnir", "mjollnir") then
            return true
        end
    end

    if TryToggleItemOn(now, me, "item_armlet", "armlet") then
        return true
    end

    if TryCastNoTargetItem(now, me, "item_manta", "manta") then
        return true
    end

    -- Windwalk last before abilities so BM/Manta do not break invis immediately.
    if SafeValue(NPC.HasModifier, me, "modifier_item_silver_edge_windwalk") ~= true
        and SafeValue(NPC.HasModifier, me, "modifier_item_invisibility_edge_windwalk") ~= true
    then
        if TryCastNoTargetItem(now, me, "item_silver_edge", "silver_edge") then
            return true
        end
        if TryCastNoTargetItem(now, me, "item_invis_sword", "shadow_blade") then
            return true
        end
    end

    -- Meteor channels 2s — only when Cookie/Blast/Shredder cannot run this engage.
    if not magicImmune and not IsMainComboAbilityPending(me) then
        if TryCastPositionItem(now, me, targetPos, "item_meteor_hammer", "meteor") then
            return true
        end
    end

    return false
end

---@param itemId string
---@return number
local function GetSupportAllyThreshold(itemId)
    for i = 1, #SUPPORT_ITEMS do
        local entry = SUPPORT_ITEMS[i]
        if entry.id == itemId then
            local slider = UI.SupportSliders and UI.SupportSliders[i]
            if slider and slider.Get then
                return tonumber(slider:Get()) or 3
            end
            return 3
        end
    end
    return 1
end

---Ally heroes in aura radius (includes self).
---@param me userdata
---@param radius number
---@return integer
local function CountNearbyAllyHeroes(me, radius)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not myPos or team == nil then
        return 0
    end
    local ok, list = TryCall(
        Heroes.InRadius,
        myPos,
        radius,
        team,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    )
    if not ok or type(list) ~= "table" then
        return 0
    end
    local count = 0
    for i = 1, #list do
        local hero = list[i]
        if IsValidUnit(hero)
            and SafeValue(Entity.IsHero, hero) == true
            and SafeValue(NPC.IsIllusion, hero) ~= true
        then
            count = count + 1
        end
    end
    return count
end

---@param me userdata
---@param itemId string
---@return boolean
local function CanUseSupportItem(me, itemId)
    local allies = CountNearbyAllyHeroes(me, SUPPORT_AURA_RADIUS)
    local need = GetSupportAllyThreshold(itemId)
    if allies >= need then
        return true
    end
    -- Solo / low ally count: still allow when critically low HP.
    return GetHealthPct(me) <= SUPPORT_EMERGENCY_HP
end

---@param me userdata
---@param radius number
---@param hpPct number
---@return boolean
local function AnyAllyBelowHp(me, radius, hpPct)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not myPos or team == nil then
        return GetHealthPct(me) <= hpPct
    end
    local ok, list = TryCall(
        Heroes.InRadius,
        myPos,
        radius,
        team,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    )
    if not ok or type(list) ~= "table" then
        return GetHealthPct(me) <= hpPct
    end
    for i = 1, #list do
        local hero = list[i]
        if IsValidUnit(hero)
            and SafeValue(Entity.IsHero, hero) == true
            and SafeValue(NPC.IsIllusion, hero) ~= true
            and GetHealthPct(hero) <= hpPct
        then
            return true
        end
    end
    return false
end



---Utility Items after Other, before ability chain (Pike mid-chain after spells).
---@param now number
---@param me userdata
---@param target userdata
---@param targetPos Vector
---@return boolean
local function TryUtilityItems(now, me, target, targetPos)
    if Script.IsMainComboBusy(me) then
        return false
    end

    local linkens = TargetNeedsLinkBreak(target)
    local magicImmune = IsMagicImmune(target)

    -- Mana before spendy casts.
    local soulThreshold = 30
    if UI.SoulRingHp and UI.SoulRingHp.Get then
        soulThreshold = tonumber(UI.SoulRingHp:Get()) or 30
    end
    if GetHealthPct(me) > soulThreshold then
        if TryCastNoTargetItem(now, me, "item_soul_ring", "soul_ring") then
            return true
        end
    end

    -- Drum / Bearing (shared CD — Bearing replaces Drum).
    if SafeValue(NPC.HasModifier, me, BEARING_ACTIVE_MOD) ~= true
        and SafeValue(NPC.HasModifier, me, JANGGO_ACTIVE_MOD) ~= true
    then
        if CanUseSupportItem(me, "item_boots_of_bearing") then
            if TryCastNoTargetItem(now, me, "item_boots_of_bearing", "bearing") then
                return true
            end
        end
        if TryCastNoTargetItem(now, me, "item_ancient_janggo", "drum") then
            return true
        end
    end

    if SafeValue(NPC.HasModifier, me, "modifier_item_pipe_barrier") ~= true then
        if CanUseSupportItem(me, "item_pipe") then
            if TryCastNoTargetItem(now, me, "item_pipe", "pipe") then
                return true
            end
        end
    end

    if SafeValue(NPC.HasModifier, me, "modifier_item_crimson_guard_extra") ~= true then
        if CanUseSupportItem(me, "item_crimson_guard") then
            if TryCastNoTargetItem(now, me, "item_crimson_guard", "crimson") then
                return true
            end
        end
    end

    -- Mek: self/ally needs heal (no dedicated Support slider).
    if AnyAllyBelowHp(me, SUPPORT_AURA_RADIUS, 65) then
        if TryCastNoTargetItem(now, me, "item_mekansm", "mek") then
            return true
        end
    end

    if CanUseSupportItem(me, "item_guardian_greaves") then
        if TryCastNoTargetItem(now, me, "item_guardian_greaves", "greaves") then
            return true
        end
    end

    -- Solar Crest is friendly-only — buff self for the fight.
    if SafeValue(NPC.HasModifier, me, SOLAR_CREST_SELF_MOD) ~= true then
        if TryCastTargetItem(now, me, me, "item_solar_crest", "solar") then
            return true
        end
    end

    -- Urn line: Vessel > Distiller > Urn on the combo target.
    if not linkens and not magicImmune then
        if SafeValue(NPC.HasModifier, target, VESSEL_DAMAGE_MOD) ~= true
            and SafeValue(NPC.HasModifier, target, URN_DAMAGE_MOD) ~= true
        then
            if TryCastTargetItem(now, me, target, "item_spirit_vessel", "vessel") then
                return true
            end
            if TryCastTargetItem(now, me, target, "item_essence_distiller", "distiller") then
                return true
            end
            if TryCastTargetItem(now, me, target, "item_urn_of_shadows", "urn") then
                return true
            end
        end
    end

    return false
end

---Neutral Items after Utility, before ability chain.
---@param now number
---@param me userdata
---@param target userdata
---@param targetPos Vector
---@return boolean
local function TryNeutralItems(now, me, target, targetPos)
    if Script.IsMainComboBusy(me) then
        return false
    end

    local linkens = TargetNeedsLinkBreak(target)
    local magicImmune = IsMagicImmune(target)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)

    -- Mobility / mini-BKB.
    if TryCastNoTargetItem(now, me, "item_spider_legs", "spider_legs") then
        return true
    end
    if SafeValue(NPC.HasModifier, me, BKB_ACTIVE_MOD) ~= true then
        if TryCastNoTargetItem(now, me, "item_minotaur_horn", "minotaur") then
            return true
        end
    end

    -- Self combat buffs / summons.
    if TryCastNoTargetItem(now, me, "item_kobold_cup", "kobold_cup") then
        return true
    end
    if TryCastNoTargetItem(now, me, "item_idol_of_screeauk", "idol") then
        return true
    end
    if TryCastNoTargetItem(now, me, "item_ash_legion_shield", "ash_shield") then
        return true
    end
    if TryCastNoTargetItem(now, me, "item_demonicon", "demonicon") then
        return true
    end
    if TryCastNoTargetItem(now, me, "item_flayers_bota", "flayers") then
        return true
    end
    if TryCastNoTargetItem(now, me, "item_dagger_of_ristul", "ristul") then
        return true
    end
    if TryCastNoTargetItem(now, me, "item_riftshadow_prism", "riftshadow") then
        return true
    end

    if GetHealthPct(me) <= 85 then
        if TryCastNoTargetItem(now, me, "item_essence_ring", "essence_ring") then
            return true
        end
    end

    -- Friendly heal/regen charm on self.
    if TryCastTargetItem(now, me, me, "item_polliwog_charm", "polliwog") then
        return true
    end

    -- Enemy-targeted / point neutrals.
    if not linkens and not magicImmune then
        if TryCastTargetItem(now, me, target, "item_medallion_of_courage", "medallion") then
            return true
        end
        if TryCastTargetItem(now, me, target, "item_crippling_crossbow", "crossbow") then
            return true
        end
        if TryCastPositionItem(now, me, targetPos, "item_heavy_blade", "heavy_blade") then
            return true
        end
    end

    -- Pollen bag: pulse around self — only if target is in the debuff radius.
    local pollenRadius = (Script.ItemAoe and Script.ItemAoe.item_jidi_pollen_bag) or 700
    if myPos and Dist2D(myPos, targetPos) <= pollenRadius then
        if TryCastNoTargetItem(now, me, "item_jidi_pollen_bag", "pollen") then
            return true
        end
    end

    return false
end

---@param me userdata
---@param ability userdata|nil
---@param fallback number
---@return number
function DC.GetAbilityCastRange(me, ability, fallback)
    local range = ability and SafeValue(Ability.GetCastRange, ability) or 0
    if type(range) ~= "number" or range <= 0 then
        range = fallback
    end
    range = range + (SafeValue(NPC.GetCastRangeBonus, me) or 0)
    return range
end

---@param me userdata|nil
---@return boolean
function DC.HasScepter(me)
    return me ~= nil and SafeValue(NPC.HasScepter, me) == true
end

---True when target can leave / ignore Field+Storm (no Aghs item-mute).
---@param unit userdata|nil
---@return boolean
---@return string|nil reason
function DC.TargetCanEscapeField(unit)
    if not unit then
        return false, nil
    end
    for i = 1, #FIELD_ESCAPE_MODS do
        local mod = FIELD_ESCAPE_MODS[i]
        if SafeValue(NPC.HasModifier, unit, mod) == true then
            return true, mod
        end
    end
    -- Ready BKB (will press into Field without Aghs mute).
    local bkb = SafeValue(NPC.GetItem, unit, "item_black_king_bar", true)
    if bkb and SafeValue(Ability.IsReady, bkb) == true then
        local cd = SafeValue(Ability.GetCooldown, bkb) or 0
        if cd <= 0.05 then
            return true, "item_black_king_bar"
        end
    end
    for i = 1, #FIELD_ESCAPE_READY_ABILITIES do
        local name = FIELD_ESCAPE_READY_ABILITIES[i]
        local ab = SafeValue(NPC.GetAbility, unit, name)
        if ab and CanCastAbility(ab, unit) then
            return true, name
        end
    end
    return false, nil
end

---Without Aghanim: delay Field/Fence/Storm while target can walk out or shrug the ult.
---@param me userdata
---@param target userdata|nil
---@return boolean
function DC.ShouldDelayFieldStorm(me, target)
    if DC.HasScepter(me) then
        return false
    end
    local escape, reason = DC.TargetCanEscapeField(target)
    if escape then
        local now = SafeValue(GameRules.GetGameTime) or 0
        if (now - (Runtime.debugWaitHeartbeatAt or -math.huge)) >= DEBUG_WAIT_HEARTBEAT then
            Runtime.debugWaitHeartbeatAt = now
            Dbg("delay field/storm: no aghs, escape=%s target=%s", tostring(reason), FmtUnit(target))
        end
        return true
    end
    return false
end

---@param me userdata|nil
---@return boolean
function DC.HasShard(me)
    return me ~= nil and SafeValue(NPC.HasShard, me) == true
end

---Static Storm radius including +75 talent via GetLevelSpecialValueFor.
---@param storm userdata|nil
---@return number
function DC.GetStormRadius(storm)
    return DC.ReadSpecial(storm, "radius", 550)
end

---Kinetic Field / Fence radius (talent-aware via specials).
---@param ability userdata|nil
---@return number
function DC.GetFieldRadius(ability)
    return DC.ReadSpecial(ability, "radius", DC.FIELD_RADIUS)
end


function DC.ReadSpecial(ability, name, fallback)
    if not ability then
        return fallback
    end
    local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, name)
    if type(value) ~= "number" or value ~= value then
        return fallback
    end
    -- Duration/formation specials of 0 are almost always a bad read — keep fallback.
    if fallback ~= nil and type(fallback) == "number" and fallback > 0 and value <= 0 then
        return fallback
    end
    return value
end

---Kinetic Field: barrier starts after formation_time, then lasts duration (talent-aware when specials work).
---@param field userdata|nil
---@return number formation
---@return number duration
---@return number total
function DC.GetFieldLifetime(field)
    local formation = DC.ReadSpecial(field, "formation_time", 1.0)
    if formation < 0.2 then
        formation = 1.0
    end
    local duration = DC.ReadSpecial(field, "duration", 0)
    if duration < 0.5 then
        local lvl = field and (SafeValue(Ability.GetLevel, field) or 1) or 1
        if lvl < 1 then
            lvl = 1
        elseif lvl > 4 then
            lvl = 4
        end
        local byLevel = { 2.6, 3.2, 3.8, 4.4 }
        duration = byLevel[lvl] or 2.6
    end
    return formation, duration, formation + duration
end

---Live Kinetic Field barrier on enemies near the trap center (modifier only).
---@param me userdata
---@return boolean
function DC.HasKineticFieldModifier(me)
    local center = Runtime.trapCenter
    if not center then
        return false
    end
    local team = SafeValue(Entity.GetTeamNum, me)
    if team == nil then
        return false
    end
    local radius = (Runtime.trapFieldRadius or DC.FIELD_RADIUS) + 80
    local heroes = SafeValue(Heroes.InRadius, center, radius, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemyHero(enemy)
            and SafeValue(NPC.HasModifier, enemy, "modifier_disruptor_kinetic_field") == true
        then
            return true
        end
    end
    return false
end

function DC.PredictEnemyPos(enemy, lead)
    local pos = SafeValue(Entity.GetAbsOrigin, enemy)
    if not pos then
        return nil
    end
    if lead <= 0 or SafeValue(NPC.IsRunning, enemy) ~= true then
        return pos
    end
    local rotation = SafeValue(Entity.GetRotation, enemy)
    local forward = rotation and rotation:GetForward()
    local speed = SafeValue(NPC.GetMoveSpeed, enemy) or 0
    if not forward or speed <= 0 then
        return pos
    end
    return Vector(pos.x + forward.x * speed * lead, pos.y + forward.y * speed * lead, pos.z)
end

function DC.CountHitsAt(pos, positions, radius)
    local hits = 0
    local r2 = radius * radius
    for i = 1, #positions do
        local p = positions[i]
        local dx = p.x - pos.x
        local dy = p.y - pos.y
        if dx * dx + dy * dy <= r2 then
            hits = hits + 1
        end
    end
    return hits
end

---@param pos Vector|nil
---@return boolean
function DC.IsWorldTraversable(pos)
    if not pos then
        return false
    end
    if not GridNav or not GridNav.IsTraversable then
        return true
    end
    local ok, result = TryCall(GridNav.IsTraversable, pos, DC.GRID_FLAG, DC.GRID_EXCLUDED)
    if ok then
        return result == true
    end
    return true
end

---@param from Vector|nil
---@param to Vector|nil
---@return boolean
function DC.IsPathClear(from, to)
    if not from or not to then
        return false
    end
    if not GridNav then
        return true
    end
    if GridNav.IsTraversableFromTo then
        local ok, result = TryCall(GridNav.IsTraversableFromTo, from, to, false, nil)
        if ok then
            return result == true
        end
    end
    return DC.IsWorldTraversable(to)
end

---How many escape rays from Field center hit impassable (0..WALL_RAYS).
---@param center Vector
---@param radius number
---@return integer
function DC.CountEscapeWalls(center, radius)
    local blocked = 0
    local rays = DC.WALL_RAYS
    for i = 0, rays - 1 do
        local ang = (i / rays) * math.pi * 2
        local edge = Vector(
            center.x + math.cos(ang) * radius,
            center.y + math.sin(ang) * radius,
            center.z
        )
        if not DC.IsPathClear(center, edge) then
            blocked = blocked + 1
        end
    end
    return blocked
end

---Nudge Field center toward nearest impassable edge while keeping target inside radius.
---@param center Vector
---@param targetPos Vector
---@param radius number
---@return Vector
function DC.NudgeTowardWall(center, targetPos, radius)
    if not center or not targetPos or not radius or radius <= 0 then
        return center
    end
    local bestDir, bestBlocked = nil, -1
    local rays = DC.WALL_RAYS
    for i = 0, rays - 1 do
        local ang = (i / rays) * math.pi * 2
        local dx, dy = math.cos(ang), math.sin(ang)
        local edge = Vector(center.x + dx * radius, center.y + dy * radius, center.z)
        if not DC.IsPathClear(center, edge) then
            local score = 1
            if score > bestBlocked then
                bestBlocked = score
                bestDir = { x = dx, y = dy }
            end
        end
    end
    if not bestDir then
        return center
    end
    local nudge = radius * DC.TARGET_WALL_NUDGE
    local candidate = Vector(
        center.x + bestDir.x * nudge,
        center.y + bestDir.y * nudge,
        center.z
    )
    if not DC.IsWorldTraversable(candidate) then
        return center
    end
    if Dist2D(candidate, targetPos) > radius - 20 then
        return center
    end
    return candidate
end

---Fence cast point on Field rim along target escape (facing / run).
---@param fieldPos Vector
---@param target userdata|nil
---@param fieldRadius number
---@return Vector
function DC.GetFenceAimPos(fieldPos, target, fieldRadius)
    if not fieldPos then
        return fieldPos
    end
    local radius = (fieldRadius or DC.FIELD_RADIUS) - DC.FENCE_RIM_MARGIN
    if radius < 80 then
        radius = 80
    end
    local dirX, dirY = 0, 0
    local targetPos = target and SafeValue(Entity.GetAbsOrigin, target) or nil
    if target and SafeValue(NPC.IsRunning, target) == true then
        local rotation = SafeValue(Entity.GetRotation, target)
        local forward = rotation and rotation:GetForward()
        if forward then
            dirX, dirY = forward.x, forward.y
        end
    end
    if (dirX == 0 and dirY == 0) and targetPos then
        dirX = targetPos.x - fieldPos.x
        dirY = targetPos.y - fieldPos.y
    end
    local len = math.sqrt(dirX * dirX + dirY * dirY)
    if len < 0.001 then
        return fieldPos
    end
    dirX, dirY = dirX / len, dirY / len
    local fencePos = Vector(
        fieldPos.x + dirX * radius,
        fieldPos.y + dirY * radius,
        fieldPos.z
    )
    if not DC.IsWorldTraversable(fencePos) then
        return fieldPos
    end
    return fencePos
end

function DC.FindBestAoePosition(origin, enemies, radius, minHits, predictionTime)
    minHits = minHits or 1
    local bestPos, bestHits, bestWalls = nil, 0, -1
    local positions = {}
    for i = 1, #enemies do
        local pos = DC.PredictEnemyPos(enemies[i], predictionTime or 0)
        if pos then
            positions[#positions + 1] = pos
        end
    end
    if #positions == 0 then
        return nil, 0
    end

    local function consider(pos)
        if not pos then
            return
        end
        if not DC.IsWorldTraversable(pos) then
            return
        end
        local hits = DC.CountHitsAt(pos, positions, radius)
        if hits < minHits then
            return
        end
        local walls = DC.CountEscapeWalls(pos, radius)
        local closer = origin
            and bestPos
            and Dist2D(origin, pos) < Dist2D(origin, bestPos)
        if hits > bestHits
            or (hits == bestHits and walls > bestWalls)
            or (hits == bestHits and walls == bestWalls and closer)
        then
            bestHits = hits
            bestWalls = walls
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
    return bestPos, bestHits
end

function DC.CollectComboEnemies(me, fieldAbility)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not myPos or team == nil then
        return {}
    end
    local fieldRange = DC.GetAbilityCastRange(me, fieldAbility, DC.E_RANGE)
    local fieldRadius = DC.GetFieldRadius(fieldAbility)
    local raw = SafeValue(
        Heroes.InRadius,
        myPos,
        fieldRange + fieldRadius + 200,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}
    local out = {}
    for i = 1, #raw do
        local enemy = raw[i]
        if IsValidEnemyHero(enemy)
            and SafeValue(Entity.IsSameTeam, me, enemy) ~= true
            and SafeValue(NPC.IsVisible, enemy) == true
            and not IsMagicImmune(enemy)
        then
            -- Without Aghs mute, skip heroes who can walk out of Field / shrug Storm.
            if not DC.HasScepter(me) then
                local escape = DC.TargetCanEscapeField(enemy)
                if escape then
                    goto continue_enemy
                end
            end
            out[#out + 1] = enemy
        end
        ::continue_enemy::
    end
    return out
end

function DC.GetGlimpseReturnPos(enemy, now)
    local index = SafeValue(Entity.GetIndex, enemy)
    if not index then
        return SafeValue(Entity.GetAbsOrigin, enemy)
    end
    local history = Runtime.glimpseHistory[index]
    if not history or #history == 0 then
        return SafeValue(Entity.GetAbsOrigin, enemy)
    end
    local targetTime = now - DC.GLIMPSE_LOOKBACK
    local best = history[1]
    local bestDelta = math.abs(best.t - targetTime)
    for i = 2, #history do
        local sample = history[i]
        local delta = math.abs(sample.t - targetTime)
        if delta < bestDelta then
            best = sample
            bestDelta = delta
        end
    end
    return Vector(best.x, best.y, best.z)
end

function DC.ResetDisruptorComboFlags()
    Runtime.comboStage = "idle"
    Runtime.comboMode = nil
    Runtime.fieldPos = nil
    Runtime.fieldHits = 0
    Runtime.fieldLocked = false
    Runtime.comboCompleteLogged = false
    Runtime.stageStartedAt = -math.huge
    Runtime.blinkSettleUntil = -math.huge
    Runtime.fieldCastAt = -math.huge
    Runtime.fieldEndsAt = -math.huge
    Runtime.stormCastAt = -math.huge
    Runtime.stormEndsAt = -math.huge
    Runtime.secondCycleAt = -math.huge
    Runtime.secondCycleWaitReason = nil
    Runtime.trapCenter = nil
    Runtime.trapFieldRadius = nil
    Runtime.qDone = false
    Runtime.wDone = false
    Runtime.eDone = false
    Runtime.fenceDone = false
    Runtime.rDone = false
    Runtime.fencePos = nil
end

---Drive Refresher consume → ReArm even while Humanizer busy blocks new orders.
---@param me userdata
function DC.PollRefresherConsume(me)
    local refresherIds = { "item_refresher_shard", "item_refresher" }
    for i = 1, #refresherIds do
        local id = refresherIds[i]
        if Runtime.abilityIssued[id] then
            local item = GetItem(me, id)
            CanUseAbilityOnce(id, item, me, item ~= nil and CanCastItem(item, me))
            return
        end
    end
end

function DC.GetFieldFormationLead(fieldAbility)
    local formation = DC.GetFieldLifetime(fieldAbility)
    return formation + 0.12
end

---Static Storm duration (talent-aware via specials).
---@param storm userdata|nil
---@return number
function DC.GetStormDuration(storm)
    local duration = DC.ReadSpecial(storm, "duration", 5.0)
    if type(duration) ~= "number" or duration < 1.0 then
        duration = 5.0
    end
    return duration
end

---Record when Static Storm will fully drop.
---@param storm userdata|nil
---@param castAt number
function DC.MarkStormTrap(storm, castAt)
    local duration = DC.GetStormDuration(storm)
    Runtime.stormCastAt = castAt
    Runtime.stormEndsAt = castAt + duration
    Dbg("storm ends in %.2fs (dur=%.2f)", duration, duration)
end

---Record when the cast Kinetic Field will fully drop (formation + duration).
---@param field userdata|nil
---@param castAt number
---@param center Vector|nil
function DC.MarkFieldTrap(field, castAt, center)
    local formation, duration, total = DC.GetFieldLifetime(field)
    Runtime.fieldCastAt = castAt
    Runtime.fieldEndsAt = castAt + total
    Runtime.trapCenter = center or Runtime.fieldPos
    Runtime.trapFieldRadius = DC.GetFieldRadius(field)
    Dbg(
        "field trap ends in %.2fs (form=%.2f dur=%.2f)",
        total,
        formation,
        duration
    )
end

function DC.AbilityStepDone(abilityName, ability, me)
    if not ability then
        return true
    end
    Runtime.abilityConsumed = Runtime.abilityConsumed or {}
    if Runtime.abilityIssued[abilityName] then
        -- Drive consume / timeout through the one-shot gate.
        CanUseAbilityOnce(abilityName, ability, me)
        if Runtime.abilityConsumed[abilityName] then
            Runtime.abilityConsumed[abilityName] = nil
            return true
        end
        if Runtime.abilityIssued[abilityName] then
            return false
        end
        -- Issue timed out without a real consume — allow retry, do not advance the chain.
        return false
    end
    if Runtime.abilityConsumed[abilityName] then
        Runtime.abilityConsumed[abilityName] = nil
        return true
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return false
    end
    return not CanCastAbility(ability, me)
end

function DC.BuildDisruptorPlan(me, mode, now)
    local fieldAbility = GetAbility(me, ABILITY.field)
    local enemies = DC.CollectComboEnemies(me, fieldAbility)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos or #enemies == 0 then
        return nil, nil, 0
    end
    local fieldRadius = DC.GetFieldRadius(fieldAbility)
    local lead = DC.GetFieldFormationLead(fieldAbility)

    if mode == "target" then
        local locked = Runtime.comboTarget
        if not IsValidEnemyHero(locked) then
            return nil, nil, 0
        end
        local fieldPos = DC.PredictEnemyPos(locked, lead)
        if fieldPos then
            local targetPos = SafeValue(Entity.GetAbsOrigin, locked) or fieldPos
            fieldPos = DC.NudgeTowardWall(fieldPos, targetPos, fieldRadius)
        end
        return locked, fieldPos, 1
    end

    local minHits = 2
    if UI.MinEnemies and UI.MinEnemies.Get then
        minHits = UI.MinEnemies:Get() or 2
    end
    if type(minHits) ~= "number" or minHits < 1 then
        minHits = 2
    end
    local fieldPos, hits = DC.FindBestAoePosition(myPos, enemies, fieldRadius, minHits, lead)
    if not fieldPos then
        fieldPos, hits = DC.FindBestAoePosition(myPos, enemies, fieldRadius, 1, lead)
    end
    if not fieldPos then
        return nil, nil, 0
    end
    local primary, bestDist = nil, math.huge
    for i = 1, #enemies do
        local d = Dist2D(fieldPos, SafeValue(Entity.GetAbsOrigin, enemies[i]))
        if d < bestDist then
            bestDist = d
            primary = enemies[i]
        end
    end
    return primary, fieldPos, hits
end

function DC.AbilityConsumed(ability, me)
    if not ability then
        return true
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return false
    end
    return not CanCastAbility(ability, me)
end

---Refresh AOE / target Field aim until Kinetic Field is locked.
function DC.RefreshFieldAim(me, target, now)
    if Runtime.fieldLocked then
        return Runtime.fieldPos
    end
    local mode = Runtime.comboMode or "aoe"
    local _, fieldPos = DC.BuildDisruptorPlan(me, mode, now)
    if fieldPos then
        Runtime.fieldPos = fieldPos
    elseif target then
        local lead = DC.GetFieldFormationLead(GetAbility(me, ABILITY.field))
        Runtime.fieldPos = DC.PredictEnemyPos(target, lead)
            or SafeValue(Entity.GetAbsOrigin, target)
            or Runtime.fieldPos
    end
    return Runtime.fieldPos
end

---Disruptor ability chain: Blink → Q → E → Fence → R (Storm on locked Field center).
function DC.UpdateDisruptorAbilities(now, me, target, targetPos)
    local q = GetAbility(me, ABILITY.thunder)
    local e = GetAbility(me, ABILITY.field)
    local r = GetAbility(me, ABILITY.storm)

    if Runtime.comboStage == "done" then
        return
    end

    if Runtime.comboStage == "idle" then
        Runtime.fieldPos = Runtime.fieldPos or targetPos
        local fence = GetAbility(me, ABILITY.fence)
        local fenceReady = DC.HasShard(me)
            and IsAbilityEnabled(ABILITY.fence)
            and fence ~= nil
            and CanCastAbility(fence, me)
        Runtime.qDone = not IsAbilityEnabled(ABILITY.thunder) or q == nil or not CanCastAbility(q, me)
        -- Glimpse is manual-only (Glimpse Key); never part of the combo chain.
        Runtime.wDone = true
        Runtime.eDone = not IsAbilityEnabled(ABILITY.field) or e == nil or not CanCastAbility(e, me)
        Runtime.fenceDone = not fenceReady
        Runtime.rDone = not IsAbilityEnabled(ABILITY.storm) or r == nil or not CanCastAbility(r, me)
        -- Linkbreak Thunder already spent this hold: treat Q as done, continue Field→Storm.
        if Runtime.abilityConsumed and Runtime.abilityConsumed[ABILITY.thunder] then
            Runtime.qDone = true
            Runtime.abilityConsumed[ABILITY.thunder] = nil
        end
        Runtime.stageStartedAt = now
        if Runtime.qDone and Runtime.wDone and Runtime.eDone and Runtime.fenceDone and Runtime.rDone then
            Runtime.comboStage = "done"
            if not Runtime.comboCompleteLogged then
                Runtime.comboCompleteLogged = true
                Dbg("disruptor combo complete (skills on CD)")
            end
            return
        end
        Runtime.comboStage = "cast"
    end

    if now - Runtime.stageStartedAt > DC.COMBO_STAGE_TIMEOUT then
        Dbg("disruptor combo stage timeout")
        Runtime.comboStage = "done"
        if not Runtime.comboCompleteLogged then
            Runtime.comboCompleteLogged = true
            Dbg("disruptor combo complete (timeout)")
        end
        return
    end

    if Runtime.blinkSettleUntil > now then
        return
    end

    local fieldPos = DC.RefreshFieldAim(me, target, now) or targetPos

    if not Runtime.qDone and IsAbilityEnabled(ABILITY.thunder) then
        if DC.AbilityStepDone(ABILITY.thunder, q, me) then
            Runtime.qDone = true
        elseif CanUseAbilityOnce(ABILITY.thunder, q, me) then
            local qRange = DC.GetAbilityCastRange(me, q, DC.Q_RANGE)
            if not IsTargetInCastRange(me, target, qRange) then
                if not Runtime.abilityChainStarted and TryBlinkEngage(now, me, targetPos) then
                    Runtime.blinkSettleUntil = now + DC.BLINK_SETTLE_DEFAULT
                    return
                end
                FaceToward(now, me, targetPos)
                return
            end
            if TargetNeedsLinkBreak(target) then
                if Script.HasPendingLinkbreak() or TryLinkbreaker(now, me, target) then
                    return
                end
            end
            if CastTarget(now, me, q, target, "thunder_strike") then
                Runtime.abilityChainStarted = true
                Runtime.stageStartedAt = now
            end
            return
        else
            return
        end
    end

    fieldPos = Runtime.fieldPos or targetPos

    -- Without Aghs mute: wait out BKB / Blade Fury / Repel / ready escapes before Field→Storm.
    if (not Runtime.eDone or not Runtime.fenceDone or not Runtime.rDone)
        and DC.ShouldDelayFieldStorm(me, target)
    then
        Runtime.stageStartedAt = now
        if not Script.IsAttackBlocked(target) then
            AttackEnemy(now, me, target)
        end
        return
    end

    if not Runtime.eDone and IsAbilityEnabled(ABILITY.field) then
        if DC.AbilityStepDone(ABILITY.field, e, me) then
            Runtime.eDone = true
            Runtime.fieldLocked = true
            if type(Runtime.fieldEndsAt) ~= "number" or Runtime.fieldEndsAt <= now then
                DC.MarkFieldTrap(e, now, Runtime.fieldPos)
            end
        elseif CanUseAbilityOnce(ABILITY.field, e, me) then
            fieldPos = DC.RefreshFieldAim(me, target, now) or fieldPos
            local eRange = DC.GetAbilityCastRange(me, e, DC.E_RANGE)
            local myPos = SafeValue(Entity.GetAbsOrigin, me)
            if myPos and Dist2D(myPos, fieldPos) > eRange + 50 then
                if not Runtime.abilityChainStarted and TryBlinkEngage(now, me, fieldPos) then
                    Runtime.blinkSettleUntil = now + DC.BLINK_SETTLE_DEFAULT
                    return
                end
                FaceToward(now, me, fieldPos)
                return
            end
            if CastPosition(now, me, e, fieldPos, "kinetic_field") then
                Runtime.abilityChainStarted = true
                Runtime.fieldPos = fieldPos
                Runtime.fieldLocked = true
                DC.MarkFieldTrap(e, now, fieldPos)
            end
            return
        else
            return
        end
    end

    fieldPos = Runtime.fieldPos or fieldPos

    -- Aghanim's Shard: Kinetic Fence on Field rim along escape path.
    if not Runtime.fenceDone and IsAbilityEnabled(ABILITY.fence) and DC.HasShard(me) then
        local fence = GetAbility(me, ABILITY.fence)
        if DC.AbilityStepDone(ABILITY.fence, fence, me) then
            Runtime.fenceDone = true
        elseif fence and CanUseAbilityOnce(ABILITY.fence, fence, me) then
            local fieldRadius = DC.GetFieldRadius(e)
            local fencePos = Runtime.fencePos
                or DC.GetFenceAimPos(fieldPos, target, fieldRadius)
            Runtime.fencePos = fencePos
            local fenceRange = DC.GetAbilityCastRange(me, fence, 1200)
            local myPos = SafeValue(Entity.GetAbsOrigin, me)
            if myPos and Dist2D(myPos, fencePos) > fenceRange + 50 then
                FaceToward(now, me, fencePos)
                return
            end
            if CastPosition(now, me, fence, fencePos, "kinetic_fence") then
                Runtime.abilityChainStarted = true
            end
            return
        else
            return
        end
    else
        Runtime.fenceDone = true
    end

    if not Runtime.rDone and IsAbilityEnabled(ABILITY.storm) then
        if DC.AbilityStepDone(ABILITY.storm, r, me) then
            Runtime.rDone = true
            if type(Runtime.stormCastAt) ~= "number" or Runtime.stormCastAt <= 0 then
                DC.MarkStormTrap(r, now)
            end
        elseif CanUseAbilityOnce(ABILITY.storm, r, me) then
            -- 1st cycle: Storm ASAP (do not wait Field formation — enemies walk out).
            -- After Refresher: wait Field formation so 2nd Field+Storm chain overlaps cleanly.
            if Runtime.refresherUsed then
                local formation = select(1, DC.GetFieldLifetime(e))
                if type(formation) ~= "number" or formation < 0.2 then
                    formation = 1.0
                end
                if Runtime.fieldCastAt > 0 and now - Runtime.fieldCastAt < formation then
                    return
                end
            end
            local rRange = DC.GetAbilityCastRange(me, r, DC.R_RANGE)
            local myPos = SafeValue(Entity.GetAbsOrigin, me)
            if myPos and Dist2D(myPos, fieldPos) > rRange + 50 then
                FaceToward(now, me, fieldPos)
                return
            end
            if CastPosition(now, me, r, fieldPos, "static_storm") then
                Runtime.abilityChainStarted = true
                DC.MarkStormTrap(r, now)
            end
            return
        else
            return
        end
    end

    if Runtime.qDone and Runtime.wDone and Runtime.eDone and Runtime.fenceDone and Runtime.rDone then
        Runtime.comboStage = "done"
        if not Runtime.comboCompleteLogged then
            Runtime.comboCompleteLogged = true
            Dbg("disruptor combo complete")
        end
    end
end

function DC.UpdateCombo(now, me, target)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not targetPos then
        Script.Target.FollowCursor(now, me, true)
        return
    end

    -- Refresher consume must run even while busy, or the 2nd cycle never arms mid-hold.
    DC.PollRefresherConsume(me)
    DC.PollLinkbreakConsume(me)

    if Runtime.comboStage == "wait_trap" then
        local endsAt = Runtime.secondCycleAt or 0
        local rem = endsAt - now
        local fieldLive = DC.HasKineticFieldModifier(me)

        -- Go on the scheduled lead time — do NOT wait until the barrier is already gone.
        if rem > 0 then
            if (now - (Runtime.debugWaitHeartbeatAt or -math.huge)) >= DEBUG_WAIT_HEARTBEAT then
                Runtime.debugWaitHeartbeatAt = now
                Dbg(
                    "second cycle wait field/storm rem=%.2f live=%s",
                    rem,
                    tostring(fieldLive)
                )
            end
            if DC.TrySelfSave(now, me) then
                return
            end
            if not Script.IsAttackBlocked(target) then
                AttackEnemy(now, me, target)
            end
            return
        end

        Runtime.comboStage = "idle"
        Runtime.stageStartedAt = now
        Runtime.trapCenter = nil
        Runtime.fieldEndsAt = -math.huge
        Dbg("second cycle go (after field lead)")
    end

    local windowClosed, windowRem, windowReason = Script.IsComboWindowClosed(target, now)
    if windowClosed then
        if Script.ShouldHoldForTiming(windowRem) then
            Script.Target.FollowCursor(now, me, true)
            return
        end
        if not Runtime.abilityChainStarted and TryBlinkEngage(now, me, targetPos) then
            return
        end
        FaceToward(now, me, targetPos)
        return
    end

    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        -- Still try Refresher cast when done (HoldForAbilityCast / cast need a free slot).
        if Runtime.comboStage == "done" then
            Script.TryRefresher(now, me)
        end
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("combo wait target=%s reason=%s", FmtUnit(target), reason or "?")
        end
        return
    end

    if ShouldSkipAbilitiesForDamageReturn(now, target) then
        if Script.IsAttackBlocked(target) then
            Script.Target.FollowCursor(now, me, true)
        else
            AttackEnemy(now, me, target)
        end
        return
    end

    if SafeValue(NPC.HasModifier, me, PIKE_RANGE_MOD) == true then
        if Script.IsAttackBlocked(target) then
            Script.Target.FollowCursor(now, me, true)
        else
            AttackEnemy(now, me, target)
        end
        return
    end

    -- Cycle finished: Refresher for a second trap, otherwise hold quietly.
    if Runtime.comboStage == "done" then
        if Script.TryRefresher(now, me) then
            return
        end
        -- Consume may move us to wait_trap / idle; only idle continues this frame.
        if Runtime.comboStage == "done" then
            return
        end
        if Runtime.comboStage == "wait_trap" then
            return
        end
    end

    if TargetNeedsLinkBreak(target) and Script.HasPendingLinkbreak() then
        DC.PollLinkbreakConsume(me)
        return
    end
    if TryLinkbreaker(now, me, target) then
        return
    end

    -- Before the ability chain: blink / hex / roots. Mid-chain: only emergency items.
    -- After Refresher, skip setup items and open the trap immediately.
    if not Runtime.abilityChainStarted then
        if not Runtime.refresherUsed then
            if TryImportantItems(now, me, target, targetPos) then
                return
            end
            if TrySemiImportantItems(now, me, target, targetPos) then
                return
            end
            if TryOtherItems(now, me, target, targetPos) then
                return
            end
            if TryUtilityItems(now, me, target, targetPos) then
                return
            end
            if TryNeutralItems(now, me, target, targetPos) then
                return
            end
        elseif TryBlinkEngage(now, me, targetPos) then
            Runtime.blinkSettleUntil = now + DC.BLINK_SETTLE_DEFAULT
            return
        end
    else
        if DC.TrySelfSave(now, me) then
            return
        end
        if TryBloodstone(now, me) then
            return
        end
        if Script.IsMainComboBusy(me) then
            if SafeValue(NPC.HasModifier, me, SATANIC_ACTIVE_MOD) ~= true then
                local threshold = 25
                if UI.SatanicHp and UI.SatanicHp.Get then
                    threshold = tonumber(UI.SatanicHp:Get()) or 25
                end
                if GetHealthPct(me) <= threshold then
                    if TryCastNoTargetItem(now, me, "item_satanic", "satanic") then
                        return
                    end
                end
            end
        end
    end

    if TargetNeedsLinkBreak(target) and not Runtime.abilityChainStarted then
        if Script.HasPendingLinkbreak() or TryLinkbreaker(now, me, target) then
            return
        end
    end

    DC.UpdateDisruptorAbilities(now, me, target, targetPos)
end

function DC.UpdateCombat(now)
    local me = SafeValue(Heroes.GetLocal)
    if me == nil or not IsLocalDisruptor(me) or not IsValidUnit(me) then
        if Runtime.prevAoeHeld or Runtime.prevTargetHeld then
            Dbg("abort: not local live Disruptor")
        end
        ResetRuntime()
        return
    end

    if SafeValue(Input.IsInputCaptured) == true then
        Runtime.drawActive = false
        return
    end

    DC.UpdateGlimpseHistory(me, now)
    DC.UpdateGlimpseDrawState(me, now)
    DC.TryManualGlimpseKey(now, me)

    local aoeHeld = IsBindHeld(UI.AoeComboKey or UI.ComboKey)
    local targetHeld = IsBindHeld(UI.TargetComboKey)
    -- Target wins if both held.
    local mode = nil
    if targetHeld then
        mode = "target"
    elseif aoeHeld then
        mode = "aoe"
    end

    if aoeHeld ~= Runtime.prevAoeHeld then
        Dbg("AoeComboKey hold=%s", tostring(aoeHeld))
        Runtime.prevAoeHeld = aoeHeld
    end
    if targetHeld ~= Runtime.prevTargetHeld then
        Dbg("TargetComboKey hold=%s", tostring(targetHeld))
        Runtime.prevTargetHeld = targetHeld
    end

    local comboHeld = mode ~= nil
    if comboHeld ~= Runtime.prevComboHeld then
        Dbg("Disruptor combo hold=%s mode=%s", tostring(comboHeld), tostring(mode))
        Runtime.prevComboHeld = comboHeld
        if comboHeld then
            ResetComboSession()
            DC.ResetDisruptorComboFlags()
            Runtime.comboMode = mode
        else
            Runtime.comboTarget = nil
            Runtime.lockEntIndex = nil
            Runtime.lockWorldPos = nil
            Runtime.lockLostAt = -math.huge
            DC.ResetDisruptorComboFlags()
        end
    end

    if not comboHeld then
        Runtime.drawActive = false
        Runtime.drawMe = nil
        Runtime.drawTarget = nil
        DC.TrySelfSave(now, me)
        return
    end

    Runtime.comboMode = mode
    Runtime.drawMe = me
    Runtime.drawActive = true

    if mode == "target" then
        Runtime.comboTarget = Script.Target.ResolveOrKeep(now, me, Runtime.comboTarget, "combo")
        Runtime.drawTarget = Runtime.comboTarget
        if Runtime.comboTarget ~= nil then
            if not Runtime.fieldLocked then
                local _, fieldPos = DC.BuildDisruptorPlan(me, "target", now)
                if fieldPos then
                    Runtime.fieldPos = fieldPos
                end
            end
            DC.UpdateCombo(now, me, Runtime.comboTarget)
        else
            Script.Target.FollowCursor(now, me)
        end
        return
    end

    -- AOE mode
    local primary, fieldPos, hits = DC.BuildDisruptorPlan(me, "aoe", now)
    if primary then
        Runtime.comboTarget = primary
        if not Runtime.fieldLocked and fieldPos then
            Runtime.fieldPos = fieldPos
            Runtime.fieldHits = hits or 0
        end
        Runtime.drawTarget = primary
        DC.UpdateCombo(now, me, primary)
    else
        Runtime.drawTarget = nil
        Script.Target.FollowCursor(now, me)
    end
end

---Collect contiguous on-screen polylines for a world circle (or arc).
---@param center Vector
---@param radius number
---@param segments integer
---@param startAng number|nil radians
---@param sweepAng number|nil radians; nil = full circle
---@return Vec2[][]
function DC.CollectWorldRingRuns(center, radius, segments, startAng, sweepAng)
    local runs = {}
    ---@type Vec2[]|nil
    local run = nil
    local full = sweepAng == nil
    local start = startAng or 0
    ---@type number
    local sweep = (type(sweepAng) == "number") and sweepAng or (math.pi * 2)
    local steps = math.max(8, segments or DC.DRAW_CIRCLE_SEGMENTS)
    if not full then
        steps = math.max(6, math.floor(steps * math.abs(sweep) / (math.pi * 2)))
    end
    for i = 0, steps do
        local t = i / steps
        local ang = start + sweep * t
        local world = Vector(
            center.x + math.cos(ang) * radius,
            center.y + math.sin(ang) * radius,
            center.z
        )
        local screen, visible = Render.WorldToScreen(world)
        if visible and screen then
            if not run then
                run = {}
            end
            run[#run + 1] = screen
        elseif run then
            if #run >= 2 then
                runs[#runs + 1] = run
            end
            run = nil
        end
    end
    if run and #run >= 2 then
        runs[#runs + 1] = run
    end
    return runs
end

---@param runs Vec2[][]
---@param color Color
---@param thickness number
function DC.StrokeRingRuns(runs, color, thickness)
    if not runs or not color then
        return
    end
    thickness = thickness or 2
    for i = 1, #runs do
        local pts = runs[i]
        if #pts >= 2 then
            if Render.PolyLine then
                SafeValue(Render.PolyLine, pts, color, thickness)
            else
                for j = 2, #pts do
                    SafeValue(Render.Line, pts[j - 1], pts[j], color, thickness)
                end
            end
        end
    end
end

---World ring: soft glow + crisp stroke (optional dashed every-other segment).
---@param center Vector
---@param radius number
---@param color Color
---@param thickness number|nil
---@param dashed boolean|nil
function DC.DrawWorldCircle(center, radius, color, thickness, dashed)
    if not center or not radius or radius <= 0 or not color then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end
    thickness = thickness or 2
    local segments = DC.DRAW_CIRCLE_SEGMENTS
    if dashed then
        local step = math.pi * 2 / segments
        local dashLen = step * 2.2
        local gapLen = step * 1.4
        local ang = 0
        while ang < math.pi * 2 - 0.001 do
            local runs = DC.CollectWorldRingRuns(center, radius, 10, ang, dashLen)
            DC.StrokeRingRuns(runs, Color(color.r, color.g, color.b, math.floor((color.a or 200) * 0.35)), thickness + 3)
            DC.StrokeRingRuns(runs, color, thickness)
            ang = ang + dashLen + gapLen
        end
        return
    end
    local runs = DC.CollectWorldRingRuns(center, radius, segments)
    local glowA = math.floor((color.a or 200) * 0.32)
    DC.StrokeRingRuns(runs, Color(color.r, color.g, color.b, glowA), thickness + 4)
    DC.StrokeRingRuns(runs, color, thickness)
end

---@param a Vec2|nil
---@param b Vec2|nil
---@param color Color
---@param thickness number|nil
function DC.DrawScreenLine(a, b, color, thickness)
    if not a or not b or not color then
        return
    end
    SafeValue(Render.Line, a, b, color, thickness or 2)
end

---Field + Storm radius rings while combo key held.
function DC.DrawComboAimRadii()
    if not Runtime.drawActive then
        return
    end
    local center = Runtime.fieldPos
    if not center then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end

    local me = Runtime.drawMe
    local field = me and GetAbility(me, ABILITY.field) or nil
    local storm = me and GetAbility(me, ABILITY.storm) or nil
    local fieldR = DC.GetFieldRadius(field)
    local stormR = DC.GetStormRadius(storm)
    local now = SafeValue(GameRules.GetGameTime) or 0
    local pulse = 0.55 + 0.45 * math.sin(now * 3.2)
    local locked = Runtime.fieldLocked == true

    local fieldA = math.floor((locked and 230 or 160) + 40 * pulse)
    local stormA = math.floor((locked and 200 or 130) + 35 * pulse)
    -- Storm: dashed secondary; Field: solid primary (chat theme).
    DC.DrawWorldCircle(center, stormR, DC.ThemeSecondary(stormA), 2.5, true)
    DC.DrawWorldCircle(center, fieldR, DC.ThemePrimary(fieldA), locked and 3 or 2.2, false)

    local centerScreen, centerVis = Render.WorldToScreen(center)
    if centerVis and centerScreen then
        local coreA = math.floor(120 + 80 * pulse)
        SafeValue(Render.FilledCircle, centerScreen, locked and 5 or 4, DC.ThemePrimary(math.floor(coreA * 0.45)))
        SafeValue(Render.Circle, centerScreen, locked and 7 or 6, DC.ThemePrimaryLite(coreA, 0.55), 2)
        local arm = locked and 11 or 9
        local tick = DC.ThemePrimaryLite(math.floor(coreA * 0.85), 0.55)
        DC.DrawScreenLine(
            Vec2(centerScreen.x - arm, centerScreen.y),
            Vec2(centerScreen.x + arm, centerScreen.y),
            tick,
            1.5
        )
        DC.DrawScreenLine(
            Vec2(centerScreen.x, centerScreen.y - arm),
            Vec2(centerScreen.x, centerScreen.y + arm),
            tick,
            1.5
        )

        local hits = Runtime.fieldHits or 0
        if hits > 0 and Render.Text then
            local font = Script.Indicator.EnsureFont()
            if font ~= 0 then
                local label = string.format("%dx", hits)
                local labelPos = Vec2(centerScreen.x + 10, centerScreen.y - 16)
                TryCall(Render.Text, font, 13, label, Vec2(labelPos.x + 1, labelPos.y + 1), Color(0, 0, 0, 180))
                TryCall(Render.Text, font, 13, label, labelPos, DC.ThemePrimaryLite(240, 0.35))
            end
        end
    end

    -- Fence wall preview on Field rim (escape arc), even before cast.
    local target = Runtime.drawTarget
    local fencePos = Runtime.fencePos
    if not fencePos and target and fieldR then
        fencePos = DC.GetFenceAimPos(center, target, fieldR)
    end
    if fencePos then
        local dx = fencePos.x - center.x
        local dy = fencePos.y - center.y
        local ang = math.atan(dy, dx)
        local half = (DC.DRAW_FENCE_ARC_DEG * math.pi / 180) * 0.5
        local rim = math.max(80, fieldR - DC.FENCE_RIM_MARGIN)
        local arcRuns = DC.CollectWorldRingRuns(center, rim, 28, ang - half, half * 2)
        local fenceGlow = DC.ThemeSecondary(math.floor(70 + 50 * pulse))
        local fenceCol = DC.ThemePrimaryLite(math.floor(200 + 40 * pulse), 0.25)
        DC.StrokeRingRuns(arcRuns, fenceGlow, 7)
        DC.StrokeRingRuns(arcRuns, fenceCol, 3.5)

        local fenceScreen, fenceVis = Render.WorldToScreen(fencePos)
        if fenceVis and fenceScreen then
            if centerVis and centerScreen then
                DC.DrawScreenLine(
                    centerScreen,
                    fenceScreen,
                    DC.ThemePrimary(math.floor(90 + 40 * pulse)),
                    1.5
                )
            end
            SafeValue(Render.FilledCircle, fenceScreen, 5, DC.ThemePrimary(100))
            SafeValue(Render.Circle, fenceScreen, 7, DC.ThemePrimaryLite(230, 0.3), 2)
        end
    end
end

function DC.UpdateGlimpseHistory(me, now)
    local team = SafeValue(Entity.GetTeamNum, me)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if team == nil or not myPos then
        return
    end
    local heroes = SafeValue(Heroes.InRadius, myPos, 2500, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    local seen = {}
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemyHero(enemy) then
            local index = SafeValue(Entity.GetIndex, enemy)
            local pos = SafeValue(Entity.GetAbsOrigin, enemy)
            if index and pos then
                seen[index] = true
                local history = Runtime.glimpseHistory[index]
                if not history then
                    history = {}
                    Runtime.glimpseHistory[index] = history
                end
                local last = history[#history]
                if not last or (now - last.t) >= DC.GLIMPSE_HISTORY_INTERVAL then
                    history[#history + 1] = { t = now, x = pos.x, y = pos.y, z = pos.z }
                    while #history > DC.GLIMPSE_HISTORY_MAX do
                        table.remove(history, 1)
                    end
                end
            end
        end
    end
    for index, history in pairs(Runtime.glimpseHistory) do
        if not seen[index] and history and #history > 0 and (now - history[#history].t) > (DC.GLIMPSE_LOOKBACK + 2) then
            Runtime.glimpseHistory[index] = nil
        end
    end
end

function DC.UpdateGlimpseDrawState(me, now)
    Runtime.glimpseDrawList = nil
    if not UI.DrawGlimpse or not UI.DrawGlimpse:Get() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end
    local glimpse = GetAbility(me, ABILITY.glimpse)
    if UI.GlimpseOnlyCastable and UI.GlimpseOnlyCastable:Get() then
        if not glimpse or not CanCastAbility(glimpse, me) then
            return
        end
    elseif not glimpse or (SafeValue(Ability.GetLevel, glimpse) or 0) <= 0 then
        return
    end
    local team = SafeValue(Entity.GetTeamNum, me)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if team == nil or not myPos then
        return
    end
    local wRange = DC.GetAbilityCastRange(me, glimpse, DC.W_RANGE)
    local scan = wRange + 400
    local heroes = SafeValue(Heroes.InRadius, myPos, scan, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    local list = {}
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemyHero(enemy) then
            local unitName = SafeValue(NPC.GetUnitName, enemy)
            local returnPos = DC.GetGlimpseReturnPos(enemy, now)
            local current = SafeValue(Entity.GetAbsOrigin, enemy)
            if unitName and returnPos and current then
                list[#list + 1] = {
                    pos = returnPos,
                    current = current,
                    unitName = unitName,
                }
            end
        end
    end
    if #list > 0 then
        Runtime.glimpseDrawList = list
    end
end

---Panorama hero icon path (per-unit, for Glimpse return markers).
---@param unitName string|nil
---@return string|nil
function DC.HeroIconPath(unitName)
    if not unitName or unitName == "" then
        return nil
    end
    return "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c"
end

---Cached Render.LoadImage handle for a hero unit name.
---@param unitName string|nil
---@return integer|nil
function DC.GetHeroIconHandle(unitName)
    if not unitName or unitName == "" then
        return nil
    end
    Persistent.heroIcons = Persistent.heroIcons or {}
    local cached = Persistent.heroIcons[unitName]
    if cached ~= nil then
        if cached == 0 then
            return nil
        end
        return cached
    end
    local path = DC.HeroIconPath(unitName)
    if not path or not Render or not Render.LoadImage then
        Persistent.heroIcons[unitName] = 0
        return nil
    end
    local handle = SafeValue(Render.LoadImage, path)
    if type(handle) == "number" and handle ~= 0 then
        Persistent.heroIcons[unitName] = handle
        return handle
    end
    Persistent.heroIcons[unitName] = 0
    return nil
end

---Draw Glimpse return markers: one hero icon per enemy.
function DC.DrawGlimpseMarkers()
    local list = Runtime.glimpseDrawList
    if not list or #list == 0 then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end
    local drawTraj = UI.DrawTrajectory and UI.DrawTrajectory:Get() == true
    local iconSize = DC.DRAW_GLIMPSE_ICON
    local half = iconSize * 0.5
    local tint = Color(255, 255, 255, 235)
    local ring = DC.ThemePrimary(200)
    local ringFill = DC.ThemePrimary(55)
    local lineCol = DC.ThemePrimary(150)
    local Ind = Script.Indicator
    local mr, mg, mb = Ind.themePr or 120, Ind.themePg or 200, Ind.themePb or 255

    for i = 1, #list do
        local entry = list[i]
        local screen, visible = Render.WorldToScreen(entry.pos)
        if visible and screen then
            SafeValue(Render.FilledCircle, screen, half + 3, ringFill)
            SafeValue(Render.Circle, screen, half + 3, ring, 2)
            local handle = DC.GetHeroIconHandle(entry.unitName)
            if handle and Render.ImageCentered then
                SafeValue(
                    Render.ImageCentered,
                    handle,
                    screen,
                    Vec2(iconSize, iconSize),
                    tint,
                    4
                )
            elseif handle and Render.Image then
                SafeValue(
                    Render.Image,
                    handle,
                    Vec2(screen.x - half, screen.y - half),
                    Vec2(iconSize, iconSize),
                    tint,
                    4
                )
            else
                SafeValue(Render.FilledCircle, screen, DC.DRAW_GLIMPSE_MARKER, ringFill)
                SafeValue(Render.Circle, screen, DC.DRAW_GLIMPSE_MARKER, ring, 2)
            end
            if drawTraj and entry.current then
                local from, fromVisible = Render.WorldToScreen(entry.current)
                if fromVisible and from then
                    SafeValue(Render.Line, from, screen, lineCol, 2)
                end
            end
        end
        if MiniMap and MiniMap.DrawHeroIcon and entry.unitName and entry.pos then
            SafeValue(MiniMap.DrawHeroIcon, entry.unitName, entry.pos, mr, mg, mb, 220, 600)
        end
    end
end

function DC.TryManualGlimpseKey(now, me)
    if not UI.GlimpseKey then
        Runtime.prevGlimpseKeyDown = false
        Runtime.glimpseKeyUpAt = nil
        Runtime.glimpseManual = nil
        return
    end
    local down = IsBindHeld(UI.GlimpseKey)
    local pressed = down and not Runtime.prevGlimpseKeyDown
    Runtime.prevGlimpseKeyDown = down

    -- Debounced release: ignore brief IsBindHeld flicker mid-hold.
    if not down then
        if Runtime.glimpseKeyUpAt == nil then
            Runtime.glimpseKeyUpAt = now
        elseif (now - Runtime.glimpseKeyUpAt) >= 0.12 then
            Runtime.glimpseManual = nil
            Runtime.glimpseKeyUpAt = nil
        end
        return
    end
    Runtime.glimpseKeyUpAt = nil

    if Runtime.comboStage == "cast" or Runtime.comboStage == "wait_trap" then
        return
    end

    local team = SafeValue(Entity.GetTeamNum, me)
    local cursorEnemy = SafeValue(Input.GetNearestHeroToCursor, team, Enum.TeamType.TEAM_ENEMY)
    local state = Runtime.glimpseManual

    -- Start only on rising edge (one sequence per hold).
    if pressed then
        local enemy = cursorEnemy
        if not IsValidEnemyHero(enemy) or IsMagicImmune(enemy) then
            return
        end
        local returnPos = DC.GetGlimpseReturnPos(enemy, now)
        ClearAbilityIssued(ABILITY.glimpse)
        ClearAbilityIssued(ABILITY.field)
        if Runtime.abilityConsumed then
            Runtime.abilityConsumed[ABILITY.glimpse] = nil
            Runtime.abilityConsumed[ABILITY.field] = nil
        end
        Runtime.glimpseManual = {
            stage = "glimpse",
            enemy = enemy,
            returnPos = returnPos,
            startedAt = now,
            glimpseIssued = false,
            fieldIssued = false,
        }
        state = Runtime.glimpseManual
        Dbg("glimpse.manual start -> %s return=%s", FmtUnit(enemy), FmtPos(returnPos))
    end

    state = Runtime.glimpseManual
    if not state or state.stage == "done" then
        return
    end

    local enemy = state.enemy
    if IsValidEnemyHero(cursorEnemy) and not IsMagicImmune(cursorEnemy) then
        enemy = cursorEnemy
        state.enemy = enemy
    end
    if not IsValidEnemyHero(enemy) then
        return
    end

    if not state.fieldIssued then
        state.returnPos = DC.GetGlimpseReturnPos(enemy, now) or state.returnPos
    end
    if now - (state.startedAt or now) > DC.GLIMPSE_MANUAL_TIMEOUT then
        state.startedAt = now
    end

    local glimpse = GetAbility(me, ABILITY.glimpse)
    local field = GetAbility(me, ABILITY.field)
    local returnPos = state.returnPos or DC.GetGlimpseReturnPos(enemy, now)
    state.returnPos = returnPos

    local stage = state.stage
    if stage == "glimpse" then
        if state.glimpseIssued then
            if DC.AbilityStepDone(ABILITY.glimpse, glimpse, me) then
                state.stage = "field"
                Dbg("glimpse.manual glimpse done → field")
            end
            return
        end
        if not glimpse or not CanUseAbilityOnce(ABILITY.glimpse, glimpse, me) then
            if not glimpse or not IsAbilityEnabled(ABILITY.glimpse) then
                state.stage = "field"
            end
            return
        end
        local range = DC.GetAbilityCastRange(me, glimpse, DC.W_RANGE)
        if not IsTargetInCastRange(me, enemy, range) then
            return
        end
        if TargetNeedsLinkBreak(enemy) then
            if Script.HasPendingLinkbreak() or TryLinkbreaker(now, me, enemy) then
                return
            end
        end
        if CastTarget(now, me, glimpse, enemy, "glimpse.manual") then
            state.glimpseIssued = true
            HoldForAbilityCast(now, me)
        end
        return
    end

    if stage == "field" then
        if not field or not IsAbilityEnabled(ABILITY.field) then
            Runtime.glimpseManual = { stage = "done", startedAt = now }
            Dbg("glimpse.manual abort: no field")
            return
        end
        if state.fieldIssued then
            if DC.AbilityStepDone(ABILITY.field, field, me) then
                Dbg("glimpse.manual complete")
                Runtime.glimpseManual = { stage = "done", startedAt = now }
            end
            return
        end
        if not CanUseAbilityOnce(ABILITY.field, field, me) then
            return
        end
        if not returnPos then
            return
        end
        local eRange = DC.GetAbilityCastRange(me, field, DC.E_RANGE)
        local myPos = SafeValue(Entity.GetAbsOrigin, me)
        if myPos and Dist2D(myPos, returnPos) > eRange + 50 then
            HoldForAbilityCast(now, me)
            return
        end
        if CastPosition(now, me, field, returnPos, "kinetic_field.glimpse") then
            state.fieldIssued = true
            state.returnPos = returnPos
            Dbg("glimpse.manual field @ %s", FmtPos(returnPos))
        end
        return
    end
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    if not UI.ready then
        UI = InitializeUI()
    end
    Script.Target.Sync(true)
    Script.Indicator.RefreshTheme()
    Script.Indicator.ResetHudProbe()
    -- Re-show every load: Built-in Disruptor can hide Main Settings again after disable.
    if UI.MainSettings then
        EnsureMenuVisible(UI.MainSettings)
    end
    if UI.ExtraSettings then
        EnsureMenuVisible(UI.ExtraSettings)
    end
    if UI.HeroSettings then
        EnsureMenuVisible(UI.HeroSettings)
    end
    if UI.ItemsSettings then
        EnsureMenuVisible(UI.ItemsSettings)
    end
    if UI.IndicatorSettings then
        EnsureMenuVisible(UI.IndicatorSettings)
    end
    if UI.GlimpseSettings then
        EnsureMenuVisible(UI.GlimpseSettings)
    end
    Runtime.menuShowAsserts = 0
    if Persistent.logger then
        Persistent.logger:info(
            "menu ready path=Heroes/Hero List/Disruptor/{Main Settings,Extra Settings}"
        )
    end
end

---Menu can be browsed out of game; keep Main/Extra Settings unhidden while the menu is open.
function Script.OnFrame()
    if not UI.ready then
        return
    end
    if not Menu or not Menu.Opened or SafeValue(Menu.Opened) ~= true then
        return
    end
    EnsureMenuVisible(UI.MainSettings)
    EnsureMenuVisible(UI.ExtraSettings)
    EnsureMenuVisible(UI.HeroSettings)
    EnsureMenuVisible(UI.ItemsSettings)
    EnsureMenuVisible(UI.IndicatorSettings)
    EnsureMenuVisible(UI.GlimpseSettings)
end

function Script.OnUpdate()
    if not SafeValue(Engine.IsInGame) then
        return
    end

    if not UI.ready then
        UI = InitializeUI()
    end

    -- Built-in may hide Main Settings after our OnScriptsLoaded; re-assert briefly in-game too.
    if (Runtime.menuShowAsserts or 0) < 60 then
        Runtime.menuShowAsserts = (Runtime.menuShowAsserts or 0) + 1
        EnsureMenuVisible(UI.MainSettings)
        EnsureMenuVisible(UI.ExtraSettings)
        EnsureMenuVisible(UI.HeroSettings)
        EnsureMenuVisible(UI.ItemsSettings)
        EnsureMenuVisible(UI.IndicatorSettings)
        EnsureMenuVisible(UI.GlimpseSettings)
    end

    if not UI.Enabled or not UI.Enabled:Get() then
        Runtime.drawActive = false
        return
    end

    local now = SafeValue(GameRules.GetGameTime) or 0
    DC.UpdateCombat(now)
    -- Toggle before orders this frame; uses last OnDraw hitboxes.
    Script.Indicator.ProcessPointer()
end

function Script.OnDraw()
    if not SafeValue(Engine.IsInGame) then
        return
    end
    if not UI.ready or not UI.Enabled or not UI.Enabled:Get() then
        return
    end
    Script.Target.DrawMark()
    Script.Indicator.Draw()
    DC.DrawComboAimRadii()
    DC.DrawGlimpseMarkers()
end

---@param data table
---@param key Enum.ButtonCode
---@param event Enum.EKeyEvent
---@return boolean|nil
function Script.OnKeyEvent(data, key, event)
    return Script.Indicator.OnKeyEvent(key, event)
end

---Block HUD cast only when MMB toggle owns the click (in-game MMB bind).
---@param data table
---@param player userdata
---@param order Enum.UnitOrder
---@param target userdata|nil
---@param position Vector
---@param ability userdata|nil
---@param orderIssuer Enum.PlayerOrderIssuer
---@param npc userdata
---@param queue boolean
---@param showEffects boolean
---@return boolean
function Script.OnPrepareUnitOrders(
    data,
    player,
    order,
    target,
    position,
    ability,
    orderIssuer,
    npc,
    queue,
    showEffects
)
    if data and data.identifier and type(data.identifier) == "string" then
        if string.find(data.identifier, ORDER_PREFIX, 1, true) == 1 then
            return true
        end
    end
    if Script.Indicator.ShouldBlockOrder(order, ability) then
        return false
    end
    return true
end

function Script.OnPreHumanizer()
    -- Catch MMB before orders if Update races the bind.
    Script.Indicator.ProcessPointer()
end

function Script.OnThemeUpdate()
    Script.Indicator.RefreshTheme()
end

function Script.OnGameEnd()
    ResetRuntime()
    Script.Indicator.ResetHudProbe()
end

--#endregion

return Script
