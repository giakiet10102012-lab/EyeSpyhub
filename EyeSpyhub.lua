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

                -- Bước 3: BAY ĐẾN ĐIỂM FARM (Vận tốc 300)
                pcall(function()
                    if targetPos and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local root = player.Character.HumanoidRootPart
                        local hum = player.Character.Humanoid
                        local goalCFrame = CFrame.new(targetPos.X, targetPos.Y + 5, targetPos.Z) * CFrame.Angles(math.rad(-90), 0, 0)
                        local distance = (root.Position - Vector3.new(targetPos.X, targetPos.Y + 5, targetPos.Z)).Magnitude
                        
                        if distance > 5 then
                            local speed = 300
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

-- ==========================================
-- PHẦN 3: THÔNG TIN
-- ==========================================
local InfoSection = CreditTab:NewSection("EyeSpyhub v1.0")
InfoSection:NewButton("Tác giả: EyeSpy", "Chúc bạn farm vui vẻ!", function()
    print("Script đã sẵn sàng!")
end)
