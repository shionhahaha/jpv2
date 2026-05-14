-- [[ Baikoku Hub - Ultimate Unified Edition (Fixed) ]] --
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VIM = game:GetService("VirtualInputManager") 
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

---------------------------------------------------------
-- 既存UIの削除
---------------------------------------------------------
pcall(function()
    if CoreGui:FindFirstChild("BaikokuHub_Final") then CoreGui.BaikokuHub_Final:Destroy() end
    if CoreGui:FindFirstChild("BaikokuHub_Unified") then CoreGui.BaikokuHub_Unified:Destroy() end
    if CoreGui:FindFirstChild("Baikoku_BountyTracker") then CoreGui.Baikoku_BountyTracker:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BaikokuHub_Unified"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

---------------------------------------------------------
-- Drawing APIの安全性チェック (Xeno対策)
---------------------------------------------------------
local HasDrawing = pcall(function() 
    local test = Drawing.new("Line")
    test:Remove() 
end)

---------------------------------------------------------
-- リモートイベントの取得
---------------------------------------------------------
local Net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
local RegisterAttack = Net and (Net:FindFirstChild("RE/RegisterAttack") or Net["RE/RegisterAttack"])
local RegisterHit = Net and (Net:FindFirstChild("RE/RegisterHit") or Net["RE/RegisterHit"])
local KickPlayerEvent = Net and (Net:FindFirstChild("RE/KickPlayer") or Net["RE/KickPlayer"])

---------------------------------------------------------
-- チーム自動参加
---------------------------------------------------------
pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", "Pirates") end)

---------------------------------------------------------
-- 制御変数 & ステータス (ボタンなし・完全オート起動)
---------------------------------------------------------
_G.AutoKill = true 
_G.AutoRespawn = true 
_G.AutoHaki = true 
_G.AutoV3_Active = true 
_G.AutoV4_Active = true 
_G.SelectedTarget = nil 
_G.ScriptPaused = false -- 一時停止用のフラグ

local espEnabled = true
local infoEnabled = true
local killCount = 0 
local playerKills = {} 
local currentAimTarget = nil

---------------------------------------------------------
-- バウンティ/時間 計算用関数
---------------------------------------------------------
local scriptStartTime = tick()
local initialBountyHub = 0

local function getRawBountyHub()
    local bounty = 0
    pcall(function()
        if LP:FindFirstChild("Data") then
            if LP.Data:FindFirstChild("Bounty") then
                bounty = LP.Data.Bounty.Value
            elseif LP.Data:FindFirstChild("Honor") then
                bounty = LP.Data.Honor.Value
            end
        end
    end)
    return tonumber(bounty) or 0
end

local function formatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(n)
    end
end

---------------------------------------------------------
-- 1ダメージ被弾時の自動リスポーン ＆ スポーン時10万上空TP
---------------------------------------------------------
local function SetupDamageRespawn(char)
    task.spawn(function()
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            task.wait(0.2)
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 100000, 0)
        end

        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        
        task.wait(0.5)
        local prevHealth = hum.Health
        
        hum.HealthChanged:Connect(function(newHealth)
            if not _G.ScriptPaused and newHealth < prevHealth then
                hum.Health = 0
            end
            prevHealth = newHealth
        end)
    end)
end

LP.CharacterAdded:Connect(SetupDamageRespawn)
if LP.Character then SetupDamageRespawn(LP.Character) end

---------------------------------------------------------
-- Invisible 状態管理 & 変数 (常時ON設定)
---------------------------------------------------------
local CombatSettings = {
    Invisible = true,
    AutoReveal = true,
}
local InvisibleParts = {}
local InvCharacterRef = nil
local InvHumanoidRef = nil
local InvRootPartRef = nil
local InvLastKnownCharacter = nil
local IsAttacking = false
local LastAttackTime = 0
local ATTACK_BUFFER = 0.3 
local SAFE_DROP_Y = 100000 

---------------------------------------------------------
-- PvP判定 ＆ ステータス取得関数 (高精度版)
---------------------------------------------------------
local function getPlayerPvPStatus(player)
    local inSafeZone = false
    
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
        local safeZones = worldOrigin and worldOrigin:FindFirstChild("SafeZones")
        
        if safeZones then
            for _, zone in ipairs(safeZones:GetChildren()) do
                if zone:IsA("BasePart") then
                    local radius = math.max(zone.Size.X, zone.Size.Z) / 2
                    local mesh = zone:FindFirstChild("Mesh")
                    if mesh then
                        radius = (zone.Size.X * mesh.Scale.X) / 2
                    end
                    
                    if (hrp.Position - zone.Position).Magnitude <= radius then
                        inSafeZone = true
                        break
                    end
                end
            end
        end
    end

    local pvpDisabled = player:GetAttribute("PvpDisabled") == true
    local isNeutral = player.Team == nil -- チーム未所属判定

    if isNeutral then
        return "未所属 (NEUTRAL)", Color3.fromRGB(150, 150, 150), false
    elseif pvpDisabled then
        return "PvP: OFF", Color3.fromRGB(255, 80, 80), false
    elseif inSafeZone then
        return "SAFE ZONE", Color3.fromRGB(100, 180, 255), false 
    else
        return "PvP: ON", Color3.fromRGB(100, 255, 150), true
    end
end

local function IsPvpEnabled(player)
    local _, _, isAttackable = getPlayerPvPStatus(player)
    return isAttackable
end

---------------------------------------------------------
-- 1秒間に1回の厳格なターゲット検知
---------------------------------------------------------
_G.LivePvPTargets = {}
task.spawn(function()
    while task.wait(1) do 
        local currentTargets = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                local statusText, statusColor, isAttackable = getPlayerPvPStatus(p)
                if isAttackable then
                    table.insert(currentTargets, p)
                end
            end
        end
        _G.LivePvPTargets = currentTargets
    end
end)

---------------------------------------------------------
-- UI作成 (リニューアル版＋サイバーアニメーション＆発光追加)
---------------------------------------------------------
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 40, 50) 
MainFrame.BackgroundTransparency = 1 
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true 
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Transparency = 1 
MainStroke.Thickness = 2.5
local StrokeGradient = Instance.new("UIGradient", MainStroke)
StrokeGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 200)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 50, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 200))
}

task.spawn(function()
    local rot = 0
    while task.wait(0.02) do
        rot = rot + 2
        if rot >= 360 then rot = 0 end
        StrokeGradient.Rotation = rot
    end
end)

-- ■■ 左側：ステータスエリア ■■
local LeftArea = Instance.new("Frame", MainFrame)
LeftArea.Size = UDim2.new(0.45, -10, 1, -20)
LeftArea.Position = UDim2.new(0, 20, 0, 20)
LeftArea.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", LeftArea)
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBlack
Title.Text = "BAIKOKU HUB"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 34 
Title.TextXAlignment = Enum.TextXAlignment.Left
local TitleGradient = Instance.new("UIGradient", Title)
TitleGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 255))
}
local TitleStroke = Instance.new("UIStroke", Title)
TitleStroke.Color = Color3.fromRGB(0, 0, 0)
TitleStroke.Transparency = 0.3
TitleStroke.Thickness = 1.5

local AvatarFrame = Instance.new("Frame", LeftArea)
AvatarFrame.Size = UDim2.new(0, 75, 0, 75) 
AvatarFrame.Position = UDim2.new(1, -85, 0, -10) 
AvatarFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
AvatarFrame.ClipsDescendants = true
Instance.new("UICorner", AvatarFrame).CornerRadius = UDim.new(1, 0)
local AvatarStroke = Instance.new("UIStroke", AvatarFrame)
AvatarStroke.Color = Color3.fromRGB(0, 255, 200)
AvatarStroke.Thickness = 2

local AvatarImg = Instance.new("ImageLabel", AvatarFrame)
AvatarImg.Size = UDim2.new(0.9, 0, 0.9, 0) 
AvatarImg.Position = UDim2.new(0.05, 0, 0.05, 0) 
AvatarImg.BackgroundTransparency = 1
AvatarImg.ScaleType = Enum.ScaleType.Stretch
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0) 
pcall(function()
    AvatarImg.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
end)

local StatsContainer = Instance.new("Frame", LeftArea)
StatsContainer.Size = UDim2.new(1, 0, 0, 250) 
StatsContainer.Position = UDim2.new(0, 0, 0, 70)
StatsContainer.BackgroundTransparency = 1

local UIListLayoutStats = Instance.new("UIListLayout", StatsContainer)
UIListLayoutStats.Padding = UDim.new(0, 10) 

local InfoTitle = Instance.new("TextLabel")
InfoTitle.Size = UDim2.new(1, 0, 0, 25)
InfoTitle.BackgroundTransparency = 1
InfoTitle.Font = Enum.Font.GothamBlack 
InfoTitle.Text = "PLAYER STATS"
InfoTitle.TextColor3 = Color3.fromRGB(0, 255, 200)
InfoTitle.TextSize = 20
InfoTitle.TextXAlignment = Enum.TextXAlignment.Left
InfoTitle.Parent = StatsContainer
local InfoTitleStroke = Instance.new("UIStroke", InfoTitle)
InfoTitleStroke.Color = Color3.fromRGB(0, 0, 0)
InfoTitleStroke.Thickness = 1

local function createStatLabel(textStr)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22) 
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold 
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255) 
    lbl.TextSize = 16 
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = textStr
    lbl.Parent = StatsContainer
    
    local textShadow = Instance.new("UIStroke", lbl)
    textShadow.Color = Color3.fromRGB(0, 0, 0)
    textShadow.Transparency = 0.2 
    textShadow.Thickness = 1
    
    return lbl
end

local LblLevel = createStatLabel("Level: Loading...")
local LblBounty = createStatLabel("Bounty Earned: 0")
local LblKills = createStatLabel("Total Kills: 0") 
local LblPing = createStatLabel("Ping: -- ms")
local LblTime = createStatLabel("Time Elapsed: 00M 00S")
local LblHopTimer = createStatLabel("鯖ホイップ時間: 01分00秒") 
local LblDamageTimer = createStatLabel("攻撃判定: 待機中") 

local StatusBottom = Instance.new("TextLabel", LeftArea)
StatusBottom.Size = UDim2.new(1, 0, 0, 20)
StatusBottom.Position = UDim2.new(0, 0, 1, -20)
StatusBottom.BackgroundTransparency = 1
StatusBottom.Font = Enum.Font.GothamBlack
StatusBottom.TextColor3 = Color3.fromRGB(100, 255, 150)
StatusBottom.TextSize = 16
StatusBottom.TextXAlignment = Enum.TextXAlignment.Left
StatusBottom.Text = "TP攻撃中: 待機"
local StatusBottomStroke = Instance.new("UIStroke", StatusBottom)
StatusBottomStroke.Color = Color3.fromRGB(0, 0, 0)
StatusBottomStroke.Thickness = 1.2

---------------------------------------------------------
-- ★【本体UIに統合】Bounty Earned Tracker (Ultra Minimalist Edition) ★
---------------------------------------------------------
task.spawn(function()
    -- 本体(LeftArea)の左下、StatusBottomの上に組み込み
    local TrackerFrame = Instance.new("Frame")
    TrackerFrame.Size = UDim2.new(0, 0, 0, 0) -- アニメーション用
    TrackerFrame.Position = UDim2.new(0, 0, 1, -85) -- 本体左下に固定
    TrackerFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    TrackerFrame.BackgroundTransparency = 0.15
    TrackerFrame.BorderSizePixel = 0
    TrackerFrame.Parent = LeftArea
    Instance.new("UICorner", TrackerFrame).CornerRadius = UDim.new(0, 8)

    local Stroke = Instance.new("UIStroke", TrackerFrame)
    Stroke.Color = Color3.fromRGB(0, 255, 200)
    Stroke.Thickness = 2.5
    Stroke.Transparency = 0.2
    local Gradient = Instance.new("UIGradient", Stroke)
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 200)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 50, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 200))
    }

    task.spawn(function()
        local rot = 0
        while task.wait(0.02) do
            rot = rot + 2
            if rot >= 360 then rot = 0 end
            Gradient.Rotation = rot
        end
    end)

    local BigBountyLabel = Instance.new("TextLabel", TrackerFrame)
    BigBountyLabel.Size = UDim2.new(1, 0, 1, 0)
    BigBountyLabel.Position = UDim2.new(0, 0, 0, 0)
    BigBountyLabel.BackgroundTransparency = 1
    BigBountyLabel.Font = Enum.Font.GothamBlack
    BigBountyLabel.Text = "読込中..."
    BigBountyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    BigBountyLabel.TextSize = 34
    BigBountyLabel.TextXAlignment = Enum.TextXAlignment.Center
    local BountyStroke = Instance.new("UIStroke", BigBountyLabel)
    BountyStroke.Color = Color3.fromRGB(0, 0, 0)
    BountyStroke.Thickness = 2 

    local function commaValue(n)
        local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
        return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
    end

    local function getTrackerBounty()
        local bounty = 0
        pcall(function()
            local ls = LP:FindFirstChild("leaderstats")
            if ls and ls:FindFirstChild("Bounty/Honor") then
                local valStr = tostring(ls["Bounty/Honor"].Value)
                valStr = string.gsub(valStr, ",", "")
                bounty = tonumber(valStr) or 0
            end
            if bounty == 0 and LP:FindFirstChild("Data") then
                if LP.Data:FindFirstChild("Bounty") and LP.Data.Bounty.Value > 0 then
                    bounty = tonumber(LP.Data.Bounty.Value)
                elseif LP.Data:FindFirstChild("Honor") and LP.Data.Honor.Value > 0 then
                    bounty = tonumber(LP.Data.Honor.Value)
                end
            end
        end)
        return tonumber(bounty) or 0
    end

    local initialTrackerBounty = 0
    local isInitialized = false

    task.spawn(function()
        while task.wait(0.5) do
            local currentBounty = getTrackerBounty()
            if not isInitialized then
                if currentBounty > 0 then
                    initialTrackerBounty = currentBounty
                    isInitialized = true
                    BigBountyLabel.Text = "0"
                    BigBountyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            else
                local earned = currentBounty - initialTrackerBounty
                if earned > 0 then
                    BigBountyLabel.Text = commaValue(earned)
                    BigBountyLabel.TextColor3 = Color3.fromRGB(100, 255, 150) 
                elseif earned < 0 then
                    BigBountyLabel.Text = commaValue(earned)
                    BigBountyLabel.TextColor3 = Color3.fromRGB(255, 100, 100) 
                else
                    BigBountyLabel.Text = "0"
                    BigBountyLabel.TextColor3 = Color3.fromRGB(200, 200, 200) 
                end
            end
        end
    end)

    -- Trackerの起動アニメーション (本体表示より少し遅らせてカッコよく展開)
    task.wait(0.5)
    TweenService:Create(TrackerFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 220, 0, 60)}):Play()
end)
---------------------------------------------------------

-- ■■ 右側：ターゲットリストエリア ■■
local RightArea = Instance.new("Frame", MainFrame)
RightArea.Size = UDim2.new(0.55, -20, 1, -40) 
RightArea.Position = UDim2.new(0.45, 10, 0, 20)
RightArea.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
RightArea.BackgroundTransparency = 0.3
Instance.new("UICorner", RightArea).CornerRadius = UDim.new(0, 10)
local RightStroke = Instance.new("UIStroke", RightArea)
RightStroke.Color = Color3.fromRGB(80, 90, 110)
RightStroke.Transparency = 0
RightStroke.Thickness = 1.5

local TargetListTitle = Instance.new("TextLabel", RightArea)
TargetListTitle.Size = UDim2.new(1, 0, 0, 40)
TargetListTitle.Position = UDim2.new(0, 10, 0, 0)
TargetListTitle.BackgroundTransparency = 1
TargetListTitle.Font = Enum.Font.GothamBlack
TargetListTitle.Text = "LIVE TARGETS"
TargetListTitle.TextColor3 = Color3.fromRGB(150, 150, 255)
TargetListTitle.TextSize = 20
TargetListTitle.TextXAlignment = Enum.TextXAlignment.Left

local PlayerListArea = Instance.new("ScrollingFrame", RightArea)
PlayerListArea.Size = UDim2.new(1, -20, 1, -50)
PlayerListArea.Position = UDim2.new(0, 10, 0, 40)
PlayerListArea.BackgroundTransparency = 1
PlayerListArea.ScrollBarThickness = 5 
PlayerListArea.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
local UIListLayout = Instance.new("UIListLayout", PlayerListArea)
UIListLayout.Padding = UDim.new(0, 8)

-- ★ 本体の起動アニメーション実行 ★
local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local goal = {
    Size = UDim2.new(0, 750, 0, 450),
    Position = UDim2.new(0.5, -375, 0.5, -225),
    BackgroundTransparency = 0.15
}
local openTween = TweenService:Create(MainFrame, tweenInfo, goal)
openTween:Play()

task.spawn(function()
    task.wait(0.3)
    TweenService:Create(MainStroke, TweenInfo.new(0.5), {Transparency = 0.2}):Play()
end)

---------------------------------------------------------
-- UI ステータス更新ループ 
---------------------------------------------------------
local isHopping = false 

task.spawn(function()
    while task.wait(0.5) do
        local levelVal = 0
        pcall(function()
            if LP:FindFirstChild("Data") and LP.Data:FindFirstChild("Level") then
                levelVal = LP.Data.Level.Value
            end
        end)
        if levelVal > 0 then LblLevel.Text = "Level: " .. tostring(levelVal) end

        local currentBounty = getRawBountyHub()
        if initialBountyHub == 0 and currentBounty > 0 then
            initialBountyHub = currentBounty
        end
        local earned = math.max(0, currentBounty - initialBountyHub)
        LblBounty.Text = "Bounty Earned: " .. formatNumber(earned)

        LblKills.Text = "Total Kills: " .. tostring(killCount)

        local pingVal = 0
        pcall(function()
            pingVal = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        LblPing.Text = string.format("Ping: %d ms", pingVal)

        local elapsed = tick() - scriptStartTime
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = math.floor(elapsed % 60)
        if h > 0 then
            LblTime.Text = string.format("Time Elapsed: %02dH %02dM %02dS", h, m, s)
        else
            LblTime.Text = string.format("Time Elapsed: %02dM %02dS", m, s)
        end
        
        local timeLeft = math.max(0, 60 - elapsed)
        local hopM = math.floor(timeLeft / 60)
        local hopS = math.floor(timeLeft % 60)
        LblHopTimer.Text = string.format("鯖ホイップ時間: %02d分%02d秒", hopM, hopS) 
        if timeLeft <= 10 then
            LblHopTimer.TextColor3 = Color3.fromRGB(255, 80, 80)
        else
            LblHopTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        
        if isHopping then
            -- ホップ中
        elseif _G.ScriptPaused then
            StatusBottom.Text = "TP攻撃中: 一時停止中(帰還)"
            StatusBottom.TextColor3 = Color3.fromRGB(255, 200, 50)
        else
            StatusBottom.TextColor3 = Color3.fromRGB(100, 255, 150) 
            if currentAimTarget and currentAimTarget.Parent then
                StatusBottom.Text = "TP攻撃中: " .. currentAimTarget.Parent.Name
            else
                if StatusBottom.Text:find("サーバー移動中") == nil then
                    StatusBottom.Text = "TP攻撃中: 索敵中..."
                end
            end
        end
    end
end)

---------------------------------------------------------
-- リスト更新 ＆ HPバー＋装備レベル表示ロジック
---------------------------------------------------------
local playerButtons = {}
local ActiveHealthBars = {} 

local function UpdatePlayerList()
    for _, btn in pairs(playerButtons) do btn:Destroy() end
    table.clear(playerButtons)
    table.clear(ActiveHealthBars)
    
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local sortedPlayers = {}
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local dist = math.huge
            if myRoot and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                dist = (myRoot.Position - p.Character.HumanoidRootPart.Position).Magnitude
            end
            table.insert(sortedPlayers, {Player = p, Dist = dist})
        end
    end
    
    table.sort(sortedPlayers, function(a, b) return a.Dist < b.Dist end)
    
    local yOffset = 0
    for _, data in ipairs(sortedPlayers) do
        local p = data.Player
        local statusText, statusColor, isAttackable = getPlayerPvPStatus(p)
        
        local targetHp = 0
        local targetMaxHp = 100
        local pct = 0
        if p.Character and p.Character:FindFirstChild("Humanoid") then
            targetHp = math.floor(p.Character.Humanoid.Health)
            targetMaxHp = p.Character.Humanoid.MaxHealth > 0 and p.Character.Humanoid.MaxHealth or 100
            pct = math.clamp(targetHp / targetMaxHp, 0, 1)
        end

        local targetLevel = "???"
        if p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") then
            targetLevel = tostring(p.Data.Level.Value)
        end
        local targetWeapon = "素手"
        if p.Character and p.Character:FindFirstChildOfClass("Tool") then
            targetWeapon = p.Character:FindFirstChildOfClass("Tool").Name
        end
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 50)  
        btn.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.ZIndex = 5
        btn.Parent = PlayerListArea
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        local stroke = Instance.new("UIStroke", btn)
        stroke.Thickness = 1.5
        
        if _G.SelectedTarget == p then
            stroke.Color = Color3.fromRGB(0, 255, 200) 
            stroke.Thickness = 2.5
            stroke.Transparency = 0
            btn.BackgroundColor3 = Color3.fromRGB(50, 60, 75)
        else
            stroke.Color = statusColor
            stroke.Transparency = 0.4
        end

        local nameLbl = Instance.new("TextLabel", btn)
        nameLbl.Size = UDim2.new(0.75, 0, 0, 30)
        nameLbl.Position = UDim2.new(0, 10, 0, 4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = string.format("Lv.%s %s | %s (HP:%d)", targetLevel, p.Name, targetWeapon, targetHp) 
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255) 
        nameLbl.Font = Enum.Font.GothamBold 
        nameLbl.TextSize = 12 
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex = 6
        local nameStroke = Instance.new("UIStroke", nameLbl)
        nameStroke.Color = Color3.fromRGB(0, 0, 0)
        nameStroke.Transparency = 0.2
        nameStroke.Thickness = 1.2

        local statusLbl = Instance.new("TextLabel", btn)
        statusLbl.Size = UDim2.new(0.25, -10, 0, 30) 
        statusLbl.Position = UDim2.new(0.75, 0, 0, 4)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Text = statusText
        statusLbl.TextColor3 = statusColor
        statusLbl.Font = Enum.Font.GothamBlack 
        statusLbl.TextSize = 13
        statusLbl.TextXAlignment = Enum.TextXAlignment.Right
        statusLbl.ZIndex = 6
        local statusStroke = Instance.new("UIStroke", statusLbl)
        statusStroke.Color = Color3.fromRGB(0, 0, 0)
        statusStroke.Transparency = 0.2
        statusStroke.Thickness = 1.2

        local hpBg = Instance.new("Frame", btn)
        hpBg.Size = UDim2.new(0.95, 0, 0, 6)
        hpBg.Position = UDim2.new(0.025, 0, 1, -10)
        hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        hpBg.BorderSizePixel = 0
        Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)

        local hpBar = Instance.new("Frame", hpBg)
        hpBar.Size = UDim2.new(pct, 0, 1, 0)
        hpBar.BackgroundColor3 = Color3.fromRGB(0, 180, 80) 
        hpBar.BorderSizePixel = 0
        Instance.new("UICorner", hpBar).CornerRadius = UDim.new(1, 0)
        
        ActiveHealthBars[p] = {Bar = hpBar, Lbl = nameLbl}
        
        btn.MouseButton1Click:Connect(function()
            if _G.SelectedTarget == p then
                _G.SelectedTarget = nil
                currentAimTarget = nil
            else
                _G.SelectedTarget = p
            end
            UpdatePlayerList()
        end)
        
        table.insert(playerButtons, btn)
        yOffset = yOffset + 58 
    end
    PlayerListArea.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

task.spawn(function()
    while task.wait(2) do UpdatePlayerList() end
end)

-- HPバーと数値・装備の0.1秒間隔リアルタイム更新
task.spawn(function()
    while task.wait(0.1) do
        for p, data in pairs(ActiveHealthBars) do
            if p and p.Character and p.Character:FindFirstChild("Humanoid") then
                local hum = p.Character.Humanoid
                local hp = math.floor(hum.Health)
                local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
                local pct = math.clamp(hp / maxHp, 0, 1)

                local targetLevel = "???"
                if p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") then
                    targetLevel = tostring(p.Data.Level.Value)
                end
                local targetWeapon = "素手"
                local tool = p.Character:FindFirstChildOfClass("Tool")
                if tool then
                    targetWeapon = tool.Name
                end
                
                pcall(function()
                    TweenService:Create(data.Bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
                    
                    data.Lbl.Text = string.format("Lv.%s %s | %s (HP:%d)", targetLevel, p.Name, targetWeapon, hp)
                    
                    if pct > 0.5 then
                        data.Bar.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
                    elseif pct > 0.2 then
                        data.Bar.BackgroundColor3 = Color3.fromRGB(180, 160, 0)
                    else
                        data.Bar.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
                    end
                end)
            end
        end
    end
end)

---------------------------------------------------------
-- Invisible 処理関数群 (常時ON)
---------------------------------------------------------
local function TryUpdateCharacterRefs()
    local currentChar = LP.Character
    if currentChar == InvLastKnownCharacter then return end
    if not currentChar or not currentChar.Parent then
        InvCharacterRef = nil; InvHumanoidRef = nil; InvRootPartRef = nil
        InvisibleParts = {}; InvLastKnownCharacter = nil
        return
    end
    task.wait(0.1)
    if not currentChar.Parent then return end
    
    InvCharacterRef = currentChar
    InvHumanoidRef = currentChar:FindFirstChild("Humanoid")
    InvRootPartRef = currentChar:FindFirstChild("HumanoidRootPart")
    
    if not InvHumanoidRef or not InvRootPartRef then
        InvCharacterRef = nil
        return
    end
    
    InvisibleParts = {}
    for _, obj in ipairs(currentChar:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Transparency == 0 then
            table.insert(InvisibleParts, obj)
        end
    end
    
    if CombatSettings.Invisible then
        for _, part in ipairs(InvisibleParts) do
            pcall(function() part.Transparency = 0.5 end)
        end
    end
    InvLastKnownCharacter = currentChar
end

TryUpdateCharacterRefs()
RunService.Heartbeat:Connect(TryUpdateCharacterRefs)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        IsAttacking = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        IsAttacking = false
        LastAttackTime = tick()
    end
end)

RunService.Heartbeat:Connect(function()
    if not CombatSettings.Invisible then return end
    if not InvRootPartRef or not InvRootPartRef.Parent or not InvHumanoidRef then return end
    
    local isAutoAttacking = _G.AutoKill and currentAimTarget ~= nil

    if CombatSettings.AutoReveal then
        if IsAttacking or (tick() - LastAttackTime < ATTACK_BUFFER) or isAutoAttacking then
            return 
        end
    end

    local originalCF = InvRootPartRef.CFrame
    local camOffset = InvHumanoidRef.CameraOffset
    
    local hiddenCF = originalCF * CFrame.new(0, SAFE_DROP_Y, 0)
    InvRootPartRef.CFrame = hiddenCF
    InvHumanoidRef.CameraOffset = hiddenCF:ToObjectSpace(CFrame.new(originalCF.Position)).Position
    
    RunService.RenderStepped:Wait()
    
    if InvRootPartRef and InvRootPartRef.Parent then
        InvRootPartRef.CFrame = originalCF
        InvHumanoidRef.CameraOffset = camOffset
    end
end)

---------------------------------------------------------
-- スキル・武装色自動発動 (一時停止フラグに対応)
---------------------------------------------------------
if _G.AutoHaki then pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end) end
LP.CharacterAdded:Connect(function()
    task.spawn(function() task.wait(2.5) if _G.AutoHaki then pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end) end end)
end)

task.spawn(function()
    while task.wait(0.5) do
        if not _G.ScriptPaused then 
            pcall(function()
                if _G.AutoV3_Active and ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommE") then
                    ReplicatedStorage.Remotes.CommE:FireServer("ActivateAbility")
                end
                if _G.AutoV4_Active then
                    VIM:SendKeyEvent(true, Enum.KeyCode.Y, false, game)
                    task.wait(0.1)
                    VIM:SendKeyEvent(false, Enum.KeyCode.Y, false, game)
                end
            end)
        end
    end
end)

---------------------------------------------------------
-- メインロジック (Noclip & 落下防止)
---------------------------------------------------------
RunService.Stepped:Connect(function()
    if _G.AutoKill and LP.Character then
        local myRoot = LP.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            myRoot.Velocity = Vector3.new(0, 0, 0) 
            
            for _, part in ipairs(LP.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait() do
        if _G.AutoRespawn and not _G.ScriptPaused and LP.Character and LP.Character:FindFirstChild("Humanoid") and LP.Character.Humanoid.Health > 0 then
            LP.Character.Humanoid.Health = 0
        end
    end
end)

---------------------------------------------------------
-- 10秒ダメージ監視 ＆ HomeButton
---------------------------------------------------------
local lastDamageTime = tick()
local lastTargetHealth = -1
local lastTrackedTarget = nil
local isTracking = false

task.spawn(function()
    while task.wait(0.1) do
        if _G.AutoKill and not _G.ScriptPaused then
            if currentAimTarget and currentAimTarget.Parent then
                local hum = currentAimTarget.Parent:FindFirstChild("Humanoid")
                if hum then
                    local currentHealth = hum.Health
                    
                    if not isTracking then
                        isTracking = true
                        lastDamageTime = tick()
                        lastTrackedTarget = hum
                        lastTargetHealth = currentHealth
                    else
                        if lastTrackedTarget ~= hum then
                            lastTrackedTarget = hum
                            lastTargetHealth = currentHealth
                        else
                            if currentHealth < lastTargetHealth then
                                lastDamageTime = tick()
                                lastTargetHealth = currentHealth
                            elseif currentHealth > lastTargetHealth then
                                lastTargetHealth = currentHealth
                            end
                        end
                    end
                    
                    local remaining = math.max(0, 10 - (tick() - lastDamageTime))
                    LblDamageTimer.Text = string.format("攻撃判定: %.1f秒", remaining)
                    
                    if remaining <= 3 then
                        LblDamageTimer.TextColor3 = Color3.fromRGB(255, 80, 80)
                    else
                        LblDamageTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
                    end
                    
                    if remaining == 0 then
                        print("🚨 10秒間ダメージなし！TPとリスポーンを一時停止し、4秒待機後にHomeButtonを発動します。")
                        _G.ScriptPaused = true  
                        isTracking = false
                        lastTrackedTarget = nil
                        lastTargetHealth = -1
                        currentAimTarget = nil  
                        
                        LblDamageTimer.Text = "攻撃判定: 帰還発動(4秒待機)！"
                        LblDamageTimer.TextColor3 = Color3.fromRGB(255, 200, 50)
                        
                        task.wait(4) 
                        
                        pcall(function()
                            local eventsFolder = ReplicatedStorage:WaitForChild("Events", 3)
                            if eventsFolder then
                                local activateHomeEvent = eventsFolder:WaitForChild("ActivateHomeButton", 3)
                                if activateHomeEvent then
                                    if activateHomeEvent:IsA("RemoteEvent") then
                                        activateHomeEvent:FireServer()
                                    elseif activateHomeEvent:IsA("BindableEvent") then
                                        activateHomeEvent:Fire()
                                    end
                                end
                            end
                        end)
                        
                        task.spawn(function()
                            task.wait(6) -- 待機時間を1秒から6秒に変更して再開
                            _G.ScriptPaused = false 
                            isTracking = false 
                            print("✅ 一時停止解除。活動を再開します！")
                        end)
                    end
                else
                    isTracking = false
                    lastTrackedTarget = nil
                    LblDamageTimer.Text = "攻撃判定: 待機中"
                    LblDamageTimer.TextColor3 = Color3.fromRGB(220, 220, 220)
                end
            else
                isTracking = false
                lastTrackedTarget = nil
                LblDamageTimer.Text = "攻撃判定: 待機中"
                LblDamageTimer.TextColor3 = Color3.fromRGB(220, 220, 220)
            end
        else
            isTracking = false
            lastTrackedTarget = nil
            if _G.ScriptPaused then
                LblDamageTimer.Text = "攻撃判定: 一時停止中"
                LblDamageTimer.TextColor3 = Color3.fromRGB(255, 200, 50)
            else
                LblDamageTimer.Text = "攻撃判定: 待機中"
                LblDamageTimer.TextColor3 = Color3.fromRGB(220, 220, 220)
            end
        end
    end
end)

---------------------------------------------------------
-- 厳格なPvP ON判定によるTP巡回＆攻撃ループ
---------------------------------------------------------
local currentPlayerIndex = 1

task.spawn(function()
    while task.wait() do
        if _G.AutoKill and not _G.ScriptPaused then
            local myChar = LP.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            
            if myChar then
                local tool = myChar:FindFirstChildOfClass("Tool")
                local fruitTool = nil
                
                for _, t in ipairs(LP.Backpack:GetChildren()) do
                    if t:IsA("Tool") and (t.ToolTip == "Blox Fruit" or string.find(t.Name, "-")) then
                        fruitTool = t; break
                    end
                end
                
                if fruitTool then
                    if tool and tool ~= fruitTool then tool.Parent = LP.Backpack end
                    fruitTool.Parent = myChar
                    tool = fruitTool
                elseif not tool and LP.Backpack:FindFirstChildOfClass("Tool") then
                    LP.Backpack:FindFirstChildOfClass("Tool").Parent = myChar
                    tool = myChar:FindFirstChildOfClass("Tool")
                end
                
                if myRoot and tool then
                    local targetToKill = nil
                    
                    if _G.SelectedTarget then
                        if _G.SelectedTarget.Character and _G.SelectedTarget.Character:FindFirstChild("HumanoidRootPart") and _G.SelectedTarget.Character:FindFirstChild("Humanoid") and _G.SelectedTarget.Character.Humanoid.Health > 0 and IsPvpEnabled(_G.SelectedTarget) then
                            targetToKill = _G.SelectedTarget
                        else
                            _G.SelectedTarget = nil
                        end
                    end
                    
                    if not targetToKill then
                        local playersList = _G.LivePvPTargets 
                        if #playersList > 0 then
                            if currentPlayerIndex > #playersList then
                                currentPlayerIndex = 1
                            end
                            targetToKill = playersList[currentPlayerIndex]
                        end
                    end
                    
                    if targetToKill then
                        local tChar = targetToKill.Character
                        local tRoot = tChar.HumanoidRootPart
                        
                        currentAimTarget = tRoot
                        local startTime = tick()
                        
                        while _G.AutoKill and not _G.ScriptPaused and targetToKill.Character and targetToKill.Character.Humanoid.Health > 0 and IsPvpEnabled(targetToKill) and (tick() - startTime < 0.5) do
                            
                            if _G.SelectedTarget and _G.SelectedTarget ~= targetToKill then break end
                            
                            local cycle = math.sin(tick() * (math.pi / 0.8)) 
                            local moveDist = 20
                            local offset = CFrame.new(0, 3, cycle * moveDist) 
                            
                            myRoot.CFrame = CFrame.new((tRoot.CFrame * offset).Position, tRoot.Position)
                            
                            pcall(function()
                                if tool:FindFirstChild("LeftClickRemote") then
                                    tool.LeftClickRemote:FireServer(myRoot.CFrame.LookVector, 1)
                                end
                                if RegisterAttack and RegisterHit then
                                    RegisterAttack:FireServer(0)
                                    RegisterHit:FireServer(tRoot, {{tChar, tRoot}})
                                end
                            end)
                            
                            task.wait(0.05)
                        end
                        
                        if not _G.SelectedTarget then
                            currentPlayerIndex = currentPlayerIndex + 1
                        end
                    else
                        currentAimTarget = nil
                        task.wait(0.5)
                    end
                else
                    currentAimTarget = nil
                    task.wait(1)
                end
            end
        else
            currentAimTarget = nil
            task.wait(0.5)
        end
    end
end)

---------------------------------------------------------
-- ESP 追尾線 & 発光 & プレイヤー情報 & 視点ロック
---------------------------------------------------------
local Tracers = {}
local Highlights = {}
local InfoBillboards = {}

local function setupPlayer(player)
    if player == LP then return end
    
    local tracer = nil
    if HasDrawing then
        pcall(function()
            tracer = Drawing.new("Line")
            tracer.Visible = false
            tracer.Color = Color3.new(1, 1, 1)
            tracer.Thickness = 1.5
            tracer.Transparency = 1
            Tracers[player] = tracer
        end)
    end

    local function onCharAdded(char)
        task.wait(0.5)
        
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                if _G.AutoKill then 
                    killCount = killCount + 1 
                    playerKills[player.Name] = (playerKills[player.Name] or 0) + 1
                end
            end)
        end
        
        local hl = Instance.new("Highlight", char)
        hl.FillColor = Color3.fromRGB(255, 0, 0)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.Enabled = espEnabled
        Highlights[player] = hl
        
        local head = char:WaitForChild("Head", 10)
        if head then
            local bb = Instance.new("BillboardGui", head)
            bb.Size = UDim2.new(0, 200, 0, 50)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Enabled = infoEnabled
            local txt = Instance.new("TextLabel", bb)
            txt.Size = UDim2.new(1, 0, 1, 0)
            txt.BackgroundTransparency = 1
            txt.Font = Enum.Font.GothamBold
            txt.TextScaled = true
            txt.TextColor3 = Color3.fromRGB(255, 255, 255)
            txt.TextStrokeTransparency = 0
            InfoBillboards[player] = txt
        end
    end

    player.CharacterAdded:Connect(onCharAdded)
    if player.Character then onCharAdded(player.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(p)
    if Tracers[p] then Tracers[p]:Remove(); Tracers[p] = nil end
    if Highlights[p] then Highlights[p]:Destroy(); Highlights[p] = nil end
    if InfoBillboards[p] then InfoBillboards[p].Parent:Destroy(); InfoBillboards[p] = nil end
    if _G.SelectedTarget == p then 
        _G.SelectedTarget = nil
        currentAimTarget = nil
    end
end)

RunService.RenderStepped:Connect(function()
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    
    if currentAimTarget and currentAimTarget.Parent and _G.AutoKill then
        pcall(function()
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentAimTarget.Position)
        end)
    end
    
    for player, txt in pairs(InfoBillboards) do
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
            local hrp = player.Character.HumanoidRootPart
            local health = math.floor(player.Character.Humanoid.Health)
            local dist = myRoot and math.floor((myRoot.Position - hrp.Position).Magnitude) or 0
            
            txt.Text = string.format("%s\nHP: %d | %dm", player.Name, health, dist)
            txt.Parent.Enabled = infoEnabled
            
            if dist <= 100 then
                txt.TextColor3 = Color3.fromRGB(255, 50, 50)
            else
                txt.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        else
            if txt.Parent then txt.Parent.Enabled = false end
        end
    end
    
    for player, hl in pairs(Highlights) do
        if player and player.Character then
            hl.Enabled = espEnabled
        end
    end

    for player, tracer in pairs(Tracers) do
        if espEnabled and player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local hrp = player.Character.HumanoidRootPart
            local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            
            if onScreen then
                if tracer then
                    tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    tracer.To = Vector2.new(vector.X, vector.Y)
                    
                    if _G.SelectedTarget == player then
                        tracer.Color = Color3.fromRGB(0, 255, 0)
                        tracer.Thickness = 2.5
                    elseif IsPvpEnabled(player) then
                        tracer.Color = Color3.fromRGB(255, 0, 0)
                        tracer.Thickness = 1.5
                    else
                        tracer.Color = Color3.fromRGB(255, 255, 255)
                        tracer.Thickness = 1
                    end
                    tracer.Visible = true
                end
            else
                if tracer then tracer.Visible = false end
            end
        else
            if tracer then tracer.Visible = false end
        end
    end
end)



---------------------------------------------------------
-- PvP対象プレイヤー数 ＆ 1分タイマー監視ループ
---------------------------------------------------------
task.spawn(function()
    task.wait(15) 
    
    while task.wait(5) do
        if isHopping then break end
        
        local attackableCount = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                if IsPvpEnabled(p) then
                    attackableCount = attackableCount + 1
                end
            end
        end
        
        local timeElapsed = tick() - scriptStartTime
        
        if attackableCount == 0 or timeElapsed >= 60 then
            isHopping = true
            
            local reason = (attackableCount == 0) and "対象0人" or "1分経過"
            
            pcall(function()
                if ScreenGui and ScreenGui:FindFirstChild("MainFrame") then
                    StatusBottom.Text = "TP攻撃中: " .. reason .. "(サーバー移動中...)"
                    StatusBottom.TextColor3 = Color3.fromRGB(100, 255, 150)
                end
            end)
            
            AutoServerHop()
        end
    end
end)
