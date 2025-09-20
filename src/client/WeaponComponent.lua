--[[
	WeaponComponent.lua

	Client-side weapon component handling weapon behavior, firing mechanics,
	animations, sounds, and visual effects.

	Features:
	- Semi-auto, full-auto, burst, and shotgun firing modes
	- Animation-driven magazine mechanics during reload
	- FastCastRedux integration for bullet physics and visualization
	- Auto-reload when ammunition is depleted

	@author Mohammed Awawdi
	@version 2.0.0
	@since 2025-09-20
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local WeaponTypes = require(ReplicatedStorage.Shared.WeaponTypes)
local WeaponConstants = require(ReplicatedStorage.Shared.WeaponConstants)
local WeaponBehavior = require(ReplicatedStorage.Shared.Modules.WeaponBehavior)
local FiringService = require(ReplicatedStorage.Shared.Modules.FiringService)
local Network = require(ReplicatedStorage.Shared.Network)
local FindUtil = require(ReplicatedStorage.Shared.utils.FindUtil)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)

export type WeaponStats = WeaponTypes.WeaponStats
export type Weapon = WeaponTypes.Weapon
export type WeaponBehavior = WeaponBehavior.WeaponBehavior

--[[
	WeaponComponent type definition

	Represents a client-side weapon instance with all necessary state and methods
	for handling weapon behavior, animations, sounds, and firing mechanics.
--]]

export type WeaponComponent = {
	-- Core weapon data
	instance: Tool,
	stats: WeaponStats,
	behavior: WeaponBehavior,

	-- State management
	equipped: boolean,
	currentAmmo: number,
	isReloading: boolean,
	isFiring: boolean,
	lastShotTime: number,

	-- Resources
	animTracks: { [string]: AnimationTrack },
	fireThread: thread?,
	bulletsFolder: Folder?,

	-- Core weapon actions
	startFiring: (self: WeaponComponent) -> boolean,
	stopFiring: (self: WeaponComponent) -> (),
	canFire: (self: WeaponComponent) -> boolean,
	reload: (self: WeaponComponent) -> (),

	-- Ammunition management
	hasAmmo: (self: WeaponComponent) -> boolean,
	consumeAmmo: (self: WeaponComponent) -> boolean,
	getCurrentAmmo: (self: WeaponComponent) -> number,

	-- Animation and visual effects
	onCharacterChanged: (self: WeaponComponent) -> (),
	cacheAnimations: (self: WeaponComponent) -> (),
	playSound: (self: WeaponComponent, action: string) -> (),
	playIdle: (self: WeaponComponent) -> (),

	-- Lifecycle management
	new: (tool: Tool) -> WeaponComponent,
	destroy: (self: WeaponComponent) -> (),
}

local WeaponComponent = {}
WeaponComponent.__index = WeaponComponent

function WeaponComponent.new(tool: Tool): WeaponComponent
	local weaponType = tool:GetAttribute("WeaponType") :: WeaponTypes.WeaponType?

	if not weaponType then
		local weaponData = tool:FindFirstChild("WeaponData")
		if weaponData and weaponData:IsA("StringValue") then
			weaponType = weaponData.Value :: WeaponTypes.WeaponType?
		end
	end

	if not weaponType then
		weaponType = "Rifle"
		warn(`[WeaponComponent] No WeaponType found for {tool.Name}, defaulting to Rifle`)
	end

	local weaponStats = WeaponConstants.WeaponPresets[weaponType] :: WeaponTypes.WeaponStats?
		or WeaponConstants.WeaponPresets["Rifle"]
		or WeaponConstants.WeaponDefaults

	if not weaponStats then
		error("No weapon stats available - check WeaponConstants configuration")
	end

	local behavior = WeaponBehavior[weaponStats.fireMode .. "Behavior"] or WeaponBehavior.SemiAutoBehavior

	if not WeaponBehavior[weaponStats.fireMode .. "Behavior"] then
		warn(`[WeaponComponent] Unknown fire mode '{weaponStats.fireMode}', using SemiAuto behavior`)
	end

	local bulletsFolder = workspace:FindFirstChild("BulletContainer")
	if not bulletsFolder then
		bulletsFolder = Instance.new("Folder")
		bulletsFolder.Name = "BulletContainer"
		bulletsFolder.Parent = workspace
	end

	local self = {
		instance = tool,
		stats = weaponStats,
		behavior = behavior,

		equipped = false,
		currentAmmo = weaponStats.magazineSize,
		isReloading = false,
		isFiring = false,
		lastShotTime = 0,

		animTracks = {},
		fireThread = nil,
		bulletsFolder = bulletsFolder,
	}

	setmetatable(self, WeaponComponent)
	return (self :: any) :: WeaponComponent
end

--[[
	Initiates weapon firing sequence

	Handles both single-shot and automatic firing modes. For automatic weapons,
	spawns a high-precision firing loop that continues until stopped.

	@return boolean - true if firing started successfully, false otherwise
--]]
function WeaponComponent:startFiring(): boolean
	if not self:canFire() then
		return false
	end

	self.isFiring = true

	self:fireSingleShot()

	if self.behavior:shouldAutoFire() and not self.fireThread then
		self.fireThread = coroutine.create(function()
			local fireDelay = 60 / self.stats.fireRate
			local nextFireTime = self.lastShotTime + fireDelay

			while self.isFiring and self.equipped and self:hasAmmo() do
				local currentTime = tick()

				if currentTime >= nextFireTime then
					if self.isFiring and self.equipped and self:hasAmmo() then
						self:fireSingleShot()
						nextFireTime = self.lastShotTime + fireDelay
					end
				else
					task.wait(0.001)
				end
			end
		end)

		task.spawn(self.fireThread)
	end

	return true
end

--[[
	Fires a single projectile

	Handles ammo consumption, trajectory calculation, server communication,
	and client-side visual effects. Triggers auto-reload if out of ammo.
--]]
function WeaponComponent:fireSingleShot()
	if not self:consumeAmmo() then
		print(`[{self.instance.Name}] No ammo left! Auto-reloading...`)
		self:stopFiring()
		task.spawn(function()
			self:reload()
		end)
		return
	end

	self.lastShotTime = tick()

	local player = Players.LocalPlayer

	local origin = self.instance.Handle.Muzzle and self.instance.Handle.Muzzle.WorldPosition
		or self.instance.Handle.Position
	local target = self:computeTargetPosition(origin, self.stats.range)
	local direction = (target - origin).Unit

	local bulletTemplate = nil
	if self.stats.weaponType == WeaponTypes.WeaponType.Shotgun then
		bulletTemplate = self.instance:FindFirstChild("Pellet")
	else
		bulletTemplate = self.instance:FindFirstChild("Bullet")
	end

	if not bulletTemplate then
		bulletTemplate = self:ensureBulletTemplate()
	end

	local firingContext = {
		origin = origin,
		direction = direction,
		weaponInstance = self.instance,
		characterInstance = player.Character,
		stats = self.stats,
		behavior = self.behavior,
		bulletsFolder = self.bulletsFolder,
		bulletTemplate = bulletTemplate,
	}

	local firingResult = FiringService.fire(firingContext)

	for _, trajectory in ipairs(firingResult.trajectories) do
		if Network.Events.fireBullet then
			Network.Events.fireBullet:Fire({
				origin = trajectory.origin,
				direction = trajectory.direction,
				time = os.clock(),
			})
		end

		self:fireBulletTrajectory(trajectory, firingContext.bulletTemplate)
	end

	self:playSound("Shoot")
	self:muzzleFlashOnce()
	self:playShootAnimation()

	if self.currentAmmo == 0 then
		self:playTickSound()
		self:stopFiring()
		task.spawn(function()
			self:reload()
		end)
	end
end

function WeaponComponent:stopFiring()
	self.isFiring = false

	if self.fireThread then
		self.fireThread = nil
	end
end

--[[
	Checks if the weapon can fire

	@return boolean - true if weapon can fire, false otherwise
--]]
function WeaponComponent:canFire(): boolean
	if not self.equipped then
		return false
	end

	if self.isReloading then
		return false
	end

	if not self:hasAmmo() then
		return false
	end

	local currentTime = tick()
	local fireRate = 60 / self.stats.fireRate -- Convert RPM to seconds

	return (currentTime - self.lastShotTime) >= fireRate
end

--[[
	Reloads the weapon with a full magazine

	Handles animation markers for magazine mechanics, refills ammunition,
	and notifies the server.
--]]
function WeaponComponent:reload()
	if self.isReloading or self.currentAmmo >= self.stats.magazineSize then
		return
	end

	self.isReloading = true
	print(`[{self.instance.Name}] Reloading... ({self.stats.reloadTime}s)`)

	-- Play reload sound
	self:playSound("Reload")

	-- Try to get reload animation
	local track = self:getTrack("Reload")
	local player = Players.LocalPlayer
	local character = player.Character

	if not track or not character then
		-- No animation or no character, just wait for reload time
		task.spawn(function()
			task.wait(self.stats.reloadTime)
			self.currentAmmo = self.stats.magazineSize
			self.isReloading = false
			print(`[{self.instance.Name}] Reload complete!`)

			-- Notify server of reload
			if Network.Events.reloadWeapon then
				Network.Events.reloadWeapon:Fire()
			end
		end)
		return
	end

	-- Get magazine for animation
	local mag = self.instance:FindFirstChild("Mag")

	-- Play reload animation
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	-- Handle magazine mechanics using animation markers
	local magJoint = character.LeftHand:FindFirstChild("MagJoint")
	if magJoint and mag then
		track:GetMarkerReachedSignal("GrabMag"):Once(function()
			magJoint.Part1 = mag
		end)

		track:GetMarkerReachedSignal("DropMag"):Once(function()
			-- Clone and drop the magazine
			local magClone = mag:Clone()
			magClone.Anchored = false
			magClone.Parent = workspace
			game:GetService("Debris"):AddItem(magClone, 5)
			mag.Transparency = 1
		end)

		track:GetMarkerReachedSignal("GrabMag2"):Once(function()
			mag.Transparency = 0
		end)

		track:GetMarkerReachedSignal("InsertMag"):Once(function()
			magJoint.Part1 = nil
			-- Reload complete - refill ammo
			self.currentAmmo = self.stats.magazineSize
			self.isReloading = false
			print(`[{self.instance.Name}] Reload complete!`)

			-- Notify server of reload
			if Network.Events.reloadWeapon then
				Network.Events.reloadWeapon:Fire()
			end
		end)
	end

	-- Handle animation completion
	track.Stopped:Once(function()
		self:ensureIdleAfterAction()
	end)
end

--[[
	Checks if weapon has ammunition available

	@return boolean - true if ammo available, false otherwise
--]]
function WeaponComponent:hasAmmo(): boolean
	if not self.currentAmmo then
		warn("[WeaponComponent] currentAmmo is nil for weapon:", self.instance.Name)
		return false
	end
	return self.currentAmmo > 0
end

--[[
	Consumes one round of ammunition

	@return boolean - true if ammo was consumed, false if no ammo available
--]]
function WeaponComponent:consumeAmmo(): boolean
	if self.currentAmmo <= 0 then
		return false
	end
	self.currentAmmo = self.currentAmmo - 1
	return true
end

--[[
	Gets the current ammunition count

	@return number - current ammo count
--]]
function WeaponComponent:getCurrentAmmo(): number
	return self.currentAmmo
end

--[[
	Handles character respawn/change events

	Re-caches animations when the character changes to ensure proper functionality.
--]]
function WeaponComponent:onCharacterChanged()
	-- Re-cache animations if weapon is equipped
	if self.equipped then
		self:cacheAnimations()
	end
end

--[[
	Caches weapon animations from the tool

	Loads and stores animation tracks for firing, reloading, and idle states.
--]]
function WeaponComponent:cacheAnimations()
	-- Clear previous animations
	self:stopAllAnims()

	-- Don't cache if no character is available
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	if not humanoid.Animator then
		return
	end

	local animator = humanoid.Animator
	local animationsFolder = self.instance:FindFirstChild("Animations")

	if not animationsFolder then
		return
	end

	-- Load all animations
	for _, anim in ipairs(animationsFolder:GetChildren()) do
		if anim:IsA("Animation") then
			local track = animator:LoadAnimation(anim)
			self.animTracks[anim.Name] = track
		end
	end
end

--[[
	Stops all cached animation tracks and clears the cache
--]]
function WeaponComponent:stopAllAnims()
	for _, track in pairs(self.animTracks) do
		track:Stop(0.05)
		track:Destroy()
	end
	self.animTracks = {}
end

--[[
	Retrieves a cached animation track by name

	@param actionName string - name of the animation (e.g., "Shoot", "Reload")
	@return AnimationTrack? - the animation track if found, nil otherwise
--]]
function WeaponComponent:getTrack(actionName: string): AnimationTrack?
	return self.animTracks[actionName]
end

--[[
	Plays a sound effect for a weapon action

	@param action string - name of the sound to play (e.g., "Shoot", "Reload")
--]]
function WeaponComponent:playSound(action: string)
	-- First try the Animations folder (new location) - search by class and name like TypeScript
	local animationsFolder = self.instance:FindFirstChild("Animations")
	local sound: Sound? = nil

	if animationsFolder then
		sound = FindUtil.findFirstChildOfClass(animationsFolder, "Sound", action) :: Sound?
	end

	-- Fallback to Sounds folder for backwards compatibility
	if not sound then
		local soundsFolder = self.instance:FindFirstChild("Sounds")
		if soundsFolder then
			sound = FindUtil.findFirstChildOfClass(soundsFolder, "Sound", action) :: Sound?
		end
	end

	if not sound or not sound:IsA("Sound") then
		return
	end

	-- Clone and play the sound to avoid conflicts
	local clone = sound:Clone()
	clone.Parent = self.instance
	clone:Play()
	clone.Ended:Connect(function()
		clone:Destroy()
	end)
end

function WeaponComponent:playTickSound()
	self:playSound("Tick")
end

--[[
	Plays the idle animation in a looped manner
--]]
function WeaponComponent:playIdle()
	local track = self:getTrack("Idle")
	if not track or track.IsPlaying then
		return
	end

	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement

	track:Play(0.05)
end

-- Play draw animation (when weapon is equipped)
function WeaponComponent:playDrawAnimation()
	local track = self:getTrack("Draw")
	if not track then
		-- If no draw animation, go straight to idle
		self:playIdle()
		return
	end

	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	-- When draw animation finishes, play idle
	track.Stopped:Connect(function()
		if self.equipped then
			self:playIdle()
		end
	end)
end

--[[
	Plays the holster animation when weapon is unequipped
--]]
function WeaponComponent:playHolsterAnimation()
	local track = self:getTrack("Holster")
	if not track then
		return
	end

	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
end

--[[
	Plays the shooting animation
--]]
function WeaponComponent:playShootAnimation()
	local track = self:getTrack("Shoot")
	if not track then
		self:ensureIdleAfterAction()
		return
	end

	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0)

	track.Stopped:Connect(function()
		self:ensureIdleAfterAction()
	end)
end

--[[
	Ensures idle animation plays after action animations complete
--]]
function WeaponComponent:ensureIdleAfterAction()
	if not self.equipped then
		return
	end
	self:playIdle()
end

--[[
	Triggers muzzle flash particle effect
--]]
function WeaponComponent:muzzleFlashOnce()
	local handle = self.instance:FindFirstChild("Handle")
	if not handle then
		return
	end

	local muzzle = handle:FindFirstChild("Muzzle")
	if not muzzle then
		return
	end

	local muzzleFlash = muzzle:FindFirstChild("MuzzleFlash")
	if not muzzleFlash or not muzzleFlash:IsA("ParticleEmitter") then
		return
	end

	muzzleFlash:Emit(1)
end

--[[
	Fires a bullet trajectory using FastCastRedux

	@param trajectory FiringService.BulletTrajectory - the trajectory data
	@param bulletTemplate Instance? - optional bullet template for visualization
--]]
function WeaponComponent:fireBulletTrajectory(trajectory: FiringService.BulletTrajectory, bulletTemplate: Instance?)
	-- Create raycast parameters using FiringService utility
	local character = Players.LocalPlayer.Character
	local castParams = FiringService.createRaycastParams(self.instance, character, self.bulletsFolder)

	-- Get final bullet template
	local finalBulletTemplate = bulletTemplate or self.instance:FindFirstChild("Bullet")
	if not finalBulletTemplate then
		finalBulletTemplate = self:ensureBulletTemplate()
	end

	-- Create cast behavior using FiringService utility
	local castBehavior =
		FiringService.createCastBehavior(castParams, self.stats.range, self.bulletsFolder, finalBulletTemplate)

	-- Create new FastCast instance and fire
	local caster = FastCast.new()

	-- Store reference to the bullet for cleanup
	local bulletInstance: BasePart? = nil

	local lengthChangedConnection, rayHitConnection, castTerminatingConnection

	lengthChangedConnection = caster.LengthChanged:Connect(
		function(_cast, lastPoint, direction, length, _velocity, bullet)
			if bullet and bullet:IsA("BasePart") then
				bulletInstance = bullet :: BasePart
				local bulletLength = bullet.Size.Z / 2
				local offset = CFrame.new(0, 0, -(length - bulletLength))
				bullet.CFrame = CFrame.lookAt(lastPoint, lastPoint + direction):ToWorldSpace(offset)
			end
		end
	)

	-- Set up RayHit event handler
	rayHitConnection = caster.RayHit:Connect(function(_cast, raycastResult, _velocity, bullet)
		lengthChangedConnection:Disconnect()
		rayHitConnection:Disconnect()
		castTerminatingConnection:Disconnect()

		if bullet and bullet:IsA("BasePart") then
			if
				not (raycastResult.Instance.Parent and raycastResult.Instance.Parent:FindFirstChildWhichIsA("Humanoid"))
			then
				bullet.CanCollide = true
				bullet.Anchored = false
				game:GetService("Debris"):AddItem(bullet, 2)
			else
				bullet:Destroy()
			end
		end
	end)

	-- Set up CastTerminating event (handles bullets that reach max range)
	castTerminatingConnection = caster.CastTerminating:Connect(function(_cast)
		lengthChangedConnection:Disconnect()
		rayHitConnection:Disconnect()
		castTerminatingConnection:Disconnect()

		-- Bullet reached max range - destroy it
		if bulletInstance then
			bulletInstance:Destroy()
		end
	end)

	local speed = trajectory.velocity.Magnitude
	caster:Fire(trajectory.origin, trajectory.direction, speed, castBehavior)
end

--[[
	Creates or retrieves the magazine instance for animation purposes

	@return Instance? - the magazine instance if available
--]]
function WeaponComponent:createMagazine()
	-- Find existing magazine template in weapon
	local magTemplate = self.instance:FindFirstChild("Mag")
	if magTemplate then
		return magTemplate
	end

	-- If no mag exists, we can't create one
	return nil
end

--[[
	Drops a magazine during reload animation

	Clones the magazine, makes it physical, and hides the original.

	@param mag Instance - the magazine instance to drop
--]]
function WeaponComponent:dropMagazine(mag)
	if not mag then
		return
	end

	-- Clone and drop the magazine
	local magClone = mag:Clone()
	magClone.Anchored = false
	magClone.Parent = workspace

	-- Clean up the dropped magazine after 5 seconds
	Debris:AddItem(magClone, 5)

	mag.Transparency = 1
end

--[[
	Computes target position for bullet firing

	@param origin Vector3 - the bullet origin position
	@param maxRange number - the maximum weapon range
	@return Vector3 - the target position to aim at
--]]
function WeaponComponent:computeTargetPosition(origin: Vector3, maxRange: number): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return origin + Vector3.new(0, 0, -1)
	end

	-- Desktop mouse: use classic mouse.Hit.Position (works anywhere on screen)
	local player = Players.LocalPlayer
	if player and player:GetMouse() then
		local mouse = player:GetMouse()
		if mouse.Hit then
			return mouse.Hit.Position
		end
	end

	-- Fallback: straight ahead far point
	return camera.CFrame.Position + (camera.CFrame.LookVector * maxRange)
end

--[[
	Cleans up the weapon component resources

	Stops firing, cleans up threads, and destroys animation tracks.
--]]
function WeaponComponent:destroy()
	-- Stop firing and clean up thread
	self:stopFiring()

	-- Clean up animation tracks
	for _, track in pairs(self.animTracks) do
		if track then
			track:Stop()
			track:Destroy()
		end
	end
	self.animTracks = {}
end

return WeaponComponent
