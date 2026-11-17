local _, HH = ...

-- The settings page (Options, AddOns, Hotbar Highlight) and the slash
-- command. The page is built with the game's Settings functions; on a client
-- without them the addon still runs with its saved (or default) settings and
-- /hh status still reports.

local REQUIRED_SETTINGS = {
    "RegisterVerticalLayoutCategory", "RegisterProxySetting", "RegisterAddOnCategory", "CreateCheckbox",
    "CreateSlider", "CreateSliderOptions", "CreateDropdown", "CreateControlTextContainer", "OpenToCategory",
}
local USAGE = "Use /hh to open the settings, /hh status to see each bar's layer, /hh on or /hh off."

local category

local function HasSettingsAPI()
    if type(Settings) ~= "table" or type(Settings.VarType) ~= "table" then
        return false
    end
    for _, name in ipairs(REQUIRED_SETTINGS) do
        if type(Settings[name]) ~= "function" then
            return false
        end
    end
    return true
end

local function Proxy(variable, variableType, name, default, getValue, setValue)
    return Settings.RegisterProxySetting(category, variable, variableType, name, default, getValue, setValue)
end

local function Flag(variable, name, key, default, tooltip)
    local setting = Proxy(variable, Settings.VarType.Boolean, name, default,
        function() return HH.db[key] end,
        function(value)
            HH.db[key] = value == true
            HH.Refresh()
        end)
    return Settings.CreateCheckbox(category, setting, tooltip)
end

local function Dropdown(variable, name, default, choices, getValue, setValue, tooltip)
    local setting = Proxy(variable, Settings.VarType.String, name, default, getValue,
        function(value)
            setValue(HH.Choice(value, choices, default))
            HH.Refresh()
        end)
    return Settings.CreateDropdown(category, setting, function()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do
            container:Add(choice.key, choice.label)
        end
        return container:GetData()
    end, tooltip)
end

local function Slider(variable, name, key, low, high, default, format, tooltip)
    local setting = Proxy(variable, Settings.VarType.Number, name, default,
        function() return HH.db[key] end,
        function(value)
            HH.db[key] = HH.Whole(value, low, high, default)
            HH.Refresh()
        end)
    local options = Settings.CreateSliderOptions(low, high, 1)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format(format, value)
        end)
    end
    return Settings.CreateSlider(category, setting, options, tooltip)
end

local function Heading(layout, name)
    if type(CreateSettingsListSectionHeaderInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
    end
end

function HH.InitializeOptions()
    SLASH_HOTBARHIGHLIGHT1 = "/hh"
    SLASH_HOTBARHIGHLIGHT2 = "/hotbarhighlight"
    SlashCmdList.HOTBARHIGHLIGHT = HH.HandleCommand
    if not HasSettingsAPI() then
        return
    end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(HH.TITLE)
    Flag("HOTBARHIGHLIGHT_ENABLED", "Enabled", "enabled", true,
        "While you hold Shift, Ctrl, Alt or a mix of them, the action bar whose keys use those modifiers is "
            .. "highlighted and the other bound bars fade. Off: bars and key labels are as the game shows them.")
    Slider("HOTBARHIGHLIGHT_DIM", "Other bars' opacity", "dim", HH.DIM_MIN, HH.DIM_MAX, HH.DEFAULT_DIM, "%d%%",
        "How visible the other bars stay while one is highlighted. 100% does not fade them.")
    Flag("HOTBARHIGHLIGHT_BORDER", "Highlight around the bar", "border", true,
        "A glow or a line around the bar of the modifiers you hold. Off: that bar only stays bright while the "
            .. "others fade.")
    Dropdown("HOTBARHIGHLIGHT_AREA", "Highlight goes around", "bar", HH.AREAS,
        function() return HH.db.area end, function(value) HH.db.area = value end,
        "The whole bar: the bar's frame, as the game sizes it. Only the buttons shown: the smallest box around "
            .. "the buttons you can see, for a bar set to fewer icons or with its empty slots hidden.")
    Dropdown("HOTBARHIGHLIGHT_STYLE", "Highlight style", "glow", HH.STYLES,
        function() return HH.db.style end, function(value) HH.db.style = value end,
        "Soft glow: a light around the bar that fades outward. Thin line: a plain frame.")
    if type(Settings.CreateColorSwatch) == "function" then
        local color = Proxy("HOTBARHIGHLIGHT_COLOR", Settings.VarType.String, "Highlight color", HH.DEFAULT_COLOR,
            function() return HH.db.color end,
            function(value)
                HH.db.color = HH.SanitizeColor(value)
                HH.Refresh()
            end)
        Settings.CreateColorSwatch(category, color, "The color of the glow or line. Click to pick any color.")
    else
        Dropdown("HOTBARHIGHLIGHT_COLOR", "Highlight color", HH.DEFAULT_COLOR, HH.COLORS,
            function() return HH.db.color end, function(value) HH.db.color = value end,
            "The color of the glow or line.")
    end
    Slider("HOTBARHIGHLIGHT_OPACITY", "Highlight opacity", "opacity", HH.OPACITY_MIN, HH.OPACITY_MAX,
        HH.DEFAULT_OPACITY, "%d%%", "How strong the glow or line is.")
    Slider("HOTBARHIGHLIGHT_GLOW", "Glow size", "glow", HH.GLOW_MIN, HH.GLOW_MAX, HH.DEFAULT_GLOW, "%d px",
        "How far the soft glow reaches beyond the bar, in pixels.")
    Slider("HOTBARHIGHLIGHT_INNER", "Inner glow", "inner", HH.INNER_MIN, HH.INNER_MAX, HH.DEFAULT_INNER, "%d%%",
        "How far the soft glow reaches in under the bar's edge, as a share of a button's size. The buttons "
            .. "cover it, so it shows only where they leave room: at their round corners and between them. "
            .. "0 turns it off.")
    Slider("HOTBARHIGHLIGHT_THICKNESS", "Line thickness", "thickness", HH.THICKNESS_MIN, HH.THICKNESS_MAX,
        HH.DEFAULT_THICKNESS, "%d px", "The thin line's thickness, in pixels.")
    Dropdown("HOTBARHIGHLIGHT_IDLE", "With no modifier held", "all", HH.IDLE,
        function() return HH.db.idle end, function(value) HH.db.idle = value end,
        "Every bar normal: nothing is highlighted until you hold a modifier. Highlight the bar with no modifier: "
            .. "the bar whose keys have no modifier is highlighted and the others stay faded until you hold one.")
    Flag("HOTBARHIGHLIGHT_COMBAT", "Only in combat", "combatOnly", false,
        "Highlight and fade only while you are in combat.")
    Dropdown("HOTBARHIGHLIGHT_LABELS", "Key labels", "short", HH.LABEL_STYLES,
        function() return HH.db.labels end, function(value) HH.db.labels = value end,
        "How a button shows its key. Short: one letter per modifier, then the key (S1 for Shift-1, AC1 for "
            .. "Alt-Ctrl-1). Key only: just the key; the highlighted bar tells you the modifier. The game's own: "
            .. "left as the game writes it (s-1).")
    Dropdown("HOTBARHIGHLIGHT_LABEL_PLACE", "Key label place", "game", HH.LABEL_PLACES,
        function() return HH.db.labelPlace end, function(value) HH.db.labelPlace = value end,
        "Where the key label sits in its button: a corner, a side, or the center. The game's own leaves it where "
            .. "the game puts it. A change made in combat shows when the fight ends.")
    Slider("HOTBARHIGHLIGHT_LABEL_X", "Key label left/right", "labelX", HH.LABEL_OFFSET_MIN, HH.LABEL_OFFSET_MAX, 0,
        "%d px", "Moves the label left (below 0) or right: from the place chosen above, or from where the game "
            .. "puts it.")
    Slider("HOTBARHIGHLIGHT_LABEL_Y", "Key label down/up", "labelY", HH.LABEL_OFFSET_MIN, HH.LABEL_OFFSET_MAX, 0,
        "%d px", "Moves the label down (below 0) or up: from the place chosen above, or from where the game puts "
            .. "it.")
    Slider("HOTBARHIGHLIGHT_LABEL_SIZE", "Key label size", "labelSize", HH.LABEL_SIZE_MIN, HH.LABEL_SIZE_MAX, 100,
        "%d%%", "The label's text size, in percent of the size it has without this addon.")
    Slider("HOTBARHIGHLIGHT_LABEL_OPACITY", "Key label opacity", "labelOpacity", HH.LABEL_OPACITY_MIN,
        HH.LABEL_OPACITY_MAX, 100, "%d%%", "How visible the labels are.")
    Heading(layout, "Bars")
    for _, bar in ipairs(HH.BARS) do
        Dropdown("HOTBARHIGHLIGHT_LAYER_" .. bar.key:upper(), bar.label, "auto", HH.LAYER_CHOICES,
            function() return HH.db.layers[bar.key] or "auto" end,
            function(value) HH.db.layers[bar.key] = value ~= "auto" and value or nil end,
            "Which modifiers this bar belongs to. Auto reads them from the keys bound to its buttons. "
                .. "/hh status lists what was found.")
    end
    Settings.RegisterAddOnCategory(category)
end

function HH.OpenSettings()
    if not category then
        HH.Report("The settings page is unavailable on this client. " .. USAGE)
        return
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        HH.Report("The settings open out of combat.")
        return
    end
    Settings.OpenToCategory(category:GetID())
end

function HH.ReportStatus()
    for _, line in ipairs(HH.StatusLines()) do
        HH.Report(line)
    end
    local tracked, changed, looked, waiting, refused, reason = HH.LabelCount()
    HH.Report(string.format("Key labels: %d found, %d shortened, %d with a changed look%s. Place %s, offsets %d, %d, "
        .. "size %d%%, opacity %d%%.", tracked, changed, looked,
        waiting and "; their place waits for combat to end" or "", HH.db.labelPlace, HH.db.labelX, HH.db.labelY,
        HH.db.labelSize, HH.db.labelOpacity))
    if refused > 0 then
        HH.Report(string.format("%d key labels could not be moved. First: %s", refused, tostring(reason)))
    end
    if #HH.startFailures > 0 then
        HH.Report("Did not start: " .. table.concat(HH.startFailures, ", ") .. ".")
    end
end

local function SetEnabled(on)
    HH.db.enabled = on
    HH.Refresh()
    if category and type(Settings.NotifyUpdate) == "function" then
        pcall(Settings.NotifyUpdate, "HOTBARHIGHLIGHT_ENABLED")
    end
    HH.Report(on and "on." or "off.")
end

function HH.HandleCommand(message)
    local command = type(message) == "string" and message:match("^%s*(.-)%s*$"):lower() or ""
    if command == "" or command == "options" then
        HH.OpenSettings()
    elseif command == "status" then
        HH.ReportStatus()
    elseif command == "on" then
        SetEnabled(true)
    elseif command == "off" then
        SetEnabled(false)
    else
        HH.Report(USAGE)
    end
end
