-- ServerScriptService/Services/MiningService.lua
-- 채굴 시스템: 쿨다운, 보상 지급, 고갈, 리젠

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Config 로드
local OresConfig = require(ReplicatedStorage.Config.Ores)
local WeaponsConfig = require(ReplicatedStorage.Config.Weapons)

local MiningService = {}
MiningService.__index = MiningService

-- player별 채굴 쿨다운 추적
local playerCooldowns = {}
local playerStats = {} -- PickaxeLevel 등 추적

-- 쿨다운 체크 및 설정
local function setCooldown(player: Player)
	playerCooldowns[player.UserId] = tick()
end

local function getCooldownRemaining(player: Player, pickaxeLevel: number): number
	local lastMine = playerCooldowns[player.UserId]
	if not lastMine then
		return 0
	end

	local config = WeaponsConfig.Pickaxe
	local cooldownMultiplier = config.scalePerLevel.cooldownMultiplier ^ pickaxeLevel
	local actualCooldown = config.baseMineCooldown * cooldownMultiplier

	local elapsed = tick() - lastMine
	return math.max(0, actualCooldown - elapsed)
end

-- player 스탯 초기화
function MiningService.InitPlayer(player: Player)
	playerStats[player.UserId] = {
		PickaxeLevel = 0,
	}
end

-- player 스탯 정리
function MiningService.CleanupPlayer(player: Player)
	playerCooldowns[player.UserId] = nil
	playerStats[player.UserId] = nil
end

-- PickaxeLevel 설정 (ProgressionService에서 호출)
function MiningService.SetPickaxeLevel(player: Player, level: number)
	if playerStats[player.UserId] then
		playerStats[player.UserId].PickaxeLevel = level or 0
	end
end

-- PickaxeLevel 조회
function MiningService.GetPickaxeLevel(player: Player): number
	if playerStats[player.UserId] then
		return playerStats[player.UserId].PickaxeLevel
	end
	return 0
end

-- 채굴 실행
function MiningService.MineNode(player: Player, node: BasePart): (boolean, string?, number?)
	-- 쿨다운 체크
	local pickaxeLevel = MiningService.GetPickaxeLevel(player)
	local cooldownRemaining = getCooldownRemaining(player, pickaxeLevel)
	if cooldownRemaining > 0 then
		return false, "Cooldown", cooldownRemaining
	end

	-- 노드 유효성 체크
	local oreType = node:GetAttribute("OreType")
	if not oreType or not OresConfig[oreType] then
		return false, "InvalidOre"
	end

	local remaining = node:GetAttribute("Remaining") or 0
	if remaining <= 0 then
		return false, "Depleted"
	end

	-- OriginalRemaining이 없으면 첫 채굴 시점의 Remaining 값을 저장
	if not node:GetAttribute("OriginalRemaining") then
		node:SetAttribute("OriginalRemaining", remaining)
	end

	-- Config 가져오기
	local oreConfig = OresConfig[oreType]
	local weaponConfig = WeaponsConfig.Pickaxe

	-- PickaxeLevel에 따른 수확량 계산
	local yieldMultiplier = 1 + (weaponConfig.scalePerLevel.yieldMultiplier * pickaxeLevel)
	local yield = math.ceil(oreConfig.baseYield * yieldMultiplier)

	-- 리소스 지급
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local oreStat = leaderstats:FindFirstChild("Ore")
		local goldStat = leaderstats:FindFirstChild("Gold")

		if oreStat then
			oreStat.Value = oreStat.Value + yield
		end
		if goldStat then
			local goldEarned = oreConfig.goldPerUnit * yield
			goldStat.Value = goldStat.Value + goldEarned
		end
	end

	-- Remaining 감소
	remaining = remaining - 1
	node:SetAttribute("Remaining", remaining)

	-- 쿨다운 설정
	setCooldown(player)

	-- 고갈 처리
	if remaining <= 0 then
		MiningService.DepleteNode(node)
	end

	return true, nil, yield
end

-- 노드 고갈 처리
function MiningService.DepleteNode(node: BasePart)
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	-- 시각적 피드백 (투명하게)
	node.Transparency = 0.7

	-- 리젠 스케줄
	local oreType = node:GetAttribute("OreType")
	local respawnTime = node:GetAttribute("RespawnTime") or OresConfig[oreType].respawnTime

	task.delay(respawnTime, function()
		if node and node.Parent then
			MiningService.RespawnNode(node)
		end
	end)
end

-- 노드 리젠
function MiningService.RespawnNode(node: BasePart)
	local oreType = node:GetAttribute("OreType")
	if not oreType or not OresConfig[oreType] then
		return
	end

	-- Remaining 복구: OriginalRemaining이 없으면 기본값 1 사용
	local originalRemaining = node:GetAttribute("OriginalRemaining")
	if not originalRemaining then
		-- OriginalRemaining이 없으면 기본값 1로 설정 (초기 노드 설정 누락 대비)
		originalRemaining = 1
		node:SetAttribute("OriginalRemaining", originalRemaining)
	end
	node:SetAttribute("Remaining", originalRemaining)

	-- 시각적 복구
	node.Transparency = 0

	-- Prompt 재활성화
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
end

return MiningService
