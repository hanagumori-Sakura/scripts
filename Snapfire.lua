--[[
    Snapfire Combo — custom hero combo (abilities + Important / Semi / Other / Utility / Neutral Items).
    Replaces the built-in Snapfire Main Settings panels when that script is disabled.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local NAME = "Snapfire"
local HERO_TAB = "Snapfire"
local HERO_UNIT = "npc_dota_hero_snapfire"
local HERO_ICON = "panorama/images/heroes/icons/npc_dota_hero_snapfire_png.vtex_c"
local ORDER_PREFIX = "snapfire:"

local ABILITY = {
    cookie = "snapfire_firesnap_cookie",
    blast = "snapfire_scatterblast",
    shredder = "snapfire_lil_shredder",
    kisses = "snapfire_mortimer_kisses",
    gobble = "snapfire_gobble_up",
    spit = "snapfire_spit_creep",
}

local KISSES_MIN_RANGE_DEFAULT = 600
local CAST_GAP = 0.08
local GLOBAL_ORDER_GAP = 0.06
local KISSES_RETARGET_GAP = 0.20
local KISSES_RETARGET_MOVE = 80
local KISSES_CLICK_GAP = 0.18
local ATTACK_GAP = 0.35
local ORDER_QUEUE_MAX = 1
local DEBUG_HEARTBEAT = 0.50
-- Cast+self-hop ≈ 0.3 cast point + 0.48 jump; start early so land overlaps old stun.
local COOKIE_STUN_REFRESH = 1.35
-- After Refresher: AA while stun is healthy; open 2nd Cookie with the same cast+hop lead
-- (0.55 was too late — enemy walked out before hop landed).
local POST_REFRESH_STUN_LEAD = 1.15
-- Brief pause after shredder lands so 1–2 hits land before stun-refresh cookie.
-- Kept short: longer waits drop the stun chain (refresh at rem≤0).
local SHREDDER_HITS_BEFORE_REFRESH = 0.06
local BLAST_MIN_AIM_DIST = 300
-- Keep a small slack so hull / cast-point drift does not fire past the cone tip.
local BLAST_RANGE_SLACK = 50
-- Wait until roughly facing before Scatterblast (cone is easy to whiff after cookie hop).
local BLAST_FACE_READY = 0.05
-- Closer than this: never MoveTo-face (orbits the target after cookie hop).
local BLAST_MOVE_FACE_MIN_DIST = 420
local COOKIE_HOP_DEFAULT = 425
local COOKIE_IMPACT_DEFAULT = 300
-- Hull / landing drift so we do not hop when stun edge will miss.
local COOKIE_RANGE_SLACK = 40
-- Skip MoveTo-face for cookie when already this close (hop is nearly in place).
local COOKIE_MOVE_FACE_MIN_DIST = 280
-- Start Cookie/combo this many seconds before Eul / invuln ends.
local TIMING_COMBO_LEAD = 0.55
local SHREDDER_BUFF = "modifier_snapfire_lil_shredder_buff"
local COOKIE_HOP_MOD = "modifier_snapfire_firesnap_cookie_short_hop"
local KISSES_CHANNEL_MOD = "modifier_snapfire_mortimer_kisses"
local KISSES_PROJECTILE_SPEED = 1300
local KISSES_MIN_TRAVEL = 0.8
local KISSES_MAX_TRAVEL = 2.0

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
    { ABILITY.cookie, true },
    { ABILITY.blast, true },
    { ABILITY.shredder, true },
    { ABILITY.kisses, false },
    { ABILITY.gobble, true },
    { ABILITY.spit, true },
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

local LINKBREAKER_ITEMS = {
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

-- Total gold cost (assets/data/items.json) — pick cheapest ready pop.
local LINKBREAKER_POP_COST = {
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
}

local Runtime = {
    comboTarget = nil,
    kissesTarget = nil,
    lastCastAt = -math.huge,
    lastAnyOrderAt = -math.huge,
    lastKissesAimAt = -math.huge,
    lastOrderTag = nil,
    lastAimPos = nil,
    busyUntil = -math.huge,
    cookieFaced = false,
    heldForCastAt = -math.huge,
    prevComboHeld = false,
    prevKissesHeld = false,
    debugHeartbeatAt = -math.huge,
    deferExtraCookie = false,
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
    shredderLandedAt = -math.huge,
    ---Cookie orders that never entered phase (MoM cancel / interrupt). Back off to attacks.
    cookieIssueFails = 0,
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
    ---Re-assert Main Settings visibility after built-in Snapfire hides it.
    menuShowAsserts = 0,
    ---After cookie step-back, must face the enemy before hopping.
    cookieNeedFace = false,
    ---True while spacing for a stun-refresh cookie (do not Hold / Pike / mid-fight skip).
    cookieSpacing = false,
    ---Deferred/stun-refresh cookie must finish even if stun drops mid-spacing.
    cookieRefreshPending = false,
    ---When step-back started (timeout → cast anyway).
    cookieSpaceAt = -math.huge,
    ---Last step-back order time (avoid re-issue spam).
    cookieSpaceOrderAt = -math.huge,
    ---After Refresher: AA while stun lasts, start 2nd Cookie cycle near stun end.
    waitStunBeforeCycle = false,
    ---True once a fresh post-refresh stun (rem > lead) was observed.
    postRefreshStunArmed = false,
    ---When post-refresh wait started (hop / timeout).
    waitStunBeforeCycleAt = -math.huge,
    ---Simple target velocity for Mortimer Kisses lead.
    ---@type { pos: Vector|nil, at: number, vx: number, vy: number }
    kissesMotion = { pos = nil, at = -math.huge, vx = 0, vy = 0 },
    ---True once Mortimer Kisses channel modifier/API was observed this cast.
    kissesChannelSeen = false,
    ---Sticky lock: entity index + last world pos (re-acquire near corpse, not cursor thrash).
    lockEntIndex = nil,
    ---@type Vector|nil
    lockWorldPos = nil,
    lockLostAt = -math.huge,
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
    Runtime.kissesTarget = nil
    Runtime.lastCastAt = -math.huge
    Runtime.lastAnyOrderAt = -math.huge
    Runtime.lastKissesAimAt = -math.huge
    Runtime.lastOrderTag = nil
    Runtime.lastAimPos = nil
    Runtime.busyUntil = -math.huge
    Runtime.cookieFaced = false
    Runtime.heldForCastAt = -math.huge
    Runtime.prevComboHeld = false
    Runtime.prevKissesHeld = false
    Runtime.debugHeartbeatAt = -math.huge
    Runtime.deferExtraCookie = false
    Runtime.abilityIssued = {}
    Runtime.abilityIssuedAt = {}
    Runtime.abilityIssuedCharges = {}
    Runtime.blinkUsed = false
    Runtime.abilityChainStarted = false
    Runtime.shredderLandedAt = -math.huge
    Runtime.cookieIssueFails = 0
    Runtime.refresherUsed = false
    Runtime.lastFollowCursorAt = -math.huge
    Runtime.drawMe = nil
    Runtime.drawTarget = nil
    Runtime.drawActive = false
    Runtime.menuShowAsserts = 0
    Runtime.cookieNeedFace = false
    Runtime.cookieSpacing = false
    Runtime.cookieRefreshPending = false
    Runtime.cookieSpaceAt = -math.huge
    Runtime.cookieSpaceOrderAt = -math.huge
    Runtime.waitStunBeforeCycle = false
    Runtime.postRefreshStunArmed = false
    Runtime.waitStunBeforeCycleAt = -math.huge
    Runtime.kissesMotion = { pos = nil, at = -math.huge, vx = 0, vy = 0 }
    Runtime.kissesChannelSeen = false
    Runtime.lockEntIndex = nil
    Runtime.lockWorldPos = nil
    Runtime.lockLostAt = -math.huge
end

local function ResetComboSession()
    Runtime.cookieFaced = false
    Runtime.cookieNeedFace = false
    Runtime.cookieSpacing = false
    Runtime.cookieRefreshPending = false
    Runtime.cookieSpaceAt = -math.huge
    Runtime.cookieSpaceOrderAt = -math.huge
    Runtime.waitStunBeforeCycle = false
    Runtime.postRefreshStunArmed = false
    Runtime.waitStunBeforeCycleAt = -math.huge
    Runtime.heldForCastAt = -math.huge
    Runtime.lastAimPos = nil
    Runtime.busyUntil = -math.huge
    Runtime.lastOrderTag = nil
    Runtime.deferExtraCookie = false
    Runtime.abilityIssued = {}
    Runtime.abilityIssuedAt = {}
    Runtime.abilityIssuedCharges = {}
    Runtime.blinkUsed = false
    Runtime.abilityChainStarted = false
    Runtime.shredderLandedAt = -math.huge
    Runtime.cookieIssueFails = 0
    Runtime.refresherUsed = false
    Runtime.lastFollowCursorAt = -math.huge
    Runtime.kissesChannelSeen = false
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
        print("[Snapfire] " .. msg)
    end
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
        snapfireTab:LinkHero(heroId, Enum.Attributes.DOTA_ATTRIBUTE_STRENGTH)
    end
end

---Built-in Snapfire hides Main Settings when disabled; force it back on.
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

    ui.ComboKey:Disabled(disabled)
    ui.KissesAimKey:Disabled(disabled)
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
    ui.LinkbreakerItems:Disabled(disabled)
end

local function InitializeUI()
    local main = FindOrCreateMainSettings()
    if not main then
        error("[Snapfire] Failed to find/create Main Settings")
    end

    local extra = FindOrCreateExtraSettings()
    if not extra then
        error("[Snapfire] Failed to find/create Extra Settings")
    end

    local heroGroup = FindOrCreateGroup(main, "Main Settings", "Hero Settings", Enum.GroupSide.Left)
    local itemsGroup = FindOrCreateGroup(main, "Main Settings", "Items Settings", Enum.GroupSide.Right)
    local indicatorGroup = FindOrCreateGroup(
        extra,
        "Extra Settings",
        "Combo Indicator",
        Enum.GroupSide.Left
    )
    if not heroGroup or not itemsGroup or not indicatorGroup then
        error("[Snapfire] Failed to create Hero/Items/Combo Indicator groups")
    end

    EnsureMenuVisible(main)
    EnsureMenuVisible(extra)
    EnsureMenuVisible(heroGroup)
    EnsureMenuVisible(itemsGroup)
    EnsureMenuVisible(indicatorGroup)

    local ui = {
        MainSettings = main,
        ExtraSettings = extra,
        HeroSettings = heroGroup,
        ItemsSettings = itemsGroup,
        IndicatorSettings = indicatorGroup,
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

    ui.ComboKey = heroGroup:Bind("Combo Key", Enum.ButtonCode.KEY_MOUSE4, I.comboKey)
    ui.ComboKey:Properties("Combo Key", "Hold", false)
    ui.ComboKey:SetToggled(false)
    ui.ComboKey:ToolTip(
        "Hold: move to cursor if no target (global Move to Cursor), then combo the enemy near cursor (Style / Search Range)."
    )

    ui.KissesAimKey = heroGroup:Bind("Kisses Aim Key", Enum.ButtonCode.KEY_SPACE, I.kissesAim)
    ui.KissesAimKey:Properties("Kisses Aim Key", "Hold", false)
    ui.KissesAimKey:SetToggled(false)
    ui.KissesAimKey:ToolTip("Hold to cast / retarget Mortimer Kisses on the enemy under cursor.")

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

    ui.ItemUsageRow = itemsGroup:Label("Items Usage", I.itemsUsage)
    local itemGear = ui.ItemUsageRow:Gear("Items Usage", I.bars, true)

    ui.ItemUsageWidgets = {}
    for _, itemGroup in ipairs(ITEM_USAGE_GROUPS) do
        local usageItems = BuildUsageMultiSelectItems(itemGroup.items, itemGroup.defaultEnabled)
        local widget = itemGear:MultiSelect(itemGroup.widget, usageItems, true)
        widget:Update(usageItems, true, true)
        ui.ItemUsageWidgets[itemGroup.widget] = widget
    end

    -- Combo blink uses Cookie range; hide legacy distance slider.
    for _, staleName in ipairs({ "Distance from Target", "Blink Distance", "Blink Distance From Target" }) do
        local stale = itemGear:Find(staleName)
        if stale and stale.Visible then
            stale:Visible(false)
        end
    end

    ui.DistanceFromTarget = itemGear:Slider(
        "Blink Distance From Target",
        1,
        1100,
        50,
        FormatBlinkDistance
    )
    ui.DistanceFromTarget:ForceLocalization("Distance from Target")
    ui.DistanceFromTarget:Update(1, 1100, 50)
    MenuImage(ui.DistanceFromTarget, BLINK_ICON)
    ui.DistanceFromTarget:ToolTip(
        "Unused — Blink / Fallen Sky land at Cookie stun range"
    )
    if ui.DistanceFromTarget.Visible then
        ui.DistanceFromTarget:Visible(false)
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

    ui.LinkbreakerItems = itemsGroup:MultiSelect(
        "Linkbreaker Items",
        BuildMultiSelectItems(LINKBREAKER_ITEMS),
        false
    )
    MenuImage(ui.LinkbreakerItems, LINKENS_ICON)

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
---@param target userdata
---@param castRange number
---@return boolean
local function IsTargetInCastRange(me, target, castRange)
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
    -- Ignore Items Usage → Blink Distance From Target: land for Cookie stun hop.
    -- (Inline specials — GetCookieHopImpact is defined later in this file.)
    local hop = COOKIE_HOP_DEFAULT
    local impact = COOKIE_IMPACT_DEFAULT
    local cookie = SafeValue(NPC.GetAbility, me, ABILITY.cookie)
    if cookie then
        local h = SafeValue(Ability.GetLevelSpecialValueFor, cookie, "jump_horizontal_distance")
        if type(h) ~= "number" or h <= 0 then
            h = SafeValue(Ability.GetLevelSpecialValueFor, cookie, "jump_distance")
        end
        if type(h) == "number" and h > 0 then
            hop = h
        end
        local r = SafeValue(Ability.GetLevelSpecialValueFor, cookie, "impact_radius")
        if type(r) == "number" and r > 0 then
            impact = r
        end
    end

    local maxReach = hop + impact - COOKIE_RANGE_SLACK
    local minStand = hop - impact + COOKIE_RANGE_SLACK
    if minStand < 120 then
        minStand = 120
    end
    -- Sweet spot: slightly past hop length so Cookie hop lands stun (~450–500).
    local desired = hop + 40
    if desired > maxReach - 30 then
        desired = maxReach - 30
    end
    if desired < minStand + 30 then
        desired = minStand + 30
    end

    local dist = Dist2D(myPos, targetPos)
    -- Already inside Cookie stun reach — no blink.
    if dist <= maxReach + BLINK_CLOSE_MARGIN then
        return nil, desired
    end

    local landPos = targetPos:Extend2D(myPos, desired)
    local blinkRange = GetItemCastRange(me, blink, 1200) - BLINK_RANGE_MARGIN
    local travel = Dist2D(myPos, landPos)
    if blinkRange > 0 and travel > blinkRange then
        landPos = myPos:Extend2D(landPos, blinkRange)
        -- After clamping, still must end meaningfully closer.
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
local function IsLocalSnapfire(me)
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
    -- Extra padding beyond hop-impact when stepping back for cookie (engage).
    COOKIE_STEPBACK_EXTRA = 35,
    -- Stun-refresh: tiny step only — stun window is short.
    COOKIE_STEPBACK_REFRESH = 20,
    -- After lock dies: wait before re-picking (cursor thrash).
    LOCK_REACQUIRE_DELAY = 0.28,
    LOCK_REACQUIRE_RADIUS_MUL = 1.75,
    -- Cookie hop follows facing; GetTimeToFace alone is too loose (casts sideways).
    -- FindRotationAngle is radians → degrees; engage must be nearly aimed.
    COOKIE_FACE_MAX_DEG = 16,
    COOKIE_FACE_MAX_DEG_URGENT = 26,
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
    -- Snapfire ember default.
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
    CONFIG = "Snapfire",
    ABILITY_SLOTS = 6,
    ITEM_SLOTS = 6,
    -- HUD layout is stable; refresh often enough that badges do not drift after UI scale/layout.
    BOUNDS_TTL = 0.85,
    BOUNDS_MISS_TTL = 0.40,
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
    ---@type Color|nil
    colorBadgeBg = nil,
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
    if Ind.usageMap and Ind.abilityTracked then
        return
    end
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

    local tracked = {}
    for i = 1, #ABILITY_ENTRIES do
        tracked[ABILITY_ENTRIES[i][1]] = true
    end
    Ind.abilityTracked = tracked
end

function Script.Indicator.EnsureFont()
    local Ind = Script.Indicator
    if Ind.font ~= 0 then
        return Ind.font
    end
    if not Render or not Render.LoadFont then
        return 0
    end
    -- Bold HUD-style (matches common cheat ON/OFF badges).
    local flags = Enum.FontCreate.FONTFLAG_ANTIALIAS
    local names = { "Tahoma", "Segoe UI", "Verdana", "Arial" }
    for i = 1, #names do
        local ok, handle = TryCall(Render.LoadFont, names[i], flags, 800)
        if ok and type(handle) == "number" and handle ~= 0 then
            Ind.font = handle
            return handle
        end
        ok, handle = TryCall(Render.LoadFont, names[i], flags, 700)
        if ok and type(handle) == "number" and handle ~= 0 then
            Ind.font = handle
            return handle
        end
    end
    return 0
end

function Script.Indicator.RefreshTheme()
    local Ind = Script.Indicator
    Ind.colorShadow = Color(0, 0, 0, 220)
    -- Dark plate so ON/OFF never blends into the icon art.
    Ind.colorBadgeBg = Color(12, 14, 18, 210)
    Ind.colorOn = Color(255, 148, 64, 255)
    -- OFF is always red (not theme secondary).
    Ind.colorOff = Color(255, 56, 56, 255)
    if Menu and Menu.Style then
        local ok, primary = TryCall(Menu.Style, "primary")
        if ok and primary and type(primary.r) == "number" then
            Ind.colorOn = Color(primary.r, primary.g, primary.b, 255)
        end
    end
    -- Theme primary often is red too — keep ON distinct from OFF.
    local on = Ind.colorOn
    local off = Ind.colorOff
    if on and off then
        local dr = (on.r or 0) - (off.r or 0)
        local dg = (on.g or 0) - (off.g or 0)
        local db = (on.b or 0) - (off.b or 0)
        local dist2 = dr * dr + dg * dg + db * db
        -- ~90 RGB units: red theme vs red OFF would collide.
        if dist2 < 8100 then
            Ind.colorOn = Color(64, 220, 96, 255)
        end
    end
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
            local drawPanel = panel and Script.Indicator.AbilityDrawPanel(panel) or nil
            local bounds = Script.Indicator.GetPanelBoundsCached(
                "ab" .. tostring(slot) .. "d",
                drawPanel
            )
            if not bounds then
                bounds = Script.Indicator.GetPanelBoundsCached("ab" .. tostring(slot), panel)
            end
            -- Prefer the image on this HUD button. Never remap an untracked panel (innate)
            -- onto AbilitySelect via HudAbilityName — that shifted every badge one slot.
            local name = Script.Indicator.AbilityNameFromPanel(drawPanel or panel)
            if name then
                if not tracked[name] then
                    name = nil
                end
            else
                local fallback = Script.Indicator.HudAbilityName(me, slot)
                if fallback and tracked[fallback] then
                    name = fallback
                end
            end
            if bounds and name then
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
                local slotPanel = Ind.itemPanels[slot]
                local drawPanel = slotPanel and Script.Indicator.ItemDrawPanel(slotPanel) or nil
                local bounds = Script.Indicator.GetPanelBoundsCached(
                    "it" .. tostring(slot) .. "d",
                    drawPanel
                )
                if not bounds then
                    bounds = Script.Indicator.GetPanelBoundsCached(
                        "it" .. tostring(slot),
                        slotPanel
                    )
                end
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
                    Ind.boundsCache["it" .. tostring(slot) .. "d"] = {
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
            local name = Script.Indicator.ItemNameFromPanel(
                panel and Script.Indicator.ItemDrawPanel(panel) or panel
            )
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
            local nPanel = Ind.neutralPanel
            local nDraw = nPanel and Script.Indicator.ItemDrawPanel(nPanel) or nPanel
            local bounds = Script.Indicator.GetPanelBoundsCached("neutrald", nDraw)
            if not bounds then
                bounds = Script.Indicator.GetPanelBoundsCached("neutral", Ind.neutralPanel)
            end
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
                -- Keep innate on the bar (Ability0) so HUD slot indices match Panorama AbilityN.
                -- Skipping innate used to shift every badge one slot (blast on the fire icon, cookie missing).
                local skip = SafeValue(Ability.IsHidden, ability) == true
                    or SafeValue(Ability.IsAttributes, ability) == true
                local name = SafeValue(Ability.GetName, ability)
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
    if iconW >= 52 then
        fontSize = 12
    elseif iconW < 34 then
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

    local padX, padY = 3, 1
    local plateW = tw + padX * 2
    local plateH = th + padY * 2
    -- Top-right corner, slightly above the icon (like standard cheat HUD badges).
    local plateX = iconX + iconW - plateW - 1
    local plateY = iconY - 4
    if plateX < iconX - 2 then
        plateX = iconX - 2
    end
    local textX = plateX + padX
    local textY = plateY + padY

    local bg = Ind.colorBadgeBg or Color(12, 14, 18, 210)
    local color = enabled and (Ind.colorOn or Color(255, 148, 64, 255))
        or (Ind.colorOff or Color(255, 56, 56, 255))

    if Render and Render.FilledRect then
        TryCall(
            Render.FilledRect,
            Vec2(plateX, plateY),
            Vec2(plateX + plateW, plateY + plateH),
            bg,
            3,
            nil
        )
    end

    if font ~= 0 and Render and Render.Text then
        TryCall(Render.Text, font, fontSize, label, Vec2(textX, textY), color)
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

---Center icon square inside panel bounds (hotkey letters sit on the icon, not as left chrome).
---@param bounds { x: number, y: number, w: number, h: number }
---@return number, number, number
function Script.Indicator.ItemIconSquare(bounds)
    local side = bounds.w
    if bounds.h > 0 and bounds.h < side then
        side = bounds.h
    end
    local pitch = Script.Indicator.slotPitch
    if type(pitch) == "number" and pitch >= 24 and pitch < side * 1.35 then
        side = math.min(side, pitch)
    end
    if side < 18 then
        side = math.max(bounds.w, 18)
    end
    local ix = bounds.x + math.max(0, (bounds.w - side) * 0.5)
    local iy = bounds.y + math.max(0, (bounds.h - side) * 0.5)
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
    if me == nil or not IsLocalSnapfire(me) or not IsValidUnit(me) then
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

---@param unit userdata|nil
---@param me userdata
---@return boolean
local function IsValidGobbleTarget(unit, me)
    if not IsValidUnit(unit) or unit == me then
        return false
    end
    if SafeValue(NPC.IsIllusion, unit) == true then
        return false
    end
    -- Only allied heroes — random creeps / nameless units caused bad gobble casts.
    if SafeValue(Entity.IsHero, unit) ~= true then
        return false
    end
    local name = SafeValue(NPC.GetUnitName, unit)
    if not name or name == "" or name == HERO_UNIT then
        return false
    end
    return true
end

---@param me userdata
---@param ability userdata
---@return userdata|nil
local function ResolveGobbleTarget(me, ability)
    local team = SafeValue(Entity.GetTeamNum, me)
    if team == nil then
        return nil
    end

    local castRange = (SafeValue(Ability.GetCastRange, ability) or 150)
        + (SafeValue(NPC.GetCastRangeBonus, me) or 0)

    local hero = SafeValue(Input.GetNearestHeroToCursor, team, Enum.TeamType.TEAM_FRIEND)
    if IsValidGobbleTarget(hero, me) and SafeValue(NPC.IsEntityInRange, me, hero, castRange) == true then
        return hero
    end

    return nil
end

---@param me userdata
---@param abilityName string
---@return userdata|nil
local function GetAbility(me, abilityName)
    return SafeValue(NPC.GetAbility, me, abilityName)
end

local BELLY_MODIFIER = "modifier_snapfire_gobble_up_belly_has_unit"

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

---Spit is only valid while Mortimer actually holds a unit.
---@param me userdata
---@param spit userdata|nil
---@return boolean
local function CanSpit(me, spit)
    if not spit then
        return false
    end
    if SafeValue(NPC.HasModifier, me, BELLY_MODIFIER) ~= true then
        return false
    end
    return CanCastAbility(spit, me)
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

---Use an extra cookie charge to chain stun when current stun is about to expire.
---@param now number
---@param me userdata
---@param target userdata
---@param cookie userdata
---@return boolean
local function ShouldRefreshCookieStun(now, me, target, cookie)
    if SafeValue(NPC.HasModifier, me, COOKIE_HOP_MOD) == true then
        return false
    end
    if not CanCastAbility(cookie, me) then
        return false
    end
    if Runtime.abilityIssued[ABILITY.cookie] then
        return false
    end

    local remaining = GetStunRemaining(target, now)
    if remaining == nil or remaining <= 0 then
        return false
    end
    if remaining > COOKIE_STUN_REFRESH then
        return false
    end

    local charges = SafeValue(Ability.GetCurrentCharges, cookie)
    if type(charges) == "number" and charges <= 0 then
        return false
    end

    return true
end

---True while blast/shredder still need to fire before spending another cookie charge.
---@param me userdata
---@return boolean
local function IsComboFollowupPending(me)
    if IsAbilityEnabled(ABILITY.blast) then
        local blast = GetAbility(me, ABILITY.blast)
        if blast and (Runtime.abilityIssued[ABILITY.blast] or CanCastAbility(blast, me)) then
            return true
        end
    end
    if IsAbilityEnabled(ABILITY.shredder) then
        local shredder = GetAbility(me, ABILITY.shredder)
        if shredder and (Runtime.abilityIssued[ABILITY.shredder] or CanCastAbility(shredder, me)) then
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

    -- Ult CD often starts before the channel modifier appears; CD alone is not "spent".
    if abilityName == ABILITY.kisses then
        local owner = SafeValue(Ability.GetOwner, ability)
        local channeling = (owner and SafeValue(NPC.HasModifier, owner, KISSES_CHANNEL_MOD) == true)
            or SafeValue(Ability.IsChannelling, ability) == true
        if channeling then
            Runtime.kissesChannelSeen = true
            return false
        end
        if Runtime.abilityIssued[ABILITY.kisses] then
            local now = SafeValue(GameRules.GetGameTime) or 0
            local issuedAt = Runtime.abilityIssuedAt[ABILITY.kisses] or now
            if not Runtime.kissesChannelSeen then
                -- Still arming channel (or cast rejected). Do not free Refresher yet.
                if (now - issuedAt) < 2.25 then
                    return false
                end
                -- Timed out with no channel — allow combo to move on.
                return true
            end
            -- Channel was seen and ended: spent once CD is up.
            local cd = SafeValue(Ability.GetCooldown, ability) or 0
            return cd > 0.05
        end
    end

    local cd = SafeValue(Ability.GetCooldown, ability) or 0
    if cd > 0.05 then
        return true
    end

    -- Charge skills (cookie talent / etc.): CD stays 0 while charges remain.
    local chargesBefore = Runtime.abilityIssuedCharges[abilityName]
    local chargesNow = SafeValue(Ability.GetCurrentCharges, ability)
    if type(chargesBefore) == "number" and type(chargesNow) == "number" and chargesNow < chargesBefore then
        return true
    end

    -- Lil' Shredder: buff appears before CD sometimes registers.
    if abilityName == ABILITY.shredder then
        local owner = SafeValue(Ability.GetOwner, ability)
        if owner and SafeValue(NPC.HasModifier, owner, SHREDDER_BUFF) == true then
            return true
        end
    end

    -- Armlet: no real CD — toggle state is the spend signal.
    if abilityName == "item_armlet" then
        if SafeValue(Ability.GetToggleState, ability) == true then
            return true
        end
        local owner = ability and SafeValue(Ability.GetOwner, ability)
        if owner and SafeValue(NPC.HasModifier, owner, ARMLET_UNHOLY_MOD) == true then
            return true
        end
        return false
    end

    return false
end

local function ClearAbilityIssued(abilityName)
    Runtime.abilityIssued[abilityName] = nil
    Runtime.abilityIssuedAt[abilityName] = nil
    Runtime.abilityIssuedCharges[abilityName] = nil
    if abilityName == ABILITY.cookie then
        Runtime.cookieFaced = false
    end
    if abilityName == ABILITY.kisses then
        Runtime.kissesChannelSeen = false
    end
end

---Arm AA-wait after Refresher (cookie hop stun may not be on target yet).
function Script.ArmPostRefreshStunWait()
    local now = SafeValue(GameRules.GetGameTime) or 0
    Runtime.waitStunBeforeCycle = true
    Runtime.postRefreshStunArmed = false
    Runtime.waitStunBeforeCycleAt = now
end

---After Refresher/Shard lands: Cookie→Blast→Shredder (+ charge talent = 4 cookies total).
function Script.ReArmAfterRefresher()
    ClearAbilityIssued(ABILITY.cookie)
    ClearAbilityIssued(ABILITY.blast)
    ClearAbilityIssued(ABILITY.shredder)
    ClearAbilityIssued(ABILITY.kisses)
    ClearAbilityIssued(ABILITY.gobble)
    ClearAbilityIssued(ABILITY.spit)
    Runtime.deferExtraCookie = false
    Runtime.shredderLandedAt = -math.huge
    Runtime.cookieIssueFails = 0
    Runtime.cookieRefreshPending = false
    Runtime.cookieSpacing = false
    Runtime.cookieNeedFace = false
    -- Stay in ability-priority mode so refreshed Hex/etc. cannot cancel the 2nd Cookie chain.
    Runtime.abilityChainStarted = true
    Runtime.cookieFaced = true
    Runtime.refresherUsed = true
    Script.ArmPostRefreshStunWait()
    Dbg("refresher: second cycle armed (AA until stun low)")
end

---True while Mortimer Kisses channel is active (API IsChannelling alone is unreliable).
---@param me userdata
---@param kisses userdata|nil
---@return boolean
local function IsMortimerKissesChannel(me, kisses)
    if not me then
        return false
    end
    if SafeValue(NPC.HasModifier, me, KISSES_CHANNEL_MOD) == true then
        Runtime.kissesChannelSeen = true
        return true
    end
    kisses = kisses or GetAbility(me, ABILITY.kisses)
    if kisses and SafeValue(Ability.IsChannelling, kisses) == true then
        Runtime.kissesChannelSeen = true
        return true
    end
    local channeling = SafeValue(NPC.GetChannellingAbility, me)
    if channeling then
        if kisses and channeling == kisses then
            Runtime.kissesChannelSeen = true
            return true
        end
        if SafeValue(Ability.GetName, channeling) == ABILITY.kisses then
            Runtime.kissesChannelSeen = true
            return true
        end
    end
    return false
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
        -- Ult channel: keep the one-shot lock; never timeout-recast mid-channel.
        if abilityName == ABILITY.kisses and IsMortimerKissesChannel(me, ability) then
            return false
        end
        if IsAbilitySpent(abilityName, ability) then
            local chargesNow = ability and SafeValue(Ability.GetCurrentCharges, ability) or nil
            ClearAbilityIssued(abilityName)
            Dbg(
                "ability consumed: %s cd=%.2f charges=%s",
                abilityName,
                ability and (SafeValue(Ability.GetCooldown, ability) or -1) or -1,
                tostring(chargesNow)
            )
            if abilityName == ABILITY.shredder then
                Runtime.shredderLandedAt = now
            end
            if abilityName == ABILITY.cookie then
                Runtime.cookieIssueFails = 0
                Runtime.cookieRefreshPending = false
                Runtime.cookieSpacing = false
                Runtime.cookieNeedFace = false
            end
            -- L20 cookie charges: finish blast/shredder before spending the next charge
            -- (unless stun-refresh clears defer). Do not re-arm ready this frame.
            if abilityName == ABILITY.cookie
                and type(chargesNow) == "number"
                and chargesNow > 0 then
                Runtime.deferExtraCookie = true
                Dbg("defer extra cookie (charges left=%d)", chargesNow)
                return false
            end
            if abilityName == "item_refresher" or abilityName == "item_refresher_shard" then
                Script.ReArmAfterRefresher()
            end
            -- Toggle-on items: do not immediately re-arm and flip back off.
            if abilityName == "item_armlet" then
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
            -- Interrupted casts stay "ready" with no CD — retry once the Humanizer queue is clear.
            local timeout = (stillReady and not inPhase and queueEmpty)
                and ABILITY_ISSUE_CANCEL_TIMEOUT
                or ABILITY_ISSUE_TIMEOUT
            if (now - issuedAt) >= timeout then
                ClearAbilityIssued(abilityName)
                Dbg(
                    "ability issue timeout: %s (ready=%s phase=%s queue=%d)",
                    abilityName,
                    tostring(stillReady),
                    tostring(inPhase),
                    GetOrderQueueCount()
                )
                if abilityName == ABILITY.cookie then
                    Runtime.cookieIssueFails = (Runtime.cookieIssueFails or 0) + 1
                    Dbg("cookie issue fails=%d", Runtime.cookieIssueFails)
                end
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
local function MarkAbilityIssued(abilityName, ability, chargesBefore)
    Runtime.abilityIssued[abilityName] = true
    Runtime.abilityIssuedAt[abilityName] = SafeValue(GameRules.GetGameTime) or 0
    if chargesBefore ~= nil then
        Runtime.abilityIssuedCharges[abilityName] = chargesBefore
    else
        Runtime.abilityIssuedCharges[abilityName] = ability and SafeValue(Ability.GetCurrentCharges, ability) or nil
    end
    if abilityName == ABILITY.kisses then
        Runtime.kissesChannelSeen = false
    end
    if abilityName == ABILITY.cookie
        or abilityName == ABILITY.blast
        or abilityName == ABILITY.shredder
        or abilityName == ABILITY.kisses
        or abilityName == ABILITY.gobble
        or abilityName == ABILITY.spit
    then
        Runtime.abilityChainStarted = true
    end
end

---@param me userdata
---@param targetPos Vector
---@param ability userdata
---@return Vector
local function GetKissesAimPos(me, targetPos, ability)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos or not targetPos then
        return targetPos
    end

    local minRange = GetSpecial(ability, "min_range", KISSES_MIN_RANGE_DEFAULT)
    local maxRange = (SafeValue(Ability.GetCastRange, ability) or 3000)
        + (SafeValue(NPC.GetCastRangeBonus, me) or 0)

    local dist = Dist2D(myPos, targetPos)
    if dist < 1 then
        return myPos:Extend2D(targetPos, minRange)
    end
    if dist < minRange then
        return myPos:Extend2D(targetPos, minRange)
    end
    if maxRange > 0 and dist > maxRange then
        return myPos:Extend2D(targetPos, maxRange)
    end
    return targetPos
end

---Mortimer Kisses will not land on a target inside min_range (forced lob flies past them).
---@param me userdata
---@param target userdata
---@param kisses userdata
---@return boolean
---@return number dist
---@return number minRange
function Script.IsKissesTargetInRange(me, target, kisses)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    local minRange = GetSpecial(kisses, "min_range", KISSES_MIN_RANGE_DEFAULT)
    if type(minRange) ~= "number" or minRange < 1 then
        minRange = KISSES_MIN_RANGE_DEFAULT
    end
    if not myPos or not targetPos then
        return false, 0, minRange
    end
    local dist = Dist2D(myPos, targetPos)
    return dist + 1 >= minRange, dist, minRange
end

---Track enemy velocity and lead the kiss landing point by lob travel time.
---@param now number
---@param me userdata
---@param target userdata
---@param kisses userdata
---@return Vector|nil
local function GetKissesLeadAimPos(now, me, target, kisses)
    local pos = SafeValue(Entity.GetAbsOrigin, target)
    if not pos then
        return nil
    end

    local motion = Runtime.kissesMotion
    local dt = now - (motion.at or -math.huge)
    if motion.pos and dt > 0.02 and dt < 0.45 then
        motion.vx = (pos.x - motion.pos.x) / dt
        motion.vy = (pos.y - motion.pos.y) / dt
    end
    motion.pos = pos
    motion.at = now

    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local dist = Dist2D(myPos, pos)
    local speed = GetSpecial(kisses, "projectile_speed", KISSES_PROJECTILE_SPEED)
    if speed < 1 then
        speed = KISSES_PROJECTILE_SPEED
    end
    local minTravel = GetSpecial(kisses, "min_lob_travel_time", KISSES_MIN_TRAVEL)
    local maxTravel = GetSpecial(kisses, "max_lob_travel_time", KISSES_MAX_TRAVEL)
    local travel = dist / speed
    if travel < minTravel then
        travel = minTravel
    elseif travel > maxTravel then
        travel = maxTravel
    end

    local speed2 = math.sqrt((motion.vx or 0) ^ 2 + (motion.vy or 0) ^ 2)
    local leadPos = pos
    if speed2 > 30 then
        leadPos = Vector(
            pos.x + motion.vx * travel,
            pos.y + motion.vy * travel,
            pos.z
        )
    end
    return GetKissesAimPos(me, leadPos, kisses)
end

---@param now number
---@param me userdata
---@param ability userdata
---@param target userdata
---@param tag string
---@return boolean
local function CastTarget(now, me, ability, target, tag)
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
            MarkAbilityIssued(abilityName, ability, chargesBefore)
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
---@param ability userdata
---@param pos Vector
---@param tag string
---@param allowWhileChanneling boolean|nil
---@return boolean
local function CastPosition(now, me, ability, pos, tag, allowWhileChanneling)
    local okSend, reason = CanSendOrder(now, me, allowWhileChanneling == true)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag, allowWhileChanneling and KISSES_RETARGET_GAP or CAST_GAP) then
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
                MarkAbilityIssued(abilityName, ability, chargesBefore)
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
    -- Hold cancels MoveTo — never interrupt cookie spacing / turn-in.
    if Runtime.cookieSpacing or Runtime.cookieNeedFace then
        return false
    end
    -- Only stop an active attack swing. MoM/Shredder buff alone must not Hold-loop forever.
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
    if Runtime.cookieSpacing or Runtime.cookieNeedFace then
        return false
    end
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
        Dbg("skip %s: %s", tag, reason or "?")
        return false
    end
    if not CanIssue(now, tag, ATTACK_GAP) then
        return false
    end
    local player = SafeValue(Players.GetLocal)
    if not player then
        Dbg("skip attack: no player")
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

---Right-click during Mortimer Kisses: AttackTarget / Attack-Move lead so each glob tracks.
---@param now number
---@param me userdata
---@param target userdata
---@param aimPos Vector|nil
---@return boolean
local function TryKissesRightClick(now, me, target, aimPos)
    local tag = "kisses_click"
    -- Don't pile into Humanizer: only click on a clear queue.
    if GetOrderQueueCount() > 0 then
        return false
    end
    local okSend, reason = CanSendOrder(now, me, true)
    if not okSend then
        return false
    end
    if not CanIssue(now, tag, KISSES_CLICK_GAP) then
        return false
    end

    local player = SafeValue(Players.GetLocal)
    if not player then
        return false
    end

    local enemyPos = SafeValue(Entity.GetAbsOrigin, target)
    if not enemyPos and not aimPos then
        return false
    end

    -- Lead far from current body → attack-move ground; otherwise RMB the hero.
    local useLead = aimPos ~= nil
        and enemyPos ~= nil
        and Dist2D(aimPos, enemyPos) > 55

    local ok, err
    if useLead then
        ok, err = TryCall(
            Player.PrepareUnitOrders,
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
            nil,
            aimPos,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            me,
            false,
            false,
            true,
            true,
            OrderId(tag),
            false
        )
    else
        ok, err = TryCall(
            Player.AttackTarget,
            player,
            me,
            target,
            false,
            true,
            true,
            OrderId(tag),
            false
        )
    end

    if ok then
        -- No busy lock — only the click gap throttles RMB spam.
        MarkIssued(now, tag, 0)
        Runtime.lastKissesAimAt = now
        Runtime.lastAimPos = aimPos or enemyPos
        Dbg(
            "kisses RMB %s -> %s",
            useLead and "lead" or "target",
            useLead and FmtPos(aimPos) or FmtUnit(target)
        )
        return true
    end
    Dbg("FAIL %s: %s", tag, tostring(err))
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

---Cookie cast point + short hop: Scatterblast mid-flight aims sideways.
---@param me userdata
---@return boolean
local function IsCookieTraveling(me)
    if SafeValue(NPC.HasModifier, me, COOKIE_HOP_MOD) == true then
        return true
    end
    local cookie = GetAbility(me, ABILITY.cookie)
    if cookie and SafeValue(Ability.IsInAbilityPhase, cookie) == true then
        return true
    end
    return false
end

---@param me userdata
---@param blast userdata
---@return number
local function GetBlastCastRange(me, blast)
    return (SafeValue(Ability.GetCastRange, blast) or 800)
        + (SafeValue(NPC.GetCastRangeBonus, me) or 0)
end

---@param me userdata
---@param aimPos Vector
---@param dist number|nil
---@return boolean
local function NeedsFaceForBlast(me, aimPos, dist)
    local threshold = BLAST_FACE_READY
    if type(dist) == "number" and dist > 350 then
        threshold = 0.10
    end
    local faceTime = SafeValue(NPC.GetTimeToFacePosition, me, aimPos)
    if type(faceTime) == "number" and faceTime > threshold then
        return true
    end
    if SafeValue(NPC.IsTurning, me) == true then
        return true
    end
    return false
end

---Cookie hop length + landing stun radius from ability specials.
---@param cookie userdata|nil
---@return number hop
---@return number impact
local function GetCookieHopImpact(cookie)
    local hop = GetSpecial(cookie, "jump_horizontal_distance", 0)
    if hop <= 0 then
        hop = GetSpecial(cookie, "jump_distance", COOKIE_HOP_DEFAULT)
    end
    local impact = GetSpecial(cookie, "impact_radius", COOKIE_IMPACT_DEFAULT)
    return hop, impact
end

---True if self-cookie hop toward the enemy can land the stun (effective skill reach).
---@param me userdata
---@param target userdata
---@param cookie userdata
---@param allowClose? boolean  refresh: ignore min stand (no step-back)
---@return boolean
---@return number dist
---@return number hop
---@return number impact
local function CanCookieLandStun(me, target, cookie, allowClose)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not myPos or not targetPos then
        return false, math.huge, COOKIE_HOP_DEFAULT, COOKIE_IMPACT_DEFAULT
    end
    local dist = Dist2D(myPos, targetPos)
    local hop, impact = GetCookieHopImpact(cookie)
    local maxReach = hop + impact - COOKIE_RANGE_SLACK
    if not allowClose then
        local minStand = hop - impact + COOKIE_RANGE_SLACK
        -- Too close: hop overshoots and landing AoE misses the enemy.
        if dist < minStand then
            return false, dist, hop, impact
        end
    end
    return dist <= maxReach, dist, hop, impact
end

---Min / ideal distance so cookie hop lands with the enemy still inside impact AoE.
---@param cookie userdata|nil
---@param urgent? boolean  stun-refresh: shortest step that still clears minStand
---@return number minStand
---@return number ideal
---@return number hop
---@return number impact
function Script.GetCookieStandoff(cookie, urgent)
    local hop, impact = GetCookieHopImpact(cookie)
    local minStand = hop - impact + COOKIE_RANGE_SLACK
    if minStand < 120 then
        minStand = 120
    end
    local T = Script.Timing
    if urgent then
        local pad = (T and T.COOKIE_STEPBACK_REFRESH) or 28
        return minStand, minStand + pad, hop, impact
    end
    local extra = (T and T.COOKIE_STEPBACK_EXTRA) or 35
    local ideal = hop - impact * 0.55
    if ideal < minStand + extra then
        ideal = minStand + extra
    end
    return minStand, ideal, hop, impact
end

---After Cookie/Blast/Shredder/Kisses opened: true while the main cycle still needs the cast slot.
---False once those skills are spent/on CD so items can fire again when their CD returns.
---@param me userdata
---@return boolean
function Script.IsMainComboBusy(me)
    if not Runtime.abilityChainStarted then
        return false
    end
    if Runtime.deferExtraCookie
        or Runtime.cookieRefreshPending
        or Runtime.cookieSpacing
        or Runtime.cookieNeedFace
    then
        return true
    end
    if IsCookieTraveling(me) then
        return true
    end
    if Runtime.abilityIssued[ABILITY.cookie]
        or Runtime.abilityIssued[ABILITY.blast]
        or Runtime.abilityIssued[ABILITY.shredder]
        or Runtime.abilityIssued[ABILITY.kisses]
    then
        return true
    end
    if IsMortimerKissesChannel(me, GetAbility(me, ABILITY.kisses)) then
        return true
    end
    local function mainReady(abilityName)
        if not IsAbilityEnabled(abilityName) then
            return false
        end
        local ability = GetAbility(me, abilityName)
        return ability ~= nil and CanCastAbility(ability, me) == true
    end
    if mainReady(ABILITY.cookie)
        or mainReady(ABILITY.blast)
        or mainReady(ABILITY.shredder)
        or mainReady(ABILITY.kisses)
    then
        return true
    end
    return false
end

---Step away from the enemy when hugging so cookie stun does not overshoot past them.
---@param now number
---@param me userdata
---@param targetPos Vector
---@param ideal number
---@param minStand number|nil
---@return boolean handled  true = spacing in progress (caller must wait)
function Script.StepBackForCookie(now, me, targetPos, ideal, minStand)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos or not targetPos then
        return false
    end
    local dist = Dist2D(myPos, targetPos)
    if type(minStand) == "number" and dist >= minStand then
        Runtime.cookieSpacing = false
        return false
    end
    -- Already walking / recently ordered — do not spam MoveTo (fills Humanizer queue).
    if Runtime.cookieSpacing then
        if SafeValue(NPC.IsRunning, me) == true then
            return true
        end
        if (now - (Runtime.cookieSpaceOrderAt or -math.huge)) < 0.12 then
            return true
        end
    end
    local backPos = targetPos:Extend2D(myPos, ideal)
    if not backPos or Dist2D(myPos, backPos) < 20 then
        return false
    end
    local tag = "cookie_space"
    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return true
    end
    if not CanIssue(now, tag, 0.12) then
        return true
    end
    local ok, err = TryCall(NPC.MoveTo, me, backPos, false, false, false, true, OrderId(tag), false)
    if ok then
        MarkIssued(now, tag, 0.04)
        Runtime.cookieSpacing = true
        Runtime.cookieNeedFace = false
        if (Runtime.cookieSpaceAt or -math.huge) < 0 then
            Runtime.cookieSpaceAt = now
        end
        Runtime.cookieSpaceOrderAt = now
        Dbg("cookie step back → %s (ideal=%.0f)", FmtPos(backPos), ideal)
        return true
    end
    Dbg("FAIL %s: %s", tag, tostring(err))
    return true
end

---@param me userdata
---@param aimPos Vector
---@param loose? boolean  urgent refresh: cast sooner when almost facing
---@return boolean
local function NeedsFaceForCookie(me, aimPos, loose)
    if SafeValue(NPC.IsTurning, me) == true then
        return true
    end

    local T = Script.Timing
    local maxDeg = loose
            and ((T and T.COOKIE_FACE_MAX_DEG_URGENT) or 26)
        or ((T and T.COOKIE_FACE_MAX_DEG) or 16)

    -- Primary: yaw delta to the enemy (hop uses facing, not move intent).
    local rot = SafeValue(NPC.FindRotationAngle, me, aimPos)
    if type(rot) == "number" then
        local deg = math.abs(math.deg(rot))
        if deg > maxDeg then
            return true
        end
        return false
    end

    -- Fallback when FindRotationAngle is unavailable.
    local limit = loose and 0.06 or 0.14
    local faceTime = SafeValue(NPC.GetTimeToFacePosition, me, aimPos)
    if type(faceTime) == "number" then
        return faceTime > limit
    end

    -- Unknown facing: engage must face; urgent may cast to save the stun chain.
    return not loose
end

---Face enemy without collapsing standoff: only when already at min distance.
---@param now number
---@param me userdata
---@param targetPos Vector
---@param urgent? boolean
---@return boolean issuedFace
function Script.EnsureCookieFacing(now, me, targetPos, urgent)
    if not NeedsFaceForCookie(me, targetPos, urgent == true) then
        Runtime.cookieNeedFace = false
        return false
    end
    -- Already turning / recent face order — wait, do not spam MoveTo.
    if Runtime.cookieNeedFace then
        if SafeValue(NPC.IsTurning, me) == true or SafeValue(NPC.IsRunning, me) == true then
            return true
        end
        if (now - (Runtime.lastAnyOrderAt or -math.huge)) < (urgent and 0.10 or 0.18) then
            return true
        end
        -- Still misaligned after the wait — re-issue face below.
    end
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local facePos = targetPos
    if myPos then
        local dist = Dist2D(myPos, targetPos)
        -- Far enough MoveTo that the engine commits a real turn (6u was a no-op facing).
        local faceDist = 120
        if type(dist) == "number" and dist > 0 then
            if dist < faceDist then
                faceDist = math.max(40, dist * 0.5)
            elseif dist > 280 then
                faceDist = 200
            end
        end
        facePos = myPos:Extend2D(targetPos, faceDist)
    end
    local tag = "cookie_face"
    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        Dbg("skip %s: %s", tag, reason or "?")
        return true
    end
    if not CanIssue(now, tag, urgent and 0.12 or 0.18) then
        return true
    end
    local ok, err = TryCall(NPC.MoveTo, me, facePos, false, false, false, true, OrderId(tag), false)
    if ok then
        MarkIssued(now, tag, 0.05)
        Runtime.cookieNeedFace = true
        local rot = SafeValue(NPC.FindRotationAngle, me, targetPos)
        local deg = type(rot) == "number" and math.abs(math.deg(rot)) or -1
        Dbg("cookie face → enemy (deg=%.0f)", deg)
        return true
    end
    Dbg("FAIL %s: %s", tag, tostring(err))
    return Runtime.cookieNeedFace == true
end

---Walk to cookie standoff early (during AA / shredder wait) so refresh does not burn stun on spacing.
---@param now number
---@param me userdata
---@param targetPos Vector
---@param cookie userdata|nil
---@return boolean busy
function Script.TryPreSpaceForCookie(now, me, targetPos, cookie)
    if not cookie or not targetPos then
        return false
    end
    if Runtime.abilityIssued[ABILITY.cookie] or IsCookieTraveling(me) then
        return false
    end
    local minStand, ideal = Script.GetCookieStandoff(cookie, true)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos then
        return false
    end
    local dist = Dist2D(myPos, targetPos)
    if dist >= minStand then
        if Runtime.cookieSpacing then
            Runtime.cookieSpacing = false
        end
        return false
    end
    if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
        Runtime.debugHeartbeatAt = now
        Dbg("cookie pre-space dist=%.0f min=%.0f", dist, minStand)
    end
    Script.StepBackForCookie(now, me, targetPos, ideal, minStand)
    return true
end

---Spacing → face enemy → hold. Cookie hop follows facing; kiting away without a turn
---makes the jump go the wrong way. Refresh also steps back when hugging — hop from
---dist≈50 overshoots past impact and the stun never lands (then post-refresher stalls).
---@param now number
---@param me userdata
---@param targetPos Vector
---@param cookie userdata|nil
---@param urgent boolean|nil
---@return boolean wait
function Script.PrepCookieForCast(now, me, targetPos, cookie, urgent)
    local minStand, ideal = Script.GetCookieStandoff(cookie, urgent == true)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local dist = (myPos and targetPos) and Dist2D(myPos, targetPos) or 0

    if dist < minStand then
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg(
                "cookie too close dist=%.0f min=%.0f → step back%s",
                dist,
                minStand,
                urgent and " (refresh)" or ""
            )
        end
        Script.StepBackForCookie(now, me, targetPos, ideal, minStand)
        return true
    end

    Runtime.cookieSpacing = false
    Runtime.cookieSpaceAt = -math.huge

    -- Face via MoveTo toward the enemy (cancels kite-away). Never Hold/stop here —
    -- stop after cookie_face cancels the turn and loops: stop → face → stop…
    if Script.EnsureCookieFacing(now, me, targetPos, urgent == true) then
        return true
    end
    Runtime.cookieNeedFace = false

    if not urgent and HoldForAbilityCast(now, me) then
        return true
    end
    return false
end

---True if self-cookie hop can land stun on the target (cookie's real engage range).
---@param me userdata
---@param target userdata
---@param cookie userdata
---@param blast userdata|nil
---@return boolean
---@return number dist
---@return number hop
---@return number distAfter
local function CanCookieEngageReach(me, target, cookie, blast)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not myPos or not targetPos then
        return false, math.huge, COOKIE_HOP_DEFAULT, math.huge
    end

    local dist = Dist2D(myPos, targetPos)
    local hop, impact = GetCookieHopImpact(cookie)
    local distAfter = math.max(0, dist - hop)
    local maxStunReach = hop + impact - COOKIE_RANGE_SLACK
    local minStand = hop - impact + COOKIE_RANGE_SLACK

    -- Hugging the target: hop lands past them and the stun AoE misses.
    if dist < minStand then
        return false, dist, hop, hop - dist
    end

    -- Only engage when the hop can actually land stun — never waste a charge for a 400+ gap.
    if dist <= maxStunReach then
        return true, dist, hop, distAfter
    end

    return false, dist, hop, distAfter
end

---Aim Scatterblast along caster→target; when hugging, past the enemy so the cone has depth.
---Aim distance is always clamped to cast range (never "fire" past the cone tip).
---@param me userdata
---@param target userdata
---@param blast userdata
---@return Vector|nil aimPos
---@return number dist
---@return number castRange
local function GetBlastAimPos(me, target, blast)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not myPos or not targetPos then
        return nil, math.huge, 0
    end

    local castRange = GetBlastCastRange(me, blast)
    local pointBlank = GetSpecial(blast, "point_blank_range", 450)
    local minAim = math.max(BLAST_MIN_AIM_DIST, pointBlank * 0.55)
    local dist = Dist2D(myPos, targetPos)
    local aimDist = math.max(dist, minAim)
    if aimDist > castRange then
        aimDist = castRange
    end
    return myPos:Extend2D(targetPos, aimDist), dist, castRange
end

---@param me userdata
---@return boolean
local function IsChannelingKisses(me)
    return IsMortimerKissesChannel(me, GetAbility(me, ABILITY.kisses))
end

---True from CastPosition until channel ends (modifier lags; cookie must not cancel ult).
---@param me userdata
---@return boolean
local function IsKissesProtected(me)
    if IsChannelingKisses(me) then
        return true
    end
    if not Runtime.abilityIssued[ABILITY.kisses] then
        return false
    end
    local kisses = GetAbility(me, ABILITY.kisses)
    if kisses and IsAbilitySpent(ABILITY.kisses, kisses) then
        return false
    end
    return true
end

---Hold cookie engage/refresh while ult is in range and ready/casting/channeling.
---If the enemy is inside min_range, do not hold — ult would whiff; cookie refresh is better.
---@param me userdata
---@param target userdata|nil
---@return boolean
local function ShouldHoldCookieForKisses(me, target)
    if not IsAbilityEnabled(ABILITY.kisses) then
        return false
    end
    if IsKissesProtected(me) then
        return true
    end
    local kisses = GetAbility(me, ABILITY.kisses)
    if not kisses then
        return false
    end
    if not CanUseAbilityOnce(ABILITY.kisses, kisses, me) then
        return false
    end
    if target == nil then
        return true
    end
    local inRange = Script.IsKissesTargetInRange(me, target, kisses)
    return inRange
end

---Kisses Aim Key: start / retarget Mortimer Kisses at the locked enemy.
---Independent of Abilities MultiSelect (combo ult still requires Multiselect).
---@param now number
---@param me userdata
---@param target userdata
---@return boolean issued
local function UpdateKissesAim(now, me, target)
    local kisses = GetAbility(me, ABILITY.kisses)
    if not kisses then
        Dbg("kisses: ability missing")
        return false
    end

    local level = SafeValue(Ability.GetLevel, kisses) or 0
    if level <= 0 then
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("kisses: not learned")
        end
        return false
    end

    local aimPos = GetKissesLeadAimPos(now, me, target, kisses)
    if not aimPos then
        return false
    end

    local channeling = IsMortimerKissesChannel(me, kisses)

    if channeling then
        -- Dota retargets each glob via right-click (enemy or ground lead).
        if TryKissesRightClick(now, me, target, aimPos) then
            return true
        end
        -- Fallback: ability CastPosition retarget if RMB was blocked.
        if (now - Runtime.lastKissesAimAt) >= KISSES_RETARGET_GAP then
            if not Runtime.lastAimPos or Dist2D(Runtime.lastAimPos, aimPos) >= KISSES_RETARGET_MOVE then
                if CastPosition(now, me, kisses, aimPos, "kisses_aim", true) then
                    Runtime.lastKissesAimAt = now
                    Runtime.lastAimPos = aimPos
                    Dbg("kisses retarget @ %s", FmtPos(aimPos))
                    return true
                end
            end
        end
        return true
    end

    if not CanCastAbility(kisses, me) then
        if Runtime.abilityIssued[ABILITY.kisses] and IsAbilitySpent(ABILITY.kisses, kisses) then
            ClearAbilityIssued(ABILITY.kisses)
            Dbg("ability consumed: %s", ABILITY.kisses)
        end
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg(
                "kisses: not castable lvl=%s cd=%.2f hidden=%s exec=%s",
                tostring(SafeValue(Ability.GetLevel, kisses)),
                SafeValue(Ability.GetCooldown, kisses) or -1,
                tostring(SafeValue(Ability.IsHidden, kisses)),
                tostring(SafeValue(Ability.CanBeExecuted, kisses))
            )
        end
        return false
    end

    if not CanUseAbilityOnce(ABILITY.kisses, kisses, me, true) then
        return true
    end

    local inRange, dist, minRange = Script.IsKissesTargetInRange(me, target, kisses)
    if not inRange then
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("kisses skip: too close dist=%.0f min=%.0f", dist, minRange)
        end
        return false
    end

    if CastPosition(now, me, kisses, aimPos, "kisses_start", false) then
        Runtime.lastKissesAimAt = now
        Runtime.lastAimPos = aimPos
        Dbg("kisses start @ %s", FmtPos(aimPos))
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
    if IsAbilityEnabled(ABILITY.cookie) then
        local cookie = GetAbility(me, ABILITY.cookie)
        if cookie and (Runtime.abilityIssued[ABILITY.cookie] or CanCastAbility(cookie, me)) then
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

---@param item userdata|nil
---@param itemId string
---@return number
local function GetLinkbreakPopCost(item, itemId)
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

---Pop Linken's with the cheapest ready item from Linkbreaker Items.
---@param now number
---@param me userdata
---@param target userdata
---@return boolean
local function TryLinkbreaker(now, me, target)
    if not TargetNeedsLinkBreak(target) then
        return false
    end
    -- Never pop while Cookie→Blast→Shredder still owns the cast slot.
    if Script.IsMainComboBusy(me) then
        return false
    end
    -- Invulnerable / Eul: targeted pops fail and only produce issue-timeouts.
    if Script.IsComboWindowClosed(target, now) then
        return false
    end
    -- Don't interrupt Cookie→Blast→Shredder mid-cast; otherwise pop even during the fight.
    if Runtime.abilityIssued[ABILITY.cookie]
        or Runtime.abilityIssued[ABILITY.blast]
        or Runtime.abilityIssued[ABILITY.shredder]
        or IsCookieTraveling(me)
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
            if item
                and resolvedId
                and CanUseAbilityOnce(resolvedId, item, me, CanCastItem(item, me))
            then
                local castRange = GetItemCastRange(me, item, Script.ItemRange[resolvedId] or Script.ItemRange[itemId] or 0)
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

    if not bestItem or not bestId then
        return false
    end

    local tag = "linkbreak_" .. tostring(bestId):gsub("^item_", "")
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

---Refresher Orb / Shard: second Cookie→Blast→Shredder (and/or Kisses) cycle.
---@param now number
---@param me userdata
---@return boolean
function Script.TryRefresher(now, me)
    if Runtime.deferExtraCookie
        or Runtime.cookieRefreshPending
        or Runtime.cookieSpacing
        or IsCookieTraveling(me)
    then
        return false
    end
    -- Never refresh while Mortimer Kisses is casting/channeling (cancels the ult).
    if Runtime.abilityIssued[ABILITY.kisses]
        or IsMortimerKissesChannel(me, GetAbility(me, ABILITY.kisses))
    then
        return false
    end
    if Runtime.abilityIssued[ABILITY.cookie]
        or Runtime.abilityIssued[ABILITY.blast]
        or Runtime.abilityIssued[ABILITY.shredder]
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

    if stillReady(ABILITY.cookie)
        or stillReady(ABILITY.blast)
        or stillReady(ABILITY.shredder)
        or stillReady(ABILITY.kisses)
    then
        return false
    end

    -- First cycle finished, or all main skills already on CD at engage.
    if not Runtime.abilityChainStarted
        and not (
            IsAbilityEnabled(ABILITY.cookie)
            or IsAbilityEnabled(ABILITY.blast)
            or IsAbilityEnabled(ABILITY.shredder)
            or IsAbilityEnabled(ABILITY.kisses)
        )
    then
        return false
    end

    if not IsItemUsageEnabled("item_refresher") then
        return false
    end

    -- Shard first, then Orb — same Important Items toggle.
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
    -- CD returned while still holding: allow another Refresher cycle.
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
        -- Arm AA-wait immediately (don't wait for consume — cookie CD resets before that).
        Script.ArmPostRefreshStunWait()
        Dbg("refresher cast %s (arming 2nd cycle, AA until stun low)", itemId)
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
            "blink %s dist=%.0f desired=%.0f (cookie) -> %s",
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
    if abilityName == ABILITY.cookie and IsCookieTraveling(me) then
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

---Self buffs after Cookie refresh — never while cookie charge still needed for stun.
---@param now number
---@param me userdata
---@param target userdata|nil
---@return boolean
local function TryOtherMidChain(now, me, target)
    -- MoM/BM/etc. CastNoTarget cancels cookie cast-point and Scatterblast (log timeouts).
    if IsOrderActivelyResolving(ABILITY.cookie, GetAbility(me, ABILITY.cookie), me)
        or IsOrderActivelyResolving(ABILITY.blast, GetAbility(me, ABILITY.blast), me)
        or IsOrderActivelyResolving(ABILITY.shredder, GetAbility(me, ABILITY.shredder), me)
        or IsCookieTraveling(me)
    then
        return false
    end

    -- Finish deferred / stun-refresh cookie before MoM (AS autos cancel cookie cast).
    if Runtime.deferExtraCookie then
        return false
    end
    local cookie = GetAbility(me, ABILITY.cookie)
    if cookie and CanCastAbility(cookie, me) and (Runtime.cookieIssueFails or 0) < 2 then
        local charges = SafeValue(Ability.GetCurrentCharges, cookie)
        local stunned = target ~= nil
            and (
                GetStunRemaining(target, SafeValue(GameRules.GetGameTime) or 0) ~= nil
                or SafeValue(NPC.IsStunned, target) == true
            )
        if type(charges) == "number" and charges > 0 and stunned then
            return false
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

    -- MoM only once shredder is up (or unused) so it buffs attacks, not the spell cast.
    local shredderPending = false
    if IsAbilityEnabled(ABILITY.shredder) and Runtime.shredderLandedAt <= 0 then
        local shredder = GetAbility(me, ABILITY.shredder)
        if shredder and CanCastAbility(shredder, me) then
            shredderPending = true
        end
    end
    if not shredderPending and SafeValue(NPC.HasModifier, me, MOM_BERSERK_MOD) ~= true then
        if TryCastNoTargetItem(now, me, "item_mask_of_madness", "mom") then
            return true
        end
    end

    if TryToggleItemOn(now, me, "item_armlet", "armlet") then
        return true
    end

    return false
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

---Hurricane Pike on enemy for attack-range buff (after spells). Linkbreaker handles Linkens separately.
---@param now number
---@param me userdata
---@param target userdata
---@return boolean
local function TryUtilityMidChain(now, me, target)
    if IsOrderActivelyResolving(ABILITY.cookie, GetAbility(me, ABILITY.cookie), me)
        or IsOrderActivelyResolving(ABILITY.blast, GetAbility(me, ABILITY.blast), me)
        or IsOrderActivelyResolving(ABILITY.shredder, GetAbility(me, ABILITY.shredder), me)
        or IsCookieTraveling(me)
        or Runtime.deferExtraCookie
        or Runtime.cookieRefreshPending
        or Runtime.cookieSpacing
        or Runtime.cookieNeedFace
    then
        return false
    end

    if TargetNeedsLinkBreak(target) then
        return false
    end

    -- Prefer Refresher cycle before Pike shove (Pike often breaks cookie reach).
    if not Runtime.refresherUsed then
        local shard = GetItem(me, "item_refresher_shard")
        local orb = GetItem(me, "item_refresher")
        if (shard and CanCastItem(shard, me)) or (orb and CanCastItem(orb, me)) then
            return false
        end
    end

    local pike = GetItem(me, "item_hurricane_pike")
    if not pike or not IsItemUsageEnabled("item_hurricane_pike") then
        return false
    end
    if not CanUseAbilityOnce("item_hurricane_pike", pike, me, CanCastItem(pike, me)) then
        return false
    end

    local enemyRange = GetSpecial(pike, "cast_range_enemy", 425)
        + (SafeValue(NPC.GetCastRangeBonus, me) or 0)
    if SafeValue(NPC.IsEntityInRange, me, target, enemyRange) ~= true then
        return false
    end

    return CastTarget(now, me, pike, target, "pike")
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

---Combo Key: Important → Semi → Other → Utility → Neutral → Cookie → Blast → Shredder.
---@param now number
---@param me userdata
---@param target userdata
local function UpdateCombo(now, me, target)
    -- Protect from cast→channel gap: cookie_refresh was cancelling ult after kisses_combo.
    if IsKissesProtected(me) and not ShouldSkipAbilitiesForDamageReturn(now, target) then
        UpdateKissesAim(now, me, target)
        return
    end

    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not targetPos then
        Script.Target.FollowCursor(now, me, true)
        return
    end

    -- Eul / astral / Aegis: follow or blink into range — never start items/cookie while invuln
    -- (failed pops timeout and Cookie would set abilityChainStarted before Hex/Eblade).
    local windowClosed, windowRem, windowReason = Script.IsComboWindowClosed(target, now)
    if windowClosed then
        if Script.ShouldHoldForTiming(windowRem) then
            if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                Runtime.debugHeartbeatAt = now
                Dbg(
                    "combo wait window reason=%s remaining=%.2f → follow",
                    windowReason or "?",
                    windowRem or -1
                )
            end
            Script.Target.FollowCursor(now, me, true)
            return
        end
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("combo prep window reason=%s remaining=%.2f → blink/face", windowReason or "?", windowRem or -1)
        end
        if not Runtime.abilityChainStarted and TryBlinkEngage(now, me, targetPos) then
            return
        end
        FaceToward(now, me, targetPos)
        return
    end

    local okSend, reason = CanSendOrder(now, me, false)
    if not okSend then
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg(
                "combo wait target=%s reason=%s queue=%d last=%s",
                FmtUnit(target),
                reason or "?",
                GetOrderQueueCount(),
                tostring(Runtime.lastOrderTag)
            )
        end
        return
    end

    -- Blade Mail / Nyx: keep right-clicks, hold abilities until reflect ends (or switch on).
    if ShouldSkipAbilitiesForDamageReturn(now, target) then
        if Script.IsAttackBlocked(target) then
            Script.Target.FollowCursor(now, me, true)
        else
            AttackEnemy(now, me, target)
        end
        return
    end

    -- Hurricane Pike range buff: stand and shoot — no Face/Move, gobble/spit, or other cancels.
    if SafeValue(NPC.HasModifier, me, PIKE_RANGE_MOD) == true then
        if Script.IsAttackBlocked(target) then
            Script.Target.FollowCursor(now, me, true)
        else
            AttackEnemy(now, me, target)
        end
        return
    end

    -- Pop Linken's before targeted disables/nukes (Linkbreaker Items MultiSelect).
    -- Wait for an in-flight pop before issuing a second breaker (pike+bloodthorn spam).
    if TargetNeedsLinkBreak(target) and Script.HasPendingLinkbreak() then
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("combo wait linkbreak pending")
        end
        return
    end
    if TryLinkbreaker(now, me, target) then
        return
    end

    -- Important Items (Blink / BKB / Hex / Abyssal / Silence / Nullifier / Satanic).
    if TryImportantItems(now, me, target, targetPos) then
        return
    end

    -- Semi-Important (Veil / Eblade / Dagon / Atos / Gleipnir / Halberd / Harpoon / Shivas / Bloodstone).
    if TrySemiImportantItems(now, me, target, targetPos) then
        return
    end

    -- Other (Phase / Grenade / Diffusal / SE / BM / Mjollnir / Armlet / Manta / Meteor; MoM mid-chain).
    if TryOtherItems(now, me, target, targetPos) then
        return
    end

    -- Utility (Soul Ring / Drum / Pipe / Crimson / Mek / Greaves / Solar / Vessel; Pike mid-chain).
    if TryUtilityItems(now, me, target, targetPos) then
        return
    end

    -- Neutral (Spider Legs / Horn / Demonicon / Medallion / Crossbow / Heavy Blade / etc.).
    if TryNeutralItems(now, me, target, targetPos) then
        return
    end

    -- Don't open Cookie→Blast while Linkens is still up and a breaker can still be used.
    if TargetNeedsLinkBreak(target) and not Runtime.abilityChainStarted then
        if Script.HasPendingLinkbreak() then
            return
        end
        if TryLinkbreaker(now, me, target) then
            return
        end
    end

    -- After Refresher: wait for cookie_refresh hop stun to land, AA, then 2nd cycle near stun end.
    -- rem≈0.03 right after refresher is the *old* stun dying — do not treat as "stun low".
    if Runtime.waitStunBeforeCycle then
        local rem = GetStunRemaining(target, now)
        if IsCookieTraveling(me) or Runtime.abilityIssued[ABILITY.cookie] then
            if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                Runtime.debugHeartbeatAt = now
                Dbg("post-refresher: wait cookie hop/stun land")
            end
            return
        end

        if rem ~= nil and rem > POST_REFRESH_STUN_LEAD then
            Runtime.postRefreshStunArmed = true
            if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                Runtime.debugHeartbeatAt = now
                Dbg("post-refresher: AA while stun remaining=%.2f", rem)
            end
            -- Space for 2nd Cookie while AA'ing so engage does not pause on step-back.
            local cookiePre = GetAbility(me, ABILITY.cookie)
            if cookiePre and Script.TryPreSpaceForCookie(now, me, targetPos, cookiePre) then
                return
            end
            if not Script.IsComboWindowClosed(target, now) then
                AttackEnemy(now, me, target)
            end
            return
        end

        if not Runtime.postRefreshStunArmed then
            local waited = now - (Runtime.waitStunBeforeCycleAt or now)
            -- Hop+land ≈ 0.8s. If no healthy stun by then, refresh missed — don't idle 2.4s.
            local noFreshStun = rem == nil or rem <= POST_REFRESH_STUN_LEAD
            if noFreshStun and waited < 0.90 then
                if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                    Runtime.debugHeartbeatAt = now
                    Dbg(
                        "post-refresher: wait fresh stun (old rem=%s)",
                        rem ~= nil and string.format("%.2f", rem) or "?"
                    )
                end
                if not Script.IsComboWindowClosed(target, now) then
                    AttackEnemy(now, me, target)
                end
                return
            end
            if noFreshStun then
                Dbg("post-refresher: no fresh stun — start 2nd cycle")
            else
                Dbg("post-refresher: stun arm timeout — start 2nd cycle")
            end
        else
            Dbg(
                "post-refresher: stun low — start 2nd Cookie cycle (rem=%s)",
                rem ~= nil and string.format("%.2f", rem) or "gone"
            )
        end

        Runtime.waitStunBeforeCycle = false
        Runtime.postRefreshStunArmed = false
    end

    -- Main engage: Cookie → Scatterblast → Lil' Shredder.
    -- Extra charge: refresh ASAP after follow-ups (while stunned), else near stun end.
    if IsAbilityEnabled(ABILITY.cookie) then
        local cookie = GetAbility(me, ABILITY.cookie)
        local targetStunned = GetStunRemaining(target, now) ~= nil
            or SafeValue(NPC.IsStunned, target) == true
        local followupPending = IsComboFollowupPending(me)
        local shredderHitWait = Runtime.shredderLandedAt > 0
            and (now - Runtime.shredderLandedAt) < SHREDDER_HITS_BEFORE_REFRESH
        local holdCookieForKisses = ShouldHoldCookieForKisses(me, target)
        local stunRemNow = GetStunRemaining(target, now)
        local stunUrgent = stunRemNow ~= nil and stunRemNow <= COOKIE_STUN_REFRESH
        -- Stun already gone: do not wait shredder hits — refresh immediately to re-stun.
        local stunDropped = stunRemNow == nil and not targetStunned

        -- Pre-space right after cookie hop (even while blast/shredder still pending) so
        -- Scatterblast fires from standoff and refresh does not burn stun on walking.
        if cookie
            and (Runtime.deferExtraCookie or Runtime.cookieRefreshPending or Runtime.cookieSpacing)
            and not IsCookieTraveling(me)
            and not Runtime.abilityIssued[ABILITY.cookie]
        then
            if Script.TryPreSpaceForCookie(now, me, targetPos, cookie) then
                return
            end
        end

        -- Deferred 2nd charge: reserved until blast/shredder finish — never unlock early
        -- (that spent the charge as a random engage and broke the cycle).
        -- Also wait for Mortimer Kisses: refresh hop cancels the channel.
        local deferredRefresh = false
        local skipShredderWait = stunUrgent or stunDropped
        if Runtime.deferExtraCookie and not followupPending and (not shredderHitWait or skipShredderWait) then
            if holdCookieForKisses then
                if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                    Runtime.debugHeartbeatAt = now
                    Dbg("hold cookie refresh for kisses")
                end
            else
                deferredRefresh = true
                Runtime.deferExtraCookie = false
                Runtime.cookieIssueFails = 0
                Runtime.cookieRefreshPending = true
                if targetStunned or (stunRemNow ~= nil and stunRemNow > 0) then
                    Dbg("extra cookie refresh (stun held)")
                else
                    Dbg("extra cookie after followups")
                end
            end
        end

        local stunRefresh = deferredRefresh
            or Runtime.cookieRefreshPending
            or (cookie ~= nil and ShouldRefreshCookieStun(now, me, target, cookie))
        if stunRefresh and followupPending then
            stunRefresh = false
        end
        if stunRefresh and shredderHitWait and not skipShredderWait then
            stunRefresh = false
        end
        if stunRefresh and holdCookieForKisses then
            stunRefresh = false
        end
        if stunRefresh then
            Runtime.deferExtraCookie = false
            Runtime.cookieRefreshPending = true
        end

        local allowCookie = stunRefresh or not Runtime.deferExtraCookie
        -- Dead cookie orders (cancelled by MoM/etc.) — stop spamming and fall through to attacks.
        if allowCookie and not stunRefresh and (Runtime.cookieIssueFails or 0) >= 2 then
            allowCookie = false
            if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                Runtime.debugHeartbeatAt = now
                Dbg("cookie skip: issue fails=%d (attack instead)", Runtime.cookieIssueFails)
            end
        end
        if allowCookie and cookie and CanUseAbilityOnce(ABILITY.cookie, cookie, me) then
            if stunRefresh or targetStunned or Runtime.cookieRefreshPending then
                -- Refresh: allowClose for max-reach check; PrepCookie steps back when hugging
                -- (cast-in-place from dist<minStand overshoots past impact).
                local canStun, dist, hop, impact = CanCookieLandStun(me, target, cookie, true)
                if not canStun and (deferredRefresh or Runtime.cookieRefreshPending) then
                    local canReach, d2, hop2 = CanCookieEngageReach(me, target, cookie, GetAbility(me, ABILITY.blast))
                    if canReach then
                        canStun = true
                        dist, hop = d2, hop2
                    end
                end
                if not canStun then
                    if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                        Runtime.debugHeartbeatAt = now
                        Dbg(
                            "cookie skip: stun out of reach dist=%.0f max=%.0f (hop=%.0f impact=%.0f)",
                            dist,
                            hop + impact - COOKIE_RANGE_SLACK,
                            hop,
                            impact
                        )
                    end
                    FaceToward(now, me, targetPos)
                    return
                end
                if Script.PrepCookieForCast(now, me, targetPos, cookie, true) then
                    return
                end
                if CastTarget(now, me, cookie, me, stunRefresh and "cookie_refresh" or "cookie") then
                    Runtime.cookieRefreshPending = false
                    Runtime.cookieSpacing = false
                    if stunRefresh then
                        Dbg(
                            "cookie stun refresh remaining=%.2f dist=%.0f",
                            GetStunRemaining(target, now) or -1,
                            dist
                        )
                    end
                    return
                end
            else
                local blastForRange = GetAbility(me, ABILITY.blast)
                local canReach, dist, hop, distAfter = CanCookieEngageReach(me, target, cookie, blastForRange)
                if not canReach then
                    local minStand = select(1, Script.GetCookieStandoff(cookie, false))
                    if dist < minStand then
                        if Script.PrepCookieForCast(now, me, targetPos, cookie, false) then
                            return
                        end
                    end
                    if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                        Runtime.debugHeartbeatAt = now
                        Dbg(
                            "cookie skip: too far dist=%.0f hop=%.0f after=%.0f (need blink/gap)",
                            dist,
                            hop,
                            distAfter
                        )
                    end
                    FaceToward(now, me, targetPos)
                    return
                else
                    if Script.PrepCookieForCast(now, me, targetPos, cookie, false) then
                        Runtime.cookieFaced = true
                        return
                    end
                    Runtime.cookieFaced = true
                    if CastTarget(now, me, cookie, me, "cookie") then
                        Runtime.cookieSpacing = false
                        local rot = SafeValue(NPC.FindRotationAngle, me, targetPos)
                        local deg = type(rot) == "number" and math.abs(math.deg(rot)) or -1
                        Dbg(
                            "cookie engage dist=%.0f hop=%.0f after=%.0f faceDeg=%.0f",
                            dist,
                            hop,
                            distAfter,
                            deg
                        )
                        return
                    end
                end
            end
        end
    end

    if IsAbilityEnabled(ABILITY.blast) then
        local blast = GetAbility(me, ABILITY.blast)
        if blast and CanUseAbilityOnce(ABILITY.blast, blast, me) then
            -- Cookie still resolving: never FaceToward/MoveTo (cancels cookie cast).
            if Runtime.abilityIssued[ABILITY.cookie] then
                if IsCookieTraveling(me) then
                    if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                        Runtime.debugHeartbeatAt = now
                        Dbg("blast: wait cookie hop/phase")
                    end
                end
                return
            end

            -- Wait out Cookie hop / cast point so the cone is not fired mid-turn.
            if IsCookieTraveling(me) then
                if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                    Runtime.debugHeartbeatAt = now
                    Dbg("blast: wait cookie hop/phase")
                end
                return
            end

            local aimPos, dist, castRange = GetBlastAimPos(me, target, blast)
            if not aimPos then
                return
            end

            local maxHit = castRange - BLAST_RANGE_SLACK
            if dist > maxHit then
                if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                    Runtime.debugHeartbeatAt = now
                    Dbg("blast: out of range dist=%.0f max=%.0f", dist, maxHit)
                end
                -- Close the gap instead of firing a cone that cannot reach.
                FaceToward(now, me, targetPos)
                return
            end

            -- After cookie hop we are already on top of them — MoveTo-face orbits forever.
            if dist <= BLAST_MOVE_FACE_MIN_DIST then
                if StopOrbitIfRunning(now, me) then
                    return
                end
            elseif NeedsFaceForBlast(me, aimPos, dist) then
                FaceToward(now, me, aimPos)
                return
            end

            if CastPosition(now, me, blast, aimPos, "blast", false) then
                Dbg("blast aim dist=%.0f range=%.0f @ %s", dist, castRange, FmtPos(aimPos))
                return
            end
        end
    end

    if IsAbilityEnabled(ABILITY.shredder) then
        local shredder = GetAbility(me, ABILITY.shredder)
        local blast = GetAbility(me, ABILITY.blast)
        -- Never shredder while Scatterblast is still resolving (cancels blast).
        if blast and Runtime.abilityIssued[ABILITY.blast] and not IsAbilitySpent(ABILITY.blast, blast) then
            return
        end
        local blastRange = blast and (GetBlastCastRange(me, blast) - BLAST_RANGE_SLACK) or 800
        -- Mid-chain / post-refresher: always try shredder once Cookie opened the fight.
        local nearFight = Runtime.abilityChainStarted
            or SafeValue(NPC.IsEntityInRange, me, target, blastRange) == true
            or SafeValue(NPC.HasModifier, me, SHREDDER_BUFF) == true
        if nearFight and shredder and CanUseAbilityOnce(ABILITY.shredder, shredder, me) then
            local attacks = GetSpecial(shredder, "buffed_attacks", 5)
            local extraTargets = GetSpecial(shredder, "extra_targets", 0)
            if CastNoTarget(now, me, shredder, "shredder") then
                Dbg("shredder cast attacks=%.0f extraTargets=%.0f", attacks, extraTargets)
                return
            end
        end
    end

    -- MoM / BM / Mjollnir / Armlet after spells so they cannot cancel Cookie→Blast→Refresh.
    if TryOtherMidChain(now, me, target) then
        return
    end

    -- Ult before Refresher: with only Kisses enabled, refresher was cancelling the channel.
    if IsAbilityEnabled(ABILITY.kisses) then
        local kisses = GetAbility(me, ABILITY.kisses)
        if kisses and CanUseAbilityOnce(ABILITY.kisses, kisses, me) then
            local inRange, dist, minRange = Script.IsKissesTargetInRange(me, target, kisses)
            if not inRange then
                if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                    Runtime.debugHeartbeatAt = now
                    Dbg("kisses_combo skip: too close dist=%.0f min=%.0f", dist, minRange)
                end
            else
                local blobs = GetSpecial(kisses, "projectile_count", 8)
                local aimPos = GetKissesLeadAimPos(now, me, target, kisses) or GetKissesAimPos(me, targetPos, kisses)
                if aimPos and CastPosition(now, me, kisses, aimPos, "kisses_combo", false) then
                    Dbg("kisses_combo blobs=%.0f @ %s", blobs, FmtPos(aimPos))
                    return
                end
            end
        end
    end

    -- First cycle spent (including Kisses channel finished): Refresher / Shard before Pike.
    if Script.TryRefresher(now, me) then
        return
    end

    -- Hurricane Pike for range buff after spells (not for Linkens — that's Linkbreaker).
    if TryUtilityMidChain(now, me, target) then
        return
    end

    -- Aghs: Spit / Gobble after main engage so they don't steal the Cookie→Blast window.
    if IsAbilityEnabled(ABILITY.spit) then
        local spit = GetAbility(me, ABILITY.spit)
        if spit and CanUseAbilityOnce(ABILITY.spit, spit, me, CanSpit(me, spit)) then
            Dbg(
                "spit ready belly=%s hidden=%s",
                tostring(SafeValue(NPC.HasModifier, me, BELLY_MODIFIER)),
                tostring(SafeValue(Ability.IsHidden, spit))
            )
            local aimPos = GetKissesAimPos(me, targetPos, spit)
            if CastPosition(now, me, spit, aimPos, "spit", false) then
                return
            end
        end
    end

    if IsAbilityEnabled(ABILITY.gobble) then
        local gobble = GetAbility(me, ABILITY.gobble)
        if gobble and CanUseAbilityOnce(ABILITY.gobble, gobble, me) then
            local gobbleTarget = ResolveGobbleTarget(me, gobble)
            if gobbleTarget then
                Dbg("gobble candidate=%s", FmtUnit(gobbleTarget))
                if CastTarget(now, me, gobble, gobbleTarget, "gobble") then
                    return
                end
            end
        end
    end

    -- Don't right-click while spells still need to land — attacks cancel face/cast (blast whiffs).
    if IsComboFollowupPending(me) then
        return
    end

    -- Hold attacks while a cookie refresh is about to go out (or cast is in flight).
    local cookieAb = GetAbility(me, ABILITY.cookie)
    local stunLeft = GetStunRemaining(target, now)
    local wantCookieRefresh = cookieAb ~= nil
        and CanCastAbility(cookieAb, me)
        and (Runtime.cookieIssueFails or 0) < 2
        and not ShouldHoldCookieForKisses(me, target)
        and (
            Runtime.deferExtraCookie
            or Runtime.cookieRefreshPending
            or Runtime.cookieSpacing
            or (stunLeft ~= nil and stunLeft <= COOKIE_STUN_REFRESH)
        )
    if wantCookieRefresh then
        if Script.TryPreSpaceForCookie(now, me, targetPos, cookieAb) then
            return
        end
        return
    end

    local blastAb = GetAbility(me, ABILITY.blast)
    local shredderAb = GetAbility(me, ABILITY.shredder)
    if IsOrderActivelyResolving(ABILITY.cookie, cookieAb, me)
        or IsOrderActivelyResolving(ABILITY.blast, blastAb, me)
        or IsOrderActivelyResolving(ABILITY.shredder, shredderAb, me)
        or IsOrderActivelyResolving("item_meteor_hammer", GetItem(me, "item_meteor_hammer"), me)
        or IsCookieTraveling(me)
        or SafeValue(NPC.IsChannellingAbility, me) == true
    then
        return
    end

    -- Cookie order still queued / fading in: don't RMB-cancel it.
    if Runtime.abilityIssued[ABILITY.cookie] then
        return
    end

    -- Ethereal / Ghost / attack-immune: don't right-click — follow cursor until attackable.
    if Script.IsAttackBlocked(target) then
        if (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("attack blocked → follow (%s)", FmtUnit(target))
        end
        Script.Target.FollowCursor(now, me, true)
        return
    end

    AttackEnemy(now, me, target)
end

---@param now number
local function UpdateCombat(now)
    local me = SafeValue(Heroes.GetLocal)
    if me == nil or not IsLocalSnapfire(me) or not IsValidUnit(me) then
        if Runtime.prevComboHeld or Runtime.prevKissesHeld then
            Dbg("abort: not local live Snapfire")
        end
        ResetRuntime()
        return
    end

    if SafeValue(Input.IsInputCaptured) == true then
        Runtime.drawActive = false
        return
    end

    -- Hold mode only (physical key down). Never IsToggled.
    local kissesHeld = IsBindHeld(UI.KissesAimKey)
    local comboHeld = IsBindHeld(UI.ComboKey)

    if kissesHeld ~= Runtime.prevKissesHeld then
        Dbg("KissesAimKey hold=%s", tostring(kissesHeld))
        Runtime.prevKissesHeld = kissesHeld
        if kissesHeld then
            Runtime.lastAimPos = nil
        else
            Runtime.kissesTarget = nil
        end
    end

    if comboHeld ~= Runtime.prevComboHeld then
        Dbg("ComboKey hold=%s", tostring(comboHeld))
        Runtime.prevComboHeld = comboHeld
        if comboHeld then
            ResetComboSession()
        else
            Runtime.comboTarget = nil
            Runtime.lockEntIndex = nil
            Runtime.lockWorldPos = nil
            Runtime.lockLostAt = -math.huge
        end
    end

    if not kissesHeld then
        Runtime.kissesTarget = nil
    end
    if not comboHeld then
        Runtime.comboTarget = nil
    end

    if not kissesHeld and not comboHeld then
        Runtime.drawActive = false
        Runtime.drawMe = nil
        Runtime.drawTarget = nil
        return
    end

    Runtime.drawMe = me
    Runtime.drawActive = true

    if kissesHeld then
        Runtime.kissesTarget = Script.Target.ResolveOrKeep(now, me, Runtime.kissesTarget, "kisses")
        Runtime.drawTarget = Runtime.kissesTarget
        if Runtime.kissesTarget ~= nil then
            if not ShouldSkipAbilitiesForDamageReturn(now, Runtime.kissesTarget) then
                UpdateKissesAim(now, me, Runtime.kissesTarget)
            end
        elseif Script.Target.FollowCursor(now, me) then
            return
        end
        return
    end

    if comboHeld then
        Runtime.comboTarget = Script.Target.ResolveOrKeep(now, me, Runtime.comboTarget, "combo")
        Runtime.drawTarget = Runtime.comboTarget
        if Runtime.comboTarget ~= nil then
            UpdateCombo(now, me, Runtime.comboTarget)
        else
            Script.Target.FollowCursor(now, me)
        end
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
    -- Re-show every load: built-in Snapfire can hide Main Settings again after disable.
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
    Runtime.menuShowAsserts = 0
    if Persistent.logger then
        Persistent.logger:info(
            "menu ready path=Heroes/Hero List/Snapfire/{Main Settings,Extra Settings}"
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
    end

    if not UI.Enabled or not UI.Enabled:Get() then
        Runtime.drawActive = false
        return
    end

    local now = SafeValue(GameRules.GetGameTime) or 0
    UpdateCombat(now)
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
