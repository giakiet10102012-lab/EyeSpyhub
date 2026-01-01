local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- [[ CẤU HÌNH EYESPYHUB ]]
_G.AutoLevel = false
_G.Distance = 12 
_G.FlySpeed = 300 

local function msk(s) return #s<=3 and s or s:sub(1,3)..string.rep("*",#s-3) end

-- [[ KHỞI TẠO WINDOW ]]
local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub | Blox Fruits",
    SubTitle = "Partner: " .. msk(game.Players.LocalPlayer.Name),
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 380),
    Acrylic = true,
    Theme = "Dark"
})

-- [[ TẠO NÚT BẬT/TẮT GUI (MẶT TRÒN NHỎ) ]]
local ScreenGui = Instance.new("ScreenGui")
local ToggleBtn = Instance.new("TextButton")

ScreenGui.Parent = game:GetService("CoreGui")
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
ToggleBtn.Position = UDim2.new(0, 10, 0.5, 0) -- Nằm bên trái giữa màn hình
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Text = "Eye"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 18

-- Bo tròn nút
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1, 0)
Corner.Parent = ToggleBtn

-- Logic ẩn/hiện GUI khi bấm nút
ToggleBtn.MouseButton1Click:Connect(function()
    Window:Minimize() -- Hàm thu gọn/hiện lại của thư viện Fluent
end)

-- [[ CÁC TAB ]]
local Tabs = { 
    Main = Window:AddTab({ Title = "Auto Farm", Icon = "rbxassetid://4483345998" }),
    Control = Window:AddTab({ Title = "Hệ thống", Icon = "settings" })
}

Tabs.Main:AddToggle("LevelToggle", {Title = "Bật Auto Farm", Default = false }):OnChanged(function()
    _G.AutoLevel = Fluent.Options.LevelToggle.Value
end)

-- Nút xóa hẳn script
Tabs.Control:AddButton({
    Title = "Xóa hoàn toàn Script",
    Callback = function()
        _G.AutoLevel = false
        ScreenGui:Destroy()
        Fluent:Destroy()
    end
})

-- [[ HÀM DI CHUYỂN TWEEN ]]
local function SmoothTween(targetCFrame)
    local rootPart = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local tween = game:GetService("TweenService"):Create(rootPart, TweenInfo.new(distance / _G.FlySpeed, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- [[ LOGIC VẬN HÀNH ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoLevel then
            pcall(function()
                local player = game.Players.LocalPlayer
                local char = player.Character
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        local safePos = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        SmoothTween(safePos)
                        repeat
                            if not _G.AutoLevel or v.Humanoid.Health <= 0 then break end
                            char.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            v.HumanoidRootPart.CanCollide = false
                            v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
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

-- [[ ANTI-BAN ]]
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    if getnamecallmethod() == "FireServer" and (tostring(self) == "AdminIT" or tostring(self):find("Detect")) then return nil end
    return old(self, ...)
end)
setreadonly(mt, true)

Fluent:Notify({ Title = "EyeSpyhub", Content = "Nhấn nút 'Eye' bên trái để ẩn/hiện Menu!", Duration = 5 })
