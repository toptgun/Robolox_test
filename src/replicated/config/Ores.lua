-- ReplicatedStorage/Config/Ores.lua
-- 광물 타입 설정 (baseYield, goldPerUnit, respawnTime)

return {
	Copper = {
		baseYield = 1,
		goldPerUnit = 5,
		respawnTime = 10,
		color = Color3.fromRGB(184, 115, 51),
		material = Enum.Material.CorrodedMetal,
	},

	Iron = {
		baseYield = 1,
		goldPerUnit = 15,
		respawnTime = 15,
		color = Color3.fromRGB(157, 157, 157),
		material = Enum.Material.Iron,
	},

	Gold = {
		baseYield = 1,
		goldPerUnit = 50,
		respawnTime = 30,
		color = Color3.fromRGB(255, 215, 0),
		material = Enum.Material.Gold,
	},

	Diamond = {
		baseYield = 1,
		goldPerUnit = 150,
		respawnTime = 60,
		color = Color3.fromRGB(170, 227, 255),
		material = Enum.Material.DiamondPlate,
	},
}
