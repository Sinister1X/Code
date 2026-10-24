if not game:IsLoaded() then game.Loaded:Wait() end
local cloneref = cloneref or function(o) return o end
local Players = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local TweenService = cloneref(game:GetService("TweenService"))
local HttpService = cloneref(game:GetService("HttpService"))
local RunService = cloneref(game:GetService("RunService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local StarterGui = cloneref(game:GetService("StarterGui"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
local getupvalues = (debug and debug.getupvalues) or getupvalues

local function waitFrames(n)
    for _ = 1, math.max(1, math.floor(tonumber(n) or 1)) do
        RunService.Heartbeat:Wait()
    end
end

local CFG_PATH = "weekly_code_sniper.json"
local cfg = {
    startScan = true,
    autoSubmit = true,
    spamRedeem = true,
    spamCount = 20,
    submitAfter = 3,
    redeemFrames = 1,
    safeMode = false,
    optimizePing = false,
    sendWebhook = true,
    autoStartOnCode = false,
    ignoreSystem = true,
    typeInsteadOfAdd = false,
    typingFrames = 1,
    testDelay = 1,
    theme = "VIPRIN",
    minimized = false,
}

local function saveConfig()
    if not writefile then return end
    pcall(writefile, CFG_PATH, HttpService:JSONEncode(cfg))
end

local function loadConfig()
    if not (readfile and isfile and isfile(CFG_PATH)) then return end
    local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(CFG_PATH)) end)
    if ok and type(dec) == "table" then
        for k, v in pairs(dec) do cfg[k] = v end
    end
end
loadConfig()
cfg.redeemFrames = 1
cfg.typingFrames = 1

local WEBHOOK_URL = "https://discord.com/api/webhooks/1558544835751841913/jQq_GTJpmmXMtmPo1cXJGxmyzxNDQoZ_X4Tsb_vD8TfaP1VIYOeqwCmh_f705Lzv33Pk"

local runtime = {
    state = "idle",
    parts = {},
    pendingCode = "",
    attempts = 0,
    maxWords = 5,
    wc = 0,
    listening = false,
    lastCode = nil,
    seen = {},
    notifConn = nil,
    notifyRemote = nil,
    typingQueue = {},
    typingBusy = false,
    typingCancel = false,
    boxCleared = false,
    lastBrainrotName = "Unknown",
}

local startNotifListener
local applyTheme

local THEMES = {
    VIPRIN = { Name = "VIPRIN", Bg = Color3.fromRGB(24, 4, 38), SidebarBg = Color3.fromRGB(14, 2, 24), CardBg = Color3.fromRGB(80, 30, 130), Accent = Color3.fromRGB(200, 100, 255), Accent2 = Color3.fromRGB(240, 130, 255), Success = Color3.fromRGB(160, 240, 180), Danger = Color3.fromRGB(255, 90, 160), Info = Color3.fromRGB(210, 150, 255), TextMain = Color3.fromRGB(255, 235, 255), TextSub = Color3.fromRGB(220, 180, 245), TextMuted = Color3.fromRGB(170, 130, 210), StrokeColor = Color3.fromRGB(220, 130, 255) },
    Default = { Name = "Default", Bg = Color3.fromRGB(20, 22, 32), SidebarBg = Color3.fromRGB(14, 16, 26), CardBg = Color3.fromRGB(50, 65, 110), Accent = Color3.fromRGB(130, 160, 255), Accent2 = Color3.fromRGB(180, 140, 255), Success = Color3.fromRGB(100, 220, 160), Danger = Color3.fromRGB(255, 100, 120), Info = Color3.fromRGB(120, 200, 255), TextMain = Color3.fromRGB(240, 245, 255), TextSub = Color3.fromRGB(170, 180, 210), TextMuted = Color3.fromRGB(120, 130, 160), StrokeColor = Color3.fromRGB(180, 200, 255) },
    Sakura = { Name = "Sakura", Bg = Color3.fromRGB(42, 22, 32), SidebarBg = Color3.fromRGB(30, 14, 24), CardBg = Color3.fromRGB(120, 60, 80), Accent = Color3.fromRGB(255, 180, 210), Accent2 = Color3.fromRGB(255, 130, 180), Success = Color3.fromRGB(180, 230, 190), Danger = Color3.fromRGB(255, 100, 150), Info = Color3.fromRGB(255, 200, 230), TextMain = Color3.fromRGB(255, 240, 245), TextSub = Color3.fromRGB(240, 190, 215), TextMuted = Color3.fromRGB(200, 150, 180), StrokeColor = Color3.fromRGB(255, 180, 210) },
    Orage = { Name = "Orage", Bg = Color3.fromRGB(8, 10, 18), SidebarBg = Color3.fromRGB(4, 6, 12), CardBg = Color3.fromRGB(30, 45, 80), Accent = Color3.fromRGB(140, 180, 255), Accent2 = Color3.fromRGB(240, 240, 255), Success = Color3.fromRGB(120, 200, 180), Danger = Color3.fromRGB(255, 120, 120), Info = Color3.fromRGB(160, 200, 255), TextMain = Color3.fromRGB(230, 240, 255), TextSub = Color3.fromRGB(150, 170, 200), TextMuted = Color3.fromRGB(100, 120, 150), StrokeColor = Color3.fromRGB(150, 180, 255) },
    Feu = { Name = "Feu", Bg = Color3.fromRGB(32, 8, 4), SidebarBg = Color3.fromRGB(20, 4, 2), CardBg = Color3.fromRGB(120, 40, 15), Accent = Color3.fromRGB(255, 140, 60), Accent2 = Color3.fromRGB(255, 90, 30), Success = Color3.fromRGB(255, 200, 100), Danger = Color3.fromRGB(255, 60, 40), Info = Color3.fromRGB(255, 170, 90), TextMain = Color3.fromRGB(255, 240, 210), TextSub = Color3.fromRGB(240, 180, 130), TextMuted = Color3.fromRGB(190, 130, 90), StrokeColor = Color3.fromRGB(255, 140, 60) },
    Ocean = { Name = "Ocean", Bg = Color3.fromRGB(6, 22, 40), SidebarBg = Color3.fromRGB(3, 14, 28), CardBg = Color3.fromRGB(15, 60, 100), Accent = Color3.fromRGB(80, 200, 255), Accent2 = Color3.fromRGB(100, 240, 230), Success = Color3.fromRGB(100, 230, 180), Danger = Color3.fromRGB(255, 120, 150), Info = Color3.fromRGB(120, 220, 255), TextMain = Color3.fromRGB(220, 245, 255), TextSub = Color3.fromRGB(150, 200, 225), TextMuted = Color3.fromRGB(100, 150, 180), StrokeColor = Color3.fromRGB(80, 200, 255) },
    Automne = { Name = "Automne", Bg = Color3.fromRGB(38, 18, 8), SidebarBg = Color3.fromRGB(26, 12, 4), CardBg = Color3.fromRGB(110, 55, 20), Accent = Color3.fromRGB(230, 140, 60), Accent2 = Color3.fromRGB(220, 90, 40), Success = Color3.fromRGB(200, 220, 120), Danger = Color3.fromRGB(240, 80, 50), Info = Color3.fromRGB(255, 180, 100), TextMain = Color3.fromRGB(255, 235, 215), TextSub = Color3.fromRGB(235, 180, 140), TextMuted = Color3.fromRGB(180, 130, 90), StrokeColor = Color3.fromRGB(230, 140, 60) },
    Space = { Name = "Espace", Bg = Color3.fromRGB(4, 2, 14), SidebarBg = Color3.fromRGB(2, 1, 8), CardBg = Color3.fromRGB(45, 25, 80), Accent = Color3.fromRGB(180, 140, 255), Accent2 = Color3.fromRGB(120, 180, 255), Success = Color3.fromRGB(120, 220, 200), Danger = Color3.fromRGB(255, 120, 200), Info = Color3.fromRGB(180, 200, 255), TextMain = Color3.fromRGB(240, 235, 255), TextSub = Color3.fromRGB(180, 170, 220), TextMuted = Color3.fromRGB(120, 110, 160), StrokeColor = Color3.fromRGB(180, 140, 255) },
    Crystal = { Name = "Crystal", Bg = Color3.fromRGB(30, 34, 46), SidebarBg = Color3.fromRGB(20, 24, 36), CardBg = Color3.fromRGB(60, 80, 110), Accent = Color3.fromRGB(180, 220, 255), Accent2 = Color3.fromRGB(240, 250, 255), Success = Color3.fromRGB(150, 230, 200), Danger = Color3.fromRGB(255, 140, 160), Info = Color3.fromRGB(200, 230, 255), TextMain = Color3.fromRGB(250, 252, 255), TextSub = Color3.fromRGB(200, 220, 240), TextMuted = Color3.fromRGB(150, 170, 190), StrokeColor = Color3.fromRGB(220, 240, 255) },
    RGB = { Name = "Gaming RGB", Bg = Color3.fromRGB(8, 8, 14), SidebarBg = Color3.fromRGB(4, 4, 10), CardBg = Color3.fromRGB(100, 20, 70), Accent = Color3.fromRGB(255, 60, 180), Accent2 = Color3.fromRGB(60, 240, 255), Success = Color3.fromRGB(80, 255, 140), Danger = Color3.fromRGB(255, 60, 60), Info = Color3.fromRGB(60, 240, 255), TextMain = Color3.fromRGB(255, 255, 255), TextSub = Color3.fromRGB(200, 200, 220), TextMuted = Color3.fromRGB(140, 140, 160), StrokeColor = Color3.fromRGB(60, 240, 255) },
    DarkLuxe = { Name = "Dark Luxe", Bg = Color3.fromRGB(8, 8, 10), SidebarBg = Color3.fromRGB(4, 4, 6), CardBg = Color3.fromRGB(60, 45, 20), Accent = Color3.fromRGB(220, 180, 100), Accent2 = Color3.fromRGB(255, 220, 140), Success = Color3.fromRGB(150, 200, 130), Danger = Color3.fromRGB(220, 80, 80), Info = Color3.fromRGB(230, 190, 110), TextMain = Color3.fromRGB(245, 235, 210), TextSub = Color3.fromRGB(200, 180, 140), TextMuted = Color3.fromRGB(150, 130, 100), StrokeColor = Color3.fromRGB(220, 180, 100) },
    Holographic = { Name = "Holographique", Bg = Color3.fromRGB(24, 22, 38), SidebarBg = Color3.fromRGB(16, 14, 28), CardBg = Color3.fromRGB(60, 60, 100), Accent = Color3.fromRGB(180, 200, 255), Accent2 = Color3.fromRGB(255, 180, 255), Success = Color3.fromRGB(180, 255, 220), Danger = Color3.fromRGB(255, 160, 200), Info = Color3.fromRGB(160, 230, 255), TextMain = Color3.fromRGB(250, 245, 255), TextSub = Color3.fromRGB(210, 200, 240), TextMuted = Color3.fromRGB(160, 150, 190), StrokeColor = Color3.fromRGB(255, 200, 255) },
    Fun = { Name = "Fun", Bg = Color3.fromRGB(30, 20, 50), SidebarBg = Color3.fromRGB(20, 12, 38), CardBg = Color3.fromRGB(110, 80, 20), Accent = Color3.fromRGB(255, 200, 60), Accent2 = Color3.fromRGB(255, 120, 180), Success = Color3.fromRGB(120, 240, 140), Danger = Color3.fromRGB(255, 100, 100), Info = Color3.fromRGB(120, 220, 255), TextMain = Color3.fromRGB(255, 250, 240), TextSub = Color3.fromRGB(240, 220, 245), TextMuted = Color3.fromRGB(190, 170, 210), StrokeColor = Color3.fromRGB(255, 220, 120) },
    Retro = { Name = "Retro", Bg = Color3.fromRGB(6, 6, 12), SidebarBg = Color3.fromRGB(3, 3, 8), CardBg = Color3.fromRGB(15, 60, 30), Accent = Color3.fromRGB(80, 255, 140), Accent2 = Color3.fromRGB(255, 220, 60), Success = Color3.fromRGB(80, 255, 140), Danger = Color3.fromRGB(255, 80, 80), Info = Color3.fromRGB(60, 180, 255), TextMain = Color3.fromRGB(120, 255, 160), TextSub = Color3.fromRGB(80, 200, 120), TextMuted = Color3.fromRGB(60, 160, 100), StrokeColor = Color3.fromRGB(80, 255, 140) },
}

local UI = {
    Size = UDim2.new(0, 360, 0, 330),
    Position = UDim2.new(0.5, -180, 0.5, -165),
    SidebarWidth = 100,
    CurrentTheme = cfg.theme or "VIPRIN",
    Minimized = cfg.minimized or false,
}
local Theme = THEMES[UI.CurrentTheme] or THEMES.VIPRIN

for _, name in ipairs({ "ViprinRound8UI", "WeeklyCodeSniperUI", "WeeklySettingsUI" }) do
    pcall(function() local g = CoreGui:FindFirstChild(name); if g then g:Destroy() end end)
    pcall(function() local g = PlayerGui:FindFirstChild(name); if g then g:Destroy() end end)
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or UDim.new(0, 10)
    c.Parent = parent
    return c
end
local function stroke(parent, color, thickness, transparency, tagName)
    local s = Instance.new("UIStroke")
    s.Color = color; s.Thickness = thickness or 1; s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s:SetAttribute("ThemeTag", tagName or "stroke")
    s.Parent = parent
    return s
end
local function gradient(parent, c1, c2, rotation, tagName)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2); g.Rotation = rotation or 0
    g:SetAttribute("ThemeTag", tagName or "custom")
    g.Parent = parent
    return g
end
local function tag(obj, t) obj:SetAttribute("ThemeTag", t) return obj end
local function new(className, props, parent)
    local o = Instance.new(className)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ViprinRound8UI"
ScreenGui.DisplayOrder = 999
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if not pcall(function() ScreenGui.Parent = CoreGui end) then ScreenGui.Parent = PlayerGui end

local Main = new("Frame", {
    Name = "Main", Size = UI.Size, Position = UI.Position,
    BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.2,
    BorderSizePixel = 0, Active = true, ClipsDescendants = true,
}, ScreenGui)
corner(Main, UDim.new(0, 14))
stroke(Main, Theme.StrokeColor, 1.5, 0.4, "strokeAccent")
gradient(Main, Theme.Bg, Theme.SidebarBg, 135, "main")

local GlowStroke = stroke(Main, Theme.Accent, 2, 0.3, "glowStroke")
task.spawn(function()
    while Main.Parent do
        TweenService:Create(GlowStroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Transparency = 0.75, Thickness = 1.5
        }):Play()
        task.wait(1.6)
        if not Main.Parent then break end
        TweenService:Create(GlowStroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Transparency = 0.2, Thickness = 2.5
        }):Play()
        task.wait(1.6)
    end
end)

local Sidebar = new("Frame", {
    Size = UDim2.new(0, UI.SidebarWidth, 1, 0),
    BackgroundColor3 = Theme.SidebarBg, BackgroundTransparency = 0.4,
    BorderSizePixel = 0, ZIndex = 3,
}, Main)
corner(Sidebar, UDim.new(0, 14))
tag(Sidebar, "sidebar")

local SepLine = new("Frame", {
    Size = UDim2.new(0, 1, 1, -24), Position = UDim2.new(0, UI.SidebarWidth, 0, 12),
    BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 4,
}, Main)
tag(SepLine, "accent")

local LogoFrame = new("Frame", {
    Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0, 8, 0, 10),
    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 4,
}, Sidebar)
corner(LogoFrame, UDim.new(0, 10))
gradient(LogoFrame, Theme.Accent, Theme.Accent2, 45, "logo")
tag(LogoFrame, "accent")

new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.6, 0),
    Font = Enum.Font.GothamBold, Text = "W",
    TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 18, ZIndex = 5,
}, LogoFrame)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0.55, 0),
    Size = UDim2.new(1, 0, 0.4, 0), Font = Enum.Font.GothamBold,
    Text = "SNIPER", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 8, ZIndex = 5,
}, LogoFrame)

local TabList = new("Frame", {
    Position = UDim2.new(0, 8, 0, 58), Size = UDim2.new(1, -16, 1, -68),
    BackgroundTransparency = 1, ZIndex = 4,
}, Sidebar)

local tabRefs = {}
local function makeTab(label, yOrder)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 0, yOrder * 30),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 5,
    }, TabList)
    corner(btn, UDim.new(0, 8))

    local indicator = new("Frame", {
        Size = UDim2.new(0, 3, 0, 14), Position = UDim2.new(0, -2, 0.5, -7),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Visible = false, ZIndex = 6,
    }, btn)
    corner(indicator, UDim.new(1, 0))
    tag(indicator, "accent")

    local lbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -10, 1, 0), Font = Enum.Font.GothamBold,
        Text = label, TextColor3 = Theme.TextSub, TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, btn)
    tag(lbl, "tabLabel")

    btn.MouseEnter:Connect(function()
        if not btn:GetAttribute("active") then
            TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 0.85 }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("active") then
            TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        end
    end)
    table.insert(tabRefs, { btn = btn, lbl = lbl, indicator = indicator })
    return btn
end

local Content = new("Frame", {
    Position = UDim2.new(0, UI.SidebarWidth, 0, 0),
    Size = UDim2.new(1, -UI.SidebarWidth, 1, 0),
    BackgroundTransparency = 1, ZIndex = 3,
}, Main)

local Topbar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 3,
}, Content)

local PageTitle = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 0),
    Size = UDim2.new(1, -180, 1, 0), Font = Enum.Font.GothamBold,
    Text = "Main", TextColor3 = Theme.TextMain, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, Topbar)
tag(PageTitle, "textMain")

local StatusPill = new("Frame", {
    Size = UDim2.new(0, 62, 0, 20), Position = UDim2.new(1, -128, 0.5, -10),
    BackgroundColor3 = Theme.Danger, BackgroundTransparency = 0.75,
    BorderSizePixel = 0, ZIndex = 4,
}, Topbar)
corner(StatusPill, UDim.new(1, 0))
stroke(StatusPill, Theme.Danger, 1, 0.4, "danger")
tag(StatusPill, "danger")

local StatusDot = new("Frame", {
    Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0, 8, 0.5, -3),
    BackgroundColor3 = Theme.Danger, BorderSizePixel = 0, ZIndex = 5,
}, StatusPill)
corner(StatusDot, UDim.new(1, 0))

local StatusText = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 0),
    Size = UDim2.new(1, -22, 1, 0), Font = Enum.Font.GothamBold,
    Text = "OFF", TextColor3 = Theme.Danger, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, StatusPill)
tag(StatusText, "danger")

local MinimizeBtn = new("TextButton", {
    Size = UDim2.new(0, 22, 0, 20), Position = UDim2.new(1, -58, 0.5, -10),
    BackgroundColor3 = Color3.fromRGB(255, 200, 60), BorderSizePixel = 0,
    AutoButtonColor = false, Font = Enum.Font.GothamBold,
    Text = "-", TextColor3 = Color3.fromRGB(20, 20, 20),
    TextSize = 16, ZIndex = 6,
}, Topbar)
corner(MinimizeBtn, UDim.new(0, 5))
stroke(MinimizeBtn, Color3.fromRGB(200, 150, 30), 1, 0.2, "stroke")

local CloseBtn = new("TextButton", {
    Size = UDim2.new(0, 22, 0, 20), Position = UDim2.new(1, -32, 0.5, -10),
    BackgroundColor3 = Color3.fromRGB(230, 60, 60), BorderSizePixel = 0,
    AutoButtonColor = false, Font = Enum.Font.GothamBold,
    Text = "X", TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13, ZIndex = 6,
}, Topbar)
corner(CloseBtn, UDim.new(0, 5))
stroke(CloseBtn, Color3.fromRGB(180, 30, 30), 1, 0.2, "stroke")

MinimizeBtn.MouseEnter:Connect(function()
    TweenService:Create(MinimizeBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(255, 220, 100) }):Play()
end)
MinimizeBtn.MouseLeave:Connect(function()
    TweenService:Create(MinimizeBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(255, 200, 60) }):Play()
end)
CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(255, 90, 90) }):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(230, 60, 60) }):Play()
end)

local Div = new("Frame", {
    Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 0, 40),
    BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.7,
    BorderSizePixel = 0, ZIndex = 3,
}, Content)
tag(Div, "accent")

local PageContainer = new("Frame", {
    Position = UDim2.new(0, 0, 0, 40),
    Size = UDim2.new(1, 0, 1, -40),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3,
}, Content)

local function makePage(name)
    local page = new("Frame", {
        Name = name, Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, Visible = false, ZIndex = 3,
    }, PageContainer)

    local scroll = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        ZIndex = 3,
    }, page)
    tag(scroll, "scrollFrame")

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = scroll

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Parent = scroll

    return page, scroll
end

local function makeSection(parent, title, height)
    local sec = new("Frame", {
        Size = UDim2.new(1, 0, 0, height or 60),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.94, BorderSizePixel = 0, ZIndex = 4,
    }, parent)
    corner(sec, UDim.new(0, 10))
    stroke(sec, Theme.StrokeColor, 1, 0.75, "strokeAccent")
    local lbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -24, 0, 10), Font = Enum.Font.GothamBold,
        Text = string.upper(title), TextColor3 = Theme.TextMuted,
        TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, sec)
    tag(lbl, "sectionLabel")
    return sec
end

local function makeButton(parent, text, pos, size, tagBtn)
    local col
    if tagBtn == "accent" then col = Theme.Accent
    elseif tagBtn == "accent2" then col = Theme.Accent2
    elseif tagBtn == "success" then col = Theme.Success
    elseif tagBtn == "danger" then col = Theme.Danger
    elseif tagBtn == "info" then col = Theme.Info
    else col = Theme.Accent end
    local btn = new("TextButton", {
        Position = pos, Size = size, BackgroundColor3 = col,
        BackgroundTransparency = 0.75, BorderSizePixel = 0,
        AutoButtonColor = false, Font = Enum.Font.GothamBold,
        Text = text, TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 10, ZIndex = 5,
    }, parent)
    corner(btn, UDim.new(0, 8))
    stroke(btn, Theme.StrokeColor, 1, 0.6, "strokeAccent")
    tag(btn, "btn_" .. tagBtn)
    return btn
end

local function makeTextInput(parent, placeholder, text, pos, size)
    local box = new("TextBox", {
        Position = pos, Size = size,
        BackgroundColor3 = Theme.CardBg, BackgroundTransparency = 0.7,
        BorderSizePixel = 0, ClearTextOnFocus = false,
        Font = Enum.Font.Gotham, PlaceholderText = placeholder or "",
        PlaceholderColor3 = Theme.TextMuted, Text = text or "",
        TextColor3 = Theme.TextMain, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, parent)
    corner(box, UDim.new(0, 8))
    stroke(box, Theme.StrokeColor, 1, 0.6, "strokeAccent")
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = box
    tag(box, "input")
    return box
end

local function makeToggle(parent, pos, default, onChanged)
    local row = new("Frame", {
        Size = UDim2.new(1, -24, 0, 26), Position = pos,
        BackgroundColor3 = Theme.CardBg, BackgroundTransparency = 0.7,
        BorderSizePixel = 0, ZIndex = 4,
    }, parent)
    corner(row, UDim.new(0, 7))
    stroke(row, Theme.StrokeColor, 1, 0.7, "strokeAccent")

    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -80, 1, 0), Font = Enum.Font.Gotham,
        Text = "", TextColor3 = Theme.TextSub, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, row)
    tag(label, "textSub")

    local track = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 34, 0, 18),
        BackgroundColor3 = default and Theme.Success or Theme.Danger,
        BorderSizePixel = 0, ZIndex = 5,
    }, row)
    corner(track, UDim.new(1, 0))

    local knob = new("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = default and UDim2.new(0, 18, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, ZIndex = 6,
    }, track)
    corner(knob, UDim.new(1, 0))

    local state = default
    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 7,
    }, row)

    local function setOn(on)
        state = on
        TweenService:Create(track, TweenInfo.new(0.18), { BackgroundColor3 = on and Theme.Success or Theme.Danger }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {
            Position = on and UDim2.new(0, 18, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }):Play()
        if onChanged then onChanged(on) end
    end

    hit.MouseButton1Click:Connect(function() setOn(not state) end)

    return row, setOn, function() return state end, label
end

local PageMain, ScrollMain = makePage("Main")
local SecControl = makeSection(ScrollMain, "Farm Control", 184)

local ScanBtn = makeButton(SecControl, "START SCAN", UDim2.new(0, 12, 0, 26), UDim2.new(1, -24, 0, 28), "success")
ScanBtn.Text = cfg.startScan and "SCANNING..." or "START SCAN"

new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 60),
    Size = UDim2.new(1, -120, 0, 20), Font = Enum.Font.Gotham,
    Text = "Auto Submit After", TextColor3 = Theme.TextSub, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecControl)

local SubmitAfterBox = makeTextInput(SecControl, "3", tostring(cfg.submitAfter), UDim2.new(1, -70, 0, 60), UDim2.new(0, 58, 0, 22))

local AutoRow, setAuto, getAuto, AutoLabel = makeToggle(SecControl, UDim2.new(0, 12, 0, 88), cfg.autoSubmit, function(on)
    cfg.autoSubmit = on; saveConfig()
end)
AutoLabel.Text = "Auto Submit"

local SpamRow, setSpam, getSpam, SpamLabel = makeToggle(SecControl, UDim2.new(0, 12, 0, 118), cfg.spamRedeem, function(on)
    cfg.spamRedeem = on; saveConfig()
end)
SpamLabel.Text = "Spam Redeem"

new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 150),
    Size = UDim2.new(1, -120, 0, 20), Font = Enum.Font.Gotham,
    Text = "Spam Count", TextColor3 = Theme.TextSub, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecControl)

local SpamCountBox = makeTextInput(SecControl, "20", tostring(cfg.spamCount), UDim2.new(1, -70, 0, 150), UDim2.new(0, 58, 0, 22))

local SecSeq = makeSection(ScrollMain, "Current Sequence", 76)
local SeqLabel = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 24),
    Size = UDim2.new(1, -24, 0, 18), Font = Enum.Font.Code,
    Text = "--", TextColor3 = Theme.TextMain, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
}, SecSeq)
tag(SeqLabel, "textMain")
local ClearSeqBtn = makeButton(SecSeq, "CLEAR SEQUENCE", UDim2.new(0, 12, 0, 46), UDim2.new(1, -24, 0, 22), "danger")

local SecLogs = makeSection(ScrollMain, "Logs", 180)
local ClearLogsBtn = makeButton(SecLogs, "CLEAR", UDim2.new(1, -68, 0, 2), UDim2.new(0, 56, 0, 18), "accent")

local LogFrame = new("ScrollingFrame", {
    Position = UDim2.new(0, 10, 0, 24),
    Size = UDim2.new(1, -20, 0, 148),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.5,
    BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ClipsDescendants = true, ZIndex = 5,
}, SecLogs)
corner(LogFrame, UDim.new(0, 5))
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical }, LogFrame)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, LogFrame)

local logEntries = {}
local function consoleLog(msg)
    local t = os.date("%H:%M:%S")
    local entry = "[" .. t .. "] " .. tostring(msg)
    table.insert(logEntries, entry)
    if #logEntries > 200 then table.remove(logEntries, 1) end
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 9,
        TextColor3 = Theme.TextSub, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Text = entry, LayoutOrder = #logEntries, ZIndex = 6,
    }, LogFrame)
    tag(lbl, "textSub")
    task.defer(function() LogFrame.CanvasPosition = Vector2.new(0, math.huge) end)
end

ClearLogsBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(LogFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    logEntries = {}
    consoleLog("Logs cleared")
end)

local PageTester, ScrollTester = makePage("Tester")
local SecTest = makeSection(ScrollTester, "Test Sender", 130)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 24),
    Size = UDim2.new(1, -24, 0, 12), Font = Enum.Font.Gotham,
    Text = "Simulate a notification:", TextColor3 = Theme.TextMuted,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecTest)
local TestInput = makeTextInput(SecTest, "the code is ABC123...", "", UDim2.new(0, 12, 0, 40), UDim2.new(1, -24, 0, 26))
local SendBtn = makeButton(SecTest, "SEND TEST", UDim2.new(0, 12, 0, 74), UDim2.new(0.5, -16, 0, 26), "success")
local ClearTestBtn = makeButton(SecTest, "CLEAR", UDim2.new(0.5, 4, 0, 74), UDim2.new(0.5, -16, 0, 26), "accent")

local SecTestCode = makeSection(ScrollTester, "Test Code", 110)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 24),
    Size = UDim2.new(1, -24, 0, 12), Font = Enum.Font.Gotham,
    Text = "Sends CERB > IS > TUFF with delay between each", TextColor3 = Theme.TextMuted,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecTestCode)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 44),
    Size = UDim2.new(0, 120, 0, 20), Font = Enum.Font.Gotham,
    Text = "Delay between (s)", TextColor3 = Theme.TextSub, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecTestCode)
local TestDelayBox = makeTextInput(SecTestCode, "1", tostring(cfg.testDelay), UDim2.new(1, -70, 0, 44), UDim2.new(0, 58, 0, 22))
local TestCodeBtn = makeButton(SecTestCode, "TEST CODE", UDim2.new(0, 12, 0, 76), UDim2.new(1, -24, 0, 26), "info")

local SecLastCode = makeSection(ScrollTester, "Last Captured Code", 82)
local LastCodeLabel = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 24),
    Size = UDim2.new(1, -24, 0, 20), Font = Enum.Font.Code,
    Text = "--", TextColor3 = Theme.TextMain, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecLastCode)
tag(LastCodeLabel, "textMain")
local RedeemBtn = makeButton(SecLastCode, "REDEEM", UDim2.new(0, 12, 0, 50), UDim2.new(0.5, -16, 0, 24), "success")
local CopyBtn = makeButton(SecLastCode, "COPY", UDim2.new(0.5, 4, 0, 50), UDim2.new(0.5, -16, 0, 24), "accent")

local SecPing = makeSection(ScrollTester, "Test Ping (CERBISTUFF)", 70)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 24),
    Size = UDim2.new(1, -24, 0, 16), Font = Enum.Font.Gotham,
    Text = "Redeems CERBISTUFF (spam if Spam Redeem ON)", TextColor3 = Theme.TextMuted,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecPing)
local TestPingBtn = makeButton(SecPing, "TEST PING", UDim2.new(0, 12, 0, 42), UDim2.new(1, -24, 0, 22), "info")

local PageSettings, ScrollSettings = makePage("Settings")
local SecSett = makeSection(ScrollSettings, "Configuration", 312)

new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 24),
    Size = UDim2.new(0, 120, 0, 20), Font = Enum.Font.Gotham,
    Text = "Delay (frames)", TextColor3 = Theme.TextSub, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecSett)
local DelayBox = makeTextInput(SecSett, "1", tostring(cfg.redeemFrames), UDim2.new(1, -70, 0, 24), UDim2.new(0, 58, 0, 22))

local SafeRow, setSafe, getSafe, SafeLabel = makeToggle(SecSett, UDim2.new(0, 12, 0, 56), cfg.safeMode, function(on)
    cfg.safeMode = on; saveConfig()
end)
SafeLabel.Text = "Safe Mode"

local OptRow, setOpt, getOpt, OptLabel = makeToggle(SecSett, UDim2.new(0, 12, 0, 86), cfg.optimizePing, function(on)
    cfg.optimizePing = on; saveConfig()
end)
OptLabel.Text = "Optimize Ping"

local WebRow, setWeb, getWeb, WebLabel = makeToggle(SecSett, UDim2.new(0, 12, 0, 116), cfg.sendWebhook, function(on)
    cfg.sendWebhook = on; saveConfig()
end)
WebLabel.Text = "Discord Webhook"

local AutoStartRow, setAutoStart, getAutoStart, AutoStartLabel = makeToggle(SecSett, UDim2.new(0, 12, 0, 146), cfg.autoStartOnCode, function(on)
    cfg.autoStartOnCode = on
    saveConfig()
    if on then startNotifListener() end
end)
AutoStartLabel.Text = "Auto Start Scan on Code Is"

local TypeRow, setType, getType, TypeLabel = makeToggle(SecSett, UDim2.new(0, 12, 0, 176), cfg.typeInsteadOfAdd, function(on)
    cfg.typeInsteadOfAdd = on
    saveConfig()
end)
TypeLabel.Text = "Type Instead Of Add"

local SysRow, setSys, getSys, SysLabel = makeToggle(SecSett, UDim2.new(0, 12, 0, 206), cfg.ignoreSystem, function(on)
    cfg.ignoreSystem = on
    saveConfig()
end)
SysLabel.Text = "Ignore System Phrases"

new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 238),
    Size = UDim2.new(0, 140, 0, 20), Font = Enum.Font.Gotham,
    Text = "Typing (frames)", TextColor3 = Theme.TextSub, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, SecSett)
local TypingSpeedBox = makeTextInput(SecSett, "1", tostring(cfg.typingFrames), UDim2.new(1, -70, 0, 238), UDim2.new(0, 58, 0, 22))

local PingBtn = makeButton(SecSett, "SHOW PING / FPS", UDim2.new(0, 12, 0, 274), UDim2.new(1, -24, 0, 26), "info")

local PageHelper, stopHelpers
do
    local ScrollHelper
    PageHelper, ScrollHelper = makePage("Helper")

    local autoBuyOn = false
    local antiRagdollOn = false
    local autoBuyElapsed = 0
    local antiRagdollCooldown = 0
    local antiRagdollConn

    local function triggerWorkspacePrompts()
        for _, prompt in ipairs(workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") then
                pcall(function()
                    prompt.HoldDuration = 0
                    prompt:InputHoldBegin()
                    prompt:InputHoldEnd()
                end)
            end
        end
    end

    local autoBuyConn = RunService.Stepped:Connect(function(_, deltaTime)
        if not autoBuyOn then return end
        autoBuyElapsed += tonumber(deltaTime) or 0
        if autoBuyElapsed < 0.12 then return end
        autoBuyElapsed = 0
        triggerWorkspacePrompts()
    end)

    local function forceAntiRagdollReset()
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then return end

        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            root.Velocity = Vector3.zero
            root.RotVelocity = Vector3.zero
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            for _, object in ipairs(character:GetDescendants()) do
                if object:IsA("Motor6D") then object.Enabled = true end
                if object:IsA("Constraint") then object.Enabled = true end
            end
            if workspace.CurrentCamera then workspace.CurrentCamera.CameraSubject = humanoid end
            humanoid.AutoRotate = true
            humanoid.PlatformStand = false
            humanoid.Sit = false
        end)

        pcall(function()
            local playerModule = LocalPlayer:FindFirstChild("PlayerScripts")
                and LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
            local controlModule = playerModule and playerModule:FindFirstChild("ControlModule")
            if controlModule then
                local controls = require(controlModule)
                if controls and controls.Enable then controls:Enable() end
            end
        end)
    end

    local function setAntiRagdoll(state)
        antiRagdollOn = state == true
        if not antiRagdollOn then
            if antiRagdollConn then antiRagdollConn:Disconnect() end
            antiRagdollConn = nil
            return
        end
        if antiRagdollConn then return end
        antiRagdollConn = RunService.Heartbeat:Connect(function()
            if not antiRagdollOn then return end
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then return end
            local current = humanoid:GetState()
            local ragdolled = current == Enum.HumanoidStateType.Physics
                or current == Enum.HumanoidStateType.Ragdoll
                or current == Enum.HumanoidStateType.FallingDown
            if ragdolled and tick() - antiRagdollCooldown > 0.15 then
                antiRagdollCooldown = tick()
                forceAntiRagdollReset()
            end
        end)
    end

    local anOn, anCF, anConn = false, nil, nil

    local function setAnchor(st)
        anOn = st == true
        if anConn then anConn:Disconnect(); anConn = nil end
        if not anOn then
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r then pcall(function() r.Anchored = false end) end
            anCF = nil
            return
        end
        local c0 = LocalPlayer.Character
        local r0 = c0 and c0:FindFirstChild("HumanoidRootPart")
        anCF = r0 and r0.CFrame
        anConn = RunService.Heartbeat:Connect(function()
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if not r or not h or h.Health <= 0 then anCF = nil return end
            if not anCF then anCF = r.CFrame end
            pcall(function()
                r.Anchored = true
                r.CFrame = anCF
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
                if h.PlatformStand then h.PlatformStand = false end
                local s = h:GetState()
                if s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown then
                    h:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
        end)
    end

    stopHelpers = function()
        autoBuyOn = false
        setAntiRagdoll(false)
        setAnchor(false)
        pcall(function() autoBuyConn:Disconnect() end)
    end

    local SecHelper = makeSection(ScrollHelper, "Helper", 130)

    local _, _, _, BuyLabel = makeToggle(SecHelper, UDim2.new(0, 12, 0, 28), false, function(on)
        autoBuyOn = on
        autoBuyElapsed = 0
        if on then task.spawn(triggerWorkspacePrompts) end
        consoleLog("Auto Buy " .. (on and "ON" or "OFF"))
    end)
    BuyLabel.Text = "Auto Buy"

    local _, _, _, RagLabel = makeToggle(SecHelper, UDim2.new(0, 12, 0, 60), false, function(on)
        setAntiRagdoll(on)
        consoleLog("Anti Ragdoll " .. (on and "ON" or "OFF"))
    end)
    RagLabel.Text = "Anti Ragdoll"

    local _, _, _, AnLabel = makeToggle(SecHelper, UDim2.new(0, 12, 0, 92), false, function(on)
        setAnchor(on)
        consoleLog("Anchor " .. (on and "ON" or "OFF"))
    end)
    AnLabel.Text = "Anchor"
end

local PageThemes, ScrollThemes = makePage("Themes")
local ThemeScroll = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4,
}, ScrollThemes)

new("UIGridLayout", {
    CellSize = UDim2.new(0.5, -6, 0, 40),
    CellPadding = UDim2.new(0, 8, 0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, ThemeScroll)

local themeButtons = {}
local function createThemeButton(themeKey, order)
    local t = THEMES[themeKey]
    local btn = new("TextButton", {
        Name = "Theme_" .. themeKey, BackgroundColor3 = t.Accent,
        BackgroundTransparency = 0.6, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", LayoutOrder = order, ZIndex = 5,
    }, ThemeScroll)
    corner(btn, UDim.new(0, 8))
    local bStroke = stroke(btn, t.StrokeColor, 1.5, 0.3, "themeBtnStroke")
    local bGrad = gradient(btn, t.Accent, t.Accent2, 45, "themeBtnGrad")
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -20, 1, 0), Font = Enum.Font.GothamBold,
        Text = t.Name, TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, btn)

    if themeKey == UI.CurrentTheme then
        bStroke.Transparency = 0; bStroke.Thickness = 3
        btn.BackgroundTransparency = 0.35; btn:SetAttribute("selected", true)
    end
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.4 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        if btn:GetAttribute("selected") then
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.35 }):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.6 }):Play()
        end
    end)
    themeButtons[themeKey] = { btn = btn, stroke = bStroke, grad = bGrad }
    btn.MouseButton1Click:Connect(function() applyTheme(themeKey) end)
end

function applyTheme(themeKey)
    local t = THEMES[themeKey]
    if not t then return end
    UI.CurrentTheme = themeKey; Theme = t
    cfg.theme = themeKey; saveConfig()

    local ti = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    for _, obj in ipairs(ScreenGui:GetDescendants()) do
        if obj:IsA("GuiObject") then
            local tg = obj:GetAttribute("ThemeTag")
            if tg == "sidebar" then
                TweenService:Create(obj, ti, { BackgroundColor3 = t.SidebarBg }):Play()
            elseif tg == "accent" then
                TweenService:Create(obj, ti, { BackgroundColor3 = t.Accent }):Play()
            elseif tg == "danger" then
                TweenService:Create(obj, ti, { BackgroundColor3 = t.Danger }):Play()
            end
            if tg and tg:sub(1, 4) == "btn_" then
                local kind = tg:sub(5)
                local col
                if kind == "accent" then col = t.Accent
                elseif kind == "accent2" then col = t.Accent2
                elseif kind == "success" then col = t.Success
                elseif kind == "danger" then col = t.Danger
                elseif kind == "info" then col = t.Info
                else col = t.Accent end
                TweenService:Create(obj, ti, { BackgroundColor3 = col }):Play()
            end
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if tg == "textMain" then
                    TweenService:Create(obj, ti, { TextColor3 = t.TextMain }):Play()
                elseif tg == "textSub" then
                    TweenService:Create(obj, ti, { TextColor3 = t.TextSub }):Play()
                elseif tg == "sectionLabel" then
                    TweenService:Create(obj, ti, { TextColor3 = t.TextMuted }):Play()
                elseif tg == "danger" then
                    TweenService:Create(obj, ti, { TextColor3 = t.Danger }):Play()
                elseif tg == "tabLabel" then
                    local parent = obj.Parent
                    local isActive = parent and parent:GetAttribute("active")
                    TweenService:Create(obj, ti, { TextColor3 = isActive and t.TextMain or t.TextSub }):Play()
                end
            end
        end
        if obj:IsA("UIStroke") then
            local tg = obj:GetAttribute("ThemeTag")
            if tg == "strokeAccent" or tg == "stroke" then
                TweenService:Create(obj, ti, { Color = t.StrokeColor }):Play()
            elseif tg == "danger" then
                TweenService:Create(obj, ti, { Color = t.Danger }):Play()
            elseif tg == "glowStroke" then
                TweenService:Create(obj, ti, { Color = t.Accent }):Play()
            end
        end
        if obj:IsA("UIGradient") then
            local tg = obj:GetAttribute("ThemeTag")
            if tg == "main" then
                TweenService:Create(obj, ti, { Color = ColorSequence.new(t.Bg, t.SidebarBg) }):Play()
            elseif tg == "logo" then
                TweenService:Create(obj, ti, { Color = ColorSequence.new(t.Accent, t.Accent2) }):Play()
            end
        end
        if obj:IsA("ScrollingFrame") and obj:GetAttribute("ThemeTag") == "scrollFrame" then
            TweenService:Create(obj, ti, { ScrollBarImageColor3 = t.Accent }):Play()
        end
    end
    TweenService:Create(Main, ti, { BackgroundColor3 = t.Bg }):Play()
    TweenService:Create(LogFrame, ti, { ScrollBarImageColor3 = t.Accent }):Play()
    TweenService:Create(ThemeScroll, ti, { ScrollBarImageColor3 = t.Accent }):Play()

    for key, tb in pairs(themeButtons) do
        local tt = THEMES[key]
        TweenService:Create(tb.grad, ti, { Color = ColorSequence.new(tt.Accent, tt.Accent2) }):Play()
        TweenService:Create(tb.stroke, ti, {
            Color = tt.StrokeColor,
            Transparency = (key == themeKey) and 0 or 0.3,
            Thickness = (key == themeKey) and 3 or 1.5
        }):Play()
        if key == themeKey then
            tb.btn:SetAttribute("selected", true)
            TweenService:Create(tb.btn, ti, { BackgroundTransparency = 0.35 }):Play()
        else
            tb.btn:SetAttribute("selected", false)
            TweenService:Create(tb.btn, ti, { BackgroundTransparency = 0.6 }):Play()
        end
    end
    for _, tab in ipairs(tabRefs) do
        TweenService:Create(tab.indicator, ti, { BackgroundColor3 = t.Accent }):Play()
    end
end

local themeOrder = { "VIPRIN", "Default", "Sakura", "Orage", "Feu", "Ocean", "Automne", "Space", "Crystal", "RGB", "DarkLuxe", "Holographic", "Fun", "Retro" }
for i, key in ipairs(themeOrder) do createThemeButton(key, i) end

local PageQuestions, ScrollQuestions = makePage("Questions")

local function makeQuestionSection(parent, title, text)
    local sec = new("Frame", {
        Size = UDim2.new(1, 0, 0, 10), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94,
        BorderSizePixel = 0, ZIndex = 4,
    }, parent)
    corner(sec, UDim.new(0, 10))
    stroke(sec, Theme.StrokeColor, 1, 0.75, "strokeAccent")

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = sec

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = sec

    local titleLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, Text = string.upper(title),
        TextColor3 = Theme.Accent, TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
    }, sec)
    tag(titleLbl, "accent")

    local descLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 10), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        Text = text, TextColor3 = Theme.TextSub, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, ZIndex = 5, LayoutOrder = 2,
    }, sec)
    tag(descLbl, "textSub")

    return sec
end

makeQuestionSection(ScrollQuestions, "Farm Control",
    "START SCAN : Active ou désactive la capture des annonces du jeu.\n\n" ..
    "Auto Submit After : Nombre de mots à capturer avant le premier redeem. Réglé sur 3, 'aura aura aura' est redeem tout de suite.\n\n" ..
    "Auto Submit : Si activé, le code est envoyé automatiquement dès qu'il est complet. Sinon, clique sur REDEEM.\n\n" ..
    "Spam Redeem : Clique plusieurs fois sur Confirm au lieu d'une seule (voir Spam Count).\n\n" ..
    "Spam Count : Nombre de clics lors d'un Spam Redeem. Max 100."
)

makeQuestionSection(ScrollQuestions, "Settings",
    "Delay (frames) : Frames Heartbeat à attendre avant chaque redeem. 1 = le plus rapide (une frame, donc 240 fois par seconde sur 240 FPS).\n\n" ..
    "Safe Mode / Optimize Ping : Options sauvegardées dans la config.\n\n" ..
    "Discord Webhook : Envoie un message Discord au premier essai de chaque code.\n\n" ..
    "Auto Start Scan on Code Is : Écoute en permanence. Si un message contient 'code is' ou 'use code', le scan démarre et les mots après la phrase sont pris comme début du code.\n\n" ..
    "Ignore System Phrases : Ignore les annonces du jeu qui ne sont jamais des codes (luck, shop, event, base locked...) et tout ce qui n'est pas une annonce 'Top'.\n\n" ..
    "Type Instead Of Add : Tape le code lettre par lettre dans la TextBox.\n\n" ..
    "Typing (frames) : Frames Heartbeat entre chaque lettre. 1 = une lettre par frame, le maximum."
)

makeQuestionSection(ScrollQuestions, "Tester",
    "Test Sender : Simule une notification pour tester la capture.\n\n" ..
    "Test Code : Envoie CERB / IS / TUFF avec un délai entre chaque.\n\n" ..
    "Last Captured Code : Dernier code capturé. REDEEM le renvoie, COPY le copie.\n\n" ..
    "Test Ping : Redeem 'CERBISTUFF' pour vérifier que le redeem marche."
)

makeQuestionSection(ScrollQuestions, "Helper",
    "Auto Buy : Active tous les ProximityPrompt proches en boucle (achat automatique).\n\n" ..
    "Anti Ragdoll : Remet ton perso debout dès qu'il passe en état ragdoll / physics."
)

makeQuestionSection(ScrollQuestions, "Themes",
    "Change l'apparence complète du menu. Le thème est sauvegardé automatiquement."
)

makeQuestionSection(ScrollQuestions, "Fonctionnement Général",
    "1. Active START SCAN.\n" ..
    "2. Le script attend 'code is' ou 'use code'. Tant qu'elle n'apparaît pas, il ignore tout. Ensuite il assemble les mots jusqu'à 'Auto Submit After' puis redeem (ex: aura aura aura -> auraauraaura).\n" ..
    "3. Si le code est invalide, il le garde et ajoute le message suivant (ex: 99 -> auraauraaura99) puis retente. 5 mots max, ensuite il s'arrête.\n" ..
    "4. Dès que le redeem réussit, ou que le code est invalide au 5e mot, ou sold out, le code est oublié. Le script ignore tout (ex: 'okay what's next') jusqu'à la prochaine phrase comme 'code is' ou 'use code'."
)

makeQuestionSection(ScrollQuestions, "Conseils",
    "- Teste tes réglages avec 'Test Code' avant de farm.\n\n" ..
    "- Regarde les logs : si le message de succès du jeu n'est pas reconnu, ajoute son texte dans SUCCESS_PATTERNS.\n\n" ..
    "- Le mode 'Spam Redeem' peut faire ban si abusé, utilise-le avec modération."
)

local Pages = {
    { label = "Main",      page = PageMain },
    { label = "Tester",    page = PageTester },
    { label = "Settings",  page = PageSettings },
    { label = "Helper",    page = PageHelper },
    { label = "Themes",    page = PageThemes },
    { label = "Questions", page = PageQuestions },
}
local currentTab = nil
local function switchTab(index)
    if currentTab == index then return end
    local prev = currentTab
    currentTab = index
    for i, tab in ipairs(tabRefs) do
        local active = (i == index)
        tab.btn:SetAttribute("active", active)
        TweenService:Create(tab.btn, TweenInfo.new(0.25), { BackgroundTransparency = active and 0.82 or 1 }):Play()
        TweenService:Create(tab.lbl, TweenInfo.new(0.25), { TextColor3 = active and Theme.TextMain or Theme.TextSub }):Play()
        tab.indicator.Visible = active
    end
    if prev then Pages[prev].page.Visible = false end
    local newPage = Pages[index].page
    newPage.Visible = true
    newPage.Position = UDim2.new(0, 16, 0, 0)
    TweenService:Create(newPage, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
    PageTitle.Text = Pages[index].label
end
for i, def in ipairs(Pages) do
    local btn = makeTab(def.label, i - 1)
    btn.MouseButton1Click:Connect(function() switchTab(i) end)
end
switchTab(1)

local function updateStatus()
    local active = cfg.startScan
    StatusText.Text = active and "ON" or "OFF"
    StatusText.TextColor3 = active and Theme.Success or Theme.Danger
    StatusPill.BackgroundColor3 = active and Theme.Success or Theme.Danger
    StatusPill.BackgroundTransparency = 0.75
    for _, c in ipairs(StatusPill:GetChildren()) do
        if c:IsA("Frame") then c.BackgroundColor3 = active and Theme.Success or Theme.Danger end
        if c:IsA("UIStroke") then c.Color = active and Theme.Success or Theme.Danger end
    end
end
updateStatus()

local function sendRobloxNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 5 })
    end)
end

local function getCodeBoxAndConfirm()
    local ok, result = pcall(function()
        local Codes = PlayerGui:WaitForChild("Codes", 3).Codes
        return { box = Codes.CodeRedeem.TextBox, confirm = Codes.Confirm }
    end)
    if ok then return result end
    return nil
end

local function typeStringInBox(data, str)
    if not data or not data.box then return false end
    local frames = math.max(1, math.floor(tonumber(cfg.typingFrames) or 1))
    for i = 1, #str do
        if runtime.typingCancel then return false end
        local char = str:sub(i, i)
        pcall(function() data.box.Text = data.box.Text .. char end)
        waitFrames(frames)
    end
    return true
end

local function typingWorker()
    if runtime.typingBusy then return end
    runtime.typingBusy = true

    while #runtime.typingQueue > 0 do
        if runtime.typingCancel or not cfg.typeInsteadOfAdd then break end
        local data = getCodeBoxAndConfirm()
        if not data or not data.box then break end

        if not runtime.boxCleared then
            pcall(function() data.box:CaptureFocus() end)
            pcall(function() data.box.Text = "" end)
            runtime.boxCleared = true
        end

        local str = table.remove(runtime.typingQueue, 1)
        consoleLog("Typing: " .. str)
        typeStringInBox(data, str)
    end

    runtime.typingBusy = false
end

local function queueTyping(str)
    if not str or str == "" then return end
    table.insert(runtime.typingQueue, str)
    if not runtime.typingBusy then
        task.spawn(typingWorker)
    end
end

local function resetTyping()
    runtime.typingQueue = {}
    runtime.typingCancel = true
    RunService.Heartbeat:Wait()
    runtime.typingCancel = false
    runtime.typingBusy = false
    runtime.boxCleared = false
end

local function waitForTypingComplete(timeout)
    timeout = timeout or 30
    local start = tick()
    while (runtime.typingBusy or #runtime.typingQueue > 0) and (tick() - start < timeout) do
        RunService.Heartbeat:Wait()
    end
    RunService.Heartbeat:Wait()
    return (not runtime.typingBusy) and (#runtime.typingQueue == 0)
end

local function finalizeTyping()
    if not waitForTypingComplete(30) then consoleLog("Typing timeout, submitting anyway") end

    local data = getCodeBoxAndConfirm()
    if not data then return end
    pcall(function() firesignal(data.box.FocusLost, true) end)
    pcall(function() data.box:ReleaseFocus(true) end)
    local button = data.confirm:FindFirstChildWhichIsA("TextButton") or data.confirm
    if button then
        pcall(function() firesignal(button.MouseButton1Click) end)
        pcall(function() firesignal(button.Activated) end)
    end
    runtime.boxCleared = false
end

local function redeemCodeClassic(code)
    if not code or code == "" then return false end

    local ok = pcall(function()
        local Codes = PlayerGui:WaitForChild("Codes", 3).Codes
        local textBox = Codes.CodeRedeem.TextBox
        local confirmButton = Codes.Confirm

        local function executeRedeem()
            textBox.Text = code
            pcall(function() firesignal(textBox.FocusLost, true) end)
            local button = confirmButton:FindFirstChildWhichIsA("TextButton") or confirmButton
            if button then
                pcall(function() firesignal(button.MouseButton1Click) end)
                pcall(function() firesignal(button.Activated) end)
            end
        end

        if cfg.spamRedeem then
            local n = math.clamp(tonumber(cfg.spamCount) or 20, 1, 100)
            for i = 1, n do
                task.spawn(function()
                    if i > 1 then waitFrames(i - 1) end
                    executeRedeem()
                end)
            end
        else
            executeRedeem()
        end
    end)

    return ok
end

local function submitCode(code, retype)
    if not code or code == "" then return false end
    if cfg.typeInsteadOfAdd then
        if retype then
            resetTyping()
            queueTyping(code)
        end
        finalizeTyping()
        return true
    end
    return redeemCodeClassic(code)
end

local function sendWebhook(code, triggerText)
    if not cfg.sendWebhook or not httpRequest then return end
    local currentTime = os.date("%H:%M:%S")
    local description = string.format(
        "Sniper Triggered\nPlayer: %s (@%s)\nTrigger: %s\nCode: %s\nTime: %s",
        LocalPlayer.DisplayName, LocalPlayer.Name, tostring(triggerText or ""), tostring(code), currentTime
    )
    local embed = { description = description, color = 65280, footer = { text = "Weekly Code Sniper | " .. currentTime } }
    local body = HttpService:JSONEncode({ content = "@here", embeds = { embed } })
    pcall(function()
        httpRequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    end)
end

local function stripRich(text)
    if type(text) ~= "string" then return tostring(text) end
    return (text:gsub("<[^>]->", ""))
end

local function tokenize(text)
    local words = {}
    for word in text:gmatch("[%w_]+") do words[#words + 1] = word end
    return words
end

local INVALID_PATTERNS = {
    "invalid code", "invalid", "expired", "already redeemed", "already used",
    "not found", "rejected", "does not exist", "you have already",
}
local SOLD_PATTERNS = {
    "sold out", "soldout", "out of stock", "no longer available", "no more uses", "max redemptions", "fully redeemed",
}
local SUCCESS_PATTERNS = {
    "success", "redeemed", "you received", "you claimed", "reward",
}
local CODE_TRIGGERS = {
    "code is", "use code",
}

local function matchesAny(text, patterns)
    local l = tostring(text or ""):lower()
    for _, p in ipairs(patterns) do
        if l:find(p, 1, true) then return true end
    end
    return false
end

local function findTrigger(text)
    local flat = text:gsub("[%:%;%!%?%'%\"%*%#%&%-%+%(%)%/%@%.,]", " ")
    local low = flat:lower()
    for _, trig in ipairs(CODE_TRIGGERS) do
        local pat = (trig:gsub(" ", "%%s+"))
        local _, e = low:find(pat)
        if e then return trig, flat:sub(e + 1) end
    end
    return nil
end

local SYSTEM_PHRASES = {
    "font color", "fontcolour", "fontcolor", "font colour",
    "sammy has activated bubblegum machine",
    "sammy activated 2x luck", "sammy activated 6x luck",
    "sammy activated 8x luck", "sammy activated 10x luck",
    "sammy activated 12x luck", "sammy activated 15x luck",
    "sammy activated 20x luck", "sammy activated 25x luck",
    "sammy activated 30x luck", "sammy activated 35x luck",
    "sammy activated",
    "coins shop", "brainrot trader", "robux shop", "robuxshop",
    "spin wheel", "spinwheel", "trade plaza", "tradeplaza",
    "event has started", "eventhasstarted",
    "allowfriends", "setcreatorid", "to buy this", "tobuythis",
    "your base is already locked", "your base is full", "request failed",
    "you locked your base for", "you got a free spin",
    "broke into your base", "someone is stealing",
    "trade has been completed", "tradehasbeencompleted",
    "event has been activated", "has been activated", "has activated",
    "base is already locked", "you locked your base",
    "you have locked your base", "locked your base",
    "brainrot express has arrived", "brainrot express has arrv",
    "brainrot express leaving in",
}
local SYSTEM_PREFIXES = { "sammy:", "spydersammy:" }

local function compactText(s)
    return (stripRich(tostring(s or "")):lower():gsub("[^%w]", ""))
end

local systemCompact = {}
do
    local added = {}
    for _, phrase in ipairs(SYSTEM_PHRASES) do
        local c = compactText(phrase)
        if c ~= "" and not added[c] then
            added[c] = true
            systemCompact[#systemCompact + 1] = c
        end
    end
end

local function isSystemPhrase(text)
    local lower = stripRich(tostring(text or "")):lower()
    local noSpaces = lower:gsub("%s+", "")
    for _, p in ipairs(SYSTEM_PREFIXES) do
        if noSpaces:find(p, 1, true) then return true end
    end
    local c = compactText(lower)
    for _, entry in ipairs(systemCompact) do
        if c:find(entry, 1, true) then return true end
    end
    return false
end

local function setLastCode(code)
    runtime.lastCode = code
    LastCodeLabel.Text = code
end

local function showSequence()
    local s = runtime.pendingCode ~= "" and runtime.pendingCode or table.concat(runtime.parts)
    SeqLabel.Text = s ~= "" and s or "--"
end

local function resetRun(state)
    runtime.state = state
    runtime.parts = {}
    runtime.pendingCode = ""
    runtime.attempts = 0
    runtime.wc = 0
    showSequence()
end

local function submit(code, retype, wc)
    runtime.attempts = runtime.attempts + 1
    runtime.wc = wc or runtime.wc
    runtime.pendingCode = code
    runtime.parts = {}
    runtime.state = "pending"
    setLastCode(code)
    showSequence()

    if not cfg.autoSubmit then return end

    local attempt = runtime.attempts
    task.spawn(function()
        waitFrames(cfg.redeemFrames)
        submitCode(code, retype)
        consoleLog("Submitted: " .. code .. " (try " .. attempt .. ")")
        if attempt == 1 then
            sendWebhook(code, "Auto")
            sendRobloxNotification("GGBG Ta Redeem un Code", runtime.lastBrainrotName .. " Spawned!")
        end
    end)
end

local function addWords(words)
    for _, word in ipairs(words) do
        if #runtime.parts >= runtime.maxWords then break end
        table.insert(runtime.parts, word)
        if cfg.typeInsteadOfAdd and cfg.autoSubmit then queueTyping(word) end
    end

    local count = #runtime.parts
    local target = math.min(tonumber(cfg.submitAfter) or 3, runtime.maxWords)
    showSequence()
    consoleLog("Captured " .. count .. "/" .. target .. " [" .. table.concat(runtime.parts) .. "]")

    if count >= target then
        submit(table.concat(runtime.parts), false, count)
    end
end

local function startCollecting(rest)
    resetRun("collecting")
    resetTyping()
    local words = tokenize(rest or "")
    if #words > 0 then addWords(words) end
end

local function finishSuccess()
    consoleLog("Redeemed " .. runtime.pendingCode .. ", waiting for the next code announcement")
    resetRun("idle")
    resetTyping()
end

local function stopRun(msg)
    consoleLog(msg)
    resetRun("idle")
    resetTyping()
end

local function onAnnouncement(...)
    local text = stripRich(tostring((...) or ""))
    text = text:match("^%s*(.-)%s*$") or ""
    if text == "" then return end
    if runtime.seen[text] then return end
    runtime.seen[text] = true
    task.delay(1, function() runtime.seen[text] = nil end)

    local spawned = text:match("^(.-)%s+spawned!")
    if spawned and spawned ~= "" then
        runtime.lastBrainrotName = spawned
        consoleLog("Brainrot detected: " .. spawned)
    end

    if cfg.ignoreSystem and select(4, ...) ~= "Top" then return end

    if matchesAny(text, SOLD_PATTERNS) then
        if cfg.startScan and runtime.state ~= "idle" then stopRun("Sold out, waiting for the next trigger") end
        return
    end

    local trigger, rest = findTrigger(text)

    if runtime.state == "pending" and cfg.startScan then
        if matchesAny(text, INVALID_PATTERNS) then
            if runtime.wc >= runtime.maxWords then
                stopRun("Invalid at " .. runtime.maxWords .. " words, waiting for the next trigger")
            else
                consoleLog("Invalid, waiting for more of the code")
            end
            return
        end
        if matchesAny(text, SUCCESS_PATTERNS) and not trigger then
            stopRun("Redeemed " .. runtime.pendingCode .. ", waiting for the next trigger")
            return
        end
    end

    if trigger and cfg.autoStartOnCode and not cfg.startScan then
        cfg.startScan = true
        ScanBtn.Text = "SCANNING..."
        updateStatus(); saveConfig()
        resetRun("idle")
        consoleLog("Trigger (" .. trigger .. ") -> Start Scan ON")
    end

    if not cfg.startScan then return end
    consoleLog("Notification: [" .. text .. "]")

    if trigger then
        consoleLog("Trigger: " .. trigger)
        startCollecting(rest)
        return
    end

    if cfg.ignoreSystem and isSystemPhrase(text) then
        consoleLog("Ignored system message")
        return
    end

    if matchesAny(text, INVALID_PATTERNS) or matchesAny(text, SUCCESS_PATTERNS) then return end

    if runtime.state == "idle" then return end

    local words = tokenize(text)
    if #words == 0 then return end

    if runtime.state == "pending" then
        local room = runtime.maxWords - runtime.wc
        if room <= 0 then return end
        local take = {}
        for i = 1, math.min(#words, room) do take[i] = words[i] end
        local joined = runtime.pendingCode .. table.concat(take)
        consoleLog("Extending code: " .. joined)
        submit(joined, true, runtime.wc + #take)
        return
    end

    addWords(words)
end

local function resolveNotifyRemote()
    if runtime.notifyRemote and runtime.notifyRemote.Parent then return runtime.notifyRemote end
    local ok, ctrl = pcall(function() return require(ReplicatedStorage.Controllers:FindFirstChild("NotificationController", true)) end)
    if ok and type(ctrl) == "table" and type(ctrl.Start) == "function" and getupvalues then
        local ok2, ups = pcall(getupvalues, ctrl.Start)
        if ok2 and type(ups) == "table" then
            for _, v in pairs(ups) do
                if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent")) then
                    runtime.notifyRemote = v
                    return v
                end
            end
        end
    end
    return nil
end

startNotifListener = function()
    if runtime.notifConn or runtime.listening then return end
    runtime.listening = true
    task.spawn(function()
        local n = 0
        while not runtime.notifConn and ScreenGui.Parent do
            local remote = resolveNotifyRemote()
            if remote then
                runtime.notifConn = remote.OnClientEvent:Connect(function(...) pcall(onAnnouncement, ...) end)
                consoleLog("Notification listener attached")
                break
            end
            n = n + 1
            if n == 1 then consoleLog("Waiting for the notification remote") end
            task.wait(0.25)
        end
        runtime.listening = false
    end)
end

local function fireTestNotification(message)
    if not message or message == "" then return end
    local remote = resolveNotifyRemote()
    if remote and typeof(firesignal) == "function" then
        if pcall(firesignal, remote.OnClientEvent, message, nil, nil, "Top", 2678001507) then return end
    end
    pcall(onAnnouncement, message, nil, nil, "Top", 2678001507)
end

ScanBtn.MouseButton1Click:Connect(function()
    cfg.startScan = not cfg.startScan
    ScanBtn.Text = cfg.startScan and "SCANNING..." or "START SCAN"
    updateStatus(); saveConfig()
    if cfg.startScan then
        resetRun("idle")
        resetTyping()
        startNotifListener()
        consoleLog("Start Scan ON")
    else
        resetRun("idle")
        resetTyping()
    end
end)

ClearSeqBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        resetTyping()
        resetRun("idle")
        consoleLog("Sequence cleared, waiting for the next trigger")
    end)
end)

SubmitAfterBox.FocusLost:Connect(function()
    local n = tonumber(SubmitAfterBox.Text)
    cfg.submitAfter = (n and n >= 1) and math.floor(n) or 3
    SubmitAfterBox.Text = tostring(cfg.submitAfter)
    saveConfig()
end)

SpamCountBox.FocusLost:Connect(function()
    local n = tonumber(SpamCountBox.Text)
    cfg.spamCount = (n and n >= 1) and math.clamp(math.floor(n), 1, 100) or 20
    SpamCountBox.Text = tostring(cfg.spamCount)
    saveConfig()
end)

DelayBox.FocusLost:Connect(function()
    cfg.redeemFrames = math.clamp(math.floor(tonumber(DelayBox.Text) or 1), 1, 600)
    DelayBox.Text = tostring(cfg.redeemFrames)
    saveConfig()
end)

TypingSpeedBox.FocusLost:Connect(function()
    cfg.typingFrames = math.clamp(math.floor(tonumber(TypingSpeedBox.Text) or 1), 1, 600)
    TypingSpeedBox.Text = tostring(cfg.typingFrames)
    saveConfig()
end)

TestDelayBox.FocusLost:Connect(function()
    cfg.testDelay = math.max(0, math.min(10, tonumber(TestDelayBox.Text) or 1))
    TestDelayBox.Text = tostring(cfg.testDelay)
    saveConfig()
end)

SendBtn.MouseButton1Click:Connect(function() fireTestNotification(TestInput.Text) end)
ClearTestBtn.MouseButton1Click:Connect(function() TestInput.Text = "" end)

TestCodeBtn.MouseButton1Click:Connect(function()
    local delayTime = math.max(0, tonumber(cfg.testDelay) or 1)
    task.spawn(function()
        resetTyping()
        resetRun("collecting")
        fireTestNotification("CERB")
        task.wait(delayTime)
        fireTestNotification("IS")
        task.wait(delayTime)
        fireTestNotification("TUFF")
    end)
end)

RedeemBtn.MouseButton1Click:Connect(function()
    local code = runtime.lastCode
    if code and code ~= "" then
        task.spawn(function()
            if submitCode(code, true) then sendWebhook(code, "Manual") end
        end)
    end
end)

CopyBtn.MouseButton1Click:Connect(function()
    local code = runtime.lastCode
    if code and code ~= "" and setclipboard then pcall(setclipboard, code) end
end)

TestPingBtn.MouseButton1Click:Connect(function()
    task.spawn(function() submitCode("CERBISTUFF", true) end)
end)

PingBtn.MouseButton1Click:Connect(function()
    local ping = 0
    pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5) end)
    consoleLog(string.format("Ping: %d ms", ping))
end)

local function applyMinimize()
    if UI.Minimized then
        Main.Size = UDim2.new(0, 360, 0, 40)
        Sidebar.Visible = false; SepLine.Visible = false; Div.Visible = false; PageContainer.Visible = false
        MinimizeBtn.Text = "+"; MinimizeBtn.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
    else
        Main.Size = UI.Size
        Sidebar.Visible = true; SepLine.Visible = true; Div.Visible = true; PageContainer.Visible = true
        MinimizeBtn.Text = "-"; MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function()
    UI.Minimized = not UI.Minimized; cfg.minimized = UI.Minimized; applyMinimize(); saveConfig()
end)
applyMinimize()

CloseBtn.MouseButton1Click:Connect(function()
    if runtime.notifConn then pcall(function() runtime.notifConn:Disconnect() end) end
    stopHelpers()
    ScreenGui:Destroy()
end)

do
    local dragging, dragStart, startPos
    Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Main.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local StatsSvc = cloneref(game:GetService("Stats"))
local PF = new("TextLabel", {
    Name = "PingFps", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6),
    Size = UDim2.new(0, 200, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
    Text = "Ping -- | FPS --", TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 20,
}, ScreenGui)
local PFS = Instance.new("UIStroke")
PFS.Color = Color3.new(0, 0, 0); PFS.Thickness = 1.5; PFS.Parent = PF

task.spawn(function()
    local fr, acc = 0, 0
    local hc = RunService.Heartbeat:Connect(function(dt) fr = fr + 1; acc = acc + dt end)
    while ScreenGui.Parent do
        task.wait(0.5)
        local fps = acc > 0 and math.floor(fr / acc + 0.5) or 0
        fr, acc = 0, 0
        local ping = 0
        local ok = pcall(function() ping = math.floor(StatsSvc.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
        if not ok or ping <= 0 then
            pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5) end)
        end
        PF.Text = string.format("Ping %d ms | FPS %d", ping, fps)
    end
    hc:Disconnect()
end)

applyTheme(UI.CurrentTheme)
if cfg.startScan or cfg.autoStartOnCode then startNotifListener() end

Main.BackgroundTransparency = 1
TweenService:Create(Main, TweenInfo.new(0.4), { BackgroundTransparency = 0.2 }):Play()

getgenv = getgenv or function() return _G end
getgenv().StopWeeklySniper = function()
    if runtime.notifConn then pcall(function() runtime.notifConn:Disconnect() end) end
    stopHelpers()
    if ScreenGui then ScreenGui:Destroy() end
end
