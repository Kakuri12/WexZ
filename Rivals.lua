--[[
    🏴 WexZ | RIVALS (Ultimate Version)
    Game: RIVALS (Roblox)
    Theme: Ultra Minimalist Black & White
    Features Added: Sticky Aim, Full Save Config, Fixed Keybind (U)
]]

-- ==========================================
-- 1. Services & Variables
-- ==========================================
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    CoreGui = game:GetService("CoreGui"),
    Workspace = game:GetService("Workspace"),
    TweenService = game:GetService("TweenService"),
    HttpService = game:GetService("HttpService"),
    Lighting = game:GetService("Lighting"),
    VirtualUser = game:GetService("VirtualUser")
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- Drawing (FOV Circle)
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness = 1
FOVCircle.Transparency = 0.5
FOVCircle.NumSides = 60
FOVCircle.Filled = false

-- Configuration Defaults
local Config = {
    -- Combat
    Aimbot = false,
    AimbotKey = Enum.UserInputType.MouseButton2,
    AimbotSmooth = 1,
    AimbotFOV = 150,
    ShowFOV = true,
    TeamCheck = true,
    WallCheck = true,
    
    -- Visuals
    ESP_Enabled = false,
    ESP_TeamCheck = true,
    
    -- Misc
    Speed = false,
    WalkSpeed = 24,
    JumpPower = 50,
    FullBright = false,
    AntiBan = false
}

-- State Management
local State = {
    OpenBtnPos = UDim2.new(0, 20, 0.5, 0),
    AimbotTarget = nil -- สำหรับ Sticky Aimbot
}

-- ==========================================
-- 2. Config Save/Load System
-- ==========================================
local ConfigFileName = "WexZ_Rivals_Settings.json"

local function SaveConfig()
    if writefile then
        local success, encoded = pcall(function() return Services.HttpService:JSONEncode(Config) end)
        if success then
            writefile(ConfigFileName, encoded)
        end
    end
end

local function LoadConfig()
    if readfile and isfile and isfile(ConfigFileName) then
        local success, decoded = pcall(function() return Services.HttpService:JSONDecode(readfile(ConfigFileName)) end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then
                    Config[k] = v
                end
            end
        end
    end
end

-- โหลดค่าตั้งแต่เริ่ม
LoadConfig()

-- ==========================================
-- 3. Game Logic (Aimbot & ESP)
-- ==========================================
-- Enhanced Team Check
local function IsTeammate(plr)
    if not Config.TeamCheck and not Config.ESP_TeamCheck then return false end
    if plr == LocalPlayer then return true end
    
    -- Roblox Default Team
    if plr.Team ~= nil and LocalPlayer.Team ~= nil then
        if plr.Team == LocalPlayer.Team then return true end
    end
    -- Rivals Custom Attribute (ถ้ามี)
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = plr:GetAttribute("Team")
    if myTeam ~= nil and theirTeam ~= nil then
        if myTeam == theirTeam then return true end
    end
    
    return false
end

-- Wall Check
local function IsVisible(targetPart, character)
    if not Config.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = Services.Workspace:Raycast(origin, direction, raycastParams)
    return not result -- ถ้าไม่ชน = มองเห็น
end

-- ตรวจสอบเป้าหมายสำหรับ Sticky Aim
local function IsValidTarget(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local char = targetPart.Parent
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not IsVisible(targetPart, char) then return false end
    
    local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    return true
end

-- หาเป้าหมายที่ใกล้เมาส์ที่สุด
local function GetClosestTarget()
    local closest = nil
    local shortestDistance = math.huge
    local mousePos = Services.UserInputService:GetMouseLocation()

    for _, plr in pairs(Services.Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if Config.TeamCheck and IsTeammate(plr) then continue end
            
            local char = plr.Character
            local humanoid = char:FindFirstChild("Humanoid")
            
            if humanoid and humanoid.Health > 0 then
                local targetPart = char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
                if targetPart and IsVisible(targetPart, char) then
                    local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local magnitude = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if magnitude < shortestDistance and magnitude <= Config.AimbotFOV then
                            closest = targetPart
                            shortestDistance = magnitude
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- Aimbot Loop
Services.RunService:BindToRenderStep("WexZAimbot", Enum.RenderPriority.Camera.Value + 1, function()
    -- อัปเดตวงกลม FOV
    FOVCircle.Visible = Config.ShowFOV
    FOVCircle.Radius = Config.AimbotFOV
    FOVCircle.Position = Services.UserInputService:GetMouseLocation()

    if Config.Aimbot and Services.UserInputService:IsMouseButtonPressed(Config.AimbotKey) then
        -- Sticky Aim: ล็อคเป้าเดิมไว้ ถ้าเป้าเดิมหายไป ค่อยหาคนใหม่
        if not State.AimbotTarget or not IsValidTarget(State.AimbotTarget) then
            State.AimbotTarget = GetClosestTarget()
        end

        local target = State.AimbotTarget
        if target then
            local currentCF = Camera.CFrame
            local targetPos = target.Position
            local targetCF = CFrame.new(currentCF.Position, targetPos)
            
            if Config.AimbotSmooth >= 1 then
                Camera.CFrame = targetCF
            else
                Camera.CFrame = currentCF:Lerp(targetCF, Config.AimbotSmooth)
            end
        end
    else
        State.AimbotTarget = nil -- เคลียร์เป้าเมื่อปล่อยเมาส์
    end
end)

-- ESP System
local function UpdateESP()
    if Config.ESP_Enabled then
        for _, plr in pairs(Services.Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                if Config.ESP_TeamCheck and IsTeammate(plr) then
                    if plr.Character:FindFirstChild("WexZ_ESP") then plr.Character.WexZ_ESP:Destroy() end
                    continue
                end

                if not plr.Character:FindFirstChild("WexZ_ESP") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "WexZ_ESP"
                    hl.Adornee = plr.Character
                    hl.FillColor = Color3.fromRGB(255, 255, 255)
                    hl.OutlineColor = Color3.fromRGB(0, 0, 0)
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.Parent = plr.Character
                end
            elseif plr.Character and plr.Character:FindFirstChild("WexZ_ESP") then
                plr.Character.WexZ_ESP:Destroy()
            end
        end
    else
        for _, plr in pairs(Services.Players:GetPlayers()) do
            if plr.Character and plr.Character:FindFirstChild("WexZ_ESP") then
                plr.Character.WexZ_ESP:Destroy()
            end
        end
    end
end

-- Misc Loop
Services.RunService.Stepped:Connect(function()
    pcall(function()
        if Config.Speed and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                hum.WalkSpeed = Config.WalkSpeed
                hum.JumpPower = Config.JumpPower
            end
        end
    end)
end)

spawn(function()
    while wait(0.5) do pcall(UpdateESP) end
end)

LocalPlayer.Idled:Connect(function()
    if Config.AntiBan then
        Services.VirtualUser:CaptureController()
        Services.VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- ==========================================
-- 4. UI Library & Construction
-- ==========================================
local Library = {}

function Library:Tween(obj, props, time)
    local tween = Services.TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

function Library:MakeDraggable(frame)
    local dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = input.Position
            startPos = frame.Position
            
            local moveConn, releaseConn
            moveConn = Services.UserInputService.InputChanged:Connect(function(moveInput)
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = moveInput.Position - dragStart
                    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
            releaseConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    moveConn:Disconnect()
                    releaseConn:Disconnect()
                end
            end)
        end
    end)
end

local ScreenGuiName = "WexZ_Rivals_UI"
local ExistingGui = Services.CoreGui:FindFirstChild(ScreenGuiName) or LocalPlayer.PlayerGui:FindFirstChild(ScreenGuiName)
if ExistingGui then ExistingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = ScreenGuiName
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling 
pcall(function() ScreenGui.Parent = Services.CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer.PlayerGui end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 20)
UICorner.Parent = MainFrame
Library:MakeDraggable(MainFrame)

-- Border
local Border = Instance.new("UIStroke")
Border.Thickness = 1
Border.Color = Color3.fromRGB(50, 50, 50)
Border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
Border.Parent = MainFrame

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 160, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 20)
SidebarCorner.Parent = Sidebar

local Logo = Instance.new("ImageLabel")
Logo.Image = "rbxassetid://73754386209589"
Logo.Size = UDim2.new(0, 40, 0, 40)
Logo.Position = UDim2.new(0, 15, 0, 15)
Logo.BackgroundTransparency = 1
Logo.Parent = Sidebar

local Title = Instance.new("TextLabel")
Title.Text = "WexZ"
Title.Font = Enum.Font.GothamBlack -- เปลี่ยนเป็นตัวหนาพิเศษ
Title.TextSize = 20 
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Size = UDim2.new(0, 80, 0, 20)
Title.Position = UDim2.new(0, 65, 0, 15)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
Title.Parent = Sidebar

local SubTitle = Instance.new("TextLabel")
SubTitle.Text = "RIVALS"
SubTitle.Font = Enum.Font.GothamBold -- เปลี่ยนเป็นตัวหนา
SubTitle.TextSize = 12 
SubTitle.TextColor3 = Color3.fromRGB(150, 150, 150) 
SubTitle.Size = UDim2.new(0, 80, 0, 15)
SubTitle.Position = UDim2.new(0, 65, 0, 35)
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.BackgroundTransparency = 1
SubTitle.Parent = Sidebar

-- Tabs Container
local TabsContainer = Instance.new("Frame")
TabsContainer.Size = UDim2.new(1, 0, 1, -80)
TabsContainer.Position = UDim2.new(0, 0, 0, 80)
TabsContainer.BackgroundTransparency = 1
TabsContainer.Parent = Sidebar
local TabsLayout = Instance.new("UIListLayout")
TabsLayout.Parent = TabsContainer
TabsLayout.Padding = UDim.new(0, 5)

-- Pages Container
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -160, 1, 0)
PagesContainer.Position = UDim2.new(0, 160, 0, 0)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

local Header = Instance.new("TextLabel")
Header.Text = "Dashboard"
Header.Font = Enum.Font.GothamBlack
Header.TextSize = 22
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Size = UDim2.new(1, -50, 0, 50)
Header.Position = UDim2.new(0, 20, 0, 0)
Header.TextXAlignment = Enum.TextXAlignment.Left
Header.BackgroundTransparency = 1
Header.Parent = PagesContainer

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "—"
CloseBtn.Font = Enum.Font.GothamBlack 
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = Color3.fromRGB(150, 150, 150) 
CloseBtn.BackgroundTransparency = 1 
CloseBtn.Size = UDim2.new(0, 40, 0, 40)
CloseBtn.Position = UDim2.new(1, -45, 0, 5)
CloseBtn.Parent = PagesContainer

local Pages = {}
local CurrentTab = nil

local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, -50)
    Page.Position = UDim2.new(0, 0, 0, 50)
    Page.BackgroundTransparency = 1
    Page.ScrollBarThickness = 0
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Visible = false
    Page.Parent = PagesContainer
    
    local Layout = Instance.new("UIListLayout")
    Layout.Parent = Page
    Layout.Padding = UDim.new(0, 8)
    
    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 5)
    Padding.PaddingLeft = UDim.new(0, 20)
    Padding.PaddingRight = UDim.new(0, 20)
    Padding.PaddingBottom = UDim.new(0, 10)
    Padding.Parent = Page
    
    Pages[name] = Page
    return Page
end

local function CreateTab(name)
    local Button = Instance.new("TextButton")
    Button.Text = name
    Button.Size = UDim2.new(1, -20, 0, 35)
    Button.Position = UDim2.new(0, 10, 0, 0)
    Button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Button.BackgroundTransparency = 1
    Button.TextColor3 = Color3.fromRGB(120, 120, 120)
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 13
    Button.Parent = TabsContainer
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button

    Button.MouseButton1Click:Connect(function()
        for _, btn in pairs(TabsContainer:GetChildren()) do
            if btn:IsA("TextButton") then
                Library:Tween(btn, {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(120, 120, 120)}, 0.2)
            end
        end
        for _, p in pairs(Pages) do p.Visible = false end
        Library:Tween(Button, {BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
        Pages[name].Visible = true
        Header.Text = name
    end)
    
    if CurrentTab == nil then
        CurrentTab = name
        Button.BackgroundTransparency = 0
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Pages[name].Visible = true
        Header.Text = name
    end
end

local function CreateToggle(page, text, configKey, callback)
    local defaultState = Config[configKey]
    
    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 45)
    Wrapper.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Wrapper.BorderSizePixel = 0
    Wrapper.Parent = page
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Wrapper
    
    local Label = Instance.new("TextLabel")
    Label.Text = text
    Label.Font = Enum.Font.GothamBold -- ทำให้ข้อความ Toggle หนาขึ้น
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.Size = UDim2.new(0.7, 0, 1, 0)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.BackgroundTransparency = 1
    Label.Parent = Wrapper
    
    local Switch = Instance.new("TextButton")
    Switch.Text = ""
    Switch.Size = UDim2.new(0, 40, 0, 20)
    Switch.Position = UDim2.new(1, -55, 0.5, -10)
    Switch.BackgroundColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 40, 40)
    Switch.Parent = Wrapper
    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = Switch
    
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = defaultState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    Knob.BackgroundColor3 = defaultState and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
    Knob.Parent = Switch
    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob
    
    local enabled = defaultState
    Switch.MouseButton1Click:Connect(function()
        enabled = not enabled
        Config[configKey] = enabled
        SaveConfig()
        
        if enabled then
            Library:Tween(Switch, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)})
            Library:Tween(Knob, {Position = UDim2.new(1, -18, 0.5, -8), BackgroundColor3 = Color3.fromRGB(0, 0, 0)})
        else
            Library:Tween(Switch, {BackgroundColor3 = Color3.fromRGB(40, 40, 40)})
            Library:Tween(Knob, {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = Color3.fromRGB(200, 200, 200)})
        end
        if callback then callback(enabled) end
    end)
    
    if enabled and callback then callback(enabled) end
end

local function CreateSlider(page, text, min, max, configKey, callback)
    local defaultVal = Config[configKey]
    
    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 55)
    Wrapper.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Wrapper.BorderSizePixel = 0
    Wrapper.Parent = page
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Wrapper

    local Label = Instance.new("TextLabel")
    Label.Text = text
    Label.Font = Enum.Font.GothamBold -- ทำให้ข้อความ Slider หนาขึ้น
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.Size = UDim2.new(1, -30, 0, 30)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.BackgroundTransparency = 1
    Label.Parent = Wrapper

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Text = tostring(defaultVal)
    ValueLabel.Font = Enum.Font.GothamBlack -- ตัวเลขหนาพิเศษ
    ValueLabel.TextSize = 12
    ValueLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    ValueLabel.Size = UDim2.new(0, 50, 0, 30)
    ValueLabel.Position = UDim2.new(1, -65, 0, 0)
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Parent = Wrapper

    local SliderBar = Instance.new("TextButton")
    SliderBar.Text = ""
    SliderBar.Size = UDim2.new(1, -30, 0, 4)
    SliderBar.Position = UDim2.new(0, 15, 0, 35)
    SliderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    SliderBar.Parent = Wrapper
    local BarCorner = Instance.new("UICorner")
    BarCorner.CornerRadius = UDim.new(1, 0)
    BarCorner.Parent = SliderBar

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((defaultVal - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Fill.Parent = SliderBar
    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill

    local isDragging = false
    local function Update(input)
        local delta = input.Position.X - SliderBar.AbsolutePosition.X
        local percent = math.clamp(delta / SliderBar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * percent)
        
        Fill.Size = UDim2.new(percent, 0, 1, 0)
        ValueLabel.Text = tostring(value)
        Config[configKey] = value
        SaveConfig()
        if callback then callback(value) end
    end

    SliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            Update(input)
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            Update(input)
        end
    end)
    Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
end

-- ==========================================
-- 5. Setup Menu Options
-- ==========================================
local PageCombat = CreatePage("Combat")
local PageVisuals = CreatePage("Visuals")
local PageMisc = CreatePage("Misc")

CreateTab("Combat")
CreateTab("Visuals")
CreateTab("Misc")

-- Combat Settings
CreateToggle(PageCombat, "Enable Aimbot", "Aimbot")
CreateToggle(PageCombat, "Show FOV Circle", "ShowFOV")
CreateToggle(PageCombat, "Team Check", "TeamCheck")
CreateToggle(PageCombat, "Wall Check (Visible Only)", "WallCheck")
CreateSlider(PageCombat, "Aimbot FOV Size", 10, 500, "AimbotFOV")
CreateSlider(PageCombat, "Aimbot Smoothness (10=Fast)", 1, 10, "AimbotSmooth", function(val)
    Config.AimbotSmooth = val / 10
end)

-- Visual Settings
CreateToggle(PageVisuals, "Player ESP", "ESP_Enabled", UpdateESP)
CreateToggle(PageVisuals, "ESP Team Check", "ESP_TeamCheck", UpdateESP)

-- Misc Settings
CreateToggle(PageMisc, "Speed & Jump Boost", "Speed", function(val)
    if not val and LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = 16; h.JumpPower = 50 end
    end
end)
CreateToggle(PageMisc, "Full Bright", "FullBright", function(val)
    if val then
        Services.Lighting.Brightness = 2
        Services.Lighting.ClockTime = 14
        Services.Lighting.FogEnd = 100000
    else
        Services.Lighting.Brightness = 1
        Services.Lighting.ClockTime = 12
        Services.Lighting.FogEnd = 1000
    end
end)
CreateToggle(PageMisc, "Anti-AFK", "AntiBan")

-- ==========================================
-- 6. Open / Close System (Keybind U & Minimize)
-- ==========================================
local OpenBtn = nil

local function CreateOpenButton()
    if OpenBtn then return end
    OpenBtn = Instance.new("ImageButton") -- กลับมาใช้ ImageButton
    OpenBtn.Name = "WexZ_OpenBtn"
    OpenBtn.Image = "rbxassetid://73754386209589" -- ใส่รูปโลโก้เดิม
    OpenBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    OpenBtn.Size = UDim2.new(0, 45, 0, 45)
    OpenBtn.Position = State.OpenBtnPos
    OpenBtn.BorderSizePixel = 0 -- สำคัญมาก! แก้ปัญหาขอบหนาด้านขวา (เอาขอบแฝงของ Roblox ออก)
    OpenBtn.AutoButtonColor = false
    OpenBtn.Parent = ScreenGui
    
    -- ใส่ Padding ให้ตัวรูปภาพหดเล็กลงมาอยู่ตรงกลาง ไม่ชนเส้นขอบ
    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 8)
    Padding.PaddingBottom = UDim.new(0, 8)
    Padding.PaddingLeft = UDim.new(0, 8)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.Parent = OpenBtn
    
    local C = Instance.new("UICorner")
    C.CornerRadius = UDim.new(0, 12)
    C.Parent = OpenBtn
    
    local S = Instance.new("UIStroke")
    S.Color = Color3.fromRGB(255, 255, 255)
    S.Thickness = 0
    S.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- บังคับเส้นขอบให้อยู่แค่รอบนอกกรอบพอดี ไม่ไปวาดตามรอยหยักของรูปภาพ
    S.LineJoinMode = Enum.LineJoinMode.Round
    S.Parent = OpenBtn

    local isDragging = false
    local dragStart, startPos

    OpenBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
            dragStart = input.Position
            startPos = OpenBtn.Position
            
            local moveConn, releaseConn
            moveConn = Services.UserInputService.InputChanged:Connect(function(moveInput)
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = moveInput.Position - dragStart
                    if delta.Magnitude > 3 then
                        isDragging = true
                        OpenBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                        State.OpenBtnPos = OpenBtn.Position
                    end
                end
            end)
            releaseConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    moveConn:Disconnect()
                    releaseConn:Disconnect()
                    if not isDragging then
                        MainFrame.Visible = true
                        OpenBtn:Destroy()
                        OpenBtn = nil
                    end
                end
            end)
        end
    end)
end

-- กดปุ่ม (-) มุมขวาบนเพื่อย่อ
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    CreateOpenButton()
end)

-- กดตัว U เพื่อเปิด/ปิด GUI ด่วน
Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.U then
        if MainFrame.Visible then
            -- ถ้าเปิดอยู่ ให้ปิด
            MainFrame.Visible = false
            CreateOpenButton()
        else
            -- ถ้าปิดอยู่ ให้เปิด และลบปุ่มย่อทิ้ง
            MainFrame.Visible = true
            if OpenBtn then
                OpenBtn:Destroy()
                OpenBtn = nil
            end
        end
    end
end)

print("🏴 WexZ Ultimate Version Loaded!")
