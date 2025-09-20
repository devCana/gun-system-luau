--[[
	WeaponNetwork.lua

	Network type definitions and interfaces for the weapon system.
	Provides type-safe contracts for client-server communication.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

--[[
	Represents a bullet firing request from client to server.

	@interface FireRequest
	@field origin Vector3 - World position where the bullet originates (e.g., muzzle position)
	@field direction Vector3 - Unit vector indicating bullet direction
	@field time number - Client timestamp (os.clock()) for anti-cheat validation
	@field weaponId string? - Optional weapon identifier for additional validation
	@field metadata table? - Optional metadata for extended validation
]]
export type FireRequest = {
	origin: Vector3,
	direction: Vector3,
	time: number,
	weaponId: string?,
	metadata: {
		fireMode: string?,
		stance: string?, -- "standing", "crouched", "prone"
		movement: string?, -- "stationary", "walking", "running"
	}?,
}

--[[
	Represents a confirmed hit from server to clients.

	@interface FireHit
	@field position Vector3 - World position where the hit occurred
	@field instanceName string - Name of the hit part/instance for VFX targeting
	@field damage number - Actual damage dealt after calculations
	@field hitType string - Type of hit for appropriate effects ("flesh", "metal", "wood", etc.)
	@field distance number? - Distance of the shot for damage falloff visualization
]]
export type FireHit = {
	position: Vector3,
	instanceName: string,
	damage: number,
	distance: number?,
}

--[[
	Represents bullet trajectory data for client-side effects.

	@interface BulletTrajectory
	@field startPosition Vector3 - Bullet spawn position
	@field endPosition Vector3 - Bullet end position (hit or max range)
	@field velocity number - Bullet velocity for trail effects
	@field weaponType string - Weapon type for appropriate visual effects
]]
export type BulletTrajectory = {
	startPosition: Vector3,
	endPosition: Vector3,
	velocity: number,
	weaponType: string,
}

--[[
	Represents weapon reload completion data.

	@interface ReloadData
	@field weaponId string - Identifier of the reloaded weapon
	@field newAmmoCount number - Updated ammunition count
	@field reloadTime number - Time taken for the reload operation
]]
export type ReloadData = {
	weaponId: string,
	newAmmoCount: number,
	reloadTime: number,
}

--// VALIDATION CONSTANTS

--[[
	Network validation constants for security and performance.
]]
local NetworkConstants = {
	-- Maximum allowed time difference between client and server (seconds)
	MAX_TIME_DESYNC = 2.0,

	-- Maximum allowed distance between player and shot origin (studs)
	MAX_SHOT_DISTANCE_FROM_PLAYER = 50,

	-- Minimum time between shots per player (seconds) - anti-spam protection
	MIN_SHOT_INTERVAL = 0.05,

	-- Maximum shots per second per player - rate limiting
	MAX_SHOTS_PER_SECOND = 20,
}

--// VALIDATION FUNCTIONS

--[[
	Validates a FireRequest payload for basic structure and security.

	@param payload FireRequest - The fire request to validate
	@param playerPosition Vector3 - Current player position for distance validation
	@return boolean - True if payload is valid, false otherwise
	@return string? - Error message if validation fails
]]
local function validateFireRequest(payload: FireRequest, playerPosition: Vector3): (boolean, string?)
	-- Type validation
	if type(payload) ~= "table" then
		return false, "Invalid payload type"
	end

	if typeof(payload.origin) ~= "Vector3" then
		return false, "Invalid origin type"
	end

	if typeof(payload.direction) ~= "Vector3" then
		return false, "Invalid direction type"
	end

	if type(payload.time) ~= "number" then
		return false, "Invalid time type"
	end

	-- Range validation
	local distanceFromPlayer = (payload.origin - playerPosition).Magnitude
	if distanceFromPlayer > NetworkConstants.MAX_SHOT_DISTANCE_FROM_PLAYER then
		return false, "Shot origin too far from player"
	end

	-- Direction validation (must be unit vector)
	if math.abs(payload.direction.Magnitude - 1.0) > 0.1 then
		return false, "Direction must be a unit vector"
	end

	-- Time validation
	local currentTime = os.clock()
	if math.abs(currentTime - payload.time) > NetworkConstants.MAX_TIME_DESYNC then
		return false, "Timestamp out of sync"
	end

	return true
end

--// EXPORTS

return {
	-- Type exports (for external use)
	FireRequest = {} :: FireRequest,
	FireHit = {} :: FireHit,
	BulletTrajectory = {} :: BulletTrajectory,
	ReloadData = {} :: ReloadData,

	-- Constants
	Constants = NetworkConstants,

	-- Validation functions
	validateFireRequest = validateFireRequest,
}
