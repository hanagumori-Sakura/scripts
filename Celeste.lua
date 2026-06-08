---@diagnostic disable: undefined-global

-- Кэширование глобальных функций Lua для повышения производительности
local math_sin = math.sin
local math_cos = math.cos
local math_random = math.random
local math_pi = math.pi
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local ipairs_cached = ipairs
local pcall_cached = pcall

local VERSION = "5.0.0"
local DEBUG_PREFIX = "[Celeste]"
local HERO_ID = 81
local UNIT_METER = 37.7358490566
local READY_EPSILON = 0.05
local TARGET_STICKY_FOV_BUFFER = 8.0
local TARGET_STICKY_RANGE_BUFFER_M = 5.0
local DEFAULT_TARGET_POINT_Z = 45.0
local DEFAULT_EYE_HEIGHT = 60.0
local DEFAULT_A3_REPRESS_DELAY = 0.35
local DEFAULT_ULT_SPEED = 1200.0
local DEFAULT_ULT_AOE = 400.0
local GUARD_BUFF_NAME = "modifier_unicorn_prismatic_guard_buff"

local STATUS = {
    READY = 0,
    COOLDOWN = 2,
    PASSIVE = 3,
    BUSY = 10,
}

local SLOT = {
    A1 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_1) or 0,
    A2 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_2) or 1,
    A3 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_3) or 2,
    A4 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_4) or 3,
}

local BIT = {
    A1 = InputBitMask_t.IN_ABILITY1,
    A2 = InputBitMask_t.IN_ABILITY2,
    A3 = InputBitMask_t.IN_ABILITY3,
    A4 = InputBitMask_t.IN_ABILITY4,
}

local MODSTATE = {
    IMMOBILIZED = (EModifierState and EModifierState.MODIFIER_STATE_IMMOBILIZED) or 10,
    SILENCED = (EModifierState and EModifierState.MODIFIER_STATE_SILENCED) or 14,
    STUNNED = (EModifierState and EModifierState.MODIFIER_STATE_STUNNED) or 17,
    INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_INVULNERABLE) or 18,
    TECH_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_INVULNERABLE) or 19,
    TECH_DAMAGE_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_DAMAGE_INVULNERABLE) or 20,
    STATUS_IMMUNE = (EModifierState and EModifierState.MODIFIER_STATE_STATUS_IMMUNE) or 22,
    OUT_OF_GAME = (EModifierState and EModifierState.MODIFIER_STATE_OUT_OF_GAME) or 24,
    COMMAND_RESTRICTED = (EModifierState and EModifierState.MODIFIER_STATE_COMMAND_RESTRICTED) or 25,
    BUSY_WITH_ACTION = (EModifierState and EModifierState.MODIFIER_STATE_BUSY_WITH_ACTION) or 55,
    BULLET_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_BULLET_INVULNERABLE) or 85,
    UNIT_STATUS_HIDDEN = (EModifierState and EModifierState.MODIFIER_STATE_UNIT_STATUS_HIDDEN) or 108,
    NO_INCOMING_DAMAGE = (EModifierState and EModifierState.MODIFIER_STATE_NO_INCOMING_DAMAGE) or 136,
}

local ICON = {
    TAB = "\u{f7d9}",
    ENABLE = "\u{f011}",
    KEY = "\u{f084}",
    CLOCK = "\u{f017}",
    LOCK = "\u{f023}",
    TARGET = "\u{f140}",
    FOV = "\u{f06e}",
    RANGE = "\u{f124}",
    HP = "\u{f21e}",
    GROUP = "\u{f0c0}",
    SHIELD = "\u{f132}",
    BLAST = "\u{f0e7}",
    DAGGER = "\u{f71b}",
    STAR = "\u{f005}",
    PSILENT = "\u{f05b}",
    STEER = "\u{f57d}",
    NET = "\u{f1eb}",
    DEBUG = "\u{f188}",
}

local BONE_PRIORITY = {
    "spine_2",
    "spine_1",
    "chest",
    "neck_0",
    "head",
}

local celeste = {
    target = nil,
    target_lock_expires = 0,
    last_cast_time = 0,
    ability_cast_times = {
        a1 = 0,
        a2 = 0,
        a3 = 0,
        a4 = 0,
    },
}

-- Статические переиспользуемые Vector и Vec2 шаблоны для исключения аллокаций
local vZero = Vec2(0, 0)
local vScreen = Vec2(1920, 1080)
local vTempVec1 = Vec2(0, 0)
local vTempVec2 = Vec2(0, 0)
local vTempWorld = Vector(0, 0, 0)
local vPredictWorld = Vector(0, 0, 0)

-- Глобальные кэшируемые переменные рендеринга
local hudFont = nil

-- ═══════════════════════════════════════════════════════════════
--  Инициализация UI через NEW_UI_LIB
-- ═══════════════════════════════════════════════════════════════
local hero_root = Menu.Find("Heroes", "Hero List", "hero_unicorn")
local tab
if hero_root then
    tab = NEW_UI_LIB.create_tab(false, hero_root, "Prismatic Core")
else
    tab = NEW_UI_LIB.create_tab(false, "Heroes", "Hero List", "hero_unicorn", "Prismatic Core")
end
local g_general = tab:create("General")
local g_targeting = tab:create("Targeting")
local g_guard = tab:create("Prismatic Guard (2)")
local g_a1 = tab:create("Radiant Blast (1)")
local g_a3 = tab:create("Radiant Daggers (3)")
local g_a4 = tab:create("Shining Wonder (4)")
local g_prediction = tab:create("Prediction")
local g_drawings = tab:create("Visuals & ESP")
local g_debug = tab:create("Debug")

local script = {}

script.enabled = g_general:switch("Enable Script", true, ICON.ENABLE, "Enables the Celeste assist logic")
script.comboKey = g_general:bind("Combo Key", Enum.ButtonCode.KEY_X, ICON.KEY, "Hold to engage combo sequence")
script.castDebounce = g_general:slider("Cast Debounce (ms)", 0, 250, 80, "%d", ICON.CLOCK,
    "Anti-spam delay between casts")

script.targetLock = g_targeting:switch("Sticky Target", true, ICON.LOCK, "Keep locked to target for a duration")
script.targetSticky = script.targetLock:slider("Stick Time (ms)", 50, 600, 280, "%d", ICON.CLOCK,
    "Lock duration after target leaves cursor")
script.targetPrio = g_targeting:combo("Priority", { "FOV", "HP%", "Distance" }, 1, ICON.TARGET,
    "Target selection heuristic")
script.targetFov = g_targeting:slider("Engagement FOV", 1, 180, 25, "%d", ICON.FOV, "Aim assist FOV angle")
script.targetRange = g_targeting:slider("Max Distance (m)", 5, 70, 40, "%d", ICON.RANGE,
    "Maximum combat tracking distance")

script.guard = g_guard:switch("Auto Guard (2)", true, ICON.SHIELD, "Automatically cast shield to protect Celeste")
script.guardHp = script.guard:slider("HP Threshold %", 1, 100, 70, "%d", ICON.HP,
    "Cast shield if HP drops below this percent")
script.guardRange = script.guard:slider("Threat Range (m)", 5, 35, 18, "%d", ICON.RANGE,
    "Threat radius to look for enemies")
script.guardMinEnemies = script.guard:slider("Min Nearby Enemies", 1, 6, 1, "%d", ICON.GROUP,
    "Minimum number of enemies within range to trigger shield")

script.a1 = g_a1:switch("Use Blast (1)", true, ICON.BLAST, "Use Radiant Blast (1) in combo")
script.a1RequireVis = script.a1:switch("Require Visibility", true, "\u{f06e}", "Verify target is visible before casting")
script.a1AimFallback = script.a1:switch("Aim Fallback", true, ICON.TARGET,
    "Aim using camera-locking if Silent Aim is not possible")

script.a3 = g_a3:switch("Use Daggers (3)", true, ICON.DAGGER, "Use Radiant Daggers (3) in combo")
script.a3RepressDelay = script.a3:slider("Recast Delay (s)", 0.05, 1.00, DEFAULT_A3_REPRESS_DELAY, "%.2f", ICON.CLOCK,
    "Delay before allowing dagger recast")
script.a3RequireVis = script.a3:switch("Require Ground Vis", true, "\u{f06e}", "Verify ground target position is visible")
script.a3AimFallback = script.a3:switch("Aim Fallback", true, ICON.TARGET,
    "Aim using camera-locking if Silent Aim is not possible")

script.a4 = g_a4:switch("Use Ultimate (4)", true, ICON.STAR, "Use Shining Wonder (4) in combo")
script.a4MinEnemies = script.a4:slider("Min Enemies to Cast", 1, 6, 1, "%d", ICON.GROUP,
    "Minimum enemies caught in AoE to cast")
script.a4HardlockFov = script.a4:slider("Aim Lock FOV", 1, 45, 16, "%d", ICON.FOV,
    "FOV angle to snap camera when casting")
script.a4Steer = g_a4:switch("Steer Active Orb", true, ICON.STEER,
    "Steer the ultimate orb towards target while it is active")
script.a4SteerFov = script.a4Steer:slider("Steer FOV", 1, 45, 20, "%d", ICON.FOV,
    "FOV angle to steer active ultimate orb")

script.predictLatency = g_prediction:switch("Latency Compensation", true, ICON.NET,
    "Add current network ping to prediction offset")
script.predictBias = g_prediction:slider("Extra Bias (ms)", 0, 200, 0, "%d", ICON.CLOCK,
    "Manual latency adjustment in milliseconds")
script.predictMaxTime = g_prediction:slider("Max Predict Time (s)", 0.05, 1.50, 0.60, "%.2f", ICON.CLOCK,
    "Safety cap on prediction duration")

script.drawFov = g_drawings:switch("Draw FOV Circle", true, ICON.FOV, "Draw assist FOV circle around crosshair")
script.drawTarget = g_drawings:switch("Draw Target ESP", true, ICON.TARGET, "Highlight current target with a 3D overlay")
script.drawPred = g_drawings:switch("Draw Prediction Marker", true, ICON.STAR,
    "Draw predicted landing spot on the ground")
script.drawHud = g_drawings:switch("Draw HUD Info", true, ICON.TAB, "Display target info overlay")
script.themeColor = g_drawings:colorpicker("Theme Color", Color(0, 180, 255, 220), "\u{f1fc}",
    "Custom accent color for overlays and text")

script.debug = g_debug:switch("Debug Logging", false, ICON.DEBUG, "Enable diagnostic prints to console")

-- Связи видимости настроек (скрывает опции, когда их родительский свитч выключен)
script.targetSticky:link_to_ui_visible_condition(script.targetLock)

script.guardHp:link_to_ui_visible_condition(script.guard)
script.guardRange:link_to_ui_visible_condition(script.guard)
script.guardMinEnemies:link_to_ui_visible_condition(script.guard)

script.a1RequireVis:link_to_ui_visible_condition(script.a1)
script.a1AimFallback:link_to_ui_visible_condition(script.a1)

script.a3RepressDelay:link_to_ui_visible_condition(script.a3)
script.a3RequireVis:link_to_ui_visible_condition(script.a3)
script.a3AimFallback:link_to_ui_visible_condition(script.a3)

script.a4MinEnemies:link_to_ui_visible_condition(script.a4)
script.a4HardlockFov:link_to_ui_visible_condition(script.a4)

script.a4SteerFov:link_to_ui_visible_condition(script.a4Steer)


-- ═══════════════════════════════════════════════════════════════
--  Вспомогательные методы
-- ═══════════════════════════════════════════════════════════════
local function is_menu_open()
    return Menu.Opened and Menu.Opened() or false
end

local function get_now()
    local now = nil
    pcall_cached(function()
        now = global_vars.curtime()
    end)
    return type(now) == "number" and now or os.clock()
end

local function debug_log(message)
    if not script.debug() then
        return
    end
    print(string.format("%s %s", DEBUG_PREFIX, message))
end

local function meters_to_units(value)
    return (value or 0) * UNIT_METER
end

local function distance_2d(a, b)
    if not a or not b then
        return math.huge
    end
    if a.Distance2D then
        return a:Distance2D(b)
    end
    return a:Distance(b)
end

local function safe_has_state(ent, state)
    if not ent or not state then
        return false
    end
    local ok, result = pcall_cached(function()
        return ent:has_modifier_state(state)
    end)
    return ok and result or false
end

local function has_any_state(ent, states)
    for _, state in ipairs_cached(states) do
        if safe_has_state(ent, state) then
            return true
        end
    end
    return false
end

local function get_target_name(target)
    if not target then
        return "unknown"
    end
    local name = ""
    pcall_cached(function()
        name = target:get_name()
    end)
    if type(name) == "string" and name ~= "" then
        return name
    end
    pcall_cached(function()
        name = target:get_vdata_class_name()
    end)
    if type(name) == "string" and name ~= "" then
        return name
    end
    local idx = -1
    pcall_cached(function()
        idx = target:get_index()
    end)
    return "target#" .. tostring(idx)
end

local function clear_target_lock()
    celeste.target = nil
    celeste.target_lock_expires = 0
end

local function can_issue_action()
    return (get_now() - celeste.last_cast_time) >= (script.castDebounce() / 1000)
end

local function can_repress_ability(cast_key, delay)
    if not cast_key then
        return true
    end
    local last_time = celeste.ability_cast_times[cast_key] or 0
    return (get_now() - last_time) >= (delay or 0)
end

local function mark_action(action_name, target, cast_key)
    local now = get_now()
    celeste.last_cast_time = now
    if cast_key then
        celeste.ability_cast_times[cast_key] = now
    end
    debug_log(string.format("Action: %s -> %s", action_name, get_target_name(target)))
end

local function is_playing_celeste(me)
    if not me or not me.valid or not me:valid() then
        return false
    end
    local hero_comp = me.m_CCitadelHeroComponent
    local spawned_hero = hero_comp and hero_comp.m_spawnedHero or nil
    local hero_id = spawned_hero and spawned_hero.m_nHeroID and spawned_hero.m_nHeroID.m_Value or nil
    return hero_id == HERO_ID
end

local function get_eye_pos(me)
    if not me or not me.valid or not me:valid() then
        return nil
    end
    return me:get_origin() + Vector(0, 0, DEFAULT_EYE_HEIGHT)
end

local function get_camera_context(me, cmd)
    local cam_pos = nil
    local cam_ang = nil

    pcall_cached(function()
        cam_pos = utils.get_camera_pos()
    end)
    if not cam_pos then
        cam_pos = get_eye_pos(me)
    end

    pcall_cached(function()
        cam_ang = utils.get_camera_angles()
    end)
    if not cam_ang and cmd then
        cam_ang = cmd.viewangles
    end

    return cam_pos, cam_ang
end

local function is_target_untargetable(ent)
    return has_any_state(ent, {
        MODSTATE.INVULNERABLE,
        MODSTATE.TECH_INVULNERABLE,
        MODSTATE.TECH_DAMAGE_INVULNERABLE,
        MODSTATE.STATUS_IMMUNE,
        MODSTATE.OUT_OF_GAME,
        MODSTATE.BULLET_INVULNERABLE,
        MODSTATE.UNIT_STATUS_HIDDEN,
        MODSTATE.NO_INCOMING_DAMAGE,
    })
end

local function is_target_static(ent)
    return has_any_state(ent, {
        MODSTATE.STUNNED,
        MODSTATE.IMMOBILIZED,
    })
end

local function is_self_disabled(me)
    return has_any_state(me, {
        MODSTATE.BUSY_WITH_ACTION,
        MODSTATE.STUNNED,
        MODSTATE.SILENCED,
        MODSTATE.COMMAND_RESTRICTED,
    })
end

local function is_valid_enemy(me, ent)
    if not me or not ent or not ent.valid or not ent:valid() then
        return false
    end
    if ent == me or not ent:is_alive() or ent:is_dormant() then
        return false
    end
    if me.m_iTeamNum == ent.m_iTeamNum then
        return false
    end
    if is_target_untargetable(ent) then
        return false
    end
    return true
end

local function get_target_point(target)
    if not target or not target.valid or not target:valid() then
        return nil
    end

    for _, bone_name in ipairs_cached(BONE_PRIORITY) do
        local bone = nil
        pcall_cached(function()
            bone = target:get_bone_pos(bone_name)
        end)
        if bone and not bone:IsInvalid() and bone:LengthSqr() > 0 then
            return bone
        end
    end

    return target:get_origin() + Vector(0, 0, DEFAULT_TARGET_POINT_Z)
end

local function is_visible_point(me, start_pos, end_pos)
    if not me or not start_pos or not end_pos then
        return false
    end
    local tr = trace.line(start_pos, end_pos, 1, 0, 0, 0, 0, function(ent) return false end)
    return tr ~= nil and tr.fraction >= 0.98
end

local function is_target_visible(me, target, start_pos, target_point)
    local aim_from = start_pos or get_eye_pos(me)
    local aim_to = target_point or get_target_point(target)
    if HERO_LIB and HERO_LIB.no_obs_to_target then
        return HERO_LIB.no_obs_to_target(target, aim_from, me)
    end
    return trace.bullet(aim_from, aim_to, 1.0, target)
end

local function get_ability_state(ability)
    local status = -1
    local cooldown = math.huge
    local level = 0

    if not ability or not ability.valid or not ability:valid() then
        return status, cooldown, level
    end

    pcall_cached(function()
        status = ability:can_be_executed()
    end)
    pcall_cached(function()
        cooldown = ability:get_cooldown()
    end)
    pcall_cached(function()
        level = ability:get_level()
    end)

    return status, cooldown, level
end

local function is_ability_ready(ability)
    if not ability or not ability.valid or not ability:valid() then
        return false
    end
    if HERO_LIB and HERO_LIB.is_ability_ready then
        return HERO_LIB.is_ability_ready(ability)
    end
    local status, cooldown, level = get_ability_state(ability)
    if type(level) == "number" and level <= 0 then
        return false, status, cooldown, level
    end

    if status == STATUS.READY then
        return true, status, cooldown, level
    end

    if type(cooldown) == "number"
        and cooldown <= READY_EPSILON
        and status ~= STATUS.COOLDOWN
        and status ~= STATUS.PASSIVE then
        return true, status, cooldown, level
    end

    return false, status, cooldown, level
end

local function is_ability_busy(ability)
    local status, _, level = get_ability_state(ability)
    return type(level) == "number" and level > 0 and status == STATUS.BUSY
end

local function get_scaled_property(ability, names)
    if not ability or not ability.valid or not ability:valid() then
        return nil
    end

    if type(names) == "string" then
        names = { names }
    end

    for _, name in ipairs_cached(names or {}) do
        local value = nil
        pcall_cached(function()
            value = ability:get_scaled_property(name)
        end)
        if type(value) == "number" and value > 0 then
            return value
        end
    end

    return nil
end

local function get_effective_cast_range(ability, fallback)
    local range = nil
    pcall_cached(function()
        range = ability:get_cast_range()
    end)
    if type(range) == "number" and range > 0 then
        return range
    end

    return get_scaled_property(ability, {
        "m_flCastRange",
        "m_flAbilityCastRange",
        "CastRange",
        "m_flRange",
    }) or fallback
end

local function get_effective_aoe_radius(ability, fallback)
    local radius = nil
    pcall_cached(function()
        radius = ability:get_aoe_radius()
    end)
    if type(radius) == "number" and radius > 0 then
        return radius
    end

    return get_scaled_property(ability, {
        "m_flRadius",
        "Radius",
    }) or fallback
end

local function get_projectile_speed(ability, fallback)
    return get_scaled_property(ability, {
        "m_flProjectileSpeed",
        "m_flSpeed",
        "m_flBulletSpeed",
    }) or fallback
end

local function get_prediction_extra_time()
    local extra = script.predictBias() / 1000
    if not script.predictLatency() then
        return math_min(extra, script.predictMaxTime())
    end

    local latency = 0
    pcall_cached(function()
        latency = net_channel.latency()
    end)

    if type(latency) == "number" and latency > 0 then
        extra = extra + math_max(0, latency - 0.015)
    end

    return math_min(extra, script.predictMaxTime())
end

local function clamp_predict_time(value)
    return math_max(0, math_min(value or 0, script.predictMaxTime()))
end

local function predict_linear_target(target, base_pos, travel_time, keep_ground)
    if not target or not base_pos then
        return base_pos
    end

    if is_target_static(target) then
        return base_pos
    end

    local velocity = Vector(0, 0, 0)
    pcall_cached(function()
        velocity = target:get_velocity()
    end)

    local predict_time = clamp_predict_time((travel_time or 0) + get_prediction_extra_time())
    local predicted = base_pos + (velocity * predict_time)
    if keep_ground then
        predicted.z = base_pos.z
    end
    return predicted
end

local function predict_projectile_target(me, target, ability, fallback_speed)
    local src = nil
    pcall_cached(function()
        src = utils.get_camera_pos()
    end)
    if not src then
        src = get_eye_pos(me)
    end

    local base_pos = get_target_point(target)
    if not src or not base_pos then
        return base_pos
    end

    if is_target_static(target) then
        return base_pos
    end

    local speed = get_projectile_speed(ability, fallback_speed)
    local predicted = nil
    pcall_cached(function()
        predicted = utils.predict_bullet(src, base_pos, target:get_velocity(), speed)
    end)

    if predicted and not predicted:IsInvalid() then
        local extra = get_prediction_extra_time()
        if extra > 0 then
            local velocity = Vector(0, 0, 0)
            pcall_cached(function()
                velocity = target:get_velocity()
            end)
            predicted = predicted + (velocity * extra)
        end
        return predicted
    end

    local travel_time = (speed and speed > 0) and (distance_2d(src, base_pos) / speed) or 0
    return predict_linear_target(target, base_pos, travel_time, false)
end

local function get_target_score(me, target, cam_pos, cam_ang)
    local target_point = get_target_point(target)
    if not target_point then
        return nil
    end

    local max_distance = meters_to_units(script.targetRange())
    local distance = distance_2d(me:get_origin(), target:get_origin())
    if distance > max_distance then
        return nil
    end

    local fov = utils.get_fov(cam_ang, utils.calc_angle(cam_pos, target_point))
    if fov > script.targetFov() then
        return nil
    end

    if not is_target_visible(me, target, cam_pos, target_point) then
        return nil
    end

    local prio = script.targetPrio()
    if prio == 2 then -- HP%
        local max_hp = math_max(target:get_max_health() or 1, 1)
        local hp_pct = (target.m_iHealth / max_hp) * 100
        return hp_pct + (fov * 0.05)
    elseif prio == 3 then -- Distance
        return distance
    end

    return fov -- FOV
end

local function can_keep_target(me, target, cam_pos, cam_ang)
    if not is_valid_enemy(me, target) then
        return false
    end

    local target_point = get_target_point(target)
    if not target_point then
        return false
    end

    local max_distance = meters_to_units(script.targetRange() + TARGET_STICKY_RANGE_BUFFER_M)
    local distance = distance_2d(me:get_origin(), target:get_origin())
    if distance > max_distance then
        return false
    end

    local fov = utils.get_fov(cam_ang, utils.calc_angle(cam_pos, target_point))
    if fov > (script.targetFov() + TARGET_STICKY_FOV_BUFFER) then
        return false
    end

    return is_target_visible(me, target, cam_pos, target_point)
end

local function acquire_target(me, cmd)
    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang then
        return nil
    end

    local now = get_now()
    if script.targetLock()
        and celeste.target
        and now < celeste.target_lock_expires
        and can_keep_target(me, celeste.target, cam_pos, cam_ang) then
        celeste.target_lock_expires = now + (script.targetSticky() / 1000)
        return celeste.target
    end

    local best_target = nil
    local best_score = math.huge

    for _, enemy in ipairs_cached(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if is_valid_enemy(me, enemy) then
            local score = get_target_score(me, enemy, cam_pos, cam_ang)
            if score and score < best_score then
                best_score = score
                best_target = enemy
            end
        end
    end

    celeste.target = best_target
    celeste.target_lock_expires = best_target and (now + (script.targetSticky() / 1000)) or 0
    return best_target
end

local function count_enemies_in_radius(me, center, radius)
    local count = 0
    for _, enemy in ipairs_cached(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if is_valid_enemy(me, enemy) and distance_2d(center, enemy:get_origin()) <= radius then
            count = count + 1
        end
    end
    return count
end

local function count_predicted_enemies_in_radius(me, center, radius, travel_time)
    local count = 0
    for _, enemy in ipairs_cached(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if is_valid_enemy(me, enemy) then
            local predicted_pos = predict_linear_target(enemy, enemy:get_origin(), travel_time, false)
            if distance_2d(center, predicted_pos) <= radius then
                count = count + 1
            end
        end
    end
    return count
end

local function hardlock_to_pos(cmd, me, pos, max_fov)
    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang or not pos then
        return false, math.huge
    end

    local aim_angle = utils.calc_angle(cam_pos, pos)
    local fov = utils.get_fov(cam_ang, aim_angle)
    if max_fov and fov > max_fov then
        return false, fov
    end

    utils.set_camera_angles(aim_angle)
    cmd.viewangles = aim_angle
    return true, fov
end


-- ═══════════════════════════════════════════════════════════════
--  Логика Каста Способностей
-- ═══════════════════════════════════════════════════════════════
local function try_guard(cmd, me, a2)
    if not script.guard() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a2)
    if not ready then
        return false
    end

    local hp_pct = (me.m_iHealth / math_max(me:get_max_health() or 1, 1)) * 100
    if hp_pct > script.guardHp() then
        return false
    end

    if me:has_modifier(GUARD_BUFF_NAME) then
        return false
    end

    local nearby_enemies = count_enemies_in_radius(me, me:get_origin(), meters_to_units(script.guardRange()))
    if nearby_enemies < script.guardMinEnemies() then
        return false
    end

    cmd:add_buttonstate1(BIT.A2)
    mark_action("Prismatic Guard", me, "a2")
    return true
end

local function try_blast(cmd, me, target, a1)
    if not script.a1() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a1)
    if not ready then
        return false
    end

    local cam_pos = select(1, get_camera_context(me, cmd))
    local cast_pos = get_target_point(target)
    if not cam_pos or not cast_pos then
        return false
    end

    local cast_range = get_effective_cast_range(a1, 0)
    if cast_range > 0 and distance_2d(me:get_origin(), target:get_origin()) > cast_range then
        return false
    end

    if script.a1RequireVis() and not is_target_visible(me, target, cam_pos, cast_pos) then
        return false
    end

    if cmd:can_psilent_at_pos(cast_pos) then
        cmd:set_psilent_at_pos(cast_pos)
        cmd:add_buttonstate1(BIT.A1)
        mark_action("Radiant Blast", target, "a1")
        return true
    elseif script.a1AimFallback() then
        local aimed, fov = hardlock_to_pos(cmd, me, cast_pos, nil)
        if aimed then
            if fov <= 1.5 then
                cmd:add_buttonstate1(BIT.A1)
                mark_action("Radiant Blast (Aim Fallback)", target, "a1")
            end
            return true
        end
    end

    return false
end

local function try_daggers(cmd, me, target, a3)
    if not script.a3() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a3)
    if not ready then
        return false
    end

    if not can_repress_ability("a3", script.a3RepressDelay()) then
        return false
    end

    local base_pos = target:get_origin()
    local cast_pos = predict_linear_target(target, base_pos, 0.80, true)

    local cast_range = get_effective_cast_range(a3, 0)
    if cast_range > 0 and distance_2d(me:get_origin(), cast_pos) > cast_range then
        return false
    end

    local eye_pos = get_eye_pos(me)
    if script.a3RequireVis() and not is_visible_point(me, eye_pos, cast_pos) then
        return false
    end

    if cmd:can_psilent_at_pos(cast_pos) then
        cmd:set_psilent_at_pos(cast_pos)
        cmd:add_buttonstate1(BIT.A3)
        mark_action("Radiant Daggers", target, "a3")
        return true
    elseif script.a3AimFallback() then
        local aimed, fov = hardlock_to_pos(cmd, me, cast_pos, nil)
        if aimed then
            if fov <= 1.5 then
                cmd:add_buttonstate1(BIT.A3)
                mark_action("Radiant Daggers (Aim Fallback)", target, "a3")
            end
            return true
        end
    end

    return false
end

local function try_ult_steer(cmd, me, target, a4)
    if not script.a4() or not script.a4Steer() or not target then
        return false
    end

    if not is_ability_busy(a4) then
        return false
    end

    local steer_pos = predict_projectile_target(me, target, a4, DEFAULT_ULT_SPEED)
    if not steer_pos then
        return false
    end

    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang then
        return false
    end

    if not is_visible_point(me, cam_pos, steer_pos) then
        return false
    end

    local steer_angle = utils.calc_angle(cam_pos, steer_pos)
    local fov = utils.get_fov(cam_ang, steer_angle)
    if fov > script.a4SteerFov() then
        return false
    end

    utils.set_camera_angles(steer_angle)
    cmd.viewangles = steer_angle
    return true
end

local function try_ult_cast(cmd, me, target, a4)
    if not script.a4() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a4)
    if not ready then
        return false
    end

    local cast_pos = predict_projectile_target(me, target, a4, DEFAULT_ULT_SPEED)
    if not cast_pos then
        return false
    end

    local cast_range = get_effective_cast_range(a4, 0)
    if cast_range > 0 and distance_2d(me:get_origin(), cast_pos) > cast_range then
        return false
    end

    local aoe_radius = get_effective_aoe_radius(a4, DEFAULT_ULT_AOE)
    local speed = get_projectile_speed(a4, DEFAULT_ULT_SPEED)
    local travel_time = distance_2d(me:get_origin(), cast_pos) / speed
    local enemy_count = count_predicted_enemies_in_radius(me, cast_pos, aoe_radius, travel_time)
    if enemy_count < script.a4MinEnemies() then
        return false
    end

    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang then
        return false
    end

    if not is_visible_point(me, cam_pos, cast_pos) then
        return false
    end

    local aimed, fov = hardlock_to_pos(cmd, me, cast_pos, script.a4HardlockFov())
    if aimed then
        if fov <= 1.5 then
            cmd:add_buttonstate1(BIT.A4)
            mark_action("Shining Wonder (Hard Lock)", target, "a4")
        end
        return true
    end

    return false
end


-- ═══════════════════════════════════════════════════════════════
--  Обратные вызовы (Callbacks)
-- ═══════════════════════════════════════════════════════════════
local function on_createmove(cmd)
    if not script.enabled() or is_menu_open() then
        clear_target_lock()
        return
    end

    local me = entity_list.local_pawn()
    if not me or not me.valid or not me:valid() or not me:is_alive() then
        clear_target_lock()
        return
    end

    if not is_playing_celeste(me) then
        clear_target_lock()
        return
    end

    local a1 = me:get_ability_by_slot(SLOT.A1)
    local a2 = me:get_ability_by_slot(SLOT.A2)
    local a3 = me:get_ability_by_slot(SLOT.A3)
    local a4 = me:get_ability_by_slot(SLOT.A4)

    local combo_active = script.comboKey:down()
    local orig_button1 = cmd:get_orig_button_state1()
    local is_holding_a4 = (orig_button1 & BIT.A4) ~= 0

    local target = nil
    if combo_active or is_holding_a4 then
        target = acquire_target(me, cmd)
    else
        clear_target_lock()
    end

    if (combo_active or is_holding_a4) and target and try_ult_steer(cmd, me, target, a4) then
        return
    end

    if is_holding_a4 and target and is_ability_ready(a4) then
        local cast_pos = predict_projectile_target(me, target, a4, DEFAULT_ULT_SPEED)
        if cast_pos then
            hardlock_to_pos(cmd, me, cast_pos, script.a4HardlockFov())
        end
    end

    if is_self_disabled(me) then
        return
    end

    if try_guard(cmd, me, a2) then
        return
    end

    if not combo_active or not target then
        return
    end

    if try_ult_cast(cmd, me, target, a4) then
        return
    end

    if try_daggers(cmd, me, target, a3) then
        return
    end

    if try_blast(cmd, me, target, a1) then
        return
    end
end

local function on_remove_entity(ent)
    if not ent or not ent.valid or not ent:valid() then
        return
    end
    if celeste.target and ent:get_index() == celeste.target:get_index() then
        clear_target_lock()
    end
end


-- ═══════════════════════════════════════════════════════════════
--  Отрисовка 3D ESP Оверлеев (Drawings)
-- ═══════════════════════════════════════════════════════════════
local function draw3DCircle(center, radius, color, thickness, speed, reverse)
    local numSegments = 32
    local lastVisible = false
    local firstScreenX, firstScreenY = 0, 0
    local prevScreenX, prevScreenY = 0, 0

    local angle_offset = speed and (get_now() * speed) or 0
    if reverse then
        angle_offset = -angle_offset
    end

    for i = 0, numSegments do
        local angle = (i / numSegments) * math_pi * 2 + angle_offset
        vTempWorld.x = center.x + math_cos(angle) * radius
        vTempWorld.y = center.y + math_sin(angle) * radius
        vTempWorld.z = center.z

        local screenPos, isVisible = Render.WorldToScreen(vTempWorld)
        if isVisible then
            local sx, sy = screenPos.x, screenPos.y
            if i == 0 then
                firstScreenX, firstScreenY = sx, sy
            else
                if lastVisible then
                    vTempVec1.x = prevScreenX
                    vTempVec1.y = prevScreenY
                    vTempVec2.x = sx
                    vTempVec2.y = sy
                    Render.Line(vTempVec1, vTempVec2, color, thickness or 1.5)
                end
            end
            prevScreenX, prevScreenY = sx, sy
            lastVisible = true
        else
            lastVisible = false
        end
    end

    if lastVisible and firstScreenX ~= 0 then
        vTempVec1.x = prevScreenX
        vTempVec1.y = prevScreenY
        vTempVec2.x = firstScreenX
        vTempVec2.y = firstScreenY
        Render.Line(vTempVec1, vTempVec2, color, thickness or 1.5)
    end
end

local function on_draw()
    if not script.enabled() or is_menu_open() then
        return
    end

    local me = entity_list.local_pawn()
    if not me or not me.valid or not me:valid() or not me:is_alive() then
        return
    end

    if not is_playing_celeste(me) then
        return
    end

    local screenSize = Render.ScreenSize()
    vScreen.x = screenSize.x
    vScreen.y = screenSize.y

    local themeColor = script.themeColor() or Color(0, 180, 255, 220)

    -- 1. Отрисовка FOV Круга
    if script.drawFov() then
        vTempVec1.x = vScreen.x / 2
        vTempVec1.y = vScreen.y / 2
        -- Примерная конвертация градусов FOV в экранные пиксели
        local fovRadius = (script.targetFov() / 90) * (vScreen.x / 2)
        Render.Circle(vTempVec1, fovRadius, themeColor:AlphaModulate(20), 1.0, 0, 1.0, false, 64)
    end

    local target = celeste.target
    if not target or not target.valid or not target:valid() or not target:is_alive() then
        return
    end

    -- 2. Отрисовка Target ESP (3D Вращающиеся кольца)
    if script.drawTarget() then
        -- Внешнее кольцо
        draw3DCircle(target:get_origin(), 45, themeColor, 2.0, 1.5, false)
        -- Внутреннее кольцо, вращающееся в другую сторону
        draw3DCircle(target:get_origin(), 50, themeColor:AlphaModulate(80), 1.0, 1.0, true)
        -- Пульсирующий маркер головы
        local headPos = target:get_bone_pos("head")
        if headPos and not headPos:IsInvalid() then
            local pulse = 18 + math_sin(get_now() * 6.0) * 4.0
            draw3DCircle(headPos, pulse, themeColor, 1.5, 0.5, false)
        end
    end

    -- 3. Отрисовка HUD Информации рядом с целью (Premium Glass Card)
    if script.drawHud() and hudFont then
        local textPos, isVisible = Render.WorldToScreen(target:get_origin() + Vector(0, 0, 115))
        if isVisible then
            local max_hp = math_max(target:get_max_health() or 1, 1)
            local hp_pct = math_floor((target.m_iHealth / max_hp) * 100)
            local dist_m = math_floor(distance_2d(me:get_origin(), target:get_origin()) / UNIT_METER)

            local targetName = target:get_vdata_class_name() or "Enemy"
            targetName = targetName:gsub("hero_", ""):gsub("C_CitadelPlayerPawn", "Player")
            targetName = targetName:sub(1, 1):upper() .. targetName:sub(2)

            -- Вычисляем динамический масштаб в зависимости от дистанции до цели
            local scale = 1.0
            if dist_m > 15 then
                scale = 1.0 - math_min(0.35, (dist_m - 15) / 45 * 0.35)
            end

            local boxWidth = math_floor(190 * scale)
            local boxHeight = math_floor(65 * scale)
            local boxX = textPos.x - boxWidth / 2
            local boxY = textPos.y - boxHeight / 2

            vTempVec1.x = boxX
            vTempVec1.y = boxY
            vTempVec2.x = boxX + boxWidth
            vTempVec2.y = boxY + boxHeight

            -- Премиальные эффекты: тень и размытие заднего фона (Glassmorphism)
            pcall_cached(function()
                Render.Shadow(vTempVec1, vTempVec2, Color(0, 0, 0, 150), math_floor(10 * scale), 6)
            end)
            pcall_cached(function()
                Render.Blur(vTempVec1, vTempVec2, 3.0, 1.0, 6)
            end)

            -- Полупрозрачный стеклянный фон
            Render.FilledRect(vTempVec1, vTempVec2, Color(15, 23, 42, 140), 6)
            Render.Rect(vTempVec1, vTempVec2, themeColor:AlphaModulate(120), 6, 0, 1.5)

            local pad = math_floor(12 * scale)
            local fontTitleSize = math_max(8, math_floor(12 * scale))
            local fontRightSize = math_max(8, math_floor(11 * scale))
            local fontStatusSize = math_max(7, math_floor(10 * scale))

            -- Имя героя
            vTempVec1.x = boxX + pad
            vTempVec1.y = boxY + math_floor(8 * scale)
            Render.Text(hudFont, fontTitleSize, targetName, vTempVec1, Color(255, 255, 255, 240))

            -- Текст здоровья и дистанции
            local rightText = string.format("%d%% | %dm", hp_pct, dist_m)
            local rightTextSize = Render.TextSize(hudFont, fontRightSize, rightText)
            vTempVec1.x = boxX + boxWidth - rightTextSize.x - pad
            vTempVec1.y = boxY + math_floor(9 * scale)
            Render.Text(hudFont, fontRightSize, rightText, vTempVec1, Color(200, 200, 200, 220))

            -- Подложка полосы здоровья
            local barY = boxY + math_floor(28 * scale)
            local barH = math_max(3, math_floor(5 * scale))
            vTempVec1.x = boxX + pad
            vTempVec1.y = barY
            vTempVec2.x = boxX + boxWidth - pad
            vTempVec2.y = barY + barH
            Render.FilledRect(vTempVec1, vTempVec2, Color(30, 41, 59, 200), 2)

            -- Заполнение здоровья с цветовой индикацией
            local fillWidth = math_floor((boxWidth - pad * 2) * (hp_pct / 100))
            if fillWidth > 0 then
                vTempVec2.x = vTempVec1.x + fillWidth
                local hpColor = themeColor
                if hp_pct < 30 then
                    hpColor = Color(255, 75, 75, 220)
                elseif hp_pct < 60 then
                    hpColor = Color(255, 180, 50, 220)
                end
                Render.FilledRect(vTempVec1, vTempVec2, hpColor, 2)
            end

            -- Статусы контроля
            local statusText = ""
            local statusColor = Color(255, 255, 255, 200)
            if is_target_static(target) then
                statusText = "STUNNED"
                statusColor = Color(255, 75, 75, 255)
            elseif safe_has_state(target, MODSTATE.SILENCED) then
                statusText = "SILENCED"
                statusColor = Color(255, 180, 50, 255)
            elseif target.m_iTeamNum == me.m_iTeamNum then
                statusText = "ALLY"
                statusColor = Color(75, 255, 75, 255)
            else
                statusText = "TARGETING"
                statusColor = themeColor
            end

            -- Рисуем пульсирующий маркер статуса и сам текст с увеличенным отступом
            vTempVec1.x = boxX + pad
            vTempVec1.y = boxY + math_floor(42 * scale)
            local dotChar = "\u{2022} "
            local pulseAlpha = math_floor(120 + math_abs(math_sin(get_now() * 5.0)) * 135)
            Render.Text(hudFont, fontStatusSize, dotChar, vTempVec1, statusColor:AlphaModulate(pulseAlpha))

            local dotSize = Render.TextSize(hudFont, fontStatusSize, dotChar)
            vTempVec1.x = vTempVec1.x + dotSize.x
            Render.Text(hudFont, fontStatusSize, statusText, vTempVec1, Color(220, 220, 220, 240))
        end
    end

    -- 4. Отрисовка Prediction Ground Circle
    if script.drawPred() then
        local combo_active = script.comboKey:down()
        if combo_active then
            local a3 = me:get_ability_by_slot(SLOT.A3)
            local a4 = me:get_ability_by_slot(SLOT.A4)

            local has_a3 = a3 and is_ability_ready(a3)
            local has_a4 = a4 and is_ability_ready(a4)

            if has_a4 then
                vPredictWorld = predict_projectile_target(me, target, a4, DEFAULT_ULT_SPEED)
                local pulse_alpha = 100 + math.floor(math_sin(get_now() * 8.0) * 40.0)
                draw3DCircle(vPredictWorld, DEFAULT_ULT_AOE, themeColor:AlphaModulate(pulse_alpha), 2.0, 1.0, false)
                draw3DCircle(vPredictWorld, 20, themeColor, 1.5, 2.0, true)
            elseif has_a3 then
                vPredictWorld = predict_linear_target(target, target:get_origin(), 0.80, true)
                draw3DCircle(vPredictWorld, 80, themeColor:AlphaModulate(120), 2.0, 1.0, false)
                draw3DCircle(vPredictWorld, 15, themeColor, 1.5, 2.0, true)
            end
        end
    end
end

local function OnScriptsLoaded()
    local antialias = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 16

    -- Определяем список возможных путей к шрифту MuseoSansEx 500.ttf
    local font_paths = {
        "C:\\Umbrella\\fonts\\MuseoSansEx 500.ttf",
        "D:\\Umbrella\\fonts\\MuseoSansEx 500.ttf",
        "E:\\Umbrella\\fonts\\MuseoSansEx 500.ttf",
        "fonts\\MuseoSansEx 500.ttf",
    }

    -- Динамически определяем путь относительно расположения этого скрипта
    local status, info = pcall(debug.getinfo, 1, "S")
    if status and info and info.source and info.source:sub(1, 1) == "@" then
        local filepath = info.source:sub(2):gsub("\\", "/")
        local base_dir = filepath:match("(.-)deadlock_scripts/") or filepath:match("(.-)[^/]+$")
        if base_dir and base_dir ~= "" then
            table.insert(font_paths, 1, (base_dir .. "fonts/MuseoSansEx 500.ttf"):gsub("/", "\\"))
        end
    end

    -- Пробуем загрузить шрифт из списка путей
    hudFont = nil
    for _, path in ipairs(font_paths) do
        hudFont = Render.LoadFont(path, antialias, 500)
        if hudFont then
            break
        end
    end

    -- Если не удалось загрузить кастомный шрифт, используем стандартные системные
    if not hudFont then
        hudFont = Render.LoadFont("Consolas", antialias, 700)
            or Render.LoadFont("Arial", antialias, 400)
    end

    print(string.format("%s v%s loaded.", DEBUG_PREFIX, VERSION))
end

callback.on_scripts_loaded:set(OnScriptsLoaded)
callback.on_createmove:set(on_createmove)
callback.on_remove_entity:set(on_remove_entity)
callback.on_draw:set(on_draw)

return script
