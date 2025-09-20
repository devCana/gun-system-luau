--[[
	CameraController.lua

	Simple camera controller for weapon ADS and FOV changes.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)

export type CameraController = {
	changeFOV: (self: CameraController, targetFOV: number) -> (),
	getCurrentFOV: (self: CameraController) -> number,
	resetFOV: (self: CameraController) -> (),
}

local CameraController = Knit.CreateController({
	Name = "CameraController",
})

-- Constants
local DEFAULT_FOV = 70
local _ADS_FOV = 50
local FOV_TWEEN_TIME = 0.25

-- Private state
local camera = Workspace.CurrentCamera
local currentTween = nil

function CameraController:KnitStart()
	camera.FieldOfView = DEFAULT_FOV
end

function CameraController:changeFOV(targetFOV: number)
	if currentTween then
		currentTween:Cancel()
	end

	local tweenInfo = TweenInfo.new(FOV_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	currentTween = TweenService:Create(camera, tweenInfo, {
		FieldOfView = targetFOV,
	})

	currentTween:Play()
end

function CameraController:getCurrentFOV(): number
	return camera.FieldOfView
end

-- Reset FOV to default
function CameraController:resetFOV()
	self:changeFOV(DEFAULT_FOV)
end

return CameraController
