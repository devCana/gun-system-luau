--[[
	WeaponTypes.lua

	Weapon type definitions and enums.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local WeaponTypes = {}

WeaponTypes.WeaponType = {
	Rifle = "Rifle",
	Pistol = "Pistol",
	Shotgun = "Shotgun",
	Sniper = "Sniper",
	SMG = "SMG",
}

WeaponTypes.FireMode = {
	SemiAuto = "SemiAuto",
	FullAuto = "FullAuto",
	Burst = "Burst",
	Bolt = "Bolt",
}

-- Weapon Action Key Enum
WeaponTypes.WeaponActionKey = {
	Idle = "Idle",
	Shoot = "Shoot",
	Reload = "Reload",
	Draw = "Draw",
	Holster = "Holster",
}

-- Type definitions for Luau type checking
export type WeaponType = "Rifle" | "Pistol" | "Shotgun" | "Sniper" | "SMG"
export type FireMode = "SemiAuto" | "FullAuto" | "Burst" | "Bolt"
export type WeaponActionKey = "Idle" | "Shoot" | "Reload" | "Draw" | "Holster"

export type RecoilStats = {
	horizontal: number,
	vertical: number,
	recovery: number,
}

export type SpreadStats = {
	hipFire: number,
	ads: number, -- aim down sight
}

export type WeaponStats = {
	weaponType: WeaponType,
	damage: number,
	range: number,
	fireRate: number, -- RPM
	cooldownTolerance: number,
	bulletVelocity: number,
	fireMode: FireMode,
	burstCount: number?, -- for burst fire
	bulletCount: number?, -- for shotguns (number of pellets)
	magazineSize: number,
	reloadTime: number,
	adsSpeed: number, -- aim down sight speed multiplier
	recoil: RecoilStats,
	spread: SpreadStats,
}

-- Expected Weapon Tool structure
export type Weapon = Tool & {
	Handle: BasePart & {
		Muzzle: Attachment & {
			MuzzleFlash: ParticleEmitter,
		},
	},
	Animations: Folder & {
		Idle: Animation,
		Shoot: Animation,
		Reload: Animation,
		Draw: Animation,
		Holster: Animation,
	},
	Sounds: Folder & {
		Shoot: Sound,
		Reload: Sound,
		Draw: Sound,
		Holster: Sound,
	},
	Mag: BasePart,
	Bullet: BasePart?,
	Pellet: BasePart?,
}

return WeaponTypes
