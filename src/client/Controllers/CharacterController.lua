--[[
	CharacterController.lua

	Character lifecycle controller handling loadfunction CharacterController:getCharacter(): Character?
	return currentCharacter
end death, and respawning events.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

export type CharacterRigR15 = Model & {
	Humanoid: Humanoid,
	HumanoidRootPart: BasePart,
	RightHand: BasePart,
	LeftHand: BasePart,
	Torso: BasePart,
	Head: BasePart,
}

export type OnMyCharacterChanged = {
	onMyCharacterLoaded: (self: OnMyCharacterChanged, model: CharacterRigR15) -> (),
	onMyCharacterDied: (self: OnMyCharacterChanged) -> (),
}

local CharacterController = Knit.CreateController({
	Name = "CharacterController",
})

-- Private state
local player = Players.LocalPlayer
local currentCharacter: CharacterRigR15? = nil
local _characterAddedConnection: RBXScriptConnection? = nil
local humanoidDiedConnection: RBXScriptConnection? = nil

-- List of objects that want to be notified of character changes
local characterChangeListeners: { OnMyCharacterChanged } = {}

function CharacterController:KnitStart()
	-- Connect to player's character events
	player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdded(character)
	end)

	player.CharacterRemoving:Connect(function()
		self:_onCharacterRemoving()
	end)

	if player.Character then
		self:_onCharacterAdded(player.Character)
	end
end

-- Register a listener for character change events
function CharacterController:registerListener(listener: OnMyCharacterChanged)
	table.insert(characterChangeListeners, listener)

	-- If character is already loaded, notify immediately
	if currentCharacter then
		listener:onMyCharacterLoaded(currentCharacter)
	end
end

-- Unregister a listener
function CharacterController:unregisterListener(listener: OnMyCharacterChanged)
	for i, registeredListener in ipairs(characterChangeListeners) do
		if registeredListener == listener then
			table.remove(characterChangeListeners, i)
			break
		end
	end
end

-- Get current character
function CharacterController:getCurrentCharacter(): CharacterRigR15?
	return currentCharacter
end

-- Private method to handle character added
function CharacterController:_onCharacterAdded(character: Model)
	-- Wait for character to be fully loaded
	local humanoid = character:WaitForChild("Humanoid", 5)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	local rightHand = character:WaitForChild("RightHand", 5)

	if not humanoid or not humanoidRootPart or not rightHand then
		warn("[CharacterController] Character not properly loaded")
		return
	end

	if currentCharacter and currentCharacter:FindFirstChild("LowerTorso") then
		local r15Character = currentCharacter :: CharacterRigR15

		local toolGripMotor = Instance.new("Motor6D")
		toolGripMotor.Name = "ToolGrip"
		toolGripMotor.Part0 = r15Character.RightHand
		toolGripMotor.Part1 = nil
		toolGripMotor.Parent = r15Character.RightHand
	end

	-- Connect to humanoid died event
	humanoidDiedConnection = humanoid.Died:Connect(function()
		self:_onCharacterDied()
	end)

	-- Notify all listeners
	for _, listener in ipairs(characterChangeListeners) do
		listener:onMyCharacterLoaded(currentCharacter)
	end
end

-- Private method to handle character removing/died
function CharacterController:_onCharacterRemoving()
	if humanoidDiedConnection then
		humanoidDiedConnection:Disconnect()
		humanoidDiedConnection = nil
	end

	-- Don't call died callback here since CharacterRemoving happens after death
	currentCharacter = nil
end

-- Private method to handle character death
function CharacterController:_onCharacterDied()
	-- Notify all listeners of death
	for _, listener in ipairs(characterChangeListeners) do
		listener:onMyCharacterDied()
	end
end

return CharacterController
