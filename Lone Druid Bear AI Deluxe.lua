---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
local ld = {}

-- =========================================================
-- RENDER
-- =========================================================
local font_big   = Render.LoadFont("Verdana", 14, 700)
local font_small = Render.LoadFont("Verdana", 12, 400)

-- =========================================================
-- ORDERS
-- =========================================================
local O_ATTACK = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
local O_MOVE   = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
local O_FOLLOW = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
local O_GIVE   = Enum.UnitOrder.DOTA_UNIT_ORDER_GIVE_ITEM
local O_CAST_T = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local O_CAST_N = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
local O_ATK_MV = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
local ISSUER   = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

-- =========================================================
-- UI
-- =========================================================
local tab  = Menu.Create("Heroes", "Hero List", "Lone Druid")
local root = tab:Create("Bear AI Deluxe")

local ui = {}

-- Language toggle
local g_lang = root:Create("Language / Язык")
ui.lang = g_lang:Switch("English / Английский [F7 to reload]", false)
ui.lang:Icon("\u{f0ac}")

local function L(ru, en)
    return ui.lang:Get() and en or ru
end

-- Groups
local g_main  = root:Create(L("Основное",              "Main"))
local g_modes = root:Create(L("Режимы",                "Modes"))
local g_farm  = root:Create(L("Фарм леса",             "Forest Farm"))
local g_push  = root:Create(L("Пуш лайна",             "Lane Push"))
local g_stack = root:Create(L("Стаки",                  "Stacking"))
local g_aghs  = root:Create(L("Логика с Аганимом",      "Aghanim Logic"))
local g_def   = root:Create(L("Выживание Медведя",      "Bear Survival"))
local g_item  = root:Create(L("Предметы",               "Items"))
local g_vis   = root:Create(L("Визуал",                 "Visuals"))
local g_keys  = root:Create(L("Горячие клавиши",        "Hotkeys"))

-- Main
ui.on        = g_main:Switch(L("Включить Bear AI",                      "Enable Bear AI"), false)
ui.on:Icon("\u{f00c}")
ui.follow    = g_main:Switch(L("Следовать за героем",                   "Follow Hero"), true)
ui.follow:Icon("\u{f238}")
ui.only_aghs = g_main:Switch(L("Farm/Push/Stack только с Аганимом",     "Farm/Push/Stack Aghs only"), false)
ui.only_aghs:Icon("\u{f005}")

-- Mirror Attack
local g_mirror = root:Create(L("Зеркальная Атака", "Mirror Attack"))
ui.mirror_on = g_mirror:Switch(L("Медведь атакует цель героя", "Bear mirrors hero attack target"), true)
ui.mirror_on:Icon("\u{f0e8}")
ui.mirror_only_follow = g_mirror:Switch(L("Только в режиме Follow",     "Only in Follow mode"), false)
ui.mirror_only_follow:Icon("\u{f238}")
ui.mirror_r = g_mirror:Slider(
    L("Макс. дистанция до цели", "Max distance to target"),
    200, 2000, 1200,
    function(v) return v .. L(" ед.", " u.") end
)
ui.mirror_r:Icon("\u{f140}")

-- Modes
ui.farm = g_modes:Switch(L("Режим: Фарм леса",  "Mode: Forest Farm"), false)
ui.farm:Image("panorama/images/spellicons/lone_druid_spirit_bear_png.vtex_c")
ui.push = g_modes:Switch(L("Режим: Пуш лайна",  "Mode: Lane Push"),   false)
ui.push:Image("panorama/images/spellicons/lone_druid_spirit_bear_entangle_png.vtex_c")

-- Farm
ui.farm_radius = g_farm:Slider(
    L("Радиус поиска нейтралов", "Neutral Search Radius"),
    400, 1200, 800,
    function(v) return v .. L(" ед.", " u.") end
)
ui.farm_radius:Icon("\u{f140}")
ui.farm_ancients = g_farm:Switch(L("Фармить древних крипов", "Farm Ancient Camps"), true)
ui.farm_ancients:Icon("\u{f1b2}")
ui.farm_lasthit = g_farm:Switch(L("Умный ласт-хит нейтралов", "Smart Neutral Last-Hit"), true)
ui.farm_lasthit:Icon("\u{f145}")

-- Push
ui.tower_lvl = g_push:Slider(
    L("Атаковать башню от уровня", "Attack Tower from Level"),
    0, 25, 0,
    function(v)
        return v == 0
            and L("Никогда", "Never")
            or  (L("Уровень ", "Level ") .. v .. "+")
    end
)
ui.tower_lvl:Icon("\u{f132}")
ui.push_lasthit = g_push:Switch(L("Умный ласт-хит крипов", "Smart Creep Last-Hit"), true)
ui.push_lasthit:Icon("\u{f145}")
ui.push_priorities = g_push:Switch(L("Приоритет дальников/знаменосцев", "Prioritize Ranged/Flagbearers"), true)
ui.push_priorities:Icon("\u{f0f3}")

-- Stacks
ui.stack_enable    = g_stack:Switch(L("Включить стаки",       "Enable Stacking"), true)
ui.stack_enable:Icon("\u{f0c9}")
ui.stack_farm      = g_stack:Switch(L("Стаки при фарме",      "Stack during Farm"), true)
ui.stack_farm:Icon("\u{f66b}")
ui.stack_push      = g_stack:Switch(L("Стаки при пуше",       "Stack during Push"), true)
ui.stack_push:Icon("\u{f0e7}")
ui.stack_aggro_sec = g_stack:Slider(
    L("Секунда агра (база)", "Aggro Second (base)"),
    50, 57, 53,
    function(v) return v .. L(" сек", " sec") end
)
ui.stack_aggro_sec:Icon("\u{f017}")
ui.stack_range = g_stack:Slider(
    L("Радиус поиска крипов", "Creep Search Radius"),
    300, 1200, 800,
    function(v) return v .. L(" ед.", " u.") end
)
ui.stack_range:Icon("\u{f140}")

-- Aghanim
ui.aghs_on  = g_aghs:Switch(L("Включить логику Аганима",  "Enable Aghanim Logic"), true)
ui.aghs_on:Image("panorama/images/items/ultimate_scepter_png.vtex_c")
ui.entangle = g_aghs:Switch(L("Авто-путы на врага",        "Auto Entangle"),        true)
ui.entangle:Image("panorama/images/spellicons/lone_druid_spirit_bear_entangle_png.vtex_c")
ui.ent_creeps = g_aghs:Switch(L("Путы на крипов (Push)", "Entangle Creeps (Push)"), false)
ui.ent_creeps:Icon("\u{f188}")
ui.ent_r    = g_aghs:Slider(
    L("Радиус пут", "Entangle Radius"),
    100, 700, 400,
    function(v) return v .. L(" ед.", " u.") end
)
ui.ent_r:Icon("\u{f140}")

-- Bear survival
ui.def_enable = g_def:Switch(L("Инстинкт самосохранения",    "Self-Preservation"),   true)
ui.def_enable:Image("panorama/images/spellicons/lone_druid_spirit_bear_return_png.vtex_c")
ui.def_hp_hero = g_def:Slider(
    L("Отступать к герою при HP <", "Retreat to Hero at HP <"), 
    20, 90, 50, function(v) return v .. "%" end
)
ui.def_hp_hero:Icon("\u{f21e}")
ui.def_hp_base = g_def:Slider(
    L("На фонтан при HP <", "To Base at HP <"), 
    5, 40, 20, function(v) return v .. "%" end
)
ui.def_hp_base:Icon("\u{f0f9}")
ui.def_hp_resume = g_def:Slider(
    L("Снова фармить при HP >", "Resume Farm at HP >"), 
    50, 100, 95, function(v) return v .. "%" end
)
ui.def_hp_resume:Icon("\u{f04e}")
ui.def_roar   = g_def:Switch(L("Авто-Savage Roar",            "Auto Savage Roar"),    true)
ui.def_roar:Image("panorama/images/spellicons/lone_druid_savage_roar_png.vtex_c")
ui.def_phase  = g_def:Switch(L("Авто-Phase Boots",            "Auto Phase Boots"),    true)
ui.def_phase:Image("panorama/images/items/phase_boots_png.vtex_c")
ui.def_gank_r = g_def:Slider(
    L("Радиус опасного героя", "Danger Hero Radius"),
    350, 1000, 600,
    function(v) return v .. L(" ед.", " u.") end
)
ui.def_gank_r:Icon("\u{f06d}")
ui.def_alone  = g_def:Slider(
    L("Медведь 'один' дальше", "Bear 'alone' beyond"),
    800, 2500, 1500,
    function(v) return v .. L(" ед.", " u.") end
)
ui.def_alone:Icon("\u{f124}")
ui.def_alert  = g_def:Switch(L("Показывать DEFENSE alert",    "Show DEFENSE Alert"),  true)
ui.def_alert:Icon("\u{f0f3}")
ui.def_roar_allies = g_def:Switch(L("Спасать союзников Рыком", "Save Allies with Savage Roar"), true)
ui.def_roar_allies:Icon("\u{f0c0}")
ui.def_invis_safety = g_def:Switch(L("Не палить инвизного героя", "Don't Reveal Invis Hero"), true)
ui.def_invis_safety:Icon("\u{f070}")

-- Items
ui.transfer = g_item:Switch(L("Авто-передача предметов медведю", "Auto Item Transfer to Bear"), true)
ui.transfer:Image("panorama/images/items/bag_of_gold_png.vtex_c")
ui.auto_items_farm = g_item:Switch(L("Авто-предметы при фарме", "Auto Items during Farm"), true)
ui.auto_items_farm:Icon("\u{f0c9}")
ui.auto_items_combat = g_item:Switch(L("Авто-предметы в бою", "Auto Items in Combat"), true)
ui.auto_items_combat:Icon("\u{f0e7}")

-- Visuals
ui.show_panel   = g_vis:Switch(L("Показывать панель медведя",       "Show Bear Panel"),       true)
ui.show_panel:Icon("\u{f0e5}")
ui.show_warning = g_vis:Switch(L("Warning без Аганима",             "No-Aghs Warning"),       true)
ui.show_warning:Icon("\u{f071}")
ui.drag_mode    = g_vis:Switch(L("Режим перемещения панелей",       "Panel Drag Mode"),       false)
ui.drag_mode:Icon("\u{f047}")

ui.panel_x = g_vis:Slider(L("Панель X", "Panel X"), 0, 1900, 760)
ui.panel_x:Icon("\u{f07e}")
ui.panel_y = g_vis:Slider(L("Панель Y", "Panel Y"), 0, 1000, 150)
ui.panel_y:Icon("\u{f07d}")
ui.aghs_x  = g_vis:Slider("Warning X", 0, 1900, 760)
ui.aghs_x:Icon("\u{f07e}")
ui.aghs_y  = g_vis:Slider("Warning Y", 0, 1000, 70)
ui.aghs_y:Icon("\u{f07d}")

-- Hotkeys
ui.k_toggle = g_keys:Bind(L("Вкл / Выкл AI",       "Toggle AI"),    Enum.ButtonCode.KEY_F7)
ui.k_toggle:Icon("\u{f011}")
ui.k_push   = g_keys:Bind(L("Переключить: Push",    "Toggle: Push"), Enum.ButtonCode.KEY_F5)
ui.k_push:Icon("\u{f0e7}")
ui.k_farm   = g_keys:Bind(L("Переключить: Farm",    "Toggle: Farm"), Enum.ButtonCode.KEY_F6)
ui.k_farm:Icon("\u{f66b}")

-- Humanizer
local hum_tab = tab:Create(L("Хуманайзер", "Humanizer"))
local g_hum   = hum_tab:Create(L("Настройки", "Settings"))

ui.hum_on = g_hum:Switch(L("Включить хуманайзер", "Enable Humanizer"), true)
ui.hum_on:Icon("\u{f007}")
ui.hum_delay = g_hum:Slider(
    L("Задержка тика", "Tick Delay"),
    0, 200, 80,
    function(v) return "± " .. v .. L(" мс", " ms") end
)
ui.hum_delay:Icon("\u{f017}")
ui.hum_atk_delay = g_hum:Slider(
    L("Мин. интервал атаки", "Min Attack Interval"),
    200, 2000, 800,
    function(v) return v .. L(" мс", " ms") end
)
ui.hum_atk_delay:Icon("\u{f017}")
ui.hum_mov_delay = g_hum:Slider(
    L("Мин. интервал move", "Min Move Interval"),
    500, 5000, 2000,
    function(v) return v .. L(" мс", " ms") end
)
ui.hum_mov_delay:Icon("\u{f017}")
ui.hum_jitter = g_hum:Slider(
    L("Разброс назначения", "Destination Jitter"),
    0, 200, 12,
    function(v)
        return v == 0
            and L("Выкл", "Off")
            or  ("± " .. v .. L(" ед.", " u."))
    end
)
ui.hum_jitter:Icon("\u{f074}")

-- Callbacks
ui.push:SetCallback(function()
    if ui.push:Get() then ui.farm:Set(false) end
end)
ui.farm:SetCallback(function()
    if ui.farm:Get() then ui.push:Set(false) end
end)

-- =========================================================
-- CONST
-- =========================================================
local TICK      = 0.25
local TR_DLY    = 1.0
local FOL_START = 350
local FOL_STOP  = 150
local ATK_R     = 800
local WALK_R    = 150
local RESP      = 60.0
local IDLE_T    = 8.0
local AFTER_T   = 2.0
local MOV_RPT   = 1.0
local GIVE_D    = 300
local ROAR_R    = 380

local BEARS = {["npc_dota_lone_druid_bear1"] = true,["npc_dota_lone_druid_bear2"] = true,
    ["npc_dota_lone_druid_bear3"] = true,["npc_dota_lone_druid_bear4"] = true,
}

local PROT = {["item_boots"] = true, ["item_phase_boots"] = true, ["item_power_treads"] = true, 
    ["item_arcane_boots"] = true, ["item_travel_boots"] = true, ["item_travel_boots_2"] = true,["item_aghanims_blessing"] = true, ["item_shard"] = true,["item_tpscroll"] = true, 
    ["item_ward_observer"] = true, ["item_ward_sentry"] = true,["item_smoke_of_deceit"] = true,
}

local CAMPS = {
    {id=1,  p=Vector(-742,   4325, 134)}, {id=2,  p=Vector(2943,   -796, 256)},
    {id=3,  p=Vector(4082,  -5526, 128)}, {id=4,  p=Vector(8255,   -734, 256)},
    {id=5,  p=Vector(-4806,  4534, 128)}, {id=6,  p=Vector(4284,  -4110, 128)},
    {id=7,  p=Vector(-2121, -3921, 128)}, {id=8,  p=Vector(262,   -4751, 136)},
    {id=9,  p=Vector(-4509,   361, 256)}, {id=10, p=Vector(4072,   -421, 256)},
    {id=11, p=Vector(-1274, -4908, 128)}, {id=12, p=Vector(1515,   8209, 128)},
    {id=13, p=Vector(455,    3965, 134)}, {id=14, p=Vector(-4144,   322, 256)},
    {id=15, p=Vector(316,   -8138, 134)}, {id=16, p=Vector(-2529, -7737, 134)},
    {id=17, p=Vector(-479,   7639, 134)}, {id=18, p=Vector(-4743,  7534,   0)},
    {id=19, p=Vector(1348,   3263, 128)}, {id=20, p=Vector(7969,   1047, 256)},
    {id=21, p=Vector(-7735,  -183, 256)}, {id=22, p=Vector(-3962,  7564,   0)},
    {id=23, p=Vector(-2589,  4502, 256)}, {id=24, p=Vector(3522,  -8186,   8)},
    {id=25, p=Vector(1501,  -4208, 256)}, {id=26, p=Vector(-4338,  4903, 128)},
    {id=27, p=Vector(-7757, -1219, 256)}, {id=28, p=Vector(4781,  -7812,   8)},
}

local STACK_CAMPS = {
    {id=1,  camp=Vector(-742,   4325, 134), pull=Vector(-682,  3881, 236)},
    {id=2,  camp=Vector(2943,   -796, 256), pull=Vector(2817,  -53,  256)},
    {id=3,  camp=Vector(4082,  -5526, 128), pull=Vector(4181, -6368, 128)},
    {id=5,  camp=Vector(-4806,  4534, 128), pull=Vector(-4884, 5071, 128)},
    {id=6,  camp=Vector(4284,  -4110, 128), pull=Vector(3622, -4505, 128)},
    {id=7,  camp=Vector(-2121, -3921, 128), pull=Vector(-1564, -4531, 128)},
    {id=8,  camp=Vector(262,   -4751, 136), pull=Vector(333,  -4101, 254)},
    {id=9,  camp=Vector(-4509,   361, 256), pull=Vector(-5031, 1121, 128)},
    {id=10, camp=Vector(4072,   -421, 256), pull=Vector(4276, -1359, 128)},
    {id=11, camp=Vector(-1274, -4908, 128), pull=Vector(-812, -5282, 128)},
    {id=12, camp=Vector(1515,   8209, 128), pull=Vector(792,   8152, 128)},
    {id=13, camp=Vector(455,    3965, 134), pull=Vector(-78,   3932, 136)},
    {id=14, camp=Vector(-4144,   322, 256), pull=Vector(-5031, 1121, 128)},
    {id=17, camp=Vector(-479,   7639, 134), pull=Vector(-551,  6961, 128)},
    {id=19, camp=Vector(1348,   3263, 128), pull=Vector(1683,  3710, 128)},
    {id=23, camp=Vector(-2589,  4502, 256), pull=Vector(-2651, 5138, 256)},
    {id=25, camp=Vector(1501,  -4208, 256), pull=Vector(1094, -5103, 136)},
    {id=26, camp=Vector(-4338,  4903, 128), pull=Vector(-5198, 4877, 128)},
}

-- =========================================================
-- STATE
-- =========================================================
local hero, bear, player = nil, nil, nil
local our_team, enemy_team = nil, nil
local prev_items = {}
local last_tick = -999
local last_tr   = -999
local npc_cache     = nil
local neutral_cache = nil

local hum_now               = 0
local hum_next_tick         = 0
local hum_last_atk          = -999
local hum_last_tgt          = nil
local hum_last_mov          = -999
local hum_goal_pos          = nil
local hum_goal_jittered     = nil
local hum_goal_tag          = nil
local hum_goal_allow_jitter = nil
local hum_last_follow       = -999
local hum_last_fol_tgt      = nil
local invis_stop_issued     = false
local hum_follow_active     = false

local def = {
    panic_until   = 0,
    reason        = "SAFE",
    lock_until    = 0,
    heal_fountain = false,
}

local bind_prev = {toggle=false, push=false, farm=false}

local fc         = {}
local camp_id    = nil
local camp_pos   = nil
local had_mob    = false
local arrived_t  = -999
local cleared_t  = -999
local last_mov_t = -999
local last_seen_mob_pos = nil

local st = {
    active          = false,
    phase           = "idle",
    camp_id         = nil,
    camp_pos        = nil,
    pull_pos        = nil,
    strike_center   = nil,
    last_minute     = -1,
    aggro_time      = 0,
    hit_confirmed   = false,
    pull_issued     = false,
    approach_issued = false,
    last_move_time  = 0,
}

-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ ПЕРЕТАСКИВАНИЯ И КЛИКОВ
local drag_state = {
    main_active = false, main_dx = 0, main_dy = 0,
    aghs_active = false, aghs_dx = 0, aghs_dy = 0,
    was_down = false
}

local click_state = {
    was_down = false
}

local entangle_cast_this_tick = false

-- Mirror attack state: target captured from hero's attack orders
local mirror_tgt     = nil   -- the enemy the hero ordered an attack on
local mirror_tgt_set = -999  -- time it was set (for staleness check)

-- =========================================================
-- UTILS / MOUSE LOGIC (ИСПРАВЛЕННЫЙ БЛОК)
-- =========================================================
local function sc(fn, ...)
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local lmb_codes = {
    "KEY_LBUTTON", "MOUSE_LEFT", "KEY_MOUSE1", "MOUSE1",
    "BUTTON_LEFT", "KEY_MOUSE_LEFT", 107, 1, 0
}

local function is_lmb_down()
    if Input.IsKeyDown then
        local bc = Enum.ButtonCode or {}
        for _, code in ipairs(lmb_codes) do
            local c = type(code) == "string" and bc[code] or code
            if c then
                local ok, r = pcall(Input.IsKeyDown, c)
                if ok and r == true then return true end
            end
        end
    end
    if Input.IsButtonDown then
        for _, idx in ipairs({0, 1, 107}) do
            local ok, r = pcall(Input.IsButtonDown, idx)
            if ok and r == true then return true end
        end
    end
    if Render.IsMouseDown then
        for _, idx in ipairs({0, 1}) do
            local ok, r = pcall(Render.IsMouseDown, idx)
            if ok and r == true then return true end
        end
    end
    return false
end

local function get_cursor()
    if Render.GetCursorPos then
        local result = Render.GetCursorPos()
        if result and type(result) == "table" then
            local mx, my = result.x or result[1], result.y or result[2]
            if type(mx) == "number" and type(my) == "number" then
                return mx, my
            end
        end
    end
    if Input.GetCursorPosition then
        local mx, my = Input.GetCursorPosition()
        if type(mx) == "number" and type(my) == "number" then
            return mx, my
        end
    end
    if Input.GetCursorPos then
        local mx, my = Input.GetCursorPos()
        if type(mx) == "table" then
            my = mx.y or mx[2]
            mx = mx.x or mx[1]
        end
        if type(mx) == "number" and type(my) == "number" then
            return mx, my
        end
    end
    return nil, nil
end

local function is_mouse_in_rect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function alive(e)
    return e ~= nil and sc(Entity.IsAlive, e) == true
end

local function bear_hp_pct()
    if not bear or not alive(bear) then return 100 end
    local hp  = sc(Entity.GetHealth, bear) or 1
    local mhp = sc(Entity.GetMaxHealth, bear) or 1
    return (hp / math.max(mhp, 1)) * 100
end

local function gn(u)
    return sc(NPC.GetUnitName, u) or ""
end

local function gp(u)
    return sc(Entity.GetAbsOrigin, u)
end

local function d2(a, b)
    return (a - b):Length2D()
end

local function en(u)
    return enemy_team ~= nil and sc(Entity.GetTeamNum, u) == enemy_team
end

local function hlvl()
    return (hero and sc(Hero.GetLevel, hero)) or 0
end

local function game_min_sec()
    local now = GameRules.GetGameTime()
    local gt  = now - (sc(GameRules.GetGameStartTime) or 0)
    if gt < 0 then gt = 0 end
    local min = math.floor(gt / 60)
    local sec = gt % 60
    return now, min, sec
end

local function reset_farm_state()
    camp_id=nil; camp_pos=nil; had_mob=false
    arrived_t=-999; cleared_t=-999; last_mov_t=-999
    last_seen_mob_pos = nil
end

local function reset_stack_state()
    st.active          = false
    st.phase           = "idle"
    st.camp_id         = nil
    st.camp_pos        = nil
    st.pull_pos        = nil
    st.strike_center   = nil
    st.aggro_time      = 0
    st.hit_confirmed   = false
    st.pull_issued     = false
    st.approach_issued = false
    st.last_move_time  = 0
end

local function reset_hum_move()
    hum_goal_pos          = nil
    hum_goal_jittered     = nil
    hum_goal_tag          = nil
    hum_goal_allow_jitter = nil
end

local function reset_hum_state()
    hum_now           = 0
    hum_next_tick     = 0
    hum_last_atk      = -999
    hum_last_tgt      = nil
    hum_last_mov      = -999
    hum_last_follow   = -999
    hum_last_fol_tgt  = nil
    hum_follow_active = false
    reset_hum_move()
end

local function reset_def_state()
    def.panic_until   = 0
    def.reason        = "SAFE"
    def.lock_until    = 0
    def.heal_fountain = false
end

local function set_panic(reason, now, dur)
    def.reason = reason or "PANIC"
    def.panic_until = math.max(def.panic_until, (now or GameRules.GetGameTime()) + (dur or 2.5))
end

local function panic_active(now)
    return (now or GameRules.GetGameTime()) < def.panic_until
end

local function mode_name()
    if ui.push:Get() then return "PUSH" end
    if ui.farm:Get() then return "FARM" end
    if ui.follow:Get() then return "FOLLOW" end
    return "IDLE"
end

local function bear_item(name)
    if not bear then return nil end
    for i = 0, 5 do
        local it = sc(NPC.GetItemByIndex, bear, i)
        if it and sc(Ability.GetName, it) == name then
            return it
        end
    end
    return nil
end

local function base_pos()
    return (our_team == 2)
        and Vector(-7200, -6600, 384)
        or Vector(7000, 6400, 384)
end

local function nearest_enemy_hero(pos)
    local best, bd = nil, math.huge
    for _, h in pairs(Heroes.GetAll()) do
        if h and alive(h) and h ~= hero and en(h)
        and not sc(NPC.IsIllusion, h)
        and not sc(Hero.IsClone, h) then
            local p = gp(h)
            if p then
                local d = d2(pos, p)
                if d < bd then
                    bd = d
                    best = h
                end
            end
        end
    end
    return best, bd
end

-- =========================================================
-- PANEL RENDERER
-- =========================================================
local BEAR_PANEL_W = 320
local BEAR_PANEL_H = 175

-- =========================================================
-- BEAR PANEL THEME
-- =========================================================
local BT = {
    bg        = Color(12, 14, 26, 220),
    border    = Color(40, 45, 65, 80),
    text      = Color(235, 238, 255, 255),
    accent    = Color(0, 200, 150, 255),
    dim       = Color(160, 165, 180, 255),
    last_sync = -999,
}

local function sync_bear_theme()
    local now = 0
    pcall(function() now = GameRules.GetGameTime() end)
    if now - BT.last_sync < 0.5 then return end
    BT.last_sync = now
    local ok, style = pcall(Menu.Style)
    if not ok or not style or type(style) ~= "table" then return end
    local function SC(k, a)
        local c = style[k]
        if c and type(c.r) == "number" then return Color(c.r, c.g, c.b, a or c.a or 255) end
        return nil
    end
    BT.bg     = SC("additional_background", 220) or BT.bg
    BT.border = SC("outline", 80) or BT.border
    BT.text   = SC("primary_first_tab_text", 255) or SC("Text", 255) or BT.text
    BT.accent = SC("primary", 255) or SC("ButtonActive", 255) or SC("CheckMark", 255) or BT.accent
    BT.dim    = SC("primary_second_tab_text", 255) or SC("third_tab_text", 255) or SC("section_group_text", 255) or Color(BT.text.r, BT.text.g, BT.text.b, 140)
end

local UIState = {
    Collapsed = false,
    HeightProgress = 1.0,
    LastHeightProgress = 1.0,
    
    SheenProgress = 1.5,
    SheenTimer = 0.0,
    
    LastRTWidth = 0,
    LastRTHeight = 0,
    
    HoverProgress = {
        btn_close = 0.0,
        btn_collapse = 0.0,
        btn_reset_pos = 0.0,
        btn_farm = 0.0,
        btn_push = 0.0,
        theme_blue = 0.0,
        theme_purple = 0.0,
        theme_rose = 0.0,
        theme_green = 0.0,
        theme_gold = 0.0,
    },
    
    InvHoverProgress = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
    
    Palette = {
        Bg = Color(12, 14, 26, 140),
        Border = Color(255, 255, 255, 20),
        Accent = Color(0, 200, 150, 255),
        Text = Color(235, 238, 255, 255),
        Subtext = Color(160, 165, 180, 200),
        Shadow = Color(0, 0, 0, 110),
    }
}

local function ShiftColorHue(color, shiftAmount)
    if not color then return Color(255, 255, 255, 255) end
    local ok, h, s, l = pcall(color.ToHsl, color)
    if not ok or not h then
        return color
    end
    
    local newH = (h + shiftAmount) % 1.0
    local newCol = Color(0, 0, 0, 255)
    local ok_as = pcall(newCol.AsHsl, newCol, newH, s, l, (color.a or 255) / 255)
    if not ok_as then
        return color
    end
    return newCol
end

local function DrawShadowText(font, size, text, pos, color, shadowAlpha)
    shadowAlpha = shadowAlpha or 160
    local shadowColor = Color(0, 0, 0, shadowAlpha)
    Render.Text(font, size, text, Vec2(pos.x + 1, pos.y + 1), shadowColor)
    Render.Text(font, size, text, pos, color)
end

local function UpdateUIAnimations(dt, mx, my)
    -- Sheen swipe
    UIState.SheenTimer = UIState.SheenTimer + dt
    if UIState.SheenTimer >= 5.0 then
        UIState.SheenTimer = 0.0
        UIState.SheenProgress = -0.5
    end
    if UIState.SheenProgress < 1.5 then
        UIState.SheenProgress = UIState.SheenProgress + 1.8 * dt
    end

    -- Dynamic collapse height animation
    local targetHeightProgress = UIState.Collapsed and 0.0 or 1.0
    UIState.HeightProgress = UIState.HeightProgress + (targetHeightProgress - UIState.HeightProgress) * 12.0 * dt
    if math.abs(UIState.HeightProgress - targetHeightProgress) < 0.005 then
        UIState.HeightProgress = targetHeightProgress
    end

    -- Update HoverProgress for header buttons and mode buttons
    local px = ui.panel_x and ui.panel_x:Get() or 760
    local py = ui.panel_y and ui.panel_y:Get() or 150
    local scale = (Menu.Scale() or 100) / 100
    local W = BEAR_PANEL_W * scale
    
    local btnY = py + 15 * scale
    local closeX = px + 15 * scale
    local collapseX = px + 30 * scale
    local resetX = px + 45 * scale
    local btnR = 4.5 * scale

    local closeHover = mx and my and is_mouse_in_rect(mx, my, closeX - btnR - 2*scale, py, btnR*2 + 4*scale, 30*scale)
    local collapseHover = mx and my and is_mouse_in_rect(mx, my, collapseX - btnR - 2*scale, py, btnR*2 + 4*scale, 30*scale)
    local resetHover = mx and my and is_mouse_in_rect(mx, my, resetX - btnR - 2*scale, py, btnR*2 + 4*scale, 30*scale)

    local function update_hover(ctrl_id, is_hovered)
        local progress = UIState.HoverProgress[ctrl_id] or 0.0
        local target = is_hovered and 1.0 or 0.0
        local next_p = progress + (target - progress) * 11.0 * dt
        if math.abs(next_p - target) < 0.001 then
            next_p = target
        end
        UIState.HoverProgress[ctrl_id] = next_p
    end

    update_hover("btn_close", closeHover)
    update_hover("btn_collapse", collapseHover)
    update_hover("btn_reset_pos", resetHover)

    -- Update Farm/Push buttons hover progress
    local farm_x = px + W - 108 * scale
    local push_x = px + W - 56 * scale
    local btn_y = py + 8 * scale
    local btn_w = 46 * scale
    local btn_h = 17 * scale

    local farmHover = mx and my and is_mouse_in_rect(mx, my, farm_x, btn_y, btn_w, btn_h)
    local pushHover = mx and my and is_mouse_in_rect(mx, my, push_x, btn_y, btn_w, btn_h)

    update_hover("btn_farm", farmHover)
    update_hover("btn_push", pushHover)

    -- Update inventory slots hover zoom
    local inv_y = py + 135 * scale
    local slot_w = 44 * scale
    local slot_h = 30 * scale
    local start_x = px + 13 * scale

    for i = 0, 5 do
        local sx = start_x + i * 50 * scale
        local is_slot_hovered = mx and my and is_mouse_in_rect(mx, my, sx, inv_y, slot_w, slot_h) and not UIState.Collapsed
        
        local progress = UIState.InvHoverProgress[i + 1] or 0.0
        local target = is_slot_hovered and 1.0 or 0.0
        local next_p = progress + (target - progress) * 11.0 * dt
        if math.abs(next_p - target) < 0.001 then
            next_p = target
        end
        UIState.InvHoverProgress[i + 1] = next_p
    end
end

local function draw_pretty_panel(x, y, w, h, title, lines, line_colors, move_mode)
    local scale = (Menu.Scale() or 100) / 100
    local sw = w * scale
    local sh = h * scale
    local rounding = 10 * scale
    
    sync_bear_theme()
    
    -- 1. Backdrop Blur
    pcall(function()
        Render.Blur(Vec2(x, y), Vec2(x + sw, y + sh), 2.5, 1.0, rounding, Enum.DrawFlags.None)
    end)
    
    -- 2. Shadow
    local shadowCol = Color(0, 0, 0, 110)
    pcall(function()
        Render.Shadow(Vec2(x, y), Vec2(x + sw, y + sh), shadowCol, 22, rounding, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(1, 2))
    end)
    
    -- 3. Glass background
    local acc = move_mode and Color(90, 255, 140, 255) or Color(255, 100, 110, 255)
    local bgCol = Color(15, 12, 12, 140)
    if move_mode then
        bgCol = Color(12, 22, 15, 140)
    end
    
    pcall(function()
        Render.FilledRect(Vec2(x, y), Vec2(x + sw, y + sh), bgCol, rounding)
    end)
    
    -- Sheen
    local sheenTopLeft = Color(255, 255, 255, 18)
    local sheenTopRight = Color(255, 255, 255, 6)
    local sheenBottomLeft = Color(255, 255, 255, 3)
    local sheenBottomRight = Color(255, 255, 255, 0)
    pcall(function()
        Render.Gradient(Vec2(x, y), Vec2(x + sw, y + sh), sheenTopLeft, sheenTopRight, sheenBottomLeft, sheenBottomRight, rounding)
    end)
    
    -- 4. Dynamic flowing border around warning
    local animTime = GlobalVars.GetCurTime() or 0.0
    local speed = 0.15
    local cTopLeft = ShiftColorHue(acc, animTime * speed)
    local cTopRight = ShiftColorHue(acc, animTime * speed + 0.25)
    local borderAlpha = 160
    
    pcall(function()
        Render.OutlineGradient(
            Vec2(x, y), Vec2(x + sw, y + sh),
            Color(cTopLeft.r, cTopLeft.g, cTopLeft.b, borderAlpha),
            Color(cTopRight.r, cTopRight.g, cTopRight.b, borderAlpha),
            Color(cTopLeft.r, cTopLeft.g, cTopLeft.b, borderAlpha),
            Color(cTopRight.r, cTopRight.g, cTopRight.b, borderAlpha),
            rounding, Enum.DrawFlags.None, 1.5
        )
    end)
    
    -- 5. Text
    local title_col = Color(255, 255, 255, 255)
    local headerText = title
    if move_mode then
        headerText = "➔ DRAGGING ➔"
        title_col = acc
    end
    
    DrawShadowText(font_big, 14 * scale, headerText, Vec2(x + 12 * scale, y + 8 * scale), title_col)
    
    local lineY = y + 28 * scale
    pcall(function()
        Render.FilledRect(Vec2(x + 10 * scale, lineY), Vec2(x + sw - 10 * scale, lineY + 1), Color(255, 255, 255, 20))
    end)
    
    local yy = y + 36 * scale
    for i, text in ipairs(lines) do
        local col = line_colors[i] or Color(180, 180, 180, 255)
        DrawShadowText(font_small, 11 * scale, text, Vec2(x + 12 * scale, yy), col)
        yy = yy + 16 * scale
    end
end

local function color_rgba(c)
    if not c then return nil end

    if type(c) == "userdata" and c.Unpack then
        local ok, r, g, b, a = pcall(function() return c:Unpack() end)
        if ok and type(r) == "number" then
            return r, g, b, a
        end
    end

    if type(c) == "table" then
        local r = c.r or c.R or c[1]
        local g = c.g or c.G or c[2]
        local b = c.b or c.B or c[3]
        local a = c.a or c.A or c[4] or 255
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, a
        end
    end

    return nil
end

local function clone_color(c, alpha_override)
    local r, g, b, a = color_rgba(c)
    if not r then return nil end
    return Color(r, g, b, alpha_override or a or 255)
end

local function mix_color(a, b, t, alpha_override)
    local ar, ag, ab, aa = color_rgba(a)
    local br, bg, bb, ba = color_rgba(b)
    if not ar or not br then
        return clone_color(a or b, alpha_override)
    end

    local nt = math.max(0, math.min(1, t or 0.5))
    local r = math.floor(ar + (br - ar) * nt + 0.5)
    local g = math.floor(ag + (bg - ag) * nt + 0.5)
    local b2 = math.floor(ab + (bb - ab) * nt + 0.5)
    local a2 = alpha_override or math.floor((aa or 255) + ((ba or 255) - (aa or 255)) * nt + 0.5)
    return Color(r, g, b2, a2)
end

local function menu_style_color(name)
    if not Menu or not Menu.Style then return nil end

    local ok, clr = pcall(Menu.Style, name)
    if ok and clr then return clr end

    local ok_tbl, tbl = pcall(Menu.Style)
    if ok_tbl and type(tbl) == "table" then
        return tbl[name]
    end

    return nil
end

local function first_style_color(names)
    for _, name in ipairs(names) do
        local clr = menu_style_color(name)
        if clr then return clr end
    end
    return nil
end

local function get_menu_glass_palette(move_mode)
    local accent = first_style_color({
        "ButtonActive", "SliderGrabActive", "ResizeGripActive", "HeaderActive", "CheckMark", "PlotHistogram"
    }) or Color(125, 185, 255, 255)

    local accent_soft = first_style_color({
        "ButtonHovered", "SliderGrab", "HeaderHovered", "SeparatorActive", "ResizeGripHovered"
    }) or mix_color(accent, Color(255, 255, 255, 255), 0.20, 255)

    local text = first_style_color({"Text", "TextSelectedBg"}) or Color(240, 244, 255, 255)
    local border = first_style_color({"Border", "Separator", "ResizeGrip"}) or mix_color(accent, Color(255, 255, 255, 255), 0.35, 180)

    local bg = mix_color(Color(12, 16, 22, 255), accent, 0.12, 164)
    local bg2 = mix_color(Color(24, 28, 38, 255), accent_soft, 0.16, 132)
    local sheen = mix_color(Color(255, 255, 255, 255), accent_soft, 0.08, 40)
    local divider = mix_color(border, accent_soft, 0.28, 110)
    local subdued = mix_color(text, bg, 0.62, 200)
    local glass = mix_color(Color(255, 255, 255, 255), accent_soft, 0.10, 28)

    if move_mode then
        accent = Color(90, 255, 140, 255)
        accent_soft = Color(150, 255, 190, 255)
        border = Color(110, 255, 160, 180)
        bg = Color(18, 32, 24, 160)
        bg2 = Color(28, 44, 34, 130)
        sheen = Color(255, 255, 255, 45)
        divider = Color(110, 255, 160, 100)
        subdued = Color(210, 255, 225, 205)
        glass = Color(140, 255, 180, 28)
    end

    return {
        accent = accent,
        accent_soft = accent_soft,
        text = text,
        border = border,
        bg = bg,
        bg2 = bg2,
        sheen = sheen,
        divider = divider,
        subdued = subdued,
        glass = glass,
    }
end



local function trim_panel_text(text, limit)
    local s = tostring(text or "")
    if #s > limit then
        return s:sub(1, math.max(1, limit - 3)) .. "..."
    end
    return s
end

local function pretty_def_reason(reason, active)
    if not active then return L("Спокойно", "Stable") end

    local map = {
        ["CRITICAL HP -> BASE"] = L("Критический HP", "Critical HP"),
        ["LOW HP -> HERO"] = L("К герою", "To hero"),
        ["GANKED"] = L("Под давлением", "Under pressure"),
        ["HEALING AT BASE"] = L("Отхил на базе", "Healing at base"),
        ["ROAR"] = L("Рык", "Roar"),
        ["RETURN"] = L("Возврат", "Return"),
        ["PHASE RUN"] = L("Разгон", "Sprint"),
    }

    return trim_panel_text(map[reason] or tostring(reason or "PANIC"), 22)
end

local function pretty_unit_label(unit)
    if not unit or not alive(unit) then
        return L("нет цели", "no target")
    end

    local raw_name = gn(unit)
    local display = nil
    if Engine and Engine.GetDisplayNameByUnitName then
        display = sc(Engine.GetDisplayNameByUnitName, raw_name)
    end

    local name = display or raw_name or "???"
    name = tostring(name)
    name = name:gsub("npc_dota_hero_", "")
        :gsub("npc_dota_", "")
        :gsub("_", " ")

    return string.upper(trim_panel_text(name, 24))
end

local img_cache = {}

local function get_image_handle(path)
    if not path or path == "" then return nil end
    if img_cache[path] then return img_cache[path] end
    local handle = sc(Render.LoadImage, path)
    if handle then
        img_cache[path] = handle
    end
    return handle
end

local function get_item_texture_path(item_name)
    if not item_name or item_name == "" then return nil end
    if string.find(item_name, "recipe", 1, true) then
        return "panorama/images/items/recipe_png.vtex_c"
    end
    local name = item_name:gsub("item_", "")
    return "panorama/images/items/" .. name .. "_png.vtex_c"
end

-- =========================================================
-- PANEL: BEAR STATUS
-- =========================================================
local function DrawSheenSwipe(x, y, w, h, progress, scale)
    if progress < 0.0 or progress > 1.0 then return end
    
    local sheenW = 50 * scale
    local totalPath = w + sheenW * 2
    local sheenX = x - sheenW + totalPath * progress
    
    local colCenter = Color(255, 255, 255, 22)
    local colFade = Color(255, 255, 255, 0)
    
    pcall(function()
        Render.Gradient(
            Vec2(sheenX, y), Vec2(sheenX + sheenW, y + h),
            colFade, colCenter, colCenter, colFade, 0, Enum.DrawFlags.None
        )
    end)
end

local function draw_bear_panel(x, y, mode, aghs_ok, aghs_gate, hp_num, d_now, cur_camp, stack_state, minute, sec, move_mode)
    sync_bear_theme()
    local scale = (Menu.Scale() or 100) / 100
    local W = BEAR_PANEL_W * scale
    local H = BEAR_PANEL_H * scale
    local rounding = 12 * scale
    local currentHeight = (30 * scale) + (H - 30 * scale) * UIState.HeightProgress
    local F = math.floor

    local function aa(c, a)
        return Color(c.r, c.g, c.b, F(math.max(0, math.min(255, a))))
    end
    local function tsz(txt)
        local ok, r = pcall(Render.TextSize, font_small, 11 * scale, tostring(txt))
        return (ok and r) or {x = 6 * scale * #tostring(txt), y = 12 * scale}
    end

    local acc    = move_mode and Color(90, 255, 140, 255) or BT.accent
    local txt_c  = BT.text
    local dim    = BT.dim
    local ok_c   = Color(80, 220, 130, 255)
    local warn_c = Color(255, 100, 110, 255)
    local sep_c  = Color(dim.r, dim.g, dim.b, 35)

    -- 1. Backdrop Blur & Real-time Shadow
    pcall(function()
        Render.Blur(Vec2(x, y), Vec2(x + W, y + currentHeight), 2.5, 1.0, rounding, Enum.DrawFlags.None)
    end)
    local shadowCol = Color(0, 0, 0, 110)
    pcall(function()
        Render.Shadow(Vec2(x, y), Vec2(x + W, y + currentHeight), shadowCol, 22, rounding, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(1, 2))
    end)

    -- 2. Render Target (RT) Caching
    local rtHandle = Render.FindOrCreateRT("glass_panel_bear", W, H)
    local sizeChanged = UIState.LastRTWidth ~= W or UIState.LastRTHeight ~= H
    local heightChanged = UIState.LastHeightProgress ~= UIState.HeightProgress
    
    if sizeChanged then
        pcall(Render.ResizeRT, rtHandle, W, H)
        pcall(Render.MarkDirtyRT, rtHandle)
        UIState.LastRTWidth = W
        UIState.LastRTHeight = H
    end
    if heightChanged then
        pcall(Render.MarkDirtyRT, rtHandle)
        UIState.LastHeightProgress = UIState.HeightProgress
    end

    -- Clip both RT rendering and sheen swipe to the current active height!
    pcall(function()
        Render.PushClip(Vec2(x, y), Vec2(x + W, y + currentHeight))
    end)
    
    pcall(function()
        Render.RenderRT(function()
            -- Baked glass background
            Render.FilledRect(Vec2(0, 0), Vec2(W, currentHeight), Color(15, 15, 25, 140), rounding)
            
            -- Gloss Sheen Gradient
            local sheenTopLeft = Color(255, 255, 255, 18)
            local sheenTopRight = Color(255, 255, 255, 6)
            local sheenBottomLeft = Color(255, 255, 255, 3)
            local sheenBottomRight = Color(255, 255, 255, 0)
            Render.Gradient(Vec2(0, 0), Vec2(W, currentHeight), sheenTopLeft, sheenTopRight, sheenBottomLeft, sheenBottomRight, rounding)
            
            -- Divider line
            local lineY = F(29 * scale)
            Render.FilledRect(Vec2(10 * scale, lineY), Vec2(W - 10 * scale, lineY + 1), Color(255, 255, 255, 18))
        end, rtHandle, Vec2(x, y), Color(255, 255, 255, 255))
    end)

    -- Sheen swipe
    pcall(function()
        DrawSheenSwipe(x, y, W, currentHeight, UIState.SheenProgress, scale)
    end)
    
    pcall(function()
        Render.PopClip()
    end)

    -- 3. Flowing Border Outline Gradient
    local animTime = GlobalVars.GetCurTime() or 0.0
    local speed = 0.15
    local cTopLeft = ShiftColorHue(acc, animTime * speed)
    local cTopRight = ShiftColorHue(acc, animTime * speed + 0.25)
    local borderAlpha = 160
    
    pcall(function()
        Render.OutlineGradient(
            Vec2(x, y), Vec2(x + W, y + currentHeight),
            Color(cTopLeft.r, cTopLeft.g, cTopLeft.b, borderAlpha),
            Color(cTopRight.r, cTopRight.g, cTopRight.b, borderAlpha),
            Color(cTopLeft.r, cTopLeft.g, cTopLeft.b, borderAlpha),
            Color(cTopRight.r, cTopRight.g, cTopRight.b, borderAlpha),
            rounding, Enum.DrawFlags.None, 1.5
        )
    end)

    -- ── macOS-Style Header Buttons ──────────────────────────
    local btnY = y + 15 * scale
    local closeX = x + 15 * scale
    local collapseX = x + 30 * scale
    local resetX = x + 45 * scale
    local btnR = 4.5 * scale

    -- Draw Red Button (Close)
    local closeHoverP = UIState.HoverProgress["btn_close"] or 0.0
    local closeCol = mix_color(Color(255, 95, 87, 200), Color(255, 70, 60, 255), closeHoverP)
    pcall(Render.FilledCircle, Vec2(closeX, btnY), btnR, closeCol)
    if closeHoverP > 0.3 then
        local crossCol = Color(0, 0, 0, F(180 * closeHoverP))
        local d = 1.5 * scale
        pcall(Render.Line, Vec2(closeX - d, btnY - d), Vec2(closeX + d, btnY + d), crossCol, 1)
        pcall(Render.Line, Vec2(closeX - d, btnY + d), Vec2(closeX + d, btnY - d), crossCol, 1)
    end

    -- Draw Yellow Button (Collapse)
    local collapseHoverP = UIState.HoverProgress["btn_collapse"] or 0.0
    local collapseCol = mix_color(Color(254, 188, 46, 200), Color(254, 170, 30, 255), collapseHoverP)
    pcall(Render.FilledCircle, Vec2(collapseX, btnY), btnR, collapseCol)
    if collapseHoverP > 0.3 then
        local lineCol = Color(0, 0, 0, F(180 * collapseHoverP))
        local d = 1.5 * scale
        pcall(Render.Line, Vec2(collapseX - d, btnY), Vec2(collapseX + d, btnY), lineCol, 1)
    end

    -- Draw Green Button (Reset Pos)
    local resetHoverP = UIState.HoverProgress["btn_reset_pos"] or 0.0
    local resetCol = mix_color(Color(40, 200, 64, 200), Color(30, 180, 50, 255), resetHoverP)
    pcall(Render.FilledCircle, Vec2(resetX, btnY), btnR, resetCol)
    if resetHoverP > 0.3 then
        local plusCol = Color(0, 0, 0, F(180 * resetHoverP))
        local d = 1.5 * scale
        pcall(Render.Line, Vec2(resetX - d, btnY), Vec2(resetX + d, btnY), plusCol, 1)
        pcall(Render.Line, Vec2(resetX, btnY - d), Vec2(resetX, btnY + d), plusCol, 1)
    end

    -- Header Title
    local titleText = "SPIRIT BEAR"
    if ui.drag_mode:Get() then
        titleText = "➔ DRAGGING ➔"
    end
    local titleCol = ui.drag_mode:Get() and acc or txt_c
    DrawShadowText(font_big, 13 * scale, titleText, Vec2(x + 60 * scale, y + 8 * scale), titleCol)

    -- Interactive Buttons (top-right)
    local btn_y = y + 8 * scale
    local btn_w = 46 * scale
    local btn_h = 17 * scale
    
    local function draw_pill_btn(btn_x, text, isActive, hoverP, activeCol)
        local baseBg = isActive and Color(activeCol.r, activeCol.g, activeCol.b, 40) or Color(0, 0, 0, 80)
        local targetBg = Color(activeCol.r, activeCol.g, activeCol.b, 75)
        local bgCol = isActive and baseBg or mix_color(baseBg, targetBg, hoverP)
        
        local baseBorder = isActive and activeCol or Color(255, 255, 255, 20)
        local targetBorder = activeCol
        local borderCol = mix_color(baseBorder, targetBorder, hoverP)
        
        local r = 4 * scale
        
        if isActive or hoverP > 0 then
            local targetGlow = isActive and 60 or 40
            local glowAlpha = F(targetGlow * (isActive and 1.0 or hoverP))
            local glowCol = Color(activeCol.r, activeCol.g, activeCol.b, glowAlpha)
            pcall(Render.Shadow, Vec2(btn_x, btn_y), Vec2(btn_x + btn_w, btn_y + btn_h), glowCol, 6 * scale, r, Enum.DrawFlags.ShadowCutOutShapeBackground)
        end
        
        pcall(Render.FilledRect, Vec2(btn_x, btn_y), Vec2(btn_x + btn_w, btn_y + btn_h), bgCol, r)
        pcall(Render.Rect, Vec2(btn_x, btn_y), Vec2(btn_x + btn_w, btn_y + btn_h), borderCol, r)
        
        local textCol = isActive and Color(255, 255, 255, 255) or Color(txt_c.r, txt_c.g, txt_c.b, 160 + F(95 * hoverP))
        local tsz_btn = tsz(text)
        Render.Text(font_small, 11 * scale, text, Vec2(btn_x + (btn_w - tsz_btn.x)/2, btn_y + (btn_h - 12 * scale)/2), textCol)
    end

    -- Draw Lock Warning or Normal buttons
    if aghs_gate ~= "" then
        local lx = x + W - 156 * scale
        local lw = 38 * scale
        local lh = 17 * scale
        local r = 4 * scale
        local pulse = F(90 + 60 * math.sin(GlobalVars.GetCurTime() * 8.5))
        pcall(Render.Shadow, Vec2(lx, btn_y), Vec2(lx + lw, btn_y + lh), Color(255, 100, 110, pulse), 6 * scale, r, Enum.DrawFlags.ShadowCutOutShapeBackground)
        pcall(Render.FilledRect, Vec2(lx, btn_y), Vec2(lx + lw, btn_y + lh), Color(255, 100, 110, 30), r)
        pcall(Render.Rect, Vec2(lx, btn_y), Vec2(lx + lw, btn_y + lh), Color(255, 100, 110, 180), r)
        local lsz = tsz("LOCK")
        Render.Text(font_small, 10 * scale, "LOCK", Vec2(lx + (lw - lsz.x)/2, btn_y + (lh - 12 * scale)/2), Color(255, 100, 110, 255))
    end

    local farm_active = ui.farm:Get()
    local farm_hover = UIState.HoverProgress["btn_farm"] or 0.0
    draw_pill_btn(x + W - 108 * scale, "FARM", farm_active, farm_hover, Color(80, 200, 255, 255))

    local push_active = ui.push:Get()
    local push_hover = UIState.HoverProgress["btn_push"] or 0.0
    draw_pill_btn(x + W - 56 * scale, "PUSH", push_active, push_hover, Color(255, 180, 50, 255))

    -- ── Collapsible Content Container ───────────────────────
    pcall(function()
        Render.PushClip(Vec2(x, y + 30 * scale), Vec2(x + W, y + currentHeight))
    end)

    -- ── Health Bar & Text ───────────────────────────────────
    local hp_txt = hp_num and (hp_num .. "%") or "N/A"
    local hp_c = hp_num and (hp_num <= 25 and warn_c or (hp_num <= 50 and Color(255, 185, 60, 255) or ok_c)) or aa(dim, 180)
    local hpsz = tsz(hp_txt)
    DrawShadowText(font_small, 11 * scale, hp_txt, Vec2(x + W - hpsz.x - 12 * scale, y + 28 * scale), hp_c)

    local bar_y = y + 42 * scale
    pcall(Render.FilledRect, Vec2(x + 11 * scale, bar_y), Vec2(x + W - 11 * scale, bar_y + 5 * scale), Color(0, 0, 0, 80), 2.5 * scale)
    if hp_num and hp_num > 0 then
        local fw = math.max(1, F((W - 22 * scale) * math.min(1, hp_num / 100)))
        pcall(Render.FilledRect, Vec2(x + 11 * scale, bar_y), Vec2(x + 11 * scale + fw, bar_y + 5 * scale), hp_c, 2.5 * scale)
        -- Highlight glow under health bar
        local barGlowCol = Color(hp_c.r, hp_c.g, hp_c.b, 60)
        pcall(Render.Shadow, Vec2(x + 11 * scale, bar_y), Vec2(x + 11 * scale + fw, bar_y + 5 * scale), barGlowCol, 4 * scale, 2.5 * scale, Enum.DrawFlags.ShadowCutOutShapeBackground)
    end

    -- Divider
    local s1 = y + 54 * scale
    pcall(Render.FilledRect, Vec2(x + 10 * scale, s1), Vec2(x + W - 10 * scale, s1 + 1), sep_c)

    -- ── Stats Grid Rows ─────────────────────────────────────
    local r1 = s1 + 7 * scale
    DrawShadowText(font_small, 11 * scale, "AI", Vec2(x + 12 * scale, r1), aa(dim, 180))
    local ai_v = ui.on:Get() and "ON" or "OFF"
    DrawShadowText(font_small, 11 * scale, ai_v, Vec2(x + 32 * scale, r1), ui.on:Get() and ok_c or warn_c)

    DrawShadowText(font_small, 11 * scale, "AGHS", Vec2(x + 105 * scale, r1), aa(dim, 180))
    local ag_v = aghs_ok and L("ДА", "YES") or L("НЕТ", "NO")
    DrawShadowText(font_small, 11 * scale, ag_v, Vec2(x + 147 * scale, r1), aghs_ok and ok_c or warn_c)

    DrawShadowText(font_small, 11 * scale, "MIRR", Vec2(x + 220 * scale, r1), aa(dim, 180))
    local mir_v = ui.mirror_on:Get() and "ON" or "OFF"
    DrawShadowText(font_small, 11 * scale, mir_v, Vec2(x + 260 * scale, r1), ui.mirror_on:Get() and aa(acc, 230) or aa(dim, 155))

    local r2 = r1 + 18 * scale
    DrawShadowText(font_small, 11 * scale, L("ЗАЩИТА:", "DEFENSE:"), Vec2(x + 12 * scale, r2), aa(dim, 180))
    DrawShadowText(font_small, 11 * scale, pretty_def_reason(def.reason, d_now), Vec2(x + 78 * scale, r2), d_now and warn_c or ok_c)
    
    local time_txt = tostring(minute) .. ":" .. string.format("%02d", F(sec))
    local tsz_t = tsz(time_txt)
    DrawShadowText(font_small, 11 * scale, time_txt, Vec2(x + W - tsz_t.x - 12 * scale, r2), aa(dim, 180))

    local r3 = r2 + 18 * scale
    DrawShadowText(font_small, 11 * scale, L("КЕМП:", "CAMP:"), Vec2(x + 12 * scale, r3), aa(dim, 180))
    DrawShadowText(font_small, 11 * scale, trim_panel_text(cur_camp, 4), Vec2(x + 56 * scale, r3), txt_c)

    local stk_c = aa(dim, 160)
    if stack_state == "PULL" or stack_state == "AGGRO" or stack_state == "APPROACH" or stack_state == "WAIT" then
        stk_c = Color(255, 200, 80, 255)
    elseif stack_state == "DONE" or stack_state == "READY" or stack_state == "ГОТОВ" then
        stk_c = ok_c
    end
    DrawShadowText(font_small, 11 * scale, L("СТАК:", "STACK:"), Vec2(x + 115 * scale, r3), aa(dim, 180))
    DrawShadowText(font_small, 11 * scale, trim_panel_text(stack_state, 10), Vec2(x + 165 * scale, r3), stk_c)

    local r4 = r3 + 18 * scale
    local tgt_lbl = ui.mirror_on:Get() and L("ЦЕЛЬ:", "TARGET:") or L("ЗЕРКАЛО:", "MIRROR:")
    DrawShadowText(font_small, 11 * scale, tgt_lbl, Vec2(x + 12 * scale, r4), ui.mirror_on:Get() and aa(acc, 200) or aa(dim, 160))
    
    local tgt_val = L("нет цели", "no target")
    local tgt_vc  = aa(dim, 140)
    if ui.mirror_on:Get() and mirror_tgt and alive(mirror_tgt) then
        tgt_val = pretty_unit_label(mirror_tgt)
        tgt_vc  = aa(acc, 240)
    end
    DrawShadowText(font_small, 11 * scale, tgt_val, Vec2(x + 70 * scale, r4), tgt_vc)

    -- ── Bear Inventory Slots ────────────────────────────────
    local inv_y = y + 135 * scale
    local slot_w = 44 * scale
    local slot_h = 30 * scale
    local start_x = x + 13 * scale

    for i = 0, 5 do
        local sx = start_x + i * 50 * scale
        local hoverP = UIState.InvHoverProgress[i + 1] or 0.0
        
        -- Aspect ratio 44:30
        local zoomW = 3 * scale * hoverP
        local zoomH = zoomW * (30 / 44)
        
        local dx = sx - zoomW/2
        local dy = inv_y - zoomH/2
        local dw = slot_w + zoomW
        local dh = slot_h + zoomH
        
        local r = 4 * scale
        
        -- Slot backdrop
        pcall(Render.FilledRect, Vec2(dx, dy), Vec2(dx + dw, dy + dh), Color(0, 0, 0, 100), r)
        
        -- Active glow outline on hover
        local borderCol = Color(255, 255, 255, 12 + F(30 * hoverP))
        if hoverP > 0 then
            local glowCol = Color(acc.r, acc.g, acc.b, F(70 * hoverP))
            pcall(Render.Shadow, Vec2(dx, dy), Vec2(dx + dw, dy + dh), glowCol, 6 * scale, r, Enum.DrawFlags.ShadowCutOutShapeBackground)
            borderCol = mix_color(borderCol, acc, hoverP)
        end
        pcall(Render.Rect, Vec2(dx, dy), Vec2(dx + dw, dy + dh), borderCol, r)
        
        if bear and alive(bear) then
            local it = sc(NPC.GetItemByIndex, bear, i)
            if it then
                local name = sc(Ability.GetName, it)
                local path = get_item_texture_path(name)
                if path then
                    local img = get_image_handle(path)
                    if img then
                        pcall(Render.Image, img, Vec2(dx, dy), Vec2(dw, dh), Color(255, 255, 255, 255), r)
                    end
                end
                
                local cd = sc(Ability.GetCooldown, it)
                if cd and cd > 0 then
                    pcall(Render.FilledRect, Vec2(dx, dy), Vec2(dx + dw, dy + dh), Color(0, 0, 0, 150), r)
                    local cd_txt = tostring(math.ceil(cd))
                    local cd_sz = tsz(cd_txt)
                    Render.Text(font_small, 11 * scale, cd_txt, Vec2(dx + (dw - cd_sz.x) / 2, dy + (dh - 12 * scale) / 2), Color(255, 255, 255, 255))
                end
            end
        end
    end

    pcall(function()
        Render.PopClip()
    end)
end


-- =========================================================
local function init_teams()
    if our_team or not hero then return end
    our_team = sc(Entity.GetTeamNum, hero)
    if not our_team then return end
    enemy_team = our_team == 2 and 3 or 2
end

-- =========================================================
-- BEAR
-- =========================================================
local function refresh_bear()
    if bear and alive(bear) and BEARS[gn(bear)] then return end

    bear = nil

    -- 7.40: Try CustomEntities.GetSpiritBear using the innate Summon Spirit Bear ability
    if hero and CustomEntities and CustomEntities.GetSpiritBear then
        for i = 0, 15 do
            local ab = sc(NPC.GetAbilityByIndex, hero, i)
            if ab then
                local name = sc(Ability.GetName, ab)
                if name == "lone_druid_summon_spirit_bear" or name == "lone_druid_spirit_bear" then
                    local b = sc(CustomEntities.GetSpiritBear, ab)
                    if b and alive(b) then
                        bear = b
                        reset_farm_state()
                        reset_stack_state()
                        reset_hum_state()
                        reset_def_state()
                        return
                    end
                end
            end
        end
    end

    -- Fallback: scan NPC list
    local list = npc_cache or NPCs.GetAll()
    for _, u in pairs(list) do
        if u and alive(u) and BEARS[gn(u)] then
            local team = sc(Entity.GetTeamNum, u)
            if our_team == nil or team == our_team then
                bear = u
                reset_farm_state()
                reset_stack_state()
                reset_hum_state()
                reset_def_state()
                return
            end
        end
    end
end

local function has_aghs()
    -- Если медведя нет, то и проверять нечего
    if not bear then return false end

    -- Списки всех возможных системных названий Аганима
    local scepters = {
        ["item_ultimate_scepter"]   = true,
        ["item_aghanims_scepter"]   = true,
        ["item_ultimate_scepter_2"] = true,
        ["item_aghanims_blessing"]  = true,
    }

    -- Списки баффов (когда Аганим съеден рецептом, выпал с Рошана или передан Алхимиком)
    local mods = {
        "modifier_item_ultimate_scepter_consumed",
        "modifier_item_ultimate_scepter_consumed_alchemist",
        "modifier_item_ultimate_scepter",
        "modifier_item_aghanims_scepter",
    }

    -- Важно: проверяем И медведя И самого героя (т.к. аганим на герое работает и на медведя)
    for _, unit in ipairs({bear, hero}) do
        if unit and alive(unit) then
            
            -- 1. Системная проверка API чита (если поддерживается)
            if NPC.HasScepter then
                local ok, r = pcall(NPC.HasScepter, unit)
                if ok and r == true then return true end
            end

            -- 2. Проверка баффов Aghanim's Blessing (съеденного аганима)
            for _, m in ipairs(mods) do
                if sc(Entity.HasModifier, unit, m) == true then 
                    return true 
                end
            end

            -- 3. Проверка инвентаря (цикл до 16, чтобы проверить и рюкзак, и тайш)
            for i = 0, 16 do
                local it = sc(NPC.GetItemByIndex, unit, i)
                if it then
                    local name = sc(Ability.GetName, it) or ""
                    if scepters[name] then 
                        return true 
                    end
                end
            end

        end
    end

    return false
end

local function bear_ab(name)
    if not bear then return nil end
    for i = 0, 15 do
        local ab = sc(NPC.GetAbilityByIndex, bear, i)
        if ab and sc(Ability.GetName, ab) == name then
            return ab
        end
    end
    return nil
end

-- =========================================================
-- ORDERS
-- =========================================================
local function hum_jitter(pos)
    local j = ui.hum_jitter:Get()
    if j == 0 then return pos end
    local dx = (math.random() * 2 - 1) * j
    local dy = (math.random() * 2 - 1) * j
    return Vector(pos:GetX() + dx, pos:GetY() + dy, pos:GetZ())
end

local function ord(t, tgt, pos, ab)
    if not player or not bear or not alive(bear) then return end
    Player.PrepareUnitOrders(player, t, tgt, pos, ab, ISSUER, bear, false)
end

local function ba(t)
    if not t or not alive(t) then return end
    if ui.hum_on:Get() then
        local min_int = ui.hum_atk_delay:Get() / 1000.0
        if t == hum_last_tgt and (hum_now - hum_last_atk) < min_int then return end
        if t == hum_last_tgt and sc(NPC.IsAttacking, bear) then return end
    end
    hum_last_tgt = t
    hum_last_atk = hum_now
    reset_hum_move()
    ord(O_ATTACK, t, nil, nil)
end

local function ba_force(t)
    if not t or not alive(t) then return end
    hum_last_tgt = t
    hum_last_atk = hum_now
    reset_hum_move()
    ord(O_ATTACK, t, nil, nil)
end

local function bam(p)
    if not p then return end
    reset_hum_move()
    ord(O_ATK_MV, nil, p, nil)
end

local function bm(p, tag, allow_jitter)
    if not p then return end
    if tag == nil then tag = "move" end
    if allow_jitter == nil then allow_jitter = true end

    local send_pos = p

    if ui.hum_on:Get() then
        local min_int = ui.hum_mov_delay:Get() / 1000.0

        local goal_changed =
            (hum_goal_pos == nil)
            or (hum_goal_tag ~= tag)
            or (hum_goal_allow_jitter ~= allow_jitter)
            or (d2(hum_goal_pos, p) > 200)

        if goal_changed then
            hum_goal_pos          = p
            hum_goal_tag          = tag
            hum_goal_allow_jitter = allow_jitter
            hum_goal_jittered     = (allow_jitter and ui.hum_jitter:Get() > 0) and hum_jitter(p) or p
        end

        if not goal_changed and (hum_now - hum_last_mov) < min_int then return end

        local bpos = gp(bear)
        if bpos and hum_goal_jittered and d2(bpos, hum_goal_jittered) < 90 then return end

        send_pos = hum_goal_jittered or p
    end

    hum_last_mov = hum_now
    ord(O_MOVE, nil, send_pos, nil)
end

local function bm_force(p, tag)
    if not p then return end
    reset_hum_move()
    hum_last_mov = hum_now
    ord(O_MOVE, nil, p, nil)
end

local function bct(a, t)
    reset_hum_move()
    ord(O_CAST_T, t, nil, a)
end

local function bcn(a)
    reset_hum_move()
    ord(O_CAST_N, nil, nil, a)
end

local function hgive(it)
    if not player or not hero or not bear or not it then return end
    if not alive(hero) or not alive(bear) then return end

    local hp = gp(hero)
    local bp2 = gp(bear)
    if not hp or not bp2 then return end
    if d2(hp, bp2) > GIVE_D then return end

    Player.PrepareUnitOrders(player, O_GIVE, bear, nil, it, ISSUER, hero, false)
end

local function is_invisible(unit)
    if not unit then return false end
    local invisible_state = Enum.ModifierState.MODIFIER_STATE_INVISIBLE
    if invisible_state and NPC.HasState then
        local ok, r = pcall(NPC.HasState, unit, invisible_state)
        if ok and r == true then return true end
    end
    local mods = {
        "modifier_invisible", "modifier_mirana_moonlight_shadow", "modifier_item_shadow_blade",
        "modifier_item_silver_edge", "modifier_item_invisibility_edge", "modifier_item_glimmer_cape_fade"
    }
    for _, m in ipairs(mods) do
        if sc(Entity.HasModifier, unit, m) == true then
            return true
        end
    end
    return false
end

local function get_bear_damage()
    if not bear or not alive(bear) then return 0 end
    local dmg_min = sc(NPC.GetTrueDamage, bear) or 40
    local dmg_max = sc(NPC.GetTrueMaximumDamage, bear) or 50
    return (dmg_min + dmg_max) / 2
end

local function is_strong_enough_for_ancients()
    if not hero then return false end
    local lvl = hlvl()
    if lvl >= 7 then return true end
    local items = {
        "item_radiance", "item_maelstrom", "item_mjollnir",
        "item_mask_of_demonic_release", "item_mask_of_madness", "item_armlet"
    }
    for _, it_name in ipairs(items) do
        if bear_item(it_name) then return true end
    end
    return false
end

local function check_armlet_toggle_off()
    local armlet = bear_item("item_armlet")
    if armlet then
        local is_toggled = sc(Ability.GetToggleState, armlet) == true
        if is_toggled then
            local is_attacking = sc(NPC.IsAttacking, bear)
            local is_panicking = panic_active(GameRules.GetGameTime())
            if not is_attacking or is_panicking then
                bcn(armlet)
            end
        end
    end
end

local function use_bear_items(target, is_hero)
    if not bear or not alive(bear) or not target or not alive(target) then return end
    
    local now = GameRules.GetGameTime()
    if now < def.lock_until then return end
    
    local is_combat = is_hero
    local is_farm = not is_hero
    
    if is_combat and not ui.auto_items_combat:Get() then return end
    if is_farm and not ui.auto_items_farm:Get() then return end
    
    local bear_mana = sc(NPC.GetMana, bear) or 0
    local bpos = gp(bear)
    local tpos = gp(target)
    if not bpos or not tpos then return end
    
    local dist = d2(bpos, tpos)
    
    -- 1. Armlet of Mordiggian
    local armlet = bear_item("item_armlet")
    if armlet then
        local is_toggled = sc(Ability.GetToggleState, armlet) == true
        if not is_toggled and sc(Ability.IsCastable, armlet, 0) then
            bcn(armlet)
            def.lock_until = now + 0.05
            return
        end
    end
    
    -- 2. Mask of Madness
    local mom = bear_item("item_mask_of_madness")
    if mom and sc(Ability.IsCastable, mom, 0) then
        bcn(mom)
        def.lock_until = now + 0.05
        return
    end
    
    -- 3. Mjollnir active shield on bear itself
    local mjollnir = bear_item("item_mjollnir")
    if mjollnir and sc(Ability.IsCastable, mjollnir, bear_mana) then
        if is_combat or (is_farm and dist <= 300) then
            bct(mjollnir, bear)
            def.lock_until = now + 0.05
            return
        end
    end
    
    -- 4. Abyssal Blade
    local abyssal = bear_item("item_abyssal_blade")
    if abyssal and is_combat and dist <= 150 and sc(Ability.IsCastable, abyssal, bear_mana) then
        bct(abyssal, target)
        def.lock_until = now + 0.05
        return
    end
    
    -- 5. Orchid / Bloodthorn
    local orchid = bear_item("item_orchid") or bear_item("item_bloodthorn")
    if orchid and is_combat and dist <= 900 and sc(Ability.IsCastable, orchid, bear_mana) then
        local is_silenced = sc(NPC.HasState, target, Enum.ModifierState.MODIFIER_STATE_SILENCED)
            or sc(NPC.HasState, target, Enum.ModifierState.MODIFIER_STATE_HEXED)
        if not is_silenced then
            bct(orchid, target)
            def.lock_until = now + 0.05
            return
        end
    end
    
    -- 6. Nullifier
    local nullifier = bear_item("item_nullifier")
    if nullifier and is_combat and dist <= 900 and sc(Ability.IsCastable, nullifier, bear_mana) then
        bct(nullifier, target)
        def.lock_until = now + 0.05
        return
    end
    
    -- 7. Halberd
    local halberd = bear_item("item_heavens_halberd")
    if halberd and is_combat and dist <= 650 and sc(Ability.IsCastable, halberd, bear_mana) then
        local is_disarmed = sc(NPC.HasState, target, Enum.ModifierState.MODIFIER_STATE_DISARMED)
            or sc(NPC.HasState, target, Enum.ModifierState.MODIFIER_STATE_HEXED)
            or sc(NPC.HasState, target, Enum.ModifierState.MODIFIER_STATE_STUNNED)
        if not is_disarmed then
            bct(halberd, target)
            def.lock_until = now + 0.05
            return
        end
    end
    
    -- 8. Harpoon
    local harpoon = bear_item("item_harpoon")
    if harpoon and is_combat and dist > 300 and dist <= 700 and sc(Ability.IsCastable, harpoon, 0) then
        bct(harpoon, target)
        def.lock_until = now + 0.05
        return
    end
    
    -- 9. Solar Crest / Pavise
    local solar = bear_item("item_solar_crest") or bear_item("item_pavise")
    if solar and is_combat and sc(Ability.IsCastable, solar, 0) then
        local cast_target = bear
        if hero and alive(hero) then
            local hero_hp = (sc(Entity.GetHealth, hero) or 1) / (sc(Entity.GetMaxHealth, hero) or 1) * 100
            if hero_hp < 50 and d2(bpos, gp(hero)) <= 600 then
                cast_target = hero
            end
        end
        bct(solar, cast_target)
        def.lock_until = now + 0.05
        return
    end
    
    -- 10. Black King Bar (BKB)
    local bkb = bear_item("item_black_king_bar")
    if bkb and is_combat and sc(Ability.IsCastable, bkb, 0) then
        local is_disabled = sc(NPC.HasState, bear, Enum.ModifierState.MODIFIER_STATE_STUNNED)
            or sc(NPC.HasState, bear, Enum.ModifierState.MODIFIER_STATE_SILENCED)
            or sc(NPC.HasState, bear, Enum.ModifierState.MODIFIER_STATE_HEXED)
            or sc(NPC.HasState, bear, Enum.ModifierState.MODIFIER_STATE_DISARMED)
        local enemy_hero_count = 0
        for _, enemy_h in pairs(Heroes.GetAll()) do
            if enemy_h and alive(enemy_h) and en(enemy_h) and not sc(NPC.IsIllusion, enemy_h) then
                local eh_p = gp(enemy_h)
                if eh_p and d2(eh_p, bpos) <= 600 then
                    enemy_hero_count = enemy_hero_count + 1
                end
            end
        end
        if is_disabled or enemy_hero_count >= 2 then
            bcn(bkb)
            def.lock_until = now + 0.05
            return
        end
    end
end

-- =========================================================
-- NEUTRALS
-- =========================================================
local function build_neutral_cache()
    neutral_cache = {}
    local list = npc_cache or NPCs.GetAll()
    for _, u in pairs(list) do
        if u then
            local name = sc(NPC.GetUnitName, u)
            if name and string.find(name, "npc_dota_neutral_", 1, true)
                and sc(Entity.IsAlive, u) == true
                and not sc(NPC.IsWaitingToSpawn, u)
                and not sc(NPC.IsInvulnerable, u) then
                local p = sc(Entity.GetAbsOrigin, u)
                if p then
                    neutral_cache[#neutral_cache + 1] = { unit = u, pos = p }
                end
            end
        end
    end
end

local function find_neutrals(center, radius)
    local best, bd, cnt = nil, math.huge, 0

    if neutral_cache then
        for _, e in ipairs(neutral_cache) do
            local d = d2(e.pos, center)
            if d <= radius then
                cnt = cnt + 1
                if d < bd then
                    bd   = d
                    best = e.unit
                end
            end
        end
    else
        local list = npc_cache or NPCs.GetAll()
        for _, u in pairs(list) do
            if u then
                local name = sc(NPC.GetUnitName, u)
                if name and string.find(name, "npc_dota_neutral_", 1, true)
                    and sc(Entity.IsAlive, u) == true
                    and not sc(NPC.IsWaitingToSpawn, u)
                    and not sc(NPC.IsInvulnerable, u) then
                    local p = sc(Entity.GetAbsOrigin, u)
                    if p then
                        local d = d2(p, center)
                        if d <= radius then
                            cnt = cnt + 1
                            if d < bd then
                                bd   = d
                                best = u
                            end
                        end
                    end
                end
            end
        end
    end

    return best, cnt
end

local function find_strike_center(camp_pos_arg)
    if not Camps or not Camps.GetAll then
        return camp_pos_arg
    end

    local camps = sc(Camps.GetAll)
    if not camps then return camp_pos_arg end

    local best_camp, best_dist = nil, math.huge
    for _, c in ipairs(camps) do
        local box = sc(Camp.GetCampBox, c)
        if box and box.min and box.max then
            local cx = (box.min:GetX() + box.max:GetX()) / 2
            local cy = (box.min:GetY() + box.max:GetY()) / 2
            local cz = (box.min:GetZ() + box.max:GetZ()) / 2
            local center = Vector(cx, cy, cz)
            local d = d2(center, camp_pos_arg)
            if d < best_dist then
                best_dist = d
                best_camp = center
            end
        end
    end

    return best_camp or camp_pos_arg
end

local function get_midas_creep_value(u)
    local name = gn(u)
    if string.find(name, "neutral", 1, true) then
        local max_hp = sc(Entity.GetMaxHealth, u) or 1
        if max_hp >= 600 then return 3 end
        return 1
    elseif string.find(name, "creep", 1, true) then
        if string.find(name, "ranged", 1, true) or string.find(name, "flagbearer", 1, true) then
            return 2
        end
        return 0.5
    end
    return 0
end

local function do_midas(bpos)
    local midas = bear_item("item_hand_of_midas")
    if not midas or not sc(Ability.IsCastable, midas, 0) then return false end

    local best_val, best_creep = 0, nil
    local list = npc_cache or NPCs.GetAll()
    for _, u in pairs(list) do
        if u and alive(u) and en(u) and sc(NPC.IsAncient, u) ~= true then
            local p = gp(u)
            if p and d2(p, bpos) <= 600 then
                local val = get_midas_creep_value(u)
                if val > best_val then
                    best_val = val
                    best_creep = u
                end
            end
        end
    end

    if best_creep then
        bct(midas, best_creep)
        return true
    end
    return false
end

local function find_nearest_friendly_creep(pos)
    local best, bd = nil, math.huge
    local list = npc_cache or NPCs.GetAll()
    for _, u in pairs(list) do
        if u and alive(u) and not en(u) then
            local name = gn(u)
            if string.find(name, "npc_dota_creep_", 1, true) then
                local p = gp(u)
                if p then
                    local d = d2(p, pos)
                    if d < bd then
                        bd = d
                        best = u
                    end
                end
            end
        end
    end
    return best
end

local function friendly_creep_near(pos, radius)
    local list = npc_cache or NPCs.GetAll()
    for _, u in pairs(list) do
        if u and alive(u) and not en(u) then
            local name = gn(u)
            if string.find(name, "npc_dota_creep_", 1, true) then
                local p = gp(u)
                if p and d2(p, pos) <= radius then
                    return true
                end
            end
        end
    end
    return false
end

local function juggle_tower_aggro(bpos)
    if not Towers or not Towers.GetAll then return false end
    local towers = sc(Towers.GetAll)
    if not towers then return false end

    for _, t in ipairs(towers) do
        if t and alive(t) and en(t) then
            local tp = gp(t)
            if tp and d2(tp, bpos) <= 900 then
                local target = sc(Tower.GetAttackTarget, t)
                if target == bear then
                    local friendly_creep = find_nearest_friendly_creep(bpos)
                    if friendly_creep and d2(gp(friendly_creep), tp) <= 900 then
                        ord(O_ATTACK, friendly_creep, nil, nil)
                        return true
                    else
                        local retreat_pos = base_pos()
                        if hero and alive(hero) then
                            retreat_pos = gp(hero)
                        end
                        bm_force(retreat_pos, "tower_retreat")
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function do_runes(bpos)
    if not Runes or not Runes.GetAll then return false end
    local list = sc(Runes.GetAll)
    if not list then return false end

    for _, r in ipairs(list) do
        if r and not sc(Entity.IsDormant, r) then
            local rp = gp(r)
            if rp then
                local dist = d2(rp, bpos)
                if dist <= 800 then
                    local enemy, enemy_dist = nearest_enemy_hero(rp)
                    if not enemy or enemy_dist > 500 then
                        ord(15, r, nil, nil)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- =========================================================
-- TRANSFER
-- =========================================================
local function do_transfer(now)
    if not ui.transfer:Get() then return end
    if now - last_tr < TR_DLY then return end
    if not (hero and bear and alive(hero) and alive(bear)) then return end

    local is_tp = sc(NPC.HasModifier, hero, "modifier_teleporting")
    if is_tp then return end

    last_tr = now

    local cur = {}
    for i = 0, 5 do
        local it = sc(NPC.GetItemByIndex, hero, i)
        if it then
            local n = sc(Ability.GetName, it)
            if n then cur[n] = it end
        end
    end

    for n, it in pairs(cur) do
        if not PROT[n] and not prev_items[n] then
            hgive(it)
            break
        end
    end

    prev_items = {}
    for n in pairs(cur) do
        prev_items[n] = true
    end
end

-- =========================================================
-- AGHS LOGIC
-- =========================================================
local function do_aghs(bpos)
    if not ui.aghs_on:Get() then return false end
    if not ui.entangle:Get() then return false end

    -- 7.40: Lone Druid's new Entangle ability (slot 1) replaces old Entangling Claws cast
    -- The bear's Entangling Claws is now a passive innate on the bear
    -- We cast Lone Druid's "lone_druid_entangle" ability targeting enemies near the bear
    local ld_entangle = nil
    if hero then
        for i = 0, 5 do
            local ab = sc(NPC.GetAbilityByIndex, hero, i)
            if ab and sc(Ability.GetName, ab) == "lone_druid_entangle" then
                ld_entangle = ab
                break
            end
        end
    end

    -- Fallback: also check bear's entangle ability name (in case of version variance)
    local ab = ld_entangle or bear_ab("lone_druid_spirit_bear_entangle")
    local caster = ld_entangle and hero or bear
    local caster_mana = caster and (sc(NPC.GetMana, caster) or 0) or 0

    if not ab or not sc(Ability.IsCastable, ab, caster_mana) then
        return false
    end

    local ent_r  = ui.ent_r:Get()
    local best, bd = nil, math.huge

    for _, h in pairs(Heroes.GetAll()) do
        if h and alive(h) and h ~= hero and en(h)
        and not sc(NPC.IsIllusion, h)
        and not sc(Hero.IsClone, h) then
            local p = gp(h)
            if p then
                local d = d2(p, bpos)
                if d <= ent_r and d < bd then
                    bd = d
                    best = h
                end
            end
        end
    end

    if not best and ui.push:Get() and ui.ent_creeps:Get() then
        local list = npc_cache or NPCs.GetAll()
        for _, u in pairs(list) do
            if u and alive(u) and en(u) then
                local nm = gn(u)
                if string.find(nm, "npc_dota_creep_", 1, true) then
                    local p = gp(u)
                    if p then
                        local d = d2(p, bpos)
                        if d <= ent_r and d < bd then
                            bd   = d
                            best = u
                        end
                    end
                end
            end
        end
    end

    if best then
        -- 7.40: If using Lone Druid's Entangle (hero ability), issue via hero player order
        if ld_entangle and hero and player then
            Player.PrepareUnitOrders(player, O_CAST_T, best, nil, ab, ISSUER, hero, false)
        else
            bct(ab, best)
        end
        return true
    end

    return false
end

-- =========================================================
-- SURVIVAL / DEFENSE
-- =========================================================
local function do_defense(bpos, now)
    -- Savage Roar Save checks
    if ui.def_roar:Get() and bear and alive(bear) then
        local roar = bear_ab("lone_druid_savage_roar_bear") or bear_ab("lone_druid_savage_roar")
        local is_roar_castable = roar and sc(Ability.IsCastable, roar, sc(NPC.GetMana, bear) or 0)

        if is_roar_castable then
            local roar_triggered = false
            if hero and alive(hero) then
                local hero_pos = gp(hero)
                if hero_pos then
                    local hp_pct = (sc(Entity.GetHealth, hero) or 1) / (sc(Entity.GetMaxHealth, hero) or 1) * 100
                    local disabled = sc(NPC.HasState, hero, Enum.ModifierState.MODIFIER_STATE_STUNNED)
                        or sc(NPC.HasState, hero, Enum.ModifierState.MODIFIER_STATE_SILENCED)
                        or sc(NPC.HasState, hero, Enum.ModifierState.MODIFIER_STATE_HEXED)
                    
                    if hp_pct < 35 or disabled then
                        local enemy_near_hero, dist_hero = nearest_enemy_hero(hero_pos)
                        local enemy_near_bear, dist_bear = nearest_enemy_hero(bpos)
                        if (enemy_near_hero and dist_hero <= ROAR_R) or (enemy_near_bear and dist_bear <= ROAR_R) then
                            roar_triggered = true
                        end
                    end
                end
            end

            if not roar_triggered and ui.def_roar_allies:Get() then
                for _, ally in pairs(Heroes.GetAll()) do
                    if ally and alive(ally) and ally ~= hero and not en(ally)
                    and not sc(NPC.IsIllusion, ally) and not sc(Hero.IsClone, ally) then
                        local ap = gp(ally)
                        if ap and d2(ap, bpos) <= ROAR_R then
                            local hp_pct = (sc(Entity.GetHealth, ally) or 1) / (sc(Entity.GetMaxHealth, ally) or 1) * 100
                            local disabled = sc(NPC.HasState, ally, Enum.ModifierState.MODIFIER_STATE_STUNNED)
                                or sc(NPC.HasState, ally, Enum.ModifierState.MODIFIER_STATE_SILENCED)
                                or sc(NPC.HasState, ally, Enum.ModifierState.MODIFIER_STATE_HEXED)
                            
                            if hp_pct < 35 or disabled then
                                local enemy_near_ally, dist_ally = nearest_enemy_hero(ap)
                                if enemy_near_ally and dist_ally <= ROAR_R then
                                    roar_triggered = true
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if roar_triggered then
                set_panic("ROAR", now, 2.0)
                bcn(roar)
                def.lock_until = now + 0.12
                return true
            end
        end
    end

    if not ui.def_enable:Get() or not bear or not alive(bear) then
        return false
    end

    local hp_pct = bear_hp_pct()

    -- Берем значения из новых ползунков
    local hp_hero   = ui.def_hp_hero:Get()
    local hp_base   = ui.def_hp_base:Get()
    local hp_resume = ui.def_hp_resume:Get()

    local hero_pos = (hero and alive(hero)) and gp(hero) or nil
    local enemy, enemy_dist = nearest_enemy_hero(bpos)
    local alone  = (not hero_pos) or (d2(bpos, hero_pos) > ui.def_alone:Get())
    local ganked = enemy ~= nil and alone and enemy_dist < ui.def_gank_r:Get()

    -- 1. ЛОГИКА ВОССТАНОВЛЕНИЯ НА ФОНТАНЕ (Если включился режим хила)
    if def.heal_fountain then
        -- Если вылечились до нужного порога - отпускаем медведя фармить
        if hp_pct >= hp_resume then
            def.heal_fountain = false 
            def.reason = "SAFE"
            def.panic_until = 0
            return false 
        end

        if now < def.lock_until then return true end

        -- Во время побега или стояния на базе жмем фейзы по кулдауну
        if ui.def_phase:Get() then
            local phase = bear_item("item_phase_boots")
            if phase and sc(Ability.IsCastable, phase, 0) then
                bcn(phase)
                def.lock_until = now + 0.05
                return true
            end
        end
        
        -- Если по пути на базу встретили врага - пугаем его рыком
        if ui.def_roar:Get() and enemy and enemy_dist <= ROAR_R then
            local roar = bear_ab("lone_druid_savage_roar_bear") or bear_ab("lone_druid_savage_roar")
            if roar and sc(Ability.IsCastable, roar, sc(NPC.GetMana, bear) or 0) then
                bcn(roar)
                def.lock_until = now + 0.12
                return true
            end
        end

        def.reason = "HEALING AT BASE"
        bm(base_pos(), "def_base", false)
        return true
    end

    -- 2. ПРОВЕРКА УГРОЗ ДЛЯ АКТИВАЦИИ ЗАЩИТЫ
    local critical_hp = hp_pct <= hp_base
    local low_hp      = hp_pct <= hp_hero

    if not low_hp and not critical_hp and not ganked and not panic_active(now) then
        return false
    end

    if critical_hp then
        def.heal_fountain = true -- Врубаем режим принудительного хила до фулла
        set_panic("CRITICAL HP -> BASE", now, 3.0)
    elseif low_hp then
        set_panic("LOW HP -> HERO", now, 2.0)
    elseif ganked then
        set_panic("GANKED", now, 2.5)
    end

    if now < def.lock_until then return true end

    -- 3. СПАСАТЕЛЬНЫЕ АБИЛКИ
    if ui.def_roar:Get() and enemy and enemy_dist <= ROAR_R then
        local roar = bear_ab("lone_druid_savage_roar_bear") or bear_ab("lone_druid_savage_roar")
        if roar and sc(Ability.IsCastable, roar, sc(NPC.GetMana, bear) or 0) then
            set_panic("ROAR", now, 2.0)
            bcn(roar)
            def.lock_until = now + 0.12
            return true
        end
    end

    local ret = bear_ab("lone_druid_spirit_bear_return")
    if (critical_hp or low_hp or ganked) and ret and sc(Ability.IsCastable, ret, sc(NPC.GetMana, bear) or 0) then
        -- Если медведь далеко от героя, юзаем Return (к герою безопаснее)
        if hero_pos and d2(bpos, hero_pos) > 1200 then
            set_panic("RETURN", now, 3.0)
            bcn(ret)
            def.lock_until = now + 0.12
            return true
        end
    end

    if ui.def_phase:Get() then
        local phase = bear_item("item_phase_boots")
        if phase and sc(Ability.IsCastable, phase, 0) then
            set_panic("PHASE RUN", now, 2.0)
            bcn(phase)
            def.lock_until = now + 0.05
            return true
        end
    end

    -- 4. МАРШРУТ ПОБЕГА
    if critical_hp or def.heal_fountain then
        bm(base_pos(), "def_base", false) -- Если 20% -> на базу
    elseif (low_hp or def.reason == "ROAR" or def.reason == "LOW HP -> HERO") and hero_pos then
        bm(hero_pos, "def_hero", false)   -- Если 50% или спасение -> к герою
    else
        bm(base_pos(), "def_base", false)
    end

    return true
end

-- =========================================================
-- ADVANCED FARM LOGIC
-- =========================================================
local function find_best_neutral(center, radius, bpos)
    local best_target = nil
    local best_score = -99999
    local count = 0

    local avg_dmg = get_bear_damage()
    local bear_range = (sc(NPC.GetAttackRange, bear) or 150) + (sc(NPC.GetAttackRangeBonus, bear) or 0)
    local skip_ancients = not ui.farm_ancients:Get() or not is_strong_enough_for_ancients()

    if neutral_cache then
        for _, e in ipairs(neutral_cache) do
            local d = d2(e.pos, center)
            if d <= radius then
                local u = e.unit
                local is_anc = sc(NPC.IsAncient, u) == true
                if not (is_anc and skip_ancients) then
                    count = count + 1
                    local hp = sc(Entity.GetHealth, u) or 1
                    local dist_to_bear = d2(e.pos, bpos)
                    
                    local score = -hp - (dist_to_bear * 0.5)
                    
                    if ui.farm_lasthit:Get() and dist_to_bear <= (bear_range + 200) then
                        local mult = sc(NPC.GetArmorDamageMultiplier, u) or 1
                        local real_dmg = avg_dmg * mult
                        if hp <= real_dmg then
                            score = score + 10000
                        end
                    end
                    
                    if score > best_score then
                        best_score = score
                        best_target = u
                    end
                end
            end
        end
    end

    return best_target, count
end

local function next_camp(bpos, now, skip)
    local best_pos, best_id, best_dist = nil, nil, math.huge
    local _, min, sec = game_min_sec()
    local hero_pos = hero and alive(hero) and gp(hero)
    local has_ag = has_aghs()
    local skip_ancients = not ui.farm_ancients:Get() or not is_strong_enough_for_ancients()

    for _, c in ipairs(CAMPS) do
        if c.id ~= skip then
            local cleared_min = fc[c.id] or -1
            if cleared_min < min or sec >= 59 then
                local eligible = true
                if not has_ag and hero_pos then
                    if d2(c.p, hero_pos) > 1000 then
                        eligible = false
                    end
                end
                if eligible and skip_ancients then
                    local is_ancient_camp = (c.id == 4 or c.id == 20 or c.id == 21 or c.id == 27 or c.id == 28)
                    if is_ancient_camp then
                        eligible = false
                    end
                end

                if eligible then
                    local d = d2(c.p, bpos)
                    if d < best_dist then
                        best_dist = d
                        best_pos  = c.p
                        best_id   = c.id
                    end
                end
            end
        end
    end

    if best_pos then
        camp_id    = best_id
        camp_pos   = best_pos
        had_mob    = false
        arrived_t  = -999
        cleared_t  = -999
        last_mov_t = -999
        
        if ui.def_phase:Get() then
            local phase = bear_item("item_phase_boots")
            if phase and sc(Ability.IsCastable, phase, 0) then
                bcn(phase)
            end
        end
        
        bm(best_pos, "farm_path", true)
    else
        camp_id  = nil
        camp_pos = nil
    end
end

local function do_farm(bpos, now)
    if entangle_cast_this_tick then return end

    -- 0. Disarm & separation awareness
    if not has_aghs() and hero and alive(hero) then
        local hp = gp(hero)
        if hp then
            if d2(bpos, hp) > 1050 or (camp_pos and d2(camp_pos, hp) > 1100) then
                bm(hp, "farm_disarm_safety", false)
                return
            end
        end
    end

    -- 0.1 Auto-rune snatching
    if do_runes(bpos) then return end

    local search_radius = ui.farm_radius:Get() or 800
    local tgt, cnt = find_best_neutral(bpos, search_radius, bpos)
    local _, min, sec = game_min_sec()

    -- 1. ЕСЛИ ВИДИМ МОБОВ — АТАКУЕМ
    if cnt > 0 and tgt then
        if not had_mob then
            had_mob   = true
            cleared_t = -999
            arrived_t = -999
        end
        last_seen_mob_pos = gp(tgt) -- Запоминаем позицию
        ba(tgt)
        return
    end

    -- 2. МОБОВ НЕТ (Убили или ушли в тень)
    if had_mob then
        if cleared_t < 0 then cleared_t = now end
        
        -- УВЕЛИЧИВАЕМ ТАЙМАУТ ДО 4.0 СЕКУНД (чтобы медведь успел забежать в тень за мобом)
        if (now - cleared_t) < 4.0 then
            -- Делаем Attack-Move туда, где моба видели последний раз
            if (now - last_mov_t) >= MOV_RPT then
                bam(last_seen_mob_pos or camp_pos)
                last_mov_t = now
            end
            return
        end

        -- Если прошло 4 секунды и никого не нашли — точно зачистили
        local old = camp_id
        if old then fc[old] = min end
        reset_farm_state()
        next_camp(bpos, now, old)
        return
    end

    -- 3. НЕТ АКТИВНОГО КЕМПА — ИЩЕМ
    if not camp_pos then
        next_camp(bpos, now, nil)
        return
    end

    local dist = d2(bpos, camp_pos)

    -- 4. В ПУТИ К КЕМПУ
    if dist > WALK_R then
        if (now - last_mov_t) >= MOV_RPT then
            -- Если скоро спавн крипов (53-59 сек) и мы близко к кемпу (чтобы не заблочить спавн)
            if sec >= 53 and sec <= 59 and dist < 450 then
                -- Останавливаем медведя на краю кемпа, чтобы не заблокировать спавн!
                bm(bpos, "farm_hold_for_spawn", false) 
            else
                bm(camp_pos, "farm_path", true)
                -- Жмем фейзы в пути
                if ui.def_phase:Get() then
                    local phase = bear_item("item_phase_boots")
                    if phase and sc(Ability.IsCastable, phase, 0) then bcn(phase) end
                end
            end
            last_mov_t = now
        end
        return
    end

    -- 5. ПРИБЫЛИ В КЕМП, А ОН ПУСТОЙ
    if arrived_t < 0 then arrived_t = now end

    -- Если сейчас 53-59 секунда, мы не уходим! Ждем спавна мобов на 00:00.
    if sec >= 53 and sec <= 59 then
        -- Немного отходим к краю кемпа, чтобы не заблочить точку спавна своим телом
        if dist < 300 and (now - last_mov_t) >= MOV_RPT then
            local dir = (bpos - camp_pos):Normalized()
            local wait_pos = camp_pos + (dir * 450)
            bm(wait_pos, "farm_wait_spawn", false)
            last_mov_t = now
        end
        return
    end

    -- Sweep-механика (поиск по кругу)
    -- Вместо того чтобы стоять на месте 8 секунд, медведь делает микро-движения по кемпу, 
    -- чтобы развеять туман войны (иногда мобы прячутся за деревьями)
    if (now - last_mov_t) >= 1.5 then
        local sweep_angle = math.random() * math.pi * 2
        local sweep_pos = camp_pos + Vector(math.cos(sweep_angle)*300, math.sin(sweep_angle)*300, 0)
        bam(sweep_pos) -- Используем Attack-Move, чтобы сразу сагрить, если увидим
        last_mov_t = now
    end

    -- Если прошло 4 секунды (снизили с 8) и мобов 100% нет — идем на некст кемп
    if (now - arrived_t) >= 4.0 then
        local old = camp_id
        if old then 
            fc[old] = min -- Помечаем зачищенным на текущей минуте
        end
        reset_farm_state()
        next_camp(bpos, now, old)
    end
end

-- =========================================================
-- PUSH
-- =========================================================
local function do_push(bpos)
    if entangle_cast_this_tick then return end

    -- 0. Disarm & separation awareness
    if not has_aghs() and hero and alive(hero) then
        local hp = gp(hero)
        if hp and d2(bpos, hp) > 1050 then
            bm(hp, "push_disarm_safety", false)
            return
        end
    end

    -- 0.1 Auto-rune snatching
    if do_runes(bpos) then return end

    local list = npc_cache or NPCs.GetAll()

    local best_creep = nil
    local best_score = -99999
    local avg_dmg = get_bear_damage()
    local bear_range = (sc(NPC.GetAttackRange, bear) or 150) + (sc(NPC.GetAttackRangeBonus, bear) or 0)

    for _, u in pairs(list) do
        if u and alive(u) and en(u) then
            local name = gn(u)
            if string.find(name, "npc_dota_creep_", 1, true) then
                local p = gp(u)
                if p then
                    local d = d2(p, bpos)
                    local score = 0
                    
                    if ui.push_priorities:Get() then
                        if string.find(name, "ranged", 1, true) or string.find(name, "flagbearer", 1, true) then
                            score = score + 50
                        elseif string.find(name, "melee", 1, true) then
                            score = score + 20
                        elseif string.find(name, "siege", 1, true) then
                            score = score + 10
                        end
                    end
                    
                    score = score - (d * 0.1)
                    
                    local hp = sc(Entity.GetHealth, u) or 1
                    if ui.push_lasthit:Get() and d <= (bear_range + 200) then
                        local mult = sc(NPC.GetArmorDamageMultiplier, u) or 1
                        local real_dmg = avg_dmg * mult
                        if hp <= real_dmg then
                            score = score + 5000
                        end
                    end
                    
                    if score > best_score then
                        best_score = score
                        best_creep = u
                    end
                end
            end
        end
    end
    if best_creep then
        ba(best_creep)
        return
    end

    local best_tower, best_tower_dist = nil, math.huge
    for _, t in pairs(Towers.GetAll()) do
        if t and alive(t) and en(t) and not sc(NPC.IsInvulnerable, t) then
            local p = gp(t)
            if p then
                local d = d2(p, bpos)
                if d < best_tower_dist then
                    best_tower_dist = d
                    best_tower = t
                end
            end
        end
    end

    if best_tower then
        local tp = gp(best_tower)
        if tp then
            local min = ui.tower_lvl:Get()
            if min > 0 and hlvl() >= min then
                -- Backdoor protection / Creep check
                if friendly_creep_near(tp, 900) then
                    ba(best_tower)
                else
                    local fallback_pos = gp(hero)
                    local nearest_creep = find_nearest_friendly_creep(bpos)
                    if nearest_creep then fallback_pos = gp(nearest_creep) end
                    bm(fallback_pos or tp, "push_backdoor_safety", false)
                end
            else
                bm(tp, "push_tower", true)
            end
        end
    end
end

-- =========================================================
-- STACK
-- =========================================================
local function next_stack_camp(bpos)
    local best, bd = nil, math.huge
    for _, c in ipairs(STACK_CAMPS) do
        local _, cnt = find_neutrals(c.camp, 600)
        if cnt > 0 then
            local d = d2(bpos, c.camp)
            if d < bd then
                bd   = d
                best = c
            end
        end
    end
    return best
end

local function can_use_independent_modes()
    if not ui.only_aghs:Get() then return true end
    return has_aghs()
end

local function do_stack(bpos)
    if not ui.stack_enable:Get() then
        reset_stack_state()
        return false
    end

    if not bear or not alive(bear) then
        reset_stack_state()
        return false
    end

    local now, minute, sec = game_min_sec()

    if st.last_minute == minute and st.phase == "done" then
        return false
    end

    if st.last_minute ~= minute then
        st.phase           = "idle"
        st.hit_confirmed   = false
        st.pull_issued     = false
        st.approach_issued = false
        st.aggro_time      = 0
        st.last_move_time  = 0
    end

    local bear_speed = sc(NPC.GetMovementSpeed, bear) or 300
    local base_aggro = ui.stack_aggro_sec:Get()

    if not st.camp_pos or st.phase == "idle" then
        local c = next_stack_camp(bpos)
        if not c then return false end
        st.camp_id       = c.id
        st.camp_pos      = c.camp
        st.pull_pos      = c.pull
        st.strike_center = find_strike_center(c.camp)
    end

    local dist_to_camp = d2(bpos, st.camp_pos)

    local travel_time  = dist_to_camp / math.max(bear_speed, 100)
    local approach_sec = base_aggro - math.ceil(travel_time) - 3
    approach_sec = math.max(approach_sec, 35)
    approach_sec = math.min(approach_sec, base_aggro - 5)

    if sec < approach_sec then
        return false
    end

    if sec >= approach_sec and sec < base_aggro and not st.pull_issued then
        st.active = true
        st.phase  = "approach"

        if dist_to_camp > 200 then
            if not st.approach_issued or (now - st.last_move_time) > 1.0 then
                st.approach_issued = true
                st.last_move_time  = now
                bm_force(st.camp_pos, "stack_approach")
            end
            return true
        end

        st.phase = "wait"
        return true
    end

    if st.phase == "wait" and sec < base_aggro then
        st.active = true
        if dist_to_camp > 300 then
            bm_force(st.camp_pos, "stack_wait_return")
        end
        return true
    end

    if sec >= base_aggro and sec < base_aggro + 4 and not st.pull_issued then
        st.active = true
        st.phase  = "aggro"

        if st.aggro_time == 0 then
            st.aggro_time = now
        end

        local search_center = st.strike_center or st.camp_pos
        local tgt, cnt = find_neutrals(search_center, ui.stack_range:Get())

        if tgt then
            -- Запоминаем, где видели моба перед тем, как он ушел в тень
            last_seen_mob_pos = gp(tgt)
            ba(tgt) -- Важно: используем ba(tgt), а не ba_force, чтобы избежать микро-станов медведя от спама кликов
        else
            -- Если моб пропал в тени, делаем Attack-Move на его последнюю позицию
            if (now - st.last_move_time) > 0.8 then
                bam(last_seen_mob_pos or search_center)
                st.last_move_time = now
            end
        end

        if hum_last_tgt and alive(hum_last_tgt) and sc(NPC.IsAttacking, bear) then
            local time_in_aggro = now - st.aggro_time
            if time_in_aggro >= 0.8 then
                st.hit_confirmed = true
            end
        end

        local time_in_aggro = now - st.aggro_time

        if st.hit_confirmed or time_in_aggro >= 1.5 then
            st.phase       = "pull"
            st.pull_issued = true
            st.last_move_time = now
            bm_force(st.pull_pos, "stack_pull")
        end

        return true
    end

    if st.pull_issued and st.phase ~= "done" then
        st.active = true
        st.phase  = "pull"

        local dist_to_pull = d2(bpos, st.pull_pos)
        if dist_to_pull > 150 and (now - st.last_move_time) > 0.8 then
            st.last_move_time = now
            bm_force(st.pull_pos, "stack_pull")
        end

        if sec >= 59 or sec < 5 then
            st.phase       = "done"
            st.last_minute = minute
            st.active      = false
            st.hit_confirmed   = false
            st.pull_issued     = false
            st.approach_issued = false
            st.aggro_time      = 0
            st.last_move_time  = 0
        end

        return true
    end

    if sec >= base_aggro + 4 and not st.pull_issued then
        st.pull_issued    = true
        st.phase          = "pull"
        st.last_move_time = now
        bm_force(st.pull_pos, "stack_pull_fallback")
        return true
    end

    return false
end

local function set_mirror_target(tgt, now)
    if not tgt or not alive(tgt) then return false end
    if not en(tgt) then return false end
    mirror_tgt = tgt
    mirror_tgt_set = now or GameRules.GetGameTime()
    return true
end

local function sync_mirror_target(now)
    if not ui.mirror_on:Get() then
        mirror_tgt = nil
        return
    end

    if not hero or not alive(hero) then
        mirror_tgt = nil
        return
    end

    -- If target is dead/dormant/invalid, clear it
    if mirror_tgt and (not alive(mirror_tgt) or not en(mirror_tgt)) then
        mirror_tgt = nil
        return
    end

    -- If the target was set too long ago (e.g. 3.5s of no manual clicks or successful attack hits), clear it
    if mirror_tgt and (now - mirror_tgt_set) > 3.5 then
        mirror_tgt = nil
    end
end

-- =========================================================
-- OnEntityHurt
-- =========================================================
function ld.OnEntityHurt(data)
    if not ui.on:Get() then return end
    if not data then return end

    -- Stacking logic
    if ui.stack_enable:Get() and data.source == bear then
        if st.phase == "aggro" and not st.pull_issued then
            st.hit_confirmed  = true
            st.phase          = "pull"
            st.pull_issued    = true
            st.last_move_time = GameRules.GetGameTime()

            if st.pull_pos and bear and alive(bear) then
                hum_now = GameRules.GetGameTime()
                bm_force(st.pull_pos, "stack_pull_onhit")
            end
        end
    end

    -- Mirror target tracking from hero auto-attacks/hits
    if ui.mirror_on:Get() and hero and data.source == hero and not data.ability then
        local tgt = data.target
        if tgt and alive(tgt) and en(tgt) then
            set_mirror_target(tgt)
        end
    end
end


-- =========================================================
-- MIRROR ATTACK (Bear attacks hero's current target)
-- Relies on OnPrepareUnitOrders to capture the hero's attack target.
-- =========================================================
local function do_mirror_attack(bpos)
    if not ui.mirror_on:Get() then return false end
    if not hero or not alive(hero) then return false end
    if not bear or not alive(bear) then return false end
    local now = GameRules.GetGameTime()

    sync_mirror_target(now)

    -- Optionally only active in Follow mode
    if ui.mirror_only_follow:Get() then
        if not (ui.follow:Get() and not ui.farm:Get() and not ui.push:Get()) then
            return false
        end
    end

    -- Validate stored target
    if not mirror_tgt or not alive(mirror_tgt) then
        mirror_tgt = nil
        return false
    end

    if not en(mirror_tgt) then
        mirror_tgt = nil
        return false
    end

    if (now - mirror_tgt_set) > 3.5 then
        mirror_tgt = nil
        return false
    end

    -- Check distance from hero to target
    local hp = gp(hero)
    local tgt_pos = gp(mirror_tgt)
    if not hp or not tgt_pos then return false end
    if d2(hp, tgt_pos) > ui.mirror_r:Get() then
        mirror_tgt = nil
        return false
    end

    -- Check distance from bear to target
    if d2(bpos, tgt_pos) > ui.mirror_r:Get() then return false end


    -- Don't spam: check if bear is already attacking this target
    if hum_last_tgt == mirror_tgt then
        if sc(NPC.IsAttacking, bear) or (now - hum_last_atk) < 1.5 then
            return true
        end
    end

    -- Auto-Phase Boots in chase
    if ui.def_phase:Get() then
        local phase = bear_item("item_phase_boots")
        if phase and sc(Ability.IsCastable, phase, 0) then
            bcn(phase)
        end
    end

    ba_force(mirror_tgt)
    return true
end

-- =========================================================
-- CORE
-- =========================================================
local function on_tick(now)
    npc_cache = NPCs.GetAll()
    build_neutral_cache()
    entangle_cast_this_tick = false
    sync_mirror_target(now)

    if not bear or not alive(bear) then
        reset_hum_state()
        reset_def_state()
        npc_cache = nil
        neutral_cache = nil
        return
    end

    local bpos = gp(bear)
    if not bpos then
        reset_hum_move()
        npc_cache = nil
        neutral_cache = nil
        return
    end

    -- Premium HUD: Tower aggro drop
    if juggle_tower_aggro(bpos) then
        npc_cache = nil
        neutral_cache = nil
        return
    end

    -- Premium HUD: Auto-Midas
    if do_midas(bpos) then
        npc_cache = nil
        neutral_cache = nil
        return
    end

    local aghs = has_aghs()

    if aghs then
        entangle_cast_this_tick = do_aghs(bpos)
    end

    if ui.push:Get() then
        if not can_use_independent_modes() then
            npc_cache = nil
            neutral_cache = nil
            return
        end

        if ui.stack_push:Get() and do_stack(bpos) then
            reset_farm_state()
            npc_cache = nil
            neutral_cache = nil
            return
        end

        reset_farm_state()
        -- Mirror attack has priority over push AI when hero is actively attacking
        if not do_mirror_attack(bpos) then
            do_push(bpos)
        end

    elseif ui.farm:Get() then
        if not can_use_independent_modes() then
            npc_cache = nil
            neutral_cache = nil
            return
        end

        if ui.stack_farm:Get() and do_stack(bpos) then
            npc_cache = nil
            neutral_cache = nil
            return
        end

        -- Mirror attack overrides farm when hero is fighting
        if not do_mirror_attack(bpos) then
            do_farm(bpos, now)
        end

    elseif ui.follow:Get() then
        reset_farm_state()
        reset_stack_state()

        -- Auto-rune snatching in follow mode
        if do_runes(bpos) then
            npc_cache = nil
            neutral_cache = nil
            return
        end

        -- Mirror attack takes priority over following
        if not do_mirror_attack(bpos) then
            if hero then
                local hp = gp(hero)
                if hp then
                    local dist = d2(bpos, hp)
                    local is_hero_invis = is_invisible(hero)
                    
                    if ui.def_invis_safety:Get() and is_hero_invis then
                        if dist > 1200 then
                            hum_follow_active = true
                        elseif dist <= 800 then
                            hum_follow_active = false
                        end
                        if hum_follow_active and not entangle_cast_this_tick then
                            if ui.def_phase:Get() then
                                local phase = bear_item("item_phase_boots")
                                if phase and sc(Ability.IsCastable, phase, 0) then
                                    bcn(phase)
                                end
                            end
                            bm(hp, "follow_invis_catchup", false)
                            invis_stop_issued = false
                        else
                            if not invis_stop_issued then
                                ord(Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION, nil, nil, nil)
                                invis_stop_issued = true
                            end
                        end
                    else
                        invis_stop_issued = false
                        if dist > FOL_START then
                            hum_follow_active = true
                        elseif dist < FOL_STOP then
                            hum_follow_active = false
                        end
                        if hum_follow_active and not entangle_cast_this_tick then
                            bm(hp, "follow_move", false)
                        end
                    end
                end
            end
        end
    else
        reset_farm_state()
        reset_stack_state()
    end

    npc_cache = nil
    neutral_cache = nil
end

-- =========================================================
-- BINDS
-- =========================================================
local function check_binds()
    local t = ui.k_toggle:IsPressed()
    if t and not bind_prev.toggle then
        ui.on:Set(not ui.on:Get())
    end
    bind_prev.toggle = t

    local p = ui.k_push:IsPressed()
    if p and not bind_prev.push then
        local v = not ui.push:Get()
        ui.push:Set(v)
        if v then ui.farm:Set(false) end
    end
    bind_prev.push = p

    local f = ui.k_farm:IsPressed()
    if f and not bind_prev.farm then
        local v = not ui.farm:Get()
        ui.farm:Set(v)
        if v then ui.push:Set(false) end
    end
    bind_prev.farm = f
end

-- =========================================================
-- FRAME
-- =========================================================
function ld.OnFrame()
    if not ui.on:Get() then return end
    if not hero or not alive(hero) then return end

    local mx, my = get_cursor()
    local is_down = is_lmb_down()

    -- Update UI animations
    local dt = GlobalVars.GetAbsFrameTime() or 0.016
    if dt <= 0 or dt > 0.1 then
        dt = 0.016
    end
    UpdateUIAnimations(dt, mx, my)

    -- =====================================================
    -- ОБНОВЛЕННАЯ СИСТЕМА ПЕРЕТАСКИВАНИЯ (БЕЗОПАСНАЯ)
    -- =====================================================
    if ui.drag_mode:Get() then
        local scale = (Menu.Scale() or 100) / 100
        local W = BEAR_PANEL_W * scale
        local H = BEAR_PANEL_H * scale
        local currentHeight = (30 * scale) + (H - 30 * scale) * UIState.HeightProgress

        if is_down and not drag_state.was_down then
            -- Проверка клика по основной панели
            if ui.show_panel:Get() then
                local px, py = ui.panel_x:Get(), ui.panel_y:Get()
                if mx and my and is_mouse_in_rect(mx, my, px, py, W, currentHeight) then
                    drag_state.main_active = true
                    drag_state.main_dx = mx - px
                    drag_state.main_dy = my - py
                end
            end

            -- Проверка клика по панели Warning
            local show_warn = ui.show_warning:Get() 
                and (ui.push:Get() or ui.farm:Get()) 
                and ui.only_aghs:Get() 
                and not has_aghs()

            if show_warn then
                local wx, wy = ui.aghs_x:Get(), ui.aghs_y:Get()
                local sw = 360 * scale
                local sh = 78 * scale
                if mx and my and is_mouse_in_rect(mx, my, wx, wy, sw, sh) then
                    drag_state.aghs_active = true
                    drag_state.aghs_dx = mx - wx
                    drag_state.aghs_dy = my - wy
                end
            end

        elseif not is_down then
            -- Кнопку отпустили — сбрасываем захват
            drag_state.main_active = false
            drag_state.aghs_active = false
        end

        -- Если панель захвачена, обновляем ее координаты в слайдере с учетом смещения
        if drag_state.main_active and mx and my then
            ui.panel_x:Set(math.max(0, math.floor(mx - drag_state.main_dx)))
            ui.panel_y:Set(math.max(0, math.floor(my - drag_state.main_dy)))
        end

        if drag_state.aghs_active and mx and my then
            ui.aghs_x:Set(math.max(0, math.floor(mx - drag_state.aghs_dx)))
            ui.aghs_y:Set(math.max(0, math.floor(my - drag_state.aghs_dy)))
        end

        drag_state.was_down = is_down
    else
        -- Защита от залипания, если выключили тумблер во время перетаскивания
        drag_state.main_active = false
        drag_state.aghs_active = false
        drag_state.was_down = false
    end
    -- =====================================================

    -- =====================================================
    -- ИНТЕРАКТИВНЫЕ КНОПКИ ПАНЕЛИ
    -- =====================================================
    local clicked = is_down and not click_state.was_down
    click_state.was_down = is_down

    if clicked and not ui.drag_mode:Get() and mx and my then
        if ui.show_panel:Get() then
            local scale = (Menu.Scale() or 100) / 100
            local px, py = ui.panel_x:Get(), ui.panel_y:Get()
            local W = BEAR_PANEL_W * scale
            
            local btnY = py + 15 * scale
            local btnR = 4.5 * scale
            
            local isOverClose = is_mouse_in_rect(mx, my, px + 15 * scale - btnR - 2*scale, py, btnR*2 + 4*scale, 30*scale)
            local isOverCollapse = is_mouse_in_rect(mx, my, px + 30 * scale - btnR - 2*scale, py, btnR*2 + 4*scale, 30*scale)
            local isOverReset = is_mouse_in_rect(mx, my, px + 45 * scale - btnR - 2*scale, py, btnR*2 + 4*scale, 30*scale)
            
            if isOverClose then
                ui.show_panel:Set(false)
            elseif isOverCollapse then
                UIState.Collapsed = not UIState.Collapsed
            elseif isOverReset then
                ui.panel_x:Set(760)
                ui.panel_y:Set(150)
            else
                if not UIState.Collapsed then
                    -- Проверка клика по кнопке FARM
                    if is_mouse_in_rect(mx, my, px + W - 108 * scale, py + 8 * scale, 46 * scale, 17 * scale) then
                        local new_val = not ui.farm:Get()
                        ui.farm:Set(new_val)
                        if new_val then ui.push:Set(false) end
                    end

                    -- Проверка клика по кнопке PUSH
                    if is_mouse_in_rect(mx, my, px + W - 56 * scale, py + 8 * scale, 46 * scale, 17 * scale) then
                        local new_val = not ui.push:Get()
                        ui.push:Set(new_val)
                        if new_val then ui.farm:Set(false) end
                    end
                end
            end
        end
    end

    -- Warning panel (only when only_aghs is ON and no aghs)
    if ui.show_warning:Get()
    and (ui.push:Get() or ui.farm:Get())
    and ui.only_aghs:Get()
    and not has_aghs() then
        local wx, wy = ui.aghs_x:Get(), ui.aghs_y:Get()

        local wlines = {
            L("Нужен Аганим для Push / Farm / Stack",
              "Aghanim needed for Push / Farm / Stack"),
            L("Переключи режим или возьми Aghanim",
              "Switch mode or obtain Aghanim Scepter"),
        }
        local wcol = {
            Color(255, 120, 120, 255),
            Color(210, 210, 210, 255),
        }

        draw_pretty_panel(wx, wy, 360, 78,
            "LONE DRUID WARNING",
            wlines, wcol, ui.drag_mode:Get())
    end

    -- Main panel
    if not ui.show_panel:Get() then return end

    local x, y      = ui.panel_x:Get(), ui.panel_y:Get()
    local mode       = mode_name()
    local aghs_ok    = has_aghs()
    local now        = GameRules.GetGameTime()
    local d_now      = panic_active(now)
    local hp_num     = nil

    if bear and alive(bear) then
        hp_num = math.floor(bear_hp_pct())
    end

    local stack_state = "OFF"
    if st.active then
        stack_state = string.upper(st.phase or "?")
    elseif ui.stack_enable:Get() then
        stack_state = L("ГОТОВ", "READY")
    end

    local cur_camp = "-"
    if st.camp_id then
        cur_camp = tostring(st.camp_id)
    elseif camp_id then
        cur_camp = tostring(camp_id)
    end

    local _, minute, sec = game_min_sec()

    local aghs_gate = ""
    if ui.only_aghs:Get() and not aghs_ok and (ui.farm:Get() or ui.push:Get()) then
        aghs_gate = "!"
    end

    draw_bear_panel(x, y, mode, aghs_ok, aghs_gate, hp_num, d_now, cur_camp, stack_state, minute, sec, ui.drag_mode:Get())

    -- Defense alert
    if ui.def_alert:Get() and d_now and Render.GetScreenSize then
        local scr = Render.GetScreenSize()
        local txt = L("ЗАЩИТА МЕДВЕДЯ: ", "BEAR DEFENSE: ")
                  .. tostring(def.reason or "PANIC")
        local sz  = Render.TextSize(font_big, 14, txt)

        local cx = math.floor((scr.x - sz.x) * 0.5)
        local cy = math.floor(scr.y * 0.18)

        Render.FilledRect(Vec2(cx - 14, cy - 8), Vec2(cx + sz.x + 14, cy + 26), Color(10, 10, 10, 190))
        Render.Rect(Vec2(cx - 14, cy - 8), Vec2(cx + sz.x + 14, cy + 26), Color(220, 70, 70, 220))
        Render.Text(font_big, 14, txt, Vec2(cx, cy), Color(255, 80, 80, 255))
    end
end

-- =========================================================
-- MAIN
-- =========================================================
function ld.OnUpdate()
    check_binds()

    if not ui.on:Get() then
        reset_farm_state()
        reset_stack_state()
        reset_hum_state()
        reset_def_state()
        return
    end

    if not hero then
        player = Players.GetLocal()
        hero   = Heroes.GetLocal()
        if not hero or not player then return end

        -- Hero check: this script is for Lone Druid only
        local hero_name = sc(NPC.GetUnitName, hero)
        if hero_name ~= "npc_dota_hero_lone_druid" then
            hero = nil  -- reset so we keep checking each tick without locking in the wrong hero
            return
        end

        init_teams()

        for i = 0, 5 do
            local it = sc(NPC.GetItemByIndex, hero, i)
            if it then
                local n = sc(Ability.GetName, it)
                if n then prev_items[n] = true end
            end
        end
        return
    end

    if not alive(hero) then
        reset_hum_state()
        reset_def_state()
        return
    end

    if not our_team then
        init_teams()
        return
    end

    refresh_bear()

    if not bear or not alive(bear) then
        reset_farm_state()
        reset_stack_state()
        reset_hum_state()
        reset_def_state()
        return
    end

    local now = GameRules.GetGameTime()
    hum_now = now

    local bpos = gp(bear)
    if bpos and do_defense(bpos, now) then
        reset_farm_state()
        if not (st.active and st.phase == "aggro") then
            reset_stack_state()
        end
        check_armlet_toggle_off()
        return
    end

    do_transfer(now)

    if hum_last_tgt and alive(hum_last_tgt) and sc(NPC.IsAttacking, bear) then
        local is_hero = sc(NPC.IsHero, hum_last_tgt) == true
        use_bear_items(hum_last_tgt, is_hero)
    else
        check_armlet_toggle_off()
    end

    if st.active and (st.phase == "aggro" or st.phase == "pull") then
        on_tick(now)
        return
    end

    if ui.hum_on:Get() then
        if now < hum_next_tick then return end
        local add = ui.hum_delay:Get() / 1000.0
        hum_next_tick = now + TICK + (math.random() * add)
    else
        if now - last_tick < TICK then return end
        last_tick = now
    end

    on_tick(now)
end


function ld.OnPrepareUnitOrders(data, player_arg, order_arg, target_arg, position_arg, ability_arg, orderIssuer_arg, npc_arg, queue_arg, showEffects_arg)
    if not ui.on:Get() then return end
    if not hero or not player then return end
    if player_arg and player_arg ~= player then return end

    -- Handle order issued to the hero
    if npc_arg == hero then
        if ui.mirror_on:Get() then
            if order_arg == O_ATTACK then
                local tgt = target_arg
                if tgt and alive(tgt) and en(tgt) then
                    set_mirror_target(tgt)
                end
            elseif order_arg == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION 
                or order_arg == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
                or order_arg == Enum.UnitOrder.DOTA_UNIT_ORDER_STOP
                or order_arg == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION then
                mirror_tgt = nil
            end
        end
    end
end

return ld