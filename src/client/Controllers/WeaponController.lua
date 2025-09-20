--[[
	WeaponController.lua

	Client-side weapon controller handling input and weapon state.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Dependencies
local CharacterController = require(script.Parent.CharacterController)
local CameraController = require(script.Parent.CameraController)
local WeaponComponent = require(script.Parent.Parent.WeaponComponent)
local Network = require(ReplicatedStorage.Shared.Network)

-- Type definitions
export type WeaponState = "Idle" | "Firing" | "Reloading" | "Switching" | "Aiming"

local WeaponController = Knit.CreateController({
	Name = "WeaponController",
})

-- Private state
local player = Players.LocalPlayer
local _mouse = player:GetMouse()
local currentWeapon = nil
local currentCharacter = nil
local _isAiming = false

-- Weapon component instances keyed by tool
local weaponComponents = {}

-- Services
local CombatService = nil

function WeaponController:KnitStart()
	CombatService = Knit.GetService("CombatService")

	CharacterController:registerListener(self)

	self:setupInputBindings()

	self:setupWeaponComponents()

	self:initializeNetworking()
end

function WeaponController:initializeNetworking()
	if CombatService then
		Network.Events.fireBullet = CombatService.FireBullet
		Network.Events.reloadWeapon = CombatService.ReloadWeapon
	else
		warn("[WeaponController] CombatService is not available!")
	end
end

-- Setup input action bindings
function WeaponController:setupInputBindings()
	-- Aim (RMB / LT)
	ContextActionService:BindAction("STM_Aim", function(actionName, state)
		if state == Enum.UserInputState.Begin then
			self:setAiming(true)
		elseif state == Enum.UserInputState.End then
			self:setAiming(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	-- Fire (LMB / RT)
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:onFireBegin()
		elseif input.KeyCode == Enum.KeyCode.R then
			self:onReload()
		end
	end)

	-- Reload (R / X)
	ContextActionService:BindAction("STM_Reload", function(actionName, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		local weapon = currentWeapon
		if not weapon then
			return Enum.ContextActionResult.Pass
		end

		task.spawn(function()
			weapon:reload()
		end)

		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
end

-- Setup CollectionService listeners for automatic weapon component creation
function WeaponController:setupWeaponComponents()
	-- Listen for tools with "weapon" tag being added
	CollectionService:GetInstanceAddedSignal("weapon"):Connect(function(instance)
		if instance:IsA("Tool") then
			self:createWeaponComponent(instance)
		end
	end)

	-- Listen for tools with "weapon" tag being removed
	CollectionService:GetInstanceRemovedSignal("weapon"):Connect(function(instance)
		if instance:IsA("Tool") then
			self:destroyWeaponComponent(instance)
		end
	end)

	-- Handle existing weapon tools
	for _, instance in ipairs(CollectionService:GetTagged("weapon")) do
		if instance:IsA("Tool") then
			self:createWeaponComponent(instance)
		end
	end
end

-- Create a weapon component for a tool
function WeaponController:createWeaponComponent(tool: Tool)
	if weaponComponents[tool] then
		return -- Already exists
	end

	local weaponComponent = WeaponComponent.new(tool)
	weaponComponents[tool] = weaponComponent

	-- Setup equip/unequip handlers
	local equipConnection = tool.Equipped:Connect(function()
		weaponComponent.equipped = true
		self:setEquippedWeapon(weaponComponent)

		-- Cache animations and play equip effects
		weaponComponent:cacheAnimations()
		weaponComponent:playSound("Draw")
		weaponComponent:playDrawAnimation()
	end)

	local unequipConnection = tool.Unequipped:Connect(function()
		weaponComponent.equipped = false

		-- Play unequip effects and stop animations
		weaponComponent:playSound("Holster")
		weaponComponent:playHolsterAnimation()
		weaponComponent:stopAllAnims()

		self:setEquippedWeapon(nil)
	end)

	-- Store connections for cleanup
	weaponComponent._equipConnection = equipConnection
	weaponComponent._unequipConnection = unequipConnection
end

-- Destroy a weapon component
function WeaponController:destroyWeaponComponent(tool: Tool)
	local weaponComponent = weaponComponents[tool]
	if not weaponComponent then
		return
	end

	-- Clean up connections
	if weaponComponent._equipConnection then
		weaponComponent._equipConnection:Disconnect()
	end
	if weaponComponent._unequipConnection then
		weaponComponent._unequipConnection:Disconnect()
	end

	-- Clean up component
	weaponComponent:destroy()
	weaponComponents[tool] = nil

	-- Clear current weapon if it was this one
	if currentWeapon == weaponComponent then
		currentWeapon = nil
	end
end

-- Character lifecycle callbacks
function WeaponController:onMyCharacterLoaded(character)
	currentCharacter = character

	-- If we have an equipped weapon, notify it of character change
	if currentWeapon then
		currentWeapon:onCharacterChanged()
	end
end

function WeaponController:onMyCharacterDied()
	currentCharacter = nil

	-- Clear equipped weapon
	self:setEquippedWeapon(nil)
end

-- Set equipped weapon
function WeaponController:setEquippedWeapon(weapon)
	currentWeapon = weapon
end

-- Set aiming state
function WeaponController:setAiming(aiming)
	if not currentWeapon then
		return
	end

	_isAiming = aiming

	-- Change camera FOV
	if aiming then
		CameraController:changeFOV(50)
	else
		CameraController:changeFOV(70)
	end
end

-- Get current weapon
function WeaponController:getEquippedWeapon()
	return currentWeapon
end

-- Get current character
function WeaponController:getCurrentCharacter()
	return currentCharacter
end

return WeaponController
