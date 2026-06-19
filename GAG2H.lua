-- HAIMIYACH HUB - GROW A GARDEN 2 EDITION
-- Full GUI with FARM tabs (Harvest, Plant, Water, Steal, Sell)
-- Based on your scripts + Haimiyach GUI Template

--// SERVICES
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatsService = nil
pcall(function()
    StatsService = game:GetService("Stats")
end)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// SAFE ENV
local HaimiyachEnv = _G
pcall(function()
    if getgenv then
        HaimiyachEnv = getgenv()
    end
end)

--// OLD GUI CLEANUP
local GUI_NAME = "Haimiyach_GAG2_GUI"
local CoreGui = nil
pcall(function()
    CoreGui = game:GetService("CoreGui")
end)

pcall(function()
    local oldPlayerGui = PlayerGui:FindFirstChild(GUI_NAME)
    if oldPlayerGui then
        oldPlayerGui:Destroy()
    end

    if CoreGui then
        local oldCoreGui = CoreGui:FindFirstChild(GUI_NAME)
        if oldCoreGui then
            oldCoreGui:Destroy()
        end
    end
end)

--// CONFIG
local CONFIG = {
    Title = "HAIMIYACH HUB",
    Subtitle = "Grow A Garden 2",
    Width = 360,
    Height = 380,
    MinWidth = 320,
    MaxWidth = 430,
    MinHeight = 340,
    MaxHeight = 450
}

local THEME = {
    Background = Color3.fromRGB(12, 12, 16),
    Panel = Color3.fromRGB(18, 18, 24),
    Panel2 = Color3.fromRGB(24, 24, 32),
    Button = Color3.fromRGB(30, 30, 40),
    ButtonHover = Color3.fromRGB(38, 38, 50),
    Accent = Color3.fromRGB(0, 210, 255),
    AccentSoft = Color3.fromRGB(0, 120, 165),
    Text = Color3.fromRGB(245, 245, 245),
    Muted = Color3.fromRGB(150, 150, 165),
    Danger = Color3.fromRGB(255, 90, 90),
    Success = Color3.fromRGB(90, 255, 150),
    Stroke = Color3.fromRGB(55, 55, 75)
}

--// STATE
local UIVisible = true
local Minimized = false
local CurrentTab = "FARM"  -- default ke FARM
local UIScaleValue = 1
local ToggleKey = Enum.KeyCode.RightShift

local TabButtons = {}
local Tabs = {}
local ThemedText = {}
local ThemedMuted = {}
local ThemedButtons = {}

--// FARM STATE
local AutoHarvest = false
local AutoPlant = false
local AutoWater = false
local AutoSteal = false
local AutoSell = false

local HarvestLoopRunning = false
local PlantLoopRunning = false
local WaterLoopRunning = false
local StealLoopRunning = false
local SellLoopRunning = false

--// VISUALS STATE (dari template)
local GraphicsMode = "Default"
local FPSBoostActive = false
local HighGraphicsActive = false
local GraphicsBackup = {
    Captured = false,
    Lighting = {},
    Effects = {},
    Atmosphere = {},
    Terrain = {},
    WorkspaceEffects = {},
    WorkspaceEffectRates = {},
    QualityLevel = nil
}
local FPSBoostDescendantConnection = nil
local VisualsFpsValueLabel = nil
local VisualsPingValueLabel = nil
local DashboardFrame = nil

--// ========== FARM FUNCTIONS (dari script2 kamu) ==========

local function getMyPlot()
    local Gardens = Workspace:FindFirstChild("Gardens")
    if not Gardens then return nil end
    local myName = LocalPlayer.Name
    for _, plot in ipairs(Gardens:GetChildren()) do
        -- coba via attribute dulu
        if plot:GetAttribute("Owner") == myName or plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
        -- coba via Sign (dari script kedua)
        local ok, text = pcall(function()
            local sign = plot:FindFirstChild("Signs")
            if sign then
                local garden = sign:FindFirstChild("Garden")
                if garden then
                    local core = garden:FindFirstChild("CorePart")
                    if core then
                        local gui = core:FindFirstChild("SurfaceGui")
                        if gui then
                            local player = gui:FindFirstChild("Player")
                            if player then
                                local label = player:FindFirstChild("TextLabel")
                                if label then
                                    return label.Text
                                end
                            end
                        end
                    end
                end
            end
            return nil
        end)
        if ok and text and text:find(myName) then
            return plot
        end
    end
    return nil
end

local function isGrown(plant)
    if plant:GetAttribute("Grown") == true then return true end
    if plant:GetAttribute("Ready") == true then return true end
    local maxAge = plant:GetAttribute("MaxAge")
    local age = plant:GetAttribute("Age")
    if maxAge and age and age >= maxAge then return true end
    for _, child in ipairs(plant:GetChildren()) do
        if child:IsA("BasePart") and (child.Name:lower():find("fruit") or child.Name:lower():find("ready")) then
            return true
        end
    end
    return false
end

local function isPlanted(plant)
    if plant:GetAttribute("Planted") == true then return true end
    if plant:GetAttribute("Seed") ~= nil then return true end
    for _, child in ipairs(plant:GetChildren()) do
        if child:IsA("BasePart") and (child.Name:lower():find("sprout") or child.Name:lower():find("seed")) then
            return true
        end
    end
    return false
end

local function needsWater(plant)
    if plant:GetAttribute("Watered") == false then return true end
    if plant:GetAttribute("Wet") == false then return true end
    return false
end

local function harvestPlant(plant)
    if not plant then return end
    -- coba remote (dari script pertama)
    local success, networking = pcall(function()
        return require(ReplicatedStorage:FindFirstChild("SharedModules"):FindFirstChild("Networking"))
    end)
    if success and networking and networking.Garden and networking.Garden.CollectFruit then
        local id = plant:GetAttribute("PlantId")
        local fruitid = plant:GetAttribute("FruitId") or ""
        if id then
            networking.Garden.CollectFruit:Fire(id, fruitid)
            return true
        end
    end
    -- coba proximity prompt (dari script kedua)
    local harvestPart = plant:FindFirstChild("HarvestPart")
    if harvestPart then
        local prompt = harvestPart:FindFirstChild("HarvestPrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            fireproximityprompt(prompt)
            return true
        end
    end
    -- coba ClickDetector
    for _, child in ipairs(plant:GetDescendants()) do
        if child:IsA("ClickDetector") then
            child:FireClick()
            return true
        end
    end
    return false
end

local function plantSeed(plot)
    if not plot then return false end
    local detector = plot:FindFirstChildWhichIsA("ClickDetector")
    if detector then
        detector:FireClick()
        return true
    end
    return false
end

local function waterPlot(plot)
    if not plot then return false end
    local detector = plot:FindFirstChildWhichIsA("ClickDetector")
    if detector then
        detector:FireClick()
        return true
    end
    return false
end

local function sellAll()
    -- coba remote sellall
    local success, networking = pcall(function()
        return require(ReplicatedStorage:FindFirstChild("SharedModules"):FindFirstChild("Networking"))
    end)
    if success and networking and networking.NPCS and networking.NPCS.SellAll then
        networking.NPCS.SellAll:Fire()
        return true
    end
    -- coba object Sell
    local sellObj = Workspace:FindFirstChild("Sell")
    if sellObj then
        local detector = sellObj:FindFirstChildWhichIsA("ClickDetector")
        if detector then
            detector:FireClick()
            return true
        end
    end
    return false
end

--// FARM LOOPS

local function HarvestLoop()
    while AutoHarvest and task.wait(0.5) do
        local plot = getMyPlot()
        if not plot then continue end
        local plantsFolder = plot:FindFirstChild("Plants")
        if not plantsFolder then continue end
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            if not plant:IsA("Model") then continue end
            local fruits = plant:FindFirstChild("Fruits")
            if fruits then
                for _, fruit in ipairs(fruits:GetChildren()) do
                    if fruit:IsA("Model") and isGrown(fruit) then
                        harvestPlant(fruit)
                        task.wait(0.2)
                    end
                end
            else
                if isGrown(plant) then
                    harvestPlant(plant)
                    task.wait(0.2)
                end
            end
        end
    end
end

local function PlantLoop()
    while AutoPlant and task.wait(0.8) do
        local plot = getMyPlot()
        if not plot then continue end
        local plantsFolder = plot:FindFirstChild("Plants")
        local hasPlant = false
        if plantsFolder then
            for _, plant in ipairs(plantsFolder:GetChildren()) do
                if plant:IsA("Model") and (isPlanted(plant) or isGrown(plant)) then
                    hasPlant = true
                    break
                end
            end
        end
        if not hasPlant then
            plantSeed(plot)
            task.wait(0.5)
        end
    end
end

local function WaterLoop()
    while AutoWater and task.wait(1) do
        local plot = getMyPlot()
        if not plot then continue end
        local plantsFolder = plot:FindFirstChild("Plants")
        if not plantsFolder then continue end
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            if plant:IsA("Model") and isPlanted(plant) and needsWater(plant) then
                waterPlot(plot)
                task.wait(0.4)
                break
            end
        end
    end
end

local function StealLoop()
    while AutoSteal and task.wait(0.6) do
        -- cek malam
        local night = ReplicatedStorage:FindFirstChild("Night")
        if night and night.Value == false then
            task.wait(2)
            continue
        end
        local Gardens = Workspace:FindFirstChild("Gardens")
        if not Gardens then continue end
        for _, plot in ipairs(Gardens:GetChildren()) do
            local ownerId = plot:GetAttribute("OwnerUserId")
            if ownerId and ownerId ~= LocalPlayer.UserId then
                local plantsFolder = plot:FindFirstChild("Plants")
                if plantsFolder then
                    for _, plant in ipairs(plantsFolder:GetChildren()) do
                        if not plant:IsA("Model") then continue end
                        local fruits = plant:FindFirstChild("Fruits")
                        if fruits then
                            for _, fruit in ipairs(fruits:GetChildren()) do
                                if fruit:IsA("Model") and isGrown(fruit) then
                                    harvestPlant(fruit)
                                    task.wait(0.3)
                                end
                            end
                        else
                            if isGrown(plant) then
                                harvestPlant(plant)
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function SellLoop()
    while AutoSell and task.wait(1.5) do
        sellAll()
        task.wait(2)
    end
end

--// ========== HELPER FUNCTIONS (dari template) ==========

local function SafeParent(gui)
    if CoreGui then
        local ok = pcall(function()
            gui.Parent = CoreGui
        end)
        if ok and gui.Parent == CoreGui then
            return
        end
    end
    gui.Parent = PlayerGui
end

local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or CONFIG.Title),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 2
        })
    end)
end

local function New(className, props)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        if key ~= "Parent" then
            object[key] = value
        end
    end
    if props and props.Parent then
        object.Parent = props.Parent
    end
    return object
end

local function Corner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = parent
    return corner
end

local function Stroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or THEME.Stroke
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.4
    stroke.Parent = parent
    return stroke
end

local function Padding(parent, left, top, right, bottom)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, left or 0)
    padding.PaddingTop = UDim.new(0, top or 0)
    padding.PaddingRight = UDim.new(0, right or 0)
    padding.PaddingBottom = UDim.new(0, bottom or 0)
    padding.Parent = parent
    return padding
end

local function Tween(object, properties, duration)
    local tween = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    )
    tween:Play()
    return tween
end

local function RegisterText(object)
    table.insert(ThemedText, object)
    return object
end

local function RegisterMuted(object)
    table.insert(ThemedMuted, object)
    return object
end

local function RegisterButton(object)
    table.insert(ThemedButtons, object)
    return object
end

local function ClampScale(value)
    value = tonumber(value) or 1
    return math.clamp(value, 0.75, 1.25)
end

--// GUI ROOT
local ScreenGui = New("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})
SafeParent(ScreenGui)

local UIScale = New("UIScale", {
    Scale = UIScaleValue,
    Parent = ScreenGui
})

local MainFrame = New("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, CONFIG.Width, 0, CONFIG.Height),
    Position = UDim2.new(0.5, -CONFIG.Width / 2, 0.5, -CONFIG.Height / 2),
    BackgroundColor3 = THEME.Panel,
    BorderSizePixel = 0,
    Active = true,
    Parent = ScreenGui
})
Corner(MainFrame, 14)
Stroke(MainFrame, THEME.Accent, 1, 0.42)

local TopBar = New("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = THEME.Panel2,
    BorderSizePixel = 0,
    Parent = MainFrame
})
Corner(TopBar, 14)

local TopBarFix = New("Frame", {
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 1, -18),
    BackgroundColor3 = THEME.Panel2,
    BorderSizePixel = 0,
    Parent = TopBar
})

local TitleLabel = RegisterText(New("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -115, 0, 24),
    Position = UDim2.new(0, 14, 0, 6),
    BackgroundTransparency = 1,
    Text = CONFIG.Title,
    TextColor3 = THEME.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar
}))

local SubtitleLabel = RegisterMuted(New("TextLabel", {
    Name = "Subtitle",
    Size = UDim2.new(1, -115, 0, 16),
    Position = UDim2.new(0, 14, 0, 27),
    BackgroundTransparency = 1,
    Text = CONFIG.Subtitle,
    TextColor3 = THEME.Muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar
}))

local MinimizeButton = RegisterButton(New("TextButton", {
    Name = "MinimizeButton",
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -72, 0, 9),
    BackgroundColor3 = THEME.Button,
    Text = "—",
    TextColor3 = THEME.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    AutoButtonColor = false,
    Parent = TopBar
}))
Corner(MinimizeButton, 8)

local HideButton = RegisterButton(New("TextButton", {
    Name = "HideButton",
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -38, 0, 9),
    BackgroundColor3 = THEME.Button,
    Text = "X",
    TextColor3 = THEME.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    AutoButtonColor = false,
    Parent = TopBar
}))
Corner(HideButton, 8)

local Body = New("Frame", {
    Name = "Body",
    Size = UDim2.new(1, -18, 1, -62),
    Position = UDim2.new(0, 9, 0, 54),
    BackgroundTransparency = 1,
    Parent = MainFrame
})

local Sidebar = New("Frame", {
    Name = "Sidebar",
    Size = UDim2.new(0, 112, 1, 0),
    BackgroundTransparency = 1,
    Parent = Body
})

local SidebarLayout = New("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 7),
    Parent = Sidebar
})

local Content = New("Frame", {
    Name = "Content",
    Size = UDim2.new(1, -124, 1, 0),
    Position = UDim2.new(0, 124, 0, 0),
    BackgroundColor3 = THEME.Background,
    BorderSizePixel = 0,
    Parent = Body
})
Corner(Content, 12)
Stroke(Content, THEME.Stroke, 1, 0.65)

--// FLOATING OPEN BUTTON
local FloatingButton = New("TextButton", {
    Name = "OpenButton",
    Size = UDim2.new(0, 118, 0, 38),
    Position = UDim2.new(0, 18, 0.5, -19),
    BackgroundColor3 = THEME.Panel2,
    Text = "HAIMIYACH",
    TextColor3 = THEME.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = false,
    Visible = false,
    Active = true,
    Parent = ScreenGui
})
Corner(FloatingButton, 12)
Stroke(FloatingButton, THEME.Accent, 1, 0.35)

--// DRAG
local function MakeDraggable(frame, handle)
    local dragging = false
    local dragStart = nil
    local startPosition = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end

        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
end

MakeDraggable(MainFrame, TopBar)
MakeDraggable(FloatingButton, FloatingButton)

--// UI COMPONENTS
local function SetButtonState(button, active)
    if active then
        button.BackgroundColor3 = THEME.AccentSoft
        button.TextColor3 = THEME.Text
    else
        button.BackgroundColor3 = THEME.Button
        button.TextColor3 = THEME.Text
    end
end

local function CreateTab(tabName)
    local tabButton = RegisterButton(New("TextButton", {
        Name = tabName .. "TabButton",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = THEME.Button,
        Text = tabName,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        LayoutOrder = #TabButtons + 1,
        Parent = Sidebar
    }))
    Corner(tabButton, 10)
    Stroke(tabButton, THEME.Stroke, 1, 0.72)

    local page = New("ScrollingFrame", {
        Name = tabName .. "Page",
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        Parent = Content
    })

    local layout = New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = page
    })
    Padding(page, 0, 0, 6, 8)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end)

    Tabs[tabName] = page
    TabButtons[tabName] = tabButton

    tabButton.Activated:Connect(function()
        CurrentTab = tabName
        for name, tab in pairs(Tabs) do
            tab.Visible = (name == tabName)
        end
        for name, button in pairs(TabButtons) do
            SetButtonState(button, name == tabName)
        end
    end)

    return page
end

local function AddSection(parent, text)
    local label = RegisterMuted(New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "— " .. text .. " —",
        TextColor3 = THEME.Muted,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent
    }))
    return label
end

local function AddInfo(parent, text)
    local label = RegisterMuted(New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.Muted,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = parent
    }))
    return label
end

local function AddButton(parent, text, callback)
    local button = RegisterButton(New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = THEME.Button,
        Text = text,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = parent
    }))
    Corner(button, 10)
    Stroke(button, THEME.Stroke, 1, 0.72)

    button.MouseEnter:Connect(function()
        if button.BackgroundColor3 == THEME.Button then
            Tween(button, {BackgroundColor3 = THEME.ButtonHover}, 0.12)
        end
    end)

    button.MouseLeave:Connect(function()
        if button.BackgroundColor3 == THEME.ButtonHover then
            Tween(button, {BackgroundColor3 = THEME.Button}, 0.12)
        end
    end)

    button.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            warn("[HAIMIYACH HUB] Button error:", err)
            Notify(CONFIG.Title, "Button error. Check console.", 2)
        end
    end)

    return button
end

local function AddToggle(parent, text, getState, callback)
    local holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = THEME.Button,
        BorderSizePixel = 0,
        Parent = parent
    })
    Corner(holder, 10)
    Stroke(holder, THEME.Stroke, 1, 0.72)

    local label = RegisterText(New("TextLabel", {
        Size = UDim2.new(1, -66, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    }))

    local toggle = New("TextButton", {
        Size = UDim2.new(0, 48, 0, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = THEME.Panel2,
        Text = "",
        AutoButtonColor = false,
        Parent = holder
    })
    Corner(toggle, 12)

    local knob = New("Frame", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(0, 3, 0.5, -9),
        BackgroundColor3 = THEME.Text,
        BorderSizePixel = 0,
        Parent = toggle
    })
    Corner(knob, 9)

    local function Refresh()
        local active = getState()
        if active then
            Tween(toggle, {BackgroundColor3 = THEME.AccentSoft}, 0.12)
            Tween(knob, {Position = UDim2.new(1, -21, 0.5, -9)}, 0.12)
        else
            Tween(toggle, {BackgroundColor3 = THEME.Panel2}, 0.12)
            Tween(knob, {Position = UDim2.new(0, 3, 0.5, -9)}, 0.12)
        end
    end

    holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pcall(callback)
            Refresh()
        end
    end)

    toggle.Activated:Connect(function()
        pcall(callback)
        Refresh()
    end)

    Refresh()
    return holder, Refresh
end

local function AddSlider(parent, text, getter, setter, min, max, step)
    local holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = THEME.Button,
        BorderSizePixel = 0,
        Parent = parent
    })
    Corner(holder, 10)
    Stroke(holder, THEME.Stroke, 1, 0.72)

    local label = RegisterText(New("TextLabel", {
        Size = UDim2.new(1, -18, 0, 24),
        Position = UDim2.new(0, 12, 0, 5),
        BackgroundTransparency = 1,
        Text = text .. ": " .. tostring(getter()),
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    }))

    local bar = New("Frame", {
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 0, 38),
        BackgroundColor3 = THEME.Panel2,
        BorderSizePixel = 0,
        Parent = holder
    })
    Corner(bar, 6)

    local fill = New("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
        Parent = bar
    })
    Corner(fill, 6)

    local knob = New("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, -7, 0.5, -7),
        BackgroundColor3 = THEME.Text,
        BorderSizePixel = 0,
        Parent = bar
    })
    Corner(knob, 7)

    local dragging = false

    local function RoundToStep(value)
        if step and step > 0 then
            return math.floor((value / step) + 0.5) * step
        end
        return value
    end

    local function ApplyValueFromX(x)
        local relative = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local value = RoundToStep(min + ((max - min) * relative))
        value = math.clamp(value, min, max)

        setter(value)

        local current = getter()
        local alpha = math.clamp((current - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -7, 0.5, -7)
        label.Text = text .. ": " .. tostring(current)
    end

    local function Refresh()
        local value = math.clamp(getter(), min, max)
        local alpha = math.clamp((value - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -7, 0.5, -7)
        label.Text = text .. ": " .. tostring(value)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            ApplyValueFromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            ApplyValueFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    Refresh()
    return holder, Refresh
end

--// ========== VISUALS LOGIC (dari template) ==========

local function IsVisualEffect(obj)
    return obj:IsA("ParticleEmitter")
        or obj:IsA("Trail")
        or obj:IsA("Beam")
        or obj:IsA("Smoke")
        or obj:IsA("Fire")
        or obj:IsA("Sparkles")
        or obj:IsA("PointLight")
        or obj:IsA("SpotLight")
        or obj:IsA("SurfaceLight")
end

local function CaptureGraphicsBackup()
    if GraphicsBackup.Captured then return end
    GraphicsBackup.Captured = true

    GraphicsBackup.Lighting = {
        GlobalShadows = Lighting.GlobalShadows,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    }

    pcall(function()
        GraphicsBackup.QualityLevel = settings():GetService("UserGameSettings").SavedQualityLevel
    end)

    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            GraphicsBackup.Terrain = {
                WaterWaveSize = terrain.WaterWaveSize,
                WaterWaveSpeed = terrain.WaterWaveSpeed,
                WaterReflectance = terrain.WaterReflectance,
                WaterTransparency = terrain.WaterTransparency
            }
        end
    end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") or obj:IsA("Atmosphere") then
            GraphicsBackup.Effects[obj] = {
                Enabled = obj:IsA("PostEffect") and obj.Enabled or nil,
                Density = obj:IsA("Atmosphere") and obj.Density or nil,
                Offset = obj:IsA("Atmosphere") and obj.Offset or nil,
                Color = obj:IsA("Atmosphere") and obj.Color or nil,
                Decay = obj:IsA("Atmosphere") and obj.Decay or nil,
                Glare = obj:IsA("Atmosphere") and obj.Glare or nil,
                Haze = obj:IsA("Atmosphere") and obj.Haze or nil
            }
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if IsVisualEffect(obj) then
            GraphicsBackup.WorkspaceEffects[obj] = {
                Enabled = obj.Enabled,
                Rate = obj:IsA("ParticleEmitter") and obj.Rate or nil
            }
        end
    end
end

local function RestoreGraphics()
    CaptureGraphicsBackup()

    if FPSBoostDescendantConnection then
        FPSBoostDescendantConnection:Disconnect()
        FPSBoostDescendantConnection = nil
    end

    local backup = GraphicsBackup.Lighting
    pcall(function()
        Lighting.GlobalShadows = backup.GlobalShadows
        Lighting.Brightness = backup.Brightness
        Lighting.ClockTime = backup.ClockTime
        Lighting.FogEnd = backup.FogEnd
        Lighting.FogStart = backup.FogStart
        Lighting.Ambient = backup.Ambient
        Lighting.OutdoorAmbient = backup.OutdoorAmbient
        Lighting.ColorShift_Top = backup.ColorShift_Top
        Lighting.ColorShift_Bottom = backup.ColorShift_Bottom
        Lighting.EnvironmentDiffuseScale = backup.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = backup.EnvironmentSpecularScale
    end)

    pcall(function()
        if GraphicsBackup.QualityLevel then
            settings():GetService("UserGameSettings").SavedQualityLevel = GraphicsBackup.QualityLevel
        end
    end)

    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain and GraphicsBackup.Terrain then
            for property, value in pairs(GraphicsBackup.Terrain) do
                terrain[property] = value
            end
        end
    end)

    for obj, props in pairs(GraphicsBackup.Effects) do
        if obj and obj.Parent then
            pcall(function()
                if props.Enabled ~= nil and obj:IsA("PostEffect") then
                    obj.Enabled = props.Enabled
                end
                if obj:IsA("Atmosphere") then
                    if props.Density ~= nil then obj.Density = props.Density end
                    if props.Offset ~= nil then obj.Offset = props.Offset end
                    if props.Color ~= nil then obj.Color = props.Color end
                    if props.Decay ~= nil then obj.Decay = props.Decay end
                    if props.Glare ~= nil then obj.Glare = props.Glare end
                    if props.Haze ~= nil then obj.Haze = props.Haze end
                end
            end)
        end
    end

    for obj, props in pairs(GraphicsBackup.WorkspaceEffects) do
        if obj and obj.Parent then
            pcall(function()
                if props.Enabled ~= nil then obj.Enabled = props.Enabled end
                if props.Rate ~= nil and obj:IsA("ParticleEmitter") then obj.Rate = props.Rate end
            end)
        end
    end

    GraphicsMode = "Default"
    FPSBoostActive = false
    HighGraphicsActive = false
end

local function ApplyFPSBoostToObject(obj)
    pcall(function()
        if obj:IsA("ParticleEmitter") then
            obj.Rate = 0
            obj.Enabled = false
        elseif obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            obj.Enabled = false
        end
    end)
end

local function EnableFPSBoost()
    CaptureGraphicsBackup()

    if HighGraphicsActive then
        RestoreGraphics()
    end

    GraphicsMode = "FPS Boost"
    FPSBoostActive = true
    HighGraphicsActive = false

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Brightness = 1
        Lighting.FogEnd = 100000
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        settings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)

    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end
    end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            pcall(function()
                obj.Enabled = false
            end)
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if IsVisualEffect(obj) then
            ApplyFPSBoostToObject(obj)
        end
    end

    if FPSBoostDescendantConnection then
        FPSBoostDescendantConnection:Disconnect()
    end

    FPSBoostDescendantConnection = Workspace.DescendantAdded:Connect(function(obj)
        if FPSBoostActive and IsVisualEffect(obj) then
            task.defer(function()
                ApplyFPSBoostToObject(obj)
            end)
        end
    end)

    Notify(CONFIG.Title, "FPS Boost enabled.", 2)
end

local function EnableHighGraphics()
    CaptureGraphicsBackup()

    if FPSBoostActive then
        RestoreGraphics()
    end

    GraphicsMode = "High Graphics"
    HighGraphicsActive = true
    FPSBoostActive = false

    pcall(function()
        Lighting.GlobalShadows = true
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
        settings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel10
    end)

    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0.25
            terrain.WaterWaveSpeed = 10
            terrain.WaterReflectance = 0.25
            terrain.WaterTransparency = 0.15
        end
    end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            pcall(function()
                obj.Enabled = true
            end)
        elseif obj:IsA("Atmosphere") then
            pcall(function()
                obj.Density = math.clamp(obj.Density, 0.2, 0.45)
                obj.Haze = math.clamp(obj.Haze, 0, 1.5)
                obj.Glare = math.clamp(obj.Glare, 0, 1)
            end)
        end
    end

    Notify(CONFIG.Title, "High Graphics enabled.", 2)
end

local function GetPingText()
    local pingText = "--"
    pcall(function()
        if StatsService and StatsService.Network and StatsService.Network.ServerStatsItem then
            local item = StatsService.Network.ServerStatsItem["Data Ping"]
            if item then
                local value = item:GetValue()
                if value then
                    pingText = tostring(math.floor(value + 0.5)) .. " ms"
                end
            end
        end
    end)
    return pingText
end

local fpsCounter = 0
local fpsTimer = 0
local currentFPS = "--"

RunService.RenderStepped:Connect(function(dt)
    fpsCounter += 1
    fpsTimer += dt

    if fpsTimer >= 0.5 then
        currentFPS = tostring(math.floor(fpsCounter / fpsTimer + 0.5))
        fpsCounter = 0
        fpsTimer = 0

        if VisualsFpsValueLabel then
            VisualsFpsValueLabel.Text = "FPS: " .. currentFPS
        end

        if VisualsPingValueLabel then
            VisualsPingValueLabel.Text = "PING: " .. GetPingText()
        end
    end
end)

--// UI ACTIONS
local function SetMainVisible(state)
    UIVisible = state
    MainFrame.Visible = state
    FloatingButton.Visible = not state
end

local function SetMinimized(state)
    Minimized = state

    if state then
        Body.Visible = false
        MinimizeButton.Text = "+"
        Tween(MainFrame, {Size = UDim2.new(0, CONFIG.Width, 0, 48)}, 0.16)
    else
        Body.Visible = true
        MinimizeButton.Text = "—"
        Tween(MainFrame, {Size = UDim2.new(0, CONFIG.Width, 0, CONFIG.Height)}, 0.16)
    end
end

local function ResetUISettings()
    UIScaleValue = 1
    UIScale.Scale = UIScaleValue
    MainFrame.Size = UDim2.new(0, CONFIG.Width, 0, CONFIG.Height)
    MainFrame.Position = UDim2.new(0.5, -CONFIG.Width / 2, 0.5, -CONFIG.Height / 2)
    ToggleKey = Enum.KeyCode.RightShift
    SetMainVisible(true)
    SetMinimized(false)
end

--// ========== CREATE TABS ==========
local FarmPage = CreateTab("FARM")
local VisualsPage = CreateTab("VISUALS")
local SettingsPage = CreateTab("SETTINGS")

--// ========== FARM TAB ==========
AddSection(FarmPage, "AUTO FARM")

local harvestRefresh, plantRefresh, waterRefresh, stealRefresh, sellRefresh

-- Auto Harvest
local _, refreshHarvest = AddToggle(FarmPage, "Auto Harvest", function()
    return AutoHarvest
end, function()
    AutoHarvest = not AutoHarvest
    if AutoHarvest then
        task.spawn(HarvestLoop)
        Notify(CONFIG.Title, "Auto Harvest ON", 1)
    else
        Notify(CONFIG.Title, "Auto Harvest OFF", 1)
    end
end)
harvestRefresh = refreshHarvest

-- Auto Plant
local _, refreshPlant = AddToggle(FarmPage, "Auto Plant", function()
    return AutoPlant
end, function()
    AutoPlant = not AutoPlant
    if AutoPlant then
        task.spawn(PlantLoop)
        Notify(CONFIG.Title, "Auto Plant ON", 1)
    else
        Notify(CONFIG.Title, "Auto Plant OFF", 1)
    end
end)
plantRefresh = refreshPlant

-- Auto Water
local _, refreshWater = AddToggle(FarmPage, "Auto Water", function()
    return AutoWater
end, function()
    AutoWater = not AutoWater
    if AutoWater then
        task.spawn(WaterLoop)
        Notify(CONFIG.Title, "Auto Water ON", 1)
    else
        Notify(CONFIG.Title, "Auto Water OFF", 1)
    end
end)
waterRefresh = refreshWater

-- Auto Steal
local _, refreshSteal = AddToggle(FarmPage, "Auto Steal (Night)", function()
    return AutoSteal
end, function()
    AutoSteal = not AutoSteal
    if AutoSteal then
        task.spawn(StealLoop)
        Notify(CONFIG.Title, "Auto Steal ON (only night)", 1)
    else
        Notify(CONFIG.Title, "Auto Steal OFF", 1)
    end
end)
stealRefresh = refreshSteal

-- Auto Sell
local _, refreshSell = AddToggle(FarmPage, "Auto Sell", function()
    return AutoSell
end, function()
    AutoSell = not AutoSell
    if AutoSell then
        task.spawn(SellLoop)
        Notify(CONFIG.Title, "Auto Sell ON", 1)
    else
        Notify(CONFIG.Title, "Auto Sell OFF", 1)
    end
end)
sellRefresh = refreshSell

AddSection(FarmPage, "ACTION BUTTONS")

AddButton(FarmPage, "Harvest Once", function()
    local count = 0
    local plot = getMyPlot()
    if plot then
        local plantsFolder = plot:FindFirstChild("Plants")
        if plantsFolder then
            for _, plant in ipairs(plantsFolder:GetChildren()) do
                if plant:IsA("Model") then
                    local fruits = plant:FindFirstChild("Fruits")
                    if fruits then
                        for _, fruit in ipairs(fruits:GetChildren()) do
                            if fruit:IsA("Model") and isGrown(fruit) then
                                harvestPlant(fruit)
                                count += 1
                                task.wait(0.2)
                            end
                        end
                    else
                        if isGrown(plant) then
                            harvestPlant(plant)
                            count += 1
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
    Notify(CONFIG.Title, "Harvested " .. count .. " plants", 2)
end)

AddButton(FarmPage, "Sell Once", function()
    local success = sellAll()
    if success then
        Notify(CONFIG.Title, "Sell triggered", 2)
    else
        Notify(CONFIG.Title, "Sell failed", 2)
    end
end)

AddInfo(FarmPage, "Auto Steal only works at night. Make sure you have a plot.")

--// VISUALS TAB (dari template)
AddSection(VisualsPage, "PERFORMANCE")

DashboardFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = THEME.Button,
    BorderSizePixel = 0,
    Parent = VisualsPage
})
Corner(DashboardFrame, 10)
Stroke(DashboardFrame, THEME.Stroke, 1, 0.72)

VisualsFpsValueLabel = RegisterText(New("TextLabel", {
    Name = "FPSValue",
    Size = UDim2.new(1, -24, 0, 22),
    Position = UDim2.new(0, 12, 0, 6),
    BackgroundTransparency = 1,
    Text = "FPS: --",
    TextColor3 = THEME.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = DashboardFrame
}))

VisualsPingValueLabel = RegisterMuted(New("TextLabel", {
    Name = "PINGValue",
    Size = UDim2.new(1, -24, 0, 22),
    Position = UDim2.new(0, 12, 0, 28),
    BackgroundTransparency = 1,
    Text = "PING: --",
    TextColor3 = THEME.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = DashboardFrame
}))

AddInfo(VisualsPage, "Visuals only changes your local graphics quality. It does not change gameplay logic.")

local FPSBoostRefresh
local HighGraphicsRefresh

local _, refreshFPSBoost = AddToggle(VisualsPage, "FPS BOOST", function()
    return FPSBoostActive
end, function()
    if FPSBoostActive then
        RestoreGraphics()
        Notify(CONFIG.Title, "Graphics restored.", 2)
    else
        EnableFPSBoost()
    end
    if HighGraphicsRefresh then HighGraphicsRefresh() end
end)
FPSBoostRefresh = refreshFPSBoost

local _, refreshHighGraphics = AddToggle(VisualsPage, "HIGH GRAPHICS", function()
    return HighGraphicsActive
end, function()
    if HighGraphicsActive then
        RestoreGraphics()
        Notify(CONFIG.Title, "Graphics restored.", 2)
    else
        EnableHighGraphics()
    end
    if FPSBoostRefresh then FPSBoostRefresh() end
end)
HighGraphicsRefresh = refreshHighGraphics

AddButton(VisualsPage, "RESET VISUALS", function()
    RestoreGraphics()
    if FPSBoostRefresh then FPSBoostRefresh() end
    if HighGraphicsRefresh then HighGraphicsRefresh() end
    Notify(CONFIG.Title, "Visuals reset.", 2)
end)

--// SETTINGS TAB (dari template)
AddSection(SettingsPage, "UI SETTINGS")

AddSlider(SettingsPage, "UI SCALE", function()
    return math.floor(UIScaleValue * 100 + 0.5)
end, function(value)
    UIScaleValue = ClampScale(value / 100)
    UIScale.Scale = UIScaleValue
end, 75, 125, 5)

AddButton(SettingsPage, "RESET UI SETTINGS", function()
    ResetUISettings()
    Notify(CONFIG.Title, "UI settings have been reset.", 2)
end)

AddSection(SettingsPage, "WINDOW")

AddButton(SettingsPage, "MINIMIZE UI", function()
    SetMinimized(not Minimized)
end)

AddButton(SettingsPage, "HIDE UI", function()
    SetMainVisible(false)
end)

AddSection(SettingsPage, "KEYBIND")

local KeybindButton
KeybindButton = AddButton(SettingsPage, "UI KEYBIND: RIGHTSHIFT", function()
    KeybindButton.Text = "PRESS ANY KEY..."

    local connection
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.Keyboard then
            ToggleKey = input.KeyCode
            KeybindButton.Text = "UI KEYBIND: " .. ToggleKey.Name:upper()

            if connection then
                connection:Disconnect()
                connection = nil
            end

            Notify(CONFIG.Title, "Keybind changed to " .. ToggleKey.Name .. ".", 2)
        end
    end)
end)

AddInfo(SettingsPage, "Press your UI keybind to show or hide the hub. Default keybind is RightShift.")

--// OPEN / HIDE BUTTONS
MinimizeButton.Activated:Connect(function()
    SetMinimized(not Minimized)
end)

HideButton.Activated:Connect(function()
    SetMainVisible(false)
end)

FloatingButton.Activated:Connect(function()
    SetMainVisible(true)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == ToggleKey then
        SetMainVisible(not UIVisible)
    end
end)

--// DEFAULT TAB
for name, tab in pairs(Tabs) do
    tab.Visible = (name == CurrentTab)
end

for name, button in pairs(TabButtons) do
    SetButtonState(button, name == CurrentTab)
end

Notify(CONFIG.Title, "HAIMIYACH HUB - GAG2 Loaded!", 3)

--// CLEANUP ON EXIT
pcall(function()
    LocalPlayer:WaitForChild("PlayerGui").ChildRemoved:Connect(function(child)
        if child.Name == GUI_NAME then
            -- stop all loops (optional)
            AutoHarvest = false
            AutoPlant = false
            AutoWater = false
            AutoSteal = false
            AutoSell = false
        end
    end)
end)