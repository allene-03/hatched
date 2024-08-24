local Raywrapper = {}
Raywrapper.__index = Raywrapper

function Raywrapper.new(name, params)
	local self = setmetatable({}, Raywrapper)
	
	self.Name = name
	self.Params = params
			
	return self
end

function Raywrapper:Cast(origin, direction)
	return workspace:Raycast(origin, direction, self.Params)
end

function Raywrapper:LocalCast(origin_cframe, vector3_offset)
	return self:Cast(origin_cframe.Position, (origin_cframe * vector3_offset - origin_cframe.Position).Unit * vector3_offset.Magnitude)
end

return Raywrapper