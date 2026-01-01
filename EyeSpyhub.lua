local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- [[ CẤU HÌNH EYESPYHUB ]]
_G.AutoLevel = false
_G.Distance = 10
_G.FlySpeed = 300 -- Tốc độ bay tối đa theo yêu cầu của bạn

-- Hàm che tên bảo mật
local function msk(s) return #s<=3 and s or s:sub(1,3)..string.rep("*",#s-3) end

-- Hàm di chuyển mượt mà (Tween) với tốc độ cố định
local function SmoothTween(targetCFrame)
    local character = game.Players.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local duration = distance / _G.FlySpeed -- Tính toán thời gian dựa trên tốc độ 300
    
    local tween = game:GetService("TweenService"):Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- [[ KHỞI TẠO WINDOW ]]
local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub | Speed: " .. _G.FlySpeed,
    SubTitle = "Partner: " .. msk(game.Players.LocalPlayer.Name),
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 380),
    Acrylic = true,
    Theme = "Dark"
})

local Tabs = {
    Main = Window:AddTab({ Title = "Chính", Icon = "home" }),
}

local LevelToggle = Tabs.Main:AddToggle("LevelToggle", {Title = "Bật Auto Farm Level (Speed 300)", Default = false })
LevelToggle:OnChanged(function()
    _G.AutoLevel = Fluent.Options.LevelToggle.Value
end)

-- [[ LOGIC VẬN HÀNH ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            pcall(function()
                local player = game.Players.LocalPlayer
                local character = player.Character
                
                -- Tìm quái (Ví dụ đơn giản, bạn có thể kết hợp với hàm GetQuest trước đó)
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        
                        -- Di chuyển đến quái với tốc độ 300
                        local targetPos = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        local move = SmoothTween(targetPos)
                        
                        -- Đợi cho đến khi đến nơi hoặc quái chết
                        repeat 
                            task.wait()
                            -- Gom quái
                            v.HumanoidRootPart.CanCollide = false
                            v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                            
                            -- Auto Click
                            game:GetService("VirtualUser"):CaptureController()
                            game:GetService("VirtualUser"):Button1Down(Vector2.new(1280, 672))
                        until v.Humanoid.Health <= 0 or not _G.AutoLevel
                    end
                end
            end)
        end
    end
end)

-- [[ BẢO MẬT ]]
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

Fluent:Notify({
    Title = "EyeSpyhub",
    Content = "Tốc độ bay đã được giới hạn ở mức 300!",
    Duration = 5
})
