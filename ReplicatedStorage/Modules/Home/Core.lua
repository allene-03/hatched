local Replicated = game:GetService('ReplicatedStorage')
local HomeAssets = Replicated:WaitForChild('Assets'):WaitForChild('Homes')

local HomeAssetsTable = {}

-- Set the homes to be utilized, DO NOT MOVE THIS UNDER MODULE TABLE
for _, Home in pairs(HomeAssets:GetChildren()) do
	HomeAssetsTable[Home.Name] = Home
end

-- If you're adding a new home, reference child 'Documentation.'

local Home = {
	Homes = {
		['Basic Home'] = {
			Model = HomeAssetsTable.Basic,
			Icon = '',
			Price = 0,
			DisplayOrder = 1,
		},
		
		['Fly Home'] = {
			Model = HomeAssetsTable.Advanced,
			Icon = '',
			Price = 200,
			DisplayOrder = 2,
		},
	},
	
	-- Interior and exterior colors can both be changed
	MutableColors = {
		Interior = true,
		Exterior = true
	},
	
	StarterHome = 'Basic Home',
	DefaultDisplayOrder = 10,
	SellPercentage = 0.6,
}

return Home