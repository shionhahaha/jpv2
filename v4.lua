-- =================================================
-- でーもんさいきょーｗｗ (TP & Base Auto-Detect)
-- =================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local myBaseFolder = nil
local isEnabled = true

-- ==================== UI作成 ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiTripGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 140, 0, 60)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.new(0.5, 0, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Active = true
frame.Draggable = true
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

-- ==================== 1. アンチ転倒 & アニメ消去 ====================
local function killAllAnimations(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, track in pairs(hum:GetPlayingAnimationTracks()) do track:Stop(0) end
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("Animation") then v.AnimationId = "" end
    end
end

RunService.Stepped:Connect(function()
    if not isEnabled then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then return end

    -- 転倒防止（GettingUp状態を強制）
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    
    -- アニメーション停止
    local animate = char:FindFirstChild("Animate")
    if animate then animate.Disabled = true end
    killAllAnimations(char)
end)

-- ==================== 2. ベースの自動特定 ====================
local function initializeMyBase()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local nb = workspace:FindFirstChild("NormalBase")
    if not (root and nb) then return end

    local closest = nil
    local dist = math.huge
    for _, folder in pairs(nb:GetChildren()) do
        local check = folder:FindFirstChild("Spawn") or folder:FindFirstChildWhichIsA("BasePart", true)
        if check then
            local d = (check.Position - root.Position).Magnitude
            if d < dist then dist = d; closest = folder end
        end
    end
    myBaseFolder = closest
    if myBaseFolder then print("ベース特定完了: " .. myBaseFolder.Name) end
end

-- ==================== 3. TP戻り処理 ====================
local function teleportAndBack()
    if not isEnabled then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    -- 登録されたベースからターゲットを探す
    local cash = myBaseFolder and myBaseFolder:FindFirstChild("Cash")
    local target = cash and cash:FindFirstChild("structure base home")

    if target and root then
        local oldPos = root.CFrame
        -- TP
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, target.Size.Y/2 + 5, 0))
        root.AssemblyLinearVelocity = Vector3.new(0,0,0)
        
        task.wait(1)
        
        -- 戻る
        root.CFrame = oldPos
        root.AssemblyLinearVelocity = Vector3.new(0,0,0)
    else
        warn("TP失敗: ベース未登録、またはパーツが見つかりません。")
    end
end

-- ==================== 4. イベント接続 ====================
button.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    if isEnabled then
        button.Text = "でーもんさいきょーｗｗ"
        button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    else
        button.Text = "OFF"
        button.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
    end
end)

local function apply(obj)
    if obj:IsA("ProximityPrompt") then
        obj.HoldDuration = 0
        obj.Triggered:Connect(teleportAndBack)
    end
end

-- 実行
initializeMyBase()
for _, v in pairs(workspace:GetDescendants()) do apply(v) end
workspace.DescendantAdded:Connect(apply)

print("Script Loaded: ノックバックあり設定で起動しました。")
