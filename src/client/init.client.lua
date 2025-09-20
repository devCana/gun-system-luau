--[[
	Client initialization script

	@author Mohammed Awawdi
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Add Controllers
Knit.AddControllers(script.Controllers)

-- Start Knit
Knit.Start()
	:andThen(function()
		print("[WeaponSystem] Client started successfully!")
	end)
	:catch(function(err)
		warn("[WeaponSystem] Client failed to start:", err)
	end)
