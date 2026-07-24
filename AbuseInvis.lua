--[[
    Abuse Invis (AbuseInvis)
    RU: Абуз бага TA Meld — атака по подконтрольному крипу во время ТП гейта не
    приземляется, пока крип пинг-понгует Twin/Hidden Gates; инвиз/баг держится.
    EN: Sustains the TA Meld gate bug: attack a dominated creep mid-gate warp so the
    projectile never lands while the creep ping-pongs Twin/Hidden Gates.
    Auto Poke optional; Cold Timing = delay-only loop. Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "AbuseInvis"
local CONFIG_SECTION = "abuse_invis"
local HERO_NAME = "npc_dota_hero_templar_assassin"
local HERO_TAB = "Templar Assassin"
local HERO_ICON = "panorama/images/heroes/icons/npc_dota_hero_templar_assassin_png.vtex_c"
local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_THIRD = "Abuse Invis"
local MENU_GROUP = "Sustain"

local GATE_UNIT = "npc_dota_unit_twin_gate"
local ABILITY_TWIN = "twin_gate_portal_warp"
local ABILITY_HIDDEN = "templar_assassin_hidden_gates"
local MOD_MELD = "modifier_templar_assassin_meld"

local ORDER_PREFIX = "abuse.invis."
local ORDER_MOVE = ORDER_PREFIX .. "move"
local ORDER_CAST = ORDER_PREFIX .. "cast"
local ORDER_HOLD = ORDER_PREFIX .. "hold"
local ORDER_ATTACK = ORDER_PREFIX .. "attack"

local GATE_TWIN = 0
local GATE_HIDDEN = 1
local GATE_ITEMS = { "Twin Gates", "Hidden Gates" }

local STAGE = {
    IDLE = "idle",
    ARMED = "armed",
    WAITING = "waiting",
    APPROACH = "approach",
    CHANNEL = "channel",
}

local C = {
    UPDATE_INTERVAL = 0.05,
    ORDER_GAP = 0.20,
    GATE_CACHE_TTL = 1.0,
    CAST_RANGE_FALLBACK = 200,
    CAST_RANGE_PAD = 40,
    CHANNEL_TWIN = 4.0,
    CHANNEL_HIDDEN = 3.0,
    CHANNEL_SLACK = 0.75,
    -- Twin channel often finishes ~0.2s after nominal; pad start budget so warp lands on target.
    CHANNEL_LEAD = 0.25,
    WARP_JUMP_DIST = 1200,
    DEFAULT_REENTER = 3.0,
    -- Start channel so the warp lands near this projectile ETA (user window ~8-10s).
    DEFAULT_TARGET_WARP_ETA = 9.0,
    TARGET_WARP_ETA_LO = 7.0,
    TARGET_WARP_ETA_HI = 12.0,
    ETA_WAIT_SAFETY = 25.0,
    APPROACH_SPEED_FALLBACK = 300,
    -- TargetProjectiles can blink a frame; do not Abort on a single miss.
    PROJ_MISS_GRACE = 1.25,
    -- Max seconds-before-warp to consider Auto Poke (actual window uses attack travel ETA).
    POKE_LEAD_MAX = 0.85,
    POKE_LEAD_MIN = 0.12,
    -- Warp should finish this much before the projectile would hit.
    POKE_PRE_WARP = 0.10,
    SETUP_REENTER = 0.40,
}

local PANEL_TITLE = "Abuse Invis"
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_HEADER_HEIGHT = 32
local PANEL_HEADER_PAD_X = 10
local PANEL_HEADER_TEXT_SIZE = 14
local PANEL_BODY_TEXT_SIZE = 12
local PANEL_HINT_TEXT_SIZE = 11
local PANEL_HEADER_ICON_SIZE = 15
local PANEL_HEADER_ICON_GAP = 7
local PANEL_HEADER_RADIUS = 5
local PANEL_BODY_PAD = 8
local PANEL_ROW_GAP = 3
local PANEL_MIN_W = 200
local SPELL_ICON_MELD = "panorama/images/spellicons/templar_assassin_meld_png.vtex_c"
local PANEL_HEADER_FONT_CANDIDATES = { "Segoe UI", "Tahoma", "Arial" }

local STAGE_LABEL = {
    [STAGE.IDLE] = "Idle",
    [STAGE.ARMED] = "Arming",
    [STAGE.WAITING] = "Waiting",
    [STAGE.APPROACH] = "To Gate",
    [STAGE.CHANNEL] = "Channeling",
}

-- Runtime may not bind Enum.modifierState at script load (host quirk); stub values: INVISIBLE=7, DOMINATED=31.
local MODIFIER_STATE = Enum.modifierState
local STATE_INVISIBLE = (MODIFIER_STATE and MODIFIER_STATE.MODIFIER_STATE_INVISIBLE) or 7
local STATE_DOMINATED = (MODIFIER_STATE and MODIFIER_STATE.MODIFIER_STATE_DOMINATED) or 31
local ORDER_ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local ORDER_MOVE_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
local ORDER_CAST_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local DRAW_FLAGS_NONE = (Enum.DrawFlags and Enum.DrawFlags.None) or 0

local Icons = {
    enable = "\u{f00c}",
    bind = "\u{f11c}",
    gate = "\u{e4de}",
    delay = "\u{f017}",
    eta = "\u{f70c}",
    cold = "\u{f2dc}", -- snowflake — ignore projectile timing
    protect = "\u{f3ed}", -- shield — quarantine creep from other binds
    poke = "\u{f05b}", -- crosshairs — auto attack at channel end
    debug = "\u{f188}",
    hud = "\u{f06e}",
}
--#endregion

--#region State
---@class AbuseInvisUI
---@field enabled CMenuSwitch|nil
---@field bind CMenuBind|nil
---@field gateType CMenuComboBox|nil
---@field reenterDelay CMenuSliderFloat|CMenuSliderInt|nil
---@field coldTiming CMenuSwitch|nil
---@field protectCreep CMenuSwitch|nil
---@field autoPoke CMenuSwitch|nil
---@field debugLogs CMenuSwitch|nil
---@field targetWarpEta CMenuSliderFloat|CMenuSliderInt|nil
---@field drawHud CMenuSwitch|nil
---@field callbacksAttached boolean
local UI = {
    enabled = nil,
    bind = nil,
    gateType = nil,
    reenterDelay = nil,
    coldTiming = nil,
    protectCreep = nil,
    autoPoke = nil,
    debugLogs = nil,
    targetWarpEta = nil,
    drawHud = nil,
    callbacksAttached = false,
}

local MenuNodes = {
    ---@type CSecondTab|nil
    hero = nil,
    ---@type CThirdTab|nil
    tab = nil,
    ---@type CMenuGroup|nil
    group = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|userdata|nil
    font = nil,
    ---@type integer|nil
    spellIcon = nil,
    ---@type any
    blurFactorWidget = nil,
    ---@type number|nil
    blurStrength = PANEL_BLUR_BASE_STRENGTH,
    wasMousePressed = false,
}

local PanelConfig = {
    X = -1,
    Y = 112,
}

local PanelDrag = {
    IsDragging = false,
    OffsetX = 0,
    OffsetY = 0,
}

local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    TextStatus = Color(120, 200, 255, 255),
    TextOk = Color(110, 210, 140, 255),
    TextBad = Color(230, 110, 110, 255),
    TextWarn = Color(240, 195, 90, 255),
    TextMuted = Color(165, 175, 190, 230),
    TextBody = Color(225, 232, 245, 245),
    TextHint = Color(130, 185, 255, 245),
    CellBg = Color(12, 12, 16, 230),
}

local Runtime = {
    lastUpdateAt = -math.huge,
    stage = STAGE.IDLE,
    ---@type userdata|nil
    creep = nil,
    ---@type userdata[]|nil
    gates = nil,
    gatesAt = -math.huge,
    ---@type userdata|nil
    targetGate = nil,
    ---@type userdata|nil
    lastGate = nil,
    waitUntil = -math.huge,
    waitByEta = false,
    channelStartedAt = -math.huge,
    channelExpect = C.CHANNEL_TWIN,
    channelConfirmed = false,
    lastOrderAt = -math.huge,
    lastHeroOrderAt = -math.huge,
    channelPokeIssued = false,
    ---True after any Auto Poke this sustain run until a projectile is latched (or reset).
    setupPokeIssued = false,
    needHold = false,
    lastSelectGuardAt = -math.huge,
    lastDebugAt = -math.huge,
    lastVetoLogAt = -math.huge,
    lastHeartbeatAt = -math.huge,
    lastAbortLogAt = -math.huge,
    lastAbortMsg = "",
    ---@type string
    lastDebug = "",
    ---@type integer|nil
    projHandle = nil,
    ---@type number|nil
    lastEta = nil,
    lastEtaAt = -math.huge,
    projMissingSince = -math.huge,
    ---@type Vector|nil
    creepPosAtChannel = nil,
    usedFallbackTwin = false,
    status = "",
    armed = false,
    ---Manual toggle latched from Sustain Bind IsPressed (menu IsToggled alone is unreliable).
    sustainOn = false,
    ---@type { sustain: boolean, invis: boolean, creepOk: boolean, projOk: boolean, cold: boolean, hint: string, gateMode: string }
    hud = {
        sustain = false,
        invis = false,
        creepOk = false,
        projOk = false,
        cold = false,
        hint = "",
        gateMode = "Twin",
    },
    ---@type Vector|nil
    projPos = nil,
}
--#endregion

--#region Helpers
---@generic T
---@param fn fun(...): T
---@param ... any
---@return boolean
---@return T|string
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

local function LogInfo(fmt, ...)
    local logger = Persistent.logger
    if logger and logger.info then
        logger:info(string.format(fmt, ...))
    end
end

local function IsDebugLogsOn()
    return UI.debugLogs ~= nil and UI.debugLogs:Get() == true
end

---@param fmt string
---@param ... any
local function Dbg(fmt, ...)
    if not IsDebugLogsOn() then
        return
    end
    local msg = fmt
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        if ok then
            msg = formatted
        end
    end
    Runtime.lastDebug = msg
    local logger = Persistent.logger
    if logger and logger.info then
        logger:info("[dbg] " .. msg)
    else
        print("[AbuseInvis] " .. msg)
    end
end

---@param unit any
---@return number|nil
local function UnitIndex(unit)
    if unit == nil then
        return nil
    end
    local ok, idx = TryCall(Entity.GetIndex, unit)
    if ok and type(idx) == "number" then
        return idx
    end
    return nil
end

---Userdata == is unreliable across projectile callbacks / GetAll snapshots.
---@param a any
---@param b any
---@return boolean
local function SameUnit(a, b)
    if a == nil or b == nil then
        return false
    end
    if a == b then
        return true
    end
    local ia = UnitIndex(a)
    local ib = UnitIndex(b)
    return ia ~= nil and ia == ib
end

---@param unit userdata|nil
---@return string
local function FmtUnit(unit)
    if not unit then
        return "nil"
    end
    local name = Entity.GetUnitDesignerName(unit) or Entity.GetUnitName(unit) or "?"
    local idx = UnitIndex(unit)
    if type(idx) == "number" then
        return string.format("%s#%d", name, idx)
    end
    return tostring(name)
end

---@param pos Vector|nil
---@return string
local function FmtPos(pos)
    if not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
        return "(?,?)"
    end
    return string.format("(%.0f,%.0f)", pos.x, pos.y)
end

---@param orderType any
---@return string
local function FmtOrder(orderType)
    if orderType == ORDER_MOVE_TARGET then
        return "MOVE_TARGET"
    end
    if orderType == ORDER_CAST_TARGET then
        return "CAST_TARGET"
    end
    if orderType == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION then
        return "HOLD"
    end
    return tostring(orderType)
end

local function SetStatus(msg)
    Runtime.status = msg or ""
end

---@param newStage string
---@param why string
local function SetStage(newStage, why)
    local prev = Runtime.stage
    if prev ~= newStage then
        Dbg("STAGE %s -> %s | %s", tostring(prev), tostring(newStage), why)
    else
        Dbg("STAGE keep %s | %s", tostring(newStage), why)
    end
    Runtime.stage = newStage
end

local function ResetRuntime(keepSustain)
    Runtime.lastUpdateAt = -math.huge
    Runtime.stage = STAGE.IDLE
    Runtime.creep = nil
    Runtime.gates = nil
    Runtime.gatesAt = -math.huge
    Runtime.targetGate = nil
    Runtime.lastGate = nil
    Runtime.waitUntil = -math.huge
    Runtime.waitByEta = false
    Runtime.channelStartedAt = -math.huge
    Runtime.channelExpect = C.CHANNEL_TWIN
    Runtime.channelConfirmed = false
    Runtime.lastOrderAt = -math.huge
    Runtime.lastHeroOrderAt = -math.huge
    Runtime.channelPokeIssued = false
    Runtime.setupPokeIssued = false
    Runtime.needHold = false
    Runtime.lastSelectGuardAt = -math.huge
    Runtime.lastDebugAt = -math.huge
    Runtime.lastVetoLogAt = -math.huge
    Runtime.lastHeartbeatAt = -math.huge
    Runtime.lastAbortLogAt = -math.huge
    Runtime.lastAbortMsg = ""
    Runtime.lastDebug = ""
    Runtime.projHandle = nil
    Runtime.lastEta = nil
    Runtime.lastEtaAt = -math.huge
    Runtime.projMissingSince = -math.huge
    Runtime.creepPosAtChannel = nil
    Runtime.usedFallbackTwin = false
    Runtime.status = ""
    Runtime.armed = false
    Runtime.projPos = nil
    Runtime.hud.sustain = false
    Runtime.hud.invis = false
    Runtime.hud.creepOk = false
    Runtime.hud.projOk = false
    Runtime.hud.cold = false
    Runtime.hud.hint = ""
    if keepSustain ~= true then
        Runtime.sustainOn = false
        if UI.bind and UI.bind.SetToggled then
            UI.bind:SetToggled(false)
        end
    end
end

local function ReadBool(key, default)
    local def = default and 1 or 0
    local ok, value = TryCall(Config.ReadInt, CONFIG_SECTION, key, def)
    if not ok or type(value) ~= "number" then
        return default == true
    end
    return value ~= 0
end

local function WriteBool(key, value)
    TryCall(Config.WriteInt, CONFIG_SECTION, key, value and 1 or 0)
end

local function ReadInt(key, default)
    local ok, value = TryCall(Config.ReadInt, CONFIG_SECTION, key, default)
    if not ok or type(value) ~= "number" then
        return default
    end
    return value
end

local function WriteInt(key, value)
    TryCall(Config.WriteInt, CONFIG_SECTION, key, value)
end

local function ReadFloat(key, default)
    local ok, value = TryCall(Config.ReadFloat, CONFIG_SECTION, key, default)
    if not ok or type(value) ~= "number" then
        return default
    end
    return value
end

local function WriteFloat(key, value)
    TryCall(Config.WriteFloat, CONFIG_SECTION, key, value)
end

local function Clamp(v, lo, hi)
    if v < lo then
        return lo
    end
    if v > hi then
        return hi
    end
    return v
end

local function IsValidUnit(unit)
    if unit == nil then
        return false
    end
    -- Stale handles can throw; fail closed unless IsAlive confirms true.
    local ok, alive = TryCall(Entity.IsAlive, unit)
    return ok and alive == true
end

---@param unit userdata|nil
---@return Vector|nil
local function AbsOrigin(unit)
    if unit == nil then
        return nil
    end
    local ok, pos = TryCall(Entity.GetAbsOrigin, unit)
    -- TryCall's error channel is a string; only return a real Vector.
    if not ok or type(pos) == "string" or pos == nil then
        return nil
    end
    ---@cast pos Vector
    return pos
end

local function UnitName(unit)
    if unit == nil then
        return nil
    end
    local name = Entity.GetUnitDesignerName(unit)
    if type(name) == "string" and name ~= "" then
        return name
    end
    name = Entity.GetUnitName(unit)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

---@param a Vector|nil
---@param b Vector|nil
---@return number|nil
local function DistSqr2D(a, b)
    if not a or not b then
        return nil
    end
    local ok, dist = TryCall(function()
        return a:DistanceSqr2D(b)
    end)
    if ok and type(dist) == "number" then
        return dist
    end
    local ax, ay = a.x, a.y
    local bx, by = b.x, b.y
    if type(ax) ~= "number" or type(bx) ~= "number" then
        return nil
    end
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

---@param a Vector|nil
---@param b Vector|nil
---@return number|nil
local function Dist2D(a, b)
    local sqr = DistSqr2D(a, b)
    if type(sqr) ~= "number" then
        return nil
    end
    return math.sqrt(sqr)
end

local function HasInvis(hero)
    if NPC.HasState(hero, STATE_INVISIBLE) == true then
        return true
    end
    if NPC.HasModifier(hero, MOD_MELD) == true then
        return true
    end
    return false
end

---@return integer|nil
---@return userdata|nil
local function GetLocalPlayerId()
    local player = Players.GetLocal()
    if not player then
        return nil, nil
    end
    local pid = Player.GetPlayerID(player)
    if type(pid) ~= "number" or pid < 0 then
        return nil, player
    end
    return pid, player
end

---@param unit userdata|nil
---@param playerId integer
---@param hero userdata
---@return boolean
local function IsCreepCandidate(unit, playerId, hero)
    if not IsValidUnit(unit) or unit == hero then
        return false
    end
    ---@cast unit userdata
    if NPC.IsHero(unit) == true then
        return false
    end
    local controllable = Entity.IsControllableByPlayer(unit, playerId) == true
        or NPC.IsControllableByPlayer(unit, playerId) == true
    if not controllable then
        return false
    end
    if NPC.HasState(unit, STATE_DOMINATED) == true then
        return true
    end
    if Entity.OwnedBy(unit, hero) == true then
        return true
    end
    if Entity.RecursiveOwnedBy(unit, hero) == true then
        return true
    end
    return false
end

---@param player userdata
---@param playerId integer
---@param hero userdata
---@return userdata|nil
local function FindCreep(player, playerId, hero)
    local selected = Player.GetSelectedUnits(player)
    if type(selected) == "table" then
        for i = 1, #selected do
            local unit = selected[i]
            if IsCreepCandidate(unit, playerId, hero) then
                return unit
            end
        end
    end

    -- Bitmask of creep-like unit types (LuaLS enum can't express OR; cast at call).
    local creepFlags = Enum.UnitTypeFlags.TYPE_CREEP
        | Enum.UnitTypeFlags.TYPE_LANE_CREEP
        | Enum.UnitTypeFlags.TYPE_ANCIENT
    ---@cast creepFlags Enum.UnitTypeFlags
    local all = NPCs.GetAll(creepFlags)
    if type(all) ~= "table" then
        return nil
    end
    for i = 1, #all do
        local unit = all[i]
        if IsCreepCandidate(unit, playerId, hero) then
            return unit
        end
    end
    return nil
end

local function GetGateType()
    local value = UI.gateType and UI.gateType:Get() or ReadInt("gate_type", GATE_TWIN)
    if value == GATE_HIDDEN then
        return GATE_HIDDEN
    end
    return GATE_TWIN
end

local function GetReenterDelay()
    local value = UI.reenterDelay and UI.reenterDelay:Get() or ReadFloat("reenter_delay", C.DEFAULT_REENTER)
    return Clamp(tonumber(value) or C.DEFAULT_REENTER, 2.0, 5.0)
end

local function GetTargetWarpEta()
    local value = UI.targetWarpEta and UI.targetWarpEta:Get()
        or ReadFloat("target_warp_eta", C.DEFAULT_TARGET_WARP_ETA)
    return Clamp(
        tonumber(value) or C.DEFAULT_TARGET_WARP_ETA,
        C.TARGET_WARP_ETA_LO,
        C.TARGET_WARP_ETA_HI
    )
end

local function IsColdTiming()
    return UI.coldTiming ~= nil and UI.coldTiming:Get() == true
end

local function IsAutoPoke()
    return UI.autoPoke ~= nil and UI.autoPoke:Get() == true
end

local function IsProtectCreep()
    return UI.protectCreep ~= nil and UI.protectCreep:Get() == true
end

---True while Auto Poke is on and we still need the setup Meld attack projectile.
---@return boolean
local function AwaitingSetupPoke()
    if not IsAutoPoke() or IsColdTiming() then
        return false
    end
    return Runtime.projHandle == nil and type(Runtime.lastEta) ~= "number"
end

local function SyncColdTimingUi()
    local cold = IsColdTiming()
    if UI.targetWarpEta and UI.targetWarpEta.Visible then
        UI.targetWarpEta:Visible(not cold)
    end
    if UI.reenterDelay and UI.reenterDelay.Visible then
        -- Re-enter Delay is the pacing control only in Cold Timing; otherwise ETA drives waits.
        UI.reenterDelay:Visible(cold)
    end
end

---@param code any
---@return boolean
local function IsBoundKeyCode(code)
    return type(code) == "number"
        and code ~= Enum.ButtonCode.KEY_NONE
        and code ~= Enum.ButtonCode.BUTTON_CODE_INVALID
end

---@param bind CMenuBind
---@return boolean
local function BindHasKey(bind)
    local key1, key2 = bind:Buttons()
    return IsBoundKeyCode(key1) or IsBoundKeyCode(key2)
end

local function IsEnabled()
    return UI.enabled ~= nil and UI.enabled:Get() == true
end

local function IsHudOn()
    return UI.drawHud ~= nil and UI.drawHud:Get() == true
end

---@param hero userdata|nil
---@return boolean
local function IsTemplarAssassin(hero)
    if not IsValidUnit(hero) then
        return false
    end
    ---@cast hero userdata
    local name = NPC.GetUnitName(hero) or Entity.GetUnitName(hero)
    return name == HERO_NAME
end

---@return boolean
local function IsLocalTemplarAssassin()
    return IsTemplarAssassin(Heroes.GetLocal())
end

local function IsFeatureActive()
    if not IsEnabled() then
        return false
    end
    -- No key assigned: Enable alone runs sustain.
    if not UI.bind or not BindHasKey(UI.bind) then
        return true
    end
    return Runtime.sustainOn == true
end

---@return boolean
local function ShouldQuarantineCreep()
    if not IsProtectCreep() or not IsFeatureActive() then
        return false
    end
    if not IsValidUnit(Runtime.creep) then
        return false
    end
    -- Only while sustain loop is actually running (armed / in stages).
    return Runtime.armed == true or Runtime.stage ~= STAGE.IDLE
end

---@param unit any
---@return boolean
local function IsPinnedCreep(unit)
    local creep = Runtime.creep
    return creep ~= nil and unit == creep
end

---True if order issuer npc is the pinned creep (single or list).
---@param npc any
---@return boolean
local function OrderNpcIsPinnedCreep(npc)
    if IsPinnedCreep(npc) then
        return true
    end
    if type(npc) ~= "table" then
        return false
    end
    for i = 1, #npc do
        if IsPinnedCreep(npc[i]) then
            return true
        end
    end
    return false
end

---Keep procast / tab-select from owning the gate creep: drop it from selection.
---@param player userdata
---@param hero userdata
---@param creep userdata
---@param now number
local function GuardCreepSelection(player, hero, creep, now)
    if (now - Runtime.lastSelectGuardAt) < 0.20 then
        return
    end
    Runtime.lastSelectGuardAt = now

    local selected = Player.GetSelectedUnits(player)
    if type(selected) ~= "table" or #selected == 0 then
        return
    end

    local hasCreep = false
    ---@type userdata[]
    local keep = {}
    for i = 1, #selected do
        local unit = selected[i]
        if IsPinnedCreep(unit) then
            hasCreep = true
        elseif unit ~= nil then
            keep[#keep + 1] = unit
        end
    end
    if not hasCreep then
        return
    end

    Dbg(
        "SELECT drop creep from selection keep=%d (was %d) creep=%s",
        #keep,
        #selected,
        FmtUnit(creep)
    )
    Player.ClearSelectedUnits(player)
    if #keep == 0 then
        if hero then
            Player.AddSelectedUnit(player, hero)
            Dbg("SELECT restore hero only %s", FmtUnit(hero))
        end
        return
    end
    for i = 1, #keep do
        Player.AddSelectedUnit(player, keep[i])
    end
end

---@param hint string|nil
local function UpdateHudSnapshot(hint)
    local hero = Heroes.GetLocal()
    local playerId = select(1, GetLocalPlayerId())
    local invis = hero ~= nil and HasInvis(hero) == true
    local creep = Runtime.creep
    local creepOk = false
    if hero and playerId ~= nil and IsCreepCandidate(creep, playerId, hero) then
        creepOk = true
    elseif IsValidUnit(creep) then
        creepOk = true
    end

    local gateMode = GetGateType() == GATE_HIDDEN and "Hidden" or "Twin"
    if Runtime.usedFallbackTwin then
        gateMode = "Hidden→Twin"
    end

    local cold = IsColdTiming()
    Runtime.hud.sustain = IsFeatureActive()
    Runtime.hud.invis = invis
    Runtime.hud.creepOk = creepOk
    Runtime.hud.cold = cold
    Runtime.hud.projOk = cold
        or Runtime.projHandle ~= nil
        or type(Runtime.lastEta) == "number"
        or (IsAutoPoke() and Runtime.stage ~= STAGE.IDLE)
    Runtime.hud.gateMode = gateMode
    if type(hint) == "string" and hint ~= "" then
        Runtime.hud.hint = hint
    elseif Runtime.status ~= "" then
        Runtime.hud.hint = Runtime.status
    end
end

---@return string
local function BuildSetupHint()
    local h = Runtime.hud
    if not IsEnabled() then
        return "Enable Abuse Invis in the menu"
    end
    if not h.sustain then
        return "Press Sustain Bind to start"
    end
    if not h.invis then
        return "1) Cast Meld (stay invisible)"
    end
    if not h.creepOk then
        return "2) Dominate a creep and select it"
    end
    if IsAutoPoke() and AwaitingSetupPoke() then
        if Runtime.setupPokeIssued and not h.invis then
            return "Re-cast Meld — Auto Poke will retry"
        end
        if Runtime.stage == STAGE.CHANNEL then
            return "Auto Poke: attack near end of gate channel"
        end
        return "Auto Poke: creep will channel, then hero attacks"
    end
    if h.cold then
        if Runtime.stage == STAGE.WAITING then
            return "Cold: waiting Re-enter Delay, then TP"
        end
        if Runtime.stage == STAGE.APPROACH then
            return "Cold: creep walking to gate"
        end
        if Runtime.stage == STAGE.CHANNEL then
            return "Cold: channeling gate"
        end
        return "Cold: looping gates on delay only"
    end
    if not h.projOk then
        return "Next: attack creep from Meld while it warps"
    end
    if Runtime.stage == STAGE.WAITING then
        return "Holding before next gate enter"
    end
    if Runtime.stage == STAGE.APPROACH then
        return "Creep walking to the next gate"
    end
    if Runtime.stage == STAGE.CHANNEL then
        return "Creep channeling twin gate"
    end
    return "Sustain running"
end

---Edge-detect Sustain Bind. Menu IsToggled does not flip on key alone.
---Only while local hero is Templar Assassin (bind is hero-scoped).
local function PollSustainBind()
    if not IsLocalTemplarAssassin() then
        return
    end
    if not IsEnabled() or not UI.bind or not BindHasKey(UI.bind) then
        return
    end
    if UI.bind:IsPressed() ~= true then
        return
    end

    local nextOn = not Runtime.sustainOn
    Runtime.sustainOn = nextOn
    UI.bind:SetToggled(nextOn)
    WriteBool("bind_toggled", nextOn)

    if nextOn then
        SetStatus("sustain ON")
        LogInfo("sustain ON")
    else
        ResetRuntime(true)
        Runtime.sustainOn = false
        SetStatus("sustain OFF")
        LogInfo("sustain OFF")
    end
end

---@param now number
---@return userdata[]
local function RefreshGates(now)
    if Runtime.gates and (now - Runtime.gatesAt) < C.GATE_CACHE_TTL then
        return Runtime.gates
    end

    local found = {}
    -- Twin gates are not reliably typed as creeps; full list + TTL is intentional.
    local all = NPCs.GetAll()
    if type(all) == "table" then
        for i = 1, #all do
            local npc = all[i]
            if IsValidUnit(npc) and UnitName(npc) == GATE_UNIT then
                found[#found + 1] = npc
            end
        end
    end

    Runtime.gates = found
    Runtime.gatesAt = now
    return found
end

---@param creep userdata
---@return userdata|nil
---@return number
---@return boolean
local function ResolveWarpAbility(creep)
    Runtime.usedFallbackTwin = false
    local gateType = GetGateType()
    if gateType == GATE_HIDDEN then
        local hidden = NPC.GetAbility(creep, ABILITY_HIDDEN)
        if hidden then
            return hidden, C.CHANNEL_HIDDEN, false
        end
        local twin = NPC.GetAbility(creep, ABILITY_TWIN)
        if twin then
            Runtime.usedFallbackTwin = true
            return twin, C.CHANNEL_TWIN, true
        end
        return nil, C.CHANNEL_HIDDEN, false
    end

    local twin = NPC.GetAbility(creep, ABILITY_TWIN)
    if twin then
        return twin, C.CHANNEL_TWIN, false
    end
    local hidden = NPC.GetAbility(creep, ABILITY_HIDDEN)
    if hidden then
        return hidden, C.CHANNEL_HIDDEN, false
    end
    return nil, C.CHANNEL_TWIN, false
end

---Twin gates: always channel the nearest portal (the one beside the creep).
---Walking to the far portal is wrong — warp links the pair automatically.
---@param creep userdata
---@param prefer userdata|nil
---@param why string|nil
---@return userdata|nil
---@return number
local function PickNearestGate(creep, prefer, why)
    local gates = Runtime.gates or {}
    if #gates == 0 then
        Dbg("PICK gate FAIL empty list | %s", why or "")
        return nil, math.huge
    end

    if prefer and IsValidUnit(prefer) then
        local creepPos = AbsOrigin(creep)
        local gatePos = AbsOrigin(prefer)
        local dist = Dist2D(creepPos, gatePos) or -1
        Dbg("PICK gate prefer %s dist=%.0f | %s", FmtUnit(prefer), dist, why or "")
        return prefer, dist
    end

    local creepPos = AbsOrigin(creep)
    if not creepPos then
        Dbg("PICK gate fallback gates[1] (no creep pos) | %s", why or "")
        return gates[1], math.huge
    end

    ---@type userdata|nil
    local bestNear = nil
    local bestNearSqr = math.huge
    local bestNearDist = math.huge
    local parts = {}

    for i = 1, #gates do
        local gate = gates[i]
        if IsValidUnit(gate) then
            local gatePos = AbsOrigin(gate)
            local sqr = DistSqr2D(creepPos, gatePos) or math.huge
            local dist = (sqr < math.huge) and math.sqrt(sqr) or math.huge
            parts[#parts + 1] = string.format("%s=%.0f", FmtUnit(gate), dist)
            if sqr < bestNearSqr then
                bestNearSqr = sqr
                bestNearDist = dist
                bestNear = gate
            end
        end
    end

    local picked = bestNear or gates[1]
    Dbg(
        "PICK nearest %s dist=%.0f creep=%s gates[%d]: %s | %s",
        FmtUnit(picked),
        bestNearDist,
        FmtPos(creepPos),
        #gates,
        table.concat(parts, ", "),
        why or ""
    )
    return picked, bestNearDist
end

local function CanOrder(now)
    return (now - Runtime.lastOrderAt) >= C.ORDER_GAP
end

---@param player userdata
---@param creep userdata
---@param orderType Enum.UnitOrder
---@param target userdata|nil
---@param ability userdata|nil
---@param identifier string
---@param why string|nil
---@return boolean
---Issue a creep order. Returns true after the host call (throttle advanced).
---Game acceptance is confirmed later via channel / warp jump / projectile latch.
local function IssueCreepOrder(player, creep, orderType, target, ability, identifier, why)
    local creepPos = AbsOrigin(creep)
    local pos = creepPos or Vector(0, 0, 0)
    local targetDist = -1
    if target then
        local tpos = AbsOrigin(target)
        if tpos then
            pos = tpos
            targetDist = Dist2D(creepPos, tpos) or -1
        end
    end

    Dbg(
        "ORDER %s id=%s target=%s dist=%.0f creep=%s | %s",
        FmtOrder(orderType),
        tostring(identifier),
        FmtUnit(target),
        targetDist,
        FmtPos(creepPos),
        why or ""
    )

    -- callback=true so OnPrepareUnitOrders sees our identifier; execute_fast keeps gate ping-pong latency low.
    Player.PrepareUnitOrders(
        player,
        orderType,
        target,
        pos,
        ability,
        ORDER_ISSUER,
        creep,
        false,
        false,
        true,
        true,
        identifier,
        true
    )
    Runtime.lastOrderAt = GameRules.GetGameTime()
    Dbg("ORDER issued %s", tostring(identifier))
    return true
end

---Stop leftover move orders so the creep stays by the arrival gate during delay.
---@param player userdata
---@param creep userdata
---@param now number
---@param why string|nil
---@return boolean
local function HoldCreep(player, creep, now, why)
    if not CanOrder(now) then
        Dbg("HOLD skip throttle | %s", why or "")
        return false
    end
    Dbg("HOLD HoldPosition creep=%s | %s", FmtPos(AbsOrigin(creep)), why or "")
    Player.HoldPosition(player, creep, false, true, true, ORDER_HOLD)
    Runtime.lastOrderAt = now
    Dbg("HOLD issued via HoldPosition")
    return true
end

---@param proj table
---@param hero userdata
---@param creepPos Vector|nil
---@param fallbackSpeed number|nil
---@param now number
---@return number eta
local function EstimateProjEta(proj, hero, creepPos, fallbackSpeed, now)
    local speed = tonumber(proj.speed) or tonumber(proj.original_speed) or tonumber(fallbackSpeed) or 0
    local pos = proj.current_position
    local targetPos = creepPos or proj.target_position
    local dist = Dist2D(pos, targetPos)
    if dist and speed > 1 then
        return dist / speed
    end
    if type(proj.max_impact_time) == "number" then
        return math.max(0, proj.max_impact_time - now)
    end
    return math.huge
end

---@param hero userdata
---@param creep userdata|nil
---@param playerId integer|nil
---@return table|nil proj
---@return number|nil eta
---@return userdata|nil matchedCreep
local function FindAttackProjectile(hero, creep, playerId)
    local list = TargetProjectiles.GetAll()
    if type(list) ~= "table" then
        return nil, nil, nil
    end

    local now = GameRules.GetGameTime() or 0
    local fallbackSpeed = NPC.GetAttackProjectileSpeed(hero)
    local creepPos = creep and AbsOrigin(creep) or nil

    ---@type table|nil
    local bestExact = nil
    local bestExactEta = math.huge
    ---@type table|nil
    local bestAny = nil
    local bestAnyEta = math.huge
    ---@type userdata|nil
    local bestAnyCreep = nil
    ---@type table|nil
    local byHandle = nil
    local byHandleEta = math.huge

    for i = 1, #list do
        local proj = list[i]
        if type(proj) == "table" and proj.attack == true and SameUnit(proj.source, hero) then
            local eta = EstimateProjEta(proj, hero, nil, fallbackSpeed, now)
            if Runtime.projHandle ~= nil and proj.handle == Runtime.projHandle then
                byHandle = proj
                byHandleEta = eta
            end

            if creep and SameUnit(proj.target, creep) then
                -- Recompute with live creep pos for pinned target.
                eta = EstimateProjEta(proj, hero, creepPos, fallbackSpeed, now)
                if eta < bestExactEta then
                    bestExactEta = eta
                    bestExact = proj
                end
            elseif playerId ~= nil and proj.target ~= nil and IsCreepCandidate(proj.target, playerId, hero) then
                local tpos = AbsOrigin(proj.target)
                eta = EstimateProjEta(proj, hero, tpos, fallbackSpeed, now)
                if eta < bestAnyEta then
                    bestAnyEta = eta
                    bestAny = proj
                    bestAnyCreep = proj.target
                end
            end
        end
    end

    local chosen = bestExact or byHandle or bestAny
    local chosenEta = bestExact and bestExactEta or (byHandle and byHandleEta or bestAnyEta)
    local matchedCreep = creep
    if chosen == bestAny and bestAnyCreep then
        matchedCreep = bestAnyCreep
    elseif chosen == byHandle and byHandle and byHandle.target then
        matchedCreep = byHandle.target
    end

    if chosen then
        if Runtime.projHandle ~= nil and chosen.handle ~= Runtime.projHandle then
            Dbg(
                "PROJ adopt handle=%s (was %s) target=%s eta=%s",
                tostring(chosen.handle),
                tostring(Runtime.projHandle),
                FmtUnit(chosen.target),
                chosenEta < math.huge and string.format("%.2f", chosenEta) or "nil"
            )
        elseif Runtime.projHandle == nil then
            Dbg(
                "PROJ latch handle=%s target=%s eta=%s",
                tostring(chosen.handle),
                FmtUnit(chosen.target),
                chosenEta < math.huge and string.format("%.2f", chosenEta) or "nil"
            )
        end
        Runtime.projHandle = chosen.handle
        Runtime.projPos = chosen.current_position
        if chosenEta < math.huge then
            Runtime.lastEta = chosenEta
            Runtime.lastEtaAt = now
            return chosen, chosenEta, matchedCreep
        end
        return chosen, nil, matchedCreep
    end

    return nil, nil, nil
end

local function GetCastRange(ability)
    local range = Ability.GetCastRange(ability)
    if type(range) == "number" and range > 0 then
        return range
    end
    return C.CAST_RANGE_FALLBACK
end

---Seconds to walk into cast range of the nearest gate (0 if already in range).
---@param creep userdata
---@param ability userdata|nil
---@return number
local function EstimateApproachSeconds(creep, ability)
    local gates = Runtime.gates or {}
    local creepPos = AbsOrigin(creep)
    if not creepPos or #gates == 0 then
        return 0
    end

    local bestDist = math.huge
    for i = 1, #gates do
        local gate = gates[i]
        if IsValidUnit(gate) then
            local gatePos = AbsOrigin(gate)
            local dist = Dist2D(creepPos, gatePos)
            if type(dist) == "number" and dist < bestDist then
                bestDist = dist
            end
        end
    end
    if bestDist >= math.huge then
        return 0
    end

    local castRange = (ability and GetCastRange(ability) or C.CAST_RANGE_FALLBACK) + C.CAST_RANGE_PAD
    local walk = bestDist - castRange
    if walk <= 1 then
        return 0
    end

    local speed = NPC.GetMoveSpeed(creep) or NPC.GetBaseSpeed(creep)
    speed = tonumber(speed) or C.APPROACH_SPEED_FALLBACK
    if speed < 1 then
        speed = C.APPROACH_SPEED_FALLBACK
    end
    return walk / speed
end

---ETA at which we should begin cast so the warp completes near Target Warp ETA.
---@param channelExpect number
---@param approachPad number
---@return number startEta
---@return number targetWarp
local function GetGateStartEta(channelExpect, approachPad)
    local targetWarp = GetTargetWarpEta()
    local startEta = targetWarp
        + (tonumber(channelExpect) or C.CHANNEL_TWIN)
        + C.CHANNEL_LEAD
        + (tonumber(approachPad) or 0)
    return startEta, targetWarp
end

---@param eta number|nil
---@param startEta number
---@return boolean
local function IsEtaReadyToEnter(eta, startEta)
    return type(eta) == "number" and eta <= startEta
end

local function Abort(reason)
    local msg = reason or "abort"
    if msg == "not invisible" then
        msg = "Cast Meld first"
    elseif msg == "no creep" then
        msg = "Dominate / select a creep"
    elseif msg == "projectile gone" then
        msg = "Projectile landed - re-attack from Meld"
    elseif msg == "waiting for Meld projectile" then
        msg = "Attack creep from Meld while it warps"
    end

    local alreadyIdle = Runtime.stage == STAGE.IDLE and Runtime.armed ~= true
    SetStatus(msg)
    if alreadyIdle and Runtime.lastAbortMsg == msg then
        -- Soft wait (e.g. no Meld yet): do not spam console every tick.
        return
    end

    local now = GameRules.GetGameTime() or 0
    if msg ~= Runtime.lastAbortMsg or (now - Runtime.lastAbortLogAt) >= 1.5 then
        Dbg("ABORT %s (stage was %s)", msg, tostring(Runtime.stage))
        Runtime.lastAbortLogAt = now
        Runtime.lastAbortMsg = msg
    end

    Runtime.stage = STAGE.IDLE
    Runtime.armed = false
    Runtime.targetGate = nil
    Runtime.waitUntil = -math.huge
    Runtime.waitByEta = false
    Runtime.channelStartedAt = -math.huge
    Runtime.channelConfirmed = false
    Runtime.creepPosAtChannel = nil
    Runtime.channelPokeIssued = false
    Runtime.setupPokeIssued = false
    Runtime.projPos = nil
    -- Drop stale latch so the next Meld poke can match a new handle.
    Runtime.projHandle = nil
    Runtime.lastEta = nil
    Runtime.lastEtaAt = -math.huge
    Runtime.projMissingSince = -math.huge
end

local function EnterWaiting(now, reason)
    local cold = IsColdTiming()
    local setup = AwaitingSetupPoke()
    local delay
    local byEta = false
    if cold then
        delay = GetReenterDelay()
    elseif setup then
        -- No projectile yet: short hop to the next gate for another Auto Poke window.
        delay = C.SETUP_REENTER
    else
        delay = C.ETA_WAIT_SAFETY
        byEta = true
    end
    SetStage(STAGE.WAITING, reason or "waiting")
    Runtime.waitUntil = now + delay
    Runtime.waitByEta = byEta
    Runtime.targetGate = nil
    Runtime.channelStartedAt = -math.huge
    Runtime.channelConfirmed = false
    Runtime.creepPosAtChannel = nil
    Runtime.channelPokeIssued = false
    Runtime.needHold = true
    SetStatus(reason or "waiting")
    if Runtime.waitByEta then
        Dbg(
            "WAIT by ETA (safety +%.1fs t=%.2f) targetWarp=%.1f needHold=true | %s",
            delay,
            Runtime.waitUntil,
            GetTargetWarpEta(),
            reason or ""
        )
    else
        Dbg(
            "WAIT until +%.2fs (t=%.2f) needHold=true setup=%s | %s",
            delay,
            Runtime.waitUntil,
            tostring(setup),
            reason or ""
        )
    end
end

---Estimated time from AttackTarget order until the projectile would hit the creep.
---@param hero userdata
---@param creep userdata
---@return number
local function EstimateAttackHitEta(hero, creep)
    local speed = NPC.GetAttackProjectileSpeed(hero)
    local heroPos = AbsOrigin(hero)
    local creepPos = AbsOrigin(creep)
    local dist = Dist2D(heroPos, creepPos)
    local flight = 0.20
    if type(dist) == "number" and type(speed) == "number" and speed > 1 then
        flight = dist / speed
    elseif type(dist) == "number" and dist < 200 then
        flight = 0.12 -- melee / no projectile speed
    end

    local spa = NPC.GetSecondsPerAttack(hero, false)
    local pointPad = 0.18
    if type(spa) == "number" and spa > 0 then
        pointPad = Clamp(spa * 0.35, 0.10, 0.40)
    end
    return flight + pointPad
end

---@param hero userdata
---@param creep userdata
---@return number pokeAt
---@return number hitEta
local function GetAutoPokeRemainingTarget(hero, creep)
    local hitEta = EstimateAttackHitEta(hero, creep)
    -- Poke late enough that warp finishes before impact: remaining ≈ hitEta - PRE_WARP.
    local target = hitEta - C.POKE_PRE_WARP
    return Clamp(target, C.POKE_LEAD_MIN, C.POKE_LEAD_MAX), hitEta
end

---@param player userdata
---@param hero userdata
---@param creep userdata
---@param ability userdata|nil
---@param now number
---@return boolean issued
local function TryAutoPoke(player, hero, creep, ability, now)
    if not IsAutoPoke() then
        return false
    end
    if Runtime.channelPokeIssued then
        return false
    end
    if not AwaitingSetupPoke() then
        return false
    end
    if not HasInvis(hero) then
        return false
    end
    if (now - Runtime.lastHeroOrderAt) < C.ORDER_GAP then
        return false
    end

    local elapsed
    if ability then
        local start = Ability.GetChannelStartTime(ability)
        if type(start) == "number" and start > 0 then
            elapsed = now - start
        end
    end
    if type(elapsed) ~= "number" then
        elapsed = now - Runtime.channelStartedAt
    end
    local remaining = Runtime.channelExpect - elapsed
    local pokeAt, hitEta = GetAutoPokeRemainingTarget(hero, creep)
    -- Need warp before hit: only swing when channel time left is below hit ETA window.
    if remaining > pokeAt then
        return false
    end
    if remaining < 0.02 then
        return false
    end

    Dbg(
        "POKE attack remaining=%.2f pokeAt=%.2f hitEta=%.2f elapsed=%.2f expect=%.2f creep=%s",
        remaining,
        pokeAt,
        hitEta,
        elapsed,
        Runtime.channelExpect,
        FmtUnit(creep)
    )
    -- Issued here; acceptance is confirmed by OnProjectile / TargetProjectiles latch.
    Player.AttackTarget(player, hero, creep, false, true, false, ORDER_ATTACK, false)
    Runtime.channelPokeIssued = true
    Runtime.setupPokeIssued = true
    Runtime.lastHeroOrderAt = now
    SetStatus(string.format("auto poke (%.2fs left, hit~%.2fs)", math.max(0, remaining), hitEta))
    Dbg("POKE issued via AttackTarget")
    return true
end

---@param handle any
---@return boolean
local function IsValidHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    return type(handle) == "userdata"
end

---@param size any
---@return boolean
local function IsValidTextSize(size)
    return (type(size) == "table" or type(size) == "userdata")
        and type(size.x) == "number"
        and type(size.y) == "number"
end

---@param handle any
---@param sampleText string|nil
---@param fontSize number|nil
---@return boolean
local function CanMeasureWithFont(handle, sampleText, fontSize)
    if not IsValidHandle(handle) or not Render or not Render.TextSize then
        return false
    end
    return IsValidTextSize(
        SafeValue(Render.TextSize, handle, fontSize or PANEL_HEADER_TEXT_SIZE, sampleText or PANEL_TITLE)
    )
end

---@param fontName string
---@param sampleText string|nil
---@return integer|userdata|nil
local function TryLoadPanelFont(fontName, sampleText)
    if not Render or not Render.LoadFont then
        return nil
    end
    local fontFlag = Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0
    local weights = {
        Enum.FontWeight and Enum.FontWeight.SEMIBOLD or 600,
        Enum.FontWeight and Enum.FontWeight.MEDIUM or 500,
        400,
    }
    for i = 1, #weights do
        local handle = SafeValue(Render.LoadFont, fontName, fontFlag, weights[i])
        if CanMeasureWithFont(handle, sampleText) then
            return handle
        end
    end
    local plain = SafeValue(Render.LoadFont, fontName)
    if CanMeasureWithFont(plain, sampleText) then
        return plain
    end
    return nil
end

---@param sampleText string|nil
---@return integer|userdata|nil
local function ResolvePanelFont(sampleText)
    for i = 1, #PANEL_HEADER_FONT_CANDIDATES do
        local handle = TryLoadPanelFont(PANEL_HEADER_FONT_CANDIDATES[i], sampleText)
        if handle then
            return handle
        end
    end
    return nil
end

---@return integer|userdata|nil
local function GetPanelFont()
    if IsValidHandle(Persistent.font) then
        return Persistent.font
    end
    Persistent.font = ResolvePanelFont(PANEL_TITLE)
    return Persistent.font
end

local function EnsureSpellIcon()
    if type(Persistent.spellIcon) == "number" then
        return
    end
    local handle = Render.LoadImage(SPELL_ICON_MELD)
    if type(handle) == "number" and handle ~= 0 then
        Persistent.spellIcon = handle
    end
end

---@param col any
---@return number|nil
---@return number|nil
---@return number|nil
---@return number|nil
local function ColorChannels(col)
    if col == nil then
        return nil
    end
    local r, g, b = col.r, col.g, col.b
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    local a = col.a
    if type(a) ~= "number" then
        a = 255
    end
    -- Some Menu.Style entries are normalized 0..1.
    if r <= 1.0 and g <= 1.0 and b <= 1.0 and a <= 1.0 then
        r, g, b, a = r * 255, g * 255, b * 255, a * 255
    elseif r <= 1.0 and g <= 1.0 and b <= 1.0 then
        r, g, b = r * 255, g * 255, b * 255
    end
    return r, g, b, a
end

---@param r number
---@param g number
---@param b number
---@return boolean
local function IsReadableOnDark(r, g, b)
    return (0.299 * r + 0.587 * g + 0.114 * b) >= 110
end

---@param col any
---@return Color|nil
local function ColorFromChannels(col)
    local r, g, b, a = ColorChannels(col)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    if type(a) ~= "number" then
        a = 255
    end
    return Color(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
end

---@param name string
---@param defaultColor Color
---@return Color
local function GetThemeColor(name, defaultColor)
    if not Menu or not Menu.Style then
        return defaultColor
    end
    local fromStyle = ColorFromChannels(Menu.Style(name))
    if fromStyle then
        return fromStyle
    end
    return defaultColor
end

---Theme keys meant for light menu widgets are often too dark for HUD body text.
---@param name string
---@param defaultColor Color
---@return Color
local function GetReadableThemeColor(name, defaultColor)
    local col = GetThemeColor(name, defaultColor)
    local r, g, b = ColorChannels(col)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return defaultColor
    end
    if not IsReadableOnDark(r, g, b) then
        return defaultColor
    end
    return col
end

local function SyncColors()
    -- Chrome only. Checklist ok/bad/muted stay fixed so theme never paints them black.
    Colors.HeaderBg = GetThemeColor("additional_background", Colors.HeaderBg)
    Colors.TextHeader = GetReadableThemeColor("primary_widgets_text", Colors.TextHeader)
    Colors.TextStatus = GetReadableThemeColor("primary", Colors.TextStatus)
    Colors.TextHint = GetReadableThemeColor("primary", Colors.TextHint)
    Colors.TextWarn = GetReadableThemeColor("indication_error", Colors.TextWarn)
end

local function RefreshBlurStrength()
    local widget = Persistent.blurFactorWidget
    if not widget then
        widget = Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")
        Persistent.blurFactorWidget = widget
    end
    if not widget then
        Persistent.blurStrength = PANEL_BLUR_BASE_STRENGTH
        return
    end
    local factor = widget:Get()
    if type(factor) ~= "number" or factor <= 0 then
        Persistent.blurStrength = nil
        return
    end
    if factor > 1 then
        factor = factor / 100
    end
    Persistent.blurStrength = math.max(0.1, factor * PANEL_BLUR_BASE_STRENGTH)
end

local function LoadPanelPosition()
    local x = ReadInt("panel_x", -1)
    local y = ReadInt("panel_y", 112)
    if type(x) == "number" then
        PanelConfig.X = x
    end
    if type(y) == "number" then
        PanelConfig.Y = y
    end
end

local function SavePanelPosition()
    WriteInt("panel_x", math.floor(PanelConfig.X + 0.5))
    WriteInt("panel_y", math.floor(PanelConfig.Y + 0.5))
end

---@return number|nil
---@return number|nil
local function GetMousePos()
    -- Preserve both returns from Input.GetCursorPos.
    local ok, x, y = TryCall(Input.GetCursorPos)
    if not ok then
        return nil, nil
    end
    if type(x) == "number" and type(y) == "number" then
        return x, y
    end
    if (type(x) == "table" or type(x) == "userdata") and type(x.x) == "number" and type(x.y) == "number" then
        return x.x, x.y
    end
    return nil, nil
end

---@return boolean
local function IsLmbDown()
    return Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) == true
end
--#endregion

--#region Menu
---@param node CSecondTab|CThirdTab|CMenuGroup|nil
local function EnsureMenuVisible(node)
    if node and node.Visible then
        node:Visible(true)
    end
end

---@param heroTab CSecondTab|nil
local function ApplyHeroTabIcon(heroTab)
    if not heroTab then
        return
    end
    heroTab:Image(HERO_ICON)
    local heroId = Engine.GetHeroIDByName(HERO_NAME)
    if heroId then
        heroTab:LinkHero(heroId, Enum.Attributes.DOTA_ATTRIBUTE_AGILITY)
    end
end

---Heroes → Hero List → Templar Assassin
---@return CSecondTab|nil
local function FindOrCreateHeroTab()
    if MenuNodes.hero then
        return MenuNodes.hero
    end

    local heroList = Menu.Find(MENU_FIRST, MENU_SECTION)
    if not heroList then
        return nil
    end

    ---@type CSecondTab|nil
    local heroTab = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB)
    if not heroTab and heroList.Find then
        heroTab = heroList:Find(HERO_TAB)
    end
    if not heroTab and heroList.Create then
        heroTab = heroList:Create(HERO_TAB)
    end
    if not heroTab then
        heroTab = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB)
    end
    if not heroTab then
        return nil
    end

    ApplyHeroTabIcon(heroTab)
    MenuNodes.hero = heroTab
    return heroTab
end

---Heroes → Hero List → Templar Assassin → Abuse Invis
---@return CThirdTab|nil
local function FindOrCreateThirdTab()
    if MenuNodes.tab then
        EnsureMenuVisible(MenuNodes.tab)
        return MenuNodes.tab
    end

    local heroTab = FindOrCreateHeroTab()
    if not heroTab then
        return nil
    end

    ---@type CThirdTab|nil
    local tab = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD)
    if not tab and heroTab.Find then
        tab = heroTab:Find(MENU_THIRD)
    end
    if not tab and heroTab.Create then
        tab = heroTab:Create(MENU_THIRD)
    end
    if not tab then
        tab = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD)
    end
    if not tab then
        return nil
    end

    EnsureMenuVisible(tab)
    MenuNodes.tab = tab
    return tab
end

---@return CMenuGroup|nil
local function FindOrCreateGroup()
    if MenuNodes.group then
        EnsureMenuVisible(MenuNodes.group)
        return MenuNodes.group
    end

    local tab = FindOrCreateThirdTab()
    if not tab then
        return nil
    end

    ---@type CMenuGroup|nil
    local group = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD, MENU_GROUP)
    if not group and tab.Find then
        group = tab:Find(MENU_GROUP)
    end
    if group then
        EnsureMenuVisible(group)
        MenuNodes.group = group
        return group
    end

    ---@type CMenuGroup|nil
    local created = nil
    if tab.Create then
        created = tab:Create(MENU_GROUP, Enum.GroupSide.Left)
    end
    if not created then
        created = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD, MENU_GROUP)
    end
    EnsureMenuVisible(created)
    MenuNodes.group = created
    return created
end

local function EnsureMenu()
    if UI.enabled
        and UI.bind
        and UI.gateType
        and UI.reenterDelay
        and UI.coldTiming
        and UI.protectCreep
        and UI.autoPoke
        and UI.debugLogs
        and UI.targetWarpEta
        and UI.drawHud
        and UI.callbacksAttached
    then
        -- Keep hero tab linked even after widgets already exist (menu can load before Engine is ready).
        if not MenuNodes.hero then
            FindOrCreateHeroTab()
        else
            ApplyHeroTabIcon(MenuNodes.hero)
        end
        SyncColdTimingUi()
        return
    end

    local group = FindOrCreateGroup()
    if not group then
        return
    end

    if not UI.enabled then
        local existing = group:Find("Enable")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or group:Switch("Enable", ReadBool("enabled", false), Icons.enable)
    end
    if UI.enabled and UI.enabled.Icon then
        UI.enabled:Icon(Icons.enable)
    end

    if not UI.bind then
        local existing = group:Find("Sustain Bind")
        ---@cast existing CMenuBind|nil
        UI.bind = existing or group:Bind("Sustain Bind", Enum.ButtonCode.KEY_NONE, Icons.bind)
        if UI.bind and UI.bind.Properties then
            -- markAsToggle for UI hint; runtime still latches via IsPressed (see PollSustainBind).
            UI.bind:Properties("Sustain Bind", nil, true)
        end
        Runtime.sustainOn = ReadBool("bind_toggled", false)
        if UI.bind and UI.bind.SetToggled then
            UI.bind:SetToggled(Runtime.sustainOn)
        end
        if UI.bind and UI.bind.ToolTip then
            UI.bind:ToolTip(
                "Toggle sustain on/off while playing Templar Assassin. Requires Enable.\n"
                    .. "With no key assigned, Enable alone runs sustain."
            )
        end
    end
    if UI.bind and UI.bind.Icon then
        UI.bind:Icon(Icons.bind)
    end

    if not UI.gateType then
        local existing = group:Find("Gate Type")
        ---@cast existing CMenuComboBox|nil
        UI.gateType = existing or group:Combo("Gate Type", GATE_ITEMS, ReadInt("gate_type", GATE_TWIN))
        if UI.gateType and UI.gateType.ToolTip then
            UI.gateType:ToolTip(
                "Twin: twin_gate_portal_warp (4s).\n"
                    .. "Hidden: templar_assassin_hidden_gates (3s); falls back to Twin on the creep."
            )
        end
    end

    if not UI.reenterDelay then
        local existing = group:Find("Re-enter Delay")
        ---@cast existing CMenuSliderFloat|CMenuSliderInt|nil
        local defaultDelay = Clamp(ReadFloat("reenter_delay", C.DEFAULT_REENTER), 2.0, 5.0)
        UI.reenterDelay = existing
            or group:Slider("Re-enter Delay", 2.0, 5.0, defaultDelay, "%.1f s")
        if UI.reenterDelay and UI.reenterDelay.Icon then
            UI.reenterDelay:Icon(Icons.delay)
        end
        if UI.reenterDelay and UI.reenterDelay.ToolTip then
            UI.reenterDelay:ToolTip(
                "Cold Timing only: delay after a warp before the next gate.\n"
                    .. "With projectile tracking, wait is calculated from Target Warp ETA."
            )
        end
    end

    if not UI.coldTiming then
        local existing = group:Find("Cold Timing")
        ---@cast existing CMenuSwitch|nil
        UI.coldTiming = existing or group:Switch("Cold Timing", ReadBool("cold_timing", false), Icons.cold)
        if UI.coldTiming and UI.coldTiming.ToolTip then
            UI.coldTiming:ToolTip(
                "Ignore attack projectile tracking.\n"
                    .. "Keeps ping-ponging gates on Re-enter Delay only — "
                    .. "use when Dota drops the projectile from the list."
            )
        end
    end
    if UI.coldTiming and UI.coldTiming.Icon then
        UI.coldTiming:Icon(Icons.cold)
    end

    if not UI.protectCreep then
        local existing = group:Find("Protect Creep")
        ---@cast existing CMenuSwitch|nil
        UI.protectCreep = existing
            or group:Switch("Protect Creep", ReadBool("protect_creep", true), Icons.protect)
        if UI.protectCreep and UI.protectCreep.ToolTip then
            UI.protectCreep:ToolTip(
                "While sustain runs: drop the dominated creep from selection and\n"
                    .. "block foreign orders on it (procast / other binds), so they cannot break the bug."
            )
        end
    end
    if UI.protectCreep and UI.protectCreep.Icon then
        UI.protectCreep:Icon(Icons.protect)
    end

    if not UI.autoPoke then
        local existing = group:Find("Auto Poke")
        ---@cast existing CMenuSwitch|nil
        UI.autoPoke = existing
            or group:Switch("Auto Poke", ReadBool("auto_poke", true), Icons.poke)
        if UI.autoPoke and UI.autoPoke.ToolTip then
            UI.autoPoke:ToolTip(
                "When on: start sustain without a manual attack.\n"
                    .. "Hero auto-attacks near channel end timed so the warp beats the projectile.\n"
                    .. "If the projectile is missed, re-cast Meld — Auto Poke retries."
            )
        end
    end
    if UI.autoPoke and UI.autoPoke.Icon then
        UI.autoPoke:Icon(Icons.poke)
    end

    if not UI.debugLogs then
        local existing = group:Find("Debug Logs")
        ---@cast existing CMenuSwitch|nil
        UI.debugLogs = existing or group:Switch("Debug Logs", ReadBool("debug_logs", true), Icons.debug)
        if UI.debugLogs and UI.debugLogs.ToolTip then
            UI.debugLogs:ToolTip(
                "Verbose console log: stage changes, gate pick distances, every creep order,\n"
                    .. "holds, selection quarantine, and foreign-order vetoes."
            )
        end
    end
    if UI.debugLogs and UI.debugLogs.Icon then
        UI.debugLogs:Icon(Icons.debug)
    end

    do
        local legacy = group:Find("Min Projectile ETA")
        if legacy and legacy.Visible then
            legacy:Visible(false)
        end
    end

    if not UI.targetWarpEta then
        local existing = group:Find("Target Warp ETA")
        ---@cast existing CMenuSliderFloat|CMenuSliderInt|nil
        local defaultEta = Clamp(
            ReadFloat("target_warp_eta", C.DEFAULT_TARGET_WARP_ETA),
            C.TARGET_WARP_ETA_LO,
            C.TARGET_WARP_ETA_HI
        )
        UI.targetWarpEta = existing
            or group:Slider(
                "Target Warp ETA",
                C.TARGET_WARP_ETA_LO,
                C.TARGET_WARP_ETA_HI,
                defaultEta,
                "%.1f s"
            )
        if UI.targetWarpEta and UI.targetWarpEta.Icon then
            UI.targetWarpEta:Icon(Icons.eta)
        end
        if UI.targetWarpEta and UI.targetWarpEta.ToolTip then
            UI.targetWarpEta:ToolTip(
                "Aim for the gate warp when the attack projectile ETA is near this value (ideal 8-10s).\n"
                    .. "Script starts the channel earlier by channel time (+ walk), so the jump lands on target.\n"
                    .. "Hidden while Cold Timing is on."
            )
        end
    end
    SyncColdTimingUi()

    if not UI.drawHud then
        -- Prefer new name; keep reading legacy "debug" config key.
        local existing = group:Find("Draw HUD") or group:Find("Debug Overlay")
        ---@cast existing CMenuSwitch|nil
        UI.drawHud = existing or group:Switch("Draw HUD", ReadBool("debug", true), Icons.hud)
        if UI.drawHud and UI.drawHud.ToolTip then
            UI.drawHud:ToolTip(
                "Native-style status panel while playing Templar Assassin.\n"
                    .. "Drag the header to move; position is saved.\n"
                    .. "Shows even if Enable is off (setup checklist).\n"
                    .. "Disable creep control in the cheat; keep dominated creep on low HP."
            )
        end
    end
    if UI.drawHud and UI.drawHud.Icon then
        UI.drawHud:Icon(Icons.hud)
    end

    if UI.enabled and not UI.callbacksAttached then
        UI.enabled:SetCallback(function(widget)
            WriteBool("enabled", widget:Get())
            if not widget:Get() then
                ResetRuntime()
            end
        end, false)

        if UI.bind then
            UI.bind:SetCallback(function(widget)
                -- Keep Runtime in sync if the menu toggle widget is clicked.
                local toggled = widget:IsToggled() == true
                if toggled ~= Runtime.sustainOn then
                    Runtime.sustainOn = toggled
                    WriteBool("bind_toggled", toggled)
                    if not toggled then
                        ResetRuntime(true)
                        Runtime.sustainOn = false
                        SetStatus("sustain OFF")
                    else
                        SetStatus("sustain ON")
                    end
                end
            end, false)
        end

        if UI.gateType then
            UI.gateType:SetCallback(function(widget)
                WriteInt("gate_type", widget:Get() or GATE_TWIN)
            end, false)
        end

        if UI.reenterDelay then
            UI.reenterDelay:SetCallback(function(widget)
                WriteFloat("reenter_delay", Clamp(tonumber(widget:Get()) or C.DEFAULT_REENTER, 2.0, 5.0))
            end, false)
        end

        if UI.coldTiming then
            UI.coldTiming:SetCallback(function(widget)
                WriteBool("cold_timing", widget:Get())
                SyncColdTimingUi()
            end, false)
        end

        if UI.protectCreep then
            UI.protectCreep:SetCallback(function(widget)
                WriteBool("protect_creep", widget:Get())
            end, false)
        end

        if UI.autoPoke then
            UI.autoPoke:SetCallback(function(widget)
                WriteBool("auto_poke", widget:Get())
            end, false)
        end

        if UI.debugLogs then
            UI.debugLogs:SetCallback(function(widget)
                WriteBool("debug_logs", widget:Get())
                if widget:Get() then
                    Dbg("debug logs ON")
                end
            end, false)
        end

        if UI.targetWarpEta then
            UI.targetWarpEta:SetCallback(function(widget)
                WriteFloat(
                    "target_warp_eta",
                    Clamp(
                        tonumber(widget:Get()) or C.DEFAULT_TARGET_WARP_ETA,
                        C.TARGET_WARP_ETA_LO,
                        C.TARGET_WARP_ETA_HI
                    )
                )
            end, false)
        end

        if UI.drawHud then
            UI.drawHud:SetCallback(function(widget)
                WriteBool("debug", widget:Get())
            end, false)
        end

        UI.callbacksAttached = true
    end
end
--#endregion

--#region Logic
---@param now number
---@param player userdata
---@param hero userdata
---@param creep userdata
local function TickSustain(now, player, hero, creep)
    RefreshGates(now)
    local cold = IsColdTiming()
    local playerId = select(1, GetLocalPlayerId())
    local proj, eta = FindAttackProjectile(hero, creep, playerId)
    if not cold and not proj then
        -- UpdateFeature owns Abort + grace; keep pacing on decayed last ETA.
        eta = Runtime.lastEta
        if type(eta) ~= "number" and not AwaitingSetupPoke() then
            return
        end
    end

    local ability, channelExpect, usedFallback = ResolveWarpAbility(creep)
    Runtime.channelExpect = channelExpect
    if usedFallback then
        SetStatus("Hidden missing → Twin fallback")
        Dbg("ABILITY fallback Twin (Hidden missing on creep)")
    end

    local approachPad = EstimateApproachSeconds(creep, ability)
    local startEta, targetWarp = GetGateStartEta(channelExpect, approachPad)
    local etaReady = (not cold) and IsEtaReadyToEnter(eta, startEta)

    if now - Runtime.lastHeartbeatAt >= 1.0 then
        Runtime.lastHeartbeatAt = now
        local cpos = AbsOrigin(creep)
        local nearest, nearestDist = PickNearestGate(creep, nil, "heartbeat")
        local waitLeft = Runtime.stage == STAGE.WAITING and math.max(0, Runtime.waitUntil - now) or -1
        Dbg(
            "HB stage=%s cold=%s eta=%s startEta=%.1f targetWarp=%.1f walk=%.1f etaReady=%s waitLeft=%.1f creep=%s nearest=%s dist=%.0f ability=%s needHold=%s protect=%s",
            tostring(Runtime.stage),
            tostring(cold),
            eta and string.format("%.2f", eta) or "nil",
            startEta,
            targetWarp,
            approachPad,
            tostring(etaReady),
            waitLeft,
            FmtPos(cpos),
            FmtUnit(nearest),
            nearestDist,
            ability and "yes" or "no",
            tostring(Runtime.needHold),
            tostring(IsProtectCreep())
        )
    end

    -- First arm: if projectile ETA is still above the start window, wait for it;
    -- otherwise go immediately (user poke already timed near the window).
    if Runtime.stage == STAGE.ARMED then
        if (not cold) and type(eta) == "number" and eta > startEta + 0.35 then
            EnterWaiting(now, string.format("armed - wait ETA window (eta=%.1f start=%.1f)", eta, startEta))
        else
            local gate, dist = PickNearestGate(creep, nil, "first arm -> approach now")
            Runtime.targetGate = gate
            Runtime.needHold = false
            if gate then
                SetStage(
                    STAGE.APPROACH,
                    string.format(
                        "first arm, target=%s dist=%.0f eta=%s start=%.1f",
                        FmtUnit(gate),
                        dist,
                        eta and string.format("%.1f", eta) or "nil",
                        startEta
                    )
                )
                SetStatus("go nearest gate")
            else
                EnterWaiting(now, "first arm but no gates yet")
            end
        end
    end

    if Runtime.stage == STAGE.WAITING then
        if Runtime.needHold then
            if HoldCreep(player, creep, now, "waiting: pin at gate") then
                Runtime.needHold = false
            end
        end

        -- Recompute after possible EnterWaiting in the ARMED branch this tick.
        local safetyTimeout = now >= Runtime.waitUntil
        local goNow = false
        local goWhy = ""
        if cold then
            goNow = safetyTimeout
            goWhy = "cold delay"
        elseif Runtime.waitByEta then
            if etaReady then
                goNow = true
                goWhy = string.format(
                    "ETA %.1f<=%.1f (warp@%.1f ch=%.1f walk=%.1f)",
                    eta,
                    startEta,
                    targetWarp,
                    channelExpect,
                    approachPad
                )
            elseif safetyTimeout then
                goNow = true
                goWhy = "ETA wait safety timeout"
            end
        else
            goNow = safetyTimeout or etaReady
            goWhy = etaReady and "ETA ready" or "delay"
        end

        if goNow then
            local gate, dist = PickNearestGate(creep, nil, "wait->approach " .. goWhy)
            Runtime.targetGate = gate
            if not Runtime.targetGate then
                SetStatus("no twin gates")
                Dbg("WAIT end but no gates found")
                return
            end
            SetStage(STAGE.APPROACH, string.format("target=%s dist=%.0f | %s", FmtUnit(gate), dist, goWhy))
            Runtime.needHold = false
            SetStatus(goWhy)
            Dbg("WAIT done -> approach | %s", goWhy)
        else
            if Runtime.waitByEta and type(eta) == "number" then
                SetStatus(
                    string.format(
                        "hold ETA %.1f → go@%.1f (warp@%.1f)",
                        eta,
                        startEta,
                        targetWarp
                    )
                )
            else
                local left = Runtime.waitUntil - now
                SetStatus(string.format("%shold %.1fs by gate", cold and "cold " or "", left))
            end
            return
        end
    end

    if Runtime.stage == STAGE.APPROACH then
        local gate = Runtime.targetGate
        if not IsValidUnit(gate) then
            local g, d = PickNearestGate(creep, nil, "approach retarget")
            Runtime.targetGate = g
            gate = Runtime.targetGate
            Dbg("APPROACH retarget %s dist=%.0f", FmtUnit(g), d)
        end
        if not IsValidUnit(gate) then
            SetStatus("gate lost")
            Dbg("APPROACH gate lost")
            return
        end

        local creepPos = AbsOrigin(creep)
        local gatePos = AbsOrigin(gate)
        local dist = Dist2D(creepPos, gatePos) or math.huge
        local castRange = ability and GetCastRange(ability) or C.CAST_RANGE_FALLBACK

        if ability and dist <= (castRange + C.CAST_RANGE_PAD) then
            local alreadyChannelling = Ability.IsChannelling(ability) == true
                or NPC.IsChannellingAbility(creep) == true
            if alreadyChannelling then
                SetStage(STAGE.CHANNEL, "already channeling")
                Runtime.channelStartedAt = now
                Runtime.channelConfirmed = true
                Runtime.creepPosAtChannel = creepPos
                Runtime.channelPokeIssued = false
                SetStatus("channel start")
                return
            end
            if not CanOrder(now) then
                Dbg("APPROACH cast throttle dist=%.0f", dist)
                SetStatus(string.format("cast ready %.0f (throttle)", dist))
                return
            end
            local castOk = IssueCreepOrder(
                player,
                creep,
                ORDER_CAST_TARGET,
                gate,
                ability,
                ORDER_CAST,
                string.format("in cast range %.0f<=%.0f", dist, castRange + C.CAST_RANGE_PAD)
            )
            if not castOk then
                SetStatus("cast failed - retry")
                return
            end
            SetStage(STAGE.CHANNEL, "cast in range")
            Runtime.channelStartedAt = now
            Runtime.channelConfirmed = false
            Runtime.creepPosAtChannel = creepPos
            Runtime.channelPokeIssued = false
            SetStatus("channel start")
            return
        end

        -- Near gate without ability yet: walk onto the gate (right-click style).
        if dist <= (C.CAST_RANGE_FALLBACK + C.CAST_RANGE_PAD) and not ability then
            if not CanOrder(now) then
                SetStatus("move-to-gate throttle")
                return
            end
            if not IssueCreepOrder(
                player,
                creep,
                ORDER_MOVE_TARGET,
                gate,
                nil,
                ORDER_MOVE,
                "no warp ability yet, move-to-gate"
            )
            then
                return
            end
            SetStage(STAGE.CHANNEL, "move-to-gate no ability")
            Runtime.channelStartedAt = now
            Runtime.channelConfirmed = false
            Runtime.creepPosAtChannel = creepPos
            Runtime.channelPokeIssued = false
            SetStatus("move-to-gate channel")
            return
        end

        if CanOrder(now) then
            IssueCreepOrder(
                player,
                creep,
                ORDER_MOVE_TARGET,
                gate,
                nil,
                ORDER_MOVE,
                string.format("walk to nearest gate dist=%.0f range=%.0f", dist, castRange)
            )
        else
            Dbg("APPROACH move throttle dist=%.0f target=%s", dist, FmtUnit(gate))
        end
        SetStatus(string.format("approach nearest %.0f", dist))
        return
    end

    if Runtime.stage == STAGE.CHANNEL then
        local gate = Runtime.targetGate
        local channeling = ability and Ability.IsChannelling(ability) == true
        if not channeling and NPC.IsChannellingAbility(creep) == true then
            channeling = true
        end
        if channeling then
            Runtime.channelConfirmed = true
        end
        local creepPos = AbsOrigin(creep)
        local jumped = false
        local jumpDist = -1
        if Runtime.creepPosAtChannel and creepPos then
            local jumpSqr = DistSqr2D(Runtime.creepPosAtChannel, creepPos)
            if type(jumpSqr) == "number" then
                jumpDist = math.sqrt(jumpSqr)
                jumped = jumpSqr >= (C.WARP_JUMP_DIST * C.WARP_JUMP_DIST)
            end
        end

        -- Only lock re-cast after the gate channel actually started (or poke mid-channel).
        local noRecast = Runtime.channelConfirmed
            and (
                Runtime.setupPokeIssued
                or Runtime.channelPokeIssued
                or Runtime.projHandle ~= nil
                or type(Runtime.lastEta) == "number"
            )

        if channeling then
            if TryAutoPoke(player, hero, creep, ability, now) then
                return
            end
            if AwaitingSetupPoke() then
                local start = ability and Ability.GetChannelStartTime(ability)
                local elapsed = (type(start) == "number" and start > 0) and (now - start)
                    or (now - Runtime.channelStartedAt)
                local left = Runtime.channelExpect - elapsed
                local pokeAt = select(1, GetAutoPokeRemainingTarget(hero, creep))
                SetStatus(string.format("channel %.1fs → poke@%.1fs", math.max(0, left), pokeAt))
            else
                SetStatus(noRecast and "channeling (proj locked)" or "channeling")
            end
            return
        end

        local elapsed = now - Runtime.channelStartedAt
        if jumped then
            Runtime.lastGate = gate
            Dbg(
                "CHANNEL done jumped=true jumpDist=%.0f elapsed=%.2f expect=%.2f creep=%s",
                jumpDist,
                elapsed,
                Runtime.channelExpect,
                FmtPos(creepPos)
            )
            EnterWaiting(now, "warped - hold")
            if HoldCreep(player, creep, now, "after warp") then
                Runtime.needHold = false
            end
            return
        end

        -- Channel never started / failed to warp: retry approach (do not sit in ETA wait).
        if elapsed >= (Runtime.channelExpect + C.CHANNEL_SLACK) then
            Dbg(
                "CHANNEL fail no-jump elapsed=%.2f confirmed=%s creep=%s -> retry approach",
                elapsed,
                tostring(Runtime.channelConfirmed),
                FmtPos(creepPos)
            )
            SetStage(STAGE.APPROACH, "retry after no-jump timeout")
            Runtime.channelStartedAt = -math.huge
            Runtime.channelConfirmed = false
            Runtime.creepPosAtChannel = nil
            Runtime.needHold = false
            SetStatus("retry gate cast")
            return
        end

        if noRecast then
            SetStatus(
                string.format(
                    "await warp %.1fs (no re-cast, eta=%s)",
                    math.max(0, Runtime.channelExpect - elapsed),
                    type(Runtime.lastEta) == "number" and string.format("%.2f", Runtime.lastEta) or "--"
                )
            )
            return
        end

        -- Wind-up or cast never stuck: keep issuing until channelConfirmed.
        if ability and IsValidUnit(gate) and CanOrder(now) then
            IssueCreepOrder(player, creep, ORDER_CAST_TARGET, gate, ability, ORDER_CAST, "re-cast while waiting channel")
            SetStatus(Runtime.channelConfirmed and "re-cast gate" or "start channel cast")
            return
        end
        if IsValidUnit(gate) and CanOrder(now) then
            IssueCreepOrder(player, creep, ORDER_MOVE_TARGET, gate, nil, ORDER_MOVE, "re-move while waiting channel")
            SetStatus("re-move gate")
            return
        end

        SetStatus(string.format("channel %.1fs", elapsed))
        return
    end
end

local function UpdateFeature(now)
    local hero = Heroes.GetLocal()
    if not IsValidUnit(hero) then
        Abort("no hero")
        return
    end
    ---@cast hero userdata
    if not IsTemplarAssassin(hero) then
        return
    end

    local playerId, player = GetLocalPlayerId()
    if not player or playerId == nil then
        Abort("no player")
        return
    end
    ---@cast player userdata

    local creep = Runtime.creep
    if not IsCreepCandidate(creep, playerId, hero) then
        creep = FindCreep(player, playerId, hero)
        Runtime.creep = creep
    end

    local cold = IsColdTiming()
    -- Projectile scan can pin the dominated creep even when selection is empty.
    local proj, _eta, matchedCreep = FindAttackProjectile(hero, creep, playerId)
    if matchedCreep and IsCreepCandidate(matchedCreep, playerId, hero) then
        if not SameUnit(Runtime.creep, matchedCreep) then
            Dbg("CREEP pin from projectile %s (was %s)", FmtUnit(matchedCreep), FmtUnit(Runtime.creep))
        end
        Runtime.creep = matchedCreep
        creep = matchedCreep
    end

    if proj then
        -- Setup complete — stop treating this run as "waiting for poke".
        Runtime.setupPokeIssued = false
    end

    if not creep then
        Abort("no creep")
        UpdateHudSnapshot()
        return
    end
    ---@cast creep userdata

    local setupPoke = AwaitingSetupPoke()
    local invis = HasInvis(hero)

    -- Meld ends on the setup attack; once a poke is out / projectile is tracked, keep sustaining visible.
    if not invis then
        local sustainUnlocked = Runtime.projHandle ~= nil
            or type(Runtime.lastEta) == "number"
            or Runtime.setupPokeIssued == true
            or Runtime.channelPokeIssued == true
        if not sustainUnlocked then
            Abort("not invisible")
            UpdateHudSnapshot()
            return
        end
    end

    -- Poke fired but projectile never latched: hold creep and wait for a fresh Meld, then retry.
    if setupPoke and Runtime.setupPokeIssued and not invis then
        SetStatus("Re-cast Meld — Auto Poke retries next gate")
        if ShouldQuarantineCreep() then
            GuardCreepSelection(player, hero, creep, now)
        end
        HoldCreep(player, creep, now, "wait remeld after poke miss")
        UpdateHudSnapshot(BuildSetupHint())
        return
    end
    if not cold then
        if proj then
            Runtime.projMissingSince = -math.huge
        else
            local armedOrRunning = Runtime.armed or Runtime.stage ~= STAGE.IDLE
            if armedOrRunning then
                if setupPoke then
                    -- Waiting for Auto Poke at channel end; do not treat as lost projectile.
                    Runtime.projMissingSince = -math.huge
                else
                    if Runtime.projMissingSince < 0 then
                        Runtime.projMissingSince = now
                        Dbg(
                            "PROJ miss start (grace %.2fs) lastEta=%s handle=%s",
                            C.PROJ_MISS_GRACE,
                            tostring(Runtime.lastEta),
                            tostring(Runtime.projHandle)
                        )
                    end
                    local missingFor = now - Runtime.projMissingSince
                    if missingFor >= C.PROJ_MISS_GRACE then
                        Abort("projectile gone")
                        UpdateHudSnapshot()
                        return
                    end
                    -- Keep looping on last known ETA while the list blinks.
                    if type(Runtime.lastEta) == "number" and Runtime.lastEtaAt > 0 then
                        local decayed = math.max(0, Runtime.lastEta - (now - Runtime.lastEtaAt))
                        Runtime.lastEta = decayed
                        Runtime.lastEtaAt = now
                    end
                    SetStatus(string.format("proj blink %.1fs", C.PROJ_MISS_GRACE - missingFor))
                end
            elseif not setupPoke then
                SetStatus("Attack creep from Meld while it warps")
                UpdateHudSnapshot()
                return
            end
        end
    end

    if Runtime.stage == STAGE.IDLE then
        if not cold and not proj and not setupPoke then
            SetStatus("Attack creep from Meld while it warps")
            UpdateHudSnapshot()
            return
        end
        Runtime.armed = true
        local armWhy = cold and "cold" or (setupPoke and "auto-poke setup" or "proj")
        SetStage(STAGE.ARMED, string.format("creep=%s mode=%s", FmtUnit(creep), armWhy))
        SetStatus(
            cold and "cold armed - delay loop"
                or (setupPoke and "auto poke: send creep to gate" or "armed - creep loop starting")
        )
        Dbg("ARMED pinned creep=%s at %s mode=%s", FmtUnit(creep), FmtPos(AbsOrigin(creep)), armWhy)
    end

    if ShouldQuarantineCreep() then
        GuardCreepSelection(player, hero, creep, now)
    end

    TickSustain(now, player, hero, creep)
    UpdateHudSnapshot()
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    EnsureMenu()
    LoadPanelPosition()
    SyncColors()
    RefreshBlurStrength()
    Persistent.font = ResolvePanelFont(PANEL_TITLE)
    EnsureSpellIcon()
    LogInfo("loaded")
end

function Script.OnThemeUpdate()
    SyncColors()
    RefreshBlurStrength()
    Persistent.font = ResolvePanelFont(PANEL_TITLE)
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end

    EnsureMenu()
    PollSustainBind()

    if not IsEnabled() then
        if Runtime.stage ~= STAGE.IDLE or Runtime.armed or Runtime.sustainOn then
            ResetRuntime()
        end
        -- Still refresh HUD while on TA so the panel is useful before Enable.
        if IsHudOn() and IsLocalTemplarAssassin() then
            if Runtime.status == "" then
                SetStatus("Enable Abuse Invis in menu")
            end
            UpdateHudSnapshot(BuildSetupHint())
        end
        return
    end

    if not IsFeatureActive() then
        if Runtime.stage ~= STAGE.IDLE or Runtime.armed then
            ResetRuntime(true)
            SetStatus("Press Sustain Bind to start")
        elseif Runtime.status == "" then
            SetStatus("Press Sustain Bind to start")
        end
        UpdateHudSnapshot(BuildSetupHint())
        return
    end

    if not IsLocalTemplarAssassin() then
        UpdateHudSnapshot()
        return
    end

    if Input.IsInputCaptured() then
        UpdateHudSnapshot()
        return
    end

    local now = GameRules.GetGameTime()
    if type(now) ~= "number" then
        return
    end
    if now - Runtime.lastUpdateAt < C.UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    UpdateFeature(now)
end

function Script.OnProjectile(
    _data,
    source,
    target,
    _ability,
    moveSpeed,
    _sourceAttachment,
    _particleSystemHandle,
    _dodgeable,
    isAttack,
    _expireTime,
    maxImpactTime,
    _launch_tick,
    _colorGemColor,
    _fullName,
    _name,
    handle,
    _target_loc,
    _original_move_speed
)
    if isAttack ~= true then
        return
    end

    local hero = Heroes.GetLocal()
    if not hero or not SameUnit(source, hero) then
        return
    end

    if type(handle) == "number" then
        if Runtime.projHandle ~= nil and Runtime.projHandle ~= handle then
            Dbg("OnProjectile replace handle %s -> %s", tostring(Runtime.projHandle), tostring(handle))
        elseif Runtime.projHandle == nil then
            Dbg("OnProjectile latch handle=%s target=%s", tostring(handle), FmtUnit(target))
        end
        Runtime.projHandle = handle
        Runtime.projMissingSince = -math.huge
    end

    local now = GameRules.GetGameTime() or 0
    if type(maxImpactTime) == "number" then
        Runtime.lastEta = math.max(0, maxImpactTime - now)
        Runtime.lastEtaAt = now
    elseif type(moveSpeed) == "number" and moveSpeed > 1 and target then
        local heroPos = AbsOrigin(hero)
        local targetPos = AbsOrigin(target)
        local dist = Dist2D(heroPos, targetPos)
        if dist then
            Runtime.lastEta = dist / moveSpeed
            Runtime.lastEtaAt = now
        end
    end

    local playerId = select(1, GetLocalPlayerId())
    if target and playerId ~= nil and IsCreepCandidate(target, playerId, hero) then
        if not SameUnit(Runtime.creep, target) then
            Dbg("OnProjectile pin creep %s", FmtUnit(target))
        end
        Runtime.creep = target
    end
end

function Script.OnPrepareUnitOrders(data, _player, order, _target, _position, _ability, orderIssuer, npc)
    local identifier = type(data) == "table" and data.identifier or nil
    if type(identifier) == "string" and identifier:sub(1, #ORDER_PREFIX) == ORDER_PREFIX then
        return true
    end

    -- Deliberate veto: foreign orders on the pinned gate creep break Meld sustain.
    if ShouldQuarantineCreep() and OrderNpcIsPinnedCreep(npc) then
        local now = GameRules.GetGameTime() or 0
        if now - Runtime.lastVetoLogAt >= 0.35 then
            Runtime.lastVetoLogAt = now
            Dbg(
                "VETO foreign order=%s issuer=%s npc=%s id=%s",
                tostring(order),
                tostring(orderIssuer),
                FmtUnit(type(npc) == "table" and npc[1] or npc),
                tostring(identifier)
            )
        end
        return false
    end

    return true
end

function Script.OnGameEnd()
    ResetRuntime()
    PanelDrag.IsDragging = false
    Persistent.wasMousePressed = false
end
--#endregion

--#region Draw
---@param font any
---@param size number
---@param text string
---@return number
---@return number
local function MeasurePanelText(font, size, text)
    local fallbackW = #text * size * 0.55
    if not IsValidHandle(font) or not Render or not Render.TextSize then
        return fallbackW, size
    end
    local measured = SafeValue(Render.TextSize, font, size, text)
    local mw = measured and measured.x or nil
    local mh = measured and measured.y or nil
    if type(mw) == "number" and type(mh) == "number" then
        return mw, mh
    end
    return fallbackW, size
end

---@param font any
---@param size number
---@param text string
---@param pos Vec2
---@param color Color
local function DrawPanelText(font, size, text, pos, color)
    if not IsValidHandle(font) then
        return
    end
    Render.Text(font, size, text, Vec2(pos.x + 1, pos.y + 1), Color(0, 0, 0, 140))
    Render.Text(font, size, text, pos, color)
end

---@return boolean
local function IsPanelHeaderTransparent()
    local alpha = Colors.HeaderBg.a
    if alpha == nil then
        alpha = 255
    end
    return alpha < 255
end

---@param layout { x: number, y: number, width: number, titleH: number }
---@param scale number
local function DrawPanelBlur(layout, scale)
    if not IsPanelHeaderTransparent() then
        return
    end
    local strength = Persistent.blurStrength
    if type(strength) ~= "number" then
        return
    end
    Render.Blur(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        strength,
        1.0,
        PANEL_HEADER_RADIUS * scale,
        DRAW_FLAGS_NONE
    )
end

---@param ok boolean|nil
---@return string
local function CheckMark(ok)
    if ok == true then
        return "+"
    end
    if ok == false then
        return "-"
    end
    return "~"
end

---@param scale number
---@param screenSize { x: number, y: number }
---@param font any
---@return table
local function GetPanelLayout(scale, screenSize, font)
    local h = Runtime.hud
    local active = h.sustain == true
    local stageLabel = STAGE_LABEL[Runtime.stage] or Runtime.stage
    local etaText = type(Runtime.lastEta) == "number" and string.format("%.2fs", Runtime.lastEta) or "--"
    local waitText = "--"
    if Runtime.stage == STAGE.WAITING then
        local now = GameRules.GetGameTime()
        if type(now) == "number" then
            waitText = string.format("%.1fs", math.max(0, Runtime.waitUntil - now))
        end
    end

    local statusRight = active and stageLabel or "OFF"
    if active and Runtime.stage == STAGE.WAITING then
        statusRight = waitText
    elseif active and type(Runtime.lastEta) == "number" and not h.cold then
        statusRight = etaText
    end

    local checkRows = {
        { text = string.format("[%s]  Sustain", CheckMark(active)), ok = active },
        { text = string.format("[%s]  Meld invis", CheckMark(h.invis)), ok = h.invis },
        { text = string.format("[%s]  Dominated creep", CheckMark(h.creepOk)), ok = h.creepOk },
    }
    if h.cold then
        checkRows[#checkRows + 1] = {
            text = string.format("[~]  Projectile ignored  (ETA %s)", etaText),
            ok = nil,
        }
    else
        checkRows[#checkRows + 1] = {
            text = string.format("[%s]  Attack projectile  ETA %s", CheckMark(h.projOk), etaText),
            ok = h.projOk,
        }
    end

    local timing
    if h.cold then
        timing = string.format("Re-enter in %s", waitText)
    elseif Runtime.waitByEta and Runtime.stage == STAGE.WAITING and type(Runtime.lastEta) == "number" then
        local startEta = GetTargetWarpEta() + (tonumber(Runtime.channelExpect) or C.CHANNEL_TWIN)
        timing = string.format("ETA %s → go@%.1fs (warp@%.1fs)", etaText, startEta, GetTargetWarpEta())
    else
        timing = string.format("Target warp ETA %.1fs   now %s", GetTargetWarpEta(), etaText)
    end
    local hint = BuildSetupHint()
    local dbgLine = nil
    if IsDebugLogsOn() and Runtime.lastDebug ~= "" then
        dbgLine = Runtime.lastDebug
        if #dbgLine > 64 then
            dbgLine = dbgLine:sub(1, 64) .. "..."
        end
        dbgLine = "dbg: " .. dbgLine
    end

    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local bodyPad = PANEL_BODY_PAD * scale
    local rowGap = PANEL_ROW_GAP * scale
    local titleFontSize = PANEL_HEADER_TEXT_SIZE * scale
    local bodyFontSize = PANEL_BODY_TEXT_SIZE * scale
    local hintFontSize = PANEL_HINT_TEXT_SIZE * scale
    local iconSize = PANEL_HEADER_ICON_SIZE * scale
    local iconGap = PANEL_HEADER_ICON_GAP * scale
    local hasIcon = type(Persistent.spellIcon) == "number"

    local titleW, titleTextH = MeasurePanelText(font, titleFontSize, PANEL_TITLE)
    local statusW, statusH = MeasurePanelText(font, titleFontSize, statusRight)
    local headerContentW = (hasIcon and (iconSize + iconGap) or 0) + titleW + iconGap + statusW
    local headerW = padX + headerContentW + padX

    local maxBodyW = 0
    local bodyH = bodyPad
    for i = 1, #checkRows do
        local w, hh = MeasurePanelText(font, bodyFontSize, checkRows[i].text)
        checkRows[i].h = hh
        if w > maxBodyW then
            maxBodyW = w
        end
        bodyH = bodyH + hh + rowGap
    end
    local timingW, timingH = MeasurePanelText(font, bodyFontSize, timing)
    if timingW > maxBodyW then
        maxBodyW = timingW
    end
    bodyH = bodyH + timingH + rowGap

    local hintW, hintH = MeasurePanelText(font, hintFontSize, hint)
    if hintW > maxBodyW then
        maxBodyW = hintW
    end
    bodyH = bodyH + hintH

    local dbgH = 0
    if dbgLine then
        local dbgW
        dbgW, dbgH = MeasurePanelText(font, hintFontSize, dbgLine)
        if dbgW > maxBodyW then
            maxBodyW = dbgW
        end
        bodyH = bodyH + rowGap + dbgH
    end
    bodyH = bodyH + bodyPad

    local width = math.max(headerW, maxBodyW + bodyPad * 2, PANEL_MIN_W * scale)
    local height = titleH + bodyH

    local x = PanelConfig.X
    if type(x) ~= "number" or x < 0 then
        x = math.floor((screenSize.x - width) * 0.5 + 0.5)
    else
        x = Clamp(x, 0, math.max(0, screenSize.x - width))
    end
    local y = Clamp(PanelConfig.Y or 112, 0, math.max(0, screenSize.y - height))

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        titleH = titleH,
        padX = padX,
        bodyPad = bodyPad,
        rowGap = rowGap,
        titleFontSize = titleFontSize,
        bodyFontSize = bodyFontSize,
        hintFontSize = hintFontSize,
        iconSize = iconSize,
        iconGap = iconGap,
        hasIcon = hasIcon,
        titleW = titleW,
        titleTextH = titleTextH,
        statusRight = statusRight,
        statusW = statusW,
        statusH = statusH,
        checkRows = checkRows,
        timing = timing,
        timingH = timingH,
        hint = hint,
        hintH = hintH,
        dbgLine = dbgLine,
        dbgH = dbgH,
        active = active,
        ready = active and h.invis and h.creepOk and (h.cold or h.projOk),
    }
end

---@param layout table
---@param font any
---@param scale number
local function DrawHudPanel(layout, font, scale)
    local radius = PANEL_HEADER_RADIUS * scale

    DrawPanelBlur(layout, scale)

    Render.FilledRect(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        Colors.HeaderBg,
        radius,
        DRAW_FLAGS_NONE
    )

    local contentH = math.max(
        layout.titleTextH,
        layout.hasIcon and layout.iconSize or 0,
        layout.statusH
    )
    local contentY = layout.y + math.floor((layout.titleH - contentH) * 0.5 + 0.5)
    local textX = layout.x + layout.padX

    local spellIcon = Persistent.spellIcon
    if layout.hasIcon and type(spellIcon) == "number" then
        local iconY = contentY + math.floor((contentH - layout.iconSize) * 0.5 + 0.5)
        Render.Image(
            spellIcon,
            Vec2(textX, iconY),
            Vec2(layout.iconSize, layout.iconSize),
            Color(255, 255, 255, 255),
            4 * scale,
            DRAW_FLAGS_NONE
        )
        textX = textX + layout.iconSize + layout.iconGap
    end

    local titleY = contentY + math.floor((contentH - layout.titleTextH) * 0.5 + 0.5)
    local titleColor = layout.ready and Colors.TextOk
        or (layout.active and Colors.TextWarn or Colors.TextHeader)
    DrawPanelText(font, layout.titleFontSize, PANEL_TITLE, Vec2(textX, titleY), titleColor)

    local statusX = layout.x + layout.width - layout.padX - layout.statusW
    local statusY = contentY + math.floor((contentH - layout.statusH) * 0.5 + 0.5)
    local statusColor = layout.active and Colors.TextStatus or Colors.TextMuted
    DrawPanelText(font, layout.titleFontSize, layout.statusRight, Vec2(statusX, statusY), statusColor)

    local bodyTop = layout.y + layout.titleH
    Render.FilledRect(
        Vec2(layout.x, bodyTop),
        Vec2(layout.x + layout.width, layout.y + layout.height),
        Colors.CellBg,
        0,
        DRAW_FLAGS_NONE
    )

    local cursorY = bodyTop + layout.bodyPad
    local bodyX = layout.x + layout.bodyPad
    for i = 1, #layout.checkRows do
        local row = layout.checkRows[i]
        local color = Colors.TextMuted
        if row.ok == true then
            color = Colors.TextOk
        elseif row.ok == false then
            color = Colors.TextBad
        else
            color = Colors.TextWarn
        end
        DrawPanelText(font, layout.bodyFontSize, row.text, Vec2(bodyX, cursorY), color)
        cursorY = cursorY + (row.h or layout.bodyFontSize) + layout.rowGap
    end

    DrawPanelText(font, layout.bodyFontSize, layout.timing, Vec2(bodyX, cursorY), Colors.TextBody)
    cursorY = cursorY + layout.timingH + layout.rowGap
    DrawPanelText(font, layout.hintFontSize, layout.hint, Vec2(bodyX, cursorY), Colors.TextHint)
    if layout.dbgLine then
        cursorY = cursorY + layout.hintH + layout.rowGap
        DrawPanelText(
            font,
            layout.hintFontSize,
            layout.dbgLine,
            Vec2(bodyX, cursorY),
            Color(200, 170, 255, 230)
        )
    end
end

---@param layout table
---@param screenSize { x: number, y: number }
---@param scale number
---@param font any
---@return table
local function UpdatePanelDrag(layout, screenSize, scale, font)
    local mx, my = GetMousePos()
    local isDown = IsLmbDown()
    local isClicked = isDown and not Persistent.wasMousePressed
    local captured = Input.IsInputCaptured() == true

    local isOverHeader = mx ~= nil
        and my ~= nil
        and mx >= layout.x
        and mx <= layout.x + layout.width
        and my >= layout.y
        and my <= layout.y + layout.titleH

    if isClicked and isOverHeader and not captured then
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
        layout = GetPanelLayout(scale, screenSize, font)
    end

    Persistent.wasMousePressed = isDown
    return layout
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if not IsHudOn() then
        PanelDrag.IsDragging = false
        return
    end
    if not IsLocalTemplarAssassin() then
        PanelDrag.IsDragging = false
        return
    end
    if Menu.VisualsIsEnabled() == false then
        return
    end

    local font = GetPanelFont()
    if not IsValidHandle(font) then
        return
    end

    local scale = (Menu.Scale() or 100) / 100
    local screenSize = Render.ScreenSize()
    if not screenSize or type(screenSize.x) ~= "number" or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    EnsureSpellIcon()
    local layout = GetPanelLayout(scale, screenSize, font)
    layout = UpdatePanelDrag(layout, screenSize, scale, font)
    DrawHudPanel(layout, font, scale)
end
--#endregion

return Script
