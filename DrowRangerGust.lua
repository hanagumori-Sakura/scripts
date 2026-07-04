--[[
    Drow Ranger Gust
    Auto-interrupt, push-back, and combo Gust with per-enemy HUD panel.
    Script by Euphoria
--]]

local Script = {}

--#region Constants

local CAST_IDENTIFIER = "drow_gust.auto"
local LOG_PREFIX = "[DrowGust] "
local HERO_NAME = "npc_dota_hero_drow_ranger"
local GUST_NAME = "drow_ranger_wave_of_silence"
local GUST_MODIFIER = "modifier_drowranger_wave_of_silence"

local CAST_COOLDOWN = 0.5
local TARGET_SYNC_INTERVAL = 0.5
local DEBUG_LOG_INTERVAL = 2.0
local LANG_CACHE_INTERVAL = 1.0
local DEFAULT_GUST_WIDTH = 250
local CONFIG_SECTION = "drow_ranger_gust"
local DEFAULT_TARGET_MODE = 2

local Icons = {
    tab            = "\u{f140}", -- bullseye / Drow ranger tab
    gear           = "\u{f013}", -- cog / gust settings
    interruptCombo = "\u{f04d}", -- stop / interrupt only in combo
    push           = "\u{f72e}", -- fan / wind push-back
    pushRange      = "\u{f1db}", -- bullseye / push trigger range
    pushCombo      = "\u{f0e7}", -- bolt / push only in combo
    pushDisabled   = "\u{f058}", -- check-circle / push HUD-disabled targets
    panel          = "\u{f108}", -- desktop / control HUD panel
    preview        = "\u{f863}", -- wind / gust cone preview
    drag           = "\u{f047}", -- arrows-alt / move HUD
    debug          = "\u{f188}", -- bug / debug logs
}

--#endregion

--#region State

local myInstanceId = os.clock() .. "_" .. tostring(math.random(100000, 999999))
DrowRangerGust_ActiveInstanceId = myInstanceId

local UI = {}

local State = {
    targetModes = {},
    imgCache = {},
    wasMousePressed = false,
    lastGustCastTime = 0,
    lastDebugLogTime = 0,
    lastTargetSyncTime = 0,
    panelInitialized = false,
    cachedEnemyNames = {},
    cachedEnemyEntities = {},
    castingByName = {},
    previewCastPos = nil,
    previewRange = 0,
    previewWidth = DEFAULT_GUST_WIDTH,
}

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
    HeaderBg = Color(32, 28, 36, 245),
    PanelBg = Color(21, 19, 24, 220),
    GroupBg = Color(13, 9, 19, 160),
    GroupBorder = Color(255, 255, 255, 15),
    CellBgDisabled = Color(42, 38, 45, 150),
    CellBgNeeded = Color(46, 33, 64, 180),
    CellBgAlways = Color(120, 160, 255, 220),
    TextHeader = Color(245, 247, 250, 255),
    BorderDisabled = Color(60, 60, 65, 255),
    BorderAlways = Color(50, 220, 110, 255),
    BorderNeeded = Color(50, 160, 255, 255),
    BorderPanel = Color(255, 255, 255, 25),
    PreviewFill = Color(120, 160, 255, 35),
    PreviewLine = Color(120, 160, 255, 140),
}

local LangState = {
    language = "en",
    nextCheck = 0,
}

local fontNormal = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)

local LoggerInstance = Logger and Logger("DrowGust") or nil

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

local function LogDebug(message)
    Log("debug", message)
end

local function IsActiveInstance()
    return DrowRangerGust_ActiveInstanceId == myInstanceId
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

local function IsLocalDrow(hero)
    return hero and SafeCall(NPC.GetUnitName, hero) == HERO_NAME
end

local function IsValidEnemyHero(myHero, hero)
    return hero
        and hero ~= myHero
        and not SafeCall(Entity.IsSameTeam, myHero, hero)
        and not SafeCall(NPC.IsIllusion, hero)
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

local function GetLuminance(color)
    if not color then
        return 0
    end
    return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
end

local function SyncColors()
    local primary = GetThemeColor("primary", Color(120, 160, 255, 255))
    local background = GetThemeColor("additional_background", Color(32, 28, 36, 245))
    local popupBg = GetThemeColor("popup_background", Color(21, 19, 24, 220))
    local popupBorder = GetThemeColor("popup_border", Color(255, 255, 255, 25))
    local groupBg = GetThemeColor("group_background", Color(13, 9, 19, 115))
    local groupOutline = GetThemeColor("group_outline", Color(0, 0, 0, 0))
    local textHeader = GetThemeColor("primary_widgets_text", Color(245, 247, 250, 255))
    local outline = GetThemeColor("outline", Color(60, 60, 65, 255))
    local activeCol = GetThemeColor("indication_active", Color(50, 220, 110, 255))
    local disabledSwitchBg = GetThemeColor("disabled_switch_background", Color(64, 51, 82, 90))
    local enabledSwitchBg = GetThemeColor("enabled_switch_background", Color(191, 140, 255, 115))
    local comboFrame = GetThemeColor("combo_frame", Color(46, 33, 64, 165))
    local comboItemActive = GetThemeColor("combo_item_active", Color(120, 160, 255, 255))

    local finalTextColor
    local panelBorderColor

    if GetLuminance(background) > 140 then
        finalTextColor = Color(20, 24, 33, 255)
        panelBorderColor = Color(0, 0, 0, 35)
        Colors.CellBgDisabled = Color(220, 220, 225, 150)
        Colors.CellBgNeeded = Color(200, 210, 230, 180)
        Colors.CellBgAlways = Color(primary.r, primary.g, primary.b, 80)
        Colors.BorderDisabled = Color(160, 160, 165, 255)
        Colors.GroupBg = Color(240, 240, 245, 160)
        Colors.GroupBorder = Color(0, 0, 0, 25)
    else
        finalTextColor = textHeader
        panelBorderColor = popupBorder
        Colors.CellBgDisabled = Color(disabledSwitchBg.r, disabledSwitchBg.g, disabledSwitchBg.b, 120)
        Colors.CellBgNeeded = Color(comboFrame.r, comboFrame.g, comboFrame.b, 150)
        Colors.CellBgAlways = Color(enabledSwitchBg.r, enabledSwitchBg.g, enabledSwitchBg.b, 180)
        Colors.BorderDisabled = outline
        Colors.GroupBg = Color(groupBg.r, groupBg.g, groupBg.b, 160)
        if groupOutline.a == 0 then
            Colors.GroupBorder = Color(popupBorder.r, popupBorder.g, popupBorder.b, 15)
        else
            Colors.GroupBorder = groupOutline
        end
    end

    Colors.HeaderBg = Color(background.r, background.g, background.b, 245)
    Colors.PanelBg = Color(popupBg.r, popupBg.g, popupBg.b, 220)
    Colors.TextHeader = finalTextColor
    Colors.BorderPanel = panelBorderColor
    Colors.BorderNeeded = Color(comboItemActive.r, comboItemActive.g, comboItemActive.b, 255)
    Colors.BorderAlways = Color(activeCol.r, activeCol.g, activeCol.b, 255)
end

SyncColors()

--#endregion

--#region Menu

local function InitializeUI()
    local mainSection = Menu.Find("Heroes", "Hero List", "Drow Ranger", "Main Settings")
    local gustGroup

    if mainSection and mainSection.Create then
        gustGroup = mainSection:Create("Gust")
    else
        local fallbackTab = Menu.Create("General", "Drow Ranger Gust", "dr_gust", L("Settings", "Настройки"))
        if fallbackTab and fallbackTab.Icon then
            SafeCall(fallbackTab.Icon, fallbackTab, Icons.tab)
        end
        gustGroup = fallbackTab:Create("Gust")
    end

    local screenSize = SafeCall(Render.ScreenSize) or Vec2(3840, 2160)
    local maxX = math.max(800, math.floor(screenSize.x))
    local maxY = math.max(600, math.floor(screenSize.y))

    UI.Enabled = gustGroup:Switch(L("Enable Gust Control", "Включить контроль Gust"), true,
        "panorama/images/spellicons/drow_ranger_wave_of_silence_png.vtex_c")
    WithTooltip(UI.Enabled, L(
        "Auto-interrupt spells and smart combo cast for Drow Ranger Gust",
        "Авто-прерывание заклинаний и умное комбо для способности Gust"))

    local gear = UI.Enabled:Gear(L("Gust Settings", "Настройки Gust"), Icons.gear)
    UI.Gear = gear

    UI.InterruptOnlyInCombo = gear:Switch(L("Only in Combo", "Только при комбо"), true, Icons.interruptCombo)
    UI.PushCloseEnemies = gear:Switch(L("Push Close Enemies", "Толкать врагов в упоре"), true, Icons.push)
    WithTooltip(UI.PushCloseEnemies, L(
        "Auto-cast Gust on enemy heroes that get too close to push them back",
        "Авто-использовать Gust на вражеских героев, подошедших слишком близко, чтобы оттолкнуть их"))
    UI.PushRange = gear:Slider(L("Push Trigger Range", "Дистанция толчка"), 150, 600, 375)
    SafeCall(UI.PushRange.Icon, UI.PushRange, Icons.pushRange)
    UI.PushOnlyInCombo = gear:Switch(L("Push Only in Combo", "Толкать только при комбо"), false, Icons.pushCombo)
    UI.PushDisabledTargets = gear:Switch(L("Push Disabled Targets", "Толкать отключенных врагов"), true, Icons.pushDisabled)
    WithTooltip(UI.PushDisabledTargets, L(
        "Allow pushing back close enemies even if they are marked as Disabled in the HUD",
        "Разрешить отталкивать подошедших близко врагов, даже если они отключены на панели HUD"))
    UI.DrawPanel = gear:Switch(L("Draw Control Panel", "Показывать панель"), true, Icons.panel)
    UI.DrawPreview = gear:Switch(L("Draw Gust Preview", "Показывать превью Gust"), true, Icons.preview)
    WithTooltip(UI.DrawPreview, L(
        "Draw Gust wave cone when the ability is ready",
        "Показывать конус волны Gust, когда способность готова"))
    UI.DragMode = gear:Switch(L("HUD Drag Mode", "Перемещение HUD"), false, Icons.drag)
    UI.Debug = gear:Switch(L("Enable Debug Logs", "Включить логи отладки"), false, Icons.debug)
    WithTooltip(UI.Debug, L(
        "Write debug details to the Umbrella log",
        "Записывать детали отладки в лог Umbrella"))

    UI.PanelX = gear:Slider("HUD X", 0, maxX, math.min(200, maxX))
    UI.PanelY = gear:Slider("HUD Y", 0, maxY, math.min(200, maxY))
    UI.PanelX:Visible(false)
    UI.PanelY:Visible(false)
end

InitializeUI()

local function LoadPanelPosition()
    if not UI.PanelX or not UI.PanelY then
        return
    end
    local x = UI.PanelX:Get()
    local y = UI.PanelY:Get()
    if x > 0 or y > 0 then
        PanelConfig.X = x
        PanelConfig.Y = y
    end
end

local function SavePanelPosition()
    if not UI.PanelX or not UI.PanelY then
        return
    end
    SafeCall(UI.PanelX.Set, UI.PanelX, math.floor(PanelConfig.X + 0.5))
    SafeCall(UI.PanelY.Set, UI.PanelY, math.floor(PanelConfig.Y + 0.5))
end

local function TargetConfigKey(cleanName)
    return "target_" .. cleanName:lower()
end

local function HideLegacyGearWidget(name)
    local gear = UI.Gear
    if not gear or not name or name == "" then
        return
    end

    local widget = SafeCall(gear.Find, gear, name)
    if widget and widget.Visible then
        SafeCall(widget.Visible, widget, false)
    end
end

local function HideLegacyGearWidgets()
    HideLegacyGearWidget("Combo Targets (Always)")
    HideLegacyGearWidget("Interrupt Targets (When casting)")
    HideLegacyGearWidget("Combo Key Fallback")
    HideLegacyGearWidget("Цели комбо (Всегда)")
    HideLegacyGearWidget("Цели прерывания (При касте)")
    HideLegacyGearWidget("Запасной бинд комбо")

    for _, cleanName in ipairs(State.cachedEnemyNames) do
        HideLegacyGearWidget(cleanName)
    end
end

local function TryMigrateLegacyMenuTarget(cleanName)
    local gear = UI.Gear
    if not gear then
        return nil
    end

    local existing = SafeCall(gear.Find, gear, cleanName)
    if existing and existing.Get then
        HideLegacyGearWidget(cleanName)
        local val = SafeCall(existing.Get, existing)
        if type(val) == "number" and val >= 0 and val <= 2 then
            return val
        end
    end

    return nil
end

local function GetTargetMode(cleanName)
    local cached = State.targetModes[cleanName]
    if cached ~= nil then
        return cached
    end

    local migrated = TryMigrateLegacyMenuTarget(cleanName)
    if migrated ~= nil then
        State.targetModes[cleanName] = migrated
        SafeCall(Config.WriteInt, CONFIG_SECTION, TargetConfigKey(cleanName), migrated)
        return migrated
    end

    local val = SafeCall(Config.ReadInt, CONFIG_SECTION, TargetConfigKey(cleanName), DEFAULT_TARGET_MODE)
    if type(val) ~= "number" or val < 0 or val > 2 then
        val = DEFAULT_TARGET_MODE
    end

    State.targetModes[cleanName] = val
    return val
end

local function SetTargetMode(cleanName, val)
    State.targetModes[cleanName] = val
    SafeCall(Config.WriteInt, CONFIG_SECTION, TargetConfigKey(cleanName), val)
end

--#endregion

--#region Input & Draw helpers

local function GetMousePos()
    local x, y = SafeCall(Input.GetCursorPos)
    if type(x) == "number" then
        return x, y
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
    if State.imgCache[heroName] then
        return State.imgCache[heroName]
    end
    local handle = SafeCall(Render.LoadImage, HeroIconPath(heroName))
    if handle then
        State.imgCache[heroName] = handle
    end
    return handle
end

local function DrawShadowText(fontObj, size, text, pos, color, shadowAlpha)
    shadowAlpha = shadowAlpha or 160
    Render.Text(fontObj, size, text, Vec2(pos.x + 1, pos.y + 1), Color(0, 0, 0, shadowAlpha))
    Render.Text(fontObj, size, text, pos, color)
end

local function GetPanelLayout(scale, numEnemies, screenSize)
    local cellW = 44 * scale
    local cellH = 30 * scale
    local cellSpacing = 8 * scale
    local titleH = 30 * scale
    local secW = numEnemies * cellW + (numEnemies - 1) * cellSpacing + 20 * scale
    local secH = cellH + 26 * scale
    local width = secW + 20 * scale
    local height = titleH + secH + 12 * scale

    local x = math.max(0, math.min(screenSize.x - width, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - height, PanelConfig.Y))

    return {
        scale = scale,
        cellW = cellW,
        cellH = cellH,
        cellSpacing = cellSpacing,
        titleH = titleH,
        secW = secW,
        secH = secH,
        width = width,
        height = height,
        x = x,
        y = y,
        secBgX = x + 10 * scale,
        secBgY = y + titleH,
        secBgW = width - 20 * scale,
        cellStartY = y + titleH + 20 * scale,
        cellsTotalW = numEnemies * cellW + (numEnemies - 1) * cellSpacing,
        cellsStartX = x + 10 * scale + ((width - 20 * scale) - (numEnemies * cellW + (numEnemies - 1) * cellSpacing)) / 2,
        closeX = x + width - 24 * scale,
        closeY = y + 8 * scale,
        closeW = 12 * scale,
    }
end

local function DrawWorldLine(a, b, color, thickness)
    local screenA, visibleA = Render.WorldToScreen(a)
    local screenB, visibleB = Render.WorldToScreen(b)
    if visibleA and visibleB then
        Render.Line(screenA, screenB, color, thickness)
    end
end

local function DrawGustPreview(origin, castPos, range, width)
    if not origin or not castPos then
        return
    end

    local dir = (castPos - origin)
    if dir:Length2D() < 1 then
        return
    end
    dir = dir:Normalized()

    local endCenter = origin + dir * range
    local perp = Vector(-dir.y, dir.x, 0)
    local half = width * 0.5
    local leftEnd = endCenter + perp * half
    local rightEnd = endCenter - perp * half
    local leftStart = origin + perp * (half * 0.15)
    local rightStart = origin - perp * (half * 0.15)

    DrawWorldLine(origin, leftEnd, Colors.PreviewLine, 1.5)
    DrawWorldLine(origin, rightEnd, Colors.PreviewLine, 1.5)
    DrawWorldLine(leftEnd, rightEnd, Colors.PreviewLine, 1.5)
    DrawWorldLine(leftStart, leftEnd, Colors.PreviewLine, 1.0)
    DrawWorldLine(rightStart, rightEnd, Colors.PreviewLine, 1.0)
end

--#endregion

--#region Targeting

local function GetGustWidth(gust)
    if not gust then
        return DEFAULT_GUST_WIDTH
    end
    local width = SafeCall(Ability.GetLevelSpecialValueFor, gust, "wave_width")
    if type(width) == "number" and width > 0 then
        return width
    end
    return DEFAULT_GUST_WIDTH
end

local function IsNPCDecapacitated(npc)
    if not npc then
        return false
    end
    return SafeCall(NPC.HasState, npc, Enum.ModifierState.MODIFIER_STATE_SILENCED)
        or SafeCall(NPC.HasState, npc, Enum.ModifierState.MODIFIER_STATE_STUNNED)
        or SafeCall(NPC.HasState, npc, Enum.ModifierState.MODIFIER_STATE_HEXED)
        or SafeCall(NPC.HasState, npc, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
        or SafeCall(NPC.HasState, npc, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
end

local function IsGustBlocked(npc)
    if not npc then
        return true
    end
    if SafeCall(NPC.HasState, npc, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
        return true
    end
    if SafeCall(NPC.HasState, npc, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
        return true
    end
    if SafeCall(NPC.IsLinkensProtected, npc) then
        return true
    end
    if SafeCall(NPC.HasModifier, npc, GUST_MODIFIER) then
        return true
    end
    return false
end

local function IsNPCUsingAbility(npc)
    if not npc or not SafeCall(Entity.IsAlive, npc) then
        return nil
    end

    local channelling = SafeCall(NPC.GetChannellingAbility, npc)
    if channelling then
        return channelling
    end

    for i = 0, 23 do
        local ability = SafeCall(NPC.GetAbilityByIndex, npc, i)
        if ability and SafeCall(Ability.IsInAbilityPhase, ability) then
            return ability
        end
    end

    for i = 0, 8 do
        local item = SafeCall(NPC.GetItemByIndex, npc, i)
        if item and SafeCall(Ability.IsInAbilityPhase, item) then
            return item
        end
    end

    return nil
end

local function WillHit(origin, castPos, enemyPos, range, width)
    local dir = (castPos - origin):Normalized()
    local toEnemy = enemyPos - origin
    local proj = toEnemy:Dot2D(dir)
    if proj < 0 or proj > range then
        return false
    end
    local distSq = toEnemy:Length2DSqr() - proj * proj
    return distSq <= (width * 0.5) ^ 2
end

local function GetEnemyScore(enemy, origin, pushRange)
    local cleanName = CleanHeroName(SafeCall(NPC.GetUnitName, enemy))
    local val = GetTargetMode(cleanName)

    local isTooClose = false
    if UI.PushCloseEnemies:Get() and origin then
        local dist = (SafeCall(Entity.GetAbsOrigin, enemy) - origin):Length2D()
        if dist <= pushRange then
            if not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_STUNNED)
                and not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_HEXED)
                and not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
                and not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
                if val > 0 or UI.PushDisabledTargets:Get() then
                    isTooClose = true
                end
            end
        end
    end

    if val == 0 and not isTooClose then
        return 0
    end

    local baseScore = 1
    if val == 1 then
        baseScore = 2
    elseif val == 2 then
        baseScore = 1.5
    elseif val == 0 and isTooClose then
        baseScore = 1.2
    end

    if IsNPCUsingAbility(enemy) then
        baseScore = baseScore + 10
    end

    return baseScore
end

local function OptimizeGust(origin, primaryTarget, enemiesInRange, range, width)
    local targetPos = SafeCall(Entity.GetAbsOrigin, primaryTarget)
    local dirTarget = (targetPos - origin):Normalized()
    local angleTarget = math.atan(dirTarget.y, dirTarget.x)
    local distTarget = (targetPos - origin):Length2D()
    local halfW = width * 0.5
    local alpha = distTarget > 0 and math.asin(math.min(1.0, halfW / distTarget)) or (math.pi * 0.5)

    local bestScore = -1
    local bestPos = nil
    local steps = 10

    for i = 0, steps do
        local angle = (angleTarget - alpha) + (i / steps) * (2 * alpha)
        local candidateDir = Vector(math.cos(angle), math.sin(angle), 0)
        local candidatePos = origin + candidateDir * range
        local score = 0

        for _, enemy in ipairs(enemiesInRange) do
            local enemyPos = SafeCall(Entity.GetAbsOrigin, enemy)
            if WillHit(origin, candidatePos, enemyPos, range, width) then
                score = score + GetEnemyScore(enemy, origin, UI.PushRange:Get())
            end
        end

        if score > bestScore then
            bestScore = score
            bestPos = candidatePos
        end
    end

    return bestScore, bestPos
end

local function IsInCombo()
    local nativeCombo = Menu.Find("Heroes", "Hero List", "Drow Ranger", "Main Settings", "Hero Settings", "Combo Key")
    return nativeCombo and nativeCombo.IsDown and nativeCombo:IsDown() or false
end

local function SyncEnemyTargets(myHero, now)
    if now - State.lastTargetSyncTime < TARGET_SYNC_INTERVAL then
        return
    end
    State.lastTargetSyncTime = now

    local names = {}
    local entities = {}

    for _, hero in ipairs(SafeCall(Heroes.GetAll) or {}) do
        if IsValidEnemyHero(myHero, hero) then
            local cleanName = CleanHeroName(SafeCall(NPC.GetUnitName, hero))
            if cleanName ~= "" then
                names[#names + 1] = cleanName
                entities[cleanName] = hero
            end
        end
    end

    table.sort(names)
    State.cachedEnemyNames = names
    State.cachedEnemyEntities = entities
    HideLegacyGearWidgets()
end

local function CastGust(gust, castPos, reason, dbg)
    if dbg then
        LogDebug(reason)
    end
    SafeCall(Ability.CastPosition, gust, castPos, false, false, true, CAST_IDENTIFIER)
    State.lastGustCastTime = os.clock()
end

local function TryCastGust(gust, origin, targetList, enemiesInRange, castRange, width, reason, dbg)
    local bestScore = -1
    local bestCastPos = nil

    for _, target in ipairs(targetList) do
        local score, castPos = OptimizeGust(origin, target, enemiesInRange, castRange, width)
        if score > bestScore then
            bestScore = score
            bestCastPos = castPos
        end
    end

    if bestCastPos then
        CastGust(gust, bestCastPos, reason, dbg)
        return true
    end

    return false
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    LoadPanelPosition()
    State.panelInitialized = true
    HideLegacyGearWidgets()
end

function Script.OnThemeUpdate()
    SyncColors()
end

function Script.OnUpdate()
    if not IsActiveInstance() or not UI.Enabled:Get() then
        return
    end

    if SafeCall(Engine.IsInGame) ~= true then
        return
    end

    local now = os.clock()
    local dbg = UI.Debug:Get()
    local shouldLog = dbg and (now - State.lastDebugLogTime >= DEBUG_LOG_INTERVAL)
    if shouldLog then
        State.lastDebugLogTime = now
    end

    local myHero = Heroes.GetLocal()
    if not IsLocalDrow(myHero) then
        if shouldLog then
            LogDebug("Exit: local hero is not Drow Ranger")
        end
        State.previewCastPos = nil
        return
    end

    if not SafeCall(Entity.IsAlive, myHero) then
        if shouldLog then
            LogDebug("Exit: Drow Ranger is dead")
        end
        State.previewCastPos = nil
        return
    end

    SyncEnemyTargets(myHero, now)

    local gust = SafeCall(NPC.GetAbility, myHero, GUST_NAME)
    if not gust or (SafeCall(Ability.GetLevel, gust) or 0) == 0 then
        State.previewCastPos = nil
        return
    end

    local mana = SafeCall(NPC.GetMana, myHero) or 0
    local isReady = SafeCall(Ability.IsReady, gust) == true
    local isCastable = SafeCall(Ability.IsCastable, gust, mana) == true

    if not isReady or not isCastable then
        State.previewCastPos = nil
        if shouldLog then
            LogDebug(string.format("Exit: Gust ready=%s castable=%s mana=%.0f", tostring(isReady), tostring(isCastable), mana))
        end
        return
    end

    if now - State.lastGustCastTime < CAST_COOLDOWN then
        return
    end

    if SafeCall(Input.IsInputCaptured) then
        return
    end

    local origin = SafeCall(Entity.GetAbsOrigin, myHero)
    local castRange = (SafeCall(Ability.GetCastRange, gust) or 0) + (SafeCall(NPC.GetCastRangeBonus, myHero) or 0)
    local width = GetGustWidth(gust)
    local inCombo = IsInCombo()
    local pushRange = UI.PushRange:Get()

    State.previewRange = castRange
    State.previewWidth = width
    State.previewCastPos = nil
    State.castingByName = {}

    local enemiesInRange = {}
    local castingEnemies = {}
    local pushEnemies = {}
    local alwaysEnemies = {}

    local nearbyEnemies = SafeCall(
        Heroes.InRadius,
        origin,
        castRange,
        SafeCall(Entity.GetTeamNum, myHero),
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}

    for _, enemy in ipairs(nearbyEnemies) do
        if IsValidEnemyHero(myHero, enemy)
            and SafeCall(Entity.IsAlive, enemy)
            and not SafeCall(Entity.IsDormant, enemy) then
            local cleanName = CleanHeroName(SafeCall(NPC.GetUnitName, enemy))
            local val = GetTargetMode(cleanName)
            local enemyPos = SafeCall(Entity.GetAbsOrigin, enemy)
            local dist = (enemyPos - origin):Length2D()
            local isDecap = IsNPCDecapacitated(enemy)
            local currentCasting = IsNPCUsingAbility(enemy)

            if currentCasting then
                State.castingByName[cleanName] = SafeCall(Ability.GetName, currentCasting) or "?"
            end

            local isTooClose = false
            if UI.PushCloseEnemies:Get() and dist <= pushRange then
                if not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_STUNNED)
                    and not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_HEXED)
                    and not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
                    and not SafeCall(NPC.HasState, enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
                    if val > 0 or UI.PushDisabledTargets:Get() then
                        isTooClose = true
                    end
                end
            end

            if shouldLog and (val > 0 or isTooClose) then
                LogDebug(string.format(
                    "Target %s: val=%d dist=%.0f/%.0f blocked=%s decap=%s casting=%s tooClose=%s",
                    cleanName, val, dist, castRange, tostring(IsGustBlocked(enemy)), tostring(isDecap),
                    tostring(currentCasting ~= nil), tostring(isTooClose)))
            end

            if dist <= castRange and not IsGustBlocked(enemy) and (val > 0 or isTooClose) then
                enemiesInRange[#enemiesInRange + 1] = enemy

                if val > 0 and currentCasting and not isDecap then
                    castingEnemies[#castingEnemies + 1] = enemy
                end
                if isTooClose then
                    pushEnemies[#pushEnemies + 1] = enemy
                end
                if val == 1 and not isDecap then
                    alwaysEnemies[#alwaysEnemies + 1] = enemy
                end
            end
        end
    end

    if UI.DrawPreview:Get() and #enemiesInRange > 0 then
        local previewTarget = castingEnemies[1] or pushEnemies[1] or alwaysEnemies[1] or enemiesInRange[1]
        if previewTarget then
            local _, previewPos = OptimizeGust(origin, previewTarget, enemiesInRange, castRange, width)
            State.previewCastPos = previewPos
        end
    end

    if shouldLog then
        LogDebug(string.format("Tick: range=%.0f mana=%.0f inCombo=%s targets=%d", castRange, mana, tostring(inCombo), #enemiesInRange))
    end

    if #castingEnemies > 0 and (not UI.InterruptOnlyInCombo:Get() or inCombo) then
        if dbg then
            LogDebug(string.format("Auto-interrupt targets: %d", #castingEnemies))
        end
        if TryCastGust(
            gust, origin, castingEnemies, enemiesInRange, castRange, width,
            string.format("CAST interrupt (targets=%d)", #castingEnemies), dbg
        ) then
            return
        end
    end

    if #pushEnemies > 0 and (not UI.PushOnlyInCombo:Get() or inCombo) then
        if dbg then
            LogDebug(string.format("Push targets: %d", #pushEnemies))
        end
        if TryCastGust(
            gust, origin, pushEnemies, enemiesInRange, castRange, width,
            string.format("CAST push (targets=%d)", #pushEnemies), dbg
        ) then
            return
        end
    end

    if inCombo and #alwaysEnemies > 0 then
        if dbg then
            LogDebug(string.format("Combo always targets: %d", #alwaysEnemies))
        end
        TryCastGust(
            gust, origin, alwaysEnemies, enemiesInRange, castRange, width,
            string.format("CAST combo (targets=%d)", #alwaysEnemies), dbg
        )
    end
end

function Script.OnDraw()
    if not IsActiveInstance() or not UI.Enabled:Get() then
        return
    end

    local myHero = Heroes.GetLocal()
    if not IsLocalDrow(myHero) then
        return
    end

    if not State.panelInitialized then
        LoadPanelPosition()
        State.panelInitialized = true
    end

    if UI.DrawPreview:Get() and State.previewCastPos then
        local origin = SafeCall(Entity.GetAbsOrigin, myHero)
        DrawGustPreview(origin, State.previewCastPos, State.previewRange, State.previewWidth)
    end

    if not UI.DrawPanel:Get() then
        return
    end

    local enemies = State.cachedEnemyNames
    local numEnemies = #enemies
    if numEnemies == 0 then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, numEnemies, screenSize)
    local mx, my = GetMousePos()
    local isDown = IsLmbDown()
    local isClicked = isDown and not State.wasMousePressed
    local isCursorValid = mx and my

    if UI.DragMode:Get() then
        local isOverHeader = isCursorValid
            and mx >= layout.x and mx <= layout.x + layout.width
            and my >= layout.y and my <= layout.y + layout.titleH

        if isClicked and isOverHeader then
            PanelDrag.IsDragging = true
            PanelDrag.OffsetX = mx - layout.x
            PanelDrag.OffsetY = my - layout.y
        elseif not isDown then
            PanelDrag.IsDragging = false
        end

        if PanelDrag.IsDragging and mx and my then
            PanelConfig.X = math.max(0, math.min(screenSize.x - layout.width, mx - PanelDrag.OffsetX))
            PanelConfig.Y = math.max(0, math.min(screenSize.y - layout.height, my - PanelDrag.OffsetY))
            SavePanelPosition()
            layout = GetPanelLayout(scale, numEnemies, screenSize)
        end
    else
        PanelDrag.IsDragging = false
    end

    local statusText = L("RDY", "ГОТ")
    local statusColor = Color(50, 220, 110, 255)
    local cdValue = 0
    local gust = SafeCall(NPC.GetAbility, myHero, GUST_NAME)

    if gust and (SafeCall(Ability.GetLevel, gust) or 0) > 0 then
        if not SafeCall(Ability.IsReady, gust) then
            local cd = SafeCall(Ability.GetCooldown, gust) or 0
            if cd > 0 then
                cdValue = cd
                statusText = string.format("%.0f", cd)
                statusColor = Color(255, 100, 110, 255)
            end
        end
    else
        statusText = L("N/A", "Н/Д")
        statusColor = Color(150, 150, 150, 255)
    end

    local titleIcon = UI.DragMode:Get() and "🤚" or "💨"
    local titleText = UI.DragMode:Get() and L("DRAGGING", "ДВИЖЕНИЕ") or L("Gust Control", "Контроль Gust")
    local titleFull = titleIcon .. "  " .. titleText

    local clickTriggered = isClicked
    State.wasMousePressed = isDown

    local isOverClose = isCursorValid
        and mx >= layout.closeX - 4 * scale and mx <= layout.closeX + layout.closeW + 4 * scale
        and my >= layout.y and my <= layout.y + layout.titleH

    if isOverClose and clickTriggered then
        UI.DrawPanel:Set(false)
        clickTriggered = false
    end

    Render.Blur(Vec2(layout.x, layout.y), Vec2(layout.x + layout.width, layout.y + layout.height), 2.5, 1.0, 8 * scale, Enum.DrawFlags.None)
    Render.Shadow(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.height),
        Color(0, 0, 0, 110),
        22,
        8 * scale,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 2)
    )
    Render.FilledRect(Vec2(layout.x, layout.y), Vec2(layout.x + layout.width, layout.y + layout.height), Colors.PanelBg, 8 * scale)
    Render.Rect(Vec2(layout.x, layout.y), Vec2(layout.x + layout.width, layout.y + layout.height), Colors.BorderPanel, 8 * scale, Enum.DrawFlags.None, 1)

    DrawShadowText(fontNormal, 11 * scale, titleFull, Vec2(layout.x + 12 * scale, layout.y + 8 * scale), Colors.TextHeader)

    if cdValue > 0 or statusText == L("N/A", "Н/Д") then
        local statusSz = Render.TextSize(fontNormal, 10 * scale, statusText)
        DrawShadowText(
            fontNormal,
            10 * scale,
            statusText,
            Vec2(layout.closeX - statusSz.x - 12 * scale, layout.y + 9 * scale),
            statusColor
        )
    end

    local closeCol = isOverClose and Color(255, 100, 110, 255)
        or Color(Colors.TextHeader.r, Colors.TextHeader.g, Colors.TextHeader.b, 140)
    DrawShadowText(fontNormal, 11 * scale, "✕", Vec2(layout.closeX, layout.closeY), closeCol)

    Render.FilledRect(
        Vec2(layout.secBgX, layout.secBgY),
        Vec2(layout.secBgX + layout.secBgW, layout.secBgY + layout.secH),
        Colors.GroupBg,
        6 * scale
    )
    Render.Rect(
        Vec2(layout.secBgX, layout.secBgY),
        Vec2(layout.secBgX + layout.secBgW, layout.secBgY + layout.secH),
        Colors.GroupBorder,
        6 * scale,
        Enum.DrawFlags.None,
        1
    )

    local secTitle = L("Targets", "Цели")
    local titleSz = Render.TextSize(fontNormal, 10 * scale, secTitle)
    DrawShadowText(
        fontNormal,
        10 * scale,
        secTitle,
        Vec2(layout.secBgX + (layout.secBgW - titleSz.x) / 2, layout.secBgY + 5 * scale),
        Colors.TextHeader
    )

    for i, cleanName in ipairs(enemies) do
        local cellX = layout.cellsStartX + (i - 1) * (layout.cellW + layout.cellSpacing)
        local enemyHero = State.cachedEnemyEntities[cleanName]
        local currentVal = GetTargetMode(cleanName)

        local cellBg = Colors.CellBgDisabled
        local imgAlpha = 110
        local grayscale = 1.0

        if currentVal == 1 then
            cellBg = Colors.CellBgAlways
            imgAlpha = 220
            grayscale = 0.0
        elseif currentVal == 2 then
            cellBg = Colors.CellBgNeeded
            imgAlpha = 180
            grayscale = 0.0
        end

        Render.FilledRect(
            Vec2(cellX, layout.cellStartY),
            Vec2(cellX + layout.cellW, layout.cellStartY + layout.cellH),
            cellBg,
            5 * scale
        )

        local heroNameRaw = enemyHero and SafeCall(NPC.GetUnitName, enemyHero) or ""
        local imgHandle = GetHeroIcon(heroNameRaw)
        if imgHandle then
            Render.Image(
                imgHandle,
                Vec2(cellX, layout.cellStartY),
                Vec2(layout.cellW, layout.cellH),
                Color(255, 255, 255, imgAlpha),
                5 * scale,
                Enum.DrawFlags.None,
                Vec2(0, 0),
                Vec2(1, 1),
                grayscale
            )
        end

        local castingAbilityName = State.castingByName[cleanName]
        local isCasting = castingAbilityName ~= nil
        local borderCol = Colors.BorderDisabled

        if isCasting then
            local pulse = math.floor(120 + 135 * math.sin((SafeCall(GlobalVars.GetCurTime) or 0) * 10.0))
            borderCol = Color(255, 75, 75, pulse)
        elseif currentVal == 1 then
            borderCol = Colors.BorderAlways
        elseif currentVal == 2 then
            borderCol = Colors.BorderNeeded
        end

        if currentVal > 0 or isCasting then
            local glowAlpha = isCasting and 85 or 55
            Render.Shadow(
                Vec2(cellX, layout.cellStartY),
                Vec2(cellX + layout.cellW, layout.cellStartY + layout.cellH),
                Color(borderCol.r, borderCol.g, borderCol.b, glowAlpha),
                6 * scale,
                5 * scale,
                Enum.DrawFlags.ShadowCutOutShapeBackground
            )
        end

        Render.Rect(
            Vec2(cellX, layout.cellStartY),
            Vec2(cellX + layout.cellW, layout.cellStartY + layout.cellH),
            borderCol,
            5 * scale,
            Enum.DrawFlags.None,
            1.5
        )

        if currentVal > 0 then
            local dotX = cellX + layout.cellW - 5 * scale
            local dotY = layout.cellStartY + 5 * scale
            local dotR = 2.5 * scale
            local dotColor = currentVal == 1 and Colors.BorderAlways or Colors.BorderNeeded
            Render.FilledCircle(Vec2(dotX, dotY), dotR, dotColor)
            Render.Circle(Vec2(dotX, dotY), dotR, Color(255, 255, 255, 200), 0.5)
        end

        local isCellHovered = isCursorValid
            and mx >= cellX and mx <= cellX + layout.cellW
            and my >= layout.cellStartY and my <= layout.cellStartY + layout.cellH

        if isCellHovered and isCasting and castingAbilityName then
            local tipSz = Render.TextSize(fontNormal, 8 * scale, castingAbilityName)
            local tipX = cellX + (layout.cellW - tipSz.x) * 0.5
            local tipY = layout.cellStartY + layout.cellH + 2 * scale
            DrawShadowText(fontNormal, 8 * scale, castingAbilityName, Vec2(tipX, tipY), Color(255, 120, 120, 255))
        end

        if isCellHovered and clickTriggered then
            local nextVal = 0
            if currentVal == 0 then
                nextVal = 2
            elseif currentVal == 2 then
                nextVal = 1
            end
            SetTargetMode(cleanName, nextVal)
        end
    end
end

function Script.OnKeyEvent(data, key, event)
    if not IsActiveInstance() then
        return
    end
    if not Menu or not Menu.VisualsIsEnabled or not Menu.VisualsIsEnabled() then
        return
    end
    if not UI.Enabled:Get() or not UI.DrawPanel:Get() then
        return
    end

    local myHero = Heroes.GetLocal()
    if not IsLocalDrow(myHero) then
        return
    end

    local numEnemies = #State.cachedEnemyNames
    if numEnemies == 0 then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, numEnemies, screenSize)
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
