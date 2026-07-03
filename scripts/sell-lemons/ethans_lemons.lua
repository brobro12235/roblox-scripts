--[[
    Ethan's Lemons — Auto Buy + Auto Upgrade + Auto Collect Fruits + Auto Phone Offer
    Game: Sell Lemons (PlaceId 79268393072444)
    Menu: Visual UI Library | Toggle menu: Right Shift

    Tycoon detection uses the game's Tycoon.getLocal() when available,
    otherwise falls back to Workspace Owner ObjectValue (not an attribute).
    Purchase remotes: InvokeServer(false)  — false = normal, true = permanent
    Upgrade remotes:  InvokeServer(stack)  — stack count (default 1)
    Orchard harvest:  OrchardPlot.Harvest:InvokeServer(plot) when State == 3 (fruit ready)
    Phone offers:     PhoneOffer:FireServer("Accept" | "Raise") on active offer
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- Visual UI Library uses writefile/readfile — wrap so missing perms don't kill the menu
if writefile then
    local rawWrite = writefile
    writefile = function(...)
        pcall(rawWrite, ...)
    end
end
if readfile then
    local rawRead = readfile
    readfile = function(path)
        local ok, data = pcall(rawRead, path)
        if ok then
            return data
        end
        return nil
    end
end
if isfile then
    local rawIsFile = isfile
    isfile = function(path)
        local ok, exists = pcall(rawIsFile, path)
        return ok and exists or false
    end
end
if delfile then
    local rawDel = delfile
    delfile = function(...)
        pcall(rawDel, ...)
    end
end
if makefolder then
    local rawMk = makefolder
    makefolder = function(...)
        pcall(rawMk, ...)
    end
end
if isfolder then
    local rawIsFolder = isfolder
    isfolder = function(path)
        local ok, exists = pcall(rawIsFolder, path)
        return ok and exists or false
    end
end

local ACCENT = Color3.fromRGB(34, 197, 94)
local LOOP_WAIT = 0.35
local scriptRunning = true

local STAND_NAMES = {
    "Lemon Stand", "Lemon Depot", "Lemon Labs", "Lemon Republic",
    "Lemon Robotics", "Lemon Trading", "LemonDash", "LemonX",
}

-- OrchardPlot.States from decompiled OrchardPlot.lua
local ORCHARD_STATE_EMPTY = 0
local ORCHARD_STATE_FRUIT_READY = 3

-- ========== Game modules (optional) ==========

local function safeRequire(moduleScript)
    local ok, mod = pcall(require, moduleScript)
    return ok and mod or nil
end

local Tycoon = safeRequire(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Tycoon"):WaitForChild("Tycoon"))
local Config = safeRequire(ReplicatedStorage:FindFirstChild("Config"))

-- Game bug: multiplier pads use Model "Button" — cash refresh spam errors on .Color
-- PropertyState is table.freeze()'d so we can't patch getDefaultProperty; hook reads/writes instead.
local function patchGamePurchaseButtonBug()
    local gray = Color3.fromRGB(102, 102, 102)

    if typeof(hookmetamethod) ~= "function" then
        return
    end

    pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            -- Model has no .Color in Roblox — game reads it anyway on multiplier pads
            if key == "Color" and typeof(self) == "Instance" and self:IsA("Model") then
                return gray
            end
            return oldIndex(self, key)
        end)

        local oldNewIndex
        oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
            if key == "Color" and typeof(self) == "Instance" and self:IsA("Model") then
                return
            end
            return oldNewIndex(self, key, value)
        end)
    end)
end

-- ========== Tycoon helpers ==========

local function getMyTycoonInstance()
    if Tycoon then
        local entity = Tycoon.getLocal()
        if entity and entity.Instance then
            return entity.Instance
        end
    end

    -- Owner is an ObjectValue pointing at the Player instance (from decompiled Tycoon.lua)
    for _, child in workspace:GetChildren() do
        if child.Name:match("^Tycoon%d+$") then
            local owner = child:FindFirstChild("Owner")
            if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
                return child
            end
        end
    end

    return nil
end

local function getUpgradeStack()
    if not Config then
        return 1
    end

    local tycoonEntity = Tycoon and Tycoon.getLocal()
    if not tycoonEntity then
        return 1
    end

    local ClientTycoonPowers = safeRequire(
        ReplicatedStorage.Modules.Tycoon.Component.Client.ClientTycoonPowers
    )
    if not ClientTycoonPowers then
        return 1
    end

    local ok, powers = pcall(function()
        return tycoonEntity:GetComponent(ClientTycoonPowers)
    end)
    if not ok or not powers then
        return 1
    end

    local levelOk, level = pcall(function()
        return powers:GetSelectedLevel("UpgradeStack")
    end)
    if not levelOk then
        return 1
    end

    local bonus = Config.Powers
        and Config.Powers.UpgradeStack
        and Config.Powers.UpgradeStack.Bonuses
        and Config.Powers.UpgradeStack.Bonuses[level]

    return bonus or 1
end

-- ========== Purchase / upgrade logic ==========

local PURCHASE_COOLDOWN = 0.6
local purchaseLastAttempt = {}

local function hasValidPurchaseButton(pad)
    local button = pad:FindFirstChild("Button", true)
    return button ~= nil and button:IsA("BasePart")
end

local function isPurchaseable(pad)
    if string.find(pad:GetFullName(), ".Multipliers.", 1, true) then
        return false
    end
    if pad:GetAttribute("Category") == "Multiplier" then
        return false
    end
    if pad:GetAttribute("Purchased") then
        return false
    end
    if not pad:GetAttribute("Shown") then
        return false
    end
    -- Game treats missing Enabled as false (TycoonPurchase.lua)
    if not pad:GetAttribute("Enabled") then
        return false
    end
    if not hasValidPurchaseButton(pad) then
        return false
    end
    return true
end

local function purchasePriority(rf)
    local pad = rf.Parent
    local category = pad:GetAttribute("Category")

    if category == "Earner" then
        return 1
    end

    -- Stand unlock pads: Purchases.Stand.Stand.Stand.Purchase
    if pad.Parent and pad.Parent.Name == pad.Name then
        for _, stand in STAND_NAMES do
            if pad.Name == stand or string.find(pad:GetFullName(), stand, 1, true) then
                return 2
            end
        end
    end

    if category == "Minigame" then
        return 4
    end
    if category == "Decoration" then
        return 5
    end

    return 3
end

local function collectPurchaseRemotes(tycoon)
    local list = {}
    local purchases = tycoon:FindFirstChild("Purchases")
    if not purchases then
        return list
    end

    for _, inst in purchases:GetDescendants() do
        if inst:IsA("RemoteFunction") and inst.Name == "Purchase" then
            if isPurchaseable(inst.Parent) then
                table.insert(list, inst)
            end
        end
    end

    table.sort(list, function(a, b)
        return purchasePriority(a) < purchasePriority(b)
    end)

    return list
end

local function isEarnerUnlocked(earnerInst, tycoon)
    local current = earnerInst
    while current and current ~= tycoon do
        if current:GetAttribute("Purchased") or current:GetAttribute("Enabled") then
            return true
        end
        current = current.Parent
    end
    return false
end

local function collectUpgradeRemotes(tycoon)
    local list = {}
    local purchases = tycoon:FindFirstChild("Purchases")
    if not purchases then
        return list
    end

    for _, inst in purchases:GetDescendants() do
        if inst:IsA("RemoteFunction") and inst.Name == "Upgrade" then
            if isEarnerUnlocked(inst.Parent, tycoon) then
                table.insert(list, inst)
            end
        end
    end

    return list
end

local function tryPurchase(rf)
    local key = rf:GetFullName()
    local now = tick()
    if purchaseLastAttempt[key] and (now - purchaseLastAttempt[key]) < PURCHASE_COOLDOWN then
        return false
    end
    purchaseLastAttempt[key] = now

    local ok = pcall(function()
        rf:InvokeServer(false)
    end)
    return ok
end

local function tryUpgrade(rf, stack)
    local key = rf:GetFullName()
    local now = tick()
    if purchaseLastAttempt[key] and (now - purchaseLastAttempt[key]) < PURCHASE_COOLDOWN then
        return false
    end
    purchaseLastAttempt[key] = now

    pcall(function()
        rf:InvokeServer(stack)
    end)
end

-- One purchase per loop (priority order) — avoids spamming hundreds of remotes
local function runPurchases(tycoon)
    local remotes = collectPurchaseRemotes(tycoon)
    if remotes[1] then
        tryPurchase(remotes[1])
    end
end

local upgradeRotateIndex = 1

local function runUpgrades(tycoon)
    local stack = getUpgradeStack()
    local remotes = collectUpgradeRemotes(tycoon)
    if #remotes == 0 then
        return
    end

    if upgradeRotateIndex > #remotes then
        upgradeRotateIndex = 1
    end

    tryUpgrade(remotes[upgradeRotateIndex], stack)
    upgradeRotateIndex = upgradeRotateIndex + 1
end

-- ========== Orchard / lemon tree fruit collection ==========

local harvestRemote

local function getHarvestRemote()
    if harvestRemote then
        return harvestRemote
    end

    local core = ReplicatedStorage:FindFirstChild("Core")
    local remoteFolder = core and core:FindFirstChild("RemoteRequest")
    harvestRemote = remoteFolder and remoteFolder:FindFirstChild("OrchardPlot.Harvest")
    return harvestRemote
end

local function isOrchardPlotReady(plot)
    if not plot:GetAttribute("ID") then
        return false
    end
    if plot:GetAttribute("Enabled") == false then
        return false
    end

    local state = plot:GetAttribute("State") or ORCHARD_STATE_EMPTY
    return state == ORCHARD_STATE_FRUIT_READY
end

local function collectOrchardPlots(tycoon)
    local remote = getHarvestRemote()
    if not remote then
        return
    end

    local plots = {}

    for _, plot in CollectionService:GetTagged("Tycoon.OrchardPlot") do
        if plot:IsDescendantOf(tycoon) and isOrchardPlotReady(plot) then
            table.insert(plots, plot)
        end
    end

    -- Fallback if tags aren't replicated yet
    if #plots == 0 then
        local orchard = tycoon:FindFirstChild("Orchard")
        if orchard then
            for _, inst in orchard:GetDescendants() do
                if inst:GetAttribute("ID") and inst:GetAttribute("GridPosition") then
                    if isOrchardPlotReady(inst) then
                        table.insert(plots, inst)
                    end
                end
            end
        end
    end

    for _, plot in plots do
        pcall(function()
            remote:InvokeServer(plot)
        end)
        task.wait(0.03)
    end
end

local function clickPickableTreeFruits(tycoon)
    -- Decorative tree lemons (Expert Picker) — server handles ClickDetector / touch
    for _, inst in tycoon:GetDescendants() do
        if inst:IsA("ClickDetector") then
            local part = inst.Parent
            if part and part:IsA("BasePart") then
                local name = part.Name:lower()
                if name:find("fruit") or name:find("lemon") then
                    pcall(function()
                        fireclickdetector(inst, 0)
                    end)
                end
            end
        elseif inst:IsA("ProximityPrompt") and inst.Enabled then
            local host = inst.Parent
            if host and host:IsA("BasePart") then
                local name = host.Name:lower()
                if name:find("fruit") or name:find("lemon") then
                    pcall(function()
                        fireproximityprompt(inst)
                    end)
                end
            end
        end
    end
end

local function runFruitCollection(tycoon)
    collectOrchardPlots(tycoon)
    clickPickableTreeFruits(tycoon)
end

-- ========== Phone offer auto-accept ==========

local lastPhoneOfferValue = nil
local phoneOfferRaisedAt = nil

local function getPhoneOfferRemote(tycoon)
    local remotes = tycoon:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("PhoneOffer")
    if remote and remote:IsA("RemoteEvent") then
        return remote
    end
    return nil
end

local function getCurrentPhoneOfferValue()
    if not Tycoon then
        return nil
    end

    local entity = Tycoon.getLocal()
    if not entity then
        return nil
    end

    local ClientTycoonPhoneOffers = safeRequire(
        ReplicatedStorage.Modules.Tycoon.Component.Client.ClientTycoonPhoneOffers
    )
    if not ClientTycoonPhoneOffers then
        return nil
    end

    local ok, component = pcall(function()
        return entity:GetComponent(ClientTycoonPhoneOffers)
    end)
    if not ok or not component then
        return nil
    end

    return component:GetCurrentOffer()
end

local function runPhoneOffer(tycoon, mode)
    local offerValue = getCurrentPhoneOfferValue()
    if not offerValue then
        lastPhoneOfferValue = nil
        phoneOfferRaisedAt = nil
        return
    end

    local remote = getPhoneOfferRemote(tycoon)
    if not remote then
        return
    end

    if mode == "Raise" then
        if offerValue ~= lastPhoneOfferValue then
            pcall(function()
                remote:FireServer("Raise")
            end)
            lastPhoneOfferValue = offerValue
        end
        return
    end

    if mode == "Raise Then Accept" then
        if phoneOfferRaisedAt and offerValue ~= phoneOfferRaisedAt then
            pcall(function()
                remote:FireServer("Accept")
            end)
            phoneOfferRaisedAt = nil
            lastPhoneOfferValue = offerValue
        elseif not phoneOfferRaisedAt and offerValue ~= lastPhoneOfferValue then
            pcall(function()
                remote:FireServer("Raise")
            end)
            phoneOfferRaisedAt = offerValue
            lastPhoneOfferValue = offerValue
        end
        return
    end

    -- Default: Accept immediately (once per offer value)
    if offerValue ~= lastPhoneOfferValue then
        pcall(function()
            remote:FireServer("Accept")
        end)
        lastPhoneOfferValue = offerValue
    end
end

-- ========== Visual UI menu ==========

local function loadVisualLibraryNoIntro()
    local source = game:HttpGet(
        "https://raw.githubusercontent.com/VisualRoblox/Roblox/main/UI-Libraries/Visual%20UI%20Library/Source.lua"
    )

    -- Strip the splash / intro sequence (~6s of waits + logo fade)
    local destroyMarker = "Main['IntroImage']:Destroy()"
    local introFrom = source:find("Utility:Tween(Main, {BackgroundTransparency = 0}", 1, true)
    local introTo = source:find(destroyMarker, introFrom, true)
    if introFrom and introTo then
        local fastOpen = table.concat({
            "Utility:Tween(Main, {BackgroundTransparency = 0}, 0.08)",
            "Utility:Tween(Main, {Size = UDim2.new(0, 600, 0, 375)}, 0.12)",
            "if Main:FindFirstChild('IntroText') then Main.IntroText:Destroy() end",
            "if Main:FindFirstChild('IntroImage') then Main.IntroImage:Destroy() end",
        }, "\n ")
        source = source:sub(1, introFrom - 1) .. fastOpen .. source:sub(introTo + #destroyMarker)
    end

    -- ChangeTheme / ChangeColor are no-ops when ImprovePerformance is true — unlock them
    source = source:gsub(
        "function Library:ChangeTheme%(NewTheme%)\r?\n if not ImprovePerformance then",
        "function Library:ChangeTheme(NewTheme)\nif true then"
    )
    source = source:gsub(
        "function Library:ChangeColor%(Index, Color%)\r?\n if not ImprovePerformance then",
        "function Library:ChangeColor(Index, Color)\nif true then"
    )

    -- Don't fail theme swap if writefile is blocked in executor
    source = source:gsub(
        "writefile%('VisualUILibraryCurrentTheme%.json', HttpService:JSONEncode%(NewTable%)%)",
        "pcall(writefile, 'VisualUILibraryCurrentTheme.json', HttpService:JSONEncode(NewTable))"
    )

    -- Clicking hub / game title opens an info popup — disable that
    source = source:gsub(
        "Library:CreatePrompt%('Text', 'Hub Name', HubName, 'Close'%)",
        "nil"
    )
    source = source:gsub(
        "Library:CreatePrompt%('Text', 'Game Name', GameName, 'Close'%)",
        "nil"
    )

    return loadstring(source)()
end

local function loadVisualLibrary()
    local url = "https://raw.githubusercontent.com/VisualRoblox/Roblox/main/UI-Libraries/Visual%20UI%20Library/Source.lua"

    local ok, lib = pcall(loadVisualLibraryNoIntro)
    if ok and lib then
        return lib
    end

    warn("[Ethan's Lemons] Patched UI failed, loading vanilla library:", lib)
    return loadstring(game:HttpGet(url))()
end

local function disableSidebarTitleClicks()
    task.defer(function()
        pcall(function()
            local CoreGui = game:GetService("CoreGui")
            local ui = CoreGui:WaitForChild("Visual UI Library | .gg/puxxCphTnK", 5)
            local sidebar = ui:WaitForChild("Main"):WaitForChild("Sidebar")
            for _, name in ipairs({ "HubNameText", "GameNameText" }) do
                local label = sidebar:FindFirstChild(name)
                if label then
                    label.Active = false
                end
            end
        end)
    end)
end

local Library = loadVisualLibrary()
if not Library or not Library.CreateWindow then
    warn("[Ethan's Lemons] Visual UI Library failed to load — menu unavailable")
    return
end

-- Classic color themes (no executor-branded presets)
local CUSTOM_THEMES = {
    ["Mint"] = {
        BackgroundColor = Color3.fromRGB(18, 32, 28),
        SidebarColor = Color3.fromRGB(14, 26, 22),
        PrimaryTextColor = Color3.fromRGB(236, 253, 245),
        SecondaryTextColor = Color3.fromRGB(134, 180, 165),
        UIStrokeColor = Color3.fromRGB(52, 211, 163),
        PrimaryElementColor = Color3.fromRGB(22, 38, 34),
        SecondaryElementColor = Color3.fromRGB(32, 52, 46),
        OtherElementColor = Color3.fromRGB(18, 32, 28),
        ScrollBarColor = Color3.fromRGB(94, 234, 212),
        PromptColor = Color3.fromRGB(26, 44, 38),
        NotificationColor = Color3.fromRGB(18, 32, 28),
        NotificationUIStrokeColor = Color3.fromRGB(52, 211, 163),
    },
    ["Forest"] = {
        BackgroundColor = Color3.fromRGB(16, 24, 16),
        SidebarColor = Color3.fromRGB(12, 20, 12),
        PrimaryTextColor = Color3.fromRGB(240, 250, 240),
        SecondaryTextColor = Color3.fromRGB(140, 170, 140),
        UIStrokeColor = Color3.fromRGB(74, 222, 128),
        PrimaryElementColor = Color3.fromRGB(22, 32, 22),
        SecondaryElementColor = Color3.fromRGB(34, 48, 34),
        OtherElementColor = Color3.fromRGB(16, 24, 16),
        ScrollBarColor = Color3.fromRGB(74, 222, 128),
        PromptColor = Color3.fromRGB(28, 40, 28),
        NotificationColor = Color3.fromRGB(16, 24, 16),
        NotificationUIStrokeColor = Color3.fromRGB(74, 222, 128),
    },
    ["Ocean"] = {
        BackgroundColor = Color3.fromRGB(14, 24, 32),
        SidebarColor = Color3.fromRGB(10, 20, 28),
        PrimaryTextColor = Color3.fromRGB(240, 249, 255),
        SecondaryTextColor = Color3.fromRGB(125, 170, 195),
        UIStrokeColor = Color3.fromRGB(56, 189, 248),
        PrimaryElementColor = Color3.fromRGB(18, 30, 40),
        SecondaryElementColor = Color3.fromRGB(28, 44, 56),
        OtherElementColor = Color3.fromRGB(14, 24, 32),
        ScrollBarColor = Color3.fromRGB(125, 211, 252),
        PromptColor = Color3.fromRGB(22, 36, 48),
        NotificationColor = Color3.fromRGB(14, 24, 32),
        NotificationUIStrokeColor = Color3.fromRGB(56, 189, 248),
    },
    ["Slate"] = {
        BackgroundColor = Color3.fromRGB(22, 24, 28),
        SidebarColor = Color3.fromRGB(18, 20, 24),
        PrimaryTextColor = Color3.fromRGB(248, 250, 252),
        SecondaryTextColor = Color3.fromRGB(148, 163, 184),
        UIStrokeColor = Color3.fromRGB(100, 116, 139),
        PrimaryElementColor = Color3.fromRGB(30, 32, 38),
        SecondaryElementColor = Color3.fromRGB(42, 46, 54),
        OtherElementColor = Color3.fromRGB(22, 24, 28),
        ScrollBarColor = Color3.fromRGB(148, 163, 184),
        PromptColor = Color3.fromRGB(36, 40, 48),
        NotificationColor = Color3.fromRGB(22, 24, 28),
        NotificationUIStrokeColor = Color3.fromRGB(100, 116, 139),
    },
    ["Rose"] = {
        BackgroundColor = Color3.fromRGB(28, 18, 24),
        SidebarColor = Color3.fromRGB(24, 14, 20),
        PrimaryTextColor = Color3.fromRGB(255, 241, 246),
        SecondaryTextColor = Color3.fromRGB(190, 140, 165),
        UIStrokeColor = Color3.fromRGB(244, 114, 182),
        PrimaryElementColor = Color3.fromRGB(36, 24, 32),
        SecondaryElementColor = Color3.fromRGB(52, 34, 44),
        OtherElementColor = Color3.fromRGB(28, 18, 24),
        ScrollBarColor = Color3.fromRGB(249, 168, 212),
        PromptColor = Color3.fromRGB(44, 28, 38),
        NotificationColor = Color3.fromRGB(28, 18, 24),
        NotificationUIStrokeColor = Color3.fromRGB(244, 114, 182),
    },
    ["Amber"] = {
        BackgroundColor = Color3.fromRGB(28, 22, 14),
        SidebarColor = Color3.fromRGB(24, 18, 10),
        PrimaryTextColor = Color3.fromRGB(255, 251, 235),
        SecondaryTextColor = Color3.fromRGB(190, 165, 120),
        UIStrokeColor = Color3.fromRGB(251, 191, 36),
        PrimaryElementColor = Color3.fromRGB(38, 30, 18),
        SecondaryElementColor = Color3.fromRGB(54, 42, 26),
        OtherElementColor = Color3.fromRGB(28, 22, 14),
        ScrollBarColor = Color3.fromRGB(252, 211, 77),
        PromptColor = Color3.fromRGB(48, 38, 22),
        NotificationColor = Color3.fromRGB(28, 22, 14),
        NotificationUIStrokeColor = Color3.fromRGB(251, 191, 36),
    },
}

local THEME_NAMES = { "Mint", "Forest", "Ocean", "Slate", "Rose", "Amber" }
local DEFAULT_THEME = "Mint"

local function applyTheme(themeName)
    local theme = CUSTOM_THEMES[themeName]
    if not theme then
        warn("[Ethan's Lemons] Unknown theme:", themeName)
        return
    end

    local ok, err = pcall(function()
        Library:ChangeTheme(theme)
    end)
    if not ok then
        warn("[Ethan's Lemons] Theme failed:", err)
    end
end

local autoBuy = false
local autoUpgrade = false
local autoCollect = false
local autoPhoneOffer = false
local phoneOfferMode = "Accept"

local Window
local windowOk, windowErr = pcall(function()
    Window = Library:CreateWindow(
        "Ethan's Lemons",
        "Sell Lemons",
        "",
        "",
        false,
        "VisualUIConfigs",
        CUSTOM_THEMES[DEFAULT_THEME]
    )

    disableSidebarTitleClicks()

    local FeaturesTab = Window:CreateTab(
        "Features",
        true,
        "rbxassetid://3926305904",
        Vector2.new(524, 44),
        Vector2.new(36, 36)
    )

    local Section = FeaturesTab:CreateSection("Automation")

    Section:CreateToggle("Auto Buy", false, ACCENT, 0.25, function(on)
        autoBuy = on
    end)

    Section:CreateToggle("Auto Upgrade", false, ACCENT, 0.25, function(on)
        autoUpgrade = on
    end)

    Section:CreateToggle("Auto Collect Fruits", false, ACCENT, 0.25, function(on)
        autoCollect = on
    end)

    Section:CreateToggle("Auto Phone Offer", false, ACCENT, 0.25, function(on)
        autoPhoneOffer = on
    end)

    Section:CreateDropdown("Phone Offer Action", {
        "Accept",
        "Raise",
        "Raise Then Accept",
    }, "Accept", 0.25, function(choice)
        phoneOfferMode = choice
    end)

    local SettingsTab = Window:CreateTab(
        "Settings",
        false,
        "rbxassetid://3926305904",
        Vector2.new(524, 44),
        Vector2.new(36, 36)
    )

    local SettingsSec = SettingsTab:CreateSection("UI")

    SettingsSec:CreateDropdown("Theme", THEME_NAMES, DEFAULT_THEME, 0.25, function(choice)
        applyTheme(choice)
    end)

    SettingsSec:CreateKeybind("Toggle Menu", "RightShift", function()
        Library:ToggleUI()
    end)

    SettingsSec:CreateButton("Unload Script", function()
        scriptRunning = false
        autoBuy = false
        autoUpgrade = false
        autoCollect = false
        autoPhoneOffer = false
        pcall(function()
            Library:DestroyUI()
        end)
        print("[Ethan's Lemons] Unloaded")
    end)

    task.defer(function()
        applyTheme(DEFAULT_THEME)
    end)
end)

if not windowOk then
    warn("[Ethan's Lemons] Menu failed to build:", windowErr)
else
    task.defer(patchGamePurchaseButtonBug)
end

-- ========== Main loop ==========

local warnedNoTycoon = false

task.spawn(function()
    while scriptRunning do
        if autoBuy or autoUpgrade or autoCollect or autoPhoneOffer then
            local tycoon = getMyTycoonInstance()
            if tycoon then
                warnedNoTycoon = false
                if autoBuy then
                    runPurchases(tycoon)
                end
                if autoUpgrade then
                    runUpgrades(tycoon)
                end
                if autoCollect then
                    runFruitCollection(tycoon)
                end
                if autoPhoneOffer then
                    runPhoneOffer(tycoon, phoneOfferMode)
                end
            elseif not warnedNoTycoon then
                warn("[Ethan's Lemons] No tycoon found — claim a plot first (Owner ObjectValue must be you)")
                warnedNoTycoon = true
            end
        end
        task.wait(LOOP_WAIT)
    end
end)

print("[Ethan's Lemons] Loaded — Right Shift to open menu")
