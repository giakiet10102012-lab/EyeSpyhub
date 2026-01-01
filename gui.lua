-- Chống phát hiện cơ bản bằng cách ngẫu nhiên hóa tên UI
local uiName = "System_" .. math.random(1000, 9999)

-- Hàm che tên: "Gemini" -> "Ge***"
local function maskName(str)
    if #str <= 3 then return str end
    return string.sub(str, 1, 3) .. string.rep("*", #str - 3)
end

local playerName = game.Players.LocalPlayer.Name
local displayNm = game.Players.LocalPlayer.DisplayName
local maskedUser = maskName(playerName)
local maskedDisplay = maskName(displayNm)

-- Khởi tạo GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = uiName
-- Thử chèn vào nơi khó bị quét hơn
local success, err = pcall(function()
    screenGui.Parent = game:GetService("CoreGui")
end)
if not success then screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui") end

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 130)
mainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true 
mainFrame.Parent = screenGui

-- Bo góc cho đẹp và hiện đại
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Hiển thị tên đã che
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 40)
infoLabel.Position = UDim2.new(0, 10, 0, 5)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Status: [PROTECTED]\nUser: " .. maskedDisplay .. " (@" .. maskedUser .. ")"
infoLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
infoLabel.TextSize = 14
infoLabel.TextWrapped = true
infoLabel.Parent = mainFrame

-- Ô nhập đơn cày
local noteBox = Instance.new("TextBox")
noteBox.Size = UDim2.new(1, -20, 0, 60)
noteBox.Position = UDim2.new(0, 10, 0, 55)
noteBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
noteBox.PlaceholderText = "Ghi đơn cày tại đây..."
noteBox.Text = ""
noteBox.TextColor3 = Color3.fromRGB(255, 255, 255)
noteBox.TextSize = 12
noteBox.TextWrapped = true
noteBox.Parent = mainFrame

local boxCorner = Instance.new("UICorner")
boxCorner.Parent = noteBox

-----------------------------------------------------------
-- ANTI-BAN CƠ BẢN (CLIENT SIDE)
-----------------------------------------------------------
local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldNamecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    -- Ngăn chặn gửi dữ liệu báo cáo về Server (chặn các RemoteEvent nghi vấn)
    if method == "FireServer" and (tostring(self) == "ReportAbuse" or tostring(self):find("Detection")) then
        return nil
    end
    
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

print("UI Loaded with Anti-Detection!")
