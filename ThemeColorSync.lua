--[[
    Theme Color Sync
    Keeps cheat menu color pickers aligned with Menu.Style() theme colors.
    Syncs on theme change, supports restore, grouped toggles, and debug reports.
    Script by Euphoria
--]]

---@diagnostic disable: undefined-global, param-type-mismatch

local Script = {}

--#region Constants

local LOG_PREFIX = "[ThemeColorSync] "
local EVENT_RETRY_DELAY = 0.75
local DEFAULT_SYNC_INTERVAL = 4

local Icons = {
    tab      = "\u{f53f}", -- palette
    enable   = "\u{f011}", -- power
    sync     = "\u{f021}", -- rotate
    restore  = "\u{f2ea}", -- undo
    general  = "\u{f05a}", -- info
    creeps   = "\u{f1b0}", -- paw
    heroes   = "\u{f007}", -- user
    changer  = "\u{f1fc}", -- brush
    danger   = "\u{f071}", -- warning
    retry    = "\u{f021}", -- rotate
    undo     = "\u{f0e2}", -- undo
    groups   = "\u{f0c8}", -- checkbox
    notify   = "\u{f0f3}", -- bell
    debug    = "\u{f120}", -- terminal
    verbose  = "\u{f03a}", -- list
}

--#endregion

--#region State

local State = {
    menuCreated = false,
    syncPending = false,
    syncAt = 0,
    retryPending = false,
    retryAt = 0,
    debugFullNext = true,
    debugWasEnabled = false,
    lastDebugSignature = nil,
    lastPalettePrimary = nil,
    lastPaletteSecondary = nil,
    stats = {applied = 0, missing = 0, skipped = 0, failed = 0},
    statusText = "Last sync: not run yet",
}

local UI = {}
local Targets = {}

--#endregion

--#region Color utils

local ThemeUtils = (function()
    local U = {}

    function U.readMember(value, key)
        local ok, result = pcall(function() return value[key] end)
        if ok then return result end
        return nil
    end

    function U.clampByte(value, fallback)
        if type(value) ~= "number" then return fallback or 0 end
        if value <= 1 and value >= 0 then
            value = value * 255
        end
        if value < 0 then return 0 end
        if value > 255 then return 255 end
        return math.floor(value + 0.5)
    end

    function U.makeColor(r, g, b, a)
        return Color(U.clampByte(r), U.clampByte(g), U.clampByte(b), U.clampByte(a, 255))
    end

    function U.normalizeColor(value)
        local valueType = type(value)
        if valueType ~= "table" and valueType ~= "userdata" then return nil end

        local function channel(keys, fallback)
            for _, key in ipairs(keys) do
                local raw = U.readMember(value, key)
                if type(raw) == "number" then
                    return raw
                end
                if type(raw) == "function" then
                    local ok, result = pcall(raw, value)
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

        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return U.makeColor(r, g, b, a)
        end

        return nil
    end

    function U.colorWithAlpha(color, alpha)
        if not color then return U.makeColor(255, 255, 255, alpha or 255) end
        return U.makeColor(color.r or 255, color.g or 255, color.b or 255, alpha or color.a or 255)
    end

    function U.colorTable(color)
        return {
            r = U.clampByte(color and color.r, 255),
            g = U.clampByte(color and color.g, 255),
            b = U.clampByte(color and color.b, 255),
            a = U.clampByte(color and color.a, 255)
        }
    end

    function U.mixColors(colorA, colorB, t, alpha)
        t = math.max(0, math.min(1, t or 0.5))
        return U.makeColor(
            (colorA.r or 0) + ((colorB.r or 0) - (colorA.r or 0)) * t,
            (colorA.g or 0) + ((colorB.g or 0) - (colorA.g or 0)) * t,
            (colorA.b or 0) + ((colorB.b or 0) - (colorA.b or 0)) * t,
            alpha or ((colorA.a or 255) + ((colorB.a or 255) - (colorA.a or 255)) * t)
        )
    end

    function U.colorsSimilar(colorA, colorB)
        if not colorA or not colorB then return true end
        local dr = (colorA.r or 0) - (colorB.r or 0)
        local dg = (colorA.g or 0) - (colorB.g or 0)
        local db = (colorA.b or 0) - (colorB.b or 0)
        return dr * dr + dg * dg + db * db < 32 * 32
    end

    function U.colorsMatch(colorA, colorB)
        if not colorA or not colorB then return false end
        local dr = math.abs((colorA.r or 0) - (colorB.r or 0))
        local dg = math.abs((colorA.g or 0) - (colorB.g or 0))
        local db = math.abs((colorA.b or 0) - (colorB.b or 0))
        local da = math.abs((colorA.a or 255) - (colorB.a or 255))
        return dr <= 3 and dg <= 3 and db <= 3 and da <= 4
    end

    function U.luminance(color)
        if not color then return 0 end
        return (color.r or 0) * 0.299 + (color.g or 0) * 0.587 + (color.b or 0) * 0.114
    end

    function U.styleTable()
        if not Menu or not Menu.Style then return nil end
        local ok, result = pcall(Menu.Style)
        if ok and type(result) == "table" then return result end
        return nil
    end

    function U.styleColor(name)
        if not Menu or not Menu.Style or not name then return nil end

        local ok, direct = pcall(Menu.Style, name)
        local normalized = ok and U.normalizeColor(direct)
        if normalized then return normalized end

        local tableValue = U.styleTable()
        if tableValue then
            normalized = U.normalizeColor(tableValue[name])
            if normalized then return normalized end
        end

        return nil
    end

    function U.styleColorAny(names, fallback)
        for _, name in ipairs(names) do
            local color = U.styleColor(name)
            if color then return color end
        end
        return fallback
    end

    return U
end)()

local T = ThemeUtils
local unpackArgs = table.unpack
local LoggerInstance = Logger and Logger("ThemeColorSync") or nil

--#endregion

--#region Targets

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function Log(level, message)
    message = tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if pcall(LoggerInstance[level], LoggerInstance, message) then return end
    end
    print(LOG_PREFIX .. message)
end

local function LogInfo(message) Log("info", message) end
local function LogDebug(message) Log("debug", message) end

local function AddTarget(group, role, path, alpha, alternatePaths)
    local entry = {
        group = group,
        role = role,
        path = path,
        alpha = alpha
    }
    if type(alternatePaths) == "table" and #alternatePaths > 0 then
        entry.alternatePaths = alternatePaths
    end
    Targets[#Targets + 1] = entry
end

local function RegisterTargets(addTarget)
    local LHH = {"Creeps", "Main", "[v2]Last Hit Helper", "Main"}

    local function heroPath(hero, ...)
        local path = {"Heroes", "Hero List", hero, "Main Settings"}
        for i = 1, select("#", ...) do
            path[#path + 1] = select(i, ...)
        end
        return path
    end

    local function heroTabPath(hero, ...)
        local path = {"Heroes", "Hero List", hero}
        for i = 1, select("#", ...) do
            path[#path + 1] = select(i, ...)
        end
        return path
    end

    local function lhhPath(...)
        local path = {}
        for i = 1, #LHH do
            path[i] = LHH[i]
        end
        for i = 1, select("#", ...) do
            path[#path + 1] = select(i, ...)
        end
        return path
    end

    local function radiusPaths(...)
        local tail = {...}
        local general = {"General", "Main", "Radius", "Main"}
        local info = {"Info Screen", "Main", "Radius", "Main"}
        local paths = {}
        for _, base in ipairs({general, info}) do
            local path = {}
            for i = 1, #base do
                path[i] = base[i]
            end
            for i = 1, #tail do
                path[#path + 1] = tail[i]
            end
            paths[#paths + 1] = path
        end
        return paths[1], {paths[2]}
    end

    local function lhhParticlePath(...)
        local nested = lhhPath(...)
        local args = {...}
        local alternates = {}

        if args[1] == "Global Settings" and args[2] == "Work Radius" and args[3] == "Work Radius" then
            if args[4] == "Attack Range Particle" and args[5] == "Color" then
                alternates[#alternates + 1] = lhhPath(
                    "Global Settings", "Attack Range Particle", "Attack Range Particle", "Color"
                )
            elseif args[4] == "Work Radius Particle" and args[5] == "1234" then
                alternates[#alternates + 1] = lhhPath(
                    "Global Settings", "Work Radius", "Work Radius Particle", "1234"
                )
            end
        end

        if #alternates == 0 then
            return nested, nil
        end
        return nested, alternates
    end

    local function addHeroInfo(hero, feature, primaryAlternates, secondaryAlternates)
        addTarget("heroes", "primary", heroPath(hero, feature, "Show Info", "Show Info", "Color"), nil, primaryAlternates)
        addTarget("heroes", "secondary", heroPath(hero, feature, "Show Info", "Show Info", "Color##1"), nil, secondaryAlternates)
    end

    local function addHeroDrawBest(hero, feature, primaryAlternates, mutedAlternates)
        addTarget("heroes", "primary", heroPath(hero, feature, "Draw Best Position", "Draw Best Position", "Color"), nil, primaryAlternates)
        addTarget("heroes", "muted", heroPath(hero, feature, "Draw Best Count", "Draw Best Count", "Color"), nil, mutedAlternates)
    end

    local function addHeroDrawBestHeroSettings(hero)
        addTarget("heroes", "primary", heroPath(hero, "Hero Settings", "Draw Best Position", "Draw Best Position", "Color"))
    end

    local function addHeroParticle(hero, ...)
        addTarget("heroes", "particle", heroPath(hero, ...))
    end

    local function addHeroColor(hero, role, ...)
        addTarget("heroes", role, heroPath(hero, ...))
    end

    addTarget("general", "primary", {"General", "Main", "FailSwitch", "Main", "General", "Indication", "Settings", "Color"})
    addTarget("general", "primary", {"General", "Beta", "FailSwitch", "Main", "General", "Indication", "Settings", "Color"})
    addTarget("general", "primary", {"General", "Main", "Procast Damage", "Main", "Indication Settings", "Default Color"})
    addTarget("general", "warn", {"General", "Main", "Procast Damage", "Main", "Indication Settings", "Warn Color"})
    addTarget("general", "lethal", {"General", "Main", "Procast Damage", "Main", "Indication Settings", "Lethal Color"})
    addTarget("general", "warn", {"General", "Main", "Procast Damage", "Main", "Chams & Glow Settings", "Warn Color"})
    addTarget("general", "lethal", {"General", "Main", "Procast Damage", "Main", "Chams & Glow Settings", "Lethal Color"})
    addTarget("general", "particle", {"Heroes", "", "Settings", "General", "Target Selection", "Draw Particle", "Draw Particle", "Particle Color"})
    addTarget("general", "soft", {"Info Screen", "Main", "Aggro Drawer", "Main", "Aggro Drawer", "Aura Color"})
    addTarget("general", "warn", {"Info Screen", "Main", "Info Overlay", "Main", "Top Overlay Settings", "What to Show", "Extra settings", "Coins Color"})
    addTarget("general", "primary", {"Info Screen", "Main", "Show Me More", "Main", "Units", "Show Illusions", "Illusions", "Original Color"})
    addTarget("general", "secondary", {"Info Screen", "Main", "Show Me More", "Main", "Units", "Show Illusions", "Illusions", "Illusion Color"})
    addTarget("general", "primary", {"Info Screen", "Main", "Visible Settings", "VBE", "Visible by Enemy", "Primary Color"})

    do
        local primary, alt = radiusPaths("Others Settings", "Enemy Gem Radius", "Enemy Gem Radius", "Color")
        addTarget("general", "particle", primary, nil, alt)
    end
    do
        local primary, alt = radiusPaths("Others Settings", "Smoke Radius", "Smoke Radius", "Color")
        addTarget("general", "soft", primary, nil, alt)
    end
    do
        local primary, alt = radiusPaths("Structures Settings", "Towers Radius", "Towers Radius", "Color")
        addTarget("general", "primary", primary, nil, alt)
    end
    do
        local primary, alt = radiusPaths("Structures Settings", "Towers Radius", "Towers Radius", "Color##1")
        addTarget("general", "secondary", primary, nil, alt)
    end
    do
        local primary, alt = radiusPaths("Structures Settings", "Watchers Radius", "Watchers Radius", "Color")
        addTarget("general", "muted", primary, nil, alt)
    end

    do
        local primary, alt = lhhParticlePath("Global Settings", "Work Radius", "Work Radius", "Work Radius Particle", "1234")
        addTarget("creeps", "particle", primary, nil, alt)
    end
    do
        local primary, alt = lhhParticlePath("Global Settings", "Work Radius", "Work Radius", "Attack Range Particle", "Color")
        addTarget("creeps", "secondary", primary, nil, alt)
    end
    do
        local primary, alt = lhhParticlePath("Global Settings", "Work Radius", "Work Radius", "Creep Aggro Range Particle", "Color")
        addTarget("creeps", "danger", primary, nil, alt)
    end
    addTarget("creeps", "primary", lhhPath("Global Settings", "Key", "Key", "Color 1"), nil, {
        lhhPath("Global Settings", "Key", "Color 1")
    })
    addTarget("creeps", "secondary", lhhPath("Global Settings", "Key", "Key", "Color 2"), nil, {
        lhhPath("Global Settings", "Key", "Color 2")
    })
    addTarget("creeps", "primary", lhhPath("Visual Settings", "Work Indication", "Work Indication", "Color 1"))
    addTarget("creeps", "secondary", lhhPath("Visual Settings", "Work Indication", "Work Indication", "Color 2"))
    addTarget("creeps", "separator", lhhPath("Visual Settings", "HP Bars", "HP Bars", "Separator Color"))
    addTarget("creeps", "muted", lhhPath("Visual Settings", "HP Bars", "HP Bars", "Minify Color"))
    addTarget("creeps", "lethal", lhhPath("Visual Settings", "Lethal Marker", "Lethal Marker", "Lethal"))
    addTarget("creeps", "warn", lhhPath("Visual Settings", "Lethal Marker", "Lethal Marker", "Nearby Lethal"))
    addTarget("creeps", "ally", lhhPath("Visual Settings", "Lethal Marker", "Lethal Marker", "Ally Lethal"))
    addTarget("creeps", "secondary", lhhPath("Visual Settings", "Lethal Marker", "Lethal Marker", "Ally Nearby Lethal"))
    addTarget("creeps", "primary", lhhPath("Visual Settings", "Attacks to Kill", "Attacks to Kill", "Color"))
    addTarget("creeps", "ally", lhhPath("Visual Settings", "Attacks to Kill", "Attacks to Kill", "Ally Color"))
    addTarget("creeps", "primary", lhhPath("Visual Settings", "Kill Marker", "Kill Marker", "My Hero Color"))
    addTarget("creeps", "danger", lhhPath("Visual Settings", "Kill Marker", "Kill Marker", "Enemy Heroes Color"))
    addTarget("creeps", "ally", lhhPath("Visual Settings", "Kill Marker", "Kill Marker", "Ally Heroes Color"))
    addTarget("creeps", "primary", lhhPath("Visual Settings", "Under Tower Helper", "Under Tower Helper", "Color"), nil, {
        lhhPath("Visual Settings", "Under Tower Helper ", "Under Tower Helper ", "Color"),
        lhhPath("Visual Settings", "Under Tower Helper    ", "Under Tower Helper    ", "Color")
    })
    addTarget("creeps", "ally", lhhPath("Visual Settings", "Under Tower Helper", "Under Tower Helper", "Ally Color"), nil, {
        lhhPath("Visual Settings", "Under Tower Helper ", "Under Tower Helper ", "Ally Color"),
        lhhPath("Visual Settings", "Under Tower Helper    ", "Under Tower Helper    ", "Ally Color")
    })
    addTarget("creeps", "lethal", lhhPath("Skill Damage Indication", "Enable", "Enable", "Lethal"))
    addTarget("creeps", "warn", lhhPath("Skill Damage Indication", "Enable", "Enable", "Nearby Lethal"))
    addTarget("changer", "ally", {"Changer", "Main", "Color Changer", "Main", "Colors", "Ally Creep Color"})
    addTarget("changer", "enemy", {"Changer", "Main", "Color Changer", "Main", "Colors", "Enemy Creep Color"})
    addTarget("changer", "tree1", {"Changer", "Main", "Tree Changer", "Main", "Color Settings", "Tree Color 1"})
    addTarget("changer", "tree2", {"Changer", "Main", "Tree Changer", "Main", "Color Settings", "Tree Color 2"})
    addTarget("changer", "worldLight", {"Changer", "Main", "World", "Main", "World", "Light Color"})
    addTarget("changer", "worldAmbient", {"Changer", "Main", "World", "Main", "World", "Ambient Color"})
    addTarget("changer", "worldFow", {"Changer", "Main", "World", "Main", "World", "Fow Color"})
    addTarget("changer", "primary", {"Changer", "Main", "Watermark", "Main", "Color Settings", "Background", "Color"})
    addTarget("changer", "secondary", {"Changer", "Main", "Watermark", "Main", "Color Settings", "Text", "Color"})
    addTarget("changer", "particle", {"Changer", "Main", "Watermark", "Main", "Color Settings", "Icons", "Color"})
    addTarget("changer", "soft", {"Changer", "Main", "Watermark", "Main", "Color Settings", "Logo", "Color"})
    addTarget("changer", "active", {"Changer", "Main", "Watermark", "Main", "Color Settings", "Icon Hover", "Color"})
    addTarget("changer", "muted", {"Changer", "Main", "Watermark", "Main", "Color Settings", "Alternative", "Color"})
    addTarget("changer", "warn", {"Changer", "Main", "Watermark", "Main", "Color Settings", "Pre Alternative", "Color"})

    local heroInfoFeatures = {
        {"Axe", "Berserker's Call Information"},
        {"Crystal Maiden", "Freezing Field Information"},
        {"Dark Seer", "Vacuum Information"},
        {"Disruptor", "Static Storm Information"},
        {"Earthshaker", "Echo Slam Information"},
        {"Enigma", "Black Hole Information"},
        {"Faceless Void", "Chronosphere Information"},
        {"Magnus", "Reverse Polarity Information"},
        {"Mars", "Arena of Blood Information"},
        {"Outworld Destroyer", "Sanity's Eclipse Information"},
        {"Puck", "Dream Coil Information"},
        {"Rubick", "Berserker's Call Information"},
        {"Rubick", "Reverse Polarity Information"},
        {"Tidehunter", "Ravage Information"},
        {"Treant Protector", "Overgrowth Information"},
        {"Warlock", "Chaotic Offering Information"},
    }

    for _, entry in ipairs(heroInfoFeatures) do
        local hero, feature = entry[1], entry[2]
        local primaryAlternates = nil
        local secondaryAlternates = nil
        if hero == "Rubick" and feature == "Reverse Polarity Information" then
            primaryAlternates = {
                heroPath(hero, feature, "Show Info##1", "Show Info", "Color")
            }
            secondaryAlternates = {
                heroPath(hero, feature, "Show Info##1", "Show Info", "Color##1")
            }
        elseif hero == "Mars" and feature == "Arena of Blood Information" then
            primaryAlternates = {
                heroPath("Mars", "Arena Of Blood Information", "Show Info", "Show Info", "Color")
            }
            secondaryAlternates = {
                heroPath("Mars", "Arena Of Blood Information", "Show Info", "Show Info", "Color##1")
            }
        end
        addHeroInfo(hero, feature, primaryAlternates, secondaryAlternates)
    end

    local heroDrawBestFeatures = {
        {"Crystal Maiden", "Freezing Field Information"},
        {"Crystal Maiden", "Hero Settings"},
        {"Dark Seer", "Vacuum Information"},
        {"Dark Seer", "Hero Settings"},
        {"Disruptor", "Static Storm Information"},
        {"Disruptor", "Hero Settings"},
        {"Faceless Void", "Chronosphere Information"},
        {"Faceless Void", "Hero Settings"},
        {"Magnus", "Reverse Polarity Information"},
        {"Magnus", "Hero Settings"},
        {"Mars", "Arena of Blood Information"},
        {"Puck", "Dream Coil Information"},
        {"Puck", "Hero Settings"},
        {"Tidehunter", "Hero Settings"},
        {"Warlock", "Hero Settings"},
    }

    for _, entry in ipairs(heroDrawBestFeatures) do
        if entry[2] == "Hero Settings" then
            addHeroDrawBestHeroSettings(entry[1])
        else
            local primaryAlternates = nil
            local mutedAlternates = nil
            if entry[1] == "Mars" and entry[2] == "Arena of Blood Information" then
                primaryAlternates = {
                    heroPath("Mars", "Arena Of Blood Information", "Draw Best Position", "Draw Best Position", "Color")
                }
                mutedAlternates = {
                    heroPath("Mars", "Arena Of Blood Information", "Draw Best Count", "Draw Best Count", "Color")
                }
            end
            addHeroDrawBest(entry[1], entry[2], primaryAlternates, mutedAlternates)
        end
    end

    addHeroParticle("Broodmother", "Web Settings", "Particle", "Particlecolor")
    addHeroColor("Dawnbreaker", "primary", "Hero Settings", "Draw Meeting Point", "Draw Meeting Point", "Color")
    addHeroParticle("Disruptor", "Glimpse Helper", "Draw Trajectory Line", "Draw Trajectory Linecolor")
    addHeroColor("Elder Titan", "primary", "Spirit Settings", "Draw Collected Buffs Info", "Draw Collected Buffs Info", "Color")
    addTarget("heroes", "particle", heroTabPath("Invoker", "Auto Usage", "Sun Strike Indication", "Predict Indication", "Predict Indication", "Color"), nil, {
        heroTabPath("Invoker", "Auto Usage", "SunStrike Indication", "Predict Indication", "Predict Indication", "Color")
    })
    addHeroParticle("Keeper Of The Light", "Hero Settings", "Show Illuminate Radius", "Show Illuminate Radiuscolor")
    addHeroParticle("Kunkka", "Hero Settings", "Draw Tidebringer Range", "Draw Tidebringer Rangecolor")
    addHeroColor("Magnus", "primary", "Skewer Combo Settings", "Skewer Set Position", "Skewer Set Position", "Color")
    addHeroColor("Pudge", "primary", "Misc Settings", "Draw Specific Positions", "Draw Specific Positions", "Color")
    addHeroColor("Shadow Fiend", "muted", "Razes Settings", "Show Radiuses", "Show Radiuses", "Reloading")
    addHeroColor("Shadow Fiend", "active", "Razes Settings", "Show Radiuses", "Show Radiuses", "Castable")
    addHeroColor("Shadow Fiend", "danger", "Razes Settings", "Show Radiuses", "Show Radiuses", "Enemy in Radius")
    addHeroParticle("Techies", "Hero Settings", "Draw Radius", "Draw Radius", "Color")
    addHeroParticle("Templar Assassin", "Psionic Trap Radius", "Particle", "Particlecolor")
    addHeroParticle("Weaver", "Hero Settings", "Show Info", "Show Info", "Line Color")
    addHeroParticle("Windranger", "Shackleshot Indication", "Line Particle", "Line Particlecolor")
    addHeroColor("Arc Warden", "particle", "Utility", "Drawings", "Drawings", "Rune Capture Radius", "Color")
    addHeroColor("Arc Warden", "primary", "Utility", "Drawings", "Drawings", "Spark Wraith Radius", "Color")
    addHeroColor("Arc Warden", "muted", "Utility", "Drawings", "Drawings", "Spark Wraith Timer", "Color")
end

RegisterTargets(AddTarget)

--#endregion

--#region Palette

local function WidgetGet(widget, fallback)
    if not widget or type(widget.Get) ~= "function" then return fallback end
    local value = SafeCall(widget.Get, widget)
    if value == nil then return fallback end
    return value
end

local function SyncDelaySeconds()
    local tenths = WidgetGet(UI.syncInterval, DEFAULT_SYNC_INTERVAL)
    if type(tenths) ~= "number" then
        tenths = DEFAULT_SYNC_INTERVAL
    end
    return math.max(0.05, tenths * 0.1)
end

local function DeriveSecondary(primary)
    return T.makeColor(
        (primary.g or 0) * 0.58 + (primary.b or 0) * 0.42,
        (primary.b or 0) * 0.58 + (primary.r or 0) * 0.42,
        (primary.r or 0) * 0.58 + (primary.g or 0) * 0.42,
        primary.a or 255
    )
end

local function BuildPalette()
    local primary = T.styleColorAny(
        {"primary", "accent", "combo_item_active", "indication_active", "highlight"},
        T.makeColor(125, 190, 255, 255)
    )
    local secondary = T.styleColorAny(
        {"secondary", "accent", "combo_item_active", "enabled_switch_background", "highlight"},
        nil
    )

    if not secondary or T.colorsSimilar(primary, secondary) then
        secondary = DeriveSecondary(primary)
    end

    local text = T.styleColorAny({"primary_widgets_text", "primary_text", "text", "section_group_text"}, T.makeColor(210, 218, 230, 255))
    local active = T.styleColorAny({"indication_active", "combo_item_active", "active", "primary"}, T.makeColor(90, 235, 145, 255))
    local preserveDanger = WidgetGet(UI.preserveDangerRed, true)

    local dangerBase = T.makeColor(255, 82, 96, 255)
    local warnBase = T.makeColor(255, 205, 85, 255)
    local danger = preserveDanger and dangerBase or T.mixColors(primary, dangerBase, 0.52, 255)
    local warn = preserveDanger and T.mixColors(primary, warnBase, 0.68, 255) or T.mixColors(primary, warnBase, 0.45, 255)
    local muted = T.mixColors(text, T.makeColor(95, 100, 112, 255), 0.55, 255)
    local lightTheme = T.luminance(T.styleColorAny({"popup_background", "additional_background", "background"}, T.makeColor(24, 26, 32, 255))) > 145

    return {
        primary = T.colorWithAlpha(primary, 255),
        secondary = T.colorWithAlpha(secondary, 255),
        particle = T.colorWithAlpha(primary, 230),
        soft = T.colorWithAlpha(T.mixColors(primary, secondary, 0.35, 255), 210),
        warn = warn,
        lethal = danger,
        danger = danger,
        active = T.colorWithAlpha(active, 255),
        muted = muted,
        separator = lightTheme and T.makeColor(45, 50, 60, 180) or T.colorWithAlpha(muted, 190),
        ally = T.colorWithAlpha(active, 255),
        enemy = danger,
        tree1 = T.mixColors(primary, T.makeColor(70, 160, 95, 255), 0.32, 255),
        tree2 = T.mixColors(secondary, T.makeColor(65, 125, 105, 255), 0.38, 255),
        worldLight = T.mixColors(primary, T.makeColor(255, 255, 255, 255), 0.45, 255),
        worldAmbient = T.mixColors(secondary, T.makeColor(130, 138, 150, 255), 0.35, 255),
        worldFow = T.makeColor((primary.r or 0) * 0.28, (primary.g or 0) * 0.28, (primary.b or 0) * 0.28, 255)
    }
end

local function PaletteChanged(palette)
    if not palette then return true end
    if not State.lastPalettePrimary or not T.colorsMatch(State.lastPalettePrimary, palette.primary) then
        return true
    end
    if not State.lastPaletteSecondary or not T.colorsMatch(State.lastPaletteSecondary, palette.secondary) then
        return true
    end
    return false
end

local function RememberPalette(palette)
    State.lastPalettePrimary = palette and palette.primary or nil
    State.lastPaletteSecondary = palette and palette.secondary or nil
end

local function ColorForTarget(target, palette)
    local color = palette[target.role] or palette.primary
    if target.alpha then
        return T.colorWithAlpha(color, target.alpha)
    end
    return color
end

--#endregion

--#region Menu

local SyncEvent
local QueueSync
local RestoreOriginalColors

local function CreateTab()
    local section = SafeCall(Menu.Find, "Changer", "Main")
    if not (section and section.Create) then
        section = SafeCall(Menu.Find, "Changer")
    end

    local tab = section and section.Create and SafeCall(section.Create, section, "Theme Color Sync")
    if tab then return tab end

    tab = SafeCall(Menu.Create, "Changer", "Main", "Theme Color Sync")
    if tab then return tab end

    return SafeCall(Menu.Create, "General", "Main", "Theme Color Sync")
end

local function MakePage(tab, name)
    if tab and tab.Create then
        local page = SafeCall(tab.Create, tab, name)
        if page then return page end
    end
    return SafeCall(Menu.Create, "Changer", "Main", "Theme Color Sync", name)
end

local function MakeControlGroup(parent, name)
    if parent and parent.Create then
        local group = SafeCall(parent.Create, parent, name)
        if group and group.Switch then
            return group
        end

        if group and group.Create then
            local inner = SafeCall(group.Create, group, name)
            if inner and inner.Switch then
                return inner
            end
        end

        if group then
            return group
        end
    end

    return SafeCall(Menu.Create, "Changer", "Main", "Theme Color Sync", "Settings", name)
end

local function WithTooltip(widget, text)
    if widget and widget.ToolTip then
        SafeCall(widget.ToolTip, widget, text)
    end
    return widget
end

local function UpdateStatusLabel(text)
    State.statusText = text or State.statusText
    local label = UI.statusLabel
    local forceLocalization = label and T.readMember(label, "ForceLocalization")
    if type(forceLocalization) == "function" then
        SafeCall(forceLocalization, label, State.statusText)
    end
end

local function FormatSyncStats(stats)
    return string.format(
        "Last sync: applied=%d missing=%d skipped=%d failed=%d",
        stats.applied or 0,
        stats.missing or 0,
        stats.skipped or 0,
        stats.failed or 0
    )
end

local function BindSyncCallback(widget)
    if not widget or not widget.SetCallback then return end
    SafeCall(widget.SetCallback, widget, function()
        QueueSync(0)
    end)
end

local function EnsureMenu()
    if State.menuCreated or not Menu then return end

    local tab = CreateTab()
    local page = MakePage(tab, "Settings")
    local main = MakeControlGroup(page, "Main")
    local groups = MakeControlGroup(page, "Groups")
    local tuning = MakeControlGroup(page, "Tuning")

    if tab and tab.Icon then
        SafeCall(tab.Icon, tab, Icons.tab)
    end

    UI.enabled = WithTooltip(
        main and main.Switch and main:Switch("Enable", true, Icons.enable),
        "Synchronizes supported visual color pickers with the current cheat theme."
    )
    UI.syncNow = WithTooltip(
        main and main.Button and main:Button("Sync now", function()
            SyncEvent()
        end, true, 1.0),
        "Runs theme color synchronization immediately."
    )
    if UI.syncNow and UI.syncNow.Icon then
        SafeCall(UI.syncNow.Icon, UI.syncNow, Icons.sync)
    end
    UI.restoreOriginal = WithTooltip(
        main and main.Button and main:Button("Restore original colors", function()
            RestoreOriginalColors()
        end, true, 1.0),
        "Restores the colors captured before Theme Color Sync changed them."
    )
    if UI.restoreOriginal and UI.restoreOriginal.Icon then
        SafeCall(UI.restoreOriginal.Icon, UI.restoreOriginal, Icons.restore)
    end
    UI.statusLabel = main and main.Label and main:Label(State.statusText)

    UI.syncGeneral = WithTooltip(
        groups and groups.Switch and groups:Switch("General / Info Screen", true, Icons.general),
        "FailSwitch, procast damage, target particle and info screen colors."
    )
    UI.syncCreeps = WithTooltip(
        groups and groups.Switch and groups:Switch("Creeps", true, Icons.creeps),
        "Last Hit Helper and creep visual colors."
    )
    UI.syncHeroes = WithTooltip(
        groups and groups.Switch and groups:Switch("Heroes", true, Icons.heroes),
        "Hero script radius, particle and info colors."
    )
    UI.syncChanger = WithTooltip(
        groups and groups.Switch and groups:Switch("Changer / World", true, Icons.changer),
        "Creep color changer, tree colors, world colors and watermark."
    )
    UI.preserveDangerRed = WithTooltip(
        tuning and tuning.Switch and tuning:Switch("Preserve danger red", true, Icons.danger),
        "Keeps lethal and danger indicators readable instead of fully tinting them into the theme color."
    )
    UI.retryMissing = WithTooltip(
        tuning and tuning.Switch and tuning:Switch("Retry missing once", true, Icons.retry),
        "Runs one delayed retry only for widgets that were missing or failed during the sync."
    )
    UI.restoreOnDisable = WithTooltip(
        tuning and tuning.Switch and tuning:Switch("Restore on disable", false, Icons.undo),
        "Restores captured original colors when Enable is turned off."
    )
    UI.restoreRespectsGroups = WithTooltip(
        tuning and tuning.Switch and tuning:Switch("Restore respects groups", true, Icons.groups),
        "Only restores widgets from enabled sync groups."
    )
    UI.notifyRestore = WithTooltip(
        tuning and tuning.Switch and tuning:Switch("Notify on restore", true, Icons.notify),
        "Shows a centered notification after restore completes."
    )
    UI.syncInterval = WithTooltip(
        tuning and tuning.Slider and tuning:Slider("Sync interval", 1, 10, DEFAULT_SYNC_INTERVAL, function(v) return v .. " (×0.1s)" end),
        "Delay before sync after theme change, in tenths of a second (4 = 0.4s)."
    )
    UI.debug = WithTooltip(
        tuning and tuning.Switch and tuning:Switch("Debug log", false, Icons.debug),
        "Prints a compact sync report after each pass."
    )
    UI.verboseDebug = WithTooltip(
        tuning and tuning.Switch and tuning:Switch("Verbose debug list", false, Icons.verbose),
        "Also prints the full list of successfully applied color widgets."
    )

    BindSyncCallback(UI.syncGeneral)
    BindSyncCallback(UI.syncCreeps)
    BindSyncCallback(UI.syncHeroes)
    BindSyncCallback(UI.syncChanger)
    BindSyncCallback(UI.preserveDangerRed)
    BindSyncCallback(UI.syncInterval)

    if UI.enabled and UI.enabled.SetCallback then
        SafeCall(UI.enabled.SetCallback, UI.enabled, function()
            if not WidgetGet(UI.enabled, true) and WidgetGet(UI.restoreOnDisable, false) then
                RestoreOriginalColors()
            else
                QueueSync(0)
            end
        end)
    end

    State.menuCreated = tab ~= nil
end

--#endregion

--#region Widget lookup

local function GroupEnabled(group)
    if group == "general" then return WidgetGet(UI.syncGeneral, true) end
    if group == "creeps" then return WidgetGet(UI.syncCreeps, true) end
    if group == "heroes" then return WidgetGet(UI.syncHeroes, true) end
    if group == "changer" then return WidgetGet(UI.syncChanger, true) end
    return true
end

local function WidgetLooksLikeColorPicker(widget)
    if not widget then return false end

    local getFn = T.readMember(widget, "Get")
    if type(getFn) ~= "function" then return true end

    local ok, value = pcall(getFn, widget)
    if not ok then
        ok, value = pcall(getFn)
    end
    if not ok then return true end
    if type(value) == "boolean" then return false end
    return T.normalizeColor(value) ~= nil or value == nil
end

local function TryMenuFind(...)
    if not Menu or not Menu.Find then return nil end
    local ok, result = pcall(Menu.Find, ...)
    if ok then return result end
    return nil
end

local function CallWidgetMethod(widget, method, ...)
    if not widget then return nil end
    local fn = T.readMember(widget, method)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, widget, ...)
    if ok then return result end
    ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function SlicePath(path, fromIdx, toIdx)
    local out = {}
    for i = fromIdx, toIdx do
        out[#out + 1] = path[i]
    end
    return out
end

local function ResolveThroughGear(widget, names, index)
    if not widget or not names then return nil end
    index = index or 1

    if index > #names then
        return WidgetLooksLikeColorPicker(widget) and widget or nil
    end

    local child = CallWidgetMethod(widget, "Find", names[index])
    if not child then return nil end

    if index == #names then
        if WidgetLooksLikeColorPicker(child) then return child end
        for _, colorName in ipairs({"Color", names[index]}) do
            local nested = CallWidgetMethod(child, "Find", colorName)
            if nested and WidgetLooksLikeColorPicker(nested) then
                return nested
            end
        end
        return nil
    end

    return ResolveThroughGear(child, names, index + 1)
end

local function FindWidgetDeep(path)
    local n = #path
    if n == 0 then return nil end

    if n <= 8 then
        local widget = TryMenuFind(unpackArgs(path))
        if widget and WidgetLooksLikeColorPicker(widget) then
            return widget
        end
    end

    if n > 8 then
        local parent = TryMenuFind(unpackArgs(SlicePath(path, 1, 8)))
        local found = ResolveThroughGear(parent, SlicePath(path, 9, n))
        if found then return found end
    end

    for peel = 1, math.min(4, n - 1) do
        local prefixLen = n - peel
        if prefixLen >= 1 and prefixLen <= 8 then
            local parent = TryMenuFind(unpackArgs(SlicePath(path, 1, prefixLen)))
            local found = ResolveThroughGear(parent, SlicePath(path, prefixLen + 1, n))
            if found then return found end
        end
    end

    if n >= 7 then
        local parent = TryMenuFind(unpackArgs(SlicePath(path, 1, 7)))
        local found = ResolveThroughGear(parent, SlicePath(path, 8, n))
        if found then return found end
    end

    return nil
end

local function FindWidget(target)
    if target.widget then return target.widget end
    if not Menu or not Menu.Find then return nil end

    local candidates = {target.path}
    if type(target.alternatePaths) == "table" then
        for _, path in ipairs(target.alternatePaths) do
            candidates[#candidates + 1] = path
        end
    end

    for _, path in ipairs(candidates) do
        if path then
            local widget = FindWidgetDeep(path)
            if widget then
                target.widget = widget
                target.path = path
                return widget
            end
        end
    end

    return nil
end

local function DescribeValue(value)
    if value == nil then return "nil" end

    local valueType = type(value)
    local normalized = T.normalizeColor(value)
    if normalized then
        return string.format(
            "color(%d,%d,%d,%d)",
            normalized.r or 0,
            normalized.g or 0,
            normalized.b or 0,
            normalized.a or 255
        )
    end

    local text = tostring(value)
    if #text > 80 then
        text = text:sub(1, 77) .. "..."
    end
    return valueType .. ":" .. text
end

local function FailedWidgetInfo(widget, lastError)
    local methods = {}
    for _, name in ipairs({"Get", "Set", "SetColor", "Color", "SetValue", "SetRGBA", "SetVector"}) do
        if type(T.readMember(widget, name)) == "function" then
            methods[#methods + 1] = name
        end
    end

    local getInfo = "none"
    local getFn = T.readMember(widget, "Get")
    if type(getFn) == "function" then
        local ok, value = pcall(getFn, widget)
        if not ok then
            ok, value = pcall(getFn)
        end
        getInfo = ok and DescribeValue(value) or "error:" .. tostring(value)
    end

    return string.format(
        "widget=%s methods=%s get=%s error=%s",
        tostring(widget),
        (#methods > 0 and table.concat(methods, ",") or "none"),
        getInfo,
        tostring(lastError or "unknown")
    )
end

local function CurrentWidgetColor(widget)
    local getFn = T.readMember(widget, "Get")
    if type(getFn) ~= "function" then return nil end

    local ok, value = pcall(getFn, widget)
    if not ok then
        ok, value = pcall(getFn)
    end

    return ok and T.normalizeColor(value) or nil
end

local function RememberOriginalColor(target, widget)
    if target.originalCaptured then return end

    local color = CurrentWidgetColor(widget)
    if not color then return end

    target.originalCaptured = true
    target.originalColor = T.colorWithAlpha(color, color.a or 255)
end

local function TrySetterCall(methodName, fn, widget, color)
    local rgba = T.colorTable(color)
    local attempts = {
        {methodName .. "(self, Color)", function() return fn(widget, color) end},
        {methodName .. "(Color)", function() return fn(color) end},
        {methodName .. "(self, table)", function() return fn(widget, rgba) end},
        {methodName .. "(table)", function() return fn(rgba) end},
        {methodName .. "(self, r,g,b,a)", function() return fn(widget, rgba.r, rgba.g, rgba.b, rgba.a) end},
        {methodName .. "(r,g,b,a)", function() return fn(rgba.r, rgba.g, rgba.b, rgba.a) end}
    }

    local lastError = nil
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        if ok then
            if result == false then
                lastError = attempt[1] .. ": returned false"
            else
                local resultColor = T.normalizeColor(result)
                if resultColor and T.colorsMatch(resultColor, color) then
                    return true, attempt[1], result
                end

                local currentColor = CurrentWidgetColor(widget)
                if currentColor and not T.colorsMatch(currentColor, color) then
                    lastError = attempt[1] .. ": current value stayed " .. DescribeValue(currentColor)
                elseif methodName == "Color" then
                    lastError = attempt[1] .. ": unverified Color() method"
                else
                    return true, attempt[1], result
                end
            end
        else
            lastError = attempt[1] .. ": " .. tostring(result)
        end
    end

    return false, lastError
end

local function SetWidgetColor(widget, color)
    if not widget then return false, "widget is nil" end

    local getFn = T.readMember(widget, "Get")
    if type(getFn) == "function" then
        local ok, value = pcall(getFn, widget)
        if not ok then
            ok, value = pcall(getFn)
        end
        if ok and type(value) == "boolean" then
            return nil, "skipped boolean switch: nested color widget is not exposed by Menu.Find"
        end

        local currentColor = ok and T.normalizeColor(value) or CurrentWidgetColor(widget)
        if currentColor and T.colorsMatch(currentColor, color) then
            return nil, "skipped already matches target color"
        end
    end

    local lastError = "no supported setter"
    for _, methodName in ipairs({"Set", "SetColor", "SetValue", "SetRGBA", "SetVector", "Color"}) do
        local fn = T.readMember(widget, methodName)
        if type(fn) == "function" then
            local ok, usedOrError = TrySetterCall(methodName, fn, widget, color)
            if ok then
                return true, usedOrError
            end
            lastError = usedOrError
        end
    end

    return false, FailedWidgetInfo(widget, lastError)
end

--#endregion

--#region Debug

local function PathLabel(path)
    return table.concat(path or {}, " > ")
end

local function AppendDebugLine(list, target)
    if not list then return end
    local extra = target.debugInfo and (" | " .. target.debugInfo) or ""
    list[#list + 1] = string.format("[%s/%s] %s%s", target.group or "?", target.role or "?", PathLabel(target.path), extra)
end

local function DebugSignature(stats)
    return string.format(
        "a:%d|m:%d:%s|s:%d:%s|f:%d:%s",
        stats.applied or 0,
        stats.missing or 0,
        table.concat(stats.missingList or {}, "|"),
        stats.skipped or 0,
        table.concat(stats.skippedList or {}, "|"),
        stats.failed or 0,
        table.concat(stats.failedList or {}, "|")
    )
end

local function PrintDebugList(title, list, limit)
    if not list or #list == 0 then return end

    LogDebug(string.format("%s (%d):", title, #list))
    limit = limit or #list
    for i = 1, math.min(#list, limit) do
        LogDebug("  " .. list[i])
    end
    if #list > limit then
        LogDebug(string.format("  ... +%d more", #list - limit))
    end
end

local function PrintDebugReport(stats, includeApplied)
    LogInfo(string.format(
        "sync report: applied=%d missing=%d skipped=%d failed=%d",
        stats.applied or 0,
        stats.missing or 0,
        stats.skipped or 0,
        stats.failed or 0
    ))

    if includeApplied then
        PrintDebugList("applied", stats.appliedList, 120)
    end
    PrintDebugList("missing", stats.missingList, 120)
    PrintDebugList("skipped", stats.skippedList, 120)
    PrintDebugList("failed", stats.failedList, 120)
end

local function PrintRestoreReport(stats)
    LogInfo(string.format(
        "restore report: restored=%d missing_original=%d missing=%d skipped=%d failed=%d",
        stats.restored or 0,
        stats.missingOriginal or 0,
        stats.missing or 0,
        stats.skipped or 0,
        stats.failed or 0
    ))

    PrintDebugList("restore missing original", stats.missingOriginalList, 120)
    PrintDebugList("restore missing", stats.missingList, 120)
    PrintDebugList("restore skipped", stats.skippedList, 120)
    PrintDebugList("restore failed", stats.failedList, 120)
end

local function ShowRestoreNotification(stats)
    if not WidgetGet(UI.notifyRestore, true) then return end
    if not Render or not Render.CenteredNotification then return end

    SafeCall(Render.CenteredNotification, string.format(
        "Theme Color Sync: restored %d colors",
        stats.restored or 0
    ), 2.5)
end

--#endregion

--#region Sync

RestoreOriginalColors = function()
    EnsureMenu()

    local debugEnabled = WidgetGet(UI.debug, false)
    local respectGroups = WidgetGet(UI.restoreRespectsGroups, true)
    local stats = {
        restored = 0,
        missingOriginal = 0,
        missing = 0,
        skipped = 0,
        failed = 0,
        missingOriginalList = debugEnabled and {} or nil,
        missingList = debugEnabled and {} or nil,
        skippedList = debugEnabled and {} or nil,
        failedList = debugEnabled and {} or nil
    }

    State.syncPending = false

    for _, target in ipairs(Targets) do
        if respectGroups and not GroupEnabled(target.group) then
            goto continue_restore
        end

        if target.originalColor then
            local widget = FindWidget(target)
            if widget then
                local ok, debugInfo = SetWidgetColor(widget, target.originalColor)
                target.debugInfo = nil
                if ok == true then
                    stats.restored = stats.restored + 1
                elseif ok == nil then
                    stats.skipped = stats.skipped + 1
                    target.debugInfo = debugInfo
                    AppendDebugLine(stats.skippedList, target)
                    target.debugInfo = nil
                else
                    target.widget = nil
                    stats.failed = stats.failed + 1
                    target.debugInfo = debugInfo
                    AppendDebugLine(stats.failedList, target)
                    target.debugInfo = nil
                end
            else
                stats.missing = stats.missing + 1
                AppendDebugLine(stats.missingList, target)
            end
        else
            stats.missingOriginal = stats.missingOriginal + 1
            AppendDebugLine(stats.missingOriginalList, target)
        end

        ::continue_restore::
    end

    State.debugFullNext = true
    State.lastDebugSignature = nil
    UpdateStatusLabel(string.format(
        "Last restore: restored=%d missing=%d failed=%d",
        stats.restored or 0,
        stats.missing or 0,
        stats.failed or 0
    ))

    if debugEnabled then
        PrintRestoreReport(stats)
    end

    ShowRestoreNotification(stats)
end

local function SyncTargets(force, retryOnly)
    EnsureMenu()
    if not WidgetGet(UI.enabled, true) then
        State.stats = {applied = 0, missing = 0, skipped = 0, failed = 0}
        UpdateStatusLabel("Last sync: disabled")
        return State.stats
    end

    local palette = BuildPalette()
    RememberPalette(palette)

    local debugEnabled = WidgetGet(UI.debug, false)
    local stats = {
        applied = 0,
        missing = 0,
        skipped = 0,
        failed = 0,
        appliedList = debugEnabled and {} or nil,
        missingList = debugEnabled and {} or nil,
        skippedList = debugEnabled and {} or nil,
        failedList = debugEnabled and {} or nil
    }

    for _, target in ipairs(Targets) do
        if GroupEnabled(target.group) and (not retryOnly or target.needsRetry) then
            local widget = FindWidget(target)
            if widget then
                RememberOriginalColor(target, widget)
                local ok, debugInfo = SetWidgetColor(widget, ColorForTarget(target, palette))
                target.debugInfo = nil
                if ok == true then
                    target.needsRetry = false
                    stats.applied = stats.applied + 1
                    if debugInfo and debugInfo ~= "Set(self, Color)" then
                        target.debugInfo = "setter=" .. tostring(debugInfo)
                    end
                    AppendDebugLine(stats.appliedList, target)
                    target.debugInfo = nil
                elseif ok == nil then
                    target.needsRetry = false
                    stats.skipped = stats.skipped + 1
                    target.debugInfo = debugInfo
                    AppendDebugLine(stats.skippedList, target)
                    target.debugInfo = nil
                else
                    target.needsRetry = true
                    target.widget = nil
                    stats.failed = stats.failed + 1
                    target.debugInfo = debugInfo
                    AppendDebugLine(stats.failedList, target)
                    target.debugInfo = nil
                end
            else
                target.needsRetry = true
                stats.missing = stats.missing + 1
                AppendDebugLine(stats.missingList, target)
            end
        end
    end

    State.stats = stats
    UpdateStatusLabel(FormatSyncStats(stats))

    if debugEnabled then
        local signature = DebugSignature(stats)
        local full = force or State.debugFullNext or State.lastDebugSignature ~= signature
        if full then
            PrintDebugReport(stats, WidgetGet(UI.verboseDebug, false))
            State.lastDebugSignature = signature
            State.debugFullNext = false
        end
    end

    return stats
end

local function ScheduleRetry(stats)
    if not WidgetGet(UI.retryMissing, true) then
        State.retryPending = false
        return
    end

    if stats and ((stats.missing or 0) > 0 or (stats.failed or 0) > 0) then
        State.retryPending = true
        State.retryAt = os.clock() + EVENT_RETRY_DELAY
    else
        State.retryPending = false
    end
end

SyncEvent = function()
    local stats = SyncTargets(true, false)
    ScheduleRetry(stats)
end

QueueSync = function(delay)
    local at = os.clock() + (delay or 0)
    if not State.syncPending or at < (State.syncAt or 0) then
        State.syncAt = at
    end
    State.syncPending = true
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    EnsureMenu()
    SyncEvent()
end

function Script.OnThemeUpdate()
    EnsureMenu()

    local palette = BuildPalette()
    if not PaletteChanged(palette) then
        return
    end

    RememberPalette(palette)
    QueueSync(SyncDelaySeconds())
end

function Script.OnUpdate()
    if not State.menuCreated then
        EnsureMenu()
    end

    local debugEnabled = WidgetGet(UI.debug, false)
    if debugEnabled and not State.debugWasEnabled then
        State.debugFullNext = true
        SyncEvent()
    end
    State.debugWasEnabled = debugEnabled

    if State.syncPending and os.clock() >= (State.syncAt or 0) then
        State.syncPending = false
        SyncEvent()
        return
    end

    if State.retryPending and os.clock() >= (State.retryAt or 0) then
        State.retryPending = false
        SyncTargets(false, true)
    end
end

--#endregion

return Script
