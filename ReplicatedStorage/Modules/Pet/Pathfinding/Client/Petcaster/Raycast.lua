local Raycaster = {}

local Raywrapper = require(script.Raywrapper)

local Raycasts = {}

function Raycaster.new(name, params)
	if not params then
		params = RaycastParams.new()
		params.FilterDescendantsInstances = Raycaster.FilterDescendants or {}
		params.IgnoreWater = false
		params.FilterType = Enum.RaycastFilterType.Blacklist
	end
	
	if not Raycasts[name] then
		Raycasts[name] = Raywrapper.new(name, params)
	else
		return Raycasts[name]
	end
	
	return Raycasts[name]
end

function Raycaster.UpdateParams(params)
	for _, ray in pairs(Raycasts) do
		ray.Params = params
	end
end

return Raycaster