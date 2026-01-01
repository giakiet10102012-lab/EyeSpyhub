local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- [[ BIẾN CÀI ĐẶT ]]
_G.AutoFarm = false
_G.SelectedMob = ""
_G.FastAttack = true
_G.Distance = 10 

-- Hàm che tên bảo mật
local function msk(s) return #s<=3 and s or s:sub(1,3)..string.rep("*",#s-3) end

-- [[ KHỞI TẠO WINDOW ]]
local Window = Fluent:CreateWindow({
    Title = "EyeSpyhub | Blox Fruits",
    SubTitle = "Cày thuê cho: " .. msk(game.Players.LocalPlayer.Name),
    TabWidth = 160,
    Size = UDim2.fromOffset(530, 350),
    Acrylic = true, 
    Theme = "Dark"
})

local Tabs = {
    Main = Window:AddTab({ Title = "Auto Farm", Icon = "rbxassetid://4483345998" }),
    Settings = Window:AddTab({ Title = "Cài đặt", Icon = "settings" })
}

-- [[ TAB MAIN ]]
Tabs.Main:AddParagraph({
    Title = "Trạng thái đơn cày",
    Content = "User: " .. msk(game.Players.LocalPlayer.DisplayName) .. "\nĐang chạy script EyeSpyhub..."
})

local MobInput = Tabs.Main:AddInput("MobInput", {
    Title = "Tên Quái (VD: Monkey, Galley Pirate...)",
    Default = "",
    Placeholder = "Nhập tên quái...",
    Callback = function(Value)
        _G.SelectedMob = Value
    end
})

local FarmToggle = Tabs.Main:AddToggle("FarmToggle", {Title = "Bật Auto Farm Quái", Default = false })

FarmToggle:OnChanged(function()
    _G.AutoFarm = Fluent.Options.FarmToggle.Value
end)

-- [[ HỆ THỐNG ĐÁNH VÀ DI CHUYỂN ]]
task.spawn(function()
    while task.wait() do
        if _G.AutoFarm then
            pcall(function()
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(Vector2.new(1280, 672))
            end)
        end
    end
end)

task.spawn(function()
    while task.wait() do
        if _G.AutoFarm and _G.SelectedMob ~= "" then
            pcall(function()
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v.Name == _G.SelectedMob and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        repeat
                            if not _G.AutoFarm then break end
                            v.HumanoidRootPart.CanCollide = false
                            v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Distance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            task.wait()
                        until not v.Parent or v.Humanoid.Health <= 0 or not _G.AutoFarm
                    end
                end
            end)
        end
    end
end)

-- [[ BẢO MẬT CHUYÊN SÂU ]]
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" and (tostring(self) == "AdminIT" or tostring(self) == "ReportAbuse" or tostring(self):find("Detection")) then
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
    Title = "EyeSpyhub",
    Content = "Script đã sẵn sàng!",
    Duration = 5
})
