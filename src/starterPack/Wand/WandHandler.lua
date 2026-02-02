-- StarterPack/Wand/WandHandler.lua
-- Wand 차징 및 발사 처리

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatEvent = remotes:WaitForChild("CombatEvent")

local WeaponsConfig = require(ReplicatedStorage.Config.Weapons)

-- 차징 상태
local isCharging = false
local chargeStartTime = 0
local maxChargeTime = WeaponsConfig.Wand.baseChargeTime

-- attackId 생성
local attackIdCounter = 0
local function generateAttackId()
	attackIdCounter = attackIdCounter + 1
	return tostring(player.UserId .. "_wand_" .. attackIdCounter)
end

-- 현재 차징 진행도 계산 (0~1)
local function getChargeAlpha()
	if not isCharging then
		return 0
	end
	local elapsed = tick() - chargeStartTime
	return math.clamp(elapsed / maxChargeTime, 0, 1)
end

-- 발사 실행
local function fireChargeShot()
	if not isCharging then
		return
	end

	isCharging = false

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	-- 차징 진행도
	local chargeAlpha = getChargeAlpha()

	-- 발사 방향 (카메라 방향)
	local camera = workspace.CurrentCamera
	local direction = camera.CFrame.LookVector

	-- 발사 위치 (Head 위치)
	local origin = head.Position

	-- attackId 생성
	local attackId = generateAttackId()

	-- 서버에 발사 요청
	CombatEvent:FireServer("RANGED_CHARGE_SHOT", origin, direction, chargeAlpha, attackId)

	-- 애니메이션
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://7828414988" -- 마법 시전 애니메이션
		local track = animator:LoadAnimation(animation)
		track:Play()
	end
end

-- Tool 이벤트
local tool = script.Parent

-- Activated: 차징 시작
tool.Activated:Connect(function()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if not isCharging then
		isCharging = true
		chargeStartTime = tick()
	end
end)

-- Deactivated: 발사
tool.Deactivated:Connect(function()
	if isCharging then
		fireChargeShot()
	end
end)

-- 차징 시각적 피드백 (GUI)
local playerGui = player:WaitForChild("PlayerGui")

-- 차징 바 GUI 생성
local function createChargeBar()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WandChargeGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "ChargeBarFrame"
	frame.Size = UDim2.new(0, 200, 0, 20)
	frame.Position = UDim2.new(0.5, -100, 0.6, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local bar = Instance.new("Frame")
	bar.Name = "ChargeBar"
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	bar.BorderSizePixel = 0
	bar.Parent = frame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = bar

	return screenGui, frame, bar
end

local chargeGui, chargeFrame, chargeBar = createChargeBar()

-- 차징 업데이트
RunService.Heartbeat:Connect(function()
	if isCharging then
		chargeFrame.Visible = true
		local alpha = getChargeAlpha()
		chargeBar.Size = UDim2.new(alpha, 0, 1, 0)

		-- 색상 변화 (충전 정도에 따라)
		local color = Color3.fromRGB(
			100 + alpha * 155,
			150 - alpha * 50,
			255 - alpha * 100
		)
		chargeBar.BackgroundColor3 = color
	else
		chargeFrame.Visible = false
	end
end)

print("[WandHandler] Initialized")
