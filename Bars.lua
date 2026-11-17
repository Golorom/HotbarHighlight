local _, HH = ...

-- Which bar belongs to which layer, and the highlight.
--
-- A bar's layer is read from the keys bound to its buttons: the modifiers
-- most of them share. A bar whose buttons are bound to Shift-1 ... Shift-=
-- is the Shift layer; a bar with no keys has no layer and is left alone. A
-- bar's setting can fix the layer or leave the bar out.
--
-- While you hold a layer's modifiers and some bar has that layer:
--   that bar      full opacity, and a soft glow (or a thin line) around it
--   other layers  faded to the "other bars" opacity
--   no layer      untouched
-- With no modifier held nothing changes, unless "Highlight the bar with no
-- modifier" is chosen. Holding modifiers that no bar uses changes nothing
-- (Alt as a self-cast key, Shift while you type).
--
-- What it touches: SetAlpha on the game's bar frames (allowed in combat; the
-- bar's own opacity is put back when the fade ends) and its own border
-- frames, which are children of UIParent, not of the bar, so the game's bar
-- layout never sees them.

-- frames: the bar's frame, by the names different client builds use.
-- button: the buttons' global names. command: their key binding commands.
HH.BARS = {
    {key = "bar1", label = "Action Bar 1", frames = {"MainActionBar", "MainMenuBar"}, button = "ActionButton%d",
        command = "ACTIONBUTTON%d", count = 12},
    {key = "bar2", label = "Action Bar 2", frames = {"MultiBarBottomLeft"}, button = "MultiBarBottomLeftButton%d",
        command = "MULTIACTIONBAR1BUTTON%d", count = 12},
    {key = "bar3", label = "Action Bar 3", frames = {"MultiBarBottomRight"}, button = "MultiBarBottomRightButton%d",
        command = "MULTIACTIONBAR2BUTTON%d", count = 12},
    {key = "bar4", label = "Action Bar 4", frames = {"MultiBarRight"}, button = "MultiBarRightButton%d",
        command = "MULTIACTIONBAR3BUTTON%d", count = 12},
    {key = "bar5", label = "Action Bar 5", frames = {"MultiBarLeft"}, button = "MultiBarLeftButton%d",
        command = "MULTIACTIONBAR4BUTTON%d", count = 12},
    {key = "bar6", label = "Action Bar 6", frames = {"MultiBar5"}, button = "MultiBar5Button%d",
        command = "MULTIACTIONBAR5BUTTON%d", count = 12},
    {key = "bar7", label = "Action Bar 7", frames = {"MultiBar6"}, button = "MultiBar6Button%d",
        command = "MULTIACTIONBAR6BUTTON%d", count = 12},
    {key = "bar8", label = "Action Bar 8", frames = {"MultiBar7"}, button = "MultiBar7Button%d",
        command = "MULTIACTIONBAR7BUTTON%d", count = 12},
    {key = "pet", label = "Pet Bar", frames = {"PetActionBar", "PetActionBarFrame"}, button = "PetActionButton%d",
        command = "BONUSACTIONBUTTON%d", count = 10},
    {key = "stance", label = "Stance Bar", frames = {"StanceBar", "StanceBarFrame"}, button = "StanceButton%d",
        command = "SHAPESHIFTBUTTON%d", count = 10},
}

local BORDER_PADDING = 3
-- The glow starts at the bar's own edge.
local GLOW_PADDING = 0
-- How often a held modifier is checked again, in case its release was never
-- reported (the game window lost focus while it was down).
local RECHECK = 0.2

local state = {bars = {}, held = "NONE", active = false}
HH.state = state

local watcher

local function FirstFrame(names)
    for _, name in ipairs(names) do
        local frame = _G[name]
        if type(frame) == "table" and type(frame.SetAlpha) == "function" and type(frame.GetAlpha) == "function" then
            return frame, name
        end
    end
end

local function Buttons(def)
    local found = {}
    for index = 1, def.count do
        local name = def.button:format(index)
        local button = _G[name]
        if type(button) == "table" then
            found[#found + 1] = {index = index, name = name, button = button, command = def.command:format(index)}
        end
    end
    return found
end
HH.BarButtons = Buttons

-- The layer most of the bar's bound buttons share, and how many buttons
-- have a key. A tie goes to the layer earlier in HH.LAYERS. Nil: no keys.
local function DetectLayer(buttons)
    local counts, bound = {}, 0
    for _, entry in ipairs(buttons) do
        local seen = {}
        for _, key in ipairs({GetBindingKey(entry.command)}) do
            local layer = HH.SplitKey(key)
            if layer and not seen[layer] then
                seen[layer] = true
                counts[layer] = (counts[layer] or 0) + 1
            end
        end
        if next(seen) then
            bound = bound + 1
        end
    end
    local best, bestCount
    local function Consider(layer)
        local count = counts[layer]
        if count and (not bestCount or count > bestCount) then
            best, bestCount = layer, count
        end
        counts[layer] = nil
    end
    for _, layer in ipairs(HH.LAYERS) do
        Consider(layer.key)
    end
    -- Layers not in the list (META), in a fixed order.
    local others = {}
    for layer in pairs(counts) do
        others[#others + 1] = layer
    end
    table.sort(others)
    for _, layer in ipairs(others) do
        Consider(layer)
    end
    return best, bound
end

local EDGES = {
    {"TOPLEFT", "TOPRIGHT", true},
    {"BOTTOMLEFT", "BOTTOMRIGHT", true},
    {"TOPLEFT", "BOTTOMLEFT", false},
    {"TOPRIGHT", "BOTTOMRIGHT", false},
}

local function MakeBorder(entry)
    local border = CreateFrame("Frame", nil, UIParent)
    border:SetFrameStrata("MEDIUM")
    border:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", -BORDER_PADDING, BORDER_PADDING)
    border:SetPoint("BOTTOMRIGHT", entry.frame, "BOTTOMRIGHT", BORDER_PADDING, -BORDER_PADDING)
    border.edges = {}
    for index, edge in ipairs(EDGES) do
        local texture = border:CreateTexture(nil, "OVERLAY")
        texture:SetPoint(edge[1], border, edge[1], 0, 0)
        texture:SetPoint(edge[2], border, edge[2], 0, 0)
        border.edges[index] = {texture = texture, horizontal = edge[3]}
    end
    border.anchor = entry.frame
    border:Hide()
    return border
end

-- The soft glow: eight pieces outside the bar's edges, four sides and four
-- corners, each a white texture whose opacity falls off away from the bar
-- (Textures\Glow*.tga), tinted with the color. One file per piece, so no
-- piece depends on turning a texture around.
--   {file, the piece's point, the frame's point it sits on, second pair for
--    a side (it stretches along the bar), which size it takes}
local GLOW_PIECES = {
    {"GlowTop", "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", "height"},
    {"GlowBottom", "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", "height"},
    {"GlowLeft", "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "width"},
    {"GlowRight", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "width"},
    {"GlowTopLeft", "BOTTOMRIGHT", "TOPLEFT"},
    {"GlowTopRight", "BOTTOMLEFT", "TOPRIGHT"},
    {"GlowBottomLeft", "TOPRIGHT", "BOTTOMLEFT"},
    {"GlowBottomRight", "TOPLEFT", "BOTTOMRIGHT"},
}

local function MakeGlow(entry)
    local glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata("MEDIUM")
    glow:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", -GLOW_PADDING, GLOW_PADDING)
    glow:SetPoint("BOTTOMRIGHT", entry.frame, "BOTTOMRIGHT", GLOW_PADDING, -GLOW_PADDING)
    glow.pieces = {}
    local folder = "Interface\\AddOns\\" .. HH.ADDON .. "\\Textures\\"
    for index, piece in ipairs(GLOW_PIECES) do
        local texture = glow:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(folder .. piece[1])
        texture:SetPoint(piece[2], glow, piece[3], 0, 0)
        if piece[4] then
            texture:SetPoint(piece[4], glow, piece[5], 0, 0)
        end
        glow.pieces[index] = {texture = texture, size = piece[6]}
    end
    glow.anchor = entry.frame
    glow:Hide()
    return glow
end

-- Each bar's frame, buttons and layer, worked out again: at login, when key
-- bindings change, and when a setting changes.
function HH.Layout()
    for _, def in ipairs(HH.BARS) do
        local entry = state.bars[def.key]
        if not entry then
            entry = {def = def}
            state.bars[def.key] = entry
        end
        local frame, name = FirstFrame(def.frames)
        if frame ~= entry.frame and entry.dimmed and entry.frame then
            entry.frame:SetAlpha(entry.restore or 1)
            entry.dimmed = false
        end
        entry.frame, entry.frameName = frame, name
        entry.buttons = Buttons(def)
        entry.auto, entry.bound = DetectLayer(entry.buttons)
        entry.choice = HH.db.layers[def.key] or "auto"
        if entry.choice == "ignore" then
            entry.layer = nil
        elseif entry.choice == "auto" then
            entry.layer = entry.auto
        else
            entry.layer = entry.choice
        end
        -- The border is made here, ahead of its first use, so that it is
        -- normally made outside combat. A bar with no layer never needs one.
        if frame and entry.layer and (not entry.border or entry.border.anchor ~= frame) then
            if entry.border then
                entry.border:Hide()
                entry.glow:Hide()
            end
            entry.border = MakeBorder(entry)
            entry.glow = MakeGlow(entry)
        end
        if frame and not entry.hooked and type(frame.HookScript) == "function" then
            -- The border follows the bar when the game shows or hides it.
            entry.hooked = true
            pcall(frame.HookScript, frame, "OnShow", function() HH.Apply() end)
            pcall(frame.HookScript, frame, "OnHide", function() HH.Apply() end)
        end
    end
end

local function Down(check)
    if type(check) ~= "function" then
        return false
    end
    local down = check()
    return not HH.IsSecret(down) and (down == true or down == 1)
end

-- The layer of the modifiers held now. While you type in an edit box
-- nothing counts as held: Shift for a capital letter is not a layer.
function HH.Held()
    if type(GetCurrentKeyBoardFocus) == "function" and GetCurrentKeyBoardFocus() ~= nil then
        return "NONE"
    end
    local parts = {}
    if Down(IsAltKeyDown) then
        parts[#parts + 1] = "ALT"
    end
    if Down(IsControlKeyDown) then
        parts[#parts + 1] = "CTRL"
    end
    if Down(IsShiftKeyDown) then
        parts[#parts + 1] = "SHIFT"
    end
    if Down(rawget(_G, "IsMetaKeyDown")) then
        parts[#parts + 1] = "META"
    end
    return #parts > 0 and table.concat(parts, "-") or "NONE"
end

local function EditModeOpen()
    local manager = rawget(_G, "EditModeManagerFrame")
    return type(manager) == "table" and type(manager.IsShown) == "function" and manager:IsShown() == true
end

local function Fade(entry, on)
    local frame = entry.frame
    if on then
        if not entry.dimmed then
            local own = frame:GetAlpha()
            entry.restore = (not HH.IsSecret(own) and type(own) == "number") and own or 1
            entry.dimmed = true
        end
        frame:SetAlpha(HH.db.dim / 100)
    elseif entry.dimmed then
        frame:SetAlpha(entry.restore or 1)
        entry.dimmed = false
    end
end

-- The highlight around a bar: the soft glow or the thin line, in the color
-- and opacity set.
local function Border(entry, on)
    if on and entry.border and entry.border.anchor ~= entry.frame then
        -- The bar's frame changed (another client build's name): start over.
        entry.border:Hide()
        entry.glow:Hide()
        entry.border, entry.glow = nil, nil
    end
    if not on then
        if entry.border then
            entry.border:Hide()
            entry.glow:Hide()
        end
        return
    end
    if not entry.border then
        entry.border = MakeBorder(entry)
        entry.glow = MakeGlow(entry)
    end
    local r, g, b, alpha = HH.Color()
    if HH.db.style == "line" then
        for _, edge in ipairs(entry.border.edges) do
            edge.texture:SetColorTexture(r, g, b, alpha)
            if edge.horizontal then
                edge.texture:SetHeight(HH.db.thickness)
            else
                edge.texture:SetWidth(HH.db.thickness)
            end
        end
        entry.glow:Hide()
        entry.border:Show()
        return
    end
    local size = HH.db.glow
    for _, piece in ipairs(entry.glow.pieces) do
        piece.texture:SetVertexColor(r, g, b, alpha)
        if piece.size == "height" then
            piece.texture:SetHeight(size)
        elseif piece.size == "width" then
            piece.texture:SetWidth(size)
        else
            piece.texture:SetSize(size, size)
        end
    end
    entry.border:Hide()
    entry.glow:Show()
end

local function Visible(frame)
    if type(frame.IsVisible) ~= "function" then
        return true
    end
    local visible = frame:IsVisible()
    return HH.IsSecret(visible) or visible == true
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function Recheck(self, elapsed)
    self.waited = (self.waited or 0) + elapsed
    if self.waited < RECHECK then
        return
    end
    self.waited = 0
    if HH.Held() ~= state.held then
        HH.Apply()
    end
end

-- The highlight for the modifiers held now.
function HH.Apply()
    if not state.ready then
        return
    end
    local db = HH.db
    local held = HH.Held()
    state.held = held
    local active = db.enabled and not EditModeOpen() and (not db.combatOnly or InCombat())
    if active and held == "NONE" and db.idle ~= "base" then
        active = false
    end
    if active then
        local any = false
        for _, def in ipairs(HH.BARS) do
            local entry = state.bars[def.key]
            if entry and entry.frame and entry.layer == held then
                any = true
            end
        end
        active = any
    end
    state.active = active
    for _, def in ipairs(HH.BARS) do
        local entry = state.bars[def.key]
        if entry and entry.frame then
            local mine = active and entry.layer == held
            local other = active and entry.layer ~= nil and entry.layer ~= held
            Fade(entry, other and db.dim < 100)
            Border(entry, mine and db.border and Visible(entry.frame))
        end
    end
    if watcher then
        watcher:SetScript("OnUpdate", held ~= "NONE" and Recheck or nil)
    end
end

local EVENTS = {"MODIFIER_STATE_CHANGED", "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED"}

function HH.InitializeBars()
    -- First, so a failure here leaves no events registered.
    HH.Layout()
    watcher = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    watcher:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
            HH.Layout()
        end
        HH.Apply()
    end)
    local manager = rawget(_G, "EditModeManagerFrame")
    if type(manager) == "table" and type(manager.HookScript) == "function" then
        -- Edit Mode shows the bars as they are: no fade, no border.
        pcall(manager.HookScript, manager, "OnShow", function() HH.Apply() end)
        pcall(manager.HookScript, manager, "OnHide", function() HH.Apply() end)
    end
    state.ready = true
    HH.Apply()
end

-- /hh status: what was found and what each bar's layer is.
function HH.StatusLines()
    local lines = {string.format("enabled=%s held=%s active=%s other bars at %d%%, highlight=%s, labels=%s",
        tostring(HH.db.enabled), HH.LayerLabel(state.held), tostring(state.active), HH.db.dim,
        HH.db.border and (HH.db.style .. " " .. HH.db.color) or "off", HH.db.labels)}
    for _, def in ipairs(HH.BARS) do
        local entry = state.bars[def.key]
        if not entry or not entry.frame then
            lines[#lines + 1] = def.label .. ": not found on this client"
        else
            local layer
            if entry.choice == "ignore" then
                layer = "left alone (your setting)"
            elseif entry.layer then
                layer = HH.LayerLabel(entry.layer) .. (entry.choice == "auto" and " (from its keys)" or " (your setting)")
            else
                layer = "no keys, left alone"
            end
            lines[#lines + 1] = string.format("%s (%s): %s; %d of %d buttons have a key", def.label, entry.frameName,
                layer, entry.bound or 0, #entry.buttons)
        end
    end
    return lines
end
