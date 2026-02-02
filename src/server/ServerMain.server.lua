-- ServerScriptService/ServerMain.server.lua
-- 서비스 초기화 엔트리 포인트

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 서비스 로드
local MiningService = require(script.Services.MiningService)
local ProgressionService = require(script.Services.ProgressionService)
local CombatService = require(script.Services.CombatService)
local ProjectileService = require(script.Services.ProjectileService)
local ZoneService = require(script.Services.ZoneService)
local DataService = require(script.Services.DataService)

-- Remotes 설정
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- PlayerAdded: leaderstats 초기화
local function onPlayerAdded(player: Player)
	-- 데이터 로드 시도
	local loadSuccess, loadReason, loadedData = DataService.LoadData(player)

	-- leaderstats 생성
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Ore stat
	local ore = Instance.new("IntValue")
	ore.Name = "Ore"
	ore.Value = loadedData and loadedData.Ore or 0
	ore.Parent = leaderstats

	-- Gold stat
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = loadedData and loadedData.Gold or 0
	gold.Parent = leaderstats

	-- 서비스 초기화
	MiningService.InitPlayer(player)
	ProgressionService.InitPlayer(player)
	ZoneService.InitPlayer(player)

	-- 로드된 데이터 반영
	if loadedData then
		-- 레벨 복원
		if loadedData.PickaxeLevel then
			ProgressionService.SetPickaxeLevelDirect and ProgressionService.SetPickaxeLevelDirect(player, loadedData.PickaxeLevel)
			MiningService.SetPickaxeLevel(player, loadedData.PickaxeLevel)
		end
		if loadedData.WandLevel then
			ProgressionService.SetWandLevelDirect and ProgressionService.SetWandLevelDirect(player, loadedData.WandLevel)
		end
		if loadedData.MaxHealthLevel then
			ProgressionService.SetMaxHealthLevelDirect and ProgressionService.SetMaxHealthLevelDirect(player, loadedData.MaxHealthLevel)
		end

		-- 해금 지역 복원
		if loadedData.UnlockedZones then
			for _, zoneName in loadedData.UnlockedZones do
				ZoneService.UnlockZoneDirect and ZoneService.UnlockZoneDirect(player, zoneName)
			end
		end

		print("[ServerMain] Loaded data for " .. player.Name .. " (" .. loadReason .. ")")
	else
		print("[ServerMain] Failed to load data for " .. player.Name .. ": " .. loadReason)
	end
end

-- PlayerRemoving: 정리 및 저장
local function onPlayerRemoving(player: Player)
	-- 데이터 저장
	local saveSuccess = DataService.SaveData(player)

	if saveSuccess then
		print("[ServerMain] Saved data for " .. player.Name)
	else
		warn("[ServerMain] Failed to save data for " .. player.Name)
	end

	-- 서비스 정리
	MiningService.CleanupPlayer(player)
	ProgressionService.CleanupPlayer(player)
	ZoneService.CleanupPlayer(player)
	DataService.CleanupPlayer(player)
end

-- RemoteEvent 핸들러
local MiningEvent = Remotes:WaitForChild("MiningEvent")

MiningEvent.OnServerEvent:Connect(function(player, node)
	local success, reason, value = MiningService.MineNode(player, node)

	if not success then
		-- TODO: 클라이언트 에러 피드백 (UiSyncEvent 등)
		if reason == "Cooldown" then
			-- 쿨다운 메시지 등
		elseif reason == "Depleted" then
			-- 고갈 메시지
		end
	end
end)

-- UpgradeEvent 핸들러
local UpgradeEvent = Remotes:WaitForChild("UpgradeEvent")

UpgradeEvent.OnServerEvent:Connect(function(player, upgradeType)
	local success, reason, result = ProgressionService.TryBuyUpgrade(player, upgradeType)

	-- 결과를 클라이언트에 전송 (fireClient 사용)
	UpgradeEvent:FireClient(player, success, reason, result)
end)

-- CombatEvent 핸들러
local CombatEvent = Remotes:WaitForChild("CombatEvent")

CombatEvent.OnServerEvent:Connect(function(player, action, ...)
	if action == "MELEE_SWING" then
		local attackId = select(1, ...)
		local success, reason, result = CombatService.MeleeSwing(player, attackId)

		if not success then
			-- TODO: 클라이언트 에러 피드백
		end
	elseif action == "RANGED_CHARGE_SHOT" then
		local origin = select(1, ...)
		local direction = select(2, ...)
		local chargeAlpha = select(3, ...)
		local attackId = select(4, ...)

		local success, reason, result = ProjectileService.FireProjectile(
			player, origin, direction, chargeAlpha, attackId
		)

		if not success then
			-- TODO: 클라이언트 에러 피드백
		end
	end
end)

-- ZoneEvent 핸들러
local ZoneEvent = Remotes:WaitForChild("ZoneEvent")

ZoneEvent.OnServerEvent:Connect(function(player, action, zoneName)
	if action == "TRY_ENTER" then
		local success, reason, result = ZoneService.TeleportToZone(player, zoneName)

		-- 클라이언트에 결과 전송
		ZoneEvent:FireClient(player, success, reason, result)
	end
end)

-- 이벤트 연결
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 이미 접속한 플레이어 처리 (재시작 대비)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- 자동 저장 루프 시작 (백그라운드)
task.spawn(DataService.StartAutoSave)

print("[ServerMain] Mining RPG Server initialized")
