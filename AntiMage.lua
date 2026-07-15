--[[
    Anti-Mage — Ethereal Blade + Mana Void helper.
    Predicts Eblade + Mana Void burst (MR, barriers, ethereal amp), draws a themed
    kill panel with item/ability icons, and optional Auto Cast (Eblade → Void on lethal).
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "AntiMageVoidPredict"
local CONFIG_SECTION = "anti_mage_void_predict"
local UPDATE_INTERVAL = 0.08
local HERO_NAME = "npc_dota_hero_antimage"
local HERO_TAB = "Anti Mage"
local VOID_ABILITY = "antimage_mana_void"
local EBLADE_ITEM = "item_ethereal_blade"
local EBLADE_ETHEREAL_MOD = "modifier_item_ethereal_blade_ethereal"
local GHOST_STATE_MOD = "modifier_ghost_state"
local EBLADE_RANGE_FALLBACK = 800
local EBLADE_RANGE_BUFFER = 100
local VOID_RANGE_FALLBACK = 600
local EBLADE_PROJECTILE_FALLBACK = 1400
local COMBO_COOLDOWN = 0.75
local ETHEREAL_WAIT_BUFFER = 0.12
local ETHEREAL_WAIT_MAX = 1.35
local ORDER_PREFIX = "antimage.void_combo."
local LABEL_FONT_SIZE = 15
local LABEL_Z_EXTRA = 56
local PANEL_SCREEN_Y_OFFSET = 36
local ICON_SIZE = 18
local ICON_GAP = 4
local ICON_TEXT_GAP = 8
local PANEL_PAD_X = 8
local PANEL_PAD_Y = 5
local PANEL_RADIUS = 6
local EBLADE_ICON_PATH = "panorama/images/items/ethereal_blade_png.vtex_c"
local VOID_ICON_PATH = "panorama/images/spellicons/antimage_mana_void_png.vtex_c"
local DEFAULT_KILL_COLOR = Color(80, 220, 120, 255)

-- Runtime Enum has no modifierState; detect via known modifiers.
local MAGIC_IMMUNE_MODS = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
}

local Icons = {
    enable = "\u{f00c}",
    damage = "\u{f54c}",
    kill = "\u{f05b}",
    color = "\u{f53f}",
    range = "\u{f140}",
    autoCast = "\u{f04b}",
}

local Theme = {
    panelBg = Color(10, 10, 14, 230),
    accent = Color(120, 200, 255, 255),
    immune = Color(160, 160, 170, 220),
}

local TEXT_COLOR = Color(235, 240, 248, 255)
local REMAINING_COLOR = Color(190, 200, 215, 235)
--#endregion

--#region State
---@class AntiMageUI
---@field enabled CMenuSwitch|nil
---@field showDamage CMenuSwitch|nil
---@field killHighlight CMenuSwitch|nil
---@field killColor CMenuColorPicker|nil
---@field onlyInRange CMenuSwitch|nil
---@field autoCast CMenuSwitch|nil
---@field callbacksAttached boolean
---@field autoCastCbAttached boolean
local UI = {
    enabled = nil,
    showDamage = nil,
    killHighlight = nil,
    killColor = nil,
    onlyInRange = nil,
    autoCast = nil,
    callbacksAttached = false,
    autoCastCbAttached = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|userdata|nil
    font = nil,
    ---@type integer|userdata|nil
    ebladeIcon = nil,
    ---@type integer|userdata|nil
    voidIcon = nil,
}

---@class AntiMagePrediction
---@field target userdata
---@field damage number
---@field remainingHp number
---@field killable boolean
---@field magicImmune boolean

---@class AntiMageComboState
---@field stage string
---@field target userdata|nil
---@field ebladeIssuedAt number
---@field waitUntil number
---@field lastComboAt number

local Runtime = {
    lastUpdateAt = -math.huge,
    ---@type AntiMagePrediction[]
    predictions = {},
    ---@type AntiMageComboState
    combo = {
        stage = "idle",
        target = nil,
        ebladeIssuedAt = -math.huge,
        waitUntil = -math.huge,
        lastComboAt = -math.huge,
    },
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

local function ResetCombo()
    Runtime.combo.stage = "idle"
    Runtime.combo.target = nil
    Runtime.combo.ebladeIssuedAt = -math.huge
    Runtime.combo.waitUntil = -math.huge
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.predictions = {}
    ResetCombo()
    Runtime.combo.lastComboAt = -math.huge
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

---@param handle integer|userdata|nil
---@return boolean
local function IsValidHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    return type(handle) == "userdata"
end

---@param name string
---@param defaultColor Color
---@return Color
local function GetThemeColor(name, defaultColor)
    if not Menu or not Menu.Style then
        return defaultColor
    end

    local col = SafeValue(Menu.Style, name)
    if col and type(col) == "userdata" then
        ---@cast col Color
        return col
    end

    local tbl = SafeValue(Menu.Style)
    if type(tbl) == "table" and tbl[name] then
        local c = tbl[name]
        if c and type(c.r) == "number" then
            local r, g, b = c.r, c.g, c.b
            local a = c.a or 255
            if r <= 1.0 and g <= 1.0 and b <= 1.0 and (a <= 1.0 or not c.a) then
                r = r * 255
                g = g * 255
                b = b * 255
                a = c.a and (a * 255) or 255
            end
            return Color(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
        end
    end

    return defaultColor
end

---@param color Color
---@param alpha number
---@return Color
local function WithAlpha(color, alpha)
    return Color(color.r, color.g, color.b, alpha)
end

local function SyncThemeColors()
    if not Menu or not Menu.Style then
        return
    end

    Theme.panelBg = WithAlpha(
        GetThemeColor("additional_background", Theme.panelBg),
        230
    )
    Theme.accent = WithAlpha(
        GetThemeColor("primary", Theme.accent),
        255
    )
    Theme.immune = WithAlpha(
        GetThemeColor("indication_error", Theme.immune),
        220
    )
end

local function EnsureFont()
    if IsValidHandle(Persistent.font) then
        return Persistent.font
    end
    Persistent.font = SafeValue(Render.LoadFont, "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
        or SafeValue(Render.LoadFont, "Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
        or SafeValue(Render.LoadFont, "Arial")
    return Persistent.font
end

local function EnsureIcons()
    if Persistent.ebladeIcon == nil and Render and Render.LoadImage then
        Persistent.ebladeIcon = SafeValue(Render.LoadImage, EBLADE_ICON_PATH)
    end
    if Persistent.voidIcon == nil and Render and Render.LoadImage then
        Persistent.voidIcon = SafeValue(Render.LoadImage, VOID_ICON_PATH)
    end
end

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

---@param unit userdata|nil
---@return boolean
local function IsMagicImmune(unit)
    if not unit then
        return true
    end
    for i = 1, #MAGIC_IMMUNE_MODS do
        if SafeValue(NPC.HasModifier, unit, MAGIC_IMMUNE_MODS[i]) == true then
            return true
        end
    end
    return false
end

---@param me userdata
---@return number
local function GetPrimaryStatTotal(me)
    local attr = SafeValue(Hero.GetPrimaryAttribute, me)
    if attr == Enum.Attributes.DOTA_ATTRIBUTE_STRENGTH then
        return SafeValue(Hero.GetStrengthTotal, me) or 0
    end
    if attr == Enum.Attributes.DOTA_ATTRIBUTE_INTELLECT then
        return SafeValue(Hero.GetIntellectTotal, me) or 0
    end
    return SafeValue(Hero.GetAgilityTotal, me) or 0
end

---@param raw number|nil
---@return number
local function SpellAmpMultiplier(raw)
    if type(raw) ~= "number" or raw ~= raw or raw <= 0 then
        return 1
    end
    if raw > 1 then
        return 1 + (raw / 100)
    end
    return 1 + raw
end

---@param target userdata
---@return boolean
local function HasEtherealModifier(target)
    return SafeValue(NPC.HasModifier, target, EBLADE_ETHEREAL_MOD) == true
        or SafeValue(NPC.HasModifier, target, GHOST_STATE_MOD) == true
end

---@param unit userdata|nil
---@return boolean
local function IsHardBlocked(unit)
    if not unit then
        return true
    end
    if SafeValue(NPC.IsLinkensProtected, unit) == true then
        return true
    end
    if SafeValue(NPC.HasModifier, unit, "modifier_item_sphere_target") == true then
        return true
    end
    if SafeValue(NPC.HasModifier, unit, "modifier_antimage_spell_shield") == true then
        return true
    end
    return false
end

---@param unit userdata|nil
---@return boolean
local function IsSafeCastTarget(unit)
    if not unit then
        return false
    end
    if Humanizer and Humanizer.IsSafeTarget then
        local ok, safe = TryCall(Humanizer.IsSafeTarget, unit)
        if ok and safe == false then
            return false
        end
    end
    return true
end

---@param me userdata
---@return boolean
local function CanAct(me)
    if SafeValue(NPC.IsStunned, me) == true then
        return false
    end
    if SafeValue(NPC.IsSilenced, me) == true then
        return false
    end
    return true
end

---@param ability userdata
---@param me userdata
---@return boolean
local function IsAbilityReady(ability, me)
    local mana = SafeValue(NPC.GetMana, me) or 0
    return SafeValue(Ability.IsCastable, ability, mana) == true
end

---@param ability userdata
---@param name string
---@param fallback number
---@return number
local function ReadSpecial(ability, name, fallback)
    local value = SafeValue(Ability.GetLevelSpecialValueFor, ability, name)
    if type(value) ~= "number" or value ~= value then
        return fallback
    end
    return value
end

---@param me userdata
---@param target userdata
---@param eblade userdata
---@return number
local function EstimateEbladeTravel(me, target, eblade)
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    local targetPos = SafeValue(Entity.GetAbsOrigin, target)
    if not mePos or not targetPos or not mePos.Distance2D then
        return 0.55
    end
    local dist = mePos:Distance2D(targetPos)
    if type(dist) ~= "number" or dist < 0 then
        return 0.55
    end
    local speed = ReadSpecial(eblade, "projectile_speed", EBLADE_PROJECTILE_FALLBACK)
    if speed <= 1 then
        speed = EBLADE_PROJECTILE_FALLBACK
    end
    return (dist / speed) + ETHEREAL_WAIT_BUFFER
end

---@param ability userdata
---@param target userdata
---@param tag string
---@return boolean
local function CastOnTarget(ability, target, tag)
    local ok = TryCall(Ability.CastTarget, ability, target, false, true, true, OrderId(tag))
    return ok == true
end

---@param me userdata
---@param eblade userdata
---@return number
local function EstimateEbladeBlastRaw(me, eblade)
    local base = ReadSpecial(eblade, "blast_damage_base", 50)
    local mult = ReadSpecial(eblade, "blast_stat_multiplier", 1)
    return base + (GetPrimaryStatTotal(me) * mult)
end

---@param voidAbility userdata
---@param target userdata
---@return number
local function EstimateManaVoidRaw(voidAbility, target)
    local maxMana = SafeValue(NPC.GetMaxMana, target) or 0
    local mana = SafeValue(NPC.GetMana, target) or 0
    local perMana = ReadSpecial(voidAbility, "mana_void_damage_per_mana", 1)
    return math.max(0, maxMana - mana) * perMana
end

---@param me userdata
---@param target userdata
---@param eblade userdata
---@param voidAbility userdata
---@return number damage
---@return boolean magicImmune
local function EstimateComboDamage(me, target, eblade, voidAbility)
    if IsMagicImmune(target) then
        return 0, true
    end

    local rawTotal = EstimateEbladeBlastRaw(me, eblade) + EstimateManaVoidRaw(voidAbility, target)
    local spellAmp = SpellAmpMultiplier(SafeValue(NPC.GetBaseSpellAmp, me))
    local magicMult = SafeValue(NPC.GetMagicalArmorDamageMultiplier, target) or 1

    if not HasEtherealModifier(target) then
        local etherealBonus = ReadSpecial(eblade, "ethereal_damage_bonus", -30)
        magicMult = magicMult * (1 - (etherealBonus / 100))
    end

    local damage = rawTotal * spellAmp * magicMult
    local barriers = SafeValue(NPC.GetBarriers, target)
    if type(barriers) == "table" then
        local magicBarrier = 0
        local allBarrier = 0
        if type(barriers.magic) == "table" and type(barriers.magic.current) == "number" then
            magicBarrier = math.max(0, barriers.magic.current)
        end
        if type(barriers.all) == "table" and type(barriers.all.current) == "number" then
            allBarrier = math.max(0, barriers.all.current)
        end
        damage = math.max(0, damage - magicBarrier - allBarrier)
    end

    return damage, false
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

---@return CMenuGroup|nil
local function FindOrCreateGroup()
    local group = Menu.Find("Heroes", "Hero List", HERO_TAB, "Main Settings", "Void Combo")
        or Menu.Find("Scripts", "Combat", "Anti-Mage", "Main", "Void Combo")

    if not group then
        local mainSection = Menu.Find("Heroes", "Hero List", HERO_TAB, "Main Settings")
        if mainSection and mainSection.Create then
            group = mainSection:Create("Void Combo")
        end
    end

    return group or Menu.Create("Scripts", "Combat", "Anti-Mage", "Main", "Void Combo")
end

---@param widget { Icon?: fun(self: any, icon: string, offset?: Vec2) }|nil
---@param icon string
local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        widget:Icon(icon)
    end
end

local function EnsureMenu()
    if UI.enabled
        and UI.showDamage
        and UI.killHighlight
        and UI.killColor
        and UI.onlyInRange
        and UI.autoCast
        and UI.callbacksAttached
        and UI.autoCastCbAttached
    then
        return
    end

    local group = FindOrCreateGroup()
    if not group then
        return
    end

    if not UI.enabled then
        local existing = group:Find("Enable")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or group:Switch("Enable", ReadBool("enabled", true), Icons.enable)
    end
    MenuIcon(UI.enabled, Icons.enable)

    if not UI.showDamage then
        local existing = group:Find("Show Damage")
        ---@cast existing CMenuSwitch|nil
        UI.showDamage = existing or group:Switch("Show Damage", ReadBool("show_damage", true), Icons.damage)
    end
    MenuIcon(UI.showDamage, Icons.damage)

    if not UI.killHighlight then
        local existing = group:Find("Kill Highlight")
        ---@cast existing CMenuSwitch|nil
        UI.killHighlight = existing or group:Switch("Kill Highlight", ReadBool("kill_highlight", true), Icons.kill)
    end
    MenuIcon(UI.killHighlight, Icons.kill)

    if not UI.killColor then
        local existing = group:Find("Kill Color")
        ---@cast existing CMenuColorPicker|nil
        UI.killColor = existing or group:ColorPicker("Kill Color", DEFAULT_KILL_COLOR, Icons.color)
    end
    MenuIcon(UI.killColor, Icons.color)

    if not UI.onlyInRange then
        local existing = group:Find("Only in Eblade range")
        ---@cast existing CMenuSwitch|nil
        UI.onlyInRange = existing or group:Switch("Only in Eblade range", ReadBool("only_in_range", true), Icons.range)
    end
    MenuIcon(UI.onlyInRange, Icons.range)

    if not UI.autoCast then
        local existing = group:Find("Auto Cast")
        ---@cast existing CMenuSwitch|nil
        UI.autoCast = existing or group:Switch("Auto Cast", ReadBool("auto_cast", false), Icons.autoCast)
        if UI.autoCast and UI.autoCast.ToolTip then
            UI.autoCast:ToolTip("Auto Eblade → Mana Void when the predicted combo is lethal.")
        end
    end
    MenuIcon(UI.autoCast, Icons.autoCast)

    if UI.autoCast then
        if not UI.callbacksAttached then
            -- callbacks block below will attach
        elseif not UI.autoCastCbAttached then
            UI.autoCast:SetCallback(function(widget)
                WriteBool("auto_cast", widget:Get())
                if not widget:Get() then
                    ResetCombo()
                end
            end, false)
            UI.autoCastCbAttached = true
        end
    end

    if UI.enabled and not UI.callbacksAttached then
        UI.enabled:SetCallback(function(widget)
            WriteBool("enabled", widget:Get())
            if not widget:Get() then
                ResetRuntime()
            end
        end, false)

        if UI.showDamage then
            UI.showDamage:SetCallback(function(widget)
                WriteBool("show_damage", widget:Get())
            end, false)
        end

        if UI.killHighlight then
            UI.killHighlight:SetCallback(function(widget)
                WriteBool("kill_highlight", widget:Get())
            end, false)
        end

        if UI.onlyInRange then
            UI.onlyInRange:SetCallback(function(widget)
                WriteBool("only_in_range", widget:Get())
            end, false)
        end

        if UI.autoCast then
            UI.autoCast:SetCallback(function(widget)
                WriteBool("auto_cast", widget:Get())
                if not widget:Get() then
                    ResetCombo()
                end
            end, false)
            UI.autoCastCbAttached = true
        end

        UI.callbacksAttached = true
    end
end

local function UpdatePredictions()
    Runtime.predictions = {}

    local me = SafeValue(Heroes.GetLocal)
    if not me
        or SafeValue(NPC.GetUnitName, me) ~= HERO_NAME
        or SafeValue(Entity.IsAlive, me) ~= true
    then
        return
    end

    local eblade = SafeValue(NPC.GetItem, me, EBLADE_ITEM, true)
    local voidAbility = SafeValue(NPC.GetAbility, me, VOID_ABILITY)
    if not eblade or not voidAbility then
        return
    end
    if (SafeValue(Ability.GetLevel, voidAbility) or 0) <= 0 then
        return
    end

    local onlyInRange = UI.onlyInRange and UI.onlyInRange:Get()
    local ebladeRange = SafeValue(Ability.GetCastRange, eblade) or EBLADE_RANGE_FALLBACK
    if ebladeRange <= 0 then
        ebladeRange = EBLADE_RANGE_FALLBACK
    end
    local maxRange = ebladeRange + EBLADE_RANGE_BUFFER

    local heroes = SafeValue(Heroes.GetAll) or {}
    for i = 1, #heroes do
        local target = heroes[i]
        if target
            and target ~= me
            and SafeValue(Entity.IsSameTeam, me, target) ~= true
            and SafeValue(Entity.IsAlive, target) == true
            and SafeValue(Entity.IsDormant, target) ~= true
            and SafeValue(NPC.IsVisible, target) == true
            and (not onlyInRange or SafeValue(NPC.IsEntityInRange, me, target, maxRange) == true)
        then
            local damage, magicImmune = EstimateComboDamage(me, target, eblade, voidAbility)
            local hp = SafeValue(Entity.GetHealth, target) or 0
            Runtime.predictions[#Runtime.predictions + 1] = {
                target = target,
                damage = damage,
                remainingHp = math.max(0, hp - damage),
                killable = (not magicImmune) and damage >= hp and hp > 0,
                magicImmune = magicImmune,
            }
        end
    end
end

---@param me userdata
---@param target userdata
---@param voidAbility userdata
---@param range number
---@return boolean
local function CanVoidTarget(me, target, voidAbility, range)
    if SafeValue(Entity.IsAlive, target) ~= true then
        return false
    end
    if SafeValue(Entity.IsDormant, target) == true then
        return false
    end
    if SafeValue(NPC.IsVisible, target) ~= true then
        return false
    end
    if IsMagicImmune(target) or IsHardBlocked(target) or not IsSafeCastTarget(target) then
        return false
    end
    if not IsAbilityReady(voidAbility, me) then
        return false
    end
    return SafeValue(NPC.IsEntityInRange, me, target, range) == true
end

---@param now number
---@param me userdata
---@param eblade userdata
---@param voidAbility userdata
local function UpdateAutoCast(now, me, eblade, voidAbility)
    if not UI.autoCast or not UI.autoCast:Get() then
        if Runtime.combo.stage ~= "idle" then
            ResetCombo()
        end
        return
    end

    if Input and Input.IsInputCaptured and SafeValue(Input.IsInputCaptured) == true then
        return
    end

    local combo = Runtime.combo
    local voidRange = SafeValue(Ability.GetCastRange, voidAbility) or VOID_RANGE_FALLBACK
    if voidRange <= 0 then
        voidRange = VOID_RANGE_FALLBACK
    end
    local castBonus = SafeValue(NPC.GetCastRangeBonus, me) or 0
    voidRange = voidRange + castBonus

    if combo.stage == "wait_ethereal" then
        local target = combo.target
        if not target
            or not CanAct(me)
            or SafeValue(Entity.IsAlive, target) ~= true
            or SafeValue(NPC.IsVisible, target) ~= true
            or IsMagicImmune(target)
        then
            ResetCombo()
            return
        end

        if HasEtherealModifier(target) then
            if CanVoidTarget(me, target, voidAbility, voidRange)
                and CastOnTarget(voidAbility, target, "void")
            then
                combo.lastComboAt = now
            end
            ResetCombo()
            return
        end

        if now >= combo.waitUntil then
            ResetCombo()
            combo.lastComboAt = now
        end
        return
    end

    if now - combo.lastComboAt < COMBO_COOLDOWN then
        return
    end
    if not CanAct(me) then
        return
    end

    local ebladeRange = SafeValue(Ability.GetCastRange, eblade) or EBLADE_RANGE_FALLBACK
    if ebladeRange <= 0 then
        ebladeRange = EBLADE_RANGE_FALLBACK
    end
    ebladeRange = ebladeRange + castBonus

    ---@type AntiMagePrediction|nil
    local best = nil
    for i = 1, #Runtime.predictions do
        local pred = Runtime.predictions[i]
        if pred.killable
            and CanVoidTarget(me, pred.target, voidAbility, voidRange)
            and IsSafeCastTarget(pred.target)
        then
            if not best or pred.remainingHp < best.remainingHp then
                best = pred
            end
        end
    end

    if not best then
        return
    end

    local target = best.target
    local mana = SafeValue(NPC.GetMana, me) or 0
    local voidCost = SafeValue(Ability.GetManaCost, voidAbility) or 0

    if HasEtherealModifier(target) then
        if not IsAbilityReady(voidAbility, me) then
            return
        end
        if CastOnTarget(voidAbility, target, "void") then
            combo.lastComboAt = now
        end
        return
    end

    if IsHardBlocked(target) then
        return
    end
    if not IsAbilityReady(eblade, me) or not IsAbilityReady(voidAbility, me) then
        return
    end
    local ebladeCost = SafeValue(Ability.GetManaCost, eblade) or 0
    if mana < (ebladeCost + voidCost) then
        return
    end
    if SafeValue(NPC.IsEntityInRange, me, target, ebladeRange) ~= true then
        return
    end

    if CastOnTarget(eblade, target, "eblade") then
        combo.stage = "wait_ethereal"
        combo.target = target
        combo.ebladeIssuedAt = now
        local travel = EstimateEbladeTravel(me, target, eblade)
        combo.waitUntil = now + math.min(ETHEREAL_WAIT_MAX, math.max(0.2, travel))
    end
end

---@param font integer|userdata
---@param size number
---@param text string
---@return number
---@return number
local function MeasureText(font, size, text)
    local textSize = SafeValue(Render.TextSize, font, size, text)
    return (textSize and textSize.x) or (#text * size * 0.55),
        (textSize and textSize.y) or size
end

---@param handle integer|userdata|nil
---@param pos Vec2
---@param size number
local function DrawIcon(handle, pos, size)
    if not IsValidHandle(handle) or not Render.Image then
        return
    end
    TryCall(
        Render.Image,
        handle,
        pos,
        Vec2(size, size),
        Color(255, 255, 255, 255),
        4,
        Enum.DrawFlags.None
    )
end

---@class AntiMageLabelParts
---@field primary string
---@field secondary string|nil
---@field color Color
---@field border Color|nil
---@field showIcons boolean

---@param pred AntiMagePrediction
---@param showDamage boolean
---@param killHighlight boolean
---@param killColor Color
---@return AntiMageLabelParts|nil
local function BuildLabelParts(pred, showDamage, killHighlight, killColor)
    if pred.magicImmune then
        if not showDamage then
            return nil
        end
        return {
            primary = "IMMUNE",
            secondary = nil,
            color = REMAINING_COLOR,
            border = Theme.immune,
            showIcons = false,
        }
    end

    local damage = math.floor(pred.damage + 0.5)
    if pred.killable then
        if not killHighlight and not showDamage then
            return nil
        end
        return {
            primary = showDamage and string.format("KILL %d", damage) or "KILL",
            secondary = nil,
            color = killColor,
            border = killColor,
            showIcons = true,
        }
    end

    if not showDamage then
        return nil
    end

    return {
        primary = tostring(damage),
        secondary = string.format("HP %d", math.floor(pred.remainingHp + 0.5)),
        color = TEXT_COLOR,
        border = Theme.accent,
        showIcons = true,
    }
end

---@param font integer|userdata
---@param size number
---@param parts AntiMageLabelParts
---@param worldPos Vector
---@return boolean
local function DrawComboPanel(font, size, parts, worldPos)
    local screen, isVisible = WorldToScreenPos(worldPos)
    if not screen then
        return false
    end
    if not isVisible and not IsOnScreen(screen) then
        return false
    end
    if not IsValidHandle(font) or not Render.Text then
        return false
    end

    local primaryW, primaryH = MeasureText(font, size, parts.primary)
    local secondaryW, secondaryH = 0, 0
    if parts.secondary then
        secondaryW, secondaryH = MeasureText(font, size - 2, parts.secondary)
    end

    local hasEbladeIcon = IsValidHandle(Persistent.ebladeIcon)
    local hasVoidIcon = IsValidHandle(Persistent.voidIcon)
    local showIcons = parts.showIcons and (hasEbladeIcon or hasVoidIcon)
    local iconsW = 0
    if showIcons then
        local iconCount = (hasEbladeIcon and 1 or 0) + (hasVoidIcon and 1 or 0)
        iconsW = (iconCount * ICON_SIZE) + (math.max(0, iconCount - 1) * ICON_GAP) + ICON_TEXT_GAP
    end

    local textBlockW = primaryW
    if parts.secondary then
        textBlockW = primaryW + 6 + secondaryW
    end
    local contentH = math.max(ICON_SIZE, primaryH, secondaryH)
    local panelW = PANEL_PAD_X * 2 + iconsW + textBlockW
    local panelH = PANEL_PAD_Y * 2 + contentH
    local bottomY = screen.y - PANEL_SCREEN_Y_OFFSET
    local topLeft = Vec2(screen.x - panelW * 0.5, bottomY - panelH)
    local bottomRight = Vec2(screen.x + panelW * 0.5, bottomY)
    local textColor = parts.color
    local borderColor = parts.border or textColor

    if Render.FilledRect then
        TryCall(Render.FilledRect, topLeft, bottomRight, Theme.panelBg, PANEL_RADIUS)
    end
    if Render.Rect then
        TryCall(
            Render.Rect,
            topLeft,
            bottomRight,
            Color(borderColor.r, borderColor.g, borderColor.b, 210),
            PANEL_RADIUS,
            Enum.DrawFlags.None,
            1.25
        )
    end

    local cursorX = topLeft.x + PANEL_PAD_X
    local contentY = topLeft.y + PANEL_PAD_Y

    if showIcons then
        local iconY = contentY + (contentH - ICON_SIZE) * 0.5
        if hasEbladeIcon then
            DrawIcon(Persistent.ebladeIcon, Vec2(cursorX, iconY), ICON_SIZE)
            cursorX = cursorX + ICON_SIZE
            if hasVoidIcon then
                cursorX = cursorX + ICON_GAP
            end
        end
        if hasVoidIcon then
            DrawIcon(Persistent.voidIcon, Vec2(cursorX, iconY), ICON_SIZE)
            cursorX = cursorX + ICON_SIZE
        end
        cursorX = cursorX + ICON_TEXT_GAP
    end

    local primaryPos = Vec2(cursorX, contentY + (contentH - primaryH) * 0.5)
    TryCall(Render.Text, font, size, parts.primary, Vec2(primaryPos.x + 1, primaryPos.y + 1), Color(0, 0, 0, 240))
    TryCall(Render.Text, font, size, parts.primary, primaryPos, textColor)

    if parts.secondary then
        local secondaryPos = Vec2(cursorX + primaryW + 6, contentY + (contentH - secondaryH) * 0.5)
        TryCall(
            Render.Text,
            font,
            size - 2,
            parts.secondary,
            Vec2(secondaryPos.x + 1, secondaryPos.y + 1),
            Color(0, 0, 0, 220)
        )
        TryCall(Render.Text, font, size - 2, parts.secondary, secondaryPos, REMAINING_COLOR)
    end

    return true
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    SyncThemeColors()
    EnsureMenu()
    EnsureFont()
    EnsureIcons()
    if Persistent.logger then
        Persistent.logger:info("loaded")
    end
end

function Script.OnThemeUpdate()
    SyncThemeColors()
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end

    EnsureMenu()
    if not UI.enabled or not UI.enabled:Get() then
        if #Runtime.predictions > 0 or Runtime.combo.stage ~= "idle" then
            ResetRuntime()
        end
        return
    end

    local showDamage = UI.showDamage and UI.showDamage:Get()
    local killHighlight = UI.killHighlight and UI.killHighlight:Get()
    local autoCast = UI.autoCast and UI.autoCast:Get()
    if not showDamage and not killHighlight and not autoCast then
        Runtime.predictions = {}
        ResetCombo()
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        -- Still advance ethereal wait on a short tick when mid-combo.
        if autoCast and Runtime.combo.stage == "wait_ethereal" then
            local me = SafeValue(Heroes.GetLocal)
            local eblade = me and SafeValue(NPC.GetItem, me, EBLADE_ITEM, true)
            local voidAbility = me and SafeValue(NPC.GetAbility, me, VOID_ABILITY)
            if me and eblade and voidAbility then
                UpdateAutoCast(now, me, eblade, voidAbility)
            end
        end
        return
    end
    Runtime.lastUpdateAt = now
    UpdatePredictions()

    if autoCast then
        local me = SafeValue(Heroes.GetLocal)
        if me and SafeValue(NPC.GetUnitName, me) == HERO_NAME then
            local eblade = SafeValue(NPC.GetItem, me, EBLADE_ITEM, true)
            local voidAbility = SafeValue(NPC.GetAbility, me, VOID_ABILITY)
            if eblade and voidAbility then
                UpdateAutoCast(now, me, eblade, voidAbility)
            else
                ResetCombo()
            end
        end
    else
        ResetCombo()
    end
end

function Script.OnPrepareUnitOrders(data)
    local identifier = type(data) == "table" and data.identifier or nil
    if IsOurOrder(identifier) then
        return true
    end
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and SafeValue(Menu.VisualsIsEnabled) == false then
        return
    end
    if not UI.enabled or not UI.enabled:Get() then
        return
    end

    local predictions = Runtime.predictions
    if #predictions == 0 then
        return
    end

    local showDamage = UI.showDamage and UI.showDamage:Get()
    local killHighlight = UI.killHighlight and UI.killHighlight:Get()
    if not showDamage and not killHighlight then
        return
    end

    local killColor = DEFAULT_KILL_COLOR
    if UI.killColor then
        local picked = SafeValue(function()
            return UI.killColor:Get()
        end)
        if picked then
            killColor = picked
        end
    end

    EnsureIcons()
    local font = EnsureFont()
    if not IsValidHandle(font) then
        return
    end
    ---@cast font integer|userdata

    for i = 1, #predictions do
        local pred = predictions[i]
        local parts = BuildLabelParts(pred, showDamage == true, killHighlight == true, killColor)
        if parts then
            local worldPos = GetLabelWorldPos(pred.target)
            if worldPos then
                DrawComboPanel(font, LABEL_FONT_SIZE, parts, worldPos)
            end
        end
    end
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
