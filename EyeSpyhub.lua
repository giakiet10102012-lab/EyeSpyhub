local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- [[ CẤU HÌNH EYESPYHUB ]]
_G.AutoLevel = false
_G.Distance = 12 
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
    Title = "EyeSpyhub | Blox Fruits",
    SubTitle = "Partner: " .. msk(game.Players.LocalPlayer.Name),
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 380),
    Acrylic = true,
    Theme = "Dark"
})

local Tabs = { 
    Main = Window:AddTab({ Title = "Auto Farm", Icon = "rbxassetid://4483345998" }),
    Control = Window:AddTab({ Title = "Hệ thống", Icon = "settings" })
}

-- [NÚT BẬT/TẮT TRONG TAB CHÍNH]
Tabs.Main:AddToggle("LevelToggle", {Title = "Bật Auto Farm (Bay trên đầu quái)", Default = false }):OnChanged(function()
    _G.AutoLevel = Fluent.Options.LevelToggle.Value
end)

-- [NÚT TẮT HẲN SCRIPT TRONG TAB HỆ THỐNG]
Tabs.Control:AddButton({
    Title = "Tắt hoàn toàn Script",
    Description = "Xóa giao diện và dừng tất cả hoạt động của EyeSpyhub",
    Callback = function()
        Window:Dialog({
            Title = "Xác nhận",
            Content = "Bạn có chắc chắn muốn tắt EyeSpyhub không?",
            Buttons = {
                {
                    Title = "Xác nhận",
                    Callback = function()
                        _G.AutoLevel = false
                        Fluent:Destroy() -- Xóa giao diện Fluent
                    end
                },
                {
                    Title = "Hủy",
                    Callback = function() end
                }
            }
        })
    end
})

-- [[ LOGIC VẬN HÀNH AN TOÀN ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            pcall(function()
                local player = game.Players.LocalPlayer
                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then return end

                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        local safePos = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        SmoothTween(safePos)
                        
                        repeat
                            if not _G.AutoLevel or v.Humanoid.Health <= 0 or not Fluent.Unloaded == false then break end
                            
                            -- KHÓA VỊ TRÍ TRÊN ĐẦU QUÁI
                            char.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            
                            -- GOM QUÁI & HITBOX
                            v.HumanoidRootPart.CanCollide = false
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

Fluent:Notify({ Title = "EyeSpyhub", Content = "Script đã sẵn sàng cày thuê!", Duration = 5 })
