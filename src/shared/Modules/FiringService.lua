--[[
	FiringService.lua

	Core firing service providing shared firing logic with FastCastRedux integration.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponTypes = require(script.Parent.Parent.WeaponTypes)
local WeaponBehavior = require(script.Parent.WeaponBehavior)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)

export type WeaponStats = WeaponTypes.WeaponStats
export type WeaponBehavior = WeaponBehavior.WeaponBehavior

export type FiringContext = {
	origin: Vector3,
	direction: Vector3,
	weaponInstance: Instance,
	characterInstance: Instance?,
	stats: WeaponStats,
	behavior: WeaponBehavior,
	bulletsFolder: Instance?,
	bulletTemplate: Instance?,
}

export type BulletTrajectory = {
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3,
	spread: { x: number, y: number },
	bulletIndex: number,
}

export type FiringResult = {
	trajectories: { BulletTrajectory },
}

local FiringService = {}

-- Core firing logic that calculates all bullet trajectories for a shot
function FiringService.fire(context: FiringContext): FiringResult
	local trajectories = {}
	local bulletCount = context.behavior:getBulletCount()

	-- Fast path for single bullet weapons (most common case)
	if bulletCount == 1 then
		local spread = context.behavior:getSpreadPattern(0)
		local direction, velocity =
			FiringService.calculateBulletTrajectory(context.origin, context.direction, spread, context.stats)

		trajectories[1] = {
			origin = context.origin,
			direction = direction,
			velocity = velocity,
			spread = spread,
			bulletIndex = 0,
		}
	else
		-- Multi-bullet path (shotguns, etc.)
		for i = 1, bulletCount do
			local spread = context.behavior:getSpreadPattern(i - 1) -- Convert to 0-based index
			local direction, velocity =
				FiringService.calculateBulletTrajectory(context.origin, context.direction, spread, context.stats)

			trajectories[i] = {
				origin = context.origin,
				direction = direction,
				velocity = velocity,
				spread = spread,
				bulletIndex = i - 1,
			}
		end
	end

	return {
		trajectories = trajectories,
	}
end

-- Calculate the final direction and velocity for a bullet with spread applied
function FiringService.calculateBulletTrajectory(
	origin: Vector3,
	baseDirection: Vector3,
	spread: { x: number, y: number },
	stats: WeaponStats
): (Vector3, Vector3)
	local finalDirection = baseDirection.Unit

	-- Apply spread if any
	if spread.x ~= 0 or spread.y ~= 0 then
		finalDirection = FiringService.applySpread(baseDirection.Unit, spread)
	end

	local velocity = finalDirection * stats.bulletVelocity

	return finalDirection, velocity
end

-- Apply spread to a base direction vector
function FiringService.applySpread(baseDirection: Vector3, spread: { x: number, y: number }): Vector3
	if spread.x == 0 and spread.y == 0 then
		return baseDirection
	end

	-- Create a local coordinate system for applying spread
	local forward = baseDirection.Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit
	if right.Magnitude < 0.1 then
		-- Handle edge case where forward is parallel to world up
		right = forward:Cross(Vector3.new(1, 0, 0)).Unit
	end
	local up = right:Cross(forward).Unit

	-- Apply spread in local coordinates
	local spreadDirection = forward + (right * spread.x) + (up * spread.y)
	return spreadDirection.Unit
end

-- Create standard raycast parameters for bullet physics
-- Equivalent to TypeScript FiringService.createRaycastParams
function FiringService.createRaycastParams(
	weaponInstance: Instance,
	characterInstance: Instance?,
	bulletsFolder: Instance?
): RaycastParams
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.IgnoreWater = true

	local filterInstances = { weaponInstance }
	if characterInstance then
		table.insert(filterInstances, characterInstance)
	end
	if bulletsFolder then
		table.insert(filterInstances, bulletsFolder)
	end

	castParams.FilterDescendantsInstances = filterInstances
	return castParams
end

-- Create standard FastCast behavior for bullet physics
-- Equivalent to TypeScript FiringService.createCastBehavior
function FiringService.createCastBehavior(
	raycastParams: RaycastParams,
	maxDistance: number,
	bulletsFolder: Instance?,
	bulletTemplate: Instance?
)
	local castBehavior = FastCast.newBehavior()
	castBehavior.RaycastParams = raycastParams
	castBehavior.Acceleration = Vector3.new(0, -(workspace.Gravity / 2), 0)
	castBehavior.AutoIgnoreContainer = false
	castBehavior.MaxDistance = maxDistance

	-- Client-side visual elements
	if bulletsFolder and bulletTemplate then
		castBehavior.CosmeticBulletContainer = bulletsFolder
		castBehavior.CosmeticBulletTemplate = bulletTemplate
	end

	return castBehavior
end

return FiringService
