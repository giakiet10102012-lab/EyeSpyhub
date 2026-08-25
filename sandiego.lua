-- [[ EyeSpyhub | San Diego (Compact Edition) ]]
local CG, P, RS, UIS, VU = game:GetService("CoreGui"), game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("VirtualUser")
local LP = P.LocalPlayer
local P_Buy, W1, W2, W3, W4, W5_Sell, W_LaundE, P_Laund = CFrame.new(6803.02,17.59,23.03), CFrame.new(6872.252,17.219,30.226), CFrame.new(6868.94,17.219,107.597), CFrame.new(258.024,17.219,104.148), CFrame.new(258.357,17.239,-44.435), CFrame.new(208.642,17.406,-43.187), CFrame.new(6882.597,17.417,-40.537), CFrame.new(6809.746,17.442,-40.643)
local bv, bg
_G.AutoFarm, _G.NoClip = false, false

LP.Idled:Connect(function() VU:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame) task.wait(1) VU:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame) end)
RS.Stepped:Connect(function() if _G.NoClip and LP.Character then for _,p in pairs(LP.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end)

local function GetChar() local c = LP.Character return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid") end
local function DisableFly() if bg then bg:Destroy() bg=nil end if bv then bv:Destroy() bv=nil end local _,_,h = GetChar() if h then h.PlatformStand = false end end
local function EnableFly()
    local _,r,h = GetChar() if not r or not h then return end
    if not bg or bg.Parent~=r then bg = Instance.new("BodyGyro", r) bg.P, bg.MaxTorque = 9e4, Vector3.new(9e9,9e9,9e9) end
    if not bv or bv.Parent~=r then bv = Instance.new("BodyVelocity", r) bv.MaxForce = Vector3.new(9e9,9e9,9e9) end
    h.PlatformStand = true
end

LP.CharacterAdded:Connect(function() DisableFly() task.wait(1) end)

local function FlyTo(targetCF, speed)
    speed = speed or 300 local _,r,h = GetChar() if not r or not h or h.Health<=0 then return end EnableFly()
    while _G.AutoFarm do
        local _,cr,ch = GetChar() if not cr or not ch or ch.Health<=0 or (targetCF.Position-cr.Position).Magnitude<=2 then break end
        bv.Velocity = (targetCF.Position-cr.Position).Unit*speed bg.CFrame = CFrame.lookAt(cr.Position, Vector3.new(targetCF.X, cr.Position.Y, targetCF.Z))
        RS.Heartbeat:Wait()
    end
    if bv then bv.Velocity = Vector3.zero end if bg then bg.CFrame = targetCF end if r and r.Parent then r.CFrame = targetCF end task.wait(0.1)
end

local function GetClosestTarget(name)
    local _,r = GetChar() if not r then return workspace:FindFirstChild(name, true) end
    local cl, minD = nil, math.huge
    for _,d in pairs(workspace:GetDescendants()) do
        if d.Name == name and d:FindFirstChildWhichIsA("ProximityPrompt", true) then
            local p = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
            if p and (r.Position-p.Position).Magnitude < minD then minD = (r.Position-p.Position).Magnitude cl = d end
        end
    end
    return cl or workspace:FindFirstChild(name, true)
end

local function FlyToTargetSafe(obj)
    if not obj then return end local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    local pPart = pr and (pr.Parent:IsA("BasePart") and pr.Parent or pr.Parent:FindFirstChildWhichIsA("BasePart", true))
    local _,r = GetChar() if not pPart or not r then return end
    local dir = (r.Position - pPart.Position) dir = dir.Magnitude>0.1 and dir.Unit or Vector3.new(0,0,1)
    FlyTo(CFrame.new(pPart.Position + (dir*2), pPart.Position), 200)
end

local function FirePrompt(obj, count, hold)
    if not obj then return end local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pr then local _,_,h = GetChar() for i=1, count or 1 do if not _G.AutoFarm or (h and h.Health<=0) then break end fireproximityprompt(pr) task.wait(hold or 0.35) end end
end

local function GetItemCount(name)
    local c = 0 if LP:FindFirstChild("Backpack") then for _,i in pairs(LP.Backpack:GetChildren()) do if i.Name == name then c = c + 1 end end end
    if LP.Character and LP.Character:FindFirstChild(name) then c = c + 1 end return c
end

if CG:FindFirstChild("EyeSpyhub_Gui") then CG.EyeSpyhub_Gui:Destroy() end
local Gui = Instance.new("ScreenGui", CG) Gui.Name = "EyeSpyhub_Gui"
local Main = Instance.new("Frame", Gui) Main.Size, Main.Position, Main.BackgroundColor3, Main.Active, Main.Draggable = UDim2.new(0,180,0,120), UDim2.new(0.5,-90,0.5,-60), Color3.fromRGB(25,25,25), true, true
local Title = Instance.new("TextLabel", Main) Title.Size, Title.Text, Title.TextColor3, Title.BackgroundColor3 = UDim2.new(1,0,0,25), "EyeSpyhub | San Diego", Color3.new(1,1,1), Color3.fromRGB(45,45,45)

local function CreateBtn(pos, text, fn)
    local btn = Instance.new("TextButton", Main) btn.Size, btn.Position, btn.Text, btn.BackgroundColor3, btn.TextColor3 = UDim2.new(0.85,0,0,30), pos, text..": OFF", Color3.fromRGB(180,40,40), Color3.new(1,1,1)
    btn.MouseButton1Click:Connect(function()
        local state = fn() btn.Text = text..(state and ": ON" or ": OFF") btn.BackgroundColor3 = state and Color3.fromRGB(40,180,40) or Color3.fromRGB(180,40,40)
    end)
end

CreateBtn(UDim2.new(0.075,0,0.3,0), "Auto Farm", function() _G.AutoFarm = not _G.AutoFarm if not _G.AutoFarm then DisableFly() end return _G.AutoFarm end)
CreateBtn(UDim2.new(0.075,0,0.62,0), "NoClip", function() _G.NoClip = not _G.NoClip return _G.NoClip end)

task.spawn(function()
    while task.wait(0.5) do
        if _G.AutoFarm then
            pcall(function()
                local _,r,h = GetChar() if not r or not h or h.Health<=0 then return end
                if GetItemCount("Mona Lisa Painting") < 5 then
                    FlyTo(P_Buy)
                    while _G.AutoFarm and GetItemCount("Mona Lisa Painting") < 5 do
                        local _,cr,ch = GetChar() if not cr or not ch or ch.Health<=0 then break end
                        local item = GetClosestTarget("Mona Lisa Painting") if item then FlyToTargetSafe(item) end FirePrompt(item, 1, 0.35) task.wait(0.1)
                    end
                end
                if not _G.AutoFarm then return end
                FlyTo(W1); FlyTo(W2); FlyTo(W3); FlyTo(W4); FlyTo(W5_Sell)
                local npc = GetClosestTarget("Seller4") if npc then FlyToTargetSafe(npc) end task.wait(6) FirePrompt(npc, 1, 1.2) task.wait(0.3)
                if not _G.AutoFarm then return end
                FlyTo(W4); FlyTo(W3); FlyTo(W2); FlyTo(W1); FlyTo(W_LaundE); FlyTo(P_Laund)
                local launder = GetClosestTarget("PromptPart") if launder then FlyToTargetSafe(launder) end FirePrompt(launder, 1, 1.2) task.wait(0.3)
                if not _G.AutoFarm then return end
                FlyTo(W_LaundE); FlyTo(W1)
            end)
        end
    end
end)
