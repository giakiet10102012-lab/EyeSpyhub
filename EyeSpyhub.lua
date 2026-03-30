local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub - Sailor Piece",
    SubTitle = "by EyeSpy",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Auto Farm", Icon = "home" }),
    Boss = Window:AddTab({ Title = "Săn GojoBoss", Icon = "target" }),
    Combat = Window:AddTab({ Title = "Chiến Đấu", Icon = "swords" }),
    FixLag = Window:AddTab({ Title = "Siêu Tối Ưu", Icon = "zap" })
}

-- ==========================================
-- BIẾN HỆ THỐNG (CẬP NHẬT)
-- ==========================================
_G.AutoFarm = false
_G.StickToBoss = false
_G.AutoClick = false

-- Cấu hình Vũ khí & Kỹ năng
_G.SelectWeapon = "Melee" -- Mặc định: "Melee" hoặc "Sword"
_G.UseSkillZ = false
_G.UseSkillX = false
_G.UseSkillC = false
_G.UseSkillV = false

local QuestTable = {
    {Min = 8000, Max = 8999, NPC = "QuestNPC14", Pos = Vector3.new(-1124.75, 19.7, 371.23)},
    {Min = 9000, Max = 9999, NPC = "QuestNPC15", Pos = Vector3.new(1072.546, 6.778, 1275.642)}, 
    {Min = 10000, Max = 11499, NPC = "QuestNPC16", Pos = Vector3.new(-1274.657, 6.175, -1191.39)}, 
    {Min = 11500, Max = 11999, NPC = "QuestNPC18", Pos = Vector3.new(-1876.007, 13.572, -738.603)}, 
    {Min = 12000, Max = 100000, NPC = "QuestNPC19", Pos = Vector3.new(59.851, 5.579, 1816.135)}
}

-- ==========================================
-- HÀM HỖ TRỢ (CẬP NHẬT)
-- ==========================================

-- Hàm trang bị vũ khí tự động dựa trên loại đã chọn (Melee/Sword)
local function EquipWeapon()
    local p = game.Players.LocalPlayer
    local char = p.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    
    -- Quét trong Backpack để tìm vũ khí khớp với loại đã chọn
    for _, tool in pairs(p.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            -- Kiểm tra ToolTip hoặc Tên vũ khí (Sailor Piece thường dùng ToolTip để phân loại)
            if (tool.ToolTip and tool.ToolTip:find(_G.SelectWeapon)) or (tool.Name:lower():find(_G.SelectWeapon:lower())) then
                char.Humanoid:EquipTool(tool)
                break
            end
        end
    end
end

-- Hàm tung kỹ năng dựa trên các lựa chọn Toggle (Z, X, C, V)
local function UseSkills()
    local Remote = game:GetService("ReplicatedStorage"):WaitForChild("AbilitySystem"):WaitForChild("Remotes"):WaitForChild("RequestAbility")
    
    -- Chỉ tung chiêu nếu ô tương ứng được bật
    if _G.UseSkillZ then 
        Remote:FireServer(1) 
        task.wait(0.05) 
    end
    if _G.UseSkillX then 
        Remote:FireServer(2) 
        task.wait(0.05) 
    end
    if _G.UseSkillC then 
        Remote:FireServer(3) 
        task.wait(0.05) 
    end
    if _G.UseSkillV then 
        Remote:FireServer(4) 
        task.wait(0.05) 
    end
end

-- ==========================================
-- TAB 1: AUTO FARM (ĐÃ TỐI ƯU)
-- ==========================================
local FarmToggle = Tabs.Main:AddToggle("FarmToggle", {Title = "Bật Auto Farm (Tốc độ 150)", Default = false})

FarmToggle:OnChanged(function()
    _G.AutoFarm = Fluent.Options.FarmToggle.Value
    
    if _G.AutoFarm then
        task.spawn(function()
            while _G.AutoFarm do
                task.wait(0.1)
                pcall(function()
                    local player = game.Players.LocalPlayer
                    local char = player.Character
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChild("Humanoid")
                    
                    if root and hum then
                        -- 1. Luôn cầm vũ khí đã chọn (Melee/Sword)
                        EquipWeapon()
                        
                        -- 2. Xác định mục tiêu dựa trên Level
                        local myLv = player.Data.Level.Value
                        local targetPos
                        for _, v in pairs(QuestTable) do
                            if myLv >= v.Min and myLv <= v.Max then 
                                targetPos = v.Pos 
                                break 
                            end
                        end

                        if targetPos then
                            -- Chống rơi và giữ nhân vật ổn định
                            hum.PlatformStand = true
                            root.Velocity = Vector3.new(0, 0, 0)
                            
                            -- Hướng mặt xuống dưới (-90 độ)
                            local goalCFrame = CFrame.new(targetPos.X, targetPos.Y + 5, targetPos.Z) * CFrame.Angles(math.rad(-90), 0, 0)
                            
                            local dist = (root.Position - targetPos).Magnitude
                            if dist > 5 then
                                -- Di chuyển mượt mà tới bãi quái
                                game:GetService("TweenService"):Create(root, TweenInfo.new(dist/150, Enum.EasingStyle.Linear), {CFrame = goalCFrame}):Play()
                            else
                                -- Khi đã đến nơi: Khóa vị trí và tung Skill
                                root.CFrame = goalCFrame
                                UseSkills() -- Tung các chiêu Z, X, C, V đã chọn
                            end
                            
                            -- Tắt va chạm để tránh văng khi quái xuất hiện
                            for _, part in pairs(char:GetChildren()) do
                                if part:IsA("BasePart") then part.CanCollide = false end
                            end
                        end
                    end
                end)
            end
        end)
    else
        -- KHI TẮT FARM: TRẢ NHÂN VẬT VỀ TRẠNG THÁI BÌNH THƯỜNG
        pcall(function()
            local char = game.Players.LocalPlayer.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            if root and hum then
                hum.PlatformStand = false
                -- Đứng thẳng lại ngay lập tức
                root.CFrame = CFrame.new(root.Position) 
                root.Velocity = Vector3.new(0, 0, 0)
                
                -- Bật lại va chạm để có thể đi lại bình thường
                for _, part in pairs(char:GetChildren()) do
                    if part:IsA("BasePart") then 
                        part.CanCollide = true 
                    end
                end
            end
        end)
    end
end)
-- ==========================================
-- TAB 2: SĂN GOJOBOSS
-- ==========================================
local StickToggle = Tabs.Boss:AddToggle("StickGojo", {Title = "Dính Theo GojoBoss", Default = false})
StickToggle:OnChanged(function()
    _G.StickToBoss = Fluent.Options.StickGojo.Value
    if _G.StickToBoss then
        pcall(function() game:GetService("ReplicatedStorage").Remotes.TeleportToPortal:FireServer("Shibuya") end)
        task.spawn(function()
            while _G.StickToBoss do
                game:GetService("RunService").Heartbeat:Wait()
                pcall(function()
                    local player = game.Players.LocalPlayer
                    local root = player.Character.HumanoidRootPart
                    local targetBoss = nil
                    for _, v in pairs(game.Workspace:GetDescendants()) do
                        if v:IsA("Model") and v.Name:find("GojoBoss") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                            targetBoss = v break
                        end
                    end
                    if targetBoss then
                        EquipWeapon()
                        root.Velocity = Vector3.new(0,0,0)
                        root.CFrame = targetBoss.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        if _G.AutoSkill then UseSkills() end
                    end
                end)
            end
        end)
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
-- TAB 3: CHIẾN ĐẤU (COMBAT)
-- ==========================================
_G.SelectedWeaponName = nil
_G.AutoSkill = false
_G.AutoClick = false

local CombatSection = Tabs.Combat:AddSection("Cấu Hình Chiến Đấu")

-- Nút nhận diện vũ khí đang cầm trên tay
Tabs.Combat:AddButton({
    Title = "Xác Nhận Vũ Khí Đang Cầm",
    Description = "Hãy cầm Kiếm hoặc Melee trên tay rồi bấm nút này",
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            _G.SelectedWeaponName = tool.Name
            Fluent:Notify({
                Title = "EyeSpyhub",
                Content = "Đã khóa vũ khí: " .. tool.Name,
                Duration = 3
            })
        else
            Fluent:Notify({
                Title = "EyeSpyhub",
                Content = "LỖI: Bạn phải cầm vũ khí trên tay trước!",
                Duration = 3
            })
        end
    end
})

-- Toggle Auto Click
local ClickToggle = Tabs.Combat:AddToggle("AutoClick", {Title = "Auto Click (Chuột Trái)", Default = false})
ClickToggle:OnChanged(function()
    _G.AutoClick = Fluent.Options.AutoClick.Value
    task.spawn(function()
        while _G.AutoClick do
            pcall(function()
                game:GetService("ReplicatedStorage").CombatSystem.Remotes.RequestHit:FireServer()
            end)
            task.wait(0.1)
        end
    end)
end)

-- Toggle Auto Skill (Z, X, C, V)
local SkillToggle = Tabs.Combat:AddToggle("AutoSkill", {Title = "Auto Tung Skill (Z, X, C, V)", Default = false})
SkillToggle:OnChanged(function()
    _G.AutoSkill = Fluent.Options.AutoSkill.Value
    task.spawn(function()
        local Remote = game:GetService("ReplicatedStorage"):WaitForChild("AbilitySystem"):WaitForChild("Remotes"):WaitForChild("RequestAbility")
        while _G.AutoSkill do
            -- Chỉ tung skill khi đang Auto Farm hoặc Săn Boss
            if _G.AutoFarm or _G.StickToBoss then
                pcall(function()
                    -- Tung lần lượt các chiêu 1, 2, 3, 4 (Tương ứng Z, X, C, V)
                    for i = 1, 4 do
                        Remote:FireServer(i)
                        task.wait(0.1) -- Delay nhỏ giữa các chiêu để tránh kẹt combo
                    end
                end)
            end
            task.wait(0.5) -- Nghỉ một chút trước khi lặp lại vòng combo mới
        end
    end)
end)

-- Hàm hỗ trợ (Đảm bảo hàm này nằm trong script chính để Auto Farm gọi được)
function EquipWeapon()
    if _G.SelectedWeaponName then
        local p = game.Players.LocalPlayer
        local tool = p.Backpack:FindFirstChild(_G.SelectedWeaponName)
        if tool and p.Character and p.Character:FindFirstChild("Humanoid") then
            p.Character.Humanoid:EquipTool(tool)
            end
    end
end

-- ==========================================
-- TAB 4: SIÊU TỐI ƯU (FIX LAG)
-- ==========================================
local LagSection = Tabs.FixLag:AddSection("Tối Ưu Phần Cứng")

-- 1. Ô nhập giới hạn FPS tùy chỉnh
Tabs.FixLag:AddInput("CustomFPS", {
    Title = "Giới Hạn FPS Tùy Chỉnh",
    Default = "60",
    Placeholder = "Nhập số FPS (VD: 15, 30, 60...)",
    Numeric = true, -- Chỉ cho phép nhập số
    Finished = true, -- Chỉ chạy callback khi bấm Enter
    Callback = function(Value)
        local fps = tonumber(Value)
        if fps and fps > 0 then
            if setfpscap then
                setfpscap(fps)
                Fluent:Notify({
                    Title = "EyeSpyhub",
                    Content = "Đã giới hạn FPS còn: " .. fps,
                    Duration = 3
                })
            else
                Fluent:Notify({
                    Title = "EyeSpyhub",
                    Content = "Executor của bạn không hỗ trợ setfpscap!",
                    Duration = 3
                })
            end
        end
    end
})

-- 2. Nút Siêu Giảm CPU/GPU (Cập nhật logic mát máy)
Tabs.FixLag:AddButton({
    Title = "Chế Độ Treo Máy (Siêu Mát)",
    Description = "Giảm FPS xuống 10 và Tắt Render 3D",
    Callback = function()
        -- Giảm FPS xuống mức tối thiểu để CPU nghỉ ngơi
        if setfpscap then setfpscap(10) end
        
        -- Tắt vẽ hình ảnh 3D để GPU không phải làm việc
        game:GetService("RunService"):Set3dRenderingEnabled(false)
        
        -- Xóa bớt hiệu ứng thừa
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = false
            end
        end

        Fluent:Notify({
            Title = "EyeSpyhub",
            Content = "Đã vào chế độ treo máy (10 FPS + No Render)",
            Duration = 5
        })
    end
})

-- 3. Nút Hồi Phục
Tabs.FixLag:AddButton({
    Title = "Hồi Phục Đồ Họa & FPS",
    Description = "Bật lại Render và đưa FPS về 60",
    Callback = function()
        game:GetService("RunService"):Set3dRenderingEnabled(true)
        if setfpscap then setfpscap(60) end
        
        Fluent:Notify({
            Title = "EyeSpyhub",
            Content = "Đã trở lại bình thường!",
            Duration = 3
        })
    end
})

-- ==========================================
-- NÚT BẬT TẮT GUI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
local Toggle = Instance.new("TextButton")
local Corner = Instance.new("UICorner")

ScreenGui.Name = "EyeSpy_Toggle"
ScreenGui.Parent = game:GetService("CoreGui")

Toggle.Name = "ToggleButton"
Toggle.Parent = ScreenGui
Toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Toggle.Position = UDim2.new(0.1, 0, 0.15, 0)
Toggle.Size = UDim2.new(0, 50, 0, 50)
Toggle.Font = Enum.Font.GothamBold
Toggle.Text = "EYE"
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
Toggle.Draggable = true

Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = Toggle

Toggle.MouseButton1Click:Connect(function()
    Window:Minimize()
end)

Window:SelectTab(1)
Fluent:Notify({Title = "EyeSpyhub", Content = "Hãy cầm vũ khí và bấm 'Chọn Vũ Khí Đang Cầm'!", Duration = 5})
