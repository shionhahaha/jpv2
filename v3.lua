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
-- =================================================
-- パーツの「真上」に安全に着地するTP
-- =================================================

local function teleportToTarget()
    -- 階層を安全に取得
    local target = workspace:FindFirstChild("NormalBase")
        and workspace.NormalBase:FindFirstChild("1")
        and workspace.NormalBase["1"]:FindFirstChild("Cash")
        and workspace.NormalBase["1"].Cash:FindFirstChild("structure base home")
    
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if target and root then
        -- 【計算】
        -- target.Position : パーツの中心
        -- target.Size.Y / 2 : パーツの表面（上端）
        -- 3.5 : キャラクターが埋まらないための余裕（足の長さ分）
        local spawnHeight = (target.Size.Y / 2) + 3.5
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, spawnHeight, 0))
        
        print("埋まり防止処理をしてTPしました。")
    else
        warn("TP先のパーツが見つかりませんでした。")
    end
end

-- プロンプト設定（既存の処理に組み込み）
local function setupPrompt(obj)
    if obj:IsA("ProximityPrompt") then
        obj.Triggered:Connect(function()
            task.wait(0.05) -- 実行の安定化
            teleportToTarget()
        end)
    end
end

for _, v in pairs(workspace:GetDescendants()) do setupPrompt(v) end
workspace.DescendantAdded:Connect(setupPrompt)
-- =================================================
-- TPして1秒後に元の位置へ戻る機能 (バグ修正版)
-- =================================================

local function teleportAndBack()
    -- 階層の再確認
    local nb = workspace:FindFirstChild("NormalBase")
    local model1 = nb and nb:FindFirstChild("1")
    local cash = model1 and model1:FindFirstChild("Cash")
    local target = cash and cash:FindFirstChild("structure base home")
    
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if target and root then
        -- 【1】現在の座標を完全に数値として保存（変数の上書き防止）
        local oldPos = root.CFrame
        print("現在の位置を保存しました: ", oldPos.Position)

        -- 【2】ターゲットの真上へ移動
        local spawnHeight = (target.Size.Y / 2) + 5 -- 少し高めに設定
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, spawnHeight, 0))
        
        -- 物理的な勢いをゼロにする（移動直後のズレ防止）
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        print("ターゲットへ移動完了。1秒待機します...")

        -- 【3】1秒待つ
        task.wait(1)

        -- 【4】元の座標へ強制送還
        root.CFrame = oldPos
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        print("元の位置に戻しました。")
    else
        warn("ターゲットまたは自分のパーツが見つかりません。階層を確認してください。")
    end
end

-- プロンプト設定の更新
local function applyHack(obj)
    if obj:IsA("ProximityPrompt") then
        obj.HoldDuration = 0
        -- 既存の接続があるかもしれないので、一度切断してから繋ぐのが理想ですが、
        -- 今回は単純にTriggeredに紐付けます
        obj.Triggered:Connect(function()
            teleportAndBack()
        end)
    end
end

for _, v in pairs(workspace:GetDescendants()) do applyHack(v) end
workspace.DescendantAdded:Connect(applyHack)
