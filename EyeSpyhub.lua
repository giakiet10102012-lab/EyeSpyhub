local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- [[ CẤU HÌNH ]]
_G.AutoLevel = false
_G.Distance = 12 
_G.FlySpeed = 300 

-- [[ HÀM TỰ ĐỘNG CẦM VŨ KHÍ ]]
local function CheckAndEquip()
    local player = game.Players.LocalPlayer
    if not player.Character:FindFirstChildOfClass("Tool") then
        local backpack = player.Backpack
        -- Ưu tiên cầm Melee (Combat, Dark Step, v.v.)
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
                player.Character.Humanoid:EquipTool(tool)
                break
            end
        end
    end
end

-- [[ HÀM TỰ ĐỘNG ĐÁNH CHUYÊN DỤNG CHO BLOX FRUITS ]]
local function AutoAttack()
    pcall(function()
        -- Cách 1: Sử dụng Remote nội bộ của Blox Fruits (Cực nhanh và chuẩn)
        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Attack")
        
        -- Cách 2: Giả lập click chuột (Dự phòng)
        local VirtualUser = game:GetService("VirtualUser")
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(1280, 672))
    end)
end

-- [[ GIAO DIỆN ]]
local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub | Fix Auto Attack",
    SubTitle = "Bản sửa lỗi đánh quái",
    TabWidth = 160, Size = UDim2.fromOffset(550, 380), Theme = "Dark"
})

local Tabs = { Main = Window:AddTab({ Title = "Auto Farm", Icon = "home" }) }

Tabs.Main:AddToggle("LevelToggle", {Title = "Bật Auto Farm & Quest", Default = false }):OnChanged(function()
    _G.AutoLevel = Fluent.Options.LevelToggle.Value
end)

-- [[ VÒNG LẶP ĐÁNH QUÁI RIÊNG BIỆT (ĐỂ KHÔNG BỊ DELAY) ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            CheckAndEquip() -- Luôn kiểm tra xem đã cầm vũ khí chưa
            AutoAttack()    -- Thực hiện lệnh đánh
        end
    end
end)

-- [[ VÒNG LẶP DI CHUYỂN VÀ GOM QUÁI ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            pcall(function()
                local player = game.Players.LocalPlayer
                -- (Phần logic tìm quái mobName đã có ở bản trước, mình viết gọn lại để tập trung vào sửa lỗi đánh)
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        -- Khóa vị trí trên đầu quái
                        player.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        
                        -- Gom quái
                        v.HumanoidRootPart.CanCollide = false
                        v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                        
                        task.wait()
                    end
                end
            end)
        end
    end
end)

-- [[ CHỐNG PHÁT HIỆN ]]
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    if getnamecallmethod() == "FireServer" and (tostring(self) == "AdminIT" or tostring(self):find("Detect")) then return nil end
    return old(self, ...)
end)
setreadonly(mt, true)

Fluent:Notify({ Title = "EyeSpyhub", Content = "Đã sửa lỗi Auto Attack!", Duration = 5 })
