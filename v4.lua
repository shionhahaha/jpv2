-- =================================================
-- でーもんさいきょーｗｗ (All-in-One Edition)
-- =================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local myBaseFolder = nil

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
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then return end

    -- 転倒防止
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    
    -- 空中制御
    if not (hum.Jump or UserInputService:IsKeyDown(Enum.KeyCode.Space)) then
        if state ~= Enum.HumanoidStateType.Freefall then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -0.8, root.AssemblyLinearVelocity.Z)
        end
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
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
    if myBaseFolder then print("ベース特定成功: " .. myBaseFolder.Name) end
end

-- ==================== 3. TP戻り処理 ====================
local function teleportAndBack()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local cash = myBaseFolder and myBaseFolder:FindFirstChild("Cash")
    local target = cash and cash:FindFirstChild("structure base home")

    if target and root then
        local oldPos = root.CFrame
        -- TP
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, target.Size.Y/2 + 4, 0))
        root.AssemblyLinearVelocity = Vector3.new(0,0,0)
        task.wait(1)
        -- 戻る
        root.CFrame = oldPos
        root.AssemblyLinearVelocity = Vector3.new(0,0,0)
    else
        warn("ベース未登録、またはパーツがありません。")
    end
end

-- ==================== 4. プロンプト適用 ====================
local function apply(obj)
    if obj:IsA("ProximityPrompt") then
        obj.HoldDuration = 0
        obj.Triggered:Connect(teleportAndBack)
    end
end

-- 実行開始
initializeMyBase()
for _, v in pairs(workspace:GetDescendants()) do apply(v) end
workspace.DescendantAdded:Connect(apply)

print("すべて完了！自分のベースに立ってから実行してね。")
