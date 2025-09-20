--[[
	WeaponConstants.lua

	Weapon constants and presets.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local WeaponTypes = require(script.Parent.WeaponTypes)

local WeaponConstants = {}

WeaponConstants.WeaponDefaults = {
	weaponType = WeaponTypes.WeaponType.Rifle,
	damage = 20,
	range = 300,
	fireRate = 360,
	cooldownTolerance = 0.06,
	bulletVelocity = 600,
	fireMode = WeaponTypes.FireMode.SemiAuto,
	bulletCount = 1,
	magazineSize = 30,
	reloadTime = 2.5,
	adsSpeed = 1.0,
	recoil = {
		horizontal = 0.5,
		vertical = 1.0,
		recovery = 0.8,
	},
	spread = {
		hipFire = 2.0,
		ads = 0.5,
	},
}

-- Weapon Type Presets
WeaponConstants.WeaponPresets = {
	[WeaponTypes.WeaponType.Rifle] = {
		weaponType = WeaponTypes.WeaponType.Rifle,
		damage = 30,
		range = 400,
		fireRate = 500, -- RPM
		cooldownTolerance = 0.06,
		bulletVelocity = 600,
		fireMode = WeaponTypes.FireMode.FullAuto,
		bulletCount = 1,
		magazineSize = 30,
		reloadTime = 2.8,
		adsSpeed = 0.8,
		recoil = {
			horizontal = 0.8,
			vertical = 1.2,
			recovery = 0.7,
		},
		spread = {
			hipFire = 3.0,
			ads = 0.8,
		},
	},
	[WeaponTypes.WeaponType.Pistol] = {
		weaponType = WeaponTypes.WeaponType.Pistol,
		damage = 25,
		range = 150,
		fireRate = 400, -- RPM
		cooldownTolerance = 0.06,
		bulletVelocity = 600,
		fireMode = WeaponTypes.FireMode.SemiAuto,
		bulletCount = 1,
		magazineSize = 15,
		reloadTime = 1.8,
		adsSpeed = 1.5,
		recoil = {
			horizontal = 1.2,
			vertical = 1.8,
			recovery = 1.2,
		},
		spread = {
			hipFire = 2.5,
			ads = 1.0,
		},
	},
	[WeaponTypes.WeaponType.Shotgun] = {
		weaponType = WeaponTypes.WeaponType.Shotgun,
		damage = 80,
		range = 50,
		fireRate = 120, -- RPM
		cooldownTolerance = 0.06,
		bulletVelocity = 600,
		fireMode = WeaponTypes.FireMode.SemiAuto,
		bulletCount = 8, -- 8 pellets per shot
		magazineSize = 8,
		reloadTime = 3.5,
		adsSpeed = 0.6,
		recoil = {
			horizontal = 2.0,
			vertical = 3.0,
			recovery = 0.4,
		},
		spread = {
			hipFire = 10.0,
			ads = 5.0,
		},
	},
	[WeaponTypes.WeaponType.Sniper] = {
		weaponType = WeaponTypes.WeaponType.Sniper,
		damage = 120,
		range = 800,
		fireRate = 60, -- RPM
		cooldownTolerance = 0.06,
		bulletVelocity = 600,
		fireMode = WeaponTypes.FireMode.Bolt,
		bulletCount = 1,
		magazineSize = 5,
		reloadTime = 3.2,
		adsSpeed = 0.4,
		recoil = {
			horizontal = 0.2,
			vertical = 4.0,
			recovery = 0.3,
		},
		spread = {
			hipFire = 10.0,
			ads = 0.1,
		},
	},
	[WeaponTypes.WeaponType.SMG] = {
		weaponType = WeaponTypes.WeaponType.SMG,
		damage = 18,
		range = 200,
		fireRate = 650, -- RPM
		cooldownTolerance = 0.06,
		bulletVelocity = 600,
		fireMode = WeaponTypes.FireMode.FullAuto,
		bulletCount = 1,
		magazineSize = 25,
		reloadTime = 2.2,
		adsSpeed = 1.2,
		recoil = {
			horizontal = 1.5,
			vertical = 0.8,
			recovery = 1.0,
		},
		spread = {
			hipFire = 2.0,
			ads = 1.2,
		},
	},
}

return WeaponConstants
