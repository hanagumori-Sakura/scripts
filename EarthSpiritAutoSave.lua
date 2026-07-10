--[[
    Earth Spirit Auto Save
    Versus saves: Geomagnetic Grip, or Aghs Petrify (Blink if out of range).
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local LOG_PREFIX = "[EarthSpiritAutoSave] "
local HERO_NAME = "npc_dota_hero_earth_spirit"
local CAST_ID = "earth_spirit.auto_save"
local GRIP_NAME = "earth_spirit_geomagnetic_grip"
local PETRIFY_NAME = "earth_spirit_petrify"
local CONFIG_SECTION = "earth_spirit_auto_save"

local ALLY_SCAN_INTERVAL = 0.15
local ALLY_SYNC_INTERVAL = 0.5
local ENEMY_ROSTER_SYNC_INTERVAL = 1.0
local DEBUG_LOG_INTERVAL = 1.0
local LANG_CACHE_INTERVAL = 1.0
local DEFAULT_GRIP_RANGE = 700
local DEFAULT_PETRIFY_RANGE = 500
local BLINK_SAVE_MARGIN = 50
local BLINK_AFTER_DELAY = 0.35
local PETRIFY_AFTER_BLINK_TIME = 1.5
local SAVE_TARGET_SILENCE = 2.0
local VERSUS_CONFIG_PREFIX = "versus_"
local CHRONO_FREEZE_MOD = "modifier_faceless_void_chronosphere_freeze"
local CHRONO_DEFAULT_RADIUS = 500
local CHRONO_SAFE_MARGIN = 75
local BLACK_HOLE_DEFAULT_RADIUS = 420
local MARS_ARENA_DEFAULT_RADIUS = 550
local DUEL_DEFAULT_RADIUS = 300
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
local PANEL_HEADER_ICON_SIZE = 13
local PANEL_HEADER_ICON_GAP = 5
local PANEL_HEADER_RADIUS = 5
local PANEL_CELL_W = 44
local PANEL_CELL_H = 26
local PANEL_CELL_SPACING = 3
local PANEL_BODY_PAD_Y = 5
local PANEL_MIN_WIDTH = 100
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_TITLE_TEXT = "Auto Save"
local PANEL_SIZE_ITEMS = { "50%", "75%", "100%", "125%", "150%" }
local PANEL_SIZE_SCALES = { 0.50, 0.75, 1.00, 1.25, 1.50 }
local PANEL_SIZE_DEFAULT_INDEX = 2

-- Ally debuffs that mark a circular no-blink zone (stay outside while saving).
local SAVE_HAZARD_MODIFIERS = {
    {
        allyMod = CHRONO_FREEZE_MOD,
        defaultRadius = CHRONO_DEFAULT_RADIUS,
        margin = CHRONO_SAFE_MARGIN,
        label = "chronosphere",
    },
    {
        allyMod = "modifier_enigma_black_hole_pull",
        defaultRadius = BLACK_HOLE_DEFAULT_RADIUS,
        margin = CHRONO_SAFE_MARGIN,
        label = "black_hole",
    },
    {
        allyMod = "modifier_mars_arena_of_blood_leash",
        defaultRadius = MARS_ARENA_DEFAULT_RADIUS,
        margin = CHRONO_SAFE_MARGIN,
        label = "arena_of_blood",
    },
    {
        allyMod = "modifier_legion_commander_duel",
        defaultRadius = DUEL_DEFAULT_RADIUS,
        margin = 50,
        label = "duel",
    },
}

local O_CAST_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local ORDER_ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

-- Grip cannot pull allies inside these — fall back to Aghs Petrify.
local GRIP_BLOCKED_ALLY_MODIFIERS = {
    "modifier_legion_commander_duel",
    "modifier_faceless_void_chronosphere_freeze",
    "modifier_winter_wyvern_winters_curse",
}

local ALLY_PETRIFY_MODIFIERS = {
    "modifier_earthspirit_petrify",
}

local CAN_ACT_BLOCKED_STATES = {
    Enum.ModifierState.MODIFIER_STATE_ROOTED,
    Enum.ModifierState.MODIFIER_STATE_HEXED,
    Enum.ModifierState.MODIFIER_STATE_MUTED,
    Enum.ModifierState.MODIFIER_STATE_DISARMED,
    Enum.ModifierState.MODIFIER_STATE_TAUNTED,
    Enum.ModifierState.MODIFIER_STATE_COMMAND_RESTRICTED,
    Enum.ModifierState.MODIFIER_STATE_FEARED,
}

local Icons = {
    enable = "\u{f00c}", -- check
    gear   = "\u{f013}", -- settings
    mana   = "\u{f043}", -- droplet / mana threshold
    blink  = "panorama/images/items/blink_png.vtex_c",
    sparkles = "\u{f890}", -- abilities row
    panel       = "\u{f108}", -- hud panel
    panelHeader = "\u{e1ac}", -- hud panel header
    bug         = "\u{f188}", -- debug
    versus = "\u{f71d}", -- versus / threat picker
}

local SPELL_ICONS = {
    earth_spirit_geomagnetic_grip = "panorama/images/spellicons/earth_spirit_geomagnetic_grip_png.vtex_c",
    earth_spirit_petrify          = "panorama/images/spellicons/earth_spirit_petrify_png.vtex_c",
}

local SAVE_ABILITY_ORDER = {
    "earth_spirit_geomagnetic_grip",
    "earth_spirit_petrify",
}

local SAVE_ABILITY_DEFAULTS = {
    earth_spirit_geomagnetic_grip = true,
    earth_spirit_petrify = true,
}

-- Ability/item id -> debuff modifiers on the ally (Umbrella Versus-style grid).
local VERSUS_THREATS = {
    -- Teamfight ultimates
    { id = "tidehunter_ravage", mods = { "modifier_tidehunter_ravage" }, default = true },
    { id = "enigma_black_hole", mods = { "modifier_enigma_black_hole_pull" }, default = true },
    { id = "faceless_void_chronosphere", mods = { "modifier_faceless_void_chronosphere_freeze" }, default = true },
    { id = "magnataur_reverse_polarity", mods = { "modifier_magnataur_reverse_polarity" }, default = true },
    { id = "axe_berserkers_call", mods = { "modifier_axe_berserkers_call" }, default = true },
    { id = "legion_commander_duel", mods = { "modifier_legion_commander_duel" }, default = true },
    { id = "winter_wyvern_winters_curse", mods = { "modifier_winter_wyvern_winters_curse" }, default = true },
    { id = "earthshaker_echo_slam", mods = {}, default = true },
    { id = "earthshaker_fissure", mods = { "modifier_earthshaker_fissure_stun" }, default = false },

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
    { id = "rattletrap_power_cogs", mods = { "modifier_rattletrap_cog_push" }, default = false },
    { id = "juggernaut_omni_slash", mods = { "modifier_juggernaut_omnislash" }, default = true },
    { id = "huskar_life_break", mods = {
        "modifier_huskar_life_break_slow",
        "modifier_huskar_life_break_charge",
    }, default = true },
    { id = "life_stealer_infest", mods = {
        "modifier_life_stealer_infest",
        "modifier_life_stealer_infest_effect",
    }, default = false },
    { id = "dark_seer_vacuum", mods = { "modifier_dark_seer_vacuum" }, default = true },
    { id = "magnataur_skewer", mods = {
        "modifier_magnataur_skewer_movement",
        "modifier_magnataur_skewer_impact",
        "modifier_magnataur_skewer_slow",
    }, default = true },
    { id = "night_stalker_crippling_fear", mods = { "modifier_night_stalker_crippling_fear" }, default = true },
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
    { id = "snapfire_firesnap_cookie", mods = { "modifier_snapfire_firesnap_cookie_stun" }, default = true },
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
    { id = "chaos_knight_chaos_bolt", mods = { "modifier_chaos_knight_chaos_bolt" }, default = false },
    { id = "centaur_hoof_stomp", mods = { "modifier_centaur_hoof_stomp" }, default = true },
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
    cachedAllyNames = {},
    cachedAllyEntities = {},
    allyEnabled = {},
    lastDebugLogTime = -100,
    saveQuietUntil = -100,
    wasMousePressed = false,
    petrifyAfterBlink = nil,
    gripSavedAllies = {},
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
}

local LangState = {
    language = "en",
    nextCheck = 0,
}

local fontPanel = 0
local LoggerInstance = Logger and Logger("EarthSpiritAutoSave") or nil

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
        return false
    end

    local x, y
    if type(pos) == "table" or type(pos) == "userdata" then
        x, y = pos.x, pos.y
    end
    if type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    local drawColor = Color(color.r, color.g, color.b, color.a or 255)

    local libRender = GetLibRender()
    if type(libRender) == "table" and type(libRender.text) == "function" then
        if pcall(libRender.text, font, size, glyph, drawColor, x, y) then
            return true
        end
    end

    if Render and Render.Text and pcall(Render.Text, font, size, glyph, Vec2(x, y), drawColor) then
        return true
    end

    return false
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

local function Log(level, message)
    message = tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if pcall(LoggerInstance[level], LoggerInstance, message) then
            return
        end
    end
    print(LOG_PREFIX .. message)
end

local function LogDebug(message)
    if not UI.Debug or not UI.Debug.Get or not UI.Debug:Get() then
        return
    end
    Log("debug", message)
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
    local hp = SafeCall(Entity.GetHealth, unit) or 0
    local maxHp = SafeCall(Entity.GetMaxHealth, unit) or 1
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

local function IsLocalEarthSpirit(hero)
    return hero and SafeCall(NPC.GetUnitName, hero) == HERO_NAME
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

    if SafeCall(NPC.IsStunned, me)
        or SafeCall(NPC.IsSilenced, me)
        or SafeCall(NPC.IsChannellingAbility, me) then
        return false
    end

    for _, state in ipairs(CAN_ACT_BLOCKED_STATES) do
        if SafeCall(NPC.HasState, me, state) then
            return false
        end
    end

    return true
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

local function IsGripBlockedOnAlly(ally)
    for _, modifierName in ipairs(GRIP_BLOCKED_ALLY_MODIFIERS) do
        if SafeCall(NPC.HasModifier, ally, modifierName) then
            return true
        end
    end
    return false
end

local function CastAbilityOnAlly(me, ability, ally, tag)
    local player = SafeCall(Players.GetLocal)
    if not player or not ability or not ally then
        return false
    end

    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    if not allyPos then
        return false
    end

    local orderTag = CAST_ID .. "." .. tag
    if Player and Player.PrepareUnitOrders then
        SafeCall(Player.PrepareUnitOrders,
            player,
            O_CAST_TARGET,
            ally,
            allyPos,
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

    SafeCall(Ability.CastTarget, ability, ally, false, true, true, orderTag)
    return true
end

local function IsVersusReason(reason)
    return reason and reason:sub(1, 7) == "versus:"
end

local function BuildAbilityMultiSelectItems()
    local items = {}
    for _, nameId in ipairs(SAVE_ABILITY_ORDER) do
        items[#items + 1] = {
            nameId,
            SPELL_ICONS[nameId] or "",
            SAVE_ABILITY_DEFAULTS[nameId] == true,
        }
    end
    return items
end

local function IsAbilityEnabled(abilityName)
    local widget = UI.Abilities
    if not widget or not widget.Get then
        return SAVE_ABILITY_DEFAULTS[abilityName] == true
    end
    return widget:Get(abilityName) == true
end

local function GetBlink(me)
    for _, itemName in ipairs(BLINK_ITEMS) do
        local blink = SafeCall(NPC.GetItem, me, itemName, true)
        if blink then
            return blink
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

--#endregion

--#region Blink Validation

local function IsBlinkPositionTraversable(origin, pos)
    if not origin or not pos or not GridNav then
        return true
    end

    if GridNav.IsTraversableFromTo then
        return SafeCall(GridNav.IsTraversableFromTo, origin, pos, false, nil) == true
    end

    if GridNav.IsTraversable then
        return SafeCall(GridNav.IsTraversable, pos, 0x1, 0x002) == true
    end

    return true
end

local function IsBlinkPositionVisible(pos)
    if not pos or not FogOfWar or not FogOfWar.IsPointVisible then
        return true
    end
    return SafeCall(FogOfWar.IsPointVisible, pos) ~= false
end

local function IsBlinkLandingValid(origin, pos)
    if not pos then
        return false
    end
    if not IsBlinkPositionTraversable(origin, pos) then
        return false
    end
    return IsBlinkPositionVisible(pos)
end

--#endregion

--#region Save Position & Hazards

local function IsAllyUnderPetrify(ally)
    for _, modifierName in ipairs(ALLY_PETRIFY_MODIFIERS) do
        if SafeCall(NPC.HasModifier, ally, modifierName) then
            return true
        end
    end
    return false
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
                if IsValidSavePosition(landing, allyPos, castRange, hazard)
                    and IsBlinkLandingValid(origin, landing) then
                    if tryDist < bestDist then
                        bestDist = tryDist
                        bestPos = landing
                    end
                    break
                end
            end
        elseif distToRim >= BLINK_SAVE_MARGIN and distToRim < bestDist
            and IsBlinkLandingValid(origin, rim) then
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
    if dist <= blinkRange
        and IsValidSavePosition(targetPos, allyPos, castRange, hazard)
        and IsBlinkLandingValid(origin, targetPos) then
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
        if IsValidSavePosition(landing, allyPos, castRange, hazard)
            and IsBlinkLandingValid(origin, landing) then
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
    local landing = Vector(
        origin.x + dirX * blinkDist,
        origin.y + dirY * blinkDist,
        origin.z
    )
    if IsBlinkLandingValid(origin, landing) then
        return landing
    end
    return nil
end

local function IsAllyInCastRange(ctx, ally, castRange)
    if not ally or castRange <= 0 then
        return false
    end
    return SafeCall(NPC.IsEntityInRange, ctx.me, ally, castRange) ~= false
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

local function HasAghanimScepter(ctx)
    local petrify = ctx.abilities.petrify
    if petrify and (SafeCall(Ability.GetLevel, petrify) or 0) > 0 then
        return true
    end
    return SafeCall(NPC.HasScepter, ctx.me) == true
end

local function IsPetrifySaveEnabled()
    return IsAbilityEnabled(PETRIFY_NAME)
end

local function CanCastPetrifySave(ctx)
    local petrify = ctx.abilities.petrify
    if not petrify or (SafeCall(Ability.GetLevel, petrify) or 0) <= 0 then
        return false
    end
    if not CanCastAbility(ctx.me, petrify) then
        return false
    end
    return SafeCall(Ability.IsCastable, petrify, ctx.mana) ~= false
end

local function CanGripSave(ctx, ally, reason)
    if not IsVersusReason(reason) or not IsAbilityEnabled(GRIP_NAME) then
        return false
    end
    if IsGripBlockedOnAlly(ally) then
        return false
    end

    local grip = ctx.abilities.geomagnetic_grip
    if not grip or not CanCastAbility(ctx.me, grip) then
        return false
    end
    if not SafeCall(Ability.IsCastable, grip, ctx.mana) then
        return false
    end

    return IsAllyInCastRange(ctx, ally, ctx.gripRange)
end

local function GetAllyTrackKey(ally)
    return ally and SafeCall(Entity.GetIndex, ally)
end

local function MarkGripSavedAlly(ally)
    local key = GetAllyTrackKey(ally)
    if key then
        State.gripSavedAllies[key] = true
    end
end

local function ClearGripSavedAlly(ally)
    local key = GetAllyTrackKey(ally)
    if key then
        State.gripSavedAllies[key] = nil
    end
end

local function IsGripSavedAlly(ally)
    local key = GetAllyTrackKey(ally)
    return key and State.gripSavedAllies[key] == true
end

local function IsGripReady(ctx)
    local grip = ctx.abilities.geomagnetic_grip
    if not grip or (SafeCall(Ability.GetLevel, grip) or 0) <= 0 then
        return false
    end
    if not CanCastAbility(ctx.me, grip) then
        return false
    end
    return SafeCall(Ability.IsCastable, grip, ctx.mana) ~= false
end

local function ShouldReservePetrifyForAlly(ally, ctx)
    if not IsGripSavedAlly(ally) then
        return false
    end
    -- Grip blocked (duel/chrono): petrify is the real emergency save.
    if IsGripBlockedOnAlly(ally) then
        ClearGripSavedAlly(ally)
        return false
    end
    if IsGripReady(ctx) then
        ClearGripSavedAlly(ally)
        return false
    end
    return true
end

local function NeedsPetrifySave(ctx, ally, reason)
    if ShouldReservePetrifyForAlly(ally, ctx) then
        return false
    end
    return IsVersusReason(reason) and IsPetrifySaveEnabled() and not CanGripSave(ctx, ally, reason)
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

local function ClearPendingPetrify()
    State.petrifyAfterBlink = nil
end

local function CanCastPetrifyOnAlly(ctx, ally)
    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    if not allyPos then
        return false
    end

    local hazard = GetAllySaveHazard(ally)
    if hazard and IsPointInSaveHazard(allyPos, hazard) then
        if not FindSafeCastPositionNearAlly(allyPos, ctx.petrifyRange, hazard) then
            return false
        end
    end

    return IsValidSavePosition(ctx.origin, allyPos, ctx.petrifyRange, hazard)
        and IsAllyInCastRange(ctx, ally, ctx.petrifyRange)
end

local function CanBlinkForPetrifySave(ctx, ally, reason)
    if not NeedsPetrifySave(ctx, ally, reason) then
        return false
    end
    if not HasAghanimScepter(ctx) or not IsPetrifySaveEnabled() then
        return false
    end
    if not CanUseBlinkSave() or not ctx.items.blink then
        return false
    end
    if not CanCastPetrifySave(ctx) then
        return false
    end
    if CanCastPetrifyOnAlly(ctx, ally) then
        return false
    end
    if not SafeCall(Ability.IsCastable, ctx.items.blink, ctx.mana) then
        return false
    end

    local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
    if not allyPos then
        return false
    end

    return ComputeSaveBlinkPos(
        ctx.origin,
        allyPos,
        ctx.petrifyRange,
        ctx.blinkRange,
        ally
    ) ~= nil
end

local function ProcessPendingPetrify(ctx)
    local pending = State.petrifyAfterBlink
    if not pending then
        return false
    end

    if ctx.now >= (pending.expireTime or 0) then
        ClearPendingPetrify()
        return false
    end

    if ctx.now < (pending.readyAfter or 0) then
        return true
    end

    local ally = pending.ally
    if not ally or not IsValidSaveAlly(ally) or IsAllyUnderPetrify(ally) then
        ClearPendingPetrify()
        return false
    end

    if not CanCastPetrifySave(ctx) or not CanCastPetrifyOnAlly(ctx, ally) then
        return true
    end

    if CastAbilityOnAlly(ctx.me, ctx.abilities.petrify, ally, "petrify") then
        MarkSaveQuiet(ctx.now)
        LogDebug(string.format(
            "save cast: petrify on %s reason=%s",
            GetHeroDisplayName(ally),
            pending.reason or "unknown"
        ))
        ClearPendingPetrify()
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
        if stored >= 0 then
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
    return GetVersusThreatEnabledState(threatId, GetVersusThreatDefault(threatId))
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

local function AllyHasStunFromAbility(ally, abilityName)
    local stunMod = SafeCall(NPC.GetModifier, ally, "modifier_stunned")
    if not stunMod then
        return false
    end

    local ability = SafeCall(Modifier.GetAbility, stunMod)
    return ability and SafeCall(Ability.GetName, ability) == abilityName
end

local function AllyHasEarthshakerEchoSlamThreat(ally)
    return AllyHasStunFromAbility(ally, "earthshaker_echo_slam")
end

local function AllyHasCentaurHoofStompThreat(ally)
    if SafeCall(NPC.HasModifier, ally, "modifier_centaur_hoof_stomp") then
        return true
    end
    return AllyHasStunFromAbility(ally, "centaur_hoof_stomp")
end

local function AllyMatchesVersusThreat(ally, threat)
    if threat.id == "beastmaster_primal_roar" then
        return AllyHasBeastmasterPrimalRoarThreat(ally)
    end
    if threat.id == "earthshaker_echo_slam" then
        return AllyHasEarthshakerEchoSlamThreat(ally)
    end
    if threat.id == "centaur_hoof_stomp" then
        return AllyHasCentaurHoofStompThreat(ally)
    end

    for _, modifierName in ipairs(threat.mods) do
        if SafeCall(NPC.HasModifier, ally, modifierName) then
            return true
        end
    end
    return false
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

local function GetGripHeroCastRange(me, grip)
    if not grip then
        return DEFAULT_GRIP_RANGE
    end

    local heroRange = SafeCall(Ability.GetLevelSpecialValueFor, grip, "cast_range_heroes")
    if type(heroRange) == "number" and heroRange > 0 then
        return heroRange + (SafeCall(NPC.GetCastRangeBonus, me) or 0)
    end

    local baseRange = SafeCall(Ability.GetCastRange, grip) or DEFAULT_GRIP_RANGE
    return baseRange + (SafeCall(NPC.GetCastRangeBonus, me) or 0)
end

local function GetPetrifyAllyRange(me, petrify)
    if not petrify or (SafeCall(Ability.GetLevel, petrify) or 0) <= 0 then
        return 0
    end

    local allyRange = SafeCall(Ability.GetLevelSpecialValueFor, petrify, "ally_cast_range")
    if type(allyRange) == "number" and allyRange > 0 then
        return allyRange + (SafeCall(NPC.GetCastRangeBonus, me) or 0)
    end

    return 500 + (SafeCall(NPC.GetCastRangeBonus, me) or 0)
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
    State.allyEnabled[cleanName] = enabled
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
    local mainSection = Menu.Find("Heroes", "Hero List", "Earth Spirit", "Main Settings")
    local group

    if mainSection and mainSection.Create then
        group = mainSection:Create("Auto Save")
    end

    if not group then
        group = Menu.Create("Scripts", "Support", "Earth Spirit Auto Save", "Main", "Auto Save")
    end

    if not group then
        error(LOG_PREFIX .. "Failed to create menu group")
    end

    local screenSize = SafeCall(Render.ScreenSize) or Vec2(3840, 2160)
    local maxX = math.max(800, math.floor(screenSize.x))
    local maxY = math.max(600, math.floor(screenSize.y))

    local ui = {}

    local enabledDefault = SafeCall(Config.ReadInt, CONFIG_SECTION, "enabled", 0) == 1
    ui.Enabled = group:Switch(L("Enable", "Включить"), enabledDefault, Icons.enable)
    WithTooltip(ui.Enabled, L(
        "Auto-save allies on Versus threats: Grip or Aghs Petrify.",
        "Автосейв союзников по Versus-угрозам: Grip или Aghs Petrify."))

    ui.Abilities = group:MultiSelect(
        L("Abilities", "Способности"),
        BuildAbilityMultiSelectItems(),
        true
    )
    MenuIcon(ui.Abilities, Icons.sparkles)
    WithTooltip(ui.Abilities, L(
        "Grip: pull ally when available. Petrify (Aghs): stone ally when Grip is blocked.",
        "Grip: притянуть, если доступен. Petrify (Aghs): окаменить, когда Grip заблокирован."))

    LoadVersusPrefs()
    ui.Versus = group:MultiSelect(
        L("Versus", "Versus"),
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

    local manaDefault = SafeCall(Config.ReadInt, CONFIG_SECTION, "mana_threshold", 20)
    if type(manaDefault) ~= "number" or manaDefault < 0 or manaDefault > 100 then
        manaDefault = 20
    end
    ui.ManaThreshold = gear:Slider(L("Min Mana %", "Мин. MP %"), 0, 100, manaDefault, "%d%%")
    MenuIcon(ui.ManaThreshold, Icons.mana)
    WithTooltip(ui.ManaThreshold, L(
        "Do not cast saves while your mana is below this percentage.",
        "Не использовать сейв, пока ваша мана ниже этого процента."))

    ui.UseBlink = gear:Switch(L("Use Blink for Save", "Использовать Blink для сейва"), true, Icons.blink)
    WithTooltip(ui.UseBlink, L(
        "Only when Aghs Petrify is needed (Grip blocked/out of range): Blink in, then Petrify. Skips Chronosphere.",
        "Только если нужен Aghs Petrify (Grip недоступен): блинк в радиус и Petrify. Обходит Chronosphere."))

    ui.Debug = gear:Switch(L("Debug logs", "Debug логи"), false)
    MenuIcon(ui.Debug, Icons.bug)
    WithTooltip(ui.Debug, L(
        "Write save decisions to the Umbrella log.",
        "Писать решения по сейву в лог Umbrella."))

    ui.PanelX = gear:Slider("HUD X", 0, maxX, math.min(200, maxX))
    ui.PanelY = gear:Slider("HUD Y", 0, maxY, math.min(200, maxY))
    SafeCall(ui.PanelX.Visible, ui.PanelX, false)
    SafeCall(ui.PanelY.Visible, ui.PanelY, false)

    ui.Panel = group:Label(L("Panel", "Панель"), Icons.panel)
    WithTooltip(ui.Panel, L(
        "Ally HUD panel settings.",
        "Настройки HUD-панели союзников."))

    local panelGear = ui.Panel:Gear(L("Panel", "Панель"), Icons.gear, true)

    ui.DrawPanel = panelGear:Switch(L("Enable", "Включить"), true, Icons.enable)
    WithTooltip(ui.DrawPanel, L(
        "HUD panel to choose allies and drag the header to reposition.",
        "HUD-панель выбора союзников. Перетаскивайте заголовок для перемещения."))

    ui.PanelSize = panelGear:Combo(L("Panel Size", "Размер панели"), PANEL_SIZE_ITEMS, PANEL_SIZE_DEFAULT_INDEX)
    WithTooltip(ui.PanelSize, L(
        "Scale the ally HUD panel (50%–150%).",
        "Масштаб HUD-панели союзников (50%–150%)."))

    local gearWidgets = {
        ui.ManaThreshold,
        ui.UseBlink,
        ui.Debug,
    }

    local panelWidgets = {
        ui.DrawPanel,
        ui.PanelSize,
    }

    local mainWidgets = {
        ui.Abilities,
        ui.Versus,
        ui.Panel,
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
        for _, widget in ipairs(panelWidgets) do
            if widget and widget.Disabled then
                widget:Disabled(not enabled)
            end
        end
    end

    local function OnEnabledChanged()
        SafeCall(Config.WriteInt, CONFIG_SECTION, "enabled", ui.Enabled:Get() and 1 or 0)
        UpdateControls()
    end

    ui.Enabled:SetCallback(OnEnabledChanged, true)
    ui.ManaThreshold:SetCallback(function()
        SafeCall(Config.WriteInt, CONFIG_SECTION, "mana_threshold", ui.ManaThreshold:Get())
    end, true)

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

local function GetPanelSizeScale()
    if not UI or not UI.PanelSize or not UI.PanelSize.Get then
        return PANEL_SIZE_SCALES[PANEL_SIZE_DEFAULT_INDEX + 1] or 1.0
    end
    local idx = UI.PanelSize:Get()
    if type(idx) ~= "number" then
        idx = PANEL_SIZE_DEFAULT_INDEX
    end
    return PANEL_SIZE_SCALES[idx + 1] or 1.0
end

local function GetHudScale()
    return ((SafeCall(Menu.Scale) or 100) / 100) * GetPanelSizeScale()
end

local function GetPanelLayout(scale, numAllies, screenSize)
    local cellW = PANEL_CELL_W * scale
    local cellH = PANEL_CELL_H * scale
    local cellSpacing = PANEL_CELL_SPACING * scale
    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local padY = PANEL_BODY_PAD_Y * scale
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
    local width = math.max(headerW, heroesW, PANEL_MIN_WIDTH * scale)
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
        cellsStartX = x + math.floor((width - cellsTotalW) * 0.5 + 0.5),
    }
end

local function SyncAllyTargets(myHero, now)
    if now - State.lastAllySyncTime < ALLY_SYNC_INTERVAL then
        return
    end
    State.lastAllySyncTime = now

    local names = {}
    local entities = {}

    for _, hero in ipairs(SafeCall(Heroes.GetAll) or {}) do
        if IsValidAlly(myHero, hero) then
            local cleanName = CleanHeroName(SafeCall(NPC.GetUnitName, hero))
            if cleanName ~= "" then
                names[#names + 1] = cleanName
                entities[cleanName] = hero
                if State.allyEnabled[cleanName] == nil then
                    IsAllySaveEnabled(cleanName)
                end
            end
        end
    end

    table.sort(names)
    State.cachedAllyNames = names
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
    if not IsLocalEarthSpirit(myHero) then
        return
    end

    local numAllies = #State.cachedAllyNames
    if numAllies == 0 then
        return
    end

    local scale = GetHudScale()
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

    for i, cleanName in ipairs(State.cachedAllyNames) do
        local cellX = layout.cellsStartX + (i - 1) * (layout.cellW + layout.cellSpacing)
        local allyHero = State.cachedAllyEntities[cleanName]
        local enabled = IsAllySaveEnabled(cleanName)

        local accentA = Colors.BorderEnabled.a
        if accentA == nil then
            accentA = 255
        end
        local imgAlpha = enabled and accentA or math.floor(accentA * 0.43)
        local grayscale = enabled and 0.0 or 1.0

        local isCellHovered = isCursorValid
            and mx >= cellX and mx <= cellX + layout.cellW
            and my >= layout.rowY and my <= layout.rowY + layout.cellH

        local heroNameRaw = allyHero and SafeCall(NPC.GetUnitName, allyHero) or ""
        local imgHandle = GetHeroIcon(heroNameRaw)

        if imgHandle then
            Render.Image(
                imgHandle,
                Vec2(cellX, layout.rowY),
                Vec2(layout.cellW, layout.cellH),
                Color(255, 255, 255, imgAlpha),
                3 * scale,
                Enum.DrawFlags.None,
                Vec2(0, 0),
                Vec2(1, 1),
                grayscale)
        end

        if enabled then
            Render.Rect(
                Vec2(cellX, layout.rowY),
                Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
                Colors.BorderEnabled,
                3 * scale,
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
    if not IsLocalEarthSpirit(myHero) then
        return
    end

    if #State.cachedAllyNames == 0 then
        return
    end

    local scale = GetHudScale()
    local screenSize = SafeCall(Render.ScreenSize)
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, #State.cachedAllyNames, screenSize)
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

local function GetAllySaveReason(ally)
    if IsAllyUnderPetrify(ally) then
        return nil
    end

    local threatId, threatScore = GetAllyVersusThreat(ally)
    if threatId then
        return "versus:" .. threatId, threatScore or 0
    end

    return nil
end

local SaveHandlers = {
    {
        name = GRIP_NAME,
        tag = "grip",
        priority = 1,
        CanSave = function(ctx, ally, reason)
            return CanGripSave(ctx, ally, reason)
        end,
        TrySave = function(ctx, ally, reason)
            if CastAbilityOnAlly(ctx.me, ctx.abilities.geomagnetic_grip, ally, "grip") then
                MarkGripSavedAlly(ally)
                MarkSaveQuiet(ctx.now)
                LogDebug(string.format(
                    "save cast: grip on %s reason=%s",
                    GetHeroDisplayName(ally),
                    reason or "unknown"
                ))
                return true
            end
            return false
        end,
    },
    {
        name = "item_blink",
        tag = "blink_petrify",
        priority = 2,
        CanSave = function(ctx, ally, reason)
            if State.petrifyAfterBlink then
                return false
            end
            return CanBlinkForPetrifySave(ctx, ally, reason)
        end,
        TrySave = function(ctx, ally, reason)
            local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
            local blinkPos = allyPos
                and ComputeSaveBlinkPos(ctx.origin, allyPos, ctx.petrifyRange, ctx.blinkRange, ally)
            if not blinkPos or not CastBlinkToPosition(ctx.me, ctx.items.blink, blinkPos) then
                return false
            end

            State.petrifyAfterBlink = {
                ally = ally,
                reason = reason,
                readyAfter = ctx.now + BLINK_AFTER_DELAY,
                expireTime = ctx.now + PETRIFY_AFTER_BLINK_TIME,
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
        name = PETRIFY_NAME,
        tag = "petrify",
        priority = 3,
        CanSave = function(ctx, ally, reason)
            if State.petrifyAfterBlink then
                return false
            end
            if not NeedsPetrifySave(ctx, ally, reason) then
                return false
            end
            if not HasAghanimScepter(ctx) or not IsPetrifySaveEnabled() then
                return false
            end
            if not CanCastPetrifySave(ctx) then
                return false
            end
            if CanBlinkForPetrifySave(ctx, ally, reason) then
                return false
            end
            return CanCastPetrifyOnAlly(ctx, ally)
        end,
        TrySave = function(ctx, ally, reason)
            if CastAbilityOnAlly(ctx.me, ctx.abilities.petrify, ally, "petrify") then
                MarkSaveQuiet(ctx.now)
                LogDebug(string.format(
                    "save cast: petrify on %s reason=%s",
                    GetHeroDisplayName(ally),
                    reason or "unknown"
                ))
                return true
            end
            return false
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
    local grip = SafeCall(NPC.GetAbility, me, GRIP_NAME)
    local petrify = SafeCall(NPC.GetAbility, me, PETRIFY_NAME)
    local blink = GetBlink(me)
    local gripRange = GetGripHeroCastRange(me, grip)
    local petrifyRange = GetPetrifyAllyRange(me, petrify)
    local blinkRange = GetItemCastRange(me, blink, 1200)
    local scanRange = math.max(
        gripRange,
        petrifyRange,
        DEFAULT_PETRIFY_RANGE,
        blinkRange + petrifyRange,
        DEFAULT_GRIP_RANGE
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
            geomagnetic_grip = grip,
            petrify = petrify,
        },
        items = {
            blink = blink,
        },
        gripRange = gripRange,
        petrifyRange = petrifyRange,
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
    local range = ctx.scanRange or DEFAULT_GRIP_RANGE
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
    local bestHp = 1

    for _, ally in ipairs(allies) do
        local cleanName = CleanHeroName(SafeCall(NPC.GetUnitName, ally))
        if cleanName ~= "" and IsAllySaveEnabled(cleanName) then
            local reason, score = GetAllySaveReason(ally)
            if reason and type(score) == "number" and score < bestScore then
                bestScore = score
                bestAlly = ally
                bestReason = reason
                bestHp = GetHealthPct(ally)
            end
        end
    end

    return bestAlly, bestHp, bestReason
end

local function LogSaveTarget(ctx, ally, hpPct, reason)
    if ctx.now < State.saveQuietUntil then
        return
    end
    if ctx.now - State.lastDebugLogTime < DEBUG_LOG_INTERVAL then
        return
    end
    State.lastDebugLogTime = ctx.now

    LogDebug(string.format(
        "save target: %s reason=%s hp=%.0f%% gripRange=%.0f",
        GetHeroDisplayName(ally),
        reason or "unknown",
        hpPct * 100,
        ctx.gripRange or DEFAULT_GRIP_RANGE
    ))
end

local function TryExecuteSave(ctx, ally, reason)
    for _, handler in ipairs(SaveHandlers) do
        if handler.CanSave(ctx, ally, reason) then
            if handler.TrySave(ctx, ally, reason) then
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

    local manaThresholdPct = (ctx.settings.manaThreshold or 20) / 100
    if ctx.manaPct < manaThresholdPct then
        return
    end

    local allies = ScanAllies(ctx)
    local ally, hpPct, reason = PickSaveTarget(ctx, allies)
    if not ally or not reason then
        return
    end

    LogSaveTarget(ctx, ally, hpPct, reason)

    if TryExecuteSave(ctx, ally, reason) then
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
    State.lastAllyScanTime = -100
    State.lastAllySyncTime = -100
    State.lastVersusRosterKey = ""
    State.lastVersusSyncTime = -100
    State.panelHeaderFaFont = nil
    State.panelHeaderFaAvailable = nil

    if Engine.IsInGame() then
        local me = Heroes.GetLocal()
        if IsLocalEarthSpirit(me) then
            RefreshVersusMultiSelect(me, true)
        end
    end

    Log("info", "loaded")
end

function Script.OnGameEnd()
    SyncVersusPrefsFromWidget()
    ShowAllVersusThreats(true)
    ClearPendingPetrify()
    State.gripSavedAllies = {}
    State.saveQuietUntil = -100
    State.lastVersusRosterKey = ""
    State.lastVersusSyncTime = -100
    State.lastAllyScanTime = -100
    State.lastAllySyncTime = -100
    State.lastDebugLogTime = -100
    State.cachedAllies = {}
    State.cachedAllyNames = {}
    State.cachedAllyEntities = {}
    State.allyEnabled = {}
    State.wasMousePressed = false
    PanelDrag.IsDragging = false
    PanelDrag.OffsetX = 0
    PanelDrag.OffsetY = 0
end

function Script.OnThemeUpdate()
    SyncColors()
    fontPanel = ResolvePanelHeaderFont(PANEL_TITLE_TEXT) or 0
    State.panelHeaderFaFont = nil
    State.panelHeaderFaAvailable = nil
end

function Script.OnUpdateEx()
    if not Engine.IsInGame() then
        local now = os.clock()
        if now - (State.lastVersusSyncTime or -100) >= ENEMY_ROSTER_SYNC_INTERVAL then
            State.lastVersusSyncTime = now
            if State.lastVersusRosterKey ~= "" then
                ShowAllVersusThreats(false)
            end
        end
        return
    end

    local me = Heroes.GetLocal()
    if IsLocalEarthSpirit(me) then
        local now = GlobalVars.GetCurTime() or 0
        SyncVersusThreats(me, now)
        SyncAllyTargets(me, now)
    end
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end

    local me = Heroes.GetLocal()
    if IsLocalEarthSpirit(me) then
        local now = GlobalVars.GetCurTime() or 0
        SyncVersusThreats(me, now)
        SyncAllyTargets(me, now)
    end

    if not UI.Enabled:Get() then
        return
    end

    if not me or not IsLocalEarthSpirit(me) then
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

    if ProcessPendingPetrify(ctx) then
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
