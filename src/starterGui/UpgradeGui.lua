-- StarterGui/UpgradeGui/LocalScript
-- 업그레이드 UI 처리

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpgradeEvent = remotes:WaitForChild("UpgradeEvent")
local UpgradesConfig = require(ReplicatedStorage.Config.Upgrades)

-- GUI 생성
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UpgradeGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 메인 프레임
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 200)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- 코너 둥글게
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

-- 제목
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "업그레이드"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 24
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Gold 표시
local goldLabel = Instance.new("TextLabel")
goldLabel.Name = "GoldLabel"
goldLabel.Size = UDim2.new(1, 0, 0, 30)
goldLabel.Position = UDim2.new(0, 0, 0, 50)
goldLabel.BackgroundTransparency = 1
goldLabel.Text = "Gold: 0"
goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
goldLabel.TextSize = 18
goldLabel.Font = Enum.Font.Gotham
goldLabel.Parent = mainFrame

-- Pickaxe 업그레이드 버튼
local pickaxeButton = Instance.new("TextButton")
pickaxeButton.Name = "PickaxeButton"
pickaxeButton.Size = UDim2.new(0, 260, 0, 50)
pickaxeButton.Position = UDim2.new(0.5, -130, 0, 90)
pickaxeButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
pickaxeButton.BorderSizePixel = 0
pickaxeButton.Text = "Pickaxe Lv.1 → 2 (50 G)"
pickaxeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
pickaxeButton.TextSize = 16
pickaxeButton.Font = Enum.Font.Gotham
pickaxeButton.Parent = mainFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = pickaxeButton

-- 메시지 라벨
local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "MessageLabel"
messageLabel.Size = UDim2.new(1, 0, 0, 30)
messageLabel.Position = UDim2.new(0, 0, 1, -30)
messageLabel.BackgroundTransparency = 1
messageLabel.Text = ""
messageLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
messageLabel.TextSize = 14
messageLabel.Font = Enum.Font.Gotham
messageLabel.Parent = mainFrame

-- 현재 레벨 저장
local currentLevels = {
	PickaxeLevel = 0,
}

-- UI 업데이트 함수
local function updateUI()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("Gold")
		if gold then
			goldLabel.Text = string.format("Gold: %d", gold.Value)
		end
	end

	-- Pickaxe 버튼 업데이트
	local pickaxeLevel = currentLevels.PickaxeLevel
	local upgradeConfig = UpgradesConfig.PickaxeLevel

	if pickaxeLevel >= upgradeConfig.maxLevel then
		pickaxeButton.Text = string.format("Pickaxe Lv.%d (MAX)", pickaxeLevel)
		pickaxeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		pickaxeButton.Active = false
	else
		local cost = upgradeConfig:getCost(pickaxeLevel)
		local effectDesc = upgradeConfig:getEffectDescription(pickaxeLevel + 1)
		pickaxeButton.Text = string.format("Pickaxe Lv.%d → %d (%d G)\n%s",
			pickaxeLevel, pickaxeLevel + 1, cost, effectDesc)

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local gold = leaderstats:FindFirstChild("Gold")
			if gold and gold.Value >= cost then
				pickaxeButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
			else
				pickaxeButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
			end
		end
		pickaxeButton.Active = true
	end
end

-- 업그레이드 버튼 클릭
pickaxeButton.MouseButton1Click:Connect(function()
	messageLabel.Text = "구매 중..."
	messageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

	-- RemoteEvent는 FireServer 사용 (InvokeServer는 RemoteFunction용)
	UpgradeEvent:FireServer("PickaxeLevel")
end)

-- UpgradeEvent 응답 처리
UpgradeEvent.OnClientEvent:Connect(function(success, reason, result)
	if success then
		currentLevels.PickaxeLevel = result.newLevel
		messageLabel.Text = string.format("업그레이드 완료! Lv.%d → %d",
			result.newLevel - 1, result.newLevel)
		messageLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

		task.delay(2, function()
			messageLabel.Text = ""
		end)
	else
		if reason == "NotEnoughGold" then
			messageLabel.Text = string.format("골드 부족! (필요: %d G)", result.needed)
		elseif reason == "MaxLevel" then
			messageLabel.Text = "최대 레벨 도달!"
		else
			messageLabel.Text = "구매 실패: " .. (reason or "알 수 없는 오류")
		end
		messageLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end

	updateUI()
end)

-- 주기적 업데이트 (골드 변경 감지)
game:GetService("RunService").Heartbeat:Connect(function()
	updateUI()
end)

-- 초기 업데이트
updateUI()

print("[UpgradeGui] Initialized")
