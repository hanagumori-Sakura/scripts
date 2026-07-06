--[[
    Anti AFK
    Prevents in-match AFK warnings with realistic idle movement: wander, jungle, tree hide, fountain dance.
    Smart mode picks the safest option; micro-actions and enemy-sight avoidance add depth.
    Script by Euphoria
--]]

local Script = {}

--#region Constants

local ORDER_PREFIX = "anti_afk."
local LOG_PREFIX = "[AntiAFK] "
local CURSOR_MOVE_THRESHOLD = 3
local HUD_ICON = "panorama/images/items/ward_observer_png.vtex_c"
local PANEL_HEADER_HEIGHT = 36
local PANEL_HEADER_PAD_X = 12
local PANEL_HEADER_TEXT_SIZE = 14
local PANEL_TITLE_TEXT_SIZE = 13
local PANEL_HEADER_ICON_SIZE = 16
local PANEL_HEADER_ICON_GAP = 8
local PANEL_HEADER_RADIUS = 6
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_BAR_H = 6
local PANEL_BAR_PAD_Y = 6
local PANEL_MODE_TEXT_SIZE = 10
local PANEL_MODE_PAD_Y = 4
local PANEL_ABOVE_PORTRAIT = 6
local PANEL_MIN_WIDTH = 110
local INDICATOR_LABEL = "AntiAFK"
local PORTRAIT_CACHE_TTL = 0.25
local CAMP_NEUTRAL_RADIUS = 650
local TREE_CLUSTER_RADIUS = 260
local EARLY_GAME_WANDER_CAP = 350
local EARLY_GAME_SECONDS = 300
local JUNGLE_UNLOCK_SECONDS = 240
local MIN_MOVE_DIST = 80
local TARGET_REPEAT_MIN_DIST = 120
local FOUNTAIN_DANCE_RADIUS_PRE = 220
local FOUNTAIN_DANCE_RADIUS_GAME = 380
local FOUNTAIN_DANCE_STEP = 0.55
local ENEMY_SIGHT_AVOID_SECONDS = 18
local ENEMY_SIGHT_RECORD_RADIUS = 1600

local ORDER_ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local ORDER_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
local ORDER_ATTACK_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE

local METHOD_WANDER = 0
local METHOD_JUNGLE = 1
local METHOD_TREE_HIDE = 2
local METHOD_SMART = 3
local METHOD_FOUNTAIN = 4

local METHOD_ITEMS = {
    "Wander",
    "Jungle Farm",
    "Tree Hide",
    "Smart",
    "Fountain Dance",
}

local MODE_LABELS = {
    "Wander",
    "Jungle",
    "Hide",
    "Smart",
    "Fountain",
}

local FOUNTAIN_POS = {
    [Enum.TeamNum.TEAM_RADIANT] = Vector(-6960, -6530, 384),
    [Enum.TeamNum.TEAM_DIRE] = Vector(6912, 6368, 384),
}

local PRE_GAME_STATES = {
    [Enum.GameState.DOTA_GAMERULES_STATE_HERO_SELECTION] = true,
    [Enum.GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME] = true,
    [Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME] = true,
}

local INDICATOR_FONT_CANDIDATES = {
    "Segoe UI",
    "Tahoma",
    "Arial",
    "Verdana",
}

local PORTRAIT_PANEL_PATHS = {
    { "HUDElements", "lower_hud", "center_with_stats", "center_block", "PortraitContainer" },
    { "HUDElements", "lower_hud", "center_with_stats", "PortraitContainer" },
    { "HUDElements", "lower_hud", "center_with_stats", "center_block", "PortraitGroup" },
    { "HUDElements", "lower_hud", "PortraitGroup" },
    { "HUDElements", "lower_hud", "center_with_stats", "center_block", "HeroPortrait" },
}

local PORTRAIT_TRAVERSE_IDS = {
    "PortraitContainer",
    "HeroPortrait",
    "CenterHeroPortrait",
    "portrait",
}

local ALLOWED_GAME_STATES = {
    [Enum.GameState.DOTA_GAMERULES_STATE_HERO_SELECTION] = true,
    [Enum.GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME] = true,
    [Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME] = true,
    [Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS] = true,
    [Enum.GameState.DOTA_GAMERULES_STATE_TEAM_SHOWCASE] = true,
}

local ACTIVITY_KEYS = {
    Enum.ButtonCode.KEY_W,
    Enum.ButtonCode.KEY_A,
    Enum.ButtonCode.KEY_S,
    Enum.ButtonCode.KEY_D,
    Enum.ButtonCode.KEY_SPACE,
    Enum.ButtonCode.KEY_MOUSE1,
    Enum.ButtonCode.KEY_MOUSE2,
}

local Icons = {
    tab           = "\u{f1ce}", -- circle-notch (keep-alive)
    enable        = "\u{f011}", -- power-off
    interval      = "\u{f017}", -- clock
    method        = "\u{f0ae}", -- tasks
    idle          = "\u{f252}", -- hourglass-half
    idleThreshold = "\u{f254}", -- hourglass-end
    hud           = "\u{f625}", -- display
    gear          = "\u{f013}", -- cog
    search        = "\u{f002}", -- magnifying-glass
    enemy         = "\u{f071}", -- triangle-exclamation
    wander        = "\u{f554}", -- person-walking
    micro         = "\u{f110}", -- spinner
    sight         = "\u{f06e}", -- eye
    jungle        = "\u{f186}", -- moon
}

--#endregion

--#region State

local State = {
    lastPulseAt = 0,
    lastUserActivityAt = 0,
    lastCursorX = nil,
    lastCursorY = nil,
    menuReady = false,
    fontIndicator = nil,
    hudIcon = nil,
    portraitBounds = nil,
    portraitBoundsAt = 0,
    activeModeLabel = nil,
    actionLogLabel = nil,
    pendingTarget = nil,
    pulseCount = 0,
    lastTargetPos = nil,
    lastTargetCamp = nil,
    lastTreeCluster = nil,
    fountainDanceAngle = 0,
    enemySightings = {},
}

local UI = {}

--#endregion

--#region Utils

local LoggerInstance = Logger and Logger("AntiAFK") or nil

local function SafeCall(fn, ...)
    if not fn then
        return false, nil
    end
    return pcall(fn, ...)
end

local function Log(level, message)
    message = tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if SafeCall(LoggerInstance[level], LoggerInstance, message) then
            return
        end
    end
    print(LOG_PREFIX .. message)
end

local function ReadMember(value, key)
    local ok, result = SafeCall(function() return value[key] end)
    if ok then
        return result
    end
    return nil
end

local function MenuIcon(widget, icon)
    if not widget or not icon then
        return
    end
    if widget.Icon then
        SafeCall(widget.Icon, widget, icon)
    elseif widget.Image then
        SafeCall(widget.Image, widget, icon)
    end
end

local function EnsureSecondTabIcon()
    local secondTab = Menu.Find("Miscellaneous", "Other", "Anti AFK")
    MenuIcon(secondTab, Icons.tab)
end

local function WithTooltip(widget, text)
    if widget and widget.ToolTip and text then
        SafeCall(widget.ToolTip, widget, text)
    end
end

local function GetNow()
    if GlobalVars and GlobalVars.GetCurTime then
        local ok, value = SafeCall(GlobalVars.GetCurTime)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function TouchUserActivity(now)
    State.lastUserActivityAt = now or GetNow()
end

local function IsOurOrder(data)
    if type(data) ~= "table" then
        return false
    end

    local identifier = data.identifier
    return type(identifier) == "string"
        and identifier:find(ORDER_PREFIX, 1, true) == 1
end

local function IsLocalPlayerOrder(player, data)
    local localPlayer = Players and Players.GetLocal and Players.GetLocal() or nil
    if not localPlayer then
        return false
    end

    if player == localPlayer then
        return true
    end

    if type(data) == "table" and data.player == localPlayer then
        return true
    end

    return false
end

local function IsInputBlocked()
    if Input and Input.IsInputCaptured then
        local ok, captured = SafeCall(Input.IsInputCaptured)
        if ok and captured then
            return true
        end
    end

    if Input and Input.IsPopupOpen then
        local ok, popup = SafeCall(Input.IsPopupOpen)
        if ok and popup then
            return true
        end
    end

    return false
end

local function IsAllowedGameState()
    if not GameRules or not GameRules.GetGameState then
        return true
    end

    local ok, gameState = SafeCall(GameRules.GetGameState)
    if not ok then
        return true
    end

    return ALLOWED_GAME_STATES[gameState] == true
end

local function IsInGame()
    if not Engine or not Engine.IsInGame then
        return false
    end
    local ok, value = SafeCall(Engine.IsInGame)
    return ok and value == true
end

local function GetLocalHero(allowDead)
    if not Heroes or not Heroes.GetLocal then
        return nil
    end

    local ok, hero = SafeCall(Heroes.GetLocal)
    if not ok or not hero then
        return nil
    end

    if not allowDead and Entity and Entity.IsAlive and not SafeCall(Entity.IsAlive, hero) then
        return nil
    end

    return hero
end

local function GetMethod()
    if not UI.Method or not UI.Method.Get then
        return METHOD_SMART
    end

    local ok, value = SafeCall(UI.Method.Get, UI.Method)
    if not ok or value == nil then
        return METHOD_SMART
    end

    return value
end

local function GetVectorXYZ(pos)
    if not pos then
        return nil, nil, nil
    end

    local x = ReadMember(pos, "x")
    local y = ReadMember(pos, "y")
    local z = ReadMember(pos, "z")
    if type(x) == "number" and type(y) == "number" then
        return x, y, type(z) == "number" and z or 0
    end

    if pos.GetX and pos.GetY then
        local okX, vx = SafeCall(pos.GetX, pos)
        local okY, vy = SafeCall(pos.GetY, pos)
        local okZ, vz = SafeCall(pos.GetZ, pos)
        if okX and okY and type(vx) == "number" and type(vy) == "number" then
            return vx, vy, (okZ and type(vz) == "number") and vz or 0
        end
    end

    return nil, nil, nil
end

local function Dist2D(a, b)
    local ax, ay = GetVectorXYZ(a)
    local bx, by = GetVectorXYZ(b)
    if not ax or not bx then
        return math.huge
    end
    local dx = ax - bx
    local dy = ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function ResetBehaviorState()
    State.pendingTarget = nil
    State.activeModeLabel = nil
    State.actionLogLabel = nil
    State.lastTargetPos = nil
    State.lastTargetCamp = nil
    State.lastTreeCluster = nil
end

local function SetActionLogLabel(label)
    State.actionLogLabel = label
    State.activeModeLabel = label
end

--#endregion

--#region Menu

local function EnsureMenu()
    if State.menuReady and UI.Enable then
        return UI
    end

    local group = Menu.Find("Miscellaneous", "Other", "Anti AFK", "Main", "Anti AFK")
    if not group then
        local otherSection = Menu.Find("Miscellaneous", "Other")
        if otherSection and otherSection.Create then
            local secondTab = otherSection:Create("Anti AFK")
            MenuIcon(secondTab, Icons.tab)
            if secondTab and secondTab.Create then
                local mainTab = secondTab:Create("Main")
                if mainTab and mainTab.Create then
                    group = mainTab:Create("Anti AFK")
                end
            end
        end
    end

    if not group then
        group = Menu.Create("Miscellaneous", "Other", "Anti AFK", "Main", "Anti AFK")
    end

    if not group then
        error(LOG_PREFIX .. "Failed to create menu group")
    end

    EnsureSecondTabIcon()

    UI.Enable = group:Switch("Enable", false)
    MenuIcon(UI.Enable, Icons.enable)
    WithTooltip(UI.Enable, "Issue realistic movement while idle to avoid AFK detection.")

    UI.Interval = group:Slider("Interval", 15, 180, 50, "%d sec")
    MenuIcon(UI.Interval, Icons.interval)
    WithTooltip(UI.Interval, "Seconds between anti-AFK actions.")

    UI.OnlyWhenIdle = group:Switch("Only when idle", true)
    MenuIcon(UI.OnlyWhenIdle, Icons.idle)
    WithTooltip(UI.OnlyWhenIdle, "Act only after no player input for the idle threshold.")

    UI.DrawIndicator = group:Switch("Draw indicator", false)
    MenuIcon(UI.DrawIndicator, Icons.hud)
    WithTooltip(UI.DrawIndicator, "Glass HUD panel with progress and mode above your hero portrait.")

    local gear = UI.Enable:Gear("Settings", Icons.gear, true)

    UI.Method = gear:Combo("Method", METHOD_ITEMS, METHOD_SMART)
    MenuIcon(UI.Method, Icons.method)
    WithTooltip(
        UI.Method,
        "Wander: random safe steps nearby. Jungle Farm: nearest neutral camp when clear. "
            .. "Tree Hide: move into tree clusters for passive XP. Smart: hide from enemies, "
            .. "else farm nearby camps, else wander. Fountain Dance: small steps near team fountain."
    )

    UI.IdleThreshold = gear:Slider("Idle threshold", 10, 120, 30, "%d sec")
    MenuIcon(UI.IdleThreshold, Icons.idleThreshold)
    WithTooltip(UI.IdleThreshold, "How long without input before anti-AFK may act.")

    UI.SearchRadius = gear:Slider("Search radius", 400, 3000, 1200, "%d")
    MenuIcon(UI.SearchRadius, Icons.search)
    WithTooltip(UI.SearchRadius, "How far to look for jungle camps or tree clusters.")

    UI.EnemyAvoid = gear:Slider("Enemy avoid radius", 400, 3000, 1000, "%d")
    MenuIcon(UI.EnemyAvoid, Icons.enemy)
    WithTooltip(UI.EnemyAvoid, "Skip jungle/wander targets when enemy heroes are within this range.")

    UI.WanderDistance = gear:Slider("Max wander distance", 150, 1500, 600, "%d")
    MenuIcon(UI.WanderDistance, Icons.wander)
    WithTooltip(UI.WanderDistance, "Maximum step length for wander and fallback movement.")

    UI.MicroActionInterval = gear:Slider("Micro action every N pulses", 0, 10, 3, "%d")
    MenuIcon(UI.MicroActionInterval, Icons.micro)
    WithTooltip(
        UI.MicroActionInterval,
        "Every N pulses: stop, move, attack nearest neutral (0 or 1 = off, 2–10 = interval)."
    )

    UI.AvoidRecentSightings = gear:Switch("Avoid recent enemy sightings", true)
    MenuIcon(UI.AvoidRecentSightings, Icons.sight)
    WithTooltip(
        UI.AvoidRecentSightings,
        "Avoid areas where enemy heroes were recently visible (uses visibility heuristics)."
    )

    UI.JungleAfterFour = gear:Switch("Jungle only after 4:00", true)
    MenuIcon(UI.JungleAfterFour, Icons.jungle)
    WithTooltip(
        UI.JungleAfterFour,
        "Before the 4:00 game clock, Smart and Jungle modes stay near fountain or wander only."
    )

    local function UpdateControls()
        local enabled = UI.Enable:Get()

        UI.Interval:Disabled(not enabled)
        UI.OnlyWhenIdle:Disabled(not enabled)
        UI.DrawIndicator:Disabled(not enabled)
        UI.Method:Disabled(not enabled)
        UI.IdleThreshold:Disabled(not enabled or not UI.OnlyWhenIdle:Get())
        UI.SearchRadius:Disabled(not enabled)
        UI.EnemyAvoid:Disabled(not enabled)
        UI.WanderDistance:Disabled(not enabled)
        UI.MicroActionInterval:Disabled(not enabled)
        UI.AvoidRecentSightings:Disabled(not enabled)
        UI.JungleAfterFour:Disabled(not enabled)
    end

    UI.Enable:SetCallback(UpdateControls, true)
    UI.OnlyWhenIdle:SetCallback(UpdateControls, true)

    State.menuReady = true
    return UI
end

--#endregion

--#region Activity

local function TrackKeyboardActivity(now)
    if not Input or not Input.IsKeyDown then
        return false
    end

    for i = 1, #ACTIVITY_KEYS do
        local key = ACTIVITY_KEYS[i]
        local ok, pressed = SafeCall(Input.IsKeyDown, key, true)
        if ok and pressed then
            TouchUserActivity(now)
            ResetBehaviorState()
            return true
        end
    end

    return false
end

local function TrackCursorActivity(now)
    if not Input or not Input.GetCursorPos then
        return false
    end

    local ok, x, y = SafeCall(Input.GetCursorPos)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    if State.lastCursorX and State.lastCursorY then
        local dx = x - State.lastCursorX
        local dy = y - State.lastCursorY
        if (dx * dx + dy * dy) >= (CURSOR_MOVE_THRESHOLD * CURSOR_MOVE_THRESHOLD) then
            TouchUserActivity(now)
            ResetBehaviorState()
            State.lastCursorX = x
            State.lastCursorY = y
            return true
        end
    end

    State.lastCursorX = x
    State.lastCursorY = y
    return false
end

local function TrackUserActivity()
    local now = GetNow()
    if TrackKeyboardActivity(now) then
        return
    end
    TrackCursorActivity(now)
end

--#endregion

--#region Behavior

local function GetSliderValue(widget, fallback)
    if not widget or not widget.Get then
        return fallback
    end
    local ok, value = SafeCall(widget.Get, widget)
    if ok and type(value) == "number" then
        return value
    end
    return fallback
end

local function GetHeroOrigin(hero)
    if not hero or not Entity or not Entity.GetAbsOrigin then
        return nil
    end
    local ok, origin = SafeCall(Entity.GetAbsOrigin, hero)
    if ok and origin then
        return origin
    end
    return nil
end

local function IsTraversable(from, to)
    if not from or not to or not GridNav or not GridNav.IsTraversableFromTo then
        return true
    end
    local ok, traversable = SafeCall(GridNav.IsTraversableFromTo, from, to, false, nil)
    return ok and traversable == true
end

local function IsHeroReady(hero)
    if not hero then
        return false
    end

    if Entity and Entity.IsAlive then
        local ok, alive = SafeCall(Entity.IsAlive, hero)
        if not ok or not alive then
            return false
        end
    end

    if NPC and NPC.IsStunned then
        local ok, stunned = SafeCall(NPC.IsStunned, hero)
        if ok and stunned then
            return false
        end
    end

    if NPC and NPC.IsChannellingAbility then
        local ok, channeling = SafeCall(NPC.IsChannellingAbility, hero)
        if ok and channeling then
            return false
        end
    end

    return true
end

local function CountEnemiesNear(pos, radius, hero)
    if not pos or not hero or not Heroes or not Heroes.InRadius or not Entity or not Entity.GetTeamNum then
        return 0
    end

    local okTeam, team = SafeCall(Entity.GetTeamNum, hero)
    if not okTeam or team == nil then
        return 0
    end

    local ok, enemies = SafeCall(Heroes.InRadius, pos, radius, team, Enum.TeamType.TEAM_ENEMY, true, true)
    if not ok or not enemies then
        return 0
    end

    local count = 0
    for i = 1, #enemies do
        local enemy = enemies[i]
        if Entity.IsAlive and SafeCall(Entity.IsAlive, enemy) then
            local visible = true
            if NPC and NPC.IsVisible then
                local okVis, isVis = SafeCall(NPC.IsVisible, enemy)
                visible = okVis and isVis == true
            end
            if visible and Entity.IsDormant then
                local okDorm, dormant = SafeCall(Entity.IsDormant, enemy)
                if okDorm and dormant then
                    visible = false
                end
            end
            if visible then
                count = count + 1
            end
        end
    end
    return count
end

local function PruneEnemySightings(now)
    local sightings = State.enemySightings
    local write = 1
    for i = 1, #sightings do
        local entry = sightings[i]
        if entry and entry.untilTime and entry.untilTime > now then
            sightings[write] = entry
            write = write + 1
        end
    end
    for i = write, #sightings do
        sightings[i] = nil
    end
end

local function IsPositionRecentlySpotted(pos, radius)
    if not pos or not UI.AvoidRecentSightings or not UI.AvoidRecentSightings:Get() then
        return false
    end

    local now = GetNow()
    PruneEnemySightings(now)

    for i = 1, #State.enemySightings do
        local entry = State.enemySightings[i]
        if entry and entry.pos and Dist2D(pos, entry.pos) <= radius then
            return true
        end
    end

    return false
end

local function IsAreaSafe(pos, hero, avoidRadius)
    if CountEnemiesNear(pos, avoidRadius, hero) > 0 then
        return false
    end
    if IsPositionRecentlySpotted(pos, avoidRadius) then
        return false
    end
    return true
end

local function IsAncientCamp(camp)
    local ancientType = Enum.ECampType and Enum.ECampType.ECampType_ANCIENT
    if ancientType == nil or not Camp or not Camp.GetType then
        return false
    end
    local ok, campType = SafeCall(Camp.GetType, camp)
    return ok and campType == ancientType
end

local function GetCampCenter(camp)
    if not camp or not Camp or not Camp.GetCampBox then
        return nil
    end

    local ok, box = SafeCall(Camp.GetCampBox, camp)
    if not ok or not box or not box.min or not box.max then
        return nil
    end

    local minX, minY, minZ = GetVectorXYZ(box.min)
    local maxX, maxY, maxZ = GetVectorXYZ(box.max)
    if not minX or not maxX then
        return nil
    end

    return Vector(
        (minX + maxX) * 0.5,
        (minY + maxY) * 0.5,
        (minZ + maxZ) * 0.5
    )
end

local function CollectCampsNear(origin, radius)
    if not origin then
        return {}
    end

    local camps
    if Camps and Camps.InRadius then
        local ok, found = SafeCall(Camps.InRadius, origin, radius)
        if ok and found then
            camps = found
        end
    end

    if not camps or #camps == 0 then
        if Camps and Camps.GetAll then
            local ok, all = SafeCall(Camps.GetAll)
            if ok and all then
                camps = all
            end
        end
    end

    if not camps then
        return {}
    end

    local result = {}
    for i = 1, #camps do
        local camp = camps[i]
        if camp and not IsAncientCamp(camp) then
            local center = GetCampCenter(camp)
            if center and Dist2D(origin, center) <= radius then
                result[#result + 1] = { camp = camp, center = center }
            end
        end
    end

    return result
end

local function PosNear(a, b, minDist)
    if not a or not b then
        return false
    end
    return Dist2D(a, b) < (minDist or TARGET_REPEAT_MIN_DIST)
end

local function CampsEqual(campA, campB)
    if not campA or not campB then
        return false
    end
    if campA == campB then
        return true
    end
    local centerA = GetCampCenter(campA)
    local centerB = GetCampCenter(campB)
    if centerA and centerB then
        return PosNear(centerA, centerB, 80)
    end
    return false
end

local function FindNearestSafeCamp(hero, searchRadius, avoidRadius)
    local origin = GetHeroOrigin(hero)
    if not origin then
        return nil, nil
    end

    local camps = CollectCampsNear(origin, searchRadius)
    local candidates = {}

    for i = 1, #camps do
        local entry = camps[i]
        if IsAreaSafe(entry.center, hero, avoidRadius) then
            candidates[#candidates + 1] = entry
        end
    end

    if #candidates == 0 then
        return nil, nil
    end

    local pickFrom = candidates
    if State.lastTargetCamp then
        local alternate = {}
        for i = 1, #candidates do
            if not CampsEqual(candidates[i].camp, State.lastTargetCamp) then
                alternate[#alternate + 1] = candidates[i]
            end
        end
        if #alternate > 0 then
            pickFrom = alternate
        end
    end

    if State.lastTargetPos then
        local alternate = {}
        for i = 1, #pickFrom do
            if not PosNear(pickFrom[i].center, State.lastTargetPos) then
                alternate[#alternate + 1] = pickFrom[i]
            end
        end
        if #alternate > 0 then
            pickFrom = alternate
        end
    end

    local bestEntry = pickFrom[1]
    local bestDist = Dist2D(origin, bestEntry.center)
    for i = 2, #pickFrom do
        local dist = Dist2D(origin, pickFrom[i].center)
        if dist < bestDist then
            bestDist = dist
            bestEntry = pickFrom[i]
        end
    end

    return bestEntry.camp, bestEntry.center
end

local function IsValidNeutral(unit)
    if not unit or not Entity or not Entity.IsAlive or not SafeCall(Entity.IsAlive, unit) then
        return false
    end

    if NPC and NPC.IsWaitingToSpawn then
        local ok, waiting = SafeCall(NPC.IsWaitingToSpawn, unit)
        if ok and waiting then
            return false
        end
    end

    if NPC and NPC.IsInvulnerable then
        local ok, invuln = SafeCall(NPC.IsInvulnerable, unit)
        if ok and invuln then
            return false
        end
    end

    if NPC and NPC.IsNeutral then
        local ok, neutral = SafeCall(NPC.IsNeutral, unit)
        if ok and neutral then
            if NPC.IsAncient then
                local okAncient, ancient = SafeCall(NPC.IsAncient, unit)
                if okAncient and ancient then
                    return false
                end
            end
            return true
        end
    end

    return false
end

local function FindNeutralNear(pos, radius)
    if not pos or not NPCs or not NPCs.GetAll then
        return nil
    end

    local ok, npcs = SafeCall(NPCs.GetAll)
    if not ok or not npcs then
        return nil
    end

    local best, bestDist = nil, radius
    for i = 1, #npcs do
        local unit = npcs[i]
        if IsValidNeutral(unit) then
            local unitPos = GetHeroOrigin(unit)
            if unitPos then
                local dist = Dist2D(pos, unitPos)
                if dist <= radius and dist < bestDist then
                    bestDist = dist
                    best = unit
                end
            end
        end
    end

    return best
end

local function FindTreeHidePosition(origin, radius, hero)
    if not origin or not Trees or not Trees.InRadius then
        return nil
    end

    local ok, trees = SafeCall(Trees.InRadius, origin, radius, true)
    if not ok or not trees or #trees == 0 then
        return nil
    end

    local avoidRadius = hero and GetSliderValue(UI.EnemyAvoid, 1000) or 1000
    local bestPos, bestScore = nil, -1
    for i = 1, #trees do
        local tree = trees[i]
        if not tree or not Entity or not Entity.GetAbsOrigin then
            goto continue_tree
        end

        local okPos, pos = SafeCall(Entity.GetAbsOrigin, tree)
        if okPos and pos then
            if hero and not IsAreaSafe(pos, hero, avoidRadius) then
                goto continue_tree
            end

            local neighbors = 0
            for j = 1, #trees do
                if i ~= j then
                    local okOther, otherPos = SafeCall(Entity.GetAbsOrigin, trees[j])
                    if okOther and otherPos and Dist2D(pos, otherPos) <= TREE_CLUSTER_RADIUS then
                        neighbors = neighbors + 1
                    end
                end
            end

            local score = neighbors
            if State.lastTreeCluster and PosNear(pos, State.lastTreeCluster, TREE_CLUSTER_RADIUS * 0.5) then
                score = score - 100
            end
            if State.lastTargetPos and PosNear(pos, State.lastTargetPos) then
                score = score - 50
            end

            if score > bestScore then
                bestScore = score
                bestPos = pos
            end
        end

        ::continue_tree::
    end

    return bestPos
end

local function IsGamePaused()
    if not GameRules or not GameRules.IsPaused then
        return false
    end
    local ok, paused = SafeCall(GameRules.IsPaused)
    return ok and paused == true
end

local function GetGameState()
    if not GameRules or not GameRules.GetGameState then
        return nil
    end
    local ok, state = SafeCall(GameRules.GetGameState)
    if ok then
        return state
    end
    return nil
end

local function IsPreGamePhase()
    local state = GetGameState()
    return state ~= nil and PRE_GAME_STATES[state] == true
end

local function RecordTarget(pos, camp, treePos)
    if pos then
        State.lastTargetPos = pos
    end
    if camp then
        State.lastTargetCamp = camp
    end
    if treePos then
        State.lastTreeCluster = treePos
    end
end

local function UpdateEnemySightings(hero)
    if not hero or not UI.AvoidRecentSightings or not UI.AvoidRecentSightings:Get() then
        return
    end

    if not Heroes or not Heroes.InRadius or not Entity or not Entity.GetTeamNum then
        return
    end

    local origin = GetHeroOrigin(hero)
    if not origin then
        return
    end

    local okTeam, team = SafeCall(Entity.GetTeamNum, hero)
    if not okTeam or team == nil then
        return
    end

    local ok, enemies = SafeCall(
        Heroes.InRadius,
        origin,
        ENEMY_SIGHT_RECORD_RADIUS,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )
    if not ok or not enemies then
        return
    end

    local now = GetNow()
    PruneEnemySightings(now)

    for i = 1, #enemies do
        local enemy = enemies[i]
        if Entity.IsAlive and SafeCall(Entity.IsAlive, enemy) then
            local visible = true
            if NPC and NPC.IsVisible then
                local okVis, isVis = SafeCall(NPC.IsVisible, enemy)
                visible = okVis and isVis == true
            end
            if visible and Entity.IsDormant then
                local okDorm, dormant = SafeCall(Entity.IsDormant, enemy)
                if okDorm and dormant then
                    visible = false
                end
            end

            if visible then
                local enemyPos = GetHeroOrigin(enemy)
                if enemyPos then
                    State.enemySightings[#State.enemySightings + 1] = {
                        pos = enemyPos,
                        untilTime = now + ENEMY_SIGHT_AVOID_SECONDS,
                    }
                end
            end
        end
    end
end

local function GetGameElapsed()
    if GameRules and GameRules.GetDOTATime then
        local ok, value = SafeCall(GameRules.GetDOTATime, false)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function IsJungleBlocked()
    if not UI.JungleAfterFour or not UI.JungleAfterFour:Get() then
        return false
    end
    return GetGameElapsed() < JUNGLE_UNLOCK_SECONDS
end

local function GetTeamFountainPos(hero)
    if not hero or not Entity or not Entity.GetTeamNum then
        return nil
    end

    local ok, team = SafeCall(Entity.GetTeamNum, hero)
    if ok and team ~= nil and FOUNTAIN_POS[team] then
        return FOUNTAIN_POS[team]
    end

    return nil
end

local function GetWanderDistance()
    local maxDist = GetSliderValue(UI.WanderDistance, 600)
    if GetGameElapsed() < EARLY_GAME_SECONDS then
        return math.min(maxDist, EARLY_GAME_WANDER_CAP)
    end
    return maxDist
end

local function PickWanderPoint(hero, anchorFountain)
    local origin = GetHeroOrigin(hero)
    if not origin then
        return nil
    end

    local maxDist = GetWanderDistance()
    local ox, oy, oz = GetVectorXYZ(origin)
    if not ox then
        return nil
    end

    local fountain = anchorFountain and GetTeamFountainPos(hero) or nil
    local fx, fy, fz = GetVectorXYZ(fountain)

    for _ = 1, 8 do
        local target
        if fountain and fx then
            State.fountainDanceAngle = State.fountainDanceAngle + FOUNTAIN_DANCE_STEP + (math.random() - 0.5) * 0.4
            local ring = IsPreGamePhase() and FOUNTAIN_DANCE_RADIUS_PRE or math.min(FOUNTAIN_DANCE_RADIUS_GAME, maxDist)
            local step = ring * (0.4 + math.random() * 0.6)
            target = Vector(
                fx + math.cos(State.fountainDanceAngle) * step,
                fy + math.sin(State.fountainDanceAngle) * step,
                fz or oz
            )
        else
            local angle = math.random() * math.pi * 2
            local dist = maxDist * (0.35 + math.random() * 0.65)
            target = Vector(
                ox + math.cos(angle) * dist,
                oy + math.sin(angle) * dist,
                oz
            )
        end

        local avoidRepeat = not PosNear(target, State.lastTargetPos)
        if IsTraversable(origin, target) and Dist2D(origin, target) >= MIN_MOVE_DIST and avoidRepeat then
            return target
        end
    end

    for _ = 1, 4 do
        local angle = math.random() * math.pi * 2
        local dist = maxDist * (0.35 + math.random() * 0.65)
        local target = Vector(
            ox + math.cos(angle) * dist,
            oy + math.sin(angle) * dist,
            oz
        )
        if IsTraversable(origin, target) and Dist2D(origin, target) >= MIN_MOVE_DIST then
            return target
        end
    end

    local fallback = Vector(ox + 120, oy + 80, oz)
    if IsTraversable(origin, fallback) then
        return fallback
    end

    return nil
end

local function IssueHoldPosition(hero, tag)
    local player = Players and Players.GetLocal and Players.GetLocal() or nil
    if not player or not hero or not Player or not Player.HoldPosition then
        return false
    end

    return SafeCall(
        Player.HoldPosition,
        player,
        hero,
        false,
        true,
        true,
        ORDER_PREFIX .. tag
    )
end

local function IssueMoveTo(hero, pos, tag, queue)
    if not hero or not pos then
        return false
    end

    if NPC and NPC.MoveTo then
        return SafeCall(
            NPC.MoveTo,
            hero,
            pos,
            queue == true,
            false,
            true,
            false,
            ORDER_PREFIX .. tag,
            false
        )
    end

    local player = Players and Players.GetLocal and Players.GetLocal() or nil
    if player and Player and Player.PrepareUnitOrders then
        return SafeCall(
            Player.PrepareUnitOrders,
            player,
            ORDER_MOVE,
            nil,
            pos,
            nil,
            ORDER_ISSUER,
            hero,
            queue == true,
            false,
            true,
            false,
            ORDER_PREFIX .. tag,
            false
        )
    end

    return false
end

local function IssueAttackMove(hero, pos, tag)
    local player = Players and Players.GetLocal and Players.GetLocal() or nil
    if not player or not hero or not pos or not Player or not Player.PrepareUnitOrders then
        return false
    end

    return SafeCall(
        Player.PrepareUnitOrders,
        player,
        ORDER_ATTACK_MOVE,
        nil,
        pos,
        nil,
        ORDER_ISSUER,
        hero,
        false,
        false,
        true,
        false,
        ORDER_PREFIX .. tag,
        false
    )
end

local function IssueAttackTarget(hero, target, tag, queue)
    local player = Players and Players.GetLocal and Players.GetLocal() or nil
    if not player or not hero or not target or not Player or not Player.AttackTarget then
        return false
    end

    return SafeCall(
        Player.AttackTarget,
        player,
        hero,
        target,
        queue == true,
        true,
        false,
        ORDER_PREFIX .. tag,
        false
    )
end

local function GetMicroActionInterval()
    local value = GetSliderValue(UI.MicroActionInterval, 3)
    if value <= 1 then
        return 0
    end
    return value
end

local function ShouldRunMicroAction()
    local interval = GetMicroActionInterval()
    if interval <= 0 then
        return false
    end
    return State.pulseCount > 0 and (State.pulseCount % interval) == 0
end

local function ExecuteMicroAction(hero)
    local origin = GetHeroOrigin(hero)
    if not origin then
        return false
    end

    local searchRadius = GetSliderValue(UI.SearchRadius, 1200)
    local neutral = FindNeutralNear(origin, searchRadius)
    if not neutral then
        return false
    end

    local neutralPos = GetHeroOrigin(neutral)
    SetActionLogLabel("Micro")
    IssueHoldPosition(hero, "micro.stop")

    if neutralPos then
        IssueMoveTo(hero, neutralPos, "micro.move", true)
    end

    IssueAttackTarget(hero, neutral, "micro.attack", true)
    RecordTarget(neutralPos, nil, nil)
    return true
end

local function ExecuteFountainDance(hero)
    local fountain = GetTeamFountainPos(hero)
    local origin = GetHeroOrigin(hero)
    if not fountain or not origin then
        SetActionLogLabel("Wander")
        local point = PickWanderPoint(hero, false)
        if point then
            RecordTarget(point, nil, nil)
            return IssueMoveTo(hero, point, "wander")
        end
        return false
    end

    SetActionLogLabel("Fountain")
    local avoidRadius = GetSliderValue(UI.EnemyAvoid, 1000)
    local maxRing = IsPreGamePhase() and FOUNTAIN_DANCE_RADIUS_PRE or FOUNTAIN_DANCE_RADIUS_GAME
    State.fountainDanceAngle = State.fountainDanceAngle + FOUNTAIN_DANCE_STEP + (math.random() - 0.5) * 0.35

    local fx, fy, fz = GetVectorXYZ(fountain)
    local stepDist = math.min(maxRing * 0.55, IsPreGamePhase() and 100 or 170)
    local target = Vector(
        fx + math.cos(State.fountainDanceAngle) * stepDist,
        fy + math.sin(State.fountainDanceAngle) * stepDist,
        fz or 0
    )

    if Dist2D(target, fountain) > maxRing then
        local ox, oy = GetVectorXYZ(origin)
        local dx, dy = fx - ox, fy - oy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 1 then
            target = Vector(fx - (dx / len) * stepDist * 0.5, fy - (dy / len) * stepDist * 0.5, fz or 0)
        end
    end

    if not IsAreaSafe(target, hero, avoidRadius) then
        State.fountainDanceAngle = State.fountainDanceAngle + math.pi
        target = Vector(
            fx + math.cos(State.fountainDanceAngle) * stepDist,
            fy + math.sin(State.fountainDanceAngle) * stepDist,
            fz or 0
        )
    end

    if not PosNear(target, State.lastTargetPos) and IsTraversable(origin, target) then
        RecordTarget(target, nil, nil)
        return IssueMoveTo(hero, target, "fountain")
    end

    local fallback = PickWanderPoint(hero, true)
    if fallback then
        RecordTarget(fallback, nil, nil)
        return IssueMoveTo(hero, fallback, "fountain.wander")
    end

    return false
end

local function ExecuteWander(hero, anchorFountain)
    SetActionLogLabel("Wander")
    local avoidRadius = GetSliderValue(UI.EnemyAvoid, 1000)
    local origin = GetHeroOrigin(hero)
    if origin and not IsAreaSafe(origin, hero, avoidRadius) then
        local maxDist = GetWanderDistance() * 0.5
        local ox, oy, oz = GetVectorXYZ(origin)
        if ox then
            local retreat = Vector(ox - maxDist * 0.35, oy - maxDist * 0.35, oz)
            if IsTraversable(origin, retreat) then
                RecordTarget(retreat, nil, nil)
                return IssueMoveTo(hero, retreat, "wander.retreat")
            end
        end
    end

    local point = PickWanderPoint(hero, anchorFountain == true)
    if not point then
        return false
    end

    RecordTarget(point, nil, nil)
    return IssueMoveTo(hero, point, "wander")
end

local function ExecuteSafeEarlyFallback(hero)
    if GetTeamFountainPos(hero) then
        return ExecuteFountainDance(hero)
    end
    SetActionLogLabel("Wander")
    return ExecuteWander(hero)
end

local function SetActiveModeLabel(methodIndex, smartResolved)
    local label = MODE_LABELS[(methodIndex or 0) + 1] or "AntiAFK"
    if methodIndex == METHOD_SMART and smartResolved then
        label = "Smart·" .. smartResolved
    end
    SetActionLogLabel(label)
end

local function ExecuteJungleFarm(hero)
    if IsJungleBlocked() then
        return ExecuteSafeEarlyFallback(hero)
    end

    SetActionLogLabel("Farm")
    local searchRadius = GetSliderValue(UI.SearchRadius, 1200)
    local avoidRadius = GetSliderValue(UI.EnemyAvoid, 1000)
    local camp, campCenter = FindNearestSafeCamp(hero, searchRadius, avoidRadius)
    if not campCenter then
        return ExecuteWander(hero, false)
    end

    if not IsAreaSafe(campCenter, hero, avoidRadius) then
        return ExecuteWander(hero, false)
    end

    local neutral = FindNeutralNear(campCenter, CAMP_NEUTRAL_RADIUS)
    RecordTarget(campCenter, camp, nil)
    if neutral then
        return IssueAttackTarget(hero, neutral, "jungle.attack")
    end

    return IssueAttackMove(hero, campCenter, "jungle.move")
end

local function ExecuteTreeHide(hero)
    SetActionLogLabel("Hide")
    local searchRadius = GetSliderValue(UI.SearchRadius, 1200)
    local origin = GetHeroOrigin(hero)
    if not origin then
        return false
    end

    local treePos = FindTreeHidePosition(origin, searchRadius, hero)
    if not treePos then
        return ExecuteWander(hero, false)
    end

    RecordTarget(treePos, nil, treePos)
    return IssueMoveTo(hero, treePos, "tree")
end

local function ResolveSmartMode(hero)
    local origin = GetHeroOrigin(hero)
    local avoidRadius = GetSliderValue(UI.EnemyAvoid, 1000)
    local searchRadius = GetSliderValue(UI.SearchRadius, 1200)

    if origin and CountEnemiesNear(origin, avoidRadius, hero) > 0 then
        return METHOD_TREE_HIDE, "Hide"
    end

    if not IsJungleBlocked() then
        local _, campCenter = FindNearestSafeCamp(hero, searchRadius, avoidRadius)
        if campCenter then
            return METHOD_JUNGLE, "Farm"
        end
    end

    if IsJungleBlocked() and GetTeamFountainPos(hero) then
        return METHOD_FOUNTAIN, "Fountain"
    end

    return METHOD_WANDER, "Wander"
end

local function ExecuteSmart(hero)
    local resolved, resolvedLabel = ResolveSmartMode(hero)
    SetActiveModeLabel(METHOD_SMART, resolvedLabel)

    if resolved == METHOD_JUNGLE then
        return ExecuteJungleFarm(hero)
    end
    if resolved == METHOD_TREE_HIDE then
        return ExecuteTreeHide(hero)
    end
    if resolved == METHOD_FOUNTAIN then
        return ExecuteFountainDance(hero)
    end
    return ExecuteWander(hero, false)
end

local function PerformAntiAFK(method)
    if IsGamePaused() then
        return false
    end

    local hero = GetLocalHero(false)
    if not IsHeroReady(hero) then
        return false
    end

    if ShouldRunMicroAction() and ExecuteMicroAction(hero) then
        return true
    end

    if method == METHOD_FOUNTAIN then
        return ExecuteFountainDance(hero)
    end

    if method == METHOD_WANDER then
        SetActionLogLabel("Wander")
        return ExecuteWander(hero, IsPreGamePhase())
    end

    if method == METHOD_JUNGLE then
        SetActionLogLabel("Farm")
        return ExecuteJungleFarm(hero)
    end

    if method == METHOD_TREE_HIDE then
        SetActionLogLabel("Hide")
        return ExecuteTreeHide(hero)
    end

    return ExecuteSmart(hero)
end

local function ShouldPulse(now)
    if not UI.Enable or not UI.Enable:Get() then
        return false
    end

    if not IsInGame() or not IsAllowedGameState() then
        return false
    end

    if IsInputBlocked() then
        return false
    end

    if IsGamePaused() then
        return false
    end

    if not IsHeroReady(GetLocalHero(false)) then
        return false
    end

    local interval = GetSliderValue(UI.Interval, 50)
    if now - State.lastPulseAt < interval then
        return false
    end

    if UI.OnlyWhenIdle and UI.OnlyWhenIdle:Get() then
        local idleThreshold = GetSliderValue(UI.IdleThreshold, 30)
        if now - State.lastUserActivityAt < idleThreshold then
            return false
        end
    end

    return true
end

local function EnsureTimers(now)
    if State.lastPulseAt <= 0 then
        State.lastPulseAt = now
    end
    if State.lastUserActivityAt <= 0 then
        State.lastUserActivityAt = now
    end
end

--#endregion

--#region Theme

local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    TextTimer = Color(120, 200, 255, 255),
    TextMode = Color(120, 180, 220, 255),
    BarBg = Color(40, 40, 50, 200),
    BarFill = Color(120, 200, 255, 255),
    Border = Color(120, 200, 255, 90),
}

local fontPanel = 0

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
    Colors.TextTimer = Color(primary.r, primary.g, primary.b, 255)
    Colors.BarFill = Color(primary.r, primary.g, primary.b, 255)
    Colors.Border = Color(primary.r, primary.g, primary.b, 90)
    Colors.TextMode = Color(primary.r, primary.g, primary.b, 180)
end

--#endregion

--#region HUD

local function ClampByte(value, fallback)
    if type(value) ~= "number" then
        return fallback or 0
    end
    if value < 0 then
        return 0
    end
    if value > 255 then
        return 255
    end
    return math.floor(value + 0.5)
end

local function LerpColor(a, b, t)
    t = math.max(0, math.min(1, t or 0))
    return Color(
        ClampByte((a.r or 0) + ((b.r or 0) - (a.r or 0)) * t, 0),
        ClampByte((a.g or 0) + ((b.g or 0) - (a.g or 0)) * t, 0),
        ClampByte((a.b or 0) + ((b.b or 0) - (a.b or 0)) * t, 0),
        ClampByte((a.a or 255) + ((b.a or 255) - (a.a or 255)) * t, 255)
    )
end

local function ShiftNeonColor(base, phase)
    local wave = 0.5 + 0.5 * math.sin(phase)
    return Color(
        ClampByte((base.r or 0) + 70 * wave, 0),
        ClampByte((base.g or 0) + 45 * (1 - wave), 0),
        ClampByte((base.b or 0) + 90 * wave, 0),
        base.a or 255
    )
end

local function GetIndicatorProgress(now)
    local idleOnly = UI.OnlyWhenIdle and UI.OnlyWhenIdle:Get()
    local idleThreshold = UI.IdleThreshold and UI.IdleThreshold:Get() or 30
    local idleFor = now - State.lastUserActivityAt

    if idleOnly and idleFor < idleThreshold then
        return math.max(0, math.min(1, idleFor / math.max(idleThreshold, 1))), false
    end

    local interval = UI.Interval and UI.Interval:Get() or 50
    local elapsed = now - State.lastPulseAt
    return math.max(0, math.min(1, elapsed / math.max(interval, 1))), true
end

local function GetScreenSize()
    if Render and Render.ScreenSize then
        local ok, screen = SafeCall(Render.ScreenSize)
        if ok and screen and type(screen.x) == "number" and type(screen.y) == "number" then
            return screen.x, screen.y
        end
    end
    return nil, nil
end

local function ResolvePortraitPanelBounds()
    if Panorama and Panorama.GetPanelInfo then
        for i = 1, #PORTRAIT_PANEL_PATHS do
            local ok, bounds = SafeCall(Panorama.GetPanelInfo, PORTRAIT_PANEL_PATHS[i], false, true)
            if ok and bounds and type(bounds.x) == "number" and type(bounds.y) == "number"
                and type(bounds.w) == "number" and bounds.w > 0 and type(bounds.h) == "number" and bounds.h > 0 then
                return bounds
            end
        end
    end

    if Panorama and Panorama.GetPanelByPath then
        local okHud, hud = SafeCall(Panorama.GetPanelByPath, { "HUDElements", "lower_hud" }, false)
        if okHud and hud then
            for i = 1, #PORTRAIT_TRAVERSE_IDS do
                local panel = nil
                if hud.FindChildTraverse then
                    local okPanel, found = SafeCall(hud.FindChildTraverse, hud, PORTRAIT_TRAVERSE_IDS[i])
                    if okPanel then
                        panel = found
                    end
                end

                if panel and panel.GetBounds then
                    local okBounds, bounds = SafeCall(panel.GetBounds, panel, true)
                    if okBounds and bounds and type(bounds.w) == "number" and bounds.w > 0 then
                        return bounds
                    end
                end
            end
        end
    end

    return nil
end

local function BuildFallbackPortraitBounds()
    local sw, sh = GetScreenSize()
    if not sw or not sh then
        return nil
    end

    local portraitW = math.min(math.max(math.floor(sh * 0.056), PANEL_MIN_WIDTH), 88)
    local portraitH = math.min(math.max(math.floor(sh * 0.066), 62), 82)
    local portraitX = math.min(math.max(math.floor(sw * 0.015), 20), 38)
    local portraitY = math.min(math.max(math.floor(sh * 0.034), 28), 52)
    return {
        x = portraitX,
        y = portraitY,
        w = portraitW,
        h = portraitH,
    }
end

local function GetPortraitBounds(now)
    now = now or GetNow()
    if State.portraitBounds and (now - (State.portraitBoundsAt or 0)) < PORTRAIT_CACHE_TTL then
        return State.portraitBounds
    end

    local bounds = ResolvePortraitPanelBounds() or BuildFallbackPortraitBounds()
    if bounds then
        State.portraitBounds = bounds
        State.portraitBoundsAt = now
    end

    return bounds
end

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

local function TryLoadPanelFont(size, sampleText)
    if not Render or not Render.LoadFont or not Render.TextSize then
        return 0
    end

    local fontFlag = Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0
    local weights = {
        Enum and Enum.FontWeight and Enum.FontWeight.SEMIBOLD or 600,
        Enum and Enum.FontWeight and Enum.FontWeight.MEDIUM or 500,
        Enum and Enum.FontWeight and Enum.FontWeight.NORMAL or 400,
        400,
    }

    for i = 1, #INDICATOR_FONT_CANDIDATES do
        local fontName = INDICATOR_FONT_CANDIDATES[i]
        for w = 1, #weights do
            local ok, handle = SafeCall(Render.LoadFont, fontName, fontFlag, weights[w])
            if ok and IsValidFontHandle(handle) then
                local okSize, sizeVec = SafeCall(Render.TextSize, handle, size, sampleText)
                local sizeW = sizeVec and sizeVec.x or 0
                if okSize and IsValidTextSize(sizeVec) and sizeW > 0 then
                    return handle
                end
            end
        end
    end

    return 0
end

local function EnsureIndicatorAssets()
    if State.fontIndicator == nil then
        State.fontIndicator = TryLoadPanelFont(PANEL_TITLE_TEXT_SIZE, INDICATOR_LABEL)
    end
    if not IsValidFontHandle(fontPanel) then
        fontPanel = TryLoadPanelFont(PANEL_HEADER_TEXT_SIZE, INDICATOR_LABEL) or 0
    end
end

local function GetPanelFont()
    EnsureIndicatorAssets()
    if IsValidFontHandle(fontPanel) then
        return fontPanel
    end
    return State.fontIndicator or 0
end

local function MeasurePanelTextSize(fontSize, text, font)
    font = font or GetPanelFont()
    local fallback = Vec2(text:len() * fontSize * 0.55, fontSize)
    if not IsValidFontHandle(font) or not Render or not Render.TextSize then
        return fallback
    end

    local ok, size = SafeCall(Render.TextSize, font, fontSize, text)
    if ok and IsValidTextSize(size) then
        return size
    end
    return fallback
end

local function MeasureIndicatorText(font, size, text)
    return MeasurePanelTextSize(size, text, font)
end

local function DrawPanelText(size, text, pos, color)
    local font = GetPanelFont()
    if not IsValidFontHandle(font) or not Render or not Render.Text then
        return false
    end

    local shadow = Color(0, 0, 0, 140)
    SafeCall(Render.Text, font, size, text, Vec2(pos.x + 1, pos.y + 1), shadow)
    return SafeCall(Render.Text, font, size, text, pos, color) == true
end

local function GetMenuBlurStrength()
    local widget = Menu and Menu.Find and Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")
    if not widget or not widget.Get then
        return PANEL_BLUR_BASE_STRENGTH
    end

    local ok, factor = SafeCall(widget.Get, widget)
    if not ok or type(factor) ~= "number" or factor <= 0 then
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
        Vec2(layout.x + layout.width, layout.y + layout.headerH),
        strength,
        1.0,
        PANEL_HEADER_RADIUS * scale,
        Enum.DrawFlags.None)
end

local function EnsureHudIcon()
    if State.hudIcon == nil and Render and Render.LoadImage then
        State.hudIcon = SafeCall(Render.LoadImage, HUD_ICON)
    end
end

local function GetHeaderTimerText(now, armed)
    if not armed then
        local idleThreshold = UI.IdleThreshold and UI.IdleThreshold:Get() or 30
        local idleFor = now - State.lastUserActivityAt
        local remaining = math.max(0, idleThreshold - idleFor)
        return string.format("%.0fs", remaining)
    end

    local interval = UI.Interval and UI.Interval:Get() or 50
    local elapsed = now - State.lastPulseAt
    local remaining = math.max(0, interval - elapsed)
    return string.format("%.0fs", remaining)
end

local function DrawNeonTitle(textX, contentY, contentH, now, armed)
    EnsureIndicatorAssets()

    local font = State.fontIndicator or 0
    if font == 0 or not Render or not Render.Text then
        return textX
    end

    local label = INDICATOR_LABEL
    local size = PANEL_TITLE_TEXT_SIZE
    local phase = (now or 0) * 5.5
    local alpha = armed and 255 or 200
    local x = textX
    local textSize = MeasureIndicatorText(font, size, label)
    local textH = textSize and textSize.y or size
    local y = contentY + math.floor((contentH - textH) * 0.5 + 0.5)

    for i = 1, #label do
        local ch = label:sub(i, i)
        local charSize = MeasureIndicatorText(font, size, ch)
        local wave = 0.5 + 0.5 * math.sin(phase + i * 0.65)
        local neonA = ShiftNeonColor(Color(20, 240, 255, alpha), phase + i * 0.45)
        local neonB = ShiftNeonColor(Color(190, 70, 255, alpha), phase + i * 0.45 + 1.4)
        local col = LerpColor(neonA, neonB, wave)
        local pos = Vec2(x, y)
        local shadowA = math.floor(alpha * 0.85)

        SafeCall(Render.Text, font, size, ch, Vec2(pos.x + 2, pos.y + 2), Color(0, 0, 0, shadowA))
        SafeCall(Render.Text, font, size, ch, Vec2(pos.x + 1, pos.y + 1), Color(0, 0, 0, math.floor(alpha * 0.65)))
        SafeCall(Render.Text, font, size, ch, pos, col)
        SafeCall(
            Render.Text,
            font,
            size,
            ch,
            Vec2(pos.x - 1, pos.y),
            Color(col.r, col.g, col.b, math.floor(alpha * 0.45))
        )

        x = x + (charSize and charSize.x or 0)
    end

    return x
end

local function GetPanelLayout(bounds, scale, now)
    local progress, armed = GetIndicatorProgress(now)
    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local barPadY = PANEL_BAR_PAD_Y * scale
    local barH = PANEL_BAR_H * scale
    local modePadY = PANEL_MODE_PAD_Y * scale
    local modeTextSize = PANEL_MODE_TEXT_SIZE * scale
    local iconSize = PANEL_HEADER_ICON_SIZE * scale
    local iconGap = PANEL_HEADER_ICON_GAP * scale
    local titleFontSize = PANEL_HEADER_TEXT_SIZE * scale
    local timerText = GetHeaderTimerText(now, armed)
    local modeText = State.actionLogLabel or State.activeModeLabel or (armed and "Ready" or "Idle")

    local titleSize = MeasureIndicatorText(State.fontIndicator or 0, PANEL_TITLE_TEXT_SIZE * scale, INDICATOR_LABEL)
    local timerSize = MeasurePanelTextSize(titleFontSize, timerText)
    local modeSize = MeasurePanelTextSize(modeTextSize, modeText)

    local titleW = titleSize and titleSize.x or 0
    local timerW = timerSize and timerSize.x or 0
    local labelContentW = iconSize + iconGap + titleW
    local headerW = padX + labelContentW + iconGap + timerW + padX
    local width = math.max(PANEL_MIN_WIDTH * scale, math.max(bounds.w, headerW))
    local headerH = titleH
    local barSectionH = barPadY + barH + barPadY
    local modeSectionH = modePadY + (modeSize and modeSize.y or modeTextSize) + modePadY
    local height = headerH + barSectionH + modeSectionH
    local x = bounds.x + math.floor((bounds.w - width) * 0.5 + 0.5)
    local y = bounds.y - PANEL_ABOVE_PORTRAIT * scale - height

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        headerH = headerH,
        padX = padX,
        barH = barH,
        barPadY = barPadY,
        barSectionH = barSectionH,
        modePadY = modePadY,
        modeTextSize = modeTextSize,
        modeText = modeText,
        modeSize = modeSize,
        titleFontSize = titleFontSize,
        timerText = timerText,
        timerSize = timerSize,
        iconSize = iconSize,
        iconGap = iconGap,
        progress = progress,
        armed = armed,
    }
end

local function DrawAntiAfkPanel(layout, now)
    local armed = layout.armed
    local progress = layout.progress
    local scale = layout.scale or 1
    local phase = (now or 0) * 5.5
    local neonA = ShiftNeonColor(Color(20, 240, 255, 255), phase)
    local neonB = ShiftNeonColor(Color(190, 70, 255, 255), phase + 1.8)
    local barColor = armed
        and LerpColor(Colors.BarFill, LerpColor(neonA, neonB, 0.5), 0.45)
        or Color(Colors.BarFill.r, Colors.BarFill.g, Colors.BarFill.b, 140)
    local timerColor = armed and Colors.TextTimer or Color(Colors.TextTimer.r, Colors.TextTimer.g, Colors.TextTimer.b, 170)

    DrawPanelBlur(layout, scale)

    if Render and Render.Shadow then
        SafeCall(
            Render.Shadow,
            Vec2(layout.x - 2, layout.y - 2),
            Vec2(layout.x + layout.width + 2, layout.y + layout.headerH + 2),
            Color(Colors.Border.r, Colors.Border.g, Colors.Border.b, armed and 120 or 70),
            14,
            PANEL_HEADER_RADIUS * scale,
            Enum.DrawFlags.ShadowCutOutShapeBackground,
            Vec2(0, 0)
        )
    end

    SafeCall(
        Render.FilledRect,
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.headerH),
        Colors.HeaderBg,
        PANEL_HEADER_RADIUS * scale)

    local timerSize = layout.timerSize
        or Vec2(layout.timerText:len() * layout.titleFontSize * 0.55, layout.titleFontSize)
    local timerH = timerSize.y or layout.titleFontSize
    local contentH = math.max(layout.iconSize, timerH, PANEL_TITLE_TEXT_SIZE * scale)
    local contentY = layout.y + math.floor((layout.headerH - contentH) * 0.5 + 0.5)
    local textX = layout.x + layout.padX

    if State.hudIcon and Render and Render.Image then
        local iconY = contentY + math.floor((contentH - layout.iconSize) * 0.5 + 0.5)
        SafeCall(
            Render.Image,
            State.hudIcon,
            Vec2(textX, iconY),
            Vec2(layout.iconSize, layout.iconSize),
            Color(255, 255, 255, armed and 255 or 190),
            5 * scale,
            Enum.DrawFlags.None)
        textX = textX + layout.iconSize + layout.iconGap
    end

    textX = DrawNeonTitle(textX, contentY, contentH, now, armed)

    local timerW = timerSize.x or 0
    local timerX = layout.x + layout.width - layout.padX - timerW
    local timerY = contentY + math.floor((contentH - timerH) * 0.5 + 0.5)
    DrawPanelText(layout.titleFontSize, layout.timerText, Vec2(timerX, timerY), timerColor)

    if Render and Render.OutlineGradient then
        SafeCall(
            Render.OutlineGradient,
            Vec2(layout.x, layout.y),
            Vec2(layout.x + layout.width, layout.y + layout.headerH),
            LerpColor(Colors.Border, Color(255, 255, 255, 120), 0.35),
            Colors.Border,
            LerpColor(neonA, Colors.Border, 0.5),
            LerpColor(neonB, Colors.Border, 0.5),
            PANEL_HEADER_RADIUS * scale,
            Enum.DrawFlags.None,
            1.0)
    elseif Render and Render.Rect then
        SafeCall(
            Render.Rect,
            Vec2(layout.x, layout.y),
            Vec2(layout.x + layout.width, layout.y + layout.headerH),
            Colors.Border,
            PANEL_HEADER_RADIUS * scale,
            Enum.DrawFlags.None,
            1)
    end

    local barY = layout.y + layout.headerH + layout.barPadY
    local barX = layout.x + layout.padX
    local barW = layout.width - layout.padX * 2
    local fillW = math.floor(barW * progress + 0.5)

    SafeCall(
        Render.FilledRect,
        Vec2(barX, barY),
        Vec2(barX + barW, barY + layout.barH),
        Colors.BarBg,
        layout.barH * 0.5,
        Enum.DrawFlags.None)

    if fillW > 0 then
        if armed and fillW > 2 and Render and Render.Gradient then
            SafeCall(
                Render.Gradient,
                Vec2(barX, barY),
                Vec2(barX + fillW, barY + layout.barH),
                neonA,
                neonB,
                neonB,
                neonA,
                layout.barH * 0.5,
                Enum.DrawFlags.None)
        else
            SafeCall(
                Render.FilledRect,
                Vec2(barX, barY),
                Vec2(barX + fillW, barY + layout.barH),
                barColor,
                layout.barH * 0.5,
                Enum.DrawFlags.None)
        end
    end

    local modeSize = layout.modeSize
        or Vec2(layout.modeText:len() * layout.modeTextSize * 0.55, layout.modeTextSize)
    local modeW = modeSize.x or 0
    local modeH = modeSize.y or layout.modeTextSize
    local modeX = layout.x + math.floor((layout.width - modeW) * 0.5 + 0.5)
    local modeY = layout.y + layout.headerH + layout.barSectionH + layout.modePadY
    local modeAlpha = armed and 200 or 120
    DrawPanelText(
        layout.modeTextSize,
        layout.modeText,
        Vec2(modeX, modeY),
        Color(Colors.TextMode.r, Colors.TextMode.g, Colors.TextMode.b, modeAlpha))
end

local function DrawIndicator(now)
    if not UI.DrawIndicator or not UI.DrawIndicator:Get() then
        return
    end

    if not Render then
        return
    end

    SyncColors()

    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local bounds = GetPortraitBounds(now)
    if not bounds or type(bounds.w) ~= "number" or bounds.w <= 0 then
        return
    end

    EnsureHudIcon()
    EnsureIndicatorAssets()

    local ok, scaleRaw = SafeCall(function()
        if Menu and Menu.Scale then
            return Menu.Scale()
        end
        return 100
    end)
    local scale = (type(scaleRaw) == "number" and scaleRaw or 100) / 100

    local layout = GetPanelLayout(bounds, scale, now)
    layout.scale = scale
    DrawAntiAfkPanel(layout, now)
end

--#endregion

--#region Lifecycle

EnsureMenu()

function Script.OnPrepareUnitOrders(data, player)
    if IsOurOrder(data) then
        return
    end

    if IsLocalPlayerOrder(player, data) then
        TouchUserActivity()
        ResetBehaviorState()
    end
end

function Script.OnUpdate()
    EnsureMenu()

    local now = GetNow()
    EnsureTimers(now)
    TrackUserActivity()

    local hero = GetLocalHero(false)
    if UI.Enable and UI.Enable:Get() and IsInGame() and IsAllowedGameState() and IsHeroReady(hero) then
        UpdateEnemySightings(hero)
    end

    if not ShouldPulse(now) then
        return
    end

    local method = GetMethod()
    PerformAntiAFK(method)
    State.pulseCount = State.pulseCount + 1
    State.lastPulseAt = now
end

function Script.OnDraw()
    if not UI.Enable or not UI.Enable:Get() then
        return
    end

    DrawIndicator(GetNow())
end

function Script.OnScriptsLoaded()
    State.fontIndicator = nil
    fontPanel = 0
    State.hudIcon = nil
    EnsureIndicatorAssets()
    EnsureHudIcon()
    SyncColors()
end

function Script.OnThemeUpdate()
    SyncColors()
    fontPanel = 0
end

function Script.OnGameEnd()
    State.lastPulseAt = 0
    State.lastUserActivityAt = 0
    State.lastCursorX = nil
    State.lastCursorY = nil
    State.portraitBounds = nil
    State.portraitBoundsAt = 0
    State.pulseCount = 0
    State.fountainDanceAngle = 0
    State.enemySightings = {}
    ResetBehaviorState()
end

--#endregion

return Script
