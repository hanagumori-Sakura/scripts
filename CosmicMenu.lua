--[[
    Cosmic Menu
    Full-screen cosmic overlay while the Umbrella menu is open.
    Accent colors always follow Menu.Style / OnThemeUpdate.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local CONSTANTS = {
    DT_DEFAULT = 0.016,
    ANIMATION_DT_MIN = 0.001,
    ANIMATION_DT_MAX = 0.05,
    PARTICLE_CONNECTION_DIST = 150,
    PARTICLE_MAX_CONNECTIONS = 3,
    SHOOTING_STAR_TAIL_LENGTH = 24,
    SHOOTING_STAR_MAX_LIFETIME = 5,
    SHOOTING_STAR_BURST_DURATION = 0.22,
    STAR_RAY_BRIGHTNESS_THRESHOLD = 0.8,
    STAR_RAY_COUNT = 6,
    STAR_GLINT_CHANCE = 0.06,
    SHOOTING_STAR_SPEED_MOD = 0.5,
    FADE_IN_DURATION = 1.5,
    WORMHOLE_PARTICLE_BURST_DURATION = 0.5,
    QUALITY_LOW_THRESHOLD = 0.8,
    STAR_RAY_QUALITY_THRESHOLD = 0.85,
    WASH_ALPHA_BASE = 17,
    VIGNETTE_ALPHA_BASE = 15,
    EDGE_ALPHA_BASE = 20,
    HALO_ALPHA_BASE = 19,
    RIPPLE_DURATION = 1.25,
    THEME_LERP_SPEED = 5.5,
    STARDUST_MAX_POINTS = 22,
    STARDUST_LIFE = 0.6,
    DT_SPIKE_RESET = 0.35,
    MENU_REOPEN_DEBOUNCE_FRAMES = 4,
    MENU_CLOSE_FLICKER_FRAMES = 2,
    POOL_REBALANCE_HYSTERESIS = 18,
    QUALITY_COUNT_SMOOTH_SPEED = 2.0,
    CUSTOM_PRESET_INDEX = 6,
    BUILTIN_PRESET_COUNT = 5,
    IDLE_PAUSE_DEFAULT = 3.0,
    IDLE_THRESHOLD_MIN = 1.0,
    IDLE_THRESHOLD_MAX = 15.0,
    LINK_LOD_QUALITY_THRESHOLD = 0.9,
    LINK_LOD_PARTICLE_THRESHOLD = 150,
    LINK_LOD_CONNECTION_SCALE = 0.5,
    PRESET_CUSTOM_MARK_BLOCK_FRAMES = 4,
    SCREEN_MIN_W = 640,
    SCREEN_MIN_H = 360,
    SCREEN_MAX_W = 7680,
    SCREEN_MAX_H = 4320,
    ACCRETION_RING_SEGMENTS = 72,
    GRAVITY_FILAMENT_COUNT = 6,
    GRAVITY_FILAMENT_SEGMENTS = 28,
    AMBIENT_NEBULA_RATIO = 0.42,
    LINK_PULSE_QUALITY_THRESHOLD = 0.92,
    GLOW_QUALITY_THRESHOLD = 0.82,
    FLYING_ROCKET_MAX = 32,
    FLYING_ROCKET_SEGMENTS = 8,
    STANDARD_SNAP_WIDTH_TOLERANCE = 0.06,
}

local STANDARD_RESOLUTIONS = {
    {1920, 1080}, {2560, 1440}, {3840, 2160}, {1600, 900}, {1366, 768},
    {1280, 720}, {1280, 1024}, {1440, 900}, {2560, 1080}, {3440, 1440},
    {1536, 864}, {2048, 1152}, {1680, 1050},
}

local DEFAULT_SCREEN_SIZE = Vec2(1920, 1080)

local CONFIG_SECTION = "cosmic_menu"
local LOG_PREFIX = "[CosmicMenu] "

local QUALITY_PRESETS = {
    {
        bgParticleCount = 40,
        starCount = 80,
        shootingStars = false,
        stars = true,
        backgroundBlur = false,
        particleConnections = false,
        ambientStreaks = false,
        particleGlow = false,
        ambientStreakCount = 4,
        vignette = false,
        hudEdges = false,
        parallax = true,
        starRays = false,
    },
    {
        bgParticleCount = 100,
        starCount = 150,
        shootingStars = true,
        shootingStarFreq = 3,
        stars = true,
        backgroundBlur = false,
        particleConnections = true,
        particleMaxConnections = 2,
        ambientStreaks = true,
        ambientStreakCount = 10,
        vignette = true,
        hudEdges = true,
        parallax = true,
        starRays = true,
    },
    {
        bgParticleCount = 100,
        starCount = 200,
        shootingStars = true,
        shootingStarFreq = 5,
        stars = true,
        backgroundBlur = false,
        particleConnections = true,
        particleMaxConnections = 3,
        ambientStreaks = true,
        ambientStreakCount = 16,
        vignette = true,
        hudEdges = true,
        parallax = true,
        starRays = true,
        accretionRing = true,
        gravityFilaments = false,
    },
    {
        bgParticleCount = 350,
        starCount = 450,
        shootingStars = true,
        shootingStarFreq = 8,
        stars = true,
        backgroundBlur = true,
        blurIntensity = 0.8,
        particleConnections = true,
        particleMaxConnections = 5,
        ambientStreaks = true,
        ambientStreakCount = 24,
        particleGlow = true,
        vignette = true,
        hudEdges = true,
        parallax = true,
        starRays = true,
        accretionRing = true,
        gravityFilaments = true,
    },
    {
        bgParticleCount = 30,
        starCount = 60,
        shootingStars = false,
        stars = true,
        backgroundBlur = false,
        particleConnections = false,
        ambientStreaks = false,
        particleGlow = false,
        vignette = false,
        hudEdges = false,
        parallax = false,
        starRays = false,
        colorWash = true,
        openRipple = false,
        horizonGrid = false,
        multiLayerStars = false,
        cursorStardust = false,
        particleSoftCore = false,
        particleCursorInteraction = false,
        accretionRing = false,
        gravityFilaments = false,
    },
}

local THEME_STYLE_KEYS = {"accent", "secondary", "highlight", "active", "text", "primary"}

local PRESET_WIDGET_KEYS = {
    "bgParticleCount", "starCount", "shootingStars", "shootingStarFreq", "stars",
    "backgroundBlur", "blurIntensity", "particleConnections", "particleMaxConnections",
    "ambientStreaks", "ambientStreakCount", "particleGlow", "vignette", "hudEdges",
    "parallax", "starRays", "colorWash", "openRipple", "horizonGrid", "multiLayerStars",
    "cursorStardust", "particleSoftCore", "particleCursorInteraction",
    "accretionRing", "gravityFilaments", "flyingRockets", "flyingRocketCount",
}

-- Switches muted while Flying Rockets solo mode is active (blur is kept as-is).
local ROCKET_SOLO_SWITCH_KEYS = {
    "colorWash", "vignette", "hudEdges", "ambientStreaks", "parallax",
    "openRipple", "horizonGrid", "accretionRing", "gravityFilaments",
    "particleSoftCore", "particleGlow", "stars", "shootingStars", "starRays",
    "multiLayerStars", "particleConnections", "particleCursorInteraction", "cursorStardust",
}

local CONFIG_BOOL_KEYS = {
    "enabled", "themeUseAccentOnly", "themeMonochrome", "pauseWhenIdle",
    "backgroundOnly", "debugOverlay",
}

--#endregion

--#region State

local State = {
    primaryColor = nil,
    secondaryColor = nil,
    fadeInAlpha = 1,
    shootingStarsWasEnabled = nil,
    starsWasEnabled = nil,
    multiLayerWasEnabled = nil,
    flyingRocketsWasEnabled = nil,
    rocketSoloActive = false,
    rocketSoloSnapshot = nil,
    lastQualityPreset = nil,
    lastNamedPreset = 3,
    applyingPreset = false,
    displayPrimary = nil,
    displaySecondary = nil,
    targetPrimary = nil,
    targetSecondary = nil,
    frameSettings = nil,
    menuIdleTime = 0,
    simulationPaused = false,
    linkGridSkipFrame = false,
    debugFont = nil,
    lastDt = 0,
    screenFallbackLogged = false,
    blockCustomPresetMarks = 0,
    cachedFullScreenSize = nil,
    lastRawScreenSize = nil,
}

local openRippleTime = 0
local stardustTrail = {}
local starLayerCounter = 0
local time = 0
local fadeInTime = 0
local menuWasOpen = false
local menuClosedFrames = 0
local menuClosedAccumulated = 0
local lastRealTime = nil
local lastCursorX = nil
local lastCursorY = nil
local lastCursorModeApplied = nil
local lastCursorInteractionApplied = nil
local sceneParallaxX = 0
local sceneParallaxY = 0
local cursorHaloX = nil
local cursorHaloY = nil
local cursorHaloOffsetX = 0
local cursorHaloOffsetY = 0
local qualityScale = 1
local qualityScaleForCounts = 1
local qualitySpikeHold = 0
local lastBgTargetCount = 0
local lastStarTargetCount = 0
local lastStreakTargetCount = 0
local lastRocketTargetCount = 0
local baseScreenMinDim = nil
local baseScreenArea = nil

local screenSize = Vec2(1, 1)

local bgParticlePool = {}
local bgParticleActive = {}
local starPool = {}
local starActive = {}
local shootingStarPool = {}
local ambientStreakPool = {}
local ambientStreakActive = {}
local flyingRocketPool = {}
local flyingRocketActive = {}
local linkSpatialGrid = {}

local LoggerInstance = Logger and Logger("CosmicMenu") or nil
local UpdateMenuControls = nil
local GatherFrameSettings
local IsCustomPresetMarkBlocked
local ArmCustomPresetMarkBlock

--#endregion

--#region Helpers

local function SafeCall(fn, ...)
    if not fn then
        return false
    end
    return pcall(fn, ...)
end

local function WidgetSet(widget, value)
    if widget and widget.Set then
        SafeCall(widget.Set, widget, value)
    end
end

local function WidgetGet(widget, default)
    if not widget or not widget.Get then
        return default
    end
    local ok, value = pcall(widget.Get, widget)
    if ok and value ~= nil then
        return value
    end
    return default
end

local function Log(level, message)
    message = tostring(message)
    if LoggerInstance and LoggerInstance[level] then
        if pcall(LoggerInstance[level], LoggerInstance, message) then
            return
        end
    end
    if level == "error" or level == "warn" then
        print(LOG_PREFIX .. message)
    end
end

local function ConfigReadInt(key, default)
    if not Config or not Config.ReadInt then
        return default
    end
    local ok, value = pcall(Config.ReadInt, CONFIG_SECTION, key, default)
    if ok and type(value) == "number" then
        return value
    end
    return default
end

local function ConfigWriteInt(key, value)
    if not Config or not Config.WriteInt then
        return
    end
    SafeCall(Config.WriteInt, CONFIG_SECTION, key, value)
end

local function ConfigReadFloat(key, default)
    if not Config or not Config.ReadFloat then
        return default
    end
    local ok, value = pcall(Config.ReadFloat, CONFIG_SECTION, key, default)
    if ok and type(value) == "number" then
        return value
    end
    return default
end

local function ConfigWriteFloat(key, value)
    if not Config or not Config.WriteFloat then
        return
    end
    SafeCall(Config.WriteFloat, CONFIG_SECTION, key, value)
end

local function randomRangeSafe(minValue, maxValue)
    if maxValue < minValue then
        maxValue = minValue
    end
    return math.random(minValue, maxValue)
end

local function GetSafeScreenDimensions()
    local w = math.floor((screenSize and screenSize.x) or 1)
    local h = math.floor((screenSize and screenSize.y) or 1)

    if w < 1 then w = 1 end
    if h < 1 then h = 1 end

    return w, h
end

local function remapCoord(value, oldMax, newMax)
    if type(value) ~= "number" then
        return value
    end

    if oldMax <= 1 or newMax <= 1 then
        return value
    end

    return value * (newMax / oldMax)
end

local function remapPoolPositionsForScreenChange(oldSize, newSize)
    if not oldSize or not newSize then
        return
    end

    local oldW = oldSize.x or 1
    local oldH = oldSize.y or 1
    local newW = newSize.x or 1
    local newH = newSize.y or 1

    if oldW <= 1 or oldH <= 1 or newW <= 1 or newH <= 1 then
        return
    end

    local widthRatio = newW / oldW
    local heightRatio = newH / oldH
    local significantChange = math.abs(widthRatio - 1) > 0.15 or math.abs(heightRatio - 1) > 0.15
    if not significantChange then
        return
    end

    for _, particle in ipairs(bgParticlePool) do
        particle.x = remapCoord(particle.x, oldW, newW)
        particle.y = remapCoord(particle.y, oldH, newH)
    end

    for _, star in ipairs(starPool) do
        star.x = remapCoord(star.x, oldW, newW)
        star.y = remapCoord(star.y, oldH, newH)
    end

    for _, streak in ipairs(ambientStreakPool) do
        streak.x = remapCoord(streak.x, oldW, newW)
        streak.y = remapCoord(streak.y, oldH, newH)
        streak.length = remapCoord(streak.length, math.min(oldW, oldH), math.min(newW, newH))
    end

    for _, rocket in ipairs(flyingRocketPool) do
        rocket.x = remapCoord(rocket.x, oldW, newW)
        rocket.y = remapCoord(rocket.y, oldH, newH)
        rocket.length = remapCoord(rocket.length, math.min(oldW, oldH), math.min(newW, newH))
    end

    for _, shot in ipairs(shootingStarPool) do
        shot.startX = remapCoord(shot.startX, oldW, newW)
        shot.startY = remapCoord(shot.startY, oldH, newH)
        shot.endX = remapCoord(shot.endX, oldW, newW)
        shot.endY = remapCoord(shot.endY, oldH, newH)

        if shot.tail then
            for _, tailPoint in ipairs(shot.tail) do
                tailPoint.x = remapCoord(tailPoint.x, oldW, newW)
                tailPoint.y = remapCoord(tailPoint.y, oldH, newH)
            end
        end
    end
end

local function normalizeCursorPos(v1, v2)
    if type(v1) == "number" and type(v2) == "number" then
        return Vec2(v1, v2)
    end

    if v1 and type(v1) == "table" then
        local x = v1.x or v1.X
        local y = v1.y or v1.Y
        if type(x) == "number" and type(y) == "number" then
            return Vec2(x, y)
        end
    end

    return nil
end

local function normalizeScreenSize(v1, v2)
    if type(v1) == "number" and type(v2) == "number" and v1 > 1 and v2 > 1 then
        return Vec2(v1, v2)
    end

    if v1 and type(v1) == "table" then
        local x = v1.x or v1.X or v1[1]
        local y = v1.y or v1.Y or v1[2]
        if type(x) == "number" and type(y) == "number" and x > 1 and y > 1 then
            return Vec2(x, y)
        end
    end

    return nil
end

local function normalizeColor(value)
    local t = type(value)
    if t ~= "table" and t ~= "userdata" then
        return nil
    end

    local function readChannel(keys, fallback)
        for _, key in ipairs(keys) do
            local raw = value[key]
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

    local r = readChannel({"r", "R", "red", "Red", "GetR", "GetRed", 1}, nil)
    local g = readChannel({"g", "G", "green", "Green", "GetG", "GetGreen", 2}, nil)
    local b = readChannel({"b", "B", "blue", "Blue", "GetB", "GetBlue", 3}, nil)
    local a = readChannel({"a", "A", "alpha", "Alpha", "GetA", "GetAlpha", 4}, 255)

    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        return Color(r, g, b, a)
    end

    return nil
end

local function updateScreenBaselines(size)
    if not size or not size.x or not size.y then
        return
    end

    local minDim = math.min(size.x, size.y)
    local area = size.x * size.y

    if minDim > 1 and (not baseScreenMinDim or baseScreenMinDim <= 1) then
        baseScreenMinDim = minDim
    end

    if area > 1 and (not baseScreenArea or baseScreenArea <= 1) then
        baseScreenArea = area
    end
end

local function isLikelyPartialViewport(size)
    if not size or not size.x or not size.y then
        return false
    end

    local w = size.x
    local h = math.max(size.y, 1)
    local aspect = w / h

    -- Menu / overlay viewport while Umbrella menu is open (e.g. 1856x687).
    if aspect > 2.05 then
        return true
    end

    if w >= 1100 and h < w * 0.55 then
        return true
    end

    return false
end

local function snapFromPartialWidth(w)
    local bestEntry = nil
    local bestDiff = math.huge

    for i = 1, #STANDARD_RESOLUTIONS do
        local entry = STANDARD_RESOLUTIONS[i]
        local rw = entry[1]
        local rh = entry[2]
        local aspect = rw / math.max(rh, 1)

        if math.abs(aspect - (16 / 9)) < 0.02 then
            local diff = math.abs(rw - w)
            if diff < bestDiff then
                bestDiff = diff
                bestEntry = entry
            end
        end
    end

    if bestEntry and bestDiff <= bestEntry[1] * 0.08 then
        return Vec2(bestEntry[1], bestEntry[2])
    end

    return nil
end

local function snapToStandardResolution(w, h)
    local bestEntry = nil
    local bestScore = math.huge

    for i = 1, #STANDARD_RESOLUTIONS do
        local entry = STANDARD_RESOLUTIONS[i]
        local rw = entry[1]
        local rh = entry[2]
        local widthDiff = math.abs(rw - w) / rw

        if widthDiff <= CONSTANTS.STANDARD_SNAP_WIDTH_TOLERANCE then
            local heightDiff = math.abs(rh - h) / rh
            local score = widthDiff * 2 + heightDiff
            if score < bestScore then
                bestScore = score
                bestEntry = entry
            end
        end
    end

    if bestEntry then
        return Vec2(bestEntry[1], bestEntry[2])
    end

    return nil
end

local function normalizeFullScreenSize(size)
    if not size or not size.x or not size.y then
        return Vec2(DEFAULT_SCREEN_SIZE.x, DEFAULT_SCREEN_SIZE.y)
    end

    local w = math.floor(size.x + 0.5)
    local h = math.floor(size.y + 0.5)

    if w < 1 or h < 1 then
        return Vec2(DEFAULT_SCREEN_SIZE.x, DEFAULT_SCREEN_SIZE.y)
    end

    if isLikelyPartialViewport(size) then
        local fromWidth = snapFromPartialWidth(w)
        if fromWidth then
            return fromWidth
        end
        return Vec2(w, math.floor(w * 9 / 16 + 0.5))
    end

    local snapped = snapToStandardResolution(w, h)
    if snapped then
        return snapped
    end

    if w < CONSTANTS.SCREEN_MIN_W then w = CONSTANTS.SCREEN_MIN_W end
    if w > CONSTANTS.SCREEN_MAX_W then w = CONSTANTS.SCREEN_MAX_W end
    if h < CONSTANTS.SCREEN_MIN_H then h = CONSTANTS.SCREEN_MIN_H end
    if h > CONSTANTS.SCREEN_MAX_H then h = CONSTANTS.SCREEN_MAX_H end
    return Vec2(w, h)
end

local function rememberRawScreenSize(size)
    if size and size.x and size.y and size.x > 1 and size.y > 1 then
        State.lastRawScreenSize = Vec2(size.x, size.y)
    end
end

local function collectRawScreenCandidates()
    local candidates = {}

    local function pushCandidate(value, valueB)
        local normalized = normalizeScreenSize(value, valueB)
        if normalized and normalized.x > 1 and normalized.y > 1 then
            rememberRawScreenSize(normalized)
            candidates[#candidates + 1] = Vec2(normalized.x, normalized.y)
        end
    end

    if Render and Render.ScreenSize then
        local ok, size = SafeCall(Render.ScreenSize)
        if ok then
            pushCandidate(size)
        end
    end

    if Renderer and Renderer.GetScreenSize then
        local ok, size = SafeCall(Renderer.GetScreenSize)
        if ok then
            pushCandidate(size)
        end
    end

    if Engine and Engine.GetScreenSize then
        local ok, a, b = SafeCall(Engine.GetScreenSize)
        if ok then
            pushCandidate(a, b)
        end
    end

    return candidates
end

local function isPlausibleScreenSize(size)
    if not size or not size.x or not size.y then
        return false
    end

    local w = math.floor(size.x)
    local h = math.floor(size.y)
    if w < CONSTANTS.SCREEN_MIN_W or h < CONSTANTS.SCREEN_MIN_H then
        return false
    end
    if w > CONSTANTS.SCREEN_MAX_W or h > CONSTANTS.SCREEN_MAX_H then
        return false
    end

    local aspect = w / math.max(h, 1)
    if aspect < 0.55 or aspect > 2.05 then
        return false
    end

    return true
end

local function resetScreenBaselines(size)
    if not isPlausibleScreenSize(size) then
        return
    end

    baseScreenMinDim = math.min(size.x, size.y)
    baseScreenArea = size.x * size.y
end

local function scoreScreenCandidate(size, sourcePriority)
    if not size or not size.x or not size.y then
        return -1
    end

    local normalized = normalizeFullScreenSize(size)
    if not isPlausibleScreenSize(normalized) then
        return -1
    end

    local aspect = normalized.x / normalized.y
    local aspectScore = 1 - math.min(math.abs(aspect - (16 / 9)), math.abs(aspect - (16 / 10))) * 0.35
    local areaPenalty = 0
    local area = normalized.x * normalized.y

    if isLikelyPartialViewport(size) then
        areaPenalty = areaPenalty + 0.45
    end

    if area > 3840 * 2160 then
        areaPenalty = areaPenalty + 0.35
    end

    return sourcePriority + aspectScore * 0.25 - areaPenalty
end

local function pickBestFullScreenSize(candidates)
    local best = nil
    local bestScore = -1

    for i = 1, #candidates do
        local raw = candidates[i]
        State.lastRawScreenSize = raw
        local normalized = normalizeFullScreenSize(raw)
        if isPlausibleScreenSize(normalized) then
            local score = scoreScreenCandidate(raw, 1.0)
            if score > bestScore then
                bestScore = score
                best = normalized
            end
        end
    end

    return best
end

local function RefreshCachedFullScreenSize()
    local candidates = collectRawScreenCandidates()
    local best = pickBestFullScreenSize(candidates)

    if best then
        State.cachedFullScreenSize = best
        return best
    end

    if State.cachedFullScreenSize and isPlausibleScreenSize(State.cachedFullScreenSize) then
        return State.cachedFullScreenSize
    end

    return nil
end

local function getAdaptiveFallbackScreenSize()
    if State.lastRawScreenSize then
        local fromRaw = normalizeFullScreenSize(State.lastRawScreenSize)
        if isPlausibleScreenSize(fromRaw) then
            return fromRaw
        end
    end

    local candidates = collectRawScreenCandidates()
    local best = pickBestFullScreenSize(candidates)
    if best then
        return best
    end

    return Vec2(DEFAULT_SCREEN_SIZE.x, DEFAULT_SCREEN_SIZE.y)
end

local function GetBestScreenSize()
    local cached = RefreshCachedFullScreenSize()
    if cached then
        updateScreenBaselines(cached)
        return Vec2(cached.x, cached.y)
    end

    local fallback = getAdaptiveFallbackScreenSize()
    fallback = normalizeFullScreenSize(fallback)
    updateScreenBaselines(fallback)
    if not State.screenFallbackLogged then
        State.screenFallbackLogged = true
        local rawText = State.lastRawScreenSize
            and string.format(" (raw %dx%d)", State.lastRawScreenSize.x, State.lastRawScreenSize.y)
            or ""
        Log("warn", "Using screen size fallback: " .. fallback.x .. "x" .. fallback.y .. rawText)
    end
    return fallback
end

local function GetLiveRenderScreenSize()
    local raw = nil

    if Render and Render.ScreenSize then
        local ok, size = SafeCall(Render.ScreenSize)
        if ok then
            raw = normalizeScreenSize(size)
        end
    end

    if not raw and Renderer and Renderer.GetScreenSize then
        local ok, size = SafeCall(Renderer.GetScreenSize)
        if ok then
            raw = normalizeScreenSize(size)
        end
    end

    if raw then
        State.lastRawScreenSize = Vec2(raw.x, raw.y)
    end

    if State.cachedFullScreenSize and isPlausibleScreenSize(State.cachedFullScreenSize) then
        return Vec2(State.cachedFullScreenSize.x, State.cachedFullScreenSize.y)
    end

    if raw then
        return normalizeFullScreenSize(raw)
    end

    return Vec2(screenSize.x, screenSize.y)
end

local function CaptureScreenSizeForMenuSession()
    RefreshCachedFullScreenSize()

    local size = State.cachedFullScreenSize or GetBestScreenSize()
    size = normalizeFullScreenSize(size)

    if not isPlausibleScreenSize(size) then
        return
    end

    local previousSize = screenSize
    if previousSize.x > 1 and previousSize.y > 1 then
        local widthRatio = size.x / previousSize.x
        local heightRatio = size.y / previousSize.y
        if math.abs(widthRatio - 1) > 0.05 or math.abs(heightRatio - 1) > 0.05 then
            remapPoolPositionsForScreenChange(previousSize, size)
            resetScreenBaselines(size)
        end
    else
        resetScreenBaselines(size)
    end

    screenSize = size
    updateScreenBaselines(size)
end

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function makeColor(r, g, b, a)
    return Color(
        clamp(math.floor(r + 0.5), 0, 255),
        clamp(math.floor(g + 0.5), 0, 255),
        clamp(math.floor(b + 0.5), 0, 255),
        clamp(math.floor((a or 255) + 0.5), 0, 255)
    )
end

local function colorWithAlpha(color, alpha)
    return makeColor(color.r, color.g, color.b, alpha)
end

local function mixColors(colorA, colorB, t, alpha)
    return makeColor(
        lerp(colorA.r, colorB.r, t),
        lerp(colorA.g, colorB.g, t),
        lerp(colorA.b, colorB.b, t),
        alpha or lerp(colorA.a or 255, colorB.a or 255, t)
    )
end

local function getGlobalVarNumber(methodName)
    if not GlobalVars or not GlobalVars[methodName] then
        return nil
    end

    local ok, value = pcall(GlobalVars[methodName], GlobalVars)
    if ok and type(value) == "number" then
        return value
    end

    return nil
end

local function GetAnimationDt()
    local realTime = getGlobalVarNumber("GetRealTime")
    if realTime then
        if lastRealTime then
            local rawDt = realTime - lastRealTime
            lastRealTime = realTime

            if rawDt and rawDt > 0 then
                if rawDt > CONSTANTS.DT_SPIKE_RESET then
                    rawDt = CONSTANTS.DT_DEFAULT
                end
                return clamp(rawDt, CONSTANTS.ANIMATION_DT_MIN, CONSTANTS.ANIMATION_DT_MAX)
            end
        else
            lastRealTime = realTime
        end
    else
        lastRealTime = nil
    end

    local fallbackDt = getGlobalVarNumber("GetAbsFrameTime") or getGlobalVarNumber("GetFrameTime") or CONSTANTS.DT_DEFAULT
    if fallbackDt <= 0 then
        fallbackDt = CONSTANTS.DT_DEFAULT
    end

    return clamp(fallbackDt, CONSTANTS.ANIMATION_DT_MIN, CONSTANTS.ANIMATION_DT_MAX)
end

local function getScreenAreaScale()
    local currentArea = (screenSize.x or 1) * (screenSize.y or 1)
    local baselineArea = baseScreenArea and math.max(baseScreenArea, 1) or math.max(currentArea, 1)
    return clamp(currentArea / baselineArea, 0.7, 2.2)
end

local function createBgParticle()
    local w, h = GetSafeScreenDimensions()
    return {
        x = randomRangeSafe(0, w),
        y = randomRangeSafe(0, h),
        size = math.random(1, 4),
        speed = math.random(20, 100) / 100,
        angle = math.random() * math.pi * 2,
        baseBrightness = math.random(35, 90) / 100,
        brightness = math.random(35, 90) / 100,
        twinkleSpeed = math.random(60, 180) / 100,
        twinklePhase = math.random() * math.pi * 2,
        driftPhase = math.random() * math.pi * 2,
        driftSpeed = math.random(40, 140) / 100,
        driftStrength = math.random(20, 120) / 100,
        angularVelocity = (math.random() - 0.5) * 0.8,
        depth = math.random(70, 150) / 100,
        impulseX = 0,
        impulseY = 0,
        colorIdx = math.random(1, 2),
        active = true
    }
end

local function roundToInt(value)
    if type(value) ~= "number" then
        return 0
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function GetCursorPos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok then
            local pos = normalizeCursorPos(x, y)
            if pos then
                return pos
            end
        end

        ok, x, y = pcall(function() return Input:GetCursorPos() end)
        if ok then
            local pos = normalizeCursorPos(x, y)
            if pos then
                return pos
            end
        end
    end

    if not Engine or not Engine.GetCursorPos then
        return nil
    end

    local ok, a, b = pcall(Engine.GetCursorPos)
    if ok then
        local pos = normalizeCursorPos(a, b)
        if pos then
            return pos
        end
    end

    ok, a, b = pcall(Engine.GetCursorPos, Engine)
    if ok then
        local pos = normalizeCursorPos(a, b)
        if pos then
            return pos
        end
    end

    ok, a, b = pcall(function() return Engine:GetCursorPos() end)
    if ok then
        local pos = normalizeCursorPos(a, b)
        if pos then
            return pos
        end
    end

    return nil
end

local STAR_LAYER_PARALLAX = {0.08, 0.52, 1.25}
local STAR_LAYER_ALPHA = {0.28, 0.62, 1.0}
local STAR_LAYER_SIZE = {0.42, 1.0, 2.05}
local STAR_LAYER_TWINKLE_SPEED = {0.50, 1.0, 1.55}
local STAR_LAYER_DRIFT = {0.35, 0.72, 1.15}

local function assignStarLayer(star)
    if Script.multiLayerStars and Script.multiLayerStars:Get() then
        starLayerCounter = (starLayerCounter % 3) + 1
        star.layer = starLayerCounter
    else
        star.layer = 2
    end
end

local function configureShootingStarTrajectory(star, w, h)
    local roll = math.random(1, 100)

    if roll <= 55 then
        star.startX = randomRangeSafe(0, w)
        star.startY = math.random(-120, -20)
        star.endX = star.startX + randomRangeSafe(math.floor(-w * 0.35), math.floor(w * 0.35))
        star.endY = randomRangeSafe(math.floor(h * 0.6), h + 200)
    elseif roll <= 85 then
        local fromLeft = math.random() < 0.5
        star.startX = fromLeft and math.random(-80, math.floor(w * 0.2)) or math.random(math.floor(w * 0.8), w + 80)
        star.startY = math.random(-100, math.floor(h * 0.3))
        star.endX = fromLeft and randomRangeSafe(math.floor(w * 0.5), w + 100) or randomRangeSafe(-100, math.floor(w * 0.5))
        star.endY = randomRangeSafe(math.floor(h * 0.55), h + 150)
    else
        star.startX = math.random(-150, -20)
        star.startY = randomRangeSafe(math.floor(h * 0.08), math.floor(h * 0.45))
        star.endX = w + math.random(20, 150)
        star.endY = star.startY + randomRangeSafe(math.floor(-h * 0.12), math.floor(h * 0.18))
    end

    local dx = star.endX - star.startX
    local dy = star.endY - star.startY
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.001 then
        star.dirX = dx / len
        star.dirY = dy / len
    else
        star.dirX = 0
        star.dirY = 1
    end
end

local function configureAmbientStreakType(streak, w, h, streakType)
    streak.streakType = streakType or ((math.random() < CONSTANTS.AMBIENT_NEBULA_RATIO) and 1 or 2)

    if streak.streakType == 1 then
        local tilt = (math.random() * 2 - 1) * 0.12
        streak.x = randomRangeSafe(-math.floor(w * 0.15), w)
        streak.y = randomRangeSafe(math.floor(h * 0.1), math.floor(h * 0.85))
        streak.length = math.random(180, 400)
        streak.speed = math.random(3, 8) / 10
        streak.angle = math.rad(-8) + tilt
        streak.alpha = math.random(4, 10)
        streak.width = math.random(3, 6)
        streak.drift = (math.random() * 2 - 1) * 6
    else
        local tilt = (math.random() * 2 - 1) * 0.28
        streak.x = randomRangeSafe(-math.floor(w * 0.3), w)
        streak.y = randomRangeSafe(0, h)
        streak.length = math.random(40, 120)
        streak.speed = math.random(15, 35) / 10
        streak.angle = math.rad(-18) + tilt
        streak.alpha = math.random(12, 22)
        streak.width = 1
        streak.drift = (math.random() * 2 - 1) * 18
    end

    streak.progress = 0
    streak.active = true
end

local function createStar()
    local w, h = GetSafeScreenDimensions()
    local star = {
        x = randomRangeSafe(0, w),
        y = randomRangeSafe(0, h),
        size = math.random(1, 3),
        twinkleSpeed = math.random(1, 5),
        twinklePhase = math.random() * math.pi * 2,
        brightness = math.random(50, 100) / 100,
        rayAngle = math.random() * math.pi * 2,
        raySpinSpeed = (math.random() * 2 - 1) * 0.4,
        glintEligible = math.random() < CONSTANTS.STAR_GLINT_CHANCE,
        glintCooldown = math.random() * 10 + 4,
        glintBoost = 0,
        layer = 2,
        active = true
    }
    assignStarLayer(star)
    return star
end

local function createShootingStar()
    local w, h = GetSafeScreenDimensions()
    local star = {
        progress = 0,
        speed = math.random(5, 20) / 10,
        size = math.random(2, 4),
        tail = {},
        lifetime = 0,
        burstLife = nil,
        burstStarted = false,
        active = false
    }
    configureShootingStarTrajectory(star, w, h)
    return star
end

local function createAmbientStreak()
    local w, h = GetSafeScreenDimensions()
    local streak = { progress = math.random(), active = true }
    configureAmbientStreakType(streak, w, h)
    return streak
end

local function resetAmbientStreak(streak)
    local w, h = GetSafeScreenDimensions()
    configureAmbientStreakType(streak, w, h)
end

local function resetShootingStar(star)
    local w, h = GetSafeScreenDimensions()

    configureShootingStarTrajectory(star, w, h)
    star.progress = 0
    star.speed = math.random(5, 20) / 10
    star.size = math.random(2, 4)
    star.lifetime = 0
    star.burstLife = nil
    star.burstStarted = false
    star.active = true
    star.tail = star.tail or {}
    clearList(star.tail)
end

local function configureFlyingRocket(rocket, w, h)
    local fromLeft = math.random() < 0.5
    rocket.length = math.random(42, 68)
    rocket.width = math.random(10, 16)
    rocket.speed = math.random(48, 105)
    rocket.wobble = (math.random() * 2 - 1) * 0.7
    rocket.wobblePhase = math.random() * math.pi * 2
    rocket.spin = (math.random() * 2 - 1) * 0.22
    rocket.angle = fromLeft and (math.rad(-16) + (math.random() * 2 - 1) * 0.28)
        or (math.rad(196) + (math.random() * 2 - 1) * 0.28)
    rocket.alpha = math.random(150, 220)
    rocket.tint = math.random() * 0.45 + 0.15
    rocket.x = fromLeft and randomRangeSafe(-100, -28) or randomRangeSafe(w + 28, w + 100)
    rocket.y = randomRangeSafe(math.floor(h * 0.1), math.floor(h * 0.9))
    rocket.progress = 0
    rocket.active = true
end

local function createFlyingRocket()
    local w, h = GetSafeScreenDimensions()
    local rocket = {}
    configureFlyingRocket(rocket, w, h)
    rocket.active = false
    return rocket
end

local function resetFlyingRocket(rocket)
    local w, h = GetSafeScreenDimensions()
    configureFlyingRocket(rocket, w, h)
end

local function initPool(pool, factory, initialSize)
    for i = 1, initialSize do
        pool[i] = factory()
    end
end

local function getFromPool(pool, factory)
    for i, obj in ipairs(pool) do
        if not obj.active then
            obj.active = true
            return obj
        end
    end
    local newObj = factory()
    newObj.active = true
    pool[#pool + 1] = newObj
    return newObj
end

local function rebalancePool(pool, targetCount, factory, onActivate)
    local activeCount = 0
    for i, obj in ipairs(pool) do
        if obj.active then
            activeCount = activeCount + 1
        end
    end

    if activeCount < targetCount then
        local toActivate = targetCount - activeCount

        for i, obj in ipairs(pool) do
            if toActivate <= 0 then break end
            if not obj.active then
                obj.active = true
                if onActivate then
                    onActivate(obj)
                end
                toActivate = toActivate - 1
            end
        end

        while toActivate > 0 do
            local obj = factory()
            obj.active = true
            if onActivate then
                onActivate(obj)
            end
            pool[#pool + 1] = obj
            toActivate = toActivate - 1
        end
    elseif activeCount > targetCount then
        local toDeactivate = activeCount - targetCount
        for i = #pool, 1, -1 do
            if toDeactivate <= 0 then break end
            if pool[i].active then
                pool[i].active = false
                toDeactivate = toDeactivate - 1
            end
        end
    end
end

local function rebalancePoolIfChanged(pool, targetCount, lastTargetCount, factory, onActivate)
    -- Always rebalance when enabling from empty or fully disabling.
    -- Hysteresis only skips tiny count tweaks while the pool stays populated.
    if targetCount == 0 or lastTargetCount == 0 then
        rebalancePool(pool, targetCount, factory, onActivate)
        return targetCount
    end

    if math.abs(targetCount - lastTargetCount) < CONSTANTS.POOL_REBALANCE_HYSTERESIS then
        return lastTargetCount
    end

    rebalancePool(pool, targetCount, factory, onActivate)
    return targetCount
end

local function collectActive(pool, outList)
    clearList(outList)
    for i, obj in ipairs(pool) do
        if obj.active then
            outList[#outList + 1] = obj
        end
    end
end

local function deactivatePoolObjects(list)
    for i, obj in ipairs(list) do
        obj.active = false
    end
end

local function resetParticleImpulses()
    for i, particle in ipairs(bgParticlePool) do
        particle.impulseX = 0
        particle.impulseY = 0
    end
end

local function resetInteractionState()
    lastCursorX = nil
    lastCursorY = nil
    lastCursorModeApplied = nil
    lastCursorInteractionApplied = nil
    cursorHaloX = nil
    cursorHaloY = nil
    cursorHaloOffsetX = 0
    cursorHaloOffsetY = 0
    sceneParallaxX = 0
    sceneParallaxY = 0
end

local function resetRuntimeState()
    resetInteractionState()
    qualitySpikeHold = 0
    qualityScale = 1
    qualityScaleForCounts = 1
    lastBgTargetCount = 0
    lastStarTargetCount = 0
    lastStreakTargetCount = 0
    lastRocketTargetCount = 0
    resetParticleImpulses()
    openRippleTime = 0
    clearList(stardustTrail)
    State.frameSettings = nil
    State.menuIdleTime = 0
    State.simulationPaused = false
    State.linkGridSkipFrame = false
    State.lastDt = 0
    State.blockCustomPresetMarks = 0
end

local function getMenuStyleTable()
    if not Menu or not Menu.Style then
        return nil
    end

    local ok, style = pcall(Menu.Style)
    if ok and type(style) == "table" then
        return style
    end

    return nil
end

local function probeMenuStyleColor(styleName)
    if not Menu or not Menu.Style or not styleName then
        return nil
    end

    local ok, color = pcall(Menu.Style, styleName)
    local normalized = ok and normalizeColor(color)
    if normalized then
        return normalized
    end

    return nil
end

local function getMenuStyleColor(styleName, defaultColor)
    local aliases = {
        primary = {"primary", "accent", "highlight", "active", "text"},
        accent = {"accent", "primary", "highlight", "active", "text"},
        secondary = {"secondary", "accent", "primary", "highlight", "text"},
    }

    local probeList = aliases[styleName] or {styleName}
    for _, key in ipairs(probeList) do
        local direct = probeMenuStyleColor(key)
        if direct then
            return direct
        end
    end

    local styleTable = getMenuStyleTable()
    if styleTable then
        for _, key in ipairs(probeList) do
            local fromTable = normalizeColor(styleTable[key])
            if fromTable then
                return fromTable
            end
        end
    end

    return defaultColor
end

local function areColorsSimilar(colorA, colorB)
    if not colorA or not colorB then
        return true
    end

    local dr = colorA.r - colorB.r
    local dg = colorA.g - colorB.g
    local db = colorA.b - colorB.b
    local distanceSq = dr * dr + dg * dg + db * db

    return distanceSq < (32 * 32)
end

local function deriveSecondaryColor(primaryColor)
    local a = primaryColor.a or 255
    return makeColor(
        primaryColor.g * 0.58 + primaryColor.b * 0.42,
        primaryColor.b * 0.58 + primaryColor.r * 0.42,
        primaryColor.r * 0.58 + primaryColor.g * 0.42,
        a
    )
end

local function getThemeColors()
    local neutralThemeColor = makeColor(210, 225, 245, 210)
    local primaryColor = getMenuStyleColor("primary", neutralThemeColor)
    local secondaryColor = nil

    local styleTable = getMenuStyleTable()
    if styleTable then
        for _, key in ipairs(THEME_STYLE_KEYS) do
            local candidate = normalizeColor(styleTable[key])
            if candidate and not areColorsSimilar(candidate, primaryColor) then
                secondaryColor = candidate
                break
            end
        end
    end

    if not secondaryColor then
        local accentProbe = getMenuStyleColor("accent", nil)
        if accentProbe and not areColorsSimilar(accentProbe, primaryColor) then
            secondaryColor = accentProbe
        end
    end

    if not secondaryColor then
        secondaryColor = deriveSecondaryColor(primaryColor)
    end

    if Script.themeUseAccentOnly and WidgetGet(Script.themeUseAccentOnly, false) then
        secondaryColor = deriveSecondaryColor(primaryColor)
    elseif Script.themeMonochrome and WidgetGet(Script.themeMonochrome, false) then
        local gray = (primaryColor.r + primaryColor.g + primaryColor.b) / 3
        secondaryColor = makeColor(gray, gray, gray, primaryColor.a or 255)
    end

    return primaryColor, secondaryColor
end

local function gradientRectCompat(pos, size, color1, color2, isHorizontal)
    local endPos = Vec2(pos.x + size.x, pos.y + size.y)

    if Render and Render.Gradient then
        local topLeft = color1
        local topRight = color1
        local bottomLeft = color2
        local bottomRight = color2

        if isHorizontal then
            topLeft = color1
            topRight = color2
            bottomLeft = color1
            bottomRight = color2
        end

        local ok = pcall(Render.Gradient, pos, endPos, topLeft, topRight, bottomLeft, bottomRight)
        if ok then
            return true
        end

        ok = pcall(Render.Gradient, Render, pos, endPos, topLeft, topRight, bottomLeft, bottomRight)
        if ok then
            return true
        end
    end

    if Render and Render.FilledRect then
        Render.FilledRect(pos, endPos, color1, 0)
    end
    return false
end

local function applyIcon(widget, icon)
    if not widget or not icon then
        return
    end

    if widget.Icon then
        local ok = pcall(widget.Icon, widget, icon)
        if not ok then
            pcall(widget.Icon, icon)
        end
    end
end

local function getUILanguage()
    local langWidget = Menu and Menu.Find and Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    if langWidget and langWidget.Get then
        local ok, idx = pcall(langWidget.Get, langWidget)
        if ok and type(idx) == "number" and idx == 1 then
            return "ru"
        end
    end
    return "en"
end

local function L(en, ru)
    if getUILanguage() == "ru" and ru then
        return ru
    end
    return en
end

--#endregion

--#region Theme

local function RefreshThemeCache()
    local primary, secondary = getThemeColors()
    if not primary then
        primary = makeColor(210, 225, 245, 210)
    end
    if not secondary then
        secondary = deriveSecondaryColor(primary)
    end

    State.targetPrimary = primary
    State.targetSecondary = secondary
    State.primaryColor = primary
    State.secondaryColor = secondary

    if not State.displayPrimary then
        State.displayPrimary = primary
        State.displaySecondary = secondary
    end
end

local function GetCachedThemeColors()
    if not State.primaryColor or not State.secondaryColor then
        RefreshThemeCache()
    end

    if not State.primaryColor then
        State.primaryColor = makeColor(210, 225, 245, 210)
    end
    if not State.secondaryColor then
        State.secondaryColor = deriveSecondaryColor(State.primaryColor)
    end

    return State.primaryColor, State.secondaryColor
end

local function StepThemeColorLerp(dt)
    if not State.targetPrimary then
        RefreshThemeCache()
    end

    local targetPrimary = State.targetPrimary
    local targetSecondary = State.targetSecondary or deriveSecondaryColor(targetPrimary)

    if not State.displayPrimary then
        State.displayPrimary = targetPrimary
        State.displaySecondary = targetSecondary
        return
    end

    local t = clamp(dt * CONSTANTS.THEME_LERP_SPEED, 0, 1)
    State.displayPrimary = mixColors(State.displayPrimary, targetPrimary, t)
    State.displaySecondary = mixColors(State.displaySecondary, targetSecondary, t)
end

---@return Color, Color
local function GetDrawThemeColors()
    if State.displayPrimary and State.displaySecondary then
        return State.displayPrimary, State.displaySecondary
    end

    local primaryColor, secondaryColor = GetCachedThemeColors()
    if not primaryColor then
        primaryColor = makeColor(210, 225, 245, 210)
    end
    if not secondaryColor then
        secondaryColor = deriveSecondaryColor(primaryColor)
    end
    return primaryColor, secondaryColor
end

--#endregion

--#region Atmosphere

local function DrawSoftBloom(pos, radius, tintColor, alpha, intensity)
    if alpha <= 0 or radius <= 0.2 then
        return
    end

    intensity = intensity or 1
    radius = math.min(radius, 120)
    local warmCenter = mixColors(tintColor, makeColor(255, 255, 255, 255), 0.38)
    local outerColor = colorWithAlpha(tintColor, math.floor(alpha * 0.24 * intensity))
    local innerColor = colorWithAlpha(warmCenter, math.floor(alpha * 0.55 * intensity))

    if Render and Render.CircleGradient then
        Render.CircleGradient(pos, radius, outerColor, innerColor)
        if qualityScale >= 0.92 and intensity > 1.05 then
            Render.CircleGradient(pos, radius * 1.65, colorWithAlpha(tintColor, math.floor(alpha * 0.12 * intensity)), colorWithAlpha(tintColor, 0))
        end
    else
        Render.FilledCircle(pos, radius * 0.9, colorWithAlpha(tintColor, math.floor(alpha * 0.28 * intensity)), 12)
    end
end

local function DrawStarHalo(drawX, drawY, drawSize, coreColor, alpha, glintBoost)
    local haloAlpha = math.floor(alpha * (0.28 + (glintBoost or 0) * 0.18))
    if haloAlpha <= 0 then
        return
    end

    Render.FilledCircle(Vec2(drawX, drawY), drawSize * 1.85, makeColor(coreColor.r, coreColor.g, coreColor.b, haloAlpha), 12)

    if (glintBoost or 0) > 0.12 and Render and Render.CircleGradient then
        Render.CircleGradient(
            Vec2(drawX, drawY),
            drawSize * (3.2 + glintBoost * 2),
            colorWithAlpha(coreColor, math.floor(haloAlpha * 0.35)),
            colorWithAlpha(coreColor, 0)
        )
    end
end

local function pushStardustPoint(x, y)
    table.insert(stardustTrail, 1, {x = x, y = y, life = 1.0})
    while #stardustTrail > CONSTANTS.STARDUST_MAX_POINTS do
        table.remove(stardustTrail)
    end
end

local function updateStardustTrail(dt, cursorPos, frameCursorDeltaLen, cursorStardustEnabled)
    if not cursorStardustEnabled then
        if #stardustTrail > 0 then
            clearList(stardustTrail)
        end
        return
    end

    if cursorPos and frameCursorDeltaLen > 0.4 then
        pushStardustPoint(cursorPos.x, cursorPos.y)
    end

    for i = #stardustTrail, 1, -1 do
        stardustTrail[i].life = stardustTrail[i].life - dt / CONSTANTS.STARDUST_LIFE
        if stardustTrail[i].life <= 0 then
            table.remove(stardustTrail, i)
        end
    end
end

local function DrawWormholeOpen(width, height, primaryColor, secondaryColor, fadeInAlpha)
    if openRippleTime >= CONSTANTS.RIPPLE_DURATION then
        return
    end

    local t = openRippleTime / CONSTANTS.RIPPLE_DURATION
    local centerX = width * 0.5
    local centerY = height * 0.5
    local maxRadius = math.sqrt(centerX * centerX + centerY * centerY) * 1.05
    local ringCount = 4
    local segments = clamp(math.floor(40 + qualityScale * 12), 36, 56)

    for ring = 1, ringCount do
        local ringDelay = (ring - 1) * 0.10
        local ringT = clamp((t - ringDelay) / (1 - ringDelay * 0.82), 0, 1)
        if ringT <= 0 or ringT >= 1 then
            goto continue_wormhole_ring
        end

        local radius = maxRadius * ringT * (0.38 + ring * 0.16)
        local twist = time * (1.15 + ring * 0.28) + ring * 1.1
        local squash = 0.86 - ring * 0.035
        local prevX, prevY

        for step = 0, segments do
            local angle = (step / segments) * math.pi * 2 + twist * (1 - ringT * 0.65)
            local wobble = 1 + math.sin(angle * 3 + twist) * 0.05 * ringT
            local x = centerX + math.cos(angle) * radius * wobble
            local y = centerY + math.sin(angle) * radius * wobble * squash

            if prevX then
                local edgeFade = 1 - ringT
                local alpha = math.floor(edgeFade * (50 - ring * 9) * fadeInAlpha)
                if alpha > 1 then
                    local ringColor = mixColors(primaryColor, secondaryColor, 0.2 + ring * 0.18)
                    Render.Line(Vec2(prevX, prevY), Vec2(x, y), colorWithAlpha(ringColor, alpha), ring == 1 and 1.35 or 1.0)
                end
            end

            prevX = x
            prevY = y
        end

        ::continue_wormhole_ring::
    end

    local spiralArms = 3
    for arm = 1, spiralArms do
        local armPhase = (arm / spiralArms) * math.pi * 2 + time * 0.9
        local armT = clamp(t * 1.15 - (arm - 1) * 0.08, 0, 1)
        if armT > 0 and armT < 1 then
            local prevX, prevY
            local spiralSteps = 18
            for step = 0, spiralSteps do
                local spiralT = step / spiralSteps
                local radius = maxRadius * 0.12 + spiralT * maxRadius * 0.55 * armT
                local angle = armPhase + spiralT * math.pi * 1.6
                local x = centerX + math.cos(angle) * radius
                local y = centerY + math.sin(angle) * radius * 0.82

                if prevX then
                    local alpha = math.floor((1 - spiralT) * (1 - armT) * 36 * fadeInAlpha)
                    if alpha > 1 then
                        Render.Line(Vec2(prevX, prevY), Vec2(x, y), colorWithAlpha(secondaryColor, alpha), 0.9)
                    end
                end

                prevX = x
                prevY = y
            end
        end
    end

    if t < 0.35 and Render and Render.CircleGradient then
        local coreAlpha = math.floor((1 - t / 0.35) * 22 * fadeInAlpha)
        if coreAlpha > 0 then
            Render.CircleGradient(
                Vec2(centerX, centerY),
                maxRadius * 0.08 * (1 + t * 2),
                colorWithAlpha(mixColors(primaryColor, makeColor(255, 255, 255, 255), 0.35), coreAlpha),
                colorWithAlpha(primaryColor, 0)
            )
        end
    end
end

local function computeAccretionScene(width, height)
    local minDim = math.min(width, height)
    local centerX = width * 0.5 + sceneParallaxX * 0.22
    local centerY = height * 0.46 + sceneParallaxY * 0.18
    local hotspotAngle = time * 0.42
    local hotspotX = centerX + math.cos(hotspotAngle) * minDim * 0.31
    local hotspotY = centerY + math.sin(hotspotAngle) * minDim * 0.11
    local focalPhase = time * 0.38

    return {
        centerX = centerX,
        centerY = centerY,
        hotspotX = hotspotX,
        hotspotY = hotspotY,
        hotspotAngle = hotspotAngle,
        focalPhase = focalPhase,
        minDim = minDim,
    }
end

local function DrawHorizonGrid(width, height, primaryColor, secondaryColor, fadeInAlpha)
    local horizonY = height * 0.76
    local vanishX = width * 0.5
    local vanishY = horizonY - height * 0.14
    local gridAlpha = math.floor(32 * fadeInAlpha)
    local lineColor = colorWithAlpha(mixColors(primaryColor, secondaryColor, 0.45), gridAlpha)
    local vertCount = clamp(math.floor(12 + qualityScale * 4), 10, 18)

    for i = 0, vertCount do
        local t = i / vertCount
        local bottomX = t * width
        Render.Line(Vec2(bottomX, height), Vec2(vanishX, vanishY), lineColor, 1)
    end

    local rowCount = clamp(math.floor(8 + qualityScale * 3), 7, 12)
    for row = 0, rowCount do
        local depth = row / rowCount
        local y = lerp(horizonY, height, depth * depth)
        local spread = depth * width * 0.52
        Render.Line(Vec2(vanishX - spread, y), Vec2(vanishX + spread, y), lineColor, 1)
    end
end

local function DrawDeepSpaceGlow(width, height, primaryColor, secondaryColor, fadeInAlpha)
    local centerX = width * 0.5 + sceneParallaxX * 0.35
    local centerY = height * 0.42 + sceneParallaxY * 0.25
    local radius = math.max(width, height) * 0.55
    local pulse = 0.9 + math.sin(time * 0.45) * 0.1
    local alpha = math.floor(12 * fadeInAlpha * pulse)

    if alpha <= 0 then
        return
    end

    if Render and Render.CircleGradient then
        local coreTint = mixColors(primaryColor, secondaryColor, 0.35)
        Render.CircleGradient(
            Vec2(centerX, centerY),
            radius,
            colorWithAlpha(coreTint, alpha),
            colorWithAlpha(primaryColor, 0)
        )

        local lobeX = centerX + sceneParallaxX * 0.18 + math.sin(time * 0.22) * width * 0.04
        local lobeY = centerY + sceneParallaxY * 0.12 + math.cos(time * 0.19) * height * 0.03
        local lobeAlpha = math.floor(alpha * 0.72)
        if lobeAlpha > 0 then
            Render.CircleGradient(
                Vec2(lobeX, lobeY),
                radius * 0.42,
                colorWithAlpha(mixColors(secondaryColor, makeColor(255, 255, 255, 255), 0.15), lobeAlpha),
                colorWithAlpha(secondaryColor, 0)
            )
        end
    end
end

local function DrawAccretionRing(width, height, primaryColor, secondaryColor, fadeInAlpha)
    if qualityScale < 0.72 then
        return
    end

    local scene = computeAccretionScene(width, height)
    local centerX = scene.centerX
    local centerY = scene.centerY
    local hotspotX = scene.hotspotX
    local hotspotY = scene.hotspotY
    local hotspotAngle = scene.hotspotAngle
    local minDim = scene.minDim
    local segments = CONSTANTS.ACCRETION_RING_SEGMENTS

    local innerShadowAlpha = math.floor(18 * fadeInAlpha * (0.85 + math.sin(time * 0.55) * 0.15))
    if innerShadowAlpha > 0 and Render and Render.CircleGradient then
        Render.CircleGradient(
            Vec2(centerX, centerY),
            minDim * 0.18,
            colorWithAlpha(makeColor(0, 0, 0, 255), innerShadowAlpha),
            colorWithAlpha(makeColor(0, 0, 0, 255), 0)
        )
    end

    for ring = 1, 2 do
        local radiusX = minDim * (0.26 + ring * 0.07)
        local radiusY = radiusX * (0.34 + ring * 0.06)
        local rotation = time * (0.11 + ring * 0.035) + ring * 1.35
        local tilt = 0.48 + ring * 0.12
        local prevX, prevY, prevAngle

        for step = 0, segments do
            local angle = (step / segments) * math.pi * 2
            local ex = math.cos(angle) * radiusX
            local ey = math.sin(angle) * radiusY
            local cosR = math.cos(rotation)
            local sinR = math.sin(rotation)
            local x = centerX + ex * cosR - ey * sinR * tilt
            local y = centerY + ex * sinR + ey * cosR

            if prevX then
                local segAngle = (prevAngle + angle) * 0.5
                local doppler = 0.5 + 0.5 * math.cos(segAngle - hotspotAngle)
                local edgePulse = 0.65 + math.sin(time * 1.25 + angle * 4 + ring * 0.8) * 0.35
                local alpha = math.floor((20 - ring * 5) * fadeInAlpha * edgePulse * (0.55 + doppler * 0.65))
                if alpha > 1 then
                    local coolMix = 0.15 + doppler * 0.45
                    local ringColor = mixColors(
                        mixColors(primaryColor, makeColor(170, 210, 255, 255), coolMix),
                        secondaryColor,
                        0.2 + ring * 0.25
                    )
                    Render.Line(
                        Vec2(prevX, prevY),
                        Vec2(x, y),
                        colorWithAlpha(ringColor, alpha),
                        ring == 1 and 1.15 or 0.85
                    )
                end
            end

            prevX = x
            prevY = y
            prevAngle = angle
        end
    end

    local hotspotPulse = 0.8 + math.sin(time * 2.4) * 0.2
    local hotspotAlpha = math.floor(28 * fadeInAlpha * hotspotPulse)
    if hotspotAlpha > 0 then
        Render.FilledCircle(Vec2(hotspotX, hotspotY), 2.4, colorWithAlpha(makeColor(255, 255, 255, 255), hotspotAlpha), 10)
        Render.FilledCircle(Vec2(hotspotX, hotspotY), 5.5, colorWithAlpha(primaryColor, math.floor(hotspotAlpha * 0.45)), 12)
        if Render and Render.CircleGradient then
            Render.CircleGradient(
                Vec2(hotspotX, hotspotY),
                minDim * 0.07,
                colorWithAlpha(mixColors(primaryColor, makeColor(255, 240, 220, 255), 0.35), math.floor(hotspotAlpha * 0.38)),
                colorWithAlpha(primaryColor, 0)
            )
        end
    end
end

local GRAVITY_FILAMENT_DEFS = {
    {ax = 0.04, ay = 0.18, bx = 0.96, by = 0.62, bend = 0.22, phase = 0.0},
    {ax = 0.08, ay = 0.72, bx = 0.92, by = 0.28, bend = 0.18, phase = 1.7},
    {ax = 0.12, ay = 0.42, bx = 0.88, by = 0.88, bend = 0.15, phase = 3.1},
    {ax = 0.02, ay = 0.55, bx = 0.78, by = 0.12, bend = 0.12, phase = 4.6},
    {ax = 0.22, ay = 0.08, bx = 0.98, by = 0.48, bend = 0.14, phase = 5.9},
    {ax = 0.18, ay = 0.92, bx = 0.82, by = 0.38, bend = 0.16, phase = 2.4},
}

local function DrawGravityFilaments(width, height, primaryColor, secondaryColor, fadeInAlpha)
    if qualityScale < 0.75 then
        return
    end

    local scene = computeAccretionScene(width, height)
    local focalX = scene.centerX
    local focalY = scene.centerY
    local hotspotX = scene.hotspotX
    local hotspotY = scene.hotspotY
    local focalPhase = scene.focalPhase
    local pullScale = scene.minDim * 0.11
    local segments = CONSTANTS.GRAVITY_FILAMENT_SEGMENTS
    local filamentCount = math.min(CONSTANTS.GRAVITY_FILAMENT_COUNT, #GRAVITY_FILAMENT_DEFS)
    local hotspotBlend = 0.42 + math.sin(focalPhase) * 0.12
    local attractX = lerp(focalX, hotspotX, hotspotBlend)
    local attractY = lerp(focalY, hotspotY, hotspotBlend)

    for i = 1, filamentCount do
        local def = GRAVITY_FILAMENT_DEFS[i]
        local prevX, prevY

        for step = 0, segments do
            local t = step / segments
            local baseX = lerp(def.ax * width, def.bx * width, t)
            local baseY = lerp(def.ay * height, def.by * height, t)
            local pullWave = math.sin(t * math.pi) * def.bend
            local dx = attractX - baseX
            local dy = attractY - baseY
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < 0.001 then
                dist = 0.001
            end
            local syncWave = math.sin(focalPhase + t * 4.2 + def.phase) * 7
            local wave = math.sin(time * 0.38 + t * 5.5 + def.phase) * 6 + syncWave * 0.55
            local hotspotPull = 1 + 0.35 * math.sin(focalPhase * 1.4 + def.phase)
            local x = baseX + (dx / dist) * pullScale * pullWave * hotspotPull + wave
            local y = baseY + (dy / dist) * pullScale * pullWave * 0.65 * hotspotPull + wave * 0.45

            if prevX then
                local edgeFade = 1 - math.abs(t - 0.5) * 0.55
                local pulse = 0.72 + math.sin(time * 0.55 + def.phase + t * 3 + focalPhase * 0.6) * 0.28
                local alpha = math.floor(16 * fadeInAlpha * edgeFade * pulse)
                if alpha > 1 then
                    local lineColor = mixColors(secondaryColor, primaryColor, t)
                    Render.Line(Vec2(prevX, prevY), Vec2(x, y), colorWithAlpha(lineColor, alpha), 1)
                end
            end

            prevX = x
            prevY = y
        end
    end
end

local function DrawCursorStardust(primaryColor, secondaryColor, fadeInAlpha)
    local trailCount = #stardustTrail
    if trailCount == 0 then
        return
    end

    for i, point in ipairs(stardustTrail) do
        local alpha = math.floor(point.life * 125 * fadeInAlpha)
        if alpha > 0 then
            local radius = 1.1 + (1 - point.life) * 2.2
            local mixT = i / math.max(trailCount, 1)
            local dotColor = mixColors(primaryColor, secondaryColor, mixT)
            Render.FilledCircle(Vec2(point.x, point.y), radius, colorWithAlpha(dotColor, alpha), 8)
        end
    end
end

local function DrawStarDiffractionRays(drawX, drawY, drawSize, alpha, rayAngle, glintBoost)
    local rayCount = CONSTANTS.STAR_RAY_COUNT
    local rayLength = drawSize * (4.2 + (glintBoost or 0) * 3.5)
    local rayAlpha = math.floor(alpha * (0.42 + (glintBoost or 0) * 0.35))
    if rayAlpha <= 0 then
        return
    end

    for r = 0, rayCount - 1 do
        local angle = rayAngle + (r / rayCount) * math.pi * 2
        local lengthMul = 0.75 + ((r % 2 == 0) and 0.25 or 0.1) + (glintBoost or 0) * 0.2
        local x1 = drawX + math.cos(angle) * drawSize
        local y1 = drawY + math.sin(angle) * drawSize
        local x2 = drawX + math.cos(angle) * rayLength * lengthMul
        local y2 = drawY + math.sin(angle) * rayLength * lengthMul
        local widthNow = (r % 2 == 0) and 1.0 or 0.65
        Render.Line(Vec2(x1, y1), Vec2(x2, y2), Color(255, 255, 255, rayAlpha), widthNow)
    end
end

local function DrawShootingStar(star, toRenderX, toRenderY, fadeInAlpha, primaryColor, secondaryColor)
    local simX = star.startX + (star.endX - star.startX) * star.progress
    local simY = star.startY + (star.endY - star.startY) * star.progress
    local x = toRenderX(simX)
    local y = toRenderY(simY)

    if star.burstLife and star.burstLife > 0 then
        local burstT = star.burstLife / CONSTANTS.SHOOTING_STAR_BURST_DURATION
        local burstAlpha = math.floor(200 * burstT * fadeInAlpha)
        local burstRadius = star.size * (3 + (1 - burstT) * 10)
        if burstAlpha > 0 then
            if Render and Render.CircleGradient then
                Render.CircleGradient(
                    Vec2(x, y),
                    burstRadius * 2.2,
                    colorWithAlpha(mixColors(secondaryColor, makeColor(255, 220, 180, 255), 0.4), math.floor(burstAlpha * 0.45)),
                    colorWithAlpha(primaryColor, 0)
                )
            end
            Render.FilledCircle(Vec2(x, y), burstRadius, colorWithAlpha(makeColor(255, 245, 220, 255), burstAlpha), 14)
            for burstRay = 0, 5 do
                local angle = burstRay / 6 * math.pi * 2 + star.progress * 4
                local len = burstRadius * (1.2 + burstT)
                Render.Line(
                    Vec2(x, y),
                    Vec2(x + math.cos(angle) * len, y + math.sin(angle) * len),
                    colorWithAlpha(secondaryColor, math.floor(burstAlpha * 0.55)),
                    0.8
                )
            end
        end
        return
    end

    local tailCount = #star.tail
    if tailCount > 1 then
        for i = 2, tailCount do
            local t = i / tailCount
            local prev = star.tail[i - 1]
            local curr = star.tail[i]
            local px = toRenderX(prev.x)
            local py = toRenderY(prev.y)
            local cx = toRenderX(curr.x)
            local cy = toRenderY(curr.y)
            local tailAlpha = math.floor(t * 210 * fadeInAlpha)
            if tailAlpha > 1 then
                local widthNow = math.max(0.5, star.size * t * 1.5)
                local headColor = makeColor(210, 230, 255, tailAlpha)
                local tailColor = makeColor(255, 170, 110, math.floor(tailAlpha * 0.85))
                local lineColor = mixColors(headColor, tailColor, 1 - t, tailAlpha)
                Render.Line(Vec2(px, py), Vec2(cx, cy), lineColor, widthNow)
            end
        end
    end

    Render.FilledCircle(Vec2(x, y), star.size * 3.2, Color(200, 220, 255, math.floor(65 * fadeInAlpha)), 14)
    DrawSoftBloom(
        Vec2(x, y),
        star.size * 2.8,
        mixColors(makeColor(220, 235, 255, 255), secondaryColor, 0.25),
        math.floor(95 * fadeInAlpha),
        0.85
    )
    Render.FilledCircle(Vec2(x, y), star.size, Color(255, 255, 255, math.floor(255 * fadeInAlpha)), 8)
    Render.FilledCircle(Vec2(x, y), math.max(1, star.size * 0.45), Color(230, 240, 255, math.floor(180 * fadeInAlpha)), 6)
end

local function DrawAmbientStreak(streak, toRenderX, toRenderY, fadeInAlpha, primaryColor, secondaryColor, streakVisibility, sway)
    local streakType = streak.streakType or 2
    local simSx = streak.x + sway * 8
    local simSy = streak.y + sway * 4
    local simEx = simSx + math.cos(streak.angle) * streak.length
    local simEy = simSy + math.sin(streak.angle) * streak.length
    local sx = toRenderX(simSx)
    local sy = toRenderY(simSy)
    local ex = toRenderX(simEx)
    local ey = toRenderY(simEy)
    local alpha = math.floor(streak.alpha * streakVisibility)
    if alpha <= 2 then
        return
    end

    if streakType == 1 then
        local bandAlpha = math.floor(alpha * 0.55)
        local midX = (sx + ex) * 0.5
        local midY = (sy + ey) * 0.5
        if Render and Render.CircleGradient and qualityScale >= CONSTANTS.GLOW_QUALITY_THRESHOLD then
            Render.CircleGradient(
                Vec2(midX, midY),
                math.min(streak.width * 7, 36),
                colorWithAlpha(mixColors(primaryColor, secondaryColor, 0.35), bandAlpha),
                colorWithAlpha(primaryColor, 0)
            )
        end
        Render.Line(Vec2(sx, sy), Vec2(ex, ey), colorWithAlpha(mixColors(primaryColor, secondaryColor, 0.5), alpha), streak.width)
        Render.Line(
            Vec2(sx + math.cos(streak.angle) * 10, sy + math.sin(streak.angle) * 10),
            Vec2(ex, ey),
            colorWithAlpha(secondaryColor, math.floor(alpha * 0.35)),
            math.max(1, streak.width - 1)
        )
    else
        local headGlow = math.floor(alpha * 0.45)
        Render.FilledCircle(Vec2(sx, sy), math.max(1.5, streak.width * 2), colorWithAlpha(secondaryColor, headGlow), 8)
        Render.Line(Vec2(sx, sy), Vec2(ex, ey), colorWithAlpha(primaryColor, alpha), streak.width)
        Render.Line(
            Vec2(sx + math.cos(streak.angle) * 4, sy + math.sin(streak.angle) * 4),
            Vec2(ex, ey),
            colorWithAlpha(makeColor(255, 220, 180, alpha), math.floor(alpha * 0.5)),
            math.max(1, streak.width)
        )
    end
end

local function DrawFlyingRocket(rocket, toRenderX, toRenderY, fadeInAlpha, primaryColor, secondaryColor)
    local angle = rocket.angle + math.sin(time * 2.2 + (rocket.wobblePhase or 0)) * (rocket.wobble or 0) * 0.14
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)
    local nx = -sinA
    local ny = cosA
    local len = rocket.length
    local halfW = rocket.width * 0.5
    local x = toRenderX(rocket.x)
    local y = toRenderY(rocket.y)
    local alpha = math.floor((rocket.alpha or 180) * fadeInAlpha * (0.8 + qualityScale * 0.2))
    if alpha <= 2 then
        return
    end

    -- Fully theme-synced palette (primary shaft, secondary base, light tip).
    local tint = rocket.tint or 0.3
    local bodyTint = mixColors(primaryColor, secondaryColor, tint * 0.55)
    local tipTint = mixColors(primaryColor, makeColor(255, 255, 255, 255), 0.35)
    local twinTint = mixColors(secondaryColor, primaryColor, 0.35)
    local bodyColor = colorWithAlpha(bodyTint, alpha)
    local tipFill = colorWithAlpha(tipTint, math.min(255, alpha + 25))
    local twinFill = colorWithAlpha(twinTint, math.floor(alpha * 0.95))
    local highlight = colorWithAlpha(
        mixColors(primaryColor, makeColor(255, 255, 255, 255), 0.65),
        math.floor(alpha * 0.5)
    )
    local trailColor = mixColors(secondaryColor, primaryColor, 0.4)

    -- Tip (glans) toward flight direction, balls at the rear.
    local tipX = x + cosA * len * 0.52
    local tipY = y + sinA * len * 0.52
    local shaftEndX = x + cosA * len * 0.28
    local shaftEndY = y + sinA * len * 0.28
    local baseX = x - cosA * len * 0.42
    local baseY = y - sinA * len * 0.42

    -- Twin spheres at the base (slightly behind and apart).
    local twinDist = halfW * 1.55
    local twinR = halfW * 1.15
    local twinPush = halfW * 0.35
    local twinCX = baseX - cosA * twinPush
    local twinCY = baseY - sinA * twinPush
    Render.FilledCircle(Vec2(twinCX + nx * twinDist, twinCY + ny * twinDist), twinR, twinFill, 14)
    Render.FilledCircle(Vec2(twinCX - nx * twinDist, twinCY - ny * twinDist), twinR, twinFill, 14)
    Render.FilledCircle(Vec2(twinCX + nx * twinDist * 0.55, twinCY + ny * twinDist * 0.55), twinR * 0.35, highlight, 10)
    Render.FilledCircle(Vec2(twinCX - nx * twinDist * 0.55, twinCY - ny * twinDist * 0.55), twinR * 0.35, highlight, 10)

    -- Shaft: thicker near base, slightly tapered toward tip.
    local segments = CONSTANTS.FLYING_ROCKET_SEGMENTS
    for step = 0, segments - 1 do
        local t = step / math.max(segments - 1, 1)
        local px = lerp(baseX, shaftEndX, t)
        local py = lerp(baseY, shaftEndY, t)
        local radius = halfW * (1.15 - t * 0.22)
        Render.FilledCircle(Vec2(px, py), radius, bodyColor, 12)
    end
    Render.FilledCircle(Vec2(lerp(baseX, shaftEndX, 0.35), lerp(baseY, shaftEndY, 0.35)), halfW * 0.35, highlight, 8)

    -- Rounded mushroom tip.
    local tipR = halfW * 1.35
    Render.FilledCircle(Vec2(tipX, tipY), tipR, tipFill, 14)
    Render.FilledCircle(Vec2(tipX - cosA * tipR * 0.15, tipY - sinA * tipR * 0.15), tipR * 0.72, bodyColor, 12)
    Render.FilledCircle(Vec2(tipX + nx * tipR * 0.25, tipY + ny * tipR * 0.25), tipR * 0.28, highlight, 8)

    -- Tiny motion puff behind the balls.
    local trailAlpha = math.floor(alpha * 0.22)
    if trailAlpha > 1 then
        local trailX = twinCX - cosA * halfW * 2.4
        local trailY = twinCY - sinA * halfW * 2.4
        Render.FilledCircle(Vec2(trailX, trailY), halfW * 0.55, colorWithAlpha(trailColor, trailAlpha), 8)
        Render.FilledCircle(
            Vec2(trailX - cosA * halfW * 1.5, trailY - sinA * halfW * 1.5),
            halfW * 0.32,
            colorWithAlpha(trailColor, math.floor(trailAlpha * 0.55)),
            8
        )
    end
end

--#endregion

--#region Pools

local function ClearShootingStarPool()
    deactivatePoolObjects(shootingStarPool)
    for i, star in ipairs(shootingStarPool) do
        if star.tail then
            clearList(star.tail)
        end
    end
end

local function SyncEffectTogglePools(settings)
    settings = settings or State.frameSettings
    if not settings and GatherFrameSettings then
        settings = GatherFrameSettings()
    end
    if not settings then
        return
    end

    local starsEnabled = settings.stars
    if State.starsWasEnabled == true and not starsEnabled then
        deactivatePoolObjects(starPool)
        clearList(starActive)
    end
    State.starsWasEnabled = starsEnabled

    local shootingEnabled = settings.shootingStars
    if State.shootingStarsWasEnabled == true and not shootingEnabled then
        ClearShootingStarPool()
    end
    State.shootingStarsWasEnabled = shootingEnabled

    local rocketsEnabled = settings.flyingRockets
    if State.flyingRocketsWasEnabled == true and not rocketsEnabled then
        deactivatePoolObjects(flyingRocketPool)
        clearList(flyingRocketActive)
        lastRocketTargetCount = 0
    end
    State.flyingRocketsWasEnabled = rocketsEnabled
end

IsCustomPresetMarkBlocked = function()
    if State.applyingPreset then
        return true
    end
    if (State.blockCustomPresetMarks or 0) > 0 then
        return true
    end
    return false
end

ArmCustomPresetMarkBlock = function()
    State.blockCustomPresetMarks = CONSTANTS.PRESET_CUSTOM_MARK_BLOCK_FRAMES
end

local function TickCustomPresetMarkBlock()
    if (State.blockCustomPresetMarks or 0) <= 0 then
        return
    end
    State.blockCustomPresetMarks = State.blockCustomPresetMarks - 1
end

local function CaptureRocketSoloSnapshot()
    local snapshot = {
        switches = {},
        bgParticleCount = WidgetGet(Script.bgParticleCount, 100),
    }
    for i = 1, #ROCKET_SOLO_SWITCH_KEYS do
        local key = ROCKET_SOLO_SWITCH_KEYS[i]
        snapshot.switches[key] = WidgetGet(Script[key], false)
    end
    return snapshot
end

local function ApplyRocketSoloMute()
    State.applyingPreset = true
    for i = 1, #ROCKET_SOLO_SWITCH_KEYS do
        WidgetSet(Script[ROCKET_SOLO_SWITCH_KEYS[i]], false)
    end
    -- Particle field has no master off-switch; mute by zeroing count while solo.
    WidgetSet(Script.bgParticleCount, 20)
    State.applyingPreset = false
    ArmCustomPresetMarkBlock()
end

local function RestoreRocketSoloSnapshot(snapshot)
    if not snapshot then
        return
    end

    State.applyingPreset = true
    if snapshot.switches then
        for key, value in pairs(snapshot.switches) do
            WidgetSet(Script[key], value)
        end
    end
    if snapshot.bgParticleCount ~= nil then
        WidgetSet(Script.bgParticleCount, snapshot.bgParticleCount)
    end
    State.applyingPreset = false
    ArmCustomPresetMarkBlock()
end

local function EnterFlyingRocketSoloMode()
    if State.rocketSoloActive then
        return
    end

    State.rocketSoloSnapshot = CaptureRocketSoloSnapshot()
    ApplyRocketSoloMute()
    State.rocketSoloActive = true
end

local function ExitFlyingRocketSoloMode(restore)
    if not State.rocketSoloActive then
        State.rocketSoloSnapshot = nil
        return
    end

    local snapshot = State.rocketSoloSnapshot
    State.rocketSoloActive = false
    State.rocketSoloSnapshot = nil

    if restore then
        RestoreRocketSoloSnapshot(snapshot)
    end
end

local function OnFlyingRocketsToggled()
    local enabled = WidgetGet(Script.flyingRockets, false)
    if enabled then
        EnterFlyingRocketSoloMode()
    else
        ExitFlyingRocketSoloMode(true)
    end

    if UpdateMenuControls then
        UpdateMenuControls()
    end
end

local function ApplyQualityPreset(presetIndex)
    local preset = QUALITY_PRESETS[presetIndex]
    if not preset or State.applyingPreset then
        return
    end

    ExitFlyingRocketSoloMode(false)

    State.applyingPreset = true
    for key, value in pairs(preset) do
        WidgetSet(Script[key], value)
    end
    WidgetSet(Script.flyingRockets, false)
    State.applyingPreset = false
    State.lastQualityPreset = presetIndex
    State.lastNamedPreset = presetIndex
    ConfigWriteInt("last_named_preset", presetIndex)
    ConfigWriteInt("quality_preset", presetIndex)
    ArmCustomPresetMarkBlock()
end

local function MarkCustomPreset()
    if IsCustomPresetMarkBlocked() then
        return
    end

    local current = roundToInt(WidgetGet(Script.qualityPreset, CONSTANTS.CUSTOM_PRESET_INDEX))
    if current ~= CONSTANTS.CUSTOM_PRESET_INDEX then
        State.applyingPreset = true
        WidgetSet(Script.qualityPreset, CONSTANTS.CUSTOM_PRESET_INDEX)
        State.applyingPreset = false
    end

    State.lastQualityPreset = CONSTANTS.CUSTOM_PRESET_INDEX
    ConfigWriteInt("quality_preset", CONSTANTS.CUSTOM_PRESET_INDEX)
end

local function SaveWidgetConfigValue(key)
    local widget = Script[key]
    if not widget or not widget.Get then
        return
    end

    local value = WidgetGet(widget, nil)
    if value == nil then
        return
    end

    if type(value) == "boolean" then
        ConfigWriteInt(key, value and 1 or 0)
    elseif type(value) == "number" then
        if math.floor(value) == value then
            ConfigWriteInt(key, value)
        else
            ConfigWriteFloat(key, value)
        end
    end
end

local function LoadWidgetConfigValue(key)
    local widget = Script[key]
    if not widget then
        return
    end

    local floatDefault = WidgetGet(widget, 0)
    local intVal = ConfigReadInt(key, -999999)
    if intVal ~= -999999 then
        WidgetSet(widget, intVal)
        return
    end

    local floatVal = ConfigReadFloat(key, -999999)
    if floatVal ~= -999999 then
        WidgetSet(widget, floatVal)
        return
    end

    WidgetSet(widget, floatDefault)
end

local function SaveCustomPresetValues()
    for i = 1, #PRESET_WIDGET_KEYS do
        SaveWidgetConfigValue(PRESET_WIDGET_KEYS[i])
    end
end

local function LoadCustomPresetValues()
    for i = 1, #PRESET_WIDGET_KEYS do
        LoadWidgetConfigValue(PRESET_WIDGET_KEYS[i])
    end
end

local function LoadConfigProfile()
    if not Config then
        return
    end

    State.applyingPreset = true

    for i = 1, #CONFIG_BOOL_KEYS do
        local key = CONFIG_BOOL_KEYS[i]
        local stored = ConfigReadInt(key, -1)
        if stored >= 0 and Script[key] then
            WidgetSet(Script[key], stored == 1)
        end
    end

    local idleStored = ConfigReadInt("idleThreshold", -1)
    if idleStored >= CONSTANTS.IDLE_THRESHOLD_MIN and Script.idleThreshold then
        WidgetSet(Script.idleThreshold, idleStored)
    end

    State.lastNamedPreset = clamp(
        ConfigReadInt("last_named_preset", State.lastNamedPreset),
        1,
        CONSTANTS.BUILTIN_PRESET_COUNT
    )

    local preset = ConfigReadInt("quality_preset", -1)
    if preset >= 1 and preset <= CONSTANTS.BUILTIN_PRESET_COUNT then
        WidgetSet(Script.qualityPreset, preset)
        ApplyQualityPreset(preset)
    elseif preset == CONSTANTS.CUSTOM_PRESET_INDEX then
        WidgetSet(Script.qualityPreset, CONSTANTS.CUSTOM_PRESET_INDEX)
        LoadCustomPresetValues()
        State.lastQualityPreset = CONSTANTS.CUSTOM_PRESET_INDEX
    end

    State.applyingPreset = false
    if WidgetGet(Script.flyingRockets, false) then
        EnterFlyingRocketSoloMode()
    end
    Log("info", "Config profile loaded")
end

local function MaybeApplyQualityPreset()
    if not Script.qualityPreset or not Script.qualityPreset.Get then
        return
    end

    local presetIndex = clamp(roundToInt(WidgetGet(Script.qualityPreset, 3)), 1, CONSTANTS.CUSTOM_PRESET_INDEX)
    if presetIndex == CONSTANTS.CUSTOM_PRESET_INDEX then
        if State.lastQualityPreset ~= CONSTANTS.CUSTOM_PRESET_INDEX then
            State.lastQualityPreset = CONSTANTS.CUSTOM_PRESET_INDEX
        end
        return
    end

    if State.lastQualityPreset ~= presetIndex then
        ApplyQualityPreset(presetIndex)
    end
end

local function ResetToNamedPreset()
    local presetIndex = clamp(State.lastNamedPreset or 3, 1, CONSTANTS.BUILTIN_PRESET_COUNT)
    State.applyingPreset = true
    WidgetSet(Script.qualityPreset, presetIndex)
    State.applyingPreset = false
    ApplyQualityPreset(presetIndex)
    SaveCustomPresetValues()
    ArmCustomPresetMarkBlock()
    if UpdateMenuControls then
        UpdateMenuControls()
    end
    Log("info", "Reset to preset " .. presetIndex)
end

local function ClearSpatialGrid(grid)
    for key in pairs(grid) do
        grid[key] = nil
    end
end

local function SpatialGridKey(cellX, cellY)
    return cellX .. ":" .. cellY
end

local function BuildParticleSpatialGrid(particles, cellSize)
    ClearSpatialGrid(linkSpatialGrid)
    local invCellSize = 1 / math.max(cellSize, 1)

    for index, particle in ipairs(particles) do
        local x = particle.drawX or particle.x
        local y = particle.drawY or particle.y
        local cellX = math.floor(x * invCellSize)
        local cellY = math.floor(y * invCellSize)
        local key = SpatialGridKey(cellX, cellY)
        local bucket = linkSpatialGrid[key]
        if not bucket then
            bucket = {}
            linkSpatialGrid[key] = bucket
        end
        bucket[#bucket + 1] = {particle = particle, index = index}
    end
end

local function DrawParticleLinks(particles, c1, c2, connectionDist, connectionDistSq, maxConnections, linkBaseAlpha, linkWidth, coloredLinks, fadeInAlpha, nodePhase, cursorPos, enablePulse)
    if #particles < 2 then
        return
    end

    BuildParticleSpatialGrid(particles, connectionDist)
    local invCellSize = 1 / math.max(connectionDist, 1)
    local cursorBoostRadius = connectionDist * 1.35
    local cursorBoostRadiusSq = cursorBoostRadius * cursorBoostRadius
    local pulseStrength = enablePulse and 1 or 0

    for i, p1 in ipairs(particles) do
        local connections = 0
        local x1 = p1.drawX or p1.x
        local y1 = p1.drawY or p1.y
        local cellX = math.floor(x1 * invCellSize)
        local cellY = math.floor(y1 * invCellSize)

        for offsetX = -1, 1 do
            if connections >= maxConnections then
                break
            end

            for offsetY = -1, 1 do
                if connections >= maxConnections then
                    break
                end

                local bucket = linkSpatialGrid[SpatialGridKey(cellX + offsetX, cellY + offsetY)]
                if bucket then
                    for _, entry in ipairs(bucket) do
                        if connections >= maxConnections then
                            break
                        end

                        local j = entry.index
                        if j > i then
                            local p2 = entry.particle
                            local x2 = p2.drawX or p2.x
                            local y2 = p2.drawY or p2.y
                            local dx = x2 - x1
                            local dy = y2 - y1
                            local distSq = dx * dx + dy * dy

                            if distSq < connectionDistSq then
                                local distT = 1 - (distSq / connectionDistSq)
                                local alpha = math.floor(distT * linkBaseAlpha * fadeInAlpha)
                                if alpha > 0 then
                                    local midX = (x1 + x2) * 0.5
                                    local midY = (y1 + y2) * 0.5

                                    if pulseStrength > 0 then
                                        local ambientPulse = 0.72 + 0.28 * math.sin(time * 2.4 + (midX + midY) * 0.008 + nodePhase * 0.1)
                                        local travelPhase = (time * 1.8 + i * 0.37 + j * 0.19) % 1
                                        local travelBoost = 1 + 0.45 * math.sin(travelPhase * math.pi * 2)
                                        alpha = math.floor(alpha * ambientPulse * travelBoost)
                                    end

                                    if cursorPos then
                                        local cdx = midX - cursorPos.x
                                        local cdy = midY - cursorPos.y
                                        local cdistSq = cdx * cdx + cdy * cdy
                                        if cdistSq < cursorBoostRadiusSq then
                                            local proximity = 1 - (cdistSq / cursorBoostRadiusSq)
                                            alpha = math.floor(alpha * (1 + 0.65 * proximity))
                                        end
                                    end

                                    if alpha <= 0 then
                                        goto continue_link
                                    end

                                    local isConstellationLink = ((i * 31 + j * 17 + nodePhase) % 97 == 0)
                                    if isConstellationLink then
                                        alpha = math.floor(alpha * 1.7)
                                    end

                                    local lineWidthNow = isConstellationLink and (linkWidth + 0.8) or linkWidth
                                    if coloredLinks then
                                        local p1Color = p1.colorIdx == 1 and c1 or c2
                                        local p2Color = p2.colorIdx == 1 and c1 or c2
                                        local lineColor = Color(
                                            math.floor((p1Color.r + p2Color.r) * 0.5),
                                            math.floor((p1Color.g + p2Color.g) * 0.5),
                                            math.floor((p1Color.b + p2Color.b) * 0.5),
                                            alpha
                                        )
                                        Render.Line(Vec2(x1, y1), Vec2(x2, y2), lineColor, lineWidthNow)
                                    else
                                        Render.Line(Vec2(x1, y1), Vec2(x2, y2), Color(255, 255, 255, alpha), lineWidthNow)
                                    end

                                    if isConstellationLink then
                                        local nodeAlpha = math.floor(alpha * 0.8)
                                        Render.FilledCircle(Vec2(x1, y1), 1.8, colorWithAlpha(c1, nodeAlpha), 12)
                                        Render.FilledCircle(Vec2(x2, y2), 1.8, colorWithAlpha(c2, nodeAlpha), 12)
                                    end
                                end
                                ::continue_link::
                                connections = connections + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

--#endregion

--#region Menu

local Icons = {
    tab = "\u{f76c}",              -- cloud-moon (cosmic tab)
    enable = "\u{f00c}",            -- check
    quality = "\u{f3fd}",           -- tachometer-alt-average
    fadeIn = "\u{f358}",            -- fill-drip
    blur = "\u{f56c}",              -- low-vision
    blurIntensity = "\u{f1de}",     -- sliders-h
    colorWash = "\u{f53f}",         -- palette
    vignette = "\u{f111}",          -- circle (dark edges)
    hudCorners = "\u{f5cb}",        -- border-all
    streaks = "\u{f76d}",           -- meteor
    streakCount = "\u{f0cb}",       -- list
    parallax = "\u{f0b2}",          -- arrows-alt
    parallaxStrength = "\u{f065}",  -- expand-arrows-alt
    starRays = "\u{f185}",          -- sun
    particleCount = "\u{f1bb}",     -- project-diagram (particle field)
    particleSize = "\u{f111}",      -- circle
    opacity = "\u{f06e}",           -- eye
    softCore = "\u{f1db}",          -- circle-notch
    glow = "\u{f0eb}",              -- lightbulb
    glowSize = "\u{f067}",          -- plus-circle (size)
    glowOpacity = "\u{f042}",       -- adjust
    stars = "\u{f005}",             -- star
    starCount = "\u{f4d8}",         -- star-of-life
    shootingStars = "\u{f135}",     -- rocket
    frequency = "\u{f017}",         -- clock
    speed = "\u{f0e7}",             -- bolt
    drift = "\u{f72e}",             -- wind
    twinkleSpeed = "\u{f0d0}",      -- magic (twinkle rate)
    twinkleAmount = "\u{f069}",     -- asterisk
    links = "\u{f0c1}",             -- link
    distance = "\u{f4a6}",          -- ruler-combined
    linkOpacity = "\u{f1fc}",       -- paint-brush
    linkWidth = "\u{f545}",         -- ruler-horizontal
    perParticle = "\u{f126}",       -- code-branch
    coloredLinks = "\u{f53f}",      -- palette
    cursor = "\u{f245}",            -- mouse-pointer
    cursorMode = "\u{f074}",        -- random (mode picker)
    radius = "\u{f192}",            -- bullseye
    force = "\u{f52d}",             -- compress-arrows-alt
    falloff = "\u{f201}",           -- chart-line
    motionBoost = "\u{f062}",       -- arrow-up
    threshold = "\u{f1ec}",         -- calculator (threshold)
    onlyMoving = "\u{f04b}",        -- play
    damping = "\u{f862}",           -- wave-square
    swirl = "\u{f2f1}",             -- sync-alt (vortex)
    ripple = "\u{f1cd}",            -- dot-circle
    horizonGrid = "\u{f547}",       -- grip-lines
    multiLayerStars = "\u{f5fd}",   -- layer-group
    stardust = "\u{f890}",          -- sparkles
    reset = "\u{f2ea}",             -- undo
    debug = "\u{f120}",             -- terminal
    background = "\u{f03e}",        -- image
    pause = "\u{f04c}",             -- pause
    themeAccent = "\u{f53f}",       -- palette
    themeMono = "\u{f042}",         -- adjust (contrast)
    idle = "\u{f254}",              -- hourglass-half
    accretionRing = "\u{f1db}",     -- circle-notch (orbit)
    gravityFilaments = "\u{f0c1}",  -- link (filament)
    flyingRockets = "\u{f135}",     -- rocket (joke parade)
}

local function WithTooltip(widget, en, ru)
    if widget and en and widget.ToolTip then
        widget:ToolTip(L(en, ru))
    end
    return widget
end

function Script.OnScriptsLoaded()
    CaptureScreenSizeForMenuSession()

    initPool(bgParticlePool, createBgParticle, 100)
    initPool(starPool, createStar, 200)
    initPool(shootingStarPool, createShootingStar, 10)
    initPool(ambientStreakPool, createAmbientStreak, 16)
    initPool(flyingRocketPool, createFlyingRocket, 14)

    local changerSection = Menu.Find("Changer", "Main")
    local tab
    if changerSection and changerSection.Create then
        tab = changerSection:Create("CosmicMenu")
    else
        tab = Menu.Create("General", "Main", "CosmicMenu")
    end
    local main = tab:Create(L("Settings", "Настройки"))

    if tab and tab.Icon then
        tab:Icon(Icons.tab)
    end

    local ok, cosmicMenuTab = pcall(function()
        return tab:Parent()
    end)

    if ok and cosmicMenuTab and cosmicMenuTab.Icon then
        cosmicMenuTab:Icon(Icons.tab)
    end

    local g_general = main:Create(L("General", "Общее"))

    Script.enabled = WithTooltip(
        g_general:Switch(L("Enable", "Включить"), true, Icons.enable),
        "Master switch for CosmicMenu",
        "Главный переключатель CosmicMenu"
    )

    Script.qualityPreset = g_general:Slider(L("Quality Preset", "Пресет качества"), 1, CONSTANTS.CUSTOM_PRESET_INDEX, 3, function(value)
        local mode = roundToInt(value)
        if mode == 1 then return L("Low", "Низкий") end
        if mode == 2 then return L("Medium", "Средний") end
        if mode == 3 then return L("High", "Высокий") end
        if mode == 4 then return L("Ultra", "Ультра") end
        if mode == 5 then return L("Zen", "Дзен") end
        if mode == CONSTANTS.CUSTOM_PRESET_INDEX then return L("Custom", "Свой") end
        return tostring(mode)
    end)
    applyIcon(Script.qualityPreset, Icons.quality)
    WithTooltip(
        Script.qualityPreset,
        "Applies recommended settings for performance or visuals",
        "Применяет рекомендуемые настройки производительности или визуала"
    )

    Script.fadeInEffect = g_general:Switch(L("Fade In", "Плавное появление"), true, Icons.fadeIn)

    local g_backdrop = main:Create(L("Backdrop", "Фон"))

    Script.backgroundBlur = g_backdrop:Switch(L("Background Blur", "Размытие фона"), false, Icons.blur)
    local blur_gear = Script.backgroundBlur:Gear(L("Blur", "Размытие"))
    Script.blurIntensity = blur_gear:Slider(L("Intensity", "Интенсивность"), 0.1, 1.0, 0.35, "%.1f")
    applyIcon(Script.blurIntensity, Icons.blurIntensity)

    Script.colorWash = g_backdrop:Switch(L("Color Wash", "Цветовой градиент"), true, Icons.colorWash)
    Script.vignette = g_backdrop:Switch(L("Vignette", "Виньетка"), true, Icons.vignette)
    Script.hudEdges = g_backdrop:Switch(L("HUD Corners", "HUD-углы"), true, Icons.hudCorners)
    Script.ambientStreaks = g_backdrop:Switch(L("Ambient Streaks", "Фоновые полосы"), true, Icons.streaks)
    Script.ambientStreakCount = g_backdrop:Slider(L("Streak Count", "Кол-во полос"), 0, 28, 16, "%d")
    applyIcon(Script.ambientStreakCount, Icons.streakCount)
    Script.parallax = g_backdrop:Switch(L("Parallax", "Параллакс"), true, Icons.parallax)
    Script.parallaxStrength = g_backdrop:Slider(L("Parallax Strength", "Сила параллакса"), 0, 100, 100, "%d%%")
    applyIcon(Script.parallaxStrength, Icons.parallaxStrength)

    Script.openRipple = WithTooltip(
        g_backdrop:Switch(L("Wormhole Open", "Червоточина при открытии"), true, Icons.ripple),
        "Spiral wormhole rings when the menu opens; particles burst outward briefly",
        "Спиральные кольца червоточины при открытии; частицы кратко разлетаются из центра"
    )
    Script.horizonGrid = WithTooltip(
        g_backdrop:Switch(L("Horizon Grid", "Синтвейв-сетка"), false, Icons.horizonGrid),
        "Perspective grid at the bottom of the screen",
        "Перспективная сетка внизу экрана"
    )
    Script.accretionRing = WithTooltip(
        g_backdrop:Switch(L("Accretion Ring", "Кольцо аккреции"), false, Icons.accretionRing),
        "Tilted orbital rings with a bright hotspot, like matter around a singularity",
        "Наклонные орбитальные кольца с яркой точкой — как аккреционный диск"
    )
    Script.gravityFilaments = WithTooltip(
        g_backdrop:Switch(L("Gravity Filaments", "Гравитационные нити"), false, Icons.gravityFilaments),
        "Curved filaments bending toward the center, like warped spacetime",
        "Изогнутые нити, стягивающиеся к центру — как искривлённое пространство"
    )
    Script.flyingRockets = WithTooltip(
        g_backdrop:Switch(L("Flying Rockets", "Летающие писюны"), false, Icons.flyingRockets),
        "Solo mode: turns off other FX except blur. Disabling restores your previous settings.",
        "Соло-режим: выключает остальные эффекты, кроме блюра. Выключение вернёт прежние настройки."
    )
    Script.flyingRocketCount = g_backdrop:Slider(L("Rocket Count", "Кол-во ракет"), 1, CONSTANTS.FLYING_ROCKET_MAX, 14, "%d")
    applyIcon(Script.flyingRocketCount, Icons.streakCount)

    local g_particles = main:Create(L("Particles", "Частицы"))

    Script.bgParticleCount = g_particles:Slider(L("Count", "Количество"), 20, 500, 100, "%d")
    applyIcon(Script.bgParticleCount, Icons.particleCount)

    Script.shieldRadius = g_particles:Slider(L("Size", "Размер"), 1, 8, 2, "%d")
    applyIcon(Script.shieldRadius, Icons.particleSize)

    Script.particleBaseAlpha = g_particles:Slider(L("Opacity", "Прозрачность"), 10, 255, 150, "%d")
    applyIcon(Script.particleBaseAlpha, Icons.opacity)

    Script.particleSoftCore = g_particles:Switch(L("Soft Core", "Мягкое ядро"), true, Icons.softCore)
    Script.particleGlow = g_particles:Switch(L("Glow", "Свечение"), true, Icons.glow)
    local glow_gear = Script.particleGlow:Gear(L("Glow", "Свечение"))
    Script.particleGlowScale = glow_gear:Slider(L("Size", "Размер"), 1, 8, 3, "%d")
    applyIcon(Script.particleGlowScale, Icons.glowSize)
    Script.particleGlowAlpha = glow_gear:Slider(L("Opacity", "Прозрачность"), 0, 100, 30, "%d%%")
    applyIcon(Script.particleGlowAlpha, Icons.glowOpacity)

    Script.particleSpeedScale = g_particles:Slider(L("Speed", "Скорость"), 10, 400, 100, "%d%%")
    applyIcon(Script.particleSpeedScale, Icons.speed)
    Script.particleDrift = g_particles:Slider(L("Drift", "Дрейф"), 0, 200, 35, "%d%%")
    applyIcon(Script.particleDrift, Icons.drift)
    Script.particleTwinkleSpeedScale = g_particles:Slider(L("Twinkle Speed", "Скорость мерцания"), 0, 300, 100, "%d%%")
    applyIcon(Script.particleTwinkleSpeedScale, Icons.twinkleSpeed)
    Script.particleTwinkleAmount = g_particles:Slider(L("Twinkle Amount", "Сила мерцания"), 0, 100, 30, "%d%%")
    applyIcon(Script.particleTwinkleAmount, Icons.twinkleAmount)

    local g_stars = main:Create(L("Stars", "Звёзды"))

    Script.stars = g_stars:Switch(L("Twinkling Stars", "Мерцающие звезды"), true, Icons.stars)
    local stars_gear = Script.stars:Gear(L("Stars", "Звезды"))
    Script.starCount = stars_gear:Slider(L("Count", "Количество"), 100, 500, 200, "%d")
    applyIcon(Script.starCount, Icons.starCount)

    Script.shootingStars = g_stars:Switch(L("Shooting Stars", "Падающие звезды"), true, Icons.shootingStars)
    local shooting_gear = Script.shootingStars:Gear(L("Shooting", "Падающие"))
    Script.shootingStarFreq = shooting_gear:Slider(L("Frequency", "Частота"), 1, 10, 5, "%d")
    applyIcon(Script.shootingStarFreq, Icons.frequency)

    Script.starRays = g_stars:Switch(L("Star Rays", "Лучи звёзд"), true, Icons.starRays)
    Script.multiLayerStars = WithTooltip(
        g_stars:Switch(L("Multi-Layer Depth", "Многослойность"), true, Icons.multiLayerStars),
        "3 depth layers: dim small back / bright large front. Move mouse to see parallax.",
        "3 слоя глубины: тусклые мелкие сзади / яркие крупные спереди. Двигай мышь — виден параллакс."
    )

    local g_links = main:Create(L("Links", "Связи"))
    Script.particleConnections = g_links:Switch(L("Enable Links", "Включить связи"), true, Icons.links)
    local links_gear = Script.particleConnections:Gear(L("Links", "Связи"))
    Script.particleConnectionDist = links_gear:Slider(L("Distance", "Дистанция"), 40, 400, 150, "%d")
    applyIcon(Script.particleConnectionDist, Icons.distance)
    Script.particleConnectionAlpha = links_gear:Slider(L("Opacity", "Прозрачность"), 0, 150, 50, "%d")
    applyIcon(Script.particleConnectionAlpha, Icons.linkOpacity)
    Script.particleConnectionWidth = links_gear:Slider(L("Width", "Толщина"), 1, 3, 1, "%d")
    applyIcon(Script.particleConnectionWidth, Icons.linkWidth)
    Script.particleMaxConnections = links_gear:Slider(L("Per Particle", "На частицу"), 0, 8, 3, "%d")
    applyIcon(Script.particleMaxConnections, Icons.perParticle)
    Script.particleColoredLinks = links_gear:Switch(L("Colored Links", "Цветные линии"), true, Icons.coloredLinks)

    local g_cursor = main:Create(L("Cursor", "Курсор"))
    Script.particleCursorInteraction = g_cursor:Switch(L("Enable Cursor", "Реакция на курсор"), true, Icons.cursor)
    local cursor_gear = Script.particleCursorInteraction:Gear(L("Cursor", "Курсор"))
    Script.particleCursorMode = cursor_gear:Slider(L("Mode", "Режим"), 1, 3, 1, function(value)
        local mode = roundToInt(value)
        if mode == 1 then return L("Repel", "Отталкивание") end
        if mode == 2 then return L("Swipe", "Свайп") end
        if mode == 3 then return L("Vortex", "Вихрь") end
        return tostring(mode)
    end)
    applyIcon(Script.particleCursorMode, Icons.cursorMode)
    Script.particleCursorRadius = cursor_gear:Slider(L("Radius", "Радиус"), 40, 600, 180, "%d")
    applyIcon(Script.particleCursorRadius, Icons.radius)
    Script.particleCursorForce = cursor_gear:Slider(L("Force", "Сила"), 100, 12000, 3200, "%d")
    applyIcon(Script.particleCursorForce, Icons.force)
    Script.particleCursorFalloff = cursor_gear:Slider(L("Falloff", "Спад"), 25, 300, 120, "%d%%")
    applyIcon(Script.particleCursorFalloff, Icons.falloff)
    Script.particleCursorMotionBoost = cursor_gear:Slider(L("Motion Boost", "Усиление"), 0, 300, 120, "%d%%")
    applyIcon(Script.particleCursorMotionBoost, Icons.motionBoost)
    Script.particleCursorMoveThreshold = cursor_gear:Slider(L("Move Threshold", "Порог"), 0, 40, 1, "%d")
    applyIcon(Script.particleCursorMoveThreshold, Icons.threshold)
    Script.particleCursorOnlyMoving = cursor_gear:Switch(L("Only While Moving", "Только при движении"), true, Icons.onlyMoving)
    Script.particleCursorImpulseDamping = cursor_gear:Slider(L("Damping", "Затухание"), 0, 300, 90, "%d%%")
    applyIcon(Script.particleCursorImpulseDamping, Icons.damping)
    Script.particleCursorSwirl = cursor_gear:Slider(L("Swirl", "Вихрь"), -100, 100, 60, "%d%%")
    applyIcon(Script.particleCursorSwirl, Icons.swirl)

    Script.cursorStardust = WithTooltip(
        g_cursor:Switch(L("Cursor Stardust", "Звёздная пыль"), true, Icons.stardust),
        "Light dot trail following the cursor",
        "Лёгкий след из точек за курсором"
    )

    local g_theme = main:Create(L("Theme", "Тема"))

    Script.themeUseAccentOnly = WithTooltip(
        g_theme:Switch(L("Accent Only", "Только акцент"), false, Icons.themeAccent),
        "Derive secondary color from accent only",
        "Вторичный цвет только из акцента"
    )
    Script.themeMonochrome = WithTooltip(
        g_theme:Switch(L("Monochrome", "Монохром"), false, Icons.themeMono),
        "Muted grayscale secondary tone",
        "Приглушённый серый вторичный тон"
    )

    local g_perf = main:Create(L("Performance", "Производительность"))

    Script.backgroundOnly = WithTooltip(
        g_perf:Switch(L("Background Only", "Только фон"), false, Icons.background),
        "Gradient, vignette and stars without particles or cursor FX",
        "Градиент, виньетка и звёзды без частиц и эффектов курсора"
    )
    Script.pauseWhenIdle = WithTooltip(
        g_perf:Switch(L("Pause When Idle", "Пауза без движения"), false, Icons.pause),
        "Freeze simulation when the cursor is still",
        "Останавливать симуляцию при неподвижном курсоре"
    )
    Script.idleThreshold = g_perf:Slider(
        L("Idle Delay", "Задержка паузы"),
        CONSTANTS.IDLE_THRESHOLD_MIN,
        CONSTANTS.IDLE_THRESHOLD_MAX,
        CONSTANTS.IDLE_PAUSE_DEFAULT,
        "%.0fs"
    )
    applyIcon(Script.idleThreshold, Icons.idle)

    Script.debugOverlay = WithTooltip(
        g_perf:Switch(L("Debug Overlay", "Отладка"), false, Icons.debug),
        "Show quality, counts and screen info on screen",
        "Показывать качество, счётчики и экран на оверлее"
    )

    if g_general.Button then
        Script.resetPresetButton = g_general:Button(
            L("Reset to Preset", "Сбросить к пресету"),
            function()
                ResetToNamedPreset()
            end,
            true
        )
        applyIcon(Script.resetPresetButton, Icons.reset)
        WithTooltip(
            Script.resetPresetButton,
            "Re-apply the last named quality preset (Low–Ultra–Zen)",
            "Повторно применить последний именованный пресет (Низкий–Ультра–Дзен)"
        )
    end

    local function attachCustomCallback(widget)
        if widget and widget.SetCallback then
            widget:SetCallback(function()
                if IsCustomPresetMarkBlocked() then
                    return
                end
                MarkCustomPreset()
                SaveCustomPresetValues()
                if UpdateMenuControls then
                    UpdateMenuControls()
                end
            end, false)
        end
    end

    State.applyingPreset = true

  local presetTrackedWidgets = {
        Script.fadeInEffect, Script.backgroundBlur, Script.blurIntensity, Script.colorWash,
        Script.vignette, Script.hudEdges, Script.ambientStreaks, Script.ambientStreakCount,
        Script.parallax, Script.parallaxStrength, Script.openRipple, Script.horizonGrid,
        Script.accretionRing, Script.gravityFilaments, Script.flyingRocketCount,
        Script.bgParticleCount, Script.shieldRadius, Script.particleBaseAlpha, Script.particleSoftCore,
        Script.particleGlow, Script.particleGlowScale, Script.particleGlowAlpha,
        Script.particleSpeedScale, Script.particleDrift, Script.particleTwinkleSpeedScale,
        Script.particleTwinkleAmount, Script.stars, Script.starCount, Script.shootingStars,
        Script.shootingStarFreq, Script.starRays, Script.multiLayerStars,
        Script.particleConnections, Script.particleConnectionDist, Script.particleConnectionAlpha,
        Script.particleConnectionWidth, Script.particleMaxConnections, Script.particleColoredLinks,
        Script.particleCursorInteraction, Script.particleCursorMode, Script.particleCursorRadius,
        Script.particleCursorForce, Script.particleCursorFalloff, Script.particleCursorMotionBoost,
        Script.particleCursorMoveThreshold, Script.particleCursorOnlyMoving,
        Script.particleCursorImpulseDamping, Script.particleCursorSwirl, Script.cursorStardust,
    }

    for i = 1, #presetTrackedWidgets do
        attachCustomCallback(presetTrackedWidgets[i])
    end

    if Script.flyingRockets and Script.flyingRockets.SetCallback then
        Script.flyingRockets:SetCallback(function()
            if State.applyingPreset then
                return
            end

            local enabled = WidgetGet(Script.flyingRockets, false)
            SaveWidgetConfigValue("flyingRockets")
            OnFlyingRocketsToggled()

            if not enabled then
                State.blockCustomPresetMarks = 0
                MarkCustomPreset()
                SaveCustomPresetValues()
            end
        end, false)
    end

    if Script.qualityPreset and Script.qualityPreset.SetCallback then
        Script.qualityPreset:SetCallback(function()
            if State.applyingPreset then
                return
            end
            local presetIndex = clamp(roundToInt(WidgetGet(Script.qualityPreset, 3)), 1, CONSTANTS.CUSTOM_PRESET_INDEX)
            ConfigWriteInt("quality_preset", presetIndex)
            if presetIndex >= 1 and presetIndex <= CONSTANTS.BUILTIN_PRESET_COUNT then
                ApplyQualityPreset(presetIndex)
            elseif presetIndex == CONSTANTS.CUSTOM_PRESET_INDEX then
                State.lastQualityPreset = CONSTANTS.CUSTOM_PRESET_INDEX
                ConfigWriteInt("quality_preset", CONSTANTS.CUSTOM_PRESET_INDEX)
            end
            if UpdateMenuControls then
                UpdateMenuControls()
            end
        end, false)
    end

    local function attachConfigFlagCallback(widget, key)
        if widget and widget.SetCallback then
            widget:SetCallback(function()
                SaveWidgetConfigValue(key)
                if key == "themeUseAccentOnly" or key == "themeMonochrome" then
                    if key == "themeUseAccentOnly" and WidgetGet(Script.themeUseAccentOnly, false) then
                        WidgetSet(Script.themeMonochrome, false)
                        SaveWidgetConfigValue("themeMonochrome")
                    end
                    RefreshThemeCache()
                end
                if UpdateMenuControls then
                    UpdateMenuControls()
                end
            end, true)
        end
    end

    attachConfigFlagCallback(Script.enabled, "enabled")
    attachConfigFlagCallback(Script.themeUseAccentOnly, "themeUseAccentOnly")
    attachConfigFlagCallback(Script.themeMonochrome, "themeMonochrome")
    attachConfigFlagCallback(Script.pauseWhenIdle, "pauseWhenIdle")
    attachConfigFlagCallback(Script.backgroundOnly, "backgroundOnly")
    attachConfigFlagCallback(Script.debugOverlay, "debugOverlay")
    attachConfigFlagCallback(Script.idleThreshold, "idleThreshold")

    UpdateMenuControls = function()
        local masterEnabled = WidgetGet(Script.enabled, true)
        local blurEnabled = WidgetGet(Script.backgroundBlur, false)
        local streaksEnabled = WidgetGet(Script.ambientStreaks, true)
        local rocketsEnabled = WidgetGet(Script.flyingRockets, false)
        local parallaxEnabled = WidgetGet(Script.parallax, true)
        local glowEnabled = WidgetGet(Script.particleGlow, true)
        local starsEnabled = WidgetGet(Script.stars, true)
        local shootingEnabled = WidgetGet(Script.shootingStars, true)
        local linksEnabled = WidgetGet(Script.particleConnections, true)
        local cursorEnabled = WidgetGet(Script.particleCursorInteraction, true)
        local pauseIdle = WidgetGet(Script.pauseWhenIdle, false)
        local backgroundOnly = WidgetGet(Script.backgroundOnly, false)
        local accentOnly = WidgetGet(Script.themeUseAccentOnly, false)

        local function setDisabled(widget, disabled)
            if widget and widget.Disabled then
                widget:Disabled(disabled)
            end
        end

        setDisabled(Script.qualityPreset, not masterEnabled)
        setDisabled(Script.fadeInEffect, not masterEnabled)
        setDisabled(Script.resetPresetButton, not masterEnabled)
        setDisabled(Script.backgroundBlur, not masterEnabled)
        setDisabled(Script.blurIntensity, not masterEnabled or not blurEnabled)
        setDisabled(Script.colorWash, not masterEnabled or rocketsEnabled)
        setDisabled(Script.vignette, not masterEnabled or rocketsEnabled)
        setDisabled(Script.hudEdges, not masterEnabled or rocketsEnabled)
        setDisabled(Script.ambientStreaks, not masterEnabled or rocketsEnabled)
        setDisabled(Script.ambientStreakCount, not masterEnabled or not streaksEnabled or rocketsEnabled)
        setDisabled(Script.parallax, not masterEnabled or rocketsEnabled)
        setDisabled(Script.parallaxStrength, not masterEnabled or not parallaxEnabled or rocketsEnabled)
        setDisabled(Script.openRipple, not masterEnabled or rocketsEnabled)
        setDisabled(Script.horizonGrid, not masterEnabled or rocketsEnabled)
        setDisabled(Script.accretionRing, not masterEnabled or rocketsEnabled)
        setDisabled(Script.gravityFilaments, not masterEnabled or rocketsEnabled)
        setDisabled(Script.flyingRockets, not masterEnabled or backgroundOnly)
        setDisabled(Script.flyingRocketCount, not masterEnabled or backgroundOnly or not rocketsEnabled)
        setDisabled(Script.bgParticleCount, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.shieldRadius, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleBaseAlpha, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleSoftCore, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleGlow, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleGlowScale, not masterEnabled or backgroundOnly or not glowEnabled or rocketsEnabled)
        setDisabled(Script.particleGlowAlpha, not masterEnabled or backgroundOnly or not glowEnabled or rocketsEnabled)
        setDisabled(Script.particleSpeedScale, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleDrift, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleTwinkleSpeedScale, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleTwinkleAmount, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.stars, not masterEnabled or rocketsEnabled)
        setDisabled(Script.starCount, not masterEnabled or not starsEnabled or rocketsEnabled)
        setDisabled(Script.shootingStars, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.shootingStarFreq, not masterEnabled or backgroundOnly or not shootingEnabled or rocketsEnabled)
        setDisabled(Script.starRays, not masterEnabled or not starsEnabled or rocketsEnabled)
        setDisabled(Script.multiLayerStars, not masterEnabled or not starsEnabled or rocketsEnabled)
        setDisabled(Script.particleConnections, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleConnectionDist, not masterEnabled or backgroundOnly or not linksEnabled or rocketsEnabled)
        setDisabled(Script.particleConnectionAlpha, not masterEnabled or backgroundOnly or not linksEnabled or rocketsEnabled)
        setDisabled(Script.particleConnectionWidth, not masterEnabled or backgroundOnly or not linksEnabled or rocketsEnabled)
        setDisabled(Script.particleMaxConnections, not masterEnabled or backgroundOnly or not linksEnabled or rocketsEnabled)
        setDisabled(Script.particleColoredLinks, not masterEnabled or backgroundOnly or not linksEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorInteraction, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.particleCursorMode, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorRadius, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorForce, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorFalloff, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorMotionBoost, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorMoveThreshold, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorOnlyMoving, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorImpulseDamping, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.particleCursorSwirl, not masterEnabled or backgroundOnly or not cursorEnabled or rocketsEnabled)
        setDisabled(Script.cursorStardust, not masterEnabled or backgroundOnly or rocketsEnabled)
        setDisabled(Script.themeUseAccentOnly, not masterEnabled)
        setDisabled(Script.themeMonochrome, not masterEnabled or accentOnly)
        setDisabled(Script.backgroundOnly, not masterEnabled)
        setDisabled(Script.pauseWhenIdle, not masterEnabled)
        setDisabled(Script.idleThreshold, not masterEnabled or not pauseIdle)
        setDisabled(Script.debugOverlay, not masterEnabled)
    end

    if Script.enabled and Script.enabled.SetCallback then
        Script.enabled:SetCallback(function()
            SaveWidgetConfigValue("enabled")
            UpdateMenuControls()
        end, true)
    end

    State.applyingPreset = false
    State.lastQualityPreset = clamp(roundToInt(WidgetGet(Script.qualityPreset, 3)), 1, CONSTANTS.CUSTOM_PRESET_INDEX)
    LoadConfigProfile()
    ArmCustomPresetMarkBlock()
    UpdateMenuControls()
    RefreshThemeCache()
end

--#endregion

--#region Frame settings

GatherFrameSettings = function()
    local backgroundOnly = WidgetGet(Script.backgroundOnly, false)

    local settings = {
        fadeInEffect = WidgetGet(Script.fadeInEffect, true),
        backgroundBlur = WidgetGet(Script.backgroundBlur, false),
        blurIntensity = WidgetGet(Script.blurIntensity, 0.35),
        colorWash = WidgetGet(Script.colorWash, true),
        vignette = WidgetGet(Script.vignette, true),
        hudEdges = WidgetGet(Script.hudEdges, true),
        ambientStreaks = WidgetGet(Script.ambientStreaks, true),
        ambientStreakCount = WidgetGet(Script.ambientStreakCount, 16),
        parallax = WidgetGet(Script.parallax, true),
        parallaxStrength = WidgetGet(Script.parallaxStrength, 100),
        openRipple = WidgetGet(Script.openRipple, true),
        horizonGrid = WidgetGet(Script.horizonGrid, false),
        accretionRing = WidgetGet(Script.accretionRing, false),
        gravityFilaments = WidgetGet(Script.gravityFilaments, false),
        flyingRockets = WidgetGet(Script.flyingRockets, false),
        flyingRocketCount = WidgetGet(Script.flyingRocketCount, 14),
        bgParticleCount = WidgetGet(Script.bgParticleCount, 100),
        particleSize = WidgetGet(Script.shieldRadius, 2),
        particleBaseAlpha = WidgetGet(Script.particleBaseAlpha, 150),
        particleSoftCore = WidgetGet(Script.particleSoftCore, true),
        particleGlow = WidgetGet(Script.particleGlow, true),
        particleGlowScale = WidgetGet(Script.particleGlowScale, 3),
        particleGlowAlpha = WidgetGet(Script.particleGlowAlpha, 30),
        particleSpeedScale = WidgetGet(Script.particleSpeedScale, 100),
        particleDrift = WidgetGet(Script.particleDrift, 35),
        particleTwinkleSpeedScale = WidgetGet(Script.particleTwinkleSpeedScale, 100),
        particleTwinkleAmount = WidgetGet(Script.particleTwinkleAmount, 30),
        stars = WidgetGet(Script.stars, true),
        starCount = WidgetGet(Script.starCount, 200),
        shootingStars = WidgetGet(Script.shootingStars, true),
        shootingStarFreq = WidgetGet(Script.shootingStarFreq, 5),
        starRays = WidgetGet(Script.starRays, true),
        multiLayerStars = WidgetGet(Script.multiLayerStars, true),
        particleConnections = WidgetGet(Script.particleConnections, true),
        particleConnectionDist = WidgetGet(Script.particleConnectionDist, CONSTANTS.PARTICLE_CONNECTION_DIST),
        particleConnectionAlpha = WidgetGet(Script.particleConnectionAlpha, 50),
        particleConnectionWidth = WidgetGet(Script.particleConnectionWidth, 1),
        particleMaxConnections = WidgetGet(Script.particleMaxConnections, CONSTANTS.PARTICLE_MAX_CONNECTIONS),
        particleColoredLinks = WidgetGet(Script.particleColoredLinks, true),
        particleCursorInteraction = WidgetGet(Script.particleCursorInteraction, true),
        particleCursorMode = WidgetGet(Script.particleCursorMode, 1),
        particleCursorRadius = WidgetGet(Script.particleCursorRadius, 180),
        particleCursorForce = WidgetGet(Script.particleCursorForce, 3200),
        particleCursorFalloff = WidgetGet(Script.particleCursorFalloff, 120),
        particleCursorMotionBoost = WidgetGet(Script.particleCursorMotionBoost, 120),
        particleCursorMoveThreshold = WidgetGet(Script.particleCursorMoveThreshold, 1),
        particleCursorOnlyMoving = WidgetGet(Script.particleCursorOnlyMoving, true),
        particleCursorImpulseDamping = WidgetGet(Script.particleCursorImpulseDamping, 90),
        particleCursorSwirl = WidgetGet(Script.particleCursorSwirl, 60),
        cursorStardust = WidgetGet(Script.cursorStardust, true),
        pauseWhenIdle = WidgetGet(Script.pauseWhenIdle, false),
        idleThreshold = WidgetGet(Script.idleThreshold, CONSTANTS.IDLE_PAUSE_DEFAULT),
        backgroundOnly = backgroundOnly,
        debugOverlay = WidgetGet(Script.debugOverlay, false),
    }

    if backgroundOnly then
        settings.bgParticleCount = 0
        settings.particleConnections = false
        settings.particleCursorInteraction = false
        settings.shootingStars = false
        settings.cursorStardust = false
        settings.particleGlow = false
        settings.particleSoftCore = false
        settings.flyingRockets = false
    end

    if State.rocketSoloActive and settings.flyingRockets then
        settings.bgParticleCount = 0
        settings.colorWash = false
        settings.vignette = false
        settings.hudEdges = false
        settings.ambientStreaks = false
        settings.parallax = false
        settings.openRipple = false
        settings.horizonGrid = false
        settings.accretionRing = false
        settings.gravityFilaments = false
        settings.stars = false
        settings.shootingStars = false
        settings.starRays = false
        settings.multiLayerStars = false
        settings.particleSoftCore = false
        settings.particleGlow = false
        settings.particleConnections = false
        settings.particleCursorInteraction = false
        settings.cursorStardust = false
    end

    return settings
end

local function updateSceneParallax(cursorPos, cursorInteractionEnabled, w, h, dt, settings)
    local parallaxEnabled = settings.parallax
    local parallaxMul = (settings.parallaxStrength or 100) * 0.01
    local targetParallaxX = 0
    local targetParallaxY = 0

    if cursorPos and parallaxEnabled then
        local centerX = w * 0.5
        local centerY = h * 0.5
        targetParallaxX = clamp((cursorPos.x - centerX) / math.max(centerX, 1), -1, 1) * 16 * parallaxMul
        targetParallaxY = clamp((cursorPos.y - centerY) / math.max(centerY, 1), -1, 1) * 10 * parallaxMul
    end

    local parallaxLerp = clamp(dt * (cursorPos and 4.5 or 3.0), 0, 1)
    sceneParallaxX = lerp(sceneParallaxX, targetParallaxX, parallaxLerp)

    if cursorPos and cursorInteractionEnabled then
        cursorHaloX = cursorPos.x
        cursorHaloY = cursorPos.y
        sceneParallaxY = lerp(sceneParallaxY, targetParallaxY, parallaxLerp)
        return
    end

    sceneParallaxY = lerp(sceneParallaxY, targetParallaxY, parallaxLerp)

    if not cursorPos then
        local haloOffsetLerp = clamp(dt * 6.0, 0, 1)
        cursorHaloOffsetX = lerp(cursorHaloOffsetX, 0, haloOffsetLerp)
        cursorHaloOffsetY = lerp(cursorHaloOffsetY, 0, haloOffsetLerp)
        cursorHaloX = nil
        cursorHaloY = nil
    end
end

local function updateCursorHaloOffset(frameCursorDeltaX, frameCursorDeltaY, dt)
    local targetHaloOffsetX = clamp(frameCursorDeltaX * 0.55, -18, 18)
    local targetHaloOffsetY = clamp(frameCursorDeltaY * 0.55, -18, 18)
    local haloOffsetLerp = clamp(dt * 8.0, 0, 1)
    cursorHaloOffsetX = lerp(cursorHaloOffsetX, targetHaloOffsetX, haloOffsetLerp)
    cursorHaloOffsetY = lerp(cursorHaloOffsetY, targetHaloOffsetY, haloOffsetLerp)
end

local function EnsureDebugFont()
    if State.debugFont then
        return State.debugFont
    end
    if not Render or not Render.LoadFont then
        return nil
    end
    local ok, font = pcall(Render.LoadFont, "MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS)
    if ok and font then
        State.debugFont = font
        return font
    end
    return nil
end

local function DrawDebugOverlay(settings, fadeInAlpha, renderW, renderH)
    if not settings or not settings.debugOverlay then
        return
    end

    renderW = renderW or screenSize.x
    renderH = renderH or screenSize.y

    local font = EnsureDebugFont()
    local raw = State.lastRawScreenSize
    local rawText = raw and string.format("%dx%d", raw.x, raw.y) or "n/a"
    local lines = {
        string.format("dt: %.3f  quality: %.2f", State.lastDt or 0, qualityScale),
        string.format("particles: %d  stars: %d  streaks: %d  rockets: %d", #bgParticleActive, #starActive, #ambientStreakActive, #flyingRocketActive),
        string.format("sim: %s  idle: %.1fs", State.simulationPaused and "paused" or "active", State.menuIdleTime or 0),
        string.format("screen: %dx%d  raw: %s", screenSize.x, screenSize.y, rawText),
        string.format("render: %dx%d  cached: %s", renderW, renderH, State.cachedFullScreenSize and "yes" or "no"),
        string.format("preset: %d  named: %d", roundToInt(WidgetGet(Script.qualityPreset, 3)), State.lastNamedPreset or 0),
    }

    local x = 12
    local y = 12
    local lineHeight = 14
    local panelH = #lines * lineHeight + 10
    local panelW = 360

    Render.FilledRect(Vec2(x - 4, y - 4), Vec2(x + panelW, y + panelH), Color(0, 0, 0, math.floor(140 * fadeInAlpha)), 4)

    if font and Render.Text then
        for i, line in ipairs(lines) do
            local alpha = math.floor(220 * fadeInAlpha)
            pcall(Render.Text, font, 12, line, Vec2(x, y + (i - 1) * lineHeight), Color(180, 220, 255, alpha))
        end
    end
end

local function GetLinkLodSettings(settings, particleCount)
    local maxConnections = settings.particleMaxConnections or CONSTANTS.PARTICLE_MAX_CONNECTIONS
    local skipFrame = false

    if qualityScale < CONSTANTS.LINK_LOD_QUALITY_THRESHOLD then
        maxConnections = math.max(1, math.floor(maxConnections * CONSTANTS.LINK_LOD_CONNECTION_SCALE))
    elseif qualityScale >= CONSTANTS.LINK_PULSE_QUALITY_THRESHOLD then
        maxConnections = maxConnections + 1
    end

    if particleCount > CONSTANTS.LINK_LOD_PARTICLE_THRESHOLD then
        maxConnections = math.max(1, maxConnections - 1)
        if qualityScale < CONSTANTS.LINK_PULSE_QUALITY_THRESHOLD then
            State.linkGridSkipFrame = not State.linkGridSkipFrame
            skipFrame = State.linkGridSkipFrame
        end
    end

    return maxConnections, skipFrame
end

--#endregion

--#region Simulation

local function IsMenuOpen()
    if Menu and Menu.Opened then
        return Menu.Opened() == true
    end
    return false
end

local function UpdateCosmicSimulation(dt)
    State.lastDt = dt
    TickCustomPresetMarkBlock()

    if dt > 0.030 then
        qualityScale = clamp(qualityScale - 0.08, 0.82, 1.0)
        qualitySpikeHold = 0.35
    elseif qualitySpikeHold > 0 then
        qualitySpikeHold = qualitySpikeHold - dt
    else
        qualityScale = clamp(qualityScale + dt * 0.15, 0.82, 1.0)
    end

    qualityScaleForCounts = lerp(
        qualityScaleForCounts,
        qualityScale,
        clamp(dt * CONSTANTS.QUALITY_COUNT_SMOOTH_SPEED, 0, 1)
    )

    local rawMenuOpen = IsMenuOpen()

    if rawMenuOpen then
        if not menuWasOpen then
            CaptureScreenSizeForMenuSession()
            if menuClosedAccumulated >= CONSTANTS.MENU_REOPEN_DEBOUNCE_FRAMES then
                fadeInTime = 0
                openRippleTime = 0
                RefreshThemeCache()
            end
        end
        menuClosedFrames = 0
        menuClosedAccumulated = 0
        menuWasOpen = true
    else
        RefreshCachedFullScreenSize()
        menuClosedFrames = menuClosedFrames + 1
        menuClosedAccumulated = menuClosedAccumulated + 1

        if menuClosedFrames >= CONSTANTS.MENU_CLOSE_FLICKER_FRAMES then
            menuWasOpen = false
            State.fadeInAlpha = 0
            State.frameSettings = nil
            return
        end

        if not menuWasOpen then
            return
        end
    end

    fadeInTime = math.min(fadeInTime + dt, CONSTANTS.FADE_IN_DURATION)
    openRippleTime = openRippleTime + dt

    time = time + dt
    StepThemeColorLerp(dt)
    MaybeApplyQualityPreset()

    local settings = GatherFrameSettings()
    State.frameSettings = settings

    SyncEffectTogglePools(settings)

    if State.multiLayerWasEnabled ~= settings.multiLayerStars then
        starLayerCounter = 0
        for i, star in ipairs(starPool) do
            if star.active then
                assignStarLayer(star)
            end
        end
        State.multiLayerWasEnabled = settings.multiLayerStars
    end

    local fadeInAlpha = 1
    if settings.fadeInEffect and fadeInTime < CONSTANTS.FADE_IN_DURATION then
        fadeInAlpha = fadeInTime / CONSTANTS.FADE_IN_DURATION
    end
    State.fadeInAlpha = fadeInAlpha

    local areaScale = getScreenAreaScale()
    local countQuality = qualityScaleForCounts
    local bgTargetCount = clamp(roundToInt(settings.bgParticleCount * areaScale * countQuality), 0, 700)
    local starsEnabled = settings.stars
    local starTargetCount = starsEnabled and clamp(roundToInt(settings.starCount * areaScale * (0.88 + countQuality * 0.12)), 60, 700) or 0
    local streakTargetCount = settings.ambientStreaks and clamp(roundToInt(settings.ambientStreakCount * areaScale * countQuality), 0, 28) or 0
    local rocketTargetCount = settings.flyingRockets and clamp(roundToInt(settings.flyingRocketCount * areaScale * countQuality), 0, CONSTANTS.FLYING_ROCKET_MAX) or 0

    lastBgTargetCount = rebalancePoolIfChanged(bgParticlePool, bgTargetCount, lastBgTargetCount, createBgParticle, function(particle)
        particle.impulseX = 0
        particle.impulseY = 0
    end)
    lastStarTargetCount = rebalancePoolIfChanged(starPool, starTargetCount, lastStarTargetCount, createStar, assignStarLayer)
    lastStreakTargetCount = rebalancePoolIfChanged(ambientStreakPool, streakTargetCount, lastStreakTargetCount, createAmbientStreak, resetAmbientStreak)
    lastRocketTargetCount = rebalancePoolIfChanged(flyingRocketPool, rocketTargetCount, lastRocketTargetCount, createFlyingRocket, resetFlyingRocket)

    collectActive(bgParticlePool, bgParticleActive)
    collectActive(starPool, starActive)
    collectActive(ambientStreakPool, ambientStreakActive)
    collectActive(flyingRocketPool, flyingRocketActive)

    local w, h = screenSize.x, screenSize.y
    local particleSpeedScale = settings.particleSpeedScale * 0.01
    local particleDrift = settings.particleDrift * 0.01
    local particleTwinkleSpeedScale = settings.particleTwinkleSpeedScale * 0.01
    local particleTwinkleAmount = settings.particleTwinkleAmount * 0.01
    local wrapMargin = 50
    local cursorInteractionEnabled = settings.particleCursorInteraction
    local cursorTrackingEnabled = cursorInteractionEnabled or settings.cursorStardust or settings.parallax
    local cursorPos = nil
    local frameCursorDeltaX = 0
    local frameCursorDeltaY = 0
    local frameCursorDeltaLen = 0
    local cursorMode = clamp(roundToInt(settings.particleCursorMode), 1, 3)
    local cursorRadius = settings.particleCursorRadius
    local cursorRadiusSq = cursorRadius * cursorRadius
    local cursorForce = settings.particleCursorForce
    local cursorFalloffExp = settings.particleCursorFalloff * 0.01
    local cursorMotionBoost = settings.particleCursorMotionBoost * 0.01
    local cursorMoveThreshold = settings.particleCursorMoveThreshold
    local cursorOnlyMoving = settings.particleCursorOnlyMoving
    local cursorImpulseDecay = clamp(1 - (settings.particleCursorImpulseDamping * 0.01) * 4 * dt, 0, 1)
    local cursorSwirl = settings.particleCursorSwirl * 0.01

    if lastCursorModeApplied ~= cursorMode or lastCursorInteractionApplied ~= cursorInteractionEnabled then
        resetParticleImpulses()
        lastCursorModeApplied = cursorMode
        lastCursorInteractionApplied = cursorInteractionEnabled
    end

    if cursorTrackingEnabled then
        cursorPos = GetCursorPos()
        if cursorPos then
            if lastCursorX ~= nil and lastCursorY ~= nil then
                frameCursorDeltaX = cursorPos.x - lastCursorX
                frameCursorDeltaY = cursorPos.y - lastCursorY
                frameCursorDeltaLen = math.sqrt(frameCursorDeltaX * frameCursorDeltaX + frameCursorDeltaY * frameCursorDeltaY)
            end

            lastCursorX = cursorPos.x
            lastCursorY = cursorPos.y
        else
            lastCursorX = nil
            lastCursorY = nil
        end
    else
        lastCursorX = nil
        lastCursorY = nil
    end

    if settings.pauseWhenIdle then
        if frameCursorDeltaLen > cursorMoveThreshold then
            State.menuIdleTime = 0
        else
            State.menuIdleTime = (State.menuIdleTime or 0) + dt
        end
        State.simulationPaused = State.menuIdleTime >= (settings.idleThreshold or CONSTANTS.IDLE_PAUSE_DEFAULT)
    else
        State.menuIdleTime = 0
        State.simulationPaused = false
    end

    local simDt = State.simulationPaused and 0 or dt

    if cursorPos and cursorInteractionEnabled then
        updateCursorHaloOffset(frameCursorDeltaX, frameCursorDeltaY, dt)
    end

    updateSceneParallax(cursorPos, cursorInteractionEnabled, w, h, dt, settings)
    updateStardustTrail(dt, cursorPos, frameCursorDeltaLen, settings.cursorStardust)

    if simDt > 0 then
        if settings.openRipple and openRippleTime < CONSTANTS.WORMHOLE_PARTICLE_BURST_DURATION then
            local burstT = 1 - (openRippleTime / CONSTANTS.WORMHOLE_PARTICLE_BURST_DURATION)
            local cx = w * 0.5
            local cy = h * 0.5
            for _, particle in ipairs(bgParticleActive) do
                local dx = particle.x - cx
                local dy = particle.y - cy
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 1 then
                    local strength = burstT * 140 / dist
                    particle.impulseX = (particle.impulseX or 0) + (dx / dist) * strength * simDt
                    particle.impulseY = (particle.impulseY or 0) + (dy / dist) * strength * simDt
                end
            end
        end

        for i, particle in ipairs(bgParticleActive) do
            particle.angle = particle.angle + (particle.angularVelocity or 0) * particleDrift * simDt

            local driftWave = math.sin(time * (particle.driftSpeed or 1) * math.max(0, particleTwinkleSpeedScale) + (particle.driftPhase or i))
            local moveAngle = particle.angle + driftWave * 0.35 * particleDrift * (particle.driftStrength or 1)
            local moveSpeed = particle.speed * 20 * simDt * particleSpeedScale * (particle.depth or 1)
            particle.x = particle.x + math.cos(moveAngle) * moveSpeed
            particle.y = particle.y + math.sin(moveAngle) * moveSpeed

            local impulseX = (particle.impulseX or 0) * cursorImpulseDecay
            local impulseY = (particle.impulseY or 0) * cursorImpulseDecay

            if cursorInteractionEnabled and cursorPos then
                local dx = particle.x - cursorPos.x
                local dy = particle.y - cursorPos.y
                local distSq = dx * dx + dy * dy

                if distSq < cursorRadiusSq and cursorRadius > 0 then
                    local allowInteraction = (not cursorOnlyMoving) or (frameCursorDeltaLen > cursorMoveThreshold)
                    if allowInteraction then
                        local dist = math.sqrt(distSq)
                        if dist < 0.001 then
                            dist = 0.001
                            dx = math.cos((particle.driftPhase or 0) + i)
                            dy = math.sin((particle.driftPhase or 0) + i)
                        end

                        local nx = dx / dist
                        local ny = dy / dist
                        local t = clamp(1 - (dist / cursorRadius), 0, 1)
                        local falloff = t ^ math.max(0.05, cursorFalloffExp)
                        local moveNorm = clamp((frameCursorDeltaLen - cursorMoveThreshold) / 24, 0, 1)
                        local boost = 1 + moveNorm * cursorMotionBoost
                        local radialForce = cursorForce * falloff * boost
                        local forceX = 0
                        local forceY = 0

                        if cursorMode == 1 then
                            forceX = nx * radialForce
                            forceY = ny * radialForce
                        elseif cursorMode == 2 then
                            if frameCursorDeltaLen > 0.001 then
                                local svx = frameCursorDeltaX / frameCursorDeltaLen
                                local svy = frameCursorDeltaY / frameCursorDeltaLen
                                local swipeForce = radialForce * (0.85 + cursorMotionBoost * 0.5)
                                forceX = svx * swipeForce
                                forceY = svy * swipeForce
                            end
                        elseif cursorMode == 3 then
                            local tangentX = -ny
                            local tangentY = nx
                            local swirlStrength = cursorSwirl

                            if swirlStrength == 0 then
                                swirlStrength = 0.6
                            end

                            if frameCursorDeltaLen > 0.001 then
                                local cross = frameCursorDeltaX * ny - frameCursorDeltaY * nx
                                if cross < 0 then
                                    tangentX = -tangentX
                                    tangentY = -tangentY
                                end
                            elseif swirlStrength < 0 then
                                tangentX = -tangentX
                                tangentY = -tangentY
                            end

                            swirlStrength = math.abs(swirlStrength)
                            local vortexForce = radialForce * (0.6 + swirlStrength)
                            forceX = tangentX * vortexForce
                            forceY = tangentY * vortexForce
                        else
                            forceX = nx * radialForce
                            forceY = ny * radialForce
                        end

                        impulseX = impulseX + forceX * simDt
                        impulseY = impulseY + forceY * simDt
                    end
                end
            end

            particle.impulseX = impulseX
            particle.impulseY = impulseY
            particle.x = particle.x + impulseX * simDt
            particle.y = particle.y + impulseY * simDt

            local twinkle = math.sin(time * 2 * (particle.twinkleSpeed or 1) * math.max(0, particleTwinkleSpeedScale) + (particle.twinklePhase or i))
            particle.brightness = clamp((particle.baseBrightness or 0.6) + twinkle * particleTwinkleAmount, 0.05, 1)

            if particle.x < -wrapMargin then particle.x = w + wrapMargin end
            if particle.x > w + wrapMargin then particle.x = -wrapMargin end
            if particle.y < -wrapMargin then particle.y = h + wrapMargin end
            if particle.y > h + wrapMargin then particle.y = -wrapMargin end
        end

        for i, star in ipairs(starActive) do
            local layer = star.layer or 2
            local twinkleMul = STAR_LAYER_TWINKLE_SPEED[layer] or 1.0
            star.brightness = 0.5 + math.sin(time * star.twinkleSpeed * twinkleMul + star.twinklePhase) * 0.5
            star.rayAngle = (star.rayAngle or 0) + (star.raySpinSpeed or 0) * simDt * 0.15

            if star.glintEligible and layer >= 2 then
                star.glintCooldown = (star.glintCooldown or 8) - simDt
                if star.glintCooldown <= 0 then
                    star.glintBoost = 1.0
                    star.glintCooldown = math.random(10, 22)
                end
            end

            if (star.glintBoost or 0) > 0 then
                star.glintBoost = math.max(0, star.glintBoost - simDt * 2.8)
            end
        end

        if settings.shootingStars then
            if math.random() < settings.shootingStarFreq * simDt * 0.01 then
                local star = getFromPool(shootingStarPool, createShootingStar)
                resetShootingStar(star)
            end

            for i = #shootingStarPool, 1, -1 do
                local star = shootingStarPool[i]
                if star.active then
                    if star.burstLife and star.burstLife > 0 then
                        star.burstLife = star.burstLife - simDt
                        if star.burstLife <= 0 then
                            star.active = false
                            star.burstStarted = false
                            star.burstLife = nil
                            clearList(star.tail)
                        end
                    else
                        star.progress = star.progress + star.speed * simDt * CONSTANTS.SHOOTING_STAR_SPEED_MOD
                        star.lifetime = star.lifetime + simDt

                        if star.progress >= 1 or star.lifetime > CONSTANTS.SHOOTING_STAR_MAX_LIFETIME then
                            if not star.burstStarted then
                                star.burstStarted = true
                                star.burstLife = CONSTANTS.SHOOTING_STAR_BURST_DURATION
                            end
                        else
                            local x = star.startX + (star.endX - star.startX) * star.progress
                            local y = star.startY + (star.endY - star.startY) * star.progress

                            star.tail[#star.tail + 1] = {x = x, y = y}
                            if #star.tail > CONSTANTS.SHOOTING_STAR_TAIL_LENGTH then
                                table.remove(star.tail, 1)
                            end
                        end
                    end
                end
            end
        end

        for i, streak in ipairs(ambientStreakActive) do
            local driftWave = math.sin(time * 0.45 + i * 0.31) * streak.drift
            local speedMul = streak.streakType == 1 and 0.55 or 1.0
            streak.progress = streak.progress + simDt * streak.speed * speedMul * (0.7 + qualityScale * 0.6)
            streak.x = streak.x + simDt * (12 + driftWave * 0.02) * speedMul
            streak.y = streak.y - simDt * (streak.streakType == 1 and 3 or 8) * speedMul

            if streak.progress >= 1 or streak.x > w + streak.length or streak.y < -streak.length then
                resetAmbientStreak(streak)
            end
        end

        for i, rocket in ipairs(flyingRocketActive) do
            local wobble = math.sin(time * 2.4 + (rocket.wobblePhase or i)) * (rocket.wobble or 0)
            local moveAngle = rocket.angle + wobble * 0.18
            local speed = rocket.speed * (0.85 + qualityScale * 0.25)
            rocket.x = rocket.x + math.cos(moveAngle) * speed * simDt
            rocket.y = rocket.y + math.sin(moveAngle) * speed * simDt
            rocket.angle = rocket.angle + (rocket.spin or 0) * simDt
            rocket.progress = (rocket.progress or 0) + simDt

            local margin = rocket.length + 40
            if rocket.x < -margin or rocket.x > w + margin or rocket.y < -margin or rocket.y > h + margin or rocket.progress > 14 then
                resetFlyingRocket(rocket)
            end
        end
    end
end

--#endregion

--#region Render

local function DrawBackgroundEffects(fadeInAlpha)
    fadeInAlpha = fadeInAlpha or State.fadeInAlpha or 1

    local primaryColor, secondaryColor = GetDrawThemeColors()
    local renderSize = GetLiveRenderScreenSize()
    local width = renderSize.x
    local height = renderSize.y
    local simW = math.max(screenSize.x, 1)
    local simH = math.max(screenSize.y, 1)
    local posScaleX = width / simW
    local posScaleY = height / simH

    local function toRenderX(simX)
        return simX * posScaleX
    end

    local function toRenderY(simY)
        return simY * posScaleY
    end

    local settings = State.frameSettings or GatherFrameSettings()
    State.frameSettings = settings

    local renderMinDim = math.min(width, height)
    local screenScale = clamp(renderMinDim / math.max(baseScreenMinDim or renderMinDim, 1), 0.75, 1.8)
    local lowQuality = qualityScale < CONSTANTS.QUALITY_LOW_THRESHOLD
    local drawStarRays = qualityScale >= CONSTANTS.STAR_RAY_QUALITY_THRESHOLD and settings.starRays
    local drawVignette = not lowQuality and settings.vignette
    local drawHudEdges = not lowQuality and settings.hudEdges
    local drawAmbientStreaks = settings.ambientStreaks

    if settings.backgroundBlur then
        local blurStrength = clamp(settings.blurIntensity, 0.1, 1.0)
        Render.Blur(Vec2(0, 0), renderSize, blurStrength, 1.0, 0, Enum.DrawFlags.None)
    end

    if settings.colorWash then
        local washAlpha = math.floor(CONSTANTS.WASH_ALPHA_BASE * fadeInAlpha)
        local washAlphaSoft = math.floor(washAlpha * 0.6)

        gradientRectCompat(
            Vec2(0, 0),
            renderSize,
            Color(primaryColor.r, primaryColor.g, primaryColor.b, washAlpha),
            Color(secondaryColor.r, secondaryColor.g, secondaryColor.b, washAlpha),
            true
        )

        gradientRectCompat(
            Vec2(0, 0),
            renderSize,
            Color(10, 18, 32, washAlphaSoft),
            Color(0, 0, 0, 0),
            false
        )

        DrawDeepSpaceGlow(width, height, primaryColor, secondaryColor, fadeInAlpha)
    end

    if settings.gravityFilaments and not settings.backgroundOnly then
        DrawGravityFilaments(width, height, primaryColor, secondaryColor, fadeInAlpha)
    end

    if settings.accretionRing then
        DrawAccretionRing(width, height, primaryColor, secondaryColor, fadeInAlpha)
    end

    if settings.openRipple then
        DrawWormholeOpen(width, height, primaryColor, secondaryColor, fadeInAlpha)
    end

    if drawVignette then
        local vignettePulse = 0.86 + math.sin(time * 0.95) * 0.14
        local vignetteAlpha = math.floor(CONSTANTS.VIGNETTE_ALPHA_BASE * fadeInAlpha * vignettePulse * (0.82 + qualityScale * 0.18))
        local vignetteSize = math.max(120, math.floor(math.min(width, height) * 0.22))

        gradientRectCompat(Vec2(0, 0), Vec2(width, vignetteSize), Color(0, 0, 0, vignetteAlpha), Color(0, 0, 0, 0), false)
        gradientRectCompat(Vec2(0, height - vignetteSize), Vec2(width, vignetteSize), Color(0, 0, 0, 0), Color(0, 0, 0, vignetteAlpha), false)
        gradientRectCompat(Vec2(0, 0), Vec2(vignetteSize, height), Color(0, 0, 0, vignetteAlpha), Color(0, 0, 0, 0), true)
        gradientRectCompat(Vec2(width - vignetteSize, 0), Vec2(vignetteSize, height), Color(0, 0, 0, 0), Color(0, 0, 0, vignetteAlpha), true)
    end

    if settings.horizonGrid then
        DrawHorizonGrid(width, height, primaryColor, secondaryColor, fadeInAlpha)
    end

    if drawAmbientStreaks then
        local streakVisibility = fadeInAlpha * (0.74 + qualityScale * 0.26)
        for i, streak in ipairs(ambientStreakActive) do
            local sway = math.sin(time * 0.8 + i * 0.67)
            DrawAmbientStreak(streak, toRenderX, toRenderY, fadeInAlpha, primaryColor, secondaryColor, streakVisibility, sway)
        end
    end

    if settings.flyingRockets then
        for _, rocket in ipairs(flyingRocketActive) do
            DrawFlyingRocket(rocket, toRenderX, toRenderY, fadeInAlpha, primaryColor, secondaryColor)
        end
    end

    if drawHudEdges then
        local pulse = 0.8 + math.sin(time * 1.25) * 0.2
        local coldPrimary = mixColors(primaryColor, makeColor(210, 235, 255, 255), 0.45, (primaryColor.a ~= nil and primaryColor.a) or 255)
        local coldSecondary = mixColors(secondaryColor, makeColor(235, 245, 255, 255), 0.55, (secondaryColor.a ~= nil and secondaryColor.a) or 255)
        local edgeAlpha = math.floor(CONSTANTS.EDGE_ALPHA_BASE * fadeInAlpha * pulse * (0.82 + qualityScale * 0.18))
        local edgeSoftAlpha = math.floor(edgeAlpha * 0.28)
        local edgeSize = math.max(42, math.floor(math.min(width, height) * 0.06 * screenScale))
        local lineThickness = math.max(0.8, 0.9 * screenScale)
        local inset = 1
        local cornerLen = math.max(50, math.floor(math.min(width, height) * 0.08))
        local sweepWidth = math.max(80, math.floor(width * 0.16))
        local sweepX = (width + sweepWidth * 2) * ((time * 0.13) % 1) - sweepWidth
        local sweepAlpha = math.floor(edgeAlpha * (0.45 + 0.20 * math.sin(time * 1.7)))

        local neonPrimary = colorWithAlpha(coldPrimary, edgeAlpha)
        local neonSecondary = colorWithAlpha(coldSecondary, edgeAlpha)

        gradientRectCompat(Vec2(0, 0), Vec2(width, edgeSize), colorWithAlpha(coldPrimary, edgeSoftAlpha), colorWithAlpha(coldPrimary, 0), false)
        gradientRectCompat(Vec2(0, height - edgeSize), Vec2(width, edgeSize), colorWithAlpha(coldSecondary, 0), colorWithAlpha(coldSecondary, edgeSoftAlpha), false)
        gradientRectCompat(Vec2(0, 0), Vec2(edgeSize, height), colorWithAlpha(coldPrimary, edgeSoftAlpha), colorWithAlpha(coldPrimary, 0), true)
        gradientRectCompat(Vec2(width - edgeSize, 0), Vec2(edgeSize, height), colorWithAlpha(coldSecondary, 0), colorWithAlpha(coldSecondary, edgeSoftAlpha), true)

        -- Corner accents only (premium HUD look) instead of full rectangular border.
        Render.Line(Vec2(inset, inset), Vec2(cornerLen, inset), neonPrimary, lineThickness)
        Render.Line(Vec2(inset, inset), Vec2(inset, cornerLen), neonPrimary, lineThickness)

        Render.Line(Vec2(width - cornerLen, inset), Vec2(width - inset, inset), neonPrimary, lineThickness)
        Render.Line(Vec2(width - inset, inset), Vec2(width - inset, cornerLen), neonPrimary, lineThickness)

        Render.Line(Vec2(inset, height - inset), Vec2(cornerLen, height - inset), neonSecondary, lineThickness)
        Render.Line(Vec2(inset, height - cornerLen), Vec2(inset, height - inset), neonSecondary, lineThickness)

        Render.Line(Vec2(width - cornerLen, height - inset), Vec2(width - inset, height - inset), neonSecondary, lineThickness)
        Render.Line(Vec2(width - inset, height - cornerLen), Vec2(width - inset, height - inset), neonSecondary, lineThickness)

        -- Subtle moving sweep at top edge.
        if sweepAlpha > 0 then
            gradientRectCompat(
                Vec2(sweepX, 0),
                Vec2(sweepWidth, math.max(2, math.floor(2 * screenScale))),
                colorWithAlpha(coldPrimary, 0),
                colorWithAlpha(coldPrimary, sweepAlpha),
                true
            )
        end

        if Render and Render.Shadow then
            Render.Shadow(Vec2(0, 0), Vec2(width, 1), colorWithAlpha(coldPrimary, math.floor(edgeAlpha * 0.28)), 5)
            Render.Shadow(Vec2(0, height - 1), Vec2(width, height), colorWithAlpha(coldSecondary, math.floor(edgeAlpha * 0.24)), 5)
            Render.Shadow(Vec2(0, 0), Vec2(1, height), colorWithAlpha(coldPrimary, math.floor(edgeAlpha * 0.18)), 4)
            Render.Shadow(Vec2(width - 1, 0), Vec2(width, height), colorWithAlpha(coldSecondary, math.floor(edgeAlpha * 0.18)), 4)
        end
    end

    if cursorHaloX and cursorHaloY and settings.particleCursorInteraction then
        local haloPulse = 0.88 + math.sin(time * 2.2) * 0.12
        local haloRadius = 66 + haloPulse * 14
        local haloAlpha = math.floor(CONSTANTS.HALO_ALPHA_BASE * fadeInAlpha)
        local basePos = Vec2(cursorHaloX, cursorHaloY)
        local trailPos = Vec2(cursorHaloX - cursorHaloOffsetX, cursorHaloY - cursorHaloOffsetY)

        if Render and Render.CircleGradient then
            Render.CircleGradient(basePos, haloRadius * 2.05, colorWithAlpha(primaryColor, math.floor(haloAlpha * 0.14)), colorWithAlpha(primaryColor, 0))
            Render.CircleGradient(trailPos, haloRadius * 1.35, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.20)), colorWithAlpha(secondaryColor, 0))
            Render.CircleGradient(basePos, haloRadius * 1.0, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.38)), colorWithAlpha(primaryColor, 0))
            Render.CircleGradient(basePos, haloRadius * 0.48, colorWithAlpha(makeColor(255, 255, 255, 255), math.floor(haloAlpha * 0.36)), colorWithAlpha(primaryColor, 0))
        else
            Render.FilledCircle(basePos, haloRadius * 1.55, colorWithAlpha(primaryColor, math.floor(haloAlpha * 0.18)), 20)
            Render.FilledCircle(trailPos, haloRadius * 1.1, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.20)), 18)
            Render.FilledCircle(basePos, haloRadius * 0.72, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.32)), 18)
        end

        if Render and Render.ShadowCircle then
            Render.ShadowCircle(basePos, haloRadius * 0.62, colorWithAlpha(primaryColor, math.floor(haloAlpha * 0.26)), haloRadius * 0.75)
        end
    end

    if settings.cursorStardust then
        DrawCursorStardust(primaryColor, secondaryColor, fadeInAlpha)
    end

    if settings.stars then
        local multiLayer = settings.multiLayerStars
        for i, star in ipairs(starActive) do
            local layer = star.layer or 2
            local layerParallax = STAR_LAYER_PARALLAX[layer] or 0.52
            local layerAlphaMul = STAR_LAYER_ALPHA[layer] or 1.0
            local layerSizeMul = STAR_LAYER_SIZE[layer] or 1.0
            local layerDriftMul = STAR_LAYER_DRIFT[layer] or 1.0
            local glintBoost = star.glintBoost or 0
            local alpha = math.floor(star.brightness * 255 * fadeInAlpha * layerAlphaMul * (1 + glintBoost * 1.4))
            local starParallax = (0.12 + star.size * 0.03) * layerParallax * (multiLayer and 1 or 0.65)
            local drawX = toRenderX(star.x + sceneParallaxX * starParallax)
            local drawY = toRenderY(star.y + sceneParallaxY * starParallax * layerDriftMul)
            local drawSize = star.size * (multiLayer and layerSizeMul or 1.0)

            local coreColor
            if multiLayer and layer == 1 then
                coreColor = mixColors(secondaryColor, makeColor(170, 195, 235, 255), 0.55, alpha)
            elseif multiLayer and layer == 3 then
                coreColor = mixColors(primaryColor, makeColor(255, 255, 255, 255), 0.42, alpha)
            else
                local tint = 0.12 + math.sin(star.twinklePhase + i * 0.17) * 0.08
                coreColor = mixColors(makeColor(255, 255, 255, alpha), primaryColor, tint, alpha)
            end

            DrawStarHalo(drawX, drawY, drawSize, coreColor, alpha, glintBoost)
            Render.FilledCircle(Vec2(drawX, drawY), drawSize, coreColor, 8)
            Render.FilledCircle(
                Vec2(drawX, drawY),
                math.max(0.5, drawSize * 0.38),
                makeColor(255, 255, 255, math.floor(alpha * (0.45 + (glintBoost or 0) * 0.25))),
                6
            )

            if glintBoost > 0.15 then
                local glintAlpha = math.floor(alpha * glintBoost * 0.55)
                if glintAlpha > 0 and Render and Render.CircleGradient then
                    Render.CircleGradient(
                        Vec2(drawX, drawY),
                        drawSize * (5 + glintBoost * 4),
                        colorWithAlpha(makeColor(255, 255, 255, 255), glintAlpha),
                        colorWithAlpha(primaryColor, 0)
                    )
                end
            end

            if drawStarRays and (star.brightness > CONSTANTS.STAR_RAY_BRIGHTNESS_THRESHOLD or glintBoost > 0.2) and layer >= 2 then
                DrawStarDiffractionRays(drawX, drawY, drawSize, alpha, star.rayAngle or 0, glintBoost)
            end
        end
    end

    if settings.shootingStars then
        for _, star in ipairs(shootingStarPool) do
            if star.active then
                DrawShootingStar(star, toRenderX, toRenderY, fadeInAlpha, primaryColor, secondaryColor)
            end
        end
    end

    local c1 = primaryColor
    local c2 = secondaryColor
    local particleSize = settings.particleSize
    local particleBaseAlpha = settings.particleBaseAlpha
    local particleGlowScale = settings.particleGlowScale
    local particleGlowAlphaScale = settings.particleGlowAlpha * 0.01
    local particleGlowEnabled = settings.particleGlow
    local particleSoftCore = settings.particleSoftCore
    local particleLinksEnabled = settings.particleConnections
    local connectionDist = settings.particleConnectionDist
    local maxConnections, skipLinkFrame = GetLinkLodSettings(settings, #bgParticleActive)
    local linkBaseAlpha = settings.particleConnectionAlpha
    local linkWidth = settings.particleConnectionWidth
    local coloredLinks = settings.particleColoredLinks
    local nodePhase = math.floor(time * 1.2)

    for i, particle in ipairs(bgParticleActive) do
        local pColor = particle.colorIdx == 1 and c1 or c2
        if not pColor then
            pColor = c1 or c2
        end
        if not pColor then
            goto continue_particle
        end

        local alpha = math.floor(particle.brightness * particleBaseAlpha * fadeInAlpha)
        local sizeScale = (posScaleX + posScaleY) * 0.5
        local radius = particle.size * particleSize * (particle.depth or 1) * 0.85 * sizeScale
        local parallaxStrength = 0.22 + (particle.depth or 1) * 0.28
        local drawX = toRenderX(particle.x + sceneParallaxX * parallaxStrength)
        local drawY = toRenderY(particle.y + sceneParallaxY * parallaxStrength)

        particle.drawX = drawX
        particle.drawY = drawY

        if particleGlowEnabled then
            local glowPulse = 0.82 + (particle.brightness or 0.6) * 0.28
            local glowSize = math.min(radius * particleGlowScale, 42)
            local glowAlpha = math.floor(alpha * particleGlowAlphaScale * glowPulse * 1.1)
            if glowAlpha > 0 then
                local useGradientGlow = qualityScale >= CONSTANTS.GLOW_QUALITY_THRESHOLD and #bgParticleActive <= 180
                if useGradientGlow and Render and Render.CircleGradient then
                    local warm = mixColors(pColor, makeColor(255, 255, 255, 255), 0.28)
                    Render.CircleGradient(
                        Vec2(drawX, drawY),
                        glowSize,
                        colorWithAlpha(pColor, math.floor(glowAlpha * 0.45)),
                        colorWithAlpha(warm, math.floor(glowAlpha * 0.2))
                    )
                else
                    Render.FilledCircle(Vec2(drawX, drawY), glowSize, Color(pColor.r, pColor.g, pColor.b, math.floor(glowAlpha * 0.7)), 14)
                    Render.FilledCircle(Vec2(drawX, drawY), glowSize * 0.55, Color(255, 255, 255, math.floor(glowAlpha * 0.18)), 10)
                end
            end
        end

        if particleSoftCore then
            Render.FilledCircle(Vec2(drawX, drawY), radius * 1.8, Color(pColor.r, pColor.g, pColor.b, math.floor(alpha * 0.25)), 12)
        end

        Render.FilledCircle(Vec2(drawX, drawY), radius, Color(pColor.r, pColor.g, pColor.b, alpha), 8)
        Render.FilledCircle(Vec2(drawX, drawY), math.max(0.6, radius * 0.42), Color(255, 255, 255, math.floor(alpha * 0.58)), 8)

        ::continue_particle::
    end

    if particleLinksEnabled and maxConnections > 0 and connectionDist > 0 and not skipLinkFrame then
        local renderConnectionDist = connectionDist * ((posScaleX + posScaleY) * 0.5)
        local linkCursorPos = nil
        if settings.particleCursorInteraction and cursorHaloX and cursorHaloY then
            linkCursorPos = Vec2(cursorHaloX, cursorHaloY)
        end
        local enableLinkPulse = qualityScale >= CONSTANTS.LINK_LOD_QUALITY_THRESHOLD
        DrawParticleLinks(
            bgParticleActive,
            c1,
            c2,
            renderConnectionDist,
            renderConnectionDist * renderConnectionDist,
            maxConnections,
            linkBaseAlpha,
            linkWidth,
            coloredLinks,
            fadeInAlpha,
            nodePhase,
            linkCursorPos,
            enableLinkPulse
        )
    end

    DrawDebugOverlay(settings, fadeInAlpha, width, height)
end

--#endregion

--#region Lifecycle

function Script.OnUpdateEx()
    if not Script.enabled or not Script.enabled.Get then
        return
    end
    if not Script.enabled:Get() then
        return
    end

    UpdateCosmicSimulation(GetAnimationDt())
end

function Script.OnFrame()
    if not Script.enabled or not Script.enabled.Get then
        return
    end
    if not Script.enabled:Get() then
        return
    end
    if not IsMenuOpen() then
        return
    end

    DrawBackgroundEffects(State.fadeInAlpha)
end

function Script.OnThemeUpdate()
    RefreshThemeCache()
end

function Script.OnGameEnd()
    deactivatePoolObjects(bgParticlePool)
    deactivatePoolObjects(starPool)
    deactivatePoolObjects(shootingStarPool)
    deactivatePoolObjects(ambientStreakPool)
    deactivatePoolObjects(flyingRocketPool)

    for i, star in ipairs(shootingStarPool) do
        if star.tail then
            clearList(star.tail)
        end
    end

    clearList(bgParticleActive)
    clearList(starActive)
    clearList(ambientStreakActive)
    clearList(flyingRocketActive)
    clearList(stardustTrail)

    time = 0
    fadeInTime = 0
    menuWasOpen = false
    menuClosedFrames = 0
    menuClosedAccumulated = 0
    lastRealTime = nil
    State.shootingStarsWasEnabled = nil
    State.starsWasEnabled = nil
    State.multiLayerWasEnabled = nil
    State.flyingRocketsWasEnabled = nil
    State.rocketSoloActive = false
    State.rocketSoloSnapshot = nil
    State.fadeInAlpha = 1
    State.frameSettings = nil
    State.menuIdleTime = 0
    State.simulationPaused = false
    State.linkGridSkipFrame = false
    State.lastDt = 0
    State.debugFont = nil
    State.blockCustomPresetMarks = 0
    State.cachedFullScreenSize = nil
    State.lastRawScreenSize = nil
    baseScreenMinDim = nil
    baseScreenArea = nil
    screenSize = Vec2(1, 1)
    resetRuntimeState()
end

--#endregion

return Script
