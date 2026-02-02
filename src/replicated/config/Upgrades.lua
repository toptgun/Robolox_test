-- ReplicatedStorage/Config/Upgrades.lua
-- 업그레이드 설정 (비용, 최대 레벨, 효과)

return {
	PickaxeLevel = {
		maxLevel = 10,
		baseCost = 50,
		costMultiplier = 1.5, -- 레벨당 비용 1.5배 증가

		-- 비용 계산: baseCost * (costMultiplier ^ (level - 1))
		getCost = function(self, currentLevel: number): number
			if currentLevel >= self.maxLevel then
				return math.huge -- 최대 레벨 도달
			end
			return math.floor(self.baseCost * (self.costMultiplier ^ currentLevel))
		end,

		-- 다음 레벨 효과 설명
		getEffectDescription = function(self, nextLevel: number): string
			local config = require(script.Parent.Weapons)
			local scale = config.Pickaxe.scalePerLevel

			local cooldownReduction = math.floor((1 - (scale.cooldownMultiplier ^ nextLevel)) * 100)
			local yieldIncrease = math.floor(scale.yieldMultiplier * nextLevel * 100)

			return string.format(
				"쿨다운 %d%% 감소, 수확량 +%d%%",
				cooldownReduction,
				yieldIncrease
			)
		end,
	},

	WandLevel = {
		maxLevel = 10,
		baseCost = 100,
		costMultiplier = 1.6,

		getCost = function(self, currentLevel: number): number
			if currentLevel >= self.maxLevel then
				return math.huge
			end
			return math.floor(self.baseCost * (self.costMultiplier ^ currentLevel))
		end,

		getEffectDescription = function(self, nextLevel: number): string
			local chargeTimeReduction = math.floor(0.1 * nextLevel * 100)
			local damageIncrease = math.floor(0.3 * nextLevel * 100)

			return string.format(
				"충전시간 %d%% 감소, 데미지 +%d%%",
				chargeTimeReduction,
				damageIncrease
			)
		end,
	},

	MaxHealthLevel = {
		maxLevel = 10,
		baseCost = 30,
		costMultiplier = 1.3,

		getCost = function(self, currentLevel: number): number
			if currentLevel >= self.maxLevel then
				return math.huge
			end
			return math.floor(self.baseCost * (self.costMultiplier ^ currentLevel))
		end,

		getEffectDescription = function(self, nextLevel: number): string
			return string.format("최대 체력 +%d", nextLevel * 10)
		end,
	},
}
