-- HAIMIYACH HUB - VISUALS & SETTINGS ONLY
-- Clean horizontal-tab UI. Old HAIMIYACH GUIs are removed before the new UI is created.

--// Services
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local StatsService = nil
pcall(function()
    StatsService = game:GetService("Stats")
end)

local CoreGui = nil
pcall(function()
    CoreGui = game:GetService("CoreGui")
end)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UIParent = CoreGui or PlayerGui

--// Remove old GUI first
local function IsHaimiyachGui(obj)
    if not obj or not obj:IsA("ScreenGui") then
        return false
    end

    local name = string.lower(obj.Name or "")
    return name:find("haimiyach") ~= nil
        or name:find("haimiya") ~= nil
        or name == string.lower("Haimiyach_Premium_GUI")
        or name == string.lower("Haimiyach_Hub_Custom_UI")
        or name == string.lower("Haimiyach_Hub_Show_Button")
        or name == string.lower("Haimiyach_FPS_Boost_Dashboard")
end

local function CleanOldGui()
    local containers = {PlayerGui}
    if CoreGui then
        table.insert(containers, CoreGui)
    end

    for _, container in ipairs(containers) do
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                if IsHaimiyachGui(child) then
                    child:Destroy()
                end
            end
        end)
    end
end

CleanOldGui()

task.wait(0.1)
CleanOldGui()

--// Notification
local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "HAIMIYACH HUB"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 2
        })
    end)
end

--// Graphics / Visual states
local GraphicsMode = "Default"
local FPSBoostActive = false
local HighGraphicsActive = false
local FPSBoostDescendantConnection = nil

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

local function SafeSetProperty(obj, prop, value)
    pcall(function()
        obj[prop] = value
    end)
end

local function CaptureGraphicsBackup()
    if GraphicsBackup.Captured then return end
    GraphicsBackup.Captured = true

    local lightingProps = {
        "GlobalShadows",
        "Brightness",
        "ClockTime",
        "FogStart",
        "FogEnd",
        "ExposureCompensation",
        "EnvironmentDiffuseScale",
        "EnvironmentSpecularScale",
        "ShadowSoftness",
        "Ambient",
        "OutdoorAmbient",
        "Technology"
    }

    for _, prop in ipairs(lightingProps) do
        pcall(function()
            GraphicsBackup.Lighting[prop] = Lighting[prop]
        end)
    end

    pcall(function()
        GraphicsBackup.QualityLevel = UserSettings():GetService("UserGameSettings").SavedQualityLevel
    end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            pcall(function()
                GraphicsBackup.Effects[obj] = obj.Enabled
            end)
        elseif obj:IsA("Atmosphere") then
            pcall(function()
                GraphicsBackup.Atmosphere[obj] = {
                    Density = obj.Density,
                    Offset = obj.Offset,
                    Color = obj.Color,
                    Decay = obj.Decay,
                    Glare = obj.Glare,
                    Haze = obj.Haze
                }
            end)
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for _, prop in ipairs({"Decoration", "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed"}) do
            pcall(function()
                GraphicsBackup.Terrain[prop] = terrain[prop]
            end)
        end
    end
end

local function CaptureWorkspaceEffectBackup(obj)
    if not obj then return end

    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        if GraphicsBackup.WorkspaceEffects[obj] == nil then
            pcall(function()
                GraphicsBackup.WorkspaceEffects[obj] = obj.Enabled
            end)
        end

        if obj:IsA("ParticleEmitter") and GraphicsBackup.WorkspaceEffectRates[obj] == nil then
            pcall(function()
                GraphicsBackup.WorkspaceEffectRates[obj] = obj.Rate
            end)
        end
    end
end

local function DisableClientVisualEffect(obj)
    if not obj then return end

    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        CaptureWorkspaceEffectBackup(obj)
        SafeSetProperty(obj, "Enabled", false)

        if obj:IsA("ParticleEmitter") then
            SafeSetProperty(obj, "Rate", 0)
        end
    end
end

local function RemoveHaimiyachHDEffects()
    for _, name in ipairs({
        "Haimiyach_HD_Bloom",
        "Haimiyach_HD_ColorCorrection",
        "Haimiyach_HD_SunRays",
        "Haimiyach_HD_DepthOfField",
        "Haimiyach_HD_Atmosphere"
    }) do
        local obj = Lighting:FindFirstChild(name)
        if obj then
            pcall(function()
                obj:Destroy()
            end)
        end
    end
end

local function RestoreDefaultGraphics()
    CaptureGraphicsBackup()
    RemoveHaimiyachHDEffects()

    if FPSBoostDescendantConnection then
        pcall(function()
            FPSBoostDescendantConnection:Disconnect()
        end)
        FPSBoostDescendantConnection = nil
    end

    for prop, value in pairs(GraphicsBackup.Lighting) do
        SafeSetProperty(Lighting, prop, value)
    end

    for obj, enabled in pairs(GraphicsBackup.Effects) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Enabled", enabled)
        end
    end

    for obj, values in pairs(GraphicsBackup.Atmosphere) do
        if obj and obj.Parent then
            for prop, value in pairs(values) do
                SafeSetProperty(obj, prop, value)
            end
        end
    end

    for obj, enabled in pairs(GraphicsBackup.WorkspaceEffects) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Enabled", enabled)
        end
    end

    for obj, rate in pairs(GraphicsBackup.WorkspaceEffectRates) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Rate", rate)
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for prop, value in pairs(GraphicsBackup.Terrain) do
            SafeSetProperty(terrain, prop, value)
        end
    end

    pcall(function()
        if GraphicsBackup.QualityLevel ~= nil then
            UserSettings():GetService("UserGameSettings").SavedQualityLevel = GraphicsBackup.QualityLevel
        end
    end)

    FPSBoostActive = false
    HighGraphicsActive = false
    GraphicsMode = "Default"
end

local function ApplyFPSBoostGraphics()
    CaptureGraphicsBackup()
    RemoveHaimiyachHDEffects()

    FPSBoostActive = true
    HighGraphicsActive = false
    GraphicsMode = "FPS Boost"

    SafeSetProperty(Lighting, "GlobalShadows", false)
    SafeSetProperty(Lighting, "Brightness", 1)
    SafeSetProperty(Lighting, "FogStart", 0)
    SafeSetProperty(Lighting, "FogEnd", 100000)
    SafeSetProperty(Lighting, "ExposureCompensation", 0)
    SafeSetProperty(Lighting, "EnvironmentDiffuseScale", 0)
    SafeSetProperty(Lighting, "EnvironmentSpecularScale", 0)
    SafeSetProperty(Lighting, "ShadowSoftness", 0)

    pcall(function()
        Lighting.Technology = Enum.Technology.Voxel
    end)

    pcall(function()
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            SafeSetProperty(obj, "Enabled", false)
        elseif obj:IsA("Atmosphere") then
            SafeSetProperty(obj, "Density", 0)
            SafeSetProperty(obj, "Haze", 0)
            SafeSetProperty(obj, "Glare", 0)
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        SafeSetProperty(terrain, "Decoration", false)
        SafeSetProperty(terrain, "WaterReflectance", 0)
        SafeSetProperty(terrain, "WaterTransparency", 1)
        SafeSetProperty(terrain, "WaterWaveSize", 0)
        SafeSetProperty(terrain, "WaterWaveSpeed", 0)
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        DisableClientVisualEffect(obj)
    end

    if FPSBoostDescendantConnection then
        pcall(function()
            FPSBoostDescendantConnection:Disconnect()
        end)
        FPSBoostDescendantConnection = nil
    end

    FPSBoostDescendantConnection = Workspace.DescendantAdded:Connect(function(obj)
        if FPSBoostActive then
            task.defer(function()
                DisableClientVisualEffect(obj)
            end)
        end
    end)
end

local function ApplyHighGraphics()
    CaptureGraphicsBackup()
    RemoveHaimiyachHDEffects()

    FPSBoostActive = false
    HighGraphicsActive = true
    GraphicsMode = "High Graphics"

    if FPSBoostDescendantConnection then
        pcall(function()
            FPSBoostDescendantConnection:Disconnect()
        end)
        FPSBoostDescendantConnection = nil
    end

    for obj, enabled in pairs(GraphicsBackup.Effects) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Enabled", enabled)
        end
    end

    for obj, values in pairs(GraphicsBackup.Atmosphere) do
        if obj and obj.Parent then
            for prop, value in pairs(values) do
                SafeSetProperty(obj, prop, value)
            end
        end
    end

    for obj, enabled in pairs(GraphicsBackup.WorkspaceEffects) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Enabled", enabled)
        end
    end

    for obj, rate in pairs(GraphicsBackup.WorkspaceEffectRates) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Rate", rate)
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        SafeSetProperty(terrain, "Decoration", true)
        SafeSetProperty(terrain, "WaterReflectance", 0.35)
        SafeSetProperty(terrain, "WaterTransparency", 0.25)
        SafeSetProperty(terrain, "WaterWaveSize", 0.12)
        SafeSetProperty(terrain, "WaterWaveSpeed", 8)
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    SafeSetProperty(part, "CastShadow", true)
                end
            end
        end
    end

    SafeSetProperty(Lighting, "GlobalShadows", true)
    SafeSetProperty(Lighting, "Brightness", 3)
    SafeSetProperty(Lighting, "ClockTime", 14.25)
    SafeSetProperty(Lighting, "FogStart", 0)
    SafeSetProperty(Lighting, "FogEnd", 100000)
    SafeSetProperty(Lighting, "ExposureCompensation", 0.16)
    SafeSetProperty(Lighting, "EnvironmentDiffuseScale", 1)
    SafeSetProperty(Lighting, "EnvironmentSpecularScale", 1)
    SafeSetProperty(Lighting, "ShadowSoftness", 0.18)
    SafeSetProperty(Lighting, "Ambient", Color3.fromRGB(105, 105, 105))
    SafeSetProperty(Lighting, "OutdoorAmbient", Color3.fromRGB(150, 150, 150))

    pcall(function()
        Lighting.Technology = Enum.Technology.ShadowMap
    end)

    pcall(function()
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel10
    end)

    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Name = "Haimiyach_HD_Atmosphere"
    atmosphere.Density = 0.24
    atmosphere.Offset = 0.05
    atmosphere.Color = Color3.fromRGB(220, 230, 255)
    atmosphere.Decay = Color3.fromRGB(90, 110, 140)
    atmosphere.Glare = 0.24
    atmosphere.Haze = 0.65
    atmosphere.Parent = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Name = "Haimiyach_HD_Bloom"
    bloom.Intensity = 0.48
    bloom.Size = 34
    bloom.Threshold = 0.95
    bloom.Parent = Lighting

    local color = Instance.new("ColorCorrectionEffect")
    color.Name = "Haimiyach_HD_ColorCorrection"
    color.Brightness = 0.04
    color.Contrast = 0.18
    color.Saturation = 0.16
    color.TintColor = Color3.fromRGB(255, 252, 244)
    color.Parent = Lighting

    local rays = Instance.new("SunRaysEffect")
    rays.Name = "Haimiyach_HD_SunRays"
    rays.Intensity = 0.095
    rays.Spread = 0.78
    rays.Parent = Lighting

    local depth = Instance.new("DepthOfFieldEffect")
    depth.Name = "Haimiyach_HD_DepthOfField"
    depth.FarIntensity = 0.08
    depth.FocusDistance = 80
    depth.InFocusRadius = 70
    depth.NearIntensity = 0.02
    depth.Parent = Lighting
end

local FPSDashboardGui = nil
local FPSDashboard = nil
local DashboardFPSLabel = nil
local DashboardPingLabel = nil

local VisualsFPSValueLabel = nil
local VisualsPingValueLabel = nil
local ToggleRefreshers = {}

local function GetRealPingText()
    local pingText = "N/A"

    pcall(function()
        if StatsService and StatsService.Network and StatsService.Network.ServerStatsItem then
            local item = StatsService.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if item then
                local valueString = item:GetValueString()
                if valueString and valueString ~= "" then
                    local firstNumber = tonumber(string.match(valueString, "[%d%.]+"))
                    if firstNumber then
                        pingText = tostring(math.floor(firstNumber + 0.5)) .. " ms"
                    else
                        pingText = valueString
                    end
                    return
                end

                local value = item:GetValue()
                if value then
                    pingText = tostring(math.floor(value + 0.5)) .. " ms"
                end
            end
        end
    end)

    return pingText
end

local CurrentFPS = 0
local FrameCounter = 0
local LastFPSUpdate = os.clock()

local function RefreshToggleControls()
    for _, refresh in ipairs(ToggleRefreshers) do
        pcall(refresh)
    end
end

local function SetDashboardVisible(state)
    if FPSDashboard then
        FPSDashboard.Visible = state and true or false
    end
end

local function SetFPSBoostEnabled(state)
    if state then
        ApplyFPSBoostGraphics()
        SetDashboardVisible(true)
    else
        if FPSBoostActive then
            RestoreDefaultGraphics()
        end
        SetDashboardVisible(false)
    end
    RefreshToggleControls()
end

local function SetHighGraphicsEnabled(state)
    if state then
        ApplyHighGraphics()
        SetDashboardVisible(false)
    else
        if HighGraphicsActive then
            RestoreDefaultGraphics()
        end
        SetDashboardVisible(false)
    end
    RefreshToggleControls()
end

--// UI helpers
local Theme = {
    Background = Color3.fromRGB(18, 18, 18),
    Top = Color3.fromRGB(28, 28, 28),
    Panel = Color3.fromRGB(22, 22, 22),
    Panel2 = Color3.fromRGB(32, 32, 32),
    Button = Color3.fromRGB(34, 34, 34),
    ButtonActive = Color3.fromRGB(235, 235, 235),
    Text = Color3.fromRGB(245, 245, 245),
    DarkText = Color3.fromRGB(28, 28, 28),
    Muted = Color3.fromRGB(170, 170, 170),
    Stroke = Color3.fromRGB(70, 70, 70),
    Accent = Color3.fromRGB(235, 235, 235)
}

local function AddCorner(obj, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = obj
    return corner
end

local function AddStroke(obj, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Stroke
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.45
    stroke.Parent = obj
    return stroke
end

local function MakeText(parent, text, size, pos, font, textSize, color, align)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.Size = size
    label.Position = pos
    label.Font = font or Enum.Font.GothamSemibold
    label.TextSize = textSize or 14
    label.TextColor3 = color or Theme.Text
    label.TextXAlignment = align or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 10
    label.Parent = parent
    return label
end

local function MakeButtonRaw(parent, text, size, pos)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.Text = text or ""
    button.Size = size
    button.Position = pos
    button.BackgroundColor3 = Theme.Button
    button.TextColor3 = Theme.Text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.BorderSizePixel = 0
    button.ZIndex = 12
    button.Parent = parent
    AddCorner(button, 16)
    return button
end

--// Create main ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Haimiyach_Hub_Custom_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999995
pcall(function()
    ScreenGui.Parent = UIParent
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = PlayerGui
end

local UIScaleValue = UserInputService.TouchEnabled and 0.90 or 1

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 680, 0, 370)
MainFrame.Position = UDim2.new(0.5, -340, 0.5, -185)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
AddCorner(MainFrame, 18)
AddStroke(MainFrame, Theme.Stroke, 2, 0.15)

local UIScaleObject = Instance.new("UIScale")
UIScaleObject.Name = "HaimiyachHubUIScale"
UIScaleObject.Scale = UIScaleValue
UIScaleObject.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 58)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Theme.Top
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 6
TitleBar.Parent = MainFrame
AddCorner(TitleBar, 18)

local TitleMask = Instance.new("Frame")
TitleMask.Name = "TitleMask"
TitleMask.Size = UDim2.new(1, 0, 0, 18)
TitleMask.Position = UDim2.new(0, 0, 1, -18)
TitleMask.BackgroundColor3 = Theme.Top
TitleMask.BorderSizePixel = 0
TitleMask.ZIndex = 7
TitleMask.Parent = TitleBar

MakeText(TitleBar, "HAIMIYACH HUB", UDim2.new(1, -150, 1, 0), UDim2.new(0, 22, 0, 0), Enum.Font.GothamBlack, 19, Theme.Text, Enum.TextXAlignment.Left)

local MinimizeButton = MakeButtonRaw(TitleBar, "-", UDim2.new(0, 42, 0, 42), UDim2.new(1, -102, 0, 8))
MinimizeButton.TextSize = 22
MinimizeButton.BackgroundTransparency = 1

local CloseButton = MakeButtonRaw(TitleBar, "X", UDim2.new(0, 42, 0, 42), UDim2.new(1, -54, 0, 8))
CloseButton.TextSize = 18
CloseButton.BackgroundTransparency = 1

local Separator = Instance.new("Frame")
Separator.Size = UDim2.new(1, 0, 0, 1)
Separator.Position = UDim2.new(0, 0, 0, 58)
Separator.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Separator.BackgroundTransparency = 0.25
Separator.BorderSizePixel = 0
Separator.ZIndex = 8
Separator.Parent = MainFrame

local TabHolder = Instance.new("Frame")
TabHolder.Name = "TabHolder"
TabHolder.Size = UDim2.new(1, -30, 0, 56)
TabHolder.Position = UDim2.new(0, 15, 0, 70)
TabHolder.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TabHolder.BorderSizePixel = 0
TabHolder.ZIndex = 6
TabHolder.Parent = MainFrame
AddCorner(TabHolder, 18)
AddStroke(TabHolder, Color3.fromRGB(52, 52, 52), 1, 0.25)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Padding = UDim.new(0, 14)
TabLayout.Parent = TabHolder

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingLeft = UDim.new(0, 18)
TabPadding.PaddingRight = UDim.new(0, 18)
TabPadding.Parent = TabHolder

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -30, 1, -146)
ContentFrame.Position = UDim2.new(0, 15, 0, 136)
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ContentFrame.BorderSizePixel = 0
ContentFrame.ClipsDescendants = true
ContentFrame.ZIndex = 5
ContentFrame.Parent = MainFrame
AddCorner(ContentFrame, 16)
AddStroke(ContentFrame, Color3.fromRGB(58, 58, 58), 1, 0.35)

local Pages = {}
local TabButtons = {}
local CurrentTab = nil

local function CreatePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -28, 1, -24)
    page.Position = UDim2.new(0, 14, 0, 12)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.ZIndex = 8
    page.Parent = ContentFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    Pages[name] = page
    return page
end

local function SelectTab(name)
    CurrentTab = name

    for tabName, page in pairs(Pages) do
        page.Visible = tabName == name
    end

    for tabName, button in pairs(TabButtons) do
        local selected = tabName == name
        button.BackgroundColor3 = selected and Theme.ButtonActive or Theme.Button
        button.TextColor3 = selected and Theme.DarkText or Theme.Text
    end
end

local function CreateTab(name)
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Size = UDim2.new(0, 210, 0, 40)
    button.BackgroundColor3 = Theme.Button
    button.TextColor3 = Theme.Text
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = name
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.ZIndex = 12
    button.Parent = TabHolder
    AddCorner(button, 18)

    button.MouseButton1Click:Connect(function()
        SelectTab(name)
    end)

    TabButtons[name] = button
    return CreatePage(name)
end

local function CreateSection(parent, title)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Text = "— " .. string.upper(title) .. " —"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Theme.Muted
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 10
    label.Parent = parent
    return label
end

local function CreateCard(parent, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height or 62)
    card.BackgroundColor3 = Theme.Panel2
    card.BorderSizePixel = 0
    card.ZIndex = 9
    card.Parent = parent
    AddCorner(card, 14)
    return card
end

local function CreateButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 52)
    button.BackgroundColor3 = Theme.Panel2
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = string.upper(text)
    button.TextColor3 = Theme.Text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.ZIndex = 10
    button.Parent = parent
    AddCorner(button, 14)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(42, 42, 42)}):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Panel2}):Play()
    end)

    button.MouseButton1Click:Connect(function()
        pcall(callback)
    end)

    return button
end

local function CreateToggle(parent, text, getter, setter)
    local row = CreateCard(parent, 52)

    local label = MakeText(row, string.upper(text), UDim2.new(1, -120, 1, 0), UDim2.new(0, 18, 0, 0), Enum.Font.GothamBold, 14, Theme.Text, Enum.TextXAlignment.Left)
    label.ZIndex = 11

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 70, 0, 30)
    switch.Position = UDim2.new(1, -88, 0.5, -15)
    switch.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
    switch.BorderSizePixel = 0
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.ZIndex = 12
    switch.Parent = row
    AddCorner(switch, 15)
    AddStroke(switch, Color3.fromRGB(92, 92, 92), 1, 0.3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 24, 0, 24)
    knob.Position = UDim2.new(0, 3, 0.5, -12)
    knob.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
    knob.BorderSizePixel = 0
    knob.ZIndex = 13
    knob.Parent = switch
    AddCorner(knob, 12)

    local function refresh()
        local enabled = getter() and true or false
        local knobPos = enabled and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12)
        local knobColor = enabled and Color3.fromRGB(238, 238, 238) or Color3.fromRGB(135, 135, 135)
        local bgColor = enabled and Color3.fromRGB(54, 54, 54) or Color3.fromRGB(30, 30, 30)
        TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = knobPos, BackgroundColor3 = knobColor}):Play()
        TweenService:Create(switch, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = bgColor}):Play()
    end

    switch.MouseButton1Click:Connect(function()
        local newValue = not (getter() and true or false)
        setter(newValue)
        refresh()
    end)

    table.insert(ToggleRefreshers, refresh)
    refresh()
    return row
end

local function CreateSlider(parent, text, minValue, maxValue, defaultValue, callback)
    local row = CreateCard(parent, 78)

    local valueLabel = MakeText(row, string.upper(text) .. ": " .. tostring(defaultValue), UDim2.new(1, -26, 0, 26), UDim2.new(0, 18, 0, 10), Enum.Font.GothamBold, 14, Theme.Text, Enum.TextXAlignment.Left)
    valueLabel.ZIndex = 11

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -36, 0, 8)
    bar.Position = UDim2.new(0, 18, 0, 48)
    bar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    bar.BorderSizePixel = 0
    bar.ZIndex = 11
    bar.Parent = row
    AddCorner(bar, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 12
    fill.Parent = bar
    AddCorner(fill, 4)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.BackgroundColor3 = Color3.fromRGB(238, 238, 238)
    knob.BorderSizePixel = 0
    knob.ZIndex = 13
    knob.Parent = bar
    AddCorner(knob, 11)

    local dragging = false
    local currentValue = defaultValue

    local function setFromAlpha(alpha, fireCallback)
        alpha = math.clamp(alpha, 0, 1)
        local value = math.floor((minValue + (maxValue - minValue) * alpha) + 0.5)
        currentValue = value
        valueLabel.Text = string.upper(text) .. ": " .. tostring(value)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -11, 0.5, -11)
        if fireCallback then
            callback(value)
        end
    end

    local function updateFromInput(input)
        local relative = (input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
        setFromAlpha(relative, true)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromInput(input)
        end
    end)

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local startAlpha = (defaultValue - minValue) / (maxValue - minValue)
    setFromAlpha(startAlpha, false)

    return {
        SetValue = function(value, fireCallback)
            local alpha = (value - minValue) / (maxValue - minValue)
            setFromAlpha(alpha, fireCallback)
        end,
        GetValue = function()
            return currentValue
        end
    }
end

--// Show button after hide
local ShowButtonGui = Instance.new("ScreenGui")
ShowButtonGui.Name = "Haimiyach_Hub_Show_Button"
ShowButtonGui.ResetOnSpawn = false
ShowButtonGui.IgnoreGuiInset = true
ShowButtonGui.DisplayOrder = 999996
pcall(function()
    ShowButtonGui.Parent = UIParent
end)
if not ShowButtonGui.Parent then
    ShowButtonGui.Parent = PlayerGui
end

local ShowButton = Instance.new("TextButton")
ShowButton.Size = UDim2.new(0, 54, 0, 54)
ShowButton.Position = UDim2.new(1, -76, 0.5, -27)
ShowButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
ShowButton.TextColor3 = Theme.Text
ShowButton.Text = "H"
ShowButton.Font = Enum.Font.GothamBlack
ShowButton.TextSize = 22
ShowButton.BorderSizePixel = 0
ShowButton.AutoButtonColor = false
ShowButton.Visible = false
ShowButton.Active = true
ShowButton.Draggable = true
ShowButton.Parent = ShowButtonGui
AddCorner(ShowButton, 16)
AddStroke(ShowButton, Color3.fromRGB(115, 115, 115), 1.5, 0.15)

local function SetHubVisible(state)
    MainFrame.Visible = state and true or false
    ShowButton.Visible = not MainFrame.Visible
end

ShowButton.MouseButton1Click:Connect(function()
    SetHubVisible(true)
end)

--// FPS dashboard
local function CreateFPSDashboard()
    if FPSDashboardGui and FPSDashboardGui.Parent then
        pcall(function()
            FPSDashboardGui:Destroy()
        end)
    end

    FPSDashboardGui = Instance.new("ScreenGui")
    FPSDashboardGui.Name = "Haimiyach_FPS_Boost_Dashboard"
    FPSDashboardGui.ResetOnSpawn = false
    FPSDashboardGui.IgnoreGuiInset = true
    FPSDashboardGui.DisplayOrder = 999998
    pcall(function()
        FPSDashboardGui.Parent = UIParent
    end)
    if not FPSDashboardGui.Parent then
        FPSDashboardGui.Parent = PlayerGui
    end

    FPSDashboard = Instance.new("Frame")
    FPSDashboard.Name = "FPSBoostDashboard"
    FPSDashboard.Size = UDim2.new(0, 150, 0, 70)
    FPSDashboard.Position = UDim2.new(1, -180, 0, 16)
    FPSDashboard.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    FPSDashboard.BackgroundTransparency = 0.22
    FPSDashboard.BorderSizePixel = 0
    FPSDashboard.Visible = false
    FPSDashboard.Active = true
    FPSDashboard.Draggable = true
    FPSDashboard.Parent = FPSDashboardGui
    AddCorner(FPSDashboard, 16)
    AddStroke(FPSDashboard, Color3.fromRGB(90, 90, 90), 1, 0.42)

    MakeText(FPSDashboard, "FPS BOOST", UDim2.new(1, -20, 0, 20), UDim2.new(0, 12, 0, 7), Enum.Font.GothamBlack, 12, Theme.Text, Enum.TextXAlignment.Left)
    DashboardFPSLabel = MakeText(FPSDashboard, "FPS: --", UDim2.new(1, -20, 0, 18), UDim2.new(0, 12, 0, 32), Enum.Font.GothamSemibold, 12, Theme.Text, Enum.TextXAlignment.Left)
    DashboardPingLabel = MakeText(FPSDashboard, "PING: --", UDim2.new(1, -20, 0, 18), UDim2.new(0, 12, 0, 50), Enum.Font.GothamSemibold, 12, Theme.Text, Enum.TextXAlignment.Left)
end

--// Pages
local VisualsPage = CreateTab("VISUALS")
local SettingsPage = CreateTab("SETTINGS")

-- VISUALS page
local performanceCard = CreateCard(VisualsPage, 78)
MakeText(performanceCard, "PERFORMANCE", UDim2.new(0, 210, 1, 0), UDim2.new(0, 18, 0, 0), Enum.Font.GothamBold, 14, Theme.Text, Enum.TextXAlignment.Left)
VisualsFPSValueLabel = MakeText(performanceCard, "FPS: --", UDim2.new(0, 200, 0, 28), UDim2.new(0.42, 0, 0, 13), Enum.Font.GothamSemibold, 14, Theme.Text, Enum.TextXAlignment.Left)
VisualsPingValueLabel = MakeText(performanceCard, "PING: --", UDim2.new(0, 200, 0, 28), UDim2.new(0.42, 0, 0, 39), Enum.Font.GothamSemibold, 14, Theme.Muted, Enum.TextXAlignment.Left)

CreateToggle(VisualsPage, "FPS BOOST", function()
    return FPSBoostActive
end, function(value)
    SetFPSBoostEnabled(value)
    Notify("FPS Boost", FPSBoostActive and "Enabled" or "Disabled", 1.5)
end)

CreateToggle(VisualsPage, "HIGH GRAPHICS", function()
    return HighGraphicsActive
end, function(value)
    SetHighGraphicsEnabled(value)
    Notify("High Graphics", HighGraphicsActive and "Enabled" or "Disabled", 1.5)
end)

-- SETTINGS page
CreateSection(SettingsPage, "UI SETTINGS")
local ScaleSlider = CreateSlider(SettingsPage, "UI SCALE", 65, 115, math.floor(UIScaleValue * 100 + 0.5), function(value)
    UIScaleValue = math.clamp(value / 100, 0.65, 1.15)
    UIScaleObject.Scale = UIScaleValue
end)

CreateButton(SettingsPage, "RESET UI SETTINGS", function()
    UIScaleValue = UserInputService.TouchEnabled and 0.90 or 1
    UIScaleObject.Scale = UIScaleValue
    if ScaleSlider then
        ScaleSlider.SetValue(math.floor(UIScaleValue * 100 + 0.5), false)
    end
    Notify("UI Settings", "UI settings have been reset.", 1.5)
end)

CreateSection(SettingsPage, "WINDOW")

local Minimized = false
local NormalSize = MainFrame.Size
local NormalContentVisible = true

local function SetHubMinimized(state)
    Minimized = state and true or false
    if Minimized then
        NormalSize = MainFrame.Size
        NormalContentVisible = ContentFrame.Visible
        TabHolder.Visible = false
        ContentFrame.Visible = false
        MainFrame.Size = UDim2.new(0, 680, 0, 58)
        MinimizeButton.Text = "+"
    else
        MainFrame.Size = NormalSize
        TabHolder.Visible = true
        ContentFrame.Visible = NormalContentVisible
        MinimizeButton.Text = "-"
    end
end

CreateButton(SettingsPage, "MINIMIZE UI", function()
    SetHubMinimized(true)
end)

CreateButton(SettingsPage, "HIDE UI", function()
    SetHubVisible(false)
end)

CreateSection(SettingsPage, "KEYBIND")

local KeybindOptions = {
    {Name = "K", Key = Enum.KeyCode.K},
    {Name = "RightShift", Key = Enum.KeyCode.RightShift},
    {Name = "LeftAlt", Key = Enum.KeyCode.LeftAlt},
    {Name = "RightAlt", Key = Enum.KeyCode.RightAlt},
    {Name = "LeftControl", Key = Enum.KeyCode.LeftControl},
    {Name = "Space", Key = Enum.KeyCode.Space}
}
local UIKeybindIndex = 1
local UIKeybind = KeybindOptions[UIKeybindIndex].Key

local KeybindButton = nil
KeybindButton = CreateButton(SettingsPage, "UI KEYBIND: " .. KeybindOptions[UIKeybindIndex].Name, function()
    UIKeybindIndex = UIKeybindIndex + 1
    if UIKeybindIndex > #KeybindOptions then
        UIKeybindIndex = 1
    end
    UIKeybind = KeybindOptions[UIKeybindIndex].Key
    KeybindButton.Text = "UI KEYBIND: " .. string.upper(KeybindOptions[UIKeybindIndex].Name)
    Notify("UI Keybind", "Keybind set to " .. KeybindOptions[UIKeybindIndex].Name .. ".", 1.5)
end)

--// Button hooks
MinimizeButton.MouseButton1Click:Connect(function()
    SetHubMinimized(not Minimized)
end)

CloseButton.MouseButton1Click:Connect(function()
    SetHubVisible(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == UIKeybind then
        SetHubVisible(not MainFrame.Visible)
    end
end)

--// Start dashboard and stats loop
CreateFPSDashboard()
SetDashboardVisible(false)
SelectTab("VISUALS")
RefreshToggleControls()

RunService.RenderStepped:Connect(function()
    FrameCounter = FrameCounter + 1
    local now = os.clock()
    local delta = now - LastFPSUpdate

    if delta >= 1 then
        CurrentFPS = math.floor((FrameCounter / delta) + 0.5)
        FrameCounter = 0
        LastFPSUpdate = now

        local ping = GetRealPingText()
        local fpsText = "FPS: " .. tostring(CurrentFPS)
        local pingText = "PING: " .. tostring(ping)

        if VisualsFPSValueLabel then
            VisualsFPSValueLabel.Text = fpsText
        end
        if VisualsPingValueLabel then
            VisualsPingValueLabel.Text = pingText
        end
        if DashboardFPSLabel then
            DashboardFPSLabel.Text = fpsText
        end
        if DashboardPingLabel then
            DashboardPingLabel.Text = pingText
        end
    end
end)

Notify("HAIMIYACH HUB", "Visuals and Settings loaded.", 2)
