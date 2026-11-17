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
--   offsets   added to the place, or to the base anchors with no place set
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
-- Each label is moved on its own: one that refuses does not stop the rest,
-- and /hh status says how many refused and why.
--
-- Pet and stance bar (1.1.0). Their buttons are of another template than the
-- action bars': the key label sits elsewhere, and Edit Mode's Icon Size
-- scales the whole button, its label too, so the labels come out bigger or
-- smaller than the action bars'. With the match setting on, each of these
-- labels takes the base look of an action bar's label (the first button of
-- Action Bar 1, 2 or 3): its font, anchors, justification and box, all
-- divided by how much bigger the small bar's button is drawn, so on screen
-- it has the same size and sits at the same distance from the corner. The
-- other look settings go on top of that as on every bar.
--
-- With every look setting at its default nothing but the text is touched on
-- the action bars, and a button with no key keeps the game's text (its
-- range dot).

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

-- label (font string) -> {command, name, button, small (pet or stance bar),
-- own (its base look), and what this addon changed: touched (text), sized,
-- faded, placed}
local labels = {}
-- button name -> label, for the labels the small bars are matched to.
local byName = {}
local REFERENCES = {"ActionButton1", "MultiBarBottomLeftButton1", "MultiBarBottomRightButton1"}
local writing = false
-- Set once the part has started; until then nothing is hooked or written.
local ready = false
-- Anchors wait: for combat's end, or for the caller that is re-anchoring a
-- label to finish (the next frame).
local pendingPlace, scheduled = false, false
-- Labels that refused their place the last time, and the first reason.
local refused = {count = 0, reason = nil, told = false}

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

local function Scale(frame)
    local scale = type(frame) == "table" and type(frame.GetEffectiveScale) == "function"
        and frame:GetEffectiveScale()
    return Number(scale) and scale > 0 and scale or nil
end

-- For a pet or stance bar label with the match setting on: the action bar
-- label it takes its look from, and how many of its own units make one of
-- that label's units on screen. Nil: the label keeps its own base.
local function Match(info)
    if not info.small or not HH.db.enabled or not HH.db.labelMatch then
        return nil
    end
    local scale = Scale(info.button)
    if not scale then
        return nil
    end
    for _, name in ipairs(REFERENCES) do
        local known = byName[name] and labels[byName[name]]
        local base = known and Scale(known.button)
        if base and known.own.font then
            return known, base / scale
        end
    end
end

local function ApplyFont(label, info)
    local own = info.own
    if not own.font then
        return
    end
    local percent = HH.db.enabled and HH.db.labelSize or 100
    local font, size, flags = own.font, own.size, own.flags
    local like, factor = Match(info)
    if like then
        font, size, flags = like.own.font, like.own.size * factor, like.own.flags
    end
    size = size * percent / 100
    local changed = like ~= nil or percent ~= 100
    if not changed and not info.sized then
        return
    end
    -- The same font again is not written again: this runs on every refresh.
    local wrote = info.wrote
    if not (wrote and wrote[1] == font and wrote[2] == size and wrote[3] == flags) then
        Write(function() label:SetFont(font, size, flags) end)
    end
    info.wrote = changed and {font, size, flags} or nil
    info.sized = changed or nil
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

local function ReadPoints(label)
    local points = {}
    for index = 1, label:GetNumPoints() do
        points[index] = {label:GetPoint(index)}
    end
    return points
end

-- The base anchors, moved by the offsets. An anchor with no frame named is
-- on the label's parent.
local function PutOwnPoints(label, info, dx, dy)
    local own = info.own
    local parent = type(label.GetParent) == "function" and label:GetParent() or info.button
    label:ClearAllPoints()
    for _, point in ipairs(own.points) do
        local x, y = point[4], point[5]
        label:SetPoint(point[1], point[2] or parent, point[3] or point[1], (Number(x) and x or 0) + (dx or 0),
            (Number(y) and y or 0) + (dy or 0))
    end
    if own.justify then
        label:SetJustifyH(own.justify)
    end
end

-- Another label's base anchors, on this label's button: an anchor on that
-- label's button (or on no frame, its parent) moves to this one; its
-- offsets, and this addon's, in this button's units.
local function PutPointsLike(label, info, like, factor, dx, dy)
    label:ClearAllPoints()
    for _, point in ipairs(like.own.points) do
        local onButton = point[2] == nil or point[2] == like.button
        local x, y = point[4], point[5]
        label:SetPoint(point[1], onButton and info.button or point[2], point[3] or point[1],
            ((Number(x) and x or 0) + dx) * factor, ((Number(y) and y or 0) + dy) * factor)
    end
    if info.own.justify and like.own.justify then
        label:SetJustifyH(like.own.justify)
    end
end

-- The label's anchors, justification and box. Out of combat only.
local function ApplyPlace(label, info)
    local own = info.own
    if not own.points then
        return
    end
    if info.dirty then
        -- Someone else anchored it since: what it has now is its base.
        info.dirty = nil
        own.points = ReadPoints(label)
    end
    local on = HH.db.enabled
    local spec = on and PlaceSpec() or nil
    local percent = on and HH.db.labelSize or 100
    local dx, dy = on and HH.db.labelX or 0, on and HH.db.labelY or 0
    local like, factor = Match(info)
    if like and not like.own.points then
        like = nil
    end
    factor = like and factor or 1
    if not spec and percent == 100 and dx == 0 and dy == 0 and not like then
        if info.placed then
            Write(function()
                PutOwnPoints(label, info)
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
            label:SetPoint(spec.point, button, spec.point, (spec.x + dx) * factor, (spec.y + dy) * factor)
            if own.justify then
                label:SetJustifyH(spec.justify)
            end
        elseif like then
            -- An action bar label's place, on this button.
            PutPointsLike(label, info, like, factor, dx, dy)
        else
            -- The game's own place, moved by the offsets.
            PutOwnPoints(label, info, dx, dy)
        end
        -- Room for a bigger or longer text: the button's width, and the base
        -- height grown with the font. A matched label has the other's box.
        if own.width and own.height then
            local baseWidth, baseHeight = own.width, own.height
            if like and like.own.width and like.own.height then
                baseWidth, baseHeight = like.own.width * factor, like.own.height * factor
            end
            local width = type(button.GetWidth) == "function" and button:GetWidth()
            label:SetWidth(math.max(baseWidth, Number(width) and width or 0))
            if baseHeight > 0 then
                label:SetHeight(baseHeight * math.max(1, percent / 100))
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
    -- A label that someone else anchored since: what it has now is its
    -- base. Read ahead of the loop, as a matched label uses another's base.
    for label, info in pairs(labels) do
        if info.dirty and info.own.points then
            local ok, points = pcall(ReadPoints, label)
            if ok then
                info.dirty, info.own.points = nil, points
            end
        end
    end
    local count, reason = 0, nil
    for label, info in pairs(labels) do
        local ok, failure = pcall(ApplyPlace, label, info)
        if not ok then
            count = count + 1
            reason = reason or (info.name .. ": " .. tostring(failure))
        end
    end
    refused.count, refused.reason = count, reason
    if count > 0 and not refused.told then
        -- Once a session, in chat; /hh status has it every time.
        refused.told = true
        HH.Report(string.format("%d key labels could not be moved. First: %s", count, reason))
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
    local info = {command = entry.command, name = entry.name, button = button, small = entry.small,
        own = ReadOwn(label)}
    labels[label] = info
    byName[entry.name] = label
    Hook(label, "SetText", function(self) Shorten(self) end)
    -- Someone else's look for this label is its new base.
    Hook(label, "SetFont", function(self, known, font, size, flags)
        if known.own.font and type(font) == "string" and Number(size) and size > 0 then
            known.own.font, known.own.size, known.own.flags = font, size, flags
            known.sized, known.wrote = nil, nil
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
    -- Anchored by someone else: its anchors are read again on the next
    -- frame, once the caller is done, and are the base from then on.
    local function Anchored(_, known)
        if known.own.points then
            known.dirty, known.placed = true, nil
            SchedulePlace()
        end
    end
    Hook(label, "ClearAllPoints", Anchored)
    Hook(label, "SetPoint", Anchored)
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
    return tracked, changed, looked, pendingPlace, refused.count, refused.reason
end

function HH.InitializeLabels()
    if type(hooksecurefunc) ~= "function" then
        error("hooksecurefunc is missing on this client", 0)
    end
    ready = true
    HH.RefreshLabels()
    local frame = CreateFrame("Frame")
    -- The last four: a bar's size can change (Edit Mode, the UI scale), and
    -- the game redraws the pet bar's buttons.
    for _, event in ipairs({"UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
            "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PET_BAR_UPDATE"}) do
        pcall(frame.RegisterEvent, frame, event)
    end
    -- After the game's own handlers for an event have written theirs; several
    -- events in one frame make one refresh.
    local queued = false
    local function Later()
        if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
            HH.RefreshLabels()
        elseif not queued then
            queued = true
            C_Timer.After(0, function()
                queued = false
                HH.RefreshLabels()
            end)
        end
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            -- Anchors that waited for the fight's end.
            if pendingPlace then
                PlaceAll()
            end
            return
        end
        Later()
    end)
    -- Leaving Edit Mode: a bar's Icon Size may have changed.
    local manager = rawget(_G, "EditModeManagerFrame")
    if type(manager) == "table" and type(manager.HookScript) == "function" then
        manager:HookScript("OnHide", Later)
    end
end
