-- ============================================================
-- RAYFIELD-STYLE GUI (Tanpa Library Eksternal)
-- Fitur: Walk Speed, Fly Mode, Fly Speed
-- 100% Kustom, tanpa raw url, tanpa download.
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- VARIABEL FLY
-- ============================================================
local flyEnabled = false
local flySpeed = 20
local flyBodyVelocity = nil
local flyGyro = nil
local flyConnection = nil

-- ============================================================
-- FUNGSI FLY
-- ============================================================
local function startFly()
    if not LocalPlayer.Character then return end
    local char = LocalPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = hrp

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyGyro.CFrame = hrp.CFrame
    flyGyro.Parent = hrp

    flyConnection = RunService.Heartbeat:Connect(function()
        if not flyEnabled or not hrp or not hrp.Parent then return end
        local moveDirection = Vector3.new(0, 0, 0)
        local camera = workspace.CurrentCamera
        if not camera then return end

        local forward = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local up = camera.CFrame.UpVector

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - up end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit * flySpeed
        end

        flyBodyVelocity.Velocity = moveDirection
        flyGyro.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + (moveDirection.Magnitude > 0 and moveDirection or forward))
    end)
end

local function stopFly()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end

    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        end
    end
end

-- ============================================================
-- MEMBUAT GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RayfieldStyleGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- WINDOW UTAMA
local Window = Instance.new("Frame")
Window.Name = "MainWindow"
Window.Size = UDim2.new(0, 420, 0, 380)
Window.Position = UDim2.new(0.5, -210, 0.5, -190)
Window.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Window.BorderSizePixel = 0
Window.Active = true
Window.Parent = ScreenGui
local winCorner = Instance.new("UICorner", Window)
winCorner.CornerRadius = UDim.new(0, 12)

-- TITLE BAR
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
local titleCorner = Instance.new("UICorner", TitleBar)
titleCorner.CornerRadius = UDim.new(0, 12)

-- Title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Fly & Speed GUI"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function()
    if flyEnabled then stopFly() end
    ScreenGui:Destroy()
end)

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -80, 0.5, -16)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 22
MinBtn.Parent = TitleBar
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Window:TweenSize(UDim2.new(0, 420, 0, 44), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        TabContainer.Visible = false
        ContentContainer.Visible = false
    else
        Window:TweenSize(UDim2.new(0, 420, 0, 380), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        TabContainer.Visible = true
        ContentContainer.Visible = true
    end
end)

-- DRAG WINDOW
local dragging = false
local dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- TAB BAR
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 0, 40)
TabContainer.Position = UDim2.new(0, 0, 0, 44)
TabContainer.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = Window

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 6)
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabLayout.Parent = TabContainer

local tabs = {}
local tabButtons = {}
local currentTab = nil

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
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
            b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        currentTab = name
    end)

    table.insert(tabs, page)
    tabButtons[name] = btn
    return page
end

-- CONTENT CONTAINER
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, 0, 1, -84)
ContentContainer.Position = UDim2.new(0, 0, 0, 84)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = Window

-- ============================================================
-- FUNGSI ELEMEN UI (Gaya Rayfield)
-- ============================================================

-- Section Header
local function addSection(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(140, 140, 140)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
    return lbl
end

-- Label
local function addLabel(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 26)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
    return lbl
end

-- Slider
local function addSlider(page, label, min, max, default, callback)
    local value = default or min
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)

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
    valLbl.Text = tostring(value)
    valLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    valLbl.Font = Enum.Font.Gotham
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 6)
    bar.Position = UDim2.new(0, 12, 0, 38)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    local barCorner = Instance.new("UICorner", bar)
    barCorner.CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function updateSlider(x)
        local absX = bar.AbsolutePosition.X
        local width = bar.AbsoluteSize.X
        if width <= 0 then return end
        local pct = math.clamp((x - absX) / width, 0, 1)
        value = min + (max - min) * pct
        value = math.floor(value + 0.5)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valLbl.Text = tostring(value)
        if callback then callback(value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)

    return {
        SetValue = function(v)
            v = math.clamp(v, min, max)
            value = v
            local pct = (v - min) / (max - min)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            valLbl.Text = tostring(v)
        end,
        GetValue = function() return value end,
    }
end

-- Toggle (Switch)
local function addToggle(page, label, default, callback)
    local value = default or false
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(0, 50, 0, 28)
    toggle.Position = UDim2.new(1, -62, 0.5, -14)
    toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    toggle.BorderSizePixel = 0
    toggle.Parent = frame
    local toggleCorner = Instance.new("UICorner", toggle)
    toggleCorner.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new(0, 3, 0.5, -11)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)

    local function updateToggle()
        if value then
            toggle.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            knob.Position = UDim2.new(1, -25, 0.5, -11)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            knob.Position = UDim2.new(0, 3, 0.5, -11)
            knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
        end
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
        SetValue = function(v) value = v; updateToggle() end,
        GetValue = function() return value end,
    }
end

-- Button
local function addButton(page, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Parent = page
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    return btn
end

-- ============================================================
-- NOTIFIKASI
-- ============================================================
local function Notify(title, content, duration)
    duration = duration or 3
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 56)
    frame.Position = UDim2.new(1, -300, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = ScreenGui
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)

    local titleLbl = Instance.new("TextLabel", frame)
    titleLbl.Size = UDim2.new(1, -16, 0, 22)
    titleLbl.Position = UDim2.new(0, 8, 0, 4)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title or "Info"
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local contentLbl = Instance.new("TextLabel", frame)
    contentLbl.Size = UDim2.new(1, -16, 0, 24)
    contentLbl.Position = UDim2.new(0, 8, 0, 28)
    contentLbl.BackgroundTransparency = 1
    contentLbl.Text = content or ""
    contentLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    contentLbl.Font = Enum.Font.Gotham
    contentLbl.TextSize = 12
    contentLbl.TextXAlignment = Enum.TextXAlignment.Left

    task.wait(0.1)
    frame:TweenPosition(UDim2.new(1, -300, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    task.wait(duration)
    frame:TweenPosition(UDim2.new(1, 20, 0, 20), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
    task.wait(0.3)
    frame:Destroy()
end

-- ============================================================
-- MEMBUAT TAB DAN KONTEN
-- ============================================================

-- Tab Main
local mainPage = createTab("Main")
addSection(mainPage, "Movement")

local speedSlider = addSlider(mainPage, "Walk Speed", 16, 100, 16, function(v)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end)

local flyToggle = addToggle(mainPage, "Fly Mode", false, function(v)
    flyEnabled = v
    if v then
        if LocalPlayer.Character then
            startFly()
        else
            LocalPlayer.CharacterAdded:Connect(function()
                if flyEnabled then startFly() end
            end)
        end
        Notify("Fly", "Fly mode ON", 2)
    else
        stopFly()
        Notify("Fly", "Fly mode OFF", 2)
    end
end)

local flySpeedSlider = addSlider(mainPage, "Fly Speed", 10, 100, 20, function(v)
    flySpeed = v
end)

addButton(mainPage, "Reset Walk Speed", function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            speedSlider.SetValue(16)
            Notify("Speed", "Reset to default (16)", 2)
        end
    end
end)

-- Tab Info
local infoPage = createTab("Info")
addSection(infoPage, "Information")
addLabel(infoPage, "Controls:")
addLabel(infoPage, "WASD - Move")
addLabel(infoPage, "Space - Fly Up")
addLabel(infoPage, "Shift - Fly Down")
addLabel(infoPage, "")
addLabel(infoPage, "Fly speed bisa diatur di slider.")
addLabel(infoPage, "Toggle Fly untuk aktif/nonaktif.")

-- Default tab aktif
tabs[1].Visible = true
tabButtons["Main"].BackgroundColor3 = Color3.fromRGB(70, 70, 70)
tabButtons["Main"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ============================================================
-- NOTIFIKASI AWAL
-- ============================================================
Notify("GUI Loaded", "Selamat datang! Atur kecepatan jalan atau aktifkan Fly.", 4)

print("[Custom Rayfield-style GUI] Berhasil dimuat.")