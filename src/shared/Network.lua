--[[
	Network.lua

	Network module providing type-safe events for weapon system communication.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _Knit = require(ReplicatedStorage.Packages.Knit)

local WeaponNetwork = require(ReplicatedStorage.Shared.WeaponNetwork)

export type FireRequest = WeaponNetwork.FireRequest
export type FireHit = WeaponNetwork.FireHit

-- Network module
local Network = {}

local initialized = false

-- Events for client-server communication
Network.Events = {
	-- Client to Server events
	fireBullet = nil,
	reloadWeapon = nil,
}

-- Functions for client-server communication
Network.Functions = {
	-- Add functions here if needed
}

function Network.init()
	if not initialized then
		Network.Events = {}
		initialized = true
	end
end

function Network.initializeServer()
	-- Server creates the events that clients will connect to
	-- This is handled by individual services
end

return Network
