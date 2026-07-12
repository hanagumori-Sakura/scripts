--[[
    Kez Raptor Dance Dodge
    Last-moment dodge with kez_raptor_dance invuln (0.2s) via cast-phase + flight ETA.
--]]

local Script = {}

--#region Constants

local LOG_PREFIX = "[KezDodge] "
local HERO_NAME = "npc_dota_hero_kez"
local ABILITY_RAPTOR = "kez_raptor_dance"
local CONFIG_SECTION = "kez_dodge"
local ORDER_ID = "kez_dodge:raptor"
local THREAT_CONFIG_PREFIX = "threat_"

local DEFAULT_INVULN = 0.2
local CAST_QUIET = 1.00
---Order latency floor when NetChannel is silent / tiny.
local LATENCY_FLOOR = 0.030
---Want invuln already up this long before impact (after order delay).
local INVULN_LEAD = 0.090
---Half-width around the ideal last-moment ETA.
local WINDOW_HALF = 0.035
---Flight/delayed: small pad on decision ETA (Assassinate also has etaBias).
local FLIGHT_ETA_PAD = 0.018
local MIN_CAST_WINDOW = 0.045
local ROSTER_SYNC_INTERVAL = 1.0
local DEBUG_INTERVAL = 2.0
local DEBUG_MIN_GAP = 0.75
local RANGE_PAD = 175
local FLIGHT_KEEP = 2.5

---Active items that cover magical nukes/disables — save Raptor CD when ready.
local COVER_ITEMS = {
    "item_black_king_bar",
    "item_minotaur_horn",
}
local BKB_ACTIVE_MOD = "modifier_black_king_bar_immune"

local ABILITY_CAST_READY = Enum.AbilityCastResult.READY
local FLOW_INCOMING = Enum.Flow.FLOW_INCOMING
local FLOW_OUTGOING = Enum.Flow.FLOW_OUTGOING
local MODIFIER_STATE = Enum.ModifierState

local Icons = {
    enable = "\u{f00c}",
    gear = "\u{f013}",
    bug = "\u{f188}",
    versus = "\u{f71d}",
}

--[[
  Cover only what 0.2s invuln can time: fixed-delay nukes / ground effects, phase nukes, Assassinate flight.
  No Impale/hex/Echo Slam (instant or travel-stun after invuln).
  kind:
    phase   - cast-phase poll; optional speedSpecial → post-cast flight ETA
    delayed - cast-phase + impactDelaySpecial / defaultImpactDelay
]]
local THREATS = {
    -- Delayed nukes / ground effects (fixed delay after cast commit)
    { id = "lion_finger_of_death", label = "Lion: Finger of Death", kind = "delayed", default = true,
        impactDelaySpecial = "damage_delay", defaultImpactDelay = 0.25 },
    { id = "lina_laguna_blade", label = "Lina: Laguna Blade", kind = "delayed", default = true,
        impactDelaySpecial = "damage_delay", defaultImpactDelay = 0.25 },
    { id = "lina_light_strike_array", label = "Lina: Light Strike Array", kind = "delayed", default = true,
        impactDelaySpecial = "light_strike_array_delay_time", defaultImpactDelay = 0.5,
        radiusSpecial = "light_strike_array_aoe", defaultRadius = 225 },
    { id = "techies_suicide", label = "Techies: Blast Off!", kind = "delayed", default = true,
        impactDelaySpecial = "duration", defaultImpactDelay = 0.75,
        radiusSpecial = "radius", defaultRadius = 400 },
    { id = "invoker_sun_strike", label = "Invoker: Sun Strike", kind = "delayed", default = true,
        impactDelaySpecial = "delay", defaultImpactDelay = 1.7,
        radiusSpecial = "area_of_effect", defaultRadius = 175, rangeOverride = 12000,
        -- Pure: BKB/Horn do not cover — still use Raptor.
        piercesMagicImmune = true },
    { id = "kunkka_torrent", label = "Kunkka: Torrent", kind = "delayed", default = true,
        impactDelaySpecial = "delay", defaultImpactDelay = 1.6,
        radiusSpecial = "radius", defaultRadius = 250 },
    { id = "leshrac_split_earth", label = "Leshrac: Split Earth", kind = "delayed", default = true,
        impactDelaySpecial = "delay", defaultImpactDelay = 0.35,
        radiusSpecial = "radius", defaultRadius = 190 },
    { id = "warlock_rain_of_chaos", label = "Warlock: Chaotic Offering", kind = "delayed", default = true,
        impactDelaySpecial = "stun_delay", defaultImpactDelay = 0.5,
        radiusSpecial = "aoe", defaultRadius = 600 },
    { id = "pugna_nether_blast", label = "Pugna: Nether Blast", kind = "delayed", default = true,
        impactDelaySpecial = "delay", defaultImpactDelay = 0.8,
        radiusSpecial = "radius", defaultRadius = 400 },
    { id = "gyrocopter_call_down", label = "Gyrocopter: Call Down", kind = "delayed", default = true,
        impactDelaySpecial = "strike_delay", defaultImpactDelay = 1.0,
        radiusSpecial = "radius", defaultRadius = 400 },

    -- Phase nukes / RP (confirmed or magical without hard travel-stun)
    { id = "antimage_mana_void", label = "Anti-Mage: Mana Void", kind = "phase", default = true },
    { id = "magnataur_reverse_polarity", label = "Magnus: Reverse Polarity", kind = "phase", default = true },
    { id = "queenofpain_sonic_wave", label = "QoP: Sonic Wave", kind = "phase", default = true },
    { id = "zuus_thundergods_wrath", label = "Zeus: Thundergod's Wrath", kind = "phase", default = true },
    { id = "zuus_lightning_bolt", label = "Zeus: Lightning Bolt", kind = "phase", default = true },
    { id = "obsidian_destroyer_sanity_eclipse", label = "OD: Sanity's Eclipse", kind = "phase", default = true,
        hero = "obsidian_destroyer" },
    { id = "lina_dragon_slave", label = "Lina: Dragon Slave", kind = "phase", default = true },
    { id = "sniper_assassinate", label = "Sniper: Assassinate", kind = "phase", default = true,
        speedSpecial = "projectile_speed", defaultSpeed = 2500,
        -- Prefer earlier press: Dist/speed after late phase-end still runs hot.
        etaBias = -0.035 },
}

local THREAT_BY_ID = {}
for _, t in ipairs(THREATS) do
    THREAT_BY_ID[t.id] = t
end

--#endregion

--#region State

local UI = {
    Enabled = nil,
    ThreatSelect = nil,
    PreferItems = nil,
    Debug = nil,
    ready = false,
}

local Runtime = {
    threatPrefs = {},
    lastRosterKey = "",
    lastRosterSyncAt = -math.huge,
    lastDebugAt = -math.huge,
    lastDebugMessage = "",
    quietUntil = -math.huge,
    ---@type { id: string, at: number }|nil
    pendingCast = nil,
    ---@type table<string, table>
    pending = {},
}

--#endregion

--#region Helpers

---@generic T
---@param fn fun(...):T
---@param ... any
---@return boolean
---@return T|string
local function TryCall(fn, ...)
    if type(fn) ~= "function" then
        return false, "not callable"
    end
    return pcall(fn, ...)
end

---@generic T
---@param fn fun(...): T
---@param ... any
---@return T|nil
local function SafeValue(fn, ...)
    local ok, value = TryCall(fn, ...)
    if not ok then
        return nil
    end
    return value
end

local function AsTable(value)
    if type(value) == "table" then
        return value
    end
    return nil
end

local function AsNumber(value, fallback)
    if type(value) == "number" then
        return value
    end
    return fallback
end

local function ResetRuntime()
    Runtime.lastRosterKey = ""
    Runtime.lastRosterSyncAt = -math.huge
    Runtime.lastDebugAt = -math.huge
    Runtime.lastDebugMessage = ""
    Runtime.quietUntil = -math.huge
    Runtime.pendingCast = nil
    Runtime.pending = {}
end

local function QuietUntil()
    return Runtime.quietUntil or -math.huge
end

local function SetQuietUntil(untilTime)
    Runtime.quietUntil = untilTime
end

---force: always emit once (CAST), but still dedupe identical lines within a short window.
local function LogLine(force, fmt, ...)
    if not UI.Debug or not UI.Debug:Get() then
        return
    end
    local now = SafeValue(GameRules.GetGameTime) or 0
    local message = string.format(fmt, ...)
    local elapsed = now - Runtime.lastDebugAt
    if force then
        if message == Runtime.lastDebugMessage and elapsed < 0.20 then
            return
        end
    else
        if message == Runtime.lastDebugMessage and elapsed < DEBUG_INTERVAL then
            return
        end
        if elapsed < DEBUG_MIN_GAP then
            return
        end
    end
    Runtime.lastDebugAt = now
    Runtime.lastDebugMessage = message
    local line = LOG_PREFIX .. message
    -- Only one sink: Log.Write and print both land in debug.log.
    if Log and Log.Write then
        TryCall(Log.Write, line)
    else
        print(line)
    end
end

local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
    return (b - a):Length2D()
end

local function ThreatIcon(id)
    return "panorama/images/spellicons/" .. tostring(id) .. "_png.vtex_c"
end

local function ThreatHero(threat)
    if threat.hero then
        return threat.hero
    end
    -- Multi-word hero internal names before first underscore of ability id.
    if threat.id:sub(1, 19) == "obsidian_destroyer_" then
        return "obsidian_destroyer"
    end
    local us = threat.id:find("_", 1, true)
    if us then
        return threat.id:sub(1, us - 1)
    end
    return nil
end

local function IsEnemyHero(me, hero)
    if not me or not hero or hero == me then
        return false
    end
    if SafeValue(NPC.IsIllusion, hero) then
        return false
    end
    return SafeValue(Entity.IsSameTeam, me, hero) == false
end

local function EnemyHeroSet(me)
    local set = {}
    local heroes = AsTable(SafeValue(Heroes.GetAll)) or {}
    for _, hero in pairs(heroes) do
        if IsEnemyHero(me, hero) then
            local name = SafeValue(NPC.GetUnitName, hero) or ""
            local internal = name:gsub("^npc_dota_hero_", "")
            if internal ~= "" then
                set[internal] = true
            end
        end
    end
    return set
end

local function RosterKey(set)
    local keys = {}
    for name in pairs(set or {}) do
        keys[#keys + 1] = name
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function ThreatInMatch(threat, enemies)
    if not enemies then
        return true
    end
    local hero = ThreatHero(threat)
    if not hero then
        return true
    end
    return enemies[hero] == true
end

local function LoadThreatPrefs()
    Runtime.threatPrefs = {}
    for _, threat in ipairs(THREATS) do
        local stored = SafeValue(Config.ReadInt, CONFIG_SECTION, THREAT_CONFIG_PREFIX .. threat.id, -1)
        if type(stored) == "number" and stored >= 0 then
            Runtime.threatPrefs[threat.id] = stored == 1
        end
    end
end

local function SaveThreatPref(id, enabled)
    Runtime.threatPrefs[id] = enabled == true
    TryCall(Config.WriteInt, CONFIG_SECTION, THREAT_CONFIG_PREFIX .. id, enabled and 1 or 0)
end

local function IsThreatEnabled(id)
    if Runtime.threatPrefs[id] ~= nil then
        return Runtime.threatPrefs[id] == true
    end
    local widget = UI.ThreatSelect
    if widget and widget.Get then
        local value = SafeValue(widget.Get, widget, id)
        if value ~= nil then
            return value == true
        end
    end
    local threat = THREAT_BY_ID[id]
    return threat and threat.default == true
end

local function SyncThreatPrefsFromWidget()
    local widget = UI.ThreatSelect
    if not widget or not widget.Get then
        return
    end
    local listed = widget.List and AsTable(SafeValue(widget.List, widget))
    if listed then
        for _, id in ipairs(listed) do
            local value = SafeValue(widget.Get, widget, id)
            if value ~= nil then
                SaveThreatPref(id, value == true)
            end
        end
        return
    end
    for _, threat in ipairs(THREATS) do
        local value = SafeValue(widget.Get, widget, threat.id)
        if value ~= nil then
            SaveThreatPref(threat.id, value == true)
        end
    end
end

local function BuildThreatItems(enemies)
    local items = {}
    for _, threat in ipairs(THREATS) do
        if ThreatInMatch(threat, enemies) then
            local enabled = Runtime.threatPrefs[threat.id]
            if enabled == nil then
                enabled = threat.default == true
            end
            items[#items + 1] = { threat.id, ThreatIcon(threat.id), enabled }
        end
    end
    return items
end

local function ApplyPrefsToWidget(widget)
    if not widget or not widget.Set or not widget.List then
        return
    end
    local listed = AsTable(SafeValue(widget.List, widget))
    if not listed then
        return
    end
    for _, id in ipairs(listed) do
        if Runtime.threatPrefs[id] ~= nil then
            TryCall(widget.Set, widget, id, Runtime.threatPrefs[id] == true)
        end
    end
end

local function RefreshThreatSelect(me, save)
    local widget = UI.ThreatSelect
    if not widget or not widget.Update then
        return
    end
    local enemies = EnemyHeroSet(me)
    local key = RosterKey(enemies)
    if key == Runtime.lastRosterKey then
        return
    end
    Runtime.lastRosterKey = key
    SyncThreatPrefsFromWidget()
    local items = BuildThreatItems(enemies)
    if #items == 0 then
        return
    end
    TryCall(widget.Update, widget, items, false, save == true)
    ApplyPrefsToWidget(widget)
end

local function ReadBool(key, default)
    return SafeValue(Config.ReadInt, CONFIG_SECTION, key, default and 1 or 0) ~= 0
end

local function WriteBool(key, value)
    TryCall(Config.WriteInt, CONFIG_SECTION, key, value and 1 or 0)
end

--#endregion

--#region Context / castability

---@return userdata|nil
local function GetLocalKez()
    ---@type userdata|nil
    local me = SafeValue(Heroes.GetLocal)
    if not me then
        return nil
    end
    if SafeValue(NPC.GetUnitName, me) ~= HERO_NAME then
        return nil
    end
    if not SafeValue(Entity.IsAlive, me) then
        return nil
    end
    return me
end

---@param me userdata
---@return boolean
local function CanAct(me)
    if SafeValue(NPC.IsStunned, me) then
        return false
    end
    if SafeValue(NPC.HasState, me, MODIFIER_STATE.MODIFIER_STATE_HEXED) then
        return false
    end
    if SafeValue(NPC.HasState, me, MODIFIER_STATE.MODIFIER_STATE_COMMAND_RESTRICTED) then
        return false
    end
    if SafeValue(NPC.HasState, me, MODIFIER_STATE.MODIFIER_STATE_FEARED) then
        return false
    end
    return true
end

---@param me userdata
---@return boolean
local function IsInvulnerable(me)
    return SafeValue(NPC.HasState, me, MODIFIER_STATE.MODIFIER_STATE_INVULNERABLE) == true
end

---@param item userdata|nil
---@return boolean
local function IsItemCastable(item)
    if not item then
        return false
    end
    local exec = SafeValue(Ability.CanBeExecuted, item)
    if exec ~= nil and exec ~= ABILITY_CAST_READY then
        return false
    end
    if SafeValue(Ability.IsReady, item) == false then
        return false
    end
    if SafeValue(Ability.IsOwnersManaEnough, item) == false then
        return false
    end
    if SafeValue(Ability.IsInAbilityPhase, item) then
        return false
    end
    return true
end

---BKB / Horn (ready or already active) cover magical threats — skip Raptor.
---Pure (Sun Strike) still needs invuln.
---@param me userdata
---@param threatId string|nil
---@return boolean, string|nil
local function HasMagicImmuneCover(me, threatId)
    if UI.PreferItems and UI.PreferItems.Get and not UI.PreferItems:Get() then
        return false, nil
    end
    local threat = threatId and THREAT_BY_ID[threatId]
    if threat and threat.piercesMagicImmune then
        return false, nil
    end
    if SafeValue(NPC.HasState, me, MODIFIER_STATE.MODIFIER_STATE_MAGIC_IMMUNE) == true then
        return true, "magic_immune"
    end
    if SafeValue(NPC.HasModifier, me, BKB_ACTIVE_MOD) == true then
        return true, "bkb_active"
    end
    for i = 1, #COVER_ITEMS do
        local id = COVER_ITEMS[i]
        local item = SafeValue(NPC.GetItem, me, id, true)
        if IsItemCastable(item) then
            return true, id
        end
    end
    return false, nil
end

local function GetRaptor(me)
    return SafeValue(NPC.GetAbility, me, ABILITY_RAPTOR)
end

local function IsRaptorReady(me, ability)
    if not ability then
        return false, "missing"
    end
    if (SafeValue(Ability.GetLevel, ability) or 0) <= 0 then
        return false, "unlearned_or_sai"
    end
    local exec = SafeValue(Ability.CanBeExecuted, ability)
    if exec ~= nil and exec ~= ABILITY_CAST_READY then
        return false, "exec=" .. tostring(exec)
    end
    if SafeValue(Ability.IsReady, ability) == false then
        return false, "cd"
    end
    if SafeValue(Ability.IsOwnersManaEnough, ability) == false then
        return false, "mana"
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) then
        return false, "casting"
    end
    return true, "ok"
end

local function InvulnPeriod(ability)
    local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, "invuln_period")
    if type(value) == "number" and value > 0 then
        return value
    end
    return DEFAULT_INVULN
end

local function LatencySeconds(flow)
    local ping = SafeValue(NetChannel.GetAvgLatency, flow)
    if type(ping) ~= "number" or ping < 0 then
        ping = SafeValue(NetChannel.GetLatency, flow)
    end
    if type(ping) ~= "number" or ping < 0 then
        return 0
    end
    return ping
end

local function RawOutPing()
    return LatencySeconds(FLOW_OUTGOING)
end

local function RawInPing()
    return LatencySeconds(FLOW_INCOMING)
end

local function PingUnknown()
    -- Tiny positive values still mean "no real ping" in demo/local.
    return (RawOutPing() + RawInPing()) < 0.008
end

local function OutPingSeconds()
    if PingUnknown() then
        return LATENCY_FLOOR
    end
    local out = RawOutPing()
    if out < 0.010 then
        return 0.010
    end
    return out
end

local function InPingSeconds()
    if PingUnknown() then
        return LATENCY_FLOOR
    end
    return RawInPing()
end

---Ideal remaining time to impact when we press ult (last-moment).
---Invuln is only 0.2s — press so it covers the impact frame itself.
local function IdealEta()
    return OutPingSeconds() + INVULN_LEAD
end

local function MinEta()
    local minEta = IdealEta() - WINDOW_HALF
    if minEta < 0.018 then
        minEta = 0.018
    end
    return minEta
end

local function MaxEta(invuln)
    local maxEta = IdealEta() + WINDOW_HALF
    local hardMax = OutPingSeconds() + invuln - 0.030
    if maxEta > hardMax then
        maxEta = hardMax
    end
    if maxEta < MIN_CAST_WINDOW then
        maxEta = MIN_CAST_WINDOW
    end
    if maxEta < MinEta() then
        maxEta = MinEta() + 0.010
    end
    return maxEta
end

---Decision clock for logs / window.
local function DecisionEta(eta, channel, threatId)
    if type(eta) ~= "number" then
        return nil
    end
    local pad = 0
    if channel == "flight" or channel == "delayed" then
        pad = FLIGHT_ETA_PAD
    end
    local threat = threatId and THREAT_BY_ID[threatId]
    if threat and type(threat.etaBias) == "number" then
        pad = pad + threat.etaBias
    end
    return eta + pad
end

---Raw ETA must stay above MinEta (order latency) or invuln starts after the hit.
---Flight: almost the full invuln band — Dist/speed over-reads on late phase-end detect.
local function InWindow(eta, invuln, channel, threatId)
    if type(eta) ~= "number" then
        return false
    end
    if channel == "flight" then
        local minE = OutPingSeconds() + 0.022
        local maxE = OutPingSeconds() + invuln - 0.020
        if maxE < minE + 0.040 then
            maxE = minE + 0.040
        end
        local decision = DecisionEta(eta, channel, threatId) or eta
        if eta < minE then
            return false
        end
        return decision <= maxE
    end
    local minE = MinEta()
    local maxE = MaxEta(invuln)
    local decision = DecisionEta(eta, channel, threatId) or eta
    if eta < minE then
        return false
    end
    return decision >= minE and decision <= maxE
end

local function SpecialOr(ability, special, fallback)
    if special then
        local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, special)
        if type(value) == "number" and value > 0 then
            return value
        end
    end
    return fallback
end

--#endregion

--#region Detection

local function PendingKey(caster, threatId)
    local idx = SafeValue(Entity.GetIndex, caster) or 0
    return tostring(idx) .. ":" .. threatId
end

local function GetEnemyAbility(enemy, threat)
    return SafeValue(NPC.GetAbility, enemy, threat.id)
end

local function InThreatRange(me, mePos, enemy, ability, threat)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, enemy)
    if not enemyPos then
        return false
    end
    if type(threat.rangeOverride) == "number" and threat.rangeOverride > 0 then
        return Dist2D(mePos, enemyPos) <= threat.rangeOverride
    end
    local castRange = SafeValue(Ability.GetCastRange, ability) or 0
    local radius = SpecialOr(ability, threat.radiusSpecial, threat.defaultRadius or 0)
    local check = castRange + radius + RANGE_PAD
    if check < 700 then
        check = 900
    end
    return Dist2D(mePos, enemyPos) <= check
end

local function ResolveImpactDelay(ability, threat)
    local impactDelay = threat.impactDelay or threat.defaultImpactDelay or 0
    if threat.impactDelaySpecial then
        impactDelay = SpecialOr(ability, threat.impactDelaySpecial, impactDelay)
    end
    if type(impactDelay) ~= "number" or impactDelay < 0 then
        return 0
    end
    return impactDelay
end

local function ArmPending(caster, threat, ability, now, launchAt)
    local key = PendingKey(caster, threat.id)
    Runtime.pending[key] = {
        threatId = threat.id,
        caster = caster,
        speed = SpecialOr(ability, threat.speedSpecial, threat.defaultSpeed or 0),
        impactDelay = ResolveImpactDelay(ability, threat),
        launchAt = launchAt,
        flightEta0 = nil,
        launchPos = nil,
        keepUntil = now + FLIGHT_KEEP,
    }
    return key
end

local function PhaseEta(ability, threat, mePos, enemy, now)
    local castStart = SafeValue(Ability.GetCastStartTime, ability)
    if type(castStart) ~= "number" or castStart <= 0 then
        castStart = now
    end
    local castPoint = SafeValue(Ability.GetCastPoint, ability, true)
    if type(castPoint) ~= "number" or castPoint < 0 then
        castPoint = threat.defaultCastPoint or 0
    end
    local impactDelay = ResolveImpactDelay(ability, threat)

    local remainingCast = (castStart + castPoint) - now
    if remainingCast < 0 then
        remainingCast = 0
    end

    local travel = 0
    local speed = SpecialOr(ability, threat.speedSpecial, threat.defaultSpeed or 0)
    if speed > 0 then
        local enemyPos = SafeValue(Entity.GetAbsOrigin, enemy)
        if enemyPos and mePos then
            travel = Dist2D(enemyPos, mePos) / speed
        end
    end

    -- 0-CP with no travel: imminent
    if castPoint <= 0.05 and travel <= 0 and impactDelay <= 0 then
        return 0.06
    end

    return remainingCast + impactDelay + travel
end

local function ScanPhaseThreats(me, mePos, now, invuln)
    local best = nil
    local heroes = AsTable(SafeValue(Heroes.GetAll)) or {}

    for _, enemy in pairs(heroes) do
        if IsEnemyHero(me, enemy) and SafeValue(Entity.IsAlive, enemy) then
            for _, threat in ipairs(THREATS) do
                if IsThreatEnabled(threat.id) then
                    local ability = GetEnemyAbility(enemy, threat)
                    if ability and SafeValue(Ability.IsInAbilityPhase, ability) == true then
                        if InThreatRange(me, mePos, enemy, ability, threat) then
                            local eta = PhaseEta(ability, threat, mePos, enemy, now)
                            local castPoint = AsNumber(SafeValue(Ability.GetCastPoint, ability, true), 0)
                            local castStart = AsNumber(SafeValue(Ability.GetCastStartTime, ability), now)
                            ArmPending(enemy, threat, ability, now, castStart + math.max(0, castPoint))
                            local speed = SpecialOr(ability, threat.speedSpecial, threat.defaultSpeed or 0)
                            local impactDelay = ResolveImpactDelay(ability, threat)
                            -- Projectiles / delayed damage: wait until cast commits.
                            local waitCommit = speed > 0 or threat.kind == "delayed" or impactDelay > 0
                            if not waitCommit and InWindow(eta, invuln, "phase", threat.id) then
                                if not best or eta < best.eta then
                                    best = { id = threat.id, eta = eta, channel = "phase" }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Continue flight / delayed ETA after cast point.
    for key, pending in pairs(Runtime.pending) do
        if now > pending.keepUntil then
            Runtime.pending[key] = nil
        else
            local ability = pending.caster and GetEnemyAbility(pending.caster, THREAT_BY_ID[pending.threatId] or { id = pending.threatId })
            local stillPhase = ability and SafeValue(Ability.IsInAbilityPhase, ability) == true
            if not stillPhase then
                if pending.speed and pending.speed > 0 then
                    -- Keep planned cast-end as launchAt. Resetting to `now` on late
                    -- phase-end detection overstates ETA (Assassinate hit before Raptor).
                    if not pending.flightCommitted then
                        pending.flightCommitted = true
                        local planned = pending.launchAt
                        if type(planned) ~= "number" or planned <= 0 or planned > now + 0.05 then
                            pending.launchAt = now
                        end
                        pending.launchPos = SafeValue(Entity.GetAbsOrigin, pending.caster)
                        if pending.launchPos and mePos and pending.speed > 0 then
                            pending.flightEta0 = Dist2D(pending.launchPos, mePos) / pending.speed
                        end
                    end
                    if pending.flightEta0 and pending.launchAt then
                        local eta = pending.flightEta0 - (now - pending.launchAt)
                        local enabled = IsThreatEnabled(pending.threatId)
                        local hit = enabled and InWindow(eta, invuln, "flight", pending.threatId)
                        -- Last chance: frame skipped the band but order can still land.
                        if enabled and not hit and not pending.lastChance
                            and type(eta) == "number"
                            and eta > 0
                            and eta < (OutPingSeconds() + 0.022)
                            and eta >= (OutPingSeconds() + 0.010)
                        then
                            pending.lastChance = true
                            hit = true
                        end
                        if hit then
                            if not best or eta < best.eta then
                                best = { id = pending.threatId, eta = eta, channel = "flight" }
                            end
                        elseif type(eta) == "number" and eta < -0.1 then
                            Runtime.pending[key] = nil
                        end
                    end
                elseif type(pending.impactDelay) == "number" and pending.impactDelay > 0 then
                    if type(pending.launchAt) ~= "number" then
                        pending.launchAt = now
                    end
                    local eta = (pending.launchAt + pending.impactDelay) - now
                    if InWindow(eta, invuln, "delayed", pending.threatId) and IsThreatEnabled(pending.threatId) then
                        if not best or eta < best.eta then
                            best = { id = pending.threatId, eta = eta, channel = "delayed" }
                        end
                    elseif type(eta) == "number" and eta < -0.1 then
                        Runtime.pending[key] = nil
                    end
                end
            end
        end
    end

    return best
end

local function FindBestThreat(me, raptor, now)
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    if not mePos then
        return nil
    end
    local invuln = InvulnPeriod(raptor)
    local best = ScanPhaseThreats(me, mePos, now, invuln)
    return best, invuln, MaxEta(invuln)
end

--#endregion

--#region Cast

local function ClearThreatPending(threatId)
    for key, pending in pairs(Runtime.pending) do
        if pending and pending.threatId == threatId then
            Runtime.pending[key] = nil
        end
    end
end

local function CastRaptor(ability, threat, now)
    -- Lock immediately so a second OnUpdate / duplicate load cannot double-cast.
    if now < QuietUntil() then
        return false
    end
    local ready = IsRaptorReady(nil, ability)
    if not ready then
        return false
    end
    -- Short anti-spam only; keep pending so a rejected order can retry in-window.
    SetQuietUntil(now + 0.12)
    Runtime.pendingCast = { id = threat.id, at = now }
    TryCall(Ability.CastNoTarget, ability, false, true, true, ORDER_ID)
    local invuln = InvulnPeriod(ability)
    local decision = DecisionEta(threat.eta, threat.channel, threat.id)
    local minE = (threat.channel == "flight") and (OutPingSeconds() + 0.022) or MinEta()
    local maxE = (threat.channel == "flight") and (OutPingSeconds() + invuln - 0.020) or MaxEta(invuln)
    LogLine(true, "CAST %s via %s eta=%.3f dec=%.3f ideal=%.3f window=[%.3f,%.3f] ping=%.0f/%.0f",
        threat.id,
        threat.channel,
        threat.eta or -1,
        decision or -1,
        IdealEta(),
        minE,
        maxE,
        OutPingSeconds() * 1000,
        InPingSeconds() * 1000
    )
    return true
end

--#endregion

--#region Menu

local function EnsureMenu()
    if UI.ready then
        return
    end

    local main = Menu.Find("Heroes", "Hero List", "Kez", "Main Settings")
    local group = main and main.Create and main:Create("Dodge")
    if not group then
        group = Menu.Create("Scripts", "Heroes", "Kez Dodge", "Main", "Dodge")
    end
    if not group then
        return
    end

    UI.Enabled = group:Switch("Enable Kez Dodge", ReadBool("enabled", true), Icons.enable)
    UI.Enabled:SetCallback(function(widget)
        WriteBool("enabled", widget:Get())
        if not widget:Get() then
            ResetRuntime()
        end
    end, false)

    LoadThreatPrefs()
    UI.ThreatSelect = group:MultiSelect("Abilities to Dodge (reliable)", BuildThreatItems(nil), false)
    ApplyPrefsToWidget(UI.ThreatSelect)
    if UI.ThreatSelect.SetCallback then
        UI.ThreatSelect:SetCallback(SyncThreatPrefsFromWidget, false)
    end
    if UI.ThreatSelect.Icon then
        TryCall(UI.ThreatSelect.Icon, UI.ThreatSelect, Icons.versus)
    end

    local gear = UI.Enabled:Gear("Dodge Settings", Icons.gear)
    if gear then
        UI.PreferItems = gear:Switch("Skip Ult if BKB/Horn Ready", ReadBool("prefer_items", true), Icons.enable)
        UI.PreferItems:SetCallback(function(widget)
            WriteBool("prefer_items", widget:Get())
        end, false)
        UI.Debug = gear:Switch("Enable Debug Logs", ReadBool("debug", false), Icons.bug)
        UI.Debug:SetCallback(function(widget)
            WriteBool("debug", widget:Get())
        end, false)
    end

    UI.ready = true
end

--#endregion

--#region Update

local function CountPending()
    local n = 0
    for _ in pairs(Runtime.pending) do
        n = n + 1
    end
    return n
end

local function SamplePendingEta(now)
    for _, pending in pairs(Runtime.pending) do
        if pending and pending.threatId then
            local eta = -1
            if pending.flightEta0 and pending.launchAt then
                eta = pending.flightEta0 - (now - pending.launchAt)
            elseif type(pending.impactDelay) == "number" and pending.impactDelay > 0 and pending.launchAt then
                eta = (pending.launchAt + pending.impactDelay) - now
            elseif pending.launchAt then
                eta = pending.launchAt - now
            end
            return pending.threatId, eta
        end
    end
    return "-", -1
end

local function UpdateDodge(now)
    local me = GetLocalKez()
    if not me then
        return
    end

    if now - Runtime.lastRosterSyncAt >= ROSTER_SYNC_INTERVAL then
        Runtime.lastRosterSyncAt = now
        RefreshThreatSelect(me, true)
    end

    local pendingN = CountPending()
    if not CanAct(me) then
        if pendingN > 0 then
            LogLine(false, "skip: cannot act")
        end
        return
    end
    if now < QuietUntil() then
        return
    end

    local raptor = GetRaptor(me)
    local ready, reason = IsRaptorReady(me, raptor)

    -- Confirm prior CAST: Raptor accepted → long quiet + drop that threat.
    if Runtime.pendingCast then
        local age = now - (Runtime.pendingCast.at or now)
        if IsInvulnerable(me) or (not ready and reason ~= "missing" and reason ~= "unlearned_or_sai") then
            ClearThreatPending(Runtime.pendingCast.id)
            SetQuietUntil(now + CAST_QUIET)
            Runtime.pendingCast = nil
            return
        end
        if age >= 0.35 then
            Runtime.pendingCast = nil
        end
    end

    if IsInvulnerable(me) then
        return
    end

    if not ready then
        if pendingN > 0 then
            LogLine(false, "skip: raptor (%s)", tostring(reason))
        end
        return
    end

    local threat, invuln, maxEta = FindBestThreat(me, raptor, now)
    if not threat then
        pendingN = CountPending()
        if pendingN > 0 then
            local inv = invuln or DEFAULT_INVULN
            local sampleId, sampleEta = SamplePendingEta(now)
            LogLine(
                false,
                "armed %s eta=%.3f invuln=%.2f window=[%.3f,%.3f] pending=%d",
                sampleId,
                sampleEta or -1,
                inv,
                MinEta(),
                maxEta or MaxEta(inv),
                pendingN
            )
        end
        return
    end

    local covered, coverId = HasMagicImmuneCover(me, threat.id)
    if covered then
        LogLine(false, "skip: cover %s vs %s", tostring(coverId), threat.id)
        ClearThreatPending(threat.id)
        return
    end

    CastRaptor(raptor, threat, now)
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    EnsureMenu()
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    EnsureMenu()
    if not UI.Enabled or not UI.Enabled:Get() then
        return
    end

    local now = SafeValue(GameRules.GetGameTime)
    if type(now) ~= "number" then
        return
    end
    UpdateDodge(now)
end

function Script.OnUnitAnimation(
    data,
    unit,
    sequenceVariant,
    playbackRate,
    castpoint,
    animType,
    activity,
    sequence,
    sequenceName,
    lag_compensation_time
)
    local me = GetLocalKez()
    if not me or not unit or not IsEnemyHero(me, unit) then
        return
    end
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local unitPos = SafeValue(Entity.GetAbsOrigin, unit)
    if not mePos or not unitPos or Dist2D(mePos, unitPos) > 1800 then
        return
    end

    local ability = activity and SafeValue(NPC.GetAbilityByActivity, unit, activity) or nil
    if not ability then
        return
    end
    local name = SafeValue(Ability.GetName, ability)
    local threat = name and THREAT_BY_ID[name]
    if not threat or not IsThreatEnabled(name) then
        return
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) ~= true then
        return
    end
    local now = SafeValue(GameRules.GetGameTime) or 0
    local eta = PhaseEta(ability, threat, mePos, unit, now)
    ArmPending(unit, threat, ability, now, now + math.max(0, castpoint or 0))
    LogLine(true, "anim phase %s eta=%.3f", name, eta or -1)
end

function Script.OnGameEnd()
    ResetRuntime()
end

--#endregion

return Script
