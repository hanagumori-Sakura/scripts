--[[
        ~ Drow Ranger Gust Control - Auto-silence and interrupt helper
        ~ Designed for uc.zone Umbrella cheat for Dota 2
        ~ Dynamic targeting, angle-sweep optimization, and horizontal cell-based HUD panel
--]]

-- Unique instance tracking to prevent duplicate drawing on script reload
local myInstanceId = os.clock() .. "_" .. tostring(math.random(100000, 999999))
DrowRangerGust_ActiveInstanceId = myInstanceId

local DRGust = {}
local menuItems = {}
local imgCache = {}
local wasMousePressed = false
local lastGustCastTime = 0
local lastDebugLogTime = 0
local gear = nil

-- Panel configuration
local PanelConfig = {
    X = 200,
    Y = 200,
    Width = 230, -- Dynamically calculated on draw based on number of enemies
}

local PanelDrag = {
    IsDragging = false,
    OffsetX = 0,
    OffsetY = 0
}

-- Harmonious iOS-style / Screenshot matching colors
local Colors = {
    HeaderBg = Color(32, 28, 36, 245), -- Dark purple-gray matching screenshot
    PanelBg = Color(21, 19, 24, 220),  -- Dark transparent panel body background
    CellBg = Color(42, 38, 45, 255),   -- Dark cell background matching screenshot
    TextHeader = Color(245, 247, 250, 255),
    BorderDisabled = Color(60, 60, 65, 255),
    BorderAlways = Color(50, 220, 110, 255), -- Emerald green
    BorderNeeded = Color(50, 160, 255, 255), -- Neon blue
    BorderCasting = Color(255, 75, 75, 255), -- Crimson red
    BorderPanel = Color(255, 255, 255, 12),  -- Subtle border for glassmorphism
}

-- Helper function to fetch the current active theme colors from Menu.Style
local function GetThemeColor(name, defaultColor)
    if not Menu or not Menu.Style then return defaultColor end

    local ok, col = pcall(Menu.Style, name)
    if ok and col and type(col) == "userdata" then
        return col
    end

    local ok_tbl, tbl = pcall(Menu.Style)
    if ok_tbl and type(tbl) == "table" and tbl[name] then
        local c = tbl[name]
        if c and type(c.r) == "number" then
            return Color(c.r, c.g, c.b, c.a or 255)
        end
    end

    return defaultColor
end

local function GetLuminance(color)
    if not color then return 0 end
    return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
end

-- Synchronize HUD panel colors to match active cheat menu theme
local function SyncColors()
    local primary = GetThemeColor("primary", Color(120, 160, 255, 255))
    local background = GetThemeColor("additional_background", Color(32, 28, 36, 245))

    local bgLuminance = GetLuminance(background)

    local finalTextColor
    local cellBgColor
    local borderDisabledColor
    local panelBorderColor

    if bgLuminance > 140 then
        -- Light theme
        finalTextColor = Color(20, 24, 33, 255)
        cellBgColor = Color(background.r - 20, background.g - 20, background.b - 20, 255)
        borderDisabledColor = Color(160, 160, 165, 255)
        panelBorderColor = Color(0, 0, 0, 35)
    else
        -- Dark theme
        finalTextColor = Color(245, 247, 250, 255)
        cellBgColor = Color(background.r + 10, background.g + 10, background.b + 10, 255)
        borderDisabledColor = Color(60, 60, 65, 255)
        panelBorderColor = Color(255, 255, 255, 25)
    end

    Colors.HeaderBg = Color(background.r, background.g, background.b, 245)
    Colors.PanelBg = Color(math.max(10, background.r - 11), math.max(10, background.g - 10),
        math.max(10, background.b - 12), 220)

    Colors.CellBg = cellBgColor
    Colors.TextHeader = finalTextColor
    Colors.BorderDisabled = borderDisabledColor
    Colors.BorderPanel = panelBorderColor

    -- Accent/primary color maps to "Needed" target outline
    Colors.BorderNeeded = Color(primary.r, primary.g, primary.b, 255)
end

-- Initialize theme colors
SyncColors()

-- Fonts
local fontNormal = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
local fontSmall = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.LIGHT)

-- Localization helper
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

-- UI Initialization (Drow Ranger -> Main Settings -> Gust group with Gear popup)
local function InitializeUI()
    local mainSection = Menu.Find("Heroes", "Hero List", "Drow Ranger", "Main Settings")
    if mainSection and mainSection.Create then
        return mainSection:Create("Gust")
    end

    -- Fallback tab if Drow Ranger menu isn't found
    local fallbackTab = Menu.Create("General", "Drow Ranger Gust", "dr_gust")
    if fallbackTab and fallbackTab.Icon then
        fallbackTab:Icon("\u{f70c}")
    end
    return fallbackTab:Create("Gust")
end

local gustGroup = InitializeUI()

local scriptEnabled = gustGroup:Switch(L("Enable Gust Control", "Включить контроль Gust"), true,
    "panorama/images/spellicons/drow_ranger_wave_of_silence_png.vtex_c")
scriptEnabled:ToolTip(L("Auto-interrupt spells & smart combo cast for Drow Ranger Gust",
    "Авто-прерывание заклинаний и умное комбо для способности Gust"))

-- Gear settings attachment directly on the main switch
gear = scriptEnabled:Gear(L("Gust Settings", "Настройки Gust"))

local interruptOnlyInCombo = gear:Switch(L("Only in Combo", "Только при комбо"), true, "\u{f007}")
local pushCloseEnemies = gear:Switch(L("Push Close Enemies", "Толкать врагов в упоре"), true, "\u{f0a1}")
pushCloseEnemies:ToolTip(L("Auto-cast Gust on enemy heroes that get too close to push them back",
    "Авто-использовать Gust на вражеских героев, подошедших слишком близко, чтобы оттолкнуть их"))
local pushRangeSlider = gear:Slider(L("Push Trigger Range", "Дистанция толчка"), 150, 600, 375)
local pushOnlyInCombo = gear:Switch(L("Push Only in Combo", "Толкать только при комбо"), false, "\u{f007}")
local pushDisabledTargets = gear:Switch(L("Push Disabled Targets", "Толкать отключенных врагов"), true, "\u{f023}")
pushDisabledTargets:ToolTip(L("Allow pushing back close enemies even if they are marked as Disabled in the HUD",
    "Разрешить отталкивать подошедших близко врагов, даже если они отключены на панели HUD"))
local drawPanel = gear:Switch(L("Draw Control Panel", "Показывать панель"), true, "\u{f080}")
local dragMode = gear:Switch(L("HUD Drag Mode", "Перемещение HUD"), false, "\u{f047}")
local debugMode = gear:Switch(L("Enable Debug Logs", "Включить логи отладки"), false, "\u{f120}")
debugMode:ToolTip(L("Write debug details to C:\\Umbrella\\debug.log to troubleshoot execution",
    "Записывать детали отладки в файл C:\\Umbrella\\debug.log"))

-- Coordinates persistence sliders inside the gear popup
local panelX = gear:Slider("HUD X", 0, 3840, 200)
local panelY = gear:Slider("HUD Y", 0, 2160, 200)
panelX:Visible(false)
panelY:Visible(false)

local function LoadPanelPosition()
    if panelX and panelY then
        local x = panelX:Get()
        local y = panelY:Get()
        if x > 0 or y > 0 then
            PanelConfig.X = x
            PanelConfig.Y = y
        end
    end
end

local function SavePanelPosition()
    if panelX and panelY then
        panelX:Set(PanelConfig.X)
        panelY:Set(PanelConfig.Y)
    end
end

-- Safely retrieves or dynamically registers combo box settings for enemy heroes
local function GetOrCreateMenuItem(cleanName)
    if menuItems[cleanName] then
        return menuItems[cleanName]
    end
    if not gear then return nil end

    local existing = gear:Find(cleanName)
    if existing then
        menuItems[cleanName] = existing
        return existing
    end

    -- Create it dynamically inside the gear attachment
    local item = gear:Combo(cleanName, {
        L("Disabled", "Отключено"),
        L("Always", "Всегда"),
        L("When casting", "Когда нужно")
    }, 2) -- Defaults to 'When casting'
    menuItems[cleanName] = item
    return item
end

-- Helper function for shifting color hue (for glowing boundaries)
local function ShiftColorHue(color, shiftAmount)
    if not color then return Color(255, 255, 255, 255) end
    local ok, h, s, l = pcall(color.ToHsl, color)
    if not ok or not h then
        return color
    end

    local newH = (h + shiftAmount) % 1.0
    local newCol = Color(0, 0, 0, 255)
    local ok_as = pcall(newCol.AsHsl, newCol, newH, s, l, (color.a or 255) / 255)
    if not ok_as then
        return color
    end
    return newCol
end

-- Shadowed text helper
local function DrawShadowText(fontObj, size, text, pos, color, shadowAlpha)
    shadowAlpha = shadowAlpha or 160
    local shadowColor = Color(0, 0, 0, shadowAlpha)
    Render.Text(fontObj, size, text, Vec2(pos.x + 1, pos.y + 1), shadowColor)
    Render.Text(fontObj, size, text, pos, color)
end

-- Mouse utilities
local function GetMousePos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok and type(x) == "number" then return x, y end
    end
    return nil, nil
end

local function IsLmbDown()
    if Input and Input.IsKeyDown then
        local ok, down = pcall(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1)
        if ok then return down end
    end
    return false
end

-- Hero image loading
local function GetHeroIcon(heroName)
    if not heroName or heroName == "" then return nil end
    if imgCache[heroName] then return imgCache[heroName] end
    local path = "panorama/images/heroes/" .. heroName .. "_png.vtex_c"
    local handle = Render.LoadImage(path)
    if handle then
        imgCache[heroName] = handle
    end
    return handle
end

-- Checks if the target is already disabled or immune
local function IsNPCDecapacitated(npc)
    if not npc then return false end
    if NPC.HasState(npc, Enum.ModifierState.MODIFIER_STATE_SILENCED) or
        NPC.HasState(npc, Enum.ModifierState.MODIFIER_STATE_STUNNED) or
        NPC.HasState(npc, Enum.ModifierState.MODIFIER_STATE_HEXED) or
        NPC.HasState(npc, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) or
        NPC.HasState(npc, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
        return true
    end
    return false
end

-- Checks if NPC is casting or channeling
local function IsNPCUsingAbility(npc)
    if not npc or not Entity.IsAlive(npc) then return nil end

    -- Check channeling first
    local channelling = NPC.GetChannellingAbility(npc)
    if channelling then
        return channelling
    end

    -- Check casting abilities
    for i = 0, 23 do
        local ability = NPC.GetAbilityByIndex(npc, i)
        if ability and Ability.IsInAbilityPhase(ability) then
            return ability
        end
    end

    -- Check casting items
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(npc, i)
        if item and Ability.IsInAbilityPhase(item) then
            return item
        end
    end

    return nil
end

-- Geometric hit test for Gust wave
local function WillHit(D, P_cast, P_E, range, width)
    local dir = (P_cast - D):Normalized()
    local to_E = P_E - D
    local proj = to_E:Dot2D(dir)
    if proj < 0 or proj > range then
        return false
    end
    local dist_sq = to_E:Length2DSqr() - proj * proj
    return dist_sq <= (width / 2) ^ 2
end

-- Get score weight for targeting optimization
local function GetEnemyScore(enemy, D)
    local heroName = NPC.GetUnitName(enemy)
    local cleanName = heroName:gsub("npc_dota_hero_", "")
    cleanName = cleanName:sub(1, 1):upper() .. cleanName:sub(2)

    local menuItem = GetOrCreateMenuItem(cleanName)
    local val = menuItem and menuItem:Get() or 0

    local isTooClose = false
    if pushCloseEnemies:Get() and D then
        local dist = (Entity.GetAbsOrigin(enemy) - D):Length2D()
        if dist <= pushRangeSlider:Get() then
            if not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_STUNNED) and
                not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_HEXED) and
                not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) and
                not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
                if val > 0 or (pushDisabledTargets and pushDisabledTargets:Get()) then
                    isTooClose = true
                end
            end
        end
    end

    if val == 0 and not isTooClose then
        return 0
    end

    local baseScore = 1
    if val == 1 then
        baseScore = 2
    elseif val == 2 then
        baseScore = 1.5
    elseif val == 0 and isTooClose then
        baseScore = 1.2
    end

    if IsNPCUsingAbility(enemy) then
        baseScore = baseScore + 10 -- Huge weight for casting enemies
    end

    return baseScore
end

-- Optimize Gust direction to hit primary target T and maximize surrounding hits
local function OptimizeGust(D, T, enemiesInRange, range, width)
    local P_T = Entity.GetAbsOrigin(T)
    local dir_T = (P_T - D):Normalized()
    local angle_T = math.atan2(dir_T.y, dir_T.x)
    local d_T = (P_T - D):Length2D()

    local half_w = width / 2
    local alpha = d_T > 0 and math.asin(math.min(1.0, half_w / d_T)) or math.pi / 2

    local bestScore = -1
    local bestPos = nil

    local steps = 10
    for i = 0, steps do
        local angle = (angle_T - alpha) + (i / steps) * (2 * alpha)
        local candidate_dir = Vector(math.cos(angle), math.sin(angle), 0)
        local candidate_pos = D + candidate_dir * range

        local score = 0
        for _, enemy in ipairs(enemiesInRange) do
            local P_E = Entity.GetAbsOrigin(enemy)
            if WillHit(D, candidate_pos, P_E, range, width) then
                score = score + GetEnemyScore(enemy, D)
            end
        end

        if score > bestScore then
            bestScore = score
            bestPos = candidate_pos
        end
    end

    return bestScore, bestPos
end

-- Logic tick loop
DRGust.OnUpdate = function()
    if DrowRangerGust_ActiveInstanceId ~= myInstanceId then return end
    if not scriptEnabled:Get() then return end

    local now = os.clock()
    local dbg = debugMode:Get()
    local shouldLog = false
    if dbg and (now - lastDebugLogTime > 2.0) then
        shouldLog = true
        lastDebugLogTime = now
    end

    local myHero = Heroes.GetLocal()
    if not myHero then
        if shouldLog then Log.Write("[DrowGust] Exit: Local hero is nil") end
        return
    end

    local heroName = NPC.GetUnitName(myHero)
    if heroName ~= "npc_dota_hero_drow_ranger" then
        if shouldLog then Log.Write("[DrowGust] Exit: Hero is " .. tostring(heroName) .. ", not drow_ranger") end
        return
    end

    if not Entity.IsAlive(myHero) then
        if shouldLog then Log.Write("[DrowGust] Exit: Drow Ranger is dead") end
        return
    end

    local gust = NPC.GetAbility(myHero, "drow_ranger_wave_of_silence")
    if not gust then
        if shouldLog then Log.Write("[DrowGust] Exit: Gust ability (drow_ranger_wave_of_silence) not found") end
        return
    end

    local gustLevel = Ability.GetLevel(gust)
    if gustLevel == 0 then
        if shouldLog then Log.Write("[DrowGust] Exit: Gust is level 0 (not learned)") end
        return
    end

    local isReady = Ability.IsReady(gust)
    local mana = NPC.GetMana(myHero)
    local isCastable = Ability.IsCastable(gust, mana)

    if not isReady or not isCastable then
        if shouldLog then
            Log.Write(string.format("[DrowGust] Exit: Gust ready=%s, castable=%s (mana=%.0f)",
                tostring(isReady), tostring(isCastable), mana))
        end
        return
    end

    if now - lastGustCastTime < 0.5 then
        return
    end

    -- Setup/Synchronize targets settings dynamically inside the gear attachment popup
    local enemies = Heroes.GetAll()
    for _, hero in ipairs(enemies) do
        if hero ~= myHero and not Entity.IsSameTeam(myHero, hero) and not NPC.IsIllusion(hero) then
            local enemyHeroName = NPC.GetUnitName(hero)
            local cleanName = enemyHeroName:gsub("npc_dota_hero_", "")
            cleanName = cleanName:sub(1, 1):upper() .. cleanName:sub(2)

            GetOrCreateMenuItem(cleanName)
        end
    end

    -- Check if combo key is held down
    local inCombo = false
    local nativeCombo = Menu.Find("Heroes", "Hero List", "Drow Ranger", "Main Settings", "Hero Settings", "Combo Key")
    if nativeCombo and nativeCombo.IsDown and nativeCombo:IsDown() then
        inCombo = true
    end

    local D = Entity.GetAbsOrigin(myHero)
    local castRange = Ability.GetCastRange(gust) + NPC.GetCastRangeBonus(myHero)
    local width = 250

    if shouldLog then
        Log.Write(string.format("[DrowGust] TICK - Gust ready. Range: %.0f, Mana: %.0f, InCombo: %s",
            castRange, mana, tostring(inCombo)))
    end

    local enemiesInRange = {}
    local castingEnemies = {}
    local pushEnemies = {}
    local alwaysEnemies = {}

    for _, enemy in ipairs(enemies) do
        if enemy ~= myHero and not Entity.IsSameTeam(myHero, enemy) and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
            local enemyHeroName = NPC.GetUnitName(enemy)
            local cleanName = enemyHeroName:gsub("npc_dota_hero_", "")
            cleanName = cleanName:sub(1, 1):upper() .. cleanName:sub(2)

            local menuItem = GetOrCreateMenuItem(cleanName)
            local val = menuItem and menuItem:Get() or 0

            local dist = (Entity.GetAbsOrigin(enemy) - D):Length2D()

            local isDecap = IsNPCDecapacitated(enemy)
            local currentCasting = IsNPCUsingAbility(enemy)

            -- Check if too close to push back
            local isTooClose = false
            if pushCloseEnemies:Get() and dist <= pushRangeSlider:Get() then
                if not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_STUNNED) and
                    not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_HEXED) and
                    not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) and
                    not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
                    if val > 0 or pushDisabledTargets:Get() then
                        isTooClose = true
                    end
                end
            end

            if shouldLog and (val > 0 or isTooClose) then
                Log.Write(string.format(
                    "[DrowGust] Target %s: val=%.0f, dist=%.0f/%.0f, magicImmune=%s, decap=%s, casting=%s, tooClose=%s",
                    cleanName, val, dist, castRange,
                    tostring(NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)),
                    tostring(isDecap), tostring(currentCasting ~= nil), tostring(isTooClose)))
            end

            if dist <= castRange then
                if not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
                    not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
                    if val > 0 or isTooClose then
                        table.insert(enemiesInRange, enemy)

                        -- Target is actively casting/channeling and is not already disabled
                        if val > 0 and currentCasting and not isDecap then
                            table.insert(castingEnemies, enemy)
                        end

                        -- Target is in push back distance
                        if isTooClose then
                            table.insert(pushEnemies, enemy)
                        end

                        -- Target is designated as "Always" combo target and not already disabled
                        if val == 1 and not isDecap then
                            table.insert(alwaysEnemies, enemy)
                        end
                    end
                end
            end
        end
    end

    -- Priority 1: Auto-interrupt casting/channeling enemies
    if #castingEnemies > 0 then
        if not interruptOnlyInCombo:Get() or inCombo then
            if dbg then Log.Write(string.format("[DrowGust] Casting auto-interrupt! Casting targets count: %d",
                    #castingEnemies)) end
            local bestScore = -1
            local bestCastPos = nil
            local bestCasterName = ""
            for _, caster in ipairs(castingEnemies) do
                local score, castPos = OptimizeGust(D, caster, enemiesInRange, castRange, width)
                if score > bestScore then
                    bestScore = score
                    bestCastPos = castPos

                    local cName = NPC.GetUnitName(caster):gsub("npc_dota_hero_", "")
                    bestCasterName = cName:sub(1, 1):upper() .. cName:sub(2)
                end
            end
            if bestCastPos then
                Log.Write(string.format("[DrowGust] CAST GUST at position %s to interrupt %s (Score: %.1f)",
                    tostring(bestCastPos), bestCasterName, bestScore))
                Ability.CastPosition(gust, bestCastPos, false, false, true)
                lastGustCastTime = now
                return
            end
        end
    end

    -- Priority 2: Push back close enemies
    if #pushEnemies > 0 then
        if not pushOnlyInCombo:Get() or inCombo then
            if dbg then Log.Write(string.format("[DrowGust] Casting close-range push! Targets count: %d", #pushEnemies)) end
            local bestScore = -1
            local bestCastPos = nil
            local bestTargetName = ""
            for _, closeEnemy in ipairs(pushEnemies) do
                local score, castPos = OptimizeGust(D, closeEnemy, enemiesInRange, castRange, width)
                if score > bestScore then
                    bestScore = score
                    bestCastPos = castPos

                    local pName = NPC.GetUnitName(closeEnemy):gsub("npc_dota_hero_", "")
                    bestTargetName = pName:sub(1, 1):upper() .. pName:sub(2)
                end
            end
            if bestCastPos then
                Log.Write(string.format("[DrowGust] CAST GUST at position %s to PUSH BACK close enemy %s (Score: %.1f)",
                    tostring(bestCastPos), bestTargetName, bestScore))
                Ability.CastPosition(gust, bestCastPos, false, false, true)
                lastGustCastTime = now
                return
            end
        end
    end

    -- Priority 3: Use in Combo on "Always" targets
    if inCombo and #alwaysEnemies > 0 then
        if dbg then Log.Write(string.format("[DrowGust] Casting combo! Always targets count: %d", #alwaysEnemies)) end
        local bestScore = -1
        local bestCastPos = nil
        local bestTargetName = ""
        for _, target in ipairs(alwaysEnemies) do
            local score, castPos = OptimizeGust(D, target, enemiesInRange, castRange, width)
            if score > bestScore then
                bestScore = score
                bestCastPos = castPos

                local tName = NPC.GetUnitName(target):gsub("npc_dota_hero_", "")
                bestTargetName = tName:sub(1, 1):upper() .. tName:sub(2)
            end
        end
        if bestCastPos then
            Log.Write(string.format("[DrowGust] CAST GUST at position %s in Combo on %s (Score: %.1f)",
                tostring(bestCastPos), bestTargetName, bestScore))
            Ability.CastPosition(gust, bestCastPos, false, false, true)
            lastGustCastTime = now
            return
        end
    end
end

-- Render and Input handling loop (Design exact match to screenshot)
local isInitialized = false

DRGust.OnDraw = function()
    if DrowRangerGust_ActiveInstanceId ~= myInstanceId then return end
    if not scriptEnabled:Get() or not drawPanel:Get() then return end

    -- Sync colors dynamically in case theme was updated in settings
    SyncColors()

    local myHero = Heroes.GetLocal()
    if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_drow_ranger" then
        return
    end

    -- Setup native sliders coords persistence on startup
    if not isInitialized then
        LoadPanelPosition()
        isInitialized = true
    end

    -- Smooth dt calculation
    local dt = GlobalVars.GetAbsFrameTime() or 0.016
    if dt <= 0 or dt > 0.1 then
        dt = 0.016
    end

    -- Unique enemy heroes setup
    local enemies = {}
    local enemyEntities = {}
    for _, hero in ipairs(Heroes.GetAll()) do
        if hero ~= myHero and not Entity.IsSameTeam(myHero, hero) and not NPC.IsIllusion(hero) then
            local heroName = NPC.GetUnitName(hero)
            local cleanName = heroName:gsub("npc_dota_hero_", "")
            cleanName = cleanName:sub(1, 1):upper() .. cleanName:sub(2)
            table.insert(enemies, cleanName)
            enemyEntities[cleanName] = hero
        end
    end
    table.sort(enemies)

    local numEnemies = #enemies
    if numEnemies == 0 then
        return
    end

    -- Handle resolution-independent scaling
    local baseScale = (Menu.Scale() or 100) / 100
    local scale = baseScale

    -- Design parameters matching screenshot
    local cellW = 44 * scale
    local cellH = 30 * scale
    local cellSpacing = 6 * scale
    local headerH = 24 * scale
    local gap = 4 * scale
    local padding = 8 * scale

    local minW = 160 * scale
    local W = padding * 2 + numEnemies * cellW + (numEnemies - 1) * cellSpacing
    if W < minW then
        W = minW
    end
    local panelHeight = headerH + gap + cellH

    -- Handle HUD dragging input
    local mx, my = GetMousePos()
    local isDown = IsLmbDown()
    local isClicked = isDown and not wasMousePressed
    local isCursorValid = mx and my

    -- Position boundary validation
    local screenSize = Render.ScreenSize()
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then return end

    local x = math.max(0, math.min(screenSize.x - W, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - panelHeight, PanelConfig.Y))

    if dragMode:Get() then
        local isOverHeader = isCursorValid and mx >= x and mx <= x + W and my >= y and my <= y + headerH

        if isClicked and isOverHeader then
            PanelDrag.IsDragging = true
            PanelDrag.OffsetX = mx - x
            PanelDrag.OffsetY = my - y
        elseif not isDown then
            PanelDrag.IsDragging = false
        end

        if PanelDrag.IsDragging and mx and my then
            local newX = math.max(0, math.min(screenSize.x - W, mx - PanelDrag.OffsetX))
            local newY = math.max(0, math.min(screenSize.y - panelHeight, my - PanelDrag.OffsetY))
            PanelConfig.X = newX
            PanelConfig.Y = newY
            SavePanelPosition()
            x = newX
            y = newY
        end
    else
        PanelDrag.IsDragging = false
    end

    -- Header Status & Cooldown Logic
    local statusText = "RDY"
    local statusColor = Color(50, 220, 110, 255) -- Green for ready
    local cdValue = 0

    local gust = NPC.GetAbility(myHero, "drow_ranger_wave_of_silence")
    if gust and Ability.GetLevel(gust) > 0 then
        if not Ability.IsReady(gust) then
            local cd = Ability.GetCooldown(gust)
            if cd > 0 then
                cdValue = cd
                statusText = string.format("%.0f", cd)
                statusColor = Color(255, 100, 110, 255) -- Red for cooldown
            end
        end
    else
        statusText = "N/A"
        statusColor = Color(150, 150, 150, 255)
    end

    -- Header Icon & Text (Dynamic left/right states)
    local headerIcon = "💨"
    local titleText = L("Ready", "Готов")

    if dragMode:Get() then
        headerIcon = "🤚"
        titleText = L("DRAGGING", "ДВИЖЕНИЕ")
    elseif cdValue > 0 then
        headerIcon = "⏳"
        titleText = L("Cooldown", "Перезарядка")
    elseif statusText == "N/A" then
        headerIcon = "💤"
        titleText = L("Not Learned", "Не изучено")
    end

    local titleFull = headerIcon .. "  " .. titleText

    -- Draw blurred and shadowed panel backgrounds
    Render.Blur(Vec2(x, y), Vec2(x + W, y + panelHeight), 2.5, 1.0, 6 * scale, Enum.DrawFlags.None)
    Render.Shadow(Vec2(x, y), Vec2(x + W, y + panelHeight), Color(0, 0, 0, 110), 22, 6 * scale,
        Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(1, 2))

    -- Draw Panel Body background (to give cells area a dark iOS style background)
    Render.FilledRect(Vec2(x, y), Vec2(x + W, y + panelHeight), Colors.PanelBg, 6 * scale)
    Render.Rect(Vec2(x, y), Vec2(x + W, y + panelHeight), Colors.BorderPanel, 6 * scale, Enum.DrawFlags.None, 1)

    -- Draw Header Bar
    Render.FilledRect(Vec2(x, y), Vec2(x + W, y + headerH), Colors.HeaderBg, 6 * scale)
    Render.Rect(Vec2(x, y), Vec2(x + W, y + headerH), Color(255, 255, 255, 20), 6 * scale)

    -- Draw Header Text and Status
    DrawShadowText(fontNormal, 11 * scale, titleFull, Vec2(x + 10 * scale, y + (headerH - 13 * scale) / 2),
        Colors.TextHeader)

    local statusSz = Render.TextSize(fontNormal, 11 * scale, statusText)
    DrawShadowText(fontNormal, 11 * scale, statusText,
        Vec2(x + W - statusSz.x - 10 * scale, y + (headerH - 13 * scale) / 2), statusColor)

    -- Mouse click single check
    local clickTriggered = false
    if isDown and not wasMousePressed then
        clickTriggered = true
    end
    wasMousePressed = isDown

    -- 2. Draw Horizontal Row of Rounded Cells
    local cellStartY = y + headerH + gap
    local cellsTotalW = numEnemies * cellW + (numEnemies - 1) * cellSpacing
    local cellsStartX = x + (W - cellsTotalW) / 2

    for i, cleanName in ipairs(enemies) do
        local cellX = cellsStartX + (i - 1) * (cellW + cellSpacing)
        local enemyHero = enemyEntities[cleanName]

        -- Base cell background
        Render.FilledRect(Vec2(cellX, cellStartY), Vec2(cellX + cellW, cellStartY + cellH), Colors.CellBg, 5 * scale)

        -- Safely fetch/create the dynamic target menu reference
        local menuItem = GetOrCreateMenuItem(cleanName)
        local currentVal = menuItem and menuItem:Get() or 0

        -- Load and draw Hero Portrait inside cell
        local heroNameRaw = enemyHero and NPC.GetUnitName(enemyHero) or ""
        local imgHandle = GetHeroIcon(heroNameRaw)

        -- Gray out portrait if Disabled (index 0)
        local isGrayscale = (currentVal == 0)

        if imgHandle then
            Render.Image(imgHandle, Vec2(cellX, cellStartY), Vec2(cellW, cellH), Color(255, 255, 255, 255), 5 * scale,
                Enum.DrawFlags.None, Vec2(0, 0), Vec2(1, 1), isGrayscale)
        end

        -- Determine Border status colors
        local isCasting = enemyHero and IsNPCUsingAbility(enemyHero)
        local borderCol = Colors.BorderDisabled

        if isCasting then
            local pulse = math.floor(120 + 135 * math.sin(GlobalVars.GetCurTime() * 10.0))
            borderCol = Color(255, 75, 75, pulse) -- Pulsing red glow for casting targets
        elseif currentVal == 1 then
            borderCol = Colors.BorderAlways       -- Green for Always combo
        elseif currentVal == 2 then
            borderCol = Colors.BorderNeeded       -- Blue for Interrupt/When casting
        end

        -- Draw glowing border around cell
        if currentVal > 0 or isCasting then
            local glowAlpha = isCasting and 85 or 55
            local glowCol = Color(borderCol.r, borderCol.g, borderCol.b, glowAlpha)
            Render.Shadow(Vec2(cellX, cellStartY), Vec2(cellX + cellW, cellStartY + cellH), glowCol, 6 * scale, 5 * scale,
                Enum.DrawFlags.ShadowCutOutShapeBackground)
        end
        Render.Rect(Vec2(cellX, cellStartY), Vec2(cellX + cellW, cellStartY + cellH), borderCol, 5 * scale,
            Enum.DrawFlags.None, 1.5)

        -- Small colored status indicator dot in top-right corner of cell
        if currentVal > 0 then
            local dotX = cellX + cellW - 5 * scale
            local dotY = cellStartY + 5 * scale
            local dotR = 2.5 * scale
            local dotColor = (currentVal == 1) and Colors.BorderAlways or Colors.BorderNeeded
            Render.FilledCircle(Vec2(dotX, dotY), dotR, dotColor)
            Render.Circle(Vec2(dotX, dotY), dotR, Color(255, 255, 255, 200), 0.5)
        end

        -- Cycle target state on click: Disabled (0) -> When casting/Needed (2) -> Always (1) -> Disabled (0)
        local isCellHovered = isCursorValid and mx >= cellX and mx <= cellX + cellW and my >= cellStartY and
        my <= cellStartY + cellH
        if isCellHovered and clickTriggered then
            local nextVal = 0
            if currentVal == 0 then
                nextVal = 2
            elseif currentVal == 2 then
                nextVal = 1
            else
                nextVal = 0
            end

            if menuItem then
                menuItem:Set(nextVal)
            end
        end
    end
end

-- Intercept and block mouse clicks over HUD panel coordinates from passing to the game map
DRGust.OnKeyEvent = function(data, key, event)
    if DrowRangerGust_ActiveInstanceId ~= myInstanceId then return end
    if not Menu or not Menu.VisualsIsEnabled or not Menu.VisualsIsEnabled() then return end
    if not scriptEnabled:Get() or not drawPanel:Get() then return end

    local myHero = Heroes.GetLocal()
    if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_drow_ranger" then
        return
    end

    local enemies = {}
    for _, hero in ipairs(Heroes.GetAll()) do
        if hero ~= myHero and not Entity.IsSameTeam(myHero, hero) and not NPC.IsIllusion(hero) then
            local heroName = NPC.GetUnitName(hero)
            local cleanName = heroName:gsub("npc_dota_hero_", "")
            cleanName = cleanName:sub(1, 1):upper() .. cleanName:sub(2)
            table.insert(enemies, cleanName)
        end
    end

    local numEnemies = #enemies
    if numEnemies == 0 then
        return
    end

    local scale = (Menu.Scale() or 100) / 100
    local cellW = 44 * scale
    local cellH = 30 * scale
    local cellSpacing = 6 * scale
    local headerH = 24 * scale
    local gap = 4 * scale
    local padding = 8 * scale

    local minW = 160 * scale
    local W = padding * 2 + numEnemies * cellW + (numEnemies - 1) * cellSpacing
    if W < minW then
        W = minW
    end
    local panelHeight = headerH + gap + cellH

    local screenSize = Render.ScreenSize()
    if not screenSize or screenSize.x <= 1 or screenSize.y <= 1 then return end

    local x = math.max(0, math.min(screenSize.x - W, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - panelHeight, PanelConfig.Y))

    local mx, my = GetMousePos()
    local isCursorOverPanel = mx and my and mx >= x and mx <= x + W and my >= y and my <= y + panelHeight

    if isCursorOverPanel or PanelDrag.IsDragging then
        if key == Enum.ButtonCode.KEY_MOUSE1 or key == Enum.ButtonCode.KEY_MOUSE2 or
            key == Enum.ButtonCode.KEY_MOUSE3 or key == Enum.ButtonCode.KEY_MWHEELUP or
            key == Enum.ButtonCode.KEY_MWHEELDOWN then
            return false
        end
    end
end

DRGust.OnThemeUpdate = function()
    SyncColors()
end

return DRGust
