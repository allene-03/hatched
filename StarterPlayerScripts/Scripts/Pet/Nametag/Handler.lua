-- WaitForSharedData, Instead of request you should be using SharedData and only request names on server

-- Replicated
local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

-- Instances
local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Pets')
local Tag = Replicated:WaitForChild('Assets'):WaitForChild('Interface'):WaitForChild('Pets'):WaitForChild('Tag')

local Request, Update = Remotes:WaitForChild('Requesting'), Remotes:WaitForChild('Updating')
local Hide = Remotes.Parent:WaitForChild('Interface'):WaitForChild('Hide')

local LocalPlayer = Players.LocalPlayer

-- Modules
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local PetModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Pet'):WaitForChild('Core'))

local DataModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Data'):WaitForChild('Core'))

-- Variables
local PrimaryColor, AlternateColor = Color3.fromRGB(63, 167, 245), Color3.fromRGB(243, 170, 39)
local HideFilter, Hiding = 'Petname', false
local AgeXOffset = 0.10

local Events = {}

-- Functions
local function Clear(Events)
	for _, Event in pairs(Events) do
		if typeof(Event) == 'Instance' then
			print('Disconnected bindable.')
			DataModule:Disconnect(Event)
		else
			print('Disconnected mainstream event.')
			Event:Disconnect()
		end
	end
	
	return {}
end

local function GetAge(PetFolder)
	local Stage = PetFolder.Data.Stage
	
	local CurrentAge, NextAge = PetModule:GetAge(Stage)
	local PercentageAge
	
	if NextAge == 'MAX' then
		PercentageAge = 1
	else
		PercentageAge = (PetFolder.Data.Experience / ((PetModule.Settings.Stages[Stage].Experience / 100) * PetModule.Settings.Experience[PetModule:GetAttribute(PetFolder, 'Rarity', true)]))
	end
	
	local BarAge = UDim2.fromScale(AgeXOffset + ((1 - AgeXOffset) * PercentageAge), 1)
	
	return CurrentAge, BarAge
end

local function Commence(Player, Pet, PetFolder, PetName)
	local Head = Pet:WaitForChild('Head', 2) or Pet:WaitForChild('Body', 2) or Pet:WaitForChild('RootPart', 2)
	
	local PetTag = Tag:Clone()
	local Holder = PetTag:WaitForChild('Holder')
	
	-- Wait for all it's descendants
	local Age = Holder:WaitForChild('Age')
	local Nickname = Holder:WaitForChild('Nickname')
	local Progress = Holder:WaitForChild('Bar'):WaitForChild('Progress')
	local OverallLabel = Holder:WaitForChild('Image'):WaitForChild('Main'):WaitForChild('Overall')
	local Image = Holder.Image.Main
	
	local AgeValue, BarSize = GetAge(PetFolder)
	
	local Potential = PetModule:GetAttribute(PetFolder, 'Potential')
	local Overall

	if Potential and type(Potential) == 'table' then
		Overall = PetModule:GetOverall(Potential)
	else
		Overall = Potential
	end
	
	Age.Text = AgeValue
	Progress.Size = BarSize
	
	Nickname.Text = PetName
	OverallLabel.Text = Overall
	
	if Player == LocalPlayer then
		PetTag.AlwaysOnTop = true
		Image.ImageColor3 = PrimaryColor
	else
		PetTag.AlwaysOnTop = false
		Image.ImageColor3 = AlternateColor
	end
	
	if Hiding == true then
		Holder.Visible = false
	end
		
	-- Age changed, progress changed
	print('Glitchy', 'Memory leaks', 'Reminder') -- Not really but I'd check structure | If player leaves, I believe events will keep going 
	Events[Pet] = {}
	
	local SharedPlayer = DataModule:Wait(DataModule, 'SharedData', Player.Name)
	local SharedFolder = DataModule:Wait(DataModule.SharedData, Player.Name, 'Equipped')
	
	local ExperienceChanged = DataModule:Changed(SharedFolder.Data, 'Experience')
	local StageChanged = DataModule:Changed(SharedFolder.Data, 'Stage')
	
	table.insert(Events[Pet], ExperienceChanged)
	table.insert(Events[Pet], StageChanged)
	
	table.insert(Events[Pet], ExperienceChanged.Event:Connect(function()
		local AgeValue, BarSize = GetAge(SharedFolder)

		Age.Text = AgeValue
		Progress.Size = BarSize
	end))

	table.insert(Events[Pet], StageChanged.Event:Connect(function()
		local AgeValue, BarSize = GetAge(SharedFolder)

		Age.Text = AgeValue
		Progress.Size = BarSize
	end))
	
	-- Save the tag as well
	Events[Pet]['Tag'] = PetTag
	
	PetTag.Parent = Head
end

local function Conclude(Pet)
	if Events[Pet] then
		if Events[Pet]['Tag'] then			
			Events[Pet]['Tag']:Destroy()
			Events[Pet]['Tag'] = nil
		end
		
		Events[Pet] = Clear(Events[Pet])
	end
end

local function Apply(Player, Pet, Folder, PetName)
	local PetEvents = Events[Pet]
	
	if PetEvents then
		local Tag = PetEvents['Tag']
		
		if Tag then
			local Holder = Tag:FindFirstChild('Holder')
			
			if Holder then
				local Nickname = Holder:FindFirstChild('Nickname')
				
				if Nickname then
					Nickname.Text = PetName
				end
			end
		end
	else
		warn('Did not find tag on pet.')
		Commence(Player, Pet, Folder, PetName)
	end
end

local function Hidden(notVisible)
	for Pet, PetInformation in pairs(Events) do
		if PetInformation.Tag then
			local Holder = PetInformation['Tag']:FindFirstChild('Holder')
			
			if Holder then
				Holder.Visible = not notVisible
			end
		end
	end
end

-- Events
Update.OnClientEvent:Connect(function(Mode, Arguments)
	if Mode == 'Equipped' then
		if Arguments.Type == 'New' then
			Commence(Arguments.Player, Arguments.Pet, Arguments.Folder, Arguments.Name)
		elseif Arguments.Type == 'Update' then
			Apply(Arguments.Player, Arguments.Pet, Arguments.Folder, Arguments.Name)
		end
	elseif Mode == 'Unequipped' then
		Conclude(Arguments.Pet)
	end
end)

local CurrentPets = Request:InvokeServer(true)

for _, Information in ipairs(CurrentPets) do
	Commence(Information.Player, Information.Pet, Information.Folder, Information.Name)
end

Hide.Event:Connect(function(Status, Type, List)
	local Mention = Settings:Index(List, HideFilter)

	if Type == 'Except' then
		if Status == 'Hide' then
			if not Mention then
				Hiding = true
			end
		else
			if not Mention then
				Hiding = false
			end
		end
	elseif Type == 'Including' then
		if Status == 'Hide' then
			if Mention then
				Hiding = true
			end
		else
			if Mention then
				Hiding = false
			end
		end
	end
	
	Hidden(Hiding)
end)

-- Centralize all the pet 'heads' with part PetTagHolder
