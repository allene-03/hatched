local Replicated = game:GetService('ReplicatedStorage')
local SSS = game:GetService('ServerScriptService')
local Storage = game:GetService('ServerStorage')

local Pets = Replicated.Assets.Pets
local Eggs = Replicated.Assets.Eggs

local Settings = require(Replicated.Modules.Utility.Settings)
local Scaling = require(Replicated.Modules.Utility.Scaling)
local DataModule = require(SSS.Modules.Data.Consolidate)

local Rarities = Replicated.Assets.Rarity
local Randomize = Random.new()

local PetCoreModule = {
	-- Where the pets will be stored
	PetRepository = Settings:Create('Folder', 'Pets', workspace),
	
	-- The bindable fired when eggs transition to pets
	EggTransitionBindable = Settings:Create('BindableFunction'),
	
	-- List of genders available
	Genders = {'Male', 'Female'},
	
	-- Stages to be utilized
	Stages = {
		[1] = { -- Remove number indexes
			['Stage'] = 'Egg',
			['Experience'] = 10,
			['HidesData'] = true
		},
		
		[2] = {
			['Stage'] = 'Baby',
			['Experience'] = 15,
			['Size'] = (9/10)
		},

		[3] = {
			['Stage'] = 'Tween',
			['Experience'] = 25,
			['Size'] = (10/10)
		},

		[4] = {
			['Stage'] = 'Teenager',
			['Experience'] = 50,
			['Size'] = (11/10)
		},

		[5] = {
			['Stage'] = 'Adult',
			['Size'] = (12/10) -- Can afford to cap this at 1.25
		}
	},

	Experience = {
		['Common'] = 100,
		['Rare'] = 200,
		['Ultra-Rare'] = 300,
		['Epic'] = 400,
		['Legendary'] = 500
	},
	
	-- Decide whether or not you're going to want these on
	BreedableStageEnabled = false, -- Activates the above | Consider making it Baby/Tween
	BreedableStage = 'Adult', -- Stage to be breedable

	GenderSpecificEnabled = false, -- Makes male/female breeding
	
	-- Implement this part?
	Max = {
		Female = 'Mother',
		Male = 'Father'
	},
	
	ReturnPercentage = 0.2, -- Percentage returned if sold
	PetNameCharacterCap = 50, -- The maximum characters for a pet's name
	
	-- Maximum potential amount
	MaxPotential = 100,
	
	-- Maximum self chemistry that can be removed from 'wild' or zoo pets
	MaxWildSChemistryOffset = 45,
	
	-- For size in breeding: the minimum and maximum size for 'small', 'big' pets
	Constraints = {
		Minimum = (3/4),
		Maximum = (1)
	},
	
	-- What the pets are currently scaled to relative to setting size
	PetsCurrentlyScaledTo = 1.25,
	
	-- Set the default eggs to be used, CHANGE FOR ZOO
	DefaultEggs = {
		Zoo = Eggs.London,
		NoneFound = Eggs.Baby,
	},
	
	-- A table that's going to hold the equipped pets to utilize
	EquippedPets = {},
	EquippedShareKey = 'Equipped',
	
	-- Template to be cloned for each pet
	Template = function()
		return {
			Data = {
				Points = {
					Current = 0,
					Total = 0
				},
				
				Potential = {
					['Bountiful'] = 0,
					['Self-Chemistry'] = 0, 
					['Golden'] = 0,
					['Economic'] = 0,
					['Multi-Chemistry'] = 0
				},
				
				Experience = 0,
				Stage = 1,
			},
			
			Reference = {
				Shading = {},
				Egg = "",
				Gender = "",
				Size = 0,
				Generation = 1
			},
			
			Variables = {
				Nickname = "",
			}
		}
	end,
}

local function ConvertToColor(Folder)
	local Colors = {}

	for _, ColorFolder in pairs(Folder) do
		Colors[ColorFolder.Old] = ColorFolder.New
	end

	return Colors
end

local function MatchColor(Table, OldValue)
	for Old, New in pairs(Table) do
		if Settings:equalsColor(Settings:ToColor(Old), Settings:ToColor(OldValue), 0.0065) then
			return Old, New
		end
	end
end

local function DrawColor(Pet, Colors)
	local petColors, petChanges = PetCoreModule:GetColor(Pet), {}

	if petColors then
		for i, Color in pairs(petColors) do
			local OldColor, NewColor = MatchColor(Colors, Color)

			if not NewColor then
				warn('Color discrepancy...')
				continue
			end

			for _, Part in pairs(Pet:GetDescendants()) do
				if Part:IsA('BasePart') and not Part:FindFirstChild('ColorExclusion') and Settings:equalsColor(Part.Color, Settings:ToColor(Color), 0.0065) then
					petChanges[Part] = NewColor
				end
			end
		end

		for Change, Color in pairs(petChanges) do
			Change.Color = Settings:ToColor(Color)
		end
	end

	return Pet
end

function PetCoreModule:Rescale(Size)
	return Size / (PetCoreModule.PetsCurrentlyScaledTo)
end

function PetCoreModule:GetColor(Pet)
	local Colors = {}
	
	-- The reason it's set to serialized form later is so they can be accurately compared beforehand
	for _, Part in pairs(Pet:GetDescendants()) do
		if Part:IsA('BasePart') and not Part:FindFirstChild('ColorExclusion') and not Settings:IndexColor(Colors, Part.Color) then
			table.insert(Colors, Part.Color)
		end
	end
	
	-- Convert to save-able colors
	for Indice, Color in pairs(Colors) do
		Colors[Indice] = Settings:FromColor(Color)
	end

	return Colors
end

function PetCoreModule:GetOverall(Potential)
	local Overall, Runs = 0, 0

	for _, Stat in pairs(Potential) do
		Overall += Stat
		Runs += 1
	end

	return Settings:Round(Overall / Runs)
end

-- To confirm that pets clients have sent over are legitimate
function PetCoreModule:Confirm(PlayerPets, PlayerPetsPath, Arguments)	
	if Arguments and type(Arguments) == 'table' and Arguments.Pet then
		local ServerConfirmedPet = PlayerPets[Arguments.Pet] 

		if ServerConfirmedPet then
			return ServerConfirmedPet, DataModule:TableInsert(PlayerPetsPath, Arguments.Pet)
		end
	end
end

function PetCoreModule:Create(Pet, Attributes)
	local Pet = Pets:FindFirstChild(Pet)
	
	if Pet then
		local Folder = PetCoreModule:Template()
		local Reference, Model = Folder.Reference, Pet.Models.Main
		
		-- Convert the data folder to a table and parent it to reference table
		for Name, Child in pairs(Settings:ConvertFolderToTable(Pet.Data)) do
			Reference[Name] = Child
		end
				
		-- Different parameters for breeding and defaulting from egg
		if Attributes.Bred then
			Attributes.Bred = nil
			
			for Property, Value in pairs(Attributes) do
				if Property == 'Potential' then
					local Total = 0
					
					for Name, Potential in pairs(Value) do
						Reference[Property][Name] = Potential
						Total += Potential
					end
					
					Folder.Data.Points.Total = Total
				else
					Reference[Property] = Value
				end
			end
		else
			-- Check to see if this actually works
			if Attributes.Wild then
				Reference.Egg = PetCoreModule.DefaultEggs.Zoo.Name
			elseif Attributes.Egg and Eggs[Attributes.Egg] then
				Reference.Egg = Attributes.Egg
			else
				Reference.Egg = PetCoreModule.DefaultEggs.NoneFound.Name
			end
			
			Reference.Gender = PetCoreModule.Genders[Randomize:NextInteger(1, #PetCoreModule.Genders)]
			Reference.Size = Randomize:NextInteger(1, (PetCoreModule.Constraints.Maximum - PetCoreModule.Constraints.Minimum) * 100)
			
			-- Make the wild have less self-chemistry points, goes before point calculation
			Reference['Potential']['Self-Chemistry'] -= (Attributes.Wild and Randomize:NextInteger(PetCoreModule.MaxWildSChemistryOffset / 2, PetCoreModule.MaxWildSChemistryOffset) or 0)
			
			-- Total points
			Folder.Data.Points.Total = 0

			for Name, Potential in pairs(Reference.Potential) do
				Folder.Data.Points.Total += Potential
			end
			
			-- Shading 
			for _, Color in pairs(PetCoreModule:GetColor(Model)) do
				table.insert(Reference.Shading, {Old = Color, New = Color})
			end
		end
		
		if Attributes.Wild then
			Folder.Data.Stage = 2
			Folder.Variables.Nickname = Reference.Species
		else
			Folder.Data.Stage = 1
			Folder.Variables.Nickname = Reference.Egg
		end
		
		return Folder
	end
end

-- Remote for client to retrieve IMAGE: Egg
function PetCoreModule:Spawn(Pet)
	local Stage = Pet.Data.Stage
	
	if PetCoreModule['Stages'][Stage]['Stage'] == 'Egg' then
		local Egg = Pet.Reference.Egg
		local EggFolder = Eggs:FindFirstChild(Egg) or PetCoreModule.DefaultEggs.NoneFound
		
		if not EggFolder then
			return
		end
		
		local Model = EggFolder.Models.Main:Clone()
		Model.Name = Egg
		
		return Model, EggFolder
	else
		local Species = Pet.Reference.Species
		local Shading = Pet.Reference.Shading
		
		local PetFolder = Pets:FindFirstChild(Species)
		
		if not PetFolder then
			return
		end
		
		local Model = PetFolder.Models.Main:Clone()
		local Colors = ConvertToColor(Shading)
		
		DrawColor(Model, Colors)

		-- This clamp between minimum and maximum size before setting
		local AgeSize = PetCoreModule.Stages[Stage].Size 
		local GeneticSize = (PetCoreModule.Constraints.Minimum + (Pet.Reference.Size / 100))
		
		local CumulativeSize = PetCoreModule:Rescale(AgeSize * (GeneticSize <= PetCoreModule.Constraints.Maximum and GeneticSize or PetCoreModule.Constraints.Maximum))
		
		-- Handle resizing / renaming
		Model.Name = Species
		Scaling:Resize(Model, CumulativeSize)
		
		return Model, PetFolder
	end
end

return PetCoreModule

-- Save colorExclusion in petDataFiles
