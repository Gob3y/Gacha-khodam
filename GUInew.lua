-- ============================================================
-- GUI CUSTOM TANPA LIBRARY EKSTERNAL
-- 100% buatan sendiri, tanpa raw URL, tanpa download apapun.
-- Bisa langsung di-execute di game Roblox.
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MyCustomGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- VARIABEL GLOBAL UNTUK PENYIMPANAN NILAI
-- ============================================================
local Flags = {
    Toggle1 = false,
    Slider1 = 50,
    Dropdown1 = "Opsi 1",
    Input1 = "",
    Keybind1 = Enum.KeyCode.LeftControl,
}

-- ============================================================
-- FUNGSI NOTIFIKASI
-- ============================================================
local function Notify(title, content, duration)
    duration = duration or 3
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(1, -320, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = ScreenGui
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)

    local titleLbl = Instance.new("TextLabel", frame)
    titleLbl.Size = UDim2.new(1, -20, 0, 24)
    titleLbl.Position = UDim2.new(0, 10, 0, 4)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title or "Info"
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local contentLbl = Instance.new("TextLabel", frame)
    contentLbl.Size = UDim2.new(1, -20, 0, 24)
    contentLbl.Position = UDim2.new(0, 10, 0, 30)
    contentLbl.BackgroundTransparency = 1
    contentLbl.Text = content or ""
    contentLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    contentLbl.Font = Enum.Font.Gotham
    contentLbl.TextSize = 12
    contentLbl.TextXAlignment = Enum.TextXAlignment.Left
    contentLbl.TextWrapped = true

    frame:TweenPosition(UDim2.new(1, -320, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    task.wait(duration)
    frame:TweenPosition(UDim2.new(1, 20, 0, 20), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
    task.wait(0.3)
    frame:Destroy()
end

-- ============================================================
-- BUAT WINDOW UTAMA
-- ============================================================
local Window = Instance.new("Frame")
Window.Name = "MainWindow"
Window.Size = UDim2.new(0, 500, 0, 400)
Window.Position = UDim2.new(0.5, -250, 0.5, -200)
Window.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Window.BorderSizePixel = 0
Window.Active = true
Window.Draggable = false -- kita akan buat drag manual
Window.Parent = ScreenGui

local winCorner = Instance.new("UICorner", Window)
winCorner.CornerRadius = UDim.new(0, 12)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
local titleCorner = Instance.new("UICorner", TitleBar)
titleCorner.CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "My Script GUI"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Tombol Close
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -15)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Tombol Minimize
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -80, 0.5, -15)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.Parent = TitleBar
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Window:TweenSize(UDim2.new(0, 500, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        TabContainer.Visible = false
        ContentContainer.Visible = false
    else
        Window:TweenSize(UDim2.new(0, 500, 0, 400), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        TabContainer.Visible = true
        ContentContainer.Visible = true
    end
end)

-- Drag Window
local dragging = false
local dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ============================================================
-- TAB BAR
-- ============================================================
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 0, 40)
TabContainer.Position = UDim2.new(0, 0, 0, 40)
TabContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = Window

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 5)
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabLayout.Parent = TabContainer

local tabs = {}
local currentTab = nil
local tabButtons = {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Parent = TabContainer
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -20, 1, -20)
    page.Position = UDim2.new(0, 10, 0, 10)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 6
    page.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.Visible = false
    page.Parent = ContentContainer

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
    end)

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(tabs) do p.Visible = false end
        for _, b in pairs(tabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            b.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        currentTab = name
    end)

    table.insert(tabs, page)
    tabButtons[name] = btn
    return page
end

-- ============================================================
-- CONTENT AREA
-- ============================================================
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, 0, 1, -80)
ContentContainer.Position = UDim2.new(0, 0, 0, 80)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = Window

-- ============================================================
-- FUNGSI UNTUK MEMBUAT ELEMEN UI
-- ============================================================

-- Section
local function addSection(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
    return lbl
end

-- Label
local function addLabel(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 30)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
    return lbl
end

-- Toggle
local function addToggle(page, label, flag, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(0, 50, 0, 26)
    toggle.Position = UDim2.new(1, -62, 0.5, -13)
    toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    toggle.BorderSizePixel = 0
    toggle.Parent = frame
    local toggleCorner = Instance.new("UICorner", toggle)
    toggleCorner.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)

    local value = Flags[flag] or false

    local function updateToggle()
        if value then
            toggle.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
            knob.Position = UDim2.new(1, -23, 0.5, -10)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            knob.Position = UDim2.new(0, 3, 0.5, -10)
            knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
        end
        Flags[flag] = value
        if callback then callback(value) end
    end

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            value = not value
            updateToggle()
        end
    end)

    updateToggle()
    return {
        Set = function(v) value = v; updateToggle() end,
        Get = function() return value end,
    }
end

-- Slider
local function addSlider(page, label, min, max, default, flag, suffix, callback)
    min = min or 0
    max = max or 100
    suffix = suffix or ""
    local value = Flags[flag] or default or min

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, -12, 0, 24)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, -12, 0, 24)
    valLbl.Position = UDim2.new(0.6, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(value) .. suffix
    valLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    valLbl.Font = Enum.Font.Gotham
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 8)
    bar.Position = UDim2.new(0, 12, 0, 36)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    local barCorner = Instance.new("UICorner", bar)
    barCorner.CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function updateSlider(x)
        local absX = bar.AbsolutePosition.X
        local width = bar.AbsoluteSize.X
        local pct = math.clamp((x - absX) / width, 0, 1)
        value = min + (max - min) * pct
        value = math.floor(value + 0.5)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valLbl.Text = tostring(value) .. suffix
        Flags[flag] = value
        if callback then callback(value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)

    return {
        Set = function(v) value = math.clamp(v, min, max); updateSlider(bar.AbsolutePosition.X + (value - min)/(max - min) * bar.AbsoluteSize.X) end,
        Get = function() return value end,
    }
end

-- Dropdown
local function addDropdown(page, label, options, default, flag, callback)
    options = options or {}
    local value = Flags[flag] or default or options[1]

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.55, -12, 0, 30)
    btn.Position = UDim2.new(0.45, 0, 0.5, -15)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    btn.Text = value
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = frame
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 6)

    local dropdown = Instance.new("ScrollingFrame")
    dropdown.Size = UDim2.new(0.55, -12, 0, 0)
    dropdown.Position = UDim2.new(0.45, 0, 0, 40)
    dropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    dropdown.BorderSizePixel = 0
    dropdown.Visible = false
    dropdown.ClipsDescendants = true
    dropdown.ScrollBarThickness = 4
    dropdown.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    dropdown.AutomaticCanvasSize = Enum.AutomaticSize.Y
    dropdown.CanvasSize = UDim2.fromOffset(0, 0)
    dropdown.Parent = frame
    local dropCorner = Instance.new("UICorner", dropdown)
    dropCorner.CornerRadius = UDim.new(0, 6)

    local dropLayout = Instance.new("UIListLayout")
    dropLayout.Padding = UDim.new(0, 2)
    dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropLayout.Parent = dropdown

    local function rebuildDropdown()
        for _, child in ipairs(dropdown:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, -4, 0, 30)
            optBtn.Position = UDim2.new(0, 2, 0, 0)
            optBtn.BackgroundColor3 = (opt == value) and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40)
            optBtn.BorderSizePixel = 0
            optBtn.Text = opt
            optBtn.TextColor3 = (opt == value) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 13
            optBtn.Parent = dropdown
            local c = Instance.new("UICorner", optBtn)
            c.CornerRadius = UDim.new(0, 4)
            optBtn.MouseButton1Click:Connect(function()
                value = opt
                btn.Text = value
                Flags[flag] = value
                dropdown.Visible = false
                dropdown.Size = UDim2.new(0.55, -12, 0, 0)
                if callback then callback(value) end
                rebuildDropdown()
            end)
        end
        dropLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local h = math.min(150, dropLayout.AbsoluteContentSize.Y + 8)
            dropdown.CanvasSize = UDim2.fromOffset(0, dropLayout.AbsoluteContentSize.Y + 8)
            if dropdown.Visible then
                dropdown.Size = UDim2.new(0.55, -12, 0, h)
            end
        end)
    end

    btn.MouseButton1Click:Connect(function()
        dropdown.Visible = not dropdown.Visible
        if dropdown.Visible then
            local h = math.min(150, dropLayout.AbsoluteContentSize.Y + 8)
            dropdown.Size = UDim2.new(0.55, -12, 0, h)
        else
            dropdown.Size = UDim2.new(0.55, -12, 0, 0)
        end
    end)

    rebuildDropdown()
    return {
        Set = function(v) value = v; btn.Text = v; Flags[flag] = v; rebuildDropdown() end,
        Get = function() return value end,
    }
end

-- Input
local function addInput(page, label, placeholder, flag, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.55, -12, 0, 30)
    box.Position = UDim2.new(0.45, 0, 0.5, -15)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    box.BorderSizePixel = 0
    box.PlaceholderText = placeholder or ""
    box.Text = Flags[flag] or ""
    box.TextColor3 = Color3.fromRGB(220, 220, 220)
    box.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.Parent = frame
    local boxCorner = Instance.new("UICorner", box)
    boxCorner.CornerRadius = UDim.new(0, 6)

    box.FocusLost:Connect(function()
        Flags[flag] = box.Text
        if callback then callback(box.Text) end
    end)

    return box
end

-- Button
local function addButton(page, label, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 36)
    btn.Position = UDim2.new(0, 10, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Parent = page
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    return btn
end

-- Keybind
local function addKeybind(page, label, flag, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.4, -12, 0, 30)
    btn.Position = UDim2.new(0.6, 0, 0.5, -15)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    local key = Flags[flag] or Enum.KeyCode.LeftControl
    btn.Text = key.Name
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = frame
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 6)

    local listening = false
    btn.MouseButton1Click:Connect(function()
        listening = not listening
        if listening then
            btn.Text = "Press any key..."
            btn.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
        else
            btn.Text = key.Name
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if listening and not gameProcessed then
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                key = input.KeyCode
                Flags[flag] = key
                btn.Text = key.Name
                btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                listening = false
                if callback then callback(key) end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                -- ignore mouse clicks
            end
        end
    end)

    return {
        Get = function() return key end,
    }
end

-- ============================================================
-- BUAT TAB-TAB
-- ============================================================

-- Tab: Main
local mainPage = createTab("Main")
addSection(mainPage, "Pengaturan")
addToggle(mainPage, "Aktifkan Fitur", "Toggle1", function(v) print("Toggle:", v) end)
addSlider(mainPage, "Kecepatan", 0, 100, 50, "Slider1", "%", function(v) print("Slider:", v) end)
addDropdown(mainPage, "Pilih Opsi", {"Opsi 1", "Opsi 2", "Opsi 3"}, "Opsi 1", "Dropdown1", function(v) print("Dropdown:", v) end)
addInput(mainPage, "Masukkan Nama", "Nama Anda...", "Input1", function(v) print("Input:", v) end)
addButton(mainPage, "Klik Saya!", function()
    Notify("Action", "Tombol diklik!", 3)
end)

-- Tab: Other
local otherPage = createTab("Other")
addSection(otherPage, "Informasi")
addLabel(otherPage, "Ini adalah label")
addLabel(otherPage, "Paragraf panjang bisa ditampilkan di sini.")
addLabel(otherPage, "Fitur lengkap tanpa library eksternal.")

-- Tab: Keybinds
local keyPage = createTab("Keybinds")
addSection(keyPage, "Shortcut")
addKeybind(keyPage, "Toggle GUI", "Keybind1", function(key)
    if key then
        -- kita akan handle toggle di bawah
    end
end)
addLabel(keyPage, "Tekan tombol lalu pilih key.")

-- Default aktifkan tab pertama
if #tabs > 0 then
    tabs[1].Visible = true
    tabButtons["Main"].BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    tabButtons["Main"].TextColor3 = Color3.fromRGB(255, 255, 255)
    currentTab = "Main"
end

-- ============================================================
-- KEYBIND GLOBAL UNTUK TOGGLE GUI
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local key = Flags["Keybind1"] or Enum.KeyCode.LeftControl
    if input.KeyCode == key then
        local visible = Window.Visible
        Window.Visible = not visible
        if not visible then
            Notify("GUI", "Ditampilkan", 2)
        end
    end
end)

-- ============================================================
-- NOTIFIKASI AWAL
-- ============================================================
Notify("GUI Loaded", "Selamat datang! Tekan LeftControl (atau keybind) untuk toggle.", 5)

print("[Custom GUI] Berhasil dimuat tanpa library eksternal.")