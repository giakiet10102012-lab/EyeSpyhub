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
-- PHẦN 3: TỐI ƯU HÓA (TAB FIX LAG)
-- ==========================================
local LagTab = Window:NewTab("Fix Lag")
local LagSection = LagTab:NewSection("Tối Ưu Hóa Hệ Thống")

-- 1. Chế độ Siêu Mượt (Xóa Texture)
LagSection:NewButton("Bật Chế Độ Siêu Mượt (Low Graphics)", "Xóa vân bề mặt để tăng FPS", function()
    local g = game
    local w = g.Workspace
    local l = g:GetService("Lighting")
    local t = w:FindFirstChildOfClass("Terrain")
    
    -- Giảm chất lượng địa hình
    if t then
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 0
    end
    
    -- Tắt hiệu ứng ánh sáng phức tạp
    l.GlobalShadows = false
    l.FogEnd = 9e9
    l.Brightness = 1
    
    -- Xóa Texture của tất cả vật thể trong game
    for _, v in pairs(g:GetDescendants()) do
        if v:IsA("Part") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") or v:IsA("WedgePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1 -- Làm tàng hình các hình dán/vân bề mặt
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Enabled = false -- Tắt hiệu ứng bụi, lửa, tia sáng
        end
    end
    print("EyeSpyhub: Đã tối ưu đồ họa!")
end)

-- 2. Chế độ Treo Máy (White Screen)
_G.WhiteScreen = false
LagSection:NewToggle("Chế Độ Treo Máy (Màn Hình Trắng)", "Giảm tải GPU cực mạnh khi treo đêm", function(state)
    _G.WhiteScreen = state
    if state then
        -- Che toàn bộ màn hình bằng 1 khung màu trắng/đen để GPU nghỉ ngơi
        local Gui = Instance.new("ScreenGui", game:GetService("CoreGui"))
        Gui.Name = "EyeSpy_WhiteScreen"
        local Frame = Instance.new("Frame", Gui)
        Frame.Size = UDim2.new(1, 0, 1, 0)
        Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Màu đen để đỡ hại mắt và tiết kiệm pin
        local Text = Instance.new("TextLabel", Frame)
        Text.Size = UDim2.new(1, 0, 1, 0)
        Text.BackgroundTransparency = 1
        Text.Text = "EYESPYHUB: ĐANG TREO MÁY...\nTẮT TOGGLE ĐỂ QUAY LẠI"
        Text.TextColor3 = Color3.fromRGB(255, 255, 255)
        Text.TextSize = 25
        
        task.spawn(function()
            while _G.WhiteScreen do
                game:GetService("RunService"):Set3dRenderingEnabled(false) -- Tắt Render 3D (Cực kỳ nhẹ máy)
                task.wait(1)
            end
            game:GetService("RunService"):Set3dRenderingEnabled(true)
            Gui:Destroy()
        end)
    else
        _G.WhiteScreen = false
    end
end)

-- 3. Xóa vật thể rác (Drops)
LagSection:NewButton("Dọn Rác Workspace", "Xóa các vật phẩm rơi vãi trên đất", function()
    pcall(function()
        for _, v in pairs(game.Workspace:GetChildren()) do
            if v:IsA("BasePart") and v.CanCollide == false then
                v:Destroy()
            end
        end
    end)
end)
-- 4. Giới Hạn FPS (Nhập số)
LagSection:NewTextBox("Giới Hạn FPS (Nhập Số)", "Ví dụ: 15, 30, 60", function(value)
    local fps = tonumber(value)
    if fps then
        -- Sử dụng setfpscap (Hầu hết các bản Executor hiện nay đều hỗ trợ)
        if setfpscap then
            setfpscap(fps)
            print("EyeSpyhub: Đã giới hạn FPS còn: " .. fps)
        else
            -- Cách dự phòng nếu Executor không có setfpscap
            game:GetService("RunService"):Set3dRenderingEnabled(true) -- Đảm bảo render đang bật
            settings().Network.IncomingReplicationLag = 0
            print("Thiết bị của bạn không hỗ trợ setfpscap trực tiếp.")
        end
    else
        print("Vui lòng nhập một con số hợp lệ!")
    end
end)

-- Nút Reset FPS về mặc định
LagSection:NewButton("Reset FPS (Về 60)", "Quay lại tốc độ mượt bình thường", function()
    if setfpscap then
        setfpscap(60)
    end
end)

