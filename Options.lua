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
    Flag("HOTBARHIGHLIGHT_BORDER", "Border around the highlighted bar", "border", true,
        "A thin frame around the bar of the modifiers you hold.")
    Dropdown("HOTBARHIGHLIGHT_COLOR", "Border color", "gold", HH.COLORS,
        function() return HH.db.color end, function(value) HH.db.color = value end, "The border's color.")
    Slider("HOTBARHIGHLIGHT_THICKNESS", "Border thickness", "thickness", HH.THICKNESS_MIN, HH.THICKNESS_MAX,
        HH.DEFAULT_THICKNESS, "%d px", "The border's thickness, in pixels.")
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
    local tracked, changed = HH.LabelCount()
    HH.Report(string.format("Key labels: %d found, %d shortened.", tracked, changed))
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
