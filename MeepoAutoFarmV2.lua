--[[
╭────────────────────────────────────────────────────────────╮
│                                                            │
│               M E E P O   A U T O F A R M                  │
│                           V 2                              │
│                                                            │
│                     Script by Euphoria                     │
│                                                            │
├────────────────────────────────────────────────────────────┤
│                        By Pidaras                          │
│                           VibeCode                         │
╰────────────────────────────────────────────────────────────╯
--]]

---@diagnostic disable: undefined-global, param-type-mismatch

local MeepoJunglePack = {}

local SCRIPT_ID = "meepo_auto_farm_v2"
local ORDER_PREFIX = SCRIPT_ID .. "."
local MEEPO_NAME = "npc_dota_hero_meepo"

local O_ATTACK = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
local O_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
local ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local KEY_NONE = Enum.ButtonCode and Enum.ButtonCode.KEY_NONE or 0
local MAP_WORLD_MIN = -8800
local MAP_WORLD_MAX = 8800
local MAP_DOT_PADDING = 15
local RESPAWN_WAIT_WINDOW = 12
local RESPAWN_SAFE_WINDOW = 7
local RESPAWN_WAIT_DISTANCE = 760
local EMPTY_LOCK_EXTRA = 1.5
local ENEMY_AVOID_TIME = 12
local DEFAULT_ENEMY_RADIUS = 1800
local FAST_WAIT_WINDOW = 3.5
local STACK_PREP_WINDOW = 5.5
local BURST_POOF_MIN_CREEPS = 3
local SHRINE_MANA_THRESHOLD = 28
local SMART_MODE_COOLDOWN = 8
local PUSH_SUPPORT_RADIUS = 950
local PUSH_WAVE_RADIUS = 900
local PUSH_STRUCTURE_RADIUS = 1450
local PUSH_ICON_CANDIDATES = {
    "C:/Umbrella/images/MenuIcons/Dota/creep_cutie.png",
    "images/MenuIcons/Dota/creep_cutie.png",
}
local LANE_ORDER = {"top", "mid", "bot"}
local LANE_PATHS = {
    top = {
        Vector(-6570, 4200, 384),
        Vector(-4200, 3500, 384),
        Vector(-1800, 2200, 384),
        Vector(600, 900, 384),
        Vector(3000, -300, 384),
        Vector(5200, -3400, 384),
        Vector(6400, -5200, 384),
    },
    mid = {
        Vector(-5800, -5800, 384),
        Vector(-3200, -3200, 384),
        Vector(0, 0, 384),
        Vector(3200, 3200, 384),
        Vector(5800, 5800, 384),
    },
    bot = {
        Vector(4200, -6570, 384),
        Vector(3500, -4200, 384),
        Vector(2200, -1800, 384),
        Vector(900, 600, 384),
        Vector(-300, 3000, 384),
        Vector(-3400, 5200, 384),
        Vector(-5200, 6400, 384),
    },
}
local DOTA_ICON = {
    meepo = "panorama/images/heroes/icons/npc_dota_hero_meepo_png.vtex_c",
    ransack = "panorama/images/spellicons/meepo_ransack_png.vtex_c",
    poof = "panorama/images/spellicons/meepo_poof_png.vtex_c",
    divided = "panorama/images/spellicons/meepo_divided_we_stand_png.vtex_c",
    mega = "panorama/images/spellicons/meepo_megameepo_png.vtex_c",
    tpscroll = "panorama/images/items/tpscroll_png.vtex_c",
    blink = "panorama/images/items/blink_png.vtex_c",
    phase = "panorama/images/items/phase_boots_png.vtex_c",
}
local FA_ICON = {
    map = "\u{f279}",
    warning = "\u{f071}",
    eye = "\u{f06e}",
    bug = "\u{f188}",
    clock = "\u{f017}",
    pause = "\u{f04c}",
    expand = "\u{f065}",
    radius = "\u{f1db}",
    heart = "\u{f004}",
    radar = "\u{f1eb}",
    road = "\u{f018}",
    image = "\u{f03e}",
    anchor = "\u{f245}",
    bind = "\u{f084}",
    flask = "\u{f0c3}",
    medkit = "\u{f0f9}",
    building = "\u{f1ad}",
    cube = "\u{f1b2}",
    users = "\u{f0c0}",
}
local MAP_IMAGE_PATHS = {
    "assets/meepo_farm_minimap.png",
    "C:/Umbrella/assets/meepo_farm_minimap.png",
    "panorama/images/minimap/dotamap_psd.vtex_c",
    "panorama/images/minimap/dotamap_psd_png.vtex_c",
    "panorama/images/minimap/dotamap.vtex_c",
    "panorama/images/minimap/dotamap_png.vtex_c"
}

local function newTickCache()
    return {
        stamp = nil,
        playerId = -1,
        team = nil,
        heroId = 0,
        selectedIds = nil,
        meepos = nil,
        neutrals = nil,
        campInfos = nil,
        enemyHeroes = nil,
        alliedLaneCreeps = nil,
        enemyLaneCreeps = nil,
        pushStructures = nil
    }
end

local state = {
    lastTick = 0,
    lastOrder = {},
    lastPoof = {},
    lastTp = {},
    manualUntil = {},
    emptyUntil = {},
    campMemory = {},
    unitCamp = {},
    selectedCamps = {},
    mapCampRects = {},
    mapRects = {},
    mapOpen = false,
    mapX = 12,
    mapY = 150,
    mapDragging = false,
    mapDragOffsetX = 0,
    mapDragOffsetY = 0,
    mapBindPrev = false,
    mapMousePrev = false,
    mapBlockInputUntil = 0,
    mapImageHandle = nil,
    mapImageInput = nil,
    mapImageLoaded = false,
    mapImageRetryAt = 0,
    lastMapThemeSync = 0,
    lastLanguage = nil,
    languageWidget = nil,
    languageLookupAt = 0,
    languageCallbackSet = false,
    comboKeyWidget = nil,
    comboKeyLookupAt = 0,
    enemyAvoid = {},
    localHero = nil,
    statusById = {},
    statusList = {},
    debugInfo = {title = "", lines = {}},
    activeGroups = {},
    lastMode = "",
    farmBindPrev = false,
    pushBindPrev = false,
    smartModeSwitchAt = 0,
    unitFightCamp = {},
    tickCache = newTickCache(),
    mapCamps = nil,
    mapCampsAncients = nil
}

local function sc(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function now()
    return sc(GameRules.GetGameTime) or os.clock()
end

local function dotaClock()
    local dota = sc(GameRules.GetDOTATime, false, true)
    if type(dota) == "number" then return dota end

    local gameNow = now()
    local startTime = sc(GameRules.GetGameStartTime) or 0
    return gameNow - startTime
end

local function secondsToNextMinute()
    local clock = math.max(0, dotaClock())
    local second = clock % 60
    local left = 60 - second
    if left <= 0.05 then return 60 end
    return left
end

local function widgetGet(widget, fallback)
    if not widget or type(widget.Get) ~= "function" then return fallback end
    local value = sc(widget.Get, widget)
    if value == nil then return fallback end
    return value
end

local function languageWidget()
    local t = os.clock()
    if state.languageWidget and t < (state.languageLookupAt or 0) then
        return state.languageWidget
    end

    state.languageLookupAt = t + 1.0
    state.languageWidget = Menu and Menu.Find and sc(Menu.Find, "SettingsHidden", "", "", "", "Main", "Language") or nil
    return state.languageWidget
end

local function languageCode()
    local value = widgetGet(languageWidget(), "en")

    if type(value) == "number" then
        if value == 1 then return "ru" end
        if value == 2 then return "cn" end
        return "en"
    end

    value = tostring(value or "en"):lower()
    if value == "ru" or value:find("рус", 1, true) or value:find("russian", 1, true) then return "ru" end
    if value == "cn"
        or value == "zh"
        or value:find("китай", 1, true)
        or value:find("chinese", 1, true)
        or value:find("中文", 1, true)
        or value:find("中国", 1, true)
        or value:find("中國", 1, true)
        or value:find("简体", 1, true) then return "cn" end
    return "en"
end

local locale = {
    tab = {en = "AutoFarm V2", ru = "Автофарм V2", cn = "自动刷野 V2"},
    group_main = {en = "Control", ru = "Управление", cn = "控制"},
    group_farm = {en = "Farm", ru = "Фарм", cn = "刷野"},
    group_push = {en = "Push", ru = "Пуш", cn = "推线"},

    ui_enable = {en = "Enable", ru = "Включить", cn = "启用"},
    ui_farm = {en = "Farm", ru = "Фарм", cn = "刷野"},
    ui_farm_key = {en = "Farm Key", ru = "Бинд фарма", cn = "刷野按键"},
    ui_push_key = {en = "Push Key", ru = "Бинд пуша", cn = "推线按键"},
    ui_map = {en = "Map", ru = "Карта", cn = "地图"},
    ui_order_delay = {en = "Order delay", ru = "Задержка ордеров", cn = "指令延迟"},
    ui_manual_pause = {en = "Manual pause", ru = "Ручная пауза", cn = "手动暂停"},
    ui_farmers = {en = "Farmers", ru = "Фармеры", cn = "刷野单位"},
    ui_poof = {en = "Poof", ru = "Пуф", cn = "忽悠"},
    ui_auto_push = {en = "Auto Push", ru = "Авто-пуш", cn = "自动推线"},
    ui_save_mana = {en = "Save Mana", ru = "Сохранять ману", cn = "保留魔法"},
    ui_join_radius = {en = "Pack join radius", ru = "Радиус сбора", cn = "编队集合范围"},
    ui_camp_radius = {en = "Camp creep radius", ru = "Радиус кемпа", cn = "野点判定范围"},
    ui_ancients = {en = "Ancients", ru = "Древние", cn = "远古"},
    ui_avoid_enemies = {en = "Avoid Enemies", ru = "Избегать врагов", cn = "躲避敌人"},
    ui_enemy_radius = {en = "Enemy avoid radius", ru = "Радиус опасности", cn = "敌人躲避范围"},
    ui_tp_fallback = {en = "TP fallback", ru = "TP fallback", cn = "传送保底"},
    ui_low_hp = {en = "Low HP Retreat", ru = "Отход по HP", cn = "低血撤退"},
    ui_retreat_hp = {en = "Retreat HP", ru = "HP отхода", cn = "撤退血量"},
    ui_poof_distance = {en = "Poof move distance", ru = "Дистанция пуфа", cn = "忽悠移动距离"},
    ui_poof_delay = {en = "Poof retry delay", ru = "Задержка пуфа", cn = "忽悠重试延迟"},
    ui_status = {en = "Portrait Status", ru = "Статус портретов", cn = "头像状态"},
    ui_debug = {en = "Debug Overlay", ru = "Debug Overlay", cn = "调试面板"},
    ui_map_image = {en = "Map image path", ru = "Путь к карте", cn = "地图图片路径"},
    ui_status_auto = {en = "Auto Portrait Anchor", ru = "Автопривязка к портретам", cn = "头像自动锚定"},
    ui_map_groups = {en = "Map Group Markers", ru = "Маркеры групп на карте", cn = "地图组标记"},
    ui_push_structures = {en = "Structures", ru = "Строения", cn = "建筑"},
    ui_push_support_radius = {en = "Support radius", ru = "Радиус поддержки", cn = "支援半径"},
    ui_push_wave_radius = {en = "Wave scan radius", ru = "Радиус линии", cn = "兵线扫描半径"},
    ui_push_structure_radius = {en = "Structure scan radius", ru = "Радиус строений", cn = "建筑扫描半径"},
    ui_push_maphack = {en = "Maphack lanes", ru = "Maphack линий", cn = "推线地图挂"},
    ui_push_maphack_memory = {en = "Maphack memory", ru = "Память maphack", cn = "地图挂记忆"},
    ui_maphack_avoid = {en = "Maphack avoid", ru = "Maphack избегание", cn = "地图挂躲避"},
    ui_flex_groups = {en = "Flexible groups", ru = "Гибкие группы", cn = "灵活编队"},
    ui_group_min = {en = "Min group size", ru = "Мин. размер", cn = "最小编队"},
    ui_group_max = {en = "Max group size", ru = "Макс. размер", cn = "最大编队"},
    ui_stack_prep = {en = "Stack prep timing", ru = "Тайминг стака", cn = "拉野时机"},
    ui_burst_poof = {en = "Burst Poof", ru = "Burst Poof", cn = "爆发忽悠"},
    ui_burst_creeps = {en = "Burst creep count", ru = "Крипов для burst", cn = "爆发怪数"},
    ui_smart_mode = {en = "Smart mode", ru = "Умный режим", cn = "智能模式"},
    ui_smart_reserve = {en = "Smart reserve", ru = "Умный резерв", cn = "智能备用"},
    ui_push_tower_safe = {en = "Tower safe", ru = "Безопасность башен", cn = "塔下安全"},
    ui_status_vitals = {en = "Status HP/MP", ru = "HP/MP в статусе", cn = "状态血量蓝量"},
    ui_order_jitter = {en = "Order jitter", ru = "Разброс ордеров", cn = "指令抖动"},
    ui_path_check = {en = "Path check", ru = "Проверка пути", cn = "路径检查"},
    ui_use_mobility = {en = "Mobility items", ru = "Мобильность", cn = "位移物品"},
    ui_shrine_mana = {en = "Low mana to base", ru = "На базу по мане", cn = "低蓝回基地"},
    ui_megameepo_hold = {en = "Mega hold", ru = "Удержание Mega", cn = "超级米波集结"},
    ui_map_awareness = {en = "Map enemy dots", ru = "Враги на карте", cn = "地图敌人点"},
    ui_debug_x = {en = "Debug X", ru = "Debug X", cn = "调试 X"},
    ui_debug_y = {en = "Debug Y", ru = "Debug Y", cn = "调试 Y"},
    ui_status_x = {en = "Status X", ru = "Статус X", cn = "状态 X"},
    ui_status_y = {en = "Status Y", ru = "Статус Y", cn = "状态 Y"},
    ui_status_gap = {en = "Status row gap", ru = "Шаг статусов", cn = "状态行距"},

    gear_script = {en = "Timing", ru = "Тайминги", cn = "时序"},
    gear_hud = {en = "HUD", ru = "Интерфейс", cn = "界面"},
    gear_camps = {en = "Camps", ru = "Кемпы", cn = "野点"},
    gear_poof = {en = "Poof", ru = "Пуф", cn = "忽悠"},
    gear_safety = {en = "Safety", ru = "Защита", cn = "安全"},
    gear_push = {en = "Radii", ru = "Радиусы", cn = "范围"},

    farmer_any_unselected = {en = "Any Unselected Meepo", ru = "Любой невыбранный Meepo", cn = "任意未选中米波"},
    farmer_unselected_clones = {en = "Unselected Clones", ru = "Невыбранные клоны", cn = "未选中克隆"},
    farmer_all = {en = "All Meepo", ru = "Все Meepo", cn = "全部米波"},
    farmer_clones = {en = "Only Clones", ru = "Только клоны", cn = "仅克隆"},
    poof_move = {en = "To Movement", ru = "Для перемещения", cn = "用于移动"},
    poof_damage = {en = "To Damage", ru = "Для урона", cn = "用于伤害"},

    bind_farm = {en = "Meepo AutoFarm V2", ru = "Meepo Автофарм V2", cn = "米波自动刷野 V2"},
    bind_map = {en = "Meepo AutoFarm V2 map", ru = "Карта Meepo AutoFarm V2", cn = "米波自动刷野 V2 地图"},
    bind_toggle = {en = "toggle", ru = "перекл.", cn = "切换"},

    panel_title = {en = "Meepo AutoFarm V2", ru = "Meepo AutoFarm V2", cn = "米波自动刷野 V2"},
    panel_radiant = {en = "RADIANT", ru = "СВЕТ", cn = "天辉"},
    panel_dire = {en = "DIRE", ru = "ТЬМА", cn = "夜魇"},
    panel_all = {en = "ALL", ru = "ВСЕ", cn = "全部"},
    panel_all_camps = {en = "ALL CAMPS", ru = "ВСЕ КЕМПЫ", cn = "全部野点"},
    panel_selected = {en = "SELECTED: ", ru = "ВЫБРАНО: ", cn = "已选: "},

    status_wait = {en = "WAIT", ru = "ЖД", cn = "等"},
    status_manual = {en = "MANUAL", ru = "РУЧН", cn = "手动"},
    status_cast = {en = "CAST", ru = "КАСТ", cn = "施法"},
    status_base = {en = "BASE", ru = "БАЗА", cn = "基地"},
    status_escape = {en = "ESCAPE", ru = "УХОД", cn = "撤退"},
    status_help = {en = "HELP", ru = "ПОМОЩЬ", cn = "助"},
    status_scout = {en = "SCOUT", ru = "ЧЕК", cn = "探"},
    status_solo = {en = "SOLO", ru = "СОЛО", cn = "单"},
    status_reserve = {en = "RESERVE", ru = "РЕЗЕРВ", cn = "备"},
    status_farm = {en = "FARM", ru = "ФАРМ", cn = "刷"},
    status_push = {en = "PUSH", ru = "ПУШ", cn = "推"},
    status_join = {en = "JOIN", ru = "СБОР", cn = "集合"},
    status_combo = {en = "COMBO", ru = "КОМБО", cn = "连招"},
    status_regen = {en = "REGEN", ru = "МАНА", cn = "回蓝"},
    status_hold = {en = "HOLD", ru = "СТОП", cn = "停"},

    tip_enable = {en = "Master switch. It only enables or disables the script.", ru = "Главный переключатель. Только включает или выключает скрипт.", cn = "总开关。只启用或禁用脚本。"},
    tip_farm = {en = "Actual jungle control state. Toggle it by key or click it here.", ru = "Реальное состояние автофарма. Переключай биндом или кликом.", cn = "实际刷野控制状态。可用按键或点击切换。"},
    tip_farm_key = {en = "Press once to start pack farming, press again to stop.", ru = "Нажми один раз, чтобы начать фарм; ещё раз, чтобы остановить.", cn = "按一次开始编队刷野，再按一次停止。"},
    tip_push_key = {en = "Press once to switch all Meepos into lane push mode, press again to stop.", ru = "Нажми один раз, чтобы включить режим пуша линий; ещё раз, чтобы остановить.", cn = "按一次让所有米波进入推线模式，再按一次停止。"},
    tip_map = {en = "Opens the camp picker panel.", ru = "Открывает панель выбора кемпов.", cn = "打开野点选择面板。"},
    tip_manual = {en = "After your own order to a Meepo, the script pauses that unit for this long.", ru = "После твоего ордера Meepo скрипт не трогает эту единицу столько секунд.", cn = "你手动给米波下达指令后，脚本会暂停控制该单位这么久。"},
    tip_farmers = {en = "Choose which controlled Meepos the farm mode may use.", ru = "Выбирает, каких контролируемых Meepo можно использовать для фарма.", cn = "选择刷野模式可控制哪些米波。"},
    tip_poof = {en = "Use Poof for moving between camps and/or extra jungle damage.", ru = "Использовать Пуф для перемещения между кемпами и/или дополнительного урона.", cn = "使用忽悠在野点间移动和/或补充刷野伤害。"},
    tip_push = {en = "Lane push mode. Meepo pairs spread across lanes with the most enemy creep pressure and avoid enemy heroes via vision and maphack.", ru = "Режим пуша линий. Пары Meepo распределяются по линиям с максимальным давлением вражеских крипов и избегают героев через видимость и maphack.", cn = "推线模式。米波双人组会分散到敌方兵线压力最大的线路，并通过视野与地图挂避开敌方英雄。"},
    tip_push_structures = {en = "Allow push mode to switch from wave control into structure pressure when the lane is supported.", ru = "Разрешает пуш-режиму переходить от контроля крипов к давлению по строениям, когда линия поддержана.", cn = "允许推线模式在兵线站稳后转为压制建筑。"},
    tip_push_maphack = {en = "Uses last enemy hero positions from maphack to skip dangerous lanes during push.", ru = "Использует последние позиции вражеских героев из maphack, чтобы не пушить опасные линии.", cn = "推线时使用地图挂记录的最后敌方英雄位置，跳过危险线路。"},
    tip_maphack_avoid = {en = "Uses maphack last-seen positions when avoiding enemies in farm and push.", ru = "Использует maphack при избегании врагов в фарме и пуше.", cn = "刷野和推线躲避敌人时使用地图挂最后可见位置。"},
    tip_flex_groups = {en = "Allows solo scouts, triples on big camps, and uneven Meepo counts.", ru = "Разрешает соло-скаутов, тройки на больших кемпах и нечётное число Meepo.", cn = "允许单人探路、大野三人组和非偶数米波分配。"},
    tip_stack_prep = {en = "Sends groups to empty camps shortly before the minute spawn.", ru = "Отправляет группы к пустым кемпам перед минутным спавном.", cn = "在分钟刷新前派组到空野点。"},
    tip_burst_poof = {en = "Coordinates damage Poof from the whole group on large camps.", ru = "Синхронизирует урон Пуфа всей группой на больших кемпах.", cn = "在大野点协调整组伤害忽悠。"},
    tip_smart_mode = {en = "Auto-switches between farm and push based on camp and lane pressure.", ru = "Автоматически переключает фарм и пуш по состоянию кемпов и линий.", cn = "根据野点与兵线压力自动切换刷野和推线。"},
    tip_smart_reserve = {en = "Idle Meepos scout camps, help push, or return for mana instead of standing still.", ru = "Свободные Meepo скаутят, помогают пушу или идут на базу по мане.", cn = "空闲米波会探路、协推或低蓝回基地。"},
    tip_push_tower_safe = {en = "Skips structure pressure when enemy heroes are near the tower.", ru = "Не давит строения, если враги рядом с башней.", cn = "塔附近有敌方英雄时跳过建筑推进。"},
    tip_status_vitals = {en = "Shows HP and mana percent in portrait status pills.", ru = "Показывает HP и ману в статусах у портретов.", cn = "在头像状态条显示血量与蓝量百分比。"},
    tip_status_auto = {en = "Automatically aligns farm/push status pills next to the vertical clone portraits.", ru = "Автоматически выравнивает плашки статусов рядом с вертикальными портретами клонов.", cn = "自动把刷野/推线状态贴到克隆头像旁边。"},
    tip_map_groups = {en = "Draws live farm and push objective markers on the opened map.", ru = "Показывает на открытой карте живые маркеры фарма и пуша.", cn = "在打开的地图上绘制实时刷野与推线目标标记。"},
    tip_ancients = {en = "Ancients stay ignored until this is enabled.", ru = "Древние кемпы игнорируются, пока это выключено.", cn = "关闭时会忽略远古野点。"},
    tip_avoid = {en = "When a visible enemy hero gets near a clone, it leaves that area and keeps farming safer camps.", ru = "Если видимый враг рядом с клоном, клон уходит из зоны и продолжает фармить безопаснее.", cn = "可见敌方英雄接近克隆时，克隆会离开该区域并继续刷更安全的野点。"},
    tip_tp = {en = "If Poof is not available during danger, the script can try TP/Travels before walking away.", ru = "Если Пуф недоступен при опасности, скрипт может попробовать TP/Travels перед отходом пешком.", cn = "危险时忽悠不可用，脚本可先尝试传送/飞鞋再步行撤退。"},
    tip_retreat = {en = "Low HP controlled Meepos are sent toward fountain and excluded from pack farm.", ru = "Контролируемые Meepo с низким HP уходят к фонтану и исключаются из фарма.", cn = "低血量米波会回泉水方向，并暂时退出刷野编队。"},
    tip_status = {en = "Draws compact Meepo statuses near the left portrait column.", ru = "Рисует компактные статусы Meepo возле левой колонки портретов.", cn = "在左侧头像栏附近绘制紧凑的米波状态。"},
    tip_debug = {en = "Shows current farm and push decisions, pair usage, and target selection.", ru = "Показывает текущие решения по фарму и пушу, использование пар и выбор цели.", cn = "显示当前刷野与推线决策、双人组使用情况和目标选择。"},
    tip_map_image = {en = "Optional minimap image path or URL. Empty value uses local override first, then the Dota minimap texture.", ru = "Необязательный путь или URL картинки миникарты. Пусто: сначала локальный override, потом текстура Dota.", cn = "可选小地图图片路径或 URL。留空会先用本地覆盖文件，再用 Dota 小地图贴图。"}
}

local function L(key)
    local lang = languageCode()
    local entry = locale[key]
    if not entry then return tostring(key) end
    return entry[lang] or entry.en or tostring(key)
end

local function LAll(key)
    local entry = locale[key] or {}
    return {entry.en or tostring(key), entry.ru or entry.en or tostring(key), entry.cn or entry.en or tostring(key)}
end

local function multiEnabled(widget, item)
    if not widget or not widget.ListEnabled then return false end

    local enabled = sc(widget.ListEnabled, widget)
    if type(enabled) ~= "table" then return false end

    local accepted = {}
    if type(item) == "table" then
        for _, name in ipairs(item) do accepted[name] = true end
    else
        accepted[item] = true
    end

    for _, value in ipairs(enabled) do
        if accepted[value] then return true end
    end

    return false
end

local statusFont = Render and Render.LoadFont and sc(
    Render.LoadFont,
    "Arial",
    Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0,
    Enum.FontWeight and Enum.FontWeight.NORMAL or 400
)
if not statusFont and Render and Render.LoadFont then
    statusFont = sc(Render.LoadFont, "Verdana", 12, 400)
end

local saveManaImage = Render and Render.LoadSvgString and sc(
    Render.LoadSvgString,
    [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path fill="#6BB8FF" d="M9 2h6v2l-1 .9V10l5.1 8.3A2.5 2.5 0 0 1 17 22H7a2.5 2.5 0 0 1-2.1-3.7L10 10V4.9L9 4V2Zm2.4 9L7 18.2a.8.8 0 0 0 .7 1.2h8.6a.8.8 0 0 0 .7-1.2L12.6 11h-1.2Zm-1.6 4h4.4l1.2 2H8.6l1.2-2Z"/>
</svg>]],
    Vec2(18, 18),
    SCRIPT_ID .. ".save_mana_icon"
)

local pushCreepImage = nil
if Render and Render.LoadImage then
    for _, path in ipairs(PUSH_ICON_CANDIDATES) do
        local handle = sc(Render.LoadImage, path)
        if type(handle) == "number" and handle > 0 then
            pushCreepImage = handle
            break
        end
    end
end

local statusColor = {
    farm = Color(110, 235, 150, 255),
    move = Color(120, 190, 255, 255),
    scout = Color(245, 210, 95, 255),
    help = Color(195, 150, 255, 255),
    base = Color(255, 115, 120, 255),
    manual = Color(210, 210, 210, 255),
    danger = Color(255, 80, 80, 255),
    combo = Color(255, 220, 90, 255),
    wait = Color(165, 175, 185, 255),
    text = Color(245, 248, 250, 255),
    bg = Color(8, 10, 12, 150),
    shadow = Color(0, 0, 0, 160)
}

local ui = {}
local applyLocalization
local setupLanguageReloadCallback

do
local function withTooltip(widget, text)
    if widget and widget.ToolTip then sc(widget.ToolTip, widget, text) end
    return widget
end

local function makeGear(widget, name)
    if widget and widget.Gear then
        return sc(widget.Gear, widget, name, "\u{f013}", true)
    end
    return nil
end

local function displayName(widget, text)
    if widget and widget.ForceLocalization then
        sc(widget.ForceLocalization, widget, text)
    end
    return widget
end

local function applyWidgetImage(widget, imagePath)
    if widget and imagePath and type(widget.Image) == "function" then
        sc(widget.Image, widget, imagePath)
    end
end

local function isMenuImagePath(value)
    return type(value) == "string" and value ~= "" and value:find("panorama/", 1, true) == 1
end

---@param widget any
local function applyMenuVisual(widget, visual)
    if not widget or not visual then return end

    if isMenuImagePath(visual) then
        applyWidgetImage(widget, visual)
    elseif type(widget.Icon) == "function" then
        sc(widget.Icon, widget, visual)
    end
end

---@param widget any
local function applyWidgetImageHandleOrIcon(widget, imageHandle, visual)
    if not widget then return end

    if imageHandle and type(widget.ImageHandle) == "function" then
        sc(widget.ImageHandle, widget, imageHandle)
        return
    end

    applyMenuVisual(widget, visual)
end

local function createTab()
    local section = sc(Menu.Find, "Heroes", "Hero List", "Meepo")
    if not section then
        section = sc(Menu.Create, "Heroes", "Hero List", "Meepo")
    end

    local tab = section and section.Create and sc(section.Create, section, "AutoFarm V2")
    if tab then return tab end

    tab = sc(Menu.Create, "General", "Meepo AutoFarm V2", SCRIPT_ID, "AutoFarm V2")
    return tab
end

local function createGroup(tab, name)
    if tab and tab.Create then
        local group = sc(tab.Create, tab, name)
        if group then return group end
    end
    return sc(Menu.Create, "General", "Meepo AutoFarm V2", SCRIPT_ID, "AutoFarm V2", name)
end

local menuNodes = {}
menuNodes.tab = createTab()
menuNodes.main = createGroup(menuNodes.tab, "Control")
menuNodes.farm = createGroup(menuNodes.tab, "Farm")
menuNodes.push = createGroup(menuNodes.tab, "Push")

ui.enabled = withTooltip(
    menuNodes.main and menuNodes.main.Switch and menuNodes.main:Switch("Enable script", false, DOTA_ICON.meepo),
    "Master switch. It only enables or disables the script."
)
displayName(ui.enabled, "Enable")
ui.farmActive = withTooltip(
    menuNodes.main and menuNodes.main.Switch and menuNodes.main:Switch("Farm mode", false, DOTA_ICON.ransack),
    "Actual jungle control state. Toggle it by key or click it here."
)
displayName(ui.farmActive, "Farm")
ui.farmKey = withTooltip(
    menuNodes.main and menuNodes.main.Bind and menuNodes.main:Bind("Toggle farm key", KEY_NONE, DOTA_ICON.ransack),
    "Press once to start pack farming, press again to stop."
)
displayName(ui.farmKey, "Farm Key")
ui.autoPush = withTooltip(
    menuNodes.main and menuNodes.main.Switch and menuNodes.main:Switch("Auto Push", false),
    "Dedicated lane push mode. Meepo pairs choose the best lane using live creep, structure, and danger state."
)
displayName(ui.autoPush, "Auto Push")
applyWidgetImageHandleOrIcon(ui.autoPush, pushCreepImage, FA_ICON.road)
ui.pushKey = withTooltip(
    menuNodes.main and menuNodes.main.Bind and menuNodes.main:Bind("Toggle push key", KEY_NONE),
    "Press once to switch all Meepos into lane push mode, press again to stop."
)
displayName(ui.pushKey, "Push Key")
applyWidgetImageHandleOrIcon(ui.pushKey, pushCreepImage, FA_ICON.road)
ui.smartMode = withTooltip(
    menuNodes.main and menuNodes.main.Switch and menuNodes.main:Switch("Smart Farm/Push", false, DOTA_ICON.divided),
    "Auto-switches between farm and push based on camp and lane pressure."
)
displayName(ui.smartMode, "Smart Farm/Push")
ui.megameepoHold = withTooltip(
    menuNodes.main and menuNodes.main.Switch and menuNodes.main:Switch("Megameepo hold", true, DOTA_ICON.mega),
    "During Megameepo, keeps clones near the main Meepo instead of scattering."
)
displayName(ui.megameepoHold, "Megameepo hold")
ui.mapKey = withTooltip(
    menuNodes.main and menuNodes.main.Bind and menuNodes.main:Bind("Farm map key", KEY_NONE, FA_ICON.map),
    "Opens the camp picker panel."
)
displayName(ui.mapKey, "Map")
menuNodes.scriptGear = makeGear(ui.enabled, "Script timing")
menuNodes.hudGear = makeGear(ui.mapKey, "HUD")
if ui.farmKey and ui.farmKey.Properties then
    sc(ui.farmKey.Properties, ui.farmKey, "Meepo AutoFarm V2", "toggle", true)
end
if ui.pushKey and ui.pushKey.Properties then
    sc(ui.pushKey.Properties, ui.pushKey, "Meepo Auto Push", "toggle", true)
end
if ui.mapKey and ui.mapKey.Properties then
    sc(ui.mapKey.Properties, ui.mapKey, "Meepo AutoFarm V2 map", "toggle", true)
end
if ui.farmActive and ui.farmActive.SetCallback and ui.farmKey and ui.farmKey.SetToggled then
    sc(ui.farmActive.SetCallback, ui.farmActive, function()
        sc(ui.farmKey.SetToggled, ui.farmKey, widgetGet(ui.farmActive, false))
    end, true)
end
if ui.autoPush and ui.autoPush.SetCallback and ui.pushKey and ui.pushKey.SetToggled then
    sc(ui.autoPush.SetCallback, ui.autoPush, function()
        sc(ui.pushKey.SetToggled, ui.pushKey, widgetGet(ui.autoPush, false))
    end, true)
end
ui.orderDelay = menuNodes.scriptGear and menuNodes.scriptGear.Slider and menuNodes.scriptGear:Slider("Order delay", 120, 900, 320, function(v) return v .. " ms" end)
applyMenuVisual(ui.orderDelay, FA_ICON.clock)
ui.orderJitter = menuNodes.scriptGear and menuNodes.scriptGear.Slider and menuNodes.scriptGear:Slider("Order jitter", 0, 220, 60, function(v) return v .. " ms" end)
applyMenuVisual(ui.orderJitter, FA_ICON.clock)
ui.pathCheck = withTooltip(
    menuNodes.scriptGear and menuNodes.scriptGear.Switch and menuNodes.scriptGear:Switch("Path check", true, FA_ICON.map),
    "Skips move orders that fail GridNav path validation."
)
displayName(ui.pathCheck, "Path check")
ui.manualPause = withTooltip(
    menuNodes.scriptGear and menuNodes.scriptGear.Slider and menuNodes.scriptGear:Slider("Manual override pause", 0, 6, 2, function(v) return v .. " sec" end),
    "After your own order to a Meepo, the script pauses that unit for this long."
)
displayName(ui.manualPause, "Manual pause")
ui.farmers = withTooltip(
    menuNodes.farm and menuNodes.farm.Combo and menuNodes.farm:Combo("Farmers", {
        L("farmer_any_unselected"),
        L("farmer_unselected_clones"),
        L("farmer_all"),
        L("farmer_clones")
    }, 3),
    "Choose which controlled Meepos the farm mode may use."
)
displayName(ui.farmers, "Farmers")
if ui.farmers and ui.farmers.Image then
    sc(ui.farmers.Image, ui.farmers, DOTA_ICON.meepo)
end
menuNodes.farmersGear = makeGear(ui.farmers, "Camp logic")
ui.poofUsage = withTooltip(
    menuNodes.farm and menuNodes.farm.MultiCombo and menuNodes.farm:MultiCombo("Poof Usage", {L("poof_move"), L("poof_damage")}, {L("poof_move")}),
    "Use Poof for moving between camps and/or extra jungle damage."
)
displayName(ui.poofUsage, "Poof")
if ui.poofUsage and ui.poofUsage.Image then
    sc(ui.poofUsage.Image, ui.poofUsage, DOTA_ICON.poof)
end
menuNodes.poofGear = makeGear(ui.poofUsage, "Poof tuning")
ui.saveMana = menuNodes.farm and menuNodes.farm.Slider and menuNodes.farm:Slider("Save Mana", 0, 90, 40, function(v) return v .. "%" end)
applyWidgetImageHandleOrIcon(ui.saveMana, saveManaImage, FA_ICON.flask)
ui.joinRadius = menuNodes.farmersGear and menuNodes.farmersGear.Slider and menuNodes.farmersGear:Slider("Pack join radius", 250, 950, 560, function(v) return v .. " u." end)
applyMenuVisual(ui.joinRadius, FA_ICON.expand)
ui.campRadius = menuNodes.farmersGear and menuNodes.farmersGear.Slider and menuNodes.farmersGear:Slider("Camp creep radius", 450, 1100, 760, function(v) return v .. " u." end)
applyMenuVisual(ui.campRadius, FA_ICON.radius)
ui.farmAncients = withTooltip(
    menuNodes.farmersGear and menuNodes.farmersGear.Switch and menuNodes.farmersGear:Switch("Farm ancient camps", false, FA_ICON.cube),
    "Ancients stay ignored until this is enabled."
)
displayName(ui.farmAncients, "Ancients")
ui.flexGroups = withTooltip(
    menuNodes.farmersGear and menuNodes.farmersGear.Switch and menuNodes.farmersGear:Switch("Flexible groups", true, DOTA_ICON.divided),
    "Allows solo scouts, triples on big camps, and uneven Meepo counts."
)
displayName(ui.flexGroups, "Flexible groups")
ui.groupMin = menuNodes.farmersGear and menuNodes.farmersGear.Slider and menuNodes.farmersGear:Slider("Min group size", 1, 3, 1, "%d")
applyMenuVisual(ui.groupMin, FA_ICON.users)
ui.groupMax = menuNodes.farmersGear and menuNodes.farmersGear.Slider and menuNodes.farmersGear:Slider("Max group size", 1, 3, 3, "%d")
applyMenuVisual(ui.groupMax, FA_ICON.users)
ui.stackPrep = withTooltip(
    menuNodes.farmersGear and menuNodes.farmersGear.Switch and menuNodes.farmersGear:Switch("Stack prep timing", true, FA_ICON.clock),
    "Sends groups to empty camps shortly before the minute spawn."
)
displayName(ui.stackPrep, "Stack prep timing")
ui.smartReserve = withTooltip(
    menuNodes.farm and menuNodes.farm.Switch and menuNodes.farm:Switch("Smart reserve", true, DOTA_ICON.divided),
    "Idle Meepos scout camps, help push, or return for mana instead of standing still."
)
displayName(ui.smartReserve, "Smart reserve")
ui.useMobility = withTooltip(
    menuNodes.farm and menuNodes.farm.Switch and menuNodes.farm:Switch("Mobility items", true, DOTA_ICON.blink),
    "Uses Blink, Swift Blink, or Phase Boots for long moves when Poof is unavailable."
)
displayName(ui.useMobility, "Mobility items")
ui.avoidEnemies = withTooltip(
    menuNodes.farm and menuNodes.farm.Switch and menuNodes.farm:Switch("Avoid visible enemies", true, FA_ICON.warning),
    "When a visible enemy hero gets near a clone, it leaves that area and keeps farming safer camps."
)
displayName(ui.avoidEnemies, "Avoid Enemies")
menuNodes.safetyGear = makeGear(ui.avoidEnemies, "Safety")

ui.pushStructures = withTooltip(
    menuNodes.push and menuNodes.push.Switch and menuNodes.push:Switch("Structure focus", true, FA_ICON.building),
    "Allow push mode to switch from wave control into structure pressure when the lane is supported."
)
displayName(ui.pushStructures, "Structure focus")
ui.pushTowerSafety = withTooltip(
    menuNodes.push and menuNodes.push.Switch and menuNodes.push:Switch("Tower safety", true, FA_ICON.heart),
    "Skips structure pressure when enemy heroes are near the tower."
)
displayName(ui.pushTowerSafety, "Tower safety")
ui.pushUseMaphack = withTooltip(
    menuNodes.push and menuNodes.push.Switch and menuNodes.push:Switch("Push maphack danger", true, FA_ICON.radar),
    "Uses last enemy hero positions from maphack to skip dangerous lanes during push."
)
displayName(ui.pushUseMaphack, "Push maphack danger")
menuNodes.pushGear = makeGear(ui.pushUseMaphack, "Lane danger")
ui.pushSupportRadius = withTooltip(
    menuNodes.pushGear and menuNodes.pushGear.Slider and menuNodes.pushGear:Slider("Support radius", 650, 1400, PUSH_SUPPORT_RADIUS, function(v) return v .. " u." end),
    "How wide an allied wave cluster must be to count as support for pushing."
)
displayName(ui.pushSupportRadius, "Support radius")
applyMenuVisual(ui.pushSupportRadius, FA_ICON.expand)
ui.pushWaveRadius = withTooltip(
    menuNodes.pushGear and menuNodes.pushGear.Slider and menuNodes.pushGear:Slider("Wave scan radius", 650, 1400, PUSH_WAVE_RADIUS, function(v) return v .. " u." end),
    "How far enemy lane creeps are considered part of the same push front."
)
displayName(ui.pushWaveRadius, "Wave scan radius")
applyMenuVisual(ui.pushWaveRadius, FA_ICON.radius)
ui.pushStructureRadius = withTooltip(
    menuNodes.pushGear and menuNodes.pushGear.Slider and menuNodes.pushGear:Slider("Structure scan radius", 900, 2200, PUSH_STRUCTURE_RADIUS, function(v) return v .. " u." end),
    "How far towers and barracks can influence the chosen push lane."
)
displayName(ui.pushStructureRadius, "Structure scan radius")
applyMenuVisual(ui.pushStructureRadius, FA_ICON.building)
ui.pushMaphackMemory = menuNodes.pushGear and menuNodes.pushGear.Slider and menuNodes.pushGear:Slider("Maphack memory", 8, 35, 22, function(v) return v .. " sec" end)
applyMenuVisual(ui.pushMaphackMemory, FA_ICON.clock)

ui.maphackAvoid = withTooltip(
    menuNodes.safetyGear and menuNodes.safetyGear.Switch and menuNodes.safetyGear:Switch("Maphack avoid", true, FA_ICON.radar),
    "Uses maphack last-seen positions when avoiding enemies in farm and push."
)
displayName(ui.maphackAvoid, "Maphack avoid")
ui.enemyAvoidRadius = menuNodes.safetyGear and menuNodes.safetyGear.Slider and menuNodes.safetyGear:Slider("Enemy avoid radius", 800, 2600, DEFAULT_ENEMY_RADIUS, function(v) return v .. " u." end)
applyMenuVisual(ui.enemyAvoidRadius, FA_ICON.radar)
ui.tpEscape = withTooltip(
    menuNodes.safetyGear and menuNodes.safetyGear.Switch and menuNodes.safetyGear:Switch("TP escape fallback", true, DOTA_ICON.tpscroll),
    "If Poof is not available during danger, the script can try TP/Travels before walking away."
)
displayName(ui.tpEscape, "TP fallback")
ui.retreatLow = withTooltip(
    menuNodes.safetyGear and menuNodes.safetyGear.Switch and menuNodes.safetyGear:Switch("Retreat low HP Meepos", true, FA_ICON.heart),
    "Low HP controlled Meepos are sent toward fountain and excluded from pack farm."
)
displayName(ui.retreatLow, "Low HP Retreat")
ui.shrineMana = withTooltip(
    menuNodes.safetyGear and menuNodes.safetyGear.Switch and menuNodes.safetyGear:Switch("Low mana to base", true, FA_ICON.flask),
    "Low mana Meepos walk toward fountain while staying out of farm groups."
)
displayName(ui.shrineMana, "Low mana to base")
ui.retreatHp = menuNodes.safetyGear and menuNodes.safetyGear.Slider and menuNodes.safetyGear:Slider("Retreat HP", 10, 70, 28, function(v) return v .. "%" end)
applyMenuVisual(ui.retreatHp, FA_ICON.heart)

ui.poofDistance = menuNodes.poofGear and menuNodes.poofGear.Slider and menuNodes.poofGear:Slider("Poof move distance", 700, 2600, 1350, function(v) return v .. " u." end)
applyMenuVisual(ui.poofDistance, DOTA_ICON.poof)
ui.poofCooldown = menuNodes.poofGear and menuNodes.poofGear.Slider and menuNodes.poofGear:Slider("Poof retry delay", 1, 8, 3, function(v) return v .. " sec" end)
applyMenuVisual(ui.poofCooldown, FA_ICON.clock)
ui.burstPoof = withTooltip(
    menuNodes.poofGear and menuNodes.poofGear.Switch and menuNodes.poofGear:Switch("Burst Poof", true, DOTA_ICON.poof),
    "Coordinates damage Poof from the whole group on large camps."
)
displayName(ui.burstPoof, "Burst Poof")
ui.burstPoofCreeps = menuNodes.poofGear and menuNodes.poofGear.Slider and menuNodes.poofGear:Slider("Burst creep count", 2, 6, 3, "%d")
applyMenuVisual(ui.burstPoofCreeps, DOTA_ICON.poof)

ui.showStatus = withTooltip(
    menuNodes.hudGear and menuNodes.hudGear.Switch and menuNodes.hudGear:Switch("Portrait statuses", true, FA_ICON.eye),
    "Draws compact Meepo statuses near the left portrait column."
)
displayName(ui.showStatus, "Portrait Status")
ui.statusVitals = withTooltip(
    menuNodes.hudGear and menuNodes.hudGear.Switch and menuNodes.hudGear:Switch("Status HP/MP", true, FA_ICON.heart),
    "Shows HP and mana percent in portrait status pills."
)
displayName(ui.statusVitals, "Status HP/MP")
ui.debugOverlay = withTooltip(
    menuNodes.hudGear and menuNodes.hudGear.Switch and menuNodes.hudGear:Switch("Debug Overlay", false, FA_ICON.bug),
    "Shows current farm and push decisions, pair usage, and target selection."
)
displayName(ui.debugOverlay, "Debug Overlay")
ui.statusAutoAnchor = withTooltip(
    menuNodes.hudGear and menuNodes.hudGear.Switch and menuNodes.hudGear:Switch("Auto Portrait Anchor", true, FA_ICON.anchor),
    "Automatically aligns farm/push status pills next to the vertical clone portraits."
)
displayName(ui.statusAutoAnchor, "Auto Portrait Anchor")
ui.mapGroupMarkers = withTooltip(
    menuNodes.hudGear and menuNodes.hudGear.Switch and menuNodes.hudGear:Switch("Map Group Markers", true, FA_ICON.map),
    "Draws live farm and push objective markers on the opened map."
)
displayName(ui.mapGroupMarkers, "Map Group Markers")
ui.mapAwareness = withTooltip(
    menuNodes.hudGear and menuNodes.hudGear.Switch and menuNodes.hudGear:Switch("Map enemy dots", true, FA_ICON.radar),
    "Draws last-seen enemy hero positions on the farm map."
)
displayName(ui.mapAwareness, "Map enemy dots")
ui.mapImagePath = withTooltip(
    menuNodes.hudGear and menuNodes.hudGear.Input and menuNodes.hudGear:Input("Map image path", "", FA_ICON.image),
    "Optional minimap image path or URL. Empty value uses local override first, then the Dota minimap texture."
)
ui.debugX = menuNodes.hudGear and menuNodes.hudGear.Slider and menuNodes.hudGear:Slider("Debug X", 0, 1200, 310, "%d")
applyMenuVisual(ui.debugX, FA_ICON.bug)
ui.debugY = menuNodes.hudGear and menuNodes.hudGear.Slider and menuNodes.hudGear:Slider("Debug Y", 0, 900, 42, "%d")
applyMenuVisual(ui.debugY, FA_ICON.bug)
ui.statusX = menuNodes.hudGear and menuNodes.hudGear.Slider and menuNodes.hudGear:Slider("Status X", 0, 600, 112, "%d")
applyMenuVisual(ui.statusX, FA_ICON.eye)
ui.statusY = menuNodes.hudGear and menuNodes.hudGear.Slider and menuNodes.hudGear:Slider("Status Y", 0, 900, 42, "%d")
applyMenuVisual(ui.statusY, FA_ICON.eye)
ui.statusGap = menuNodes.hudGear and menuNodes.hudGear.Slider and menuNodes.hudGear:Slider("Status row gap", 35, 110, 73, "%d")
applyMenuVisual(ui.statusGap, FA_ICON.expand)
applyMenuVisual(ui.manualPause, FA_ICON.pause)

local function setTooltip(widget, key)
    if widget and widget.ToolTip then
        sc(widget.ToolTip, widget, L(key))
    end
end

local function localizeWidget(widget, nameKey, tooltipKey)
    displayName(widget, L(nameKey))
    if tooltipKey then setTooltip(widget, tooltipKey) end
end

local function localizedItems(keys)
    local items = {}
    for _, key in ipairs(keys) do
        items[#items + 1] = L(key)
    end
    return items
end

local function updateComboItems(widget, keys, fallbackIndex)
    if not widget or not widget.Update then return end

    local index = widgetGet(widget, fallbackIndex or 0)
    if type(index) ~= "number" then index = fallbackIndex or 0 end

    sc(widget.Update, widget, localizedItems(keys), index)
end

local function updateMultiComboItems(widget, keys)
    if not widget or not widget.Update then return end

    local enabled = {}
    for _, key in ipairs(keys) do
        if multiEnabled(widget, LAll(key)) then
            enabled[#enabled + 1] = L(key)
        end
    end

    sc(widget.Update, widget, localizedItems(keys), enabled)
end

applyLocalization = function(force)
    local lang = languageCode()
    if not force and state.lastLanguage == lang then return end
    state.lastLanguage = lang

    displayName(menuNodes.tab, L("tab"))
    displayName(menuNodes.main, L("group_main"))
    displayName(menuNodes.farm, L("group_farm"))
    displayName(menuNodes.push, L("group_push"))

    displayName(menuNodes.scriptGear, L("gear_script"))
    displayName(menuNodes.hudGear, L("gear_hud"))
    displayName(menuNodes.farmersGear, L("gear_camps"))
    displayName(menuNodes.poofGear, L("gear_poof"))
    displayName(menuNodes.safetyGear, L("gear_safety"))
    displayName(menuNodes.pushGear, L("gear_push"))

    localizeWidget(ui.enabled, "ui_enable", "tip_enable")
    localizeWidget(ui.farmActive, "ui_farm", "tip_farm")
    localizeWidget(ui.farmKey, "ui_farm_key", "tip_farm_key")
    localizeWidget(ui.pushKey, "ui_push_key", "tip_push_key")
    localizeWidget(ui.mapKey, "ui_map", "tip_map")
    localizeWidget(ui.orderDelay, "ui_order_delay")
    localizeWidget(ui.manualPause, "ui_manual_pause", "tip_manual")
    localizeWidget(ui.farmers, "ui_farmers", "tip_farmers")
    localizeWidget(ui.poofUsage, "ui_poof", "tip_poof")
    localizeWidget(ui.autoPush, "ui_auto_push", "tip_push")
    localizeWidget(ui.pushStructures, "ui_push_structures", "tip_push_structures")
    localizeWidget(ui.pushSupportRadius, "ui_push_support_radius")
    localizeWidget(ui.pushWaveRadius, "ui_push_wave_radius")
    localizeWidget(ui.pushStructureRadius, "ui_push_structure_radius")
    localizeWidget(ui.pushUseMaphack, "ui_push_maphack", "tip_push_maphack")
    localizeWidget(ui.pushMaphackMemory, "ui_push_maphack_memory")
    localizeWidget(ui.maphackAvoid, "ui_maphack_avoid", "tip_maphack_avoid")
    localizeWidget(ui.flexGroups, "ui_flex_groups", "tip_flex_groups")
    localizeWidget(ui.groupMin, "ui_group_min")
    localizeWidget(ui.groupMax, "ui_group_max")
    localizeWidget(ui.stackPrep, "ui_stack_prep", "tip_stack_prep")
    localizeWidget(ui.smartMode, "ui_smart_mode", "tip_smart_mode")
    localizeWidget(ui.smartReserve, "ui_smart_reserve", "tip_smart_reserve")
    localizeWidget(ui.pushTowerSafety, "ui_push_tower_safe", "tip_push_tower_safe")
    localizeWidget(ui.burstPoof, "ui_burst_poof", "tip_burst_poof")
    localizeWidget(ui.burstPoofCreeps, "ui_burst_creeps")
    localizeWidget(ui.statusVitals, "ui_status_vitals", "tip_status_vitals")
    localizeWidget(ui.orderJitter, "ui_order_jitter")
    localizeWidget(ui.pathCheck, "ui_path_check")
    localizeWidget(ui.useMobility, "ui_use_mobility")
    localizeWidget(ui.shrineMana, "ui_shrine_mana")
    localizeWidget(ui.megameepoHold, "ui_megameepo_hold")
    localizeWidget(ui.mapAwareness, "ui_map_awareness")
    localizeWidget(ui.saveMana, "ui_save_mana")
    localizeWidget(ui.joinRadius, "ui_join_radius")
    localizeWidget(ui.campRadius, "ui_camp_radius")
    localizeWidget(ui.farmAncients, "ui_ancients", "tip_ancients")
    localizeWidget(ui.avoidEnemies, "ui_avoid_enemies", "tip_avoid")
    localizeWidget(ui.enemyAvoidRadius, "ui_enemy_radius")
    localizeWidget(ui.tpEscape, "ui_tp_fallback", "tip_tp")
    localizeWidget(ui.retreatLow, "ui_low_hp", "tip_retreat")
    localizeWidget(ui.retreatHp, "ui_retreat_hp")
    localizeWidget(ui.poofDistance, "ui_poof_distance")
    localizeWidget(ui.poofCooldown, "ui_poof_delay")
    localizeWidget(ui.showStatus, "ui_status", "tip_status")
    localizeWidget(ui.debugOverlay, "ui_debug", "tip_debug")
    localizeWidget(ui.statusAutoAnchor, "ui_status_auto", "tip_status_auto")
    localizeWidget(ui.mapGroupMarkers, "ui_map_groups", "tip_map_groups")
    localizeWidget(ui.mapImagePath, "ui_map_image", "tip_map_image")
    localizeWidget(ui.debugX, "ui_debug_x")
    localizeWidget(ui.debugY, "ui_debug_y")
    localizeWidget(ui.statusX, "ui_status_x")
    localizeWidget(ui.statusY, "ui_status_y")
    localizeWidget(ui.statusGap, "ui_status_gap")

    updateComboItems(ui.farmers, {
        "farmer_any_unselected",
        "farmer_unselected_clones",
        "farmer_all",
        "farmer_clones"
    }, 3)
    updateMultiComboItems(ui.poofUsage, {"poof_move", "poof_damage"})

    if ui.farmKey and ui.farmKey.Properties then
        sc(ui.farmKey.Properties, ui.farmKey, L("bind_farm"), L("bind_toggle"), true)
    end
    if ui.mapKey and ui.mapKey.Properties then
        sc(ui.mapKey.Properties, ui.mapKey, L("bind_map"), L("bind_toggle"), true)
    end
end

setupLanguageReloadCallback = function()
    if state.languageCallbackSet then return end

    local widget = languageWidget()
    if not widget or not widget.SetCallback then return end

    state.languageCallbackSet = true
    local previous = widgetGet(widget, "en")
    sc(widget.SetCallback, widget, function(ctrl)
        local current = widgetGet(ctrl or widget, "en")
        if current == previous then return end
        previous = current

        state.lastLanguage = nil
        applyLocalization(true)
    end)
end

end

applyLocalization(true)
setupLanguageReloadCallback()

local function isEnabled()
    return widgetGet(ui.enabled, false)
end

local function isFarmActive()
    return isEnabled() and widgetGet(ui.farmActive, false)
end

local function isPushActive()
    return isEnabled() and widgetGet(ui.autoPush, false)
end

local function hasActiveMode()
    return isFarmActive() or isPushActive()
end

local function setMapOpen(open)
    state.mapOpen = open == true
    if ui.mapKey and ui.mapKey.SetToggled then
        sc(ui.mapKey.SetToggled, ui.mapKey, state.mapOpen)
    end
end

local function resetTickCache()
    state.tickCache = newTickCache()
end

local function resetRuntimeState()
    state.lastTick = 0
    state.lastOrder = {}
    state.lastPoof = {}
    state.lastTp = {}
    state.manualUntil = {}
    state.emptyUntil = {}
    state.campMemory = {}
    state.unitCamp = {}
    state.enemyAvoid = {}
    state.localHero = nil
    state.statusById = {}
    state.statusList = {}
    state.debugInfo = {title = "", lines = {}}
    state.activeGroups = {}
    state.smartModeSwitchAt = 0
    state.unitFightCamp = {}
    state.comboKeyWidget = nil
    state.comboKeyLookupAt = 0
    state.mapDragging = false
    state.mapMousePrev = false
    state.mapBlockInputUntil = 0
    state.mapBindPrev = false
    state.farmBindPrev = false
    resetTickCache()
end

local function syncModeWidgets()
    local farm = widgetGet(ui.farmActive, false)
    local push = widgetGet(ui.autoPush, false)

    if farm and push then
        if state.lastMode == "push" then
            if ui.farmActive and ui.farmActive.Set then sc(ui.farmActive.Set, ui.farmActive, false) end
            farm = false
        else
            if ui.autoPush and ui.autoPush.Set then sc(ui.autoPush.Set, ui.autoPush, false) end
            push = false
        end
    end

    if farm then
        state.lastMode = "farm"
    elseif push then
        state.lastMode = "push"
    else
        state.lastMode = ""
    end

    if ui.farmKey and ui.farmKey.SetToggled then
        sc(ui.farmKey.SetToggled, ui.farmKey, farm)
    end
    if ui.pushKey and ui.pushKey.SetToggled then
        sc(ui.pushKey.SetToggled, ui.pushKey, push)
    end
end

local function purgeUnitStateById(id)
    if not id or id <= 0 then return end

    state.lastOrder[id] = nil
    state.lastPoof[id] = nil
    state.lastTp[id] = nil
    state.manualUntil[id] = nil
    state.unitCamp[id] = nil
    state.unitFightCamp[id] = nil
    state.statusById[id] = nil

    for index = #state.statusList, 1, -1 do
        local entry = state.statusList[index]
        local entryId = entry and entry.unit and (sc(Entity.GetIndex, entry.unit) or 0) or 0
        if entryId == id then
            table.remove(state.statusList, index)
        end
    end

    if state.localHero and (sc(Entity.GetIndex, state.localHero) or 0) == id then
        state.localHero = nil
    end
end

local function purgeUnitState(entity)
    purgeUnitStateById(sc(Entity.GetIndex, entity) or 0)
end

local function getTickCache(t)
    local cache = state.tickCache
    if not cache or cache.stamp ~= t then
        cache = newTickCache()
        cache.stamp = t
        state.tickCache = cache
    end
    return cache
end

local function checkFarmToggleBind()
    if not isEnabled() or not ui.farmKey or not ui.farmKey.IsPressed then
        state.farmBindPrev = false
        return
    end

    local pressed = sc(ui.farmKey.IsPressed, ui.farmKey) == true
    if pressed and not state.farmBindPrev and ui.farmActive and ui.farmActive.Set then
        local nextState = not widgetGet(ui.farmActive, false)
        sc(ui.farmActive.Set, ui.farmActive, nextState)
        if nextState and ui.autoPush and ui.autoPush.Set then
            sc(ui.autoPush.Set, ui.autoPush, false)
        end
    end
    state.farmBindPrev = pressed
end

local function checkPushToggleBind()
    if not isEnabled() or not ui.pushKey or not ui.pushKey.IsPressed then
        state.pushBindPrev = false
        return
    end

    local pressed = sc(ui.pushKey.IsPressed, ui.pushKey) == true
    if pressed and not state.pushBindPrev and ui.autoPush and ui.autoPush.Set then
        local nextState = not widgetGet(ui.autoPush, false)
        sc(ui.autoPush.Set, ui.autoPush, nextState)
        if nextState and ui.farmActive and ui.farmActive.Set then
            sc(ui.farmActive.Set, ui.farmActive, false)
        end
    end
    state.pushBindPrev = pressed
end

local function checkMapToggleBind()
    if not isEnabled() or not ui.mapKey or not ui.mapKey.IsPressed then
        state.mapBindPrev = false
        return
    end

    local pressed = sc(ui.mapKey.IsPressed, ui.mapKey) == true
    if pressed and not state.mapBindPrev then
        setMapOpen(not state.mapOpen)
    end
    state.mapBindPrev = pressed
end

local function comboKeyWidget(t)
    if not Menu or not Menu.Find then return nil end

    if t < (state.comboKeyLookupAt or 0) then
        return state.comboKeyWidget
    end

    state.comboKeyLookupAt = t + 1.0
    state.comboKeyWidget = sc(
        Menu.Find,
        "Heroes",
        "Hero List",
        "Meepo",
        "Main Settings",
        "Hero Settings",
        "Combo Key"
    )

    return state.comboKeyWidget
end

local function comboKeyActive(t)
    local bind = comboKeyWidget(t)
    if not bind or not bind.IsDown then return false end

    return sc(bind.IsDown, bind) == true
end

local function alive(entity)
    return entity ~= nil and sc(Entity.IsAlive, entity) == true
end

local function dormant(entity)
    return Entity.IsDormant and sc(Entity.IsDormant, entity) == true
end

local function visible(entity)
    local isVisible = Entity.IsVisible and sc(Entity.IsVisible, entity)
    if isVisible ~= nil then return isVisible == true end
    return not dormant(entity)
end

local function unitName(unit)
    return sc(NPC.GetUnitName, unit) or ""
end

local function unitId(unit)
    return sc(Entity.GetIndex, unit) or 0
end

local function origin(unit)
    return sc(Entity.GetAbsOrigin, unit)
end

local function vecX(value)
    if not value then return 0 end
    local x = value.x
    if type(x) == "number" then return x end
    if value.GetX then return value:GetX() end
    return 0
end

local function vecY(value)
    if not value then return 0 end
    local y = value.y
    if type(y) == "number" then return y end
    if value.GetY then return value:GetY() end
    return 0
end

local function vecZ(value)
    if not value then return 0 end
    local z = value.z
    if type(z) == "number" then return z end
    if value.GetZ then return value:GetZ() end
    return 0
end

local function dist2DSqr(a, b)
    if not a or not b then return math.huge end
    local dx = vecX(a) - vecX(b)
    local dy = vecY(a) - vecY(b)
    return dx * dx + dy * dy
end

local function dist2D(a, b)
    local sqr = dist2DSqr(a, b)
    if sqr == math.huge then return math.huge end
    return math.sqrt(sqr)
end

local function isWithin2D(a, b, radius)
    if not a or not b then return false end
    local dx = vecX(a) - vecX(b)
    local dy = vecY(a) - vecY(b)
    return dx * dx + dy * dy <= radius * radius
end

local function hpPct(unit)
    local hp = sc(Entity.GetHealth, unit) or 0
    local maxHp = sc(Entity.GetMaxHealth, unit) or 1
    if maxHp <= 0 then return 100 end
    return (hp / maxHp) * 100
end

local function manaPct(unit)
    local mana = sc(NPC.GetMana, unit) or 0
    local maxMana = sc(NPC.GetMaxMana, unit) or 1
    if maxMana <= 0 then return 100 end
    return (mana / maxMana) * 100
end

local function basePosition(team)
    if team == 2 then
        return Vector(-7200, -6600, 384)
    end
    return Vector(7000, 6400, 384)
end

local function isControllable(unit, playerId)
    if not unit or not playerId or playerId < 0 then return false end

    local byNpc = sc(NPC.IsControllableByPlayer, unit, playerId)
    if byNpc ~= nil then return byNpc == true end

    local byEntity = sc(Entity.IsControllableByPlayer, unit, playerId)
    if byEntity ~= nil then return byEntity == true end

    return true
end

local function isMeepo(unit)
    return unit and unitName(unit) == MEEPO_NAME and sc(NPC.IsIllusion, unit) ~= true
end

local function isCloneMeepo(unit, localHero)
    if not isMeepo(unit) then return false end
    if sc(NPC.IsMeepoClone, unit) == true then return true end
    return localHero ~= nil and unitId(unit) ~= unitId(localHero)
end

local function buildSelectedIds(player)
    local selectedIds = {}
    local selected = player and Player.GetSelectedUnits and sc(Player.GetSelectedUnits, player) or {}

    for _, unit in ipairs(selected) do
        selectedIds[unitId(unit)] = true
    end

    return selectedIds
end

local function farmerMode()
    return widgetGet(ui.farmers, 3)
end

local function farmerAllowed(unit, localHero, selectedIds)
    local id = unitId(unit)
    local selected = selectedIds and selectedIds[id] == true
    local clone = isCloneMeepo(unit, localHero)
    local mode = farmerMode()

    if mode == 0 then
        return not selected
    elseif mode == 1 then
        return clone and not selected
    elseif mode == 2 then
        return true
    end

    return clone
end

local function isManual(unit, t)
    local untilTime = state.manualUntil[unitId(unit)]
    return untilTime ~= nil and t < untilTime
end

local function shouldRetreat(unit)
    return widgetGet(ui.retreatLow, true) and hpPct(unit) <= widgetGet(ui.retreatHp, 28)
end

local function maphackAvoidEnabled()
    return widgetGet(ui.maphackAvoid, true)
end

local function awarenessMaphackEnabled()
    if maphackAvoidEnabled() then return true end
    return isPushActive() and widgetGet(ui.pushUseMaphack, true)
end

local function isMegameepoActive(hero)
    if not hero then return false end
    if NPC.HasModifier and sc(NPC.HasModifier, hero, "modifier_meepo_megameepo") == true then return true end
    return false
end

local function needsManaRefill(unit)
    return widgetGet(ui.shrineMana, true) and manaPct(unit) <= SHRINE_MANA_THRESHOLD
end

local function formatStatusText(unit, text)
    if not widgetGet(ui.statusVitals, true) or not unit then return text end
    return string.format("%s %d/%d", text, math.floor(hpPct(unit)), math.floor(manaPct(unit)))
end

local function clearStatuses()
    state.statusById = {}
    state.statusList = {}
end

local function setDebugInfo(title, lines)
    state.debugInfo = {
        title = title or "Meepo AutoFarm V2",
        lines = lines or {}
    }
end

local function setStatus(unit, text, color, groupId)
    if not unit then return end

    state.statusById[unitId(unit)] = {
        unit = unit,
        text = formatStatusText(unit, text or L("status_wait")),
        color = color or statusColor.wait,
        groupId = groupId
    }
end

local function finalizeStatuses(units)
    state.statusList = {}

    for index, unit in ipairs(units or {}) do
        local entry = state.statusById[unitId(unit)]
        if entry then
            entry.index = index
            state.statusList[#state.statusList + 1] = entry
        end
    end
end

local function addMeepo(list, seen, unit, playerId, team, localHero, selectedIds)
    if not isMeepo(unit) or not alive(unit) or dormant(unit) then return end
    if sc(Entity.GetTeamNum, unit) ~= team then return end
    if not isControllable(unit, playerId) then return end

    local id = unitId(unit)
    if seen[id] then return end

    if not farmerAllowed(unit, localHero, selectedIds) then return end

    seen[id] = true
    list[#list + 1] = unit
end

local function getControllableMeepos(localHero, player, playerId, team, t)
    local cache = getTickCache(t)
    if cache.meepos then return cache.meepos end

    local result, seen = {}, {}
    local selectedIds = cache.selectedIds
    if not selectedIds then
        selectedIds = buildSelectedIds(player)
        cache.selectedIds = selectedIds
    end

    local heroes = sc(Heroes.GetAll) or {}
    for _, hero in ipairs(heroes) do
        addMeepo(result, seen, hero, playerId, team, localHero, selectedIds)
    end

    local npcs = sc(NPCs.GetAll) or {}
    for _, npc in ipairs(npcs) do
        addMeepo(result, seen, npc, playerId, team, localHero, selectedIds)
    end

    local localHeroId = unitId(localHero)
    table.sort(result, function(a, b)
        local aMain = unitId(a) == localHeroId
        local bMain = unitId(b) == localHeroId
        if aMain ~= bMain then return aMain end
        return unitId(a) < unitId(b)
    end)
    cache.meepos = result
    return result
end

local buildPushGroups
local collectEnemyAwareness
local syncSmartMode
local pruneEnemyAvoid, rememberEnemyAvoid, enemyAvoidRadius, minDistanceToEnemyAvoid, collectVisibleEnemyHeroes
local collectCampInfos, getCampMemory, shouldWaitCamp, nextNeutralSpawnTime, campWaitPosition
local campSafeFromEnemies, countNear, formationPosition, campCenter, campAllowed, groupCenter, reserveAnchorPosition
local minDistanceToUnits, desiredGroupSize, campPriorityScore
local pushStructuresEnabled, pushSupportRadius, pushWaveRadius, pushStructureRadius
local takeNearestUnits, takePreferredUnits, newGroup, storeActiveGroups
local hasSelectedCamps, selectedCampCount

do
local function countEntriesNear(entries, pos, radius)
    local count = 0
    for _, entry in ipairs(entries or {}) do
        if entry.pos and isWithin2D(entry.pos, pos, radius) then
            count = count + 1
        end
    end
    return count
end

local function minDistanceToEntries(entries, pos)
    local best = math.huge
    for _, entry in ipairs(entries or {}) do
        if entry.pos then
            local d = dist2D(entry.pos, pos)
            if d < best then best = d end
        end
    end
    return best
end

local function nearestAwarenessInfo(entries, pos)
    local bestDistance = math.huge
    local bestAge = math.huge
    local bestVisible = false

    for _, entry in ipairs(entries or {}) do
        if entry.pos then
            local d = dist2D(entry.pos, pos)
            if d < bestDistance then
                bestDistance = d
                bestAge = entry.age or 0
                bestVisible = entry.visible == true
            end
        end
    end

    return bestDistance, bestAge, bestVisible
end

local function enemyBasePosition(team)
    return team == 2 and basePosition(3) or basePosition(2)
end

local function pushProgressScore(pos, team)
    local ownBase = basePosition(team)
    local enemyBase = enemyBasePosition(team)
    local total = math.max(1, dist2D(ownBase, enemyBase))
    local remain = dist2D(pos, enemyBase)
    return math.max(0, total - remain) / total * 650
end

local function pushTargetPriority(name)
    if name == "" then return 0 end
    if name:find("siege", 1, true) then return 180 end
    if name:find("flagbearer", 1, true) then return 140 end
    if name:find("ranged", 1, true) then return 100 end
    if name:find("melee", 1, true) then return 40 end
    return 0
end

local function pushTargetLabel(unit, fallback)
    if not unit then return fallback or "front" end

    local name = unitName(unit)
    if name ~= "" then return name end
    if sc(NPC.IsFort, unit) == true then return "fort" end
    if sc(NPC.IsBarracks, unit) == true then return "barracks" end
    if sc(NPC.IsTower, unit) == true then return "tower" end
    return fallback or "target"
end

local function structurePushBonus(kind, supportCount)
    local base = 0
    if kind == "fort" then
        base = 1800
    elseif kind == "barracks" then
        base = 1350
    else
        base = 950
    end

    if supportCount <= 0 then
        base = base - 1500
    end

    return base + supportCount * 140
end

local function collectLaneCreeps(team, t)
    local cache = getTickCache(t)
    if cache.alliedLaneCreeps then
        return cache.alliedLaneCreeps, cache.enemyLaneCreeps
    end

    local allied, enemy = {}, {}
    local npcs = sc(NPCs.GetAll) or {}

    for _, npc in ipairs(npcs) do
        if alive(npc) and not dormant(npc) and sc(NPC.IsLaneCreep, npc) == true then
            local pos = origin(npc)
            if pos then
                local entry = {
                    unit = npc,
                    pos = pos,
                    name = unitName(npc),
                    hp = sc(Entity.GetHealth, npc) or 1
                }

                if sc(Entity.GetTeamNum, npc) == team then
                    allied[#allied + 1] = entry
                else
                    enemy[#enemy + 1] = entry
                end
            end
        end
    end

    cache.alliedLaneCreeps = allied
    cache.enemyLaneCreeps = enemy
    return allied, enemy
end

local function collectPushStructures(team, t)
    local cache = getTickCache(t)
    if cache.pushStructures then return cache.pushStructures end

    local result = {}
    local towers = sc(Towers.GetAll) or {}
    for _, tower in ipairs(towers) do
        if alive(tower)
            and not dormant(tower)
            and sc(Entity.GetTeamNum, tower) ~= team
            and sc(NPC.IsInvulnerable, tower) ~= true then
            local pos = origin(tower)
            if pos then
                result[#result + 1] = {unit = tower, pos = pos, kind = "tower"}
            end
        end
    end

    local npcs = sc(NPCs.GetAll) or {}
    for _, npc in ipairs(npcs) do
        if alive(npc)
            and not dormant(npc)
            and sc(Entity.GetTeamNum, npc) ~= team
            and sc(NPC.IsInvulnerable, npc) ~= true then
            local kind = nil
            if sc(NPC.IsBarracks, npc) == true then
                kind = "barracks"
            elseif sc(NPC.IsFort, npc) == true then
                kind = "fort"
            end

            if kind then
                local pos = origin(npc)
                if pos then
                    result[#result + 1] = {unit = npc, pos = pos, kind = kind}
                end
            end
        end
    end

    cache.pushStructures = result
    return result
end

local function pushMaphackEnabled()
    return awarenessMaphackEnabled()
end

local function pushMaphackMemory()
    return widgetGet(ui.pushMaphackMemory, 22)
end

pushStructuresEnabled = function()
    return widgetGet(ui.pushStructures, true)
end

pushSupportRadius = function()
    return widgetGet(ui.pushSupportRadius, PUSH_SUPPORT_RADIUS)
end

pushWaveRadius = function()
    return widgetGet(ui.pushWaveRadius, PUSH_WAVE_RADIUS)
end

pushStructureRadius = function()
    return widgetGet(ui.pushStructureRadius, PUSH_STRUCTURE_RADIUS)
end

local function distPointToSegment2D(p, a, b)
    local px, py = vecX(p), vecY(p)
    local ax, ay = vecX(a), vecY(a)
    local bx, by = vecX(b), vecY(b)
    local abx, aby = bx - ax, by - ay
    local apx, apy = px - ax, py - ay
    local abLenSqr = abx * abx + aby * aby
    local proj = abLenSqr > 0 and ((apx * abx + apy * aby) / abLenSqr) or 0
    proj = math.max(0, math.min(1, proj))
    local cx, cy = ax + abx * proj, ay + aby * proj
    local dx, dy = px - cx, py - cy
    return math.sqrt(dx * dx + dy * dy)
end

local function distToLanePath(pos, laneName)
    local path = LANE_PATHS[laneName]
    if not path then return math.huge end

    local best = math.huge
    for i = 1, #path - 1 do
        local d = distPointToSegment2D(pos, path[i], path[i + 1])
        if d < best then best = d end
    end
    return best
end

local function classifyLane(pos)
    local bestLane, bestDist = "mid", math.huge
    for _, lane in ipairs(LANE_ORDER) do
        local d = distToLanePath(pos, lane)
        if d < bestDist then
            bestDist = d
            bestLane = lane
        end
    end
    return bestLane
end

local function laneDefensivePressure(pos, team)
    local ownBase = basePosition(team)
    local enemyBase = enemyBasePosition(team)
    local total = math.max(1, dist2D(ownBase, enemyBase))
    local intoOurSide = dist2D(pos, ownBase)
    return math.max(0, total - intoOurSide) / total
end

local function collectEnemyAwarenessImpl(team, t)
    local result = {}
    local heroes = sc(Heroes.GetAll) or {}
    local useMaphack = pushMaphackEnabled()
    local maxAge = pushMaphackMemory()

    for _, hero in ipairs(heroes) do
        if alive(hero) and sc(Entity.GetTeamNum, hero) ~= team and sc(NPC.IsIllusion, hero) ~= true then
            local pos = nil
            local visibleNow = visible(hero)
            local age = 0

            if visibleNow then
                pos = origin(hero)
            elseif useMaphack then
                pos = sc(Hero.GetLastMaphackPos, hero)
                local lastVisible = sc(Hero.GetLastVisibleTime, hero)
                if pos and type(lastVisible) == "number" then
                    age = math.max(0, t - lastVisible)
                else
                    age = 999
                end
                if age > maxAge then
                    pos = nil
                end
            end

            if pos then
                result[#result + 1] = {
                    hero = hero,
                    pos = pos,
                    visible = visibleNow,
                    age = age
                }
            end
        end
    end

    return result
end

collectEnemyAwareness = collectEnemyAwarenessImpl

local function newLaneBucket(lane)
    return {
        lane = lane,
        enemyCreeps = {},
        alliedCreeps = {},
        structures = {},
        pressure = 0,
    }
end

local function buildLaneBuckets(team, t)
    local allied, enemy = collectLaneCreeps(team, t)
    local structures = collectPushStructures(team, t)
    local buckets = {
        top = newLaneBucket("top"),
        mid = newLaneBucket("mid"),
        bot = newLaneBucket("bot"),
    }

    for _, creep in ipairs(enemy) do
        local lane = classifyLane(creep.pos)
        local bucket = buckets[lane]
        bucket.enemyCreeps[#bucket.enemyCreeps + 1] = creep
        local weight = laneDefensivePressure(creep.pos, team)
        bucket.pressure = bucket.pressure
            + 420 * weight
            + pushTargetPriority(creep.name) * weight
            + weight * 180
    end

    for _, creep in ipairs(allied) do
        local lane = classifyLane(creep.pos)
        buckets[lane].alliedCreeps[#buckets[lane].alliedCreeps + 1] = creep
    end

    for _, structure in ipairs(structures) do
        local lane = classifyLane(structure.pos)
        buckets[lane].structures[#buckets[lane].structures + 1] = structure
    end

    for _, lane in ipairs(LANE_ORDER) do
        local bucket = buckets[lane]
        local relief = 0
        for _, creep in ipairs(bucket.alliedCreeps) do
            relief = relief + laneDefensivePressure(creep.pos, team) * 90
        end
        bucket.pressure = math.max(0, bucket.pressure - relief)
    end

    return buckets
end

local function lanePathCenter(laneName)
    local path = LANE_PATHS[laneName]
    if not path or #path == 0 then return nil end
    return path[math.floor((#path + 1) / 2)]
end

local function computeLaneAnchor(bucket, team)
    local bestPos, bestPressure = nil, -1

    for _, creep in ipairs(bucket.enemyCreeps) do
        local pressure = laneDefensivePressure(creep.pos, team)
        if pressure > bestPressure then
            bestPressure = pressure
            bestPos = creep.pos
        end
    end

    if bestPos then return bestPos end

    if #bucket.enemyCreeps > 0 then
        local sx, sy, sz, count = 0, 0, 0, 0
        for _, creep in ipairs(bucket.enemyCreeps) do
            sx = sx + vecX(creep.pos)
            sy = sy + vecY(creep.pos)
            sz = sz + vecZ(creep.pos)
            count = count + 1
        end
        return Vector(sx / count, sy / count, sz / count)
    end

    if pushStructuresEnabled() and #bucket.structures > 0 then
        return bucket.structures[1].pos
    end

    return lanePathCenter(bucket.lane)
end

local function laneThreatInfo(pos, awareness, t)
    local danger, age, visibleNow = nearestAwarenessInfo(awareness, pos)
    local memory = minDistanceToEnemyAvoid(pos, t)
    local radius = enemyAvoidRadius()
    local memoryAge = pushMaphackMemory()
    local freshness = visibleNow and 1 or math.max(0, 1 - age / memoryAge)
    local threatRadius = radius * (0.72 + freshness * 0.58)
    local nearest = math.min(danger, memory)
    local unsafe = nearest < threatRadius or memory < radius * 0.85
    return unsafe, nearest, threatRadius, freshness, visibleNow
end

local function buildLanePushObjective(laneName, bucket, units, team, t, awareness)
    local anchor = computeLaneAnchor(bucket, team)
    if not anchor then return nil, nil end

    local unsafe, dangerDist = laneThreatInfo(anchor, awareness, t)
    if unsafe then return nil, nil end

    local alliedLaneCreeps, enemyLaneCreeps = collectLaneCreeps(team, t)
    local structures = bucket.structures
    local bestWave, bestWaveScore = nil, -math.huge

    for _, creep in ipairs(bucket.enemyCreeps) do
        local d = dist2D(creep.pos, anchor)
        if d <= pushWaveRadius() then
            local score = 260
                + pushTargetPriority(creep.name)
                + laneDefensivePressure(creep.pos, team) * 420
                - d * 0.24
                - creep.hp * 0.08
                - minDistanceToUnits(creep.pos, units) * 0.25
            if score > bestWaveScore then
                bestWave = creep.unit
                bestWaveScore = score
            end
        end
    end

    local bestStructure, bestStructureScore = nil, -math.huge
    if pushStructuresEnabled() then
        for _, structure in ipairs(structures) do
            local d = dist2D(structure.pos, anchor)
            if d <= pushStructureRadius() then
                local support = countEntriesNear(alliedLaneCreeps, structure.pos, pushSupportRadius())
                local score = structurePushBonus(structure.kind, support) - d * 0.18
                if widgetGet(ui.pushTowerSafety, true) then
                    local structUnsafe = select(1, laneThreatInfo(structure.pos, awareness, t))
                    if structUnsafe then
                        score = score - 5000
                    end
                end
                if score > bestStructureScore then
                    bestStructure = structure.unit
                    bestStructureScore = score
                end
            end
        end
    end

    local target = bestWave
    local reason = "enemy_wave"
    if bestStructure and bestStructureScore > bestWaveScore + 180 then
        target = bestStructure
        reason = pushTargetLabel(bestStructure, "structure")
    elseif not target and bestStructure then
        target = bestStructure
        reason = pushTargetLabel(bestStructure, "structure")
    end

    local support = countEntriesNear(alliedLaneCreeps, anchor, pushSupportRadius())
    return {
        id = "push_" .. laneName,
        lane = laneName,
        center = anchor,
        target = target,
        count = target and 1 or 0,
        isPush = true,
        reason = reason,
    }, {
        label = pushTargetLabel(target, laneName),
        lane = laneName,
        score = bucket.pressure,
        support = support,
        danger = dangerDist,
    }
end

local function rankLanesForPush(buckets, team, t, awareness)
    local ranked = {}

    for _, lane in ipairs(LANE_ORDER) do
        local bucket = buckets[lane]
        local anchor = computeLaneAnchor(bucket, team)
        if anchor then
            local unsafe, dangerDist, threatRadius = laneThreatInfo(anchor, awareness, t)
            local score = bucket.pressure
            if #bucket.enemyCreeps > 0 then
                score = score + 120
            end
            if pushStructuresEnabled() and #bucket.structures > 0 then
                score = score + 80
            end
            if unsafe then
                score = score - 2400 - math.max(0, threatRadius - dangerDist) * 0.65
            else
                score = score + pushProgressScore(anchor, team) * 0.25
            end

            if score > 0 or #bucket.enemyCreeps > 0 or (#bucket.structures > 0 and pushStructuresEnabled()) then
                ranked[#ranked + 1] = {
                    lane = lane,
                    bucket = bucket,
                    anchor = anchor,
                    score = score,
                    safe = not unsafe,
                    danger = dangerDist,
                }
            end
        end
    end

    table.sort(ranked, function(a, b)
        if a.safe ~= b.safe then return a.safe end
        if a.score == b.score then return a.lane < b.lane end
        return a.score > b.score
    end)

    return ranked
end

buildPushGroups = function(units, baseIndex, team, t)
    local groups = {}
    local reserves = {}
    local debug = {lanes = {}}
    local awareness = collectEnemyAwareness(team, t)
    for _, enemy in ipairs(awareness) do
        if enemy.pos then
            rememberEnemyAvoid(enemy.pos, t)
        end
    end
    local buckets = buildLaneBuckets(team, t)
    local ranked = rankLanesForPush(buckets, team, t, awareness)

    for _, unit in ipairs(units or {}) do
        reserves[#reserves + 1] = unit
    end

    if #reserves < 2 then
        return groups, reserves, nil
    end

    local pool = reserves
    reserves = {}
    local usedLanes = {}

    while #pool >= 2 do
        local pickedEntry = nil
        for _, entry in ipairs(ranked) do
            if not usedLanes[entry.lane] and entry.safe then
                pickedEntry = entry
                break
            end
        end

        if not pickedEntry then
            for _, entry in ipairs(ranked) do
                if not usedLanes[entry.lane] then
                    pickedEntry = entry
                    break
                end
            end
        end

        if not pickedEntry then break end

        local objective, debugInfo = buildLanePushObjective(pickedEntry.lane, pickedEntry.bucket, pool, team, t, awareness)
        usedLanes[pickedEntry.lane] = true
        if not objective then
            goto continue_push
        end

        local chosen
        chosen, pool = takeNearestUnits(pool, objective.center, 2)
        if not chosen then break end

        objective.id = "push_" .. pickedEntry.lane .. "_" .. tostring(baseIndex + #groups + 1)
        local group = newGroup(baseIndex + #groups + 1, objective, chosen, "PUSH", 2)
        groups[#groups + 1] = group

        debug.lanes[#debug.lanes + 1] = string.format(
            "%s:%s (%.0f)",
            pickedEntry.lane,
            debugInfo and debugInfo.label or "?",
            pickedEntry.score or 0
        )
        if not debug.label and debugInfo then
            debug.label = debugInfo.label
            debug.score = debugInfo.score
            debug.support = debugInfo.support
            debug.danger = debugInfo.danger
        end

        ::continue_push::
    end

    for _, unit in ipairs(pool) do
        reserves[#reserves + 1] = unit
    end

    if #debug.lanes == 0 then
        debug = nil
    end

    return groups, reserves, debug
end

syncSmartMode = function(t, team)
    if not widgetGet(ui.smartMode, false) then return end
    if t < (state.smartModeSwitchAt or 0) then return end

    local buckets = buildLaneBuckets(team, t)
    local totalPressure = 0
    local lanesWithCreeps = 0

    for _, lane in ipairs(LANE_ORDER) do
        local bucket = buckets[lane]
        totalPressure = totalPressure + bucket.pressure
        if #bucket.enemyCreeps > 0 then
            lanesWithCreeps = lanesWithCreeps + 1
        end
    end

    if isPushActive() and lanesWithCreeps == 0 and totalPressure < 200 then
        if ui.autoPush and ui.autoPush.Set then sc(ui.autoPush.Set, ui.autoPush, false) end
        if ui.farmActive and ui.farmActive.Set then sc(ui.farmActive.Set, ui.farmActive, true) end
        state.smartModeSwitchAt = t + SMART_MODE_COOLDOWN
        state.lastMode = "farm"
    elseif isFarmActive() and lanesWithCreeps >= 2 and totalPressure > 800 then
        if ui.farmActive and ui.farmActive.Set then sc(ui.farmActive.Set, ui.farmActive, false) end
        if ui.autoPush and ui.autoPush.Set then sc(ui.autoPush.Set, ui.autoPush, true) end
        state.smartModeSwitchAt = t + SMART_MODE_COOLDOWN
        state.lastMode = "push"
    end
end
end

local buildGroups, collectNeutrals
local issueMove, issueAttack, runPackFarm

do
campWaitPosition = function(center, team)
    if not center then return nil end

    local base = basePosition(team)
    local dx = vecX(base) - vecX(center)
    local dy = vecY(base) - vecY(center)
    local len = math.sqrt(dx * dx + dy * dy)

    if len < 1 then
        dx, dy, len = 1, 0, 1
    end

    local distance = RESPAWN_WAIT_DISTANCE
    return Vector(
        vecX(center) + dx / len * distance,
        vecY(center) + dy / len * distance,
        vecZ(center)
    )
end

desiredGroupSize = function(camp, role, poolSize)
    local size = math.max(1, poolSize)
    if not widgetGet(ui.flexGroups, true) then
        if role == "SCOUT" then return 1 end
        return math.min(2, size)
    end
    local minS = math.max(1, widgetGet(ui.groupMin, 1))
    local maxS = math.max(minS, widgetGet(ui.groupMax, 3))
    if role == "SCOUT" and (not camp or not camp.target) then return 1 end
    if camp and camp.isAncient then return math.max(minS, math.min(maxS, size, 3)) end
    if camp and (camp.count or 0) >= 4 then return math.max(minS, math.min(maxS, size, 3)) end
    if size == 1 then return 1 end
    return math.max(minS, math.min(maxS, size, 2))
end

campPriorityScore = function(info, pool, t)
    local score = minDistanceToUnits(info.center, pool)
    local sticky = 0
    for _, unit in ipairs(pool) do
        local uid = unitId(unit)
        if state.unitCamp[uid] == info.id or state.unitFightCamp[uid] == info.id then
            sticky = sticky + 1
        end
    end
    score = score - (info.count or 0) * 90 - sticky * 350
    if widgetGet(ui.stackPrep, true) and not info.target then
        if secondsToNextMinute() <= STACK_PREP_WINDOW then
            score = score - 520
        end
    end
    if info.isAncient then score = score - 160 end
    return score
end

local function packCenter(units)
    local sx, sy, sz, count = 0, 0, 0, 0
    for _, unit in ipairs(units) do
        local pos = origin(unit)
        if pos then
            sx = sx + vecX(pos)
            sy = sy + vecY(pos)
            sz = sz + vecZ(pos)
            count = count + 1
        end
    end

    if count == 0 then return nil end
    return Vector(sx / count, sy / count, sz / count)
end

formationPosition = function(center, index, count)
    if not center or count <= 1 then return center end
    local radius = math.min(140, math.max(45, widgetGet(ui.joinRadius, 560) * 0.18))
    local angle = ((index - 1) / count) * math.pi * 2
    return Vector(
        vecX(center) + math.cos(angle) * radius,
        vecY(center) + math.sin(angle) * radius,
        vecZ(center)
    )
end

local function isValidNeutral(unit)
    if not unit or not alive(unit) or dormant(unit) then return false end
    if sc(NPC.IsWaitingToSpawn, unit) == true then return false end
    if sc(NPC.IsInvulnerable, unit) == true then return false end

    local neutral = sc(NPC.IsNeutral, unit)
    if neutral ~= true then
        local name = unitName(unit)
        if not string.find(name, "npc_dota_neutral_", 1, true) then return false end
    end

    if not widgetGet(ui.farmAncients, false) and sc(NPC.IsAncient, unit) == true then
        return false
    end

    return origin(unit) ~= nil
end

collectNeutrals = function(t)
    local cache = getTickCache(t)
    if cache.neutrals then return cache.neutrals end

    local result = {}
    local npcs = sc(NPCs.GetAll) or {}

    for _, unit in ipairs(npcs) do
        if isValidNeutral(unit) then
            result[#result + 1] = {
                unit = unit,
                pos = origin(unit),
                hp = sc(Entity.GetHealth, unit) or 99999
            }
        end
    end

    cache.neutrals = result
    return result
end

campCenter = function(camp)
    local box = sc(Camp.GetCampBox, camp)
    if not box or not box.min or not box.max then return nil end

    return Vector(
        (vecX(box.min) + vecX(box.max)) / 2,
        (vecY(box.min) + vecY(box.max)) / 2,
        (vecZ(box.min) + vecZ(box.max)) / 2
    )
end

campAllowed = function(camp)
    if widgetGet(ui.farmAncients, false) then return true end
    local ancientType = Enum.ECampType and Enum.ECampType.ECampType_ANCIENT
    if ancientType == nil then return true end
    local campType = sc(Camp.GetType, camp)
    return campType ~= ancientType
end

hasSelectedCamps = function()
    for _, selected in pairs(state.selectedCamps) do
        if selected == true then return true end
    end
    return false
end

selectedCampCount = function()
    local count = 0
    for _, selected in pairs(state.selectedCamps) do
        if selected == true then count = count + 1 end
    end
    return count
end

local function campAllowedBySelection(info)
    if not info then return false end
    if not hasSelectedCamps() then return true end
    return state.selectedCamps[info.id] == true
end

nextNeutralSpawnTime = function(t)
    return t + secondsToNextMinute() + EMPTY_LOCK_EXTRA
end

getCampMemory = function(campId)
    local memory = state.campMemory[campId]
    if not memory then
        memory = {}
        state.campMemory[campId] = memory
    end
    return memory
end

local function updateCampMemory(info, t)
    if not info or info.id == nil then return info end

    local memory = getCampMemory(info.id)
    memory.center = info.center
    memory.lastUpdate = t

    if info.target and info.count > 0 then
        memory.hadCreeps = true
        memory.lastSeen = t
        memory.waitUntil = nil
        state.emptyUntil[info.id] = nil
    end

    info.memory = memory
    info.waitUntil = memory.waitUntil
    info.waitPos = memory.waitPos
    return info
end

shouldWaitCamp = function(info, t)
    if not info or info.target then return false end

    local memory = state.campMemory[info.id]
    return memory and memory.waitUntil and t < memory.waitUntil
end

local function buildCampInfo(camp, index, neutrals)
    if not campAllowed(camp) then return nil end

    local center = campCenter(camp)
    if not center then return nil end

    local radius = widgetGet(ui.campRadius, 760)
    local radiusSqr = radius * radius
    local count = 0
    local target = nil
    local bestTargetScore = math.huge

    for _, neutral in ipairs(neutrals) do
        local dSqr = dist2DSqr(center, neutral.pos)
        if dSqr <= radiusSqr then
            local d = math.sqrt(dSqr)
            count = count + 1
            local score = neutral.hp + d * 0.05
            if score < bestTargetScore then
                bestTargetScore = score
                target = neutral.unit
            end
        end
    end

    local isAncient = false
    local ancientType = Enum.ECampType and Enum.ECampType.ECampType_ANCIENT
    if ancientType ~= nil and sc(Camp.GetType, camp) == ancientType then
        isAncient = true
    end

    return {
        id = index,
        center = center,
        target = target,
        count = count,
        isAncient = isAncient
    }
end

collectCampInfos = function(neutrals, t)
    local cache = getTickCache(t)
    if cache.campInfos then return cache.campInfos end

    local infos = {}
    local camps = sc(Camps.GetAll)

    if camps and #camps > 0 then
        for i, camp in ipairs(camps) do
            local info = updateCampMemory(buildCampInfo(camp, i, neutrals), t)
            if info and campAllowedBySelection(info) then
                infos[#infos + 1] = info
            end
        end
        cache.campInfos = infos
        return infos
    end

    for _, neutral in ipairs(neutrals) do
        infos[#infos + 1] = {
            id = "neutral_" .. tostring(unitId(neutral.unit)),
            center = neutral.pos,
            target = neutral.unit,
            count = 1,
            memory = getCampMemory("neutral_" .. tostring(unitId(neutral.unit)))
        }
    end

    cache.campInfos = infos
    return infos
end

minDistanceToUnits = function(center, units)
    local best = math.huge

    for _, unit in ipairs(units) do
        local pos = origin(unit)
        if pos then
            local d = dist2D(pos, center)
            if d < best then best = d end
        end
    end

    return best
end

takeNearestUnits = function(pool, center, count)
    if #pool < count then return nil, pool end

    local scored = {}
    for _, unit in ipairs(pool) do
        scored[#scored + 1] = {
            unit = unit,
            distance = dist2D(origin(unit), center)
        }
    end

    table.sort(scored, function(a, b)
        if a.distance == b.distance then
            return unitId(a.unit) < unitId(b.unit)
        end
        return a.distance < b.distance
    end)

    local chosen, chosenIds = {}, {}
    for i = 1, count do
        local unit = scored[i] and scored[i].unit
        if unit then
            chosen[#chosen + 1] = unit
            chosenIds[unitId(unit)] = true
        end
    end

    if #chosen < count then return nil, pool end

    local remaining = {}
    for _, unit in ipairs(pool) do
        if not chosenIds[unitId(unit)] then
            remaining[#remaining + 1] = unit
        end
    end

    return chosen, remaining
end

takePreferredUnits = function(pool, center, count, campId)
    if #pool < count then return nil, pool end

    local scored = {}
    for _, unit in ipairs(pool) do
        local preferred = state.unitCamp[unitId(unit)] == campId
        scored[#scored + 1] = {
            unit = unit,
            distance = dist2D(origin(unit), center) - (preferred and 100000 or 0)
        }
    end

    table.sort(scored, function(a, b)
        if a.distance == b.distance then
            return unitId(a.unit) < unitId(b.unit)
        end
        return a.distance < b.distance
    end)

    local chosen, chosenIds = {}, {}
    for i = 1, count do
        local unit = scored[i] and scored[i].unit
        if unit then
            chosen[#chosen + 1] = unit
            chosenIds[unitId(unit)] = true
        end
    end

    if #chosen < count then return nil, pool end

    local remaining = {}
    for _, unit in ipairs(pool) do
        if not chosenIds[unitId(unit)] then
            remaining[#remaining + 1] = unit
        end
    end

    return chosen, remaining
end

newGroup = function(index, camp, units, role, minSize)
    local group = {
        index = index,
        camp = camp,
        units = {},
        roles = {},
        role = role or "FARM",
        minSize = minSize or #(units or {})
    }

    for _, unit in ipairs(units or {}) do
        group.units[#group.units + 1] = unit
        group.roles[unitId(unit)] = group.role
    end

    return group
end

local function addUnitToGroup(group, unit, role)
    if not group or not unit then return end

    group.units[#group.units + 1] = unit
    group.roles[unitId(unit)] = role or "HELP"
end

groupCenter = function(group)
    if not group or not group.units then return nil end
    return packCenter(group.units) or (group.camp and group.camp.center)
end

local function nearestGroup(unit, groups)
    local unitPos = origin(unit)
    local best, bestDist = nil, math.huge

    for _, group in ipairs(groups) do
        local campPos = group.camp and group.camp.center
        local center = campPos or groupCenter(group)
        local d = dist2D(unitPos, center)
        if d < bestDist then
            bestDist = d
            best = group
        end
    end

    return best
end

reserveAnchorPosition = function(groups, team)
    if state.localHero and alive(state.localHero) then
        local heroPos = origin(state.localHero)
        if heroPos then return heroPos end
    end

    for _, group in ipairs(groups or {}) do
        local center = groupCenter(group)
        if center then return center end
    end

    return basePosition(team)
end

storeActiveGroups = function(groups)
    state.activeGroups = {}

    for _, group in ipairs(groups or {}) do
        local targetPos = nil
        if group.camp then
            targetPos = (group.camp.target and origin(group.camp.target)) or group.camp.center or group.camp.waitPos
        end

        state.activeGroups[#state.activeGroups + 1] = {
            index = group.index,
            role = group.role,
            lane = group.camp and group.camp.lane or nil,
            isPush = group.camp and group.camp.isPush == true,
            targetPos = targetPos,
            groupPos = groupCenter(group),
            unitCount = #group.units,
            waitUntil = group.camp and group.camp.waitUntil or nil
        }
    end
end

enemyAvoidRadius = function()
    return widgetGet(ui.enemyAvoidRadius, DEFAULT_ENEMY_RADIUS)
end

pruneEnemyAvoid = function(t)
    for i = #state.enemyAvoid, 1, -1 do
        if not state.enemyAvoid[i].pos or t >= (state.enemyAvoid[i].untilTime or 0) then
            table.remove(state.enemyAvoid, i)
        end
    end
end

rememberEnemyAvoid = function(pos, t)
    if not pos then return end
    for _, danger in ipairs(state.enemyAvoid) do
        if danger.pos and isWithin2D(danger.pos, pos, 250) then
            danger.pos = pos
            danger.untilTime = t + ENEMY_AVOID_TIME
            return
        end
    end

    state.enemyAvoid[#state.enemyAvoid + 1] = {
        pos = pos,
        untilTime = t + ENEMY_AVOID_TIME
    }
end

minDistanceToEnemyAvoid = function(pos, t)
    pruneEnemyAvoid(t)
    local best = math.huge

    for _, danger in ipairs(state.enemyAvoid) do
        local d = dist2D(pos, danger.pos)
        if d < best then best = d end
    end

    return best
end

campSafeFromEnemies = function(info, t)
    if not widgetGet(ui.avoidEnemies, true) then return true end
    return minDistanceToEnemyAvoid(info.center, t) > enemyAvoidRadius()
end

buildGroups = function(active, neutrals, t, team)
    local groups = {}
    local reserves = {}

    if #active == 0 then
        return groups, reserves
    end

    local pool = {}
    for _, unit in ipairs(active) do pool[#pool + 1] = unit end

    local function makeGroup(camp, role, preferred)
        local size = desiredGroupSize(camp, role, #pool)
        if size < 1 or #pool < size then return false end

        local chosen
        if preferred then
            chosen, pool = takePreferredUnits(pool, camp.center, size, camp.id)
        else
            chosen, pool = takeNearestUnits(pool, camp.center, size)
        end

        if not chosen then return false end

        local group = newGroup(#groups + 1, camp, chosen, role, size)
        groups[#groups + 1] = group
        return true
    end

    local infos = collectCampInfos(neutrals, t)
    local waitingSoon, waitingLater, visible, scouts = {}, {}, {}, {}

    for _, info in ipairs(infos) do
        if not campSafeFromEnemies(info, t) then
            -- Dangerous camps are skipped until the last visible enemy position expires.
        elseif shouldWaitCamp(info, t) then
            local waitRemaining = math.max(0, (info.waitUntil or t) - t)
            if waitRemaining <= FAST_WAIT_WINDOW then
                waitingSoon[#waitingSoon + 1] = info
            else
                waitingLater[#waitingLater + 1] = info
            end
        elseif info.target and info.count > 0 then
            visible[#visible + 1] = info
        elseif t >= (state.emptyUntil[info.id] or 0) then
            scouts[#scouts + 1] = info
        end
    end

    local function sortWaiting(list)
        table.sort(list, function(a, b)
            local da = minDistanceToUnits(a.center, pool)
            local db = minDistanceToUnits(b.center, pool)
            if da == db then return tostring(a.id) < tostring(b.id) end
            return da < db
        end)
    end

    sortWaiting(waitingSoon)
    sortWaiting(waitingLater)

    table.sort(visible, function(a, b)
        local da = campPriorityScore(a, pool, t)
        local db = campPriorityScore(b, pool, t)
        if da == db then return tostring(a.id) < tostring(b.id) end
        return da < db
    end)

    local usedCamps = {}
    for _, camp in ipairs(visible) do
        if #pool < 1 then break end
        if not usedCamps[camp.id] then
            if makeGroup(camp, "FARM", true) then
                usedCamps[camp.id] = true
            end
        end
    end

    for _, camp in ipairs(waitingSoon) do
        if #pool < 1 then break end
        if not usedCamps[camp.id] and makeGroup(camp, "WAIT", true) then
            local group = groups[#groups]
            camp.waitPos = camp.waitPos or campWaitPosition(camp.center, team)
            group.camp.waitPos = camp.waitPos
            usedCamps[camp.id] = true
        end
    end

    while #pool >= 1 and #scouts > 0 do
        local bestIndex, bestCamp, bestScore = nil, nil, math.huge

        for index, camp in ipairs(scouts) do
            if not usedCamps[camp.id] then
                local score = campPriorityScore(camp, pool, t)
                if score < bestScore then
                    bestIndex = index
                    bestCamp = camp
                    bestScore = score
                end
            end
        end

        if not bestCamp then break end

        if makeGroup(bestCamp, "SCOUT", false) then
            usedCamps[bestCamp.id] = true
        end

        table.remove(scouts, bestIndex)
    end

    for _, camp in ipairs(waitingLater) do
        if #pool < 1 then break end
        if not usedCamps[camp.id] and makeGroup(camp, "WAIT", true) then
            local group = groups[#groups]
            camp.waitPos = camp.waitPos or campWaitPosition(camp.center, team)
            group.camp.waitPos = camp.waitPos
            usedCamps[camp.id] = true
        end
    end

    for _, unit in ipairs(pool) do
        reserves[#reserves + 1] = unit
    end

    return groups, reserves
end

countNear = function(units, pos, radius)
    local count = 0
    for _, unit in ipairs(units) do
        local upos = origin(unit)
        if upos and isWithin2D(upos, pos, radius) then
            count = count + 1
        end
    end
    return count
end

collectVisibleEnemyHeroes = function(team, t)
    local cache = getTickCache(t)
    if cache.enemyHeroes then return cache.enemyHeroes end

    local result = {}
    local heroes = sc(Heroes.GetAll) or {}

    for _, hero in ipairs(heroes) do
        if alive(hero) and visible(hero) and sc(Entity.GetTeamNum, hero) ~= team and sc(NPC.IsIllusion, hero) ~= true then
            local pos = origin(hero)
            if pos then
                result[#result + 1] = {
                    hero = hero,
                    pos = pos
                }
            end
        end
    end

    cache.enemyHeroes = result
    return result
end

end

do
local function visibleEnemyNearUnit(unit, visibleEnemies, radius)
    local pos = origin(unit)
    if not pos then return nil end

    local bestHero, bestPos = nil, nil
    local bestDistSqr = radius * radius
    for _, enemy in ipairs(visibleEnemies or {}) do
        local dSqr = dist2DSqr(pos, enemy.pos)
        if dSqr <= bestDistSqr then
            bestHero = enemy.hero
            bestPos = enemy.pos
            bestDistSqr = dSqr
        end
    end

    return bestHero, bestPos
end

local function canOrder(unit, orderType, target, pos, t)
    local id = unitId(unit)
    local last = state.lastOrder[id]
    local delay = math.max(0.05, widgetGet(ui.orderDelay, 320) / 1000)
    local jitter = 0
    local maxJitter = widgetGet(ui.orderJitter, 60) / 1000
    if maxJitter > 0 then
        jitter = ((id * 17 + math.floor(t * 10)) % 1000) / 1000 * maxJitter
    end

    if last and t - last.time < delay + jitter then return false end

    if orderType == "move" then
        local upos = origin(unit)
        if upos and pos and isWithin2D(upos, pos, 110) then return false end
        if last and last.type == "move" and last.pos and pos and isWithin2D(last.pos, pos, 140) and t - last.time < 1.2 then
            return false
        end
    elseif orderType == "attack" then
        if not target or not alive(target) then return false end
        local currentTarget = Entity.GetAttackTarget and sc(Entity.GetAttackTarget, unit)
        if currentTarget == target and last and t - last.time < 1.0 then return false end
        if last and last.type == "attack" and last.targetId == unitId(target) and t - last.time < 0.75 then
            return false
        end
    end

    return true
end

local function rememberOrder(unit, orderType, target, pos, t)
    state.lastOrder[unitId(unit)] = {
        type = orderType,
        targetId = target and unitId(target) or nil,
        pos = pos,
        time = t
    }
end

local function safeMovePosition(unit, pos)
    if not pos or not unit then return pos end
    if not widgetGet(ui.pathCheck, true) or not GridNav or not GridNav.IsTraversableFromTo then return pos end
    local from = origin(unit)
    if not from then return pos end
    if sc(GridNav.IsTraversableFromTo, from, pos, false, nil) == true then return pos end
    return from
end

local function tryMobilityMove(player, unit, pos, t)
    if not widgetGet(ui.useMobility, true) or not player or not unit or not pos then return false end
    if sc(NPC.IsChannellingAbility, unit) == true then return false end

    local upos = origin(unit)
    if not upos or dist2D(upos, pos) < 900 then return false end

    local mana = sc(NPC.GetMana, unit) or 0
    local blink = sc(NPC.GetItem, unit, "item_blink", true)
        or sc(NPC.GetItem, unit, "item_overwhelming_blink", true)
        or sc(NPC.GetItem, unit, "item_swift_blink", true)
        or sc(NPC.GetItem, unit, "item_arcane_blink", true)
    if blink and sc(Ability.IsCastable, blink, mana) == true then
        sc(Ability.CastPosition, blink, pos, false, true, false, ORDER_PREFIX .. "blink", true)
        rememberOrder(unit, "move", nil, pos, t)
        return true
    end

    local phase = sc(NPC.GetItem, unit, "item_phase_boots", true)
    if phase and sc(Ability.IsCastable, phase, mana) == true then
        sc(Ability.Toggle, phase, false, true, false, ORDER_PREFIX .. "phase")
    end

    return false
end

issueMove = function(player, unit, pos, t)
    pos = safeMovePosition(unit, pos)
    if not player or not unit or not pos or not canOrder(unit, "move", nil, pos, t) then return false end
    if tryMobilityMove(player, unit, pos, t) then return true end
    sc(Player.PrepareUnitOrders, player, O_MOVE, nil, pos, nil, ISSUER, unit, false, false, false, false, ORDER_PREFIX .. "move", false)
    rememberOrder(unit, "move", nil, pos, t)
    return true
end

issueAttack = function(player, unit, target, t)
    if not player or not unit or not target or not canOrder(unit, "attack", target, nil, t) then return false end
    sc(Player.PrepareUnitOrders, player, O_ATTACK, target, Vector(), nil, ISSUER, unit, false, false, false, false, ORDER_PREFIX .. "attack", false)
    rememberOrder(unit, "attack", target, nil, t)
    return true
end

local function handleReserveUnits(player, reserves, groups, t, team)
    if not reserves or #reserves == 0 then return end

    local anchor = reserveAnchorPosition(groups, team)
    local heroId = unitId(state.localHero)
    local smart = widgetGet(ui.smartReserve, true)
    local base = basePosition(team)

    for index, unit in ipairs(reserves) do
        local id = unitId(unit)
        state.unitCamp[id] = nil

        if needsManaRefill(unit) then
            setStatus(unit, L("status_regen"), statusColor.base)
            issueMove(player, unit, base, t)
        elseif smart and #groups > 0 then
            local bestGroup, bestNeed = nil, -1
            for _, group in ipairs(groups) do
                if group.camp and group.camp.center then
                    local joinPos = (group.camp.target and alive(group.camp.target) and origin(group.camp.target))
                        or group.camp.center
                    local near = countNear(group.units, joinPos, widgetGet(ui.joinRadius, 560))
                    local need = (group.minSize or #group.units) - near
                    if need > bestNeed then
                        bestNeed = need
                        bestGroup = group
                    end
                end
            end

            if bestGroup and bestNeed > 0 then
                setStatus(unit, L("status_help") .. " G" .. bestGroup.index, statusColor.help, bestGroup.index)
                local joinPos = (bestGroup.camp.target and alive(bestGroup.camp.target) and origin(bestGroup.camp.target))
                    or bestGroup.camp.center
                issueMove(player, unit, formationPosition(joinPos, index, #reserves), t)
            else
                setStatus(unit, L("status_reserve"), statusColor.move)
                if heroId ~= id and anchor then
                    issueMove(player, unit, formationPosition(anchor, index, #reserves), t)
                end
            end
        else
            setStatus(unit, L("status_reserve"), statusColor.move)
            if heroId ~= id and anchor then
                issueMove(player, unit, formationPosition(anchor, index, #reserves), t)
            end
        end
    end
end


local function canSpendMana(unit)
    return manaPct(unit) > widgetGet(ui.saveMana, 40)
end

local function canUsePoofCandidate(unit, candidate)
    return candidate
        and unitId(candidate) ~= unitId(unit)
        and alive(candidate)
        and isMeepo(candidate)
end

local function findBestPoofTarget(unit, destination, mode, anchorUnits)
    local unitPos = origin(unit)
    if not unitPos or not destination then return nil end

    local bestTarget = nil
    local bestScore = math.huge
    local currentDist = dist2D(unitPos, destination)
    local seen = {}

    local function consider(candidate, bias)
        if not canUsePoofCandidate(unit, candidate) then return end

        local id = unitId(candidate)
        if seen[id] then return end
        seen[id] = true

        local candidatePos = origin(candidate)
        if not candidatePos then return end

        local candidateDist = dist2D(candidatePos, destination)
        if mode == "damage" then
            if candidateDist > 425 then return end
        else
            if candidateDist >= currentDist - 250 then return end
        end

        local score = candidateDist + (bias or 0)
        if score < bestScore then
            bestScore = score
            bestTarget = candidate
        end
    end

    for _, candidate in ipairs(anchorUnits or {}) do
        consider(candidate, 0)
    end

    local cachedUnits = state.tickCache and state.tickCache.meepos or nil
    for _, candidate in ipairs(cachedUnits or {}) do
        consider(candidate, 25)
    end

    consider(state.localHero, 10)
    return bestTarget
end

local function tryPoof(unit, pos, t, mode, anchorUnits)
    if not unit or not pos then return false end
    if mode == "move" and not multiEnabled(ui.poofUsage, LAll("poof_move")) then return false end
    if mode == "damage" and not multiEnabled(ui.poofUsage, LAll("poof_damage")) then return false end
    if not canSpendMana(unit) then return false end

    local upos = origin(unit)
    if not upos then return false end

    local distance = dist2D(upos, pos)
    if mode == "move" and distance < widgetGet(ui.poofDistance, 1350) then return false end
    if mode == "escape" and distance < 850 then return false end
    if mode == "damage" and distance > 575 then return false end
    if sc(NPC.IsChannellingAbility, unit) == true then return false end

    local id = unitId(unit)
    if t - (state.lastPoof[id] or 0) < widgetGet(ui.poofCooldown, 3) then return false end

    local poof = sc(NPC.GetAbility, unit, "meepo_poof")
    local mana = sc(NPC.GetMana, unit) or 0
    if poof and sc(Ability.IsCastable, poof, mana) == true then
        local target = findBestPoofTarget(unit, pos, mode, anchorUnits)
        if not target then return false end

        sc(Ability.CastTarget, poof, target, false, true, false, ORDER_PREFIX .. "poof")
        state.lastPoof[id] = t
        return true
    end

    return false
end

local function tryTeleportEscape(unit, pos, t, team)
    if not widgetGet(ui.tpEscape, true) or not unit or not pos then return false end
    if sc(NPC.IsChannellingAbility, unit) == true then return false end

    local id = unitId(unit)
    if t - (state.lastTp[id] or 0) < 8 then return false end

    local mana = sc(NPC.GetMana, unit) or 0
    local travels = sc(NPC.GetItem, unit, "item_travel_boots_2", true)
        or sc(NPC.GetItem, unit, "item_travel_boots", true)

    if travels and sc(Ability.IsCastable, travels, mana) == true then
        sc(Ability.CastPosition, travels, pos, false, true, false, ORDER_PREFIX .. "escape_travel", true)
        state.lastTp[id] = t
        return true
    end

    local scroll = sc(NPC.GetItem, unit, "item_tpscroll", false)
    if scroll and sc(Ability.IsCastable, scroll, mana) == true then
        sc(Ability.CastPosition, scroll, basePosition(team), false, true, false, ORDER_PREFIX .. "escape_tp", true)
        state.lastTp[id] = t
        return true
    end

    return false
end

local function escapePositionFor(unit, neutrals, t, team)
    local unitPos = origin(unit)
    local bestCamp, bestScore = nil, -math.huge
    local infos = collectCampInfos(neutrals, t)

    for _, info in ipairs(infos) do
        local emptyLocked = not info.target and t < (state.emptyUntil[info.id] or 0)
        if not emptyLocked and campSafeFromEnemies(info, t) then
            local dangerDistance = minDistanceToEnemyAvoid(info.center, t)
            if dangerDistance == math.huge then dangerDistance = enemyAvoidRadius() * 2 end

            local travelDistance = dist2D(unitPos, info.center)
            local score = dangerDistance * 1.15 - travelDistance * 0.35
            if info.target and info.count > 0 then score = score + 650 end
            if shouldWaitCamp(info, t) then score = score + 160 end

            if score > bestScore then
                bestScore = score
                bestCamp = info
            end
        end
    end

    if bestCamp then
        return bestCamp.target and origin(bestCamp.target) or bestCamp.center
    end

    return basePosition(team)
end

local function avoidVisibleEnemies(player, active, neutrals, team, t)
    if not widgetGet(ui.avoidEnemies, true) then return active end

    pruneEnemyAvoid(t)

    local visibleEnemies
    if awarenessMaphackEnabled() and collectEnemyAwareness then
        visibleEnemies = collectEnemyAwareness(team, t)
    else
        visibleEnemies = collectVisibleEnemyHeroes(team, t)
    end

    local dangerById = {}
    local radius = enemyAvoidRadius()
    for _, unit in ipairs(active) do
        local _, enemyPos = visibleEnemyNearUnit(unit, visibleEnemies, radius)
        if enemyPos then
            dangerById[unitId(unit)] = enemyPos
            rememberEnemyAvoid(enemyPos, t)
        end
    end

    local farming = {}
    for _, unit in ipairs(active) do
        local id = unitId(unit)
        local unitPos = origin(unit)
        local dangerPos = dangerById[id]
        if not dangerPos and unitPos and minDistanceToEnemyAvoid(unitPos, t) <= radius * 0.65 then
            dangerPos = unitPos
        end

        if dangerPos then
            state.unitCamp[id] = nil
            setStatus(unit, L("status_escape"), statusColor.danger)

            local safePos = escapePositionFor(unit, neutrals, t, team)
            if not tryPoof(unit, safePos, t, "escape", active) and not tryTeleportEscape(unit, safePos, t, team) then
                issueMove(player, unit, safePos, t)
            end
        else
            farming[#farming + 1] = unit
        end
    end

    return farming
end

local function markEmptyIfScouted(camp, packPos, t, team)
    if not camp or camp.target or not packPos then return end
    if isWithin2D(packPos, camp.center, math.max(700, widgetGet(ui.campRadius, 760) * 0.85)) then
        local memory = getCampMemory(camp.id)
        local recentlyHadCreeps = memory.hadCreeps or (memory.lastSeen and t - memory.lastSeen <= 45)
        local waitLeft = secondsToNextMinute()

        memory.hadCreeps = false
        memory.lastCleared = t
        state.emptyUntil[camp.id] = nextNeutralSpawnTime(t)

        if (recentlyHadCreeps or waitLeft <= RESPAWN_SAFE_WINDOW) and waitLeft <= RESPAWN_WAIT_WINDOW then
            memory.hadCreeps = false
            memory.waitUntil = t + waitLeft + 1.5
            memory.waitPos = campWaitPosition(camp.center, team)
            camp.waitUntil = memory.waitUntil
            camp.waitPos = memory.waitPos
        else
            memory.waitUntil = nil
        end
    end
end

local function shouldBurstPoof(group)
    if not widgetGet(ui.burstPoof, true) then return false end
    if not group or not group.camp or group.camp.isPush then return false end
    local minCreeps = widgetGet(ui.burstPoofCreeps, BURST_POOF_MIN_CREEPS)
    return (group.camp.count or 0) >= minCreeps or group.camp.isAncient == true
end

local function commandGroup(player, group, t, team)
    if not group or not group.camp then return end

    local target = group.camp.target
    if target and not alive(target) then target = nil end

    if not target then
        local center = groupCenter(group)
        markEmptyIfScouted(group.camp, center, t, team)
        if group.camp.waitUntil and t < group.camp.waitUntil then
            group.role = "WAIT"
        end
        local waitLeft = secondsToNextMinute()
        if waitLeft <= RESPAWN_SAFE_WINDOW then
            local memory = getCampMemory(group.camp.id)
            memory.waitUntil = t + waitLeft + 1.5
            memory.waitPos = memory.waitPos or campWaitPosition(group.camp.center, team)
            group.camp.waitUntil = memory.waitUntil
            group.camp.waitPos = memory.waitPos
            group.role = "WAIT"
        end
    end

    local joinPos = target and origin(target) or group.camp.center
    if not target and group.role == "WAIT" then
        joinPos = group.camp.waitPos or campWaitPosition(group.camp.center, team)
    end
    if not joinPos then return end

    local nearCount = countNear(group.units, joinPos, widgetGet(ui.joinRadius, 560))
    local requiredCount = math.max(1, group.minSize or #group.units)
    local readyToAttack = target and nearCount >= requiredCount
    local laneTag = group.camp.isPush and group.camp.lane and (string.upper(tostring(group.camp.lane)) .. " ") or ""

    for i, unit in ipairs(group.units) do
        local role = group.roles[unitId(unit)] or group.role
        state.unitCamp[unitId(unit)] = group.camp.id

        if role == "HELP" then
            setStatus(unit, L("status_help") .. " G" .. group.index, statusColor.help, group.index)
        elseif group.role == "WAIT" then
            local left = group.camp.waitUntil and math.max(0, math.ceil(group.camp.waitUntil - t)) or math.ceil(secondsToNextMinute())
            setStatus(unit, "G" .. group.index .. " " .. L("status_wait") .. " " .. left, statusColor.wait, group.index)
        elseif not target then
            local label = group.camp.isPush and (laneTag .. L("status_push")) or L("status_scout")
            setStatus(unit, "G" .. group.index .. " " .. label, group.camp.isPush and statusColor.move or statusColor.scout, group.index)
        elseif readyToAttack then
            local label
            if group.camp.isPush then
                label = " " .. laneTag .. L("status_push")
            else
                label = requiredCount == 1 and (" " .. L("status_solo")) or (" " .. L("status_farm"))
            end
            setStatus(unit, "G" .. group.index .. label, statusColor.farm, group.index)
        else
            local label = group.camp.isPush and (laneTag .. L("status_push")) or L("status_join")
            setStatus(unit, "G" .. group.index .. " " .. label, statusColor.move, group.index)
        end

        if readyToAttack then
            state.unitFightCamp[unitId(unit)] = group.camp.id
        elseif not target then
            state.unitFightCamp[unitId(unit)] = nil
        end

        if readyToAttack and shouldBurstPoof(group) then
            if not tryPoof(unit, joinPos, t, "damage", group.units) then
                issueAttack(player, unit, target, t)
            end
        elseif not readyToAttack and tryPoof(unit, joinPos, t, "move", group.units) then
            -- Poof order is enough for this tick.
        elseif readyToAttack then
            issueAttack(player, unit, target, t)
        else
            issueMove(player, unit, formationPosition(joinPos, i, #group.units), t)
        end
    end
end

runPackFarm = function(player, units, team, t)
    if syncSmartMode then syncSmartMode(t, team) end
    clearStatuses()
    state.activeGroups = {}

    for _, unit in ipairs(units) do
        setStatus(unit, L("status_wait"), statusColor.wait)
    end

    local active = {}
    local base = basePosition(team)

    for _, unit in ipairs(units) do
        if isManual(unit, t) then
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_manual"), statusColor.manual)
        elseif sc(NPC.IsChannellingAbility, unit) == true then
            setStatus(unit, L("status_cast"), statusColor.manual)
        elseif widgetGet(ui.megameepoHold, true) and isMegameepoActive(state.localHero) and unitId(unit) == unitId(state.localHero) then
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_hold"), statusColor.manual)
        elseif needsManaRefill(unit) then
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_regen"), statusColor.base)
            issueMove(player, unit, base, t)
        elseif shouldRetreat(unit) then
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_base"), statusColor.base)
            issueMove(player, unit, base, t)
        else
            active[#active + 1] = unit
        end
    end

    if #active == 0 then
        storeActiveGroups(nil)
        finalizeStatuses(units)
        return
    end

    local neutrals = collectNeutrals(t)
    active = avoidVisibleEnemies(player, active, neutrals, team, t)
    if #active == 0 then
        storeActiveGroups(nil)
        setDebugInfo("Meepo AutoFarm V2", {
            "Active pairs: 0",
            "All active Meepos are escaping or unavailable"
        })
        finalizeStatuses(units)
        return
    end

    local groups, reserves, pushDebug
    if isPushActive() then
        groups, reserves, pushDebug = buildPushGroups(active, 0, team, t)
        handleReserveUnits(player, reserves, groups, t, team)

        local debugLines = {
            string.format("Mode: PUSH | Push pairs: %d | Reserve: %d", #groups, #reserves),
            string.format("Active Meepos: %d | Enemy memory: %d", #active, #state.enemyAvoid)
        }
        if pushDebug then
            if pushDebug.lanes and #pushDebug.lanes > 0 then
                debugLines[#debugLines + 1] = "Lanes: " .. table.concat(pushDebug.lanes, " | ")
            else
                debugLines[#debugLines + 1] = string.format("Push target: %s", pushDebug.label or "front")
                debugLines[#debugLines + 1] = string.format("Push score: %.0f | Support: %d | Danger: %.0f", pushDebug.score or 0, pushDebug.support or 0, pushDebug.danger or 0)
            end
        end
        setDebugInfo("Meepo AutoFarm V2", debugLines)
    else
        groups, reserves = buildGroups(active, neutrals, t, team)
        handleReserveUnits(player, reserves, groups, t, team)
        setDebugInfo("Meepo AutoFarm V2", {
            string.format("Mode: FARM | Farm pairs: %d | Reserve: %d", #groups, #reserves),
            string.format("Active Meepos: %d | Enemy memory: %d | Camp picks: %d", #active, #state.enemyAvoid, selectedCampCount())
        })
    end

    storeActiveGroups(groups)

    if #groups == 0 then
        finalizeStatuses(units)
        return
    end

    for _, group in ipairs(groups) do
        commandGroup(player, group, t, team)
    end

    finalizeStatuses(units)
end

end

function MeepoJunglePack.OnUpdate()
    if Engine and Engine.IsInGame and sc(Engine.IsInGame) ~= true then
        resetRuntimeState()
        setMapOpen(false)
        return
    end
    if not isEnabled() then
        resetRuntimeState()
        setMapOpen(false)
        return
    end

    checkFarmToggleBind()
    checkPushToggleBind()
    checkMapToggleBind()
    syncModeWidgets()

    if not hasActiveMode() then
        clearStatuses()
        state.activeGroups = {}
        resetTickCache()
        setDebugInfo("Meepo AutoFarm V2", {"Modes: OFF"})
        return
    end

    local t = now()
    if t - state.lastTick < 0.16 then return end
    state.lastTick = t

    local player = Players.GetLocal and Players.GetLocal() or nil
    local playerId = player and sc(Player.GetPlayerID, player) or -1
    local hero = Heroes.GetLocal and Heroes.GetLocal() or nil
    state.localHero = hero

    if not player or not hero or not alive(hero) or unitName(hero) ~= MEEPO_NAME then
        resetRuntimeState()
        return
    end

    local team = sc(Entity.GetTeamNum, hero)
    if not team then
        resetRuntimeState()
        return
    end

    local meepos = getControllableMeepos(hero, player, playerId, team, t)
    if #meepos == 0 then
        resetRuntimeState()
        return
    end

    if comboKeyActive(t) then
        clearStatuses()
        for _, unit in ipairs(meepos) do
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_combo"), statusColor.combo)
        end
        setDebugInfo("Meepo AutoFarm V2", {
            "Mode: COMBO",
            string.format("Controlled Meepos: %d", #meepos)
        })
        finalizeStatuses(meepos)
        return
    end

    runPackFarm(player, meepos, team, t)
end

function MeepoJunglePack.OnUpdateEx()
    setupLanguageReloadCallback()
    applyLocalization(false)
    syncModeWidgets()
end

local statusTextSize, syncMapTheme, drawFarmMap, drawDebugOverlay, handleFarmMapClick, cursorOnMapPanel, statusLayout, isMouseKey

do
local mapColor = {
    panel = Color(64, 54, 78, 232),
    header = Color(126, 113, 148, 235),
    border = Color(255, 255, 255, 30),
    tabActive = Color(250, 245, 255, 245),
    tabIdle = Color(104, 92, 122, 210),
    tabTextActive = Color(204, 86, 226, 255),
    mapTop = Color(118, 170, 205, 245),
    mapRight = Color(190, 230, 235, 245),
    mapBottom = Color(210, 235, 110, 245),
    mapLeft = Color(85, 190, 80, 245),
    mapOverlay = Color(0, 0, 0, 18),
    mapBorder = Color(20, 24, 28, 210),
    road = Color(235, 240, 220, 88),
    river = Color(82, 126, 156, 160),
    text = Color(255, 255, 255, 255),
    mutedText = Color(225, 218, 235, 210),
    selected = Color(70, 255, 90, 235),
    unselected = Color(255, 82, 96, 220),
    neutral = Color(245, 242, 210, 225),
    danger = Color(255, 60, 72, 80),
    hero = Color(110, 190, 255, 245)
}

statusTextSize = function(text)
    if Render and Render.TextSize and statusFont then
        local size = sc(Render.TextSize, statusFont, 12, text)
        if size and size.x and size.y then return size.x, size.y end
    end

    return #tostring(text) * 7, 12
end

local function clampByte(value, fallback)
    value = tonumber(value)
    if not value then return fallback or 0 end
    if value <= 1 then value = value * 255 end
    return math.max(0, math.min(255, math.floor(value + 0.5)))
end

local function normalizeColor(value)
    if not value then return nil end
    if type(value) == "userdata" then return value end
    if type(value) == "table" and type(value.r) == "number" then
        return Color(
            clampByte(value.r, 255),
            clampByte(value.g, 255),
            clampByte(value.b, 255),
            clampByte(value.a or 255, 255)
        )
    end
    return nil
end

local function colorPart(color, key, fallback)
    local value = color and color[key]
    if type(value) == "number" then return clampByte(value, fallback or 0) end
    return fallback or 0
end

local function alpha(color)
    return colorPart(color, "a", 255)
end

local function withAlpha(color, value)
    return Color(colorPart(color, "r", 255), colorPart(color, "g", 255), colorPart(color, "b", 255), value)
end

local function visibleThemeColor(color, fallback, minAlpha)
    local normalized = normalizeColor(color)
    if not normalized then return fallback end
    if alpha(normalized) < (minAlpha or 18) then
        return withAlpha(normalized, minAlpha or 18)
    end
    return normalized
end

local function luminance(color)
    return colorPart(color, "r", 0) * 0.299 + colorPart(color, "g", 0) * 0.587 + colorPart(color, "b", 0) * 0.114
end

local function themeColor(name, fallback)
    if not Menu or not Menu.Style then return fallback end

    local ok, color = pcall(Menu.Style, name)
    local normalized = ok and normalizeColor(color)
    if normalized then return normalized end

    local okTable, style = pcall(Menu.Style)
    if okTable and type(style) == "table" then
        normalized = normalizeColor(style[name])
        if normalized then return normalized end
    end

    return fallback
end

local function themeColorAny(names, fallback)
    for _, name in ipairs(names) do
        local color = themeColor(name, nil)
        if color then return color end
    end
    return fallback
end

syncMapTheme = function(force)
    local t = os.clock()
    if not force and t - (state.lastMapThemeSync or 0) < 0.5 then return end
    state.lastMapThemeSync = t

    local panel = themeColorAny({"popup_background", "additional_background", "background"}, Color(64, 54, 78, 232))
    local header = themeColorAny({"additional_background", "primary", "combo_frame"}, Color(126, 113, 148, 235))
    local group = themeColorAny({"group_background", "combo_frame", "disabled_switch_background"}, Color(104, 92, 122, 210))
    local primary = themeColorAny({"primary", "accent", "combo_item_active", "indication_active"}, Color(204, 86, 226, 255))
    local active = themeColorAny({"indication_active", "combo_item_active", "enabled_switch_background", "primary"}, Color(70, 255, 90, 235))
    local inactive = themeColorAny({"danger", "warning", "indication_inactive"}, Color(255, 82, 96, 220))
    local text = themeColorAny({"primary_widgets_text", "text", "primary_text"}, Color(255, 255, 255, 255))
    local border = themeColorAny({"popup_border", "group_outline", "outline"}, Color(255, 255, 255, 30))

    local lightPanel = luminance(panel) > 145
    if lightPanel and luminance(text) > 160 then
        text = Color(26, 28, 34, 255)
    end

    mapColor.panel = withAlpha(panel, math.max(alpha(panel), 226))
    mapColor.header = withAlpha(header, math.max(alpha(header), 218))
    mapColor.border = visibleThemeColor(border, lightPanel and Color(0, 0, 0, 38) or Color(255, 255, 255, 30), 24)
    mapColor.tabIdle = withAlpha(group, lightPanel and 160 or 205)
    mapColor.tabActive = lightPanel and Color(255, 255, 255, 230) or withAlpha(themeColorAny({"primary_widgets_background", "combo_frame"}, group), 235)
    mapColor.tabTextActive = primary
    mapColor.mapBorder = visibleThemeColor(border, lightPanel and Color(0, 0, 0, 65) or Color(20, 24, 28, 210), 35)
    mapColor.mapOverlay = lightPanel and Color(255, 255, 255, 10) or Color(0, 0, 0, 24)
    mapColor.text = text
    mapColor.mutedText = withAlpha(text, 210)
    mapColor.selected = withAlpha(active, 240)
    mapColor.unselected = withAlpha(inactive, 230)
    mapColor.hero = withAlpha(primary, 245)
end

local function trimText(value)
    value = tostring(value or "")
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function getMapImageHandle()
    if not Render or not Render.LoadImage then return nil end

    local customPath = trimText(widgetGet(ui.mapImagePath, ""))
    if state.mapImageInput ~= customPath then
        state.mapImageInput = customPath
        state.mapImageHandle = nil
        state.mapImageLoaded = false
        state.mapImageRetryAt = 0
    end

    local clock = os.clock()
    if state.mapImageLoaded then
        if state.mapImageHandle or clock < (state.mapImageRetryAt or 0) then
            return state.mapImageHandle
        end
        state.mapImageLoaded = false
    end
    state.mapImageLoaded = true

    local candidates = {}
    if customPath ~= "" then
        candidates[#candidates + 1] = customPath
    end
    for _, path in ipairs(MAP_IMAGE_PATHS) do
        candidates[#candidates + 1] = path
    end

    for _, path in ipairs(candidates) do
        local handle = sc(Render.LoadImage, path)
        if type(handle) == "number" and handle > 0 then
            state.mapImageHandle = handle
            state.mapImagePath = path
            return handle
        end
    end

    state.mapImageRetryAt = clock + 5
    return nil
end

local function cursorPos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok and type(x) == "number" and type(y) == "number" then return x, y end
    end

    if Render and Render.GetCursorPos then
        local ok, posOrX, y = pcall(Render.GetCursorPos)
        if ok then
            if type(posOrX) == "number" and type(y) == "number" then return posOrX, y end
            if type(posOrX) == "table" or type(posOrX) == "userdata" then
                local x = posOrX.x or (posOrX.GetX and posOrX:GetX())
                local yy = posOrX.y or (posOrX.GetY and posOrX:GetY())
                if type(x) == "number" and type(yy) == "number" then return x, yy end
            end
        end
    end

    return nil, nil
end

local function mouseDown()
    if not Input or not Input.IsKeyDown or not Enum.ButtonCode then return false end
    return sc(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1, true) == true
end

local function rectContains(rect, x, y)
    return rect and x and y and x >= rect.x and y >= rect.y and x <= rect.x + rect.w and y <= rect.y + rect.h
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function screenSize()
    local screen = Render and Render.ScreenSize and sc(Render.ScreenSize)
    if screen and screen.x and screen.y then
        return screen.x, screen.y
    end
    return nil, nil
end

local function currentModeLabel()
    if state.lastMode == "push" then return L("status_push") end
    if state.lastMode == "farm" then return L("status_farm") end
    return L("status_wait")
end

statusLayout = function(count)
    if widgetGet(ui.statusAutoAnchor, true) then
        local sw, sh = screenSize()
        if sw and sh then
            local portraitW = clamp(math.floor(sh * 0.056), 54, 74)
            local portraitH = clamp(math.floor(sh * 0.066), 62, 82)
            local portraitX = clamp(math.floor(sw * 0.015), 20, 38)
            local portraitY = clamp(math.floor(sh * 0.034), 28, 52)
            local gap = portraitH + clamp(math.floor(sh * 0.0045), 4, 8)
            local x = portraitX + portraitW + 10
            local y = portraitY + math.floor((portraitH - 18) * 0.5)
            if count and count > 4 then
                gap = math.max(portraitH + 4, math.floor((sh - portraitY * 2) / count))
            end
            return x, y, gap, true
        end
    end

    return widgetGet(ui.statusX, 112), widgetGet(ui.statusY, 42), widgetGet(ui.statusGap, 73), false
end

local function mapLayout()
    local w, h = 322, 388
    local x = state.mapX or 12
    local y = state.mapY or 150
    local screen = Render and Render.ScreenSize and sc(Render.ScreenSize)

    if screen and screen.x and screen.y then
        x = clamp(x, 0, math.max(0, screen.x - w))
        y = clamp(y, 0, math.max(0, screen.y - h))
    end

    state.mapX = x
    state.mapY = y

    return {
        x = x,
        y = y,
        w = w,
        h = h,
        headerH = 28,
        tabY = y + 34,
        tabH = 23,
        mapX = x + 12,
        mapY = y + 66,
        mapSize = 298
    }
end

local function updateMapRects(layout)
    state.mapRects = {
        panel = {x = layout.x, y = layout.y, w = layout.w, h = layout.h},
        header = {x = layout.x, y = layout.y, w = layout.w, h = layout.headerH},
        close = {x = layout.x + layout.w - 24, y = layout.y + 5, w = 18, h = 18},
        radiant = {x = layout.x + 10, y = layout.tabY, w = 150, h = layout.tabH},
        dire = {x = layout.x + 166, y = layout.tabY, w = 146, h = layout.tabH},
        all = {x = layout.x + 12, y = layout.y + layout.h - 21, w = 48, h = 16}
    }
end

cursorOnMapPanel = function()
    if not state.mapOpen then return false end
    local x, y = cursorPos()
    if not x or not y then return false end

    local layout = mapLayout()
    updateMapRects(layout)
    return rectContains(state.mapRects.panel, x, y)
end

local function campSideByCenter(center)
    if not center then return "dire" end
    return (vecX(center) + vecY(center)) < 0 and "radiant" or "dire"
end

local function collectMapCamps()
    local allowAncients = widgetGet(ui.farmAncients, false)
    if state.mapCamps and state.mapCampsAncients == allowAncients then
        return state.mapCamps
    end

    local infos = {}
    local camps = sc(Camps.GetAll)
    if not camps then
        state.mapCamps = infos
        state.mapCampsAncients = allowAncients
        return infos
    end

    for i, camp in ipairs(camps) do
        if campAllowed(camp) then
            local center = campCenter(camp)
            if center then
                infos[#infos + 1] = {
                    id = i,
                    center = center,
                    side = campSideByCenter(center)
                }
            end
        end
    end

    state.mapCamps = infos
    state.mapCampsAncients = allowAncients
    return infos
end

local function selectCampsBySide(side)
    state.selectedCamps = {}
    for _, info in ipairs(collectMapCamps()) do
        if info.side == side then
            state.selectedCamps[info.id] = true
        end
    end
    state.mapSide = side
end

local function worldToMap(pos, layout)
    if not pos then return nil, nil end
    local usableSize = layout.mapSize - MAP_DOT_PADDING * 2
    local scale = usableSize / (MAP_WORLD_MAX - MAP_WORLD_MIN)
    local x = layout.mapX + MAP_DOT_PADDING + (vecX(pos) - MAP_WORLD_MIN) * scale
    local y = layout.mapY + MAP_DOT_PADDING + usableSize - (vecY(pos) - MAP_WORLD_MIN) * scale
    x = clamp(x, layout.mapX + MAP_DOT_PADDING, layout.mapX + layout.mapSize - MAP_DOT_PADDING)
    y = clamp(y, layout.mapY + MAP_DOT_PADDING, layout.mapY + layout.mapSize - MAP_DOT_PADDING)
    return x, y
end

local function drawText(text, x, y, size, color)
    if statusFont then
        sc(Render.Text, statusFont, size or 12, text, Vec2(x, y), color or mapColor.text)
    end
end

local function drawMapModeBadge(layout)
    local label = currentModeLabel()
    local textW = statusTextSize(label)
    local width = math.max(54, textW + 18)
    local x = layout.x + layout.w - width - 30
    local y = layout.y + 5
    local color = state.lastMode == "push" and Color(255, 180, 92, 236)
        or state.lastMode == "farm" and Color(92, 215, 132, 236)
        or Color(150, 160, 170, 205)

    sc(Render.FilledRect, Vec2(x, y), Vec2(x + width, y + 18), color, 4)
    drawText(label, x + 8, y + 2, 11, Color(20, 24, 28, 255))
end

local function drawActiveGroupMarkers(layout)
    if not widgetGet(ui.mapGroupMarkers, true) then return end

    for _, group in ipairs(state.activeGroups or {}) do
        local targetPos = group.targetPos
        local groupPos = group.groupPos
        local tx, ty = worldToMap(targetPos, layout)
        local gx, gy = worldToMap(groupPos, layout)
        local color = group.isPush and Color(255, 178, 90, 240)
            or group.role == "WAIT" and Color(180, 188, 198, 220)
            or Color(92, 225, 132, 238)

        if gx and gy and tx and ty then
            sc(Render.Line, Vec2(gx, gy), Vec2(tx, ty), withAlpha(color, 150), 2)
        end

        if tx and ty then
            sc(Render.FilledCircle, Vec2(tx, ty), 10, Color(0, 0, 0, 118))
            sc(Render.FilledCircle, Vec2(tx, ty), 8, color)
            local marker = group.lane and string.upper(string.sub(group.lane, 1, 1)) or tostring(group.index or "?")
            drawText(marker, tx - 4, ty - 7, 11, Color(18, 20, 24, 255))
        end
    end
end

drawDebugOverlay = function()
    if not isEnabled() or not widgetGet(ui.debugOverlay, false) or not Render or not statusFont then return end

    local info = state.debugInfo
    local lines = info and info.lines or nil
    if not lines or #lines == 0 then return end

    local x = widgetGet(ui.debugX, 310)
    local y = widgetGet(ui.debugY, 42)
    local title = info.title or "Meepo AutoFarm V2"
    local width = math.max(220, statusTextSize(title) + 22)
    local lineHeight = 16

    for _, line in ipairs(lines) do
        local textW = statusTextSize(line)
        width = math.max(width, textW + 22)
    end

    local height = 26 + #lines * lineHeight + 8
    local topLeft = Vec2(x, y)
    local bottomRight = Vec2(x + width, y + height)

    sc(Render.FilledRect, topLeft, bottomRight, Color(10, 14, 18, 178), 5)
    sc(Render.Rect, topLeft, bottomRight, Color(255, 255, 255, 28), 5, Enum.DrawFlags and Enum.DrawFlags.None or 0, 1)
    sc(Render.FilledRect, Vec2(x, y), Vec2(x + width, y + 22), Color(40, 55, 66, 188), 5)
    drawText(title, x + 9, y + 4, 12, Color(245, 248, 250, 255))

    for index, line in ipairs(lines) do
        drawText(line, x + 9, y + 10 + index * lineHeight, 12, Color(220, 228, 235, 255))
    end
end

drawFarmMap = function()
    if not state.mapOpen or not isEnabled() or not Render or not statusFont then return end

    syncMapTheme(false)

    local layout = mapLayout()
    state.mapCampRects = {}
    updateMapRects(layout)

    sc(Render.FilledRect, Vec2(layout.x, layout.y), Vec2(layout.x + layout.w, layout.y + layout.h), mapColor.panel, 5)
    sc(Render.Rect, Vec2(layout.x, layout.y), Vec2(layout.x + layout.w, layout.y + layout.h), mapColor.border, 5, Enum.DrawFlags and Enum.DrawFlags.None or 0, 1)
    sc(Render.FilledRect, Vec2(layout.x, layout.y), Vec2(layout.x + layout.w, layout.y + layout.headerH), mapColor.header, 5)
    drawText(L("panel_title"), layout.x + 12, layout.y + 6, 14, mapColor.text)
    drawMapModeBadge(layout)
    drawText("x", layout.x + layout.w - 19, layout.y + 5, 16, mapColor.text)

    local radiantActive = state.mapSide == "radiant"
    local direActive = state.mapSide == "dire"
    sc(Render.FilledRect, Vec2(state.mapRects.radiant.x, state.mapRects.radiant.y), Vec2(state.mapRects.radiant.x + state.mapRects.radiant.w, state.mapRects.radiant.y + state.mapRects.radiant.h), radiantActive and mapColor.tabActive or mapColor.tabIdle, 4)
    sc(Render.FilledRect, Vec2(state.mapRects.dire.x, state.mapRects.dire.y), Vec2(state.mapRects.dire.x + state.mapRects.dire.w, state.mapRects.dire.y + state.mapRects.dire.h), direActive and mapColor.tabActive or mapColor.tabIdle, 4)
    drawText(L("panel_radiant"), state.mapRects.radiant.x + 55, state.mapRects.radiant.y + 4, 11, radiantActive and mapColor.tabTextActive or mapColor.text)
    drawText(L("panel_dire"), state.mapRects.dire.x + 61, state.mapRects.dire.y + 4, 11, direActive and mapColor.tabTextActive or mapColor.text)

    local mapStart = Vec2(layout.mapX, layout.mapY)
    local mapEnd = Vec2(layout.mapX + layout.mapSize, layout.mapY + layout.mapSize)
    local mapImage = getMapImageHandle()
    if mapImage and Render.Image then
        sc(Render.Image, mapImage, mapStart, Vec2(layout.mapSize, layout.mapSize), Color(255, 255, 255, 245), 5)
        sc(Render.FilledRect, mapStart, mapEnd, mapColor.mapOverlay, 5)
    elseif Render.Gradient then
        sc(Render.Gradient, mapStart, mapEnd, mapColor.mapTop, mapColor.mapRight, mapColor.mapLeft, mapColor.mapBottom, 5)
    else
        sc(Render.FilledRect, mapStart, mapEnd, mapColor.mapBottom, 5)
    end
    sc(Render.Rect, mapStart, mapEnd, mapColor.mapBorder, 5, Enum.DrawFlags and Enum.DrawFlags.None or 0, 2)

    if not mapImage then
        local mx, my, ms = layout.mapX, layout.mapY, layout.mapSize
        sc(Render.Line, Vec2(mx + 12, my + ms - 72), Vec2(mx + ms - 32, my + 42), mapColor.river, 10)
        sc(Render.Line, Vec2(mx + 28, my + ms - 42), Vec2(mx + ms - 38, my + 68), mapColor.road, 3)
        sc(Render.Line, Vec2(mx + 52, my + ms - 210), Vec2(mx + ms - 36, my + 178), mapColor.road, 2)
        sc(Render.Line, Vec2(mx + 90, my + ms - 18), Vec2(mx + ms - 68, my + 92), mapColor.road, 2)
    end

    local anySelected = hasSelectedCamps()
    for _, info in ipairs(collectMapCamps()) do
        local px, py = worldToMap(info.center, layout)
        if px and py then
            local selected = not anySelected or state.selectedCamps[info.id] == true
            local color = selected and mapColor.selected or mapColor.unselected
            local r = selected and 8 or 7
            sc(Render.FilledCircle, Vec2(px, py), r + 2, Color(0, 0, 0, 120))
            sc(Render.Circle, Vec2(px, py), r + 4, color, 2)
            sc(Render.FilledCircle, Vec2(px, py), r, Color(32, 38, 42, 215))
            sc(Render.FilledCircle, Vec2(px, py), math.max(3, r - 3), color)
            state.mapCampRects[#state.mapCampRects + 1] = {id = info.id, x = px, y = py, r = r + 7}
        end
    end

    drawActiveGroupMarkers(layout)

    pruneEnemyAvoid(now())
    local avoidScale = layout.mapSize / (MAP_WORLD_MAX - MAP_WORLD_MIN)
    for _, danger in ipairs(state.enemyAvoid) do
        local px, py = worldToMap(danger.pos, layout)
        if px and py then
            sc(Render.Circle, Vec2(px, py), enemyAvoidRadius() * avoidScale, mapColor.danger, 2)
        end
    end

    if widgetGet(ui.mapAwareness, true) and state.localHero and alive(state.localHero) and collectEnemyAwareness then
        local team = sc(Entity.GetTeamNum, state.localHero)
        local t = now()
        if team then
            for _, enemy in ipairs(collectEnemyAwareness(team, t)) do
                local px, py = worldToMap(enemy.pos, layout)
                if px and py then
                    local dotColor = enemy.visible and Color(255, 80, 80, 230) or Color(255, 180, 60, 180)
                    sc(Render.FilledCircle, Vec2(px, py), 4, dotColor)
                    sc(Render.Circle, Vec2(px, py), 6, Color(255, 255, 255, 140), 1)
                end
            end
        end
    end

    if state.localHero and alive(state.localHero) then
        local hx, hy = worldToMap(origin(state.localHero), layout)
        if hx and hy then
            sc(Render.FilledCircle, Vec2(hx, hy), 5, mapColor.hero)
            sc(Render.Circle, Vec2(hx, hy), 8, Color(255, 255, 255, 180), 1)
        end
    end

    local selectedText = anySelected and (L("panel_selected") .. selectedCampCount()) or L("panel_all_camps")
    drawText(L("panel_all"), state.mapRects.all.x + 11, state.mapRects.all.y + 1, 11, mapColor.text)
    drawText(selectedText, layout.x + 70, layout.y + layout.h - 20, 11, mapColor.mutedText)
    drawText(string.format("%s: %d", currentModeLabel(), #state.activeGroups), layout.x + 182, layout.y + layout.h - 20, 11, mapColor.mutedText)
end

handleFarmMapClick = function()
    if not state.mapOpen or not isEnabled() then
        state.mapMousePrev = false
        state.mapDragging = false
        return
    end
    if Input and Input.IsInputCaptured and sc(Input.IsInputCaptured) == true then return end

    local down = mouseDown()
    local x, y = cursorPos()
    local layout = mapLayout()
    updateMapRects(layout)

    if down and state.mapDragging and x and y then
        state.mapX = x - state.mapDragOffsetX
        state.mapY = y - state.mapDragOffsetY
        updateMapRects(mapLayout())
        state.mapBlockInputUntil = os.clock() + 0.25
        state.mapMousePrev = down
        return
    end

    if not down then
        state.mapDragging = false
        state.mapMousePrev = false
        return
    end

    if state.mapMousePrev then
        state.mapMousePrev = down
        if rectContains(state.mapRects.panel, x, y) then
            state.mapBlockInputUntil = os.clock() + 0.15
        end
        return
    end

    if not x or not y then
        state.mapMousePrev = down
        return
    end

    if rectContains(state.mapRects.close, x, y) then
        setMapOpen(false)
    elseif rectContains(state.mapRects.header, x, y) then
        state.mapDragging = true
        state.mapDragOffsetX = x - layout.x
        state.mapDragOffsetY = y - layout.y
    elseif rectContains(state.mapRects.radiant, x, y) then
        selectCampsBySide("radiant")
    elseif rectContains(state.mapRects.dire, x, y) then
        selectCampsBySide("dire")
    elseif rectContains(state.mapRects.all, x, y) then
        state.selectedCamps = {}
        state.mapSide = nil
    else
        for _, rect in ipairs(state.mapCampRects or {}) do
            local dx, dy = x - rect.x, y - rect.y
            if dx * dx + dy * dy <= rect.r * rect.r then
                state.selectedCamps[rect.id] = not state.selectedCamps[rect.id]
                state.mapSide = nil
                break
            end
        end
    end

    if rectContains(state.mapRects.panel, x, y) then
        state.mapBlockInputUntil = os.clock() + 0.25
    end

    state.mapMousePrev = down
end

isMouseKey = function(key)
    if not Enum.ButtonCode then return false end
    return key == Enum.ButtonCode.KEY_MOUSE1
        or key == Enum.ButtonCode.KEY_MOUSE2
        or key == Enum.ButtonCode.KEY_MOUSE3
        or key == Enum.ButtonCode.KEY_MOUSE4
        or key == Enum.ButtonCode.KEY_MOUSE5
        or key == Enum.ButtonCode.KEY_MWHEELUP
        or key == Enum.ButtonCode.KEY_MWHEELDOWN
end

end

function MeepoJunglePack.OnDraw()
    drawFarmMap()
    drawDebugOverlay()

    if not hasActiveMode() then return end
    if not widgetGet(ui.showStatus, true) then return end
    if not Render or not statusFont then return end

    local list = state.statusList
    if not list or #list == 0 then return end

    local x, y, gap, anchored = statusLayout(#list)

    for row, entry in ipairs(list) do
        local text = entry.text or L("status_wait")
        local color = entry.color or statusColor.wait
        local rowY = y + (row - 1) * gap
        local textW, textH = statusTextSize(text)
        local width = math.max(anchored and 72 or 58, textW + (anchored and 18 or 20))
        local height = math.max(17, textH + 5)
        local topLeft = Vec2(x, rowY)
        local bottomRight = Vec2(x + width, rowY + height)
        local textPos = Vec2(x + (anchored and 12 or 14), rowY + 2)

        sc(Render.FilledRect, topLeft, bottomRight, anchored and Color(12, 16, 20, 176) or statusColor.bg, 4)
        sc(Render.FilledCircle, Vec2(x + 7, rowY + height / 2), 3, color)
        sc(Render.Text, statusFont, 12, text, Vec2(textPos.x + 1, textPos.y + 1), statusColor.shadow)
        sc(Render.Text, statusFont, 12, text, textPos, color)
    end
end

function MeepoJunglePack.OnFrame()
    handleFarmMapClick()
end

function MeepoJunglePack.OnThemeUpdate()
    syncMapTheme(true)
end

function MeepoJunglePack.OnGameEnd()
    resetRuntimeState()
    setMapOpen(false)
end

function MeepoJunglePack.OnEntityDestroy(entity)
    purgeUnitState(entity)
end

function MeepoJunglePack.OnNpcDying(npc)
    purgeUnitState(npc)
end

function MeepoJunglePack.OnKeyEvent(data, key)
    if not isEnabled() or not state.mapOpen or not isMouseKey(key) then return end
    if state.mapDragging or cursorOnMapPanel() or os.clock() < (state.mapBlockInputUntil or 0) then
        return false
    end
end

local function applyManualOverride(unit)
    if not isMeepo(unit) then return end

    local duration = widgetGet(ui.manualPause, 2)
    if duration <= 0 then return end

    state.manualUntil[unitId(unit)] = now() + duration
end

function MeepoJunglePack.OnPrepareUnitOrders(data, playerArg, orderArg, targetArg, positionArg, abilityArg, orderIssuerArg, npcArg)
    local dataTable = type(data) == "table" and data or nil
    local identifier = dataTable and dataTable.identifier or nil
    if identifier and type(identifier) == "string" and string.find(identifier, ORDER_PREFIX, 1, true) == 1 then
        return true
    end

    if isEnabled() and state.mapOpen and (state.mapDragging or cursorOnMapPanel() or os.clock() < (state.mapBlockInputUntil or 0)) then
        return false
    end

    if not hasActiveMode() then return true end

    local localPlayer = Players.GetLocal and Players.GetLocal() or nil
    local localPlayerId = localPlayer and sc(Player.GetPlayerID, localPlayer) or -1

    local orderPlayer = dataTable and dataTable.player or playerArg
    if orderPlayer then
        local orderPlayerId = sc(Player.GetPlayerID, orderPlayer)
        if orderPlayerId ~= localPlayerId then return true end
    end

    local issuer = dataTable and dataTable.orderIssuer or orderIssuerArg
    local npc = dataTable and dataTable.npc or npcArg

    if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local selected = localPlayer and Player.GetSelectedUnits and sc(Player.GetSelectedUnits, localPlayer) or {}
        for _, unit in ipairs(selected) do
            applyManualOverride(unit)
        end
    elseif type(npc) == "table" then
        for _, unit in ipairs(npc) do
            applyManualOverride(unit)
        end
    else
        applyManualOverride(npc)
    end

    return true
end

return MeepoJunglePack
