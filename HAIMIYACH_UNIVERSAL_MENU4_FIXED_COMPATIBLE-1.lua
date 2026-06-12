--// HAIMIYACH PREMIUM GUI + MAIN MENU
--// Premium layout + no crop + minimize/open + size setting + one-click themes
--// GUI utama + TROLL EMOTE. Logic lama tetap dipertahankan.

--// SERVICES
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--// REMOVE OLD GUI
local OLD_GUI_NAME = "Haimiyach_Premium_GUI"
local oldGui = PlayerGui:FindFirstChild(OLD_GUI_NAME)
if oldGui then
    oldGui:Destroy()
end

--// STATE
local SelectedTargets = {}
local PlayerCheckboxes = {}
local ThemedButtons = {}
local CurrentWidth = 300
local CurrentHeight = 350
local CurrentThemeName = "CYAN"

local StartFling
local StopFling

local AntiFlingActive = false
local AntiFlingConnection = nil
local LastSafeCFrame = nil
local AntiFlingButton
local ToggleAntiFling


--// MENU 3 MOVEMENT STATE
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

--// FIXED BY CHATGPT - MENU 4 UI NO ERROR VERSION
--// MENU 4 UI STATE
local Menu4Scroll = nil
local Menu4ThemeLabels = {}
local Menu4AimbotButton = nil
local Menu4EspButton = nil
local Menu4FlyButton = nil
local Menu4StatusLabel = nil
local Menu4FovLabel = nil
local Menu4SmoothnessLabel = nil
local Menu4SensitivityLabel = nil
local Menu4FlySpeedLabel = nil

--// THEMES
local Themes = {
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

--// UTILS
local function GetTheme()
    return Themes[CurrentThemeName] or Themes["CYAN"]
end

local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

local function New(className, props)
    local obj = Instance.new(className)

    for key, value in pairs(props or {}) do
        obj[key] = value
    end

    return obj
end

local function Corner(parent, radius)
    local c = New("UICorner", {
        CornerRadius = UDim.new(0, radius or 10),
        Parent = parent
    })
    return c
end

local function Stroke(parent, color, thickness, transparency)
    local s = New("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        Parent = parent
    })
    return s
end

local function Padding(parent, left, right, top, bottom)
    local p = New("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent
    })
    return p
end

local function MakeButton(text, parent, callback)
    local theme = GetTheme()

    local parentZIndex = 1
if parent and parent:IsA("GuiObject") then
    parentZIndex = parent.ZIndex + 1
end

local btn = New("TextButton", {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = theme.Button,
    BorderSizePixel = 0,
    Text = text,
    TextColor3 = theme.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    AutoButtonColor = true,
    Active = true,
    Selectable = true,
    ZIndex = parentZIndex,
    Parent = parent
})

    Corner(btn, 10)
    local btnStroke = Stroke(btn, theme.Accent, 1, 0.72)

    table.insert(ThemedButtons, {
        Button = btn,
        Stroke = btnStroke
    })

    btn.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end)

    return btn
end

local function CountSelectedTargets()
    local count = 0

    for _ in pairs(SelectedTargets) do
        count = count + 1
    end

    return count
end

--// GUI SETUP
local ScreenGui = New("ScreenGui", {
    Name = OLD_GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui
})

local OpenButton = New("TextButton", {
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

local MainFrame = New("Frame", {
    Size = UDim2.new(0, CurrentWidth, 0, CurrentHeight),
    Position = UDim2.new(0.5, -CurrentWidth / 2, 0.5, -CurrentHeight / 2),
    BackgroundColor3 = GetTheme().Background,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 10,
    Parent = ScreenGui
})
Corner(MainFrame, 16)
local MainStroke = Stroke(MainFrame, GetTheme().Accent, 2, 0.25)

local MainGradient = New("UIGradient", {
    Rotation = 35,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, GetTheme().Background),
        ColorSequenceKeypoint.new(1, GetTheme().Panel)
    }),
    Parent = MainFrame
})

local TitleBar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 50),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Top,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = MainFrame
})
Corner(TitleBar, 16)

local TitleBarFix = New("Frame", {
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = GetTheme().Top,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = TitleBar
})

local Title = New("TextLabel", {
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

local SettingsButton = New("TextButton", {
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
local SettingsButtonStroke = Stroke(SettingsButton, GetTheme().Accent, 1, 0.72)

local CloseButton = New("TextButton", {
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

local ContentFrame = New("Frame", {
    Position = UDim2.new(0, 14, 0, 62),
    Size = UDim2.new(1, -28, 1, -76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = MainFrame
})

local StatusLabel = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 28),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    Text = "0 target(s) selected",
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamMedium,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
    Parent = ContentFrame
})

local Pages = New("Frame", {
    Position = UDim2.new(0, 0, 0, 38),
    Size = UDim2.new(1, 0, 1, -38),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = ContentFrame
})

local FlingPage = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})

local PlayerPage = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = FlingPage
})

local SelectionFrame = New("Frame", {
    Size = UDim2.new(1, 0, 1, -104),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    ZIndex = 12,
    Parent = PlayerPage
})
Corner(SelectionFrame, 14)
local SelectionStroke = Stroke(SelectionFrame, GetTheme().Accent, 1, 0.78)

local PlayerScrollFrame = New("ScrollingFrame", {
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

local PlayerListLayout = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8),
    Parent = PlayerScrollFrame
})

local ActionFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 132),
    Position = UDim2.new(0, 0, 1, -132),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 12,
    Parent = PlayerPage
})

local ActionGrid = New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -6, 0, 34),
    CellPadding = UDim2.new(0, 12, 0, 8),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = ActionFrame
})

local StartButton = MakeButton("START FLING", ActionFrame, function()
    if StartFling then
        StartFling()
    else
        Notify("Error", "StartFling belum tersedia", 3)
    end
end)

StartButton.BackgroundColor3 = Color3.fromRGB(30, 155, 80)

local StopButton = MakeButton("STOP FLING", ActionFrame, function()
    if StopFling then
        StopFling()
    else
        Notify("GUI", "STOP FLING.", 3)
    end
end)

StopButton.BackgroundColor3 = Color3.fromRGB(170, 45, 55)

local SelectAllButton = MakeButton("SELECT ALL", ActionFrame, nil)
local DeselectAllButton = MakeButton("DESELECT ALL", ActionFrame, nil)

AntiFlingButton = MakeButton("ANTI FLING: OFF", ActionFrame, function()
    if ToggleAntiFling then
        ToggleAntiFling()
    else
        Notify("Anti Fling", "Anti fling belum siap", 3)
    end
end)

local SettingsPage = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
    Parent = Pages
})
Corner(SettingsPage, 14)
local SettingsStroke = Stroke(SettingsPage, GetTheme().Accent, 1, 0.68)

local SettingsScroll = New("ScrollingFrame", {
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

local SettingsList = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 12),
    Parent = SettingsScroll
})

local SettingsPadding = Padding(SettingsScroll, 0, 8, 0, 14)

local function SectionLabel(text)
    local label = New("TextLabel", {
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
    return label
end

local function GridContainer(height, columns)
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

local SizeGrid
local ThemeGrid

SectionLabel("SIZE")
local SizeFrame
SizeFrame, SizeGrid = GridContainer(142, 3)

local ThemeTitle = SectionLabel("THEME COLOR")
local ThemeFrame
ThemeFrame, ThemeGrid = GridContainer(196, 2)

local ShowPage

local CloseSettingsSpacer = New("Frame", {
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = SettingsScroll
})

local CloseSettingsSpacerTop = New("Frame", {
    Size = UDim2.new(1, 0, 0, 6),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = SettingsScroll
})

local CloseSettingsButton = MakeButton("CLOSE SETTINGS", SettingsScroll, function()
    if ShowPage then
        ShowPage("HOME")
    else
        PlayerPage.Visible = true
        SettingsPage.Visible = false
    end
end)

CloseSettingsButton.Size = UDim2.new(1, 0, 0, 38)

local CloseSettingsSpacerBottom = New("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = SettingsScroll
})

--// MAIN MENU PAGE
local MainMenuPage = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = true,
    ZIndex = 30,
    Parent = Pages
})
Corner(MainMenuPage, 14)
local MainMenuStroke = Stroke(MainMenuPage, GetTheme().Accent, 1, 0.72)

local Menu2Page = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})
Corner(Menu2Page, 14)

local Menu3Page = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})
Corner(Menu3Page, 14)

local Menu4Page = New("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 30,
    Parent = Pages
})
Corner(Menu4Page, 14)

ShowPage = function(pageName)
    MainMenuPage.Visible = false
    FlingPage.Visible = false
    PlayerPage.Visible = false
    SettingsPage.Visible = false
    Menu2Page.Visible = false
    Menu3Page.Visible = false
    Menu4Page.Visible = false

    if pageName == "HOME" then
        MainMenuPage.Visible = true

    elseif pageName == "FLING" then
        FlingPage.Visible = true
        PlayerPage.Visible = true

    elseif pageName == "SETTINGS" then
        SettingsPage.Visible = true

    elseif pageName == "TROLL" then
        Menu2Page.Visible = true

    elseif pageName == "MOVEMENT" then
        Menu3Page.Visible = true

    elseif pageName == "AIMBOT" then
        Menu4Page.Visible = true
    end
end

local MenuTitle = New("TextLabel", {
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

local MenuGrid = New("Frame", {
    Size = UDim2.new(1, -20, 1, -52),
    Position = UDim2.new(0, 10, 0, 48),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = MainMenuPage
})

local MenuGridLayout = New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 44),
    CellPadding = UDim2.new(0, 10, 0, 10),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Parent = MenuGrid
})

local FlingMenuButton = MakeButton("FLING", MenuGrid, function()
    ShowPage("FLING")
end)

local Menu2Button = MakeButton("TROLL", MenuGrid, function()
    ShowPage("TROLL")
end)

local Menu3Button = MakeButton("MOVEMENT", MenuGrid, function()
    ShowPage("MOVEMENT")
end)

local Menu4Button = MakeButton("AIMBOT", MenuGrid, function()
    ShowPage("MENU4")
end)

local FlingBackFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 40,
    Parent = PlayerPage
})

local FlingBackButton = MakeButton("← BACK", FlingBackFrame, function()
    ShowPage("HOME")
end)
FlingBackButton.Size = UDim2.new(0, 92, 0, 32)
FlingBackButton.Position = UDim2.new(0, 0, 0, 0)
FlingBackButton.ZIndex = 41

SelectionFrame.Position = UDim2.new(0, 0, 0, 42)
SelectionFrame.Size = UDim2.new(1, 0, 1, -182)
ActionFrame.Size = UDim2.new(1, 0, 0, 132)
ActionFrame.Position = UDim2.new(0, 0, 1, -132)

local function CreateMenuPageContent(page, titleText)
    local backButton = MakeButton("← BACK", page, function()
        ShowPage("HOME")
    end)

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

local Menu2BackButton, Menu2Label = CreateMenuPageContent(Menu2Page, "TROLL")
local Menu3BackButton, Menu3Label = CreateMenuPageContent(Menu3Page, "MOVEMENT")
local Menu4BackButton, Menu4Label = CreateMenuPageContent(Menu4Page, "AIMBOT")


--// TROLL: EMOTE PLAYER
--// Script emote dimasukkan ke Menu2Page, tidak membuat ScreenGui/CoreGui baru.

if Menu2Label then
    Menu2Label.Text = "EMOTE PLAYER"
    Menu2Label.Position = UDim2.new(0, 110, 0, 12)
    Menu2Label.Size = UDim2.new(1, -122, 0, 32)
    Menu2Label.TextSize = 15
    Menu2Label.TextXAlignment = Enum.TextXAlignment.Center
    Menu2Label.ZIndex = 42
end

local EmoteSettings = {
    Speed = 1
}

local CurrentTrack = nil
local EmoteCharacter = Player.Character or Player.CharacterAdded:Wait()
local EmoteHumanoid = EmoteCharacter:WaitForChild("Humanoid")

Player.CharacterAdded:Connect(function(newCharacter)
    EmoteCharacter = newCharacter
    EmoteHumanoid = newCharacter:WaitForChild("Humanoid")
    CurrentTrack = nil
end)

local function ExtractEmoteId(input)
    input = tostring(input or "")

    local num = tonumber(input)
    if num then
        return num
    end

    local patterns = {
        "rbxassetid://(%d+)",
        "roblox%.com/catalog/(%d+)",
        "roblox%.com/library/(%d+)",
        "roblox%.com/animations/(%d+)",
        "roblox%.com/bundles/(%d+)",
        "roblox%.com/asset/%?id=(%d+)"
    }

    for _, pattern in ipairs(patterns) do
        local match = string.match(input, pattern)
        if match then
            return tonumber(match)
        end
    end

    return nil
end

local function StopEmoteTrack()
    if CurrentTrack then
        pcall(function()
            CurrentTrack:Stop(0.1)
        end)

        CurrentTrack = nil
    end
end

local function LoadEmoteTrack(id)
    if not EmoteHumanoid then
        Notify("Error", "Humanoid belum siap", 3)
        return nil
    end

    StopEmoteTrack()

    local animId = "rbxassetid://" .. tostring(id)

    -- Beberapa ID adalah asset/catalog yang di dalamnya berisi AnimationId asli.
    -- Kalau GetObjects gagal, script tetap coba pakai ID langsung.
    local ok, result = pcall(function()
        return game:GetObjects(animId)
    end)

    if ok and result and #result > 0 then
        local anim = result[1]

        if anim and anim:IsA("Animation") and anim.AnimationId and anim.AnimationId ~= "" then
            animId = anim.AnimationId
        end
    end

    local newAnim = Instance.new("Animation")
    newAnim.AnimationId = animId

    local track
    local success, err = pcall(function()
        local animator = EmoteHumanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = EmoteHumanoid
        end

        track = animator:LoadAnimation(newAnim)
    end)

    -- Fallback untuk beberapa executor/game yang lebih cocok dengan Humanoid:LoadAnimation
    if (not success or not track) and EmoteHumanoid then
        success, err = pcall(function()
            track = EmoteHumanoid:LoadAnimation(newAnim)
        end)
    end

    if not success or not track then
        Notify("Error", "Gagal load emote. ID bisa private/tidak valid.", 3)
        return nil
    end

    track.Priority = Enum.AnimationPriority.Action4

    local playOk = pcall(function()
        track:Play(0.1, 1, EmoteSettings.Speed)
        track:AdjustSpeed(EmoteSettings.Speed)
    end)

    if not playOk then
        Notify("Error", "Emote gagal diputar", 3)
        return nil
    end

    CurrentTrack = track
    Notify("Emote", "Playing: " .. tostring(id), 2)
    return track
end

local EmoteList = {
    {Name = "Dropkick", Id = 77072646896519},
    {Name = "Punch", Id = 112242378828218},
    {Name = "Freeze", Id = 18243599800},
}

local EmoteContainer = New("Frame", {
    Size = UDim2.new(1, -24, 1, -56),
    Position = UDim2.new(0, 12, 0, 52),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = Menu2Page
})

local EmoteBox = New("TextBox", {
    Size = UDim2.new(1, 0, 0, 32),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = GetTheme().Entry,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Masukkan Emote ID atau URL...",
    TextColor3 = GetTheme().Text,
    PlaceholderColor3 = GetTheme().Muted,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
    ZIndex = 32,
    Parent = EmoteContainer
})
Corner(EmoteBox, 8)
Stroke(EmoteBox, GetTheme().Accent, 1, 0.78)

local EmoteButtonFrame = New("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    Position = UDim2.new(0, 0, 0, 40),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 32,
    Parent = EmoteContainer
})

local EmoteButtonGrid = New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 32),
    CellPadding = UDim2.new(0, 10, 0, 0),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = EmoteButtonFrame
})

local PlayEmoteButton = MakeButton("▶ PLAY", EmoteButtonFrame, function()
    local id = ExtractEmoteId(EmoteBox.Text)

    if not id then
        Notify("Error", "Emote ID/URL tidak valid", 3)
        return
    end

    LoadEmoteTrack(id)
end)
PlayEmoteButton.Size = UDim2.new(1, 0, 0, 32)

local StopEmoteButton = MakeButton("■ STOP", EmoteButtonFrame, function()
    StopEmoteTrack()
end)
StopEmoteButton.Size = UDim2.new(1, 0, 0, 32)

local EmoteScroll = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -84),
    Position = UDim2.new(0, 0, 0, 84),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 32,
    Parent = EmoteContainer
})

local EmoteListLayout = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8),
    Parent = EmoteScroll
})

Padding(EmoteScroll, 0, 8, 0, 12)

for _, emote in ipairs(EmoteList) do
    local emoteButton = MakeButton(emote.Name, EmoteScroll, function()
        EmoteBox.Text = tostring(emote.Id)
        LoadEmoteTrack(emote.Id)
    end)

    emoteButton.Size = UDim2.new(1, 0, 0, 34)
end

local SpeedContainer = New("Frame", {
    Size = UDim2.new(1, 0, 0, 68),
    BackgroundColor3 = GetTheme().Entry,
    BorderSizePixel = 0,
    ZIndex = 33,
    Parent = EmoteScroll
})
Corner(SpeedContainer, 10)
Stroke(SpeedContainer, GetTheme().Accent, 1, 0.78)

local SpeedLabel = New("TextLabel", {
    Size = UDim2.new(0.5, -8, 0, 22),
    Position = UDim2.new(0, 10, 0, 6),
    BackgroundTransparency = 1,
    Text = "Speed: 1.00",
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 34,
    Parent = SpeedContainer
})

local SpeedTextBox = New("TextBox", {
    Size = UDim2.new(0.5, -18, 0, 22),
    Position = UDim2.new(0.5, 8, 0, 6),
    BackgroundColor3 = GetTheme().Button,
    BorderSizePixel = 0,
    Text = "1",
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    ClearTextOnFocus = false,
    ZIndex = 34,
    Parent = SpeedContainer
})
Corner(SpeedTextBox, 7)

local SliderBar = New("Frame", {
    Size = UDim2.new(1, -28, 0, 10),
    Position = UDim2.new(0, 14, 0, 42),
    BackgroundColor3 = GetTheme().Button,
    BorderSizePixel = 0,
    ZIndex = 34,
    Parent = SpeedContainer
})
Corner(SliderBar, 6)

local SliderFill = New("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = GetTheme().Accent,
    BorderSizePixel = 0,
    ZIndex = 35,
    Parent = SliderBar
})
Corner(SliderFill, 6)

local SliderThumb = New("Frame", {
    Size = UDim2.new(0, 16, 0, 16),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0,
    ZIndex = 36,
    Parent = SliderBar
})
Corner(SliderThumb, 16)

local function ApplyEmoteSpeed(value)
    value = math.clamp(tonumber(value) or 1, 0, 5)
    value = math.floor(value * 100) / 100

    EmoteSettings.Speed = value
    SpeedLabel.Text = string.format("Speed: %.2f", value)
    SpeedTextBox.Text = tostring(value)

    local rel = math.clamp(value / 5, 0, 1)

    TweenService:Create(SliderFill, TweenInfo.new(0.12), {
        Size = UDim2.new(rel, 0, 1, 0)
    }):Play()

    TweenService:Create(SliderThumb, TweenInfo.new(0.12), {
        Position = UDim2.new(rel, 0, 0.5, 0)
    }):Play()

    if CurrentTrack and CurrentTrack.IsPlaying then
        pcall(function()
            CurrentTrack:AdjustSpeed(value)
        end)
    end
end

local SpeedDragging = false

local function UpdateSpeedFromInput(input)
    local rel = math.clamp(
        (input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X,
        0,
        1
    )

    ApplyEmoteSpeed(5 * rel)
end

SliderBar.InputBegan:Connect(function(input)
    local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
    local isTouch = input.UserInputType == Enum.UserInputType.Touch

    if isMouse or isTouch then
        SpeedDragging = true
        UpdateSpeedFromInput(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
    local isTouch = input.UserInputType == Enum.UserInputType.Touch

    if SpeedDragging and (isMouseMove or isTouch) then
        UpdateSpeedFromInput(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
    local isTouch = input.UserInputType == Enum.UserInputType.Touch

    if SpeedDragging and (isMouse or isTouch) then
        SpeedDragging = false
    end
end)

SpeedTextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        ApplyEmoteSpeed(SpeedTextBox.Text)
    end
end)

ApplyEmoteSpeed(1)



--// MOVEMENT LOGIC
if Menu3Label then
    Menu3Label.Text = "MOVEMENT"
    Menu3Label.Position = UDim2.new(0, 110, 0, 12)
    Menu3Label.Size = UDim2.new(1, -122, 0, 32)
    Menu3Label.TextSize = 15
    Menu3Label.TextXAlignment = Enum.TextXAlignment.Center
    Menu3Label.ZIndex = 42
end

local function GetMovementCharacterParts()
    local char = Player.Character
    if not char then return nil, nil, nil end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart)

    return char, humanoid, root
end

local function UpdateMovementLabels()
    if FlySpeedLabel then
        FlySpeedLabel.Text = "FLY SPEED: " .. tostring(FlySpeed)
    end

    if MoveSpeedLabel then
        MoveSpeedLabel.Text = "MOVE SPEED: " .. tostring(MoveSpeed)
    end

    if FlyButton then
        FlyButton.Text = FlyActive and "FLY: ON" or "FLY: OFF"
    end

    if InfJumpButton then
        InfJumpButton.Text = InfJumpActive and "INF JUMP: ON" or "INF JUMP: OFF"
    end
end

local function ApplyMoveSpeed()
    local _, humanoid = GetMovementCharacterParts()

    if humanoid then
        pcall(function()
            humanoid.WalkSpeed = MoveSpeed
        end)
    end
end

Player.CharacterAdded:Connect(function()
    task.wait(1)
    ApplyMoveSpeed()
end)

local function StartFly()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end

    FlyActive = true

    FlyConnection = RunService.RenderStepped:Connect(function()
        if not FlyActive then return end

        local _, humanoid, root = GetMovementCharacterParts()
        if not humanoid or not root then return end

        local moveDirection = Vector3.new(0, 0, 0)

        if humanoid.MoveDirection.Magnitude > 0 then
            moveDirection = moveDirection + humanoid.MoveDirection
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end

        humanoid.PlatformStand = false

        pcall(function()
            root.AssemblyLinearVelocity = moveDirection * FlySpeed
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end)
    end)

    UpdateMovementLabels()
end

local function StopFly()
    FlyActive = false

    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end

    local _, humanoid, root = GetMovementCharacterParts()

    if humanoid then
        humanoid.PlatformStand = false
    end

    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end)
    end

    UpdateMovementLabels()
end

local function ToggleFly()
    if FlyActive then
        StopFly()
    else
        StartFly()
    end

    Notify("Fly", FlyActive and "ON" or "OFF", 2)
end

local function ToggleInfJump()
    InfJumpActive = not InfJumpActive

    if InfJumpActive then
        if InfJumpConnection then
            InfJumpConnection:Disconnect()
            InfJumpConnection = nil
        end

        InfJumpConnection = UserInputService.JumpRequest:Connect(function()
            if not InfJumpActive then return end

            local _, humanoid = GetMovementCharacterParts()
            if not humanoid then return end

            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end)

        Notify("Inf Jump", "ON", 2)
    else
        if InfJumpConnection then
            InfJumpConnection:Disconnect()
            InfJumpConnection = nil
        end

        Notify("Inf Jump", "OFF", 2)
    end

    UpdateMovementLabels()
end

local function ChangeFlySpeed(amount)
    FlySpeed = math.clamp(FlySpeed + amount, 10, 250)
    UpdateMovementLabels()
    Notify("Fly Speed", tostring(FlySpeed), 1.5)
end

local function ChangeMoveSpeed(amount)
    MoveSpeed = math.clamp(MoveSpeed + amount, 16, 250)
    ApplyMoveSpeed()
    UpdateMovementLabels()
    Notify("Move Speed", tostring(MoveSpeed), 1.5)
end

--// MOVEMENT UI
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

FlyButton = MakeButton("FLY: OFF", Menu3Scroll, function()
    ToggleFly()
end)
FlyButton.Size = UDim2.new(1, 0, 0, 34)

InfJumpButton = MakeButton("INF JUMP: OFF", Menu3Scroll, function()
    ToggleInfJump()
end)
InfJumpButton.Size = UDim2.new(1, 0, 0, 34)

FlySpeedLabel = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
    Text = "FLY SPEED: " .. tostring(FlySpeed),
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 36,
    Parent = Menu3Scroll
})

local FlySpeedGrid = New("Frame", {
    Size = UDim2.new(1, 0, 0, 76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 36,
    Parent = Menu3Scroll
})

New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 32),
    CellPadding = UDim2.new(0, 8, 0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = FlySpeedGrid
})

MakeButton("FLY -5", FlySpeedGrid, function()
    ChangeFlySpeed(-5)
end)

MakeButton("FLY +5", FlySpeedGrid, function()
    ChangeFlySpeed(5)
end)

MakeButton("FLY -25", FlySpeedGrid, function()
    ChangeFlySpeed(-25)
end)

MakeButton("FLY +25", FlySpeedGrid, function()
    ChangeFlySpeed(25)
end)

MoveSpeedLabel = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
    Text = "MOVE SPEED: " .. tostring(MoveSpeed),
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 36,
    Parent = Menu3Scroll
})

local MoveSpeedGrid = New("Frame", {
    Size = UDim2.new(1, 0, 0, 76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 36,
    Parent = Menu3Scroll
})

New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 32),
    CellPadding = UDim2.new(0, 8, 0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = MoveSpeedGrid
})

MakeButton("MOVE -5", MoveSpeedGrid, function()
    ChangeMoveSpeed(-5)
end)

MakeButton("MOVE +5", MoveSpeedGrid, function()
    ChangeMoveSpeed(5)
end)

MakeButton("MOVE -25", MoveSpeedGrid, function()
    ChangeMoveSpeed(-25)
end)

MakeButton("MOVE +25", MoveSpeedGrid, function()
    ChangeMoveSpeed(25)
end)

local ResetMovementButton = MakeButton("RESET SPEED", Menu3Scroll, function()
    FlySpeed = 55
    MoveSpeed = 16
    ApplyMoveSpeed()
    UpdateMovementLabels()
    Notify("Movement", "Speed reset", 2)
end)
ResetMovementButton.Size = UDim2.new(1, 0, 0, 34)

UpdateMovementLabels()


--// MENU 4 UI 
if Menu4Label then
    Menu4Label.Text = "AIMBOT"
    Menu4Label.Position = UDim2.new(0, 110, 0, 12)
    Menu4Label.Size = UDim2.new(1, -122, 0, 32)
    Menu4Label.TextSize = 15
    Menu4Label.TextXAlignment = Enum.TextXAlignment.Center
    Menu4Label.ZIndex = 42
end

local RivalsUI = {
    Aimbot = false,
    ESP = false,
    Fly = false,
    FOV = 150,
    Smoothness = 0.20,
    Sensitivity = 0.45,
    FlySpeed = 1.30
}

local Menu4RenderConnection = nil
local Menu4FlyVel = Vector3.zero
local Menu4LastEspUpdate = 0

local function AddMenu4ThemeLabel(label)
    table.insert(Menu4ThemeLabels, label)
    return label
end

local function GetMenu4Camera()
    return workspace.CurrentCamera
end

local function cleanESP()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then
            local hl = char:FindFirstChild("Menu4ESP_Highlight")
            if hl then
                hl:Destroy()
            end
        end
    end
end

local function getMenu4Target()
    if not RivalsUI.Aimbot then
        return nil
    end

    local camera = GetMenu4Camera()
    if not camera then
        return nil
    end

    local mouse = UserInputService:GetMouseLocation()
    local closest, dist = nil, RivalsUI.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            local char = p.Character
            local head = char and char:FindFirstChild("Head")

            if head and head:IsA("BasePart") then
                local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)

                if onScreen then
                    local mag = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude

                    if mag < dist then
                        dist = mag
                        closest = screenPos
                    end
                end
            end
        end
    end

    return closest
end

local function UpdateMenu4ESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            local char = p.Character
            local head = char and char:FindFirstChild("Head")

            if head and head:IsA("BasePart") and not char:FindFirstChild("Menu4ESP_Highlight") then
                local hl = Instance.new("Highlight")
                hl.Name = "Menu4ESP_Highlight"
                hl.FillColor = Color3.fromRGB(0, 200, 255)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.45
                hl.OutlineTransparency = 0
                hl.Adornee = char
                hl.Parent = char
            end
        end
    end
end

local function StopMenu4Fly()
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.PlatformStand = false
    end

    Menu4FlyVel = Vector3.zero
end

local function UpdateMenu4Fly()
    local char = Player.Character
    if not char then
        StopMenu4Fly()
        return
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local camera = GetMenu4Camera()

    if not root or not camera then
        return
    end

    if hum then
        hum.PlatformStand = true
    end

    local dir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        dir = dir + camera.CFrame.LookVector
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        dir = dir - camera.CFrame.LookVector
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        dir = dir - camera.CFrame.RightVector
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        dir = dir + camera.CFrame.RightVector
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
        dir = dir + Vector3.new(0, 1, 0)
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
        dir = dir - Vector3.new(0, 1, 0)
    end

    Menu4FlyVel = Menu4FlyVel:Lerp(dir * RivalsUI.FlySpeed, 0.12)
    root.CFrame = root.CFrame + Menu4FlyVel
    root.AssemblyLinearVelocity = Vector3.zero
end

local function UpdateMenu4Aimbot()
    if not RivalsUI.Aimbot then
        return
    end

    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end

    local target = getMenu4Target()
    if not target then
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    local dx = (target.X - mousePos.X) * RivalsUI.Sensitivity
    local dy = (target.Y - mousePos.Y) * RivalsUI.Sensitivity

    if mousemoverel then
        local smooth = math.max(RivalsUI.Smoothness, 0.01)
        mousemoverel(dx / (smooth * 10), dy / (smooth * 10))
    end
end

local function StartMenu4Loop()
    if Menu4RenderConnection then
        return
    end

    Menu4RenderConnection = RunService.RenderStepped:Connect(function()
        if RivalsUI.ESP then
            local now = tick()
            if now - Menu4LastEspUpdate >= 0.5 then
                Menu4LastEspUpdate = now
                UpdateMenu4ESP()
            end
        else
            cleanESP()
        end

        UpdateMenu4Aimbot()

        if RivalsUI.Fly then
            UpdateMenu4Fly()
        else
            StopMenu4Fly()
        end
    end)
end

local function OnMenu4AimbotChanged(enabled)
    RivalsUI.Aimbot = enabled
    StartMenu4Loop()
end

local function OnMenu4EspChanged(enabled)
    RivalsUI.ESP = enabled
    StartMenu4Loop()

    if not enabled then
        cleanESP()
    end
end

local function OnMenu4FlyChanged(enabled)
    RivalsUI.Fly = enabled
    StartMenu4Loop()

    if not enabled then
        StopMenu4Fly()
    end
end

local function OnMenu4SettingsChanged(settings)
    RivalsUI.FOV = settings.FOV
    RivalsUI.Smoothness = settings.Smoothness
    RivalsUI.Sensitivity = settings.Sensitivity
    RivalsUI.FlySpeed = settings.FlySpeed
end

local function UpdateMenu4UI()
    if Menu4AimbotButton then
        Menu4AimbotButton.Text = RivalsUI.Aimbot and "AIMBOT: ON" or "AIMBOT: OFF"
    end

    if Menu4EspButton then
        Menu4EspButton.Text = RivalsUI.ESP and "ESP: ON" or "ESP: OFF"
    end

    if Menu4FlyButton then
        Menu4FlyButton.Text = RivalsUI.Fly and "FLY: ON" or "FLY: OFF"
    end

    if Menu4StatusLabel then
        Menu4StatusLabel.Text = string.format(
            "Aimbot: %s  |  ESP: %s  |  Fly: %s",
            RivalsUI.Aimbot and "ON" or "OFF",
            RivalsUI.ESP and "ON" or "OFF",
            RivalsUI.Fly and "ON" or "OFF"
        )
    end

    if Menu4FovLabel then
        Menu4FovLabel.Text = "FOV: " .. tostring(RivalsUI.FOV)
    end

    if Menu4SmoothnessLabel then
        Menu4SmoothnessLabel.Text = string.format("SMOOTHNESS: %.2f", RivalsUI.Smoothness)
    end

    if Menu4SensitivityLabel then
        Menu4SensitivityLabel.Text = string.format("SENSITIVITY: %.2f", RivalsUI.Sensitivity)
    end

    if Menu4FlySpeedLabel then
        Menu4FlySpeedLabel.Text = string.format("FLY SPEED: %.2f", RivalsUI.FlySpeed)
    end
end

local function NotifyMenu4Setting(name, value)
    Notify("Aimbot", name .. ": " .. tostring(value), 1.5)
end

local function ChangeMenu4Fov(amount)
    RivalsUI.FOV = math.clamp(RivalsUI.FOV + amount, 20, 500)
    UpdateMenu4UI()
    OnMenu4SettingsChanged(RivalsUI)
    NotifyMenu4Setting("FOV", RivalsUI.FOV)
end

local function ChangeMenu4Smoothness(amount)
    RivalsUI.Smoothness = math.clamp(math.floor((RivalsUI.Smoothness + amount) * 100 + 0.5) / 100, 0.01, 2)
    UpdateMenu4UI()
    OnMenu4SettingsChanged(RivalsUI)
    NotifyMenu4Setting("Smoothness", RivalsUI.Smoothness)
end

local function ChangeMenu4Sensitivity(amount)
    RivalsUI.Sensitivity = math.clamp(math.floor((RivalsUI.Sensitivity + amount) * 100 + 0.5) / 100, 0.01, 5)
    UpdateMenu4UI()
    OnMenu4SettingsChanged(RivalsUI)
    NotifyMenu4Setting("Sensitivity", RivalsUI.Sensitivity)
end

local function ChangeMenu4FlySpeed(amount)
    RivalsUI.FlySpeed = math.clamp(math.floor((RivalsUI.FlySpeed + amount) * 100 + 0.5) / 100, 0.10, 10)
    UpdateMenu4UI()
    OnMenu4SettingsChanged(RivalsUI)
    NotifyMenu4Setting("Fly Speed", RivalsUI.FlySpeed)
end

Menu4Scroll = New("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 52),
    Size = UDim2.new(1, -24, 1, -60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 35,
    Parent = Menu4Page
})

local Menu4List = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Menu4Scroll
})

Padding(Menu4Scroll, 0, 8, 0, 12)

Menu4StatusLabel = AddMenu4ThemeLabel(New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    Text = "Aimbot: OFF  |  ESP: OFF  |  Fly: OFF",
    TextColor3 = GetTheme().Text,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 36,
    Parent = Menu4Scroll
}))

Menu4AimbotButton = MakeButton("AIMBOT: OFF", Menu4Scroll, function()
    RivalsUI.Aimbot = not RivalsUI.Aimbot
    OnMenu4AimbotChanged(RivalsUI.Aimbot)
    UpdateMenu4UI()
    Notify("Aimbot", RivalsUI.Aimbot and "ON" or "OFF", 2)
end)
Menu4AimbotButton.Size = UDim2.new(1, 0, 0, 34)

Menu4EspButton = MakeButton("ESP: OFF", Menu4Scroll, function()
    RivalsUI.ESP = not RivalsUI.ESP
    OnMenu4EspChanged(RivalsUI.ESP)
    UpdateMenu4UI()
    Notify("ESP", RivalsUI.ESP and "ON" or "OFF", 2)
end)
Menu4EspButton.Size = UDim2.new(1, 0, 0, 34)

Menu4FlyButton = MakeButton("FLY: OFF", Menu4Scroll, function()
    RivalsUI.Fly = not RivalsUI.Fly
    OnMenu4FlyChanged(RivalsUI.Fly)
    UpdateMenu4UI()
    Notify("FLY", RivalsUI.Fly and "ON" or "OFF", 2)
end)
Menu4FlyButton.Size = UDim2.new(1, 0, 0, 34)

local function CreateMenu4SectionLabel(text)
    return AddMenu4ThemeLabel(New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = GetTheme().Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 36,
        Parent = Menu4Scroll
    }))
end

local function CreateMenu4Grid(height)
    local gridFrame = New("Frame", {
        Size = UDim2.new(1, 0, 0, height or 76),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 36,
        Parent = Menu4Scroll
    })

    New("UIGridLayout", {
        CellSize = UDim2.new(0.5, -5, 0, 32),
        CellPadding = UDim2.new(0, 8, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = gridFrame
    })

    return gridFrame
end

Menu4FovLabel = CreateMenu4SectionLabel("FOV: " .. tostring(RivalsUI.FOV))
local FovGrid = CreateMenu4Grid(76)

MakeButton("FOV -10", FovGrid, function()
    ChangeMenu4Fov(-10)
end)

MakeButton("FOV +10", FovGrid, function()
    ChangeMenu4Fov(10)
end)

MakeButton("FOV -50", FovGrid, function()
    ChangeMenu4Fov(-50)
end)

MakeButton("FOV +50", FovGrid, function()
    ChangeMenu4Fov(50)
end)

Menu4SmoothnessLabel = CreateMenu4SectionLabel(string.format("SMOOTHNESS: %.2f", RivalsUI.Smoothness))
local SmoothGrid = CreateMenu4Grid(76)

MakeButton("SMOOTH -0.05", SmoothGrid, function()
    ChangeMenu4Smoothness(-0.05)
end)

MakeButton("SMOOTH +0.05", SmoothGrid, function()
    ChangeMenu4Smoothness(0.05)
end)

MakeButton("SMOOTH -0.20", SmoothGrid, function()
    ChangeMenu4Smoothness(-0.20)
end)

MakeButton("SMOOTH +0.20", SmoothGrid, function()
    ChangeMenu4Smoothness(0.20)
end)

Menu4SensitivityLabel = CreateMenu4SectionLabel(string.format("SENSITIVITY: %.2f", RivalsUI.Sensitivity))
local SensGrid = CreateMenu4Grid(76)

MakeButton("SENS -0.05", SensGrid, function()
    ChangeMenu4Sensitivity(-0.05)
end)

MakeButton("SENS +0.05", SensGrid, function()
    ChangeMenu4Sensitivity(0.05)
end)

MakeButton("SENS -0.25", SensGrid, function()
    ChangeMenu4Sensitivity(-0.25)
end)

MakeButton("SENS +0.25", SensGrid, function()
    ChangeMenu4Sensitivity(0.25)
end)

Menu4FlySpeedLabel = CreateMenu4SectionLabel(string.format("FLY SPEED: %.2f", RivalsUI.FlySpeed))
local Menu4FlyGrid = CreateMenu4Grid(76)

MakeButton("FLY -0.1", Menu4FlyGrid, function()
    ChangeMenu4FlySpeed(-0.1)
end)

MakeButton("FLY +0.1", Menu4FlyGrid, function()
    ChangeMenu4FlySpeed(0.1)
end)

MakeButton("FLY -0.5", Menu4FlyGrid, function()
    ChangeMenu4FlySpeed(-0.5)
end)

MakeButton("FLY +0.5", Menu4FlyGrid, function()
    ChangeMenu4FlySpeed(0.5)
end)

local Menu4TargetInfo = AddMenu4ThemeLabel(New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    Text = "Target: Players | Fly: W/A/S/D + Q/E",
    TextColor3 = GetTheme().Muted,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 36,
    Parent = Menu4Scroll
}))

local Menu4ResetButton = MakeButton("RESET SETTINGS", Menu4Scroll, function()
    RivalsUI.Aimbot = false
    RivalsUI.ESP = false
    RivalsUI.Fly = false
    RivalsUI.FOV = 150
    RivalsUI.Smoothness = 0.20
    RivalsUI.Sensitivity = 0.45
    RivalsUI.FlySpeed = 1.30

    OnMenu4AimbotChanged(false)
    OnMenu4EspChanged(false)
    OnMenu4FlyChanged(false)
    OnMenu4SettingsChanged(RivalsUI)
    UpdateMenu4UI()
    Notify("Aimbot", "Settings reset", 2)
end)
Menu4ResetButton.Size = UDim2.new(1, 0, 0, 34)

UpdateMenu4UI()


ShowPage("HOME")


--// DRAG
local dragging = false
local dragStart = nil
local startPos = nil

TitleBar.InputBegan:Connect(function(input)
    local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
    local isTouch = input.UserInputType == Enum.UserInputType.Touch

    if isMouse or isTouch then
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
    local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
    local isTouch = input.UserInputType == Enum.UserInputType.Touch

    if dragging and (isMouseMove or isTouch) then
        local delta = input.Position - dragStart

        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

--// FUNCTIONS
local function UpdateStatus()
    StatusLabel.Text = tostring(CountSelectedTargets()) .. " target(s) selected"
end

local function ApplyTheme(themeName)
    local theme = Themes[themeName]
    if not theme then return end

    CurrentThemeName = themeName

    MainFrame.BackgroundColor3 = theme.Background
    MainGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.Background),
        ColorSequenceKeypoint.new(1, theme.Panel)
    })

    MainStroke.Color = theme.Accent
    TitleBar.BackgroundColor3 = theme.Top
    TitleBarFix.BackgroundColor3 = theme.Top
    Title.TextColor3 = theme.Accent

    SettingsButton.BackgroundColor3 = theme.Button
    SettingsButton.TextColor3 = theme.Text

    OpenButton.BackgroundColor3 = theme.Background
    OpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)

    ContentFrame.BackgroundTransparency = 1
    StatusLabel.TextColor3 = theme.Text

    SelectionFrame.BackgroundColor3 = theme.Panel
    SelectionStroke.Color = theme.Accent

    if MainMenuPage then
        MainMenuPage.BackgroundColor3 = theme.Panel
    end
    if MainMenuStroke then
        MainMenuStroke.Color = theme.Accent
    end
    if Menu2Page then
        Menu2Page.BackgroundColor3 = theme.Panel
    end
    if Menu3Page then
        Menu3Page.BackgroundColor3 = theme.Panel
    end
    if Menu4Page then
        Menu4Page.BackgroundColor3 = theme.Panel
    end
    if MenuTitle then
        MenuTitle.TextColor3 = theme.Text
    end
    if Menu2Label then
        Menu2Label.TextColor3 = theme.Text
    end
    if Menu3Label then
        Menu3Label.TextColor3 = theme.Text
    end
    if Menu4Label then
        Menu4Label.TextColor3 = theme.Text
    end

    if EmoteBox then
        EmoteBox.BackgroundColor3 = theme.Entry
        EmoteBox.TextColor3 = theme.Text
        EmoteBox.PlaceholderColor3 = theme.Muted
    end
    if SpeedContainer then
        SpeedContainer.BackgroundColor3 = theme.Entry
    end
    if SpeedLabel then
        SpeedLabel.TextColor3 = theme.Text
    end
    if SpeedTextBox then
        SpeedTextBox.BackgroundColor3 = theme.Button
        SpeedTextBox.TextColor3 = theme.Text
    end
    if SliderBar then
        SliderBar.BackgroundColor3 = theme.Button
    end
    if SliderFill then
        SliderFill.BackgroundColor3 = theme.Accent
    end

    SettingsPage.BackgroundColor3 = theme.Panel
    SettingsStroke.Color = theme.Accent

    CloseSettingsButton.BackgroundColor3 = theme.Button
    CloseSettingsButton.TextColor3 = theme.Text

    SelectAllButton.BackgroundColor3 = theme.Button
    DeselectAllButton.BackgroundColor3 = theme.Button

    for _, obj in ipairs(SettingsScroll:GetChildren()) do
        if obj:IsA("TextLabel") then
            obj.TextColor3 = theme.Text
        end
    end

    for _, data in pairs(PlayerCheckboxes) do
        if data.Entry then
            data.Entry.BackgroundColor3 = theme.Entry
        end

        if data.Checkbox then
            data.Checkbox.BackgroundColor3 = theme.Button
        end

        if data.NameLabel then
            data.NameLabel.TextColor3 = theme.Text
        end
    end

    for _, data in ipairs(ThemedButtons) do
        if data.Button then
            data.Button.BackgroundColor3 = theme.Button
            data.Button.TextColor3 = theme.Text
        end

        if data.Stroke then
            data.Stroke.Color = theme.Accent
        end
    end


    if FlySpeedLabel then
        FlySpeedLabel.TextColor3 = theme.Text
    end

    if MoveSpeedLabel then
        MoveSpeedLabel.TextColor3 = theme.Text
    end

    if Menu3Scroll then
        Menu3Scroll.ScrollBarImageColor3 = theme.Accent
    end

    if FlyButton then
        FlyButton.TextColor3 = theme.Text
    end

    if InfJumpButton then
        InfJumpButton.TextColor3 = theme.Text
    end



    if Menu4Scroll then
        Menu4Scroll.ScrollBarImageColor3 = theme.Accent
    end

    if Menu4ThemeLabels then
        for _, label in ipairs(Menu4ThemeLabels) do
            if label then
                label.TextColor3 = theme.Text
            end
        end
    end

    if Menu4NoteLabel then
        Menu4NoteLabel.TextColor3 = theme.Muted
    end

    if SettingsButtonStroke then
        SettingsButtonStroke.Color = theme.Accent
    end

end

local function SafeResize(width, height)
    CurrentWidth = math.clamp(width, 240, 420)
    CurrentHeight = math.clamp(height, 300, 500)

    MainFrame.Size = UDim2.new(0, CurrentWidth, 0, CurrentHeight)

    ActionGrid.CellSize = UDim2.new(0.5, -6, 0, 34)

    if CurrentWidth < 390 then
        SizeGrid.CellSize = UDim2.new(0.5, -8, 0, 40)
        ThemeGrid.CellSize = UDim2.new(1, -8, 0, 40)
        SizeFrame.Size = UDim2.new(1, 0, 0, 196)
        ThemeFrame.Size = UDim2.new(1, 0, 0, 372)
    else
        SizeGrid.CellSize = UDim2.new(1 / 3, -8, 0, 40)
        ThemeGrid.CellSize = UDim2.new(0.5, -8, 0, 40)
        SizeFrame.Size = UDim2.new(1, 0, 0, 142)
        ThemeFrame.Size = UDim2.new(1, 0, 0, 196)
    end
end

local function RefreshPlayerList()
    for _, child in ipairs(PlayerScrollFrame:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    PlayerCheckboxes = {}

    local playerList = Players:GetPlayers()
    table.sort(playerList, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    local theme = GetTheme()

    for _, player in ipairs(playerList) do
        if player ~= Player then
            local selected = SelectedTargets[player.Name] ~= nil

            local entry = New("Frame", {
                Size = UDim2.new(1, -2, 0, 42),
                BackgroundColor3 = theme.Entry,
                BorderSizePixel = 0,
                ZIndex = 14,
                Parent = PlayerScrollFrame
            })
            Corner(entry, 10)

            local checkbox = New("TextButton", {
                Size = UDim2.new(0, 28, 0, 28),
                Position = UDim2.new(0, 8, 0.5, -14),
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
                Text = "✓",
                TextColor3 = theme.Accent2,
                Font = Enum.Font.GothamBlack,
                TextSize = 18,
                Visible = selected,
                ZIndex = 16,
                Parent = checkbox
            })

            local nameLabel = New("TextLabel", {
                Size = UDim2.new(1, -50, 1, 0),
                Position = UDim2.new(0, 46, 0, 0),
                BackgroundTransparency = 1,
                Text = player.DisplayName .. "  @" .. player.Name,
                TextColor3 = theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
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

            clickArea.MouseButton1Click:Connect(toggle)

            PlayerCheckboxes[player.Name] = {
                Entry = entry,
                Checkbox = checkbox,
                Checkmark = checkmark,
                NameLabel = nameLabel
            }
        end
    end

    UpdateStatus()
end

local function ToggleAllPlayers(selectAll)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Player then
            local data = PlayerCheckboxes[player.Name]

            if data then
                if selectAll then
                    SelectedTargets[player.Name] = player
                    data.Checkmark.Visible = true
                else
                    SelectedTargets[player.Name] = nil
                    data.Checkmark.Visible = false
                end
            end
        end
    end

    UpdateStatus()
end

--// SETTINGS BUTTONS
local function AddSizeButton(text, callback)
    return MakeButton(text, SizeFrame, callback)
end

AddSizeButton("SMALL", function()
    SafeResize(240, 300)
end)

AddSizeButton("NORMAL", function()
    SafeResize(300, 350)
end)

AddSizeButton("BIG", function()
    SafeResize(340, 400)
end)

AddSizeButton("WIDTH -", function()
    SafeResize(CurrentWidth - 15, CurrentHeight)
end)

AddSizeButton("WIDTH +", function()
    SafeResize(CurrentWidth + 15, CurrentHeight)
end)

AddSizeButton("HEIGHT -", function()
    SafeResize(CurrentWidth, CurrentHeight - 15)
end)

AddSizeButton("HEIGHT +", function()
    SafeResize(CurrentWidth, CurrentHeight + 15)
end)

local function AddThemeButton(themeName)
    local btn = MakeButton(themeName, ThemeFrame, function()
        ApplyTheme(themeName)
    end)

    btn.BackgroundColor3 = Themes[themeName].Button
    return btn
end

AddThemeButton("CYAN")
AddThemeButton("RED DARK")
AddThemeButton("BLUE")
AddThemeButton("PURPLE")
AddThemeButton("GREEN")
AddThemeButton("GOLD")
AddThemeButton("PINK")
AddThemeButton("ORANGE")

-- Variables
local FlingActive = false
local FlingConnection = nil
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

-- The fling function from zqyDSUWX
local function SkidFling(TargetPlayer)
local Character = Player.Character
local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
local RootPart = Humanoid and Humanoid.RootPart
local TCharacter = TargetPlayer.Character
if not TCharacter then return end

local THumanoid  
local TRootPart  
local THead  
local Accessory  
local Handle  
if TCharacter:FindFirstChildOfClass("Humanoid") then  
    THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")  
end  
if THumanoid and THumanoid.RootPart then  
    TRootPart = THumanoid.RootPart  
end  
if TCharacter:FindFirstChild("Head") then  
    THead = TCharacter.Head  
end  
if TCharacter:FindFirstChildOfClass("Accessory") then  
    Accessory = TCharacter:FindFirstChildOfClass("Accessory")  
end  
if Accessory and Accessory:FindFirstChild("Handle") then  
    Handle = Accessory.Handle  
end  
if Character and Humanoid and RootPart then  
    if RootPart.Velocity.Magnitude < 50 then  
        getgenv().OldPos = RootPart.CFrame  
    end  
      
    if THumanoid and THumanoid.Sit then  
        return Notify("Error", TargetPlayer.Name .. " is sitting", 2)  
    end  
      
    if THead then  
        workspace.CurrentCamera.CameraSubject = THead  
    elseif Handle then  
        workspace.CurrentCamera.CameraSubject = Handle  
    elseif THumanoid and TRootPart then  
        workspace.CurrentCamera.CameraSubject = THumanoid  
    end  
      
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then  
        return  
    end  
      
    local FPos = function(BasePart, Pos, Ang)  
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang  
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)  
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)  
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)  
    end  
      
    local SFBasePart = function(BasePart)  
        local TimeToWait = 2  
        local Time = tick()  
        local Angle = 0  
        repeat  
            if RootPart and THumanoid then  
                if BasePart.Velocity.Magnitude < 50 then  
                    Angle = Angle + 100  
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0 ,0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))  
                    task.wait()  
                else  
                    FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))  
                    task.wait()  
                      
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))  
                    task.wait()  
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))  
                    task.wait()  
                end  
            end  
        until Time + TimeToWait < tick() or not FlingActive  
    end  
      
    workspace.FallenPartsDestroyHeight = 0/0  
      
    local BV = Instance.new("BodyVelocity")  
    BV.Parent = RootPart  
    BV.Velocity = Vector3.new(0, 0, 0)  
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)  
      
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)  
      
    if TRootPart then  
        SFBasePart(TRootPart)  
    elseif THead then  
        SFBasePart(THead)  
    elseif Handle then  
        SFBasePart(Handle)  
    else  
        return Notify("Error", TargetPlayer.Name .. " has no valid parts", 2)  
    end  
      
    BV:Destroy()  
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)  
    workspace.CurrentCamera.CameraSubject = Humanoid  
      
    -- Reset character position  
    if getgenv().OldPos then  
        repeat  
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)  
            Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))  
            Humanoid:ChangeState("GettingUp")  
            for _, part in pairs(Character:GetChildren()) do  
                if part:IsA("BasePart") then  
                    part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new()  
                end  
            end  
            task.wait()  
        until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25  
        workspace.FallenPartsDestroyHeight = getgenv().FPDH  
    end  
else  
    return Notify("Error", "Your character is not ready", 2)  
end

end
-- Start flinging selected targets
StartFling = function()
if FlingActive then return end

local count = CountSelectedTargets()  
if count == 0 then  
    StatusLabel.Text = "No targets selected!"  
    wait(1)  
    StatusLabel.Text = "Select targets to fling"  
    return  
end  
  
FlingActive = true  
UpdateStatus()  
Notify("Started", "Flinging " .. count .. " targets", 2)  
  
-- Start flinger in separate thread  
spawn(function()  
    while FlingActive do  
        local validTargets = {}  
          
        -- Process all targets first to determine which are valid  
        for name, player in pairs(SelectedTargets) do  
            if player and player.Parent then  
                validTargets[name] = player  
            else  
                -- Remove players who left  
                SelectedTargets[name] = nil  
                local checkbox = PlayerCheckboxes[name]  
                if checkbox then  
                    checkbox.Checkmark.Visible = false  
                end  
            end  
        end  
          
        -- Then attempt to fling each valid target  
        for _, player in pairs(validTargets) do  
            if FlingActive then  
                SkidFling(player)  
                -- Brief wait between targets to allow movement to reset  
                wait(0.1)  
            else  
                break  
            end  
        end  
          
        -- Update status periodically  
        UpdateStatus()  
          
        -- Wait a moment before starting next fling cycle  
        wait(0.5)  
    end  
end)

end
-- Stop flinging
StopFling = function()
    if not FlingActive then return end

    FlingActive = false

    if UpdateStatus then
        UpdateStatus()
    end

    if Notify then
        Notify("Stopped", "Fling has been stopped", 2)
    end
end

--// ANTI FLING DEFENSE
--// Mode: Light NoCollisionConstraint
--// Tujuan: mencegah tabrakan badan player lain tanpa reset velocity.
local AntiFlingConstraints = {}
local AntiFlingOriginalCanCollide = {}
local AntiFlingNextRefresh = 0
local AntiFlingRefreshDelay = 0.85
local AntiFlingRadius = 55

local function ClearAntiFlingConstraints(restoreCollision)
    for localPart, pairMap in pairs(AntiFlingConstraints) do
        for otherPart, constraint in pairs(pairMap) do
            if constraint and constraint.Parent then
                pcall(function()
                    constraint:Destroy()
                end)
            end
        end
    end

    AntiFlingConstraints = {}

    if restoreCollision then
        for part, oldValue in pairs(AntiFlingOriginalCanCollide) do
            if part and part.Parent and part:IsA("BasePart") then
                pcall(function()
                    part.CanCollide = oldValue
                end)
            end
        end

        AntiFlingOriginalCanCollide = {}
    end
end

local function GetBaseParts(model)
    local parts = {}

    if not model then
        return parts
    end

    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then
            table.insert(parts, obj)
        end
    end

    return parts
end

local function GetCharacterRoot(char)
    if not char then return nil end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart)

    return root
end

local function PruneAntiFlingConstraints()
    for localPart, pairMap in pairs(AntiFlingConstraints) do
        if not localPart or not localPart.Parent then
            for _, constraint in pairs(pairMap) do
                if constraint and constraint.Parent then
                    pcall(function()
                        constraint:Destroy()
                    end)
                end
            end

            AntiFlingConstraints[localPart] = nil
        else
            for otherPart, constraint in pairs(pairMap) do
                if not otherPart
                    or not otherPart.Parent
                    or not constraint
                    or not constraint.Parent
                    or constraint.Part0 ~= localPart
                    or constraint.Part1 ~= otherPart then

                    if constraint and constraint.Parent then
                        pcall(function()
                            constraint:Destroy()
                        end)
                    end

                    pairMap[otherPart] = nil
                end
            end
        end
    end
end

local function CreateNoCollision(localPart, otherPart, parent)
    if not localPart or not otherPart or not parent then return end
    if not localPart.Parent or not otherPart.Parent then return end
    if localPart == otherPart then return end
    if not localPart:IsA("BasePart") or not otherPart:IsA("BasePart") then return end

    AntiFlingConstraints[localPart] = AntiFlingConstraints[localPart] or {}

    local existing = AntiFlingConstraints[localPart][otherPart]

    if existing and existing.Parent then
        return
    end

    if AntiFlingOriginalCanCollide[otherPart] == nil then
        AntiFlingOriginalCanCollide[otherPart] = otherPart.CanCollide
    end

    pcall(function()
        otherPart.CanCollide = false
    end)

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

local function RefreshAntiFlingNoCollision()
    if not AntiFlingActive then return end

    local localChar = Player.Character
    if not localChar then return end

    local localRoot = GetCharacterRoot(localChar)
    if not localRoot then return end

    local localHumanoid = localChar:FindFirstChildOfClass("Humanoid")
    if localHumanoid then
        if localHumanoid.Sit then
            localHumanoid.Sit = false
        end

        if localHumanoid.PlatformStand then
            localHumanoid.PlatformStand = false
        end
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

local function CleanAntiFlingCharacter(char)
    if not AntiFlingActive then return end

    local now = os.clock()

    if now < AntiFlingNextRefresh then
        return
    end

    AntiFlingNextRefresh = now + AntiFlingRefreshDelay
    RefreshAntiFlingNoCollision()
end

ToggleAntiFling = function()
    AntiFlingActive = not AntiFlingActive

    if AntiFlingButton then
        AntiFlingButton.Text = AntiFlingActive and "ANTI FLING: ON" or "ANTI FLING: OFF"
    end

    if AntiFlingActive then
        if FlingActive and StopFling then
            StopFling()
        end

        if AntiFlingConnection then
            AntiFlingConnection:Disconnect()
            AntiFlingConnection = nil
        end

        -- Bersihkan constraint lama supaya tidak dobel setelah respawn/reload.
        ClearAntiFlingConstraints(true)
        AntiFlingNextRefresh = 0

        AntiFlingConnection = RunService.Heartbeat:Connect(function()
            CleanAntiFlingCharacter(Player.Character)
        end)

        RefreshAntiFlingNoCollision()
        Notify("Anti Fling", "ON - NoCollision ringan aktif", 2)
    else
        if AntiFlingConnection then
            AntiFlingConnection:Disconnect()
            AntiFlingConnection = nil
        end

        ClearAntiFlingConstraints(true)
        AntiFlingNextRefresh = 0

        Notify("Anti Fling", "OFF", 2)
    end
end

--// EVENTS
SettingsButton.MouseButton1Click:Connect(function()
    ShowPage("SETTINGS")
end)

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenButton.Visible = true
end)

OpenButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenButton.Visible = false
end)

SelectAllButton.MouseButton1Click:Connect(function()
    ToggleAllPlayers(true)
end)

DeselectAllButton.MouseButton1Click:Connect(function()
    ToggleAllPlayers(false)
end)

Players.PlayerAdded:Connect(function()
    RefreshPlayerList()
end)

Players.PlayerRemoving:Connect(function(player)
    SelectedTargets[player.Name] = nil
    RefreshPlayerList()
end)

Player.CharacterAdded:Connect(function(char)
    task.wait(1)
    if AntiFlingActive then
        CleanAntiFlingCharacter(char)
    end
end)

--// INIT
SafeResize(CurrentWidth, CurrentHeight)
ApplyTheme(CurrentThemeName)
RefreshPlayerList()

if ShowPage then
    ShowPage("HOME")
end

Notify("Loaded", "Haimiyach HUB GUI loaded!", 3)