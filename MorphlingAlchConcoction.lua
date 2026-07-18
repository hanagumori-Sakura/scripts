--[[
    Morphling — Alchemist Concoction helper
    Morph into enemy Alchemist, stay in form, brew W (Unstable Concoction).
    Do not throw. When self-brew is about to explode on you, dodge with Manta.
    Hold Combo Key to run the loop.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local SCRIPT_ID = "morph_alch_concoction"
local ORDER_PREFIX = SCRIPT_ID .. "."
local DEBUG_PREFIX = "[MorphAlch] "

local HERO_NAME = "npc_dota_hero_morphling"
local ENEMY_ALCH_NAME = "npc_dota_hero_alchemist"

local REPLICATE_NAME = "morphling_replicate"
-- One-shot form fix only (never spam during brew loop).
local MORPH_TOGGLE_NAME = "morphling_morph_replicate"
local CONCOCTION_NAME = "alchemist_unstable_concoction"
local THROW_NAME = "alchemist_unstable_concoction_throw"
local ACID_SPRAY_NAME = "alchemist_acid_spray"
local MANTA_NAME = "item_manta"

local MOD_MORPH_MANAGER = "modifier_morphling_replicate_manager"
local MOD_BREWING = "modifier_alchemist_unstable_concoction"

local DEFAULT_MORPH_RANGE = 1200
local DEFAULT_BREW_EXPLOSION = 5.5
local ABILITY_SCAN_MAX_INDEX = 23

local MODE_FULL = 0
local MODE_SEMI = 1
local MODE_ITEMS = { "Full (Morph + loop)", "Semi (already morphed)" }

local PHASE_IDLE = "idle"
local PHASE_MORPH_ALCH = "morph_alch"
local PHASE_ENSURE_ALCH = "ensure_alch"
local PHASE_BREW = "brew"
local PHASE_MANTA = "manta"

local MORPH_SETTLE_DELAY = 0.35
local MORPH_TIMEOUT = 2.5
local REPLICATE_RETRY_INTERVAL = 0.75
local ACTION_COOLDOWN = 0.05

local DEFAULT_MANTA_LEAD_TENTHS = 5

local Icons = {
    enable   = "\u{f00c}",
    keyboard = "\u{f11c}",
    gear     = "\u{f013}",
    flask    = "\u{f0c3}",
    timer    = "\u{f017}",
    bug      = "\u{f188}",
}

--#endregion

--#region State

local State = {
    phase = PHASE_IDLE,
    lastActionAt = -100,
    brewStartAt = -100,
    morphAttemptAt = -100,
    replicateCastSent = false,
    mantaUsedThisBrew = false,
    statusMessage = "",
}

--#endregion

local UI = {}
local MenuNodes = {}

local Locale = {
    group_name = { en = "Alch Concoction", ru = "Alch Concoction" },
    gear_settings = { en = "Settings", ru = "Настройки" },
    ui_enabled = { en = "Enable", ru = "Включить" },
    ui_combo_key = { en = "Combo Key", ru = "Бинд комбо" },
    ui_mode = { en = "Mode", ru = "Режим" },
    ui_manta_dodge = { en = "Manta dodge self-explode", ru = "Manta от самоподрыва" },
    ui_manta_lead = { en = "Manta lead time", ru = "Manta за N сек" },
    ui_debug = { en = "Debug logs", ru = "Debug логи" },
    ui_overlay = { en = "Debug overlay", ru = "Debug overlay" },
    tip_enabled = {
        en = "Master switch for Morphling Alchemist concoction loop.",
        ru = "Главный переключатель цикла Morphling + Alchemist concoction.",
    },
    tip_combo_key = {
        en = "Hold to run the loop. Release to stop. Not a toggle.",
        ru = "Удерживай — цикл работает. Отпустил — стоп. Не toggle.",
    },
    tip_mode = {
        en = "Full: morph enemy Alchemist then loop. Semi: you morph manually first.",
        ru = "Full: morph во вражеского Alch и цикл. Semi: morph вручную.",
    },
    tip_manta_dodge = {
        en = "Manta Style when your brew is about to explode on yourself (not thrown flask).",
        ru = "Manta когда варка сейчас взорвётся на тебе (не летящая колба).",
    },
    tip_manta_lead = {
        en = "Seconds before self-explode to cast Manta (default 0.5s).",
        ru = "За сколько секунд до самоподрыва кастовать Manta (по умолчанию 0.5).",
    },
    tip_debug = {
        en = "Write phase decisions to debug.log.",
        ru = "Писать фазы и касты в debug.log.",
    },
    tip_overlay = {
        en = "Show phase and ability state on screen.",
        ru = "Показывать фазу и состояние способностей на экране.",
    },
}

local LangState = {
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    callbackSet = false,
}

--#region Logging

local LoggerInstance = Logger and Logger("MorphAlch") or nil
local UmbrellaLog = Log

local function SafeValue(fn, ...)
    if not fn then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function WriteLog(level, message)
    message = tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if pcall(LoggerInstance[level], LoggerInstance, message) then
            return
        end
    end
    if UmbrellaLog and UmbrellaLog.Write then
        UmbrellaLog.Write(DEBUG_PREFIX .. message)
        return
    end
    print(DEBUG_PREFIX .. message)
end

local function Dbg(message, ...)
    if not UI.Debug or not UI.Debug:Get() then
        return
    end
    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    WriteLog("info", message)
end

--#endregion

--#region Localization

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
    if value == "ru" or value:find("рус", 1, true) then
        return "ru"
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
    MenuLabel(UI.Mode, "ui_mode")
    MenuTip(UI.Mode, "tip_mode")
    MenuLabel(UI.MantaDodge, "ui_manta_dodge")
    MenuTip(UI.MantaDodge, "tip_manta_dodge")
    MenuLabel(UI.MantaLead, "ui_manta_lead")
    MenuTip(UI.MantaLead, "tip_manta_lead")
    MenuLabel(UI.Debug, "ui_debug")
    MenuTip(UI.Debug, "tip_debug")
    MenuLabel(UI.Overlay, "ui_overlay")
    MenuTip(UI.Overlay, "tip_overlay")
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
    local group = nil
    local heroSection = Menu.Find("Heroes", "Hero List", "Morphling", "Main Settings")
    if heroSection and heroSection.Create then
        group = heroSection:Create("Alch Concoction")
    end

    if not group then
        group = Menu.Create("Scripts", "Combat", "Morphling Alch Concoction", "Main", "Alch Concoction")
    end

    if not group then
        error(DEBUG_PREFIX .. "Failed to create menu group")
    end

    MenuNodes.group = group

    local ui = {}
    ui.Enabled = group:Switch("Enable", false, Icons.enable)
    ui.ComboKey = group:Bind("Combo Key (Hold)", Enum.ButtonCode.KEY_NONE, Icons.keyboard)

    local gear = ui.Enabled:Gear("Settings", Icons.gear, true)
    MenuNodes.gear = gear

    ui.Mode = gear:Combo("Mode", MODE_ITEMS, MODE_FULL)
    MenuIcon(ui.Mode, Icons.flask)

    ui.MantaDodge = gear:Switch("Manta dodge self-explode", true)
    MenuIcon(ui.MantaDodge, Icons.flask)

    ui.MantaLead = gear:Slider("Manta lead time", 1, 20, DEFAULT_MANTA_LEAD_TENTHS, function(v)
        return string.format("%.1fs", v * 0.1)
    end)
    MenuIcon(ui.MantaLead, Icons.timer)

    ui.Debug = gear:Switch("Debug logs", false)
    MenuIcon(ui.Debug, Icons.bug)

    ui.Overlay = gear:Switch("Debug overlay", true)
    MenuIcon(ui.Overlay, Icons.bug)

    local function UpdateControls()
        local enabled = ui.Enabled:Get()
        ui.ComboKey:Disabled(not enabled)
        ui.Mode:Disabled(not enabled)
        ui.MantaDodge:Disabled(not enabled)
        ui.MantaLead:Disabled(not enabled)
        ui.Debug:Disabled(not enabled)
        ui.Overlay:Disabled(not enabled)
    end

    ui.Enabled:SetCallback(UpdateControls, true)
    ApplyLocalization(true)
    SetupLanguageCallback()
    return ui
end

--#endregion

--#region Ability helpers

local function GetAbilityLookupName(ability)
    if not ability then
        return nil
    end

    local name = SafeValue(Ability.GetBaseName, ability)
    if name and name ~= "" then
        return name
    end

    name = SafeValue(Ability.GetName, ability)
    if name and name ~= "" then
        return name
    end

    return nil
end

local function FindHeroAbilityByName(hero, abilityName)
    local direct = SafeValue(NPC.GetAbility, hero, abilityName)
    if direct then
        return direct
    end

    if not NPC.GetAbilityByIndex then
        return nil
    end

    for index = 0, ABILITY_SCAN_MAX_INDEX do
        local ability = SafeValue(NPC.GetAbilityByIndex, hero, index)
        if ability and GetAbilityLookupName(ability) == abilityName then
            return ability
        end
    end

    return nil
end

local function FindHeroAbilityMatching(hero, predicate)
    if not NPC.GetAbilityByIndex or type(predicate) ~= "function" then
        return nil
    end

    for index = 0, ABILITY_SCAN_MAX_INDEX do
        local ability = SafeValue(NPC.GetAbilityByIndex, hero, index)
        local name = ability and GetAbilityLookupName(ability)
        if name and predicate(name, ability) then
            return ability
        end
    end

    return nil
end

local function GetConcoctionPair(me)
    local brew = FindHeroAbilityByName(me, CONCOCTION_NAME)
    local throw = FindHeroAbilityByName(me, THROW_NAME)

    if not brew then
        brew = FindHeroAbilityMatching(me, function(name)
            return name == CONCOCTION_NAME
                or (name:find("unstable_concoction", 1, true)
                    and not name:find("throw", 1, true)
                    and name ~= ACID_SPRAY_NAME)
        end)
    end

    if not throw then
        throw = FindHeroAbilityMatching(me, function(name)
            return name == THROW_NAME
                or name:find("unstable_concoction_throw", 1, true)
        end)
    end

    -- Hard lock: only W (Unstable Concoction / Throw). Never Q (Acid Spray).
    if brew then
        local brewName = GetAbilityLookupName(brew)
        if brewName ~= CONCOCTION_NAME
            and not (brewName and brewName:find("unstable_concoction", 1, true) and not brewName:find("throw", 1, true))
        then
            brew = nil
        end
    end

    if throw then
        local throwName = GetAbilityLookupName(throw)
        if throwName ~= THROW_NAME
            and not (throwName and throwName:find("unstable_concoction_throw", 1, true))
        then
            throw = nil
        end
    end

    return brew, throw
end

local function IsConcoctionAbility(ability)
    local name = GetAbilityLookupName(ability)
    if not name or name == ACID_SPRAY_NAME then
        return false
    end
    return name == CONCOCTION_NAME
        or name == THROW_NAME
        or name:find("unstable_concoction", 1, true) ~= nil
end

local function GetMorphToggle(me)
    local toggle = FindHeroAbilityByName(me, MORPH_TOGGLE_NAME)
    if toggle then
        return toggle
    end

    return FindHeroAbilityMatching(me, function(name)
        return name == MORPH_TOGGLE_NAME
            or name:find("morph_replicate", 1, true) ~= nil
    end)
end

local function GetManta(me)
    return SafeValue(NPC.GetItem, me, MANTA_NAME, true)
end

local function GetAbilityStateLine(ability, mana, label)
    if not ability then
        return label .. "=missing"
    end

    return string.format(
        "%s cd=%.2f ready=%s castable=%s",
        label,
        SafeValue(Ability.GetCooldown, ability) or -1,
        tostring(SafeValue(Ability.IsReady, ability)),
        tostring(SafeValue(Ability.IsCastable, ability, mana))
    )
end

local function OrderTag(phase)
    return ORDER_PREFIX .. phase
end

local function CastNoTargetFast(ability, phase)
    if not ability then
        return false
    end
    if (phase == "brew") and not IsConcoctionAbility(ability) then
        Dbg("blocked non-W cast | phase=%s ability=%s", phase, GetAbilityLookupName(ability) or "?")
        return false
    end
    SafeValue(Ability.CastNoTarget, ability, false, true, true, OrderTag(phase))
    return true
end

local function CastTargetFast(ability, target, phase)
    if not ability or not target then
        return false
    end
    SafeValue(Ability.CastTarget, ability, target, false, true, true, OrderTag(phase))
    return true
end

--#endregion

--#region Hero helpers

local function IsValidHero(unit)
    return unit
        and Entity.IsAlive(unit)
        and not Entity.IsDormant(unit)
        and not NPC.IsIllusion(unit)
end

local function CanAct(me)
    if not IsValidHero(me) then
        return false
    end

    return not NPC.IsStunned(me)
        and not NPC.IsSilenced(me)
        and not NPC.HasState(me, Enum.ModifierState.MODIFIER_STATE_ROOTED)
end

local function HasMorphBuff(me)
    return SafeValue(NPC.HasModifier, me, MOD_MORPH_MANAGER) == true
end

local function IsBrewing(me)
    return SafeValue(NPC.HasModifier, me, MOD_BREWING) == true
end

local function IsInAlchemistForm(me)
    if IsBrewing(me) then
        return true
    end

    local concoction = FindHeroAbilityByName(me, CONCOCTION_NAME)
    local throw = FindHeroAbilityByName(me, THROW_NAME)
    if concoction and not SafeValue(Ability.IsHidden, concoction) then
        return true
    end
    if throw and not SafeValue(Ability.IsHidden, throw) then
        return true
    end

    return false
end

local function GetMorphRange(me, replicate)
    if replicate then
        local range = SafeValue(Ability.GetCastRange, replicate)
        if range and range > 0 then
            return range + (SafeValue(NPC.GetCastRangeBonus, me) or 0)
        end
    end
    return DEFAULT_MORPH_RANGE
end

local function FindEnemyAlchemist(me, range)
    local team = Entity.GetTeamNum(me)
    if not team or not Heroes.InRadius then
        return nil
    end

    local heroes = Heroes.InRadius(
        Entity.GetAbsOrigin(me),
        range,
        team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}

    local best = nil
    local bestDist = range + 1

    for _, hero in ipairs(heroes) do
        if IsValidHero(hero) and NPC.GetUnitName(hero) == ENEMY_ALCH_NAME then
            local dist = (Entity.GetAbsOrigin(hero) - Entity.GetAbsOrigin(me)):Length2D()
            if dist < bestDist then
                bestDist = dist
                best = hero
            end
        end
    end

    return best
end

--#endregion

--#region State machine

local function ResetState()
    State.phase = PHASE_IDLE
    State.lastActionAt = -100
    State.brewStartAt = -100
    State.morphAttemptAt = -100
    State.replicateCastSent = false
    State.mantaUsedThisBrew = false
    State.statusMessage = ""
end

local function SetPhase(phase, message)
    if State.phase ~= phase then
        Dbg("phase %s -> %s | %s", State.phase, phase, message or "")
    end
    State.phase = phase
    if message then
        State.statusMessage = message
    end
end

local function CanActNow(now)
    return now - State.lastActionAt >= ACTION_COOLDOWN
end

local function MarkAction(now)
    State.lastActionAt = now
end

-- Hold-only: never use IsToggled.
local function IsComboKeyHeld()
    local key = UI.ComboKey
    if not key or not key.IsDown then
        return false
    end
    return key:IsDown() == true
end

local function IsFullMode()
    return (UI.Mode:Get() or MODE_FULL) == MODE_FULL
end

local function GetMantaLeadSeconds()
    local value = UI.MantaLead and UI.MantaLead:Get() or DEFAULT_MANTA_LEAD_TENTHS
    return value * 0.1
end

local function CanCastBrew(ability, mana)
    if not ability or SafeValue(Ability.IsHidden, ability) then
        return false
    end

    if SafeValue(Ability.IsCastable, ability, mana) then
        return true
    end

    local cooldown = SafeValue(Ability.GetCooldown, ability) or 999
    return SafeValue(Ability.IsReady, ability) == true and cooldown <= 0.05
end

local function GetBrewExplosionDuration(brewAbility)
    if brewAbility then
        local value = SafeValue(Ability.GetLevelSpecialValueFor, brewAbility, "brew_explosion", -1)
        if value and value > 0 then
            return value
        end
    end
    return DEFAULT_BREW_EXPLOSION
end

local function SyncBrewStart(me, now)
    local mod = SafeValue(NPC.GetModifier, me, MOD_BREWING)
    if not mod then
        return false
    end

    local created = SafeValue(Modifier.GetCreationTime, mod)
    if type(created) == "number" and created > 0 then
        State.brewStartAt = created
    elseif State.brewStartAt < 0 then
        State.brewStartAt = now
    end
    return true
end

local function GetBrewRemaining(me, now, brewAbility)
    local mod = SafeValue(NPC.GetModifier, me, MOD_BREWING)
    if mod then
        local dieTime = SafeValue(Modifier.GetDieTime, mod)
        if type(dieTime) == "number" and dieTime > 0 then
            return math.max(0, dieTime - now)
        end
    end

    if State.brewStartAt < 0 then
        return nil
    end

    return math.max(0, GetBrewExplosionDuration(brewAbility) - (now - State.brewStartAt))
end

local function TryMorphAlchemist(me, now, mana)
    local replicate = FindHeroAbilityByName(me, REPLICATE_NAME)
    if not replicate then
        SetPhase(PHASE_MORPH_ALCH, "morphling_replicate missing")
        return false
    end

    if HasMorphBuff(me) then
        SetPhase(PHASE_ENSURE_ALCH, "already morphed")
        return true
    end

    local alch = FindEnemyAlchemist(me, GetMorphRange(me, replicate))
    if not alch then
        SetPhase(PHASE_MORPH_ALCH, "no enemy Alchemist in range")
        return false
    end

    if not SafeValue(Ability.IsCastable, replicate, mana) then
        SetPhase(PHASE_MORPH_ALCH, "replicate on cooldown")
        return false
    end

    if State.morphAttemptAt < 0 then
        State.morphAttemptAt = now
    end

    if now - State.morphAttemptAt > MORPH_TIMEOUT then
        SetPhase(PHASE_MORPH_ALCH, "morph timeout")
        State.morphAttemptAt = -100
        State.replicateCastSent = false
        return false
    end

    if not CanActNow(now) then
        return false
    end

    if State.replicateCastSent and not HasMorphBuff(me) then
        if now - State.morphAttemptAt < REPLICATE_RETRY_INTERVAL then
            SetPhase(PHASE_MORPH_ALCH, "waiting morph")
            return true
        end
        State.replicateCastSent = false
    end

    if CastTargetFast(replicate, alch, "replicate") then
        MarkAction(now)
        State.replicateCastSent = true
        Dbg("CAST replicate -> enemy Alchemist")
        SetPhase(PHASE_MORPH_ALCH, "morph cast sent")
    end

    if HasMorphBuff(me) and now - State.morphAttemptAt >= MORPH_SETTLE_DELAY then
        SetPhase(PHASE_ENSURE_ALCH, "morph buff active")
    end

    return true
end

local function TryEnsureAlchemistForm(me, now, mana)
    if not HasMorphBuff(me) then
        if IsFullMode() then
            SetPhase(PHASE_MORPH_ALCH, "need morph first")
            State.morphAttemptAt = -100
            return false
        end
        SetPhase(PHASE_ENSURE_ALCH, "Semi: morph into Alchemist first")
        return false
    end

    if IsInAlchemistForm(me) then
        SetPhase(PHASE_BREW, "in Alchemist form")
        return true
    end

    -- One-shot only: enter Alchemist form. Never spam during brew loop.
    local morphToggle = GetMorphToggle(me)
    if not morphToggle then
        SetPhase(PHASE_ENSURE_ALCH, "waiting for Alchemist form")
        return false
    end

    local canToggle = SafeValue(Ability.IsCastable, morphToggle, mana) == true
        or SafeValue(Ability.IsActivated, morphToggle) == true
    if not canToggle then
        SetPhase(PHASE_ENSURE_ALCH, "waiting for Alchemist form")
        return false
    end

    if not CanActNow(now) then
        return false
    end

    if CastNoTargetFast(morphToggle, "ensure_alch") then
        MarkAction(now)
        Dbg("CAST morph toggle -> Alchemist form (once)")
        SetPhase(PHASE_ENSURE_ALCH, "toggle to Alchemist")
    end

    return false
end

local function TryCastMantaSelfExplode(me, now, mana, remaining)
    if not UI.MantaDodge or not UI.MantaDodge:Get() then
        return false
    end
    if State.mantaUsedThisBrew then
        return false
    end

    local manta = GetManta(me)
    if not manta or SafeValue(Ability.IsCastable, manta, mana) ~= true then
        SetPhase(PHASE_MANTA, string.format("manta needed rem=%.2f", remaining))
        return false
    end

    if not CanActNow(now) then
        return false
    end

    SafeValue(Ability.CastNoTarget, manta, false, true, true, OrderTag("manta"))
    MarkAction(now)
    State.mantaUsedThisBrew = true
    Dbg("CAST manta | self-explode rem=%.2f", remaining)
    SetPhase(PHASE_MANTA, string.format("manta self-explode %.2f", remaining))
    return true
end

local function TryBrewCycle(me, now, mana)
    local brew = select(1, GetConcoctionPair(me))

    if not IsInAlchemistForm(me) then
        SetPhase(PHASE_ENSURE_ALCH, "lost Alchemist form")
        return false
    end

    if IsBrewing(me) then
        SyncBrewStart(me, now)
        local remaining = GetBrewRemaining(me, now, brew)
        if remaining == nil then
            remaining = GetBrewExplosionDuration(brew)
        end
        local elapsed = math.max(0, now - State.brewStartAt)
        local mantaLead = GetMantaLeadSeconds()

        -- Only dodge the brew that explodes on YOU — never thrown projectile.
        if remaining <= mantaLead then
            if TryCastMantaSelfExplode(me, now, mana, remaining) then
                return true
            end
        end

        SetPhase(PHASE_BREW, string.format("brew %.1fs rem=%.2f", elapsed, remaining))
        return true
    end

    State.brewStartAt = -100
    State.mantaUsedThisBrew = false

    if not brew then
        SetPhase(PHASE_BREW, "concoction missing")
        return false
    end

    if not CanCastBrew(brew, mana) then
        SetPhase(PHASE_BREW, "waiting for concoction")
        return false
    end

    if not CanActNow(now) then
        return false
    end

    if CastNoTargetFast(brew, "brew") then
        MarkAction(now)
        State.brewStartAt = now
        State.mantaUsedThisBrew = false
        Dbg("CAST brew concoction")
        SetPhase(PHASE_BREW, "brew started")
    end

    return true
end

local function RunComboTick(me, now)
    local mana = NPC.GetMana(me) or 0

    if State.phase == PHASE_IDLE then
        State.morphAttemptAt = -100
        State.replicateCastSent = false
        State.mantaUsedThisBrew = false
        State.brewStartAt = -100
        if IsFullMode() and not HasMorphBuff(me) then
            SetPhase(PHASE_MORPH_ALCH, "start full")
        else
            SetPhase(PHASE_ENSURE_ALCH, "start semi / morphed")
        end
    end

    if State.phase == PHASE_MORPH_ALCH then
        if TryMorphAlchemist(me, now, mana) and State.phase == PHASE_MORPH_ALCH then
            return
        end
    end

    if State.phase == PHASE_ENSURE_ALCH or (State.phase == PHASE_MORPH_ALCH and HasMorphBuff(me)) then
        if TryEnsureAlchemistForm(me, now, mana) then
            -- fall through to brew when form ready
        elseif State.phase == PHASE_ENSURE_ALCH then
            return
        end
    end

    if State.phase == PHASE_BREW or State.phase == PHASE_MANTA or IsInAlchemistForm(me) then
        if State.phase ~= PHASE_BREW and State.phase ~= PHASE_MANTA then
            SetPhase(PHASE_BREW, "form ready")
        end
        TryBrewCycle(me, now, mana)
    end
end

--#endregion

--#region Debug overlay

local OverlayFont = nil
local OverlayColor = nil
local OverlayShadow = nil

local function GetOverlayFont()
    if OverlayFont and OverlayFont ~= 0 then
        return OverlayFont
    end
    if not Render or not Render.LoadFont then
        return nil
    end
    OverlayFont = SafeValue(Render.LoadFont, "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 0, 400)
    if not OverlayFont or OverlayFont == 0 then
        OverlayFont = nil
        return nil
    end
    return OverlayFont
end

local function DrawDebugOverlay(me)
    if not UI.Overlay or not UI.Overlay:Get() then
        return
    end

    if not Render or not Render.Text then
        return
    end

    local font = GetOverlayFont()
    if not font then
        return
    end

    if not OverlayColor then
        OverlayColor = Color(180, 230, 255, 255)
        OverlayShadow = Color(0, 0, 0, 200)
    end

    local mana = NPC.GetMana(me) or 0
    local concoction, throw = GetConcoctionPair(me)
    local manta = GetManta(me)

    local lines = {
        string.format("MorphAlch | phase=%s", State.phase),
        State.statusMessage ~= "" and State.statusMessage or "—",
        string.format("morphed=%s alchForm=%s brewing=%s", tostring(HasMorphBuff(me)), tostring(IsInAlchemistForm(me)), tostring(IsBrewing(me))),
        GetAbilityStateLine(concoction, mana, "W brew"),
        GetAbilityStateLine(throw, mana, "W throw"),
        GetAbilityStateLine(manta, mana, "manta"),
    }

    local x, y = 24, 120
    local lineHeight = 16

    for i, line in ipairs(lines) do
        local pos = Vec2(x, y + (i - 1) * lineHeight)
        SafeValue(Render.Text, font, 14, line, Vec2(pos.x + 1, pos.y + 1), OverlayShadow)
        SafeValue(Render.Text, font, 14, line, pos, OverlayColor)
    end
end

--#endregion

UI = InitializeUI()

--#region Lifecycle

function Script.OnUpdate()
    if not Engine.IsInGame() or not UI.Enabled:Get() then
        if State.phase ~= PHASE_IDLE then
            ResetState()
        end
        return
    end

    if Input.IsInputCaptured and Input.IsInputCaptured() then
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    local now = GlobalVars.GetCurTime() or 0

    if not IsComboKeyHeld() then
        if State.phase ~= PHASE_IDLE then
            ResetState()
        end
        return
    end

    if not CanAct(me) then
        State.statusMessage = "hero cannot act"
        return
    end

    RunComboTick(me, now)
end

function Script.OnDraw()
    if not Engine.IsInGame() or not UI.Enabled:Get() then
        return
    end

    if not UI.Overlay or not UI.Overlay:Get() then
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    DrawDebugOverlay(me)
end

function Script.OnGameEnd()
    ResetState()
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    if not UI.Debug or not UI.Debug:Get() then
        return true
    end

    local identifier = data and (data.identifier or data.orderIdentifier)
    if type(identifier) ~= "string" or identifier:find(ORDER_PREFIX, 1, true) ~= 1 then
        return true
    end

    Dbg("order id=%s ability=%s", identifier, ability and GetAbilityLookupName(ability) or "?")
    return true
end

--#endregion

return Script
