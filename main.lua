-- ============================================================
-- SID'S AIMBOT & PERFORMANCE SUITE: EVOLUTION MAX (COMPLETE)
-- Complete Stable Jitter-Free Framework for Xeno
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

-- ============================================================
-- GLOBAL CONFIGURATION & SETTINGS
-- ============================================================
local Settings = {
    AimKey          = Enum.UserInputType.MouseButton2,
    AimbotEnabled   = false,
    TeamCheck       = true,
    WallCheck       = true,        -- Raycast checks to ignore enemies hidden behind cover
    TargetPart      = "Head",
    
    FOV             = 9999,
    PredictiveMove  = true,        
    PredictionMult  = 0.165,       
    
    Triggerbot      = false,       
    
    ChamsEnabled    = false,
    EnemyColor      = Color3.fromRGB(255, 10, 80),   
    TeamColor       = Color3.fromRGB(0, 235, 180),   
    
    HitboxesEnabled = false,
    HitboxSize      = 4.5,
    HitboxAlpha     = 0.3,
    
    FlyEnabled      = false,
    FlySpeed        = 100,
    
    SpeedEnabled    = false,
    WalkSpeed       = 120
}

local States = { IsAiming = false }
local flightAttachment, flightVelocity, flightConnection
local visualHitboxes, connectionTracks = {}, {}
local HITBOX_BASE = Vector3.new(4, 6, 2)
local PositionHistory = {}

-- ============================================================
-- RAYCAST WALL-CHECK VALIDATION
-- ============================================================
local function IsTargetVisible(targetChar, targetPart)
    if not Settings.WallCheck then return true end
    if not targetChar or not targetPart then return false end
    
    local Origin = Camera.CFrame.Position
    local Direction = (targetPart.Position - Origin)
    
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {LocalPlayer.Character, targetChar}
    Params.IgnoreWater = true
    
    local Result = Workspace:Raycast(Origin, Direction, Params)
    return Result == nil
end

-- ============================================================
-- POSITION & ESTIMATION UTILITIES (PREDICTION SYSTEM)
-- ============================================================
local function GetEstimatedVelocity(player, currentPos)
    if not PositionHistory[player] then
        PositionHistory[player] = { Pos = currentPos, Time = os.clock() }
        return Vector3.new(0, 0, 0)
    end
    local history = PositionHistory[player]
    local now = os.clock()
    local deltaTime = now - history.Time
    if deltaTime <= 0 then return Vector3.new(0,0,0) end
    local velocity = (currentPos - history.Pos) / deltaTime
    PositionHistory[player] = { Pos = currentPos, Time = now }
    return velocity
end

-- ============================================================
-- TARGETING RESOLVER FUNCTION
-- ============================================================
local function getOptimalTarget()
    if not Camera then return nil, nil end
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local ClosestTarget, MinDistance = nil, Settings.FOV
    local TargetPlayerReference = nil
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then 
            local isTeammate = (Settings.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team)
            if not isTeammate then
                local character = player.Character
                local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
                local targetPart = character and character:FindFirstChild(Settings.TargetPart)
                if character and humanoid and humanoid.Health > 0 and targetPart then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - Center).Magnitude
                        if distance < MinDistance then
                            if IsTargetVisible(character, targetPart) then
                                MinDistance = distance
                                ClosestTarget = targetPart
                                TargetPlayerReference = player
                            end
                        end
                    end
                end
            end
        end
    end
    return ClosestTarget, TargetPlayerReference
end

-- ============================================================
-- VISUAL GENERATION MODULATION (ESP Chams & Expanded Hitboxes)
-- ============================================================
local function cleanElements(player)
    if visualHitboxes[player] then
        pcall(function() visualHitboxes[player]:Destroy() end)
        visualHitboxes[player] = nil
    end
end

local function applyVisuals(player)
    local function processCharacter(char)
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart", 5) or char:FindFirstChild("HumanoidRootPart")
        local hum = char:WaitForChild("Humanoid", 5) or char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        
        local isTeammate = (Settings.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team)
        
        if Settings.ChamsEnabled and not isTeammate then
            local oldCham = char:FindFirstChild("SuiteCham")
            if oldCham then oldCham:Destroy() end
            
            local highlight = Instance.new("Highlight")
            highlight.Name = "SuiteCham"
            highlight.Adornee = char
            highlight.FillTransparency = 0.2
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = isTeammate and Settings.TeamColor or Settings.EnemyColor
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.Parent = char
        else
            local oldCham = char:FindFirstChild("SuiteCham")
            if oldCham then oldCham:Destroy() end
        end
        
        if Settings.HitboxesEnabled and player ~= LocalPlayer and not isTeammate then
            cleanElements(player)
            local hitboxPart = Instance.new("Part")
            hitboxPart.Name = "SuiteVisualHitbox"
            hitboxPart.CanCollide = false; hitboxPart.Anchored = false; hitboxPart.Massless = true
            hitboxPart.Transparency = Settings.HitboxAlpha; hitboxPart.Color = Settings.EnemyColor
            hitboxPart.Material = Enum.Material.Neon; hitboxPart.Size = HITBOX_BASE * Settings.HitboxSize
            hitboxPart.Parent = char
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = hrp; weld.Part1 = hitboxPart; weld.Parent = hitboxPart
            visualHitboxes[player] = hitboxPart
        else
            cleanElements(player)
        end
    end
    if connectionTracks[player] then connectionTracks[player]:Disconnect() end
    connectionTracks[player] = player.CharacterAdded:Connect(processCharacter)
    if player.Character then processCharacter(player.Character) end
end

local function updateWorldVisuals()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then applyVisuals(p) end
    end
end

Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then applyVisuals(p) end end)
Players.PlayerRemoving:Connect(function(p)
    if connectionTracks[p] then connectionTracks[p]:Disconnect() connectionTracks[p] = nil end
    cleanElements(p)
    PositionHistory[p] = nil
end)

-- ============================================================
-- LOCOMOTION HANDLING (Flight & WalkSpeed Updates)
-- ============================================================
local function setFly(state)
    Settings.FlyEnabled = state
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    if state then
        if flightAttachment then flightAttachment:Destroy() end
        if flightVelocity then flightVelocity:Destroy() end
        if flightConnection then flightConnection:Disconnect() end
        flightAttachment = Instance.new("Attachment", hrp)
        flightVelocity = Instance.new("LinearVelocity", hrp)
        flightVelocity.MaxForce = 9e9
        flightVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        flightVelocity.Attachment0 = flightAttachment
        hum.PlatformStand = true
        flightConnection = RunService.RenderStepped:Connect(function()
            if not Settings.FlyEnabled or not hrp.Parent or not flightVelocity.Parent then
                if flightConnection then flightConnection:Disconnect() end
                return
            end
            local moveDir = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0,1,0) end
            flightVelocity.VectorVelocity = moveDir.Magnitude > 0 and moveDir.Unit * Settings.FlySpeed or Vector3.new(0,0,0)
            hrp.Velocity = Vector3.new(0,0,0)
        end)
    else
        if flightConnection then flightConnection:Disconnect() flightConnection = nil end
        if flightVelocity then flightVelocity:Destroy() flightVelocity = nil end
        if flightAttachment then flightAttachment:Destroy() flightAttachment = nil end
        if hum then hum.PlatformStand = false end
    end
end

local function setSpeed(state)
    Settings.SpeedEnabled = state
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = state and Settings.WalkSpeed or 16 end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    if Settings.SpeedEnabled then setSpeed(true) end
    if Settings.FlyEnabled then setFly(true) end
end)

-- ============================================================
-- MAIN ENGINE TIMING PIPELINE (FIXED SHAKING OVERRIDE)
-- ============================================================
RunService.RenderStepped:Connect(function()
    local targetPart, targetPlayer = getOptimalTarget()
    
    -- Absolute Jitter-Free Lock Vector Injection
    if Settings.AimbotEnabled and States.IsAiming and targetPart and Camera then
        local targetPosition = targetPart.Position
        if Settings.PredictiveMove and targetPlayer then
            local estimatedVel = GetEstimatedVelocity(targetPlayer, targetPosition)
            targetPosition = targetPosition + (estimatedVel * Settings.PredictionMult)
        end
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    end
    
    if Settings.Triggerbot and targetPart then
        local mousePos = UserInputService:GetMouseLocation()
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if onScreen then
            local deltaDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
            if deltaDist <= (Settings.HitboxSize * 6) then
                pcall(function() mouse1click() end)
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Settings.AimKey then States.IsAiming = true end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Settings.AimKey then States.IsAiming = false end
end)
-- ============================================================
-- GLASSMORPHISM EVOLUTION DESIGN FRONTEND UI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false; ScreenGui.Name = "SidsEvolutionSuite"
pcall(function() ScreenGui.Parent = CoreGui end)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 275, 0, 485)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 14); UICorner.Parent = MainFrame

local GlowStroke = Instance.new("UIStroke")
GlowStroke.Thickness = 1.5
GlowStroke.Color = Color3.fromRGB(255, 10, 80)
GlowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
GlowStroke.Parent = MainFrame

local HeaderGradient = Instance.new("Frame")
HeaderGradient.Size = UDim2.new(1, 0, 0, 50)
HeaderGradient.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HeaderGradient.BorderSizePixel = 0
HeaderGradient.Parent = MainFrame

local HGCorner = Instance.new("UICorner")
HGCorner.CornerRadius = UDim.new(0, 14); HGCorner.Parent = HeaderGradient

local UIGradient = Instance.new("UIGradient")
UIGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 80)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 20))
}
UIGradient.Rotation = 45
UIGradient.Parent = HeaderGradient

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "SID'S AIMBOT"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = HeaderGradient

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -40, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
CloseBtn.BackgroundTransparency = 0.6
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = HeaderGradient

local CBCorner = Instance.new("UICorner")
CBCorner.CornerRadius = UDim.new(1, 0); CBCorner.Parent = CloseBtn

local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -32, 1, -75)
Container.Position = UDim2.new(0, 16, 0, 65)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 2
Container.ScrollBarImageColor3 = Color3.fromRGB(255, 10, 80)
Container.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = Container

local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 130, 0, 38)
OpenBtn.Position = UDim2.new(0.05, 0, 0.05, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
OpenBtn.BorderSizePixel = 0
OpenBtn.Text = "⚡ SID'S EVOLUTION"
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.TextSize = 11
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.Visible = false
OpenBtn.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 10); OpenCorner.Parent = OpenBtn

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Thickness = 1.5; OpenStroke.Color = Color3.fromRGB(255, 10, 80); OpenStroke.Parent = OpenBtn

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 275, 0, 0)}):Play()
    task.wait(0.22)
    MainFrame.Visible = false
    OpenBtn.Visible = true
end)

OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 275, 0, 485)}):Play()
end)

local function AddModularToggle(titleText, stateDefault, actionCallback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -4, 0, 42)
    Frame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    Frame.BorderSizePixel = 0
    Frame.Parent = Container
    
    local FCorner = Instance.new("UICorner")
    FCorner.CornerRadius = UDim.new(0, 8); FCorner.Parent = Frame
    
    local FStroke = Instance.new("UIStroke")
    FStroke.Thickness = 1
    FStroke.Color = Color3.fromRGB(28, 32, 42)
    FStroke.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 14, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = titleText
    Label.TextColor3 = Color3.fromRGB(195, 205, 220)
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamSemibold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Track = Instance.new("TextButton")
    Track.Size = UDim2.new(0, 36, 0, 20)
    Track.Position = UDim2.new(1, -50, 0.5, -10)
    Track.BackgroundColor3 = stateDefault and Color3.fromRGB(255, 10, 80) or Color3.fromRGB(35, 40, 50)
    Track.Text = ""
    Track.Parent = Frame
    
    local TCorner = Instance.new("UICorner")
    TCorner.CornerRadius = UDim.new(1, 0); TCorner.Parent = Track

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.Position = stateDefault and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Track
    
    local KCorner = Instance.new("UICorner")
    KCorner.CornerRadius = UDim.new(1, 0); KCorner.Parent = Knob

    local isToggled = stateDefault
    Track.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        actionCallback(isToggled)
        
        TweenService:Create(Track, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = isToggled and Color3.fromRGB(255, 10, 80) or Color3.fromRGB(35, 40, 50)
        }):Play()
        TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Cubic), {
            Position = isToggled and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        }):Play()
        TweenService:Create(FStroke, TweenInfo.new(0.2), {
            Color = isToggled and Color3.fromRGB(255, 10, 80) or Color3.fromRGB(28, 32, 42)
        }):Play()
    end)
end

-- ============================================================
-- CORE MATRIX SUBSYSTEM INITIALIZATION
-- ============================================================
AddModularToggle("Rage Engine Lock", Settings.AimbotEnabled, function(v) Settings.AimbotEnabled = v end)
AddModularToggle("Wall Visibility Check", Settings.WallCheck, function(v) Settings.WallCheck = v end)
AddModularToggle("Bullet Vector Prediction", Settings.PredictiveMove, function(v) Settings.PredictiveMove = v end)
AddModularToggle("Instant Crosshair Trigger", Settings.Triggerbot, function(v) Settings.Triggerbot = v end)
AddModularToggle("Exclude Teammates", Settings.TeamCheck, function(v) Settings.TeamCheck = v updateWorldVisuals() end)
AddModularToggle("Hyper Radiant Chams", Settings.ChamsEnabled, function(v) Settings.ChamsEnabled = v updateWorldVisuals() end)
AddModularToggle("Expanded Hitbox Cubes", Settings.HitboxesEnabled, function(v) Settings.HitboxesEnabled = v updateWorldVisuals() end)
AddModularToggle("Vector Air Flight", Settings.FlyEnabled, function(v) setFly(v) end)
AddModularToggle("Ground Speed Matrix", Settings.SpeedEnabled, function(v) setSpeed(v) end)

-- Smooth initial viewport entry animation sequence
MainFrame.Size = UDim2.new(0, 275, 0, 0)
MainFrame.Visible = true
TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 275, 0, 485)}):Play()

updateWorldVisuals()
