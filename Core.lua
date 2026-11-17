local ADDON, HH = ...

-- Hotbar Highlight: shows which action bar the modifier keys you hold belong
-- to. The bar bound to the held modifier gets a soft glow (or a thin line)
-- around it; the other bound bars fade. Key labels on the buttons can be
-- shortened ("S1" for Shift-1), moved inside their button, resized and faded.
--
-- It only changes how things look: a bar's opacity, its own highlight
-- frames, and the buttons' key labels (text, font size, opacity, place). It
-- binds nothing, casts nothing, moves no bar or button, and sends nothing to
-- anyone.
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

-- The highlight's color is saved as "aarrggbb", the form the game's color
-- swatch setting uses. The presets are for a client without the swatch, and
-- they are what 0.1.0 saved (a preset's key), which is still understood.
HH.DEFAULT_COLOR = "ffffd100"
HH.COLORS = {
    {key = "ffffd100", label = "Gold", old = "gold"},
    {key = "ffffffff", label = "White", old = "white"},
    {key = "ff4dff73", label = "Green", old = "green"},
    {key = "ff59b3ff", label = "Blue", old = "blue"},
    {key = "ffbf80ff", label = "Purple", old = "purple"},
    {key = "ffff594d", label = "Red", old = "red"},
}

-- What the highlight goes around: the bar's whole frame, or only the
-- buttons shown on it (a bar set to fewer icons, or with empty slots hidden).
HH.AREAS = {
    {key = "bar", label = "The whole bar"},
    {key = "buttons", label = "Only the buttons shown"},
}

-- glow: a soft light around the bar that fades outward. line: a thin frame.
HH.STYLES = {
    {key = "glow", label = "Soft glow"},
    {key = "line", label = "Thin line"},
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

-- Where a key label sits in its button. "game": where the game puts it.
-- Each place: the corner or side, how the text lines up, and a small inset.
HH.LABEL_PLACES = {
    {key = "game", label = "The game's own"},
    {key = "topleft", label = "Top left", point = "TOPLEFT", justify = "LEFT", x = 2, y = -2},
    {key = "top", label = "Top", point = "TOP", justify = "CENTER", x = 0, y = -2},
    {key = "topright", label = "Top right", point = "TOPRIGHT", justify = "RIGHT", x = -2, y = -2},
    {key = "left", label = "Left", point = "LEFT", justify = "LEFT", x = 2, y = 0},
    {key = "center", label = "Center", point = "CENTER", justify = "CENTER", x = 0, y = 0},
    {key = "right", label = "Right", point = "RIGHT", justify = "RIGHT", x = -2, y = 0},
    {key = "bottomleft", label = "Bottom left", point = "BOTTOMLEFT", justify = "LEFT", x = 2, y = 2},
    {key = "bottom", label = "Bottom", point = "BOTTOM", justify = "CENTER", x = 0, y = 2},
    {key = "bottomright", label = "Bottom right", point = "BOTTOMRIGHT", justify = "RIGHT", x = -2, y = 2},
}
HH.LABEL_OFFSET_MIN, HH.LABEL_OFFSET_MAX = -20, 20
HH.LABEL_SIZE_MIN, HH.LABEL_SIZE_MAX = 50, 200
HH.LABEL_OPACITY_MIN, HH.LABEL_OPACITY_MAX = 20, 100

HH.DIM_MIN, HH.DIM_MAX, HH.DEFAULT_DIM = 10, 100, 40
HH.THICKNESS_MIN, HH.THICKNESS_MAX, HH.DEFAULT_THICKNESS = 1, 6, 2
HH.GLOW_MIN, HH.GLOW_MAX, HH.DEFAULT_GLOW = 6, 48, 18
HH.OPACITY_MIN, HH.OPACITY_MAX, HH.DEFAULT_OPACITY = 20, 100, 90
-- The inner glow's depth, in percent of a button's size.
HH.INNER_MIN, HH.INNER_MAX, HH.DEFAULT_INNER = 0, 30, 14

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

-- "aarrggbb", lower case; a 0.1.0 preset key becomes its color; anything
-- else the default.
function HH.SanitizeColor(value)
    if type(value) == "string" then
        local hex = value:lower()
        if hex:match("^%x%x%x%x%x%x%x%x$") then
            return hex
        end
        for _, preset in ipairs(HH.COLORS) do
            if preset.old == hex then
                return preset.key
            end
        end
    end
    return HH.DEFAULT_COLOR
end

-- The saved settings, rebuilt: only known keys with valid values survive.
function HH.Sanitize(saved)
    saved = type(saved) == "table" and saved or {}
    local clean = {
        enabled = saved.enabled ~= false,
        dim = Whole(saved.dim, HH.DIM_MIN, HH.DIM_MAX, HH.DEFAULT_DIM),
        border = saved.border ~= false,
        style = Choice(saved.style, HH.STYLES, "glow"),
        area = Choice(saved.area, HH.AREAS, "bar"),
        color = HH.SanitizeColor(saved.color),
        opacity = Whole(saved.opacity, HH.OPACITY_MIN, HH.OPACITY_MAX, HH.DEFAULT_OPACITY),
        glow = Whole(saved.glow, HH.GLOW_MIN, HH.GLOW_MAX, HH.DEFAULT_GLOW),
        inner = Whole(saved.inner, HH.INNER_MIN, HH.INNER_MAX, HH.DEFAULT_INNER),
        thickness = Whole(saved.thickness, HH.THICKNESS_MIN, HH.THICKNESS_MAX, HH.DEFAULT_THICKNESS),
        idle = Choice(saved.idle, HH.IDLE, "all"),
        combatOnly = saved.combatOnly == true,
        labels = Choice(saved.labels, HH.LABEL_STYLES, "short"),
        labelPlace = Choice(saved.labelPlace, HH.LABEL_PLACES, "game"),
        labelX = Whole(saved.labelX, HH.LABEL_OFFSET_MIN, HH.LABEL_OFFSET_MAX, 0),
        labelY = Whole(saved.labelY, HH.LABEL_OFFSET_MIN, HH.LABEL_OFFSET_MAX, 0),
        labelSize = Whole(saved.labelSize, HH.LABEL_SIZE_MIN, HH.LABEL_SIZE_MAX, 100),
        labelOpacity = Whole(saved.labelOpacity, HH.LABEL_OPACITY_MIN, HH.LABEL_OPACITY_MAX, 100),
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

-- The highlight's red, green, blue (0-1) and its opacity (0-1).
function HH.Color()
    local hex = HH.SanitizeColor(HH.db.color)
    return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255,
        HH.db.opacity / 100
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
