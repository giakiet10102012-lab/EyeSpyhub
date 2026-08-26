-- [[ EyeSpyhub | San Diego (Hardcore Fix Lag V3 + 6s Sell Cooldown + Launder Fix) ]]
local CG, P, RS, UIS, VU, L = game:GetService("CoreGui"), game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("VirtualUser"), game:GetService("Lighting")
local LP = P.LocalPlayer
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local P_Buy, W1, W2, W3, W4, W5_Sell, W_LaundE, P_Laund = CFrame.new(6803.02,17.59,23.03), CFrame.new(6872.252,17.219,30.226), CFrame.new(6868.94,17.219,107.597), CFrame.new(258.024,17.219,104.148), CFrame.new(258.357,17.239,-44.435), CFrame.new(208.642,17.406,-43.187), CFrame.new(6882.597,17.417,-40.537), CFrame.new(6809.746,17.442,-40.643)
local bv, bg
_G.AutoFarm, _G.NoClip = false, false

-- [HỆ THỐNG FIX LAG HARDCORE V3]
task.spawn(function()
    pcall(function()
        L.GlobalShadows = false
        L.FogEnd = 9e9
        L.Brightness = 0
        L.ClockTime = 12
        L.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        pcall(function() L.Technology = Enum.Technology.Compatibility end)

        for _, v in pairs(L:GetChildren()) do
            if not v:IsA("Sky") then
                v:Destroy()
            end
        end

        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
            pcall(function() Terrain:Clear() end)
        end

        local function ProcessCharacter(char)
            if not char then return end
            for _, obj in pairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Color = Color3.fromRGB(120, 120, 120)
                    obj.Reflectance = 0
                    obj.CastShadow = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("CharacterMesh") or obj:IsA("Accessory") or obj:IsA("Hat") then
                    obj:Destroy()
                end
            end
        end

        if LP.Character then ProcessCharacter(LP.Character) end
        LP.CharacterAdded:Connect(function(char)
            char:WaitForChild("HumanoidRootPart")
            task.wait(0.1)
            ProcessCharacter(char)
        end)

        local GREY_COLOR = Color3.fromRGB(120, 120, 120)
        local function StripObject(obj)
            for _, p in pairs(P:GetPlayers()) do
                if p.Character and obj:IsDescendantOf(p.Character) then
                    return
                end
            end

            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Color = GREY_COLOR
                obj.Reflectance = 0
                obj.CastShadow = false
                if obj:IsA("MeshPart") then
                    obj.TextureID = ""
                end
            elseif obj:IsA("SpecialMesh") then
                obj.TextureId = ""
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj:Destroy()
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") or obj:IsA("Light") or obj:IsA("Highlight") then
                obj:Destroy()
            end
        end

        for _, obj in pairs(workspace:GetDescendants()) do
            StripObject(obj)
        end

        workspace.DescendantAdded:Connect(function(obj)
            task.wait()
            StripObject(obj)
        end)
    end)
end)

-- Anti-AFK
LP.Idled:Connect(function() 
    VU:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame) 
    task.wait(1) 
    VU:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame) 
end)

-- [HỆ THỐNG NOCLIP]
local noClipConnection
local function ToggleNoClip(state)
    _G.NoClip = state
    if noClipConnection then 
        noClipConnection:Disconnect() 
        noClipConnection = nil 
    end
    
    if _G.NoClip then
        noClipConnection = RS.Stepped:Connect(function()
            if _G.NoClip and LP.Character then
                for _, part in ipairs(LP.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if LP.Character then
            for _, part in ipairs(LP.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
                    part.CanCollide = false
                elseif part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function GetChar() 
    local c = LP.Character 
    return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid") 
end

local function DisableFly() 
    if bg then bg:Destroy() bg = nil end 
    if bv then bv:Destroy() bv = nil end 
    local _,_,h = GetChar() if h then h.PlatformStand = false end 
end

local function EnableFly()
    local _,r,h = GetChar() if not r or not h then return end
    if not bg or bg.Parent ~= r then bg = Instance.new("BodyGyro", r) bg.P = 10000 bg.MaxTorque = Vector3.new(9e9,9e9,9e9) end
    if not bv or bv.Parent ~= r then bv = Instance.new("BodyVelocity", r) bv.MaxForce = Vector3.new(9e9,9e9,9e9) end
    h.PlatformStand = true
end

LP.CharacterAdded:Connect(function() 
    DisableFly() 
    if _G.NoClip then ToggleNoClip(true) end
    task.wait(1) 
end)

local function FlyTo(targetCF, speed)
    speed = speed or 250 local _,r,h = GetChar() if not r or not h or h.Health <= 0 then return end EnableFly()
    while _G.AutoFarm do
        local _,cr,ch = GetChar() if not cr or not ch or ch.Health <= 0 then break end
        local dist = (targetCF.Position - cr.Position).Magnitude
        if dist <= 2.5 then break end
        
        bv.Velocity = (targetCF.Position - cr.Position).Unit * speed
        local lookPos = Vector3.new(targetCF.X, cr.Position.Y, targetCF.Z)
        if (lookPos - cr.Position).Magnitude > 0.5 then
            bg.CFrame = CFrame.lookAt(cr.Position, lookPos)
        end
        RS.Heartbeat:Wait()
    end
    if bv then bv.Velocity = Vector3.zero end
    if r and r.Parent then r.CFrame = targetCF end
    task.wait(0.05)
end

local function GetClosestTarget(name)
    local _,r = GetChar() if not r then return workspace:FindFirstChild(name, true) end
    local cl, minD = nil, math.huge
    for _,d in pairs(workspace:GetDescendants()) do
        if d.Name == name and d:FindFirstChildWhichIsA("ProximityPrompt", true) then
            local p = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
            if p and (r.Position - p.Position).Magnitude < minD then 
                minD = (r.Position - p.Position).Magnitude 
                cl = d 
            end
        end
    end
    return cl or workspace:FindFirstChild(name, true)
end

local function FlyToTargetSafe(obj)
    if not obj then return end 
    local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    local pPart = pr and (pr.Parent:IsA("BasePart") and pr.Parent or pr.Parent:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true))
    local _,r = GetChar() if not pPart or not r then return end
    FlyTo(CFrame.new(pPart.Position + Vector3.new(0, 1, 1), pPart.Position), 200)
end

local function FirePrompt(obj, count, hold)
    if not obj then return end 
    local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pr then 
        local _,_,h = GetChar() 
        for i = 1, count or 1 do 
            if not _G.AutoFarm or (h and h.Health <= 0) then break end 
            fireproximityprompt(pr) 
            task.wait(hold or 0.3) 
        end 
    end
end

local function GetItemCount(name)
    local c = 0 
    if LP:FindFirstChild("Backpack") then 
        for _,i in pairs(LP.Backpack:GetChildren()) do if i.Name == name then c = c + 1 end end 
    end
    if LP.Character and LP.Character:FindFirstChild(name) then c = c + 1 end 
    return c
end

-- [GIAO DIỆN EYESPYHUB GUI]
if CG:FindFirstChild("EyeSpyhub_Gui") then CG.EyeSpyhub_Gui:Destroy() end
local Gui = Instance.new("ScreenGui", CG) Gui.Name = "EyeSpyhub_Gui"
local Main = Instance.new("Frame", Gui) Main.Size, Main.Position, Main.BackgroundColor3, Main.Active, Main.Draggable = UDim2.new(0,180,0,120), UDim2.new(0.5,-90,0.5,-60), Color3.fromRGB(25,25,25), true, true
local Title = Instance.new("TextLabel", Main) Title.Size, Title.Text, Title.TextColor3, Title.BackgroundColor3 = UDim2.new(1,0,0,25), "EyeSpyhub | San Diego", Color3.new(1,1,1), Color3.fromRGB(45,45,45)

local function CreateBtn(pos, text, fn)
    local btn = Instance.new("TextButton", Main) btn.Size, btn.Position, btn.Text, btn.BackgroundColor3, btn.TextColor3 = UDim2.new(0.85,0,0,30), pos, text..": OFF", Color3.fromRGB(180,40,40), Color3.new(1,1,1)
    btn.MouseButton1Click:Connect(function()
        local state = fn() 
        btn.Text = text..(state and ": ON" or ": OFF") 
        btn.BackgroundColor3 = state and Color3.fromRGB(40,180,40) or Color3.fromRGB(180,40,40)
    end)
end

CreateBtn(UDim2.new(0.075,0,0.3,0), "Auto Farm", function() 
    _G.AutoFarm = not _G.AutoFarm 
    if not _G.AutoFarm then DisableFly() end 
    return _G.AutoFarm 
end)

CreateBtn(UDim2.new(0.075,0,0.62,0), "NoClip", function() 
    ToggleNoClip(not _G.NoClip) 
    return _G.NoClip 
end)

-- [VÒNG LẶP AUTO FARM]
task.spawn(function()
    while task.wait(0.3) do
        if _G.AutoFarm then
            pcall(function()
                local _,r,h = GetChar() if not r or not h or h.Health <= 0 then return end
                
                -- 1. Mua tranh
                if GetItemCount("Mona Lisa Painting") < 5 then
                    FlyTo(P_Buy)
                    while _G.AutoFarm and GetItemCount("Mona Lisa Painting") < 5 do
                        local _,cr,ch = GetChar() if not cr or not ch or ch.Health <= 0 then break end
                        local item = GetClosestTarget("Mona Lisa Painting") 
                        if item then 
                            FlyToTargetSafe(item) 
                            FirePrompt(item, 1, 0.3)
                        else
                            FlyTo(P_Buy)
                        end
                        task.wait(0.2)
                    end
                end
                
                if not _G.AutoFarm then return end
                
                -- 2. Bay đến khu vực bán (Seller4)
                FlyTo(W1); FlyTo(W2); FlyTo(W3); FlyTo(W4); FlyTo(W5_Sell)
                local npc = GetClosestTarget("Seller4") 
                if npc then FlyToTargetSafe(npc) end 
                
                -- Cooldown Bán 6s
                task.wait(6) 
                
                FirePrompt(npc, 1, 1.0) 
                task.wait(0.5)
                
                if not _G.AutoFarm then return end
                
                -- 3. Rửa tiền & Bay về
                FlyTo(W4); FlyTo(W3); FlyTo(W2); FlyTo(W1); FlyTo(W_LaundE); FlyTo(P_Laund)
                local launder = GetClosestTarget("PromptPart") 
                if launder then FlyToTargetSafe(launder) end 
                
                -- Bấm nút rửa tiền 2 lần, mỗi lần cách nhau 0.5 giây
                FirePrompt(launder, 2, 0.5) 
                task.wait(0.3)
                
                if not _G.AutoFarm then return end
                FlyTo(W_LaundE); FlyTo(W1)
            end)
        end
    end
end)
