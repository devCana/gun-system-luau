--[[
	ServerWeaponComponent.lua

	Server-side weapon component handling authoritative weapon state and validation.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponTypes = require(ReplicatedStorage.Shared.WeaponTypes)
local WeaponConstants = require(ReplicatedStorage.Shared.WeaponConstants)
local WeaponBehavior = require(ReplicatedStorage.Shared.Modules.WeaponBehavior)

export type WeaponStats = WeaponTypes.WeaponStats
export type WeaponBehavior = WeaponBehavior.WeaponBehavior

export type ServerWeaponComponent = {
	instance: Tool,
	stats: WeaponStats,
	behavior: WeaponBehavior,
	lastShotTime: number,
	currentAmmo: number,

	-- Methods
	hasAmmo: (self: ServerWeaponComponent) -> boolean,
	canFire: (self: ServerWeaponComponent, currentTime: number) -> boolean,
	consumeAmmo: (self: ServerWeaponComponent) -> boolean,
	reloadAmmo: (self: ServerWeaponComponent) -> (),
	markFired: (self: ServerWeaponComponent, currentTime: number) -> (),
	validateFireRequest: (self: ServerWeaponComponent, currentTime: number, playerLastFire: number) -> boolean,
	getBulletCount: (self: ServerWeaponComponent) -> number,
}

local ServerWeaponComponent = {}
ServerWeaponComponent.__index = ServerWeaponComponent

-- Create new server weapon component
function ServerWeaponComponent.new(tool: Tool): ServerWeaponComponent
	local self = setmetatable({}, ServerWeaponComponent)

	self.instance = tool
	self.stats = self:buildWeaponStats()
	self.behavior = WeaponBehavior.createWeaponBehavior(self.stats)
	self.lastShotTime = 0
	self.currentAmmo = self.stats.magazineSize

	tool:SetAttribute("WeaponType", self.stats.weaponType)

	return self
end

function ServerWeaponComponent:buildWeaponStats(): WeaponStats
	local weaponType = self.instance:GetAttribute("WeaponType") or WeaponTypes.WeaponType.Rifle
	local preset = WeaponConstants.WeaponPresets[weaponType] or WeaponConstants.WeaponDefaults
	local defaults = WeaponConstants.WeaponDefaults

	return {
		weaponType = weaponType,
		damage = self.instance:GetAttribute("Damage") or preset.damage or defaults.damage,
		range = self.instance:GetAttribute("Range") or preset.range or defaults.range,
		fireRate = self.instance:GetAttribute("FireRate") or preset.fireRate or defaults.fireRate,
		cooldownTolerance = self.instance:GetAttribute("CooldownTolerance")
			or preset.cooldownTolerance
			or defaults.cooldownTolerance,
		bulletVelocity = self.instance:GetAttribute("BulletVelocity")
			or preset.bulletVelocity
			or defaults.bulletVelocity,
		fireMode = self.instance:GetAttribute("FireMode") or preset.fireMode or defaults.fireMode,
		burstCount = self.instance:GetAttribute("BurstCount") or preset.burstCount or defaults.burstCount,
		bulletCount = self.instance:GetAttribute("BulletCount") or preset.bulletCount or defaults.bulletCount,
		magazineSize = self.instance:GetAttribute("MagazineSize") or preset.magazineSize or defaults.magazineSize,
		reloadTime = self.instance:GetAttribute("ReloadTime") or preset.reloadTime or defaults.reloadTime,
		adsSpeed = self.instance:GetAttribute("AdsSpeed") or preset.adsSpeed or defaults.adsSpeed,
		recoil = {
			horizontal = self.instance:GetAttribute("RecoilHorizontal")
				or preset.recoil.horizontal
				or defaults.recoil.horizontal,
			vertical = self.instance:GetAttribute("RecoilVertical")
				or preset.recoil.vertical
				or defaults.recoil.vertical,
			recovery = self.instance:GetAttribute("RecoilRecovery")
				or preset.recoil.recovery
				or defaults.recoil.recovery,
		},
		spread = {
			hipFire = self.instance:GetAttribute("SpreadHipFire") or preset.spread.hipFire or defaults.spread.hipFire,
			ads = self.instance:GetAttribute("SpreadAds") or preset.spread.ads or defaults.spread.ads,
		},
	}
end

-- Check if weapon has ammo
function ServerWeaponComponent:hasAmmo(): boolean
	return self.currentAmmo > 0
end

-- Check if weapon can fire at current time
function ServerWeaponComponent:canFire(currentTime: number): boolean
	return self.behavior:canFire(self.lastShotTime, currentTime)
end

-- Consume one round of ammo
function ServerWeaponComponent:consumeAmmo(): boolean
	if self.currentAmmo <= 0 then
		return false
	end

	self.currentAmmo -= 1
	return true
end

-- Reload weapon to full capacity
function ServerWeaponComponent:reloadAmmo()
	self.currentAmmo = self.stats.magazineSize
	print(`[ServerWeaponComponent] {self.instance.Name} reloaded to {self.currentAmmo} rounds`)
end

-- Mark weapon as fired at current time
function ServerWeaponComponent:markFired(currentTime: number)
	self.lastShotTime = currentTime
end

-- Validate fire request against anti-cheat measures
function ServerWeaponComponent:validateFireRequest(currentTime: number, playerLastFire: number): boolean
	local fireDelay = self.behavior:getFireDelay()
	local tolerance = self.stats.cooldownTolerance

	-- Check weapon-specific fire rate
	if currentTime - self.lastShotTime < fireDelay - tolerance then
		return false
	end

	-- Additional player-specific validation could go here
	-- For now, just basic validation

	return true
end

-- Get number of bullets this weapon fires per shot
function ServerWeaponComponent:getBulletCount(): number
	return self.behavior:getBulletCount()
end

return ServerWeaponComponent

-- Start with defaults
