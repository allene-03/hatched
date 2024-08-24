local Replicated = game:GetService('ReplicatedStorage')

local Purchasing = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Purchasing')

local Interact = require(Replicated:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Core'))
local PetDataModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Pet'):WaitForChild('Data'))

local Eggs = workspace:WaitForChild('Eggs')
local Zoo = workspace:WaitForChild('Zoo')

local function InitializeEgg(Egg)
	local Purchasable = Egg:WaitForChild('Purchasable')

	if Purchasable then
		local EggDetails = PetDataModule['Eggs'][Purchasable.Value]

		if EggDetails then
			local Connection = Interact:Listen(Egg, 'Click', 'Purchase ($' .. tostring(EggDetails.Price or 0) .. ')', function()
				Purchasing:InvokeServer({Type = 'Egg', Value = Purchasable.Value})
			end)
		end
	end
end

local function InitializeAnimal(Animal)
	local Purchasable = Animal:WaitForChild('Purchasable')

	if Purchasable then
		local AnimalDetails = PetDataModule['Zoo'][Purchasable.Value]
		
		repeat
			task.wait(1)
		until Animal.PrimaryPart
		
		if AnimalDetails and Animal.PrimaryPart then
			local Connection = Interact:Listen(Animal.PrimaryPart, 'Click', 'Adopt ($' .. tostring(AnimalDetails.Price or 0) .. ')', function()
				Purchasing:InvokeServer({Type = 'Zoo', Value = Purchasable.Value})
			end)
		end
	end
end

-- Initialize all the eggs
for _, Egg in pairs(Eggs:GetChildren()) do
	InitializeEgg(Egg)
end

Eggs.ChildAdded:Connect(function(Egg)
	InitializeEgg(Egg)
end)

-- Initia
for _, Animal in pairs(Zoo:GetChildren()) do
	task.spawn(function()
		InitializeAnimal(Animal)
	end)
end

Zoo.ChildAdded:Connect(function(Animal)
	InitializeEgg(Animal)
end)
