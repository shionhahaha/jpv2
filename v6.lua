-- =================================================
-- ⚡ DEMON ULTIMATE EDITION (Advanced UI) ⚡
-- Target: NormalBase (All 0s, No TP on MyBase)
-- =================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local myBaseFolder = nil
local isEnabled = true

-- ==================== MODERN UI SYSTEM ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DemonUltraGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 150)
frame.Position = UDim2.new(0.5, -100, 0.5, -75)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 15)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Thickness = 2
frameStroke.Color = Color3.fromRGB(45, 45, 45)
frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
frameStroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "でーもんさいきょーｗｗ🤓🤓🤓"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.Parent = frame

local function applyModernStyle(btn, baseColor)
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 10)
    btn.BackgroundColor3 = baseColor
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 14
    btn.AutoButtonColor = false

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = baseColor:Lerp(Color3.new(1,1,1), 0.15), Size = UDim2.new(1, -15, 0, 38)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = baseColor, Size = UDim2.new(1, -20, 0, 35)}):Play()
    end)
end

local button = Instance.new("TextButton")
button.Name = "Toggle"
button.Size = UDim2.new(1, -20, 0, 35)
button.Position = UDim2.new(0, 10, 0, 45)
button.Text = "モード:オン"
button.Parent = frame
applyModernStyle(button, Color3.fromRGB(46, 204, 113))

local tpButton = Instance.new("TextButton")
tpButton.Name = "TPBase"
tpButton.Size = UDim2.new(1, -20, 0, 35)
tpButton.Position = UDim2.new(0, 10, 0, 95)
tpButton.Text = "ベースtp"
tpButton.Parent = frame
applyModernStyle(tpButton, Color3.fromRGB(52, 152, 219))

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

-- 座標が指定されたベース（モデル）の範囲内にあるか判定する関数
local function isInsideEnemyBase(targetPos)
    local nb = workspace:FindFirstChild("NormalBase")
    if not (nb and myBaseFolder) then return false end
    
    for _, base in pairs(nb:GetChildren()) do
        -- 自分のベース以外をチェック
        if base ~= myBaseFolder and base:IsA("Model") then
            -- モデル全体の中心座標とサイズを取得（GetBoundingBox）
            local cf, size = base:GetBoundingBox()
            local bPos = cf.Position
            
            -- 少し余裕を持たせるためにマージン（遊び）を追加
            local margin = 2 
            local minX, maxX = bPos.X - (size.X / 2) - margin, bPos.X + (size.X / 2) + margin
            local minZ, maxZ = bPos.Z - (size.Z / 2) - margin, bPos.Z + (size.Z / 2) + margin
            
            -- デバッグ用：判定範囲をプリント（うまくいかない時に確認用）
            -- print(string.format("Base %s Range: X(%.1f-%.1f) Z(%.1f-%.1f)", base.Name, minX, maxX, minZ, maxZ))

            if targetPos.X >= minX and targetPos.X <= maxX and
               targetPos.Z >= minZ and targetPos.Z <= maxZ then
                return true
            end
        end
    end
    return false
end

-- Animalsフォルダ内のキャラへTPするメイン関数
local function tpToEnemyAnimals()
    if not isEnabled then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local anims = workspace:FindFirstChild("Animals")
    if not (root and anims) then return end

    local targets = {}
    for _, obj in pairs(anims:GetChildren()) do
        -- 自分以外のモデルを対象
        if obj:IsA("Model") and obj.Name ~= player.Name then
            local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
            -- 「敵のベース内」にいる時だけリストに入れる
            if p and isInsideEnemyBase(p.Position) then
                table.insert(targets, p)
            end
        end
    end

    -- 見つかったターゲットからランダムにTP
    if #targets > 0 then
        local t = targets[math.random(1, #targets)]
        root.CFrame = t.CFrame + Vector3.new(0, 3, 0)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        print("⚡ 敵ベース内のキャラへTPしました")
    else
        print("❌ 敵ベース内にキャラが見つかりません（道にいるキャラは無視されました）")
    end
end

-- ==================== CORE FUNCTIONS ====================

local function killAllAnimations(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, track in pairs(hum:GetPlayingAnimationTracks()) do track:Stop(0) end
end

local function initializeMyBase()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local nb = workspace:FindFirstChild("NormalBase")
    if not (root and nb) then return end

    local closest, dist = nil, math.huge
    for _, folder in pairs(nb:GetChildren()) do
        local check = folder:FindFirstChild("Spawn") or folder:FindFirstChildWhichIsA("BasePart", true)
        if check then
            local d = (check.Position - root.Position).Magnitude
            if d < dist then dist = d; closest = folder end
        end
    end
    myBaseFolder = closest
end

local function teleportToBase()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local cash = myBaseFolder and myBaseFolder:FindFirstChild("Cash")
    local target = cash and cash:FindFirstChild("structure base home")

    if target and root then
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, 5, 0))
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    else
        initializeMyBase()
    end
end

-- ==================== ANTI-FALL & PROXIMITY LOGIC ====================

local function applyToPrompt(obj)
    if obj:IsA("ProximityPrompt") then
        -- 自分のベースかに関わらず、全部爆速（HoldDuration = 0）にする
        obj.HoldDuration = 0
        
        -- ボタンを押した時の処理
        obj.Triggered:Connect(function()
            if not isEnabled then return end
            
            -- もしこれが「自分のベースじゃない」時だけ、TPして戻る
            if myBaseFolder and not obj:IsDescendantOf(myBaseFolder) then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local cash = myBaseFolder:FindFirstChild("Cash")
                local target = cash and cash:FindFirstChild("structure base home")

                if target and root then
                    local oldPos = root.CFrame
                    root.CFrame = CFrame.new(target.Position + Vector3.new(0, 5, 0))
                    task.wait(0.3)
                    root.CFrame = oldPos
                end
            end
        end)
    end
end

local normalBase = workspace:WaitForChild("NormalBase")
initializeMyBase()

for _, v in pairs(normalBase:GetDescendants()) do applyToPrompt(v) end
normalBase.DescendantAdded:Connect(applyToPrompt)

-- 転倒防止ループ
RunService.Stepped:Connect(function()
    if not isEnabled then return end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        killAllAnimations(char)
    end
end)

-- フレームの高さを調整（ボタンが増えるため）
frame.Size = UDim2.new(0, 200, 0, 195) 

local animalTpBtn = Instance.new("TextButton", frame)
animalTpBtn.Name = "AnimalTP"
animalTpBtn.Size = UDim2.new(1, -20, 0, 35)
animalTpBtn.Position = UDim2.new(0, 10, 0, 145) -- 3つ目のボタンの位置
animalTpBtn.Text = "キャラtp(バグあると思う)"
applyModernStyle(animalTpBtn, Color3.fromRGB(39, 174, 96)) -- 緑色

-- クリックイベントの登録
animalTpBtn.MouseButton1Click:Connect(tpToEnemyAnimals)
-- UIボタン処理
button.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    button.Text = isEnabled and "モード:オン" or "モード:オフ"
    button.BackgroundColor3 = isEnabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)
end)

tpButton.MouseButton1Click:Connect(teleportToBase)

print("⚡ DEMON MENU: OPTIMIZED ⚡")
