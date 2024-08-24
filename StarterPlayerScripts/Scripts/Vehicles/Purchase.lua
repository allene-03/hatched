local Replicated = game:GetService('ReplicatedStorage')

local Exchanging = Replicated:WaitForChild('Remotes'):WaitForChild('Vehicles'):WaitForChild('Exchanging')

local Interact = require(Replicated:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Core'))
local VehiclesModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Vehicles'):WaitForChild('Core'))

local Platters = workspace:WaitForChild('Platters')

local function InitializePlatter(Platter)
	local Purchasable = Platter:WaitForChild('Purchasable')
	
	repeat
		task.wait(1)
	until Platter.PrimaryPart
		
	if Purchasable and Platter.PrimaryPart then
		local VehicleDetails = VehiclesModule['Vehicles'][Purchasable.Value]

		if VehicleDetails then
			local Connection = Interact:Listen(Platter.PrimaryPart, 'Click', 'Purchase ($' .. tostring(VehicleDetails.Price or 0) .. ')', function()
				Exchanging:InvokeServer('Purchasing', {Value = Purchasable.Value})
			end)
		end
	end
end

for _, Platter in pairs(Platters:GetChildren()) do
	task.spawn(function()
		InitializePlatter(Platter)
	end)
end

Platters.ChildAdded:Connect(function(Platter)
	InitializePlatter(Platter)
end)