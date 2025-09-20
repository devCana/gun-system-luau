--[[
	FindUtil.lua

	Utility functions for finding instances.

	@author Mohammed Awawdi
	@version 1.0.0
	@since 2025-09-19
]]

local FindUtil = {}

function FindUtil.findFirstChildOfClass(parent: Instance, className: string, name: string): Instance?
	for _, child in pairs(parent:GetChildren()) do
		if child.ClassName == className and child.Name == name then
			return child
		end
	end
	return nil
end

return FindUtil
