-- StarterPack/Pickaxe/CombatHandler.lua
-- 근접 공격 입력 처리 (마우스 클릭 시 휘두르기)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatEvent = remotes:WaitForChild("CombatEvent")

-- 공격 상태
local isAttacking = false
local lastAttackId = nil

-- attackId 생성 (클라이언트)
local attackIdCounter = 0
local function generateAttackId()
	attackIdCounter = attackIdCounter + 1
	return tostring(player.UserId .. "_" .. attackIdCounter)
end

-- 근접 공격 실행
local function performMeleeSwing()
	if isAttacking then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	isAttacking = true
	local attackId = generateAttackId()
	lastAttackId = attackId

	-- 서버에 공격 요청
	CombatEvent:FireServer("MELEE_SWING", attackId)

	-- 애니메이션 플레이
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://6723907804" -- 기본 휘두르기 애니메이션
		local track = animator:LoadAnimation(animation)
		track:Play()
		track.Ended:Connect(function()
			isAttacking = false
		end)
	else
		-- Animator가 없으면 기본 쿨다운 후 해제
		task.wait(0.4)
		isAttacking = false
	end
end

-- 마우스 클릭 감지 (툴 장착 시)
local tool = script.Parent
tool.Equipped:Connect(function()
	-- 툴 장착 시 입력 연결
	local connection
	connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- 마우스 좌클릭
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			performMeleeSwing()
		end
	end)

	-- 툴 해제 시 연결 해제
	tool.Unequipped:Connect(function()
		if connection then
			connection:Disconnect()
		end
	end)
end)

print("[CombatHandler] Initialized")
