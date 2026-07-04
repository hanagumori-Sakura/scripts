--[[
    Cosmic Menu
    Full-screen cosmic overlay while the Umbrella menu is open.
    Accent colors always follow Menu.Style / OnThemeUpdate.
    Script by Euphoria
--]]

local Script = {}

--#region Constants

local CONSTANTS = {
    DT_DEFAULT = 0.016,
    ANIMATION_DT_MIN = 0.001,
    ANIMATION_DT_MAX = 0.05,
    PARTICLE_CONNECTION_DIST = 150,
    PARTICLE_MAX_CONNECTIONS = 3,
    SHOOTING_STAR_TAIL_LENGTH = 20,
    SHOOTING_STAR_MAX_LIFETIME = 5,
    STAR_RAY_BRIGHTNESS_THRESHOLD = 0.8,
    SHOOTING_STAR_SPEED_MOD = 0.5,
    FADE_IN_DURATION = 1.5,
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
}

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
    },
}

local THEME_STYLE_KEYS = {"accent", "secondary", "highlight", "active", "text", "primary"}

--#endregion

--#region State

local State = {
    primaryColor = nil,
    secondaryColor = nil,
    fadeInAlpha = 1,
    shootingStarsWasEnabled = nil,
    starsWasEnabled = nil,
    multiLayerWasEnabled = nil,
    lastQualityPreset = nil,
    applyingPreset = false,
    displayPrimary = nil,
    displaySecondary = nil,
    targetPrimary = nil,
    targetSecondary = nil,
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
local baseScreenMinDim = nil
local baseScreenArea = nil
local adaptiveFallbackMaxW = 0
local adaptiveFallbackMaxH = 0

local screenSize = Vec2(1, 1)

local bgParticlePool = {}
local bgParticleActive = {}
local starPool = {}
local starActive = {}
local shootingStarPool = {}
local ambientStreakPool = {}
local ambientStreakActive = {}
local linkSpatialGrid = {}

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

local function getAdaptiveFallbackScreenSize()
    local bestW = 0
    local bestH = 0

    local function considerCandidate(size)
        if not size or not size.x or not size.y then
            return
        end

        local cw = math.floor(size.x)
        local ch = math.floor(size.y)
        if cw > bestW then bestW = cw end
        if ch > bestH then bestH = ch end
    end

    considerCandidate(screenSize)

    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok and type(x) == "number" and type(y) == "number" then
            local estW = math.max(640, math.floor(x * 2))
            local estH = math.max(360, math.floor(y * 2))
            considerCandidate(Vec2(estW, estH))
        end

        ok, x, y = pcall(function() return Input:GetCursorPos() end)
        if ok and type(x) == "number" and type(y) == "number" then
            local estW = math.max(640, math.floor(x * 2))
            local estH = math.max(360, math.floor(y * 2))
            considerCandidate(Vec2(estW, estH))
        end
    end

    if Menu and Menu.Pos and Menu.Size then
        local okPos, menuPos = pcall(Menu.Pos)
        local okSize, menuSize = pcall(Menu.Size)
        if okPos and okSize and menuPos and menuSize and menuPos.x and menuPos.y and menuSize.x and menuSize.y then
            local estW = math.max(640, math.floor((menuPos.x + menuSize.x) * 2))
            local estH = math.max(360, math.floor((menuPos.y + menuSize.y) * 2))
            considerCandidate(Vec2(estW, estH))
        end
    end

    if bestW > adaptiveFallbackMaxW then
        adaptiveFallbackMaxW = bestW
    end
    if bestH > adaptiveFallbackMaxH then
        adaptiveFallbackMaxH = bestH
    end

    if adaptiveFallbackMaxW > 1 and adaptiveFallbackMaxH > 1 then
        return Vec2(adaptiveFallbackMaxW, adaptiveFallbackMaxH)
    end

    return Vec2(1280, 720)
end

local function GetBestScreenSize()
    local candidates = {}

    local function addCandidate(value, valueB)
        local normalized = normalizeScreenSize(value, valueB)
        if normalized then
            candidates[#candidates + 1] = normalized
        end
    end

    if Render and Render.ScreenSize then
        local ok, size = SafeCall(Render.ScreenSize)
        if ok then
            addCandidate(size)
        end
    end

    if Renderer and Renderer.GetScreenSize then
        local ok, size = SafeCall(Renderer.GetScreenSize)
        if ok then
            addCandidate(size)
        end
    end

    if Engine and Engine.GetScreenSize then
        local ok, a, b = SafeCall(Engine.GetScreenSize)
        if ok then
            addCandidate(a, b)
        end
    end

    local best = nil
    local bestArea = 0
    for i, candidate in ipairs(candidates) do
        local area = candidate.x * candidate.y
        if area > bestArea then
            bestArea = area
            best = candidate
        end
    end

    if best then
        updateScreenBaselines(best)
        return Vec2(best.x, best.y)
    end

    local fallback = getAdaptiveFallbackScreenSize()
    updateScreenBaselines(fallback)
    return fallback
end

local function GetScreenSize()
    return GetBestScreenSize()
end

local function GetLiveRenderScreenSize()
    if Render and Render.ScreenSize then
        local ok, size = SafeCall(Render.ScreenSize)
        if ok then
            local normalized = normalizeScreenSize(size)
            if normalized then
                return Vec2(normalized.x, normalized.y)
            end
        end
    end

    if Renderer and Renderer.GetScreenSize then
        local ok, size = SafeCall(Renderer.GetScreenSize)
        if ok then
            local normalized = normalizeScreenSize(size)
            if normalized then
                return Vec2(normalized.x, normalized.y)
            end
        end
    end

    return Vec2(screenSize.x, screenSize.y)
end

local function CaptureScreenSizeForMenuSession()
    local size = GetBestScreenSize()
    local liveSize = GetLiveRenderScreenSize()
    if liveSize.x * liveSize.y > size.x * size.y then
        size = liveSize
    end

    if not size or not size.x or not size.y or size.x <= 1 or size.y <= 1 then
        return
    end

    local previousSize = screenSize
    if previousSize.x > 1 and previousSize.y > 1 then
        local widthRatio = size.x / previousSize.x
        local heightRatio = size.y / previousSize.y
        if math.abs(widthRatio - 1) > 0.05 or math.abs(heightRatio - 1) > 0.05 then
            remapPoolPositionsForScreenChange(previousSize, size)
        end
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

local function getScreenScale()
    local currentMinDim = math.min(screenSize.x or 1, screenSize.y or 1)
    local baselineMinDim = baseScreenMinDim and math.max(baseScreenMinDim, 1) or math.max(currentMinDim, 1)
    return clamp(currentMinDim / baselineMinDim, 0.75, 1.8)
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

local function createStar()
    local w, h = GetSafeScreenDimensions()
    local star = {
        x = randomRangeSafe(0, w),
        y = randomRangeSafe(0, h),
        size = math.random(1, 3),
        twinkleSpeed = math.random(1, 5),
        twinklePhase = math.random() * math.pi * 2,
        brightness = math.random(50, 100) / 100,
        layer = 2,
        active = true
    }
    assignStarLayer(star)
    return star
end

local function createShootingStar()
    local w, h = GetSafeScreenDimensions()
    return {
        startX = randomRangeSafe(0, w),
        startY = math.random(-100, 0),
        endX = randomRangeSafe(0, w),
        endY = randomRangeSafe(h, h + 200),
        progress = 0,
        speed = math.random(5, 20) / 10,
        size = math.random(2, 4),
        tail = {},
        lifetime = 0,
        active = false
    }
end

local function createAmbientStreak()
    local w, h = GetSafeScreenDimensions()
    local tilt = (math.random() * 2 - 1) * 0.18
    local angle = math.rad(-12) + tilt
    return {
        x = randomRangeSafe(-w, w),
        y = randomRangeSafe(0, h),
        length = math.random(70, 220),
        speed = math.random(8, 26) / 10,
        angle = angle,
        alpha = math.random(7, 18),
        width = math.random(1, 2),
        drift = (math.random() * 2 - 1) * 12,
        progress = math.random(),
        active = true,
    }
end

local function resetAmbientStreak(streak)
    local w, h = GetSafeScreenDimensions()
    local tilt = (math.random() * 2 - 1) * 0.18
    streak.x = randomRangeSafe(-math.floor(w * 0.25), w)
    streak.y = randomRangeSafe(0, h)
    streak.length = math.random(70, 220)
    streak.speed = math.random(8, 26) / 10
    streak.angle = math.rad(-12) + tilt
    streak.alpha = math.random(7, 18)
    streak.width = math.random(1, 2)
    streak.drift = (math.random() * 2 - 1) * 12
    streak.progress = 0
    streak.active = true
end

local function resetShootingStar(star)
    local w, h = GetSafeScreenDimensions()

    star.startX = randomRangeSafe(0, w)
    star.startY = math.random(-100, 0)
    star.endX = randomRangeSafe(0, w)
    star.endY = randomRangeSafe(h, h + 200)
    star.progress = 0
    star.speed = math.random(5, 20) / 10
    star.size = math.random(2, 4)
    star.lifetime = 0
    star.active = true
    star.tail = star.tail or {}
    clearList(star.tail)
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
    if lastTargetCount > 0 and math.abs(targetCount - lastTargetCount) < CONSTANTS.POOL_REBALANCE_HYSTERESIS then
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
    resetParticleImpulses()
    openRippleTime = 0
    clearList(stardustTrail)
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

local function pushStardustPoint(x, y)
    table.insert(stardustTrail, 1, {x = x, y = y, life = 1.0})
    while #stardustTrail > CONSTANTS.STARDUST_MAX_POINTS do
        table.remove(stardustTrail)
    end
end

local function updateStardustTrail(dt, cursorPos, frameCursorDeltaLen)
    if not Script.cursorStardust or not Script.cursorStardust:Get() then
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

local function DrawOpenRipple(width, height, primaryColor, fadeInAlpha)
    if openRippleTime >= CONSTANTS.RIPPLE_DURATION then
        return
    end

    local t = openRippleTime / CONSTANTS.RIPPLE_DURATION
    local centerX = width * 0.5
    local centerY = height * 0.5
    local maxRadius = math.sqrt(centerX * centerX + centerY * centerY) * 1.08

    for ring = 1, 2 do
        local ringDelay = (ring - 1) * 0.14
        local ringT = clamp((t - ringDelay) / (1 - ringDelay), 0, 1)
        if ringT > 0 and ringT < 1 then
            local radius = maxRadius * ringT
            local alpha = math.floor((1 - ringT) * 52 * fadeInAlpha / ring)
            if alpha > 0 then
                Render.Circle(Vec2(centerX, centerY), radius, colorWithAlpha(primaryColor, alpha), 1.4)
            end
        end
    end
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

local function SyncEffectTogglePools()
    local starsEnabled = Script.stars and Script.stars:Get()
    if State.starsWasEnabled == true and not starsEnabled then
        deactivatePoolObjects(starPool)
        clearList(starActive)
    end
    State.starsWasEnabled = starsEnabled

    local shootingEnabled = Script.shootingStars and Script.shootingStars:Get()
    if State.shootingStarsWasEnabled == true and not shootingEnabled then
        ClearShootingStarPool()
    end
    State.shootingStarsWasEnabled = shootingEnabled
end

local function ApplyQualityPreset(presetIndex)
    local preset = QUALITY_PRESETS[presetIndex]
    if not preset or State.applyingPreset then
        return
    end

    State.applyingPreset = true
    for key, value in pairs(preset) do
        WidgetSet(Script[key], value)
    end
    State.applyingPreset = false
    State.lastQualityPreset = presetIndex
end

local function MaybeApplyQualityPreset()
    if not Script.qualityPreset or not Script.qualityPreset.Get then
        return
    end

    local presetIndex = clamp(roundToInt(Script.qualityPreset:Get()), 1, #QUALITY_PRESETS)
    if State.lastQualityPreset ~= presetIndex then
        ApplyQualityPreset(presetIndex)
    end
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

local function DrawParticleLinks(particles, c1, c2, connectionDist, connectionDistSq, maxConnections, linkBaseAlpha, linkWidth, coloredLinks, fadeInAlpha, nodePhase)
    if #particles < 2 then
        return
    end

    BuildParticleSpatialGrid(particles, connectionDist)
    local invCellSize = 1 / math.max(connectionDist, 1)

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
                            local dx = (p2.drawX or p2.x) - x1
                            local dy = (p2.drawY or p2.y) - y1
                            local distSq = dx * dx + dy * dy

                            if distSq < connectionDistSq then
                                local alpha = math.floor((1 - (distSq / connectionDistSq)) * linkBaseAlpha * fadeInAlpha)
                                if alpha > 0 then
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
                                        Render.Line(Vec2(p1.drawX or p1.x, p1.drawY or p1.y), Vec2(p2.drawX or p2.x, p2.drawY or p2.y), lineColor, lineWidthNow)
                                    else
                                        Render.Line(Vec2(p1.drawX or p1.x, p1.drawY or p1.y), Vec2(p2.drawX or p2.x, p2.drawY or p2.y), Color(255, 255, 255, alpha), lineWidthNow)
                                    end

                                    if isConstellationLink then
                                        local nodeAlpha = math.floor(alpha * 0.8)
                                        Render.FilledCircle(Vec2(p1.drawX or p1.x, p1.drawY or p1.y), 1.8, colorWithAlpha(c1, nodeAlpha), 12)
                                        Render.FilledCircle(Vec2(p2.drawX or p2.x, p2.drawY or p2.y), 1.8, colorWithAlpha(c2, nodeAlpha), 12)
                                    end
                                end
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
    tab = "\u{f186}",            -- moon
    enable = "\u{f011}",         -- power-off
    quality = "\u{f0ae}",        -- tachometer-alt
    fadeIn = "\u{f358}",         -- fill-drip
    blur = "\u{f0b0}",           -- filter
    blurIntensity = "\u{f1de}",  -- sliders-h
    colorWash = "\u{f53f}",      -- palette
    vignette = "\u{f565}",       -- crop-alt
    hudCorners = "\u{f5cb}",     -- border-all
    streaks = "\u{f76d}",        -- meteor
    streakCount = "\u{f03b}",    -- list-ol
    parallax = "\u{f0b2}",       -- arrows-alt
    parallaxStrength = "\u{f065}", -- expand-arrows-alt
    starRays = "\u{f185}",       -- sun
    particleCount = "\u{f1bb}",  -- project-diagram
    particleSize = "\u{f111}",   -- circle
    opacity = "\u{f06e}",        -- eye
    softCore = "\u{f1db}",       -- circle-notch
    glow = "\u{f0eb}",           -- lightbulb
    glowSize = "\u{f185}",       -- sun
    glowOpacity = "\u{f042}",    -- adjust
    stars = "\u{f005}",          -- star
    starCount = "\u{f4d8}",      -- star-of-life
    shootingStars = "\u{f135}",  -- rocket
    frequency = "\u{f017}",      -- clock
    speed = "\u{f70c}",          -- person-running
    drift = "\u{f72e}",          -- wind
    twinkleSpeed = "\u{f0e7}",   -- bolt
    twinkleAmount = "\u{f069}",  -- asterisk
    links = "\u{f0c1}",          -- link
    distance = "\u{f4a6}",       -- ruler-combined
    linkOpacity = "\u{f06e}",    -- eye
    linkWidth = "\u{f545}",      -- ruler-horizontal
    perParticle = "\u{f126}",    -- code-branch
    coloredLinks = "\u{f1fc}",   -- paint-brush
    cursor = "\u{f245}",         -- mouse-pointer
    cursorMode = "\u{f074}",     -- random (mode picker)
    radius = "\u{f192}",         -- bullseye
    force = "\u{f0e7}",          -- bolt
    falloff = "\u{f201}",        -- chart-line
    motionBoost = "\u{f062}",    -- arrow-up
    threshold = "\u{f1ec}",      -- calculator
    onlyMoving = "\u{f04b}",     -- play
    damping = "\u{f862}",        -- wave-square
    swirl = "\u{f2f1}",          -- sync-alt
    ripple = "\u{f067}",         -- plus-circle
    horizonGrid = "\u{f547}",    -- grip-lines
    multiLayerStars = "\u{f5fd}", -- layer-group
    stardust = "\u{f890}",       -- sparkles
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

    Script.qualityPreset = g_general:Slider(L("Quality Preset", "Пресет качества"), 1, 5, 3, function(value)
        local mode = roundToInt(value)
        if mode == 1 then return L("Low", "Низкий") end
        if mode == 2 then return L("Medium", "Средний") end
        if mode == 3 then return L("High", "Высокий") end
        if mode == 4 then return L("Ultra", "Ультра") end
        if mode == 5 then return L("Zen", "Дзен") end
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
        g_backdrop:Switch(L("Open Ripple", "Волна при открытии"), true, Icons.ripple),
        "Expanding ring when the menu opens",
        "Расходящееся кольцо при открытии меню"
    )
    Script.horizonGrid = WithTooltip(
        g_backdrop:Switch(L("Horizon Grid", "Синтвейв-сетка"), false, Icons.horizonGrid),
        "Perspective grid at the bottom of the screen",
        "Перспективная сетка внизу экрана"
    )

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

    State.lastQualityPreset = clamp(roundToInt(Script.qualityPreset:Get()), 1, #QUALITY_PRESETS)
    RefreshThemeCache()
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
        menuClosedFrames = menuClosedFrames + 1
        menuClosedAccumulated = menuClosedAccumulated + 1

        if menuClosedFrames >= CONSTANTS.MENU_CLOSE_FLICKER_FRAMES then
            menuWasOpen = false
            State.fadeInAlpha = 0
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
    SyncEffectTogglePools()

    if Script.multiLayerStars then
        local multiLayerEnabled = Script.multiLayerStars:Get()
        if State.multiLayerWasEnabled ~= multiLayerEnabled then
            starLayerCounter = 0
            for i, star in ipairs(starPool) do
                if star.active then
                    assignStarLayer(star)
                end
            end
            State.multiLayerWasEnabled = multiLayerEnabled
        end
    end

    local fadeInAlpha = 1
    if Script.fadeInEffect and Script.fadeInEffect:Get() and fadeInTime < CONSTANTS.FADE_IN_DURATION then
        fadeInAlpha = fadeInTime / CONSTANTS.FADE_IN_DURATION
    end
    State.fadeInAlpha = fadeInAlpha

    local areaScale = getScreenAreaScale()
    local countQuality = qualityScaleForCounts
    local bgTargetCount = clamp(roundToInt(Script.bgParticleCount:Get() * areaScale * countQuality), 20, 700)
    local starsEnabled = Script.stars and Script.stars:Get()
    local starTargetCount = starsEnabled and clamp(roundToInt(Script.starCount:Get() * areaScale * (0.88 + countQuality * 0.12)), 60, 700) or 0
    local streakBase = Script.ambientStreakCount and Script.ambientStreakCount:Get() or 16
    local streaksEnabled = Script.ambientStreaks and Script.ambientStreaks:Get()
    local streakTargetCount = streaksEnabled and clamp(roundToInt(streakBase * areaScale * countQuality), 0, 28) or 0

    lastBgTargetCount = rebalancePoolIfChanged(bgParticlePool, bgTargetCount, lastBgTargetCount, createBgParticle, function(particle)
        particle.impulseX = 0
        particle.impulseY = 0
    end)
    lastStarTargetCount = rebalancePoolIfChanged(starPool, starTargetCount, lastStarTargetCount, createStar, assignStarLayer)
    lastStreakTargetCount = rebalancePoolIfChanged(ambientStreakPool, streakTargetCount, lastStreakTargetCount, createAmbientStreak, resetAmbientStreak)

    collectActive(bgParticlePool, bgParticleActive)
    collectActive(starPool, starActive)
    collectActive(ambientStreakPool, ambientStreakActive)

    local w, h = screenSize.x, screenSize.y
    local particleSpeedScale = (Script.particleSpeedScale and Script.particleSpeedScale:Get() or 100) * 0.01
    local particleDrift = (Script.particleDrift and Script.particleDrift:Get() or 35) * 0.01
    local particleTwinkleSpeedScale = (Script.particleTwinkleSpeedScale and Script.particleTwinkleSpeedScale:Get() or 100) * 0.01
    local particleTwinkleAmount = (Script.particleTwinkleAmount and Script.particleTwinkleAmount:Get() or 30) * 0.01
    local wrapMargin = 50
    local cursorInteractionEnabled = Script.particleCursorInteraction and Script.particleCursorInteraction:Get()
    local cursorTrackingEnabled = cursorInteractionEnabled
        or (Script.cursorStardust and Script.cursorStardust:Get())
        or (Script.parallax and Script.parallax:Get())
    local cursorPos = nil
    local frameCursorDeltaX = 0
    local frameCursorDeltaY = 0
    local frameCursorDeltaLen = 0
    local rawCursorMode = Script.particleCursorMode and Script.particleCursorMode:Get() or 1
    local cursorMode = clamp(roundToInt(rawCursorMode), 1, 3)
    local cursorRadius = Script.particleCursorRadius and Script.particleCursorRadius:Get() or 180
    local cursorRadiusSq = cursorRadius * cursorRadius
    local cursorForce = Script.particleCursorForce and Script.particleCursorForce:Get() or 3200
    local cursorFalloffExp = (Script.particleCursorFalloff and Script.particleCursorFalloff:Get() or 120) * 0.01
    local cursorMotionBoost = (Script.particleCursorMotionBoost and Script.particleCursorMotionBoost:Get() or 120) * 0.01
    local cursorMoveThreshold = Script.particleCursorMoveThreshold and Script.particleCursorMoveThreshold:Get() or 1
    local cursorOnlyMoving = Script.particleCursorOnlyMoving and Script.particleCursorOnlyMoving:Get()
    local cursorImpulseDecay = clamp(1 - ((Script.particleCursorImpulseDamping and Script.particleCursorImpulseDamping:Get() or 90) * 0.01) * 4 * dt, 0, 1)
    local cursorSwirl = (Script.particleCursorSwirl and Script.particleCursorSwirl:Get() or 0) * 0.01

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

    if cursorPos and cursorInteractionEnabled then
        cursorHaloX = cursorPos.x
        cursorHaloY = cursorPos.y
        local targetHaloOffsetX = clamp(frameCursorDeltaX * 0.55, -18, 18)
        local targetHaloOffsetY = clamp(frameCursorDeltaY * 0.55, -18, 18)
        local haloOffsetLerp = clamp(dt * 8.0, 0, 1)

        cursorHaloOffsetX = lerp(cursorHaloOffsetX, targetHaloOffsetX, haloOffsetLerp)
        cursorHaloOffsetY = lerp(cursorHaloOffsetY, targetHaloOffsetY, haloOffsetLerp)

        local centerX = w * 0.5
        local centerY = h * 0.5
        local parallaxEnabled = Script.parallax and Script.parallax:Get()
        local parallaxMul = (Script.parallaxStrength and Script.parallaxStrength:Get() or 100) * 0.01
        local targetParallaxX = 0
        local targetParallaxY = 0

        if parallaxEnabled then
            targetParallaxX = clamp((cursorPos.x - centerX) / math.max(centerX, 1), -1, 1) * 16 * parallaxMul
            targetParallaxY = clamp((cursorPos.y - centerY) / math.max(centerY, 1), -1, 1) * 10 * parallaxMul
        end

        local parallaxLerp = clamp(dt * 4.5, 0, 1)

        sceneParallaxX = lerp(sceneParallaxX, targetParallaxX, parallaxLerp)
        sceneParallaxY = lerp(sceneParallaxY, targetParallaxY, parallaxLerp)
    elseif cursorPos then
        local parallaxLerp = clamp(dt * 4.5, 0, 1)
        local centerX = w * 0.5
        local centerY = h * 0.5
        local parallaxEnabled = Script.parallax and Script.parallax:Get()
        local parallaxMul = (Script.parallaxStrength and Script.parallaxStrength:Get() or 100) * 0.01
        local targetParallaxX = 0
        local targetParallaxY = 0

        if parallaxEnabled then
            targetParallaxX = clamp((cursorPos.x - centerX) / math.max(centerX, 1), -1, 1) * 16 * parallaxMul
            targetParallaxY = clamp((cursorPos.y - centerY) / math.max(centerY, 1), -1, 1) * 10 * parallaxMul
        end

        sceneParallaxX = lerp(sceneParallaxX, targetParallaxX, parallaxLerp)
        sceneParallaxY = lerp(sceneParallaxY, targetParallaxY, parallaxLerp)
    else
        local parallaxLerp = clamp(dt * 3.0, 0, 1)
        local haloOffsetLerp = clamp(dt * 6.0, 0, 1)
        sceneParallaxX = lerp(sceneParallaxX, 0, parallaxLerp)
        sceneParallaxY = lerp(sceneParallaxY, 0, parallaxLerp)
        cursorHaloOffsetX = lerp(cursorHaloOffsetX, 0, haloOffsetLerp)
        cursorHaloOffsetY = lerp(cursorHaloOffsetY, 0, haloOffsetLerp)
        cursorHaloX = nil
        cursorHaloY = nil
    end

    updateStardustTrail(dt, cursorPos, frameCursorDeltaLen)

    for i, particle in ipairs(bgParticleActive) do
        particle.angle = particle.angle + (particle.angularVelocity or 0) * particleDrift * dt

        local driftWave = math.sin(time * (particle.driftSpeed or 1) * math.max(0, particleTwinkleSpeedScale) + (particle.driftPhase or i))
        local moveAngle = particle.angle + driftWave * 0.35 * particleDrift * (particle.driftStrength or 1)
        local moveSpeed = particle.speed * 20 * dt * particleSpeedScale * (particle.depth or 1)
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
                        -- Repel: pure radial push away from cursor.
                        forceX = nx * radialForce
                        forceY = ny * radialForce
                    elseif cursorMode == 2 then
                        -- Swipe: directional push by cursor movement, almost no radial component.
                        if frameCursorDeltaLen > 0.001 then
                            local svx = frameCursorDeltaX / frameCursorDeltaLen
                            local svy = frameCursorDeltaY / frameCursorDeltaLen
                            local swipeForce = radialForce * (0.85 + cursorMotionBoost * 0.5)
                            forceX = svx * swipeForce
                            forceY = svy * swipeForce
                        else
                            -- No movement in swipe mode -> no force (keeps mode behavior distinct).
                            forceX = 0
                            forceY = 0
                        end
                    elseif cursorMode == 3 then
                        -- Vortex: pure tangential swirl around cursor.
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
                        -- Safe fallback: behave like Repel.
                        forceX = nx * radialForce
                        forceY = ny * radialForce
                    end

                    impulseX = impulseX + forceX * dt
                    impulseY = impulseY + forceY * dt
                end
            end
        end

        particle.impulseX = impulseX
        particle.impulseY = impulseY
        particle.x = particle.x + impulseX * dt
        particle.y = particle.y + impulseY * dt

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
    end

    if Script.shootingStars and Script.shootingStars:Get() then
        if math.random() < Script.shootingStarFreq:Get() * dt * 0.01 then
            local star = getFromPool(shootingStarPool, createShootingStar)
            resetShootingStar(star)
        end

        for i = #shootingStarPool, 1, -1 do
            local star = shootingStarPool[i]
            if star.active then
                star.progress = star.progress + star.speed * dt * CONSTANTS.SHOOTING_STAR_SPEED_MOD
                star.lifetime = star.lifetime + dt

                if star.progress >= 1 or star.lifetime > CONSTANTS.SHOOTING_STAR_MAX_LIFETIME then
                    star.active = false
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

    for i, streak in ipairs(ambientStreakActive) do
        local driftWave = math.sin(time * 0.45 + i * 0.31) * streak.drift
        streak.progress = streak.progress + dt * streak.speed * (0.7 + qualityScale * 0.6)
        streak.x = streak.x + dt * (15 + driftWave * 0.02)
        streak.y = streak.y - dt * (6 + math.abs(driftWave) * 0.03)

        if streak.progress >= 1 or streak.x > w + streak.length or streak.y < -streak.length then
            resetAmbientStreak(streak)
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

    local renderMinDim = math.min(width, height)
    local screenScale = clamp(renderMinDim / math.max(baseScreenMinDim or renderMinDim, 1), 0.75, 1.8)
    local lowQuality = qualityScale < CONSTANTS.QUALITY_LOW_THRESHOLD
    local drawStarRays = qualityScale >= CONSTANTS.STAR_RAY_QUALITY_THRESHOLD
        and Script.starRays and Script.starRays:Get()
    local drawVignette = not lowQuality and Script.vignette and Script.vignette:Get()
    local drawHudEdges = not lowQuality and Script.hudEdges and Script.hudEdges:Get()
    local drawAmbientStreaks = Script.ambientStreaks and Script.ambientStreaks:Get()

    if Script.backgroundBlur and Script.backgroundBlur:Get() and Script.blurIntensity then
        local blurStrength = clamp(Script.blurIntensity:Get(), 0.1, 1.0)
        Render.Blur(Vec2(0, 0), renderSize, blurStrength, 1.0, 0, Enum.DrawFlags.None)
    end

    if Script.colorWash and Script.colorWash:Get() then
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
    end

    if Script.openRipple and Script.openRipple:Get() then
        DrawOpenRipple(width, height, primaryColor, fadeInAlpha)
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

    if Script.horizonGrid and Script.horizonGrid:Get() then
        DrawHorizonGrid(width, height, primaryColor, secondaryColor, fadeInAlpha)
    end

    if drawAmbientStreaks then
        local streakVisibility = fadeInAlpha * (0.74 + qualityScale * 0.26)
        for i, streak in ipairs(ambientStreakActive) do
            local sway = math.sin(time * 0.8 + i * 0.67)
            local simSx = streak.x + sway * 8
            local simSy = streak.y + sway * 4
            local simEx = simSx + math.cos(streak.angle) * streak.length
            local simEy = simSy + math.sin(streak.angle) * streak.length
            local sx = toRenderX(simSx)
            local sy = toRenderY(simSy)
            local ex = toRenderX(simEx)
            local ey = toRenderY(simEy)
            local alpha = math.floor(streak.alpha * streakVisibility)

            if alpha > 2 then
                Render.Line(Vec2(sx, sy), Vec2(ex, ey), colorWithAlpha(primaryColor, alpha), streak.width)
                Render.Line(
                    Vec2(sx + math.cos(streak.angle) * 6, sy + math.sin(streak.angle) * 6),
                    Vec2(ex, ey),
                    colorWithAlpha(secondaryColor, math.floor(alpha * 0.45)),
                    math.max(1, streak.width - 0.25)
                )
            end
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

    if cursorHaloX and cursorHaloY and Script.particleCursorInteraction and Script.particleCursorInteraction:Get() then
        local haloPulse = 0.88 + math.sin(time * 2.2) * 0.12
        local haloRadius = 66 + haloPulse * 14
        local haloAlpha = math.floor(CONSTANTS.HALO_ALPHA_BASE * fadeInAlpha)
        local basePos = Vec2(cursorHaloX, cursorHaloY)
        local trailPos = Vec2(cursorHaloX - cursorHaloOffsetX, cursorHaloY - cursorHaloOffsetY)

        if Render and Render.CircleGradient then
            Render.CircleGradient(basePos, haloRadius * 1.9, colorWithAlpha(primaryColor, math.floor(haloAlpha * 0.10)), colorWithAlpha(primaryColor, 0))
            Render.CircleGradient(trailPos, haloRadius * 1.25, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.16)), colorWithAlpha(secondaryColor, 0))
            Render.CircleGradient(basePos, haloRadius * 0.92, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.34)), colorWithAlpha(primaryColor, 0))
            Render.CircleGradient(basePos, haloRadius * 0.42, colorWithAlpha(makeColor(255, 255, 255, 255), math.floor(haloAlpha * 0.30)), colorWithAlpha(primaryColor, 0))
        else
            Render.FilledCircle(basePos, haloRadius * 1.55, colorWithAlpha(primaryColor, math.floor(haloAlpha * 0.18)), 20)
            Render.FilledCircle(trailPos, haloRadius * 1.1, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.20)), 18)
            Render.FilledCircle(basePos, haloRadius * 0.72, colorWithAlpha(secondaryColor, math.floor(haloAlpha * 0.32)), 18)
        end

        if Render and Render.ShadowCircle then
            Render.ShadowCircle(basePos, haloRadius * 0.55, colorWithAlpha(primaryColor, math.floor(haloAlpha * 0.20)), haloRadius * 0.65)
        end
    end

    DrawCursorStardust(primaryColor, secondaryColor, fadeInAlpha)

    if Script.stars and Script.stars:Get() then
        local multiLayer = Script.multiLayerStars and Script.multiLayerStars:Get()
        for i, star in ipairs(starActive) do
            local layer = star.layer or 2
            local layerParallax = STAR_LAYER_PARALLAX[layer] or 0.52
            local layerAlphaMul = STAR_LAYER_ALPHA[layer] or 1.0
            local layerSizeMul = STAR_LAYER_SIZE[layer] or 1.0
            local layerDriftMul = STAR_LAYER_DRIFT[layer] or 1.0
            local alpha = math.floor(star.brightness * 255 * fadeInAlpha * layerAlphaMul)
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
                coreColor = makeColor(255, 255, 255, alpha)
            end
            local haloColor = makeColor(coreColor.r, coreColor.g, coreColor.b, math.floor(alpha * 0.3))

            Render.FilledCircle(Vec2(drawX, drawY), drawSize * 2, haloColor, 16)
            Render.FilledCircle(Vec2(drawX, drawY), drawSize, coreColor, 8)

            if drawStarRays and star.brightness > CONSTANTS.STAR_RAY_BRIGHTNESS_THRESHOLD and layer >= 2 then
                local rayLength = drawSize * 4
                for angle = 0, math.pi * 2, math.pi / 2 do
                    local x1 = drawX + math.cos(angle) * drawSize
                    local y1 = drawY + math.sin(angle) * drawSize
                    local x2 = drawX + math.cos(angle) * rayLength
                    local y2 = drawY + math.sin(angle) * rayLength

                    Render.Line(Vec2(x1, y1), Vec2(x2, y2), Color(255, 255, 255, math.floor(alpha * 0.5)), 1)
                end
            end
        end
    end

    if Script.shootingStars and Script.shootingStars:Get() then
        for _, star in ipairs(shootingStarPool) do
            if star.active then
                local simX = star.startX + (star.endX - star.startX) * star.progress
                local simY = star.startY + (star.endY - star.startY) * star.progress
                local x = toRenderX(simX)
                local y = toRenderY(simY)

                for i = 1, #star.tail - 1 do
                    local tailAlpha = math.floor((i / #star.tail) * 200 * fadeInAlpha)
                    local size = star.size * (i / #star.tail)
                    Render.FilledCircle(Vec2(toRenderX(star.tail[i].x), toRenderY(star.tail[i].y)), size, Color(255, 255, 200, tailAlpha), 8)
                end

                Render.FilledCircle(Vec2(x, y), star.size, Color(255, 255, 255, math.floor(255 * fadeInAlpha)), 8)
                Render.FilledCircle(Vec2(x, y), star.size * 3, Color(255, 255, 200, math.floor(100 * fadeInAlpha)), 16)
            end
        end
    end

    local c1 = primaryColor
    local c2 = secondaryColor
    local particleSize = Script.shieldRadius and Script.shieldRadius:Get() or 2
    local particleBaseAlpha = Script.particleBaseAlpha and Script.particleBaseAlpha:Get() or 150
    local particleGlowScale = Script.particleGlowScale and Script.particleGlowScale:Get() or 3
    local particleGlowAlphaScale = (Script.particleGlowAlpha and Script.particleGlowAlpha:Get() or 30) * 0.01
    local particleGlowEnabled = Script.particleGlow and Script.particleGlow:Get()
    local particleSoftCore = Script.particleSoftCore and Script.particleSoftCore:Get()
    local particleLinksEnabled = Script.particleConnections and Script.particleConnections:Get()
    local connectionDist = Script.particleConnectionDist and Script.particleConnectionDist:Get() or CONSTANTS.PARTICLE_CONNECTION_DIST
    local maxConnections = Script.particleMaxConnections and Script.particleMaxConnections:Get() or CONSTANTS.PARTICLE_MAX_CONNECTIONS
    local linkBaseAlpha = Script.particleConnectionAlpha and Script.particleConnectionAlpha:Get() or 50
    local linkWidth = Script.particleConnectionWidth and Script.particleConnectionWidth:Get() or 1
    local coloredLinks = Script.particleColoredLinks and Script.particleColoredLinks:Get()
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
            local glowSize = radius * particleGlowScale
            local glowAlpha = math.floor(alpha * particleGlowAlphaScale)
            if glowAlpha > 0 then
                Render.FilledCircle(Vec2(drawX, drawY), glowSize, Color(pColor.r, pColor.g, pColor.b, glowAlpha), 16)
            end
        end

        if particleSoftCore then
            Render.FilledCircle(Vec2(drawX, drawY), radius * 1.8, Color(pColor.r, pColor.g, pColor.b, math.floor(alpha * 0.25)), 12)
        end

        Render.FilledCircle(Vec2(drawX, drawY), radius, Color(pColor.r, pColor.g, pColor.b, alpha), 8)
        Render.FilledCircle(Vec2(drawX, drawY), math.max(0.6, radius * 0.45), Color(255, 255, 255, math.floor(alpha * 0.5)), 8)

        ::continue_particle::
    end

    if particleLinksEnabled and maxConnections > 0 and connectionDist > 0 then
        local renderConnectionDist = connectionDist * ((posScaleX + posScaleY) * 0.5)
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
            nodePhase
        )
    end
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

    for i, star in ipairs(shootingStarPool) do
        if star.tail then
            clearList(star.tail)
        end
    end

    clearList(bgParticleActive)
    clearList(starActive)
    clearList(ambientStreakActive)
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
    State.fadeInAlpha = 1
    resetRuntimeState()
end

--#endregion

return Script
