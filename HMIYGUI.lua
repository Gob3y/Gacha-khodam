-- // HAIMIYACH HUB GAG2 GUI ONLY | load after logic main
local __BASE_ENV=(getfenv and getfenv(1)) or _ENV or _G
local __G=(getgenv and getgenv()) or _G
local __CORE=__G.HaimiyachGAG2Core or _G.HaimiyachGAG2Core
if not __CORE then
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title="HAIMIYACH HUB",Text="Run logic main first.",Duration=6}) end)
    return
end
local __ENV=setmetatable({}, {
    __index=function(_,k) local v=__CORE[k]; if v~=nil then return v end; return __BASE_ENV[k] end,
    __newindex=function(_,k,v) __CORE[k]=v end
})
if setfenv then setfenv(1,__ENV) end
local function HaimiyachGAG2_StartUI()
-- // ============================================================ \ --
-- //                 HAIMIYACH HUB CUSTOM GUI                    \ --
-- // ============================================================ \ --

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = nil
pcall(function() CoreGui = game:GetService("CoreGui") end)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- clean old GUI first
local GUI_NAMES = {
    "Haimiyach_GAG2_Custom_UI",
    "Haimiyach_GAG2_Show_Button",
    "Haimiyach_Hub_Custom_UI",
    "Haimiyach_Hub_Show_Button",
    "Haimiyach_Premium_GUI",
    "Haimiyach_FOV_Circle",
    "Haimiyach_FPS_Boost_Dashboard",
    "SkrilyaHub",
    "MacLib"
}
local function cleanContainer(container)
    if not container then return end
    for _, name in ipairs(GUI_NAMES) do
        pcall(function()
            local old = container:FindFirstChild(name)
            if old then old:Destroy() end
        end)
    end
    for _, child in ipairs(container:GetChildren()) do
        pcall(function()
            local n = string.lower(child.Name or "")
            if child:IsA("ScreenGui") and (string.find(n, "skrilya") or string.find(n, "maclib") or string.find(n, "haimiyach_gag2") or string.find(n, "haimiyach_hub") or string.find(n, "haimiyach_premium") or string.find(n, "haimiyach_fov") or string.find(n, "haimiyach_fps")) then
                child:Destroy()
            end
        end)
    end
end
cleanContainer(PlayerGui)
cleanContainer(CoreGui)

local UI = {
    Scale = 1,
    Keybind = Enum.KeyCode.LeftControl,
    Visible = true,
    Minimized = false,
    Unloaded = false,
    CurrentTab = nil,
    Pages = {},
    TabButtons = {},
    LiveLabels = {},
    Connections = {},
}

local function trackConnection(conn)
    if conn then UI.Connections[#UI.Connections + 1] = conn end
    return conn
end

local function disconnectUiConnections()
    for _, conn in ipairs(UI.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if table.clear then
        table.clear(UI.Connections)
    else
        for i = #UI.Connections, 1, -1 do
            UI.Connections[i] = nil
        end
    end
end

local T = {
    Bg = Color3.fromRGB(22,22,22),
    Top = Color3.fromRGB(29,29,29),
    Panel = Color3.fromRGB(16,16,16),
    Panel2 = Color3.fromRGB(24,24,24),
    Row = Color3.fromRGB(32,32,32),
    Row2 = Color3.fromRGB(40,40,40),
    Text = Color3.fromRGB(242,242,242),
    Muted = Color3.fromRGB(170,170,170),
    White = Color3.fromRGB(232,232,232),
    DarkText = Color3.fromRGB(20,20,20),
    Stroke = Color3.fromRGB(60,60,60),
    Good = Color3.fromRGB(230,230,230),
}

local function new(class, props, parent)
    local obj = Instance.new(class)

    for k, v in pairs(props or {}) do
        pcall(function()
            obj[k] = v
        end)
    end

    if parent then
        pcall(function()
            obj.Parent = parent
        end)
    end

    return obj
end
local function corner(obj, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, obj)
end
local function stroke(obj, color, thickness, transparency)
    return new("UIStroke", { Color = color or T.Stroke, Thickness = thickness or 1, Transparency = transparency or 0.35 }, obj)
end
local function pad(obj, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, obj)
end
local function tween(obj, ti, props)
    pcall(function() TweenService:Create(obj, ti or TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end)
end
local function fmtValue(v, precision)
    precision = precision or 0
    if precision <= 0 then return tostring(math.floor((tonumber(v) or 0) + 0.5)) end
    local s = string.format("%." .. tostring(precision) .. "f", tonumber(v) or 0)
    s = string.gsub(s, "(%..-)0+$", "%1")
    s = string.gsub(s, "%.$", "")
    return s
end

local function cleanUiText(value)
    local s = tostring(value or "")
    s = s:gsub("[_%-]+", " ")
    s = s:gsub("(%l)(%u)", "%1 %2")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return string.upper(s)
end

-- COPY YOUTUBE LINK ON EXECUTE
do
    local YOUTUBE_LINK = "https://youtube.com/@HAIMIYACH"

    local function CopyToClipboard(text)
        local copied = false

        if type(setclipboard) == "function" then
            pcall(function()
                setclipboard(text)
                copied = true
            end)
        elseif type(toclipboard) == "function" then
            pcall(function()
                toclipboard(text)
                copied = true
            end)
        elseif type(set_clipboard) == "function" then
            pcall(function()
                set_clipboard(text)
                copied = true
            end)
        end

        return copied
    end

    if not getgenv().HaimiyachYoutubeCopied then
        getgenv().HaimiyachYoutubeCopied = true

        if CopyToClipboard(YOUTUBE_LINK) then
            pcall(function()
                notify("HAIMIYACH HUB", "YouTube link copied.", 3)
            end)
        end
    end
end

local guiParent = PlayerGui or CoreGui
local ScreenGui = new("ScreenGui", {
    Name = "Haimiyach_GAG2_Custom_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999995,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)

local BlankGui = new("ScreenGui", {
    Name = "Haimiyach_GAG2_Blank_Screen",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999994,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled = false,
}, guiParent)

local BlankFrame = new("Frame", {
    Name = "BlankFrame",
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Active = false,
    Selectable = false,
    ZIndex = 1,
}, BlankGui)

local function SetBlankScreenEnabled(state)
    S.blankScreen = state and true or false
    pcall(function()
        BlankGui.Enabled = S.blankScreen
        BlankFrame.Visible = S.blankScreen
    end)
end

local ScreenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
-- Match the original HAIMIYACH HUB custom UI proportions.
-- The uploaded HAIMIYACH-HUB.lua contains an older legacy GUI too; this size follows the custom top-tab UI style.
UI.Scale = (tonumber(S.uiScale) and tonumber(S.uiScale) > 0) and tonumber(S.uiScale) or (isMobile and 0.88 or 1)
S.uiScale = UI.Scale
do
    local savedKey = tostring(S.uiKeybindName or "LeftControl")
    if Enum.KeyCode[savedKey] then UI.Keybind = Enum.KeyCode[savedKey] end
end
local baseW = 600
local baseH = isMobile and 370 or 390

local Main = new("Frame", {
    Name = "MainWindow",
    Size = UDim2.fromOffset(baseW, baseH),
    Position = UDim2.new(0.5, -baseW/2, 0.5, -baseH/2),
    BackgroundColor3 = T.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
}, ScreenGui)
corner(Main, 14); stroke(Main, Color3.fromRGB(80,80,80), 1, 0.15)

local UIScaleObj = new("UIScale", { Scale = UI.Scale }, Main)

local TopBar = new("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = T.Top,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, Main)
corner(TopBar, 14)
-- TopBar needs its own UICorner. Parent UICorner does not reliably mask child frames in many Roblox executors,
-- so without this the upper left/right corners look sharp.
local TopCover = new("Frame", { Name = "TopCover", Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,1,-14), BackgroundColor3 = T.Top, BorderSizePixel = 0, ZIndex = 1 }, TopBar)
new("Frame", { Name = "TopLine", Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = Color3.fromRGB(45,45,45), BorderSizePixel = 0, ZIndex = 2 }, TopBar)

local Title = new("TextLabel", {
    Size = UDim2.new(1, -120, 1, 0),
    Position = UDim2.fromOffset(18, 0),
    BackgroundTransparency = 1,
    Text = "HAIMIYACH HUB",
    TextColor3 = T.Text,
    Font = Enum.Font.GothamBlack,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

local MinBtn = new("TextButton", {
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(1, -74, 0, 9),
    BackgroundTransparency = 1,
    Text = "-",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false,
}, TopBar)
local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(1, -40, 0, 9),
    BackgroundTransparency = 1,
    Text = "X",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false,
}, TopBar)

-- Separate minimized bar. Do not resize the main window into a bar because child frames can cover
-- the parent UICorner in some mobile executors and make the minimized UI look sharp/lancip.
-- MiniBar itself is transparent; MiniBg is the only visible rounded surface, so no square/lancip corner can show.
local MiniBar = new("Frame", {
    Name = "MinimizedWindow",
    Size = UDim2.fromOffset(math.floor((390 * UI.Scale) + 0.5), math.floor((44 * UI.Scale) + 0.5)),
    Position = Main.Position,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    Active = true,
    Visible = false,
}, ScreenGui)

local MiniBg = new("Frame", {
    Name = "RoundedMinimizedBackground",
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = T.Top,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 1,
}, MiniBar)
corner(MiniBg, 16); stroke(MiniBg, Color3.fromRGB(80,80,80), 1, 0.15)

local MiniTitle = new("TextLabel", {
    Size = UDim2.new(1, -92, 1, 0),
    Position = UDim2.fromOffset(16, 0),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "HAIMIYACH HUB",
    TextColor3 = T.Text,
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, MiniBar)

local MiniPlusBtn = new("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -58, 0.5, -12),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "+",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    AutoButtonColor = false,
}, MiniBar)

local MiniCloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -30, 0.5, -12),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "X",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    AutoButtonColor = false,
}, MiniBar)

local TabBar = new("ScrollingFrame", {
    Name = "LeftTabBar",
    Size = UDim2.new(0, 120, 1, -68),
    Position = UDim2.fromOffset(10, 56),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = isMobile and 3 or 4,
    ScrollBarImageColor3 = Color3.fromRGB(85,85,85),
    ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0,0),
    ClipsDescendants = true,
}, Main)
corner(TabBar, 12); stroke(TabBar, Color3.fromRGB(80,80,80), 1, 0.72); pad(TabBar, 8, 8, 8, 8)
local TabLayout = new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, TabBar)

local Content = new("Frame", {
    Name = "Content",
    Size = UDim2.new(1, -144, 1, -68),
    Position = UDim2.fromOffset(134, 56),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, Main)
corner(Content, 12); stroke(Content, Color3.fromRGB(80,80,80), 1, 0.72)

local ShowGui = new("ScreenGui", {
    Name = "Haimiyach_GAG2_Show_Button",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)
local ShowButton = new("TextButton", {
    Name = "LockedTopShowButton",
    AnchorPoint = Vector2.new(0.5, 0),
    Size = UDim2.fromOffset(isMobile and 248 or 285, isMobile and 30 or 32),
    Position = UDim2.new(0.5, 0, 0, isMobile and 8 or 12),
    BackgroundColor3 = T.Top,
    BackgroundTransparency = 0,
    Text = "",
    TextTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Active = true,
    Visible = false,
    ZIndex = 999,
}, ShowGui)

corner(ShowButton, 20)

local showBorder = Instance.new("UIStroke")
showBorder.Name = "BackgroundBorder"
showBorder.Color = Color3.fromRGB(80, 80, 80)
showBorder.Thickness = 1
showBorder.Transparency = 0.15
pcall(function()
    showBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end)
showBorder.Parent = ShowButton

local ShowButtonLabel = new("TextLabel", {
    Name = "StatusText",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -12, 1, 0),
    Position = UDim2.fromOffset(6, 0),
    Text = "HAIMIYACH HUB. |  -- FPS   |   -- ms",
    TextColor3 = T.Text,
    TextTransparency = 0,
    TextStrokeTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = isMobile and 12 or 13,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 1000,
}, ShowButton)

do
    local fpsValue = 0
    local pingValue = 0
    local fpsFrames = 0
    local fpsClock = os.clock()

    trackConnection(RunService.RenderStepped:Connect(function()
        fpsFrames = fpsFrames + 1
        local nowClock = os.clock()
        if nowClock - fpsClock >= 1 then
            fpsValue = math.floor(fpsFrames / (nowClock - fpsClock) + 0.5)
            fpsFrames = 0
            fpsClock = nowClock
        end
    end))

    task.spawn(function()
        while not S.killed do
            pcall(function()
                local stats = game:GetService("Stats")
                local net = stats:FindFirstChild("Network")
                local serverStats = net and net:FindFirstChild("ServerStatsItem")
                local pingItem = serverStats and serverStats:FindFirstChild("Data Ping")
                if pingItem and pingItem.GetValue then
                    pingValue = math.floor(tonumber(pingItem:GetValue()) or 0)
                end
            end)

            local fpsText = tostring(fpsValue > 0 and fpsValue or "--")
            local pingText = tostring(pingValue > 0 and pingValue or "--")
            ShowButtonLabel.Text = "HAIMIYACH HUB | " .. fpsText .. " FPS | " .. pingText .. " ms"

            task.wait(1)
        end
    end)
end

-- Drag main window from top bar only.
do
    local dragging = false
    local dragStart, startPos
    trackConnection(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and not UI.Unloaded and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

-- Drag minimized bar separately so the rounded bar keeps its own clean shape.
do
    local dragging = false
    local dragStart, startPos
    local function beginMiniDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MiniBar.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end
    trackConnection(MiniBar.InputBegan:Connect(beginMiniDrag))
    trackConnection(MiniBg.InputBegan:Connect(beginMiniDrag))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and not UI.Unloaded and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MiniBar.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

local function setVisible(v)
    UI.Visible = v and true or false
    if UI.Visible then
        ShowButton.Visible = false
        Main.Visible = not UI.Minimized
        MiniBar.Visible = UI.Minimized
    else
        Main.Visible = false
        MiniBar.Visible = false
        ShowButton.Visible = true
    end
end

local function setMinimized(v)
    UI.Minimized = v and true or false
    if UI.Minimized then
        MiniBar.Size = UDim2.fromOffset(math.floor((390 * UI.Scale) + 0.5), math.floor((44 * UI.Scale) + 0.5))
        MiniBar.Position = Main.Position
        Main.Visible = false
        MiniBar.Visible = UI.Visible
        MinBtn.Text = "-"
    else
        Main.Position = MiniBar.Position
        Main.Size = UDim2.fromOffset(baseW, baseH)
        TopBar.Position = UDim2.new(0, 0, 0, 0)
        TopBar.Size = UDim2.new(1, 0, 0, 48)
        if TopCover then TopCover.Visible = true end
        TabBar.Visible = true
        Content.Visible = true
        Main.Visible = UI.Visible
        MiniBar.Visible = false
        MinBtn.Text = "-"
    end
end

trackConnection(ShowButton.Activated:Connect(function()
    setMinimized(false)
    setVisible(true)
end))
trackConnection(MiniPlusBtn.Activated:Connect(function() setMinimized(false) end))
trackConnection(MiniCloseBtn.Activated:Connect(function() setVisible(false) end))
trackConnection(MinBtn.Activated:Connect(function() setMinimized(true) end))
trackConnection(CloseBtn.Activated:Connect(function() setVisible(false) end))
trackConnection(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UI.Unloaded then return end
    if input.KeyCode == UI.Keybind then
        setVisible(not UI.Visible)
    end
end))

local function refreshCanvas(page)
    task.defer(function()
        local layout = page:FindFirstChildOfClass("UIListLayout")
        if layout then page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18) end
    end)
end

local function selectTab(name)
    UI.CurrentTab = name
    for n, p in pairs(UI.Pages) do p.Visible = (n == name) end
    for n, b in pairs(UI.TabButtons) do
        local active = n == name
        tween(b, TweenInfo.new(0.12), {
            BackgroundColor3 = active and T.White or T.Row,
            TextColor3 = active and T.DarkText or T.Text,
        })
    end
end

local function createTab(name, order)
    -- Left sidebar tabs keep each page shorter and are easier to scroll on mobile.
    local displayNames = {
        ["PETS_CRATES"] = "PETS / CRATES",
    }
    local display = displayNames[name] or name
    local btn = new("TextButton", {
        Name = "Tab_" .. name,
        Size = UDim2.new(1, -2, 0, 42),
        BackgroundColor3 = T.Row,
        Text = cleanUiText(display),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = (#display > 12) and 10 or 11,
        BorderSizePixel = 0,
        LayoutOrder = order or 99,
        AutoButtonColor = true,
    }, TabBar)
    corner(btn, 12)
    stroke(btn, Color3.fromRGB(60,60,60), 1, 0.82)
    UI.TabButtons[name] = btn

    local page = new("ScrollingFrame", {
        Name = "Page_" .. name,
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = isMobile and 5 or 6,
        ScrollBarImageColor3 = Color3.fromRGB(80,80,80),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0,0),
        Visible = false,
    }, Content)
    pad(page, 3, 8, 2, 8)
    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    trackConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() refreshCanvas(page) end))
    UI.Pages[name] = page
    trackConnection(btn.Activated:Connect(function() selectTab(name) end))
    return page
end

local function safePage(page)
    return page or UI.Pages["DASHBOARD"]
end

local function addSection(page, text)
    page = safePage(page)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = cleanUiText(text),
        TextColor3 = T.Muted,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, page)
    return lbl
end

local function addLabel(page, text)
    page = safePage(page)
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        Position = UDim2.fromOffset(11, 0),
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    return lbl
end

local function addMiniNote(page, text)
    page = safePage(page)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = T.Muted,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, page)
    return lbl
end

local function addButton(page, label, callback)
    page = safePage(page)
    local btn = new("TextButton", {
        Size = UDim2.new(1,0,0,42),
        BackgroundColor3 = T.Row,
        BorderSizePixel = 0,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        AutoButtonColor = false,
    }, page)
    corner(btn, 12)
    trackConnection(btn.Activated:Connect(function()
        tween(btn, TweenInfo.new(0.08), { BackgroundColor3 = T.Row2 })
        task.delay(0.1, function() if btn and btn.Parent then tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = T.Row }) end end)
        if callback then task.spawn(function() pcall(callback) end) end
    end))
    return btn
end

local function addToggle(page, label, default, callback)
    page = safePage(page)
    local value = default and true or false
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    local txt = new("TextLabel", {
        Size = UDim2.new(1, -78, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local hit = new("TextButton", {
        Size = UDim2.fromOffset(52, 24),
        Position = UDim2.new(1, -64, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(38,38,38),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(hit, 13); stroke(hit, Color3.fromRGB(80,80,80), 1, 0.35)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(18,18),
        Position = UDim2.fromOffset(3,3),
        BackgroundColor3 = Color3.fromRGB(135,135,135),
        BorderSizePixel = 0,
    }, hit)
    corner(knob, 10)
    local function draw(call)
        tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = value and UDim2.fromOffset(31,3) or UDim2.fromOffset(3,3),
            BackgroundColor3 = value and T.White or Color3.fromRGB(135,135,135),
        })
        tween(hit, TweenInfo.new(0.15), { BackgroundColor3 = value and Color3.fromRGB(55,55,55) or Color3.fromRGB(38,38,38) })
        if call and callback then task.spawn(function() pcall(callback, value) end) end
    end
    trackConnection(hit.Activated:Connect(function() value = not value; draw(true) end))
    trackConnection(row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position
            local hp, hs = hit.AbsolutePosition, hit.AbsoluteSize
            local onSwitch = pos.X >= hp.X and pos.X <= hp.X + hs.X and pos.Y >= hp.Y and pos.Y <= hp.Y + hs.Y
            if not onSwitch then
                value = not value; draw(true)
            end
        end
    end))
    draw(false)
    return {
        Set = function(v, call) value = v and true or false; draw(call ~= false) end,
        Get = function() return value end,
    }
end

local function addSlider(page, label, min, max, default, precision, callback)
    page = safePage(page)
    min = tonumber(min) or 0; max = tonumber(max) or 100; precision = precision or 0

    -- Slider unit display:
    -- Label stays clean, value shows suffix.
    -- Example: "SPRINKLER DELAY (SEC)" -> label "SPRINKLER DELAY", value "60 sec"
    local displayLabel = tostring(label or "")
    local valueSuffix = ""
    local upperLabel = string.upper(displayLabel)

    if string.find(upperLabel, "%(SEC%)") then
        valueSuffix = " sec"
        displayLabel = displayLabel:gsub("%s*%([Ss][Ee][Cc]%)", "")
    elseif string.find(upperLabel, "%(MIN%)") then
        valueSuffix = " min"
        displayLabel = displayLabel:gsub("%s*%([Mm][Ii][Nn]%)", "")
    end

    local function fmtSliderValue(v)
        return fmtValue(v, precision) .. valueSuffix
    end

    local value = tonumber(default) or min
    value = math.clamp(value, min, max)
    local row = new("Frame", { Size = UDim2.new(1,0,0,50), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    local txt = new("TextLabel", {
        Size = UDim2.new(0.56, -16, 0, 22),
        Position = UDim2.fromOffset(12, 3),
        BackgroundTransparency = 1,
        Text = cleanUiText(displayLabel),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local valLbl = new("TextLabel", {
        Size = UDim2.new(0.44, -16, 0, 22),
        Position = UDim2.new(0.56, 0, 0, 3),
        BackgroundTransparency = 1,
        Text = fmtSliderValue(value),
        TextColor3 = T.White,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local bar = new("TextButton", {
        Size = UDim2.new(1, -24, 0, 10),
        Position = UDim2.new(0, 12, 0, 34),
        BackgroundColor3 = Color3.fromRGB(26,26,26),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(bar, 10)
    local fill = new("Frame", { Size = UDim2.new(0,0,1,0), BackgroundColor3 = T.White, BorderSizePixel = 0 }, bar)
    corner(fill, 10)
    local knob = new("Frame", { Size = UDim2.fromOffset(18,18), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0,0,0.5,0), BackgroundColor3 = T.White, BorderSizePixel = 0 }, bar)
    corner(knob, 10)
    stroke(knob, Color3.fromRGB(15,15,15), 1, 0.65)
    local dragging = false
    local function rounded(v)
        local mul = 10 ^ precision
        return math.floor(v * mul + 0.5) / mul
    end
    local function draw(call)
        local pct = 0
        if max ~= min then pct = (value - min) / (max - min) end
        pct = math.clamp(pct, 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = fmtSliderValue(value)
        if call and callback then task.spawn(function() pcall(callback, value) end) end
    end
    local function setFromX(x, call)
        local absPos = bar.AbsolutePosition.X
        local absSize = math.max(1, bar.AbsoluteSize.X)
        local pct = math.clamp((x - absPos) / absSize, 0, 1)
        value = rounded(min + (max - min) * pct)
        draw(call)
    end
    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X, true)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end
    trackConnection(bar.InputBegan:Connect(beginDrag))
    trackConnection(knob.InputBegan:Connect(beginDrag))
    trackConnection(fill.InputBegan:Connect(beginDrag))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and not UI.Unloaded and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X, true)
        end
    end))
    draw(false)
    return {
        Set = function(v, call) value = math.clamp(tonumber(v) or min, min, max); value = rounded(value); draw(call ~= false) end,
        Get = function() return value end,
    }
end

local function addInput(page, label, placeholder, default, callback)
    page = safePage(page)
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    new("TextLabel", {
        Size = UDim2.new(0.40, -16, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local box = new("TextBox", {
        Size = UDim2.new(0.60, -18, 0, 30),
        Position = UDim2.new(0.40, 8, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(25,25,25),
        BorderSizePixel = 0,
        Text = default or "",
        PlaceholderText = placeholder or "",
        TextColor3 = T.Text,
        PlaceholderColor3 = Color3.fromRGB(115,115,115),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ClearTextOnFocus = false,
    }, row)
    corner(box, 9); pad(box, 10, 10, 0, 0)
    trackConnection(box.FocusLost:Connect(function()
        if callback then task.spawn(function() pcall(callback, box.Text) end) end
    end))
    return box
end

local function tableFind(list, value)
    if table.find then return table.find(list, value) end
    for i, v in ipairs(list or {}) do
        if v == value then return i end
    end
    return nil
end

local dropdownZ = 10
local function addDropdown(page, label, options, default, multi, callback)
    page = safePage(page)
    options = options or {}
    local selected = {}
    local current = default
    if multi then
        if type(default) == "table" then
            for k, v in pairs(default) do if v == true then selected[k] = true elseif type(v) == "string" then selected[v] = true end end
        end
    end
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0, ClipsDescendants = false, ZIndex = dropdownZ }, page)
    corner(row, 12)
    new("TextLabel", {
        Size = UDim2.new(0.40, -16, 0, 42),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, row)
    local btn = new("TextButton", {
        Size = UDim2.new(0.60, -18, 0, 30),
        Position = UDim2.new(0.40, 8, 0, 6),
        BackgroundColor3 = Color3.fromRGB(25,25,25),
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = false,
        ClipsDescendants = true,
        ZIndex = dropdownZ + 1,
    }, row)
    corner(btn, 12)
    local btnText = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, btn)
    new("TextLabel", { Size = UDim2.fromOffset(24, 30), Position = UDim2.new(1, -28, 0, 0), BackgroundTransparency = 1, Text = "v", TextColor3 = T.Muted, Font = Enum.Font.GothamBold, TextSize = 12 }, btn)
    local list = new("ScrollingFrame", {
        Size = UDim2.new(0.60, -18, 0, 0),
        Position = UDim2.new(0.40, 8, 0, 40),
        BackgroundColor3 = Color3.fromRGB(21,21,21),
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(80,80,80),
        CanvasSize = UDim2.fromOffset(0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = dropdownZ + 2,
        ClipsDescendants = true,
    }, row)
    corner(list, 10); stroke(list, Color3.fromRGB(70,70,70), 1, 0.3)
    local layout = new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    pad(list, 6, 6, 6, 6)
    local function selectedText()
        if multi then
            local arr = {}
            for _, op in ipairs(options) do if selected[op] then arr[#arr + 1] = op end end
            if #arr == 0 then return "NONE" end
            for i, name in ipairs(arr) do arr[i] = cleanUiText(name) end
            if #arr <= 2 then return table.concat(arr, ", ") end
            return tostring(#arr) .. " SELECTED"
        else
            return cleanUiText((current == "Best owned" and "BEST OWNED") or current or options[1] or "SELECT")
        end
    end
    local function emit()
        btnText.Text = selectedText()
        if callback then
            if multi then
                local copy = {}
                for k, v in pairs(selected) do copy[k] = v end
                task.spawn(function() pcall(callback, copy) end)
            else
                task.spawn(function() pcall(callback, current) end)
            end
        end
    end
    local function rebuild()
        for _, ch in ipairs(list:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        for i, op in ipairs(options) do
            local item = new("TextButton", {
                Size = UDim2.new(1, -2, 0, 26),
                BackgroundColor3 = (multi and selected[op] or current == op) and Color3.fromRGB(230,230,230) or Color3.fromRGB(32,32,32),
                BorderSizePixel = 0,
                Text = (multi and (selected[op] and "✓ " or "") or "") .. cleanUiText(op),
                TextColor3 = (multi and selected[op] or current == op) and T.DarkText or T.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                LayoutOrder = i,
                AutoButtonColor = false,
                ZIndex = dropdownZ + 1,
            }, list)
            corner(item, 9)
            trackConnection(item.Activated:Connect(function()
                if multi then
                    selected[op] = not selected[op] or nil
                else
                    current = op
                    list.Visible = false
                end
                rebuild()
                emit()
                refreshCanvas(page)
            end))
        end
        task.defer(function()
            local h = math.min(132, layout.AbsoluteContentSize.Y + 10)
            list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
            if list.Visible then
                list.Size = UDim2.new(0.60, -20, 0, h)
            end
        end)
        btnText.Text = selectedText()
    end
    trackConnection(btn.Activated:Connect(function()
        list.Visible = not list.Visible
        dropdownZ = dropdownZ + 5
        row.ZIndex = dropdownZ
        btn.ZIndex = dropdownZ + 1
        list.ZIndex = dropdownZ + 2
        if list.Visible then
            local h = math.min(132, layout.AbsoluteContentSize.Y + 10)
            list.Size = UDim2.new(0.60, -20, 0, h)
        else
            list.Size = UDim2.new(0.60, -20, 0, 0)
        end
    end))
    rebuild()
    if not multi and not current then current = options[1] end
    btnText.Text = selectedText()
    return {
        SetOptions = function(newOptions)
            options = newOptions or {}
            if not multi and current and not tableFind(options, current) then current = options[1] end
            rebuild(); emit()
        end,
        Get = function() return multi and selected or current end,
        Set = function(v, call)
            if multi then
                selected = {}
                if type(v) == "table" then for k, val in pairs(v) do if val == true then selected[k] = true elseif type(val) == "string" then selected[val] = true end end end
            else current = v end
            rebuild(); if call ~= false then emit() end
        end,
    }
end

-- Tabs
createTab("DASHBOARD", 1)
createTab("FARM", 2)
createTab("BOOSTS", 3)
createTab("SHOP", 4)
createTab("PETS_CRATES", 6)
createTab("ESP", 7)
createTab("EVENTS", 8)
createTab("MAILBOX", 9)
createTab("STEAL", 10)
createTab("VISUALS", 11)
createTab("PROTECT", 12)
createTab("SETTINGS", 13)

-- DASHBOARD
addSection(UI.Pages["DASHBOARD"], "STATUS")
UI.plotLabel = addLabel(UI.Pages["DASHBOARD"], "GARDEN: ?")
UI.cashLabel = addLabel(UI.Pages["DASHBOARD"], "SHECKLES: ? · TOKENS: ?")
UI.totalValueLabel = addLabel(UI.Pages["DASHBOARD"], "TOTAL VALUE: ?")
UI.priceRefreshLabel = addLabel(UI.Pages["DASHBOARD"], "PRICE REFRESH: ?")
UI.statLabel = addLabel(UI.Pages["DASHBOARD"], "BOUGHT 0 · PLANTED 0 · HARVESTED 0 · SOLD 0 (+0)")
UI.extraStatLabel = addLabel(UI.Pages["DASHBOARD"], "SPRINKLERS 0 · WATERED 0 · TAMED 0 · OPENED 0 · STOLEN 0")
UI.seedEventAvailableLabel = addLabel(UI.Pages["DASHBOARD"], "EVENT READY: NONE")
UI.seedEventClaimedLabel = addLabel(UI.Pages["DASHBOARD"], "EVENT CLAIMED: RAINBOW 0 · GOLD 0 · TOTAL 0")
UI.seedEventLastLabel = addLabel(UI.Pages["DASHBOARD"], "LAST EVENT CLAIM: NONE")
UI.uptimeLabel = addLabel(UI.Pages["DASHBOARD"], "UPTIME: 0S")
UI.afkStatusLabel = addLabel(UI.Pages["DASHBOARD"], "AFK: READY")
UI.serverStatusLabel = addLabel(UI.Pages["DASHBOARD"], "SERVER: STABLE")
UI.webhookStatusLabel = addLabel(UI.Pages["DASHBOARD"], "WEBHOOK: OFF")
UI.progressRateLabel = addLabel(UI.Pages["DASHBOARD"], "SHECKLES/MIN: 0 · HARVEST/MIN: 0")
UI.lastSellLabel = addLabel(UI.Pages["DASHBOARD"], "SELL VALUE LAST: 0")
UI.bestPetLabel = addLabel(UI.Pages["DASHBOARD"], "BEST PET EQUIPPED: NONE")
UI.weatherDashLabel = addLabel(UI.Pages["DASHBOARD"], "ACTIVE WEATHER: NONE")
UI.shopDashLabel = addLabel(UI.Pages["DASHBOARD"], "SHOP STOCK: ?")
UI.wildPetDashLabel = addLabel(UI.Pages["DASHBOARD"], "WILD PET FOUND: NONE")
UI.nextHopLabel = addLabel(UI.Pages["DASHBOARD"], "NEXT SERVER HOP: OFF")
-- FARM
addSection(UI.Pages["FARM"], "MASTER")
addToggle(UI.Pages["FARM"], "AUTO FARM", S.autoFarm, function(v) S.autoFarm = v end)
addToggle(UI.Pages["FARM"], "AUTO EXPAND", S.autoExpand, function(v) S.autoExpand = v end)
addSection(UI.Pages["FARM"], "PLANT & HARVEST")
local plantOptions = { "BEST OWNED" }; for _, n in ipairs(SEED_NAMES) do plantOptions[#plantOptions + 1] = n end
addDropdown(UI.Pages["FARM"], "SEEDS TO PLANT", plantOptions, S.plantSeeds, true, function(sel)
    if type(S.plantSeeds) ~= "table" then S.plantSeeds = {} end
    pickMulti(sel, S.plantSeeds)
    local hasSpecific = false
    for name, enabled in pairs(S.plantSeeds) do
        if enabled == true and name ~= "BEST OWNED" and name ~= "Best owned" then hasSpecific = true; break end
    end
    S.plantSeed = hasSpecific and "Selected" or "Best owned"
end)
addToggle(UI.Pages["FARM"], "AUTO PLANT", S.autoPlant, function(v) S.autoPlant = v end)
addSlider(UI.Pages["FARM"], "PLANT DISTANCE", 2, 10, S.plantSpacing, 0, function(v) S.plantSpacing = v end)
addToggle(UI.Pages["FARM"], "AUTO HARVEST", S.autoHarvest, function(v) S.autoHarvest = v end)
addToggle(UI.Pages["FARM"], "AUTO HARVEST ALL", S.harvestAll, function(v) S.harvestAll = v end)
addDropdown(UI.Pages["FARM"], "HARVEST FRUIT TARGETS", SEED_NAMES, S.harvestFruitTargets, true, function(sel)
    pickMulti(sel, S.harvestFruitTargets)
    if HaimiyachGAG2_HasSelection(S.harvestFruitTargets) then S.harvestAll = false end
end)
addDropdown(UI.Pages["FARM"], "HARVEST KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.harvestKeepMutations, true, function(sel) pickMulti(sel, S.harvestKeepMutations) end)
addDropdown(UI.Pages["FARM"], "HARVEST WEIGHT FILTER", KG_MODE_OPTIONS, S.harvestKgMode, false, function(v) S.harvestKgMode = v end)
addSlider(UI.Pages["FARM"], "HARVEST WEIGHT VALUE", 0, 500, S.harvestKgValue, 1, function(v) S.harvestKgValue = v end)
addSlider(UI.Pages["FARM"], "HARVEST DELAY (SEC)", 0, 0.2, S.harvestDelay, 3, function(v) S.harvestDelay = v end)
addToggle(UI.Pages["FARM"], "AUTO POT PLANTS", S.autoPot, function(v) S.autoPot = v end)

-- AUTO
addSection(UI.Pages["FARM"], "SELL WHEN FULL")
addToggle(UI.Pages["FARM"], "AUTO SELL WHEN FULL", S.autoSell, function(v) S.autoSell = v end)
addSlider(UI.Pages["FARM"], "SELL DELAY (SEC)", 3, 120, S.sellInterval, 0, function(v) S.sellInterval = v end)
addDropdown(UI.Pages["FARM"], "SELL KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.sellKeepMutations, true, function(sel) pickMulti(sel, S.sellKeepMutations) end)
addDropdown(UI.Pages["FARM"], "SELL KEEP WEIGHT FILTER", KG_MODE_OPTIONS, S.sellKeepKgMode, false, function(v) S.sellKeepKgMode = v end)
addSlider(UI.Pages["FARM"], "SELL KEEP WEIGHT VALUE", 0, 500, S.sellKeepKgValue, 1, function(v) S.sellKeepKgValue = v end)
addSection(UI.Pages["EVENTS"], "WEATHER")
UI.activeWeatherLabel = addLabel(UI.Pages["EVENTS"], "ACTIVE WEATHER: NONE")
UI.weatherTimeLabel = addLabel(UI.Pages["EVENTS"], "WEATHER TIME LEFT: NONE")
UI.weatherMachineLabel = addLabel(UI.Pages["EVENTS"], "WEATHER MACHINE: ?")
addDropdown(UI.Pages["EVENTS"], "RARE WEATHER NOTIFY", HaimiyachGAG2_WeatherNames(), S.rareWeatherTargets, true, function(sel)
    if type(S.rareWeatherTargets) ~= "table" then S.rareWeatherTargets = {} end
    pickMulti(sel, S.rareWeatherTargets)
    saveConfig(true)
end)
addToggle(UI.Pages["EVENTS"], "NOTIFY RARE WEATHER", S.notifyRareWeather, function(v) S.notifyRareWeather = v; saveConfig(true) end)

addSection(UI.Pages["EVENTS"], "SEED EVENTS")
addToggle(UI.Pages["EVENTS"], "AUTO CLAIM EVENT SEEDS", S.autoClaimSeedEvent, function(v) S.autoClaimSeedEvent = v end)
addToggle(UI.Pages["EVENTS"], "USE FLY TO EVENT", S.claimUseFly, function(v) S.claimUseFly = v end)
addSlider(UI.Pages["EVENTS"], "EVENT CLAIM DELAY (SEC)", 3, 60, S.seedEventDelay, 0, function(v) S.seedEventDelay = v end)
addSection(UI.Pages["EVENTS"], "DAILY DEALS")
addToggle(UI.Pages["EVENTS"], "AUTO DAILY CLAIM", S.autoDaily, function(v) S.autoDaily = v end)
addSlider(UI.Pages["EVENTS"], "DAILY CLAIM DELAY (SEC)", 10, 300, S.dailyDelay, 0, function(v) S.dailyDelay = v end)
addSection(UI.Pages["FARM"], "SHOVEL")
addToggle(UI.Pages["FARM"], "AUTO SHOVEL PLANTS", S.autoShovelPlants, function(v) S.autoShovelPlants = v end)
addDropdown(UI.Pages["FARM"], "SHOVEL PLANT TARGETS", SEED_NAMES, S.shovelPlantTargets, true, function(sel) pickMulti(sel, S.shovelPlantTargets) end)
addToggle(UI.Pages["FARM"], "AUTO SHOVEL FRUITS", S.autoShovelFruits, function(v) S.autoShovelFruits = v end)
addDropdown(UI.Pages["FARM"], "SHOVEL FRUIT TARGETS", SEED_NAMES, S.shovelFruitTargets, true, function(sel) pickMulti(sel, S.shovelFruitTargets) end)
addDropdown(UI.Pages["FARM"], "SHOVEL KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.shovelKeepMutations, true, function(sel) pickMulti(sel, S.shovelKeepMutations) end)
addDropdown(UI.Pages["FARM"], "SHOVEL WEIGHT FILTER", KG_MODE_OPTIONS, S.shovelKgMode, false, function(v) S.shovelKgMode = v end)
addSlider(UI.Pages["FARM"], "SHOVEL WEIGHT VALUE", 0, 500, S.shovelKgValue, 1, function(v) S.shovelKgValue = v end)
addSlider(UI.Pages["FARM"], "SHOVEL DELAY (SEC)", 1, 30, S.shovelDelay, 0, function(v) S.shovelDelay = v end)
addSection(UI.Pages["FARM"], "TROWEL")
addToggle(UI.Pages["FARM"], "AUTO TROWEL PLANTS", S.autoTrowelPlants, function(v) S.autoTrowelPlants = v end)
addDropdown(UI.Pages["FARM"], "TROWEL PLANT TARGETS", SEED_NAMES, S.trowelPlantTargets, true, function(sel) pickMulti(sel, S.trowelPlantTargets) end)
addDropdown(UI.Pages["FARM"], "TROWEL POSITION", { "MAPPING", "AVATAR POSITION" }, S.trowelPositionMode, false, function(v) S.trowelPositionMode = v or "MAPPING" end)
addSlider(UI.Pages["FARM"], "TROWEL DELAY (SEC)", 1, 30, S.trowelDelay, 0, function(v) S.trowelDelay = v end)
addSection(UI.Pages["FARM"], "INVENTORY FAVORITE")
addToggle(UI.Pages["FARM"], "AUTO FAVORITE FRUITS", S.autoFavoriteFruits, function(v) S.autoFavoriteFruits = v end)
addDropdown(UI.Pages["FARM"], "FAVORITE FRUIT TARGETS", SEED_NAMES, S.favoriteFruitTargets, true, function(sel) pickMulti(sel, S.favoriteFruitTargets) end)
addDropdown(UI.Pages["FARM"], "FAVORITE MUTATIONS", HaimiyachGAG2_MutationNames, S.favoriteMutations, true, function(sel) pickMulti(sel, S.favoriteMutations) end)
addDropdown(UI.Pages["FARM"], "FAVORITE WEIGHT FILTER", KG_MODE_OPTIONS, S.favoriteKgMode, false, function(v) S.favoriteKgMode = v end)
addSlider(UI.Pages["FARM"], "FAVORITE WEIGHT VALUE", 0, 500, S.favoriteKgValue, 1, function(v) S.favoriteKgValue = v end)
addToggle(UI.Pages["FARM"], "UNFAVORITE NOT MATCHING", S.unfavoriteNotMatching, function(v) S.unfavoriteNotMatching = v end)
addSlider(UI.Pages["FARM"], "FAVORITE DELAY (SEC)", 1, 30, S.favoriteDelay, 0, function(v) S.favoriteDelay = v end)
addButton(UI.Pages["FARM"], "FAVORITE INVENTORY NOW", function()
    local n = HaimiyachGAG2_AutoFavoriteStep()
    notify("Inventory Favorite", tostring(n) .. " item updated", 3)
end)

-- BOOSTS
addSection(UI.Pages["BOOSTS"], "SPRINKLER & WATER")
addToggle(UI.Pages["BOOSTS"], "AUTO PLACE SPRINKLERS", S.autoSprinkler, function(v) S.autoSprinkler = v end)
addDropdown(UI.Pages["BOOSTS"], "SELECTED SPRINKLERS", HaimiyachGAG2_SprinklerOptions(), S.sprinklerTargets, true, function(sel)
    pickMulti(sel, S.sprinklerTargets)
end)
addDropdown(UI.Pages["BOOSTS"], "SPRINKLER TARGET", { "GARDEN CENTER", "AVATAR POSITION", "MAPPING" }, S.sprinklerTargetMode, false, function(v) S.sprinklerTargetMode = v or "GARDEN CENTER" end)
addSlider(UI.Pages["BOOSTS"], "SPRINKLER DELAY (SEC)", 10, 900, S.sprinklerInterval, 0, function(v) S.sprinklerInterval = v end)
addToggle(UI.Pages["BOOSTS"], "AUTO WATERING CAN", S.autoWater, function(v) S.autoWater = v end)
addSlider(UI.Pages["BOOSTS"], "WATER DELAY (SEC)", 2, 60, S.waterInterval, 0, function(v) S.waterInterval = v end)
addSection(UI.Pages["BOOSTS"], "SKILL POINTS")
addDropdown(UI.Pages["BOOSTS"], "STATS TO LEVEL", { "BaseSpeed", "BaseJump", "ShovelPower", "MaxBackpack" }, S.skillStats, true, function(sel) pickMulti(sel, S.skillStats) end)
addToggle(UI.Pages["BOOSTS"], "AUTO SPEND SKILL POINTS", S.autoSkill, function(v) S.autoSkill = v end)


-- PETS
addSection(UI.Pages["PETS_CRATES"], "PETS")
addDropdown(UI.Pages["PETS_CRATES"], "BEST PET MODE", { "FARM", "STEAL", "PROTECT", "VALUE" }, S.bestPetMode or "FARM", false, function(v)
    S.bestPetMode = tostring(v or "FARM")
    saveConfig(true)
end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO EQUIP PETS", S.autoEquipPets, function(v) S.autoEquipPets = v end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO BUY PET SLOTS", S.autoPetSlot, function(v) S.autoPetSlot = v end)

addSection(UI.Pages["PETS_CRATES"], "WILD PETS")
UI.worldPetDrop = addDropdown(UI.Pages["PETS_CRATES"], "WILD PET NAME FILTER", HaimiyachGAG2_WorldPetNames(), S.buyWorldPets, true, function(sel)
    if type(S.buyWorldPets) ~= "table" then S.buyWorldPets = {} end
    pickMulti(sel, S.buyWorldPets)
    saveConfig(true)
end)
addDropdown(UI.Pages["PETS_CRATES"], "WILD PET RARITY FILTER", HaimiyachGAG2_RarityOptions, S.wildPetRarities, true, function(sel)
    if type(S.wildPetRarities) ~= "table" then S.wildPetRarities = {} end
    pickMulti(sel, S.wildPetRarities)
    saveConfig(true)
end)
addToggle(UI.Pages["PETS_CRATES"], "ONLY UNOWNED WILD PET", S.wildPetOnlyUnowned, function(v) S.wildPetOnlyUnowned = v; saveConfig(true) end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO TAME WILD PET", S.autoBuyPets, function(v) S.autoBuyPets = v; saveConfig(true) end)
addToggle(UI.Pages["PETS_CRATES"], "TELEPORT TO PET", S.petTeleport, function(v) S.petTeleport = v end)
addSlider(UI.Pages["PETS_CRATES"], "PET BUY DELAY (SEC)", 2, 60, S.petBuyInterval, 0, function(v) S.petBuyInterval = v end)
addSection(UI.Pages["PETS_CRATES"], "SELL PETS")
UI.petDrop = addDropdown(UI.Pages["PETS_CRATES"], "PETS TO SELL", ownedPetNames(), S.sellPets, true, function(sel) pickMulti(sel, S.sellPets) end)
addButton(UI.Pages["PETS_CRATES"], "REFRESH PET LIST", function() UI.petDrop.SetOptions(ownedPetNames()) end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO SELL SELECTED PETS", S.autoSellPets, function(v) S.autoSellPets = v end)

-- OPEN
addSection(UI.Pages["PETS_CRATES"], "OPEN ITEMS")
addToggle(UI.Pages["PETS_CRATES"], "AUTO OPEN EGGS", S.autoEgg, function(v) S.autoEgg = v end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO OPEN CRATES", S.autoCrate, function(v) S.autoCrate = v end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO OPEN SEED PACKS", S.autoPack, function(v) S.autoPack = v end)
addSlider(UI.Pages["PETS_CRATES"], "OPEN DELAY (SEC)", 1, 30, S.openInterval, 0, function(v) S.openInterval = v end)

-- SHOP
addSection(UI.Pages["SHOP"], "SEED SHOP")
addDropdown(UI.Pages["SHOP"], "SEEDS TO BUY", SEED_NAMES, S.buySeeds, true, function(sel) pickMulti(sel, S.buySeeds) end)
addToggle(UI.Pages["SHOP"], "AUTO BUY SEEDS", S.autoBuy, function(v) S.autoBuy = v end)
addToggle(UI.Pages["SHOP"], "AUTO BUY ALL SEEDS", S.autoBuyAllSeeds, function(v) S.autoBuyAllSeeds = v end)
addSlider(UI.Pages["SHOP"], "SEED BUY DELAY (SEC)", 1, 30, S.buyInterval, 0, function(v) S.buyInterval = v end)
addSlider(UI.Pages["SHOP"], "MAX BUYS PER SEED", 1, 50, S.buyPerTick, 0, function(v) S.buyPerTick = v end)
addSection(UI.Pages["SHOP"], "GEAR SHOP")
addDropdown(UI.Pages["SHOP"], "GEAR TO BUY", GEAR_NAMES, S.gearBuy, true, function(sel) pickMulti(sel, S.gearBuy) end)
addToggle(UI.Pages["SHOP"], "AUTO BUY GEAR", S.autoGear, function(v) S.autoGear = v end)
addToggle(UI.Pages["SHOP"], "AUTO BUY ALL GEAR", S.autoBuyAllGear, function(v) S.autoBuyAllGear = v end)
addSlider(UI.Pages["SHOP"], "GEAR BUY DELAY (SEC)", 2, 60, S.gearInterval, 0, function(v) S.gearInterval = v end)

-- CRATE SHOP
addSection(UI.Pages["SHOP"], "CRATE SHOP")
UI.crateBuyDrop = addDropdown(UI.Pages["SHOP"], "CRATES TO BUY", HaimiyachGAG2_CrateNames(), S.buyCrates, true, function(sel)
    if type(S.buyCrates) ~= "table" then S.buyCrates = {} end
    pickMulti(sel, S.buyCrates)
    saveConfig(true)
end)
addButton(UI.Pages["SHOP"], "REFRESH CRATE LIST", function()
    if UI.crateBuyDrop and UI.crateBuyDrop.SetOptions then UI.crateBuyDrop.SetOptions(HaimiyachGAG2_CrateNames()) end
end)
addToggle(UI.Pages["SHOP"], "AUTO BUY SELECTED CRATES", S.autoBuyCrates, function(v)
    S.autoBuyCrates = v
    if not v then HaimiyachGAG2_HideCrateShopGui() end
    saveConfig(true)
end)
addButton(UI.Pages["SHOP"], "BUY SELECTED CRATES NOW", function()
    HaimiyachGAG2_ManualCrateBuyNow = true
    HaimiyachGAG2_BuySelectedCratesOnce()
    HaimiyachGAG2_ManualCrateBuyNow = false
end)
addSlider(UI.Pages["SHOP"], "CRATE BUY DELAY (SEC)", 2, 60, S.crateBuyDelay or 5, 0, function(v)
    S.crateBuyDelay = v
    saveConfig(true)
end)

-- STEAL
addSection(UI.Pages["STEAL"], "STEAL")
addToggle(UI.Pages["STEAL"], "AUTO STEAL RIPE FRUIT", S.autoSteal, function(v) S.autoSteal = v end)
addToggle(UI.Pages["STEAL"], "TELEPORT TO FRUIT", S.stealTeleport, function(v) S.stealTeleport = v end)
addToggle(UI.Pages["STEAL"], "RETURN TO BASE", S.stealReturnBase, function(v) S.stealReturnBase = v end)
addSlider(UI.Pages["STEAL"], "STEAL WAIT TIME (SEC)", 0, 1, S.stealDelay, 2, function(v) S.stealDelay = v end)

-- MISC
addSection(UI.Pages["SETTINGS"], "SERVER")
addToggle(UI.Pages["SETTINGS"], "ANTI AFK", S.antiAfk, function(v) S.antiAfk = v end)
addToggle(UI.Pages["SETTINGS"], "AUTO SERVER HOP", S.autoHop, function(v) S.autoHop = v; saveConfig(true) end)
addDropdown(UI.Pages["SETTINGS"], "SMART HOP CONDITIONS", HaimiyachGAG2_HopConditionOptions, S.hopConditions, true, function(sel)
    if type(S.hopConditions) ~= "table" then S.hopConditions = {} end
    pickMulti(sel, S.hopConditions)
    saveConfig(true)
end)
addSlider(UI.Pages["SETTINGS"], "SERVER HOP DELAY (MIN)", 0, 120, S.hopInterval / 60, 0, function(v) S.hopInterval = v * 60; saveConfig(true) end)
addToggle(UI.Pages["SETTINGS"], "AUTO RECONNECT", S.autoReconnect, function(v) S.autoReconnect = v; saveConfig(true) end)
addSlider(UI.Pages["SETTINGS"], "RECONNECT DELAY (SEC)", 3, 60, S.reconnectDelay, 0, function(v) S.reconnectDelay = v; saveConfig(true) end)
addToggle(UI.Pages["SETTINGS"], "AUTO EXECUTE AFTER HOP", S.autoExecute, function(v)
    S.autoExecute = v
    saveConfig(true)
    if v then
        local ok, err = writeAutoExecuteLoader()
        notify("HAIMIYACH HUB", ok and "Auto execute loader saved." or ("Auto execute loader failed: " .. tostring(err)), 4)
    end
end)
addInput(UI.Pages["SETTINGS"], "LOADER URL", "raw loader url", S.autoExecuteUrl, function(text)
    S.autoExecuteUrl = tostring(text or "")
    saveConfig(true)
    if S.autoExecute then
        pcall(writeAutoExecuteLoader)
    end
end)
addSection(UI.Pages["SETTINGS"], "CODES")
addInput(UI.Pages["SETTINGS"], "REDEEM CODE", "enter code", "", function(text) S.codeText = text or "" end)
addButton(UI.Pages["SETTINGS"], "REDEEM CODE NOW", function()
    local code = S.codeText or ""
    if code ~= "" then
        local ok, res = fire("Settings.SubmitCode", code)
        notify("Code", ok and "Redeem request sent" or tostring(res or "Failed"), 3)
    end
end)
addToggle(UI.Pages["SETTINGS"], "AUTO REDEEM CODE LIST", S.autoCodes, function(v) S.autoCodes = v end)

-- ESP
addSection(UI.Pages["ESP"], "GARDEN ESP")
addMiniNote(UI.Pages["ESP"], "Turn off FPS BOOST before using ESP.")
addToggle(UI.Pages["ESP"], "ESP FRUITS", S.espGardenFruit, function(v) GardenESP.set(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "ESP GROWING FRUITS", S.espGardenGrowing, function(v) GardenESP.setGrowing(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "GARDEN VALUE", S.espGardenValue, function(v) GardenESP.setValue(v); saveConfig(true) end)

addSection(UI.Pages["ESP"], "BACKPACK ESP")
addToggle(UI.Pages["ESP"], "ESP BACKPACK FRUIT", S.espBackpackFruit, function(v) BackpackESP.set(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "BACKPACK VALUE", S.espBackpackValue, function(v) BackpackESP.setValue(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "TOTAL VALUE", S.espBackpackTotal, function(v) BackpackESP.setTotal(v); saveConfig(true) end)

addSection(UI.Pages["ESP"], "WILD PET ESP")
addDropdown(UI.Pages["ESP"], "WILD PET DETAILS", HaimiyachGAG2_WildPetDetailOptions, S.espWildPetDetails, true, function(sel)
    if type(S.espWildPetDetails) ~= "table" then S.espWildPetDetails = {} end
    pickMulti(sel, S.espWildPetDetails)
    saveConfig(true)
end)
addToggle(UI.Pages["ESP"], "WILD PET ESP", S.espWildPet, function(v)
    S.espWildPet = v
    if not v then HaimiyachGAG2_ClearWildPetESP() end
    saveConfig(true)
end)

-- PROTECT
addSection(UI.Pages["PROTECT"], "AVATAR PROTECTION")
addToggle(UI.Pages["PROTECT"], "NO CLIP", S.protectNoClip, function(v) S.protectNoClip = v end)
addToggle(UI.Pages["PROTECT"], "ANTI FLING", S.protectAntiFling, function(v) S.protectAntiFling = v end)
addToggle(UI.Pages["PROTECT"], "ANTI RAGDOLL", S.protectAntiRagdoll, function(v) S.protectAntiRagdoll = v end)
addToggle(UI.Pages["PROTECT"], "ANTI KNOCKBACK", S.protectAntiKnockback, function(v) S.protectAntiKnockback = v end)
addToggle(UI.Pages["PROTECT"], "ANTI SIT", S.protectAntiSit, function(v) S.protectAntiSit = v end)
addToggle(UI.Pages["PROTECT"], "ANTI VOID", S.protectAntiVoid, function(v) S.protectAntiVoid = v end)
addSlider(UI.Pages["PROTECT"], "VELOCITY LIMIT", 25, 250, S.protectVelocityLimit, 0, function(v) S.protectVelocityLimit = v end)
addSlider(UI.Pages["PROTECT"], "VOID HEIGHT", -150, 0, S.protectVoidY, 0, function(v) S.protectVoidY = v end)
addButton(UI.Pages["PROTECT"], "RESET CHARACTER VELOCITY NOW", function()
    local n = HaimiyachGAG2_ResetOwnVelocity(false)
    notify("Protect", "Velocity reset on " .. tostring(n) .. " parts.", 3)
end)


-- MAILBOX
addSection(UI.Pages["MAILBOX"], "AUTO CLAIM MAIL / GIFT")
addToggle(UI.Pages["MAILBOX"], "AUTO CLAIM MAILBOX", S.autoMail, function(v) S.autoMail = v; saveConfig(true) end)
addToggle(UI.Pages["MAILBOX"], "AUTO ACCEPT GIFTS", S.autoAcceptGift, function(v) S.autoAcceptGift = v; saveConfig(true) end)
addSection(UI.Pages["MAILBOX"], "SEND MAIL BY USERNAME")
addInput(UI.Pages["MAILBOX"], "MAIL TARGET USERNAME", "username", S.mailTargetUsername or "", function(v)
    S.mailTargetUsername = tostring(v or "")
    saveConfig(true)
end)
addInput(UI.Pages["MAILBOX"], "MAIL NOTE", "optional note", S.mailNote or "", function(v)
    S.mailNote = tostring(v or "")
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "SEEDS TO SEND", SEED_NAMES, S.mailSeedTargets, true, function(sel)
    if type(S.mailSeedTargets) ~= "table" then S.mailSeedTargets = {} end
    pickMulti(sel, S.mailSeedTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "FRUITS TO SEND", SEED_NAMES, S.mailFruitTargets, true, function(sel)
    if type(S.mailFruitTargets) ~= "table" then S.mailFruitTargets = {} end
    pickMulti(sel, S.mailFruitTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "GEAR TO SEND", HaimiyachGAG2_MailGearOptionNames(), S.mailGearTargets, true, function(sel)
    if type(S.mailGearTargets) ~= "table" then S.mailGearTargets = {} end
    pickMulti(sel, S.mailGearTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "PETS TO SEND", HaimiyachGAG2_WorldPetNames(), S.mailPetTargets, true, function(sel)
    if type(S.mailPetTargets) ~= "table" then S.mailPetTargets = {} end
    pickMulti(sel, S.mailPetTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "CRATES TO SEND", HaimiyachGAG2_CrateNames(), S.mailCrateTargets, true, function(sel)
    if type(S.mailCrateTargets) ~= "table" then S.mailCrateTargets = {} end
    pickMulti(sel, S.mailCrateTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "SEED PACKS TO SEND", HaimiyachGAG2_SeedPackNames(), S.mailSeedPackTargets, true, function(sel)
    if type(S.mailSeedPackTargets) ~= "table" then S.mailSeedPackTargets = {} end
    pickMulti(sel, S.mailSeedPackTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "PROPS TO SEND", HaimiyachGAG2_PropNames(), S.mailPropTargets, true, function(sel)
    if type(S.mailPropTargets) ~= "table" then S.mailPropTargets = {} end
    pickMulti(sel, S.mailPropTargets)
    saveConfig(true)
end)
addSlider(UI.Pages["MAILBOX"], "MAIL COUNT PER ITEM", 1, 20, S.mailSendCount, 0, function(v)
    S.mailSendCount = v
    saveConfig(true)
end)
addSlider(UI.Pages["MAILBOX"], "MAIL SEND DELAY (SEC)", 5, 300, S.mailSendDelay, 0, function(v)
    S.mailSendDelay = v
    saveConfig(true)
end)
addButton(UI.Pages["MAILBOX"], "SEND SELECTED MAIL NOW", function()
    HaimiyachGAG2_SendSelectedMailNow(true)
end)
addToggle(UI.Pages["MAILBOX"], "AUTO SEND SELECTED MAIL", S.autoSendMail, function(v)
    S.autoSendMail = v
    saveConfig(true)
end)

-- VISUALS
addSection(UI.Pages["VISUALS"], "PERFORMANCE")
UI.visualPerfLabel = addLabel(UI.Pages["VISUALS"], "FPS: ?\nPING: ?")
addToggle(UI.Pages["VISUALS"], "BLACK SCREEN", S.blankScreen, function(v)
    SetBlankScreenEnabled(v)
    saveConfig(true)
end)
addDropdown(UI.Pages["VISUALS"], "FPS BOOST MODE", { "LIGHT", "BALANCED", "ULTRA" }, S.fpsBoostMode or "BALANCED", false, function(v)
    S.fpsBoostMode = NormalizeFPSBoostMode(v)
    if S.fpsBoost then SetFPSBoostEnabled(true) end
    saveConfig(true)
end)
UI.fpsBoostToggle = nil
UI.highGraphicsToggle = nil
UI.fpsBoostToggle = addToggle(UI.Pages["VISUALS"], "FPS BOOST", S.fpsBoost, function(v)
    S.fpsBoost = v
    SetFPSBoostEnabled(v)
    if v and UI.highGraphicsToggle then
        UI.highGraphicsToggle.Set(false, false)
    end
end)
UI.highGraphicsToggle = addToggle(UI.Pages["VISUALS"], "HIGH GRAPHICS", S.highGraphics, function(v)
    S.highGraphics = v
    SetHighGraphicsEnabled(v)
    if v and UI.fpsBoostToggle then
        UI.fpsBoostToggle.Set(false, false)
    end
end)

addSection(UI.Pages["VISUALS"], "CUTSCENE")
addToggle(UI.Pages["VISUALS"], "DISABLE CUTSCENE", S.disableCutscene, function(v) SetCutsceneDisabled(v); saveConfig(true) end)

if S.fpsBoost then SetFPSBoostEnabled(true) end
if S.highGraphics then SetHighGraphicsEnabled(true) end
if S.blankScreen then SetBlankScreenEnabled(true) end
if S.espGardenFruit then GardenESP.set(true) end
if S.espGardenGrowing then GardenESP.setGrowing(true) end
if S.espBackpackFruit then BackpackESP.set(true) end
if S.espBackpackTotal then BackpackESP.setTotal(true) end
if S.espWildPet then HaimiyachGAG2_UpdateWildPetESP() end

-- SETTINGS
addSection(UI.Pages["SETTINGS"], "UI")
addSlider(UI.Pages["SETTINGS"], "UI SCALE", 0.6, 1.4, UI.Scale, 2, function(v)
    UI.Scale = v
    S.uiScale = v
    UIScaleObj.Scale = v
    if UI.Minimized then
        MiniBar.Size = UDim2.fromOffset(math.floor((390 * UI.Scale) + 0.5), math.floor((44 * UI.Scale) + 0.5))
    end
end)
addSection(UI.Pages["SETTINGS"], "WINDOW")
addDropdown(UI.Pages["SETTINGS"], "UI KEYBIND", { "LeftControl", "RightControl", "LeftAlt", "RightAlt", "RightShift", "K", "F" }, S.uiKeybindName or "LeftControl", false, function(v)
    S.uiKeybindName = tostring(v or "LeftControl")
    local kc = Enum.KeyCode[S.uiKeybindName]
    if kc then UI.Keybind = kc end
end)
addButton(UI.Pages["SETTINGS"], "MINIMIZE UI", function() setMinimized(true) end)
addButton(UI.Pages["SETTINGS"], "HIDE UI", function() setVisible(false) end)
addButton(UI.Pages["SETTINGS"], "RESET UI SETTINGS", function()
    UI.Scale = isMobile and 0.88 or 1
    S.uiScale = UI.Scale
    S.uiKeybindName = "LeftControl"
    UI.Keybind = Enum.KeyCode.LeftControl
    UIScaleObj.Scale = UI.Scale
    setMinimized(false)
    Main.Position = UDim2.new(0.5, -baseW/2, 0.5, -baseH/2)
end)
addSection(UI.Pages["SETTINGS"], "CONFIG")
addButton(UI.Pages["SETTINGS"], "SAVE CONFIG", function() saveConfig(false) end)
addButton(UI.Pages["SETTINGS"], "LOAD CONFIG", function() loadConfig(false) end)
addSection(UI.Pages["SETTINGS"], "WEBHOOK")
addInput(UI.Pages["SETTINGS"], "WEBHOOK URL", "https://discord.com/api/webhooks/...", S.webhookUrl, function(text) S.webhookUrl = text or ""; saveConfig(true) end)
addToggle(UI.Pages["SETTINGS"], "ENABLE REPORTS", S.webhookEnabled, function(v)
    S.webhookEnabled = v
    saveConfig(true)
    if v then task.spawn(function() task.wait(0.5); sendWebhook(false) end) end
end)
addToggle(UI.Pages["SETTINGS"], "DISCONNECT WEBHOOK", S.webhookDisconnect, function(v) S.webhookDisconnect = v; saveConfig(true) end)
addSlider(UI.Pages["SETTINGS"], "REPORT DELAY (MIN)", 1, 60, S.webhookInterval / 60, 0, function(v) S.webhookInterval = v * 60; saveConfig(true) end)
addButton(UI.Pages["SETTINGS"], "SEND TEST REPORT", function() task.spawn(function() sendWebhook(true) end) end)
addButton(UI.Pages["SETTINGS"], "SEND DISCONNECT TEST", function()
    task.spawn(function()
        if HaimiyachGAG2_ResetDisconnectWebhook then HaimiyachGAG2_ResetDisconnectWebhook() else DisconnectWebhookSent = false end
        sendDisconnectWebhook("TEST DISCONNECT", "Manual test from HAIMIYACH HUB settings.", true)
    end)
end)
addButton(UI.Pages["SETTINGS"], "UNLOAD HUB", function()
    S.killed = true
    UI.Unloaded = true
    pcall(function() SetCutsceneDisabled(false, true) end)
    pcall(RestoreDefaultGraphics)
    pcall(HaimiyachGAG2_ClearWildPetESP)
    if fpsConnection then pcall(function() fpsConnection:Disconnect() end) end
    disconnectUiConnections()
    cleanContainer(PlayerGui)
    cleanContainer(CoreGui)
end)

-- AUTO CLAIM SEED EVENT loop
loopOn(function() return S.autoClaimSeedEvent end, function() return math.max(3, tonumber(S.seedEventDelay) or 3) end, function()
    claimSeedEvent()
end)

-- AUTO POT loop (own grown plants flagged via prompt tag is rare; pot all listed plants)
loopOn(function() return S.autoPot end, 10, function()
    local plot = myPlot(); local plants = plot and plot:FindFirstChild("Plants")
    if not plants then return end
    for _, m in ipairs(plants:GetChildren()) do
        if not S.autoPot then break end
        local pid = m:GetAttribute("PlantId") or m.Name
        if pid then fire("Garden.PotPlant", tostring(pid)); task.wait(0.3) end
    end
end)

local function getPriceRefreshText()
    local ok, txt = pcall(function()
        if GardenESP and type(GardenESP.ensureFruitStock) == "function" then
            GardenESP.ensureFruitStock()
        end
        local nextRefresh = GardenESP and tonumber(GardenESP.stockNextRefreshUnix) or 0
        if not nextRefresh or nextRefresh <= 0 then return "?" end
        local serverNow = os.time() + (tonumber(GardenESP.stockServerOffset) or 0)
        local remain = math.max(0, math.floor(nextRefresh - serverNow))
        return string.format("%dm %02ds", remain // 60, remain % 60)
    end)
    return ok and tostring(txt or "?") or "?"
end

local function getBackpackTotalText()
    local ok, data = pcall(function()
        return BackpackESP and BackpackESP.collectItems and BackpackESP.collectItems()
    end)
    if ok and data and tonumber(data.total) then
        return BackpackESP.money(data.total) .. "¢"
    end
    return "?"
end

-- live status
function UI.SafeSetText(lbl, txt)
    pcall(function() if lbl and lbl.Parent then lbl.Text = txt end end)
end
task.spawn(function()
    while not S.killed do
        local p = myPlot()
        UI.SafeSetText(UI.plotLabel, "GARDEN: " .. (p and p.Name or "?"))
        UI.SafeSetText(UI.cashLabel, string.format("SHECKLES: %s · TOKENS: %s", fmt(getSheckles()), fmt(getTokens())))
        UI.SafeSetText(UI.totalValueLabel, "TOTAL VALUE: " .. getBackpackTotalText())
        UI.SafeSetText(UI.priceRefreshLabel, "PRICE REFRESH: " .. getPriceRefreshText())
        UI.SafeSetText(UI.statLabel, string.format("BOUGHT %d · PLANTED %d · HARVESTED %d · SOLD %d (+%s)",
            Stats.bought, Stats.planted, Stats.harvested, Stats.sold, fmt(Stats.earned)))
        UI.SafeSetText(UI.extraStatLabel, string.format("SPRINKLERS %d · WATERED %d · TAMED %d · OPENED %d · STOLEN %d",
            Stats.sprinklers, Stats.watered, Stats.tamed, Stats.opened, Stats.stolen))
        UI.SafeSetText(UI.seedEventAvailableLabel, "EVENT READY: " .. getSeedEventAvailableText())
        UI.SafeSetText(UI.seedEventClaimedLabel, "EVENT CLAIMED: " .. getSeedEventClaimText())
        UI.SafeSetText(UI.seedEventLastLabel, "LAST EVENT CLAIM: " .. getSeedEventLastText())
        UI.SafeSetText(UI.uptimeLabel, "UPTIME: " .. hms(os.clock() - Stats.startAt))
        UI.SafeSetText(UI.afkStatusLabel, "AFK: " .. (S.antiAfk and "ON" or "OFF"))
        UI.SafeSetText(UI.serverStatusLabel, string.format("SERVER: HOP %s · RECONNECT %s", S.autoHop and "ON" or "OFF", S.autoReconnect and "ON" or "OFF"))
        UI.SafeSetText(UI.webhookStatusLabel, "WEBHOOK: " .. ((S.webhookEnabled or S.webhookDisconnect) and "ON" or "OFF"))
        UI.SafeSetText(UI.progressRateLabel, HaimiyachGAG2_SessionRatesText())
        UI.SafeSetText(UI.lastSellLabel, "SELL VALUE LAST: " .. fmt(Stats.lastSellValue or 0))
        UI.SafeSetText(UI.bestPetLabel, "BEST PET EQUIPPED: " .. HaimiyachGAG2_BestPetEquippedText())
        UI.SafeSetText(UI.weatherDashLabel, "ACTIVE WEATHER: " .. HaimiyachGAG2_ActiveWeatherText(true))
        UI.SafeSetText(UI.shopDashLabel, "SHOP STOCK: " .. HaimiyachGAG2_ShopStockStatusText())
        if UI.restockNextLabel then UI.SafeSetText(UI.restockNextLabel, "NEXT RESTOCK: " .. HaimiyachGAG2_SeedRestockText()) end
        if UI.restockPredictionLabel then UI.SafeSetText(UI.restockPredictionLabel, "NEXT SEED PREDICTION:\n" .. HaimiyachGAG2_RestockPredictionText()) end
        if UI.restockTargetLabel then UI.SafeSetText(UI.restockTargetLabel, "TARGET STATUS: " .. HaimiyachGAG2_RestockTargetText()) end
        if UI.restockRecentLabel then UI.SafeSetText(UI.restockRecentLabel, "RECENT RARE SEEDS:\n" .. HaimiyachGAG2_RestockRecentText()) end
        UI.SafeSetText(UI.wildPetDashLabel, "WILD PET FOUND: " .. HaimiyachGAG2_BestWildPetText())
        UI.SafeSetText(UI.nextHopLabel, "NEXT SERVER HOP: " .. HaimiyachGAG2_NextHopText())
        if UI.activeWeatherLabel then UI.SafeSetText(UI.activeWeatherLabel, "ACTIVE WEATHER: " .. HaimiyachGAG2_ActiveWeatherText(false)) end
        if UI.weatherTimeLabel then UI.SafeSetText(UI.weatherTimeLabel, "WEATHER TIME LEFT: " .. HaimiyachGAG2_WeatherTimeText()) end
        if UI.weatherMachineLabel then
            local wm = HaimiyachGAG2_WeatherMachineInfo()
            UI.SafeSetText(UI.weatherMachineLabel, "WEATHER MACHINE: " .. tostring(wm.progress) .. " · COOLDOWN " .. tostring(wm.cooldown) .. " · PLAYERS " .. tostring(wm.active))
        end
        UI.SafeSetText(UI.visualPerfLabel, string.format("FPS: %s\nPING: %s", (HaimiyachGAG2_GetCurrentFps and tostring(HaimiyachGAG2_GetCurrentFps()) or tostring(currentFps)), getPingText()))
        task.wait(1)
    end
end)

pcall(function()
    if getgenv then getgenv().HaimiyachGAG2 = {
        S = S, Stats = Stats, Net = Net, fire = fire, action = action,
        catalog = CATALOG, gearNames = GEAR_NAMES, myPlot = myPlot, replica = replica,
        ripeHarvests = ripeHarvests, stealable = stealable, wildPets = wildPets,
        claimSeedEvent = claimSeedEvent, flyToPosition = flyToPosition, SetCutsceneDisabled = SetCutsceneDisabled,
        toolsByAttr = toolsByAttr, plantGrid = plantGrid, ownedPetNames = ownedPetNames, myBasePos = myBasePos,
        stepHarvest = stepHarvest, fireFast = fireFast, fruitCount = fruitCount, sellAllNow = sellAllNow, maxFruitCap = maxFruitCap,
        activeWeather = HaimiyachGAG2_ActiveWeatherRows, wildPetEsp = HaimiyachGAG2_UpdateWildPetESP,
        restockPrediction = HaimiyachGAG2_RestockPredictionRows, restockHistory = HaimiyachGAG2_RestockHistory,
        bestPets = HaimiyachGAG2_BestOwnedPetNames, shouldHop = HaimiyachGAG2_ShouldHopNow,
        unload = function()
            S.killed = true
            UI.Unloaded = true
            pcall(function() SetCutsceneDisabled(false, true) end)
            pcall(RestoreDefaultGraphics)
            pcall(function() GardenESP.set(false) end)
            pcall(GardenESP.clear)
            pcall(function() BackpackESP.set(false) end)
            pcall(BackpackESP.clear)
            pcall(HaimiyachGAG2_ClearWildPetESP)
            if fpsConnection then pcall(function() fpsConnection:Disconnect() end) end
            disconnectUiConnections()
            cleanContainer(PlayerGui)
            cleanContainer(CoreGui)
        end,
    } end
end)

selectTab("DASHBOARD")
setVisible(true)
notify("HAIMIYACH HUB", "has loaded successfully.", 3)
print("[HAIMIYACH HUB] Grow a Garden 2 custom GUI loaded.")
end

HaimiyachGAG2_StartUI()
