--[[
    Magnus — Harpoon + Blink + Reverse Polarity combo
    Hold combo key: approach → harpoon → blink behind cluster → RP
    Script by Euphoria
    --]]

local Script = {}

--#region Constants

local DEBUG_PREFIX = "[MagnusHarpoonRP] "
local HERO_NAME = "npc_dota_hero_magnataur"
local HARPOON_NAME = "item_harpoon"
local RP_NAME = "magnataur_reverse_polarity"
local ORDER_ID = "magnus.harpoon_blink_rp"

local DEFAULT_RP_RADIUS = 430
local DEFAULT_HARPOON_RANGE = 700
local MIN_BLINK_DIST_FROM_ME = 150
local BLINK_RANGE_MARGIN = 20
local BLINK_SCAN_STEP = 25
local BLINK_ANGLE_STEP = 5
local BLINK_ANGLE_MAX = 20
local SCAN_RADIUS_BUFFER = 300
local TWO_ENEMY_MAX_SEP = 200

local DEBUG_HOLD_INTERVAL = 0.5
local COMBO_RECOVERY_TIME = 0.45
local RECOVERY_MIN_DELAY = 0.15
local HARPOON_PULL_RATIO = 0.45
local CLUSTER_MERGE_RATIO = 0.15
local APPROACH_MOVE_INTERVAL = 0.12
local HARPOON_RETRY_DELAY = 0.12

-- Always-on logic (hidden from menu to avoid breaking the combo)
local CONFIG = {
    targetLock = true,
    skipHarpoonBlock = true,
    predictPull = true,
    blinkBehind = true,
    requireBlinkRange = true,
}

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local HARPOON_BLOCK_MODIFIERS = {
    "modifier_item_sphere_target",
    "modifier_item_lotus_orb_channel",
    "modifier_antimage_spell_shield",
}

--#endregion

--#region State

local State = {
    lastDebugHoldLog = -100,
    lastApproachMove = -100,
    comboDone = false,
    harpoonAttempted = false,
    blinkRpSent = false,
    comboAttemptTime = 0,
    lockedHarpoonTarget = nil,
    lockedTargets = nil,
}

--#endregion

local UI = {}

--#region Localization

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

local I = {
    power   = "\u{f011}", -- power
    combo   = "\u{f0e7}", -- bolt
    bind    = "\u{f084}", -- keyboard
    sep     = "\u{f337}", -- horizontal separation
    hits    = "\u{f0c0}", -- group hits
    ruler   = "\u{f547}", -- behind distance
    bug     = "\u{f188}", -- debug
    gear    = "\u{f013}", -- settings gear
}

local Locale = {
    group_name = {
        en = "Harpoon Combo",
        ru = "Комбо Harpoon",
        cn = "钩矛连招",
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
    ui_min_sep = {
        en = "Min target separation",
        ru = "Мин. расстояние целей",
        cn = "最小目标间距",
    },
    ui_min_rp_hits = {
        en = "Min RP hits",
        ru = "Мин. попаданий RP",
        cn = "最小RP命中数",
    },
    ui_behind_dist = {
        en = "Behind distance",
        ru = "Дистанция за толпой",
        cn = "敌后距离",
    },
    ui_debug = {
        en = "Debug logs",
        ru = "Debug логи",
        cn = "调试日志",
    },
    tip_enabled = {
        en = "Master switch for the Magnus Harpoon + Blink + RP combo script.",
        ru = "Главный переключатель скрипта комбо Harpoon + Blink + RP.",
        cn = "Magnus 钩矛+闪烁+反转极性连招脚本总开关。",
    },
    tip_combo_key = {
        en = "Hold this key to run the combo: approach if needed, harpoon, blink behind the cluster, then RP.",
        ru = "Удерживай для комбо: подход при необходимости, harpoon, блинк за толпу, затем RP.",
        cn = "按住此键执行连招：必要时接近、钩矛、闪到敌后、再反转极性。",
    },
    tip_min_sep = {
        en = "Minimum distance between harpoon target and blink anchor enemy.",
        ru = "Минимальная дистанция между целью harpoon и якорем для блинка.",
        cn = "钩矛目标与闪烁锚点敌人之间的最小距离。",
    },
    tip_min_rp_hits = {
        en = "Minimum enemy heroes that must be caught by RP for a valid combo.",
        ru = "Минимум врагов, которых должен зацепить RP для валидного комбо.",
        cn = "连招成立时反转极性至少命中的敌方英雄数量。",
    },
    tip_behind_dist = {
        en = "Minimum distance past the predicted cluster; blink uses full range beyond this point.",
        ru = "Минимальное расстояние за предсказанной толпой; блинк идёт на полный радиус дальше этой точки.",
        cn = "超过预测敌群的最小距离；在此之外会使用闪烁的完整射程。",
    },
    tip_debug = {
        en = "Write combo decisions and casts to debug.log.",
        ru = "Писать решения комбо и касты в debug.log.",
        cn = "将连招决策和施法写入 debug.log。",
    },
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

    MenuLabel(UI.MinSep, "ui_min_sep")
    MenuTip(UI.MinSep, "tip_min_sep")

    MenuLabel(UI.MinRPHits, "ui_min_rp_hits")
    MenuTip(UI.MinRPHits, "tip_min_rp_hits")

    MenuLabel(UI.BehindDistance, "ui_behind_dist")
    MenuTip(UI.BehindDistance, "tip_behind_dist")

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

local function InitializeUI()
    ---@type CMenuGroup|nil
    local group = nil

    local mainSection = Menu.Find("Heroes", "Hero List", "Magnus", "Main Settings")
    if mainSection and mainSection.Create then
        group = mainSection:Create("Harpoon Combo")
    end

    if not group then
        group = Menu.Create("Scripts", "Combat", "Magnus Harpoon Combo", "Main", "Harpoon Combo")
    end

    if not group then
        error(DEBUG_PREFIX .. "Failed to create menu group")
    end

    MenuNodes.group = group

    local ui = {}
    ui.Enabled = group:Switch("Enable", false)
    MenuIcon(ui.Enabled, I.power)

    ui.ComboKey = group:Bind("Combo Key", Enum.ButtonCode.KEY_NONE)
    MenuIcon(ui.ComboKey, I.bind)

    local gear = ui.Enabled:Gear("Settings", I.gear, true)
    MenuNodes.gear = gear

    ui.MinSep = gear:Slider("Min target separation", 200, 1200, 400, "%d")
    MenuIcon(ui.MinSep, I.sep)

    ui.MinRPHits = gear:Slider("Min RP hits", 1, 5, 2, "%d")
    MenuIcon(ui.MinRPHits, I.hits)

    ui.BehindDistance = gear:Slider("Behind distance", 100, 500, 280, "%d")
    MenuIcon(ui.BehindDistance, I.ruler)

    ui.Debug = gear:Switch("Debug logs", false)
    MenuIcon(ui.Debug, I.bug)

    local function UpdateControls()
        local enabled = ui.Enabled:Get()

        ui.ComboKey:Disabled(not enabled)
        ui.MinSep:Disabled(not enabled)
        ui.MinRPHits:Disabled(not enabled)
        ui.BehindDistance:Disabled(not enabled)
        ui.Debug:Disabled(not enabled)
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

local function GetCastableDebug(ability, mana, label)
    if not ability then
        return string.format("%s=missing", label)
    end

    return string.format(
        "%s ready=%s castable=%s cd=%.2f",
        label,
        tostring(Ability.IsReady(ability)),
        tostring(Ability.IsCastable(ability, mana)),
        Ability.GetCooldown(ability) or -1
    )
end

local function LogHoldState(reason, me, mana, harpoon, blink, blinkName, rp, targets, comboReady)
    local now = GlobalVars.GetCurTime() or 0
    if now - State.lastDebugHoldLog < DEBUG_HOLD_INTERVAL then
        return
    end

    State.lastDebugHoldLog = now

    local harpBonus = NPC.GetCastRangeBonus(me) or 0
    local harpBase = harpoon and Ability.GetCastRange(harpoon) or 0
    local blinkBase = blink and Ability.GetCastRange(blink) or 0

    Dbg(
        "HOLD | %s | ready=%s | harpoon=%.0f blink=%.0f (%s) | %s | %s | %s | %s",
        reason,
        tostring(comboReady),
        harpBase + harpBonus,
        blinkBase + harpBonus,
        blinkName or "none",
        GetCastableDebug(harpoon, mana, "harpoon"),
        GetCastableDebug(blink, mana, "blink"),
        GetCastableDebug(rp, mana, "rp"),
        targets and string.format(
            "hits=%d sep=%.0f pos=(%.0f,%.0f)",
            targets.hitCount,
            targets.sepDist,
            targets.blinkPos.x,
            targets.blinkPos.y
        ) or "none"
    )
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

local function HasHarpoonBlock(unit)
    if not IsValidHero(unit) then
        return false
    end

    for _, modifierName in ipairs(HARPOON_BLOCK_MODIFIERS) do
        if NPC.HasModifier(unit, modifierName) then
            return true
        end
    end

    return false
end

local function CanHarpoonTarget(target)
    if not IsValidHero(target) then
        return false
    end

    if CONFIG.skipHarpoonBlock and HasHarpoonBlock(target) then
        return false
    end

    return true
end

local function CanBlinkAnchor(target)
    return IsValidHero(target)
end

local function CanAct(me)
    if not IsValidHero(me) then
        return false
    end

    return not NPC.IsStunned(me)
        and not NPC.IsSilenced(me)
        and not NPC.HasState(me, Enum.ModifierState.MODIFIER_STATE_ROOTED)
end

local function IsComboKeyHeld()
    return UI.ComboKey.IsDown and UI.ComboKey:IsDown()
end

local function GetBlink(me)
    for _, name in ipairs(BLINK_ITEMS) do
        local blink = NPC.GetItem(me, name, true)
        if blink then
            return blink, name
        end
    end
    return nil, nil
end

local function GetItemCastRange(me, item, fallback)
    if not item then
        return fallback and (fallback + (NPC.GetCastRangeBonus(me) or 0)) or 0
    end
    return Ability.GetCastRange(item) + (NPC.GetCastRangeBonus(me) or 0)
end

local function GetRPRadius(rp)
    if not rp then
        return DEFAULT_RP_RADIUS
    end

    local radius = Ability.GetLevelSpecialValueFor(rp, "pull_radius")
    return (radius and radius > 0) and radius or DEFAULT_RP_RADIUS
end

local function Lerp3(a, b, t)
    return Vector(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    )
end

local function EffectiveMinSep(enemyCount, minSep)
    if enemyCount <= 2 then
        return math.min(minSep, TWO_ENEMY_MAX_SEP)
    end
    return minSep
end

local function ResetHoldState()
    State.comboDone = false
    State.harpoonAttempted = false
    State.blinkRpSent = false
    State.comboAttemptTime = 0
    State.lastApproachMove = -100
    State.lockedHarpoonTarget = nil
    State.lockedTargets = nil
end

--#endregion

--#region Targeting

local function GetHarpoonTargetUnderCursor(me, debugReason)
    local harpoonTarget = Input.GetNearestHeroToCursor(
        Entity.GetTeamNum(me),
        Enum.TeamType.TEAM_ENEMY
    )

    if not harpoonTarget or not CanHarpoonTarget(harpoonTarget) then
        if debugReason then
            debugReason[1] = harpoonTarget and HasHarpoonBlock(harpoonTarget)
                and "harpoon target has block (Linken's/Lotus)"
                or "no valid harpoon target under cursor"
        end
        return nil
    end

    return harpoonTarget
end

local function ResolveHarpoonTarget(me, debugReason)
    if CONFIG.targetLock then
        if not State.lockedHarpoonTarget then
            State.lockedHarpoonTarget = GetHarpoonTargetUnderCursor(me, nil)
        end

        local locked = State.lockedHarpoonTarget
        if not locked or not CanHarpoonTarget(locked) then
            if debugReason then
                debugReason[1] = locked and HasHarpoonBlock(locked)
                    and "locked harpoon target blocked"
                    or "no locked harpoon target"
            end
            return nil
        end

        return locked
    end

    return GetHarpoonTargetUnderCursor(me, debugReason)
end

local function GetHarpoonDist(me, target)
    return (Entity.GetAbsOrigin(target) - Entity.GetAbsOrigin(me)):Length2D()
end

local function GetHarpoonCastRange(me, harpoon)
    return GetItemCastRange(me, harpoon, DEFAULT_HARPOON_RANGE)
end

local function IsHarpoonInCastRange(me, target, harpoon)
    if not NPC.IsEntityInRange then
        return GetHarpoonDist(me, target) <= GetHarpoonCastRange(me, harpoon)
    end

    return NPC.IsEntityInRange(me, target, GetHarpoonCastRange(me, harpoon))
end

local function CanCastHarpoonNow(me, target, harpoon, mana)
    return Ability.IsCastable(harpoon, mana) and IsHarpoonInCastRange(me, target, harpoon)
end

local function TryApproachHarpoonTarget(me, harpoon, harpoonTarget, now, mana, force)
    if not CanAct(me) then
        return false
    end

    if not force and CanCastHarpoonNow(me, harpoonTarget, harpoon, mana) then
        return false
    end

    if now - State.lastApproachMove < APPROACH_MOVE_INTERVAL then
        return true
    end

    State.lastApproachMove = now
    local targetPos = Entity.GetAbsOrigin(harpoonTarget)
    NPC.MoveTo(me, targetPos, false, false, false, true, ORDER_ID .. ".approach", false)
    Dbg(
        "approach | dist=%.0f range=%.0f",
        GetHarpoonDist(me, harpoonTarget),
        GetHarpoonCastRange(me, harpoon)
    )
    return true
end

local function GetEnemyHeroes(me, scanRadius)
    local team = Entity.GetTeamNum(me)
    local myPos = Entity.GetAbsOrigin(me)
    local raw = Heroes.InRadius(myPos, scanRadius, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    local enemies = {}

    for _, enemy in ipairs(raw) do
        if IsValidHero(enemy) then
            enemies[#enemies + 1] = enemy
        end
    end

    return enemies
end

local function PredictPostHarpoonPositions(harpoonTarget, harpoonPos, myPos, enemies)
    local predicted = {}
    local pulledTarget = Lerp3(harpoonPos, myPos, HARPOON_PULL_RATIO)

    for _, enemy in ipairs(enemies) do
        if IsValidHero(enemy) then
            local pos = Entity.GetAbsOrigin(enemy)
            if enemy == harpoonTarget then
                predicted[#predicted + 1] = { unit = enemy, pos = pulledTarget }
            else
                predicted[#predicted + 1] = {
                    unit = enemy,
                    pos = Lerp3(pos, pulledTarget, CLUSTER_MERGE_RATIO),
                }
            end
        end
    end

    return predicted
end

local function CountPredictedHits(origin, predicted, radius)
    local count = 0

    for _, entry in ipairs(predicted) do
        if (entry.pos - origin):Length2D() <= radius then
            count = count + 1
        end
    end

    return count
end

local function GetPredictedClusterCenter(predicted, fallback)
    if #predicted == 0 then
        return fallback
    end

    local sumX, sumY, sumZ = 0, 0, fallback.z
    for _, entry in ipairs(predicted) do
        sumX = sumX + entry.pos.x
        sumY = sumY + entry.pos.y
        sumZ = sumZ + entry.pos.z
    end

    return Vector(sumX / #predicted, sumY / #predicted, sumZ / #predicted)
end

local function RotateDir2D(dx, dy, angleRad)
    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)
    return dx * cosA - dy * sinA, dx * sinA + dy * cosA
end

local function ComputeBlinkPosition(myPos, harpoonPos, predicted, rpRadius, blinkRange)
    local clusterPos = GetPredictedClusterCenter(predicted, harpoonPos)
    if not CONFIG.predictPull then
        clusterPos = harpoonPos
    end

    local dx = clusterPos.x - myPos.x
    local dy = clusterPos.y - myPos.y
    local baseLen = math.sqrt(dx * dx + dy * dy)

    if baseLen < 1 then
        return Vector(myPos.x, myPos.y, myPos.z), predicted
    end

    dx = dx / baseLen
    dy = dy / baseLen

    local clusterDist = baseLen
    local maxDist = math.max(MIN_BLINK_DIST_FROM_ME, blinkRange - BLINK_RANGE_MARGIN)
    local behindMin = CONFIG.blinkBehind and UI.BehindDistance:Get() or 0
    local minDist = CONFIG.blinkBehind
        and math.max(MIN_BLINK_DIST_FROM_ME, clusterDist + behindMin)
        or math.max(MIN_BLINK_DIST_FROM_ME, math.min(clusterDist, maxDist))

    if minDist > maxDist then
        minDist = maxDist
    end

    local function EvaluateDirection(dirX, dirY)
        local posAtMin = Vector(
            myPos.x + dirX * minDist,
            myPos.y + dirY * minDist,
            myPos.z
        )
        local bestPos = posAtMin
        local bestHits = CountPredictedHits(posAtMin, predicted, rpRadius)
        local bestDist = minDist

        for dist = maxDist, minDist, -BLINK_SCAN_STEP do
            local pos = Vector(
                myPos.x + dirX * dist,
                myPos.y + dirY * dist,
                myPos.z
            )
            local hits = CountPredictedHits(pos, predicted, rpRadius)

            if hits > bestHits or (hits == bestHits and dist > bestDist) then
                bestHits = hits
                bestPos = pos
                bestDist = dist
            end
        end

        return bestPos, bestHits, bestDist
    end

    local bestPos, bestHits, bestDist = EvaluateDirection(dx, dy)

    for angle = BLINK_ANGLE_STEP, BLINK_ANGLE_MAX, BLINK_ANGLE_STEP do
        local rad = math.rad(angle)
        for _, sign in ipairs({ -1, 1 }) do
            local dirX, dirY = RotateDir2D(dx, dy, rad * sign)
            local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
            if dirLen > 0.001 then
                dirX = dirX / dirLen
                dirY = dirY / dirLen
                local pos, hits, dist = EvaluateDirection(dirX, dirY)
                if hits > bestHits or (hits == bestHits and dist > bestDist) then
                    bestHits = hits
                    bestPos = pos
                    bestDist = dist
                end
            end
        end
    end

    return bestPos, predicted
end

local function FindBestBlinkTarget(me, harpoonTarget, enemies, blinkRange, rpRadius, minSep, minRPHits)
    local myPos = Entity.GetAbsOrigin(me)
    local harpoonPos = Entity.GetAbsOrigin(harpoonTarget)
    local minSeparation = EffectiveMinSep(#enemies, minSep)
    local predicted = PredictPostHarpoonPositions(harpoonTarget, harpoonPos, myPos, enemies)
    local blinkPos = ComputeBlinkPosition(myPos, harpoonPos, predicted, rpRadius, blinkRange)
    local distFromMe = (blinkPos - myPos):Length2D()
    local rpHits = CountPredictedHits(blinkPos, predicted, rpRadius)

    if distFromMe < MIN_BLINK_DIST_FROM_ME
        or rpHits < minRPHits
        or (CONFIG.requireBlinkRange and distFromMe > blinkRange) then
        return nil
    end

    local best = nil

    for _, enemy in ipairs(enemies) do
        if enemy ~= harpoonTarget and CanBlinkAnchor(enemy) then
            local anchorPos = Entity.GetAbsOrigin(enemy)
            local sepDist = (anchorPos - harpoonPos):Length2D()

            if sepDist >= minSeparation then
                local candidate = {
                    enemy = enemy,
                    blinkPos = blinkPos,
                    distFromMe = distFromMe,
                    sepDist = sepDist,
                    rpHits = rpHits,
                }

                if not best or candidate.sepDist > best.sepDist then
                    best = candidate
                end
            end
        end
    end

    return best
end

local function ResolveComboTargets(me, harpoon, blink, rp, debugReason)
    local myPos = Entity.GetAbsOrigin(me)
    local harpoonRange = GetHarpoonCastRange(me, harpoon)
    local blinkRange = GetItemCastRange(me, blink, nil)
    local rpRadius = GetRPRadius(rp)
    local scanRadius = harpoonRange + blinkRange + rpRadius + SCAN_RADIUS_BUFFER

    local harpoonTarget = ResolveHarpoonTarget(me, debugReason)
    if not harpoonTarget then
        return nil
    end

    local harpoonDist = GetHarpoonDist(me, harpoonTarget)
    if harpoonDist > harpoonRange then
        debugReason[1] = string.format("harpoon target too far (%.0f > %.0f)", harpoonDist, harpoonRange)
        return nil
    end

    local enemies = GetEnemyHeroes(me, scanRadius)
    if #enemies < 2 then
        debugReason[1] = string.format("need 2 enemies, found %d", #enemies)
        return nil
    end

    local best = FindBestBlinkTarget(
        me,
        harpoonTarget,
        enemies,
        blinkRange,
        rpRadius,
        UI.MinSep:Get(),
        UI.MinRPHits:Get()
    )

    if not best then
        debugReason[1] = string.format(
            "no blink target (sep>=%d hits>=%d enemies=%d)",
            EffectiveMinSep(#enemies, UI.MinSep:Get()),
            UI.MinRPHits:Get(),
            #enemies
        )
        return nil
    end

    debugReason[1] = "ok"
    return {
        harpoonTarget = harpoonTarget,
        blinkTarget = best.enemy,
        blinkPos = best.blinkPos,
        hitCount = best.rpHits,
        harpoonDist = harpoonDist,
        blinkDist = best.distFromMe,
        sepDist = best.sepDist,
    }
end

local function IsComboReady(me, mana, harpoon, blink, rp, targets)
    return targets
        and CanAct(me)
        and Ability.IsCastable(harpoon, mana)
        and Ability.IsCastable(blink, mana)
        and Ability.IsCastable(rp, mana)
end

--#endregion

--#region Casting

local function OrderTag(tag, suffix)
    return ORDER_ID .. "." .. tag .. "." .. suffix
end

local function CastHarpoonStep(targets, harpoon)
    Ability.CastTarget(harpoon, targets.harpoonTarget, false, true, true, OrderTag("harpoon", "cast"))
    Dbg(
        "CAST harpoon | hits=%d dist=%.0f",
        targets.hitCount,
        targets.harpoonDist
    )
end

local function CastBlinkAndRP(targets, blink, rp, tag)
    -- execute_fast prepends: blink fires first, then rp
    Ability.CastNoTarget(rp, false, true, true, OrderTag(tag, "rp"))
    Ability.CastPosition(blink, targets.blinkPos, false, true, true, OrderTag(tag, "blink"), true)
    Dbg("CAST %s | blink→rp | hits=%d pos=(%.0f,%.0f)", tag, targets.hitCount, targets.blinkPos.x, targets.blinkPos.y)
end

local function TryFinishCombo(activeTargets, harpoon, blink, rp, mana, elapsed, tag)
    if State.blinkRpSent then
        return false
    end

    if elapsed < RECOVERY_MIN_DELAY or elapsed > COMBO_RECOVERY_TIME then
        return false
    end

    if Ability.IsCastable(harpoon, mana) then
        return false
    end

    local blinkReady = Ability.IsCastable(blink, mana)
    local rpReady = Ability.IsCastable(rp, mana)
    local targets = State.lockedTargets or activeTargets

    if not blinkReady and not rpReady then
        Dbg("%s skipped | full combo landed", tag)
        State.blinkRpSent = true
        return true
    end

    State.blinkRpSent = true

    if blinkReady and rpReady then
        CastBlinkAndRP(targets, blink, rp, tag)
    elseif rpReady then
        Ability.CastNoTarget(rp, false, true, true, OrderTag(tag .. "-rp", "rp"))
        Dbg("CAST %s | rp only", tag)
    elseif blinkReady then
        Ability.CastPosition(blink, targets.blinkPos, false, true, true, OrderTag(tag .. "-blink", "blink"), true)
        Dbg("CAST %s | blink only", tag)
    end

    return true
end

--#endregion

--#region Script callbacks

function Script:OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    if not UI.Debug:Get() or not ability then
        return
    end

    local abilityName = GetAbilityName(ability)
    if abilityName ~= HARPOON_NAME
        and abilityName ~= RP_NAME
        and not string.find(abilityName, "blink", 1, true) then
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
    if not Engine.IsInGame() or not UI.Enabled:Get() then
        ResetHoldState()
        return
    end

    if Input.IsInputCaptured and Input.IsInputCaptured() then
        return
    end

    if not IsComboKeyHeld() then
        ResetHoldState()
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME or not CanAct(me) then
        return
    end

    local mana = NPC.GetMana(me)
    local harpoon = NPC.GetItem(me, HARPOON_NAME, true)
    local blink, blinkName = GetBlink(me)
    local rp = NPC.GetAbility(me, RP_NAME)

    if not harpoon or not blink or not rp then
        return
    end

    local now = GlobalVars.GetCurTime() or 0
    local debugReason = { "" }
    local targets = ResolveComboTargets(me, harpoon, blink, rp, debugReason)
    local comboReady = IsComboReady(me, mana, harpoon, blink, rp, targets)

    LogHoldState(debugReason[1], me, mana, harpoon, blink, blinkName, rp, targets, comboReady)

    if State.comboDone then
        return
    end

    local activeTargets = State.lockedTargets or targets

    if not activeTargets then
        local harpoonTarget = ResolveHarpoonTarget(me, nil)
        if harpoonTarget then
            TryApproachHarpoonTarget(me, harpoon, harpoonTarget, now, mana)
        end
        return
    end

    if State.harpoonAttempted then
        local elapsed = now - State.comboAttemptTime

        if Ability.IsCastable(harpoon, mana) and elapsed >= HARPOON_RETRY_DELAY then
            Dbg(
                "harpoon retry | dist=%.0f inRange=%s",
                GetHarpoonDist(me, activeTargets.harpoonTarget),
                tostring(IsHarpoonInCastRange(me, activeTargets.harpoonTarget, harpoon))
            )
            State.harpoonAttempted = false
            if CanCastHarpoonNow(me, activeTargets.harpoonTarget, harpoon, mana) then
                TryApproachHarpoonTarget(me, harpoon, activeTargets.harpoonTarget, now, mana, true)
            else
                TryApproachHarpoonTarget(me, harpoon, activeTargets.harpoonTarget, now, mana, false)
            end
            return
        end

        if not State.blinkRpSent then
            TryFinishCombo(activeTargets, harpoon, blink, rp, mana, elapsed, "recovery")
        end

        if State.blinkRpSent then
            State.comboDone = true
        elseif not Ability.IsCastable(blink, mana) and not Ability.IsCastable(rp, mana) then
            State.comboDone = true
        elseif elapsed > COMBO_RECOVERY_TIME then
            if not State.blinkRpSent then
                TryFinishCombo(activeTargets, harpoon, blink, rp, mana, elapsed, "late-recovery")
            end
            State.comboDone = true
        end
        return
    end

    if not IsComboReady(me, mana, harpoon, blink, rp, activeTargets) then
        return
    end

    if not CanCastHarpoonNow(me, activeTargets.harpoonTarget, harpoon, mana) then
        TryApproachHarpoonTarget(me, harpoon, activeTargets.harpoonTarget, now, mana)
        return
    end

    if targets then
        State.lockedTargets = targets
        activeTargets = targets
    end

    State.harpoonAttempted = true
    State.comboAttemptTime = now
    CastHarpoonStep(activeTargets, harpoon)
end

--#endregion

return Script
