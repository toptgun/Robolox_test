-- ReplicatedStorage/Config/Weapons.lua
-- 무기 스탯 설정 (cooldowns, chargeTime, projectile params)

return {
	Pickaxe = {
		baseMineCooldown = 0.4, -- 초 (채굴용)
		baseCombatCooldown = 0.5, -- 초 (전투용, 채굴보다 약간 느림)
		baseDamage = 10,
		range = 8,

		-- PickaxeLevel에 따른 스케일링
		scalePerLevel = {
			cooldownMultiplier = 0.92, -- 레벨당 쿨다운 8% 감소
			yieldMultiplier = 0.15, -- 레벨당 수확량 15% 증가
			damageMultiplier = 1.2, -- 레벨당 데미지 20% 증가
		},
	},

	Wand = {
		baseDamage = 20,
		baseChargeTime = 2, -- 완충까지 초
		baseCooldown = 1.0, -- 발사 쿨다운 (초)
		baseProjectileSpeed = 50,
		maxRange = 100,

		-- 차징에 따른 스케일링
		chargeScaling = {
			minSpeedMultiplier = 0.5,
			maxSpeedMultiplier = 1.5,
			minDamageMultiplier = 0.5,
			maxDamageMultiplier = 2.0,
		},

		-- WandLevel에 따른 스케일링
		scalePerLevel = {
			chargeTimeReduction = 0.1, -- 레벨당 충전시간 10% 감소
			damageMultiplier = 1.3, -- 레벨당 데미지 30% 증가
		},
	},
}
