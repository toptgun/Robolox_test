-- ReplicatedStorage/Config/Zones.lua
-- 지역 설정 및 해금 조건

return {
	StarterZone = {
		name = "초보자 광산",
		description = "첫 번째 모험을 시작하는 곳",
		locked = false, -- 항상 열림
		teleportPosition = CFrame.new(0, 5, 0),
	},

	ForestZone = {
		name = "숲의 광산",
		description = "더 강력한 광물과 몬스터가 있는 곳",
		locked = true,
		teleportPosition = CFrame.new(0, 5, 200),
		unlockConditions = {
			{ type = "PickaxeLevel", value = 3 },
		},
		rewardDescription = "Pickaxe Lv.3 필요",
	},

	MountainZone = {
		name = "산악 광산",
		description = "험난한 지형, 희귀 광물 서식",
		locked = true,
		teleportPosition = CFrame.new(0, 50, 400),
		unlockConditions = {
			{ type = "PickaxeLevel", value = 5 },
			{ type = "WandLevel", value = 2 },
		},
		rewardDescription = "Pickaxe Lv.5, Wand Lv.2 필요",
	},

	DragonCave = {
		name = "용의 동굴",
		description = "가장 위험한 지역, 최고급 보상",
		locked = true,
		teleportPosition = CFrame.new(0, 10, 600),
		unlockConditions = {
			{ type = "PickaxeLevel", value = 10 },
			{ type = "WandLevel", value = 5 },
		},
		rewardDescription = "Pickaxe Lv.10, Wand Lv.5 필요",
	},
}
