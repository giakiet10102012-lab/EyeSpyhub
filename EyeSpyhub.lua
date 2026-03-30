-- Kiểm tra sự tồn tại của thư viện trước khi chạy
local success, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
end)

if not success or not Library then
    warn("Không thể tải thư viện GUI. Hãy thử đổi Executor khác!")
    return
end

local Window = Library.CreateLib("EyeSpyhub - Sailor Piece", "BloodTheme")

local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub - Sailor Piece (Bản Tự Chế)",
    SubTitle = "by Gemini AI",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- TẠO CÁC TAB
local Tabs = {
    Main = Window:AddTab({ Title = "Auto Farm", Icon = "home" }),
    Boss = Window:AddTab({ Title = "Săn Boss Gojo", Icon = "target" }),
    Combat = Window:AddTab({ Title = "Chiến Đấu", Icon = "swords" }),
    FixLag = Window:AddTab({ Title = "Fix Lag", Icon = "zap" })
}

-- ==========================================
-- TAB: AUTO FARM
-- ==========================================
local FarmSection = Tabs.Main:AddSection("Cấu Hình Farm")

local QuestTable = {
    {Min = 8000, Max = 8999, NPC = "QuestNPC14", Pos = Vector3.new(-1124.75, 19.7, 371.23)},
    {Min = 9000, Max = 9999, NPC = "QuestNPC15", Pos = Vector3.new(1072.546, 6.778, 1275.642)}, 
    {Min = 10000, Max = 10749, NPC = "QuestNPC16", Pos = Vector3.new(-1274.657, 6.175, -1191.39)}, 
    {Min = 10750, Max = 11999, NPC = "QuestNPC18", Pos = Vector3.new(-1876.007, 13.572, -738.603)}, 
    {Min = 12000, Max = 100000, NPC = "QuestNPC19", Pos = Vector3.new(59.851, 5.579, 1816.135)}
}

_G.AutoFarm = false
_G.CurrentQuest = ""

local FarmToggle = Tabs.Main:AddToggle("AutoFarmToggle", {Title = "Bật Auto Farm", Default = false})

FarmToggle:OnChanged(function()
    _G.AutoFarm = Fluent.Options.AutoFarmToggle.Value
    if _G.AutoFarm then
        _G.CurrentQuest = ""
        task.spawn(function()
            while _G.AutoFarm do
                task.wait(0.1)
                local player = game.Players.LocalPlayer
                local myLv = player.Data.Level.Value
                local targetNPC, targetPos

                for _, v in pairs(QuestTable) do
                    if myLv >= v.Min and myLv <= v.Max then
                        targetNPC, targetPos = v.NPC, v.Pos
                        break
                    end
                end

                if targetNPC and _G.CurrentQuest ~= targetNPC then
                    if _G.CurrentQuest ~= "" then
                        game:GetService("ReplicatedStorage").RemoteEvents.QuestAbandon:FireServer("repeatable")
                        task.wait(0.3)
                    end
                    game:GetService("ReplicatedStorage").RemoteEvents.QuestAccept:FireServer(targetNPC)
                    _G.CurrentQuest = targetNPC
                end

                pcall(function()
                    if targetPos and player.Character:FindFirstChild("HumanoidRootPart") then
                        local root = player.Character.HumanoidRootPart
                        local hum = player.Character.Humanoid
                        local goalCFrame = CFrame.new(targetPos.X, targetPos.Y + 5, targetPos.Z) * CFrame.Angles(math.rad(-90), 0, 0)
                        
                        if (root.Position - targetPos).Magnitude > 5 then
                            game:GetService("TweenService"):Create(root, TweenInfo.new((root.Position - targetPos).Magnitude/150, Enum.EasingStyle.Linear), {CFrame = goalCFrame}):Play()
                        else
                            root.CFrame = goalCFrame
                        end
                        root.Velocity = Vector3.new(0, 0, 0)
                        hum.PlatformStand = true
                        for _, v in pairs(player.Character:GetChildren()) do if v:IsA("BasePart") then v.CanCollide = false end end
                    end
                end)
            end
        end)
    else
        pcall(function() game.Players.LocalPlayer.Character.Humanoid.PlatformStand = false end)
    end
end)

Tabs.Main:AddButton({
    Title = "Xóa Nhiệm Vụ Hiện Tại",
    Callback = function()
        game:GetService("ReplicatedStorage").RemoteEvents.QuestAbandon:FireServer("repeatable")
        _G.CurrentQuest = ""
    end
})

-- ==========================================
-- TAB: SĂN BOSS GOJO
-- ==========================================
local GojoSection = Tabs.Boss:AddSection("Boss Magnet")

_G.StickToBoss = false
local BOSS_NAME = "GojoBoss"

local StickToggle = Tabs.Boss:AddToggle("StickGojo", {Title = "Dính Theo Boss Gojo", Default = false})

StickToggle:OnChanged(function()
    _G.StickToBoss = Fluent.Options.StickGojo.Value
    if _G.StickToBoss then
        pcall(function() game:GetService("ReplicatedStorage").Remotes.TeleportToPortal:FireServer("Shibuya") end)
        task.wait(2)
        task.spawn(function()
            local player = game.Players.LocalPlayer
            while _G.StickToBoss do
                game:GetService("RunService").RenderStepped:Wait()
                pcall(function()
                    local root = player.Character.HumanoidRootPart
                    local targetBoss = nil
                    for _, v in pairs(game.Workspace:GetDescendants()) do
                        if v:IsA("Model") and v.Name:find(BOSS_NAME) and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                            targetBoss = v break
                        end
                    end
                    if targetBoss then
                        root.Velocity = Vector3.new(0,0,0)
                        player.Character.Humanoid.PlatformStand = true
                        root.CFrame = targetBoss.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                    else
                        local waitPos = Vector3.new(1858.326, 12.986, 338.14)
                        root.CFrame = root.CFrame:Lerp(CFrame.new(waitPos.X, waitPos.Y + 15, waitPos.Z) * CFrame.Angles(math.rad(-90), 0, 0), 0.1)
                    end
                end)
            end
        end)
    else
        pcall(function() game.Players.LocalPlayer.Character.Humanoid.PlatformStand = false end)
    end
end)

Tabs.Boss:AddButton({
    Title = "Hop Server (Đổi Máy Chủ)",
    Callback = function()
        local Http = game:GetService("HttpService")
        local Tp = game:GetService("TeleportService")
        local Servers = Http:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        for _, s in pairs(Servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then Tp:TeleportToPlaceInstance(game.PlaceId, s.id, game.Players.LocalPlayer) break end
        end
    end
})

-- ==========================================
-- TAB: CHIẾN ĐẤU
-- ==========================================
local CombatSection = Tabs.Combat:AddSection("Kỹ Năng")

local AutoClickToggle = Tabs.Combat:AddToggle("AutoClick", {Title = "Auto Click", Default = false})
AutoClickToggle:OnChanged(function()
    _G.AutoClick = Fluent.Options.AutoClick.Value
    if _G.AutoClick then
        task.spawn(function()
            while _G.AutoClick do
                game:GetService("ReplicatedStorage").CombatSystem.Remotes.RequestHit:FireServer()
                task.wait(0.1)
            end
        end)
    end
end)

local AutoZToggle = Tabs.Combat:AddToggle("AutoZ", {Title = "Auto Skill Z", Default = false})
AutoZToggle:OnChanged(function()
    _G.AutoSkillZ = Fluent.Options.AutoZ.Value
    if _G.AutoSkillZ then
        task.spawn(function()
            while _G.AutoSkillZ do
                game:GetService("ReplicatedStorage").AbilitySystem.Remotes.RequestAbility:FireServer(2)
                task.wait(0.5)
            end
        end)
    end
end)

-- ==========================================
-- TAB: FIX LAG
-- ==========================================
Tabs.FixLag:AddButton({
    Title = "Bật Chế Độ Siêu Mượt",
    Callback = function()
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
        end
    end
})

Tabs.FixLag:AddInput("FPSCap", {
    Title = "Giới Hạn FPS",
    Default = "60",
    Placeholder = "Nhập số FPS...",
    Callback = function(Value)
        if setfpscap then setfpscap(tonumber(Value)) end
    end
})

Window:SelectTab(1)
Fluent:Notify({Title = "EyeSpyhub", Content = "Script đã sẵn sàng!", Duration = 5})
-- ==========================================
-- NÚT BẤM ẨN/HIỆN GUI (Dán ở cuối Script)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
local ToggleButton = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")

-- Thiết lập để nút không bị mất khi nhân vật chết
ScreenGui.Name = "EyeSpyToggleGui"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- Cấu hình ngoại hình nút bấm
ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0) -- Màu đỏ phù hợp BloodTheme
ToggleButton.Position = UDim2.new(0.1, 0, 0.2, 0) 
ToggleButton.Size = UDim2.new(0, 45, 0, 45) -- Kích thước vừa phải cho Nubia Neo 2
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "EYE"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14
ToggleButton.Draggable = true -- Bạn có thể kéo nút này trên màn hình

UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = ToggleButton

-- CHỨC NĂNG QUAN TRỌNG: ẨN/HIỆN
ToggleButton.MouseButton1Click:Connect(function()
    -- Tìm đúng tên giao diện bạn đã đặt ở dòng đầu tiên của script
    local uiName = "EyeSpyhub - Sailor Piece (Bản Tự Chế)"
    local targetUI = game:GetService("CoreGui"):FindFirstChild(uiName)
    
    if targetUI then
        targetUI.Enabled = not targetUI.Enabled
        -- Đổi màu nút để biết đang bật hay tắt
        if targetUI.Enabled then
            ToggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        else
            ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
    else
        -- Nếu không tìm thấy theo tên, ta dùng cách quét thủ công
        for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
            if v:IsA("ScreenGui") and v.Name:find("EyeSpyhub") then
                v.Enabled = not v.Enabled
                break
            end
        end
    end
end)
