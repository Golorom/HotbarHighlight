-- Hotbar Highlight's tests: the addon's files run against a small stand-in
-- for the game's functions. Run from the repository root with Lua 5.1:
--   lua5.1 tests/run.lua
-- A pass here shows the logic holds together. It does not show that the
-- game's own frames behave as the stand-in does.

local FILES = {"Core.lua", "Bars.lua", "Labels.lua", "Options.lua"}
local RANGE_DOT = "*"

local tests = {}
local function test(name, body)
    tests[#tests + 1] = {name = name, body = body}
end
local function equal(actual, expected, context)
    if actual ~= expected then
        error((context or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function near(actual, expected, context)
    if type(actual) ~= "number" or math.abs(actual - expected) > 0.005 then
        error((context or "value") .. ": expected about " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function contains(actual, fragment, context)
    if type(actual) ~= "string" or not actual:find(fragment, 1, true) then
        error((context or "text") .. ": expected text containing " .. fragment .. ", got " .. tostring(actual), 2)
    end
end

-- The user's layout this addon was written for: five bars on a 12-button
-- mouse grid, one per modifier layer, and a bar with no keys.
local NAGA_KEYS = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="}
local function nagaBindings()
    local bindings = {}
    local function bar(command, prefix, count)
        for index = 1, count do
            bindings[command:format(index)] = {prefix .. NAGA_KEYS[index]}
        end
    end
    bar("ACTIONBUTTON%d", "", 12)
    bar("MULTIACTIONBAR1BUTTON%d", "SHIFT-", 12)
    bar("MULTIACTIONBAR2BUTTON%d", "CTRL-", 12)
    bar("MULTIACTIONBAR3BUTTON%d", "ALT-SHIFT-", 12)
    bar("BONUSACTIONBUTTON%d", "ALT-CTRL-", 10)
    return bindings
end

local BAR_FRAMES = {
    {frame = "MainActionBar", button = "ActionButton%d", command = "ACTIONBUTTON%d", count = 12},
    {frame = "MultiBarBottomLeft", button = "MultiBarBottomLeftButton%d", command = "MULTIACTIONBAR1BUTTON%d", count = 12},
    {frame = "MultiBarBottomRight", button = "MultiBarBottomRightButton%d", command = "MULTIACTIONBAR2BUTTON%d", count = 12},
    {frame = "MultiBarRight", button = "MultiBarRightButton%d", command = "MULTIACTIONBAR3BUTTON%d", count = 12},
    {frame = "MultiBarLeft", button = "MultiBarLeftButton%d", command = "MULTIACTIONBAR4BUTTON%d", count = 12},
    {frame = "MultiBar5", button = "MultiBar5Button%d", command = "MULTIACTIONBAR5BUTTON%d", count = 12},
    {frame = "MultiBar6", button = "MultiBar6Button%d", command = "MULTIACTIONBAR6BUTTON%d", count = 12},
    {frame = "MultiBar7", button = "MultiBar7Button%d", command = "MULTIACTIONBAR7BUTTON%d", count = 12},
    {frame = "PetActionBar", button = "PetActionButton%d", command = "BONUSACTIONBUTTON%d", count = 10},
    {frame = "StanceBar", button = "StanceButton%d", command = "SHAPESHIFTBUTTON%d", count = 10},
}

-- options: bindings, db (saved settings), mainName (the main bar's frame
-- name), without (frame names this client lacks), noSettings, noSwatch,
-- breakLabels, secretKeys, beforeLoad(env) (runs before the addon's files).
local function fixture(options)
    options = options or {}
    local state = {frames = {}, messages = {}, mods = {}, combat = false, focus = nil, timers = {},
        settings = {}, initializers = {}, headings = {}, opened = nil, errors = {}, secrets = {},
        bindings = options.bindings or nagaBindings()}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    state.env = env

    local function newFrame(kind, name, parent)
        local frame = {kind = kind or "Frame", name = name, parent = parent, events = {}, scripts = {}, hooks = {},
            alpha = 1, shown = true, points = {}, textures = {}}
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(script, handler) self.scripts[script] = handler end
        function frame:GetScript(script) return self.scripts[script] end
        function frame:HookScript(script, handler)
            self.hooks[script] = self.hooks[script] or {}
            table.insert(self.hooks[script], handler)
        end
        function frame:SetAlpha(alpha) self.alpha = alpha end
        function frame:GetAlpha() return self.alpha end
        function frame:Show()
            local was = self.shown
            self.shown = true
            if not was then for _, hook in ipairs(self.hooks.OnShow or {}) do hook(self) end end
        end
        function frame:Hide()
            local was = self.shown
            self.shown = false
            if was then for _, hook in ipairs(self.hooks.OnHide or {}) do hook(self) end end
        end
        function frame:IsShown() return self.shown end
        function frame:IsVisible() return self.shown end
        function frame:SetPoint(...)
            if self.game then error("the addon anchored a game frame: " .. tostring(self.name)) end
            self.points[#self.points + 1] = {...}
        end
        function frame:ClearAllPoints()
            if self.game then error("the addon cleared a game frame's anchors: " .. tostring(self.name)) end
            self.points = {}
        end
        for _, method in ipairs({"SetSize", "SetWidth", "SetHeight", "SetScale", "SetParent"}) do
            frame[method] = function(self)
                if self.game then error("the addon called " .. method .. " on a game frame: " .. tostring(self.name)) end
            end
        end
        -- A frame's place on screen, in its own scale's units.
        function frame:GetLeft() return self.rect and self.rect[1] end
        function frame:GetRight() return self.rect and self.rect[2] end
        function frame:GetTop() return self.rect and self.rect[3] end
        function frame:GetBottom() return self.rect and self.rect[4] end
        function frame:SetFrameStrata(strata) self.strata = strata end
        function frame:GetFrameStrata() return self.strata or "MEDIUM" end
        function frame:GetWidth() return self.width or 45 end
        function frame:GetEffectiveScale() return self.scale or 1 end
        function frame:CreateTexture()
            local texture = {points = {}}
            function texture:SetPoint(...) self.points[#self.points + 1] = {...} end
            function texture:SetColorTexture(r, g, b, a) self.color = {r, g, b, a} end
            function texture:SetTexture(path) self.path = path end
            function texture:SetVertexColor(r, g, b, a) self.tint = {r, g, b, a} end
            function texture:SetHeight(height) self.height = height end
            function texture:SetWidth(width) self.width = width end
            function texture:SetSize(width, height) self.width, self.height = width, height end
            texture.shown = true
            function texture:Show() self.shown = true end
            function texture:Hide() self.shown = false end
            self.textures[#self.textures + 1] = texture
            return texture
        end
        state.frames[#state.frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    env.CreateFrame = newFrame
    env.UIParent = newFrame("Frame", "UIParent")
    env.EditModeManagerFrame = newFrame("Frame", "EditModeManagerFrame")
    env.EditModeManagerFrame.shown = false

    env.hooksecurefunc = function(object, method, hook)
        local original = object[method]
        object[method] = function(...)
            original(...)
            hook(...)
        end
    end
    if options.breakLabels then env.hooksecurefunc = nil end

    env.GetBindingKey = function(command)
        return unpack(state.bindings[command] or {})
    end
    env.GetBindingText = function(key)
        return (key:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-"):gsub("ALT%-", "a-"))
    end
    local function modifier(name)
        return function()
            if options.secretKeys then
                local hidden = {}
                state.secrets[hidden] = true
                return hidden
            end
            return state.mods[name] == true
        end
    end
    env.IsAltKeyDown, env.IsControlKeyDown, env.IsShiftKeyDown = modifier("ALT"), modifier("CTRL"), modifier("SHIFT")
    env.issecretvalue = function(value) return state.secrets[value] == true end
    env.GetCurrentKeyBoardFocus = function() return state.focus end
    env.InCombatLockdown = function() return state.combat end
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message)
        state.messages[#state.messages + 1] = (message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end}
    env.geterrorhandler = function()
        return function(message) state.errors[#state.errors + 1] = message end
    end
    env.C_Timer = {After = function(_, callback) state.timers[#state.timers + 1] = callback end}
    function state.runTimers()
        local due = state.timers
        state.timers = {}
        for _, callback in ipairs(due) do callback() end
    end
    env.SlashCmdList = {}

    if not options.noSettings then
        local nextID = 0
        env.Settings = {
            VarType = {Boolean = "boolean", Number = "number", String = "string"},
            RegisterVerticalLayoutCategory = function(title)
                nextID = nextID + 1
                local id = nextID
                state.category = {title = title, GetID = function() return id end}
                return state.category, {AddInitializer = function(_, heading)
                    state.headings[#state.headings + 1] = heading
                end}
            end,
            RegisterProxySetting = function(_, variable, variableType, name, default, getValue, setValue)
                local setting = {variable = variable, type = variableType, name = name, default = default,
                    get = getValue, set = setValue}
                state.settings[variable] = setting
                return setting
            end,
            RegisterAddOnCategory = function(category) state.registered = category end,
            CreateCheckbox = function(_, setting, tooltip)
                state.initializers[setting.variable] = {setting = setting, tooltip = tooltip}
            end,
            CreateSliderOptions = function(low, high, step) return {low = low, high = high, step = step} end,
            CreateSlider = function(_, setting, sliderOptions, tooltip)
                state.initializers[setting.variable] = {setting = setting, options = sliderOptions, tooltip = tooltip}
            end,
            CreateControlTextContainer = function()
                local data = {}
                return {Add = function(_, key, label) data[#data + 1] = {value = key, label = label} end,
                    GetData = function() return data end}
            end,
            CreateDropdown = function(_, setting, choices, tooltip)
                state.initializers[setting.variable] = {setting = setting, choices = choices, tooltip = tooltip}
            end,
            CreateColorSwatch = function(_, setting, tooltip)
                state.initializers[setting.variable] = {setting = setting, tooltip = tooltip, swatch = true}
            end,
            OpenToCategory = function(id) state.opened = id end,
            NotifyUpdate = function(variable) state.notified = variable end,
        }
        env.CreateSettingsListSectionHeaderInitializer = function(name) return {heading = name} end
        if options.noSwatch then env.Settings.CreateColorSwatch = nil end
    end

    -- The game's bars and buttons, each with a key label.
    local without = {}
    for _, name in ipairs(options.without or {}) do without[name] = true end
    state.labels = {}
    for barIndex, bar in ipairs(BAR_FRAMES) do
        local frameName = bar.frame == "MainActionBar" and (options.mainName or "MainActionBar") or bar.frame
        if not without[bar.frame] then
            newFrame("Frame", frameName).game = true
            for index = 1, bar.count do
                local name = bar.button:format(index)
                local button = newFrame("Button", name)
                button.game = true
                -- One row of 45 px buttons per bar, bars 60 px apart.
                local left, bottom = 100 + (index - 1) * 45, 100 + barIndex * 60
                button.rect = {left, left + 45, bottom + 45, bottom}
                -- The key label, as the game makes it: small, top right.
                local label = {text = "", writes = 0, font = {"Fonts\\ARIALN.TTF", 10, "OUTLINE"}, alpha = 1,
                    points = {{"TOPRIGHT", button, "TOPRIGHT", -5, -5}}, justify = "RIGHT", width = 36, height = 10,
                    fontWrites = 0, pointWrites = 0}
                function label:SetText(text)
                    self.text = text
                    self.writes = self.writes + 1
                end
                function label:GetText() return self.text end
                function label:GetFont() return unpack(self.font) end
                function label:SetFont(font, size, flags)
                    self.font = {font, size, flags}
                    self.fontWrites = self.fontWrites + 1
                end
                function label:GetAlpha() return self.alpha end
                function label:SetAlpha(alpha) self.alpha = alpha end
                function label:GetNumPoints() return #self.points end
                function label:GetPoint(at) return unpack(self.points[at], 1, 5) end
                function label:ClearAllPoints()
                    if state.combat then error("a label's anchors changed in combat") end
                    self.points = {}
                end
                function label:SetPoint(...)
                    if state.combat then error("a label's anchors changed in combat") end
                    self.points[#self.points + 1] = {...}
                    self.pointWrites = self.pointWrites + 1
                end
                function label:GetJustifyH() return self.justify end
                function label:SetJustifyH(justify) self.justify = justify end
                function label:GetWidth() return self.width end
                function label:GetHeight() return self.height end
                function label:SetWidth(width) self.width = width end
                function label:SetHeight(height) self.height = height end
                function label:SetSize(width, height) self.width, self.height = width, height end
                button.HotKey = label
                state.labels[name] = {label = label, command = bar.command:format(index)}
            end
        end
    end
    -- The game writes every button's key label, as on UPDATE_BINDINGS.
    function state.gameWritesLabels()
        for _, entry in pairs(state.labels) do
            local key = env.GetBindingKey(entry.command)
            entry.label:SetText(key and env.GetBindingText(key, 1) or RANGE_DOT)
        end
    end
    state.gameWritesLabels()

    function state.emit(event, ...)
        for _, frame in ipairs(state.frames) do
            if frame.events[event] and frame.scripts.OnEvent then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end
    function state.hold(...)
        state.mods = {}
        for _, name in ipairs({...}) do state.mods[name] = true end
        state.emit("MODIFIER_STATE_CHANGED")
    end
    function state.slash(text)
        env.SlashCmdList.HOTBARHIGHLIGHT(text or "")
    end
    function state.clear() state.messages = {} end
    function state.alpha(name) return env[name].alpha end
    local function entryOf(name)
        for _, bar in pairs(state.hh.state.bars) do
            if bar.frameName == name then return bar end
        end
    end
    -- The thin line's frame and the soft glow's frame.
    function state.borderOf(name)
        local entry = entryOf(name)
        return entry and entry.border
    end
    function state.glowOf(name)
        local entry = entryOf(name)
        return entry and entry.glow
    end
    -- Highlighted, by either look.
    function state.bordered(name)
        local border, glow = state.borderOf(name), state.glowOf(name)
        return (border ~= nil and border.shown == true) or (glow ~= nil and glow.shown == true)
    end
    function state.text(button) return state.labels[button].label.text end
    function state.label(button) return state.labels[button].label end

    if options.beforeLoad then options.beforeLoad(env) end
    env.HotbarHighlightDB = options.db
    state.hh = {}
    for _, path in ipairs(FILES) do
        local chunk, message = loadfile(path)
        if not chunk then error(message) end
        setfenv(chunk, env)
        chunk("HotbarHighlight", state.hh)
    end
    state.emit("ADDON_LOADED", "SomethingElse")
    state.emit("ADDON_LOADED", "HotbarHighlight")
    state.emit("PLAYER_LOGIN")
    state.emit("PLAYER_ENTERING_WORLD")
    state.runTimers()
    return state
end

-- Keys -------------------------------------------------------------------------

test("a key splits into its layer and the key itself, the minus key too", function()
    local hh = fixture().hh
    local function split(key)
        local layer, plain = hh.SplitKey(key)
        return tostring(layer) .. " " .. tostring(plain)
    end
    equal(split("1"), "NONE 1")
    equal(split("SHIFT-1"), "SHIFT 1")
    equal(split("ALT-CTRL-SHIFT-F5"), "ALT-CTRL-SHIFT F5")
    equal(split("SHIFT--"), "SHIFT -", "Shift and the minus key")
    equal(split("-"), "NONE -")
    equal(split("CTRL-="), "CTRL =")
    equal(split("SHIFT-ALT-Q"), "ALT-SHIFT Q", "the game's order, whatever order the key came in")
    equal(split("LSHIFT-1"), "SHIFT 1", "a left or right modifier is its modifier")
    equal(split("META-X"), "META X")
    equal(split("NUMPAD1"), "NONE NUMPAD1")
    equal(split(""), "nil nil")
    equal(split(nil), "nil nil")
end)

test("short labels: a letter per modifier and the key; long key names shortened", function()
    local hh = fixture().hh
    equal(hh.ShortKey("SHIFT-1", "short"), "S1")
    equal(hh.ShortKey("CTRL-1", "short"), "C1")
    equal(hh.ShortKey("ALT-SHIFT-1", "short"), "AS1")
    equal(hh.ShortKey("ALT-CTRL-1", "short"), "AC1")
    equal(hh.ShortKey("ALT-CTRL-SHIFT-=", "short"), "ACS=")
    equal(hh.ShortKey("SHIFT--", "short"), "S-")
    equal(hh.ShortKey("5", "short"), "5")
    equal(hh.ShortKey("ALT-SHIFT-1", "key"), "1", "key only")
    equal(hh.ShortKey("SHIFT-NUMPAD7", "short"), "SN7")
    equal(hh.ShortKey("CTRL-BUTTON4", "short"), "CM4")
    equal(hh.ShortKey("BUTTON3", "short"), "MM")
    equal(hh.ShortKey("SHIFT-MOUSEWHEELUP", "short"), "SWU")
    equal(hh.ShortKey("ALT-SPACE", "short"), "ASp")
    equal(hh.ShortKey("F11", "short"), "F11")
    equal(hh.ShortKey(nil, "short"), nil)
end)

-- Layers -----------------------------------------------------------------------

test("each bar's layer is read from its keys; a bar with no keys has none", function()
    local state = fixture()
    local bars = state.hh.state.bars
    equal(bars.bar1.layer, "NONE")
    equal(bars.bar2.layer, "SHIFT")
    equal(bars.bar3.layer, "CTRL")
    equal(bars.bar4.layer, "ALT-SHIFT")
    equal(bars.pet.layer, "ALT-CTRL")
    equal(bars.bar5.layer, nil)
    equal(bars.bar5.bound, 0)
    equal(bars.bar2.bound, 12)
    equal(bars.stance.layer, nil)
end)

test("a bar with mixed keys takes the layer most of its buttons share; a tie goes to the simpler one", function()
    local bindings = {}
    for index = 1, 12 do
        bindings["ACTIONBUTTON" .. index] = {index <= 8 and tostring(index) or ("SHIFT-" .. index)}
    end
    for index = 1, 6 do bindings["MULTIACTIONBAR1BUTTON" .. index] = {"CTRL-" .. index} end
    for index = 7, 12 do bindings["MULTIACTIONBAR1BUTTON" .. index] = {"SHIFT-F" .. index} end
    -- Two keys on one button: each layer counts once.
    bindings.MULTIACTIONBAR2BUTTON1 = {"ALT-1", "ALT-NUMPAD1"}
    local state = fixture({bindings = bindings})
    equal(state.hh.state.bars.bar1.layer, "NONE", "8 of 12")
    equal(state.hh.state.bars.bar2.layer, "SHIFT", "6 and 6: Shift is listed before Ctrl")
    equal(state.hh.state.bars.bar3.layer, "ALT")
    equal(state.hh.state.bars.bar3.bound, 1)
end)

test("new key bindings change the layers at once", function()
    local state = fixture()
    for index = 1, 12 do state.bindings["MULTIACTIONBAR4BUTTON" .. index] = {"ALT-" .. NAGA_KEYS[index]} end
    state.emit("UPDATE_BINDINGS")
    equal(state.hh.state.bars.bar5.layer, "ALT")
end)

-- The highlight ------------------------------------------------------------------

test("holding Shift highlights the Shift bar and fades the other bound bars; letting go puts all back", function()
    local state = fixture()
    state.env.MultiBarBottomRight.alpha = 0.8 -- the user's own opacity
    state.env.MultiBarLeft.alpha = 0.6 -- a bar with no keys
    state.hold("SHIFT")
    equal(state.hh.state.held, "SHIFT")
    equal(state.hh.state.active, true)
    equal(state.alpha("MultiBarBottomLeft"), 1, "the Shift bar")
    equal(state.bordered("MultiBarBottomLeft"), true)
    equal(state.alpha("MainActionBar"), 0.4)
    equal(state.alpha("MultiBarBottomRight"), 0.4)
    equal(state.alpha("MultiBarRight"), 0.4)
    equal(state.alpha("PetActionBar"), 0.4)
    equal(state.alpha("MultiBarLeft"), 0.6, "no keys: left alone")
    equal(state.alpha("StanceBar"), 1, "no keys: left alone")
    equal(state.bordered("MainActionBar"), false)
    local glow = state.glowOf("MultiBarBottomLeft")
    equal(glow.shown, true, "the soft glow by default")
    equal(state.borderOf("MultiBarBottomLeft").shown, false, "not the line")
    equal(glow.parent, state.env.UIParent, "not a child of the game's bar")
    equal(glow.points[1][2], state.env.MultiBarBottomLeft, "anchored around the bar")
    equal(#glow.textures, 12, "four sides, four corners, four inner sides")
    equal(glow.strata, "LOW", "one strata below the bar, so the buttons draw over the inner glow")
    equal(glow.textures[1].path, "Interface\\AddOns\\HotbarHighlight\\Textures\\GlowTop")
    equal(glow.textures[1].height, 18, "a side reaches 18 px out")
    equal(glow.textures[3].width, 18)
    equal(glow.textures[5].width, 18, "a corner is square")
    equal(glow.textures[5].height, 18)
    near(glow.textures[1].tint[1], 1, "gold")
    near(glow.textures[1].tint[2], 0.82)
    near(glow.textures[1].tint[3], 0)
    near(glow.textures[1].tint[4], 0.9, "at 90%")
    -- The inner glow: just inside each edge, the opposite side's texture, 14% of a 45 px button deep.
    equal(glow.textures[9].path, "Interface\\AddOns\\HotbarHighlight\\Textures\\GlowBottom", "fades downward from the top edge")
    equal(glow.textures[9].points[1][1], "TOPLEFT")
    equal(glow.textures[9].points[1][3], "TOPLEFT", "inside the edge")
    near(glow.textures[9].height, 6.3)
    near(glow.textures[11].width, 6.3)
    equal(glow.textures[11].path, "Interface\\AddOns\\HotbarHighlight\\Textures\\GlowRight")
    state.hold()
    equal(state.hh.state.active, false)
    equal(state.alpha("MainActionBar"), 1)
    equal(state.alpha("MultiBarBottomRight"), 0.8, "its own opacity is back")
    equal(state.bordered("MultiBarBottomLeft"), false)
end)

test("the inner glow follows the bar's own scale, and the glow sits below whatever strata the bar is in", function()
    local state = fixture()
    -- Edit Mode's Icon Size at 80%, and a bar the client keeps in a low strata.
    state.env.MultiBarBottomLeftButton1.scale = 0.8
    state.env.MultiBarBottomRight.strata = "LOW"
    state.emit("UPDATE_BINDINGS")
    state.hold("SHIFT")
    near(state.glowOf("MultiBarBottomLeft").textures[9].height, 0.14 * 45 * 0.8)
    state.hold("CTRL")
    local glow = state.glowOf("MultiBarBottomRight")
    equal(glow.shown, true)
    equal(glow.strata, "LOW", "made at login, when the bar still said MEDIUM")
    local low = fixture({beforeLoad = function(env) env.MultiBarBottomRight.strata = "LOW" end})
    equal(low.glowOf("MultiBarBottomRight").strata, "BACKGROUND")
    local lowest = fixture({beforeLoad = function(env) env.MultiBarBottomRight.strata = "BACKGROUND" end})
    equal(lowest.glowOf("MultiBarBottomRight").strata, "BACKGROUND", "nothing lower")
end)

test("each layer has its bar: Ctrl, Alt+Shift, Alt+Ctrl", function()
    local state = fixture()
    state.hold("CTRL")
    equal(state.bordered("MultiBarBottomRight"), true)
    equal(state.alpha("MultiBarBottomLeft"), 0.4)
    state.hold("ALT", "SHIFT")
    equal(state.bordered("MultiBarRight"), true)
    equal(state.bordered("MultiBarBottomRight"), false)
    equal(state.alpha("MultiBarBottomRight"), 0.4)
    equal(state.alpha("MultiBarRight"), 1)
    state.hold("ALT", "CTRL")
    equal(state.bordered("PetActionBar"), true)
    equal(state.alpha("PetActionBar"), 1)
    equal(state.alpha("MultiBarRight"), 0.4)
end)

test("modifiers no bar uses change nothing: Alt alone as a self-cast key", function()
    local state = fixture()
    state.hold("ALT")
    equal(state.hh.state.active, false)
    equal(state.alpha("MainActionBar"), 1)
    equal(state.alpha("MultiBarBottomLeft"), 1)
    equal(state.bordered("MultiBarBottomLeft"), false)
    state.hold("ALT", "CTRL", "SHIFT")
    equal(state.hh.state.active, false)
end)

test("Shift while you type in an edit box is not a layer", function()
    local state = fixture()
    state.focus = {}
    state.hold("SHIFT")
    equal(state.hh.state.held, "NONE")
    equal(state.alpha("MainActionBar"), 1)
    state.focus = nil
    state.hold("SHIFT")
    equal(state.alpha("MainActionBar"), 0.4)
end)

test("with no modifier held nothing is highlighted, unless the setting asks for the unmodified bar", function()
    local state = fixture()
    equal(state.hh.state.active, false)
    equal(state.bordered("MainActionBar"), false)
    state.settings.HOTBARHIGHLIGHT_IDLE.set("base")
    equal(state.hh.db.idle, "base")
    equal(state.bordered("MainActionBar"), true)
    equal(state.alpha("MainActionBar"), 1)
    equal(state.alpha("MultiBarBottomLeft"), 0.4)
    state.hold("SHIFT")
    equal(state.bordered("MainActionBar"), false)
    equal(state.alpha("MainActionBar"), 0.4)
    equal(state.bordered("MultiBarBottomLeft"), true)
end)

test("only in combat: nothing outside a fight, and it starts and ends with the fight", function()
    local state = fixture({db = {combatOnly = true}})
    state.hold("SHIFT")
    equal(state.alpha("MainActionBar"), 1)
    state.combat = true
    state.emit("PLAYER_REGEN_DISABLED")
    equal(state.alpha("MainActionBar"), 0.4)
    equal(state.bordered("MultiBarBottomLeft"), true)
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.alpha("MainActionBar"), 1)
    equal(state.bordered("MultiBarBottomLeft"), false)
end)

test("Edit Mode shows the bars as they are", function()
    local state = fixture()
    state.hold("SHIFT")
    equal(state.alpha("MainActionBar"), 0.4)
    state.env.EditModeManagerFrame:Show()
    equal(state.alpha("MainActionBar"), 1)
    equal(state.bordered("MultiBarBottomLeft"), false)
    state.env.EditModeManagerFrame:Hide()
    equal(state.alpha("MainActionBar"), 0.4)
end)

test("a hidden bar gets no border; it comes back with the bar", function()
    local state = fixture()
    state.hold("SHIFT")
    equal(state.bordered("MultiBarBottomLeft"), true)
    state.env.MultiBarBottomLeft:Hide()
    equal(state.bordered("MultiBarBottomLeft"), false)
    state.env.MultiBarBottomLeft:Show()
    equal(state.bordered("MultiBarBottomLeft"), true)
end)

test("a modifier whose release was never reported is noticed on the next check", function()
    local state = fixture()
    state.hold("SHIFT")
    local watcher
    for _, frame in ipairs(state.frames) do
        if frame.events.MODIFIER_STATE_CHANGED then watcher = frame end
    end
    equal(type(watcher.scripts.OnUpdate), "function", "checking while a modifier is held")
    state.mods = {} -- the window lost focus: no event
    watcher.scripts.OnUpdate(watcher, 0.1)
    equal(state.alpha("MainActionBar"), 0.4, "not yet: checked every 0.2 s")
    watcher.scripts.OnUpdate(watcher, 0.15)
    equal(state.alpha("MainActionBar"), 1)
    equal(watcher.scripts.OnUpdate, nil, "no checking with nothing held")
end)

test("a secret answer about a modifier counts as not held", function()
    local state = fixture({secretKeys = true})
    state.hold("SHIFT")
    equal(state.hh.state.held, "NONE")
    equal(state.alpha("MainActionBar"), 1)
end)

-- Settings -----------------------------------------------------------------------

test("a bar can be given a layer or left alone", function()
    local state = fixture()
    state.settings.HOTBARHIGHLIGHT_LAYER_BAR5.set("ALT")
    equal(state.hh.db.layers.bar5, "ALT")
    state.hold("ALT")
    equal(state.bordered("MultiBarLeft"), true)
    equal(state.alpha("MainActionBar"), 0.4)
    state.hold()
    state.settings.HOTBARHIGHLIGHT_LAYER_BAR1.set("ignore")
    state.hold("SHIFT")
    equal(state.alpha("MainActionBar"), 1, "left alone")
    equal(state.alpha("MultiBarBottomRight"), 0.4)
    state.settings.HOTBARHIGHLIGHT_LAYER_BAR1.set("auto")
    equal(state.hh.db.layers.bar1, nil, "auto is not saved")
    equal(state.alpha("MainActionBar"), 0.4)
    state.settings.HOTBARHIGHLIGHT_LAYER_BAR1.set("nonsense")
    equal(state.hh.db.layers.bar1, nil)
end)

test("the fade, the border and its look follow the settings at once", function()
    local state = fixture()
    state.hold("SHIFT")
    state.settings.HOTBARHIGHLIGHT_DIM.set(70)
    equal(state.alpha("MainActionBar"), 0.7)
    state.settings.HOTBARHIGHLIGHT_DIM.set(100)
    equal(state.alpha("MainActionBar"), 1, "100%: no fade")
    state.settings.HOTBARHIGHLIGHT_DIM.set(5)
    equal(state.hh.db.dim, 10, "kept in range")
    state.settings.HOTBARHIGHLIGHT_COLOR.set("FF00FF80")
    equal(state.hh.db.color, "ff00ff80", "any color, saved in lower case")
    state.settings.HOTBARHIGHLIGHT_OPACITY.set(50)
    state.settings.HOTBARHIGHLIGHT_GLOW.set(30)
    local glow = state.glowOf("MultiBarBottomLeft")
    near(glow.textures[2].tint[1], 0)
    near(glow.textures[2].tint[2], 1)
    near(glow.textures[2].tint[3], 0.5)
    near(glow.textures[2].tint[4], 0.5)
    equal(glow.textures[2].height, 30)
    equal(glow.textures[8].width, 30)
    state.settings.HOTBARHIGHLIGHT_GLOW.set(500)
    equal(state.hh.db.glow, 48, "kept in range")
    state.settings.HOTBARHIGHLIGHT_INNER.set(20)
    near(glow.textures[10].height, 9, "20% of a button")
    equal(glow.textures[10].shown, true)
    state.settings.HOTBARHIGHLIGHT_INNER.set(0)
    equal(glow.textures[9].shown, false, "0: no inner glow")
    equal(glow.textures[12].shown, false)
    equal(glow.textures[1].shown, true, "the outer glow stays")
    state.settings.HOTBARHIGHLIGHT_INNER.set(14)
    equal(glow.textures[9].shown, true)
    state.settings.HOTBARHIGHLIGHT_COLOR.set("not a color")
    equal(state.hh.db.color, "ffffd100", "nonsense: gold")
    -- The thin line instead.
    state.settings.HOTBARHIGHLIGHT_STYLE.set("line")
    state.settings.HOTBARHIGHLIGHT_THICKNESS.set(4)
    local border = state.borderOf("MultiBarBottomLeft")
    equal(border.shown, true)
    equal(glow.shown, false, "one look at a time")
    equal(border.parent, state.env.UIParent)
    near(border.textures[1].color[1], 1)
    near(border.textures[1].color[4], 0.5, "the line takes the opacity too")
    equal(border.textures[1].height, 4)
    equal(border.textures[3].width, 4)
    state.settings.HOTBARHIGHLIGHT_STYLE.set("glow")
    equal(glow.shown, true)
    equal(border.shown, false)
    state.settings.HOTBARHIGHLIGHT_BORDER.set(false)
    equal(state.bordered("MultiBarBottomLeft"), false)
    equal(state.alpha("MainActionBar"), 0.1, "the fade stays")
    state.settings.HOTBARHIGHLIGHT_ENABLED.set(false)
    equal(state.alpha("MainActionBar"), 1)
end)

test("saved settings are repaired: only known keys and valid values survive", function()
    local state = fixture({db = {enabled = "yes", dim = 500, border = 0, color = "pink", thickness = "x",
        idle = 7, combatOnly = "true", labels = "tiny", extra = true,
        layers = {bar1 = "SHIFT", bar2 = "auto", bar3 = "wrong", nothing = "ALT"}}})
    local db = state.hh.db
    equal(db.enabled, true)
    equal(db.dim, 100)
    equal(db.border, true)
    equal(db.color, "ffffd100")
    equal(db.style, "glow")
    equal(db.opacity, 90)
    equal(db.glow, 18)
    equal(db.inner, 14)
    equal(db.thickness, 2)
    equal(db.idle, "all")
    equal(db.combatOnly, false)
    equal(db.labels, "short")
    equal(db.area, "bar")
    equal(db.labelPlace, "game")
    equal(db.labelX, 0)
    equal(db.labelSize, 100)
    equal(db.labelOpacity, 100)
    equal(db.extra, nil)
    equal(db.layers.bar1, "SHIFT")
    equal(db.layers.bar2, nil)
    equal(db.layers.bar3, nil)
    equal(db.layers.nothing, nil)
    equal(state.env.HotbarHighlightDB, db, "saved as the game's variable")
    local fresh = fixture({db = "broken"})
    equal(fresh.hh.db.enabled, true)
    equal(fresh.hh.db.dim, 40)
    -- 0.1.0 saved a preset's name.
    local older = fixture({db = {color = "green", style = "line"}})
    equal(older.hh.db.color, "ff4dff73")
    equal(older.hh.db.style, "line")
end)

test("the settings page lists every setting and a choice per bar", function()
    local state = fixture()
    equal(state.category.title, "Hotbar Highlight")
    equal(state.registered, state.category)
    for _, variable in ipairs({"HOTBARHIGHLIGHT_ENABLED", "HOTBARHIGHLIGHT_DIM", "HOTBARHIGHLIGHT_BORDER",
        "HOTBARHIGHLIGHT_STYLE", "HOTBARHIGHLIGHT_COLOR", "HOTBARHIGHLIGHT_OPACITY", "HOTBARHIGHLIGHT_GLOW",
        "HOTBARHIGHLIGHT_INNER", "HOTBARHIGHLIGHT_AREA", "HOTBARHIGHLIGHT_LABEL_PLACE", "HOTBARHIGHLIGHT_LABEL_X",
        "HOTBARHIGHLIGHT_LABEL_Y", "HOTBARHIGHLIGHT_LABEL_SIZE", "HOTBARHIGHLIGHT_LABEL_OPACITY",
        "HOTBARHIGHLIGHT_THICKNESS", "HOTBARHIGHLIGHT_IDLE", "HOTBARHIGHLIGHT_COMBAT",
        "HOTBARHIGHLIGHT_LABELS", "HOTBARHIGHLIGHT_LAYER_BAR1", "HOTBARHIGHLIGHT_LAYER_BAR8",
        "HOTBARHIGHLIGHT_LAYER_PET", "HOTBARHIGHLIGHT_LAYER_STANCE"}) do
        equal(state.initializers[variable] ~= nil, true, variable)
        equal(type(state.initializers[variable].tooltip), "string", variable .. " has help")
    end
    equal(state.settings.HOTBARHIGHLIGHT_DIM.get(), 40)
    equal(state.initializers.HOTBARHIGHLIGHT_COLOR.swatch, true, "a color swatch")
    equal(state.settings.HOTBARHIGHLIGHT_COLOR.get(), "ffffd100")
    -- A client without the swatch gets a list of colors.
    local plain = fixture({noSwatch = true})
    local colors = plain.initializers.HOTBARHIGHLIGHT_COLOR.choices()
    equal(#colors, 6)
    equal(colors[1].label, "Gold")
    plain.settings.HOTBARHIGHLIGHT_COLOR.set("ff59b3ff")
    equal(plain.hh.db.color, "ff59b3ff")
    equal(state.settings.HOTBARHIGHLIGHT_LAYER_PET.get(), "auto")
    local choices = state.initializers.HOTBARHIGHLIGHT_LAYER_PET.choices()
    equal(#choices, 10)
    equal(choices[1].value, "auto")
    equal(choices[2].value, "ignore")
    equal(choices[10].value, "ALT-CTRL-SHIFT")
    equal(state.headings[1].heading, "Bars")
end)

test("/hh opens the settings, out of combat; status, on and off; anything else explains", function()
    local state = fixture()
    state.slash("")
    equal(state.opened, state.category.GetID())
    state.opened = nil
    state.combat = true
    state.slash("")
    equal(state.opened, nil)
    contains(state.messages[#state.messages], "out of combat")
    state.combat = false
    state.clear()
    state.slash(" Status ")
    contains(state.messages[1], "enabled=true held=No modifier active=false other bars at 40%")
    contains(state.messages[2], "Action Bar 1 (MainActionBar): No modifier (from its keys); 12 of 12 buttons have a key")
    contains(state.messages[3], "Action Bar 2 (MultiBarBottomLeft): Shift (from its keys)")
    contains(state.messages[6], "Action Bar 5 (MultiBarLeft): no keys, left alone; 0 of 12")
    contains(state.messages[10], "Pet Bar (PetActionBar): Alt+Ctrl (from its keys); 10 of 10")
    contains(state.messages[12], "Key labels: 116 found, 46 shortened, 0 with a changed look.")
    state.slash("off")
    equal(state.hh.db.enabled, false)
    equal(state.notified, "HOTBARHIGHLIGHT_ENABLED")
    state.slash("on")
    equal(state.hh.db.enabled, true)
    state.clear()
    state.slash("dance")
    contains(state.messages[1], "Use /hh to open the settings")
    equal(type(state.env.SLASH_HOTBARHIGHLIGHT1), "string")
end)

-- Key labels ---------------------------------------------------------------------

test("key labels are shortened, and again each time the game rewrites them; a button with no key keeps the game's text", function()
    local state = fixture()
    equal(state.text("ActionButton1"), "1")
    equal(state.text("MultiBarBottomLeftButton1"), "S1")
    equal(state.text("MultiBarBottomLeftButton11"), "S-")
    equal(state.text("MultiBarBottomRightButton3"), "C3")
    equal(state.text("MultiBarRightButton12"), "AS=")
    equal(state.text("PetActionButton2"), "AC2")
    equal(state.text("MultiBarLeftButton1"), RANGE_DOT, "no key: the game's range dot stays")
    state.gameWritesLabels()
    equal(state.text("MultiBarBottomLeftButton1"), "S1", "written again right after the game")
    local writes = state.labels.MultiBarBottomLeftButton1.label.writes
    state.hh.RefreshLabels()
    equal(state.labels.MultiBarBottomLeftButton1.label.writes, writes, "nothing to write when it already reads right")
    state.bindings.MULTIACTIONBAR1BUTTON1 = {"CTRL-SHIFT-Q"}
    state.emit("UPDATE_BINDINGS")
    state.runTimers()
    equal(state.text("MultiBarBottomLeftButton1"), "CSQ")
end)

test("key labels: key only, the game's own, and off put the texts back", function()
    local state = fixture()
    state.settings.HOTBARHIGHLIGHT_LABELS.set("key")
    equal(state.text("MultiBarBottomLeftButton1"), "1")
    equal(state.text("PetActionButton2"), "2")
    state.settings.HOTBARHIGHLIGHT_LABELS.set("blizzard")
    equal(state.text("MultiBarBottomLeftButton1"), "s-1")
    equal(state.text("PetActionButton2"), "a-c-2")
    state.gameWritesLabels()
    equal(state.text("MultiBarBottomLeftButton1"), "s-1", "left alone")
    state.settings.HOTBARHIGHLIGHT_LABELS.set("short")
    equal(state.text("MultiBarBottomLeftButton1"), "S1")
    state.settings.HOTBARHIGHLIGHT_ENABLED.set(false)
    equal(state.text("MultiBarBottomLeftButton1"), "s-1", "off: the game's text")
    state.gameWritesLabels()
    equal(state.text("MultiBarBottomLeftButton1"), "s-1")
end)

-- Key label look -----------------------------------------------------------------

test("label look: with every setting at its default only the text is touched", function()
    local state = fixture()
    local label = state.label("MultiBarBottomLeftButton1")
    equal(label.text, "S1")
    equal(label.fontWrites, 0)
    equal(label.pointWrites, 0)
    equal(label.font[2], 10)
    equal(label.width, 36)
    equal(label.alpha, 1)
end)

test("label look: a place moves every label to that corner of its button, with offsets; the game's own puts it back", function()
    local state = fixture()
    local label = state.label("MultiBarBottomLeftButton1")
    local button = state.env.MultiBarBottomLeftButton1
    state.settings.HOTBARHIGHLIGHT_LABEL_PLACE.set("bottomleft")
    equal(#label.points, 1)
    equal(label.points[1][1], "BOTTOMLEFT")
    equal(label.points[1][2], button, "on its own button")
    equal(label.points[1][3], "BOTTOMLEFT")
    equal(label.points[1][4], 2, "a small inset")
    equal(label.points[1][5], 2)
    equal(label.justify, "LEFT")
    equal(label.width, 45, "room for the text: the button's width")
    equal(state.label("PetActionButton3").points[1][1], "BOTTOMLEFT", "every bar")
    state.settings.HOTBARHIGHLIGHT_LABEL_X.set(4)
    state.settings.HOTBARHIGHLIGHT_LABEL_Y.set(-3)
    equal(label.points[1][4], 6)
    equal(label.points[1][5], -1)
    state.settings.HOTBARHIGHLIGHT_LABEL_PLACE.set("center")
    equal(label.points[1][1], "CENTER")
    equal(label.justify, "CENTER")
    state.clear()
    state.slash("status")
    contains(state.messages[12], "116 with a changed look")
    -- The game's own place keeps the offsets: they move the label from where the game puts it.
    state.settings.HOTBARHIGHLIGHT_LABEL_PLACE.set("game")
    equal(label.points[1][1], "TOPRIGHT")
    equal(label.points[1][2], button)
    equal(label.points[1][4], -1, "the game's -5, moved 4 right")
    equal(label.points[1][5], -8, "the game's -5, moved 3 down")
    equal(label.justify, "RIGHT")
    state.settings.HOTBARHIGHLIGHT_LABEL_X.set(0)
    state.settings.HOTBARHIGHLIGHT_LABEL_Y.set(0)
    equal(label.points[1][4], -5)
    equal(label.points[1][5], -5)
    equal(label.width, 36)
    equal(label.height, 10)
end)

test("label look: the offsets alone move a label from where the game puts it", function()
    local state = fixture()
    local label = state.label("ActionButton1")
    state.settings.HOTBARHIGHLIGHT_LABEL_Y.set(-10)
    equal(state.hh.db.labelPlace, "game")
    equal(label.points[1][1], "TOPRIGHT")
    equal(label.points[1][4], -5)
    equal(label.points[1][5], -15)
    state.settings.HOTBARHIGHLIGHT_LABEL_X.set(-20)
    equal(label.points[1][4], -25)
    state.clear()
    state.slash("status")
    contains(state.messages[12], "116 with a changed look. Place game, offsets -20, -10, size 100%, opacity 100%.")
end)

test("label look: a label that refuses to move does not stop the others, and the reason is reported", function()
    local state = fixture()
    local stubborn = state.label("ActionButton1")
    local setPoint = stubborn.SetPoint
    stubborn.SetPoint = function(self, ...)
        if select(2, ...) == state.env.ActionButton1 and select("#", ...) == 5 and select(1, ...) == "BOTTOM" then
            error("Action blocked", 0)
        end
        return setPoint(self, ...)
    end
    state.clear()
    state.settings.HOTBARHIGHLIGHT_LABEL_PLACE.set("bottom")
    equal(state.label("ActionButton2").points[1][1], "BOTTOM", "the others moved")
    equal(state.label("PetActionButton10").points[1][1], "BOTTOM")
    contains(state.messages[1], "1 key labels could not be moved. First: ActionButton1: Action blocked")
    state.settings.HOTBARHIGHLIGHT_LABEL_X.set(1)
    equal(#state.messages, 1, "said once a session")
    state.slash("status")
    contains(state.messages[#state.messages], "1 key labels could not be moved. First: ActionButton1: Action blocked")
    equal(#state.errors, 0, "not an error for the error handler")
end)

test("label look: size is a percent of the label's own font, opacity of its own opacity; off puts both back", function()
    local state = fixture()
    local label = state.label("ActionButton5")
    state.settings.HOTBARHIGHLIGHT_LABEL_SIZE.set(150)
    equal(label.font[1], "Fonts\\ARIALN.TTF", "the same font")
    equal(label.font[2], 15)
    equal(label.font[3], "OUTLINE")
    equal(label.height, 15, "the label's box grows with it")
    equal(label.width, 45)
    equal(label.points[1][1], "TOPRIGHT", "still where the game put it")
    state.settings.HOTBARHIGHLIGHT_LABEL_OPACITY.set(50)
    equal(label.alpha, 0.5)
    state.settings.HOTBARHIGHLIGHT_LABEL_SIZE.set(80)
    equal(label.font[2], 8)
    equal(label.height, 10, "never smaller than the game's own box")
    state.settings.HOTBARHIGHLIGHT_ENABLED.set(false)
    equal(label.font[2], 10)
    equal(label.alpha, 1)
    equal(label.width, 36)
    state.settings.HOTBARHIGHLIGHT_ENABLED.set(true)
    equal(label.font[2], 8)
    state.settings.HOTBARHIGHLIGHT_LABEL_SIZE.set(999)
    equal(state.hh.db.labelSize, 200, "kept in range")
end)

test("label look: anchors wait for combat to end; the font and opacity do not", function()
    local state = fixture()
    local label = state.label("ActionButton5")
    state.combat = true
    state.settings.HOTBARHIGHLIGHT_LABEL_PLACE.set("topleft")
    state.settings.HOTBARHIGHLIGHT_LABEL_SIZE.set(120)
    equal(label.points[1][1], "TOPRIGHT", "not in combat")
    equal(label.font[2], 12, "the font at once")
    state.clear()
    state.slash("status")
    contains(state.messages[12], "their place waits for combat to end")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(label.points[1][1], "TOPLEFT")
    equal(label.justify, "LEFT")
end)

test("label look: another addon's size and place for a label become its base, with these settings on top", function()
    local state = fixture()
    local label = state.label("PetActionButton1")
    local button = state.env.PetActionButton1
    state.settings.HOTBARHIGHLIGHT_LABEL_SIZE.set(150)
    equal(label.font[2], 15)
    -- Another addon makes the pet bar's labels smaller, as Grimoire does.
    label:SetFont("Fonts\\ARIALN.TTF", 6, "OUTLINE")
    equal(label.font[2], 9, "150% of the other addon's 6")
    -- And moves them, in the usual two calls.
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    equal(label.points[1][1], "TOPLEFT", "left as the other addon set it: the place setting is the game's own")
    state.settings.HOTBARHIGHLIGHT_LABEL_PLACE.set("bottomright")
    equal(label.points[1][1], "BOTTOMRIGHT")
    label:ClearAllPoints()
    label:SetPoint("TOP", button, "TOP", 0, -1)
    state.runTimers()
    equal(label.points[1][1], "BOTTOMRIGHT", "this addon's place again, a frame later")
    equal(#label.points, 1)
    -- Back to the game's own place: the other addon's last anchors, not the first ones seen.
    state.settings.HOTBARHIGHLIGHT_LABEL_PLACE.set("game")
    state.settings.HOTBARHIGHLIGHT_LABEL_SIZE.set(100)
    equal(label.points[1][1], "TOP")
    equal(label.font[2], 6)
end)

-- The highlight's area --------------------------------------------------------------

test("highlight area: only the buttons shown, when the bar shows fewer than it holds", function()
    local state = fixture()
    state.hold("SHIFT")
    local glow = state.glowOf("MultiBarBottomLeft")
    equal(glow.points[1][2], state.env.MultiBarBottomLeft, "the whole bar by default")
    -- Nine icons: the last three are hidden.
    for index = 10, 12 do state.env["MultiBarBottomLeftButton" .. index].shown = false end
    state.settings.HOTBARHIGHLIGHT_AREA.set("buttons")
    equal(#glow.points, 2)
    equal(glow.points[1][1], "TOPLEFT")
    equal(glow.points[1][2], state.env.UIParent)
    equal(glow.points[1][3], "BOTTOMLEFT", "measured from the screen's corner")
    equal(glow.points[1][4], 100, "the first button's left")
    equal(glow.points[1][5], 265, "the buttons' top")
    equal(glow.points[2][4], 100 + 9 * 45, "the ninth button's right")
    equal(glow.points[2][5], 220, "the buttons' bottom")
    -- The thin line goes around the same box, 3 px out.
    state.settings.HOTBARHIGHLIGHT_STYLE.set("line")
    local border = state.borderOf("MultiBarBottomLeft")
    equal(border.points[1][4], 97)
    equal(border.points[2][4], 100 + 9 * 45 + 3)
    state.settings.HOTBARHIGHLIGHT_STYLE.set("glow")
    -- A slot the game fades out instead of hiding counts as hidden too; the box is read each time.
    state.env.MultiBarBottomLeftButton9.alpha = 0
    state.hold()
    state.hold("SHIFT")
    equal(glow.points[2][4], 100 + 8 * 45)
    -- A bar at 80% size: its buttons' places are in its own units.
    for index = 1, 12 do state.env["MultiBarBottomLeftButton" .. index].scale = 0.8 end
    state.hold()
    state.hold("SHIFT")
    equal(glow.points[1][4], 80)
    equal(glow.points[2][4], (100 + 8 * 45) * 0.8)
    -- Back to the whole bar.
    state.settings.HOTBARHIGHLIGHT_AREA.set("bar")
    equal(glow.points[1][2], state.env.MultiBarBottomLeft)
    equal(#glow.points, 2)
end)

test("highlight area: with no button's place readable, the whole bar is used", function()
    local state = fixture({db = {area = "buttons"}})
    for index = 1, 12 do state.env["MultiBarBottomLeftButton" .. index].rect = nil end
    state.hold("SHIFT")
    equal(state.glowOf("MultiBarBottomLeft").shown, true)
    equal(state.glowOf("MultiBarBottomLeft").points[1][2], state.env.MultiBarBottomLeft)
    state.hold("CTRL")
    equal(state.glowOf("MultiBarBottomRight").points[1][2], state.env.UIParent, "a bar whose buttons do read")
end)

-- Other clients, failures, and the rule -----------------------------------------------

test("a client with an older main bar name and fewer bars still works", function()
    local state = fixture({mainName = "MainMenuBar", without = {"MultiBar5", "MultiBar6", "MultiBar7", "StanceBar"}})
    equal(state.hh.state.bars.bar1.frameName, "MainMenuBar")
    equal(state.hh.state.bars.bar6.frame, nil)
    state.hold("SHIFT")
    equal(state.alpha("MainMenuBar"), 0.4)
    equal(state.bordered("MultiBarBottomLeft"), true)
    state.clear()
    state.slash("status")
    contains(table.concat(state.messages, "\n"), "Action Bar 6: not found on this client")
end)

test("without the game's settings functions the addon still runs and /hh still reports", function()
    local state = fixture({noSettings = true})
    state.hold("SHIFT")
    equal(state.alpha("MainActionBar"), 0.4)
    state.clear()
    state.slash("")
    contains(state.messages[1], "settings page is unavailable")
    state.slash("status")
    contains(state.messages[2], "enabled=true")
end)

test("a part that fails to start is reported and the others still start", function()
    local state = fixture({breakLabels = true})
    equal(#state.hh.startFailures, 1)
    equal(state.hh.startFailures[1], "Key labels")
    equal(#state.errors, 1, "handed to the error handler")
    contains(table.concat(state.messages, "\n"), "Key labels did not start")
    state.hold("SHIFT")
    equal(state.alpha("MainActionBar"), 0.4, "the highlight works")
    equal(state.category ~= nil, true, "the settings page too")
end)

test("source scan: nothing binds, casts, moves a bar, or sends anything", function()
    -- Anchors do change, but only on the addon's own highlight frames and on
    -- key labels; the stand-in raises an error if a bar or a button is
    -- anchored, sized, scaled or re-parented, in every test.
    local banned = {"SendChatMessage", "SendAddonMessage", "C_ChatInfo", "DoEmote", "SetRaidTarget", "SetBinding",
        "SetOverrideBinding", "SaveBindings", "SetAttribute", "RunMacroText", "CastSpell", "UseAction",
        "SetParent", "SetScale", "RegisterStateDriver", "SetCVar", "ConsoleExec"}
    for _, path in ipairs(FILES) do
        local file = assert(io.open(path))
        local text = file:read("*a")
        file:close()
        for _, name in ipairs(banned) do
            equal(text:find(name, 1, true), nil, path .. " uses " .. name)
        end
    end
end)

test("each glow piece has its texture file: 32 x 32, 32-bit, white, clear at its outer side", function()
    local file = assert(io.open("Bars.lua"))
    local source = file:read("*a")
    file:close()
    local count = 0
    for name in source:gmatch('{"(Glow%a+)"') do
        count = count + 1
        local texture = assert(io.open("Textures/" .. name .. ".tga", "rb"), name .. ".tga is missing")
        local data = texture:read("*a")
        texture:close()
        equal(#data, 18 + 32 * 32 * 4, name .. " size")
        equal(data:byte(3), 2, name .. " uncompressed true color")
        equal(data:byte(13) + data:byte(14) * 256, 32, name .. " width")
        equal(data:byte(15) + data:byte(16) * 256, 32, name .. " height")
        equal(data:byte(17), 32, name .. " bits")
        equal(data:byte(19), 255, name .. " white")
    end
    equal(count, 12, "eight outer pieces and four inner ones, which reuse the sides' files")
    -- The top piece sits above the bar: clear on its top row, solid at the bottom.
    local top = assert(io.open("Textures/GlowTop.tga", "rb"))
    local data = top:read("*a")
    top:close()
    local function alpha(x, y) return data:byte(18 + (y * 32 + x) * 4 + 4) end
    equal(alpha(16, 0) < 5, true, "outer row")
    equal(alpha(16, 31) > 240, true, "inner row")
end)

test("the TOC lists every file, and the version matches the changelog", function()
    local file = assert(io.open("HotbarHighlight.toc"))
    local toc = file:read("*a")
    file:close()
    for _, path in ipairs(FILES) do
        contains(toc, "\n" .. path, path)
    end
    local version = toc:match("## Version: ([%d%.]+)")
    local log = assert(io.open("CHANGELOG.md"))
    local changes = log:read("*a")
    log:close()
    contains(changes, "## " .. version, "the changelog's entry")
end)

local passed, failed = 0, 0
for index, entry in ipairs(tests) do
    local ok, message = xpcall(entry.body, debug.traceback)
    if ok then
        passed = passed + 1
        print("ok " .. index .. " - " .. entry.name)
    else
        failed = failed + 1
        print("not ok " .. index .. " - " .. entry.name)
        print(message)
    end
end
print(string.format("\n%d tests: %d passed, %d failed", #tests, passed, failed))
print("Mock results do not establish in-client compatibility.")
os.exit(failed == 0 and 0 or 1)
