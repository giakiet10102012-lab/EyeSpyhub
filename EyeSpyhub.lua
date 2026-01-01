local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local VIM = game:GetService("VirtualInputManager")

-- [[ CẤU HÌNH ]]
_G.AutoLevel = false
_G.Distance = 12 
_G.FlySpeed = 300 

local function msk(s) return #s<=3 and s or s:sub(1,3)..string.rep("*",#s-3) end

-- [[ HÀM TỰ ĐỘNG CẦM VŨ KHÍ ]]
local function CheckAndEquip()
    local player = game.Players.LocalPlayer
    if not player.Character:FindFirstChildOfClass("Tool") then
        for _, tool in pairs(player.Backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
                player.Character.Humanoid:EquipTool(tool)
                break
            end
        end
    end
end

-- [[ GIAO DIỆN ]]
local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub | Optimized Farm",
    SubTitle = "Fixed Attack & Single Target",
    TabWidth = 160, Size = UDim2.fromOffset(550, 380), Theme = "Dark"
})

local Tabs = { Main = Window:AddTab({ Title = "Auto Farm", Icon = "home" }) }

Tabs.Main:AddToggle("LevelToggle", {Title = "Bật Auto Farm (Single Target)", Default = false }):OnChanged(function()
    _G.AutoLevel = Fluent.Options.LevelToggle.Value
end)

-- [[ VÒNG LẶP CHÍNH ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            pcall(function()
                local player = game.Players.LocalPlayer
                local character = player.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then return end

                -- TÌM 1 CON QUÁI DUY NHẤT (Gần nhất)
                local targetMob = nil
                local shortestDistance = math.huge

                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and v:FindFirstChild("HumanoidRootPart") then
                        local dist = (character.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
                        if dist < shortestDistance then
                            shortestDistance = dist
                            targetMob = v
                        end
                    end
                end

                -- NẾU CÓ MỤC TIÊU
                if targetMob then
                    CheckAndEquip() -- Cầm vũ khí
                    
                    repeat
                        if not _G.AutoLevel or not targetMob.Parent or targetMob.Humanoid.Health <= 0 then break end

                        -- KHÓA VỊ TRÍ TRÊN ĐẦU
                        character.HumanoidRootPart.CFrame = targetMob.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        
                        -- GOM QUÁI XUNG QUANH VÀO MỤC TIÊU CHÍNH
                        targetMob.HumanoidRootPart.CanCollide = false
                        targetMob.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                        
                        -- THỰC HIỆN ĐÁNH (Gửi tín hiệu nhấn chuột thật)
                        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                        
                        -- Lệnh đánh dự phòng của Blox Fruits
                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Attack")
                        
                        task.wait(0.1) -- Tốc độ đánh
                    until not _G.AutoLevel or targetMob.Humanoid.Health <= 0
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

-- Nút thu nhỏ
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local ToggleBtn = Instance.new("TextButton", ScreenGui)
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0, 10, 0.5, 0)
ToggleBtn.Text = "Eye"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
ToggleBtn.MouseButton1Click:Connect(function() Window:Minimize() end)

Fluent:Notify({ Title = "EyeSpyhub", Content = "Đã cập nhật hệ thống đánh và khóa mục tiêu!", Duration = 5 })
