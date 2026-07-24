--[[
    Io Helper v1.1
    Relocate return HUD, tether guard, spirits timer, auto-overcharge before heal items.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local LOG_PREFIX = "[IoHelper] "
local HERO_NAME = "npc_dota_hero_wisp"
local TETHER_NAME = "wisp_tether"
local TETHER_BREAK_NAME = "wisp_tether_break"
local OVERCHARGE_NAME = "wisp_overcharge"
local SPIRITS_NAME = "wisp_spirits"
local TETHER_MOD = "modifier_wisp_tether"
local SPIRITS_MOD = "modifier_wisp_spirits"
local OVERCHARGE_MOD = "modifier_wisp_overcharge"
local CAST_ID_PREFIX = "io_helper."
local ORDER_CAST_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local ORDER_CAST_NO_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
local SPIRIT_SCAN_INTERVAL = 0.1
local OVERCHARGE_CAST_COOLDOWN = 0.15
local SPIRIT_Z_OFFSET = 128
local SPIRIT_MIN_FONT_SIZE = 22
local HERO_SPIRIT_TIMER_Z_EXTRA = 48
local RELOCATE_RETURN_MOD = "modifier_wisp_relocate_return"
local RELOCATE_THINKER_MOD = "modifier_wisp_relocate_thinker"
local RELOCATE_MOD_NAMES = {
    RELOCATE_RETURN_MOD,
    RELOCATE_THINKER_MOD,
}
local SPELL_ICON = "panorama/images/spellicons/wisp_relocate_png.vtex_c"
local CONFIG_SECTION = "io_relocate_return_hud"
local PANEL_HEADER_FONT_CANDIDATES = {
    "Segoe UI",
    "Tahoma",
    "Arial",
}
local PANEL_HEADER_HEIGHT = 36
local PANEL_HEADER_PAD_X = 12
local PANEL_HEADER_TEXT_SIZE = 15
local PANEL_HEADER_ICON_SIZE = 15
local PANEL_HEADER_ICON_GAP = 8
local PANEL_HEADER_RADIUS = 6
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_SHADOW_THICKNESS = 14
local PANEL_BAR_H = 6
local PANEL_BAR_PAD_Y = 6
local DEFAULT_RETURN_DURATION = 12.0
local DEFAULT_TETHER_GUARD_DURATION = 2.0
local LANG_CACHE_INTERVAL = 1.0

local HEAL_SOURCE_ITEMS = {
    "item_faerie_fire",
    "item_magic_stick",
    "item_magic_wand",
    "item_mekansm",
    "item_guardian_greaves",
    "item_holy_locket",
}

local HEAL_SOURCE_DEFAULTS = {
    item_faerie_fire = true,
    item_magic_stick = true,
    item_magic_wand = true,
    item_mekansm = true,
    item_guardian_greaves = true,
    item_holy_locket = true,
}

local Icons = {
    enable  = "\u{f00c}",
    gear    = "\u{f013}",
    timer   = "\u{f017}",
    bar     = "\u{f080}",
    scale   = "\u{f065}",
    shield  = "\u{f132}",
    bomb    = "\u{f1e2}",
    bolt    = "\u{f0e7}",
    heal    = "\u{f21e}",
}

--#endregion

--#region State

local UI = {}

local MenuNodes = {
    group = nil,
    gear = nil,
    tetherGroup = nil,
    tetherGear = nil,
    spiritsGroup = nil,
    spiritsGear = nil,
    overchargeGroup = nil,
    overchargeGear = nil,
}

local LangState = {
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    callbackSet = false,
}

local State = {
    spellIcon = nil,
    wasMousePressed = false,
    returnState = nil,
    relocateTrack = nil,
    relocateReturnWasActive = false,
    tetherGuardUntil = 0,
    spiritsState = nil,
    spiritHitTracker = nil,
    lastSpiritSyncAt = -100,
    lastOverchargeCastAt = -100,
}

local fontPanel = 0
local fontSpirits = 0

local PanelConfig = {
    X = -1,
    Y = 48,
}

local PanelDrag = {
    IsDragging = false,
    OffsetX = 0,
    OffsetY = 0,
}

local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    TextTimer = Color(180, 180, 190, 255),
    Accent = Color(180, 180, 190, 255),
    BarBg = Color(40, 40, 50, 200),
    BarFill = Color(180, 180, 190, 255),
    BodyBg = Color(12, 12, 16, 255),
    Shadow = Color(0, 0, 0, 0),
    TextShadow = Color(0, 0, 0, 140),
}

local LoggerInstance = Logger and Logger("IoHelper") or nil

--#endregion

--#region Helpers

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function Log(level, message)
    message = LOG_PREFIX .. tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if pcall(LoggerInstance[level], LoggerInstance, message) then
            return
        end
    end
    print(message)
end

local function GetGameTime()
    return SafeCall(GameRules.GetGameTime) or 0
end

local function GetMousePos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok then
            if type(x) == "number" and type(y) == "number" then
                return x, y
            end
            if (type(x) == "table" or type(x) == "userdata") and x.x and x.y then
                return x.x, x.y
            end
        end

        ok, x, y = pcall(function()
            return Input:GetCursorPos()
        end)
        if ok and type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    if Render and Render.GetCursorPos then
        local ok, posOrX, y = pcall(Render.GetCursorPos)
        if ok then
            if type(posOrX) == "number" and type(y) == "number" then
                return posOrX, y
            end
            if (type(posOrX) == "table" or type(posOrX) == "userdata") and posOrX.x and posOrX.y then
                return posOrX.x, posOrX.y
            end
        end
    end

    return nil, nil
end

local function IsLmbDown()
    return SafeCall(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1) == true
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function GetLocalIoHero()
    local hero = SafeCall(Heroes.GetLocal)
    if not hero then
        return nil
    end
    if SafeCall(NPC.GetUnitName, hero) ~= HERO_NAME then
        return nil
    end
    if SafeCall(Entity.IsAlive, hero) == false then
        return nil
    end
    return hero
end

local function GetAbilityName(ability)
    if not ability then
        return nil
    end
    return SafeCall(Ability.GetName, ability)
        or SafeCall(Ability.GetAbilityName, ability)
end

local function GetManaPct(mana, maxMana)
    if type(mana) ~= "number" or type(maxMana) ~= "number" or maxMana <= 0 then
        return 0
    end
    return (mana / maxMana) * 100
end

local function IsOurOrderIdentifier(identifier)
    return type(identifier) == "string"
        and identifier:find(CAST_ID_PREFIX, 1, true) == 1
end

local function ResetRelocateTrack()
    State.relocateTrack = nil
end

local function ResetRuntimeState()
    State.returnState = nil
    State.spiritsState = nil
    State.spiritHitTracker = nil
    ResetRelocateTrack()
    State.relocateReturnWasActive = false
    State.tetherGuardUntil = 0
    State.lastSpiritSyncAt = -100
    State.lastOverchargeCastAt = -100
end

local function ResetAllState()
    ResetRuntimeState()
    State.spellIcon = nil
    State.wasMousePressed = false
    PanelDrag.IsDragging = false
    PanelDrag.OffsetX = 0
    PanelDrag.OffsetY = 0
end

--#endregion

--#region Localization

local Locale = {
    group_name = {
        en = "Relocate Return HUD",
        ru = "HUD возврата Relocate",
    },
    gear_settings = {
        en = "Settings",
        ru = "Настройки",
    },
    ui_enabled = {
        en = "Enable",
        ru = "Включить",
    },
    ui_font_scale = {
        en = "Font scale",
        ru = "Масштаб шрифта",
    },
    ui_show_bar = {
        en = "Show progress bar",
        ru = "Показывать полосу",
    },
    tip_enabled = {
        en = "Screen HUD showing time until Relocate returns you to the cast point.",
        ru = "Экранный HUD с таймером до возврата Relocate на точку каста.",
    },
    label_return = {
        en = "RETURN",
        ru = "ВОЗВРАТ",
    },
    tether_group_name = {
        en = "Tether Guard",
        ru = "Защита Tether",
    },
    spirits_group_name = {
        en = "Spirits Explosion Timer",
        ru = "Таймер взрыва Spirits",
    },
    overcharge_group_name = {
        en = "Overcharge + Heal Items",
        ru = "Overcharge + лечение",
    },
    ui_tether_duration = {
        en = "Guard duration (s)",
        ru = "Длительность защиты (с)",
    },
    ui_tether_hud = {
        en = "Show lock indicator",
        ru = "Показывать индикатор",
    },
    tip_tether = {
        en = "Block Tether recast for a short time after Relocate teleports to prevent accidental unlink.",
        ru = "Блокирует повторный каст Tether после телепорта Relocate, чтобы не разорвать привязку.",
    },
    tip_tether_duration = {
        en = "How long Tether recasts are blocked while already tethered.",
        ru = "На сколько секунд блокировать повторный каст Tether при активной привязке.",
    },
    label_tether_lock = {
        en = "TETHER LOCK",
        ru = "TETHER ЗАБЛОК",
    },
    ui_spirits_scale = {
        en = "Font scale",
        ru = "Масштаб шрифта",
    },
    tip_spirits = {
        en = "Io-blue countdown above hero: spirit count and time until explosion.",
        ru = "Голубой счётчик над героем: число духов и время до взрыва.",
    },
    ui_overcharge_mana = {
        en = "Min mana (%)",
        ru = "Мин. мана (%)",
    },
    ui_overcharge_tether = {
        en = "Only with Tether",
        ru = "Только с Tether",
    },
    ui_heal_sources = {
        en = "Heal Sources",
        ru = "Источники лечения",
    },
    tip_heal_sources = {
        en = "Items that trigger auto-Overcharge before use.",
        ru = "Предметы, перед использованием которых автоматически кастуется Overcharge.",
    },
    tip_overcharge = {
        en = "Auto-cast Overcharge before using enabled team heal items when mana is above the threshold.",
        ru = "Авто-Overcharge перед включёнными предметами лечения при достаточной мане.",
    },
    tip_overcharge_mana = {
        en = "Minimum mana percent required to auto-cast Overcharge.",
        ru = "Минимальный процент маны для авто-Overcharge.",
    },
}

local function GetLanguageWidget()
    local now = os.clock()
    if LangState.languageWidget and now < LangState.languageLookupAt then
        return LangState.languageWidget
    end

    LangState.languageLookupAt = now + LANG_CACHE_INTERVAL
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
        return "en"
    end

    value = tostring(value or "en"):lower()
    if value == "ru" or value:find("рус", 1, true) or value:find("russian", 1, true) then
        return "ru"
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
    if widget and widget.Icon then
        SafeCall(widget.Icon, widget, icon)
    end
end

local function MenuImage(widget, imagePath)
    if widget and widget.Image then
        SafeCall(widget.Image, widget, imagePath)
    end
end

local function MenuTip(widget, key)
    if widget and widget.ToolTip then
        SafeCall(widget.ToolTip, widget, L(key))
    end
end

local function MenuLabel(widget, key)
    if widget and widget.ForceLocalization then
        SafeCall(widget.ForceLocalization, widget, L(key))
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
    MenuLabel(UI.FontScale, "ui_font_scale")
    MenuLabel(UI.ShowBar, "ui_show_bar")

    MenuLabel(MenuNodes.tetherGroup, "tether_group_name")
    MenuLabel(MenuNodes.tetherGear, "gear_settings")
    MenuLabel(UI.TetherEnabled, "ui_enabled")
    MenuTip(UI.TetherEnabled, "tip_tether")
    MenuLabel(UI.TetherDuration, "ui_tether_duration")
    MenuTip(UI.TetherDuration, "tip_tether_duration")
    MenuLabel(UI.TetherHud, "ui_tether_hud")

    MenuLabel(MenuNodes.spiritsGroup, "spirits_group_name")
    MenuLabel(MenuNodes.spiritsGear, "gear_settings")
    MenuLabel(UI.SpiritsEnabled, "ui_enabled")
    MenuTip(UI.SpiritsEnabled, "tip_spirits")
    MenuLabel(UI.SpiritsFontScale, "ui_spirits_scale")

    MenuLabel(MenuNodes.overchargeGroup, "overcharge_group_name")
    MenuLabel(MenuNodes.overchargeGear, "gear_settings")
    MenuLabel(UI.OverchargeEnabled, "ui_enabled")
    MenuTip(UI.OverchargeEnabled, "tip_overcharge")
    MenuLabel(UI.OverchargeManaPct, "ui_overcharge_mana")
    MenuTip(UI.OverchargeManaPct, "tip_overcharge_mana")
    MenuLabel(UI.OverchargeRequireTether, "ui_overcharge_tether")
    MenuLabel(UI.HealSources, "ui_heal_sources")
    MenuTip(UI.HealSources, "tip_heal_sources")
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

--#region Theme

local function ClampThemeByte(value, fallback)
    if type(value) ~= "number" then
        return fallback
    end
    if value < 0 then
        return 0
    end
    if value > 255 then
        return 255
    end
    return value
end

local function NormalizeThemeColor(col)
    if col == nil then
        return nil
    end

    local r = col.r
    local g = col.g
    local b = col.b
    local a = col.a
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    if a == nil then
        a = 255
    end

    if r <= 1 and g <= 1 and b <= 1 and a <= 1 then
        r = r * 255
        g = g * 255
        b = b * 255
        a = a * 255
    end

    return Color(
        ClampThemeByte(r, 255),
        ClampThemeByte(g, 255),
        ClampThemeByte(b, 255),
        ClampThemeByte(a, 255))
end

local function TryGetThemeColor(name)
    if not Menu or not Menu.Style or not name then
        return nil
    end

    local col = SafeCall(Menu.Style, name)
    local normalized = NormalizeThemeColor(col)
    if normalized then
        return normalized
    end

    local tbl = SafeCall(Menu.Style)
    if type(tbl) == "table" then
        return NormalizeThemeColor(tbl[name])
    end

    return nil
end

local function TryGetThemeColorAny(names)
    for i = 1, #names do
        local color = TryGetThemeColor(names[i])
        if color then
            return color
        end
    end
    return nil
end

local function PickAccentColor()
    local enabledSwitchBg = TryGetThemeColor("enabled_switch_background")
    local comboItemActive = TryGetThemeColor("combo_item_active")
    local primary = TryGetThemeColor("primary")
    local indicationActive = TryGetThemeColor("indication_active")
    local sliderGrab = TryGetThemeColor("slider_grab_active")

    local candidates = {}
    local sources = { enabledSwitchBg, comboItemActive, primary, indicationActive, sliderGrab }
    for i = 1, #sources do
        local src = sources[i]
        if src then
            candidates[#candidates + 1] = src
        end
    end
    if #candidates == 0 then
        return nil
    end

    local best = candidates[1]
    local bestScore = (best.r or 0) + (best.g or 0) + (best.b or 0)
    for i = 2, #candidates do
        local candidate = candidates[i]
        local alpha = candidate.a
        if alpha == nil then
            alpha = 255
        end
        if alpha > 0 then
            local score = (candidate.r or 0) + (candidate.g or 0) + (candidate.b or 0)
            if score > bestScore then
                best = candidate
                bestScore = score
            end
        end
    end

    return Color(best.r, best.g, best.b, best.a == nil and 255 or best.a)
end

local function SyncColors()
    if not Menu or not Menu.Style then
        return
    end

    local headerBg = TryGetThemeColorAny({
        "additional_background",
        "popup_background",
        "main_background",
        "group_background",
    })
    if headerBg then
        Colors.HeaderBg = headerBg
    end

    local textHeader = TryGetThemeColorAny({
        "primary_widgets_text",
        "active_widgets_text",
    })
    if textHeader then
        Colors.TextHeader = textHeader
    end

    local accent = PickAccentColor()
    if accent then
        Colors.Accent = accent
        Colors.TextTimer = Color(accent.r, accent.g, accent.b, 255)
        Colors.BarFill = Color(accent.r, accent.g, accent.b, 255)
    end

    local body = TryGetThemeColorAny({
        "group_background",
        "button_background",
        "combo_frame",
        "input_text_bg",
    })
    if body then
        Colors.BodyBg = body
    end

    local barBg = TryGetThemeColorAny({
        "slider_background",
        "scrollbar_bg",
        "outline",
    })
    if barBg then
        Colors.BarBg = Color(barBg.r, barBg.g, barBg.b, 200)
    end

    -- Soft chrome glow from theme (widgets_shadow / shadow). Alpha 0 = no glow.
    local panelShadow = TryGetThemeColorAny({
        "widgets_shadow",
        "shadow",
    })
    if panelShadow and (panelShadow.a or 0) > 0 then
        Colors.Shadow = panelShadow
    else
        Colors.Shadow = Color(0, 0, 0, 0)
    end

    local textShadow = TryGetThemeColor("text_shadow")
    if textShadow and (textShadow.a or 0) > 0 then
        Colors.TextShadow = textShadow
    elseif panelShadow and (panelShadow.a or 0) > 0 then
        local a = math.min(180, math.max(80, math.floor((panelShadow.a or 140) * 0.55 + 0.5)))
        Colors.TextShadow = Color(panelShadow.r, panelShadow.g, panelShadow.b, a)
    else
        Colors.TextShadow = Color(0, 0, 0, 140)
    end
end

--#endregion

--#region Menu

local function LoadPanelPosition()
    local x = SafeCall(Config.ReadInt, CONFIG_SECTION, "panel_x", -1)
    local y = SafeCall(Config.ReadInt, CONFIG_SECTION, "panel_y", 48)
    if type(x) == "number" then
        PanelConfig.X = x
    end
    if type(y) == "number" then
        PanelConfig.Y = y
    end
end

local function SavePanelPosition()
    SafeCall(Config.WriteInt, CONFIG_SECTION, "panel_x", math.floor(PanelConfig.X + 0.5))
    SafeCall(Config.WriteInt, CONFIG_SECTION, "panel_y", math.floor(PanelConfig.Y + 0.5))
end

local function FindOrCreateIoGroup(title, fallbackPath)
    local mainSection = Menu.Find("Heroes", "Hero List", "Io", "Main Settings")
    if mainSection and mainSection.Create then
        return mainSection:Create(title)
    end

    if type(fallbackPath) == "table" then
        return Menu.Create(table.unpack(fallbackPath))
    end

    return Menu.Create("Scripts", "Support", "Io Helper", "Main", title)
end

local function GetItemIconPath(itemId)
    if type(itemId) ~= "string" or itemId == "" then
        return nil
    end
    return "panorama/images/items/" .. itemId:gsub("^item_", "") .. "_png.vtex_c"
end

local function BuildHealSourcesMultiSelectItems()
    local items = {}
    for i = 1, #HEAL_SOURCE_ITEMS do
        local itemId = HEAL_SOURCE_ITEMS[i]
        items[#items + 1] = {
            itemId,
            GetItemIconPath(itemId),
            HEAL_SOURCE_DEFAULTS[itemId] == true,
        }
    end
    return items
end

local function InitializeUI()
    local group = FindOrCreateIoGroup("Relocate Return HUD", {
        "Scripts", "Support", "Io Helper", "Main", "Relocate Return HUD",
    })

    if not group then
        Log("error", "Failed to create menu group")
        return
    end

    MenuNodes.group = group

    UI.Enabled = group:Switch("Enable", true)
    MenuIcon(UI.Enabled, Icons.enable)

    local gear = UI.Enabled:Gear("Settings", Icons.gear, true)
    MenuNodes.gear = gear

    UI.FontScale = gear:Slider("Font scale", 80, 160, 100, "%d%%")
    MenuIcon(UI.FontScale, Icons.scale)

    UI.ShowBar = gear:Switch("Show progress bar", true)
    MenuIcon(UI.ShowBar, Icons.bar)

    local function UpdateControls()
        local enabled = UI.Enabled:Get()
        UI.FontScale:Disabled(not enabled)
        UI.ShowBar:Disabled(not enabled)
    end

    UI.Enabled:SetCallback(UpdateControls, true)

    local tetherGroup = FindOrCreateIoGroup("Tether Guard", {
        "Scripts", "Support", "Io Helper", "Tether", "Tether Guard",
    })
    if tetherGroup then
        MenuNodes.tetherGroup = tetherGroup
        UI.TetherEnabled = tetherGroup:Switch("Enable", true)
        MenuIcon(UI.TetherEnabled, Icons.enable)

        local tetherGear = UI.TetherEnabled:Gear("Settings", Icons.gear, true)
        MenuNodes.tetherGear = tetherGear

        UI.TetherDuration = tetherGear:Slider("Guard duration (s)", 1, 4, 2, "%d")
        MenuIcon(UI.TetherDuration, Icons.timer)

        UI.TetherHud = tetherGear:Switch("Show lock indicator", true)
        MenuIcon(UI.TetherHud, Icons.bar)

        local function UpdateTetherControls()
            local enabled = UI.TetherEnabled:Get()
            UI.TetherDuration:Disabled(not enabled)
            UI.TetherHud:Disabled(not enabled)
        end

        UI.TetherEnabled:SetCallback(UpdateTetherControls, true)
    end

    local spiritsGroup = FindOrCreateIoGroup("Spirits Explosion Timer", {
        "Scripts", "Support", "Io Helper", "Spirits", "Spirits Explosion Timer",
    })
    if spiritsGroup then
        MenuNodes.spiritsGroup = spiritsGroup
        UI.SpiritsEnabled = spiritsGroup:Switch("Enable", true)
        MenuIcon(UI.SpiritsEnabled, Icons.enable)

        local spiritsGear = UI.SpiritsEnabled:Gear("Settings", Icons.gear, true)
        MenuNodes.spiritsGear = spiritsGear

        UI.SpiritsFontScale = spiritsGear:Slider("Font scale", 80, 160, 100, "%d%%")
        MenuIcon(UI.SpiritsFontScale, Icons.scale)

        local function UpdateSpiritsControls()
            local enabled = UI.SpiritsEnabled:Get()
            UI.SpiritsFontScale:Disabled(not enabled)
        end

        UI.SpiritsEnabled:SetCallback(UpdateSpiritsControls, true)
    end

    local overchargeGroup = FindOrCreateIoGroup("Overcharge + Heal Items", {
        "Scripts", "Support", "Io Helper", "Overcharge", "Overcharge + Heal Items",
    })
    if overchargeGroup then
        MenuNodes.overchargeGroup = overchargeGroup
        UI.OverchargeEnabled = overchargeGroup:Switch("Enable", true)
        MenuIcon(UI.OverchargeEnabled, Icons.enable)

        UI.HealSources = overchargeGroup:MultiSelect(
            "Heal Sources",
            BuildHealSourcesMultiSelectItems(),
            false)
        MenuIcon(UI.HealSources, Icons.heal)

        local overchargeGear = UI.OverchargeEnabled:Gear("Settings", Icons.gear, true)
        MenuNodes.overchargeGear = overchargeGear

        UI.OverchargeManaPct = overchargeGear:Slider("Min mana (%)", 40, 90, 60, "%d%%")
        MenuIcon(UI.OverchargeManaPct, Icons.timer)

        UI.OverchargeRequireTether = overchargeGear:Switch("Only with Tether", false)
        MenuIcon(UI.OverchargeRequireTether, Icons.shield)

        local function UpdateOverchargeControls()
            local enabled = UI.OverchargeEnabled:Get()
            UI.OverchargeManaPct:Disabled(not enabled)
            UI.OverchargeRequireTether:Disabled(not enabled)
            if UI.HealSources and UI.HealSources.Disabled then
                UI.HealSources:Disabled(not enabled)
            end
        end

        UI.OverchargeEnabled:SetCallback(UpdateOverchargeControls, true)
    end

    ApplyLocalization(true)
    SetupLanguageCallback()
end

--#endregion

--#region Relocate

local function GetModifierDuration(mod, modName)
    local duration = SafeCall(Modifier.GetDuration, mod)
    if type(duration) == "number" and duration > 0 then
        return duration
    end

    local fieldName = modName == RELOCATE_THINKER_MOD and "cast_delay" or "return_time"
    local fieldValue = SafeCall(Modifier.GetField, mod, fieldName)
    if type(fieldValue) == "number" and fieldValue > 0 then
        return fieldValue
    end

    return DEFAULT_RETURN_DURATION
end

local function GetModifierRemaining(mod, now)
    now = now or GetGameTime()

    local dieTime = SafeCall(Modifier.GetDieTime, mod)
    if type(dieTime) == "number" and dieTime > now then
        return dieTime - now
    end

    local duration = SafeCall(Modifier.GetDuration, mod)
    local created = SafeCall(Modifier.GetCreationTime, mod)
    if type(duration) == "number" and duration > 0 and type(created) == "number" and created > 0 then
        local remaining = duration - (now - created)
        if remaining > 0 then
            return remaining
        end
    end

    local lastApplied = SafeCall(Modifier.GetLastAppliedTime, mod)
    if type(duration) == "number" and duration > 0 and type(lastApplied) == "number" and lastApplied > 0 then
        local remaining = duration - (now - lastApplied)
        if remaining > 0 then
            return remaining
        end
    end

    local returnTime = SafeCall(Modifier.GetField, mod, "return_time")
    if type(returnTime) == "number" and returnTime > 0 and type(created) == "number" and created > 0 then
        local remaining = returnTime - (now - created)
        if remaining > 0 then
            return remaining
        end
    end

    local track = State.relocateTrack
    if track and track.mod == mod and type(track.startedAt) == "number" and type(track.duration) == "number" then
        local remaining = track.duration - (now - track.startedAt)
        if remaining > 0 then
            return remaining
        end
    end

    return nil
end

local function FindRelocateModifier(hero)
    for _, modName in ipairs(RELOCATE_MOD_NAMES) do
        if SafeCall(NPC.HasModifier, hero, modName) then
            local mod = SafeCall(NPC.GetModifier, hero, modName)
            if mod then
                return mod, modName
            end
        end
    end

    local modifiers = SafeCall(NPC.GetModifiers, hero) or {}
    local returnMod, returnName, thinkerMod, thinkerName

    for _, mod in ipairs(modifiers) do
        local name = SafeCall(Modifier.GetName, mod) or ""
        if name == RELOCATE_RETURN_MOD or name:find("relocate_return", 1, true) then
            returnMod, returnName = mod, name
        elseif name == RELOCATE_THINKER_MOD or name:find("relocate_thinker", 1, true) then
            thinkerMod, thinkerName = mod, name
        end
    end

    if returnMod then
        return returnMod, returnName
    end
    if thinkerMod then
        return thinkerMod, thinkerName
    end

    return nil, nil
end

local function UpdateRelocateTrack(mod, modName, now)
    local track = State.relocateTrack
    if track and track.mod == mod then
        return
    end

    State.relocateTrack = {
        mod = mod,
        startedAt = now,
        duration = GetModifierDuration(mod, modName),
    }
end

local function BuildRelocateReturnState(hero)
    if not hero or SafeCall(Entity.IsAlive, hero) == false then
        ResetRelocateTrack()
        return nil
    end

    local mod, modName = FindRelocateModifier(hero)
    if not mod then
        ResetRelocateTrack()
        return nil
    end

    local now = GetGameTime()
    UpdateRelocateTrack(mod, modName, now)

    local remaining = GetModifierRemaining(mod, now)
    if not remaining or remaining <= 0 then
        ResetRelocateTrack()
        return nil
    end

    local duration = GetModifierDuration(mod, modName)
    if type(duration) ~= "number" or duration <= 0 then
        duration = DEFAULT_RETURN_DURATION
    end

    return {
        remaining = remaining,
        duration = duration,
        fraction = Clamp(remaining / duration, 0, 1),
    }
end

--#endregion

--#region Tether Guard

local OrderCtx = nil

local function ResolveEnumValue(container, candidates)
    if type(container) ~= "table" or type(candidates) ~= "table" then
        return nil
    end
    for i = 1, #candidates do
        local value = container[candidates[i]]
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function GetOrderCtx()
    if OrderCtx then
        return OrderCtx
    end

    OrderCtx = {
        castTarget = ResolveEnumValue(Enum and Enum.UnitOrder or nil, {
            "DOTA_UNIT_ORDER_CAST_TARGET",
            "CAST_TARGET",
        }),
        castNoTarget = ResolveEnumValue(Enum and Enum.UnitOrder or nil, {
            "DOTA_UNIT_ORDER_CAST_NO_TARGET",
            "CAST_NO_TARGET",
        }),
    }
    return OrderCtx
end

local function NormalizeOrderContext(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    local dataTable = type(data) == "table" and data or nil
    if not dataTable then
        return dataTable, player, order, target, position, ability, orderIssuer, npc, queue, showEffects
    end

    if order == nil and dataTable.order ~= nil then
        order = dataTable.order
    end
    if target == nil and dataTable.target ~= nil then
        target = dataTable.target
    end
    if position == nil and dataTable.position ~= nil then
        position = dataTable.position
    end
    if ability == nil and dataTable.ability ~= nil then
        ability = dataTable.ability
    end
    if orderIssuer == nil and dataTable.orderIssuer ~= nil then
        orderIssuer = dataTable.orderIssuer
    elseif orderIssuer == nil and dataTable.issuer ~= nil then
        orderIssuer = dataTable.issuer
    end
    if npc == nil and dataTable.npc ~= nil then
        npc = dataTable.npc
    end
    if queue == nil and dataTable.queue ~= nil then
        queue = dataTable.queue
    end
    if showEffects == nil and dataTable.showEffects ~= nil then
        showEffects = dataTable.showEffects
    end
    if player == nil and dataTable.player ~= nil then
        player = dataTable.player
    end

    return dataTable, player, order, target, position, ability, orderIssuer, npc, queue, showEffects
end

local function IsCastTargetOrder(order)
    if order == nil then
        return false
    end
    if order == ORDER_CAST_TARGET then
        return true
    end
    local ctx = GetOrderCtx()
    return ctx.castTarget ~= nil and order == ctx.castTarget
end

local function IsCastNoTargetOrder(order)
    if order == nil then
        return false
    end
    if order == ORDER_CAST_NO_TARGET then
        return true
    end
    local ctx = GetOrderCtx()
    return ctx.castNoTarget ~= nil and order == ctx.castNoTarget
end

local function HasActiveTether(hero)
    if SafeCall(NPC.HasModifier, hero, TETHER_MOD) == true then
        return true, "modifier"
    end

    local tether = SafeCall(NPC.GetAbility, hero, TETHER_NAME)
    if tether and CustomEntities and CustomEntities.GetTetheredUnit then
        local linked = SafeCall(CustomEntities.GetTetheredUnit, tether)
        if linked then
            return true, "linked"
        end
    end

    return false, "none"
end

local function GetTetherGuardDuration()
    if UI.TetherDuration and UI.TetherDuration.Get then
        local value = SafeCall(UI.TetherDuration.Get, UI.TetherDuration)
        if type(value) == "number" and value > 0 then
            return value
        end
    end
    return DEFAULT_TETHER_GUARD_DURATION
end

local function StartTetherGuard(now, _reason)
    if not UI.TetherEnabled or not SafeCall(UI.TetherEnabled.Get, UI.TetherEnabled) then
        return
    end
    local duration = GetTetherGuardDuration()
    State.tetherGuardUntil = now + duration
end

local function HasRelocateReturnModifier(hero)
    return SafeCall(NPC.HasModifier, hero, RELOCATE_RETURN_MOD) == true
end

local function TrackRelocateTeleports(hero, now)
    if not hero then
        State.relocateReturnWasActive = false
        return
    end

    local hasReturn = HasRelocateReturnModifier(hero)
    if hasReturn and not State.relocateReturnWasActive then
        StartTetherGuard(now, "relocate_out")
    elseif State.relocateReturnWasActive and not hasReturn then
        StartTetherGuard(now, "relocate_back")
    end
    State.relocateReturnWasActive = hasReturn
end

local function IsTetherGuardActive(now)
    now = now or GetGameTime()
    return type(State.tetherGuardUntil) == "number" and now < State.tetherGuardUntil
end

local function IsTetherRelatedAbility(abilityName)
    if type(abilityName) ~= "string" or abilityName == "" then
        return false
    end
    return abilityName == TETHER_NAME
        or abilityName == TETHER_BREAK_NAME
        or abilityName:find("tether", 1, true) ~= nil
end

local function IsTetherBreakAbility(abilityName)
    if type(abilityName) ~= "string" or abilityName == "" then
        return false
    end
    return abilityName == TETHER_BREAK_NAME
        or abilityName:find("tether_break", 1, true) ~= nil
end

local function ShouldBlockTetherOrder(hero, order, ability)
    if not hero or not ability then
        return false, "no_hero_or_ability"
    end

    local abilityName = GetAbilityName(ability) or ""
    if not IsTetherRelatedAbility(abilityName) then
        return false, "not_tether"
    end

    local hasTether = select(1, HasActiveTether(hero))

    -- While tethered, Io's Tether slot becomes "Break Tether" (no-target cast).
    if IsTetherBreakAbility(abilityName) then
        if hasTether then
            return true, "block_break"
        end
        return false, "break_not_tethered"
    end

    -- Fallback: recast Tether on a target while already linked.
    if abilityName == TETHER_NAME and IsCastTargetOrder(order) and hasTether then
        return true, "block_recast"
    end

    return false, "allow"
end

--#endregion

--#region Spirits

local function FindSpiritsModifier(hero)
    if SafeCall(NPC.HasModifier, hero, SPIRITS_MOD) then
        return SafeCall(NPC.GetModifier, hero, SPIRITS_MOD)
    end

    local modifiers = SafeCall(NPC.GetModifiers, hero) or {}
    for _, mod in ipairs(modifiers) do
        local name = SafeCall(Modifier.GetName, mod) or ""
        if name == SPIRITS_MOD or name:find("wisp_spirits", 1, true) then
            return mod
        end
    end

    return nil
end

local function IsInfiniteSpiritsDuration(duration)
    return type(duration) ~= "number" or duration <= 0 or duration > 300
end

local function GetSpiritsRemaining(mod, now)
    now = now or GetGameTime()

    local dieTime = SafeCall(Modifier.GetDieTime, mod)
    if type(dieTime) == "number" and dieTime > now then
        return dieTime - now
    end

    local duration = SafeCall(Modifier.GetDuration, mod)
    local created = SafeCall(Modifier.GetCreationTime, mod)
    if type(duration) == "number" and duration > 0 and type(created) == "number" and created > 0 then
        local remaining = duration - (now - created)
        if remaining > 0 then
            return remaining
        end
    end

    return nil
end

local function GetEntityPosition(entity)
    if not entity then
        return nil
    end

    local pos = SafeCall(Entity.GetAbsOrigin, entity)
    if pos and type(pos.x) == "number" and type(pos.y) == "number" then
        return pos
    end

    if Entity and Entity.GetAbsOriginXYZ then
        local x, y, z = SafeCall(Entity.GetAbsOriginXYZ, entity)
        if type(x) == "number" and type(y) == "number" then
            return Vector(x, y, z or 0)
        end
    end

    if NPC and NPC.GetAbsOrigin then
        pos = SafeCall(NPC.GetAbsOrigin, entity)
        if pos and type(pos.x) == "number" and type(pos.y) == "number" then
            return pos
        end
    end

    return nil
end

local function ReadSpiritNumericField(spiritsMod, spiritsAbility, fieldName)
    local value = spiritsMod and SafeCall(Modifier.GetField, spiritsMod, fieldName)
    if type(value) == "number" then
        return value
    end
    value = spiritsAbility and SafeCall(Entity.GetField, spiritsAbility, fieldName)
    if type(value) == "number" then
        return value
    end
    return nil
end

local function GetSpiritsAbility(hero)
    return SafeCall(NPC.GetAbility, hero, SPIRITS_NAME)
end

local function GetSpiritCount(hero, spiritsMod, spiritsAbility)
    spiritsAbility = spiritsAbility or GetSpiritsAbility(hero)
    local amount = ReadSpiritNumericField(spiritsMod, spiritsAbility, "spirit_amount")
    if type(amount) == "number" and amount > 0 then
        return math.floor(Clamp(amount, 1, 10))
    end
    return 5
end

local function IsWispSpiritUnit(npc, hero)
    if not npc or not hero then
        return false
    end

    local owner = SafeCall(Entity.GetOwner, npc)
    if owner ~= hero then
        return false
    end

    local unitName = SafeCall(NPC.GetUnitName, npc) or ""
    if unitName:find("wisp_spirit", 1, true) then
        return true
    end

    local className = SafeCall(Entity.GetClassName, npc) or ""
    return className:find("Wisp_Spirit", 1, true) ~= nil
end

local function IsSpiritEntityActive(entity)
    if not entity then
        return false
    end
    if Entity and Entity.IsAlive and SafeCall(Entity.IsAlive, entity) == false then
        return false
    end
    if Entity and Entity.IsDormant and SafeCall(Entity.IsDormant, entity) == true then
        return false
    end
    return true
end

local function IsSpiritNpcActive(npc, hero)
    return IsWispSpiritUnit(npc, hero) and IsSpiritEntityActive(npc)
end

local function CountActiveSpiritsFromNpcs(hero)
    local count = 0
    if not NPCs or not NPCs.GetAll then
        return count
    end

    local all = SafeCall(NPCs.GetAll) or {}
    for i = 1, #all do
        local npc = all[i]
        if IsSpiritNpcActive(npc, hero) then
            count = count + 1
        end
    end

    return count
end

local function ResetSpiritHitTracker()
    State.spiritHitTracker = nil
end

local function CountConsumedSpirits(tracker)
    if not tracker or type(tracker.consumed) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(tracker.consumed) do
        count = count + 1
    end
    return count
end

local function SyncSpiritHitTracker(hero, spiritsMod, infinite)
    if not hero or not spiritsMod then
        ResetSpiritHitTracker()
        return
    end

    local modCreated = SafeCall(Modifier.GetCreationTime, spiritsMod) or 0
    local tracker = State.spiritHitTracker
    if tracker and tracker.modCreated == modCreated then
        tracker.infinite = infinite == true
        return
    end

    local spiritsAbility = GetSpiritsAbility(hero)
    local npcCount = CountActiveSpiritsFromNpcs(hero)
    local maxCount = math.max(npcCount, GetSpiritCount(hero, spiritsMod, spiritsAbility))

    State.spiritHitTracker = {
        modCreated = modCreated,
        maxCount = maxCount,
        consumed = {},
        infinite = infinite == true,
    }
end

local function GetTrackedSpiritCount()
    local tracker = State.spiritHitTracker
    if not tracker or tracker.infinite then
        return nil
    end
    local consumed = CountConsumedSpirits(tracker) + (tracker.fallbackHits or 0)
    return math.max(0, (tracker.maxCount or 0) - consumed)
end

local function TryTrackSpiritHeroHit(hero, data)
    if not hero or not data then
        return
    end
    if not UI.SpiritsEnabled or not SafeCall(UI.SpiritsEnabled.Get, UI.SpiritsEnabled) then
        return
    end

    local spiritsMod = FindSpiritsModifier(hero)
    if not spiritsMod then
        return
    end

    local tracker = State.spiritHitTracker
    if not tracker or tracker.infinite then
        return
    end

    local source = data.source
    if IsWispSpiritUnit(source, hero) then
        local target = data.target
        if not target or SafeCall(NPC.IsHero, target) ~= true then
            return
        end

        local damage = data.damage or 0
        if damage <= 0 then
            return
        end

        local idx = SafeCall(Entity.GetIndex, source)
        if not idx or tracker.consumed[idx] then
            return
        end

        tracker.consumed[idx] = true
        return
    end

    if source ~= hero then
        return
    end

    local ability = data.ability
    local abilityName = ability and GetAbilityName(ability)
    if abilityName ~= SPIRITS_NAME then
        return
    end

    local target = data.target
    if not target or SafeCall(NPC.IsHero, target) ~= true then
        return
    end

    local damage = data.damage or 0
    if damage <= 0 then
        return
    end

    local consumedTotal = CountConsumedSpirits(tracker) + (tracker.fallbackHits or 0)
    if consumedTotal >= (tracker.maxCount or 0) then
        return
    end

    local now = GetGameTime()
    if now - (tracker.lastFallbackHitAt or -100) < 0.15 then
        return
    end

    tracker.lastFallbackHitAt = now
    tracker.fallbackHits = (tracker.fallbackHits or 0) + 1
end

local function GetLiveSpiritCount(hero, spiritsMod, spiritsState)
    local infinite = spiritsState and spiritsState.infinite == true
    if not infinite and spiritsMod then
        local tracked = GetTrackedSpiritCount()
        if type(tracked) == "number" then
            return tracked
        end
    end

    local fromNpcs = CountActiveSpiritsFromNpcs(hero)
    if fromNpcs > 0 then
        return fromNpcs
    end

    return 0
end

local function BuildSpiritsState(hero, now)
    local spiritsMod = FindSpiritsModifier(hero)
    if not spiritsMod then
        return nil
    end

    local duration = SafeCall(Modifier.GetDuration, spiritsMod)
    local infinite = IsInfiniteSpiritsDuration(duration)
    local remaining = infinite and nil or GetSpiritsRemaining(spiritsMod, now)
    if not infinite and (not remaining or remaining <= 0) then
        ResetSpiritHitTracker()
        return nil
    end

    SyncSpiritHitTracker(hero, spiritsMod, infinite)

    local spiritCount = GetLiveSpiritCount(hero, spiritsMod, { infinite = infinite })

    return {
        remaining = remaining,
        infinite = infinite,
        spiritCount = spiritCount,
    }
end

--#endregion

--#region Overcharge

local function IsHealItemEnabled(itemId)
    if not itemId or not UI.HealSources or not UI.HealSources.Get then
        return false
    end
    return SafeCall(UI.HealSources.Get, UI.HealSources, itemId) == true
end

local function ShouldInterceptHealOrder(order, itemId)
    if IsCastNoTargetOrder(order) then
        return true
    end
    if IsCastTargetOrder(order) and itemId == "item_holy_locket" then
        return true
    end
    return false
end

local function ShouldAutoOverchargeForItem(itemId, order)
    if not itemId then
        return false
    end
    if not ShouldInterceptHealOrder(order, itemId) then
        return false
    end
    return IsHealItemEnabled(itemId)
end

local function TryAutoOvercharge(hero, now, _itemId)
    if not UI.OverchargeEnabled or not SafeCall(UI.OverchargeEnabled.Get, UI.OverchargeEnabled) then
        return false, "disabled"
    end

    if now - (State.lastOverchargeCastAt or -100) < OVERCHARGE_CAST_COOLDOWN then
        return false, "cooldown"
    end

    if SafeCall(NPC.HasModifier, hero, OVERCHARGE_MOD) == true then
        return false, "active"
    end

    if UI.OverchargeRequireTether and SafeCall(UI.OverchargeRequireTether.Get, UI.OverchargeRequireTether) then
        if SafeCall(NPC.HasModifier, hero, TETHER_MOD) ~= true then
            return false, "no_tether"
        end
    end

    local mana = SafeCall(NPC.GetMana, hero) or 0
    local maxMana = SafeCall(NPC.GetMaxMana, hero) or 1
    local minPct = UI.OverchargeManaPct and SafeCall(UI.OverchargeManaPct.Get, UI.OverchargeManaPct) or 60
    if GetManaPct(mana, maxMana) < minPct then
        return false, "mana"
    end

    local overcharge = SafeCall(NPC.GetAbility, hero, OVERCHARGE_NAME)
    if not overcharge then
        return false, "no_ability"
    end
    if SafeCall(Ability.IsReady, overcharge) ~= true then
        return false, "not_ready"
    end
    if Ability.IsCastable and SafeCall(Ability.IsCastable, overcharge, mana) ~= true then
        return false, "not_castable"
    end

    if not Ability or not Ability.CastNoTarget then
        return false, "no_api"
    end

    local ok = SafeCall(
        Ability.CastNoTarget,
        overcharge,
        false,
        true,
        true,
        CAST_ID_PREFIX .. "overcharge_heal")
    if ok == false then
        return false, "cast_failed"
    end

    State.lastOverchargeCastAt = now
    return true, "cast"
end

--#endregion

--#region Draw

local function IsValidFontHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    return type(handle) == "userdata"
end

local function IsValidTextSize(size)
    if size == nil then
        return false
    end
    return (type(size) == "table" or type(size) == "userdata")
        and type(size.x) == "number"
        and type(size.y) == "number"
end

local function GetPanelSampleText()
    return L("label_return")
end

local function CanMeasureWithFont(handle, sampleText, fontSize)
    if not IsValidFontHandle(handle) or not Render or not Render.TextSize then
        return false
    end
    return IsValidTextSize(SafeCall(
        Render.TextSize,
        handle,
        fontSize or PANEL_HEADER_TEXT_SIZE,
        sampleText or GetPanelSampleText()))
end

local function GetLibRender()
    ---@diagnostic disable-next-line: undefined-global
    return LIB_RENDER
end

local function TryLibRenderDefaultFont(sampleText)
    local libRender = GetLibRender()
    if type(libRender) ~= "table" then
        return nil
    end

    local defaultFont = libRender.default_font
    if IsValidFontHandle(defaultFont)
        and CanMeasureWithFont(defaultFont, sampleText, PANEL_HEADER_TEXT_SIZE) then
        return defaultFont
    end

    return nil
end

local function TryDefaultFont(fontName)
    local libRender = GetLibRender()
    if type(fontName) ~= "string" or fontName == "" or type(libRender) ~= "table" then
        return nil
    end

    local defaultFont = libRender.default_font
    if type(defaultFont) == "function" then
        local handle = SafeCall(defaultFont, fontName)
        if IsValidFontHandle(handle) then
            return handle
        end

        handle = SafeCall(defaultFont, libRender, fontName)
        if IsValidFontHandle(handle) then
            return handle
        end
    elseif type(defaultFont) == "table" then
        local entry = defaultFont[fontName]
        if IsValidFontHandle(entry) then
            return entry
        end

        if type(entry) == "function" then
            local handle = SafeCall(entry)
            if IsValidFontHandle(handle) then
                return handle
            end

            handle = SafeCall(entry, fontName)
            if IsValidFontHandle(handle) then
                return handle
            end

            handle = SafeCall(entry, libRender, fontName)
            if IsValidFontHandle(handle) then
                return handle
            end
        end
    end

    return nil
end

local PANEL_HEADER_FONT_WEIGHTS = {
    Enum and Enum.FontWeight and Enum.FontWeight.SEMIBOLD or 600,
    Enum and Enum.FontWeight and Enum.FontWeight.MEDIUM or 500,
    400,
}

local function TryLoadRenderFont(fontName, sampleText, weights)
    if type(fontName) ~= "string" or fontName == "" or not Render or not Render.LoadFont then
        return nil
    end

    local fontFlag = Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0
    local weightList = weights or PANEL_HEADER_FONT_WEIGHTS
    for w = 1, #weightList do
        local handle = SafeCall(Render.LoadFont, fontName, fontFlag, weightList[w])
        if CanMeasureWithFont(handle, sampleText, PANEL_HEADER_TEXT_SIZE) then
            return handle
        end
    end

    return nil
end

local function ResolvePanelHeaderFont(sampleText)
    local preloaded = TryLibRenderDefaultFont(sampleText)
    if preloaded then
        return preloaded
    end

    for i = 1, #PANEL_HEADER_FONT_CANDIDATES do
        local fontName = PANEL_HEADER_FONT_CANDIDATES[i]
        local handle = TryDefaultFont(fontName)
        if CanMeasureWithFont(handle, sampleText, PANEL_HEADER_TEXT_SIZE) then
            return handle
        end

        handle = TryLoadRenderFont(fontName, sampleText)
        if handle then
            return handle
        end
    end
    return 0
end

local function GetPanelFont()
    local sampleText = GetPanelSampleText()
    if not CanMeasureWithFont(fontPanel, sampleText) then
        fontPanel = ResolvePanelHeaderFont(sampleText) or 0
    end
    if CanMeasureWithFont(fontPanel, sampleText) then
        return fontPanel
    end
    return 0
end

local function GetSpiritsFont()
    local sampleText = "9.9"
    if not CanMeasureWithFont(fontSpirits, sampleText) then
        fontSpirits = ResolvePanelHeaderFont(sampleText) or 0
    end
    if CanMeasureWithFont(fontSpirits, sampleText) then
        return fontSpirits
    end
    return GetPanelFont()
end

local function WorldToScreenPos(worldPos)
    if not Render or not Render.WorldToScreen or not worldPos then
        return nil, false
    end

    local ok, screen, visible = pcall(Render.WorldToScreen, worldPos)
    if not ok or not screen or type(screen.x) ~= "number" or type(screen.y) ~= "number" then
        return nil, false
    end

    return screen, visible == true
end

local function IsOnScreen(screen, margin)
    margin = margin or 80
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or type(screenSize.x) ~= "number" or type(screenSize.y) ~= "number" then
        return true
    end

    return screen.x >= -margin
        and screen.y >= -margin
        and screen.x <= screenSize.x + margin
        and screen.y <= screenSize.y + margin
end

local function DrawWorldLabel(font, size, text, worldPos, textColor)
    local screen, isVisible = WorldToScreenPos(worldPos)
    if not screen then
        return false
    end

    if not isVisible and not IsOnScreen(screen) then
        return false
    end

    if not IsValidFontHandle(font) then
        font = GetPanelFont()
    end
    if not IsValidFontHandle(font) or not Render.Text then
        return false
    end

    local anchorY = screen.y - 12
    if Render.FilledCircle then
        pcall(Render.FilledCircle, Vec2(screen.x, anchorY), 6, Color(textColor.r, textColor.g, textColor.b, 90))
        pcall(Render.FilledCircle, Vec2(screen.x, anchorY), 3, Color(255, 255, 255, 220))
    end

    local textSize = SafeCall(Render.TextSize, font, size, text)
    local textW = textSize and textSize.x or (text:len() * size * 0.55)
    local textH = textSize and textSize.y or size
    local padX, padY = 7, 4
    local topLeft = Vec2(screen.x - textW * 0.5 - padX, anchorY - textH - padY - 10)
    local bottomRight = Vec2(screen.x + textW * 0.5 + padX, anchorY - 10 + padY)

    if Render.FilledRect then
        pcall(Render.FilledRect, topLeft, bottomRight, Color(12, 12, 16, 220), 5)
    end
    if Render.Rect then
        pcall(Render.Rect, topLeft, bottomRight, Color(textColor.r, textColor.g, textColor.b, 200), 5, Enum.DrawFlags.None, 1)
    end

    local textPos = Vec2(screen.x - textW * 0.5, anchorY - textH - 8)
    local shadow = Colors.TextShadow or Color(0, 0, 0, 240)
    if (shadow.a or 0) > 0 then
        pcall(Render.Text, font, size, text, Vec2(textPos.x + 1, textPos.y + 1), shadow)
    end
    return pcall(Render.Text, font, size, text, textPos, textColor) == true
end

local function MeasurePanelTextSize(fontSize, text)
    local font = GetPanelFont()
    local fallback = Vec2(text:len() * fontSize * 0.55, fontSize)
    if not IsValidFontHandle(font) or not Render or not Render.TextSize then
        return fallback
    end
    local size = SafeCall(Render.TextSize, font, fontSize, text)
    if IsValidTextSize(size) then
        return size
    end
    return fallback
end

local function DrawPanelText(size, text, pos, color)
    local font = GetPanelFont()
    if not IsValidFontHandle(font) then
        fontPanel = ResolvePanelHeaderFont(text) or 0
        font = fontPanel
    end
    if not IsValidFontHandle(font) or not Render or not Render.Text then
        return false
    end

    local shadow = Colors.TextShadow or Color(0, 0, 0, 140)
    if (shadow.a or 0) > 0 then
        pcall(Render.Text, font, size, text, Vec2(pos.x + 1, pos.y + 1), shadow)
    end
    if pcall(Render.Text, font, size, text, pos, color) then
        return true
    end

    fontPanel = ResolvePanelHeaderFont(text) or 0
    if IsValidFontHandle(fontPanel)
        and pcall(Render.Text, fontPanel, size, text, pos, color) then
        return true
    end
    return false
end

local function GetMenuBlurStrength()
    local widget = Menu and Menu.Find and Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")
    if not widget or not widget.Get then
        return PANEL_BLUR_BASE_STRENGTH
    end

    local factor = SafeCall(widget.Get, widget)
    if type(factor) ~= "number" or factor <= 0 then
        return nil
    end

    if factor > 1 then
        factor = factor / 100
    end

    return math.max(0.1, factor * PANEL_BLUR_BASE_STRENGTH)
end

local function IsPanelHeaderTransparent()
    local alpha = Colors.HeaderBg.a
    if alpha == nil then
        alpha = 255
    end
    return alpha < 255
end

local function DrawPanelBlur(layout, scale)
    if not IsPanelHeaderTransparent() or not Render or not Render.Blur then
        return
    end

    local strength = GetMenuBlurStrength()
    if not strength then
        return
    end

    SafeCall(
        Render.Blur,
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        strength,
        1.0,
        PANEL_HEADER_RADIUS * scale,
        Enum.DrawFlags.None)
end

local function DrawPanelShadow(x, y, width, height, scale)
    local shadow = Colors.Shadow
    if not shadow or not Render or not Render.Shadow then
        return
    end

    local alpha = shadow.a
    if alpha == nil then
        alpha = 0
    end
    if alpha <= 0 then
        return
    end

    local thickness = math.max(6, PANEL_SHADOW_THICKNESS * scale * (0.55 + alpha / 255))
    local radius = PANEL_HEADER_RADIUS * scale
    local flags = Enum and Enum.DrawFlags and Enum.DrawFlags.ShadowCutOutShapeBackground or nil
    SafeCall(
        Render.Shadow,
        Vec2(x, y),
        Vec2(x + width, y + height),
        shadow,
        thickness,
        radius,
        flags)
end

local function EnsureSpellIcon()
    if State.spellIcon == nil and Render and Render.LoadImage then
        State.spellIcon = SafeCall(Render.LoadImage, SPELL_ICON)
    end
end

local function GetPanelLayout(scale, screenSize, returnState)
    local fontScale = (UI.FontScale and UI.FontScale:Get() or 100) / 100
    local showBar = UI.ShowBar and UI.ShowBar:Get()

    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local barPadY = showBar and (PANEL_BAR_PAD_Y * scale) or 0
    local barH = showBar and (PANEL_BAR_H * scale) or 0

    local labelText = L("label_return")
    local timerText = string.format("%.1fs", returnState.remaining)
    local titleFontSize = PANEL_HEADER_TEXT_SIZE * scale * fontScale
    local timerFontSize = titleFontSize
    local iconSize = PANEL_HEADER_ICON_SIZE * scale
    local iconGap = PANEL_HEADER_ICON_GAP * scale

    local labelSize = MeasurePanelTextSize(titleFontSize, labelText)
    local timerSize = MeasurePanelTextSize(timerFontSize, timerText)
    local labelW = labelSize and labelSize.x or 0
    local timerW = timerSize and timerSize.x or 0

    local labelContentW = iconSize + iconGap + labelW
    local headerW = padX + labelContentW + iconGap + timerW + padX
    local width = math.max(110 * scale, headerW)
    local height = titleH
    if showBar then
        height = height + barPadY + barH + barPadY
    end

    local x = PanelConfig.X
    if type(x) ~= "number" or x < 0 then
        x = math.floor((screenSize.x - width) * 0.5 + 0.5)
    else
        x = Clamp(x, 0, math.max(0, screenSize.x - width))
    end

    local y = Clamp(PanelConfig.Y or 48, 0, math.max(0, screenSize.y - height))

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        titleH = titleH,
        padX = padX,
        barH = barH,
        barPadY = barPadY,
        showBar = showBar,
        labelText = labelText,
        timerText = timerText,
        titleFontSize = titleFontSize,
        timerFontSize = timerFontSize,
        iconSize = iconSize,
        iconGap = iconGap,
        labelSize = labelSize,
        timerSize = timerSize,
    }
end

local function DrawRelocatePanel(layout, returnState, scale)
    DrawPanelBlur(layout, scale)
    DrawPanelShadow(layout.x, layout.y, layout.width, layout.titleH, scale)

    SafeCall(
        Render.FilledRect,
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        Colors.HeaderBg,
        PANEL_HEADER_RADIUS * scale)

    local labelSize = layout.labelSize
    local timerSize = layout.timerSize
    local labelH = labelSize and labelSize.y or layout.titleFontSize
    local timerH = timerSize and timerSize.y or layout.timerFontSize
    local contentH = math.max(labelH, layout.iconSize, timerH)
    local contentY = layout.y + math.floor((layout.titleH - contentH) * 0.5 + 0.5)
    local textX = layout.x + layout.padX

    if State.spellIcon and Render.Image then
        local iconY = contentY + math.floor((contentH - layout.iconSize) * 0.5 + 0.5)
        SafeCall(
            Render.Image,
            State.spellIcon,
            Vec2(textX, iconY),
            Vec2(layout.iconSize, layout.iconSize),
            Color(255, 255, 255, 255),
            5 * scale,
            Enum.DrawFlags.None)
        textX = textX + layout.iconSize + layout.iconGap
    end

    local labelY = contentY + math.floor((contentH - labelH) * 0.5 + 0.5)
    DrawPanelText(
        layout.titleFontSize,
        layout.labelText,
        Vec2(textX, labelY),
        Colors.TextHeader)

    local timerW = timerSize.x or 0
    local timerX = layout.x + layout.width - layout.padX - timerW
    local timerY = contentY + math.floor((contentH - timerH) * 0.5 + 0.5)
    DrawPanelText(
        layout.timerFontSize,
        layout.timerText,
        Vec2(timerX, timerY),
        Colors.TextTimer)

    if layout.showBar and layout.barH > 0 then
        local barY = layout.y + layout.titleH + layout.barPadY
        local barX = layout.x + layout.padX
        local barW = layout.width - layout.padX * 2
        local fillW = math.floor(barW * returnState.fraction + 0.5)

        SafeCall(
            Render.FilledRect,
            Vec2(barX, barY),
            Vec2(barX + barW, barY + layout.barH),
            Colors.BarBg,
            layout.barH * 0.5,
            Enum.DrawFlags.None)

        if fillW > 0 then
            SafeCall(
                Render.FilledRect,
                Vec2(barX, barY),
                Vec2(barX + fillW, barY + layout.barH),
                Colors.BarFill,
                layout.barH * 0.5,
                Enum.DrawFlags.None)
        end
    end
end

local function DrawTetherLockIndicator(scale, screenSize, now)
    if not UI.TetherHud or not SafeCall(UI.TetherHud.Get, UI.TetherHud) then
        return
    end
    if not IsTetherGuardActive(now) then
        return
    end

    local remaining = State.tetherGuardUntil - now
    if remaining <= 0 then
        return
    end

    local label = L("label_tether_lock")
    local timerText = string.format("%.1fs", remaining)
    local fontSize = PANEL_HEADER_TEXT_SIZE * scale
    local labelSize = MeasurePanelTextSize(fontSize, label)
    local timerSize = MeasurePanelTextSize(fontSize, timerText)
    local padX = PANEL_HEADER_PAD_X * scale
    local labelW = labelSize and labelSize.x or 0
    local timerW = timerSize and timerSize.x or 0
    local width = padX + labelW + 8 * scale + timerW + padX
    local height = PANEL_HEADER_HEIGHT * scale
    local x = math.floor((screenSize.x - width) * 0.5 + 0.5)
    local y = math.floor((PanelConfig.Y or 48) + height + 8 * scale + 0.5)

    if IsPanelHeaderTransparent() and Render and Render.Blur then
        local strength = GetMenuBlurStrength()
        if strength then
            SafeCall(
                Render.Blur,
                Vec2(x, y),
                Vec2(x + width, y + height),
                strength,
                1.0,
                PANEL_HEADER_RADIUS * scale,
                Enum.DrawFlags.None)
        end
    end

    SafeCall(
        Render.FilledRect,
        Vec2(x, y),
        Vec2(x + width, y + height),
        Colors.HeaderBg,
        PANEL_HEADER_RADIUS * scale)

    local labelH = labelSize and labelSize.y or fontSize
    local timerH = timerSize and timerSize.y or fontSize
    local contentH = math.max(labelH, timerH)
    local contentY = y + math.floor((height - contentH) * 0.5 + 0.5)
    local textX = x + padX

    DrawPanelText(fontSize, label, Vec2(textX, contentY), Colors.TextHeader)

    local timerX = x + width - padX - timerW
    DrawPanelText(fontSize, timerText, Vec2(timerX, contentY), Colors.TextTimer)
end

local function GetHeroSpiritTimerPosition(hero)
    local pos = GetEntityPosition(hero)
    if not pos then
        return nil
    end

    local zOffset = SPIRIT_Z_OFFSET
    local barOffset = SafeCall(NPC.GetHealthBarOffset, hero, true)
    if type(barOffset) == "number" and barOffset > 0 then
        zOffset = barOffset + HERO_SPIRIT_TIMER_Z_EXTRA
    end

    return Vector(pos.x, pos.y, (pos.z or 0) + zOffset)
end

local function DrawSpiritTimers(hero, spiritsState, scale, now)
    if not hero or not spiritsState then
        return
    end

    local spiritsMod = FindSpiritsModifier(hero)
    if not spiritsMod then
        return
    end

    local worldPos = GetHeroSpiritTimerPosition(hero)
    if not worldPos then
        return
    end

    local fontScale = (UI.SpiritsFontScale and SafeCall(UI.SpiritsFontScale.Get, UI.SpiritsFontScale) or 100) / 100
    local font = GetSpiritsFont()
    if not IsValidFontHandle(font) then
        return
    end

    local spiritCount = GetLiveSpiritCount(hero, spiritsMod, spiritsState)
    spiritsState.spiritCount = spiritCount

    local timerText

    if spiritsState.infinite then
        if spiritCount <= 0 then
            return
        end
        timerText = tostring(spiritCount)
    else
        local remaining = GetSpiritsRemaining(spiritsMod, now)
        if not remaining or remaining <= 0 then
            return
        end
        spiritsState.remaining = remaining
        timerText = string.format("%d · %.1f", spiritCount, remaining)
    end

    local fontSize = math.max(SPIRIT_MIN_FONT_SIZE, PANEL_HEADER_TEXT_SIZE * scale * fontScale)
    DrawWorldLabel(font, fontSize, timerText, worldPos, Colors.TextTimer)
end

--#endregion

--#region Lifecycle

InitializeUI()
SyncColors()

function Script.OnScriptsLoaded()
    EnsureSpellIcon()
    LoadPanelPosition()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(GetPanelSampleText()) or 0
    fontSpirits = ResolvePanelHeaderFont("9.9") or 0
end

function Script.OnThemeUpdate()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(GetPanelSampleText()) or 0
    fontSpirits = ResolvePanelHeaderFont("9.9") or 0
end

function Script.OnUpdate()
    if not SafeCall(Engine.IsInGame) then
        ResetRuntimeState()
        return
    end

    local hero = GetLocalIoHero()
    if not hero then
        ResetRuntimeState()
        return
    end

    local now = GetGameTime()

    if UI.Enabled and SafeCall(UI.Enabled.Get, UI.Enabled) then
        State.returnState = BuildRelocateReturnState(hero)
    else
        State.returnState = nil
        ResetRelocateTrack()
    end

    TrackRelocateTeleports(hero, now)

    if UI.SpiritsEnabled and SafeCall(UI.SpiritsEnabled.Get, UI.SpiritsEnabled) then
        if now - (State.lastSpiritSyncAt or -100) >= SPIRIT_SCAN_INTERVAL then
            State.lastSpiritSyncAt = now
            State.spiritsState = BuildSpiritsState(hero, now)
        elseif State.spiritsState and not State.spiritsState.infinite then
            local spiritsMod = FindSpiritsModifier(hero)
            if spiritsMod then
                State.spiritsState.remaining = GetSpiritsRemaining(spiritsMod, now)
                State.spiritsState.spiritCount = GetLiveSpiritCount(
                    hero, spiritsMod, { infinite = false })
                if not State.spiritsState.remaining or State.spiritsState.remaining <= 0 then
                    State.spiritsState = nil
                    ResetSpiritHitTracker()
                end
            else
                State.spiritsState = nil
                ResetSpiritHitTracker()
            end
        end
    else
        State.spiritsState = nil
        State.lastSpiritSyncAt = -100
        ResetSpiritHitTracker()
    end
end

function Script.OnDraw()
    if not SafeCall(Engine.IsInGame) then
        return
    end

    local hero = GetLocalIoHero()
    if not hero then
        return
    end

    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local now = GetGameTime()

    if UI.SpiritsEnabled and SafeCall(UI.SpiritsEnabled.Get, UI.SpiritsEnabled) then
        DrawSpiritTimers(hero, State.spiritsState, scale, now)
    end

    DrawTetherLockIndicator(scale, screenSize, now)

    if not UI.Enabled or not SafeCall(UI.Enabled.Get, UI.Enabled) then
        return
    end

    local returnState = State.returnState
    if not returnState then
        PanelDrag.IsDragging = false
        return
    end

    EnsureSpellIcon()

    local layout = GetPanelLayout(scale, screenSize, returnState)

    local mx, my = GetMousePos()
    local isDown = IsLmbDown()
    local isClicked = isDown and not State.wasMousePressed
    if isClicked and Input and Input.IsInputCaptured and SafeCall(Input.IsInputCaptured) then
        isClicked = false
    end
    local isCursorValid = mx and my

    local isOverHeader = isCursorValid
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.titleH

    if isClicked and isOverHeader then
        PanelDrag.IsDragging = true
        PanelDrag.OffsetX = mx - layout.x
        PanelDrag.OffsetY = my - layout.y
    elseif not isDown then
        if PanelDrag.IsDragging then
            SavePanelPosition()
        end
        PanelDrag.IsDragging = false
    end

    if PanelDrag.IsDragging and mx and my then
        PanelConfig.X = math.max(0, math.min(screenSize.x - layout.width, mx - PanelDrag.OffsetX))
        PanelConfig.Y = math.max(0, math.min(screenSize.y - layout.height, my - PanelDrag.OffsetY))
        layout = GetPanelLayout(scale, screenSize, returnState)
    end

    State.wasMousePressed = isDown

    DrawRelocatePanel(layout, returnState, scale)
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    local dataTable
    dataTable, player, order, target, position, ability, orderIssuer, npc, queue, showEffects =
        NormalizeOrderContext(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)

    local identifier = dataTable and dataTable.identifier or nil
    if IsOurOrderIdentifier(identifier) then
        return true
    end

    local hero = GetLocalIoHero()
    if not hero then
        return true
    end

    local orderNpc = (dataTable and dataTable.npc) or npc
    if orderNpc and Entity.GetIndex then
        local heroIndex = SafeCall(Entity.GetIndex, hero)
        local orderIndex = SafeCall(Entity.GetIndex, orderNpc)
        if heroIndex and orderIndex and heroIndex ~= orderIndex then
            return true
        end
    end

    local now = GetGameTime()
    local abilityName = ability and GetAbilityName(ability) or nil

    if UI.TetherEnabled and SafeCall(UI.TetherEnabled.Get, UI.TetherEnabled)
        and IsTetherGuardActive(now) then
        local shouldBlock = ShouldBlockTetherOrder(hero, order, ability)
        if shouldBlock then
            return false
        end
    end

    if abilityName and (IsCastNoTargetOrder(order) or IsCastTargetOrder(order)) then
        if ShouldAutoOverchargeForItem(abilityName, order) then
            TryAutoOvercharge(hero, now, abilityName)
        end
    end

    return true
end

function Script.OnKeyEvent(_data, key, _event)
    if not SafeCall(Engine.IsInGame) then
        return
    end
    if not UI.Enabled or not SafeCall(UI.Enabled.Get, UI.Enabled) then
        return
    end
    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end
    if Input and Input.IsInputCaptured and SafeCall(Input.IsInputCaptured) then
        return
    end

    local returnState = State.returnState
    if not returnState then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, screenSize, returnState)
    local mx, my = GetMousePos()
    local isCursorOverHeader = mx and my
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.titleH

    if isCursorOverHeader or PanelDrag.IsDragging then
        if key == Enum.ButtonCode.KEY_MOUSE1
            or key == Enum.ButtonCode.KEY_MOUSE2
            or key == Enum.ButtonCode.KEY_MOUSE3
            or key == Enum.ButtonCode.KEY_MWHEELUP
            or key == Enum.ButtonCode.KEY_MWHEELDOWN then
            return false
        end
    end
end

function Script.OnEntityHurt(data)
    if not SafeCall(Engine.IsInGame) then
        return
    end

    local hero = GetLocalIoHero()
    if not hero then
        return
    end

    TryTrackSpiritHeroHit(hero, data)
end

function Script.OnGameEnd()
    ResetAllState()
    fontPanel = 0
    fontSpirits = 0
    OrderCtx = nil
end

--#endregion

return Script
