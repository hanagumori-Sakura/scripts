-- Кэширование глобальных функций Lua для повышения производительности
local math_sin = math.sin
local math_cos = math.cos
local math_random = math.random
local math_pi = math.pi
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local ipairs_cached = ipairs

local CONSTANTS = {
    SCREEN_DEFAULT_WIDTH = 1920,
    SCREEN_DEFAULT_HEIGHT = 1080,
    DT_DEFAULT = 0.016,
    DT_MAX = 0.033,
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

local DEFAULT_PRIMARY_COLOR = Color(100, 200, 255, 200)
local DEFAULT_SECONDARY_COLOR = Color(255, 100, 200, 200)

local script = {}

local time = 0
local fadeInTime = 0
local menuWasOpen = false
local lastRealTime = nil
local lastCursorX = nil
local lastCursorY = nil
local lastCursorModeApplied = nil
local lastCursorInteractionApplied = nil
local currentFadeInAlpha = 1
local densityMultiplier = 1.0

local screenSize = Vec2(CONSTANTS.SCREEN_DEFAULT_WIDTH, CONSTANTS.SCREEN_DEFAULT_HEIGHT)
local lastScreenUpdateTime = 0

-- Статические mutable-векторы Vec2 для устранения аллокаций в циклах отрисовки (предотвращает фризы и GC-лаги)
local vZero = Vec2(0, 0)
local vScreen = Vec2(CONSTANTS.SCREEN_DEFAULT_WIDTH, CONSTANTS.SCREEN_DEFAULT_HEIGHT)
local vTemp1 = Vec2(0, 0)
local vTemp2 = Vec2(0, 0)
local vTemp3 = Vec2(0, 0)

local bgParticlePool = {}
local bgParticleActive = {}
local starPool = {}
local starActive = {}
local shootingStarPool = {}
local trailPool = {}
local trailActive = {}
local ripplePool = {}
local rippleActive = {}

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

local function GetScreenSize()
    if Render and Render.ScreenSize then
        local ok, size = pcall(Render.ScreenSize)
        if ok and size then
            return size
        end
    end
    return Vec2(CONSTANTS.SCREEN_DEFAULT_WIDTH, CONSTANTS.SCREEN_DEFAULT_HEIGHT)
end

local function UpdateScreenSize(currentTime)
    if currentTime - lastScreenUpdateTime > CONSTANTS.SCREEN_UPDATE_INTERVAL then
        screenSize = GetScreenSize()
        vScreen.x = screenSize.x
        vScreen.y = screenSize.y
        densityMultiplier = (screenSize.x * screenSize.y) / (1920 * 1080)
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

local function GetAnimationDt()
    if chronos and chronos.nanotime then
        local realTime = chronos.nanotime()
        if lastRealTime then
            local rawDt = realTime - lastRealTime
            lastRealTime = realTime
            return clamp(rawDt, CONSTANTS.ANIMATION_DT_MIN, CONSTANTS.ANIMATION_DT_MAX)
        else
            lastRealTime = realTime
            return CONSTANTS.DT_DEFAULT
        end
    end

    local fallbackDt = (global_vars and global_vars.absoluteframetime and global_vars.absoluteframetime()) or CONSTANTS.DT_DEFAULT
    if fallbackDt <= 0 then
        fallbackDt = CONSTANTS.DT_DEFAULT
    end
    return clamp(fallbackDt, CONSTANTS.ANIMATION_DT_MIN, CONSTANTS.ANIMATION_DT_MAX)
end

local function GetCursorPos()
    if input and input.cursor_pos then
        local ok, pos = pcall(input.cursor_pos)
        if ok and pos then
            return pos
        end
    end
    return nil
end

local function createBgParticle()
    return {
        x = math_random(0, math_floor(screenSize.x)),
        y = math_random(0, math_floor(screenSize.y)),
        size = math_random(1, 4),
        speed = math_random(20, 100) / 100,
        angle = math_random() * math_pi * 2,
        baseBrightness = math_random(35, 90) / 100,
        brightness = math_random(35, 90) / 100,
        twinkleSpeed = math_random(60, 180) / 100,
        twinklePhase = math_random() * math_pi * 2,
        driftPhase = math_random() * math_pi * 2,
        driftSpeed = math_random(40, 140) / 100,
        driftStrength = math_random(20, 120) / 100,
        angularVelocity = (math_random() - 0.5) * 0.8,
        depth = math_random(70, 150) / 100,
        impulseX = 0,
        impulseY = 0,
        colorIdx = math_random(1, 2),
        active = true,
        idx = 0,
        connections = 0
    }
end

local function roundToInt(value)
    if type(value) ~= "number" then
        return 0
    end
    if value >= 0 then
        return math_floor(value + 0.5)
    end
    return math_floor(value - 0.5)
end

local function createStar()
    return {
        x = math_random(0, math_floor(screenSize.x)),
        y = math_random(0, math_floor(screenSize.y)),
        size = math_random(1, 3),
        twinkleSpeed = math_random(1, 5),
        twinklePhase = math_random() * math_pi * 2,
        brightness = math_random(50, 100) / 100,
        active = true
    }
end

local function createShootingStar()
    return {
        startX = math_random(0, math_floor(screenSize.x)),
        startY = math_random(-100, 0),
        endX = math_random(0, math_floor(screenSize.x)),
        endY = math_random(math_floor(screenSize.y), math_floor(screenSize.y + 200)),
        progress = 0,
        speed = math_random(5, 20) / 10,
        size = math_random(2, 4),
        tail = {},
        lifetime = 0,
        active = false
    }
end

local function createTrailParticle()
    return {
        x = 0,
        y = 0,
        vx = 0,
        vy = 0,
        lifetime = 0,
        maxLifetime = 0,
        size = 0,
        colorIdx = 1,
        active = false
    }
end

local function createRipple()
    return {
        x = 0,
        y = 0,
        progress = 0,
        speed = 2.0,
        maxRadius = 200,
        force = 3000,
        active = false
    }
end

local function resetShootingStar(star)
    star.startX = math_random(0, math_floor(screenSize.x))
    star.startY = math_random(-100, 0)
    star.endX = math_random(0, math_floor(screenSize.x))
    star.endY = math_random(math_floor(screenSize.y), math_floor(screenSize.y + 200))
    star.progress = 0
    star.speed = math_random(5, 20) / 10
    star.size = math_random(2, 4)
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
    for i, obj in ipairs_cached(pool) do
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

local function deactivatePoolObjects(list)
    for i, obj in ipairs_cached(list) do
        obj.active = false
    end
end

local function resetParticleImpulses()
    for i, particle in ipairs_cached(bgParticlePool) do
        particle.impulseX = 0
        particle.impulseY = 0
    end
end

local function getActiveCount(list)
    local count = 0
    for i, obj in ipairs_cached(list) do
        if obj.active then
            count = count + 1
        end
    end
    return count
end

local function getFallbackColor(widget, defaultColor)
    if type(widget) == "function" then
        local ok, color = pcall(widget)
        if ok and color then return color end
    elseif type(widget) == "table" then
        if widget.Get then
            local ok, color = pcall(widget.Get, widget)
            if ok and color then return color end
        end
        local mt = getmetatable(widget)
        if mt and mt.__call then
            local ok, color = pcall(widget)
            if ok and color then return color end
        end
        if widget.value then
            return widget.value
        end
    end
    return defaultColor
end

local function getPrimaryColor()
    return getFallbackColor(script.shieldColor, DEFAULT_PRIMARY_COLOR)
end

local function getSecondaryColor()
    return getFallbackColor(script.shieldColor2, DEFAULT_SECONDARY_COLOR)
end

local function gradientRectCompat(pos, size, color1, color2, isHorizontal)
    if Render and Render.Gradient then
        vTemp3.x = pos.x + size.x
        vTemp3.y = pos.y + size.y
        local tl, tr, bl, br
        if isHorizontal then
            tl = color1
            bl = color1
            tr = color2
            br = color2
        else
            tl = color1
            tr = color1
            bl = color2
            br = color2
        end
        local ok = pcall(Render.Gradient, pos, vTemp3, tl, tr, bl, br, 0)
        if ok then
            return true
        end
    end

    if Render and Render.FilledRect then
        vTemp3.x = pos.x + size.x
        vTemp3.y = pos.y + size.y
        Render.FilledRect(pos, vTemp3, color1, 0)
    end
    return false
end

local function renderFilledCircle(pos, radius, color, segments)
    if Render and Render.FilledCircle then
        Render.FilledCircle(pos, radius, color, 0, 1.0, segments or 32)
    end
end

local function renderCircle(pos, radius, color, segments, thickness)
    if Render and Render.Circle then
        Render.Circle(pos, radius, color, thickness or 1.0, 0, 1.0, false, segments or 32)
    end
end

local function IsMenuOpen()
    if Menu and Menu.Opened then
        return Menu.Opened() == true
    end
    return false
end

local function OnScriptsLoaded()
    initPool(bgParticlePool, createBgParticle, 100)
    initPool(starPool, createStar, 200)
    initPool(shootingStarPool, createShootingStar, 10)
    initPool(trailPool, createTrailParticle, 150)
    initPool(ripplePool, createRipple, 5)

    UpdateScreenSize(0)

    local visuals_tab = Menu.Find("Visuals", "", "Visuals")
    local tab
    if visuals_tab then
        tab = NEW_UI_LIB.create_tab(false, visuals_tab, "CosmicMenu")
    else
        tab = NEW_UI_LIB.create_tab(false, "Visuals", "", "Visuals", "CosmicMenu")
    end

    -- ═══════════════════════════════════════════════════════════════
    --  General
    -- ═══════════════════════════════════════════════════════════════
    local g_general = tab:create("General")

    script.enabled = g_general:switch("Enable CosmicMenu", true, "\u{f011}", "Master switch — enables or disables the entire cosmic background")
    script.backgroundEffects = function() return true end
    script.backgroundOpacity = g_general:slider("Background Darkness", 0, 100, 30, "%d", "\u{f186}", "How dark the overlay behind the menu is (0 = transparent, 100 = fully black)")
    script.fadeInEffect = g_general:switch("Fade In Effect", true, "\u{f252}", "Smooth fade-in animation when the menu is opened")
    script.slowMoFade = g_general:switch("Slow-Mo On Open", true, "\u{f017}", "Gradually accelerates particles from slow-motion to normal speed when opening the menu")

    -- ═══════════════════════════════════════════════════════════════
    --  Colors
    -- ═══════════════════════════════════════════════════════════════
    local g_colors = tab:create("Colors")

    script.shieldColor = g_colors:colorpicker("Primary Color", DEFAULT_PRIMARY_COLOR, "\u{f1fc}", "Main accent color used for particles, glow, and color wash")
    script.shieldColor2 = g_colors:colorpicker("Secondary Color", DEFAULT_SECONDARY_COLOR, "\u{f53f}", "Second accent color — particles alternate between primary and secondary")

    -- ═══════════════════════════════════════════════════════════════
    --  Particles
    -- ═══════════════════════════════════════════════════════════════
    local g_particles = tab:create("Particles")

    script.bgParticleCount = g_particles:slider("Particle Count", 20, 500, 100, "%d", "\u{f715}", "Total number of floating particles on screen (adapts to screen resolution)")
    script.shieldRadius = g_particles:slider("Particle Size", 1, 8, 2, "%d", "\u{f065}", "Base radius of each particle dot (pixels)")
    script.particleBaseAlpha = g_particles:slider("Particle Opacity", 10, 255, 150, "%d", "\u{f06e}", "Base opacity of particles (10 = barely visible, 255 = fully opaque)")
    script.particleSoftCore = g_particles:switch("Soft Core", true, "\u{f111}", "Adds a soft halo ring around each particle core for a smoother look")

    script.particleGlow = g_particles:switch("Particle Glow", true, "\u{f0eb}", "Enable a large colored glow aura behind every particle")
    script.particleGlowScale = script.particleGlow:slider("Glow Size", 1, 8, 3, "%d", "\u{f065}", "Multiplier for the glow radius relative to particle size")
    script.particleGlowAlpha = script.particleGlow:slider("Glow Opacity", 0, 100, 30, "%d%%", "\u{f042}", "How visible the glow aura is (0%% = invisible, 100%% = very bright)")

    -- ═══════════════════════════════════════════════════════════════
    --  Particle Motion
    -- ═══════════════════════════════════════════════════════════════
    local g_motion = tab:create("Particle Motion")

    script.particleSpeedScale = g_motion:slider("Particle Speed", 10, 400, 100, "%d%%", "\u{f3fd}", "How fast particles move across the screen (100%% = default speed)")
    script.particleDrift = g_motion:slider("Particle Drift", 0, 200, 35, "%d%%", "\u{f72e}", "How much particles sway and wobble during movement")
    script.particleTwinkleSpeedScale = g_motion:slider("Twinkle Speed", 0, 300, 100, "%d%%", "\u{f005}", "Speed of the brightness pulsation (twinkle) effect")
    script.particleTwinkleAmount = g_motion:slider("Twinkle Amount", 0, 100, 30, "%d%%", "\u{f0d0}", "Intensity of brightness variation — higher = more noticeable twinkle")

    -- ═══════════════════════════════════════════════════════════════
    --  Particle Links
    -- ═══════════════════════════════════════════════════════════════
    local g_links = tab:create("Particle Links")

    script.particleConnections = g_links:switch("Enable Links", true, "\u{f0c1}", "Draw thin lines between nearby particles creating a constellation web")
    script.particleConnectionDist = script.particleConnections:slider("Link Distance", 40, 400, 150, "%d", "\u{f545}", "Maximum distance (px) at which two particles are connected by a line")
    script.particleConnectionAlpha = script.particleConnections:slider("Link Opacity", 0, 150, 50, "%d", "\u{f070}", "Base opacity of connection lines (fades with distance)")
    script.particleConnectionWidth = script.particleConnections:slider("Link Width", 1, 3, 1, "%d", "\u{f0b2}", "Thickness of connection lines in pixels")
    script.particleMaxConnections = script.particleConnections:slider("Links per Particle", 0, 8, 3, "%d", "\u{f1ce}", "Max number of connections a single particle can have")
    script.particleColoredLinks = script.particleConnections:switch("Colored Links", true, "\u{f5aa}", "Tint connection lines with the particle colors instead of plain white")

    -- ═══════════════════════════════════════════════════════════════
    --  Cursor Interaction
    -- ═══════════════════════════════════════════════════════════════
    local g_cursor = tab:create("Cursor Interaction")

    script.particleCursorInteraction = g_cursor:switch("Enable Cursor Interaction", true, "\u{f245}", "Particles react to your mouse cursor movement")
    
    script.particleCursorMode = script.particleCursorInteraction:slider("Cursor Mode", 1, 3, 1, function(value)
        local mode = roundToInt(value)
        if mode == 1 then return "Repel" end
        if mode == 2 then return "Swipe" end
        if mode == 3 then return "Vortex" end
        return tostring(mode)
    end, "\u{f05b}", "Repel — pushes particles away, Swipe — drags in cursor direction, Vortex — swirls around cursor")

    script.particleCursorRadius = script.particleCursorInteraction:slider("Cursor Radius", 40, 600, 180, "%d", "\u{f51c}", "Area of effect around the cursor (pixels)")
    script.particleCursorForce = script.particleCursorInteraction:slider("Cursor Force", 100, 12000, 3200, "%d", "\u{f6e3}", "Strength of the push/pull force applied to particles")
    script.particleCursorFalloff = script.particleCursorInteraction:slider("Cursor Falloff", 25, 300, 120, "%d%%", "\u{f103}", "How quickly the force weakens with distance from cursor (higher = sharper edge)")
    script.particleCursorMotionBoost = script.particleCursorInteraction:slider("Cursor Motion Boost", 0, 300, 120, "%d%%", "\u{f135}", "Extra force multiplier when the cursor is moving fast")
    script.particleCursorMoveThreshold = script.particleCursorInteraction:slider("Cursor Move Threshold", 0, 40, 1, "%d", "\u{f051}", "Minimum cursor movement (px/frame) to trigger interaction")
    script.particleCursorOnlyMoving = script.particleCursorInteraction:switch("Only While Moving", true, "\u{f04b}", "Particles only react when the cursor is actively moving")
    script.particleCursorImpulseDamping = script.particleCursorInteraction:slider("Cursor Damping", 0, 300, 90, "%d%%", "\u{f3ed}", "How fast the cursor impulse fades — higher = particles slow down quicker")
    script.particleCursorSwirl = script.particleCursorInteraction:slider("Cursor Swirl", -100, 100, 60, "%d%%", "\u{f021}", "Tangential swirl strength for Vortex mode (negative = reverse direction)")

    script.clickRipple = g_cursor:switch("Click Ripple", true, "\u{f00a}", "Clicking on the menu creates a glowing ripple that pushes particles away")
    script.rippleSize = script.clickRipple:slider("Ripple Max Size", 50, 400, 200, "%d", "\u{f065}", "Maximum radius of the click ripple")
    script.rippleSpeed = script.clickRipple:slider("Ripple Speed", 50, 300, 150, "%d%%", "\u{f017}", "How fast the ripple wave expands")
    script.rippleForce = script.clickRipple:slider("Ripple Push Force", 100, 8000, 3000, "%d", "\u{f6e3}", "How hard the click wave pushes particles away")

    -- ═══════════════════════════════════════════════════════════════
    --  Mouse Trail
    -- ═══════════════════════════════════════════════════════════════
    local g_trail = tab:create("Mouse Trail")

    script.trailEnabled = g_trail:switch("Enable Mouse Trail", true, "\u{f245}", "Spawns glowing trail particles when moving the mouse pointer")
    script.trailColorMode = script.trailEnabled:slider("Color Mode", 1, 3, 1, function(value)
        local mode = roundToInt(value)
        if mode == 1 then return "Accent Colors" end
        if mode == 2 then return "Primary Only" end
        if mode == 3 then return "Secondary Only" end
        return tostring(mode)
    end, "\u{f1fc}", "Color scheme of the trail particles")
    script.trailSize = script.trailEnabled:slider("Particle Size", 1, 8, 3, "%d", "\u{f065}", "Base size of trail embers")
    script.trailOpacity = script.trailEnabled:slider("Trail Opacity", 10, 255, 180, "%d", "\u{f06e}", "Opacity of trail embers")
    script.trailDecay = script.trailEnabled:slider("Fade Speed", 50, 300, 100, "%d%%", "\u{f017}", "How fast trail particles fade out")

    -- ═══════════════════════════════════════════════════════════════
    --  Visual Effects
    -- ═══════════════════════════════════════════════════════════════
    local g_effects = tab:create("Visual Effects")

    script.backgroundBlur = g_effects:switch("Background Blur", false, "\u{f2a4}", "Apply a gaussian-like blur to the game behind the menu overlay")
    script.blurIntensity = script.backgroundBlur:slider("Blur Intensity", 0, 20, 5, "%d", "\u{f1de}", "Blur strength — uses multiple soft passes to avoid blocky artifacts")

    script.colorWash = g_effects:switch("Color Wash", true, "\u{f043}", "Subtle colored gradient overlay using your primary and secondary colors")

    script.stars = g_effects:switch("Twinkling Stars", true, "\u{f005}", "Show small twinkling stars in the background")
    script.starCount = script.stars:slider("Star Count", 100, 500, 200, "%d", "\u{f005}", "Number of background stars (adapts to screen resolution)")

    -- ═══════════════════════════════════════════════════════════════
    --  Advanced Effects
    -- ═══════════════════════════════════════════════════════════════
    local g_advanced = tab:create("Advanced Effects")

    script.shootingStars = g_advanced:switch("Shooting Stars", true, "\u{f753}", "Occasional shooting stars streak across the screen")
    script.shootingStarFreq = script.shootingStars:slider("Frequency", 1, 10, 5, "%d", "\u{f017}", "How often shooting stars appear (1 = rare, 10 = frequent)")
end

local function OnFrame()
    if not script.enabled or not script.enabled() then return end

    local realDt = GetAnimationDt()
    local dt = realDt

    local menuOpen = IsMenuOpen()
    if menuOpen and not menuWasOpen then
        fadeInTime = 0
        screenSize = GetScreenSize()
        vScreen.x = screenSize.x
        vScreen.y = screenSize.y
        densityMultiplier = (screenSize.x * screenSize.y) / (1920 * 1080)
        lastScreenUpdateTime = time
    end
    if menuOpen then
        fadeInTime = math_min(fadeInTime + realDt, CONSTANTS.FADE_IN_DURATION)
    end

    if script.slowMoFade and script.slowMoFade() and fadeInTime < CONSTANTS.FADE_IN_DURATION then
        local progress = fadeInTime / CONSTANTS.FADE_IN_DURATION
        dt = realDt * (0.15 + 0.85 * progress)
    end

    if not menuOpen then
        if menuWasOpen then
            deactivatePoolObjects(bgParticlePool)
            deactivatePoolObjects(starPool)
            deactivatePoolObjects(shootingStarPool)
            deactivatePoolObjects(trailPool)
            deactivatePoolObjects(ripplePool)
            for i, star in ipairs_cached(shootingStarPool) do
                if star.tail then
                    clearList(star.tail)
                end
            end
            clearList(bgParticleActive)
            clearList(starActive)
            clearList(trailActive)
            clearList(rippleActive)
        end
        menuWasOpen = false
        lastCursorX = nil
        lastCursorY = nil
        lastCursorModeApplied = nil
        lastCursorInteractionApplied = nil
        resetParticleImpulses()
        return
    end
    menuWasOpen = true

    time = time + dt
    UpdateScreenSize(time)

    currentFadeInAlpha = 1
    if script.fadeInEffect and script.fadeInEffect() and fadeInTime < CONSTANTS.FADE_IN_DURATION then
        currentFadeInAlpha = fadeInTime / CONSTANTS.FADE_IN_DURATION
    end

    -- Адаптивный расчет лимитов на основе разрешения экрана
    local targetParticleCount = math_floor((script.bgParticleCount() or 100) * densityMultiplier)
    local activeParticles = getActiveCount(bgParticlePool)
    if activeParticles < targetParticleCount then
        for i = 1, targetParticleCount - activeParticles do
            local particle = getFromPool(bgParticlePool, createBgParticle)
            if particle then
                particle.impulseX = 0
                particle.impulseY = 0
            end
        end
    elseif activeParticles > targetParticleCount then
        local toDeactivate = activeParticles - targetParticleCount
        for i = #bgParticlePool, 1, -1 do
            if toDeactivate <= 0 then break end
            if bgParticlePool[i].active then
                bgParticlePool[i].active = false
                toDeactivate = toDeactivate - 1
            end
        end
    end

    local targetStarCount = math_floor((script.starCount() or 200) * densityMultiplier)
    local activeStars = getActiveCount(starPool)
    if activeStars < targetStarCount then
        for i = 1, targetStarCount - activeStars do
            getFromPool(starPool, createStar)
        end
    elseif activeStars > targetStarCount then
        local toDeactivate = activeStars - targetStarCount
        for i = #starPool, 1, -1 do
            if toDeactivate <= 0 then break end
            if starPool[i].active then
                starPool[i].active = false
                toDeactivate = toDeactivate - 1
            end
        end
    end

    clearList(bgParticleActive)
    clearList(starActive)

    for i, particle in ipairs_cached(bgParticlePool) do
        if particle.active then
            particle.idx = #bgParticleActive + 1
            bgParticleActive[particle.idx] = particle
        end
    end

    for i, star in ipairs_cached(starPool) do
        if star.active then
            starActive[#starActive + 1] = star
        end
    end

    local w, h = screenSize.x, screenSize.y
    local particleSpeedScale = (script.particleSpeedScale and script.particleSpeedScale() or 100) * 0.01
    local particleDrift = (script.particleDrift and script.particleDrift() or 35) * 0.01
    local particleTwinkleSpeedScale = (script.particleTwinkleSpeedScale and script.particleTwinkleSpeedScale() or 100) * 0.01
    local particleTwinkleAmount = (script.particleTwinkleAmount and script.particleTwinkleAmount() or 30) * 0.01
    local wrapMargin = 50
    local cursorInteractionEnabled = script.particleCursorInteraction and script.particleCursorInteraction()
    local cursorPos = nil
    local frameCursorDeltaX = 0
    local frameCursorDeltaY = 0
    local frameCursorDeltaLen = 0
    local rawCursorMode = script.particleCursorMode and script.particleCursorMode() or 1
    local cursorMode = clamp(roundToInt(rawCursorMode), 1, 3)
    local cursorRadius = script.particleCursorRadius and script.particleCursorRadius() or 180
    local cursorRadiusSq = cursorRadius * cursorRadius
    local cursorForce = script.particleCursorForce and script.particleCursorForce() or 3200
    local cursorFalloffExp = (script.particleCursorFalloff and script.particleCursorFalloff() or 120) * 0.01
    local cursorMotionBoost = (script.particleCursorMotionBoost and script.particleCursorMotionBoost() or 120) * 0.01
    local cursorMoveThreshold = script.particleCursorMoveThreshold and script.particleCursorMoveThreshold() or 1
    local cursorOnlyMoving = script.particleCursorOnlyMoving and script.particleCursorOnlyMoving()
    local cursorImpulseDecay = clamp(1 - ((script.particleCursorImpulseDamping and script.particleCursorImpulseDamping() or 90) * 0.01) * 4 * dt, 0, 1)
    local cursorSwirl = (script.particleCursorSwirl and script.particleCursorSwirl() or 0) * 0.01

    if lastCursorModeApplied ~= cursorMode or lastCursorInteractionApplied ~= cursorInteractionEnabled then
        resetParticleImpulses()
        lastCursorModeApplied = cursorMode
        lastCursorInteractionApplied = cursorInteractionEnabled
    end

    local trailEnabled = script.trailEnabled and script.trailEnabled()
    local trackCursor = cursorInteractionEnabled or trailEnabled

    if trackCursor then
        cursorPos = GetCursorPos()
        if cursorPos then
            if lastCursorX ~= nil and lastCursorY ~= nil then
                frameCursorDeltaX = cursorPos.x - lastCursorX
                frameCursorDeltaY = cursorPos.y - lastCursorY
                frameCursorDeltaLen = math_sqrt(frameCursorDeltaX * frameCursorDeltaX + frameCursorDeltaY * frameCursorDeltaY)
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

    -- Физика частиц
    for i, particle in ipairs_cached(bgParticleActive) do
        particle.angle = particle.angle + (particle.angularVelocity or 0) * particleDrift * dt

        local driftWave = math_sin(time * (particle.driftSpeed or 1) * math_max(0, particleTwinkleSpeedScale) + (particle.driftPhase or i))
        local moveAngle = particle.angle + driftWave * 0.35 * particleDrift * (particle.driftStrength or 1)
        local moveSpeed = particle.speed * 20 * dt * particleSpeedScale * (particle.depth or 1)
        particle.x = particle.x + math_cos(moveAngle) * moveSpeed
        particle.y = particle.y + math_sin(moveAngle) * moveSpeed

        local impulseX = (particle.impulseX or 0) * cursorImpulseDecay
        local impulseY = (particle.impulseY or 0) * cursorImpulseDecay

        if cursorInteractionEnabled and cursorPos then
            local dx = particle.x - cursorPos.x
            local dy = particle.y - cursorPos.y
            local distSq = dx * dx + dy * dy

            if distSq < cursorRadiusSq and cursorRadius > 0 then
                local allowInteraction = (not cursorOnlyMoving) or (frameCursorDeltaLen > cursorMoveThreshold)
                if allowInteraction then
                    local dist = math_sqrt(distSq)
                    if dist < 0.001 then
                        dist = 0.001
                        dx = math_cos((particle.driftPhase or 0) + i)
                        dy = math_sin((particle.driftPhase or 0) + i)
                    end

                    local nx = dx / dist
                    local ny = dy / dist
                    local t = clamp(1 - (dist / cursorRadius), 0, 1)
                    local falloff = t ^ math_max(0.05, cursorFalloffExp)
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
                        else
                            forceX = 0
                            forceY = 0
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

                        swirlStrength = math_abs(swirlStrength)
                        local vortexForce = radialForce * (0.6 + swirlStrength)
                        forceX = tangentX * vortexForce
                        forceY = tangentY * vortexForce
                    else
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

        local twinkle = math_sin(time * 2 * (particle.twinkleSpeed or 1) * math_max(0, particleTwinkleSpeedScale) + (particle.twinklePhase or i))
        particle.brightness = clamp((particle.baseBrightness or 0.6) + twinkle * particleTwinkleAmount, 0.05, 1)

        if particle.x < -wrapMargin then particle.x = w + wrapMargin end
        if particle.x > w + wrapMargin then particle.x = -wrapMargin end
        if particle.y < -wrapMargin then particle.y = h + wrapMargin end
        if particle.y > h + wrapMargin then particle.y = -wrapMargin end
    end

    -- Звезды
    for i, star in ipairs_cached(starActive) do
        star.brightness = 0.5 + math_sin(time * star.twinkleSpeed + star.twinklePhase) * 0.5
    end

    -- Падающие звезды
    if script.shootingStars and script.shootingStars() then
        if math_random() < script.shootingStarFreq() * dt * 0.01 then
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

    -- Спавн следа мыши при движении курсора (Интерактивный шлейф)
    if trailEnabled and cursorPos and lastCursorX ~= nil and lastCursorY ~= nil then
        if frameCursorDeltaLen > 5 then
            local decayMultiplier = (script.trailDecay and script.trailDecay() or 100) * 0.01
            local trailSizeBase = script.trailSize and script.trailSize() or 3
            local trailColorMode = script.trailColorMode and script.trailColorMode() or 1
            
            local steps = math_floor(frameCursorDeltaLen / 8)
            if steps < 1 then steps = 1 end
            if steps > 8 then steps = 8 end
            
            for step = 1, steps do
                local t = step / steps
                local x = lastCursorX + (cursorPos.x - lastCursorX) * t
                local y = lastCursorY + (cursorPos.y - lastCursorY) * t
                
                local trailPart = getFromPool(trailPool, createTrailParticle)
                if trailPart then
                    trailPart.x = x
                    trailPart.y = y
                    trailPart.vx = frameCursorDeltaX * 0.15 + (math_random() - 0.5) * 15
                    trailPart.vy = frameCursorDeltaY * 0.15 - math_random(15, 40)
                    trailPart.lifetime = (math_random(40, 80) / 100) / decayMultiplier
                    trailPart.maxLifetime = trailPart.lifetime
                    trailPart.size = math_random(1, 3) * (trailSizeBase * 0.5)
                    
                    if trailColorMode == 1 then
                        trailPart.colorIdx = math_random(1, 2)
                    elseif trailColorMode == 2 then
                        trailPart.colorIdx = 1
                    else
                        trailPart.colorIdx = 2
                    end
                end
            end
        end
    end

    -- Обновление шлейфа мыши
    clearList(trailActive)
    for i, p in ipairs_cached(trailPool) do
        if p.active then
            p.lifetime = p.lifetime - dt
            if p.lifetime <= 0 then
                p.active = false
            else
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                -- Замедление и плавный подъем вверх
                p.vx = p.vx * (1 - 2 * dt)
                p.vy = p.vy - 15 * dt
                trailActive[#trailActive + 1] = p
            end
        end
    end

    -- Спавн и физика волн от клика (Click Ripple)
    if script.clickRipple and script.clickRipple() and input and input.is_pressed and input.is_pressed(314) then
        local clickPos = GetCursorPos()
        if clickPos then
            local ripple = getFromPool(ripplePool, createRipple)
            if ripple then
                ripple.x = clickPos.x
                ripple.y = clickPos.y
                ripple.progress = 0
                ripple.maxRadius = script.rippleSize and script.rippleSize() or 200
                local speedPct = script.rippleSpeed and script.rippleSpeed() or 150
                ripple.speed = (speedPct * 0.01) * 2.0
                local pushForce = script.rippleForce and script.rippleForce() or 3000

                -- Мгновенный импульс частицам
                for k = 1, #bgParticleActive do
                    local p = bgParticleActive[k]
                    local dx = p.x - clickPos.x
                    local dy = p.y - clickPos.y
                    local distSq = dx * dx + dy * dy
                    local rSq = ripple.maxRadius * ripple.maxRadius
                    if distSq < rSq then
                        local dist = math_sqrt(distSq)
                        if dist < 0.001 then dist = 0.001 end
                        local tFactor = 1 - (dist / ripple.maxRadius)
                        local force = tFactor * pushForce
                        p.impulseX = (p.impulseX or 0) + (dx / dist) * force
                        p.impulseY = (p.impulseY or 0) + (dy / dist) * force
                    end
                end
            end
        end
    end

    -- Обновление активных волн
    clearList(rippleActive)
    for k = 1, #ripplePool do
        local r = ripplePool[k]
        if r.active then
            r.progress = r.progress + dt * r.speed
            if r.progress >= 1.0 then
                r.active = false
            else
                rippleActive[#rippleActive + 1] = r
            end
        end
    end
end

local function DrawBackgroundEffects(fadeInAlpha)
    if not script.backgroundOpacity then
        return
    end

    fadeInAlpha = fadeInAlpha or 1

    local opacity = script.backgroundOpacity()
    local primaryColor = getPrimaryColor()
    local secondaryColor = getSecondaryColor()

    local fadeOpacity = math_floor(opacity * 2.55 * fadeInAlpha)
    Render.FilledRect(vZero, vScreen, Color(0, 0, 0, fadeOpacity), 0)

    -- Размытие (Blur)
    if script.backgroundBlur and script.backgroundBlur() and script.blurIntensity then
        local blurIntensity = script.blurIntensity()
        if blurIntensity > 0 then
            local maxPassStrength = 1.2
            local totalStrength = blurIntensity * 0.15
            local passCount = math_max(1, math_floor(totalStrength / maxPassStrength + 0.99))
            local perPass = totalStrength / passCount
            for _blurPass = 1, passCount do
                Render.Blur(vZero, vScreen, perPass)
            end
        end
    end

    -- Мягкий цветной градиент
    if script.colorWash and script.colorWash() then
        local washAlpha = math_floor((12 + opacity * 0.18) * fadeInAlpha)
        local washAlphaSoft = math_floor(washAlpha * 0.6)

        gradientRectCompat(
            vZero,
            screenSize,
            Color(primaryColor.r, primaryColor.g, primaryColor.b, washAlpha),
            Color(secondaryColor.r, secondaryColor.g, secondaryColor.b, washAlpha),
            true
        )

        gradientRectCompat(
            vZero,
            screenSize,
            Color(10, 18, 32, washAlphaSoft),
            Color(0, 0, 0, 0),
            false
        )
    end

    -- Звезды
    if script.stars and script.stars() then
        for i, star in ipairs_cached(starActive) do
            local alpha = math_floor(star.brightness * 255 * fadeInAlpha)

            vTemp1.x = star.x
            vTemp1.y = star.y
            renderFilledCircle(vTemp1, star.size * 2, Color(255, 255, 255, math_floor(alpha * 0.3)), 16)
            renderFilledCircle(vTemp1, star.size, Color(255, 255, 255, alpha), 8)

            if star.brightness > CONSTANTS.STAR_RAY_BRIGHTNESS_THRESHOLD then
                local rayLength = star.size * 4
                for angle = 0, math_pi * 2, math_pi / 2 do
                    vTemp1.x = star.x + math_cos(angle) * star.size
                    vTemp1.y = star.y + math_sin(angle) * star.size
                    vTemp2.x = star.x + math_cos(angle) * rayLength
                    vTemp2.y = star.y + math_sin(angle) * rayLength

                    Render.Line(vTemp1, vTemp2, Color(255, 255, 255, math_floor(alpha * 0.5)), 1)
                end
            end
        end
    end

    -- Падающие звезды
    if script.shootingStars and script.shootingStars() then
        for _, star in ipairs_cached(shootingStarPool) do
            if star.active then
                local x = star.startX + (star.endX - star.startX) * star.progress
                local y = star.startY + (star.endY - star.startY) * star.progress

                for i = 1, #star.tail - 1 do
                    local tailAlpha = math_floor((i / #star.tail) * 200 * fadeInAlpha)
                    local size = star.size * (i / #star.tail)
                    vTemp1.x = star.tail[i].x
                    vTemp1.y = star.tail[i].y
                    renderFilledCircle(vTemp1, size, Color(255, 255, 200, tailAlpha), 8)
                end

                vTemp1.x = x
                vTemp1.y = y
                renderFilledCircle(vTemp1, star.size, Color(255, 255, 255, 255 * fadeInAlpha), 8)
                renderFilledCircle(vTemp1, star.size * 3, Color(255, 255, 200, math_floor(100 * fadeInAlpha)), 16)
            end
        end
    end

    -- Отрисовка интерактивного шлейфа мыши
    if script.trailEnabled and script.trailEnabled() then
        local trailOpacity = script.trailOpacity and script.trailOpacity() or 180
        for i, p in ipairs_cached(trailActive) do
            local progress = p.lifetime / p.maxLifetime
            if progress > 0 then
                local alpha = math_floor(progress * trailOpacity * fadeInAlpha)
                local size = p.size * (0.3 + 0.7 * progress)
                local pColor = p.colorIdx == 1 and primaryColor or secondaryColor
                vTemp1.x = p.x
                vTemp1.y = p.y
                renderFilledCircle(vTemp1, size, Color(pColor.r, pColor.g, pColor.b, alpha), 8)
            end
        end
    end

    -- Отрисовка волн от кликов (Click Ripples)
    if script.clickRipple and script.clickRipple() then
        for i = 1, #rippleActive do
            local r = rippleActive[i]
            local progress = r.progress
            if progress > 0 and progress < 1 then
                local alpha = math_floor((1 - progress) * 150 * fadeInAlpha)
                local radius = r.maxRadius * progress
                vTemp1.x = r.x
                vTemp1.y = r.y
                
                -- Отрисовываем основное цветное кольцо волны (первичный цвет)
                renderCircle(vTemp1, radius, Color(primaryColor.r, primaryColor.g, primaryColor.b, alpha), 32, 2.0)
                -- Тонкое дополнительное кольцо (вторичный цвет)
                renderCircle(vTemp1, radius + 2, Color(secondaryColor.r, secondaryColor.g, secondaryColor.b, math_floor(alpha * 0.5)), 32, 1.0)
                -- Мягкое внутреннее заполнение
                renderFilledCircle(vTemp1, radius, Color(primaryColor.r, primaryColor.g, primaryColor.b, math_floor(alpha * 0.1)), 24)
            end
        end
    end

    local c1 = primaryColor
    local c2 = secondaryColor
    local particleSize = script.shieldRadius and script.shieldRadius() or 2
    local particleBaseAlpha = script.particleBaseAlpha and script.particleBaseAlpha() or 150
    local particleGlowScale = script.particleGlowScale and script.particleGlowScale() or 3
    local particleGlowAlphaScale = (script.particleGlowAlpha and script.particleGlowAlpha() or 30) * 0.01
    local particleGlowEnabled = script.particleGlow and script.particleGlow()
    local particleSoftCore = script.particleSoftCore and script.particleSoftCore()
    local particleLinksEnabled = script.particleConnections and script.particleConnections()
    
    -- Адаптивная дистанция связей
    local connectionDist = (script.particleConnectionDist and script.particleConnectionDist() or CONSTANTS.PARTICLE_CONNECTION_DIST) * math_sqrt(densityMultiplier)
    local connectionDistSq = connectionDist * connectionDist
    
    local maxConnections = script.particleMaxConnections and script.particleMaxConnections() or CONSTANTS.PARTICLE_MAX_CONNECTIONS
    local linkBaseAlpha = script.particleConnectionAlpha and script.particleConnectionAlpha() or 50
    local linkWidth = script.particleConnectionWidth and script.particleConnectionWidth() or 1
    local coloredLinks = script.particleColoredLinks and script.particleColoredLinks()

    -- Отрисовка частиц
    for i, particle in ipairs_cached(bgParticleActive) do
        local pColor = particle.colorIdx == 1 and c1 or c2
        local alpha = math_floor(particle.brightness * particleBaseAlpha * fadeInAlpha)
        local radius = particle.size * particleSize * (particle.depth or 1) * 0.85

        vTemp1.x = particle.x
        vTemp1.y = particle.y

        if particleGlowEnabled then
            local glowSize = radius * particleGlowScale
            local glowAlpha = math_floor(alpha * particleGlowAlphaScale)
            if glowAlpha > 0 then
                renderFilledCircle(vTemp1, glowSize, Color(pColor.r, pColor.g, pColor.b, glowAlpha), 16)
            end
        end

        if particleSoftCore then
            renderFilledCircle(vTemp1, radius * 1.8, Color(pColor.r, pColor.g, pColor.b, math_floor(alpha * 0.25)), 12)
        end

        renderFilledCircle(vTemp1, radius, Color(pColor.r, pColor.g, pColor.b, alpha), 8)
        renderFilledCircle(vTemp1, math_max(0.6, radius * 0.45), Color(255, 255, 255, math_floor(alpha * 0.5)), 8)
    end

    -- Оптимизированный рендеринг связей (Constellation Links) с помощью 2D-сетки пространственного разбиения O(N)
    if particleLinksEnabled and maxConnections > 0 and connectionDist > 0 then
        local cellSize = connectionDist
        if cellSize < 1 then cellSize = 1 end
        
        -- Построение пространственной хэш-карты
        local grid = {}
        for i = 1, #bgParticleActive do
            local p = bgParticleActive[i]
            p.connections = 0
            
            local cx = math_floor(p.x / cellSize)
            local cy = math_floor(p.y / cellSize)
            local key = cx * 1000 + cy -- быстрое числовое хэширование (быстрее строк)
            
            local cell = grid[key]
            if not cell then
                cell = {}
                grid[key] = cell
            end
            cell[#cell + 1] = p
        end
        
        -- Поиск связей только в текущей и 8 соседних ячейках
        for i = 1, #bgParticleActive do
            local p1 = bgParticleActive[i]
            if p1.connections < maxConnections then
                local cx = math_floor(p1.x / cellSize)
                local cy = math_floor(p1.y / cellSize)
                
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local key = (cx + dx) * 1000 + (cy + dy)
                        local cell = grid[key]
                        if cell then
                            for k = 1, #cell do
                                local p2 = cell[k]
                                -- Связываем только если p1.idx < p2.idx, чтобы избежать двойной отрисовки линии
                                if p2 ~= p1 and p2.connections < maxConnections and p1.connections < maxConnections and p1.idx < p2.idx then
                                    local dx_val = p1.x - p2.x
                                    local dy_val = p1.y - p2.y
                                    local distSq = dx_val * dx_val + dy_val * dy_val
                                    
                                    if distSq < connectionDistSq then
                                        local dist = math_sqrt(distSq)
                                        local alpha = math_floor((connectionDist - dist) / connectionDist * linkBaseAlpha * fadeInAlpha)
                                        if alpha > 0 then
                                            vTemp1.x = p1.x
                                            vTemp1.y = p1.y
                                            vTemp2.x = p2.x
                                            vTemp2.y = p2.y
                                            if coloredLinks then
                                                local p1Color = p1.colorIdx == 1 and c1 or c2
                                                local p2Color = p2.colorIdx == 1 and c1 or c2
                                                local lineColor = Color(
                                                    math_floor((p1Color.r + p2Color.r) * 0.5),
                                                    math_floor((p1Color.g + p2Color.g) * 0.5),
                                                    math_floor((p1Color.b + p2Color.b) * 0.5),
                                                    alpha
                                                )
                                                Render.Line(vTemp1, vTemp2, lineColor, linkWidth)
                                            else
                                                Render.Line(vTemp1, vTemp2, Color(255, 255, 255, alpha), linkWidth)
                                            end
                                        end
                                        p1.connections = p1.connections + 1
                                        p2.connections = p2.connections + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function OnDraw()
    if not script.enabled or not script.enabled() then return end
    if not IsMenuOpen() then return end

    if script.backgroundEffects and script.backgroundEffects() then
        DrawBackgroundEffects(currentFadeInAlpha)
    end
end

callback.on_scripts_loaded:set(OnScriptsLoaded)
callback.on_frame:set(OnFrame)
callback.on_draw:set(OnDraw)

return script
