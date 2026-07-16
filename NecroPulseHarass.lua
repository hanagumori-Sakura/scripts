--[[
    Necrophos Death Pulse Harass
    Hold/Toggle bind Q with cast/projectile prediction (AoE, no facing required).
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "NecroPulseHarass"
local CONFIG_SECTION = "necro_pulse_harass"
local HERO_NAME = "npc_dota_hero_necrolyte"
local HERO_TAB = "Necrophos"
local ABILITY_NAME = "necrolyte_death_pulse"
local ORDER_PREFIX = "necro.pulse_harass."
local ORDER_CAST = ORDER_PREFIX .. "cast"
local ORDER_FOLLOW = ORDER_PREFIX .. "follow"

local MODE_HOLD = 0
local MODE_TOGGLE = 1

local UPDATE_INTERVAL = 0.033
local CAST_DEDUP = 0.28
local FOLLOW_DEDUP = 0.18
local FOLLOW_STOP_DIST = 90
local PENDING_EXPIRE = 0.85
local CHASE_BUFFER = 180
local DEFAULT_RADIUS = 500
local DEFAULT_PROJECTILE_SPEED = 400
local DEFAULT_SAFETY_MARGIN = 50
local DEFAULT_MANA_RESERVE = 15
local DEFAULT_MIN_ENEMIES = 1
local PREDICT_ITERATIONS = 8
local PREDICT_EPS = 0.015
local RING_SEGMENTS = 48
local MARKER_Z = 52

local MAGIC_IMMUNE_MODS = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
    "modifier_omniknight_guardian_angel",
    "modifier_winter_wyvern_cold_embrace",
}

local Icons = {
    enable = "\u{f00c}",
    bind = "\u{e1c1}",
    gear = "\u{f013}",
    mode = "\u{f205}",
    margin = "\u{f140}",
    mana = "\u{f0eb}",
    kill = "\u{f05b}",
    draw = "\u{f06e}",
    follow = "\u{f018}",
    enemies = "\u{f0c0}",
}

local Theme = {
    ready = Color(72, 220, 150, 220),
    wait = Color(230, 190, 80, 200),
    miss = Color(210, 95, 95, 180),
    kill = Color(90, 235, 140, 240),
    marker = Color(140, 230, 255, 235),
    outer = Color(90, 180, 160, 120),
    line = Color(120, 210, 190, 140),
    accent = Color(80, 210, 170, 255),
}
--#endregion

--#region Locale
local Locale = {
    group_name = {
        en = "Death Pulse Harass",
        ru = "Death Pulse Harass",
        cn = "死亡脉冲骚扰",
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
    ui_harass_bind = {
        en = "Harass Bind",
        ru = "Бинд хараса",
        cn = "骚扰按键",
    },
    ui_mode = {
        en = "Mode",
        ru = "Режим",
        cn = "模式",
    },
    mode_hold = {
        en = "Hold",
        ru = "Hold",
        cn = "按住",
    },
    mode_toggle = {
        en = "Toggle",
        ru = "Toggle",
        cn = "切换",
    },
    ui_follow_cursor = {
        en = "Follow Cursor",
        ru = "Следование за курсором",
        cn = "跟随光标",
    },
    ui_min_enemies = {
        en = "Min Enemies",
        ru = "Мин. врагов",
        cn = "最少敌人",
    },
    ui_safety_margin = {
        en = "Safety Margin",
        ru = "Запас к радиусу",
        cn = "安全边距",
    },
    ui_mana_reserve = {
        en = "Mana Reserve %",
        ru = "Резерв маны %",
        cn = "蓝量预留 %",
    },
    ui_kill_secure = {
        en = "Kill Secure",
        ru = "Добивание",
        cn = "击杀确认",
    },
    ui_draw_preview = {
        en = "Draw Preview",
        ru = "Превью радиуса",
        cn = "显示范围",
    },
    tip_enabled = {
        en = "Master switch for Necrophos Death Pulse harass.",
        ru = "Главный переключатель хараса Death Pulse у Necrophos.",
        cn = "Necrophos 死亡脉冲骚扰脚本总开关。",
    },
    tip_harass_bind = {
        en = "Activate according to Mode: Hold or Toggle. Casts Death Pulse when prediction keeps the target in AoE.",
        ru = "Активация по режиму Hold или Toggle. Жмёт Death Pulse, если предикт держит цель в AoE.",
        cn = "按模式激活（按住/切换）。预测目标仍在范围内时释放死亡脉冲。",
    },
    tip_mode = {
        en = "Hold: active while key is down. Toggle: press once to start, press again to stop.",
        ru = "Hold: работает пока клавиша зажата. Toggle: нажал — включил, нажал снова — выключил.",
        cn = "按住：按键按下时生效。切换：按一次开启，再按一次关闭。",
    },
    tip_follow_cursor = {
        en = "While active: move to cursor and harass enemies that enter Pulse range.",
        ru = "Пока активно: идти за курсором и харасить врагов в радиусе пульса.",
        cn = "激活时移向光标，并对进入脉冲范围的敌人进行骚扰。",
    },
    tip_min_enemies = {
        en = "Cast Death Pulse only when at least this many enemy heroes are predicted inside effective AoE.",
        ru = "Кастовать Death Pulse только если в эффективном AoE предиктом не меньше стольких вражеских героев.",
        cn = "仅当预测有效范围内敌方英雄数量达到该值时才释放死亡脉冲。",
    },
    tip_safety_margin = {
        en = "Extra inward buffer from Death Pulse AoE so edge casts do not miss while the target moves.",
        ru = "Запас внутрь от AoE Death Pulse, чтобы каст с края не промахивался из‑за движения цели.",
        cn = "死亡脉冲范围向内预留，避免目标移动导致边缘施法落空。",
    },
    tip_mana_reserve = {
        en = "Do not cast Pulse if remaining mana percent would fall below this value.",
        ru = "Не кастовать Pulse, если после каста мана % упадёт ниже порога.",
        cn = "施放后蓝量百分比若低于此值则不释放脉冲。",
    },
    tip_kill_secure = {
        en = "Prefer targets that predicted Pulse damage would finish.",
        ru = "Приоритет целям, которых оценочный урон Pulse добивает.",
        cn = "优先选择预测脉冲伤害可击杀的目标。",
    },
    tip_draw_preview = {
        en = "Draw effective Pulse radius and target marker while the script is active.",
        ru = "Рисовать эффективный радиус Pulse и маркер цели, пока скрипт активен.",
        cn = "脚本激活时绘制有效脉冲范围与目标标记。",
    },
}

local LangState = {
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    callbackSet = false,
}

local MenuNodes = {
    ---@type CMenuGroup|nil
    group = nil,
    ---@type CMenuGearAttachment|nil
    gear = nil,
}
--#endregion

--#region State
---@class NecroPulseUI
---@field enabled CMenuSwitch|nil
---@field harassBind CMenuBind|nil
---@field gear CMenuGearAttachment|nil
---@field mode CMenuComboBox|nil
---@field minEnemies CMenuSliderInt|CMenuSliderFloat|nil
---@field safetyMargin CMenuSliderInt|CMenuSliderFloat|nil
---@field manaReserve CMenuSliderInt|CMenuSliderFloat|nil
---@field killSecure CMenuSwitch|nil
---@field drawPreview CMenuSwitch|nil
---@field followCursor CMenuSwitch|nil
---@field callbacksAttached boolean
local UI = {
    enabled = nil,
    harassBind = nil,
    gear = nil,
    mode = nil,
    minEnemies = nil,
    safetyMargin = nil,
    manaReserve = nil,
    killSecure = nil,
    drawPreview = nil,
    followCursor = nil,
    callbacksAttached = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
}

---@class NecroPulsePending
---@field kind string
---@field issuedAt number
---@field cooldownBefore number
---@field ability userdata

---@class NecroPulseDraw
---@field mePos Vector|nil
---@field radius number
---@field effectiveRadius number
---@field targetPos Vector|nil
---@field predictedPos Vector|nil
---@field canHit boolean
---@field killable boolean
---@field active boolean

local Runtime = {
    lastUpdateAt = -math.huge,
    lastCastAt = -math.huge,
    lastFollowAt = -math.huge,
    toggleActive = false,
    ---@type userdata|nil
    lockedTarget = nil,
    ---@type NecroPulsePending|nil
    pending = nil,
    ---@type NecroPulseDraw
    draw = {
        mePos = nil,
        radius = DEFAULT_RADIUS,
        effectiveRadius = DEFAULT_RADIUS - DEFAULT_SAFETY_MARGIN,
        targetPos = nil,
        predictedPos = nil,
        canHit = false,
        killable = false,
        active = false,
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

local function ClearDraw()
    Runtime.draw.mePos = nil
    Runtime.draw.targetPos = nil
    Runtime.draw.predictedPos = nil
    Runtime.draw.canHit = false
    Runtime.draw.killable = false
    Runtime.draw.active = false
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastCastAt = -math.huge
    Runtime.lastFollowAt = -math.huge
    Runtime.toggleActive = false
    Runtime.lockedTarget = nil
    Runtime.pending = nil
    ClearDraw()
end

local function ReadBool(key, defaultOn)
    return Config.ReadInt(CONFIG_SECTION, key, defaultOn and 1 or 0) ~= 0
end

local function WriteBool(key, value)
    Config.WriteInt(CONFIG_SECTION, key, value and 1 or 0)
end

local function ReadInt(key, defaultValue)
    return Config.ReadInt(CONFIG_SECTION, key, defaultValue)
end

local function WriteInt(key, value)
    Config.WriteInt(CONFIG_SECTION, key, value)
end

---@param identifier any
---@return boolean
local function IsOurOrder(identifier)
    return type(identifier) == "string" and identifier:sub(1, #ORDER_PREFIX) == ORDER_PREFIX
end

---@param widget { Icon?: fun(self: any, icon: string) }|nil
---@param icon string
local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        widget:Icon(icon)
    end
end

---@param a Vector|nil
---@param b Vector|nil
---@return number
local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
    if a.Distance2D then
        local d = a:Distance2D(b)
        if type(d) == "number" then
            return d
        end
    end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

---@param ability userdata
---@param name string
---@param fallback number
---@return number
local function ReadSpecial(ability, name, fallback)
    local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, name)
    if type(value) ~= "number" or value ~= value or value <= 0 then
        return fallback
    end
    return value
end

---@param ability userdata
---@return number
local function CooldownRemaining(ability)
    local remaining = SafeValue(Ability.GetCooldown, ability)
    if type(remaining) == "number" and remaining > 0 then
        return remaining
    end
    return 0
end

---@param raw number|nil
---@return number
local function SpellAmpMultiplier(raw)
    if type(raw) ~= "number" or raw ~= raw or raw <= 0 then
        return 1
    end
    if raw > 1 then
        return 1 + (raw / 100)
    end
    return 1 + raw
end

---@param color Color
---@param alpha number
---@return Color
local function WithAlpha(color, alpha)
    return Color(color.r, color.g, color.b, math.floor(math.max(0, math.min(255, alpha))))
end

---@param name string
---@param defaultColor Color
---@return Color
local function GetThemeColor(name, defaultColor)
    if not Menu or not Menu.Style then
        return defaultColor
    end
    local col = SafeValue(Menu.Style, name)
    if col and type(col) == "userdata" then
        ---@cast col Color
        return col
    end
    return defaultColor
end

local function SyncThemeColors()
    local primary = GetThemeColor("primary", Theme.accent)
    local okColor = GetThemeColor("indication_good", Theme.ready)
    local warnColor = GetThemeColor("indication_warning", Theme.wait)
    local errColor = GetThemeColor("indication_error", Theme.miss)

    Theme.accent = WithAlpha(primary, 255)
    Theme.ready = WithAlpha(okColor, 220)
    Theme.wait = WithAlpha(warnColor, 200)
    Theme.miss = WithAlpha(errColor, 180)
    Theme.kill = WithAlpha(okColor, 240)
    Theme.marker = WithAlpha(primary, 235)
    Theme.outer = WithAlpha(primary, 110)
    Theme.line = WithAlpha(primary, 140)
end
--#endregion

--#region Localization
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
        or value:find("简体", 1, true)
    then
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

local function ModeItems()
    return { L("mode_hold"), L("mode_toggle") }
end

local function ApplyLocalization(force)
    local lang = GetLanguageCode()
    if not force and LangState.lastLanguage == lang then
        return
    end
    LangState.lastLanguage = lang

    MenuLabel(MenuNodes.group, "group_name")
    MenuLabel(MenuNodes.gear, "gear_settings")

    MenuLabel(UI.enabled, "ui_enabled")
    MenuTip(UI.enabled, "tip_enabled")

    MenuLabel(UI.harassBind, "ui_harass_bind")
    MenuTip(UI.harassBind, "tip_harass_bind")

    if UI.mode then
        local selected = UI.mode:Get() or MODE_HOLD
        UI.mode:Update(ModeItems(), selected)
        MenuLabel(UI.mode, "ui_mode")
        MenuTip(UI.mode, "tip_mode")
    end

    MenuLabel(UI.followCursor, "ui_follow_cursor")
    MenuTip(UI.followCursor, "tip_follow_cursor")

    MenuLabel(UI.minEnemies, "ui_min_enemies")
    MenuTip(UI.minEnemies, "tip_min_enemies")

    MenuLabel(UI.safetyMargin, "ui_safety_margin")
    MenuTip(UI.safetyMargin, "tip_safety_margin")

    MenuLabel(UI.manaReserve, "ui_mana_reserve")
    MenuTip(UI.manaReserve, "tip_mana_reserve")

    MenuLabel(UI.killSecure, "ui_kill_secure")
    MenuTip(UI.killSecure, "tip_kill_secure")

    MenuLabel(UI.drawPreview, "ui_draw_preview")
    MenuTip(UI.drawPreview, "tip_draw_preview")
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
---@return CMenuGroup|nil
local function FindOrCreateGroup()
    local group = Menu.Find("Heroes", "Hero List", HERO_TAB, "Main Settings", "Death Pulse Harass")
        or Menu.Find("Scripts", "Combat", "NecroPulseHarass", "Main", "General")

    if not group then
        local mainSection = Menu.Find("Heroes", "Hero List", HERO_TAB, "Main Settings")
        if mainSection and mainSection.Create then
            group = mainSection:Create("Death Pulse Harass")
        end
    end

    return group or Menu.Create("Scripts", "Combat", "NecroPulseHarass", "Main", "General")
end

local function EnsureMenu()
    if UI.enabled
        and UI.harassBind
        and UI.gear
        and UI.mode
        and UI.minEnemies
        and UI.safetyMargin
        and UI.manaReserve
        and UI.killSecure
        and UI.drawPreview
        and UI.followCursor
        and UI.callbacksAttached
    then
        ApplyLocalization(false)
        return
    end

    local group = FindOrCreateGroup()
    if not group then
        return
    end
    MenuNodes.group = group

    if not UI.enabled then
        local existing = group:Find("Enable")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or group:Switch("Enable", ReadBool("enabled", true), Icons.enable)
    end
    MenuIcon(UI.enabled, Icons.enable)

    if not UI.harassBind then
        local existing = group:Find("Harass Bind")
        ---@cast existing CMenuBind|nil
        UI.harassBind = existing or group:Bind("Harass Bind", Enum.ButtonCode.KEY_NONE, Icons.bind)
    end
    MenuIcon(UI.harassBind, Icons.bind)

    if UI.enabled and not UI.gear then
        UI.gear = UI.enabled:Gear("Settings", Icons.gear, true)
    end
    local gear = UI.gear
    if not gear then
        return
    end
    MenuNodes.gear = gear

    if not UI.mode then
        local existing = gear:Find("Mode")
        ---@cast existing CMenuComboBox|nil
        local defaultMode = ReadInt("mode", MODE_HOLD)
        if defaultMode ~= MODE_HOLD and defaultMode ~= MODE_TOGGLE then
            defaultMode = MODE_HOLD
        end
        UI.mode = existing or gear:Combo("Mode", ModeItems(), defaultMode)
    end
    MenuIcon(UI.mode, Icons.mode)

    if not UI.followCursor then
        local existing = gear:Find("Follow Cursor") or gear:Find("Следование за курсором")
        ---@cast existing CMenuSwitch|nil
        UI.followCursor = existing
            or gear:Switch("Follow Cursor", ReadBool("follow_cursor", true), Icons.follow)
    end
    MenuIcon(UI.followCursor, Icons.follow)

    if not UI.minEnemies then
        local existing = gear:Find("Min Enemies") or gear:Find("Мин. врагов")
        ---@cast existing CMenuSliderInt|CMenuSliderFloat|nil
        local defaultMin = ReadInt("min_enemies", DEFAULT_MIN_ENEMIES)
        if defaultMin < 1 then
            defaultMin = 1
        elseif defaultMin > 5 then
            defaultMin = 5
        end
        UI.minEnemies = existing or gear:Slider("Min Enemies", 1, 5, defaultMin, "%d")
    end
    MenuIcon(UI.minEnemies, Icons.enemies)

    if not UI.safetyMargin then
        local existing = gear:Find("Safety Margin") or gear:Find("Запас к радиусу")
        ---@cast existing CMenuSliderInt|CMenuSliderFloat|nil
        UI.safetyMargin = existing
            or gear:Slider("Safety Margin", 0, 120, ReadInt("safety_margin", DEFAULT_SAFETY_MARGIN), "%d")
    end
    MenuIcon(UI.safetyMargin, Icons.margin)

    if not UI.manaReserve then
        local existing = gear:Find("Mana Reserve %") or gear:Find("Резерв маны %")
        ---@cast existing CMenuSliderInt|CMenuSliderFloat|nil
        UI.manaReserve = existing
            or gear:Slider("Mana Reserve %", 0, 80, ReadInt("mana_reserve", DEFAULT_MANA_RESERVE), "%d")
    end
    MenuIcon(UI.manaReserve, Icons.mana)

    if not UI.killSecure then
        local existing = gear:Find("Kill Secure") or gear:Find("Добивание")
        ---@cast existing CMenuSwitch|nil
        UI.killSecure = existing or gear:Switch("Kill Secure", ReadBool("kill_secure", true), Icons.kill)
    end
    MenuIcon(UI.killSecure, Icons.kill)

    if not UI.drawPreview then
        local existing = gear:Find("Draw Preview") or gear:Find("Превью радиуса")
        ---@cast existing CMenuSwitch|nil
        UI.drawPreview = existing or gear:Switch("Draw Preview", ReadBool("draw_preview", true), Icons.draw)
    end
    MenuIcon(UI.drawPreview, Icons.draw)

    if UI.enabled and not UI.callbacksAttached then
        UI.enabled:SetCallback(function(widget)
            WriteBool("enabled", widget:Get())
            if not widget:Get() then
                ResetRuntime()
            end
        end, false)

        if UI.mode then
            UI.mode:SetCallback(function(widget)
                local value = widget:Get() or MODE_HOLD
                WriteInt("mode", value)
                Runtime.toggleActive = false
            end, false)
        end

        if UI.followCursor then
            UI.followCursor:SetCallback(function(widget)
                WriteBool("follow_cursor", widget:Get())
            end, false)
        end

        if UI.minEnemies then
            UI.minEnemies:SetCallback(function(widget)
                WriteInt("min_enemies", widget:Get())
            end, false)
        end

        if UI.safetyMargin then
            UI.safetyMargin:SetCallback(function(widget)
                WriteInt("safety_margin", widget:Get())
            end, false)
        end

        if UI.manaReserve then
            UI.manaReserve:SetCallback(function(widget)
                WriteInt("mana_reserve", widget:Get())
            end, false)
        end

        if UI.killSecure then
            UI.killSecure:SetCallback(function(widget)
                WriteBool("kill_secure", widget:Get())
            end, false)
        end

        if UI.drawPreview then
            UI.drawPreview:SetCallback(function(widget)
                WriteBool("draw_preview", widget:Get())
            end, false)
        end

        UI.callbacksAttached = true
    end

    ApplyLocalization(true)
    SetupLanguageCallback()
end

---@return integer
local function GetMode()
    if not UI.mode then
        return MODE_HOLD
    end
    local mode = UI.mode:Get()
    if mode == MODE_TOGGLE then
        return MODE_TOGGLE
    end
    return MODE_HOLD
end

---@return boolean
local function IsHarassActive()
    if not UI.harassBind then
        return false
    end
    if GetMode() == MODE_TOGGLE then
        if UI.harassBind:IsPressed() then
            Runtime.toggleActive = not Runtime.toggleActive
        end
        return Runtime.toggleActive == true
    end
    Runtime.toggleActive = false
    return UI.harassBind:IsDown() == true
end
--#endregion

--#region Validation
---@param unit userdata|nil
---@return boolean
local function IsAliveUnit(unit)
    return unit ~= nil and SafeValue(Entity.IsAlive, unit) == true
end

---@param me userdata|nil
---@return boolean
local function IsLocalNecro(me)
    if not IsAliveUnit(me) then
        return false
    end
    return SafeValue(NPC.GetUnitName, me) == HERO_NAME
end

---@param me userdata
---@return boolean
local function CanMove(me)
    if SafeValue(NPC.IsStunned, me) == true then
        return false
    end
    if SafeValue(NPC.IsChannellingAbility, me) == true then
        return false
    end
    local states = Enum.modifierState
    if states then
        if SafeValue(NPC.HasState, me, states.MODIFIER_STATE_HEXED) == true then
            return false
        end
        if SafeValue(NPC.HasState, me, states.MODIFIER_STATE_COMMAND_RESTRICTED) == true then
            return false
        end
    end
    return true
end

---@param me userdata
---@return boolean
local function CanCastActions(me)
    if not CanMove(me) then
        return false
    end
    if SafeValue(NPC.IsSilenced, me) == true then
        return false
    end
    return true
end

---@param unit userdata|nil
---@return boolean
local function IsMagicImmune(unit)
    if not unit then
        return true
    end
    local states = Enum.modifierState
    if states and SafeValue(NPC.HasState, unit, states.MODIFIER_STATE_MAGIC_IMMUNE) == true then
        return true
    end
    for i = 1, #MAGIC_IMMUNE_MODS do
        if SafeValue(NPC.HasModifier, unit, MAGIC_IMMUNE_MODS[i]) == true then
            return true
        end
    end
    return false
end

---@param unit userdata|nil
---@return boolean
local function IsInvulnerable(unit)
    if not unit then
        return true
    end
    local states = Enum.modifierState
    if states and SafeValue(NPC.HasState, unit, states.MODIFIER_STATE_INVULNERABLE) == true then
        return true
    end
    return false
end

---@param unit userdata|nil
---@return boolean
local function IsEnemyVisible(unit)
    if not unit then
        return false
    end
    if SafeValue(NPC.IsVisible, unit) == false then
        return false
    end
    if SafeValue(Entity.IsDormant, unit) == true then
        return false
    end
    local pos = SafeValue(Entity.GetAbsOrigin, unit)
    if pos and FogOfWar and FogOfWar.IsPointVisible then
        return SafeValue(FogOfWar.IsPointVisible, pos) ~= false
    end
    return true
end

---@param unit userdata|nil
---@return boolean
local function IsSafeCastTarget(unit)
    if not unit then
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

---@param enemy userdata|nil
---@param me userdata
---@return boolean
local function IsValidEnemyTarget(enemy, me)
    if not IsAliveUnit(enemy) or enemy == me then
        return false
    end
    if SafeValue(NPC.IsIllusion, enemy) == true then
        return false
    end
    local myTeam = SafeValue(Entity.GetTeamNum, me)
    local theirTeam = SafeValue(Entity.GetTeamNum, enemy)
    if myTeam == nil or theirTeam == nil or myTeam == theirTeam then
        return false
    end
    if IsMagicImmune(enemy) or IsInvulnerable(enemy) then
        return false
    end
    if not IsEnemyVisible(enemy) then
        return false
    end
    if not IsSafeCastTarget(enemy) then
        return false
    end
    return true
end

---@param ability userdata
---@param me userdata
---@return boolean
local function IsPulseCastable(ability, me)
    local mana = SafeValue(NPC.GetMana, me) or 0
    local maxMana = SafeValue(NPC.GetMaxMana, me) or 0
    local reservePct = UI.manaReserve and UI.manaReserve:Get() or DEFAULT_MANA_RESERVE
    if maxMana > 0 then
        local manaCost = SafeValue(Ability.GetManaCost, ability) or 0
        local manaAfter = mana - manaCost
        if manaAfter < 0 then
            return false
        end
        local pctAfter = (manaAfter / maxMana) * 100
        if pctAfter < reservePct then
            return false
        end
    end
    return SafeValue(Ability.IsCastable, ability, mana) == true
end
--#endregion

--#region Prediction / damage
---@param me userdata
---@param target userdata
---@param ability userdata
---@param includeTravel boolean
---@return Vector|nil predicted
---@return number lead
local function PredictTarget(me, target, ability, includeTravel)
    local position = SafeValue(Entity.GetAbsOrigin, target)
    local ownerPos = SafeValue(Entity.GetAbsOrigin, me)
    if not position or not ownerPos then
        return nil, 0
    end

    -- Death Pulse is true AoE around the caster; no facing gate.
    local castPoint = SafeValue(Ability.GetCastPoint, ability, true) or 0
    if type(castPoint) ~= "number" or castPoint < 0 then
        castPoint = 0
    end

    local projectileSpeed = includeTravel and ReadSpecial(ability, "projectile_speed", DEFAULT_PROJECTILE_SPEED) or 0
    local travelTime = 0
    if projectileSpeed > 0 then
        travelTime = Dist2D(ownerPos, position) / projectileSpeed
    end

    local lead = math.max(0, castPoint + travelTime)
    local states = Enum.modifierState
    local immobile = SafeValue(NPC.IsStunned, target) == true
        or (states and SafeValue(NPC.HasState, target, states.MODIFIER_STATE_ROOTED) == true)

    if lead > 0 and SafeValue(NPC.IsRunning, target) == true then
        local speed = immobile and 0 or (SafeValue(NPC.GetMoveSpeed, target) or 0)
        for _ = 1, PREDICT_ITERATIONS do
            local previousLead = lead
            local forward = SafeValue(Entity.GetForwardPosition, target, speed * lead)
            if not forward then
                break
            end
            position = forward
            local refinedTravel = 0
            if projectileSpeed > 0 then
                refinedTravel = Dist2D(ownerPos, position) / projectileSpeed
            end
            lead = math.max(0, castPoint + refinedTravel)
            if math.abs(lead - previousLead) <= PREDICT_EPS then
                break
            end
        end
    end

    return position, lead
end

---@param me userdata
---@param target userdata
---@param ability userdata
---@return number
---@return boolean killable
local function EstimatePulseDamage(me, target, ability)
    if IsMagicImmune(target) then
        return 0, false
    end

    local raw = SafeValue(Ability.GetDamage, ability) or 0
    if type(raw) ~= "number" or raw <= 0 then
        raw = 0
    end

    local spellAmp = SpellAmpMultiplier(SafeValue(NPC.GetBaseSpellAmp, me))
    local magicMult = SafeValue(NPC.GetMagicalArmorDamageMultiplier, target) or 1
    local damage = raw * spellAmp * magicMult

    local barriers = SafeValue(NPC.GetBarriers, target)
    if type(barriers) == "table" then
        local magicBarrier = 0
        local allBarrier = 0
        if type(barriers.magic) == "table" and type(barriers.magic.current) == "number" then
            magicBarrier = math.max(0, barriers.magic.current)
        end
        if type(barriers.all) == "table" and type(barriers.all.current) == "number" then
            allBarrier = math.max(0, barriers.all.current)
        end
        damage = math.max(0, damage - magicBarrier - allBarrier)
    end

    local hp = SafeValue(Entity.GetHealth, target) or 0
    return damage, damage >= hp and hp > 0
end

---@param me userdata
---@param ability userdata
---@param searchRadius number
---@return userdata|nil
local function SelectTarget(me, ability, searchRadius)
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not mePos or team == nil or not Heroes or not Heroes.InRadius then
        return nil
    end

    local locked = Runtime.lockedTarget
    if locked and IsValidEnemyTarget(locked, me) then
        local lockedPos = SafeValue(Entity.GetAbsOrigin, locked)
        if lockedPos and Dist2D(mePos, lockedPos) <= searchRadius + 80 then
            return locked
        end
    end

    local heroes = SafeValue(
        Heroes.InRadius,
        mePos,
        searchRadius,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}

    local cursor = SafeValue(Input.GetWorldCursorPos)
    local killSecure = UI.killSecure and UI.killSecure:Get() == true
    local best = nil
    local bestScore = -math.huge

    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemyTarget(enemy, me) then
            local enemyPos = SafeValue(Entity.GetAbsOrigin, enemy)
            if enemyPos then
                local dist = Dist2D(mePos, enemyPos)
                local score = 10000 - dist
                if cursor then
                    local toCursor = Dist2D(enemyPos, cursor)
                    if toCursor < 450 then
                        score = score + (450 - toCursor) * 1.5
                    end
                end
                local _, killable = EstimatePulseDamage(me, enemy, ability)
                if killSecure and killable then
                    score = score + 5000
                end
                if score > bestScore then
                    bestScore = score
                    best = enemy
                end
            end
        end
    end

    return best
end

---@param me userdata
---@param ability userdata
---@param effectiveRadius number
---@return integer
local function CountEnemiesInEffectiveAoE(me, ability, effectiveRadius)
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not mePos or team == nil or not Heroes or not Heroes.InRadius then
        return 0
    end

    local heroes = SafeValue(
        Heroes.InRadius,
        mePos,
        effectiveRadius + 80,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}

    local count = 0
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemyTarget(enemy, me) then
            local predicted = PredictTarget(me, enemy, ability, false)
            if predicted and Dist2D(mePos, predicted) <= effectiveRadius then
                count = count + 1
            end
        end
    end
    return count
end

---@return integer
local function GetMinEnemies()
    local value = UI.minEnemies and UI.minEnemies:Get() or DEFAULT_MIN_ENEMIES
    if type(value) ~= "number" then
        return DEFAULT_MIN_ENEMIES
    end
    value = math.floor(value)
    if value < 1 then
        return 1
    end
    if value > 5 then
        return 5
    end
    return value
end
--#endregion

--#region Orders
---@param now number
---@param ability userdata
local function UpdatePending(now, ability)
    local pending = Runtime.pending
    if not pending then
        return
    end
    if now - pending.issuedAt > PENDING_EXPIRE then
        Runtime.pending = nil
        return
    end

    if SafeValue(Ability.IsInAbilityPhase, ability) == true then
        Runtime.pending = nil
        Runtime.lastCastAt = now
        return
    end

    local cd = CooldownRemaining(ability)
    if cd > pending.cooldownBefore + 0.05 then
        Runtime.pending = nil
        Runtime.lastCastAt = now
        return
    end

    local since = SafeValue(Ability.SecondsSinceLastUse, ability)
    if type(since) == "number" and since >= 0 and since < 0.35 and since < PENDING_EXPIRE then
        Runtime.pending = nil
        Runtime.lastCastAt = now
    end
end

---@param ability userdata
---@return boolean
local function IssueCast(ability)
    local ok = TryCall(Ability.CastNoTarget, ability, false, true, true, ORDER_CAST)
    return ok == true
end

---@param now number
---@param me userdata
---@return boolean
local function TryFollowCursor(now, me)
    if not UI.followCursor or UI.followCursor:Get() ~= true then
        return false
    end
    if not CanMove(me) then
        return false
    end
    if Runtime.pending then
        return false
    end
    if now - Runtime.lastFollowAt < FOLLOW_DEDUP then
        return false
    end
    if now - Runtime.lastCastAt < 0.12 then
        return false
    end

    local cursor = SafeValue(Input.GetWorldCursorPos)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    if not cursor or not myPos then
        return false
    end
    if Dist2D(myPos, cursor) < FOLLOW_STOP_DIST then
        return false
    end

    local ok = TryCall(NPC.MoveTo, me, cursor, false, false, true, false, ORDER_FOLLOW, false)
    if ok then
        Runtime.lastFollowAt = now
        return true
    end
    return false
end

---@param now number
---@param ability userdata
local function TryCast(now, ability)
    if Runtime.pending then
        return
    end
    if now - Runtime.lastCastAt < CAST_DEDUP then
        return
    end

    local cdBefore = CooldownRemaining(ability)
    if IssueCast(ability) then
        Runtime.lastCastAt = now
        Runtime.pending = {
            kind = "cast",
            issuedAt = now,
            cooldownBefore = cdBefore,
            ability = ability,
        }
    end
end
--#endregion

--#region Feature
---@param now number
local function UpdateFeature(now)
    local me = SafeValue(Heroes.GetLocal)
    if not IsLocalNecro(me) then
        ResetRuntime()
        return
    end
    ---@cast me userdata

    local active = IsHarassActive()
    Runtime.draw.active = active == true
    if not active then
        Runtime.lockedTarget = nil
        Runtime.pending = nil
        ClearDraw()
        return
    end

    if Input.IsInputCaptured() or (Input.IsPopupOpen and Input.IsPopupOpen()) then
        ClearDraw()
        Runtime.draw.active = true
        return
    end

    if not CanMove(me) then
        ClearDraw()
        Runtime.draw.active = true
        return
    end

    local ability = SafeValue(NPC.GetAbility, me, ABILITY_NAME)
    local hasPulse = ability ~= nil and (SafeValue(Ability.GetLevel, ability) or 0) > 0
    if hasPulse then
        ---@cast ability userdata
        UpdatePending(now, ability)
    end

    local radius = hasPulse and ReadSpecial(ability, "area_of_effect", DEFAULT_RADIUS) or DEFAULT_RADIUS
    local margin = UI.safetyMargin and UI.safetyMargin:Get() or DEFAULT_SAFETY_MARGIN
    local effectiveRadius = math.max(50, radius - margin)
    local searchRadius = radius + margin + CHASE_BUFFER

    Runtime.draw.radius = radius
    Runtime.draw.effectiveRadius = effectiveRadius

    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    Runtime.draw.mePos = mePos

    local canCastNow = hasPulse
        and CanCastActions(me)
        and IsPulseCastable(ability, me)

    if not canCastNow then
        Runtime.draw.canHit = false
        Runtime.draw.targetPos = nil
        Runtime.draw.predictedPos = nil
        Runtime.draw.killable = false
        TryFollowCursor(now, me)
        return
    end
    ---@cast ability userdata

    local target = SelectTarget(me, ability, searchRadius)
    Runtime.lockedTarget = target
    if not target or not mePos then
        Runtime.draw.canHit = false
        Runtime.draw.targetPos = nil
        Runtime.draw.predictedPos = nil
        Runtime.draw.killable = false
        TryFollowCursor(now, me)
        return
    end

    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    Runtime.draw.targetPos = targetPos

    local castPredicted = PredictTarget(me, target, ability, false)
    if not castPredicted then
        Runtime.draw.canHit = false
        TryFollowCursor(now, me)
        return
    end
    Runtime.draw.predictedPos = castPredicted

    local castDist = Dist2D(mePos, castPredicted)
    local inRange = castDist <= effectiveRadius
    local enemiesInAoE = inRange and CountEnemiesInEffectiveAoE(me, ability, effectiveRadius) or 0
    local minEnemies = GetMinEnemies()
    local canHit = inRange and enemiesInAoE >= minEnemies
    Runtime.draw.canHit = canHit

    local _, killable = EstimatePulseDamage(me, target, ability)
    Runtime.draw.killable = killable

    if canHit and killable and UI.killSecure and UI.killSecure:Get() then
        local arrivalPredicted = PredictTarget(me, target, ability, true)
        if arrivalPredicted then
            Runtime.draw.predictedPos = arrivalPredicted
        end
    end

    if canHit then
        TryCast(now, ability)
        return
    end

    TryFollowCursor(now, me)
end
--#endregion

--#region Draw
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

---@param center Vector
---@param radius number
---@param segments integer
---@param startAng number|nil
---@param sweepAng number|nil
---@return Vec2[][]
local function CollectWorldRingRuns(center, radius, segments, startAng, sweepAng)
    local runs = {}
    ---@type Vec2[]|nil
    local run = nil
    local start = startAng or 0
    local sweep = (type(sweepAng) == "number") and sweepAng or (math.pi * 2)
    local steps = math.max(8, segments or RING_SEGMENTS)
    if sweepAng ~= nil then
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
        local screen, visible = WorldToScreenPos(world)
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
local function StrokeRingRuns(runs, color, thickness)
    if not runs or not color then
        return
    end
    thickness = thickness or 2
    for i = 1, #runs do
        local pts = runs[i]
        if #pts >= 2 then
            if Render.PolyLine then
                TryCall(Render.PolyLine, pts, color, thickness)
            else
                for j = 2, #pts do
                    TryCall(Render.Line, pts[j - 1], pts[j], color, thickness)
                end
            end
        end
    end
end

---@param center Vector
---@param radius number
---@param color Color
---@param thickness number
---@param dashed boolean|nil
local function DrawWorldCircle(center, radius, color, thickness, dashed)
    if not center or not radius or radius <= 0 or not color then
        return
    end
    thickness = thickness or 2
    if dashed then
        local step = math.pi * 2 / RING_SEGMENTS
        local dashLen = step * 2.0
        local gapLen = step * 1.35
        local ang = 0
        while ang < math.pi * 2 - 0.001 do
            local runs = CollectWorldRingRuns(center, radius, 10, ang, dashLen)
            StrokeRingRuns(runs, WithAlpha(color, (color.a or 180) * 0.35), thickness + 3)
            StrokeRingRuns(runs, color, thickness)
            ang = ang + dashLen + gapLen
        end
        return
    end
    local runs = CollectWorldRingRuns(center, radius, RING_SEGMENTS)
    StrokeRingRuns(runs, WithAlpha(color, (color.a or 200) * 0.30), thickness + 4)
    StrokeRingRuns(runs, color, thickness)
end

---@param from Vector
---@param to Vector
---@param color Color
local function DrawWorldLine(from, to, color)
    local a, av = WorldToScreenPos(from)
    local b, bv = WorldToScreenPos(to)
    if not av or not bv or not a or not b then
        return
    end
    TryCall(Render.Line, a, b, color, 1.5)
end

---@param worldPos Vector
---@param color Color
---@param pulse number
---@param killable boolean
local function DrawTargetMarker(worldPos, color, pulse, killable)
    local lifted = Vector(worldPos.x, worldPos.y, (worldPos.z or 0) + MARKER_Z)
    local screen, visible = WorldToScreenPos(lifted)
    if not visible or not screen or not Render then
        return
    end

    local ring = (killable and 10 or 8) + pulse * 2.2
    if Render.Circle then
        TryCall(Render.Circle, screen, ring + 5, WithAlpha(color, 45), 2)
        TryCall(Render.Circle, screen, ring, color, 2.2)
    end
    if Render.FilledCircle then
        TryCall(Render.FilledCircle, screen, math.max(2.5, ring * 0.28), WithAlpha(color, 220))
    end

    local arm = ring + 4
    local tick = WithAlpha(color, 200)
    TryCall(Render.Line, Vec2(screen.x - arm, screen.y), Vec2(screen.x + arm, screen.y), tick, 1.4)
    TryCall(Render.Line, Vec2(screen.x, screen.y - arm), Vec2(screen.x, screen.y + arm), tick, 1.4)
end

---@param mePos Vector
---@param color Color
---@param pulse number
local function DrawCenterGlyph(mePos, color, pulse)
    local screen, visible = WorldToScreenPos(mePos)
    if not visible or not screen or not Render then
        return
    end
    local core = 3.5 + pulse
    if Render.FilledCircle then
        TryCall(Render.FilledCircle, screen, core + 2, WithAlpha(color, 55))
        TryCall(Render.FilledCircle, screen, core, WithAlpha(color, 210))
    end
    if Render.Circle then
        TryCall(Render.Circle, screen, core + 5, WithAlpha(color, 160), 1.6)
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    SyncThemeColors()
    EnsureMenu()
    if Persistent.logger then
        Persistent.logger:info("loaded")
    end
end

function Script.OnThemeUpdate()
    SyncThemeColors()
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end

    EnsureMenu()
    if not UI.enabled or not UI.enabled:Get() then
        if Runtime.lockedTarget or Runtime.pending or Runtime.draw.active or Runtime.toggleActive then
            ResetRuntime()
        end
        return
    end

    local now = GameRules.GetGameTime()
    if type(now) ~= "number" then
        return
    end
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    UpdateFeature(now)
end

function Script.OnPrepareUnitOrders(data)
    local identifier = type(data) == "table" and (data.identifier or data.orderIdentifier) or nil
    if IsOurOrder(identifier) then
        return true
    end
    return true
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end
    if not UI.enabled or not UI.enabled:Get() then
        return
    end
    if not UI.drawPreview or not UI.drawPreview:Get() then
        return
    end

    local draw = Runtime.draw
    if not draw.active or not draw.mePos then
        return
    end

    local now = SafeValue(GameRules.GetGameTime) or 0
    local pulse = 0.55 + 0.45 * math.sin(now * 3.4)

    local coreColor = Theme.miss
    if draw.canHit then
        coreColor = draw.killable and Theme.kill or Theme.ready
    elseif draw.targetPos then
        coreColor = Theme.wait
    end

    local coreA = math.floor(150 + 70 * pulse)
    local outerA = math.floor(70 + 40 * pulse)
    local effectiveColor = WithAlpha(coreColor, coreA)
    local outerColor = WithAlpha(Theme.outer, outerA)

    -- True AoE (dashed) + effective cast gate (solid glow).
    if draw.radius > draw.effectiveRadius + 8 then
        DrawWorldCircle(draw.mePos, draw.radius, outerColor, 1.8, true)
    end
    DrawWorldCircle(draw.mePos, draw.effectiveRadius, effectiveColor, draw.canHit and 2.8 or 2.2, false)

    DrawCenterGlyph(draw.mePos, effectiveColor, pulse)

    local markPos = draw.predictedPos or draw.targetPos
    if markPos then
        local markColor = draw.killable and Theme.kill or Theme.marker
        DrawWorldLine(draw.mePos, markPos, WithAlpha(Theme.line, 90 + 50 * pulse))
        DrawTargetMarker(markPos, markColor, pulse, draw.killable == true)
    end
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
