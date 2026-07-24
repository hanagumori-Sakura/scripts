--[[
    Keeper of the Light Assist
    Illuminate auto-release, Blinding Light saves, Spirit Form Solar Bind, Chakra Magic.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local LOG_PREFIX = "[KeeperOfTheLight] "
local HERO_NAME = "npc_dota_hero_keeper_of_the_light"
local CONFIG_SECTION = "keeper_of_the_light"
local ORDER_PREFIX = "kotl."
local ORDER_ILLUMINATE_END = "kotl.illuminate_end"
local ORDER_CHAKRA = "kotl.chakra"
local ORDER_SOLAR_BIND = "kotl.solar_bind"
local ORDER_BLINDING = "kotl.blinding_light"

local UPDATE_INTERVAL = 0.05
local SUPPORT_CAST_GAP = 1.0
local CHAKRA_SELF_MANA_RATIO = 0.30
local ILLUMINATE_ESCAPE_MIN_CHANNEL = 0.75
local ILLUMINATE_ESCAPE_BUFFER = 0.10
local ILLUMINATE_PROJECTILE_SPEED = 900
local CHANNELER_SCAN_RADIUS = 2000
local SOLAR_BIND_MIN_MOVE_SPEED = 330

local ABILITY_ILLUMINATE = "keeper_of_the_light_illuminate"
local ABILITY_ILLUMINATE_SPIRIT = "keeper_of_the_light_spirit_form_illuminate"
local ABILITY_ILLUMINATE_END = "keeper_of_the_light_illuminate_end"
local ABILITY_ILLUMINATE_SPIRIT_END = "keeper_of_the_light_spirit_form_illuminate_end"
local ABILITY_BLINDING = "keeper_of_the_light_blinding_light"
local ABILITY_SOLAR_BIND = "keeper_of_the_light_radiant_bind"
local ABILITY_CHAKRA = "keeper_of_the_light_chakra_magic"
local ABILITY_SPIRIT_FORM = "keeper_of_the_light_spirit_form"

local MOD_ILLUMINATE = "modifier_keeper_of_the_light_illuminate"
local MOD_ILLUMINATE_SPIRIT = "modifier_keeper_of_the_light_spirit_form_illuminate"
local MOD_SPIRIT_FORM = "modifier_keeper_of_the_light_spirit_form"

local DEFAULT_ILLUMINATE_RADIUS = 400
local DEFAULT_ILLUMINATE_RANGE = 1550
local DEFAULT_HEAL_PERCENT = 0.70
local DEFAULT_BL_RANGE = 600
local DEFAULT_SOLAR_RANGE = 890
local DEFAULT_CHAKRA_RANGE = 900

local LANG_CACHE_INTERVAL = 1.0

local Icons = {
    enable = "\u{f00c}", -- check
    debug = "\u{f188}", -- bug
    gear = "\u{f013}", -- settings
    escape = "\u{f70c}", -- person-running
    overkill = "\u{f140}", -- bullseye
    farm = "\u{f722}", -- wheat-awn
    creeps = "\u{f0c0}", -- users / wave count
    heart = "\u{f004}", -- hp threshold
    range = "\u{f546}", -- ruler-horizontal
    mana = "\u{f043}", -- droplet
    self = "\u{f007}", -- user
    heal = "\u{f590}", -- hand-holding-heart
}

local SpellIcons = {
    illuminate = "panorama/images/spellicons/keeper_of_the_light_illuminate_png.vtex_c",
    blinding = "panorama/images/spellicons/keeper_of_the_light_blinding_light_png.vtex_c",
    solar = "panorama/images/spellicons/keeper_of_the_light_radiant_bind_png.vtex_c",
    chakra = "panorama/images/spellicons/keeper_of_the_light_chakra_magic_png.vtex_c",
    spirit = "panorama/images/spellicons/keeper_of_the_light_spirit_form_png.vtex_c",
}

local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_SECOND = "Keeper Of The Light"
local MENU_THIRD = "Main Settings"

local O_CAST_POSITION = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
local O_CAST_NO_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
local ORDER_ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local TEAM_FRIEND = Enum.TeamType.TEAM_FRIEND
local TEAM_ENEMY = Enum.TeamType.TEAM_ENEMY
-- Runtime may not bind Enum.modifierState at script load (host quirk); stub values from Enums.lua.
local MODIFIER_STATE = Enum.modifierState
local STATE_INVULNERABLE = (MODIFIER_STATE and MODIFIER_STATE.MODIFIER_STATE_INVULNERABLE) or 8
local STATE_MAGIC_IMMUNE = (MODIFIER_STATE and MODIFIER_STATE.MODIFIER_STATE_MAGIC_IMMUNE) or 9
local STATE_OUT_OF_GAME = (MODIFIER_STATE and MODIFIER_STATE.MODIFIER_STATE_OUT_OF_GAME) or 33

--#endregion

--#region State

---@class KotLUI
---@field enabled CMenuSwitch|nil
---@field autoRelease CMenuSwitch|nil
---@field releaseOnEscape CMenuSwitch|nil
---@field overkillMargin CMenuSliderInt|nil
---@field autoFarm CMenuSwitch|nil
---@field minCreeps CMenuSliderInt|nil
---@field debugMode CMenuSwitch|nil
---@field autoBlinding CMenuSwitch|nil
---@field blHpThreshold CMenuSliderInt|nil
---@field blEnemyRange CMenuSliderInt|nil
---@field autoSolarBind CMenuSwitch|nil
---@field autoChakra CMenuSwitch|nil
---@field chakraManaThreshold CMenuSliderInt|nil
---@field chakraPrioritySelf CMenuSwitch|nil
---@field autoHeal CMenuSwitch|nil
---@field healHpThreshold CMenuSliderInt|nil
---@field callbacksAttached boolean
local UI = {
    enabled = nil,
    autoRelease = nil,
    releaseOnEscape = nil,
    overkillMargin = nil,
    autoFarm = nil,
    minCreeps = nil,
    debugMode = nil,
    autoBlinding = nil,
    blHpThreshold = nil,
    blEnemyRange = nil,
    autoSolarBind = nil,
    autoChakra = nil,
    chakraManaThreshold = nil,
    chakraPrioritySelf = nil,
    autoHeal = nil,
    healHpThreshold = nil,
    callbacksAttached = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
}

local LangState = {
    language = "en",
    nextCheck = 0,
}

local Runtime = {
    lastUpdateAt = -math.huge,
    lastChakraCast = -math.huge,
    lastSolarBindCast = -math.huge,
    lastBlindingCast = -math.huge,
    castPos = nil,
    castDir = nil,
    channelStartTime = nil,
}

--#endregion

--#region Helpers

local function TryCall(fn, ...)
    if type(fn) ~= "function" then
        return false, "expected a callable function"
    end
    return pcall(fn, ...)
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastChakraCast = -math.huge
    Runtime.lastSolarBindCast = -math.huge
    Runtime.lastBlindingCast = -math.huge
    Runtime.castPos = nil
    Runtime.castDir = nil
    Runtime.channelStartTime = nil
end

local function DebugLog(...)
    if not UI.debugMode or UI.debugMode:Get() ~= true then
        return
    end
    if Persistent.logger then
        Persistent.logger:debug(...)
    else
        Log.Write(LOG_PREFIX .. table.concat({ ... }, " "))
    end
end

---@param ability userdata|nil
---@param key string
---@param fallback number
---@return number
local function AbilitySpecial(ability, key, fallback)
    if not ability then
        return fallback
    end
    local value = Ability.GetLevelSpecialValueFor(ability, key)
    if type(value) == "number" and value > 0 then
        return value
    end
    return fallback
end

---@param me userdata
---@param ability userdata|nil
---@param fallback number
---@return number
local function EffectiveCastRange(me, ability, fallback)
    if not ability then
        return fallback
    end
    local range = Ability.GetCastRange(ability)
    if type(range) ~= "number" or range <= 0 then
        range = fallback
    end
    local bonus = NPC.GetCastRangeBonus(me)
    if type(bonus) == "number" and bonus > 0 then
        range = range + bonus
    end
    return range
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

---@param me userdata
---@return number
local function GetSpellAmpMultiplier(me)
    return SpellAmpMultiplier(NPC.GetBaseSpellAmp(me))
end

---@param target userdata
---@return number
local function BarrierAbsorb(target)
    local ok, barriers = TryCall(NPC.GetBarriers, target)
    if not ok or type(barriers) ~= "table" then
        return 0
    end
    local absorb = 0
    if type(barriers.magic) == "table" and type(barriers.magic.current) == "number" then
        absorb = absorb + math.max(0, barriers.magic.current)
    end
    if type(barriers.all) == "table" and type(barriers.all.current) == "number" then
        absorb = absorb + math.max(0, barriers.all.current)
    end
    return absorb
end

---@param point Vector
---@param lineStart Vector
---@param lineDir Vector
---@return number
local function DistancePointToLine(point, lineStart, lineDir)
    local w = point - lineStart
    local proj = w:Dot(lineDir)
    if proj <= 0 then
        return (point - lineStart):Length()
    end
    local vSq = lineDir:LengthSqr()
    if vSq == 0 then
        return (point - lineStart):Length()
    end
    local projVec = lineDir:Scaled(proj / vSq)
    return (w - projVec):Length()
end

---@param me userdata
---@return boolean
local function IsSpiritFormActive(me)
    return NPC.HasModifier(me, MOD_SPIRIT_FORM) == true
end

---@param unit userdata|nil
---@return boolean
local function IsValidHeroTarget(unit)
    if not unit then
        return false
    end
    if Entity.IsAlive(unit) ~= true then
        return false
    end
    if Entity.IsDormant(unit) == true then
        return false
    end
    if NPC.IsIllusion(unit) == true then
        return false
    end
    return true
end

---@param unit userdata
---@return boolean
local function IsMagicDamageable(unit)
    if NPC.HasState(unit, STATE_MAGIC_IMMUNE) == true then
        return false
    end
    if NPC.HasState(unit, STATE_INVULNERABLE) == true then
        return false
    end
    if NPC.HasState(unit, STATE_OUT_OF_GAME) == true then
        return false
    end
    return true
end

---@param abilityName string|nil
---@return boolean
local function IsIlluminateAbilityName(abilityName)
    return abilityName == ABILITY_ILLUMINATE or abilityName == ABILITY_ILLUMINATE_SPIRIT
end

---@param me userdata
---@param channeler userdata|nil
---@return userdata|nil
---@return userdata|nil
local function FindIlluminateEndAbility(me, channeler)
    if channeler then
        for i = 0, 30 do
            local ab = NPC.GetAbilityByIndex(channeler, i)
            if ab then
                local name = Ability.GetName(ab)
                if type(name) == "string" and string.find(name, "illuminate_end", 1, true) then
                    return ab, channeler
                end
            end
        end
    end

    if channeler ~= me then
        for i = 0, 30 do
            local ab = NPC.GetAbilityByIndex(me, i)
            if ab then
                local name = Ability.GetName(ab)
                if type(name) == "string" and string.find(name, "illuminate_end", 1, true) then
                    return ab, me
                end
            end
        end
    end

    local endSpell = NPC.GetAbility(me, ABILITY_ILLUMINATE_SPIRIT_END) or NPC.GetAbility(me, ABILITY_ILLUMINATE_END)
    if endSpell then
        return endSpell, me
    end
    return nil, nil
end

---@param endSpell userdata
---@param endSpellOwner userdata
local function ReleaseIlluminate(endSpell, endSpellOwner)
    local me = Heroes.GetLocal()
    if me and endSpellOwner == me then
        Ability.CastNoTarget(endSpell, false, true, false, ORDER_ILLUMINATE_END)
    else
        local player = Players.GetLocal()
        if not player then
            return
        end
        Player.PrepareUnitOrders(
            player,
            O_CAST_NO_TARGET,
            endSpellOwner,
            Vector(0, 0, 0),
            endSpell,
            ORDER_ISSUER,
            endSpellOwner,
            false,
            true,
            true,
            false,
            ORDER_ILLUMINATE_END
        )
    end
    Runtime.channelStartTime = nil
end

--#endregion

--#region Menu

local function GetUILanguage()
    local now = os.clock()
    if now < LangState.nextCheck then
        return LangState.language
    end
    LangState.nextCheck = now + LANG_CACHE_INTERVAL

    local langWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    if langWidget and langWidget.Get then
        local idx = langWidget:Get()
        if type(idx) == "number" and idx == 1 then
            LangState.language = "ru"
            return LangState.language
        end
    end

    LangState.language = "en"
    return LangState.language
end

---@param en string
---@param ru string|nil
---@return string
local function L(en, ru)
    if GetUILanguage() == "ru" and ru then
        return ru
    end
    return en
end

---@param widget any
---@param text string
local function WithTooltip(widget, text)
    if widget and widget.ToolTip then
        widget:ToolTip(text)
    end
end

---@param widget any
---@param icon string|nil
local function ApplyWidgetIcon(widget, icon)
    if not widget or not icon then
        return
    end
    if string.find(icon, "panorama/", 1, true) or string.find(icon, ".vtex", 1, true) then
        if widget.Image then
            widget:Image(icon)
        end
        return
    end
    if widget.Icon then
        widget:Icon(icon)
    end
end

---@param widget any
---@param text string
local function Localize(widget, text)
    if widget and widget.ForceLocalization then
        widget:ForceLocalization(text)
    end
end

---@param groupName string
---@return CMenuGroup|nil
local function FindOrCreateGroup(groupName)
    local group = Menu.Find(MENU_FIRST, MENU_SECTION, MENU_SECOND, MENU_THIRD, groupName)
    if group then
        return group
    end
    return Menu.Create(MENU_FIRST, MENU_SECTION, MENU_SECOND, MENU_THIRD, groupName)
end

---@param parent CMenuGroup|CMenuGearAttachment
---@param name string
---@param default boolean
---@param icon string|nil
---@return CMenuSwitch|nil
local function EnsureSwitch(parent, name, default, icon)
    local existing = parent:Find(name)
    ---@cast existing CMenuSwitch|nil
    if existing then
        ApplyWidgetIcon(existing, icon)
        return existing
    end
    local widget = parent:Switch(name, default)
    ApplyWidgetIcon(widget, icon)
    return widget
end

---@param parent CMenuGroup|CMenuGearAttachment
---@param name string
---@param minValue integer
---@param maxValue integer
---@param default integer
---@param format string|nil
---@param icon string|nil
---@return CMenuSliderInt|nil
local function EnsureSlider(parent, name, minValue, maxValue, default, format, icon)
    local existing = parent:Find(name)
    ---@cast existing CMenuSliderInt|nil
    if existing then
        ApplyWidgetIcon(existing, icon)
        return existing
    end
    local widget = parent:Slider(name, minValue, maxValue, default, format)
    ApplyWidgetIcon(widget, icon)
    return widget
end

local function UpdateMenuEnabledState()
    local on = UI.enabled and UI.enabled:Get() == true
    local featureWidgets = {
        UI.autoRelease,
        UI.autoBlinding,
        UI.autoSolarBind,
        UI.autoChakra,
        UI.autoHeal,
        UI.debugMode,
    }
    for _, widget in ipairs(featureWidgets) do
        if widget and widget.Disabled then
            widget:Disabled(not on)
        end
    end
end

local function BindConfigCallbacks()
    if UI.callbacksAttached then
        return
    end

    local function writeBool(key, widget)
        if not widget then
            return
        end
        widget:SetCallback(function(w)
            Config.WriteInt(CONFIG_SECTION, key, w:Get() and 1 or 0)
            if key == "enabled" then
                if w:Get() ~= true then
                    ResetRuntime()
                end
                UpdateMenuEnabledState()
            end
        end, false)
    end

    local function writeInt(key, widget)
        if not widget then
            return
        end
        widget:SetCallback(function(w)
            Config.WriteInt(CONFIG_SECTION, key, w:Get())
        end, false)
    end

    writeBool("enabled", UI.enabled)
    writeBool("auto_release", UI.autoRelease)
    writeBool("release_on_escape", UI.releaseOnEscape)
    writeInt("overkill_margin", UI.overkillMargin)
    writeBool("auto_farm", UI.autoFarm)
    writeInt("min_creeps", UI.minCreeps)
    writeBool("debug_mode", UI.debugMode)
    writeBool("auto_blinding", UI.autoBlinding)
    writeInt("bl_hp_threshold", UI.blHpThreshold)
    writeInt("bl_enemy_range", UI.blEnemyRange)
    writeBool("auto_solar_bind", UI.autoSolarBind)
    writeBool("auto_chakra", UI.autoChakra)
    writeInt("chakra_mana_threshold", UI.chakraManaThreshold)
    writeBool("chakra_priority_self", UI.chakraPrioritySelf)
    writeBool("auto_heal", UI.autoHeal)
    writeInt("heal_hp_threshold", UI.healHpThreshold)

    UI.callbacksAttached = true
end

local function HideLegacyWidget(parent, name)
    if not parent or not parent.Find then
        return
    end
    local widget = parent:Find(name)
    if widget and widget.Visible then
        widget:Visible(false)
    end
end

local function HideLegacyMenus(heroSettings, tabOffense, tabSupport)
    -- Pre-refresh English labels left behind after the UI reorganization.
    HideLegacyWidget(heroSettings, "Enable Debug Console Logs")
    HideLegacyWidget(tabOffense, "Auto Early Illuminate for Kill")
    HideLegacyWidget(tabSupport, "Auto Blinding Light Saves")
    HideLegacyWidget(tabSupport, "Auto Solar Bind Fleeing Enemies")
    HideLegacyWidget(tabSupport, "Auto Chakra Magic Allies")
    HideLegacyWidget(tabSupport, "Auto Release for Healing (Spirit Form)")
    HideLegacyWidget(tabSupport, "Auto Release for Healing (Shard)")
    HideLegacyWidget(tabSupport, "Auto Smart Recall Saves")
end

local function EnsureMenu()
    if UI.enabled and UI.autoRelease and UI.autoBlinding and UI.autoSolarBind and UI.autoChakra and UI.autoHeal then
        BindConfigCallbacks()
        UpdateMenuEnabledState()
        return
    end

    local heroSettings = FindOrCreateGroup("Hero Settings")
    local tabOffense = FindOrCreateGroup("Offensive Abilities")
    local tabSupport = FindOrCreateGroup("Support & Saves")
    if not heroSettings or not tabOffense or not tabSupport then
        return
    end

    HideLegacyMenus(heroSettings, tabOffense, tabSupport)

    -- General
    UI.enabled = EnsureSwitch(
        heroSettings,
        "Enable",
        Config.ReadInt(CONFIG_SECTION, "enabled", 1) ~= 0,
        Icons.enable
    )
    Localize(UI.enabled, L("Enable", "Включить"))
    WithTooltip(UI.enabled, L(
        "Master switch for all Keeper of the Light assists.",
        "Главный переключатель всех ассистов Keeper of the Light."
    ))

    UI.debugMode = EnsureSwitch(
        heroSettings,
        "Debug Logs",
        Config.ReadInt(CONFIG_SECTION, "debug_mode", 0) ~= 0,
        Icons.debug
    )
    Localize(UI.debugMode, L("Debug Logs", "Debug логи"))
    WithTooltip(UI.debugMode, L(
        "Write Illuminate / save / Chakra decisions to the Umbrella log.",
        "Писать решения Illuminate / сейвов / Chakra в лог Umbrella."
    ))

    -- Illuminate (offense)
    UI.autoRelease = EnsureSwitch(
        tabOffense,
        "Auto Illuminate",
        Config.ReadInt(CONFIG_SECTION, "auto_release", 1) ~= 0,
        SpellIcons.illuminate
    )
    Localize(UI.autoRelease, L("Auto Illuminate", "Авто Illuminate"))
    WithTooltip(UI.autoRelease, L(
        "Early-release Illuminate for lethal damage or escaping targets.",
        "Ранний релиз Illuminate для летала или убегающих целей."
    ))

    local illuGear = UI.autoRelease:Gear(L("Illuminate Settings", "Настройки Illuminate"), Icons.gear)

    UI.releaseOnEscape = EnsureSwitch(
        illuGear,
        "Release On Escape",
        Config.ReadInt(CONFIG_SECTION, "release_on_escape", 1) ~= 0,
        Icons.escape
    )
    Localize(UI.releaseOnEscape, L("Release On Escape", "Релиз при уходе"))
    WithTooltip(UI.releaseOnEscape, L(
        "Release if the target is about to leave the wave, even without lethal damage.",
        "Отпустить волну, если цель вот-вот выйдет из луча — даже без летала."
    ))

    UI.overkillMargin = EnsureSlider(
        illuGear,
        "Overkill Margin",
        0,
        150,
        Config.ReadInt(CONFIG_SECTION, "overkill_margin", 20),
        nil,
        Icons.overkill
    )
    Localize(UI.overkillMargin, L("Overkill Margin", "Запас урона"))
    WithTooltip(UI.overkillMargin, L(
        "Extra damage buffer required before auto-releasing for a kill.",
        "Дополнительный запас урона перед авто-релизом на килл."
    ))

    UI.autoFarm = EnsureSwitch(
        illuGear,
        "Auto Farm Creeps",
        Config.ReadInt(CONFIG_SECTION, "auto_farm", 0) ~= 0,
        Icons.farm
    )
    Localize(UI.autoFarm, L("Auto Farm Creeps", "Авто фарм крипов"))
    WithTooltip(UI.autoFarm, L(
        "Release Illuminate when enough creeps in the wave are killable.",
        "Отпускать Illuminate, когда в волне достаточно добиваемых крипов."
    ))

    UI.minCreeps = EnsureSlider(
        illuGear,
        "Min Creeps",
        1,
        10,
        Config.ReadInt(CONFIG_SECTION, "min_creeps", 2),
        nil,
        Icons.creeps
    )
    Localize(UI.minCreeps, L("Min Creeps", "Мин. крипов"))
    WithTooltip(UI.minCreeps, L(
        "Minimum killable creeps required for farm release.",
        "Минимум добиваемых крипов для релиза на фарм."
    ))

    -- Support: Blinding Light
    UI.autoBlinding = EnsureSwitch(
        tabSupport,
        "Auto Blinding Light",
        Config.ReadInt(CONFIG_SECTION, "auto_blinding", 1) ~= 0,
        SpellIcons.blinding
    )
    Localize(UI.autoBlinding, L("Auto Blinding Light", "Авто Blinding Light"))
    WithTooltip(UI.autoBlinding, L(
        "Knock back enemies around low-HP allies in cast range.",
        "Отталкивать врагов вокруг союзников с низким HP в радиусе каста."
    ))

    local blGear = UI.autoBlinding:Gear(L("Blinding Light Settings", "Настройки Blinding Light"), Icons.gear)

    UI.blHpThreshold = EnsureSlider(
        blGear,
        "Ally HP %",
        1,
        100,
        Config.ReadInt(CONFIG_SECTION, "bl_hp_threshold", 30),
        "%d%%",
        Icons.heart
    )
    Localize(UI.blHpThreshold, L("Ally HP %", "HP союзника %"))
    WithTooltip(UI.blHpThreshold, L(
        "Cast when an ally is at or below this HP percent.",
        "Кастовать, когда HP союзника на этом проценте или ниже."
    ))

    UI.blEnemyRange = EnsureSlider(
        blGear,
        "Threat Range",
        100,
        1000,
        Config.ReadInt(CONFIG_SECTION, "bl_enemy_range", 500),
        nil,
        Icons.range
    )
    Localize(UI.blEnemyRange, L("Threat Range", "Радиус угрозы"))
    WithTooltip(UI.blEnemyRange, L(
        "Enemy hero distance from the ally that counts as a threat.",
        "Дистанция вражеского героя до союзника, считающаяся угрозой."
    ))

    -- Support: Solar Bind (Spirit Form only)
    UI.autoSolarBind = EnsureSwitch(
        tabSupport,
        "Auto Solar Bind",
        Config.ReadInt(CONFIG_SECTION, "auto_solar_bind", 1) ~= 0,
        SpellIcons.solar
    )
    Localize(UI.autoSolarBind, L("Auto Solar Bind", "Авто Solar Bind"))
    WithTooltip(UI.autoSolarBind, L(
        "During Spirit Form, bind fleeing enemies that are facing away from you.",
        "В Spirit Form вешать бинд на убегающих врагов, смотрящих от вас."
    ))

    -- Support: Chakra
    UI.autoChakra = EnsureSwitch(
        tabSupport,
        "Auto Chakra Magic",
        Config.ReadInt(CONFIG_SECTION, "auto_chakra", 1) ~= 0,
        SpellIcons.chakra
    )
    Localize(UI.autoChakra, L("Auto Chakra Magic", "Авто Chakra Magic"))
    WithTooltip(UI.autoChakra, L(
        "Restore mana to low-mana allies (and yourself when prioritized).",
        "Восстанавливать ману союзникам с низкой маной (и себе при приоритете)."
    ))

    local chakraGear = UI.autoChakra:Gear(L("Chakra Settings", "Настройки Chakra"), Icons.gear)

    UI.chakraManaThreshold = EnsureSlider(
        chakraGear,
        "Ally Mana %",
        1,
        100,
        Config.ReadInt(CONFIG_SECTION, "chakra_mana_threshold", 40),
        "%d%%",
        Icons.mana
    )
    Localize(UI.chakraManaThreshold, L("Ally Mana %", "Мана союзника %"))
    WithTooltip(UI.chakraManaThreshold, L(
        "Cast on allies at or below this mana percent.",
        "Кастовать на союзников с маной на этом проценте или ниже."
    ))

    UI.chakraPrioritySelf = EnsureSwitch(
        chakraGear,
        "Prioritize Self",
        Config.ReadInt(CONFIG_SECTION, "chakra_priority_self", 1) ~= 0,
        Icons.self
    )
    Localize(UI.chakraPrioritySelf, L("Prioritize Self", "Приоритет себе"))
    WithTooltip(UI.chakraPrioritySelf, L(
        "If your mana is very low, Chakra yourself before helping allies.",
        "Если ваша мана очень низкая — сначала Chakra себе, потом союзникам."
    ))

    -- Support: Illuminate heal in Spirit Form
    UI.autoHeal = EnsureSwitch(
        tabSupport,
        "Auto Illuminate Heal",
        Config.ReadInt(CONFIG_SECTION, "auto_heal", 1) ~= 0,
        SpellIcons.spirit
    )
    Localize(UI.autoHeal, L("Auto Illuminate Heal", "Авто хил Illuminate"))
    WithTooltip(UI.autoHeal, L(
        "In Spirit Form, release Illuminate early to heal allies in the wave.",
        "В Spirit Form рано отпускать Illuminate, чтобы хилить союзников в волне."
    ))

    local healGear = UI.autoHeal:Gear(L("Healing Settings", "Настройки хила"), Icons.gear)

    UI.healHpThreshold = EnsureSlider(
        healGear,
        "Heal Ally HP %",
        1,
        100,
        Config.ReadInt(CONFIG_SECTION, "heal_hp_threshold", 50),
        "%d%%",
        Icons.heal
    )
    Localize(UI.healHpThreshold, L("Heal Ally HP %", "HP для хила %"))
    WithTooltip(UI.healHpThreshold, L(
        "Release for heal when an ally in the wave is below this HP percent.",
        "Отпускать для хила, когда союзник в волне ниже этого процента HP."
    ))

    BindConfigCallbacks()
    UpdateMenuEnabledState()
end

--#endregion

--#region Support Abilities

---@param me userdata
---@param now number
local function ManageChakra(me, now)
    if not UI.autoChakra or UI.autoChakra:Get() ~= true then
        return
    end
    if now - Runtime.lastChakraCast < SUPPORT_CAST_GAP then
        return
    end

    local chakra = NPC.GetAbility(me, ABILITY_CHAKRA)
    if not chakra or Ability.GetLevel(chakra) == 0 then
        return
    end
    if Ability.IsCastable(chakra, NPC.GetMana(me)) ~= true then
        return
    end

    local castRange = EffectiveCastRange(me, chakra, DEFAULT_CHAKRA_RANGE)
    local threshold = (UI.chakraManaThreshold and UI.chakraManaThreshold:Get() or 40) / 100.0

    if UI.chakraPrioritySelf and UI.chakraPrioritySelf:Get() == true then
        local myMana = NPC.GetMana(me)
        local myMaxMana = NPC.GetMaxMana(me)
        if myMaxMana > 0 and (myMana / myMaxMana) < CHAKRA_SELF_MANA_RATIO then
            Ability.CastTarget(chakra, me, false, true, false, ORDER_CHAKRA)
            Runtime.lastChakraCast = now
            return
        end
    end

    local allies = Entity.GetHeroesInRadius(me, castRange, TEAM_FRIEND, true, true)
    if not allies then
        return
    end

    for _, ally in ipairs(allies) do
        if IsValidHeroTarget(ally) then
            local maxMana = NPC.GetMaxMana(ally)
            if maxMana > 0 then
                local manaPerc = NPC.GetMana(ally) / maxMana
                if manaPerc < threshold then
                    Ability.CastTarget(chakra, ally, false, true, false, ORDER_CHAKRA)
                    Runtime.lastChakraCast = now
                    DebugLog("Chakra", NPC.GetUnitName(ally), string.format("%.0f%%", manaPerc * 100))
                    return
                end
            end
        end
    end
end

---@param me userdata
---@param now number
local function ManageSolarBind(me, now)
    if not UI.autoSolarBind or UI.autoSolarBind:Get() ~= true then
        return
    end
    if now - Runtime.lastSolarBindCast < SUPPORT_CAST_GAP then
        return
    end
    if IsSpiritFormActive(me) ~= true then
        return
    end

    local sbAbility = NPC.GetAbility(me, ABILITY_SOLAR_BIND)
    if not sbAbility or Ability.GetLevel(sbAbility) == 0 then
        return
    end
    if Ability.IsHidden(sbAbility) == true then
        return
    end
    if Ability.IsCastable(sbAbility, NPC.GetMana(me)) ~= true then
        return
    end

    local castRange = EffectiveCastRange(me, sbAbility, DEFAULT_SOLAR_RANGE)
    local enemies = Entity.GetHeroesInRadius(me, castRange, TEAM_ENEMY, true, true)
    if not enemies then
        return
    end

    local myPos = Entity.GetAbsOrigin(me)
    for _, enemy in ipairs(enemies) do
        if IsValidHeroTarget(enemy) and IsMagicDamageable(enemy) and NPC.IsRunning(enemy) == true then
            local enemyPos = Entity.GetAbsOrigin(enemy)
            local dirToKotl = (myPos - enemyPos):Normalized()
            local enemyDir = Entity.GetRotation(enemy):GetForward():Normalized()
            local isFacingKotl = enemyDir:Dot(dirToKotl) > 0
            if not isFacingKotl then
                local moveSpeed = NPC.GetMoveSpeed(enemy)
                if type(moveSpeed) == "number" and moveSpeed >= SOLAR_BIND_MIN_MOVE_SPEED then
                    Ability.CastTarget(sbAbility, enemy, false, true, false, ORDER_SOLAR_BIND)
                    Runtime.lastSolarBindCast = now
                    DebugLog("SolarBind", NPC.GetUnitName(enemy), "MS", tostring(moveSpeed))
                    return
                end
            end
        end
    end
end

---@param me userdata
---@param now number
local function ManageBlindingLight(me, now)
    if not UI.autoBlinding or UI.autoBlinding:Get() ~= true then
        return
    end
    if now - Runtime.lastBlindingCast < SUPPORT_CAST_GAP then
        return
    end

    local blAbility = NPC.GetAbility(me, ABILITY_BLINDING)
    if not blAbility or Ability.GetLevel(blAbility) == 0 then
        return
    end
    if Ability.IsCastable(blAbility, NPC.GetMana(me)) ~= true then
        return
    end

    local castRange = EffectiveCastRange(me, blAbility, DEFAULT_BL_RANGE)
    local hpThreshold = (UI.blHpThreshold and UI.blHpThreshold:Get() or 30) / 100.0
    local threatRange = UI.blEnemyRange and UI.blEnemyRange:Get() or 500

    local allies = Entity.GetHeroesInRadius(me, castRange, TEAM_FRIEND, true, true)
    if not allies then
        return
    end

    for _, ally in ipairs(allies) do
        if IsValidHeroTarget(ally) then
            local maxHp = Entity.GetMaxHealth(ally)
            local currentHp = Entity.GetHealth(ally)
            if maxHp > 0 and (currentHp / maxHp) <= hpThreshold then
                local enemies = Entity.GetHeroesInRadius(ally, threatRange, TEAM_ENEMY, true, true)
                if enemies and #enemies > 0 then
                    for _, enemy in ipairs(enemies) do
                        if IsValidHeroTarget(enemy) then
                            Ability.CastPosition(
                                blAbility,
                                Entity.GetAbsOrigin(ally),
                                false,
                                true,
                                false,
                                ORDER_BLINDING
                            )
                            Runtime.lastBlindingCast = now
                            DebugLog(
                                "BlindingLight",
                                NPC.GetUnitName(ally),
                                string.format("%.0f%%", (currentHp / maxHp) * 100),
                                NPC.GetUnitName(enemy)
                            )
                            return
                        end
                    end
                end
            end
        end
    end
end

--#endregion

--#region Illuminate

---@param me userdata
---@return userdata|nil, userdata|nil, number
local function ResolveIlluminateChannel(me)
    local channeler = nil
    if NPC.HasModifier(me, MOD_ILLUMINATE) == true or NPC.HasModifier(me, MOD_ILLUMINATE_SPIRIT) == true then
        channeler = me
    else
        local units = Entity.GetUnitsInRadius(me, CHANNELER_SCAN_RADIUS, TEAM_FRIEND, true, true)
        if units then
            for _, unit in ipairs(units) do
                if NPC.HasModifier(unit, MOD_ILLUMINATE_SPIRIT) == true
                    or NPC.HasModifier(unit, MOD_ILLUMINATE) == true then
                    channeler = unit
                    break
                end
            end
        end
    end

    if not channeler then
        return nil, nil, 0
    end

    local modifier = NPC.GetModifier(channeler, MOD_ILLUMINATE_SPIRIT)
        or NPC.GetModifier(channeler, MOD_ILLUMINATE)
    if not modifier then
        return nil, nil, 0
    end

    local illuminate = NPC.GetAbility(me, ABILITY_ILLUMINATE)
    local illuminateSpirit = NPC.GetAbility(me, ABILITY_ILLUMINATE_SPIRIT)
    local activeIlluminate = illuminateSpirit
    if not activeIlluminate or Ability.GetLevel(activeIlluminate) == 0 then
        activeIlluminate = illuminate
    end
    if not activeIlluminate then
        return nil, nil, 0
    end

    local creationTime = Modifier.GetCreationTime(modifier)
    if type(creationTime) ~= "number" or creationTime <= 0 then
        creationTime = Runtime.channelStartTime
    end
    if type(creationTime) ~= "number" or creationTime <= 0 then
        return nil, nil, 0
    end

    return channeler, activeIlluminate, creationTime
end

---@param me userdata
---@param channeler userdata
---@param currentDamage number
---@param castPos Vector
---@param castDir Vector
---@param range number
---@param radius number
---@param endSpell userdata
---@param endSpellOwner userdata
---@return boolean
local function TryReleaseForKillOrEscape(
    me,
    channeler,
    currentDamage,
    castPos,
    castDir,
    range,
    radius,
    endSpell,
    endSpellOwner
)
    local enemies = Entity.GetHeroesInRadius(channeler, range + radius, TEAM_ENEMY, true, true)
    if not enemies then
        return false
    end

    local spellAmp = GetSpellAmpMultiplier(me)
    local overkill = UI.overkillMargin and UI.overkillMargin:Get() or 20
    local releaseOnEscape = UI.releaseOnEscape and UI.releaseOnEscape:Get() == true

    for _, enemy in ipairs(enemies) do
        if IsValidHeroTarget(enemy) and IsMagicDamageable(enemy) then
            local enemyPos = Entity.GetAbsOrigin(enemy)
            local w = enemyPos - castPos
            local proj = w:Dot(castDir)

            if proj > -radius and proj < (range + radius) then
                local dist = DistancePointToLine(enemyPos, castPos, castDir)
                local isInside = dist <= radius and proj > 0 and proj < range

                local enemySpeed = 0
                local dir = Vector(0, 0, 0)
                if NPC.IsRunning(enemy) == true then
                    enemySpeed = NPC.GetMoveSpeed(enemy) or 0
                    dir = Entity.GetRotation(enemy):GetForward():Normalized()
                end

                local vY = (dir.x * castDir.x + dir.y * castDir.y) * enemySpeed
                local timeToReach = 0
                if proj > 0 then
                    local relativeSpeed = ILLUMINATE_PROJECTILE_SPEED - vY
                    if relativeSpeed > 10 then
                        timeToReach = proj / relativeSpeed
                    else
                        timeToReach = 9999
                    end
                end

                local expectedPos = enemyPos + dir:Scaled(enemySpeed * timeToReach)
                local expectedW = expectedPos - castPos
                local expectedProj = expectedW:Dot(castDir)
                local expectedDist = DistancePointToLine(expectedPos, castPos, castDir)

                local willMiss = false
                local isEscaping = false

                if proj > -radius then
                    if expectedDist > dist then
                        local tEscLat = (radius - dist) * timeToReach / (expectedDist - dist)
                        if timeToReach > tEscLat then
                            willMiss = true
                        elseif (tEscLat - timeToReach) <= ILLUMINATE_ESCAPE_BUFFER then
                            isEscaping = true
                        end
                    end

                    if vY > 0 and proj < range then
                        local tEscLong = (range - proj) / vY
                        if timeToReach > tEscLong then
                            willMiss = true
                        elseif (tEscLong - timeToReach) <= ILLUMINATE_ESCAPE_BUFFER then
                            isEscaping = true
                        end
                    end
                end

                if expectedProj < -radius then
                    willMiss = true
                end

                local magicResist = NPC.GetMagicalArmorDamageMultiplier(enemy) or 1
                local actualDamage = currentDamage * spellAmp * magicResist
                local requiredDamage = Entity.GetHealth(enemy) + overkill + BarrierAbsorb(enemy)

                DebugLog(
                    "Illuminate",
                    NPC.GetUnitName(enemy),
                    "IN",
                    tostring(isInside),
                    "MISS",
                    tostring(willMiss),
                    "ESC",
                    tostring(isEscaping),
                    string.format("DMG %.0f/%.0f", actualDamage, requiredDamage)
                )

                if isInside and not willMiss then
                    if isEscaping then
                        if actualDamage >= requiredDamage then
                            ReleaseIlluminate(endSpell, endSpellOwner)
                            return true
                        elseif releaseOnEscape then
                            local channelDuration = GameRules.GetGameTime() - (Runtime.channelStartTime or 0)
                            if channelDuration > ILLUMINATE_ESCAPE_MIN_CHANNEL then
                                ReleaseIlluminate(endSpell, endSpellOwner)
                                return true
                            end
                        end
                    elseif actualDamage >= requiredDamage then
                        ReleaseIlluminate(endSpell, endSpellOwner)
                        return true
                    end
                end
            end
        end
    end

    return false
end

---@param me userdata
---@param channeler userdata
---@param currentDamage number
---@param castPos Vector
---@param castDir Vector
---@param range number
---@param radius number
---@param endSpell userdata
---@param endSpellOwner userdata
---@return boolean
local function TryReleaseForHeal(
    me,
    channeler,
    currentDamage,
    castPos,
    castDir,
    range,
    radius,
    endSpell,
    endSpellOwner
)
    if not UI.autoHeal or UI.autoHeal:Get() ~= true then
        return false
    end
    if IsSpiritFormActive(me) ~= true then
        return false
    end

    -- Spirit Form KV: illuminate_heal = 70 (+30 with Shard) → factor 0.7 / 1.0
    local spiritForm = NPC.GetAbility(me, ABILITY_SPIRIT_FORM)
    local healPercent = AbilitySpecial(spiritForm, "illuminate_heal", DEFAULT_HEAL_PERCENT * 100) / 100.0
    if healPercent <= 0 then
        healPercent = DEFAULT_HEAL_PERCENT
    end
    local currentHeal = currentDamage * healPercent
    local healThreshold = (UI.healHpThreshold and UI.healHpThreshold:Get() or 50) / 100.0

    local allies = Entity.GetHeroesInRadius(channeler, range + radius, TEAM_FRIEND, true, true)
    if not allies then
        return false
    end

    for _, ally in ipairs(allies) do
        if IsValidHeroTarget(ally) then
            local allyPos = Entity.GetAbsOrigin(ally)
            local w = allyPos - castPos
            local proj = w:Dot(castDir)
            if proj > -radius and proj < (range + radius) then
                local dist = DistancePointToLine(allyPos, castPos, castDir)
                if dist <= radius and proj > 0 and proj < range then
                    local maxHp = Entity.GetMaxHealth(ally)
                    if maxHp > 0 then
                        local hpPerc = Entity.GetHealth(ally) / maxHp
                        if hpPerc < healThreshold then
                            if currentHeal > (maxHp * 0.1) or hpPerc < 0.2 then
                                DebugLog(
                                    "Heal",
                                    NPC.GetUnitName(ally),
                                    string.format("%.0f%%", hpPerc * 100),
                                    string.format("%.0f", currentHeal)
                                )
                                ReleaseIlluminate(endSpell, endSpellOwner)
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

---@param me userdata
---@param channeler userdata
---@param currentDamage number
---@param castPos Vector
---@param castDir Vector
---@param range number
---@param radius number
---@param endSpell userdata
---@param endSpellOwner userdata
---@return boolean
local function TryReleaseForFarm(
    me,
    channeler,
    currentDamage,
    castPos,
    castDir,
    range,
    radius,
    endSpell,
    endSpellOwner
)
    if not UI.autoFarm or UI.autoFarm:Get() ~= true then
        return false
    end

    local minCreeps = UI.minCreeps and UI.minCreeps:Get() or 2
    local killableCreeps = 0
    local spellAmp = GetSpellAmpMultiplier(me)
    local units = Entity.GetUnitsInRadius(channeler, range + radius, TEAM_ENEMY, true, true)
    if not units then
        return false
    end

    for _, creep in ipairs(units) do
        if Entity.IsAlive(creep) == true
            and Entity.IsDormant(creep) ~= true
            and NPC.IsCreep(creep) == true
            and IsMagicDamageable(creep) then
            local creepPos = Entity.GetAbsOrigin(creep)
            local w = creepPos - castPos
            local proj = w:Dot(castDir)
            if proj > -radius and proj < (range + radius) then
                local dist = DistancePointToLine(creepPos, castPos, castDir)
                if dist <= radius and proj > 0 and proj < range then
                    local magicResist = NPC.GetMagicalArmorDamageMultiplier(creep) or 1
                    local actualDamage = currentDamage * spellAmp * magicResist
                    local requiredDamage = Entity.GetHealth(creep) + BarrierAbsorb(creep)
                    if actualDamage >= requiredDamage then
                        killableCreeps = killableCreeps + 1
                    end
                end
            end
        end
    end

    if killableCreeps >= minCreeps then
        ReleaseIlluminate(endSpell, endSpellOwner)
        return true
    end
    return false
end

---@param me userdata
local function ManageIlluminate(me)
    if not UI.autoRelease or UI.autoRelease:Get() ~= true then
        return
    end

    local channeler, activeIlluminate, creationTime = ResolveIlluminateChannel(me)
    if not channeler or not activeIlluminate then
        return
    end

    local maxDamage = AbilitySpecial(activeIlluminate, "total_damage", 0)
    local maxChannelTime = AbilitySpecial(activeIlluminate, "max_channel_time", 0)
    if maxDamage <= 0 or maxChannelTime <= 0 then
        return
    end

    local currentDamageTime = GameRules.GetGameTime() - creationTime
    if currentDamageTime > maxChannelTime then
        currentDamageTime = maxChannelTime
    end
    if currentDamageTime < 0 then
        currentDamageTime = 0
    end
    local currentDamage = (currentDamageTime / maxChannelTime) * maxDamage

    local endSpell, endSpellOwner = FindIlluminateEndAbility(me, channeler)
    if not endSpell or not endSpellOwner then
        DebugLog("Illuminate", "no end spell")
        return
    end

    local castDir = Runtime.castDir
    if not castDir then
        castDir = Entity.GetRotation(channeler):GetForward():Normalized()
    end
    local castPos = Runtime.castPos or Entity.GetAbsOrigin(channeler)
    local radius = AbilitySpecial(activeIlluminate, "radius", DEFAULT_ILLUMINATE_RADIUS)
    local range = AbilitySpecial(activeIlluminate, "range", DEFAULT_ILLUMINATE_RANGE)

    if TryReleaseForKillOrEscape(
        me,
        channeler,
        currentDamage,
        castPos,
        castDir,
        range,
        radius,
        endSpell,
        endSpellOwner
    ) then
        return
    end

    if TryReleaseForHeal(
        me,
        channeler,
        currentDamage,
        castPos,
        castDir,
        range,
        radius,
        endSpell,
        endSpellOwner
    ) then
        return
    end

    TryReleaseForFarm(
        me,
        channeler,
        currentDamage,
        castPos,
        castDir,
        range,
        radius,
        endSpell,
        endSpellOwner
    )
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    Persistent.logger = Logger("KeeperOfTheLight")
    EnsureMenu()
    Persistent.logger:info("loaded")
end

function Script.OnPrepareUnitOrders(data, _player, order, _target, position, ability, _orderIssuer, npc)
    local identifier = type(data) == "table" and data.identifier or nil
    if type(identifier) == "string" and string.sub(identifier, 1, #ORDER_PREFIX) == ORDER_PREFIX then
        return true
    end

    if order ~= O_CAST_POSITION and order ~= O_CAST_NO_TARGET then
        return true
    end

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return true
    end
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return true
    end

    local abilityName = ""
    if ability and ability ~= 0 then
        abilityName = Ability.GetName(ability) or ""
    end

    if abilityName == "" then
        local illu = NPC.GetAbility(me, ABILITY_ILLUMINATE)
        local illuS = NPC.GetAbility(me, ABILITY_ILLUMINATE_SPIRIT)
        if (illu and Ability.IsInAbilityPhase(illu) == true)
            or (illuS and Ability.IsInAbilityPhase(illuS) == true) then
            abilityName = ABILITY_ILLUMINATE
        end
    end

    if IsIlluminateAbilityName(abilityName) then
        local originNpc = npc or me
        Runtime.castPos = Entity.GetAbsOrigin(originNpc)
        if position and position:Length() > 0 then
            Runtime.castDir = (position - Runtime.castPos):Normalized()
        else
            Runtime.castDir = Entity.GetRotation(originNpc):GetForward():Normalized()
        end
        Runtime.channelStartTime = GameRules.GetGameTime()
    end

    return true
end

function Script.OnUpdate()
    if Engine.IsInGame() ~= true then
        return
    end

    EnsureMenu()
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Input.IsInputCaptured() == true then
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
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    ManageIlluminate(me)
    ManageBlindingLight(me, now)
    ManageSolarBind(me, now)
    ManageChakra(me, now)
end

function Script.OnGameEnd()
    ResetRuntime()
end

--#endregion

return Script
