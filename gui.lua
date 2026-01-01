-- [[ CÀI ĐẶT HỆ THỐNG ]]
local uiName = "Secure_UI_" .. math.random(1000, 9999)

-- Hàm che tên: "abcdxzy" -> "abc****"
local function maskName(str)
    if #str <= 3 then return str end
    return string.sub(str, 1, 3) .. string.rep("*", #str - 3)
end

local player = game.Players.LocalPlayer
local maskedUser = maskName(player.Name)
local maskedDisplay = maskName(player.DisplayName)

-- [[ KHỞI TẠO GIAO DIỆN ]]
local screenGui = Instance.new("ScreenGui")
screenGui.Name = uiName
-- Chèn vào CoreGui để tránh bị quét bởi một số Script quản lý của game
local success, err = pcall(function()
    screenGui.Parent = game:GetService("CoreGui")
end)
if not success then screenGui.Parent = player:WaitForChild("PlayerGui") end

-- Khung chính
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 140)
mainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true -- Có thể cầm kéo
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Nút Tắt Script (X)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 25, 0, 25)
closeButton.Position = UDim2.new(1, -30, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 16
closeButton.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 5)
btnCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Hiển thị Tên (Đã che)
local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -40, 0, 40)
nameLabel.Position = UDim2.new(0, 12, 0, 5)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = "Name: " .. maskedDisplay .. " (@" .. maskedUser .. ")"
nameLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
nameLabel.TextSize = 14
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Font = Enum.Font.GothamSemibold
nameLabel.Parent = mainFrame

-- Ô ghi chú đơn cày
local noteBox = Instance.new("TextBox")
noteBox.Size = UDim2.new(1, -24, 0, 70)
noteBox.Position = UDim2.new(0, 12, 0, 55)
noteBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
noteBox.PlaceholderText = "Nhập thông tin đơn cày..."
noteBox.Text = ""
noteBox.TextColor3 = Color3.fromRGB(255, 255, 255)
noteBox.TextSize = 13
noteBox.TextWrapped = true
noteBox.TextYAlignment = Enum.TextYAlignment.Top
noteBox.ClearTextOnFocus = false
noteBox.Parent = mainFrame

local boxCorner = Instance.new("UICorner")
boxCorner.Parent = noteBox

-----------------------------------------------------------
-- ANTI-BAN & BYPASS (HOOKING)
-----------------------------------------------------------
local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldNamecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    -- Chặn các nỗ lực gửi báo cáo hoặc quét log từ game
    if method == "FireServer" and (tostring(self) == "ReportAbuse" or tostring(self):find("Detection") or tostring(self):find("Log")) then
        return nil
    end
    
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

print("Script Loaded Successfully!")
