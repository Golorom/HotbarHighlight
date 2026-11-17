local _, HH = ...

-- Key labels on the bar buttons: their text and their look.
--
-- Text. The game writes a button's key as "s-1", "c-1", "a-s-1". Styles:
--   short     "S1", "C1", "AS1": one letter per modifier, then the key
--   key       "1": the key alone; the highlighted bar says which layer
--   blizzard  the game's own text, untouched
--
-- Look (0.3.0): where the label sits in its button (a corner, a side, the
-- center, with offsets), its size in percent, and its opacity.
--
-- A label is the button's HotKey font string. Whatever look it has from the
-- game, or from another addon, is its base; this addon's settings go on top:
--   size      the base font at the set percent
--   opacity   the base opacity times the set percent
--   place     the label's anchors, in place of the base ones
-- The base is read once and then kept up to date by hooks (hooksecurefunc:
-- the caller's own call runs first, untouched): when anything else sets the
-- label's text, font, anchors or size, the hook notes the new base and puts
-- this addon's settings back on top. So another addon that sizes or places
-- the same labels is not fought: its result is the base. A flag marks this
-- addon's own writes so the hooks do not answer them.
--
-- Anchors and sizes of a label change only out of combat; a change asked for
-- in combat waits for its end. Text, font and opacity change at any time.
--
-- With every look setting at its default nothing but the text is touched,
-- and a button with no key keeps the game's text (its range dot).

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

-- label (font string) -> {command, name, button, own (its base look), and
-- what this addon changed: touched (text), sized, faded, placed}
local labels = {}
local writing = false
-- Set once the part has started; until then nothing is hooked or written.
local ready = false
-- Anchors wait: for combat's end, or for the caller that is re-anchoring a
-- label to finish (the next frame).
local pendingPlace, scheduled = false, false

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

-- This addon's own write to a label: the hooks stay quiet during it.
local function Write(run)
    writing = true
    local ok, failure = pcall(run)
    writing = false
    if not ok then
        error(failure, 0)
    end
end

local function Has(label, ...)
    for index = 1, select("#", ...) do
        if type(label[select(index, ...)]) ~= "function" then
            return false
        end
    end
    return true
end

local function Number(value)
    return not HH.IsSecret(value) and type(value) == "number"
end

-- Text ----------------------------------------------------------------------------

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
        Write(function() label:SetText(text) end)
        info.touched = true
    end
end

-- The game's own text for a key, for a label this addon changed.
local function RestoreText(label)
    local info = labels[label]
    if not info.touched then
        return
    end
    info.touched = nil
    local key = FirstKey(info.command)
    if key and type(GetBindingText) == "function" then
        local text = GetBindingText(key, 1)
        if not HH.IsSecret(text) and type(text) == "string" then
            Write(function() label:SetText(text) end)
        end
    end
end

-- Look ----------------------------------------------------------------------------

local function PlaceSpec()
    for _, place in ipairs(HH.LABEL_PLACES) do
        if place.key == HH.db.labelPlace then
            return place.point and place or nil
        end
    end
end

-- The label's base look, read once. Each part only where the label has the
-- functions for it.
local function ReadOwn(label)
    local own = {}
    if Has(label, "GetFont", "SetFont") then
        local font, size, flags = label:GetFont()
        if type(font) == "string" and Number(size) and size > 0 then
            own.font, own.size, own.flags = font, size, flags
        end
    end
    if Has(label, "GetAlpha", "SetAlpha") then
        local alpha = label:GetAlpha()
        own.alpha = Number(alpha) and alpha or 1
    end
    if Has(label, "GetNumPoints", "GetPoint", "SetPoint", "ClearAllPoints") then
        own.points = {}
        for index = 1, label:GetNumPoints() do
            own.points[index] = {label:GetPoint(index)}
        end
        if Has(label, "GetJustifyH", "SetJustifyH") then
            own.justify = label:GetJustifyH()
        end
        if Has(label, "GetWidth", "GetHeight", "SetWidth", "SetHeight") then
            local width, height = label:GetWidth(), label:GetHeight()
            own.width, own.height = Number(width) and width or nil, Number(height) and height or nil
        end
    end
    return own
end

local function ApplyFont(label, info)
    local own = info.own
    local percent = HH.db.enabled and HH.db.labelSize or 100
    if not own.font or (percent == 100 and not info.sized) then
        return
    end
    Write(function() label:SetFont(own.font, own.size * percent / 100, own.flags) end)
    info.sized = percent ~= 100 or nil
end

local function ApplyAlpha(label, info)
    local own = info.own
    local percent = HH.db.enabled and HH.db.labelOpacity or 100
    if not own.alpha or (percent == 100 and not info.faded) then
        return
    end
    Write(function() label:SetAlpha(own.alpha * percent / 100) end)
    info.faded = percent ~= 100 or nil
end

local function PutOwnPoints(label, own)
    label:ClearAllPoints()
    for _, point in ipairs(own.points) do
        label:SetPoint(unpack(point, 1, 5))
    end
    if own.justify then
        label:SetJustifyH(own.justify)
    end
end

-- The label's anchors, justification and box. Out of combat only.
local function ApplyPlace(label, info)
    local own = info.own
    if not own.points then
        return
    end
    local spec = HH.db.enabled and PlaceSpec() or nil
    local percent = HH.db.enabled and HH.db.labelSize or 100
    if not spec and percent == 100 then
        if info.placed then
            Write(function()
                PutOwnPoints(label, own)
                if own.width and own.height then
                    label:SetWidth(own.width)
                    label:SetHeight(own.height)
                end
            end)
            info.placed = nil
        end
        return
    end
    local button = info.button
    Write(function()
        if spec then
            label:ClearAllPoints()
            label:SetPoint(spec.point, button, spec.point, spec.x + HH.db.labelX, spec.y + HH.db.labelY)
            if own.justify then
                label:SetJustifyH(spec.justify)
            end
        else
            PutOwnPoints(label, own)
        end
        -- Room for a bigger or longer text: the button's width, and the base
        -- height grown with the font.
        if own.width and own.height then
            local width = type(button.GetWidth) == "function" and button:GetWidth()
            label:SetWidth(math.max(own.width, Number(width) and width or 0))
            if own.height > 0 then
                label:SetHeight(own.height * math.max(1, percent / 100))
            end
        end
    end)
    info.placed = true
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function PlaceAll()
    if InCombat() then
        pendingPlace = true
        return
    end
    pendingPlace = false
    for label, info in pairs(labels) do
        ApplyPlace(label, info)
    end
end

-- Anchors again on the next frame: a caller that re-anchors a label does it
-- in several calls, and this must come after the last of them.
local function SchedulePlace()
    if scheduled then
        return
    end
    scheduled = true
    local function Run()
        scheduled = false
        PlaceAll()
    end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, Run)
    else
        Run()
    end
end

-- Hooks ---------------------------------------------------------------------------

local function Hook(label, method, after)
    if type(label[method]) == "function" then
        hooksecurefunc(label, method, function(self, ...)
            if not writing and ready then
                after(self, labels[self], ...)
            end
        end)
    end
end

local function Track(entry)
    local button = entry.button
    local label = button.HotKey or _G[entry.name .. "HotKey"]
    if type(label) ~= "table" or type(label.SetText) ~= "function" or type(label.GetText) ~= "function" then
        return
    end
    if labels[label] then
        return
    end
    local info = {command = entry.command, name = entry.name, button = button, own = ReadOwn(label)}
    labels[label] = info
    Hook(label, "SetText", function(self) Shorten(self) end)
    -- Someone else's look for this label is its new base.
    Hook(label, "SetFont", function(self, known, font, size, flags)
        if known.own.font and type(font) == "string" and Number(size) and size > 0 then
            known.own.font, known.own.size, known.own.flags = font, size, flags
            known.sized = nil
            ApplyFont(self, known)
        end
    end)
    Hook(label, "SetAlpha", function(self, known, alpha)
        if known.own.alpha and Number(alpha) then
            known.own.alpha = alpha
            known.faded = nil
            ApplyAlpha(self, known)
        end
    end)
    Hook(label, "ClearAllPoints", function(_, known)
        if known.own.points then
            known.own.points = {}
            known.placed = nil
            SchedulePlace()
        end
    end)
    Hook(label, "SetPoint", function(_, known, ...)
        if known.own.points then
            known.own.points[#known.own.points + 1] = {...}
            known.placed = nil
            SchedulePlace()
        end
    end)
    Hook(label, "SetJustifyH", function(_, known, justify)
        if known.own.points and known.own.justify then
            known.own.justify = justify
            SchedulePlace()
        end
    end)
    local function Sized(self, known)
        if known.own.width then
            local width, height = self:GetWidth(), self:GetHeight()
            known.own.width, known.own.height = Number(width) and width or known.own.width,
                Number(height) and height or known.own.height
            SchedulePlace()
        end
    end
    Hook(label, "SetWidth", Sized)
    Hook(label, "SetHeight", Sized)
    Hook(label, "SetSize", Sized)
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
    for label, info in pairs(labels) do
        if plain then
            RestoreText(label)
        else
            Shorten(label)
        end
        ApplyFont(label, info)
        ApplyAlpha(label, info)
    end
    PlaceAll()
end

-- How many labels were found, how many have a shortened text, how many a
-- changed look, and whether anchors wait for combat's end.
function HH.LabelCount()
    local tracked, changed, looked = 0, 0, 0
    for _, info in pairs(labels) do
        tracked = tracked + 1
        if info.touched then
            changed = changed + 1
        end
        if info.sized or info.faded or info.placed then
            looked = looked + 1
        end
    end
    return tracked, changed, looked, pendingPlace
end

function HH.InitializeLabels()
    if type(hooksecurefunc) ~= "function" then
        error("hooksecurefunc is missing on this client", 0)
    end
    ready = true
    HH.RefreshLabels()
    local frame = CreateFrame("Frame")
    for _, event in ipairs({"UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            -- Anchors that waited for the fight's end.
            if pendingPlace then
                PlaceAll()
            end
            return
        end
        -- After the game's own handlers for this event have written theirs.
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(0, HH.RefreshLabels)
        else
            HH.RefreshLabels()
        end
    end)
end
