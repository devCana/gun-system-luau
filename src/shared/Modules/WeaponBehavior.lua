--[[
	WeaponBehavior.lua

	Weapon behavior system providing different firing behaviors for weapon types.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local WeaponTypes = require(script.Parent.Parent.WeaponTypes)

export type WeaponStats = WeaponTypes.WeaponStats
export type FireMode = WeaponTypes.FireMode

export type WeaponBehavior = {
	canFire: (self: WeaponBehavior, lastShotTime: number, currentTime: number) -> boolean,
	getFireDelay: (self: WeaponBehavior) -> number,
	shouldAutoFire: (self: WeaponBehavior) -> boolean,
	getBulletCount: (self: WeaponBehavior) -> number,
	getSpreadPattern: (self: WeaponBehavior, shotIndex: number) -> { x: number, y: number },
	isBurstBehavior: (self: WeaponBehavior) -> boolean,
	startBurst: ((self: WeaponBehavior, currentTime: number) -> ())?,
	incrementBurst: ((self: WeaponBehavior) -> ())?,
}

-- Base WeaponBehavior (abstract)
local WeaponBehaviorBase = {}
WeaponBehaviorBase.__index = WeaponBehaviorBase

function WeaponBehaviorBase.new(stats: WeaponStats)
	local self = setmetatable({}, WeaponBehaviorBase)
	self.stats = stats
	return self
end

function WeaponBehaviorBase:isBurstBehavior(): boolean
	return false
end

-- SemiAutoBehavior
local SemiAutoBehavior = {}
SemiAutoBehavior.__index = SemiAutoBehavior
setmetatable(SemiAutoBehavior, { __index = WeaponBehaviorBase })

function SemiAutoBehavior.new(stats: WeaponStats): WeaponBehavior
	local self = setmetatable(WeaponBehaviorBase.new(stats), SemiAutoBehavior)
	return self
end

function SemiAutoBehavior:canFire(lastShotTime: number, currentTime: number): boolean
	local fireDelay = self:getFireDelay()
	return currentTime - lastShotTime >= fireDelay
end

function SemiAutoBehavior:getFireDelay(): number
	return 60 / self.stats.fireRate -- Convert RPM to seconds
end

function SemiAutoBehavior:shouldAutoFire(): boolean
	return false
end

function SemiAutoBehavior:getBulletCount(): number
	return 1
end

function SemiAutoBehavior:getSpreadPattern(shotIndex: number): { x: number, y: number }
	return { x = 0, y = 0 }
end

-- FullAutoBehavior
local FullAutoBehavior = {}
FullAutoBehavior.__index = FullAutoBehavior
setmetatable(FullAutoBehavior, { __index = WeaponBehaviorBase })

function FullAutoBehavior.new(stats: WeaponStats): WeaponBehavior
	local self = setmetatable(WeaponBehaviorBase.new(stats), FullAutoBehavior)
	return self
end

function FullAutoBehavior:canFire(lastShotTime: number, currentTime: number): boolean
	local fireDelay = self:getFireDelay()
	return currentTime - lastShotTime >= fireDelay
end

function FullAutoBehavior:getFireDelay(): number
	return 60 / self.stats.fireRate
end

function FullAutoBehavior:shouldAutoFire(): boolean
	return true
end

function FullAutoBehavior:getBulletCount(): number
	return 1
end

function FullAutoBehavior:getSpreadPattern(shotIndex: number): { x: number, y: number }
	return { x = 0, y = 0 }
end

-- BurstBehavior
local BurstBehavior = {}
BurstBehavior.__index = BurstBehavior
setmetatable(BurstBehavior, { __index = WeaponBehaviorBase })

function BurstBehavior.new(stats: WeaponStats): WeaponBehavior
	local self = setmetatable(WeaponBehaviorBase.new(stats), BurstBehavior)
	self.burstShotCount = 0
	self.burstStartTime = 0
	return self
end

function BurstBehavior:canFire(lastShotTime: number, currentTime: number): boolean
	local burstDelay = 0.1 -- Time between shots in burst
	local burstCooldown = self:getFireDelay()
	local burstCount = self.stats.burstCount or 3

	if self.burstShotCount == 0 then
		-- Start new burst
		return currentTime - lastShotTime >= burstCooldown
	elseif self.burstShotCount < burstCount then
		-- Continue burst
		return currentTime - self.burstStartTime >= burstDelay * self.burstShotCount
	end

	return false
end

function BurstBehavior:getFireDelay(): number
	return 60 / self.stats.fireRate
end

function BurstBehavior:shouldAutoFire(): boolean
	return false
end

function BurstBehavior:getBulletCount(): number
	return 1
end

function BurstBehavior:getSpreadPattern(shotIndex: number): { x: number, y: number }
	return { x = 0, y = 0 }
end

function BurstBehavior:isBurstBehavior(): boolean
	return true
end

function BurstBehavior:startBurst(currentTime: number)
	self.burstShotCount = 0
	self.burstStartTime = currentTime
end

function BurstBehavior:incrementBurst()
	self.burstShotCount += 1
end

-- ShotgunBehavior
local ShotgunBehavior = {}
ShotgunBehavior.__index = ShotgunBehavior
setmetatable(ShotgunBehavior, { __index = WeaponBehaviorBase })

function ShotgunBehavior.new(stats: WeaponStats): WeaponBehavior
	local self = setmetatable(WeaponBehaviorBase.new(stats), ShotgunBehavior)
	return self
end

function ShotgunBehavior:canFire(lastShotTime: number, currentTime: number): boolean
	local fireDelay = self:getFireDelay()
	return currentTime - lastShotTime >= fireDelay
end

function ShotgunBehavior:getFireDelay(): number
	return 60 / self.stats.fireRate
end

function ShotgunBehavior:shouldAutoFire(): boolean
	return false
end

function ShotgunBehavior:getBulletCount(): number
	return self.stats.bulletCount or 8
end

function ShotgunBehavior:getSpreadPattern(shotIndex: number): { x: number, y: number }
	-- Generate random spread pattern for each pellet
	local spreadRange = self.stats.spread.hipFire or 5.0
	local angle = math.random() * math.pi * 2
	local distance = math.random() * spreadRange

	return {
		x = math.cos(angle) * distance,
		y = math.sin(angle) * distance,
	}
end

-- Factory function to create weapon behaviors
local function createWeaponBehavior(stats: WeaponStats): WeaponBehavior
	local fireMode = stats.fireMode

	if fireMode == WeaponTypes.FireMode.SemiAuto then
		return SemiAutoBehavior.new(stats)
	elseif fireMode == WeaponTypes.FireMode.FullAuto then
		return FullAutoBehavior.new(stats)
	elseif fireMode == WeaponTypes.FireMode.Burst then
		return BurstBehavior.new(stats)
	elseif fireMode == WeaponTypes.FireMode.Bolt then
		return SemiAutoBehavior.new(stats) -- Bolt action acts like semi-auto with slower fire rate
	elseif stats.weaponType == WeaponTypes.WeaponType.Shotgun then
		return ShotgunBehavior.new(stats)
	else
		return SemiAutoBehavior.new(stats) -- Default fallback
	end
end

return {
	createWeaponBehavior = createWeaponBehavior,
	SemiAutoBehavior = SemiAutoBehavior,
	FullAutoBehavior = FullAutoBehavior,
	BurstBehavior = BurstBehavior,
	ShotgunBehavior = ShotgunBehavior,
}
