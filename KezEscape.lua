--[[
    Kez Full Escape
    Hold Escape Key: flee toward own fountain with Katana W → Q → Sai R
    plus Blink / Force / Pike / Eul, with automatic stance switching.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local NAME = "KezEscape"
local CONFIG_SECTION = "kez_escape"
local HERO_NAME = "npc_dota_hero_kez"
local ORDER_PREFIX = "kez.escape."

local ABILITY_SWITCH = "kez_switch_weapons"
local ABILITY_CLAW = "kez_grappling_claw"
local ABILITY_ECHO = "kez_echo_slash"
local ABILITY_VEIL = "kez_ravens_veil"
local ABILITY_TALON = "kez_talon_toss"
local ABILITY_RUSH = "kez_falcon_rush"
local ABILITY_RAPTOR = "kez_raptor_dance"

local FOUNTAIN_RADIANT = "npc_dota_goodguys_fountain"
local FOUNTAIN_DIRE = "npc_dota_badguys_fountain"

-- Classic map fountain anchors used only if entity scan fails.
local FALLBACK_FOUNTAIN = {
    [Enum.TeamNum.TEAM_RADIANT] = Vector(-6816, -6368, 512),
    [Enum.TeamNum.TEAM_DIRE] = Vector(6752, 6112, 512),
}

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local FORCE_ITEMS = {
    "item_force_staff",
    "item_hurricane_pike",
}

local EUL_ITEMS = {
    "item_wind_waker",
    "item_cyclone",
}

local UPDATE_INTERVAL = 0.05
local CAST_QUIET = 0.20
local SWITCH_QUIET = 0.22
local MOVE_INTERVAL = 0.22
local FACE_MAX_TURN = 0.08
local MIN_BLINK_DIST = 50
local BLINK_RANGE_FALLBACK = 1200
local BLINK_RANGE_MARGIN = 20
local CLAW_RANGE_FALLBACK = 650
local CLAW_MIN_RANGE_FRAC = 0.70
local FOUNTAIN_RESYNC = 5.0
local MIN_FOUNTAIN_DOT = 0.25
local CONFIRM_WAIT = 0.65
local SWITCH_CONFIRM_WAIT = 1.00
local MAX_CAST_RETRIES = 3
local BLACKLIST_SEC = 4.0
local PATH_STEP = 275
local PATH_LOOKAHEAD = 700
local GRID_FLAG = 0x1
local GRID_EXCLUDED = 0x002
local BAD_ANCHOR_SEC = 4.0

local ABILITY_CAST_READY = Enum.AbilityCastResult.READY
local ABILITY_CAST_HIDDEN = Enum.AbilityCastResult.HIDDEN
local ABILITY_CAST_CD = Enum.AbilityCastResult.ABILITY_CD
local TEAM_ENEMY = Enum.TeamType.TEAM_ENEMY
local ORDER_CAST_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local ORDER_CAST_TREE = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET_TREE
local ORDER_CAST_NO_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
local ORDER_ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

local MOD_KATANA = "modifier_kez_katana"
local MOD_SAI = "modifier_kez_sai"
local MOD_EUL_CYCLONE = "modifier_eul_cyclone"
local MOD_WIND_WAKER = "modifier_wind_waker"

-- Runtime Enum often lacks modifierState (AntiMage note). Values match Enum.modifierState stubs.
local STATE_ROOTED = 0
local STATE_HEXED = 6
local STATE_INVISIBLE = 7
local STATE_COMMAND_RESTRICTED = 20

local Icons = {
    enable = "\u{f00c}",
    bind = "\u{f11c}",
    gear = "\u{f013}",
    bug = "\u{f188}",
    abilities = "\u{f890}",
    items = "\u{e196}",
}

--#endregion

--#region State

---@class KezEscapeUI
---@field enabled CMenuSwitch|nil
---@field escapeKey CMenuBind|nil
---@field abilities CMenuMultiSelect|nil
---@field items CMenuMultiSelect|nil
---@field debug CMenuSwitch|nil
---@field ready boolean
local UI = {
    enabled = nil,
    escapeKey = nil,
    abilities = nil,
    items = nil,
    debug = nil,
    ready = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
}

local Runtime = {
    lastUpdateAt = -math.huge,
    quietUntil = -math.huge,
    lastMoveAt = -math.huge,
    lastDebugAt = -math.huge,
    ---@type Vector|nil
    fountainPos = nil,
    fountainTeam = nil,
    fountainScanAt = -math.huge,
    pendingSwitchTo = nil,
    pendingSwitchAt = -math.huge,
    lastAction = nil,
    veilCastAt = -math.huge,
    keyWasDown = false,
    ---@type { tag: string, abilityName: string, issuedAt: number, cdBefore: number, wantStance?: string, anchorIdx?: integer, anchorKind?: string }|nil
    pendingCast = nil,
    ---@type table<string, number>
    blacklistUntil = {},
    ---@type table<string, number>
    failCounts = {},
    ---@type table<integer, number>
    badAnchors = {},
    ---@type string @ "katana" | "sai" | "finish"
    escapePhase = "katana",
}

--#endregion

--#region Helpers

---@generic T
---@param fn fun(...): T
---@param ... any
---@return boolean ok
---@return T|string ...
local function TryCall(fn, ...)
    if type(fn) ~= "function" then
        return false, "expected a callable function"
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

local function ResetEscapeSession()
    Runtime.quietUntil = -math.huge
    Runtime.pendingSwitchTo = nil
    Runtime.pendingSwitchAt = -math.huge
    Runtime.lastAction = nil
    Runtime.pendingCast = nil
    Runtime.blacklistUntil = {}
    Runtime.failCounts = {}
    Runtime.badAnchors = {}
    Runtime.escapePhase = "katana"
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastMoveAt = -math.huge
    Runtime.lastDebugAt = -math.huge
    Runtime.fountainPos = nil
    Runtime.fountainTeam = nil
    Runtime.fountainScanAt = -math.huge
    Runtime.veilCastAt = -math.huge
    Runtime.keyWasDown = false
    ResetEscapeSession()
end

---@param tag string
---@return string
local function OrderId(tag)
    return ORDER_PREFIX .. tag
end

---@param identifier any
---@return boolean
local function IsOurOrder(identifier)
    return type(identifier) == "string" and identifier:sub(1, #ORDER_PREFIX) == ORDER_PREFIX
end

local function ReadBool(key, defaultOn)
    return Config.ReadInt(CONFIG_SECTION, key, defaultOn and 1 or 0) ~= 0
end

local function WriteBool(key, value)
    Config.WriteInt(CONFIG_SECTION, key, value and 1 or 0)
end

---@param widget { Icon?: fun(self: any, icon: string), Image?: fun(self: any, path: string) }|nil
---@param icon string
local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        TryCall(widget.Icon, widget, icon)
    end
end

---@param widget { Image?: fun(self: any, path: string) }|nil
---@param imagePath string
local function MenuImage(widget, imagePath)
    if widget and widget.Image then
        TryCall(widget.Image, widget, imagePath)
    end
end

local ABILITY_USAGE = {
    { id = "kez_grappling_claw", config = "use_claw", image = "panorama/images/spellicons/kez_grappling_claw_png.vtex_c", default = true },
    { id = "kez_echo_slash", config = "use_echo", image = "panorama/images/spellicons/kez_echo_slash_png.vtex_c", default = true },
    { id = "kez_ravens_veil", config = "use_veil", image = "panorama/images/spellicons/kez_ravens_veil_png.vtex_c", default = true },
}

local ITEM_USAGE = {
    { id = "item_blink", config = "use_blink", image = "panorama/images/items/blink_png.vtex_c", default = true },
    { id = "item_force_staff", config = "use_force", image = "panorama/images/items/force_staff_png.vtex_c", default = true },
    { id = "item_wind_waker", config = "use_eul", image = "panorama/images/items/wind_waker_png.vtex_c", default = true },
}

local USAGE_ID = {
    claw = "kez_grappling_claw",
    echo = "kez_echo_slash",
    veil = "kez_ravens_veil",
    blink = "item_blink",
    force = "item_force_staff",
    eul = "item_wind_waker",
}

---@param entries { id: string, config: string, image: string, default: boolean }[]
---@return table[]
local function BuildUsageMultiSelectItems(entries)
    local items = {}
    for i = 1, #entries do
        local e = entries[i]
        items[#items + 1] = {
            e.id,
            e.image,
            ReadBool(e.config, e.default),
        }
    end
    return items
end

---@param widget CMenuMultiSelect|nil
---@param entries { id: string, config: string }[]
local function SyncUsagePrefsFromWidget(widget, entries)
    if not widget or not widget.Get then
        return
    end
    for i = 1, #entries do
        local e = entries[i]
        WriteBool(e.config, widget:Get(e.id) == true)
    end
end

---@param id string @ short key: claw|echo|veil|blink|force|eul
---@return boolean
local function UsageEnabled(id)
    local nameId = USAGE_ID[id] or id
    if id == "claw" or id == "echo" or id == "veil" then
        if not UI.abilities or not UI.abilities.Get then
            return true
        end
        return UI.abilities:Get(nameId) == true
    end
    if not UI.items or not UI.items.Get then
        return true
    end
    return UI.items:Get(nameId) == true
end

---@param fmt string
---@param ... any
local function DebugLog(fmt, ...)
    if not UI.debug or not UI.debug:Get() then
        return
    end
    local now = SafeValue(GameRules.GetGameTime) or 0
    if now - Runtime.lastDebugAt < 0.35 then
        return
    end
    Runtime.lastDebugAt = now
    local msg = string.format(fmt, ...)
    if Persistent.logger then
        Persistent.logger:info(msg)
    else
        print("[" .. NAME .. "] " .. msg)
    end
end

---@param now number
---@return boolean
local function InQuiet(now)
    return now < Runtime.quietUntil
end

---@param now number
---@param duration number
local function SetQuiet(now, duration)
    Runtime.quietUntil = now + duration
end

---@param me userdata|nil
---@return boolean
local function IsLocalKez(me)
    return me ~= nil
        and SafeValue(NPC.GetUnitName, me) == HERO_NAME
        and SafeValue(Entity.IsAlive, me) == true
end

---@param me userdata
---@return boolean
local function IsHardLocked(me)
    if SafeValue(NPC.IsStunned, me) == true then
        return true
    end
    if SafeValue(NPC.HasState, me, STATE_HEXED) == true then
        return true
    end
    if SafeValue(NPC.HasState, me, STATE_COMMAND_RESTRICTED) == true then
        return true
    end
    return false
end

---@param me userdata
---@return boolean
local function IsRooted(me)
    return SafeValue(NPC.HasState, me, STATE_ROOTED) == true
end

---@param me userdata
---@return boolean
local function IsSilenced(me)
    return SafeValue(NPC.IsSilenced, me) == true
end

---@param me userdata
---@return boolean
local function IsInvisible(me)
    return SafeValue(NPC.HasState, me, STATE_INVISIBLE) == true
end

---@param me userdata
---@return boolean
local function IsWindWakerActive(me)
    return SafeValue(NPC.HasModifier, me, MOD_WIND_WAKER) == true
        or SafeValue(NPC.HasModifier, me, MOD_EUL_CYCLONE) == true
end

---@param widget any
---@return boolean
local function BindHeld(widget)
    if not widget or type(widget.IsDown) ~= "function" then
        return false
    end
    return SafeValue(widget.IsDown, widget) == true
end

---@param a Vector
---@param b Vector
---@return number
local function Dist2D(a, b)
    if a.Distance2D then
        local d = a:Distance2D(b)
        if type(d) == "number" then
            return d
        end
    end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

---@param from Vector
---@param to Vector
---@return number, number, number @dx, dy, len
local function Dir2D(from, to)
    local dx = (to.x or 0) - (from.x or 0)
    local dy = (to.y or 0) - (from.y or 0)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

---@param me userdata
---@param ability userdata|nil
---@param fallback number
---@return number
local function GetCastRange(me, ability, fallback)
    local base = fallback
    if ability then
        local range = SafeValue(Ability.GetCastRange, ability)
        if type(range) == "number" and range > 0 then
            base = range
        end
    end
    local bonus = SafeValue(NPC.GetCastRangeBonus, me) or 0
    return base + bonus
end

---@param tag string
---@param now number
---@return boolean
local function IsBlacklisted(tag, now)
    local untilAt = Runtime.blacklistUntil[tag]
    return type(untilAt) == "number" and now < untilAt
end

---@param tag string
---@param now number
local function Blacklist(tag, now)
    Runtime.blacklistUntil[tag] = now + BLACKLIST_SEC
    Runtime.failCounts[tag] = 0
    DebugLog("blacklist %s for %.2fs", tag, BLACKLIST_SEC)
end

---@param tag string
---@param now number
local function NoteCastFail(tag, now)
    local n = (Runtime.failCounts[tag] or 0) + 1
    Runtime.failCounts[tag] = n
    DebugLog("fail %s (%d/%d)", tag, n, MAX_CAST_RETRIES)
    if n >= MAX_CAST_RETRIES then
        Blacklist(tag, now)
    end
end

---@param tag string
local function NoteCastOk(tag)
    Runtime.failCounts[tag] = 0
    if tag == "veil" then
        Runtime.escapePhase = "finish"
        DebugLog("phase -> finish (veil)")
    end
end

---@param ability userdata|nil
---@return number
local function ReadCooldown(ability)
    if not ability then
        return 0
    end
    local cd = SafeValue(Ability.GetCooldown, ability)
    if type(cd) == "number" and cd > 0 then
        return cd
    end
    return 0
end

---@param tag string
---@param abilityName string
---@param ability userdata
---@param now number
---@param extra? { wantStance?: string, anchorIdx?: integer, anchorKind?: string }
local function BeginPendingCast(tag, abilityName, ability, now, extra)
    Runtime.pendingCast = {
        tag = tag,
        abilityName = abilityName,
        issuedAt = now,
        cdBefore = ReadCooldown(ability),
        wantStance = extra and extra.wantStance or nil,
        anchorIdx = extra and extra.anchorIdx or nil,
        anchorKind = extra and extra.anchorKind or nil,
    }
    SetQuiet(now, CAST_QUIET)
    Runtime.lastAction = tag
end

-- Forward declare for PollPendingCast (defined in Stance region).
local GetStance

---Returns true while waiting on a pending cast (caller should not issue new actions).
---@param me userdata
---@param now number
---@return boolean waiting
local function PollPendingCast(me, now)
    local pending = Runtime.pendingCast
    if not pending then
        return false
    end

    local waitLimit = pending.tag == "switch" and SWITCH_CONFIRM_WAIT or CONFIRM_WAIT

    if pending.tag == "switch" then
        local want = pending.wantStance or Runtime.pendingSwitchTo
        local stanceNow = GetStance and GetStance(me) or "unknown"

        local claw = SafeValue(NPC.GetAbility, me, ABILITY_CLAW)
        local veil = SafeValue(NPC.GetAbility, me, ABILITY_VEIL)
        local clawExec = claw and SafeValue(Ability.CanBeExecuted, claw)
        local veilExec = veil and SafeValue(Ability.CanBeExecuted, veil)
        local clawHidden = claw and SafeValue(Ability.IsHidden, claw) == true
        local veilHidden = veil and SafeValue(Ability.IsHidden, veil) == true

        local flipped = false
        if want == "sai" then
            local veilLearned = veil ~= nil and (SafeValue(Ability.GetLevel, veil) or 0) > 0
            flipped = clawHidden == true
                or clawExec == ABILITY_CAST_HIDDEN
                or (veilHidden == false and veilLearned)
                or (veilExec ~= nil and veilExec ~= ABILITY_CAST_HIDDEN and veilLearned)
        elseif want == "katana" then
            local clawLearned = claw ~= nil and (SafeValue(Ability.GetLevel, claw) or 0) > 0
            flipped = clawHidden == false
                or (clawExec ~= nil and clawExec ~= ABILITY_CAST_HIDDEN and clawLearned)
                or veilHidden == true
                or veilExec == ABILITY_CAST_HIDDEN
        end

        if (want and stanceNow == want) or flipped then
            DebugLog("confirm switch want=%s stance=%s flipped=%s", tostring(want), stanceNow, tostring(flipped))
            NoteCastOk("switch")
            Runtime.pendingCast = nil
            Runtime.pendingSwitchTo = nil
            return false
        end

        local switchAb = SafeValue(NPC.GetAbility, me, ABILITY_SWITCH)
        local cd = ReadCooldown(switchAb)
        -- CD alone is not enough (weapon casts refresh switch CD), but helps with logging.
        if now - pending.issuedAt < waitLimit then
            return true
        end

        DebugLog(
            "switch timeout want=%s got=%s clawExec=%s veilExec=%s clawHid=%s cd=%.2f",
            tostring(want),
            stanceNow,
            tostring(clawExec),
            tostring(veilExec),
            tostring(clawHidden),
            cd
        )
        NoteCastFail("switch", now)
        Runtime.pendingCast = nil
        Runtime.pendingSwitchTo = nil
        return false
    end

    local ab = SafeValue(NPC.GetAbility, me, pending.abilityName)
        or SafeValue(NPC.GetItem, me, pending.abilityName, true)
    local cd = ReadCooldown(ab)
    local ready = ab and SafeValue(Ability.IsReady, ab)
    local inPhase = ab and SafeValue(Ability.IsInAbilityPhase, ab) == true

    if inPhase then
        return true
    end

    if cd > pending.cdBefore + 0.05 or ready == false then
        DebugLog("confirm %s cd=%.2f", pending.tag, cd)
        NoteCastOk(pending.tag)
        Runtime.pendingCast = nil
        return false
    end

    if now - pending.issuedAt < waitLimit then
        return true
    end

    if pending.anchorIdx then
        Runtime.badAnchors[pending.anchorIdx] = now + BAD_ANCHOR_SEC
    end
    NoteCastFail(pending.tag, now)
    Runtime.pendingCast = nil
    return false
end

--#endregion

--#region Pathing

---@param pos Vector|nil
---@return boolean
local function IsWorldTraversable(pos)
    if not pos then
        return false
    end
    if not GridNav or not GridNav.IsTraversable then
        return true
    end
    local ok, result = TryCall(GridNav.IsTraversable, pos, GRID_FLAG, GRID_EXCLUDED)
    if ok then
        return result == true
    end
    return true
end

---@param from Vector|nil
---@param to Vector|nil
---@return boolean
local function IsPathClear(from, to)
    if not from or not to then
        return false
    end
    if not GridNav then
        return true
    end
    if GridNav.IsTraversableFromTo then
        local ok, result = TryCall(GridNav.IsTraversableFromTo, from, to, false, nil)
        if ok then
            return result == true
        end
    end
    return IsWorldTraversable(to)
end

---@param from Vector
---@param to Vector
---@param maxDist number
---@return Vector
local function FindWalkTarget(from, to, maxDist)
    if GridNav and GridNav.BuildPath then
        local path = SafeValue(GridNav.BuildPath, from, to, false, nil)
        if type(path) == "table" and #path >= 2 then
            local budget = math.min(maxDist, PATH_LOOKAHEAD)
            local traveled = 0
            local prev = path[1]
            for i = 2, #path do
                local node = path[i]
                if prev and node then
                    local seg = Dist2D(prev, node)
                    if traveled + seg >= budget then
                        local need = budget - traveled
                        if seg > 1 and need > 0 then
                            local nx, ny = Dir2D(prev, node)
                            return Vector(prev.x + nx * need, prev.y + ny * need, prev.z or from.z)
                        end
                        return node
                    end
                    traveled = traveled + seg
                    prev = node
                end
            end
            return path[#path]
        end
    end

    local fx, fy, dist = Dir2D(from, to)
    if dist < 1 then
        return to
    end

    local best = nil
    local bestDist = 0
    local limit = math.min(maxDist, dist)
    for d = PATH_STEP, limit, PATH_STEP do
        local candidate = Vector(from.x + fx * d, from.y + fy * d, from.z)
        if IsWorldTraversable(candidate) and IsPathClear(from, candidate) then
            best = candidate
            bestDist = d
        else
            break
        end
    end
    if best then
        return best
    end

    -- Side offsets when forward is blocked.
    local px, py = -fy, fx
    for _, side in ipairs({ 120, -120, 220, -220, 340, -340 }) do
        for d = PATH_STEP, limit, PATH_STEP do
            local candidate = Vector(
                from.x + fx * d + px * side,
                from.y + fy * d + py * side,
                from.z
            )
            if IsWorldTraversable(candidate) and IsPathClear(from, candidate) then
                return candidate
            end
        end
    end

    return best or to
end

---@param from Vector
---@param fountainPos Vector
---@param blinkRange number
---@return Vector|nil
local function FindBlinkPos(from, fountainPos, blinkRange)
    local fx, fy, dist = Dir2D(from, fountainPos)
    if dist < MIN_BLINK_DIST then
        return nil
    end

    local ideal = math.min(blinkRange - BLINK_RANGE_MARGIN, dist)
    ideal = math.max(ideal, MIN_BLINK_DIST)

    local function tryAt(distAlong, side)
        local px, py = -fy, fx
        local pos = Vector(
            from.x + fx * distAlong + px * side,
            from.y + fy * distAlong + py * side,
            from.z
        )
        if IsWorldTraversable(pos) and IsPathClear(from, pos) then
            return pos
        end
        return nil
    end

    for _, side in ipairs({ 0, 80, -80, 160, -160, 240, -240 }) do
        for shrink = 0, 4 do
            local d = ideal - shrink * 80
            if d >= MIN_BLINK_DIST then
                local pos = tryAt(d, side)
                if pos then
                    return pos
                end
            end
        end
    end

    return nil
end

--#endregion

--#region Fountain

---@param me userdata
---@param now number
---@return Vector|nil
local function ResolveFountainPos(me, now)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not team then
        return nil
    end

    if Runtime.fountainPos
        and Runtime.fountainTeam == team
        and now - Runtime.fountainScanAt < FOUNTAIN_RESYNC
    then
        return Runtime.fountainPos
    end

    Runtime.fountainScanAt = now
    Runtime.fountainTeam = team

    local wantName = team == Enum.TeamNum.TEAM_DIRE and FOUNTAIN_DIRE or FOUNTAIN_RADIANT
    local npcs = SafeValue(NPCs.GetAll) or {}
    for i = 1, #npcs do
        local npc = npcs[i]
        if npc and SafeValue(NPC.GetUnitName, npc) == wantName then
            local pos = SafeValue(Entity.GetAbsOrigin, npc)
            if pos then
                Runtime.fountainPos = pos
                return pos
            end
        end
    end

    local fallback = FALLBACK_FOUNTAIN[team]
    if fallback then
        Runtime.fountainPos = fallback
        return fallback
    end

    return Runtime.fountainPos
end

--#endregion

--#region Stance / Ability readiness

---@param ability userdata|nil
---@return boolean
local function AbilityLearned(ability)
    return ability ~= nil and (SafeValue(Ability.GetLevel, ability) or 0) > 0
end

---@param ability userdata|nil
---@return boolean
local function AbilityVisible(ability)
    return ability ~= nil and SafeValue(Ability.IsHidden, ability) ~= true
end

---@param me userdata
---@return string @ "katana" | "sai" | "unknown"
GetStance = function(me)
    -- Prefer live castability: HIDDEN means the other discipline is active.
    local claw = SafeValue(NPC.GetAbility, me, ABILITY_CLAW)
    if AbilityLearned(claw) then
        local exec = SafeValue(Ability.CanBeExecuted, claw)
        if exec == ABILITY_CAST_HIDDEN or SafeValue(Ability.IsHidden, claw) == true then
            return "sai"
        end
        if exec ~= nil then
            return "katana"
        end
    end

    local veil = SafeValue(NPC.GetAbility, me, ABILITY_VEIL)
    if AbilityLearned(veil) then
        local exec = SafeValue(Ability.CanBeExecuted, veil)
        if exec == ABILITY_CAST_HIDDEN or SafeValue(Ability.IsHidden, veil) == true then
            return "katana"
        end
        if exec ~= nil then
            return "sai"
        end
    end

    local echo = SafeValue(NPC.GetAbility, me, ABILITY_ECHO)
    local rush = SafeValue(NPC.GetAbility, me, ABILITY_RUSH)
    if AbilityLearned(echo) and AbilityVisible(echo) and not AbilityVisible(rush) then
        return "katana"
    end
    if AbilityLearned(rush) and AbilityVisible(rush) and not AbilityVisible(echo) then
        return "sai"
    end

    local hasKatana = SafeValue(NPC.HasModifier, me, MOD_KATANA) == true
    local hasSai = SafeValue(NPC.HasModifier, me, MOD_SAI) == true
    if hasKatana and not hasSai then
        return "katana"
    end
    if hasSai and not hasKatana then
        return "sai"
    end

    return "unknown"
end

---@param ability userdata|nil
---@return boolean
local function CanExecuteNow(ability)
    if not ability then
        return false
    end
    local exec = SafeValue(Ability.CanBeExecuted, ability)
    return exec == ABILITY_CAST_READY
end

---@param ability userdata|nil
---@return boolean ready
---@return string reason
local function AbilityOffCooldown(ability)
    if not ability then
        return false, "missing"
    end
    if not AbilityLearned(ability) then
        return false, "unlearned"
    end
    local exec = SafeValue(Ability.CanBeExecuted, ability)
    if exec == ABILITY_CAST_READY then
        return true, "ok"
    end
    if exec == ABILITY_CAST_CD then
        return false, "cd"
    end
    if exec == ABILITY_CAST_HIDDEN then
        if SafeValue(Ability.IsReady, ability) == false then
            return false, "cd"
        end
        if SafeValue(Ability.IsOwnersManaEnough, ability) == false then
            return false, "mana"
        end
        return true, "hidden"
    end
    if exec ~= nil then
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

---True if either linked stance form is off CD (may still need a stance switch).
---Shared-CD pairs: if either learned form is on cooldown, the pair is unavailable.
---(Hidden stance twin can still report ready while the cast form is on CD.)
---@param me userdata
---@param katanaName string
---@param saiName string
---@return boolean
local function IsPairAvailable(me, katanaName, saiName)
    local katana = SafeValue(NPC.GetAbility, me, katanaName)
    local sai = SafeValue(NPC.GetAbility, me, saiName)

    ---@param ability userdata|nil
    ---@return boolean
    local function clearlyOnCd(ability)
        if not AbilityLearned(ability) then
            return false
        end
        local exec = SafeValue(Ability.CanBeExecuted, ability)
        if exec == ABILITY_CAST_CD then
            return true
        end
        if SafeValue(Ability.IsReady, ability) == false then
            return true
        end
        local cd = SafeValue(Ability.GetCooldown, ability)
        if type(cd) == "number" and cd > 0.05 then
            return true
        end
        return false
    end

    if clearlyOnCd(katana) or clearlyOnCd(sai) then
        return false
    end

    if AbilityOffCooldown(katana) == true then
        return true
    end
    if AbilityOffCooldown(sai) == true then
        return true
    end
    return false
end

---@param me userdata
---@param switchAb userdata
---@return boolean
local function IssueSwitchCast(me, switchAb)
    local player = SafeValue(Players.GetLocal)
    if player then
        local pos = SafeValue(Entity.GetAbsOrigin, me) or Vector(0, 0, 0)
        local ok = TryCall(
            Player.PrepareUnitOrders,
            player,
            ORDER_CAST_NO_TARGET,
            nil,
            pos,
            switchAb,
            ORDER_ISSUER,
            me,
            false,
            false,
            true,
            true,
            OrderId("switch"),
            false
        )
        if ok then
            return true
        end
    end
    return TryCall(Ability.CastNoTarget, switchAb, false, true, true, OrderId("switch")) == true
end

---@param me userdata
---@param now number
---@param wantStance string
---@return string @ "ready" | "pending" | "failed"
local function EnsureStance(me, now, wantStance)
    local stance = GetStance(me)
    if stance == wantStance then
        Runtime.pendingSwitchTo = nil
        return "ready"
    end

    if Runtime.pendingSwitchTo == wantStance and now - Runtime.pendingSwitchAt < SWITCH_CONFIRM_WAIT then
        return "pending"
    end

    if IsBlacklisted("switch", now) then
        return "failed"
    end

    local switchAb = SafeValue(NPC.GetAbility, me, ABILITY_SWITCH)
    if not switchAb or not CanExecuteNow(switchAb) then
        local _, reason = AbilityOffCooldown(switchAb)
        DebugLog("switch blocked: %s (stance=%s want=%s)", tostring(reason), stance, wantStance)
        return "failed"
    end

    BeginPendingCast("switch", ABILITY_SWITCH, switchAb, now, { wantStance = wantStance })
    Runtime.pendingSwitchTo = wantStance
    Runtime.pendingSwitchAt = now
    SetQuiet(now, SWITCH_QUIET)
    if not IssueSwitchCast(me, switchAb) then
        NoteCastFail("switch", now)
        Runtime.pendingCast = nil
        Runtime.pendingSwitchTo = nil
        DebugLog("switch order failed")
        return "failed"
    end
    DebugLog("switch -> %s (was %s)", wantStance, stance)
    return "pending"
end

--#endregion

--#region Facing / Move

---@param me userdata
---@param pos Vector
---@return boolean
local function IsFacingPos(me, pos)
    local timeToFace = SafeValue(NPC.GetTimeToFacePosition, me, pos)
    if type(timeToFace) == "number" then
        return timeToFace <= FACE_MAX_TURN
    end
    return true
end

---@param me userdata
---@param fountainPos Vector
---@param now number
---@param force? boolean
local function MoveTowardFountain(me, fountainPos, now, force)
    if now - Runtime.lastMoveAt < MOVE_INTERVAL and not force then
        return
    end

    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    if not mePos then
        return
    end

    local walkTo = FindWalkTarget(mePos, fountainPos, PATH_LOOKAHEAD)
    Runtime.lastMoveAt = now
    Runtime.lastAction = "move"
    TryCall(NPC.MoveTo, me, walkTo, false, false, true, false, OrderId("move"), false)
end

---@param me userdata
---@param fountainPos Vector
---@param now number
---@return boolean @true when facing fountain
local function FaceFountain(me, fountainPos, now)
    if IsFacingPos(me, fountainPos) then
        return true
    end
    MoveTowardFountain(me, fountainPos, now, true)
    return false
end

--#endregion

--#region Targeting

---@param me userdata
---@param claw userdata
---@param mePos Vector
---@param fountainPos Vector
---@param now number
---@return userdata|nil
---@return string|nil @ "tree" | "unit"
---@return integer|nil
local function FindClawAnchor(me, claw, mePos, fountainPos, now)
    local castRange = GetCastRange(me, claw, CLAW_RANGE_FALLBACK)
    local minTreeDist = castRange * CLAW_MIN_RANGE_FRAC
    local fx, fy, flen = Dir2D(mePos, fountainPos)
    if flen < 1 then
        return nil, nil, nil
    end

    ---@type userdata|nil
    local best = nil
    local bestKind = nil
    local bestIdx = nil
    local bestScore = -math.huge

    ---@param entity userdata
    ---@param kind string
    ---@param requireLong boolean
    local function consider(entity, kind, requireLong)
        if not entity then
            return
        end
        local idx = SafeValue(Entity.GetIndex, entity)
        if type(idx) == "number" then
            local badUntil = Runtime.badAnchors[idx]
            if type(badUntil) == "number" and now < badUntil then
                return
            end
        end
        local pos = SafeValue(Entity.GetAbsOrigin, entity)
        if not pos then
            return
        end
        local dist = Dist2D(mePos, pos)
        if dist > castRange or dist < 80 then
            return
        end
        if requireLong and dist < minTreeDist then
            return
        end
        local dx, dy, len = Dir2D(mePos, pos)
        if len < 1 then
            return
        end
        local dot = dx * fx + dy * fy
        if dot < MIN_FOUNTAIN_DOT then
            return
        end
        local landOk = IsWorldTraversable(pos) and 1 or 0
        -- Max-range trees toward fountain win. Distance dominates scoring.
        local kindBonus = kind == "tree" and 50000 or 0
        local rangeScore = (dist / castRange) * 20000
        local score = kindBonus + rangeScore + landOk * 1500 + dot * 3000
        if score > bestScore then
            bestScore = score
            best = entity
            bestKind = kind
            bestIdx = type(idx) == "number" and idx or nil
        end
    end

    local trees = SafeValue(Trees.InRadius, mePos, castRange, true) or {}
    local temps = SafeValue(TempTrees.InRadius, mePos, castRange) or {}

    -- Pass 1: long-range trees only (>= 70% cast range).
    for i = 1, #trees do
        local tree = trees[i]
        if not Tree or not Tree.IsActive or SafeValue(Tree.IsActive, tree) == true then
            consider(tree, "tree", true)
        end
    end
    for i = 1, #temps do
        consider(temps[i], "tree", true)
    end

    if best then
        return best, bestKind, bestIdx
    end

    -- Pass 2: any fountain-aligned tree (still prefer farthest).
    for i = 1, #trees do
        local tree = trees[i]
        if not Tree or not Tree.IsActive or SafeValue(Tree.IsActive, tree) == true then
            consider(tree, "tree", false)
        end
    end
    for i = 1, #temps do
        consider(temps[i], "tree", false)
    end

    if best then
        return best, bestKind, bestIdx
    end

    -- Pass 3: enemy units only if no tree.
    local team = SafeValue(Entity.GetTeamNum, me)
    if team then
        local creeps = SafeValue(NPCs.InRadius, mePos, castRange, team, TEAM_ENEMY, true, true) or {}
        for i = 1, #creeps do
            local creep = creeps[i]
            if creep
                and SafeValue(Entity.IsAlive, creep) == true
                and SafeValue(NPC.IsHero, creep) ~= true
            then
                consider(creep, "unit", true)
            end
        end
        if not best then
            for i = 1, #creeps do
                local creep = creeps[i]
                if creep
                    and SafeValue(Entity.IsAlive, creep) == true
                    and SafeValue(NPC.IsHero, creep) ~= true
                then
                    consider(creep, "unit", false)
                end
            end
        end

        if not best then
            local heroes = SafeValue(Heroes.InRadius, mePos, castRange, team, TEAM_ENEMY, true, true) or {}
            for i = 1, #heroes do
                local hero = heroes[i]
                if hero and hero ~= me and SafeValue(Entity.IsAlive, hero) == true then
                    consider(hero, "unit", false)
                end
            end
        end
    end

    return best, bestKind, bestIdx
end

---@param me userdata
---@param ability userdata
---@param target userdata
---@param kind string
---@return boolean
local function IssueClawCast(me, ability, target, kind)
    if kind == "tree" then
        local player = SafeValue(Players.GetLocal)
        if not player then
            return false
        end
        local pos = SafeValue(Entity.GetAbsOrigin, target) or Vector(0, 0, 0)
        local ok = TryCall(
            Player.PrepareUnitOrders,
            player,
            ORDER_CAST_TREE,
            target,
            pos,
            ability,
            ORDER_ISSUER,
            me,
            false,
            false,
            true,
            true,
            OrderId("claw"),
            false
        )
        return ok == true
    end

    local ok = TryCall(Ability.CastTarget, ability, target, false, true, true, OrderId("claw"))
    if ok then
        return true
    end

    local player = SafeValue(Players.GetLocal)
    if not player then
        return false
    end
    local pos = SafeValue(Entity.GetAbsOrigin, target) or Vector(0, 0, 0)
    ok = TryCall(
        Player.PrepareUnitOrders,
        player,
        ORDER_CAST_TARGET,
        target,
        pos,
        ability,
        ORDER_ISSUER,
        me,
        false,
        false,
        true,
        true,
        OrderId("claw"),
        false
    )
    return ok == true
end

--#endregion

--#region Item / Ability casts

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
    if SafeValue(Ability.IsInAbilityPhase, item) then
        return false
    end
    return true
end

---@param me userdata
---@param names string[]
---@return userdata|nil
---@return string|nil
local function FindUsableItem(me, names)
    for i = 1, #names do
        local name = names[i]
        local item = SafeValue(NPC.GetItem, me, name, true)
        if IsItemCastable(item) then
            return item, name
        end
    end
    return nil, nil
end

---@param me userdata
---@param mePos Vector
---@param fountainPos Vector
---@param now number
---@return boolean
local function TryBlink(me, mePos, fountainPos, now)
    if not UsageEnabled("blink") or IsBlacklisted("blink", now) then
        return false
    end
    local blink, blinkName = FindUsableItem(me, BLINK_ITEMS)
    if not blink or not blinkName then
        return false
    end

    local range = GetCastRange(me, blink, BLINK_RANGE_FALLBACK)
    local target = FindBlinkPos(mePos, fountainPos, range)
    if not target then
        DebugLog("blink: no traversable pos")
        return false
    end

    BeginPendingCast("blink", blinkName, blink, now)
    TryCall(Ability.CastPosition, blink, target, false, true, true, OrderId("blink"), true)
    DebugLog("blink")
    return true
end

---@param stanceResult string
---@return boolean consumed
---@return boolean okToCast
local function StanceGate(stanceResult)
    if stanceResult == "ready" then
        return false, true
    end
    if stanceResult == "pending" then
        return true, false
    end
    return false, false
end

---@param me userdata
---@param mePos Vector
---@param fountainPos Vector
---@param now number
---@return boolean
local function TryClaw(me, mePos, fountainPos, now)
    if not UsageEnabled("claw") or IsBlacklisted("claw", now) then
        return false
    end
    if IsSilenced(me) or IsRooted(me) then
        return false
    end
    if not IsPairAvailable(me, ABILITY_CLAW, ABILITY_TALON) then
        return false
    end

    local consumed, okToCast = StanceGate(EnsureStance(me, now, "katana"))
    if consumed then
        return true
    end
    if not okToCast then
        return false
    end

    local castAb = SafeValue(NPC.GetAbility, me, ABILITY_CLAW)
    if not CanExecuteNow(castAb) then
        return false
    end
    ---@cast castAb userdata

    local anchor, kind, anchorIdx = FindClawAnchor(me, castAb, mePos, fountainPos, now)
    if not anchor or not kind then
        return false
    end

    BeginPendingCast("claw", ABILITY_CLAW, castAb, now, {
        anchorIdx = anchorIdx,
        anchorKind = kind,
    })
    if not IssueClawCast(me, castAb, anchor, kind) then
        if anchorIdx then
            Runtime.badAnchors[anchorIdx] = now + BAD_ANCHOR_SEC
        end
        NoteCastFail("claw", now)
        Runtime.pendingCast = nil
        return false
    end
    DebugLog("claw cast (%s)", kind)
    return true
end

---@param me userdata
---@param fountainPos Vector
---@param now number
---@return boolean
local function TryForce(me, fountainPos, now)
    if not UsageEnabled("force") or IsBlacklisted("force", now) then
        return false
    end
    if IsRooted(me) then
        return false
    end
    local item, itemName = FindUsableItem(me, FORCE_ITEMS)
    if not item or not itemName then
        return false
    end
    if not FaceFountain(me, fountainPos, now) then
        return true
    end

    BeginPendingCast("force", itemName, item, now)
    TryCall(Ability.CastTarget, item, me, false, true, true, OrderId("force"))
    DebugLog("force/pike")
    return true
end

---@param me userdata
---@param fountainPos Vector
---@param now number
---@return boolean
local function TryEcho(me, fountainPos, now)
    if not UsageEnabled("echo") or IsBlacklisted("echo", now) then
        return false
    end
    if IsSilenced(me) then
        return false
    end
    if not IsPairAvailable(me, ABILITY_ECHO, ABILITY_RUSH) then
        return false
    end

    local consumed, okToCast = StanceGate(EnsureStance(me, now, "katana"))
    if consumed then
        return true
    end
    if not okToCast then
        return false
    end

    local castAb = SafeValue(NPC.GetAbility, me, ABILITY_ECHO)
    if not CanExecuteNow(castAb) then
        return false
    end
    ---@cast castAb userdata

    if not FaceFountain(me, fountainPos, now) then
        return true
    end

    BeginPendingCast("echo", ABILITY_ECHO, castAb, now)
    TryCall(Ability.CastNoTarget, castAb, false, true, true, OrderId("echo"))
    DebugLog("echo slash")
    return true
end

---@param me userdata
---@param now number
---@return boolean
local function TryVeil(me, now)
    if not UsageEnabled("veil") or IsBlacklisted("veil", now) then
        return false
    end
    if IsSilenced(me) then
        return false
    end
    if not IsPairAvailable(me, ABILITY_RAPTOR, ABILITY_VEIL) then
        return false
    end

    local consumed, okToCast = StanceGate(EnsureStance(me, now, "sai"))
    if consumed then
        return true
    end
    if not okToCast then
        return false
    end

    local castAb = SafeValue(NPC.GetAbility, me, ABILITY_VEIL)
    if not CanExecuteNow(castAb) then
        return false
    end
    ---@cast castAb userdata

    BeginPendingCast("veil", ABILITY_VEIL, castAb, now)
    Runtime.veilCastAt = now
    TryCall(Ability.CastNoTarget, castAb, false, true, true, OrderId("veil"))
    DebugLog("raven veil")
    return true
end

---@param me userdata
---@param now number
---@return boolean
local function TryEul(me, now)
    if not UsageEnabled("eul") or IsBlacklisted("eul", now) then
        return false
    end
    local item, itemName = FindUsableItem(me, EUL_ITEMS)
    if not item or not itemName then
        return false
    end

    BeginPendingCast("eul", itemName, item, now)
    TryCall(Ability.CastTarget, item, me, false, true, true, OrderId("eul"))
    DebugLog("eul/wind waker")
    return true
end

--#endregion

--#region Escape FSM

---@param me userdata
---@param now number
---@return boolean
local function CanStillUseClaw(me, now)
    if not UsageEnabled("claw") or IsBlacklisted("claw", now) then
        return false
    end
    if IsSilenced(me) or IsRooted(me) then
        return false
    end
    return IsPairAvailable(me, ABILITY_CLAW, ABILITY_TALON)
end

---@param me userdata
---@param now number
---@return boolean
local function CanStillUseEcho(me, now)
    if not UsageEnabled("echo") or IsBlacklisted("echo", now) then
        return false
    end
    if IsSilenced(me) then
        return false
    end
    return IsPairAvailable(me, ABILITY_ECHO, ABILITY_RUSH)
end

---@param me userdata
---@param now number
---@return boolean
local function CanStillUseVeil(me, now)
    if not UsageEnabled("veil") or IsBlacklisted("veil", now) then
        return false
    end
    if IsSilenced(me) then
        return false
    end
    return IsPairAvailable(me, ABILITY_RAPTOR, ABILITY_VEIL)
end

---@param me userdata
---@param now number
---@return boolean
local function CanStillUseBlink(me, now)
    if not UsageEnabled("blink") or IsBlacklisted("blink", now) then
        return false
    end
    local item = FindUsableItem(me, BLINK_ITEMS)
    return item ~= nil
end

---@param me userdata
---@param now number
---@return boolean
local function CanStillUseForce(me, now)
    if not UsageEnabled("force") or IsBlacklisted("force", now) then
        return false
    end
    local item = FindUsableItem(me, FORCE_ITEMS)
    return item ~= nil
end

---@param me userdata
---@param now number
---@return boolean
local function CanStillUseEul(me, now)
    if not UsageEnabled("eul") or IsBlacklisted("eul", now) then
        return false
    end
    local item = FindUsableItem(me, EUL_ITEMS)
    return item ~= nil
end

---@param me userdata
---@param now number
---@return boolean
local function ShouldPreserveVeilInvis(me, now)
    if Runtime.veilCastAt < 0 then
        return false
    end
    local age = now - Runtime.veilCastAt
    if age < 0 or age > 12 then
        return false
    end
    -- Landing window: invis may appear a beat after the cast confirms.
    if age < 1.0 then
        return true
    end
    return IsInvisible(me)
end

--- Re-arm phases while the key stays held: when Claw/Echo come off CD,
--- return to katana; when only Veil is ready, use sai; otherwise finish items.
--- While preserving Raven's Veil invis, do not re-arm katana/finish casts.
---@param me userdata
---@param now number
local function UpdateEscapePhase(me, now)
    if ShouldPreserveVeilInvis(me, now) then
        local prev = Runtime.escapePhase or "katana"
        if prev ~= "finish" then
            Runtime.escapePhase = "finish"
            DebugLog("phase -> finish (veil invis)")
        else
            Runtime.escapePhase = "finish"
        end
        return
    end

    local nextPhase
    if CanStillUseClaw(me, now) or CanStillUseEcho(me, now) then
        nextPhase = "katana"
    elseif CanStillUseVeil(me, now) then
        nextPhase = "sai"
    else
        nextPhase = "finish"
    end

    local prev = Runtime.escapePhase or "katana"
    if nextPhase ~= prev then
        Runtime.escapePhase = nextPhase
        DebugLog("phase -> %s", nextPhase)
    else
        Runtime.escapePhase = nextPhase
    end
end

---@param me userdata
---@param fountainPos Vector
---@param now number
local function KeepMovingHome(me, fountainPos, now)
    MoveTowardFountain(me, fountainPos, now, false)
end

---@param me userdata
---@param now number
local function UpdateEscape(me, now)
    local fountainPos = ResolveFountainPos(me, now)
    local windMove = IsWindWakerActive(me)

    if IsHardLocked(me) and not windMove then
        return
    end

    if PollPendingCast(me, now) then
        if fountainPos and (windMove or (Runtime.pendingCast and Runtime.pendingCast.tag == "eul")) then
            KeepMovingHome(me, fountainPos, now)
        end
        return
    end

    if InQuiet(now) and not windMove then
        return
    end

    if not fountainPos then
        DebugLog("no fountain")
        return
    end

    if windMove then
        KeepMovingHome(me, fountainPos, now)
        return
    end

    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    if not mePos then
        return
    end

    UpdateEscapePhase(me, now)

    -- Raven's Veil: only move while invisible / landing — never break stealth.
    if ShouldPreserveVeilInvis(me, now) then
        KeepMovingHome(me, fountainPos, now)
        return
    end

    -- Face fountain before any escape cast (Force/Pike/Blink/spells).
    if not IsFacingPos(me, fountainPos) then
        MoveTowardFountain(me, fountainPos, now, true)
        return
    end

    local phase = Runtime.escapePhase or "katana"

    if phase == "katana" then
        -- Blink → Claw → Force → Echo (stay katana; no Veil yet)
        if TryBlink(me, mePos, fountainPos, now) then
            return
        end
        if TryClaw(me, mePos, fountainPos, now) then
            return
        end
        if TryForce(me, fountainPos, now) then
            return
        end
        if TryEcho(me, fountainPos, now) then
            return
        end
        KeepMovingHome(me, fountainPos, now)
        return
    end

    if phase == "sai" then
        if TryVeil(me, now) then
            return
        end
        -- Waiting on stance/quiet for Veil — do not burn Blink/Force/Eul (breaks upcoming invis).
        if CanStillUseVeil(me, now) then
            KeepMovingHome(me, fountainPos, now)
            return
        end
        Runtime.escapePhase = "finish"
    end

    -- finish: Blink/Force/Eul when ready + move (re-arms when items leave CD)
    if TryBlink(me, mePos, fountainPos, now) then
        return
    end
    if TryForce(me, fountainPos, now) then
        return
    end
    if TryEul(me, now) then
        KeepMovingHome(me, fountainPos, now)
        return
    end
    KeepMovingHome(me, fountainPos, now)
end

--#endregion

--#region Menu

---@return CMenuGroup|nil
local function FindOrCreateGroup()
    local group = Menu.Find("Heroes", "Hero List", "Kez", "Main Settings", "Escape Module")
        or Menu.Find("Scripts", "Heroes", "Kez Escape", "Main", "Escape Module")

    if not group then
        local main = Menu.Find("Heroes", "Hero List", "Kez", "Main Settings")
        if main and main.Create then
            group = main:Create("Escape Module")
        end
    end

    return group or Menu.Create("Scripts", "Heroes", "Kez Escape", "Main", "Escape Module")
end

local function EnsureMenu()
    if UI.ready then
        return
    end

    local group = FindOrCreateGroup()
    if not group then
        return
    end

    do
        local existing = group:Find("Enable")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or group:Switch("Enable", ReadBool("enabled", true), Icons.enable)
    end
    MenuIcon(UI.enabled, Icons.enable)
    UI.enabled:SetCallback(function(widget)
        WriteBool("enabled", widget:Get())
        if not widget:Get() then
            ResetRuntime()
        end
    end, false)

    do
        local existing = group:Find("Escape Key")
        ---@cast existing CMenuBind|nil
        UI.escapeKey = existing or group:Bind("Escape Key", Enum.ButtonCode.KEY_NONE, Icons.bind)
    end
    MenuIcon(UI.escapeKey, Icons.bind)

    -- Hide leftover widgets from previous UI layouts.
    for _, staleName in ipairs({
        "Grappling Claw",
        "Echo Slash",
        "Raven's Veil",
        "Blink",
        "Force / Pike",
        "Eul / Wind Waker",
        "Abilities",
        "Items",
        "Debug logs",
    }) do
        local stale = group:Find(staleName)
        if stale and stale.Visible then
            TryCall(stale.Visible, stale, false)
        end
    end

    local abilityItems = BuildUsageMultiSelectItems(ABILITY_USAGE)
    do
        local existing = group:Find("Abilities to Escape")
        ---@cast existing CMenuMultiSelect|nil
        UI.abilities = existing or group:MultiSelect("Abilities to Escape", abilityItems, false)
    end
    if UI.abilities.Update then
        TryCall(UI.abilities.Update, UI.abilities, abilityItems, false, true)
    end
    MenuIcon(UI.abilities, Icons.abilities)
    if UI.abilities.SetCallback then
        UI.abilities:SetCallback(function(widget)
            SyncUsagePrefsFromWidget(widget, ABILITY_USAGE)
        end, false)
    end

    local itemItems = BuildUsageMultiSelectItems(ITEM_USAGE)
    do
        local existing = group:Find("Items to Escape")
        ---@cast existing CMenuMultiSelect|nil
        UI.items = existing or group:MultiSelect("Items to Escape", itemItems, false)
    end
    if UI.items.Update then
        TryCall(UI.items.Update, UI.items, itemItems, false, true)
    end
    MenuIcon(UI.items, Icons.items)
    if UI.items.SetCallback then
        UI.items:SetCallback(function(widget)
            SyncUsagePrefsFromWidget(widget, ITEM_USAGE)
        end, false)
    end

    local gear = UI.enabled:Gear("Escape Settings", Icons.gear)
    if gear then
        local existingDebug = gear:Find("Enable Debug Logs")
        ---@cast existingDebug CMenuSwitch|nil
        UI.debug = existingDebug or gear:Switch("Enable Debug Logs", ReadBool("debug", false), Icons.bug)
        MenuIcon(UI.debug, Icons.bug)
        UI.debug:SetCallback(function(widget)
            WriteBool("debug", widget:Get())
        end, false)
    elseif not UI.debug then
        UI.debug = group:Switch("Enable Debug Logs", ReadBool("debug", false), Icons.bug)
        MenuIcon(UI.debug, Icons.bug)
        UI.debug:SetCallback(function(widget)
            WriteBool("debug", widget:Get())
        end, false)
    end

    UI.ready = true
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    EnsureMenu()
    Persistent.logger:info("loaded")
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end

    EnsureMenu()
    if not UI.enabled or not UI.enabled:Get() then
        Runtime.keyWasDown = false
        return
    end

    local keyDown = BindHeld(UI.escapeKey)
    if not keyDown then
        if Runtime.keyWasDown then
            ResetEscapeSession()
        end
        Runtime.keyWasDown = false
        return
    end
    Runtime.keyWasDown = true

    if SafeValue(Input.IsInputCaptured) == true then
        return
    end

    local me = SafeValue(Heroes.GetLocal)
    if not IsLocalKez(me) then
        return
    end
    ---@cast me userdata

    local now = SafeValue(GameRules.GetGameTime) or 0
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    UpdateEscape(me, now)
end

function Script.OnPrepareUnitOrders(data)
    local identifier = type(data) == "table" and data.identifier or nil
    if IsOurOrder(identifier) then
        return true
    end
end

function Script.OnGameEnd()
    ResetRuntime()
end

--#endregion

return Script
