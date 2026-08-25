-- [[ EyeSpyhub | San Diego - Farm Edition ]]
local CoreGui, Players, RunService, UserInputService, VirtualUser = game:GetService("CoreGui"), game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("VirtualUser")
local LP = Players.LocalPlayer

local Pos_BuyItem, Way_1, Way_2, Way_3, Way_4, Way_5_Seller, Way_LaunderEntry, Pos_Launder = CFrame.new(6803.02, 17.59, 23.03), CFrame.new(6872.252, 17.219, 30.226), CFrame.new(6868.94, 17.219, 107.597), CFrame.new(258.024, 17.219, 104.148), CFrame.new(258.357, 17.239, -44.435), CFrame.new(208.642, 17.406, -43.187), CFrame.new(6882.597, 17.417, -40.537), CFrame.new(6809.746, 17.442, -40.643)
local FLY_SPEED, SELL_COOLDOWN, bv, bg = 300, 6
_G.AutoFarm = false
_G.NoClip = false

LP.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
end)

RunService.Stepped:Connect(function()
    if _G.NoClip and LP.Character then
        for _, part in pairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

local function GetCharacter()
    local char = LP.Character
    return char, char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function DisableFly()
    if bg then bg:Destroy() bg = nil end
    if bv then bv:Destroy() bv = nil end
    local _, _, hum = GetCharacter()
    if hum then hum.PlatformStand = false end
end

local function EnableFly()
    local _, root, hum = GetCharacter()
    if not root or not hum then return end
    if not bg or bg.Parent ~= root then
        if bg then bg:Destroy() end
        bg = Instance.new("BodyGyro", root)
        bg.P, bg.MaxTorque, bg.CFrame = 9e4, Vector3.new(9e9, 9e9, 9e9), root.CFrame
    end
    if not bv or bv.Parent ~= root then
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity", root)
        bv.MaxForce, bv.Velocity = Vector3.new(9e9, 9e9, 9e9), Vector3.zero
    end
    hum.PlatformStand = true
end

LP.CharacterAdded:Connect(function()
    DisableFly()
    task.wait(1)
end)

local function FlyTo(targetCFrame, speed)
    speed = speed or FLY_SPEED
    local _, root, hum = GetCharacter()
    if not root or not hum or hum.Health <= 0 then return end
    EnableFly()
    local targetPos = targetCFrame.Position
    while _G.AutoFarm do
        local _, curRoot, curHum = GetCharacter()
        if not curRoot or not curHum or curHum.Health <= 0 or (targetPos - curRoot.Position).Magnitude <= 2.0 then break end
        bv.Velocity = (targetPos - curRoot.Position).Unit * speed
        bg.CFrame = CFrame.lookAt(curRoot.Position, Vector3.new(targetPos.X, curRoot.Position.Y, targetPos.Z))
        RunService.Heartbeat:Wait()
    end
    if bv then bv.Velocity = Vector3.zero end
    if bg then bg.CFrame = targetCFrame end
    if root and root.Parent then root.CFrame = targetCFrame end
    task.wait(0.1)
end

local function GetClosestTarget(targetName)
    local _, root, _ = GetCharacter()
    if not root then return workspace:FindFirstChild(targetName, true) end
    local closestObj, minDistance = nil, math.huge
    for _, desc in pairs(workspace:GetDescendants()) do
        if desc.Name == targetName and desc:FindFirstChildWhichIsA("ProximityPrompt", true) then
            local part = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local dist = (root.Position - part.Position).Magnitude
                if dist < minDistance then minDistance = dist; closestObj = desc end
            end
        end
    end
    return closestObj or workspace:FindFirstChild(targetName, true)
end

local function FlyToTargetSafe(targetObj)
    if not targetObj then return end
    local prompt = targetObj:FindFirstChildWhichIsA("ProximityPrompt", true)
    local parentPart = prompt and (prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart", true))
    local _, root, _ = GetCharacter()
    if not parentPart or not root then return end
    local dir = (root.Position - parentPart.Position)
    dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1)
    FlyTo(CFrame.new(parentPart.Position + (dir * 2.0), parentPart.Position), 200)
end

local function FirePrompt(target, count, holdTime)
    count, holdTime = count or 1, holdTime or 0
    if not target then return end
    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        local _, _, hum = GetCharacter()
        for i = 1, count do
            if not _G.AutoFarm or (hum and hum.Health <= 0) then break end
            fireproximityprompt(prompt)
            task.wait(holdTime > 0 and holdTime or 0.35)
        end
    end
end

local function GetItemCount(itemName)
    local count = 0
    if LP:FindFirstChild("Backpack") then
        for _, item in pairs(LP.Backpack:GetChildren()) do if item.Name == itemName then count = count + 1 end end
    end
    if LP.Character and LP.Character:FindFirstChild(itemName) then count = count + 1 end
    return count
end

if CoreGui:FindFirstChild("EyeSpyhub_Gui") then CoreGui.EyeSpyhub_Gui:Destroy() end
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "EyeSpyhub_Gui"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size, MainFrame.Position, MainFrame.BackgroundColor3, MainFrame.Draggable, MainFrame.Active = UDim2.new(0, 200, 0, 140), UDim2.new(0.5, -100, 0.5, -70), Color3.fromRGB(25, 25, 25), true, true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size, Title.Text, Title.TextColor3, Title.BackgroundColor3 = UDim2.new(1, 0, 0, 30), "EyeSpyhub | Auto Farm", Color3.new(1, 1, 1), Color3.fromRGB(45, 45, 45)

local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size, ToggleBtn.Position, ToggleBtn.Text, ToggleBtn.BackgroundColor3, ToggleBtn.TextColor3 = UDim2.new(0.85, 0, 0, 35), UDim2.new(0.075, 0, 0.28, 0), "Auto Farm: OFF", Color3.fromRGB(180, 40, 40), Color3.new(1, 1, 1)

ToggleBtn.MouseButton1Click:Connect(function()
    _G.AutoFarm = not _G.AutoFarm
    ToggleBtn.Text = _G.AutoFarm and "Auto Farm: ON" or "Auto Farm: OFF"
    ToggleBtn.BackgroundColor3 = _G.AutoFarm and Color3.fromRGB(40, 180, 40) or Color3.fromRGB(180, 40, 40)
    if not _G.AutoFarm then DisableFly() end
end)

local NoClipBtn = Instance.new("TextButton", MainFrame)
NoClipBtn.Size, NoClipBtn.Position, NoClipBtn.Text, NoClipBtn.BackgroundColor3, NoClipBtn.TextColor3 = UDim2.new(0.85, 0, 0, 35), UDim2.new(0.075, 0, 0.60, 0), "NoClip: OFF", Color3.fromRGB(180, 40, 40), Color3.new(1, 1, 1)

NoClipBtn.MouseButton1Click:Connect(function()
    _G.NoClip = not _G.NoClip
    NoClipBtn.Text = _G.NoClip and "NoClip: ON" or "NoClip: OFF"
    NoClipBtn.BackgroundColor3 = _G.NoClip and Color3.fromRGB(40, 180, 40) or Color3.fromRGB(180, 40, 40)
end)

local ToggleGuiBtn = Instance.new("TextButton", ScreenGui)
ToggleGuiBtn.Size, ToggleGuiBtn.Position, ToggleGuiBtn.Text, ToggleGuiBtn.BackgroundColor3, ToggleGuiBtn.TextColor3 = UDim2.new(0, 100, 0, 30), UDim2.new(0, 10, 0, 10), "Ẩn/Hiện GUI (Ctrl)", Color3.fromRGB(35, 35, 35), Color3.new(1, 1, 1)

local function ToggleMenu() MainFrame.Visible = not MainFrame.Visible end
ToggleGuiBtn.MouseButton1Click:Connect(ToggleMenu)
UserInputService.InputBegan:Connect(function(input, gP) if not gP and input.KeyCode == Enum.KeyCode.RightControl then ToggleMenu() end end)

task.spawn(function()
    while task.wait(0.5) do
        if _G.AutoFarm then
            pcall(function()
                local _, root, hum = GetCharacter()
                if not root or not hum or hum.Health <= 0 then return end

                if GetItemCount("Mona Lisa Painting") < 5 then
                    FlyTo(Pos_BuyItem)
                    while _G.AutoFarm and GetItemCount("Mona Lisa Painting") < 5 do
                        local _, r, h = GetCharacter()
                        if not r or not h or h.Health <= 0 then break end
                        local item = GetClosestTarget("Mona Lisa Painting")
                        if item then FlyToTargetSafe(item) end
                        FirePrompt(item, 1, 0.35)
                        task.wait(0.1)
                    end
                end
                if not _G.AutoFarm then return end

                FlyTo(Way_1); FlyTo(Way_2); FlyTo(Way_3); FlyTo(Way_4); FlyTo(Way_5_Seller)
                local npc = GetClosestTarget("Seller4")
                if npc then FlyToTargetSafe(npc) end
                task.wait(SELL_COOLDOWN)
                FirePrompt(npc, 1, 1.2)
                task.wait(0.3)
                if not _G.AutoFarm then return end

                FlyTo(Way_4); FlyTo(Way_3); FlyTo(Way_2); FlyTo(Way_1); FlyTo(Way_LaunderEntry); FlyTo(Pos_Launder)
                local launder = GetClosestTarget("PromptPart")
                if launder then FlyToTargetSafe(launder) end
                FirePrompt(launder, 1, 1.2)
                task.wait(0.3)
                if not _G.AutoFarm then return end

                FlyTo(Way_LaunderEntry); FlyTo(Way_1)
            end)
        end
    end
end)
