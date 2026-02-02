-- ServerScriptService/Services/ProgressionService.lua
-- 업그레이드 구매 처리, 플레이어 스탯 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local UpgradesConfig = require(ReplicatedStorage.Config.Upgrades)
local MiningService = require(script.Parent.MiningService)

local ProgressionService = {}

-- player별 업그레이드 레벨 저장
local playerLevels = {}

-- 플레이어 초기화
function ProgressionService.InitPlayer(player: Player)
	playerLevels[player.UserId] = {
		PickaxeLevel = 0,
		WandLevel = 0,
		MaxHealthLevel = 0,
	}

	-- MiningService에 PickaxeLevel 전달
	MiningService.SetPickaxeLevel(player, 0)
end

-- 플레이어 정리
function ProgressionService.CleanupPlayer(player: Player)
	playerLevels[player.UserId] = nil
end

-- 레벨 조회
function ProgressionService.GetLevel(player: Player, upgradeType: string): number
	local data = playerLevels[player.UserId]
	if data then
		return data[upgradeType] or 0
	end
	return 0
end

-- 업그레이드 구매 시도
function ProgressionService.TryBuyUpgrade(player: Player, upgradeType: string): (boolean, string?, table?)
	-- 유효성 체크
	local upgradeConfig = UpgradesConfig[upgradeType]
	if not upgradeConfig then
		return false, "InvalidUpgrade"
	end

	local currentLevel = ProgressionService.GetLevel(player, upgradeType)

	-- 최대 레벨 체크
	if currentLevel >= upgradeConfig.maxLevel then
		return false, "MaxLevel", { currentLevel = currentLevel, maxLevel = upgradeConfig.maxLevel }
	end

	-- 비용 계산
	local cost = upgradeConfig:getCost(currentLevel)

	-- 골드 체크
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return false, "NoLeaderstats"
	end

	local gold = leaderstats:FindFirstChild("Gold")
	if not gold then
		return false, "NoGold"
	end

	if gold.Value < cost then
		return false, "NotEnoughGold", { current = gold.Value, needed = cost }
	end

	-- 구매 처리
	gold.Value = gold.Value - cost
	playerLevels[player.UserId][upgradeType] = currentLevel + 1

	-- DataService에 레벨 변경 반영 (옵셔널, 순환 참조 방지)
	local DataService = require(script.Parent.DataService)
	if DataService and DataService.SetLevel then
		DataService.SetLevel(player, upgradeType, currentLevel + 1)
	end

	-- PickaxeLevel 업그레이드 시 MiningService에 알림
	if upgradeType == "PickaxeLevel" then
		MiningService.SetPickaxeLevel(player, currentLevel + 1)
	end

	-- MaxHealthLevel 업그레이드 시 체력 증가
	if upgradeType == "MaxHealthLevel" then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local healthIncrease = 10
				humanoid.MaxHealth = humanoid.MaxHealth + healthIncrease
				humanoid.Health = humanoid.Health + healthIncrease
			end
		end
	end

	local newLevel = currentLevel + 1
	local nextCost = upgradeConfig:getCost(newLevel)

	return true, nil, {
		upgradeType = upgradeType,
		newLevel = newLevel,
		cost = cost,
		nextCost = nextCost,
		maxLevel = upgradeConfig.maxLevel,
	}
end

-- 모든 레벨 조회 (UI용)
function ProgressionService.GetAllLevels(player: Player): table
	return playerLevels[player.UserId] or {}
end

-- 데이터 복원을 위한 직접 설정 함수 (DataService에서 호출)
function ProgressionService.SetPickaxeLevelDirect(player: Player, level: number)
	if playerLevels[player.UserId] then
		playerLevels[player.UserId].PickaxeLevel = level
		MiningService.SetPickaxeLevel(player, level)
	end
end

function ProgressionService.SetWandLevelDirect(player: Player, level: number)
	if playerLevels[player.UserId] then
		playerLevels[player.UserId].WandLevel = level
	end
end

function ProgressionService.SetMaxHealthLevelDirect(player: Player, level: number)
	if playerLevels[player.UserId] then
		playerLevels[player.UserId].MaxHealthLevel = level
		-- 체력 증가 적용
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local healthIncrease = level * 10
				humanoid.MaxHealth = 100 + healthIncrease
				humanoid.Health = math.min(humanoid.Health + healthIncrease, humanoid.MaxHealth)
			end
		end
	end
end

return ProgressionService
