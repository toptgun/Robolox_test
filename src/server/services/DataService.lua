-- ServerScriptService/Services/DataService.lua
-- 데이터 저장 시스템: DataStore를 이용한 영구 저장

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DataService = {}

-- DataStore
local PlayerDataStore = DataStoreService:GetDataStore("MiningRPG_PlayerData_v1")

-- 저장할 데이터 구조
--[[
	{
		Gold = number,
		Ore = number,
		PickaxeLevel = number,
		WandLevel = number,
		MaxHealthLevel = number,
		UnlockedZones = { string },
	}
]]

-- 메모리 캐시 (playerData)
local playerDataCache = {}

-- 자동 저장 간격
local AUTO_SAVE_INTERVAL = 120 -- 2분

-- 기본 데이터
local function getDefaultData(): table
	return {
		Gold = 0,
		Ore = 0,
		PickaxeLevel = 0,
		WandLevel = 0,
		MaxHealthLevel = 0,
		UnlockedZones = { "StarterZone" },
	}
end

-- 데이터 로드
function DataService.LoadData(player: Player): (boolean, string?, table?)
	local userId = player.UserId
	local key = "Player_" .. userId

	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(key)
	end)

	if not success then
		warn("[DataService] Failed to load data for " .. player.Name .. ": " .. tostring(data))
		return false, "LoadFailed", nil
	end

	if data == nil then
		-- 새 플레이어
		local defaultData = getDefaultData()
		playerDataCache[userId] = defaultData
		return true, "NewPlayer", defaultData
	end

	-- 데이터 검증 (필드 누락 방지)
	local validatedData = getDefaultData()
	for field, defaultValue in pairs(validatedData) do
		if data[field] ~= nil then
			validatedData[field] = data[field]
		end
	end

	playerDataCache[userId] = validatedData
	return true, "Loaded", validatedData
end

-- 데이터 저장
function DataService.SaveData(player: Player): (boolean, string?)
	local userId = player.UserId
	local key = "Player_" .. userId
	local data = playerDataCache[userId]

	if not data then
		return false, "NoDataToSave"
	end

	-- 현재 게임 상태 반영 (leaderstats 동기화)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("Gold")
		local ore = leaderstats:FindFirstChild("Ore")
		if gold then
			data.Gold = gold.Value
		end
		if ore then
			data.Ore = ore.Value
		end
	end

	-- ProgressionService에서 레벨 동기화
	local ProgressionService = require(script.Parent.ProgressionService)
	if ProgressionService then
		local levels = ProgressionService.GetAllLevels(player)
		if levels then
			data.PickaxeLevel = levels.PickaxeLevel or data.PickaxeLevel
			data.WandLevel = levels.WandLevel or data.WandLevel
			data.MaxHealthLevel = levels.MaxHealthLevel or data.MaxHealthLevel
		end
	end

	-- ZoneService에서 해금 지역 동기화
	local ZoneService = require(script.Parent.ZoneService)
	if ZoneService then
		local unlockedZones = ZoneService.GetUnlockedZones(player)
		if unlockedZones then
			data.UnlockedZones = unlockedZones
		end
	end

	local success, err = pcall(function()
		PlayerDataStore:SetAsync(key, data)
	end)

	if not success then
		warn("[DataService] Failed to save data for " .. player.Name .. ": " .. tostring(err))
		return false, "SaveFailed"
	end

	return true, nil
end

-- 데이터 가져오기 (캐시에서)
function DataService.GetData(player: Player): table?
	return playerDataCache[player.UserId]
end

-- Gold 설정 (저장 데이터 업데이트)
function DataService.SetGold(player: Player, amount: number)
	local data = playerDataCache[player.UserId]
	if data then
		data.Gold = amount
	end
end

-- Ore 설정
function DataService.SetOre(player: Player, amount: number)
	local data = playerDataCache[player.UserId]
	if data then
		data.Ore = amount
	end
end

-- 레벨 설정
function DataService.SetLevel(player: Player, levelType: string, level: number)
	local data = playerDataCache[player.UserId]
	if data then
		data[levelType] = level
	end
end

-- 지역 해금 추가
function DataService.AddUnlockedZone(player: Player, zoneName: string)
	local data = playerDataCache[player.UserId]
	if data then
		-- 중복 방지
		for _, existingZone in data.UnlockedZones do
			if existingZone == zoneName then
				return
			end
		end
		table.insert(data.UnlockedZones, zoneName)
	end
end

-- 모든 플레이어 저장 (주기적 저장)
function DataService.SaveAll()
	local successCount = 0
	local failCount = 0

	for _, player in Players:GetPlayers() do
		local success = DataService.SaveData(player)
		if success then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end
	end

	print(string.format("[DataService] Auto-save complete: %d saved, %d failed", successCount, failCount))
	return successCount, failCount
end

-- 자동 저장 루프 시작
function DataService.StartAutoSave()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		DataService.SaveAll()
	end
end

-- 플레이어 정리
function DataService.CleanupPlayer(player: Player)
	-- 저장은 PlayerRemoving에서 처리
	playerDataCache[player.UserId] = nil
end

return DataService
