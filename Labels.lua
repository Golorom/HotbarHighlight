local _, HH = ...

-- Key labels on the bar buttons.
--
-- The game writes a button's key as "s-1", "c-1", "a-s-1". Styles:
--   short     "S1", "C1", "AS1": one letter per modifier, then the key
--   key       "1": the key alone; the highlighted bar says which layer
--   blizzard  the game's own text, untouched
--
-- A label is the button's HotKey font string. The game rewrites it whenever
-- bindings or the button change, so each label's SetText is hooked
-- (hooksecurefunc: the game's call runs first, untouched) and the short text
-- is written right after. Only the text changes: no font, size, color or
-- place, so the range coloring and other addons' styling stay.
--
-- A button with no key keeps the game's text (its range dot).

local MODIFIER_LETTER = {ALT = "A", CTRL = "C", SHIFT = "S", META = "M"}

-- Long key names, shortened. Anything not listed shows as the game names it.
local KEY_NAMES = {
    SPACE = "Sp", ESCAPE = "Esc", BACKSPACE = "BS", DELETE = "Del", INSERT = "Ins", HOME = "Hm", END = "End",
    PAGEUP = "PU", PAGEDOWN = "PD", TAB = "Tab", CAPSLOCK = "Cap", ENTER = "Ent", NUMLOCK = "NL",
    UP = "Up", DOWN = "Dn", LEFT = "Lt", RIGHT = "Rt",
    MOUSEWHEELUP = "WU", MOUSEWHEELDOWN = "WD",
    NUMPADPLUS = "N+", NUMPADMINUS = "N-", NUMPADMULTIPLY = "N*", NUMPADDIVIDE = "N/", NUMPADDECIMAL = "N.",
    BUTTON1 = "LM", BUTTON2 = "RM", BUTTON3 = "MM",
}

-- label (font string) -> {command, button}
local labels = {}
local touched = {}
local writing = false
-- Set once the part has started; until then nothing is hooked or written.
local ready = false

local function ShortName(key)
    local known = KEY_NAMES[key]
    if known then
        return known
    end
    local pad = key:match("^NUMPAD(%d)$")
    if pad then
        return "N" .. pad
    end
    local mouse = key:match("^BUTTON(%d+)$")
    if mouse then
        return "M" .. mouse
    end
    return key
end

-- "ALT-SHIFT-1" -> "AS1" (short) or "1" (key). Nil for no key.
function HH.ShortKey(key, style)
    local layer, plain = HH.SplitKey(key)
    if not layer then
        return nil
    end
    local name = ShortName(plain)
    if style == "key" or layer == "NONE" then
        return name
    end
    local letters = {}
    for _, modifier in ipairs(HH.MODIFIER_ORDER) do
        if layer:find(modifier, 1, true) then
            letters[#letters + 1] = MODIFIER_LETTER[modifier]
        end
    end
    return table.concat(letters) .. name
end

local function FirstKey(command)
    local key = GetBindingKey(command)
    if HH.IsSecret(key) or type(key) ~= "string" or key == "" then
        return nil
    end
    return key
end

local function Write(label, text)
    writing = true
    local ok, failure = pcall(label.SetText, label, text)
    writing = false
    if not ok then
        error(failure, 0)
    end
end

local function Shorten(label)
    local info = labels[label]
    local style = HH.db and HH.db.labels
    if not info or not style or style == "blizzard" or not HH.db.enabled then
        return
    end
    local key = FirstKey(info.command)
    local text = key and HH.ShortKey(key, style)
    if not text then
        return
    end
    local current = label:GetText()
    if HH.IsSecret(current) or current ~= text then
        Write(label, text)
        touched[label] = true
    end
end

-- The game's own text for a key, for a label this addon changed.
local function Restore(label)
    if not touched[label] then
        return
    end
    touched[label] = nil
    local key = FirstKey(labels[label].command)
    if key and type(GetBindingText) == "function" then
        local text = GetBindingText(key, 1)
        if not HH.IsSecret(text) and type(text) == "string" then
            Write(label, text)
        end
    end
end

local function Track(entry)
    local button = entry.button
    local label = button.HotKey or _G[entry.name .. "HotKey"]
    if type(label) ~= "table" or type(label.SetText) ~= "function" or type(label.GetText) ~= "function" then
        return
    end
    if not labels[label] then
        labels[label] = {command = entry.command, name = entry.name}
        hooksecurefunc(label, "SetText", function(self)
            if not writing then
                Shorten(self)
            end
        end)
    end
end

function HH.RefreshLabels()
    if not ready then
        return
    end
    for _, def in ipairs(HH.BARS) do
        for _, entry in ipairs(HH.BarButtons(def)) do
            Track(entry)
        end
    end
    local plain = not HH.db.enabled or HH.db.labels == "blizzard"
    for label in pairs(labels) do
        if plain then
            Restore(label)
        else
            Shorten(label)
        end
    end
end

function HH.LabelCount()
    local tracked, changed = 0, 0
    for label in pairs(labels) do
        tracked = tracked + 1
        if touched[label] then
            changed = changed + 1
        end
    end
    return tracked, changed
end

function HH.InitializeLabels()
    if type(hooksecurefunc) ~= "function" then
        error("hooksecurefunc is missing on this client", 0)
    end
    ready = true
    HH.RefreshLabels()
    local frame = CreateFrame("Frame")
    for _, event in ipairs({"UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD"}) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function()
        -- After the game's own handlers for this event have written theirs.
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(0, HH.RefreshLabels)
        else
            HH.RefreshLabels()
        end
    end)
end
