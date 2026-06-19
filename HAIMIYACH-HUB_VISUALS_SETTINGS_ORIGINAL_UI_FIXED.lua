-- HAIMIYACH HUB (FINAL BUILD - THREE FLING MODES + TOUCH FLING + FE EMOTE MENU)

-- SERVICES
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local StatsService = nil
pcall(function() StatsService = game:GetService("Stats") end)

local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- SAFE GLOBAL ENV FOR EXECUTOR COMPATIBILITY
HaimiyachEnv = _G
pcall(function()
    if getgenv then
        HaimiyachEnv = getgenv()
    end
end)

-- REMOVE OLD GUI / CLEAN PREVIOUS HAIMIYACH UI FIRST
local OLD_GUI_NAME = "Haimiyach_Premium_GUI"
local CoreGui = nil
pcall(function()
    CoreGui = game:GetService("CoreGui")
end)

local function DestroyOldHaimiyachGui(container)
    if not container then return end
    local names = {
        "Haimiyach_Premium_GUI",
        "Haimiyach_Hub_Custom_UI",
        "Haimiyach_Hub_Show_Button",
        "Haimiyach_FPS_Boost_Dashboard",
        "Haimiyach_FOV_Circle"
    }
    for _, guiName in ipairs(names) do
        pcall(function()
            local old = container:FindFirstChild(guiName)
            if old then old:Destroy() end
        end)
    end
end

DestroyOldHaimiyachGui(PlayerGui)
DestroyOldHaimiyachGui(CoreGui)

-- STATE
local SelectedTargets = {}
local PlayerCheckboxes = {}
local ThemedButtons = {}
local ThemedInputs = {}
local ThemedPickers = {}
local CurrentWidth = 300
local CurrentHeight = 330
local CurrentThemeName = "DARK"

-- GRAPHICS / VISUAL QUALITY STATE
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

-- UTILITY STATE
local AntiAFKActive = false
local AntiAFKConnection = nil
local StartFling
local StopFling

local AntiFlingActive = false
local AntiFlingConnection = nil
local LastSafeCFrame = nil
local AntiFlingButton
local ToggleAntiFling

-- MENU 3 MOVEMENT STATE
local FlyActive = false
local InfJumpActive = false
local FlyConnection = nil
local InfJumpConnection = nil
local FlySpeed = 55
local MoveSpeed = 16
local FlyButton = nil
local InfJumpButton = nil
local FlySpeedLabel = nil
local MoveSpeedLabel = nil
local Menu3Scroll = nil
local AntiKnockbackActive = false
local AntiKnockbackConnection = nil
local AntiRagdollActive = false
local AntiRagdollConnections = {}
local NoclipActive = false
local NoclipConnection = nil

-- STATE AIMBOT
local AimbotData = {
    Enabled = false,
    ESP = false,
    ShowFOV = false,
    FOV = 150,
    Smoothness = 0.02,
    Sensitivity = 1.5,
    TeamCheck = true,
    VisibleCheck = true,
    DamageIndicator = false
}
local AimbotLoop = nil
local AimbotLockedTarget = nil
local ESPList = {}

-- Damage indicator state for FOV circle
local DamageIndicatorArrow = nil
local DamageIndicatorFlashUntil = 0
local DamageIndicatorWorldPosition = nil
local DamageIndicatorConnections = {}
local LastHumanoidHealth = nil
local DamageIndicatorBtn = nil

local function ClearOldESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            for _, obj in ipairs(plr.Character:GetDescendants()) do
                if obj:IsA("Highlight") and obj.Name == "HaimiyachESP" then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end
    ESPList = {}
end
ClearOldESP()

-- THEMES (lengkap)
local Themes = {
    ["DARK"] = {
        Background = Color3.fromRGB(22, 22, 22),
        Top = Color3.fromRGB(29, 29, 29),
        Panel = Color3.fromRGB(24, 24, 24),
        Panel2 = Color3.fromRGB(32, 32, 32),
        Entry = Color3.fromRGB(38, 38, 38),
        Button = Color3.fromRGB(36, 36, 36),
        Button2 = Color3.fromRGB(230, 230, 230),
        Accent = Color3.fromRGB(95, 95, 95),
        Accent2 = Color3.fromRGB(230, 230, 230),
        Text = Color3.fromRGB(242, 242, 242),
        Muted = Color3.fromRGB(170, 170, 170)
    },
    ["CYAN"] = {
        Background = Color3.fromRGB(8, 18, 22),
        Top = Color3.fromRGB(5, 14, 18),
        Panel = Color3.fromRGB(13, 37, 43),
        Panel2 = Color3.fromRGB(16, 48, 56),
        Entry = Color3.fromRGB(21, 58, 66),
        Button = Color3.fromRGB(27, 82, 94),
        Button2 = Color3.fromRGB(35, 110, 125),
        Accent = Color3.fromRGB(72, 235, 255),
        Accent2 = Color3.fromRGB(120, 255, 230),
        Text = Color3.fromRGB(245, 255, 255),
        Muted = Color3.fromRGB(180, 210, 215)
    },
    ["RED DARK"] = {
        Background = Color3.fromRGB(25, 20, 22),
        Top = Color3.fromRGB(16, 12, 14),
        Panel = Color3.fromRGB(38, 30, 32),
        Panel2 = Color3.fromRGB(48, 38, 40),
        Entry = Color3.fromRGB(58, 45, 48),
        Button = Color3.fromRGB(75, 45, 48),
        Button2 = Color3.fromRGB(105, 55, 60),
        Accent = Color3.fromRGB(255, 90, 100),
        Accent2 = Color3.fromRGB(255, 135, 120),
        Text = Color3.fromRGB(255, 245, 245),
        Muted = Color3.fromRGB(220, 190, 190)
    },
    ["BLUE"] = {
        Background = Color3.fromRGB(13, 20, 38),
        Top = Color3.fromRGB(8, 14, 28),
        Panel = Color3.fromRGB(20, 32, 58),
        Panel2 = Color3.fromRGB(25, 42, 78),
        Entry = Color3.fromRGB(32, 50, 90),
        Button = Color3.fromRGB(42, 70, 120),
        Button2 = Color3.fromRGB(55, 95, 155),
        Accent = Color3.fromRGB(85, 165, 255),
        Accent2 = Color3.fromRGB(130, 200, 255),
        Text = Color3.fromRGB(245, 250, 255),
        Muted = Color3.fromRGB(185, 205, 235)
    },
    ["PURPLE"] = {
        Background = Color3.fromRGB(27, 18, 42),
        Top = Color3.fromRGB(18, 12, 30),
        Panel = Color3.fromRGB(42, 28, 62),
        Panel2 = Color3.fromRGB(55, 36, 82),
        Entry = Color3.fromRGB(68, 45, 98),
        Button = Color3.fromRGB(82, 52, 122),
        Button2 = Color3.fromRGB(105, 70, 155),
        Accent = Color3.fromRGB(195, 125, 255),
        Accent2 = Color3.fromRGB(230, 170, 255),
        Text = Color3.fromRGB(252, 245, 255),
        Muted = Color3.fromRGB(215, 190, 230)
    },
    ["GREEN"] = {
        Background = Color3.fromRGB(15, 30, 22),
        Top = Color3.fromRGB(10, 22, 16),
        Panel = Color3.fromRGB(23, 48, 34),
        Panel2 = Color3.fromRGB(30, 65, 45),
        Entry = Color3.fromRGB(38, 78, 55),
        Button = Color3.fromRGB(45, 95, 65),
        Button2 = Color3.fromRGB(58, 125, 82),
        Accent = Color3.fromRGB(90, 255, 160),
        Accent2 = Color3.fromRGB(150, 255, 190),
        Text = Color3.fromRGB(245, 255, 250),
        Muted = Color3.fromRGB(190, 225, 205)
    },
    ["GOLD"] = {
        Background = Color3.fromRGB(36, 28, 14),
        Top = Color3.fromRGB(24, 18, 8),
        Panel = Color3.fromRGB(54, 42, 20),
        Panel2 = Color3.fromRGB(70, 54, 26),
        Entry = Color3.fromRGB(86, 66, 32),
        Button = Color3.fromRGB(105, 78, 35),
        Button2 = Color3.fromRGB(135, 100, 45),
        Accent = Color3.fromRGB(255, 205, 85),
        Accent2 = Color3.fromRGB(255, 230, 135),
        Text = Color3.fromRGB(255, 250, 235),
        Muted = Color3.fromRGB(225, 205, 165)
    },
    ["PINK"] = {
        Background = Color3.fromRGB(42, 20, 34),
        Top = Color3.fromRGB(28, 12, 22),
        Panel = Color3.fromRGB(62, 30, 50),
        Panel2 = Color3.fromRGB(78, 38, 62),
        Entry = Color3.fromRGB(95, 48, 75),
        Button = Color3.fromRGB(118, 55, 90),
        Button2 = Color3.fromRGB(150, 70, 112),
        Accent = Color3.fromRGB(255, 125, 195),
        Accent2 = Color3.fromRGB(255, 175, 220),
        Text = Color3.fromRGB(255, 245, 252),
        Muted = Color3.fromRGB(230, 190, 210)
    },
    ["ORANGE"] = {
        Background = Color3.fromRGB(42, 25, 12),
        Top = Color3.fromRGB(28, 16, 8),
        Panel = Color3.fromRGB(62, 36, 18),
        Panel2 = Color3.fromRGB(80, 45, 22),
        Entry = Color3.fromRGB(96, 55, 28),
        Button = Color3.fromRGB(122, 68, 34),
        Button2 = Color3.fromRGB(155, 85, 42),
        Accent = Color3.fromRGB(255, 145, 65),
        Accent2 = Color3.fromRGB(255, 190, 115),
        Text = Color3.fromRGB(255, 248, 240),
        Muted = Color3.fromRGB(230, 200, 175)
    }

}

local function ClampByte(value)
    value = tonumber(value) or 0
    if value < 0 then value = 0 end
    if value > 255 then value = 255 end
    return math.floor(value + 0.5)
end

local function BlendColor(a, b, alpha)
    alpha = math.clamp(tonumber(alpha) or 0, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * alpha,
        a.G + (b.G - a.G) * alpha,
        a.B + (b.B - a.B) * alpha
    )
end

local function ColorToRGB255(color)
    return ClampByte(color.R * 255), ClampByte(color.G * 255), ClampByte(color.B * 255)
end

local function ColorToHexString(color)
    local r, g, b = ColorToRGB255(color)
    return string.format("#%02X%02X%02X", r, g, b)
end

local CustomAccentColor = Color3.fromRGB(58, 99, 103)
local function BuildCustomTheme(accent)
    accent = accent or CustomAccentColor
    local black = Color3.fromRGB(22, 22, 22)
    local deep = Color3.fromRGB(18, 18, 18)
    local panel = Color3.fromRGB(24, 24, 24)
    local panel2 = Color3.fromRGB(31, 31, 31)
    local entry = Color3.fromRGB(38, 38, 38)
    return {
        Background = black,
        Top = deep,
        Panel = panel,
        Panel2 = panel2,
        Entry = entry,
        Button = Color3.fromRGB(36, 36, 36),
        Button2 = BlendColor(accent, Color3.fromRGB(255, 255, 255), 0.12),
        Accent = accent,
        Accent2 = BlendColor(accent, Color3.fromRGB(255, 255, 255), 0.35),
        Text = Color3.fromRGB(242, 242, 242),
        Muted = Color3.fromRGB(170, 170, 170)
    }
end
Themes["CUSTOM"] = BuildCustomTheme(CustomAccentColor)

-- UTILS
local function GetTheme()
    return Themes[CurrentThemeName] or Themes["DARK"]
end

local HaimiyachNotificationsEnabled = true -- true = use Roblox native notifications

local function Notify(title, text, duration)
    if not HaimiyachNotificationsEnabled then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

-- AIMBOT FOV CIRCLE / CROSSHAIR OVERLAY
local FOVCircleGui = nil
local FOVCircleFrame = nil
local FOVCircleStroke = nil
local FOVCircleConnection = nil

local function EnsureFOVCircle()
    if FOVCircleGui and FOVCircleGui.Parent and FOVCircleFrame and FOVCircleFrame.Parent then
        return
    end

    pcall(function()
        local old = PlayerGui:FindFirstChild("Haimiyach_FOV_Circle")
        if old then old:Destroy() end
    end)
    if CoreGui then
        pcall(function()
            local old = CoreGui:FindFirstChild("Haimiyach_FOV_Circle")
            if old then old:Destroy() end
        end)
    end

    FOVCircleGui = Instance.new("ScreenGui")
    FOVCircleGui.Name = "Haimiyach_FOV_Circle"
    FOVCircleGui.ResetOnSpawn = false
    FOVCircleGui.IgnoreGuiInset = true
    FOVCircleGui.DisplayOrder = 999999

    FOVCircleFrame = Instance.new("Frame")
    FOVCircleFrame.Name = "Circle"
    FOVCircleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FOVCircleFrame.BackgroundTransparency = 1
    FOVCircleFrame.BorderSizePixel = 0
    FOVCircleFrame.Visible = false
    FOVCircleFrame.Parent = FOVCircleGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = FOVCircleFrame

    FOVCircleStroke = Instance.new("UIStroke")
    FOVCircleStroke.Name = "Stroke"
    FOVCircleStroke.Thickness = 2
    FOVCircleStroke.Transparency = 0.08
    FOVCircleStroke.Color = GetTheme().Accent2 or Color3.fromRGB(255, 255, 255)
    FOVCircleStroke.Parent = FOVCircleFrame

    DamageIndicatorArrow = Instance.new("TextLabel")
    DamageIndicatorArrow.Name = "DamageIndicatorArrow"
    DamageIndicatorArrow.AnchorPoint = Vector2.new(0.5, 0.5)
    DamageIndicatorArrow.Size = UDim2.fromOffset(26, 26)
    DamageIndicatorArrow.BackgroundTransparency = 1
    DamageIndicatorArrow.BorderSizePixel = 0
    DamageIndicatorArrow.Text = "^"
    DamageIndicatorArrow.Font = Enum.Font.GothamBlack
    DamageIndicatorArrow.TextSize = 22
    DamageIndicatorArrow.TextColor3 = Color3.fromRGB(255, 140, 0)
    DamageIndicatorArrow.TextStrokeTransparency = 0.25
    DamageIndicatorArrow.Visible = false
    DamageIndicatorArrow.ZIndex = 999999
    DamageIndicatorArrow.Parent = FOVCircleGui

    local parentOk = false
    if CoreGui then
        parentOk = pcall(function()
            FOVCircleGui.Parent = CoreGui
        end)
    end
    if not parentOk then
        FOVCircleGui.Parent = PlayerGui
    end
end

local function UpdateFOVCircle()
    if not FOVCircleFrame then return end

    Camera = Workspace.CurrentCamera or Camera
    local viewport = Camera and Camera.ViewportSize or Vector2.new(0, 0)
    local radius = math.clamp(tonumber(AimbotData.FOV) or 150, 20, 1000)

    FOVCircleFrame.Size = UDim2.fromOffset(radius * 2, radius * 2)
    FOVCircleFrame.Position = UDim2.fromOffset(viewport.X / 2, viewport.Y / 2)
    FOVCircleFrame.Visible = AimbotData.ShowFOV == true

    local damageActive = AimbotData.DamageIndicator and os.clock() < DamageIndicatorFlashUntil

    if FOVCircleStroke then
        if damageActive then
            FOVCircleStroke.Color = Color3.fromRGB(255, 140, 0) -- damage detected
        elseif AimbotLockedTarget and AimbotLockedTarget.Parent and AimbotData.Enabled then
            FOVCircleStroke.Color = Color3.fromRGB(255, 60, 60) -- locked target / aim active
        else
            FOVCircleStroke.Color = Color3.fromRGB(255, 255, 255) -- idle / no target
        end
    end

    if DamageIndicatorArrow then
        DamageIndicatorArrow.Visible = false

        if damageActive and AimbotData.ShowFOV and DamageIndicatorWorldPosition and Camera then
            local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
            local worldOffset = DamageIndicatorWorldPosition - Camera.CFrame.Position

            if worldOffset.Magnitude > 0.05 then
                -- Camera-space damage direction.
                -- Roblox camera faces -Z, so:
                -- front = top, right = right, left = left, behind = bottom.
                local relative = Camera.CFrame:PointToObjectSpace(DamageIndicatorWorldPosition)
                local angle = math.atan2(relative.X, -relative.Z)

                local dir = Vector2.new(
                    math.sin(angle),
                    -math.cos(angle)
                )

                if dir.Magnitude > 0 then
                    dir = dir.Unit
                    local arrowDistance = radius + 18
                    local arrowPos = center + dir * arrowDistance

                    DamageIndicatorArrow.Position = UDim2.fromOffset(arrowPos.X, arrowPos.Y)
                    DamageIndicatorArrow.Rotation = math.deg(angle)
                    DamageIndicatorArrow.TextColor3 = Color3.fromRGB(255, 140, 0)
                    DamageIndicatorArrow.Visible = true
                end
            end
        end
    end
end

local function SetFOVCircleVisible(state)
    AimbotData.ShowFOV = state == true
    EnsureFOVCircle()
    UpdateFOVCircle()

    if AimbotData.ShowFOV then
        if not FOVCircleConnection then
            FOVCircleConnection = RunService.RenderStepped:Connect(UpdateFOVCircle)
        end
    else
        if FOVCircleConnection then
            pcall(function() FOVCircleConnection:Disconnect() end)
            FOVCircleConnection = nil
        end
        if FOVCircleFrame then
            FOVCircleFrame.Visible = false
        end
        if DamageIndicatorArrow then
            DamageIndicatorArrow.Visible = false
        end
    end
end

local function New(className, props)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    return obj
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency or 0, Parent = parent })
end

local function Padding(parent, left, right, top, bottom)
    return New("UIPadding", { PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0), PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or 0), Parent = parent })
end

local function MakeButton(text, parent, callback)
    local theme = GetTheme()
    local parentZ = 1
    if parent and parent:IsA("GuiObject") then
        parentZ = parent.ZIndex + 5
    end
    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = theme.Button or theme.Panel or Color3.fromRGB(25, 25, 25),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = theme.Text or Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextWrapped = true,
        AutoButtonColor = true,
        Active = true,
        Selectable = true,
        ZIndex = parentZ,
        Parent = parent
    })
    Corner(btn, 12)
    local btnStroke = Stroke(btn, theme.Accent or Color3.fromRGB(0, 255, 255), 1, 0.62)
    table.insert(ThemedButtons, { Button = btn, Stroke = btnStroke })
    local debounce = false
    local function FireButton()
        if debounce then return end
        debounce = true
        pcall(function() if callback then callback() end end)
        task.delay(0.15, function() debounce = false end)
    end
    local lastFire = 0
    local touchPress = false
    local function TryFire(source)
        if source == "Activated" and touchPress then return end
        local now = os.clock()
        if now - lastFire < 0.35 then return end
        lastFire = now
        FireButton()
    end
    pcall(function() btn.Activated:Connect(function() TryFire("Activated") end) end)
    pcall(function() btn.MouseButton1Click:Connect(function() TryFire("MouseButton1Click") end) end)
    pcall(function()
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                touchPress = true
                TryFire("Touch")
            end
        end)
    end)
    pcall(function()
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                task.delay(0.2, function() touchPress = false end)
            end
        end)
    end)
    return btn
end

local function MakeNumberInput(parent, labelText, defaultValue, minValue, maxValue, decimals, callback)
    local theme = GetTheme()
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local label = New("TextLabel", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.55, -6, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText .. ": " .. tostring(defaultValue),
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })
    local box = New("TextBox", {
        Position = UDim2.new(0.55, 6, 0, 4),
        Size = UDim2.new(0.45, -6, 1, -8),
        BackgroundColor3 = theme.Button,
        BorderSizePixel = 0,
        Text = tostring(defaultValue),
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        ClearTextOnFocus = false,
        Parent = row
    })
    Corner(box, 8)
    local boxStroke = Stroke(box, theme.Accent, 1, 0.75)
    table.insert(ThemedInputs, { Label = label, Box = box, Stroke = boxStroke })
    local function FormatNumber(value)
        if decimals then return string.format("%."..decimals.."f", value) end
        return tostring(math.floor(value))
    end
    local function SetValue(value, silent)
        local num = tonumber(value) or defaultValue or 0
        num = math.clamp(num, minValue, maxValue)
        if decimals then num = tonumber(string.format("%."..decimals.."f", num)) else num = math.floor(num) end
        box.Text = FormatNumber(num)
        label.Text = labelText .. ": " .. FormatNumber(num)
        if callback and not silent then callback(num) end
        return num
    end
    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if not num then box.Text = FormatNumber(defaultValue) Notify("Input Error", "Please enter a valid number.", 1.5) return end
        SetValue(num, false)
    end)
    SetValue(defaultValue, true)
    return label, box, SetValue
end

local function MakeOptionPicker(parent, labelText, options, defaultValue, callback)
    local theme = GetTheme()
    local selectedValue = defaultValue or options[1]
    local holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local row = New("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = holder })
    local label = New("TextLabel", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.45, -6, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText .. ":",
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })
    local picker = New("TextButton", {
        Position = UDim2.new(0.45, 6, 0, 4),
        Size = UDim2.new(0.55, -6, 1, -8),
        BackgroundColor3 = theme.Button,
        BorderSizePixel = 0,
        Text = selectedValue .. " v",
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Parent = row
    })
    Corner(picker, 8)
    local pickerStroke = Stroke(picker, theme.Accent, 1, 0.75)
    local dropdown = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundColor3 = theme.Panel2,
        Visible = false,
        ClipsDescendants = true,
        Parent = holder
    })
    Corner(dropdown, 8)
    local dropdownStroke = Stroke(dropdown, theme.Accent, 1, 0.8)
    local list = New("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), Parent = dropdown })
    Padding(dropdown, 6, 6, 6, 6)
    local opened = false
    local function SetOpen(state)
        opened = state
        dropdown.Visible = opened
        if opened then
            holder.Size = UDim2.new(1, 0, 0, 46 + (#options * 32) + 14)
            dropdown.Size = UDim2.new(1, 0, 0, (#options * 32) + 12)
            picker.Text = selectedValue .. " ^"
        else
            holder.Size = UDim2.new(1, 0, 0, 46)
            dropdown.Size = UDim2.new(1, 0, 0, 0)
            picker.Text = selectedValue .. " v"
        end
    end
    local function SetValue(value, silent)
        if not Themes[value] then return end
        selectedValue = value
        picker.Text = selectedValue .. (opened and " ^" or " v")
        SetOpen(false)
        if callback and not silent then callback(selectedValue) end
    end
    picker.Activated:Connect(function() SetOpen(not opened) end)
    for _, option in ipairs(options) do
        local optTheme = Themes[option] or theme
        local btn = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = optTheme.Button,
            BorderSizePixel = 0,
            Text = option,
            TextColor3 = optTheme.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            Parent = dropdown
        })
        Corner(btn, 7)
        Stroke(btn, optTheme.Accent, 1, 0.78)
        btn.Activated:Connect(function() SetValue(option, false) end)
    end
    table.insert(ThemedPickers, {
        Holder = holder, Label = label, Picker = picker, PickerStroke = pickerStroke,
        Dropdown = dropdown, DropdownStroke = dropdownStroke
    })
    SetValue(selectedValue, true)
    return label, picker, SetValue, function() return selectedValue end
end

local function CountSelectedTargets()
    local count = 0
    for _ in pairs(SelectedTargets) do count = count + 1 end
    return count
end

-- ================== FLING 3 MODES + TOUCH FLING (DARI FLING GUI) ==================
local FlingActive = false
local FlingMode = 1          -- 1: SkidFling, 2: shhhlol, 3: yeet
local TouchFlingActive = false
local TouchFlingLoop = nil

local function SkidFling(TargetPlayer, duration)
    if not TargetPlayer or TargetPlayer == Player then return end
    local targetChar = TargetPlayer.Character
    if not targetChar then return end
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetHumanoid.RootPart
    if not targetRoot then return end

    if targetHumanoid.Sit then
        Notify("Fling", TargetPlayer.Name .. " is currently sitting.", 2)
        return
    end

    pcall(function()
        targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    end)

    for _, bv in ipairs(targetRoot:GetChildren()) do
        if bv:IsA("BodyVelocity") then
            pcall(function() bv:Destroy() end)
        end
    end

    local localChar = Player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if localRoot and localRoot.Velocity.Magnitude < 50 then
        _G.OldPos = localRoot.CFrame
    end

    local camera = workspace.CurrentCamera
    local targetHead = targetChar:FindFirstChild("Head")
    if targetHead then
        camera.CameraSubject = targetHead
    else
        camera.CameraSubject = targetHumanoid
    end

    local previousDestroyHeight = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0

    local bv = Instance.new("BodyVelocity")
    bv.Name = "EpixVel"
    bv.Parent = targetRoot
    bv.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local startTime = tick()
    local timeToWait = duration or 2
    local angle = 0

    repeat
        if targetRoot and targetHumanoid then
            angle = angle + 100
            local function move(pos, ang)
                if localRoot then
                    localRoot.CFrame = CFrame.new(targetRoot.Position) * pos * ang
                    localChar:SetPrimaryPartCFrame(CFrame.new(targetRoot.Position) * pos * ang)
                    localRoot.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    localRoot.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                end
            end
            move(CFrame.new(0, 1.5, 0) + targetHumanoid.MoveDirection * targetRoot.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
            task.wait()
            move(CFrame.new(0, -1.5, 0) + targetHumanoid.MoveDirection * targetRoot.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
            task.wait()
            move(CFrame.new(2.25, 1.5, -2.25) + targetHumanoid.MoveDirection * targetRoot.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
            task.wait()
            move(CFrame.new(-2.25, -1.5, 2.25) + targetHumanoid.MoveDirection * targetRoot.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
            task.wait()
        else
            break
        end
    until not FlingActive 
        or targetRoot.Velocity.Magnitude > 500 
        or not targetChar:IsDescendantOf(workspace) 
        or TargetPlayer.Character ~= targetChar 
        or tick() > startTime + timeToWait

    bv:Destroy()
    targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = (Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")) or nil

    if localRoot and _G.OldPos then
        localRoot.CFrame = _G.OldPos * CFrame.new(0, 0.5, 0)
        for _, part in pairs(localChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.new()
                part.RotVelocity = Vector3.new()
            end
        end
    end
    workspace.FallenPartsDestroyHeight = previousDestroyHeight
end

local function shhhlol(TargetPlayer)
    if not TargetPlayer or TargetPlayer == Player then return end
    local targetChar = TargetPlayer.Character
    if not targetChar then return end
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetHumanoid.RootPart
    if not targetRoot then return end

    local localChar = Player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    if localRoot.Velocity.Magnitude < 50 then
        _G.OldPos = localRoot.CFrame
    end

    local function move(part, pos, ang)
        localRoot.CFrame = CFrame.new(part.Position) * pos * ang
        localRoot.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local Att1 = Instance.new("Attachment", localRoot)
    local Att2 = Instance.new("Attachment", targetRoot)

    local startTime = tick()
    repeat
        if localRoot and targetHumanoid then
            if targetRoot.Velocity.Magnitude < 30 then
                move(targetRoot, CFrame.new(0, 1.5, 0) + targetHumanoid.MoveDirection * targetRoot.Velocity.Magnitude / 5,
                    CFrame.Angles(math.random() > 0.5 and math.rad(0) or math.rad(180), math.random() > 0.5 and math.rad(0) or math.rad(180), math.random() > 0.5 and math.rad(0) or math.rad(180)))
                task.wait()
                move(targetRoot, CFrame.new(0, 1.5, 0) + targetHumanoid.MoveDirection * targetRoot.Velocity.Magnitude / 1.25,
                    CFrame.Angles(math.random() > 0.5 and math.rad(0) or math.rad(180), math.random() > 0.5 and math.rad(0) or math.rad(180), math.random() > 0.5 and math.rad(0) or math.rad(180)))
                task.wait()
                move(targetRoot, CFrame.new(0, -1.5, 0) + targetHumanoid.MoveDirection * targetRoot.Velocity.Magnitude / 1.25,
                    CFrame.Angles(math.random() > 0.5 and math.rad(0) or math.rad(180), math.random() > 0.5 and math.rad(0) or math.rad(180), math.random() > 0.5 and math.rad(0) or math.rad(180)))
                task.wait()
            else
                move(targetRoot, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(0), 0, 0))
                task.wait()
            end
        else
            break
        end
    until not FlingActive 
        or targetRoot.Velocity.Magnitude > 1000 
        or not targetChar:IsDescendantOf(workspace) 
        or TargetPlayer.Character ~= targetChar 
        or tick() > startTime + 0.134

    Att1:Destroy()
    Att2:Destroy()

    if localRoot and _G.OldPos then
        localRoot.CFrame = _G.OldPos * CFrame.new(0, 0.5, 0)
        for _, part in pairs(localChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.new()
                part.RotVelocity = Vector3.new()
            end
        end
    end
end

local function yeet(TargetPlayer)
    if not TargetPlayer or TargetPlayer == Player then return end
    local targetChar = TargetPlayer.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    local localChar = Player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    local oldPos = localRoot.CFrame
    local oldVel = localRoot.AssemblyLinearVelocity
    local direction = (targetRoot.Position - localRoot.Position).Unit
    localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -2)
    localRoot.AssemblyLinearVelocity = direction * 9e7 + Vector3.new(0, 9e6, 0)
    task.wait(0.15)
    localRoot.AssemblyLinearVelocity = Vector3.zero
    localRoot.CFrame = oldPos
    localRoot.AssemblyLinearVelocity = oldVel
    localRoot.AssemblyAngularVelocity = Vector3.zero
end

local function FlingPlayer(target, duration)
    if FlingMode == 1 then
        SkidFling(target, duration)
    elseif FlingMode == 2 then
        shhhlol(target)
    elseif FlingMode == 3 then
        yeet(target)
    end
end

local function TouchFlingLoop()
    while TouchFlingActive do
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local vel = root.Velocity
            root.Velocity = vel * 1e35 + Vector3.new(0, 1e35, 0)
            RunService.RenderStepped:Wait()
            root.Velocity = vel
            RunService.Stepped:Wait()
            root.Velocity = vel + Vector3.new(0, (math.sin(tick() * 20) * 0.1), 0)
        end
        task.wait()
    end
end

-- Fungsi update teks tombol
local ModeButton = nil
local TouchFlingButton = nil

local function UpdateModeButtonText()
    if ModeButton then
        ModeButton.Text = "MODE: " .. tostring(FlingMode)
    end
end

local function UpdateTouchFlingButtonText()
    if TouchFlingButton then
        TouchFlingButton.Text = "TOUCH FLING: " .. (TouchFlingActive and "ON" or "OFF")
    end
end

local function ToggleTouchFling()
    TouchFlingActive = not TouchFlingActive
    UpdateTouchFlingButtonText()

    if TouchFlingActive then
        task.spawn(TouchFlingLoop)
        Notify("Touch Fling", "Enabled", 2)
    else
        Notify("Touch Fling", "Disabled", 2)
    end
end

-- ========== FLING START/STOP (DENGAN AUTO MATIKAN ANTI FLING) ==========
StartFling = function()
    if FlingActive then return end
    local count = CountSelectedTargets()
    if count == 0 then
        StatusLabel.Text = "No targets selected."
        task.wait(1)
        StatusLabel.Text = "Select at least one target."
        return
    end

    -- If Anti Fling is active, disable it automatically first.
    if AntiFlingActive and ToggleAntiFling then
        ToggleAntiFling()
        task.wait(0.15)
    end

    FlingActive = true
    UpdateStatus()
    Notify("Fling Started", "Processing " .. count .. " selected target(s) using Mode " .. FlingMode .. ".", 2)

    task.spawn(function()
        while FlingActive do
            local validTargets = {}
            for name, player in pairs(SelectedTargets) do
                -- Validasi karakter target masih hidup dan utuh
                local char = player and player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if player and player.Parent and player ~= Player and char and hum and root and hum.Health > 0 then
                    validTargets[name] = player
                else
                    SelectedTargets[name] = nil
                    local cb = PlayerCheckboxes[name]
                    if cb and cb.Checkmark then
                        cb.Checkmark.Visible = false
                    end
                end
            end

            for _, player in pairs(validTargets) do
                if not FlingActive then break end
                local ok, err = pcall(function()
                    FlingPlayer(player)
                end)
                if not ok then
                    warn("[FLING ERROR]", err)
                end
                task.wait(0.2)
            end

            UpdateStatus()
            task.wait(0.5)
        end
    end)
end

StopFling = function()
    if not FlingActive then return end
    FlingActive = false
    UpdateStatus()
    Notify("Fling Stopped", "Fling has been stopped.", 2)
end

-- GUI SETUP
ScreenGui = New("ScreenGui", {
    Name = OLD_GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})
local parented = false
if CoreGui then
    pcall(function()
        ScreenGui.Parent = CoreGui
        parented = ScreenGui.Parent == CoreGui
    end)
end
if not parented then ScreenGui.Parent = PlayerGui end

OpenButton = New("TextButton", {
    Size = UDim2.new(0, 110, 0, 34),
    Position = UDim2.new(0, 10, 0.5, -17),
    BackgroundColor3 = GetTheme().Background,
    BorderSizePixel = 0,
    Text = "OPEN GUI",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    Visible = false,
    ZIndex = 1000,
    Parent = ScreenGui
})
Corner(OpenButton, 14)
Stroke(OpenButton, Color3.fromRGB(255, 255, 255), 1, 0.45)

MainFrame = New("Frame", {
    Size = UDim2.new(0, CurrentWidth, 0, CurrentHeight),
    Position = UDim2.new(0.5, -CurrentWidth / 2, 0.5, -CurrentHeight / 2),
    BackgroundColor3 = GetTheme().Background,
    BorderSizePixel = 0,
    Active = true,
    Visible = false,
    ZIndex = 10,
    Parent = ScreenGui
})
Corner(MainFrame, 16)
MainStroke = Stroke(MainFrame, GetTheme().Accent, 2, 0.25)

MainGradient = New("UIGradient", {
    Rotation = 35,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, GetTheme().Background),
        ColorSequenceKeypoint.new(1, GetTheme().Panel)
    }),
    Parent = MainFrame
})

TitleBar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 50),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Top,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = MainFrame
})
Corner(TitleBar, 16)

TitleBarFix = New("Frame", {
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = GetTheme().Top,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = TitleBar
})

Title = New("TextLabel", {
    Size = UDim2.new(1, -106, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text = "HAIMIYACH HUB",
    TextColor3 = GetTheme().Accent,
    Font = Enum.Font.GothamBlack,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
    Parent = TitleBar
})

SettingsButton = New("TextButton", {
    Position = UDim2.new(1, -92, 0, 8),
    Size = UDim2.new(0, 36, 0, 34),
    BackgroundColor3 = GetTheme().Button,
    BorderSizePixel = 0,
    Text = "⚙",
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    ZIndex = 13,
    Parent = TitleBar
})
Corner(SettingsButton, 10)
SettingsButtonStroke = Stroke(SettingsButton, GetTheme().Accent, 1, 0.72)

CloseButton = New("TextButton", {
    Position = UDim2.new(1, -48, 0, 8),
    Size = UDim2.new(0, 36, 0, 34),
    BackgroundColor3 = Color3.fromRGB(210, 35, 45),
    BorderSizePixel = 0,
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
    ZIndex = 13,
    Parent = TitleBar
})
Corner(CloseButton, 10)

ContentFrame = New("Frame", {
    Position = UDim2.new(0, 14, 0, 62),
    Size = UDim2.new(1, -28, 1, -76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = MainFrame
})

StatusLabel = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 22),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    Text = "0 target(s) selected",
    TextColor3 = GetTheme().Muted or GetTheme().Text,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
    Parent = ContentFrame
})

Pages = New("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = ContentFrame
})

-- FLING PAGE (LENGKAP)
FlingPage = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})
Corner(FlingPage, 14)
FlingPageStroke = Stroke(FlingPage, GetTheme().Accent, 1, 0.72)

PlayerPage = New("Frame", {
    Size = UDim2.new(1, -24, 1, -24),
    Position = UDim2.new(0, 12, 0, 12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = FlingPage
})

FlingStatusOffset = 34
FlingEntryHeight = 36
FlingEntryTextSize = 12
FlingCheckboxSize = 22
FlingCheckboxOffset = 6
FlingNameOffset = 36
FlingListPopupOpen = false
FlingPlayerListButton = nil
FlingPlayerListStroke = nil
FlingPlayerListTitle = nil
FlingPlayerListMeta = nil
FlingListCloseButton = nil
PresetSizeFrame = nil

SelectionFrame = New("Frame", {
    Size = UDim2.new(1, 0, 1, -126),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    ZIndex = 12,
    Parent = PlayerPage
})
Corner(SelectionFrame, 14)
SelectionStroke = Stroke(SelectionFrame, GetTheme().Accent, 1, 0.78)

PlayerScrollFrame = New("ScrollingFrame", {
    Position = UDim2.new(0, 8, 0, 8),
    Size = UDim2.new(1, -16, 1, -16),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 13,
    Parent = SelectionFrame
})

PlayerListLayout = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6),
    Parent = PlayerScrollFrame
})

ActionFrame = New("Frame", {
    -- Hanya untuk 6 tombol utama: 3 baris x 2 kolom.
    -- Anti Fling is separated to prevent the button layout from dropping or offsetting.
    Size = UDim2.new(1, 0, 0, 86),
    Position = UDim2.new(0, 0, 0, 82),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 12,
    Parent = PlayerPage
})

ActionGrid = New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -7, 0, 26),
    CellPadding = UDim2.new(0, 14, 0, 4),
    FillDirection = Enum.FillDirection.Horizontal,
    FillDirectionMaxCells = 2,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = ActionFrame
})

StartButton = MakeButton("START FLING", ActionFrame, function()
    if StartFling then StartFling() end
end)
StartButton.LayoutOrder = 1

StopButton = MakeButton("STOP FLING", ActionFrame, function()
    if StopFling then StopFling() end
end)
StopButton.LayoutOrder = 2

SelectAllButton = MakeButton("SELECT ALL", ActionFrame, function()
    if ToggleAllPlayers then ToggleAllPlayers(true) end
end)
SelectAllButton.LayoutOrder = 3
DeselectAllButton = MakeButton("DESELECT ALL", ActionFrame, function()
    if ToggleAllPlayers then ToggleAllPlayers(false) end
end)
DeselectAllButton.LayoutOrder = 4

-- Fling mode button (1/2/3).
ModeButton = MakeButton("MODE: 1", ActionFrame, function()
    FlingMode = (FlingMode % 3) + 1
    UpdateModeButtonText()
    Notify("Fling Mode", "Mode " .. FlingMode .. " selected.", 2)
end)
ModeButton.LayoutOrder = 5

-- Touch Fling button.
TouchFlingButton = MakeButton("TOUCH FLING: OFF", ActionFrame, function()
    ToggleTouchFling()
end)
TouchFlingButton.LayoutOrder = 6

AntiFlingButton = MakeButton("ANTI FLING: OFF", PlayerPage, function()
    if ToggleAntiFling then ToggleAntiFling() end
end)
AntiFlingButton.AnchorPoint = Vector2.new(0.5, 0)
AntiFlingButton.Size = UDim2.new(0.5, -7, 0, 26)
AntiFlingButton.Position = UDim2.new(0.5, 0, 0, 172)
AntiFlingButton.ZIndex = 36

-- Inisialisasi teks tombol
UpdateModeButtonText()
UpdateTouchFlingButtonText()

function StyleFlingActionButtons()
    local theme = GetTheme()
    for _, btn in ipairs({StartButton, StopButton, SelectAllButton, DeselectAllButton, AntiFlingButton, ModeButton, TouchFlingButton}) do
        if btn then
            btn.BackgroundColor3 = theme.Button
            btn.TextColor3 = theme.Text
        end
    end
end
StyleFlingActionButtons()

-- SETTINGS PAGE (LENGKAP)
SettingsPage = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
    Parent = Pages
})
Corner(SettingsPage, 14)
SettingsStroke = Stroke(SettingsPage, GetTheme().Accent, 1, 0.68)

SettingsScroll = New("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 12),
    Size = UDim2.new(1, -24, 1, -24),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 21,
    Parent = SettingsPage
})

SettingsList = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 12),
    Parent = SettingsScroll
})
Padding(SettingsScroll, 0, 8, 0, 14)

function SectionLabel(text)
    return New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = GetTheme().Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
        Parent = SettingsScroll
    })
end

function GridContainer(height, columns)
    local frame = New("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 22,
        Parent = SettingsScroll
    })
    local grid = New("UIGridLayout", {
        CellSize = UDim2.new(1 / columns, -8, 0, 40),
        CellPadding = UDim2.new(0, 10, 0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = frame
    })
    return frame, grid
end

SectionLabel("SIZE")
SizeFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 148),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 22,
    Parent = SettingsScroll
})
New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8),
    Parent = SizeFrame
})

ThemeTitle = SectionLabel("COLOR")
ThemeFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 46),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 22,
    Parent = SettingsScroll
})
New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8),
    Parent = ThemeFrame
})

SetWidthInput = nil
SetHeightInput = nil
SetColourPicker = nil
GetSelectedColour = nil

-- MAIN MENU PAGE
MainMenuPage = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = true,
    ZIndex = 30,
    Parent = Pages
})
Corner(MainMenuPage, 14)
MainMenuStroke = Stroke(MainMenuPage, GetTheme().Accent, 1, 0.72)

Menu2Page = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})
Corner(Menu2Page, 14)
Menu2Stroke = Stroke(Menu2Page, GetTheme().Accent, 1, 0.78)

Menu3Page = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})
Corner(Menu3Page, 14)
Menu3Stroke = Stroke(Menu3Page, GetTheme().Accent, 1, 0.78)

Menu4Page = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})
Corner(Menu4Page, 14)
Menu4Stroke = Stroke(Menu4Page, GetTheme().Accent, 1, 0.78)

function SetTargetCountVisible(isVisible)
    if StatusLabel then
        StatusLabel.Visible = isVisible
    end
end

function SetPagesForFling(isFling)
    if isFling then
        Pages.Position = UDim2.new(0, 0, 0, FlingStatusOffset)
        Pages.Size = UDim2.new(1, 0, 1, -FlingStatusOffset)
    else
        Pages.Position = UDim2.new(0, 0, 0, 0)
        Pages.Size = UDim2.new(1, 0, 1, 0)
    end
end

function ShowPage(pageName)
    MainMenuPage.Visible = false
    FlingPage.Visible = false
    PlayerPage.Visible = false
    SettingsPage.Visible = false
    Menu2Page.Visible = false
    Menu3Page.Visible = false
    Menu4Page.Visible = false
    
    SetTargetCountVisible(false)
    SetPagesForFling(false)
    if pageName ~= "FLING" and SetFlingPlayerListOpen then
        SetFlingPlayerListOpen(false)
    end
    
    if pageName == "HOME" then
        MainMenuPage.Visible = true
    elseif pageName == "FLING" then
        FlingPage.Visible = true
        PlayerPage.Visible = true
        SetTargetCountVisible(true)
        SetPagesForFling(true)
        if SetFlingPlayerListOpen then SetFlingPlayerListOpen(false) end
    elseif pageName == "SETTINGS" then
        SettingsPage.Visible = true
    elseif pageName == "MENU2" then
        Menu2Page.Visible = true
    elseif pageName == "MOVEMENT" then
        Menu3Page.Visible = true
    elseif pageName == "MENU4" then
        Menu4Page.Visible = true
    end
end

MenuTitle = New("TextLabel", {
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.new(0, 10, 0, 8),
    BackgroundTransparency = 1,
    Text = "MAIN MENU",
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 31,
    Parent = MainMenuPage
})

MenuGrid = New("Frame", {
    Size = UDim2.new(1, -20, 1, -52),
    Position = UDim2.new(0, 10, 0, 48),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = MainMenuPage
})

MenuGridLayout = New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 44),
    CellPadding = UDim2.new(0, 10, 0, 10),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Parent = MenuGrid
})

Menu4Button = MakeButton("AIMBOT", MenuGrid, function() ShowPage("MENU4") end)
FlingMenuButton = MakeButton("FLING", MenuGrid, function() ShowPage("FLING") end)
Menu2Button = MakeButton("FE EMOTE", MenuGrid, function() ShowPage("MENU2") end)
Menu3Button = MakeButton("MOVEMENT", MenuGrid, function() ShowPage("MOVEMENT") end)

Menu4Button.LayoutOrder = 1
FlingMenuButton.LayoutOrder = 2
Menu2Button.LayoutOrder = 3
Menu3Button.LayoutOrder = 4

FlingBackFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 40,
    Parent = PlayerPage
})

FlingBackButton = MakeButton("←  BACK", FlingBackFrame, function() ShowPage("HOME") end)
FlingBackButton.Size = UDim2.new(0, 124, 0, 32)
FlingBackButton.Position = UDim2.new(0, 0, 0, 0)
FlingBackButton.ZIndex = 41
FlingBackButton.TextSize = 14

-- Premium dropdown selector
FlingPlayerListButton = MakeButton("", PlayerPage, function()
    SetFlingPlayerListOpen(not FlingListPopupOpen)
end)
FlingPlayerListButton.Size = UDim2.new(1, 0, 0, 38)
FlingPlayerListButton.Position = UDim2.new(0, 0, 0, 38)
FlingPlayerListButton.ZIndex = 41
FlingPlayerListButton.Text = ""
FlingPlayerListButton.AutoButtonColor = true
FlingPlayerListStroke = FlingPlayerListButton:FindFirstChildOfClass("UIStroke")

FlingPlayerListTitle = New("TextLabel", {
    Position = UDim2.new(0, 14, 0, 0),
    Size = UDim2.new(1, -122, 1, 0),
    BackgroundTransparency = 1,
    Text = "TARGET PLAYERS",
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 42,
    Parent = FlingPlayerListButton
})

FlingPlayerListMeta = New("TextLabel", {
    Position = UDim2.new(1, -108, 0, 0),
    Size = UDim2.new(0, 94, 1, 0),
    BackgroundTransparency = 1,
    Text = "0 OPEN",
    TextColor3 = GetTheme().Accent2,
    Font = Enum.Font.GothamBlack,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 42,
    Parent = FlingPlayerListButton
})

function StyleFlingPlayerListButton()
    local theme = GetTheme()
    if FlingPage then FlingPage.BackgroundColor3 = theme.Panel end
    if FlingPageStroke then FlingPageStroke.Color = theme.Accent end
    if FlingPlayerListButton then
        FlingPlayerListButton.BackgroundColor3 = theme.Panel2 or theme.Button2 or theme.Panel
        FlingPlayerListButton.TextColor3 = theme.Text
        FlingPlayerListButton.Font = Enum.Font.GothamBlack
        FlingPlayerListButton.Text = ""
    end
    if FlingPlayerListTitle then FlingPlayerListTitle.TextColor3 = theme.Text end
    if FlingPlayerListMeta then FlingPlayerListMeta.TextColor3 = theme.Accent2 or theme.Accent end
    if FlingPlayerListStroke then
        FlingPlayerListStroke.Color = theme.Accent2 or theme.Accent
        FlingPlayerListStroke.Thickness = 2
        FlingPlayerListStroke.Transparency = 0.18
    end
end
StyleFlingPlayerListButton()

FlingListCloseButton = nil

function CountAvailableTargets()
    local count = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then count = count + 1 end
    end
    return count
end

function UpdateFlingListButtonText()
    local count = CountAvailableTargets()
    if FlingPlayerListButton then FlingPlayerListButton.Text = "" end
    if FlingPlayerListTitle then FlingPlayerListTitle.Text = "TARGET PLAYERS" end
    if FlingPlayerListMeta then
        if FlingListPopupOpen then
            FlingPlayerListMeta.Text = tostring(count) .. " HIDE"
        else
            FlingPlayerListMeta.Text = tostring(count) .. " OPEN"
        end
    end
    if StyleFlingPlayerListButton then StyleFlingPlayerListButton() end
end

function SetFlingPlayerListOpen(state)
    FlingListPopupOpen = state and true or false
    UpdateFlingListButtonText()
    UpdateFlingResponsiveLayout()
end

SelectionFrame.Position = UDim2.new(0, 0, 0, 42)
SelectionFrame.Size = UDim2.new(1, 0, 1, -126)
SelectionFrame.Visible = false

function UpdateFlingResponsiveLayout()
    local isSmall = (CurrentHeight <= 320 or CurrentWidth <= 260)
    local isLarge = (CurrentHeight >= 390 and CurrentWidth >= 320)

    if isSmall then
        FlingStatusOffset = 26
        FlingEntryHeight = 28
        FlingEntryTextSize = 11
        FlingCheckboxSize = 18
        FlingCheckboxOffset = 5
        FlingNameOffset = 30

        StatusLabel.Size = UDim2.new(1, 0, 0, 20)
        StatusLabel.TextSize = 11

        FlingBackFrame.Size = UDim2.new(1, 0, 0, 26)
        FlingBackButton.Size = UDim2.new(0, 108, 0, 28)
        FlingBackButton.TextSize = 12
        FlingPlayerListButton.Size = UDim2.new(1, 0, 0, 34)
        FlingPlayerListButton.Position = UDim2.new(0, 0, 0, 30)
        if FlingPlayerListTitle then FlingPlayerListTitle.TextSize = 12 end
        if FlingPlayerListMeta then FlingPlayerListMeta.TextSize = 11 end

        SelectionFrame.Position = UDim2.new(0, 0, 0, 38)
        SelectionFrame.Size = UDim2.new(1, 0, 1, -116)
        PlayerScrollFrame.Position = UDim2.new(0, 5, 0, 5)
        PlayerScrollFrame.Size = UDim2.new(1, -10, 1, -10)
        PlayerListLayout.Padding = UDim.new(0, 3)

        ActionFrame.Size = UDim2.new(1, 0, 0, 78)
        ActionFrame.Position = UDim2.new(0, 0, 0, 68)
        ActionGrid.CellSize = UDim2.new(0.5, -6, 0, 24)
        ActionGrid.CellPadding = UDim2.new(0, 12, 0, 3)
        if AntiFlingButton then
            AntiFlingButton.AnchorPoint = Vector2.new(0.5, 0)
            AntiFlingButton.Size = UDim2.new(0.5, -6, 0, 22)
            AntiFlingButton.Position = UDim2.new(0.5, 0, 0, 148)
        end

        for _, btn in ipairs({StartButton, StopButton, SelectAllButton, DeselectAllButton, AntiFlingButton, ModeButton, TouchFlingButton}) do
            if btn then
                btn.TextSize = 10
                btn.TextWrapped = true
            end
        end
    elseif isLarge then
        FlingStatusOffset = 32
        FlingEntryHeight = 40
        FlingEntryTextSize = 13
        FlingCheckboxSize = 24
        FlingCheckboxOffset = 7
        FlingNameOffset = 40

        StatusLabel.Size = UDim2.new(1, 0, 0, 22)
        StatusLabel.TextSize = 12

        FlingBackFrame.Size = UDim2.new(1, 0, 0, 34)
        FlingBackButton.Size = UDim2.new(0, 132, 0, 40)
        FlingBackButton.TextSize = 14
        FlingPlayerListButton.Size = UDim2.new(1, 0, 0, 46)
        FlingPlayerListButton.Position = UDim2.new(0, 0, 0, 48)
        if FlingPlayerListTitle then FlingPlayerListTitle.TextSize = 14 end
        if FlingPlayerListMeta then FlingPlayerListMeta.TextSize = 12 end

        SelectionFrame.Position = UDim2.new(0, 0, 0, 46)
        SelectionFrame.Size = UDim2.new(1, 0, 1, -146)
        PlayerScrollFrame.Position = UDim2.new(0, 7, 0, 7)
        PlayerScrollFrame.Size = UDim2.new(1, -14, 1, -14)
        PlayerListLayout.Padding = UDim.new(0, 5)

        ActionFrame.Size = UDim2.new(1, 0, 0, 108)
        ActionFrame.Position = UDim2.new(0, 0, 0, 104)
        ActionGrid.CellSize = UDim2.new(0.5, -7, 0, 32)
        ActionGrid.CellPadding = UDim2.new(0, 14, 0, 6)
        if AntiFlingButton then
            AntiFlingButton.AnchorPoint = Vector2.new(0.5, 0)
            AntiFlingButton.Size = UDim2.new(0.5, -7, 0, 32)
            AntiFlingButton.Position = UDim2.new(0.5, 0, 0, 216)
        end

        for _, btn in ipairs({StartButton, StopButton, SelectAllButton, DeselectAllButton, AntiFlingButton, ModeButton, TouchFlingButton}) do
            if btn then
                btn.TextSize = 12
                btn.TextWrapped = true
            end
        end
    else
        FlingStatusOffset = 30
        FlingEntryHeight = 36
        FlingEntryTextSize = 12
        FlingCheckboxSize = 22
        FlingCheckboxOffset = 6
        FlingNameOffset = 36

        StatusLabel.Size = UDim2.new(1, 0, 0, 22)
        StatusLabel.TextSize = 12

        FlingBackFrame.Size = UDim2.new(1, 0, 0, 30)
        FlingBackButton.Size = UDim2.new(0, 124, 0, 32)
        FlingBackButton.TextSize = 14
        FlingPlayerListButton.Size = UDim2.new(1, 0, 0, 38)
        FlingPlayerListButton.Position = UDim2.new(0, 0, 0, 38)
        if FlingPlayerListTitle then FlingPlayerListTitle.TextSize = 13 end
        if FlingPlayerListMeta then FlingPlayerListMeta.TextSize = 12 end

        SelectionFrame.Position = UDim2.new(0, 0, 0, 42)
        SelectionFrame.Size = UDim2.new(1, 0, 1, -126)
        PlayerScrollFrame.Position = UDim2.new(0, 6, 0, 6)
        PlayerScrollFrame.Size = UDim2.new(1, -12, 1, -12)
        PlayerListLayout.Padding = UDim.new(0, 4)

        ActionFrame.Size = UDim2.new(1, 0, 0, 86)
        ActionFrame.Position = UDim2.new(0, 0, 0, 82)
        ActionGrid.CellSize = UDim2.new(0.5, -7, 0, 26)
        ActionGrid.CellPadding = UDim2.new(0, 14, 0, 4)
        if AntiFlingButton then
            AntiFlingButton.AnchorPoint = Vector2.new(0.5, 0)
            AntiFlingButton.Size = UDim2.new(0.5, -7, 0, 26)
            AntiFlingButton.Position = UDim2.new(0.5, 0, 0, 172)
        end

        for _, btn in ipairs({StartButton, StopButton, SelectAllButton, DeselectAllButton, AntiFlingButton, ModeButton, TouchFlingButton}) do
            if btn then
                btn.TextSize = 11
                btn.TextWrapped = true
            end
        end
    end

    for _, data in pairs(PlayerCheckboxes) do
        if data.Entry then
            data.Entry.Size = UDim2.new(1, -4, 0, FlingEntryHeight)
            data.Entry.ZIndex = FlingListPopupOpen and 72 or 14
        end
        if data.Checkbox then
            data.Checkbox.Size = UDim2.new(0, FlingCheckboxSize, 0, FlingCheckboxSize)
            data.Checkbox.Position = UDim2.new(0, FlingCheckboxOffset, 0.5, -FlingCheckboxSize / 2)
            data.Checkbox.ZIndex = FlingListPopupOpen and 73 or 15
        end
        if data.Checkmark then
            data.Checkmark.TextSize = math.max(12, FlingCheckboxSize - 7)
            data.Checkmark.ZIndex = FlingListPopupOpen and 74 or 16
        end
        if data.NameLabel then
            data.NameLabel.Size = UDim2.new(1, -(FlingNameOffset + 8), 1, 0)
            data.NameLabel.Position = UDim2.new(0, FlingNameOffset, 0, 0)
            data.NameLabel.TextSize = FlingEntryTextSize
            data.NameLabel.ZIndex = FlingListPopupOpen and 73 or 15
        end
    end

    if SelectionFrame then
        SelectionFrame.Visible = FlingListPopupOpen
        if FlingListPopupOpen then
            SelectionFrame.Position = UDim2.new(0, 0, 0, 92)
            SelectionFrame.Size = UDim2.new(1, 0, 1, -96)
            SelectionFrame.ZIndex = 60
            SelectionStroke.Color = GetTheme().Accent
            if FlingPlayerListButton then FlingPlayerListButton.ZIndex = 76 end
            PlayerScrollFrame.Position = UDim2.new(0, 6, 0, 6)
            PlayerScrollFrame.Size = UDim2.new(1, -12, 1, -12)
            PlayerScrollFrame.ZIndex = 71
        else
            SelectionFrame.Visible = false
            SelectionFrame.ZIndex = 12
            PlayerScrollFrame.ZIndex = 13
            if FlingPlayerListButton then FlingPlayerListButton.ZIndex = 41 end
        end
    end

    if FlingPage and FlingPage.Visible then
        SetPagesForFling(true)
    end
end
UpdateFlingResponsiveLayout()

function CreateMenuPageContent(page, titleText)
    local backButton = MakeButton("← BACK", page, function() ShowPage("HOME") end)
    backButton.Size = UDim2.new(0, 92, 0, 32)
    backButton.Position = UDim2.new(0, 12, 0, 12)
    local titleLabel = New("TextLabel", {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0.5, -18),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = GetTheme().Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 31,
        Parent = page
    })
    return backButton, titleLabel
end

Menu2BackButton, Menu2Label = CreateMenuPageContent(Menu2Page, "FE EMOTE")
Menu3BackButton, Menu3Label = CreateMenuPageContent(Menu3Page, "MOVEMENT")
Menu4BackButton, Menu4Label = CreateMenuPageContent(Menu4Page, "AIMBOT")

-- ========== MENU 2 - FE EMOTE ==========
if Menu2Label then
    Menu2Label.Text = "FE EMOTE"
    Menu2Label.Position = UDim2.new(0, 110, 0, 12)
    Menu2Label.Size = UDim2.new(1, -122, 0, 32)
    Menu2Label.TextSize = 15
    Menu2Label.TextXAlignment = Enum.TextXAlignment.Center
    Menu2Label.ZIndex = 42
end

if Menu2Placeholder then
    Menu2Placeholder:Destroy()
    Menu2Placeholder = nil
end

if Menu2Scroll then
    Menu2Scroll:Destroy()
    Menu2Scroll = nil
end

Menu2Scroll = New("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 52),
    Size = UDim2.new(1, -24, 1, -60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 35,
    Parent = Menu2Page
})

Menu2List = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Menu2Scroll
})
Padding(Menu2Scroll, 0, 8, 0, 12)

-- MOVEMENT LOGIC (LENGKAP)
if Menu3Label then
    Menu3Label.Text = "MOVEMENT"
    Menu3Label.Position = UDim2.new(0, 110, 0, 12)
    Menu3Label.Size = UDim2.new(1, -122, 0, 32)
    Menu3Label.TextSize = 15
    Menu3Label.TextXAlignment = Enum.TextXAlignment.Center
    Menu3Label.ZIndex = 42
end

function GetMovementCharacterParts()
    local char = Player.Character
    if not char then return nil, nil, nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart)
    return char, humanoid, root
end

function UpdateMovementLabels()
    if FlySpeedLabel then FlySpeedLabel.Text = "FLY SPEED: " .. tostring(FlySpeed) end
    if MoveSpeedLabel then MoveSpeedLabel.Text = "MOVE SPEED: " .. tostring(MoveSpeed) end
    if FlyButton then FlyButton.Text = FlyActive and "FLY: ON" or "FLY: OFF" end
    if InfJumpButton then InfJumpButton.Text = InfJumpActive and "INFINITE JUMP: ON" or "INFINITE JUMP: OFF" end
end

function ApplyMoveSpeed()
    local _, humanoid = GetMovementCharacterParts()
    if humanoid then pcall(function() humanoid.WalkSpeed = MoveSpeed end) end
end

Player.CharacterAdded:Connect(function()
    task.wait(1)
    ApplyMoveSpeed()
end)

function StartFly()
    if FlyConnection then FlyConnection:Disconnect() end
    FlyActive = true
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not FlyActive then return end
        local _, humanoid, root = GetMovementCharacterParts()
        if not humanoid or not root then return end
        local moveDirection = Vector3.new(0, 0, 0)
        if humanoid.MoveDirection.Magnitude > 0 then moveDirection = moveDirection + humanoid.MoveDirection end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
        if moveDirection.Magnitude > 0 then moveDirection = moveDirection.Unit end
        humanoid.PlatformStand = false
        pcall(function()
            root.AssemblyLinearVelocity = moveDirection * FlySpeed
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end)
    end)
    UpdateMovementLabels()
end

function StopFly()
    FlyActive = false
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    local _, humanoid, root = GetMovementCharacterParts()
    if humanoid then humanoid.PlatformStand = false end
    if root then pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        root.RotVelocity = Vector3.new(0, 0, 0)
    end) end
    UpdateMovementLabels()
end

function ToggleFly()
    if FlyActive then StopFly() else StartFly() end
    Notify("Fly", FlyActive and "Enabled" or "Disabled", 2)
end

function ToggleInfJump()
    InfJumpActive = not InfJumpActive
    if InfJumpActive then
        if InfJumpConnection then InfJumpConnection:Disconnect() end
        InfJumpConnection = UserInputService.JumpRequest:Connect(function()
            if not InfJumpActive then return end
            local _, humanoid = GetMovementCharacterParts()
            if humanoid then pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end) end
        end)
        Notify("Infinite Jump", "Enabled", 2)
    else
        if InfJumpConnection then InfJumpConnection:Disconnect() InfJumpConnection = nil end
        Notify("Infinite Jump", "Disabled", 2)
    end
    UpdateMovementLabels()
end

function ChangeFlySpeed(amount)
    FlySpeed = math.clamp(FlySpeed + amount, 10, 250)
    UpdateMovementLabels()
    Notify("Fly Speed", "Set to " .. tostring(FlySpeed), 1.5)
end

function ChangeMoveSpeed(amount)
    MoveSpeed = math.clamp(MoveSpeed + amount, 16, 250)
    ApplyMoveSpeed()
    UpdateMovementLabels()
    Notify("Move Speed", "Set to " .. tostring(MoveSpeed), 1.5)
end

Menu3Scroll = New("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 52),
    Size = UDim2.new(1, -24, 1, -60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 35,
    Parent = Menu3Page
})

local Menu3List = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Menu3Scroll
})
Padding(Menu3Scroll, 0, 8, 0, 12)

local function CompactMenu3Button(btn)
    if btn then
        btn.Size = UDim2.new(1, 0, 0, 44)
        btn.TextSize = 14
    end
    return btn
end

local function CompactMenu3Row(labelObj)
    if labelObj and labelObj.Parent then
        labelObj.Parent.Size = UDim2.new(1, 0, 0, 46)
    end
end

FlyButton = MakeButton("FLY: OFF", Menu3Scroll, function() ToggleFly() end)
CompactMenu3Button(FlyButton)

InfJumpButton = MakeButton("INFINITE JUMP: OFF", Menu3Scroll, function() ToggleInfJump() end)
CompactMenu3Button(InfJumpButton)

-- ========== ANTI KNOCKBACK (TIDAK TERPENTAL) ==========

local function StartAntiKnockback()
    if AntiKnockbackConnection then return end
    AntiKnockbackConnection = RunService.Heartbeat:Connect(function()
        if not AntiKnockbackActive then return end
        local char = Player.Character
        if not char then return end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if rootPart then
            rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
            rootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part ~= rootPart then
                    part.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    part.AssemblyAngularVelocity = Vector3.new(0,0,0)
                end
            end
        end
    end)
end

local function StopAntiKnockback()
    if AntiKnockbackConnection then
        AntiKnockbackConnection:Disconnect()
        AntiKnockbackConnection = nil
    end
end

local AntiKnockbackButton = nil
AntiKnockbackButton = MakeButton("ANTI KNOCKBACK: OFF", Menu3Scroll, function()
    AntiKnockbackActive = not AntiKnockbackActive
    if AntiKnockbackActive then
        StartAntiKnockback()
        Notify("Anti Knockback", "Enabled", 2)
    else
        StopAntiKnockback()
        Notify("Anti Knockback", "Disabled", 2)
    end
    if AntiKnockbackButton then
        AntiKnockbackButton.Text = AntiKnockbackActive and "ANTI KNOCKBACK: ON" or "ANTI KNOCKBACK: OFF"
    end
end)
CompactMenu3Button(AntiKnockbackButton)

-- ========== ANTI RAGDOLL (CEGAH TERGELEPAK) ==========
local function HandleRagdoll(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return {} end
    local connections = {}
    
    -- Cegah state ragdoll / falling down / physics
    local stateConn = humanoid.StateChanged:Connect(function(_, newState)
        if not AntiRagdollActive then return end
        if newState == Enum.HumanoidStateType.Ragdoll or 
           newState == Enum.HumanoidStateType.FallingDown or
           newState == Enum.HumanoidStateType.Physics then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            humanoid.PlatformStand = false
        end
    end)
    table.insert(connections, stateConn)
    
    -- Cegah platform stand
    local platformConn = humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if AntiRagdollActive and humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end
    end)
    table.insert(connections, platformConn)
    
    -- Cegah sit karena ragdoll
    local sitConn = humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
        if AntiRagdollActive and humanoid.Sit then
            humanoid.Sit = false
        end
    end)
    table.insert(connections, sitConn)
    
    return connections
end

local function ClearRagdollConnections()
    for _, conn in ipairs(AntiRagdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    AntiRagdollConnections = {}
end

local function StartAntiRagdoll()
    ClearRagdollConnections()
    local char = Player.Character
    if char then
        local conns = HandleRagdoll(char)
        for _, c in ipairs(conns) do
            table.insert(AntiRagdollConnections, c)
        end
    end
    -- Pantau saat karakter berganti
    local addedConn = Player.CharacterAdded:Connect(function(newChar)
        if AntiRagdollActive then
            ClearRagdollConnections()
            local conns = HandleRagdoll(newChar)
            for _, c in ipairs(conns) do
                table.insert(AntiRagdollConnections, c)
            end
        end
    end)
    table.insert(AntiRagdollConnections, addedConn)
end

local function StopAntiRagdoll()
    ClearRagdollConnections()
    local char = Player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if hum.PlatformStand then hum.PlatformStand = false end
            if hum.Sit then hum.Sit = false end
        end
    end
end

local AntiRagdollButton = nil
AntiRagdollButton = MakeButton("ANTI RAGDOLL: OFF", Menu3Scroll, function()
    AntiRagdollActive = not AntiRagdollActive
    if AntiRagdollActive then
        StartAntiRagdoll()
        Notify("Anti Ragdoll", "Enabled", 2)
    else
        StopAntiRagdoll()
        Notify("Anti Ragdoll", "Disabled", 2)
    end
    if AntiRagdollButton then
        AntiRagdollButton.Text = AntiRagdollActive and "ANTI RAGDOLL: ON" or "ANTI RAGDOLL: OFF"
    end
end)
CompactMenu3Button(AntiRagdollButton)

-- ========== NOCLIP (TEMBUS DINDING) ==========

local function StartNoclip()
    if NoclipConnection then return end
    NoclipConnection = RunService.Stepped:Connect(function()
        if not NoclipActive then return end
        local char = Player.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function StopNoclip()
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
    local char = Player.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

local NoclipButton = nil
NoclipButton = MakeButton("NOCLIP: OFF", Menu3Scroll, function()
    NoclipActive = not NoclipActive
    if NoclipActive then
        StartNoclip()
        Notify("Noclip", "Enabled", 2)
    else
        StopNoclip()
        Notify("Noclip", "Disabled", 2)
    end
    if NoclipButton then
        NoclipButton.Text = NoclipActive and "NOCLIP: ON" or "NOCLIP: OFF"
    end
end)
CompactMenu3Button(NoclipButton)

-- Keep the feature active when the character respawns. Place this near the bottom if it is not already present.
Player.CharacterAdded:Connect(function()
    if AntiKnockbackActive then StartAntiKnockback() end
    if NoclipActive then StartNoclip() end
end)

FlySpeedBox = nil
SetFlySpeedInput = nil
FlySpeedLabel, FlySpeedBox, SetFlySpeedInput = MakeNumberInput(Menu3Scroll, "FLY SPEED", FlySpeed, 10, 250, nil, function(value)
    FlySpeed = value
    UpdateMovementLabels()
    Notify("Fly Speed", "Set to " .. tostring(FlySpeed), 1.5)
end)
CompactMenu3Row(FlySpeedLabel)

MoveSpeedBox = nil
SetMoveSpeedInput = nil
MoveSpeedLabel, MoveSpeedBox, SetMoveSpeedInput = MakeNumberInput(Menu3Scroll, "MOVE SPEED", MoveSpeed, 16, 250, nil, function(value)
    MoveSpeed = value
    ApplyMoveSpeed()
    UpdateMovementLabels()
    Notify("Move Speed", "Set to " .. tostring(MoveSpeed), 1.5)
end)
CompactMenu3Row(MoveSpeedLabel)

ResetMovementButton = MakeButton("RESET SPEED", Menu3Scroll, function()
    FlySpeed = 55
    MoveSpeed = 16
    ApplyMoveSpeed()
    if SetFlySpeedInput then SetFlySpeedInput(FlySpeed, true) end
    if SetMoveSpeedInput then SetMoveSpeedInput(MoveSpeed, true) end
    UpdateMovementLabels()
    Notify("Movement", "Movement speed has been reset.", 2)
end)
CompactMenu3Button(ResetMovementButton)
UpdateMovementLabels()

-- // ========== MENU 4 - AIMBOT (LENGKAP) ==========
if Menu4Label then
    Menu4Label.Text = "AIMBOT"
    Menu4Label.Position = UDim2.new(0, 110, 0, 12)
    Menu4Label.Size = UDim2.new(1, -122, 0, 32)
    Menu4Label.TextSize = 15
    Menu4Label.TextXAlignment = Enum.TextXAlignment.Center
    Menu4Label.ZIndex = 42
end

if not Menu4Page then
    warn("Menu4Page not found")
    return
end

for _, child in ipairs(Menu4Page:GetChildren()) do
    if child:IsA("ScrollingFrame") then
        child:Destroy()
    end
end

Menu4Scroll = New("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 52),
    Size = UDim2.new(1, -24, 1, -60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 35,
    Parent = Menu4Page
})

local Menu4Layout = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Menu4Scroll
})
Padding(Menu4Scroll, 0, 8, 0, 12)

Menu4StatusLabel = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    Text = string.format("Aimbot: %s  |  ESP: %s",
        (AimbotData.Enabled and "ON" or "OFF"),
        (AimbotData.ESP and "ON" or "OFF")),
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextWrapped = true,
    Parent = Menu4Scroll
})

-- AIMBOT FUNCTIONS
function GetBestPart(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
end

local ClearESPForPlayer
local RefreshESPPlayer

function DoESP()
    if not AimbotData.ESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            ClearESPForPlayer(plr)
        end
        ESPList = {}
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        RefreshESPPlayer(plr)
    end
end

-- ESP WATCHER
local ESPConnections = {}


local function HasRealTeamMode()
    -- FFA games often put every player on the same default team/color.
    -- If only one team/color exists among alive players, treat the game as FFA.
    local teamSet = {}
    local teamColorSet = {}
    local teamCount = 0
    local colorCount = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health > 0 then
                if plr.Neutral ~= true and plr.Team ~= nil then
                    local key = tostring(plr.Team)
                    if not teamSet[key] then
                        teamSet[key] = true
                        teamCount = teamCount + 1
                    end
                end

                if plr.Neutral ~= true and plr.TeamColor ~= nil then
                    local colorKey = tostring(plr.TeamColor)
                    if not teamColorSet[colorKey] then
                        teamColorSet[colorKey] = true
                        colorCount = colorCount + 1
                    end
                end
            end
        end
    end

    if Player.Neutral ~= true and Player.Team ~= nil then
        local myKey = tostring(Player.Team)
        if not teamSet[myKey] then
            teamSet[myKey] = true
            teamCount = teamCount + 1
        end
    end

    if Player.Neutral ~= true and Player.TeamColor ~= nil then
        local myColorKey = tostring(Player.TeamColor)
        if not teamColorSet[myColorKey] then
            teamColorSet[myColorKey] = true
            colorCount = colorCount + 1
        end
    end

    return teamCount >= 2 or colorCount >= 2
end

local function IsSameTeam(plr)
    if not plr or plr == Player then
        return false
    end

    -- Gun Grounds / many FFA games keep everyone on one default team/color.
    -- In that case TeamCheck must NOT turn everyone blue.
    if not HasRealTeamMode() then
        return false
    end

    if Player.Neutral == true or plr.Neutral == true then
        return false
    end

    if Player.Team ~= nil and plr.Team ~= nil then
        return plr.Team == Player.Team
    end

    if Player.TeamColor ~= nil and plr.TeamColor ~= nil then
        return Player.TeamColor == plr.TeamColor
    end

    return false
end

local function DisconnectDamageIndicator()
    for _, con in ipairs(DamageIndicatorConnections) do
        pcall(function() con:Disconnect() end)
    end
    DamageIndicatorConnections = {}
    LastHumanoidHealth = nil
    DamageIndicatorFlashUntil = 0
    DamageIndicatorWorldPosition = nil
    if DamageIndicatorArrow then
        DamageIndicatorArrow.Visible = false
    end
    UpdateFOVCircle()
end

local function GetRootPositionFromPlayer(plr)
    local char = plr and plr.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("Head"))
    if root and root:IsA("BasePart") then
        return root.Position
    end
    return nil
end

local function GetTaggedDamageSource(humanoid)
    local tagNames = {"creator", "Creator", "attacker", "Attacker", "killer", "Killer"}
    for _, tagName in ipairs(tagNames) do
        local tag = humanoid and humanoid:FindFirstChild(tagName)
        if tag and tag:IsA("ObjectValue") and tag.Value then
            if tag.Value:IsA("Player") then
                return tag.Value
            end
            if tag.Value:IsA("Model") then
                local taggedPlayer = Players:GetPlayerFromCharacter(tag.Value)
                if taggedPlayer then
                    return taggedPlayer
                end
            end
        end
    end
    return nil
end

local function GetNearestEnemyPosition()
    local localChar = Player.Character
    local localRoot = localChar and (localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("UpperTorso") or localChar:FindFirstChild("Torso"))
    if not localRoot then return nil end

    local nearestPosition = nil
    local nearestDistance = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character then
            if AimbotData.TeamCheck and IsSameTeam(plr) then
                -- skip teammate as damage direction fallback
            else
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local pos = GetRootPositionFromPlayer(plr)
                if hum and hum.Health > 0 and pos then
                    local distance = (pos - localRoot.Position).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPosition = pos
                    end
                end
            end
        end
    end

    return nearestPosition
end

local function TriggerDamageIndicator(attackerPlayer, humanoid)
    if not AimbotData.DamageIndicator then return end

    local sourcePosition = GetRootPositionFromPlayer(attackerPlayer)
    if not sourcePosition then
        sourcePosition = GetNearestEnemyPosition()
    end

    DamageIndicatorWorldPosition = sourcePosition
    DamageIndicatorFlashUntil = os.clock() + 1.35

    EnsureFOVCircle()
    UpdateFOVCircle()

    task.delay(1.4, function()
        if os.clock() >= DamageIndicatorFlashUntil then
            DamageIndicatorWorldPosition = nil
            if DamageIndicatorArrow then
                DamageIndicatorArrow.Visible = false
            end
            UpdateFOVCircle()
        end
    end)
end

local function SetupDamageIndicatorForCharacter(char)
    if not AimbotData.DamageIndicator then return end
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    LastHumanoidHealth = humanoid.Health

    table.insert(DamageIndicatorConnections, humanoid.HealthChanged:Connect(function(newHealth)
        local oldHealth = LastHumanoidHealth or newHealth
        LastHumanoidHealth = newHealth

        if newHealth < oldHealth and humanoid.Health > 0 then
            local attacker = GetTaggedDamageSource(humanoid)
            if attacker and AimbotData.TeamCheck and IsSameTeam(attacker) then
                return
            end
            TriggerDamageIndicator(attacker, humanoid)
        end
    end))
end

local function SetDamageIndicator(state)
    AimbotData.DamageIndicator = state == true

    DisconnectDamageIndicator()

    if DamageIndicatorBtn then
        DamageIndicatorBtn.Text = AimbotData.DamageIndicator and "DAMAGE INDICATOR: ON" or "DAMAGE INDICATOR: OFF"
    end

    if AimbotData.DamageIndicator then
        SetupDamageIndicatorForCharacter(Player.Character)
        table.insert(DamageIndicatorConnections, Player.CharacterAdded:Connect(function(char)
            task.wait(0.4)
            SetupDamageIndicatorForCharacter(char)
        end))
    end

    UpdateFOVCircle()
    if AimbotData.ESP then
        DoESP()
    end
end

ClearESPForPlayer = function(plr)
    local old = ESPList[plr]
    if old then
        pcall(function() old:Destroy() end)
        ESPList[plr] = nil
    end

    -- Clean any old highlight that may still be inside the current character.
    if plr and plr.Character then
        for _, obj in ipairs(plr.Character:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "HaimiyachESP" then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end

RefreshESPPlayer = function(plr)
    if not plr or plr == Player then return end

    if not AimbotData.ESP then
        ClearESPForPlayer(plr)
        return
    end

    local char = plr.Character
    if not char or not char.Parent then
        ClearESPForPlayer(plr)
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        ClearESPForPlayer(plr)
        return
    end

    local hl = ESPList[plr]

    -- Parent the Highlight to ScreenGui instead of the character.
    -- If it is parented to the character, Roblox destroys it when the character dies/respawns,
    -- which makes ESP disappear until a manual refresh.
    if not hl or not hl.Parent or not hl:IsDescendantOf(game) then
        ClearESPForPlayer(plr)
        hl = Instance.new("Highlight")
        hl.Name = "HaimiyachESP"
        hl.FillTransparency = 0.2
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = ScreenGui
        ESPList[plr] = hl
    end

    if hl.Adornee ~= char then
        hl.Adornee = char
    end

    hl.Enabled = true

    if AimbotData.TeamCheck and IsSameTeam(plr) then
        -- Same team = blue/cyan
        hl.FillColor = Color3.fromRGB(0, 170, 255)
        hl.OutlineColor = Color3.fromRGB(200, 240, 255)
    else
        -- Enemy / FFA / no team = red
        hl.FillColor = Color3.fromRGB(255, 50, 50)
        hl.OutlineColor = Color3.fromRGB(255, 200, 200)
    end
end

local ESPCharacterConnections = {}

local function DisconnectESPCharacter(plr)
    local cons = ESPCharacterConnections[plr]
    if cons then
        for _, con in ipairs(cons) do
            pcall(function() con:Disconnect() end)
        end
    end
    ESPCharacterConnections[plr] = nil
end

local function AddESPCharacterConnection(plr, con)
    if not con then return end
    ESPCharacterConnections[plr] = ESPCharacterConnections[plr] or {}
    table.insert(ESPCharacterConnections[plr], con)
end

local function HookESPCharacter(plr, char)
    if not plr or plr == Player then return end
    DisconnectESPCharacter(plr)

    if not char then return end

    task.spawn(function()
        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if humanoid then
            AddESPCharacterConnection(plr, humanoid.Died:Connect(function()
                ClearESPForPlayer(plr)
            end))
        end
    end)

    -- Refresh several times because many Roblox games build the character parts a bit late.
    task.spawn(function()
        ClearESPForPlayer(plr)
        char:WaitForChild("HumanoidRootPart", 5)
        char:WaitForChild("Humanoid", 5)

        for _, delayTime in ipairs({0.15, 0.5, 1.0}) do
            task.wait(delayTime)
            if AimbotData.ESP and plr.Character == char then
                RefreshESPPlayer(plr)
            end
        end
    end)
end

function SetupESPWatcher()
    for _, con in pairs(ESPConnections) do
        pcall(function() con:Disconnect() end)
    end
    ESPConnections = {}

    for plr in pairs(ESPCharacterConnections) do
        DisconnectESPCharacter(plr)
    end

    local function WatchPlayer(plr)
        if not plr or plr == Player then return end

        table.insert(ESPConnections, plr.CharacterAdded:Connect(function(char)
            HookESPCharacter(plr, char)
        end))

        table.insert(ESPConnections, plr.CharacterRemoving:Connect(function()
            ClearESPForPlayer(plr)
            DisconnectESPCharacter(plr)
        end))

        table.insert(ESPConnections, plr:GetPropertyChangedSignal("Team"):Connect(function()
            if AimbotData.ESP then
                DoESP()
            end
        end))

        table.insert(ESPConnections, plr:GetPropertyChangedSignal("TeamColor"):Connect(function()
            if AimbotData.ESP then
                DoESP()
            end
        end))

        table.insert(ESPConnections, plr:GetPropertyChangedSignal("Neutral"):Connect(function()
            if AimbotData.ESP then
                DoESP()
            end
        end))

        if plr.Character then
            HookESPCharacter(plr, plr.Character)
            if AimbotData.ESP then
                RefreshESPPlayer(plr)
            end
        end
    end

    table.insert(ESPConnections, Players.PlayerAdded:Connect(function(plr)
        WatchPlayer(plr)
    end))

    table.insert(ESPConnections, Players.PlayerRemoving:Connect(function(plr)
        ClearESPForPlayer(plr)
        DisconnectESPCharacter(plr)
    end))

    for _, plr in ipairs(Players:GetPlayers()) do
        WatchPlayer(plr)
    end
end
SetupESPWatcher()

-- Strong ESP resync for FFA / fast-respawn games.
-- Some games replace characters/parts without clean CharacterAdded timing, so this keeps ESP alive.
task.spawn(function()
    while task.wait(0.7) do
        if AimbotData and AimbotData.ESP then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player then
                    local ok = pcall(function()
                        RefreshESPPlayer(plr)
                    end)
                    if not ok then
                        pcall(function() ClearESPForPlayer(plr) end)
                    end
                end
            end
        end
    end
end)

function GetClosestTarget()
    if not Camera then return nil end
    local closestDist = AimbotData.FOV
    local bestTarget = nil
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            if AimbotData.TeamCheck and IsSameTeam(p) then
                -- skip same team
            else
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local part = GetBestPart(p.Character)
                    if part then
                        local pos, on = Camera:WorldToViewportPoint(part.Position)
                        if on then
                            local dist = (center - Vector2.new(pos.X, pos.Y)).Magnitude
                            if dist < closestDist then
                                local visible = true
                                if AimbotData.VisibleCheck then
                                    local params = RaycastParams.new()
                                    params.FilterDescendantsInstances = {Player.Character, Camera}
                                    params.FilterType = Enum.RaycastFilterType.Exclude
                                    local res = Workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * (part.Position - Camera.CFrame.Position).Magnitude, params)
                                    if not (res and res.Instance:IsDescendantOf(p.Character)) then
                                        visible = false
                                    end
                                end
                                if visible then
                                    closestDist = dist
                                    bestTarget = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

function GetInputPos()
    if UserInputService.TouchEnabled then
        return Camera and Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) or Vector2.new(0,0)
    else
        return UserInputService:GetMouseLocation()
    end
end

function ShouldAim()
    if not AimbotData.Enabled then return false end
    if UserInputService.TouchEnabled then return true
    else return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
end

function StartAimbot()
    if AimbotLoop then AimbotLoop:Disconnect() end
    AimbotLoop = RunService.RenderStepped:Connect(function()
        if AimbotData.ESP then DoESP() end
        if not ShouldAim() then
            if AimbotLockedTarget ~= nil then
                AimbotLockedTarget = nil
                UpdateFOVCircle()
            end
            return
        end

        local target = GetClosestTarget()
        if not target then
            if AimbotLockedTarget ~= nil then
                AimbotLockedTarget = nil
                UpdateFOVCircle()
            end
            return
        end

        AimbotLockedTarget = target
        UpdateFOVCircle()

        local pos, on = Camera:WorldToViewportPoint(target.Position)
        if not on then
            AimbotLockedTarget = nil
            UpdateFOVCircle()
            return
        end
        local mouse = GetInputPos()
        local dx = (pos.X - mouse.X) * AimbotData.Sensitivity
        local dy = (pos.Y - mouse.Y) * AimbotData.Sensitivity
        if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
        local smooth = math.max(AimbotData.Smoothness, 0.05)
        local moveX = dx / (smooth * 15)
        local moveY = dy / (smooth * 15)
        pcall(function()
            if mousemoverel then mousemoverel(moveX, moveY)
            elseif mouse1move then mouse1move(moveX, moveY)
            elseif syn and syn.input then syn.input.mouse_move(moveX, moveY)
            elseif getgenv().mouse1move then getgenv().mouse1move(moveX, moveY)
            end
        end)
    end)
end

function StopAimbot()
    AimbotLockedTarget = nil
    UpdateFOVCircle()
    if AimbotLoop then
        AimbotLoop:Disconnect()
        AimbotLoop = nil
    end
end

-- TOMBOL AIMBOT
local aimBtn, espBtn, showFovBtn, teamBtn, visBtn, resetBtn

aimBtn = MakeButton(
    AimbotData.Enabled and "AIMBOT: ON" or "AIMBOT: OFF",
    Menu4Scroll,
    function()
        AimbotData.Enabled = not AimbotData.Enabled
        aimBtn.Text = AimbotData.Enabled and "AIMBOT: ON" or "AIMBOT: OFF"
        if AimbotData.Enabled then StartAimbot() else StopAimbot() end
        Menu4StatusLabel.Text = string.format("Aimbot: %s  |  ESP: %s",
            AimbotData.Enabled and "ON" or "OFF",
            AimbotData.ESP and "ON" or "OFF")
        Notify("Aimbot", AimbotData.Enabled and "Enabled" or "Disabled", 2)
    end
)

espBtn = MakeButton(
    AimbotData.ESP and "ESP: ON" or "ESP: OFF",
    Menu4Scroll,
    function()
        AimbotData.ESP = not AimbotData.ESP
        espBtn.Text = AimbotData.ESP and "ESP: ON" or "ESP: OFF"
        DoESP()
        Menu4StatusLabel.Text = string.format("Aimbot: %s  |  ESP: %s",
            AimbotData.Enabled and "ON" or "OFF",
            AimbotData.ESP and "ON" or "OFF")
        Notify("ESP", AimbotData.ESP and "Enabled" or "Disabled", 2)
    end
)

showFovBtn = MakeButton(
    AimbotData.ShowFOV and "SHOW FOV: ON" or "SHOW FOV: OFF",
    Menu4Scroll,
    function()
        SetFOVCircleVisible(not AimbotData.ShowFOV)
        showFovBtn.Text = AimbotData.ShowFOV and "SHOW FOV: ON" or "SHOW FOV: OFF"
        Notify("FOV Circle", AimbotData.ShowFOV and "Enabled" or "Disabled", 2)
    end
)

DamageIndicatorBtn = MakeButton(
    AimbotData.DamageIndicator and "DAMAGE INDICATOR: ON" or "DAMAGE INDICATOR: OFF",
    Menu4Scroll,
    function()
        SetDamageIndicator(not AimbotData.DamageIndicator)
        Notify("Damage Indicator", AimbotData.DamageIndicator and "Enabled" or "Disabled", 2)
    end
)

-- SEPARATOR SETTINGS
New("TextLabel", {
    Size = UDim2.new(1,0,0,20),
    BackgroundTransparency = 1,
    Text = "--- SETTINGS ---",
    TextColor3 = GetTheme().Accent,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Center,
    Parent = Menu4Scroll
})

-- FOV / SMOOTHNESS / SENSITIVITY INPUTS
local fovLabel, smoothLabel, sensLabel
local fovBox, smoothBox, sensBox
local SetFovInput, SetSmoothInput, SetSensInput

fovLabel, fovBox, SetFovInput = MakeNumberInput(Menu4Scroll, "FOV", AimbotData.FOV, 50, 400, nil, function(value)
    AimbotData.FOV = value
    UpdateFOVCircle()
    Notify("FOV", AimbotData.FOV, 1.5)
end)

smoothLabel, smoothBox, SetSmoothInput = MakeNumberInput(Menu4Scroll, "SMOOTHNESS", AimbotData.Smoothness, 0.02, 1, 2, function(value)
    AimbotData.Smoothness = value
    Notify("Smoothness", "Set to " .. tostring(AimbotData.Smoothness), 1.5)
end)

sensLabel, sensBox, SetSensInput = MakeNumberInput(Menu4Scroll, "SENSITIVITY", AimbotData.Sensitivity, 0.2, 3, 2, function(value)
    AimbotData.Sensitivity = value
    Notify("Sensitivity", "Set to " .. tostring(AimbotData.Sensitivity), 1.5)
end)

-- SEPARATOR OPTIONS
New("TextLabel", {
    Size = UDim2.new(1,0,0,20),
    BackgroundTransparency = 1,
    Text = "--- OPTIONS ---",
    TextColor3 = GetTheme().Accent,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Center,
    Parent = Menu4Scroll
})

-- TEAM CHECK
teamBtn = MakeButton(
    AimbotData.TeamCheck and "TEAM CHECK: ON" or "TEAM CHECK: OFF",
    Menu4Scroll,
    function()
        AimbotData.TeamCheck = not AimbotData.TeamCheck
        teamBtn.Text = AimbotData.TeamCheck and "TEAM CHECK: ON" or "TEAM CHECK: OFF"
        if AimbotData.ESP then DoESP() end
        Notify("Team Check", AimbotData.TeamCheck and "Enabled" or "Disabled", 1.5)
    end
)

-- VISIBLE CHECK
visBtn = MakeButton(
    AimbotData.VisibleCheck and "VISIBLE CHECK: ON" or "VISIBLE CHECK: OFF",
    Menu4Scroll,
    function()
        AimbotData.VisibleCheck = not AimbotData.VisibleCheck
        visBtn.Text = AimbotData.VisibleCheck and "VISIBLE CHECK: ON" or "VISIBLE CHECK: OFF"
        Notify("Visible Check", AimbotData.VisibleCheck and "Enabled" or "Disabled", 1.5)
    end
)

-- RESET
resetBtn = MakeButton("RESET SETTINGS", Menu4Scroll, function()
    AimbotData.Enabled = false
    AimbotData.ESP = false
    AimbotData.ShowFOV = false
    SetDamageIndicator(false)
    AimbotData.FOV = 150
    AimbotData.Smoothness = 0.02
    AimbotData.Sensitivity = 1.5
    AimbotData.TeamCheck = true
    AimbotData.VisibleCheck = true
    
    aimBtn.Text = "AIMBOT: OFF"
    espBtn.Text = "ESP: OFF"
    if showFovBtn then showFovBtn.Text = "SHOW FOV: OFF" end
    SetFOVCircleVisible(false)
    if SetFovInput then SetFovInput(AimbotData.FOV, true) end
    if SetSmoothInput then SetSmoothInput(AimbotData.Smoothness, true) end
    if SetSensInput then SetSensInput(AimbotData.Sensitivity, true) end
    teamBtn.Text = "TEAM CHECK: ON"
    visBtn.Text = "VISIBLE CHECK: ON"
    Menu4StatusLabel.Text = "Aimbot: OFF  |  ESP: OFF"
    
    StopAimbot()
    for _, hl in pairs(ESPList) do pcall(function() hl:Destroy() end) end
    ESPList = {}
    Notify("Aimbot", "Aimbot settings have been reset.", 2)
end)

-- INFO
New("TextLabel", {
    Size = UDim2.new(1,0,0,40),
    BackgroundTransparency = 1,
    Text = UserInputService.TouchEnabled and "Mobile: Auto aim | Head priority" or "PC: Hold Right Click | Head priority",
    TextColor3 = GetTheme().Muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Center,
    Parent = Menu4Scroll
})

-- INIT AIMBOT LOOP & ESP
if AimbotData.Enabled then StartAimbot() else StopAimbot() end
if AimbotData.ESP then DoESP() end
SetFOVCircleVisible(AimbotData.ShowFOV)
SetDamageIndicator(AimbotData.DamageIndicator)

-- DRAG
local dragging = false
local dragStart = nil
local startPos = nil

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- FUNCTIONS
function UpdateStatus()
    StatusLabel.Text = tostring(CountSelectedTargets()) .. " target(s) selected"
    if UpdateFlingListButtonText then UpdateFlingListButtonText() end
end

function ApplyTheme(themeName)
    local theme = Themes[themeName]
    if not theme then return end
    CurrentThemeName = themeName
    MainFrame.BackgroundColor3 = theme.Background
    MainGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, theme.Background), ColorSequenceKeypoint.new(1, theme.Panel) })
    MainStroke.Color = theme.Accent
    TitleBar.BackgroundColor3 = theme.Top
    TitleBarFix.BackgroundColor3 = theme.Top
    Title.TextColor3 = theme.Accent
    SettingsButton.BackgroundColor3 = theme.Button
    SettingsButton.TextColor3 = theme.Text
    OpenButton.BackgroundColor3 = theme.Background
    ContentFrame.BackgroundTransparency = 1
    StatusLabel.TextColor3 = theme.Text
    SelectionFrame.BackgroundColor3 = theme.Panel
    SelectionStroke.Color = theme.Accent
    if MainMenuPage then MainMenuPage.BackgroundColor3 = theme.Panel end
    if MainMenuStroke then MainMenuStroke.Color = theme.Accent end
    if Menu2Page then Menu2Page.BackgroundColor3 = theme.Panel end
    if Menu2Stroke then Menu2Stroke.Color = theme.Accent end
    if Menu3Page then Menu3Page.BackgroundColor3 = theme.Panel end
    if Menu3Stroke then Menu3Stroke.Color = theme.Accent end
    if Menu4Page then Menu4Page.BackgroundColor3 = theme.Panel end
    if Menu4Stroke then Menu4Stroke.Color = theme.Accent end
    if MenuTitle then MenuTitle.TextColor3 = theme.Text end
    if Menu2Label then Menu2Label.TextColor3 = theme.Text end
    if Menu3Label then Menu3Label.TextColor3 = theme.Text end
    if Menu4Label then Menu4Label.TextColor3 = theme.Text end
    if Menu2Scroll then Menu2Scroll.ScrollBarImageColor3 = theme.Accent end
    if Menu2Placeholder then Menu2Placeholder.TextColor3 = theme.Muted end
    SettingsPage.BackgroundColor3 = theme.Panel
    SettingsStroke.Color = theme.Accent
    SelectAllButton.BackgroundColor3 = theme.Button
    DeselectAllButton.BackgroundColor3 = theme.Button
    for _, obj in ipairs(SettingsScroll:GetChildren()) do
        if obj:IsA("TextLabel") then obj.TextColor3 = theme.Text end
    end
    for _, data in pairs(PlayerCheckboxes) do
        if data.Entry then data.Entry.BackgroundColor3 = theme.Entry end
        if data.Checkbox then data.Checkbox.BackgroundColor3 = theme.Button end
        if data.NameLabel then data.NameLabel.TextColor3 = theme.Text end
    end
    for _, data in ipairs(ThemedButtons) do
        if data.Button then
            data.Button.BackgroundColor3 = theme.Button
            data.Button.TextColor3 = theme.Text
        end
        if data.Stroke then data.Stroke.Color = theme.Accent end
    end
    if FlingPage then FlingPage.BackgroundColor3 = theme.Panel end
    if FlingPageStroke then FlingPageStroke.Color = theme.Accent end
    if StyleFlingPlayerListButton then StyleFlingPlayerListButton() end
    if StyleFlingActionButtons then StyleFlingActionButtons() end
    for _, data in ipairs(ThemedInputs) do
        if data.Label then data.Label.TextColor3 = theme.Text end
        if data.Box then
            data.Box.BackgroundColor3 = theme.Button
            data.Box.TextColor3 = theme.Text
            data.Box.PlaceholderColor3 = theme.Muted
        end
        if data.Stroke then data.Stroke.Color = theme.Accent end
    end
    for _, data in ipairs(ThemedPickers) do
        if data.Label then data.Label.TextColor3 = theme.Text end
        if data.Picker then
            data.Picker.BackgroundColor3 = theme.Button
            data.Picker.TextColor3 = theme.Text
        end
        if data.PickerStroke then data.PickerStroke.Color = theme.Accent end
        if data.Dropdown then data.Dropdown.BackgroundColor3 = theme.Panel2 end
        if data.DropdownStroke then data.DropdownStroke.Color = theme.Accent end
        if data.Options then
            for _, opt in ipairs(data.Options) do
                local optTheme = Themes[opt.ThemeName] or theme
                if opt.Button then
                    opt.Button.BackgroundColor3 = optTheme.Button or theme.Button
                    opt.Button.TextColor3 = optTheme.Text or theme.Text
                end
                if opt.Stroke then opt.Stroke.Color = optTheme.Accent or theme.Accent end
            end
        end
    end
    if FlySpeedLabel then FlySpeedLabel.TextColor3 = theme.Text end
    if MoveSpeedLabel then MoveSpeedLabel.TextColor3 = theme.Text end
    if Menu3Scroll then Menu3Scroll.ScrollBarImageColor3 = theme.Accent end
    if FlyButton then FlyButton.TextColor3 = theme.Text end
    if InfJumpButton then InfJumpButton.TextColor3 = theme.Text end
    if Menu4Scroll then
        Menu4Scroll.ScrollBarImageColor3 = theme.Accent
        for _, obj in ipairs(Menu4Scroll:GetDescendants()) do
            if obj:IsA("TextLabel") then
                if obj.Text == "--- SETTINGS ---" or obj.Text == "--- OPTIONS ---" then
                    obj.TextColor3 = theme.Accent
                elseif string.find(obj.Text or "", "Mobile:") or string.find(obj.Text or "", "PC:") then
                    obj.TextColor3 = theme.Muted
                else
                    obj.TextColor3 = theme.Text
                end
            end
        end
    end
    if SettingsButtonStroke then SettingsButtonStroke.Color = theme.Accent end
end

function SafeResize(width, height, fromInput)
    CurrentWidth = math.clamp(tonumber(width) or CurrentWidth, 240, 420)
    CurrentHeight = math.clamp(tonumber(height) or CurrentHeight, 300, 500)
    MainFrame.Size = UDim2.new(0, CurrentWidth, 0, CurrentHeight)
    MainFrame.Position = UDim2.new(0.5, -CurrentWidth / 2, 0.5, -CurrentHeight / 2)
    UpdateFlingResponsiveLayout()
    if SizeFrame then SizeFrame.Size = UDim2.new(1, 0, 0, 148) end
    if ThemeFrame then ThemeFrame.Size = UDim2.new(1, 0, 0, 96) end
    if not fromInput then
        if SetWidthInput then SetWidthInput(CurrentWidth, true) end
        if SetHeightInput then SetHeightInput(CurrentHeight, true) end
    end
end

function RefreshPlayerList()
    for _, child in ipairs(PlayerScrollFrame:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    PlayerCheckboxes = {}
    local playerList = Players:GetPlayers()
    table.sort(playerList, function(a, b) return a.Name:lower() < b.Name:lower() end)
    local theme = GetTheme()
    for _, player in ipairs(playerList) do
        if player ~= Player then
            local selected = SelectedTargets[player.Name] ~= nil
            local entry = New("Frame", {
                Size = UDim2.new(1, -4, 0, FlingEntryHeight),
                BackgroundColor3 = theme.Entry,
                BorderSizePixel = 0,
                ZIndex = 14,
                Parent = PlayerScrollFrame
            })
            Corner(entry, 10)
            local checkbox = New("TextButton", {
                Size = UDim2.new(0, FlingCheckboxSize, 0, FlingCheckboxSize),
                Position = UDim2.new(0, FlingCheckboxOffset, 0.5, -FlingCheckboxSize / 2),
                BackgroundColor3 = theme.Button,
                BorderSizePixel = 0,
                Text = "",
                ZIndex = 15,
                Parent = entry
            })
            Corner(checkbox, 8)
            local checkmark = New("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "X",
                TextColor3 = theme.Accent2,
                Font = Enum.Font.GothamBlack,
                TextSize = math.max(14, FlingCheckboxSize - 8),
                Visible = selected,
                ZIndex = 16,
                Parent = checkbox
            })
            local nameLabel = New("TextLabel", {
                Size = UDim2.new(1, -(FlingNameOffset + 10), 1, 0),
                Position = UDim2.new(0, FlingNameOffset, 0, 0),
                BackgroundTransparency = 1,
                Text = player.DisplayName .. "  @" .. player.Name,
                TextColor3 = theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = FlingEntryTextSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 15,
                Parent = entry
            })
            local clickArea = New("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 20,
                Parent = entry
            })
            local function toggle()
                if SelectedTargets[player.Name] then
                    SelectedTargets[player.Name] = nil
                    checkmark.Visible = false
                else
                    SelectedTargets[player.Name] = player
                    checkmark.Visible = true
                end
                UpdateStatus()
            end
            -- Debounce untuk HP
            local lastToggle = 0
            local function safeToggle()
                local now = os.clock()
                if now - lastToggle < 0.25 then return end
                lastToggle = now
                toggle()
            end
            clickArea.Activated:Connect(safeToggle)
            clickArea.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    safeToggle()
                end
            end)
            PlayerCheckboxes[player.Name] = { Entry = entry, Checkbox = checkbox, Checkmark = checkmark, NameLabel = nameLabel }
        end
    end
    UpdateStatus()
end

function ToggleAllPlayers(selectAll)
    if selectAll then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Player then SelectedTargets[player.Name] = player end
        end
    else
        for name in pairs(SelectedTargets) do SelectedTargets[name] = nil end
    end
    for _, data in pairs(PlayerCheckboxes) do
        if data and data.Checkmark then data.Checkmark.Visible = selectAll and true or false end
    end
    UpdateStatus()
end

-- SETTINGS BUTTONS / INPUTS
WidthLabel, WidthBox, SetWidthInput = MakeNumberInput(SizeFrame, "WIDTH", CurrentWidth, 240, 420, nil, function(value)
    SafeResize(value, CurrentHeight, true)
end)
HeightLabel, HeightBox, SetHeightInput = MakeNumberInput(SizeFrame, "HEIGHT", CurrentHeight, 300, 500, nil, function(value)
    SafeResize(CurrentWidth, value, true)
end)

PresetSizeFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 23,
    Parent = SizeFrame
})
PresetSizeGrid = New("UIGridLayout", {
    CellSize = UDim2.new(1/3, -6, 0, 32),
    CellPadding = UDim2.new(0, 9, 0, 0),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = PresetSizeFrame
})
PresetSmallButton = MakeButton("SMALL", PresetSizeFrame, function() SafeResize(260, 300, false) Notify("UI Size", "Compact", 1.5) end)
PresetNormalButton = MakeButton("NORMAL", PresetSizeFrame, function() SafeResize(300, 330, false) Notify("UI Size", "Standard", 1.5) end)
PresetBigButton = MakeButton("BIG", PresetSizeFrame, function() SafeResize(340, 400, false) Notify("UI Size", "Large", 1.5) end)
for _, btn in ipairs({PresetSmallButton, PresetNormalButton, PresetBigButton}) do if btn then btn.TextSize = 11 end end

ColourLabel, ColourPicker, SetColourPicker, GetSelectedColour = MakeOptionPicker(
    ThemeFrame,
    "COLOR",
    {"DARK", "CYAN", "RED DARK", "BLUE", "PURPLE", "GREEN", "GOLD", "PINK", "ORANGE"},
    CurrentThemeName,
    function(value)
        ApplyTheme(value)
        Notify("Color", "Theme set to " .. tostring(value), 1.5)
    end
)

-- ANTI FLING DEFENSE (COMPLETE - UNCHANGED)
AntiFlingConstraints = {}
AntiFlingOriginalCanCollide = {}
AntiFlingNextRefresh = 0
AntiFlingRefreshDelay = 0.85
AntiFlingRadius = 55

function ClearAntiFlingConstraints(restoreCollision)
    for localPart, pairMap in pairs(AntiFlingConstraints) do
        for otherPart, constraint in pairs(pairMap) do
            if constraint and constraint.Parent then pcall(function() constraint:Destroy() end) end
        end
    end
    AntiFlingConstraints = {}
    if restoreCollision then
        for part, oldValue in pairs(AntiFlingOriginalCanCollide) do
            if part and part.Parent and part:IsA("BasePart") then pcall(function() part.CanCollide = oldValue end) end
        end
        AntiFlingOriginalCanCollide = {}
    end
end

function GetBaseParts(model)
    local parts = {}
    if not model then return parts end
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then table.insert(parts, obj) end
    end
    return parts
end

function GetCharacterRoot(char)
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return char:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart)
end

function PruneAntiFlingConstraints()
    for localPart, pairMap in pairs(AntiFlingConstraints) do
        if not localPart or not localPart.Parent then
            for _, constraint in pairs(pairMap) do
                if constraint and constraint.Parent then pcall(function() constraint:Destroy() end) end
            end
            AntiFlingConstraints[localPart] = nil
        else
            for otherPart, constraint in pairs(pairMap) do
                if not otherPart or not otherPart.Parent or not constraint or not constraint.Parent or constraint.Part0 ~= localPart or constraint.Part1 ~= otherPart then
                    if constraint and constraint.Parent then pcall(function() constraint:Destroy() end) end
                    pairMap[otherPart] = nil
                end
            end
        end
    end
end

function CreateNoCollision(localPart, otherPart, parent)
    if not localPart or not otherPart or not parent then return end
    if not localPart.Parent or not otherPart.Parent then return end
    if localPart == otherPart then return end
    if not localPart:IsA("BasePart") or not otherPart:IsA("BasePart") then return end
    AntiFlingConstraints[localPart] = AntiFlingConstraints[localPart] or {}
    local existing = AntiFlingConstraints[localPart][otherPart]
    if existing and existing.Parent then return end
    if AntiFlingOriginalCanCollide[otherPart] == nil then
        AntiFlingOriginalCanCollide[otherPart] = otherPart.CanCollide
    end
    pcall(function() otherPart.CanCollide = false end)
    local ok, constraint = pcall(function()
        local ncc = Instance.new("NoCollisionConstraint")
        ncc.Name = "__HaimiyachAntiFlingNoCollision"
        ncc.Part0 = localPart
        ncc.Part1 = otherPart
        ncc.Parent = parent
        return ncc
    end)
    if ok and constraint then
        AntiFlingConstraints[localPart][otherPart] = constraint
    end
end

function RefreshAntiFlingNoCollision()
    if not AntiFlingActive then return end
    local localChar = Player.Character
    if not localChar then return end
    local localRoot = GetCharacterRoot(localChar)
    if not localRoot then return end
    local localHumanoid = localChar:FindFirstChildOfClass("Humanoid")
    if localHumanoid then
        if localHumanoid.Sit then localHumanoid.Sit = false end
        if localHumanoid.PlatformStand then localHumanoid.PlatformStand = false end
    end
    PruneAntiFlingConstraints()
    local localParts = GetBaseParts(localChar)
    if #localParts == 0 then return end
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= Player then
            local otherChar = otherPlayer.Character
            local otherRoot = GetCharacterRoot(otherChar)
            if otherChar and otherRoot then
                local distance = (otherRoot.Position - localRoot.Position).Magnitude
                if distance <= AntiFlingRadius then
                    local otherParts = GetBaseParts(otherChar)
                    for _, localPart in ipairs(localParts) do
                        for _, otherPart in ipairs(otherParts) do
                            CreateNoCollision(localPart, otherPart, localChar)
                        end
                    end
                end
            end
        end
    end
end

function CleanAntiFlingCharacter(char)
    if not AntiFlingActive then return end
    local now = os.clock()
    if now < AntiFlingNextRefresh then return end
    AntiFlingNextRefresh = now + AntiFlingRefreshDelay
    RefreshAntiFlingNoCollision()
end

ToggleAntiFling = function()
    AntiFlingActive = not AntiFlingActive
    if AntiFlingButton then
        AntiFlingButton.Text = AntiFlingActive and "ANTI FLING: ON" or "ANTI FLING: OFF"
    end
    if AntiFlingActive then
        if FlingActive and StopFling then StopFling() end
        if AntiFlingConnection then AntiFlingConnection:Disconnect() end
        ClearAntiFlingConstraints(true)
        AntiFlingNextRefresh = 0
        AntiFlingConnection = RunService.Heartbeat:Connect(function()
            CleanAntiFlingCharacter(Player.Character)
        end)
        RefreshAntiFlingNoCollision()
        Notify("Anti Fling", "Enabled", 2)
    else
        if AntiFlingConnection then
            AntiFlingConnection:Disconnect()
            AntiFlingConnection = nil
        end
        ClearAntiFlingConstraints(true)
        AntiFlingNextRefresh = 0
        Notify("Anti Fling", "Disabled", 2)
    end
end

-- EVENTS
SettingsButton.Activated:Connect(function()
    if SettingsPage.Visible then ShowPage("HOME") else ShowPage("SETTINGS") end
end)
CloseButton.Activated:Connect(function()
    -- Disable the old custom GUI while CustomUI UI is in use.
    MainFrame.Visible = false
    OpenButton.Visible = false
end)
OpenButton.Activated:Connect(function()
    -- Do not show the old custom GUI.
    MainFrame.Visible = false
    OpenButton.Visible = false
end)

Players.PlayerAdded:Connect(function() RefreshPlayerList() end)
Players.PlayerRemoving:Connect(function(player)
    SelectedTargets[player.Name] = nil
    RefreshPlayerList()
end)
Player.CharacterAdded:Connect(function(char)
    task.wait(1)
    if AntiFlingActive then CleanAntiFlingCharacter(char) end
end)

-- CLEANUP ON CLOSE
CloseButton.Activated:Connect(function()
    StopAimbot()
end)

-- LOOP ESP REFRESH
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        if AimbotData.ESP then DoESP() end
        task.wait(1)
    end
end)

-- INIT
SafeResize(CurrentWidth, CurrentHeight)
CurrentThemeName = "DARK"
ApplyTheme(CurrentThemeName)
RefreshPlayerList()
ShowPage("HOME")
pcall(function()
    if MainFrame then MainFrame.Visible = false end
    if OpenButton then OpenButton.Visible = false end
end)

Notify("HAIMIYACH HUB", "loaded successfully.", 3)


-- =========================================================
-- MENU 2 - FE EMOTE BACKEND
-- =========================================================
local FEEmoteSelected = "Wave"
local FEEmoteLooped = false
local FEEmoteSpeed = 1
local FEEmoteTrack = nil
local FEEmoteAnimation = nil

local FEEmoteList = {
    {Name = "1 2 3 Freeze", AnimationId = 99666006095369},
    {Name = "6 7", AnimationId = 117781289000852},
    {Name = "Air Guitar", AnimationId = 3696761354},
    {Name = "Andy's DELICIA DANCE", AnimationId = 116182167550557},
    {Name = "Anime Sleep", AnimationId = 107454576443439},
    {Name = "Applaud", AnimationId = 5915693819},
    {Name = "APT DANCE", AnimationId = 100737367655655},
    {Name = "Baby Ice Dance", AnimationId = 71780273112858},
    {Name = "Bag Up", AnimationId = 73191192797882},
    {Name = "Bang Bang Bang", AnimationId = 140168210563968},
    {Name = "Basketball Head", AnimationId = 82941594615418},
    {Name = "Best Boggie Groove Club Dance", AnimationId = 78428745803276},
    {Name = "Bird Brain", AnimationId = 126204710132518},
    {Name = "BLACKPINK How You Like That", AnimationId = 106522804875525},
    {Name = "BLACKPINK Pink Dance", AnimationId = 106522804875527},
    {Name = "BLACKPINK Pink Venom", AnimationId = 106522804875524},
    {Name = "BLACKPINK Playing With Fire", AnimationId = 106522804875526},
    {Name = "BLACKPINK Shut Down", AnimationId = 106522804875523},
    {Name = "BLURRED LINES DANCE", AnimationId = 91195956272951},
    {Name = "Body Phone", AnimationId = 95714033584938},
    {Name = "Boom Shake", AnimationId = 106522804875535},
    {Name = "Bored", AnimationId = 5230661597},
    {Name = "Bossy Girl", AnimationId = 100012593394329},
    {Name = "BOUNCE WITH IT DANCE", AnimationId = 99991282567149},
    {Name = "Boxed In", AnimationId = 76663531222223},
    {Name = "BOYNEXTDOOR Knock Knock Dance", AnimationId = 80540297505662},
    {Name = "California Girls", AnimationId = 130248288787333},
    {Name = "Can't Get Enough Dance", AnimationId = 123338588277849},
    {Name = "Captivating Kpop Like Jennie", AnimationId = 117355174141394},
    {Name = "Car Transformation", AnimationId = 79360981055415},
    {Name = "Catch Catch Yena Dance", AnimationId = 106242438130255},
    {Name = "Catch Catch YENA Alt", AnimationId = 116913701204152},
    {Name = "Che Che Loop Dance", AnimationId = 121774819821582},
    {Name = "Cheer", Command = "cheer", AnimationId = 507770677},
    {Name = "Chinese Dance", AnimationId = 79865711363977},
    {Name = "Cholo Cumbia", AnimationId = 131035546452795},
    {Name = "Chromatic Sols RNG", AnimationId = 82019787808682},
    {Name = "CLAP DANCE", AnimationId = 89384484697553},
    {Name = "club cant handle me dance", AnimationId = 120172343189130},
    {Name = "Coffin Walkout", AnimationId = 117302755748327},
    {Name = "Crazy", AnimationId = 120819498172771},
    {Name = "Crazy Jumping Spider", AnimationId = 106522804875522},
    {Name = "Crossbow Morph", AnimationId = 90354248835031},
    {Name = "Crying Sit", AnimationId = 95339652051393},
    {Name = "Cute Sit", AnimationId = 87715072383313},
    {Name = "Dance 1", Command = "dance", AnimationId = 507771019},
    {Name = "Dance 2", Command = "dance2", AnimationId = 507776043},
    {Name = "Dance 3", Command = "dance3", AnimationId = 507777268},
    {Name = "Dance Warm-Up", AnimationId = 75926006855142},
    {Name = "Dance With You Some More", AnimationId = 97667611626279},
    {Name = "Dancing Fish Meme", AnimationId = 66863843952722},
    {Name = "Daoko Emote", AnimationId = 140159816880305},
    {Name = "Default Dance FORTNITE", AnimationId = 114793346878480},
    {Name = "Default Dance OG", AnimationId = 80877772569772},
    {Name = "DELIRIOS DANCE", AnimationId = 104872153953053},
    {Name = "Dia Delicia", AnimationId = 70955237174596},
    {Name = "Dirty Laundry Dance", AnimationId = 133705557351816},
    {Name = "Dizzy Spinning Head", AnimationId = 73623351299950},
    {Name = "Don't Hurt Em 2 Dance", AnimationId = 105529749698015},
    {Name = "Don't Hurt Em Dance", AnimationId = 138996301441437},
    {Name = "DOODLE DANCE", AnimationId = 105563223931607},
    {Name = "DOODLE DANCE Alt", AnimationId = 136020416750605},
    {Name = "Dot Emote", AnimationId = 137154085515108},
    {Name = "Dougie", AnimationId = 93675237485386},
    {Name = "Drone Morph", AnimationId = 85432847262900},
    {Name = "DROOP DANCE", AnimationId = 73669955658573},
    {Name = "Dropkick Alt 1", AnimationId = 98481111917153},
    {Name = "Dropkick Alt", AnimationId = 127764273000599},
    {Name = "Druski Shuffle Dance", AnimationId = 108939580037531},
    {Name = "e invisible works in every game", AnimationId = 133296330979892},
    {Name = "effortless aura floating", AnimationId = 125150640771180},
    {Name = "El Meneaito", AnimationId = 112169125180577},
    {Name = "Endless Aura Floating", AnimationId = 75011704041025},
    {Name = "Endless Ghost Floating", AnimationId = 84457462766084},
    {Name = "Failed Backflip", AnimationId = 82250437555780},
    {Name = "Fake Death", AnimationId = 94974159893660},
    {Name = "Fake Disconnected", AnimationId = 85170737638688},
    {Name = "Fake Lag", AnimationId = 100520536432570},
    {Name = "Fake Lag Fall", AnimationId = 132697161431443},
    {Name = "Fan Morph", AnimationId = 81591274525402},
    {Name = "Fart", AnimationId = 85172385910433},
    {Name = "Fashionable", AnimationId = 3333331310},
    {Name = "FF LOL Laugh", AnimationId = 129709531895539},
    {Name = "Finger Gun", AnimationId = 117657682786863},
    {Name = "Fling Emote 2025", AnimationId = 117140090625211},
    {Name = "Flying Head Glitch", AnimationId = 99033587367752},
    {Name = "Forsaken Coin Flip And Shot", AnimationId = 127381899249486},
    {Name = "Forsaken Dino Stuff", AnimationId = 111325131016020},
    {Name = "Forsaken Jetpack", AnimationId = 121193113092825},
    {Name = "Forsaken Thumbs Up", AnimationId = 118802634071307},
    {Name = "Forsaken Time Reverse", AnimationId = 133432808296417},
    {Name = "Funny Worm Break Dance", AnimationId = 99838823020668},
    {Name = "FUNKY MACARENA DANCE", AnimationId = 105093840531011},
    {Name = "Gangnam style", AnimationId = 80923445784018},
    {Name = "Gared", AnimationId = 137994630000746},
    {Name = "Get Low", AnimationId = 110189672156592},
    {Name = "Girl Front", AnimationId = 125785033794559},
    {Name = "Glitch Walk", AnimationId = 92400436034979},
    {Name = "glitch", AnimationId = 90801137139059},
    {Name = "Glow Swing", AnimationId = 134872404382541},
    {Name = "Gnarly KATSEYE", AnimationId = 79701936708542},
    {Name = "Godlike", AnimationId = 3823158750},
    {Name = "Gojo Floating Jujutsu", AnimationId = 90582990719520},
    {Name = "Gojo Groove", AnimationId = 109951131677075},
    {Name = "Griddy", AnimationId = 129149402922241},
    {Name = "Gubby", AnimationId = 95459654754047},
    {Name = "Hacker Dance", AnimationId = 103576329272587},
    {Name = "Hakari Dance", AnimationId = 116015057527853},
    {Name = "Hakari Dance Alt", AnimationId = 122147154162464},
    {Name = "Hakari Dance RPEmotes", AnimationId = 95996056452687},
    {Name = "Hand Wave Morph", AnimationId = 105209959441169},
    {Name = "Happy", AnimationId = 4849499887},
    {Name = "Hero Landing", AnimationId = 5104344710},
    {Name = "I Like To Move It", AnimationId = 94916865621656},
    {Name = "I See Kareem Dance", AnimationId = 100738069927436},
    {Name = "Iconic by Mistake Dance break", AnimationId = 119802090682277},
    {Name = "Imagine Dragons Bones Dance", AnimationId = 15689314578},
    {Name = "In the Groove", AnimationId = 126593422685490},
    {Name = "INVISIBLE Hide MM2", AnimationId = 99257567132275},
    {Name = "Invincible Wobbly", AnimationId = 123567579386306},
    {Name = "Ishowspeed Dance", AnimationId = 71431922013603},
    {Name = "Jabba Switchway", AnimationId = 103538719480738},
    {Name = "jamal's brazilian dance", AnimationId = 75582369873943},
    {Name = "Jellyous Dance", AnimationId = 116259845226856},
    {Name = "Jellyous Illit Kpop", AnimationId = 107082340537189},
    {Name = "Jojo Torture", AnimationId = 82910305160190},
    {Name = "Jumpstart Aura", AnimationId = 109146156971831},
    {Name = "Jumpstyle", AnimationId = 133248139921782},
    {Name = "Kicau Mania Dance", AnimationId = 88934624756317},
    {Name = "King Isnar Groove Emote", AnimationId = 121448325263129},
    {Name = "Kobakov Dance", AnimationId = 80586888849053},
    {Name = "Laugh", Command = "laugh", AnimationId = 507770818},
    {Name = "Le Sserafim Easy", AnimationId = 91611125175294},
    {Name = "Le Sserafim Smart", AnimationId = 105824860899126},
    {Name = "Leg Trap", AnimationId = 104746315279105},
    {Name = "Legend Isnar Aura Emote", AnimationId = 126665883593764},
    {Name = "Letter L Emote", AnimationId = 97825210370280},
    {Name = "Lit Aura", AnimationId = 97471024652382},
    {Name = "Long Fall", AnimationId = 128916062570716},
    {Name = "Low Cortisol OG", AnimationId = 125250788035617},
    {Name = "Macarena Dance", AnimationId = 117797298226262},
    {Name = "Malevolent Shrines", AnimationId = 112613020906074},
    {Name = "Mbappe Celebration", AnimationId = 101032415365235},
    {Name = "Metro Man", AnimationId = 112847019488635},
    {Name = "Mini Morph", AnimationId = 123056132344739},
    {Name = "MM2 Fake Death", AnimationId = 122738151230260},
    {Name = "Mog", AnimationId = 110305637529153},
    {Name = "Mog Body", AnimationId = 74743471570111},
    {Name = "Money Hop Switch", AnimationId = 134222090358172},
    {Name = "Monkey", AnimationId = 3716636630},
    {Name = "Needy Myers Bounce OG", AnimationId = 119501268589276},
    {Name = "Nervy Dance", AnimationId = 93234152211927},
    {Name = "NMIXX Heavy Serenade Dance", AnimationId = 120547908255427},
    {Name = "Nonchalant sit", AnimationId = 136258159413652},
    {Name = "Obby", AnimationId = 76394392186917},
    {Name = "OMG I LOVE IT DANCE", AnimationId = 129086037755203},
    {Name = "Original Club Penguin Dance", AnimationId = 122914802675592},
    {Name = "Otsukare Summer", AnimationId = 76376833018796},
    {Name = "Party Rock Anthem", AnimationId = 105248382902194},
    {Name = "Pasito cumbia", AnimationId = 139816236849217},
    {Name = "Peanut Butter Jelly", AnimationId = 100267888506831},
    {Name = "Phase Dodge MM2 Invincible Fast Teleporting", AnimationId = 91233158970085},
    {Name = "Point", Command = "point", AnimationId = 507770453},
    {Name = "Point 2", AnimationId = 3576823880},
    {Name = "Possessed", AnimationId = 106370760824973},
    {Name = "Pretty Princess Dance", AnimationId = 90279651314389},
    {Name = "Question Mark", AnimationId = 104019029213443},
    {Name = "R15 Crash Lag", AnimationId = 70501730121783},
    {Name = "R15 Lagging Run", AnimationId = 107270936527236},
    {Name = "Random Moves", AnimationId = 107591912237291},
    {Name = "Rapid Fire Gun", AnimationId = 73562814360939},
    {Name = "Rat Dance", AnimationId = 81610562663654},
    {Name = "Rat Dance OG", AnimationId = 128109831935307},
    {Name = "RAWR Skeleton", AnimationId = 84422432225920},
    {Name = "REAPER'S SHOWTIME DANCE", AnimationId = 90674844728471},
    {Name = "RIBBON DANCE DANCE", AnimationId = 94080378662404},
    {Name = "RING IT ON DANCE v2", AnimationId = 106139392589283},
    {Name = "Rise Of Death", AnimationId = 84814446163530},
    {Name = "Robot", AnimationId = 3576721660},
    {Name = "Ronaldo Siuuu Celebration", AnimationId = 107447321843426},
    {Name = "Rushin", AnimationId = 94257605787065},
    {Name = "Russian Dance", AnimationId = 74608751145756},
    {Name = "Salute", AnimationId = 3360689775},
    {Name = "Scout Conga", AnimationId = 93036664546565},
    {Name = "Scuba Nick Wilde", AnimationId = 70919402339484},
    {Name = "Shake That Thing", AnimationId = 109031585977967},
    {Name = "Shidou", AnimationId = 83455126191680},
    {Name = "Shrug", AnimationId = 3576968026},
    {Name = "Shy", AnimationId = 3576717965},
    {Name = "SILLI ALIEN CAT BABY BOO DANCE", AnimationId = 133844965296670},
    {Name = "Silly Dance", AnimationId = 86472188278784},
    {Name = "Slowed Sway", AnimationId = 102071786113518},
    {Name = "Snail Groove", AnimationId = 112400466889305},
    {Name = "Snapback Reggae", AnimationId = 106522804875534},
    {Name = "Soda Pop", AnimationId = 106522804875536},
    {Name = "SpongeBob Wiggle", AnimationId = 106522804875533},
    {Name = "Spring Trapped", AnimationId = 125974779288821},
    {Name = "Stadium", AnimationId = 3360686498},
    {Name = "Star Destroyer Morph", AnimationId = 104338220173377},
    {Name = "Stealth Plane Morph", AnimationId = 92250619740649},
    {Name = "Super Saiyan Aura", AnimationId = 70519587159467},
    {Name = "Sync Dance", AnimationId = 128228244005381},
    {Name = "Take The L", AnimationId = 133005847117851},
    {Name = "Tall Scary Creature", AnimationId = 79216795769647},
    {Name = "Tank Morph", AnimationId = 72815073007573},
    {Name = "Tenna's Cabbage Dance", AnimationId = 140406175549428},
    {Name = "TF2 Laughing", AnimationId = 76507949699963},
    {Name = "TF2 Laughing Soldier", AnimationId = 136834866733872},
    {Name = "Tilt", AnimationId = 3360692915},
    {Name = "TWICE Dance The Night Away", AnimationId = 106522804875529},
    {Name = "TWICE Fancy", AnimationId = 106522804875531},
    {Name = "TWICE Feel Special", AnimationId = 106522804875528},
    {Name = "TWICE Likey", AnimationId = 106522804875530},
    {Name = "TWICE What Is Love", AnimationId = 106522804875532},
    {Name = "Tylil Dance", AnimationId = 97165945273064},
    {Name = "Ufo Morph", AnimationId = 107388138434308},
    {Name = "Ugly Ahh Walk", AnimationId = 116603191660213},
    {Name = "uncle samsonite dance", AnimationId = 79868479080607},
    {Name = "UNIFICATION DANCE", AnimationId = 88177801390867},
    {Name = "Unknown Emote", AnimationId = 110064349530772},
    {Name = "Viral Tiktok Dance", AnimationId = 135385271601107},
    {Name = "Walk Like Egyptian", AnimationId = 104366084845323},
    {Name = "Wave", Command = "wave", AnimationId = 507770239},
    {Name = "We Can't Stop", AnimationId = 100644958552473},
    {Name = "Worm Floating Endless", AnimationId = 122127075117748},
    {Name = "Xavier Emote", AnimationId = 77861002252935},
    {Name = "Youre Too Slow", AnimationId = 103737097131582},
    {Name = "Yuji Jumping", AnimationId = 83770467908315},
    {Name = "Zero Two Dance V2", AnimationId = 95385842020103},
    {Name = "Zombie Run Lagging", AnimationId = 138037527767150},
}

local function GetFEEmoteOptions()
    local opts = {}
    for _, emote in ipairs(FEEmoteList) do
        table.insert(opts, {Name = emote.Name, Value = emote.Name})
    end
    return opts
end

local function FindFEEmote(name)
    name = tostring(name or ""):lower()
    for _, emote in ipairs(FEEmoteList) do
        if tostring(emote.Name):lower() == name then
            return emote
        end
    end
    return FEEmoteList[1]
end

local function GetFEHumanoid()
    local char = Player and Player.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil, char end
    return hum, char
end

local function StopFEEmote()
    if FEEmoteTrack then
        pcall(function()
            FEEmoteTrack:Stop(0.15)
            FEEmoteTrack:Destroy()
        end)
        FEEmoteTrack = nil
    end

    if FEEmoteAnimation then
        pcall(function()
            FEEmoteAnimation:Destroy()
        end)
        FEEmoteAnimation = nil
    end
end

local function PlayFEEmote(emoteName)
    local emote = FindFEEmote(emoteName or FEEmoteSelected)
    if not emote then
        Notify("FE Emote", "No emote selected.", 2)
        return false
    end

    local humanoid = GetFEHumanoid()
    if not humanoid then
        Notify("FE Emote", "Character is not ready.", 2)
        return false
    end

    StopFEEmote()

    local played = false
    local loadError = nil

    if emote.AnimationId then
        local animId = "rbxassetid://" .. tostring(emote.AnimationId)

        -- Legacy loader from the old EMOTE PLAYER menu.
        -- Some catalog/library links return an Animation object through GetObjects,
        -- so this keeps Dropkick/Punch style emotes working like before.
        pcall(function()
            local objects = game:GetObjects(animId)
            if objects and #objects > 0 then
                local object = objects[1]
                if object and object:IsA("Animation") and object.AnimationId and object.AnimationId ~= "" then
                    animId = object.AnimationId
                end
            end
        end)

        local animation = Instance.new("Animation")
        animation.Name = "Haimiyach_FE_Emote_" .. tostring(emote.Name)
        animation.AnimationId = animId
        FEEmoteAnimation = animation

        local track = nil
        local ok, err = pcall(function()
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then
                animator = Instance.new("Animator")
                animator.Parent = humanoid
            end
            track = animator:LoadAnimation(animation)
        end)

        -- Fallback used by the older working menu.
        if (not ok or not track) then
            ok, err = pcall(function()
                track = humanoid:LoadAnimation(animation)
            end)
        end

        if ok and track then
            FEEmoteTrack = track
            pcall(function()
                track.Priority = Enum.AnimationPriority.Action4
            end)
            pcall(function()
                track.Looped = FEEmoteLooped == true
            end)

            local playOk, playErr = pcall(function()
                track:Play(0.1, 1, tonumber(FEEmoteSpeed) or 1)
                track:AdjustSpeed(tonumber(FEEmoteSpeed) or 1)
            end)

            if playOk then
                played = true
            else
                loadError = playErr
                StopFEEmote()
            end
        else
            loadError = err
            StopFEEmote()
        end
    end

    -- Roblox built-in emotes fallback.
    if not played and emote.Command then
        local ok = pcall(function()
            played = humanoid:PlayEmote(emote.Command) and true or false
        end)
        if not ok then played = false end
    end

    if played then
        FEEmoteSelected = emote.Name
        Notify("FE Emote", emote.Name .. " started.", 1.5)
    else
        Notify("FE Emote", "Failed to play this emote.", 2)
        if loadError then
            warn("[FE EMOTE ERROR]", tostring(emote.Name), tostring(emote.AnimationId), tostring(loadError))
        end
    end

    return played
end


-- =========================================================
-- UTILITY FEATURES
-- =========================================================
local function SetAntiAFKEnabled(state)
    AntiAFKActive = state and true or false

    if AntiAFKConnection then
        pcall(function() AntiAFKConnection:Disconnect() end)
        AntiAFKConnection = nil
    end

    if AntiAFKActive then
        AntiAFKConnection = Player.Idled:Connect(function()
            if not AntiAFKActive then return end
            pcall(function()
                if VirtualUser then
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end
            end)
        end)
    end
end

local function RejoinCurrentServer()
    Notify("Server", "Rejoining current server...", 2)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
    end)
end

local function RequestPublicServers(sortOrder, cursor)
    sortOrder = sortOrder or "Desc"
    local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=" .. sortOrder .. "&limit=100"
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not body then return nil end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if decodeOk and type(data) == "table" then
        return data
    end
    return nil
end

local function TeleportToServerId(serverId, label)
    if not serverId then
        Notify("Server", "No valid server found.", 2)
        return
    end

    Notify("Server", label or "Teleporting to server...", 2)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, Player)
    end)
end

local function ServerHopRandom()
    local data = RequestPublicServers("Desc")
    local candidates = {}

    if data and type(data.data) == "table" then
        for _, server in ipairs(data.data) do
            if server.id and server.id ~= game.JobId and tonumber(server.playing or 0) < tonumber(server.maxPlayers or 0) then
                table.insert(candidates, server.id)
            end
        end
    end

    if #candidates <= 0 then
        Notify("Server", "No random server found.", 2)
        return
    end

    TeleportToServerId(candidates[math.random(1, #candidates)], "Server hopping...")
end

local function JoinSmallServer()
    local data = RequestPublicServers("Asc")
    local best = nil
    local bestPlaying = math.huge

    if data and type(data.data) == "table" then
        for _, server in ipairs(data.data) do
            local playing = tonumber(server.playing or 0) or 0
            local maxPlayers = tonumber(server.maxPlayers or 0) or 0
            if server.id and server.id ~= game.JobId and playing > 0 and playing < maxPlayers and playing < bestPlaying then
                best = server.id
                bestPlaying = playing
            end
        end
    end

    if not best then
        Notify("Server", "No small server found.", 2)
        return
    end

    TeleportToServerId(best, "Joining small server...")
end

-- =========================================================
-- VISUALS / GRAPHICS QUALITY
-- Local visual presets. These only change the user's client view.
-- FPS Boost is intentionally lightweight: no parts are hidden and no hitbox/gameplay logic is changed.
-- =========================================================
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
            GraphicsBackup.Atmosphere[obj] = {
                Density = obj.Density,
                Offset = obj.Offset,
                Color = obj.Color,
                Decay = obj.Decay,
                Glare = obj.Glare,
                Haze = obj.Haze
            }
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
            pcall(function() obj:Destroy() end)
        end
    end
end

local function RestoreDefaultGraphics()
    CaptureGraphicsBackup()
    RemoveHaimiyachHDEffects()

    if FPSBoostDescendantConnection then
        pcall(function() FPSBoostDescendantConnection:Disconnect() end)
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

    -- Lightweight visual cleanup. Does not hide map parts, characters, UI, or hitboxes.
    SafeSetProperty(Lighting, "GlobalShadows", false)
    SafeSetProperty(Lighting, "Brightness", 1)
    SafeSetProperty(Lighting, "FogStart", 0)
    SafeSetProperty(Lighting, "FogEnd", 100000)
    SafeSetProperty(Lighting, "ExposureCompensation", 0)
    SafeSetProperty(Lighting, "EnvironmentDiffuseScale", 0)
    SafeSetProperty(Lighting, "EnvironmentSpecularScale", 0)
    SafeSetProperty(Lighting, "ShadowSoftness", 0)
    pcall(function() Lighting.Technology = Enum.Technology.Voxel end)
    pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)

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

    -- Disable only non-essential client visual effects to reduce FPS spikes.
    -- Character parts, decals, highlights, hitboxes, camera, and GUI are not touched.
    for _, obj in ipairs(Workspace:GetDescendants()) do
        DisableClientVisualEffect(obj)
    end

    if FPSBoostDescendantConnection then
        pcall(function() FPSBoostDescendantConnection:Disconnect() end)
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

local function ApplyHighHDGraphics()
    CaptureGraphicsBackup()
    RemoveHaimiyachHDEffects()
    FPSBoostActive = false
    HighGraphicsActive = true
    GraphicsMode = "High Graphics"

    if FPSBoostDescendantConnection then
        pcall(function() FPSBoostDescendantConnection:Disconnect() end)
        FPSBoostDescendantConnection = nil
    end

    -- Restore every visual item that FPS Boost may have reduced before enabling HD visuals.
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
        -- Important: FPS Boost disables Terrain.Decoration. High Graphics must turn it back on,
        -- otherwise grass/terrain decoration stays missing.
        SafeSetProperty(terrain, "Decoration", true)
        SafeSetProperty(terrain, "WaterReflectance", 0.35)
        SafeSetProperty(terrain, "WaterTransparency", 0.25)
        SafeSetProperty(terrain, "WaterWaveSize", 0.12)
        SafeSetProperty(terrain, "WaterWaveSpeed", 8)
    end

    -- Re-enable character shadows locally so avatars do not look flat after switching from FPS Boost.
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
        -- ShadowMap is more reliable on mobile for visible avatar/terrain shadows.
        Lighting.Technology = Enum.Technology.ShadowMap
    end)
    pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel10 end)

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

local function SetFPSBoostEnabled(state)
    if state then
        ApplyFPSBoostGraphics()
    else
        if FPSBoostActive then
            RestoreDefaultGraphics()
        end
    end
end

local function SetHighGraphicsEnabled(state)
    if state then
        ApplyHighHDGraphics()
    else
        if HighGraphicsActive then
            RestoreDefaultGraphics()
        end
    end
end

local function SetGraphicsMode(mode)
    mode = tostring(mode or "Default")

    if mode == "FPS Boost" or mode == "Low Graphics" then
        SetFPSBoostEnabled(true)
    elseif mode == "High HD" or mode == "High Graphics" then
        SetHighGraphicsEnabled(true)
    else
        RestoreDefaultGraphics()
    end
end

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

-- =========================================================
-- HAIMIYACH HUB CUSTOM UI
-- Custom interface inspired by modern hub layouts. No third-party UI library is loaded.
-- The original feature logic above remains as the backend.
-- =========================================================
task.spawn(function()
    pcall(function()
        if MainFrame then MainFrame.Visible = false end
        if OpenButton then OpenButton.Visible = false end
    end)

    local containers = {}
    if CoreGui then table.insert(containers, CoreGui) end
    if PlayerGui then table.insert(containers, PlayerGui) end

    for _, container in ipairs(containers) do
        pcall(function()
            local oldCustom = container:FindFirstChild("Haimiyach_Hub_Custom_UI")
            if oldCustom then oldCustom:Destroy() end
            local oldToggle = container:FindFirstChild("Haimiyach_Hub_Show_Button")
            if oldToggle then oldToggle:Destroy() end
        end)
    end

    local UIParent = CoreGui or PlayerGui
    if not UIParent then return end

    local CustomGui = Instance.new("ScreenGui")
    CustomGui.Name = "Haimiyach_Hub_Custom_UI"
    CustomGui.ResetOnSpawn = false
    CustomGui.IgnoreGuiInset = true
    CustomGui.DisplayOrder = 999995
    local parentOk = pcall(function() CustomGui.Parent = UIParent end)
    if not parentOk and PlayerGui then
        pcall(function() CustomGui.Parent = PlayerGui end)
    end
    if not CustomGui.Parent then return end

    local UIScaleValue = UserInputService.TouchEnabled and 0.82 or 1
    local SelectedTab = nil
    local Pages = {}
    local TabButtons = {}
    local ToggleRefreshers = {}
    local ValueRefreshers = {}
    local TargetRows = {}
    local ThemeButtons = {}
    local DashboardTextLabel = nil
    local DashboardStateLabel = nil
    local TargetCountLabel = nil
    local ModeLabel = nil
    local MovementSpeedLabel = nil
    local AimbotValueLabel = nil
    local Main = nil
    local ShowUIButton = nil
    local ShowUIStroke = nil
    local MinimizeHub = nil
    local CloseHub = nil
    local IsMinimized = false
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
    local ActivePopup = nil
    local FPSDashboardGui = nil
    local FPSDashboard = nil
    local FPSDashboardFpsLabel = nil
    local FPSDashboardPingLabel = nil
    local FPSDashboardToggle = nil
    local VisualsFpsValueLabel = nil
    local VisualsPingValueLabel = nil
    local RealFPSValue = 0

    -- Show button is locked to the top so it cannot be dragged off-screen.
    -- The button stays transparent but remains clickable in the same position.
    local ShowButtonWidth = UserInputService.TouchEnabled and 148 or 168
    local ShowButtonHeight = UserInputService.TouchEnabled and 32 or 34
    local ShowButtonTopOffset = UserInputService.TouchEnabled and 10 or 14
    local ShowButtonBgTransparency = 0.88
    local ShowButtonTextTransparency = 0.32

    local function GetSafeViewportSize()
        local cam = workspace.CurrentCamera
        if cam and cam.ViewportSize then
            return cam.ViewportSize
        end
        return Vector2.new(1280, 720)
    end

    local function ClampGuiToViewport(guiObject, margin)
        if not guiObject or not guiObject.Parent then return end
        margin = margin or 8

        local viewport = GetSafeViewportSize()
        local absSize = guiObject.AbsoluteSize
        local absPos = guiObject.AbsolutePosition

        if absSize.X <= 2 or absSize.Y <= 2 then
            return
        end

        local minX = margin
        local minY = margin
        local maxX = math.max(minX, viewport.X - absSize.X - margin)
        local maxY = math.max(minY, viewport.Y - absSize.Y - margin)

        local newX = math.clamp(absPos.X, minX, maxX)
        local newY = math.clamp(absPos.Y, minY, maxY)

        guiObject.Position = UDim2.fromOffset(math.floor(newX + 0.5), math.floor(newY + 0.5))
    end

    local function LockShowButtonTop()
        if not ShowUIButton then return end
        ShowUIButton.AnchorPoint = Vector2.new(0.5, 0)
        ShowUIButton.Size = UDim2.new(0, ShowButtonWidth, 0, ShowButtonHeight)
        ShowUIButton.Position = UDim2.new(0.5, 0, 0, ShowButtonTopOffset)
        ShowUIButton.BackgroundTransparency = ShowButtonBgTransparency
        ShowUIButton.TextTransparency = ShowButtonTextTransparency
        ShowUIButton.AutoButtonColor = false
        ShowUIButton.Active = true
    end

    local function EnsureMainOnScreen()
        task.defer(function()
            ClampGuiToViewport(Main, 10)
        end)
    end

    local function IsMobileDevice()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    local function DeviceText()
        return UserInputService.TouchEnabled and "Mobile" or "PC"
    end

    local function Theme()
        return GetTheme()
    end

    local function ThemeColor(kind)
        local t = Theme()
        if kind == "Background" then return t.Background end
        if kind == "Top" then return t.Top end
        if kind == "Sidebar" then return t.Panel end
        if kind == "Panel" then return t.Panel end
        if kind == "Panel2" then return t.Panel2 end
        if kind == "Entry" then return t.Entry end
        if kind == "Button" then return t.Button end
        if kind == "ButtonActive" then return t.Button2 end
        if kind == "Accent" then return t.Accent end
        if kind == "Accent2" then return t.Accent2 end
        if kind == "Text" then return t.Text end
        if kind == "Muted" then return t.Muted end
        return t.Text
    end

    local function MarkBg(obj, kind)
        if obj and obj.SetAttribute then
            obj:SetAttribute("HaimiyachBgKind", kind)
        end
        if obj and obj:IsA("GuiObject") then
            obj.BackgroundColor3 = ThemeColor(kind)
        end
        return obj
    end

    local function MarkText(obj, kind)
        if obj and obj.SetAttribute then
            obj:SetAttribute("HaimiyachTextKind", kind)
        end
        if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
            obj.TextColor3 = ThemeColor(kind)
        end
        return obj
    end

    local function MarkStroke(obj, kind)
        if obj and obj.SetAttribute then
            obj:SetAttribute("HaimiyachStrokeKind", kind)
        end
        if obj and obj:IsA("UIStroke") then
            obj.Color = ThemeColor(kind)
        end
        return obj
    end

    local function AddCorner(obj, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius or 10)
        corner.Parent = obj
        return corner
    end

    local function AddStroke(obj, kind, thickness, transparency)
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = thickness or 1
        stroke.Transparency = transparency or 0
        stroke.Parent = obj
        MarkStroke(stroke, kind or "Accent")
        return stroke
    end

    local function RepaintCustomUI()
        for _, obj in ipairs(CustomGui:GetDescendants()) do
            local bgKind = obj:GetAttribute("HaimiyachBgKind")
            if bgKind and obj:IsA("GuiObject") then
                obj.BackgroundColor3 = ThemeColor(bgKind)
            end
            local textKind = obj:GetAttribute("HaimiyachTextKind")
            if textKind and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
                obj.TextColor3 = ThemeColor(textKind)
            end
            local strokeKind = obj:GetAttribute("HaimiyachStrokeKind")
            if strokeKind and obj:IsA("UIStroke") then
                obj.Color = ThemeColor(strokeKind)
            end
            if obj:IsA("ScrollingFrame") then
                obj.ScrollBarImageColor3 = ThemeColor("Accent")
            end
        end
        if ShowUIButton then
            ShowUIButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            ShowUIButton.TextColor3 = Color3.fromRGB(235, 235, 235)
            LockShowButtonTop()
        end
        if MinimizeHub then
            MarkText(MinimizeHub, "Muted")
        end
        if CloseHub then
            MarkText(CloseHub, "Muted")
        end
        for themeName, btn in pairs(ThemeButtons) do
            if btn then
                MarkBg(btn, themeName == CurrentThemeName and "ButtonActive" or "Button")
            end
        end
        for name, btn in pairs(TabButtons) do
            if btn then
                local active = name == SelectedTab
                MarkBg(btn, active and "ButtonActive" or "Button")
                if active and CurrentThemeName == "DARK" then
                    btn.TextColor3 = Color3.fromRGB(25, 25, 25)
                else
                    MarkText(btn, "Text")
                end
            end
        end
    end


    local function MakeDraggable(dragHandle, targetFrame, moveThreshold, clampToScreen)
        if not dragHandle or not targetFrame then return function() return false end end

        dragHandle.Active = true
        moveThreshold = moveThreshold or 4
        clampToScreen = clampToScreen == true

        local dragging = false
        local moved = false
        local dragStart = nil
        local startPos = nil
        local activeInput = nil

        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                moved = false
                activeInput = input
                dragStart = input.Position
                startPos = targetFrame.Position
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and activeInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if math.abs(delta.X) > moveThreshold or math.abs(delta.Y) > moveThreshold then
                    moved = true
                end
                targetFrame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
                if clampToScreen then
                    ClampGuiToViewport(targetFrame, 8)
                end
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if activeInput and (input == activeInput or input.UserInputType == activeInput.UserInputType) then
                dragging = false
                activeInput = nil
                if clampToScreen then
                    ClampGuiToViewport(targetFrame, 8)
                end
            end
        end)

        return function()
            return moved
        end
    end

    Main = Instance.new("Frame")
    Main.Name = "MainWindow"
    Main.Size = UDim2.new(0, 600, 0, 350)
    Main.Position = UDim2.new(0.5, -300, 0.5, -175)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.ClipsDescendants = true
    Main.Parent = CustomGui
    MarkBg(Main, "Background")
    local MainCorner = AddCorner(Main, 14)
    AddStroke(Main, "Accent", 1.6, 0.18)

    local UIScaleObj = Instance.new("UIScale")
    UIScaleObj.Name = "HaimiyachHubUIScale"
    UIScaleObj.Scale = UIScaleValue
    UIScaleObj.Parent = Main

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 48)
    TopBar.BackgroundTransparency = 0
    TopBar.BorderSizePixel = 0
    TopBar.ClipsDescendants = true
    TopBar.Parent = Main
    MarkBg(TopBar, "Top")
    local TopBarCorner = AddCorner(TopBar, 14)

    local TopCover = Instance.new("Frame")
    TopCover.Size = UDim2.new(1, 0, 0, 14)
    TopCover.Position = UDim2.new(0, 0, 1, -14)
    TopCover.BorderSizePixel = 0
    TopCover.Parent = TopBar
    MarkBg(TopCover, "Top")

    local Watermark = Instance.new("TextLabel")
    Watermark.Name = "Watermark"
    Watermark.Size = UDim2.new(0, 245, 1, 0)
    Watermark.Position = UDim2.new(0, 18, 0, 0)
    Watermark.BackgroundTransparency = 1
    Watermark.Text = "HAIMIYACH HUB"
    Watermark.Font = Enum.Font.GothamBlack
    Watermark.TextSize = 19
    Watermark.TextXAlignment = Enum.TextXAlignment.Left
    Watermark.Parent = TopBar
    MarkText(Watermark, "Text")

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Name = "Subtitle"
    SubTitle.Size = UDim2.new(0, 245, 0, 18)
    SubTitle.Position = UDim2.new(0, 18, 0, 28)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = ""
    SubTitle.Font = Enum.Font.Gotham
    SubTitle.TextSize = 10
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.Parent = TopBar
    SubTitle.Visible = false
    MarkText(SubTitle, "Muted")

    MinimizeHub = Instance.new("TextButton")
    MinimizeHub.Name = "MinimizeHub"
    MinimizeHub.Size = UDim2.new(0, 30, 0, 30)
    MinimizeHub.Position = UDim2.new(1, -74, 0, 9)
    MinimizeHub.BorderSizePixel = 0
    MinimizeHub.BackgroundTransparency = 1
    MinimizeHub.Text = "-"
    MinimizeHub.Font = Enum.Font.GothamBold
    MinimizeHub.TextSize = 18
    MinimizeHub.TextXAlignment = Enum.TextXAlignment.Center
    MinimizeHub.TextYAlignment = Enum.TextYAlignment.Center
    MinimizeHub.AutoButtonColor = false
    MinimizeHub.Parent = TopBar
    MarkText(MinimizeHub, "Muted")

    CloseHub = Instance.new("TextButton")
    CloseHub.Name = "CloseHub"
    CloseHub.Size = UDim2.new(0, 30, 0, 30)
    CloseHub.Position = UDim2.new(1, -40, 0, 9)
    CloseHub.BorderSizePixel = 0
    CloseHub.BackgroundTransparency = 1
    CloseHub.Text = "X"
    CloseHub.Font = Enum.Font.GothamBold
    CloseHub.TextSize = 18
    CloseHub.TextXAlignment = Enum.TextXAlignment.Center
    CloseHub.TextYAlignment = Enum.TextYAlignment.Center
    CloseHub.AutoButtonColor = false
    CloseHub.Parent = TopBar
    MarkText(CloseHub, "Muted")

    local TabBar = Instance.new("ScrollingFrame")
    TabBar.Name = "TopTabBar"
    TabBar.Size = UDim2.new(1, -24, 0, 46)
    TabBar.Position = UDim2.new(0, 12, 0, 56)
    TabBar.BackgroundTransparency = 0
    TabBar.BorderSizePixel = 0
    TabBar.ScrollBarThickness = 0
    TabBar.ScrollBarImageTransparency = 1
    TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    TabBar.ClipsDescendants = true
    TabBar.Parent = Main
    MarkBg(TabBar, "Panel")
    AddCorner(TabBar, 12)
    AddStroke(TabBar, "Accent", 1, 0.72)

    local TabList = Instance.new("UIListLayout")
    TabList.Padding = UDim.new(0, 8)
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.FillDirection = Enum.FillDirection.Horizontal
    TabList.VerticalAlignment = Enum.VerticalAlignment.Center
    TabList.Parent = TabBar

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingLeft = UDim.new(0, 8)
    TabPadding.PaddingRight = UDim.new(0, 8)
    TabPadding.PaddingTop = UDim.new(0, 6)
    TabPadding.PaddingBottom = UDim.new(0, 6)
    TabPadding.Parent = TabBar

    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, -24, 1, -116)
    Content.Position = UDim2.new(0, 12, 0, 108)
    Content.BorderSizePixel = 0
    Content.ClipsDescendants = true
    Content.Parent = Main
    MarkBg(Content, "Panel")
    AddCorner(Content, 12)
    AddStroke(Content, "Accent", 1, 0.74)

    local ContentPadding = Instance.new("UIPadding")
    ContentPadding.PaddingLeft = UDim.new(0, 10)
    ContentPadding.PaddingRight = UDim.new(0, 10)
    ContentPadding.PaddingTop = UDim.new(0, 10)
    ContentPadding.PaddingBottom = UDim.new(0, 10)
    ContentPadding.Parent = Content

    local function UpdateDashboard()
        if DashboardTextLabel then
            DashboardTextLabel.Text = table.concat({
                "Status: Loaded",
                "Device: " .. DeviceText(),
                "Selected Targets: " .. tostring(CountSelectedTargets()),
                "Current Fling Mode: " .. tostring(FlingMode),
                "UI Theme: " .. tostring(CurrentThemeName),
                "UI Scale: " .. tostring(math.floor((UIScaleValue or 1) * 100 + 0.5)) .. "%"
            }, "\n")
        end
        if DashboardStateLabel then
            DashboardStateLabel.Text = table.concat({
                "Touch Fling: " .. (TouchFlingActive and "Enabled" or "Disabled"),
                "Anti Fling: " .. (AntiFlingActive and "Enabled" or "Disabled"),
                "Fly: " .. (FlyActive and "Enabled" or "Disabled"),
                "Noclip: " .. (NoclipActive and "Enabled" or "Disabled"),
                "Anti Knockback: " .. (AntiKnockbackActive and "Enabled" or "Disabled"),
                "Aimbot: " .. (AimbotData.Enabled and "Enabled" or "Disabled"),
                "Aimbot ESP: " .. (AimbotData.ESP and "Enabled" or "Disabled")
            }, "\n")
        end
        if TargetCountLabel then
            TargetCountLabel.Text = tostring(CountSelectedTargets()) .. " selected target(s)"
        end
        if ModeLabel then
            ModeLabel.Text = "Current Mode: " .. tostring(FlingMode)
        end
        if MovementSpeedLabel then
            MovementSpeedLabel.Text = "Fly Speed: " .. tostring(FlySpeed) .. "  |  Move Speed: " .. tostring(MoveSpeed)
        end
        if AimbotValueLabel then
            AimbotValueLabel.Text = "FOV: " .. tostring(AimbotData.FOV) .. "  |  Smoothness: " .. tostring(AimbotData.Smoothness) .. "  |  Sensitivity: " .. tostring(AimbotData.Sensitivity)
        end
    end

    local function RefreshAllControls()
        for _, refresh in ipairs(ToggleRefreshers) do
            pcall(refresh)
        end
        for _, refresh in ipairs(ValueRefreshers) do
            pcall(refresh)
        end
        UpdateDashboard()
    end

    local function SelectTab(tabName)
        SelectedTab = tabName
        for name, page in pairs(Pages) do
            page.Visible = (name == tabName)
        end
        for name, btn in pairs(TabButtons) do
            local active = name == tabName
            MarkBg(btn, active and "ButtonActive" or "Button")
            if active and CurrentThemeName == "DARK" then
                btn.TextColor3 = Color3.fromRGB(25, 25, 25)
            else
                MarkText(btn, "Text")
            end
        end
        RefreshAllControls()
    end

    local function CreateTab(tabName)
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. tabName
        local TabWidths = {
            ["FLING"] = 104,
            ["FE EMOTE"] = 118,
            ["MOVEMENT"] = 128,
            ["VISUALS"] = 108,
            ["UTILITY"] = 108,
            ["AIMBOT"] = 106,
            ["SETTINGS"] = 120,
            ["CREDITS"] = 110
        }
        local tabWidth = TabWidths[tabName] or math.clamp((#tabName * 8) + 58, 96, 136)
        local TabOrders = {
            ["AIMBOT"] = 1,
            ["FLING"] = 2,
            ["FE EMOTE"] = 3,
            ["MOVEMENT"] = 4,
            ["VISUALS"] = 5,
            ["UTILITY"] = 6,
            ["SETTINGS"] = 7,
            ["CREDITS"] = 8
        }
        btn.LayoutOrder = TabOrders[tabName] or 99
        btn.Size = UDim2.new(0, tabWidth, 0, 34)
        btn.BorderSizePixel = 0
        btn.Text = tabName
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = true
        btn.Parent = TabBar
        MarkBg(btn, "Button")
        MarkText(btn, "Text")
        AddCorner(btn, 17)
        AddStroke(btn, "Accent", 1, 0.82)
        TabButtons[tabName] = btn

        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. tabName
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = UserInputService.TouchEnabled and 5 or 6
        page.ScrollBarImageColor3 = ThemeColor("Accent")
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.Parent = Content
        Pages[tabName] = page

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 7)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = page

        local pad = Instance.new("UIPadding")
        -- Small inner padding prevents card strokes/backgrounds from being clipped on the left edge.
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 10)
        pad.PaddingTop = UDim.new(0, 2)
        pad.PaddingBottom = UDim.new(0, 10)
        pad.Parent = page

        btn.Activated:Connect(function()
            SelectTab(tabName)
        end)

        return page
    end

    local function ClosePopup()
        if ActivePopup then
            pcall(function() ActivePopup:Destroy() end)
            ActivePopup = nil
        end
    end

    local function SetHubVisible(state)
        Main.Visible = state and true or false
        if Main.Visible then
            EnsureMainOnScreen()
        else
            ClosePopup()
        end
        if ShowUIButton then
            ShowUIButton.Visible = not Main.Visible
            ShowUIButton.Text = "HAIMIYACH HUB"
            LockShowButtonTop()
        end
    end

    local function SetHubMinimized(state)
        IsMinimized = state and true or false
        if IsMinimized then
            ClosePopup()
        end

        TabBar.Visible = not IsMinimized
        Content.Visible = not IsMinimized

        if IsMinimized then
            -- Rounded minimized bar, matching the main UI shape.
            Main.Size = UDim2.new(0, 520, 0, 54)
            MainCorner.CornerRadius = UDim.new(0, 14)
            TopBar.Position = UDim2.new(0, 0, 0, 0)
            TopBar.Size = UDim2.new(1, 0, 1, 0)
            TopBarCorner.CornerRadius = UDim.new(0, 14)
            TopCover.Visible = false
        else
            Main.Size = UDim2.new(0, 600, 0, 350)
            MainCorner.CornerRadius = UDim.new(0, 14)
            TopBar.Position = UDim2.new(0, 0, 0, 0)
            TopBar.Size = UDim2.new(1, 0, 0, 48)
            TopBarCorner.CornerRadius = UDim.new(0, 14)
            TopCover.Visible = true
        end

        if MinimizeHub then
            MinimizeHub.Text = IsMinimized and "+" or "-"
            MinimizeHub.TextSize = 18
        end
        if CloseHub then
            CloseHub.TextSize = 18
        end
        EnsureMainOnScreen()
    end

    local function ToggleHubVisible()
        SetHubVisible(not Main.Visible)
    end

    local function OpenPopup(title, width, height)
        ClosePopup()

        local overlay = Instance.new("Frame")
        overlay.Name = "PopupOverlay"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.BackgroundTransparency = 0.35
        overlay.BorderSizePixel = 0
        overlay.Active = true
        overlay.Parent = CustomGui
        ActivePopup = overlay

        local popup = Instance.new("Frame")
        popup.Name = "PopupWindow"
        popup.Size = UDim2.new(0, width or 500, 0, height or 350)
        popup.Position = UDim2.new(0.5, -((width or 500) / 2), 0.5, -((height or 350) / 2))
        popup.BorderSizePixel = 0
        popup.Active = true
        popup.Parent = overlay
        MarkBg(popup, "Panel")
        AddCorner(popup, 14)
        AddStroke(popup, "Accent", 1.4, 0.38)

        local popupTop = Instance.new("Frame")
        popupTop.Size = UDim2.new(1, 0, 0, 44)
        popupTop.BorderSizePixel = 0
        popupTop.Parent = popup
        MarkBg(popupTop, "Top")
        AddCorner(popupTop, 14)

        local cover = Instance.new("Frame")
        cover.Size = UDim2.new(1, 0, 0, 14)
        cover.Position = UDim2.new(0, 0, 1, -14)
        cover.BorderSizePixel = 0
        cover.Parent = popupTop
        MarkBg(cover, "Top")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -80, 1, 0)
        titleLabel.Position = UDim2.new(0, 14, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title or "POPUP"
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.TextSize = 15
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = popupTop
        MarkText(titleLabel, "Text")

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 54, 0, 28)
        close.Position = UDim2.new(1, -64, 0.5, -14)
        close.BorderSizePixel = 0
        close.Text = "CLOSE"
        close.Font = Enum.Font.GothamBlack
        close.TextSize = 10
        close.Parent = popupTop
        MarkBg(close, "Button")
        MarkText(close, "Text")
        AddCorner(close, 8)
        close.Activated:Connect(ClosePopup)

        -- Popup can be moved by dragging its title bar.
        MakeDraggable(popupTop, popup, 4, true)

        local body = Instance.new("ScrollingFrame")
        body.Name = "PopupBody"
        body.Size = UDim2.new(1, -24, 1, -60)
        body.Position = UDim2.new(0, 12, 0, 52)
        body.BackgroundTransparency = 1
        body.BorderSizePixel = 0
        body.ScrollBarThickness = UserInputService.TouchEnabled and 5 or 6
        body.ScrollBarImageColor3 = ThemeColor("Accent")
        body.AutomaticCanvasSize = Enum.AutomaticSize.Y
        body.CanvasSize = UDim2.new(0, 0, 0, 0)
        body.Parent = popup

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = body

        local padding = Instance.new("UIPadding")
        padding.PaddingRight = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.Parent = body

        RepaintCustomUI()
        return body, overlay
    end

    local function Section(parent, text)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 26)
        label.BackgroundTransparency = 1
        label.Text = text
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = parent
        MarkText(label, "Accent")
        return label
    end

    local function Paragraph(parent, title, text, height)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, height or 100)
        frame.BorderSizePixel = 0
        frame.Parent = parent
        MarkBg(frame, "Panel2")
        AddCorner(frame, 10)
        AddStroke(frame, "Accent", 1, 0.82)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -18, 0, 24)
        titleLabel.Position = UDim2.new(0, 9, 0, 7)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.TextSize = 12
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = frame
        MarkText(titleLabel, "Text")

        local contentLabel = Instance.new("TextLabel")
        contentLabel.Size = UDim2.new(1, -18, 1, -36)
        contentLabel.Position = UDim2.new(0, 9, 0, 31)
        contentLabel.BackgroundTransparency = 1
        contentLabel.Text = text or ""
        contentLabel.Font = Enum.Font.Gotham
        contentLabel.TextSize = 12
        contentLabel.TextWrapped = true
        contentLabel.TextXAlignment = Enum.TextXAlignment.Left
        contentLabel.TextYAlignment = Enum.TextYAlignment.Top
        contentLabel.Parent = frame
        MarkText(contentLabel, "Muted")
        return contentLabel, frame
    end

    local function Button(parent, text, callback, height)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, height or 38)
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.TextWrapped = true
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = true
        btn.Parent = parent
        MarkBg(btn, "Panel2")
        MarkText(btn, "Text")
        AddCorner(btn, 10)
        AddStroke(btn, "Accent", 1, 0.84)

        local btnPad = Instance.new("UIPadding")
        btnPad.PaddingLeft = UDim.new(0, 14)
        btnPad.PaddingRight = UDim.new(0, 78)
        btnPad.Parent = btn

        local rightHint = Instance.new("TextLabel")
        rightHint.Name = "RightHint"
        rightHint.Size = UDim2.new(0, 66, 1, 0)
        rightHint.Position = UDim2.new(1, -76, 0, 0)
        rightHint.BackgroundTransparency = 1
        rightHint.Text = "button"
        rightHint.Font = Enum.Font.Gotham
        rightHint.TextSize = 12
        rightHint.TextXAlignment = Enum.TextXAlignment.Right
        rightHint.Parent = btn
        MarkText(rightHint, "Muted")
        local busy = false
        btn.Activated:Connect(function()
            if busy then return end
            busy = true
            pcall(function()
                if callback then callback() end
            end)
            task.delay(0.18, function() busy = false end)
        end)
        return btn
    end

    local function Toggle(parent, labelText, getState, setState)
        local row = Instance.new("TextButton")
        row.Name = "Toggle_" .. tostring(labelText)
        row.Size = UDim2.new(1, 0, 0, 40)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Active = true
        row.Parent = parent
        MarkBg(row, "Panel2")
        AddCorner(row, 10)
        AddStroke(row, "Accent", 1, 0.86)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -86, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row
        MarkText(label, "Text")

        local switch = Instance.new("Frame")
        switch.Name = "Switch"
        switch.Size = UDim2.new(0, 58, 0, 24)
        switch.Position = UDim2.new(1, -70, 0.5, -12)
        switch.BorderSizePixel = 0
        switch.Parent = row
        MarkBg(switch, "Entry")
        AddCorner(switch, 12)
        AddStroke(switch, "Accent", 1, 0.58)

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.Position = UDim2.new(0, 2, 0.5, -10)
        knob.BorderSizePixel = 0
        knob.Parent = switch
        knob.BackgroundColor3 = Color3.fromRGB(235, 240, 255)
        AddCorner(knob, 10)

        local function refresh()
            local active = false
            pcall(function() active = getState() and true or false end)

            switch.BackgroundColor3 = active and Color3.fromRGB(44, 44, 44) or Color3.fromRGB(31, 31, 31)
            knob.BackgroundColor3 = active and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(115, 115, 115)

            local targetPos = active and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            pcall(function()
                TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
            end)
            knob.Position = targetPos
        end

        row.Activated:Connect(function()
            local active = false
            pcall(function() active = getState() and true or false end)
            pcall(function() setState(not active) end)
            task.wait()
            refresh()
            UpdateDashboard()
        end)

        table.insert(ToggleRefreshers, refresh)
        refresh()
        return row
    end

    local function Adjuster(parent, labelText, getValue, setValue, minusStep, plusStep, minValue, maxValue, decimals)
        local row = Instance.new("Frame")
        row.Name = "Slider_" .. tostring(labelText)
        row.Size = UDim2.new(1, 0, 0, 48)
        row.BorderSizePixel = 0
        row.Parent = parent
        MarkBg(row, "Panel2")
        AddCorner(row, 10)
        AddStroke(row, "Accent", 1, 0.86)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.42, -10, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Text = labelText
        label.Parent = row
        MarkText(label, "Text")

        local track = Instance.new("TextButton")
        track.Name = "Track"
        track.Size = UDim2.new(0.52, -14, 0, 24)
        track.Position = UDim2.new(0.46, 0, 0.5, -12)
        track.BorderSizePixel = 0
        track.Text = ""
        track.AutoButtonColor = false
        track.Active = true
        track.Parent = row
        MarkBg(track, "Entry")
        AddCorner(track, 12)
        AddStroke(track, "Accent", 1, 0.52)

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BorderSizePixel = 0
        fill.Parent = track
        MarkBg(fill, "ButtonActive")
        AddCorner(fill, 12)

        local valueBubble = Instance.new("TextLabel")
        valueBubble.Name = "Value"
        valueBubble.Size = UDim2.new(0, 74, 1, 0)
        valueBubble.Position = UDim2.new(0, 0, 0, 0)
        valueBubble.BackgroundTransparency = 0
        valueBubble.BorderSizePixel = 0
        valueBubble.Font = Enum.Font.GothamBold
        valueBubble.TextSize = 13
        valueBubble.TextXAlignment = Enum.TextXAlignment.Center
        valueBubble.Active = true
        valueBubble.Parent = track
        MarkBg(valueBubble, "ButtonActive")
        MarkText(valueBubble, "Text")
        AddCorner(valueBubble, 12)

        local dragging = false
        local activeInput = nil
        local lockedScrollFrame = nil
        local lockedScrollState = nil
        local step = plusStep or minusStep or 1

        local function formatValue(v)
            v = tonumber(v) or 0
            if decimals then
                return string.format("%." .. tostring(decimals) .. "f", v)
            end
            return tostring(math.floor(v + 0.5))
        end

        local function normalizeValue(v)
            local minV = tonumber(minValue) or 0
            local maxV = tonumber(maxValue) or 100
            if maxV <= minV then return minV end

            v = math.clamp(tonumber(v) or minV, minV, maxV)

            if step and step > 0 then
                v = minV + math.floor(((v - minV) / step) + 0.5) * step
            end

            v = math.clamp(v, minV, maxV)

            if decimals then
                v = tonumber(string.format("%." .. tostring(decimals) .. "f", v))
            else
                v = math.floor(v + 0.5)
            end

            return v
        end

        local function refresh()
            local minV = tonumber(minValue) or 0
            local maxV = tonumber(maxValue) or 100
            local v = minV

            pcall(function()
                v = normalizeValue(getValue())
            end)

            local pct = 0
            if maxV > minV then
                pct = math.clamp((v - minV) / (maxV - minV), 0, 1)
            end

            fill.Size = UDim2.new(pct, 0, 1, 0)
            valueBubble.Text = formatValue(v)

            if pct < 0.12 then
                valueBubble.Position = UDim2.new(0, 0, 0, 0)
            elseif pct > 0.88 then
                valueBubble.Position = UDim2.new(1, -74, 0, 0)
            else
                valueBubble.Position = UDim2.new(pct, -37, 0, 0)
            end
        end

        local function findScrollingFrame(obj)
            local current = obj
            while current do
                if current:IsA("ScrollingFrame") then
                    return current
                end
                current = current.Parent
            end
            return nil
        end

        local function lockScroll()
            if lockedScrollFrame then return end
            local scrollFrame = findScrollingFrame(row)
            if scrollFrame then
                lockedScrollFrame = scrollFrame
                lockedScrollState = scrollFrame.ScrollingEnabled
                scrollFrame.ScrollingEnabled = false
            end
        end

        local function unlockScroll()
            if lockedScrollFrame then
                pcall(function()
                    lockedScrollFrame.ScrollingEnabled = lockedScrollState ~= false
                end)
            end
            lockedScrollFrame = nil
            lockedScrollState = nil
        end

        local function setFromX(x)
            local minV = tonumber(minValue) or 0
            local maxV = tonumber(maxValue) or 100
            local pct = 0

            if track.AbsoluteSize.X > 0 then
                pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            end

            local value = normalizeValue(minV + (maxV - minV) * pct)

            pcall(function()
                setValue(value)
            end)

            refresh()
        end

        local function setFromInput(input)
            if not input or not input.Position then return end
            setFromX(input.Position.X)
        end

        local function beginDrag(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end

            dragging = true
            activeInput = input
            lockScroll()
            setFromInput(input)
        end

        local function endDrag(input)
            if not dragging then return end

            local shouldEnd = false
            if input == activeInput then
                shouldEnd = true
            elseif activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1 then
                shouldEnd = true
            elseif activeInput and activeInput.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch then
                shouldEnd = true
            end

            if not shouldEnd then return end

            dragging = false
            activeInput = nil
            unlockScroll()
            refresh()
            UpdateDashboard()
            RefreshAllControls()
        end

        track.InputBegan:Connect(beginDrag)
        fill.InputBegan:Connect(beginDrag)
        valueBubble.InputBegan:Connect(beginDrag)

        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end

            if input.UserInputType == Enum.UserInputType.MouseMovement then
                setFromInput(input)
                return
            end

            if input.UserInputType == Enum.UserInputType.Touch then
                if not activeInput or activeInput.UserInputType == Enum.UserInputType.Touch then
                    setFromInput(input)
                end
            end
        end)

        UserInputService.InputEnded:Connect(endDrag)

        table.insert(ValueRefreshers, refresh)
        refresh()
        return row
    end


    local function ValueDropdown(parent, labelText, getValue, callback)
        local row = Instance.new("TextButton")
        row.Name = "Dropdown_" .. tostring(labelText)
        row.Size = UDim2.new(1, 0, 0, 44)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Active = true
        row.Parent = parent
        MarkBg(row, "Panel2")
        AddCorner(row, 10)
        AddStroke(row, "Accent", 1, 0.84)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.52, -18, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row
        MarkText(label, "Text")

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "Value"
        valueLabel.Size = UDim2.new(0.36, -18, 1, 0)
        valueLabel.Position = UDim2.new(0.56, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = ""
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 13
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
        valueLabel.Parent = row
        MarkText(valueLabel, "Muted")

        local chevron = Instance.new("TextLabel")
        chevron.Name = "Chevron"
        chevron.Size = UDim2.new(0, 30, 1, 0)
        chevron.Position = UDim2.new(1, -42, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "v"
        chevron.Font = Enum.Font.GothamBold
        chevron.TextSize = 20
        chevron.TextXAlignment = Enum.TextXAlignment.Center
        chevron.Parent = row
        MarkText(chevron, "Muted")

        local function refresh()
            local ok, value = pcall(getValue)
            valueLabel.Text = ok and tostring(value or "") or ""
        end

        row.Activated:Connect(function()
            if callback then
                pcall(callback)
            end
            refresh()
            RefreshAllControls()
        end)

        table.insert(ValueRefreshers, refresh)
        refresh()
        return row, valueLabel, chevron
    end


    local function OptionDropdown(parent, labelText, getValue, options, onSelect)
        local open = false
        local optionRows = {}

        local row = Instance.new("TextButton")
        row.Name = "Dropdown_" .. tostring(labelText)
        row.Size = UDim2.new(1, 0, 0, 44)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Active = true
        row.Parent = parent
        MarkBg(row, "Panel2")
        AddCorner(row, 10)
        AddStroke(row, "Accent", 1, 0.84)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.52, -18, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row
        MarkText(label, "Text")

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "Value"
        valueLabel.Size = UDim2.new(0.36, -18, 1, 0)
        valueLabel.Position = UDim2.new(0.56, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = ""
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 13
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
        valueLabel.Parent = row
        MarkText(valueLabel, "Muted")

        local chevron = Instance.new("TextLabel")
        chevron.Name = "Chevron"
        chevron.Size = UDim2.new(0, 28, 1, 0)
        chevron.Position = UDim2.new(1, -38, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "v"
        chevron.Font = Enum.Font.GothamBold
        chevron.TextSize = 12
        chevron.TextXAlignment = Enum.TextXAlignment.Center
        chevron.Parent = row
        MarkText(chevron, "Accent")

        local listFrame = Instance.new("Frame")
        listFrame.Name = "DropdownList_" .. tostring(labelText)
        listFrame.Size = UDim2.new(1, 0, 0, 0)
        listFrame.Visible = false
        listFrame.ClipsDescendants = true
        listFrame.BorderSizePixel = 0
        listFrame.Parent = parent
        MarkBg(listFrame, "Entry")
        AddCorner(listFrame, 10)
        AddStroke(listFrame, "Accent", 1, 0.86)

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 6)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = listFrame

        local listPadding = Instance.new("UIPadding")
        listPadding.PaddingLeft = UDim.new(0, 8)
        listPadding.PaddingRight = UDim.new(0, 8)
        listPadding.PaddingTop = UDim.new(0, 8)
        listPadding.PaddingBottom = UDim.new(0, 8)
        listPadding.Parent = listFrame

        local function getOptions()
            if typeof(options) == "function" then
                local ok, result = pcall(options)
                if ok and type(result) == "table" then return result end
                return {}
            end
            return options or {}
        end

        local function currentValue()
            local ok, value = pcall(getValue)
            return ok and tostring(value or "") or ""
        end

        local function refreshValue()
            valueLabel.Text = currentValue()
            chevron.Text = open and "^" or "v"
        end

        local function clearOptionRows()
            for _, child in ipairs(optionRows) do
                pcall(function() child:Destroy() end)
            end
            optionRows = {}
        end

        local function buildOptions()
            clearOptionRows()
            local opts = getOptions()
            local current = currentValue()
            local count = 0
            for _, opt in ipairs(opts) do
                local name = tostring(type(opt) == "table" and (opt.Name or opt.Value or opt[1]) or opt)
                local value = (type(opt) == "table" and (opt.Value or opt.Key or opt.Name or opt[1])) or opt
                local item = Instance.new("TextButton")
                item.Name = "Option_" .. name
                item.Size = UDim2.new(1, 0, 0, 34)
                item.BorderSizePixel = 0
                item.Text = "  " .. name
                item.Font = Enum.Font.GothamBold
                item.TextSize = 12
                item.TextXAlignment = Enum.TextXAlignment.Left
                item.TextTruncate = Enum.TextTruncate.AtEnd
                item.AutoButtonColor = true
                item.Parent = listFrame
                AddCorner(item, 8)
                AddStroke(item, "Accent", 1, 0.9)
                table.insert(optionRows, item)
                count = count + 1

                local selected = name == current
                if selected and CurrentThemeName == "DARK" then
                    item.BackgroundColor3 = ThemeColor("ButtonActive")
                    item.TextColor3 = Color3.fromRGB(25, 25, 25)
                else
                    MarkBg(item, selected and "ButtonActive" or "Panel2")
                    MarkText(item, "Text")
                end

                item.Activated:Connect(function()
                    if onSelect then
                        pcall(function() onSelect(value, name) end)
                    end
                    open = false
                    listFrame.Visible = false
                    listFrame.Size = UDim2.new(1, 0, 0, 0)
                    refreshValue()
                    buildOptions()
                    RefreshAllControls()
                end)
            end

            local visibleCount = math.min(count, 5)
            listFrame.Size = UDim2.new(1, 0, 0, open and (visibleCount * 40 + 16) or 0)
        end

        local function setOpen(state)
            open = state and true or false
            listFrame.Visible = open
            refreshValue()
            buildOptions()
        end

        row.Activated:Connect(function()
            setOpen(not open)
        end)

        table.insert(ValueRefreshers, function()
            refreshValue()
            if open then buildOptions() end
        end)

        refreshValue()
        return row, listFrame
    end


    local function SearchDropdown(parent, labelText, getValue, getOptions, onSelect)
        local open = false
        local query = ""
        local optionRows = {}

        local row = Instance.new("TextButton")
        row.Name = "SearchDropdown_" .. tostring(labelText)
        row.Size = UDim2.new(1, 0, 0, 44)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Active = true
        row.Parent = parent
        MarkBg(row, "Panel2")
        AddCorner(row, 10)
        AddStroke(row, "Accent", 1, 0.84)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.46, -14, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row
        MarkText(label, "Text")

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "Value"
        valueLabel.Size = UDim2.new(0.42, -24, 1, 0)
        valueLabel.Position = UDim2.new(0.50, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = ""
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 12
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
        valueLabel.Parent = row
        MarkText(valueLabel, "Muted")

        local chevron = Instance.new("TextLabel")
        chevron.Name = "Chevron"
        chevron.Size = UDim2.new(0, 28, 1, 0)
        chevron.Position = UDim2.new(1, -38, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "v"
        chevron.Font = Enum.Font.GothamBold
        chevron.TextSize = 12
        chevron.TextXAlignment = Enum.TextXAlignment.Center
        chevron.Parent = row
        MarkText(chevron, "Accent")

        local dropdown = Instance.new("Frame")
        dropdown.Name = "SearchDropdownList_" .. tostring(labelText)
        dropdown.Size = UDim2.new(1, 0, 0, 0)
        dropdown.Visible = false
        dropdown.ClipsDescendants = true
        dropdown.BorderSizePixel = 0
        dropdown.Parent = parent
        MarkBg(dropdown, "Entry")
        AddCorner(dropdown, 10)
        AddStroke(dropdown, "Accent", 1, 0.86)

        local search = Instance.new("TextBox")
        search.Name = "SearchBox"
        search.Size = UDim2.new(1, -16, 0, 34)
        search.Position = UDim2.new(0, 8, 0, 8)
        search.BorderSizePixel = 0
        search.ClearTextOnFocus = false
        search.PlaceholderText = "Search emote..."
        search.Text = ""
        search.Font = Enum.Font.Gotham
        search.TextSize = 12
        search.TextXAlignment = Enum.TextXAlignment.Left
        search.Parent = dropdown
        MarkBg(search, "Panel2")
        MarkText(search, "Text")
        AddCorner(search, 8)
        AddStroke(search, "Accent", 1, 0.9)

        local list = Instance.new("ScrollingFrame")
        list.Name = "Options"
        list.Size = UDim2.new(1, -16, 1, -54)
        list.Position = UDim2.new(0, 8, 0, 46)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ScrollBarThickness = UserInputService.TouchEnabled and 5 or 6
        list.ScrollBarImageColor3 = ThemeColor("Accent")
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.Parent = dropdown

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 6)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = list

        local listPadding = Instance.new("UIPadding")
        listPadding.PaddingBottom = UDim.new(0, 6)
        listPadding.PaddingRight = UDim.new(0, 8)
        listPadding.Parent = list

        local function fetchOptions()
            local ok, opts = pcall(getOptions)
            if ok and type(opts) == "table" then return opts end
            return {}
        end

        local function currentValue()
            local ok, value = pcall(getValue)
            return ok and tostring(value or "") or ""
        end

        local function clearRows()
            for _, child in ipairs(optionRows) do
                pcall(function() child:Destroy() end)
            end
            optionRows = {}
        end

        local function refreshHeader()
            valueLabel.Text = currentValue()
            chevron.Text = open and "^" or "v"
        end

        local function rebuild()
            clearRows()
            local opts = fetchOptions()
            local current = currentValue()
            local q = string.lower(query or "")
            local added = 0
            for _, opt in ipairs(opts) do
                local name = tostring(type(opt) == "table" and (opt.Name or opt.Value or opt[1]) or opt)
                local value = (type(opt) == "table" and (opt.Value or opt.Key or opt.Name or opt[1])) or opt
                if q == "" or string.find(string.lower(name), q, 1, true) then
                    local item = Instance.new("TextButton")
                    item.Name = "Emote_" .. name
                    item.Size = UDim2.new(1, 0, 0, 34)
                    item.BorderSizePixel = 0
                    item.Text = (name == current and "[X] " or "[ ] ") .. name
                    item.Font = Enum.Font.GothamBold
                    item.TextSize = 12
                    item.TextXAlignment = Enum.TextXAlignment.Left
                    item.TextTruncate = Enum.TextTruncate.AtEnd
                    item.AutoButtonColor = true
                    item.Parent = list
                    AddCorner(item, 8)
                    AddStroke(item, "Accent", 1, 0.9)
                    table.insert(optionRows, item)
                    added = added + 1

                    local selected = name == current
                    if selected and CurrentThemeName == "DARK" then
                        item.BackgroundColor3 = ThemeColor("ButtonActive")
                        item.TextColor3 = Color3.fromRGB(25, 25, 25)
                    else
                        MarkBg(item, selected and "ButtonActive" or "Panel2")
                        MarkText(item, "Text")
                    end

                    item.Activated:Connect(function()
                        if onSelect then
                            pcall(function() onSelect(value, name) end)
                        end
                        open = false
                        dropdown.Visible = false
                        dropdown.Size = UDim2.new(1, 0, 0, 0)
                        refreshHeader()
                        rebuild()
                        RefreshAllControls()
                    end)
                end
            end

            if added == 0 then
                local empty = Instance.new("TextLabel")
                empty.Name = "NoResults"
                empty.Size = UDim2.new(1, 0, 0, 34)
                empty.BackgroundTransparency = 1
                empty.Text = "No emote found"
                empty.Font = Enum.Font.Gotham
                empty.TextSize = 12
                empty.TextXAlignment = Enum.TextXAlignment.Left
                empty.Parent = list
                MarkText(empty, "Muted")
                table.insert(optionRows, empty)
            end
        end

        local function setOpen(state)
            open = state and true or false
            dropdown.Visible = open
            dropdown.Size = UDim2.new(1, 0, 0, open and 214 or 0)
            refreshHeader()
            rebuild()
            if open then
                task.defer(function()
                    pcall(function() search:CaptureFocus() end)
                end)
            end
        end

        row.Activated:Connect(function()
            setOpen(not open)
        end)

        search:GetPropertyChangedSignal("Text"):Connect(function()
            query = search.Text or ""
            if open then rebuild() end
        end)

        table.insert(ValueRefreshers, function()
            refreshHeader()
            if open then rebuild() end
        end)

        refreshHeader()
        return row, dropdown
    end

    local function SetCustomScale(value)
        UIScaleValue = math.clamp(tonumber(value) or UIScaleValue, 0.65, 1.15)
        UIScaleObj.Scale = UIScaleValue
        UpdateDashboard()
    end

    local function SetCustomTheme(themeName)
        if not Themes[themeName] then return end
        CurrentThemeName = themeName
        ApplyTheme(CurrentThemeName)
        RepaintCustomUI()
        UpdateDashboard()
    end

    local function SetCustomAccentColor(color)
        if typeof(color) ~= "Color3" then return end
        CustomAccentColor = color
        Themes["CUSTOM"] = BuildCustomTheme(CustomAccentColor)
        SetCustomTheme("CUSTOM")
    end

    local function UpdateFPSDashboardButton()
        -- FPS Boost ON/OFF is controlled from the VISUALS tab only.
    end

    local function SetFPSDashboardVisible(state)
        if FPSDashboard then
            FPSDashboard.Visible = state and true or false
        end
        UpdateFPSDashboardButton()
    end

    local function CreateFPSDashboard()
        if FPSDashboard and FPSDashboard.Parent then return end

        local parentGui = CoreGui or PlayerGui or CustomGui
        if not parentGui then return end

        if FPSDashboardGui and FPSDashboardGui.Parent then
            pcall(function() FPSDashboardGui:Destroy() end)
        end

        FPSDashboardGui = Instance.new("ScreenGui")
        FPSDashboardGui.Name = "Haimiyach_FPS_Boost_Dashboard"
        FPSDashboardGui.ResetOnSpawn = false
        FPSDashboardGui.IgnoreGuiInset = true
        FPSDashboardGui.DisplayOrder = 999998
        pcall(function() FPSDashboardGui.Parent = parentGui end)
        if not FPSDashboardGui.Parent and PlayerGui then
            pcall(function() FPSDashboardGui.Parent = PlayerGui end)
        end
        if not FPSDashboardGui.Parent then return end

        FPSDashboard = Instance.new("Frame")
        FPSDashboard.Name = "FPSBoostDashboard"
        FPSDashboard.Size = UDim2.new(0, UserInputService.TouchEnabled and 132 or 150, 0, 64)
        FPSDashboard.Position = UDim2.new(0, 10, 0, UserInputService.TouchEnabled and 58 or 66)
        FPSDashboard.BorderSizePixel = 0
        FPSDashboard.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        FPSDashboard.BackgroundTransparency = 0.34
        FPSDashboard.Active = true
        FPSDashboard.Visible = FPSBoostActive
        FPSDashboard.ZIndex = 950
        FPSDashboard.Parent = FPSDashboardGui
        AddCorner(FPSDashboard, 12)
        local dashStroke = Instance.new("UIStroke")
        dashStroke.Color = Color3.fromRGB(110, 110, 110)
        dashStroke.Thickness = 1
        dashStroke.Transparency = 0.72
        dashStroke.Parent = FPSDashboard

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, -16, 0, 18)
        title.Position = UDim2.new(0, 8, 0, 4)
        title.BackgroundTransparency = 1
        title.Text = "FPS BOOST"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 10
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(245, 245, 245)
        title.ZIndex = 951
        title.Parent = FPSDashboard

        FPSDashboardFpsLabel = Instance.new("TextLabel")
        FPSDashboardFpsLabel.Name = "FPSLabel"
        FPSDashboardFpsLabel.Size = UDim2.new(1, -16, 0, 15)
        FPSDashboardFpsLabel.Position = UDim2.new(0, 8, 0, 27)
        FPSDashboardFpsLabel.BackgroundTransparency = 1
        FPSDashboardFpsLabel.Text = "FPS: --"
        FPSDashboardFpsLabel.Font = Enum.Font.GothamSemibold
        FPSDashboardFpsLabel.TextSize = 10
        FPSDashboardFpsLabel.TextXAlignment = Enum.TextXAlignment.Left
        FPSDashboardFpsLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
        FPSDashboardFpsLabel.ZIndex = 951
        FPSDashboardFpsLabel.Parent = FPSDashboard

        FPSDashboardPingLabel = Instance.new("TextLabel")
        FPSDashboardPingLabel.Name = "PingLabel"
        FPSDashboardPingLabel.Size = UDim2.new(1, -16, 0, 15)
        FPSDashboardPingLabel.Position = UDim2.new(0, 8, 0, 43)
        FPSDashboardPingLabel.BackgroundTransparency = 1
        FPSDashboardPingLabel.Text = "PING: --"
        FPSDashboardPingLabel.Font = Enum.Font.GothamSemibold
        FPSDashboardPingLabel.TextSize = 10
        FPSDashboardPingLabel.TextXAlignment = Enum.TextXAlignment.Left
        FPSDashboardPingLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        FPSDashboardPingLabel.ZIndex = 951
        FPSDashboardPingLabel.Parent = FPSDashboard

        local dragHitbox = Instance.new("TextButton")
        dragHitbox.Name = "DragHitbox"
        dragHitbox.Size = UDim2.new(1, 0, 1, 0)
        dragHitbox.Position = UDim2.fromOffset(0, 0)
        dragHitbox.BackgroundTransparency = 1
        dragHitbox.Text = ""
        dragHitbox.AutoButtonColor = false
        dragHitbox.ZIndex = 952
        dragHitbox.Parent = FPSDashboard

        -- Mini dashboard is draggable from the whole panel and has no extra ON/OFF button.
        MakeDraggable(dragHitbox, FPSDashboard, 2, true)
        UpdateFPSDashboardButton()
    end

    task.spawn(function()
        local frames = 0
        local last = os.clock()
        local fpsConnection
        fpsConnection = RunService.RenderStepped:Connect(function()
            frames += 1
            local now = os.clock()
            if now - last >= 1 then
                RealFPSValue = math.floor(frames / math.max(now - last, 0.01) + 0.5)
                frames = 0
                last = now
            end
        end)

        while CustomGui and CustomGui.Parent do
            local fpsText = "FPS: " .. tostring(RealFPSValue)
            local pingText = "PING: " .. GetRealPingText()

            if VisualsFpsValueLabel then
                VisualsFpsValueLabel.Text = fpsText
            end
            if VisualsPingValueLabel then
                VisualsPingValueLabel.Text = pingText
            end

            if FPSDashboard and FPSDashboard.Visible then
                if FPSDashboardFpsLabel then
                    FPSDashboardFpsLabel.Text = fpsText
                end
                if FPSDashboardPingLabel then
                    FPSDashboardPingLabel.Text = pingText
                end
                UpdateFPSDashboardButton()
            end
            task.wait(0.35)
        end

        if fpsConnection then
            pcall(function() fpsConnection:Disconnect() end)
        end
    end)

    local function CreateFloatingButton()
        local buttonParent = CoreGui or PlayerGui
        if not buttonParent then return end
        for _, container in ipairs(containers) do
            pcall(function()
                local old = container:FindFirstChild("Haimiyach_Hub_Show_Button")
                if old then old:Destroy() end
            end)
        end

        local ShowGui = Instance.new("ScreenGui")
        ShowGui.Name = "Haimiyach_Hub_Show_Button"
        ShowGui.ResetOnSpawn = false
        ShowGui.IgnoreGuiInset = true
        ShowGui.DisplayOrder = 999999
        pcall(function() ShowGui.Parent = buttonParent end)
        if not ShowGui.Parent and PlayerGui then pcall(function() ShowGui.Parent = PlayerGui end) end
        if not ShowGui.Parent then return end

        ShowUIButton = Instance.new("TextButton")
        ShowUIButton.Name = "LockedTopShowButton"
        ShowUIButton.BorderSizePixel = 0
        ShowUIButton.Text = "HAIMIYACH HUB"
        ShowUIButton.Font = Enum.Font.GothamBold
        ShowUIButton.TextSize = UserInputService.TouchEnabled and 12 or 13
        ShowUIButton.Active = true
        ShowUIButton.Visible = not Main.Visible
        ShowUIButton.Parent = ShowGui
        ShowUIButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        ShowUIButton.TextColor3 = Color3.fromRGB(235, 235, 235)
        ShowUIButton.ZIndex = 999
        AddCorner(ShowUIButton, 18)
        ShowUIStroke = nil
        LockShowButtonTop()

        -- Locked top button: no drag, so it cannot disappear off-screen.
        ShowUIButton.Activated:Connect(function()
            SetHubVisible(true)
        end)
    end

    -- Main window can be moved freely by dragging the top title bar. Only the show button stays locked.
    MakeDraggable(TopBar, Main, 4, false)

    if MinimizeHub then
        MinimizeHub.Activated:Connect(function()
            SetHubMinimized(not IsMinimized)
        end)
    end

    CloseHub.Activated:Connect(function()
        SetHubVisible(false)
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == UIKeybind then
            ToggleHubVisible()
        end
    end)

    task.spawn(function()
        while CustomGui and CustomGui.Parent do
            task.wait(1)
            if ShowUIButton then
                LockShowButtonTop()
            end
        end
    end)

    -- ================= FLING =================
    -- Removed from clean build: FLING tab and controls.

    -- ================= FE EMOTE =================
    -- Removed from clean build: FE EMOTE tab and controls.

    -- ================= MOVEMENT =================
    -- Removed from clean build: MOVEMENT tab and controls.

    -- ================= VISUALS =================
    local VisualsPage = CreateTab("VISUALS")

    local PerformanceRow = Instance.new("Frame")
    PerformanceRow.Name = "PerformanceDashboard"
    PerformanceRow.Size = UDim2.new(1, 0, 0, 54)
    PerformanceRow.BorderSizePixel = 0
    PerformanceRow.Parent = VisualsPage
    MarkBg(PerformanceRow, "Panel2")
    AddCorner(PerformanceRow, 10)
    AddStroke(PerformanceRow, "Accent", 1, 0.86)

    local PerformanceTitle = Instance.new("TextLabel")
    PerformanceTitle.Name = "Title"
    PerformanceTitle.Size = UDim2.new(0.34, -8, 1, 0)
    PerformanceTitle.Position = UDim2.new(0, 12, 0, 0)
    PerformanceTitle.BackgroundTransparency = 1
    PerformanceTitle.Text = "PERFORMANCE"
    PerformanceTitle.Font = Enum.Font.GothamBold
    PerformanceTitle.TextSize = 13
    PerformanceTitle.TextXAlignment = Enum.TextXAlignment.Left
    PerformanceTitle.Parent = PerformanceRow
    MarkText(PerformanceTitle, "Text")

    local PerformanceStats = Instance.new("Frame")
    PerformanceStats.Name = "Stats"
    PerformanceStats.Size = UDim2.new(0.58, -12, 1, -8)
    PerformanceStats.Position = UDim2.new(0.39, 0, 0, 4)
    PerformanceStats.BackgroundTransparency = 1
    PerformanceStats.Parent = PerformanceRow

    VisualsFpsValueLabel = Instance.new("TextLabel")
    VisualsFpsValueLabel.Name = "FPSValue"
    VisualsFpsValueLabel.Size = UDim2.new(1, 0, 0, 22)
    VisualsFpsValueLabel.Position = UDim2.new(0, 0, 0, 1)
    VisualsFpsValueLabel.BackgroundTransparency = 1
    VisualsFpsValueLabel.Text = "FPS: --"
    VisualsFpsValueLabel.Font = Enum.Font.GothamSemibold
    VisualsFpsValueLabel.TextSize = 13
    VisualsFpsValueLabel.TextXAlignment = Enum.TextXAlignment.Left
    VisualsFpsValueLabel.Parent = PerformanceStats
    MarkText(VisualsFpsValueLabel, "Text")

    VisualsPingValueLabel = Instance.new("TextLabel")
    VisualsPingValueLabel.Name = "PingValue"
    VisualsPingValueLabel.Size = UDim2.new(1, 0, 0, 22)
    VisualsPingValueLabel.Position = UDim2.new(0, 0, 0, 24)
    VisualsPingValueLabel.BackgroundTransparency = 1
    VisualsPingValueLabel.Text = "PING: --"
    VisualsPingValueLabel.Font = Enum.Font.GothamSemibold
    VisualsPingValueLabel.TextSize = 13
    VisualsPingValueLabel.TextXAlignment = Enum.TextXAlignment.Left
    VisualsPingValueLabel.Parent = PerformanceStats
    MarkText(VisualsPingValueLabel, "Muted")

    Toggle(VisualsPage, "FPS BOOST", function()
        return FPSBoostActive
    end, function(value)
        SetFPSBoostEnabled(value)
        SetFPSDashboardVisible(FPSBoostActive)
        RefreshAllControls()
        Notify("FPS Boost", FPSBoostActive and "Enabled" or "Disabled", 2)
    end)
    Toggle(VisualsPage, "HIGH GRAPHICS", function()
        return HighGraphicsActive
    end, function(value)
        SetHighGraphicsEnabled(value)
        SetFPSDashboardVisible(FPSBoostActive)
        RefreshAllControls()
        Notify("High Graphics", HighGraphicsActive and "Enabled" or "Disabled", 2)
    end)

    -- ================= UTILITY =================
    -- Removed from clean build: UTILITY tab and controls.

    -- ================= AIMBOT =================
    -- Removed from clean build: AIMBOT tab and controls.

    -- ================= SETTINGS =================
    local SettingsPageCustom = CreateTab("SETTINGS")

    -- UI color settings removed: HAIMIYACH HUB now uses the default DARK theme only.

    Adjuster(SettingsPageCustom, "UI Scale", function() return UIScaleValue * 100 end, function(v)
        SetCustomScale((tonumber(v) or 100) / 100)
    end, 5, 5, 65, 115, nil)
    Button(SettingsPageCustom, "RESET UI SETTINGS", function()
        SetCustomScale(UserInputService.TouchEnabled and 0.82 or 1)
        CurrentThemeName = "DARK"
        ApplyTheme("DARK")
        RepaintCustomUI()
        Notify("UI Settings", "UI settings have been reset.", 1.5)
        RefreshAllControls()
    end)
    OptionDropdown(SettingsPageCustom, "UI KEYBIND", function()
        return KeybindOptions[UIKeybindIndex].Name
    end, function()
        local list = {}
        for _, option in ipairs(KeybindOptions) do
            table.insert(list, option.Name)
        end
        return list
    end, function(value)
        local selectedName = tostring(value)
        for i, option in ipairs(KeybindOptions) do
            if option.Name == selectedName then
                UIKeybindIndex = i
                UIKeybind = option.Key
                break
            end
        end
        Notify("UI Keybind", "Keybind set to " .. KeybindOptions[UIKeybindIndex].Name .. ".", 1.5)
    end)
    Button(SettingsPageCustom, "MINIMIZE UI", function()
        SetHubMinimized(true)
    end)
    Button(SettingsPageCustom, "HIDE UI", function()
        SetHubVisible(false)
    end)

    -- ================= CREDITS =================
    -- Removed from clean build: CREDITS tab and controls.

    CreateFloatingButton()
    CreateFPSDashboard()
    SetFPSDashboardVisible(FPSBoostActive)
    if ShowUIButton then ShowUIButton.Visible = false end
    RepaintCustomUI()
    if TabBar then
        TabBar.CanvasPosition = Vector2.new(0, 0)
    end
    SelectTab("VISUALS")

    task.spawn(function()
        while CustomGui and CustomGui.Parent do
            pcall(RefreshAllControls)
            task.wait(1.25)
        end
    end)
end)
