--[[
╭────────────────────────────────────────────────────────────╮
│                                                            │
│                 T H E M E   C O L O R   S Y N C            │
│                                                            │
│                     Script by Euphoria                     │
│                                                            │
├────────────────────────────────────────────────────────────┤
│                        By Pidaras                          │
│                           VibeCode                         │
╰────────────────────────────────────────────────────────────╯
--]]

---@diagnostic disable: undefined-global, param-type-mismatch

local ThemeColorSync = {}

local THEME_SYNC_DELAY = 0.12
local EVENT_RETRY_DELAY = 0.75

local unpackArgs = table.unpack or unpack
local ui = {}
local restoreOriginalColors
local state = {
    menuCreated = false,
    syncPending = false,
    syncAt = 0,
    retryPending = false,
    retryAt = 0,
    debugFullNext = true,
    debugWasEnabled = false,
    lastDebugSignature = nil,
    stats = {applied = 0, missing = 0, skipped = 0, failed = 0}
}

local targets = {}

local function sc(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function addTarget(group, role, path, alpha)
    targets[#targets + 1] = {
        group = group,
        role = role,
        path = path,
        alpha = alpha
    }
end

local function widgetGet(widget, fallback)
    if not widget or type(widget.Get) ~= "function" then return fallback end
    local value = sc(widget.Get, widget)
    if value == nil then return fallback end
    return value
end

local function clampByte(value, fallback)
    if type(value) ~= "number" then return fallback or 0 end
    if value <= 1 and value >= 0 then
        value = value * 255
    end
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return math.floor(value + 0.5)
end

local function makeColor(r, g, b, a)
    return Color(clampByte(r), clampByte(g), clampByte(b), clampByte(a, 255))
end

local function readMember(value, key)
    local ok, result = pcall(function()
        return value[key]
    end)
    if ok then return result end
    return nil
end

local function normalizeColor(value)
    local valueType = type(value)
    if valueType ~= "table" and valueType ~= "userdata" then return nil end

    local function channel(keys, fallback)
        for _, key in ipairs(keys) do
            local raw = readMember(value, key)
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
        return makeColor(r, g, b, a)
    end

    return nil
end

local function colorWithAlpha(color, alpha)
    if not color then return makeColor(255, 255, 255, alpha or 255) end
    return makeColor(color.r or 255, color.g or 255, color.b or 255, alpha or color.a or 255)
end

local function colorTable(color)
    return {
        r = clampByte(color and color.r, 255),
        g = clampByte(color and color.g, 255),
        b = clampByte(color and color.b, 255),
        a = clampByte(color and color.a, 255)
    }
end

local function mixColors(colorA, colorB, t, alpha)
    t = math.max(0, math.min(1, t or 0.5))
    return makeColor(
        (colorA.r or 0) + ((colorB.r or 0) - (colorA.r or 0)) * t,
        (colorA.g or 0) + ((colorB.g or 0) - (colorA.g or 0)) * t,
        (colorA.b or 0) + ((colorB.b or 0) - (colorA.b or 0)) * t,
        alpha or ((colorA.a or 255) + ((colorB.a or 255) - (colorA.a or 255)) * t)
    )
end

local function colorsSimilar(colorA, colorB)
    if not colorA or not colorB then return true end
    local dr = (colorA.r or 0) - (colorB.r or 0)
    local dg = (colorA.g or 0) - (colorB.g or 0)
    local db = (colorA.b or 0) - (colorB.b or 0)
    return dr * dr + dg * dg + db * db < 32 * 32
end

local function colorsMatch(colorA, colorB)
    if not colorA or not colorB then return false end
    local dr = math.abs((colorA.r or 0) - (colorB.r or 0))
    local dg = math.abs((colorA.g or 0) - (colorB.g or 0))
    local db = math.abs((colorA.b or 0) - (colorB.b or 0))
    local da = math.abs((colorA.a or 255) - (colorB.a or 255))
    return dr <= 3 and dg <= 3 and db <= 3 and da <= 4
end

local function luminance(color)
    if not color then return 0 end
    return (color.r or 0) * 0.299 + (color.g or 0) * 0.587 + (color.b or 0) * 0.114
end

local function styleTable()
    if not Menu or not Menu.Style then return nil end
    local ok, result = pcall(Menu.Style)
    if ok and type(result) == "table" then return result end
    return nil
end

local function styleColor(name)
    if not Menu or not Menu.Style or not name then return nil end

    local ok, direct = pcall(Menu.Style, name)
    local normalized = ok and normalizeColor(direct)
    if normalized then return normalized end

    local tableValue = styleTable()
    if tableValue then
        normalized = normalizeColor(tableValue[name])
        if normalized then return normalized end
    end

    return nil
end

local function styleColorAny(names, fallback)
    for _, name in ipairs(names) do
        local color = styleColor(name)
        if color then return color end
    end
    return fallback
end

local function deriveSecondary(primary)
    return makeColor(
        (primary.g or 0) * 0.58 + (primary.b or 0) * 0.42,
        (primary.b or 0) * 0.58 + (primary.r or 0) * 0.42,
        (primary.r or 0) * 0.58 + (primary.g or 0) * 0.42,
        primary.a or 255
    )
end

local function buildPalette()
    local primary = styleColorAny(
        {"primary", "accent", "combo_item_active", "indication_active", "highlight"},
        makeColor(125, 190, 255, 255)
    )
    local secondary = styleColorAny(
        {"secondary", "accent", "combo_item_active", "enabled_switch_background", "highlight"},
        nil
    )

    if not secondary or colorsSimilar(primary, secondary) then
        secondary = deriveSecondary(primary)
    end

    local text = styleColorAny({"primary_widgets_text", "primary_text", "text", "section_group_text"}, makeColor(210, 218, 230, 255))
    local active = styleColorAny({"indication_active", "combo_item_active", "active", "primary"}, makeColor(90, 235, 145, 255))
    local preserveDanger = widgetGet(ui.preserveDangerRed, true)

    local dangerBase = makeColor(255, 82, 96, 255)
    local warnBase = makeColor(255, 205, 85, 255)
    local danger = preserveDanger and dangerBase or mixColors(primary, dangerBase, 0.52, 255)
    local warn = preserveDanger and mixColors(primary, warnBase, 0.68, 255) or mixColors(primary, warnBase, 0.45, 255)
    local muted = mixColors(text, makeColor(95, 100, 112, 255), 0.55, 255)
    local lightTheme = luminance(styleColorAny({"popup_background", "additional_background", "background"}, makeColor(24, 26, 32, 255))) > 145

    return {
        primary = colorWithAlpha(primary, 255),
        secondary = colorWithAlpha(secondary, 255),
        particle = colorWithAlpha(primary, 230),
        soft = colorWithAlpha(mixColors(primary, secondary, 0.35, 255), 210),
        warn = warn,
        lethal = danger,
        danger = danger,
        active = colorWithAlpha(active, 255),
        muted = muted,
        separator = lightTheme and makeColor(45, 50, 60, 180) or colorWithAlpha(muted, 190),
        ally = colorWithAlpha(active, 255),
        enemy = danger,
        tree1 = mixColors(primary, makeColor(70, 160, 95, 255), 0.32, 255),
        tree2 = mixColors(secondary, makeColor(65, 125, 105, 255), 0.38, 255),
        worldLight = mixColors(primary, makeColor(255, 255, 255, 255), 0.45, 255),
        worldAmbient = mixColors(secondary, makeColor(130, 138, 150, 255), 0.35, 255),
        worldFow = makeColor((primary.r or 0) * 0.28, (primary.g or 0) * 0.28, (primary.b or 0) * 0.28, 255)
    }
end

local function colorForTarget(target, palette)
    local color = palette[target.role] or palette.primary
    if target.alpha then
        return colorWithAlpha(color, target.alpha)
    end
    return color
end

local function createTab()
    local section = sc(Menu.Find, "Changer", "Main")
    if not (section and section.Create) then
        section = sc(Menu.Find, "Changer")
    end

    local tab = section and section.Create and sc(section.Create, section, "Theme Color Sync")
    if tab then return tab end

    tab = sc(Menu.Create, "Changer", "Main", "Theme Color Sync")
    if tab then return tab end

    return sc(Menu.Create, "General", "Main", "Theme Color Sync")
end

local function makePage(tab, name)
    if tab and tab.Create then
        local page = sc(tab.Create, tab, name)
        if page then return page end
    end
    return sc(Menu.Create, "Changer", "Main", "Theme Color Sync", name)
end

local function makeControlGroup(parent, name)
    if parent and parent.Create then
        local group = sc(parent.Create, parent, name)
        if group and group.Switch then
            return group
        end

        if group and group.Create then
            local inner = sc(group.Create, group, name)
            if inner and inner.Switch then
                return inner
            end
        end

        if group then
            return group
        end
    end

    return sc(Menu.Create, "Changer", "Main", "Theme Color Sync", "Settings", name)
end

local function withTooltip(widget, text)
    if widget and widget.ToolTip then
        sc(widget.ToolTip, widget, text)
    end
    return widget
end

local function ensureMenu()
    if state.menuCreated or not Menu then return end

    local tab = createTab()
    local page = makePage(tab, "Settings")
    local main = makeControlGroup(page, "Main")
    local groups = makeControlGroup(page, "Groups")
    local tuning = makeControlGroup(page, "Tuning")

    if tab and tab.Icon then
        sc(tab.Icon, tab, "\u{f53f}")
    end

    ui.enabled = withTooltip(
        main and main.Switch and main:Switch("Enable", true, "\u{f011}"),
        "Synchronizes supported visual color pickers with the current cheat theme."
    )
    ui.restoreOriginal = withTooltip(
        main and main.Button and main:Button("Restore original colors", function()
            if restoreOriginalColors then
                restoreOriginalColors()
            end
        end, true, 1.0),
        "Restores the colors captured before Theme Color Sync changed them."
    )
    if ui.restoreOriginal and ui.restoreOriginal.Icon then
        sc(ui.restoreOriginal.Icon, ui.restoreOriginal, "\u{f2ea}")
    end
    ui.syncGeneral = withTooltip(
        groups and groups.Switch and groups:Switch("General / Info Screen", true, "\u{f05a}"),
        "FailSwitch, procast damage, target particle and info screen colors."
    )
    ui.syncCreeps = withTooltip(
        groups and groups.Switch and groups:Switch("Creeps", true, "\u{f1b0}"),
        "Last Hit Helper and creep visual colors."
    )
    ui.syncHeroes = withTooltip(
        groups and groups.Switch and groups:Switch("Heroes", true, "\u{f007}"),
        "Hero script radius, particle and info colors."
    )
    ui.syncChanger = withTooltip(
        groups and groups.Switch and groups:Switch("Changer / World", true, "\u{f1fc}"),
        "Creep color changer, tree colors and world colors."
    )
    ui.preserveDangerRed = withTooltip(
        tuning and tuning.Switch and tuning:Switch("Preserve danger red", true, "\u{f071}"),
        "Keeps lethal and danger indicators readable instead of fully tinting them into the theme color."
    )
    ui.retryMissing = withTooltip(
        tuning and tuning.Switch and tuning:Switch("Retry missing once", true, "\u{f021}"),
        "Runs one delayed retry only for widgets that were missing or failed during the sync."
    )
    ui.debug = withTooltip(
        tuning and tuning.Switch and tuning:Switch("Debug log", false, "\u{f120}"),
        "Prints a compact sync report after each pass."
    )
    ui.verboseDebug = withTooltip(
        tuning and tuning.Switch and tuning:Switch("Verbose debug list", false, "\u{f03a}"),
        "Also prints the full list of successfully applied color widgets."
    )

    state.menuCreated = tab ~= nil
end

local function groupEnabled(group)
    if group == "general" then return widgetGet(ui.syncGeneral, true) end
    if group == "creeps" then return widgetGet(ui.syncCreeps, true) end
    if group == "heroes" then return widgetGet(ui.syncHeroes, true) end
    if group == "changer" then return widgetGet(ui.syncChanger, true) end
    return true
end

local function findWidget(target)
    if target.widget then return target.widget end
    if not Menu or not Menu.Find or not target.path then return nil end

    local ok, widget = pcall(Menu.Find, unpackArgs(target.path))
    if ok and widget then
        target.widget = widget
        return widget
    end

    return nil
end

local function describeValue(value)
    if value == nil then return "nil" end

    local valueType = type(value)
    local normalized = normalizeColor(value)
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

local function failedWidgetInfo(widget, lastError)
    local methods = {}
    for _, name in ipairs({"Get", "Set", "SetColor", "Color", "SetValue", "SetRGBA", "SetVector"}) do
        if type(readMember(widget, name)) == "function" then
            methods[#methods + 1] = name
        end
    end

    local getInfo = "none"
    local getFn = readMember(widget, "Get")
    if type(getFn) == "function" then
        local ok, value = pcall(getFn, widget)
        if not ok then
            ok, value = pcall(getFn)
        end
        getInfo = ok and describeValue(value) or "error:" .. tostring(value)
    end

    return string.format(
        "widget=%s methods=%s get=%s error=%s",
        tostring(widget),
        (#methods > 0 and table.concat(methods, ",") or "none"),
        getInfo,
        tostring(lastError or "unknown")
    )
end

local function currentWidgetColor(widget)
    local getFn = readMember(widget, "Get")
    if type(getFn) ~= "function" then return nil end

    local ok, value = pcall(getFn, widget)
    if not ok then
        ok, value = pcall(getFn)
    end

    return ok and normalizeColor(value) or nil
end

local function rememberOriginalColor(target, widget)
    if target.originalCaptured then return end

    local color = currentWidgetColor(widget)
    target.originalCaptured = true
    if color then
        target.originalColor = colorWithAlpha(color, color.a or 255)
    end
end

local function trySetterCall(methodName, fn, widget, color)
    local rgba = colorTable(color)
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
                local resultColor = normalizeColor(result)
                if resultColor and colorsMatch(resultColor, color) then
                    return true, attempt[1], result
                end

                local currentColor = currentWidgetColor(widget)
                if currentColor and not colorsMatch(currentColor, color) then
                    lastError = attempt[1] .. ": current value stayed " .. describeValue(currentColor)
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

local function setWidgetColor(widget, color)
    if not widget then return false, "widget is nil" end

    local getFn = readMember(widget, "Get")
    if type(getFn) == "function" then
        local ok, value = pcall(getFn, widget)
        if not ok then
            ok, value = pcall(getFn)
        end
        if ok and type(value) == "boolean" then
            return nil, "skipped boolean switch: nested color widget is not exposed by Menu.Find"
        end
    end

    local lastError = "no supported setter"
    for _, methodName in ipairs({"Set", "SetColor", "SetValue", "SetRGBA", "SetVector", "Color"}) do
        local fn = readMember(widget, methodName)
        if type(fn) == "function" then
            local ok, usedOrError = trySetterCall(methodName, fn, widget, color)
            if ok then
                return true, usedOrError
            end
            lastError = usedOrError
        end
    end

    return false, failedWidgetInfo(widget, lastError)
end

local function pathLabel(path)
    return table.concat(path or {}, " > ")
end

local function appendDebugLine(list, target)
    if not list then return end
    local extra = target.debugInfo and (" | " .. target.debugInfo) or ""
    list[#list + 1] = string.format("[%s/%s] %s%s", target.group or "?", target.role or "?", pathLabel(target.path), extra)
end

local function debugSignature(stats)
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

local function printDebugList(title, list, limit)
    if not list or #list == 0 then return end

    print(string.format("[ThemeColorSync] %s (%d):", title, #list))
    limit = limit or #list
    for i = 1, math.min(#list, limit) do
        print("[ThemeColorSync]   " .. list[i])
    end
    if #list > limit then
        print(string.format("[ThemeColorSync]   ... +%d more", #list - limit))
    end
end

local function printDebugReport(stats, includeApplied)
    print(string.format(
        "[ThemeColorSync] sync report: applied=%d missing=%d skipped=%d failed=%d",
        stats.applied or 0,
        stats.missing or 0,
        stats.skipped or 0,
        stats.failed or 0
    ))

    if includeApplied then
        printDebugList("applied", stats.appliedList, 120)
    end
    printDebugList("missing", stats.missingList, 120)
    printDebugList("skipped", stats.skippedList, 120)
    printDebugList("failed", stats.failedList, 120)
end

local function printRestoreReport(stats)
    print(string.format(
        "[ThemeColorSync] restore report: restored=%d missing_original=%d missing=%d skipped=%d failed=%d",
        stats.restored or 0,
        stats.missingOriginal or 0,
        stats.missing or 0,
        stats.skipped or 0,
        stats.failed or 0
    ))

    printDebugList("restore missing original", stats.missingOriginalList, 120)
    printDebugList("restore missing", stats.missingList, 120)
    printDebugList("restore skipped", stats.skippedList, 120)
    printDebugList("restore failed", stats.failedList, 120)
end

restoreOriginalColors = function()
    ensureMenu()

    local debugEnabled = widgetGet(ui.debug, false)
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

    state.syncPending = false
    state.retryPending = false

    for _, target in ipairs(targets) do
        if target.originalColor then
            local widget = findWidget(target)
            if widget then
                local ok, debugInfo = setWidgetColor(widget, target.originalColor)
                target.debugInfo = nil
                if ok == true then
                    stats.restored = stats.restored + 1
                elseif ok == nil then
                    stats.skipped = stats.skipped + 1
                    target.debugInfo = debugInfo
                    appendDebugLine(stats.skippedList, target)
                    target.debugInfo = nil
                else
                    target.widget = nil
                    stats.failed = stats.failed + 1
                    target.debugInfo = debugInfo
                    appendDebugLine(stats.failedList, target)
                    target.debugInfo = nil
                end
            else
                stats.missing = stats.missing + 1
                appendDebugLine(stats.missingList, target)
            end
        else
            stats.missingOriginal = stats.missingOriginal + 1
            appendDebugLine(stats.missingOriginalList, target)
        end
    end

    state.debugFullNext = true
    state.lastDebugSignature = nil

    if debugEnabled then
        printRestoreReport(stats)
    end
end

local function syncTargets(force, retryOnly)
    ensureMenu()
    if not widgetGet(ui.enabled, true) then
        state.stats = {applied = 0, missing = 0, skipped = 0, failed = 0}
        return state.stats
    end

    local palette = buildPalette()
    local debugEnabled = widgetGet(ui.debug, false)
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

    for _, target in ipairs(targets) do
        if groupEnabled(target.group) and (not retryOnly or target.needsRetry) then
            local widget = findWidget(target)
            if widget then
                rememberOriginalColor(target, widget)
                local ok, debugInfo = setWidgetColor(widget, colorForTarget(target, palette))
                target.debugInfo = nil
                if ok == true then
                    target.needsRetry = false
                    stats.applied = stats.applied + 1
                    if debugInfo and debugInfo ~= "Set(self, Color)" then
                        target.debugInfo = "setter=" .. tostring(debugInfo)
                    end
                    appendDebugLine(stats.appliedList, target)
                    target.debugInfo = nil
                elseif ok == nil then
                    target.needsRetry = false
                    stats.skipped = stats.skipped + 1
                    target.debugInfo = debugInfo
                    appendDebugLine(stats.skippedList, target)
                    target.debugInfo = nil
                else
                    target.needsRetry = true
                    target.widget = nil
                    stats.failed = stats.failed + 1
                    target.debugInfo = debugInfo
                    appendDebugLine(stats.failedList, target)
                    target.debugInfo = nil
                end
            else
                target.needsRetry = true
                stats.missing = stats.missing + 1
                appendDebugLine(stats.missingList, target)
            end
        end
    end

    state.stats = stats

    if debugEnabled then
        local signature = debugSignature(stats)
        local full = force or state.debugFullNext or state.lastDebugSignature ~= signature
        if full then
            printDebugReport(stats, widgetGet(ui.verboseDebug, false))
            state.lastDebugSignature = signature
            state.debugFullNext = false
        end
    end

    return stats
end

local function scheduleRetry(stats)
    if not widgetGet(ui.retryMissing, true) then
        state.retryPending = false
        return
    end

    if stats and ((stats.missing or 0) > 0 or (stats.failed or 0) > 0) then
        state.retryPending = true
        state.retryAt = os.clock() + EVENT_RETRY_DELAY
    else
        state.retryPending = false
    end
end

local function syncEvent()
    local stats = syncTargets(true, false)
    scheduleRetry(stats)
end

local function queueSync(delay)
    state.syncPending = true
    state.syncAt = os.clock() + (delay or 0)
    state.retryPending = false
end

addTarget("general", "primary", {"General", "Main", "FailSwitch", "Main", "General", "Indication", "Settings", "Color"})
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

addTarget("creeps", "particle", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Global Settings", "Work Radius", "Work Radius", "Work Radius Particle", "1234"})
addTarget("creeps", "secondary", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Global Settings", "Work Radius", "Work Radius", "Attack Range Particle", "Color"})
addTarget("creeps", "danger", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Global Settings", "Work Radius", "Work Radius", "Creep Aggro Range Particle", "Color"})
addTarget("creeps", "primary", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Visual Settings", "Work Indication", "Work Indication", "Color 1"})
addTarget("creeps", "secondary", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Visual Settings", "Work Indication", "Work Indication", "Color 2"})
addTarget("creeps", "separator", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Visual Settings", "HP Bars", "HP Bars", "Separator Color"})
addTarget("creeps", "lethal", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Visual Settings", "Lethal Marker", "Lethal Marker", "Lethal"})
addTarget("creeps", "warn", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Visual Settings", "Lethal Marker", "Lethal Marker", "Nearby Lethal"})
addTarget("creeps", "ally", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Visual Settings", "Lethal Marker", "Lethal Marker", "Ally Lethal"})
addTarget("creeps", "secondary", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Visual Settings", "Lethal Marker", "Lethal Marker", "Ally Nearby Lethal"})
addTarget("creeps", "lethal", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Skill Damage Indication", "Enable", "Enable", "Lethal"})
addTarget("creeps", "warn", {"Creeps", "Main", "[v2]Last Hit Helper", "Main", "Skill Damage Indication", "Enable", "Enable", "Nearby Lethal"})

addTarget("changer", "ally", {"Changer", "Main", "Color Changer", "Main", "Colors", "Ally Creep Color"})
addTarget("changer", "enemy", {"Changer", "Main", "Color Changer", "Main", "Colors", "Enemy Creep Color"})
addTarget("changer", "tree1", {"Changer", "Main", "Tree Changer", "Main", "Color Settings", "Tree Color 1"})
addTarget("changer", "tree2", {"Changer", "Main", "Tree Changer", "Main", "Color Settings", "Tree Color 2"})
addTarget("changer", "worldLight", {"Changer", "Main", "World", "Main", "World", "Light Color"})
addTarget("changer", "worldAmbient", {"Changer", "Main", "World", "Main", "World", "Ambient Color"})
addTarget("changer", "worldFow", {"Changer", "Main", "World", "Main", "World", "Fow Color"})

addTarget("heroes", "primary", {"Heroes", "Hero List", "Axe", "Main Settings", "Berserker's Call Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Axe", "Main Settings", "Berserker's Call Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Broodmother", "Main Settings", "Web Settings", "Particle", "Particlecolor"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Crystal Maiden", "Main Settings", "Freezing Field Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Crystal Maiden", "Main Settings", "Freezing Field Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Dark Seer", "Main Settings", "Vacuum Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Dark Seer", "Main Settings", "Vacuum Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Dawnbreaker", "Main Settings", "Hero Settings", "Draw Meeting Point", "Draw Meeting Point", "Color"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Disruptor", "Main Settings", "Static Storm Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Disruptor", "Main Settings", "Static Storm Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Disruptor", "Main Settings", "Glimpse Helper", "Draw Trajectory Line", "Draw Trajectory Linecolor"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Earthshaker", "Main Settings", "Echo Slam Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Earthshaker", "Main Settings", "Echo Slam Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Elder Titan", "Main Settings", "Spirit Settings", "Draw Collected Buffs Info", "Draw Collected Buffs Info", "Color"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Enigma", "Main Settings", "Black Hole Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Enigma", "Main Settings", "Black Hole Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Faceless Void", "Main Settings", "Chronosphere Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Faceless Void", "Main Settings", "Chronosphere Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Invoker", "Auto Usage", "Sun Strike Indication", "Predict Indication", "Predict Indication", "Color"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Keeper Of The Light", "Main Settings", "Hero Settings", "Show Illuminate Radius", "Show Illuminate Radiuscolor"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Kunkka", "Main Settings", "Hero Settings", "Draw Tidebringer Range", "Draw Tidebringer Rangecolor"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Magnus", "Main Settings", "Skewer Combo Settings", "Skewer Set Position", "Skewer Set Position", "Color"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Magnus", "Main Settings", "Reverse Polarity Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Magnus", "Main Settings", "Reverse Polarity Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Mars", "Main Settings", "Arena of Blood Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Mars", "Main Settings", "Arena of Blood Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Outworld Destroyer", "Main Settings", "Sanity's Eclipse Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Outworld Destroyer", "Main Settings", "Sanity's Eclipse Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Puck", "Main Settings", "Dream Coil Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Puck", "Main Settings", "Dream Coil Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Pudge", "Main Settings", "Misc Settings", "Draw Specific Positions", "Draw Specific Positions", "Color"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Rubick", "Main Settings", "Berserker's Call Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Rubick", "Main Settings", "Berserker's Call Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "muted", {"Heroes", "Hero List", "Shadow Fiend", "Main Settings", "Razes Settings", "Show Radiuses", "Show Radiuses", "Reloading"})
addTarget("heroes", "active", {"Heroes", "Hero List", "Shadow Fiend", "Main Settings", "Razes Settings", "Show Radiuses", "Show Radiuses", "Castable"})
addTarget("heroes", "danger", {"Heroes", "Hero List", "Shadow Fiend", "Main Settings", "Razes Settings", "Show Radiuses", "Show Radiuses", "Enemy in Radius"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Techies", "Main Settings", "Hero Settings", "Draw Radius", "Draw Radius", "Color"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Templar Assassin", "Main Settings", "Psionic Trap Radius", "Particle", "Particlecolor"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Tidehunter", "Main Settings", "Ravage Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Tidehunter", "Main Settings", "Ravage Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Treant Protector", "Main Settings", "Overgrowth Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Treant Protector", "Main Settings", "Overgrowth Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "primary", {"Heroes", "Hero List", "Warlock", "Main Settings", "Chaotic Offering Information", "Show Info", "Show Info", "Color"})
addTarget("heroes", "secondary", {"Heroes", "Hero List", "Warlock", "Main Settings", "Chaotic Offering Information", "Show Info", "Show Info", "Color##1"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Weaver", "Main Settings", "Hero Settings", "Show Info", "Show Info", "Line Color"})
addTarget("heroes", "particle", {"Heroes", "Hero List", "Windranger", "Main Settings", "Shackleshot Indication", "Line Particle", "Line Particlecolor"})

function ThemeColorSync.OnScriptsLoaded()
    ensureMenu()
    syncEvent()
end

function ThemeColorSync.OnThemeUpdate()
    queueSync(THEME_SYNC_DELAY)
end

function ThemeColorSync.OnUpdate()
    ensureMenu()

    local debugEnabled = widgetGet(ui.debug, false)
    if debugEnabled and not state.debugWasEnabled then
        state.debugFullNext = true
        syncEvent()
    end
    state.debugWasEnabled = debugEnabled

    if state.syncPending and os.clock() >= (state.syncAt or 0) then
        state.syncPending = false
        syncEvent()
        return
    end

    if state.retryPending and os.clock() >= (state.retryAt or 0) then
        state.retryPending = false
        syncTargets(false, true)
    end
end

return ThemeColorSync
