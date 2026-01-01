local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- [[ CẤU HÌNH EYESPYHUB ]]
_G.AutoLevel = false
_G.Distance = 12 -- Khoảng cách bay TRÊN đầu quái (An toàn nhất là 10-12)
_G.FlySpeed = 300 

local function msk(s) return #s<=3 and s or s:sub(1,3)..string.rep("*",#s-3) end

-- Hàm di chuyển Tween tốc độ 300
local function SmoothTween(targetCFrame)
    local rootPart = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local tween = game:GetService("TweenService"):Create(rootPart, TweenInfo.new(distance / _G.FlySpeed, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- [[ GIAO DIỆN ]]
local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub | Safe Farm Mode",
    SubTitle = "Tên: " .. msk(game.Players.LocalPlayer.Name),
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 380),
    Acrylic = true,
    Theme = "Dark"
})

local Tabs = { Main = Window:AddTab({ Title = "Auto Farm", Icon = "rbxassetid://4483345998" }) }

Tabs.Main:AddToggle("LevelToggle", {Title = "Bật Auto Farm (Bay trên đầu quái)", Default = false }):OnChanged(function()
    _G.AutoLevel = Fluent.Options.LevelToggle.Value
end)

-- [[ LOGIC VẬN HÀNH AN TOÀN ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            pcall(function()
                local player = game.Players.LocalPlayer
                local char = player.Character
                
                -- Tìm quái mục tiêu (Ví dụ: đang đứng gần quái nào đánh quái đó hoặc theo tên)
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        
                        -- Tọa độ mục tiêu: Luôn nằm TRÊN HumanoidRootPart của quái 1 khoảng _G.Distance
                        -- CFrame.Angles giúp nhân vật hướng mặt xuống dưới để đánh dễ hơn
                        local safePos = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        
                        -- Di chuyển đến vị trí an toàn
                        SmoothTween(safePos)
                        
                        repeat
                            if not _G.AutoLevel or v.Humanoid.Health <= 0 then break end
                            
                            -- GIỮ VỊ TRÍ: Khóa vị trí nhân vật trên đầu quái liên tục
                            char.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            
                            -- GOM QUÁI & HITBOX: Quái đứng yên và to ra để dễ đánh trúng
                            v.HumanoidRootPart.CanCollide = false
                            if v.HumanoidRootPart:FindFirstChild("BodyVelocity") then v.HumanoidRootPart.BodyVelocity:Destroy() end -- Chống quái bị văng
                            v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                            
                            -- AUTO CLICK
                            game:GetService("VirtualUser"):CaptureController()
                            game:GetService("VirtualUser"):Button1Down(Vector2.new(1280, 672))
                            
                            task.wait()
                        until v.Humanoid.Health <= 0 or not _G.AutoLevel
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

Fluent:Notify({ Title = "EyeSpyhub", Content = "Chế độ Bay trên đầu quái đã kích hoạt!", Duration = 5 })
