--[[
    Camera Follow
    Bind the camera to the local hero (Dota-like hold, plus toggle/always).
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "Camera Follow"
local CONFIG_SECTION = "camera_follow"

local MODE_HOLD = 0
local MODE_TOGGLE = 1
local MODE_ALWAYS = 2

local MODE_ITEMS = { "Hold", "Toggle", "Always" }

local MENU_PATH = {
    first = "Scripts",
    section = "Utility",
    second = NAME,
    third = "Main",
    group = "General",
}

-- Font Awesome solid — lens locked on the hero (avoid generic check/power icons).
local Icons = {
    tab = "\u{f21d}", -- street-view — camera orbiting a person
    enable = "\u{f03d}", -- video — follow cam feed
    mode = "\u{f0b2}", -- arrows-alt — Hold / Toggle / Always framing
    hotkey = "\u{f084}", -- key — select-hero style bind
}
--#endregion

--#region State
---@class CameraFollowUI
---@field enabled CMenuSwitch|nil
---@field mode CMenuComboBox|nil
---@field hotkey CMenuBind|nil
---@field callbacksAttached boolean
local UI = {
    enabled = nil,
    mode = nil,
    hotkey = nil,
    callbacksAttached = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
}

local Runtime = {
    following = false,
}
--#endregion

--#region Helpers
local function TryCall(fn, ...)
    if type(fn) ~= "function" then
        return false, "expected a callable function"
    end
    return pcall(fn, ...)
end

local function SafeValue(fn, ...)
    local ok, value = TryCall(fn, ...)
    if not ok then
        return nil
    end
    return value
end

local function ResetRuntime()
    Runtime.following = false
    if UI.hotkey then
        UI.hotkey:SetToggled(false)
    end
end

local function ReadEnabled()
    return Config.ReadInt(CONFIG_SECTION, "enabled", 1) ~= 0
end

local function ReadMode()
    local mode = Config.ReadInt(CONFIG_SECTION, "mode", MODE_HOLD)
    if mode == MODE_TOGGLE or mode == MODE_ALWAYS then
        return mode
    end
    return MODE_HOLD
end

---@return integer
local function GetMode()
    if not UI.mode then
        return MODE_HOLD
    end
    local mode = UI.mode:Get()
    if mode == MODE_TOGGLE or mode == MODE_ALWAYS then
        return mode
    end
    return MODE_HOLD
end

---@return boolean
local function IsHotkeyBound()
    if not UI.hotkey then
        return false
    end
    local key = UI.hotkey:Get()
    return key ~= Enum.ButtonCode.BUTTON_CODE_INVALID
        and key ~= Enum.ButtonCode.KEY_NONE
end

local function SyncHotkeyUi()
    if not UI.hotkey then
        return
    end
    local mode = GetMode()
    UI.hotkey:Disabled(mode == MODE_ALWAYS)
    UI.hotkey:Properties("Camera Follow", nil, mode == MODE_TOGGLE)
end

---@return boolean
local function ShouldFollow()
    local mode = GetMode()
    if mode == MODE_ALWAYS then
        Runtime.following = false
        return true
    end

    if not IsHotkeyBound() then
        Runtime.following = false
        return false
    end

    if mode == MODE_TOGGLE then
        if UI.hotkey:IsPressed() then
            Runtime.following = not Runtime.following
            UI.hotkey:SetToggled(Runtime.following)
        end
        return Runtime.following == true
    end

    Runtime.following = false
    return UI.hotkey:IsDown() == true
end

---@param me userdata
---@return boolean
local function FollowCamera(me)
    local ok, x, y = TryCall(Entity.GetAbsOriginXYZ, me)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end
    Engine.LookAt(x, y)
    return true
end
--#endregion

--#region Menu
---@param widget { Icon?: fun(self: any, icon: string) }|nil
---@param icon string
local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        widget:Icon(icon)
    end
end

local function ApplyTabIcons()
    local second = Menu.Find(MENU_PATH.first, MENU_PATH.section, MENU_PATH.second)
    MenuIcon(second, Icons.tab)
    local third = Menu.Find(MENU_PATH.first, MENU_PATH.section, MENU_PATH.second, MENU_PATH.third)
    MenuIcon(third, Icons.tab)
end

---@return CMenuGroup|nil
local function FindOrCreateGroup()
    local group = Menu.Find(
        MENU_PATH.first,
        MENU_PATH.section,
        MENU_PATH.second,
        MENU_PATH.third,
        MENU_PATH.group
    )
    if group then
        return group
    end

    return Menu.Create(
        MENU_PATH.first,
        MENU_PATH.section,
        MENU_PATH.second,
        MENU_PATH.third,
        MENU_PATH.group
    )
end

local function EnsureMenu()
    if UI.enabled and UI.mode and UI.hotkey and UI.callbacksAttached then
        return
    end

    local group = FindOrCreateGroup()
    if not group then
        return
    end

    if not UI.enabled then
        local existing = group:Find("Enable")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or group:Switch("Enable", ReadEnabled(), Icons.enable)
    end

    if not UI.mode then
        local existing = group:Find("Mode")
        ---@cast existing CMenuComboBox|nil
        UI.mode = existing or group:Combo("Mode", MODE_ITEMS, ReadMode())
        UI.mode:ToolTip(
            "Hold: follow while the hotkey is held (Dota-like).\n"
                .. "Toggle: press to lock/unlock follow.\n"
                .. "Always: follow whenever the script is enabled."
        )
    end

    if not UI.hotkey then
        local existing = group:Find("Hotkey")
        ---@cast existing CMenuBind|nil
        UI.hotkey = existing or group:Bind("Hotkey", Enum.ButtonCode.KEY_F1, Icons.hotkey)
        UI.hotkey:ToolTip("Select-hero style key. Hold or toggle depending on Mode.")
    end

    if UI.enabled and UI.mode and UI.hotkey and not UI.callbacksAttached then
        UI.enabled:SetCallback(function(widget)
            Config.WriteInt(CONFIG_SECTION, "enabled", widget:Get() and 1 or 0)
            if not widget:Get() then
                ResetRuntime()
            end
        end, false)

        UI.mode:SetCallback(function(widget)
            local value = widget:Get() or MODE_HOLD
            if value ~= MODE_TOGGLE and value ~= MODE_ALWAYS then
                value = MODE_HOLD
            end
            Config.WriteInt(CONFIG_SECTION, "mode", value)
            ResetRuntime()
            SyncHotkeyUi()
        end, false)

        UI.callbacksAttached = true
        SyncHotkeyUi()
    end

    MenuIcon(UI.enabled, Icons.enable)
    MenuIcon(UI.mode, Icons.mode)
    MenuIcon(UI.hotkey, Icons.hotkey)
    ApplyTabIcons()
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    EnsureMenu()
    Persistent.logger:info("loaded")
end

function Script.OnUpdate()
    EnsureMenu()
end

-- LookAt on the render path: OnUpdate is tick-rate and feels jerky while moving.
function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end

    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Input.IsInputCaptured() then
        return
    end
    if not ShouldFollow() then
        return
    end

    local me = Heroes.GetLocal()
    if me == nil or SafeValue(Entity.IsAlive, me) ~= true then
        return
    end
    ---@cast me userdata

    FollowCamera(me)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
