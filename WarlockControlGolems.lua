--[[
    Warlock Control Golems
    Smart micro for Chaotic Offering golems after summon.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "WarlockControlGolems"
local UPDATE_INTERVAL = 0.15
local CONFIG_INI_REL = "configs/" .. NAME .. ".ini"

local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_SECOND = "Warlock"
local MENU_THIRD = "Main Settings"
local MENU_GROUP = "Control Golems"

local HERO_NAME = "npc_dota_hero_warlock"
local GOLEM_PREFIX = "npc_dota_warlock_golem"
local GOLEM_PREFIX_LEN = #GOLEM_PREFIX
local MODIFIER_KILL = "modifier_kill"

local ORDER_PREFIX = "warlock_control_golems."
local ORDER_ATTACK = ORDER_PREFIX .. "attack"
local ORDER_PUSH = ORDER_PREFIX .. "push"

local ICON_ENABLE = "\u{f00c}"
local ICON_FORCE = "\u{e1c1}"
local ICON_SEARCH = "\u{f689}"
local ICON_OVERLAY = "\u{f0ce}"

local PANEL_CENTER_SENTINEL = -1

local PANEL_BLUR_BASE = 2.5
local PANEL_HEADER_H = 32
local PANEL_PAD_X = 10
local PANEL_RADIUS = 8
local PANEL_ROW_H = 20
local PANEL_WIDTH = 220

local STYLE_KEYS = {
    "active_widgets_text", "additional_background", "button_active_background",
    "button_background", "combo_frame", "combo_item", "combo_item_active",
    "disabled_switch_background", "disabled_switch_circle", "enabled_switch_background",
    "group_background", "group_outline", "healthbar_ally", "healthbar_enemy",
    "healthbar_roshan", "healthbar_self", "hero_tab_filter_background",
    "hero_tab_filter_separator", "indication_active", "indication_inactive",
    "input_text_bg", "keybind_background", "keybind_background_active",
    "left_tabs_background", "main_background", "manabar", "multiselect_item",
    "multiselect_item_selected", "outline", "popup_background", "popup_border",
    "primary", "primary_first_tab_text", "primary_second_tab_text",
    "primary_widgets_text", "scrollbar_bg", "search_outline", "search_text",
    "section_group_text", "selected_tabs_background", "separator", "shadow",
    "slider_background", "slider_background_active", "slider_grab",
    "slider_grab_active", "text_shadow", "third_tab_text", "widgets_shadow",
}
--#endregion

--#region State
---@class WarlockControlGolemsUI
---@field enabled CMenuSwitch|nil
---@field forceBind CMenuBind|nil
---@field searchRange CMenuSliderInt|CMenuSliderFloat|nil
---@field showOverlay CMenuSwitch|nil
local UI = {
    enabled = nil,
    forceBind = nil,
    searchRange = nil,
    showOverlay = nil,
}

local Style = {}
local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    TextSecondary = Color(180, 184, 190, 255),
    Accent = Color(180, 180, 190, 255),
    Quiet = Color(120, 120, 130, 255),
    BodyBg = Color(12, 12, 16, 220),
    BarBg = Color(40, 40, 50, 200),
    BarFill = Color(180, 180, 190, 255),
    Shadow = Color(0, 0, 0, 160),
    TextShadow = Color(0, 0, 0, 140),
}

local PanelConfig = {
    X = PANEL_CENTER_SENTINEL,
    Y = 200,
    Saved = false,
}

local PanelDrag = {
    IsDragging = false,
    OffsetX = 0,
    OffsetY = 0,
}

local PanelLayoutCache = {
    w = PANEL_WIDTH,
    h = PANEL_HEADER_H + PANEL_ROW_H + 4,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|nil
    font = nil,
    ---@type CMenuSliderFloat|CMenuSliderInt|nil
    blurFactor = nil,
    wasMousePressed = false,
}

---@class WarlockGolemOrderState
---@field kind string
---@field targetIndex integer|nil
---@field destX number|nil
---@field destY number|nil

---@class WarlockGolemHudRow
---@field remain number|nil
---@field action string

local Runtime = {
    lastUpdateAt = -math.huge,
    ---@type table<integer, WarlockGolemOrderState>
    lastOrders = {},
    ---@type userdata|nil
    enemyFort = nil,
    ---@type userdata|nil
    allyFort = nil,
    ---@type Vector|nil
    pushDest = nil,
    controlActive = false,
    ---@type WarlockGolemHudRow[]
    hudRows = {},
}
--#endregion

--#region Theme
local function NormalizeStyleColor(value, fallback)
    if value == nil then
        return fallback
    end
    if type(value) == "userdata" then
        return value
    end
    if type(value) ~= "table" then
        return fallback
    end

    local r = value.r or 0
    local g = value.g or 0
    local b = value.b or 0
    local a = value.a
    if a == nil then
        a = 255
    end
    if r <= 1 and g <= 1 and b <= 1 and a <= 1 then
        r = r * 255
        g = g * 255
        b = b * 255
        a = a * 255
    end
    return Color(r, g, b, a)
end

local function TryGetThemeColor(key, all)
    local value = Menu.Style(key)
    if value == nil and type(all) == "table" then
        value = all[key]
    end
    return NormalizeStyleColor(value, nil)
end

local function SyncColors()
    local all = Menu.Style()
    for i = 1, #STYLE_KEYS do
        local key = STYLE_KEYS[i]
        Style[key] = TryGetThemeColor(key, all)
    end
    if type(all) == "table" then
        for key, _ in pairs(all) do
            if Style[key] == nil then
                Style[key] = TryGetThemeColor(key, all)
            end
        end
    end

    Colors.HeaderBg = Style.additional_background
        or Style.popup_background
        or Style.main_background
        or Style.group_background
        or Colors.HeaderBg
    Colors.TextHeader = Style.primary_widgets_text
        or Style.active_widgets_text
        or Colors.TextHeader
    Colors.TextSecondary = Style.primary_second_tab_text
        or Style.third_tab_text
        or Style.section_group_text
        or Colors.TextSecondary
    Colors.Accent = Style.enabled_switch_background
        or Style.combo_item_active
        or Style.primary
        or Style.indication_active
        or Colors.Accent
    Colors.Quiet = Style.indication_inactive
        or Style.disabled_switch_background
        or Style.multiselect_item
        or Colors.Quiet
    Colors.BodyBg = Style.group_background
        or Style.button_background
        or Style.combo_frame
        or Colors.BodyBg
    Colors.BarBg = Style.slider_background
        or Style.combo_frame
        or Style.scrollbar_bg
        or Colors.BarBg
    Colors.BarFill = Style.primary
        or Style.slider_grab_active
        or Style.combo_item_active
        or Colors.BarFill
    Colors.Shadow = Style.shadow or Colors.Shadow
    if Style.text_shadow and (Style.text_shadow.a or 0) > 0 then
        Colors.TextShadow = Style.text_shadow
    end
end

local function ColorWithAlpha(base, alpha)
    return Color(base.r, base.g, base.b, alpha)
end

local function ResolveFont()
    local candidates = { "Segoe UI", "Tahoma", "Arial" }
    for i = 1, #candidates do
        local handle = Render.LoadFont(candidates[i], Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.SEMIBOLD)
        if handle and handle ~= 0 then
            local size = Render.TextSize(handle, 14, "Golems")
            if size and size.x > 0 and size.y > 0 then
                return handle
            end
        end
    end
    return nil
end

--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastOrders = {}
    Runtime.enemyFort = nil
    Runtime.allyFort = nil
    Runtime.pushDest = nil
    Runtime.controlActive = false
    Runtime.hudRows = {}
end

local function OnEnabledChanged(widget)
    if widget:Get() ~= true then
        ResetRuntime()
    end
end

local function IsForceBindBound()
    local bind = UI.forceBind
    if not bind then
        return false
    end
    local key = bind:Get()
    return key ~= Enum.ButtonCode.KEY_NONE and key ~= Enum.ButtonCode.BUTTON_CODE_INVALID
end

local function IsForceBindActive()
    if not IsForceBindBound() then
        return true
    end
    return UI.forceBind:IsToggled() == true
end

local function IsWarlockGolem(npc)
    local name = NPC.GetUnitName(npc)
    if type(name) ~= "string" or name == "" then
        return false
    end
    return string.sub(name, 1, GOLEM_PREFIX_LEN) == GOLEM_PREFIX
end

local function CollectGolems(playerId)
    local golems = {}
    local all = NPCs.GetAll()
    for i = 1, #all do
        local npc = all[i]
        if IsWarlockGolem(npc)
            and Entity.IsAlive(npc) == true
            and Entity.IsDormant(npc) ~= true
            and Entity.IsControllableByPlayer(npc, playerId) == true
        then
            golems[#golems + 1] = npc
        end
    end
    return golems
end

local function GetGolemRemain(golem)
    local mod = NPC.GetModifier(golem, MODIFIER_KILL)
    if not mod then
        return nil
    end
    local dieTime = Modifier.GetDieTime(mod)
    if type(dieTime) ~= "number" then
        return nil
    end
    return math.max(0, dieTime - GameRules.GetGameTime())
end

local function ActionLabel(kind, controlActive)
    if controlActive ~= true then
        return "Paused"
    end
    if kind == "hero" then
        return "Hero"
    end
    if kind == "push" then
        return "Push"
    end
    return "Idle"
end

local function RefreshHud(golems, controlActive)
    local rows = {}
    for i = 1, #golems do
        local golem = golems[i]
        local order = Runtime.lastOrders[Entity.GetIndex(golem)]
        local kind = order and order.kind or nil
        rows[#rows + 1] = {
            remain = GetGolemRemain(golem),
            action = ActionLabel(kind, controlActive),
        }
    end
    Runtime.hudRows = rows
    Runtime.controlActive = controlActive
end

local function IsValidEnemyHero(golem, hero, searchRange)
    if not hero or Entity.IsEntity(hero) ~= true then
        return false
    end
    if Entity.IsAlive(hero) ~= true or NPC.IsIllusion(hero) == true then
        return false
    end
    if Entity.IsSameTeam(golem, hero) == true then
        return false
    end
    return NPC.IsEntityInRange(golem, hero, searchRange) == true
end

local function PickLowestHpHero(golem, searchRange)
    local heroes = Entity.GetHeroesInRadius(golem, searchRange, Enum.TeamType.TEAM_ENEMY, true, true)
    local best = nil
    local bestHp = math.huge
    local bestDistSqr = math.huge
    local golemPos = Entity.GetAbsOrigin(golem)

    for i = 1, #heroes do
        local hero = heroes[i]
        if IsValidEnemyHero(golem, hero, searchRange) then
            local hp = Entity.GetHealth(hero)
            local distSqr = golemPos:DistanceSqr2D(Entity.GetAbsOrigin(hero))
            if hp < bestHp or (hp == bestHp and distSqr < bestDistSqr) then
                best = hero
                bestHp = hp
                bestDistSqr = distSqr
            end
        end
    end

    return best
end

local function DetectLane(pos)
    if math.abs(pos.x - pos.y) < 2200 then
        return "mid"
    end
    if pos.y > pos.x then
        return "top"
    end
    return "bot"
end

local function FindFort(me, wantEnemy)
    local forts = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_FORT)
    for i = 1, #forts do
        local fort = forts[i]
        if NPC.IsFort(fort) == true and Entity.IsAlive(fort) == true then
            local sameTeam = Entity.IsSameTeam(me, fort) == true
            if wantEnemy and sameTeam ~= true then
                return fort
            end
            if wantEnemy ~= true and sameTeam == true then
                return fort
            end
        end
    end
    return nil
end

local function GetEnemyFort(me)
    local cached = Runtime.enemyFort
    if cached and Entity.IsEntity(cached) == true and Entity.IsAlive(cached) == true then
        return cached
    end
    Runtime.enemyFort = FindFort(me, true)
    return Runtime.enemyFort
end

local function GetAllyFort(me)
    local cached = Runtime.allyFort
    if cached and Entity.IsEntity(cached) == true and Entity.IsAlive(cached) == true then
        return cached
    end
    Runtime.allyFort = FindFort(me, false)
    return Runtime.allyFort
end

local function CollectLaneEndCandidates(me, lane)
    local positions = {}

    local towers = Towers.GetAll()
    for i = 1, #towers do
        local tower = towers[i]
        if Entity.IsAlive(tower) == true
            and Entity.IsSameTeam(me, tower) ~= true
            and DetectLane(Entity.GetAbsOrigin(tower)) == lane
        then
            positions[#positions + 1] = Entity.GetAbsOrigin(tower)
        end
    end

    local barracks = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_BARRACKS)
    for i = 1, #barracks do
        local building = barracks[i]
        if Entity.IsAlive(building) == true
            and NPC.IsBarracks(building) == true
            and Entity.IsSameTeam(me, building) ~= true
            and DetectLane(Entity.GetAbsOrigin(building)) == lane
        then
            positions[#positions + 1] = Entity.GetAbsOrigin(building)
        end
    end

    local fort = GetEnemyFort(me)
    if fort then
        positions[#positions + 1] = Entity.GetAbsOrigin(fort)
    end

    return positions
end

local function ResolveLanePushDestination(me, lane)
    local allyFort = GetAllyFort(me)
    local origin = allyFort and Entity.GetAbsOrigin(allyFort) or Entity.GetAbsOrigin(me)
    local candidates = CollectLaneEndCandidates(me, lane)

    local bestPos = nil
    local bestDist = -1
    for i = 1, #candidates do
        local pos = candidates[i]
        local dist = origin:DistanceSqr2D(pos)
        if dist > bestDist then
            bestDist = dist
            bestPos = pos
        end
    end

    if bestPos then
        return bestPos
    end

    local fort = GetEnemyFort(me)
    if fort then
        return Entity.GetAbsOrigin(fort)
    end
    return nil
end

local function EnsurePushDest(me)
    if Runtime.pushDest then
        return Runtime.pushDest
    end

    local dest = ResolveLanePushDestination(me, DetectLane(Entity.GetAbsOrigin(me)))
    if not dest then
        return nil
    end

    Runtime.pushDest = Vector(dest.x, dest.y, dest.z)
    return Runtime.pushDest
end

local function SameAttackOrder(state, target, kind)
    return state
        and state.kind == kind
        and state.targetIndex == Entity.GetIndex(target)
end

local function SamePushOrder(state, dest)
    if not state or state.kind ~= "push" or not dest then
        return false
    end
    if type(state.destX) ~= "number" or type(state.destY) ~= "number" then
        return false
    end
    local dx = state.destX - dest.x
    local dy = state.destY - dest.y
    return (dx * dx + dy * dy) < (64 * 64)
end

local function IssueAttack(player, golem, target, kind)
    local golemIndex = Entity.GetIndex(golem)
    local prev = Runtime.lastOrders[golemIndex]
    if SameAttackOrder(prev, target, kind) then
        return
    end

    Player.AttackTarget(player, golem, target, false, true, false, ORDER_ATTACK, false)
    Runtime.lastOrders[golemIndex] = {
        kind = kind,
        targetIndex = Entity.GetIndex(target),
    }
end

local function IssuePush(player, golem, dest)
    local golemIndex = Entity.GetIndex(golem)
    local prev = Runtime.lastOrders[golemIndex]
    if SamePushOrder(prev, dest) then
        return
    end

    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
        nil,
        dest,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        golem,
        false,
        false,
        true,
        false,
        ORDER_PUSH,
        true
    )

    Runtime.lastOrders[golemIndex] = {
        kind = "push",
        destX = dest.x,
        destY = dest.y,
    }
end

local function ControlGolem(player, me, golem, searchRange)
    local golemIndex = Entity.GetIndex(golem)
    local prev = Runtime.lastOrders[golemIndex]
    if prev and prev.kind == "hero" and prev.targetIndex then
        local prevHero = Entity.Get(prev.targetIndex)
        if IsValidEnemyHero(golem, prevHero, searchRange) then
            IssueAttack(player, golem, prevHero, "hero")
            return
        end
    end

    local hero = PickLowestHpHero(golem, searchRange)
    if hero then
        IssueAttack(player, golem, hero, "hero")
        return
    end

    local dest = EnsurePushDest(me)
    if dest then
        IssuePush(player, golem, dest)
    end
end

local function InvalidateGolemOrder(unit)
    if not unit or IsWarlockGolem(unit) ~= true then
        return
    end
    Runtime.lastOrders[Entity.GetIndex(unit)] = nil
end

local function InvalidateGolemOrdersFromIssuer(npc)
    if type(npc) == "table" then
        for i = 1, #npc do
            InvalidateGolemOrder(npc[i])
        end
        return
    end
    InvalidateGolemOrder(npc)
end

local function IsOwnOrderIdentifier(identifier)
    return type(identifier) == "string"
        and string.sub(identifier, 1, #ORDER_PREFIX) == ORDER_PREFIX
end

local function UpdateFeature(me, player, controlActive)
    local playerId = Player.GetPlayerID(player)
    if playerId < 0 then
        return
    end

    local searchRange = UI.searchRange:Get()
    local golems = CollectGolems(playerId)
    if #golems == 0 then
        Runtime.pushDest = nil
        Runtime.lastOrders = {}
    end

    if controlActive ~= true then
        -- Drop dedupe cache so the next resume re-issues attack/push.
        Runtime.lastOrders = {}
        RefreshHud(golems, false)
        return
    end

    for i = 1, #golems do
        ControlGolem(player, me, golems[i], searchRange)
    end

    RefreshHud(golems, true)
end
--#endregion

--#region Rendering
local function DrawTextShadowed(font, size, text, pos, color)
    local shadow = Colors.TextShadow
    if shadow and (shadow.a or 0) > 0 then
        Render.Text(font, size, text, Vec2(pos.x + 1, pos.y + 1), shadow)
    end
    Render.Text(font, size, text, pos, color)
end

local function DrawShimmerLine(centerX, y, width)
    local accent = Colors.Accent
    local quiet = Colors.Quiet
    local half = width * 0.5
    local x0 = centerX - half
    local x1 = centerX + half
    local t = GameRules.GetGameTime() * 1.8
    local pulse = 0.55 + 0.45 * math.sin(t)
    local shift = (math.sin(t * 0.7) * 0.5 + 0.5) * width * 0.35

    local mid = x0 + width * 0.5 + shift - width * 0.175
    local left = ColorWithAlpha(quiet, math.floor(40 + 50 * pulse))
    local bright = ColorWithAlpha(accent, math.floor(160 + 80 * pulse))
    local right = ColorWithAlpha(quiet, math.floor(40 + 50 * pulse))

    Render.Gradient(
        Vec2(x0, y),
        Vec2(mid, y + 2),
        left,
        bright,
        left,
        bright,
        1
    )
    Render.Gradient(
        Vec2(mid, y),
        Vec2(x1, y + 2),
        bright,
        right,
        bright,
        right,
        1
    )
end

local function DrawForceIndicator(me)
    if Runtime.controlActive ~= true then
        return
    end

    local origin = Entity.GetAbsOrigin(me)
    local offset = NPC.GetHealthBarOffset(me)
    local barWorld = Vector(origin.x, origin.y, origin.z + offset)
    local screen, onScreen = Render.WorldToScreen(barWorld)
    if onScreen ~= true then
        return
    end

    local scale = Menu.Scale() / 100
    local width = 72 * scale
    local y = screen.y - 14 * scale
    DrawShimmerLine(screen.x, y, width)
end

local function GetBlurStrength()
    local widget = Persistent.blurFactor
    if not widget then
        return 0
    end
    local factor = widget:Get()
    if type(factor) ~= "number" or factor <= 0 then
        return 0
    end
    if factor > 1 then
        factor = factor / 100
    end
    return factor * PANEL_BLUR_BASE
end

local function ClampPanelPos(x, y, width, height, screen)
    local maxX = math.max(0, screen.x - width)
    local maxY = math.max(0, screen.y - height)
    return math.max(0, math.min(x, maxX)), math.max(0, math.min(y, maxY))
end

local function IsScreenSizeUsable(screen, width, height)
    return screen ~= nil
        and type(screen.x) == "number"
        and type(screen.y) == "number"
        and screen.x > width
        and screen.y > height
end

local function ForEachPanelIniPath(callback)
    local root = Engine.GetCheatDirectory()
    if type(root) == "string" and root ~= "" then
        local slash = string.find(root, "/", 1, true) and "/" or "\\"
        callback(root .. slash .. "configs" .. slash .. NAME .. ".ini")
    end
    if CONFIG_INI_REL ~= "" then
        callback(CONFIG_INI_REL)
    end
end

local function WritePanelIni(x, y)
    local body = string.format(
        "[config]\npanel_saved=1\npanel_x=%d\npanel_y=%d\n",
        x,
        y
    )
    ForEachPanelIniPath(function(path)
        local file = io.open(path, "w")
        if file then
            file:write(body)
            file:close()
        end
    end)
end

local function ReadPanelIni()
    local foundX, foundY = nil, nil
    ForEachPanelIniPath(function(path)
        if foundX ~= nil then
            return
        end
        local file = io.open(path, "r")
        if not file then
            return
        end
        local content = file:read("*a")
        file:close()
        if type(content) ~= "string" then
            return
        end
        local saved = tonumber(string.match(content, "panel_saved%s*=%s*(%-?%d+)"))
        local x = tonumber(string.match(content, "panel_x%s*=%s*(%-?%d+)"))
        local y = tonumber(string.match(content, "panel_y%s*=%s*(%-?%d+)"))
        if saved == 1 and x ~= nil and y ~= nil then
            foundX = math.floor(x)
            foundY = math.floor(y)
        end
    end)
    return foundX, foundY
end

local function LoadPanelPos()
    local iniX, iniY = ReadPanelIni()
    if iniX ~= nil and iniY ~= nil then
        PanelConfig.X = iniX
        PanelConfig.Y = iniY
        PanelConfig.Saved = true
        return
    end

    local saved = Config.ReadInt(NAME, "panel_saved", 0)
    local x = Config.ReadInt(NAME, "panel_x", PANEL_CENTER_SENTINEL)
    local y = Config.ReadInt(NAME, "panel_y", 200)
    if saved == 1 and x >= 0 then
        PanelConfig.X = math.floor(x)
        PanelConfig.Y = math.floor(y)
        PanelConfig.Saved = true
        return
    end

    PanelConfig.X = PANEL_CENTER_SENTINEL
    PanelConfig.Y = 200
    PanelConfig.Saved = false
end

local function SavePanelPos()
    if PanelConfig.X == PANEL_CENTER_SENTINEL and PanelConfig.Saved ~= true then
        return
    end

    local x = math.floor(PanelConfig.X + 0.5)
    local y = math.floor(PanelConfig.Y + 0.5)
    if x == PANEL_CENTER_SENTINEL then
        return
    end

    if Engine.IsInGame() then
        local screen = Render.ScreenSize()
        if IsScreenSizeUsable(screen, PanelLayoutCache.w, PanelLayoutCache.h) then
            x, y = ClampPanelPos(x, y, PanelLayoutCache.w, PanelLayoutCache.h, screen)
        end
    end

    PanelConfig.X = x
    PanelConfig.Y = y
    PanelConfig.Saved = true

    Config.WriteInt(NAME, "panel_x", x)
    Config.WriteInt(NAME, "panel_y", y)
    Config.WriteInt(NAME, "panel_saved", 1)
    WritePanelIni(x, y)
end

local function IsMouse1Down()
    local state = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true)
    return state == true or state == 1
end

local function IsOverHeader(layout, mx, my)
    if type(mx) ~= "number" or type(my) ~= "number" then
        return false
    end
    return mx >= layout.x
        and mx <= layout.x + layout.w
        and my >= layout.y
        and my <= layout.y + layout.titleH
end

local function UpdatePanelDrag(layout)
    PanelLayoutCache.w = layout.w
    PanelLayoutCache.h = layout.h

    local mx, my = Input.GetCursorPos()
    local isDown = IsMouse1Down()
    local isClicked = isDown and Persistent.wasMousePressed ~= true
    local captured = Input.IsInputCaptured() == true

    if captured then
        if PanelDrag.IsDragging then
            SavePanelPos()
            PanelDrag.IsDragging = false
        end
        Persistent.wasMousePressed = isDown
        return
    end

    if isClicked and IsOverHeader(layout, mx, my) then
        PanelDrag.IsDragging = true
        PanelDrag.OffsetX = mx - layout.x
        PanelDrag.OffsetY = my - layout.y
    elseif not isDown then
        if PanelDrag.IsDragging then
            SavePanelPos()
        end
        PanelDrag.IsDragging = false
    elseif PanelDrag.IsDragging then
        PanelConfig.X = math.floor(mx - PanelDrag.OffsetX)
        PanelConfig.Y = math.floor(my - PanelDrag.OffsetY)
        PanelConfig.Saved = true
    end

    Persistent.wasMousePressed = isDown
end

local function DrawSimpleGolemIcon(x, y, size)
    local accent = Colors.Accent
    local inner = ColorWithAlpha(Colors.BodyBg, 255)
    Render.FilledRect(Vec2(x, y), Vec2(x + size, y + size), accent, size * 0.22)
    local cx = x + size * 0.5
    local cy = y + size * 0.55
    Render.FilledCircle(Vec2(cx, cy), size * 0.22, inner)
    Render.FilledRect(
        Vec2(x + size * 0.22, y + size * 0.12),
        Vec2(x + size * 0.38, y + size * 0.34),
        accent,
        1
    )
    Render.FilledRect(
        Vec2(x + size * 0.62, y + size * 0.12),
        Vec2(x + size * 0.78, y + size * 0.34),
        accent,
        1
    )
end

local function DrawOverlayPanel()
    if not UI.showOverlay or UI.showOverlay:Get() ~= true then
        return
    end

    local rows = Runtime.hudRows
    local font = Persistent.font
    if not font then
        return
    end

    local scale = Menu.Scale() / 100
    local titleH = PANEL_HEADER_H * scale
    local padX = PANEL_PAD_X * scale
    local rowH = (PANEL_ROW_H + 4) * scale
    local radius = PANEL_RADIUS * scale
    local width = PANEL_WIDTH * scale
    local bodyH = math.max(rowH, (#rows) * rowH + padX)
    local height = titleH + bodyH
    local screen = Render.ScreenSize()
    local screenOk = IsScreenSizeUsable(screen, width, height)
    if not screenOk and PanelConfig.X == PANEL_CENTER_SENTINEL then
        return
    end

    if screenOk
        and PanelConfig.X == PANEL_CENTER_SENTINEL
        and PanelConfig.Saved ~= true
    then
        PanelConfig.X = math.floor((screen.x - width) * 0.5)
    end

    local x, y = PanelConfig.X, PanelConfig.Y
    if screenOk then
        x, y = ClampPanelPos(x, y, width, height, screen)
    end

    UpdatePanelDrag({
        x = x,
        y = y,
        w = width,
        h = height,
        titleH = titleH,
    })

    x, y = PanelConfig.X, PanelConfig.Y
    if screenOk then
        x, y = ClampPanelPos(x, y, width, height, screen)
        if PanelDrag.IsDragging ~= true then
            PanelConfig.X = x
            PanelConfig.Y = y
        end
    end

    local headerStart = Vec2(x, y)
    local headerEnd = Vec2(x + width, y + titleH)
    local bodyStart = Vec2(x, y + titleH)
    local bodyEnd = Vec2(x + width, y + height)

    if Colors.Shadow and (Colors.Shadow.a or 0) > 0 then
        Render.Shadow(headerStart, headerEnd, Colors.Shadow, 18 * scale, radius)
    end

    local blur = GetBlurStrength()
    local headerA = Colors.HeaderBg.a or 255
    if blur > 0 and headerA < 255 then
        Render.Blur(headerStart, headerEnd, blur, 1, radius, Enum.DrawFlags.RoundCornersTop)
    end

    Render.FilledRect(headerStart, headerEnd, Colors.HeaderBg, radius, Enum.DrawFlags.RoundCornersTop)
    Render.FilledRect(
        bodyStart,
        bodyEnd,
        ColorWithAlpha(Colors.BodyBg, 150),
        radius,
        Enum.DrawFlags.RoundCornersBottom
    )

    local titleSize = 14 * scale
    local textX = x + padX
    local titleY = y + (titleH - titleSize) * 0.45
    DrawTextShadowed(font, titleSize, "Golems", Vec2(textX, titleY), Colors.TextHeader)

    local countText = tostring(#rows)
    local countSize = Render.TextSize(font, titleSize, countText)
    DrawTextShadowed(
        font,
        titleSize,
        countText,
        Vec2(x + width - padX - countSize.x, y + (titleH - titleSize) * 0.45),
        Colors.Accent
    )

    if Runtime.controlActive == true then
        DrawShimmerLine(x + width * 0.5, y + titleH - 3 * scale, width - padX * 2)
    end

    local rowY = y + titleH + 4 * scale
    local bodySize = 13 * scale
    if #rows == 0 then
        DrawTextShadowed(font, bodySize, "No golems", Vec2(x + padX, rowY), Colors.TextSecondary)
        return
    end

    local rowIconSize = 16 * scale

    for i = 1, #rows do
        local row = rows[i]
        local remain = row.remain
        local timer = remain and string.format("%.0fs", remain) or "--"
        local action = row.action or "Idle"
        local textXRow = x + padX

        DrawSimpleGolemIcon(textXRow, rowY + 1 * scale, rowIconSize)
        textXRow = textXRow + rowIconSize + 6 * scale

        local line = string.format("%s  %s", timer, action)
        DrawTextShadowed(font, bodySize, line, Vec2(textXRow, rowY + 1 * scale), Colors.TextSecondary)

        if remain and remain > 0 then
            local barW = width - padX * 2
            local barH = 3 * scale
            local barY = rowY + rowIconSize + 3 * scale
            local frac = math.min(1, remain / 60)
            Render.FilledRect(Vec2(x + padX, barY), Vec2(x + padX + barW, barY + barH), Colors.BarBg, 2)
            Render.FilledRect(
                Vec2(x + padX, barY),
                Vec2(x + padX + barW * frac, barY + barH),
                Colors.BarFill,
                2
            )
        end

        rowY = rowY + rowH
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    SyncColors()
    Persistent.font = ResolveFont()
    Persistent.blurFactor = Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")
    LoadPanelPos()

    local group = Menu.Create(MENU_FIRST, MENU_SECTION, MENU_SECOND, MENU_THIRD, MENU_GROUP)

    UI.enabled = group:Switch("Enable", true)
    UI.enabled:Icon(ICON_ENABLE)

    UI.forceBind = group:Bind("Force Bind", Enum.ButtonCode.BUTTON_CODE_INVALID)
    UI.forceBind:Icon(ICON_FORCE)
    UI.forceBind:Properties("Force Bind", "Toggle", true)
    UI.forceBind:SetToggled(true)

    UI.searchRange = group:Slider("Enemy Range", 600, 2000, 1200, "%d")
    UI.searchRange:Icon(ICON_SEARCH)

    UI.showOverlay = group:Switch("Show Overlay", true)
    UI.showOverlay:Icon(ICON_OVERLAY)

    UI.enabled:SetCallback(OnEnabledChanged, false)

    Persistent.logger:info("loaded")
end

function Script.OnThemeUpdate()
    SyncColors()
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    if IsOwnOrderIdentifier(data and data.identifier) then
        return true
    end

    local localPlayer = Players.GetLocal()
    if not localPlayer or player ~= localPlayer then
        return true
    end

    InvalidateGolemOrdersFromIssuer(npc)

    local selected = Player.GetSelectedUnits(localPlayer)
    if type(selected) == "table" then
        for i = 1, #selected do
            InvalidateGolemOrder(selected[i])
        end
    end

    return true
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        Runtime.hudRows = {}
        Runtime.controlActive = false
        return
    end
    if Input.IsInputCaptured() then
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        Runtime.hudRows = {}
        Runtime.controlActive = false
        return
    end

    local player = Players.GetLocal()
    if not player then
        return
    end

    UpdateFeature(me, player, IsForceBindActive())
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Menu.VisualsIsEnabled() ~= true then
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    DrawForceIndicator(me)
    DrawOverlayPanel()
end

function Script.OnGameEnd()
    if PanelConfig.Saved == true then
        SavePanelPos()
    end
    ResetRuntime()
    PanelDrag.IsDragging = false
    Persistent.wasMousePressed = false
end
--#endregion

return Script
