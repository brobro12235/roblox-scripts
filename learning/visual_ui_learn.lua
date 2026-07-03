--[[
    VISUAL UI LIBRARY — LEARNING TEMPLATE
    =====================================
    Run in Potassium. Read top-to-bottom once, then delete comments and build your own.

    STRUCTURE (memorize this):
        loadstring(...)()  →  Library
        Library:CreateWindow(...)  →  Window (the whole menu)
        Window:CreateTab(...)  →  Tab (sidebar page)
        Tab:CreateSection(...)  →  Section (group box)
        Section:CreateToggle/Button/etc  →  actual controls

    EVERY CONTROL HAS A CALLBACK — the function at the end runs when user interacts.
]]

-- STEP 1: Load the library (one line, don't touch unless URL breaks)
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/VisualRoblox/Roblox/main/UI-Libraries/Visual%20UI%20Library/Source.lua"
))()

--[[
    STEP 2: Create the window
    Args (in order):
      1. Hub name      — title shown at top of your hub
      2. Game name     — subtitle (put your game name here)
      3. Library name  — credit line
      4. Image ID      — logo (rbxassetid://...) or use default
      5. ???           — false in template (library-specific flag)
      6. Config folder — where save/load configs go on disk
      7. Default theme — "Default" or another from Library:GetThemes()
]]
local Window = Library:CreateWindow(
    "My Hub",           -- change: your script name
    "Ugc",              -- change: game you're playing
    "Visual UI Library",
    "rbxassetid://10618928818",
    false,
    "VisualUIConfigs",  -- config files saved under this name
    "Default"
)

--[[
    STEP 3: Create a tab
    Args:
      1. Tab name
      2. Selected? — true = this tab shows first when menu opens
      3. Icon asset id
      4. Icon rect in sprite sheet (Vector2)
      5. Icon size (Vector2)
    Tip: Most scripts only need 1–3 tabs, not 10.
]]
local MainTab = Window:CreateTab(
    "Main",
    true,  -- open this tab by default
    "rbxassetid://3926305904",
    Vector2.new(524, 44),
    Vector2.new(36, 36)
)

--[[
    STEP 4: Section = labeled group (like a card)
    Put related controls in one section.
]]
local FarmSection = MainTab:CreateSection("Auto Farm")

-- ========== CONTROLS YOU'LL ACTUALLY USE ==========

--[[ TOGGLE — on/off switch
    CreateToggle(name, defaultOn, accentColor, animSpeed, callback)
    callback(Value) — Value is true/false
]]
local autoFarmEnabled = false

FarmSection:CreateToggle("Auto Farm", false, Color3.fromRGB(99, 102, 241), 0.25, function(on)
    autoFarmEnabled = on
    print("Auto Farm:", on)

    if on then
        -- START your loop here (see task.spawn example below)
    else
        -- STOP your loop (set flag false — loop checks it)
    end
end)

--[[ BUTTON — runs once when clicked
    CreateButton(name, callback)
]]
FarmSection:CreateButton("Harvest Once", function()
    print("Harvest Once clicked")
    -- Fire remote once, teleport once, etc.
end)

--[[ SLIDER — number in a range
    CreateSlider(name, min, max, default, color, callback)
    callback(Value) — number between min and max
]]
FarmSection:CreateSlider("Delay (seconds)", 1, 10, 3, Color3.fromRGB(99, 102, 241), function(value)
    print("Delay set to:", value)
    -- store in a variable your loop reads: _G.farmDelay = value
end)

--[[ DROPDOWN — pick one option
    CreateDropdown(name, options, default, animSpeed, callback)
]]
local selectedCrop = "Apple"

FarmSection:CreateDropdown("Crop", { "Apple", "Orange", "Banana" }, "Apple", 0.25, function(value)
    selectedCrop = value
    print("Selected crop:", value)
end)

--[[ TEXTBOX — user types text, fires on enter
    CreateTextbox(name, placeholder, callback)
]]
FarmSection:CreateTextbox("Player name", "Enter name...", function(text)
    print("Text:", text)
end)

--[[ KEYBIND — press a key to run callback
    CreateKeybind(name, defaultKey, callback)
]]
FarmSection:CreateKeybind("Toggle Farm", "F", function()
    autoFarmEnabled = not autoFarmEnabled
    print("Farm toggled via key:", autoFarmEnabled)
end)

-- ========== OPTIONAL: second tab for settings ==========

local SettingsTab = Window:CreateTab(
    "Settings",
    false,
    "rbxassetid://3926305904",
    Vector2.new(524, 44),
    Vector2.new(36, 36)
)

local UISection = SettingsTab:CreateSection("UI")

UISection:CreateKeybind("Show / Hide Menu", "E", function()
    Library:ToggleUI()
end)

UISection:CreateButton("Destroy Menu", function()
    Library:DestroyUI()
end)

UISection:CreateSlider("Transparency", 0, 100, 0, Color3.fromRGB(99, 102, 241), function(value)
    Library:SetTransparency(value / 100, true)
end)

-- ========== PATTERN: background loop controlled by toggle ==========
--[[
    DON'T put infinite loops in the callback directly — it freezes UI.
    DO: task.spawn a loop that checks a boolean flag.
]]

task.spawn(function()
    while true do
        if autoFarmEnabled then
            -- your farm logic every iteration:
            -- 1. find target
            -- 2. fire remote
            -- 3. wait
            print("Farming... crop:", selectedCrop)
        end
        task.wait(1)  -- use your slider value instead of 1
    end
end)

--[[
    ========== CHEAT SHEET ==========

    Label (read-only text):
        Section:CreateLabel("Status: Idle")

    Paragraph (title + body):
        Section:CreateParagraph("Info", "How to use this script")

    Update label after creation:
        local lbl = Section:CreateLabel("HP: ?")
        lbl:UpdateLabel("HP: 100", true)

    Notification:
        Library:CreateNotification("Title", "Message", 5)

    Save/load settings:
        Library:SaveConfig("myconfig")
        Library:LoadConfig("myconfig")
        Library:GetConfigs()  -- list for dropdown

    Themes:
        Library:ChangeTheme("Default")
        Library:GetThemes()

    ========== WHAT TO DELETE FROM THE BIG TEMPLATE ==========
    - Update Functions tab (demo only)
    - Library Functions tab (copy only what you need to Settings)
    - ColorSection loop (theme tweaking — optional)
    - Image demos

    ========== MINIMUM REAL SCRIPT ==========
    1. loadstring → Library
    2. CreateWindow
    3. One Tab + one Section
    4. One Toggle with your logic
    5. Keybind to ToggleUI
]]

print("[Visual UI] Learning template loaded — press E if you added ToggleUI keybind")
