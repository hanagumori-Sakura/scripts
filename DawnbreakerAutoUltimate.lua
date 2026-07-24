--[[
    Dawnbreaker Auto Ultimate
    Auto-cast Solar Guardian for ally saves and fight turns.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "DawnbreakerAutoUltimate"
local UPDATE_INTERVAL = 0.10
local CAST_COOLDOWN = 0.75
local CAMERA_LEAD = 0.20

local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_SECOND = "Dawnbreaker"
local MENU_THIRD = "Main Settings"
local MENU_GROUP = "Auto Ultimate"

local HERO_NAME = "npc_dota_hero_dawnbreaker"
local ABILITY_ULT = "dawnbreaker_solar_guardian"
local ORDER_ID = "dawnbreaker_auto_ultimate.cast"

-- Enum.modifierState is nil in runtime 1.2.3; values match Enums.lua stub.
local STATE_MUTED = 4
local STATE_HEXED = 6

local ICON_ENABLE = "\u{f00c}"
local ICON_ALLY_HP = "\u{f004}"
local ICON_MIN_SAVE = "\u{f0c0}"
local ICON_MIN_FIGHT = "\u{f6de}"
local ICON_FIGHT_RADIUS = "\u{f140}"
local ICON_CANCEL = "\u{f071}"
local ICON_SKIP = "\u{f70c}"
local ICON_CAMERA = "\u{f03d}"

local LOC = {
    en = {
        group = "Auto Ultimate",
        enable = "Enable",
        enableTip = "Auto-cast Solar Guardian when an ally needs a save or a fight is worth joining.",
        settings = "Settings",
        moveCamera = "Move Camera",
        moveCameraTip = "Pan the camera to the cast point shortly before casting.",
        allyHp = "Ally HP %",
        allyHpTip = "Save trigger: ally health percent must be at or below this value.",
        saveEnemies = "Save Enemies",
        saveEnemiesTip = "Save trigger: minimum enemy heroes near the ally.",
        fightEnemies = "Fight Enemies",
        fightEnemiesTip = "Fight trigger: minimum enemy heroes near an ally (no HP gate).",
        fightRadius = "Fight Radius",
        fightRadiusTip = "Radius around the ally used to count enemy heroes.",
        cancelDanger = "Cancel Danger",
        cancelDangerTip = "Do not cast if an enemy hero is within this range of Dawnbreaker (channel interrupt risk).",
        skipNear = "Skip Near Fight",
        skipNearTip = "Do not ult if Dawnbreaker is already this close to the chosen ally.",
    },
    ru = {
        group = "Авто ульт",
        enable = "Включить",
        enableTip = "Автокаст Solar Guardian: сейв союзника или вход в выгодный файт.",
        settings = "Настройки",
        moveCamera = "Камера",
        moveCameraTip = "Перед кастом переносит камеру на точку ульты.",
        allyHp = "HP союзника %",
        allyHpTip = "Сейв: HP союзника должно быть не выше этого процента.",
        saveEnemies = "Враги (сейв)",
        saveEnemiesTip = "Сейв: минимум вражеских героев рядом с союзником.",
        fightEnemies = "Враги (файт)",
        fightEnemiesTip = "Файт: минимум вражеских героев рядом с союзником (без порога HP).",
        fightRadius = "Радиус файла",
        fightRadiusTip = "Радиус вокруг союзника для подсчёта вражеских героев.",
        cancelDanger = "Опасность срыва",
        cancelDangerTip = "Не кастовать, если вражеский герой в этом радиусе от Dawnbreaker (риск срыва канала).",
        skipNear = "Уже рядом",
        skipNearTip = "Не ультовать, если Dawnbreaker уже близко к выбранному союзнику.",
    },
    cn = {
        group = "自动大招",
        enable = "启用",
        enableTip = "自动施放太阳守卫：救援队友或加入有利团战。",
        settings = "设置",
        moveCamera = "移动镜头",
        moveCameraTip = "施法前将镜头移到大招落点。",
        allyHp = "队友血量%",
        allyHpTip = "救援条件：队友生命值不高于该百分比。",
        saveEnemies = "救援敌人数",
        saveEnemiesTip = "救援条件：队友附近最少敌方英雄数。",
        fightEnemies = "团战敌人数",
        fightEnemiesTip = "团战条件：队友附近最少敌方英雄数（无血量门槛）。",
        fightRadius = "战斗半径",
        fightRadiusTip = "统计敌方英雄时以队友为中心的半径。",
        cancelDanger = "打断危险",
        cancelDangerTip = "破晓者附近有敌方英雄时不施放（避免引导被打断）。",
        skipNear = "已在附近",
        skipNearTip = "若破晓者已接近所选队友则不大招。",
    },
}
--#endregion

--#region State
---@class DawnbreakerAutoUltimateUI
---@field group CMenuGroup|nil
---@field gear CMenuGearAttachment|nil
---@field enabled CMenuSwitch|nil
---@field moveCamera CMenuSwitch|nil
---@field allyHpThreshold CMenuSliderInt|nil
---@field minEnemiesNearAlly CMenuSliderInt|nil
---@field minEnemiesForFight CMenuSliderInt|nil
---@field fightRadius CMenuSliderInt|nil
---@field cancelDangerRadius CMenuSliderInt|nil
---@field skipIfNearFight CMenuSliderInt|nil
local UI = {}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type CMenuComboBox|nil
    langWidget = nil,
    localeKey = "",
}

local Runtime = {
    lastUpdateAt = -math.huge,
    lastCastAt = -math.huge,
    pendingCastAt = nil,
    ---@type Vector|nil
    pendingPos = nil,
}
--#endregion

--#region Locale
local function LocaleKeyFromCode(code)
    if not code then
        return "en"
    end
    local s = string.lower(tostring(code))
    if s == "ru" or s == "russian" or string.find(s, "рус", 1, true) then
        return "ru"
    end
    if s == "cn" or s == "zh" or s == "schinese" or s == "tchinese"
        or string.find(s, "chinese", 1, true) or string.find(s, "中", 1, true)
    then
        return "cn"
    end
    return "en"
end

local function ReadMenuLanguageCode()
    local widget = Persistent.langWidget
    if widget then
        local idx = widget:Get()
        local list = widget:List()
        if type(idx) == "number" and list then
            local item = list[idx + 1]
            if item ~= nil and item ~= "" then
                return item
            end
        end
    end
    return Steam.GetGameLanguage()
end

local function ApplyLabel(widget, label, tip)
    widget:ForceLocalization(label)
    widget:ToolTip(tip)
end

local function ApplyMenuLocale()
    local key = LocaleKeyFromCode(ReadMenuLanguageCode())
    if key == Persistent.localeKey then
        return
    end
    Persistent.localeKey = key

    local L = LOC[key] or LOC.en
    UI.group:ForceLocalization(L.group)
    UI.gear:ForceLocalization(L.settings)
    ApplyLabel(UI.enabled, L.enable, L.enableTip)
    ApplyLabel(UI.moveCamera, L.moveCamera, L.moveCameraTip)
    ApplyLabel(UI.allyHpThreshold, L.allyHp, L.allyHpTip)
    ApplyLabel(UI.minEnemiesNearAlly, L.saveEnemies, L.saveEnemiesTip)
    ApplyLabel(UI.minEnemiesForFight, L.fightEnemies, L.fightEnemiesTip)
    ApplyLabel(UI.fightRadius, L.fightRadius, L.fightRadiusTip)
    ApplyLabel(UI.cancelDangerRadius, L.cancelDanger, L.cancelDangerTip)
    ApplyLabel(UI.skipIfNearFight, L.skipNear, L.skipNearTip)
end

local function OnMenuLanguageChanged()
    Persistent.localeKey = ""
    ApplyMenuLocale()
end
--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastCastAt = -math.huge
    Runtime.pendingCastAt = nil
    Runtime.pendingPos = nil
end

local function ClearPending()
    Runtime.pendingCastAt = nil
    Runtime.pendingPos = nil
end

local function OnEnabledChanged(widget)
    if not widget:Get() then
        ResetRuntime()
    end
end

local function IsLocalUnsafe(me)
    return NPC.IsStunned(me) == true
        or NPC.IsSilenced(me) == true
        or NPC.HasState(me, STATE_HEXED) == true
        or NPC.HasState(me, STATE_MUTED) == true
        or NPC.IsChannellingAbility(me) == true
end

local function CountEnemyHeroesNear(pos, radius, teamNum)
    return #Heroes.InRadius(pos, radius, teamNum, Enum.TeamType.TEAM_ENEMY, true, true)
end

local function AllyHpPercent(ally)
    local maxHealth = Entity.GetMaxHealth(ally)
    if maxHealth <= 0 then
        return 100
    end
    return (Entity.GetHealth(ally) / maxHealth) * 100
end

local function FindBestAlly(me, teamNum, allyHpThreshold, minEnemiesNearAlly, minEnemiesForFight, fightRadius)
    local bestAlly = nil
    local bestIsSave = false
    local bestEnemyCount = -1
    local bestHpPercent = 101

    local heroes = Heroes.GetAll()
    for i = 1, #heroes do
        local ally = heroes[i]
        if ally ~= me
            and Entity.IsAlive(ally) == true
            and Entity.GetTeamNum(ally) == teamNum
            and NPC.IsIllusion(ally) ~= true
            and Entity.IsDormant(ally) ~= true
        then
            local enemyCount = CountEnemyHeroesNear(Entity.GetAbsOrigin(ally), fightRadius, teamNum)
            local hpPercent = AllyHpPercent(ally)
            local isSave = hpPercent <= allyHpThreshold and enemyCount >= minEnemiesNearAlly
            local isFight = enemyCount >= minEnemiesForFight

            if isSave or isFight then
                local better = bestAlly == nil
                    or (isSave and not bestIsSave)
                    or (isSave == bestIsSave and (
                        enemyCount > bestEnemyCount
                        or (enemyCount == bestEnemyCount and hpPercent < bestHpPercent)
                    ))

                if better then
                    bestAlly = ally
                    bestIsSave = isSave
                    bestEnemyCount = enemyCount
                    bestHpPercent = hpPercent
                end
            end
        end
    end

    return bestAlly
end

local function IsUltReady(me, ult)
    if Ability.IsCastable(ult, NPC.GetMana(me)) ~= true then
        return false
    end
    if IsLocalUnsafe(me) then
        return false
    end
    return true
end

local function CastUltAt(ult, pos, now)
    Ability.CastPosition(ult, pos, false, true, false, ORDER_ID, false)
    Runtime.lastCastAt = now
    ClearPending()
end

local function FinishPendingCast(me, now)
    local ult = NPC.GetAbility(me, ABILITY_ULT)
    local pos = Runtime.pendingPos
    if not ult or not pos or IsUltReady(me, ult) ~= true then
        ClearPending()
        return
    end

    local teamNum = Entity.GetTeamNum(me)
    if CountEnemyHeroesNear(Entity.GetAbsOrigin(me), UI.cancelDangerRadius:Get(), teamNum) >= 1 then
        ClearPending()
        return
    end

    CastUltAt(ult, pos, now)
end

local function TryCastUlt(me, now)
    if Runtime.pendingCastAt ~= nil then
        if now >= Runtime.pendingCastAt then
            FinishPendingCast(me, now)
        end
        return
    end

    local ult = NPC.GetAbility(me, ABILITY_ULT)
    if not ult or IsUltReady(me, ult) ~= true then
        return
    end

    local teamNum = Entity.GetTeamNum(me)
    local mePos = Entity.GetAbsOrigin(me)
    if CountEnemyHeroesNear(mePos, UI.cancelDangerRadius:Get(), teamNum) >= 1 then
        return
    end

    local ally = FindBestAlly(
        me,
        teamNum,
        UI.allyHpThreshold:Get(),
        UI.minEnemiesNearAlly:Get(),
        UI.minEnemiesForFight:Get(),
        UI.fightRadius:Get()
    )
    if not ally then
        return
    end

    local x, y, z = Entity.GetAbsOriginXYZ(ally)
    local allyPos = Vector(x, y, z)
    local skipRange = UI.skipIfNearFight:Get()
    if mePos:DistanceSqr2D(allyPos) <= skipRange * skipRange then
        return
    end

    if UI.moveCamera:Get() == true then
        Engine.LookAt(x, y)
        Runtime.pendingPos = allyPos
        Runtime.pendingCastAt = now + CAMERA_LEAD
        Runtime.lastCastAt = now
        return
    end

    CastUltAt(ult, allyPos, now)
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    Persistent.langWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    if Persistent.langWidget then
        Persistent.langWidget:SetCallback(OnMenuLanguageChanged, false)
    end

    UI.group = Menu.Create(MENU_FIRST, MENU_SECTION, MENU_SECOND, MENU_THIRD, MENU_GROUP)

    UI.enabled = UI.group:Switch("Enable", true)
    UI.enabled:Icon(ICON_ENABLE)
    UI.enabled:SetCallback(OnEnabledChanged, false)

    UI.gear = UI.enabled:Gear("Settings")
    UI.moveCamera = UI.gear:Switch("Move Camera", true, ICON_CAMERA)

    UI.allyHpThreshold = UI.group:Slider("Ally HP %", 5, 100, 45)
    UI.allyHpThreshold:Icon(ICON_ALLY_HP)

    UI.minEnemiesNearAlly = UI.group:Slider("Save Enemies", 1, 5, 1)
    UI.minEnemiesNearAlly:Icon(ICON_MIN_SAVE)

    UI.minEnemiesForFight = UI.group:Slider("Fight Enemies", 1, 5, 2)
    UI.minEnemiesForFight:Icon(ICON_MIN_FIGHT)

    UI.fightRadius = UI.gear:Slider("Fight Radius", 300, 1200, 700)
    UI.fightRadius:Icon(ICON_FIGHT_RADIUS)

    UI.cancelDangerRadius = UI.gear:Slider("Cancel Danger", 200, 2000, 900)
    UI.cancelDangerRadius:Icon(ICON_CANCEL)

    UI.skipIfNearFight = UI.gear:Slider("Skip Near Fight", 400, 3000, 1200)
    UI.skipIfNearFight:Icon(ICON_SKIP)

    ApplyMenuLocale()
    Persistent.logger:info("loaded")
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Input.IsInputCaptured() then
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    if Entity.GetUnitName(me) ~= HERO_NAME then
        return
    end
    if Runtime.pendingCastAt == nil and now - Runtime.lastCastAt < CAST_COOLDOWN then
        return
    end

    TryCastUlt(me, now)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
