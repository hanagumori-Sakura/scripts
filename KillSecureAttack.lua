--[[
    Kill Secure Attack — AA fallback alongside native Kill Stealer.
    When an enemy hero is killable by a normal attack, chase/orbwalk to secure it.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "KillSecureAttack"
local CONFIG_SECTION = "kill_secure_attack"
local UPDATE_INTERVAL = 0.04
local ATTACK_RESEND = 0.12
local MOVE_RESEND = 0.14
local TARGET_SYNC_INTERVAL = 1.0
local DEBUG_HEARTBEAT = 1.25
local STEALER_DB_REFRESH = 2.0
local STEALER_NAMES_PATH = "assets/data/stealer_names.lua"
local DEFAULT_SEARCH = 1400
local HULL_PAD = 8
local MAX_INDICATOR_HITS = 9
local LABEL_FONT_SIZE = 17
local LABEL_Z_EXTRA = 52
local PANEL_PAD_X = 9
local PANEL_PAD_Y = 5
local PANEL_RADIUS = 7
local PANEL_SCREEN_Y_OFFSET = 30
local INDICATOR_ICON_SIZE = 20
local INDICATOR_ICON_GAP = 6
local INDICATOR_SVG_CACHE = "ksa.indicator.finisher_v2"
-- Real-time floors (os.clock) — game time can jump under demo speedup.
local ATTACK_GAP_FLOOR = 0.50
local ATTACK_PENDING_REAL = 0.40
local ATTACK_MIN_FRAMES = 18
-- Custom finisher mark: bullseye + sword (thicker strokes for HUD scale).
local INDICATOR_SVG = [[
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <circle cx="16" cy="16" r="12.5" fill="none" stroke="#ffffff" stroke-width="2.4"/>
  <circle cx="16" cy="16" r="7.2" fill="none" stroke="#ffffff" stroke-width="2.1"/>
  <circle cx="16" cy="16" r="2.6" fill="#ffffff"/>
  <path fill="#ffffff" d="M22.2 4.2l5.6 5.6-2.7 0.7-3.6-3.6 0.7-2.7z"/>
  <path fill="#ffffff" d="M24.4 7.8L13.2 19l-2.8-2.8L21.6 5l2.8 2.8z"/>
  <path fill="#ffffff" d="M10.2 16.2l2.9 2.9-6.2 6.2-2.1 2.1-2.9-2.9 2.1-2.1 6.2-6.2z"/>
</svg>
]]
local INDICATOR_ICON_FALLBACK = "panorama/images/spellicons/axe_culling_blade_png.vtex_c"

local ORDER_PREFIX = "ksa."
local ORDER_ATTACK = ORDER_PREFIX .. "attack"
local ORDER_MOVE = ORDER_PREFIX .. "move"
local ORDER_ATTACK_MOVE = ORDER_PREFIX .. "attack_move"

local STYLE_CURSOR = 0
local STYLE_LOCKED = 1
local STYLE_SCORE = 2

local ETHEREAL_MODS = {
    "modifier_ghost_state",
    "modifier_item_ethereal_blade_ethereal",
    "modifier_pugna_decrepify",
    "modifier_necrolyte_sadist_active",
}

-- Font Awesome solid — thematic, distinct (match Kill Stealer card style).
local Icons = {
    enable = "\u{f71c}",   -- sword — secure the kill
    chase = "\u{f70c}",    -- person-running — auto chase
    orb = "\u{f2f1}",      -- arrows-rotate — attack/move cycle
    range = "\u{f140}",    -- bullseye — attack range buffer
    distance = "\u{f4d7}", -- route — chase distance
    combo = "\u{f500}",    -- user-check — respect combo / locked target
    draw = "\u{f06e}",     -- eye — attack count indicator
    gear = "\u{f013}",     -- cog — Enable settings
    debug = "\u{f188}",    -- bug — debug logs
    ksGate = "\u{f3ed}",   -- shield-halved — wait for KS unavailable
}

-- Fixed R/Y/G ladder (no theme sync). Soft glow uses the same hues.
local Theme = {
    panelBg = Color(12, 12, 16, 235),
    lethal = Color(72, 220, 120, 255),  -- green — last hit
    near = Color(240, 190, 55, 255),    -- yellow — close
    far = Color(220, 64, 64, 255),      -- red — far
    text = Color(255, 255, 255, 255),
    shadow = Color(0, 0, 0, 220),
}
--#endregion

--#region State
---@class KillSecureAttackUI
---@field enabled CMenuSwitch|nil
---@field enableGear CMenuGearAttachment|nil
---@field debug CMenuSwitch|nil
---@field onlyWhenKsUnavailable CMenuSwitch|nil
---@field autoChase CMenuSwitch|nil
---@field orbwalking CMenuSwitch|nil
---@field rangeBuffer CMenuSliderInt|CMenuSliderFloat|nil
---@field chaseDistance CMenuSliderInt|CMenuSliderFloat|nil
---@field respectCombo CMenuSwitch|nil
---@field drawIndicator CMenuSwitch|nil
---@field callbacksAttached boolean
local UI = {
    enabled = nil,
    enableGear = nil,
    debug = nil,
    onlyWhenKsUnavailable = nil,
    autoChase = nil,
    orbwalking = nil,
    rangeBuffer = nil,
    chaseDistance = nil,
    respectCombo = nil,
    drawIndicator = nil,
    callbacksAttached = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|userdata|nil
    font = nil,
    ---@type integer|userdata|nil
    indicatorIcon = nil,
    indicatorIconFailed = false,
    ---@type table<string, boolean>|nil
    stealerNames = nil,
    stealerNamesFailed = false,
}

---@class KillSecureAttackIndicator
---@field target userdata
---@field attacks integer
---@field killable boolean

local TargetSel = {
    lastSyncAt = -math.huge,
    ---@type any
    searchRange = nil,
    ---@type any
    style = nil,
}

local Runtime = {
    lastUpdateAt = -math.huge,
    lastAttackAt = -math.huge,
    lastAttackReal = -math.huge,
    nextAttackReal = -math.huge,
    nextAttackFrame = -1,
    attackPendingUntilReal = -math.huge,
    lastMoveAt = -math.huge,
    lastMoveReal = -math.huge,
    debugHeartbeatAt = -math.huge,
    ---@type integer|nil
    lastDebugTargetIndex = nil,
    ---@type userdata|nil
    lastAttackTarget = nil,
    ---@type integer|nil
    lastAttackIndex = nil,
    ---@type userdata|nil
    lockedTarget = nil,
    ---@type integer|nil
    lockedIndex = nil,
    ---@type KillSecureAttackIndicator[]
    indicators = {},
    stealerFlagsAt = -math.huge,
    ---@type table<string, {state: boolean, onlyDraw: boolean}>
    stealerFlags = {},
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

local function ClearIndicators()
    for i = #Runtime.indicators, 1, -1 do
        Runtime.indicators[i] = nil
    end
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastAttackAt = -math.huge
    Runtime.lastAttackReal = -math.huge
    Runtime.nextAttackReal = -math.huge
    Runtime.nextAttackFrame = -1
    Runtime.attackPendingUntilReal = -math.huge
    Runtime.lastMoveAt = -math.huge
    Runtime.lastMoveReal = -math.huge
    Runtime.debugHeartbeatAt = -math.huge
    Runtime.lastDebugTargetIndex = nil
    Runtime.lastAttackTarget = nil
    Runtime.lastAttackIndex = nil
    Runtime.lockedTarget = nil
    Runtime.lockedIndex = nil
    ClearIndicators()
end

---Monotonic-ish client clock; immune to demo game-speed jumps.
---@return number
local function RealNow()
    if type(os) == "table" and type(os.clock) == "function" then
        local t = os.clock()
        if type(t) == "number" then
            return t
        end
    end
    local cur = SafeValue(GlobalVars.GetCurTime)
    if type(cur) == "number" then
        return cur
    end
    return SafeValue(GameRules.GetGameTime) or 0
end

---@param color Color
---@param alpha number
---@return Color
local function WithAlpha(color, alpha)
    return Color(color.r, color.g, color.b, math.floor(math.max(0, math.min(255, alpha))))
end

---@return boolean
local function IsDebugOn()
    return UI.debug ~= nil and UI.debug:Get() == true
end

---@param fmt string
---@param ... any
local function Dbg(fmt, ...)
    if not IsDebugOn() then
        return
    end
    local msg = fmt
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        if ok then
            msg = formatted
        end
    end
    if Persistent.logger then
        Persistent.logger:info(msg)
    else
        print("[KillSecureAttack] " .. msg)
    end
end

---@param unit userdata|nil
---@return string
local function FmtUnit(unit)
    if not unit then
        return "nil"
    end
    local name = SafeValue(NPC.GetUnitName, unit) or "?"
    local short = tostring(name):gsub("^npc_dota_hero_", ""):gsub("^npc_dota_", "")
    return short
end

---@param handle any
---@return boolean
local function IsValidHandle(handle)
    return type(handle) == "number" or type(handle) == "userdata"
end

local function EnsureFont()
    if IsValidHandle(Persistent.font) then
        return Persistent.font
    end
    Persistent.font = SafeValue(Render.LoadFont, "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
        or SafeValue(Render.LoadFont, "Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
        or SafeValue(Render.LoadFont, "Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
    return Persistent.font
end

---@return integer|userdata|nil
local function EnsureIndicatorIcon()
    if IsValidHandle(Persistent.indicatorIcon) then
        return Persistent.indicatorIcon
    end
    if Persistent.indicatorIconFailed or not Render then
        return nil
    end

    if Render.LoadSvgString then
        Persistent.indicatorIcon = SafeValue(
            Render.LoadSvgString,
            INDICATOR_SVG,
            Vec2(32, 32),
            INDICATOR_SVG_CACHE
        )
    end
    if not IsValidHandle(Persistent.indicatorIcon) and Render.LoadImage then
        Persistent.indicatorIcon = SafeValue(Render.LoadImage, INDICATOR_ICON_FALLBACK)
    end
    if not IsValidHandle(Persistent.indicatorIcon) then
        Persistent.indicatorIconFailed = true
        return nil
    end
    return Persistent.indicatorIcon
end

local function ReadBool(key, defaultOn)
    return Config.ReadInt(CONFIG_SECTION, key, defaultOn and 1 or 0) ~= 0
end

local function WriteBool(key, value)
    Config.WriteInt(CONFIG_SECTION, key, value and 1 or 0)
end

local function ReadInt(key, defaultValue)
    return Config.ReadInt(CONFIG_SECTION, key, defaultValue)
end

local function WriteInt(key, value)
    Config.WriteInt(CONFIG_SECTION, key, value)
end

---@param identifier any
---@return boolean
local function IsOurOrder(identifier)
    return type(identifier) == "string" and identifier:sub(1, #ORDER_PREFIX) == ORDER_PREFIX
end

---@param widget { Icon?: fun(self: any, icon: string) }|nil
---@param icon string
local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        widget:Icon(icon)
    end
end

---@param a Vector|nil
---@param b Vector|nil
---@return number
local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
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

---@return integer
local function GetOrderQueueCount()
    local queue = SafeValue(Humanizer.GetOrderQueue)
    if type(queue) ~= "table" then
        return 0
    end
    return #queue
end

---@return table<string, boolean>
local function EnsureStealerNames()
    if Persistent.stealerNames then
        return Persistent.stealerNames
    end
    if Persistent.stealerNamesFailed then
        return {}
    end
    if type(loadfile) ~= "function" then
        Persistent.stealerNamesFailed = true
        return {}
    end
    local loader = loadfile(STEALER_NAMES_PATH)
    if type(loader) ~= "function" then
        Persistent.stealerNamesFailed = true
        Dbg("stealer catalog missing: %s", STEALER_NAMES_PATH)
        return {}
    end
    local ok, result = pcall(loader)
    if ok and type(result) == "table" then
        Persistent.stealerNames = result
        return result
    end
    Persistent.stealerNamesFailed = true
    Dbg("stealer catalog load failed")
    return {}
end

---@param name string|nil
---@return string|nil
local function NormalizeStealerName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if name:find("^item_dagon") then
        return "item_dagon"
    end
    return name
end

---@param now number
local function RefreshStealerFlags(now)
    if (now - Runtime.stealerFlagsAt) < STEALER_DB_REFRESH then
        return
    end
    Runtime.stealerFlagsAt = now
    if type(io) ~= "table" or type(io.open) ~= "function" then
        return
    end
    if type(json) ~= "table" or type(json.decode) ~= "function" then
        return
    end

    local file = io.open("db.json", "r")
    if not file then
        return
    end
    local content = file:read("*a")
    file:close()
    if type(content) ~= "string" or content == "" then
        return
    end

    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" then
        return
    end

    ---@type table<string, {state: boolean, onlyDraw: boolean}>
    local flags = {}
    for key, value in pairs(data) do
        if type(key) == "string" and key:sub(1, 11) == "db.stealer." then
            local rest = key:sub(12)
            local name, field = rest:match("^(.+)%.([%w_]+)$")
            if name and field then
                local entry = flags[name]
                if not entry then
                    entry = { state = true, onlyDraw = false }
                    flags[name] = entry
                end
                if field == "state" then
                    entry.state = value == true
                elseif field == "only_draw" then
                    entry.onlyDraw = value == true
                end
            end
        end
    end
    Runtime.stealerFlags = flags
end

---@param abilityName string|nil
---@return boolean
local function IsStealerConfigured(abilityName)
    local key = NormalizeStealerName(abilityName)
    if not key then
        return false
    end
    local catalog = EnsureStealerNames()
    if not catalog[key] then
        return false
    end
    local flags = Runtime.stealerFlags[key]
    if flags then
        if flags.onlyDraw or flags.state == false then
            return false
        end
    end
    return true
end

---@param ability userdata|nil
---@param me userdata
---@return boolean
local function IsAbilityCastReady(ability, me)
    if not ability then
        return false
    end
    if (SafeValue(Ability.GetLevel, ability) or 0) <= 0 then
        return false
    end
    if SafeValue(Ability.IsPassive, ability) == true then
        return false
    end
    if SafeValue(Ability.IsHidden, ability) == true then
        return false
    end
    local mana = SafeValue(NPC.GetMana, me) or 0
    if SafeValue(Ability.IsCastable, ability, mana) == true then
        return true
    end
    if SafeValue(Ability.IsReady, ability) == true
        and SafeValue(Ability.IsOwnersManaEnough, ability) == true
        and SafeValue(Ability.CanBeExecuted, ability) == true
    then
        return true
    end
    return false
end

local STEALER_LETHAL_KEYS = {
    "kill_threshold",
    "damage_threshold",
    "threshold",
    "damage",
    "AbilityDamage",
    "nuke_damage",
    "strike_damage",
    "shadowraze_damage",
    "raze_damage",
    "base_damage",
    "damage_max",
}

---Whether a ready KS ability/item is likely lethal to this target (so AA should wait).
---@param ability userdata
---@param target userdata
---@return boolean
local function IsLikelyStealerLethal(ability, target)
    local hp = SafeValue(Entity.GetHealth, target) or 0
    if hp <= 0 then
        return false
    end

    local dmg = SafeValue(Ability.GetDamage, ability) or 0
    if type(dmg) == "number" and dmg >= hp then
        return true
    end

    for i = 1, #STEALER_LETHAL_KEYS do
        local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, STEALER_LETHAL_KEYS[i])
        if type(value) == "number" and value > 0 and value >= hp then
            return true
        end
    end

    -- Unknown / non-lethal with current values — do not block AA.
    return false
end

---Returns first configured KS ability/item that is castable and likely lethal to target.
---@param me userdata
---@param now number
---@param target userdata
---@return string|nil
local function FindReadyStealerAbility(me, now, target)
    RefreshStealerFlags(now)
    EnsureStealerNames()

    for i = 0, 31 do
        local ability = SafeValue(NPC.GetAbilityByIndex, me, i)
        if ability then
            local name = SafeValue(Ability.GetName, ability) or SafeValue(Ability.GetBaseName, ability)
            if IsStealerConfigured(name)
                and IsAbilityCastReady(ability, me)
                and IsLikelyStealerLethal(ability, target)
            then
                return NormalizeStealerName(name) or name
            end
        end
    end

    for i = 0, 8 do
        local item = SafeValue(NPC.GetItemByIndex, me, i)
        if item then
            local name = SafeValue(Ability.GetName, item) or SafeValue(Ability.GetBaseName, item)
            if IsStealerConfigured(name)
                and IsAbilityCastReady(item, me)
                and IsLikelyStealerLethal(item, target)
            then
                return NormalizeStealerName(name) or name
            end
        end
    end

    return nil
end

---@param unit userdata|nil
---@param state any
---@return boolean
local function HasState(unit, state)
    if not unit or state == nil then
        return false
    end
    return SafeValue(NPC.HasState, unit, state) == true
end

---@param unit userdata|nil
---@param names string[]
---@return boolean
local function HasAnyNamedModifier(unit, names)
    if not unit then
        return false
    end
    if SafeValue(NPC.HasAnyModifier, unit, names) == true then
        return true
    end
    for i = 1, #names do
        if SafeValue(NPC.HasModifier, unit, names[i]) == true then
            return true
        end
    end
    return false
end
--#endregion

--#region Menu
local GROUP_NAME = "Kill Secure Attack"

---@return CMenuGroup|nil
local function FindOrCreateGroup()
    local group = Menu.Find("General", "Main", "Kill Stealer", "Main", GROUP_NAME)
    if group then
        return group
    end

    ---@type CSecondTab|nil
    local stealer = Menu.Find("General", "Main", "Kill Stealer")
    if not stealer then
        return nil
    end

    local mainPage = stealer:Find("Main")
    if not mainPage and stealer.Create then
        mainPage = stealer:Create("Main")
    end
    if not mainPage then
        return nil
    end

    group = mainPage:Find(GROUP_NAME)
    if group then
        return group
    end
    if mainPage.Create then
        -- Left column card next to Main Settings / Panel Settings.
        return mainPage:Create(GROUP_NAME, Enum.GroupSide.Left)
    end
    return nil
end

local function EnsureMenu()
    if UI.enabled
        and UI.enableGear
        and UI.debug
        and UI.onlyWhenKsUnavailable
        and UI.autoChase
        and UI.orbwalking
        and UI.rangeBuffer
        and UI.chaseDistance
        and UI.respectCombo
        and UI.drawIndicator
        and UI.callbacksAttached
    then
        return
    end

    local group = FindOrCreateGroup()
    if not group then
        return
    end

    if not UI.enabled then
        local existing = group:Find("Enable Kill Secure Attack")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or group:Switch("Enable Kill Secure Attack", ReadBool("enabled", true), Icons.enable)
        MenuIcon(UI.enabled, Icons.enable)
    end

    if UI.enabled and not UI.enableGear then
        UI.enableGear = UI.enabled:Gear("Settings", Icons.gear, true)
    end

    if UI.enableGear and not UI.onlyWhenKsUnavailable then
        local existing = UI.enableGear:Find("Only When KS Unavailable")
        ---@cast existing CMenuSwitch|nil
        UI.onlyWhenKsUnavailable = existing
            or UI.enableGear:Switch("Only When KS Unavailable", ReadBool("only_when_ks_unavailable", true), Icons.ksGate)
        MenuIcon(UI.onlyWhenKsUnavailable, Icons.ksGate)
        if UI.onlyWhenKsUnavailable then
            if UI.onlyWhenKsUnavailable.ToolTip then
                UI.onlyWhenKsUnavailable:ToolTip(
                    "Attack only when configured Kill Stealer abilities/items are unavailable (CD, mana, disabled, only-draw)."
                )
            end
            UI.onlyWhenKsUnavailable:SetCallback(function(widget)
                WriteBool("only_when_ks_unavailable", widget:Get() == true)
            end, false)
        end
    end

    if UI.enableGear and not UI.debug then
        local existing = UI.enableGear:Find("Debug")
        ---@cast existing CMenuSwitch|nil
        UI.debug = existing or UI.enableGear:Switch("Debug", ReadBool("debug", false), Icons.debug)
        MenuIcon(UI.debug, Icons.debug)
        if UI.debug then
            if UI.debug.ToolTip then
                UI.debug:ToolTip(
                    "Logs target pick, skips, attack/chase orders, KS gate, and indicators to the Umbrella console."
                )
            end
            UI.debug:SetCallback(function(widget)
                WriteBool("debug", widget:Get() == true)
                if widget:Get() == true then
                    Dbg("debug ON")
                end
            end, false)
        end
    end

    if not UI.autoChase then
        local existing = group:Find("Auto Chase Killable Target")
        ---@cast existing CMenuSwitch|nil
        UI.autoChase = existing or group:Switch("Auto Chase Killable Target", ReadBool("auto_chase", true), Icons.chase)
        MenuIcon(UI.autoChase, Icons.chase)
    end

    if not UI.orbwalking then
        local existing = group:Find("Orbwalking")
        ---@cast existing CMenuSwitch|nil
        UI.orbwalking = existing or group:Switch("Orbwalking", ReadBool("orbwalking", true), Icons.orb)
        MenuIcon(UI.orbwalking, Icons.orb)
    end

    if not UI.rangeBuffer then
        local existing = group:Find("Attack Range Buffer")
        ---@cast existing CMenuSliderInt|nil
        UI.rangeBuffer = existing or group:Slider("Attack Range Buffer", 0, 150, ReadInt("range_buffer", 50), "%d")
        MenuIcon(UI.rangeBuffer, Icons.range)
    end

    if not UI.chaseDistance then
        local existing = group:Find("Chase Distance")
        ---@cast existing CMenuSliderInt|nil
        UI.chaseDistance = existing or group:Slider("Chase Distance", 0, 1200, ReadInt("chase_distance", 400), "%d")
        MenuIcon(UI.chaseDistance, Icons.distance)
    end

    if not UI.respectCombo then
        local existing = group:Find("Respect Combo Target")
        ---@cast existing CMenuSwitch|nil
        UI.respectCombo = existing or group:Switch("Respect Combo Target", ReadBool("respect_combo", true), Icons.combo)
        MenuIcon(UI.respectCombo, Icons.combo)
    end

    if not UI.drawIndicator then
        local existing = group:Find("Draw Attack Indicator")
        ---@cast existing CMenuSwitch|nil
        UI.drawIndicator = existing or group:Switch("Draw Attack Indicator", ReadBool("draw_indicator", true), Icons.draw)
        MenuIcon(UI.drawIndicator, Icons.draw)
        if UI.drawIndicator then
            UI.drawIndicator:SetCallback(function(widget)
                WriteBool("draw_indicator", widget:Get() == true)
                if widget:Get() ~= true then
                    ClearIndicators()
                end
            end, false)
        end
    end

    if not UI.callbacksAttached then
        if UI.enabled then
            UI.enabled:SetCallback(function(widget)
                WriteBool("enabled", widget:Get() == true)
                if widget:Get() ~= true then
                    ResetRuntime()
                end
            end, false)
        end
        if UI.autoChase then
            UI.autoChase:SetCallback(function(widget)
                WriteBool("auto_chase", widget:Get() == true)
            end, false)
        end
        if UI.orbwalking then
            UI.orbwalking:SetCallback(function(widget)
                WriteBool("orbwalking", widget:Get() == true)
            end, false)
        end
        if UI.rangeBuffer then
            UI.rangeBuffer:SetCallback(function(widget)
                local value = widget:Get()
                if type(value) == "number" then
                    WriteInt("range_buffer", math.floor(value + 0.5))
                end
            end, false)
        end
        if UI.chaseDistance then
            UI.chaseDistance:SetCallback(function(widget)
                local value = widget:Get()
                if type(value) == "number" then
                    WriteInt("chase_distance", math.floor(value + 0.5))
                end
            end, false)
        end
        if UI.respectCombo then
            UI.respectCombo:SetCallback(function(widget)
                WriteBool("respect_combo", widget:Get() == true)
            end, false)
        end
        UI.callbacksAttached = true
    end
end

---@return number
local function GetRangeBuffer()
    if UI.rangeBuffer and UI.rangeBuffer.Get then
        local value = SafeValue(UI.rangeBuffer.Get, UI.rangeBuffer)
        if type(value) == "number" then
            return math.max(0, math.min(150, value))
        end
    end
    return ReadInt("range_buffer", 50)
end

---@return number
local function GetChaseDistance()
    if UI.chaseDistance and UI.chaseDistance.Get then
        local value = SafeValue(UI.chaseDistance.Get, UI.chaseDistance)
        if type(value) == "number" then
            return math.max(0, math.min(1200, value))
        end
    end
    return ReadInt("chase_distance", 400)
end
--#endregion

--#region Target Selection sync
local function MenuFind(...)
    if not Menu or not Menu.Find then
        return nil
    end
    local ok, result = TryCall(Menu.Find, ...)
    if ok then
        return result
    end
    return nil
end

local function SyncTargetSelection(force)
    local now = SafeValue(GameRules.GetGameTime) or 0
    if not force and (now - TargetSel.lastSyncAt) < TARGET_SYNC_INTERVAL then
        return
    end
    TargetSel.lastSyncAt = now
    TargetSel.searchRange = MenuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Search Range"
    )
    TargetSel.style = MenuFind(
        "Heroes", "", "Settings", "General", "Target Selection", "Style"
    )
end

---@return number
local function GetSearchRadius()
    SyncTargetSelection(false)
    local widget = TargetSel.searchRange
    if widget and widget.Get then
        local value = SafeValue(widget.Get, widget)
        if type(value) == "number" and value > 0 then
            return value + GetChaseDistance()
        end
    end
    return DEFAULT_SEARCH
end

---@return integer
local function GetStyleMode()
    SyncTargetSelection(false)
    local widget = TargetSel.style
    if widget and widget.Get then
        local idx = SafeValue(widget.Get, widget)
        if widget.List then
            local items = SafeValue(widget.List, widget)
            if type(items) == "table" and type(idx) == "number" and items[idx + 1] then
                local label = string.lower(tostring(items[idx + 1]))
                if label:find("score", 1, true)
                    or label:find("smart", 1, true)
                    or label:find("auto", 1, true)
                then
                    return STYLE_SCORE
                end
                if label:find("lock", 1, true) then
                    return STYLE_LOCKED
                end
                return STYLE_CURSOR
            end
        end
        if type(idx) == "number" then
            if idx == 0 then
                return STYLE_CURSOR
            end
            if idx == 2 then
                return STYLE_SCORE
            end
            return STYLE_LOCKED
        end
    end
    return STYLE_LOCKED
end
--#endregion

--#region Combat helpers
---@param me userdata
---@return number
local function GetAttackDamage(me)
    local dMin = SafeValue(NPC.GetTrueDamage, me)
    local dMax = SafeValue(NPC.GetTrueMaximumDamage, me)
    if type(dMin) == "number" and dMin > 0 then
        if type(dMax) == "number" and dMax >= dMin then
            return (dMin + dMax) * 0.5
        end
        return dMin
    end
    local minDmg = SafeValue(NPC.GetMinDamage, me) or 0
    local bonusDmg = SafeValue(NPC.GetBonusDamage, me) or 0
    return math.max(0, minDmg + bonusDmg)
end

---@param me userdata
---@param target userdata
---@return number perHit
---@return number barrierAbsorb
local function GetAttackHitStats(me, target)
    local damage = GetAttackDamage(me)
    if damage <= 0 then
        return 0, 0
    end

    local mult = SafeValue(NPC.GetArmorDamageMultiplier, target)
    if type(mult) == "number" then
        damage = damage * mult
    end

    local barrierAbsorb = 0
    local barriers = SafeValue(NPC.GetBarriers, target)
    if type(barriers) == "table" then
        if type(barriers.physical) == "table" and type(barriers.physical.current) == "number" then
            barrierAbsorb = barrierAbsorb + math.max(0, barriers.physical.current)
        end
        if type(barriers.all) == "table" and type(barriers.all.current) == "number" then
            barrierAbsorb = barrierAbsorb + math.max(0, barriers.all.current)
        end
    end

    return math.max(0, damage), barrierAbsorb
end

---@param me userdata
---@param target userdata
---@return number effective
---@return number remaining
---@return boolean killable
local function EstimateAttackKill(me, target)
    local hp = SafeValue(Entity.GetHealth, target) or 0
    if hp <= 0 then
        return 0, 0, false
    end
    if SafeValue(NPC.IsKillable, target) == false then
        return 0, hp, false
    end

    local perHit, barrierAbsorb = GetAttackHitStats(me, target)
    if perHit <= 0 then
        return 0, hp, false
    end

    local firstHit = math.max(0, perHit - barrierAbsorb)
    local remaining = hp - firstHit
    return firstHit, remaining, firstHit >= hp
end

---Attacks needed to kill (barrier applies once on the first hit).
---@param me userdata
---@param target userdata
---@return integer attacks
---@return boolean killable
local function EstimateAttacksToKill(me, target)
    local hp = SafeValue(Entity.GetHealth, target) or 0
    if hp <= 0 then
        return 0, false
    end
    if SafeValue(NPC.IsKillable, target) == false then
        return 0, false
    end

    local perHit, barrierAbsorb = GetAttackHitStats(me, target)
    if perHit <= 0 then
        return 0, false
    end

    local firstHit = math.max(0, perHit - barrierAbsorb)
    if firstHit >= hp then
        return 1, true
    end

    local leftover = hp - firstHit
    local extra = math.ceil(leftover / perHit)
    if extra < 1 then
        extra = 1
    end
    local attacks = 1 + extra
    if attacks > MAX_INDICATOR_HITS then
        return MAX_INDICATOR_HITS + 1, false
    end
    return attacks, attacks == 1
end

---@param me userdata
---@param target userdata
---@return boolean
local function CanAttackTarget(me, target)
    if not me or not target then
        return false
    end
    if SafeValue(Entity.IsAlive, me) ~= true or SafeValue(Entity.IsAlive, target) ~= true then
        return false
    end
    if SafeValue(Entity.IsSameTeam, me, target) == true then
        return false
    end
    if SafeValue(NPC.IsIllusion, target) == true then
        return false
    end
    if SafeValue(NPC.IsHero, target) ~= true and SafeValue(Entity.IsHero, target) ~= true then
        return false
    end

    local states = Enum.modifierState
    if states then
        if HasState(me, states.MODIFIER_STATE_DISARMED) then
            return false
        end
        local blockTarget = {
            states.MODIFIER_STATE_INVULNERABLE,
            states.MODIFIER_STATE_OUT_OF_GAME,
            states.MODIFIER_STATE_ATTACK_IMMUNE,
            states.MODIFIER_STATE_UNSELECTABLE,
        }
        for i = 1, #blockTarget do
            if HasState(target, blockTarget[i]) then
                return false
            end
        end
    end

    if HasAnyNamedModifier(target, ETHEREAL_MODS) then
        return false
    end

    if Humanizer and Humanizer.IsSafeTarget then
        if SafeValue(Humanizer.IsSafeTarget, target) == false then
            return false
        end
    end

    return true
end

---@param me userdata
---@param target userdata
---@param rangeBuffer number
---@return number distance
---@return number attackRange
---@return boolean inRange
local function GetRangeInfo(me, target, rangeBuffer)
    local myPos = SafeValue(Entity.GetAbsOrigin, me)
    local enemyPos = SafeValue(Entity.GetAbsOrigin, target)
    local dist = Dist2D(myPos, enemyPos)
    local base = SafeValue(NPC.GetAttackRange, me) or 150
    local bonus = SafeValue(NPC.GetAttackRangeBonus, me) or 0
    local myHull = SafeValue(NPC.GetHullRadius, me) or 0
    local enemyHull = SafeValue(NPC.GetHullRadius, target) or 0
    local attackRange = base + bonus + myHull + enemyHull + HULL_PAD + rangeBuffer
    return dist, attackRange, dist <= attackRange
end

---@param me userdata
---@param target userdata
---@param distance number
---@return number
local function EstimateHitDelay(me, target, distance)
    local anim = SafeValue(NPC.GetAttackAnimPoint, me)
    if type(anim) ~= "number" or anim < 0 then
        anim = 0.3
    end
    local delay = anim
    if SafeValue(NPC.IsRanged, me) == true then
        local proj = SafeValue(NPC.GetAttackProjectileSpeed, me)
        if type(proj) == "number" and proj > 0 then
            delay = delay + distance / proj
        end
    end
    return delay
end

---@param me userdata
---@return boolean
local function IsBusyCasting(me)
    if SafeValue(NPC.IsChannellingAbility, me) == true then
        return true
    end
    for i = 0, 31 do
        local ability = SafeValue(NPC.GetAbilityByIndex, me, i)
        if ability and SafeValue(Ability.IsInAbilityPhase, ability) == true then
            return true
        end
    end
    for i = 0, 8 do
        local item = SafeValue(NPC.GetItemByIndex, me, i)
        if item and SafeValue(Ability.IsInAbilityPhase, item) == true then
            return true
        end
    end
    return false
end

---@param me userdata
---@param unit userdata|nil
---@return boolean
local function IsValidLockedEnemy(me, unit)
    if not unit or SafeValue(Entity.IsEntity, unit) ~= true then
        return false
    end
    return CanAttackTarget(me, unit)
end
--#endregion

--#region Targeting
---@param me userdata
---@param enemy userdata
---@param damage number
---@param remaining number
---@param dist number
---@param cursor Vector|nil
---@param respectCombo boolean
---@param style integer
---@param cursorHero userdata|nil
---@return number
local function ScoreEnemy(me, enemy, damage, remaining, dist, cursor, respectCombo, style, cursorHero)
    -- Higher = better. Prefer sure kills with less overkill waste / closer.
    local score = 100000 - remaining * 10 - dist * 0.25
    score = score + math.min(damage, 2000) * 0.01

    local enemyPos = SafeValue(Entity.GetAbsOrigin, enemy)
    if cursor and enemyPos then
        local toCursor = Dist2D(cursor, enemyPos)
        score = score - toCursor * 0.35
        if toCursor < 350 then
            score = score + (350 - toCursor) * 2.0
        end
    end

    if respectCombo then
        if cursorHero and cursorHero == enemy then
            score = score + 50000
        end
        if style == STYLE_LOCKED
            and Runtime.lockedTarget
            and Runtime.lockedIndex
            and SafeValue(Entity.GetIndex, enemy) == Runtime.lockedIndex
        then
            score = score + 60000
        end
        if style == STYLE_CURSOR and cursor and enemyPos then
            local toCursor = Dist2D(cursor, enemyPos)
            score = score + math.max(0, 800 - toCursor) * 8
        end
    end

    return score
end

---@param me userdata
---@param respectCombo boolean
---@return userdata|nil
---@return number|nil distance
---@return number|nil attackRange
---@return boolean|nil inRange
local function PickKillableTarget(me, respectCombo)
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not mePos or team == nil then
        return nil
    end

    local searchRadius = GetSearchRadius()
    local rangeBuffer = GetRangeBuffer()
    local style = respectCombo and GetStyleMode() or STYLE_SCORE
    local cursor = SafeValue(Input.GetWorldCursorPos)
    local cursorHero = SafeValue(Input.GetNearestHeroToCursor, team, Enum.TeamType.TEAM_ENEMY)

    if respectCombo and style == STYLE_LOCKED and Runtime.lockedTarget then
        if not IsValidLockedEnemy(me, Runtime.lockedTarget) then
            Runtime.lockedTarget = nil
            Runtime.lockedIndex = nil
        end
    end

    local heroes = SafeValue(
        Heroes.InRadius,
        mePos,
        searchRadius,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}

    local best = nil
    local bestScore = -math.huge
    local bestDist = nil
    local bestRange = nil
    local bestInRange = nil

    for i = 1, #heroes do
        local enemy = heroes[i]
        if CanAttackTarget(me, enemy) then
            local damage, remaining, killable = EstimateAttackKill(me, enemy)
            if killable then
                local dist, attackRange, inRange = GetRangeInfo(me, enemy, rangeBuffer)
                local chaseDist = GetChaseDistance()
                local reachable = inRange or (UI.autoChase and UI.autoChase:Get() == true and dist <= attackRange + chaseDist)
                if reachable then
                    local score = ScoreEnemy(
                        me,
                        enemy,
                        damage,
                        remaining,
                        dist,
                        cursor,
                        respectCombo,
                        style,
                        cursorHero
                    )
                    -- Slight preference for targets we can hit sooner (melee / short projectile).
                    score = score - EstimateHitDelay(me, enemy, dist) * 40
                    if score > bestScore then
                        bestScore = score
                        best = enemy
                        bestDist = dist
                        bestRange = attackRange
                        bestInRange = inRange
                    end
                end
            end
        end
    end

    if best and respectCombo and style == STYLE_LOCKED then
        Runtime.lockedTarget = best
        Runtime.lockedIndex = SafeValue(Entity.GetIndex, best)
    end

    return best, bestDist, bestRange, bestInRange
end
--#endregion

--#region Orders
---@param me userdata
---@param target userdata
---@return boolean
local function IssueAttack(me, target)
    local player = SafeValue(Players.GetLocal)
    if not player then
        return false
    end
    if SafeValue(Entity.IsAlive, target) ~= true then
        return false
    end
    local _, _, killable = EstimateAttackKill(me, target)
    if not killable then
        return false
    end

    local real = RealNow()
    local frame = SafeValue(GlobalVars.GetFrameCount) or 0
    local attacking = SafeValue(NPC.IsAttacking, me) == true

    -- Swing already going — do not re-send.
    if attacking then
        Runtime.attackPendingUntilReal = -math.huge
        return true
    end

    -- Waiting for the previous AttackTarget to start animating.
    if real < Runtime.attackPendingUntilReal then
        return false
    end

    local spa = SafeValue(NPC.GetSecondsPerAttack, me, false)
    if type(spa) ~= "number" or spa <= 0 then
        spa = SafeValue(NPC.GetAttackTime, me) or 1.0
    end
    local minGap = math.max(ATTACK_GAP_FLOOR, spa)

    if real < Runtime.nextAttackReal then
        return false
    end
    if Runtime.nextAttackFrame >= 0 and frame <= Runtime.nextAttackFrame then
        return false
    end
    if (real - Runtime.lastAttackReal) < minGap then
        return false
    end

    -- Lock real-time + frames before the order leaves.
    Runtime.nextAttackReal = real + minGap
    Runtime.attackPendingUntilReal = real + ATTACK_PENDING_REAL
    Runtime.nextAttackFrame = frame + math.max(ATTACK_MIN_FRAMES, math.floor(minGap * 60))

    local targetIndex = SafeValue(Entity.GetIndex, target)
    local ok = TryCall(
        Player.AttackTarget,
        player,
        me,
        target,
        false,
        true,
        true,
        ORDER_ATTACK,
        false
    )
    if ok then
        Runtime.lastAttackAt = SafeValue(GameRules.GetGameTime) or real
        Runtime.lastAttackReal = real
        Runtime.lastAttackTarget = target
        Runtime.lastAttackIndex = targetIndex
        Dbg("order attack → %s (spa=%.2f realGap=%.2f)", FmtUnit(target), spa, minGap)
        return true
    end
    Runtime.nextAttackReal = real + ATTACK_RESEND
    Runtime.attackPendingUntilReal = -math.huge
    Dbg("FAIL attack → %s", FmtUnit(target))
    return false
end

---@param me userdata
---@param pos Vector
---@return boolean
local function IssueMove(me, pos)
    local real = RealNow()
    if (real - Runtime.lastMoveReal) < MOVE_RESEND then
        return false
    end
    local ok = TryCall(NPC.MoveTo, me, pos, false, false, true, true, ORDER_MOVE, false)
    if ok then
        Runtime.lastMoveAt = SafeValue(GameRules.GetGameTime) or real
        Runtime.lastMoveReal = real
        return true
    end
    return false
end

---@param me userdata
---@param pos Vector
---@return boolean
local function IssueAttackMove(me, pos)
    local real = RealNow()
    if (real - Runtime.lastMoveReal) < MOVE_RESEND then
        return false
    end
    local player = SafeValue(Players.GetLocal)
    if not player then
        return false
    end
    local ok = TryCall(
        Player.PrepareUnitOrders,
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
        nil,
        pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        me,
        false,
        false,
        true,
        true,
        ORDER_ATTACK_MOVE,
        false
    )
    if ok then
        Runtime.lastMoveAt = SafeValue(GameRules.GetGameTime) or real
        Runtime.lastMoveReal = real
        return true
    end
    return false
end

---@param now number
---@param me userdata
---@param target userdata
---@param inRange boolean
---@param orbwalking boolean
---@param autoChase boolean
local function ActOnTarget(now, me, target, inRange, orbwalking, autoChase)
    if SafeValue(Entity.IsAlive, target) ~= true then
        return
    end
    local _, _, killable = EstimateAttackKill(me, target)
    if not killable then
        return
    end

    local enemyPos = SafeValue(Entity.GetAbsOrigin, target)
    if not enemyPos then
        Dbg("act skip: no enemy pos (%s)", FmtUnit(target))
        return
    end

    local real = RealNow()
    local spa = SafeValue(NPC.GetSecondsPerAttack, me, false)
    if type(spa) ~= "number" or spa <= 0 then
        spa = SafeValue(NPC.GetAttackTime, me) or 1.0
    end
    local anim = SafeValue(NPC.GetAttackAnimPoint, me)
    if type(anim) ~= "number" or anim < 0 then
        anim = math.min(0.35, spa * 0.35)
    end

    local attacking = SafeValue(NPC.IsAttacking, me) == true
    if attacking then
        Runtime.attackPendingUntilReal = -math.huge
    end

    local canStartAttack = (not attacking)
        and real >= Runtime.nextAttackReal
        and real >= Runtime.attackPendingUntilReal
        and (real - Runtime.lastAttackReal) >= math.max(ATTACK_GAP_FLOOR, spa)

    if inRange then
        if canStartAttack then
            IssueAttack(me, target)
            return
        end
        if orbwalking and attacking == false and (real - Runtime.lastAttackReal) >= anim and real < Runtime.nextAttackReal then
            IssueMove(me, enemyPos)
        elseif IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg(
                "hold swing %s attacking=%s realSince=%.2f spa=%.2f nextReal=%.2f",
                FmtUnit(target),
                tostring(attacking),
                real - Runtime.lastAttackReal,
                spa,
                Runtime.nextAttackReal
            )
        end
        return
    end

    if autoChase then
        if IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("chase %s orb=%s", FmtUnit(target), tostring(orbwalking))
        end
        if orbwalking then
            IssueAttackMove(me, enemyPos)
        else
            IssueMove(me, enemyPos)
        end
    end
end
--#endregion

--#region Update
---@param now number
local function UpdateFeature(now)
    local me = SafeValue(Heroes.GetLocal)
    if not me or SafeValue(Entity.IsAlive, me) ~= true then
        return
    end

    local queue = GetOrderQueueCount()
    if queue > 0 then
        if IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("skip: humanizer queue=%d", queue)
        end
        return
    end
    if IsBusyCasting(me) then
        if IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg("skip: ability phase / channel")
        end
        return
    end

    local respectCombo = (UI.respectCombo and UI.respectCombo:Get()) == true
    local autoChase = (UI.autoChase and UI.autoChase:Get()) == true
    local orbwalking = (UI.orbwalking and UI.orbwalking:Get()) == true

    local target, dist, attackRange, inRange = PickKillableTarget(me, respectCombo)
    if not target or dist == nil or attackRange == nil then
        if IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
            Runtime.debugHeartbeatAt = now
            Dbg(
                "idle: no AA-killable target (search=%.0f chase=%.0f buffer=%.0f combo=%s)",
                GetSearchRadius(),
                GetChaseDistance(),
                GetRangeBuffer(),
                tostring(respectCombo)
            )
        end
        return
    end

    if (UI.onlyWhenKsUnavailable and UI.onlyWhenKsUnavailable:Get()) == true then
        local readyKs = FindReadyStealerAbility(me, now, target)
        if readyKs then
            if IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                Runtime.debugHeartbeatAt = now
                Dbg("skip AA: KS ready & lethal (%s) on %s", readyKs, FmtUnit(target))
            end
            return
        end
    end

    local isInRange = inRange == true
    if not isInRange then
        if not autoChase or dist > attackRange + GetChaseDistance() then
            if IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
                Runtime.debugHeartbeatAt = now
                Dbg(
                    "skip chase %s dist=%.0f range=%.0f chase=%.0f auto=%s",
                    FmtUnit(target),
                    dist,
                    attackRange,
                    GetChaseDistance(),
                    tostring(autoChase)
                )
            end
            return
        end
    end

    local _, remaining, killable = EstimateAttackKill(me, target)
    local attacks = EstimateAttacksToKill(me, target)
    local targetIndex = SafeValue(Entity.GetIndex, target)
    if IsDebugOn()
        and (
            targetIndex ~= Runtime.lastDebugTargetIndex
            or (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT
        )
    then
        Runtime.lastDebugTargetIndex = targetIndex
        Runtime.debugHeartbeatAt = now
        Dbg(
            "secure %s dist=%.0f/%.0f inRange=%s aaLeft=%s killable=%s remHp=%.0f orb=%s chase=%s",
            FmtUnit(target),
            dist,
            attackRange,
            tostring(isInRange),
            tostring(attacks),
            tostring(killable),
            remaining,
            tostring(orbwalking),
            tostring(autoChase)
        )
    end

    ActOnTarget(now, me, target, isInRange, orbwalking, autoChase)
end

---@param me userdata
local function UpdateIndicators(me)
    ClearIndicators()
    if (UI.drawIndicator and UI.drawIndicator:Get()) ~= true then
        return
    end

    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local team = SafeValue(Entity.GetTeamNum, me)
    if not mePos or team == nil then
        return
    end

    local searchRadius = GetSearchRadius()
    local heroes = SafeValue(
        Heroes.InRadius,
        mePos,
        searchRadius,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}

    local out = Runtime.indicators
    local now = SafeValue(GameRules.GetGameTime) or 0
    local summary = nil
    for i = 1, #heroes do
        local enemy = heroes[i]
        if CanAttackTarget(me, enemy) then
            local attacks, killable = EstimateAttacksToKill(me, enemy)
            -- Show when the kill is close enough to matter (last few hits).
            if attacks >= 1 and attacks <= MAX_INDICATOR_HITS then
                out[#out + 1] = {
                    target = enemy,
                    attacks = attacks,
                    killable = killable or attacks == 1,
                }
                if IsDebugOn() then
                    local piece = string.format("%s:x%d", FmtUnit(enemy), attacks)
                    summary = summary and (summary .. ", " .. piece) or piece
                end
            end
        end
    end

    if IsDebugOn() and (now - Runtime.debugHeartbeatAt) >= DEBUG_HEARTBEAT then
        Runtime.debugHeartbeatAt = now
        if summary then
            Dbg("indicators [%s] search=%.0f", summary, searchRadius)
        else
            Dbg("indicators: none in search=%.0f (enemies=%d)", searchRadius, #heroes)
        end
    end
end
--#endregion

--#region Draw
---@param worldPos Vector
---@return Vec2|nil
---@return boolean
local function WorldToScreenPos(worldPos)
    if not Render or not Render.WorldToScreen or not worldPos then
        return nil, false
    end
    local ok, screen, visible = TryCall(Render.WorldToScreen, worldPos)
    if not ok or (type(screen) ~= "userdata" and type(screen) ~= "table") then
        return nil, false
    end
    ---@cast screen Vec2
    if type(screen.x) ~= "number" or type(screen.y) ~= "number" then
        return nil, false
    end
    return screen, visible == true
end

---@param screen Vec2
---@param margin? number
---@return boolean
local function IsOnScreen(screen, margin)
    margin = margin or 80
    local screenSize = SafeValue(Render.ScreenSize)
    if not screenSize or type(screenSize.x) ~= "number" or type(screenSize.y) ~= "number" then
        return true
    end
    return screen.x >= -margin
        and screen.y >= -margin
        and screen.x <= screenSize.x + margin
        and screen.y <= screenSize.y + margin
end

---@param font integer|userdata
---@param size number
---@param text string
---@return number
---@return number
local function MeasureText(font, size, text)
    local textSize = SafeValue(Render.TextSize, font, size, text)
    if textSize and type(textSize.x) == "number" and type(textSize.y) == "number" then
        return textSize.x, textSize.y
    end
    return #text * size * 0.55, size
end

---@param target userdata
---@return Vector|nil
local function GetLabelWorldPos(target)
    local origin = SafeValue(Entity.GetAbsOrigin, target)
    if not origin or type(origin.x) ~= "number" then
        return nil
    end
    local barOffset = SafeValue(NPC.GetHealthBarOffset, target, true) or 0
    return Vector(origin.x, origin.y, origin.z + barOffset + LABEL_Z_EXTRA)
end

---@param attacks integer
---@param killable boolean
---@return Color
local function IndicatorColor(attacks, killable)
    if killable or attacks <= 1 then
        return Theme.lethal
    end
    if attacks <= 3 then
        return Theme.near
    end
    return Theme.far
end

---@param handle integer|userdata|nil
---@param pos Vec2
---@param size number
---@param color Color
local function DrawIndicatorIcon(handle, pos, size, color)
    if not IsValidHandle(handle) or not Render.Image then
        return
    end
    TryCall(
        Render.Image,
        handle,
        pos,
        Vec2(size, size),
        Color(color.r, color.g, color.b, color.a or 255),
        4,
        Enum.DrawFlags.None
    )
end

---@param topLeft Vec2
---@param bottomRight Vec2
---@param color Color
local function DrawSoftGlow(topLeft, bottomRight, color)
    if not Render or not Render.Shadow then
        return
    end
    local flags = Enum.DrawFlags.ShadowCutOutShapeBackground
    -- Outer soft bloom, then tighter halo.
    TryCall(
        Render.Shadow,
        topLeft,
        bottomRight,
        WithAlpha(color, 55),
        22,
        PANEL_RADIUS + 2,
        flags,
        Vec2(0, 0)
    )
    TryCall(
        Render.Shadow,
        topLeft,
        bottomRight,
        WithAlpha(color, 90),
        12,
        PANEL_RADIUS + 1,
        flags,
        Vec2(0, 0)
    )
end

---@param font integer|userdata
---@param ind KillSecureAttackIndicator
local function DrawAttackBadge(font, ind)
    local worldPos = GetLabelWorldPos(ind.target)
    if not worldPos then
        return
    end
    local screen, isVisible = WorldToScreenPos(worldPos)
    if not screen then
        return
    end
    if not isVisible and not IsOnScreen(screen) then
        return
    end

    local label = string.format("x%d", ind.attacks)
    local textW, textH = MeasureText(font, LABEL_FONT_SIZE, label)
    local icon = EnsureIndicatorIcon()
    local hasIcon = IsValidHandle(icon)
    local iconsW = hasIcon and (INDICATOR_ICON_SIZE + INDICATOR_ICON_GAP) or 0
    local contentH = math.max(textH, hasIcon and INDICATOR_ICON_SIZE or 0)
    local panelW = PANEL_PAD_X * 2 + iconsW + textW
    local panelH = PANEL_PAD_Y * 2 + contentH
    local color = IndicatorColor(ind.attacks, ind.killable)
    local border = WithAlpha(color, 235)
    -- Sit just above the HP bar, slightly to the right of center.
    local centerX = screen.x + 48
    local bottomY = screen.y - PANEL_SCREEN_Y_OFFSET
    local topLeft = Vec2(centerX - panelW * 0.5, bottomY - panelH)
    local bottomRight = Vec2(centerX + panelW * 0.5, bottomY)

    DrawSoftGlow(topLeft, bottomRight, color)

    if Render.FilledRect then
        TryCall(Render.FilledRect, topLeft, bottomRight, Theme.panelBg, PANEL_RADIUS)
    end
    if Render.Rect then
        TryCall(
            Render.Rect,
            topLeft,
            bottomRight,
            border,
            PANEL_RADIUS,
            Enum.DrawFlags.None,
            1.8
        )
    end

    local cursorX = topLeft.x + PANEL_PAD_X
    local contentY = topLeft.y + PANEL_PAD_Y
    if hasIcon then
        local iconY = contentY + (contentH - INDICATOR_ICON_SIZE) * 0.5
        DrawIndicatorIcon(icon, Vec2(cursorX, iconY), INDICATOR_ICON_SIZE, color)
        cursorX = cursorX + INDICATOR_ICON_SIZE + INDICATOR_ICON_GAP
    end

    local textPos = Vec2(cursorX, contentY + (contentH - textH) * 0.5)
    TryCall(Render.Text, font, LABEL_FONT_SIZE, label, Vec2(textPos.x + 1, textPos.y + 1), Theme.shadow)
    TryCall(Render.Text, font, LABEL_FONT_SIZE, label, textPos, Theme.text)
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
    if not UI.enabled or UI.enabled:Get() ~= true then
        ClearIndicators()
        return
    end

    local now = GameRules.GetGameTime()
    if type(now) ~= "number" then
        return
    end
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = SafeValue(Heroes.GetLocal)
    if not me or SafeValue(Entity.IsAlive, me) ~= true then
        ClearIndicators()
        return
    end

    UpdateIndicators(me)

    if Input.IsInputCaptured() then
        return
    end

    UpdateFeature(now)
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if (UI.drawIndicator and UI.drawIndicator:Get()) ~= true then
        return
    end

    local indicators = Runtime.indicators
    if #indicators == 0 then
        return
    end

    local font = EnsureFont()
    if not IsValidHandle(font) then
        return
    end
    ---@cast font integer|userdata

    for i = 1, #indicators do
        DrawAttackBadge(font, indicators[i])
    end
end

function Script.OnPrepareUnitOrders(data)
    local identifier = type(data) == "table" and (data.identifier or data.orderIdentifier) or nil
    if IsOurOrder(identifier) then
        return true
    end
    return true
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
