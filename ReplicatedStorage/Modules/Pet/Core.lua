-- Forked from SSS/PetCoreHandler
local Replicated = game:GetService('ReplicatedStorage')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Assets = Replicated:WaitForChild('Assets')

local PetAssets = Assets:WaitForChild('Pets')
local EggsAssets = Assets:WaitForChild('Eggs')

local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Pets')
local Cache = Remotes:WaitForChild('Caching')

local Pet = {
	DefaultCameraCFrame =  CFrame.Angles(math.rad(337.5), math.rad(42.5), math.rad(13.5)) * CFrame.new(0, 0, 6.25),
	
	OptimizedMaterials = {
		Enum.Material.SmoothPlastic,
		Enum.Material.Foil
	}
}

-- HAVE TO ENSURE THIS WORKS / TEST IF NOT
local PetSettings = Cache:InvokeServer()
Pet.Settings = PetSettings

function MatchColor(Table, OldValue)
	for Old, New in pairs(Table) do
		if Settings:equalsColor(Settings:ToColor(Old), Settings:ToColor(OldValue), 0.0065) then
			return Old, New
		end
	end
end

local function ConvertToColor(Folder)
	local Colors = {}

	for _, ColorFolder in pairs(Folder) do
		Colors[ColorFolder.Old] = ColorFolder.New
	end

	return Colors
end

function GetColor(Pet)
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

local function DrawColor(Pet, Colors)
	local petColors, petChanges = GetColor(Pet), {}

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

local function LightModel(Model)
	for _, Part in pairs(Model:GetChildren()) do
		if Part:IsA('BasePart') and Part.Transparency < 1 then
			if Settings:equalsColor(Part.Color, Color3.new(1, 1, 1), 0.15) then
				return true
			end
		end
	end
end

function Pet:Scale(Size)
	return Size / (Pet.Settings.PetsCurrentlyScaledTo)
end

function Pet:GetAge(Stage)
	local Next
	
	if Settings:iMax(Pet.Settings.Stages) == Stage then
		Next = 'MAX'
	else
		Next = Pet.Settings.Stages[Stage + 1].Stage
	end
	
	return Pet.Settings.Stages[Stage].Stage, Next
end

function Pet:GetSize(Size)
	local List = {'Small', 'Average', 'Big'}
	
	local MinimumSize = Pet.Settings.Constraints.Minimum
	local MaximumSize = Pet.Settings.Constraints.Maximum
	
	local Size = (MinimumSize + (Size / 100))
	local Value = (Size - MinimumSize) / (MaximumSize - MinimumSize)
		
	local Return = 'UNKNOWN'
	
	for i = 1, #List do
		if Value <= (i / #List) then
			Return = List[i]
			break
		end
	end
	
	return Return
end

function Pet:GetAttribute(Folder, Attribute, IgnoreEggStatus)
	local Data = Folder.Data
	local Reference = Folder.Reference
	
	if (Pet['Settings']['Stages'][Data.Stage]['Stage'] == 'Egg' and not IgnoreEggStatus) then
		return '???'
	else
		return Reference[Attribute]
	end
end

function Pet:GetPotential(Folder, PotentialType, IgnoreEggStatus)
	local Potential = Pet:GetAttribute(Folder, 'Potential', IgnoreEggStatus)
	
	if Potential and type(Potential) == 'table' then
		Potential = Potential[PotentialType]
	end
	
	return Potential
end

function Pet:GetCamera(Object, CameraCFrame)	
	if CameraCFrame then
		return Object.PrimaryPart.CFrame * CameraCFrame.Value
	else
		return Object.PrimaryPart.CFrame * Pet.DefaultCameraCFrame
	end
end

function Pet:ReturnCamera(Button, Details)
	local Camera, Object

	if Details.Model then
		local Picture =  Button.Background.Picture
		local Configurations = Details.Folder.Interface

		Object = Details.Model:Clone()
		Object.Parent = Picture

		Camera = Instance.new('Camera')
		Camera.CFrame = Pet:GetCamera(Object, Configurations:FindFirstChild('Camera'))
		Camera.Parent = Picture
		
		local BackgroundColor = Picture.BackgroundColor3
		
		if LightModel(Object) then
			print('Light.')
			BackgroundColor = Color3.fromRGB(165, 165, 165) -- test 0, 0, 0 for all
		end
		
		Picture.BackgroundColor3 = BackgroundColor
		Picture.CurrentCamera = Camera
		
		return Camera, Object, BackgroundColor
	end
end

local function CreateForInterface(Folder)
	local Stage = Folder.Data.Stage
	local Model
	
	-- Spawn and modify the model
	if Pet['Settings']['Stages'][Stage]['Stage'] == 'Egg' then
		local Egg = Folder.Reference.Egg
		local EggFolder = EggsAssets:FindFirstChild(Egg) or Pet.Settings.DefaultEggs.NoneFound

		if not EggFolder then
			return
		end

		Model = EggFolder.Models.Client:Clone()
	else
		local Species = Folder.Reference.Species
		local Shading = Folder.Reference.Shading

		local PetFolder = PetAssets:FindFirstChild(Species)

		if not PetFolder then
			return
		end
		
		Model = PetFolder.Models.Client:Clone()
		
		local Colors = ConvertToColor(Shading)
		DrawColor(Model, Colors)

		for _, Part in pairs(Model:GetChildren()) do
			if Part:IsA('BasePart') then
				if Settings:Index(Pet.OptimizedMaterials, Part.Material) then
					if Part.Transparency > 0 then
						Part.Material = Enum.Material.SmoothPlastic
					else
						Part.Material = Enum.Material.Glass
					end
				end
			end
		end
	end
	
	-- Perfect equillibrium between performance and speed
	task.wait(0.075)
	
	return Model
end

-- Add spawning
function Pet:GetData(Folder, IsAnEgg)
	if Folder then
		return {
			Model = CreateForInterface(Folder),
			Folder = (IsAnEgg and EggsAssets:FindFirstChild(Folder.Reference.Egg or Pet.Settings.DefaultEggs.NoneFound.Name)) or
				PetAssets:FindFirstChild(Folder.Reference.Species)
		}
	end
end

function Pet:GetOverall(Potential)
	local Overall, Runs = 0, 0

	for _, Stat in pairs(Potential) do
		Overall += Stat
		Runs += 1
	end

	return Settings:Round(Overall / Runs)
end

return Pet