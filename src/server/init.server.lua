--[[
	Server initialization script

	@author Mohammed Awawdi
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Add Services
Knit.AddServices(script.Services)

-- Ensure Character Service is loaded for MagJoint setup
require(script.Services.CharacterService)

-- Start Knit
Knit.Start():andThen(function() end):catch(function(err)
	warn("[Knit] Server failed to start:", err)
end)
