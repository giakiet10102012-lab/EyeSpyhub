-- [[ EyeSpyhub | San Diego v14.3 ]]
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

-- [LỘ TRÌNH TỌA ĐỘ CHUẨN]
local Pos_BuyItem       = CFrame.new(6803.020, 17.590, 23.030)
local Way_1             = CFrame.new(6872.252, 17.219, 30.226)
local Way_2             = CFrame.new(6868.940, 17.219, 107.597)
local Way_3             = CFrame.new(258.024, 17.219, 104.148)
local Way_4             = CFrame.new(258.357, 17.239, -44.435)
local Way_5_Seller      = CFrame.new(208.642, 17.406, -43.187)
local Way_LaunderEntry  = CFrame.new(6882.597, 17.417, -40.537)
local Pos_Launder       = CFrame.new(6809.746, 17.442, -40.643)

local FLY_SPEED          = 300
local SELL_COOLDOWN      = 6
_G.AutoFarm              = false
_G.IsCooldownWaiting     = false

local bv, bg

-- [ANTI-AFK]
LP.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

-- [HÀM LẤY HUMAN/ROOT AN TOÀN]
local function GetCharacter()
    local char = LP.Character
    if not char then return nil, nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, root, hum
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
        bg = Instance.new("BodyGyro")
        bg.P = 9e4
        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.CFrame = root.CFrame
        bg.Parent = root
    end

    if not bv or bv.Parent ~= root then
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Velocity = Vector3.zero
        bv.Parent = root
    end

    hum.PlatformStand = true
end

-- [HÀM TỰ TỬ ÉP BẰNG BREAKJOINTS]
local function ResetCharacter()
    DisableFly()
    if LP.Character then
        LP.Character:BreakJoints()
    end
    local _, _, hum = GetCharacter()
    if hum then
        hum.Health = 0
    end
    task.wait(2)
end

LP.CharacterAdded:Connect(function()
    DisableFly()
end)

-- [GLOBAL ANTI-STUCK WATCHER]
task.spawn(function()
    local lastPos = nil
    local stuckCounter = 0

    while task.wait(1) do
        if _G.AutoFarm and not _G.IsCooldownWaiting then
            local _, root, hum = GetCharacter()
            if root and hum and hum.Health > 0 then
                if lastPos and (root.Position - lastPos).Magnitude < 1.5 then
                    stuckCounter = stuckCounter + 1
                    if stuckCounter >= 5 then
                        stuckCounter = 0
                        ResetCharacter()
                    end
                else
                    stuckCounter = 0
                    lastPos = root.Position
                end
            else
                stuckCounter = 0
                lastPos = nil
            end
        else
            stuckCounter = 0
            lastPos = nil
        end
    end
end)

-- [HÀM BAY AN TOÀN]
local function FlyTo(targetCFrame, speed)
    speed = speed or FLY_SPEED
    local _, root, hum = GetCharacter()
    if not root or not hum or hum.Health <= 0 then return end

    EnableFly()
    local targetPos = targetCFrame.Position

    while _G.AutoFarm do
        local _, curRoot, curHum = GetCharacter()
        if not curRoot or not curHum or curHum.Health <= 0 then break end

        local currentPos = curRoot.Position
        local distance = (targetPos - currentPos).Magnitude

        if distance <= 2.0 then break end

        local dir = (targetPos - currentPos).Unit
        bv.Velocity = dir * speed
        bg.CFrame = CFrame.lookAt(currentPos, Vector3.new(targetPos.X, currentPos.Y, targetPos.Z))

        RunService.Heartbeat:Wait()
    end

    if bv then bv.Velocity = Vector3.zero end
    if bg then bg.CFrame = targetCFrame end
    if root then root.CFrame = targetCFrame end
    task.wait(0.1)
end

-- [HÀM TÌM ĐỐI TƯỢNG GẦN NHẤT]
local function GetClosestTarget(targetName)
    local _, root, _ = GetCharacter()
    if not root then return workspace:FindFirstChild(targetName, true) end

    local closestObj = nil
    local minDistance = math.huge

    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant.Name == targetName and descendant:FindFirstChildWhichIsA("ProximityPrompt", true) then
            local targetPart = descendant:IsA("BasePart") and descendant or descendant:FindFirstChildWhichIsA("BasePart", true)
            if targetPart then
                local dist = (root.Position - targetPart.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestObj = descendant
                end
            end
        end
    end

    return closestObj or workspace:FindFirstChild(targetName, true)
end

-- [HÀM BAY ÁP SÁT AN TOÀN CÁCH MỤC TIÊU 2 STUDS]
local function FlyToTargetSafe(targetObj)
    if not targetObj then return end
    local prompt = targetObj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then return end
    
    local parentPart = prompt.Parent
    if parentPart and not parentPart:IsA("BasePart") then
        parentPart = parentPart:FindFirstChildWhichIsA("BasePart", true)
    end
    if not parentPart then return end

    local _, root, _ = GetCharacter()
    if not root then return end

    local targetPos = parentPart.Position
    local currentPos = root.Position
    local dir = (currentPos - targetPos)
    
    if dir.Magnitude > 0.1 then
        dir = dir.Unit
    else
        dir = Vector3.new(0, 0, 1)
    end

    -- Tính vị trí an toàn nằm ở khoảng trống hướng về phía nhân vật đang đứng
    local safePos = targetPos + (dir * 2.0)
    FlyTo(CFrame.new(safePos, targetPos), 200)
end

-- [HÀM TƯƠNG TÁC KÍCH HOẠT PROMPT]
local function FirePrompt(target, count, holdTime)
    count = count or 1
    holdTime = holdTime or 0
    if not target then return end
    
    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        local _, _, hum = GetCharacter()
        for i = 1, count do
            if not _G.AutoFarm or (hum and hum.Health <= 0) then break end
            
            fireproximityprompt(prompt)
            
            if holdTime > 0 then
                task.wait(holdTime)
            else
                task.wait(0.35)
            end
        end
    end
end

local function GetItemCount(itemName)
    local count = 0
    if LP:FindFirstChild("Backpack") then
        for _, item in pairs(LP.Backpack:GetChildren()) do
            if item.Name == itemName then count = count + 1 end
        end
    end
    if LP.Character and LP.Character:FindFirstChild(itemName) then
        count = count + 1
    end
    return count
end

-- [GUI SETUP]
if CoreGui:FindFirstChild("EyeSpyhub_Gui") then
    CoreGui.EyeSpyhub_Gui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "EyeSpyhub_Gui"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 150)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -75)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Draggable = true
MainFrame.Active = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "EyeSpyhub Auto Farm v14.3"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Title.BorderSizePixel = 0

local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(0.85, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.075, 0, 0.4, 0)
ToggleBtn.Text = "Auto Farm: OFF"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
ToggleBtn.BorderSizePixel = 0

ToggleBtn.MouseButton1Click:Connect(function()
    _G.AutoFarm = not _G.AutoFarm
    ToggleBtn.Text = _G.AutoFarm and "Auto Farm: ON" or "Auto Farm: OFF"
    ToggleBtn.BackgroundColor3 = _G.AutoFarm and Color3.fromRGB(40, 180, 40) or Color3.fromRGB(180, 40, 40)
    
    if not _G.AutoFarm then
        DisableFly()
    end
end)

local ToggleGuiBtn = Instance.new("TextButton", ScreenGui)
ToggleGuiBtn.Size = UDim2.new(0, 100, 0, 30)
ToggleGuiBtn.Position = UDim2.new(0, 10, 0, 10)
ToggleGuiBtn.Text = "Ẩn/Hiện GUI (Ctrl)"
ToggleGuiBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ToggleGuiBtn.TextColor3 = Color3.new(1, 1, 1)

local function ToggleMenu()
    MainFrame.Visible = not MainFrame.Visible
end

ToggleGuiBtn.MouseButton1Click:Connect(ToggleMenu)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
        ToggleMenu()
    end
end)

-- [CORE FARM LOOP]
task.spawn(function()
    while task.wait(0.5) do
        if _G.AutoFarm then
            pcall(function()
                local _, _, hum = GetCharacter()
                if not hum or hum.Health <= 0 then return end

                -- Bước 1: Mua 5 tranh Mona Lisa
                if GetItemCount("Mona Lisa Painting") < 5 then
                    FlyTo(Pos_BuyItem)
                    while _G.AutoFarm and GetItemCount("Mona Lisa Painting") < 5 do
                        local item = GetClosestTarget("Mona Lisa Painting")
                        if item then FlyToTargetSafe(item) end
                        FirePrompt(item, 1, 0.35)
                        task.wait(0.1)
                    end
                end
                if not _G.AutoFarm then return end

                -- Bước 2: Bay đến NPC Seller
                FlyTo(Way_1)
                if not _G.AutoFarm then return end
                FlyTo(Way_2)
                if not _G.AutoFarm then return end
                FlyTo(Way_3)
                if not _G.AutoFarm then return end
                FlyTo(Way_4)
                if not _G.AutoFarm then return end
                FlyTo(Way_5_Seller)
                if not _G.AutoFarm then return end

                -- Áp sát Seller & nhận vali
                local npc = GetClosestTarget("Seller4")
                if npc then FlyToTargetSafe(npc) end
                
                _G.IsCooldownWaiting = true
                task.wait(SELL_COOLDOWN)

                FirePrompt(npc, 1, 1.2)
                task.wait(0.3)
                _G.IsCooldownWaiting = false

                if not _G.AutoFarm then return end

                -- Bước 3: Bay ngược lại
                FlyTo(Way_4)
                if not _G.AutoFarm then return end
                FlyTo(Way_3)
                if not _G.AutoFarm then return end
                FlyTo(Way_2)
                if not _G.AutoFarm then return end
                FlyTo(Way_1)
                if not _G.AutoFarm then return end

                -- Bước 4: Vào khu Rửa tiền
                FlyTo(Way_LaunderEntry)
                if not _G.AutoFarm then return end
                FlyTo(Pos_Launder)
                if not _G.AutoFarm then return end

                -- Áp sát máy rửa tiền an toàn & Rửa tiền
                local launder = GetClosestTarget("PromptPart")
                if launder then FlyToTargetSafe(launder) end

                _G.IsCooldownWaiting = true
                FirePrompt(launder, 1, 1.2)
                task.wait(0.3)
                _G.IsCooldownWaiting = false

                if not _G.AutoFarm then return end

                -- Bước 5: Bay ngược ra ngoài
                FlyTo(Way_LaunderEntry)
                if not _G.AutoFarm then return end
                FlyTo(Way_1)
                if not _G.AutoFarm then return end
            end)
        end
    end
end)
