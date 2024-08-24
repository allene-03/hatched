local ServerScriptService = game:GetService('ServerScriptService')
local Replicated = game:GetService('ReplicatedStorage')
local TextService = game:GetService('TextService')
local Players = game:GetService('Players')

local Pathfinder = require(ServerScriptService.Modules.Pet.Pathfinder)
local Growth = require(ServerScriptService.Modules.Pet.Growth)
local Choice = require(ServerScriptService.Modules.Pet.Choice)
local CarryModule = require(ServerScriptService.Modules.Pet.Carry)
local Core = require(ServerScriptService.Modules.Pet.Core)

local DataModule = require(ServerScriptService.Modules.Data.Consolidate)
local Inventory = require(ServerScriptService.Modules.Inventory.Core)
local Settings = require(Replicated.Modules.Utility.Settings)

local Rarity = Replicated.Assets.Rarity
local PetsAssets = Replicated.Assets.Pets
local EggsAssets = Replicated.Assets.Eggs

-- For core pet stuff
local Handling = Replicated.Remotes.Pets.Handling
local Purchasing = Replicated.Remotes.Pets.Purchasing
local Caching = Replicated.Remotes.Pets.Caching
local Emitting = Replicated.Remotes.Pets.Emitting
local Carrying = Replicated.Remotes.Pets.Carrying

-- For visual pet stuff (names)
local Requesting = Replicated.Remotes.Pets.Requesting
local Updating = Replicated.Remotes.Pets.Updating

-- Other
local Notify = Replicated.Remotes.Systems.ServerNotify

-- Pet repository
local PetFolder = Core.PetRepository

-- So other players can monitor changes from the pet | Purely for updating the client // Replace this with a number value
local function Share(Player, Mode, Pet)
	local Shared = DataModule:GetShared(Player)
	
	if Shared then
		if Mode == 'Unequip' then
			DataModule:Set(Player, 'Remove', {
				Shared = true,
				Directory = Shared,
				Key = Core.EquippedShareKey,
				Path = {}
			})
		elseif Mode == 'Equip' then
			DataModule:Set(Player, 'Set', {
				Shared = true,
				Directory = Shared,
				Key = Core.EquippedShareKey,
				Value = Pet,
				Default = 'ObjectValue',
				Path = {}
			})
		end
	end
end

local function Filtered(Player, Nickname)
	local Filtering
	
	local Success, Error = pcall(function()
		Filtering = TextService:FilterStringAsync(Nickname, Player.UserId)
	end)
	
	return Success, Filtering
end

-- Respawn/Leaving/Etc???
local function Equip(PlayerData, Player, Folder, FolderKey, FolderPath, FromEggToPet)
	if PlayerData then
		local Character = Player.Character
		local Equipped = Core['EquippedPets'][Player]
		
		if Equipped and Equipped.Pet then
			Share(Player, 'Unequip')
			Updating:FireAllClients('Unequipped', {Pet = Equipped.Pet})
			
			Growth:Stunt(Player)
			CarryModule:Drop(Player)
			Pathfinder:Unequip(Player)
			
			Equipped.Pet:Destroy()
			Core['EquippedPets'][Player] = nil
		end

		if Character and Folder then
			local Pet, PetInfo = Core:Spawn(Folder)
			Pet.Parent = PetFolder -- Parent before setting the pathfinder, important
			
			-- Now set pathfinding
			local PathfindingInitialized = Pathfinder:Equip(Player, Pet, PetInfo)
			
			if PathfindingInitialized then
				-- Let the user create the pet's tag with a filtered pet name
				local Nickname = Folder.Variables.Nickname
				local Success, FilteringNickname = Filtered(Player, Nickname)
				
				Core['EquippedPets'][Player] = {
					Pet = Pet,
					Folder = Folder,
					Name = (Success and FilteringNickname),
					Size = 1
				}

				Share(Player, 'Equip', Folder)

				for _, FiringPlayer in pairs(Players:GetPlayers()) do
					task.spawn(function()
						Updating:FireClient(FiringPlayer, 'Equipped', {
							Type = 'New',
							Player = Player,
							Key = FolderKey,
							Pet = Pet,
							Folder = Folder,
							Name = (Success and (FilteringNickname:GetNonChatStringForBroadcastAsync() or "####")) or (Folder.Reference.Species)
						})							
					end)
				end

				-- Start the 'growth' process
				task.spawn(function()
					Growth:Grow(Player, PlayerData, Folder, FolderPath)
				end)

				-- Let the client know the pet was equipped
				if not FromEggToPet then
					Emitting:FireClient(Player, 'Equipping', Pet, {_PlayerId = Player.UserId})
				end
				
				-- Return the pet
				return Pet
			else
				Pet:Destroy()
			end
		end
	end
end

Handling.OnServerInvoke = function(Player, Mode, Arguments)
	local PlayerData = DataModule:Get(Player)
	
	if PlayerData then
		local PlayerPets, PlayerPetsPath = PlayerData.Inventory.Pets, DataModule:TableSet('Inventory', 'Pets')
		local ServerConfirmedPet, ConfirmedPath = Core:Confirm(PlayerPets, PlayerPetsPath, Arguments)
		
		if Mode == 'Equipping' then
			if Arguments and type(Arguments) == 'table' and Arguments.Pet then
				if ServerConfirmedPet then
					Equip(PlayerData, Player, ServerConfirmedPet, ConfirmedPath[#ConfirmedPath], ConfirmedPath)
				end
			else
				Equip(PlayerData, Player)
			end
		elseif Mode == 'Selling' then
			if not ServerConfirmedPet then
				return
			elseif Settings:Length(PlayerPets) <= 1  then
				return 'Only'
			end
			
			local RarityFolder = Rarity:FindFirstChild(ServerConfirmedPet.Reference.Rarity)
			local Merit, MeritPath = PlayerData.Merit, {'Merit'}
			
			if RarityFolder then				
				local Value = RarityFolder.Price.Value
				local Equipped = Core['EquippedPets'][Player]
				local Stunting = Equipped and (Equipped.Folder == ServerConfirmedPet)
				
				if Stunting then
					Growth:Stunt(Player)
					Equip(PlayerData, Player)
				end
				
				local Index = Settings:Index(PlayerPets, ServerConfirmedPet)
				
				if Index then
					DataModule:Set(Player, 'Remove', {
						Directory = PlayerPets,
						Key = Index,
						Path = PlayerPetsPath
					})
					
					DataModule:Set(Player, 'Set', {
						Directory = Merit,
						Key = 'Currency',
						Value = Merit.Currency + Settings:Round(Value * Core.ReturnPercentage),
						Default = 'IntValue',
						Path = MeritPath
					})	
					
					return 'Complete'
				end
			end
		elseif Mode == 'Upgrading' then
			if ServerConfirmedPet then
				if Arguments.Statistic and type(Arguments.Statistic) == 'string' then
					local Statistic, StatisticPath = ServerConfirmedPet.Data.Potential, DataModule:TableInsert(ConfirmedPath, 'Data', 'Potential')
					local MaxStatistic = ServerConfirmedPet.Reference.Potential

					if Statistic[Arguments.Statistic] and MaxStatistic[Arguments.Statistic] then
						local Multiplier = Arguments.Multiplier

						if Multiplier and type(Multiplier) == 'number' then
							local Points, PointsPath = ServerConfirmedPet.Data.Points, DataModule:TableInsert(ConfirmedPath, 'Data', 'Points')

							-- Check these next five lines | If the multiplier is greater than what's remaining in that specific stat
							if Multiplier > (MaxStatistic[Arguments.Statistic] - Statistic[Arguments.Statistic]) then
								Multiplier = MaxStatistic[Arguments.Statistic] - Statistic[Arguments.Statistic]
							end
							
							-- If the multiplier is greater than what's remaining in total points
							if Multiplier > Points.Current then
								Multiplier = Points.Current
							end
							
							if (Multiplier > 0) and ((Statistic[Arguments.Statistic] + Multiplier) <= MaxStatistic[Arguments.Statistic]) and (Points.Current >= Multiplier) then								
								DataModule:Set(Player, 'Set', {
									Directory = Points,
									Key = 'Current',
									Value = Points.Current - Multiplier,
									Default = 'IntValue',
									Path = PointsPath
								})
								
								DataModule:Set(Player, 'Set', {
									Directory = Statistic,
									Key = Arguments.Statistic,
									Value = Statistic[Arguments.Statistic] + Multiplier,
									Default = 'IntValue',
									Path = StatisticPath
								}) 

								return true, Statistic[Arguments.Statistic]
							else
								return false, ''
							end
						end
					end
				end
			end
		elseif Mode == 'Renaming' then
			-- Do what was done for other nickname where if length is 0 then it doesn't send request
			if ServerConfirmedPet and Arguments.Name and type(Arguments.Name) == 'string' then	
				if Arguments.Name == "" then
					return false, 'You need to enter a name!'
				elseif #Arguments.Name >= Core.PetNameCharacterCap then
					return false, 'Your name is too long!'
				end
				
				if #Arguments.Name:gsub("%s+", "") == 0 then
					Arguments.Name = ServerConfirmedPet.Reference.Species
				end
				
				local Success, FilteringNickname = Filtered(Player, Arguments.Name)
				
				if Success then
					DataModule:Set(Player, 'Set', {
						Directory = ServerConfirmedPet.Variables,
						Key = 'Nickname',
						Value = Arguments.Name,
						Default = 'StringValue',
						Path = DataModule:TableInsert(ConfirmedPath, 'Variables')
					})
					
					-- Update the existing pet's names
					local Equipped = Core['EquippedPets'][Player]

					if Equipped and Equipped.Folder == ServerConfirmedPet then
						Core['EquippedPets'][Player]['Name'] = FilteringNickname
						
						for _, FiringPlayer in pairs(Players:GetPlayers()) do
							task.spawn(function()
								Updating:FireClient(FiringPlayer, 'Equipped', {
									Type = 'Update',
									Player = Player,
									Pet = Equipped.Pet,
									Folder = Equipped.Folder,
									Size = Equipped.Size,
									Name = FilteringNickname:GetNonChatStringForBroadcastAsync() or "####"
								})							
							end)
						end
					end
					
					local Name = FilteringNickname:GetNonChatStringForBroadcastAsync() or "####"
					return true, Name
				else
					return false, 'Text filtering routine failed.'
				end
			end
		end
	end
end

Purchasing.OnServerInvoke = function(Player, Arguments)
	if not Arguments or type(Arguments) ~= 'table' or not Arguments.Value then
		return
	end
	
	local PlayerData = DataModule:Get(Player)
	
	if PlayerData then
		local PetData, Parameters
		local Merit = PlayerData.Merit
		
		if Arguments.Type == 'Egg' then
			if Settings:SetDebounce(Player, 'PurchaseEgg', 1) then
				PetData = Choice:GetEggData(Arguments.Value)
				Parameters = {Egg = PetData.Egg.Name}
			end
		elseif Arguments.Type == 'Zoo' then
			PetData = Choice:GetAnimalData(Arguments.Value)
			Parameters = {Wild = true}
		end
		
		if PetData then
			if Merit.Currency >= PetData.Price then
				if Inventory:CheckRequirements(PlayerData.Inventory.Pets) then
					DataModule:Set(Player, 'Set', {
						Directory = Merit,
						Key = 'Currency',
						Value = Merit.Currency - PetData.Price,
						Default = 'IntValue',
						Path = {'Merit'}
					})
					
					local PetObject = Core:Create(PetData.Pet.Name, Parameters)
					local Success, AddedPet = Inventory:Add(Player, 'Pets', PetObject)

					if Success then
						-- Not permanent... switch with equipping pet (update in inventory)
						if AddedPet then
							local ServerConfirmedPet, ConfirmedPath = Core:Confirm(PlayerData.Inventory.Pets, DataModule:TableSet('Inventory', 'Pets'), {Pet = AddedPet})

							if ServerConfirmedPet then
								print(ServerConfirmedPet.Reference.Species)
							else
								print('Error locating your egg.')
							end
						else
							print('Egg not purchased... either glitch or lack of money.')
						end
					end
				else
					Notify:FireClient(Player, 'The maximum number of pets you can store is ' .. tostring(Inventory.Settings.MaxItemsPerCategory) .. '.')
				end
			end
		end
	end
end

Requesting.OnServerInvoke = function(Player, Total)
	local PetTable = {}
	
	for Reference, Equipped in pairs(Core['EquippedPets']) do
		table.insert(PetTable, {
			Player = Total and Reference,
			Pet = Equipped.Pet,
			Folder = Total and Equipped.Folder,
			Name = Total and (Equipped.Name and (Equipped.Name:GetNonChatStringForBroadcastAsync() or "####")) or (Equipped.Folder.Reference.Species),
			Size = Equipped.Size
		})
	end
	
	return PetTable
end

Caching.OnServerInvoke = function(Player)
	if not Settings:SetDebounce(Player, 'CachePetInfo', 2) then
		return
	end
	
	return {
		Stages = Core.Stages,
		DefaultEggs = Core.DefaultEggs,
		Experience = Core.Experience,
		Max = Core.Max,
		Breedable = Core.Breedable,
		ReturnPercentage = Core.ReturnPercentage,
		Constraints = Core.Constraints,
		PetsCurrentlyScaledTo = Core.PetsCurrentlyScaledTo
	}
end

Carrying.OnServerEvent:Connect(function(Player, Mode)
	if Mode == 'Carry' then
		local PetEquippedDetails = Core['EquippedPets'][Player]

		if PetEquippedDetails then
			local Stage = PetEquippedDetails.Folder.Data.Stage
			local Folder
			
			if Core['Stages'][Stage]['Stage'] == 'Egg' then
				Folder = EggsAssets:FindFirstChild(PetEquippedDetails.Folder.Reference.Egg)
			else
				Folder = PetsAssets:FindFirstChild(PetEquippedDetails.Folder.Reference.Species)
			end

			if Folder then
				CarryModule:Carry(Player, PetEquippedDetails.Pet, Folder)
			end
		end
	elseif Mode == 'Drop' then
		local PetEquippedDetails = Core['EquippedPets'][Player]
		local EquippedPet = PetEquippedDetails and PetEquippedDetails.Pet

		CarryModule:Drop(Player)
	end
end)

Core.EggTransitionBindable.OnInvoke = function(Player, PetIndex)
	local PlayerData = DataModule:Get(Player)
	
	-- We have to essentially 'reindex' the pet because sending a table through a bindable duplicates it and disregards the original version, so can't send pet
	-- folder as a parameter
	if PlayerData then
		local PlayerPets, PlayerPetsPath = PlayerData.Inventory.Pets, DataModule:TableSet('Inventory', 'Pets')
		local ServerConfirmedPet, ConfirmedPath = Core:Confirm(PlayerPets, PlayerPetsPath, {Pet = PetIndex})
		
		if ServerConfirmedPet then
			return Equip(PlayerData, Player, ServerConfirmedPet, ConfirmedPath[#ConfirmedPath], ConfirmedPath, true)
		end
	end
end

-- Events
Players.PlayerAdded:Connect(function(Player)
	-- Everytime player dies, the drop button shouldn't be on their screen
	Player.CharacterAdded:Connect(function()
		CarryModule:Drop(Player)
	end)
end)

-- Spawn GUI over them currently in StarterGui
-- LIMIT EVERY REMOTE