-- ServerScriptService/Services/ProjectileService.lua
-- 투사체 시뮬레이션: raycast 기반 서버 권한 판정

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local WeaponsConfig = require(ReplicatedStorage.Config.Weapons)

local ProjectileService = {}

-- 활성 투사체 추적
local activeProjectiles = {}

-- 플레이어별 쿨다운 추적
local playerCooldowns = {}

-- 쿨다운 체크
local function getCooldownRemaining(player: Player): number
	local lastFire = playerCooldowns[player.UserId]
	if not lastFire then
		return 0
	end
	local cooldown = WeaponsConfig.Wand.baseCooldown
	local elapsed = tick() - lastFire
	return math.max(0, cooldown - elapsed)
end

local function setCooldown(player: Player)
	playerCooldowns[player.UserId] = tick()
end

-- 투사체 생성
function ProjectileService.FireProjectile(player: Player, origin: Vector3, direction: Vector3, chargeAlpha: number, attackId: string): (boolean, string?, table?)
	-- 쿨다운 체크
	local cooldownRemaining = getCooldownRemaining(player)
	if cooldownRemaining > 0 then
		return false, "Cooldown", cooldownRemaining
	end

	-- 서버 검증: 유효성 체크
	local character = player.Character
	if not character then
		return false, "NoCharacter"
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not humanoidRootPart or not head then
		return false, "NoCharacter"
	end

	-- origin 유효성 체크 (플레이어 근처여부)
	local maxOriginDist = 10
	if (origin - head.Position).Magnitude > maxOriginDist then
		return false, "InvalidOrigin"
	end

	-- direction 정규화
	if typeof(direction) ~= "Vector3" then
		return false, "InvalidDirection"
	end
	direction = direction.Unit

	-- FOV 체크 (플레이어가 바라보는 방향과 일치하는지)
	local lookVector = humanoidRootPart.CFrame.LookVector
	local dotProduct = lookVector:Dot(direction)
	local maxFov = math.cos(math.rad(90)) -- 90도 FOV

	if dotProduct < maxFov then
		return false, "InvalidAimDirection"
	end

	-- chargeAlpha 클램프
	chargeAlpha = math.clamp(chargeAlpha, 0, 1)

	-- Wand Config
	local wandConfig = WeaponsConfig.Wand
	local ProgressionService = require(script.Parent.ProgressionService)
	local wandLevel = ProgressionService.GetLevel(player, "WandLevel")

	-- 레벨에 따른 충전시간 감소 반영
	local chargeTimeReduction = 1 - (wandConfig.scalePerLevel.chargeTimeReduction * wandLevel)
	local effectiveChargeAlpha = math.min(1, chargeAlpha / chargeTimeReduction)

	-- 차징에 따른 속도/데미지 계산
	local speedMultiplier = wandConfig.chargeScaling.minSpeedMultiplier +
		(wandConfig.chargeScaling.maxSpeedMultiplier - wandConfig.chargeScaling.minSpeedMultiplier) * effectiveChargeAlpha

	local damageMultiplier = wandConfig.chargeScaling.minDamageMultiplier +
		(wandConfig.chargeScaling.maxDamageMultiplier - wandConfig.chargeScaling.minDamageMultiplier) * effectiveChargeAlpha

	-- 레벨 보너스
	local levelDamageMultiplier = wandConfig.scalePerLevel.damageMultiplier ^ wandLevel

	local speed = wandConfig.baseProjectileSpeed * speedMultiplier
	local damage = wandConfig.baseDamage * damageMultiplier * levelDamageMultiplier

	-- 투사체 데이터
	local projectile = {
		player = player,
		attackId = attackId,
		position = origin,
		direction = direction,
		speed = speed,
		damage = damage,
		maxRange = wandConfig.maxRange,
		traveled = 0,
		alive = true,
	}

	-- 시뮬레이션 시작
	table.insert(activeProjectiles, projectile)

	-- 쿨다운 설정
	setCooldown(player)

	return true, nil, {
		attackId = attackId,
		damage = damage,
		speed = speed,
		chargeAlpha = chargeAlpha,
	}
end

-- 투사체 시뮬레이션 (Heartbeat)
local RunService = game:GetService("RunService")

local function simulateProjectiles()
	local dt = 1 / 60 -- 고정 delta time

	for i = #activeProjectiles, 1, -1 do
		local proj = activeProjectiles[i]

		if not proj.alive then
			table.remove(activeProjectiles, i)
			continue
		end

		-- 현재 위치 저장 (raycast 시작점)
		local currentPos = proj.position

		-- 다음 위치 계산
		local nextPos = currentPos + (proj.direction * proj.speed * dt)
		local distanceMoved = (nextPos - currentPos).Magnitude
		proj.traveled = proj.traveled + distanceMoved

		-- 최대 사거리 체크
		if proj.traveled >= proj.maxRange then
			proj.alive = false
			table.remove(activeProjectiles, i)
			continue
		end

		-- Raycast 히트 판정 (현재 위치에서 다음 위치로)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { proj.player.Character }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local rayResult = workspace:Raycast(currentPos, proj.direction * distanceMoved, raycastParams)

		-- 위치 업데이트 (히트하지 않은 경우에만)
		if not rayResult then
			proj.position = nextPos
		end

		if rayResult then
			-- 히트 처리
			local hitPart = rayResult.Instance
			local model = hitPart:FindFirstAncestorOfClass("Model")

			if model then
				local humanoid = model:FindFirstChildOfClass("Humanoid")

				if humanoid and humanoid.Health > 0 then
					-- 데미지 적용
					humanoid:TakeDamage(proj.damage)

					-- VFX/SFX: 히트 이펙트 생성
					createHitEffect(hitPart, proj.damage)
				end
			end

			proj.alive = false
			table.remove(activeProjectiles, i)
		end
	end
end

-- 히트 이펙트 생성 (VFX/SFX) - CombatService와 동일한 로직
local TweenService = game:GetService("TweenService")

local function createHitEffect(hitPart: BasePart, damage: number)
	-- 파티클 효과 생성
	local attachment = Instance.new("Attachment")
	attachment.Parent = hitPart

	-- 마법 히트 파티클 (투사체용)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Parent = attachment
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(150, 150, 255))
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.4, 0.6)
	sparks.Rate = 60
	sparks.Speed = NumberRange.new(8, 12)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.EmissionDirection = Enum.NormalId.Top

	-- 파티클 재생
	sparks:Emit(30)

	-- 사운드 효과
	local sound = Instance.new("Sound")
	sound.Parent = hitPart
	sound.SoundId = "rbxassetid://131961136" -- 기본 히트 사운드
	sound.Volume = 0.6
	sound.PlayOnRemove = true
	sound:Play()

	-- 정리
	Debris:AddItem(attachment, 1.5)
	Debris:AddItem(sound, 2)

	-- 데미지 숫자 표시
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
			damageLabel.TextColor3 = Color3.fromRGB(150, 150, 255) -- 마법 색상
			damageLabel.TextSize = 24
			damageLabel.Font = Enum.Font.GothamBold
			damageLabel.TextStrokeTransparency = 0.5
			damageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

			-- 애니메이션 (위로 올라가며 페이드아웃)
			local tween = TweenService:Create(
				billboardGui,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					StudsOffset = Vector3.new(0, 4, 0),
				}
			)
			tween:Play()

			local fadeTween = TweenService:Create(
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

-- Heartbeat 연결
RunService.Heartbeat:Connect(simulateProjectiles)

-- 클린업 (주기적으로 남은 투사체 정리)
task.spawn(function()
	while true do
		task.wait(5)
		-- 죽은 투사체 정리
		for i = #activeProjectiles, 1, -1 do
			if not activeProjectiles[i].alive then
				table.remove(activeProjectiles, i)
			end
		end

		-- 플레이어가 떠난 경우 처리
		local Players = game:GetService("Players")
		for i = #activeProjectiles, 1, -1 do
			local proj = activeProjectiles[i]
			if proj.player and proj.player.Parent ~= Players then
				proj.alive = false
				table.remove(activeProjectiles, i)
			end
		end
	end
end)

return ProjectileService
