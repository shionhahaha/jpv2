local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local isEnabled=true

local screenGui=Instance.new("ScreenGui")
screenGui.Name="FastPromptGui"
screenGui.ResetOnSpawn=false
screenGui.Parent=player:WaitForChild("PlayerGui")

local frame=Instance.new("Frame")
frame.Size=UDim2.new(0,200,0,90)
frame.Position=UDim2.new(0.5,-100,0.5,-45)
frame.BackgroundColor3=Color3.fromRGB(25,25,25)
frame.BorderSizePixel=0
frame.Active=true
frame.Draggable=true
frame.Parent=screenGui

Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
local stroke=Instance.new("UIStroke",frame)
stroke.Color=Color3.fromRGB(50,50,50)
stroke.Thickness=2

local title=Instance.new("TextLabel",frame)
title.Size=UDim2.new(1,0,0,30)
title.BackgroundTransparency=1
title.Text="PROXIMITY FAST"
title.TextColor3=Color3.fromRGB(200,200,200)
title.Font=Enum.Font.GothamBold
title.TextSize=12

local btn=Instance.new("TextButton",frame)
btn.Size=UDim2.new(1,-20,0,40)
btn.Position=UDim2.new(0,10,0,35)
btn.Font=Enum.Font.GothamBlack
btn.TextSize=16
btn.TextColor3=Color3.new(1,1,1)
Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)

local function stopAnims(char)
local hum=char:FindFirstChildOfClass("Humanoid")
if hum then

for _,t in pairs(hum:GetPlayingAnimationTracks()) do t:Stop(0) end
end

local anim=char:FindFirstChild("Animate")
if anim then anim.Disabled=true end
end

RunService.Stepped:Connect(function()
if not isEnabled then return end
local char=player.Character
local hum=char and char:FindFirstChildOfClass("Humanoid")
if hum then
local s=hum:GetState()
if s==Enum.HumanoidStateType.Ragdoll or s==Enum.HumanoidStateType.FallingDown or s==Enum.HumanoidStateType.PlatformStanding then
hum:ChangeState(Enum.HumanoidStateType.GettingUp)
end

stopAnims(char)
end
end)

local function updateUI()
if isEnabled then
btn.Text="STATUS: ON"
btn.BackgroundColor3=Color3.fromRGB(45,180,100)
else
btn.Text="STATUS: OFF"
btn.BackgroundColor3=Color3.fromRGB(180,50,50)
local char=player.Character
local anim=char and char:FindFirstChild("Animate")
if anim then anim.Disabled=false end
end
end
updateUI()

local originals={}
local function fast(obj)
if obj:IsA("ProximityPrompt")then
if not originals[obj]then originals[obj]=obj.HoldDuration end
task.spawn(function()
while obj.Parent do
obj.HoldDuration=isEnabled and 0.5 or originals[obj]
task.wait(0.5)
end
end)
end
end

for _,v in pairs(workspace:GetDescendants())do fast(v)end
workspace.DescendantAdded:Connect(fast)

btn.MouseButton1Click:Connect(function()
isEnabled=not isEnabled
updateUI()
end)
