--[[
    CLEAN UI TUTORIAL — build this yourself, line by line

    HOW TO LEARN:
      1. Run this in Potassium (in any game)
      2. Change ONE thing at a time (color, size, text) and see what happens
      3. Delete sections and rebuild them from memory
      4. Read the "WHY" comments below

    CLEAN UI RULES (memorize these):
      • One font everywhere (GothamMedium / GothamBold for titles)
      • Dark background + slightly lighter cards
      • 8px spacing grid (padding/margin in multiples of 8: 8, 12, 16, 24)
      • Rounded corners (UICorner 6–10 for buttons, 10–14 for panels)
      • Subtle border (UIStroke, low transparency) instead of thick outlines
      • One accent color (blue/purple/green) — don't rainbow everything
      • Left-align text; center only titles/icons
]]

-- ========== SERVICES ==========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ========== THEME (change these first when skinning) ==========
local Theme = {
    bg          = Color3.fromRGB(18, 18, 22),      -- main window
    card        = Color3.fromRGB(28, 28, 34),      -- inner panels
    accent      = Color3.fromRGB(99, 102, 241),    -- buttons / highlights (indigo)
    accentHover = Color3.fromRGB(129, 132, 255),
    text        = Color3.fromRGB(240, 240, 245),
    textMuted   = Color3.fromRGB(160, 162, 170),
    stroke      = Color3.fromRGB(255, 255, 255),
    strokeAlpha = 0.08,
    corner      = 10,
    cornerSm    = 8,
    font        = Enum.Font.GothamMedium,
    fontBold    = Enum.Font.GothamBold,
}

-- ========== HELPERS (reusable UI factory) ==========
-- WHY: Don't copy-paste 20 lines per button. One function = consistent look.

local function tween(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad), props):Play()
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or Theme.corner)
    c.Parent = parent
    return c
end

local function addStroke(parent, thickness, alpha)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1
    s.Color = Theme.stroke
    s.Transparency = 1 - (alpha or Theme.strokeAlpha)
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function addPadding(parent, px)
    local p = Instance.new("UIPadding")
    local n = UDim.new(0, px or 12)
    p.PaddingTop, p.PaddingBottom = n, n
    p.PaddingLeft, p.PaddingRight = n, n
    p.Parent = parent
    return p
end

local function makeLabel(parent, props)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Font = props.font or Theme.font
    lbl.TextSize = props.size or 14
    lbl.TextColor3 = props.color or Theme.text
    lbl.TextXAlignment = props.align or Enum.TextXAlignment.Left
    lbl.Text = props.text or ""
    lbl.Size = props.sizeDim or UDim2.new(1, 0, 0, 20)
    lbl.Parent = parent
    return lbl
end

local function makeButton(parent, props)
    local btn = Instance.new("TextButton")
    btn.Size = props.size or UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = props.bg or Theme.accent
    btn.Text = props.text or "Button"
    btn.Font = Theme.font
    btn.TextSize = 14
    btn.TextColor3 = Theme.text
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = parent
    addCorner(btn, Theme.cornerSm)

    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = Theme.accentHover })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = props.bg or Theme.accent })
    end)

    if props.onClick then
        btn.MouseButton1Click:Connect(props.onClick)
    end
    return btn
end

local function makeToggle(parent, props)
    -- WHY: Toggles are Frame + clickable area + sliding pill (standard pattern)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundTransparency = 1
    row.Parent = parent

    makeLabel(row, { text = props.text, sizeDim = UDim2.new(1, -56, 1, 0) })

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 44, 0, 24)
    track.Position = UDim2.new(1, -44, 0.5, -12)
    track.BackgroundColor3 = Theme.card
    track.Text = ""
    track.AutoButtonColor = false
    track.BorderSizePixel = 0
    track.Parent = row
    addCorner(track, 12)
    addStroke(track, 1, 0.06)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Theme.textMuted
    knob.BorderSizePixel = 0
    knob.Parent = track
    addCorner(knob, 9)

    local enabled = props.default or false

    local function refresh()
        if enabled then
            tween(track, { BackgroundColor3 = Theme.accent })
            tween(knob, { Position = UDim2.new(1, -21, 0.5, -9), BackgroundColor3 = Theme.text })
        else
            tween(track, { BackgroundColor3 = Theme.card })
            tween(knob, { Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = Theme.textMuted })
        end
    end

    track.MouseButton1Click:Connect(function()
        enabled = not enabled
        refresh()
        if props.onChange then props.onChange(enabled) end
    end)

    refresh()
    return { set = function(v) enabled = v; refresh() end, get = function() return enabled end }
end

-- ========== MAIN WINDOW ==========
-- Hierarchy:
--   ScreenGui
--     └── Main (Frame)          ← window shell
--           ├── TopBar (Frame)  ← title + drag
--           └── Body (Frame)    ← content

local gui = Instance.new("ScreenGui")
gui.Name = "CleanUI_Tutorial"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 320, 0, 380)
main.Position = UDim2.new(0.5, -160, 0.5, -190)
main.BackgroundColor3 = Theme.bg
main.BorderSizePixel = 0
main.Parent = gui
addCorner(main, Theme.corner + 4)
addStroke(main, 1, 0.06)

-- Top bar (drag handle)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 44)
topBar.BackgroundTransparency = 1
topBar.Parent = main

makeLabel(topBar, {
    text = "My Script",
    font = Theme.fontBold,
    size = 16,
    sizeDim = UDim2.new(1, -48, 1, 0),
    align = Enum.TextXAlignment.Left,
}).Position = UDim2.new(0, 16, 0, 0)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
closeBtn.BackgroundColor3 = Theme.card
closeBtn.Text = "×"
closeBtn.TextSize = 18
closeBtn.Font = Theme.fontBold
closeBtn.TextColor3 = Theme.textMuted
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topBar
addCorner(closeBtn, 8)
closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- Body with list layout (WHY: UIListLayout auto-stacks children — no manual Y math)
local body = Instance.new("Frame")
body.Size = UDim2.new(1, -32, 1, -56)
body.Position = UDim2.new(0, 16, 0, 48)
body.BackgroundTransparency = 1
body.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = body

-- Section card
local card = Instance.new("Frame")
card.Size = UDim2.new(1, 0, 0, 0)
card.AutomaticSize = Enum.AutomaticSize.Y
card.BackgroundColor3 = Theme.card
card.BorderSizePixel = 0
card.LayoutOrder = 1
card.Parent = body
addCorner(card, Theme.corner)
addStroke(card, 1, 0.05)
addPadding(card, 12)

local cardList = Instance.new("UIListLayout")
cardList.Padding = UDim.new(0, 8)
cardList.SortOrder = Enum.SortOrder.LayoutOrder
cardList.Parent = card

makeLabel(card, { text = "Features", font = Theme.fontBold, size = 13, color = Theme.textMuted, sizeDim = UDim2.new(1, 0, 0, 16) })

local autoFarm = makeToggle(card, {
    text = "Auto Farm",
    default = false,
    onChange = function(on)
        print("[UI] Auto Farm:", on)
        -- YOUR CODE HERE: start/stop farm loop
    end,
})

makeToggle(card, {
    text = "Auto Collect",
    onChange = function(on) print("[UI] Auto Collect:", on) end,
})

makeButton(card, {
    text = "Run Once",
    onClick = function()
        print("[UI] Run Once clicked")
        -- YOUR CODE HERE
    end,
})

-- Status line at bottom
makeLabel(body, {
    text = "Status: Ready",
    color = Theme.textMuted,
    size = 12,
    sizeDim = UDim2.new(1, 0, 0, 16),
    align = Enum.TextXAlignment.Center,
}).LayoutOrder = 2

-- ========== DRAG WINDOW (standard pattern) ==========
local dragging, dragStart, startPos = false, nil, nil

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

print("[CleanUI] Tutorial loaded — toggle stuff and watch Output")
