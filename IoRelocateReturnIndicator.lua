--[[
    Io — Relocate Return HUD
    Fixed screen overlay showing countdown until Relocate teleports back.
    Visible regardless of camera zoom or hero position on the map.
    Script by Euphoria
--]]

local Script = {}

--#region Constants

local LOG_PREFIX = "[IoRelocateHUD] "
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
local PANEL_BAR_H = 6
local PANEL_BAR_PAD_Y = 6
local DEFAULT_RETURN_DURATION = 12.0
local LANG_CACHE_INTERVAL = 1.0

local Icons = {
    enable  = "\u{f00c}",
    gear    = "\u{f013}",
    timer   = "\u{f017}",
    bar     = "\u{f080}",
    scale   = "\u{f065}",
}

--#endregion

--#region State

local UI = {}

local MenuNodes = {
    group = nil,
    gear = nil,
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
}

local fontPanel = 0

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
    TextTimer = Color(120, 200, 255, 255),
    TextWarn = Color(255, 90, 90, 255),
    BarBg = Color(40, 40, 50, 200),
    BarFill = Color(120, 200, 255, 255),
    BarWarn = Color(255, 90, 90, 255),
}

local LoggerInstance = Logger and Logger("IoRelocateHUD") or nil

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

local function LerpColor(a, b, t)
    t = Clamp(t, 0, 1)
    return Color(
        math.floor(a.r + (b.r - a.r) * t),
        math.floor(a.g + (b.g - a.g) * t),
        math.floor(a.b + (b.b - a.b) * t),
        math.floor(a.a + (b.a - a.a) * t))
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
    ui_warn = {
        en = "Warn at (s)",
        ru = "Предупреждение (с)",
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
    tip_warn = {
        en = "Flash red when remaining time drops below this threshold.",
        ru = "Мигать красным, когда осталось меньше указанного времени.",
    },
    label_return = {
        en = "RETURN",
        ru = "ВОЗВРАТ",
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
    MenuLabel(UI.WarnAt, "ui_warn")
    MenuTip(UI.WarnAt, "tip_warn")
    MenuLabel(UI.FontScale, "ui_font_scale")
    MenuLabel(UI.ShowBar, "ui_show_bar")
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

local function GetThemeColor(name, defaultColor)
    if not Menu or not Menu.Style then
        return defaultColor
    end

    local col = SafeCall(Menu.Style, name)
    if col and type(col) == "userdata" then
        return col
    end

    local tbl = SafeCall(Menu.Style)
    if type(tbl) == "table" and tbl[name] then
        local c = tbl[name]
        if c and type(c.r) == "number" then
            local r, g, b = c.r, c.g, c.b
            local a = c.a or 255
            if r <= 1.0 and g <= 1.0 and b <= 1.0 and (a <= 1.0 or not c.a) then
                r = r * 255
                g = g * 255
                b = b * 255
                a = c.a and (a * 255) or 255
            end
            return Color(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
        end
    end

    return defaultColor
end

local function SyncColors()
    if not Menu or not Menu.Style then
        return
    end

    Colors.HeaderBg = GetThemeColor("additional_background", Colors.HeaderBg)
    Colors.TextHeader = GetThemeColor("primary_widgets_text", Colors.TextHeader)

    local primary = GetThemeColor("primary", Colors.TextTimer)
    local warnCol = GetThemeColor("indication_error", Colors.TextWarn)

    Colors.TextTimer = Color(primary.r, primary.g, primary.b, 255)
    Colors.BarFill = Color(primary.r, primary.g, primary.b, 255)
    Colors.TextWarn = Color(warnCol.r, warnCol.g, warnCol.b, 255)
    Colors.BarWarn = Color(warnCol.r, warnCol.g, warnCol.b, 255)
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

local function InitializeUI()
    local group = nil
    local mainSection = Menu.Find("Heroes", "Hero List", "Io", "Main Settings")

    if mainSection and mainSection.Create then
        group = mainSection:Create("Relocate Return HUD")
    end

    if not group then
        group = Menu.Create("Scripts", "Support", "Io Relocate HUD", "Main", "Relocate Return HUD")
    end

    if not group then
        Log("error", "Failed to create menu group")
        return
    end

    MenuNodes.group = group

    UI.Enabled = group:Switch("Enable", true)
    MenuIcon(UI.Enabled, Icons.enable)

    local gear = UI.Enabled:Gear("Settings", Icons.gear, true)
    MenuNodes.gear = gear

    UI.WarnAt = gear:Slider("Warn at (s)", 1, 6, 3, "%d")
    MenuIcon(UI.WarnAt, Icons.timer)

    UI.FontScale = gear:Slider("Font scale", 80, 160, 100, "%d%%")
    MenuIcon(UI.FontScale, Icons.scale)

    UI.ShowBar = gear:Switch("Show progress bar", true)
    MenuIcon(UI.ShowBar, Icons.bar)

    local function UpdateControls()
        local enabled = UI.Enabled:Get()
        UI.WarnAt:Disabled(not enabled)
        UI.FontScale:Disabled(not enabled)
        UI.ShowBar:Disabled(not enabled)
    end

    UI.Enabled:SetCallback(UpdateControls, true)

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

local function ResetRelocateTrack()
    State.relocateTrack = nil
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

    local shadow = Color(0, 0, 0, 140)
    pcall(Render.Text, font, size, text, Vec2(pos.x + 1, pos.y + 1), shadow)
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

local function DrawRelocatePanel(layout, returnState, warnThreshold, scale)
    local isWarn = returnState.remaining <= warnThreshold
    local pulse = 1.0
    if isWarn then
        pulse = 0.65 + 0.35 * (0.5 + 0.5 * math.sin(GetGameTime() * 10))
    end

    local timerColor = isWarn
        and LerpColor(Colors.TextWarn, Colors.TextHeader, 1 - pulse)
        or Colors.TextTimer
    local barColor = isWarn
        and LerpColor(Colors.BarWarn, Colors.BarFill, 1 - pulse)
        or Colors.BarFill

    DrawPanelBlur(layout, scale)

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
        timerColor)

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
                barColor,
                layout.barH * 0.5,
                Enum.DrawFlags.None)
        end
    end
end

--#endregion

--#region Lifecycle

InitializeUI()

function Script.OnScriptsLoaded()
    EnsureSpellIcon()
    LoadPanelPosition()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(GetPanelSampleText()) or 0
end

function Script.OnThemeUpdate()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(GetPanelSampleText()) or 0
end

function Script.OnUpdate()
    if not Engine.IsInGame() or not UI.Enabled or not UI.Enabled:Get() then
        State.returnState = nil
        ResetRelocateTrack()
        return
    end

    local hero = Heroes.GetLocal()
    State.returnState = BuildRelocateReturnState(hero)
end

function Script.OnDraw()
    if not Engine.IsInGame() or not UI.Enabled or not UI.Enabled:Get() then
        return
    end

    SyncColors()

    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local returnState = State.returnState
    if not returnState then
        PanelDrag.IsDragging = false
        return
    end

    EnsureSpellIcon()

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local warnThreshold = UI.WarnAt and UI.WarnAt:Get() or 3
    local layout = GetPanelLayout(scale, screenSize, returnState)

    local mx, my = GetMousePos()
    local isDown = IsLmbDown()
    local isClicked = isDown and not State.wasMousePressed
    local isCursorValid = mx and my

    local isOverPanel = isCursorValid
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.height

    if isClicked and isOverPanel then
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

    DrawRelocatePanel(layout, returnState, warnThreshold, scale)
end

function Script.OnKeyEvent(_data, key, _event)
    if not Engine.IsInGame() or not UI.Enabled or not UI.Enabled:Get() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
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

return Script
