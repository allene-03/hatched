local Replicated = game:GetService('ReplicatedStorage')
local VehicleAssets = Replicated:WaitForChild('Assets'):WaitForChild('Vehicles')

-- Some assets free, some paid for

local CoreVehicleData = {
	Vehicles = {
		-- Don't add anything here	
	},
	
	Customize = {
		ColorCostPercentage = 0.05,
		GlowCostPercentage = 0.2
	},
	
	SellPercentage = 0.25,
}

local Vehicles = {
	{Price = 100, Folder = VehicleAssets:FindFirstChild('Basic')},
	{Price = 350, Folder = VehicleAssets:FindFirstChild('SUV')}
}

-- Setting the table to the core returned
for _, VehicleData in pairs(Vehicles) do
	CoreVehicleData['Vehicles'][VehicleData.Folder.Name] = VehicleData
end

return CoreVehicleData