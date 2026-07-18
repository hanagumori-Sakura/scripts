--[[
    Oracle Assist
    Hold combo: Fortune's End + Purifying Flames spam; ally Flames save; strict False Promise.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "OracleAssist"
local CONFIG_SECTION = "oracle_assist"
local HERO_NAME = "npc_dota_hero_oracle"
local HERO_TAB = "Oracle"
local HERO_ICON = "panorama/images/heroes/icons/npc_dota_hero_oracle_png.vtex_c"
local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_THIRD = "Oracle Assist"

local ABILITY_FORTUNES_END = "oracle_fortunes_end"
local ABILITY_FATES_EDICT = "oracle_fates_edict"
local ABILITY_PURIFYING_FLAMES = "oracle_purifying_flames"
local ABILITY_FALSE_PROMISE = "oracle_false_promise"

local MOD_FALSE_PROMISE = "modifier_oracle_false_promise"
local MOD_FATES_EDICT = "modifier_oracle_fates_edict"
local MOD_PURIFYING_FLAMES = "modifier_oracle_purifying_flames"

local ORDER_PREFIX = "oracle.assist."

local UPDATE_INTERVAL = 0.033
local CAST_DEDUP = 0.12
local PENDING_CAST_EXPIRE = 1.80
local TARGET_LOCK_INTERVAL = 0.08
local FLAMES_STAGE_TIMEOUT = 1.15
local HURT_WINDOW = 2.2
local POST_FP_EDICT_QUIET = 6.0
local ABILITY_RECENT_USE_WINDOW = 0.45
-- If a PF-under-FP order never lands (no CD observed), allow one retry after this.
local FP_FLAMES_STUCK_RETRY = 3.50
local FP_FLAMES_MIN_GAP = 1.35
local DEFAULT_FE_RANGE = 850
local DEFAULT_PF_RANGE = 850
local DEFAULT_EDICT_RANGE = 500
local DEFAULT_FP_RANGE = 700

local DEFAULT_FP_HP_PCT = 18
local DEFAULT_FP_MIN_DAMAGE_PCT = 8
local DEFAULT_FP_HP_DROP_PCT = 12
local DEFAULT_FP_HP_DROP_WINDOW = 0.45
local DEFAULT_FP_ENEMY_RANGE = 1200
local DEFAULT_FP_QUIET = 1.25
local DEFAULT_FP_MANA_FLOOR = 10

local DEFAULT_FLAMES_HP_PCT = 70
local DEFAULT_FLAMES_MANA_FLOOR = 12
local DEFAULT_FLAMES_ENEMY_RANGE = 900
local DEFAULT_FLAMES_QUIET = 0.55
-- Under FP only pending-cast / CAST_DEDUP gate PF; spam every time the ability is ready.
local DEBUG_PREFIX = "[OracleAssist] "
local DEBUG_HOLD_INTERVAL = 2.5

local SPELL_ICON_FORTUNES_END = "panorama/images/spellicons/oracle_fortunes_end_png.vtex_c"
local SPELL_ICON_FATES_EDICT = "panorama/images/spellicons/oracle_fates_edict_png.vtex_c"
local SPELL_ICON_PURIFYING_FLAMES = "panorama/images/spellicons/oracle_purifying_flames_png.vtex_c"
local SPELL_ICON_FALSE_PROMISE = "panorama/images/spellicons/oracle_false_promise_png.vtex_c"
local ITEM_ICON_BLADE_MAIL = "panorama/images/items/blade_mail_png.vtex_c"

local DAMAGE_RETURN_MODS = {
    "modifier_item_blade_mail_reflect",
    "modifier_nyx_assassin_spiked_carapace",
}

-- Font Awesome solid; ability/item rows use spell/item images instead.
local Icons = {
    enable = "\u{f00c}", -- check (do not change usage)
    bind = "\u{e1c1}", -- keyboard (do not change usage)
    debug = "\u{f188}", -- bug
    combo = "\u{f890}", -- sparkles
    flamesHp = "\u{f004}", -- heart
    flamesMana = "\u{f043}", -- tint / droplet
    flamesRange = "\u{f140}", -- crosshairs
    fpHp = "\u{f21e}", -- heartbeat
    fpDamage = "\u{f0e7}", -- bolt
    fpDrop = "\u{f063}", -- arrow-down
    fpWindow = "\u{f254}", -- hourglass-half
    fpRange = "\u{f192}", -- bullseye
    fpQuiet = "\u{f6a9}", -- volume-mute
    fpMana = "\u{f0eb}", -- lightbulb
}
--#endregion

--#region Locale
local Locale = {
    tab_assist = {
        en = "Oracle Assist",
        ru = "Oracle Assist",
        cn = "Oracle Assist",
    },
    tab_combo = {
        en = "Combo",
        ru = "Combo",
        cn = "Combo",
    },
    tab_flames = {
        en = "Flames Save",
        ru = "Flames Save",
        cn = "Flames Save",
    },
    tab_fp = {
        en = "False Promise",
        ru = "False Promise",
        cn = "False Promise",
    },
    group_general = {
        en = "General",
        ru = "General",
        cn = "General",
    },
    ui_enabled = {
        en = "Enable",
        ru = "Включить",
        cn = "启用",
    },
    tip_enabled = {
        en = "Heroes → Hero List → Oracle → Oracle Assist. Disable built-in Oracle Auto Usage → False Promise and Z-Plugin auto-protect to avoid double ults.",
        ru = "Heroes → Hero List → Oracle → Oracle Assist. Отключите встроенные Oracle Auto Usage → False Promise и Z-Plugin автозащиту, чтобы не было двойной ульты.",
        cn = "Heroes → Hero List → Oracle → Oracle Assist。请关闭内置 Oracle Auto Usage → False Promise 与 Z-Plugin 自动保护，避免重复开大。",
    },
    ui_combo_key = {
        en = "Combo Key",
        ru = "Клавиша комбо",
        cn = "连招键",
    },
    tip_combo_key = {
        en = "Hold to lock an enemy and cast Fortune's End, then spam Purifying Flames while ready.",
        ru = "Удерживайте: лок врага, Fortune's End, затем спам Purifying Flames по КД.",
        cn = "按住锁定敌人：先 Fortune's End，再在冷却好时重复 Purifying Flames。",
    },
    ui_combo_enable = {
        en = "Combo Enable",
        ru = "Комбо вкл.",
        cn = "启用连招",
    },
    ui_use_fortunes = {
        en = "Use Fortune's End",
        ru = "Fortune's End",
        cn = "使用 Fortune's End",
    },
    ui_use_flames_spam = {
        en = "Spam Purifying Flames",
        ru = "Спам Purifying Flames",
        cn = "重复 Purifying Flames",
    },
    ui_skip_damage_return = {
        en = "Skip into Blade Mail / Nyx",
        ru = "Не кастовать в Blade Mail / Nyx",
        cn = "不打 Blade Mail / Nyx",
    },
    tip_skip_damage_return = {
        en = "When ON, skip offensive casts into active Blade Mail reflect or Spiked Carapace.",
        ru = "Если включено — не кастовать по активному Blade Mail / Spiked Carapace.",
        cn = "开启后不在 Blade Mail 反伤或尖刺外壳期间对敌施法。",
    },
    ui_flames_enable = {
        en = "Enable Flames Save",
        ru = "Включить Flames Save",
        cn = "启用火焰救援",
    },
    tip_flames_enable = {
        en = "Auto Fate's Edict → Purifying Flames on low allies under attack. Under False Promise casts Flames only.",
        ru = "Авто Fate's Edict → Purifying Flames по низким союзникам под атакой. Под False Promise — только Flames.",
        cn = "低血受击友军自动 Fate's Edict → Purifying Flames；已有 False Promise 时只放 Flames。",
    },
    ui_flames_hp = {
        en = "Ally HP% Threshold",
        ru = "Порог HP% союзника",
        cn = "友军 HP% 阈值",
    },
    ui_flames_mana = {
        en = "Mana Floor %",
        ru = "Пол маны %",
        cn = "蓝量下限 %",
    },
    ui_flames_enemy_range = {
        en = "Enemy Presence Range",
        ru = "Радиус врагов",
        cn = "敌人检测范围",
    },
    ui_fp_enable = {
        en = "Enable False Promise",
        ru = "Включить False Promise",
        cn = "启用虚假契约",
    },
    tip_fp_enable = {
        en = "Strict save: never ult above HP% threshold. Requires meaningful recent damage or HP drop, plus nearby enemy.",
        ru = "Строгий сейв: никогда не ультать выше порога HP%. Нужен существенный урон/падение HP и враг рядом.",
        cn = "严格救援：高于 HP% 阈值绝不开大；需有效近期伤害或掉血，且附近有敌人。",
    },
    ui_fp_hp = {
        en = "HP% Threshold",
        ru = "Порог HP%",
        cn = "HP% 阈值",
    },
    ui_fp_min_damage = {
        en = "Min Recent Damage %",
        ru = "Мин. недавний урон %",
        cn = "最低近期伤害 %",
    },
    tip_fp_min_damage = {
        en = "Recent damage must be at least this % of max HP (blocks Bristleback chip / small AoE).",
        ru = "Недавний урон ≥ этого % от макс. HP (режет чип Bristleback / мелкий AoE).",
        cn = "近期伤害至少为最大生命的该百分比（过滤刚背刺针等碎伤）。",
    },
    ui_fp_drop = {
        en = "Min HP% Drop",
        ru = "Мин. падение HP%",
        cn = "最低掉血 %",
    },
    ui_fp_drop_window = {
        en = "HP Drop Window (s)",
        ru = "Окно падения HP (с)",
        cn = "掉血窗口 (秒)",
    },
    ui_fp_enemy_range = {
        en = "Enemy Presence Range",
        ru = "Радиус врагов",
        cn = "敌人检测范围",
    },
    ui_fp_quiet = {
        en = "Quiet After Cast (s)",
        ru = "Пауза после каста (с)",
        cn = "施法后静默 (秒)",
    },
    ui_fp_mana = {
        en = "Mana Floor %",
        ru = "Пол маны %",
        cn = "蓝量下限 %",
    },
    ui_debug = {
        en = "Debug logs",
        ru = "Debug логи",
        cn = "调试日志",
    },
    tip_debug = {
        en = "Write combo / save decisions and casts to debug.log.",
        ru = "Писать решения комбо/сейва и касты в debug.log.",
        cn = "将连招/救援决策与施法写入 debug.log。",
    },
}

local LangState = {
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
}

local MenuNodes = {
    ---@type CSecondTab|nil
    hero = nil,
    ---@type CThirdTab|nil
    assist = nil,
    ---@type CMenuGroup|nil
    main = nil,
    ---@type CMenuGroup|nil
    combo = nil,
    ---@type CMenuGroup|nil
    flames = nil,
    ---@type CMenuGroup|nil
    fp = nil,
}
--#endregion

--#region State
---@class OracleAssistUI
---@field enabled CMenuSwitch|nil
---@field comboKey CMenuBind|nil
---@field comboEnable CMenuSwitch|nil
---@field useFortunes CMenuSwitch|nil
---@field useFlamesSpam CMenuSwitch|nil
---@field skipDamageReturn CMenuSwitch|nil
---@field flamesEnable CMenuSwitch|nil
---@field flamesHp CMenuSliderInt|CMenuSliderFloat|nil
---@field flamesMana CMenuSliderInt|CMenuSliderFloat|nil
---@field flamesEnemyRange CMenuSliderInt|CMenuSliderFloat|nil
---@field fpEnable CMenuSwitch|nil
---@field fpHp CMenuSliderInt|CMenuSliderFloat|nil
---@field fpMinDamage CMenuSliderInt|CMenuSliderFloat|nil
---@field fpDrop CMenuSliderInt|CMenuSliderFloat|nil
---@field fpDropWindow CMenuSliderInt|CMenuSliderFloat|nil
---@field fpEnemyRange CMenuSliderInt|CMenuSliderFloat|nil
---@field fpQuiet CMenuSliderInt|CMenuSliderFloat|nil
---@field fpMana CMenuSliderInt|CMenuSliderFloat|nil
---@field debug CMenuSwitch|nil
---@field callbacksAttached boolean
local UI = {
    enabled = nil,
    comboKey = nil,
    comboEnable = nil,
    useFortunes = nil,
    useFlamesSpam = nil,
    skipDamageReturn = nil,
    flamesEnable = nil,
    flamesHp = nil,
    flamesMana = nil,
    flamesEnemyRange = nil,
    fpEnable = nil,
    fpHp = nil,
    fpMinDamage = nil,
    fpDrop = nil,
    fpDropWindow = nil,
    fpEnemyRange = nil,
    fpQuiet = nil,
    fpMana = nil,
    debug = nil,
    callbacksAttached = false,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
}

---@class OracleFlamesStage
---@field target userdata
---@field stage string
---@field startedAt number
---@field edictIssued boolean|nil

---@class OraclePendingCast
---@field abilityName string
---@field issuedAt number
---@field cooldownBefore number

local Runtime = {
    lastUpdateAt = -math.huge,
    lastCastAt = -math.huge,
    lastTargetResolveAt = -math.huge,
    lastFpCastAt = -math.huge,
    lastFlamesSaveAt = -math.huge,
    lastDebugHoldAt = -math.huge,
    ---@type userdata|nil
    comboTarget = nil,
    ---@type OracleFlamesStage|nil
    flamesStage = nil,
    ---@type OraclePendingCast|nil
    pendingCast = nil,
    ---@type table<integer, { hpPct: number, at: number }>
    hpHistory = {},
    ---@type table<integer, number>
    postFpQuietUntil = {},
    ---PF under FP: issued → must observe real CD → then allow next cast when ready again.
    fpFlamesAwaitingCd = false,
    fpFlamesSawCd = false,
    fpFlamesIssuedAt = -math.huge,
    ---@type string|nil
    fpFlamesTargetName = nil,
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

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastCastAt = -math.huge
    Runtime.lastTargetResolveAt = -math.huge
    Runtime.lastFpCastAt = -math.huge
    Runtime.lastFlamesSaveAt = -math.huge
    Runtime.lastDebugHoldAt = -math.huge
    Runtime.comboTarget = nil
    Runtime.flamesStage = nil
    Runtime.pendingCast = nil
    Runtime.hpHistory = {}
    Runtime.postFpQuietUntil = {}
    Runtime.fpFlamesAwaitingCd = false
    Runtime.fpFlamesSawCd = false
    Runtime.fpFlamesIssuedAt = -math.huge
    Runtime.fpFlamesTargetName = nil
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

local function ReadFloat(key, defaultValue)
    return Config.ReadFloat(CONFIG_SECTION, key, defaultValue)
end

local function WriteFloat(key, value)
    Config.WriteFloat(CONFIG_SECTION, key, value)
end

---@param tag string
---@return string
local function OrderId(tag)
    return ORDER_PREFIX .. tag
end

---@param widget { Icon?: fun(self: any, icon: string) }|nil
---@param icon string
local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        widget:Icon(icon)
    end
end

---@param widget { Image?: fun(self: any, imagePath: string) }|nil
---@param imagePath string
local function MenuImage(widget, imagePath)
    if widget and widget.Image and imagePath then
        widget:Image(imagePath)
    end
end

---@param unit userdata|nil
---@return string
local function FmtUnit(unit)
    if not unit then
        return "nil"
    end
    local name = SafeValue(NPC.GetUnitName, unit) or "?"
    local short = name:gsub("^npc_dota_hero_", "")
    short = short:gsub("^npc_dota_", "")
    return short
end

local function IsDebugOn()
    return UI.debug ~= nil and UI.debug:Get() == true
end

---Single sink: Logger info (visible), else Log.Write. Never both (duplicates the console).
local function LogWrite(message)
    message = tostring(message)
    local logger = Persistent.logger
    if logger then
        local ok = pcall(function()
            logger:info(message)
        end)
        if ok then
            return
        end
        if pcall(function()
            logger:debug(message)
        end) then
            return
        end
    end
    if Log and Log.Write then
        pcall(Log.Write, DEBUG_PREFIX .. message)
    end
end

local function Dbg(message, ...)
    if not IsDebugOn() then
        return
    end
    if select("#", ...) > 0 then
        local ok, formatted = TryCall(string.format, message, ...)
        if ok and type(formatted) == "string" then
            message = formatted
        end
    end
    LogWrite(message)
end

---@param now number
---@param message string
---@param ... any
local function DbgThrottled(now, message, ...)
    if not IsDebugOn() then
        return
    end
    if now - Runtime.lastDebugHoldAt < DEBUG_HOLD_INTERVAL then
        return
    end
    Runtime.lastDebugHoldAt = now
    Dbg(message, ...)
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

---@param bind CMenuBind|nil
---@return boolean
local function IsBindHeld(bind)
    if not bind then
        return false
    end
    if bind.IsDown and bind:IsDown() == true then
        return true
    end
    return false
end

---@param unit userdata|nil
---@return boolean
local function IsAliveUnit(unit)
    return unit ~= nil and SafeValue(Entity.IsAlive, unit) == true
end

---@param me userdata|nil
---@return boolean
local function IsLocalOracle(me)
    if not IsAliveUnit(me) then
        return false
    end
    return SafeValue(NPC.GetUnitName, me) == HERO_NAME
end

---@param me userdata
---@return boolean
local function CanCastActions(me)
    if SafeValue(NPC.IsStunned, me) == true then
        return false
    end
    if SafeValue(NPC.IsSilenced, me) == true then
        return false
    end
    local states = Enum.modifierState
    if states then
        if SafeValue(NPC.HasState, me, states.MODIFIER_STATE_HEXED) == true then
            return false
        end
        if SafeValue(NPC.HasState, me, states.MODIFIER_STATE_COMMAND_RESTRICTED) == true then
            return false
        end
    end
    return true
end

---@param unit userdata|nil
---@return boolean
local function IsInvulnerable(unit)
    if not unit then
        return true
    end
    local states = Enum.modifierState
    if states and SafeValue(NPC.HasState, unit, states.MODIFIER_STATE_INVULNERABLE) == true then
        return true
    end
    return false
end

---@param unit userdata|nil
---@return boolean
local function IsOutOfWorld(unit)
    if not unit then
        return true
    end
    local states = Enum.modifierState
    if states and SafeValue(NPC.HasState, unit, states.MODIFIER_STATE_OUT_OF_GAME) == true then
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

---@param unit userdata|nil
---@return boolean
local function HasDamageReturn(unit)
    if not unit then
        return false
    end
    for i = 1, #DAMAGE_RETURN_MODS do
        if SafeValue(NPC.HasModifier, unit, DAMAGE_RETURN_MODS[i]) == true then
            return true
        end
    end
    return false
end

---@param unit userdata|nil
---@return number
local function HealthPct(unit)
    if not unit then
        return 100
    end
    local hp = SafeValue(Entity.GetHealth, unit) or 0
    local maxHp = SafeValue(Entity.GetMaxHealth, unit) or 0
    if maxHp <= 0 then
        return 100
    end
    return (hp / maxHp) * 100
end

---@param me userdata
---@return number
local function ManaPct(me)
    local mana = SafeValue(NPC.GetMana, me) or 0
    local maxMana = SafeValue(NPC.GetMaxMana, me) or 0
    if maxMana <= 0 then
        return 100
    end
    return (mana / maxMana) * 100
end

---@param ability userdata|nil
---@param me userdata
---@param manaFloor number
---@return boolean
local function IsAbilityCastable(ability, me, manaFloor)
    if not ability then
        return false
    end
    local level = SafeValue(Ability.GetLevel, ability) or 0
    if level <= 0 then
        return false
    end
    if ManaPct(me) < manaFloor then
        return false
    end
    local mana = SafeValue(NPC.GetMana, me) or 0
    return SafeValue(Ability.IsCastable, ability, mana) == true
end

---@param ability userdata|nil
---@param fallback number
---@return number
local function AbilityRange(ability, fallback)
    local range = SafeValue(Ability.GetCastRange, ability)
    if type(range) == "number" and range > 0 then
        return range
    end
    return fallback
end

---@param me userdata
---@param target userdata
---@param range number
---@return boolean
local function InRange(me, target, range)
    local a = SafeValue(Entity.GetAbsOrigin, me)
    local b = SafeValue(Entity.GetAbsOrigin, target)
    return Dist2D(a, b) <= range + 35
end

---@param ability userdata|nil
---@return number
local function CooldownRemaining(ability)
    if not ability then
        return 0
    end
    local remaining = SafeValue(Ability.GetCooldown, ability)
    if type(remaining) == "number" and remaining > 0 then
        return remaining
    end
    return 0
end

---@param ability userdata|nil
---@param me userdata|nil
---@return boolean
local function AbilityRecentlyUsed(ability, me)
    if not ability then
        return false
    end
    local sslu = SafeValue(Ability.SecondsSinceLastUse, ability)
    -- Stub: -1 when not on cooldown; >=0 means used and still cooling down / recently used.
    if type(sslu) == "number" and sslu >= 0 and sslu < ABILITY_RECENT_USE_WINDOW then
        return true
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return true
    end
    if me and SafeValue(NPC.IsChannellingAbility, me) == true then
        return true
    end
    return false
end

---@param ability userdata|nil
---@param abilityName string
---@param now number
---@param me userdata|nil
local function ResolvePendingCast(ability, abilityName, now, me)
    local pending = Runtime.pendingCast
    if not pending or pending.abilityName ~= abilityName then
        return
    end
    if not ability then
        if now - pending.issuedAt > PENDING_CAST_EXPIRE then
            Runtime.pendingCast = nil
        end
        return
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) == true
        or SafeValue(Ability.IsChannelling, ability) == true
    then
        return
    end

    local mana = me and (SafeValue(NPC.GetMana, me) or 0) or 0
    local stillCastable = SafeValue(Ability.IsCastable, ability, mana) == true
    -- Order not consumed yet: keep pending so we do not re-spam the same cast.
    if stillCastable then
        if now - pending.issuedAt > PENDING_CAST_EXPIRE then
            Runtime.pendingCast = nil
        end
        return
    end

    -- Accepted (on CD / not castable) — clear.
    Runtime.pendingCast = nil
end

---@param abilityName string
---@param now number
---@return boolean
local function IsPendingCast(abilityName, now)
    local pending = Runtime.pendingCast
    if not pending or pending.abilityName ~= abilityName then
        return false
    end
    if now - pending.issuedAt > PENDING_CAST_EXPIRE then
        Runtime.pendingCast = nil
        return false
    end
    return true
end

---@param ability userdata
---@param abilityName string
---@param now number
local function MarkPendingCast(ability, abilityName, now)
    Runtime.pendingCast = {
        abilityName = abilityName,
        issuedAt = now,
        cooldownBefore = CooldownRemaining(ability),
    }
end

---@param ability userdata|nil
---@param target userdata
---@param tag string
---@param abilityName string|nil
---@param now number|nil
---@return boolean
local function CastOnTarget(ability, target, tag, abilityName, now)
    if not ability then
        return false
    end
    if GetOrderQueueCount() > 1 then
        return false
    end
    if SafeValue(Ability.IsInAbilityPhase, ability) == true then
        return false
    end
    if abilityName and now and IsPendingCast(abilityName, now) then
        return false
    end
    local ok = TryCall(Ability.CastTarget, ability, target, false, true, true, OrderId(tag))
    if ok == true and abilityName and now then
        MarkPendingCast(ability, abilityName, now)
    end
    return ok == true
end

---@param unit userdata|nil
---@param now number
---@return boolean
local function WasRecentlyHurt(unit, now)
    if not unit then
        return false
    end
    local lastHurt = SafeValue(Hero.GetLastHurtTime, unit)
    if type(lastHurt) == "number" and lastHurt > 0 and now - lastHurt <= HURT_WINDOW then
        return true
    end
    local recent = SafeValue(Hero.GetRecentDamage, unit) or 0
    local maxHp = SafeValue(Entity.GetMaxHealth, unit) or 1
    return recent >= maxHp * 0.05
end

---@param unit userdata|nil
---@param now number
---@return boolean
local function IsPostFpEdictQuiet(unit, now)
    if not unit then
        return false
    end
    local idx = SafeValue(Entity.GetIndex, unit)
    if type(idx) ~= "number" then
        return false
    end
    local untilAt = Runtime.postFpQuietUntil[idx]
    return type(untilAt) == "number" and now < untilAt
end

---@param unit userdata|nil
---@param now number
local function MarkPostFpEdictQuiet(unit, now)
    if not unit then
        return
    end
    local idx = SafeValue(Entity.GetIndex, unit)
    if type(idx) == "number" then
        Runtime.postFpQuietUntil[idx] = now + POST_FP_EDICT_QUIET
    end
end

---@param unit userdata
---@param now number
---@return number recent
---@return number dropPct
local function SampleDamageSignals(unit, now)
    local recent = SafeValue(Hero.GetRecentDamage, unit) or 0
    local hpPct = HealthPct(unit)
    local idx = SafeValue(Entity.GetIndex, unit)
    local dropPct = 0
    if type(idx) == "number" then
        local prev = Runtime.hpHistory[idx]
        if prev and type(prev.hpPct) == "number" and type(prev.at) == "number" then
            local window = UI.fpDropWindow and UI.fpDropWindow:Get() or DEFAULT_FP_HP_DROP_WINDOW
            if now - prev.at <= window then
                dropPct = math.max(0, prev.hpPct - hpPct)
            end
        end
        Runtime.hpHistory[idx] = { hpPct = hpPct, at = now }
    end
    return recent, dropPct
end

---@param me userdata
---@param origin Vector|nil
---@param range number
---@return boolean
local function HasNearbyEnemyHero(me, origin, range)
    if not origin then
        return false
    end
    local heroes = SafeValue(
        Entity.GetHeroesInRadius,
        me,
        range,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )
    if type(heroes) ~= "table" then
        return false
    end
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsAliveUnit(enemy)
            and SafeValue(NPC.IsIllusion, enemy) ~= true
            and not IsOutOfWorld(enemy)
        then
            return true
        end
    end
    return false
end

---@param me userdata
---@param ally userdata
---@param range number
---@return boolean
local function AllyHasNearbyEnemy(me, ally, range)
    local origin = SafeValue(Entity.GetAbsOrigin, ally)
    if not origin then
        return false
    end
    local heroes = SafeValue(
        Entity.GetHeroesInRadius,
        ally,
        range,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )
    if type(heroes) ~= "table" then
        return HasNearbyEnemyHero(me, origin, range)
    end
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsAliveUnit(enemy)
            and SafeValue(NPC.IsIllusion, enemy) ~= true
            and not IsOutOfWorld(enemy)
        then
            return true
        end
    end
    return false
end

---@param enemy userdata|nil
---@param me userdata
---@return boolean
local function IsValidEnemyTarget(enemy, me)
    if not IsAliveUnit(enemy) or enemy == me then
        return false
    end
    if SafeValue(NPC.IsIllusion, enemy) == true then
        return false
    end
    if SafeValue(Entity.IsSameTeam, me, enemy) == true then
        return false
    end
    if IsInvulnerable(enemy) or IsOutOfWorld(enemy) then
        return false
    end
    if SafeValue(NPC.IsVisible, enemy) == false then
        return false
    end
    if not IsSafeCastTarget(enemy) then
        return false
    end
    if UI.skipDamageReturn and UI.skipDamageReturn:Get() == true and HasDamageReturn(enemy) then
        return false
    end
    return true
end

---@param ally userdata|nil
---@param me userdata
---@return boolean
local function IsValidAllyTarget(ally, me)
    if not IsAliveUnit(ally) then
        return false
    end
    if SafeValue(NPC.IsIllusion, ally) == true then
        return false
    end
    if ally ~= me and SafeValue(Entity.IsSameTeam, me, ally) ~= true then
        return false
    end
    if IsInvulnerable(ally) or IsOutOfWorld(ally) then
        return false
    end
    if not IsSafeCastTarget(ally) then
        return false
    end
    return true
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
    if value == "ru" or value:find("рус", 1, true) or value:find("russian", 1, true) then
        return "ru"
    end
    if value == "cn"
        or value == "zh"
        or value:find("chinese", 1, true)
        or value:find("中文", 1, true)
        or value:find("中国", 1, true)
        or value:find("简体", 1, true)
    then
        return "cn"
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

    MenuLabel(MenuNodes.assist, "tab_assist")
    MenuLabel(MenuNodes.main, "group_general")
    MenuLabel(MenuNodes.combo, "tab_combo")
    MenuLabel(MenuNodes.flames, "tab_flames")
    MenuLabel(MenuNodes.fp, "tab_fp")

    MenuLabel(UI.enabled, "ui_enabled")
    MenuTip(UI.enabled, "tip_enabled")
    MenuLabel(UI.comboKey, "ui_combo_key")
    MenuTip(UI.comboKey, "tip_combo_key")
    MenuLabel(UI.debug, "ui_debug")
    MenuTip(UI.debug, "tip_debug")

    MenuLabel(UI.comboEnable, "ui_combo_enable")
    MenuLabel(UI.useFortunes, "ui_use_fortunes")
    MenuLabel(UI.useFlamesSpam, "ui_use_flames_spam")
    MenuLabel(UI.skipDamageReturn, "ui_skip_damage_return")
    MenuTip(UI.skipDamageReturn, "tip_skip_damage_return")

    MenuLabel(UI.flamesEnable, "ui_flames_enable")
    MenuTip(UI.flamesEnable, "tip_flames_enable")
    MenuLabel(UI.flamesHp, "ui_flames_hp")
    MenuLabel(UI.flamesMana, "ui_flames_mana")
    MenuLabel(UI.flamesEnemyRange, "ui_flames_enemy_range")

    MenuLabel(UI.fpEnable, "ui_fp_enable")
    MenuTip(UI.fpEnable, "tip_fp_enable")
    MenuLabel(UI.fpHp, "ui_fp_hp")
    MenuLabel(UI.fpMinDamage, "ui_fp_min_damage")
    MenuTip(UI.fpMinDamage, "tip_fp_min_damage")
    MenuLabel(UI.fpDrop, "ui_fp_drop")
    MenuLabel(UI.fpDropWindow, "ui_fp_drop_window")
    MenuLabel(UI.fpEnemyRange, "ui_fp_enemy_range")
    MenuLabel(UI.fpQuiet, "ui_fp_quiet")
    MenuLabel(UI.fpMana, "ui_fp_mana")
end
--#endregion

--#region Menu
---@param node CThirdTab|CMenuGroup|nil
local function EnsureMenuVisible(node)
    if node and node.Visible then
        node:Visible(true)
    end
end

---@param oracleTab CSecondTab|nil
local function ApplyHeroTabIcon(oracleTab)
    if not oracleTab then
        return
    end

    oracleTab:Image(HERO_ICON)

    local heroId = Engine.GetHeroIDByName(HERO_NAME)
    if heroId then
        oracleTab:LinkHero(heroId, Enum.Attributes.DOTA_ATTRIBUTE_INTELLECT)
    end
end

---Heroes → Hero List → Oracle
---@return CSecondTab|nil
local function FindOrCreateHeroTab()
    if MenuNodes.hero then
        return MenuNodes.hero
    end

    ---@type CTabSection|nil
    local heroList = Menu.Find(MENU_FIRST, MENU_SECTION)
    if not heroList then
        return nil
    end

    ---@type CSecondTab|nil
    local oracleTab = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB)
    if not oracleTab and heroList.Find then
        oracleTab = heroList:Find(HERO_TAB)
    end
    if not oracleTab and heroList.Create then
        oracleTab = heroList:Create(HERO_TAB)
    end
    if not oracleTab then
        oracleTab = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB)
    end
    if not oracleTab then
        return nil
    end

    ApplyHeroTabIcon(oracleTab)
    MenuNodes.hero = oracleTab
    return oracleTab
end

---Heroes → Hero List → Oracle → Oracle Assist
---@return CThirdTab|nil
local function FindOrCreateAssistTab()
    if MenuNodes.assist then
        EnsureMenuVisible(MenuNodes.assist)
        return MenuNodes.assist
    end

    local oracleTab = FindOrCreateHeroTab()
    if not oracleTab then
        return nil
    end

    ---@type CThirdTab|nil
    local tab = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD)
    if not tab and oracleTab.Find then
        tab = oracleTab:Find(MENU_THIRD)
    end
    if not tab and oracleTab.Create then
        tab = oracleTab:Create(MENU_THIRD)
    end
    if not tab then
        tab = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD)
    end
    if not tab then
        return nil
    end

    EnsureMenuVisible(tab)
    MenuNodes.assist = tab
    return tab
end

---@param groupName string
---@param side Enum.GroupSide
---@return CMenuGroup|nil
local function EnsureMenuGroup(groupName, side)
    local assistTab = FindOrCreateAssistTab()
    if not assistTab then
        return nil
    end

    ---@type CMenuGroup|nil
    local group = Menu.Find(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD, groupName)
    if not group and assistTab.Find then
        group = assistTab:Find(groupName)
    end
    if group then
        EnsureMenuVisible(group)
        return group
    end

    ---@type CMenuGroup|nil
    local created = nil
    if assistTab.Create then
        created = assistTab:Create(groupName, side)
    end
    if not created then
        created = Menu.Create(MENU_FIRST, MENU_SECTION, HERO_TAB, MENU_THIRD, groupName)
    end
    EnsureMenuVisible(created)
    return created
end

---@return boolean
local function EnsureMenuTree()
    MenuNodes.main = MenuNodes.main or EnsureMenuGroup("General", Enum.GroupSide.Left)
    MenuNodes.combo = MenuNodes.combo or EnsureMenuGroup("Combo", Enum.GroupSide.Right)
    MenuNodes.flames = MenuNodes.flames or EnsureMenuGroup("Flames Save", Enum.GroupSide.Left)
    MenuNodes.fp = MenuNodes.fp or EnsureMenuGroup("False Promise", Enum.GroupSide.Right)
    return MenuNodes.main ~= nil
        and MenuNodes.combo ~= nil
        and MenuNodes.flames ~= nil
        and MenuNodes.fp ~= nil
end

local function EnsureMenu()
    if UI.enabled
        and UI.comboKey
        and UI.comboEnable
        and UI.useFortunes
        and UI.useFlamesSpam
        and UI.skipDamageReturn
        and UI.flamesEnable
        and UI.flamesHp
        and UI.flamesMana
        and UI.flamesEnemyRange
        and UI.fpEnable
        and UI.fpHp
        and UI.fpMinDamage
        and UI.fpDrop
        and UI.fpDropWindow
        and UI.fpEnemyRange
        and UI.fpQuiet
        and UI.fpMana
        and UI.debug
        and UI.callbacksAttached
    then
        ApplyLocalization(false)
        return
    end

    if not EnsureMenuTree() then
        return
    end

    local main = MenuNodes.main
    local combo = MenuNodes.combo
    local flames = MenuNodes.flames
    local fp = MenuNodes.fp
    ---@cast main CMenuGroup
    ---@cast combo CMenuGroup
    ---@cast flames CMenuGroup
    ---@cast fp CMenuGroup

    if not UI.enabled then
        local existing = main:Find("Enable")
        ---@cast existing CMenuSwitch|nil
        UI.enabled = existing or main:Switch("Enable", ReadBool("enabled", true), Icons.enable)
    end
    MenuIcon(UI.enabled, Icons.enable)

    if not UI.comboKey then
        local existing = main:Find("Combo Key")
        ---@cast existing CMenuBind|nil
        UI.comboKey = existing or main:Bind("Combo Key", Enum.ButtonCode.KEY_NONE, Icons.bind)
        if UI.comboKey and UI.comboKey.Properties then
            UI.comboKey:Properties("Combo Key", "Hold", false)
        end
        if UI.comboKey and UI.comboKey.SetToggled then
            UI.comboKey:SetToggled(false)
        end
    end
    MenuIcon(UI.comboKey, Icons.bind)

    if not UI.debug then
        local existing = main:Find("Debug logs")
        ---@cast existing CMenuSwitch|nil
        UI.debug = existing or main:Switch("Debug logs", ReadBool("debug", false), Icons.debug)
    end
    MenuIcon(UI.debug, Icons.debug)

    if not UI.comboEnable then
        local existing = combo:Find("Combo Enable")
        ---@cast existing CMenuSwitch|nil
        UI.comboEnable = existing or combo:Switch("Combo Enable", ReadBool("combo_enable", true), Icons.combo)
    end
    MenuIcon(UI.comboEnable, Icons.combo)

    if not UI.useFortunes then
        local existing = combo:Find("Use Fortune's End")
        ---@cast existing CMenuSwitch|nil
        UI.useFortunes = existing or combo:Switch("Use Fortune's End", ReadBool("use_fortunes", true))
    end
    MenuImage(UI.useFortunes, SPELL_ICON_FORTUNES_END)

    if not UI.useFlamesSpam then
        local existing = combo:Find("Spam Purifying Flames")
        ---@cast existing CMenuSwitch|nil
        UI.useFlamesSpam = existing
            or combo:Switch("Spam Purifying Flames", ReadBool("use_flames_spam", true))
    end
    MenuImage(UI.useFlamesSpam, SPELL_ICON_PURIFYING_FLAMES)

    if not UI.skipDamageReturn then
        local existing = combo:Find("Skip into Blade Mail / Nyx")
        ---@cast existing CMenuSwitch|nil
        UI.skipDamageReturn = existing
            or combo:Switch("Skip into Blade Mail / Nyx", ReadBool("skip_damage_return", true))
    end
    MenuImage(UI.skipDamageReturn, ITEM_ICON_BLADE_MAIL)

    if not UI.flamesEnable then
        local existing = flames:Find("Enable Flames Save")
        ---@cast existing CMenuSwitch|nil
        UI.flamesEnable = existing
            or flames:Switch("Enable Flames Save", ReadBool("flames_enable", true))
    end
    MenuImage(UI.flamesEnable, SPELL_ICON_FATES_EDICT)

    if not UI.flamesHp then
        local existing = flames:Find("Ally HP% Threshold")
        ---@cast existing CMenuSliderInt|nil
        UI.flamesHp = existing
            or flames:Slider("Ally HP% Threshold", 20, 95, ReadInt("flames_hp", DEFAULT_FLAMES_HP_PCT), "%d")
    end
    MenuIcon(UI.flamesHp, Icons.flamesHp)

    if not UI.flamesMana then
        local existing = flames:Find("Mana Floor %")
        ---@cast existing CMenuSliderInt|nil
        UI.flamesMana = existing
            or flames:Slider("Mana Floor %", 0, 80, ReadInt("flames_mana", DEFAULT_FLAMES_MANA_FLOOR), "%d")
    end
    MenuIcon(UI.flamesMana, Icons.flamesMana)

    if not UI.flamesEnemyRange then
        local existing = flames:Find("Enemy Presence Range")
        ---@cast existing CMenuSliderInt|nil
        UI.flamesEnemyRange = existing
            or flames:Slider(
                "Enemy Presence Range",
                400,
                1800,
                ReadInt("flames_enemy_range", DEFAULT_FLAMES_ENEMY_RANGE),
                "%d"
            )
    end
    MenuIcon(UI.flamesEnemyRange, Icons.flamesRange)

    if not UI.fpEnable then
        local existing = fp:Find("Enable False Promise")
        ---@cast existing CMenuSwitch|nil
        UI.fpEnable = existing or fp:Switch("Enable False Promise", ReadBool("fp_enable", true))
    end
    MenuImage(UI.fpEnable, SPELL_ICON_FALSE_PROMISE)

    if not UI.fpHp then
        local existing = fp:Find("HP% Threshold")
        ---@cast existing CMenuSliderInt|nil
        UI.fpHp = existing or fp:Slider("HP% Threshold", 5, 50, ReadInt("fp_hp", DEFAULT_FP_HP_PCT), "%d")
    end
    MenuIcon(UI.fpHp, Icons.fpHp)

    if not UI.fpMinDamage then
        local existing = fp:Find("Min Recent Damage %")
        ---@cast existing CMenuSliderInt|nil
        UI.fpMinDamage = existing
            or fp:Slider("Min Recent Damage %", 2, 40, ReadInt("fp_min_damage", DEFAULT_FP_MIN_DAMAGE_PCT), "%d")
    end
    MenuIcon(UI.fpMinDamage, Icons.fpDamage)

    if not UI.fpDrop then
        local existing = fp:Find("Min HP% Drop")
        ---@cast existing CMenuSliderInt|nil
        UI.fpDrop = existing or fp:Slider("Min HP% Drop", 5, 50, ReadInt("fp_drop", DEFAULT_FP_HP_DROP_PCT), "%d")
    end
    MenuIcon(UI.fpDrop, Icons.fpDrop)

    if not UI.fpDropWindow then
        local existing = fp:Find("HP Drop Window (s)")
        ---@cast existing CMenuSliderFloat|nil
        UI.fpDropWindow = existing
            or fp:Slider(
                "HP Drop Window (s)",
                0.10,
                1.50,
                ReadFloat("fp_drop_window", DEFAULT_FP_HP_DROP_WINDOW),
                "%.2f"
            )
    end
    MenuIcon(UI.fpDropWindow, Icons.fpWindow)

    if not UI.fpEnemyRange then
        local existing = fp:Find("Enemy Presence Range")
        ---@cast existing CMenuSliderInt|nil
        UI.fpEnemyRange = existing
            or fp:Slider(
                "Enemy Presence Range",
                500,
                2000,
                ReadInt("fp_enemy_range", DEFAULT_FP_ENEMY_RANGE),
                "%d"
            )
    end
    MenuIcon(UI.fpEnemyRange, Icons.fpRange)

    if not UI.fpQuiet then
        local existing = fp:Find("Quiet After Cast (s)")
        ---@cast existing CMenuSliderFloat|nil
        UI.fpQuiet = existing
            or fp:Slider("Quiet After Cast (s)", 0.20, 3.00, ReadFloat("fp_quiet", DEFAULT_FP_QUIET), "%.2f")
    end
    MenuIcon(UI.fpQuiet, Icons.fpQuiet)

    if not UI.fpMana then
        local existing = fp:Find("Mana Floor %")
        ---@cast existing CMenuSliderInt|nil
        UI.fpMana = existing or fp:Slider("Mana Floor %", 0, 80, ReadInt("fp_mana", DEFAULT_FP_MANA_FLOOR), "%d")
    end
    MenuIcon(UI.fpMana, Icons.fpMana)

    local menuReady = UI.enabled
        and UI.comboKey
        and UI.debug
        and UI.comboEnable
        and UI.useFortunes
        and UI.useFlamesSpam
        and UI.skipDamageReturn
        and UI.flamesEnable
        and UI.flamesHp
        and UI.flamesMana
        and UI.flamesEnemyRange
        and UI.fpEnable
        and UI.fpHp
        and UI.fpMinDamage
        and UI.fpDrop
        and UI.fpDropWindow
        and UI.fpEnemyRange
        and UI.fpQuiet
        and UI.fpMana

    if menuReady and not UI.callbacksAttached then
        UI.enabled:SetCallback(function(widget)
            WriteBool("enabled", widget:Get() == true)
            if widget:Get() ~= true then
                ResetRuntime()
            end
        end, false)

        UI.comboEnable:SetCallback(function(widget)
            WriteBool("combo_enable", widget:Get() == true)
        end, false)
        UI.useFortunes:SetCallback(function(widget)
            WriteBool("use_fortunes", widget:Get() == true)
        end, false)
        UI.useFlamesSpam:SetCallback(function(widget)
            WriteBool("use_flames_spam", widget:Get() == true)
        end, false)
        UI.skipDamageReturn:SetCallback(function(widget)
            WriteBool("skip_damage_return", widget:Get() == true)
        end, false)
        UI.flamesEnable:SetCallback(function(widget)
            WriteBool("flames_enable", widget:Get() == true)
        end, false)
        UI.flamesHp:SetCallback(function(widget)
            WriteInt("flames_hp", widget:Get())
        end, false)
        UI.flamesMana:SetCallback(function(widget)
            WriteInt("flames_mana", widget:Get())
        end, false)
        UI.flamesEnemyRange:SetCallback(function(widget)
            WriteInt("flames_enemy_range", widget:Get())
        end, false)
        UI.fpEnable:SetCallback(function(widget)
            WriteBool("fp_enable", widget:Get() == true)
        end, false)
        UI.fpHp:SetCallback(function(widget)
            WriteInt("fp_hp", widget:Get())
        end, false)
        UI.fpMinDamage:SetCallback(function(widget)
            WriteInt("fp_min_damage", widget:Get())
        end, false)
        UI.fpDrop:SetCallback(function(widget)
            WriteInt("fp_drop", widget:Get())
        end, false)
        UI.fpDropWindow:SetCallback(function(widget)
            WriteFloat("fp_drop_window", widget:Get())
        end, false)
        UI.fpEnemyRange:SetCallback(function(widget)
            WriteInt("fp_enemy_range", widget:Get())
        end, false)
        UI.fpQuiet:SetCallback(function(widget)
            WriteFloat("fp_quiet", widget:Get())
        end, false)
        UI.fpMana:SetCallback(function(widget)
            WriteInt("fp_mana", widget:Get())
        end, false)
        UI.debug:SetCallback(function(widget)
            local on = widget:Get() == true
            WriteBool("debug", on)
            LogWrite(on and "debug ON" or "debug OFF")
        end, false)

        UI.callbacksAttached = true
    end

    ApplyLocalization(true)
end
--#endregion

--#region Combo
---@param me userdata
---@param now number
---@param maxRange number
---@return userdata|nil
local function ResolveComboTarget(me, now, maxRange)
    if Runtime.comboTarget
        and IsValidEnemyTarget(Runtime.comboTarget, me)
        and InRange(me, Runtime.comboTarget, maxRange + 150)
    then
        if now - Runtime.lastTargetResolveAt < TARGET_LOCK_INTERVAL then
            return Runtime.comboTarget
        end
    end

    Runtime.lastTargetResolveAt = now
    local myTeam = SafeValue(Entity.GetTeamNum, me)
    if type(myTeam) ~= "number" then
        return nil
    end

    local cursorHero = SafeValue(Input.GetNearestHeroToCursor, myTeam, Enum.TeamType.TEAM_ENEMY)
    if cursorHero and IsValidEnemyTarget(cursorHero, me) and InRange(me, cursorHero, maxRange + 200) then
        Runtime.comboTarget = cursorHero
        return cursorHero
    end

    local heroes = SafeValue(
        Entity.GetHeroesInRadius,
        me,
        maxRange + 200,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )
    if type(heroes) ~= "table" then
        Runtime.comboTarget = nil
        return nil
    end

    local best, bestDist = nil, math.huge
    local mePos = SafeValue(Entity.GetAbsOrigin, me)
    for i = 1, #heroes do
        local enemy = heroes[i]
        if IsValidEnemyTarget(enemy, me) then
            local dist = Dist2D(mePos, SafeValue(Entity.GetAbsOrigin, enemy))
            if dist < bestDist then
                best = enemy
                bestDist = dist
            end
        end
    end

    Runtime.comboTarget = best
    return best
end

---@param now number
---@param me userdata
---@return boolean
local function UpdateCombo(now, me)
    if not UI.comboEnable or UI.comboEnable:Get() ~= true then
        Runtime.comboTarget = nil
        return false
    end
    if not IsBindHeld(UI.comboKey) then
        Runtime.comboTarget = nil
        return false
    end
    if now - Runtime.lastCastAt < CAST_DEDUP then
        return false
    end
    if SafeValue(NPC.IsChannellingAbility, me) == true then
        DbgThrottled(now, "combo: channelling, wait")
        return false
    end

    local fortunes = SafeValue(NPC.GetAbility, me, ABILITY_FORTUNES_END)
    local flames = SafeValue(NPC.GetAbility, me, ABILITY_PURIFYING_FLAMES)
    ResolvePendingCast(fortunes, ABILITY_FORTUNES_END, now, me)
    ResolvePendingCast(flames, ABILITY_PURIFYING_FLAMES, now, me)

    local feRange = AbilityRange(fortunes, DEFAULT_FE_RANGE)
    local pfRange = AbilityRange(flames, DEFAULT_PF_RANGE)
    local maxRange = math.max(feRange, pfRange)
    local target = ResolveComboTarget(me, now, maxRange)
    if not target then
        DbgThrottled(now, "combo: no target in range %.0f", maxRange)
        return false
    end

    local manaFloor = 0
    if UI.useFortunes
        and UI.useFortunes:Get() == true
        and not IsPendingCast(ABILITY_FORTUNES_END, now)
        and IsAbilityCastable(fortunes, me, manaFloor)
        and InRange(me, target, feRange)
        and SafeValue(NPC.IsLinkensProtected, target) ~= true
    then
        if CastOnTarget(fortunes, target, "combo.fe", ABILITY_FORTUNES_END, now) then
            Runtime.lastCastAt = now
            Dbg("combo: Fortune's End -> %s", FmtUnit(target))
            return true
        end
    end

    if UI.useFlamesSpam
        and UI.useFlamesSpam:Get() == true
        and not IsPendingCast(ABILITY_PURIFYING_FLAMES, now)
        and not IsPendingCast(ABILITY_FORTUNES_END, now)
        and IsAbilityCastable(flames, me, manaFloor)
        and InRange(me, target, pfRange)
        and SafeValue(NPC.IsLinkensProtected, target) ~= true
    then
        if CastOnTarget(flames, target, "combo.pf", ABILITY_PURIFYING_FLAMES, now) then
            Runtime.lastCastAt = now
            Dbg("combo: Purifying Flames -> %s", FmtUnit(target))
            return true
        end
    end

    return false
end
--#endregion

--#region AutoSave
---@param now number
---@param me userdata
---@return boolean
local function TryFalsePromise(now, me)
    if not UI.fpEnable or UI.fpEnable:Get() ~= true then
        return false
    end

    local quiet = UI.fpQuiet and UI.fpQuiet:Get() or DEFAULT_FP_QUIET
    if now - Runtime.lastFpCastAt < quiet then
        return false
    end
    if now - Runtime.lastCastAt < CAST_DEDUP then
        return false
    end
    if SafeValue(NPC.IsChannellingAbility, me) == true then
        return false
    end

    local ability = SafeValue(NPC.GetAbility, me, ABILITY_FALSE_PROMISE)
    ResolvePendingCast(ability, ABILITY_FALSE_PROMISE, now, me)
    local manaFloor = UI.fpMana and UI.fpMana:Get() or DEFAULT_FP_MANA_FLOOR
    if IsPendingCast(ABILITY_FALSE_PROMISE, now) or not IsAbilityCastable(ability, me, manaFloor) then
        return false
    end

    local castRange = AbilityRange(ability, DEFAULT_FP_RANGE)
    local hpThreshold = UI.fpHp and UI.fpHp:Get() or DEFAULT_FP_HP_PCT
    local minDamagePct = UI.fpMinDamage and UI.fpMinDamage:Get() or DEFAULT_FP_MIN_DAMAGE_PCT
    local minDropPct = UI.fpDrop and UI.fpDrop:Get() or DEFAULT_FP_HP_DROP_PCT
    local enemyRange = UI.fpEnemyRange and UI.fpEnemyRange:Get() or DEFAULT_FP_ENEMY_RANGE

    local allies = SafeValue(
        Entity.GetHeroesInRadius,
        me,
        castRange + 50,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    )
    if type(allies) ~= "table" then
        return false
    end

    ---@type userdata|nil
    local best = nil
    local bestScore = -math.huge

    for i = 1, #allies do
        local ally = allies[i]
        if IsValidAllyTarget(ally, me) and InRange(me, ally, castRange) then
            if SafeValue(NPC.HasModifier, ally, MOD_FALSE_PROMISE) ~= true then
                local hpPct = HealthPct(ally)
                -- Hard floor: never ult full / high HP allies (BB chip false positives).
                if hpPct <= hpThreshold then
                    local recent, dropPct = SampleDamageSignals(ally, now)
                    local maxHp = SafeValue(Entity.GetMaxHealth, ally) or 1
                    local meaningful = recent >= maxHp * (minDamagePct / 100.0)
                    local dropped = dropPct >= minDropPct
                    local enemyNear = AllyHasNearbyEnemy(me, ally, enemyRange)
                    if (meaningful or dropped) and enemyNear then
                        local score = (100 - hpPct) * 1.5 + (recent / math.max(1, maxHp)) * 40 + dropPct
                        if score > bestScore then
                            best = ally
                            bestScore = score
                        end
                    else
                        DbgThrottled(
                            now,
                            "fp skip %s: hp=%.1f meaningful=%s drop=%.1f enemyNear=%s",
                            FmtUnit(ally),
                            hpPct,
                            tostring(meaningful),
                            dropPct,
                            tostring(enemyNear)
                        )
                    end
                else
                    SampleDamageSignals(ally, now)
                end
            end
        end
    end

    if not best then
        return false
    end

    if CastOnTarget(ability, best, "save.fp", ABILITY_FALSE_PROMISE, now) then
        Runtime.lastFpCastAt = now
        Runtime.lastCastAt = now
        -- Avoid Edict (disarm) on the same ally right after FP ends.
        MarkPostFpEdictQuiet(best, now)
        Dbg("fp cast -> %s score=%.1f hp=%.1f", FmtUnit(best), bestScore, HealthPct(best))
        return true
    end
    Dbg("fp cast failed -> %s", FmtUnit(best))
    return false
end

---@param now number
---@param me userdata
---@return boolean
local function ContinueFlamesStage(now, me)
    local stage = Runtime.flamesStage
    if not stage then
        return false
    end
    if now - stage.startedAt > FLAMES_STAGE_TIMEOUT then
        Runtime.flamesStage = nil
        return false
    end
    if not IsValidAllyTarget(stage.target, me) then
        Runtime.flamesStage = nil
        return false
    end
    if now - Runtime.lastCastAt < CAST_DEDUP then
        return true
    end
    if SafeValue(NPC.IsChannellingAbility, me) == true then
        return true
    end

    local flames = SafeValue(NPC.GetAbility, me, ABILITY_PURIFYING_FLAMES)
    local edict = SafeValue(NPC.GetAbility, me, ABILITY_FATES_EDICT)
    ResolvePendingCast(edict, ABILITY_FATES_EDICT, now, me)
    ResolvePendingCast(flames, ABILITY_PURIFYING_FLAMES, now, me)
    local manaFloor = UI.flamesMana and UI.flamesMana:Get() or DEFAULT_FLAMES_MANA_FLOOR
    local pfRange = AbilityRange(flames, DEFAULT_PF_RANGE)

    if stage.stage == "edict" then
        local hasEdict = SafeValue(NPC.HasModifier, stage.target, MOD_FATES_EDICT) == true
        local hasFp = SafeValue(NPC.HasModifier, stage.target, MOD_FALSE_PROMISE) == true
        if hasEdict or hasFp then
            stage.stage = "flames"
            stage.startedAt = now
        elseif stage.edictIssued or IsPendingCast(ABILITY_FATES_EDICT, now) then
            -- Wait for modifier / cooldown instead of re-spamming Edict orders.
            return true
        else
            local edictRange = AbilityRange(edict, DEFAULT_EDICT_RANGE)
            if IsAbilityCastable(edict, me, manaFloor) and InRange(me, stage.target, edictRange) then
                if CastOnTarget(edict, stage.target, "save.edict", ABILITY_FATES_EDICT, now) then
                    Runtime.lastCastAt = now
                    stage.startedAt = now
                    stage.edictIssued = true
                    Dbg("flames-stage: Edict -> %s", FmtUnit(stage.target))
                    return true
                end
            end
            return true
        end
    end

    if stage.stage == "flames" then
        if IsPendingCast(ABILITY_PURIFYING_FLAMES, now) then
            return true
        end
        if not IsAbilityCastable(flames, me, manaFloor) or not InRange(me, stage.target, pfRange) then
            return true
        end
        if CastOnTarget(flames, stage.target, "save.pf", ABILITY_PURIFYING_FLAMES, now) then
            Runtime.lastCastAt = now
            Runtime.lastFlamesSaveAt = now
            Runtime.flamesStage = nil
            Dbg("flames-stage: Flames -> %s", FmtUnit(stage.target))
            return true
        end
        return true
    end

    Runtime.flamesStage = nil
    return false
end

---@param me userdata
---@param flames userdata|nil
---@param pfRange number
---@return userdata|nil
---@return number
local function BestAllyUnderFalsePromise(me, flames, pfRange)
    if not flames then
        return nil, -math.huge
    end
    local allies = SafeValue(
        Entity.GetHeroesInRadius,
        me,
        pfRange + 50,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    )
    if type(allies) ~= "table" then
        return nil, -math.huge
    end

    ---@type userdata|nil
    local best = nil
    local bestScore = -math.huge
    for i = 1, #allies do
        local ally = allies[i]
        if IsValidAllyTarget(ally, me)
            and SafeValue(NPC.HasModifier, ally, MOD_FALSE_PROMISE) == true
            and InRange(me, ally, pfRange)
        then
            -- FP freezes displayed HP; prefer the most recently hurt / lowest frozen %.
            local score = (100 - HealthPct(ally)) + 50
            if score > bestScore then
                best = ally
                bestScore = score
            end
        end
    end
    return best, bestScore
end

---@param now number
---@param me userdata
---@return boolean
local function TryFlamesSave(now, me)
    if not UI.flamesEnable or UI.flamesEnable:Get() ~= true then
        return false
    end
    if Runtime.flamesStage then
        return ContinueFlamesStage(now, me)
    end
    if now - Runtime.lastCastAt < CAST_DEDUP then
        return false
    end
    if SafeValue(NPC.IsChannellingAbility, me) == true then
        return false
    end

    local edict = SafeValue(NPC.GetAbility, me, ABILITY_FATES_EDICT)
    local flames = SafeValue(NPC.GetAbility, me, ABILITY_PURIFYING_FLAMES)
    ResolvePendingCast(edict, ABILITY_FATES_EDICT, now, me)
    ResolvePendingCast(flames, ABILITY_PURIFYING_FLAMES, now, me)
    local manaFloor = UI.flamesMana and UI.flamesMana:Get() or DEFAULT_FLAMES_MANA_FLOOR
    local edictReady = not IsPendingCast(ABILITY_FATES_EDICT, now)
        and not AbilityRecentlyUsed(edict, me)
        and IsAbilityCastable(edict, me, manaFloor)
    local flamesReady = not IsPendingCast(ABILITY_PURIFYING_FLAMES, now)
        and not AbilityRecentlyUsed(flames, me)
        and IsAbilityCastable(flames, me, manaFloor)
    if not flamesReady and not edictReady then
        return false
    end

    local pfRange = AbilityRange(flames, DEFAULT_PF_RANGE)
    local edictRange = AbilityRange(edict, DEFAULT_EDICT_RANGE)

    -- PF under FP: gate on real cooldown only (IsCastable can lie during phase).
    --   issue → awaitingCd → cd>0 confirms once → cd==0 unlocks next cast
    do
        local cdLeft = CooldownRemaining(flames)
        local onCooldown = cdLeft > 0.05

        if Runtime.fpFlamesAwaitingCd then
            if onCooldown then
                if not Runtime.fpFlamesSawCd then
                    Runtime.fpFlamesSawCd = true
                    Dbg("flames-save: Flames under FP -> %s", Runtime.fpFlamesTargetName or "?")
                end
            elseif Runtime.fpFlamesSawCd then
                -- Cooldown finished — ready for the next cast.
                Runtime.fpFlamesAwaitingCd = false
                Runtime.fpFlamesSawCd = false
                Runtime.fpFlamesTargetName = nil
            elseif now - Runtime.fpFlamesIssuedAt >= FP_FLAMES_STUCK_RETRY then
                -- Silent retry: order may still land; avoid log spam.
                Runtime.fpFlamesAwaitingCd = false
                Runtime.fpFlamesSawCd = false
                Runtime.fpFlamesTargetName = nil
            end
        end

        local gap = FP_FLAMES_MIN_GAP
        local cdLen = SafeValue(Ability.GetCooldownLength, flames)
        if type(cdLen) == "number" and cdLen > 0.5 then
            gap = math.max(FP_FLAMES_MIN_GAP, cdLen - 0.20)
        end

        local allowFpFlames = flamesReady
            and not onCooldown
            and not Runtime.fpFlamesAwaitingCd
            and (now - Runtime.fpFlamesIssuedAt >= gap)

        if allowFpFlames then
            local fpAlly = BestAllyUnderFalsePromise(me, flames, pfRange)
            if fpAlly then
                if CastOnTarget(flames, fpAlly, "save.pf.fp", ABILITY_PURIFYING_FLAMES, now) then
                    Runtime.lastCastAt = now
                    Runtime.lastFlamesSaveAt = now
                    Runtime.fpFlamesAwaitingCd = true
                    Runtime.fpFlamesSawCd = false
                    Runtime.fpFlamesIssuedAt = now
                    Runtime.fpFlamesTargetName = FmtUnit(fpAlly)
                    return true
                end
            end
        end
    end

    if now - Runtime.lastFlamesSaveAt < DEFAULT_FLAMES_QUIET then
        return false
    end

    local scanRange = math.max(pfRange, edictRange) + 50
    local hpThreshold = UI.flamesHp and UI.flamesHp:Get() or DEFAULT_FLAMES_HP_PCT
    local enemyRange = UI.flamesEnemyRange and UI.flamesEnemyRange:Get() or DEFAULT_FLAMES_ENEMY_RANGE

    local allies = SafeValue(
        Entity.GetHeroesInRadius,
        me,
        scanRange,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    )
    if type(allies) ~= "table" then
        return false
    end

    ---@type userdata|nil
    local best = nil
    local bestScore = -math.huge
    local bestHasEdict = false

    for i = 1, #allies do
        local ally = allies[i]
        if IsValidAllyTarget(ally, me) then
            -- Skip allies under FP (handled above) and allies we just ulted (no Edict disarm).
            if SafeValue(NPC.HasModifier, ally, MOD_FALSE_PROMISE) ~= true
                and not IsPostFpEdictQuiet(ally, now)
            then
                local hpPct = HealthPct(ally)
                if hpPct <= hpThreshold then
                    local hasFlames = SafeValue(NPC.HasModifier, ally, MOD_PURIFYING_FLAMES) == true
                    local hasEdict = SafeValue(NPC.HasModifier, ally, MOD_FATES_EDICT) == true
                    local hurt = WasRecentlyHurt(ally, now)
                    local enemyNear = AllyHasNearbyEnemy(me, ally, enemyRange)
                    if (hurt or enemyNear) and not hasFlames then
                        local inPfRange = InRange(me, ally, pfRange)
                        local inEdictRange = InRange(me, ally, edictRange)
                        local canChain = (hasEdict and flamesReady and inPfRange)
                            or (edictReady and flamesReady and inEdictRange and inPfRange)
                            or (hasEdict == false and edictReady and inEdictRange)
                        if canChain then
                            local score = (100 - hpPct) + (hurt and 18 or 0) + (enemyNear and 10 or 0)
                            if score > bestScore then
                                best = ally
                                bestScore = score
                                bestHasEdict = hasEdict
                            end
                        end
                    end
                end
            end
        end
    end

    if not best then
        return false
    end

    if bestHasEdict or SafeValue(NPC.HasModifier, best, MOD_FATES_EDICT) == true then
        if flamesReady and InRange(me, best, pfRange) then
            if CastOnTarget(flames, best, "save.pf", ABILITY_PURIFYING_FLAMES, now) then
                Runtime.lastCastAt = now
                Runtime.lastFlamesSaveAt = now
                Dbg("flames-save: Flames after Edict -> %s hp=%.1f", FmtUnit(best), HealthPct(best))
                return true
            end
        end
        return false
    end

    if edictReady and InRange(me, best, edictRange) then
        if CastOnTarget(edict, best, "save.edict", ABILITY_FATES_EDICT, now) then
            Runtime.lastCastAt = now
            Runtime.flamesStage = {
                target = best,
                stage = "edict",
                startedAt = now,
                edictIssued = true,
            }
            Dbg("flames-save: start Edict -> Flames on %s hp=%.1f", FmtUnit(best), HealthPct(best))
            return true
        end
    end

    return false
end

---@param now number
---@param me userdata
---@return boolean
local function UpdateAutoSave(now, me)
    if TryFalsePromise(now, me) then
        return true
    end
    if TryFlamesSave(now, me) then
        return true
    end
    return false
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    EnsureMenu()
    LogWrite("loaded")
    if IsDebugOn() then
        LogWrite("debug already enabled")
    end
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end

    EnsureMenu()
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Input.IsInputCaptured() then
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

    local me = Heroes.GetLocal()
    if not IsLocalOracle(me) then
        DbgThrottled(now, "idle: local hero is not Oracle")
        return
    end
    ---@cast me userdata
    if not CanCastActions(me) then
        DbgThrottled(now, "idle: cannot cast (stun/silence/hex)")
        return
    end

    if UpdateAutoSave(now, me) then
        return
    end
    UpdateCombo(now, me)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
