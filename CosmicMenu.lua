--[[
╭────────────────────────────────────────────────────────────╮
|                       Cosmic Menu by Euphoria              │
│                        By Pidaras                          │
|                             VibeCode                       │                     
╰────────────────────────────────────────────────────────────╯
]]
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
    SCREEN_UPDATE_INTERVAL = 2.0,
}

local script = {}

local time = 0
local fadeInTime = 0
local menuWasOpen = false
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
local qualitySpikeHold = 0
local baseScreenMinDim = nil
local baseScreenArea = nil
local adaptiveFallbackMaxW = 0
local adaptiveFallbackMaxH = 0

local screenSize = Vec2(1, 1)
local lastScreenUpdateTime = 0

local bgParticlePool = {}
local bgParticleActive = {}
local starPool = {}
local starActive = {}
local shootingStarPool = {}
local ambientStreakPool = {}
local ambientStreakActive = {}

local function randomRangeSafe(minValue, maxValue)
    if maxValue < minValue then
        maxValue = minValue
    end
    return math.random(minValue, maxValue)
end

local function getSafeScreenDimensions()
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

local function GetScreenSize()
    local function probeScreenSizeV2(target)
        if not target or not target.ScreenSize then
            return nil
        end

        local ok, a, b = pcall(target.ScreenSize, target)
        if ok then
            local size = normalizeScreenSize(a, b)
            if size then
                return size
            end
        end

        ok, a, b = pcall(target.ScreenSize)
        if ok then
            local size = normalizeScreenSize(a, b)
            if size then
                return size
            end
        end

        ok, a, b = pcall(function()
            return target:ScreenSize()
        end)
        if ok then
            local size = normalizeScreenSize(a, b)
            if size then
                return size
            end
        end

        return nil
    end

    local function probeGetScreenSize(target)
        if not target or not target.GetScreenSize then
            return nil
        end

        local ok, a, b = pcall(target.GetScreenSize, target)
        if ok then
            local size = normalizeScreenSize(a, b)
            if size then
                return size
            end
        end

        ok, a, b = pcall(target.GetScreenSize)
        if ok then
            local size = normalizeScreenSize(a, b)
            if size then
                return size
            end
        end

        ok, a, b = pcall(function()
            return target:GetScreenSize()
        end)
        if ok then
            local size = normalizeScreenSize(a, b)
            if size then
                return size
            end
        end

        return nil
    end

    local renderSizeV2 = probeScreenSizeV2(Render)
    if renderSizeV2 then
        updateScreenBaselines(renderSizeV2)
        return renderSizeV2
    end

    local renderSize = probeGetScreenSize(Render)
    if renderSize then
        updateScreenBaselines(renderSize)
        return renderSize
    end

    local engineSizeV2 = probeScreenSizeV2(Engine)
    if engineSizeV2 then
        updateScreenBaselines(engineSizeV2)
        return engineSizeV2
    end

    local engineSize = probeGetScreenSize(Engine)
    if engineSize then
        updateScreenBaselines(engineSize)
        return engineSize
    end

    local adaptiveFallback = getAdaptiveFallbackScreenSize()
    updateScreenBaselines(adaptiveFallback)
    return adaptiveFallback

end

local function UpdateScreenSize(currentTime)
    if screenSize.x <= 1 or screenSize.y <= 1 or currentTime - lastScreenUpdateTime > CONSTANTS.SCREEN_UPDATE_INTERVAL then
        local previousSize = screenSize
        local size = GetScreenSize()
        if size and size.x and size.y then
            screenSize = size

            if previousSize and previousSize.x and previousSize.y and previousSize.x > 1 and previousSize.y > 1 then
                remapPoolPositionsForScreenChange(previousSize, size)
            end
        end
        lastScreenUpdateTime = currentTime
    end
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
    local w, h = getSafeScreenDimensions()
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

local function createStar()
    local w, h = getSafeScreenDimensions()
    return {
        x = randomRangeSafe(0, w),
        y = randomRangeSafe(0, h),
        size = math.random(1, 3),
        twinkleSpeed = math.random(1, 5),
        twinklePhase = math.random() * math.pi * 2,
        brightness = math.random(50, 100) / 100,
        active = true
    }
end

local function createShootingStar()
    local w, h = getSafeScreenDimensions()
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
    local w, h = getSafeScreenDimensions()
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
    local w, h = getSafeScreenDimensions()
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
    local w, h = getSafeScreenDimensions()

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
    resetParticleImpulses()
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

        for _, entry in pairs(styleTable) do
            local fromTable = normalizeColor(entry)
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
        local preferredKeys = {"accent", "secondary", "highlight", "active", "text", "primary"}
        for _, key in ipairs(preferredKeys) do
            local candidate = normalizeColor(styleTable[key])
            if candidate and not areColorsSimilar(candidate, primaryColor) then
                secondaryColor = candidate
                break
            end
        end

        if not secondaryColor then
            for _, entry in pairs(styleTable) do
                local candidate = normalizeColor(entry)
                if candidate and not areColorsSimilar(candidate, primaryColor) then
                    secondaryColor = candidate
                    break
                end
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

script.OnScriptsLoaded = function()
    UpdateScreenSize(-CONSTANTS.SCREEN_UPDATE_INTERVAL)

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
    local main = tab:Create(L("Minimal", "Минимал"))

    if tab and tab.Icon then
        tab:Icon("\u{f005}")
    end

    local ok, cosmicMenuTab = pcall(function()
        return tab:Parent()
    end)

    if ok and cosmicMenuTab and cosmicMenuTab.Icon then
        cosmicMenuTab:Icon("\u{f005}")
    end

    local g_main = main:Create(L("Main", "Основное"))

    script.enabled = g_main:Switch(L("Enable", "Включить"), true, "\u{f011}")
    script.enabled:ToolTip(L("Master switch for CosmicMenu", "Главный переключатель CosmicMenu"))

    script.backgroundEffects = g_main:Switch(L("Background Effects", "Фоновые эффекты"), true, "\u{f5fd}")
    script.backgroundEffects:ToolTip(L("Disable to save FPS", "Выключите для максимального FPS"))

    script.backgroundOpacity = g_main:Slider(L("Background Darkness", "Затемнение фона"), 0, 100, 30, "%d")
    applyIcon(script.backgroundOpacity, "\u{f186}")

    script.fadeInEffect = g_main:Switch(L("Fade In", "Плавное появление"), true, "\u{f021}")

    script.backgroundBlur = g_main:Switch(L("Background Blur", "Размытие фона"), false, "\u{f0b0}")
    local blur_gear = script.backgroundBlur:Gear(L("Blur", "Размытие"))
    script.blurIntensity = blur_gear:Slider(L("Intensity", "Интенсивность"), 0, 20, 5, "%d")
    applyIcon(script.blurIntensity, "\u{f2dc}")

    script.colorWash = g_main:Switch(L("Color Wash", "Цветовой градиент"), true, "\u{f043}")

    local themeLabel = g_main:Label(L("Colors sync with cheat theme", "Цвета синхронизированы с темой чита"), "\u{f53f}")
    if themeLabel and themeLabel.ToolTip then
        themeLabel:ToolTip(L("Accent colors are taken from the current menu theme", "Акцентные цвета берутся из текущей темы меню"))
    end

    local g_particles = main:Create(L("Particles", "Частицы"))

    script.bgParticleCount = g_particles:Slider(L("Count", "Количество"), 20, 500, 100, "%d")
    applyIcon(script.bgParticleCount, "\u{f111}")

    script.shieldRadius = g_particles:Slider(L("Size", "Размер"), 1, 8, 2, "%d")
    applyIcon(script.shieldRadius, "\u{f192}")

    script.particleBaseAlpha = g_particles:Slider(L("Opacity", "Прозрачность"), 10, 255, 150, "%d")
    applyIcon(script.particleBaseAlpha, "\u{f5e0}")

    script.particleSoftCore = g_particles:Switch(L("Soft Core", "Мягкое ядро"), true, "\u{f111}")
    script.particleGlow = g_particles:Switch(L("Glow", "Свечение"), true, "\u{f0eb}")
    local glow_gear = script.particleGlow:Gear(L("Glow", "Свечение"))
    script.particleGlowScale = glow_gear:Slider(L("Size", "Размер"), 1, 8, 3, "%d")
    applyIcon(script.particleGlowScale, "\u{f185}")
    script.particleGlowAlpha = glow_gear:Slider(L("Opacity", "Прозрачность"), 0, 100, 30, "%d%%")
    applyIcon(script.particleGlowAlpha, "\u{f5e0}")

    script.stars = g_particles:Switch(L("Twinkling Stars", "Мерцающие звезды"), true, "\u{f005}")
    local stars_gear = script.stars:Gear(L("Stars", "Звезды"))
    script.starCount = stars_gear:Slider(L("Count", "Количество"), 100, 500, 200, "%d")
    applyIcon(script.starCount, "\u{f005}")

    script.shootingStars = g_particles:Switch(L("Shooting Stars", "Падающие звезды"), true, "\u{f135}")
    local shooting_gear = script.shootingStars:Gear(L("Shooting", "Падающие"))
    script.shootingStarFreq = shooting_gear:Slider(L("Frequency", "Частота"), 1, 10, 5, "%d")
    applyIcon(script.shootingStarFreq, "\u{f017}")

    local g_motion = main:Create(L("Motion", "Движение"))
    script.particleSpeedScale = g_motion:Slider(L("Speed", "Скорость"), 10, 400, 100, "%d%%")
    applyIcon(script.particleSpeedScale, "\u{f70c}")
    script.particleDrift = g_motion:Slider(L("Drift", "Дрейф"), 0, 200, 35, "%d%%")
    applyIcon(script.particleDrift, "\u{f1e6}")
    script.particleTwinkleSpeedScale = g_motion:Slider(L("Twinkle Speed", "Скорость мерцания"), 0, 300, 100, "%d%%")
    applyIcon(script.particleTwinkleSpeedScale, "\u{f0e7}")
    script.particleTwinkleAmount = g_motion:Slider(L("Twinkle Amount", "Сила мерцания"), 0, 100, 30, "%d%%")
    applyIcon(script.particleTwinkleAmount, "\u{f005}")

    local g_links = main:Create(L("Links", "Связи"))
    script.particleConnections = g_links:Switch(L("Enable Links", "Включить связи"), true, "\u{f0c1}")
    local links_gear = script.particleConnections:Gear(L("Links", "Связи"))
    script.particleConnectionDist = links_gear:Slider(L("Distance", "Дистанция"), 40, 400, 150, "%d")
    applyIcon(script.particleConnectionDist, "\u{f4ad}")
    script.particleConnectionAlpha = links_gear:Slider(L("Opacity", "Прозрачность"), 0, 150, 50, "%d")
    applyIcon(script.particleConnectionAlpha, "\u{f5e0}")
    script.particleConnectionWidth = links_gear:Slider(L("Width", "Толщина"), 1, 3, 1, "%d")
    applyIcon(script.particleConnectionWidth, "\u{f61f}")
    script.particleMaxConnections = links_gear:Slider(L("Per Particle", "На частицу"), 0, 8, 3, "%d")
    applyIcon(script.particleMaxConnections, "\u{f126}")
    script.particleColoredLinks = links_gear:Switch(L("Colored Links", "Цветные линии"), true, "\u{f1fc}")

    local g_cursor = main:Create(L("Cursor", "Курсор"))
    script.particleCursorInteraction = g_cursor:Switch(L("Enable Cursor", "Реакция на курсор"), true, "\u{f245}")
    local cursor_gear = script.particleCursorInteraction:Gear(L("Cursor", "Курсор"))
    script.particleCursorMode = cursor_gear:Slider(L("Mode", "Режим"), 1, 3, 1, function(value)
        local mode = roundToInt(value)
        if mode == 1 then return L("Repel", "Отталкивание") end
        if mode == 2 then return L("Swipe", "Свайп") end
        if mode == 3 then return L("Vortex", "Вихрь") end
        return tostring(mode)
    end)
    script.particleCursorRadius = cursor_gear:Slider(L("Radius", "Радиус"), 40, 600, 180, "%d")
    applyIcon(script.particleCursorRadius, "\u{f192}")
    script.particleCursorForce = cursor_gear:Slider(L("Force", "Сила"), 100, 12000, 3200, "%d")
    applyIcon(script.particleCursorForce, "\u{f0e7}")
    script.particleCursorFalloff = cursor_gear:Slider(L("Falloff", "Спад"), 25, 300, 120, "%d%%")
    applyIcon(script.particleCursorFalloff, "\u{f2f9}")
    script.particleCursorMotionBoost = cursor_gear:Slider(L("Motion Boost", "Усиление"), 0, 300, 120, "%d%%")
    applyIcon(script.particleCursorMotionBoost, "\u{f062}")
    script.particleCursorMoveThreshold = cursor_gear:Slider(L("Move Threshold", "Порог"), 0, 40, 1, "%d")
    applyIcon(script.particleCursorMoveThreshold, "\u{f201}")
    script.particleCursorOnlyMoving = cursor_gear:Switch(L("Only While Moving", "Только при движении"), true, "\u{f04b}")
    script.particleCursorImpulseDamping = cursor_gear:Slider(L("Damping", "Затухание"), 0, 300, 90, "%d%%")
    applyIcon(script.particleCursorImpulseDamping, "\u{f863}")
    script.particleCursorSwirl = cursor_gear:Slider(L("Swirl", "Вихрь"), -100, 100, 60, "%d%%")
    applyIcon(script.particleCursorSwirl, "\u{f021}")
end

script.OnFrame = function()
    if not script.enabled or not script.enabled.Get then return end
    if not script.enabled:Get() then return end

    local dt = GetAnimationDt()

    if dt > 0.030 then
        qualityScale = clamp(qualityScale - 0.14, 0.64, 1.0)
        qualitySpikeHold = 0.5
    elseif qualitySpikeHold > 0 then
        qualitySpikeHold = qualitySpikeHold - dt
    else
        qualityScale = clamp(qualityScale + dt * 0.22, 0.64, 1.0)
    end

    local menuOpen = IsMenuOpen()
    if menuOpen and not menuWasOpen then
        fadeInTime = 0
        screenSize = GetScreenSize()
        lastScreenUpdateTime = time
    end
    if menuOpen then
        fadeInTime = math.min(fadeInTime + dt, CONSTANTS.FADE_IN_DURATION)
    end
    menuWasOpen = menuOpen

    if not menuOpen then
        resetRuntimeState()
        return
    end

    time = time + dt
    UpdateScreenSize(time)

    local fadeInAlpha = 1
    if script.fadeInEffect and script.fadeInEffect:Get() and fadeInTime < CONSTANTS.FADE_IN_DURATION then
        fadeInAlpha = fadeInTime / CONSTANTS.FADE_IN_DURATION
    end
    local areaScale = getScreenAreaScale()
    local bgTargetCount = clamp(roundToInt(script.bgParticleCount:Get() * areaScale * qualityScale), 20, 700)
    local starTargetCount = clamp(roundToInt(script.starCount:Get() * areaScale * (0.88 + qualityScale * 0.12)), 60, 700)
    local streakTargetCount = clamp(roundToInt((8 + areaScale * 8) * qualityScale), 5, 28)

    rebalancePool(bgParticlePool, bgTargetCount, createBgParticle, function(particle)
        particle.impulseX = 0
        particle.impulseY = 0
    end)
    rebalancePool(starPool, starTargetCount, createStar)
    rebalancePool(ambientStreakPool, streakTargetCount, createAmbientStreak, resetAmbientStreak)

    collectActive(bgParticlePool, bgParticleActive)
    collectActive(starPool, starActive)
    collectActive(ambientStreakPool, ambientStreakActive)

    local w, h = screenSize.x, screenSize.y
    local particleSpeedScale = (script.particleSpeedScale and script.particleSpeedScale:Get() or 100) * 0.01
    local particleDrift = (script.particleDrift and script.particleDrift:Get() or 35) * 0.01
    local particleTwinkleSpeedScale = (script.particleTwinkleSpeedScale and script.particleTwinkleSpeedScale:Get() or 100) * 0.01
    local particleTwinkleAmount = (script.particleTwinkleAmount and script.particleTwinkleAmount:Get() or 30) * 0.01
    local wrapMargin = 50
    local cursorInteractionEnabled = script.particleCursorInteraction and script.particleCursorInteraction:Get()
    local cursorPos = nil
    local frameCursorDeltaX = 0
    local frameCursorDeltaY = 0
    local frameCursorDeltaLen = 0
    local rawCursorMode = script.particleCursorMode and script.particleCursorMode:Get() or 1
    local cursorMode = clamp(roundToInt(rawCursorMode), 1, 3)
    local cursorRadius = script.particleCursorRadius and script.particleCursorRadius:Get() or 180
    local cursorRadiusSq = cursorRadius * cursorRadius
    local cursorForce = script.particleCursorForce and script.particleCursorForce:Get() or 3200
    local cursorFalloffExp = (script.particleCursorFalloff and script.particleCursorFalloff:Get() or 120) * 0.01
    local cursorMotionBoost = (script.particleCursorMotionBoost and script.particleCursorMotionBoost:Get() or 120) * 0.01
    local cursorMoveThreshold = script.particleCursorMoveThreshold and script.particleCursorMoveThreshold:Get() or 1
    local cursorOnlyMoving = script.particleCursorOnlyMoving and script.particleCursorOnlyMoving:Get()
    local cursorImpulseDecay = clamp(1 - ((script.particleCursorImpulseDamping and script.particleCursorImpulseDamping:Get() or 90) * 0.01) * 4 * dt, 0, 1)
    local cursorSwirl = (script.particleCursorSwirl and script.particleCursorSwirl:Get() or 0) * 0.01

    if lastCursorModeApplied ~= cursorMode or lastCursorInteractionApplied ~= cursorInteractionEnabled then
        resetParticleImpulses()
        lastCursorModeApplied = cursorMode
        lastCursorInteractionApplied = cursorInteractionEnabled
    end

    if cursorInteractionEnabled then
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

    if cursorPos then
        cursorHaloX = cursorPos.x
        cursorHaloY = cursorPos.y
        local targetHaloOffsetX = clamp(frameCursorDeltaX * 0.55, -18, 18)
        local targetHaloOffsetY = clamp(frameCursorDeltaY * 0.55, -18, 18)
        local haloOffsetLerp = clamp(dt * 8.0, 0, 1)

        cursorHaloOffsetX = lerp(cursorHaloOffsetX, targetHaloOffsetX, haloOffsetLerp)
        cursorHaloOffsetY = lerp(cursorHaloOffsetY, targetHaloOffsetY, haloOffsetLerp)

        local centerX = w * 0.5
        local centerY = h * 0.5
        local targetParallaxX = clamp((cursorPos.x - centerX) / math.max(centerX, 1), -1, 1) * 16
        local targetParallaxY = clamp((cursorPos.y - centerY) / math.max(centerY, 1), -1, 1) * 10
        local parallaxLerp = clamp(dt * 4.5, 0, 1)

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
        star.brightness = 0.5 + math.sin(time * star.twinkleSpeed + star.twinklePhase) * 0.5
    end

    if script.shootingStars and script.shootingStars:Get() then
        if math.random() < script.shootingStarFreq:Get() * dt * 0.01 then
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

    if script.backgroundEffects:Get() then
        DrawBackgroundEffects(fadeInAlpha)
    end
end

function IsMenuOpen()
    if Menu and Menu.Opened then
        return Menu.Opened() == true
    end
    return false
end

function DrawBackgroundEffects(fadeInAlpha)
    if not script.backgroundOpacity then
        return
    end

    fadeInAlpha = fadeInAlpha or 1

    local opacity = script.backgroundOpacity:Get()
    local primaryColor, secondaryColor = getThemeColors()
    local width = screenSize.x
    local height = screenSize.y
    local screenScale = getScreenScale()

    local fadeOpacity = math.floor(opacity * 2.55 * fadeInAlpha)
    Render.FilledRect(Vec2(0, 0), screenSize, Color(0, 0, 0, fadeOpacity), 0)

    if script.backgroundBlur and script.backgroundBlur:Get() and script.blurIntensity then
        local blurIntensity = script.blurIntensity:Get()
        if blurIntensity > 0 then
            local maxPassStrength = 1.2
            local totalStrength = blurIntensity * 0.15 * (0.78 + qualityScale * 0.22)
            local passCount = math.max(1, math.ceil(totalStrength / maxPassStrength))
            local perPass = totalStrength / passCount
            for _blurPass = 1, passCount do
                Render.Blur(Vec2(0, 0), screenSize, perPass)
            end
        end
    end

    if script.colorWash and script.colorWash:Get() then
        local washAlpha = math.floor((12 + opacity * 0.18) * fadeInAlpha)
        local washAlphaSoft = math.floor(washAlpha * 0.6)

        gradientRectCompat(
            Vec2(0, 0),
            screenSize,
            Color(primaryColor.r, primaryColor.g, primaryColor.b, washAlpha),
            Color(secondaryColor.r, secondaryColor.g, secondaryColor.b, washAlpha),
            true
        )

        gradientRectCompat(
            Vec2(0, 0),
            screenSize,
            Color(10, 18, 32, washAlphaSoft),
            Color(0, 0, 0, 0),
            false
        )
    end

    do
        local vignettePulse = 0.86 + math.sin(time * 0.95) * 0.14
        local vignetteAlpha = math.floor((12 + opacity * 0.11) * fadeInAlpha * vignettePulse * (0.82 + qualityScale * 0.18))
        local vignetteSize = math.max(120, math.floor(math.min(width, height) * 0.22))

        gradientRectCompat(Vec2(0, 0), Vec2(width, vignetteSize), Color(0, 0, 0, vignetteAlpha), Color(0, 0, 0, 0), false)
        gradientRectCompat(Vec2(0, height - vignetteSize), Vec2(width, vignetteSize), Color(0, 0, 0, 0), Color(0, 0, 0, vignetteAlpha), false)
        gradientRectCompat(Vec2(0, 0), Vec2(vignetteSize, height), Color(0, 0, 0, vignetteAlpha), Color(0, 0, 0, 0), true)
        gradientRectCompat(Vec2(width - vignetteSize, 0), Vec2(vignetteSize, height), Color(0, 0, 0, 0), Color(0, 0, 0, vignetteAlpha), true)
    end

    do
        local streakVisibility = fadeInAlpha * (0.74 + qualityScale * 0.26)
        for i, streak in ipairs(ambientStreakActive) do
            local sway = math.sin(time * 0.8 + i * 0.67)
            local sx = streak.x + sway * 8
            local sy = streak.y + sway * 4
            local ex = sx + math.cos(streak.angle) * streak.length
            local ey = sy + math.sin(streak.angle) * streak.length
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

    do
        local pulse = 0.8 + math.sin(time * 1.25) * 0.2
        local coldPrimary = mixColors(primaryColor, makeColor(210, 235, 255, 255), 0.45, primaryColor.a or 255)
        local coldSecondary = mixColors(secondaryColor, makeColor(235, 245, 255, 255), 0.55, secondaryColor.a or 255)
        local edgeAlpha = math.floor((18 + opacity * 0.05) * fadeInAlpha * pulse * (0.82 + qualityScale * 0.18))
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

    if cursorHaloX and cursorHaloY and script.particleCursorInteraction and script.particleCursorInteraction:Get() then
        local haloPulse = 0.88 + math.sin(time * 2.2) * 0.12
        local haloRadius = 66 + haloPulse * 14
        local haloAlpha = math.floor((16 + opacity * 0.11) * fadeInAlpha)
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

    if script.stars and script.stars:Get() then
        for i, star in ipairs(starActive) do
            local alpha = math.floor(star.brightness * 255 * fadeInAlpha)
            local starParallax = 0.12 + star.size * 0.03
            local drawX = star.x + sceneParallaxX * starParallax
            local drawY = star.y + sceneParallaxY * starParallax

            Render.FilledCircle(Vec2(drawX, drawY), star.size * 2, Color(255, 255, 255, math.floor(alpha * 0.3)), 16)

            Render.FilledCircle(Vec2(drawX, drawY), star.size, Color(255, 255, 255, alpha), 8)

            if star.brightness > CONSTANTS.STAR_RAY_BRIGHTNESS_THRESHOLD then
                local rayLength = star.size * 4
                for angle = 0, math.pi * 2, math.pi / 2 do
                    local x1 = drawX + math.cos(angle) * star.size
                    local y1 = drawY + math.sin(angle) * star.size
                    local x2 = drawX + math.cos(angle) * rayLength
                    local y2 = drawY + math.sin(angle) * rayLength

                    Render.Line(Vec2(x1, y1), Vec2(x2, y2), Color(255, 255, 255, math.floor(alpha * 0.5)), 1)
                end
            end
        end
    end

    if script.shootingStars and script.shootingStars:Get() then
        for _, star in ipairs(shootingStarPool) do
            if star.active then
                local x = star.startX + (star.endX - star.startX) * star.progress
                local y = star.startY + (star.endY - star.startY) * star.progress

                for i = 1, #star.tail - 1 do
                    local tailAlpha = math.floor((i / #star.tail) * 200 * fadeInAlpha)
                    local size = star.size * (i / #star.tail)
                    Render.FilledCircle(Vec2(star.tail[i].x, star.tail[i].y), size, Color(255, 255, 200, tailAlpha), 8)
                end

                Render.FilledCircle(Vec2(x, y), star.size, Color(255, 255, 255, 255 * fadeInAlpha), 8)
                Render.FilledCircle(Vec2(x, y), star.size * 3, Color(255, 255, 200, math.floor(100 * fadeInAlpha)), 16)
            end
        end
    end

    local c1 = primaryColor
    local c2 = secondaryColor
    local particleSize = script.shieldRadius and script.shieldRadius:Get() or 2
    local particleBaseAlpha = script.particleBaseAlpha and script.particleBaseAlpha:Get() or 150
    local particleGlowScale = script.particleGlowScale and script.particleGlowScale:Get() or 3
    local particleGlowAlphaScale = (script.particleGlowAlpha and script.particleGlowAlpha:Get() or 30) * 0.01
    local particleGlowEnabled = script.particleGlow and script.particleGlow:Get()
    local particleSoftCore = script.particleSoftCore and script.particleSoftCore:Get()
    local particleLinksEnabled = script.particleConnections and script.particleConnections:Get()
    local connectionDist = script.particleConnectionDist and script.particleConnectionDist:Get() or CONSTANTS.PARTICLE_CONNECTION_DIST
    local connectionDistSq = connectionDist * connectionDist
    local maxConnections = script.particleMaxConnections and script.particleMaxConnections:Get() or CONSTANTS.PARTICLE_MAX_CONNECTIONS
    local linkBaseAlpha = script.particleConnectionAlpha and script.particleConnectionAlpha:Get() or 50
    local linkWidth = script.particleConnectionWidth and script.particleConnectionWidth:Get() or 1
    local coloredLinks = script.particleColoredLinks and script.particleColoredLinks:Get()
    local nodePhase = math.floor(time * 1.2)

    for i, particle in ipairs(bgParticleActive) do
        local pColor = particle.colorIdx == 1 and c1 or c2
        local alpha = math.floor(particle.brightness * particleBaseAlpha * fadeInAlpha)
        local radius = particle.size * particleSize * (particle.depth or 1) * 0.85
        local parallaxStrength = 0.22 + (particle.depth or 1) * 0.28
        local drawX = particle.x + sceneParallaxX * parallaxStrength
        local drawY = particle.y + sceneParallaxY * parallaxStrength

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
    end

    if particleLinksEnabled and maxConnections > 0 and connectionDist > 0 then
        table.sort(bgParticleActive, function(a, b)
            return a.x < b.x
        end)

        for i = 1, #bgParticleActive do
            local p1 = bgParticleActive[i]
            local connections = 0

            for j = i + 1, #bgParticleActive do
                if connections >= maxConnections then break end

                local p2 = bgParticleActive[j]
                local dx = (p2.drawX or p2.x) - (p1.drawX or p1.x)
                if dx > connectionDist then
                    break
                end

                local dy = (p1.drawY or p1.y) - (p2.drawY or p2.y)
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

script.OnGameEnd = function()
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

    time = 0
    fadeInTime = 0
    menuWasOpen = false
    lastRealTime = nil
    resetRuntimeState()
end

return script
