-- =================================================
-- Anti-Trip + Full Animation Eraser (Modern UI Center)
-- =================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local antiTripConnection = nil
local isEnabled = true

-- ==================== UI作成 ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiTripGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 140, 0, 60)
-- 画面中央に配置
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.new(0.5, 0, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true -- マウスで移動可能
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -20, 1, -20)
button.Position = UDim2.new(0, 10, 0, 10)
button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
button.Text = "でーもんさいきょーｗｗ"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextScaled = true
button.Font = Enum.Font.GothamBold
button.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = button

local function killAllAnimations(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    -- 再生中のトラックを全部停止
    for _, track in pairs(hum:GetPlayingAnimationTracks()) do
        track:Stop(0)
    end
    
    -- アニメーションデータ自体を空にする
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("Animation") then
            v.AnimationId = ""
        end
    end
end

local function startAntiTrip()
    if antiTripConnection then return end
    
    antiTripConnection = RunService.Stepped:Connect(function()
        local char = player.Character
        if not char then return end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not (root and hum) then return end

        -- 1. 転倒ステートを即解除
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll or 
           state == Enum.HumanoidStateType.FallingDown or 
           state == Enum.HumanoidStateType.PlatformStanding then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        
        local isJumping = hum.Jump or UserInputService:IsKeyDown(Enum.KeyCode.Space)
        if not isJumping then
            local vel = root.AssemblyLinearVelocity
            
            if state ~= Enum.HumanoidStateType.Freefall then
                root.AssemblyLinearVelocity = Vector3.new(vel.X, -0.8, vel.Z)
            end
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end

        
        for _, v in pairs(root:GetChildren()) do
            if v:IsA("BodyVelocity") or v:IsA("BodyForce") or v:IsA("LinearVelocity") then
                v:Destroy()
            end
        end

        
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end

        killAllAnimations(char)

        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("Motor6D") then
                v.Enabled = true
                v.Transform = CFrame.new() -- 直立姿勢にリセット
            end
        end
    end)
end

local function stopAntiTrip()
    if antiTripConnection then
        antiTripConnection:Disconnect()
        antiTripConnection = nil
    end
    
    local char = player.Character
    if char then
        local animate = char:FindFirstChild("Animate")
        if animate then
            animate.Disabled = false -- 歩行アニメを戻す
        end
    end
end

button.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    
    if isEnabled then
        startAntiTrip()
        button.Text = "でーもんさいきょーｗｗ"
        button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    else
        stopAntiTrip()
        button.Text = "of"
        button.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
    end
end)

startAntiTrip()
print("Anti-Trip & Animation Eraser Loaded (Centered UI)!")


local function makeFast(obj)
    if obj:IsA("ProximityPrompt") then
        obj.HoldDuration = 0
    end
end

-- 1. ゲーム起動時に、今あるプロンプトをすべて0秒にする
for _, v in pairs(workspace:GetDescendants()) do
    makeFast(v)
end

workspace.DescendantAdded:Connect(makeFast)

print("Fast Prompt Loaded: すべての長押しを0秒にしました")
