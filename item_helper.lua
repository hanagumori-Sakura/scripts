--[[
╭────────────────────────────────────────────────────────────╮
│                                                            │
│                    I T E M   H E L P E R                   │
│                                                            │
│                     Script by Euphoria                     │
│                                                            │
├────────────────────────────────────────────────────────────┤
│                        By Pidaras                          │
│                           VibeCode                         │
╰────────────────────────────────────────────────────────────╯
--]]

local script = {}
--------------------------------------------------------------------------------
-- LOCALIZATION
--------------------------------------------------------------------------------
local LANG = "en"
local _langWidget = nil
local _langLastCheck = 0

local L_STRINGS = {
    en = {
        title           = "ITEM HELPER",
        enemies         = "ENEMIES",
        threats         = "THREATS",
        recommended     = "RECOMMENDED",
        analyzing       = "Analyzing enemy team...",
        no_enemies      = "No enemies detected",
        owned           = "OWNED",
        early           = "EARLY",
        mid             = "MID",
        late            = "LATE",
        -- Game modes
        mode_unknown    = "UNKNOWN",
        mode_allpick    = "ALL PICK",
        mode_ranked     = "RANKED",
        mode_turbo      = "TURBO",
        mode_draft      = "DRAFT",
        mode_random     = "RANDOM",
        -- Tips
        tip_invis       = "!! Many invis — buy Dust/Sentries!",
        tip_magic       = "!! Heavy magic dmg — Pipe/BKB!",
        tip_heal        = "!! Much healing — Spirit Vessel!",
        tip_phys        = "!! Heavy phys dmg — Guard/AC!",
        tip_illusions   = "!! Illusions — Mjollnir/BF!",
        tip_disable     = "!! Heavy CC — BKB/Lotus!",
        -- Menu
        m_enable        = "Enable Helper",
        m_panel         = "Show Panel",
        m_auto          = "Auto Analyze",
        m_max           = "Max Suggestions",
        m_reasons       = "Show Reasons",
        m_threats       = "Show Threat Analysis",
        m_owned         = "Highlight Owned",
        m_scale         = "Panel Scale %",
        m_offx          = "Offset X",
        m_offy          = "Offset Y",
        m_opacity       = "Opacity %",
        m_side          = "Panel Side",
        m_left          = "Left",
        m_right         = "Right",
        m_visibility    = "Show Mode",
        m_vis_always    = "Always",
        m_vis_menu      = "Cheat Menu Only",
        m_vis_shop      = "Shop Only",
        m_vis_both      = "Menu or Shop",
        m_show_gold     = "Show Gold in Header",
        m_show_score_breakdown = "Show Score Breakdown",
        m_show_category_badges = "Show Category Badges",
        m_breakdown_chips = "Breakdown Chips",
        net_worth       = "NET WORTH",
        hero_counters   = "HERO COUNTERS",
        enemy_focus     = "ENEMY FOCUS",
        waiting_data    = "Waiting for data...",
        alive           = "ALIVE",
        dead            = "DEAD",
        gold_unknown    = "--",
        cat_must_have   = "MUST",
        cat_situational = "SIT",
        cat_luxury      = "LUX",
        no_data         = "No recommendations yet",
        -- Menu sections & options (for settings panel)
        m_menu_settings = "Settings",
        m_section_general = "General",
        m_section_analysis = "Analysis",
        m_section_panel = "Panel Settings",
        m_section_filter = "Enemy Filter",
        m_section_debug = "Debug",
        m_panel_key = "Panel Key",
        m_panel_mode = "Panel Mode",
        m_mode_extended = "Extended",
        m_mode_minimal = "Minimal",
        m_scale_panel = "Panel Scale %",
        m_track_enemy_items = "Enemy Item Tracking",
        m_counter_pick = "Counter-pick Items",
        m_networth_analysis = "Networth Analysis",
        m_focus_lines = "Focus Lines",
        m_focus_rows = "Focus Rows",
        m_focus_settings = "Focus Settings",
        m_neutrals = "Neutral Items",
        m_highlight_owned = "Highlight Purchased",
        m_gold_header = "Gold in Header",
        m_show_panel_vis = "Show Panel",
        m_filter_mode = "Filter Mode",
        m_filter_all = "All Enemies",
        m_filter_selected = "Selected Only",
        m_filter_exclude = "Exclude Selected",
        m_filter_heroes = "Hero Filter",
        m_score_breakdown = "Score Breakdown",
        m_breakdown_settings = "Breakdown Settings",
        m_breakdown_chip_count = "Chip Count",
        -- Tooltips
        m_tt_enable = "Enable or disable the entire script",
        m_tt_panel = "Show/hide the item recommendations panel",
        m_tt_panel_key = "Key to toggle the panel (Alt / Ctrl / any key)",
        m_tt_panel_mode = "Extended: full info. Minimal: items and targets only",
        m_tt_auto = "Analyze enemy draft every 2 seconds",
        m_tt_max = "Maximum number of items in the suggestions list",
        m_tt_reasons = "Show the reason for each item recommendation",
        m_tt_threats = "Show threat tags of the enemy draft (silence, stun, burst...)",
        m_tt_track_enemy = "Track enemy heroes' items for better analysis",
        m_tt_counter_pick = "Item recommendations based on hero counters",
        m_tt_networth = "Team networth comparison bar",
        m_tt_focus_lines = "Detailed focus lines per enemy hero",
        m_tt_focus_rows = "Number of enemy hero rows to show",
        m_tt_neutrals = "Recommend neutral items for current tier",
        m_tt_scale = "Panel scale: font, padding, size. Increase for 2K/4K",
        m_tt_opacity = "Panel opacity. 100% = fully opaque",
        m_tt_owned = "Highlight items you already own",
        m_tt_gold_header = "Turn off if gold value displays incorrectly",
        m_tt_vis_mode = "When to show the panel on screen",
        m_tt_filter_mode = "Analyze all enemies, selected only, or exclude selected",
        m_tt_filter_list = "Icons appear after enemy heroes are detected",
        m_tt_category_badges = "Show MUST / SITUATIONAL / LUXURY on item cards",
        m_tt_score_breakdown = "Compact chips with score contribution",
        m_tt_breakdown_chips = "How many score chips to show per item",
    },
    ru = {
        title           = "ITEM HELPER",
        enemies         = "ВРАГИ",
        threats         = "УГРОЗЫ",
        recommended     = "РЕКОМЕНДАЦИИ",
        analyzing       = "Анализ вражеской команды...",
        no_enemies      = "Враги не обнаружены",
        owned           = "ЕСТЬ",
        early           = "РАННЯЯ",
        mid             = "СЕРЕДИНА",
        late            = "ПОЗДНЯЯ",
        -- Game modes
        mode_unknown    = "НЕИЗВЕСТНО",
        mode_allpick    = "ALL PICK",
        mode_ranked     = "RANKED",
        mode_turbo      = "TURBO",
        mode_draft      = "DRAFT",
        mode_random     = "RANDOM",
        -- Tips
        tip_invis       = "!! Много инвизов — Dust/Sentries!",
        tip_magic       = "!! Много маг. урона — Pipe/BKB!",
        tip_heal        = "!! Много хила — Spirit Vessel!",
        tip_phys        = "!! Много физ. урона — Guard/AC!",
        tip_illusions   = "!! Иллюзии — Mjollnir/BF!",
        tip_disable     = "!! Много контроля — BKB/Lotus!",
        m_enable        = "Включить хелпер",
        m_panel         = "Показать панель",
        m_auto          = "Авто-анализ",
        m_max           = "Макс. предметов",
        m_reasons       = "Показать причины",
        m_threats       = "Показать анализ угроз",
        m_owned         = "Подсвечивать купленные",
        m_scale         = "Масштаб %",
        m_offx          = "Смещение X",
        m_offy          = "Смещение Y",
        m_opacity       = "Прозрачность %",
        m_side          = "Сторона панели",
        m_left          = "Слева",
        m_right         = "Справа",
        m_visibility    = "Режим показа",
        m_vis_always    = "Всегда",
        m_vis_menu      = "Только меню чита",
        m_vis_shop      = "Только магазин",
        m_vis_both      = "Меню или магазин",
        m_show_gold     = "Показывать золото в шапке",
        m_show_score_breakdown = "Показать разбор очков",
        m_show_category_badges = "Показать бейджи категорий",
        m_breakdown_chips = "Чипы разбора",
        net_worth       = "СЕТ. СТОИМОСТЬ",
        hero_counters   = "КОНТРЫ ГЕРОЯМ",
        enemy_focus     = "ФОКУС ВРАГА",
        waiting_data    = "Ожидание данных...",
        alive           = "ЖИВ",
        dead            = "МЕРТВ",
        gold_unknown    = "--",
        cat_must_have   = "НУЖЕН",
        cat_situational = "СИТ",
        cat_luxury      = "ЛЮКС",
        no_data         = "Пока нет рекомендаций",
        -- Menu sections & options
        m_menu_settings = "Настройки",
        m_section_general = "Общее",
        m_section_analysis = "Анализ",
        m_section_panel = "Настройки панели",
        m_section_filter = "Фильтр врагов",
        m_section_debug = "Отладка",
        m_panel_key = "Клавиша панели",
        m_panel_mode = "Режим панели",
        m_mode_extended = "Расширенный",
        m_mode_minimal = "Минимальный",
        m_scale_panel = "Масштаб панели %",
        m_track_enemy_items = "Трекинг предметов врагов",
        m_counter_pick = "Контр-пик предметы",
        m_networth_analysis = "Анализ нетворса",
        m_focus_lines = "Строки фокуса",
        m_focus_rows = "Строк фокуса",
        m_focus_settings = "Настройки фокуса",
        m_neutrals = "Нейтральные предметы",
        m_highlight_owned = "Подсветка купленных",
        m_gold_header = "Золото в заголовке",
        m_show_panel_vis = "Показывать панель",
        m_filter_mode = "Режим фильтра",
        m_filter_all = "Все враги",
        m_filter_selected = "Только выбранные",
        m_filter_exclude = "Исключить выбранных",
        m_filter_heroes = "Фильтр героев",
        m_score_breakdown = "Разбор оценки",
        m_breakdown_settings = "Настройки разбора",
        m_breakdown_chip_count = "Количество чипов",
        -- Tooltips
        m_tt_enable = "Включить/выключить весь функционал скрипта",
        m_tt_panel = "Отображение информационной панели с рекомендациями предметов",
        m_tt_panel_key = "Открыть/закрыть панель по нажатию (Alt / Ctrl / любая клавиша)",
        m_tt_panel_mode = "Расширенный — полная информация. Минимальный — только предметы и против кого",
        m_tt_auto = "Автоматический анализ вражеского пика каждые 2 секунды",
        m_tt_max = "Максимальное количество предметов в списке предложений",
        m_tt_reasons = "Показывать причину рекомендации каждого предмета",
        m_tt_threats = "Показать теги угроз вражеского пика (silence, stun, burst...)",
        m_tt_track_enemy = "Отслеживать предметы вражеских героев для точности анализа",
        m_tt_counter_pick = "Рекомендации предметов на основе контр-пика героев",
        m_tt_networth = "Шкала сравнения нетворса команд",
        m_tt_focus_lines = "Детализированные строки фокуса на вражеских героев",
        m_tt_focus_rows = "Количество строк с вражескими героями для отображения",
        m_tt_neutrals = "Рекомендации нейтральных предметов текущего тира",
        m_tt_scale = "Масштаб всей панели: шрифт, отступы, размер. Увеличьте для 2K/4K мониторов",
        m_tt_opacity = "Прозрачность панели. 100% = полностью непрозрачная",
        m_tt_owned = "Подсвечивать предметы, которые уже куплены вами",
        m_tt_gold_header = "Отключите если значение золота отображается некорректно",
        m_tt_vis_mode = "Когда отображать панель на экране",
        m_tt_filter_mode = "Управление: анализировать всех врагов, только выбранных или исключить выбранных",
        m_tt_filter_list = "Иконки появятся после обнаружения вражеских героев",
        m_tt_category_badges = "Показывать MUST / SITUATIONAL / LUXURY на карточках предметов",
        m_tt_score_breakdown = "Компактные чипы с вкладом в общую оценку предмета",
        m_tt_breakdown_chips = "Сколько чипов оценки показывать на каждом предмете",
    },
    cn = {
        title           = "物品助手",
        enemies         = "敌人",
        threats         = "威胁",
        recommended     = "推荐",
        analyzing       = "正在分析敌方阵容...",
        no_enemies      = "未检测到敌人",
        owned           = "已购买",
        early           = "前期",
        mid             = "中期",
        late            = "后期",
        -- Game modes
        mode_unknown    = "未知",
        mode_allpick    = "全选",
        mode_ranked     = "天梯",
        mode_turbo      = "快速",
        mode_draft      = "征召",
        mode_random     = "随机",
        -- Tips
        tip_invis       = "!! 隐身较多 — 买粉/岗哨!",
        tip_magic       = "!! 魔法伤害高 — 笛子/BKB!",
        tip_heal        = "!! 大量回复 — 大勋章!",
        tip_phys        = "!! 物理伤害高 — 龙心/板甲!",
        tip_illusions   = "!! 幻象较多 — 电锤/战斧!",
        tip_disable     = "!! 大量控制 — BKB/莲花!",
        m_enable        = "启用助手",
        m_panel         = "显示面板",
        m_auto          = "自动分析",
        m_max           = "最大建议数",
        m_reasons       = "显示原因",
        m_threats       = "显示威胁分析",
        m_owned         = "高亮已买物品",
        m_scale         = "面板缩放 %",
        m_offx          = "X偏移",
        m_offy          = "Y偏移",
        m_opacity       = "透明度 %",
        m_side          = "面板位置",
        m_left          = "左",
        m_right         = "右",
        m_visibility    = "显示模式",
        m_vis_always    = "始终显示",
        m_vis_menu      = "仅作弊菜单",
        m_vis_shop      = "仅商店",
        m_vis_both      = "菜单或商店",
        m_show_gold     = "标题显示金钱",
        m_show_score_breakdown = "显示得分明细",
        m_show_category_badges = "显示分类徽章",
        m_breakdown_chips = "明细筹码",
        net_worth       = "总资产",
        hero_counters   = "英雄克制",
        enemy_focus     = "敌方重点",
        waiting_data    = "等待数据...",
        alive           = "存活",
        dead            = "死亡",
        gold_unknown    = "--",
        cat_must_have   = "必备",
        cat_situational = "情境",
        cat_luxury      = "奢侈",
        no_data         = "暂无推荐",
        -- Menu sections & options
        m_menu_settings = "设置",
        m_section_general = "常规",
        m_section_analysis = "分析",
        m_section_panel = "面板设置",
        m_section_filter = "敌方筛选",
        m_section_debug = "调试",
        m_panel_key = "面板按键",
        m_panel_mode = "面板模式",
        m_mode_extended = "扩展",
        m_mode_minimal = "最小",
        m_scale_panel = "面板缩放 %",
        m_track_enemy_items = "敌方物品追踪",
        m_counter_pick = "反选物品",
        m_networth_analysis = "净值分析",
        m_focus_lines = "焦点行",
        m_focus_rows = "焦点行数",
        m_focus_settings = "焦点设置",
        m_neutrals = "中立物品",
        m_highlight_owned = "高亮已购",
        m_gold_header = "标题显示金钱",
        m_show_panel_vis = "显示面板",
        m_filter_mode = "筛选模式",
        m_filter_all = "全部敌人",
        m_filter_selected = "仅已选",
        m_filter_exclude = "排除已选",
        m_filter_heroes = "英雄筛选",
        m_score_breakdown = "得分明细",
        m_breakdown_settings = "明细设置",
        m_breakdown_chip_count = "筹码数量",
        -- Tooltips (short)
        m_tt_enable = "启用或关闭脚本",
        m_tt_panel = "显示/隐藏推荐面板",
        m_tt_panel_key = "切换面板的按键",
        m_tt_panel_mode = "扩展：完整信息；最小：仅物品与目标",
        m_tt_auto = "每2秒分析敌方阵容",
        m_tt_max = "建议列表中最多显示物品数",
        m_tt_reasons = "显示每个物品的推荐原因",
        m_tt_threats = "显示敌方阵容威胁标签",
        m_tt_track_enemy = "追踪敌方英雄物品以提高分析准确性",
        m_tt_counter_pick = "基于英雄克制的物品推荐",
        m_tt_networth = "队伍净值对比条",
        m_tt_focus_lines = "每个敌方英雄的详细焦点行",
        m_tt_focus_rows = "显示的敌方英雄行数",
        m_tt_neutrals = "当前层级中立物品推荐",
        m_tt_scale = "面板缩放，2K/4K可增大",
        m_tt_opacity = "面板透明度",
        m_tt_owned = "高亮已拥有的物品",
        m_tt_gold_header = "金钱显示异常时可关闭",
        m_tt_vis_mode = "何时在屏幕上显示面板",
        m_tt_filter_mode = "分析全部/仅选中的/排除选中的敌人",
        m_tt_filter_list = "检测到敌方英雄后显示图标",
        m_tt_category_badges = "在物品卡上显示 MUST/SIT/LUX",
        m_tt_score_breakdown = "得分贡献的紧凑筹码",
        m_tt_breakdown_chips = "每物品显示的得分筹码数",
    },
}

-- Item reasons per language (key = item internal name)
local L_REASONS = {
    en = {
        item_magic_wand       = "Quick heal vs spell spam",
        item_bracer           = "HP and stats for early game",
        item_wraith_band      = "Stats for agi carries",
        item_null_talisman    = "Stats for int heroes",
        item_phase_boots      = "Armor + damage + speed",
        item_power_treads     = "Attack speed + stat switching",
        item_arcane_boots     = "Mana for the team",
        item_boots_of_bearing = "Attack + move speed aura for team",
        item_ghost            = "Protection from right-clicks",
        item_blade_mail       = "Damage reflection vs carries",
        item_vanguard         = "Damage block for melee heroes",
        item_crimson_guard    = "Team phys damage protection",
        item_assault          = "Armor aura + enemy armor reduction",
        item_shivas_guard     = "Armor + slow vs phys DPS",
        item_heavens_halberd  = "Disarm vs right-clickers",
        item_solar_crest      = "Buff ally / debuff enemy armor",
        item_pipe             = "Team magic barrier",
        item_glimmer_cape     = "Save ally + magic resistance",
        item_black_king_bar   = "Magic immunity — must have vs CC",
        item_spirit_vessel    = "45% heal reduction",
        item_monkey_king_bar  = "True Strike vs evasion",
        item_dust             = "Reveal invisible heroes",
        item_ward_sentry      = "Sentry ward for invis control",
        item_mjollnir         = "Lightning vs illusions/summons",
        item_battlefury       = "Cleave clears illusions + farm",
        item_radiance          = "Burn aura + miss vs illusions",
        item_maelstrom        = "Chain lightning vs unit clusters",
        item_blink            = "Mobility and initiation",
        item_force_staff      = "Escape from slows / reposition",
        item_hurricane_pike   = "Distance from melee + push away",
        item_lotus_orb        = "Dispel + reflect targeted spells",
        item_manta            = "Dispel + illusions for push/fight",
        item_sphere           = "Blocks one targeted spell",
        item_aeon_disk        = "Protection from instant kill",
        item_desolator        = "Armor reduction for phys damage",
        item_daedalus         = "Critical strike for late game",
        item_butterfly        = "Evasion + attack speed for agi carries",
        item_satanic          = "Lifesteal + active heal in fights",
        item_skadi            = "Slow + stats + heal reduction",
        item_abyssal_blade    = "Pierces BKB + bash",
        item_nullifier        = "Purge enemy buffs (Ghost, Glimmer)",
        item_bloodthorn       = "Silence + True Strike + crit",
        item_rod_of_atos      = "Root vs mobile heroes",
        item_orchid           = "Silence vs casters",
        item_sheepstick       = "Hex — strongest disable",
        item_scythe_of_vyse   = "Hex — strongest disable",
        item_ethereal_blade   = "Disarm + magic damage amp",
        item_refresher        = "Double ultimate in fights",
        item_heart            = "Huge HP pool for late game",
        item_overwhelming_blink = "Blink with AoE damage + slow",
        item_swift_blink      = "Blink with agility bonus",
        item_arcane_blink     = "Blink with cooldown reduction",
        item_mekansm          = "Team heal",
        item_guardian_greaves  = "Greaves: aura + dispel + heal",
        item_silver_edge      = "Break disables passives (Bristle, PA)",
        item_gungir           = "AoE root + lightning vs mobile/illusions",
        item_gungungir        = "AoE root + lightning vs mobile/illusions",
        item_harpoon          = "Pull to enemy for initiation",
        item_disperser        = "Strong self-dispel + enemy slow",
        item_witch_blade      = "Attack damage + slow for int heroes",
        item_pavise           = "Physical shield on ally",
        item_ultimate_scepter = "Hero ability upgrade",
        item_aghanims_shard   = "New ability or improvement",
        item_invis_sword      = "Invis for initiation + damage",
        item_veil_of_discord  = "Amplify team magic damage in area",
        item_kaya_and_sange   = "HP + spell amp for caster carries",
        item_sange_and_yasha  = "Stats + speed for agi/str carries",
        item_yasha_and_kaya   = "Speed + spell amp for hybrids",
        item_diffusal_blade   = "Mana burn + slow",
        item_bloodstone       = "Huge mana pool + spell lifesteal",
        item_cyclone          = "Self-dispel + interrupt channels",
        item_dagon            = "Magic nuke for finishing",
        item_octarine_core    = "25% CDR for casters",
        item_wind_waker       = "Save ally (Tornado + dispel)",
        item_travel_boots     = "TP to creeps for split-push",
        item_phylactery       = "Spell amp + HP for casters",
        item_holy_locket      = "Amplify healing + charges",
        item_hand_of_midas    = "Gold + XP acceleration",
        item_tiara_of_selemene = "Large mana regen for Scythe/Refresher",
        item_splintmail       = "Armor + HP for mid-game builds",
        item_shawl            = "Magic resist for Pipe/Glimmer",
        item_angels_demise    = "Major spell burst + HP/Mana",
        item_chasm_stone      = "AOE bonus for abilities (Gleipnir/Shivas)",
        item_consecrated_wraps = "Self-shield on spell damage",
        item_crellas_crozier   = "Ethereal + stat steal for casters",
        item_essence_distiller = "Aggressive Urn upgrade with stats",
    },
    ru = {
        item_magic_wand       = "Быстрый хил vs спама заклинаний",
        item_bracer           = "HP и статы на ранней стадии",
        item_wraith_band      = "Статы для agi-керри",
        item_null_talisman    = "Статы для int-героев",
        item_phase_boots      = "Броня + урон + скорость",
        item_power_treads     = "Атака + переключение статов",
        item_arcane_boots     = "Мана для команды",
        item_boots_of_bearing = "Аура скорости для команды",
        item_ghost            = "Защита от правой кнопки",
        item_blade_mail       = "Отражение урона vs керри",
        item_vanguard         = "Блок урона для ближнего боя",
        item_crimson_guard    = "Командная защита от физ. урона",
        item_assault          = "Аура брони + снижение вражеской",
        item_shivas_guard     = "Броня + замедление vs физ. ДПС",
        item_heavens_halberd  = "Разоружение vs правокликеров",
        item_solar_crest      = "Бафф союзника / дебафф брони",
        item_pipe             = "Командный щит от магии",
        item_glimmer_cape     = "Спасение союзника + маг. резист",
        item_black_king_bar   = "Иммунитет к магии — must have vs контроля",
        item_spirit_vessel    = "Снижение хила на 45%",
        item_monkey_king_bar  = "True Strike vs уклонения",
        item_dust             = "Обнаружение невидимых героев",
        item_ward_sentry      = "Сентри для контроля инвизов",
        item_mjollnir         = "Молния vs иллюзий/призывов",
        item_battlefury       = "Клив vs иллюзий + фарм",
        item_radiance          = "Аура урона + промах vs иллюзий",
        item_maelstrom        = "Молния vs скоплений юнитов",
        item_blink            = "Мобильность и инициация",
        item_force_staff      = "Спасение от слоу / позиционирование",
        item_hurricane_pike   = "Дистанция от ближников",
        item_lotus_orb        = "Диспел + отражение заклинаний",
        item_manta            = "Диспел + иллюзии для push/fight",
        item_sphere           = "Блок одного targeted заклинания",
        item_aeon_disk        = "Защита от моментального убийства",
        item_desolator        = "Снижение брони для физ. урона",
        item_daedalus         = "Критический урон для поздней",
        item_butterfly        = "Уклонение + скорость атаки",
        item_satanic          = "Вампиризм + активный хил",
        item_skadi            = "Замедление + статы + снижение хила",
        item_abyssal_blade    = "Пробивает BKB + bash",
        item_nullifier        = "Снимает баффы (Ghost, Glimmer, Aeon)",
        item_bloodthorn       = "Молчание + True Strike + крит",
        item_rod_of_atos      = "Рут vs мобильных героев",
        item_orchid           = "Молчание vs кастеров",
        item_sheepstick       = "Хекс — сильнейший дизейбл",
        item_scythe_of_vyse   = "Хекс — сильнейший дизейбл",
        item_ethereal_blade   = "Обезоружение + маг. усиление",
        item_refresher        = "Двойной ультимейт в драке",
        item_heart            = "Огромный запас HP для лейта",
        item_overwhelming_blink = "Блинк с AoE уроном + замедлением",
        item_swift_blink      = "Блинк с бонусом ловкости",
        item_arcane_blink     = "Блинк с уменьшением КД",
        item_mekansm          = "Командный хил",
        item_guardian_greaves  = "Грейвзы: аура + диспел + хил",
        item_silver_edge      = "Break отключает пассивки (Bristle, PA)",
        item_gungir           = "AoE рут + молнии vs иллюзий",
        item_gungungir        = "AoE рут + молнии vs иллюзий",
        item_harpoon          = "Притягивание к врагу",
        item_disperser        = "Сильный диспел + замедление врагов",
        item_witch_blade      = "Урон + замедление для int-героев",
        item_pavise           = "Физический щит на союзника",
        item_ultimate_scepter = "Улучшение способностей героя",
        item_aghanims_shard   = "Новая способность или улучшение",
        item_invis_sword      = "Невидимость + урон для инициации",
        item_veil_of_discord  = "Усиление маг. урона в области",
        item_kaya_and_sange   = "HP + усиление заклинаний",
        item_sange_and_yasha  = "Статы + скорость для керри",
        item_yasha_and_kaya   = "Скорость + маг. усиление",
        item_diffusal_blade   = "Сжигание маны + замедление",
        item_bloodstone       = "Огромная мана + вампиризм заклинаний",
        item_cyclone          = "Диспел на себя + прерывание каналов",
        item_dagon            = "Магический нюк для добивания",
        item_octarine_core    = "Сокращение КД на 25% для кастеров",
        item_wind_waker       = "Сейв союзника (Торнадо + диспел)",
        item_travel_boots     = "ТП на крипов для сплит-пуша",
        item_phylactery       = "Усиление заклинаний + HP",
        item_holy_locket      = "Усиление хила + заряды",
        item_hand_of_midas    = "Ускорение золота и опыта",
        item_tiara_of_selemene = "Реген маны для Хекса/Рефрешера",
        item_splintmail       = "Броня + HP для мид-гейм сборок",
        item_shawl            = "Маг. резист для Пайпа/Глиммера",
        item_angels_demise    = "Мощный маг. урон + HP/Мана",
        item_chasm_stone      = "Бонус к AoE (Глейпнир/Шива)",
        item_consecrated_wraps = "Щит при получении маг. урона",
        item_crellas_crozier   = "Этериал + кража статов",
        item_essence_distiller = "Агрессивный апгрейд Урны",
    },
    cn = {
        item_magic_wand       = "对付技能骚扰的快速回复",
        item_bracer           = "前期生命值和属性",
        item_wraith_band      = "敏捷核心属性",
        item_null_talisman    = "智力英雄属性",
        item_phase_boots      = "护甲+攻击+速度",
        item_power_treads     = "攻速+属性切换",
        item_arcane_boots     = "团队法力值",
        item_boots_of_bearing = "团队攻速移速光环",
        item_ghost            = "防物理攻击",
        item_blade_mail       = "反弹伤害对抗核心",
        item_vanguard         = "近战伤害格挡",
        item_crimson_guard    = "团队物理防护",
        item_assault          = "护甲光环+降低敌方护甲",
        item_shivas_guard     = "护甲+减速对抗物理",
        item_heavens_halberd  = "缴械对抗右键英雄",
        item_solar_crest      = "增益友军/减甲敌人",
        item_pipe             = "团队魔法护盾",
        item_glimmer_cape     = "保护队友+魔抗",
        item_black_king_bar   = "魔法免疫 — 对抗控制必备",
        item_spirit_vessel    = "降低治疗45%",
        item_monkey_king_bar  = "真实打击对抗闪避",
        item_dust             = "显示隐身英雄",
        item_ward_sentry      = "岗哨守卫控制隐身",
        item_mjollnir         = "闪电对抗幻象/召唤物",
        item_battlefury       = "分裂清除幻象+打钱",
        item_radiance          = "灼烧光环+对抗幻象",
        item_maelstrom        = "闪电链对抗单位群",
        item_blink            = "机动性和先手",
        item_force_staff      = "逃脱减速/调整位置",
        item_hurricane_pike   = "拉开近战距离",
        item_lotus_orb        = "驱散+反射指向技能",
        item_manta            = "驱散+幻象推进/团战",
        item_sphere           = "格挡一个指向技能",
        item_aeon_disk        = "防止瞬间击杀",
        item_desolator        = "降甲增加物理伤害",
        item_daedalus         = "后期暴击伤害",
        item_butterfly        = "闪避+攻速",
        item_satanic          = "吸血+主动回复",
        item_skadi            = "减速+属性+降低回复",
        item_abyssal_blade    = "穿刺BKB+眩晕",
        item_nullifier        = "清除敌方增益效果",
        item_bloodthorn       = "沉默+真实打击+暴击",
        item_rod_of_atos      = "束缚对抗机动英雄",
        item_orchid           = "沉默对抗法师",
        item_scythe_of_vyse   = "变羊 — 最强控制",
        item_ethereal_blade   = "缴械+魔法增幅",
        item_refresher        = "团战双大招",
        item_heart            = "后期大量生命值",
        item_overwhelming_blink = "闪烁+范围伤害减速",
        item_swift_blink      = "闪烁+敏捷加成",
        item_arcane_blink     = "闪烁+冷却缩减",
        item_mekansm          = "团队治疗",
        item_guardian_greaves  = "卫士胫甲: 光环+驱散+治疗",
        item_silver_edge      = "破隐+破除被动技能",
        item_gungungir        = "范围束缚+闪电",
        item_harpoon          = "拉向敌人先手",
        item_disperser        = "强驱散+减速敌人",
        item_witch_blade      = "智力英雄攻击减速",
        item_pavise           = "物理护盾保护队友",
        item_ultimate_scepter = "英雄技能升级",
        item_aghanims_shard   = "新技能或增强",
        item_invis_sword      = "隐身先手+伤害",
        item_veil_of_discord  = "增幅区域魔法伤害",
        item_kaya_and_sange   = "生命+技能增幅",
        item_sange_and_yasha  = "属性+速度",
        item_yasha_and_kaya   = "速度+技能增幅",
        item_diffusal_blade   = "燃烧法力+减速",
        item_bloodstone       = "大量法力+技能吸血",
        item_cyclone          = "自我驱散+打断施法",
        item_dagon            = "魔法爆发收割",
        item_octarine_core    = "法师25%冷却缩减",
        item_wind_waker       = "保护队友(龙卷风+驱散)",
        item_travel_boots     = "传送到小兵分推",
        item_phylactery       = "技能增幅+生命值",
        item_holy_locket      = "增强治疗效果+充能",
        item_hand_of_midas    = "加速金币和经验",
        item_tiara_of_selemene = "用于刷新/羊刀的大量回蓝",
        item_splintmail       = "中期护甲和生命值组件",
        item_shawl            = "微光/笛子的前期魔抗",
        item_angels_demise    = "强力法术爆发+HP/MP",
        item_chasm_stone      = "增加技能范围 (大电锤/希瓦)",
        item_consecrated_wraps = "受魔伤时获得护盾",
        item_crellas_crozier   = "虚灵+偷取属性",
        item_essence_distiller = "攻击性骨灰盒升级",
    },
}

-- Neutral item reasons per language (Updated 2026)
local L_NEUTRAL_REASONS = {
    en = {
        -- Tier 1
        item_occult_bracelet    = "Mana + INT for spell casters",
        item_kobold_cup         = "Movespeed + gold acceleration",
        item_chipped_vest       = "Reflect vs physical damage",
        item_polliwog_charm     = "Healing + mana sustain",
        item_dormant_curio      = "Stats + item effectiveness",
        item_duelist_gloves     = "Attack speed + AGI for carries",
        item_weighted_dice      = "Crit chance + luck bonus",
        item_ash_legion_shield  = "Block + slow vs physical",
        item_dagger_of_ristul   = "Physical damage bonus (HP cost)",
        item_stonefeather_satchel= "Stats + movement speed",
        item_possessed_mask     = "Lifesteal for sustain",
        item_foragers_kit       = "Consumables from trees",
        -- Tier 2
        item_essence_ring       = "Active HP gain + mana sustain",
        item_mana_draught       = "Mana sustain for spellcasters",
        item_poor_mans_shield   = "Block vs early right-clicks",
        item_searing_signet     = "Burn + magic damage amp",
        item_pogo_stick         = "Mobility + jumps for initiation",
        item_defiant_shell      = "Armor + counter-attack",
        item_crippling_crossbow = "Slow + armor reduction on hit",
        item_medallion_of_courage= "Targeted armor reduction",
        item_seeds_of_serenity   = "Active AoE health regen",
        -- Tier 3
        item_serrated_shiv      = "Armor reduction + bleed on hit",
        item_gunpowder_gauntlets= "AOE burst damage + speed",
        item_jidi_pollen_bag    = "Aoe health regen reduction",
        item_psychic_headband   = "INT + mana + cast range CDR",
        item_unrelenting_eye    = "Vision + true strike bonus",
        item_cloak_of_flames    = "Burn aura + armor protection",
        item_spellslinger       = "Mana restore + sustain",
        item_stormcrafter       = "Magic burst sparks + mobility",
        item_partisans_brand    = "Mana burn + damage scaling",
        -- Tier 4
        item_giant_maul         = "Crit + stun for strength heroes",
        item_rattlecage         = "Armor + reflect + fear proc",
        item_idol_of_screeauk   = "Evasion + slow resistance save",
        item_flayers_bota       = "Burst mobility + attack speed",
        item_metamorphic_mandible= "Magic resist + movespeed",
        item_dandelion_amulet   = "Flat magic damage block",
        item_enchanters_bauble  = "Spell range + magic amp",
        item_prophets_pendulum  = "Status resist + movement speed",
        item_conjurers_catalyst = "CDR + status and spell amp",
        -- Tier 5
        item_desolator_2        = "Massive armor reduction",
        item_fallen_sky         = "Global initiation + stun",
        item_demonicon          = "Strong summons for push",
        item_minotaur_horn      = "HP + spell immunity active",
        item_spider_legs        = "Free pathing + mobility",
        item_riftshadow_prism   = "Magic amp + CDR + stats",
        item_dezun_bloodrite    = "Heal + magic burst + burst save",
        item_divine_regalia     = "Large stats + protect active",
        item_harmonizer         = "Stat copying + lower mana cost",
        item_heavy_blade        = "Armor + damage + slow",
    },
    ru = {
        -- Tier 1
        item_occult_bracelet    = "Мана + INT для кастеров",
        item_kobold_cup         = "Скорость + ускорение фарма",
        item_chipped_vest       = "Отражение физ. урона",
        item_polliwog_charm     = "Хил + мана сустейн",
        item_dormant_curio      = "Статы + усиление предметов",
        item_duelist_gloves     = "Атака + AGI для керри",
        item_weighted_dice      = "Шанс крита + удача",
        item_ash_legion_shield  = "Блок + замедление врага",
        item_dagger_of_ristul   = "Урон ценою здоровья",
        item_stonefeather_satchel= "Статы + скорость бега",
        item_possessed_mask     = "Вампиризм для фарма",
        item_foragers_kit       = "Расходники из деревьев",
        -- Tier 2
        item_essence_ring       = "Прирост HP + мана сустейн",
        item_mana_draught       = "Мана сустейн для кастеров",
        item_poor_mans_shield   = "Блок vs ранней агрессии",
        item_searing_signet     = "Горение + усиление магии",
        item_pogo_stick         = "Мобильность + прыжок",
        item_defiant_shell      = "Броня + ответный удар",
        item_crippling_crossbow = "Замедление + минус броня",
        item_medallion_of_courage= "Снижение брони таргетно",
        item_seeds_of_serenity   = "Активный АоЕ реген здоровья",
        -- Tier 3
        item_serrated_shiv      = "Минус броня + кровотечение",
        item_gunpowder_gauntlets= "АоЕ бёрст + скорость атаки",
        item_jidi_pollen_bag    = "Срезает вражеский реген",
        item_psychic_headband   = "INT + мана + дальность",
        item_unrelenting_eye    = "Видение + верный удар",
        item_cloak_of_flames    = "Аура урона + броня",
        item_spellslinger       = "Реген маны + сустейн",
        item_stormcrafter       = "Маг. искры + мобильность",
        item_partisans_brand    = "Сжигание маны + урон",
        -- Tier 4
        item_giant_maul         = "Крит + оглушение (для силы)",
        item_rattlecage         = "Броня + отражение + страх",
        item_idol_of_screeauk   = "Уклонение + сопр. замедлению",
        item_flayers_bota       = "Блинк + скорость атаки",
        item_metamorphic_mandible= "Маг. резист + скорость",
        item_dandelion_amulet   = "Блок магического урона",
        item_enchanters_bauble  = "Дальность + усиление магии",
        item_prophets_pendulum  = "Сопр. эффектам + скорость",
        item_conjurers_catalyst = "КД + усиление заклинаний",
        -- Tier 5
        item_desolator_2        = "Огромное снижение брони",
        item_fallen_sky         = "Глобальная инициация + стан",
        item_demonicon          = "Сильные саммоны для пуша",
        item_minotaur_horn      = "HP + БКБ на минималках",
        item_spider_legs        = "Хождение сквозь препятствия",
        item_riftshadow_prism   = "Маг. усиление + КД + статы",
        item_dezun_bloodrite    = "Хил + маг. бёрст + сейв",
        item_divine_regalia     = "Большие статы + защита",
        item_harmonizer         = "Копирование статов + мана",
        item_heavy_blade        = "Броня + урон + замедление",
    },
    cn = {
        -- Tier 1
        item_occult_bracelet    = "智力英雄的法力回复",
        item_kobold_cup         = "移动速度+金币获取",
        item_chipped_vest       = "反弹物理伤害",
        item_polliwog_charm     = "生命+法力续航",
        item_dormant_curio      = "属性+物品增强",
        item_duelist_gloves     = "攻速+敏捷核心续航",
        item_weighted_dice      = "暴击率+幸运加成",
        item_ash_legion_shield  = "格挡+物理减速",
        item_dagger_of_ristul   = "血量换攻击",
        item_stonefeather_satchel= "属性及移速",
        item_possessed_mask     = "吸血续航",
        item_foragers_kit       = "通过树木获得补给",
        -- Tier 2
        item_essence_ring       = "增加生命+法力续航",
        item_mana_draught       = "法师法力续航",
        item_poor_mans_shield   = "前期格挡物理攻击",
        item_searing_signet     = "灼烧+魔法增幅",
        item_pogo_stick         = "机动性+跳跃先手",
        item_defiant_shell      = "护甲+反击被动",
        item_crippling_crossbow = "减速+降甲",
        item_medallion_of_courage= "指向性降低护甲",
        item_seeds_of_serenity   = "范围内生命恢复",
        -- Tier 3
        item_serrated_shiv      = "降甲+流血效果",
        item_gunpowder_gauntlets= "范围爆发伤害+攻速",
        item_jidi_pollen_bag    = "降低敌方生命回复",
        item_psychic_headband   = "智力+法力+施法距离",
        item_unrelenting_eye    = "视野+真实打击",
        item_cloak_of_flames    = "灼烧光环+护甲护罩",
        item_spellslinger       = "法力恢复+续航",
        item_stormcrafter       = "法术爆发+机动性",
        item_partisans_brand    = "法力燃烧+伤害成长",
        -- Tier 4
        item_giant_maul         = "力量英雄暴击+眩晕",
        item_rattlecage         = "护甲+反弹+恐惧控场",
        item_idol_of_screeauk   = "闪避+减速抗性主动",
        item_flayers_bota       = "爆发位移+攻速",
        item_metamorphic_mandible= "魔抗+移速主动",
        item_dandelion_amulet   = "固定格挡魔法伤害",
        item_enchanters_bauble  = "施法距离增加+魔法增幅",
        item_prophets_pendulum  = "状态抗性+移速",
        item_conjurers_catalyst = "冷却缩减+状态增幅",
        -- Tier 5
        item_desolator_2        = "大量物理降甲",
        item_fallen_sky         = "全球先手+眩晕",
        item_demonicon          = "强力召唤物推进",
        item_minotaur_horn      = "生命值+主动魔免",
        item_spider_legs        = "跨越地形机动性",
        item_riftshadow_prism   = "魔法增幅+冷却+属性",
        item_dezun_bloodrite    = "治疗+魔法爆发+保命",
        item_divine_regalia     = "大量属性+主动防护",
        item_harmonizer         = "属性模仿+减少蓝耗",
        item_heavy_blade        = "护甲+伤害+减速",
    },
}

local function updateLang()
    local now = 0
    pcall(function() now = GameRules.GetGameTime() end)
    if now - _langLastCheck < 2.0 then return end
    _langLastCheck = now

    if not _langWidget then
        local ok, w = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Language")
        if ok and w then _langWidget = w end
    end

    if _langWidget then
        local ok, v = pcall(function() return _langWidget:Get() end)
        if ok and v ~= nil then
            if v == 1 then LANG = "ru"
            elseif v == 2 then LANG = "cn"
            else LANG = "en" end
        end
    end
end

local L_UI_OVERRIDES = {
    en = {
        analyzing = "Scanning enemy draft...",
        no_enemies = "No enemies yet (demo/lobby: spawn bots to test)",
        waiting_data = "No data yet...",
        test_tryhero = "TRY HERO",
        test_lobby = "LOBBY",
        test_custom = "CUSTOM",
    },
    ru = {
        analyzing = "Сканю вражеский пик...",
        no_enemies = "Пока пусто (в демке/лобби заспавни ботов)",
        waiting_data = "Данных пока нет...",
        test_tryhero = "ОПРОБОВАТЬ",
        test_lobby = "ЛОББИ",
        test_custom = "КАСТОМ",
    },
    cn = {
        analyzing = "在看对面阵容...",
        no_enemies = "还没敌人（测试可在试玩/房间里生机器人）",
        waiting_data = "还没拿到数据...",
        test_tryhero = "试玩英雄",
        test_lobby = "房间",
        test_custom = "自定义",
    },
}

-- Breakdown chip labels (used by breakdownKeyLabel) — EN / RU / CN
local L_BREAKDOWN_LABELS = {
    en = {
        counter_rules   = "counter rules",
        hero_counter    = "hero counter",
        affordable      = "affordable",
        role_penalty    = "role penalty",
        style_bonus     = "hero style",
        tempo           = "tempo",
        mode_adjust     = "mode",
        phase_mult      = "phase",
        phase_fit       = "phase fit",
        team_need       = "team need",
        hero_specific   = "hero fit",
        function_overlap = "function overlap",
        ["enemy_item:bkb"]       = "vs BKB",
        ["enemy_item:linkens"]   = "vs Linken",
        ["enemy_item:aeon"]      = "vs Aeon",
        ["enemy_item:ghost"]     = "vs Ghost",
        ["enemy_item:glimmer"]   = "vs Glimmer",
        ["enemy_item:blademail"] = "vs BM",
    },
    ru = {
        counter_rules   = "контр-правила",
        affordable      = "по карману",
        role_penalty    = "штраф роли",
        style_bonus     = "стиль героя",
        tempo           = "темп",
        mode_adjust     = "режим",
        phase_mult      = "фаза",
        hero_specific   = "под героя",
        ["enemy_item:bkb"]       = "vs BKB",
        ["enemy_item:linkens"]   = "vs Линка",
        ["enemy_item:aeon"]      = "vs Аеон",
        ["enemy_item:ghost"]     = "vs Гост",
        ["enemy_item:glimmer"]   = "vs Глиммер",
        ["enemy_item:blademail"] = "vs БМ",
    },
    cn = {
        counter_rules   = "克制规则",
        affordable      = "买得起",
        role_penalty    = "定位惩罚",
        style_bonus     = "英雄风格",
        tempo           = "节奏",
        mode_adjust     = "模式",
        phase_mult      = "阶段",
        hero_specific   = "契合英雄",
        ["enemy_item:bkb"]       = "vs BKB",
        ["enemy_item:linkens"]   = "vs 林肯",
        ["enemy_item:aeon"]      = "vs 永恒",
        ["enemy_item:ghost"]     = "vs 绿杖",
        ["enemy_item:glimmer"]   = "vs 微光",
        ["enemy_item:blademail"] = "vs 刃甲",
    },
}

local L_REASON_SLANG = {
    en = {
        item_ghost = "Panic button vs right-click focus",
        item_cyclone = "Eul: self-dispel / setup / cancel channels",
        item_black_king_bar = "BKB so you can actually hit/cast",
        item_force_staff = "Force: save / reposition / break slows",
        item_glimmer_cape = "Glimmer save: magic resist + fade out",
        item_heavens_halberd = "Halberd shuts down right-click cores",
        item_spirit_vessel = "Vessel hard-cuts heal and regen",
        item_lotus_orb = "Lotus: self-dispel + bounce target spells",
        item_pipe = "Pipe vs heavy magic spam",
        item_hurricane_pike = "Pike for spacing vs melee jumpers",
        item_sphere = "Linken vs single-target catch",
        item_aeon_disk = "Aeon stops getting bursted 100-0",
        item_nullifier = "Nullifier removes save items (Ghost/Glimmer/Aeon)",
        item_orchid = "Orchid to shut up caster cores",
        item_rod_of_atos = "Atos root for mobile heroes",
        item_sheepstick = "Hex = best late hard catch",
        item_scythe_of_vyse = "Hex = best late hard catch",
        item_dust = "Dust if they keep juking in invis",
        item_ward_sentry = "Sentries for invis vision + deward",
        item_manta = "Manta to purge stuff and split lanes",
        item_blink = "Blink for jump/start or disengage",
        item_blade_mail = "Blademail punishes commit and burst",
        item_wind_waker = "Wind Waker save / reset / drag fight",
    },
    ru = {
        item_ghost = "Сэйв от райтклик фокуса",
        item_cyclone = "Еул: диспел с себя / сетап / сбить чейнел",
        item_black_king_bar = "BKB, чтобы тебя не держали и ты бил/кастил",
        item_force_staff = "Форс: сейв / репозишн / сбить слоу",
        item_glimmer_cape = "Глиммер: сейв, магрез и уйти в инвиз",
        item_heavens_halberd = "Алебарда выключает райтклик кора",
        item_spirit_vessel = "Вессел режет хил/реген очень сильно",
        item_lotus_orb = "Лотус: диспел с себя + вернуть таргет-спелл",
        item_pipe = "Пайп против магического спама/прокаста",
        item_hurricane_pike = "Пика для кайта милишников и прыгающих",
        item_sphere = "Линка против таргетного контроля",
        item_aeon_disk = "Аеон чтобы не лопаться за прокаст",
        item_nullifier = "Нуллик снимает сейвы (Ghost/Glimmer/Aeon)",
        item_orchid = "Орчид чтобы заткнуть кастера/мидера",
        item_rod_of_atos = "Атос: прибить мобильного героя",
        item_sheepstick = "Хекс — самый надёжный лейт-контроль",
        item_scythe_of_vyse = "Хекс — самый надёжный лейт-контроль",
        item_dust = "Даст, если они вечно уходят в инвиз",
        item_ward_sentry = "Сентри: вижен по инвизу + девард",
        item_manta = "Мантуха: снять гадость и сплитить",
        item_blink = "Блинк на врыв / инициацию / выход",
        item_blade_mail = "БМ наказывает за врыв и прокаст",
        item_wind_waker = "Виндвейкер: сейв / ресет / потянуть время",
    },
    cn = {
        item_ghost = "Ghost保命，顶住物理右键集火",
        item_cyclone = "吹风：给自己解状态 / 先手接控 / 打断读条",
        item_black_king_bar = "BKB开了才能站着打和放技能",
        item_force_staff = "推推保命/拉扯/断减速",
        item_glimmer_cape = "微光保人，魔抗+隐身拉扯",
        item_heavens_halberd = "天堂直接废右键大哥",
        item_spirit_vessel = "大骨灰狠砍回复和吸血",
        item_lotus_orb = "莲花：解状态，还能弹回单体技能",
        item_pipe = "笛子顶法系爆发和消耗",
        item_hurricane_pike = "大推推拉开身位打近战跳脸",
        item_sphere = "林肯防单点先手",
        item_aeon_disk = "永恒盘防被一套秒",
        item_nullifier = "否决拆救人装（Ghost/微光/Aeon）",
        item_orchid = "紫苑先手封嘴法核",
        item_rod_of_atos = "阿托斯拴住会跑的英雄",
        item_sheepstick = "羊刀=后期最稳硬控",
        item_scythe_of_vyse = "羊刀=后期最稳硬控",
        item_dust = "粉别省，对面老隐身就安排",
        item_ward_sentry = "真眼控隐身顺手反眼",
        item_manta = "分身斧解状态+带线拉扯",
        item_blink = "跳刀开团/先手/拉开都好用",
        item_blade_mail = "刃甲反打，谁冲你谁难受",
        item_wind_waker = "风杖鞋保人/拖时间/重置团战",
    },
}

local function L(key)
    local tbl = L_STRINGS[LANG] or L_STRINGS.en
    local ov = (L_UI_OVERRIDES[LANG] and L_UI_OVERRIDES[LANG][key])
        or (L_UI_OVERRIDES.en and L_UI_OVERRIDES.en[key])
    return ov or tbl[key] or L_STRINGS.en[key] or key
end

local function LR(itemName)
    local rawName = itemName
    local canonicalName = rawName
    if rawName then
        canonicalName = ({
            item_aghanims_scepter = "item_ultimate_scepter",
            item_ether_sword = "item_ethereal_blade",
            item_vladmirs_offering = "item_vladmir",
            item_shadow_blade = "item_invis_sword",
            item_orchid_malevolence = "item_orchid",
            item_linkens = "item_sphere",
            item_euls = "item_cyclone",
            item_medallion = "item_medallion_of_courage",
            item_urnd = "item_spirit_vessel",
            item_gleipnir = "item_gungir",
            item_glimmer = "item_glimmer_cape",
            item_refresher_orb = "item_refresher",
            item_scythe_of_vyse = "item_sheepstick",
            item_bfury = "item_battlefury",
            item_greater_crit = "item_daedalus",
        })[rawName] or rawName
    end

    local slangTbl = L_REASON_SLANG[LANG] or L_REASON_SLANG.en
    local slang = (slangTbl and (slangTbl[canonicalName] or slangTbl[rawName]))
        or (L_REASON_SLANG.en and (L_REASON_SLANG.en[canonicalName] or L_REASON_SLANG.en[rawName]))
    if slang and slang ~= "" then return slang end
    local tbl = L_REASONS[LANG] or L_REASONS.en
    local reason = tbl[canonicalName] or tbl[rawName] or L_REASONS.en[canonicalName] or L_REASONS.en[rawName] or ""
    if reason ~= "" then return reason end
    -- Fallback to neutral item reasons
    local neutralTbl = L_NEUTRAL_REASONS[LANG] or L_NEUTRAL_REASONS.en
    return neutralTbl[canonicalName] or neutralTbl[rawName]
        or L_NEUTRAL_REASONS.en[canonicalName] or L_NEUTRAL_REASONS.en[rawName] or ""
end

local ITEM_NAME_ALIASES = {
    item_aghanims_scepter = "item_ultimate_scepter",
    item_ether_sword = "item_ethereal_blade",
    item_vladmirs_offering = "item_vladmir",
    item_shadow_blade = "item_invis_sword",
    item_orchid_malevolence = "item_orchid",
    item_linkens = "item_sphere",
    item_euls = "item_cyclone",
    item_medallion = "item_medallion_of_courage",
    item_urnd = "item_spirit_vessel",
    item_gleipnir = "item_gungir",
    item_glimmer = "item_glimmer_cape",
    item_refresher_orb = "item_refresher",
    item_scythe_of_vyse = "item_sheepstick",
    item_bfury = "item_battlefury",
    item_greater_crit = "item_daedalus",
}

local function canonItemName(itemName)
    if not itemName then return itemName end
    return ITEM_NAME_ALIASES[itemName] or itemName
end

local ITEM_ENGINE_NAME_ALIASES = {
    item_battlefury = "item_bfury",
    item_daedalus = "item_greater_crit",
}

local function engineItemName(itemName)
    local canonical = canonItemName(itemName)
    return ITEM_ENGINE_NAME_ALIASES[canonical] or ITEM_ENGINE_NAME_ALIASES[itemName] or canonical or itemName
end

--------------------------------------------------------------------------------
-- HERO THREAT TAGS
--------------------------------------------------------------------------------
local HERO_TAGS = {
    -- ══════════════ Carry / Physical DPS ══════════════
    npc_dota_hero_antimage           = {"carry","magic_resist","mobility","mana_burn"},
    npc_dota_hero_phantom_assassin   = {"carry","phys_burst","crit","evasion"},
    npc_dota_hero_juggernaut         = {"carry","phys_dps","magic_immune","heal"},
    npc_dota_hero_faceless_void      = {"carry","chrono","phys_dps","evasion","mobility"},
    npc_dota_hero_terrorblade        = {"carry","phys_dps","illusions","push"},
    npc_dota_hero_spectre            = {"carry","global","phys_dps","tanky"},
    npc_dota_hero_phantom_lancer     = {"carry","illusions","phys_dps","mana_burn"},
    npc_dota_hero_medusa             = {"carry","phys_dps","tanky","split_shot"},
    npc_dota_hero_troll_warlord      = {"carry","phys_dps","bash","attack_speed"},
    npc_dota_hero_ursa               = {"carry","phys_burst","tanky"},
    npc_dota_hero_sven               = {"carry","phys_burst","stun","cleave"},
    npc_dota_hero_life_stealer       = {"carry","phys_dps","magic_immune","heal","slow"},
    npc_dota_hero_slark              = {"carry","phys_dps","purge","invis","mobility"},
    npc_dota_hero_monkey_king        = {"carry","phys_burst","stun","mobility"},
    npc_dota_hero_chaos_knight       = {"carry","phys_burst","illusions","stun"},
    npc_dota_hero_luna               = {"carry","phys_dps","push","magic_burst"},
    npc_dota_hero_drow_ranger        = {"carry","phys_dps","slow","ranged"},
    npc_dota_hero_morphling          = {"carry","phys_burst","magic_burst","mobility"},
    npc_dota_hero_naga_siren         = {"carry","illusions","push","disable"},
    npc_dota_hero_weaver             = {"carry","phys_dps","invis","mobility"},
    npc_dota_hero_riki               = {"carry","phys_dps","invis","silence"},
    npc_dota_hero_clinkz             = {"carry","phys_dps","invis","push"},
    npc_dota_hero_sniper             = {"carry","phys_dps","ranged","siege"},
    npc_dota_hero_templar_assassin   = {"carry","phys_burst","armor_reduce","invis"},
    npc_dota_hero_bloodseeker        = {"carry","phys_dps","heal","silence","rupture"},
    npc_dota_hero_lycan              = {"carry","phys_dps","push","summons"},
    npc_dota_hero_huskar             = {"carry","magic_resist","phys_dps","heal"},
    npc_dota_hero_alchemist          = {"carry","phys_dps","stun","tanky","farm"},
    npc_dota_hero_skeleton_king      = {"carry","phys_dps","stun","reincarnation"},
    npc_dota_hero_arc_warden         = {"carry","phys_dps","push","summons","ranged"},
    npc_dota_hero_lone_druid         = {"carry","phys_dps","push","summons"},
    npc_dota_hero_ember_spirit       = {"carry","magic_burst","mobility","cleave"},
    npc_dota_hero_gyrocopter         = {"carry","magic_burst","phys_dps","ranged"},
    npc_dota_hero_nevermore          = {"carry","phys_dps","magic_burst","armor_reduce"},
    npc_dota_hero_razor              = {"carry","phys_dps","tanky","armor_reduce","drain"},
    npc_dota_hero_viper              = {"carry","slow","magic_burst","break","tanky"},

    -- ══════════════ Magic Burst / Nukers ══════════════
    npc_dota_hero_invoker            = {"magic_burst","disable","global","versatile"},
    npc_dota_hero_storm_spirit       = {"magic_burst","mobility","disable"},
    npc_dota_hero_lina               = {"magic_burst","stun","phys_dps"},
    npc_dota_hero_zuus               = {"magic_burst","global","vision"},
    npc_dota_hero_tinker             = {"magic_burst","push","rearm"},
    npc_dota_hero_queenofpain        = {"magic_burst","mobility","silence"},
    npc_dota_hero_puck               = {"magic_burst","mobility","disable","silence"},
    npc_dota_hero_void_spirit        = {"magic_burst","mobility","disable"},
    npc_dota_hero_leshrac            = {"magic_burst","push","stun"},
    npc_dota_hero_death_prophet      = {"magic_burst","push","heal","silence"},
    npc_dota_hero_necrolyte          = {"magic_burst","heal","tanky","anti_heal"},
    npc_dota_hero_skywrath_mage      = {"magic_burst","silence","slow"},
    npc_dota_hero_pugna              = {"magic_burst","push","ward"},
    npc_dota_hero_dark_willow        = {"magic_burst","disable","fear"},
    npc_dota_hero_hoodwink           = {"magic_burst","disable","invis"},
    npc_dota_hero_muerta             = {"magic_burst","phys_dps","silence","invis"},
    npc_dota_hero_obsidian_destroyer = {"magic_burst","mana_burn","disable","int"},
    npc_dota_hero_phoenix            = {"magic_burst","heal","disable","slow"},
    npc_dota_hero_shredder           = {"magic_burst","tanky","pure_dmg"},
    npc_dota_hero_venomancer         = {"magic_burst","slow","push","summons"},

    -- ══════════════ Disable / Control ══════════════
    npc_dota_hero_lion               = {"disable","stun","hex","magic_burst","mana_burn"},
    npc_dota_hero_shadow_shaman      = {"disable","push","hex","stun"},
    npc_dota_hero_bane               = {"disable","pure_dmg","nightmare"},
    npc_dota_hero_enigma             = {"disable","black_hole","push","summons"},
    npc_dota_hero_tidehunter         = {"disable","tanky","armor_reduce"},
    npc_dota_hero_magnataur          = {"disable","empower","mobility"},
    npc_dota_hero_earthshaker        = {"disable","stun","magic_burst"},
    npc_dota_hero_sand_king          = {"disable","stun","magic_burst"},
    npc_dota_hero_elder_titan        = {"disable","armor_reduce","magic_resist_reduce"},
    npc_dota_hero_primal_beast       = {"disable","tanky","phys_dps","magic_burst"},
    npc_dota_hero_spirit_breaker     = {"disable","bash","global","mobility"},
    npc_dota_hero_axe                = {"disable","tanky","call"},
    npc_dota_hero_legion_commander   = {"disable","phys_dps","duel"},
    npc_dota_hero_doom_bringer       = {"disable","doom","tanky"},
    npc_dota_hero_batrider           = {"disable","mobility","magic_burst"},
    npc_dota_hero_mars               = {"disable","tanky","phys_burst"},
    npc_dota_hero_centaur            = {"disable","tanky","stun","global"},
    npc_dota_hero_slardar            = {"disable","armor_reduce","bash","phys_dps"},
    npc_dota_hero_brewmaster         = {"disable","tanky","evasion","summons"},
    npc_dota_hero_rattletrap         = {"disable","tanky","vision"},
    npc_dota_hero_nyx_assassin       = {"disable","invis","mana_burn","magic_burst"},
    npc_dota_hero_tusk               = {"disable","phys_burst","mobility","save"},
    npc_dota_hero_ringmaster         = {"disable","magic_burst","fear"},
    npc_dota_hero_beastmaster        = {"disable","push","summons","vision"},

    -- ══════════════ Support / Utility ══════════════
    npc_dota_hero_crystal_maiden     = {"magic_burst","disable","slow","mana"},
    npc_dota_hero_dazzle             = {"heal","save","armor"},
    npc_dota_hero_oracle             = {"heal","save","purge","magic_burst"},
    npc_dota_hero_omniknight         = {"heal","save","magic_immune","tanky"},
    npc_dota_hero_abaddon            = {"heal","save","purge","tanky"},
    npc_dota_hero_chen               = {"heal","push","summons","global"},
    npc_dota_hero_enchantress        = {"heal","slow","summons","pure_dmg"},
    npc_dota_hero_wisp               = {"heal","save","global","tether"},
    npc_dota_hero_witch_doctor       = {"heal","stun","magic_burst"},
    npc_dota_hero_warlock            = {"heal","disable","summons","magic_burst"},
    npc_dota_hero_jakiro             = {"magic_burst","push","slow","disable"},
    npc_dota_hero_disruptor          = {"disable","silence","magic_burst"},
    npc_dota_hero_winter_wyvern      = {"disable","save","magic_burst","slow"},
    npc_dota_hero_shadow_demon       = {"disable","purge","save","illusions"},
    npc_dota_hero_grimstroke         = {"disable","magic_burst","silence"},
    npc_dota_hero_snapfire           = {"disable","magic_burst","stun"},
    npc_dota_hero_marci              = {"disable","phys_burst","mobility","save"},
    npc_dota_hero_bounty_hunter      = {"invis","track","phys_burst","slow"},
    npc_dota_hero_keeper_of_the_light = {"magic_burst","heal","mana","push"},
    npc_dota_hero_dawnbreaker        = {"heal","stun","global","phys_dps"},

    -- ══════════════ Tanky / Initiators ══════════════
    npc_dota_hero_bristleback        = {"tanky","phys_dps","slow"},
    npc_dota_hero_dragon_knight      = {"tanky","stun","push"},
    npc_dota_hero_abyssal_underlord  = {"tanky","magic_burst","global","aura"},
    npc_dota_hero_night_stalker      = {"tanky","silence","phys_dps","vision"},
    npc_dota_hero_undying            = {"tanky","heal","slow","summons"},
    npc_dota_hero_ogre_magi          = {"tanky","stun","buff","magic_burst"},
    npc_dota_hero_treant             = {"tanky","heal","invis","global"},
    npc_dota_hero_pudge              = {"tanky","pure_dmg","disable"},

    -- ══════════════ Misc / Multi-role ══════════════
    npc_dota_hero_meepo              = {"carry","disable","magic_burst","summons"},
    npc_dota_hero_broodmother        = {"carry","push","summons","invis"},
    npc_dota_hero_visage             = {"magic_burst","summons","phys_dps"},
    npc_dota_hero_techies            = {"magic_burst","disable","mines"},
    npc_dota_hero_furion             = {"push","global","summons","phys_dps"},
    npc_dota_hero_vengefulspirit     = {"stun","save","armor_reduce","phys_dps"},
    npc_dota_hero_rubick             = {"disable","magic_burst","steal"},
    npc_dota_hero_silencer           = {"silence","magic_burst","global","mana_burn"},
    npc_dota_hero_ancient_apparition = {"magic_burst","global","anti_heal"},
    npc_dota_hero_lich               = {"magic_burst","slow","save"},
    npc_dota_hero_windrunner         = {"phys_dps","disable","evasion","magic_burst"},
    npc_dota_hero_mirana             = {"magic_burst","stun","invis","mobility"},
    npc_dota_hero_pangolier          = {"disable","phys_dps","mobility","evasion"},
    npc_dota_hero_dark_seer          = {"tanky","illusions","mobility","aura"},
    npc_dota_hero_earth_spirit       = {"disable","silence","magic_burst","mobility"},
    npc_dota_hero_kunkka             = {"phys_burst","disable","cleave"},
    npc_dota_hero_tiny               = {"phys_burst","stun","push","tanky"},
    npc_dota_hero_kez                = {"carry","phys_burst","mobility","invis"},
}

local function addHeroTags741D(heroName, tags)
    local dst = HERO_TAGS[heroName] or {}
    local seen = {}
    for _, tag in ipairs(dst) do seen[tag] = true end
    for _, tag in ipairs(tags or {}) do
        if not seen[tag] then
            dst[#dst + 1] = tag
            seen[tag] = true
        end
    end
    HERO_TAGS[heroName] = dst
end

local HERO_TAGS_741D_EXTRA = {
    npc_dota_hero_antimage = {"blink_escape","spell_shield","pickoff"},
    npc_dota_hero_arc_warden = {"clone","bubble","split_push"},
    npc_dota_hero_bristleback = {"breakable","regen","frontliner"},
    npc_dota_hero_broodmother = {"summon_swarm","lane_domination"},
    npc_dota_hero_chaos_knight = {"illusion_burst","single_target_burst"},
    npc_dota_hero_doom_bringer = {"bkb_piercing_disable","single_target_disable"},
    npc_dota_hero_enigma = {"bkb_piercing_disable","channel_ultimate","blink_initiator"},
    npc_dota_hero_faceless_void = {"bkb_piercing_disable","arena_control","blink_escape"},
    npc_dota_hero_huskar = {"regen","low_hp_fighter","anti_magic_core"},
    npc_dota_hero_legion_commander = {"bkb_piercing_disable","single_target_disable","snowball"},
    npc_dota_hero_life_stealer = {"lifesteal","anti_magic_core"},
    npc_dota_hero_medusa = {"mana_shield","mana_dependent","frontliner"},
    npc_dota_hero_morphling = {"regen","attribute_shift","burst_escape"},
    npc_dota_hero_naga_siren = {"illusion_core","sleep_setup"},
    npc_dota_hero_necrolyte = {"regen","spell_lifesteal","execute"},
    npc_dota_hero_omniknight = {"save_core","strong_dispel","anti_physical_save"},
    npc_dota_hero_oracle = {"save_core","strong_dispel","heal"},
    npc_dota_hero_phantom_assassin = {"breakable","evasion_core","jump_burst"},
    npc_dota_hero_phantom_lancer = {"illusion_core","mana_burn_core"},
    npc_dota_hero_puck = {"phase_escape","coil_control"},
    npc_dota_hero_pudge = {"bkb_piercing_disable","hook_pickoff"},
    npc_dota_hero_razor = {"link_drain","anti_carry"},
    npc_dota_hero_riki = {"smoke_silence","permanent_invis"},
    npc_dota_hero_shadow_demon = {"save_core","illusion_save","purge"},
    npc_dota_hero_silencer = {"global_silence","anti_caster"},
    npc_dota_hero_slark = {"leash","regen","night_vision"},
    npc_dota_hero_spectre = {"breakable","global_dive","dispersion"},
    npc_dota_hero_storm_spirit = {"ball_escape","mana_dependent","pickoff"},
    npc_dota_hero_templar_assassin = {"evasion_core","invis_trap","refraction"},
    npc_dota_hero_terrorblade = {"illusion_core","sunder","metamorph_timing"},
    npc_dota_hero_tidehunter = {"blink_initiator","teamfight_disable"},
    npc_dota_hero_tinker = {"spell_spam","blink_escape","split_push"},
    npc_dota_hero_troll_warlord = {"low_hp_fighter","ult_survival"},
    npc_dota_hero_ursa = {"roshan","jump_burst","status_resist"},
    npc_dota_hero_viper = {"break","anti_carry","poison"},
    npc_dota_hero_weaver = {"invis_escape","time_lapse","bug_vision"},
    npc_dota_hero_windrunner = {"evasion_core","single_target_focus"},
    npc_dota_hero_wisp = {"save_core","global_save","heal"},
    npc_dota_hero_kez = {"parry","jump_burst","silence_window"},
    npc_dota_hero_largo = {"magic_burst","disable","tanky","tempo_core"},
}

for heroName, tags in pairs(HERO_TAGS_741D_EXTRA) do
    addHeroTags741D(heroName, tags)
end

--------------------------------------------------------------------------------
-- GAME MODE DETECTION
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- GAME MODE DETECTION
--------------------------------------------------------------------------------
local GAME_MODE = {
    UNKNOWN = 0,
    ALL_PICK = 1,
    RANKED = 2,
    TURBO = 3,
    SINGLE_DRAFT = 4,
    ALL_RANDOM = 5,
    CAPTAINS_MODE = 6,
    ABILITY_DRAFT = 7,
}

local function GetEnum(path)
    local ok, res = pcall(function()
        local parts = {}
        for part in path:gmatch("[^%.]+") do table.insert(parts, part) end
        local curr = _G
        for _, p in ipairs(parts) do
            if not curr[p] then return nil end
            curr = curr[p]
        end
        return curr
    end)
    return ok and res or nil
end

local MODE_PHASE_MULTIPLIERS = {
    [GAME_MODE.UNKNOWN]        = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.ALL_PICK]       = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.RANKED]         = {early = 1.1, mid = 1.0, late = 0.9},
    [GAME_MODE.TURBO]          = {early = 0.5, mid = 0.8, late = 1.5}, -- Turbo: skip early, focus late
    [GAME_MODE.SINGLE_DRAFT]   = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.ALL_RANDOM]     = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.CAPTAINS_MODE]  = {early = 1.1, mid = 1.0, late = 0.9},
    [GAME_MODE.ABILITY_DRAFT]  = {early = 0.8, mid = 1.0, late = 1.2},
}

--------------------------------------------------------------------------------
-- HERO ROLE SYSTEM (for hero-aware item scoring)
-- role: "carry", "mid", "offlane", "support", "hardsupport"
-- style: "phys" = physical DPS, "magic" = caster, "hybrid", "utility"
-- Items tagged with excluded_roles get heavy penalty when you play that role.
-- Items tagged with preferred_styles get bonus when hero matches.
--------------------------------------------------------------------------------
local HERO_ROLES = {
    -- ══════════ Carry (Pos 1) ══════════
    npc_dota_hero_antimage           = {role="carry",  style="phys"},
    npc_dota_hero_phantom_assassin   = {role="carry",  style="phys"},
    npc_dota_hero_juggernaut         = {role="carry",  style="phys"},
    npc_dota_hero_faceless_void      = {role="carry",  style="phys"},
    npc_dota_hero_terrorblade        = {role="carry",  style="phys"},
    npc_dota_hero_spectre            = {role="carry",  style="phys"},
    npc_dota_hero_phantom_lancer     = {role="carry",  style="phys"},
    npc_dota_hero_medusa             = {role="carry",  style="phys"},
    npc_dota_hero_troll_warlord      = {role="carry",  style="phys"},
    npc_dota_hero_ursa               = {role="carry",  style="phys"},
    npc_dota_hero_sven               = {role="carry",  style="phys"},
    npc_dota_hero_life_stealer       = {role="carry",  style="phys"},
    npc_dota_hero_slark              = {role="carry",  style="phys"},
    npc_dota_hero_monkey_king        = {role="carry",  style="phys"},
    npc_dota_hero_chaos_knight       = {role="carry",  style="phys"},
    npc_dota_hero_luna               = {role="carry",  style="phys"},
    npc_dota_hero_drow_ranger        = {role="carry",  style="phys"},
    npc_dota_hero_morphling          = {role="carry",  style="hybrid"},
    npc_dota_hero_naga_siren         = {role="carry",  style="phys"},
    npc_dota_hero_weaver             = {role="carry",  style="phys"},
    npc_dota_hero_riki               = {role="carry",  style="phys"},
    npc_dota_hero_clinkz             = {role="carry",  style="phys"},
    npc_dota_hero_sniper             = {role="carry",  style="phys"},
    npc_dota_hero_templar_assassin   = {role="carry",  style="phys"},
    npc_dota_hero_bloodseeker        = {role="carry",  style="phys"},
    npc_dota_hero_lycan              = {role="carry",  style="phys"},
    npc_dota_hero_huskar             = {role="carry",  style="phys"},
    npc_dota_hero_alchemist          = {role="carry",  style="phys"},
    npc_dota_hero_skeleton_king      = {role="carry",  style="phys"},
    npc_dota_hero_arc_warden         = {role="carry",  style="phys"},
    npc_dota_hero_lone_druid         = {role="carry",  style="phys"},
    npc_dota_hero_gyrocopter         = {role="carry",  style="hybrid"},
    npc_dota_hero_nevermore          = {role="carry",  style="hybrid"},
    npc_dota_hero_razor              = {role="carry",  style="hybrid"},
    npc_dota_hero_viper              = {role="carry",  style="hybrid"},
    npc_dota_hero_meepo              = {role="carry",  style="hybrid"},
    npc_dota_hero_broodmother        = {role="carry",  style="phys"},
    npc_dota_hero_kez                = {role="carry",  style="phys"},
    -- ══════════ Mid (Pos 2) ══════════
    npc_dota_hero_invoker            = {role="mid",    style="magic"},
    npc_dota_hero_storm_spirit       = {role="mid",    style="magic"},
    npc_dota_hero_ember_spirit       = {role="mid",    style="magic"},
    npc_dota_hero_lina               = {role="mid",    style="magic"},
    npc_dota_hero_zuus               = {role="mid",    style="magic"},
    npc_dota_hero_tinker             = {role="mid",    style="magic"},
    npc_dota_hero_queenofpain        = {role="mid",    style="magic"},
    npc_dota_hero_puck               = {role="mid",    style="magic"},
    npc_dota_hero_void_spirit        = {role="mid",    style="magic"},
    npc_dota_hero_leshrac            = {role="mid",    style="magic"},
    npc_dota_hero_death_prophet      = {role="mid",    style="magic"},
    npc_dota_hero_obsidian_destroyer = {role="mid",    style="magic"},
    npc_dota_hero_skywrath_mage      = {role="mid",    style="magic"},
    npc_dota_hero_muerta             = {role="mid",    style="hybrid"},
    npc_dota_hero_windrunner         = {role="mid",    style="hybrid"},
    -- ══════════ Offlane (Pos 3) ══════════
    npc_dota_hero_axe                = {role="offlane",style="utility"},
    npc_dota_hero_tidehunter         = {role="offlane",style="utility"},
    npc_dota_hero_bristleback        = {role="offlane",style="phys"},
    npc_dota_hero_centaur            = {role="offlane",style="utility"},
    npc_dota_hero_mars               = {role="offlane",style="utility"},
    npc_dota_hero_legion_commander   = {role="offlane",style="phys"},
    npc_dota_hero_doom_bringer       = {role="offlane",style="utility"},
    npc_dota_hero_sand_king          = {role="offlane",style="magic"},
    npc_dota_hero_slardar            = {role="offlane",style="utility"},
    npc_dota_hero_magnataur          = {role="offlane",style="utility"},
    npc_dota_hero_night_stalker      = {role="offlane",style="phys"},
    npc_dota_hero_primal_beast       = {role="offlane",style="utility"},
    npc_dota_hero_dragon_knight      = {role="offlane",style="hybrid"},
    npc_dota_hero_abyssal_underlord  = {role="offlane",style="utility"},
    npc_dota_hero_batrider           = {role="offlane",style="magic"},
    npc_dota_hero_brewmaster         = {role="offlane",style="utility"},
    npc_dota_hero_spirit_breaker     = {role="offlane",style="utility"},
    npc_dota_hero_dark_seer          = {role="offlane",style="utility"},
    npc_dota_hero_necrolyte          = {role="offlane",style="magic"},
    npc_dota_hero_undying            = {role="offlane",style="utility"},
    npc_dota_hero_pangolier          = {role="offlane",style="hybrid"},
    npc_dota_hero_earth_spirit       = {role="offlane",style="utility"},
    npc_dota_hero_pudge              = {role="offlane",style="utility"},
    npc_dota_hero_rattletrap         = {role="offlane",style="utility"},
    npc_dota_hero_shredder           = {role="offlane",style="magic"},
    npc_dota_hero_elder_titan        = {role="offlane",style="utility"},
    npc_dota_hero_phoenix            = {role="offlane",style="magic"},
    npc_dota_hero_ringmaster         = {role="offlane",style="magic"},
    npc_dota_hero_kunkka             = {role="offlane",style="hybrid"},
    npc_dota_hero_tiny               = {role="offlane",style="hybrid"},
    npc_dota_hero_beastmaster        = {role="offlane",style="utility"},
    -- ══════════ Support (Pos 4) ══════════
    npc_dota_hero_earthshaker        = {role="support",style="utility"},
    npc_dota_hero_tusk               = {role="support",style="utility"},
    npc_dota_hero_bounty_hunter      = {role="support",style="utility"},
    npc_dota_hero_nyx_assassin       = {role="support",style="utility"},
    npc_dota_hero_rubick             = {role="support",style="magic"},
    npc_dota_hero_mirana             = {role="support",style="magic"},
    npc_dota_hero_dark_willow        = {role="support",style="magic"},
    npc_dota_hero_hoodwink           = {role="support",style="magic"},
    npc_dota_hero_grimstroke         = {role="support",style="magic"},
    npc_dota_hero_snapfire           = {role="support",style="utility"},
    npc_dota_hero_marci              = {role="support",style="utility"},
    npc_dota_hero_vengefulspirit     = {role="support",style="utility"},
    npc_dota_hero_pugna              = {role="support",style="magic"},
    npc_dota_hero_disruptor          = {role="support",style="magic"},
    npc_dota_hero_shadow_demon       = {role="support",style="magic"},
    npc_dota_hero_furion             = {role="support",style="hybrid"},
    npc_dota_hero_techies            = {role="support",style="magic"},
    npc_dota_hero_jakiro             = {role="support",style="magic"},
    npc_dota_hero_silencer           = {role="support",style="magic"},
    npc_dota_hero_venomancer         = {role="support",style="magic"},
    npc_dota_hero_visage             = {role="support",style="hybrid"},
    -- ══════════ Hard Support (Pos 5) ══════════
    npc_dota_hero_crystal_maiden     = {role="hardsupport",style="magic"},
    npc_dota_hero_dazzle             = {role="hardsupport",style="utility"},
    npc_dota_hero_oracle             = {role="hardsupport",style="utility"},
    npc_dota_hero_omniknight         = {role="hardsupport",style="utility"},
    npc_dota_hero_abaddon            = {role="hardsupport",style="utility"},
    npc_dota_hero_chen               = {role="hardsupport",style="utility"},
    npc_dota_hero_enchantress        = {role="hardsupport",style="utility"},
    npc_dota_hero_wisp               = {role="hardsupport",style="utility"},
    npc_dota_hero_witch_doctor       = {role="hardsupport",style="magic"},
    npc_dota_hero_warlock            = {role="hardsupport",style="magic"},
    npc_dota_hero_winter_wyvern      = {role="hardsupport",style="magic"},
    npc_dota_hero_lich               = {role="hardsupport",style="magic"},
    npc_dota_hero_lion               = {role="hardsupport",style="magic"},
    npc_dota_hero_shadow_shaman      = {role="hardsupport",style="magic"},
    npc_dota_hero_bane               = {role="hardsupport",style="utility"},
    npc_dota_hero_enigma             = {role="hardsupport",style="utility"},
    npc_dota_hero_keeper_of_the_light = {role="hardsupport",style="magic"},
    npc_dota_hero_ogre_magi          = {role="hardsupport",style="utility"},
    npc_dota_hero_treant             = {role="hardsupport",style="utility"},
    npc_dota_hero_dawnbreaker        = {role="hardsupport",style="utility"},
    npc_dota_hero_ancient_apparition = {role="hardsupport",style="magic"},
}

-- Items that are BAD for certain roles (heavy score penalty).
-- carry/mid with "phys" style shouldn't buy support/utility items that waste a slot.
-- support/hardsupport shouldn't buy expensive DPS items.
local ITEM_ROLE_PENALTY = {
    -- Support/utility items bad for phys carries (slot waste)
    item_pavise          = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_mekansm         = {bad_roles={"carry","mid"}},
    item_guardian_greaves = {bad_roles={"carry","mid"}},
    item_holy_locket     = {bad_roles={"carry","mid"}},
    item_tranquil_boots  = {bad_roles={"carry","mid"}, bad_styles={"phys"}},
    item_glimmer_cape    = {bad_roles={"carry"}},
    item_force_staff     = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_medallion_of_courage = {bad_roles={"carry","mid"}},
    item_solar_crest     = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_rod_of_atos     = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_veil_of_discord = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_aether_lens     = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_arcane_boots    = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_pipe            = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_crimson_guard   = {bad_roles={"carry","mid"}, bad_styles={"magic"}},
    item_spirit_vessel   = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_cyclone         = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_ghost           = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_lotus_orb       = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_blade_mail      = {bad_styles={"magic"}},
    -- Expensive DPS items bad for hard supports
    item_daedalus        = {bad_roles={"hardsupport","support"}},
    item_butterfly       = {bad_roles={"hardsupport","support"}},
    item_satanic         = {bad_roles={"hardsupport","support"}},
    item_mask_of_madness = {bad_roles={"hardsupport","support"}, bad_styles={"magic","utility"}},
    item_armlet          = {bad_roles={"hardsupport","support"}, bad_styles={"magic"}},
    item_battlefury      = {bad_roles={"hardsupport","support"}, bad_styles={"magic"}},
    item_desolator       = {bad_roles={"hardsupport","support"}},
    item_mjollnir        = {bad_roles={"hardsupport"}},
    item_skadi           = {bad_roles={"hardsupport"}},
    item_abyssal_blade   = {bad_roles={"hardsupport","support"}},
    item_nullifier       = {bad_roles={"hardsupport","support"}},
    item_bloodthorn      = {bad_roles={"hardsupport"}},
    item_silver_edge     = {bad_roles={"hardsupport"}},
    item_diffusal_blade  = {bad_roles={"hardsupport"}, bad_styles={"magic"}},
    item_monkey_king_bar = {bad_roles={"hardsupport","support"}},
    item_radiance        = {bad_roles={"hardsupport","support"}},
    item_refresher       = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_hand_of_midas   = {bad_roles={"hardsupport","support"}},
    item_harpoon         = {bad_roles={"hardsupport","support"}},
    item_heart           = {bad_roles={"hardsupport","support"}},
    item_overwhelming_blink = {bad_roles={"hardsupport","support"}},
    item_swift_blink     = {bad_roles={"hardsupport","support"}, bad_styles={"magic"}},
    item_arcane_blink    = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_dagon           = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_ethereal_blade  = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_vanguard        = {bad_roles={"carry"}, bad_styles={"magic"}},
    item_bloodstone      = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_octarine_core   = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_kaya_and_sange  = {bad_styles={"phys"}},
    item_yasha_and_kaya  = {bad_styles={"phys"}},
    item_witch_blade     = {bad_roles={"hardsupport"}},
    item_phylactery      = {bad_roles={"carry"}, bad_styles={"phys"}},
}

--------------------------------------------------------------------------------
-- HERO SPECIFIC ITEMS (предметы для конкретных героев)
-- good_items: предметы которые особенно хороши на этом герое (бонус score)
-- bad_items: предметы которые плохи на этом герое (штраф score)
-- Это позволяет учитывать специфику героя, например BF на Arc Warden - плохая идея
--------------------------------------------------------------------------------
local HERO_SPECIFIC_ITEMS = {
    -- ══════════════ Carry Heroes ══════════════
    npc_dota_hero_arc_warden = {
        good_items = {
            "item_mjollnir", "item_butterfly", "item_satanic", "item_skadi",
            "item_monkey_king_bar", "item_black_king_bar", "item_blink",
            "item_swift_blink", "item_nullifier", "item_abyssal_blade",
            "item_diffusal_blade", "item_manta", "item_disperser"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_vanguard", "item_heart", "item_blade_mail"
        },
        reason_good = "Arc Warden uses Tempest Double to duplicate items",
        reason_bad = "BF/Radiance don't work with Tempest Double"
    },
    npc_dota_hero_phantom_lancer = {
        good_items = {
            "item_diffusal_blade", "item_manta", "item_butterfly", "item_satanic",
            "item_skadi", "item_abyssal_blade", "item_disperser", "item_heart"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_radiance",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Illusions benefit from these items",
        reason_bad = "BF/Mjollnir/Radiance don't work on illusions"
    },
    npc_dota_hero_terrorblade = {
        good_items = {
            "item_satanic", "item_butterfly", "item_skadi", "item_manta",
            "item_heart", "item_black_king_bar", "item_disperser"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_radiance",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Illusions and metamorphosis synergy",
        reason_bad = "BF/Mjollnir don't work on illusions"
    },
    npc_dota_hero_naga_siren = {
        good_items = {
            "item_diffusal_blade", "item_manta", "item_butterfly", "item_heart",
            "item_skadi", "item_radiance", "item_disperser"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_desolator",
            "item_monkey_king_bar"
        },
        reason_good = "Illusions push and fight",
        reason_bad = "BF/Mjollnir don't work on illusions"
    },
    npc_dota_hero_chaos_knight = {
        good_items = {
            "item_armlet", "item_heart", "item_satanic", "item_skadi",
            "item_abyssal_blade", "item_manta", "item_black_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_radiance",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Illusions get full stats from items",
        reason_bad = "BF/Mjollnir don't work on illusions"
    },
    npc_dota_hero_meepo = {
        good_items = {
            "item_power_treads", "item_aghanims_scepter", "item_blink",
            "item_ethereal_blade", "item_sheepstick", "item_octarine_core",
            "item_witch_blade", "item_assault"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_heart", "item_satanic"
        },
        reason_good = "All Meepos benefit from stats",
        reason_bad = "BF/Radiance only work on main Meepo"
    },
    npc_dota_hero_antimage = {
        good_items = {
            "item_battlefury", "item_manta", "item_blink", "item_abyssal_blade",
            "item_skadi", "item_satanic", "item_butterfly", "item_black_king_bar"
        },
        bad_items = {
            "item_hand_of_midas", "item_radiance", "item_mjollnir"
        },
        reason_good = "Classic AM build with BF farm",
        reason_bad = "Midas too slow, Radiance/Mjollnir not optimal"
    },
    npc_dota_hero_spectre = {
        good_items = {
            "item_radiance", "item_blade_mail", "item_heart", "item_skadi",
            "item_spirit_vessel", "item_crimson_guard", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_hand_of_midas", "item_desolator",
            "item_monkey_king_bar"
        },
        reason_good = "Radiance + Haunt is devastating",
        reason_bad = "BF doesn't help Spectre's playstyle"
    },
    npc_dota_hero_faceless_void = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_butterfly", "item_satanic",
            "item_abyssal_blade", "item_monkey_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + Chronosphere synergy",
        reason_bad = "BF/Radiance don't fit Void's burst style"
    },
    npc_dota_hero_juggernaut = {
        good_items = {
            "item_battlefury", "item_mask_of_madness", "item_manta",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_abyssal_blade", "item_swift_blink"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas"
        },
        reason_good = "BF for farm + Omnislash synergy",
        reason_bad = "Radiance doesn't fit Jugg's style"
    },
    npc_dota_hero_ursa = {
        good_items = {
            "item_blink", "item_black_king_bar", "item_satanic", "item_skadi",
            "item_abyssal_blade", "item_butterfly", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Blink + BKB for burst damage",
        reason_bad = "BF/Radiance don't help Ursa's burst"
    },
    npc_dota_hero_slark = {
        good_items = {
            "item_silver_edge", "item_sange_and_yasha", "item_skadi",
            "item_blink", "item_black_king_bar", "item_abyssal_blade",
            "item_butterfly", "item_satanic"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Mobility + stat stealing synergy",
        reason_bad = "BF/Radiance reveal Slark's position"
    },
    npc_dota_hero_weaver = {
        good_items = {
            "item_desolator", "item_black_king_bar", "item_silver_edge",
            "item_butterfly", "item_manta", "item_monkey_king_bar",
            "item_abyssal_blade"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Deso + Geminate Attack burst",
        reason_bad = "BF/Radiance don't fit Weaver's hit-and-run"
    },
    npc_dota_hero_clinkz = {
        good_items = {
            "item_desolator", "item_silver_edge", "item_black_king_bar",
            "item_butterfly", "item_satanic", "item_monkey_king_bar",
            "item_abyssal_blade", "item_hurricane_pike"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Burst + Strafe synergy",
        reason_bad = "BF/Radiance reveal Clinkz"
    },
    npc_dota_hero_templar_assassin = {
        good_items = {
            "item_desolator", "item_blink", "item_black_king_bar",
            "item_butterfly", "item_satanic", "item_monkey_king_bar",
            "item_abyssal_blade", "item_swift_blink"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Deso + Refraction burst",
        reason_bad = "BF/Radiance don't fit TA's burst style"
    },
    npc_dota_hero_sniper = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_skadi", "item_hurricane_pike", "item_monkey_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_blink"
        },
        reason_good = "Range + attack speed synergy",
        reason_bad = "BF/Radiance don't fit Sniper's range"
    },
    npc_dota_hero_drow_ranger = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_skadi", "item_hurricane_pike", "item_monkey_king_bar",
            "item_silver_edge"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_blink"
        },
        reason_good = "Glaives + attack speed synergy",
        reason_bad = "BF/Radiance don't fit Drow's range"
    },
    npc_dota_hero_medusa = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_skadi", "item_butterfly", "item_satanic", "item_black_king_bar",
            "item_monkey_king_bar", "item_heart"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_desolator",
            "item_diffusal_blade"
        },
        reason_good = "Mana + attack speed for Stone Gaze",
        reason_bad = "BF/Deso don't fit Medusa's split shot"
    },
    npc_dota_hero_luna = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_skadi", "item_monkey_king_bar", "item_hurricane_pike"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_desolator"
        },
        reason_good = "Glaives + Eclipse synergy",
        reason_bad = "BF doesn't work with Glaives"
    },
    npc_dota_hero_sven = {
        good_items = {
            "item_mask_of_madness", "item_blink", "item_black_king_bar",
            "item_satanic", "item_abyssal_blade", "item_swift_blink",
            "item_monkey_king_bar", "item_assault"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas", "item_mjollnir"
        },
        reason_good = "Blink + God's Strength burst",
        reason_bad = "Radiance doesn't fit Sven's burst"
    },
    npc_dota_hero_troll_warlord = {
        good_items = {
            "item_mask_of_madness", "item_black_king_bar", "item_satanic",
            "item_butterfly", "item_skadi", "item_abyssal_blade",
            "item_monkey_king_bar", "item_silver_edge"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + bash synergy",
        reason_bad = "BF/Radiance don't fit Troll's fight style"
    },
    npc_dota_hero_life_stealer = {
        good_items = {
            "item_desolator", "item_sange_and_yasha", "item_black_king_bar",
            "item_satanic", "item_skadi", "item_abyssal_blade",
            "item_monkey_king_bar", "item_silver_edge"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Lifesteal + Rage synergy",
        reason_bad = "BF/Radiance don't fit LS's style"
    },
    npc_dota_hero_huskar = {
        good_items = {
            "item_armlet", "item_black_king_bar", "item_satanic", "item_skadi",
            "item_heart", "item_heavens_halberd", "item_spirit_vessel"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir", "item_monkey_king_bar"
        },
        reason_good = "Armlet + Berserker's Blood synergy",
        reason_bad = "BF/Radiance don't fit Huskar's magic damage"
    },
    npc_dota_hero_bloodseeker = {
        good_items = {
            "item_maelstrom", "item_mjollnir", "item_black_king_bar",
            "item_sange_and_yasha", "item_butterfly", "item_satanic",
            "item_monkey_king_bar", "item_abyssal_blade"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + Blood Rite synergy",
        reason_bad = "BF doesn't fit BS's chase style"
    },
    npc_dota_hero_broodmother = {
        good_items = {
            "item_soul_ring", "item_black_king_bar", "item_butterfly",
            "item_satanic", "item_skadi", "item_monkey_king_bar",
            "item_abyssal_blade", "item_assault"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Spiderlings + lifesteal synergy",
        reason_bad = "BF doesn't help Brood's spider army"
    },
    npc_dota_hero_lycan = {
        good_items = {
            "item_vladmir", "item_black_king_bar", "item_assault",
            "item_abyssal_blade", "item_satanic", "item_monkey_king_bar",
            "item_desolator"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Wolves + Shapeshift synergy",
        reason_bad = "BF doesn't help Lycan's summons"
    },
    npc_dota_hero_lone_druid = {
        good_items = {
            "item_soul_ring", "item_black_king_bar", "item_assault",
            "item_butterfly", "item_satanic", "item_monkey_king_bar",
            "item_abyssal_blade", "item_skadi"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Spirit Bear + items synergy",
        reason_bad = "BF doesn't help Spirit Bear"
    },
    -- ══════════════ Mid Heroes ══════════════
    npc_dota_hero_invoker = {
        good_items = {
            "item_aghanims_scepter", "item_black_king_bar", "item_blink",
            "item_octarine_core", "item_sheepstick", "item_refresher",
            "item_arcane_blink", "item_sphere"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Spell amp + CDR for Invoker",
        reason_bad = "Right-click items don't fit Invoker"
    },
    npc_dota_hero_storm_spirit = {
        good_items = {
            "item_bloodstone", "item_black_king_bar", "item_sheepstick",
            "item_octarine_core", "item_sphere", "item_arcane_blink",
            "item_orchid", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Mana + spell amp for Ball Lightning",
        reason_bad = "Right-click items don't fit Storm"
    },
    npc_dota_hero_ember_spirit = {
        good_items = {
            "item_battlefury", "item_black_king_bar", "item_maelstrom",
            "item_mjollnir", "item_sheepstick", "item_blink",
            "item_swift_blink", "item_satanic"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas", "item_desolator"
        },
        reason_good = "BF + Sleight of Fist synergy",
        reason_bad = "Radiance doesn't fit Ember's style"
    },
    npc_dota_hero_tinker = {
        good_items = {
            "item_blink", "item_aether_lens", "item_sheepstick",
            "item_octarine_core", "item_dagon", "item_ethereal_blade",
            "item_arcane_blink", "item_sphere"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Rearm + active items synergy",
        reason_bad = "Right-click items don't fit Tinker"
    },
    npc_dota_hero_zuus = {
        good_items = {
            "item_aether_lens", "item_octarine_core", "item_sheepstick",
            "item_refresher", "item_aghanims_scepter", "item_dagon",
            "item_ethereal_blade", "item_kaya_and_sange"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_blink"
        },
        reason_good = "Spell amp + global presence",
        reason_bad = "Right-click items don't fit Zeus"
    },
    npc_dota_hero_puck = {
        good_items = {
            "item_blink", "item_aether_lens", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_arcane_blink",
            "item_gungir", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Mobility + spell amp for Puck",
        reason_bad = "Right-click items don't fit Puck"
    },
    npc_dota_hero_queenofpain = {
        good_items = {
            "item_blink", "item_aether_lens", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_arcane_blink",
            "item_orchid", "item_dagon"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Blink + spell burst synergy",
        reason_bad = "Right-click items don't fit QoP"
    },
    npc_dota_hero_lina = {
        good_items = {
            "item_aether_lens", "item_octarine_core", "item_sheepstick",
            "item_sphere", "item_black_king_bar", "item_aghanims_scepter",
            "item_dagon", "item_kaya_and_sange"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Spell amp + Laguna Blade burst",
        reason_bad = "BF doesn't fit Lina's magic burst"
    },
    npc_dota_hero_leshrac = {
        good_items = {
            "item_bloodstone", "item_black_king_bar", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_shivas_guard",
            "item_kaya_and_sange"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator"
        },
        reason_good = "Mana + spell amp for Leshrac",
        reason_bad = "Right-click items don't fit Leshrac"
    },
    npc_dota_hero_void_spirit = {
        good_items = {
            "item_blink", "item_aether_lens", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_arcane_blink",
            "item_kaya_and_sange", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Mobility + spell amp for Void Spirit",
        reason_bad = "Right-click items don't fit Void Spirit"
    },
    npc_dota_hero_obsidian_destroyer = {
        good_items = {
            "item_aether_lens", "item_octarine_core", "item_sheepstick",
            "item_sphere", "item_black_king_bar", "item_aghanims_scepter",
            "item_refresher", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_mjollnir"
        },
        reason_good = "Int + spell amp for Arcane Orb",
        reason_bad = "Attack speed items don't scale with Arcane Orb"
    },
    -- ══════════════ Offlane Heroes ══════════════
    npc_dota_hero_axe = {
        good_items = {
            "item_vanguard", "item_blink", "item_blade_mail", "item_black_king_bar",
            "item_shivas_guard", "item_heart", "item_overwhelming_blink",
            "item_crimson_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Counter Helix synergy",
        reason_bad = "DPS items don't fit Axe's tank role"
    },
    npc_dota_hero_tidehunter = {
        good_items = {
            "item_vanguard", "item_pipe", "item_crimson_guard", "item_shivas_guard",
            "item_heart", "item_blink", "item_refresher", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Ravage initiation",
        reason_bad = "DPS items don't fit Tide's tank role"
    },
    npc_dota_hero_bristleback = {
        good_items = {
            "item_vanguard", "item_blade_mail", "item_crimson_guard",
            "item_shivas_guard", "item_heart", "item_spirit_vessel",
            "item_holy_locket", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Quill Spray synergy",
        reason_bad = "DPS items don't fit BB's tank role"
    },
    npc_dota_hero_mars = {
        good_items = {
            "item_vanguard", "item_blink", "item_black_king_bar",
            "item_shivas_guard", "item_heart", "item_overwhelming_blink",
            "item_desolator", "item_assault"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Initiation + Arena synergy",
        reason_bad = "BF doesn't fit Mars's spell-based style"
    },
    npc_dota_hero_centaur = {
        good_items = {
            "item_vanguard", "item_blink", "item_blade_mail", "item_black_king_bar",
            "item_heart", "item_overwhelming_blink", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Double Edge synergy",
        reason_bad = "DPS items don't fit Centaur's tank role"
    },
    npc_dota_hero_legion_commander = {
        good_items = {
            "item_vanguard", "item_blink", "item_blade_mail", "item_black_king_bar",
            "item_desolator", "item_abyssal_blade", "item_overwhelming_blink",
            "item_assault"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas", "item_mjollnir"
        },
        reason_good = "Blink + Duel damage stacking",
        reason_bad = "Radiance doesn't fit LC's duel style"
    },
    npc_dota_hero_doom_bringer = {
        good_items = {
            "item_vanguard", "item_blink", "item_shivas_guard", "item_heart",
            "item_overwhelming_blink", "item_refresher", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Doom disable",
        reason_bad = "DPS items don't fit Doom's utility role"
    },
    npc_dota_hero_sand_king = {
        good_items = {
            "item_blink", "item_black_king_bar", "item_shivas_guard",
            "item_heart", "item_overwhelming_blink", "item_refresher",
            "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Blink + Epicenter initiation",
        reason_bad = "DPS items don't fit SK's initiator role"
    },
    npc_dota_hero_dark_seer = {
        good_items = {
            "item_vanguard", "item_blink", "item_shivas_guard", "item_heart",
            "item_refresher", "item_aghanims_scepter", "item_octarine_core"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Wall of Replica synergy",
        reason_bad = "DPS items don't fit DS's utility role"
    },
    npc_dota_hero_batrider = {
        good_items = {
            "item_blink", "item_black_king_bar", "item_shivas_guard",
            "item_heart", "item_overwhelming_blink", "item_sphere",
            "item_force_staff"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Blink + Lasso initiation",
        reason_bad = "DPS items don't fit Batrider's initiator role"
    },
    npc_dota_hero_pangolier = {
        good_items = {
            "item_maelstrom", "item_mjollnir", "item_black_king_bar",
            "item_blink", "item_satanic", "item_abyssal_blade",
            "item_swift_blink", "item_monkey_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + Rolling Thunder synergy",
        reason_bad = "BF doesn't fit Pangolier's style"
    },
    -- ══════════════ Support Heroes ══════════════
    npc_dota_hero_lion = {
        good_items = {
            "item_aether_lens", "item_blink", "item_aghanims_scepter",
            "item_octarine_core", "item_dagon", "item_sphere",
            "item_arcane_blink"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Finger burst",
        reason_bad = "DPS items don't fit Lion's support role"
    },
    npc_dota_hero_shadow_shaman = {
        good_items = {
            "item_aether_lens", "item_blink", "item_aghanims_scepter",
            "item_octarine_core", "item_refresher", "item_sphere",
            "item_arcane_blink"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Wards push",
        reason_bad = "DPS items don't fit Shaman's support role"
    },
    npc_dota_hero_crystal_maiden = {
        good_items = {
            "item_aether_lens", "item_blink", "item_black_king_bar",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_glimmer_cape"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Freezing Field",
        reason_bad = "DPS items don't fit CM's support role"
    },
    npc_dota_hero_dazzle = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_force_staff",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_holy_locket"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Heal amp + save items",
        reason_bad = "DPS items don't fit Dazzle's support role"
    },
    npc_dota_hero_oracle = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_force_staff",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_holy_locket", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Heal amp + save items",
        reason_bad = "DPS items don't fit Oracle's support role"
    },
    npc_dota_hero_witch_doctor = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_black_king_bar",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_dagon"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Death Ward",
        reason_bad = "DPS items don't fit WD's support role"
    },
    npc_dota_hero_warlock = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_aghanims_scepter",
            "item_octarine_core", "item_refresher", "item_sphere"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Golem push",
        reason_bad = "DPS items don't fit Warlock's support role"
    },
    npc_dota_hero_ancient_apparition = {
        good_items = {
            "item_aether_lens", "item_aghanims_scepter", "item_octarine_core",
            "item_sphere", "item_shivas_guard", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Ice Blast global",
        reason_bad = "DPS items don't fit AA's support role"
    },
}

--------------------------------------------------------------------------------
-- HERO COUNTER ITEMS (предметы против конкретных героев)
--------------------------------------------------------------------------------
local HERO_COUNTERS = {
    -- Anti-escape / Anti-invis
    npc_dota_hero_spectre = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier", "item_radiance"},
        reason = "Anti-heal + disarm vs low HP"
    },
    npc_dota_hero_medusa = {
        items = {"item_nullifier", "item_silver_edge", "item_abyssal_blade"},
        reason = "Break + disable vs mana shield"
    },
    npc_dota_hero_bristleback = {
        items = {"item_silver_edge", "item_abyssal_blade", "item_heavens_halberd"},
        reason = "Break passive + disarm"
    },
    npc_dota_hero_phantom_assassin = {
        items = {"item_monkey_king_bar", "item_heavens_halberd", "item_spirit_vessel"},
        reason = "True strike + disarm + anti-heal"
    },
    npc_dota_hero_juggernaut = {
        items = {"item_heavens_halberd", "item_abyssal_blade", "item_spirit_vessel"},
        reason = "Disarm vs omnislash + anti-heal"
    },
    npc_dota_hero_faceless_void = {
        items = {"item_aeon_disk", "item_sphere", "item_heavens_halberd"},
        reason = "Save from chrono + disarm"
    },
    npc_dota_hero_terrorblade = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + disarm vs illusions"
    },
    npc_dota_hero_slark = {
        items = {"item_heavens_halberd", "item_nullifier", "item_spirit_vessel"},
        reason = "Disarm + anti-heal vs agility steal"
    },
    npc_dota_hero_weaver = {
        items = {"item_nullifier", "item_spirit_vessel", "item_heavens_halberd"},
        reason = "Prevent escape + anti-heal"
    },
    npc_dota_hero_antimage = {
        items = {"item_nullifier", "item_heavens_halberd", "item_spirit_vessel"},
        reason = "Prevent blink escape + anti-heal"
    },
    -- Anti-blink / Anti-initiation
    npc_dota_hero_magnataur = {
        items = {"item_sphere", "item_aeon_disk", "item_heavens_halberd"},
        reason = "Block RP + disarm after"
    },
    npc_dota_hero_tidehunter = {
        items = {"item_sphere", "item_aeon_disk", "item_heavens_halberd"},
        reason = "Block ravage + disarm"
    },
    npc_dota_hero_enigma = {
        items = {"item_sphere", "item_aeon_disk", "item_nullifier"},
        reason = "Block black hole + purge"
    },
    npc_dota_hero_legion_commander = {
        items = {"item_sphere", "item_heavens_halberd", "item_spirit_vessel"},
        reason = "Block duel + disarm"
    },
    npc_dota_hero_axe = {
        items = {"item_heavens_halberd", "item_spirit_vessel", "item_blade_mail"},
        reason = "Disarm + anti-heal vs counter helix"
    },
    -- Anti-summon / Anti-illusions
    npc_dota_hero_phantom_lancer = {
        items = {"item_mjollnir", "item_radiance", "item_abyssal_blade"},
        reason = "AOE clear + bash vs illusions"
    },
    npc_dota_hero_naga_siren = {
        items = {"item_mjollnir", "item_radiance", "item_nullifier"},
        reason = "AOE vs illusions + purge"
    },
    npc_dota_hero_chaos_knight = {
        items = {"item_mjollnir", "item_heavens_halberd", "item_abyssal_blade"},
        reason = "AOE + disarm vs illusions"
    },
    npc_dota_hero_lycan = {
        items = {"item_mjollnir", "item_heavens_halberd", "item_assault"},
        reason = "AOE + armor vs wolves"
    },
    npc_dota_hero_broodmother = {
        items = {"item_mjollnir", "item_radiance", "item_nullifier"},
        reason = "AOE clear + purge spiders"
    },
    npc_dota_hero_furion = {
        items = {"item_mjollnir", "item_radiance", "item_assault"},
        reason = "AOE vs treants"
    },
    npc_dota_hero_warlock = {
        items = {"item_spirit_vessel", "item_mjollnir", "item_heavens_halberd"},
        reason = "Anti-heal + AOE vs golem"
    },
    npc_dota_hero_beastmaster = {
        items = {"item_mjollnir", "item_heavens_halberd", "item_assault"},
        reason = "AOE + armor vs hawk + boar"
    },
    -- Anti-magic burst
    npc_dota_hero_lina = {
        items = {"item_pipe", "item_black_king_bar", "item_sphere"},
        reason = "Magic defense + spell block"
    },
    npc_dota_hero_zuus = {
        items = {"item_pipe", "item_black_king_bar", "item_sphere"},
        reason = "Magic defense vs global ult"
    },
    npc_dota_hero_invoker = {
        items = {"item_black_king_bar", "item_sphere", "item_nullifier"},
        reason = "Magic immunity + purge"
    },
    npc_dota_hero_lion = {
        items = {"item_sphere", "item_aeon_disk", "item_black_king_bar"},
        reason = "Block hex + finger"
    },
    npc_dota_hero_shadow_shaman = {
        items = {"item_sphere", "item_aeon_disk", "item_black_king_bar"},
        reason = "Block hex + shackles"
    },
    npc_dota_hero_skywrath_mage = {
        items = {"item_pipe", "item_black_king_bar", "item_sphere"},
        reason = "Magic defense vs ult"
    },
    -- Anti-sustain
    npc_dota_hero_dragon_knight = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_assault"},
        reason = "Anti-heal + armor reduction"
    },
    npc_dota_hero_alchemist = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + disarm"
    },
    npc_dota_hero_huskar = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + disarm"
    },
    npc_dota_hero_necrolyte = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + purge"
    },
    npc_dota_hero_omniknight = {
        items = {"item_spirit_vessel", "item_nullifier", "item_silver_edge"},
        reason = "Anti-heal + break"
    },
    npc_dota_hero_chen = {
        items = {"item_spirit_vessel", "item_mjollnir", "item_nullifier"},
        reason = "Anti-heal + AOE vs creeps"
    },
    npc_dota_hero_dazzle = {
        items = {"item_spirit_vessel", "item_nullifier", "item_silver_edge"},
        reason = "Anti-heal + break vs save"
    },
    npc_dota_hero_witch_doctor = {
        items = {"item_spirit_vessel", "item_black_king_bar", "item_sphere"},
        reason = "Anti-heal + magic immunity"
    },
    -- Anti-carry late game
    npc_dota_hero_sven = {
        items = {"item_heavens_halberd", "item_assault", "item_spirit_vessel"},
        reason = "Disarm + armor vs god strength"
    },
    npc_dota_hero_troll_warlord = {
        items = {"item_heavens_halberd", "item_spirit_vessel", "item_nullifier"},
        reason = "Disarm + anti-heal"
    },
    npc_dota_hero_ursa = {
        items = {"item_heavens_halberd", "item_spirit_vessel", "item_blade_mail"},
        reason = "Disarm + reflect fury swipes"
    },
    npc_dota_hero_luna = {
        items = {"item_heavens_halberd", "item_assault", "item_black_king_bar"},
        reason = "Disarm + armor vs glaives"
    },
    npc_dota_hero_sniper = {
        items = {"item_blink", "item_black_king_bar", "item_nullifier"},
        reason = "Gap close + magic immunity"
    },
    npc_dota_hero_drow_ranger = {
        items = {"item_blink", "item_black_king_bar", "item_heavens_halberd"},
        reason = "Gap close + disarm"
    },
}

local HERO_COUNTERS_741D = {
    npc_dota_hero_antimage = {items={"item_orchid","item_bloodthorn","item_sheepstick","item_gungir","item_abyssal_blade"}, reason="Lock down blink and punish mana burn", priority={item_orchid=12,item_bloodthorn=14,item_sheepstick=15,item_gungir=11,item_abyssal_blade=10}},
    npc_dota_hero_arc_warden = {items={"item_blink","item_nullifier","item_sheepstick","item_mjollnir","item_crimson_guard"}, reason="Reach the real hero and clear doubles/summons", priority={item_blink=8,item_nullifier=12,item_sheepstick=13,item_mjollnir=9,item_crimson_guard=8}},
    npc_dota_hero_bloodseeker = {items={"item_cyclone","item_force_staff","item_lotus_orb","item_ghost","item_spirit_vessel"}, reason="Reset Rupture/Blood Rite and reduce sustain", priority={item_cyclone=12,item_force_staff=10,item_lotus_orb=11,item_ghost=8,item_spirit_vessel=8}},
    npc_dota_hero_bounty_hunter = {items={"item_dust","item_ward_sentry","item_force_staff","item_cyclone","item_lotus_orb"}, reason="Detection and dispel Track pressure", priority={item_dust=16,item_ward_sentry=14,item_lotus_orb=9,item_force_staff=7,item_cyclone=7}},
    npc_dota_hero_broodmother = {items={"item_maelstrom","item_mjollnir","item_shivas_guard","item_crimson_guard","item_dust"}, reason="Clear spiders and reveal web pressure", priority={item_maelstrom=11,item_mjollnir=13,item_shivas_guard=12,item_crimson_guard=9,item_dust=8}},
    npc_dota_hero_chaos_knight = {items={"item_mjollnir","item_shivas_guard","item_crimson_guard","item_heavens_halberd","item_ghost"}, reason="Illusion clear and disarm burst", priority={item_mjollnir=15,item_shivas_guard=13,item_crimson_guard=12,item_heavens_halberd=10,item_ghost=8}},
    npc_dota_hero_clinkz = {items={"item_dust","item_ward_sentry","item_ghost","item_force_staff","item_heavens_halberd"}, reason="Detection plus kite physical burst", priority={item_dust=16,item_ward_sentry=14,item_ghost=9,item_force_staff=8,item_heavens_halberd=9}},
    npc_dota_hero_drow_ranger = {items={"item_blink","item_heavens_halberd","item_ghost","item_crimson_guard","item_assault"}, reason="Close distance and reduce ranged physical damage", priority={item_blink=10,item_heavens_halberd=13,item_ghost=9,item_crimson_guard=8,item_assault=8}},
    npc_dota_hero_faceless_void = {items={"item_aeon_disk","item_wind_waker","item_force_staff","item_ghost","item_sphere"}, reason="Survive or reset Chronosphere", priority={item_aeon_disk=16,item_wind_waker=15,item_force_staff=9,item_ghost=9,item_sphere=7}},
    npc_dota_hero_gyrocopter = {items={"item_pipe","item_mage_slayer","item_crimson_guard","item_heavens_halberd","item_assault"}, reason="Layer magic and physical mitigation", priority={item_pipe=10,item_mage_slayer=9,item_crimson_guard=10,item_heavens_halberd=8,item_assault=7}},
    npc_dota_hero_juggernaut = {items={"item_ghost","item_cyclone","item_heavens_halberd","item_abyssal_blade","item_spirit_vessel"}, reason="Dodge Omnislash and punish Healing Ward sustain", priority={item_ghost=14,item_cyclone=13,item_heavens_halberd=10,item_abyssal_blade=9,item_spirit_vessel=8}},
    npc_dota_hero_kez = {items={"item_ghost","item_heavens_halberd","item_sheepstick","item_bloodthorn","item_crimson_guard"}, reason="Kite burst windows and stop mobility chains", priority={item_ghost=10,item_heavens_halberd=12,item_sheepstick=12,item_bloodthorn=10,item_crimson_guard=8}},
    npc_dota_hero_life_stealer = {items={"item_heavens_halberd","item_skadi","item_spirit_vessel","item_ghost","item_sheepstick"}, reason="Disarm Rage downtime and cut lifesteal", priority={item_heavens_halberd=13,item_skadi=11,item_spirit_vessel=10,item_ghost=8,item_sheepstick=10}},
    npc_dota_hero_luna = {items={"item_crimson_guard","item_assault","item_heavens_halberd","item_pipe","item_butterfly"}, reason="Mitigate glaives and Eclipse", priority={item_crimson_guard=11,item_assault=9,item_heavens_halberd=11,item_pipe=8,item_butterfly=7}},
    npc_dota_hero_medusa = {items={"item_diffusal_blade","item_disperser","item_skadi","item_sheepstick","item_bloodthorn"}, reason="Mana pressure and hard control through tankiness", priority={item_diffusal_blade=14,item_disperser=15,item_skadi=9,item_sheepstick=10,item_bloodthorn=8}},
    npc_dota_hero_meepo = {items={"item_shivas_guard","item_mjollnir","item_crimson_guard","item_ghost","item_aeon_disk"}, reason="AoE control and survival against Poof burst", priority={item_shivas_guard=14,item_mjollnir=12,item_crimson_guard=10,item_ghost=9,item_aeon_disk=10}},
    npc_dota_hero_morphling = {items={"item_spirit_vessel","item_skadi","item_sheepstick","item_orchid","item_bloodthorn"}, reason="Cut attribute-shift sustain and lock mobility", priority={item_spirit_vessel=14,item_skadi=12,item_sheepstick=13,item_orchid=10,item_bloodthorn=12}},
    npc_dota_hero_naga_siren = {items={"item_mjollnir","item_shivas_guard","item_crimson_guard","item_gungir","item_battlefury"}, reason="Illusion clear and root the real hero", priority={item_mjollnir=16,item_shivas_guard=13,item_crimson_guard=12,item_gungir=10,item_battlefury=8}},
    npc_dota_hero_phantom_assassin = {items={"item_monkey_king_bar","item_bloodthorn","item_heavens_halberd","item_ghost","item_crimson_guard"}, reason="True strike and physical burst protection", priority={item_monkey_king_bar=16,item_bloodthorn=14,item_heavens_halberd=12,item_ghost=10,item_crimson_guard=8}},
    npc_dota_hero_phantom_lancer = {items={"item_maelstrom","item_mjollnir","item_shivas_guard","item_crimson_guard","item_battlefury"}, reason="Illusion clear before he overwhelms fights", priority={item_maelstrom=14,item_mjollnir=16,item_shivas_guard=13,item_crimson_guard=12,item_battlefury=8}},
    npc_dota_hero_riki = {items={"item_dust","item_ward_sentry","item_force_staff","item_gungir","item_ghost"}, reason="Detection and escape from Smoke Screen", priority={item_dust=17,item_ward_sentry=15,item_force_staff=11,item_gungir=9,item_ghost=8}},
    npc_dota_hero_slark = {items={"item_force_staff","item_ghost","item_heavens_halberd","item_bloodthorn","item_spirit_vessel"}, reason="Break leash pressure and punish sustain", priority={item_force_staff=13,item_ghost=11,item_heavens_halberd=12,item_bloodthorn=10,item_spirit_vessel=9}},
    npc_dota_hero_sniper = {items={"item_blink","item_hurricane_pike","item_force_staff","item_ghost","item_heavens_halberd"}, reason="Close or create distance against long range", priority={item_blink=13,item_hurricane_pike=11,item_force_staff=9,item_ghost=8,item_heavens_halberd=9}},
    npc_dota_hero_spectre = {items={"item_spirit_vessel","item_silver_edge","item_shivas_guard","item_crimson_guard","item_heavens_halberd"}, reason="Reduce sustain and survive Haunt damage", priority={item_spirit_vessel=11,item_silver_edge=12,item_shivas_guard=10,item_crimson_guard=10,item_heavens_halberd=8}},
    npc_dota_hero_sven = {items={"item_ghost","item_heavens_halberd","item_crimson_guard","item_butterfly","item_force_staff"}, reason="Kite God's Strength burst", priority={item_ghost=13,item_heavens_halberd=14,item_crimson_guard=10,item_butterfly=8,item_force_staff=8}},
    npc_dota_hero_templar_assassin = {items={"item_dust","item_monkey_king_bar","item_bloodthorn","item_heavens_halberd","item_shivas_guard"}, reason="Reveal Meld and fight through evasion/refraction", priority={item_dust=11,item_monkey_king_bar=12,item_bloodthorn=11,item_heavens_halberd=9,item_shivas_guard=8}},
    npc_dota_hero_terrorblade = {items={"item_mjollnir","item_shivas_guard","item_crimson_guard","item_heavens_halberd","item_spirit_vessel"}, reason="Illusion clear and stop Sunder windows", priority={item_mjollnir=15,item_shivas_guard=13,item_crimson_guard=12,item_heavens_halberd=10,item_spirit_vessel=9}},
    npc_dota_hero_troll_warlord = {items={"item_heavens_halberd","item_ghost","item_cyclone","item_skadi","item_sheepstick"}, reason="Disarm or reset Battle Trance", priority={item_heavens_halberd=16,item_ghost=12,item_cyclone=11,item_skadi=9,item_sheepstick=10}},
    npc_dota_hero_ursa = {items={"item_ghost","item_heavens_halberd","item_force_staff","item_cyclone","item_spirit_vessel"}, reason="Kite Fury Swipes and cut Roshan sustain", priority={item_ghost=14,item_heavens_halberd=13,item_force_staff=11,item_cyclone=10,item_spirit_vessel=9}},
    npc_dota_hero_weaver = {items={"item_dust","item_gungir","item_bloodthorn","item_sheepstick","item_nullifier"}, reason="Detection, root and stop Time Lapse saves", priority={item_dust=15,item_gungir=12,item_bloodthorn=12,item_sheepstick=13,item_nullifier=10}},

    npc_dota_hero_axe = {items={"item_lotus_orb","item_aeon_disk","item_ghost","item_force_staff","item_spirit_vessel"}, reason="Survive Call/Blade Mail and reduce regen", priority={item_lotus_orb=12,item_aeon_disk=11,item_ghost=10,item_force_staff=8,item_spirit_vessel=7}},
    npc_dota_hero_batrider = {items={"item_sphere","item_lotus_orb","item_force_staff","item_hurricane_pike","item_black_king_bar"}, reason="Block or break Flaming Lasso initiation", priority={item_sphere=16,item_lotus_orb=13,item_force_staff=10,item_hurricane_pike=9,item_black_king_bar=8}},
    npc_dota_hero_beastmaster = {items={"item_sphere","item_lotus_orb","item_crimson_guard","item_mjollnir","item_force_staff"}, reason="Block Roar and control summons", priority={item_sphere=15,item_lotus_orb=12,item_crimson_guard=10,item_mjollnir=9,item_force_staff=8}},
    npc_dota_hero_brewmaster = {items={"item_black_king_bar","item_orchid","item_bloodthorn","item_sheepstick","item_nullifier"}, reason="Stop Split setup or purge cyclone saves", priority={item_black_king_bar=8,item_orchid=10,item_bloodthorn=12,item_sheepstick=12,item_nullifier=9}},
    npc_dota_hero_bristleback = {items={"item_silver_edge","item_spirit_vessel","item_skadi","item_shivas_guard","item_heavens_halberd"}, reason="Break passive and reduce Quill/sustain", priority={item_silver_edge=16,item_spirit_vessel=12,item_skadi=10,item_shivas_guard=9,item_heavens_halberd=8}},
    npc_dota_hero_centaur = {items={"item_spirit_vessel","item_silver_edge","item_shivas_guard","item_pipe","item_force_staff"}, reason="Reduce tank sustain and reset initiation", priority={item_spirit_vessel=10,item_silver_edge=9,item_shivas_guard=9,item_pipe=8,item_force_staff=7}},
    npc_dota_hero_dark_seer = {items={"item_pipe","item_black_king_bar","item_lotus_orb","item_shivas_guard","item_mjollnir"}, reason="Mitigate Wall/Vacuum magic and illusions", priority={item_pipe=12,item_black_king_bar=10,item_lotus_orb=8,item_shivas_guard=9,item_mjollnir=8}},
    npc_dota_hero_doom_bringer = {items={"item_sphere","item_lotus_orb","item_aeon_disk","item_black_king_bar","item_force_staff"}, reason="Block Doom or buy time after initiation", priority={item_sphere=18,item_lotus_orb=14,item_aeon_disk=13,item_black_king_bar=9,item_force_staff=8}},
    npc_dota_hero_dragon_knight = {items={"item_spirit_vessel","item_silver_edge","item_skadi","item_shivas_guard","item_assault"}, reason="Cut regen and armor tankiness", priority={item_spirit_vessel=11,item_silver_edge=11,item_skadi=9,item_shivas_guard=8,item_assault=7}},
    npc_dota_hero_earthshaker = {items={"item_black_king_bar","item_aeon_disk","item_force_staff","item_pipe","item_sphere"}, reason="Survive chain stuns and Echo burst", priority={item_black_king_bar=13,item_aeon_disk=12,item_force_staff=8,item_pipe=9,item_sphere=7}},
    npc_dota_hero_elder_titan = {items={"item_force_staff","item_ghost","item_black_king_bar","item_assault","item_crimson_guard"}, reason="Respect armor removal and long control", priority={item_force_staff=8,item_ghost=8,item_black_king_bar=10,item_assault=8,item_crimson_guard=7}},
    npc_dota_hero_enigma = {items={"item_black_king_bar","item_aeon_disk","item_wind_waker","item_force_staff","item_sphere"}, reason="Prevent or survive Black Hole", priority={item_black_king_bar=12,item_aeon_disk=16,item_wind_waker=15,item_force_staff=10,item_sphere=7}},
    npc_dota_hero_kunkka = {items={"item_black_king_bar","item_lotus_orb","item_force_staff","item_pipe","item_ghost"}, reason="Dispel X/rum burst and kite cleave", priority={item_black_king_bar=11,item_lotus_orb=10,item_force_staff=8,item_pipe=8,item_ghost=7}},
    npc_dota_hero_legion_commander = {items={"item_sphere","item_lotus_orb","item_aeon_disk","item_heavens_halberd","item_ghost"}, reason="Block Duel or prevent burst during Duel", priority={item_sphere=18,item_lotus_orb=14,item_aeon_disk=13,item_heavens_halberd=10,item_ghost=9}},
    npc_dota_hero_magnataur = {items={"item_black_king_bar","item_aeon_disk","item_force_staff","item_sphere","item_lotus_orb"}, reason="Survive RP/Skewer initiation", priority={item_black_king_bar=12,item_aeon_disk=14,item_force_staff=10,item_sphere=7,item_lotus_orb=8}},
    npc_dota_hero_mars = {items={"item_black_king_bar","item_force_staff","item_lotus_orb","item_ghost","item_heavens_halberd"}, reason="Escape Arena/Spear and reduce physical follow-up", priority={item_black_king_bar=11,item_force_staff=12,item_lotus_orb=9,item_ghost=8,item_heavens_halberd=7}},
    npc_dota_hero_night_stalker = {items={"item_force_staff","item_ghost","item_heavens_halberd","item_black_king_bar","item_glimmer_cape"}, reason="Escape silence dive and night chase", priority={item_force_staff=12,item_ghost=11,item_heavens_halberd=10,item_black_king_bar=9,item_glimmer_cape=8}},
    npc_dota_hero_pangolier = {items={"item_black_king_bar","item_sphere","item_force_staff","item_bloodthorn","item_sheepstick"}, reason="Stop Rolling Thunder chain control", priority={item_black_king_bar=11,item_sphere=8,item_force_staff=9,item_bloodthorn=10,item_sheepstick=11}},
    npc_dota_hero_primal_beast = {items={"item_black_king_bar","item_force_staff","item_ghost","item_heavens_halberd","item_aeon_disk"}, reason="Kite trample burst and Pulverize", priority={item_black_king_bar=11,item_force_staff=12,item_ghost=9,item_heavens_halberd=8,item_aeon_disk=9}},
    npc_dota_hero_pudge = {items={"item_force_staff","item_hurricane_pike","item_lotus_orb","item_sphere","item_spirit_vessel"}, reason="Break Hook/Dismember and cut tank sustain", priority={item_force_staff=14,item_hurricane_pike=10,item_lotus_orb=11,item_sphere=12,item_spirit_vessel=8}},
    npc_dota_hero_sand_king = {items={"item_black_king_bar","item_dust","item_ward_sentry","item_pipe","item_aeon_disk"}, reason="Detection plus magic burst protection", priority={item_black_king_bar=11,item_dust=12,item_ward_sentry=10,item_pipe=10,item_aeon_disk=8}},
    npc_dota_hero_slardar = {items={"item_lotus_orb","item_heavens_halberd","item_ghost","item_assault","item_crimson_guard"}, reason="Dispel Corrosive Haze and reduce bash damage", priority={item_lotus_orb=13,item_heavens_halberd=11,item_ghost=9,item_assault=8,item_crimson_guard=8}},
    npc_dota_hero_spirit_breaker = {items={"item_lotus_orb","item_sphere","item_force_staff","item_ghost","item_heavens_halberd"}, reason="Reflect/block Charge and kite bash chain", priority={item_lotus_orb=12,item_sphere=10,item_force_staff=9,item_ghost=8,item_heavens_halberd=8}},
    npc_dota_hero_tidehunter = {items={"item_black_king_bar","item_aeon_disk","item_force_staff","item_pipe","item_lotus_orb"}, reason="Survive Ravage and Anchor Smash teamfights", priority={item_black_king_bar=12,item_aeon_disk=12,item_force_staff=8,item_pipe=8,item_lotus_orb=7}},
    npc_dota_hero_tiny = {items={"item_ghost","item_force_staff","item_heavens_halberd","item_crimson_guard","item_aeon_disk"}, reason="Respect Avalanche/Toss physical burst", priority={item_ghost=12,item_force_staff=10,item_heavens_halberd=9,item_crimson_guard=9,item_aeon_disk=10}},
    npc_dota_hero_abyssal_underlord = {items={"item_black_king_bar","item_pipe","item_force_staff","item_shivas_guard","item_nullifier"}, reason="Mitigate Pit/Firestorm and punish saves", priority={item_black_king_bar=10,item_pipe=10,item_force_staff=8,item_shivas_guard=7,item_nullifier=7}},

    npc_dota_hero_invoker = {items={"item_black_king_bar","item_pipe","item_mage_slayer","item_sphere","item_lotus_orb"}, reason="Reduce spell combos and block key disables", priority={item_black_king_bar=14,item_pipe=11,item_mage_slayer=10,item_sphere=9,item_lotus_orb=8}},
    npc_dota_hero_leshrac = {items={"item_pipe","item_mage_slayer","item_black_king_bar","item_spirit_vessel","item_shivas_guard"}, reason="Magic mitigation and anti-heal vs spell sustain", priority={item_pipe=15,item_mage_slayer=13,item_black_king_bar=11,item_spirit_vessel=9,item_shivas_guard=8}},
    npc_dota_hero_lina = {items={"item_black_king_bar","item_pipe","item_mage_slayer","item_sphere","item_aeon_disk"}, reason="Survive Laguna and magic/physical burst", priority={item_black_king_bar=13,item_pipe=10,item_mage_slayer=10,item_sphere=10,item_aeon_disk=9}},
    npc_dota_hero_nevermore = {items={"item_black_king_bar","item_pipe","item_ghost","item_assault","item_heavens_halberd"}, reason="Answer mixed burst and armor reduction", priority={item_black_king_bar=11,item_pipe=9,item_ghost=8,item_assault=8,item_heavens_halberd=8}},
    npc_dota_hero_obsidian_destroyer = {items={"item_black_king_bar","item_mage_slayer","item_sphere","item_lotus_orb","item_pipe"}, reason="Block Astral/Sanity burst and reduce magic output", priority={item_black_king_bar=13,item_mage_slayer=11,item_sphere=11,item_lotus_orb=9,item_pipe=8}},
    npc_dota_hero_puck = {items={"item_orchid","item_bloodthorn","item_sheepstick","item_rod_of_atos","item_black_king_bar"}, reason="Silence or hard-control elusive spell burst", priority={item_orchid=14,item_bloodthorn=15,item_sheepstick=15,item_rod_of_atos=10,item_black_king_bar=9}},
    npc_dota_hero_queenofpain = {items={"item_orchid","item_bloodthorn","item_sheepstick","item_black_king_bar","item_pipe"}, reason="Silence mobility and reduce magic burst", priority={item_orchid=13,item_bloodthorn=14,item_sheepstick=13,item_black_king_bar=10,item_pipe=8}},
    npc_dota_hero_storm_spirit = {items={"item_orchid","item_bloodthorn","item_sheepstick","item_rod_of_atos","item_black_king_bar"}, reason="Lock Ball Lightning and survive pickoffs", priority={item_orchid=15,item_bloodthorn=16,item_sheepstick=15,item_rod_of_atos=10,item_black_king_bar=9}},
    npc_dota_hero_tinker = {items={"item_black_king_bar","item_pipe","item_mage_slayer","item_blink","item_orchid"}, reason="Reach him and reduce spell spam", priority={item_black_king_bar=12,item_pipe=11,item_mage_slayer=10,item_blink=9,item_orchid=10}},
    npc_dota_hero_void_spirit = {items={"item_orchid","item_bloodthorn","item_sheepstick","item_black_king_bar","item_pipe"}, reason="Silence mobility and survive magic burst", priority={item_orchid=13,item_bloodthorn=14,item_sheepstick=13,item_black_king_bar=10,item_pipe=8}},
    npc_dota_hero_zuus = {items={"item_pipe","item_mage_slayer","item_black_king_bar","item_glimmer_cape","item_sphere"}, reason="Layer magic resistance against global burst", priority={item_pipe=15,item_mage_slayer=11,item_black_king_bar=10,item_glimmer_cape=9,item_sphere=8}},

    npc_dota_hero_abaddon = {items={"item_spirit_vessel","item_nullifier","item_skadi","item_shivas_guard","item_silver_edge"}, reason="Purge saves and cut healing", priority={item_spirit_vessel=12,item_nullifier=14,item_skadi=10,item_shivas_guard=9,item_silver_edge=8}},
    npc_dota_hero_ancient_apparition = {items={"item_pipe","item_black_king_bar","item_force_staff","item_glimmer_cape","item_sphere"}, reason="Avoid Ice Blast follow-up and magic burst", priority={item_pipe=10,item_black_king_bar=10,item_force_staff=8,item_glimmer_cape=8,item_sphere=8}},
    npc_dota_hero_bane = {items={"item_sphere","item_lotus_orb","item_cyclone","item_black_king_bar","item_aeon_disk"}, reason="Block Nightmare/Fiend's Grip pickoffs", priority={item_sphere=15,item_lotus_orb=12,item_cyclone=9,item_black_king_bar=10,item_aeon_disk=9}},
    npc_dota_hero_chen = {items={"item_spirit_vessel","item_nullifier","item_mjollnir","item_crimson_guard","item_shivas_guard"}, reason="Anti-heal and summon clear", priority={item_spirit_vessel=13,item_nullifier=10,item_mjollnir=10,item_crimson_guard=9,item_shivas_guard=8}},
    npc_dota_hero_crystal_maiden = {items={"item_black_king_bar","item_pipe","item_force_staff","item_glimmer_cape","item_mage_slayer"}, reason="Reduce root/Freezing Field magic damage", priority={item_black_king_bar=10,item_pipe=9,item_force_staff=8,item_glimmer_cape=8,item_mage_slayer=7}},
    npc_dota_hero_dark_willow = {items={"item_black_king_bar","item_pipe","item_force_staff","item_cyclone","item_orchid"}, reason="Handle fear/root magic control", priority={item_black_king_bar=12,item_pipe=9,item_force_staff=9,item_cyclone=8,item_orchid=8}},
    npc_dota_hero_dazzle = {items={"item_nullifier","item_spirit_vessel","item_orchid","item_bloodthorn","item_shivas_guard"}, reason="Purge Shallow Grave and cut healing", priority={item_nullifier=16,item_spirit_vessel=13,item_orchid=9,item_bloodthorn=10,item_shivas_guard=8}},
    npc_dota_hero_death_prophet = {items={"item_spirit_vessel","item_skadi","item_pipe","item_mage_slayer","item_orchid"}, reason="Cut siphon sustain and magic pressure", priority={item_spirit_vessel=14,item_skadi=11,item_pipe=10,item_mage_slayer=9,item_orchid=8}},
    npc_dota_hero_disruptor = {items={"item_black_king_bar","item_force_staff","item_lotus_orb","item_sphere","item_glimmer_cape"}, reason="Escape Kinetic Field/Static Storm catches", priority={item_black_king_bar=12,item_force_staff=12,item_lotus_orb=10,item_sphere=8,item_glimmer_cape=7}},
    npc_dota_hero_enchantress = {items={"item_spirit_vessel","item_silver_edge","item_bloodthorn","item_pipe","item_mage_slayer"}, reason="Cut heal and break Untouchable-style survivability", priority={item_spirit_vessel=11,item_silver_edge=11,item_bloodthorn=9,item_pipe=7,item_mage_slayer=7}},
    npc_dota_hero_grimstroke = {items={"item_black_king_bar","item_lotus_orb","item_force_staff","item_pipe","item_glimmer_cape"}, reason="Dispel/survive silence and Soulbind setups", priority={item_black_king_bar=11,item_lotus_orb=10,item_force_staff=9,item_pipe=8,item_glimmer_cape=7}},
    npc_dota_hero_hoodwink = {items={"item_dust","item_force_staff","item_black_king_bar","item_pipe","item_lotus_orb"}, reason="Reveal evasive setup and escape Bushwhack", priority={item_dust=10,item_force_staff=11,item_black_king_bar=10,item_pipe=8,item_lotus_orb=8}},
    npc_dota_hero_jakiro = {items={"item_pipe","item_black_king_bar","item_force_staff","item_mage_slayer","item_glimmer_cape"}, reason="Magic mitigation and reposition from Ice Path", priority={item_pipe=12,item_black_king_bar=10,item_force_staff=9,item_mage_slayer=8,item_glimmer_cape=8}},
    npc_dota_hero_keeper_of_the_light = {items={"item_pipe","item_mage_slayer","item_black_king_bar","item_orchid","item_force_staff"}, reason="Reduce spell spam and catch channeling/caster play", priority={item_pipe=10,item_mage_slayer=9,item_black_king_bar=8,item_orchid=8,item_force_staff=7}},
    npc_dota_hero_lich = {items={"item_pipe","item_black_king_bar","item_force_staff","item_glimmer_cape","item_mage_slayer"}, reason="Magic mitigation and spacing vs Chain Frost", priority={item_pipe=11,item_black_king_bar=9,item_force_staff=10,item_glimmer_cape=8,item_mage_slayer=7}},
    npc_dota_hero_lion = {items={"item_sphere","item_lotus_orb","item_aeon_disk","item_black_king_bar","item_glimmer_cape"}, reason="Block Hex/Finger pickoffs", priority={item_sphere=15,item_lotus_orb=12,item_aeon_disk=11,item_black_king_bar=10,item_glimmer_cape=7}},
    npc_dota_hero_marci = {items={"item_ghost","item_force_staff","item_heavens_halberd","item_cyclone","item_crimson_guard"}, reason="Kite Unleash and jump burst", priority={item_ghost=12,item_force_staff=11,item_heavens_halberd=11,item_cyclone=9,item_crimson_guard=8}},
    npc_dota_hero_mirana = {items={"item_dust","item_ward_sentry","item_force_staff","item_black_king_bar","item_lotus_orb"}, reason="Detection and arrow/spell protection", priority={item_dust=11,item_ward_sentry=10,item_force_staff=8,item_black_king_bar=8,item_lotus_orb=8}},
    npc_dota_hero_muerta = {items={"item_black_king_bar","item_pipe","item_mage_slayer","item_ghost","item_heavens_halberd"}, reason="Handle mixed magic and right-click windows", priority={item_black_king_bar=12,item_pipe=10,item_mage_slayer=9,item_ghost=8,item_heavens_halberd=8}},
    npc_dota_hero_necrolyte = {items={"item_spirit_vessel","item_skadi","item_pipe","item_mage_slayer","item_sphere"}, reason="Cut healing and block Reaper setup", priority={item_spirit_vessel=15,item_skadi=11,item_pipe=9,item_mage_slayer=8,item_sphere=9}},
    npc_dota_hero_nyx_assassin = {items={"item_dust","item_ward_sentry","item_black_king_bar","item_pipe","item_sphere"}, reason="Detection plus Carapace/Mana Burn protection", priority={item_dust=15,item_ward_sentry=13,item_black_king_bar=9,item_pipe=8,item_sphere=8}},
    npc_dota_hero_ogre_magi = {items={"item_pipe","item_black_king_bar","item_lotus_orb","item_sphere","item_mage_slayer"}, reason="Reduce multicast disables and magic damage", priority={item_pipe=9,item_black_king_bar=9,item_lotus_orb=9,item_sphere=8,item_mage_slayer=7}},
    npc_dota_hero_omniknight = {items={"item_nullifier","item_spirit_vessel","item_skadi","item_shivas_guard","item_orchid"}, reason="Purge saves and cut healing", priority={item_nullifier=16,item_spirit_vessel=12,item_skadi=10,item_shivas_guard=9,item_orchid=8}},
    npc_dota_hero_oracle = {items={"item_nullifier","item_spirit_vessel","item_orchid","item_bloodthorn","item_sheepstick"}, reason="Stop False Promise save chains", priority={item_nullifier=16,item_spirit_vessel=12,item_orchid=11,item_bloodthorn=12,item_sheepstick=10}},
    npc_dota_hero_phoenix = {items={"item_pipe","item_mage_slayer","item_black_king_bar","item_spirit_vessel","item_assault"}, reason="Magic mitigation, anti-heal and attack speed for Egg", priority={item_pipe=11,item_mage_slayer=9,item_black_king_bar=9,item_spirit_vessel=10,item_assault=8}},
    npc_dota_hero_pugna = {items={"item_black_king_bar","item_pipe","item_mage_slayer","item_spirit_vessel","item_orchid"}, reason="Reduce Nether magic and Life Drain sustain", priority={item_black_king_bar=12,item_pipe=10,item_mage_slayer=9,item_spirit_vessel=9,item_orchid=8}},
    npc_dota_hero_ringmaster = {items={"item_black_king_bar","item_force_staff","item_pipe","item_lotus_orb","item_aeon_disk"}, reason="Survive control chains and forced positioning", priority={item_black_king_bar=11,item_force_staff=10,item_pipe=8,item_lotus_orb=8,item_aeon_disk=8}},
    npc_dota_hero_rubick = {items={"item_black_king_bar","item_lotus_orb","item_sphere","item_pipe","item_force_staff"}, reason="Reduce stolen-spell pickoffs and Telekinesis catches", priority={item_black_king_bar=9,item_lotus_orb=9,item_sphere=8,item_pipe=7,item_force_staff=7}},
    npc_dota_hero_shadow_demon = {items={"item_black_king_bar","item_lotus_orb","item_sphere","item_nullifier","item_mjollnir"}, reason="Block Disruption/Demonic Purge and clear illusions", priority={item_black_king_bar=9,item_lotus_orb=10,item_sphere=10,item_nullifier=8,item_mjollnir=7}},
    npc_dota_hero_shadow_shaman = {items={"item_sphere","item_lotus_orb","item_aeon_disk","item_black_king_bar","item_force_staff"}, reason="Block Hex/Shackles and survive ward traps", priority={item_sphere=15,item_lotus_orb=12,item_aeon_disk=10,item_black_king_bar=10,item_force_staff=8}},
    npc_dota_hero_silencer = {items={"item_manta","item_lotus_orb","item_black_king_bar","item_cyclone","item_disperser"}, reason="Dispel silence and keep casting through Global", priority={item_manta=13,item_lotus_orb=12,item_black_king_bar=11,item_cyclone=10,item_disperser=11}},
    npc_dota_hero_skywrath_mage = {items={"item_black_king_bar","item_pipe","item_glimmer_cape","item_force_staff","item_sphere"}, reason="Survive silence into Mystic Flare", priority={item_black_king_bar=14,item_pipe=11,item_glimmer_cape=10,item_force_staff=10,item_sphere=10}},
    npc_dota_hero_snapfire = {items={"item_pipe","item_black_king_bar","item_force_staff","item_mage_slayer","item_glimmer_cape"}, reason="Magic mitigation and spacing vs Kisses/Cookie", priority={item_pipe=11,item_black_king_bar=10,item_force_staff=9,item_mage_slayer=8,item_glimmer_cape=7}},
    npc_dota_hero_techies = {items={"item_pipe","item_black_king_bar","item_force_staff","item_glimmer_cape","item_mage_slayer"}, reason="Magic burst protection and reposition from mines", priority={item_pipe=12,item_black_king_bar=10,item_force_staff=9,item_glimmer_cape=8,item_mage_slayer=8}},
    npc_dota_hero_treant = {items={"item_dust","item_ward_sentry","item_lotus_orb","item_black_king_bar","item_force_staff"}, reason="Detection and Overgrowth dispel/reposition", priority={item_dust=12,item_ward_sentry=11,item_lotus_orb=10,item_black_king_bar=9,item_force_staff=8}},
    npc_dota_hero_tusk = {items={"item_force_staff","item_ghost","item_black_king_bar","item_lotus_orb","item_heavens_halberd"}, reason="Escape Snowball/Walrus burst and save allies", priority={item_force_staff=12,item_ghost=10,item_black_king_bar=9,item_lotus_orb=8,item_heavens_halberd=8}},
    npc_dota_hero_undying = {items={"item_spirit_vessel","item_shivas_guard","item_pipe","item_mjollnir","item_crimson_guard"}, reason="Cut healing and clear Tombstone pressure", priority={item_spirit_vessel=14,item_shivas_guard=10,item_pipe=8,item_mjollnir=8,item_crimson_guard=8}},
    npc_dota_hero_vengefulspirit = {items={"item_lotus_orb","item_sphere","item_force_staff","item_ghost","item_heavens_halberd"}, reason="Reflect/block swap stun and reduce right-click aura", priority={item_lotus_orb=11,item_sphere=10,item_force_staff=9,item_ghost=7,item_heavens_halberd=7}},
    npc_dota_hero_venomancer = {items={"item_pipe","item_black_king_bar","item_force_staff","item_lotus_orb","item_mage_slayer"}, reason="Mitigate poison and dispel slows", priority={item_pipe=13,item_black_king_bar=10,item_force_staff=9,item_lotus_orb=8,item_mage_slayer=8}},
    npc_dota_hero_visage = {items={"item_crimson_guard","item_mjollnir","item_assault","item_spirit_vessel","item_shivas_guard"}, reason="Handle familiars and gravekeeper sustain", priority={item_crimson_guard=10,item_mjollnir=9,item_assault=8,item_spirit_vessel=8,item_shivas_guard=8}},
    npc_dota_hero_warlock = {items={"item_pipe","item_black_king_bar","item_spirit_vessel","item_mjollnir","item_force_staff"}, reason="Survive teamfight magic and clear golem pressure", priority={item_pipe=12,item_black_king_bar=10,item_spirit_vessel=9,item_mjollnir=8,item_force_staff=7}},
    npc_dota_hero_witch_doctor = {items={"item_black_king_bar","item_pipe","item_glimmer_cape","item_force_staff","item_spirit_vessel"}, reason="Stop Maledict/Death Ward burst and cut healing", priority={item_black_king_bar=12,item_pipe=11,item_glimmer_cape=9,item_force_staff=8,item_spirit_vessel=8}},
    npc_dota_hero_windrunner = {items={"item_monkey_king_bar","item_bloodthorn","item_heavens_halberd","item_ghost","item_sheepstick"}, reason="True strike and stop Focus Fire", priority={item_monkey_king_bar=15,item_bloodthorn=13,item_heavens_halberd=11,item_ghost=9,item_sheepstick=10}},
    npc_dota_hero_winter_wyvern = {items={"item_black_king_bar","item_pipe","item_nullifier","item_lotus_orb","item_force_staff"}, reason="Purge saves and survive Winter's Curse setups", priority={item_black_king_bar=10,item_pipe=8,item_nullifier=12,item_lotus_orb=9,item_force_staff=8}},
    npc_dota_hero_wisp = {items={"item_spirit_vessel","item_nullifier","item_skadi","item_shivas_guard","item_orchid"}, reason="Cut tether sustain and stop Relocate saves", priority={item_spirit_vessel=14,item_nullifier=12,item_skadi=10,item_shivas_guard=9,item_orchid=8}},
    npc_dota_hero_dawnbreaker = {items={"item_spirit_vessel","item_heavens_halberd","item_ghost","item_shivas_guard","item_force_staff"}, reason="Cut global healing and kite physical burst", priority={item_spirit_vessel=12,item_heavens_halberd=10,item_ghost=8,item_shivas_guard=8,item_force_staff=8}},
    npc_dota_hero_earth_spirit = {items={"item_black_king_bar","item_lotus_orb","item_force_staff","item_cyclone","item_pipe"}, reason="Survive silence/control chains and reposition", priority={item_black_king_bar=11,item_lotus_orb=10,item_force_staff=10,item_cyclone=8,item_pipe=8}},
    npc_dota_hero_ember_spirit = {items={"item_orchid","item_bloodthorn","item_sheepstick","item_gungir","item_black_king_bar"}, reason="Silence or root Sleight/Remnant mobility", priority={item_orchid=14,item_bloodthorn=15,item_sheepstick=14,item_gungir=12,item_black_king_bar=8}},
    npc_dota_hero_furion = {items={"item_mjollnir","item_battlefury","item_force_staff","item_blink"}, reason="Clear treants and answer global split-push", priority={item_mjollnir=9,item_battlefury=7,item_force_staff=7,item_blink=7}},
    npc_dota_hero_lone_druid = {items={"item_heavens_halberd","item_ghost","item_crimson_guard","item_assault","item_spirit_vessel"}, reason="Disarm bear pressure and reduce sustain", priority={item_heavens_halberd=12,item_ghost=9,item_crimson_guard=10,item_assault=8,item_spirit_vessel=8}},
    npc_dota_hero_lycan = {items={"item_crimson_guard","item_mjollnir","item_shivas_guard","item_heavens_halberd","item_ghost"}, reason="Block summons and kite Shapeshift", priority={item_crimson_guard=13,item_mjollnir=11,item_shivas_guard=10,item_heavens_halberd=9,item_ghost=8}},
    npc_dota_hero_monkey_king = {items={"item_force_staff","item_ghost","item_heavens_halberd","item_crimson_guard","item_black_king_bar"}, reason="Leave Wukong area and reduce burst", priority={item_force_staff=12,item_ghost=10,item_heavens_halberd=9,item_crimson_guard=8,item_black_king_bar=8}},
    npc_dota_hero_rattletrap = {items={"item_force_staff","item_hurricane_pike","item_black_king_bar","item_ghost","item_lotus_orb"}, reason="Escape Cogs and Hookshot follow-up", priority={item_force_staff=16,item_hurricane_pike=12,item_black_king_bar=9,item_ghost=7,item_lotus_orb=7}},
    npc_dota_hero_alchemist = {items={"item_spirit_vessel","item_skadi","item_shivas_guard","item_heavens_halberd","item_silver_edge"}, reason="Cut Chemical Rage sustain and physical timing", priority={item_spirit_vessel=15,item_skadi=12,item_shivas_guard=10,item_heavens_halberd=10,item_silver_edge=8}},
    npc_dota_hero_huskar = {items={"item_spirit_vessel","item_skadi","item_heavens_halberd","item_ghost","item_silver_edge"}, reason="Anti-heal and disarm Burning Spears burst", priority={item_spirit_vessel=16,item_skadi=12,item_heavens_halberd=13,item_ghost=10,item_silver_edge=8}},
    npc_dota_hero_razor = {items={"item_force_staff","item_hurricane_pike","item_lotus_orb","item_heavens_halberd","item_ghost"}, reason="Break Static Link and kite Eye timing", priority={item_force_staff=14,item_hurricane_pike=12,item_lotus_orb=9,item_heavens_halberd=9,item_ghost=8}},
    npc_dota_hero_shredder = {items={"item_spirit_vessel","item_pipe","item_mage_slayer","item_silver_edge","item_black_king_bar"}, reason="Cut regen and reduce pure/magic spam", priority={item_spirit_vessel=14,item_pipe=9,item_mage_slayer=9,item_silver_edge=10,item_black_king_bar=8}},
    npc_dota_hero_viper = {items={"item_pipe","item_black_king_bar","item_lotus_orb","item_force_staff","item_mage_slayer"}, reason="Mitigate poison, break and slows", priority={item_pipe=12,item_black_king_bar=11,item_lotus_orb=9,item_force_staff=9,item_mage_slayer=8}},
    npc_dota_hero_skeleton_king = {items={"item_spirit_vessel","item_skadi","item_heavens_halberd","item_ghost","item_crimson_guard"}, reason="Cut lifesteal and handle reincarnation fights", priority={item_spirit_vessel=10,item_skadi=9,item_heavens_halberd=11,item_ghost=9,item_crimson_guard=8}},
    npc_dota_hero_largo = {items={"item_pipe","item_black_king_bar","item_force_staff","item_lotus_orb","item_aeon_disk"}, reason="Default 7.41d profile: respect control and magic burst", priority={item_pipe=9,item_black_king_bar=9,item_force_staff=8,item_lotus_orb=8,item_aeon_disk=8}},
}

for heroName, data in pairs(HERO_COUNTERS_741D) do
    HERO_COUNTERS[heroName] = data
end

--------------------------------------------------------------------------------
-- ITEM DATABASE (partial for net worth calculation)
--------------------------------------------------------------------------------
local ITEM_COSTS = {
    -- Boots
    item_boots = 500, item_phase_boots = 1450, item_power_treads = 1400,
    item_arcane_boots = 1500, item_tranquil_boots = 900, item_travel_boots = 2500, item_travel_boots_2 = 4500,
    item_boots_of_bearing = 4225,
    -- Basic items
    item_magic_wand = 460, item_magic_stick = 200, item_bracer = 505,
    item_wraith_band = 505, item_null_talisman = 505, item_belt_of_strength = 450,
    item_boots_of_elves = 450, item_robe = 450, item_circlet = 155, item_crown = 450,
    item_ogre_axe = 1000, item_blade_of_alacrity = 1000, item_staff_of_wizardry = 1000,
    item_soul_ring = 805, item_aether_lens = 2275,
    -- Weapons
    item_broadsword = 1000, item_claymore = 1350, item_mithril_hammer = 1600,
    item_blades_of_attack = 450, item_quarterstaff = 875, item_javelin = 900,
    item_mask_of_madness = 1900, item_armlet = 2500, item_blade_mail = 2400,
    item_blight_stone = 300, item_orb_of_venom = 350,
    -- Armor
    item_chainmail = 500, item_platemail = 1400, item_helm_of_iron_will = 975,
    item_ring_of_protection = 175, item_buckler = 425, item_vanguard = 1700,
    item_crimson_guard = 3725, item_assault = 5125, item_shivas_guard = 4500,
    -- Accessories
    item_blink = 2250, item_force_staff = 2200, item_ultimate_scepter = 4200,
    item_aghanims_shard = 1400, item_black_king_bar = 4050, item_sphere = 4800,
    item_aeon_disk = 3000, item_lotus_orb = 3850, item_linkens = 4800,
    -- Damage
    item_daedalus = 5100, item_demon_edge = 2200, item_eagle = 2800, item_reaver = 2800,
    item_mystic_staff = 2800, item_hyperstone = 2000, item_talisman_of_evasion = 1300,
    item_relic = 3400, item_sacred_relic = 3400,
    -- Specific items
    -- Specific items
    item_mjollnir = 5500, item_radiance = 4700, item_heart = 5100, item_tarrasque = 5100,
    item_butterfly = 5450, item_satanic = 5050, item_skadi = 5900, item_eye_of_skadi = 5900,
    item_abyssal_blade = 6250, item_nullifier = 4350, item_bloodthorn = 6400,
    item_silver_edge = 5700, item_diffusal_blade = 2500, item_diffusal_blade_2 = 2500,
    item_sheepstick = 5200, item_scythe_of_vyse = 5200, item_gungir = 4650, item_gleipnir = 4650,
    item_pipe = 3725, item_crimson_guard = 3725, item_heavens_halberd = 3400,
    item_solar_crest = 2575, item_manta = 4650, item_disperser = 6100,
    item_cyclone = 2600, item_euls = 2600, item_wind_waker = 6800,
    item_desolator = 3500, item_monkey_king_bar = 5000, item_spirit_vessel = 2725,
    item_urnd = 2725, item_guardian_greaves = 4450, item_refresher = 5000,
    item_refresher_orb = 5000, item_overwhelming_blink = 6800, item_swift_blink = 6800,
    item_arcane_blink = 6800, item_hurricane_pike = 4450, item_orchid = 3275,
    item_orchid_malevolence = 3275, item_ethereal_blade = 5200, item_rod_of_atos = 2250,
    item_pavise = 1350, item_holy_locket = 2250, item_witch_blade = 2775,
    item_veil_of_discord = 1700, item_kaya_and_sange = 4200, item_sange_and_yasha = 4200,
    item_yasha_and_kaya = 4200, item_invis_sword = 3250, item_shadow_blade = 3250,
    item_bloodstone = 4700, item_octarine_core = 4900, item_phylactery = 2600,
    item_hand_of_midas = 2200, item_harpoon = 4700, item_dagon = 3050,
    item_medallion = 1025, item_solar = 2575,
    item_vladmir = 2200, item_vladmirs_offering = 2200, item_mekansm = 1775,
    item_glimmer = 2150, item_glimmer_cape = 2150,
    item_drum = 1650, item_headdress = 425,
    item_buckler = 425, item_ring_of_basilius = 425, item_basilius = 425,
    -- 7.41 Additions
    item_battlefury = 3900, item_bfury = 3900, item_maelstrom = 2950, item_mage_slayer = 3100,
    item_splintmail = 950, item_shawl = 450, item_chasm_stone = 800, item_wizard_hat = 250,
    item_consecrated_wraps = 2600, item_angels_demise = 5600, item_crellas_crozier = 4800,
    item_essence_distiller = 1775,
}

-- Function to get item cost from database
local function GetItemCost(itemName)
    if not itemName then return 0 end
    local rawName = itemName
    itemName = canonItemName(itemName)
    local engineName = engineItemName(itemName)
    -- Prefer live game data when available; fallback to local table for aliases/undocumented cases.
    local ok, liveCost = pcall(GameRules.GetItemCost, engineName)
    if ok and liveCost and liveCost > 0 then return liveCost end
    ok, liveCost = pcall(GameRules.GetItemCost, itemName)
    if ok and liveCost and liveCost > 0 then return liveCost end
    local cost = ITEM_COSTS[itemName] or ITEM_COSTS[rawName] or ITEM_COSTS[engineName]
    if cost then return cost end
    return 0
end

--------------------------------------------------------------------------------
-- GAME-PHASE DETECTION
--------------------------------------------------------------------------------
local PHASE_EARLY = 1
local PHASE_MID   = 2
local PHASE_LATE  = 3

--------------------------------------------------------------------------------
-- ITEM DATABASE
--------------------------------------------------------------------------------
local ITEM_DB = {
    -- ═══════════════════════ EARLY GAME ═══════════════════════
    {name="item_magic_wand",     display="Magic Wand",       cost=460,   phase={1,2},     tags={"sustain","vs_spam"}},
    {name="item_bracer",         display="Bracer",            cost=505,   phase={1},       tags={"hp","phys_def"}},
    {name="item_wraith_band",    display="Wraith Band",       cost=505,   phase={1},       tags={"agi","phys_dps"}},
    {name="item_null_talisman",  display="Null Talisman",     cost=505,   phase={1},       tags={"int","magic_dps"}},
    {name="item_soul_ring",      display="Soul Ring",         cost=805,   phase={1,2},     tags={"mana","hp","armor","sustain"}},
    {name="item_wizard_hat",     display="Wizard Hat",        cost=250,   phase={1},       tags={"mana","int"}},
    -- Boots
    {name="item_phase_boots",    display="Phase Boots",       cost=1450,  phase={1,2},     tags={"mobility","phys_dps","armor"}},
    {name="item_power_treads",   display="Power Treads",      cost=1400,  phase={1,2},     tags={"attack_speed","stats","sustain"}},
    {name="item_arcane_boots",   display="Arcane Boots",      cost=1500,  phase={1,2},     tags={"mana","team_utility"}},
    {name="item_tranquil_boots", display="Tranquil Boots",    cost=900,   phase={1,2},     tags={"mobility","sustain","armor"}},
    {name="item_boots_of_bearing",display="Boots of Bearing", cost=4225,  phase={2,3},     tags={"aura","team_utility","attack_speed"}},
    {name="item_travel_boots",   display="Boots of Travel",   cost=2500,  phase={2,3},     tags={"mobility","push","global"}},
    -- ═══════════════════════ CORE / MID GAME ══════════════════
    -- Physical defense
    {name="item_ghost",          display="Ghost Scepter",    cost=1500,   phase={1,2},     tags={"vs_phys","save"}},
    {name="item_blade_mail",     display="Blade Mail",       cost=2400,   phase={1,2},     tags={"vs_phys","vs_burst","armor","reflect"},
     triggers={"carry","phys_burst","phys_dps"}},
    {name="item_vanguard",       display="Vanguard",         cost=1700,   phase={1,2},     tags={"hp","block","tanky"}},
    {name="item_splintmail",     display="Splintmail",       cost=950,    phase={1,2},     tags={"armor","vs_phys","hp"}},
    {name="item_pavise",         display="Pavise",           cost=1350,   phase={1,2},     tags={"vs_phys","save","armor"},
     triggers={"phys_dps","phys_burst"}},
    {name="item_crimson_guard",  display="Crimson Guard",    cost=3725,   phase={2,3},     tags={"vs_phys","team","block","armor"},
     triggers={"phys_dps","summons","illusions","push"}},
    {name="item_assault",        display="Assault Cuirass",  cost=5125,   phase={2,3},     tags={"armor","attack_speed","aura","vs_phys"},
     triggers={"phys_dps","carry","armor_reduce"}},
    {name="item_shivas_guard",   display="Shiva's Guard",    cost=4500,   phase={2,3},     tags={"armor","vs_phys","slow","int"},
     triggers={"phys_dps","carry","heal","attack_speed"}},
    {name="item_heavens_halberd",display="Heaven's Halberd", cost=3400,   phase={2,3},     tags={"vs_phys","disarm","evasion","hp"},
     triggers={"carry","phys_dps","phys_burst"}},
    {name="item_solar_crest",    display="Solar Crest",      cost=2575,   phase={1,2},     tags={"armor","vs_phys","buff","debuff"}},
    -- Magical defense
    {name="item_pipe",           display="Pipe of Insight",  cost=3725,   phase={2,3},     tags={"vs_magic","team","magic_resist","barrier"},
     triggers={"magic_burst"}},
    {name="item_glimmer_cape",   display="Glimmer Cape",     cost=2150,   phase={1,2},     tags={"vs_magic","save","invis"},
     triggers={"magic_burst","disable"}},
    {name="item_mage_slayer",    display="Mage Slayer",      cost=3100,   phase={1,2,3},   tags={"vs_magic","magic_resist","debuff","phys_dps"},
     triggers={"magic_burst","spell_lifesteal"}},
    {name="item_shawl",          display="Shawl",            cost=450,    phase={1,2},     tags={"vs_magic","magic_resist"}},
    {name="item_consecrated_wraps",display="Consecrated Wraps",cost=2600, phase={2,3},     tags={"vs_magic","save","hp","mobility"},
     triggers={"magic_burst","slow"}},
    {name="item_black_king_bar", display="BKB",              cost=4050,   phase={2,3},     tags={"vs_magic","magic_immune","vs_disable"},
     triggers={"disable","stun","silence","hex","magic_burst","doom"}},
    -- Anti-heal
    {name="item_spirit_vessel",  display="Spirit Vessel",    cost=2725,   phase={1,2},     tags={"anti_heal","hp","move_speed"},
     triggers={"heal","save","tanky"}},
    -- Anti-evasion
    {name="item_monkey_king_bar",display="MKB",              cost=5000,   phase={2,3},     tags={"vs_evasion","phys_dps","attack"},
     triggers={"evasion"}},
    -- Anti-invis
    {name="item_dust",           display="Dust of Appearance",cost=80,    phase={1,2,3},   tags={"vs_invis","detection"},
     triggers={"invis"}},
    {name="item_ward_sentry",    display="Sentry Ward",      cost=50,     phase={1,2,3},   tags={"vs_invis","detection"},
     triggers={"invis"}},
    -- Anti-illusions & summons
    {name="item_mjollnir",       display="Mjollnir",         cost=5500,   phase={2,3},     tags={"vs_illusions","attack_speed","phys_dps","cleave"},
     triggers={"illusions","summons","push"}},
    {name="item_battlefury",     display="Battle Fury",      cost=3900,   phase={1,2},     tags={"vs_illusions","cleave","farm","phys_dps"},
     triggers={"illusions","summons"}},
    {name="item_radiance",       display="Radiance",         cost=4700,   phase={2,3},     tags={"vs_illusions","burn","miss","farm"},
     triggers={"illusions","summons","invis"}},
    {name="item_maelstrom",      display="Maelstrom",        cost=2950,   phase={1,2},     tags={"vs_illusions","attack_speed","farm"},
     triggers={"illusions","summons"}},
    {name="item_mask_of_madness",display="Mask of Madness",  cost=1900,   phase={1,2},     tags={"phys_dps","attack_speed","lifesteal","farm"}},
    {name="item_gungir",         display="Gleipnir",         cost=4650,   phase={2,3},     tags={"root","vs_illusions","attack_speed","phys_dps"},
     triggers={"mobility","illusions","invis"}},
    -- Mobility
    {name="item_blink",          display="Blink Dagger",     cost=2250,   phase={1,2,3},   tags={"mobility","initiation"}},
    {name="item_force_staff",    display="Force Staff",      cost=2200,   phase={1,2},     tags={"mobility","save","vs_slow"},
     triggers={"slow","root"}},
    {name="item_hurricane_pike", display="Hurricane Pike",   cost=4450,   phase={2,3},     tags={"mobility","save","vs_melee","ranged"}},
    {name="item_harpoon",        display="Harpoon",          cost=4700,   phase={2,3},     tags={"initiation","gap_close","stats"}},
    -- Dispel / Purge
    {name="item_lotus_orb",      display="Lotus Orb",        cost=3850,   phase={2,3},     tags={"dispel","reflect","armor","mana"},
     triggers={"disable","stun","hex","silence","doom"}},
    {name="item_manta",          display="Manta Style",      cost=4650,   phase={2,3},     tags={"dispel","illusions","stats","phys_dps"},
     triggers={"silence","slow","root"}},
    {name="item_disperser",      display="Disperser",        cost=6100,   phase={2,3},     tags={"dispel","mobility","agi","slow"},
     triggers={"silence","slow","root","disable"}},
    {name="item_cyclone",        display="Eul's Scepter",    cost=2600,   phase={1,2},     tags={"dispel","mana","mobility","disable"},
     triggers={"silence","slow","disable"}},
    -- Protection
    {name="item_sphere",         display="Linken's Sphere",  cost=4800,   phase={2,3},     tags={"block_spell","save","stats"},
     triggers={"disable","hex","doom","duel","black_hole"}},
    {name="item_aeon_disk",      display="Aeon Disk",        cost=3000,   phase={2,3},     tags={"save","vs_burst","dispel"},
     triggers={"phys_burst","magic_burst","chrono","black_hole"}},
    {name="item_wind_waker",     display="Wind Waker",       cost=6800,   phase={2,3},     tags={"save","dispel","mobility","mana"},
     triggers={"disable","chrono","black_hole"}},
    -- Damage items
    {name="item_armlet",         display="Armlet of Mordiggian", cost=2500, phase={1,2},   tags={"phys_dps","attack_speed","armor","tanky","hp"}},
    {name="item_desolator",      display="Desolator",        cost=3500,   phase={2},       tags={"armor_reduce","phys_dps"}},
    {name="item_daedalus",       display="Daedalus",         cost=5100,   phase={2,3},     tags={"crit","phys_dps"}},
    {name="item_butterfly",      display="Butterfly",        cost=5450,   phase={3},       tags={"evasion","attack_speed","agi","phys_dps"}},
    {name="item_satanic",        display="Satanic",          cost=5050,   phase={3},       tags={"lifesteal","hp","save","phys_dps"}},
    {name="item_skadi",          display="Eye of Skadi",     cost=5900,   phase={3},       tags={"slow","stats","hp","anti_heal"},
     triggers={"heal","tanky","mobility"}},
    {name="item_abyssal_blade",  display="Abyssal Blade",    cost=6250,   phase={3},       tags={"stun","bash","vs_bkb","phys_dps","block"},
     triggers={"magic_immune","carry"}},
    {name="item_nullifier",      display="Nullifier",        cost=4350,   phase={3},       tags={"dispel","vs_save","phys_dps"},
     triggers={"save","invis","evasion"}},
    {name="item_bloodthorn",     display="Bloodthorn",       cost=6400,   phase={3},       tags={"silence","crit","vs_evasion","attack_speed"},
     triggers={"evasion","mobility","magic_burst"}},
    {name="item_silver_edge",    display="Silver Edge",      cost=5700,   phase={2,3},     tags={"invis","break","phys_dps"},
     triggers={"tanky","evasion","breakable"}},
    {name="item_diffusal_blade", display="Diffusal Blade",   cost=2500,   phase={1,2},     tags={"mana_burn","slow","agi","phys_dps"},
     triggers={"mana_burn"}},
    -- Utility / Mixed
    {name="item_aether_lens",    display="Aether Lens",      cost=2275,   phase={1,2,3},   tags={"mana","int","cast_range"}},
    {name="item_rod_of_atos",    display="Rod of Atos",      cost=2250,   phase={1,2},     tags={"root","hp","int"},
     triggers={"mobility","invis"}},
    {name="item_orchid",         display="Orchid Malevolence",cost=3275,   phase={2},       tags={"silence","mana","attack_speed"},
     triggers={"magic_burst","mobility","versatile"}},
    {name="item_sheepstick",     display="Scythe of Vyse",    cost=5200,   phase={3},       tags={"hex","disable","mana","int"},
     triggers={"carry","magic_immune","mobility"}},
    {name="item_ethereal_blade", display="Ethereal Blade",   cost=5200,   phase={2,3},     tags={"vs_phys","magic_amp","save","agi"}},
    {name="item_refresher",      display="Refresher Orb",    cost=5000,   phase={3},       tags={"refresh","ultimate"}},
    {name="item_heart",          display="Heart of Tarrasque",cost=5100,  phase={3},       tags={"hp","tanky","regen"},
     triggers={"phys_dps","magic_burst"}},
    {name="item_overwhelming_blink", display="Overwhelming Blink", cost=6800, phase={3},   tags={"mobility","slow","str","initiation"}},
    {name="item_swift_blink",    display="Swift Blink",      cost=6800,   phase={3},       tags={"mobility","agi","attack_speed"}},
    {name="item_arcane_blink",   display="Arcane Blink",     cost=6800,   phase={3},       tags={"mobility","int","cd_reduction"}},
    {name="item_witch_blade",    display="Witch Blade",      cost=2775,   phase={1,2},     tags={"int","phys_dps","slow","armor"}},
    {name="item_veil_of_discord",display="Veil of Discord",  cost=1700,   phase={1,2},     tags={"magic_amp","int","armor"}},
    {name="item_kaya_and_sange", display="Kaya and Sange",   cost=4200,   phase={2,3},     tags={"hp","int","magic_amp","slow"}},
    {name="item_sange_and_yasha",display="Sange and Yasha",  cost=4200,   phase={2,3},     tags={"hp","agi","mobility","slow"}},
    {name="item_yasha_and_kaya", display="Yasha and Kaya",   cost=4200,   phase={2,3},     tags={"agi","int","magic_amp","mobility"}},
    {name="item_invis_sword",    display="Shadow Blade",     cost=3250,   phase={1,2},     tags={"invis","phys_dps","initiation"}},
    {name="item_crellas_crozier",display="Crella's Crozier", cost=4800,   phase={2,3},     tags={"stats","mobility","save","escape"},
     triggers={"slow","root","mobility"}},
    -- Support items
    {name="item_mekansm",        display="Mekansm",          cost=1775,   phase={1,2},     tags={"heal","team","armor"}},
    {name="item_essence_distiller",display="Essence Distiller",cost=1775, phase={1,2},     tags={"heal","team","save","sustain"},
     triggers={"phys_burst","magic_burst"}},
    {name="item_guardian_greaves",display="Guardian Greaves", cost=4450,   phase={2,3},     tags={"heal","team","dispel","armor","mana"},
     triggers={"disable","silence"}},
    {name="item_vladmir",        display="Vladmir's Offering",cost=2200,   phase={1,2},     tags={"team","aura","armor","mana","lifesteal"}},
    {name="item_holy_locket",    display="Holy Locket",      cost=2250,   phase={1,2},     tags={"heal","hp","save"}},
    {name="item_ultimate_scepter",display="Aghanim's Scepter",cost=4200, phase={2,3},     tags={"ultimate","stats"}},
    {name="item_aghanims_shard", display="Aghanim's Shard",  cost=1400,  phase={2,3},     tags={"ultimate","ability"}},
    {name="item_bloodstone",     display="Bloodstone",       cost=4700,   phase={2,3},     tags={"hp","mana","spell_lifesteal","int"}},
    {name="item_dagon",          display="Dagon",            cost=3050,   phase={1,2},     tags={"magic_burst","int"}},
    {name="item_octarine_core",  display="Octarine Core",    cost=4900,   phase={3},       tags={"cd_reduction","hp","mana","int"}},
    {name="item_phylactery",     display="Phylactery",       cost=2600,   phase={1,2},     tags={"magic_burst","hp","int"}},
    {name="item_chasm_stone",    display="Chasm Stone",      cost=800,    phase={1,2},     tags={"aoe","stats"}},
    {name="item_angels_demise",   display="Angel's Demise",   cost=5600,   phase={2,3},     tags={"magic_burst","hp","int","slow"},
     triggers={"magic_burst","mobility","tanky"}},
    {name="item_hand_of_midas",  display="Hand of Midas",    cost=2200,   phase={1},       tags={"farm","attack_speed"}},
}

local ITEM_LOOKUP = {}
for _, item in ipairs(ITEM_DB) do
    ITEM_LOOKUP[item.name] = item
end
for alias, canonical in pairs(ITEM_NAME_ALIASES) do
    if ITEM_LOOKUP[canonical] then
        ITEM_LOOKUP[alias] = ITEM_LOOKUP[canonical]
    end
end

--------------------------------------------------------------------------------
-- NEUTRAL ITEMS DATABASE (Updated for current patch - 2026)
-- Source: assets/data/neutral_items.json
--------------------------------------------------------------------------------
local NEUTRAL_DB = {
    -- Tier 1 (5:00+)
    {name="item_occult_bracelet",    display="Occult Bracelet",    tier=1, tags={"mana","int","magic_burst"}},
    {name="item_kobold_cup",         display="Kobold Cup",         tier=1, tags={"gold","farm","luck"}},
    {name="item_chipped_vest",       display="Chipped Vest",       tier=1, tags={"armor","reflect","vs_phys"}},
    {name="item_polliwog_charm",     display="Polliwog Charm",     tier=1, tags={"heal","mana","sustain"}},
    {name="item_dormant_curio",      display="Dormant Curio",      tier=1, tags={"stats","vision"}},
    {name="item_duelist_gloves",     display="Duelist Gloves",     tier=1, tags={"lifesteal","phys_dps","agi"}},
    {name="item_weighted_dice",      display="Weighted Dice",      tier=1, tags={"luck","gold","crit"}},
    {name="item_ash_legion_shield",  display="Ash Legion Shield",  tier=1, tags={"block","armor","vs_phys"}},
    {name="item_dagger_of_ristul",   display="Dagger of Ristul",   tier=1, tags={"phys_dps","hp_cost"}},
    {name="item_stonefeather_satchel",display="Stonefeather Satchel",tier=1, tags={"stats","mobility"}},
    {name="item_foragers_kit",       display="Forager's Kit",       tier=1, tags={"farm","summons"}},
    {name="item_possessed_mask",     display="Possessed Mask",     tier=1, tags={"lifesteal","stats"}},
    -- Tier 2 (15:00+)
    {name="item_essence_ring",       display="Essence Ring",       tier=2, tags={"hp","mana","sustain"}},
    {name="item_mana_draught",       display="Mana Draught",       tier=2, tags={"mana","sustain","int"}},
    {name="item_poor_mans_shield",   display="Poor Man's Shield",  tier=2, tags={"block","vs_phys","agi"}},
    {name="item_searing_signet",     display="Searing Signet",     tier=2, tags={"burn","magic_amp","int"}},
    {name="item_pogo_stick",         display="Pogo Stick",         tier=2, tags={"mobility","initiation"}},
    {name="item_defiant_shell",      display="Defiant Shell",      tier=2, tags={"armor","save","vs_phys"}},
    {name="item_seeds_of_serenity",   display="Seeds of Serenity",   tier=2, tags={"heal","sustain"}},
    {name="item_medallion_of_courage",display="Medallion",          tier=2, tags={"armor","armor_reduce"}},
    -- Tier 3 (25:00+)
    {name="item_serrated_shiv",      display="Serrated Shiv",      tier=3, tags={"armor_reduce","phys_dps","bleed"}},
    {name="item_gunpowder_gauntlets",display="Gunpowder Gauntlets",tier=3, tags={"phys_burst","attack_speed","aoe"}},
    {name="item_jidi_pollen_bag",    display="Jidi Pollen Bag",    tier=3, tags={"slow","heal","mana"}},
    {name="item_psychic_headband",   display="Psychic Headband",   tier=3, tags={"int","mana","cd_reduction"}},
    {name="item_unrelenting_eye",    display="Unrelenting Eye",    tier=3, tags={"vision","attack_speed","true_strike"}},
    {name="item_spellslinger",       display="Spellslinger",       tier=3, tags={"mana","spell_amp"}},
    {name="item_partisans_brand",    display="Partisan's Brand",    tier=3, tags={"mana_burn","phys_dps"}},
    {name="item_cloak_of_flames",    display="Cloak of Flames",    tier=3, tags={"burn","armor"}},
    {name="item_stormcrafter",       display="Stormcrafter",       tier=3, tags={"magic_burst","mobility"}},
    -- Tier 4 (35:00+)
    {name="item_crippling_crossbow", display="Crippling Crossbow", tier=4, tags={"slow","phys_dps","armor_reduce"}},
    {name="item_giant_maul",         display="Giant Maul",         tier=4, tags={"phys_burst","stun","str"}},
    {name="item_rattlecage",         display="Rattlecage",         tier=4, tags={"armor","reflect","fear"}},
    {name="item_idol_of_screeauk",   display="Idol of Scree'auk",  tier=4, tags={"save","dispel","magic_resist"}},
    {name="item_flayers_bota",       display="Flayer's Bota",      tier=4, tags={"mobility","agi","attack_speed"}},
    {name="item_metamorphic_mandible", display="Metamorphic Mandible", tier=4, tags={"stats","armor","hp"}},
    {name="item_dandelion_amulet",   display="Dandelion Amulet",   tier=4, tags={"magic_block","save"}},
    {name="item_enchanters_bauble",  display="Enchanter's Bauble", tier=4, tags={"cast_range","magic_amp"}},
    {name="item_prophets_pendulum",  display="Prophet's Pendulum", tier=4, tags={"damage_delay","stats"}},
    {name="item_conjurers_catalyst", display="Conjurer's Catalyst",tier=4, tags={"stats","cd_reduction"}},
    -- Tier 5 (60:00+)
    {name="item_desolator_2",        display="Desolator 2",        tier=5, tags={"armor_reduce","phys_dps"}},
    {name="item_fallen_sky",         display="Fallen Sky",         tier=5, tags={"initiation","stun","phys_burst"}},
    {name="item_demonicon",          display="Demonicon",          tier=5, tags={"summons","push","magic_burst"}},
    {name="item_minotaur_horn",      display="Minotaur Horn",      tier=5, tags={"stun","tanky","initiation"}},
    {name="item_spider_legs",        display="Spider Legs",        tier=5, tags={"mobility","slow","initiation"}},
    {name="item_riftshadow_prism",   display="Riftshadow Prism",   tier=5, tags={"magic_amp","int","mana"}},
    {name="item_dezun_bloodrite",    display="Dezun Bloodrite",    tier=5, tags={"heal","magic_burst","anti_heal"}},
    {name="item_divine_regalia",     display="Divine Regalia",     tier=5, tags={"stats","save","ultimate"}},
    {name="item_harmonizer",         display="Harmonizer",         tier=5, tags={"mana_reduction","spell_amp"}},
    {name="item_heavy_blade",        display="Heavy Blade",        tier=5, tags={"armor","phys_dps","slow"}},
}

--------------------------------------------------------------------------------
-- COUNTER-LOGIC
--------------------------------------------------------------------------------
local COUNTER_RULES = {
    {tags={"phys_dps","carry"},        weight=3, suggest={"vs_phys","armor","block"}},
    {tags={"phys_burst"},              weight=4, suggest={"vs_phys","vs_burst","save","armor"}},
    {tags={"attack_speed"},            weight=2, suggest={"vs_phys","armor","slow"}},
    {tags={"magic_burst"},             weight=4, suggest={"vs_magic","magic_resist","vs_disable"}},
    {tags={"pure_dmg"},                weight=3, suggest={"hp","save","tanky"}},
    {tags={"disable","stun"},          weight=3, suggest={"vs_disable","dispel","save"}},
    {tags={"hex"},                     weight=5, suggest={"vs_disable","dispel","block_spell"}},
    {tags={"silence"},                 weight=3, suggest={"dispel"}},
    {tags={"doom"},                    weight=5, suggest={"block_spell","save"}},
    {tags={"root"},                    weight=2, suggest={"dispel","mobility"}},
    {tags={"fear"},                    weight=3, suggest={"vs_disable","dispel","save"}},
    {tags={"invis"},                   weight=4, suggest={"vs_invis","detection"}},
    {tags={"illusions"},               weight=3, suggest={"vs_illusions","cleave"}},
    {tags={"summons"},                 weight=2, suggest={"vs_illusions","cleave"}},
    {tags={"mobility"},                weight=2, suggest={"root","slow","disable"}},
    {tags={"evasion"},                 weight=4, suggest={"vs_evasion","break"}},
    {tags={"heal","save"},             weight=3, suggest={"anti_heal"}},
    {tags={"heal"},                    weight=2, suggest={"anti_heal"}},
    {tags={"carry","phys_dps"},        weight=2, suggest={"disarm","vs_phys","armor"}},
    {tags={"magic_immune"},            weight=2, suggest={"vs_bkb","disable"}},
    {tags={"mana_burn"},               weight=2, suggest={"mana","sustain","hp"}},
    {tags={"global"},                  weight=2, suggest={"hp","tanky","save"}},
    {tags={"break"},                   weight=2, suggest={"dispel","save"}},
    {tags={"anti_heal"},               weight=2, suggest={"dispel","hp"}},
    {tags={"chrono"},                  weight=5, suggest={"save","vs_burst","block_spell"}},
    {tags={"black_hole"},              weight=5, suggest={"save","vs_burst","block_spell"}},
    {tags={"duel"},                    weight=4, suggest={"save","block_spell"}},
    {tags={"reincarnation"},           weight=1, suggest={"anti_heal","slow"}},
    {tags={"rupture"},                 weight=2, suggest={"dispel","save"}},
    {tags={"drain"},                   weight=2, suggest={"mobility","save"}},
    {tags={"push"},                    weight=2, suggest={"vs_illusions","cleave","team"}},
    {tags={"armor_reduce"},            weight=2, suggest={"armor","vs_phys"}},
    {tags={"track"},                   weight=2, suggest={"dispel","vs_invis"}},
    {tags={"slow"},                    weight=2, suggest={"dispel","mobility"}},
}

--------------------------------------------------------------------------------
-- PANEL POSITION PERSISTENCE (io.open — matching broodmother pattern)
--------------------------------------------------------------------------------
local UI = {}
local PANEL_CONFIG_FILE = "item_helper_panel.ini"

local function GetScriptDir()
    local getInfo = debug and debug.getinfo
    if not getInfo then return nil end
    local ok, info = pcall(getInfo, 1, "S")
    local source = ok and info and info.source or ""
    source = tostring(source):gsub("^@", "")
    return source:match("^(.*)[/\\][^/\\]+$")
end

local function GetConfigPath()
    local dir = GetScriptDir()
    if dir and dir ~= "" then
        return dir .. "\\" .. PANEL_CONFIG_FILE
    end
    return PANEL_CONFIG_FILE
end

local function ReadPanelPositionFile(configPath, x, y)
    local file = io.open(configPath, "r")
    if not file then return x, y, false end
    for line in file:lines() do
        local xMatch = line:match("pos_x=([%d%.%-]+)")
        local yMatch = line:match("pos_y=([%d%.%-]+)")
        if xMatch then x = tonumber(xMatch) or x end
        if yMatch then y = tonumber(yMatch) or y end
    end
    file:close()
    return x, y, true
end

local function LoadPanelPosition()
    local x, y = 100.0, 100.0
    pcall(function()
        local loaded
        x, y, loaded = ReadPanelPositionFile(GetConfigPath(), x, y)
        if not loaded then
            x, y = ReadPanelPositionFile(PANEL_CONFIG_FILE, x, y)
        end
    end)
    return x, y
end

local function SavePanelPositionToMenu(px, py)
    px, py = tonumber(px), tonumber(py)
    if not px or not py then return nil, nil end
    px = math.floor(px + 0.5)
    py = math.floor(py + 0.5)

    if UI.panelX and UI.panelX.Set then pcall(function() UI.panelX:Set(px) end) end
    if UI.panelY and UI.panelY.Set then pcall(function() UI.panelY:Set(py) end) end
    return px, py
end

local function SavePanelPosition(px, py)
    SavePanelPositionToMenu(px, py)
end

local _loadedPanelX, _loadedPanelY = LoadPanelPosition()

--------------------------------------------------------------------------------
-- MENU
--------------------------------------------------------------------------------
function script.OnScriptsLoaded()
    local tab = Menu.Create("General", "Main", "Item Helper")
    tab:Icon("\u{f085}")
    local main = tab:Create(L("m_menu_settings"))

    local g_main = main:Create(L("m_section_general"))

    UI.enabled = g_main:Switch(L("m_enable"), true, "\u{f00c}")
    UI.enabled:ToolTip(L("m_tt_enable"))

    UI.showPanel = g_main:Switch(L("m_panel"), true, "\u{f06e}")
    UI.showPanel:ToolTip(L("m_tt_panel"))

    UI.toggleKey = g_main:Bind(L("m_panel_key"), Enum.ButtonCode.KEY_NONE, "\u{f11c}")
    UI.toggleKey:ToolTip(L("m_tt_panel_key"))

    UI.panelMode = g_main:Combo(L("m_panel_mode"), {L("m_mode_extended"), L("m_mode_minimal")}, 0)
    UI.panelMode:ToolTip(L("m_tt_panel_mode"))

    local g_analysis = main:Create(L("m_section_analysis"))

    UI.autoAnalyze = g_analysis:Switch(L("m_auto"), true, "\u{f021}")
    UI.autoAnalyze:ToolTip(L("m_tt_auto"))

    UI.maxItems = g_analysis:Slider(L("m_max"), 3, 10, 6, "%d")
    UI.maxItems:ToolTip(L("m_tt_max"))

    UI.showReasons = g_analysis:Switch(L("m_reasons"), true, "\u{f05a}")
    UI.showReasons:ToolTip(L("m_tt_reasons"))

    UI.showThreats = g_analysis:Switch(L("m_threats"), true, "\u{f071}")
    UI.showThreats:ToolTip(L("m_tt_threats"))

    UI.trackEnemyItems = g_analysis:Switch(L("m_track_enemy_items"), true, "\u{f06d}")
    UI.trackEnemyItems:ToolTip(L("m_tt_track_enemy"))

    UI.showHeroCounters = g_analysis:Switch(L("m_counter_pick"), true, "\u{f0e7}")
    UI.showHeroCounters:ToolTip(L("m_tt_counter_pick"))

    UI.showNetWorth = g_analysis:Switch(L("m_networth_analysis"), true, "\u{f155}")
    UI.showNetWorth:ToolTip(L("m_tt_networth"))

    UI.showEnemyFocus = g_analysis:Switch(L("m_focus_lines"), true, "\u{f05b}")
    UI.showEnemyFocus:ToolTip(L("m_tt_focus_lines"))

    local focus_gear = UI.showEnemyFocus:Gear(L("m_focus_settings"))
    UI.enemyFocusRows = focus_gear:Slider(L("m_focus_rows"), 1, 6, 3, "%d")
    UI.enemyFocusRows:ToolTip(L("m_tt_focus_rows"))

    UI.showNeutrals = g_analysis:Switch(L("m_neutrals"), true, "\u{f06c}")
    UI.showNeutrals:ToolTip(L("m_tt_neutrals"))

    local g_panel = main:Create(L("m_section_panel"))

    UI.scale = g_panel:Slider(L("m_scale_panel"), 60, 200, 100, "%d")
    UI.scale:ToolTip(L("m_tt_scale"))

    UI.opacity = g_panel:Slider(L("m_opacity"), 20, 100, 85, "%d")
    UI.opacity:ToolTip(L("m_tt_opacity"))

    UI.panelX = g_panel:Slider(L("m_offx"), 0, 7680, math.floor((_loadedPanelX or 100) + 0.5), "%d")
    UI.panelY = g_panel:Slider(L("m_offy"), 0, 4320, math.floor((_loadedPanelY or 100) + 0.5), "%d")
    if UI.panelX.Visible then UI.panelX:Visible(false) end
    if UI.panelY.Visible then UI.panelY:Visible(false) end

    UI.showOwned = g_panel:Switch(L("m_highlight_owned"), true, "\u{f00c}")
    UI.showOwned:ToolTip(L("m_tt_owned"))

    UI.showGoldHeader = g_panel:Switch(L("m_gold_header"), true, "\u{f155}")
    UI.showGoldHeader:ToolTip(L("m_tt_gold_header"))

    UI.visMode = g_panel:Combo(L("m_show_panel_vis"), {L("m_vis_always"), L("m_vis_menu"), L("m_vis_shop"), L("m_vis_both")}, 0)
    UI.visMode:ToolTip(L("m_tt_vis_mode"))

    local g_filter = main:Create(L("m_section_filter"))

    UI.enemyFilterMode = g_filter:Combo(L("m_filter_mode"),
        {L("m_filter_all"), L("m_filter_selected"), L("m_filter_exclude")}, 0)
    UI.enemyFilterMode:ToolTip(L("m_tt_filter_mode"))

    UI.enemyFilterList = g_filter:MultiSelect(L("m_filter_heroes"), {}, false)
    UI.enemyFilterList:ToolTip(L("m_tt_filter_list"))

    local g_debug = main:Create(L("m_section_debug"))

    UI.showCategoryBadges = g_debug:Switch(L("m_show_category_badges"), true, "\u{f02b}")
    UI.showCategoryBadges:ToolTip(L("m_tt_category_badges"))

    UI.showScoreBreakdown = g_debug:Switch(L("m_score_breakdown"), true, "\u{f080}")
    UI.showScoreBreakdown:ToolTip(L("m_tt_score_breakdown"))

    local breakdown_gear = UI.showScoreBreakdown:Gear(L("m_breakdown_settings"))
    UI.breakdownChipCount = breakdown_gear:Slider(L("m_breakdown_chip_count"), 1, 4, 2, "%d")
    UI.breakdownChipCount:ToolTip(L("m_tt_breakdown_chips"))
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local S = {
    enemyHeroes     = {},
    enemyTags       = {},
    threatCounts    = {},
    suggestions     = {},
    neutralSuggestions = {},
    ownedItems      = {},
    enemyItems      = {},      -- Items owned by enemies
    enemyItemCounts = {},      -- Count of specific items among enemies
    enemyFilterSnapshot = {},  -- cached order for MultiSelect updates
    enemyFocus      = {},
    activeEnemyCount = 0,
    myGold          = 0,
    myGoldKnown     = false,
    rawGameModeId   = -1,
    playerCount     = 0,
    testContextKind = nil, -- "tryhero" | "lobby" | "custom" | nil
    myHeroName      = "",
    gamePhase       = PHASE_EARLY,
    gameMode        = GAME_MODE.UNKNOWN,  -- Current game mode
    neutralTier     = 0,       -- Current neutral tier available
    lastAnalysis    = 0,
    heroIcons       = {},
    itemIcons       = {},
    lastFrame       = 0,
    dt              = 0.016,
    pulseTime       = 0,
    initialized     = false,
    totalNetWorth   = 0,
    -- Net worth analysis
    myTeamNetWorth  = 0,
    enemyTeamNetWorth = 0,
    netWorthDiff    = 0,       -- Positive = we're leading
    gameTempo       = "even",  -- "ahead", "even", "behind"
    -- Hero counter suggestions
    heroCounterSuggestions = {},
    clickRegions     = {},      -- interactive item card regions
    hoveredRegion    = nil,     -- current hovered click region
    panelVisible     = false,   -- last panel draw visibility state
    panelRect        = nil,     -- last panel bounds for hit-tests
    panelBlockInputUntil = 0,   -- short gate after panel mouse events
    panelMenuPosLoaded = false, -- panel position restored from persisted menu sliders
    -- Drag-to-move state
    panelPos         = {x = _loadedPanelX, y = _loadedPanelY},
    isDragging       = false,
    dragOffset       = {x = 0, y = 0},
    -- Toggle key state
    toggleState      = true,
    toggleKeyWasDown = false,
    -- Draw scale (computed each frame for 2K/4K support)
    drawScale        = 1.0,
}

--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
local FC = {}
local fontsReady = false

local function getFont(sz)
    sz = math.max(8, math.floor(sz))
    if FC[sz] then return FC[sz] end
    local flags = Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or nil

    -- Prefer legacy API used by this script/build first, then try Render v2.
    local ok, f = pcall(function()
        if Render.LoadFont then
            return Render.LoadFont("Inter", flags, 500)
        end
    end)
    if ok and f then FC[sz] = f; fontsReady = true; return f end

    ok, f = pcall(function()
        if Render.CreateFont then
            local weight = (Enum.FontWeight and Enum.FontWeight.NORMAL) or 400
            return Render.CreateFont("Inter", sz, weight, flags)
        end
    end)
    if ok and f then FC[sz] = f; fontsReady = true; return f end
    return nil
end

local function initFonts()
    if fontsReady then return end
    for _, s in ipairs({8,9,10,11,12,14,16}) do getFont(s) end
end

--------------------------------------------------------------------------------
-- UTILS
--------------------------------------------------------------------------------
local F = math.floor
local V = Vec2

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function col(r, g, b, a) return Color(r, g, b, F(clamp(a or 255, 0, 255))) end
local function colA(c, a) return Color(c.r, c.g, c.b, F(clamp(a, 0, 255))) end

-- Scale helper: multiplies a pixel value by the current draw scale
local function sc(v) return F(v * (S.drawScale or 1.0)) end

local function sg(widget, fallback)
    local ok, v = pcall(function() return widget:Get() end)
    if ok and v ~= nil then return v end
    return fallback
end

local function restorePanelPositionFromMenu()
    if S.panelMenuPosLoaded then return end
    if not UI.panelX or not UI.panelY then return end

    local x = sg(UI.panelX, S.panelPos.x or 100)
    local y = sg(UI.panelY, S.panelPos.y or 100)
    if type(x) == "number" and type(y) == "number" then
        S.panelPos.x = x
        S.panelPos.y = y
        S.panelMenuPosLoaded = true
    end
end

local function gt()
    local ok, v = pcall(GameRules.GetGameTime); return ok and v or 0
end
local function gst()
    local ok, v = pcall(GameRules.GetGameStartTime); return ok and v or 0
end

-- Detect game mode from GameRules using Enum.GameMode
local function detectGameMode()
    local ok, mode = pcall(GameRules.GetGameMode)
    if not ok or mode == nil then return GAME_MODE.UNKNOWN end

    -- Safe lookup for Enum.GameMode values
    local function GetMode(key, fallback)
        local em = GetEnum("Enum.GameMode")
        if em and em[key] then return em[key] end
        return fallback
    end

    -- Ranked AP / All Pick
    local rankedAp = GetMode("RANKED_AP", nil)
    local ap = GetMode("AP", 1)
    if mode == rankedAp then return GAME_MODE.RANKED end
    if mode == ap then return GAME_MODE.ALL_PICK end

    -- Turbo
    local turbo = GetMode("TURBO", 23)
    if mode == turbo then return GAME_MODE.TURBO end

    -- Captains
    local cm = GetMode("CM", 2)
    local cd = GetMode("CD", 3)
    if mode == cm or mode == cd then return GAME_MODE.CAPTAINS_MODE end

    -- Drafts
    local sd = GetMode("SD", 4)
    local rd = GetMode("RD", 5)
    if mode == sd or mode == rd then return GAME_MODE.SINGLE_DRAFT end

    -- Random
    local ar = GetMode("AR", 6)
    local ardm = GetMode("ARDM", 22)
    if mode == ar or mode == ardm then return GAME_MODE.ALL_RANDOM end

    -- Ability Draft
    local ad = GetMode("AD", GetMode("ABILITY_DRAFT", 7))
    if mode == ad then return GAME_MODE.ABILITY_DRAFT end

    return GAME_MODE.UNKNOWN
end

local function prettyHero(name)
    local n = name:gsub("npc_dota_hero_", ""):gsub("_", " ")
    n = n:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
    if #n > 16 then n = n:sub(1, 14) .. ".." end
    return n
end

local function screenSz()
    local ok, r = pcall(function()
        if Render.ScreenSize then return Render.ScreenSize() end
        if Render.GetScreenSize then return Render.GetScreenSize() end
        if Engine.GetScreenSize then return Engine.GetScreenSize() end
    end)
    if ok and r then
        if type(r) == "userdata" or type(r) == "table" then return r.x or 1920, r.y or 1080 end
    end
    return 1920, 1080
end

local function safeStatic(tbl, method, ...)
    if not tbl then return nil end
    local okLookup, fn = pcall(function() return tbl[method] end)
    if not okLookup or not fn then return nil end
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function safeMethod(obj, method, ...)
    if not obj then return nil end
    local okLookup, fn = pcall(function() return obj[method] end)
    if not okLookup or not fn then return nil end

    -- Prefer regular method call with self, then fall back to bindings that don't expect self.
    local ok, r = pcall(fn, obj, ...)
    if ok then return r end

    ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function numOrNil(v)
    if v == nil then return nil end
    if type(v) == "number" then return v end
    local ok, n = pcall(tonumber, v)
    if ok then return n end
    return nil
end

local function findPlayerByID(playerID)
    if not playerID or playerID < 0 then return nil end
    local allPlayers = safeStatic(Players, "GetAll")
    if allPlayers then
        for _, p in ipairs(allPlayers) do
            local pid = safeMethod(p, "GetPlayerID") or safeStatic(Player, "GetPlayerID", p)
            if pid == playerID then
                return p
            end
        end
    end
    return nil
end

local function getLocalPlayerObject()
    local p = safeStatic(Players, "GetLocal")
    if p then return p end
    p = safeStatic(Player, "GetLocal")
    if p then return p end

    local me = safeStatic(Heroes, "GetLocal")
    if not me then return nil end
    p = safeMethod(me, "GetPlayer")
    if p then return p end
    local playerID = safeMethod(me, "GetPlayerID")
    if playerID and playerID >= 0 then
        return findPlayerByID(playerID)
    end
    return nil
end

local function getPlayerCurrentGold(player)
    if not player then return nil end

    local g = numOrNil(safeMethod(player, "GetGold")) or numOrNil(safeStatic(Player, "GetGold", player))
    if g and g >= 0 then return g end

    local rg = numOrNil(safeMethod(player, "GetReliableGold")) or numOrNil(safeStatic(Player, "GetReliableGold", player))
    local ug = numOrNil(safeMethod(player, "GetUnreliableGold")) or numOrNil(safeStatic(Player, "GetUnreliableGold", player))
    if rg and ug then
        local s = rg + ug
        if s >= 0 then return s end
    end

    local tg = numOrNil(safeMethod(player, "GetTotalGold")) or numOrNil(safeStatic(Player, "GetTotalGold", player))
    if tg and tg >= 0 then return tg end

    return nil
end

local function getHeroCurrentGold(hero)
    if not hero then return nil end
    local g = numOrNil(safeMethod(hero, "GetGold")) or numOrNil(safeStatic(Heroes, "GetGold", hero))
    if g and g >= 0 then return g end
    local rg = numOrNil(safeMethod(hero, "GetReliableGold")) or numOrNil(safeStatic(Heroes, "GetReliableGold", hero))
    local ug = numOrNil(safeMethod(hero, "GetUnreliableGold")) or numOrNil(safeStatic(Heroes, "GetUnreliableGold", hero))
    if rg and ug then
        local s = rg + ug
        if s >= 0 then return s end
    end
    return nil
end

local function refreshMyGold()
    local p = getLocalPlayerObject()
    local g = getPlayerCurrentGold(p)
    if g == nil then
        g = getHeroCurrentGold(safeStatic(Heroes, "GetLocal"))
    end
    if g ~= nil then
        S.myGold = g
        S.myGoldKnown = true
        return g
    end
    S.myGoldKnown = false
    return S.myGold or 0
end

local function refreshRuntimeTestContext()
    local modeId = numOrNil(safeStatic(GameRules, "GetGameMode"))
    local playerCount = numOrNil(safeStatic(Players, "Count"))
    if playerCount == nil then
        local all = safeStatic(Players, "GetAll")
        if all then playerCount = #all end
    end
    local localPlayer = getLocalPlayerObject()
    local localHero = (localPlayer and safeMethod(localPlayer, "GetHero")) or safeStatic(Heroes, "GetLocal")

    S.rawGameModeId = modeId or -1
    S.playerCount = playerCount or 0
    S.testContextKind = nil

    -- Heuristic: "Try Hero" and most sandbox lobbies run as custom mode (15).
    if modeId == 15 then
        if localHero and (not playerCount or playerCount <= 1) then
            S.testContextKind = "tryhero"
        elseif playerCount and playerCount > 1 then
            S.testContextKind = "lobby"
        else
            S.testContextKind = "custom"
        end
    end
end

local function StyleColor(style, key, alphaOverride)
    if not style then return col(200, 200, 200, alphaOverride or 255) end
    local c = style[key]
    if not c then return col(200, 200, 200, alphaOverride or 255) end
    return Color(c.r or 200, c.g or 200, c.b or 200, alphaOverride or c.a or 255)
end

local function colorPart(c, key, fallback)
    local v = c and c[key]
    if type(v) ~= "number" then v = tonumber(v) or fallback end
    return clamp(v or fallback or 0, 0, 255)
end

local function withAlpha(c, alpha)
    return col(colorPart(c, "r", 200), colorPart(c, "g", 200), colorPart(c, "b", 200), alpha or colorPart(c, "a", 255))
end

local function mixColor(a, b, t, alpha)
    t = clamp(t or 0.5, 0, 1)
    local r = colorPart(a, "r", 0) + (colorPart(b, "r", 0) - colorPart(a, "r", 0)) * t
    local g = colorPart(a, "g", 0) + (colorPart(b, "g", 0) - colorPart(a, "g", 0)) * t
    local bl = colorPart(a, "b", 0) + (colorPart(b, "b", 0) - colorPart(a, "b", 0)) * t
    return col(r + 0.5, g + 0.5, bl + 0.5, alpha or colorPart(a, "a", 255))
end

local function linearChannel(v)
    v = clamp(v or 0, 0, 255) / 255
    if v <= 0.03928 then return v / 12.92 end
    return ((v + 0.055) / 1.055) ^ 2.4
end

local function relativeLuma(c)
    return 0.2126 * linearChannel(colorPart(c, "r", 0))
        + 0.7152 * linearChannel(colorPart(c, "g", 0))
        + 0.0722 * linearChannel(colorPart(c, "b", 0))
end

local function contrastRatio(a, b)
    local la, lb = relativeLuma(a), relativeLuma(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

local function readableColor(fg, bg, minRatio, lightFallback, darkFallback)
    local alpha = colorPart(fg, "a", 255)
    local candidate = withAlpha(fg, alpha)
    if contrastRatio(candidate, bg) >= (minRatio or 4.5) then return candidate end

    local light = withAlpha(lightFallback or col(242, 245, 255, alpha), alpha)
    local dark = withAlpha(darkFallback or col(22, 26, 34, alpha), alpha)
    if contrastRatio(light, bg) >= contrastRatio(dark, bg) then
        return light
    end
    return dark
end

local function readableMutedColor(rawDim, bg, text, minRatio, alpha)
    local targetAlpha = alpha or colorPart(rawDim, "a", 180)
    local candidate = withAlpha(rawDim, targetAlpha)
    if contrastRatio(candidate, bg) >= (minRatio or 3.0) then return candidate end

    candidate = mixColor(bg, text, 0.64, targetAlpha)
    if contrastRatio(candidate, bg) >= (minRatio or 3.0) then return candidate end

    local light = mixColor(bg, col(255, 255, 255, targetAlpha), 0.72, targetAlpha)
    local dark = mixColor(bg, col(0, 0, 0, targetAlpha), 0.72, targetAlpha)
    return readableColor(candidate, bg, minRatio or 3.0, light, dark)
end

local function readableAccentColor(rawAccent, bg, text)
    local alpha = colorPart(rawAccent, "a", 255)
    local candidate = withAlpha(rawAccent, alpha)
    if contrastRatio(candidate, bg) >= 2.2 then return candidate end

    local fallback = relativeLuma(bg) < 0.45 and col(255, 205, 70, alpha) or col(0, 110, 180, alpha)
    if contrastRatio(fallback, bg) >= 2.2 then return fallback end
    return withAlpha(text, alpha)
end

local function getEnemyFilterValue(name)
    if not UI.enemyFilterList or not UI.enemyFilterList.Get then return nil end
    local ok, val = pcall(function() return UI.enemyFilterList:Get(name) end)
    if ok then return val end
    return nil
end

local function shouldIncludeEnemy(name)
    local mode = sg(UI.enemyFilterMode, 0)
    if mode == 0 or not UI.enemyFilterList then return true end
    local selected = getEnemyFilterValue(name)
    if mode == 1 then
        return selected == true
    elseif mode == 2 then
        return selected ~= true
    end
    return true
end

local function refreshEnemyFilterList()
    if not UI.enemyFilterList or not UI.enemyFilterList.Update then return end
    if #S.enemyHeroes == 0 then
        S.enemyFilterSnapshot = {}
        UI.enemyFilterList:Update({}, true)
        return
    end

    local names = {}
    for _, enemy in ipairs(S.enemyHeroes) do
        table.insert(names, enemy.name)
    end

    local changed = #names ~= #S.enemyFilterSnapshot
    if not changed then
        for i, name in ipairs(names) do
            if name ~= S.enemyFilterSnapshot[i] then
                changed = true
                break
            end
        end
    end

    if not changed then return end

    local entries = {}
    for _, name in ipairs(names) do
        local icon = "panorama/images/heroes/icons/" .. name .. "_png.vtex_c"
        local defaultOn = getEnemyFilterValue(name)
        if defaultOn == nil then defaultOn = false end
        table.insert(entries, {name, icon, defaultOn})
    end

    UI.enemyFilterList:Update(entries, true)
    S.enemyFilterSnapshot = names
end

local function buildTagCounts(tags)
    local counts = {}
    if not tags then return counts end
    for _, tag in ipairs(tags) do
        counts[tag] = (counts[tag] or 0) + 1
    end
    return counts
end

local function tableContains(tbl, val)
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

local function listContainsCanonicalItem(list, itemName)
    if not list or not itemName then return false end
    local canonical = canonItemName(itemName)
    for _, entry in ipairs(list) do
        if canonItemName(entry) == canonical then
            return true
        end
    end
    return false
end

local function getHeroProfile(heroName)
    local roleInfo = heroName and HERO_ROLES[heroName]
    if not roleInfo then return nil, nil end
    return roleInfo.role, roleInfo.style
end

local function countMatches(tbl, vals)
    local c = 0
    for _, v in ipairs(vals) do if tableContains(tbl, v) then c = c + 1 end end
    return c
end

local function shortText(txt, limit)
    txt = txt or ""
    if #txt <= limit then return txt end
    return txt:sub(1, math.max(1, limit - 2)) .. ".."
end

local tSz

local function shortTextByWidth(sz, txt, maxW)
    txt = tostring(txt or "")
    if txt == "" then return txt end
    if maxW <= 6 then return "" end
    if tSz(sz, txt).x <= maxW then return txt end

    local suffix = ".."
    local out = txt
    while #out > 1 and tSz(sz, out .. suffix).x > maxW do
        out = out:sub(1, #out - 1)
    end
    if out == "" then return suffix end
    return out .. suffix
end

local function applyRolePenalty(score, itemName, myRole, myStyle)
    if score <= 0 then return score end
    if not myRole and not myStyle then return score end
    itemName = canonItemName(itemName)
    local penalty = ITEM_ROLE_PENALTY[itemName]
    if not penalty then return score end
    local penalized = false
    if penalty.bad_roles and myRole then
        for _, br in ipairs(penalty.bad_roles) do
            if br == myRole then penalized = true; break end
        end
    end
    if not penalized and penalty.bad_styles and myStyle then
        for _, bs in ipairs(penalty.bad_styles) do
            if bs == myStyle then penalized = true; break end
        end
    end
    if penalized then
        local factor = score >= 24 and 0.45 or 0.25
        score = math.max(1, math.floor(score * factor))
    end
    return score
end

local function itemHasTag(itemDef, tag)
    if not itemDef.tags then return false end
    for _, t in ipairs(itemDef.tags) do
        if t == tag then return true end
    end
    return false
end

local function stylePreferenceBonus(itemDef, ctx)
    if not itemDef.tags or not ctx then return 0 end
    local bonus = 0
    local tags = itemDef.tags
    local role = ctx.myRole
    local style = ctx.myStyle

    if style == "phys" and (tableContains(tags, "phys_dps") or tableContains(tags, "attack_speed")) then
        bonus = bonus + 2
    elseif style == "magic" and (tableContains(tags, "magic_burst") or tableContains(tags, "magic_amp") or tableContains(tags, "mana")) then
        bonus = bonus + 2
    elseif style == "utility" and (tableContains(tags, "team") or tableContains(tags, "save") or tableContains(tags, "dispel")) then
        bonus = bonus + 2
    elseif style == "hybrid" and (tableContains(tags, "phys_dps") and tableContains(tags, "magic_burst")) then
        bonus = bonus + 2
    end

    if role == "support" or role == "hardsupport" then
        if tableContains(tags, "team") or tableContains(tags, "save") or tableContains(tags, "heal") then
            bonus = bonus + 2
        end
    elseif role == "carry" and (tableContains(tags, "phys_dps") or tableContains(tags, "farm")) then
        bonus = bonus + 1
    end

    return bonus
end

local function applyHeroSpecificAdjust(score, heroName, itemName)
    local spec = HERO_SPECIFIC_ITEMS[heroName]
    if not spec then return score end
    itemName = canonItemName(itemName)
    if spec.good_items and listContainsCanonicalItem(spec.good_items, itemName) then
        score = score + 10
    end
    if score > 0 and spec.bad_items and listContainsCanonicalItem(spec.bad_items, itemName) then
        score = math.max(0, math.floor(score * 0.1))
    end
    return score
end

local function itemAllowedForProfile(itemName, myRole, myStyle)
    local canonical = canonItemName(itemName)
    local itemDef = ITEM_LOOKUP[canonical]
    if not itemDef then return canonical, true end
    local probe = applyRolePenalty(10, canonical, myRole, myStyle)
    return canonical, probe > 1
end

local ITEM_COUNTER_PROFILES = {
    item_magic_wand = {threats={magic_burst=1.5, spell_spam=2, disable=1}},
    item_bracer = {threats={phys_burst=2, jump_burst=2, carry=1}},
    item_soul_ring = {threats={mana_burn=2}},
    item_phase_boots = {threats={phys_dps=1.5, armor_reduce=1.5}},
    item_power_treads = {threats={mana_burn=1, phys_dps=1}},
    item_arcane_boots = {threats={mana_burn=1.5, spell_spam=1}},
    item_tranquil_boots = {threats={slow=1, poison=1}},
    item_boots_of_bearing = {threats={slow=2, summon_swarm=1.5, teamfight_disable=1.5}},

    item_ghost = {threats={phys_burst=6, jump_burst=5, carry=3, duel=4, low_hp_fighter=3, single_target_focus=4}},
    item_blade_mail = {threats={phys_burst=4, magic_burst=2, jump_burst=4, low_hp_fighter=2}},
    item_vanguard = {threats={phys_dps=3, summon_swarm=4, illusions=3, push=2}},
    item_splintmail = {threats={phys_dps=3, phys_burst=2, armor_reduce=2}},
    item_pavise = {threats={phys_burst=4, phys_dps=3, jump_burst=3}},
    item_crimson_guard = {threats={illusion_core=6, illusions=5, summon_swarm=5, summons=4, phys_dps=3, push=3}},
    item_assault = {threats={phys_dps=4, armor_reduce=4, push=2, illusion_core=2}},
    item_shivas_guard = {threats={heal=4, regen=5, illusion_core=5, illusions=4, phys_dps=3, attack_speed=3, low_hp_fighter=3}},
    item_heavens_halberd = {threats={carry=5, phys_dps=5, phys_burst=4, jump_burst=3, low_hp_fighter=4, single_target_focus=4}},
    item_solar_crest = {threats={phys_burst=2, armor_reduce=2, roshan=2}},

    item_pipe = {threats={magic_burst=6, spell_spam=5, teamfight_disable=2, poison=3, global=3}},
    item_glimmer_cape = {threats={magic_burst=4, single_target_disable=3, pickoff=3, global=2}},
    item_mage_slayer = {threats={magic_burst=5, spell_spam=5, spell_lifesteal=4}},
    item_shawl = {threats={magic_burst=3, spell_spam=2}},
    item_consecrated_wraps = {threats={magic_burst=4, slow=3, poison=2, spell_spam=2}},
    item_black_king_bar = {threats={magic_burst=5, disable=5, stun=4, silence=5, hex=5, root=3, fear=4, global_silence=6, teamfight_disable=3}},

    item_spirit_vessel = {threats={heal=6, regen=6, save=4, save_core=5, spell_lifesteal=5, low_hp_fighter=5, tanky=3}},
    item_monkey_king_bar = {threats={evasion=6, evasion_core=7, refraction=3}},
    item_dust = {threats={invis=7, permanent_invis=8, invis_escape=7, invis_trap=5}},
    item_ward_sentry = {threats={invis=6, permanent_invis=7, invis_escape=6, invis_trap=6}},

    item_mjollnir = {threats={illusion_core=7, illusions=6, summon_swarm=5, summons=4, push=3}},
    item_battlefury = {threats={illusion_core=4, illusions=4, summon_swarm=3, summons=3}},
    item_radiance = {threats={illusion_core=4, illusions=4, summons=3, invis=2, evasion=2}},
    item_maelstrom = {threats={illusion_core=5, illusions=5, summon_swarm=4, summons=3}},
    item_gungir = {threats={mobility=5, blink_escape=6, ball_escape=5, phase_escape=4, invis_escape=4, illusion_core=3}},

    item_blink = {threats={ranged=4, siege=4, backline=3, split_push=3, spell_spam=2}},
    item_force_staff = {threats={slow=4, root=4, leash=5, hook_pickoff=5, arena_control=4, cogs=5, jump_burst=3, single_target_disable=3}},
    item_hurricane_pike = {threats={ranged=3, slow=3, hook_pickoff=4, jump_burst=3, phys_dps=2}},
    item_harpoon = {threats={ranged=3, mobility=3, blink_escape=2}},

    item_lotus_orb = {threats={single_target_disable=6, doom=5, duel=5, hex=5, silence=4, stun=3, track=4, armor_reduce=3, hook_pickoff=4}},
    item_manta = {threats={silence=5, global_silence=5, slow=3, root=4, track=3, poison=2}},
    item_disperser = {threats={silence=4, global_silence=4, slow=5, root=5, leash=4, mana_shield=3, mobility=2}},
    item_cyclone = {threats={silence=4, slow=3, root=3, phys_burst=3, low_hp_fighter=4, rupture=5}},
    item_sphere = {threats={single_target_disable=7, doom=7, duel=7, hex=5, hook_pickoff=5, bkb_piercing_disable=4, pickoff=4}},
    item_aeon_disk = {threats={phys_burst=5, magic_burst=5, jump_burst=5, arena_control=5, bkb_piercing_disable=5, pickoff=4}},
    item_wind_waker = {threats={bkb_piercing_disable=6, arena_control=5, single_target_disable=4, phys_burst=4, magic_burst=4}},

    item_skadi = {threats={heal=5, regen=5, mobility=3, low_hp_fighter=4, mana_shield=3, lifesteal=5}},
    item_abyssal_blade = {threats={magic_immune=5, carry=4, mobility=3, low_hp_fighter=4}},
    item_nullifier = {threats={save=7, save_core=8, invis=4, phase_escape=3, evasion=3, ghost_save=6}},
    item_bloodthorn = {threats={evasion=5, evasion_core=6, mobility=5, phase_escape=5, blink_escape=5, magic_burst=3, spell_spam=3}},
    item_silver_edge = {threats={breakable=7, tanky=4, regen=3, evasion=2, dispersion=5}},
    item_diffusal_blade = {threats={mana_shield=7, mana_dependent=4, low_mana=3, mobility=2}},
    item_rod_of_atos = {threats={mobility=4, blink_escape=4, ball_escape=4, invis_escape=3, ranged=2}},
    item_orchid = {threats={mobility=5, phase_escape=5, ball_escape=6, spell_spam=4, magic_burst=4, save_core=3}},
    item_sheepstick = {threats={carry=4, mobility=5, magic_immune=3, phase_escape=5, ball_escape=5, low_hp_fighter=4, save_core=4}},

    item_mekansm = {threats={magic_burst=2, phys_burst=2, push=2}},
    item_essence_distiller = {threats={magic_burst=3, phys_burst=3, jump_burst=2}},
    item_guardian_greaves = {threats={silence=4, disable=3, magic_burst=2, poison=2}},
    item_holy_locket = {threats={magic_burst=2, phys_burst=2, heal=2}},
    item_vladmir = {threats={armor_reduce=2, phys_dps=2, push=2}},
    item_dagon = {threats={low_hp_fighter=3, invis_escape=2, pickoff=2}},
    item_angels_demise = {threats={magic_burst=3, mobility=3, tanky=2, regen=2}},
    item_crellas_crozier = {threats={slow=3, root=3, hook_pickoff=3, pickoff=2}},
}

local function getItemCounterProfile(itemName)
    return ITEM_COUNTER_PROFILES[canonItemName(itemName)] or ITEM_COUNTER_PROFILES[itemName]
end

local function ownedItemContains(ownedItems, itemName)
    if not ownedItems or not itemName then return false end
    local canonical = canonItemName(itemName)
    local engineName = engineItemName(itemName)
    return ownedItems[itemName] or ownedItems[canonical] or ownedItems[engineName] or false
end

local function scaledThreatCount(count)
    count = count or 0
    if count <= 0 then return 0 end
    return 1 + math.max(0, count - 1) * 0.65
end

local function phaseFitFactor(itemDef, phase, gameMode)
    if not itemDef or not itemDef.phase then return 0 end
    if tableContains(itemDef.phase, phase) then return 1.0 end

    local minPhase, maxPhase = 9, 0
    for _, p in ipairs(itemDef.phase) do
        if p < minPhase then minPhase = p end
        if p > maxPhase then maxPhase = p end
    end

    if gameMode == GAME_MODE.TURBO then
        if phase < minPhase then return 0.75 end
        if phase > maxPhase then return itemHasTag(itemDef, "farm") and 0.2 or 0.55 end
    end

    if phase < minPhase then
        local gap = minPhase - phase
        return gap == 1 and 0.55 or 0.3
    end
    if phase > maxPhase then
        if itemHasTag(itemDef, "farm") then return 0.15 end
        return 0.45
    end
    return 1.0
end

local function directCounterWeight(counterData, itemName)
    if not counterData then return 0 end
    local canonical = canonItemName(itemName)
    if counterData.priority then
        return counterData.priority[canonical] or counterData.priority[itemName] or counterData.priority[engineItemName(itemName)] or 0
    end
    return listContainsCanonicalItem(counterData.items, itemName) and 10 or 0
end

local function computeItemScore(itemDef, ctx, withBreakdown)
    if not itemDef or not ctx then return 0, nil end
    if ownedItemContains(ctx.ownedItems, itemDef.name) then return -1, nil end

    local enemyTags = ctx.enemyTags or {}
    local activeEnemyCount = math.max(1, ctx.activeEnemyCount or 0)
    local score = 0
    local directScore = 0
    local tacticalScore = 0
    local breakMap = withBreakdown and {} or nil

    local function addBreak(key, delta)
        if not breakMap or not key or not delta or delta == 0 then return end
        delta = math.floor(delta)
        if delta == 0 then return end
        breakMap[key] = (breakMap[key] or 0) + delta
    end

    for _, enemy in ipairs(ctx.enemyHeroes or {}) do
        if enemy.included then
            local cd = HERO_COUNTERS[enemy.name]
            if cd and listContainsCanonicalItem(cd.items, itemDef.name) then
                local w = directCounterWeight(cd, itemDef.name)
                if w <= 0 then w = 10 end
                if (enemy.level or 0) >= 18 then w = w + 2
                elseif (enemy.level or 0) >= 12 then w = w + 1 end
                directScore = directScore + w
            end
        end
    end
    if directScore > 0 then
        score = score + directScore
        addBreak("hero_counter", directScore)
    end

    local profile = getItemCounterProfile(itemDef.name)
    if profile and profile.threats then
        for tag, weight in pairs(profile.threats) do
            local cnt = enemyTags[tag] or 0
            if cnt > 0 then
                local d = weight * scaledThreatCount(cnt)
                tacticalScore = tacticalScore + d
                addBreak("profile:" .. tag, d)
            end
        end
    end

    if itemDef.triggers then
        for _, tr in ipairs(itemDef.triggers) do
            local cnt = enemyTags[tr] or 0
            if cnt > 0 then
                local d = 2.25 * scaledThreatCount(cnt)
                tacticalScore = tacticalScore + d
                addBreak("trigger:" .. tr, d)
            end
        end
    end

    for _, rule in ipairs(COUNTER_RULES) do
        local totalEnemyTags = 0
        local matched = true
        for _, rTag in ipairs(rule.tags) do
            local cnt = enemyTags[rTag] or 0
            if cnt <= 0 then matched = false; break end
            totalEnemyTags = totalEnemyTags + cnt
        end
        if matched then
            local itemMatch = countMatches(itemDef.tags or {}, rule.suggest)
            if itemMatch > 0 then
                local d = itemMatch * rule.weight * scaledThreatCount(totalEnemyTags) * 0.65
                tacticalScore = tacticalScore + d
                addBreak("counter_rules", d)
            end
        end
    end

    score = score + tacticalScore
    if score <= 0 then return 0, nil end

    if ctx.trackEnemyItems and ctx.enemyItemCounts then
        local counts = ctx.enemyItemCounts
        local bkbCount = counts["item_black_king_bar"] or 0
        if bkbCount > 0 and (itemDef.name == "item_nullifier" or itemDef.name == "item_abyssal_blade" or itemDef.name == "item_sheepstick") then
            local d = bkbCount * 4
            score = score + d
            addBreak("enemy_item:bkb", d)
        end
        local linkenCount = counts["item_sphere"] or counts["item_linkens"] or 0
        if linkenCount > 0 and (itemHasTag(itemDef, "disable") or itemDef.name == "item_nullifier" or itemDef.name == "item_diffusal_blade") then
            local d = linkenCount * 3
            score = score + d
            addBreak("enemy_item:linkens", d)
        end
        local aeonCount = counts["item_aeon_disk"] or 0
        if aeonCount > 0 and (itemDef.name == "item_nullifier" or itemDef.name == "item_orchid" or itemDef.name == "item_bloodthorn") then
            local d = aeonCount * 6
            score = score + d
            addBreak("enemy_item:aeon", d)
        end
        local ghostCount = counts["item_ghost"] or counts["item_ethereal_blade"] or 0
        if ghostCount > 0 and itemDef.name == "item_nullifier" then
            local d = ghostCount * 6
            score = score + d
            addBreak("enemy_item:ghost", d)
        end
        local glimmerCount = counts["item_glimmer_cape"] or counts["item_glimmer"] or 0
        if glimmerCount > 0 and (itemDef.name == "item_dust" or itemDef.name == "item_ward_sentry" or itemDef.name == "item_nullifier") then
            local d = glimmerCount * 5
            score = score + d
            addBreak("enemy_item:glimmer", d)
        end
        local butterflyCount = counts["item_butterfly"] or counts["item_talisman_of_evasion"] or 0
        if butterflyCount > 0 and (itemDef.name == "item_monkey_king_bar" or itemDef.name == "item_bloodthorn") then
            local d = butterflyCount * 7
            score = score + d
            addBreak("enemy_item:evasion", d)
        end
        local satanicCount = counts["item_satanic"] or counts["item_heart"] or counts["item_bloodstone"] or 0
        if satanicCount > 0 and (itemDef.name == "item_spirit_vessel" or itemDef.name == "item_skadi" or itemDef.name == "item_shivas_guard") then
            local d = satanicCount * 5
            score = score + d
            addBreak("enemy_item:sustain", d)
        end
    end

    if itemHasTag(itemDef, "team") then
        local magicLoad = (enemyTags.magic_burst or 0) + (enemyTags.spell_spam or 0)
        local physLoad = (enemyTags.phys_dps or 0) + (enemyTags.illusion_core or 0) + (enemyTags.summon_swarm or 0)
        if itemHasTag(itemDef, "vs_magic") and magicLoad >= math.min(3, activeEnemyCount) then
            score = score + 3
            addBreak("team_need", 3)
        elseif itemHasTag(itemDef, "vs_phys") and physLoad >= math.min(3, activeEnemyCount) then
            score = score + 3
            addBreak("team_need", 3)
        end
    end

    if score > 0 and ctx.myGoldKnown and ctx.myGold and ctx.myGold >= itemDef.cost then
        score = score + 1.5
        addBreak("affordable", 1.5)
    end

    if score > 0 then
        local d = stylePreferenceBonus(itemDef, ctx)
        if d ~= 0 then
            score = score + d
            addBreak("style_bonus", d)
        end
    end

    if ctx.showNetWorth and ctx.gameTempo then
        local before = score
        if ctx.gameTempo == "ahead" then
            if itemDef.cost >= 4000 and (itemHasTag(itemDef, "phys_dps") or itemHasTag(itemDef, "disable") or itemHasTag(itemDef, "vs_save")) then
                score = score + 2
            end
        elseif ctx.gameTempo == "behind" then
            if itemDef.cost <= 3100 and (itemHasTag(itemDef, "vs_phys") or itemHasTag(itemDef, "vs_magic") or itemHasTag(itemDef, "save") or itemHasTag(itemDef, "dispel")) then
                score = score + 4
            end
            if itemDef.cost >= 5600 and directScore <= 0 then
                score = math.max(1, math.floor(score * 0.55))
            end
        end
        addBreak("tempo", score - before)
    end

    do
        local before = score
        score = applyRolePenalty(score, itemDef.name, ctx.myRole, ctx.myStyle)
        addBreak("role_penalty", score - before)
    end

    do
        local before = score
        score = applyHeroSpecificAdjust(score, ctx.heroName, itemDef.name)
        addBreak("hero_specific", score - before)
    end

    local modeMultipliers = MODE_PHASE_MULTIPLIERS[ctx.gameMode or GAME_MODE.UNKNOWN] or MODE_PHASE_MULTIPLIERS[GAME_MODE.UNKNOWN]
    local phaseKey = ctx.phase == PHASE_EARLY and "early" or (ctx.phase == PHASE_MID and "mid" or "late")
    local multiplier = modeMultipliers[phaseKey] or 1.0

    do
        local before = score
        if ctx.gameMode == GAME_MODE.TURBO then
            if itemDef.cost < 1400 and tableContains(itemDef.phase, PHASE_EARLY) and not tableContains(itemDef.phase, PHASE_MID) then
                score = score * 0.35
            end
            if itemDef.cost >= 3000 and directScore > 0 then
                score = score + 2
            end
        elseif ctx.gameMode == GAME_MODE.RANKED and itemDef.cost >= 1800 and itemDef.cost <= 4800 then
            score = score + 1
        end
        score = score * multiplier
        addBreak("mode_adjust", score - before)
    end

    do
        local before = score
        local factor = phaseFitFactor(itemDef, ctx.phase, ctx.gameMode)
        if directScore >= 14 and factor < 0.55 then factor = 0.55 end
        score = score * factor
        addBreak("phase_fit", score - before)
    end

    score = math.floor(score + 0.5)
    if score <= 0 then return 0, nil end

    if not breakMap then
        return score, nil
    end

    local breakdown = {}
    for key, delta in pairs(breakMap) do
        if delta ~= 0 then
            table.insert(breakdown, {key = key, delta = delta})
        end
    end
    table.sort(breakdown, function(a, b)
        local aa = math.abs(a.delta or 0)
        local bb = math.abs(b.delta or 0)
        if aa ~= bb then return aa > bb end
        if (a.delta or 0) ~= (b.delta or 0) then return (a.delta or 0) > (b.delta or 0) end
        return tostring(a.key) < tostring(b.key)
    end)
    table.insert(breakdown, {key = "final", delta = score})
    return score, breakdown
end

local function sumBreakdownPrefix(breakdown, prefix)
    local total = 0
    for _, entry in ipairs(breakdown or {}) do
        local k = tostring(entry.key or "")
        if k:find(prefix, 1, true) == 1 and (entry.delta or 0) > 0 then
            total = total + (entry.delta or 0)
        end
    end
    return total
end

local function breakdownKeyLabel(key)
    if not key then return "" end
    local tbl = L_BREAKDOWN_LABELS[LANG] or L_BREAKDOWN_LABELS.en
    local v = tbl[key]
    if v and v ~= "" then return v end
    v = L_BREAKDOWN_LABELS.en[key]
    if v and v ~= "" then return v end
    if key:find("trigger:", 1, true) == 1 then
        return key:sub(9):gsub("_", " ")
    end
    if key:find("profile:", 1, true) == 1 then
        return key:sub(9):gsub("_", " ")
    end
    return tostring(key):gsub("_", " ")
end

local function classifySuggestionCategory(itemDef, score, breakdown)
    if not itemDef then return "situational" end

    local defensive = itemHasTag(itemDef, "save") or itemHasTag(itemDef, "dispel")
        or itemHasTag(itemDef, "vs_magic") or itemHasTag(itemDef, "vs_phys")
        or itemHasTag(itemDef, "block_spell")
    local triggerPower = sumBreakdownPrefix(breakdown, "trigger:")
    local counterPower = sumBreakdownPrefix(breakdown, "counter_rules")
    local heroPower = sumBreakdownPrefix(breakdown, "hero_counter")
    local profilePower = sumBreakdownPrefix(breakdown, "profile:")
    local enemyItemPower = sumBreakdownPrefix(breakdown, "enemy_item:")

    if defensive and (score >= 10 or triggerPower >= 8 or heroPower >= 10 or enemyItemPower >= 6) then
        return "must_have"
    end
    if (counterPower + heroPower + profilePower + enemyItemPower) >= 10 and score >= 9 then
        return "must_have"
    end

    local luxury = itemDef.cost >= 4500 and (
        itemHasTag(itemDef, "phys_dps") or itemHasTag(itemDef, "magic_burst")
        or itemHasTag(itemDef, "crit") or itemHasTag(itemDef, "attack_speed")
        or itemHasTag(itemDef, "farm")
    )
    if luxury then
        return "luxury"
    end
    return "situational"
end

local function buildSuggestionMeta(itemDef, ctx, score, breakdown)
    breakdown = breakdown or {{key = "final", delta = score}}

    local highlights = {}
    for _, entry in ipairs(breakdown) do
        if entry.key ~= "final" and (entry.delta or 0) ~= 0 then
            table.insert(highlights, {
                key = entry.key,
                delta = entry.delta,
                label = breakdownKeyLabel(entry.key),
            })
        end
    end
    table.sort(highlights, function(a, b)
        local ap = (a.delta or 0) > 0
        local bp = (b.delta or 0) > 0
        if ap ~= bp then return ap end
        local aa = math.abs(a.delta or 0)
        local bb = math.abs(b.delta or 0)
        if aa ~= bb then return aa > bb end
        return tostring(a.label) < tostring(b.label)
    end)

    local topReasons = {}
    for _, h in ipairs(highlights) do
        if (h.delta or 0) > 0 and h.label and h.label ~= "" then
            table.insert(topReasons, h.label)
            if #topReasons >= 3 then break end
        end
    end
    if #topReasons == 0 then
        local reason = itemDef and LR(itemDef.name) or ""
        if reason ~= "" then table.insert(topReasons, reason) end
    end

    return {
        category = classifySuggestionCategory(itemDef, score, breakdown),
        breakdown = breakdown,
        breakdownHighlights = highlights,
        topReasons = topReasons,
    }
end

local ITEM_FUNCTION_WEIGHTS = {
    save = 5,
    dispel = 5,
    block_spell = 6,
    vs_magic = 4,
    vs_phys = 4,
    anti_heal = 5,
    vs_invis = 6,
    detection = 6,
    vs_illusions = 5,
    vs_evasion = 5,
    vs_save = 5,
    disarm = 5,
    ["break"] = 5,
    silence = 4,
    root = 4,
    hex = 5,
    stun = 4,
    magic_immune = 4,
    magic_resist = 3,
    barrier = 3,
    mobility = 3,
    team = 2,
    armor = 2,
}

local ITEM_FUNCTION_ALIASES = {
    magic_resist = "vs_magic",
    barrier = "vs_magic",
}

local function getItemFunctionKeys(itemDef)
    local keys = {}
    local seen = {}
    if not itemDef or not itemDef.tags then return keys end
    for _, tag in ipairs(itemDef.tags) do
        local key = ITEM_FUNCTION_ALIASES[tag] or tag
        if ITEM_FUNCTION_WEIGHTS[key] and not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
    return keys
end

local function appendBreakdownDelta(breakdown, key, delta)
    local out = {}
    for _, entry in ipairs(breakdown or {}) do
        if entry.key ~= "final" then
            table.insert(out, {key = entry.key, delta = entry.delta})
        end
    end
    if delta and delta ~= 0 then
        table.insert(out, {key = key, delta = delta})
    end
    return out
end

local function computeFunctionOverlapPenalty(entry, functionCounts)
    local penalty = 0
    for _, key in ipairs(getItemFunctionKeys(entry.item)) do
        local count = functionCounts[key] or 0
        if count > 0 then
            penalty = penalty + (ITEM_FUNCTION_WEIGHTS[key] or 0) * count
        end
    end

    if penalty > 0 and entry.category == "must_have" then
        penalty = math.floor(penalty * 0.5)
    end

    local heroFit = sumBreakdownPrefix(entry.breakdown, "hero_specific")
    if heroFit > 0 then
        penalty = math.max(0, penalty - math.floor(heroFit / 2))
    end

    return penalty
end

local function buildDiverseSuggestions(scored, ctx, maxItems)
    local remaining = {}
    local selected = {}
    local functionCounts = {}

    for _, entry in ipairs(scored or {}) do
        table.insert(remaining, entry)
    end

    while #selected < maxItems and #remaining > 0 do
        local bestIdx = nil
        local bestAdjusted = nil
        local bestPenalty = 0
        local bestEntry = nil

        for idx, entry in ipairs(remaining) do
            local penalty = computeFunctionOverlapPenalty(entry, functionCounts)
            local adjusted = math.max(1, entry.score - penalty)
            if bestAdjusted == nil
                or adjusted > bestAdjusted
                or (adjusted == bestAdjusted and entry.score > (bestEntry and bestEntry.score or -1))
                or (adjusted == bestAdjusted and entry.score == (bestEntry and bestEntry.score or -1)
                    and (entry.item.cost or 0) > ((bestEntry and bestEntry.item and bestEntry.item.cost) or 0)) then
                bestIdx = idx
                bestAdjusted = adjusted
                bestPenalty = penalty
                bestEntry = entry
            end
        end

        if not bestIdx or not bestEntry then break end

        table.remove(remaining, bestIdx)

        local adjustedScore = math.max(1, bestEntry.score - bestPenalty)
        local adjustedBreakdown = appendBreakdownDelta(bestEntry.breakdown, "function_overlap", -bestPenalty)
        table.insert(adjustedBreakdown, {key = "final", delta = adjustedScore})
        local meta = buildSuggestionMeta(bestEntry.item, ctx, adjustedScore, adjustedBreakdown)

        table.insert(selected, {
            item = bestEntry.item,
            score = adjustedScore,
            category = meta.category,
            breakdown = meta.breakdown,
            breakdownHighlights = meta.breakdownHighlights,
            topReasons = meta.topReasons,
        })

        for _, key in ipairs(getItemFunctionKeys(bestEntry.item)) do
            functionCounts[key] = (functionCounts[key] or 0) + 1
        end
    end

    return selected
end

local function buildEnemyFocusData(ctxTemplate)
    local focusEntries = {}
    for _, enemy in ipairs(S.enemyHeroes) do
        if enemy.included then
            local ctx = {}
            for k, v in pairs(ctxTemplate) do ctx[k] = v end
            ctx.enemyTags = enemy.tagCounts or {}
            ctx.enemyItemCounts = enemy.itemCounts or {}
            ctx.enemyHeroes = {enemy}
            ctx.activeEnemyCount = 1

            local scored = {}
            local function addScore(itemName, value, reason)
                local itemDef = ITEM_LOOKUP[itemName]
                if not itemDef then return end
                if ownedItemContains(ctx.ownedItems, itemName) then return end
                local entry = scored[itemName]
                if not entry then
                    entry = {item = itemDef, score = 0, reasons = {}}
                    scored[itemName] = entry
                end
                entry.score = entry.score + value
                if reason and reason ~= "" then
                    table.insert(entry.reasons, reason)
                end
            end

            local counterData = HERO_COUNTERS[enemy.name]
            if counterData and counterData.items then
                for _, rawItemName in ipairs(counterData.items) do
                    local itemName, allowed = itemAllowedForProfile(rawItemName, ctx.myRole, ctx.myStyle)
                    if allowed then
                        addScore(itemName, 30, counterData.reason or "Direct counter")
                    end
                end
            end

            for _, itemDef in ipairs(ITEM_DB) do
                local s = computeItemScore(itemDef, ctx)
                if s > 0 then
                    addScore(itemDef.name, s)
                end
            end

            local rankedItems = {}
            for _, entry in pairs(scored) do
                local reason = (#entry.reasons > 0) and entry.reasons[1] or LR(entry.item.name)
                table.insert(rankedItems, {
                    item = entry.item,
                    score = entry.score,
                    reason = reason,
                })
            end
            table.sort(rankedItems, function(a, b)
                if a.score ~= b.score then return a.score > b.score end
                return a.item.cost > b.item.cost
            end)

            local basePriority = #(HERO_TAGS[enemy.name] or {})
            if counterData then basePriority = basePriority + 10 end

            table.insert(focusEntries, {
                enemy = enemy,
                display = prettyHero(enemy.name),
                items = rankedItems,
                priority = basePriority,
            })
        end
    end
    table.sort(focusEntries, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return (a.enemy.level or 0) > (b.enemy.level or 0)
    end)
    return focusEntries
end

--------------------------------------------------------------------------------
-- IMAGE CACHE
--------------------------------------------------------------------------------
local function cacheImg(tbl, key, path)
    if tbl[key] ~= nil then return tbl[key] end
    local ok, h = pcall(Render.LoadImage, path)
    if ok and h then tbl[key] = h; return h end
    tbl[key] = false
    return nil
end

local function heroIcon(name)
    local v = S.heroIcons[name]
    if v then return v ~= false and v or nil end
    return cacheImg(S.heroIcons, name, "panorama/images/heroes/icons/" .. name .. "_png.vtex_c")
end

-- Item names where script has no underscore but panorama asset has (e.g. item_battlefury -> battle_fury)
local ITEM_ICON_NAME_OVERRIDES = {
    item_battlefury = "battle_fury",
    item_daedalus = "greater_crit",
}

local function itemIcon(name)
    name = canonItemName(name)
    local v = S.itemIcons[name]
    if v then return v ~= false and v or nil end

    local iconName = ITEM_ICON_NAME_OVERRIDES[name] or name:gsub("item_", "")
    local base = "panorama/images/items/"
    local paths = { base .. iconName .. "_png.vtex_c" }
    -- Fallback: compound name (e.g. battlefury -> battle_fury) and variant with item_ prefix
    if not iconName:find("_", 1, true) and #iconName > 6 then
        local alt = iconName:gsub("fury", "_fury"):gsub("blade", "_blade"):gsub("guard", "_guard")
            :gsub("orb", "_orb"):gsub("boots", "_boots"):gsub("staff", "_staff"):gsub("mail", "_mail")
        if alt ~= iconName then
            paths[#paths + 1] = base .. alt .. "_png.vtex_c"
            paths[#paths + 1] = base .. "item_" .. alt .. "_png.vtex_c"
        end
    elseif ITEM_ICON_NAME_OVERRIDES[name] then
        paths[#paths + 1] = base .. "item_" .. iconName .. "_png.vtex_c"
    end

    for _, path in ipairs(paths) do
        local ok, h = pcall(Render.LoadImage, path)
        if ok and h then
            S.itemIcons[name] = h
            return h
        end
    end
    S.itemIcons[name] = false
    return nil
end

--------------------------------------------------------------------------------
-- DRAW PRIMITIVES
--------------------------------------------------------------------------------
local function dRect(x, y, w, h, c, rnd)
    local pos = V(F(x), F(y))
    local size = V(F(w), F(h))
    local ok = pcall(function()
        -- Legacy signature used by original script (pos, endPos, color, rounding, flags)
        Render.FilledRect(pos, V(F(x+w), F(y+h)), c, rnd or 0, Enum.DrawFlags.RoundCornersAll)
    end)
    if not ok then
        pcall(Render.FilledRect, pos, size, c, rnd or 0)
    end
end

local function dBorder(x, y, w, h, c, rnd, t)
    local pos = V(F(x), F(y))
    local size = V(F(w), F(h))
    local ok = pcall(function()
        if Render.Rect then
            Render.Rect(pos, V(F(x+w), F(y+h)), c, rnd or 0, Enum.DrawFlags.RoundCornersAll, t or 1)
        elseif Render.OutlineRect then
            Render.OutlineRect(pos, size, c, rnd or 0, t or 1)
        end
    end)
    if not ok and Render.OutlineRect then
        pcall(Render.OutlineRect, pos, size, c, rnd or 0, t or 1)
    end
end

local function dText(sz, txt, x, y, c)
    local scaledSz = sc(sz)
    local f = getFont(scaledSz); if not f then return end
    txt = tostring(txt)
    local pos = V(F(x), F(y))
    local ok = pcall(function()
        -- Legacy signature used by original script/build.
        Render.Text(f, scaledSz, txt, pos, c)
    end)
    if not ok then
        pcall(Render.Text, f, pos, txt, c)
    end
end

--------------------------------------------------------------------------------
-- TEXT SIZE CACHE
--------------------------------------------------------------------------------
local textSizeCache = {}
local TEXT_CACHE_MAX_SIZE = 500  -- Limit cache size to prevent memory bloat
local textSizeCacheCount = 0
local clearTextCache

tSz = function(sz, txt)
    local scaledSz = sc(sz)
    local key = scaledSz .. "_" .. tostring(txt)
    local cached = textSizeCache[key]
    if cached then return cached end
    
    local f = getFont(scaledSz)
    local result
    if not f then 
        result = {x = scaledSz * #tostring(txt) * 0.55, y = scaledSz}
    else
        local ok, r1, r2 = pcall(function()
            if Render.TextSize then
                return Render.TextSize(f, scaledSz, tostring(txt))
            end
            if Render.GetTextSize then
                return Render.GetTextSize(f, tostring(txt))
            end
        end)
        if ok and r1 then
            if type(r1) == "number" then
                result = {x = r1, y = r2 or scaledSz}
            elseif type(r1) == "table" or type(r1) == "userdata" then
                result = {x = r1.x or 0, y = r1.y or scaledSz}
            end
        end
        if not result then
            result = {x = scaledSz * #tostring(txt) * 0.55, y = scaledSz}
        end
    end
    
    -- Limit cache size
    if textSizeCacheCount >= TEXT_CACHE_MAX_SIZE then
        clearTextCache()
    end
    if textSizeCache[key] == nil then
        textSizeCache[key] = result
        textSizeCacheCount = textSizeCacheCount + 1
    end
    
    return result
end

clearTextCache = function()
    textSizeCache = {}
    textSizeCacheCount = 0
end

local function dLine(x1, y1, x2, y2, c, t)
    Render.Line(V(F(x1), F(y1)), V(F(x2), F(y2)), c, t or 1)
end

local function dCircle(x, y, r, c)
    Render.FilledCircle(V(F(x), F(y)), r, c)
end

local function dImg(img, x, y, w, h, c, rnd)
    Render.Image(img, V(F(x), F(y)), V(w, h), c, rnd or 0)
end

local function dBlur(x, y, w, h)
    local pos = V(F(x), F(y))
    local size = V(F(w), F(h))
    local ok = pcall(function()
        Render.Blur(pos, V(F(x+w), F(y+h)), 1.0, 1.0, 0, Enum.DrawFlags.None)
    end)
    if not ok then
        pcall(Render.Blur, pos, size, 1.0)
    end
end

local function wrapTextLines(sz, txt, maxW)
    txt = tostring(txt or "")
    if txt == "" or maxW <= 0 then return {} end
    local words = {}
    for word in txt:gmatch("%S+") do table.insert(words, word) end
    if #words == 0 then return {} end

    local lines = {}
    local line = ""
    for _, word in ipairs(words) do
        local test = (line == "") and word or (line .. " " .. word)
        if tSz(sz, test).x > maxW and line ~= "" then
            table.insert(lines, line)
            line = word
        else
            line = test
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

local function clearClickRegions()
    S.clickRegions = {}
    S.hoveredRegion = nil
end

local function registerClickRegion(x, y, w, h, itemName, section, priorityIndex, enabled)
    if not itemName or w <= 0 or h <= 0 then return end
    table.insert(S.clickRegions, {
        x = x, y = y, w = w, h = h,
        itemName = itemName,
        section = section or "main",
        priorityIndex = priorityIndex or 0,
        enabled = (enabled ~= false),
    })
end

local function getCursorPos2D()
    -- Primary: Input.GetCursorPos() returns two numbers (x, y) — used by broodmother
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok and x and y then return x, y end
    end
    -- Fallback: Engine.GetCursorPos() returns Vec2
    local ok2, pos = pcall(Engine.GetCursorPos)
    if ok2 and pos then
        if type(pos) == "userdata" or type(pos) == "table" then
            return pos.x or 0, pos.y or 0
        end
    end
    return nil, nil
end

local function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and y >= ry and x <= (rx + rw) and y <= (ry + rh)
end

local function findClickRegionAt(x, y)
    for i = #S.clickRegions, 1, -1 do
        local r = S.clickRegions[i]
        local inside = false
        if r then
            if x and y then
                inside = pointInRect(x, y, r.x, r.y, r.w, r.h)
            end
            if not inside and Input and Input.IsCursorInRect then
                inside = (safeStatic(Input, "IsCursorInRect", r.x, r.y, r.w, r.h) == true)
            end
        end
        if inside then
            return r
        end
    end
    return nil
end

local function mouseKey(key)
    local bc = Enum and Enum.ButtonCode
    if not bc then return false end
    return key == bc.KEY_MOUSE1
        or key == bc.KEY_MOUSE2
        or key == bc.KEY_MOUSE3
        or key == bc.KEY_MOUSE4
        or key == bc.KEY_MOUSE5
        or key == bc.KEY_MWHEELUP
        or key == bc.KEY_MWHEELDOWN
end

local function panelHitTestAt(x, y)
    local pr = S.panelRect
    if not S.panelVisible or not pr then return false end

    if x and y and pointInRect(x, y, pr.x or 0, pr.y or 0, pr.w or 0, pr.h or 0) then
        return true
    end

    if Input and Input.IsCursorInRect then
        return safeStatic(Input, "IsCursorInRect", pr.x or 0, pr.y or 0, pr.w or 0, pr.h or 0) == true
    end

    return false
end

local function cursorOnPanel()
    local x, y = getCursorPos2D()
    return panelHitTestAt(x, y)
end

local function markPanelInputBlocked(duration)
    S.panelBlockInputUntil = os.clock() + (duration or 0.18)
end

local function shouldBlockPanelInput()
    if not sg(UI.enabled, true) or not sg(UI.showPanel, true) or not S.toggleState then return false end
    if S.isDragging then return true end
    if os.clock() < (S.panelBlockInputUntil or 0) then return true end
    return cursorOnPanel()
end

local function isLocalPlayerOrder(data, playerArg)
    local localPlayer = safeStatic(Players, "GetLocal")
    if not localPlayer then return true end

    local orderPlayer = type(data) == "table" and data.player or playerArg
    if not orderPlayer then return true end

    local localId = safeStatic(Player, "GetPlayerID", localPlayer)
    local orderId = safeStatic(Player, "GetPlayerID", orderPlayer)
    if localId == nil or orderId == nil then return true end
    return localId == orderId
end

--------------------------------------------------------------------------------
-- ANALYSIS ENGINE
--------------------------------------------------------------------------------
local function analyzeEnemyTeam()
    local me = Heroes.GetLocal()
    if not me then return end

    local myTeam = safeStatic(Entity, "GetTeamNum", me)
    if not myTeam then return end

    -- Detect game mode (only once per game)
    if S.gameMode == GAME_MODE.UNKNOWN then
        S.gameMode = detectGameMode()
    end

    -- Game phase
    local gameTime = gt() - gst()
    if gameTime < 0 then gameTime = 0 end
    if gameTime < 840 then S.gamePhase = PHASE_EARLY
    elseif gameTime < 1800 then S.gamePhase = PHASE_MID
    else S.gamePhase = PHASE_LATE end

    -- Determine neutral tier based on game time (updated for current patch)
    if gameTime < 300 then S.neutralTier = 0       -- No neutrals yet
    elseif gameTime < 900 then S.neutralTier = 1   -- Tier 1: 5-15 min
    elseif gameTime < 1500 then S.neutralTier = 2  -- Tier 2: 15-25 min
    elseif gameTime < 2100 then S.neutralTier = 3  -- Tier 3: 25-35 min
    elseif gameTime < 3600 then S.neutralTier = 4  -- Tier 4: 35-60 min
    else S.neutralTier = 5 end                     -- Tier 5: 60+ min

    -- Net worth analysis (via item values + gold)
    if sg(UI.showNetWorth, true) then
        local myTeamNW = 0
        local enemyTeamNW = 0
        
        local heroes = Heroes.GetAll()
        if not heroes or #heroes == 0 then
            Log.Write("[ItemHelper] No heroes found")
            return
        end
        
        for _, hero in ipairs(heroes) do
            if hero and Entity.IsEntity(hero) then
                local team = safeStatic(Entity, "GetTeamNum", hero)
                local totalGold = 0
                
                -- Prefer hero-owned player object (documented) and fall back to player id path.
                local player = safeMethod(hero, "GetPlayer")
                if not player then
                    local playerID = safeMethod(hero, "GetPlayerID")
                    if playerID and playerID >= 0 then
                        player = findPlayerByID(playerID)
                    end
                end
                if player then
                    local gold = safeMethod(player, "GetGold") or safeStatic(Player, "GetGold", player)
                    if gold and gold > 0 then
                        totalGold = totalGold + gold
                    end
                end
                
                -- Item net worth approximation from inventory value.
                local itemValue = 0
                local itemCount = 0
                for i = 0, 8 do
                    local item = safeStatic(NPC, "GetItemByIndex", hero, i)
                    if item then
                        local cost = safeMethod(item, "GetCost")
                        if not cost or cost <= 0 then
                            local itemName = safeMethod(item, "GetName") or safeStatic(Ability, "GetName", item)
                            cost = GetItemCost(itemName)
                        end
                        if cost > 0 then
                            itemValue = itemValue + cost
                            itemCount = itemCount + 1
                        end
                    end
                end
                -- Neutral item (slot 16)
                local neutralItem = safeStatic(NPC, "GetItemByIndex", hero, 16)
                if neutralItem then
                    local nCost = safeMethod(neutralItem, "GetCost")
                    if not nCost or nCost <= 0 then
                        local nName = safeMethod(neutralItem, "GetName") or safeStatic(Ability, "GetName", neutralItem)
                        nCost = GetItemCost(nName)
                    end
                    itemValue = itemValue + (nCost and nCost > 0 and nCost or 1000)
                    itemCount = itemCount + 1
                end
                
                totalGold = totalGold + itemValue
                
                if team == myTeam then
                    myTeamNW = myTeamNW + totalGold
                else
                    enemyTeamNW = enemyTeamNW + totalGold
                end
                
            end
        end
        
        S.myTeamNetWorth = myTeamNW
        S.enemyTeamNetWorth = enemyTeamNW
        S.netWorthDiff = myTeamNW - enemyTeamNW

        -- Determine game tempo
        local diffPercent = enemyTeamNW > 0 and (S.netWorthDiff / enemyTeamNW) or 0
        if diffPercent > 0.15 then S.gameTempo = "ahead"
        elseif diffPercent < -0.15 then S.gameTempo = "behind"
        else S.gameTempo = "even" end
    end

    -- My gold & hero name
    local myPlayer = getLocalPlayerObject()
    local gold = getPlayerCurrentGold(myPlayer)
    if gold == nil then
        gold = getHeroCurrentGold(me)
    end
    if gold ~= nil then
        S.myGold = gold
        S.myGoldKnown = true
    else
        if not myPlayer then
            S.myGold = 0
        end
        S.myGoldKnown = false
    end
    S.myHeroName = safeStatic(NPC, "GetUnitName", me) or ""

    -- Own items (including neutral slot)
    S.ownedItems = {}
    for i = 0, 8 do
        local item = safeStatic(NPC, "GetItemByIndex", me, i)
        if item then
            local iName = safeStatic(Ability, "GetName", item)
            if iName then
                S.ownedItems[iName] = true
                S.ownedItems[canonItemName(iName)] = true
                S.ownedItems[engineItemName(iName)] = true
            end
        end
    end
    -- Check neutral slot (slot 16)
    local neutralItem = safeStatic(NPC, "GetItemByIndex", me, 16)
    if neutralItem then
        local nName = safeStatic(Ability, "GetName", neutralItem)
        if nName then
            S.ownedItems[nName] = true
            S.ownedItems[canonItemName(nName)] = true
            S.ownedItems[engineItemName(nName)] = true
        end
    end

    -- Enemies (filter out illusions, clones, tempest doubles; deduplicate by name)
    S.enemyHeroes = {}
    S.enemyTags = {}
    S.enemyItems = {}
    S.enemyItemCounts = {}
    S.enemyFocus = {}
    S.activeEnemyCount = 0
    local heroes = Heroes.GetAll()
    if not heroes then return end

    local seenNames = {}
    for _, hero in ipairs(heroes) do
        local team = safeStatic(Entity, "GetTeamNum", hero)
        if team and team ~= myTeam then
            -- Skip illusions, clones (MK ult), tempest doubles (Arc Warden)
            local isIllusion = safeStatic(NPC, "IsIllusion", hero)
            if isIllusion then goto continue end
            local isClone = safeStatic(NPC, "IsClone", hero)
            if isClone then goto continue end
            local isTempest = safeStatic(NPC, "IsTempestDouble", hero)
            if isTempest then goto continue end

            local name = safeStatic(NPC, "GetUnitName", hero) or ""
            if name ~= "" and not seenNames[name] then
                seenNames[name] = true
                local alive = safeStatic(Entity, "IsAlive", hero)
                local level = safeStatic(NPC, "GetCurrentLevel", hero) or 0

                local enemyData = {
                    name  = name,
                    alive = alive ~= false,
                    level = level,
                    items = {},
                    tags = HERO_TAGS[name] or {},
                }

                -- Track enemy items if enabled
                if sg(UI.trackEnemyItems, true) then
                    for i = 0, 8 do
                        local item = safeStatic(NPC, "GetItemByIndex", hero, i)
                        if item then
                            local iName = safeStatic(Ability, "GetName", item)
                            if iName then
                                local cName = canonItemName(iName)
                                enemyData.items[iName] = true
                                enemyData.items[cName] = true
                                S.enemyItems[cName] = (S.enemyItems[cName] or 0) + 1
                                S.enemyItemCounts[cName] = (S.enemyItemCounts[cName] or 0) + 1
                            end
                        end
                    end
                    -- Check neutral slot
                    local neutralItem = safeStatic(NPC, "GetItemByIndex", hero, 16)
                    if neutralItem then
                        local nName = safeStatic(Ability, "GetName", neutralItem)
                        if nName then
                            local cName = canonItemName(nName)
                            enemyData.items[nName] = true
                            enemyData.items[cName] = true
                            S.enemyItems[cName] = (S.enemyItems[cName] or 0) + 1
                        end
                    end
                end

                table.insert(S.enemyHeroes, enemyData)
            end
        end
        ::continue::
    end

    -- Apply enemy filters
    S.enemyTags = {}
    for _, enemy in ipairs(S.enemyHeroes) do
        enemy.included = shouldIncludeEnemy(enemy.name)
        if enemy.included then
            S.activeEnemyCount = S.activeEnemyCount + 1
            for _, tag in ipairs(enemy.tags or {}) do
                S.enemyTags[tag] = (S.enemyTags[tag] or 0) + 1
            end
        end
        enemy.tagCounts = buildTagCounts(enemy.tags)
        enemy.itemCounts = {}
        for itemName, _ in pairs(enemy.items) do
            enemy.itemCounts[itemName] = 1
        end
    end

    refreshEnemyFilterList()

    -- Sort threat counts
    S.threatCounts = {}
    for tag, count in pairs(S.enemyTags) do
        table.insert(S.threatCounts, {tag = tag, count = count})
    end
    table.sort(S.threatCounts, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.tag < b.tag
    end)

    -- Hero counter suggestions
    local myRole, myStyle = getHeroProfile(S.myHeroName)

    S.heroCounterSuggestions = {}
    if sg(UI.showHeroCounters, true) then
        local counterScore = {}
        for _, enemy in ipairs(S.enemyHeroes) do
            if enemy.included then
            local counterData = HERO_COUNTERS[enemy.name]
            if counterData then
                for _, rawItemName in ipairs(counterData.items) do
                    local itemName, allowed = itemAllowedForProfile(rawItemName, myRole, myStyle)
                    if allowed and not ownedItemContains(S.ownedItems, itemName) then
                        local w = directCounterWeight(counterData, itemName)
                        if w <= 0 then w = 10 end
                        counterScore[itemName] = (counterScore[itemName] or 0) + w
                    end
                end
            end
            end
        end
        -- Convert to sorted table
        for itemName, score in pairs(counterScore) do
            local counterData = nil
            -- Find reason from HERO_COUNTERS among filtered enemies
            for _, enemy in ipairs(S.enemyHeroes) do
                if enemy.included then
                    local cd = HERO_COUNTERS[enemy.name]
                    if cd and listContainsCanonicalItem(cd.items, itemName) then
                        counterData = cd
                        break
                    end
                end
            end
            table.insert(S.heroCounterSuggestions, {
                item = itemName,
                score = score,
                reason = counterData and counterData.reason or "Counter pick"
            })
        end
        table.sort(S.heroCounterSuggestions, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return tostring(a.item) < tostring(b.item)
        end)
    end

    -- Score items
    local ctx = {
        phase = S.gamePhase,
        ownedItems = S.ownedItems,
        enemyTags = S.enemyTags,
        enemyHeroes = S.enemyHeroes,
        activeEnemyCount = S.activeEnemyCount,
        enemyItemCounts = S.enemyItemCounts,
        myGold = S.myGold,
        myGoldKnown = S.myGoldKnown,
        myRole = myRole,
        myStyle = myStyle,
        gameMode = S.gameMode,
        gameTempo = S.gameTempo,
        showNetWorth = sg(UI.showNetWorth, true),
        heroName = S.myHeroName,
        trackEnemyItems = sg(UI.trackEnemyItems, true),
    }

    if sg(UI.showEnemyFocus, true) then
        S.enemyFocus = buildEnemyFocusData(ctx)
    else
        S.enemyFocus = {}
    end

    local scored = {}
    for _, itemDef in ipairs(ITEM_DB) do
        local s, breakdown = computeItemScore(itemDef, ctx, true)
        if s > 0 then
            local meta = buildSuggestionMeta(itemDef, ctx, s, breakdown)
            table.insert(scored, {
                item = itemDef,
                score = s,
                category = meta.category,
                breakdown = meta.breakdown,
                breakdownHighlights = meta.breakdownHighlights,
                topReasons = meta.topReasons,
            })
        end
    end
    table.sort(scored, function(a, b)
        if a.category ~= b.category then
            local prio = {must_have = 3, situational = 2, luxury = 1}
            return (prio[a.category] or 0) > (prio[b.category] or 0)
        end
        if a.score ~= b.score then return a.score > b.score end
        return (a.item.cost or 0) > (b.item.cost or 0)
    end)

    local maxItems = sg(UI.maxItems, 6)
    S.suggestions = buildDiverseSuggestions(scored, ctx, maxItems)

    -- Score neutral items
    if sg(UI.showNeutrals, true) and S.neutralTier > 0 then
        local function scoreNeutralItem(itemDef)
            if itemDef.tier > S.neutralTier then return 0 end
            if S.ownedItems[itemDef.name] then return -1 end
            local score = 0
            -- Trigger-based scoring
            if itemDef.tags then
                for _, tag in ipairs(itemDef.tags) do
                    local cnt = S.enemyTags[tag] or 0
                    if cnt > 0 then score = score + cnt * 2 end
                end
            end
            -- Counter-rule scoring for neutrals
            for _, rule in ipairs(COUNTER_RULES) do
                local ruleMatch = 0
                for _, rTag in ipairs(rule.tags) do
                    if S.enemyTags[rTag] and S.enemyTags[rTag] > 0 then
                        ruleMatch = ruleMatch + 1
                    end
                end
                if ruleMatch >= #rule.tags then
                    local itemMatch = countMatches(itemDef.tags, rule.suggest)
                    if itemMatch > 0 then
                        score = score + itemMatch * rule.weight * 0.5
                    end
                end
            end
            -- Prefer higher tier items if available
            score = score + (itemDef.tier * 2)
            -- Role/style penalty for neutrals
            if score > 0 and (myRole or myStyle) then
                local penalty = ITEM_ROLE_PENALTY[itemDef.name]
                if penalty then
                    local penalized = false
                    if penalty.bad_roles and myRole then
                        for _, br in ipairs(penalty.bad_roles) do
                            if br == myRole then penalized = true; break end
                        end
                    end
                    if not penalized and penalty.bad_styles and myStyle then
                        for _, bs in ipairs(penalty.bad_styles) do
                            if bs == myStyle then penalized = true; break end
                        end
                    end
                    if penalized then
                        score = math.max(1, math.floor(score * 0.3))
                    end
                end
            end
            return score
        end

        local neutralScored = {}
        for _, itemDef in ipairs(NEUTRAL_DB) do
            local s = scoreNeutralItem(itemDef)
            if s > 0 then table.insert(neutralScored, {item = itemDef, score = s}) end
        end
        table.sort(neutralScored, function(a, b) return a.score > b.score end)

        S.neutralSuggestions = {}
        local maxNeutrals = 3
        for _, entry in ipairs(neutralScored) do
            if #S.neutralSuggestions >= maxNeutrals then break end
            table.insert(S.neutralSuggestions, {item = entry.item, score = entry.score})
        end
    end
end

--------------------------------------------------------------------------------
-- DRAW: THREAT TAG
--------------------------------------------------------------------------------
local THREAT_TAG_COLORS = {
    carry       = {255, 80, 80},
    phys_dps    = {255, 130, 50},
    phys_burst  = {255, 80, 50},
    magic_burst = {120, 80, 255},
    disable     = {255, 220, 50},
    stun        = {255, 200, 50},
    hex         = {200, 80, 255},
    silence     = {80, 130, 255},
    heal        = {80, 220, 100},
    save        = {80, 200, 180},
    invis       = {180, 180, 220},
    illusions   = {200, 150, 255},
    summons     = {150, 180, 130},
    mobility    = {80, 200, 255},
    evasion     = {180, 255, 80},
    tanky       = {160, 160, 180},
    slow        = {100, 150, 255},
    global      = {255, 180, 100},
    push        = {200, 180, 100},
    mana_burn   = {50, 100, 255},
    magic_immune= {255, 200, 80},
    doom        = {255, 50, 50},
    pure_dmg    = {255, 220, 220},
    armor_reduce= {200, 130, 50},
    anti_heal   = {255, 100, 100},
    root        = {100, 200, 100},
    fear        = {200, 100, 200},
    break_tag   = {200, 150, 100},
}

local function getTTagColor(tag)
    return THREAT_TAG_COLORS[tag] or {150, 150, 150}
end

local function drawThreatTag(x, y, tag, count, alpha, maxW)
    local tc = getTTagColor(tag)
    local txt = tag:upper()
    if count > 1 then txt = txt .. " x" .. count end
    local tw = tSz(8, txt)
    local w = tw.x + 10
    local h = 15
    if maxW and (x + w) > maxW then return 0, true end
    dRect(x, y, w, h, col(tc[1], tc[2], tc[3], F(alpha * 0.2)), 3)
    dText(8, txt, x + 5, y + 2, col(tc[1], tc[2], tc[3], F(alpha * 0.85)))
    return w + 3, false
end

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local CFG = {
    PW          = 310,
    MARGIN      = 12,
    PAD         = 10,
    ROUNDING    = 8,
    HEADER_H    = 40,
    ANALYSIS_CD = 2.0,
}

--------------------------------------------------------------------------------
-- THEME COLOR CACHE
--------------------------------------------------------------------------------
local TC = {
    bg       = col(12, 14, 26, 220),
    border   = col(40, 45, 65, 80),
    text     = col(235, 238, 255, 255),
    accent   = col(0, 200, 150, 255),
    dim      = col(100, 105, 120, 180),
    lastSync = 0,
}

local function syncThemeColors()
    local now = gt()
    if now - TC.lastSync < 0.5 then return end
    TC.lastSync = now
    local ok, style = pcall(Menu.Style)
    if not ok or not style then return end
    local bg     = StyleColor(style, "additional_background", 220)
    local border = StyleColor(style, "outline", 90)
    local text   = StyleColor(style, "primary_first_tab_text", 255)
    local accent = StyleColor(style, "primary", 255)
    local dim    = StyleColor(style, "slider_background", 180)

    TC.bg     = bg
    TC.text   = readableColor(text, bg, 4.5, col(242, 245, 255, 255), col(24, 28, 36, 255))
    TC.dim    = readableMutedColor(dim, bg, TC.text, 3.0, 185)
    TC.accent = readableAccentColor(accent, bg, TC.text)
    TC.border = contrastRatio(border, bg) >= 1.35 and border or readableMutedColor(border, bg, TC.text, 1.45, 105)
end

--------------------------------------------------------------------------------
-- PANORAMA / VISIBILITY
--------------------------------------------------------------------------------
local _shopCache       = false
local _shopCacheT      = 0
local _shopPanel       = nil
local _panelSearchDone = false

-- Find shop panel (id=shop, type=DOTAHUDShop)
local function findShopPanel()
    if _panelSearchDone then return _shopPanel end
    _panelSearchDone = true
    -- Direct search by ID
    local ok, p = pcall(Panorama.GetPanelByName, "shop", false)
    if ok and p then _shopPanel = p; return p end
    -- Fallback: traverse from HUD root
    local ok2, hud = pcall(Panorama.GetPanelByName, "Hud", false)
    if ok2 and hud then
        local ok3, sp = pcall(hud.FindChildTraverse, hud, "shop")
        if ok3 and sp then _shopPanel = sp; return sp end
    end
    return nil
end

local function isShopOpen()
    local now = gt()
    if now - _shopCacheT < 0.15 then return _shopCache end
    _shopCacheT = now

    -- Shop panel has CSS class "ShopOpen" when open, "ShopClosing" when closed
    local sp = findShopPanel()
    if sp then
        local ok, has = pcall(sp.HasClass, sp, "ShopOpen")
        if ok then
            _shopCache = (has == true)
            return _shopCache
        end
    end

    _shopCache = false
    return false
end

local function isCheatMenuOpen()
    local ok, v = pcall(Menu.Opened)
    return ok and v == true
end

-- visMode: 0=Always, 1=Cheat Menu Only, 2=Shop Only, 3=Menu or Shop
local function shouldShowPanel()
    local mode = sg(UI.visMode, 0)
    if mode == 0 then
        return true
    elseif mode == 1 then
        return isCheatMenuOpen()
    elseif mode == 2 then
        return isShopOpen()
    elseif mode == 3 then
        return isCheatMenuOpen() or isShopOpen()
    end
    return true
end

--------------------------------------------------------------------------------
-- DRAW: HEADER
--------------------------------------------------------------------------------
local function drawHeader(x, y, w, alpha)
    local acc = TC.accent
    local textC = colA(TC.text, alpha)
    dRect(x, y, w, sc(2), colA(acc, alpha * 0.8), 0)
    dText(14, L("title"), x + sc(8), y + sc(10), textC)

    -- Drag hint icon
    dText(8, "\u{f0b2}", x + w - sc(20), y + sc(6), colA(TC.dim, alpha * 0.4))

    -- Game mode badge
    local modeKeys = {
        [GAME_MODE.UNKNOWN] = "mode_unknown",
        [GAME_MODE.ALL_PICK] = "mode_allpick",
        [GAME_MODE.RANKED] = "mode_ranked",
        [GAME_MODE.TURBO] = "mode_turbo",
        [GAME_MODE.SINGLE_DRAFT] = "mode_draft",
        [GAME_MODE.ALL_RANDOM] = "mode_random",
        [GAME_MODE.CAPTAINS_MODE] = "mode_draft",
        [GAME_MODE.ABILITY_DRAFT] = "mode_draft",
    }
    local modeColors = {
        [GAME_MODE.UNKNOWN] = {100, 100, 100},
        [GAME_MODE.ALL_PICK] = {80, 180, 220},
        [GAME_MODE.RANKED] = {255, 180, 60},
        [GAME_MODE.TURBO] = {255, 100, 150},
        [GAME_MODE.SINGLE_DRAFT] = {150, 120, 200},
        [GAME_MODE.ALL_RANDOM] = {120, 200, 150},
        [GAME_MODE.CAPTAINS_MODE] = {200, 150, 100},
        [GAME_MODE.ABILITY_DRAFT] = {180, 100, 200},
    }
    local mc = modeColors[S.gameMode] or {100, 100, 100}
    local mName = L(modeKeys[S.gameMode] or "mode_unknown")
    local ms = tSz(8, mName)
    dRect(x + sc(8), y + sc(28), ms.x + sc(8), sc(14), col(mc[1], mc[2], mc[3], F(alpha * 0.15)), sc(3))
    dText(8, mName, x + sc(12), y + sc(29), col(mc[1], mc[2], mc[3], F(alpha * 0.85)))

    -- Test context badge (lobby / Try Hero custom sandbox)
    if S.testContextKind then
        local tKey = (S.testContextKind == "tryhero" and "test_tryhero")
            or (S.testContextKind == "lobby" and "test_lobby")
            or "test_custom"
        local tTxt = L(tKey)
        local ts = tSz(7, tTxt)
        local tx = x + sc(8) + ms.x + sc(16)
        local tw = ts.x + sc(8)
        dRect(tx, y + sc(29), tw, sc(12), col(255, 170, 60, F(alpha * 0.16)), sc(3))
        dText(7, tTxt, tx + sc(4), y + sc(30), col(255, 190, 90, F(alpha * 0.85)))
    end

    -- Phase badge
    local phaseKeys = {[PHASE_EARLY]="early", [PHASE_MID]="mid", [PHASE_LATE]="late"}
    local phaseColors = {[PHASE_EARLY]={80,220,120}, [PHASE_MID]={255,200,60}, [PHASE_LATE]={255,90,70}}
    local pc = phaseColors[S.gamePhase]
    local pName = L(phaseKeys[S.gamePhase])
    local ps = tSz(10, pName)
    local bx = x + w - ps.x - sc(14)
    dRect(bx, y + sc(10), ps.x + sc(10), sc(18), col(pc[1], pc[2], pc[3], F(alpha * 0.15)), sc(4))
    dText(10, pName, bx + sc(5), y + sc(12), col(pc[1], pc[2], pc[3], F(alpha * 0.9)))

    -- Gold (optional)
    if sg(UI.showGoldHeader, true) then
        local goldTxt = (S.myGoldKnown and (F(S.myGold) .. "g")) or L("gold_unknown")
        local goldSz = tSz(9, goldTxt)
        local goldColor = S.myGoldKnown and col(255, 215, 0, F(alpha * 0.7)) or colA(TC.dim, alpha * 0.65)
        dText(9, goldTxt, x + w - goldSz.x - sc(8), y + sc(30), goldColor)
    end

    dRect(x + sc(4), y + sc(CFG.HEADER_H) - 1, w - sc(8), 1, colA(TC.dim, alpha * 0.2), 0)
    return sc(CFG.HEADER_H)
end

--------------------------------------------------------------------------------
-- DRAW: ENEMY HEROES SECTION
--------------------------------------------------------------------------------
local function drawEnemySection(x, y, w, alpha)
    local curY = y
    local acc = TC.accent
    local enemyTitle = L("enemies")
    if S.activeEnemyCount > 0 and S.activeEnemyCount < #S.enemyHeroes then
        enemyTitle = enemyTitle .. " (" .. S.activeEnemyCount .. "/" .. #S.enemyHeroes .. ")"
    end
    dText(10, enemyTitle, x + 4, curY, colA(acc, alpha * 0.9))
    curY = curY + 16

    local iconSz = 24
    local gap = 3
    local ix = x + 4

    for _, enemy in ipairs(S.enemyHeroes) do
        local icon = heroIcon(enemy.name)
        local iA = enemy.alive and alpha or (alpha * 0.3)
        dRect(ix, curY, iconSz, iconSz, col(20, 22, 36, F(iA * 0.7)), 4)
        if icon then
            dImg(icon, ix, curY, iconSz, iconSz, col(255, 255, 255, F(iA)), 4)
        else
            dText(12, "?", ix + 7, curY + 4, col(70, 75, 100, F(iA)))
        end
        if enemy.level > 0 then
            local lt = tostring(enemy.level)
            local lsz = tSz(7, lt)
            dRect(ix + iconSz - lsz.x - 2, curY + iconSz - 10, lsz.x + 3, 10,
                  col(0, 0, 0, F(iA * 0.8)), 2)
            dText(7, lt, ix + iconSz - lsz.x, curY + iconSz - 9, col(255, 255, 255, F(iA)))
        end
        if not enemy.alive then
            local cx2, cy2 = ix + iconSz / 2, curY + iconSz / 2
            local sz = iconSz * 0.22
            dLine(cx2 - sz, cy2 - sz, cx2 + sz, cy2 + sz, col(255, 50, 50, F(alpha * 0.7)), 2)
            dLine(cx2 + sz, cy2 - sz, cx2 - sz, cy2 + sz, col(255, 50, 50, F(alpha * 0.7)), 2)
        end
        ix = ix + iconSz + gap
        if ix > x + w - iconSz then break end
    end
    curY = curY + iconSz + 6

    -- Threat tags
    if sg(UI.showThreats, true) and #S.threatCounts > 0 then
        dText(9, L("threats"), x + 4, curY, col(180, 150, 80, F(alpha * 0.8)))
        curY = curY + 14
        local tagX = x + 4
        local maxRight = x + w - 4
        local maxTags = 10
        local shown = 0
        for _, tc in ipairs(S.threatCounts) do
            if shown >= maxTags then break end
            if tc.count > 0 then
                local tw, needWrap = drawThreatTag(tagX, curY, tc.tag, tc.count, alpha, maxRight)
                if needWrap then
                    tagX = x + 4
                    curY = curY + 17
                    tw, needWrap = drawThreatTag(tagX, curY, tc.tag, tc.count, alpha, maxRight)
                end
                if tw > 0 then tagX = tagX + tw; shown = shown + 1 end
            end
        end
        curY = curY + 19
    end

    dRect(x + 4, curY, w - 8, 1, colA(TC.dim, alpha * 0.15), 0)
    curY = curY + 6
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: NET WORTH BAR
--------------------------------------------------------------------------------
local function drawNetWorthBar(x, y, w, alpha)
    if not sg(UI.showNetWorth, true) then return 0 end
    -- Always show if enabled, even with 0 values (for debugging)
    
    local curY = y
    local totalNW = S.myTeamNetWorth + S.enemyTeamNetWorth
    
    -- Title
    dText(9, L("net_worth"), x + 4, curY, col(150, 150, 150, F(alpha * 0.7)))
    curY = curY + 14
    
    -- If no data yet, show placeholder
    if totalNW == 0 then
        dText(8, L("waiting_data"), x + 4, curY + 2, col(100, 100, 100, F(alpha * 0.5)))
        return 24
    end

    local myPercent = S.myTeamNetWorth / totalNW
    local diff = S.netWorthDiff

    -- Bar
    local barH = 8
    local barW = w - 8
    local myW = F(barW * myPercent)

    -- Background
    dRect(x + 4, curY, barW, barH, col(30, 30, 40, F(alpha * 0.5)), 2)

    -- Our team (green)
    if myW > 0 then
        dRect(x + 4, curY, myW, barH, col(60, 180, 80, F(alpha * 0.7)), 2)
    end

    -- Enemy team (red)
    local enemyW = barW - myW
    if enemyW > 0 then
        dRect(x + 4 + myW, curY, enemyW, barH, col(180, 60, 60, F(alpha * 0.7)), 2)
    end

    -- Diff text
    local diffTxt = diff >= 0 and "+" .. F(diff) or F(diff)
    local diffColor = diff >= 0 and {80, 200, 80} or {200, 80, 80}
    local diffSz = tSz(8, diffTxt)
    dText(8, diffTxt, x + 4 + F(barW / 2) - F(diffSz.x / 2), curY - 1, col(diffColor[1], diffColor[2], diffColor[3], F(alpha * 0.9)))

    -- Tempo badge
    local tempoColors = {
        ahead = {80, 200, 80},
        even = {150, 150, 150},
        behind = {200, 80, 80}
    }
    local tempoTxt = S.gameTempo:upper()
    local tempoSz = tSz(7, tempoTxt)
    local tc = tempoColors[S.gameTempo] or {150, 150, 150}
    dRect(x + w - tempoSz.x - 10, curY - 1, tempoSz.x + 6, 12, col(tc[1], tc[2], tc[3], F(alpha * 0.15)), 2)
    dText(7, tempoTxt, x + w - tempoSz.x - 7, curY, col(tc[1], tc[2], tc[3], F(alpha * 0.8)))

    curY = curY + barH + 10
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: HERO COUNTERS SECTION
--------------------------------------------------------------------------------
local function drawHeroCounters(x, y, w, alpha)
    if not sg(UI.showHeroCounters, true) then return 0 end
    if #S.heroCounterSuggestions == 0 then return 0 end

    local curY = y
    dText(10, L("hero_counters"), x + 4, curY, col(255, 100, 100, F(alpha * 0.9)))
    local hcTitleW = tSz(10, L("hero_counters")).x
    dRect(x + 8 + hcTitleW, curY + 7, math.max(0, w - hcTitleW - 16), 1, colA(TC.dim, alpha * 0.14), 0)
    curY = curY + 16

    -- Draw compact counter items
    local maxCounters = 5
    for i, counter in ipairs(S.heroCounterSuggestions) do
        if i > maxCounters then break end

        local item = counter.item
        local owned = sg(UI.showOwned, true) and S.ownedItems[item]
        local canAfford = S.myGoldKnown and S.myGold >= GetItemCost(item)

        -- Find item display name
        local displayName = item:gsub("item_", ""):gsub("_", " ")
        for _, itemDef in ipairs(ITEM_DB) do
            if itemDef.name == item then
                displayName = itemDef.display
                break
            end
        end

        local h = 20
        local bgA = F(alpha * 0.25)
        if owned then
            dRect(x, curY, w, h, col(18, 35, 25, bgA), 4)
        else
            dRect(x, curY, w, h, col(16, 18, 30, bgA), 4)
        end

        -- Counter indicator line (red)
        dRect(x, curY + 3, 2, h - 6, col(255, 80, 80, F(alpha * 0.7)), 1)

        -- Item icon
        local iconSz = 18
        local iconX = x + 6
        local iconY = curY + 2
        local iImg = itemIcon(item)
        dRect(iconX, iconY, iconSz, iconSz, col(22, 25, 40, F(alpha * 0.4)), 3)
        if iImg then
            dImg(iImg, iconX, iconY, iconSz, iconSz, col(255, 255, 255, F(alpha * (owned and 0.4 or 1))), 3)
        else
            local firstChar = displayName:sub(1, 1)
            dText(9, firstChar, iconX + 5, iconY + 3, colA(TC.dim, alpha * 0.5))
        end

        -- Item name
        local nameC
        if owned then
            nameC = col(80, 200, 120, F(alpha * 0.7))
        elseif canAfford then
            nameC = col(255, 215, 0, F(alpha * 0.9))
        else
            nameC = colA(TC.text, alpha)
        end
        dText(9, displayName, x + 28, curY + 3, nameC)

        -- Counter score badge
        local scoreTxt = "x" .. counter.score
        local scoreSz = tSz(7, scoreTxt)
        local scoreBg = canAfford and {255, 215, 0} or {255, 80, 80}
        local scoreFg = canAfford and {255, 225, 120} or {255, 100, 100}
        dRect(x + w - scoreSz.x - 8, curY + 4, scoreSz.x + 4, 12, col(scoreBg[1], scoreBg[2], scoreBg[3], F(alpha * 0.2)), 2)
        dText(7, scoreTxt, x + w - scoreSz.x - 6, curY + 5, col(scoreFg[1], scoreFg[2], scoreFg[3], F(alpha * 0.85)))

        registerClickRegion(x, curY, w, h, item, "hero_counter", i, true)

        curY = curY + h + 2
    end

    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: ENEMY FOCUS SECTION
--------------------------------------------------------------------------------
local function drawEnemyFocus(x, y, w, alpha)
    if not sg(UI.showEnemyFocus, true) then return 0 end
    if not S.enemyFocus or #S.enemyFocus == 0 then return 0 end

    local rows = clamp(sg(UI.enemyFocusRows, 3), 1, 6)
    local curY = y
    dText(10, L("enemy_focus"), x + 4, curY, col(255, 150, 90, F(alpha * 0.9)))
    local efTitleW = tSz(10, L("enemy_focus")).x
    dRect(x + 8 + efTitleW, curY + 7, math.max(0, w - efTitleW - 16), 1, colA(TC.dim, alpha * 0.14), 0)
    curY = curY + 16

    for i = 1, math.min(rows, #S.enemyFocus) do
        local entry = S.enemyFocus[i]
        local enemy = entry.enemy
        local rowH = 30
        dRect(x, curY, w, rowH, col(18, 20, 30, F(alpha * 0.25)), 5)

        local icon = heroIcon(enemy.name)
        if icon then
            dImg(icon, x + 4, curY + 4, 20, 20, col(255, 255, 255, F(alpha * 0.9)), 3)
        else
            dText(10, "?", x + 10, curY + 6, colA(TC.dim, alpha * 0.5))
        end

        local aliveC = enemy.alive and col(120, 220, 160, F(alpha * 0.8)) or col(220, 100, 100, F(alpha * 0.8))
        local leftX = x + 28
        local rightW = math.max(145, F(w * 0.52))
        local rightX = x + w - rightW - 6
        local leftW = math.max(32, rightX - leftX - 8)
        dText(10, shortTextByWidth(10, entry.display, leftW), leftX, curY + 4, colA(TC.text, alpha * 0.95))
        dText(8, shortTextByWidth(8, enemy.alive and L("alive") or L("dead"), leftW), leftX, curY + 17, aliveC)

        if entry.items and #entry.items > 0 then
            local best = entry.items[1]
            local reason = best.reason ~= "" and best.reason or LR(best.item.name)
            local canAffordBest = S.myGoldKnown and S.myGold >= (best.item.cost or 0)
            dText(9, shortTextByWidth(9, reason, rightW), rightX, curY + 4, colA(TC.dim, alpha * 0.8))
            local bestC = canAffordBest and col(255, 215, 0, F(alpha * 0.9)) or colA(TC.accent, alpha * 0.9)
            dText(10, shortTextByWidth(10, best.item.display, rightW), rightX, curY + 16, bestC)
            registerClickRegion(x, curY, w, rowH, best.item.name, "enemy_focus", i, true)
        end

        curY = curY + rowH + 2
    end
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: ITEM SUGGESTION CARD
--------------------------------------------------------------------------------
local CATEGORY_VIS = {
    must_have = {labelKey = "cat_must_have", color = {255, 116, 104}},
    situational = {labelKey = "cat_situational", color = {85, 170, 255}},
    luxury = {labelKey = "cat_luxury", color = {255, 205, 95}},
}

local function getCategoryVis(cat)
    return CATEGORY_VIS[cat or "situational"] or CATEGORY_VIS.situational
end

local function getBreakdownChips(suggestion)
    if not sg(UI.showScoreBreakdown, true) then return {} end
    local maxChips = clamp(sg(UI.breakdownChipCount, 2), 1, 4)
    local chips = {}
    for _, h in ipairs(suggestion.breakdownHighlights or {}) do
        if (h.delta or 0) ~= 0 and h.label and h.label ~= "" then
            local sign = (h.delta or 0) > 0 and "+" or ""
            local txt = sign .. tostring(h.delta) .. " " .. shortText(h.label, 14)
            table.insert(chips, {
                text = txt,
                delta = h.delta or 0,
                label = h.label,
            })
            if #chips >= maxChips then break end
        end
    end
    return chips
end

local function buildItemCardLayout(suggestion, w)
    local item = suggestion.item
    local nameXOffset = sc(26) + sc(26) + sc(8)
    local textAreaW = w - nameXOffset - sc(6)
    local h = sc(20)
    local reasonLines = {}
    local breakdownChips = getBreakdownChips(suggestion)
    local showCategory = sg(UI.showCategoryBadges, true)

    if showCategory then
        h = h + sc(13)
    end

    if sg(UI.showReasons, true) then
        local reason = LR(item.name)
        if reason == "" and suggestion.topReasons and #suggestion.topReasons > 0 then
            reason = table.concat(suggestion.topReasons, " • ")
        end
        if reason ~= "" then
            reasonLines = wrapTextLines(10, reason, textAreaW)
            if #reasonLines > 0 then
                h = h + #reasonLines * sc(13) + sc(2)
            end
        end
    end

    if #breakdownChips > 0 then
        h = h + sc(14)
    end

    local hasTriggers = false
    if item.triggers then
        for _, tr in ipairs(item.triggers) do
            if S.enemyTags[tr] and S.enemyTags[tr] > 0 then
                hasTriggers = true
                break
            end
        end
    end
    if hasTriggers then h = h + sc(14) end
    h = math.max(h, showCategory and sc(44) or sc(36))

    return {
        h = h,
        nameXOffset = nameXOffset,
        textAreaW = textAreaW,
        reasonLines = reasonLines,
        breakdownChips = breakdownChips,
        showCategory = showCategory,
        hasTriggers = hasTriggers,
    }
end

local function drawItemCard(x, y, w, suggestion, idx, alpha)
    local item = suggestion.item
    local acc = TC.accent
    local owned = sg(UI.showOwned, true) and S.ownedItems[item.name]
    local canAfford = S.myGoldKnown and S.myGold >= item.cost
    local layout = buildItemCardLayout(suggestion, w)

    local nameX = x + layout.nameXOffset
    local textAreaW = layout.textAreaW
    local h = layout.h
    local reasonLines = layout.reasonLines
    local breakdownChips = layout.breakdownChips
    local showCategory = layout.showCategory
    local hasTriggers = layout.hasTriggers
    local categoryVis = getCategoryVis(suggestion.category)

    -- Card background
    local bgA = F(alpha * 0.35)
    if owned then
        dRect(x, y, w, h, col(18, 35, 25, bgA), sc(6))
    else
        dRect(x, y, w, h, col(16, 18, 30, bgA), sc(6))
    end

    -- Left accent line
    if owned then
        dRect(x, y + sc(3), sc(2), h - sc(6), col(50, 200, 100, F(alpha * 0.7)), 1)
    elseif canAfford then
        dRect(x, y + sc(3), sc(2), h - sc(6), colA(acc, alpha * 0.5), 1)
    else
        dRect(x, y + sc(3), sc(2), h - sc(6), colA(TC.dim, alpha * 0.2), 1)
    end

    -- Priority number
    local numC = idx <= 2 and colA(acc, alpha * 0.9) or colA(TC.dim, alpha * 0.55)
    dText(10, "#" .. idx, x + sc(6), y + sc(4), numC)

    -- Item icon
    local iconSz = sc(26)
    local iconX = x + sc(26)
    local iconY = y + F((math.min(h, sc(46)) - iconSz) / 2)
    local iImg = itemIcon(item.name)
    dRect(iconX, iconY, iconSz, iconSz, col(22, 25, 40, F(alpha * 0.5)), sc(4))
    if iImg then
        dImg(iImg, iconX, iconY, iconSz, iconSz, col(255, 255, 255, F(alpha * (owned and 0.4 or 1))), sc(4))
    else
        -- Show first letter if icon not loaded
        local firstChar = item.display:sub(1, 1)
        dText(10, firstChar, iconX + sc(8), iconY + sc(6), colA(TC.dim, alpha * 0.5))
    end

    -- Top-right badges (score + cost) for cleaner alignment
    local costTxt = owned and L("owned") or (item.cost .. "g")
    local scoreTxt = "S " .. tostring(suggestion.score or 0)
    local costSz = tSz(8, costTxt)
    local scoreSz = tSz(8, scoreTxt)
    local costBadgeW = costSz.x + sc(8)
    local scoreBadgeW = scoreSz.x + sc(8)
    local badgeGap = sc(4)
    local costBx = x + w - costBadgeW - sc(6)
    local scoreBx = costBx - scoreBadgeW - badgeGap
    local badgeY = y + sc(4)

    local scoreC = categoryVis.color
    dRect(scoreBx, badgeY, scoreBadgeW, sc(12), col(scoreC[1], scoreC[2], scoreC[3], F(alpha * 0.14)), sc(3))
    dText(8, scoreTxt, scoreBx + sc(4), badgeY + sc(1), col(scoreC[1], scoreC[2], scoreC[3], F(alpha * 0.9)))

    local costC
    if owned then costC = col(80, 200, 120, F(alpha * 0.65))
    elseif canAfford then costC = col(255, 215, 0, F(alpha * 0.85))
    else costC = col(150, 85, 85, F(alpha * 0.7)) end
    dRect(costBx, badgeY, costBadgeW, sc(12), col(costC.r, costC.g, costC.b, F(alpha * 0.10)), sc(3))
    dText(8, costTxt, costBx + sc(4), badgeY + sc(1), costC)

    -- Item name
    local nameC
    if owned then
        nameC = col(80, 200, 120, F(alpha * 0.7))
    elseif canAfford then
        nameC = col(255, 215, 0, F(alpha * 0.95))
    else
        nameC = colA(TC.text, alpha)
    end
    local nameMaxW = math.max(sc(40), scoreBx - nameX - sc(6))
    dText(11, shortTextByWidth(11, item.display, nameMaxW), nameX, y + sc(4), nameC)

    local curTextY = y + sc(20)
    if showCategory then
        local catTxt = L(categoryVis.labelKey)
        local catSz = tSz(7, catTxt)
        local catW = catSz.x + sc(8)
        dRect(nameX, curTextY, catW, sc(11), col(categoryVis.color[1], categoryVis.color[2], categoryVis.color[3], F(alpha * 0.14)), sc(3))
        dText(7, catTxt, nameX + sc(4), curTextY + sc(1), col(categoryVis.color[1], categoryVis.color[2], categoryVis.color[3], F(alpha * 0.85)))
        curTextY = curTextY + sc(13)
    end

    -- Reason text (multi-line)
    for _, rLine in ipairs(reasonLines) do
        dText(10, rLine, nameX, curTextY, colA(TC.text, alpha * 0.85))
        curTextY = curTextY + sc(13)
    end

    -- Score breakdown chips (compact transparency)
    if #breakdownChips > 0 then
        local chipX = nameX
        local chipY = curTextY
        local maxRight = x + w - sc(4)
        for _, chip in ipairs(breakdownChips) do
            local chipText = chip.text
            local chipSz = tSz(7, chipText)
            local chipW = chipSz.x + sc(6)
            if chipX + chipW > maxRight then break end
            local pos = (chip.delta or 0) >= 0
            local cc = pos and {92, 205, 140} or {235, 120, 120}
            dRect(chipX, chipY, chipW, sc(11), col(cc[1], cc[2], cc[3], F(alpha * 0.10)), sc(3))
            dText(7, chipText, chipX + sc(3), chipY + sc(1), col(cc[1], cc[2], cc[3], F(alpha * 0.78)))
            chipX = chipX + chipW + sc(3)
        end
        curTextY = curTextY + sc(14)
    end

    -- Trigger tags
    if hasTriggers then
        local tagX = nameX
        local tagY = curTextY + sc(1)
        local shownTags = 0
        for _, tr in ipairs(item.triggers) do
            if shownTags >= 3 then break end
            if S.enemyTags[tr] and S.enemyTags[tr] > 0 then
                local tc = getTTagColor(tr)
                local tt = tr:upper()
                local tts = tSz(7, tt)
                local tw = tts.x + sc(6)
                if tagX + tw > x + w - sc(4) then break end
                dRect(tagX, tagY, tw, sc(11), col(tc[1], tc[2], tc[3], F(alpha * 0.12)), sc(3))
                dText(7, tt, tagX + sc(3), tagY + sc(1), col(tc[1], tc[2], tc[3], F(alpha * 0.5)))
                tagX = tagX + tw + sc(2)
                shownTags = shownTags + 1
            end
        end
    end

    registerClickRegion(x, y, w, h, item.name, "main", idx, true)

    return h
end

--------------------------------------------------------------------------------
-- DRAW: SUGGESTIONS SECTION
--------------------------------------------------------------------------------
local function drawSuggestions(x, y, w, alpha)
    local curY = y
    dText(10, L("recommended"), x + sc(4), curY, colA(TC.accent, alpha * 0.9))
    local recTitleW = tSz(10, L("recommended")).x
    dRect(x + sc(8) + recTitleW, curY + sc(7), math.max(0, w - recTitleW - sc(16)), 1, colA(TC.dim, alpha * 0.14), 0)
    if #S.suggestions > 0 then
        local counts = {must_have = 0, situational = 0, luxury = 0}
        for _, sug in ipairs(S.suggestions) do
            counts[sug.category or "situational"] = (counts[sug.category or "situational"] or 0) + 1
        end
        local bx = x + w - sc(4)
        for _, cat in ipairs({"luxury", "situational", "must_have"}) do
            local cnt = counts[cat] or 0
            if cnt > 0 then
                local vis = getCategoryVis(cat)
                local txt = L(vis.labelKey) .. " " .. cnt
                local ts = tSz(7, txt)
                local bw = ts.x + sc(8)
                bx = bx - bw
                dRect(bx, curY + sc(1), bw, sc(11), col(vis.color[1], vis.color[2], vis.color[3], F(alpha * 0.12)), sc(3))
                dText(7, txt, bx + sc(4), curY + sc(2), col(vis.color[1], vis.color[2], vis.color[3], F(alpha * 0.8)))
                bx = bx - sc(3)
            end
        end
    end
    curY = curY + sc(18)

    if #S.suggestions == 0 then
        dText(9, L("analyzing"), x + sc(4), curY, colA(TC.dim, alpha * 0.4))
        curY = curY + sc(18)
        return curY - y
    end

    for i, sug in ipairs(S.suggestions) do
        local cardH = drawItemCard(x, curY, w, sug, i, alpha)
        curY = curY + cardH + sc(3)
    end
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: NEUTRAL ITEMS SECTION
--------------------------------------------------------------------------------
local NEUTRAL_TIER_COLORS = {
    [1] = {120, 200, 120},  -- Green
    [2] = {100, 180, 255},  -- Blue
    [3] = {200, 120, 255},  -- Purple
    [4] = {255, 180, 80},   -- Orange
    [5] = {255, 100, 100},  -- Red
}

local function drawNeutralSection(x, y, w, alpha)
    if not sg(UI.showNeutrals, true) then return 0 end
    if S.neutralTier == 0 then return 0 end
    if #S.neutralSuggestions == 0 then return 0 end

    local curY = y
    local tierC = NEUTRAL_TIER_COLORS[S.neutralTier] or {150, 150, 150}
    
    -- Section header with tier indicator
    dRect(x + 4, curY, w - 8, 1, colA(TC.dim, alpha * 0.15), 0)
    curY = curY + 6
    
    local tierText = "NEUTRAL T" .. S.neutralTier
    dText(10, tierText, x + 4, curY, col(tierC[1], tierC[2], tierC[3], F(alpha * 0.9)))
    curY = curY + 16

    -- Neutral item cards (compact version)
    for i, sug in ipairs(S.neutralSuggestions) do
        local item = sug.item
        local owned = sg(UI.showOwned, true) and S.ownedItems[item.name]
        local tierItemC = NEUTRAL_TIER_COLORS[item.tier] or {150, 150, 150}
        
        local h = 22
        local bgA = F(alpha * 0.25)
        if owned then
            dRect(x, curY, w, h, col(18, 35, 25, bgA), 4)
        else
            dRect(x, curY, w, h, col(16, 18, 30, bgA), 4)
        end

        -- Tier indicator line
        dRect(x, curY + 3, 2, h - 6, col(tierItemC[1], tierItemC[2], tierItemC[3], F(alpha * 0.6)), 1)

        -- Item icon
        local iconSz = 18
        local iconX = x + 6
        local iconY = curY + 2
        local iImg = itemIcon(item.name)
        dRect(iconX, iconY, iconSz, iconSz, col(22, 25, 40, F(alpha * 0.4)), 3)
        if iImg then
            dImg(iImg, iconX, iconY, iconSz, iconSz, col(255, 255, 255, F(alpha * (owned and 0.4 or 1))), 3)
        else
            -- Show first letter if icon not loaded
            local firstChar = item.display:sub(1, 1)
            dText(9, firstChar, iconX + 5, iconY + 3, colA(TC.dim, alpha * 0.5))
        end

        -- Item name
        local nameC = owned and col(80, 200, 120, F(alpha * 0.7)) or colA(TC.text, alpha)
        dText(9, item.display, x + 28, curY + 3, nameC)

        -- Tier badge
        local tierBadge = "T" .. item.tier
        local tierBadgeSz = tSz(7, tierBadge)
        dRect(x + w - tierBadgeSz.x - 10, curY + 5, tierBadgeSz.x + 6, 12, col(tierItemC[1], tierItemC[2], tierItemC[3], F(alpha * 0.15)), 2)
        dText(7, tierBadge, x + w - tierBadgeSz.x - 7, curY + 6, col(tierItemC[1], tierItemC[2], tierItemC[3], F(alpha * 0.7)))

        registerClickRegion(x, curY, w, h, item.name, "neutral", i, true)

        curY = curY + h + 2
    end

    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: FOOTER
--------------------------------------------------------------------------------
local function getFooterTipData()
    local tip, tipC = nil, {150, 158, 185}
    if S.enemyTags["invis"] and S.enemyTags["invis"] >= 2 then
        tip = L("tip_invis"); tipC = {255, 200, 80}
    elseif S.enemyTags["magic_burst"] and S.enemyTags["magic_burst"] >= 3 then
        tip = L("tip_magic"); tipC = {120, 80, 255}
    elseif S.enemyTags["heal"] and S.enemyTags["heal"] >= 2 then
        tip = L("tip_heal"); tipC = {80, 220, 120}
    elseif S.enemyTags["phys_dps"] and S.enemyTags["phys_dps"] >= 3 then
        tip = L("tip_phys"); tipC = {255, 130, 50}
    elseif S.enemyTags["illusions"] and S.enemyTags["illusions"] >= 2 then
        tip = L("tip_illusions"); tipC = {200, 150, 255}
    elseif S.enemyTags["disable"] and S.enemyTags["disable"] >= 3 then
        tip = L("tip_disable"); tipC = {255, 220, 50}
    end
    return tip, tipC
end

local function drawFooter(x, y, w, alpha)
    local curY = y
    dRect(x + sc(4), curY, w - sc(8), 1, colA(TC.dim, alpha * 0.15), 0)
    curY = curY + sc(6)

    local tip, tipC = getFooterTipData()

    if tip then
        local lines = wrapTextLines(9, tip, w - sc(12))
        local tipH = #lines * sc(13) + sc(6)
        dRect(x + sc(2), curY, w - sc(4), tipH, col(tipC[1], tipC[2], tipC[3], F(alpha * 0.06)), sc(4))
        for _, ln in ipairs(lines) do
            dText(9, ln, x + sc(8), curY + sc(3), col(tipC[1], tipC[2], tipC[3], F(alpha * 0.65)))
            curY = curY + sc(13)
        end
        curY = curY + sc(4)
    end

    dText(8, "v3.2", x + w - sc(26), curY, col(40, 44, 60, F(alpha * 0.25)))
    curY = curY + sc(12)
    return curY - y
end

--------------------------------------------------------------------------------
-- PANEL MEASURE / OVERLAYS
--------------------------------------------------------------------------------

local function measureEnemySectionHeight(w)
    local h = sc(16) + sc(24) + sc(6)
    if sg(UI.showThreats, true) and #S.threatCounts > 0 then
        local tagRowY = 0
        local tagX = sc(4)
        local shown = 0
        local maxRight = w - sc(4)
        for _, tc in ipairs(S.threatCounts) do
            if shown >= 10 then break end
            if tc.count > 0 then
                local txt = tc.tag:upper()
                if tc.count > 1 then txt = txt .. " x" .. tc.count end
                local tagW = tSz(8, txt).x + sc(10)
                if tagX + tagW > maxRight and tagX > sc(4) then
                    tagX = sc(4)
                    tagRowY = tagRowY + sc(17)
                end
                tagX = tagX + tagW + sc(3)
                shown = shown + 1
            end
        end
        h = h + sc(14) + tagRowY + sc(19)
    end
    h = h + sc(6)
    return h
end

local function measureNetWorthBarHeight()
    if not sg(UI.showNetWorth, true) then return 0 end
    local totalNW = S.myTeamNetWorth + S.enemyTeamNetWorth
    if totalNW == 0 then return sc(24) end
    return sc(32)
end

local function measureHeroCountersHeight()
    if not sg(UI.showHeroCounters, true) then return 0 end
    if #S.heroCounterSuggestions == 0 then return 0 end
    return sc(16) + math.min(#S.heroCounterSuggestions, 5) * sc(22)
end

local function measureEnemyFocusHeight()
    if not sg(UI.showEnemyFocus, true) then return 0 end
    if not S.enemyFocus or #S.enemyFocus == 0 then return 0 end
    local rows = clamp(sg(UI.enemyFocusRows, 3), 1, 6)
    return sc(16) + math.min(rows, #S.enemyFocus) * sc(32)
end

local function measureSuggestionsHeight(w)
    local h = sc(18)
    if #S.suggestions == 0 then
        return h + sc(18)
    end
    for _, sug in ipairs(S.suggestions) do
        h = h + buildItemCardLayout(sug, w).h + sc(3)
    end
    return h
end

local function measureNeutralSectionHeight()
    if not sg(UI.showNeutrals, true) then return 0 end
    if S.neutralTier == 0 or #S.neutralSuggestions == 0 then return 0 end
    return sc(6) + sc(16) + (#S.neutralSuggestions * sc(24))
end

local function measureFooterHeight(w)
    local h = sc(6)
    local tip = getFooterTipData()
    if tip then
        local lines = wrapTextLines(9, tip, w - sc(12))
        h = h + (#lines * sc(13)) + sc(4)
    end
    h = h + sc(12)
    return h
end

local function measurePanelHeight(innerW)
    local contentH = sc(CFG.PAD)
    contentH = contentH + sc(CFG.HEADER_H) + sc(4)
    contentH = contentH + measureEnemySectionHeight(innerW)
    contentH = contentH + measureNetWorthBarHeight()
    contentH = contentH + measureHeroCountersHeight()
    contentH = contentH + measureEnemyFocusHeight()
    contentH = contentH + measureSuggestionsHeight(innerW)
    contentH = contentH + measureNeutralSectionHeight()
    contentH = contentH + measureFooterHeight(innerW)
    return F(contentH)
end

local function drawHoverOverlay()
    local cx, cy = getCursorPos2D()
    S.hoveredRegion = findClickRegionAt(cx, cy)

    local hover = S.hoveredRegion
    if hover then
        dRect(hover.x, hover.y, hover.w, hover.h, col(255, 255, 255, 12), 5)
        dBorder(hover.x, hover.y, hover.w, hover.h, col(255, 255, 255, 46), 5, 1)
    end
end

--------------------------------------------------------------------------------
-- PANEL DRAG INPUT
--------------------------------------------------------------------------------
local function HandlePanelInput()
    local pr = S.panelRect
    if not pr then return end

    local cx, cy = getCursorPos2D()
    if not cx or not cy then return end

    local headerH = sc(CFG.HEADER_H)
    local isInHeader = (cx >= (pr.x or 0)) and (cx <= (pr.x or 0) + (pr.w or 0)) and
                       (cy >= (pr.y or 0)) and (cy <= (pr.y or 0) + headerH)

    local mouseDown = false
    if Input and Input.IsKeyDown and Enum and Enum.ButtonCode then
        local okDown, down = pcall(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1, true)
        if not okDown then okDown, down = pcall(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1) end
        mouseDown = okDown and down == true
    end

    if mouseDown and (S.isDragging or panelHitTestAt(cx, cy)) then
        markPanelInputBlocked(0.22)
    end

    if isInHeader and mouseDown and not S.isDragging then
        S.isDragging = true
        S.dragOffset.x = cx - (S.panelPos.x or 0)
        S.dragOffset.y = cy - (S.panelPos.y or 0)
        markPanelInputBlocked(0.25)
    end

    if S.isDragging then
        if mouseDown then
            S.panelPos.x = cx - S.dragOffset.x
            S.panelPos.y = cy - S.dragOffset.y
            local sw, sh = screenSz()
            local pw = pr.w or sc(CFG.PW)
            local ph = pr.h or 400
            S.panelPos.x = clamp(S.panelPos.x, 0, sw - pw)
            S.panelPos.y = clamp(S.panelPos.y, 0, sh - ph)
            SavePanelPositionToMenu(S.panelPos.x, S.panelPos.y)
        else
            S.isDragging = false
            SavePanelPosition(S.panelPos.x, S.panelPos.y)
        end
    end
end

--------------------------------------------------------------------------------
-- MINIMAL MODE: Helper to find which enemies an item counters
--------------------------------------------------------------------------------
local function getCounteredEnemies(itemDef)
    if not itemDef then return {} end
    local enemies = {}

    -- Check if item is a direct counter via HERO_COUNTERS
    for _, enemy in ipairs(S.enemyHeroes) do
        if enemy.included then
            local cd = HERO_COUNTERS[enemy.name]
            if cd and cd.items then
                for _, iName in ipairs(cd.items) do
                    if canonItemName(iName) == itemDef.name then
                        table.insert(enemies, prettyHero(enemy.name))
                        break
                    end
                end
            end
        end
    end

    -- Check trigges matching enemy tags
    if #enemies == 0 and itemDef.triggers then
        for _, enemy in ipairs(S.enemyHeroes) do
            if enemy.included and enemy.tagCounts then
                for _, trigger in ipairs(itemDef.triggers) do
                    if enemy.tagCounts[trigger] and enemy.tagCounts[trigger] > 0 then
                        local name = prettyHero(enemy.name)
                        local found = false
                        for _, e in ipairs(enemies) do
                            if e == name then found = true; break end
                        end
                        if not found then
                            table.insert(enemies, name)
                        end
                        break
                    end
                end
            end
        end
    end

    return enemies
end

--------------------------------------------------------------------------------
-- MINIMAL MODE: Simplified header
--------------------------------------------------------------------------------
local function drawHeaderMinimal(x, y, w, alpha)
    local acc = TC.accent
    local textC = colA(TC.text, alpha)
    dRect(x, y, w, sc(2), colA(acc, alpha * 0.8), 0)
    dText(12, L("title"), x + sc(8), y + sc(8), textC)

    -- Drag hint
    dText(8, "\u{f0b2}", x + w - sc(20), y + sc(8), colA(TC.dim, alpha * 0.4))

    return sc(28)
end

--------------------------------------------------------------------------------
-- MINIMAL MODE: Items with "vs WHO" labels
--------------------------------------------------------------------------------
local function drawSuggestionsMinimal(x, y, w, alpha)
    local curY = y
    dText(10, L("recommended"), x + sc(4), curY, colA(TC.accent, alpha * 0.9))
    curY = curY + sc(18)

    if #S.suggestions == 0 then
        dText(9, L("no_data"), x + sc(4), curY, colA(TC.dim, alpha * 0.5))
        return sc(36)
    end

    for idx, suggestion in ipairs(S.suggestions) do
        local item = suggestion.item
        local owned = sg(UI.showOwned, true) and S.ownedItems[item.name]
        local canAfford = S.myGoldKnown and S.myGold >= item.cost
        local cardH = sc(34)

        -- Card background
        local bgA = F(alpha * 0.35)
        if owned then
            dRect(x, curY, w, cardH, col(18, 35, 25, bgA), sc(6))
        else
            dRect(x, curY, w, cardH, col(16, 18, 30, bgA), sc(6))
        end

        -- Left accent
        if owned then
            dRect(x, curY + sc(3), sc(2), cardH - sc(6), col(50, 200, 100, F(alpha * 0.7)), 1)
        elseif canAfford then
            dRect(x, curY + sc(3), sc(2), cardH - sc(6), colA(TC.accent, alpha * 0.5), 1)
        end

        -- Item icon
        local iconSz = sc(24)
        local iconX = x + sc(6)
        local iconY = curY + F((cardH - iconSz) / 2)
        dRect(iconX, iconY, iconSz, iconSz, col(22, 25, 40, F(alpha * 0.5)), sc(4))
        local iImg = itemIcon(item.name)
        if iImg then
            dImg(iImg, iconX, iconY, iconSz, iconSz, col(255, 255, 255, F(alpha * (owned and 0.4 or 1))), sc(4))
        end

        -- Item name
        local nameX = x + sc(36)
        local nameC
        if owned then nameC = col(80, 200, 120, F(alpha * 0.7))
        elseif canAfford then nameC = col(255, 215, 0, F(alpha * 0.95))
        else nameC = colA(TC.text, alpha) end
        dText(10, shortTextByWidth(10, item.display, w * 0.45), nameX, curY + sc(3), nameC)

        -- Cost badge
        local costTxt = owned and L("owned") or (item.cost .. "g")
        local costSz = tSz(8, costTxt)
        local costBx = x + w - costSz.x - sc(12)
        local costC
        if owned then costC = col(80, 200, 120, F(alpha * 0.65))
        elseif canAfford then costC = col(255, 215, 0, F(alpha * 0.85))
        else costC = col(150, 85, 85, F(alpha * 0.7)) end
        dText(8, costTxt, costBx, curY + sc(4), costC)

        -- "vs WHO" line
        local countered = getCounteredEnemies(item)
        if #countered > 0 then
            local vsText = "vs " .. table.concat(countered, ", ")
            if tSz(8, vsText).x > w - sc(42) then
                vsText = "vs " .. countered[1]
                if #countered > 1 then vsText = vsText .. " +" .. (#countered - 1) end
            end
            dText(8, vsText, nameX, curY + sc(18), col(255, 180, 80, F(alpha * 0.7)))
        else
            -- Show top reason instead
            if suggestion.topReasons and #suggestion.topReasons > 0 then
                dText(8, suggestion.topReasons[1], nameX, curY + sc(18), colA(TC.dim, alpha * 0.6))
            end
        end

        registerClickRegion(x, curY, w, cardH, item.name, "main", idx, true)
        curY = curY + cardH + sc(3)
    end

    return curY - y
end

--------------------------------------------------------------------------------
-- MINIMAL MODE: Panel height measurement
--------------------------------------------------------------------------------
local function measurePanelHeightMinimal(innerW)
    local h = sc(CFG.PAD)
    h = h + sc(28) + sc(4) -- header
    h = h + sc(18) -- "recommended" title
    if #S.suggestions == 0 then
        h = h + sc(36)
    else
        for _ in ipairs(S.suggestions) do
            h = h + sc(34) + sc(3) -- card + gap
        end
    end
    h = h + measureFooterHeight(innerW)
    return F(h)
end

--------------------------------------------------------------------------------
-- DRAW: MAIN PANEL
--------------------------------------------------------------------------------
local function drawPanel()
    if not shouldShowPanel() then
        S.panelVisible = false
        S.panelRect = nil
        clearClickRegions()
        return
    end
    syncThemeColors()

    local sw, sh = screenSz()

    -- Auto-detect high-res and adjust base scale
    local autoScale = 1.0
    if sh >= 2160 then autoScale = 1.6       -- 4K
    elseif sh >= 1440 then autoScale = 1.25  -- 2K / 1440p
    end

    local userScale = clamp(sg(UI.scale, 100), 60, 200) / 100
    local scale = userScale * autoScale
    S.drawScale = scale  -- set BEFORE any drawing/measuring

    local opac = clamp(sg(UI.opacity, 85), 20, 100) / 100
    local pw = F(CFG.PW * scale)
    local pad = sc(CFG.PAD)
    local margin = sc(CFG.MARGIN)
    local rounding = sc(CFG.ROUNDING)

    local innerW = pw - pad * 2
    local isMinimal = sg(UI.panelMode, 0) == 1
    local ph = isMinimal and measurePanelHeightMinimal(innerW) or measurePanelHeight(innerW)

    restorePanelPositionFromMenu()

    -- Use drag position instead of sliders
    local px = F(S.panelPos.x)
    local py = F(S.panelPos.y)
    px = clamp(px, 4, sw - pw - 4)
    py = clamp(py, 4, sh - ph - 4)

    local alpha = 255 * opac
    if alpha < 2 then
        S.panelVisible = false
        S.panelRect = nil
        clearClickRegions()
        return
    end

    clearClickRegions()

    dBlur(px, py, pw, ph)
    local themeBg = TC.bg
    dRect(px, py, pw, ph, col(themeBg.r, themeBg.g, themeBg.b, F(210 * alpha / 255)), rounding)
    local bdrC = TC.border
    dBorder(px, py, pw, ph, col(bdrC.r, bdrC.g, bdrC.b, F(40 * alpha / 255)), rounding, 1)

    local curY = py + pad
    local clipPushed = false

    if isMinimal then
        -- Minimal mode: simplified header + suggestions only + footer
        local hH = drawHeaderMinimal(px + pad, curY, innerW, alpha)
        curY = curY + hH + sc(4)
        local sH = drawSuggestionsMinimal(px + pad, curY, innerW, alpha)
        curY = curY + sH
        drawFooter(px + pad, curY, innerW, alpha)
    else
        -- Extended mode: full layout
        local hH = drawHeader(px + pad, curY, innerW, alpha)
        curY = curY + hH + sc(4)
        local eH = drawEnemySection(px + pad, curY, innerW, alpha)
        curY = curY + eH
        if sg(UI.showNetWorth, true) then
            local nwH = drawNetWorthBar(px + pad, curY, innerW, alpha)
            curY = curY + nwH
        end
        if sg(UI.showHeroCounters, true) then
            local hcH = drawHeroCounters(px + pad, curY, innerW, alpha)
            curY = curY + hcH
        end
        local focusH = drawEnemyFocus(px + pad, curY, innerW, alpha)
        curY = curY + focusH
        local sH = drawSuggestions(px + pad, curY, innerW, alpha)
        curY = curY + sH
        local nH = drawNeutralSection(px + pad, curY, innerW, alpha)
        curY = curY + nH
        drawFooter(px + pad, curY, innerW, alpha)
    end

    if clipPushed and Render.PopClip then pcall(Render.PopClip) end

    S.panelVisible = true
    S.panelRect = {x = px, y = py, w = pw, h = ph}
    drawHoverOverlay()
    HandlePanelInput()
end

--------------------------------------------------------------------------------
-- CALLBACKS
--------------------------------------------------------------------------------
function script.OnUpdate()
    local ok, err = pcall(function()
        if not sg(UI.enabled, true) then return end
        local inGame = false
        pcall(function() inGame = Engine.IsInGame() end)
        if not inGame then return end

        initFonts()
        updateLang()
        refreshRuntimeTestContext()
        refreshMyGold()

        if sg(UI.autoAnalyze, true) then
            local now = gt()
            if now - S.lastAnalysis >= CFG.ANALYSIS_CD then
                S.lastAnalysis = now
                analyzeEnemyTeam()
            end
        end

    end)
    if not ok and err then print("[ItemHelper] Update: " .. tostring(err)) end
end

function script.OnDraw()
    local ok, err = pcall(function()
        if not fontsReady then initFonts() end
        if not sg(UI.enabled, true) then
            S.panelVisible = false
            S.panelRect = nil
            clearClickRegions()
            return
        end

        if not sg(UI.showPanel, true) then
            S.panelVisible = false
            S.panelRect = nil
            clearClickRegions()
            return
        end

        -- Toggle key: use :IsPressed() for edge detection (like broodmother)
        if UI.toggleKey then
            local ok2, pressed = pcall(function() return UI.toggleKey:IsPressed() end)
            if ok2 and pressed then
                S.toggleState = not S.toggleState
            end
        end

        if not S.toggleState then
            S.panelVisible = false
            S.panelRect = nil
            clearClickRegions()
            return
        end

        local inGame = false
        pcall(function() inGame = Engine.IsInGame() end)
        if not inGame then
            S.panelVisible = false
            S.panelRect = nil
            clearClickRegions()
            return
        end

        local now = gt()
        if S.lastFrame > 0 then S.dt = clamp(now - S.lastFrame, 0.001, 0.1) end
        S.lastFrame = now
        S.pulseTime = S.pulseTime + S.dt
        drawPanel()
    end)
    if not ok and err then
        S.panelVisible = false
        S.panelRect = nil
        clearClickRegions()
        print("[ItemHelper] Draw: " .. tostring(err))
    end
end

function script.OnKeyEvent(data, key, event)
    local ok, block = pcall(function()
        if not mouseKey(key) then return false end
        if shouldBlockPanelInput() then
            markPanelInputBlocked(0.22)
            return true
        end
        return false
    end)

    if not ok then
        print("[ItemHelper] KeyEvent: " .. tostring(block))
        return
    end

    if block then return false end
end

function script.OnPrepareUnitOrders(data, playerArg, orderArg, targetArg, positionArg, abilityArg, orderIssuerArg, npcArg, queueArg, showEffectsArg)
    local ok, block = pcall(function()
        if not isLocalPlayerOrder(data, playerArg) then return false end
        if shouldBlockPanelInput() then
            markPanelInputBlocked(0.15)
            return true
        end
        return false
    end)

    if not ok then
        print("[ItemHelper] PrepareUnitOrders: " .. tostring(block))
        return true
    end

    if block then return false end
    return true
end

function script.OnGameEnd()
    S.enemyHeroes = {}
    S.enemyTags = {}
    S.threatCounts = {}
    S.suggestions = {}
    S.neutralSuggestions = {}
    S.ownedItems = {}
    S.enemyItems = {}
    S.enemyItemCounts = {}
    S.myGold = 0
    S.myGoldKnown = false
    S.rawGameModeId = -1
    S.playerCount = 0
    S.testContextKind = nil
    S.myHeroName = ""
    S.gamePhase = PHASE_EARLY
    S.gameMode = GAME_MODE.UNKNOWN
    S.neutralTier = 0
    S.lastAnalysis = 0
    S.heroIcons = {}
    S.itemIcons = {}
    S.clickRegions = {}
    S.hoveredRegion = nil
    S.panelVisible = false
    S.panelRect = nil
    S.panelBlockInputUntil = 0
    S.lastFrame = 0
    S.dt = 0.016
    S.pulseTime = 0
    S.totalNetWorth = 0
    -- Reset net worth analysis
    S.myTeamNetWorth = 0
    S.enemyTeamNetWorth = 0
    S.netWorthDiff = 0
    S.gameTempo = "even"
    -- Reset hero counters
    S.heroCounterSuggestions = {}
    -- Reset drag/toggle state
    S.isDragging = false
    S.dragOffset = {x = 0, y = 0}
    S.toggleState = true
    S.toggleKeyWasDown = false
    S.drawScale = 1.0
    -- Reset shop detection state
    _shopCache = false
    _shopCacheT = 0
    _shopPanel = nil
    _panelSearchDone = false
    -- Clear text size cache
    clearTextCache()
end

return script
