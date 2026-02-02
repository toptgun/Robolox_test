-- ServerScriptService/Services/ZoneService.lua
-- 지역 해금 시스템: 진입 조건 체크, 텔레포트

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ZonesConfig = require(ReplicatedStorage.Config.Zones)
local ProgressionService = require(script.Parent.ProgressionService)

local ZoneService = {}

-- 플레이어별 해금 지역 추적
local playerUnlockedZones = {}

-- 초기화
function ZoneService.InitPlayer(player: Player)
	playerUnlockedZones[player.UserId] = {
		StarterZone = true, -- 항상 해금
	}
end

-- 정리
function ZoneService.CleanupPlayer(player: Player)
	playerUnlockedZones[player.UserId] = nil
end

-- 해금 조건 체크
function ZoneService.CheckUnlockConditions(player: Player, zoneName: string): (boolean, string?, table?)
	local zoneConfig = ZonesConfig[zoneName]
	if not zoneConfig then
		return false, "InvalidZone"
	end

	-- 플레이어 데이터 초기화 확인
	if not playerUnlockedZones[player.UserId] then
		ZoneService.InitPlayer(player)
	end

	-- 이미 해금된 지역인지 확인
	if not zoneConfig.locked then
		return true, nil, { alreadyUnlocked = true }
	end

	if playerUnlockedZones[player.UserId][zoneName] then
		return true, nil, { alreadyUnlocked = true }
	end

	-- 조건 체크
	local conditions = zoneConfig.unlockConditions
	if not conditions or #conditions == 0 then
		return true, nil, { noConditions = true }
	end

	local failedConditions = {}
	local allMet = true

	for _, condition in conditions do
		local conditionType = condition.type
		local requiredValue = condition.value

		local currentValue
		if conditionType == "PickaxeLevel" then
			currentValue = ProgressionService.GetLevel(player, "PickaxeLevel")
		elseif conditionType == "WandLevel" then
			currentValue = ProgressionService.GetLevel(player, "WandLevel")
		elseif conditionType == "MaxHealthLevel" then
			currentValue = ProgressionService.GetLevel(player, "MaxHealthLevel")
		else
			continue
		end

		if currentValue < requiredValue then
			allMet = false
			table.insert(failedConditions, {
				type = conditionType,
				current = currentValue,
				required = requiredValue,
			})
		end
	end

	if allMet then
		-- 해금 처리
		playerUnlockedZones[player.UserId][zoneName] = true

		-- DataService에 해금 지역 반영 (옵셔널, 순환 참조 방지)
		local DataService = require(script.Parent.DataService)
		if DataService and DataService.AddUnlockedZone then
			DataService.AddUnlockedZone(player, zoneName)
		end

		return true, nil, { newlyUnlocked = true }
	else
		return false, "ConditionsNotMet", {
			failedConditions = failedConditions,
			rewardDescription = zoneConfig.rewardDescription,
		}
	end
end

-- 지역 해금 여부 확인
function ZoneService.IsZoneUnlocked(player: Player, zoneName: string): boolean
	return playerUnlockedZones[player.UserId][zoneName] or false
end

-- 텔레포트 실행
function ZoneService.TeleportToZone(player: Player, zoneName: string): (boolean, string?)
	-- 조건 체크
	local canEnter, reason, result = ZoneService.CheckUnlockConditions(player, zoneName)

	if not canEnter then
		return false, reason
	end

	-- 텔레포트
	local zoneConfig = ZonesConfig[zoneName]
	local character = player.Character

	if not character then
		return false, "NoCharacter"
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return false, "NoCharacter"
	end

	-- 텔레포트 (직접 위치 이동)
	humanoidRootPart.CFrame = zoneConfig.teleportPosition

	return true, nil
end

-- 모든 해금 지역 목록
function ZoneService.GetUnlockedZones(player: Player): { string }
	local unlocked = {}
	for zoneName, _ in pairs(playerUnlockedZones[player.UserId]) do
		table.insert(unlocked, zoneName)
	end
	return unlocked
end

-- 데이터 복원을 위한 직접 해금 함수 (DataService에서 호출)
function ZoneService.UnlockZoneDirect(player: Player, zoneName: string)
	if playerUnlockedZones[player.UserId] then
		playerUnlockedZones[player.UserId][zoneName] = true
	end
end

return ZoneService
