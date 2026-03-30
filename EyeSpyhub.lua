-- Khởi tạo Thư viện GUI
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("EyeSpyhub - Sailor Piece (Bản Tự Chế)", "BloodTheme")

-- TẠO CÁC TAB
local MainTab = Window:NewTab("Auto Farm")
local CombatTab = Window:NewTab("Chiến Đấu")
local CreditTab = Window:NewTab("Thông Tin")

-- ==========================================
-- PHẦN 1: AUTO FARM (TAB CHÍNH)
-- ==========================================
local FarmSection = MainTab:NewSection("Cấu Hình Farm")

local QuestTable = {
    {Min = 8000, Max = 8999, NPC = "QuestNPC14", Pos = Vector3.new(-1124.75, 19.7, 371.23)},
    {Min = 9000, Max = 9999, NPC = "QuestNPC15", Pos = Vector3.new(1072.546, 6.778, 1275.642)}, 
    {Min = 10000, Max = 11499, NPC = "QuestNPC16", Pos = Vector3.new(-1274.657, 6.175, -1191.39)}, 
    {Min = 11500, Max = 11999, NPC = "QuestNPC18", Pos = Vector3.new(-1876.007, 13.572, -738.603)}, 
    {Min = 12000, Max = 100000, NPC = "QuestNPC19", Pos = Vector3.new(59.851, 5.579, 1816.135)}
}

_G.AutoFarm = false
_G.CurrentQuest = "" 

FarmSection:NewToggle("Bật Auto Farm", "Tự động Xóa & Nhận Quest", function(state)
    _G.AutoFarm = state
    
    if state then
        _G.CurrentQuest = "" 
        task.spawn(function()
            while _G.AutoFarm do
                task.wait(0.1)
                
                local player = game.Players.LocalPlayer
                local myLv = player.Data.Level.Value
                local targetNPC = nil
                local targetPos = nil

                for _, v in pairs(QuestTable) do
                    if myLv >= v.Min and myLv <= v.Max then
                        targetNPC = v.NPC
                        targetPos = v.Pos
                        break
                    end
                end

                -- Bước 2: Nhận/Đổi Quest
                if targetNPC and _G.CurrentQuest ~= targetNPC then
                    if _G.CurrentQuest ~= "" then
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("QuestAbandon"):FireServer("repeatable")
                        task.wait(0.3)
                    end
                    game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("QuestAccept"):FireServer(targetNPC)
                    _G.CurrentQuest = targetNPC
                end

                -- Bước 3: BAY ĐẾN ĐIỂM FARM (Vận tốc 150)
                pcall(function()
                    if targetPos and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local root = player.Character.HumanoidRootPart
                        local hum = player.Character.Humanoid
                        local goalCFrame = CFrame.new(targetPos.X, targetPos.Y + 5, targetPos.Z) * CFrame.Angles(math.rad(-90), 0, 0)
                        local distance = (root.Position - Vector3.new(targetPos.X, targetPos.Y + 5, targetPos.Z)).Magnitude
                        
                        if distance > 5 then
                            local speed = 150
                            local duration = distance / speed
                            local tween = game:GetService("TweenService"):Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = goalCFrame})
                            tween:Play()
                        else
                            root.CFrame = goalCFrame
                        end
                        
                        root.Velocity = Vector3.new(0, 0, 0)
                        hum.PlatformStand = true
                        
                        for _, part in pairs(player.Character:GetChildren()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end
                end)
            end -- Kết thúc vòng lặp while
        end) -- Kết thúc task.spawn
    else
        -- Khi tắt Auto Farm
        pcall(function() game.Players.LocalPlayer.Character.Humanoid.PlatformStand = false end)
    end
end)

FarmSection:NewButton("Xóa Nhiệm Vụ Hiện Tại", "Gửi lệnh QuestAbandon", function()
    game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("QuestAbandon"):FireServer("repeatable")
    _G.CurrentQuest = ""
end)

-- ==========================================
-- PHẦN: SĂN BOSS GOJO (DÍNH THEO BOSS)
-- ==========================================
local GojoSection = MainTab:NewSection("Săn Boss Gojo")

_G.StickToBoss = false
local BOSS_NAME = "GojoBoss" -- Thay tên chính xác của Boss trong game bạn vào đây
local HEIGHT_ABOVE = 5   -- Luôn ở trên đầu 5 studs

GojoSection:NewToggle("Auto Stick Gojo (Dính Theo Boss)", "Boss đi đâu mình theo đó", function(state)
    _G.StickToBoss = state
    
    if state then
        -- BƯỚC 1: QUA CỔNG SHIBUYA
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("TeleportToPortal"):FireServer("Shibuya")
        end)
        
        task.wait(2) -- Đợi load map

        task.spawn(function()
            local player = game.Players.LocalPlayer
            local RunService = game:GetService("RunService")

            -- Vòng lặp dính theo Boss
            while _G.StickToBoss do
                RunService.RenderStepped:Wait() -- Cập nhật liên tục theo khung hình (Cực mượt)
                
                pcall(function()
                    local char = player.Character
                    local root = char.HumanoidRootPart
                    local hum = char.Humanoid
                    
                    -- TÌM BOSS TRONG WORKSPACE
                    local targetBoss = nil
                    -- Quét trong folder quái hoặc toàn bộ Workspace
                    for _, v in pairs(game:GetService("Workspace"):GetDescendants()) do
                        if v:IsA("Model") and v.Name:find(BOSS_NAME) and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid").Health > 0 then
                            targetBoss = v
                            break
                        end
                    end

                    if targetBoss then
                        -- NẾU TÌM THẤY BOSS: DÍNH CHẶT TRÊN ĐẦU
                        local bossRoot = targetBoss.HumanoidRootPart
                        root.Velocity = Vector3.new(0,0,0)
                        hum.PlatformStand = true
                        
                        -- Cập nhật tọa độ của mình = Tọa độ Boss + 5 studs chiều dọc (Y)
                        root.CFrame = bossRoot.CFrame * CFrame.new(0, HEIGHT_ABOVE, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        
                        -- Noclip để không bị đẩy
                        for _, part in pairs(char:GetChildren()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    else
                        -- NẾU CHƯA THẤY BOSS: BAY ĐẾN ĐIỂM CHỜ (Tọa độ cũ bạn đưa)
                        local waitPos = Vector3.new(1858.3266, 12.9861, 338.1400)
                        if (root.Position - waitPos).Magnitude > 5 then
                            root.CFrame = root.CFrame:Lerp(CFrame.new(waitPos.X, waitPos.Y + 15, waitPos.Z) * CFrame.Angles(math.rad(-90), 0, 0), 0.1)
                        end
                    end
                end)
            end
        end)
    else
        -- Tắt chế độ dính
        pcall(function() 
            game.Players.LocalPlayer.Character.Humanoid.PlatformStand = false 
        end)
    end
end)

-- NÚT ĐỔI SERVER (GIỮ NGUYÊN)
GojoSection:NewButton("Tìm Server Mới (Hop Server)", "Đổi server săn Boss", function()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    pcall(function()
        local Servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        for _, s in pairs(Servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, game.Players.LocalPlayer)
                break
            end
        end
    end)
end)
-- ==========================================
-- PHẦN 2: CHIẾN ĐẤU
-- ==========================================
local CombatSection = CombatTab:NewSection("Kỹ Năng & Đánh")

_G.AutoClick = false
CombatSection:NewToggle("Auto Click", "Tự động spam đánh", function(state)
    _G.AutoClick = state
    if state then
        task.spawn(function()
            while _G.AutoClick do
                game:GetService("ReplicatedStorage"):WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit"):FireServer()
                task.wait(0.1)
            end
        end)
    end
end)

_G.AutoSkillZ = false
CombatSection:NewToggle("Auto Skill Z", "Tự động dùng chiêu Z", function(state)
    _G.AutoSkillZ = state
    if state then
        task.spawn(function()
            while _G.AutoSkillZ do
                game:GetService("ReplicatedStorage"):WaitForChild("AbilitySystem"):WaitForChild("Remotes"):WaitForChild("RequestAbility"):FireServer(2)
                task.wait(0.5)
            end
        end)
    end
end)

