--[[
    Dead Shot
    Smart + fast Dead Shot on built-in Combo Key and Dead Shot Aim Key.
    Disable built-in Smart Dead Shot and Dead Shot Combo to avoid double-cast.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local SCRIPT_NAME = "DeadShot"
local DEBUG_PREFIX = "[" .. SCRIPT_NAME .. "] "
local CONFIG_SECTION = "muerta_smart_dead_shot"
local HERO_NAME = "npc_dota_hero_muerta"
local DEAD_SHOT_NAME = "muerta_dead_shot"
local ORDER_ID = "muerta.smart_dead_shot"

local ICON = {
    check = "\u{f00c}",
    gear = "\u{f013}",
    draw = "\u{f2d0}",
    bug = "\u{f188}",
}

local TARGET_SCAN_INTERVAL = 0.033
local FULL_PLAN_SOLVE_INTERVAL = 0.033
local ANCHOR_SCAN_INTERVAL = 0.12
local ANCHOR_ENEMY_MOVE_THRESHOLD = 72
local PLAN_RESOLVE_STABLE_INTERVAL = 0.10
local PLAN_SWITCH_SCORE_MARGIN = 7500
local PLAN_SWITCH_MIN_HOLD = 0.14
local PREDICT_MAX_ITERATIONS = 6
local PREDICT_POS_EPSILON = 3.5
local MOTION_SAMPLE_MIN_DT = 0.008
local BUILTIN_MENU_SYNC_INTERVAL = 1.0

local DEFAULT_CAST_RANGE = 1000
local DEFAULT_CAST_POINT = 0.15
local DEFAULT_PROJECTILE_SPEED = 2000
local DEFAULT_RICOCHET_MULTIPLIER = 1.5
local DEFAULT_RICOCHET_RADIUS = 115
local TREE_SEARCH_RADIUS = 650
local VECTOR_HINT_DISTANCE = 350
local ENEMY_HULL_RADIUS = 45
local FEAR_PUSH_DISTANCE = 250
local MAX_PREDICT_SPEED = 550
local MIN_MOTION_SPEED = 45
local MAX_ANCHORS = 56
local RICOCHET_PATH_BONUS = 7000
local CAST_REPEAT_DELAY = 0.65
local CAST_REPEAT_DELAY_CHARGED = 0.55
local CAST_REPEAT_DELAY_READY = 0.35
local POST_ORDER_LOCK_SUCCESS = 0.60
local VECTOR_FOLLOWUP_DELAY = 0.04
local VECTOR_FOLLOWUP_FIRST_DELAY = 0.05
local VECTOR_FOLLOWUP_TREE_EXTRA = 0.03
local VECTOR_FOLLOWUP_EXPIRE = 0.65
local VECTOR_FOLLOWUP_MAX_ATTEMPTS = 3
local FOLLOWUP_MAX_LIVE_VECTOR_DELTA = 240
local FOLLOWUP_FAIL_COOLDOWN = 0.45
local VECTOR_MIN_RAY_DISTANCE = 80

local BUILTIN_PATHS = {
    comboKey = { "Heroes", "Hero List", "Muerta", "Main Settings", "Hero Settings", "Combo Key" },
    comboKeyFallback = { "Heroes", "Hero List", "Muerta", "Main Settings", "General", "Combo Key" },
    aimKey = { "Heroes", "Hero List", "Muerta", "Main Settings", "Hero Settings", "Dead Shot Aim Key" },
    drawPreview = {
        "Heroes", "Hero List", "Muerta", "Main Settings", "Hero Settings",
        "Smart Dead Shot", "Settings", "Draw aim preview",
    },
    debugLogs = {
        "Heroes", "Hero List", "Muerta", "Main Settings", "Hero Settings",
        "Smart Dead Shot", "Settings", "Debug logs",
    },
}

local ORDER_CAST_TARGET_NAMES = { "CAST_TARGET", "DOTA_UNIT_ORDER_CAST_TARGET" }
local ORDER_CAST_TARGET_TREE_NAMES = { "CAST_TARGET_TREE", "DOTA_UNIT_ORDER_CAST_TARGET_TREE" }
local ORDER_VECTOR_TARGET_POSITION_NAMES = { "VECTOR_TARGET_POSITION", "DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION" }
local ORDER_ISSUER_PASSED_UNIT_ONLY_NAMES =
    { "PLAYER_ORDER_ISSUER_PASSED_UNIT_ONLY", "DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY" }
local ORDER_ISSUER_HERO_ONLY_NAMES = { "PLAYER_ORDER_ISSUER_HERO_ONLY", "DOTA_ORDER_ISSUER_HERO_ONLY" }
local ORDER_ISSUER_SCRIPT_NAMES = { "PLAYER_ORDER_ISSUER_SCRIPT", "DOTA_ORDER_ISSUER_SCRIPT" }

local MAGIC_IMMUNE_MODIFIERS = {
    "modifier_black_king_bar_immune",
    "modifier_omniknight_guardian_angel",
    "modifier_winter_wyvern_cold_embrace",
}

--#endregion

--#region State

local State = {
    menuReady = false,
    lastBuiltinSyncAt = -100,
    lastPlanAt = -100,
    lastAnchorScanAt = -100,
    lastTargetScanAt = -100,
    postOrderLockUntil = 0,
    activeBindMode = nil,
    lockedAimTarget = nil,
    lockedComboTarget = nil,
    combatTarget = nil,
    unitMotion = {},
    anchorBuffer = {},
    anchorSeen = {},
    enemyBuffer = {},
    bestPlan = nil,
    precomputedCast = nil,
    lockedCastPlan = nil,
    planLockedAt = -100,
    lastAnchorEnemyPos = nil,
    pendingVectorStep = nil,
    orderContext = nil,
    abilityStats = nil,
    cachedAnchorCount = 0,
    lastSuccessfulCastAt = -100,
    lastCastCharges = nil,
    lastAnchorDebug = nil,
    preferredIssuer = nil,
    lastLoggedPlanKey = nil,
    nextDebugLogAt = {},
    _logger = nil,
}

local UI = {}
local BuiltIn = {}

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

local function SaveConfigInt(key, value)
    SafeCall(Config.WriteInt, CONFIG_SECTION, key, value)
end

local function LoadConfigInt(key, defaultValue)
    local stored = SafeCall(Config.ReadInt, CONFIG_SECTION, key, defaultValue)
    if stored == nil then
        return defaultValue
    end
    return stored
end

local function TryMenuFind(...)
    if not Menu or not Menu.Find then
        return nil
    end
    local ok, result = pcall(Menu.Find, ...)
    if ok then
        return result
    end
    return nil
end

local function CallWidgetMethod(widget, method, ...)
    if not widget then
        return nil
    end
    local fn = widget[method]
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, widget, ...)
    if ok then
        return result
    end
    ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function WidgetGet(widget, default)
    if not widget then
        return default
    end
    local value = CallWidgetMethod(widget, "Get")
    if value == nil then
        return default
    end
    return value
end

local function WidgetIsDown(widget)
    if not widget then
        return false
    end
    if CallWidgetMethod(widget, "IsDown") then
        return true
    end
    return false
end

local function Log(level, message)
    message = tostring(message)
    local logger = State._logger
    if logger == nil then
        State._logger = Logger and Logger(SCRIPT_NAME) or false
        logger = State._logger
    end
    if logger and logger[level] then
        pcall(logger[level], logger, message)
        return
    end
    print(DEBUG_PREFIX .. message)
end

local function IsDebugEnabled()
    return WidgetGet(BuiltIn.debugLogs, false) or (UI.Debug and WidgetGet(UI.Debug, false))
end

local function FmtPos(pos)
    if not pos then
        return "?"
    end
    return string.format("%.0f,%.0f", pos.x or 0, pos.y or 0)
end

local function FmtEntityRef(entity)
    if not entity then
        return "nil"
    end

    local idx = SafeCall(Entity.GetIndex, entity)
    local name = SafeCall(NPC.GetUnitName, entity)
    if name and idx then
        return string.format("%s#%d", name, idx)
    end
    if idx then
        return string.format("ent#%d", idx)
    end
    if name then
        return name
    end
    return tostring(entity)
end

local function FmtSnapshot(snap)
    if not snap then
        return "{}"
    end

    return string.format(
        "{ch=%s,cd=%.2f,phase=%s,active=%s}",
        tostring(snap.charges),
        snap.cooldown or 0,
        snap.inPhase and "1" or "0",
        snap.activeAbility and (SafeCall(Ability.GetName, snap.activeAbility) or "?") or "nil"
    )
end

local function LogCastDebug(event, details)
    if not IsDebugEnabled() then
        return
    end
    Log("debug", string.format("[%s] %s", event, details))
end

local function LogCastDebugThrottled(key, interval, event, details)
    if not IsDebugEnabled() then
        return
    end

    local now = SafeCall(GameRules.GetGameTime) or 0
    local nextAt = State.nextDebugLogAt[key] or -100
    if now < nextAt then
        return
    end

    State.nextDebugLogAt[key] = now + interval
    LogCastDebug(event, details)
end

local function LogCastDebugOnce(pending, key, event, details)
    if not pending then
        return
    end
    pending.debugOnce = pending.debugOnce or {}
    if pending.debugOnce[key] then
        return
    end
    pending.debugOnce[key] = true
    LogCastDebug(event, details)
end

local function DescribeCastPlan(plan, me, stats)
    if not plan then
        return "plan=nil"
    end

    local myPos = me and SafeCall(Entity.GetAbsOrigin, me)
    local anchorPos = plan.castTargetPos
    local enemyPos = plan.enemy and SafeCall(Entity.GetAbsOrigin, plan.enemy)

    local function localDist2D(a, b)
        if not a or not b then
            return -1
        end
        local dx = (a.x or 0) - (b.x or 0)
        local dy = (a.y or 0) - (b.y or 0)
        return math.sqrt(dx * dx + dy * dy)
    end

    local rayTarget = plan.predictedPos or enemyPos or plan.vectorPos or plan.ricochetEnd
    local dirX, dirY = 0, 0
    if anchorPos and rayTarget then
        local dx = (rayTarget.x or 0) - (anchorPos.x or 0)
        local dy = (rayTarget.y or 0) - (anchorPos.y or 0)
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.001 then
            dirX, dirY = dx / len, dy / len
        end
    end

    local distMeAnchor = localDist2D(myPos, anchorPos)
    local distAnchorEnemy = localDist2D(anchorPos, enemyPos)
    local ricochetDist = distMeAnchor >= 0 and stats
        and distMeAnchor * (stats.ricochetMultiplier or DEFAULT_RICOCHET_MULTIPLIER)
        or -1

    return string.format(
        "bind=%s mode=%s dir=%s cert=%.2f score=%.0f | me=(%s) anchor=%s@(%s) enemy=%s@(%s) pred=(%s) vec=(%s) ricEnd=(%s) ray=(%.2f,%.2f) dist_me_anchor=%.0f dist_anchor_enemy=%.0f ricDist=%.0f",
        tostring(State.activeBindMode or "?"),
        tostring(plan.mode),
        tostring(plan.directionTag or "?"),
        plan.hitCertainty or 0,
        plan.score or 0,
        FmtPos(myPos),
        FmtEntityRef(plan.castTarget),
        FmtPos(anchorPos),
        FmtEntityRef(plan.enemy),
        FmtPos(enemyPos),
        FmtPos(plan.predictedPos),
        FmtPos(plan.vectorPos),
        FmtPos(plan.ricochetEnd),
        dirX,
        dirY,
        distMeAnchor,
        distAnchorEnemy,
        ricochetDist or -1
    )
end

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

local function ResolveUnitOrder(candidates)
    return ResolveEnumValue(Enum and Enum.UnitOrder or nil, candidates)
end

local function ResolveOrderIssuer(candidates)
    return ResolveEnumValue(Enum and Enum.PlayerOrderIssuer or nil, candidates)
end

local function GetResolvedOrderContext()
    if State.orderContext then
        return State.orderContext
    end

    local ctx = {}
    ctx.castTarget = ResolveUnitOrder(ORDER_CAST_TARGET_NAMES)
    ctx.castTargetTree = ResolveUnitOrder(ORDER_CAST_TARGET_TREE_NAMES)
    ctx.vectorTargetPosition = ResolveUnitOrder(ORDER_VECTOR_TARGET_POSITION_NAMES)
    State.orderContext = ctx
    return ctx
end

local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
    return (a - b):Length2D()
end

local function Normalize2D(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

local function MakeGroundPosition(pos)
    if not pos then
        return nil
    end
    return Vector(pos.x, pos.y, pos.z)
end

local function MoveTowards2D(from, dirX, dirY, distance)
    return Vector(from.x + dirX * distance, from.y + dirY * distance, from.z)
end

local function Dot2D(ax, ay, bx, by)
    return ax * bx + ay * by
end

local function AlongRayFromAnchor(anchorPos, dirX, dirY, distance)
    return MakeGroundPosition(MoveTowards2D(anchorPos, dirX, dirY, distance))
end

local function GetRayDistanceAlong(anchorPos, dirX, dirY, pos)
    if not anchorPos or not pos then
        return nil
    end
    local dx = (pos.x or 0) - (anchorPos.x or 0)
    local dy = (pos.y or 0) - (anchorPos.y or 0)
    return Dot2D(dx, dy, dirX, dirY)
end

local function DistPointToSegment2D(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local apx = px - ax
    local apy = py - ay
    local abLenSq = abx * abx + aby * aby
    if abLenSq < 0.001 then
        local dx = px - ax
        local dy = py - ay
        return math.sqrt(dx * dx + dy * dy)
    end

    local t = (apx * abx + apy * aby) / abLenSq
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end

    local cx = ax + abx * t
    local cy = ay + aby * t
    local dx = px - cx
    local dy = py - cy
    return math.sqrt(dx * dx + dy * dy)
end

local function MenuIcon(widget, icon)
    if not widget or not icon then
        return
    end
    if widget.Icon then
        if not pcall(widget.Icon, widget, icon) then
            pcall(widget.Icon, icon)
        end
    end
end

--#endregion

--#region Built-in menu hook

local function FindBuiltinWidget(path)
    return TryMenuFind(table.unpack(path))
end

local function SyncBuiltInMenu(force)
    local now = SafeCall(GlobalVars.GetCurTime) or 0
    if not force and now - State.lastBuiltinSyncAt < BUILTIN_MENU_SYNC_INTERVAL then
        return
    end
    State.lastBuiltinSyncAt = now

    BuiltIn.comboKey = FindBuiltinWidget(BUILTIN_PATHS.comboKey)
        or FindBuiltinWidget(BUILTIN_PATHS.comboKeyFallback)
    BuiltIn.aimKey = FindBuiltinWidget(BUILTIN_PATHS.aimKey)
    BuiltIn.drawPreview = FindBuiltinWidget(BUILTIN_PATHS.drawPreview)
    BuiltIn.debugLogs = FindBuiltinWidget(BUILTIN_PATHS.debugLogs)
end

local function IsComboKeyHeld()
    return WidgetIsDown(BuiltIn.comboKey)
end

local function IsAimKeyHeld()
    return WidgetIsDown(BuiltIn.aimKey)
end

local function IsAnyBindHeld()
    if IsComboKeyHeld() then
        State.activeBindMode = "combo"
        return true
    end
    if IsAimKeyHeld() then
        State.activeBindMode = "aim"
        return true
    end
    State.activeBindMode = nil
    return false
end

local function ShouldDrawPreview()
    if UI.DrawOverlay and WidgetGet(UI.DrawOverlay, false) then
        return true
    end
    return WidgetGet(BuiltIn.drawPreview, false) == true
end

--#endregion

--#region Menu

local function EnsureMenu()
    if State.menuReady then
        return
    end
    if not Menu or not Menu.Find or not Menu.Create then
        return
    end

    local group = TryMenuFind("Heroes", "Hero List", "Muerta", "Main Settings", "Dead Shot")
    if not group then
        local mainSettings = TryMenuFind("Heroes", "Hero List", "Muerta", "Main Settings")
        if mainSettings and mainSettings.Create then
            group = mainSettings:Create("Dead Shot")
        end
    end

    if not group then
        group = Menu.Create("Scripts", "Combat", "Dead Shot", "Main", "Dead Shot")
    end
    if not group then
        return
    end

    UI.Enabled = group:Switch("Enable", LoadConfigInt("enabled", 1) == 1, ICON.check)

    local gear = UI.Enabled:Gear("Settings", ICON.gear, true)
    UI.Debug = gear:Switch("Debug logs", LoadConfigInt("debug", 0) == 1)
    MenuIcon(UI.Debug, ICON.bug)
    UI.DrawOverlay = gear:Switch("Draw overlay", LoadConfigInt("draw_overlay", 1) == 1)
    MenuIcon(UI.DrawOverlay, ICON.draw)

    local function UpdateControls()
        local enabled = WidgetGet(UI.Enabled, true)
        if UI.Debug and UI.Debug.Disabled then
            UI.Debug:Disabled(not enabled)
        end
        if UI.DrawOverlay and UI.DrawOverlay.Disabled then
            UI.DrawOverlay:Disabled(not enabled)
        end
    end

    UI.Enabled:SetCallback(function()
        SaveConfigInt("enabled", WidgetGet(UI.Enabled, true) and 1 or 0)
        UpdateControls()
    end, true)

    UI.Debug:SetCallback(function()
        SaveConfigInt("debug", WidgetGet(UI.Debug, false) and 1 or 0)
    end, true)

    UI.DrawOverlay:SetCallback(function()
        SaveConfigInt("draw_overlay", WidgetGet(UI.DrawOverlay, true) and 1 or 0)
    end, true)

    UpdateControls()
    State.menuReady = true
end

--#endregion

--#region Unit validation

local function IsValidHero(unit)
    return unit
        and SafeCall(Entity.IsAlive, unit)
        and not SafeCall(Entity.IsDormant, unit)
        and not SafeCall(NPC.IsIllusion, unit)
end

local function IsFriendlyUnit(unit, me)
    if not unit or not me then
        return false
    end
    if SafeCall(Entity.IsSameTeam, unit, me) == true then
        return true
    end

    local unitTeam = SafeCall(Entity.GetTeamNum, unit)
    local myTeam = SafeCall(Entity.GetTeamNum, me)
    return unitTeam ~= nil and myTeam ~= nil and unitTeam == myTeam
end

local function IsValidEnemyTarget(unit, me)
    if not IsValidHero(unit) then
        return false
    end
    if IsFriendlyUnit(unit, me) then
        return false
    end
    return true
end

local function IsEnemyVisible(enemy)
    if not IsValidHero(enemy) then
        return false
    end
    if SafeCall(NPC.IsVisible, enemy) == false then
        return false
    end
    local pos = SafeCall(Entity.GetAbsOrigin, enemy)
    if pos and FogOfWar and FogOfWar.IsPointVisible then
        return SafeCall(FogOfWar.IsPointVisible, pos) ~= false
    end
    return true
end

local function IsMagicImmune(unit)
    if not IsValidHero(unit) then
        return true
    end
    if SafeCall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
        return true
    end
    for i = 1, #MAGIC_IMMUNE_MODIFIERS do
        if SafeCall(NPC.HasModifier, unit, MAGIC_IMMUNE_MODIFIERS[i]) then
            return true
        end
    end
    return false
end

local function HasHardBlock(unit)
    if not unit then
        return true
    end
    if SafeCall(NPC.HasModifier, unit, "modifier_item_sphere_target") then
        return true
    end
    if SafeCall(NPC.HasModifier, unit, "modifier_antimage_spell_shield") then
        return true
    end
    if SafeCall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
        return true
    end
    return false
end

local function IsSafeCastTarget(unit)
    if Humanizer and Humanizer.IsSafeTarget then
        local ok, safe = pcall(Humanizer.IsSafeTarget, unit)
        if ok and safe == false then
            return false
        end
    end
    return true
end

local function CanCastOnEnemy(enemy, me)
    return IsValidEnemyTarget(enemy, me)
        and IsEnemyVisible(enemy)
        and not IsMagicImmune(enemy)
        and not HasHardBlock(enemy)
        and IsSafeCastTarget(enemy)
end

local function CanAct(me)
    if not IsValidHero(me) then
        return false
    end
    return not SafeCall(NPC.IsStunned, me)
        and not SafeCall(NPC.IsSilenced, me)
        and not SafeCall(NPC.HasState, me, Enum.ModifierState.MODIFIER_STATE_ROOTED)
end

--#endregion

--#region Motion prediction

local function UpdateUnitMotionCache(units)
    if not units then
        return
    end

    local now = SafeCall(GlobalVars.GetCurTime) or 0

    for i = 1, #units do
        local unit = units[i]
        local idx = SafeCall(Entity.GetIndex, unit)
        local pos = SafeCall(Entity.GetAbsOrigin, unit)
        if idx and pos then
            local entry = State.unitMotion[idx]
            if entry and entry.time then
                local dt = now - entry.time
                if dt >= MOTION_SAMPLE_MIN_DT and dt <= 0.75 then
                    local vx = (pos.x - entry.x) / dt
                    local vy = (pos.y - entry.y) / dt
                    local speed = math.sqrt(vx * vx + vy * vy)
                    if speed > MAX_PREDICT_SPEED then
                        local scale = MAX_PREDICT_SPEED / speed
                        vx = vx * scale
                        vy = vy * scale
                    end
                    entry.vx = vx
                    entry.vy = vy
                    entry.x = pos.x
                    entry.y = pos.y
                    entry.z = pos.z
                    entry.time = now
                elseif dt > 0.75 then
                    entry.vx = nil
                    entry.vy = nil
                    entry.x = pos.x
                    entry.y = pos.y
                    entry.z = pos.z
                    entry.time = now
                end
            else
                State.unitMotion[idx] = {
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    time = now,
                }
            end
        end
    end
end

local function GetSampledVelocity(unit)
    local idx = SafeCall(Entity.GetIndex, unit)
    local motion = idx and State.unitMotion[idx]
    if not motion or not motion.vx or not motion.vy then
        return 0, 0, 0
    end

    local vx = motion.vx
    local vy = motion.vy
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed < MIN_MOTION_SPEED then
        return 0, 0, 0
    end

    return vx, vy, speed
end

local function ComputeProjectileTravelTime(myPos, anchorPos, targetPos, stats)
    if not myPos or not anchorPos or not targetPos or not stats or stats.projectileSpeed <= 0 then
        return 0
    end

    return stats.castPoint
        + Dist2D(myPos, anchorPos) / stats.projectileSpeed
        + Dist2D(anchorPos, targetPos) / stats.projectileSpeed
end

local function PredictUnitPos(unit, basePos, leadTime)
    if not unit or not basePos or leadTime <= 0 then
        return basePos
    end
    if SafeCall(NPC.IsStunned, unit) or SafeCall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
        return basePos
    end

    local vx, vy, speed = GetSampledVelocity(unit)
    if speed < MIN_MOTION_SPEED then
        return basePos
    end

    return Vector(
        basePos.x + vx * leadTime,
        basePos.y + vy * leadTime,
        basePos.z
    )
end

local function GetPredictedEnemyPos(enemy, leadTime)
    local pos = SafeCall(Entity.GetAbsOrigin, enemy)
    if not pos then
        return nil
    end
    return PredictUnitPos(enemy, pos, leadTime)
end

--#endregion

--#region Ability stats

local function GetAbilityStats(me, deadShot)
    local castRange = DEFAULT_CAST_RANGE
    local castPoint = DEFAULT_CAST_POINT
    local projectileSpeed = DEFAULT_PROJECTILE_SPEED
    local ricochetMultiplier = DEFAULT_RICOCHET_MULTIPLIER
    local ricochetRadius = DEFAULT_RICOCHET_RADIUS

    if deadShot then
        local range = SafeCall(Ability.GetCastRange, deadShot)
        if range and range > 0 then
            castRange = range
        end
        local point = SafeCall(Ability.GetCastPoint, deadShot, true)
        if not point or point <= 0 then
            point = SafeCall(Ability.GetLevelSpecialValueFor, deadShot, "AbilityCastPoint")
        end
        if point and point > 0 then
            castPoint = point
        end
        local speed = SafeCall(Ability.GetLevelSpecialValueFor, deadShot, "speed")
        if speed and speed > 0 then
            projectileSpeed = speed
        end
        local mult = SafeCall(Ability.GetLevelSpecialValueFor, deadShot, "ricochet_distance_multiplier")
        if mult and mult > 0 then
            ricochetMultiplier = mult
        end
        local radius = SafeCall(Ability.GetLevelSpecialValueFor, deadShot, "ricochet_radius_start")
        if radius and radius > 0 then
            ricochetRadius = radius
        end
        local radiusEnd = SafeCall(Ability.GetLevelSpecialValueFor, deadShot, "ricochet_radius_end")
        if radiusEnd and radiusEnd > ricochetRadius then
            ricochetRadius = radiusEnd
        end
    end

    castRange = castRange + (SafeCall(NPC.GetCastRangeBonus, me) or 0)

    return {
        castRange = castRange,
        castPoint = castPoint,
        projectileSpeed = projectileSpeed,
        ricochetMultiplier = ricochetMultiplier,
        ricochetRadius = ricochetRadius,
        hitRadius = ricochetRadius + ENEMY_HULL_RADIUS,
    }
end

local function IsDeadShotReady(deadShot, mana)
    if not deadShot then
        return false
    end
    if SafeCall(Ability.GetLevel, deadShot) <= 0 then
        return false
    end
    if SafeCall(Ability.IsInAbilityPhase, deadShot) then
        return false
    end
    if mana and SafeCall(Ability.IsOwnersManaEnough, deadShot) == false then
        return false
    end

    local charges = SafeCall(Ability.GetCurrentCharges, deadShot)
    if charges ~= nil and charges > 0 then
        return true
    end

    if SafeCall(Ability.IsReady, deadShot) == false then
        return false
    end

    local cooldown = SafeCall(Ability.GetCooldown, deadShot) or 0
    return cooldown <= 0.05
end

local function GetRicochetDistanceFromHero(me, anchorPos, stats)
    local myPos = me and SafeCall(Entity.GetAbsOrigin, me)
    if not myPos or not anchorPos or not stats then
        return nil
    end
    return Dist2D(myPos, anchorPos) * stats.ricochetMultiplier
end

local function SolveImpactPrediction(me, enemy, anchorPos, stats, extraTravelTime)
    local myPos = me and SafeCall(Entity.GetAbsOrigin, me)
    local enemyPos = enemy and SafeCall(Entity.GetAbsOrigin, enemy)
    if not myPos or not enemyPos or not anchorPos or not stats then
        return enemyPos, 0, 0, 0
    end

    UpdateUnitMotionCache({ enemy })

    local extraTime = extraTravelTime or 0
    local predictedPos = enemyPos
    local travelTime = 0

    for _ = 1, PREDICT_MAX_ITERATIONS do
        travelTime = ComputeProjectileTravelTime(myPos, anchorPos, predictedPos, stats) + extraTime
        local nextPos = GetPredictedEnemyPos(enemy, travelTime) or predictedPos
        if Dist2D(nextPos, predictedPos) <= PREDICT_POS_EPSILON then
            predictedPos = nextPos
            break
        end
        predictedPos = nextPos
    end

    local dirX, dirY = Normalize2D(predictedPos.x - anchorPos.x, predictedPos.y - anchorPos.y)
    return predictedPos, travelTime, dirX, dirY
end

local function BuildRicochetVectorPos(anchorPos, predictedPos, dirX, dirY)
    if not anchorPos or not predictedPos then
        return nil
    end

    if dirX == 0 and dirY == 0 then
        dirX, dirY = Normalize2D(predictedPos.x - anchorPos.x, predictedPos.y - anchorPos.y)
    end
    if dirX == 0 and dirY == 0 then
        return MakeGroundPosition(predictedPos)
    end

    local along = GetRayDistanceAlong(anchorPos, dirX, dirY, predictedPos) or 0
    if along < VECTOR_MIN_RAY_DISTANCE then
        return AlongRayFromAnchor(anchorPos, dirX, dirY, VECTOR_HINT_DISTANCE)
    end

    return MakeGroundPosition(predictedPos)
end

local function ComputeRicochetAimGeometry(plan, me, stats, extraTravelTime)
    local anchorPos = plan.castTargetPos
    local enemy = plan.enemy
    local myPos = me and SafeCall(Entity.GetAbsOrigin, me)
    if not anchorPos or not enemy or not stats or not myPos then
        return {
            predictedPos = plan.predictedPos,
            vectorPos = plan.vectorPos,
            ricochetEnd = plan.ricochetEnd,
        }
    end

    local predictedPos, _, dirX, dirY = SolveImpactPrediction(
        me,
        enemy,
        anchorPos,
        stats,
        extraTravelTime
    )
    if not predictedPos then
        return {
            predictedPos = plan.predictedPos,
            vectorPos = plan.vectorPos,
            ricochetEnd = plan.ricochetEnd,
        }
    end

    if dirX == 0 and dirY == 0 then
        return {
            predictedPos = plan.predictedPos,
            vectorPos = plan.vectorPos,
            ricochetEnd = plan.ricochetEnd,
        }
    end

    local ricochetDist = GetRicochetDistanceFromHero(me, anchorPos, stats) or VECTOR_HINT_DISTANCE * 2
    local vectorPos = BuildRicochetVectorPos(anchorPos, predictedPos, dirX, dirY)

    return {
        predictedPos = MakeGroundPosition(predictedPos),
        vectorPos = vectorPos,
        ricochetEnd = AlongRayFromAnchor(anchorPos, dirX, dirY, ricochetDist),
    }
end

local function CloneCastPlan(plan)
    if not plan then
        return nil
    end

    return {
        enemy = plan.enemy,
        castTarget = plan.castTarget,
        castTargetPos = plan.castTargetPos and MakeGroundPosition(plan.castTargetPos),
        vectorPos = plan.vectorPos and MakeGroundPosition(plan.vectorPos),
        ricochetEnd = plan.ricochetEnd and MakeGroundPosition(plan.ricochetEnd),
        predictedPos = plan.predictedPos and MakeGroundPosition(plan.predictedPos),
        mode = plan.mode,
        anchorMode = plan.anchorMode,
        directionTag = plan.directionTag,
        score = plan.score,
        hitCertainty = plan.hitCertainty,
    }
end

local function BuildCastPlan(plan, me, stats)
    local castPlan = CloneCastPlan(plan)
    if not castPlan then
        return nil
    end

    if castPlan.castTarget then
        local livePos = SafeCall(Entity.GetAbsOrigin, castPlan.castTarget)
        if livePos then
            castPlan.castTargetPos = MakeGroundPosition(livePos)
        end
    end

    local geom = ComputeRicochetAimGeometry(castPlan, me, stats, 0)
    castPlan.vectorPos = geom.vectorPos
    castPlan.predictedPos = geom.predictedPos
    castPlan.ricochetEnd = geom.ricochetEnd
    return castPlan
end

--#endregion

--#region Targeting

local function GetEnemyHeroes(me, radius)
    local enemies = State.enemyBuffer
    local count = 0

    if Heroes and Heroes.InRadius then
        local list = SafeCall(Heroes.InRadius, Entity.GetAbsOrigin(me), radius, Enum.TeamType.TEAM_ENEMY)
        if list then
            for i = 1, #list do
                local enemy = list[i]
                if CanCastOnEnemy(enemy, me) then
                    count = count + 1
                    enemies[count] = enemy
                end
            end
        end
    end

    for i = count + 1, #enemies do
        enemies[i] = nil
    end

    if count > 0 then
        UpdateUnitMotionCache(enemies)
    end

    return enemies, count
end

local function GetCursorEnemy(me)
    if not Input or not Input.GetNearestHeroToCursor then
        return nil
    end
    local enemy = SafeCall(
        Input.GetNearestHeroToCursor,
        SafeCall(Entity.GetTeamNum, me),
        Enum.TeamType.TEAM_ENEMY
    )
    if enemy and CanCastOnEnemy(enemy, me) then
        return enemy
    end
    return nil
end

local function ScoreEnemyPriority(enemy, me, cursorEnemy)
    local pos = SafeCall(Entity.GetAbsOrigin, enemy)
    local myPos = SafeCall(Entity.GetAbsOrigin, me)
    if not pos or not myPos then
        return -math.huge
    end

    local hp = SafeCall(Entity.GetHealth, enemy) or 0
    local maxHp = SafeCall(Entity.GetMaxHealth, enemy) or 1
    local hpPct = hp / math.max(1, maxHp)
    local dist = Dist2D(myPos, pos)
    local score = (1 - hpPct) * 5000 - dist * 0.5

    if cursorEnemy and enemy == cursorEnemy then
        score = score + 15000
    end
    return score
end

local function PickBestEnemy(me, enemies, count, cursorEnemy, preferred)
    if preferred and CanCastOnEnemy(preferred, me) then
        return preferred
    end

    local best = nil
    local bestScore = -math.huge
    for i = 1, count do
        local enemy = enemies[i]
        local score = ScoreEnemyPriority(enemy, me, cursorEnemy)
        if score > bestScore then
            bestScore = score
            best = enemy
        end
    end
    return best
end

local function ResolveCombatTarget(me, enemies, count, bindHeld)
    local cursorEnemy = GetCursorEnemy(me)

    if bindHeld and State.activeBindMode == "aim" then
        if State.lockedAimTarget and not CanCastOnEnemy(State.lockedAimTarget, me) then
            State.lockedAimTarget = nil
            State.combatTarget = nil
        end
        if not State.lockedAimTarget then
            local fallback = State.combatTarget
            if fallback and not CanCastOnEnemy(fallback, me) then
                fallback = nil
            end
            State.lockedAimTarget = cursorEnemy or fallback
        end
        local locked = State.lockedAimTarget
        if locked and CanCastOnEnemy(locked, me) then
            State.combatTarget = locked
            return locked
        end
        State.combatTarget = nil
        return nil
    end

    if bindHeld then
        if not State.lockedComboTarget or not CanCastOnEnemy(State.lockedComboTarget, me) then
            State.lockedComboTarget = PickBestEnemy(me, enemies, count, cursorEnemy, cursorEnemy)
        end
        State.combatTarget = State.lockedComboTarget
        return State.lockedComboTarget
    end

    local target = cursorEnemy
    if target and CanCastOnEnemy(target, me) then
        State.combatTarget = target
        return target
    end

    target = State.combatTarget
    if target and CanCastOnEnemy(target, me) then
        return target
    end

    target = PickBestEnemy(me, enemies, count, cursorEnemy, State.combatTarget)
    State.combatTarget = target
    return target
end

--#endregion

--#region Anchor scan

local function IsValidCreepAnchor(unit, me, finalTarget)
    if not unit or unit == finalTarget then
        return false
    end
    if not SafeCall(Entity.IsAlive, unit) then
        return false
    end
    if SafeCall(Entity.IsDormant, unit) then
        return false
    end
    if IsFriendlyUnit(unit, me) then
        return false
    end
    if SafeCall(Entity.IsHero, unit) then
        return false
    end
    if SafeCall(NPC.IsIllusion, unit) then
        return false
    end
    if SafeCall(NPC.IsWaitingToSpawn, unit) then
        return false
    end
    return true
end

local function CollectRicochetAnchors(me, finalTarget, enemyPos, stats, out, seen, maxCount)
    local count = 0
    local myPos = SafeCall(Entity.GetAbsOrigin, me)
    if not myPos then
        return 0
    end

    local teamNum = SafeCall(Entity.GetTeamNum, me)

    local function tryAddAnchor(entity, mode)
        if count >= maxCount or not entity or entity == finalTarget then
            return
        end
        if mode ~= "tree" and IsFriendlyUnit(entity, me) then
            return
        end

        local idx = SafeCall(Entity.GetIndex, entity)
        if not idx or seen[idx] then
            return
        end

        local anchorPos = SafeCall(Entity.GetAbsOrigin, entity)
        if not anchorPos then
            return
        end
        if Dist2D(myPos, anchorPos) > stats.castRange then
            return
        end

        seen[idx] = true
        count = count + 1
        out[count] = {
            entity = entity,
            mode = mode,
            pos = anchorPos,
        }
    end

    if Trees and Trees.InRadius then
        local treesNearMe = SafeCall(Trees.InRadius, myPos, stats.castRange, true)
        if treesNearMe then
            for i = 1, #treesNearMe do
                tryAddAnchor(treesNearMe[i], "tree")
            end
        end
    end

    if enemyPos and Trees and Trees.InRadius then
        local treesNearEnemy = SafeCall(Trees.InRadius, enemyPos, TREE_SEARCH_RADIUS, true)
        if treesNearEnemy then
            for i = 1, #treesNearEnemy do
                tryAddAnchor(treesNearEnemy[i], "tree")
            end
        end
    end

    if TempTrees and TempTrees.InRadius then
        local tempNearMe = SafeCall(TempTrees.InRadius, myPos, stats.castRange)
        if tempNearMe then
            for i = 1, #tempNearMe do
                tryAddAnchor(tempNearMe[i], "tree")
            end
        end
        if enemyPos then
            local tempNearEnemy = SafeCall(TempTrees.InRadius, enemyPos, TREE_SEARCH_RADIUS)
            if tempNearEnemy then
                for i = 1, #tempNearEnemy do
                    tryAddAnchor(tempNearEnemy[i], "tree")
                end
            end
        end
    end

    if NPCs and NPCs.InRadius and teamNum then
        local creeps = SafeCall(
            NPCs.InRadius,
            myPos,
            stats.castRange,
            teamNum,
            Enum.TeamType.TEAM_ENEMY,
            true,
            true
        )
        if creeps then
            for i = 1, #creeps do
                local creep = creeps[i]
                if IsValidCreepAnchor(creep, me, finalTarget) then
                    tryAddAnchor(creep, "creep")
                end
            end
        end
    end

    if Heroes and Heroes.InRadius and teamNum then
        local heroes = SafeCall(Heroes.InRadius, myPos, stats.castRange, Enum.TeamType.TEAM_ENEMY)
        if heroes then
            for i = 1, #heroes do
                local hero = heroes[i]
                if hero ~= finalTarget and CanCastOnEnemy(hero, me) then
                    tryAddAnchor(hero, "hero")
                end
            end
        end
    end

    for i = count + 1, #out do
        out[i] = nil
    end

    return count
end

--#endregion

--#region Dead Shot solver

local function EstimateTravelMs(myPos, anchorPos, stats)
    local distToAnchor = Dist2D(myPos, anchorPos)
    local toAnchorMs = (distToAnchor / stats.projectileSpeed) * 1000
    local ricochetDist = distToAnchor * stats.ricochetMultiplier
    local ricochetMs = (ricochetDist / stats.projectileSpeed) * 1000
    return stats.castPoint * 1000 + toAnchorMs + ricochetMs
end

local function ComputeCloserGain(myPos, enemyPos, ricochetDirX, ricochetDirY)
    local before = Dist2D(myPos, enemyPos)
    local afterPos = MoveTowards2D(enemyPos, ricochetDirX, ricochetDirY, FEAR_PUSH_DISTANCE)
    local after = Dist2D(myPos, afterPos)
    return before - after
end

local function BuildAnchorPlanFromDirection(
    enemy,
    anchor,
    anchorPos,
    myPos,
    predictedPos,
    dirX,
    dirY,
    stats,
    comboBonus,
    directionTag
)
    if dirX == 0 and dirY == 0 then
        return nil
    end

    local distToAnchor = Dist2D(myPos, anchorPos)
    local ricochetDist = distToAnchor * stats.ricochetMultiplier
    if Dist2D(anchorPos, predictedPos) > ricochetDist + stats.hitRadius then
        return nil
    end

    local ricochetEnd = MoveTowards2D(anchorPos, dirX, dirY, ricochetDist)
    local missDist = DistPointToSegment2D(
        predictedPos.x,
        predictedPos.y,
        anchorPos.x,
        anchorPos.y,
        ricochetEnd.x,
        ricochetEnd.y
    )

    local hitRadius = stats.hitRadius

    if missDist > hitRadius then
        return nil
    end

    local hitCertainty = math.max(0, 1 - (missDist / math.max(1, hitRadius)))
    local closerGain = ComputeCloserGain(myPos, predictedPos, dirX, dirY)

    local travelMs = EstimateTravelMs(myPos, anchorPos, stats)
    local modeBonus = anchor.mode == "creep" and 3200
        or (anchor.mode == "hero" and 2400
        or (anchor.mode == "tree" and 250 or 100))
    local directionBonus = 0
    if directionTag == "muerta" then
        directionBonus = State.activeBindMode == "aim" and 1200 or 300
    elseif directionTag == "enemy" then
        directionBonus = State.activeBindMode == "combo" and 1800 or 600
    end
    local score = hitCertainty * 100000
        + closerGain * 500
        + RICOCHET_PATH_BONUS
        + modeBonus
        + directionBonus
        + comboBonus
        - travelMs * 10

    local hintDist = VECTOR_HINT_DISTANCE
    local vectorPos = BuildRicochetVectorPos(anchorPos, predictedPos, dirX, dirY)
        or MoveTowards2D(anchorPos, dirX, dirY, hintDist)

    return {
        enemy = enemy,
        castTarget = anchor.entity,
        castTargetPos = MakeGroundPosition(anchorPos),
        vectorPos = MakeGroundPosition(vectorPos),
        ricochetEnd = MakeGroundPosition(ricochetEnd),
        predictedPos = MakeGroundPosition(predictedPos),
        mode = anchor.mode,
        anchorMode = anchor.mode,
        score = score,
        hitCertainty = hitCertainty,
        directionTag = directionTag,
    }
end

local function EvaluateAnchorRicochetPlan(
    me,
    enemy,
    anchor,
    myPos,
    enemyPos,
    stats,
    comboBonus
)
    local anchorPos = anchor.pos or SafeCall(Entity.GetAbsOrigin, anchor.entity)
    if not anchorPos then
        return nil
    end
    if Dist2D(myPos, anchorPos) > stats.castRange then
        return nil
    end

    local predictedPos = select(1, SolveImpactPrediction(me, enemy, anchorPos, stats, 0)) or enemyPos

    local enemyDirX, enemyDirY = Normalize2D(predictedPos.x - anchorPos.x, predictedPos.y - anchorPos.y)
    if enemyDirX == 0 and enemyDirY == 0 then
        return nil
    end

    if State.activeBindMode ~= "aim" then
        return BuildAnchorPlanFromDirection(
            enemy,
            anchor,
            anchorPos,
            myPos,
            predictedPos,
            enemyDirX,
            enemyDirY,
            stats,
            comboBonus,
            "enemy"
        )
    end

    local best = nil

    local muertaDirX, muertaDirY = Normalize2D(myPos.x - anchorPos.x, myPos.y - anchorPos.y)
    local towardMuerta = BuildAnchorPlanFromDirection(
        enemy,
        anchor,
        anchorPos,
        myPos,
        predictedPos,
        muertaDirX,
        muertaDirY,
        stats,
        comboBonus,
        "muerta"
    )
    if towardMuerta and (not best or towardMuerta.score > best.score) then
        best = towardMuerta
    end

    local towardEnemy = BuildAnchorPlanFromDirection(
        enemy,
        anchor,
        anchorPos,
        myPos,
        predictedPos,
        enemyDirX,
        enemyDirY,
        stats,
        comboBonus,
        "enemy"
    )
    if towardEnemy and (not best or towardEnemy.score > best.score) then
        best = towardEnemy
    end

    return best
end

local function EvaluateDeadShotPlans(me, enemy, stats, anchors, anchorCount, comboBonus)
    local myPos = SafeCall(Entity.GetAbsOrigin, me)
    local enemyPos = SafeCall(Entity.GetAbsOrigin, enemy)
    if not myPos or not enemyPos then
        return nil
    end

    local bestAnchor = nil
    for i = 1, anchorCount do
        local plan = EvaluateAnchorRicochetPlan(
            me,
            enemy,
            anchors[i],
            myPos,
            enemyPos,
            stats,
            comboBonus
        )
        if plan and (not bestAnchor or plan.score > bestAnchor.score) then
            bestAnchor = plan
        end
    end

    return bestAnchor
end

local function GetPlanAnchorKey(plan)
    if not plan then
        return nil
    end

    local idx = plan.castTarget and SafeCall(Entity.GetIndex, plan.castTarget)
    if idx then
        return string.format(
            "%s:%d:%s",
            tostring(plan.mode),
            idx,
            tostring(plan.directionTag or "")
        )
    end

    local anchorPos = plan.castTargetPos
    if anchorPos then
        return string.format(
            "%s:%.0f:%.0f",
            tostring(plan.mode),
            anchorPos.x or 0,
            anchorPos.y or 0
        )
    end

    return nil
end

local function IsPlanStillValid(plan, me, target, stats)
    if not plan or not me or not target or not stats then
        return false
    end
    if plan.enemy ~= target or not CanCastOnEnemy(target, me) then
        return false
    end

    local castTarget = plan.castTarget
    if castTarget then
        local isTreeAnchor = plan.anchorMode == "tree" or plan.mode == "tree"
        if isTreeAnchor then
            if not Tree or not Tree.IsActive or SafeCall(Tree.IsActive, castTarget) ~= true then
                return false
            end
        else
            if not SafeCall(Entity.IsAlive, castTarget) then
                return false
            end
            if SafeCall(Entity.IsDormant, castTarget) then
                return false
            end
            if IsFriendlyUnit(castTarget, me) then
                return false
            end
        end
    end

    local myPos = SafeCall(Entity.GetAbsOrigin, me)
    local anchorPos = castTarget and SafeCall(Entity.GetAbsOrigin, castTarget)
        or plan.castTargetPos
    if myPos and anchorPos and Dist2D(myPos, anchorPos) > stats.castRange + 30 then
        return false
    end

    return true
end

local function StabilizePlanChoice(candidate, me, target, stats, now)
    if not candidate then
        return nil
    end

    local current = State.bestPlan
    if not current or not IsPlanStillValid(current, me, target, stats) then
        State.planLockedAt = now
        return candidate
    end

    if GetPlanAnchorKey(current) == GetPlanAnchorKey(candidate) then
        if (candidate.score or 0) > (current.score or 0) then
            return candidate
        end
        return current
    end

    local heldFor = now - (State.planLockedAt or 0)
    local margin = PLAN_SWITCH_SCORE_MARGIN
    if heldFor < PLAN_SWITCH_MIN_HOLD then
        margin = margin + 3500
    end

    if (candidate.score or 0) <= (current.score or 0) + margin then
        return current
    end

    State.planLockedAt = now
    return candidate
end

local function FindBestDeadShotPlan(me, deadShot, target, now)
    if not target then
        return nil
    end

    local stats = GetAbilityStats(me, deadShot)
    local comboBonus = State.activeBindMode == "aim" and 3000 or 0

    UpdateUnitMotionCache({ target })

    local anchors = State.anchorBuffer
    local seen = State.anchorSeen
    local anchorCount = State.cachedAnchorCount or 0
    local enemyPos = SafeCall(Entity.GetAbsOrigin, target)
    local lastPos = State.lastAnchorEnemyPos
    local enemyMoved = not lastPos
        or not enemyPos
        or Dist2D(lastPos, enemyPos) >= ANCHOR_ENEMY_MOVE_THRESHOLD
    local scanDue = now - State.lastAnchorScanAt >= ANCHOR_SCAN_INTERVAL

    if anchorCount <= 0 or (scanDue and enemyMoved) then
        State.lastAnchorScanAt = now
        for k in pairs(seen) do
            seen[k] = nil
        end
        anchorCount = CollectRicochetAnchors(me, target, enemyPos, stats, anchors, seen, MAX_ANCHORS)
        State.cachedAnchorCount = anchorCount
        if enemyPos then
            State.lastAnchorEnemyPos = MakeGroundPosition(enemyPos)
        end
    elseif scanDue then
        State.lastAnchorScanAt = now
    end

    local plan = EvaluateDeadShotPlans(me, target, stats, anchors, anchorCount, comboBonus)
    if plan then
        State.lastAnchorDebug = string.format(
            "anchors=%d mode=%s dir=%s certainty=%.2f",
            anchorCount,
            tostring(plan.mode),
            tostring(plan.directionTag or "?"),
            plan.hitCertainty or 0
        )
    else
        State.lastAnchorDebug = string.format("anchors=%d plan=none", anchorCount)
    end

    return plan
end

--#endregion

--#region Vector cast

local function GetAbilityNameSafe(ability)
    if not ability then
        return nil
    end
    return SafeCall(Ability.GetName, ability)
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

local function TryCallMethod(obj, methodName, ...)
    if not obj or not methodName then
        return false, "missing_obj_or_method"
    end

    local okIndex, member = pcall(function()
        return obj[methodName]
    end)
    if not okIndex or type(member) ~= "function" then
        return false, "method_missing"
    end

    local args = { ... }
    local okCall, result = pcall(function()
        return member(obj, table.unpack(args))
    end)
    if okCall then
        return true, result
    end
    return false, tostring(result)
end

local function BuildPreparedOrder(order, target, position, ability, issuer, hero, identifier, queue, executeFast, callback)
    return {
        order = order,
        target = target,
        position = position,
        ability = ability,
        issuer = issuer,
        npc = hero,
        queue = queue == true,
        showEffects = false,
        callback = callback == true,
        executeFast = executeFast == true,
        identifier = identifier,
    }
end

local function GetPlayerActiveAbility(player)
    if not player then
        return nil
    end
    if Player and Player.GetActiveAbility then
        return SafeCall(Player.GetActiveAbility, player)
    end
    return nil
end

local function GetPlayerForHero(hero)
    if Players and Players.GetLocal then
        local player = Players.GetLocal()
        if player then
            return player
        end
    end
    if Hero and Hero.GetPlayer then
        local player = SafeCall(Hero.GetPlayer, hero)
        if player then
            return player
        end
    end
    if NPC and NPC.GetPlayerOwner then
        local player = SafeCall(NPC.GetPlayerOwner, hero)
        if player then
            return player
        end
    end
    return nil
end

local function GetOrderIssuerCandidates()
    local issuers = {}
    local seen = {}

    local function add(candidates)
        local value = ResolveOrderIssuer(candidates)
        if value ~= nil and not seen[value] then
            seen[value] = true
            issuers[#issuers + 1] = value
        end
    end

    add(ORDER_ISSUER_PASSED_UNIT_ONLY_NAMES)
    add(ORDER_ISSUER_HERO_ONLY_NAMES)
    add(ORDER_ISSUER_SCRIPT_NAMES)
    return issuers
end

local function TryPrepareUnitOrdersRaw(
    player,
    order,
    target,
    position,
    ability,
    issuer,
    hero,
    identifier,
    queue,
    callback,
    executeFast,
    forceMinimap
)
    if not Player or not Player.PrepareUnitOrders or order == nil or issuer == nil then
        return false
    end

    local pos = position or Vector(0, 0, 0)
    local ok = pcall(
        Player.PrepareUnitOrders,
        player,
        order,
        target,
        pos,
        ability,
        issuer,
        hero,
        queue == true,
        false,
        callback == true,
        executeFast == true,
        identifier,
        forceMinimap ~= false
    )
    return ok
end

local function TryPrepareUnitOrdersStaticTable(
    player,
    order,
    target,
    position,
    ability,
    issuer,
    hero,
    identifier,
    queue,
    callback,
    executeFast
)
    if not Player or not Player.PrepareUnitOrders then
        return false
    end

    local ok = pcall(
        Player.PrepareUnitOrders,
        player,
        BuildPreparedOrder(order, target, position, ability, issuer, hero, identifier, queue, executeFast, callback)
    )
    return ok
end

local function TryPrepareUnitOrdersMethodTable(
    player,
    order,
    target,
    position,
    ability,
    issuer,
    hero,
    identifier,
    queue,
    callback,
    executeFast
)
    local ok = TryCallMethod(
        player,
        "PrepareUnitOrders",
        BuildPreparedOrder(order, target, position, ability, issuer, hero, identifier, queue, executeFast, callback)
    )
    return ok
end

local function TryIssuePrepareOrderAny(
    player,
    order,
    target,
    position,
    ability,
    hero,
    identifier,
    queue,
    executeFast
)
    local issuers = GetOrderIssuerCandidates()
    local combos = {
        { callback = true, executeFast = true, forceMinimap = false, tag = "live" },
        { callback = true, executeFast = executeFast == true, forceMinimap = false, tag = "push" },
        { callback = false, executeFast = true, forceMinimap = false, tag = "fast" },
        { callback = false, executeFast = false, forceMinimap = false, tag = "plain" },
    }

    for issuerIndex = 1, #issuers do
        local issuer = issuers[issuerIndex]
        for comboIndex = 1, #combos do
            local combo = combos[comboIndex]
            if TryPrepareUnitOrdersRaw(
                player,
                order,
                target,
                position,
                ability,
                issuer,
                hero,
                identifier,
                queue,
                combo.callback,
                combo.executeFast,
                combo.forceMinimap
            ) then
                State.preferredIssuer = issuer
                return true, combo.tag
            end

            if TryPrepareUnitOrdersStaticTable(
                player,
                order,
                target,
                position,
                ability,
                issuer,
                hero,
                identifier,
                queue,
                combo.callback,
                combo.executeFast
            ) then
                State.preferredIssuer = issuer
                return true, combo.tag .. "_table"
            end

            if TryPrepareUnitOrdersMethodTable(
                player,
                order,
                target,
                position,
                ability,
                issuer,
                hero,
                identifier,
                queue,
                combo.callback,
                combo.executeFast
            ) then
                State.preferredIssuer = issuer
                return true, combo.tag .. "_method"
            end
        end
    end

    return false, "prepare_failed"
end

local function TryPrepareUnitOrders(player, order, target, position, ability, issuer, hero, identifier, queue, executeFast)
    return TryPrepareUnitOrdersRaw(
        player,
        order,
        target,
        position,
        ability,
        issuer,
        hero,
        identifier,
        queue,
        true,
        executeFast,
        false
    )
end

local function GetPreferredOrderIssuer()
    if State.preferredIssuer ~= nil then
        return State.preferredIssuer
    end

    local issuers = GetOrderIssuerCandidates()
    State.preferredIssuer = issuers[1]
    return State.preferredIssuer
end

local function TryIssueVectorFollowupOrder(player, order, target, vectorPos, ability, hero, identifier)
    local targetTag = target and "target" or "nil"
    local preferred = GetPreferredOrderIssuer()
    if preferred and TryPrepareUnitOrders(
        player,
        order,
        target,
        vectorPos,
        ability,
        preferred,
        hero,
        identifier .. "_" .. targetTag,
        false,
        true
    ) then
        return true, targetTag .. "_live"
    end

    local issuers = GetOrderIssuerCandidates()
    for i = 1, #issuers do
        local issuer = issuers[i]
        if issuer ~= preferred and TryPrepareUnitOrders(
            player,
            order,
            target,
            vectorPos,
            ability,
            issuer,
            hero,
            identifier .. "_" .. targetTag .. "_alt",
            false,
            true
        ) then
            State.preferredIssuer = issuer
            return true, targetTag .. "_live_alt"
        end
    end

    if Ability and Ability.CastPosition then
        local ok = pcall(
            Ability.CastPosition,
            ability,
            vectorPos,
            false,
            true,
            true,
            identifier .. "_pos",
            false
        )
        if ok then
            return true, "cast_position"
        end
    end

    return false, "followup_failed"
end

local function CaptureCastSnapshot(deadShot, player, hero)
    return {
        charges = SafeCall(Ability.GetCurrentCharges, deadShot),
        cooldown = SafeCall(Ability.GetCooldown, deadShot) or 0,
        inPhase = SafeCall(Ability.IsInAbilityPhase, deadShot) == true,
        activeAbility = GetPlayerActiveAbility(player),
        mana = hero and SafeCall(NPC.GetMana, hero),
        hero = hero,
    }
end

local function WasVectorFollowupAccepted(deadShot, before)
    local charges = SafeCall(Ability.GetCurrentCharges, deadShot)
    if before.charges ~= nil and charges ~= nil and charges < before.charges then
        return true, "charges"
    end

    local cooldown = SafeCall(Ability.GetCooldown, deadShot) or 0
    if cooldown > before.cooldown + 0.05 then
        return true, "cooldown"
    end

    if before.inPhase and SafeCall(Ability.IsInAbilityPhase, deadShot) ~= true then
        local manaBefore = before.mana
        local manaNow = before.hero and SafeCall(NPC.GetMana, before.hero)
        if manaBefore ~= nil and manaNow ~= nil and manaNow < manaBefore - 1 then
            return true, "mana_spent"
        end
    end

    return false, "not_accepted"
end

local function UsesPositionCast(plan)
    return plan and (plan.anchorMode == "tree" or plan.mode == "tree")
end

local function GetVectorFollowupFirstDelay(plan)
    -- Start polling shortly after stage 1 and fire only after vector phase begins.
    local delay = VECTOR_FOLLOWUP_FIRST_DELAY
    if plan and UsesPositionCast(plan) then
        delay = delay + VECTOR_FOLLOWUP_TREE_EXTRA
    end
    return delay
end

local function GetCastRepeatDelay(deadShot)
    local charges = SafeCall(Ability.GetCurrentCharges, deadShot)
    if charges ~= nil and charges > 0 then
        return CAST_REPEAT_DELAY_CHARGED
    end

    local cooldown = SafeCall(Ability.GetCooldown, deadShot) or 0
    if cooldown <= 0.05 and SafeCall(Ability.IsReady, deadShot) ~= false then
        return CAST_REPEAT_DELAY_READY
    end

    return CAST_REPEAT_DELAY
end

local function ResolveFollowupVectorPos(pending, hero, stats)
    local anchor = pending.castTarget
    local anchorPos = anchor and SafeCall(Entity.GetAbsOrigin, anchor) or pending.castTargetPos
    local enemy = pending.enemy
    if not anchorPos or not enemy or not stats or not hero then
        return pending.vectorPos
    end

    local geom = ComputeRicochetAimGeometry({
        castTargetPos = MakeGroundPosition(anchorPos),
        enemy = enemy,
    }, hero, stats, 0)

    local liveVectorPos = geom.vectorPos
    local queuedVectorPos = pending.vectorPos
    if liveVectorPos and queuedVectorPos then
        local delta = Dist2D(liveVectorPos, queuedVectorPos)
        if delta > FOLLOWUP_MAX_LIVE_VECTOR_DELTA then
            LogCastDebugOnce(pending, "vector_jitter", "FOLLOWUP", string.format(
                "kept queued vector | live delta=%.0f limit=%.0f queued=(%s) rejectedLive=(%s)",
                delta,
                FOLLOWUP_MAX_LIVE_VECTOR_DELTA,
                FmtPos(queuedVectorPos),
                FmtPos(liveVectorPos)
            ))
            return queuedVectorPos
        end
    end

    return liveVectorPos or queuedVectorPos
end

local function QueueVectorFollowup(player, hero, ability, plan, ctx, stage1Reason)
    local now = SafeCall(GameRules.GetGameTime) or 0
    local stats = State.abilityStats or GetAbilityStats(hero, ability)
    local firstDelay = GetVectorFollowupFirstDelay(plan)
    State.pendingVectorStep = {
        player = player,
        hero = hero,
        ability = ability,
        enemy = plan.enemy,
        castTarget = plan.castTarget,
        castTargetPos = plan.castTargetPos and MakeGroundPosition(plan.castTargetPos),
        mode = plan.mode,
        anchorMode = plan.anchorMode,
        isTree = UsesPositionCast(plan),
        vectorPos = plan.vectorPos and MakeGroundPosition(plan.vectorPos),
        ctx = ctx,
        castSnapshot = CaptureCastSnapshot(ability, player, hero),
        dueTime = now + firstDelay,
        expireTime = now + VECTOR_FOLLOWUP_EXPIRE,
        attempts = 0,
        followupIssued = false,
        phaseSeen = false,
        issuedMethod = nil,
        stage1Reason = stage1Reason,
        debugOnce = {},
    }
    LogCastDebug("QUEUE", string.format(
        "stage1=%s tree=%s delay=%.2f due=%.2f exp=%.2f snap=%s | %s",
        tostring(stage1Reason or "?"),
        tostring(State.pendingVectorStep.isTree),
        firstDelay,
        State.pendingVectorStep.dueTime,
        State.pendingVectorStep.expireTime,
        FmtSnapshot(State.pendingVectorStep.castSnapshot),
        DescribeCastPlan(plan, hero, stats)
    ))
end

local function ClearVectorFollowup()
    State.pendingVectorStep = nil
end

local function UnlockCastPlanForRepeat()
    State.bestPlan = nil
    State.precomputedCast = nil
    State.lockedCastPlan = nil
    State.planLockedAt = -100
    State.lastLoggedPlanKey = nil
end

local function IssueStage1ForPlan(player, hero, deadShot, plan, ctx)
    if not player or not ctx then
        return false, "stage1_no_ctx"
    end

    local castTarget = plan.castTarget
    local anchorPos = plan.castTargetPos or SafeCall(Entity.GetAbsOrigin, castTarget)
    if not anchorPos then
        return false, "stage1_no_pos"
    end
    if castTarget and not UsesPositionCast(plan) and IsFriendlyUnit(castTarget, hero) then
        LogCastDebug("STAGE1", string.format(
            "blocked friendly target=%s mode=%s",
            FmtEntityRef(castTarget),
            tostring(plan.mode)
        ))
        return false, "friendly_anchor_blocked"
    end

    -- Ability.CastTarget may complete Dead Shot with its default forward
    -- direction before a vector order is attached. For hero anchors, enter
    -- vector targeting explicitly through the raw CAST_TARGET order.
    if (plan.anchorMode == "hero" or plan.mode == "hero")
        and ctx.castTarget
        and castTarget
    then
        local orderOk, orderMethod = TryIssuePrepareOrderAny(
            player,
            ctx.castTarget,
            castTarget,
            Vector(0, 0, 0),
            deadShot,
            hero,
            ORDER_ID .. ".stage1_hero_cast_target",
            false,
            true
        )
        if orderOk then
            local stage1Reason = "hero_cast_target_" .. tostring(orderMethod)
            QueueVectorFollowup(player, hero, deadShot, plan, ctx, stage1Reason)
            LogCastDebug("STAGE1", string.format(
                "ok tag=%s order=%s target=%s",
                stage1Reason,
                tostring(ctx.castTarget),
                FmtEntityRef(castTarget)
            ))
            return true, stage1Reason
        end
    end

    local attempts = {}
    if castTarget and not UsesPositionCast(plan) and Ability and Ability.CastTarget then
        local ok = pcall(
            Ability.CastTarget,
            deadShot,
            castTarget,
            false,
            true,
            true,
            ORDER_ID .. ".ability_cast_target"
        )
        if ok then
            QueueVectorFollowup(player, hero, deadShot, plan, ctx, "ability_cast_target")
            LogCastDebug("STAGE1", string.format(
                "ok tag=ability_cast_target target=%s",
                FmtEntityRef(castTarget)
            ))
            return true, "ability_cast_target"
        end
    end

    if UsesPositionCast(plan) then
        if ctx.castTargetTree and castTarget then
            attempts[#attempts + 1] = { order = ctx.castTargetTree, target = castTarget, pos = anchorPos, tag = "tree_cast_anchor" }
        end
    else
        if ctx.castTarget and castTarget then
            attempts[#attempts + 1] = { order = ctx.castTarget, target = castTarget, pos = Vector(0, 0, 0), tag = "ent_zero" }
        end
    end

    for i = 1, #attempts do
        local attempt = attempts[i]
        if attempt.order and TryIssuePrepareOrderAny(
            player,
            attempt.order,
            attempt.target,
            attempt.pos,
            deadShot,
            hero,
            ORDER_ID .. ".stage1_" .. attempt.tag,
            false,
            true
        ) then
            QueueVectorFollowup(player, hero, deadShot, plan, ctx, attempt.tag)
            LogCastDebug("STAGE1", string.format(
                "ok tag=%s order=%s target=%s pos=(%s)",
                attempt.tag,
                tostring(attempt.order),
                FmtEntityRef(attempt.target),
                FmtPos(attempt.pos)
            ))
            return true, attempt.tag
        end
    end

    return false, UsesPositionCast(plan) and "tree_stage1_failed" or "entity_stage1_failed"
end

local function MarkCastIssued(me, deadShot, now)
    local stats = GetAbilityStats(me, deadShot)
    State.postOrderLockUntil = now + (stats.castPoint or DEFAULT_CAST_POINT) + 0.06
end

local function TryProcessVectorFollowup()
    local pending = State.pendingVectorStep
    if not pending then
        return false
    end

    local now = SafeCall(GameRules.GetGameTime) or 0
    if now < (pending.dueTime or 0) then
        return true
    end

    if now > (pending.expireTime or 0) then
        if not pending.phaseSeen and not pending.followupIssued then
            LogCastDebug("FOLLOWUP", string.format(
                "vector phase not observed | stage1=%s attempts=0 live=%s",
                tostring(pending.stage1Reason or "?"),
                FmtSnapshot(CaptureCastSnapshot(pending.ability, pending.player, pending.hero))
            ))
        else
            LogCastDebug("FOLLOWUP", string.format(
                "expired stage1=%s attempts=%d live=%s",
                tostring(pending.stage1Reason or "?"),
                pending.attempts or 0,
                FmtSnapshot(CaptureCastSnapshot(pending.ability, pending.player, pending.hero))
            ))
        end
        State.postOrderLockUntil = now + FOLLOWUP_FAIL_COOLDOWN
        ClearVectorFollowup()
        UnlockCastPlanForRepeat()
        return false
    end

    -- Player.GetActiveAbility is often nil for Dead Shot vector targeting.
    -- Only abort when a *different* ability is clearly active; never block on nil.
    local activeAbility = GetPlayerActiveAbility(pending.player)
    if activeAbility and pending.ability and not IsSameAbilityRef(activeAbility, pending.ability) then
        LogCastDebug("FOLLOWUP", string.format(
            "abort active_changed active=%s expected=%s",
            GetAbilityNameSafe(activeAbility) or "?",
            GetAbilityNameSafe(pending.ability) or "?"
        ))
        ClearVectorFollowup()
        return false
    end

    -- Fire once while the ability is in its vector-targeting phase. Orders
    -- sent before this phase are accepted by pcall but ignored by the game.
    local inPhase = SafeCall(Ability.IsInAbilityPhase, pending.ability) == true
    if inPhase then
        pending.phaseSeen = true
    end
    if not pending.followupIssued and not inPhase then
        LogCastDebugOnce(pending, "wait_phase", "FOLLOWUP", string.format(
            "wait stage1 phase | inPhase=0 active=%s snap=%s",
            GetAbilityNameSafe(activeAbility) or "nil",
            FmtSnapshot(CaptureCastSnapshot(pending.ability, pending.player))
        ))
        pending.dueTime = now + VECTOR_FOLLOWUP_DELAY
        return true
    end

    local player = pending.player
    local hero = pending.hero
    local deadShot = pending.ability
    local ctx = pending.ctx
    local castTarget = pending.castTarget
    local stats = State.abilityStats or GetAbilityStats(hero, deadShot)
    local vectorPos = ResolveFollowupVectorPos(pending, hero, stats)
    local before = CaptureCastSnapshot(deadShot, player, hero)

    if not player or not ctx or not ctx.vectorTargetPosition or not vectorPos then
        LogCastDebug("FOLLOWUP", string.format(
            "abort missing ctx player=%s vectorOrder=%s vectorPos=%s",
            tostring(player ~= nil),
            tostring(ctx and ctx.vectorTargetPosition ~= nil),
            FmtPos(vectorPos)
        ))
        ClearVectorFollowup()
        return false
    end

    local anchorPos = castTarget and SafeCall(Entity.GetAbsOrigin, castTarget) or pending.castTargetPos
    local enemyPos = pending.enemy and SafeCall(Entity.GetAbsOrigin, pending.enemy)
    local queuedVec = pending.vectorPos
    local vecDelta = queuedVec and vectorPos and Dist2D(queuedVec, vectorPos) or 0

    local function markSuccess(reason)
        local after = CaptureCastSnapshot(deadShot, player)
        State.postOrderLockUntil = now + POST_ORDER_LOCK_SUCCESS
        State.lastSuccessfulCastAt = now
        LogCastDebug("CAST", string.format(
            "confirmed %s | before=%s after=%s vec=(%s)",
            tostring(reason),
            FmtSnapshot(pending.castSnapshot or before),
            FmtSnapshot(after),
            FmtPos(vectorPos)
        ))
        ClearVectorFollowup()
        UnlockCastPlanForRepeat()
        return true
    end

    local queuedAccepted, queuedReason = WasVectorFollowupAccepted(deadShot, pending.castSnapshot)
    if queuedAccepted then
        return markSuccess(tostring(pending.issuedMethod or "queued") .. "+" .. queuedReason)
    end

    if pending.followupIssued then
        LogCastDebugOnce(pending, "wait_accept", "FOLLOWUP", string.format(
            "wait acceptance method=%s snap=%s",
            tostring(pending.issuedMethod),
            FmtSnapshot(CaptureCastSnapshot(deadShot, player))
        ))
        pending.dueTime = now + VECTOR_FOLLOWUP_DELAY
        return true
    end

    pending.attempts = (pending.attempts or 0) + 1

    LogCastDebug("FOLLOWUP", string.format(
        "fire attempt=%d stage1=%s tree=%s inPhase=%s active=%s | anchor=%s@(%s) enemy=%s@(%s) queuedVec=(%s) liveVec=(%s) vecDelta=%.0f before=%s",
        pending.attempts,
        tostring(pending.stage1Reason or "?"),
        tostring(pending.isTree),
        inPhase and "1" or "0",
        GetAbilityNameSafe(activeAbility) or "nil",
        FmtEntityRef(castTarget),
        FmtPos(anchorPos),
        FmtEntityRef(pending.enemy),
        FmtPos(enemyPos),
        FmtPos(queuedVec),
        FmtPos(vectorPos),
        vecDelta,
        FmtSnapshot(before)
    ))

    -- VECTOR_TARGET_POSITION must retain the primary unit for hero anchors.
    -- With target=nil the cast still consumes a charge, but Dead Shot can
    -- ricochet along its default incoming direction instead of our vector.
    local vectorOrderTarget = (pending.anchorMode == "hero" or pending.mode == "hero")
        and castTarget
        or nil
    local orderOk, orderMethod = TryIssueVectorFollowupOrder(
        player,
        ctx.vectorTargetPosition,
        vectorOrderTarget,
        vectorPos,
        deadShot,
        hero,
        ORDER_ID .. ".followup_a" .. pending.attempts
    )
    if orderOk then
        pending.followupIssued = true
        pending.issuedMethod = orderMethod
        pending.vectorPos = MakeGroundPosition(vectorPos)
        local accepted, acceptReason = WasVectorFollowupAccepted(deadShot, before)
        if accepted then
            return markSuccess("followup_" .. orderMethod .. "+" .. acceptReason)
        end
        local queuedAfter, queuedAfterReason = WasVectorFollowupAccepted(deadShot, pending.castSnapshot)
        if queuedAfter then
            return markSuccess("followup_" .. orderMethod .. "_queued+" .. queuedAfterReason)
        end
        LogCastDebug("FOLLOWUP", string.format(
            "issued method=%s target=%s accepted=false; waiting after=%s",
            tostring(orderMethod),
            FmtEntityRef(vectorOrderTarget),
            FmtSnapshot(CaptureCastSnapshot(deadShot, player))
        ))
        pending.dueTime = now + VECTOR_FOLLOWUP_DELAY
        return true
    else
        LogCastDebug("FOLLOWUP", string.format(
            "try method=%s order=fail",
            tostring(orderMethod)
        ))
    end

    if pending.attempts < VECTOR_FOLLOWUP_MAX_ATTEMPTS then
        LogCastDebug("FOLLOWUP", string.format(
            "retry scheduled attempt=%d next_in=%.2f",
            pending.attempts,
            VECTOR_FOLLOWUP_DELAY
        ))
        pending.dueTime = now + VECTOR_FOLLOWUP_DELAY
        return true
    end

    LogCastDebug("CAST", string.format(
        "followup failed stage1=%s attempts=%d vec=(%s) snap=%s",
        tostring(pending.stage1Reason or "?"),
        pending.attempts,
        FmtPos(vectorPos),
        FmtSnapshot(CaptureCastSnapshot(deadShot, player))
    ))
    State.postOrderLockUntil = now + FOLLOWUP_FAIL_COOLDOWN
    ClearVectorFollowup()
    UnlockCastPlanForRepeat()
    return false
end

local function IssueDeadShotOrder(me, deadShot, plan)
    local player = GetPlayerForHero(me)
    local ctx = GetResolvedOrderContext()

    if not player or not ctx then
        return false, "no_player_or_ctx"
    end

    local now = SafeCall(GameRules.GetGameTime) or 0
    local okStage1, stage1Reason = IssueStage1ForPlan(player, me, deadShot, plan, ctx)
    if okStage1 then
        MarkCastIssued(me, deadShot, now)
        return true, stage1Reason
    end

    return false, tostring(stage1Reason)
end

--#endregion

--#region Draw

local OverlayTheme = {
    route = Color(120, 210, 255, 220),
    hit = Color(120, 255, 160, 220),
    marginal = Color(255, 220, 90, 220),
    anchor = Color(255, 150, 90, 220),
    velocity = Color(255, 120, 220, 200),
}

local function WorldToScreen(world)
    if not Render or not Render.WorldToScreen then
        return nil, false
    end
    local ok, screen, visible = pcall(Render.WorldToScreen, world)
    if ok and screen and visible then
        return screen, true
    end
    return nil, false
end

local function DrawScreenLine(a, b, color, thickness)
    if not Render or not Render.Line or not a or not b then
        return
    end
    pcall(Render.Line, a, b, color, thickness or 2)
end

local function DrawWorldRoute(fromPos, toPos, color, thickness)
    local a, aVisible = WorldToScreen(fromPos)
    local b, bVisible = WorldToScreen(toPos)
    if aVisible and bVisible then
        DrawScreenLine(a, b, color, thickness)
    end
end

local function DrawPlanOverlay(plan)
    if not plan then
        return
    end

    local me = Heroes.GetLocal()
    local myPos = me and SafeCall(Entity.GetAbsOrigin, me)
    if not myPos or not plan.enemy then
        return
    end

    local anchorPos = plan.castTargetPos
    local aimPos = plan.predictedPos
    local ricochetEnd = plan.ricochetEnd
    if not anchorPos or not aimPos then
        return
    end

    local lineColor = plan.hitCertainty >= 0.75 and OverlayTheme.route or OverlayTheme.marginal
    local enemyPos = SafeCall(Entity.GetAbsOrigin, plan.enemy)

    DrawWorldRoute(myPos, anchorPos, lineColor, 2)
    if ricochetEnd then
        DrawWorldRoute(anchorPos, ricochetEnd, lineColor, 2)
    end

    if enemyPos then
        local vx, vy, speed = GetSampledVelocity(plan.enemy)
        if speed >= MIN_MOTION_SPEED then
            local velEnd = Vector(
                enemyPos.x + vx * 0.35,
                enemyPos.y + vy * 0.35,
                enemyPos.z
            )
            DrawWorldRoute(enemyPos, velEnd, OverlayTheme.velocity, 2)
        end

        local enemyScreen, enemyVisible = WorldToScreen(enemyPos)
        if enemyVisible and Render and Render.FilledCircle then
            pcall(Render.FilledCircle, enemyScreen, 5, OverlayTheme.anchor)
        end
    end

    local aimScreen, visible = WorldToScreen(aimPos)
    if visible and Render and Render.FilledCircle then
        local hitColor = plan.hitCertainty >= 0.75 and OverlayTheme.hit or OverlayTheme.marginal
        pcall(Render.FilledCircle, aimScreen, 6, hitColor)
    end
end

--#endregion

--#region State reset

local function ClearBindLocks()
    State.activeBindMode = nil
    State.lockedAimTarget = nil
    State.lockedComboTarget = nil
    State.lockedCastPlan = nil
end

local function ResetHoldState()
    ClearBindLocks()
    State.combatTarget = nil
    State.bestPlan = nil
    State.precomputedCast = nil
    State.planLockedAt = -100
    State.lastAnchorEnemyPos = nil
    State.lastSuccessfulCastAt = -100
    State.lastCastCharges = nil
    ClearVectorFollowup()
end

local function ResetAllState()
    ResetHoldState()
    State.unitMotion = {}
    State.anchorBuffer = {}
    State.anchorSeen = {}
    State.enemyBuffer = {}
    State.lastPlanAt = -100
    State.lastAnchorScanAt = -100
    State.lastTargetScanAt = -100
    State.postOrderLockUntil = 0
    State.abilityStats = nil
    State.cachedAnchorCount = 0
    State.preferredIssuer = nil
    State.nextDebugLogAt = {}
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    EnsureMenu()
    SyncBuiltInMenu(true)
    Log("info", "loaded")
end

local function IsCastPending(deadShot, now)
    if SafeCall(Ability.IsInAbilityPhase, deadShot) then
        return true
    end
    if now < 0 then
        return true
    end
    return false
end

local function DidAbilityConsume(deadShot)
    local charges = SafeCall(Ability.GetCurrentCharges, deadShot)
    if charges ~= nil and State.lastCastCharges ~= nil and charges < State.lastCastCharges then
        State.lastCastCharges = charges
        return true
    end

    local cooldown = SafeCall(Ability.GetCooldown, deadShot) or 0
    if cooldown > 0.1 then
        return true
    end

    return false
end

local function RefreshCombatState(me, deadShot, now, bindHeld)
    if not me or not deadShot then
        return
    end

    local stats = GetAbilityStats(me, deadShot)
    State.abilityStats = stats

    if now - State.lastTargetScanAt >= TARGET_SCAN_INTERVAL then
        State.lastTargetScanAt = now
        local enemies, count = GetEnemyHeroes(me, stats.castRange + 300)
        ResolveCombatTarget(me, enemies, count, bindHeld)
    end

    local target = State.combatTarget
    if not target or not CanCastOnEnemy(target, me) then
        State.combatTarget = nil
        State.bestPlan = nil
        State.precomputedCast = nil
        State.lockedCastPlan = nil
        State.planLockedAt = -100
        State.lastLoggedPlanKey = nil
        return
    end

    if bindHeld
        and State.lockedCastPlan
        and not IsPlanStillValid(State.lockedCastPlan, me, target, stats)
    then
        UnlockCastPlanForRepeat()
    end

    UpdateUnitMotionCache({ target })

    if State.pendingVectorStep and bindHeld and State.lockedCastPlan then
        State.precomputedCast = BuildCastPlan(State.lockedCastPlan, me, stats)
        return
    end

    local _, _, targetSpeed = GetSampledVelocity(target)
    local planInterval = targetSpeed >= MIN_MOTION_SPEED
        and FULL_PLAN_SOLVE_INTERVAL
        or PLAN_RESOLVE_STABLE_INTERVAL

    if bindHeld then
        if not State.lockedCastPlan then
            local bestPlanValid = State.bestPlan
                and IsPlanStillValid(State.bestPlan, me, target, stats)
            local solveDue = now - State.lastPlanAt >= planInterval
            if (State.bestPlan and not bestPlanValid) or (not State.bestPlan and solveDue) then
                State.lastPlanAt = now
                local candidate = FindBestDeadShotPlan(me, deadShot, target, now)
                State.bestPlan = StabilizePlanChoice(candidate, me, target, stats, now)
            end
            if State.bestPlan then
                State.lockedCastPlan = CloneCastPlan(State.bestPlan)
            else
                LogCastDebugThrottled(
                    "lock_no_plan",
                    0.75,
                    "PLAN",
                    "bind held | no valid plan"
                )
            end
        end
    else
        State.lockedCastPlan = nil

        local needSolve = now - State.lastPlanAt >= planInterval
            or not State.bestPlan
            or State.bestPlan.enemy ~= target
            or not IsPlanStillValid(State.bestPlan, me, target, stats)

        if needSolve then
            State.lastPlanAt = now
            local candidate = FindBestDeadShotPlan(me, deadShot, target, now)
            State.bestPlan = StabilizePlanChoice(candidate, me, target, stats, now)
        end
    end

    local geometryPlan = bindHeld and State.lockedCastPlan or State.bestPlan
    if geometryPlan then
        State.precomputedCast = BuildCastPlan(geometryPlan, me, stats)
        local planKey = GetPlanAnchorKey(geometryPlan)
        if planKey and planKey ~= State.lastLoggedPlanKey then
            State.lastLoggedPlanKey = planKey
            LogCastDebug("PLAN", string.format(
                "%s | %s",
                bindHeld and "precompute locked" or "precompute live",
                DescribeCastPlan(State.precomputedCast, me, stats)
            ))
        end
    else
        if State.lastLoggedPlanKey ~= nil then
            State.lastLoggedPlanKey = nil
            LogCastDebug("PLAN", "precompute cleared | no plan")
        end
        State.precomputedCast = nil
    end
end

function Script.OnUpdate()
    EnsureMenu()
    SyncBuiltInMenu(false)

    if Engine and Engine.IsInGame and not SafeCall(Engine.IsInGame) then
        ResetHoldState()
        return
    end

    local me = Heroes.GetLocal()
    if not me or SafeCall(NPC.GetUnitName, me) ~= HERO_NAME then
        ResetHoldState()
        return
    end

    if Input and Input.IsInputCaptured and SafeCall(Input.IsInputCaptured) then
        local now = SafeCall(GameRules.GetGameTime) or 0
        local deadShot = SafeCall(NPC.GetAbility, me, DEAD_SHOT_NAME)
        RefreshCombatState(me, deadShot, now, false)
        return
    end

    if not State.menuReady or not WidgetGet(UI.Enabled, true) then
        if not IsAnyBindHeld() then
            ClearBindLocks()
        end
        return
    end

    local now = SafeCall(GameRules.GetGameTime) or 0
    local deadShot = SafeCall(NPC.GetAbility, me, DEAD_SHOT_NAME)
    local bindHeld = IsAnyBindHeld()

    if State.pendingVectorStep then
        TryProcessVectorFollowup()
        if not bindHeld and not State.pendingVectorStep then
            ClearBindLocks()
        end
        return
    end

    RefreshCombatState(me, deadShot, now, bindHeld)

    if not bindHeld then
        ClearBindLocks()
        return
    end

    if not CanAct(me) then
        return
    end

    if now < (State.postOrderLockUntil or 0) then
        return
    end

    local mana = SafeCall(NPC.GetMana, me)
    local ready = IsDeadShotReady(deadShot, mana)
    if not ready then
        if DidAbilityConsume(deadShot) then
            State.lastSuccessfulCastAt = now
        end
        return
    end

    if IsCastPending(deadShot, now) then
        if DidAbilityConsume(deadShot) then
            State.lastSuccessfulCastAt = now
        end
        return
    end

    if now - State.lastSuccessfulCastAt < GetCastRepeatDelay(deadShot) then
        return
    end

    local charges = SafeCall(Ability.GetCurrentCharges, deadShot)
    if charges ~= nil then
        State.lastCastCharges = charges
    end

    local castPlan = CloneCastPlan(State.precomputedCast)
    if not castPlan then
        LogCastDebugThrottled(
            "cast_no_plan",
            0.75,
            "CAST",
            "skipped | no valid plan | " .. tostring(State.lastAnchorDebug or "anchors=?")
        )
        return
    end

    if SafeCall(Ability.IsInAbilityPhase, deadShot) then
        return
    end

    local ok, reason = IssueDeadShotOrder(me, deadShot, castPlan)
    if ok then
        LogCastDebug("CAST", string.format(
            "issued stage1=%s | scan=%s | %s",
            tostring(reason),
            tostring(State.lastAnchorDebug or "anchors=?"),
            DescribeCastPlan(castPlan, me, State.abilityStats)
        ))
    else
        State.postOrderLockUntil = now + 0.35
        UnlockCastPlanForRepeat()
        LogCastDebug("CAST", string.format(
            "stage1 failed reason=%s | %s",
            tostring(reason),
            DescribeCastPlan(castPlan, me, State.abilityStats)
        ))
    end
end

function Script.OnDraw()
    EnsureMenu()
    if not ShouldDrawPreview() then
        return
    end
    if not WidgetGet(UI.Enabled, true) then
        return
    end
    if not SafeCall(Engine.IsInGame) then
        return
    end

    local me = Heroes.GetLocal()
    if not me or SafeCall(NPC.GetUnitName, me) ~= HERO_NAME then
        return
    end

    DrawPlanOverlay(State.precomputedCast)
end

function Script.OnGameEnd()
    ResetAllState()
    State.menuReady = false
    State._logger = nil
    UI = {}
    BuiltIn = {}
end

--#endregion

return Script
