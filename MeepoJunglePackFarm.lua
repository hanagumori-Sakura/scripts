--[[
╭────────────────────────────────────────────────────────────╮
│                                                            │
│             M E E P O   J U N G L E   P A C K              │
│                         F A R M                            │
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

local SCRIPT_ID = "meepo_jungle_pack"
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
local MAP_IMAGE_PATHS = {
    "assets/meepo_farm_minimap.png",
    "C:/Umbrella/assets/meepo_farm_minimap.png",
    "panorama/images/minimap/dotamap_psd.vtex_c",
    "panorama/images/minimap/dotamap_psd_png.vtex_c",
    "panorama/images/minimap/dotamap.vtex_c",
    "panorama/images/minimap/dotamap_png.vtex_c"
}

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
    farmBindPrev = false
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
    tab = {en = "Jungle Pack", ru = "Лесной фарм", cn = "野区编队"},
    group_main = {en = "Main", ru = "Основное", cn = "主要"},
    group_farm = {en = "Farm", ru = "Фарм", cn = "刷野"},
    group_safety = {en = "Safety", ru = "Защита", cn = "安全"},

    ui_enable = {en = "Enable", ru = "Включить", cn = "启用"},
    ui_farm = {en = "Farm", ru = "Фарм", cn = "刷野"},
    ui_farm_key = {en = "Farm Key", ru = "Бинд фарма", cn = "刷野按键"},
    ui_map = {en = "Map", ru = "Карта", cn = "地图"},
    ui_order_delay = {en = "Order delay", ru = "Задержка ордеров", cn = "指令延迟"},
    ui_manual_pause = {en = "Manual pause", ru = "Ручная пауза", cn = "手动暂停"},
    ui_farmers = {en = "Farmers", ru = "Фармеры", cn = "刷野单位"},
    ui_poof = {en = "Poof", ru = "Пуф", cn = "忽悠"},
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
    ui_map_image = {en = "Map image path", ru = "Путь к карте", cn = "地图图片路径"},
    ui_status_x = {en = "Status X", ru = "Статус X", cn = "状态 X"},
    ui_status_y = {en = "Status Y", ru = "Статус Y", cn = "状态 Y"},
    ui_status_gap = {en = "Status row gap", ru = "Шаг статусов", cn = "状态行距"},

    gear_script = {en = "Script timing", ru = "Тайминги", cn = "脚本时序"},
    gear_map = {en = "Panel / status", ru = "Панель / статус", cn = "面板 / 状态"},
    gear_camps = {en = "Camp logic", ru = "Логика кемпов", cn = "野点逻辑"},
    gear_poof = {en = "Poof tuning", ru = "Настройка пуфа", cn = "忽悠设置"},
    gear_danger = {en = "Danger response", ru = "Реакция на врагов", cn = "危险应对"},
    gear_retreat = {en = "Retreat tuning", ru = "Настройка отхода", cn = "撤退设置"},

    farmer_any_unselected = {en = "Any Unselected Meepo", ru = "Любой невыбранный Meepo", cn = "任意未选中米波"},
    farmer_unselected_clones = {en = "Unselected Clones", ru = "Невыбранные клоны", cn = "未选中克隆"},
    farmer_all = {en = "All Meepo", ru = "Все Meepo", cn = "全部米波"},
    farmer_clones = {en = "Only Clones", ru = "Только клоны", cn = "仅克隆"},
    poof_move = {en = "To Movement", ru = "Для перемещения", cn = "用于移动"},
    poof_damage = {en = "To Damage", ru = "Для урона", cn = "用于伤害"},

    bind_farm = {en = "Meepo farm", ru = "Фарм Meepo", cn = "米波刷野"},
    bind_map = {en = "Meepo camp map", ru = "Карта кемпов Meepo", cn = "米波野点地图"},
    bind_toggle = {en = "toggle", ru = "перекл.", cn = "切换"},

    panel_title = {en = "Meepo Farm Settings", ru = "Настройки фарма Meepo", cn = "米波刷野设置"},
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
    status_farm = {en = "FARM", ru = "ФАРМ", cn = "刷"},
    status_join = {en = "JOIN", ru = "СБОР", cn = "集合"},
    status_combo = {en = "COMBO", ru = "КОМБО", cn = "连招"},

    tip_enable = {en = "Master switch. It only enables or disables the script.", ru = "Главный переключатель. Только включает или выключает скрипт.", cn = "总开关。只启用或禁用脚本。"},
    tip_farm = {en = "Actual jungle control state. Toggle it by key or click it here.", ru = "Реальное состояние автофарма. Переключай биндом или кликом.", cn = "实际刷野控制状态。可用按键或点击切换。"},
    tip_farm_key = {en = "Press once to start pack farming, press again to stop.", ru = "Нажми один раз, чтобы начать фарм; ещё раз, чтобы остановить.", cn = "按一次开始编队刷野，再按一次停止。"},
    tip_map = {en = "Opens the camp picker panel.", ru = "Открывает панель выбора кемпов.", cn = "打开野点选择面板。"},
    tip_manual = {en = "After your own order to a Meepo, the script pauses that unit for this long.", ru = "После твоего ордера Meepo скрипт не трогает эту единицу столько секунд.", cn = "你手动给米波下达指令后，脚本会暂停控制该单位这么久。"},
    tip_farmers = {en = "Choose which controlled Meepos the farm mode may use.", ru = "Выбирает, каких контролируемых Meepo можно использовать для фарма.", cn = "选择刷野模式可控制哪些米波。"},
    tip_poof = {en = "Use Poof for moving between camps and/or extra jungle damage.", ru = "Использовать Пуф для перемещения между кемпами и/или дополнительного урона.", cn = "使用忽悠在野点间移动和/或补充刷野伤害。"},
    tip_ancients = {en = "Ancients stay ignored until this is enabled.", ru = "Древние кемпы игнорируются, пока это выключено.", cn = "关闭时会忽略远古野点。"},
    tip_avoid = {en = "When a visible enemy hero gets near a clone, it leaves that area and keeps farming safer camps.", ru = "Если видимый враг рядом с клоном, клон уходит из зоны и продолжает фармить безопаснее.", cn = "可见敌方英雄接近克隆时，克隆会离开该区域并继续刷更安全的野点。"},
    tip_tp = {en = "If Poof is not available during danger, the script can try TP/Travels before walking away.", ru = "Если Пуф недоступен при опасности, скрипт может попробовать TP/Travels перед отходом пешком.", cn = "危险时忽悠不可用，脚本可先尝试传送/飞鞋再步行撤退。"},
    tip_retreat = {en = "Low HP controlled Meepos are sent toward fountain and excluded from pack farm.", ru = "Контролируемые Meepo с низким HP уходят к фонтану и исключаются из фарма.", cn = "低血量米波会回泉水方向，并暂时退出刷野编队。"},
    tip_status = {en = "Draws compact Meepo statuses near the left portrait column.", ru = "Рисует компактные статусы Meepo возле левой колонки портретов.", cn = "在左侧头像栏附近绘制紧凑的米波状态。"},
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

local function createTab()
    local section = sc(Menu.Find, "Heroes", "Hero List", "Meepo")
    if not section then
        section = sc(Menu.Create, "Heroes", "Hero List", "Meepo")
    end

    local tab = section and section.Create and sc(section.Create, section, "Jungle Pack")
    if tab then return tab end

    tab = sc(Menu.Create, "General", "Meepo Jungle Pack", SCRIPT_ID, "Jungle Pack")
    return tab
end

local function createGroup(tab, name)
    if tab and tab.Create then
        local group = sc(tab.Create, tab, name)
        if group then return group end
    end
    return sc(Menu.Create, "General", "Meepo Jungle Pack", SCRIPT_ID, "Jungle Pack", name)
end

local menuTab = createTab()
local gMain = createGroup(menuTab, "Main")
local gFarm = createGroup(menuTab, "Farm")
local gSafety = createGroup(menuTab, "Safety")

local ui = {}

ui.enabled = withTooltip(
    gMain and gMain.Switch and gMain:Switch("Enable script", false, "panorama/images/heroes/icons/npc_dota_hero_meepo_png.vtex_c"),
    "Master switch. It only enables or disables the script."
)
displayName(ui.enabled, "Enable")
ui.farmActive = withTooltip(
    gMain and gMain.Switch and gMain:Switch("Farm mode", false, "\u{f04b}"),
    "Actual jungle control state. Toggle it by key or click it here."
)
displayName(ui.farmActive, "Farm")
ui.farmKey = withTooltip(
    gMain and gMain.Bind and gMain:Bind("Toggle farm key", KEY_NONE, "\u{f084}"),
    "Press once to start pack farming, press again to stop."
)
displayName(ui.farmKey, "Farm Key")
ui.mapKey = withTooltip(
    gMain and gMain.Bind and gMain:Bind("Farm map key", KEY_NONE, "\u{f279}"),
    "Opens the camp picker panel."
)
displayName(ui.mapKey, "Map")
local scriptGear = makeGear(ui.enabled, "Script timing")
local mapGear = makeGear(ui.mapKey, "Panel / status")
if ui.farmKey and ui.farmKey.Properties then
    sc(ui.farmKey.Properties, ui.farmKey, "Meepo farm", "toggle", true)
end
if ui.mapKey and ui.mapKey.Properties then
    sc(ui.mapKey.Properties, ui.mapKey, "Meepo camp map", "toggle", true)
end
if ui.farmActive and ui.farmActive.SetCallback and ui.farmKey and ui.farmKey.SetToggled then
    sc(ui.farmActive.SetCallback, ui.farmActive, function()
        sc(ui.farmKey.SetToggled, ui.farmKey, widgetGet(ui.farmActive, false))
    end, true)
end
ui.orderDelay = scriptGear and scriptGear.Slider and scriptGear:Slider("Order delay", 120, 900, 320, function(v) return v .. " ms" end)
ui.manualPause = withTooltip(
    scriptGear and scriptGear.Slider and scriptGear:Slider("Manual override pause", 0, 6, 2, function(v) return v .. " sec" end),
    "After your own order to a Meepo, the script pauses that unit for this long."
)
displayName(ui.manualPause, "Manual pause")
ui.farmers = withTooltip(
    gFarm and gFarm.Combo and gFarm:Combo("Farmers", {
        L("farmer_any_unselected"),
        L("farmer_unselected_clones"),
        L("farmer_all"),
        L("farmer_clones")
    }, 3),
    "Choose which controlled Meepos the farm mode may use."
)
displayName(ui.farmers, "Farmers")
if ui.farmers and ui.farmers.Image then
    sc(ui.farmers.Image, ui.farmers, "panorama/images/heroes/icons/npc_dota_hero_meepo_png.vtex_c")
end
local farmersGear = makeGear(ui.farmers, "Camp logic")
ui.poofUsage = withTooltip(
    gFarm and gFarm.MultiCombo and gFarm:MultiCombo("Poof Usage", {L("poof_move"), L("poof_damage")}, {L("poof_move")}),
    "Use Poof for moving between camps and/or extra jungle damage."
)
displayName(ui.poofUsage, "Poof")
if ui.poofUsage and ui.poofUsage.Image then
    sc(ui.poofUsage.Image, ui.poofUsage, "panorama/images/spellicons/meepo_poof_png.vtex_c")
end
local poofGear = makeGear(ui.poofUsage, "Poof tuning")
ui.saveMana = gFarm and gFarm.Slider and gFarm:Slider("Save Mana", 0, 90, 40, function(v) return v .. "%" end)
if ui.saveMana and saveManaImage and ui.saveMana.ImageHandle then
    sc(ui.saveMana.ImageHandle, ui.saveMana, saveManaImage)
elseif ui.saveMana and ui.saveMana.Icon then
    sc(ui.saveMana.Icon, ui.saveMana, "\u{f0c3}")
end
ui.joinRadius = farmersGear and farmersGear.Slider and farmersGear:Slider("Pack join radius", 250, 950, 560, function(v) return v .. " u." end)
ui.campRadius = farmersGear and farmersGear.Slider and farmersGear:Slider("Camp creep radius", 450, 1100, 760, function(v) return v .. " u." end)
ui.farmAncients = withTooltip(
    farmersGear and farmersGear.Switch and farmersGear:Switch("Farm ancient camps", false, "\u{f1b2}"),
    "Ancients stay ignored until this is enabled."
)
displayName(ui.farmAncients, "Ancients")

ui.avoidEnemies = withTooltip(
    gSafety and gSafety.Switch and gSafety:Switch("Avoid visible enemies", true, "\u{f071}"),
    "When a visible enemy hero gets near a clone, it leaves that area and keeps farming safer camps."
)
displayName(ui.avoidEnemies, "Avoid Enemies")
local dangerGear = makeGear(ui.avoidEnemies, "Danger response")
ui.enemyAvoidRadius = dangerGear and dangerGear.Slider and dangerGear:Slider("Enemy avoid radius", 800, 2600, DEFAULT_ENEMY_RADIUS, function(v) return v .. " u." end)
ui.tpEscape = withTooltip(
    dangerGear and dangerGear.Switch and dangerGear:Switch("TP escape fallback", true, "\u{f0e7}"),
    "If Poof is not available during danger, the script can try TP/Travels before walking away."
)
displayName(ui.tpEscape, "TP fallback")
ui.retreatLow = withTooltip(
    gSafety and gSafety.Switch and gSafety:Switch("Retreat low HP Meepos", true, "\u{f0f9}"),
    "Low HP controlled Meepos are sent toward fountain and excluded from pack farm."
)
displayName(ui.retreatLow, "Low HP Retreat")
local retreatGear = makeGear(ui.retreatLow, "Retreat tuning")
ui.retreatHp = retreatGear and retreatGear.Slider and retreatGear:Slider("Retreat HP", 10, 70, 28, function(v) return v .. "%" end)

ui.poofDistance = poofGear and poofGear.Slider and poofGear:Slider("Poof move distance", 700, 2600, 1350, function(v) return v .. " u." end)
ui.poofCooldown = poofGear and poofGear.Slider and poofGear:Slider("Poof retry delay", 1, 8, 3, function(v) return v .. " sec" end)

ui.showStatus = withTooltip(
    mapGear and mapGear.Switch and mapGear:Switch("Portrait statuses", true, "\u{f06e}"),
    "Draws compact Meepo statuses near the left portrait column."
)
displayName(ui.showStatus, "Portrait Status")
ui.mapImagePath = withTooltip(
    mapGear and mapGear.Input and mapGear:Input("Map image path", "", "\u{f03e}"),
    "Optional minimap image path or URL. Empty value uses local override first, then the Dota minimap texture."
)
ui.statusX = mapGear and mapGear.Slider and mapGear:Slider("Status X", 0, 600, 112, "%d")
ui.statusY = mapGear and mapGear.Slider and mapGear:Slider("Status Y", 0, 900, 42, "%d")
ui.statusGap = mapGear and mapGear.Slider and mapGear:Slider("Status row gap", 35, 110, 73, "%d")

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

local function applyLocalization(force)
    local lang = languageCode()
    if not force and state.lastLanguage == lang then return end
    state.lastLanguage = lang

    displayName(menuTab, L("tab"))
    displayName(gMain, L("group_main"))
    displayName(gFarm, L("group_farm"))
    displayName(gSafety, L("group_safety"))

    displayName(scriptGear, L("gear_script"))
    displayName(mapGear, L("gear_map"))
    displayName(farmersGear, L("gear_camps"))
    displayName(poofGear, L("gear_poof"))
    displayName(dangerGear, L("gear_danger"))
    displayName(retreatGear, L("gear_retreat"))

    localizeWidget(ui.enabled, "ui_enable", "tip_enable")
    localizeWidget(ui.farmActive, "ui_farm", "tip_farm")
    localizeWidget(ui.farmKey, "ui_farm_key", "tip_farm_key")
    localizeWidget(ui.mapKey, "ui_map", "tip_map")
    localizeWidget(ui.orderDelay, "ui_order_delay")
    localizeWidget(ui.manualPause, "ui_manual_pause", "tip_manual")
    localizeWidget(ui.farmers, "ui_farmers", "tip_farmers")
    localizeWidget(ui.poofUsage, "ui_poof", "tip_poof")
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
    localizeWidget(ui.mapImagePath, "ui_map_image", "tip_map_image")
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

local function setupLanguageReloadCallback()
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

applyLocalization(true)
setupLanguageReloadCallback()

local function isEnabled()
    return widgetGet(ui.enabled, false)
end

local function isFarmActive()
    return isEnabled() and widgetGet(ui.farmActive, false)
end

local function setMapOpen(open)
    state.mapOpen = open == true
    if ui.mapKey and ui.mapKey.SetToggled then
        sc(ui.mapKey.SetToggled, ui.mapKey, state.mapOpen)
    end
end

local function checkFarmToggleBind()
    if not isEnabled() or not ui.farmKey or not ui.farmKey.IsPressed then
        state.farmBindPrev = false
        return
    end

    local pressed = sc(ui.farmKey.IsPressed, ui.farmKey) == true
    if pressed and not state.farmBindPrev and ui.farmActive and ui.farmActive.Set then
        sc(ui.farmActive.Set, ui.farmActive, not widgetGet(ui.farmActive, false))
    end
    state.farmBindPrev = pressed
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

local function dist2D(a, b)
    if not a or not b then return math.huge end
    local ok, d = pcall(function() return (a - b):Length2D() end)
    if ok and type(d) == "number" then return d end

    local ax = a.GetX and a:GetX() or a.x or 0
    local ay = a.GetY and a:GetY() or a.y or 0
    local bx = b.GetX and b:GetX() or b.x or 0
    local by = b.GetY and b:GetY() or b.y or 0
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
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

local function campWaitPosition(center, team)
    if not center then return nil end

    local base = basePosition(team)
    local dx = base:GetX() - center:GetX()
    local dy = base:GetY() - center:GetY()
    local len = math.sqrt(dx * dx + dy * dy)

    if len < 1 then
        dx, dy, len = 1, 0, 1
    end

    local distance = RESPAWN_WAIT_DISTANCE
    return Vector(
        center:GetX() + dx / len * distance,
        center:GetY() + dy / len * distance,
        center:GetZ()
    )
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

local function clearStatuses()
    state.statusById = {}
    state.statusList = {}
end

local function setStatus(unit, text, color, groupId)
    if not unit then return end

    state.statusById[unitId(unit)] = {
        unit = unit,
        text = text or L("status_wait"),
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

local function getControllableMeepos(localHero, player, playerId, team)
    local result, seen = {}, {}
    local selectedIds = buildSelectedIds(player)

    local heroes = sc(Heroes.GetAll) or {}
    for _, hero in pairs(heroes) do
        addMeepo(result, seen, hero, playerId, team, localHero, selectedIds)
    end

    local npcs = sc(NPCs.GetAll) or {}
    for _, npc in pairs(npcs) do
        addMeepo(result, seen, npc, playerId, team, localHero, selectedIds)
    end

    local localHeroId = unitId(localHero)
    table.sort(result, function(a, b)
        local aMain = unitId(a) == localHeroId
        local bMain = unitId(b) == localHeroId
        if aMain ~= bMain then return aMain end
        return unitId(a) < unitId(b)
    end)
    return result
end

local function packCenter(units)
    local sx, sy, sz, count = 0, 0, 0, 0
    for _, unit in ipairs(units) do
        local pos = origin(unit)
        if pos then
            sx = sx + pos:GetX()
            sy = sy + pos:GetY()
            sz = sz + pos:GetZ()
            count = count + 1
        end
    end

    if count == 0 then return nil end
    return Vector(sx / count, sy / count, sz / count)
end

local function formationPosition(center, index, count)
    if not center or count <= 1 then return center end
    local radius = math.min(140, math.max(45, widgetGet(ui.joinRadius, 560) * 0.18))
    local angle = ((index - 1) / count) * math.pi * 2
    return Vector(
        center:GetX() + math.cos(angle) * radius,
        center:GetY() + math.sin(angle) * radius,
        center:GetZ()
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

local function collectNeutrals()
    local result = {}
    local npcs = sc(NPCs.GetAll) or {}

    for _, unit in pairs(npcs) do
        if isValidNeutral(unit) then
            result[#result + 1] = {
                unit = unit,
                pos = origin(unit),
                hp = sc(Entity.GetHealth, unit) or 99999
            }
        end
    end

    return result
end

local function campCenter(camp)
    local box = sc(Camp.GetCampBox, camp)
    if not box or not box.min or not box.max then return nil end

    return Vector(
        (box.min:GetX() + box.max:GetX()) / 2,
        (box.min:GetY() + box.max:GetY()) / 2,
        (box.min:GetZ() + box.max:GetZ()) / 2
    )
end

local function campAllowed(camp)
    if widgetGet(ui.farmAncients, false) then return true end
    local ancientType = Enum.ECampType and Enum.ECampType.ECampType_ANCIENT
    if ancientType == nil then return true end
    local campType = sc(Camp.GetType, camp)
    return campType ~= ancientType
end

local function hasSelectedCamps()
    for _, selected in pairs(state.selectedCamps) do
        if selected == true then return true end
    end
    return false
end

local function campAllowedBySelection(info)
    if not info then return false end
    if not hasSelectedCamps() then return true end
    return state.selectedCamps[info.id] == true
end

local function nextNeutralSpawnTime(t)
    return t + secondsToNextMinute() + EMPTY_LOCK_EXTRA
end

local function getCampMemory(campId)
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

local function shouldWaitCamp(info, t)
    if not info or info.target then return false end

    local memory = state.campMemory[info.id]
    return memory and memory.waitUntil and t < memory.waitUntil
end

local function buildCampInfo(camp, index, neutrals)
    if not campAllowed(camp) then return nil end

    local center = campCenter(camp)
    if not center then return nil end

    local radius = widgetGet(ui.campRadius, 760)
    local count = 0
    local target = nil
    local bestTargetScore = math.huge

    for _, neutral in ipairs(neutrals) do
        local d = dist2D(center, neutral.pos)
        if d <= radius then
            count = count + 1
            local score = neutral.hp + d * 0.05
            if score < bestTargetScore then
                bestTargetScore = score
                target = neutral.unit
            end
        end
    end

    return {
        id = index,
        center = center,
        target = target,
        count = count
    }
end

local function collectCampInfos(neutrals, t)
    local infos = {}
    local camps = sc(Camps.GetAll)

    if camps and #camps > 0 then
        for i, camp in ipairs(camps) do
            local info = updateCampMemory(buildCampInfo(camp, i, neutrals), t)
            if info and campAllowedBySelection(info) then
                infos[#infos + 1] = info
            end
        end
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

    return infos
end

local function minDistanceToUnits(center, units)
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

local function takeNearestUnits(pool, center, count)
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

local function takePreferredUnits(pool, center, count, campId)
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

local function newGroup(index, camp, units, role, minSize)
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

local function plannedGroupSizes(count)
    local sizes = {}
    if count <= 0 then return sizes end
    if count == 1 then return {1} end

    local pairs = math.floor(count / 2)
    for _ = 1, pairs do
        sizes[#sizes + 1] = 2
    end

    if count % 2 == 1 then
        sizes[#sizes + 1] = 1
    end

    return sizes
end

local function addUnitToGroup(group, unit, role)
    if not group or not unit then return end

    group.units[#group.units + 1] = unit
    group.roles[unitId(unit)] = role or "HELP"
end

local function groupCenter(group)
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

local function enemyAvoidRadius()
    return widgetGet(ui.enemyAvoidRadius, DEFAULT_ENEMY_RADIUS)
end

local function pruneEnemyAvoid(t)
    for i = #state.enemyAvoid, 1, -1 do
        if not state.enemyAvoid[i].pos or t >= (state.enemyAvoid[i].untilTime or 0) then
            table.remove(state.enemyAvoid, i)
        end
    end
end

local function rememberEnemyAvoid(pos, t)
    if not pos then return end
    for _, danger in ipairs(state.enemyAvoid) do
        if danger.pos and dist2D(danger.pos, pos) <= 250 then
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

local function minDistanceToEnemyAvoid(pos, t)
    pruneEnemyAvoid(t)
    local best = math.huge

    for _, danger in ipairs(state.enemyAvoid) do
        local d = dist2D(pos, danger.pos)
        if d < best then best = d end
    end

    return best
end

local function campSafeFromEnemies(info, t)
    if not widgetGet(ui.avoidEnemies, true) then return true end
    return minDistanceToEnemyAvoid(info.center, t) > enemyAvoidRadius()
end

local function buildGroups(active, neutrals, t, team)
    local groups = {}
    local groupSizes = plannedGroupSizes(#active)
    local sizeIndex = 1

    if #active == 0 or #groupSizes == 0 then
        return groups
    end

    local pool = {}
    for _, unit in ipairs(active) do pool[#pool + 1] = unit end

    local function nextSize()
        return groupSizes[sizeIndex]
    end

    local function makeGroup(camp, role, preferred)
        local size = nextSize()
        if not size or #pool < size then return false end

        local chosen
        if preferred then
            chosen, pool = takePreferredUnits(pool, camp.center, size, camp.id)
        else
            chosen, pool = takeNearestUnits(pool, camp.center, size)
        end

        if not chosen then return false end

        local group = newGroup(#groups + 1, camp, chosen, role, size)
        groups[#groups + 1] = group
        sizeIndex = sizeIndex + 1
        return true
    end

    local infos = collectCampInfos(neutrals, t)
    local waiting, visible, scouts = {}, {}, {}

    for _, info in ipairs(infos) do
        if not campSafeFromEnemies(info, t) then
            -- Dangerous camps are skipped until the last visible enemy position expires.
        elseif shouldWaitCamp(info, t) then
            waiting[#waiting + 1] = info
        elseif info.target and info.count > 0 then
            visible[#visible + 1] = info
        elseif t >= (state.emptyUntil[info.id] or 0) then
            scouts[#scouts + 1] = info
        end
    end

    table.sort(waiting, function(a, b)
        local da = minDistanceToUnits(a.center, pool)
        local db = minDistanceToUnits(b.center, pool)
        if da == db then return tostring(a.id) < tostring(b.id) end
        return da < db
    end)

    local usedCamps = {}
    for _, camp in ipairs(waiting) do
        if not nextSize() then break end
        if makeGroup(camp, "WAIT", true) then
            local group = groups[#groups]
            camp.waitPos = camp.waitPos or campWaitPosition(camp.center, team)
            group.camp.waitPos = camp.waitPos
            usedCamps[camp.id] = true
        end
    end

    table.sort(visible, function(a, b)
        local aSticky, bSticky = 0, 0
        for _, unit in ipairs(pool) do
            if state.unitCamp[unitId(unit)] == a.id then aSticky = aSticky + 1 end
            if state.unitCamp[unitId(unit)] == b.id then bSticky = bSticky + 1 end
        end

        local da = minDistanceToUnits(a.center, pool) - (a.count or 0) * 90 - aSticky * 350
        local db = minDistanceToUnits(b.center, pool) - (b.count or 0) * 90 - bSticky * 350
        if da == db then return tostring(a.id) < tostring(b.id) end
        return da < db
    end)

    for _, camp in ipairs(visible) do
        if not nextSize() then break end
        if not usedCamps[camp.id] then
            if makeGroup(camp, "FARM", true) then
                usedCamps[camp.id] = true
            end
        end
    end

    while nextSize() and #scouts > 0 do
        local bestIndex, bestCamp, bestDist = nil, nil, math.huge

        for index, camp in ipairs(scouts) do
            if not usedCamps[camp.id] then
                local d = minDistanceToUnits(camp.center, pool)
                if d < bestDist then
                    bestIndex = index
                    bestCamp = camp
                    bestDist = d
                end
            end
        end

        if not bestCamp then break end

        if makeGroup(bestCamp, "SCOUT", false) then
            usedCamps[bestCamp.id] = true
        end

        table.remove(scouts, bestIndex)
    end

    for _, unit in ipairs(pool) do
        local group = nearestGroup(unit, groups)
        if group then
            addUnitToGroup(group, unit, "HELP")
        else
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_wait"), statusColor.wait)
        end
    end

    return groups
end

local function countNear(units, pos, radius)
    local count = 0
    for _, unit in ipairs(units) do
        local upos = origin(unit)
        if upos and dist2D(upos, pos) <= radius then
            count = count + 1
        end
    end
    return count
end

local function visibleEnemyNearUnit(unit, team)
    if not widgetGet(ui.avoidEnemies, true) then return nil end

    local pos = origin(unit)
    if not pos then return nil end

    local radius = enemyAvoidRadius()
    local nearby = sc(Heroes.InRadius, pos, radius, team, Enum.TeamType.TEAM_ENEMY, true, true)
    if nearby then
        for _, hero in ipairs(nearby) do
            if alive(hero) and visible(hero) and sc(NPC.IsIllusion, hero) ~= true then
                local hpos = origin(hero)
                if hpos then return hero, hpos end
            end
        end
    end

    local heroes = sc(Heroes.GetAll) or {}
    for _, hero in pairs(heroes) do
        if hero ~= unit and alive(hero) and visible(hero) and sc(Entity.GetTeamNum, hero) ~= team and sc(NPC.IsIllusion, hero) ~= true then
            local hpos = origin(hero)
            if hpos and dist2D(pos, hpos) <= radius then return hero, hpos end
        end
    end

    return nil
end

local function canOrder(unit, orderType, target, pos, t)
    local id = unitId(unit)
    local last = state.lastOrder[id]
    local delay = math.max(0.05, widgetGet(ui.orderDelay, 320) / 1000)

    if last and t - last.time < delay then return false end

    if orderType == "move" then
        local upos = origin(unit)
        if upos and pos and dist2D(upos, pos) < 110 then return false end
        if last and last.type == "move" and last.pos and pos and dist2D(last.pos, pos) < 140 and t - last.time < 1.2 then
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

local function issueMove(player, unit, pos, t)
    if not player or not unit or not pos or not canOrder(unit, "move", nil, pos, t) then return false end
    sc(Player.PrepareUnitOrders, player, O_MOVE, nil, pos, nil, ISSUER, unit, false, false, false, false, ORDER_PREFIX .. "move", false)
    rememberOrder(unit, "move", nil, pos, t)
    return true
end

local function issueAttack(player, unit, target, t)
    if not player or not unit or not target or not canOrder(unit, "attack", target, nil, t) then return false end
    sc(Player.PrepareUnitOrders, player, O_ATTACK, target, Vector(), nil, ISSUER, unit, false, false, false, false, ORDER_PREFIX .. "attack", false)
    rememberOrder(unit, "attack", target, nil, t)
    return true
end

local function canSpendMana(unit)
    return manaPct(unit) > widgetGet(ui.saveMana, 40)
end

local function tryPoof(unit, pos, t, mode)
    if not unit or not pos then return false end
    if mode == "move" and not multiEnabled(ui.poofUsage, LAll("poof_move")) then return false end
    if mode == "damage" and not multiEnabled(ui.poofUsage, LAll("poof_damage")) then return false end
    if not canSpendMana(unit) then return false end

    local upos = origin(unit)
    if not upos then return false end

    local castPos = pos
    if (mode == "move" or mode == "escape") and state.localHero and unitId(state.localHero) ~= unitId(unit) and alive(state.localHero) then
        local heroPos = origin(state.localHero)
        if heroPos and dist2D(heroPos, pos) <= 650 and dist2D(upos, heroPos) > 650 then
            castPos = heroPos
        end
    end

    local distance = dist2D(upos, castPos)
    if mode == "move" and distance < widgetGet(ui.poofDistance, 1350) then return false end
    if mode == "escape" and distance < 850 then return false end
    if mode == "damage" and distance > 575 then return false end
    if sc(NPC.IsChannellingAbility, unit) == true then return false end

    local id = unitId(unit)
    if t - (state.lastPoof[id] or 0) < widgetGet(ui.poofCooldown, 3) then return false end

    local poof = sc(NPC.GetAbility, unit, "meepo_poof")
    local mana = sc(NPC.GetMana, unit) or 0
    if poof and sc(Ability.IsCastable, poof, mana) == true then
        sc(Ability.CastPosition, poof, castPos, false, true, false, ORDER_PREFIX .. "poof", false)
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

    local dangerById = {}
    for _, unit in ipairs(active) do
        local _, enemyPos = visibleEnemyNearUnit(unit, team)
        if enemyPos then
            dangerById[unitId(unit)] = enemyPos
            rememberEnemyAvoid(enemyPos, t)
        end
    end

    local farming = {}
    local radius = enemyAvoidRadius()
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
            if not tryPoof(unit, safePos, t, "escape") and not tryTeleportEscape(unit, safePos, t, team) then
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
    if dist2D(packPos, camp.center) <= math.max(700, widgetGet(ui.campRadius, 760) * 0.85) then
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

    for i, unit in ipairs(group.units) do
        local role = group.roles[unitId(unit)] or group.role
        state.unitCamp[unitId(unit)] = group.camp.id

        if role == "HELP" then
            setStatus(unit, L("status_help") .. " G" .. group.index, statusColor.help, group.index)
        elseif group.role == "WAIT" then
            local left = group.camp.waitUntil and math.max(0, math.ceil(group.camp.waitUntil - t)) or math.ceil(secondsToNextMinute())
            setStatus(unit, "G" .. group.index .. " " .. L("status_wait") .. " " .. left, statusColor.wait, group.index)
        elseif not target then
            setStatus(unit, "G" .. group.index .. " " .. L("status_scout"), statusColor.scout, group.index)
        elseif readyToAttack then
            local label = requiredCount == 1 and (" " .. L("status_solo")) or (" " .. L("status_farm"))
            setStatus(unit, "G" .. group.index .. label, statusColor.farm, group.index)
        else
            setStatus(unit, "G" .. group.index .. " " .. L("status_join"), statusColor.move, group.index)
        end

        if readyToAttack and tryPoof(unit, joinPos, t, "damage") then
            -- Damage Poof replaces the attack order for this tick.
        elseif not readyToAttack and tryPoof(unit, joinPos, t, "move") then
            -- Poof order is enough for this tick.
        elseif readyToAttack then
            issueAttack(player, unit, target, t)
        else
            issueMove(player, unit, formationPosition(joinPos, i, #group.units), t)
        end
    end
end

local function runPackFarm(player, units, team, t)
    clearStatuses()

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
        elseif shouldRetreat(unit) then
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_base"), statusColor.base)
            issueMove(player, unit, base, t)
        else
            active[#active + 1] = unit
        end
    end

    if #active == 0 then
        finalizeStatuses(units)
        return
    end

    local neutrals = collectNeutrals()
    active = avoidVisibleEnemies(player, active, neutrals, team, t)
    if #active == 0 then
        finalizeStatuses(units)
        return
    end

    local groups = buildGroups(active, neutrals, t, team)

    if #groups == 0 then
        for _, unit in ipairs(active) do
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_wait"), statusColor.wait)
        end
        finalizeStatuses(units)
        return
    end

    for _, group in ipairs(groups) do
        commandGroup(player, group, t, team)
    end

    finalizeStatuses(units)
end

function MeepoJunglePack.OnUpdate()
    if Engine and Engine.IsInGame and sc(Engine.IsInGame) ~= true then
        state.statusList = {}
        setMapOpen(false)
        return
    end
    if not isEnabled() then
        state.statusList = {}
        setMapOpen(false)
        return
    end

    checkFarmToggleBind()
    checkMapToggleBind()

    if not isFarmActive() then
        state.statusList = {}
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
        state.statusList = {}
        return
    end

    local team = sc(Entity.GetTeamNum, hero)
    if not team then
        state.statusList = {}
        return
    end

    local meepos = getControllableMeepos(hero, player, playerId, team)
    if #meepos == 0 then
        state.statusList = {}
        return
    end

    if comboKeyActive(t) then
        clearStatuses()
        for _, unit in ipairs(meepos) do
            state.unitCamp[unitId(unit)] = nil
            setStatus(unit, L("status_combo"), statusColor.combo)
        end
        finalizeStatuses(meepos)
        return
    end

    runPackFarm(player, meepos, team, t)
end

function MeepoJunglePack.OnUpdateEx()
    setupLanguageReloadCallback()
    applyLocalization(false)
end

local function statusTextSize(text)
    if Render and Render.TextSize and statusFont then
        local size = sc(Render.TextSize, statusFont, 12, text)
        if size and size.x and size.y then return size.x, size.y end
    end

    return #tostring(text) * 7, 12
end

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

local function syncMapTheme(force)
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

local function cursorOnMapPanel()
    if not state.mapOpen then return false end
    local x, y = cursorPos()
    if not x or not y then return false end

    local layout = mapLayout()
    updateMapRects(layout)
    return rectContains(state.mapRects.panel, x, y)
end

local function campSideByCenter(center)
    if not center then return "dire" end
    return (center:GetX() + center:GetY()) < 0 and "radiant" or "dire"
end

local function collectMapCamps()
    local infos = {}
    local camps = sc(Camps.GetAll)
    if not camps then return infos end

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

    return infos
end

local function selectedCampCount()
    local count = 0
    for _, selected in pairs(state.selectedCamps) do
        if selected == true then count = count + 1 end
    end
    return count
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
    local x = layout.mapX + MAP_DOT_PADDING + (pos:GetX() - MAP_WORLD_MIN) * scale
    local y = layout.mapY + MAP_DOT_PADDING + usableSize - (pos:GetY() - MAP_WORLD_MIN) * scale
    x = clamp(x, layout.mapX + MAP_DOT_PADDING, layout.mapX + layout.mapSize - MAP_DOT_PADDING)
    y = clamp(y, layout.mapY + MAP_DOT_PADDING, layout.mapY + layout.mapSize - MAP_DOT_PADDING)
    return x, y
end

local function drawText(text, x, y, size, color)
    if statusFont then
        sc(Render.Text, statusFont, size or 12, text, Vec2(x, y), color or mapColor.text)
    end
end

local function drawFarmMap()
    if not state.mapOpen or not isEnabled() or not Render or not statusFont then return end

    syncMapTheme(false)

    local layout = mapLayout()
    state.mapCampRects = {}
    updateMapRects(layout)

    sc(Render.FilledRect, Vec2(layout.x, layout.y), Vec2(layout.x + layout.w, layout.y + layout.h), mapColor.panel, 5)
    sc(Render.Rect, Vec2(layout.x, layout.y), Vec2(layout.x + layout.w, layout.y + layout.h), mapColor.border, 5, Enum.DrawFlags and Enum.DrawFlags.None or 0, 1)
    sc(Render.FilledRect, Vec2(layout.x, layout.y), Vec2(layout.x + layout.w, layout.y + layout.headerH), mapColor.header, 5)
    drawText(L("panel_title"), layout.x + 12, layout.y + 6, 14, mapColor.text)
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

    pruneEnemyAvoid(now())
    local avoidScale = layout.mapSize / (MAP_WORLD_MAX - MAP_WORLD_MIN)
    for _, danger in ipairs(state.enemyAvoid) do
        local px, py = worldToMap(danger.pos, layout)
        if px and py then
            sc(Render.Circle, Vec2(px, py), enemyAvoidRadius() * avoidScale, mapColor.danger, 2)
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
end

local function handleFarmMapClick()
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

function MeepoJunglePack.OnDraw()
    drawFarmMap()

    if not isFarmActive() then return end
    if not widgetGet(ui.showStatus, true) then return end
    if not Render or not statusFont then return end

    local list = state.statusList
    if not list or #list == 0 then return end

    local x = widgetGet(ui.statusX, 112)
    local y = widgetGet(ui.statusY, 42)
    local gap = widgetGet(ui.statusGap, 73)

    for row, entry in ipairs(list) do
        local text = entry.text or L("status_wait")
        local color = entry.color or statusColor.wait
        local rowY = y + (row - 1) * gap
        local textW, textH = statusTextSize(text)
        local width = math.max(58, textW + 20)
        local height = math.max(17, textH + 5)
        local topLeft = Vec2(x, rowY)
        local bottomRight = Vec2(x + width, rowY + height)
        local textPos = Vec2(x + 14, rowY + 2)

        sc(Render.FilledRect, topLeft, bottomRight, statusColor.bg, 4)
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

local function isMouseKey(key)
    if not Enum.ButtonCode then return false end
    return key == Enum.ButtonCode.KEY_MOUSE1
        or key == Enum.ButtonCode.KEY_MOUSE2
        or key == Enum.ButtonCode.KEY_MOUSE3
        or key == Enum.ButtonCode.KEY_MOUSE4
        or key == Enum.ButtonCode.KEY_MOUSE5
        or key == Enum.ButtonCode.KEY_MWHEELUP
        or key == Enum.ButtonCode.KEY_MWHEELDOWN
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

    if not isFarmActive() then return true end

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
