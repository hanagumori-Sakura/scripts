--[[
    Auto Unsleep
    Wake Nightmared units with controllable attackers; enemy wake only for Bane save.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local UPDATE_INTERVAL = 0.08
local ORDER_GAP = 0.40
local ORDER_ID = "auto_unsleep.attack"
local DEFAULT_RADIUS = 1600

local STATE_DISARMED = 1 -- MODIFIER_STATE_DISARMED
local STATE_NIGHTMARED = 11 -- MODIFIER_STATE_NIGHTMARED
local TEAM_BOTH = 2 -- Enum.TeamType.TEAM_BOTH

local MOD_BANE_NIGHTMARE = "modifier_bane_nightmare"

local ICON_AUTO_UNSLEEP = "\u{e38d}"
local ICON_SELF = "\u{f007}"
local ICON_ALLIES = "\u{f0c0}"
local ICON_ENEMIES = "\u{f6db}"
local ICON_RADIUS = "\u{f002}"
--#endregion

--#region State
---@class AutoUnsleepUI
---@field enabled CMenuSwitch|nil
---@field selfSwitch CMenuSwitch|nil
---@field allies CMenuSwitch|nil
---@field enemies CMenuSwitch|nil
---@field searchRadius CMenuSliderInt|nil
local UI = {
    enabled = nil,
    selfSwitch = nil,
    allies = nil,
    enemies = nil,
    searchRadius = nil,
}

local Runtime = {
    lastUpdateAt = -math.huge,
    ---@type table<integer, number>
    wakeIssuedAt = {},
}
--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.wakeIssuedAt = {}
end

local function OnEnabledChanged(widget)
    if widget:Get() ~= true then
        ResetRuntime()
    end
end

local function IsNightmared(npc)
    return NPC.HasState(npc, STATE_NIGHTMARED) == true
end

local function IsEnemyBaneNightmare(npc, myTeam)
    local mod = NPC.GetModifier(npc, MOD_BANE_NIGHTMARE)
    if not mod then
        return false
    end

    local caster = Modifier.GetCaster(mod)
    if not caster or Entity.IsAlive(caster) ~= true then
        return false
    end

    return Entity.GetTeamNum(caster) ~= myTeam
end

local function IsValidAttacker(npc, playerId, target, me)
    if npc == me or npc == target then
        return false
    end
    if NPC.IsControllableByPlayer(npc, playerId) ~= true then
        return false
    end
    if Entity.IsAlive(npc) ~= true then
        return false
    end
    if NPC.IsCourier(npc) == true then
        return false
    end
    if NPC.IsHero(npc) == true and NPC.IsIllusion(npc) ~= true then
        return false
    end
    if IsNightmared(npc) then
        return false
    end
    if NPC.HasState(npc, STATE_DISARMED) == true then
        return false
    end
    return true
end

local function AttackerScore(npc, target, targetPos)
    local distSqr = Entity.GetAbsOrigin(npc):DistanceSqr2D(targetPos)
    local range = NPC.GetAttackRange(npc) + NPC.GetAttackRangeBonus(npc)
        + NPC.GetHullRadius(npc) + NPC.GetHullRadius(target)
    if distSqr <= range * range then
        return distSqr - 1e12
    end
    return distSqr
end

local function PickAttacker(playerId, target, me, origin, radius)
    local targetPos = Entity.GetAbsOrigin(target)
    local radiusSqr = radius * radius
    local units = NPCs.GetAll()
    local best = nil
    local bestScore = math.huge

    for i = 1, #units do
        local npc = units[i]
        if IsValidAttacker(npc, playerId, target, me)
            and Entity.GetAbsOrigin(npc):DistanceSqr2D(origin) <= radiusSqr
        then
            local score = AttackerScore(npc, target, targetPos)
            if score < bestScore then
                bestScore = score
                best = npc
            end
        end
    end

    return best
end

local function PickTarget(me, myTeam, origin, radius, wantSelf, wantAllies, wantEnemies)
    if wantSelf and IsNightmared(me) then
        return me
    end
    if not wantAllies and not wantEnemies then
        return nil
    end

    local heroes = Heroes.InRadius(origin, radius, myTeam, TEAM_BOTH, false, true)
    local best = nil
    local bestDist = math.huge

    for i = 1, #heroes do
        local hero = heroes[i]
        if hero ~= me and Entity.IsAlive(hero) == true and IsNightmared(hero) then
            local ok = false
            if Entity.GetTeamNum(hero) == myTeam then
                ok = wantAllies
            elseif wantEnemies then
                ok = IsEnemyBaneNightmare(hero, myTeam)
            end

            if ok then
                local dist = Entity.GetAbsOrigin(hero):DistanceSqr2D(origin)
                if dist < bestDist then
                    bestDist = dist
                    best = hero
                end
            end
        end
    end

    return best
end

local function UpdateFeature(me, now)
    local wantSelf = UI.selfSwitch:Get() == true
    local wantAllies = UI.allies:Get() == true
    local wantEnemies = UI.enemies:Get() == true
    if not wantSelf and not wantAllies and not wantEnemies then
        return
    end

    if not IsNightmared(me) then
        Runtime.wakeIssuedAt[Entity.GetIndex(me)] = nil
    end

    local player = Players.GetLocal()
    if not player then
        return
    end

    local playerId = Player.GetPlayerID(player)
    if playerId < 0 then
        return
    end

    local radius = UI.searchRadius:Get()
    local myTeam = Entity.GetTeamNum(me)
    local origin = Entity.GetAbsOrigin(me)
    local target = PickTarget(me, myTeam, origin, radius, wantSelf, wantAllies, wantEnemies)
    if not target then
        return
    end

    local targetIndex = Entity.GetIndex(target)
    local lastIssued = Runtime.wakeIssuedAt[targetIndex]
    if lastIssued and now - lastIssued < ORDER_GAP then
        return
    end

    local attacker = PickAttacker(playerId, target, me, origin, radius)
    if not attacker then
        return
    end

    Player.AttackTarget(player, attacker, target, false, true, false, ORDER_ID, false)
    Runtime.wakeIssuedAt[targetIndex] = now
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    local group = Menu.Create("Heroes", "", "Settings", "General", "Units Controller")
    UI.enabled = group:Switch("AutoUnsleep", true, ICON_AUTO_UNSLEEP)
    UI.enabled:SetCallback(OnEnabledChanged, false)

    local gear = UI.enabled:Gear("Settings")
    UI.selfSwitch = gear:Switch("Self", true, ICON_SELF)
    UI.allies = gear:Switch("Allies", true, ICON_ALLIES)
    UI.enemies = gear:Switch("Enemies (Bane save)", true, ICON_ENEMIES)
    UI.searchRadius = gear:Slider("Search Radius", 600, 3000, DEFAULT_RADIUS)
    UI.searchRadius:Icon(ICON_RADIUS)
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

    UpdateFeature(me, now)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
