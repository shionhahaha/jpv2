local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

local myBaseFolder = nil
local isEnabled = true
local isTpLooping = false
local currentTargetRoot = nil
local isAutoEnabled = false
--きちtp
local function initializeMyBaseAndWipeLasers()
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

    if myBaseFolder then
        for _, base in pairs(nb:GetChildren()) do
            if base ~= myBaseFolder then
                for _, obj in pairs(base:GetDescendants()) do
                    if obj.Name == "Laser" then
                        local targets = obj:IsA("BasePart") and {obj} or obj:GetDescendants()
                        for _, p in pairs(targets) do
                            if p:IsA("BasePart") then
                                p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
                                p.Transparency = 1
                                for _, c in pairs(p:GetChildren()) do
                                    if c:IsA("TouchTransmitter") or c.ClassName == "TouchInterest" then
                                        c:Destroy()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    if isEnabled and isTpLooping and currentTargetRoot and currentTargetRoot.Parent then
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            myRoot.CFrame = currentTargetRoot.CFrame + Vector3.new(0, 3, 0)
            myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    elseif isTpLooping then
        isTpLooping = false
    end
end)

local function isInsideEnemyBase(targetPos)
    local nb = workspace:FindFirstChild("NormalBase")
    if not (nb and myBaseFolder) then return false end
    for _, base in pairs(nb:GetChildren()) do
        if base ~= myBaseFolder and base:IsA("Model") then
            local cf, size = base:GetBoundingBox()
            local bPos, m = cf.Position, 2
            if targetPos.X >= bPos.X - size.X/2 - m and targetPos.X <= bPos.X + size.X/2 + m and
               targetPos.Z >= bPos.Z - size.Z/2 - m and targetPos.Z <= bPos.Z + size.Z/2 + m then
                return true
            end
        end
    end
    return false
end

local function applyToPrompt(obj)
    if obj:IsA("ProximityPrompt") then
        obj.HoldDuration = 0
    end
end

local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "DemonUltraGui"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 240)
frame.Position = UDim2.new(0.5, -100, 0.5, -120)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15)
frame.Active, frame.Draggable = true, true

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 40)
title.Text = "でーもんさいきょーｗｗ🤓"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBlack
title.BackgroundTransparency = 1

local function applyBtnStyle(btn, color)
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0, 10)
    btn.BackgroundColor3 = color
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 14
end

local toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Size = UDim2.new(1, -20, 0, 35)
toggleBtn.Position = UDim2.new(0, 10, 0, 45)
toggleBtn.Text = "モード:オン"
applyBtnStyle(toggleBtn, Color3.fromRGB(46, 204, 113))

local tpBaseBtn = Instance.new("TextButton", frame)
tpBaseBtn.Size = UDim2.new(1, -20, 0, 35)
tpBaseBtn.Position = UDim2.new(0, 10, 0, 95)
tpBaseBtn.Text = "ベースtp"
applyBtnStyle(tpBaseBtn, Color3.fromRGB(52, 152, 219))

local animalTpBtn = Instance.new("TextButton", frame)
animalTpBtn.Size = UDim2.new(1, -20, 0, 35)
animalTpBtn.Position = UDim2.new(0, 10, 0, 145)
animalTpBtn.Text = "キャラtp:オフ"
applyBtnStyle(animalTpBtn, Color3.fromRGB(39, 174, 96))

local autoBtn = Instance.new("TextButton", frame)
autoBtn.Size = UDim2.new(1, -20, 0, 35)
autoBtn.Position = UDim2.new(0, 10, 0, 195)
autoBtn.Text = "おーと:オフ"
applyBtnStyle(autoBtn, Color3.fromRGB(127, 140, 141))

toggleBtn.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    toggleBtn.Text = isEnabled and "モード:オン" or "モード:オフ"
    toggleBtn.BackgroundColor3 = isEnabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)
end)

tpBaseBtn.MouseButton1Click:Connect(function()
    initializeMyBaseAndWipeLasers()
    local cash = myBaseFolder and myBaseFolder:FindFirstChild("Cash")
    local target = cash and cash:FindFirstChild("structure base home")
    if target and root then
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, 5, 0))
    end
end)

animalTpBtn.MouseButton1Click:Connect(function()
    if isTpLooping then
        isTpLooping = false
        animalTpBtn.Text = "キャラtp:オフ"
        animalTpBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
    else
        local anims = workspace:FindFirstChild("Animals")
        local targets = {}
        if anims then
            for _, obj in pairs(anims:GetChildren()) do
                if obj:IsA("Model") then
                    local name = obj.Name
                    
                    local isForbidden = (name == player.Name) 
                                     or name:find("ヌッピーニ") 
                                     or name:find("寿司") 
                                     or name:find("ぬびりーに")
                    
                    if isForbidden then
                        
                        print("論外: " .. name)
                    else
                        local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                        if p and isInsideEnemyBase(p.Position) then 
                            table.insert(targets, p) 
                        end
                    end
                end
            end
        end

        if #targets > 0 then
            local selected = targets[math.random(1, #targets)]
            
            print("TP成功: " .. selected.Parent.Name .. " にtp")
            
            currentTargetRoot = selected
            isTpLooping = true
            animalTpBtn.Text = "らんだむtp"
            animalTpBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        else
            warn(" キャラがいません")
        end
    end
end)

autoBtn.MouseButton1Click:Connect(function()
    isAutoEnabled = not isAutoEnabled
    autoBtn.Text = isAutoEnabled and "おーと:オン" or "おーと:オフ"
    autoBtn.BackgroundColor3 = isAutoEnabled and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(127, 140, 141)
end)

--プロンプトloop
initializeMyBaseAndWipeLasers()
for _, v in pairs(workspace:GetDescendants()) do applyToPrompt(v) end
workspace.DescendantAdded:Connect(applyToPrompt)

RunService.Stepped:Connect(function()
    if not isEnabled then return end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end)

print("でーもんはぶはつどう！ｗ")
