--[[
    Batrider — Blink + Flaming Lasso Extract
    Hold combo key: pop Linken's, blink + lasso on cursor target, drag to ally cluster.
    Drag phase uses speed/displacement/survival/invis items with strict priority.
    Script by Euphoria
--]]

local Script = {}

--#region Constants

local DEBUG_PREFIX = "[BatriderLasso] "
local HERO_NAME = "npc_dota_hero_batrider"
local LASSO_NAME = "batrider_flaming_lasso"
local FIREFLY_NAME = "batrider_firefly"
local LASSO_MODIFIER = "modifier_batrider_flaming_lasso"
local FIREFLY_MODIFIER = "modifier_batrider_firefly"
local ORDER_ID = "batrider.lasso_extract"

local DEFAULT_LASSO_RANGE = 175
local MIN_BLINK_DIST_FROM_ME = 50
local BLINK_RANGE_MARGIN = 20
local BLINK_TOWARD_ANCHOR_OFFSET = 30

local DEBUG_HOLD_INTERVAL = 0.5
local COMBO_RECOVERY_TIME = 1.0
local RECOVERY_MIN_DELAY = 0.04
local APPROACH_MOVE_INTERVAL = 0.22
local LASSO_RETRY_DELAY = 0.05
local LASSO_ORDER_SETTLE = 0.15
local LASSO_CONFIRM_WAIT = 0.40
local MAX_LASSO_RETRIES = 2
local DRAG_ITEM_INTERVAL = 0.12
local DRAG_MOVE_INTERVAL = 0.35
local AUTO_ALLY_SCAN_RADIUS = 5000
local AUTO_CLUSTER_RADIUS = 600
local AUTO_DELIVER_DISTANCE = 220
local AUTO_SELF_DELIVER_DISTANCE = 260
local AUTO_STOP_WHEN_DELIVERED = true
local LINK_BREAK_CAST_INTERVAL = 0.12
local LINK_BREAK_BLINK_SETTLE = 0.30
local COMBO_BLINK_SETTLE = 0.22
local COMBO_BLINK_LASSO_TIMEOUT = 0.55
local LINK_BREAK_BLINK_POP_MAX_WAIT = 0.65
local LINK_BREAK_POP_VERIFY = 0.45
local LINK_BREAK_MAX_WAIT = 2.5
local LINK_BREAK_CD_LOG_INTERVAL = 0.75
local LINK_BREAK_NO_ITEM_LOG_INTERVAL = 2.5
local LINK_BREAK_APPROACH_MARGIN = 25
local OVERLAY_THEME_INTERVAL = 0.5
local DRAG_FACE_MAX_ANGLE = 22
local DRAG_FACE_MAX_TURN_TIME = 0.06
local DRAG_BOOST_MIN_MOVE = 0.0
local DRAG_SURVIVAL_HP_PCT = 0.70
local DRAG_HEAL_HP_PCT = 0.62
local PREINIT_THREAT_RADIUS = 1600
local DISPLACEMENT_PENDING_CD = 0.5
local FALLBACK_ITEM_SLOT_MAX = 16
local FALLBACK_ABILITY_SLOT_MAX = 23

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local LINKENS_MODIFIER = "modifier_item_sphere_target"
-- Passive item buff on carriers; NOT an active block — do not use for pop detection.
local LINKENS_PASSIVE_MODIFIER = "modifier_item_sphere"

local HARD_BLOCK_MODIFIERS = {
    "modifier_item_lotus_orb_channel",
    "modifier_antimage_spell_shield",
}

-- ACTIVE invisibility only. While any of these is present the hero is truly
-- invisible and any order would break it, so drag boosting pauses.
-- NOTE: do NOT list the permanent passives (modifier_item_invisibility_edge /
-- modifier_item_silver_edge) — those exist whenever the item is merely owned and
-- would otherwise block every drag cast.
local INVIS_MODIFIERS = {
    "modifier_invisible",
    "modifier_item_invisibility_edge_windwalk",
    "modifier_item_silver_edge_windwalk",
    "modifier_item_glimmer_cape_fade",
}

-- Full/magic immunity: nothing to dispel while these are up, so skip Manta/Lotus.
local IMMUNITY_MODIFIERS = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
    "modifier_item_sphere_target",
}

-- Root/leash debuffs removable by a basic dispel (Manta / Lotus). Silence is
-- detected separately via NPC.IsSilenced. Hex/stun cannot be self-cleared.
local DISPELLABLE_DISABLE_MODIFIERS = {
    "modifier_rod_of_atos_debuff",
    "modifier_gungir_root",
    "modifier_ensnare",
    "modifier_naga_siren_ensnare",
    "modifier_meepo_earthbind",
    "modifier_treant_overgrowth",
    "modifier_cage_trap",
}

local LASSO_ICON = "panorama/images/spellicons/batrider_flaming_lasso_png.vtex_c"
local LINKENS_ICON = "panorama/images/items/sphere_png.vtex_c"

local LINKBREAK_WIDGET_NAME = "Linkbreaker Items"
local ITEM_USAGE_WIDGET_NAME = "Items Usage"

local LINKBREAK_DEFAULT_ENABLED = {
    "item_cyclone",
    "item_wind_waker",
    "item_dagon",
    "item_orchid",
    "item_bloodthorn",
    "item_abyssal_blade",
    "item_heavens_halberd",
    "item_rod_of_atos",
    "item_gungir",
    "item_nullifier",
    "item_revenants_brooch",
    "item_ethereal_blade",
    "item_diffusal_blade",
    "item_disperser",
    "item_spirit_vessel",
    "item_urn_of_shadows",
    "item_crippling_crossbow",
    "item_blood_grenade",
}

local ITEM_USAGE_GROUPS = {
    {
        widget = "Important Items",
        items = {
            "item_blink",
            "item_overwhelming_blink",
            "item_swift_blink",
            "item_arcane_blink",
            "item_black_king_bar",
        },
        defaultEnabled = {
            item_blink = true,
            item_overwhelming_blink = true,
            item_swift_blink = true,
            item_arcane_blink = true,
            item_black_king_bar = false,
        },
    },
    {
        widget = "Utility Items",
        items = {
            "item_phase_boots",
            "item_ancient_janggo",
            "item_boots_of_bearing",
            "item_force_staff",
            "item_hurricane_pike",
        },
        defaultEnabled = {
            item_phase_boots = true,
            item_ancient_janggo = true,
            item_boots_of_bearing = true,
            item_force_staff = true,
            item_hurricane_pike = true,
        },
    },
    {
        widget = "Invisibility Items",
        items = {
            "item_invis_sword",
            "item_silver_edge",
            "item_glimmer_cape",
        },
        defaultEnabled = {
            item_invis_sword = true,
            item_silver_edge = true,
            item_glimmer_cape = true,
        },
    },
    {
        widget = "Survival Items",
        items = {
            "item_manta",
            "item_lotus_orb",
            "item_pipe",
            "item_crimson_guard",
            "item_mekansm",
            "item_guardian_greaves",
            "item_cheese",
            "item_greater_faerie_fire",
        },
        defaultEnabled = {
            item_manta = true,
            item_lotus_orb = true,
            item_pipe = true,
            item_crimson_guard = true,
            item_mekansm = true,
            item_guardian_greaves = true,
            item_cheese = true,
            item_greater_faerie_fire = true,
        },
    },
}

-- Linken's blocks/reflects displacement actives — they do not pop the sphere.
local POP_BLOCKED_DISPLACEMENT = {
    item_force_staff = true,
    item_hurricane_pike = true,
    item_harpoon = true,
}

-- Pop costs from assets/data/items.json (offensive enemy-target pops only).
local ITEM_POP_COSTS = {
    item_crippling_crossbow = 0,
    item_blood_grenade = 50,
    item_urn_of_shadows = 825,
    item_rod_of_atos = 2250,
    item_diffusal_blade = 2500,
    item_cyclone = 2600,
    item_spirit_vessel = 2725,
    item_dagon = 3050,
    item_orchid = 3275,
    item_heavens_halberd = 3400,
    item_dagon_2 = 4200,
    item_nullifier = 4350,
    item_gungir = 4650,
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

-- Enemy-target cast range overrides (from items.json AbilityValues).
local POP_ENEMY_RANGE = {
    item_cyclone = 550,
    item_wind_waker = 550,
    item_bloodthorn = 900,
    item_orchid = 900,
}

local LINKBREAK_NEVER = {
    item_blink = true,
    item_overwhelming_blink = true,
    item_swift_blink = true,
    item_arcane_blink = true,
    item_tpscroll = true,
    item_flask = true,
    item_clarity = true,
    item_enchanted_mango = true,
    item_faerie_fire = true,
    item_bottle = true,
    item_ward_observer = true,
    item_ward_sentry = true,
    item_smoke_of_deceit = true,
    item_dust = true,
    item_tango = true,
    item_force_staff = true,
    item_hurricane_pike = true,
    item_harpoon = true,
    item_glimmer_cape = true,
    item_lotus_orb = true,
    item_solar_crest = true,
    item_guardian_greaves = true,
    item_boots_of_bearing = true,
    item_mekansm = true,
    item_pipe = true,
    item_arcane_boots = true,
    item_phase_boots = true,
    item_power_treads = true,
    item_tranquil_boots = true,
    item_boots = true,
    item_hand_of_midas = true,
    item_ring_of_basilius = true,
    item_vladmir = true,
    item_ancient_janggo = true,
    item_refresher = true,
    item_sphere = true,
    item_black_king_bar = true,
    item_aeon_disk = true,
    item_magic_wand = true,
    item_magic_stick = true,
    item_branches = true,
    item_quelling_blade = true,
    item_infused_raindrop = true,
    item_wind_lace = true,
    item_boots_of_elves = true,
    item_belt_of_strength = true,
    item_robe = true,
    item_void_stone = true,
    item_recipe = true,
}

local LINKBREAK_NAME_TO_ID = {}

for itemId in pairs(ITEM_POP_COSTS) do
    LINKBREAK_NAME_TO_ID[itemId] = itemId
end

LINKBREAK_NAME_TO_ID.item_dagon_2 = "item_dagon"
LINKBREAK_NAME_TO_ID.item_dagon_3 = "item_dagon"
LINKBREAK_NAME_TO_ID.item_dagon_4 = "item_dagon"
LINKBREAK_NAME_TO_ID.item_dagon_5 = "item_dagon"
LINKBREAK_NAME_TO_ID.item_diffusal_blade_2 = "item_diffusal_blade"

local function NormalizeLinkbreakItemName(name)
    if not name then
        return nil
    end

    return LINKBREAK_NAME_TO_ID[name] or name
end

--#endregion

--#region State

local State = {
    phase = "idle",
    sessionActive = false,
    lastDebugHoldLog = -100,
    lastApproachMove = -100,
    lastDragMove = -100,
    lastDragItemUse = {},
    comboAttempted = false,
    comboSent = false,
    comboDone = false,
    comboAttemptTime = 0,
    delivered = false,
    deliveredHoldSent = false,
    linkBreakPending = false,
    linkBreakAttemptTime = 0,
    linkBreakBlinkUsed = false,
    linkBreakFollowUpItem = nil,
    linkBreakFollowUpName = nil,
    linkBreakPopSent = false,
    comboAfterLinkBreak = false,
    initBlinkPending = false,
    initBlinkTime = 0,
    lastLassoRetry = -100,
    lassoRetryCount = 0,
    missingLinkbreaker = false,
    missingLinkbreakerLogged = false,
    lastLinkBreakCast = -100,
    lastLinkBreakNoItemLog = -100,
    lastLinkBreakCdLog = -100,
    manualOverrideUntil = -100,
    lastDragDisplacementDiag = -100,
    dragDisplacementUsed = false,
    preInitDone = {},
    dragStartTime = 0,
    comboKeyHeld = false,
    lockedTarget = nil,
    lockedTargets = nil,
    lockedAnchor = nil,
    lockedClusterMembers = nil,
    overlayAnchor = nil,
    overlayTarget = nil,
    overlayPhase = "idle",
    overlayClusterRadius = 0,
}

local OverlayTheme = {
    syncedAt = -100,
    font = 0,
    route = Color(120, 160, 255, 210),
    routeGlow = Color(120, 160, 255, 45),
    anchor = Color(50, 220, 110, 220),
    anchorGlow = Color(50, 220, 110, 40),
    target = Color(255, 120, 90, 210),
    pillBg = Color(16, 18, 24, 185),
    pillBorder = Color(255, 255, 255, 35),
    text = Color(245, 247, 250, 235),
}

--#endregion

local UI = {}

--#region Localization

local MenuNodes = {
    group = nil,
    gear = nil,
    linkGear = nil,
    itemGear = nil,
}

local LangState = {
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    callbackSet = false,
}

local I = {
    power  = "\u{f011}",
    bind   = "\u{f084}",
    hits   = "\u{f0c0}",
    ruler  = "\u{f547}",
    radius = "\u{f1ce}",
    stop   = "\u{f04d}",
    draw   = "\u{f06e}",
    bug    = "\u{f188}",
    gear   = "\u{f013}",
    items  = "\u{f00a}",
    bars   = "\u{f0c9}",
}

local Locale = {
    group_name = {
        en = "Lasso Extract",
        ru = "Lasso Extract",
        cn = "套索提取",
    },
    gear_settings = {
        en = "Settings",
        ru = "Настройки",
        cn = "设置",
    },
    ui_enabled = {
        en = "Enable",
        ru = "Включить",
        cn = "启用",
    },
    ui_combo_key = {
        en = "Combo Key",
        ru = "Бинд комбо",
        cn = "连招按键",
    },
    ui_item_usage = {
        en = "Items Usage",
        ru = "Использование предметов",
        cn = "物品使用",
    },
    ui_firefly = {
        en = "Firefly",
        ru = "Firefly",
        cn = "火焰飞行",
    },
    ui_min_allies = {
        en = "Min allies for anchor",
        ru = "Мин. союзников для якоря",
        cn = "锚点最少友军",
    },
    ui_linkbreaker_items = {
        en = "Break Linken's",
        ru = "Сбив Linken's",
        cn = "破林肯",
    },
    ui_draw_overlay = {
        en = "Draw overlay",
        ru = "Рисовать оверлей",
        cn = "绘制覆盖层",
    },
    ui_debug = {
        en = "Debug logs",
        ru = "Debug логи",
        cn = "调试日志",
    },
    tip_enabled = {
        en = "Master switch for Blink + Lasso Extract combo.",
        ru = "Главный переключатель комбо Blink + Lasso Extract.",
        cn = "闪烁+套索提取连招总开关。",
    },
    tip_combo_key = {
        en = "Hold to blink + lasso cursor target and drag to the nearest ally group. Release to stop.",
        ru = "Удерживай: blink + lasso на цель под курсором, drag к союзникам. Отпусти — стоп.",
        cn = "按住：对光标目标闪烁+套索并拖向友军群。松开即停止。",
    },
    tip_item_usage = {
        en = "Enable items the script may use. Each selected item has its own combo or drag logic.",
        ru = "Включает предметы, которые может использовать скрипт. У каждого выбранного предмета своя логика.",
        cn = "启用脚本可使用的物品。每个选中物品都有独立逻辑。",
    },
    tip_firefly = {
        en = "Use Firefly during drag for speed and pathing.",
        ru = "Использовать Firefly при drag для скорости и обхода.",
        cn = "拖拽时使用火焰飞行以提速和绕地形。",
    },
    tip_min_allies = {
        en = "Minimum allied heroes required in a cluster to use as drag anchor.",
        ru = "Минимум союзников в группе для якоря drag.",
        cn = "作为拖拽锚点所需的友军集群最少人数。",
    },
    tip_ally_scan = {
        en = "How far to search for allied heroes when picking an anchor cluster.",
        ru = "Радиус поиска союзников для выбора якоря.",
        cn = "选择锚点集群时搜索友军的半径。",
    },
    tip_cluster_radius = {
        en = "Allies within this distance of each other count as one cluster.",
        ru = "Союзники ближе этой дистанции считаются одной группой.",
        cn = "彼此在此距离内的友军计为同一集群。",
    },
    tip_deliver_dist = {
        en = "Stop dragging when the lassoed target is this close to the anchor.",
        ru = "Остановить drag, когда жертва ближе этой дистанции к якорю.",
        cn = "被套索目标距锚点此距离内时停止拖拽。",
    },
    tip_linkbreaker_items = {
        en = "Icon grid of items used to pop Linken's. Pike/Force/Harpoon cannot pop Linken's.",
        ru = "Сетка предметов для сбития Linken's. Pike/Force/Harpoon не сбивают Linken's.",
        cn = "用于破林肯的物品图标网格。Pike/Force/Harpoon无法破林肯。",
    },
    tip_stop_delivered = {
        en = "Hold position when the target reaches the ally anchor.",
        ru = "Hold position, когда цель доставлена к якорю.",
        cn = "目标到达友军锚点时按住不动。",
    },
    tip_draw_overlay = {
        en = "Draw route line, anchor circle, and current phase on screen.",
        ru = "Рисовать линию маршрута, круг якоря и текущую фазу.",
        cn = "绘制路线、锚点圆和当前阶段。",
    },
    tip_debug = {
        en = "Write combo decisions and casts to debug.log.",
        ru = "Писать решения комбо и касты в debug.log.",
        cn = "将连招决策和施法写入 debug.log。",
    },
    phase_idle = { en = "Idle", ru = "Ожидание", cn = "空闲" },
    phase_acquire = { en = "Acquire", ru = "Захват цели", cn = "锁定" },
    phase_linkbreak = { en = "Break Linken's", ru = "Сбить Linken's", cn = "破林肯" },
    phase_combo = { en = "Combo", ru = "Комбо", cn = "连招" },
    phase_drag = { en = "Drag", ru = "Drag", cn = "拖拽" },
}

local function GetLanguageWidget()
    local now = os.clock()
    if LangState.languageWidget and now < LangState.languageLookupAt then
        return LangState.languageWidget
    end

    LangState.languageLookupAt = now + 1.0
    LangState.languageWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    return LangState.languageWidget
end

local function GetLanguageCode()
    local widget = GetLanguageWidget()
    local value = widget and widget.Get and widget:Get() or "en"

    if type(value) == "number" then
        if value == 1 then
            return "ru"
        end
        if value == 2 then
            return "cn"
        end
        return "en"
    end

    value = tostring(value or "en"):lower()
    if value == "ru" or value:find("рус", 1, true) or value:find("russian", 1, true) then
        return "ru"
    end
    if value == "cn"
        or value == "zh"
        or value:find("chinese", 1, true)
        or value:find("中文", 1, true)
        or value:find("中国", 1, true)
        or value:find("简体", 1, true) then
        return "cn"
    end
    return "en"
end

local function L(key)
    local lang = GetLanguageCode()
    local entry = Locale[key]
    if not entry then
        return tostring(key)
    end
    return entry[lang] or entry.en or tostring(key)
end

local function MenuImage(widget, imagePath)
    if widget and widget.Image then
        widget:Image(imagePath)
    end
end

local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        widget:Icon(icon)
    end
end

local function MenuTip(widget, key)
    if widget and widget.ToolTip then
        widget:ToolTip(L(key))
    end
end

local function MenuLabel(widget, key)
    if widget and widget.ForceLocalization then
        widget:ForceLocalization(L(key))
    end
end

local function ApplyLocalization(force)
    local lang = GetLanguageCode()
    if not force and LangState.lastLanguage == lang then
        return
    end
    LangState.lastLanguage = lang

    MenuLabel(MenuNodes.group, "group_name")
    MenuLabel(MenuNodes.gear, "gear_settings")

    MenuLabel(UI.Enabled, "ui_enabled")
    MenuTip(UI.Enabled, "tip_enabled")

    MenuLabel(UI.ComboKey, "ui_combo_key")
    MenuTip(UI.ComboKey, "tip_combo_key")

    MenuLabel(UI.MinAllies, "ui_min_allies")
    MenuTip(UI.MinAllies, "tip_min_allies")

    MenuLabel(UI.ItemUsageRow, "ui_item_usage")
    MenuTip(UI.ItemUsageRow, "tip_item_usage")

    MenuLabel(UI.UseFirefly, "ui_firefly")
    MenuTip(UI.UseFirefly, "tip_firefly")

    MenuLabel(UI.LinkbreakerItems, "ui_linkbreaker_items")
    MenuTip(UI.LinkbreakerItems, "tip_linkbreaker_items")

    MenuLabel(UI.DrawOverlay, "ui_draw_overlay")
    MenuTip(UI.DrawOverlay, "tip_draw_overlay")

    MenuLabel(UI.Debug, "ui_debug")
    MenuTip(UI.Debug, "tip_debug")
end

local function SetupLanguageCallback()
    if LangState.callbackSet then
        return
    end

    local widget = GetLanguageWidget()
    if not widget or not widget.SetCallback then
        return
    end

    LangState.callbackSet = true
    local previous = widget:Get()
    widget:SetCallback(function(ctrl)
        local current = (ctrl or widget):Get()
        if current == previous then
            return
        end
        previous = current
        LangState.lastLanguage = nil
        ApplyLocalization(true)
    end)
end

--#endregion

--#region Menu

local BUILTIN_LINKBREAKER_PATH = {
    "Heroes", "Hero List", "Batrider",
    "Main Settings", "Items Settings", "Linkbreaker Items",
}

local function GetBuiltinLinkbreakerWidget()
    return Menu.Find(
        BUILTIN_LINKBREAKER_PATH[1],
        BUILTIN_LINKBREAKER_PATH[2],
        BUILTIN_LINKBREAKER_PATH[3],
        BUILTIN_LINKBREAKER_PATH[4],
        BUILTIN_LINKBREAKER_PATH[5],
        BUILTIN_LINKBREAKER_PATH[6]
    )
end

local function GetLinkbreakerWidget()
    if UI and UI.LinkbreakerItems and UI.LinkbreakerItems.Get then
        return UI.LinkbreakerItems
    end

    return GetBuiltinLinkbreakerWidget()
end

local function BuildLinkbreakDefaultSet()
    local set = {}

    for _, itemId in ipairs(LINKBREAK_DEFAULT_ENABLED) do
        if not POP_BLOCKED_DISPLACEMENT[itemId] and not LINKBREAK_NEVER[itemId] then
            set[itemId] = true
        end
    end

    return set
end

local function GetPanoramaIconPath(name)
    if not name or name == "" then
        return "panorama/images/items/recipe_png.vtex_c"
    end

    if name:find("^item_", 1) then
        if name:find("recipe", 1, true) then
            return "panorama/images/items/recipe_png.vtex_c"
        end

        return "panorama/images/items/" .. name:gsub("^item_", "") .. "_png.vtex_c"
    end

    return "panorama/images/spellicons/" .. name .. "_png.vtex_c"
end

local function GetCatalogIconPath(name)
    ---@diagnostic disable-next-line: undefined-global
    local libRender = LIB_RENDER

    if libRender and libRender.get_ability_icon_path then
        local ok, path = pcall(libRender.get_ability_icon_path, name)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end

    if libRender and libRender.get_item_icon_path then
        local ok, path = pcall(libRender.get_item_icon_path, name)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end

    return GetPanoramaIconPath(name)
end

local function BuildLinkbreakAllowlist()
    local ordered = {}
    local seen = {}

    local function Add(nameId)
        if type(nameId) ~= "string" or nameId == "" or seen[nameId] then
            return
        end
        if POP_BLOCKED_DISPLACEMENT[nameId] then
            return
        end

        seen[nameId] = true
        ordered[#ordered + 1] = nameId
    end

    local builtin = GetBuiltinLinkbreakerWidget()
    if builtin and builtin.List then
        for _, nameId in ipairs(builtin:List() or {}) do
            Add(nameId)
        end
    end

    if #ordered == 0 then
        for _, nameId in ipairs(LINKBREAK_DEFAULT_ENABLED) do
            Add(nameId)
        end
        Add("item_sheepstick")
        Add("item_gungir")
    end

    Add(LASSO_NAME)

    return ordered
end

local function BuildLinkbreakMultiSelectEntry(nameId, enabledSet)
    return {
        nameId,
        GetCatalogIconPath(nameId),
        enabledSet[nameId] == true,
    }
end

local function BuildLinkbreakMultiSelectItems()
    local allowlist = BuildLinkbreakAllowlist()
    local enabledSet = {}
    local builtin = GetBuiltinLinkbreakerWidget()

    if builtin and builtin.Get then
        for _, nameId in ipairs(allowlist) do
            if builtin:Get(nameId) then
                enabledSet[nameId] = true
            end
        end
    else
        local defaultSet = BuildLinkbreakDefaultSet()
        for _, nameId in ipairs(allowlist) do
            if defaultSet[nameId] then
                enabledSet[nameId] = true
            end
        end
    end

    local catalog = allowlist

    for i, nameId in ipairs(catalog) do
        if nameId == LASSO_NAME then
            table.remove(catalog, i)
            catalog[#catalog + 1] = LASSO_NAME
            break
        end
    end

    if table.Map then
        return table.Map(catalog, function(nameId)
            return BuildLinkbreakMultiSelectEntry(nameId, enabledSet)
        end)
    end

    local items = {}
    for _, nameId in ipairs(catalog) do
        items[#items + 1] = BuildLinkbreakMultiSelectEntry(nameId, enabledSet)
    end

    return items
end

local function BuildUsageMultiSelectItems(names, defaultEnabled)
    local items = {}

    for _, nameId in ipairs(names) do
        items[#items + 1] = {
            nameId,
            GetCatalogIconPath(nameId),
            defaultEnabled[nameId] == true,
        }
    end

    return items
end

local function GetDefaultItemUsage(itemId)
    for _, group in ipairs(ITEM_USAGE_GROUPS) do
        if group.defaultEnabled[itemId] ~= nil then
            return group.defaultEnabled[itemId] == true
        end
    end

    return true
end

local function IsItemUsageEnabled(itemId)
    if not itemId then
        return false
    end

    for _, itemGroup in ipairs(ITEM_USAGE_GROUPS) do
        local groupContainsItem = false
        for _, groupItemId in ipairs(itemGroup.items) do
            if groupItemId == itemId then
                groupContainsItem = true
                break
            end
        end

        if groupContainsItem then
            local widget = UI
                and UI.ItemUsageWidgets
                and UI.ItemUsageWidgets[itemGroup.widget]

            if widget and widget.Get then
                local ok, enabled = pcall(widget.Get, widget, itemId)
                if ok and enabled ~= nil then
                    return enabled == true
                end
            end

            return itemGroup.defaultEnabled[itemId] == true
        end
    end

    return GetDefaultItemUsage(itemId)
end

local function IsAbilityUsageEnabled(abilityName)
    if abilityName == LASSO_NAME then
        return true
    end

    if abilityName == FIREFLY_NAME then
        return UI.UseFirefly == nil or UI.UseFirefly:Get()
    end

    return false
end

local function RefreshLinkbreakerMultiSelect(saveToConfig)
    local widget = UI.LinkbreakerItems
    if not widget or not widget.Update then
        return false
    end

    local items = BuildLinkbreakMultiSelectItems()
    if #items == 0 then
        return false
    end

    widget:Update(items, false, saveToConfig == true)
    return #(widget:List() or {}) > 0
end

local function InitializeUI()
    ---@type CMenuGroup|nil
    local group = nil

    local mainSection = Menu.Find("Heroes", "Hero List", "Batrider", "Main Settings")
    if mainSection and mainSection.Create then
        group = mainSection:Create("Lasso Extract")
    end

    if not group then
        group = Menu.Create("Scripts", "Combat", "Batrider Lasso Extract", "Main", "Lasso Extract")
    end

    if not group then
        error(DEBUG_PREFIX .. "Failed to create menu group")
    end

    MenuNodes.group = group

    local ui = {}
    ui.Enabled = group:Switch("Enable", false)
    MenuIcon(ui.Enabled, I.power)

    ui.ComboKey = group:Bind("Combo Key", Enum.ButtonCode.KEY_NONE)
    MenuImage(ui.ComboKey, LASSO_ICON)
    if ui.ComboKey.Properties then
        ui.ComboKey:Properties("Combo Key", "hold", false)
    end
    if ui.ComboKey.SetToggled then
        ui.ComboKey:SetToggled(false)
    end
    if ui.ComboKey.SetKeyCallback then
        ui.ComboKey:SetKeyCallback(function(ctrl, _key, event)
            if event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
                State.comboKeyHeld = true
                if ctrl.SetToggled then
                    ctrl:SetToggled(false)
                end
            elseif event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
                State.comboKeyHeld = false
                if ctrl.SetToggled then
                    ctrl:SetToggled(false)
                end
            end
        end)
    end

    ui.ItemUsageRow = group:Label(ITEM_USAGE_WIDGET_NAME, I.items)
    MenuTip(ui.ItemUsageRow, "tip_item_usage")

    local itemGear = ui.ItemUsageRow:Gear(ITEM_USAGE_WIDGET_NAME, I.bars, true)
    MenuNodes.itemGear = itemGear

    ui.ItemUsageWidgets = {}
    for _, itemGroup in ipairs(ITEM_USAGE_GROUPS) do
        ui.ItemUsageWidgets[itemGroup.widget] = itemGear:MultiSelect(
            itemGroup.widget,
            BuildUsageMultiSelectItems(itemGroup.items, itemGroup.defaultEnabled),
            false
        )
    end

    ui.UseFirefly = group:Switch("Firefly", true)
    MenuImage(ui.UseFirefly, GetCatalogIconPath(FIREFLY_NAME))
    MenuTip(ui.UseFirefly, "tip_firefly")

    ui.LinkbreakerItems = group:MultiSelect(
        LINKBREAK_WIDGET_NAME,
        BuildLinkbreakMultiSelectItems(),
        false
    )
    MenuImage(ui.LinkbreakerItems, LINKENS_ICON)
    MenuTip(ui.LinkbreakerItems, "tip_linkbreaker_items")

    local gear = ui.Enabled:Gear("Settings", I.gear, true)
    MenuNodes.gear = gear

    ui.MinAllies = gear:Slider("Min allies for anchor", 1, 5, 2, "%d")
    MenuIcon(ui.MinAllies, I.hits)

    ui.DrawOverlay = gear:Switch("Draw overlay", true)
    MenuIcon(ui.DrawOverlay, I.draw)

    ui.Debug = gear:Switch("Debug logs", false)
    MenuIcon(ui.Debug, I.bug)

    local gearWidgets = {
        ui.MinAllies,
        ui.DrawOverlay,
        ui.Debug,
    }

    local function UpdateControls()
        local enabled = ui.Enabled:Get()
        ui.ComboKey:Disabled(not enabled)
        ui.LinkbreakerItems:Disabled(not enabled)
        ui.ItemUsageRow:Disabled(not enabled)
        ui.UseFirefly:Disabled(not enabled)
        for _, widget in pairs(ui.ItemUsageWidgets) do
            widget:Disabled(not enabled)
        end
        for _, widget in ipairs(gearWidgets) do
            widget:Disabled(not enabled)
        end
    end

    ui.Enabled:SetCallback(UpdateControls, true)

    ApplyLocalization(true)
    SetupLanguageCallback()
    return ui
end

--#endregion

--#region Debug

local function Dbg(message, ...)
    if not UI.Debug:Get() then
        return
    end

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    if Log and Log.Write then
        Log.Write(DEBUG_PREFIX .. message)
    end
end

local function GetAbilityName(ability)
    if not ability then
        return "nil"
    end
    return Ability.GetName(ability) or Ability.GetBaseName(ability) or "unknown"
end

UI = InitializeUI()
Dbg("script loaded")

--#endregion

--#region Helpers

local function IsValidHero(unit)
    return unit
        and Entity.IsAlive(unit)
        and not Entity.IsDormant(unit)
        and not NPC.IsIllusion(unit)
end

local function HasHardBlock(unit)
    if not IsValidHero(unit) then
        return false
    end

    for _, modifierName in ipairs(HARD_BLOCK_MODIFIERS) do
        if NPC.HasModifier(unit, modifierName) then
            return true
        end
    end

    return false
end

local function HasLinkens(unit)
    if not IsValidHero(unit) then
        return false
    end

    if NPC.HasModifier(unit, LINKENS_MODIFIER) then
        return true
    end

    if not NPC.HasModifier(unit, LINKENS_PASSIVE_MODIFIER) then
        return false
    end

    local sphere = NPC.GetItem(unit, "item_sphere", true)
    if not sphere then
        return false
    end

    if Ability.IsReady and not Ability.IsReady(sphere) then
        return false
    end

    if Ability.GetCooldown then
        local cd = Ability.GetCooldown(sphere) or 0
        if cd > 0.05 then
            return false
        end
    end

    return true
end

local function TargetNeedsLinkBreak(target)
    return HasLinkens(target)
end

local function IsComboKeyHeld()
    if State.comboKeyHeld then
        return true
    end

    local key = UI.ComboKey
    return key and key.IsDown and key:IsDown() or false
end

local function CanLassoTarget(target)
    return IsValidHero(target) and not HasHardBlock(target)
end

local function CanAct(me)
    if not IsValidHero(me) then
        return false
    end

    return not NPC.IsStunned(me)
        and not NPC.IsSilenced(me)
        and not NPC.HasState(me, Enum.ModifierState.MODIFIER_STATE_ROOTED)
end

local function GetBlink(me)
    for _, name in ipairs(BLINK_ITEMS) do
        local blink = NPC.GetItem(me, name, true)
        if blink and IsItemUsageEnabled(name) then
            return blink, name
        end
    end
    return nil, nil
end

local function GetCastRange(me, ability, fallback)
    if not ability then
        return fallback and (fallback + (NPC.GetCastRangeBonus(me) or 0)) or 0
    end
    return Ability.GetCastRange(ability) + (NPC.GetCastRangeBonus(me) or 0)
end

local function Dist2D(a, b)
    return (a - b):Length2D()
end

local function GetHoldBlockReason(me, mana, lasso, blink, targets, comboReady)
    if comboReady then
        return nil
    end

    if State.comboDone then
        return "combo-done"
    end

    if State.linkBreakPending then
        return "link-pending"
    end

    if targets and TargetNeedsLinkBreak(targets.target) then
        return "linken's"
    end

    if not targets or not lasso then
        return nil
    end

    if not Ability.IsCastable(lasso, mana) then
        return "lasso-cd"
    end

    if targets.needsBlink and not (blink and Ability.IsCastable(blink, mana)) then
        return "blink-cd"
    end

    return nil
end

local function LogHoldState(reason, me, mana, lasso, blink, blinkName, targets, comboReady)
    local now = GlobalVars.GetCurTime() or 0
    if now - State.lastDebugHoldLog < DEBUG_HOLD_INTERVAL then
        return
    end

    State.lastDebugHoldLog = now

    local rangeBonus = NPC.GetCastRangeBonus(me) or 0
    local lassoBase = lasso and Ability.GetCastRange(lasso) or 0
    local blinkBase = blink and Ability.GetCastRange(blink) or 0
    local blockReason = GetHoldBlockReason(me, mana, lasso, blink, targets, comboReady)
    if State.missingLinkbreaker and blockReason == "linken's" then
        return
    end

    local distText = ""
    if targets and targets.target then
        distText = string.format(" dist=%.0f", targets.distToEnemy or Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(targets.target)))
    end

    Dbg(
        "HOLD | %s | ready=%s%s%s | lasso=%.0f blink=%.0f (%s) | anchor=%s",
        reason,
        tostring(comboReady),
        blockReason and (" block=" .. blockReason) or "",
        distText,
        lassoBase + rangeBonus,
        blinkBase + rangeBonus,
        blinkName or "none",
        targets and targets.anchor
            and string.format("allies=%d pos=(%.0f,%.0f)", targets.anchor.count, targets.anchor.anchorPos.x, targets.anchor.anchorPos.y)
            or "none"
    )
end

local function ResetHoldState()
    State.phase = "idle"
    State.sessionActive = false
    State.comboAttempted = false
    State.comboSent = false
    State.comboDone = false
    State.comboAttemptTime = 0
    State.delivered = false
    State.deliveredHoldSent = false
    State.linkBreakPending = false
    State.linkBreakAttemptTime = 0
    State.linkBreakBlinkUsed = false
    State.linkBreakFollowUpItem = nil
    State.linkBreakFollowUpName = nil
    State.linkBreakPopSent = false
    State.comboAfterLinkBreak = false
    State.initBlinkPending = false
    State.initBlinkTime = 0
    State.lastLassoRetry = -100
    State.lassoRetryCount = 0
    State.missingLinkbreaker = false
    State.missingLinkbreakerLogged = false
    State.lastLinkBreakCast = -100
    State.lastLinkBreakCdLog = -100
    State.manualOverrideUntil = -100
    State.lastDragDisplacementDiag = -100
    State.dragDisplacementUsed = false
    State.preInitDone = {}
    State.dragStartTime = 0
    State.comboKeyHeld = false
    State.lastApproachMove = -100
    State.lastDragMove = -100
    State.lastDragItemUse = {}
    State.lockedTarget = nil
    State.lockedTargets = nil
    State.lockedAnchor = nil
    State.lockedClusterMembers = nil
    State.overlayAnchor = nil
    State.overlayTarget = nil
    State.overlayPhase = "idle"
    State.overlayClusterRadius = 0
end

local function StopComboExecution(me)
    if not State.sessionActive then
        ResetHoldState()
        return
    end

    local shouldHold = State.phase ~= "drag" and not State.comboDone and not State.delivered
    local player = shouldHold and Players.GetLocal() or nil
    if player and me then
        Player.HoldPosition(player, me, false, true, true, ORDER_ID .. ".stop")
    end
    ResetHoldState()
end

local function UpdateOverlay(phase, anchor, target)
    State.overlayPhase = phase or State.overlayPhase
    State.overlayAnchor = anchor and anchor.anchorPos or State.overlayAnchor
    State.overlayTarget = target and Entity.GetAbsOrigin(target) or State.overlayTarget
    State.overlayClusterRadius = anchor and AUTO_CLUSTER_RADIUS or State.overlayClusterRadius
end

local function OrderTag(tag, suffix)
    return ORDER_ID .. "." .. tag .. "." .. suffix
end

--#endregion

--#region AllyCluster

local function GetAllyHeroes(me, radius)
    local team = Entity.GetTeamNum(me)
    local myPos = Entity.GetAbsOrigin(me)
    local raw = Heroes.InRadius(myPos, radius, team, Enum.TeamType.TEAM_FRIEND, true, true) or {}
    local allies = {}

    for _, ally in ipairs(raw) do
        if IsValidHero(ally) and ally ~= me then
            allies[#allies + 1] = ally
        end
    end

    return allies
end

local function BuildClusterCentroid(members)
    if #members == 0 then
        return nil
    end

    local sumX, sumY, sumZ = 0, 0, 0
    for _, member in ipairs(members) do
        local pos = Entity.GetAbsOrigin(member)
        sumX = sumX + pos.x
        sumY = sumY + pos.y
        sumZ = sumZ + pos.z
    end

    return Vector(sumX / #members, sumY / #members, sumZ / #members)
end

local function FindBestAllyAnchor(me)
    local allies = GetAllyHeroes(me, AUTO_ALLY_SCAN_RADIUS)
    local clusterRadius = AUTO_CLUSTER_RADIUS
    local minAllies = UI.MinAllies:Get()
    local myPos = Entity.GetAbsOrigin(me)
    local best = nil

    for _, seed in ipairs(allies) do
        local seedPos = Entity.GetAbsOrigin(seed)
        local cluster = { seed }

        for _, other in ipairs(allies) do
            if other ~= seed then
                local otherPos = Entity.GetAbsOrigin(other)
                if Dist2D(otherPos, seedPos) <= clusterRadius then
                    cluster[#cluster + 1] = other
                end
            end
        end

        if #cluster >= minAllies then
            local centroid = BuildClusterCentroid(cluster)
            local distToMe = Dist2D(centroid, myPos)
            local candidate = {
                anchorPos = centroid,
                count = #cluster,
                members = cluster,
                distToMe = distToMe,
            }

            if not best
                or candidate.count > best.count
                or (candidate.count == best.count and candidate.distToMe < best.distToMe) then
                best = candidate
            end
        end
    end

    return best
end

--#endregion

--#region Targeting

local function GetTargetUnderCursor(me, debugReason)
    local target = Input.GetNearestHeroToCursor(
        Entity.GetTeamNum(me),
        Enum.TeamType.TEAM_ENEMY
    )

    if not target or not CanLassoTarget(target) then
        if debugReason then
            debugReason[1] = target and HasHardBlock(target)
                and "target has hard block (Lotus/AM shield)"
                or "no valid target under cursor"
        end
        return nil
    end

    return target
end

local function ResolveTarget(me, debugReason)
    if not State.lockedTarget then
        State.lockedTarget = GetTargetUnderCursor(me, nil)
    end

    local locked = State.lockedTarget
    if not locked or not CanLassoTarget(locked) then
        if debugReason then
            debugReason[1] = locked and HasHardBlock(locked)
                and "locked target hard blocked"
                or "no locked target"
        end
        return nil
    end

    return locked
end

local function GetLassoCastRange(me, lasso)
    return GetCastRange(me, lasso, DEFAULT_LASSO_RANGE)
end

local function IsLassoInRange(me, target, lasso)
    local range = GetLassoCastRange(me, lasso)
    if NPC.IsEntityInRange then
        return NPC.IsEntityInRange(me, target, range)
    end
    return Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target)) <= range
end

local function CanCastLassoNow(me, target, lasso, mana)
    return IsAbilityUsageEnabled(LASSO_NAME)
        and Ability.IsCastable(lasso, mana)
        and IsLassoInRange(me, target, lasso)
end

local function ComputeBlinkPosition(myPos, enemyPos, anchorPos, blinkRange, lassoRange)
    local distToEnemy = Dist2D(myPos, enemyPos)

    if distToEnemy <= lassoRange then
        return nil
    end

    if distToEnemy > blinkRange + lassoRange then
        return nil
    end

    local offsetX, offsetY = 0, 0
    local toAnchor = anchorPos - enemyPos
    local anchorLen = toAnchor:Length2D()
    if anchorLen > 1 then
        offsetX = toAnchor.x / anchorLen * BLINK_TOWARD_ANCHOR_OFFSET
        offsetY = toAnchor.y / anchorLen * BLINK_TOWARD_ANCHOR_OFFSET
    end

    local idealPos = Vector(
        enemyPos.x + offsetX,
        enemyPos.y + offsetY,
        enemyPos.z
    )

    local toIdeal = idealPos - myPos
    local idealDist = toIdeal:Length2D()
    if idealDist < MIN_BLINK_DIST_FROM_ME then
        return idealPos
    end

    local blinkDist = math.min(blinkRange - BLINK_RANGE_MARGIN, idealDist)
    blinkDist = math.max(blinkDist, MIN_BLINK_DIST_FROM_ME)

    if idealDist > 0.001 then
        return Vector(
            myPos.x + toIdeal.x / idealDist * blinkDist,
            myPos.y + toIdeal.y / idealDist * blinkDist,
            myPos.z
        )
    end

    return idealPos
end

local function ResolveComboTargets(me, lasso, blink, debugReason)
    local myPos = Entity.GetAbsOrigin(me)
    local lassoRange = GetLassoCastRange(me, lasso)
    local blinkRange = blink and GetCastRange(me, blink, nil) or 0

    local target = ResolveTarget(me, debugReason)
    if not target then
        return nil
    end

    local anchor = FindBestAllyAnchor(me)
    if not anchor then
        debugReason[1] = string.format("no ally anchor (min=%d)", UI.MinAllies:Get())
        return nil
    end

    local enemyPos = Entity.GetAbsOrigin(target)
    local distToEnemy = Dist2D(myPos, enemyPos)
    local blinkPos = nil
    local needsBlink = distToEnemy > lassoRange

    if needsBlink then
        if not blink then
            debugReason[1] = "need blink but none equipped"
            return nil
        end

        blinkPos = ComputeBlinkPosition(myPos, enemyPos, anchor.anchorPos, blinkRange, lassoRange)
        if not blinkPos then
            debugReason[1] = string.format("target too far (%.0f > %.0f)", distToEnemy, blinkRange + lassoRange)
            return nil
        end
    end

    debugReason[1] = "ok"
    return {
        target = target,
        anchor = anchor,
        blinkPos = blinkPos,
        needsBlink = needsBlink,
        distToEnemy = distToEnemy,
    }
end

local function IsComboReady(me, mana, lasso, blink, targets)
    if not targets
        or not CanAct(me)
        or not IsAbilityUsageEnabled(LASSO_NAME)
        or not Ability.IsCastable(lasso, mana) then
        return false
    end

    if State.linkBreakPending or TargetNeedsLinkBreak(targets.target) then
        return false
    end

    if CanCastLassoNow(me, targets.target, lasso, mana) then
        return true
    end

    if targets.needsBlink then
        if State.linkBreakBlinkUsed then
            return false
        end
        return blink ~= nil and Ability.IsCastable(blink, mana)
    end

    return true
end

local function NeedsApproach(me, target, lasso, blink)
    local mana = NPC.GetMana(me)
    if lasso and CanCastLassoNow(me, target, lasso, mana) then
        return false
    end

    local lassoRange = GetLassoCastRange(me, lasso)
    local dist = Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target))
    if dist <= lassoRange then
        return false
    end

    local blinkRange = blink and GetCastRange(me, blink, nil) or 0
    if blink and Ability.IsCastable(blink, mana)
        and dist <= lassoRange + blinkRange - LINK_BREAK_APPROACH_MARGIN then
        return false
    end

    return true
end

local function TryApproachTarget(me, target, lasso, blink, now, force)
    if not CanAct(me) then
        return false
    end

    if now < State.manualOverrideUntil then
        return true
    end

    local mana = NPC.GetMana(me)

    if not force and lasso and CanCastLassoNow(me, target, lasso, mana) then
        return false
    end

    if not force and not NeedsApproach(me, target, lasso, blink) then
        return false
    end

    if now - State.lastApproachMove < APPROACH_MOVE_INTERVAL then
        return true
    end

    State.lastApproachMove = now
    NPC.MoveTo(me, Entity.GetAbsOrigin(target), false, false, false, false, ORDER_ID .. ".approach", false)
    Dbg("approach | dist=%.0f", Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target)))
    return true
end

local function FindLassoVictim(me)
    if State.lockedTarget
        and IsValidHero(State.lockedTarget)
        and NPC.HasModifier(State.lockedTarget, LASSO_MODIFIER) then
        return State.lockedTarget
    end

    local team = Entity.GetTeamNum(me)
    local myPos = Entity.GetAbsOrigin(me)
    local raw = Heroes.InRadius(myPos, 2500, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}

    for _, enemy in ipairs(raw) do
        if IsValidHero(enemy) and NPC.HasModifier(enemy, LASSO_MODIFIER) then
            local mod = NPC.GetModifier(enemy, LASSO_MODIFIER)
            if mod and Modifier.GetCaster and Modifier.GetCaster(mod) == me then
                return enemy
            end
            return enemy
        end
    end

    local channel = NPC.GetChannellingAbility(me)
    if channel and GetAbilityName(channel) == LASSO_NAME and State.lockedTarget then
        return State.lockedTarget
    end

    return nil
end

local function IsLassoChanneling(me)
    local channel = NPC.GetChannellingAbility(me)
    return channel and GetAbilityName(channel) == LASSO_NAME
end

--- True while a lasso order is likely in flight (cast point, channel, hook modifier).
local function IsLassoOrderActive(me, lasso)
    if FindLassoVictim(me) or IsLassoChanneling(me) then
        return true
    end

    if lasso then
        if Ability.IsInAbilityPhase and Ability.IsInAbilityPhase(lasso) then
            return true
        end
        if Ability.IsChannelling and Ability.IsChannelling(lasso) then
            return true
        end
    end

    return false
end

--#endregion

--#region LinkBreak

local function IsLinkbreakItemEnabledInUI(itemId)
    local widget = GetLinkbreakerWidget()
    if not widget or not widget.Get then
        return true
    end

    local canonical = NormalizeLinkbreakItemName(itemId) or itemId
    local defaultSet = BuildLinkbreakDefaultSet()

    local function IsEnabled(id)
        if not id then
            return false
        end

        local ok, enabled = pcall(widget.Get, widget, id)
        return ok and enabled == true
    end

    if IsEnabled(itemId) or IsEnabled(canonical) then
        return true
    end

    if widget.ListEnabled then
        local ok, list = pcall(widget.ListEnabled, widget)
        if ok and type(list) == "table" then
            for _, id in ipairs(list) do
                if id == itemId or id == canonical then
                    return true
                end
            end

            if #list == 0 then
                return defaultSet[itemId] == true or defaultSet[canonical] == true
            end
        end
    end

    return false
end

local function GetPopCastRange(me, ability, itemName)
    if not ability then
        return 0
    end

    local override = itemName and POP_ENEMY_RANGE[itemName]
    if override then
        return override + (NPC.GetCastRangeBonus(me) or 0)
    end

    return GetCastRange(me, ability, 400)
end

local function IsBreakCastable(me, target, ability, mana, itemName)
    if not ability or not Ability.IsCastable(ability, mana) then
        return false
    end

    local range = GetPopCastRange(me, ability, itemName)
    if range <= 0 then
        return true
    end

    if NPC.IsEntityInRange then
        return NPC.IsEntityInRange(me, target, range)
    end

    return Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target)) <= range
end

local function SafeItemName(item)
    if not item then
        return nil
    end

    return Ability.GetName(item) or (Ability.GetBaseName and Ability.GetBaseName(item))
end

local function HasAbilityBehaviorFlag(behavior, flag)
    if type(behavior) ~= "number" or type(flag) ~= "number" then
        return false
    end

    return (behavior & flag) ~= 0
end

local function GetHeroAbilitySlotMax(me)
    ---@diagnostic disable-next-line: undefined-global
    local xhelpers = type(XHelpers) == "table" and XHelpers or nil
    if xhelpers and xhelpers.xkv and xhelpers.xkv.GetHeroAbilityCount and me then
        local heroName = NPC.GetUnitName(me)
        if heroName then
            local ok, count = pcall(xhelpers.xkv.GetHeroAbilityCount, xhelpers.xkv, heroName)
            if ok and type(count) == "number" and count >= 0 then
                return count
            end
        end
    end

    return FALLBACK_ABILITY_SLOT_MAX
end

local function IsLocalHero(unit)
    if not unit or not Heroes or not Heroes.GetLocal then
        return false
    end

    local localHero = Heroes.GetLocal()
    return localHero ~= nil and localHero == unit
end

local function TryFindLocalHeroAbilityByName(me, itemId)
    if not IsLocalHero(me) then
        return nil, nil
    end

    ---@diagnostic disable-next-line: undefined-global
    local xhelpers = type(XHelpers) == "table" and XHelpers or nil
    local xhero = xhelpers and xhelpers.XHero or nil
    if not xhero or not xhero.GetLocalHeroAbilitiesByName then
        return nil, nil
    end

    local lookupNames = { itemId }
    if itemId == "item_dagon" then
        lookupNames = { "item_dagon", "item_dagon_2", "item_dagon_3", "item_dagon_4", "item_dagon_5" }
    elseif itemId == "item_orchid" then
        lookupNames = { "item_orchid", "item_bloodthorn" }
    elseif itemId == "item_diffusal_blade" then
        lookupNames = { "item_diffusal_blade", "item_diffusal_blade_2" }
    end

    local ok, abilities = pcall(xhero.GetLocalHeroAbilitiesByName, xhero, table.unpack(lookupNames))
    if not ok or type(abilities) ~= "table" then
        return nil, nil
    end

    if itemId == "item_dagon" then
        for level = 5, 1, -1 do
            local name = level == 1 and "item_dagon" or ("item_dagon_" .. level)
            local ability = abilities[name]
            if ability then
                return ability, name
            end
        end
        return nil, nil
    end

    for _, name in ipairs(lookupNames) do
        local ability = abilities[name]
        if ability then
            return ability, SafeItemName(ability) or name
        end
    end

    return nil, nil
end

local function CollectHeroItems(me)
    local list = {}
    local seen = {}

    local function AddItem(item)
        if not item or seen[item] then
            return
        end

        seen[item] = true
        local name = SafeItemName(item)
        if name and name:find("^item_", 1) then
            list[#list + 1] = { item = item, name = name }
        end
    end

    for i = 0, FALLBACK_ITEM_SLOT_MAX do
        AddItem(NPC.GetItemByIndex(me, i))
    end

    local abilityMax = GetHeroAbilitySlotMax(me)
    for i = 0, abilityMax do
        AddItem(NPC.GetAbilityByIndex(me, i))
    end

    return list
end

local function GetTargetTeamFlag(name)
    if Enum and Enum.TargetTeam and Enum.TargetTeam[name] then
        return Enum.TargetTeam[name]
    end

    local fallback = {
        DOTA_UNIT_TARGET_TEAM_FRIENDLY = 1,
        DOTA_UNIT_TARGET_TEAM_ENEMY = 2,
        DOTA_UNIT_TARGET_TEAM_BOTH = 3,
        DOTA_UNIT_TARGET_TEAM_CUSTOM = 4,
    }
    return fallback[name]
end

local function CanPopLinkensOnEnemy(item, name)
    if not item or not name then
        return false
    end

    local canonical = NormalizeLinkbreakItemName(name)
    if POP_BLOCKED_DISPLACEMENT[name] or POP_BLOCKED_DISPLACEMENT[canonical] then
        return false
    end

    if LINKBREAK_NEVER[name] or LINKBREAK_NEVER[canonical] then
        return false
    end

    if not IsLinkbreakItemEnabledInUI(name) and not IsLinkbreakItemEnabledInUI(canonical) then
        return false
    end

    if Ability.IsPassive and Ability.IsPassive(item, true) then
        return false
    end

    local catalogCost = ITEM_POP_COSTS[name] or ITEM_POP_COSTS[canonical]
    local team = nil

    if Ability.GetTargetTeam then
        local ok, value = pcall(Ability.GetTargetTeam, item, true)
        if ok and type(value) == "number" then
            team = value
        end
    end

    if type(team) == "number" then
        local friendly = GetTargetTeamFlag("DOTA_UNIT_TARGET_TEAM_FRIENDLY") or 1
        local enemy = GetTargetTeamFlag("DOTA_UNIT_TARGET_TEAM_ENEMY") or 2
        local both = GetTargetTeamFlag("DOTA_UNIT_TARGET_TEAM_BOTH") or 3

        if team == friendly then
            return false
        end

        if team == enemy or team == both or (team & enemy) ~= 0 then
            -- Lotus/glimmer are friendly-only; force/pike are BOTH|CUSTOM.
        elseif catalogCost == nil then
            return false
        end
    elseif catalogCost == nil then
        return false
    end

    if Ability.GetBehavior then
        local behavior = Ability.GetBehavior(item, true) or Ability.GetBehavior(item, false) or 0
        if type(behavior) == "number" then
            local unitTarget = Enum.AbilityBehavior and Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET or 8
            local point = Enum.AbilityBehavior and Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT or 16

            if HasAbilityBehaviorFlag(behavior, unitTarget) then
                return true
            end

            if catalogCost and HasAbilityBehaviorFlag(behavior, point) then
                return true
            end

            return false
        end
    end

    return catalogCost ~= nil
end

local function GetItemCostValue(item, name)
    if item and Item and Item.GetCost then
        local ok, cost = pcall(Item.GetCost, item)
        if ok and type(cost) == "number" and cost > 0 then
            return cost
        end
    end

    local canonical = NormalizeLinkbreakItemName(name)
    return ITEM_POP_COSTS[name] or ITEM_POP_COSTS[canonical] or 99999
end

local function CollectAvailableLinkbreakers(me, mana, target, requireInRange)
    local candidates = {}

    for _, entry in ipairs(CollectHeroItems(me)) do
        local name = entry.name
        local canonical = NormalizeLinkbreakItemName(name)

        if CanPopLinkensOnEnemy(entry.item, name) then
            if Ability.IsCastable(entry.item, mana) then
                local inRange = not target or IsBreakCastable(me, target, entry.item, mana, name)
                if not requireInRange or inRange then
                    candidates[#candidates + 1] = {
                        item = entry.item,
                        name = name,
                        canonical = canonical,
                        cost = GetItemCostValue(entry.item, name),
                        range = GetPopCastRange(me, entry.item, name),
                    }
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.cost ~= b.cost then
            return a.cost < b.cost
        end
        return a.range < b.range
    end)

    return candidates
end

local function ItemMatchesId(item, itemId)
    if not item then
        return false
    end

    local name = SafeItemName(item)
    if name == itemId then
        return true
    end

    if Ability.GetBaseName then
        local base = Ability.GetBaseName(item)
        if base == itemId then
            return true
        end
    end

    if NormalizeLinkbreakItemName(name) == itemId then
        return true
    end

    if itemId == "item_dagon" and name and name:find("item_dagon", 1, true) == 1 then
        return true
    end

    if itemId == "item_diffusal_blade" and name then
        return name == "item_diffusal_blade" or name == "item_diffusal_blade_2"
    end

    return false
end

local function FindHeroItemByName(me, itemId)
    local cached, cachedName = TryFindLocalHeroAbilityByName(me, itemId)
    if cached then
        return cached, cachedName
    end

    if itemId == "item_dagon" then
        for level = 5, 1, -1 do
            local name = level == 1 and "item_dagon" or ("item_dagon_" .. level)
            local item = NPC.GetItem(me, name, true)
            if item then
                return item, name
            end
        end
    end

    if itemId == "item_orchid" then
        local bloodthorn, bloodName = FindHeroItemByName(me, "item_bloodthorn")
        if bloodthorn then
            return bloodthorn, bloodName
        end
    end

    for _, entry in ipairs(CollectHeroItems(me)) do
        if ItemMatchesId(entry.item, itemId) then
            return entry.item, entry.name
        end
    end

    local item = NPC.GetItem(me, itemId, true)
    if item then
        return item, itemId
    end

    item = NPC.GetItem(me, itemId, false)
    if item then
        return item, SafeItemName(item) or itemId
    end

    if NPC.GetAbility then
        item = NPC.GetAbility(me, itemId)
        if item then
            return item, itemId
        end
    end

    return nil, nil
end

local function ResolveLinkbreakItem(me, itemId)
    return FindHeroItemByName(me, itemId)
end

local function CountOwnedLinkbreakers(me)
    local count = 0

    for _, entry in ipairs(CollectHeroItems(me)) do
        if CanPopLinkensOnEnemy(entry.item, entry.name) then
            count = count + 1
        end
    end

    return count
end

local function CollectInventoryDebugNames(me)
    local names = {}

    for _, entry in ipairs(CollectHeroItems(me)) do
        names[#names + 1] = entry.name
    end

    return names
end

local function FindOwnedLinkbreaker(me, mana)
    local candidates = CollectAvailableLinkbreakers(me, mana, nil, false)
    if #candidates == 0 then
        return nil, nil, 0
    end

    local best = candidates[1]
    return best.item, best.name, best.range
end

local function FindBestLinkbreaker(me, target, mana)
    local candidates = CollectAvailableLinkbreakers(me, mana, target, true)
    if #candidates == 0 then
        return nil, nil
    end

    return candidates[1].item, candidates[1].name
end

local function GetMaxLinkbreakRange(me)
    local bestRange = 0

    for _, entry in ipairs(CollectHeroItems(me)) do
        if CanPopLinkensOnEnemy(entry.item, entry.name) then
            local range = GetPopCastRange(me, entry.item, entry.name)
            if range > bestRange then
                bestRange = range
            end
        end
    end

    return bestRange
end

local function ComputeLinkbreakBlinkPosition(myPos, enemyPos, blinkRange, breakRange)
    local dist = Dist2D(myPos, enemyPos)
    local standoff = math.max(breakRange - LINK_BREAK_APPROACH_MARGIN, 50)

    if dist <= standoff then
        return nil
    end

    if dist > blinkRange + standoff + BLINK_RANGE_MARGIN then
        return nil
    end

    local toEnemy = enemyPos - myPos
    local len = toEnemy:Length2D()
    if len < 0.001 then
        return nil
    end

    local blinkDist = dist - standoff
    local maxBlink = blinkRange - BLINK_RANGE_MARGIN
    if blinkDist > maxBlink then
        blinkDist = maxBlink
    end

    if blinkDist < MIN_BLINK_DIST_FROM_ME then
        return nil
    end

    return Vector(
        myPos.x + toEnemy.x / len * blinkDist,
        myPos.y + toEnemy.y / len * blinkDist,
        myPos.z
    )
end

local function CastPreInitiationItem(me, mana, itemName, castSelf, logName)
    if not IsItemUsageEnabled(itemName) then
        return false
    end

    local item = NPC.GetItem(me, itemName, true)
    if not item or not Ability.IsCastable(item, mana) then
        return false
    end

    if castSelf then
        Ability.CastTarget(item, me, false, true, true, OrderTag("preinit", itemName))
    else
        Ability.CastNoTarget(item, false, true, true, OrderTag("preinit", itemName))
    end

    Dbg("CAST %s | before initiation", logName or itemName)
    return true
end

local function HasEnemyThreatNear(me, radius)
    local myPos = Entity.GetAbsOrigin(me)
    if not myPos then
        return false
    end

    local team = Entity.GetTeamNum(me)
    local enemies = Heroes.InRadius(myPos, radius, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    for _, enemy in ipairs(enemies) do
        if IsValidHero(enemy) then
            return true
        end
    end

    return false
end

local function PreInitOnce(me, mana, itemName, castSelf, logName)
    if State.preInitDone[itemName] then
        return
    end
    if CastPreInitiationItem(me, mana, itemName, castSelf, logName) then
        State.preInitDone[itemName] = true
    end
end

local function CastPreInitiationDefensives(me, mana)
    -- Cast before blink/initiation so we are not stunned/hexed mid-jump.
    -- Each item fires at most once per hold session (no re-attempt spam).

    -- BKB is a deliberate manual toggle: when enabled, pop it unconditionally.
    PreInitOnce(me, mana, "item_black_king_bar", false, "bkb")

    -- Barrier / dispel defensives are only worth spending when a real enemy hero
    -- is close to the jump — otherwise we would waste them on a safe extraction.
    if HasEnemyThreatNear(me, PREINIT_THREAT_RADIUS) then
        PreInitOnce(me, mana, "item_lotus_orb", true, "lotus orb on self")
        PreInitOnce(me, mana, "item_pipe", false, "pipe")
        PreInitOnce(me, mana, "item_crimson_guard", false, "crimson guard")
    end
end

local function CastBlinkLinkBreak(me, target, blink, breaker, breakerName, mana, targets, lasso)
    if State.linkBreakBlinkUsed then
        return false
    end

    if not blink or not Ability.IsCastable(blink, mana) or not breaker then
        return false
    end

    if not Ability.IsCastable(breaker, mana) then
        return false
    end

    local myPos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(target)
    local breakRange = GetPopCastRange(me, breaker, breakerName)
    local blinkRange = GetCastRange(me, blink, nil)
    local blinkPos = nil

    if targets and targets.anchor and lasso then
        local lassoRange = GetLassoCastRange(me, lasso)
        blinkPos = ComputeBlinkPosition(myPos, enemyPos, targets.anchor.anchorPos, blinkRange, lassoRange)
    end

    if not blinkPos then
        blinkPos = ComputeLinkbreakBlinkPosition(myPos, enemyPos, blinkRange, breakRange)
    end

    if not blinkPos then
        return false
    end

    local dist = Dist2D(myPos, enemyPos)
    local now = GlobalVars.GetCurTime() or 0
    CastPreInitiationDefensives(me, mana)
    Ability.CastPosition(blink, blinkPos, false, true, true, OrderTag("linkbreak", "blink"), true)
    State.linkBreakPending = true
    State.linkBreakBlinkUsed = true
    State.linkBreakFollowUpItem = breaker
    State.linkBreakFollowUpName = breakerName
    State.linkBreakPopSent = false
    State.linkBreakAttemptTime = now
    Dbg(
        "CAST blink (link break setup) | %s dist=%.0f popRange=%.0f lassoRange=%.0f",
        breakerName or GetAbilityName(breaker),
        dist,
        breakRange,
        lasso and GetLassoCastRange(me, lasso) or 0
    )
    return true
end

local function ResetLinkBreakPopAttempt(reason, allowReblink)
    State.linkBreakPopSent = false
    State.linkBreakFollowUpItem = nil
    State.linkBreakFollowUpName = nil
    State.linkBreakPending = true
    if allowReblink then
        State.linkBreakBlinkUsed = false
    end
    Dbg("link break | pop failed | %s", reason or "?")
end

local function CastLinkBreakPop(me, target, breaker, breakerName, mana, tag)
    if not breaker or not IsBreakCastable(me, target, breaker, mana, breakerName) then
        return false
    end

    local now = GlobalVars.GetCurTime() or 0
    CastPreInitiationDefensives(me, mana)
    Ability.CastTarget(breaker, target, false, true, true, OrderTag(tag or "linkbreak", "cast"))
    State.linkBreakPending = true
    State.linkBreakPopSent = true
    State.linkBreakAttemptTime = now
    State.lastLinkBreakCast = now
    State.linkBreakFollowUpItem = nil
    State.linkBreakFollowUpName = nil
    Dbg("CAST link break | %s (cost=%d)", breakerName or GetAbilityName(breaker), GetItemCostValue(breaker, breakerName))
    return true
end

local function IsWaitingPopItemOnCd(me, target, mana)
    for _, entry in ipairs(CollectHeroItems(me)) do
        if CanPopLinkensOnEnemy(entry.item, entry.name) and not Ability.IsCastable(entry.item, mana) then
            local range = GetPopCastRange(me, entry.item, entry.name)
            local dist = Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target))
            if dist <= range + LINK_BREAK_APPROACH_MARGIN then
                return true, entry.name
            end
        end
    end

    return false, nil
end

local function HasOwnedDisplacementPopItem(me)
    for _, entry in ipairs(CollectHeroItems(me)) do
        local canonical = NormalizeLinkbreakItemName(entry.name)
        if POP_BLOCKED_DISPLACEMENT[entry.name] or POP_BLOCKED_DISPLACEMENT[canonical] then
            return true, entry.name
        end
    end

    return false, nil
end

local function TryApproachLinkBreak(me, target, blink, mana, now)
    if not CanAct(me) or not target then
        return false
    end

    if FindBestLinkbreaker(me, target, mana) then
        return false
    end

    local dist = Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target))
    local neededRange = GetMaxLinkbreakRange(me)
    if neededRange <= 0 then
        State.missingLinkbreaker = true
        if not State.missingLinkbreakerLogged
            and now - State.lastLinkBreakNoItemLog >= LINK_BREAK_NO_ITEM_LOG_INTERVAL then
            State.missingLinkbreakerLogged = true
            State.lastLinkBreakNoItemLog = now
            local ownedCount = CountOwnedLinkbreakers(me)
            local invNames = CollectInventoryDebugNames(me)
            local hasDisp, dispName = HasOwnedDisplacementPopItem(me)
            if hasDisp and ownedCount == 0 then
                Dbg(
                    "link break | need Linkbreaker item (have %s — displacement is blocked by linken's) dist=%.0f",
                    dispName or "force/pike",
                    dist
                )
            else
                local _, nextName = FindOwnedLinkbreaker(me, mana)
                local previewText = nextName and (" next=" .. nextName) or ""
                Dbg(
                    "link break | no in-range breaker (owned=%d dist=%.0f)%s items=[%s]",
                    ownedCount,
                    dist,
                    previewText,
                    table.concat(invNames, ", ")
                )
            end
        end
        return false
    end

    State.missingLinkbreaker = false
    State.missingLinkbreakerLogged = false

    if dist <= neededRange - LINK_BREAK_APPROACH_MARGIN then
        if not FindOwnedLinkbreaker(me, mana) then
            if now - State.lastLinkBreakCdLog >= LINK_BREAK_CD_LOG_INTERVAL then
                State.lastLinkBreakCdLog = now
                Dbg("link break | in range but breaker on cd or no mana")
            end
        end
        return false
    end

    if now - State.lastApproachMove < APPROACH_MOVE_INTERVAL then
        return true
    end

    State.lastApproachMove = now
    NPC.MoveTo(me, Entity.GetAbsOrigin(target), false, false, false, false, ORDER_ID .. ".linkbreak_approach", false)
    Dbg("approach link break | dist=%.0f need=%.0f", dist, neededRange)
    return true
end

local function ResetComboAttemptState()
    State.comboAttempted = false
    State.comboSent = false
    State.comboDone = false
    State.comboAttemptTime = 0
    State.initBlinkPending = false
    State.initBlinkTime = 0
    State.lastLassoRetry = -100
    State.lassoRetryCount = 0
end

local function IssueLassoCast(me, target, lasso, tag)
    Ability.CastTarget(lasso, target, false, true, true, OrderTag(tag, "lasso"))
    State.lastLassoRetry = GlobalVars.GetCurTime() or 0
    State.lassoRetryCount = State.lassoRetryCount + 1
    State.comboSent = true
    State.initBlinkPending = false
end

local function ClearLinkBreakState()
    State.linkBreakPending = false
    State.linkBreakBlinkUsed = false
    State.linkBreakFollowUpItem = nil
    State.linkBreakFollowUpName = nil
    State.linkBreakPopSent = false
end

---@return boolean chained True when lasso was cast immediately after link break.
local function ChainLassoAfterLinkBreak(me, target, lasso, bkb, mana, now)
    if not target or TargetNeedsLinkBreak(target) then
        return false
    end

    if not Ability.IsCastable(lasso, mana) or not CanCastLassoNow(me, target, lasso, mana) then
        State.comboAfterLinkBreak = true
        return false
    end

    CastPreInitiationDefensives(me, mana)

    IssueLassoCast(me, target, lasso, "linkbreak-chain.lasso")
    State.phase = "combo"
    State.comboAttempted = true
    State.comboAttemptTime = now
    State.comboAfterLinkBreak = false
    State.linkBreakBlinkUsed = false
    Dbg(
        "CAST lasso | chained after link break | dist=%.0f",
        Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target))
    )
    return true
end

---@return boolean blocked True while link-break phase should hold the combo.
local function HandleLinkBreak(me, target, lasso, blink, mana, now, targets)
    if not TargetNeedsLinkBreak(target) then
        ClearLinkBreakState()
        return false
    end

    if State.linkBreakPending then
        UpdateOverlay("linkbreak", State.lockedAnchor, target)

        if not TargetNeedsLinkBreak(target) then
            ClearLinkBreakState()
            ResetComboAttemptState()
            Dbg("link broken")
            ChainLassoAfterLinkBreak(me, target, lasso, NPC.GetItem(me, "item_black_king_bar", true), mana, now)
            return false
        end

        if State.linkBreakFollowUpItem and not State.linkBreakPopSent then
            if now >= State.linkBreakAttemptTime + LINK_BREAK_BLINK_SETTLE then
                if IsBreakCastable(
                    me,
                    target,
                    State.linkBreakFollowUpItem,
                    mana,
                    State.linkBreakFollowUpName
                ) then
                    CastLinkBreakPop(
                        me,
                        target,
                        State.linkBreakFollowUpItem,
                        State.linkBreakFollowUpName,
                        mana,
                        "linkbreak-follow"
                    )
                elseif now - State.linkBreakAttemptTime > LINK_BREAK_BLINK_POP_MAX_WAIT then
                    ResetLinkBreakPopAttempt("follow-up out of range", true)
                end
            end
            return true
        end

        if State.linkBreakPopSent then
            if not TargetNeedsLinkBreak(target) then
                ClearLinkBreakState()
                ResetComboAttemptState()
                Dbg("link broken")
                ChainLassoAfterLinkBreak(me, target, lasso, NPC.GetItem(me, "item_black_king_bar", true), mana, now)
                return false
            end

            local elapsed = now - State.linkBreakAttemptTime
            if elapsed < LINK_BREAK_POP_VERIFY then
                return true
            end

            if TargetNeedsLinkBreak(target) then
                ResetLinkBreakPopAttempt("linken's still up", false)
            end
            return true
        end
    end

    local breaker, breakerName = FindBestLinkbreaker(me, target, mana)
    if breaker and CastLinkBreakPop(me, target, breaker, breakerName, mana, "linkbreak") then
        UpdateOverlay("linkbreak", State.lockedAnchor, target)
        return true
    end

    if not State.linkBreakBlinkUsed then
        local ownedBreaker, ownedName = FindOwnedLinkbreaker(me, mana)
        if CastBlinkLinkBreak(me, target, blink, ownedBreaker, ownedName, mana, targets, lasso) then
            UpdateOverlay("linkbreak", State.lockedAnchor, target)
            return true
        end
    end

    local waitingCd, cdItem = IsWaitingPopItemOnCd(me, target, mana)
    if waitingCd then
        if not TargetNeedsLinkBreak(target) then
            ClearLinkBreakState()
            ResetComboAttemptState()
            Dbg("link broken | while waiting pop cd")
            ChainLassoAfterLinkBreak(me, target, lasso, NPC.GetItem(me, "item_black_king_bar", true), mana, now)
            return false
        end

        State.linkBreakPending = true
        if now - State.lastLinkBreakCdLog >= LINK_BREAK_CD_LOG_INTERVAL then
            State.lastLinkBreakCdLog = now
            Dbg("link break | waiting cd | %s", cdItem or "?")
        end
        UpdateOverlay("linkbreak", State.lockedAnchor, target)
        return true
    end

    TryApproachLinkBreak(me, target, blink, mana, now)
    UpdateOverlay("linkbreak", State.lockedAnchor, target)
    return true
end

--#endregion

--#region Casting

local function CastBlinkLassoCombo(me, targets, blink, lasso, bkb, mana, tag)
    tag = tag or "combo"

    if TargetNeedsLinkBreak(targets.target) then
        Dbg("combo blocked | target still has linken's")
        return false
    end

    CastPreInitiationDefensives(me, mana)

    if CanCastLassoNow(me, targets.target, lasso, mana) then
        IssueLassoCast(me, targets.target, lasso, tag .. ".lasso")
        Dbg("CAST %s | lasso only | allies=%d", tag, targets.anchor.count)
        return true
    end

    if targets.blinkPos and blink and Ability.IsCastable(blink, mana) and not State.linkBreakBlinkUsed then
        local now = GlobalVars.GetCurTime() or 0
        Ability.CastPosition(blink, targets.blinkPos, false, true, true, OrderTag(tag, "blink"), true)
        State.initBlinkPending = true
        State.initBlinkTime = now
        State.comboSent = false
        Dbg(
            "CAST %s | blink setup | allies=%d pos=(%.0f,%.0f)",
            tag,
            targets.anchor.count,
            targets.blinkPos.x,
            targets.blinkPos.y
        )
        return true
    end

    if Ability.IsCastable(lasso, mana) then
        IssueLassoCast(me, targets.target, lasso, tag .. ".lasso")
        Dbg("CAST %s | lasso only | allies=%d", tag, targets.anchor.count)
        return true
    end

    return false
end

--- After an initiation blink lands, cast lasso once we are in range (never same-tick as blink).
---@return boolean chained True when lasso was issued this tick.
local function TryChainLassoAfterInitBlink(me, target, lasso, mana, now)
    if not State.initBlinkPending then
        return false
    end

    if now < State.initBlinkTime + COMBO_BLINK_SETTLE then
        return true
    end

    if TargetNeedsLinkBreak(target) then
        return false
    end

    if CanCastLassoNow(me, target, lasso, mana) then
        if now - State.lastLassoRetry < LASSO_ORDER_SETTLE then
            return true
        end

        if State.lassoRetryCount >= MAX_LASSO_RETRIES then
            State.initBlinkPending = false
            return false
        end

        IssueLassoCast(me, target, lasso, "init-blink.lasso")
        Dbg(
            "CAST init | lasso after blink | dist=%.0f",
            Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(target))
        )
        return true
    end

    if now - State.initBlinkTime > COMBO_BLINK_LASSO_TIMEOUT then
        State.initBlinkPending = false
        return false
    end

    return true
end

local function TryFinishCombo(me, activeTargets, lasso, blink, mana, elapsed, tag)
    if State.comboSent then
        return false
    end

    if elapsed < RECOVERY_MIN_DELAY or elapsed > COMBO_RECOVERY_TIME then
        return false
    end

    if Ability.IsCastable(lasso, mana) then
        return false
    end

    local lassoReady = Ability.IsCastable(lasso, mana)
    local blinkReady = blink and Ability.IsCastable(blink, mana)
    local bkb = NPC.GetItem(me, "item_black_king_bar", true)
    local targets = State.lockedTargets or activeTargets

    if not lassoReady and not blinkReady then
        Dbg("%s skipped | combo landed", tag)
        State.comboSent = true
        return true
    end

    State.comboSent = true

    if lassoReady and (blinkReady or not targets.needsBlink) then
        CastBlinkLassoCombo(me, targets, blink, lasso, bkb, mana, tag)
    elseif lassoReady then
        Ability.CastTarget(lasso, targets.target, false, true, true, OrderTag(tag .. "-lasso", "lasso"))
        Dbg("CAST %s | lasso only recovery", tag)
    elseif blinkReady and targets.blinkPos then
        Ability.CastPosition(blink, targets.blinkPos, false, true, true, OrderTag(tag .. "-blink", "blink"), true)
        Dbg("CAST %s | blink only recovery", tag)
    end

    return true
end

--#endregion

--#region Drag

local function GetFacingAngleTo(me, pos)
    if NPC.FindRotationAngle then
        -- FindRotationAngle returns radians; convert to degrees for the gate.
        return math.abs(math.deg(NPC.FindRotationAngle(me, pos) or math.pi))
    end

    return 999
end

local function IsFacingAnchor(me, anchorPos)
    if NPC.GetTimeToFacePosition then
        local timeToFace = NPC.GetTimeToFacePosition(me, anchorPos)
        if timeToFace ~= nil then
            return timeToFace <= DRAG_FACE_MAX_TURN_TIME
        end
    end

    return GetFacingAngleTo(me, anchorPos) <= DRAG_FACE_MAX_ANGLE
end

local function CanUseDragDisplacementLoose(me, anchorPos, now)
    if State.dragStartTime <= 0 then
        return false
    end

    if now - State.dragStartTime < DRAG_BOOST_MIN_MOVE then
        return false
    end

    return IsFacingAnchor(me, anchorPos)
end

local function GetHealthPct(unit)
    local hp = Entity.GetHealth(unit) or 0
    local maxHp = Entity.GetMaxHealth(unit) or 1
    if maxHp <= 0 then
        return 1
    end

    return hp / maxHp
end

local function WasDragItemRecently(name, now, interval)
    local last = State.lastDragItemUse[name] or -100
    return now - last < (interval or DRAG_ITEM_INTERVAL)
end

local function MarkDragItemUse(name, now)
    State.lastDragItemUse[name] = now
end

local function GetCastableUsageItem(me, mana, itemName)
    if not IsItemUsageEnabled(itemName) then
        return nil
    end

    local item = NPC.GetItem(me, itemName, true)
    if item and Ability.IsCastable(item, mana) then
        return item
    end

    return nil
end

local function HasAnyModifier(unit, modifiers)
    for _, modifierName in ipairs(modifiers) do
        if NPC.HasModifier(unit, modifierName) then
            return true
        end
    end

    return false
end

local function IsMagicImmune(me)
    return HasAnyModifier(me, IMMUNITY_MODIFIERS)
end

-- True when a basic dispel (Manta / Lotus) would actually clear a disable that
-- is stopping the drag: an active silence, or a root/leash debuff. Hex and stun
-- cannot be self-cleared, so they are intentionally excluded.
local function NeedsProactiveDispel(me)
    if IsMagicImmune(me) then
        return false
    end

    if NPC.IsSilenced and NPC.IsSilenced(me) then
        return true
    end

    return HasAnyModifier(me, DISPELLABLE_DISABLE_MODIFIERS)
end

-- Displacement (Force/Pike) is still "coming" this drag when it is enabled,
-- owned, off cooldown and affordable — used to hold invisibility until the push.
local function IsDisplacementPending(me, mana)
    if State.dragDisplacementUsed then
        return false
    end

    local function usableSoon(itemName)
        if not IsItemUsageEnabled(itemName) then
            return false
        end
        local item = NPC.GetItem(me, itemName, true)
        if not item then
            return false
        end
        if (Ability.GetCooldown(item) or 0) > DISPLACEMENT_PENDING_CD then
            return false
        end
        return mana >= (Ability.GetManaCost(item) or 0)
    end

    return usableSoon("item_force_staff") or usableSoon("item_hurricane_pike")
end

local function CastDragNoTarget(me, mana, itemName, logName, now, interval)
    if WasDragItemRecently(itemName, now, interval) then
        return false
    end

    local item = GetCastableUsageItem(me, mana, itemName)
    if not item then
        return false
    end

    Ability.CastNoTarget(item, false, true, true, OrderTag("drag", itemName))
    MarkDragItemUse(itemName, now)
    Dbg("CAST %s", logName or itemName)
    return true
end

local function CastDragSelfTarget(me, mana, itemName, logName, now, interval)
    if WasDragItemRecently(itemName, now, interval) then
        return false
    end

    local item = GetCastableUsageItem(me, mana, itemName)
    if not item then
        return false
    end

    Ability.CastTarget(item, me, false, true, true, OrderTag("drag", itemName))
    MarkDragItemUse(itemName, now)
    Dbg("CAST %s", logName or itemName)
    return true
end

local function TryDragFirefly(me, mana, now)
    if not IsAbilityUsageEnabled(FIREFLY_NAME) or WasDragItemRecently(FIREFLY_NAME, now, 0.35) then
        return false
    end

    local firefly = NPC.GetAbility(me, FIREFLY_NAME)
    if firefly
        and Ability.IsCastable(firefly, mana)
        and not NPC.HasModifier(me, FIREFLY_MODIFIER) then
        Ability.CastNoTarget(firefly, false, true, true, OrderTag("drag", "firefly"))
        MarkDragItemUse(FIREFLY_NAME, now)
        Dbg("CAST firefly on self")
        return true
    end

    return false
end

local function TryDragSpeedItems(me, mana, now)
    if IsItemUsageEnabled("item_phase_boots") and not WasDragItemRecently("item_phase_boots", now, 0.20) then
        local phase = NPC.GetItem(me, "item_phase_boots", true)
        if phase and Ability.IsCastable(phase, mana) then
            Ability.Toggle(phase, false, true, true, OrderTag("drag", "phase"))
            MarkDragItemUse("item_phase_boots", now)
            Dbg("CAST phase boots on self")
            return true
        end
    end

    if CastDragNoTarget(me, mana, "item_boots_of_bearing", "boots of bearing", now, 0.35) then
        return true
    end

    if CastDragNoTarget(me, mana, "item_ancient_janggo", "drum of endurance", now, 0.35) then
        return true
    end

    return false
end

local function TryDragInvisItems(me, mana, now)
    -- Already invisible: nothing to do (and the top-level guard blocks other casts).
    if HasAnyModifier(me, INVIS_MODIFIERS) then
        return false
    end

    -- Invis must be the very last action so we do not immediately break it: hold
    -- until the displacement push has resolved (or is no longer coming this drag).
    if IsDisplacementPending(me, mana) then
        return false
    end

    local cast = CastDragNoTarget(me, mana, "item_silver_edge", "silver edge", now, 0.50)
        or CastDragNoTarget(me, mana, "item_invis_sword", "shadow blade", now, 0.50)
        or CastDragSelfTarget(me, mana, "item_glimmer_cape", "glimmer cape on self", now, 0.50)

    if cast then
        return true
    end

    return false
end

local function TryDragSurvivalItems(me, mana, now)
    -- Proactive dispel: clear a silence/root that would stall the drag, regardless
    -- of HP. Manta is the stronger dispel, Lotus is the fallback (also reflects).
    if NeedsProactiveDispel(me) then
        if CastDragNoTarget(me, mana, "item_manta", "manta (dispel)", now, 0.50) then
            return true
        end

        if CastDragSelfTarget(me, mana, "item_lotus_orb", "lotus orb (dispel)", now, 0.50) then
            return true
        end
    end

    local hpPct = GetHealthPct(me)

    if hpPct <= DRAG_SURVIVAL_HP_PCT then
        if CastDragNoTarget(me, mana, "item_manta", "manta style", now, 0.50) then
            return true
        end

        if CastDragSelfTarget(me, mana, "item_lotus_orb", "lotus orb on self", now, 0.50) then
            return true
        end

        if CastDragNoTarget(me, mana, "item_pipe", "pipe", now, 0.50) then
            return true
        end

        if CastDragNoTarget(me, mana, "item_crimson_guard", "crimson guard", now, 0.50) then
            return true
        end
    end

    if hpPct <= DRAG_HEAL_HP_PCT then
        if CastDragNoTarget(me, mana, "item_guardian_greaves", "guardian greaves", now, 0.50) then
            return true
        end

        if CastDragNoTarget(me, mana, "item_mekansm", "mekansm", now, 0.50) then
            return true
        end

        if CastDragNoTarget(me, mana, "item_cheese", "cheese", now, 0.50) then
            return true
        end

        if CastDragNoTarget(me, mana, "item_greater_faerie_fire", "greater faerie fire", now, 0.50) then
            return true
        end
    end

    return false
end

local function TryDragDisplacementItems(me, mana, anchorPos, now)
    if State.dragDisplacementUsed then
        return false
    end

    local forceStaffEnabled = IsItemUsageEnabled("item_force_staff")
    local pikeEnabled = IsItemUsageEnabled("item_hurricane_pike")
    local forceStaff = NPC.GetItem(me, "item_force_staff", true)
    local hurricanePike = NPC.GetItem(me, "item_hurricane_pike", true)
    local forceCastable = forceStaff and Ability.IsCastable(forceStaff, mana)
    local pikeCooldown = hurricanePike and Ability.GetCooldown(hurricanePike) or -1
    local pikeManaCost = hurricanePike and Ability.GetManaCost(hurricanePike) or -1
    local pikeCastable = hurricanePike and Ability.IsCastable(hurricanePike, mana)
    local pikeUsable = pikeCastable == true
        or (
            hurricanePike ~= nil
            and pikeCooldown <= 0
            and mana >= pikeManaCost
        )

    if not (forceStaffEnabled and forceCastable) and not (pikeEnabled and pikeUsable) then
        if UI.Debug:Get() and now - State.lastDragDisplacementDiag >= 0.75 then
            State.lastDragDisplacementDiag = now
            Dbg(
                "drag displacement unavailable | force enabled=%s slot=%s castable=%s cd=%.2f mana=%d/%d | pike enabled=%s slot=%s castable=%s usable=%s cd=%.2f mana=%d/%d",
                tostring(forceStaffEnabled),
                tostring(forceStaff ~= nil),
                tostring(forceCastable == true),
                forceStaff and Ability.GetCooldown(forceStaff) or -1,
                math.floor(mana or 0),
                forceStaff and Ability.GetManaCost(forceStaff) or -1,
                tostring(pikeEnabled),
                tostring(hurricanePike ~= nil),
                tostring(pikeCastable == true),
                tostring(pikeUsable == true),
                pikeCooldown,
                math.floor(mana or 0),
                pikeManaCost
            )
        end
        return false
    end

    if not CanUseDragDisplacementLoose(me, anchorPos, now) then
        -- Not facing the anchor yet. Do NOT block here: return false so speed/
        -- firefly keep firing, and let the regular drag MoveTo turn the hero.
        return false
    end

    if forceStaffEnabled and forceStaff and forceCastable and not WasDragItemRecently("item_force_staff", now, 0.25) then
        Ability.CastTarget(forceStaff, me, false, true, true, OrderTag("drag", "item_force_staff"))
        MarkDragItemUse("item_force_staff", now)
        State.dragDisplacementUsed = true
        Dbg("CAST force staff on self")
        return true
    end

    if pikeEnabled and hurricanePike and pikeUsable and not WasDragItemRecently("item_hurricane_pike", now, 0.25) then
        Ability.CastTarget(hurricanePike, me, false, true, true, OrderTag("drag", "item_hurricane_pike"))
        MarkDragItemUse("item_hurricane_pike", now)
        State.dragDisplacementUsed = true
        Dbg("CAST hurricane pike on self")
        return true
    end

    return false
end

local function TryDragBoostItems(me, mana, anchorPos, now)
    -- Preserve invisibility: once invisible, any cast would reveal us, so skip all
    -- item usage and let movement carry the drag to the anchor.
    if HasAnyModifier(me, INVIS_MODIFIERS) then
        return false
    end

    -- One cast per tick. Priority:
    --   1) Firefly + speed items fire immediately for movement speed (no facing needed).
    --   2) Displacement (Force/Pike) pushes toward allies once the hero has turned.
    --   3) Survival (proactive dispel, then HP-based defensives/heals).
    --   4) Invisibility strictly last, so it is never broken by a follow-up cast.
    if TryDragFirefly(me, mana, now) then
        return true
    end
    if TryDragSpeedItems(me, mana, now) then
        return true
    end
    if TryDragDisplacementItems(me, mana, anchorPos, now) then
        return true
    end
    if TryDragSurvivalItems(me, mana, now) then
        return true
    end
    return TryDragInvisItems(me, mana, now)
end

local function HandleDragPhase(me, victim, now)
    if not victim or not IsValidHero(victim) then
        UpdateOverlay("drag", State.lockedAnchor, victim)
        return
    end

    State.phase = "drag"

    local anchor = FindBestAllyAnchor(me) or State.lockedAnchor
    if anchor then
        State.lockedAnchor = anchor
        State.lockedClusterMembers = anchor.members
    end

    local lockedAnchor = State.lockedAnchor
    local anchorPos = anchor and anchor.anchorPos or lockedAnchor and lockedAnchor.anchorPos
    if not anchorPos then
        UpdateOverlay("drag", nil)
        return
    end

    UpdateOverlay("drag", anchor, victim)

    local victimPos = Entity.GetAbsOrigin(victim)
    local deliverDist = AUTO_DELIVER_DISTANCE

    if Dist2D(victimPos, anchorPos) <= deliverDist then
        if not State.delivered then
            State.delivered = true
            Dbg("delivered | dist=%.0f", Dist2D(victimPos, anchorPos))
        end

        if now < State.manualOverrideUntil then
            return
        end

        if AUTO_STOP_WHEN_DELIVERED and not State.deliveredHoldSent then
            local player = Players.GetLocal()
            if player then
                Player.HoldPosition(player, me, false, true, true, ORDER_ID .. ".delivered")
                State.deliveredHoldSent = true
            end
        end
        return
    end

    if now < State.manualOverrideUntil then
        return
    end

    local itemCast = TryDragBoostItems(me, NPC.GetMana(me), anchorPos, now)

    if not itemCast and now - State.lastDragMove >= DRAG_MOVE_INTERVAL then
        State.lastDragMove = now
        NPC.MoveTo(me, anchorPos, false, false, false, false, ORDER_ID .. ".drag", false)
    end
end

local function HandleAnchorDeliveryPhase(me, now)
    local anchor = State.lockedAnchor
    local anchorPos = anchor and anchor.anchorPos
    if not anchorPos then
        State.comboDone = true
        return true
    end

    State.phase = "drag"
    UpdateOverlay("drag", anchor, State.lockedTarget)

    local dist = Dist2D(Entity.GetAbsOrigin(me), anchorPos)
    if dist <= AUTO_SELF_DELIVER_DISTANCE then
        if not State.delivered then
            State.delivered = true
            State.comboDone = true
            Dbg("delivered self | dist=%.0f", dist)
        end
        return true
    end

    if now < State.manualOverrideUntil then
        return true
    end

    local itemCast = TryDragBoostItems(me, NPC.GetMana(me), anchorPos, now)
    if not itemCast and now - State.lastDragMove >= DRAG_MOVE_INTERVAL then
        State.lastDragMove = now
        NPC.MoveTo(me, anchorPos, false, false, false, false, ORDER_ID .. ".drag_fallback", false)
    end

    return true
end

--#endregion

--#region Overlay

---@param source Color
---@param alpha integer
---@return Color
local function ColorWithAlpha(source, alpha)
    if source.Unpack then
        local r, g, b = source:Unpack()
        return Color(r, g, b, alpha)
    end

    return Color(source.r, source.g, source.b, alpha)
end

---@return Color
local function GetThemeColor(name, fallback)
    if not Menu or not Menu.Style then
        return fallback
    end

    local ok, color = pcall(Menu.Style, name)
    if ok and color and type(color) == "userdata" then
        ---@cast color Color
        return color
    end

    return fallback
end

local function SyncOverlayTheme()
    local now = os.clock()
    if now - OverlayTheme.syncedAt < OVERLAY_THEME_INTERVAL then
        return
    end
    OverlayTheme.syncedAt = now

    local primary = GetThemeColor("primary", OverlayTheme.route)
    local active = GetThemeColor("indication_active", OverlayTheme.anchor)
    local accent = GetThemeColor("slider_circle", OverlayTheme.target)

    OverlayTheme.route = ColorWithAlpha(primary, 215)
    OverlayTheme.routeGlow = ColorWithAlpha(primary, 42)
    OverlayTheme.anchor = ColorWithAlpha(active, 225)
    OverlayTheme.anchorGlow = ColorWithAlpha(active, 38)
    OverlayTheme.target = ColorWithAlpha(accent, 205)

    local popupBg = GetThemeColor("popup_background", OverlayTheme.pillBg)
    OverlayTheme.pillBg = ColorWithAlpha(popupBg, 188)

    local text = GetThemeColor("primary_widgets_text", OverlayTheme.text)
    OverlayTheme.text = ColorWithAlpha(text, 235)

    if Render and Render.LoadFont and OverlayTheme.font == 0 then
        OverlayTheme.font = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500) or 0
        if OverlayTheme.font == 0 then
            OverlayTheme.font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500) or 0
        end
    end
end

local function PhaseLabel(phase)
    local key = "phase_" .. tostring(phase or "idle")
    return L(key)
end

local function DrawSoftLine(from, to, coreColor, glowColor, coreWidth, glowWidth)
    if glowWidth and glowWidth > 0 then
        Render.Line(from, to, glowColor, glowWidth)
    end
    Render.Line(from, to, coreColor, coreWidth or 2)
end

local function DrawRoutePath(myPos, anchorPos, pulse)
    local steps = 14
    local prevScreen, prevVisible = nil, false

    for i = 0, steps do
        local t = i / steps
        local world = Vector(
            myPos.x + (anchorPos.x - myPos.x) * t,
            myPos.y + (anchorPos.y - myPos.y) * t,
            myPos.z + (anchorPos.z - myPos.z) * t
        )
        local screen, visible = Render.WorldToScreen(world)

        if visible and prevVisible then
            local fade = 0.55 + 0.45 * math.sin(pulse + t * 4.0)
            local core = Color(
                OverlayTheme.route.r,
                OverlayTheme.route.g,
                OverlayTheme.route.b,
                math.floor(OverlayTheme.route.a * fade)
            )
            local glow = Color(
                OverlayTheme.routeGlow.r,
                OverlayTheme.routeGlow.g,
                OverlayTheme.routeGlow.b,
                math.floor(OverlayTheme.routeGlow.a * fade)
            )

            if i % 2 == 1 then
                DrawSoftLine(prevScreen, screen, core, glow, 2, 6)
            end
        end

        if visible and i > 0 and i < steps and i % 3 == 0 then
            local dotPulse = 0.65 + 0.35 * math.sin(pulse * 1.4 + i)
            local radius = 2.5 + dotPulse * 1.5
            Render.FilledCircle(
                screen,
                radius + 2,
                Color(OverlayTheme.route.r, OverlayTheme.route.g, OverlayTheme.route.b, 28)
            )
            Render.FilledCircle(
                screen,
                radius,
                Color(OverlayTheme.route.r, OverlayTheme.route.g, OverlayTheme.route.b, 170)
            )
        end

        prevScreen = screen
        prevVisible = visible
    end
end

local function DrawMarker(screen, color, glowColor, pulse, radius)
    local ring = radius + math.sin(pulse) * 1.5
    Render.Circle(screen, ring + 7, glowColor, 2)
    Render.Circle(screen, ring + 3, Color(color.r, color.g, color.b, 90), 1)
    Render.Circle(screen, ring, color, 2)
    Render.FilledCircle(screen, math.max(3, radius * 0.35), Color(color.r, color.g, color.b, 230))
end

local function DrawPhasePill(screen, text, pulse)
    if not Render.Text or OverlayTheme.font == 0 then
        return
    end

    local textSize = Render.TextSize and Render.TextSize(OverlayTheme.font, 13, text) or Vec2(72, 16)
    local padX, padY = 10, 5
    local width = textSize.x + padX * 2
    local height = textSize.y + padY * 2
    local topLeft = Vec2(screen.x + 18, screen.y - height * 0.5 - 8)
    local bottomRight = Vec2(topLeft.x + width, topLeft.y + height)
    local accentAlpha = math.floor(55 + 25 * math.sin(pulse * 1.2))

    Render.FilledRect(topLeft, bottomRight, OverlayTheme.pillBg, 6)
    Render.Rect(topLeft, bottomRight, OverlayTheme.pillBorder, 6, Enum.DrawFlags and Enum.DrawFlags.None or 0, 1)
    Render.FilledRect(
        topLeft,
        Vec2(topLeft.x + width, topLeft.y + 2),
        Color(OverlayTheme.route.r, OverlayTheme.route.g, OverlayTheme.route.b, accentAlpha),
        6
    )
    Render.Text(OverlayTheme.font, 13, text, Vec2(topLeft.x + padX, topLeft.y + padY - 1), OverlayTheme.text)
end

function Script:OnDraw()
    if not UI.Enabled:Get() or not UI.DrawOverlay:Get() then
        return
    end

    if not Engine.IsInGame() or not Render then
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    local anchorPos = State.overlayAnchor
    if not anchorPos then
        return
    end

    SyncOverlayTheme()

    local pulse = os.clock() * 3.2
    local myPos = Entity.GetAbsOrigin(me)
    DrawRoutePath(myPos, anchorPos, pulse)

    local myScreen, myVisible = Render.WorldToScreen(myPos)
    local anchorScreen, anchorVisible = Render.WorldToScreen(anchorPos)

    if myVisible then
        DrawMarker(myScreen, OverlayTheme.route, OverlayTheme.routeGlow, pulse, 5)
    end

    if State.overlayTarget then
        local targetScreen, targetVisible = Render.WorldToScreen(State.overlayTarget)
        if targetVisible then
            DrawMarker(targetScreen, OverlayTheme.target, Color(OverlayTheme.target.r, OverlayTheme.target.g, OverlayTheme.target.b, 35), pulse + 1.2, 4)

            if myVisible then
                DrawSoftLine(
                    myScreen,
                    targetScreen,
                    Color(OverlayTheme.target.r, OverlayTheme.target.g, OverlayTheme.target.b, 120),
                    Color(OverlayTheme.target.r, OverlayTheme.target.g, OverlayTheme.target.b, 25),
                    1,
                    4
                )
            end
        end
    end

    if anchorVisible then
        DrawMarker(anchorScreen, OverlayTheme.anchor, OverlayTheme.anchorGlow, pulse + 0.8, 7)
        DrawPhasePill(anchorScreen, PhaseLabel(State.overlayPhase), pulse)
    end
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    ApplyLocalization(false)
    RefreshLinkbreakerMultiSelect(true)
end

function Script:OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    local dataTable = type(data) == "table" and data or nil
    local identifier = dataTable and dataTable.identifier or nil

    if State.sessionActive and ability
        and not (type(identifier) == "string" and identifier:find(ORDER_ID, 1, true) == 1) then
        local abilityName = GetAbilityName(ability)
        local isScriptAbility = abilityName == LASSO_NAME
            or abilityName == FIREFLY_NAME
            or string.find(abilityName, "blink", 1, true)
            or ITEM_POP_COSTS[abilityName] ~= nil

        if not isScriptAbility then
            for _, itemGroup in ipairs(ITEM_USAGE_GROUPS) do
                for _, itemId in ipairs(itemGroup.items) do
                    if abilityName == itemId then
                        isScriptAbility = true
                        break
                    end
                end
                if isScriptAbility then
                    break
                end
            end
        end

        local localPlayer = Players.GetLocal and Players.GetLocal() or nil
        local localPlayerId = localPlayer and Player.GetPlayerID(localPlayer) or -1
        local orderPlayer = dataTable and dataTable.player or player
        local orderPlayerId = orderPlayer and Player.GetPlayerID(orderPlayer) or localPlayerId

        if not isScriptAbility and orderPlayerId == localPlayerId then
            State.manualOverrideUntil = (GlobalVars.GetCurTime() or 0) + 0.85
        end
    end

    if not UI.Debug:Get() or not ability then
        return
    end

    local abilityName = GetAbilityName(ability)
    local isRelevant = abilityName == LASSO_NAME
        or abilityName == FIREFLY_NAME
        or string.find(abilityName, "blink", 1, true)

    if not isRelevant then
        for _, itemGroup in ipairs(ITEM_USAGE_GROUPS) do
            for _, itemId in ipairs(itemGroup.items) do
                if abilityName == itemId then
                    isRelevant = true
                    break
                end
            end
            if isRelevant then
                break
            end
        end
    end

    if not isRelevant then
        for itemId in pairs(ITEM_POP_COSTS) do
            if abilityName == itemId or string.find(abilityName, "item_dagon", 1, true) then
                isRelevant = true
                break
            end
        end
    end

    if not isRelevant then
        return
    end

    Dbg(
        "order=%s ability=%s queue=%s pos=%s",
        tostring(order),
        abilityName,
        tostring(queue),
        position and string.format("(%.0f,%.0f)", position.x, position.y) or "nil"
    )
end

function Script:OnUpdate()
    ApplyLocalization(false)

    if not Engine.IsInGame() or not UI.Enabled:Get() then
        ResetHoldState()
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    local now = GlobalVars.GetCurTime() or 0
    local victim = FindLassoVictim(me)
    local keyHeld = IsComboKeyHeld()

    if not keyHeld then
        if State.sessionActive then
            StopComboExecution(me)
        else
            ResetHoldState()
        end
        return
    end

    State.sessionActive = true

    if victim or IsLassoChanneling(me) then
        if victim then
            State.lockedTarget = victim
        end

        if State.dragStartTime <= 0 then
            State.dragStartTime = now
        end

        HandleDragPhase(me, victim or State.lockedTarget, now)
        return
    end

    if State.comboDone then
        return
    end

    if State.phase == "drag" then
        if State.delivered then
            State.comboDone = true
            State.phase = "combo"
            return
        end
        if State.lockedAnchor and (State.comboSent or State.dragStartTime > 0) then
            HandleAnchorDeliveryPhase(me, now)
            return
        end
        ResetHoldState()
    end

    if Input.IsInputCaptured and Input.IsInputCaptured() then
        return
    end

    if not CanAct(me) then
        return
    end

    local mana = NPC.GetMana(me)
    local lasso = NPC.GetAbility(me, LASSO_NAME)
    local blink, blinkName = GetBlink(me)
    local bkb = NPC.GetItem(me, "item_black_king_bar", true)

    if not lasso then
        return
    end

    if not IsAbilityUsageEnabled(LASSO_NAME) then
        return
    end

    if State.lockedAnchor
        and not Ability.IsCastable(lasso, mana)
        and (State.comboSent or State.comboAttempted or State.dragStartTime > 0) then
        State.comboDone = true
        HandleAnchorDeliveryPhase(me, now)
        return
    end

    State.phase = "acquire"
    UpdateOverlay("acquire", State.lockedAnchor)

    local debugReason = { "" }
    local targets = State.lockedTargets or ResolveComboTargets(me, lasso, blink, debugReason)
    local comboReady = IsComboReady(me, mana, lasso, blink, targets)

    LogHoldState(debugReason[1], me, mana, lasso, blink, blinkName, targets, comboReady)

    local activeTargets = State.lockedTargets or targets

    if State.comboDone then
        return
    end

    if not activeTargets then
        local approachTarget = ResolveTarget(me, nil)
        if approachTarget then
            TryApproachTarget(me, approachTarget, lasso, blink, now, false)
        end
        return
    end

    State.lockedAnchor = activeTargets.anchor
    State.lockedClusterMembers = activeTargets.anchor.members
    State.lockedTargets = activeTargets
    UpdateOverlay("acquire", activeTargets.anchor, activeTargets.target)

    if HandleLinkBreak(me, activeTargets.target, lasso, blink, mana, now, activeTargets) then
        return
    end

    if State.comboAfterLinkBreak then
        local refreshedAfterLink = ResolveComboTargets(me, lasso, blink, debugReason)
        if refreshedAfterLink then
            State.lockedTargets = refreshedAfterLink
            activeTargets = refreshedAfterLink
        end

        if CanCastLassoNow(me, activeTargets.target, lasso, mana) and Ability.IsCastable(lasso, mana) then
            if ChainLassoAfterLinkBreak(
                me,
                activeTargets.target,
                lasso,
                bkb,
                mana,
                now
            ) then
                return
            end
        end

        if IsComboReady(me, mana, lasso, blink, activeTargets) then
            State.phase = "combo"
            State.comboAttempted = true
            State.comboAttemptTime = now
            State.comboAfterLinkBreak = false
            UpdateOverlay("combo", activeTargets.anchor, activeTargets.target)
            CastBlinkLassoCombo(me, activeTargets, blink, lasso, bkb, mana, "post-link")
            return
        end

        if TryApproachTarget(me, activeTargets.target, lasso, blink, now, true) then
            UpdateOverlay("linkbreak", activeTargets.anchor, activeTargets.target)
            return
        end
    end

    local refreshed = ResolveComboTargets(me, lasso, blink, debugReason)
    if refreshed then
        State.lockedTargets = refreshed
        activeTargets = refreshed
    end

    comboReady = IsComboReady(me, mana, lasso, blink, activeTargets)

    if State.comboAttempted then
        local elapsed = now - State.comboAttemptTime

        if TryChainLassoAfterInitBlink(me, activeTargets.target, lasso, mana, now) then
            if IsLassoOrderActive(me, lasso) then
                State.comboDone = true
                State.phase = "combo"
            elseif State.initBlinkPending
                and now >= State.initBlinkTime + COMBO_BLINK_SETTLE
                and not CanCastLassoNow(me, activeTargets.target, lasso, mana) then
                TryApproachTarget(me, activeTargets.target, lasso, blink, now, true)
            end
            return
        end

        if not State.comboSent then
            TryFinishCombo(me, activeTargets, lasso, blink, mana, elapsed, "recovery")
        end

        if State.comboSent then
            if IsLassoOrderActive(me, lasso) then
                State.comboDone = true
                State.phase = "combo"
            elseif now - State.lastLassoRetry < LASSO_CONFIRM_WAIT then
                -- Order just sent; wait for cast point / channel before judging failure.
            elseif not Ability.IsCastable(lasso, mana) then
                if elapsed > COMBO_RECOVERY_TIME then
                    ResetComboAttemptState()
                    Dbg("combo reset | lasso on cd but no hook detected")
                end
            elseif CanCastLassoNow(me, activeTargets.target, lasso, mana)
                and State.lassoRetryCount < MAX_LASSO_RETRIES then
                IssueLassoCast(me, activeTargets.target, lasso, "recovery.lasso")
                Dbg(
                    "CAST recovery | lasso retry %d/%d | dist=%.0f",
                    State.lassoRetryCount,
                    MAX_LASSO_RETRIES,
                    Dist2D(Entity.GetAbsOrigin(me), Entity.GetAbsOrigin(activeTargets.target))
                )
            elseif elapsed > COMBO_RECOVERY_TIME then
                ResetComboAttemptState()
                Dbg("combo reset | lasso command did not land")
            end
        elseif not Ability.IsCastable(lasso, mana)
            and (not blink or not Ability.IsCastable(blink, mana)) then
            if IsLassoOrderActive(me, lasso) then
                State.comboDone = true
                State.phase = "combo"
            elseif elapsed > COMBO_RECOVERY_TIME then
                ResetComboAttemptState()
                Dbg("combo reset | no lasso landed")
            end
        elseif elapsed > COMBO_RECOVERY_TIME then
            if not State.comboSent then
                TryFinishCombo(me, activeTargets, lasso, blink, mana, elapsed, "late-recovery")
            end
            State.comboDone = true
            State.phase = "combo"
        end
        return
    end

    if not IsComboReady(me, mana, lasso, blink, activeTargets) then
        if activeTargets.target then
            TryApproachTarget(me, activeTargets.target, lasso, blink, now, false)
        end
        return
    end

    if not CanCastLassoNow(me, activeTargets.target, lasso, mana) then
        if not (activeTargets.needsBlink and activeTargets.blinkPos) then
            TryApproachTarget(me, activeTargets.target, lasso, blink, now, false)
            return
        end
    end

    if targets then
        State.lockedTargets = targets
        activeTargets = targets
    end

    State.phase = "combo"
    UpdateOverlay("combo", activeTargets.anchor, activeTargets.target)
    State.comboAttempted = true
    State.comboAttemptTime = now
    CastBlinkLassoCombo(me, activeTargets, blink, lasso, bkb, mana, "init")
end

--#endregion

return Script
