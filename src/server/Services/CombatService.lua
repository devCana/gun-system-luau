--[[
	CombatService.lua

	Server-side combat service handling weapon mechanics and validation.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local WeaponNetwork = require(ReplicatedStorage.Shared.WeaponNetwork)
local FiringService = require(ReplicatedStorage.Shared.Modules.FiringService)
local ServerWeaponComponent = require(script.Parent.Parent.ServerWeaponComponent)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)

export type FireRequest = WeaponNetwork.FireRequest
export type ServerWeaponComponent = ServerWeaponComponent.ServerWeaponComponent
export type FireHit = WeaponNetwork.FireHit

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		-- Client to Server events
		FireBullet = Knit.CreateSignal(),
		ReloadWeapon = Knit.CreateSignal(),

		-- Server to Client events
		BulletFired = Knit.CreateSignal(),
		WeaponReloaded = Knit.CreateSignal(),
		HitConfirmed = Knit.CreateSignal(),
	},
})

-- Private state
local playerLastFire = {} -- { [Player]: number }
local weaponLastFire = {} -- { [Tool]: number }
local weaponComponents = {} -- { [Tool]: ServerWeaponComponent }

function CombatService:KnitStart()
	-- Handle fire bullet requests from clients
	self.Client.FireBullet:Connect(function(player, payload)
		self:handleFireBullet(player, payload)
	end)

	-- Handle reload requests from clients
	self.Client.ReloadWeapon:Connect(function(player)
		self:handleReloadWeapon(player)
	end)

	-- Clean up when players leave
	Players.PlayerRemoving:Connect(function(player)
		playerLastFire[player] = nil
		-- Clean up weapon components for this player
		local character = player.Character
		if character then
			local tool = character:FindFirstChildOfClass("Tool")
			if tool then
				weaponLastFire[tool] = nil
				weaponComponents[tool] = nil
			end
		end
	end)
end

--[[
	Handles fire bullet request from client

	Validates request, checks weapon state, and processes the shot if valid.

	@param player Player - the player making the request
	@param payload FireRequest - the fire request data
--]]
function CombatService:handleFireBullet(player: Player, payload: FireRequest)
	-- Basic payload validation
	if not payload or not payload.origin or not payload.direction or not payload.time then
		warn(`[CombatService] Invalid payload from {player.Name}`)
		return
	end

	local now = os.clock()

	-- Timing validation (2 second tolerance for network lag)
	if math.abs(now - payload.time) > 2.0 then
		return -- Silent fail for timing issues (common with lag)
	end

	-- Ensure player has a weapon equipped
	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or not CollectionService:HasTag(tool, "weapon") then
		return
	end

	-- Get or create weapon component
	local weapon = weaponComponents[tool]
	if not weapon then
		weapon = ServerWeaponComponent.new(tool)
		weaponComponents[tool] = weapon
	end

	-- Validation checks
	if not weapon:hasAmmo() then
		return
	end

	if not weapon:canFire(now) then
		return
	end

	-- Anti-cheat validation
	local playerLastFireTime = playerLastFire[player] or 0
	if not weapon:validateFireRequest(now, playerLastFireTime) then
		warn(`[CombatService] Fire request validation failed for {player.Name}`)
		return
	end

	-- Consume ammo
	if not weapon:consumeAmmo() then
		warn(`[CombatService] Failed to consume ammo for {tool.Name}`)
		return
	end

	-- Process the shot(s)
	self:processWeaponFire(player, payload, weapon, now)

	-- Mark weapon as fired
	weapon:markFired(now)
	weaponLastFire[tool] = now
	playerLastFire[player] = now
end

-- Process weapon fire - just fire the single bullet from the request
--[[
	Processes weapon fire for a player

	@param player Player - the player firing
	@param payload FireRequest - the fire request data
	@param weapon ServerWeaponComponent - the weapon component
	@param currentTime number - current timestamp
--]]
function CombatService:processWeaponFire(
	player: Player,
	payload: FireRequest,
	weapon: ServerWeaponComponent,
	currentTime: number
)
	-- Fire single bullet trajectory using the origin/direction from client
	-- (Client already calculated trajectories and sends one request per bullet)
	self:castBulletTrajectory(player, payload, weapon)

	-- Broadcast bullet fired event to other clients for visual effects
	-- self.Client.BulletFired:FireAllClients(player, payload)
end

--[[
	Casts a bullet trajectory using FastCastRedux

	@param player Player - the player firing
	@param payload FireRequest - the fire request data
	@param weapon ServerWeaponComponent - the weapon component
--]]
function CombatService:castBulletTrajectory(player: Player, payload: FireRequest, weapon: ServerWeaponComponent)
	-- Create raycast parameters using FiringService utility
	local castParams = FiringService.createRaycastParams(weapon.instance, player.Character)
	local castBehavior = FiringService.createCastBehavior(castParams, weapon.stats.range)

	-- Calculate velocity from direction and weapon stats
	local velocity = payload.direction * weapon.stats.bulletVelocity

	-- Use new FastCast instance
	local caster = FastCast.new()
	caster:Fire(payload.origin, payload.direction, velocity, castBehavior)

	-- Handle bullet hits
	local hitConnection
	hitConnection = caster.RayHit:Connect(function(cast, hit)
		hitConnection:Disconnect()
		hitConnection = nil
		self:processBulletHit(hit, {
			player = player,
			weapon = weapon,
			origin = payload.origin,
			direction = payload.direction,
		})
	end)

	-- Handle bullets that reach max range without hitting anything
	local terminatingConnection
	terminatingConnection = caster.CastTerminating:Connect(function(cast)
		if hitConnection ~= nil then
			hitConnection:Disconnect()
			hitConnection = nil
		end
		terminatingConnection:Disconnect()
	end)
end

--[[
	Processes bullet hit on target

	@param hit RaycastResult - the hit result
	@param context table - context containing player, weapon, origin, direction
--]]
function CombatService:processBulletHit(
	hit: RaycastResult,
	context: {
		player: Player,
		weapon: ServerWeaponComponent,
		origin: Vector3,
		direction: Vector3,
	}
)
	local _player = context.player -- Unused but kept for context
	local weapon = context.weapon

	-- Calculate damage (with falloff)
	local distance = (hit.Position - context.origin).Magnitude
	local damage = weapon.stats.damage

	-- Apply damage falloff
	if distance > weapon.stats.range * 0.5 then
		local falloffFactor = 1 - ((distance - weapon.stats.range * 0.5) / (weapon.stats.range * 0.5))
		damage = damage * falloffFactor
	end

	-- Apply damage to target (if it's a humanoid)
	local humanoid = hit.Instance and hit.Instance.Parent and hit.Instance.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
	end

	-- Broadcast hit confirmation to clients (optional)
	-- self.Client.HitConfirmed:FireAllClients(player, hit)
end

--[[
	Handles weapon reload request from client

	@param player Player - the player requesting reload
--]]
function CombatService:handleReloadWeapon(player: Player)
	-- Ensure player has a weapon equipped
	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or not CollectionService:HasTag(tool, "weapon") then
		return
	end

	-- Get weapon component
	local weapon = weaponComponents[tool]
	if not weapon then
		weapon = ServerWeaponComponent.new(tool)
		weaponComponents[tool] = weapon
	end

	-- Reload the weapon
	weapon:reloadAmmo()

	-- Broadcast reload completion to clients
	-- self.Client.WeaponReloaded:FireAllClients(player)
end

return CombatService
