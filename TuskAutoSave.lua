--[[
    Tusk Auto Save
    Versus saves: Snowball on enemy, then RMB ally pickup while rolling.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local LOG_PREFIX = "[TuskAutoSave] "
local HERO_NAME = "npc_dota_hero_tusk"
local CAST_ID = "tusk.auto_save"
local SNOWBALL_NAME = "tusk_snowball"
local CONFIG_SECTION = "tusk_auto_save"

local ALLY_SCAN_INTERVAL = 0.15
local ALLY_SYNC_INTERVAL = 0.5
local ENEMY_ROSTER_SYNC_INTERVAL = 1.0
local DEBUG_LOG_INTERVAL = 1.0
local LANG_CACHE_INTERVAL = 1.0
local DEFAULT_SNOWBALL_RANGE = 1250
local BLINK_SAVE_MARGIN = 50
local BLINK_AFTER_DELAY = 0.35
local BLINK_AFTER_DELAY_PREEMPT = 0.15
local SNOWBALL_AFTER_BLINK_TIME = 1.5
local SAVE_TARGET_SILENCE = 2.0
local VERSUS_CONFIG_PREFIX = "versus_"
local CHRONO_FREEZE_MOD = "modifier_faceless_void_chronosphere_freeze"
local CHRONO_DEFAULT_RADIUS = 500
local CHRONO_SAFE_MARGIN = 75
local BLINK_LANDING_SCAN_STEP = 25
local SAFE_CAST_ANGLE_STEP = math.pi / 12

local PANEL_HEADER_FONT_CANDIDATES = {
    "Segoe UI",
    "Tahoma",
    "Arial",
}
local PANEL_HEADER_HEIGHT = 28
local PANEL_HEADER_PAD_X = 8
local PANEL_HEADER_TEXT_SIZE = 14
local PANEL_HEADER_ICON_SIZE = 14
local PANEL_HEADER_ICON_GAP = 6
local PANEL_HEADER_RADIUS = 5
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_TITLE_TEXT = "Auto Save"

-- Ally debuffs that mark a circular no-blink zone (stay outside while saving).
local SAVE_HAZARD_MODIFIERS = {
    {
        allyMod = CHRONO_FREEZE_MOD,
        defaultRadius = CHRONO_DEFAULT_RADIUS,
        margin = CHRONO_SAFE_MARGIN,
        label = "chronosphere",
    },
}

local O_CAST_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local O_ATTACK_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
local ORDER_ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

local SNOWBALL_SAVE_EXPIRE = 4.0
local SNOWBALL_CAST_TIMEOUT = 0.9
local SNOWBALL_PICKUP_INTERVAL = 0.08
local SNOWBALL_PICKUP_MAX_ATTEMPTS = 15
local PREEMPTIVE_CAST_LEAD = 0.25
local PREEMPTIVE_CAST_SCORE_BASE = -500
local SNOWBALL_HERO_TARGET_BIAS = -500
local SNOWBALL_CREEP_TARGET_BIAS = 250
local DEFAULT_SNOWBALL_GATHER_RADIUS = 325
local ALLY_IN_SNOWBALL_MODIFIERS = {
    "modifier_tusk_snowball_movement",
    "modifier_tusk_snowball",
    "modifier_tusk_snowball_visible",
}

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local Icons = {
    enable = "\u{f00c}", -- check
    gear   = "\u{f013}", -- settings
    flask  = "\u{f0c3}", -- mana threshold
    blink  = "panorama/images/items/blink_png.vtex_c",
    panel       = "\u{f108}", -- hud panel
    panelHeader = "\u{e1ac}", -- hud panel header
    bug         = "\u{f188}", -- debug
    versus      = "\u{f05b}", -- crosshairs / threat picker
}

local VERSUS_THREATS = {
    -- Teamfight ultimates
    { id = "tidehunter_ravage", mods = { "modifier_tidehunter_ravage" }, default = true },
    { id = "enigma_black_hole", mods = { "modifier_enigma_black_hole_pull" }, default = true },
    { id = "faceless_void_chronosphere", mods = { "modifier_faceless_void_chronosphere_freeze" }, default = true },
    { id = "magnataur_reverse_polarity", mods = { "modifier_magnataur_reverse_polarity" }, default = true },
    { id = "axe_berserkers_call", mods = { "modifier_axe_berserkers_call" }, default = true },
    { id = "legion_commander_duel", mods = { "modifier_legion_commander_duel" }, default = true },
    { id = "winter_wyvern_winters_curse", mods = { "modifier_winter_wyvern_winters_curse" }, default = true },
    { id = "earthshaker_echo_slam", mods = { "modifier_earthshaker_fissure_stun" }, default = true },
    { id = "earthshaker_fissure", mods = { "modifier_earthshaker_fissure_stun" }, default = false },
    { id = "nevermore_requiem", mods = {
        "modifier_nevermore_requiem_fear",
        "modifier_nevermore_requiem_slow",
    }, default = true },
    { id = "warlock_rain_of_chaos", mods = {}, default = true },

    -- Hard channeled / long disables
    { id = "bane_fiends_grip", mods = { "modifier_bane_fiends_grip", "modifier_bane_fiends_grip_cast_illusion" }, default = true },
    { id = "batrider_flaming_lasso", mods = { "modifier_batrider_flaming_lasso" }, default = true },
    { id = "pudge_dismember", mods = { "modifier_pudge_dismember" }, default = true },
    { id = "shadow_shaman_shackles", mods = { "modifier_shadow_shaman_shackles" }, default = true },
    { id = "rubick_telekinesis", mods = { "modifier_rubick_telekinesis", "modifier_rubick_telekinesis_stun" }, default = true },
    { id = "beastmaster_primal_roar", mods = {
        "modifier_beastmaster_primal_roar_push",
        "modifier_beastmaster_primal_roar_slow",
    }, default = true },
    { id = "elder_titan_echo_stomp", mods = { "modifier_elder_titan_echo_stomp" }, default = true },
    { id = "primal_beast_pulverize", mods = { "modifier_primal_beast_pulverize" }, default = true },
    { id = "necrolyte_reapers_scythe", mods = { "modifier_necrolyte_reapers_scythe" }, default = true },
    { id = "doom_bringer_doom", mods = { "modifier_doom_bringer_doom" }, default = true },
    { id = "obsidian_destroyer_astral_imprisonment", mods = { "modifier_obsidian_destroyer_astral_imprisonment" }, default = true },
    { id = "treant_overgrowth", mods = { "modifier_treant_overgrowth" }, default = true },
    { id = "medusa_stone_gaze", mods = { "modifier_medusa_stone_gaze_stone" }, default = true },
    { id = "puck_dream_coil", mods = { "modifier_puck_coiled_break_stun" }, default = true },

    -- Gap-close / catch disables
    { id = "storm_spirit_electric_vortex", mods = { "modifier_storm_spirit_electric_vortex_pull" }, default = true },
    { id = "slark_pounce", mods = { "modifier_slark_pounce" }, default = true },
    { id = "bloodseeker_rupture", mods = { "modifier_bloodseeker_rupture" }, default = true },
    { id = "morphling_adaptive_strike_agi", mods = { "modifier_morphling_adaptive_strike" }, default = true },
    { id = "mars_arena_of_blood", mods = { "modifier_mars_arena_of_blood_leash" }, default = true },
    { id = "mars_spear", mods = { "modifier_mars_spear_stun" }, default = true },
    { id = "pangolier_gyroshell", mods = { "modifier_pangolier_gyroshell_stunned" }, default = true },
    { id = "void_spirit_aether_remnant", mods = { "modifier_void_spirit_aether_remnant_pull" }, default = true },
    { id = "hoodwink_bushwhack", mods = { "modifier_hoodwink_bushwhack_trap" }, default = true },
    { id = "rattletrap_hookshot", mods = { "modifier_rattletrap_hookshot" }, default = true },
    { id = "kunkka_ghostship", mods = { "modifier_kunkka_ghostship_knockout" }, default = true },
    { id = "kunkka_torrent", mods = { "modifier_kunkka_torrent" }, default = false },
    { id = "spirit_breaker_charge_of_darkness", mods = { "modifier_spirit_breaker_charge_of_darkness" }, default = true },
    { id = "spirit_breaker_nether_strike", mods = { "modifier_spirit_breaker_nether_strike_stun" }, default = false },
    { id = "tusk_snowball", mods = { "modifier_tusk_snowball_movement" }, default = true },
    { id = "windrunner_shackleshot", mods = { "modifier_windrunner_shackleshot_stun" }, default = true },
    { id = "brewmaster_storm_cyclone", mods = { "modifier_brewmaster_storm_cyclone" }, default = true },
    { id = "invoker_cold_snap", mods = { "modifier_invoker_cold_snap" }, default = true },
    { id = "marci_grapple", mods = { "modifier_marci_grapple_stun" }, default = false },

    -- Roots / sleeps
    { id = "snapfire_firesnap_cookie", mods = { "modifier_snapfire_firesnap_cookie_stun" }, default = false },
    { id = "crystal_maiden_frostbite", mods = { "modifier_crystal_maiden_frostbite" }, default = true },
    { id = "naga_siren_ensnare", mods = { "modifier_naga_siren_ensnare" }, default = true },
    { id = "ember_spirit_searing_chains", mods = { "modifier_ember_spirit_searing_chains" }, default = true },
    { id = "bane_nightmare", mods = { "modifier_bane_nightmare" }, default = true },
    { id = "dark_willow_bramble_maze", mods = { "modifier_dark_willow_bramble_maze" }, default = true },
    { id = "dark_willow_cursed_crown", mods = { "modifier_dark_willow_cursed_crown" }, default = false },
    { id = "meepo_earthbind", mods = { "modifier_meepo_earthbind" }, default = true },
    { id = "abyssal_underlord_pit_of_malice", mods = { "modifier_abyssal_underlord_pit_of_malice_ensare" }, default = true },
    { id = "furion_sprout", mods = { "modifier_furion_sprout_entangle" }, default = false },
    { id = "keeper_of_the_light_radiant_bind", mods = { "modifier_keeper_of_the_light_radiant_bind" }, default = false },
    { id = "enigma_malefice", mods = { "modifier_enigma_malefice" }, default = false },

    -- Silences (high impact)
    { id = "silencer_global_silence", mods = { "modifier_silencer_global_silence" }, default = true },
    { id = "silencer_last_word", mods = { "modifier_silencer_last_word" }, default = true },
    { id = "death_prophet_silence", mods = { "modifier_death_prophet_silence" }, default = true },
    { id = "drow_ranger_wave_of_silence", mods = { "modifier_drowranger_wave_of_silence" }, default = true },
    { id = "skywrath_mage_ancient_seal", mods = { "modifier_skywrath_mage_ancient_seal" }, default = true },
    { id = "disruptor_static_storm", mods = { "modifier_disruptor_static_storm" }, default = true },
    { id = "muerta_the_calling", mods = { "modifier_muerta_the_calling_silence" }, default = true },
    { id = "puck_waning_rift", mods = { "modifier_puck_waning_rift_silence" }, default = false },

    -- Hex / items
    { id = "item_abyssal_blade", mods = { "modifier_bashed" }, default = true },
    { id = "item_sheepstick", mods = { "modifier_sheepstick_debuff" }, default = true },
    { id = "item_gungir", mods = { "modifier_gungir_debuff" }, default = true },
    { id = "item_rod_of_atos", mods = { "modifier_rod_of_atos_debuff" }, default = true },
    { id = "item_bloodthorn", mods = { "modifier_bloodthorn_debuff" }, default = true },
    { id = "item_orchid", mods = { "modifier_orchid_malevolence_debuff" }, default = true },
    { id = "item_fallen_sky", mods = { "modifier_item_fallen_sky_burn" }, default = true },
    { id = "lion_voodoo", mods = { "modifier_lion_voodoo" }, default = true },
    { id = "shadow_shaman_voodoo", mods = { "modifier_shadow_shaman_voodoo" }, default = true },

    -- Strong single-target stuns
    { id = "lion_impale", mods = { "modifier_lion_impale" }, default = true },
    { id = "sandking_burrowstrike", mods = { "modifier_sandking_impale" }, default = true },
    { id = "sven_storm_bolt", mods = { "modifier_sven_storm_bolt_hidden" }, default = true },
    { id = "monkey_king_boundless_strike", mods = { "modifier_monkey_king_boundless_strike_stun" }, default = true },
    { id = "nyx_assassin_impale", mods = { "modifier_nyx_assassin_impale" }, default = false },
    { id = "mirana_arrow", mods = { "modifier_mirana_arrow_stun" }, default = false },
    { id = "chaos_knight_chaos_bolt", mods = { "modifier_chaos_knight_chaos_bolt", "modifier_chaos_knight_chaos_bolt_stun" }, default = true },
    { id = "centaur_hoof_stomp", mods = { "modifier_centaur_hoof_stomp_stun" }, default = true },
    { id = "dragon_knight_dragon_tail", mods = { "modifier_dragon_knight_dragon_tail_stun" }, default = false },
    { id = "jakiro_ice_path", mods = { "modifier_jakiro_ice_path_stun" }, default = false },
    { id = "leshrac_split_earth", mods = { "modifier_leshrac_split_earth_stun" }, default = false },
    { id = "lich_sinister_gaze", mods = { "modifier_lich_sinister_gaze" }, default = false },
    { id = "lina_light_strike_array", mods = { "modifier_lina_light_strike_array_stun" }, default = false },
    { id = "pudge_meat_hook", mods = { "modifier_pudge_meat_hook" }, default = false },
    { id = "skeleton_king_hellfire_blast", mods = { "modifier_skeleton_king_hellfire_blast" }, default = false },
    { id = "slardar_slithereen_crush", mods = { "modifier_slithereen_crush" }, default = false },
    { id = "tiny_avalanche", mods = { "modifier_tiny_avalanche_stun" }, default = false },
    { id = "tiny_toss", mods = { "modifier_tiny_toss" }, default = false },
    { id = "tusk_walrus_punch", mods = { "modifier_tusk_walrus_punch_stun" }, default = false },
    { id = "vengefulspirit_magic_missile", mods = { "modifier_vengefulspirit_magic_missile_stun" }, default = false },
    { id = "witch_doctor_paralyzing_cask", mods = { "modifier_witch_doctor_paralyzing_cask_stun" }, default = false },
    { id = "ogre_magi_fireblast", mods = { "modifier_ogre_magi_fireblast_stun" }, default = false },
    { id = "gyrocopter_homing_missile", mods = { "modifier_gyrocopter_homing_missile_stun" }, default = false },
    { id = "techies_suicide", mods = { "modifier_techies_suicide_leap" }, default = false },
    { id = "antimage_mana_void", mods = { "modifier_antimage_mana_void" }, default = false },
    { id = "ancient_apparition_cold_feet", mods = { "modifier_ancientapparition_coldfeet_freeze" }, default = false },
}

--#endregion

--#region State

local UI = {}

local State = {
    lastAllyScanTime = -100,
    lastAllySyncTime = -100,
    cachedAllies = {},
    matchAllyNames = {},
    matchAllySet = {},
    cachedAllyEntities = {},
    cachedAllyUnitNames = {},
    allyEnabled = {},
    lastDebugLogTime = -100,
    saveQuietUntil = -100,
    wasMousePressed = false,
    snowballAfterBlink = nil,
    activeSnowballSave = nil,
    lastVersusRosterKey = "",
    lastVersusSyncTime = -100,
    versusPrefs = {},
    panelHeaderFaFont = nil,
    panelHeaderFaAvailable = nil,
}

local PanelConfig = {
    X = 200,
    Y = 200,
}

local PanelDrag = {
    IsDragging = false,
    OffsetX = 0,
    OffsetY = 0,
}

local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    BorderEnabled = Color(191, 140, 255, 255),
    CellBg = Color(12, 12, 16, 255),
}

local LangState = {
    language = "en",
    nextCheck = 0,
}

local fontPanel = 0
local LoggerInstance = Logger and Logger("TuskAutoSave") or nil

--#endregion

--#region Helpers

(function()
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function Log(level, message)
    message = tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if pcall(LoggerInstance[level], LoggerInstance, message) then
            return
        end
    end
    print(LOG_PREFIX .. message)
end

local function IsDebugEnabled()
    return UI and UI.Debug and UI.Debug.Get and UI.Debug:Get() == true
end

local function LogDebug(message)
    if not IsDebugEnabled() then
        return
    end
    Log("debug", message)
end

local function IsValidFontHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    return type(handle) == "userdata"
end

local function IsValidTextSize(size)
    return (type(size) == "table" or type(size) == "userdata")
        and type(size.x) == "number"
        and type(size.y) == "number"
end

local function CanMeasureWithFont(handle, sampleText, fontSize)
    if not IsValidFontHandle(handle) or not Render or not Render.TextSize then
        return false
    end
    return IsValidTextSize(SafeCall(
        Render.TextSize,
        handle,
        fontSize or PANEL_HEADER_TEXT_SIZE,
        sampleText or PANEL_TITLE_TEXT))
end

local function GetLibRender()
    ---@diagnostic disable-next-line: undefined-global
    return LIB_RENDER
end

local function ResolvePanelHeaderFaFont()
    if State.panelHeaderFaFont ~= nil then
        if State.panelHeaderFaFont == 0 then
            return nil
        end
        return State.panelHeaderFaFont
    end

    State.panelHeaderFaFont = 0
    local libRender = GetLibRender()
    if type(libRender) ~= "table" then
        return nil
    end

    local faFont = libRender.default_font_awesome
    if IsValidFontHandle(faFont) then
        State.panelHeaderFaFont = faFont
        return faFont
    end

    return nil
end

local function HasLibRenderText()
    local libRender = GetLibRender()
    return type(libRender) == "table" and type(libRender.text) == "function"
end

local function CanUsePanelHeaderFaIcon()
    local font = ResolvePanelHeaderFaFont()
    if not IsValidFontHandle(font) or not Render or not Render.TextSize then
        return false
    end

    if not IsValidTextSize(SafeCall(Render.TextSize, font, PANEL_HEADER_ICON_SIZE, Icons.panelHeader)) then
        return false
    end

    return HasLibRenderText()
end

local function IsPanelHeaderFaIconAvailable()
    if State.panelHeaderFaAvailable ~= nil then
        return State.panelHeaderFaAvailable
    end

    State.panelHeaderFaAvailable = CanUsePanelHeaderFaIcon()
    return State.panelHeaderFaAvailable
end

local function GetPanelHeaderIconFontSize(scale)
    return math.floor(PANEL_HEADER_ICON_SIZE * scale + 0.5)
end

local function MeasurePanelHeaderFaIconSize(scale)
    local fontSize = GetPanelHeaderIconFontSize(scale)
    local font = ResolvePanelHeaderFaFont()
    local glyph = Icons.panelHeader

    local libRender = GetLibRender()
    if type(libRender) == "table" and type(libRender.text_size) == "function" then
        local size = SafeCall(libRender.text_size, font, fontSize, glyph)
        if IsValidTextSize(size) then
            return size
        end
    end

    if CanMeasureWithFont(font, glyph) then
        local size = SafeCall(Render.TextSize, font, fontSize, glyph)
        if IsValidTextSize(size) then
            return size
        end
    end

    return Vec2(fontSize, fontSize)
end

local function TryDrawPanelHeaderFaIcon(font, size, glyph, pos, color)
    if not IsValidFontHandle(font) then
        return false, nil
    end

    local x, y
    if type(pos) == "table" or type(pos) == "userdata" then
        x, y = pos.x, pos.y
    end
    if type(x) ~= "number" or type(y) ~= "number" then
        return false, nil
    end

    local drawColor = Color(color.r, color.g, color.b, color.a or 255)

    -- LIB_RENDER.text(font, size, glyph, color, x, y) — Vec2 as 5th arg succeeds in pcall but draws nothing.
    local libRender = GetLibRender()
    if type(libRender) == "table" and type(libRender.text) == "function" then
        if pcall(libRender.text, font, size, glyph, drawColor, x, y) then
            return true, "lib_render_xy"
        end
    end

    if Render and Render.Text and pcall(Render.Text, font, size, glyph, Vec2(x, y), drawColor) then
        return true, "render_text"
    end

    return false, nil
end

local function DrawPanelHeaderIcon(textX, titleContentY, titleContentH, titleIconSize, titleIconGap, scale, iconColor)
    local font = ResolvePanelHeaderFaFont()
    local fontSize = GetPanelHeaderIconFontSize(scale)
    local iconSize = titleIconSize or MeasurePanelHeaderFaIconSize(scale)
    local iconH = iconSize.y or fontSize
    local iconY = titleContentY + math.floor((titleContentH - iconH) * 0.5 + 0.5)
    local drew = TryDrawPanelHeaderFaIcon(
        font,
        fontSize,
        Icons.panelHeader,
        Vec2(textX, iconY),
        iconColor)
    if drew then
        return textX + (iconSize.x or fontSize) + titleIconGap
    end

    return textX
end

local function TryLibRenderDefaultFont(sampleText)
    local libRender = GetLibRender()
    if type(libRender) ~= "table" then
        return nil
    end

    local defaultFont = libRender.default_font
    if IsValidFontHandle(defaultFont)
        and CanMeasureWithFont(defaultFont, sampleText, PANEL_HEADER_TEXT_SIZE) then
        return defaultFont
    end

    return nil
end

local function TryDefaultFont(fontName)
    local libRender = GetLibRender()
    if type(fontName) ~= "string" or fontName == "" or type(libRender) ~= "table" then
        return nil
    end

    local defaultFont = libRender.default_font
    if type(defaultFont) == "function" then
        local handle = SafeCall(defaultFont, fontName)
        if IsValidFontHandle(handle) then
            return handle
        end

        handle = SafeCall(defaultFont, libRender, fontName)
        if IsValidFontHandle(handle) then
            return handle
        end
    elseif type(defaultFont) == "table" then
        local entry = defaultFont[fontName]
        if IsValidFontHandle(entry) then
            return entry
        end

        if type(entry) == "function" then
            local handle = SafeCall(entry)
            if IsValidFontHandle(handle) then
                return handle
            end

            handle = SafeCall(entry, fontName)
            if IsValidFontHandle(handle) then
                return handle
            end

            handle = SafeCall(entry, libRender, fontName)
            if IsValidFontHandle(handle) then
                return handle
            end
        end
    end

    return nil
end

local PANEL_HEADER_FONT_WEIGHTS = {
    Enum and Enum.FontWeight and Enum.FontWeight.SEMIBOLD or 600,
    Enum and Enum.FontWeight and Enum.FontWeight.MEDIUM or 500,
    400,
}

local function TryLoadRenderFont(fontName, sampleText, weights)
    if type(fontName) ~= "string" or fontName == "" or not Render or not Render.LoadFont then
        return nil
    end

    local fontFlag = Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0
    local weightList = weights or PANEL_HEADER_FONT_WEIGHTS
    for w = 1, #weightList do
        local handle = SafeCall(Render.LoadFont, fontName, fontFlag, weightList[w])
        if CanMeasureWithFont(handle, sampleText, PANEL_HEADER_TEXT_SIZE) then
            return handle
        end
    end

    return nil
end

local function ResolvePanelHeaderFont(sampleText)
    local preloaded = TryLibRenderDefaultFont(sampleText)
    if preloaded then
        return preloaded
    end

    for i = 1, #PANEL_HEADER_FONT_CANDIDATES do
        local fontName = PANEL_HEADER_FONT_CANDIDATES[i]
        local handle = TryDefaultFont(fontName)
        if CanMeasureWithFont(handle, sampleText, PANEL_HEADER_TEXT_SIZE) then
            return handle
        end

        handle = TryLoadRenderFont(fontName, sampleText)
        if handle then
            return handle
        end
    end
    return 0
end

fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_TEXT) or 0

local function GetMenuBlurStrength()
    local widget = Menu and Menu.Find and Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")
    if not widget or not widget.Get then
        return PANEL_BLUR_BASE_STRENGTH
    end

    local factor = SafeCall(widget.Get, widget)
    if type(factor) ~= "number" or factor <= 0 then
        return nil
    end

    if factor > 1 then
        factor = factor / 100
    end

    return math.max(0.1, factor * PANEL_BLUR_BASE_STRENGTH)
end

local function IsPanelHeaderTransparent()
    local alpha = Colors.HeaderBg.a
    if alpha == nil then
        alpha = 255
    end
    return alpha < 255
end

local function DrawPanelBlur(layout, scale)
    if not IsPanelHeaderTransparent() or not Render or not Render.Blur then
        return
    end

    local strength = GetMenuBlurStrength()
    if not strength then
        return
    end

    SafeCall(
        Render.Blur,
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        strength,
        1.0,
        PANEL_HEADER_RADIUS * scale,
        Enum.DrawFlags.None)
end

local function GetUILanguage()
    local now = os.clock()
    if now < LangState.nextCheck then
        return LangState.language
    end
    LangState.nextCheck = now + LANG_CACHE_INTERVAL

    local langWidget = Menu and Menu.Find and Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    if langWidget and langWidget.Get then
        local idx = SafeCall(langWidget.Get, langWidget)
        if type(idx) == "number" and idx == 1 then
            LangState.language = "ru"
            return LangState.language
        end
    end

    LangState.language = "en"
    return LangState.language
end

local function L(en, ru)
    if GetUILanguage() == "ru" and ru then
        return ru
    end
    return en
end

local function WithTooltip(widget, text)
    if widget and widget.ToolTip then
        SafeCall(widget.ToolTip, widget, text)
    end
end

local function MenuIcon(widget, icon)
    if widget and widget.Icon then
        SafeCall(widget.Icon, widget, icon)
    end
end

local function CleanHeroName(unitName)
    if not unitName then
        return ""
    end
    local cleanName = unitName:gsub("npc_dota_hero_", "")
    if cleanName == "" then
        return ""
    end
    return cleanName:sub(1, 1):upper() .. cleanName:sub(2)
end

local function GetHeroDisplayName(hero)
    return CleanHeroName(SafeCall(NPC.GetUnitName, hero))
end

local function HeroIconPath(unitName)
    if not unitName or unitName == "" then
        return nil
    end
    return "panorama/images/heroes/" .. unitName .. "_png.vtex_c"
end

local function GetHealthPct(unit)
    local hp = Entity.GetHealth(unit) or 0
    local maxHp = Entity.GetMaxHealth(unit) or 1
    if maxHp <= 0 then
        return 1
    end
    return hp / maxHp
end

local function GetManaPct(mana, maxMana)
    if not maxMana or maxMana <= 0 then
        return 1
    end
    return mana / maxMana
end

local function IsValidHero(unit)
    return unit
        and SafeCall(Entity.IsAlive, unit)
        and not SafeCall(Entity.IsDormant, unit)
        and not SafeCall(NPC.IsIllusion, unit)
end

local function IsLocalTusk(hero)
    return hero and SafeCall(NPC.GetUnitName, hero) == HERO_NAME
end

local function IsSnowballRolling(me)
    return SafeCall(NPC.HasModifier, me, "modifier_tusk_snowball")
        or SafeCall(NPC.HasModifier, me, "modifier_tusk_snowball_visible")
end

local function GetUnitDisplayName(unit)
    if not unit then
        return "unknown"
    end
    if Tree and Tree.IsActive and SafeCall(Tree.IsActive, unit) then
        return "Tree"
    end
    local name = GetHeroDisplayName(unit)
    if name ~= "" then
        return name
    end
    return SafeCall(NPC.GetUnitName, unit) or "unit"
end

local function IsValidAlly(myHero, ally)
    return IsValidHero(ally)
        and ally ~= myHero
        and SafeCall(Entity.IsSameTeam, myHero, ally)
        and not SafeCall(Hero.IsClone, ally)
end

local function CanAct(me)
    if not IsValidHero(me) then
        return false
    end

    return not SafeCall(NPC.IsStunned, me)
        and not SafeCall(NPC.IsSilenced, me)
        and not SafeCall(NPC.HasState, me, Enum.ModifierState.MODIFIER_STATE_ROOTED)
        and not SafeCall(NPC.IsChannellingAbility, me)
        and not IsSnowballRolling(me)
end

local function CanCastAbility(me, ability)
    if not CanAct(me) then
        return false
    end
    if ability and SafeCall(Ability.IsInAbilityPhase, ability) then
        return false
    end
    return true
end

local function IsVersusReason(reason)
    return reason and reason:sub(1, 7) == "versus:"
end

local function IsPreemptiveCastReason(reason)
    return type(reason) == "string" and reason:sub(-5) == ":cast"
end

local function GetBlinkAfterDelay(reason)
    if IsPreemptiveCastReason(reason) then
        return BLINK_AFTER_DELAY_PREEMPT
    end
    return BLINK_AFTER_DELAY
end

local function CastAbilityOnTarget(me, ability, target, tag)
    if not ability or not target then
        return false
    end

    local targetPos = SafeCall(Entity.GetAbsOrigin, target)
    if not targetPos then
        return false
    end

    local orderTag = CAST_ID .. "." .. tag
    if Ability and Ability.CastTarget then
        SafeCall(Ability.CastTarget, ability, target, false, true, true, orderTag)
        return true
    end

    local player = SafeCall(Players.GetLocal)
    if not player then
        return false
    end

    if Player and Player.PrepareUnitOrders then
        SafeCall(Player.PrepareUnitOrders,
            player,
            O_CAST_TARGET,
            target,
            targetPos,
            ability,
            ORDER_ISSUER,
            me,
            false,
            false,
            true,
            true,
            orderTag,
            false
        )
        return true
    end

    return false
end

local function GetSnowballGatherRadius(snowball)
    if not snowball then
        return DEFAULT_SNOWBALL_GATHER_RADIUS
    end

    for _, key in ipairs({ "snowball_gather_radius", "gather_radius", "radius" }) do
        local radius = SafeCall(Ability.GetLevelSpecialValueFor, snowball, key)
        if type(radius) == "number" and radius > 0 then
            return radius
        end
    end

    return DEFAULT_SNOWBALL_GATHER_RADIUS
end

local function IsSnowballPickupWindow(ctx)
    if IsSnowballRolling(ctx.me) then
        return true
    end

    local snowball = ctx.abilities.snowball
    if snowball and SafeCall(Ability.IsInAbilityPhase, snowball) then
        return true
    end

    local channel = SafeCall(NPC.GetChannellingAbility, ctx.me)
    return channel and SafeCall(Ability.GetName, channel) == SNOWBALL_NAME
end

local function WasSnowballCastAccepted(ctx, active)
    if IsSnowballPickupWindow(ctx) then
        return true
    end

    local snowball = ctx.abilities.snowball
    if not snowball then
        return false
    end

    local cd = SafeCall(Ability.GetCooldown, snowball) or 0
    return cd > (active.preCastCooldown or 0) + 0.05
end

local function IssueSnowballPickup(ctx, ally, attemptIndex)
    local player = SafeCall(Players.GetLocal)
    if not player or not ally then
        return false, "none"
    end

    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    if not allyPos then
        return false, "none"
    end

    if Player and Player.AttackTarget then
        SafeCall(
            Player.AttackTarget,
            player,
            ctx.me,
            ally,
            false,
            true,
            true,
            CAST_ID .. ".pickup_attack",
            false
        )
        return true, "attack"
    end

    if Player and Player.PrepareUnitOrders then
        SafeCall(Player.PrepareUnitOrders,
            player,
            O_ATTACK_TARGET,
            ally,
            allyPos,
            nil,
            ORDER_ISSUER,
            ctx.me,
            false,
            false,
            true,
            true,
            CAST_ID .. ".pickup",
            false
        )
        return true, "attack_order"
    end

    return false, "none"
end

local function IsAllyInSnowballGatherRange(ctx, ally)
    local gatherRange = GetSnowballGatherRadius(ctx.abilities.snowball)
    return SafeCall(NPC.IsEntityInRange, ctx.me, ally, gatherRange) ~= false
end

local function GetBlink(me)
    for _, itemName in ipairs(BLINK_ITEMS) do
        local blink = SafeCall(NPC.GetItem, me, itemName, true)
        if blink then
            return blink, itemName
        end
    end
    return nil
end

local function GetItemCastRange(me, item, fallback)
    if not item then
        return fallback or 0
    end
    local range = SafeCall(Ability.GetCastRange, item) or fallback or 0
    return range + (SafeCall(NPC.GetCastRangeBonus, me) or 0)
end

local function Dist2D(a, b)
    if not a or not b then
        return math.huge
    end
    return (b - a):Length2D()
end

local function IsPointInSaveHazard(pos, hazard)
    if not pos or not hazard or not hazard.center then
        return false
    end
    return Dist2D(pos, hazard.center) < (hazard.radius or 0)
end

local function ResolveHazardCenter(mod)
    if not mod then
        return nil
    end

    local auraOwner = SafeCall(Modifier.GetAuraOwner, mod)
    if auraOwner then
        local pos = SafeCall(Entity.GetAbsOrigin, auraOwner)
        if pos then
            return pos
        end
    end

    local caster = SafeCall(Modifier.GetCaster, mod)
    if caster then
        return SafeCall(Entity.GetAbsOrigin, caster)
    end

    return nil
end

local function GetAllySaveHazard(ally)
    for _, entry in ipairs(SAVE_HAZARD_MODIFIERS) do
        if SafeCall(NPC.HasModifier, ally, entry.allyMod) then
            local mod = SafeCall(NPC.GetModifier, ally, entry.allyMod)
            local center = ResolveHazardCenter(mod)
            if center then
                local radius = SafeCall(Modifier.GetAuraRadius, mod)
                if type(radius) ~= "number" or radius <= 0 then
                    radius = entry.defaultRadius or CHRONO_DEFAULT_RADIUS
                end
                return {
                    label = entry.label or entry.allyMod,
                    center = center,
                    radius = radius + (entry.margin or CHRONO_SAFE_MARGIN),
                }
            end
        end
    end
    return nil
end

local function IsValidSavePosition(pos, allyPos, castRange, hazard)
    if not pos or not allyPos or castRange <= 0 then
        return false
    end
    if Dist2D(pos, allyPos) > castRange then
        return false
    end
    if hazard and IsPointInSaveHazard(pos, hazard) then
        return false
    end
    return true
end

local function FindSafeCastPositionNearAlly(allyPos, castRange, hazard)
    if not allyPos or castRange <= 0 then
        return nil
    end
    if not hazard or not hazard.center then
        return allyPos
    end

    if not IsPointInSaveHazard(allyPos, hazard) then
        return allyPos
    end

    local center = hazard.center
    local rimRadius = hazard.radius or CHRONO_DEFAULT_RADIUS
    local allyDist = Dist2D(allyPos, center)
    if allyDist <= 0 then
        return nil
    end

    local dirX = (allyPos.x - center.x) / allyDist
    local dirY = (allyPos.y - center.y) / allyDist
    local rimPos = Vector(
        center.x + dirX * rimRadius,
        center.y + dirY * rimRadius,
        allyPos.z
    )

    if IsValidSavePosition(rimPos, allyPos, castRange, hazard) then
        return rimPos
    end

    local baseAngle = math.atan(dirY, dirX)
    for step = 1, math.floor((2 * math.pi) / SAFE_CAST_ANGLE_STEP) do
        local angle = baseAngle + step * SAFE_CAST_ANGLE_STEP
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)
        local tryRim = Vector(
            center.x + cosA * rimRadius,
            center.y + sinA * rimRadius,
            allyPos.z
        )
        if IsValidSavePosition(tryRim, allyPos, castRange, hazard) then
            return tryRim
        end
    end

    for step = 1, math.floor((2 * math.pi) / SAFE_CAST_ANGLE_STEP) do
        local angle = baseAngle - step * SAFE_CAST_ANGLE_STEP
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)
        local tryRim = Vector(
            center.x + cosA * rimRadius,
            center.y + sinA * rimRadius,
            allyPos.z
        )
        if IsValidSavePosition(tryRim, allyPos, castRange, hazard) then
            return tryRim
        end
    end

    return nil
end

local function ScanSaveBlinkLanding(origin, allyPos, castRange, blinkRange, hazard)
    if not origin or not allyPos or not hazard then
        return nil
    end

    local bestPos = nil
    local bestDist = math.huge
    local rimRadius = hazard.radius or CHRONO_DEFAULT_RADIUS
    local center = hazard.center

    for step = 0, math.floor((2 * math.pi) / SAFE_CAST_ANGLE_STEP) - 1 do
        local angle = step * SAFE_CAST_ANGLE_STEP
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)
        local rim = Vector(
            center.x + cosA * rimRadius,
            center.y + sinA * rimRadius,
            allyPos.z
        )

        if not IsValidSavePosition(rim, allyPos, castRange, hazard) then
            goto continue_rim
        end

        local distToRim = Dist2D(origin, rim)
        if distToRim > blinkRange then
            local dx = (rim.x - origin.x) / distToRim
            local dy = (rim.y - origin.y) / distToRim
            for tryDist = blinkRange, BLINK_SAVE_MARGIN, -BLINK_LANDING_SCAN_STEP do
                local landing = Vector(
                    origin.x + dx * tryDist,
                    origin.y + dy * tryDist,
                    origin.z
                )
                if IsValidSavePosition(landing, allyPos, castRange, hazard) then
                    if tryDist < bestDist then
                        bestDist = tryDist
                        bestPos = landing
                    end
                    break
                end
            end
        elseif distToRim >= BLINK_SAVE_MARGIN and distToRim < bestDist then
            bestDist = distToRim
            bestPos = rim
        end

        ::continue_rim::
    end

    return bestPos
end

local function ComputeBlinkTowardSavePos(origin, allyPos, targetPos, castRange, blinkRange, hazard)
    if not origin or not allyPos or not targetPos or blinkRange <= 0 then
        return nil
    end

    local dist = Dist2D(origin, targetPos)
    if dist <= blinkRange and IsValidSavePosition(targetPos, allyPos, castRange, hazard) then
        return targetPos
    end

    if dist <= 0 then
        return nil
    end

    local dx = (targetPos.x - origin.x) / dist
    local dy = (targetPos.y - origin.y) / dist
    local maxBlink = math.min(blinkRange, dist)

    for tryDist = maxBlink, BLINK_SAVE_MARGIN, -BLINK_LANDING_SCAN_STEP do
        local landing = Vector(
            origin.x + dx * tryDist,
            origin.y + dy * tryDist,
            origin.z
        )
        if IsValidSavePosition(landing, allyPos, castRange, hazard) then
            return landing
        end
    end

    return nil
end

local function ComputeBlinkPosNearAlly(origin, allyPos, castRange, blinkRange)
    if not origin or not allyPos or castRange <= 0 or blinkRange <= 0 then
        return nil
    end

    local toAlly = allyPos - origin
    local dist = toAlly:Length2D()
    if dist <= castRange then
        return nil
    end

    local needClose = dist - castRange + BLINK_SAVE_MARGIN
    if needClose <= 0 then
        return nil
    end

    local blinkDist = math.min(blinkRange, needClose)
    if dist <= 0 or blinkDist <= 0 then
        return nil
    end

    local dirX = toAlly.x / dist
    local dirY = toAlly.y / dist
    return Vector(
        origin.x + dirX * blinkDist,
        origin.y + dirY * blinkDist,
        origin.z
    )
end

local function ComputeSaveBlinkPos(origin, allyPos, castRange, blinkRange, ally)
    if not origin or not allyPos or castRange <= 0 or blinkRange <= 0 then
        return nil
    end

    local hazard = ally and GetAllySaveHazard(ally) or nil

    if IsValidSavePosition(origin, allyPos, castRange, hazard) then
        return nil
    end

    if hazard then
        local safeCastPos = FindSafeCastPositionNearAlly(allyPos, castRange, hazard)
        if not safeCastPos then
            LogDebug(string.format(
                "save skip: ally too deep in %s, no safe cast point",
                hazard.label or "hazard"
            ))
            return nil
        end

        local direct = ComputeBlinkTowardSavePos(
            origin, allyPos, safeCastPos, castRange, blinkRange, hazard
        )
        if direct then
            return direct
        end

        return ScanSaveBlinkLanding(origin, allyPos, castRange, blinkRange, hazard)
    end

    return ComputeBlinkPosNearAlly(origin, allyPos, castRange, blinkRange)
end

local function CastBlinkToPosition(me, blink, pos)
    if not blink or not pos then
        return false
    end

    SafeCall(Ability.CastPosition, blink, pos, false, true, true, CAST_ID .. ".blink", true)
    return true
end

local function CanUseBlinkSave()
    return UI.UseBlink and UI.UseBlink.Get and UI.UseBlink:Get() == true
end

local function CanCastSnowballSave(ctx)
    local snowball = ctx.abilities.snowball
    if not snowball or (SafeCall(Ability.GetLevel, snowball) or 0) <= 0 then
        return false
    end
    if not CanCastAbility(ctx.me, snowball) then
        return false
    end
    return SafeCall(Ability.IsCastable, snowball, ctx.mana) ~= false
end

local function IsValidSaveAlly(ally)
    if not ally then
        return false
    end
    if SafeCall(NPC.IsIllusion, ally) then
        return false
    end
    return SafeCall(Entity.IsAlive, ally) ~= false
end

local function MarkSaveQuiet(now)
    State.saveQuietUntil = now + SAVE_TARGET_SILENCE
end

local function ClearPendingSnowball()
    State.snowballAfterBlink = nil
end

local function ClearActiveSnowballSave()
    State.activeSnowballSave = nil
end

local SNOWBALL_EXCLUDED_TARGETS = {
    npc_dota_warlock_golem = true,
}

local function IsExcludedSnowballTarget(unit)
    local unitName = SafeCall(NPC.GetUnitName, unit) or ""
    if unitName == "" then
        return false
    end
    if SNOWBALL_EXCLUDED_TARGETS[unitName] then
        return true
    end
    if unitName:find("warlock_golem", 1, true) then
        return true
    end
    return false
end

local function IsValidSnowballEnemy(me, unit)
    if not unit or unit == me then
        return false
    end
    if not SafeCall(Entity.IsAlive, unit) then
        return false
    end
    if SafeCall(Entity.IsSameTeam, me, unit) ~= false then
        return false
    end
    if SafeCall(NPC.IsIllusion, unit) and SafeCall(NPC.IsHero, unit) then
        return false
    end
    if IsExcludedSnowballTarget(unit) then
        return false
    end
    return true
end

local function IsValidSnowballTarget(me, unit, range)
    return IsValidSnowballEnemy(me, unit)
        and SafeCall(NPC.IsEntityInRange, me, unit, range) ~= false
end

local function IsValidSnowballCastTarget(me, unit, range)
    if not unit or unit == me then
        return false
    end
    if Tree and Tree.IsActive and SafeCall(Tree.IsActive, unit) then
        return SafeCall(NPC.IsEntityInRange, me, unit, range) ~= false
    end
    return IsValidSnowballTarget(me, unit, range)
end

local function IsSnowballCastBlocked(me, unit, range)
    if not IsValidSnowballCastTarget(me, unit, range) then
        return true
    end
    if SafeCall(Entity.IsDormant, unit) then
        return true
    end
    if SafeCall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
        return true
    end
    if SafeCall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
        return true
    end
    if SafeCall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then
        return true
    end
    if NPC.IsVisible and SafeCall(NPC.IsVisible, unit) == false then
        return true
    end
    return false
end

local function FindSnowballTreeNearAlly(ctx, ally)
    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    if not allyPos or not Entity.GetTreesInRadius then
        return nil
    end

    local trees = SafeCall(Entity.GetTreesInRadius, ctx.me, ctx.snowballRange, true) or {}
    local best = nil
    local bestDist = math.huge

    for _, tree in ipairs(trees) do
        if SafeCall(NPC.IsEntityInRange, ctx.me, tree, ctx.snowballRange) ~= false then
            local treePos = SafeCall(Entity.GetAbsOrigin, tree)
            if treePos then
                local distToAlly = Dist2D(treePos, allyPos)
                if distToAlly < bestDist then
                    bestDist = distToAlly
                    best = tree
                end
            end
        end
    end

    return best
end

local function FindSnowballEnemyTarget(ctx, ally, preferredEnemy)
    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    local teamNum = SafeCall(Entity.GetTeamNum, ctx.me)
    local range = ctx.snowballRange
    if range <= 0 then
        return nil
    end

    if preferredEnemy and not IsSnowballCastBlocked(ctx.me, preferredEnemy, range) then
        return preferredEnemy
    end

    local best = nil
    local bestScore = math.huge

    local function ConsiderUnit(unit, bias)
        if IsSnowballCastBlocked(ctx.me, unit, range) then
            return
        end

        local unitPos = SafeCall(Entity.GetAbsOrigin, unit)
        if not unitPos then
            return
        end

        local distToAlly = allyPos and Dist2D(unitPos, allyPos) or Dist2D(ctx.origin, unitPos)
        local score = distToAlly + (bias or 0)
        if score < bestScore then
            bestScore = score
            best = unit
        end
    end

    local heroes = SafeCall(Heroes.InRadius, ctx.origin, range, teamNum, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    for _, enemy in ipairs(heroes) do
        ConsiderUnit(enemy, SNOWBALL_HERO_TARGET_BIAS)
    end

    if NPCs and NPCs.InRadius then
        local creeps = SafeCall(NPCs.InRadius, ctx.origin, range, teamNum, Enum.TeamType.TEAM_ENEMY, true, true) or {}
        for _, creep in ipairs(creeps) do
            if SafeCall(NPC.IsHero, creep) == false and not IsExcludedSnowballTarget(creep) then
                ConsiderUnit(creep, SNOWBALL_CREEP_TARGET_BIAS)
            end
        end
    end

    if best then
        return best
    end

    local tree = FindSnowballTreeNearAlly(ctx, ally)
    if tree and IsValidSnowballCastTarget(ctx.me, tree, range) then
        return tree
    end

    return nil
end

local function IsSnowballModifierFromTusk(mod, me)
    if mod then
        local caster = SafeCall(Modifier.GetCaster, mod)
        if caster and caster ~= me then
            return false
        end
    end

    return true
end

local function IsAllyPickedUpInSnowball(ally, me)
    for _, modName in ipairs(ALLY_IN_SNOWBALL_MODIFIERS) do
        if SafeCall(NPC.HasModifier, ally, modName) then
            local mod = SafeCall(NPC.GetModifier, ally, modName)
            return IsSnowballModifierFromTusk(mod, me)
        end
    end

    local modifiers = SafeCall(NPC.GetModifiers, ally) or {}
    for _, mod in ipairs(modifiers) do
        local name = SafeCall(Modifier.GetName, mod) or ""
        if name:find("tusk_snowball", 1, true) and IsSnowballModifierFromTusk(mod, me) then
            return true
        end
    end

    return false
end

local function CanStartSnowballSave(ctx, ally, preferredEnemy)
    if not CanCastSnowballSave(ctx) then
        return false
    end
    if not FindSnowballEnemyTarget(ctx, ally, preferredEnemy) then
        return false
    end

    local hazard = GetAllySaveHazard(ally)
    if hazard and IsPointInSaveHazard(ctx.origin, hazard) then
        return false
    end

    return true
end

local function StartSnowballSave(ctx, ally, reason, preferredEnemy)
    local enemy = FindSnowballEnemyTarget(ctx, ally, preferredEnemy)
    if not enemy then
        LogDebug("save skip: no snowball enemy target in range")
        return false
    end

    local snowball = ctx.abilities.snowball
    local preCastCooldown = snowball and (SafeCall(Ability.GetCooldown, snowball) or 0) or 0
    if not snowball or not CastAbilityOnTarget(ctx.me, snowball, enemy, "snowball_cast") then
        return false
    end

    if preferredEnemy and preferredEnemy ~= enemy then
        LogDebug(string.format(
            "save snowball: fallback target %s (preferred %s blocked)",
            GetUnitDisplayName(enemy),
            GetUnitDisplayName(preferredEnemy)
        ))
    end

    State.activeSnowballSave = {
        ally = ally,
        enemy = enemy,
        preferredEnemy = preferredEnemy,
        reason = reason,
        phase = "cast",
        startedAt = ctx.now,
        expireTime = ctx.now + SNOWBALL_SAVE_EXPIRE,
        castExpireTime = ctx.now + SNOWBALL_CAST_TIMEOUT,
        preCastCooldown = preCastCooldown,
        lastPickupTry = -100,
        lastRangeLog = -100,
        pickupAttempts = 0,
    }

    LogDebug(string.format(
        "save cast: snowball on %s to pick up %s reason=%s",
        GetUnitDisplayName(enemy),
        GetHeroDisplayName(ally),
        reason or "unknown"
    ))
    return true
end

local function CanBlinkForSnowballSave(ctx, ally, reason)
    if not IsVersusReason(reason) then
        return false
    end
    if not CanUseBlinkSave() or not ctx.items.blink then
        return false
    end
    if not CanCastSnowballSave(ctx) then
        return false
    end
    if not SafeCall(Ability.IsCastable, ctx.items.blink, ctx.mana) then
        return false
    end

    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    if not allyPos then
        return false
    end

    local gatherRange = GetSnowballGatherRadius(ctx.abilities.snowball)
    return ComputeSaveBlinkPos(
        ctx.origin,
        allyPos,
        gatherRange,
        ctx.blinkRange,
        ally
    ) ~= nil
end

local function CanPickupWithoutBlink(ctx, ally, reason)
    if not IsVersusReason(reason) then
        return false
    end
    if CanBlinkForSnowballSave(ctx, ally, reason) then
        return false
    end
    return IsAllyInSnowballGatherRange(ctx, ally)
end

local function ProcessActiveSnowballSave(ctx)
    local active = State.activeSnowballSave
    if not active then
        return false
    end

    if ctx.now >= (active.expireTime or 0) then
        LogDebug("save expire: snowball pickup timed out")
        ClearActiveSnowballSave()
        return false
    end

    local ally = active.ally
    if not ally or not IsValidSaveAlly(ally) then
        ClearActiveSnowballSave()
        return false
    end

    if IsAllyPickedUpInSnowball(ally, ctx.me) then
        MarkSaveQuiet(ctx.now)
        LogDebug("save done: picked up " .. GetHeroDisplayName(ally))
        ClearActiveSnowballSave()
        return true
    end

    if active.phase == "cast" then
        if WasSnowballCastAccepted(ctx, active) then
            active.phase = "pickup"
            active.lastPickupTry = ctx.now - SNOWBALL_PICKUP_INTERVAL
            active.pickupAttempts = 0
            LogDebug("save phase: snowball accepted, pickup " .. GetHeroDisplayName(ally))
            if IsAllyInSnowballGatherRange(ctx, ally) then
                active.pickupAttempts = 1
                active.lastPickupTry = ctx.now
                IssueSnowballPickup(ctx, ally, 1)
            end
            return true
        end

        if ctx.now >= (active.castExpireTime or active.expireTime or 0) then
            LogDebug("save fail: snowball cast did not start")
            MarkSaveQuiet(ctx.now)
            ClearActiveSnowballSave()
            return false
        end

        return true
    end

    if not WasSnowballCastAccepted(ctx, active) then
        LogDebug("save end: snowball ended before pickup")
        MarkSaveQuiet(ctx.now)
        ClearActiveSnowballSave()
        return false
    end

    if (active.pickupAttempts or 0) >= SNOWBALL_PICKUP_MAX_ATTEMPTS then
        LogDebug("save fail: pickup attempts exhausted")
        MarkSaveQuiet(ctx.now)
        ClearActiveSnowballSave()
        return true
    end

    local inRange = IsAllyInSnowballGatherRange(ctx, ally)
    if not inRange then
        if ctx.now - (active.lastRangeLog or -100) >= 0.5 then
            active.lastRangeLog = ctx.now
            LogDebug(string.format(
                "save wait: %s outside snowball gather range dist=%.0f",
                GetHeroDisplayName(ally),
                Dist2D(ctx.origin, SafeCall(Entity.GetAbsOrigin, ally) or ctx.origin)
            ))
        end
        return true
    end

    if ctx.now - (active.lastPickupTry or -100) >= SNOWBALL_PICKUP_INTERVAL then
        active.lastPickupTry = ctx.now
        active.pickupAttempts = (active.pickupAttempts or 0) + 1
        local _, pickupMode = IssueSnowballPickup(ctx, ally, active.pickupAttempts)
        LogDebug(string.format(
            "save cast: pickup %s on %s attempt=%d/%d dist=%.0f",
            pickupMode or "order",
            GetHeroDisplayName(ally),
            active.pickupAttempts,
            SNOWBALL_PICKUP_MAX_ATTEMPTS,
            Dist2D(ctx.origin, SafeCall(Entity.GetAbsOrigin, ally) or ctx.origin)
        ))
    end

    return true
end

local function ProcessPendingSnowball(ctx)
    local pending = State.snowballAfterBlink
    if not pending then
        return false
    end

    if ctx.now >= (pending.expireTime or 0) then
        ClearPendingSnowball()
        return false
    end

    if ctx.now < (pending.readyAfter or 0) then
        return true
    end

    local ally = pending.ally
    if not ally or not IsValidSaveAlly(ally) then
        ClearPendingSnowball()
        return false
    end

    if not CanStartSnowballSave(ctx, ally, pending.preferredEnemy) then
        return true
    end

    if StartSnowballSave(ctx, ally, pending.reason, pending.preferredEnemy) then
        ClearPendingSnowball()
    end

    return true
end

local function VersusIconPath(nameId)
    if nameId:sub(1, 5) == "item_" then
        return "panorama/images/items/" .. nameId:sub(6) .. "_png.vtex_c"
    end
    return "panorama/images/spellicons/" .. nameId .. "_png.vtex_c"
end

local function IsVersusItemThreat(threatId)
    return type(threatId) == "string" and threatId:sub(1, 5) == "item_"
end

local function IsEnemyHero(me, hero)
    if not me or not hero or hero == me then
        return false
    end
    if SafeCall(Hero.IsIllusion, hero) or SafeCall(NPC.IsIllusion, hero) then
        return false
    end
    if SafeCall(Hero.IsClone, hero) then
        return false
    end
    return SafeCall(Entity.IsSameTeam, me, hero) == false
end

local function GetEnemyHeroNameSet(me)
    local names = {}
    if not me then
        return names
    end

    local heroes = SafeCall(Heroes.GetAll) or {}
    for _, hero in ipairs(heroes) do
        if IsEnemyHero(me, hero) then
            local unitName = SafeCall(NPC.GetUnitName, hero) or ""
            local internal = unitName:gsub("^npc_dota_hero_", "")
            if internal ~= "" then
                names[internal] = true
            end
        end
    end

    return names
end

local function GetEnemyRosterKey(nameSet)
    if not nameSet then
        return ""
    end

    local keys = {}
    for name in pairs(nameSet) do
        keys[#keys + 1] = name
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function IsVersusThreatForHero(threatId, heroInternalName)
    if not threatId or not heroInternalName or heroInternalName == "" then
        return false
    end

    local prefix = heroInternalName .. "_"
    return threatId:sub(1, #prefix) == prefix
end

local function IsVersusThreatInMatch(threatId, enemyHeroNames)
    if IsVersusItemThreat(threatId) then
        return true
    end
    if not enemyHeroNames then
        return true
    end

    local hasEnemyNames = false
    for heroName in pairs(enemyHeroNames) do
        hasEnemyNames = true
        if IsVersusThreatForHero(threatId, heroName) then
            return true
        end
    end

    if not hasEnemyNames then
        return true
    end

    return false
end

local function FindVersusThreat(threatId)
    for _, threat in ipairs(VERSUS_THREATS) do
        if threat.id == threatId then
            return threat
        end
    end
    return nil
end

local function GetVersusThreatDefault(threatId)
    local threat = FindVersusThreat(threatId)
    if not threat then
        return false
    end
    return threat.default == true
end

local function GetVersusConfigKey(threatId)
    return VERSUS_CONFIG_PREFIX .. threatId
end

local function LoadVersusPrefs()
    State.versusPrefs = {}
    for _, threat in ipairs(VERSUS_THREATS) do
        local stored = SafeCall(Config.ReadInt, CONFIG_SECTION, GetVersusConfigKey(threat.id), -1)
        if type(stored) == "number" and stored >= 0 then
            State.versusPrefs[threat.id] = stored == 1
        end
    end
end

local function SaveVersusPref(threatId, enabled)
    State.versusPrefs[threatId] = enabled == true
    SafeCall(Config.WriteInt, CONFIG_SECTION, GetVersusConfigKey(threatId), enabled and 1 or 0)
end

local function ApplyVersusPrefsToWidget(widget)
    if not widget or not widget.Set or not widget.List then
        return
    end

    local listed = SafeCall(widget.List, widget)
    if not listed then
        return
    end

    for _, threatId in ipairs(listed) do
        local enabled = State.versusPrefs[threatId]
        if enabled ~= nil then
            SafeCall(widget.Set, widget, threatId, enabled == true)
        end
    end
end

local function SyncVersusPrefsFromWidget()
    local widget = UI.Versus
    if not widget or not widget.Get then
        return
    end

    local listed = widget.List and SafeCall(widget.List, widget)
    if listed then
        for _, threatId in ipairs(listed) do
            local value = SafeCall(widget.Get, widget, threatId)
            if value ~= nil then
                SaveVersusPref(threatId, value == true)
            end
        end
        return
    end

    for _, threat in ipairs(VERSUS_THREATS) do
        local value = SafeCall(widget.Get, widget, threat.id)
        if value ~= nil then
            SaveVersusPref(threat.id, value == true)
        end
    end
end

local function GetVersusThreatEnabledState(threatId, defaultEnabled)
    if State.versusPrefs[threatId] ~= nil then
        return State.versusPrefs[threatId] == true
    end

    local widget = UI.Versus
    if widget and widget.Get then
        local value = SafeCall(widget.Get, widget, threatId)
        if value ~= nil then
            return value == true
        end
    end
    return defaultEnabled == true
end

local function BuildVersusMultiSelectItems(enemyHeroNames)
    local items = {}
    for _, threat in ipairs(VERSUS_THREATS) do
        if IsVersusThreatInMatch(threat.id, enemyHeroNames) then
            items[#items + 1] = {
                threat.id,
                VersusIconPath(threat.id),
                GetVersusThreatEnabledState(threat.id, threat.default),
            }
        end
    end
    return items
end

local function RefreshVersusMultiSelect(me, saveToConfig)
    local widget = UI.Versus
    if not widget or not widget.Update then
        return false
    end

    local enemyHeroNames = GetEnemyHeroNameSet(me)
    local rosterKey = GetEnemyRosterKey(enemyHeroNames)
    if rosterKey == State.lastVersusRosterKey then
        return false
    end

    State.lastVersusRosterKey = rosterKey
    SyncVersusPrefsFromWidget()
    local items = BuildVersusMultiSelectItems(enemyHeroNames)
    if #items == 0 then
        return false
    end

    SafeCall(widget.Update, widget, items, false, saveToConfig == true)
    ApplyVersusPrefsToWidget(widget)
    return true
end

local function ShowAllVersusThreats(saveToConfig)
    local widget = UI.Versus
    if not widget or not widget.Update then
        return false
    end

    SyncVersusPrefsFromWidget()
    State.lastVersusRosterKey = ""
    SafeCall(widget.Update, widget, BuildVersusMultiSelectItems(nil), false, saveToConfig == true)
    ApplyVersusPrefsToWidget(widget)
    return true
end

local function SyncVersusThreats(me, now)
    if not me or not Engine.IsInGame() then
        return
    end
    if now - State.lastVersusSyncTime < ENEMY_ROSTER_SYNC_INTERVAL then
        return
    end
    State.lastVersusSyncTime = now
    RefreshVersusMultiSelect(me, true)
end

local function IsVersusThreatEnabled(threatId)
    if State.versusPrefs[threatId] ~= nil then
        return State.versusPrefs[threatId] == true
    end

    local widget = UI.Versus
    if not widget or not widget.Get then
        return GetVersusThreatDefault(threatId)
    end

    local value = SafeCall(widget.Get, widget, threatId)
    if value ~= nil then
        return value == true
    end

    return GetVersusThreatDefault(threatId)
end

local function AllyHasBeastmasterPrimalRoarThreat(ally)
    if SafeCall(NPC.HasModifier, ally, "modifier_beastmaster_primal_roar_push")
        or SafeCall(NPC.HasModifier, ally, "modifier_beastmaster_primal_roar_slow") then
        return true
    end

    -- Primary roar target only gets the shared stun modifier, not push/slow.
    local stunMod = SafeCall(NPC.GetModifier, ally, "modifier_stunned")
    if not stunMod then
        return false
    end

    local ability = SafeCall(Modifier.GetAbility, stunMod)
    if ability and SafeCall(Ability.GetName, ability) == "beastmaster_primal_roar" then
        return true
    end

    local caster = SafeCall(Modifier.GetCaster, stunMod)
    if caster and SafeCall(NPC.GetUnitName, caster) == "npc_dota_hero_beastmaster" then
        return true
    end

    return false
end

local GENERIC_CONTROL_MODIFIERS = {
    modifier_stunned = true,
    modifier_bashed = true,
    modifier_rooted = true,
    modifier_silenced = true,
    modifier_hexed = true,
}

local function IsThreatFromCaster(threatId, caster)
    if not caster then
        return false
    end

    local casterName = SafeCall(NPC.GetUnitName, caster) or ""
    local heroName = casterName:gsub("^npc_dota_hero_", "")
    return IsVersusThreatForHero(threatId, heroName)
end

local function IsActiveEnemyThreatModifier(ally, mod)
    if not ally or not mod then
        return false
    end

    if SafeCall(Modifier.IsDebuff, mod) ~= true then
        return false
    end

    local caster = SafeCall(Modifier.GetCaster, mod)
    if not caster or caster == ally then
        return false
    end

    return SafeCall(Entity.IsSameTeam, ally, caster) == false
end

local function AllyHasThreatAbilityModifier(ally, threat)
    local modifiers = SafeCall(NPC.GetModifiers, ally) or {}
    for _, mod in ipairs(modifiers) do
        local ability = SafeCall(Modifier.GetAbility, mod)
        if ability and SafeCall(Ability.GetName, ability) == threat.id then
            if IsActiveEnemyThreatModifier(ally, mod) then
                return true
            end
        end

        local modName = SafeCall(Modifier.GetName, mod) or ""
        if GENERIC_CONTROL_MODIFIERS[modName] then
            local caster = SafeCall(Modifier.GetCaster, mod)
            if IsThreatFromCaster(threat.id, caster)
                and IsActiveEnemyThreatModifier(ally, mod) then
                return true
            end
        end
    end

    return false
end

local function AllyMatchesVersusThreat(ally, threat)
    if threat.id == "beastmaster_primal_roar" then
        return AllyHasBeastmasterPrimalRoarThreat(ally)
    end

    for _, modifierName in ipairs(threat.mods) do
        local mod = SafeCall(NPC.GetModifier, ally, modifierName)
        if mod and IsActiveEnemyThreatModifier(ally, mod) then
            return true
        end
    end

    return AllyHasThreatAbilityModifier(ally, threat)
end

local function GetAllyThreatSourceEnemy(ally, threatId)
    if not ally or not threatId then
        return nil
    end

    local threat = nil
    for _, entry in ipairs(VERSUS_THREATS) do
        if entry.id == threatId then
            threat = entry
            break
        end
    end
    if not threat then
        return nil
    end

    if threat.id == "beastmaster_primal_roar" then
        for _, modifierName in ipairs(threat.mods) do
            local mod = SafeCall(NPC.GetModifier, ally, modifierName)
            if mod and IsActiveEnemyThreatModifier(ally, mod) then
                return SafeCall(Modifier.GetCaster, mod)
            end
        end

        local stunMod = SafeCall(NPC.GetModifier, ally, "modifier_stunned")
        if stunMod and IsActiveEnemyThreatModifier(ally, stunMod) then
            local ability = SafeCall(Modifier.GetAbility, stunMod)
            if ability and SafeCall(Ability.GetName, ability) == "beastmaster_primal_roar" then
                return SafeCall(Modifier.GetCaster, stunMod)
            end
            local caster = SafeCall(Modifier.GetCaster, stunMod)
            if caster and SafeCall(NPC.GetUnitName, caster) == "npc_dota_hero_beastmaster" then
                return caster
            end
        end
        return nil
    end

    for _, modifierName in ipairs(threat.mods) do
        local mod = SafeCall(NPC.GetModifier, ally, modifierName)
        if mod and IsActiveEnemyThreatModifier(ally, mod) then
            return SafeCall(Modifier.GetCaster, mod)
        end
    end

    local modifiers = SafeCall(NPC.GetModifiers, ally) or {}
    for _, mod in ipairs(modifiers) do
        if not IsActiveEnemyThreatModifier(ally, mod) then
            goto continue_mod
        end

        local ability = SafeCall(Modifier.GetAbility, mod)
        if ability and SafeCall(Ability.GetName, ability) == threat.id then
            return SafeCall(Modifier.GetCaster, mod)
        end

        local modName = SafeCall(Modifier.GetName, mod) or ""
        if GENERIC_CONTROL_MODIFIERS[modName] then
            local caster = SafeCall(Modifier.GetCaster, mod)
            if IsThreatFromCaster(threat.id, caster) then
                return caster
            end
        end

        ::continue_mod::
    end

    return nil
end

local function GetAllyVersusThreat(ally)
    for index, threat in ipairs(VERSUS_THREATS) do
        if IsVersusThreatEnabled(threat.id) then
            if AllyMatchesVersusThreat(ally, threat) then
                return threat.id, index - 1
            end
        end
    end

    return nil
end

local PREEMPTIVE_CAST_CONFIG = {
    nevermore_requiem = {
        ability = "nevermore_requiem",
        defaultCastPoint = 1.67,
        impactDelay = 0,
        radiusSpecial = "requiem_radius",
        defaultRadius = 1000,
        leadFraction = 0.5,
        minElapsed = 0.15,
        useCasterOrigin = true,
    },
    warlock_rain_of_chaos = {
        ability = "warlock_rain_of_chaos",
        defaultCastPoint = 0.5,
        impactDelaySpecial = "stun_delay",
        defaultImpactDelay = 0.5,
        radiusSpecial = "aoe",
        defaultRadius = 600,
        castRangeFallback = 900,
        leadTime = 0.2,
        thinkerMod = "modifier_warlock_rain_of_chaos_thinker",
    },
}

local function GetPreemptiveThreatIndex(threatId)
    for index, threat in ipairs(VERSUS_THREATS) do
        if threat.id == threatId then
            return index - 1
        end
    end
    return 0
end

local function GetPreemptiveCastTiming(ability, config)
    local castPoint = SafeCall(Ability.GetCastPoint, ability, true)
    if type(castPoint) ~= "number" or castPoint <= 0 then
        castPoint = config.defaultCastPoint or 0
    end

    local impactDelay = config.impactDelay or config.defaultImpactDelay or 0
    if config.impactDelaySpecial then
        local delay = SafeCall(Ability.GetLevelSpecialValueFor, ability, config.impactDelaySpecial)
        if type(delay) == "number" and delay >= 0 then
            impactDelay = delay
        end
    end

    local effectRadius = config.defaultRadius or 0
    if config.radiusSpecial then
        local radius = SafeCall(Ability.GetLevelSpecialValueFor, ability, config.radiusSpecial)
        if type(radius) == "number" and radius > 0 then
            effectRadius = radius
        end
    end

    return castPoint, impactDelay, effectRadius
end

local function GetPreemptiveCastLeadTime(config, castPoint)
    if config.leadFraction and type(castPoint) == "number" and castPoint > 0 then
        return castPoint * config.leadFraction
    end
    return config.leadTime or PREEMPTIVE_CAST_LEAD
end

local function FindAbilityThinkerOrigin(ctx, center, searchRadius, thinkerMod)
    if not center or not thinkerMod or not NPCs or not NPCs.InRadius then
        return nil
    end

    local teamNum = SafeCall(Entity.GetTeamNum, ctx.me)
    local units = SafeCall(
        NPCs.InRadius,
        center,
        searchRadius,
        teamNum,
        Enum.TeamType.TEAM_BOTH,
        true,
        true
    ) or {}

    for _, unit in ipairs(units) do
        if SafeCall(NPC.HasModifier, unit, thinkerMod) then
            return SafeCall(Entity.GetAbsOrigin, unit)
        end
    end

    return nil
end

local function IsAllyInsideThreatRadius(allyPos, center, radius)
    if not allyPos or not center or type(radius) ~= "number" or radius <= 0 then
        return false
    end
    return Dist2D(allyPos, center) <= radius
end

local function GetEnemyPreemptiveCastZone(ctx, enemy, threatId, config, now)
    if not IsVersusThreatEnabled(threatId) or not IsEnemyHero(ctx.me, enemy) then
        return nil
    end

    local ability = SafeCall(NPC.GetAbility, enemy, config.ability)
    if not ability then
        return nil
    end

    local inCastPhase = SafeCall(Ability.IsInAbilityPhase, ability) == true
    local castStart = SafeCall(Ability.GetCastStartTime, ability)
    if type(castStart) ~= "number" or castStart <= 0 then
        if not inCastPhase then
            return nil
        end
        castStart = now
    end

    local castPoint, impactDelay, effectRadius = GetPreemptiveCastTiming(ability, config)
    local elapsed = now - castStart
    local leadTime = GetPreemptiveCastLeadTime(config, castPoint)
    local triggerAt = math.max(config.minElapsed or 0, castPoint - leadTime)
    local impactAt = castPoint + impactDelay
    local enemyPos = SafeCall(Entity.GetAbsOrigin, enemy)
    if not enemyPos then
        return nil
    end

    if config.useCasterOrigin then
        if not inCastPhase or elapsed < triggerAt or elapsed > castPoint + 0.1 then
            return nil
        end
        return {
            center = enemyPos,
            radius = effectRadius,
        }
    end

    if elapsed < triggerAt or elapsed > impactAt + 0.2 then
        return nil
    end

    local castRange = SafeCall(Ability.GetCastRange, ability) or config.castRangeFallback or 900
    local searchR = castRange + effectRadius + 200
    local thinkerPos = config.thinkerMod
        and FindAbilityThinkerOrigin(ctx, enemyPos, searchR, config.thinkerMod)
    if thinkerPos then
        return {
            center = thinkerPos,
            radius = effectRadius,
        }
    end

    if inCastPhase and elapsed >= triggerAt then
        return {
            center = enemyPos,
            radius = castRange + effectRadius,
        }
    end

    if elapsed >= castPoint and elapsed <= impactAt + 0.1 then
        return {
            center = enemyPos,
            radius = castRange + effectRadius,
        }
    end

    return nil
end

local function GetPreemptiveCastThreat(ctx, ally)
    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    if not allyPos then
        return nil
    end

    local teamNum = SafeCall(Entity.GetTeamNum, ctx.me)
    local scanRange = ctx.scanRange or ctx.snowballRange or DEFAULT_SNOWBALL_RANGE
    local enemies = SafeCall(
        Heroes.InRadius,
        ctx.origin,
        scanRange,
        teamNum,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    ) or {}

    local bestThreatId = nil
    local bestEnemy = nil
    local bestScore = math.huge

    for _, enemy in ipairs(enemies) do
        for threatId, config in pairs(PREEMPTIVE_CAST_CONFIG) do
            if IsVersusThreatEnabled(threatId) then
                local zone = GetEnemyPreemptiveCastZone(ctx, enemy, threatId, config, ctx.now)
                if zone and IsAllyInsideThreatRadius(allyPos, zone.center, zone.radius) then
                    local score = PREEMPTIVE_CAST_SCORE_BASE - GetPreemptiveThreatIndex(threatId)
                    if score < bestScore then
                        bestScore = score
                        bestThreatId = threatId
                        bestEnemy = enemy
                    end
                end
            end
        end
    end

    if bestThreatId then
        return bestThreatId, bestScore, bestEnemy
    end
    return nil
end

local function GetSnowballCastRange(me, snowball)
    if not snowball then
        return DEFAULT_SNOWBALL_RANGE
    end

    local specialRange = SafeCall(Ability.GetLevelSpecialValueFor, snowball, "snowball_cast_range")
    if type(specialRange) == "number" and specialRange > 0 then
        return specialRange + (SafeCall(NPC.GetCastRangeBonus, me) or 0)
    end

    local baseRange = SafeCall(Ability.GetCastRange, snowball) or DEFAULT_SNOWBALL_RANGE
    return baseRange + (SafeCall(NPC.GetCastRangeBonus, me) or 0)
end

local function AllyConfigKey(cleanName)
    return "ally_" .. cleanName:lower()
end

local function IsAllySaveEnabled(cleanName)
    if cleanName == "" then
        return false
    end

    local cached = State.allyEnabled[cleanName]
    if cached ~= nil then
        return cached
    end

    local val = SafeCall(Config.ReadInt, CONFIG_SECTION, AllyConfigKey(cleanName), 1)
    local enabled = val ~= 0
    State.allyEnabled[cleanName] = enabled
    return enabled
end

local function SetAllySaveEnabled(cleanName, enabled)
    if cleanName == "" then
        return
    end
    State.allyEnabled[cleanName] = enabled == true
    SafeCall(Config.WriteInt, CONFIG_SECTION, AllyConfigKey(cleanName), enabled and 1 or 0)
end

--#endregion

--#region Theme

local function ReadThemeMember(value, key)
    local ok, result = pcall(function()
        return value[key]
    end)
    if ok then
        return result
    end
    return nil
end

local function ClampThemeByte(value, fallback)
    if type(value) ~= "number" then
        return fallback or 0
    end
    if value >= 0 and value <= 1 then
        value = value * 255
    end
    if value < 0 then
        return 0
    end
    if value > 255 then
        return 255
    end
    return math.floor(value + 0.5)
end

local function NormalizeThemeColor(c)
    if not c then
        return nil
    end

    local valueType = type(c)
    if valueType ~= "table" and valueType ~= "userdata" then
        return nil
    end

    local function channel(keys, fallback)
        for _, key in ipairs(keys) do
            local raw = ReadThemeMember(c, key)
            if type(raw) == "number" then
                return raw
            end
            if type(raw) == "function" then
                local ok, result = pcall(raw, c)
                if ok and type(result) == "number" then
                    return result
                end
            end
        end
        return fallback
    end

    local r = channel({"r", "R", "red", "Red", "GetR", "GetRed", 1}, nil)
    local g = channel({"g", "G", "green", "Green", "GetG", "GetGreen", 2}, nil)
    local b = channel({"b", "B", "blue", "Blue", "GetB", "GetBlue", 3}, nil)
    local a = channel({"a", "A", "alpha", "Alpha", "GetA", "GetAlpha", 4}, 255)

    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end

    return Color(
        ClampThemeByte(r, 0),
        ClampThemeByte(g, 0),
        ClampThemeByte(b, 0),
        ClampThemeByte(a, 255))
end

local function TryGetThemeColor(name)
    if not Menu or not Menu.Style or not name then
        return nil
    end

    local col = SafeCall(Menu.Style, name)
    local normalized = NormalizeThemeColor(col)
    if normalized then
        return normalized
    end

    local tbl = SafeCall(Menu.Style)
    if type(tbl) == "table" then
        return NormalizeThemeColor(tbl[name])
    end

    return nil
end

local function TryGetThemeColorAny(names)
    for _, name in ipairs(names) do
        local color = TryGetThemeColor(name)
        if color then
            return color
        end
    end
    return nil
end

local function PickAccentBorderColor()
    local enabledSwitchBg = TryGetThemeColor("enabled_switch_background")
    local comboItemActive = TryGetThemeColor("combo_item_active")
    local primary = TryGetThemeColor("primary")
    local indicationActive = TryGetThemeColor("indication_active")

    local borderSource = enabledSwitchBg or comboItemActive or primary or indicationActive
    if not borderSource then
        return nil
    end

    local candidates = {borderSource}
    if comboItemActive and comboItemActive ~= borderSource then
        candidates[#candidates + 1] = comboItemActive
    end
    if primary and primary ~= borderSource then
        candidates[#candidates + 1] = primary
    end
    if indicationActive and indicationActive ~= borderSource then
        candidates[#candidates + 1] = indicationActive
    end

    local best = borderSource
    local bestScore = (best.r or 0) + (best.g or 0) + (best.b or 0)
    local bestAlpha = best.a
    if bestAlpha == nil then
        bestAlpha = 255
    end

    for i = 2, #candidates do
        local candidate = candidates[i]
        local alpha = candidate.a
        if alpha == nil then
            alpha = 255
        end
        if alpha > 0 then
            local score = (candidate.r or 0) + (candidate.g or 0) + (candidate.b or 0)
            if score > bestScore then
                best = candidate
                bestScore = score
                bestAlpha = alpha
            end
        end
    end

    return Color(best.r, best.g, best.b, bestAlpha)
end

local function SyncColors()
    if not Menu or not Menu.Style then
        return
    end

    local headerBg = TryGetThemeColorAny({
        "additional_background",
        "popup_background",
        "background",
    })
    if headerBg then
        Colors.HeaderBg = headerBg
    end

    local textHeader = TryGetThemeColor("primary_widgets_text")
    if textHeader then
        Colors.TextHeader = textHeader
    end

    local borderSource = PickAccentBorderColor()
    if borderSource then
        Colors.BorderEnabled = borderSource
    end
end

SyncColors()

--#endregion

--#region Menu

local function InitializeUI()
    local mainSection = Menu.Find("Heroes", "Hero List", "Tusk", "Main Settings")
    local group

    if mainSection and mainSection.Create then
        group = mainSection:Create("Auto Save")
    end

    if not group then
        group = Menu.Create("Scripts", "Support", "Tusk Auto Save", "Main", "Auto Save")
    end

    if not group then
        error(LOG_PREFIX .. "Failed to create menu group")
    end

    local screenSize = SafeCall(Render.ScreenSize) or Vec2(3840, 2160)
    local maxX = math.max(800, math.floor(screenSize.x))
    local maxY = math.max(600, math.floor(screenSize.y))

    local ui = {}

    ui.Enabled = group:Switch(L("Enable", "Включить"), false, Icons.enable)
    WithTooltip(ui.Enabled, L(
        "Auto-save allies on Versus threats: Snowball enemy, then pick up ally.",
        "Автосейв союзников по Versus-угрозам: Snowball на врага, затем подбор союзника."))

    LoadVersusPrefs()
    ui.Versus = group:MultiSelect(
        L("Use VS", "Use VS"),
        BuildVersusMultiSelectItems(nil),
        false
    )
    ApplyVersusPrefsToWidget(ui.Versus)
    if ui.Versus.SetCallback then
        ui.Versus:SetCallback(SyncVersusPrefsFromWidget, false)
    end
    MenuIcon(ui.Versus, Icons.versus)
    WithTooltip(ui.Versus, L(
        "Before a match shows all dangerous abilities. In game filters to enemy heroes + dangerous items.",
        "До матча показывает все опасные способности. В игре фильтрует под героев врага + опасные предметы."))

    local gear = ui.Enabled:Gear(L("Auto Save Settings", "Настройки Auto Save"), Icons.gear)

    ui.ManaThreshold = gear:Slider(L("Min Mana %", "Мин. MP %"), 0, 100, 20, "%d%%")
    MenuIcon(ui.ManaThreshold, Icons.flask)
    WithTooltip(ui.ManaThreshold, L(
        "Do not cast saves while your mana is below this percentage.",
        "Не использовать сейв, пока ваша мана ниже этого процента."))

    ui.UseBlink = gear:Switch(L("Use Blink for Save", "Использовать Blink для сейва"), true, Icons.blink)
    WithTooltip(ui.UseBlink, L(
        "Blink into Snowball range when ally is out of range. Avoids blinking into Chronosphere.",
        "Блинк в радиус Snowball, если союзник далеко. Не блинкает внутрь Chronosphere."))

    ui.DrawPanel = gear:Switch(L("Draw Ally Panel", "Показывать панель союзников"), true, Icons.panel)
    WithTooltip(ui.DrawPanel, L(
        "HUD panel to choose allies and drag the header to reposition.",
        "HUD-панель выбора союзников. Перетаскивайте заголовок для перемещения."))

    ui.Debug = gear:Switch(L("Debug logs", "Debug логи"), false)
    MenuIcon(ui.Debug, Icons.bug)
    WithTooltip(ui.Debug, L(
        "Write save decisions to the Umbrella log.",
        "Писать решения по сейву в лог Umbrella."))

    ui.PanelX = gear:Slider("HUD X", 0, maxX, math.min(200, maxX))
    ui.PanelY = gear:Slider("HUD Y", 0, maxY, math.min(200, maxY))
    SafeCall(ui.PanelX.Visible, ui.PanelX, false)
    SafeCall(ui.PanelY.Visible, ui.PanelY, false)

    local gearWidgets = {
        ui.ManaThreshold,
        ui.UseBlink,
        ui.DrawPanel,
        ui.Debug,
    }

    local mainWidgets = {
        ui.Versus,
    }

    local function UpdateControls()
        local enabled = ui.Enabled:Get()
        for _, widget in ipairs(mainWidgets) do
            if widget and widget.Disabled then
                widget:Disabled(not enabled)
            end
        end
        for _, widget in ipairs(gearWidgets) do
            if widget and widget.Disabled then
                widget:Disabled(not enabled)
            end
        end
    end

    ui.Enabled:SetCallback(UpdateControls, true)

    return ui
end

UI = InitializeUI()

local function SavePanelPosition()
    local x = math.floor(PanelConfig.X + 0.5)
    local y = math.floor(PanelConfig.Y + 0.5)
    SafeCall(Config.WriteInt, CONFIG_SECTION, "panel_x", x)
    SafeCall(Config.WriteInt, CONFIG_SECTION, "panel_y", y)

    if UI.PanelX and UI.PanelY then
        SafeCall(UI.PanelX.Set, UI.PanelX, x)
        SafeCall(UI.PanelY.Set, UI.PanelY, y)
    end
end

local function LoadPanelPosition()
    local needsSave = false
    local x = SafeCall(Config.ReadInt, CONFIG_SECTION, "panel_x", -1)
    local y = SafeCall(Config.ReadInt, CONFIG_SECTION, "panel_y", -1)

    if type(x) ~= "number" or x < 0 then
        x = (UI.PanelX and UI.PanelX.Get and UI.PanelX:Get()) or PanelConfig.X
        needsSave = true
    end
    if type(y) ~= "number" or y < 0 then
        y = (UI.PanelY and UI.PanelY.Get and UI.PanelY:Get()) or PanelConfig.Y
        needsSave = true
    end

    PanelConfig.X = x
    PanelConfig.Y = y

    if UI.PanelX and UI.PanelY then
        SafeCall(UI.PanelX.Set, UI.PanelX, math.floor(x + 0.5))
        SafeCall(UI.PanelY.Set, UI.PanelY, math.floor(y + 0.5))
    end

    if needsSave then
        SavePanelPosition()
    end
end

LoadPanelPosition()

--#endregion

--#region Panel

local function GetMousePos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok then
            if type(x) == "number" and type(y) == "number" then
                return x, y
            end
            if (type(x) == "table" or type(x) == "userdata") and x.x and x.y then
                return x.x, x.y
            end
        end

        ok, x, y = pcall(function()
            return Input:GetCursorPos()
        end)
        if ok and type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    if Render and Render.GetCursorPos then
        local ok, posOrX, y = pcall(Render.GetCursorPos)
        if ok then
            if type(posOrX) == "number" and type(y) == "number" then
                return posOrX, y
            end
            if (type(posOrX) == "table" or type(posOrX) == "userdata") and posOrX.x and posOrX.y then
                return posOrX.x, posOrX.y
            end
        end
    end

    return nil, nil
end

local function IsLmbDown()
    return SafeCall(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1) == true
end

local function GetHeroIcon(heroName)
    if not heroName or heroName == "" then
        return nil
    end
    if State.imgCache == nil then
        State.imgCache = {}
    end
    if State.imgCache[heroName] then
        return State.imgCache[heroName]
    end
    local handle = SafeCall(Render.LoadImage, HeroIconPath(heroName))
    if handle then
        State.imgCache[heroName] = handle
    end
    return handle
end

local function GetPanelFont()
    if not CanMeasureWithFont(fontPanel, PANEL_TITLE_TEXT) then
        fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_TEXT) or 0
    end
    if CanMeasureWithFont(fontPanel, PANEL_TITLE_TEXT) then
        return fontPanel
    end
    return 0
end

local function MeasurePanelTextSize(fontSize, text)
    local font = GetPanelFont()
    local fallback = Vec2(text:len() * fontSize * 0.55, fontSize)
    if font == 0 or not Render or not Render.TextSize then
        return fallback
    end
    local size = SafeCall(Render.TextSize, font, fontSize, text)
    if IsValidTextSize(size) then
        return size
    end
    return fallback
end

local function DrawPanelText(size, text, pos, color)
    local font = GetPanelFont()
    if not IsValidFontHandle(font) then
        fontPanel = ResolvePanelHeaderFont(text) or 0
        font = fontPanel
    end
    if not IsValidFontHandle(font) or not Render or not Render.Text then
        return false
    end

    local shadow = Color(0, 0, 0, 140)
    pcall(Render.Text, font, size, text, Vec2(pos.x + 1, pos.y + 1), shadow)
    if pcall(Render.Text, font, size, text, pos, color) then
        return true
    end

    fontPanel = ResolvePanelHeaderFont(text) or 0
    if IsValidFontHandle(fontPanel)
        and pcall(Render.Text, fontPanel, size, text, pos, color) then
        return true
    end
    return false
end

local function GetPanelLayout(scale, numAllies, screenSize)
    local cellW = 44 * scale
    local cellH = 26 * scale
    local cellSpacing = 6 * scale
    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local padY = 6 * scale
    local titleText = PANEL_TITLE_TEXT
    local titleFontSize = PANEL_HEADER_TEXT_SIZE * scale
    local hasTitleIcon = IsPanelHeaderFaIconAvailable()
    local titleSize = MeasurePanelTextSize(titleFontSize, titleText) or Vec2(titleText:len() * titleFontSize * 0.55, titleFontSize)
    local titleSizeX = titleSize.x or 0
    local titleSizeY = titleSize.y or titleFontSize
    local titleIconSize = hasTitleIcon and MeasurePanelHeaderFaIconSize(scale) or Vec2(0, titleSizeY)
    local titleIconW = titleIconSize.x or 0
    local titleIconGap = hasTitleIcon and (PANEL_HEADER_ICON_GAP * scale) or 0
    local titleContentW = titleIconW + titleIconGap + titleSizeX
    local cellsTotalW = numAllies * cellW + math.max(0, numAllies - 1) * cellSpacing
    local headerW = padX + titleContentW + padX
    local heroesW = padX + cellsTotalW + padX
    local width = math.max(headerW, heroesW, 110 * scale)
    local height = titleH + padY + cellH + padY

    local x = math.max(0, math.min(screenSize.x - width, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - height, PanelConfig.Y))

    return {
        cellW = cellW,
        cellH = cellH,
        cellSpacing = cellSpacing,
        titleH = titleH,
        padX = padX,
        titleText = titleText,
        titleIconSize = titleIconSize,
        titleIconGap = titleIconGap,
        titleSize = titleSize,
        titleFontSize = titleFontSize,
        hasTitleIcon = hasTitleIcon,
        width = width,
        height = height,
        x = x,
        y = y,
        rowY = y + titleH + padY,
        cellsStartX = x + padX,
    }
end

local function SyncAllyTargets(myHero, now)
    if not myHero then
        return
    end
    if now - State.lastAllySyncTime < ALLY_SYNC_INTERVAL then
        return
    end
    State.lastAllySyncTime = now

    local entities = {}

    for _, hero in ipairs(SafeCall(Heroes.GetAll) or {}) do
        if IsValidAlly(myHero, hero) then
            local unitName = SafeCall(NPC.GetUnitName, hero)
            local cleanName = CleanHeroName(unitName)
            if cleanName ~= "" then
                if not State.matchAllySet[cleanName] then
                    State.matchAllySet[cleanName] = true
                    State.matchAllyNames[#State.matchAllyNames + 1] = cleanName
                end
                if unitName and unitName ~= "" then
                    State.cachedAllyUnitNames[cleanName] = unitName
                end
                entities[cleanName] = hero
                if State.allyEnabled[cleanName] == nil then
                    IsAllySaveEnabled(cleanName)
                end
            end
        end
    end

    table.sort(State.matchAllyNames)
    State.cachedAllyEntities = entities
end

function Script.OnDraw()
    if not Engine.IsInGame() or not UI.Enabled:Get() or not UI.DrawPanel:Get() then
        return
    end
    SyncColors()
    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local myHero = Heroes.GetLocal()
    if not IsLocalTusk(myHero) then
        return
    end

    local numAllies = #State.matchAllyNames
    if numAllies == 0 then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, numAllies, screenSize)
    local mx, my = GetMousePos()
    local isDown = IsLmbDown()
    local isClicked = isDown and not State.wasMousePressed
    local isCursorValid = mx and my

    local isOverHeader = isCursorValid
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.titleH

    if isClicked and isOverHeader then
        PanelDrag.IsDragging = true
        PanelDrag.OffsetX = mx - layout.x
        PanelDrag.OffsetY = my - layout.y
    elseif not isDown then
        if PanelDrag.IsDragging then
            SavePanelPosition()
        end
        PanelDrag.IsDragging = false
    end

    if PanelDrag.IsDragging and mx and my then
        PanelConfig.X = math.max(0, math.min(screenSize.x - layout.width, mx - PanelDrag.OffsetX))
        PanelConfig.Y = math.max(0, math.min(screenSize.y - layout.height, my - PanelDrag.OffsetY))
        layout = GetPanelLayout(scale, numAllies, screenSize)
    end

    local clickTriggered = isClicked
    if clickTriggered and Input.IsInputCaptured and SafeCall(Input.IsInputCaptured) then
        clickTriggered = false
    end
    State.wasMousePressed = isDown

    local titleText = layout.titleText or PANEL_TITLE_TEXT
    local titleFontSize = layout.titleFontSize or (PANEL_HEADER_TEXT_SIZE * scale)
    local titleSize = layout.titleSize
        or MeasurePanelTextSize(titleFontSize, titleText)
        or Vec2(titleText:len() * titleFontSize * 0.55, titleFontSize)
    local titleSizeY = titleSize.y or titleFontSize
    local titleIconSize = layout.titleIconSize or Vec2(0, titleSizeY)
    local titleIconGap = layout.titleIconGap or 0
    local titleIconH = titleIconSize.y or math.floor(PANEL_HEADER_ICON_SIZE * scale + 0.5)
    local titleContentH = math.max(titleSizeY, layout.hasTitleIcon and titleIconH or 0)
    local titleContentY = layout.y + math.floor((layout.titleH - titleContentH) * 0.5 + 0.5)
    local textX = layout.x + layout.padX
    local textY = titleContentY + math.floor((titleContentH - titleSizeY) * 0.5 + 0.5)

    DrawPanelBlur(layout, scale)

    Render.FilledRect(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        Colors.HeaderBg,
        PANEL_HEADER_RADIUS * scale)

    if layout.hasTitleIcon then
        textX = DrawPanelHeaderIcon(
            textX,
            titleContentY,
            titleContentH,
            titleIconSize,
            titleIconGap,
            scale,
            Colors.TextHeader)
    end

    DrawPanelText(
        titleFontSize,
        titleText,
        Vec2(textX, textY),
        Colors.TextHeader)

    for i, cleanName in ipairs(State.matchAllyNames) do
        local cellX = layout.cellsStartX + (i - 1) * (layout.cellW + layout.cellSpacing)
        local allyHero = State.cachedAllyEntities[cleanName]
        local enabled = IsAllySaveEnabled(cleanName)

        local imgAlpha = enabled and 255 or 110
        local grayscale = enabled and 0.0 or 1.0
        local borderColor = enabled
            and Color(Colors.BorderEnabled.r, Colors.BorderEnabled.g, Colors.BorderEnabled.b, 255)
            or Color(Colors.BorderEnabled.r, Colors.BorderEnabled.g, Colors.BorderEnabled.b, 110)

        local isCellHovered = isCursorValid
            and mx >= cellX and mx <= cellX + layout.cellW
            and my >= layout.rowY and my <= layout.rowY + layout.cellH

        local heroNameRaw = State.cachedAllyUnitNames[cleanName]
            or (allyHero and SafeCall(NPC.GetUnitName, allyHero))
            or ""
        local imgHandle = GetHeroIcon(heroNameRaw)

        Render.FilledRect(
            Vec2(cellX, layout.rowY),
            Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
            Colors.CellBg,
            5 * scale)

        if imgHandle then
            Render.Image(
                imgHandle,
                Vec2(cellX, layout.rowY),
                Vec2(layout.cellW, layout.cellH),
                Color(255, 255, 255, imgAlpha),
                5 * scale,
                Enum.DrawFlags.None,
                Vec2(0, 0),
                Vec2(1, 1),
                grayscale)
        end

        if enabled then
            Render.Rect(
                Vec2(cellX, layout.rowY),
                Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
                borderColor,
                5 * scale,
                Enum.DrawFlags.None,
                1.0)
        end

        if isCellHovered and clickTriggered and not PanelDrag.IsDragging then
            SetAllySaveEnabled(cleanName, not enabled)
        end
    end
end

function Script.OnKeyEvent(_data, key, _event)
    if not Engine.IsInGame() or not UI.Enabled:Get() or not UI.DrawPanel:Get() then
        return
    end
    if Menu and Menu.VisualsIsEnabled and not SafeCall(Menu.VisualsIsEnabled) then
        return
    end

    local myHero = Heroes.GetLocal()
    if not IsLocalTusk(myHero) then
        return
    end

    if #State.matchAllyNames == 0 then
        return
    end

    local scale = (SafeCall(Menu.Scale) or 100) / 100
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, #State.matchAllyNames, screenSize)
    local mx, my = GetMousePos()
    local isCursorOverPanel = mx and my
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.height

    if isCursorOverPanel or PanelDrag.IsDragging then
        if key == Enum.ButtonCode.KEY_MOUSE1
            or key == Enum.ButtonCode.KEY_MOUSE2
            or key == Enum.ButtonCode.KEY_MOUSE3
            or key == Enum.ButtonCode.KEY_MWHEELUP
            or key == Enum.ButtonCode.KEY_MWHEELDOWN then
            return false
        end
    end
end

--#endregion

--#region Save Handlers

local function GetAllySaveReason(ctx, ally)
    local preemptId, preemptScore, preemptEnemy = GetPreemptiveCastThreat(ctx, ally)
    if preemptId then
        return "versus:" .. preemptId .. ":cast", preemptScore, preemptEnemy
    end

    local threatId, threatScore = GetAllyVersusThreat(ally)
    if threatId then
        local sourceEnemy = GetAllyThreatSourceEnemy(ally, threatId)
        return "versus:" .. threatId, threatScore or 0, sourceEnemy
    end

    return nil
end

local SaveHandlers = {
    {
        name = "item_blink",
        tag = "blink_snowball",
        priority = 1,
        CanSave = function(ctx, ally, reason, preferredEnemy)
            if State.snowballAfterBlink or State.activeSnowballSave then
                return false
            end
            return CanBlinkForSnowballSave(ctx, ally, reason)
        end,
        TrySave = function(ctx, ally, reason, preferredEnemy)
            local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
            local gatherRange = GetSnowballGatherRadius(ctx.abilities.snowball)
            local blinkPos = allyPos
                and ComputeSaveBlinkPos(ctx.origin, allyPos, gatherRange, ctx.blinkRange, ally)
            if not blinkPos or not CastBlinkToPosition(ctx.me, ctx.items.blink, blinkPos) then
                return false
            end

            State.snowballAfterBlink = {
                ally = ally,
                reason = reason,
                preferredEnemy = preferredEnemy,
                readyAfter = ctx.now + GetBlinkAfterDelay(reason),
                expireTime = ctx.now + SNOWBALL_AFTER_BLINK_TIME,
            }

            local hazard = GetAllySaveHazard(ally)
            if hazard then
                LogDebug(string.format(
                    "save cast: blink outside %s toward %s",
                    hazard.label or "hazard",
                    GetHeroDisplayName(ally)
                ))
            else
                LogDebug("save cast: blink toward " .. GetHeroDisplayName(ally))
            end
            return true
        end,
    },
    {
        name = SNOWBALL_NAME,
        tag = "snowball",
        priority = 2,
        CanSave = function(ctx, ally, reason, preferredEnemy)
            if State.snowballAfterBlink or State.activeSnowballSave then
                return false
            end
            if not IsVersusReason(reason) then
                return false
            end
            if CanBlinkForSnowballSave(ctx, ally, reason) then
                return false
            end
            if not CanPickupWithoutBlink(ctx, ally, reason) then
                return false
            end
            return CanStartSnowballSave(ctx, ally, preferredEnemy)
        end,
        TrySave = function(ctx, ally, reason, preferredEnemy)
            return StartSnowballSave(ctx, ally, reason, preferredEnemy)
        end,
    },
}

table.sort(SaveHandlers, function(a, b)
    return (a.priority or 99) < (b.priority or 99)
end)

--#endregion

--#region Context & Allies

local function BuildContext(me, now)
    local origin = SafeCall(Entity.GetAbsOrigin, me)
    if not origin then
        return nil
    end

    local mana = SafeCall(NPC.GetMana, me) or 0
    local maxMana = SafeCall(NPC.GetMaxMana, me) or 1
    local snowball = SafeCall(NPC.GetAbility, me, SNOWBALL_NAME)
    local blink = GetBlink(me)
    local snowballRange = GetSnowballCastRange(me, snowball)
    local blinkRange = GetItemCastRange(me, blink, 1200)
    local scanRange = math.max(
        snowballRange,
        DEFAULT_SNOWBALL_RANGE,
        blinkRange + snowballRange
    )

    return {
        me = me,
        mana = mana,
        manaPct = GetManaPct(mana, maxMana),
        now = now,
        origin = origin,
        settings = {
            manaThreshold = UI.ManaThreshold and UI.ManaThreshold:Get() or 20,
        },
        abilities = {
            snowball = snowball,
        },
        items = {
            blink = blink,
        },
        snowballRange = snowballRange,
        blinkRange = blinkRange,
        scanRange = scanRange,
    }
end

local function ScanAllies(ctx)
    if ctx.now - State.lastAllyScanTime < ALLY_SCAN_INTERVAL then
        return State.cachedAllies
    end

    State.lastAllyScanTime = ctx.now
    State.cachedAllies = {}

    local teamNum = SafeCall(Entity.GetTeamNum, ctx.me)
    local range = ctx.scanRange or DEFAULT_SNOWBALL_RANGE
    local allies = SafeCall(Heroes.InRadius, ctx.origin, range, teamNum, Enum.TeamType.TEAM_FRIEND, true, true)

    if not allies or #allies == 0 then
        allies = SafeCall(Heroes.GetAll) or {}
    end

    for _, ally in ipairs(allies) do
        if IsValidAlly(ctx.me, ally) then
            local cleanName = CleanHeroName(SafeCall(NPC.GetUnitName, ally))
            if cleanName ~= "" and IsAllySaveEnabled(cleanName) then
                local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
                if allyPos and Dist2D(ctx.origin, allyPos) <= range then
                    State.cachedAllies[#State.cachedAllies + 1] = ally
                end
            end
        end
    end

    return State.cachedAllies
end

local function PickSaveTarget(ctx, allies)
    local bestAlly = nil
    local bestScore = math.huge
    local bestReason = nil
    local bestPreferredEnemy = nil
    local bestHp = 1

    for _, ally in ipairs(allies) do
        local cleanName = CleanHeroName(SafeCall(NPC.GetUnitName, ally))
        if cleanName ~= "" and IsAllySaveEnabled(cleanName) then
            local reason, score, preferredEnemy = GetAllySaveReason(ctx, ally)
            if reason and type(score) == "number" and score < bestScore then
                bestScore = score
                bestAlly = ally
                bestReason = reason
                bestPreferredEnemy = preferredEnemy
                bestHp = GetHealthPct(ally)
            end
        end
    end

    return bestAlly, bestHp, bestReason, bestPreferredEnemy
end

local function LogSaveTarget(ctx, ally, hpPct, reason, preferredEnemy)
    if ctx.now < State.saveQuietUntil then
        return
    end
    if ctx.now - State.lastDebugLogTime < DEBUG_LOG_INTERVAL then
        return
    end
    State.lastDebugLogTime = ctx.now

    LogDebug(string.format(
        "save target: %s reason=%s hp=%.0f%% snowballRange=%.0f%s",
        GetHeroDisplayName(ally),
        reason or "unknown",
        hpPct * 100,
        ctx.snowballRange or DEFAULT_SNOWBALL_RANGE,
        preferredEnemy and (" preferredEnemy=" .. GetUnitDisplayName(preferredEnemy)) or ""
    ))
end

local function TryExecuteSave(ctx, ally, reason, preferredEnemy)
    for _, handler in ipairs(SaveHandlers) do
        if handler.CanSave(ctx, ally, reason, preferredEnemy) then
            local ok = handler.TrySave(ctx, ally, reason, preferredEnemy)
            if ok then
                return true
            end
        end
    end
    return false
end

local function TryAutoSave(ctx)
    if ctx.now < State.saveQuietUntil then
        return
    end
    if State.activeSnowballSave then
        return
    end

    local manaThresholdPct = (ctx.settings.manaThreshold or 20) / 100
    if ctx.manaPct < manaThresholdPct then
        return
    end

    local allies = ScanAllies(ctx)
    local ally, hpPct, reason, preferredEnemy = PickSaveTarget(ctx, allies)
    if not ally or not reason then
        return
    end

    LogSaveTarget(ctx, ally, hpPct, reason, preferredEnemy)

    if TryExecuteSave(ctx, ally, reason, preferredEnemy) then
        return
    end
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    LoadPanelPosition()
    LoadVersusPrefs()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_TEXT) or 0
    State.lastAllySyncTime = -100
    State.lastVersusRosterKey = ""
    State.lastVersusSyncTime = -100
    State.panelHeaderFaFont = nil
    State.panelHeaderFaAvailable = nil

    if Engine.IsInGame() then
        local me = Heroes.GetLocal()
        if IsLocalTusk(me) then
            local now = GlobalVars.GetCurTime() or 0
            RefreshVersusMultiSelect(me, true)
            SyncAllyTargets(me, now)
        end
    end

    Log("info", "loaded")
end

function Script.OnGameEnd()
    SyncVersusPrefsFromWidget()
    ShowAllVersusThreats(true)
    ClearPendingSnowball()
    ClearActiveSnowballSave()
    State.saveQuietUntil = -100
    State.lastAllySyncTime = -100
    State.lastVersusRosterKey = ""
    State.lastVersusSyncTime = -100
    State.wasMousePressed = false
    PanelDrag.IsDragging = false
    State.matchAllyNames = {}
    State.matchAllySet = {}
    State.cachedAllyEntities = {}
    State.cachedAllyUnitNames = {}
end

function Script.OnThemeUpdate()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_TEXT) or 0
end

function Script.OnUpdate()
    SyncColors()

    if not Engine.IsInGame() then
        return
    end

    local me = Heroes.GetLocal()
    if IsLocalTusk(me) then
        local now = GlobalVars.GetCurTime() or 0
        SyncVersusThreats(me, now)
        SyncAllyTargets(me, now)
    end

    if not UI.Enabled:Get() then
        return
    end

    if not me or not IsLocalTusk(me) then
        return
    end

    local now = GlobalVars.GetCurTime() or 0

    if Input.IsInputCaptured and SafeCall(Input.IsInputCaptured) then
        return
    end

    local ctx = BuildContext(me, now)
    if not ctx then
        return
    end

    if ProcessActiveSnowballSave(ctx) then
        return
    end

    if ProcessPendingSnowball(ctx) then
        return
    end

    if not CanAct(me) then
        return
    end

    TryAutoSave(ctx)
end

end)()

--#endregion

return Script
