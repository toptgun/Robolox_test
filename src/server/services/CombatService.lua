-- ServerScriptService/Services/CombatService.lua
-- 근접 전투 시스템: 히트 판정, 데미지, 중복 타격 방지

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local WeaponsConfig = require(ReplicatedStorage.Config.Weapons)

local CombatService = {}

-- player별 쿨다운 추적
local playerCooldowns = {}
local playerLastAttackId = {}

-- attackId 생성
local attackIdCounter = 0
local function generateAttackId()
	attackIdCounter = attackIdCounter + 1
	return tostring(attackIdCounter)
end

-- 쿨다운 체크 및 설정
local function setAttackCooldown(player: Player)
	playerCooldowns[player.UserId] = tick()
end

local function getCooldownRemaining(player: Player): number
	local lastAttack = playerCooldowns[player.UserId]
	if not lastAttack then
		return 0
	end
	-- 전투 전용 쿨다운 사용
	local cooldown = WeaponsConfig.Pickaxe.baseCombatCooldown
	local elapsed = tick() - lastAttack
	return math.max(0, cooldown - elapsed)
end

-- 근접 공격 실행
function CombatService.MeleeSwing(player: Player, attackId: string?): (boolean, string?, table?)
	-- 쿨다운 체크
	local cooldownRemaining = getCooldownRemaining(player)
	if cooldownRemaining > 0 then
		return false, "Cooldown"
	end

	-- attackId 유효성 체크
	if not attackId then
		attackId = generateAttackId()
	end

	-- 같은 attackId로 중복 요청 방지
	if playerLastAttackId[player.UserId] == attackId then
		return false, "DuplicateAttack"
	end
	playerLastAttackId[player.UserId] = attackId

	-- 캐릭터 확인
	local character = player.Character
	if not character then
		return false, "NoCharacter"
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoidRootPart or not humanoid then
		return false, "NoCharacter"
	end

	-- PickaxeLevel에 따른 데미지 계산
	local MiningService = require(script.Parent.MiningService)
	local pickaxeLevel = MiningService.GetPickaxeLevel(player)
	local config = WeaponsConfig.Pickaxe
	local damage = config.baseDamage * (config.scalePerLevel.damageMultiplier ^ pickaxeLevel)

	-- 히트 박스 설정 (캐릭터 전방)
	local range = config.range
	local characterCFrame = humanoidRootPart.CFrame
	local lookVector = characterCFrame.LookVector
	local boxSize = Vector3.new(4, 5, range) -- 가로, 세로, 범위
	local boxPosition = humanoidRootPart.Position + (lookVector * (range / 2))

	-- OverlapParams 설정 (공격자 제외)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	-- 히트 판정: CFrame에 방향 포함 (캐릭터가 바라보는 방향)
	local boxCFrame = CFrame.new(boxPosition, boxPosition + lookVector)
	local hitParts = workspace:GetPartBoundsInBox(
		boxCFrame,
		boxSize,
		overlapParams
	)

	-- 타격한 Humanoid 추적 (중복 타격 방지)
	local hitHumanoids = {}
	local hitCount = 0

	for _, part in hitParts do
		-- Model에서 Humanoid 찾기
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
			local targetHumanoid = model:FindFirstChildOfClass("Humanoid")
			if targetHumanoid and targetHumanoid.Health > 0 then
				-- 이미 타격한 Humanoid인지 체크
				if not hitHumanoids[targetHumanoid] then
					hitHumanoids[targetHumanoid] = true
					hitCount = hitCount + 1

					-- 데미지 적용
					targetHumanoid:TakeDamage(damage)

					-- VFX/SFX: 히트 이펙트 생성
					createHitEffect(part, damage)
				end
			end
		end
	end

	-- 쿨다운 설정
	setAttackCooldown(player)

	return true, nil, {
		attackId = attackId,
		damage = damage,
		hitCount = hitCount,
	}
end

-- 히트 이펙트 생성 (VFX/SFX)
local function createHitEffect(hitPart: BasePart, damage: number)
	-- 파티클 효과 생성
	local attachment = Instance.new("Attachment")
	attachment.Parent = hitPart

	-- 스파크 파티클
	local sparks = Instance.new("ParticleEmitter")
	sparks.Parent = attachment
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100))
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.3, 0.5)
	sparks.Rate = 50
	sparks.Speed = NumberRange.new(5, 10)
	sparks.SpreadAngle = Vector2.new(45, 45)
	sparks.EmissionDirection = Enum.NormalId.Top

	-- 파티클 재생
	sparks:Emit(20)

	-- 사운드 효과
	local sound = Instance.new("Sound")
	sound.Parent = hitPart
	sound.SoundId = "rbxassetid://131961136" -- 기본 히트 사운드
	sound.Volume = 0.5
	sound.PlayOnRemove = true
	sound:Play()

	-- 정리
	Debris:AddItem(attachment, 1)
	Debris:AddItem(sound, 2)

	-- 데미지 숫자 표시 (선택사항)
	local model = hitPart:FindFirstAncestorOfClass("Model")
	if model then
		local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local billboardGui = Instance.new("BillboardGui")
			billboardGui.Parent = humanoidRootPart
			billboardGui.Size = UDim2.new(0, 100, 0, 50)
			billboardGui.StudsOffset = Vector3.new(0, 2, 0)
			billboardGui.Adornee = humanoidRootPart

			local damageLabel = Instance.new("TextLabel")
			damageLabel.Parent = billboardGui
			damageLabel.Size = UDim2.new(1, 0, 1, 0)
			damageLabel.BackgroundTransparency = 1
			damageLabel.Text = tostring(math.floor(damage))
			damageLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			damageLabel.TextSize = 24
			damageLabel.Font = Enum.Font.GothamBold
			damageLabel.TextStrokeTransparency = 0.5
			damageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

			-- 애니메이션 (위로 올라가며 페이드아웃)
			local tweenService = game:GetService("TweenService")
			local tween = tweenService:Create(
				billboardGui,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					StudsOffset = Vector3.new(0, 4, 0),
				}
			)
			tween:Play()

			local fadeTween = tweenService:Create(
				damageLabel,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}
			)
			fadeTween:Play()

			Debris:AddItem(billboardGui, 1.5)
		end
	end
end

-- 마지막 attackId 클리어 (쿨다운 종료 후)
task.spawn(function()
	while true do
		task.wait(1)
		-- 쿨다운 종료 후 attackId 정리 (메모리 관리)
		local cooldown = WeaponsConfig.Pickaxe.baseCombatCooldown
		for userId, lastId in pairs(playerLastAttackId) do
			local lastAttack = playerCooldowns[userId]
			if lastAttack then
				local elapsed = tick() - lastAttack
				-- 쿨다운이 지난 경우 attackId 정리
				if elapsed > cooldown + 1 then -- 여유 시간 1초 추가
					playerLastAttackId[userId] = nil
				end
			else
				-- 쿨다운 정보가 없으면 attackId도 정리
				playerLastAttackId[userId] = nil
			end
		end
	end
end)

return CombatService
