local ADDON, HH = ...

-- Hotbar Highlight: shows which action bar the modifier keys you hold belong
-- to. The bar bound to the held modifier gets a border; the other bound bars
-- fade. Key labels on the buttons can be shortened ("S1" for Shift-1).
--
-- It only changes how things look: a bar's opacity, its own border frames,
-- and the text of the buttons' key labels. It binds nothing, casts nothing,
-- moves nothing, and sends nothing to anyone.
--
-- Files: Core (settings, start), Bars (which bar is which layer, highlight),
-- Labels (key label text), Options (settings page, slash command).

HH.ADDON = ADDON
HH.TITLE = "Hotbar Highlight"

-- A layer is the modifiers of a key binding, in the game's own order:
-- "NONE", "SHIFT", "CTRL", "ALT", "ALT-SHIFT", "ALT-CTRL", "CTRL-SHIFT",
-- "ALT-CTRL-SHIFT" (and META on a Mac keyboard).
HH.MODIFIER_ORDER = {"ALT", "CTRL", "SHIFT", "META"}
local MODIFIER_OF = {
    ALT = "ALT", LALT = "ALT", RALT = "ALT",
    CTRL = "CTRL", LCTRL = "CTRL", RCTRL = "CTRL",
    SHIFT = "SHIFT", LSHIFT = "SHIFT", RSHIFT = "SHIFT",
    META = "META", LMETA = "META", RMETA = "META",
}

HH.LAYERS = {
    {key = "NONE", label = "No modifier"},
    {key = "SHIFT", label = "Shift"},
    {key = "CTRL", label = "Ctrl"},
    {key = "ALT", label = "Alt"},
    {key = "ALT-SHIFT", label = "Alt+Shift"},
    {key = "ALT-CTRL", label = "Alt+Ctrl"},
    {key = "CTRL-SHIFT", label = "Ctrl+Shift"},
    {key = "ALT-CTRL-SHIFT", label = "Alt+Ctrl+Shift"},
}

-- A bar's setting: read the layer from its keys, leave the bar alone, or a
-- fixed layer.
HH.LAYER_CHOICES = {
    {key = "auto", label = "Auto (from this bar's keys)"},
    {key = "ignore", label = "Leave this bar alone"},
}
for _, layer in ipairs(HH.LAYERS) do
    HH.LAYER_CHOICES[#HH.LAYER_CHOICES + 1] = layer
end

HH.COLORS = {
    {key = "gold", label = "Gold", color = {1, 0.82, 0}},
    {key = "white", label = "White", color = {1, 1, 1}},
    {key = "green", label = "Green", color = {0.3, 1, 0.45}},
    {key = "blue", label = "Blue", color = {0.35, 0.7, 1}},
    {key = "purple", label = "Purple", color = {0.75, 0.5, 1}},
    {key = "red", label = "Red", color = {1, 0.35, 0.3}},
}

HH.IDLE = {
    {key = "all", label = "Every bar normal"},
    {key = "base", label = "Highlight the bar with no modifier"},
}

HH.LABEL_STYLES = {
    {key = "short", label = "Short: S1, AC1"},
    {key = "key", label = "Key only: 1"},
    {key = "blizzard", label = "The game's own: s-1"},
}

HH.DIM_MIN, HH.DIM_MAX, HH.DEFAULT_DIM = 10, 100, 40
HH.THICKNESS_MIN, HH.THICKNESS_MAX, HH.DEFAULT_THICKNESS = 1, 6, 2

function HH.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

function HH.Report(text)
    local frame = DEFAULT_CHAT_FRAME
    if frame and type(frame.AddMessage) == "function" then
        frame:AddMessage("|cffffd100" .. HH.TITLE .. ":|r " .. tostring(text))
    end
end

local function Choice(value, choices, default)
    for _, choice in ipairs(choices) do
        if choice.key == value then
            return value
        end
    end
    return default
end
HH.Choice = Choice

local function Whole(value, low, high, default)
    if type(value) ~= "number" or value ~= value then
        return default
    end
    return math.max(low, math.min(high, math.floor(value + 0.5)))
end
HH.Whole = Whole

-- The saved settings, rebuilt: only known keys with valid values survive.
function HH.Sanitize(saved)
    saved = type(saved) == "table" and saved or {}
    local clean = {
        enabled = saved.enabled ~= false,
        dim = Whole(saved.dim, HH.DIM_MIN, HH.DIM_MAX, HH.DEFAULT_DIM),
        border = saved.border ~= false,
        color = Choice(saved.color, HH.COLORS, "gold"),
        thickness = Whole(saved.thickness, HH.THICKNESS_MIN, HH.THICKNESS_MAX, HH.DEFAULT_THICKNESS),
        idle = Choice(saved.idle, HH.IDLE, "all"),
        combatOnly = saved.combatOnly == true,
        labels = Choice(saved.labels, HH.LABEL_STYLES, "short"),
        layers = {},
    }
    local layers = type(saved.layers) == "table" and saved.layers or {}
    for _, bar in ipairs(HH.BARS or {}) do
        local choice = Choice(layers[bar.key], HH.LAYER_CHOICES, "auto")
        if choice ~= "auto" then
            clean.layers[bar.key] = choice
        end
    end
    return clean
end

-- "ALT-SHIFT-1" -> "ALT-SHIFT", "1". "SHIFT--" -> "SHIFT", "-". "F5" ->
-- "NONE", "F5". Nil for anything that is not a key name.
function HH.SplitKey(key)
    if HH.IsSecret(key) or type(key) ~= "string" or key == "" then
        return nil
    end
    local held, rest = {}, key
    while true do
        local prefix, tail = rest:match("^(%u+)%-(.+)$")
        local modifier = prefix and MODIFIER_OF[prefix]
        if not modifier then
            break
        end
        held[modifier], rest = true, tail
    end
    local parts = {}
    for _, modifier in ipairs(HH.MODIFIER_ORDER) do
        if held[modifier] then
            parts[#parts + 1] = modifier
        end
    end
    return #parts > 0 and table.concat(parts, "-") or "NONE", rest
end

function HH.LayerLabel(layer)
    for _, entry in ipairs(HH.LAYERS) do
        if entry.key == layer then
            return entry.label
        end
    end
    return layer and (layer:gsub("%-", "+")) or "none"
end

function HH.Color()
    for _, preset in ipairs(HH.COLORS) do
        if preset.key == HH.db.color then
            return preset.color
        end
    end
    return HH.COLORS[1].color
end

-- Each part starts on its own: one that fails is reported (and handed to the
-- error handler, so BugSack shows it) and the others still start.
HH.startFailures = {}

local function Start(name, start)
    local failure
    local ok = xpcall(start, function(message)
        failure = message
        local handler = type(geterrorhandler) == "function" and geterrorhandler()
        if type(handler) == "function" then
            pcall(handler, message)
        end
        return message
    end)
    if not ok then
        HH.startFailures[#HH.startFailures + 1] = name
        HH.Report(name .. " did not start, so it stays off: " .. tostring(failure))
    end
end

-- Settings changed: everything is worked out again.
function HH.Refresh()
    if not HH.started then
        return
    end
    if HH.state.ready then
        HH.Layout()
        HH.Apply()
    end
    HH.RefreshLabels()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            HotbarHighlightDB = HH.Sanitize(HotbarHighlightDB)
            HH.db = HotbarHighlightDB
        end
        return
    end
    if not HH.db then
        HotbarHighlightDB = HH.Sanitize(HotbarHighlightDB)
        HH.db = HotbarHighlightDB
    end
    HH.started = true
    Start("Bars", HH.InitializeBars)
    Start("Key labels", HH.InitializeLabels)
    Start("Settings", HH.InitializeOptions)
end)
