--[[
    Pangolier Rolling Thunder AutoPilot
    Hold key: cast Gyroshell (+ optional blink), then steer with wall/cliff bounces for max hits.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "PangolierAutoPilot"
local CONFIG_SECTION = "pangolier_autopilot"
local HERO_NAME = "npc_dota_hero_pangolier"
local HERO_TAB = "Pangolier"
local HERO_ICON = "panorama/images/heroes/icons/npc_dota_hero_pangolier_png.vtex_c"
local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_THIRD = "AutoPilot"
local MENU_GROUP = "Rolling Thunder"

local ABILITY_GYROSHELL = "pangolier_gyroshell"
local ABILITY_SWASHBUCKLE = "pangolier_swashbuckle"
local ABILITY_SHIELD_CRASH = "pangolier_shield_crash"
local ABILITY_GYROSHELL_STOP = "pangolier_gyroshell_stop"
local ABILITY_ROLLUP = "pangolier_rollup"
local ABILITY_ROLLUP_STOP = "pangolier_rollup_stop"
local MOD_GYROSHELL = "modifier_pangolier_gyroshell"
local MOD_RICOCHET = "modifier_pangolier_gyroshell_ricochet"
local MOD_STUNNED = "modifier_pangolier_gyroshell_stunned"
local MOD_ROLLUP = "modifier_pangolier_rollup"
-- Jump-only (NOT the 6s armor buff — that must not fake "still rolling").
local MOD_SHIELD_JUMP = "modifier_pangolier_shield_crash_jump"

local ORDER_PREFIX = "pango.autopilot."
local ORDER_ULT = ORDER_PREFIX .. "ult"
local ORDER_BLINK = ORDER_PREFIX .. "blink"
local ORDER_MOVE = ORDER_PREFIX .. "move"
local ORDER_FACE = ORDER_PREFIX .. "face"
local ORDER_SHIELD = ORDER_PREFIX .. "shield"
local ORDER_ROLLUP = ORDER_PREFIX .. "rollup"
local ORDER_ROLLUP_STOP = ORDER_PREFIX .. "rollup_stop"

---Numeric / KV-tuned timings (packed to stay under Lua 200-local limit).
local C = {
    UPDATE_INTERVAL = 0.033,
    MOVE_INTERVAL = 0.05,
    MOVE_REFRESH = 0.20,
    KEY_UP_GRACE = 0.35,
    FACE_TIME_MAX = 0.055,
    ORDER_QUEUE_MAX = 1,
    CAST_DEDUP = 0.18,
    SHIELD_DEDUP = 1.25,
    PENDING_ULT_EXPIRE = 1.80,
    BLINK_CONFIRM_WINDOW = 1.25,
    BLINK_MAX_ATTEMPTS = 2,
    BLINK_LAND_DIST = 160,
    BLINK_MIN_DIST = 280,
    CHASE_BLINK_MIN_DIST = 620,
    CHASE_BLINK_AFTER_W = 0.75, -- shield jump_duration_gyroshell
    BLINK_RANGE_FALLBACK = 1200,
    BLINK_RANGE_MARGIN = 25,
    ROLLUP_DEDUP = 0.45,
    ROLLUP_PENDING = 0.60,
    ROLLUP_FACE_DOT = 0.42,
    ROLLUP_FACE_TIME = 0.06,
    ROLLUP_MAX_HOLD = 2.05,
    ROLLUP_BAD_FACE = 0.20,
    ROLLUP_STOP_DEDUP = 0.10,
    FACE_NUDGE = 100,
    FACE_RESEND = 0.12,
    DEFAULT_SEARCH_RANGE = 1400,
    DEFAULT_BALL_SPEED = 550,
    DEFAULT_HIT_RADIUS = 150,
    DEFAULT_STUN = 1.2,
    DEFAULT_BOUNCE_DURATION = 0.4,
    DEFAULT_RAMP_UP = 1.0,
    DEFAULT_JUMP_RECOVER = 0.25,
    DEFAULT_JUMP_GYRO = 0.75,
    DEFAULT_ROLLUP_DURATION = 2.25,
    DEFAULT_SHIELD_RADIUS = 500,
    DEFAULT_JUMP_HORIZONTAL = 225,
    TURN_DIRECT_DOT = 0.38,
    TURN_BOUNCE_DOT = 0.10,
    WALL_SCAN_MIN = 100,
    -- Closer walls still smash-turn; ball is often already on them.
    WALL_SCAN_NEAR = 48,
    WALL_SCAN_MAX = 720,
    WALL_SCAN_STEP = 32,
    WALL_RAYS = 28,
    CLIFF_DROP = 42,
    CLIFF_RISE = 55,
    STUN_ARRIVE_SLACK = 0.18,
    STUN_REHIT_BLINK_MIN = 0.12,
    STUN_REHIT_BLINK_MAX = 0.55,
    ROLL_LOST_GRACE = 1.10,
    SHIELD_JUMP_GRACE = 0.80,
    SHIELD_WALL_BLOCK_DIST = 180,
    SHIELD_MAX_PER_ROLL = 3,
    SHIELD_COMBAT_MAX = 1,
    BOUNCE_MIN_SCORE = -0.15,
    -- Prefer wall bounce over straight chase unless already this aligned to the target.
    BOUNCE_CHASE_DOT = 0.90,
    -- Wall must clearly improve facing — no obligatory smash.
    BOUNCE_IMPROVE = 0.22,
    BOUNCE_MIN_AFTER = 0.30,
    -- Only "hard turn" below this; above it chase/Roll Up are fine.
    BOUNCE_TURN_FACE = 0.15,
    BOUNCE_HARD_FACE = -0.35,
    WALL_COMMIT = 0.55,
    WALL_COMMIT_FAR = 0.35,
    -- After roll start / blink: hunt walls before Roll Up / chase-blink.
    ROLLUP_WALL_HUNT = 0.45,
    BLINK_WALL_HUNT = 0.40,
    DECIDE_LOG = 0.22,
    -- Tight pocket only — trees near a single wall used to fake "corners".
    CORNER_WALL_RADIUS = 175,
    CORNER_WALL_MIN = 3,
    CORNER_WALL_HARD = 4,
    GRID_FLAG = 0x1,
    GRID_EXCLUDED = 0x002,
    ICON_SIZE = 28,
    LINE_SEGMENTS = 18,
    MARKER_Z = 70,
    DRAW_ARC_HEIGHT = 90,
}

-- From npc_abilities: rollup cast 0.1 / tooltip 0.5, duration 2.25, turn_rate 275.
-- From npc_abilities pangolier_gyroshell / rollup / shield_crash.
local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local SPELL_ICON = "panorama/images/spellicons/pangolier_gyroshell_png.vtex_c"
local SHIELD_ICON = "panorama/images/spellicons/pangolier_shield_crash_png.vtex_c"
local ROLLUP_ICON = "panorama/images/spellicons/pangolier_rollup_png.vtex_c"
local BLINK_ICON = "panorama/images/items/blink_png.vtex_c"

local Icons = {
    enable = "\u{f00c}",
    bind = "\u{e1c1}",
    debug = "\u{f188}",
    search = "\u{f002}",
    draw = "\u{f06e}",
}

local Theme = {
    line = Color(236, 214, 168, 210),
    lineSoft = Color(236, 214, 168, 70),
    accent = Color(255, 186, 92, 230),
    ring = Color(255, 255, 255, 55),
    iconBg = Color(12, 12, 16, 170),
    text = Color(240, 232, 214, 220),
}

local STAGE = {
    IDLE = "idle",
    FACE = "face",
    CAST_ULT = "cast_ult",
    BLINK = "blink",
    WAIT_ROLL = "wait_roll",
    STEER = "steer",
}
--#endregion

--#region Locale
local Locale = {
    group_name = {
        en = "Rolling Thunder",
        ru = "Rolling Thunder",
        cn = "滚动雷霆",
    },
    ui_enabled = {
        en = "Enable",
        ru = "Включить",
        cn = "启用",
    },
    ui_key = {
        en = "AutoPilot Key",
        ru = "Клавиша AutoPilot",
        cn = "自动驾驶按键",
    },
    ui_use_blink = {
        en = "Use Blink",
        ru = "Использовать Blink",
        cn = "使用闪烁匕首",
    },
    ui_use_shield = {
        en = "Use Shield Crash",
        ru = "Использовать Shield Crash",
        cn = "使用护盾猛击",
    },
    ui_use_rollup = {
        en = "Use Roll Up",
        ru = "Использовать Roll Up",
        cn = "使用卷起",
    },
    ui_search = {
        en = "Cursor Priority",
        ru = "Приоритет курсора",
        cn = "光标优先半径",
    },
    ui_debug = {
        en = "Debug logs",
        ru = "Debug логи",
        cn = "调试日志",
    },
    ui_draw = {
        en = "Draw Overlay",
        ru = "Оверлей",
        cn = "显示叠加层",
    },
    tip_enabled = {
        en = "Master switch for Pangolier Rolling Thunder AutoPilot.",
        ru = "Главный переключатель AutoPilot Rolling Thunder у Pangolier.",
        cn = "Pangolier 滚动雷霆自动驾驶总开关。",
    },
    tip_key = {
        en = "Hold to cast Gyroshell (optional blink onto target), then steer with wall/cliff bounces.",
        ru = "Удерживай: каст Gyroshell (опционально блинк на цель), затем руление с отскоками от стен/клифов.",
        cn = "按住：施放滚动雷霆（可选闪到目标旁），随后用墙/悬崖反弹操控。",
    },
    tip_use_blink = {
        en = "During Gyroshell cast point, blink near the locked enemy (meta initiate).",
        ru = "Во время каста Gyroshell блинкует рядом с залоченной целью (meta initiate).",
        cn = "在滚动雷霆前摇期间闪到锁定敌人附近（标准起手）。",
    },
    tip_use_shield = {
        en = "While rolling: Shield Crash for damage when enemies are in radius, or hop only when a cliff/wall blocks the path and the target is behind it.",
        ru = "Во время ролла: Shield Crash по врагам в радиусе; hop только если на пути стена/клифф и цель за ним.",
        cn = "滚动时：范围内输出；仅当路径上有墙/悬崖且目标在其后时跳跃。",
    },
    tip_use_rollup = {
        en = "Shard Roll Up (2.25s, turn 275): pause when facing is bad, then End Roll Up as soon as aimed at the target.",
        ru = "Shard Roll Up (2.25с, turn 275): пауза при плохом facing, End Roll Up сразу как смотрим на цель.",
        cn = "魔晶卷起（2.25秒，转向275）：朝向差时暂停，对准目标后立刻结束卷起。",
    },
    tip_search = {
        en = "Cursor priority radius only. Target search itself is map-wide.",
        ru = "Только приоритет у курсора. Поиск цели — по всей карте.",
        cn = "仅影响光标优先级；目标搜索为全图。",
    },
    tip_debug = {
        en = "Write AutoPilot decisions to the script logger.",
        ru = "Писать решения AutoPilot в лог скрипта.",
        cn = "将自动驾驶决策写入脚本日志。",
    },
    tip_draw = {
        en = "Overlay: lock line, aim, nearest wall, stun left, hop/aim reason while rolling.",
        ru = "Оверлей: линия лока, aim, ближайшая стена, оставшийся стан, причина hop/aim в ролле.",
        cn = "叠加层：锁定线、瞄准点、最近墙、眩晕剩余、跳跃/瞄准原因。",
    },
}

local LangState = {
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    callbackSet = false,
}

local MenuNodes = {
    ---@type CSecondTab|nil
    hero = nil,
    ---@type CThirdTab|nil
    tab = nil,
    ---@type CMenuGroup|nil
    group = nil,
}
--#endregion

--#region State
---@class PangolierAutoPilotUI
---@field enabled CMenuSwitch|nil
---@field key CMenuBind|nil
---@field useBlink CMenuSwitch|nil
---@field useShield CMenuSwitch|nil
---@field useRollUp CMenuSwitch|nil
---@field searchRange CMenuSliderInt|CMenuSliderFloat|nil
---@field debug CMenuSwitch|nil
---@field drawOverlay CMenuSwitch|nil
---@field callbacksAttached boolean
local UI = {
    enabled = nil,
    key = nil,
    useBlink = nil,
    useShield = nil,
    useRollUp = nil,
    searchRange = nil,
    debug = nil,
    drawOverlay = nil,
    callbacksAttached = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|userdata|nil
    font = nil,
    ---@type table<string, integer|userdata|false>
    heroIcons = {},
}

local Runtime = {
    lastUpdateAt = -math.huge,
    lastMoveAt = -math.huge,
    lastDebugAt = -math.huge,
    lastUltIssueAt = -math.huge,
    lastBlinkIssueAt = -math.huge,
    ---@type userdata|nil
    lockedTarget = nil,
    ---@type Vector|nil
    lastTargetPos = nil,
    ---@type number|nil
    keyUpAt = nil,
    stage = STAGE.IDLE,
    ---@type number|nil
    stageStartedAt = nil,
    ---@type Vector|nil
    lastAimPos = nil,
    pendingUltAt = nil,
    pendingBlinkAt = nil,
    ---@type number|nil
    blinkCdBefore = nil,
    ---@type Vector|nil
    blinkOrigin = nil,
    blinkUsed = false,
    blinkConfirmed = false,
    blinkAttempts = 0,
    ultIssued = false,
    rollSeen = false,
    ---@type number|nil
    rollLostAt = nil,
    lastShieldAt = -math.huge,
    ---@type number
    shieldJumpUntil = -math.huge,
    shieldCastsThisRoll = 0,
    shieldCombatCasts = 0,
    lastRollUpAt = -math.huge,
    lastRollUpStopAt = -math.huge,
    ---@type number|nil
    rollUpStartedAt = nil,
    ---@type number|nil
    rollStartedAt = nil,
    lastRicochetAt = -math.huge,
    ---@type number
    wallCommitUntil = -math.huge,
    ---@type Vector|nil
    wallCommitPos = nil,
    wallCommitMinDist = math.huge,
    lastBlinkConfirmAt = -math.huge,
    ---@type string|nil
    lastDecideKey = nil,
    lastDecideAt = -math.huge,
    ---@type Vector|nil
    lastWallPos = nil,
    ---@type string|nil
    aimReason = nil,
    ---@type string|nil
    hopReason = nil,
    ---@type number|nil
    stunLeft = nil,
    draw = {
        active = false,
        ---@type Vector|nil
        mePos = nil,
        ---@type Vector|nil
        targetPos = nil,
        ---@type Vector|nil
        aimPos = nil,
        ---@type Vector|nil
        wallPos = nil,
        ---@type string|nil
        targetName = nil,
        ---@type string|nil
        stageLabel = nil,
        ---@type string|nil
        debugText = nil,
        rolling = false,
    },
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

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastMoveAt = -math.huge
    Runtime.lastDebugAt = -math.huge
    Runtime.lastUltIssueAt = -math.huge
    Runtime.lastBlinkIssueAt = -math.huge
    Runtime.lockedTarget = nil
    Runtime.lastTargetPos = nil
    Runtime.keyUpAt = nil
    Runtime.stage = STAGE.IDLE
    Runtime.stageStartedAt = nil
    Runtime.lastAimPos = nil
    Runtime.pendingUltAt = nil
    Runtime.pendingBlinkAt = nil
    Runtime.blinkCdBefore = nil
    Runtime.blinkOrigin = nil
    Runtime.blinkUsed = false
    Runtime.blinkConfirmed = false
    Runtime.blinkAttempts = 0
    Runtime.ultIssued = false
    Runtime.rollSeen = false
    Runtime.rollLostAt = nil
    Runtime.lastShieldAt = -math.huge
    Runtime.shieldJumpUntil = -math.huge
    Runtime.shieldCastsThisRoll = 0
    Runtime.shieldCombatCasts = 0
    Runtime.lastRollUpAt = -math.huge
    Runtime.lastRollUpStopAt = -math.huge
    Runtime.rollUpStartedAt = nil
    Runtime.rollStartedAt = nil
    Runtime.lastRicochetAt = -math.huge
    Runtime.wallCommitUntil = -math.huge
    Runtime.wallCommitPos = nil
    Runtime.wallCommitMinDist = math.huge
    Runtime.lastBlinkConfirmAt = -math.huge
    Runtime.lastDecideKey = nil
    Runtime.lastDecideAt = -math.huge
    Runtime.lastWallPos = nil
    Runtime.aimReason = nil
    Runtime.hopReason = nil
    Runtime.stunLeft = nil
    Runtime.draw.active = false
    Runtime.draw.mePos = nil
    Runtime.draw.targetPos = nil
    Runtime.draw.aimPos = nil
    Runtime.draw.wallPos = nil
    Runtime.draw.targetName = nil
    Runtime.draw.stageLabel = nil
    Runtime.draw.debugText = nil
    Runtime.draw.rolling = false
end

-- Some Umbrella builds expose Config without ReadInt/WriteInt; fall back to defaults.
local function ReadBool(key, default)
    local fallback = default and 1 or 0
    if not Config or type(Config.ReadInt) ~= "function" then
        return default and true or false
    end
    local ok, value = TryCall(Config.ReadInt, CONFIG_SECTION, key, fallback)
    if not ok or type(value) ~= "number" then
        return default and true or false
    end
    return value ~= 0
end

local function WriteBool(key, value)
    if not Config or type(Config.WriteInt) ~= "function" then
        return
    end
    TryCall(Config.WriteInt, CONFIG_SECTION, key, value and 1 or 0)
end

local function ReadInt(key, default)
    if not Config or type(Config.ReadInt) ~= "function" then
        return default
    end
    local ok, value = TryCall(Config.ReadInt, CONFIG_SECTION, key, default)
    if not ok or type(value) ~= "number" then
        return default
    end
    return value
end

local function WriteInt(key, value)
    if not Config or type(Config.WriteInt) ~= "function" then
        return
    end
    TryCall(Config.WriteInt, CONFIG_SECTION, key, value)
end

local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function Normalize2D(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-4 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

local function Dot2D(ax, ay, bx, by)
    return ax * bx + ay * by
end

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
        or value:find("中文", 1, true) then
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

local function MenuIcon(widget, icon)
    if not widget or not icon or not widget.Icon then
        return
    end
    local ok = pcall(widget.Icon, widget, icon)
    if not ok then
        pcall(widget.Icon, icon)
    end
end

local function MenuImage(widget, imagePath)
    if widget and widget.Image and imagePath then
        widget:Image(imagePath)
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
    MenuLabel(UI.enabled, "ui_enabled")
    MenuTip(UI.enabled, "tip_enabled")
    MenuLabel(UI.key, "ui_key")
    MenuTip(UI.key, "tip_key")
    MenuLabel(UI.useBlink, "ui_use_blink")
    MenuTip(UI.useBlink, "tip_use_blink")
    MenuLabel(UI.useShield, "ui_use_shield")
    MenuTip(UI.useShield, "tip_use_shield")
    MenuLabel(UI.useRollUp, "ui_use_rollup")
    MenuTip(UI.useRollUp, "tip_use_rollup")
    MenuLabel(UI.searchRange, "ui_search")
    MenuTip(UI.searchRange, "tip_search")
    MenuLabel(UI.debug, "ui_debug")
    MenuTip(UI.debug, "tip_debug")
    MenuLabel(UI.drawOverlay, "ui_draw")
    MenuTip(UI.drawOverlay, "tip_draw")
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

local function Dbg(fmt, ...)
    if not UI.debug or UI.debug:Get() ~= true or not Persistent.logger then
        return
    end
    Runtime.lastDebugAt = SafeValue(GameRules.GetGameTime) or 0
    Persistent.logger:info(string.format(fmt, ...))
end

---Throttled decision log (why we pick wall / skip rollup / skip blink / chase).
---@param now number
---@param key string
---@param fmt string
---@param ... any
local function DbgDecide(now, key, fmt, ...)
    if not UI.debug or UI.debug:Get() ~= true or not Persistent.logger then
        return
    end
    if Runtime.lastDecideKey == key and (now - (Runtime.lastDecideAt or -math.huge)) < C.DECIDE_LOG then
        return
    end
    Runtime.lastDecideKey = key
    Runtime.lastDecideAt = now
    Persistent.logger:info(string.format(fmt, ...))
end

---@param reason string|nil
---@return boolean
local function IsWallAimReason(reason)
    return reason == "turn_bounce"
        or reason == "bounce"
        or reason == "ramp_bounce"
        or reason == "stun_bounce"
        or reason == "wall_commit"
end

local function SetStage(stage, now)
    if Runtime.stage ~= stage then
        Runtime.stage = stage
        Runtime.stageStartedAt = now
        Dbg("stage=%s", stage)
    end
end

local function IsOurOrder(identifier)
    return type(identifier) == "string" and identifier:sub(1, #ORDER_PREFIX) == ORDER_PREFIX
end

---@return integer
local function GetOrderQueueCount()
    local queue = SafeValue(Humanizer.GetOrderQueue)
    if type(queue) ~= "table" then
        return 0
    end
    return #queue
end

---@param me userdata
---@return boolean
local function CanSendOrder(me)
    if GetOrderQueueCount() > C.ORDER_QUEUE_MAX then
        return false
    end
    if SafeValue(NPC.IsStunned, me) == true then
        return false
    end
    return true
end

---@param unit userdata|nil
---@return boolean
local function IsAliveUnit(unit)
    return unit ~= nil and SafeValue(Entity.IsAlive, unit) == true
end

---@param unit userdata|nil
---@param me userdata
---@return boolean
local function IsEnemyUnit(unit, me)
    if not IsAliveUnit(unit) or unit == me then
        return false
    end
    if SafeValue(NPC.IsIllusion, unit) == true then
        return false
    end
    local myTeam = SafeValue(Entity.GetTeamNum, me)
    local theirTeam = SafeValue(Entity.GetTeamNum, unit)
    if myTeam == nil or theirTeam == nil or myTeam == theirTeam then
        return false
    end
    return true
end

---@param unit userdata|nil
---@param me userdata
---@return boolean
local function IsValidEnemy(unit, me)
    if not IsEnemyUnit(unit, me) then
        return false
    end
    if SafeValue(Entity.IsDormant, unit) == true then
        return false
    end
    if SafeValue(NPC.IsVisible, unit) == false then
        return false
    end
    local states = Enum.modifierState
    if states and SafeValue(NPC.HasState, unit, states.MODIFIER_STATE_INVULNERABLE) == true then
        return false
    end
    if Humanizer and Humanizer.IsSafeTarget then
        local ok, safe = TryCall(Humanizer.IsSafeTarget, unit)
        if ok and safe == false then
            return false
        end
    end
    return true
end

---Keep chase lock through brief FOW while the ball is active.
---@param unit userdata|nil
---@param me userdata
---@return boolean
local function IsKeepableRollTarget(unit, me)
    return IsEnemyUnit(unit, me)
end

---@param me userdata
---@return boolean
local function HasGyroshell(me)
    return SafeValue(NPC.HasModifier, me, MOD_GYROSHELL) == true
        or SafeValue(NPC.HasModifier, me, MOD_RICOCHET) == true
end

---@param me userdata
---@return boolean
local function HasShieldJump(me)
    return SafeValue(NPC.HasModifier, me, MOD_SHIELD_JUMP) == true
end

---@param me userdata
---@return boolean
local function HasRollUp(me)
    return SafeValue(NPC.HasModifier, me, MOD_ROLLUP) == true
end

---@param me userdata
---@param now number|nil
---@return boolean
local function IsRolling(me, now)
    if HasGyroshell(me) then
        return true
    end
    if HasRollUp(me) then
        return true
    end
    -- Jump motion only (not the 6s armor buff).
    if HasShieldJump(me) then
        return true
    end
    now = now or SafeValue(GameRules.GetGameTime) or 0
    -- Tiny grace right after W while gyroshell may flicker, only before rollLostAt.
    if Runtime.rollSeen and not Runtime.rollLostAt and now < (Runtime.shieldJumpUntil or -math.huge) then
        return true
    end
    return false
end

---@param me userdata
---@return boolean
local function IsRicocheting(me)
    return SafeValue(NPC.HasModifier, me, MOD_RICOCHET) == true
end

---@param ability userdata|nil
---@param name string
---@param fallback number
---@return number
local function ReadSpecial(ability, name, fallback)
    if not ability then
        return fallback
    end
    local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, name)
    if type(value) == "number" and value > 0 then
        return value
    end
    return fallback
end

---@param me userdata
---@return userdata|nil
local function GetGyroshell(me)
    ---@type userdata|nil
    local ability = SafeValue(NPC.GetAbility, me, ABILITY_GYROSHELL)
    return ability
end

---@param me userdata
---@return userdata|nil, string|nil
local function GetBlink(me)
    for i = 1, #BLINK_ITEMS do
        local name = BLINK_ITEMS[i]
        ---@type userdata|nil
        local item = SafeValue(NPC.GetItem, me, name, true)
        if item then
            return item, name
        end
    end
    return nil, nil
end

---@param me userdata
---@param ability userdata
---@return boolean
local function IsAbilityCastable(me, ability)
    local mana = SafeValue(NPC.GetMana, me) or 0
    return SafeValue(Ability.IsCastable, ability, mana) == true
end

---@param pos Vector|nil
---@return boolean
local function IsWorldTraversable(pos)
    if not pos or not GridNav or not GridNav.IsTraversable then
        return true
    end
    local ok, result = TryCall(GridNav.IsTraversable, pos, C.GRID_FLAG, C.GRID_EXCLUDED)
    if ok then
        return result == true
    end
    return true
end

---Gyroshell breaks trees and does not bounce on them. ignoreTrees=true.
---@param from Vector|nil
---@param to Vector|nil
---@return boolean
local function IsBallPathClear(from, to)
    if not from or not to then
        return false
    end
    if GridNav and GridNav.IsTraversableFromTo then
        local ok, result = TryCall(GridNav.IsTraversableFromTo, from, to, true, nil)
        if ok then
            return result == true
        end
    end
    return IsWorldTraversable(to)
end

---@param from Vector|nil
---@param to Vector|nil
---@return boolean
local function IsPathClear(from, to)
    if not from or not to then
        return false
    end
    if GridNav and GridNav.IsTraversableFromTo then
        local ok, result = TryCall(GridNav.IsTraversableFromTo, from, to, false, nil)
        if ok then
            return result == true
        end
    end
    return IsWorldTraversable(to)
end

---@param from Vector
---@param to Vector
---@return boolean
local function IsBlinkPositionTraversable(from, to)
    return IsPathClear(from, to) and IsWorldTraversable(to)
end

---True only for hard walls/cliffs. Tree-only blocks are ignored.
---@param from Vector
---@param to Vector
---@param fromZ number
---@param toZ number
---@return boolean isHard
---@return boolean isCliff
local function IsHardBounceSurface(from, to, fromZ, toZ)
    local cliffDrop = (fromZ - toZ) >= C.CLIFF_DROP
    local cliffRise = (toZ - fromZ) >= C.CLIFF_RISE
    if cliffDrop or cliffRise then
        return true, true
    end
    -- Open for the ball (trees ignored) => not a bounce surface.
    if IsBallPathClear(from, to) then
        return false, false
    end
    return true, false
end

---@param me userdata
---@return number, number, number
local function GetForward2D(me)
    local rot = SafeValue(Entity.GetRotation, me)
    if rot and rot.GetForward then
        local forward = rot:GetForward()
        if forward then
            local fx, fy, len = Normalize2D(forward.x, forward.y)
            if len > 0 then
                return fx, fy, len
            end
        end
    end
    local tip = SafeValue(Entity.GetForwardPosition, me, 100)
    local origin = SafeValue(Entity.GetAbsOrigin, me)
    if tip and origin then
        return Normalize2D(tip.x - origin.x, tip.y - origin.y)
    end
    return 1, 0, 1
end

---@param me userdata
---@param pos Vector
---@return number
local function GetFacingDot(me, pos)
    local origin = SafeValue(Entity.GetAbsOrigin, me)
    if not origin then
        return 0
    end
    local tx, ty, tlen = Normalize2D(pos.x - origin.x, pos.y - origin.y)
    if tlen <= 0 then
        return 1
    end
    local fx, fy = GetForward2D(me)
    return Dot2D(fx, fy, tx, ty)
end

---@param target userdata
---@param lead number
---@return Vector|nil
local function PredictPosition(target, lead)
    ---@type Vector|nil
    local pos = SafeValue(Entity.GetAbsOrigin, target)
    if not pos then
        return nil
    end
    if lead <= 0 or SafeValue(NPC.IsRunning, target) ~= true then
        return pos
    end
    if SafeValue(NPC.IsStunned, target) == true then
        return pos
    end
    local speed = SafeValue(NPC.GetMoveSpeed, target) or 0
    if type(speed) ~= "number" or speed <= 1 then
        return pos
    end
    ---@type Vector|nil
    local tip = SafeValue(Entity.GetForwardPosition, target, speed * lead)
    if tip then
        return tip
    end
    return pos
end

---@param target userdata
---@param now number
---@return number|nil remaining
local function GetGyroStunRemaining(target, now)
    local mod = SafeValue(NPC.GetModifier, target, MOD_STUNNED)
    if not mod then
        return nil
    end
    local die = SafeValue(Modifier.GetDieTime, mod)
    if type(die) ~= "number" then
        return nil
    end
    return math.max(0, die - now)
end

---@return number
local function GetSearchRange()
    local value = UI.searchRange and UI.searchRange:Get() or C.DEFAULT_SEARCH_RANGE
    if type(value) ~= "number" then
        return C.DEFAULT_SEARCH_RANGE
    end
    return value
end

---@return boolean
local function IsKeyHeld()
    return UI.key ~= nil and UI.key.IsDown and SafeValue(UI.key.IsDown, UI.key) == true
end

---@return boolean
local function IsUseBlinkEnabled()
    return UI.useBlink ~= nil and UI.useBlink:Get() == true
end

---@return boolean
local function IsUseShieldEnabled()
    return UI.useShield ~= nil and UI.useShield:Get() == true
end

---@return boolean
local function IsUseRollUpEnabled()
    return UI.useRollUp ~= nil and UI.useRollUp:Get() == true
end

---@param me userdata
---@param now number
local function NoteRollingState(me, now)
    if HasGyroshell(me) then
        if not Runtime.rollSeen then
            Runtime.shieldCastsThisRoll = 0
            Runtime.shieldCombatCasts = 0
            Runtime.rollStartedAt = now
        end
        Runtime.rollSeen = true
        Runtime.rollLostAt = nil
        if IsRicocheting(me) then
            Runtime.lastRicochetAt = now
        end
        if Runtime.blinkUsed and not Runtime.blinkConfirmed then
            Runtime.blinkConfirmed = true
            Runtime.pendingBlinkAt = nil
            Runtime.lastBlinkConfirmAt = now
            Dbg("blink confirmed by rolling")
        end
        return
    end

    -- W jump / Roll Up can flicker gyroshell off — do not treat that as roll end.
    if HasRollUp(me)
        or HasShieldJump(me)
        or (Runtime.rollUpStartedAt and now - Runtime.rollUpStartedAt < C.ROLLUP_PENDING)
        or (Runtime.rollSeen and now < (Runtime.shieldJumpUntil or -math.huge))
    then
        return
    end

    -- Ball ended: clear jump grace so shield buff cannot fake an active roll.
    if Runtime.rollSeen and not Runtime.rollLostAt then
        Runtime.rollLostAt = now
        Runtime.shieldJumpUntil = -math.huge
        Runtime.ultIssued = false
        Runtime.blinkUsed = false
        Runtime.blinkConfirmed = false
        Runtime.blinkAttempts = 0
        Runtime.pendingUltAt = nil
        Runtime.pendingBlinkAt = nil
        Dbg("roll ended")
    end
end

---@param now number
---@param me userdata
---@param ability userdata|nil
---@return boolean
local function CanStartNewUlt(now, me, ability)
    if Runtime.ultIssued then
        return false
    end
    if HasGyroshell(me) or HasShieldJump(me) then
        return false
    end
    if ability and SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return false
    end
    -- Brief pause after ball ends — shield armor buff must not extend this.
    if Runtime.rollLostAt and now - Runtime.rollLostAt < C.ROLL_LOST_GRACE then
        return false
    end
    if not ability or not IsAbilityCastable(me, ability) then
        return false
    end
    return true
end
--#endregion

--#region Menu
---@param node CThirdTab|CMenuGroup|nil
local function EnsureMenuVisible(node)
    if node and node.Visible then
        node:Visible(true)
    end
end

---@param heroTab CSecondTab|nil
local function ApplyHeroTabIcon(heroTab)
    if not heroTab then
        return
    end
    heroTab:Image(HERO_ICON)
    local heroId = Engine.GetHeroIDByName(HERO_NAME)
    if heroId then
        heroTab:LinkHero(heroId, Enum.Attributes.DOTA_ATTRIBUTE_AGILITY)
    end
end

---@return CSecondTab|nil
local function FindOrCreateHeroTab()
    if MenuNodes.hero then
        return MenuNodes.hero
    end

    local heroList = Menu.Find(MENU_FIRST, MENU_SECTION)
    if not heroList then
        return nil
    end

    ---@type CSecondTab|nil
    local heroTab = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB)
    if not heroTab and heroList.Find then
        heroTab = heroList:Find(HERO_TAB)
    end
    if not heroTab and heroList.Create then
        heroTab = heroList:Create(HERO_TAB)
    end
    if not heroTab then
        heroTab = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB)
    end
    if not heroTab then
        return nil
    end

    ApplyHeroTabIcon(heroTab)
    MenuNodes.hero = heroTab
    return heroTab
end

---@return CThirdTab|nil
local function FindOrCreateAutoPilotTab()
    if MenuNodes.tab then
        EnsureMenuVisible(MenuNodes.tab)
        return MenuNodes.tab
    end

    local heroTab = FindOrCreateHeroTab()
    if not heroTab then
        return nil
    end

    ---@type CThirdTab|nil
    local tab = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD)
    if not tab and heroTab.Find then
        tab = heroTab:Find(MENU_THIRD)
    end
    if not tab and heroTab.Create then
        tab = heroTab:Create(MENU_THIRD)
    end
    if not tab then
        tab = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD)
    end
    if not tab then
        return nil
    end

    EnsureMenuVisible(tab)
    MenuNodes.tab = tab
    return tab
end

---@return CMenuGroup|nil
local function FindOrCreateGroup()
    if MenuNodes.group then
        EnsureMenuVisible(MenuNodes.group)
        return MenuNodes.group
    end

    local tab = FindOrCreateAutoPilotTab()
    if not tab then
        return nil
    end

    ---@type CMenuGroup|nil
    local group = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD, MENU_GROUP)
    if not group and tab.Find then
        group = tab:Find(MENU_GROUP)
    end
    if group then
        EnsureMenuVisible(group)
        MenuNodes.group = group
        return group
    end

    ---@type CMenuGroup|nil
    local created = nil
    if tab.Create then
        created = tab:Create(MENU_GROUP, Enum.GroupSide.Left)
    end
    if not created then
        created = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD, MENU_GROUP)
    end
    EnsureMenuVisible(created)
    MenuNodes.group = created
    return created
end

local function EnsureMenu()
    if UI.enabled
        and UI.key
        and UI.useBlink
        and UI.useShield
        and UI.useRollUp
        and UI.searchRange
        and UI.debug
        and UI.drawOverlay
        and UI.callbacksAttached
    then
        ApplyLocalization(false)
        return
    end

    local group = FindOrCreateGroup()
    if not group then
        return
    end

    if not UI.enabled then
        local existing = group:Find("Enable")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or group:Switch("Enable", ReadBool("enabled", true), Icons.enable)
    end
    MenuIcon(UI.enabled, Icons.enable)

    if not UI.key then
        local existing = group:Find("AutoPilot Key")
        ---@cast existing CMenuBind|nil
        UI.key = existing or group:Bind("AutoPilot Key", Enum.ButtonCode.KEY_NONE, Icons.bind)
        if UI.key and UI.key.Properties then
            UI.key:Properties("AutoPilot Key", "Hold", false)
        end
        if UI.key and UI.key.SetToggled then
            UI.key:SetToggled(false)
        end
    end
    MenuIcon(UI.key, Icons.bind)

    if not UI.useBlink then
        local existing = group:Find("Use Blink")
        ---@cast existing CMenuSwitch|nil
        UI.useBlink = existing or group:Switch("Use Blink", ReadBool("use_blink", true))
    end
    MenuImage(UI.useBlink, BLINK_ICON)

    if not UI.useShield then
        local existing = group:Find("Use Shield Crash")
        ---@cast existing CMenuSwitch|nil
        UI.useShield = existing or group:Switch("Use Shield Crash", ReadBool("use_shield", true))
    end
    MenuImage(UI.useShield, SHIELD_ICON)

    if not UI.useRollUp then
        local existing = group:Find("Use Roll Up")
        ---@cast existing CMenuSwitch|nil
        UI.useRollUp = existing or group:Switch("Use Roll Up", ReadBool("use_rollup", true))
    end
    MenuImage(UI.useRollUp, ROLLUP_ICON)

    if not UI.searchRange then
        local existing = group:Find("Search Range")
        ---@cast existing CMenuSliderInt|CMenuSliderFloat|nil
        local defaultRange = ReadInt("search_range", C.DEFAULT_SEARCH_RANGE)
        if defaultRange < 800 then
            defaultRange = 800
        elseif defaultRange > 2200 then
            defaultRange = 2200
        end
        UI.searchRange = existing or group:Slider("Search Range", 800, 2200, defaultRange, "%d")
    end
    MenuIcon(UI.searchRange, Icons.search)

    if not UI.debug then
        local existing = group:Find("Debug logs")
        ---@cast existing CMenuSwitch|nil
        UI.debug = existing or group:Switch("Debug logs", ReadBool("debug", false), Icons.debug)
    end
    MenuIcon(UI.debug, Icons.debug)

    if not UI.drawOverlay then
        local existing = group:Find("Draw Overlay")
        ---@cast existing CMenuSwitch|nil
        UI.drawOverlay = existing or group:Switch("Draw Overlay", ReadBool("draw_overlay", true), Icons.draw)
    end
    MenuIcon(UI.drawOverlay, Icons.draw)
    MenuImage(UI.enabled, SPELL_ICON)

    if UI.enabled and not UI.callbacksAttached then
        UI.enabled:SetCallback(function(widget)
            WriteBool("enabled", widget:Get())
            if not widget:Get() then
                ResetRuntime()
            end
        end, false)

        if UI.useBlink then
            UI.useBlink:SetCallback(function(widget)
                WriteBool("use_blink", widget:Get())
            end, false)
        end

        if UI.useShield then
            UI.useShield:SetCallback(function(widget)
                WriteBool("use_shield", widget:Get())
            end, false)
        end

        if UI.useRollUp then
            UI.useRollUp:SetCallback(function(widget)
                WriteBool("use_rollup", widget:Get())
            end, false)
        end

        if UI.searchRange then
            UI.searchRange:SetCallback(function(widget)
                WriteInt("search_range", math.floor(widget:Get() or C.DEFAULT_SEARCH_RANGE))
            end, false)
        end

        if UI.debug then
            UI.debug:SetCallback(function(widget)
                WriteBool("debug", widget:Get())
            end, false)
        end

        if UI.drawOverlay then
            UI.drawOverlay:SetCallback(function(widget)
                WriteBool("draw_overlay", widget:Get())
                if not widget:Get() then
                    Runtime.draw.active = false
                end
            end, false)
        end

        UI.callbacksAttached = true
    end

    ApplyLocalization(false)
    SetupLanguageCallback()
end
--#endregion

--#region Targeting
---@param me userdata
---@return userdata|nil
local function SelectTarget(me)
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not mePos or team == nil or not Heroes then
        return nil
    end

    local locked = Runtime.lockedTarget
    if locked and IsValidEnemy(locked, me) then
        local pos = SafeValue(Entity.GetAbsOrigin, locked)
        if pos then
            Runtime.lastTargetPos = pos
        end
        return locked
    end

    -- Keep the same hero through brief fog while rolling so steer never goes idle.
    if locked and HasGyroshell(me) and IsKeepableRollTarget(locked, me) then
        return locked
    end

    ---@type userdata[]
    local heroes = {}
    if Heroes.GetAll then
        heroes = SafeValue(Heroes.GetAll) or {}
    elseif Heroes.InRadius then
        heroes = SafeValue(
            Heroes.InRadius,
            mePos,
            30000,
            team,
            Enum.TeamType.TEAM_ENEMY,
            true,
            true
        ) or {}
    end

    local cursor = SafeValue(Input.GetWorldCursorPos)
    local cursorPriority = GetSearchRange()
    local best = nil
    local bestScore = -math.huge

    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemy(enemy, me) then
            local enemyPos = SafeValue(Entity.GetAbsOrigin, enemy)
            if enemyPos then
                local dist = Dist2D(mePos, enemyPos)
                local score = 20000 - dist
                if cursor then
                    local toCursor = Dist2D(enemyPos, cursor)
                    if toCursor < cursorPriority then
                        score = score + (cursorPriority - toCursor) * 1.25
                    end
                end
                if score > bestScore then
                    bestScore = score
                    best = enemy
                end
            end
        end
    end

    if best then
        local pos = SafeValue(Entity.GetAbsOrigin, best)
        if pos then
            Runtime.lastTargetPos = pos
        end
    end

    return best
end
--#endregion

--#region Orders
---@param me userdata
---@param ability userdata|nil
---@return boolean
local function IsUltBusy(me, ability)
    if Runtime.ultIssued or Runtime.pendingUltAt then
        return true
    end
    if ability and SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return true
    end
    return IsRolling(me)
end

---Short facing nudge — never MoveTo onto the enemy (that can trigger Swashbuckle Aim / attacks).
---@param now number
---@param me userdata
---@param targetPos Vector
---@return boolean
local function IssueFace(now, me, targetPos)
    if now - Runtime.lastMoveAt < C.FACE_RESEND then
        return false
    end
    if not CanSendOrder(me) then
        return false
    end

    local origin = SafeValue(Entity.GetAbsOrigin, me)
    if not origin then
        return false
    end

    local dx, dy, len = Normalize2D(targetPos.x - origin.x, targetPos.y - origin.y)
    if len <= 0 then
        return false
    end

    local point = Vector(origin.x + dx * C.FACE_NUDGE, origin.y + dy * C.FACE_NUDGE, origin.z)
    local player = SafeValue(Players.GetLocal)
    if player and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION then
        local ok = TryCall(
            Player.PrepareUnitOrders,
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION,
            nil,
            point,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            me,
            false,
            false,
            true,
            true,
            ORDER_FACE,
            false
        )
        if ok then
            Runtime.lastMoveAt = now
            return true
        end
    end

    local ok = TryCall(NPC.MoveTo, me, point, false, false, true, true, ORDER_FACE, false)
    if ok then
        Runtime.lastMoveAt = now
    end
    return ok == true
end

---@param me userdata
---@param pos Vector
---@param identifier string
---@return boolean
local function IssueMove(me, pos, identifier)
    if not CanSendOrder(me) then
        return false
    end
    local ok = TryCall(NPC.MoveTo, me, pos, false, false, true, true, identifier, false)
    return ok == true
end

---@param now number
---@param me userdata
---@param ability userdata
---@return boolean
local function IssueUlt(now, me, ability)
    if now - Runtime.lastUltIssueAt < C.CAST_DEDUP then
        return false
    end
    if not CanSendOrder(me) then
        return false
    end
    if not IsAbilityCastable(me, ability) then
        return false
    end
    -- queue=false, push=true, execute_fast=false — start cast without racing blink.
    local ok = TryCall(Ability.CastNoTarget, ability, false, true, false, ORDER_ULT)
    if ok then
        Runtime.lastUltIssueAt = now
        Runtime.pendingUltAt = now
        Runtime.ultIssued = true
        Runtime.blinkUsed = false
        Runtime.blinkConfirmed = false
        Runtime.blinkAttempts = 0
        Runtime.pendingBlinkAt = nil
        Runtime.rollSeen = false
        Runtime.rollLostAt = nil
        Runtime.rollStartedAt = nil
        Runtime.lastRicochetAt = -math.huge
        Runtime.wallCommitUntil = -math.huge
        Runtime.wallCommitPos = nil
        Runtime.shieldJumpUntil = -math.huge
        Runtime.shieldCastsThisRoll = 0
        Runtime.shieldCombatCasts = 0
        Runtime.lastAimPos = nil
        Dbg("cast ult")
        return true
    end
    return false
end

---@param blink userdata
---@return number
local function GetBlinkCooldown(blink)
    local cd = SafeValue(Ability.GetCooldown, blink)
    if type(cd) == "number" then
        return cd
    end
    return 0
end

---@param now number
---@param me userdata
---@param blink userdata
---@param landPos Vector
---@param chase boolean|nil
---@return boolean
local function IssueBlink(now, me, blink, landPos, chase)
    if not chase then
        if Runtime.blinkConfirmed then
            return false
        end
        if Runtime.blinkAttempts >= C.BLINK_MAX_ATTEMPTS then
            return false
        end
    elseif Runtime.blinkUsed and not Runtime.blinkConfirmed then
        -- Wait for pending initiate/chase blink confirmation first.
        return false
    end
    if Runtime.pendingBlinkAt and now - Runtime.pendingBlinkAt < C.BLINK_CONFIRM_WINDOW then
        return false
    end
    if now - Runtime.lastBlinkIssueAt < C.CAST_DEDUP then
        return false
    end
    if GetOrderQueueCount() > 0 then
        return false
    end
    if not IsAbilityCastable(me, blink) then
        return false
    end

    if chase then
        Runtime.blinkConfirmed = false
        Runtime.blinkUsed = false
        Runtime.blinkAttempts = 0
    end

    local origin = SafeValue(Entity.GetAbsOrigin, me)
    Runtime.blinkCdBefore = GetBlinkCooldown(blink)
    Runtime.blinkOrigin = origin

    -- execute_fast helps land inside cast window / while rolling.
    local ok = TryCall(Ability.CastPosition, blink, landPos, false, true, true, ORDER_BLINK, true)
    if ok then
        Runtime.lastBlinkIssueAt = now
        Runtime.pendingBlinkAt = now
        Runtime.blinkUsed = true
        Runtime.blinkAttempts = Runtime.blinkAttempts + 1
        Dbg(
            "issue blink #%d%s -> (%.0f, %.0f)",
            Runtime.blinkAttempts,
            chase and " (chase)" or "",
            landPos.x,
            landPos.y
        )
        return true
    end
    return false
end

---@param now number
---@param me userdata
---@param blink userdata|nil
---@return boolean
local function UpdateBlinkConfirm(now, me, blink)
    if not Runtime.blinkUsed or Runtime.blinkConfirmed then
        return Runtime.blinkConfirmed
    end
    if not Runtime.pendingBlinkAt then
        return false
    end

    if IsRolling(me) then
        Runtime.blinkConfirmed = true
        Runtime.pendingBlinkAt = nil
        Runtime.lastBlinkConfirmAt = now
        Dbg("blink confirmed by rolling")
        return true
    end

    local origin = SafeValue(Entity.GetAbsOrigin, me)
    if origin and Runtime.blinkOrigin and Dist2D(origin, Runtime.blinkOrigin) >= 150 then
        Runtime.blinkConfirmed = true
        Runtime.pendingBlinkAt = nil
        Runtime.lastBlinkConfirmAt = now
        Dbg("blink confirmed by teleport")
        return true
    end

    if blink then
        local cd = GetBlinkCooldown(blink)
        local before = Runtime.blinkCdBefore or 0
        if cd > before + 0.35 then
            Runtime.blinkConfirmed = true
            Runtime.pendingBlinkAt = nil
            Runtime.lastBlinkConfirmAt = now
            Dbg("blink confirmed by cooldown")
            return true
        end
        if not IsAbilityCastable(me, blink) and cd > 1 then
            Runtime.blinkConfirmed = true
            Runtime.pendingBlinkAt = nil
            Runtime.lastBlinkConfirmAt = now
            Dbg("blink confirmed by uncastable")
            return true
        end
    end

    if now - Runtime.pendingBlinkAt > C.BLINK_CONFIRM_WINDOW then
        if Runtime.blinkAttempts < C.BLINK_MAX_ATTEMPTS then
            Runtime.blinkUsed = false
            Runtime.pendingBlinkAt = nil
            Runtime.blinkCdBefore = nil
            Runtime.blinkOrigin = nil
            Dbg("blink not confirmed, retry allowed (%d/%d)", Runtime.blinkAttempts, C.BLINK_MAX_ATTEMPTS)
        else
            Runtime.blinkConfirmed = true
            Runtime.pendingBlinkAt = nil
            Runtime.lastBlinkConfirmAt = now
            Dbg("blink give up after %d attempts", Runtime.blinkAttempts)
        end
        return false
    end

    return false
end

---@param now number
---@param me userdata
---@param shield userdata
---@return boolean
local function IssueShieldCrash(now, me, shield)
    if now - Runtime.lastShieldAt < C.SHIELD_DEDUP then
        return false
    end
    if not CanSendOrder(me) then
        return false
    end
    if not IsAbilityCastable(me, shield) then
        return false
    end
    local ok = TryCall(Ability.CastNoTarget, shield, false, true, true, ORDER_SHIELD)
    if ok then
        local jumpGyro = ReadSpecial(shield, "jump_duration_gyroshell", C.DEFAULT_JUMP_GYRO)
        Runtime.lastShieldAt = now
        Runtime.shieldJumpUntil = now + jumpGyro + 0.05
        Runtime.shieldCastsThisRoll = (Runtime.shieldCastsThisRoll or 0) + 1
        Runtime.lastAimPos = nil
        Dbg("cast shield crash (%d/%d)", Runtime.shieldCastsThisRoll, C.SHIELD_MAX_PER_ROLL)
        return true
    end
    return false
end
--#endregion

--#region Initiate
---@param me userdata
---@param myPos Vector
---@param targetPos Vector
---@param blink userdata
---@return Vector|nil
local function ComputeBlinkLandPos(me, myPos, targetPos, blink)
    local dist = Dist2D(myPos, targetPos)
    if dist <= C.BLINK_MIN_DIST then
        return nil
    end

    local castRange = SafeValue(Ability.GetCastRange, blink) or 0
    castRange = castRange + (SafeValue(NPC.GetCastRangeBonus, me) or 0)
    if castRange <= 0 then
        castRange = C.BLINK_RANGE_FALLBACK
    end
    castRange = castRange - C.BLINK_RANGE_MARGIN

    local landDists = { 140, 180, 100, 220, 80, 260, C.BLINK_LAND_DIST }
    local laterals = { 0, 45, -45, 90, -90, 130, -130 }

    ---@param candidate Vector|nil
    ---@return Vector|nil
    local function AcceptLand(candidate)
        if not candidate then
            return nil
        end
        local travel = Dist2D(myPos, candidate)
        if travel < 90 or travel > castRange + 5 then
            return nil
        end
        if Dist2D(candidate, targetPos) >= dist - 45 then
            return nil
        end
        if IsBlinkPositionTraversable(myPos, candidate) then
            return candidate
        end
        for i = 1, #laterals do
            local off = laterals[i]
            local side = Vector(candidate.x + off, candidate.y, candidate.z)
            if IsBlinkPositionTraversable(myPos, side) and Dist2D(side, targetPos) < dist - 45 then
                return side
            end
            side = Vector(candidate.x, candidate.y + off, candidate.z)
            if IsBlinkPositionTraversable(myPos, side) and Dist2D(side, targetPos) < dist - 45 then
                return side
            end
        end
        return nil
    end

    for i = 1, #landDists do
        local landPos = targetPos:Extend2D(myPos, landDists[i])
        if landPos then
            local travel = Dist2D(myPos, landPos)
            if travel > castRange then
                landPos = myPos:Extend2D(landPos, castRange)
            end
            local ok = AcceptLand(landPos)
            if ok then
                return ok
            end
        end
    end

    local along = myPos:Extend2D(targetPos, math.min(castRange, dist - 120))
    return AcceptLand(along)
end

local function UpdateInitiate(now, me, ability, target)
    ---@type Vector|nil
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    ---@type Vector|nil
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not myPos or not targetPos then
        return
    end

    NoteRollingState(me, now)

    if IsRolling(me, now) then
        Runtime.pendingUltAt = nil
        SetStage(STAGE.STEER, now)
        return
    end

    if Runtime.pendingUltAt and now - Runtime.pendingUltAt > C.PENDING_ULT_EXPIRE then
        if not Runtime.rollSeen then
            Runtime.pendingUltAt = nil
            Runtime.ultIssued = false
            Dbg("ult pending expired without roll")
        end
    end

    local inPhase = SafeValue(Ability.IsInAbilityPhase, ability) == true
    if inPhase then
        Runtime.ultIssued = true
        Runtime.pendingUltAt = Runtime.pendingUltAt or now
    end

    local blink = select(1, GetBlink(me))
    UpdateBlinkConfirm(now, me, blink)

    -- After a finished roll this hold, do not instantly re-initiate (prevents flying off).
    if Runtime.rollSeen and Runtime.rollLostAt and now - Runtime.rollLostAt < C.ROLL_LOST_GRACE then
        SetStage(STAGE.WAIT_ROLL, now)
        return
    end

    -- Never face/move after ult order — that cancels cast and can proc Swashbuckle Aim.
    if CanStartNewUlt(now, me, ability) and not inPhase then
        local faceTime = SafeValue(NPC.GetTimeToFacePosition, me, targetPos) or 0
        if faceTime > C.FACE_TIME_MAX then
            SetStage(STAGE.FACE, now)
            IssueFace(now, me, targetPos)
            return
        end

        SetStage(STAGE.CAST_ULT, now)
        IssueUlt(now, me, ability)
        return
    end

    if not Runtime.ultIssued and not inPhase and not HasGyroshell(me) then
        if not IsAbilityCastable(me, ability) then
            SetStage(STAGE.IDLE, now)
            return
        end
    end

    -- Blink only inside real cast point. Early CastPosition cancels Gyroshell.
    if inPhase and IsUseBlinkEnabled() and not Runtime.blinkConfirmed then
        if blink then
            local landPos = ComputeBlinkLandPos(me, myPos, targetPos, blink)
            if landPos then
                SetStage(STAGE.BLINK, now)
                IssueBlink(now, me, blink, landPos)
                return
            end
            Dbg("blink skipped: no valid land (dist=%.0f)", Dist2D(myPos, targetPos))
        end
    end

    SetStage(STAGE.WAIT_ROLL, now)
end
--#endregion

--#region Steer / bounce
---@param origin Vector
---@param dirX number
---@param dirY number
---@param maxDist number
---@return Vector|nil hitPos
---@return number hitDist
---@return boolean isCliff
local function FindWallAlongRay(origin, dirX, dirY, maxDist)
    local prev = origin
    local prevZ = origin.z
    if World and World.GetGroundZ then
        local gz = SafeValue(World.GetGroundZ, origin.x, origin.y)
        if type(gz) == "number" then
            prevZ = gz
        end
    end

    for dist = C.WALL_SCAN_STEP, maxDist, C.WALL_SCAN_STEP do
        local sample = Vector(origin.x + dirX * dist, origin.y + dirY * dist, origin.z)
        local groundZ = sample.z
        if World and World.GetGroundZ then
            local gz = SafeValue(World.GetGroundZ, sample.x, sample.y)
            if type(gz) == "number" then
                groundZ = gz
                sample = Vector(sample.x, sample.y, gz)
            end
        end

        local hard, isCliff = IsHardBounceSurface(prev, sample, prevZ, groundZ)
        if hard then
            local back = math.max(C.WALL_SCAN_MIN * 0.7, dist - C.WALL_SCAN_STEP * 0.6)
            return Vector(origin.x + dirX * back, origin.y + dirY * back, origin.z), back, isCliff
        end
        prev = sample
        prevZ = groundZ
    end
    return nil, 0, false
end

---@param pos Vector
---@param radius number
---@return integer
local function CountHardWallsAround(pos, radius)
    local count = 0
    local samples = 8
    for i = 0, samples - 1 do
        local ang = (i / samples) * math.pi * 2
        local rx, ry = math.cos(ang), math.sin(ang)
        local hitPos, hitDist = FindWallAlongRay(pos, rx, ry, radius)
        if hitPos and hitDist > 0 and hitDist <= radius then
            count = count + 1
        end
    end
    return count
end

---True only for real pockets. Forward smash walls next to trees are allowed.
---@param hitPos Vector
---@param alignForward number
---@return boolean
local function IsHitCornerTrap(hitPos, alignForward)
    local n = CountHardWallsAround(hitPos, C.CORNER_WALL_RADIUS)
    if n >= C.CORNER_WALL_HARD then
        return true
    end
    if n < C.CORNER_WALL_MIN then
        return false
    end
    -- 3 nearby walls: still OK if we are smashing almost straight into the face.
    return alignForward < 0.48
end

---Nearest hard bounce wall in a forward cone.
---@param me userdata
---@param myPos Vector
---@param maxDist number
---@return Vector|nil hitPos
---@return number|nil hitDist
---@return number dirX
---@return number dirY
local function FindForwardBounceWall(me, myPos, maxDist)
    local fx, fy = GetForward2D(me)
    local bestPos, bestDist, bestRx, bestRy = nil, nil, fx, fy
    local offsets = { 0, 0.18, -0.18, 0.36, -0.36, 0.55, -0.55 }
    for i = 1, #offsets do
        local ang = offsets[i]
        local c, s = math.cos(ang), math.sin(ang)
        local rx = fx * c - fy * s
        local ry = fx * s + fy * c
        local hitPos, hitDist = FindWallAlongRay(myPos, rx, ry, maxDist)
        if hitPos and hitDist >= C.WALL_SCAN_NEAR and hitDist <= maxDist then
            if not bestDist or hitDist < bestDist then
                bestPos, bestDist, bestRx, bestRy = hitPos, hitDist, rx, ry
            end
        end
    end
    return bestPos, bestDist, bestRx, bestRy
end

---Distance to nearest hard bounce wall in a forward cone (nil if none).
---@param me userdata
---@param myPos Vector
---@param maxDist number
---@return number|nil
local function FindForwardBounceWallDist(me, myPos, maxDist)
    local _, hitDist = FindForwardBounceWall(me, myPos, maxDist)
    return hitDist
end

---@param me userdata
---@param myPos Vector
---@param desiredPos Vector
---@param ballSpeed number
---@return Vector|nil
---@return number score
---@return number afterDot facing toward target after the bounce reverse
---@return string|nil rejectReason why nil / -inf when no aim
local function FindBounceAim(me, myPos, desiredPos, ballSpeed)
    local dx, dy, dlen = Normalize2D(desiredPos.x - myPos.x, desiredPos.y - myPos.y)
    if dlen <= 0 then
        return nil, -math.huge, -1, "no_desired_dir"
    end

    local fx, fy = GetForward2D(me)
    local facingDot = Dot2D(fx, fy, dx, dy)
    local cornerCount = CountHardWallsAround(myPos, C.CORNER_WALL_RADIUS)
    local inCorner = cornerCount >= C.CORNER_WALL_MIN
    -- In a corner we still smash the nearest forward wall; we just skip side hunting.

    local bestPos = nil
    local bestScore = -math.huge
    local bestAfter = facingDot
    local needTurn = facingDot < C.BOUNCE_TURN_FACE
    ---@type string|nil
    local reject = inCorner and "corner_side_skip" or "no_candidate"
    local minDist = needTurn and C.WALL_SCAN_NEAR or C.WALL_SCAN_MIN

    for i = 0, C.WALL_RAYS - 1 do
        local ang = (i / C.WALL_RAYS) * math.pi * 2
        local rx, ry = math.cos(ang), math.sin(ang)
        local alignForward = Dot2D(rx, ry, fx, fy)
        -- When we need a turn, prioritize walls ahead we can actually smash into.
        -- Cornered: only almost-forward walls (avoid side trap loops).
        local alignOk = needTurn and alignForward > (inCorner and 0.55 or 0.12)
            or (not needTurn and alignForward > -0.35)
        if alignOk then
            local hitPos, hitDist, isCliff = FindWallAlongRay(myPos, rx, ry, C.WALL_SCAN_MAX)
            if hitPos and hitDist >= minDist and hitDist <= C.WALL_SCAN_MAX then
                local trapped = IsHitCornerTrap(hitPos, alignForward)
                local afterHit, afterDist = FindWallAlongRay(hitPos, -rx, -ry, 200)
                local bounceTrap = afterHit and afterDist > 0 and afterDist < 110
                if trapped then
                    reject = "hit_corner"
                elseif bounceTrap and not needTurn then
                    reject = "bounce_trap"
                elseif bounceTrap and needTurn and hitDist > 220 then
                    -- Far bounce-trap walls are useless for a turn smash.
                    reject = "bounce_trap_far"
                else
                    -- Reverse after wall hit.
                    local afterX, afterY = -rx, -ry
                    local towardDot = Dot2D(afterX, afterY, dx, dy)
                    local improve = towardDot - facingDot
                    -- Soft needTurn (already somewhat facing): do not pick walls that reverse away.
                    if needTurn and facingDot > 0.05 and towardDot < facingDot - 0.20 and towardDot < 0.15 then
                        reject = "worsens_face"
                    else
                        local travel = hitDist / math.max(1, ballSpeed)
                        local score = towardDot * 7.0 + improve * 5.0 + alignForward * 2.8 - travel * 0.15
                        if needTurn then
                            score = score + alignForward * 3.5 + 1.25
                            if towardDot > facingDot then
                                score = score + 2.0
                            end
                            -- Prefer walls that actually flip us toward the target.
                            if towardDot < -0.15 and facingDot > -0.25 then
                                score = score - 4.0
                            end
                        else
                            -- Rehit loop: reward walls that keep us on the enemy after bounce.
                            if towardDot >= 0.25 then
                                score = score + 1.4
                            end
                        end
                        if isCliff then
                            score = score + 0.15
                        end
                        if hitDist < 90 then
                            -- Close wall is fine for smash-turn.
                            if needTurn then
                                score = score + 0.35
                            else
                                score = score - 0.55
                            end
                        elseif hitDist >= 140 and hitDist <= 520 then
                            score = score + 0.85
                        end
                        if score > bestScore then
                            bestScore = score
                            bestPos = hitPos
                            bestAfter = towardDot
                            reject = nil
                        end
                    end
                end
            elseif hitPos and hitDist > 0 and hitDist < minDist then
                reject = "too_close"
            end
        end
    end

    -- Fallback: only when facing away and the forward wall would improve aim.
    if facingDot < C.BOUNCE_HARD_FACE and (not bestPos or bestScore < 4.0) then
        local hitPos, hitDist, rx, ry = FindForwardBounceWall(me, myPos, C.WALL_SCAN_MAX)
        if hitPos and hitDist then
            local towardDot = Dot2D(-rx, -ry, dx, dy)
            local allow = towardDot >= facingDot + C.BOUNCE_IMPROVE
                or (hitDist <= 260 and towardDot > facingDot + 0.10)
            if allow then
                local score = 14.0 + towardDot * 6.0 + Dot2D(rx, ry, fx, fy) * 4.0
                if hitDist <= 220 then
                    score = score + 1.5
                end
                if score > bestScore then
                    bestScore = score
                    bestPos = hitPos
                    bestAfter = towardDot
                    reject = nil
                end
            else
                reject = reject or "fwd_worsens_face"
            end
        elseif not bestPos then
            reject = reject or "no_fwd_wall"
        end
    end

    if not bestPos or bestScore < C.BOUNCE_MIN_SCORE then
        return nil, bestScore, facingDot, reject or "low_score"
    end
    return bestPos, bestScore, bestAfter, nil
end

---@param x number
---@param y number
---@param fallback number
---@return number
local function GetGroundZAt(x, y, fallback)
    if World and World.GetGroundZ then
        local gz = SafeValue(World.GetGroundZ, x, y)
        if type(gz) == "number" then
            return gz
        end
    end
    return fallback
end

---@param myPos Vector
---@param maxDist number
---@return Vector|nil
---@return number
local function FindNearestBounceWallPos(myPos, maxDist)
    local bestPos = nil
    local bestDist = math.huge
    local rays = 16
    for i = 0, rays - 1 do
        local ang = (i / rays) * math.pi * 2
        local hitPos, hitDist = FindWallAlongRay(myPos, math.cos(ang), math.sin(ang), maxDist)
        if hitPos and hitDist > 0 and hitDist < bestDist then
            bestDist = hitDist
            bestPos = hitPos
        end
    end
    return bestPos, bestDist
end

---P0: hop only if elevation differs AND a hard cliff/wall sits on the path with the target behind it.
---@param me userdata
---@param myPos Vector
---@param targetPos Vector
---@param jumpDist number
---@return boolean
---@return string|nil reason
local function NeedsTerrainHopToward(me, myPos, targetPos, jumpDist)
    local dx, dy, dlen = Normalize2D(targetPos.x - myPos.x, targetPos.y - myPos.y)
    if dlen < 140 then
        return false, nil
    end

    local myZ = GetGroundZAt(myPos.x, myPos.y, myPos.z)
    local tZ = GetGroundZAt(targetPos.x, targetPos.y, targetPos.z)
    local elevDrop = (myZ - tZ) >= C.CLIFF_DROP
    local elevRise = (tZ - myZ) >= C.CLIFF_RISE
    if not elevDrop and not elevRise then
        return false, nil
    end

    local sampleMax = math.min(jumpDist + 30, dlen * 0.82)
    local step = 32
    local prev = myPos
    local prevZ = myZ
    for dist = step, sampleMax, step do
        local x = myPos.x + dx * dist
        local y = myPos.y + dy * dist
        local gz = GetGroundZAt(x, y, prevZ)
        local sample = Vector(x, y, gz)
        local hard, isCliff = IsHardBounceSurface(prev, sample, prevZ, gz)
        if hard and dist < dlen - 50 then
            -- Target must sit past the obstacle on this path.
            local beyond = math.min(dlen, dist + 70)
            local bx = myPos.x + dx * beyond
            local by = myPos.y + dy * beyond
            local bZ = GetGroundZAt(bx, by, gz)
            if isCliff or math.abs(gz - prevZ) >= C.CLIFF_DROP then
                if elevDrop and (myZ - bZ) >= C.CLIFF_DROP * 0.6 then
                    return true, "hop_cliff_down"
                end
                if elevRise and (bZ - myZ) >= C.CLIFF_RISE * 0.6 then
                    return true, "hop_cliff_up"
                end
            elseif elevDrop or elevRise then
                return true, "hop_wall"
            end
        end
        prev = sample
        prevZ = gz
    end

    return false, nil
end

local function CountEnemiesInShieldRadius(me, myPos, radius)
    local team = SafeValue(Entity.GetTeamNum, me)
    if team == nil or not Heroes or not Heroes.InRadius then
        return 0
    end
    local heroes = SafeValue(
        Heroes.InRadius,
        myPos,
        radius,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}
    local count = 0
    for i = 1, #heroes do
        if IsValidEnemy(heroes[i], me) then
            count = count + 1
        end
    end
    return count
end

---@param now number
---@param me userdata
---@param bounceAim Vector|nil
---@return boolean
local function TryShieldCrash(now, me, bounceAim)
    if not IsUseShieldEnabled() then
        return false
    end
    -- Only while the ball is actually active.
    if not HasGyroshell(me) then
        return false
    end
    -- Never W during / right after Roll Up — steals re-aim and can cancel the ball.
    if HasRollUp(me)
        or (Runtime.rollUpStartedAt and now - Runtime.rollUpStartedAt < C.ROLLUP_PENDING)
        or (now - (Runtime.lastRollUpAt or -math.huge) < C.ROLLUP_PENDING + 0.25)
    then
        return false
    end
    if (Runtime.shieldCastsThisRoll or 0) >= C.SHIELD_MAX_PER_ROLL then
        return false
    end
    local shield = SafeValue(NPC.GetAbility, me, ABILITY_SHIELD_CRASH)
    if not shield or not IsAbilityCastable(me, shield) then
        return false
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos then
        return false
    end

    local radius = ReadSpecial(shield, "radius", C.DEFAULT_SHIELD_RADIUS)
    local jumpDist = ReadSpecial(shield, "jump_horizontal_distance", C.DEFAULT_JUMP_HORIZONTAL)

    local enemies = CountEnemiesInShieldRadius(me, myPos, radius * 0.95)
    ---@type Vector|nil
    local targetPos = nil
    local locked = Runtime.lockedTarget
    if locked and IsKeepableRollTarget(locked, me) then
        targetPos = PredictPosition(locked, 0.10)
            or SafeValue(Entity.GetAbsOrigin, locked)
            or Runtime.lastTargetPos
    end
    local needHop = false
    local hopReason = nil
    if targetPos then
        needHop, hopReason = NeedsTerrainHopToward(me, myPos, targetPos, jumpDist)
    end
    local combatOk = enemies > 0 and (Runtime.shieldCombatCasts or 0) < C.SHIELD_COMBAT_MAX

    -- Combat: one W in radius. Terrain hop: cliff/wall on path with target behind it.
    if not combatOk and not needHop then
        Runtime.hopReason = nil
        return false
    end

    -- Deep corners: jumping here still flies you into a pocket.
    if CountHardWallsAround(myPos, C.CORNER_WALL_RADIUS) >= C.CORNER_WALL_MIN then
        return false
    end

    local wallDist = FindForwardBounceWallDist(me, myPos, C.SHIELD_WALL_BLOCK_DIST + 40)
    if wallDist and wallDist <= C.SHIELD_WALL_BLOCK_DIST then
        -- Allow hop over the ledge we need; block only hard bounce walls for combat W.
        if not needHop then
            return false
        end
    end

    -- Driving into a chosen bounce aim: do not jump over it unless terrain hop is required.
    if not needHop and bounceAim and Dist2D(myPos, bounceAim) <= 360 then
        local fx, fy = GetForward2D(me)
        local ax, ay, alen = Normalize2D(bounceAim.x - myPos.x, bounceAim.y - myPos.y)
        if alen > 0 and Dot2D(fx, fy, ax, ay) > 0.15 then
            return false
        end
    end

    if not IssueShieldCrash(now, me, shield) then
        return false
    end
    if combatOk and not needHop then
        Runtime.shieldCombatCasts = (Runtime.shieldCombatCasts or 0) + 1
        Runtime.hopReason = "combat"
    else
        Runtime.hopReason = hopReason or "hop"
    end
    return true
end

---@param now number
---@param me userdata
---@param rollup userdata
---@return boolean
local function IssueRollUp(now, me, rollup)
    if now - (Runtime.lastRollUpAt or -math.huge) < C.ROLLUP_DEDUP then
        return false
    end
    if not CanSendOrder(me) then
        return false
    end
    if not IsAbilityCastable(me, rollup) then
        return false
    end
    local ok = TryCall(Ability.CastNoTarget, rollup, false, true, true, ORDER_ROLLUP)
    if ok then
        Runtime.lastRollUpAt = now
        Runtime.rollUpStartedAt = now
        Runtime.lastAimPos = nil
        Runtime.aimReason = "rollup"
        Dbg("cast roll up")
        return true
    end
    return false
end

---@param me userdata
---@param now number
---@return boolean
local function IsRollUpSession(me, now)
    if HasRollUp(me) then
        return true
    end
    local started = Runtime.rollUpStartedAt
    return started ~= nil and (now - started) < C.ROLLUP_PENDING
end

---@param now number
---@param me userdata
---@return boolean
local function IssueRollUpStop(now, me)
    if now - (Runtime.lastRollUpStopAt or -math.huge) < C.ROLLUP_STOP_DEDUP then
        return false
    end
    if not HasRollUp(me) then
        return false
    end
    local stop = SafeValue(NPC.GetAbility, me, ABILITY_ROLLUP_STOP)
    if not stop then
        Dbg("rollup stop ability missing")
        return false
    end
    if not CanSendOrder(me) then
        return false
    end
    -- Immediate end — same style as gyroshell_stop.
    local ok = TryCall(Ability.CastNoTarget, stop, false, true, true, ORDER_ROLLUP_STOP)
    if ok then
        Runtime.lastRollUpStopAt = now
        Runtime.rollUpStartedAt = nil
        Runtime.lastAimPos = nil
        Runtime.aimReason = "rollup_end"
        Dbg("stop roll up")
        return true
    end
    return false
end

---@param now number
---@param me userdata
---@param target userdata
---@return boolean
local function TryRollUp(now, me, target)
    if not IsUseRollUpEnabled() then
        return false
    end
    if not HasGyroshell(me) or IsRollUpSession(me, now) or IsRicocheting(me) then
        return false
    end
    if HasShieldJump(me) then
        return false
    end

    local rollup = SafeValue(NPC.GetAbility, me, ABILITY_ROLLUP)
    if not rollup or not IsAbilityCastable(me, rollup) then
        return false
    end

    local gyro = GetGyroshell(me)
    local bounceDur = ReadSpecial(gyro, "bounce_duration", C.DEFAULT_BOUNCE_DURATION)
    local shield = SafeValue(NPC.GetAbility, me, ABILITY_SHIELD_CRASH)
    local jumpRecover = ReadSpecial(shield, "jump_recover_time", C.DEFAULT_JUMP_RECOVER)

    -- KV jump_recover_time: no mobility tech right after W land.
    if now - (Runtime.lastShieldAt or -math.huge) < jumpRecover + 0.05 then
        return false
    end
    -- After ricochet we already get turn_rate_boosted — don't waste shard.
    if now - (Runtime.lastRicochetAt or -math.huge) < bounceDur + 0.15 then
        return false
    end
    -- Need enough gyroshell time left to re-aim and hit again.
    local gyroMod = SafeValue(NPC.GetModifier, me, MOD_GYROSHELL)
    local gyroDie = gyroMod and SafeValue(Modifier.GetDieTime, gyroMod) or nil
    if type(gyroDie) == "number" and (gyroDie - now) < 1.35 then
        return false
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = PredictPosition(target, 0.12)
        or SafeValue(Entity.GetAbsOrigin, target)
        or Runtime.lastTargetPos
    if not myPos or not targetPos then
        return false
    end

    local facingDot = GetFacingDot(me, targetPos)
    -- turn_rate 120: use Roll Up once we are clearly not facing the target.
    if facingDot >= C.ROLLUP_BAD_FACE then
        DbgDecide(now, "rollup_skip_face", "rollup skip: face=%.2f already ok enough", facingDot)
        return false
    end

    if now < (Runtime.wallCommitUntil or -math.huge) then
        DbgDecide(now, "rollup_skip_commit", "rollup skip: wall commit %.2fs left", Runtime.wallCommitUntil - now)
        return false
    end

    -- Give GridNav a moment after roll/blink before falling back to Roll Up.
    if Runtime.rollStartedAt and (now - Runtime.rollStartedAt) < C.ROLLUP_WALL_HUNT then
        DbgDecide(
            now,
            "rollup_skip_hunt",
            "rollup skip: wall hunt after roll start (%.2fs left) face=%.2f",
            C.ROLLUP_WALL_HUNT - (now - Runtime.rollStartedAt),
            facingDot
        )
        return false
    end
    if (now - (Runtime.lastBlinkConfirmAt or -math.huge)) < C.BLINK_WALL_HUNT then
        DbgDecide(
            now,
            "rollup_skip_blink_hunt",
            "rollup skip: wall hunt after blink (%.2fs left) face=%.2f",
            C.BLINK_WALL_HUNT - (now - (Runtime.lastBlinkConfirmAt or now)),
            facingDot
        )
        return false
    end

    local ballSpeed = ReadSpecial(gyro, "forward_move_speed", C.DEFAULT_BALL_SPEED)
    local bounce, bounceScore, bounceAfter = FindBounceAim(me, myPos, targetPos, ballSpeed)
    local wallDist = FindForwardBounceWallDist(me, myPos, 700)
    local bounceDist = bounce and Dist2D(myPos, bounce) or nil

    -- Wall bounce is better than Roll Up whenever a usable wall exists.
    if bounce then
        DbgDecide(
            now,
            "rollup_skip_bounce",
            "rollup skip: bounce score=%.2f after=%.2f wallDist=%s face=%.2f fwdWall=%s",
            bounceScore or 0,
            bounceAfter or -1,
            bounceDist and string.format("%.0f", bounceDist) or "nil",
            facingDot,
            wallDist and string.format("%.0f", wallDist) or "nil"
        )
        return false
    end
    if wallDist and wallDist < 650 then
        DbgDecide(
            now,
            "rollup_skip_fwd",
            "rollup skip: forward wall at %.0f (smash turn instead) face=%.2f",
            wallDist,
            facingDot
        )
        return false
    end

    if not IssueRollUp(now, me, rollup) then
        return false
    end
    DbgDecide(
        now,
        "rollup_cast",
        "rollup CAST: no usable wall face=%.2f fwdWall=%s bounceScore=%.2f aim=%s",
        facingDot,
        wallDist and string.format("%.0f", wallDist) or "nil",
        bounceScore or -99,
        Runtime.aimReason or "nil"
    )
    return true
end

---@param now number
---@param me userdata
---@param target userdata
---@return boolean handled
local function UpdateRollUpSteer(now, me, target)
    if not IsRollUpSession(me, now) then
        return false
    end

    -- Cast accepted but modifier not on yet — hold other actions, don't clear session.
    if not HasRollUp(me) then
        Runtime.aimReason = "rollup_wait"
        return true
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = PredictPosition(target, 0.10)
        or SafeValue(Entity.GetAbsOrigin, target)
        or Runtime.lastTargetPos
    if not myPos or not targetPos then
        return true
    end

    Runtime.aimReason = "rollup_face"
    Runtime.lastTargetPos = targetPos
    -- Roll Up turn_rate 275: re-issue facing every tick.
    if IssueMove(me, targetPos, ORDER_MOVE) then
        Runtime.lastMoveAt = now
        Runtime.lastAimPos = targetPos
    end

    -- End Roll Up as soon as we face the enemy (rollup_stop is IMMEDIATE).
    local facingDot = GetFacingDot(me, targetPos)
    local faceTime = SafeValue(NPC.GetTimeToFacePosition, me, targetPos)
    local faced = facingDot >= C.ROLLUP_FACE_DOT
        or (type(faceTime) == "number" and faceTime <= C.ROLLUP_FACE_TIME)
    local rollupAb = SafeValue(NPC.GetAbility, me, ABILITY_ROLLUP)
    local maxHold = ReadSpecial(rollupAb, "duration", C.DEFAULT_ROLLUP_DURATION) - 0.20
    if maxHold < 0.8 then
        maxHold = C.ROLLUP_MAX_HOLD
    end
    local held = Runtime.rollUpStartedAt and (now - Runtime.rollUpStartedAt) or 0
    if faced or held >= maxHold then
        IssueRollUpStop(now, me)
    end
    return true
end

---@param me userdata
---@param myPos Vector
---@param targetPos Vector
---@return Vector
---@return string reason
local function ComputeRicochetAim(me, myPos, targetPos)
    -- Ricochet window: hard snap to the target when possible.
    local facingDot = GetFacingDot(me, targetPos)
    if facingDot > -0.15 then
        return targetPos, "rico_target"
    end

    local wallPos = Runtime.lastWallPos
    if not wallPos then
        wallPos = select(1, FindNearestBounceWallPos(myPos, 420))
    end
    if wallPos then
        Runtime.lastWallPos = wallPos
        -- Aim back into the wall for an in-place bounce loop.
        return wallPos, "rico_loop"
    end

    return targetPos, "rico_target"
end

---@param now number
---@param me userdata
---@param target userdata
---@return boolean
local function TryBlinkDuringRoll(now, me, target)
    if not IsUseBlinkEnabled() then
        return false
    end
    if not HasGyroshell(me) or IsRicocheting(me) or IsRollUpSession(me, now) then
        return false
    end
    if HasShieldJump(me) then
        return false
    end

    local blink = select(1, GetBlink(me))
    if not blink or not IsAbilityCastable(me, blink) then
        return false
    end

    ---@type Vector|nil
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    ---@type Vector|nil
    local targetPos = PredictPosition(target, 0.12) or SafeValue(Entity.GetAbsOrigin, target)
    if not myPos or not targetPos then
        return false
    end

    local facingDot = GetFacingDot(me, targetPos)
    local dist = Dist2D(myPos, targetPos)
    local stunLeft = GetGyroStunRemaining(target, now)
    -- Meta: blink beside target as gyroshell stun is about to end for a rehit.
    local rehitBlink = stunLeft ~= nil
        and stunLeft >= C.STUN_REHIT_BLINK_MIN
        and stunLeft <= C.STUN_REHIT_BLINK_MAX
        and dist >= C.BLINK_MIN_DIST + 40

    -- Cheap exits first — avoid wall scans / log spam while already closing.
    if not rehitBlink and dist < C.CHASE_BLINK_MIN_DIST then
        return false
    end
    if not rehitBlink
        and facingDot >= C.TURN_DIRECT_DOT
        and dist < C.CHASE_BLINK_MIN_DIST + 250
    then
        return false
    end

    if now < (Runtime.wallCommitUntil or -math.huge) or IsWallAimReason(Runtime.aimReason) then
        DbgDecide(
            now,
            "blink_skip_wall",
            "blink skip: wall aim=%s commitLeft=%.2f face=%.2f (would cancel smash)",
            Runtime.aimReason or "nil",
            math.max(0, (Runtime.wallCommitUntil or 0) - now),
            facingDot
        )
        return false
    end
    -- Wall hunt after blink only when we still need a smash-turn.
    if facingDot < C.BOUNCE_TURN_FACE
        and (now - (Runtime.lastBlinkConfirmAt or -math.huge)) < C.BLINK_WALL_HUNT
    then
        DbgDecide(
            now,
            "blink_skip_hunt",
            "blink skip: wall hunt after blink (%.2fs left) face=%.2f",
            C.BLINK_WALL_HUNT - (now - (Runtime.lastBlinkConfirmAt or now)),
            facingDot
        )
        return false
    end
    if facingDot < C.BOUNCE_TURN_FACE then
        local fwdWall = FindForwardBounceWallDist(me, myPos, 700)
        local bounce = select(1, FindBounceAim(me, myPos, targetPos, C.DEFAULT_BALL_SPEED))
        DbgDecide(
            now,
            "blink_skip_turn",
            "blink skip: need turn face=%.2f fwdWall=%s bounce=%s (smash wall first)",
            facingDot,
            fwdWall and string.format("%.0f", fwdWall) or "nil",
            bounce and "yes" or "no"
        )
        return false
    end

    local shield = SafeValue(NPC.GetAbility, me, ABILITY_SHIELD_CRASH)
    local jumpGyro = ReadSpecial(shield, "jump_duration_gyroshell", C.DEFAULT_JUMP_GYRO)
    local jumpRecover = ReadSpecial(shield, "jump_recover_time", C.DEFAULT_JUMP_RECOVER)
    if now - (Runtime.lastShieldAt or -math.huge) < math.max(C.CHASE_BLINK_AFTER_W, jumpGyro, jumpRecover + 0.05) then
        DbgDecide(now, "blink_skip_w", "blink skip: recent W (recover)")
        return false
    end

    -- Don't blink while about to smack a bounce wall.
    local wallDist = FindForwardBounceWallDist(me, myPos, 650)
    if wallDist and wallDist < 560 then
        DbgDecide(now, "blink_skip_fwd", "blink skip: forward wall at %.0f face=%.2f", wallDist, facingDot)
        return false
    end

    local landPos = ComputeBlinkLandPos(me, myPos, targetPos, blink)
    if not landPos then
        DbgDecide(now, "blink_skip_land", "blink skip: no valid land dist=%.0f face=%.2f", dist, facingDot)
        return false
    end
    if Dist2D(landPos, targetPos) >= dist - 120 then
        DbgDecide(
            now,
            "blink_skip_worse",
            "blink skip: land not closer dist=%.0f landGap=%.0f",
            dist,
            Dist2D(landPos, targetPos)
        )
        return false
    end

    if not IssueBlink(now, me, blink, landPos, true) then
        return false
    end
    Runtime.lastAimPos = nil
    Runtime.wallCommitUntil = -math.huge
    Runtime.wallCommitPos = nil
    if rehitBlink then
        DbgDecide(
            now,
            "blink_chase",
            "chase blink CAST (stun rehit) left=%.2f dist=%.0f face=%.2f aimWas=%s",
            stunLeft or -1,
            dist,
            facingDot,
            Runtime.aimReason or "nil"
        )
    else
        DbgDecide(
            now,
            "blink_chase",
            "chase blink CAST (gap) dist=%.0f face=%.2f fwdWall=%s aimWas=%s",
            dist,
            facingDot,
            wallDist and string.format("%.0f", wallDist) or "nil",
            Runtime.aimReason or "nil"
        )
    end
    return true
end

---@param now number
---@param me userdata
---@param ability userdata
---@param target userdata
---@return Vector|nil
local function ComputeSteerAim(now, me, ability, target)
    ---@type Vector|nil
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not myPos then
        return nil
    end

    local ballSpeed = ReadSpecial(ability, "forward_move_speed", C.DEFAULT_BALL_SPEED)
    local hitRadius = ReadSpecial(ability, "hit_radius", C.DEFAULT_HIT_RADIUS)
    local rampUp = ReadSpecial(ability, "move_speed_ramp_up_time", C.DEFAULT_RAMP_UP)

    ---@type Vector|nil
    local targetPos = PredictPosition(target, 0.15)
    if not targetPos then
        targetPos = SafeValue(Entity.GetAbsOrigin, target)
    end
    if not targetPos then
        targetPos = Runtime.lastTargetPos
    end
    if not targetPos then
        return nil
    end
    Runtime.lastTargetPos = targetPos

    local dist = Dist2D(myPos, targetPos)
    local travel = dist / math.max(1, ballSpeed)
    local facingDot = GetFacingDot(me, targetPos)
    local inRamp = Runtime.rollStartedAt ~= nil and (now - Runtime.rollStartedAt) < rampUp

    local stunLeft = GetGyroStunRemaining(target, now)
    Runtime.stunLeft = stunLeft

    -- Always score wall bounce vs chase. Overlay wall should match what we actually drive into.
    local bounceAim, bounceScore, afterDot, bounceReject = FindBounceAim(me, myPos, targetPos, ballSpeed)
    local needTurn = facingDot < C.BOUNCE_TURN_FACE
    local fwdWallPos, fwdWall, fwdRx, fwdRy = FindForwardBounceWall(me, myPos, 700)

    -- Force a forward wall only when we are facing away and the bounce clearly helps.
    if (not bounceAim) and fwdWallPos and fwdWall and facingDot < C.BOUNCE_HARD_FACE then
        local tdx, tdy = Normalize2D(targetPos.x - myPos.x, targetPos.y - myPos.y)
        local forcedAfter = Dot2D(-fwdRx, -fwdRy, tdx, tdy)
        local okForce = forcedAfter >= facingDot + C.BOUNCE_IMPROVE
            or (fwdWall <= 260 and forcedAfter > facingDot + 0.10)
        if okForce then
            local rejectWas = bounceReject or "nil"
            bounceAim = fwdWallPos
            bounceScore = 11.0 + forcedAfter * 5.0
            afterDot = forcedAfter
            bounceReject = nil
            DbgDecide(
                now,
                "force_fwd_wall",
                "force fwd wall: dist=%.0f face=%.2f after=%.2f rejectWas=%s",
                fwdWall,
                facingDot,
                forcedAfter,
                rejectWas
            )
        end
    end

    local wallDistAim = bounceAim and Dist2D(myPos, bounceAim) or nil
    local improve = afterDot - facingDot
    local hardTurn = facingDot < C.BOUNCE_HARD_FACE
    -- Walls are optional tools, not a duty. Take them only when after-facing is clearly better.
    local bounceHelps = false
    if bounceAim and facingDot < C.BOUNCE_CHASE_DOT then
        local clearImprove = afterDot >= facingDot + C.BOUNCE_IMPROVE and afterDot >= C.BOUNCE_MIN_AFTER
        local closeSmash = hardTurn
            and wallDistAim
            and wallDistAim <= 280
            and afterDot > facingDot + 0.10
        local stunWall = stunLeft ~= nil
            and stunLeft > travel + C.STUN_ARRIVE_SLACK
            and afterDot >= facingDot + 0.15
            and afterDot >= 0.20
        local rampWall = inRamp and clearImprove
        bounceHelps = clearImprove or closeSmash or stunWall or rampWall
        if not bounceHelps then
            bounceReject = bounceReject or "wall_not_worth"
        end
    end

    local function CommitWall(aim, reason)
        local commitDist = Dist2D(myPos, aim)
        local hold = commitDist > 380 and C.WALL_COMMIT_FAR or C.WALL_COMMIT
        Runtime.lastWallPos = aim
        Runtime.wallCommitPos = aim
        Runtime.wallCommitUntil = now + hold
        Runtime.wallCommitMinDist = commitDist
        Runtime.aimReason = reason
    end

    if stunLeft and stunLeft > travel + C.STUN_ARRIVE_SLACK then
        if bounceHelps and bounceAim then
            CommitWall(bounceAim, "stun_bounce")
            DbgDecide(
                now,
                "aim_stun_bounce",
                "aim wall (stun_bounce) face=%.2f after=%.2f improve=%.2f wallDist=%s score=%.2f stunLeft=%.2f commit=%.2fs",
                facingDot,
                afterDot,
                improve,
                wallDistAim and string.format("%.0f", wallDistAim) or "nil",
                bounceScore or 0,
                stunLeft,
                math.max(0, (Runtime.wallCommitUntil or now) - now)
            )
            return bounceAim
        end
        local fx, fy = GetForward2D(me)
        local px, py = -fy, fx
        local orbit = math.max(hitRadius + 120, 220)
        Runtime.aimReason = "stun_orbit"
        DbgDecide(
            now,
            "stun_orbit",
            "stun orbit (no wall help) face=%.2f stunLeft=%.2f bounce=%s fwdWall=%s reject=%s",
            facingDot,
            stunLeft,
            bounceAim and "yes" or "no",
            fwdWall and string.format("%.0f", fwdWall) or "nil",
            bounceReject or "nil"
        )
        return Vector(
            targetPos.x + px * orbit * 0.35 + fx * 60,
            targetPos.y + py * orbit * 0.35 + fy * 60,
            targetPos.z
        )
    end

    if bounceHelps and bounceAim then
        local reason = hardTurn and "turn_bounce" or (inRamp and "ramp_bounce" or "bounce")
        CommitWall(bounceAim, reason)
        local hold = (wallDistAim and wallDistAim > 380) and C.WALL_COMMIT_FAR or C.WALL_COMMIT
        DbgDecide(
            now,
            "aim_" .. reason,
            "aim wall (%s) face=%.2f after=%.2f improve=%.2f wallDist=%s score=%.2f fwdWall=%s commit=%.2fs",
            reason,
            facingDot,
            afterDot,
            improve,
            wallDistAim and string.format("%.0f", wallDistAim) or "nil",
            bounceScore or 0,
            fwdWall and string.format("%.0f", fwdWall) or "nil",
            hold
        )
        return bounceAim
    end

    -- Keep wall marker for overlay even when we still chase (shows the option).
    if bounceAim then
        Runtime.lastWallPos = bounceAim
        local why = bounceReject or "unknown"
        if facingDot >= C.BOUNCE_CHASE_DOT then
            why = string.format("face>=chaseDot(%.2f)", C.BOUNCE_CHASE_DOT)
        elseif not needTurn and improve < C.BOUNCE_IMPROVE and afterDot <= facingDot then
            why = string.format("improve=%.2f < %.2f and after<=face", improve, C.BOUNCE_IMPROVE)
        end
        DbgDecide(
            now,
            "chase_ignore_wall",
            "chase despite wall: why=%s face=%.2f after=%.2f improve=%.2f score=%.2f wallDist=%s needTurn=%s",
            why,
            facingDot,
            afterDot,
            improve,
            bounceScore or 0,
            wallDistAim and string.format("%.0f", wallDistAim) or "nil",
            needTurn and "y" or "n"
        )
    else
        DbgDecide(
            now,
            "chase_no_wall",
            "chase: no bounce face=%.2f needTurn=%s fwdWall=%s score=%.2f reject=%s dist=%.0f",
            facingDot,
            needTurn and "y" or "n",
            fwdWall and string.format("%.0f", fwdWall) or "nil",
            bounceScore or -99,
            bounceReject or "nil",
            dist
        )
    end

    Runtime.aimReason = "chase"
    return targetPos
end

---@param now number
---@param me userdata
---@param ability userdata
---@param target userdata
local function UpdateSteer(now, me, ability, target)
    NoteRollingState(me, now)

    if not IsRolling(me, now) then
        if Runtime.rollSeen and Runtime.rollLostAt and now - Runtime.rollLostAt >= C.ROLL_LOST_GRACE then
            Runtime.ultIssued = false
            SetStage(STAGE.IDLE, now)
        else
            SetStage(STAGE.WAIT_ROLL, now)
        end
        return
    end

    SetStage(STAGE.STEER, now)

    local blink = select(1, GetBlink(me))
    UpdateBlinkConfirm(now, me, blink)

    if UpdateRollUpSteer(now, me, target) then
        return
    end

    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    ---@type Vector|nil
    local targetPos = PredictPosition(target, 0.12)
        or SafeValue(Entity.GetAbsOrigin, target)
        or Runtime.lastTargetPos

    if IsRicocheting(me) then
        Runtime.wallCommitUntil = -math.huge
        Runtime.wallCommitPos = nil
        Runtime.wallCommitMinDist = math.huge
        if myPos and targetPos then
            local aim, reason = ComputeRicochetAim(me, myPos, targetPos)
            Runtime.aimReason = reason
            if IssueMove(me, aim, ORDER_MOVE) then
                Runtime.lastMoveAt = now
                Runtime.lastAimPos = aim
            end
        end
        return
    end

    -- Hold a chosen wall long enough to actually hit it (blink/rollup used to cancel mid-approach).
    if myPos and targetPos and now < (Runtime.wallCommitUntil or -math.huge) and Runtime.wallCommitPos then
        local commitAim = Runtime.wallCommitPos
        local wallDist = Dist2D(myPos, commitAim)
        local faceNow = GetFacingDot(me, targetPos)
        local minDist = Runtime.wallCommitMinDist or wallDist
        if wallDist < minDist then
            Runtime.wallCommitMinDist = wallDist
            minDist = wallDist
        end
        -- Abort: already facing the target and the wall is still far — chase instead.
        local abortFar = faceNow >= 0.40 and wallDist > 320
        local abortFacing = faceNow >= 0.55 and wallDist > 220
        -- Already bounced: distance to the old aim jumped back up.
        if wallDist > minDist + 90 or abortFar or abortFacing then
            DbgDecide(
                now,
                "wall_commit_done",
                "wall commit cleared: %s face=%.2f dist=%.0f",
                (abortFar or abortFacing) and "prefer chase" or "bounced",
                faceNow,
                wallDist
            )
            Runtime.wallCommitUntil = -math.huge
            Runtime.wallCommitPos = nil
            Runtime.wallCommitMinDist = math.huge
        else
            local freshAim = select(
                1,
                FindBounceAim(
                    me,
                    myPos,
                    targetPos,
                    ReadSpecial(ability, "forward_move_speed", C.DEFAULT_BALL_SPEED)
                )
            )
            local refreshed = false
            if freshAim then
                local freshDist = Dist2D(myPos, freshAim)
                if freshDist <= wallDist + 80 then
                    commitAim = freshAim
                    Runtime.wallCommitPos = freshAim
                    Runtime.lastWallPos = freshAim
                    wallDist = freshDist
                    refreshed = true
                    if freshDist < (Runtime.wallCommitMinDist or math.huge) then
                        Runtime.wallCommitMinDist = freshDist
                    end
                end
            end
            Runtime.aimReason = "wall_commit"
            DbgDecide(
                now,
                "wall_commit",
                "wall commit: driving into wall, %.2fs left face=%.2f wallDist=%.0f refreshed=%s",
                Runtime.wallCommitUntil - now,
                faceNow,
                wallDist,
                refreshed and "y" or "n"
            )
            TryShieldCrash(now, me, commitAim)
            if now - Runtime.lastMoveAt >= C.MOVE_INTERVAL then
                if IssueMove(me, commitAim, ORDER_MOVE) then
                    Runtime.lastMoveAt = now
                    Runtime.lastAimPos = commitAim
                end
            end
            return
        end
    end

    -- Walls first — never Roll Up / chase-blink away from a turn bounce we can take.
    local aim = ComputeSteerAim(now, me, ability, target)

    if aim and IsWallAimReason(Runtime.aimReason) then
        TryShieldCrash(now, me, aim)
        if now - Runtime.lastMoveAt >= C.MOVE_INTERVAL then
            if IssueMove(me, aim, ORDER_MOVE) then
                Runtime.lastMoveAt = now
                Runtime.lastAimPos = aim
            end
        end
        return
    end

    if TryRollUp(now, me, target) then
        return
    end

    local blinked = TryBlinkDuringRoll(now, me, target)
    if not aim then
        aim = ComputeSteerAim(now, me, ability, target)
    end
    local shielded = TryShieldCrash(now, me, aim)

    -- Still steer this tick after W/blink — skipping MoveTo is how the ball flies off.
    if not aim then
        return
    end

    if now - Runtime.lastMoveAt < C.MOVE_INTERVAL then
        return
    end

    local facingDot = GetFacingDot(me, aim)
    local sameAim = Runtime.lastAimPos and Dist2D(Runtime.lastAimPos, aim) < 45
    local stale = (now - Runtime.lastMoveAt) >= C.MOVE_REFRESH
    -- Only suppress repeats when already facing the aim and the order is fresh.
    if sameAim and not stale and not blinked and not shielded and facingDot >= C.TURN_DIRECT_DOT then
        return
    end

    if IssueMove(me, aim, ORDER_MOVE) then
        Runtime.lastMoveAt = now
        Runtime.lastAimPos = aim
    end
end
--#endregion

--#region Update
---@param now number
---@param me userdata
local function UpdateFeature(now, me)
    local ability = GetGyroshell(me)
    if not ability then
        return
    end

    NoteRollingState(me, now)

    local blink = select(1, GetBlink(me))
    UpdateBlinkConfirm(now, me, blink)

    local target = SelectTarget(me)
    Runtime.lockedTarget = target

    if IsRolling(me, now) then
        if target then
            UpdateSteer(now, me, ability, target)
        else
            SetStage(STAGE.STEER, now)
            TryShieldCrash(now, me, nil)
        end
        return
    end

    if not target then
        if Runtime.rollSeen and Runtime.rollLostAt and now - Runtime.rollLostAt < C.ROLL_LOST_GRACE then
            SetStage(STAGE.WAIT_ROLL, now)
        else
            SetStage(STAGE.IDLE, now)
        end
        return
    end

    UpdateInitiate(now, me, ability, target)
end

---@param me userdata
local function RefreshDrawState(me)
    if not UI.drawOverlay or UI.drawOverlay:Get() ~= true then
        Runtime.draw.active = false
        return
    end

    local target = Runtime.lockedTarget
    local rolling = IsRolling(me)
    if not target or not (IsValidEnemy(target, me) or (rolling and IsKeepableRollTarget(target, me))) then
        Runtime.draw.active = false
        return
    end

    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target) or Runtime.lastTargetPos
    if not mePos or not targetPos then
        Runtime.draw.active = false
        return
    end

    local now = SafeValue(GameRules.GetGameTime) or 0
    local stageLabel = "LOCK"
    if Runtime.stage == STAGE.FACE or Runtime.stage == STAGE.CAST_ULT or Runtime.stage == STAGE.BLINK then
        stageLabel = "CAST"
    elseif Runtime.stage == STAGE.STEER or rolling then
        stageLabel = "ROLL"
    elseif Runtime.stage == STAGE.WAIT_ROLL then
        stageLabel = "WAIT"
    end

    local parts = { stageLabel }
    if Runtime.aimReason then
        parts[#parts + 1] = Runtime.aimReason
    end
    if Runtime.hopReason then
        parts[#parts + 1] = Runtime.hopReason
    end
    if Runtime.stunLeft and Runtime.stunLeft > 0 then
        parts[#parts + 1] = string.format("stun%.1f", Runtime.stunLeft)
    end

    Runtime.draw.active = true
    Runtime.draw.mePos = mePos
    Runtime.draw.targetPos = targetPos
    Runtime.draw.aimPos = Runtime.lastAimPos
    Runtime.draw.wallPos = Runtime.lastWallPos
    Runtime.draw.targetName = SafeValue(NPC.GetUnitName, target)
    Runtime.draw.stageLabel = stageLabel
    Runtime.draw.debugText = table.concat(parts, " | ")
    Runtime.draw.rolling = rolling
end
--#endregion

--#region Draw
local function IsValidHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    return type(handle) == "userdata"
end

---@param color Color
---@param alpha number
---@return Color
local function WithAlpha(color, alpha)
    return Color(color.r, color.g, color.b, math.floor(math.max(0, math.min(255, alpha))))
end

local function EnsureFont()
    if IsValidHandle(Persistent.font) then
        return Persistent.font
    end
    Persistent.font = SafeValue(Render.LoadFont, "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
        or SafeValue(Render.LoadFont, "Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
        or SafeValue(Render.LoadFont, "Arial")
    return Persistent.font
end

---@param unitName string|nil
---@return integer|userdata|nil
local function GetHeroIcon(unitName)
    if type(unitName) ~= "string" or unitName == "" then
        return nil
    end
    local cached = Persistent.heroIcons[unitName]
    if cached == false then
        return nil
    end
    if cached ~= nil and IsValidHandle(cached) then
        return cached
    end
    local path = "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c"
    local handle = SafeValue(Render.LoadImage, path)
    if IsValidHandle(handle) then
        Persistent.heroIcons[unitName] = handle
        return handle
    end
    Persistent.heroIcons[unitName] = false
    return nil
end

---@param worldPos Vector
---@return Vec2|nil
---@return boolean
local function WorldToScreenPos(worldPos)
    if not Render or not Render.WorldToScreen or not worldPos then
        return nil, false
    end
    local ok, screen, visible = TryCall(Render.WorldToScreen, worldPos)
    if not ok or (type(screen) ~= "userdata" and type(screen) ~= "table") then
        return nil, false
    end
    ---@cast screen Vec2
    if type(screen.x) ~= "number" or type(screen.y) ~= "number" then
        return nil, false
    end
    return screen, visible == true
end

---@param from Vector
---@param to Vector
---@param pulse number
local function DrawArcLine(from, to, pulse)
    local dx = to.x - from.x
    local dy = to.y - from.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 8 then
        return
    end

    local nx, ny = -dy / len, dx / len
    local arc = C.DRAW_ARC_HEIGHT * (0.85 + 0.15 * pulse)
    ---@type Vec2[]
    local points = {}
    for i = 0, C.LINE_SEGMENTS do
        local t = i / C.LINE_SEGMENTS
        local ease = t * t * (3 - 2 * t)
        local lift = math.sin(math.pi * t) * arc
        local world = Vector(
            from.x + dx * ease + nx * lift * 0.08,
            from.y + dy * ease + ny * lift * 0.08,
            from.z + (to.z - from.z) * ease + lift
        )
        local screen, visible = WorldToScreenPos(world)
        if visible and screen then
            points[#points + 1] = screen
        end
    end

    if #points < 2 then
        return
    end

    local soft = WithAlpha(Theme.lineSoft, 55 + 25 * pulse)
    local hard = WithAlpha(Theme.line, 170 + 50 * pulse)
    if Render.PolyLine then
        TryCall(Render.PolyLine, points, soft, 4.5)
        TryCall(Render.PolyLine, points, hard, 1.6)
    else
        for i = 2, #points do
            TryCall(Render.Line, points[i - 1], points[i], soft, 4.5)
            TryCall(Render.Line, points[i - 1], points[i], hard, 1.6)
        end
    end
end

---@param targetScreen Vec2
---@param iconHandle integer|userdata|nil
---@param label string|nil
---@param pulse number
---@param rolling boolean
local function DrawTargetBadge(targetScreen, iconHandle, label, pulse, rolling)
    local cx, cy = targetScreen.x, targetScreen.y - 42
    local size = C.ICON_SIZE
    local half = size * 0.5
    local accent = rolling and Theme.accent or Theme.line

    if Render.FilledCircle then
        TryCall(Render.FilledCircle, Vec2(cx, cy), half + 7, WithAlpha(Theme.iconBg, 160))
    end
    if Render.Circle then
        TryCall(Render.Circle, Vec2(cx, cy), half + 8 + pulse * 1.5, WithAlpha(Theme.ring, 40 + 30 * pulse), 1.4)
        TryCall(Render.Circle, Vec2(cx, cy), half + 3, WithAlpha(accent, 200), 1.7)
    end

    if iconHandle and Render.ImageCentered then
        TryCall(
            Render.ImageCentered,
            iconHandle,
            Vec2(cx, cy),
            Vec2(size, size),
            Color(255, 255, 255, 245),
            size * 0.5,
            Enum.DrawFlags.None
        )
    elseif iconHandle and Render.Image then
        TryCall(
            Render.Image,
            iconHandle,
            Vec2(cx - half, cy - half),
            Vec2(size, size),
            Color(255, 255, 255, 245),
            6,
            Enum.DrawFlags.None
        )
    end

    local font = EnsureFont()
    if label and IsValidHandle(font) and Render.Text then
        local fontSize = 11
        local textSize = SafeValue(Render.TextSize, font, fontSize, label)
        local tw = (textSize and textSize.x) or (#label * 6)
        local textPos = Vec2(cx - tw * 0.5, cy + half + 8)
        TryCall(Render.Text, font, fontSize, label, Vec2(textPos.x + 1, textPos.y + 1), Color(0, 0, 0, 160))
        TryCall(Render.Text, font, fontSize, label, textPos, WithAlpha(Theme.text, 230))
    end
end

---@param meScreen Vec2
---@param pulse number
---@param rolling boolean
local function DrawOriginDot(meScreen, pulse, rolling)
    local accent = rolling and Theme.accent or Theme.line
    local r = 3.2 + pulse
    if Render.FilledCircle then
        TryCall(Render.FilledCircle, meScreen, r + 3, WithAlpha(accent, 40))
        TryCall(Render.FilledCircle, meScreen, r, WithAlpha(accent, 220))
    end
    if Render.Circle then
        TryCall(Render.Circle, meScreen, r + 5, WithAlpha(Theme.ring, 90), 1.2)
    end
end

local function DrawOverlay()
    local draw = Runtime.draw
    if not draw.active or not draw.mePos or not draw.targetPos then
        return
    end

    local now = SafeValue(GameRules.GetGameTime) or 0
    local pulse = 0.5 + 0.5 * math.sin(now * 3.2)

    local meScreen, meVis = WorldToScreenPos(draw.mePos)
    local targetLift = Vector(draw.targetPos.x, draw.targetPos.y, (draw.targetPos.z or 0) + C.MARKER_Z)
    local targetScreen, targetVis = WorldToScreenPos(targetLift)

    if meVis and targetVis and meScreen and targetScreen then
        DrawArcLine(draw.mePos, targetLift, pulse)
        DrawOriginDot(meScreen, pulse, draw.rolling == true)
        local icon = GetHeroIcon(draw.targetName)
        DrawTargetBadge(targetScreen, icon, draw.stageLabel, pulse, draw.rolling == true)
    elseif targetVis and targetScreen then
        local icon = GetHeroIcon(draw.targetName)
        DrawTargetBadge(targetScreen, icon, draw.stageLabel, pulse, draw.rolling == true)
    end

    if draw.aimPos and draw.rolling and meVis then
        local aimScreen, aimVis = WorldToScreenPos(draw.aimPos)
        if aimVis and aimScreen and meScreen then
            TryCall(Render.Line, meScreen, aimScreen, WithAlpha(Theme.accent, 70), 1.1)
            if Render.FilledCircle then
                TryCall(Render.FilledCircle, aimScreen, 2.4, WithAlpha(Theme.accent, 180))
            end
        end
    end

    if draw.wallPos and draw.rolling and meVis and meScreen then
        local wallScreen, wallVis = WorldToScreenPos(draw.wallPos)
        if wallVis and wallScreen then
            TryCall(Render.Line, meScreen, wallScreen, WithAlpha(Theme.line, 90), 1.0)
            if Render.FilledCircle then
                TryCall(Render.FilledCircle, wallScreen, 3.0, WithAlpha(Theme.line, 200))
            end
        end
    end

    if draw.debugText and meVis and meScreen then
        local font = EnsureFont()
        if IsValidHandle(font) and Render.Text then
            local fontSize = 12
            local pos = Vec2(meScreen.x + 14, meScreen.y - 18)
            TryCall(Render.Text, font, fontSize, draw.debugText, Vec2(pos.x + 1, pos.y + 1), Color(0, 0, 0, 170))
            TryCall(Render.Text, font, fontSize, draw.debugText, pos, WithAlpha(Theme.text, 235))
        end
    end

    if draw.targetName and draw.targetPos and MiniMap and MiniMap.DrawHeroIcon then
        TryCall(
            MiniMap.DrawHeroIcon,
            draw.targetName,
            draw.targetPos,
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            210,
            700
        )
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    EnsureMenu()
    EnsureFont()
    Persistent.logger:info("loaded")
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end

    EnsureMenu()
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Input.IsInputCaptured() then
        return
    end

    local now = SafeValue(GameRules.GetGameTime)
    if type(now) ~= "number" then
        return
    end
    if now - Runtime.lastUpdateAt < C.UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or SafeValue(NPC.GetUnitName, me) ~= HERO_NAME then
        return
    end
    if not IsAliveUnit(me) then
        return
    end

    if IsKeyHeld() then
        Runtime.keyUpAt = nil
    else
        -- Brief debounce: a 1-frame IsDown flicker used to ResetRuntime mid-roll.
        Runtime.keyUpAt = Runtime.keyUpAt or now
        local rolling = IsRolling(me, now)
        if rolling and (now - Runtime.keyUpAt) < C.KEY_UP_GRACE then
            -- keep steering through a short key-up blip
        elseif Runtime.stage ~= STAGE.IDLE or Runtime.lockedTarget ~= nil or Runtime.draw.active then
            ResetRuntime()
            return
        else
            return
        end
    end

    UpdateFeature(now, me)
    RefreshDrawState(me)
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if not UI.drawOverlay or UI.drawOverlay:Get() ~= true then
        return
    end
    if not IsKeyHeld() then
        return
    end
    DrawOverlay()
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability)
    local identifier = type(data) == "table" and (data.identifier or data.orderIdentifier) or nil
    if IsOurOrder(identifier) then
        return true
    end

    -- Block Swashbuckle / stop during cast+roll. Shield Crash is allowed while rolling.
    if UI.enabled and UI.enabled:Get() == true and IsKeyHeld() then
        local me = Heroes.GetLocal()
        if me and SafeValue(NPC.GetUnitName, me) == HERO_NAME and ability then
            local name = SafeValue(Ability.GetName, ability)
            local gyroshell = GetGyroshell(me)
            local inPhase = gyroshell and SafeValue(Ability.IsInAbilityPhase, gyroshell) == true
            if name == ABILITY_GYROSHELL_STOP and IsUltBusy(me, gyroshell) then
                Dbg("veto gyroshell_stop")
                return false
            end
            if name == ABILITY_SWASHBUCKLE and (inPhase or Runtime.ultIssued or IsRolling(me)) then
                -- Deliberate veto: Swashbuckle cancels Gyroshell cast / fights the roll.
                Dbg("veto swashbuckle during gyroshell")
                return false
            end
            if name == ABILITY_SHIELD_CRASH and inPhase then
                -- Deliberate veto: do not interrupt cast point; W is fine after ball forms.
                Dbg("veto shield crash during cast point")
                return false
            end
        end
    end

    return true
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
