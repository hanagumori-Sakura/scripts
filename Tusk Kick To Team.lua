--[[
    Tusk Kick To Team
    Kicks enemies toward selected allied heroes with Walrus Kick vector orders.
    Auto-plans kick direction; Bind can Blink first, then Snowball the kicked enemy.
    Script by Euphoria
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
local TARGET_VISUAL_LANDING_RADIUS = 175
local TARGET_VISUAL_ALLY_RADIUS = 130

local PARTICLE_TARGET_RING = "particles/units/heroes/hero_tusk/tusk_snowball_target.vpcf"
local PARTICLE_KICK_PATH = "particles/units/heroes/hero_hoodwink/hoodwink_sharpshooter_range_finder.vpcf"
local PARTICLE_LANDING_RING = "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_calldown.vpcf"
local PARTICLE_ALLY_RING = "particles/ui_mouseactions/range_display.vpcf"

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

--#endregion

--#region State

local State = {
    lastCastTime = 0,
    lastAllySyncTime = -100,
    lastAllyRosterKey = "",
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
    targetVisualEnemyIndex = nil,
    targetVisualParticles = {},
    lastTargetVisualTime = -100,
    targetVisualPathSignature = "",
    cachedAllyNames = {},
    cachedAllyEntities = {},
    cachedAllyUnitNames = {},
    allyEnabled = {},
}

local UI = {}
local LoggerInstance = Logger and Logger("TuskKickToTeam") or nil

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

local function BuildAllyMultiSelectItems()
    local items = {}

    for _, cleanName in ipairs(State.cachedAllyNames) do
        items[#items + 1] = {
            cleanName,
            HeroIconPath(State.cachedAllyUnitNames[cleanName]),
            IsAllyKickEnabled(cleanName),
        }
    end

    return items
end

local function ApplyAllyPrefsToWidget(widget)
    if not widget or not widget.Set or not widget.List then
        return
    end

    local listed = SafeCall(widget.List, widget)
    if not listed then
        return
    end

    for _, cleanName in ipairs(listed) do
        local enabled = State.allyEnabled[cleanName]
        if enabled ~= nil then
            SafeCall(widget.Set, widget, cleanName, enabled == true)
        end
    end
end

local function SyncAllyPrefsFromWidget()
    local widget = UI.Allies
    if not widget or not widget.Get then
        return
    end

    local listed = widget.List and SafeCall(widget.List, widget)
    if not listed then
        return
    end

    for _, cleanName in ipairs(listed) do
        local value = SafeCall(widget.Get, widget, cleanName)
        if value ~= nil then
            SetAllyKickEnabled(cleanName, value == true)
        end
    end
end

--#endregion

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

    local ui = {}

    ui.Enabled = group:Switch("Kick To Team", false)
    ui.Enabled:Image(SPELL_ICON)

    ui.Allies = group:MultiSelect("Kick Target Allies", BuildAllyMultiSelectItems(), false)
    ui.Allies:Image(SPELL_ICON)
    if ui.Allies.SetCallback then
        ui.Allies:SetCallback(SyncAllyPrefsFromWidget, false)
    end

    local gear = ui.Enabled:Gear("Settings")
    ui.Mode = gear:Combo("Mode", MODE_ITEMS, MODE_AUTO)
    ui.Mode:Image(SPELL_ICON)
    ui.CastKey = gear:Bind("Kick Bind", Enum.ButtonCode.KEY_NONE)
    ui.CastKey:Image(SPELL_ICON)
    ui.Debug = gear:Switch("Debug Log", false)
    ui.Debug:Image(SPELL_ICON)

    local function UpdateControls()
        local enabled = ui.Enabled:Get()
        local isBindMode = (ui.Mode:Get() or MODE_AUTO) == MODE_BIND
        ui.Allies:Disabled(not enabled)
        ui.Mode:Disabled(not enabled)
        ui.CastKey:Disabled(not enabled or not isBindMode)
        ui.Debug:Disabled(not enabled)
    end

    ui.Enabled:SetCallback(UpdateControls, true)
    ui.Mode:SetCallback(UpdateControls, true)

    return ui
end

UI = InitializeUI()

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

local function BuildAllyRosterKey(names)
    return table.concat(names, ",")
end

local function RefreshAllySelection(hero, now, saveToConfig)
    if not hero then
        return false
    end

    if now - State.lastAllySyncTime < ALLY_SYNC_INTERVAL then
        return false
    end
    State.lastAllySyncTime = now

    local names = {}
    local entities = {}
    local unitNames = {}
    local allHeroes = Heroes.GetAll()

    for i = 1, #allHeroes do
        local other = allHeroes[i]
        if other ~= hero and IsValidHeroUnit(other) and Entity.IsSameTeam(other, hero) then
            local unitName = NPC.GetUnitName(other)
            local cleanName = CleanHeroName(unitName)
            if cleanName ~= "" then
                names[#names + 1] = cleanName
                entities[cleanName] = other
                unitNames[cleanName] = unitName
                if State.allyEnabled[cleanName] == nil then
                    IsAllyKickEnabled(cleanName)
                end
            end
        end
    end

    table.sort(names)

    local rosterKey = BuildAllyRosterKey(names)
    State.cachedAllyNames = names
    State.cachedAllyEntities = entities
    State.cachedAllyUnitNames = unitNames

    if rosterKey == State.lastAllyRosterKey then
        return false
    end

    State.lastAllyRosterKey = rosterKey
    SyncAllyPrefsFromWidget()

    if UI.Allies and UI.Allies.Update then
        SafeCall(UI.Allies.Update, UI.Allies, BuildAllyMultiSelectItems(), false, saveToConfig == true)
        ApplyAllyPrefsToWidget(UI.Allies)
    end

    return true
end

local function IsAllySelectedForKick(ally)
    local cleanName = CleanHeroName(NPC.GetUnitName(ally))
    if cleanName == "" then
        return false
    end

    if UI.Allies and UI.Allies.Get then
        local value = SafeCall(UI.Allies.Get, UI.Allies, cleanName)
        if value ~= nil then
            SetAllyKickEnabled(cleanName, value == true)
            return value == true
        end
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

--#region Target Visuals

local function GetParticleAttachType(name, fallback)
    if Enum and Enum.ParticleAttachment and Enum.ParticleAttachment[name] ~= nil then
        return Enum.ParticleAttachment[name]
    end

    return fallback
end

local PARTICLE_ATTACH_WORLD = GetParticleAttachType("PATTACH_WORLDORIGIN", 8)
local PARTICLE_ATTACH_FOLLOW = GetParticleAttachType("PATTACH_ABSORIGIN_FOLLOW", 1)

local function CanUseTargetParticles()
    return Particle and Particle.Create and Particle.Destroy and Particle.SetControlPoint
end

local function ClearTargetSelectionVisuals()
    State.targetVisualPathSignature = ""

    if not CanUseTargetParticles() then
        State.targetVisualEnemyIndex = nil
        State.targetVisualParticles = {}
        return
    end

    for _, particleIndex in pairs(State.targetVisualParticles) do
        if particleIndex then
            SafeCall(Particle.Destroy, particleIndex)
        end
    end

    State.targetVisualEnemyIndex = nil
    State.targetVisualParticles = {}
    State.targetVisualPathSignature = ""
end

local function DestroyTargetVisualSlot(slotName)
    local particleIndex = State.targetVisualParticles[slotName]
    if particleIndex and CanUseTargetParticles() then
        SafeCall(Particle.Destroy, particleIndex)
    end

    State.targetVisualParticles[slotName] = nil
end

local function CreateOwnedWorldParticle(hero, particlePath)
    if not CanUseTargetParticles() or not hero or not particlePath then
        return nil
    end

    local particleIndex = SafeCall(Particle.Create, particlePath, PARTICLE_ATTACH_WORLD, hero)
    if not particleIndex or particleIndex <= 0 then
        return nil
    end

    return particleIndex
end

local function CreateEntityFollowParticle(entity, particlePath)
    if not CanUseTargetParticles() or not entity or not particlePath then
        return nil
    end

    local particleIndex = SafeCall(Particle.Create, particlePath, PARTICLE_ATTACH_FOLLOW, entity)
    if not particleIndex or particleIndex <= 0 then
        return nil
    end

    return particleIndex
end

local function EnsureTargetVisualParticle(slotName, hero, particlePath)
    local particleIndex = State.targetVisualParticles[slotName]
    if particleIndex then
        return particleIndex
    end

    particleIndex = CreateOwnedWorldParticle(hero, particlePath)
    if particleIndex then
        State.targetVisualParticles[slotName] = particleIndex
    end

    return particleIndex
end

local function UpdateTargetEnemyRing(enemy)
    local enemyIndex = GetEntityIndexSafe(enemy)
    if State.targetVisualEnemyIndex ~= enemyIndex then
        DestroyTargetVisualSlot("enemyRing")
        State.targetVisualEnemyIndex = enemyIndex

        local particleIndex = CreateEntityFollowParticle(enemy, PARTICLE_TARGET_RING)
        if particleIndex then
            State.targetVisualParticles.enemyRing = particleIndex
        end
    end
end

local function BuildTargetPathSignature(startPos, endPos)
    return string.format(
        "%.0f:%.0f:%.0f:%.0f",
        startPos.x,
        startPos.y,
        endPos.x,
        endPos.y
    )
end

local function UpdateTargetPathParticle(hero, startPos, endPos)
    local signature = BuildTargetPathSignature(startPos, endPos)
    if State.targetVisualPathSignature == signature then
        return
    end

    State.targetVisualPathSignature = signature

    local particleIndex = EnsureTargetVisualParticle("kickPath", hero, PARTICLE_KICK_PATH)
    if not particleIndex then
        return
    end

    local groundStart = MakeGroundPosition(startPos)
    local groundEnd = MakeGroundPosition(endPos)
    if not groundStart or not groundEnd then
        return
    end

    local direction = MakeDirection2D(groundStart, groundEnd)
    local length = groundStart:Distance2D(groundEnd)

    SafeCall(Particle.SetControlPoint, particleIndex, 0, groundStart)
    SafeCall(Particle.SetControlPoint, particleIndex, 1, groundEnd)

    if direction then
        SafeCall(
            Particle.SetControlPoint,
            particleIndex,
            2,
            Vector(direction.x * length, direction.y * length, 0)
        )
    end
end

local function UpdateTargetLandingParticle(hero, pos, radius, slotName, particlePath, colorVariant)
    local particleIndex = EnsureTargetVisualParticle(slotName, hero, particlePath)
    if not particleIndex then
        return
    end

    local groundPos = MakeGroundPosition(pos)
    SafeCall(Particle.SetControlPoint, particleIndex, 0, groundPos)
    SafeCall(Particle.SetControlPoint, particleIndex, 1, Vector(radius, 0, 0))

    if colorVariant then
        SafeCall(Particle.SetControlPoint, particleIndex, 6, colorVariant)
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

local function RefreshTargetSelectionVisuals(force)
    if not CanUseTargetParticles() or not UI.Enabled:Get() or not Engine.IsInGame() then
        ClearTargetSelectionVisuals()
        return
    end

    local hero = Heroes.GetLocal()
    if not IsTusk(hero) then
        ClearTargetSelectionVisuals()
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
        ClearTargetSelectionVisuals()
        return
    end

    local plan = FindBestPlan(hero, kick, GetTargetPreviewScanDistance(hero, kick))
    if not plan or not IsValidHeroUnit(plan.enemy) then
        ClearTargetSelectionVisuals()
        return
    end

    UpdateTargetEnemyRing(plan.enemy)
    UpdateTargetPathParticle(hero, plan.enemyPos, plan.endPos)
    UpdateTargetLandingParticle(hero, plan.endPos, TARGET_VISUAL_LANDING_RADIUS, "landingRing", PARTICLE_LANDING_RING)
    UpdateTargetLandingParticle(
        hero,
        plan.desiredPos,
        TARGET_VISUAL_ALLY_RADIUS,
        "allyMarker",
        PARTICLE_ALLY_RING,
        Vector(1, 0, 0)
    )
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    State.lastAllySyncTime = -100
    State.lastAllyRosterKey = ""

    if Engine.IsInGame() then
        local hero = Heroes.GetLocal()
        if IsTusk(hero) then
            RefreshAllySelection(hero, GameRules.GetGameTime() or 0, true)
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
            ClearTargetSelectionVisuals()
            return
        end

    local hero = Heroes.GetLocal()
    if not hero then
        ClearVectorFollowup()
        ClearBlinkKickCombo()
        ClearSnowballCombo()
        ClearTargetSelectionVisuals()
        LogDebug("Bind blocked | local hero missing")
        return
    end

    if not IsTusk(hero) then
        ClearVectorFollowup()
        ClearBlinkKickCombo()
        ClearSnowballCombo()
        ClearTargetSelectionVisuals()
        LogDebug("Bind blocked | local hero is not Tusk: " .. tostring(SafeCall(NPC and NPC.GetUnitName, hero)))
        return
    end

    local now = GameRules.GetGameTime() or 0
    RefreshAllySelection(hero, now, true)

    if not UI.Enabled:Get() then
        ClearVectorFollowup()
        ClearBlinkKickCombo()
        ClearSnowballCombo()
        ClearTargetSelectionVisuals()
        return
    end

    RefreshTargetSelectionVisuals()

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

function Script.OnGameEnd()
    SyncAllyPrefsFromWidget()
    ClearTargetSelectionVisuals()
    State.lastCastTime = 0
    State.lastAllySyncTime = -100
    State.lastAllyRosterKey = ""
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
    State.targetVisualPathSignature = ""
end

--#endregion

return Script
