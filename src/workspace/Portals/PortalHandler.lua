-- Workspace/Portals/PortalHandler.lua (LocalScript)
-- 지역 포털: ProximityPrompt로 진입 시도 (클라이언트)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ZoneEvent = remotes:WaitForChild("ZoneEvent")
local ZonesConfig = require(ReplicatedStorage.Config.Zones)

-- Portal 설정 (Portal Part의 Attribute에서 읽기)
local portal = script.Parent
local zoneName = portal:GetAttribute("ZoneName") or "StarterZone"

local player = Players.LocalPlayer

-- ProximityPrompt 찾기 (서버에서 생성되어야 함)
local prompt = portal:WaitForChildOfClass("ProximityPrompt", 5)
if not prompt then
	-- ProximityPrompt가 없으면 생성 (클라이언트에서도 가능)
	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ObjectText = "포털"
	prompt.ActionText = "입장하려면 클릭"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	prompt.Parent = portal
end

-- 진입 시도 처리
prompt.Triggered:Connect(function(triggeredPlayer)
	if triggeredPlayer == player then
		-- 서버에 진입 요청
		ZoneEvent:FireServer("TRY_ENTER", zoneName)
	end
end)

-- 결과 처리
ZoneEvent.OnClientEvent:Connect(function(success, reason, result)
		if not success then
			-- 실패 메시지 표시
			local playerGui = player:WaitForChild("PlayerGui")

			local messageGui = Instance.new("ScreenGui")
			messageGui.Name = "ZoneMessage"
			messageGui.Parent = playerGui

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0, 400, 0, 100)
			frame.Position = UDim2.new(0.5, -200, 0.5, -50)
			frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			frame.BorderSizePixel = 0
			frame.Parent = messageGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = frame

			local titleLabel = Instance.new("TextLabel")
			titleLabel.Size = UDim2.new(1, 0, 0, 30)
			titleLabel.Position = UDim2.new(0, 0, 0, 10)
			titleLabel.BackgroundTransparency = 1
			titleLabel.Text = "입장 불가"
			titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			titleLabel.TextSize = 24
			titleLabel.Font = Enum.Font.GothamBold
			titleLabel.Parent = frame

			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(1, -40, 0, 50)
			descLabel.Position = UDim2.new(0, 20, 0, 40)
			descLabel.BackgroundTransparency = 1
			descLabel.Text = result.rewardDescription or "조건 불충족"
			descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			descLabel.TextSize = 16
			descLabel.Font = Enum.Font.Gotham
			descLabel.TextWrapped = true
			descLabel.Parent = frame

			-- 3초 후 제거
			game:GetService("Debris"):AddItem(messageGui, 3)
	elseif result and result.newlyUnlocked then
		-- 새로운 지역 해금 메시지
		local zoneConfig = ZonesConfig[zoneName]
		if not zoneConfig then
			return
		end

		local playerGui = player:WaitForChild("PlayerGui")

		local messageGui = Instance.new("ScreenGui")
		messageGui.Name = "UnlockMessage"
		messageGui.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0, 400, 0, 120)
		frame.Position = UDim2.new(0.5, -200, 0.4, -60)
		frame.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
		frame.BorderSizePixel = 0
		frame.Parent = messageGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, 0, 0, 30)
		titleLabel.Position = UDim2.new(0, 0, 0, 10)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = "새로운 지역 해금!"
		titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		titleLabel.TextSize = 24
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.Parent = frame

		local zoneLabel = Instance.new("TextLabel")
		zoneLabel.Size = UDim2.new(1, 0, 0, 30)
		zoneLabel.Position = UDim2.new(0, 0, 0, 40)
		zoneLabel.BackgroundTransparency = 1
		zoneLabel.Text = zoneConfig.name
		zoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		zoneLabel.TextSize = 20
		zoneLabel.Font = Enum.Font.Gotham
		zoneLabel.Parent = frame

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -40, 0, 40)
		descLabel.Position = UDim2.new(0, 20, 0, 70)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = zoneConfig.description
		descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		descLabel.TextSize = 14
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.Parent = frame

		Debris:AddItem(messageGui, 4)
	end
end)

print("[PortalHandler] Initialized for zone: " .. zoneName)
