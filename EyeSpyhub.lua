local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- [[ BIẾN ĐIỀU KHIỂN ]]
_G.AutoLevel = false
_G.Distance = 10

-- Hàm che tên bảo mật
local function msk(s) return #s<=3 and s or s:sub(1,3)..string.rep("*",#s-3) end

-- [[ CẤU TRÌNH WINDOW ]]
local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub | Auto Farm Level",
    SubTitle = "Bảo mật cho: " .. msk(game.Players.LocalPlayer.Name),
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 380),
    Acrylic = true,
    Theme = "Dark"
})

local Tabs = {
    Main = Window:AddTab({ Title = "Chính", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Cài đặt", Icon = "settings" })
}

Tabs.Main:AddParagraph({
    Title = "Hệ thống EyeSpyhub",
    Content = "Tự động nhận nhiệm vụ theo Level và gom quái."
})

local LevelToggle = Tabs.Main:AddToggle("LevelToggle", {Title = "Bật Auto Farm Level", Default = false })
LevelToggle:OnChanged(function()
    _G.AutoLevel = Fluent.Options.LevelToggle.Value
end)

-- [[ HÀM LOGIC BLOX FRUITS ]]

-- Hàm kiểm tra Level và lấy dữ liệu nhiệm vụ (Ví dụ đơn giản cho Sea 1)
function GetQuest()
    local lvl = game.Players.LocalPlayer.Data.Level.Value
    if lvl >= 0 and lvl < 10 then
        return "Bandit", "BanditQuest1", 1 -- Tên quái, Tên Quest, ID Quest
    elseif lvl >= 10 and lvl < 15 then
        return "Monkey", "JungleQuest", 1
    -- Bạn có thể thêm các bãi quái khác ở đây dựa theo Level
    else
        return "Bandit", "BanditQuest1", 1 -- Mặc định
    end
end

-- Vòng lặp chính của EyeSpyhub
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            pcall(function()
                local mobName, questName, questID = GetQuest()
                local player = game.Players.LocalPlayer
                
                -- Kiểm tra xem đã nhận nhiệm vụ chưa
                if not player.PlayerGui.Main:FindFirstChild("Quest") or player.PlayerGui.Main.Quest.Visible == false then
                    -- Bay đến NPC nhận nhiệm vụ (Đây là logic giả lập, cần tọa độ NPC chính xác)
                    -- game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Tọa_độ_NPC
                    print("Đang đi nhận nhiệm vụ: " .. questName)
                else
                    -- Nếu có nhiệm vụ rồi thì đi tìm quái
                    for _, v in pairs(workspace.Enemies:GetChildren()) do
                        if v.Name == mobName and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            repeat
                                if not _G.AutoLevel then break end
                                -- Gom quái & Hitbox
                                v.HumanoidRootPart.CanCollide = false
                                v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                                
                                -- Bay trên đầu quái
                                player.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                
                                -- Auto Click
                                game:GetService("VirtualUser"):CaptureController()
                                game:GetService("VirtualUser"):Button1Down(Vector2.new(1280, 672))
                                
                                task.wait()
                            until v.Humanoid.Health <= 0 or not _G.AutoLevel
                        end
                    end
                end
            end)
        end
    end
end)

-- [[ BẢO MẬT & ANTI-DETECTION ]]
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    if getnamecallmethod() == "FireServer" and (tostring(self) == "AdminIT" or tostring(self):find("Detect")) then
        return nil
    end
    return old(self, ...)
end)
setreadonly(mt, true)

-- Chống AFK
game.Players.LocalPlayer.Idled:Connect(function()
    game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

Fluent:Notify({
    Title = "EyeSpyhub Activated",
    Content = "Hệ thống cày Level tự động đã sẵn sàng!",
    Duration = 5
})
