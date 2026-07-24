--[[
    Tusk Kick To Team
    Kicks enemies toward selected allied heroes with Walrus Kick vector orders.
    Auto-plans kick direction; Bind can Blink first, then Snowball the kicked enemy.
    Script by 花曇り hanagumori
--]]

local Script = {}
local unpack = table.unpack

--#region Constants

local LOG_PREFIX = "[TuskKickToTeam] "
local HERO_NAME = "npc_dota_hero_tusk"
local ABILITY_NAME = "tusk_walrus_kick"
local SNOWBALL_NAME = "tusk_snowball"
local SNOWBALL_LAUNCH_NAME = "tusk_launch_snowball"
local SPELL_ICON = "panorama/images/spellicons/tusk_walrus_kick_png.vtex_c"
local CONFIG_SECTION = "tusk_kick_to_team"

local MODE_AUTO = 0
local MODE_BIND = 1

local MODE_ITEMS = {
    "Auto",
    "Bind",
}

local PUSH_LENGTH = 1200
local VECTOR_HINT_DISTANCE = 350
local CAST_THROTTLE = 0.30
local ALLY_SYNC_INTERVAL = 1.0
local AUTO_ASSIST_RADIUS = 1400
local AUTO_CLUSTER_RADIUS = 340
local AUTO_MIN_CLOSER_GAIN = 160
local AUTO_MAX_LANDING_DISTANCE = 700
local OVERSHOOT_WORSEN_TOLERANCE = 75
local POST_ORDER_MIN_LOCK = 0.85
local POST_ORDER_EXTRA_LOCK = 0.45
local DEFAULT_BLINK_RANGE = 1200
local DEFAULT_SNOWBALL_RANGE = 1250
local BIND_BLINK_AFTER_DELAY = 0.12
local BIND_BLINK_KICK_EXPIRE = 1.00
local BIND_BLINK_MIN_DISTANCE = 220
local BIND_BLINK_RANGE_MARGIN = 85
local SNOWBALL_AFTER_KICK_DELAY = 0.08
local SNOWBALL_CAST_RETRY_INTERVAL = 0.05
local SNOWBALL_CAST_CONFIRM_TIMEOUT = 0.75
local SNOWBALL_LAUNCH_RETRY_INTERVAL = 0.08
local SNOWBALL_LAUNCH_RETRY_WINDOW = 0.75
local SNOWBALL_LAUNCH_MAX_ATTEMPTS = 6
local SNOWBALL_WAIT_LOG_INTERVAL = 0.25
local SNOWBALL_COMBO_EXPIRE = 2.00
local DEBUG_LOG_INTERVAL = 0.45
local KICK_UNAVAILABLE_LOG_INTERVAL = 1.50
local ABILITY_SCAN_MAX_INDEX = 24
local TARGET_VISUAL_UPDATE_INTERVAL = 0.04
local PREVIEW_LANDING_RADIUS = 140
local PREVIEW_ALLY_RADIUS = 70
local PREVIEW_RING_SEGMENTS = 28
local PREVIEW_ARROW_LEN = 18
local PREVIEW_ARROW_WIDTH = 10

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local LANG_CACHE_INTERVAL = 1.0

local PANEL_HEADER_FONT_CANDIDATES = {
    "Segoe UI",
    "Tahoma",
    "Arial",
}
local PANEL_HEADER_HEIGHT = 28
local PANEL_HEADER_PAD_X = 8
local PANEL_HEADER_TEXT_SIZE = 14
local PANEL_HEADER_ICON_SIZE = 14
local PANEL_HEADER_ICON_GAP = 6
local PANEL_HEADER_RADIUS = 5
local PANEL_BODY_PAD_Y = 6
local PANEL_CELL_W = 44
local PANEL_CELL_H = 26
local PANEL_CELL_SPACING = 6
local PANEL_CELL_RADIUS = 3
local PANEL_CHIP_ENABLED_ALPHA = 255
local PANEL_CHIP_DISABLED_ALPHA = 105
local PANEL_CHIP_MIN_BORDER_LUMA = 90
local PANEL_MIN_WIDTH = 110
local PANEL_TITLE_SAMPLE = "Kick To Team"
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_SHADOW_THICKNESS = 14

local Icons = {
    panel = "\u{f108}",
    panelHeader = "\u{e1ac}",
    gear = "\u{f013}",
    bind = "\u{e1c1}",
    bug = "\u{f188}",
    draw = "\u{f2d0}",
}

--#endregion

--#region State

local State = {
    lastCastTime = 0,
    lastAllySyncTime = -100,
    wasMousePressed = false,
    panelHeaderFaFont = nil,
    panelHeaderFaAvailable = nil,
    imgCache = nil,
    spellIcon = nil,
    bestPlan = nil,
    pendingOrderUntil = 0,
    postOrderLockUntil = 0,
    pendingVectorStep = nil,
    pendingSnowballCombo = nil,
    pendingBlinkKick = nil,
    lastDebugLogTime = -100,
    lastDebugMessage = "",
    lastKickUnavailableLogTime = -100,
    lastKickUnavailableReason = "",
    lastTargetVisualTime = -100,
    kickPreview = nil,
    matchAllyNames = {},
    matchAllySet = {},
    cachedAllyEntities = {},
    cachedAllyUnitNames = {},
    allyEnabled = {},
}

local UI = {}
local LoggerInstance = Logger and Logger("TuskKickToTeam") or nil

local PanelConfig = {
    X = 200,
    Y = 200,
}

local PanelDrag = {
    IsDragging = false,
    OffsetX = 0,
    OffsetY = 0,
}

local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    BorderEnabled = Color(191, 140, 255, 255),
    CellBg = Color(12, 12, 16, 255),
    Quiet = Color(90, 90, 100, 180),
    Shadow = Color(0, 0, 0, 0),
    TextShadow = Color(0, 0, 0, 140),
}

local LangState = {
    language = "en",
    nextCheck = 0,
}

local fontPanel = 0

--#endregion

--#region Helpers

(function()

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
    message = tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if pcall(LoggerInstance[level], LoggerInstance, message) then
            return
        end
    end

    print(LOG_PREFIX .. message)
end

local function LogDebug(message, force)
    if not UI.Debug or not UI.Debug.Get or UI.Debug:Get() ~= true then
        return
    end

    message = tostring(message)
    local now = GameRules and GameRules.GetGameTime and (GameRules.GetGameTime() or 0) or os.clock()
    if not force and message == State.lastDebugMessage and now - State.lastDebugLogTime < DEBUG_LOG_INTERVAL then
        return
    end

    State.lastDebugMessage = message
    State.lastDebugLogTime = now
    Log("debug", message)
end

local function CleanHeroName(unitName)
    if not unitName then
        return ""
    end

    local cleanName = unitName:gsub("npc_dota_hero_", "")
    if cleanName == "" then
        return ""
    end

    return cleanName:sub(1, 1):upper() .. cleanName:sub(2)
end

local function HeroIconPath(unitName)
    if not unitName or unitName == "" then
        return nil
    end

    return "panorama/images/heroes/" .. unitName .. "_png.vtex_c"
end

local function AllyConfigKey(cleanName)
    return "ally_" .. cleanName:lower()
end

local function IsAllyKickEnabled(cleanName)
    if cleanName == "" then
        return false
    end

    local cached = State.allyEnabled[cleanName]
    if cached ~= nil then
        return cached
    end

    local val = SafeCall(Config and Config.ReadInt, CONFIG_SECTION, AllyConfigKey(cleanName), 1)
    local enabled = val ~= 0
    State.allyEnabled[cleanName] = enabled
    return enabled
end

local function SetAllyKickEnabled(cleanName, enabled)
    if cleanName == "" then
        return
    end

    State.allyEnabled[cleanName] = enabled == true
    SafeCall(Config and Config.WriteInt, CONFIG_SECTION, AllyConfigKey(cleanName), enabled and 1 or 0)
end

local function GetUILanguage()
    local now = os.clock()
    if now < LangState.nextCheck then
        return LangState.language
    end
    LangState.nextCheck = now + LANG_CACHE_INTERVAL

    local langWidget = Menu and Menu.Find and Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    if langWidget and langWidget.Get then
        local idx = SafeCall(langWidget.Get, langWidget)
        if type(idx) == "number" and idx == 1 then
            LangState.language = "ru"
            return LangState.language
        end
    end

    LangState.language = "en"
    return LangState.language
end

local function L(en, ru)
    if GetUILanguage() == "ru" and ru then
        return ru
    end
    return en
end

local function WithTooltip(widget, text)
    if widget and widget.ToolTip then
        SafeCall(widget.ToolTip, widget, text)
    end
end

local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        SafeCall(widget.Icon, widget, icon)
    end
end

local function IsValidFontHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    return type(handle) == "userdata"
end

local function IsValidTextSize(size)
    return (type(size) == "table" or type(size) == "userdata")
        and type(size.x) == "number"
        and type(size.y) == "number"
end

local function GetPanelTitleText()
    return L("Kick To Team", "Пинок в команду")
end

local function CanMeasureWithFont(handle, sampleText, fontSize)
    if not IsValidFontHandle(handle) or not Render or not Render.TextSize then
        return false
    end
    return IsValidTextSize(SafeCall(
        Render.TextSize,
        handle,
        fontSize or PANEL_HEADER_TEXT_SIZE,
        sampleText or PANEL_TITLE_SAMPLE))
end

local function GetLibRender()
    ---@diagnostic disable-next-line: undefined-global
    return LIB_RENDER
end

local function ResolvePanelHeaderFaFont()
    if State.panelHeaderFaFont ~= nil then
        if State.panelHeaderFaFont == 0 then
            return nil
        end
        return State.panelHeaderFaFont
    end

    State.panelHeaderFaFont = 0
    local libRender = GetLibRender()
    if type(libRender) ~= "table" then
        return nil
    end

    local faFont = libRender.default_font_awesome
    if IsValidFontHandle(faFont) then
        State.panelHeaderFaFont = faFont
        return faFont
    end

    return nil
end

local function HasLibRenderText()
    local libRender = GetLibRender()
    return type(libRender) == "table" and type(libRender.text) == "function"
end

local function CanUsePanelHeaderFaIcon()
    local font = ResolvePanelHeaderFaFont()
    if not IsValidFontHandle(font) or not Render or not Render.TextSize then
        return false
    end

    if not IsValidTextSize(SafeCall(Render.TextSize, font, PANEL_HEADER_ICON_SIZE, Icons.panelHeader)) then
        return false
    end

    return HasLibRenderText()
end

local function IsPanelHeaderFaIconAvailable()
    if State.panelHeaderFaAvailable ~= nil then
        return State.panelHeaderFaAvailable
    end

    State.panelHeaderFaAvailable = CanUsePanelHeaderFaIcon()
    return State.panelHeaderFaAvailable
end

local function GetPanelHeaderIconFontSize(scale)
    return math.floor(PANEL_HEADER_ICON_SIZE * scale + 0.5)
end

local function MeasurePanelHeaderFaIconSize(scale)
    local fontSize = GetPanelHeaderIconFontSize(scale)
    local font = ResolvePanelHeaderFaFont()
    local glyph = Icons.panelHeader

    local libRender = GetLibRender()
    if type(libRender) == "table" and type(libRender.text_size) == "function" then
        local size = SafeCall(libRender.text_size, font, fontSize, glyph)
        if IsValidTextSize(size) then
            return size
        end
    end

    if CanMeasureWithFont(font, glyph) then
        local size = SafeCall(Render.TextSize, font, fontSize, glyph)
        if IsValidTextSize(size) then
            return size
        end
    end

    return Vec2(fontSize, fontSize)
end

local function TryDrawPanelHeaderFaIcon(font, size, glyph, pos, color)
    if not IsValidFontHandle(font) then
        return false, nil
    end

    local x, y
    if type(pos) == "table" or type(pos) == "userdata" then
        x, y = pos.x, pos.y
    end
    if type(x) ~= "number" or type(y) ~= "number" then
        return false, nil
    end

    local drawColor = Color(color.r, color.g, color.b, color.a or 255)

    local libRender = GetLibRender()
    if type(libRender) == "table" and type(libRender.text) == "function" then
        if pcall(libRender.text, font, size, glyph, drawColor, x, y) then
            return true, "lib_render_xy"
        end
    end

    if Render and Render.Text and pcall(Render.Text, font, size, glyph, Vec2(x, y), drawColor) then
        return true, "render_text"
    end

    return false, nil
end

local function DrawPanelHeaderIcon(textX, titleContentY, titleContentH, titleIconSize, titleIconGap, scale, iconColor)
    local font = ResolvePanelHeaderFaFont()
    local fontSize = GetPanelHeaderIconFontSize(scale)
    local iconSize = titleIconSize or MeasurePanelHeaderFaIconSize(scale)
    local iconH = iconSize.y or fontSize
    local iconY = titleContentY + math.floor((titleContentH - iconH) * 0.5 + 0.5)
    local drew = TryDrawPanelHeaderFaIcon(
        font,
        fontSize,
        Icons.panelHeader,
        Vec2(textX, iconY),
        iconColor)
    if drew then
        return textX + (iconSize.x or fontSize) + titleIconGap
    end

    return textX
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

fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_SAMPLE) or 0

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

local function DrawPanelHeaderShadow(layout, scale)
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
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        shadow,
        thickness,
        radius,
        flags)
end

local function ReadThemeMember(value, key)
    local ok, result = pcall(function()
        return value[key]
    end)
    if ok then
        return result
    end
    return nil
end

local function ClampThemeByte(value, fallback)
    if type(value) ~= "number" then
        return fallback or 0
    end
    if value >= 0 and value <= 1 then
        value = value * 255
    end
    if value < 0 then
        return 0
    end
    if value > 255 then
        return 255
    end
    return math.floor(value + 0.5)
end

local function NormalizeThemeColor(c)
    if not c then
        return nil
    end

    local valueType = type(c)
    if valueType ~= "table" and valueType ~= "userdata" then
        return nil
    end

    local function channel(keys, fallback)
        for _, key in ipairs(keys) do
            local raw = ReadThemeMember(c, key)
            if type(raw) == "number" then
                return raw
            end
            if type(raw) == "function" then
                local ok, result = pcall(raw, c)
                if ok and type(result) == "number" then
                    return result
                end
            end
        end
        return fallback
    end

    local r = channel({"r", "R", "red", "Red", "GetR", "GetRed", 1}, nil)
    local g = channel({"g", "G", "green", "Green", "GetG", "GetGreen", 2}, nil)
    local b = channel({"b", "B", "blue", "Blue", "GetB", "GetBlue", 3}, nil)
    local a = channel({"a", "A", "alpha", "Alpha", "GetA", "GetAlpha", 4}, 255)

    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end

    return Color(
        ClampThemeByte(r, 0),
        ClampThemeByte(g, 0),
        ClampThemeByte(b, 0),
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
    for _, name in ipairs(names) do
        local color = TryGetThemeColor(name)
        if color then
            return color
        end
    end
    return nil
end

local function PickAccentBorderColor()
    local enabledSwitchBg = TryGetThemeColor("enabled_switch_background")
    local comboItemActive = TryGetThemeColor("combo_item_active")
    local primary = TryGetThemeColor("primary")
    local indicationActive = TryGetThemeColor("indication_active")

    local borderSource = enabledSwitchBg or comboItemActive or primary or indicationActive
    if not borderSource then
        return nil
    end

    local candidates = {borderSource}
    if comboItemActive and comboItemActive ~= borderSource then
        candidates[#candidates + 1] = comboItemActive
    end
    if primary and primary ~= borderSource then
        candidates[#candidates + 1] = primary
    end
    if indicationActive and indicationActive ~= borderSource then
        candidates[#candidates + 1] = indicationActive
    end

    local best = borderSource
    local bestScore = (best.r or 0) + (best.g or 0) + (best.b or 0)
    local bestAlpha = best.a
    if bestAlpha == nil then
        bestAlpha = 255
    end

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
                bestAlpha = alpha
            end
        end
    end

    return Color(best.r, best.g, best.b, bestAlpha)
end

local function SyncColors()
    if not Menu or not Menu.Style then
        return
    end

    local headerBg = TryGetThemeColorAny({
        "additional_background",
        "popup_background",
        "main_background",
        "background",
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

    local borderSource = PickAccentBorderColor()
    if borderSource then
        Colors.BorderEnabled = borderSource
    end

    local cellBg = TryGetThemeColorAny({
        "group_background",
        "button_background",
        "combo_frame",
        "input_text_bg",
    })
    if cellBg then
        Colors.CellBg = Color(cellBg.r, cellBg.g, cellBg.b, 255)
    end

    local quiet = TryGetThemeColorAny({
        "indication_inactive",
        "disabled_switch_background",
        "multiselect_item",
    })
    if quiet then
        Colors.Quiet = quiet
    end

    local panelShadow = TryGetThemeColor("shadow")
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

local function ColorLuminance(color)
    if not color then
        return 0
    end
    return 0.299 * (color.r or 0) + 0.587 * (color.g or 0) + 0.114 * (color.b or 0)
end

local function GetChipBorderColor()
    local accent = Colors.BorderEnabled
    if ColorLuminance(accent) >= PANEL_CHIP_MIN_BORDER_LUMA then
        return Color(accent.r, accent.g, accent.b, 255)
    end

    local text = Colors.TextHeader
    return Color(text.r, text.g, text.b, 255)
end

local function ColorWithAlpha(color, alpha)
    if not color then
        return Color(255, 255, 255, alpha or 255)
    end
    return Color(color.r or 255, color.g or 255, color.b or 255, alpha or 255)
end

SyncColors()

local function ResolveEnumValue(container, candidates)
    if not container then
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

local ORDER_CAST_TARGET_POSITION_NAMES = { "CAST_TARGET_POSITION", "DOTA_UNIT_ORDER_CAST_TARGET_POSITION" }
local ORDER_CAST_TARGET_NAMES = { "CAST_TARGET", "DOTA_UNIT_ORDER_CAST_TARGET" }
local ORDER_CAST_NO_TARGET_NAMES = { "CAST_NO_TARGET", "DOTA_UNIT_ORDER_CAST_NO_TARGET" }
local ORDER_VECTOR_TARGET_POSITION_NAMES = { "VECTOR_TARGET_POSITION", "DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION" }
local ORDER_ISSUER_PASSED_UNIT_ONLY_NAMES =
    { "PLAYER_ORDER_ISSUER_PASSED_UNIT_ONLY", "DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY" }
local ORDER_ISSUER_HERO_ONLY_NAMES = { "PLAYER_ORDER_ISSUER_HERO_ONLY", "DOTA_ORDER_ISSUER_HERO_ONLY" }
local ORDER_ISSUER_SCRIPT_NAMES = { "PLAYER_ORDER_ISSUER_SCRIPT", "DOTA_ORDER_ISSUER_SCRIPT" }

local function ResolveUnitOrder(candidates)
    return ResolveEnumValue(Enum and Enum.UnitOrder or nil, candidates)
end

local function ResolveOrderIssuer(candidates)
    return ResolveEnumValue(Enum and Enum.PlayerOrderIssuer or nil, candidates)
end

local function GetResolvedOrderContext()
    local ctx = {}
    ctx.castTargetPosition = ResolveUnitOrder(ORDER_CAST_TARGET_POSITION_NAMES)
    ctx.castTarget = ResolveUnitOrder(ORDER_CAST_TARGET_NAMES)
    ctx.castNoTarget = ResolveUnitOrder(ORDER_CAST_NO_TARGET_NAMES)
    ctx.vectorTargetPosition = ResolveUnitOrder(ORDER_VECTOR_TARGET_POSITION_NAMES)
    ctx.issuerPassedUnitOnly = ResolveOrderIssuer(ORDER_ISSUER_PASSED_UNIT_ONLY_NAMES)
    ctx.issuerHeroOnly = ResolveOrderIssuer(ORDER_ISSUER_HERO_ONLY_NAMES)
    ctx.issuerScript = ResolveOrderIssuer(ORDER_ISSUER_SCRIPT_NAMES)
    ctx.issuer = ctx.issuerPassedUnitOnly or ctx.issuerHeroOnly or ctx.issuerScript
    return ctx
end

local function InitializeUI()
    local mainSettings = Menu.Find("Heroes", "Hero List", "Tusk", "Main Settings")
    local group = nil

    if mainSettings and mainSettings.Create then
        group = mainSettings:Create("Walrus Kick")
    end

    if not group then
        group = Menu.Create("General", "Tusk", "Walrus Kick", "Settings", "Kick To Team")
    end

    local screenSize = SafeCall(Render.ScreenSize) or Vec2(3840, 2160)
    local maxX = math.max(800, math.floor(screenSize.x))
    local maxY = math.max(600, math.floor(screenSize.y))

    local ui = {}

    ui.Enabled = group:Switch("Kick To Team", false)
    ui.Enabled:Image(SPELL_ICON)

    local gear = ui.Enabled:Gear(L("Settings", "Настройки"), Icons.gear)
    ui.Mode = gear:Combo("Mode", MODE_ITEMS, MODE_AUTO)
    ui.Mode:Image(SPELL_ICON)
    ui.CastKey = gear:Bind("Kick Bind", Enum.ButtonCode.KEY_NONE, Icons.bind)
    ui.DrawPanel = gear:Switch(L("Draw Ally Panel", "Показывать панель союзников"), true, Icons.panel)
    WithTooltip(ui.DrawPanel, L(
        "HUD panel to choose allies and drag the header to reposition.",
        "HUD-панель выбора союзников. Перетаскивайте заголовок для перемещения."))
    ui.DrawPreview = gear:Switch(L("Draw Preview", "Показывать превью пинка"), true, Icons.draw)
    WithTooltip(ui.DrawPreview, L(
        "Minimal kick direction overlay toward selected allies.",
        "Минималистичный оверлей направления пинка к выбранным союзникам."))
    ui.Debug = gear:Switch(L("Debug Log", "Debug логи"), false)
    MenuIcon(ui.Debug, Icons.bug)
    ui.PanelX = gear:Slider("HUD X", 0, maxX, math.min(200, maxX))
    ui.PanelY = gear:Slider("HUD Y", 0, maxY, math.min(200, maxY))
    SafeCall(ui.PanelX.Visible, ui.PanelX, false)
    SafeCall(ui.PanelY.Visible, ui.PanelY, false)

    local gearWidgets = {
        ui.Mode,
        ui.CastKey,
        ui.DrawPanel,
        ui.DrawPreview,
        ui.Debug,
    }

    local function UpdateControls()
        local enabled = ui.Enabled:Get()
        local isBindMode = (ui.Mode:Get() or MODE_AUTO) == MODE_BIND
        for _, widget in ipairs(gearWidgets) do
            if widget and widget.Disabled then
                widget:Disabled(not enabled)
            end
        end
        if ui.CastKey and ui.CastKey.Disabled then
            ui.CastKey:Disabled(not enabled or not isBindMode)
        end
    end

    ui.Enabled:SetCallback(UpdateControls, true)
    ui.Mode:SetCallback(UpdateControls, true)

    return ui
end

UI = InitializeUI()

local function SavePanelPosition()
    local x = math.floor(PanelConfig.X + 0.5)
    local y = math.floor(PanelConfig.Y + 0.5)
    SafeCall(Config.WriteInt, CONFIG_SECTION, "panel_x", x)
    SafeCall(Config.WriteInt, CONFIG_SECTION, "panel_y", y)

    if UI.PanelX and UI.PanelY then
        SafeCall(UI.PanelX.Set, UI.PanelX, x)
        SafeCall(UI.PanelY.Set, UI.PanelY, y)
    end
end

local function LoadPanelPosition()
    local needsSave = false
    local x = SafeCall(Config.ReadInt, CONFIG_SECTION, "panel_x", -1)
    local y = SafeCall(Config.ReadInt, CONFIG_SECTION, "panel_y", -1)

    if type(x) ~= "number" or x < 0 then
        x = (UI.PanelX and UI.PanelX.Get and UI.PanelX:Get()) or PanelConfig.X
        needsSave = true
    end
    if type(y) ~= "number" or y < 0 then
        y = (UI.PanelY and UI.PanelY.Get and UI.PanelY:Get()) or PanelConfig.Y
        needsSave = true
    end

    PanelConfig.X = x
    PanelConfig.Y = y

    if UI.PanelX and UI.PanelY then
        SafeCall(UI.PanelX.Set, UI.PanelX, math.floor(x + 0.5))
        SafeCall(UI.PanelY.Set, UI.PanelY, math.floor(y + 0.5))
    end

    if needsSave then
        SavePanelPosition()
    end
end

LoadPanelPosition()

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

local function GetHeroIcon(heroName)
    if not heroName or heroName == "" then
        return nil
    end
    if State.imgCache == nil then
        State.imgCache = {}
    end
    if State.imgCache[heroName] then
        return State.imgCache[heroName]
    end
    local handle = SafeCall(Render.LoadImage, HeroIconPath(heroName))
    if handle then
        State.imgCache[heroName] = handle
    end
    return handle
end

local function EnsureSpellIcon()
    if State.spellIcon == nil and Render and Render.LoadImage then
        State.spellIcon = SafeCall(Render.LoadImage, SPELL_ICON)
    end
end

local function GetPanelFont()
    local titleText = GetPanelTitleText()
    if not CanMeasureWithFont(fontPanel, titleText) then
        fontPanel = ResolvePanelHeaderFont(titleText) or 0
    end
    if CanMeasureWithFont(fontPanel, titleText) then
        return fontPanel
    end
    return 0
end

local function MeasurePanelTextSize(fontSize, text)
    local font = GetPanelFont()
    local fallback = Vec2(text:len() * fontSize * 0.55, fontSize)
    if font == 0 or not Render or not Render.TextSize then
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

local function MeasurePanelSpellIconSize(scale, titleSizeY)
    local textH = titleSizeY or math.floor(PANEL_HEADER_TEXT_SIZE * scale + 0.5)
    local minIcon = math.floor(PANEL_HEADER_ICON_SIZE * scale + 0.5)
    local maxIcon = math.floor((PANEL_HEADER_HEIGHT - 6) * scale + 0.5)
    local size = math.min(maxIcon, math.max(minIcon, textH))
    return Vec2(size, size)
end

local function GetPanelLayout(scale, numAllies, screenSize)
    local cellW = PANEL_CELL_W * scale
    local cellH = PANEL_CELL_H * scale
    local cellSpacing = PANEL_CELL_SPACING * scale
    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local padY = PANEL_BODY_PAD_Y * scale
    local titleText = GetPanelTitleText()
    local titleFontSize = PANEL_HEADER_TEXT_SIZE * scale
    EnsureSpellIcon()
    local hasTitleIcon = State.spellIcon ~= nil
    local titleSize = MeasurePanelTextSize(titleFontSize, titleText) or Vec2(titleText:len() * titleFontSize * 0.55, titleFontSize)
    local titleSizeX = titleSize.x or 0
    local titleSizeY = titleSize.y or titleFontSize
    local titleIconSize = hasTitleIcon and MeasurePanelSpellIconSize(scale, titleSizeY) or Vec2(0, titleSizeY)
    local titleIconW = titleIconSize.x or 0
    local titleIconGap = hasTitleIcon and (PANEL_HEADER_ICON_GAP * scale) or 0
    local titleContentW = titleIconW + titleIconGap + titleSizeX
    local cellsTotalW = numAllies * cellW + math.max(0, numAllies - 1) * cellSpacing
    local headerW = padX + titleContentW + padX
    local heroesW = padX + cellsTotalW + padX
    local width = math.max(headerW, heroesW, PANEL_MIN_WIDTH * scale)
    local height = titleH + padY + cellH + padY

    local x = math.max(0, math.min(screenSize.x - width, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - height, PanelConfig.Y))

    return {
        cellW = cellW,
        cellH = cellH,
        cellSpacing = cellSpacing,
        titleH = titleH,
        padX = padX,
        titleText = titleText,
        titleIconSize = titleIconSize,
        titleIconGap = titleIconGap,
        titleSize = titleSize,
        titleFontSize = titleFontSize,
        hasTitleIcon = hasTitleIcon,
        width = width,
        height = height,
        x = x,
        y = y,
        rowY = y + titleH + padY,
        cellsStartX = x + math.floor((width - cellsTotalW) * 0.5 + 0.5),
    }
end

local function TryIndex(obj, key)
    if not obj or not key then
        return false, nil
    end

    return pcall(function()
        return obj[key]
    end)
end

local function TryCallMethod(obj, methodName, ...)
    local okIndex, memberOrErr = TryIndex(obj, methodName)
    if not okIndex then
        return false, "index failed: " .. tostring(memberOrErr)
    end

    if type(memberOrErr) ~= "function" then
        return false, "method missing"
    end

    local args = { ... }
    local okCall, resultOrErr = pcall(function()
        return memberOrErr(obj, unpack(args))
    end)

    if okCall then
        return true, resultOrErr
    end

    return false, tostring(resultOrErr)
end

local function GetPlayerForHero(hero)
    local tried = {}

    if Players and Players.GetLocal then
        local player = Players.GetLocal()
        if player then
            return player, "Players.GetLocal"
        end
        tried[#tried + 1] = "Players.GetLocal=nil"
    else
        tried[#tried + 1] = "Players.GetLocal missing"
    end

    if Hero and Hero.GetPlayer then
        local ok, player = pcall(Hero.GetPlayer, hero)
        if ok and player then
            return player, "Hero.GetPlayer"
        end
        tried[#tried + 1] = ok and "Hero.GetPlayer=nil" or ("Hero.GetPlayer error=" .. tostring(player))
    end

    if NPC and NPC.GetPlayerOwner then
        local ok, player = pcall(NPC.GetPlayerOwner, hero)
        if ok and player then
            return player, "NPC.GetPlayerOwner"
        end
        tried[#tried + 1] = ok and "NPC.GetPlayerOwner=nil" or ("NPC.GetPlayerOwner error=" .. tostring(player))
    end

    do
        local ok, playerOrErr = TryCallMethod(hero, "GetPlayer")
        if ok and playerOrErr then
            return playerOrErr, "hero:GetPlayer"
        end
        tried[#tried + 1] = "hero:GetPlayer " .. tostring(playerOrErr)
    end

    do
        local ok, playerOrErr = TryCallMethod(hero, "GetPlayerOwner")
        if ok and playerOrErr then
            return playerOrErr, "hero:GetPlayerOwner"
        end
        tried[#tried + 1] = "hero:GetPlayerOwner " .. tostring(playerOrErr)
    end

    return nil, table.concat(tried, ", ")
end

local function DescribeCompat(ctx, player, playerSource)
    return string.format(
        "player=%s(%s) cast=%s castTarget=%s vector=%s issuer=%s",
        player and "ok" or "nil",
        tostring(playerSource or "?"),
        tostring(ctx and ctx.castTargetPosition or nil),
        tostring(ctx and ctx.castTarget or nil),
        tostring(ctx and ctx.vectorTargetPosition or nil),
        tostring(ctx and ctx.issuer or nil)
    )
end

local function IsTusk(hero)
    return hero and NPC.GetUnitName(hero) == HERO_NAME
end

local function IsValidHeroUnit(unit)
    if not unit then
        return false
    end

    if not Entity.IsAlive(unit) or Entity.IsDormant(unit) then
        return false
    end

    if NPC.IsIllusion(unit) then
        return false
    end

    if NPC.IsInvulnerable and NPC.IsInvulnerable(unit) then
        return false
    end

    return true
end

local function SyncAllyTargets(myHero, now)
    if not myHero then
        return
    end

    if now - State.lastAllySyncTime < ALLY_SYNC_INTERVAL then
        return
    end
    State.lastAllySyncTime = now

    local entities = {}
    local allHeroes = Heroes.GetAll()

    for i = 1, #allHeroes do
        local other = allHeroes[i]
        if other ~= myHero and IsValidHeroUnit(other) and Entity.IsSameTeam(other, myHero) then
            local unitName = NPC.GetUnitName(other)
            local cleanName = CleanHeroName(unitName)
            if cleanName ~= "" then
                if not State.matchAllySet[cleanName] then
                    State.matchAllySet[cleanName] = true
                    State.matchAllyNames[#State.matchAllyNames + 1] = cleanName
                end
                if unitName and unitName ~= "" then
                    State.cachedAllyUnitNames[cleanName] = unitName
                end
                entities[cleanName] = other
                if State.allyEnabled[cleanName] == nil then
                    IsAllyKickEnabled(cleanName)
                end
            end
        end
    end

    table.sort(State.matchAllyNames)
    State.cachedAllyEntities = entities
end

local function GetEntityIndexSafe(unit)
    return SafeCall(Entity and Entity.GetIndex, unit)
end

local function DescribeUnit(unit)
    if not unit then
        return "nil"
    end

    local unitName = SafeCall(NPC and NPC.GetUnitName, unit) or "unit"
    return string.format("%s#index=%s", unitName, tostring(GetEntityIndexSafe(unit)))
end

local function IsAllySelectedForKick(ally)
    local cleanName = CleanHeroName(NPC.GetUnitName(ally))
    if cleanName == "" then
        return false
    end

    return IsAllyKickEnabled(cleanName)
end

local function MakeGroundPosition(pos)
    if not pos then
        return nil
    end

    local groundZ = World.GetGroundZ(pos)
    return Vector(pos.x, pos.y, groundZ)
end

local function MakeDirection2D(fromPos, toPos)
    local delta = Vector(toPos.x - fromPos.x, toPos.y - fromPos.y, 0)
    local length = delta:Length2D()
    if length < 0.001 then
        return nil, 0
    end

    return Vector(delta.x / length, delta.y / length, 0), length
end

local function MoveTowards2D(startPos, direction, distance)
    return Vector(
        startPos.x + direction.x * distance,
        startPos.y + direction.y * distance,
        startPos.z
    )
end

local function DistancePointToSegment2D(point, segA, segB)
    local abX = segB.x - segA.x
    local abY = segB.y - segA.y
    local apX = point.x - segA.x
    local apY = point.y - segA.y
    local abLenSq = abX * abX + abY * abY

    if abLenSq <= 0.001 then
        return segA:Distance2D(point)
    end

    local t = (apX * abX + apY * abY) / abLenSq
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end

    local closest = Vector(segA.x + abX * t, segA.y + abY * t, 0)
    local flatPoint = Vector(point.x, point.y, 0)

    return closest:Distance2D(flatPoint)
end

local function CollectUnits(hero, wantAllies)
    local result = {}
    local allHeroes = Heroes.GetAll()

    for i = 1, #allHeroes do
        local other = allHeroes[i]
        if other ~= hero and IsValidHeroUnit(other) then
            local sameTeam = Entity.IsSameTeam(other, hero)
            if sameTeam == wantAllies then
                local canUse = not wantAllies or IsAllySelectedForKick(other)
                if canUse then
                    result[#result + 1] = {
                        hero = other,
                        pos = Entity.GetAbsOrigin(other),
                    }
                end
            end
        end
    end

    return result
end

local function GetKickRange(hero, kick)
    return Ability.GetCastRange(kick) or 250
end

local function CountAlliesNearPath(allies, startPos, endPos, width)
    local count = 0

    for i = 1, #allies do
        local allyPos = allies[i].pos
        if DistancePointToSegment2D(allyPos, startPos, endPos) <= width then
            count = count + 1
        end
    end

    return count
end

local function CountAlliesNearPosition(allies, pos, radius)
    local count = 0

    for i = 1, #allies do
        if allies[i].pos:Distance2D(pos) <= radius then
            count = count + 1
        end
    end

    return count
end

local function GetNearestAllyDistance(allies, pos)
    local best = math.huge

    for i = 1, #allies do
        local dist = allies[i].pos:Distance2D(pos)
        if dist < best then
            best = dist
        end
    end

    return best
end

local function BuildPlan(hero, enemyData, allies, desiredPos, meta)
    local enemyPos = enemyData.pos
    local heroPos = Entity.GetAbsOrigin(hero)
    local direction, desiredDist = MakeDirection2D(enemyPos, desiredPos)
    local minCloserGain = AUTO_MIN_CLOSER_GAIN
    local maxLandingDistance = AUTO_MAX_LANDING_DISTANCE

    if not direction then
        return nil
    end

    local endPos = MoveTowards2D(enemyPos, direction, PUSH_LENGTH)
    local vectorPos = MoveTowards2D(enemyPos, direction, VECTOR_HINT_DISTANCE)
    local lineWidth = math.max(140, meta.lineWidth or 200)
    local alliesOnPath = CountAlliesNearPath(allies, enemyPos, endPos, lineWidth)
    local alliesNearStart = CountAlliesNearPosition(allies, enemyPos, maxLandingDistance)
    local alliesNearEnd = CountAlliesNearPosition(allies, endPos, maxLandingDistance)
    local desiredEndDist = endPos:Distance2D(desiredPos)
    local nearestBeforeDist = GetNearestAllyDistance(allies, enemyPos)
    local nearestAfterDist = GetNearestAllyDistance(allies, endPos)
    local desiredGain = desiredDist - desiredEndDist
    local closerGain = nearestBeforeDist - nearestAfterDist
    local heroDist = heroPos:Distance2D(enemyPos)
    local alreadyNearTeam =
        alliesNearStart > 0 or nearestBeforeDist <= maxLandingDistance or desiredDist <= maxLandingDistance
    local worsensDesired = desiredEndDist > desiredDist + OVERSHOOT_WORSEN_TOLERANCE
    local worsensNearest = nearestAfterDist > nearestBeforeDist + OVERSHOOT_WORSEN_TOLERANCE
    local improvesNearbyAllies = alliesNearEnd > alliesNearStart

    if alreadyNearTeam and worsensDesired and worsensNearest and not improvesNearbyAllies then
        return nil
    end

    local smartCloserEnough =
        nearestAfterDist <= maxLandingDistance and (desiredGain >= minCloserGain or closerGain >= minCloserGain)
    local enoughCloser = alliesOnPath > 0 or alliesNearEnd > 0 or smartCloserEnough

    if not enoughCloser then
        return nil
    end

    local score =
        (meta.clusterCount or 0) * 100000 +
        alliesOnPath * 14000 +
        alliesNearEnd * 11000 +
        math.max(0, desiredGain) * 20 +
        math.max(0, closerGain) * 16 -
        nearestAfterDist * 8 -
        desiredEndDist * 4 -
        heroDist * 0.25

    return {
        enemy = enemyData.hero,
        enemyPos = MakeGroundPosition(enemyPos),
        desiredPos = MakeGroundPosition(desiredPos),
        vectorPos = MakeGroundPosition(vectorPos),
        endPos = MakeGroundPosition(endPos),
        score = score,
        alliesOnPath = alliesOnPath,
        alliesNearEnd = alliesNearEnd,
        clusterCount = meta.clusterCount or 0,
        strategy = meta.strategy,
        enemyDistance = heroDist,
        nearestAfterDist = nearestAfterDist,
        desiredEndDist = desiredEndDist,
        desiredGain = desiredGain,
        closerGain = closerGain,
    }
end

local function EvaluateNearestPlan(hero, enemyData, allies, assistRadius, clusterRadius)
    local nearest = nil
    local bestProjectedEndDist = math.huge
    local bestCurrentDist = math.huge
    local endSearchRadius = math.max(assistRadius, AUTO_MAX_LANDING_DISTANCE)

    for i = 1, #allies do
        local allyData = allies[i]
        local currentDist = enemyData.pos:Distance2D(allyData.pos)
        local projectedEndDist = math.abs(currentDist - PUSH_LENGTH)

        if (currentDist <= assistRadius or projectedEndDist <= endSearchRadius)
            and (projectedEndDist < bestProjectedEndDist
                or (projectedEndDist == bestProjectedEndDist and currentDist < bestCurrentDist))
        then
            nearest = allyData
            bestProjectedEndDist = projectedEndDist
            bestCurrentDist = currentDist
        end
    end

    if not nearest then
        return nil
    end

    return BuildPlan(hero, enemyData, allies, nearest.pos, {
        strategy = "nearest",
        clusterCount = 1,
        lineWidth = math.max(140, clusterRadius),
    })
end

local function EvaluateClusterPlan(hero, enemyData, allies, assistRadius, clusterRadius)
    local candidates = {}
    local endSearchRadius = math.max(assistRadius, AUTO_MAX_LANDING_DISTANCE)

    for i = 1, #allies do
        local allyData = allies[i]
        local currentDist = enemyData.pos:Distance2D(allyData.pos)
        local projectedEndDist = math.abs(currentDist - PUSH_LENGTH)
        if currentDist <= assistRadius or projectedEndDist <= endSearchRadius then
            candidates[#candidates + 1] = allyData
        end
    end

    if #candidates == 0 then
        return nil
    end

    local bestCenter = nil
    local bestCount = 0
    local bestCenterDist = math.huge
    local bestProjectedEndDist = math.huge

    for i = 1, #candidates do
        local anchor = candidates[i].pos
        local sumX = 0
        local sumY = 0
        local sumZ = 0
        local count = 0

        for j = 1, #candidates do
            local allyPos = candidates[j].pos
            if anchor:Distance2D(allyPos) <= clusterRadius then
                count = count + 1
                sumX = sumX + allyPos.x
                sumY = sumY + allyPos.y
                sumZ = sumZ + allyPos.z
            end
        end

        if count > 0 then
            local center = Vector(sumX / count, sumY / count, sumZ / count)
            local centerDist = enemyData.pos:Distance2D(center)
            local projectedEndDist = math.abs(centerDist - PUSH_LENGTH)

            if count > bestCount
                or (count == bestCount and projectedEndDist < bestProjectedEndDist)
                or (count == bestCount and projectedEndDist == bestProjectedEndDist and centerDist < bestCenterDist)
            then
                bestCount = count
                bestCenter = center
                bestCenterDist = centerDist
                bestProjectedEndDist = projectedEndDist
            end
        end
    end

    if not bestCenter then
        return nil
    end

    return BuildPlan(hero, enemyData, allies, bestCenter, {
        strategy = "cluster",
        clusterCount = bestCount,
        lineWidth = math.max(180, clusterRadius),
    })
end

local CURSOR_OFF_SCREEN_BIAS_SQ = 1e12

local function GetMousePos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok then
            if type(x) == "number" and type(y) == "number" then
                return x, y
            end
            if x and (type(x) == "table" or type(x) == "userdata") and type(x.x) == "number" and type(x.y) == "number" then
                return x.x, x.y
            end
        end
    end

    return nil, nil
end

local function GetCursorScreenDistSq(worldPos, cursorX, cursorY)
    if not worldPos or type(cursorX) ~= "number" or type(cursorY) ~= "number" then
        return nil
    end

    if not Render or not Render.WorldToScreen then
        return nil
    end

    local ok, screenPos, visible = pcall(Render.WorldToScreen, worldPos)
    if not ok or not screenPos then
        return nil
    end

    local sx = screenPos.x
    local sy = screenPos.y
    if type(sx) ~= "number" or type(sy) ~= "number" then
        return nil
    end

    local dx = sx - cursorX
    local dy = sy - cursorY
    local distSq = dx * dx + dy * dy
    if visible == false then
        distSq = distSq + CURSOR_OFF_SCREEN_BIAS_SQ
    end

    return distSq
end

local function IsPlanBetterCandidate(newPlan, newCursorDistSq, bestPlan, bestCursorDistSq, useCursor)
    if not bestPlan then
        return true
    end

    if useCursor then
        local hasNew = type(newCursorDistSq) == "number"
        local hasBest = type(bestCursorDistSq) == "number"

        if hasNew and hasBest then
            if newCursorDistSq < bestCursorDistSq then
                return true
            end
            if newCursorDistSq > bestCursorDistSq then
                return false
            end
            return newPlan.score > bestPlan.score
        end

        if hasNew and not hasBest then
            return true
        end

        if not hasNew and hasBest then
            return false
        end
    end

    return newPlan.score > bestPlan.score
end

local function SelectPlanForEnemy(hero, enemyData, allies, assistRadius, clusterRadius)
    local nearestPlan = EvaluateNearestPlan(hero, enemyData, allies, assistRadius, clusterRadius)
    local clusterPlan = EvaluateClusterPlan(hero, enemyData, allies, assistRadius, clusterRadius)

    if nearestPlan and clusterPlan then
        return nearestPlan.score >= clusterPlan.score and nearestPlan or clusterPlan
    end

    return nearestPlan or clusterPlan
end

local function FindBestPlan(hero, kick, maxEnemyDistance)
    local allies = CollectUnits(hero, true)
    local enemies = CollectUnits(hero, false)

    if #allies == 0 or #enemies == 0 then
        return nil, string.format("insufficient units | allies=%d enemies=%d", #allies, #enemies)
    end

    local castRange = GetKickRange(hero, kick)
    local assistRadius = AUTO_ASSIST_RADIUS
    local clusterRadius = AUTO_CLUSTER_RADIUS
    local enemyScanDistance = maxEnemyDistance or (castRange + 25)
    local cursorX, cursorY = GetMousePos()
    local useCursor = cursorX ~= nil and cursorY ~= nil
    local bestPlan = nil
    local bestCursorDistSq = nil
    local enemiesInRange = 0

    for i = 1, #enemies do
        local enemyData = enemies[i]
        local heroDist = Entity.GetAbsOrigin(hero):Distance2D(enemyData.pos)

        if heroDist <= enemyScanDistance then
            enemiesInRange = enemiesInRange + 1
            local plan = SelectPlanForEnemy(hero, enemyData, allies, assistRadius, clusterRadius)
            if plan then
                local cursorDistSq = useCursor
                    and GetCursorScreenDistSq(plan.enemyPos or enemyData.pos, cursorX, cursorY)
                    or nil
                if IsPlanBetterCandidate(plan, cursorDistSq, bestPlan, bestCursorDistSq, useCursor) then
                    bestPlan = plan
                    bestCursorDistSq = cursorDistSq
                end
            end
        end
    end

    if not bestPlan then
        if enemiesInRange == 0 then
            return nil, string.format("no enemies in cast range | cast=%.0f", castRange)
        end

        return nil, string.format(
            "no valid plan | allies=%d enemiesInRange=%d",
            #allies,
            enemiesInRange
        )
    end

    return bestPlan, nil
end

local function CanEvaluateKick(hero, kick)
    if not Entity.IsAlive(hero) or Entity.IsDormant(hero) then
        return false, "hero invalid"
    end

    if not kick or Ability.GetLevel(kick) <= 0 then
        return false, "kick ability missing or level 0"
    end

    if Ability.IsActivated and not Ability.IsActivated(kick) then
        return false, "kick not activated"
    end

    return true, "ok"
end

local function CanAutoCastKick(hero, kick)
    local canEval, evalReason = CanEvaluateKick(hero, kick)
    if not canEval then
        return false, evalReason
    end

    if not Ability.IsReady(kick) then
        return false, "kick cooldown"
    end

    if not Ability.IsCastable(kick, NPC.GetMana(hero)) then
        return false, "not enough mana or cast blocked"
    end

    return true, "ok"
end

local function GetAbilityCastPointValue(ability)
    if not ability then
        return 0
    end

    if Ability and Ability.GetCastPoint then
        local ok, value = pcall(Ability.GetCastPoint, ability)
        if ok and type(value) == "number" then
            return value
        end
    end

    local ok, value = TryCallMethod(ability, "GetCastPoint")
    if ok and type(value) == "number" then
        return value
    end

    return 0
end

local function GetAbilityCooldownValue(ability)
    if not ability then
        return 0
    end

    if Ability and Ability.GetCooldown then
        local ok, value = pcall(Ability.GetCooldown, ability)
        if ok and type(value) == "number" then
            return value
        end
    end

    local ok, value = TryCallMethod(ability, "GetCooldown")
    if ok and type(value) == "number" then
        return value
    end

    return 0
end

local function IsAbilityInPhaseValue(ability)
    if not ability then
        return false
    end

    if Ability and Ability.IsInAbilityPhase then
        local ok, value = pcall(Ability.IsInAbilityPhase, ability)
        if ok and value ~= nil then
            return value == true
        end
    end

    local ok, value = TryCallMethod(ability, "IsInAbilityPhase")
    if ok and value ~= nil then
        return value == true
    end

    return false
end

local function GetPostOrderLockDuration(ability)
    local castPoint = GetAbilityCastPointValue(ability)
    return math.max(POST_ORDER_MIN_LOCK, castPoint + POST_ORDER_EXTRA_LOCK)
end

local function GetPostOrderLockStatus(ability)
    local now = GameRules.GetGameTime()
    if (State.postOrderLockUntil or 0) <= now then
        return false, nil
    end

    if GetAbilityCooldownValue(ability) > 0.05 then
        State.postOrderLockUntil = 0
        return false, nil
    end

    local left = math.max(0, State.postOrderLockUntil - now)
    if IsAbilityInPhaseValue(ability) then
        return true, string.format("kick in ability phase | left=%.2f", left)
    end

    return true, string.format("awaiting order resolve | left=%.2f", left)
end

local function ClearSnowballCombo()
    State.pendingSnowballCombo = nil
end

local function QueueSnowballCombo(enemy, source)
    if not enemy then
        return
    end

    local now = GameRules.GetGameTime() or 0
    State.pendingSnowballCombo = {
        enemy = enemy,
        enemyIndex = GetEntityIndexSafe(enemy),
        enemyName = SafeCall(NPC and NPC.GetUnitName, enemy) or "enemy",
        phase = "cast",
        dueTime = now + SNOWBALL_AFTER_KICK_DELAY,
        expireTime = now + SNOWBALL_COMBO_EXPIRE,
    }
    LogDebug(
        string.format(
            "Snowball queued after kick | source=%s target=%s",
            tostring(source or "kick"),
            DescribeUnit(enemy)
        ),
        true
    )
end

local function IsEnemyTargetValid(hero, enemy)
    return IsValidHeroUnit(enemy) and not Entity.IsSameTeam(enemy, hero)
end

local function ResolveTrackedEnemy(hero, pending)
    if not pending then
        return nil, "no pending target"
    end

    local expectedIndex = pending.enemyIndex
    local enemy = pending.enemy
    if IsEnemyTargetValid(hero, enemy) then
        local currentIndex = GetEntityIndexSafe(enemy)
        if expectedIndex == nil or currentIndex == expectedIndex then
            return enemy, nil
        end

        return nil, string.format("target index changed | expected=%s current=%s", tostring(expectedIndex), tostring(currentIndex))
    end

    if expectedIndex == nil or not Heroes or not Heroes.GetAll then
        return nil, "tracked target object invalid"
    end

    local allHeroes = Heroes.GetAll()
    for i = 1, #allHeroes do
        local candidate = allHeroes[i]
        if GetEntityIndexSafe(candidate) == expectedIndex and IsEnemyTargetValid(hero, candidate) then
            pending.enemy = candidate
            return candidate, nil
        end
    end

    return nil, string.format("tracked target invalid | expected=%s", tostring(expectedIndex))
end

local function GetAbilityRangeWithBonus(hero, ability, fallback)
    if not ability then
        return fallback or 0
    end

    local range = SafeCall(Ability and Ability.GetCastRange, ability) or fallback or 0
    return range + (SafeCall(NPC and NPC.GetCastRangeBonus, hero) or 0)
end

local function GetSnowballCastRange(hero, snowball)
    local specialRange = SafeCall(Ability and Ability.GetLevelSpecialValueFor, snowball, "snowball_cast_range")
    if type(specialRange) == "number" and specialRange > 0 then
        return specialRange + (SafeCall(NPC and NPC.GetCastRangeBonus, hero) or 0)
    end

    return GetAbilityRangeWithBonus(hero, snowball, DEFAULT_SNOWBALL_RANGE)
end

local function IsEntityInRangeSafe(hero, target, range)
    if not hero or not target or range <= 0 then
        return false
    end

    local inRange = SafeCall(NPC and NPC.IsEntityInRange, hero, target, range)
    if inRange ~= nil then
        return inRange ~= false
    end

    local heroPos = Entity.GetAbsOrigin(hero)
    local targetPos = Entity.GetAbsOrigin(target)
    return heroPos and targetPos and heroPos:Distance2D(targetPos) <= range
end

local function GetTargetAbilityBlockReason(hero, ability, target, range)
    if not ability or not target then
        return "ability or target missing"
    end

    if Ability.GetLevel and Ability.GetLevel(ability) <= 0 then
        return "ability level 0"
    end

    if Ability.IsActivated and not Ability.IsActivated(ability) then
        return "ability not activated"
    end

    if Ability.IsReady and not Ability.IsReady(ability) then
        return "ability cooldown"
    end

    if Ability.IsCastable and not Ability.IsCastable(ability, NPC.GetMana(hero)) then
        return "not enough mana or cast blocked"
    end

    if range ~= nil and not IsEntityInRangeSafe(hero, target, range) then
        local heroPos = SafeCall(Entity and Entity.GetAbsOrigin, hero)
        local targetPos = SafeCall(Entity and Entity.GetAbsOrigin, target)
        local distance = heroPos and targetPos and heroPos:Distance2D(targetPos) or -1
        return string.format("target out of range | dist=%.0f range=%.0f", distance, range)
    end

    return nil
end

local function GetAbilityLookupName(ability)
    if not ability then
        return nil
    end

    local name = SafeCall(Ability and Ability.GetName, ability)
    if name then
        return name
    end

    local ok, methodName = TryCallMethod(ability, "GetName")
    if ok then
        return methodName
    end

    return nil
end

local function FindHeroAbilityByName(hero, abilityName)
    local direct = SafeCall(NPC and NPC.GetAbility, hero, abilityName)
    if direct then
        return direct, "NPC.GetAbility"
    end

    if NPC and NPC.GetAbilityByIndex then
        for index = 0, ABILITY_SCAN_MAX_INDEX do
            local ability = SafeCall(NPC.GetAbilityByIndex, hero, index)
            if ability and GetAbilityLookupName(ability) == abilityName then
                return ability, "NPC.GetAbilityByIndex:" .. tostring(index)
            end
        end
    end

    return nil, "not found"
end

local function DescribeAbilityState(hero, ability, source)
    if not ability then
        return string.format("ability=%s exists=false source=%s", SNOWBALL_LAUNCH_NAME, tostring(source or "none"))
    end

    local index = SafeCall(Ability and Ability.GetIndex, ability)
    local activated = Ability and Ability.IsActivated and SafeCall(Ability.IsActivated, ability)
    local castable = Ability and Ability.IsCastable and SafeCall(Ability.IsCastable, ability, NPC.GetMana(hero))
    local ready = Ability and Ability.IsReady and SafeCall(Ability.IsReady, ability)
    local hidden = Ability and Ability.IsHidden and SafeCall(Ability.IsHidden, ability)
    local inPhase = IsAbilityInPhaseValue(ability)
    return string.format(
        "ability=%s exists=true source=%s index=%s activated=%s castable=%s ready=%s hidden=%s inPhase=%s",
        tostring(GetAbilityLookupName(ability) or SNOWBALL_LAUNCH_NAME),
        tostring(source or "unknown"),
        tostring(index or "?"),
        tostring(activated),
        tostring(castable),
        tostring(ready),
        tostring(hidden),
        tostring(inPhase)
    )
end

local function IsSnowballRolling(hero)
    return SafeCall(NPC and NPC.HasModifier, hero, "modifier_tusk_snowball") == true
        or SafeCall(NPC and NPC.HasModifier, hero, "modifier_tusk_snowball_visible") == true
        or SafeCall(NPC and NPC.HasModifier, hero, "modifier_tusk_snowball_movement") == true
end

local function IsSnowballActive(hero, snowball)
    if IsSnowballRolling(hero) then
        return true, "modifier"
    end

    if snowball and IsAbilityInPhaseValue(snowball) then
        return true, "ability_phase"
    end

    local channel = SafeCall(NPC and NPC.GetChannellingAbility, hero)
    local channelName = SafeCall(Ability and Ability.GetName, channel)
    if not channelName then
        local ok, methodName = TryCallMethod(channel, "GetName")
        if ok then
            channelName = methodName
        end
    end
    if channel and channelName == SNOWBALL_NAME then
        return true, "channel"
    end

    return false, nil
end

local function IsLaunchAbilityReady(hero, launch)
    if not launch then
        return false, "launch ability missing"
    end

    local activated = Ability and Ability.IsActivated and SafeCall(Ability.IsActivated, launch)
    if activated == true then
        return true, "launch activated"
    end

    local castable = Ability and Ability.IsCastable and SafeCall(Ability.IsCastable, launch, NPC.GetMana(hero))
    local ready = Ability and Ability.IsReady and SafeCall(Ability.IsReady, launch)
    if castable == true and ready ~= false then
        return true, "launch castable"
    end

    if ready == true and castable ~= false then
        return true, "launch ready"
    end

    return false, string.format("launch not ready | activated=%s castable=%s ready=%s", tostring(activated), tostring(castable), tostring(ready))
end

local function GetSnowballLaunchReadyState(hero, snowball, launch)
    if IsSnowballRolling(hero) then
        return true, "modifier"
    end

    local channel = SafeCall(NPC and NPC.GetChannellingAbility, hero)
    local channelName = SafeCall(Ability and Ability.GetName, channel)
    if not channelName then
        local ok, methodName = TryCallMethod(channel, "GetName")
        if ok then
            channelName = methodName
        end
    end
    if channel and channelName == SNOWBALL_NAME then
        return true, "channel"
    end

    if snowball and IsAbilityInPhaseValue(snowball) then
        return false, "snowball ability_phase"
    end

    return IsLaunchAbilityReady(hero, launch)
end

local function WasSnowballCastAccepted(hero, snowball, pending)
    local active, activeReason = IsSnowballActive(hero, snowball)
    if active then
        return true, activeReason
    end

    if snowball and GetAbilityCooldownValue(snowball) > (pending.preCastCooldown or 0) + 0.05 then
        return true, "cooldown"
    end

    return false, "waiting for snowball state"
end

local function LogSnowballWait(pending, now, message)
    if now - (pending.lastSnowballWaitLog or -100) < SNOWBALL_WAIT_LOG_INTERVAL then
        return
    end

    pending.lastSnowballWaitLog = now
    LogDebug(message, true)
end

local function IssueSnowballTargetOrder(hero, snowball, enemy)
    local identifier = "tusk_kick_to_team_snowball"
    if Ability and Ability.CastTarget then
        local ok, err = pcall(Ability.CastTarget, snowball, enemy, false, true, true, identifier)
        if ok then
            return true, "Ability.CastTarget", identifier
        end
        return false, "Ability.CastTarget failed: " .. tostring(err)
    end

    local player = SafeCall(Players and Players.GetLocal)
    local ctx = GetResolvedOrderContext()
    if not (player and Player and Player.PrepareUnitOrders and ctx.castTarget and ctx.issuer) then
        return false, "target order API unavailable"
    end

    local targetPos = SafeCall(Entity and Entity.GetAbsOrigin, enemy) or Vector(0, 0, 0)
    local ok, err = pcall(
        Player.PrepareUnitOrders,
        player,
        ctx.castTarget,
        enemy,
        targetPos,
        snowball,
        ctx.issuer,
        hero,
        false,
        false,
        true,
        true,
        identifier,
        false
    )
    if ok then
        return true, "Player.PrepareUnitOrders:CAST_TARGET", identifier
    end

    return false, "Player.PrepareUnitOrders:CAST_TARGET failed: " .. tostring(err)
end

local function IssueSnowballNoTargetOrder(hero, ability, identifier, label)
    if Ability and Ability.CastNoTarget then
        local ok, err = pcall(Ability.CastNoTarget, ability, false, true, true, identifier)
        if ok then
            return true, "Ability.CastNoTarget:" .. label, identifier
        end
        return false, "Ability.CastNoTarget:" .. label .. " failed: " .. tostring(err)
    end

    local player = SafeCall(Players and Players.GetLocal)
    local ctx = GetResolvedOrderContext()
    if not (player and Player and Player.PrepareUnitOrders and ctx.castNoTarget and ctx.issuer) then
        return false, "no-target order API unavailable"
    end

    local ok, err = pcall(
        Player.PrepareUnitOrders,
        player,
        ctx.castNoTarget,
        nil,
        Vector(0, 0, 0),
        ability,
        ctx.issuer,
        hero,
        false,
        false,
        true,
        true,
        identifier,
        false
    )
    if ok then
        return true, "Player.PrepareUnitOrders:CAST_NO_TARGET:" .. label, identifier
    end

    return false, "Player.PrepareUnitOrders:CAST_NO_TARGET:" .. label .. " failed: " .. tostring(err)
end

local function TryCastSnowballLaunch(hero, snowball, pending)
    local launch, lookupSource = FindHeroAbilityByName(hero, SNOWBALL_LAUNCH_NAME)
    if not launch then
        LogSnowballWait(
            pending,
            GameRules.GetGameTime() or 0,
            string.format(
                "Snowball waiting for launch ability | name=%s lookup=%s state=%s",
                SNOWBALL_LAUNCH_NAME,
                tostring(lookupSource),
                "missing"
            )
        )
        return false, "launch ability missing"
    end

    local ready, readyReason = GetSnowballLaunchReadyState(hero, snowball, launch)
    if not ready then
        LogSnowballWait(
            pending,
            GameRules.GetGameTime() or 0,
            string.format(
                "Snowball waiting for launch ready | %s state=%s",
                DescribeAbilityState(hero, launch, lookupSource),
                tostring(readyReason)
            )
        )
        return false, readyReason or "launch not ready"
    end

    local attempt = (pending.launchAttempts or 0) + 1
    local launchIdentifier = "tusk_kick_to_team_snowball_launch." .. tostring(attempt)
    local issued, methodOrReason, identifier =
        IssueSnowballNoTargetOrder(hero, launch, launchIdentifier, SNOWBALL_LAUNCH_NAME)
    if issued then
        pending.launchAttempts = attempt
        LogDebug(
            string.format(
                "Snowball launch attempt pressed | attempt=%d/%d method=%s %s state=%s identifier=%s",
                attempt,
                SNOWBALL_LAUNCH_MAX_ATTEMPTS,
                tostring(methodOrReason),
                DescribeAbilityState(hero, launch, lookupSource),
                tostring(readyReason),
                tostring(identifier)
            ),
            true
        )
        return true, methodOrReason
    end

    LogSnowballWait(
        pending,
        GameRules.GetGameTime() or 0,
        string.format(
            "Snowball launch order failed | %s state=%s reason=%s",
            DescribeAbilityState(hero, launch, lookupSource),
            tostring(readyReason),
            tostring(methodOrReason)
        )
    )
    return false, methodOrReason or "launch unavailable"
end

local function ContinueSnowballLaunch(hero, snowball, pending, now)
    if not pending.launchExpireTime then
        pending.launchExpireTime = now + SNOWBALL_LAUNCH_RETRY_WINDOW
    end

    if (pending.launchAttempts or 0) >= SNOWBALL_LAUNCH_MAX_ATTEMPTS or now > pending.launchExpireTime then
        LogDebug(
            string.format(
                "Snowball launch retry window complete | attempts=%d target=%s reason=%s",
                pending.launchAttempts or 0,
                tostring(pending.enemyName),
                (pending.launchAttempts or 0) >= SNOWBALL_LAUNCH_MAX_ATTEMPTS and "max_attempts" or "timeout"
            ),
            true
        )
        ClearSnowballCombo()
        return true
    end

    local pressed, launchReason = TryCastSnowballLaunch(hero, snowball, pending)
    if pressed and (pending.launchAttempts or 0) >= SNOWBALL_LAUNCH_MAX_ATTEMPTS then
        LogDebug(
            string.format(
                "Snowball launch retry window complete | attempts=%d target=%s",
                pending.launchAttempts or 0,
                tostring(pending.enemyName)
            ),
            true
        )
        ClearSnowballCombo()
        return true
    end

    pending.lastFailureReason = launchReason
    pending.dueTime = now + SNOWBALL_LAUNCH_RETRY_INTERVAL
    return true
end

local function TryProcessSnowballCombo(hero, now)
    local pending = State.pendingSnowballCombo
    if not pending then
        return false
    end

    if now > (pending.expireTime or 0) then
        LogDebug(
            string.format(
                "Snowball combo expired | phase=%s target=%s reason=%s",
                tostring(pending.phase),
                tostring(pending.enemyName),
                tostring(pending.lastFailureReason or "timeout")
            ),
            true
        )
        ClearSnowballCombo()
        return false
    end

    local enemy, targetReason = ResolveTrackedEnemy(hero, pending)
    if not enemy then
        LogDebug("Snowball combo cancelled | " .. tostring(targetReason), true)
        ClearSnowballCombo()
        return false
    end

    if now < (pending.dueTime or 0) then
        return true
    end

    local snowball = NPC.GetAbility(hero, SNOWBALL_NAME)
    if pending.phase == "cast" then
        local kick = NPC.GetAbility(hero, ABILITY_NAME)
        local lockActive, lockReason = GetPostOrderLockStatus(kick)
        if lockActive then
            pending.dueTime = now + SNOWBALL_CAST_RETRY_INTERVAL
            LogSnowballWait(
                pending,
                now,
                "Snowball waiting after kick | target=" .. DescribeUnit(enemy) .. " reason=" .. tostring(lockReason)
            )
            return true
        end

        local range = GetSnowballCastRange(hero, snowball)
        local blockReason = GetTargetAbilityBlockReason(hero, snowball, enemy, range)
        if blockReason then
            LogDebug(
                string.format(
                    "Snowball cast blocked | target=%s reason=%s",
                    DescribeUnit(enemy),
                    tostring(blockReason)
                ),
                true
            )
            ClearSnowballCombo()
            return false
        end

        LogDebug(
            string.format("Snowball ability found | ability=%s target=%s", SNOWBALL_NAME, DescribeUnit(enemy)),
            true
        )

        pending.preCastCooldown = GetAbilityCooldownValue(snowball)
        local issued, methodOrReason, identifier = IssueSnowballTargetOrder(hero, snowball, enemy)
        if not issued then
            LogDebug("Snowball cast order failed | " .. tostring(methodOrReason), true)
            ClearSnowballCombo()
            return false
        end

        LogDebug(
            string.format(
                "Snowball cast order issued | method=%s ability=%s target=%s identifier=%s",
                tostring(methodOrReason),
                SNOWBALL_NAME,
                DescribeUnit(enemy),
                tostring(identifier)
            ),
            true
        )
        pending.phase = "confirm_cast"
        pending.castIssuedAt = now
        pending.castConfirmUntil = now + SNOWBALL_CAST_CONFIRM_TIMEOUT
        pending.dueTime = now + SNOWBALL_CAST_RETRY_INTERVAL
        return true
    end

    if pending.phase == "confirm_cast" then
        local accepted, acceptReason = WasSnowballCastAccepted(hero, snowball, pending)
        if accepted then
            pending.phase = "launch"
            pending.launchAttempts = 0
            pending.launchStartedAt = now
            pending.launchExpireTime = now + SNOWBALL_LAUNCH_RETRY_WINDOW
            LogDebug(
                string.format(
                    "Snowball waiting for launch ability/state | state=%s target=%s",
                    tostring(acceptReason),
                    DescribeUnit(enemy)
                ),
                true
            )

            return ContinueSnowballLaunch(hero, snowball, pending, now)
        end

        if now >= (pending.castConfirmUntil or pending.expireTime or 0) then
            LogDebug(
                string.format(
                    "Snowball combo expired | phase=confirm_cast reason=%s target=%s",
                    tostring(acceptReason),
                    DescribeUnit(enemy)
                ),
                true
            )
            ClearSnowballCombo()
            return false
        end

        pending.dueTime = now + SNOWBALL_CAST_RETRY_INTERVAL
        LogSnowballWait(
            pending,
            now,
            "Snowball waiting for launch ability/state | reason=" .. tostring(acceptReason) .. " target=" .. DescribeUnit(enemy)
        )
        return true
    end

    if pending.phase == "launch" then
        return ContinueSnowballLaunch(hero, snowball, pending, now)
    end

    ClearSnowballCombo()
    return false
end

local function BuildPreparedOrder(order, target, position, kick, issuer, hero, identifier)
    return {
        order = order,
        target = target,
        position = position,
        ability = kick,
        issuer = issuer,
        npc = hero,
        queue = false,
        showEffects = false,
        identifier = identifier,
    }
end

local function TryPrepareUnitOrdersStaticPositional(player, order, target, position, kick, issuer, hero, identifier)
    if not (Player and Player.PrepareUnitOrders) then
        return false, "Player.PrepareUnitOrders missing"
    end

    local pos = position or Vector(0, 0, 0)

    local ok, err = pcall(
        Player.PrepareUnitOrders,
        player,
        order,
        target,
        pos,
        kick,
        issuer,
        hero,
        false,
        false,
        false,
        false,
        identifier
    )

    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function TryPrepareUnitOrdersStaticTable(player, order, target, position, kick, issuer, hero, identifier)
    if not (Player and Player.PrepareUnitOrders) then
        return false, "Player.PrepareUnitOrders missing"
    end

    local ok, err =
        pcall(Player.PrepareUnitOrders, player, BuildPreparedOrder(order, target, position, kick, issuer, hero, identifier))
    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function TryPrepareUnitOrdersMethodTable(player, order, target, position, kick, issuer, hero, identifier)
    local ok, err =
        TryCallMethod(player, "PrepareUnitOrders", BuildPreparedOrder(order, target, position, kick, issuer, hero, identifier))
    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function MarkPendingOrder(methodName, identifier)
    State.pendingOrderUntil = GameRules.GetGameTime() + 0.40
end

local function GetPlayerActiveAbility(player)
    if not player then
        return nil
    end

    if Player and Player.GetActiveAbility then
        local ok, ability = pcall(Player.GetActiveAbility, player)
        if ok then
            return ability
        end
    end

    local ok, ability = TryCallMethod(player, "GetActiveAbility")
    if ok then
        return ability
    end

    return nil
end

local function GetAbilityNameSafe(ability)
    if not ability then
        return nil
    end

    if Ability and Ability.GetName then
        local ok, value = pcall(Ability.GetName, ability)
        if ok and value then
            return value
        end
    end

    local ok, value = TryCallMethod(ability, "GetName")
    if ok and value then
        return value
    end

    return nil
end

local function IsSameAbilityRef(a, b)
    if not a or not b then
        return false
    end

    if a == b then
        return true
    end

    local aName = GetAbilityNameSafe(a)
    local bName = GetAbilityNameSafe(b)
    return aName ~= nil and aName == bName
end

local function QueueVectorFollowup(player, playerSource, hero, kick, plan, ctx)
    State.pendingVectorStep = {
        player = player,
        playerSource = playerSource,
        hero = hero,
        kick = kick,
        enemy = plan.enemy,
        vectorPos = plan.vectorPos,
        order = ctx.vectorTargetPosition,
        issuer = ctx.issuer,
        dueTime = GameRules.GetGameTime() + 0.03,
        expireTime = GameRules.GetGameTime() + 0.25,
        identifier = "tusk_kick_to_team_vector_followup",
    }
end

local function ClearVectorFollowup()
    State.pendingVectorStep = nil
end

local function TryIssuePrepareOrderAny(player, order, target, position, kick, issuer, hero, identifier, label, errors)
    local okStaticPos, errStaticPos =
        TryPrepareUnitOrdersStaticPositional(player, order, target, position, kick, issuer, hero, identifier)
    if okStaticPos then
        MarkPendingOrder("prepare_static_positional:" .. label, identifier)
        return true, "prepare_static_positional:" .. label
    end
    errors[#errors + 1] = label .. " static_positional=" .. tostring(errStaticPos)

    local okStaticTable, errStaticTable =
        TryPrepareUnitOrdersStaticTable(player, order, target, position, kick, issuer, hero, identifier)
    if okStaticTable then
        MarkPendingOrder("prepare_static_table:" .. label, identifier)
        return true, "prepare_static_table:" .. label
    end
    errors[#errors + 1] = label .. " static_table=" .. tostring(errStaticTable)

    local okMethodTable, errMethodTable =
        TryPrepareUnitOrdersMethodTable(player, order, target, position, kick, issuer, hero, identifier)
    if okMethodTable then
        MarkPendingOrder("prepare_method_table:" .. label, identifier)
        return true, "prepare_method_table:" .. label
    end
    errors[#errors + 1] = label .. " method_table=" .. tostring(errMethodTable)

    return false, nil
end

local function TryProcessVectorFollowup()
    local pending = State.pendingVectorStep
    if not pending then
        return false
    end

    local now = GameRules.GetGameTime()
    if now < (pending.dueTime or 0) then
        return true
    end

    if now > (pending.expireTime or 0) then
        ClearVectorFollowup()
        return true
    end

    local activeAbility = GetPlayerActiveAbility(pending.player)

    if activeAbility and not IsSameAbilityRef(activeAbility, pending.kick) then
        ClearVectorFollowup()
        return true
    end

    local errors = {}
    local okTargetNil = TryIssuePrepareOrderAny(
        pending.player,
        pending.order,
        nil,
        pending.vectorPos,
        pending.kick,
        pending.issuer,
        pending.hero,
        pending.identifier .. "_nil_target",
        "vector_followup_nil_target",
        errors
    )
    if okTargetNil then
        State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(pending.kick)
        QueueSnowballCombo(pending.enemy, "vector_followup_nil_target")
        ClearVectorFollowup()
        return true
    end

    local okTargetEnemy = TryIssuePrepareOrderAny(
        pending.player,
        pending.order,
        pending.enemy,
        pending.vectorPos,
        pending.kick,
        pending.issuer,
        pending.hero,
        pending.identifier .. "_enemy_target",
        "vector_followup_enemy_target",
        errors
    )
    if okTargetEnemy then
        State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(pending.kick)
        QueueSnowballCombo(pending.enemy, "vector_followup_enemy_target")
        ClearVectorFollowup()
        return true
    end

    ClearVectorFollowup()
    return true
end

local function IssueKickOrder(hero, kick, plan)
    local player, playerSource = GetPlayerForHero(hero)
    local ctx = GetResolvedOrderContext()
    local compatText = DescribeCompat(ctx, player, playerSource)
    local issuer = ctx.issuer
    local orderCandidates = {}
    local errors = {}

    if ctx.castTargetPosition ~= nil then
        orderCandidates[#orderCandidates + 1] = {
            label = "cast_target_position",
            value = ctx.castTargetPosition,
        }
    end

    if ctx.vectorTargetPosition ~= nil and ctx.vectorTargetPosition ~= ctx.castTargetPosition then
        orderCandidates[#orderCandidates + 1] = {
            label = "vector_target_position",
            value = ctx.vectorTargetPosition,
        }
    end

    if not player then
        errors[#errors + 1] = "player unavailable (" .. tostring(playerSource) .. ")"
    end

    if #orderCandidates == 0 then
        errors[#errors + 1] = "no order enum (" .. compatText .. ")"
    end

    if issuer == nil then
        errors[#errors + 1] = "no order issuer (" .. compatText .. ")"
    end

    if player and issuer ~= nil and #orderCandidates > 0 then
        if ctx.castTarget ~= nil and ctx.vectorTargetPosition ~= nil then
            local okTargetStage, targetStageReason = TryIssuePrepareOrderAny(
                player,
                ctx.castTarget,
                plan.enemy,
                Vector(0, 0, 0),
                kick,
                issuer,
                hero,
                "tusk_kick_to_team_cast_target_start",
                "cast_target_start",
                errors
            )
            if okTargetStage then
                QueueVectorFollowup(player, playerSource, hero, kick, plan, ctx)
                return true, "prepare_stage1_cast_target"
            end
        end

        for i = 1, #orderCandidates do
            local candidate = orderCandidates[i]
            local identifier = "tusk_kick_to_team_" .. candidate.label

            local okAny, reasonAny = TryIssuePrepareOrderAny(
                player,
                candidate.value,
                plan.enemy,
                plan.vectorPos,
                kick,
                issuer,
                hero,
                identifier,
                candidate.label,
                errors
            )
            if okAny then
                State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(kick)
                QueueSnowballCombo(plan.enemy, tostring(reasonAny))
                return true, tostring(reasonAny)
            end
        end
    end

    do
        local okVectorMethod, errVectorMethod =
            TryCallMethod(hero, "CastAbilityVector", kick, plan.enemyPos, plan.vectorPos)
        if okVectorMethod then
            State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(kick)
            QueueSnowballCombo(plan.enemy, "npc_method_vector")
            return true, "npc_method_vector"
        end
        errors[#errors + 1] = "hero:CastAbilityVector=" .. tostring(errVectorMethod)
    end

    if NPC and NPC.CastAbilityVector then
        local ok, err = pcall(NPC.CastAbilityVector, hero, kick, plan.enemyPos, plan.vectorPos)
        if ok then
            State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(kick)
            QueueSnowballCombo(plan.enemy, "npc_static_vector")
            return true, "npc_static_vector"
        end

        errors[#errors + 1] = "NPC.CastAbilityVector=" .. tostring(err)
    else
        errors[#errors + 1] = "NPC.CastAbilityVector unavailable"
    end

    return false, table.concat(errors, " | ")
end

local function ClearBlinkKickCombo()
    State.pendingBlinkKick = nil
end

local function GetBlink(hero)
    for _, itemName in ipairs(BLINK_ITEMS) do
        local blink = SafeCall(NPC and NPC.GetItem, hero, itemName, true)
        if blink then
            return blink, itemName
        end
    end

    return nil, nil
end

local function CanCastBlink(hero, blink)
    if not blink then
        return false, "blink item missing"
    end

    if Ability.IsReady and not Ability.IsReady(blink) then
        return false, "blink cooldown"
    end

    if Ability.IsCastable and not Ability.IsCastable(blink, NPC.GetMana(hero)) then
        return false, "blink not castable"
    end

    return true, "ok"
end

local function GetBlinkRange(hero, blink)
    return GetAbilityRangeWithBonus(hero, blink, DEFAULT_BLINK_RANGE)
end

local function ComputeBindBlinkPosition(hero, kick, blink, plan)
    if not hero or not kick or not blink or not plan or not plan.enemy then
        return nil
    end

    local origin = Entity.GetAbsOrigin(hero)
    local enemyPos = Entity.GetAbsOrigin(plan.enemy)
    if not origin or not enemyPos then
        return nil
    end

    local toEnemy = enemyPos - origin
    local distance = toEnemy:Length2D()
    if distance <= BIND_BLINK_MIN_DISTANCE then
        return nil
    end

    local kickRange = GetKickRange(hero, kick)
    local blinkRange = GetBlinkRange(hero, blink)
    local landingEnemyDistance = math.max(100, math.min(kickRange - 35, kickRange * 0.60))
    if landingEnemyDistance <= 0 then
        landingEnemyDistance = math.max(100, kickRange * 0.60)
    end

    local dirX = toEnemy.x / distance
    local dirY = toEnemy.y / distance
    local blinkPos = Vector(
        enemyPos.x - dirX * landingEnemyDistance,
        enemyPos.y - dirY * landingEnemyDistance,
        origin.z
    )

    local blinkDistance = origin:Distance2D(blinkPos)
    if blinkDistance > blinkRange then
        local cappedDistance = math.max(0, blinkRange - BIND_BLINK_RANGE_MARGIN)
        blinkPos = Vector(
            origin.x + dirX * cappedDistance,
            origin.y + dirY * cappedDistance,
            origin.z
        )
    end

    if origin:Distance2D(blinkPos) <= BIND_BLINK_MIN_DISTANCE then
        return nil
    end

    if blinkPos:Distance2D(enemyPos) > kickRange + 25 then
        return nil
    end

    return MakeGroundPosition(blinkPos)
end

local function CastBlinkToPosition(blink, position)
    if not blink or not position then
        return false
    end

    SafeCall(Ability.CastPosition, blink, position, false, true, true, "tusk_kick_to_team_blink", true)
    LogDebug("Bind sequence started | Blink -> Walrus Kick -> Snowball", true)
    return true
end

local function RebuildPlanForEnemy(hero, pending)
    if not pending or not pending.enemy or not pending.plan then
        return nil
    end

    local allies = CollectUnits(hero, true)
    if #allies == 0 then
        return nil
    end

    local enemyPos = Entity.GetAbsOrigin(pending.enemy)
    if not enemyPos then
        return nil
    end

    return BuildPlan(hero, { hero = pending.enemy, pos = enemyPos }, allies, pending.plan.desiredPos, {
        strategy = pending.plan.strategy or "blink",
        clusterCount = pending.plan.clusterCount or 1,
        lineWidth = AUTO_CLUSTER_RADIUS,
    })
end

local function TryProcessBlinkKickCombo(hero, kick, now)
    local pending = State.pendingBlinkKick
    if not pending then
        return false
    end

    if now > (pending.expireTime or 0) then
        LogDebug("Bind blink combo expired before kick | target=" .. DescribeUnit(pending.enemy), true)
        ClearBlinkKickCombo()
        return false
    end

    if now < (pending.readyAfter or 0) then
        return true
    end

    if not IsEnemyTargetValid(hero, pending.enemy) then
        LogDebug("Bind blink combo cancelled | target invalid=" .. DescribeUnit(pending.enemy), true)
        ClearBlinkKickCombo()
        return false
    end

    local canCast, reason = CanAutoCastKick(hero, kick)
    if not canCast then
        LogDebug("Bind blink combo cancelled | kick unavailable: " .. tostring(reason), true)
        ClearBlinkKickCombo()
        return false
    end

    local plan = RebuildPlanForEnemy(hero, pending) or pending.plan
    local enemyPos = Entity.GetAbsOrigin(plan.enemy)
    local heroPos = Entity.GetAbsOrigin(hero)
    if not enemyPos or not heroPos or heroPos:Distance2D(enemyPos) > GetKickRange(hero, kick) + 25 then
        LogDebug(
            string.format(
                "Bind blink combo waiting | target range=%.0f kickRange=%.0f",
                enemyPos and heroPos and heroPos:Distance2D(enemyPos) or -1,
                GetKickRange(hero, kick)
            )
        )
        return true
    end

    local issued, issueReason = IssueKickOrder(hero, kick, plan)
    ClearBlinkKickCombo()
    if issued then
        LogDebug("Bind blink combo issued kick | method=" .. tostring(issueReason), true)
        State.lastCastTime = now
        return true
    end

    LogDebug("Bind blink combo failed to issue kick | " .. tostring(issueReason), true)
    return false
end

local function TryStartBindBlinkCombo(hero, kick, now, currentPlan)
    local blink, blinkName = GetBlink(hero)
    local canBlink, blinkReason = CanCastBlink(hero, blink)
    if not canBlink then
        LogDebug("Bind blink unavailable | " .. tostring(blinkReason))
        return false
    end

    local kickRange = GetKickRange(hero, kick)
    local blinkRange = GetBlinkRange(hero, blink)
    local scanDistance = blinkRange + kickRange - BIND_BLINK_RANGE_MARGIN
    local blinkPlan, planReason = FindBestPlan(hero, kick, scanDistance)
    blinkPlan = blinkPlan or currentPlan
    if not blinkPlan then
        LogDebug(
            string.format(
                "Bind blink skipped | no target in blink+kick scan=%.0f reason=%s",
                scanDistance,
                tostring(planReason)
            ),
            true
        )
        return false
    end

    local blinkPos = ComputeBindBlinkPosition(hero, kick, blink, blinkPlan)
    if not blinkPos then
        LogDebug(
            string.format(
                "Bind blink skipped | invalid blink position item=%s target=%s kickRange=%.0f blinkRange=%.0f",
                tostring(blinkName),
                DescribeUnit(blinkPlan.enemy),
                kickRange,
                blinkRange
            ),
            true
        )
        return false
    end

    if not CastBlinkToPosition(blink, blinkPos) then
        LogDebug("Bind blink cast failed | item=" .. tostring(blinkName), true)
        return false
    end

    ClearVectorFollowup()
    ClearSnowballCombo()
    State.pendingBlinkKick = {
        enemy = blinkPlan.enemy,
        plan = blinkPlan,
        readyAfter = now + BIND_BLINK_AFTER_DELAY,
        expireTime = now + BIND_BLINK_KICK_EXPIRE,
    }

    LogDebug(
        string.format(
            "Bind blink queued kick | item=%s target=%s scan=%.0f",
            tostring(blinkName),
            DescribeUnit(blinkPlan.enemy),
            scanDistance
        ),
        true
    )
    return true
end

local function GetCastModeState()
    local mode = UI.Mode:Get() or MODE_AUTO
    if mode ~= MODE_BIND then
        return {
            mode = mode,
            isBindMode = false,
            shouldCast = true,
            bindPressed = false,
            reason = "auto mode",
        }
    end

    if Input and Input.IsInputCaptured and SafeCall(Input.IsInputCaptured) then
        return {
            mode = mode,
            isBindMode = true,
            shouldCast = false,
            bindPressed = false,
            reason = "input captured",
        }
    end

    if not UI.CastKey or not UI.CastKey.IsPressed then
        return {
            mode = mode,
            isBindMode = true,
            shouldCast = false,
            bindPressed = false,
            reason = "bind widget unavailable",
        }
    end

    local pressed = UI.CastKey:IsPressed() == true
    return {
        mode = mode,
        isBindMode = true,
        shouldCast = pressed,
        bindPressed = pressed,
        reason = pressed and "bind pressed" or "bind not pressed",
    }
end

local function LogKickUnavailable(reason)
    reason = tostring(reason)
    local now = GameRules and GameRules.GetGameTime and (GameRules.GetGameTime() or 0) or os.clock()
    if reason == "kick not activated" then
        if
            State.lastKickUnavailableReason == reason
            and now - State.lastKickUnavailableLogTime < KICK_UNAVAILABLE_LOG_INTERVAL
        then
            return
        end

        State.lastKickUnavailableReason = reason
        State.lastKickUnavailableLogTime = now
    end

    LogDebug("Bind blocked | Walrus Kick unavailable: " .. reason, true)
end

--#region Kick Preview

local function ClearKickPreview()
    State.kickPreview = nil
end

local function WorldToScreenPos(worldPos)
    if not worldPos or not Render or not Render.WorldToScreen then
        return nil, false
    end

    local ok, screenPos, visible = pcall(Render.WorldToScreen, worldPos)
    if not ok or not screenPos then
        return nil, false
    end

    if type(screenPos.x) ~= 'number' or type(screenPos.y) ~= 'number' then
        return nil, false
    end

    return screenPos, visible ~= false
end

local function DrawPreviewLine(from, to, coreColor, glowColor, coreWidth, glowWidth)
    if not from or not to or not Render or not Render.Line then
        return
    end

    if glowWidth and glowWidth > 0 and glowColor then
        Render.Line(from, to, glowColor, glowWidth)
    end
    Render.Line(from, to, coreColor, coreWidth or 1.5)
end

local function DrawWorldRing(worldPos, radius, color, segments)
    if not worldPos or not color or not Render then
        return
    end

    segments = segments or PREVIEW_RING_SEGMENTS
    local prevScreen, prevVisible = nil, false
    local ground = MakeGroundPosition(worldPos) or worldPos

    for i = 0, segments do
        local angle = (i / segments) * math.pi * 2
        local point = Vector(
            ground.x + math.cos(angle) * radius,
            ground.y + math.sin(angle) * radius,
            ground.z
        )
        local screen, visible = WorldToScreenPos(point)
        if visible and prevVisible then
            DrawPreviewLine(prevScreen, screen, color, ColorWithAlpha(color, 40), 1.6, 4.0)
        end
        prevScreen = screen
        prevVisible = visible
    end
end

local function DrawPreviewArrow(fromScreen, toScreen, color)
    if not fromScreen or not toScreen or not Render or not Render.FilledTriangle then
        return
    end

    local dx = toScreen.x - fromScreen.x
    local dy = toScreen.y - fromScreen.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 8 then
        return
    end

    local ux, uy = dx / len, dy / len
    local px, py = -uy, ux
    local tip = toScreen
    local base = Vec2(toScreen.x - ux * PREVIEW_ARROW_LEN, toScreen.y - uy * PREVIEW_ARROW_LEN)
    local left = Vec2(base.x + px * (PREVIEW_ARROW_WIDTH * 0.5), base.y + py * (PREVIEW_ARROW_WIDTH * 0.5))
    local right = Vec2(base.x - px * (PREVIEW_ARROW_WIDTH * 0.5), base.y - py * (PREVIEW_ARROW_WIDTH * 0.5))

    Render.FilledTriangle({ tip, left, right }, color)
end

local function DrawKickPreviewMarker(screen, color, radius)
    if not screen or not color or not Render then
        return
    end

    if Render.Circle then
        Render.Circle(screen, radius + 4, ColorWithAlpha(color, 45), 1.5)
        Render.Circle(screen, radius, ColorWithAlpha(color, 210), 1.6)
    end
    if Render.FilledCircle then
        Render.FilledCircle(screen, math.max(2.5, radius * 0.35), ColorWithAlpha(color, 230))
    end
end

local function GetTargetPreviewScanDistance(hero, kick)
    local scanDistance = GetKickRange(hero, kick) + 25
    local modeState = GetCastModeState()

    if not modeState.isBindMode then
        return scanDistance
    end

    local blink = select(1, GetBlink(hero))
    local canBlink = CanCastBlink(hero, blink)
    if not canBlink then
        return scanDistance
    end

    return math.max(
        scanDistance,
        GetBlinkRange(hero, blink) + BIND_BLINK_RANGE_MARGIN + GetKickRange(hero, kick)
    )
end

local function RefreshKickPreview(force)
    if not UI.Enabled:Get() or not Engine.IsInGame() then
        ClearKickPreview()
        return
    end

    if UI.DrawPreview and UI.DrawPreview.Get and UI.DrawPreview:Get() ~= true then
        ClearKickPreview()
        return
    end

    local hero = Heroes.GetLocal()
    if not IsTusk(hero) then
        ClearKickPreview()
        return
    end

    local now = GameRules.GetGameTime() or 0
    if not force and now - State.lastTargetVisualTime < TARGET_VISUAL_UPDATE_INTERVAL then
        return
    end
    State.lastTargetVisualTime = now

    local kick = NPC.GetAbility(hero, ABILITY_NAME)
    local canEval = CanEvaluateKick(hero, kick)
    if not canEval then
        ClearKickPreview()
        return
    end

    local plan = FindBestPlan(hero, kick, GetTargetPreviewScanDistance(hero, kick))
    if not plan or not IsValidHeroUnit(plan.enemy) or not plan.enemyPos or not plan.endPos then
        ClearKickPreview()
        return
    end

    State.kickPreview = {
        enemyPos = plan.enemyPos,
        endPos = plan.endPos,
        desiredPos = plan.desiredPos,
    }
end

local function DrawKickPreviewOverlay()
    local preview = State.kickPreview
    if not preview or not preview.enemyPos or not preview.endPos then
        return
    end

    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local accent = Colors.BorderEnabled or Colors.TextHeader
    local quiet = Colors.Quiet or ColorWithAlpha(accent, 140)
    local enemyScreen, enemyVisible = WorldToScreenPos(preview.enemyPos)
    local endScreen, endVisible = WorldToScreenPos(preview.endPos)

    if enemyVisible and endVisible then
        DrawPreviewLine(
            enemyScreen,
            endScreen,
            ColorWithAlpha(accent, 220),
            ColorWithAlpha(accent, 55),
            1.8,
            5.0
        )
        DrawPreviewArrow(enemyScreen, endScreen, ColorWithAlpha(accent, 235))
    end

    if enemyVisible then
        DrawKickPreviewMarker(enemyScreen, accent, 7)
    end

    DrawWorldRing(preview.endPos, PREVIEW_LANDING_RADIUS, ColorWithAlpha(accent, 170), PREVIEW_RING_SEGMENTS)

    if preview.desiredPos then
        DrawWorldRing(preview.desiredPos, PREVIEW_ALLY_RADIUS, ColorWithAlpha(quiet, 150), 20)
        local allyScreen, allyVisible = WorldToScreenPos(preview.desiredPos)
        if allyVisible then
            DrawKickPreviewMarker(allyScreen, quiet, 5)
        end
    end

    if endVisible then
        DrawKickPreviewMarker(endScreen, accent, 5)
    end
end

--#endregion

--#region Panel

function Script.OnDraw()
    if not Engine.IsInGame() or not UI.Enabled:Get() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local myHero = Heroes.GetLocal()
    if not IsTusk(myHero) then
        return
    end

    DrawKickPreviewOverlay()

    if not UI.DrawPanel:Get() then
        return
    end

    local numAllies = #State.matchAllyNames
    if numAllies == 0 then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, numAllies, screenSize)
    local mx, my = GetMousePos()
    local isDown = IsLmbDown()
    local isClicked = isDown and not State.wasMousePressed
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
        layout = GetPanelLayout(scale, numAllies, screenSize)
    end

    local clickTriggered = isClicked
    if clickTriggered and Input.IsInputCaptured and SafeCall(Input.IsInputCaptured) then
        clickTriggered = false
    end
    State.wasMousePressed = isDown

    local titleText = layout.titleText or GetPanelTitleText()
    local titleFontSize = layout.titleFontSize or (PANEL_HEADER_TEXT_SIZE * scale)
    local titleSize = layout.titleSize
        or MeasurePanelTextSize(titleFontSize, titleText)
        or Vec2(titleText:len() * titleFontSize * 0.55, titleFontSize)
    local titleSizeY = titleSize.y or titleFontSize
    local titleIconSize = layout.titleIconSize or Vec2(0, titleSizeY)
    local titleIconGap = layout.titleIconGap or 0
    local titleIconH = titleIconSize.y or math.floor(PANEL_HEADER_ICON_SIZE * scale + 0.5)
    local titleContentH = math.max(titleSizeY, layout.hasTitleIcon and titleIconH or 0)
    local titleContentY = layout.y + math.floor((layout.titleH - titleContentH) * 0.5 + 0.5)
    local textX = layout.x + layout.padX
    local textY = titleContentY + math.floor((titleContentH - titleSizeY) * 0.5 + 0.5)
    local cellRadius = PANEL_CELL_RADIUS * scale

    DrawPanelHeaderShadow(layout, scale)
    DrawPanelBlur(layout, scale)

    Render.FilledRect(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        Colors.HeaderBg,
        PANEL_HEADER_RADIUS * scale)

    if layout.hasTitleIcon and State.spellIcon then
        local iconSize = titleIconH
        local iconY = titleContentY + math.floor((titleContentH - iconSize) * 0.5 + 0.5)
        Render.Image(
            State.spellIcon,
            Vec2(textX, iconY),
            Vec2(iconSize, iconSize),
            Color(255, 255, 255, 255),
            4 * scale,
            Enum.DrawFlags.None)
        textX = textX + iconSize + titleIconGap
    end

    DrawPanelText(
        titleFontSize,
        titleText,
        Vec2(textX, textY),
        Colors.TextHeader)

    local borderColor = GetChipBorderColor()

    for i, cleanName in ipairs(State.matchAllyNames) do
        local cellX = layout.cellsStartX + (i - 1) * (layout.cellW + layout.cellSpacing)
        local allyHero = State.cachedAllyEntities[cleanName]
        local enabled = IsAllyKickEnabled(cleanName)
        local imgAlpha = enabled and PANEL_CHIP_ENABLED_ALPHA or PANEL_CHIP_DISABLED_ALPHA
        local grayscale = enabled and 0.0 or 1.0

        local isCellHovered = isCursorValid
            and mx >= cellX and mx <= cellX + layout.cellW
            and my >= layout.rowY and my <= layout.rowY + layout.cellH

        local heroNameRaw = State.cachedAllyUnitNames[cleanName]
            or (allyHero and SafeCall(NPC.GetUnitName, allyHero))
            or ""
        local imgHandle = GetHeroIcon(heroNameRaw)

        Render.FilledRect(
            Vec2(cellX, layout.rowY),
            Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
            Colors.CellBg,
            cellRadius)

        if imgHandle then
            Render.Image(
                imgHandle,
                Vec2(cellX, layout.rowY),
                Vec2(layout.cellW, layout.cellH),
                Color(255, 255, 255, imgAlpha),
                cellRadius,
                Enum.DrawFlags.None,
                Vec2(0, 0),
                Vec2(1, 1),
                grayscale)
        end

        if enabled then
            Render.Rect(
                Vec2(cellX, layout.rowY),
                Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
                borderColor,
                cellRadius,
                Enum.DrawFlags.None,
                1.3)
        end

        if isCellHovered and clickTriggered and not PanelDrag.IsDragging then
            SetAllyKickEnabled(cleanName, not enabled)
        end
    end
end

function Script.OnKeyEvent(_data, key, _event)
    if not Engine.IsInGame() or not UI.Enabled:Get() or not UI.DrawPanel:Get() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local myHero = Heroes.GetLocal()
    if not IsTusk(myHero) then
        return
    end

    if #State.matchAllyNames == 0 then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, #State.matchAllyNames, screenSize)
    local mx, my = GetMousePos()
    local isCursorOverPanel = mx and my
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.height

    if isCursorOverPanel or PanelDrag.IsDragging then
        if key == Enum.ButtonCode.KEY_MOUSE1
            or key == Enum.ButtonCode.KEY_MOUSE2
            or key == Enum.ButtonCode.KEY_MOUSE3
            or key == Enum.ButtonCode.KEY_MWHEELUP
            or key == Enum.ButtonCode.KEY_MWHEELDOWN then
            return false
        end
    end
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    LoadPanelPosition()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_SAMPLE) or 0
    State.lastAllySyncTime = -100
    State.panelHeaderFaFont = nil
    State.panelHeaderFaAvailable = nil

    if Engine.IsInGame() then
        local hero = Heroes.GetLocal()
        if IsTusk(hero) then
            SyncAllyTargets(hero, GameRules.GetGameTime() or 0)
        end
    end

    Log("info", "loaded")
end

function Script.OnUpdate()
    State.bestPlan = nil

    local function RunKickLogic()
        if not Engine.IsInGame() then
            ClearVectorFollowup()
            ClearBlinkKickCombo()
            ClearSnowballCombo()
            ClearKickPreview()
            return
        end

    local hero = Heroes.GetLocal()
    if not hero then
        ClearVectorFollowup()
        ClearBlinkKickCombo()
        ClearSnowballCombo()
        ClearKickPreview()
        LogDebug("Bind blocked | local hero missing")
        return
    end

    if not IsTusk(hero) then
        ClearVectorFollowup()
        ClearBlinkKickCombo()
        ClearSnowballCombo()
        ClearKickPreview()
        LogDebug("Bind blocked | local hero is not Tusk: " .. tostring(SafeCall(NPC and NPC.GetUnitName, hero)))
        return
    end

    local now = GameRules.GetGameTime() or 0
    SyncAllyTargets(hero, now)

    if not UI.Enabled:Get() then
        ClearVectorFollowup()
        ClearBlinkKickCombo()
        ClearSnowballCombo()
        ClearKickPreview()
        return
    end

    RefreshKickPreview()

        if TryProcessSnowballCombo(hero, now) then
            return
        end

        local kick = NPC.GetAbility(hero, ABILITY_NAME)
        local canEval, evalReason = CanEvaluateKick(hero, kick)
        if not canEval then
            ClearVectorFollowup()
            ClearBlinkKickCombo()
            if evalReason == "kick not activated" then
                local snowball = NPC.GetAbility(hero, SNOWBALL_NAME)
                if IsSnowballActive(hero, snowball) then
                    return
                end
            end
            LogKickUnavailable(evalReason)
            return
        end

        if TryProcessVectorFollowup() then
            return
        end

        if TryProcessBlinkKickCombo(hero, kick, now) then
            return
        end

        local modeState = GetCastModeState()
        if not modeState.shouldCast then
            if modeState.isBindMode then
                LogDebug(
                    string.format(
                        "Bind idle | mode=Bind pressed=%s reason=%s",
                        tostring(modeState.bindPressed),
                        tostring(modeState.reason)
                    )
                )
            end
            return
        end

        local lockActive, lockReason = GetPostOrderLockStatus(kick)
        if lockActive then
            if modeState.isBindMode then
                LogDebug("Bind blocked | order throttle: " .. tostring(lockReason))
            end
            return
        end

        local canCast, castReason = CanAutoCastKick(hero, kick)
        if not canCast then
            if modeState.isBindMode then
                LogDebug("Bind blocked | Walrus Kick not castable: " .. tostring(castReason), true)
            end
            return
        end

        if now - State.lastCastTime < CAST_THROTTLE then
            if modeState.isBindMode then
                LogDebug(
                    string.format(
                        "Bind blocked | cast throttle left=%.2f",
                        math.max(0, CAST_THROTTLE - (now - State.lastCastTime))
                    )
                )
            end
            return
        end

        if modeState.isBindMode then
            local snowball = NPC.GetAbility(hero, SNOWBALL_NAME)
            local blink, blinkName = GetBlink(hero)
            local canBlink, blinkReason = CanCastBlink(hero, blink)
            LogDebug(
                string.format(
                    "Bind ready | mode=Bind pressed=true hero=%s kick=ready snowball=%s blink=%s canBlink=%s reason=%s",
                    DescribeUnit(hero),
                    snowball and "found" or "missing",
                    tostring(blinkName or "none"),
                    tostring(canBlink),
                    tostring(blinkReason)
                )
            )
            LogDebug("Bind pressed | checking Blink -> Walrus Kick -> Snowball")
            if TryStartBindBlinkCombo(hero, kick, now, nil) then
                State.lastCastTime = now
                return
            end
            LogDebug("Bind fallback | trying Walrus Kick -> Snowball")
        end

        local plan, planReason = FindBestPlan(hero, kick)
        State.bestPlan = plan

        if not plan then
            if modeState.isBindMode then
                LogDebug("Bind blocked | target/plan not found: " .. tostring(planReason), true)
            end
            return
        end

        if modeState.isBindMode then
            LogDebug(
                string.format(
                    "Bind target selected | target=%s distance=%.0f sequence=Walrus Kick -> Snowball",
                    DescribeUnit(plan.enemy),
                    plan.enemyDistance or -1
                ),
                true
            )
        end

        local issued, issueReason = IssueKickOrder(hero, kick, plan)
        if issued then
            if modeState.isBindMode then
                LogDebug("Bind kick issued | method=" .. tostring(issueReason), true)
            end
            State.lastCastTime = now
            return
        end

        if modeState.isBindMode then
            LogDebug("Bind kick failed | " .. tostring(issueReason), true)
        end
    end

    RunKickLogic()
end

function Script.OnPrepareUnitOrders(data)
    if not UI.Enabled:Get() then
        return true
    end

    if not data or State.pendingOrderUntil <= 0 then
        return true
    end

    if GameRules.GetGameTime() > State.pendingOrderUntil then
        State.pendingOrderUntil = 0
        return true
    end

    local hero = Heroes.GetLocal()
    if not hero or not data.npc then
        return true
    end

    if Entity.GetIndex(data.npc) ~= Entity.GetIndex(hero) then
        return true
    end

    State.pendingOrderUntil = 0
    return true
end

function Script.OnThemeUpdate()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_SAMPLE) or 0
    State.panelHeaderFaFont = nil
    State.panelHeaderFaAvailable = nil
end

function Script.OnGameEnd()
    ClearKickPreview()
    State.lastCastTime = 0
    State.lastAllySyncTime = -100
    State.wasMousePressed = false
    PanelDrag.IsDragging = false
    State.panelHeaderFaFont = nil
    State.panelHeaderFaAvailable = nil
    State.imgCache = nil
    State.spellIcon = nil
    State.matchAllyNames = {}
    State.matchAllySet = {}
    State.cachedAllyEntities = {}
    State.cachedAllyUnitNames = {}
    State.bestPlan = nil
    State.pendingOrderUntil = 0
    State.postOrderLockUntil = 0
    State.pendingVectorStep = nil
    State.pendingSnowballCombo = nil
    State.pendingBlinkKick = nil
    State.lastDebugLogTime = -100
    State.lastDebugMessage = ""
    State.lastKickUnavailableLogTime = -100
    State.lastKickUnavailableReason = ""
    State.lastTargetVisualTime = -100
    end

end)()

--#endregion

return Script
