--[[
	CharacterService.lua

	Sets up character-specific components like Motor6D joints for magazine mechanics.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local CharacterService = Knit.CreateService({
	Name = "CharacterService",
	Client = {},
})

function CharacterService:KnitStart()
	print("[CharacterService] Character service started")

	Players.PlayerAdded:Connect(function(player)
		-- Set up character components when player spawns
		local function setupCharacter(character)
			-- Wait for character to be fully loaded
			local _humanoid = character:WaitForChild("Humanoid")
			local rightHand = character:WaitForChild("RightHand", 5)
			local leftHand = character:WaitForChild("LeftHand", 5)

			if not rightHand or not leftHand then
				warn("[CharacterService] Failed to find hands for", player.Name)
				return
			end

			-- Create ToolGrip for weapon handling
			local toolGrip = Instance.new("Motor6D")
			toolGrip.Name = "ToolGrip"
			toolGrip.Part0 = rightHand
			toolGrip.Parent = rightHand

			-- Create MagJoint for magazine mechanics
			local magJoint = Instance.new("Motor6D")
			magJoint.Name = "MagJoint"
			magJoint.Part0 = leftHand
			magJoint.C0 = CFrame.fromAxisAngle(Vector3.new(1, 0, 0), math.rad(90)) * CFrame.new(0, -0.2, 0)
			magJoint.Parent = leftHand
		end

		-- Setup for current character if it exists
		if player.Character then
			setupCharacter(player.Character)
		end

		-- Setup for future characters
		player.CharacterAdded:Connect(setupCharacter)
	end)
end

return CharacterService
