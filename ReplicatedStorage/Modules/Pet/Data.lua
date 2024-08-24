local Replicated = game:GetService('ReplicatedStorage')

local Pets = Replicated.Assets.Pets
local Eggs = Replicated.Assets.Eggs

local Rarities = Replicated.Assets.Rarity

local PetDataModule = {}

-- Functions
function Rates(RarityTable)
	local Temporary = {}

	for _, Rarity in pairs(Rarities:GetChildren()) do
		Temporary[Rarity.Name] = RarityTable[Rarity.Rank.Value]
	end

	return Temporary
end

-- Eggs
local Eggs = {
	_Baby = {
		Rates = Rates({42.5, 37.5, 15, 4.5, 0.5}),
		Model = Eggs:WaitForChild('Baby'),
		Price = 0
	},
	
	_London = {
		Rates = Rates({25, 40, 20, 12.5, 2.5}),
		Model = Eggs:WaitForChild('London'),
		Price = 1250
	},
	
	_Brazen = {
		Rates = Rates({0, 0, 0, 0, 100}),
		Model = Eggs:WaitForChild('Brazen'),
		Price = 100
	},
}

-- Zoo animals
local Zoo = {
	_Zebra = {
		Model = Pets:WaitForChild('Zebra'),
		Price = 300
	},
	
	_Sandhill = {
		Model = Pets:WaitForChild('Sandhill Crane'),
		Price = 150
	},
}

-- Set these to the main module
PetDataModule.Zoo = Zoo
PetDataModule.Eggs = Eggs

return PetDataModule