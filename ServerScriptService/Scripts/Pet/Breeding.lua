-- The reason we don't use Pet:GetAttribute() here is because eggs are declined in this system (from both the client and server)

local SSS = game:GetService('ServerScriptService')
local Players = game:GetService('Players')
local Replicated = game:GetService('ReplicatedStorage')

-- Remotes
local BreedHandling = Replicated.Remotes.Breed.Handle
local Emitting = Replicated.Remotes.Pets.Emitting

-- Modules
local DataModule = require(SSS.Modules.Data.Consolidate)
local InventoryModule = require(SSS.Modules.Inventory.Core)
local Settings = require(Replicated.Modules.Utility.Settings)
local System = require(SSS.Modules.Systems.Exchange)

local Core = require(SSS.Modules.Pet.Core)
local Breed = require(SSS.Modules.Pet.Breed)

-- Breeding functions
local function BreedUpdate(Information, Object, Unconfirming)
	if Information then
		local Items = {}
		local PriceCheckingSet = {}

		for _, Client in pairs(Information.Players) do
			if Client.Items then
				local EquippedPet = Core['EquippedPets'][Client.Player] and Core['EquippedPets'][Client.Player]['Folder']
				
				table.insert(Items, Client.Items)
				table.insert(PriceCheckingSet, {Pet = Client.Items, Equipped = EquippedPet})
			end
		end

		local Price = Breed:GetBreedPrice(PriceCheckingSet)
		local Valid = Breed:CheckRequirements(Items, Information.Self)

		if Information.Self then
			BreedHandling:FireClient(Information.Self.Player, 'Update', {
				Player = Object.Player,
				Items = Object.Items,
				Confirmed = Information.Self.Confirmed.Preliminary,
				Unconfirming = Unconfirming,
				Price = Price,
				Valid = Valid,
				Relative = Object.Role,
			})
		else
			for _, Client in pairs(Information.Players) do
				BreedHandling:FireClient(Client.Player, 'Update', {
					Player = Object.Player,
					Items = Object.Items,
					Confirmed = Object.Confirmed.Preliminary,
					Unconfirming = Unconfirming,
					Price = Price,
					Valid = Valid,
				})
			end
		end
	end
end

local function BreedDecline(Player, Arguments)
	local Breeders = System:Conclude(Player, Arguments.Id)

	if Breeders then
		if Breeders.Self then
			BreedHandling:FireClient(Breeders.Self.Player, 'Declined')
		else
			for _, Client in pairs(Breeders) do
				if Client == Player then
					BreedHandling:FireClient(Client, 'Declined')
				else
					BreedHandling:FireClient(Client, 'Declined', {Message = Player.Name .. ' has canceled the breeding session.'})
				end
			end
		end
	end
end

-- Whenever a requirement is added wrap all if statements with a 'return false' given a requirement is violated
local function BreedComplete(Information, PlayerData, Price)
	if PlayerData then
		local Currency, PetsInventory = PlayerData.Merit.Currency, PlayerData.Inventory.Pets
		
		if Currency < Price then
			if Information.Self then
				return false, "You do not have sufficient cash to breed those pets."
			else
				return false, "Both players do not have sufficient cash to breed those pets."
			end
		end
		
		if not InventoryModule:CheckRequirements(PetsInventory) then
			if Information.Self then
				return false, "You have reached the max limit of " .. InventoryModule.Settings.MaxItemsPerCategory .. " pets in your inventory."
			else
				return false, "One or both players have reached the max limit of " .. InventoryModule.Settings.MaxItemsPerCategory .. " pets in their inventory."
			end
		end
		
		return true, PlayerData
	else
		return false, "An unexpected error has occured."
	end
end

BreedHandling.OnServerEvent:Connect(function(Player, Action, Arguments)
	local PlayerData = DataModule:Get(Player)

	if PlayerData and (Arguments and type(Arguments) == 'table') then
		if Action == 'Initiate' then
			local Other = Arguments.Other and Players:FindFirstChild(Arguments.Other)

			if Other then
				-- Can't send a request if you're in a session or that person is in a session
				local CurrentOther, CurrentSelf = System:LocatePlayer(Other, true), System:LocatePlayer(Player, true)

				if CurrentOther then
					if CurrentOther == CurrentSelf then
						BreedHandling:FireClient(Player, nil, {Message = "You're already in a breeding session."})
					else
						BreedHandling:FireClient(Player, nil, {Message = Arguments.Other .. ' is in another breeding session.'})
					end

					return
				elseif CurrentSelf then
					BreedHandling:FireClient(Player, nil, {Message = "You're already in a breeding session."})
					return
				end

				local On, Time = System:OnBlacklist(Player, Other, 'Breed')

				if On then
					BreedHandling:FireClient(Player, nil, {Message = "Please wait " .. Time .. " seconds before requesting this player again."})
					return
				else
					System:SetBlacklist(Player, Other, 'Breed')
				end

				local Created = System:Create(Player, Other, 'Breed')

				if Created then
					if Created.Self then
						local Valid, Information = System:Commence(Player, Created.Id)

						if Valid then
							BreedHandling:FireClient(Information.Self.Player, 'Commence', {Other = nil, Id = Created.Id})
						end
					else
						BreedHandling:FireClient(
							System:GetRequested(Created.Id), 
							'Request',
							{Player = System:GetRequestor(Created.Id), Id = Created.Id}
						)
					end
				end
			end
		elseif Action == 'Respond' then
			if Arguments.Option == true then
				local Previous, EngagedPlayer = System:Check(Player, Arguments.Id)

				if Previous then
					if (EngagedPlayer == Player) then
						BreedHandling:FireClient(Player, nil, {Message = "You're already in a breeding session."})
					else
						BreedHandling:FireClient(Player, nil, {Message = EngagedPlayer.Name .. ' is in another breeding session.'})
					end

					return
				end

				local Valid, Information = System:Commence(Player, Arguments.Id)

				if Valid == 1 then
					for _, Object in pairs(Information.Players) do
						local Others = {}

						for _, Other in pairs(Information.Players) do
							if Other.Player ~= Object.Player then
								table.insert(Others, Other.Player)
							end
						end

						BreedHandling:FireClient(Object.Player, 'Commence', {Other = Others, Id = Arguments.Id})
					end
				elseif Valid == 0 then
					BreedHandling:FireClient(Information, nil, {Message = "The breed request has expired."})
				elseif Valid == -1 then
					BreedHandling:FireClient(Player, nil, {Message = "The requested player has left the server."})
				end
			else
				local ModifiedInformation = System:Conclude(Player, Arguments.Id)

				if ModifiedInformation then
					BreedHandling:FireClient(ModifiedInformation.Requestor, nil, {Message = ModifiedInformation.Requested.Name .. ' has declined your request.'})
				end
			end
		elseif Action == 'Update' then
			local PlayerPets, PlayerPetsPath = PlayerData.Inventory.Pets, DataModule:TableSet('Inventory', 'Pets')
			local Confirmed = Core:Confirm(PlayerPets, PlayerPetsPath, {Pet = Arguments.Pet})
			
			if Confirmed then
				-- You can't breed with eggs
				local Stage = Confirmed.Data.Stage
				
				if not Stage or Core['Stages'][Stage]['Stage'] == 'Egg' then
					return
				end

				local Object, Information, Success = System:Add(Player, Confirmed, Arguments.Id, Arguments.Relative)

				if Information then
					if Success then
						BreedUpdate(Information, Object, true)
					else
						-- Insufficient
						BreedHandling:FireClient(Object.Player, nil, {Message = "You cannot breed two of the same pets."})
						return
					end
				end
			end
		elseif Action == 'Confirm' then
			local MicroAction, Object, Information = System:Confirm(Player, Arguments.Value, Arguments.Id)

			if Information then
				if MicroAction == 'Update' then
					BreedUpdate(Information, Object)
				elseif MicroAction == 'Preliminary' then
					-- This should fire one event instead of two: perhaps preliminary should return confirm information for client
					BreedUpdate(Information, Object)

					if Information.Self then
						BreedHandling:FireClient(Information.Self.Player, 'Preliminary')
					else
						for _, Client in pairs(Information.Players) do
							BreedHandling:FireClient(Client.Player, 'Preliminary')
						end
					end
				elseif MicroAction == 'Insufficient' then
					BreedHandling:FireClient(Object.Player, 'Insufficient', {Message = "Please offer a pet before being ready."})
					return
				elseif MicroAction == 'Completed' then
					local BreedingPlayers = {}
					
					-- This segment confirms you have pets in the item cache and adds pets and final 
					-- breed data to the tables
					for _, Client in pairs(Information.Players) do
						local PlayerData = DataModule:Get(Client.Player)

						if PlayerData then
							-- This system is very insecure for table objects - it would be difficult to implement
							-- well with trade system, easy to duplicate unless you store KEYS | Consider doing that
							-- for this too (And send to client with keys figured out since they don't have replication)
							
							local PlayerPets, PlayerPetsPath = PlayerData.Inventory.Pets, DataModule:TableSet('Inventory', 'Pets')
							local PetFound -- Should use Core:Confirm(PlayerPets, PlayerPetsPath, {Pet = Client.Items}) when using keys
							
							for _, Pet in pairs(PlayerPets) do
								if Pet == Client.Items then
									PetFound = true
									break
								end
							end

							if Client.Items and PetFound then
								local PlayerData = DataModule:Get(Client.Player)
								local EquippedPet = Core['EquippedPets'][Client.Player] and Core['EquippedPets'][Client.Player]['Folder']
								
								table.insert(BreedingPlayers, {Pet = Client.Items, Data = PlayerData, Player = Client.Player, Equipped = EquippedPet})
							else
								if Information.Self then
									BreedHandling:FireClient(Object.Player, 'Unconfirm', {Message = 'Error collecting pets. Please try again later.'})
								else
									for _, Client in pairs(Information.Players) do
										BreedHandling:FireClient(Client.Player, 'Unconfirm', {Message = 'Error collecting pets. Please try again later.'})
									end
								end

								System:Unconfirm(Object.Player, Arguments.Id)
								return
							end
						end
					end
					
					-- This segment confirms that the prices of the pets can be collected and used and then
					-- saves it in a variable
					local Price = Breed:GetBreedPrice(BreedingPlayers)
					
					if not Price then
						if Information.Self then
							BreedHandling:FireClient(Object.Player, 'Unconfirm', {Message = "Pricing error has occurred."})
						else
							for _, Client in pairs(Information.Players) do
								BreedHandling:FireClient(Client.Player, 'Unconfirm', {Message = "Pricing error has occurred."})
							end
						end

						System:Unconfirm(Object.Player, Arguments.Id)
						return
					end
					
					
					-- Does the final checks before resuming the main thread to process
					for _, BreedingInformation in pairs(BreedingPlayers) do
						local Success, Value = BreedComplete(Information, BreedingInformation.Data, Price)
						
						if not Success then
							for _, BreedingInformation in pairs(BreedingPlayers) do
								BreedHandling:FireClient(BreedingInformation.Player, 'Unconfirm', {Message = Value})
								
								-- So it only sends to you once
								if Information.Self then
									break
								end
							end
							
							System:Unconfirm(Object.Player, Arguments.Id)
							return
						end
						
						-- So it doesn't evaluate one player twice
						if Information.Self then
							break
						end
					end
					
					-- This segment handles the breeding
					local Success, Error = Breed:Form(BreedingPlayers, Information.Self)
					
					if Success then
						for _, BreedSuccess in pairs(Success) do
							local BreedData = BreedSuccess.Data
							
							if BreedData then
								DataModule:Set(BreedSuccess.Player, 'Set', {
									Directory = BreedData.Merit,
									Key = 'Currency',
									Value = BreedData.Merit.Currency - Price,
									Default = 'IntValue',
									Path = {'Merit'}
								})
								
								-- Just equips the last pet in the table since you can't equip all duplications
								local PetToEquip
								
								-- Don't bother checking for requirements or anything because we already did above and
								-- if they happen to get twins, triplets, etc, while at 199 inventory space then they
								-- wouldn't get to keep it. The last parameter for the add() ignores the max inventory requirement
								for _, Pet in pairs(BreedSuccess.Pets) do
									_, PetToEquip = InventoryModule:Add(BreedSuccess.Player, 'Pets', Pet, true)
								end
								
								if PetToEquip then
									local ServerConfirmedPet, ConfirmedPath = Core:Confirm(BreedData.Inventory.Pets, DataModule:TableSet('Inventory', 'Pets'), {Pet = PetToEquip})
									
									if ServerConfirmedPet then
										-- Equip pet here
										print(ServerConfirmedPet.Reference.Species)
									else
										print('Error locating your bred pet.')
									end
								else
									print('Pet not acquired... seems to be a glitch.')
								end
								
								local AmountOfPets, DuplicationType = Settings:Length(BreedSuccess.Pets), (BreedSuccess.DuplicationType and string.lower(BreedSuccess.DuplicationType))
								
								if AmountOfPets >= 5 then
									BreedHandling:FireClient(BreedSuccess.Player, 'Completed', {Message = "Wow! You've just got a bundle of " .. (DuplicationType and DuplicationType .. ' ' or '') .. "pets, congratulations.", IsMessageImportant = true})
								elseif AmountOfPets >= 4 then
									BreedHandling:FireClient(BreedSuccess.Player, 'Completed', {Message = "Wow! You've just got " .. (DuplicationType and DuplicationType .. ' ' or '') .. "quadruplets, congratulations.", IsMessageImportant = true})
								elseif AmountOfPets >= 3 then
									BreedHandling:FireClient(BreedSuccess.Player, 'Completed', {Message = "Wow! You've just got " .. (DuplicationType and DuplicationType .. ' ' or '') .. "triplets, congratulations.", IsMessageImportant = true})
								elseif AmountOfPets >= 2 then
									BreedHandling:FireClient(BreedSuccess.Player, 'Completed', {Message = "Wow! You've just got " .. (DuplicationType and DuplicationType .. ' ' or '') .. "twins, congratulations.", IsMessageImportant = true})
								elseif AmountOfPets >= 1 then
									BreedHandling:FireClient(BreedSuccess.Player, 'Completed', {Message = "Congratulations on successfully breeding!"})
								end
								
								-- If the player's pet is equipped then play the particle
								local PlayerEquipData = Core['EquippedPets'][BreedSuccess.Player]
								
								if PlayerEquipData then
									local IsEquipped = false
									
									for _, Information in pairs(BreedingPlayers) do
										if Information.Pet == PlayerEquipData.Folder then
											IsEquipped = true
											break
										end
									end
									
									if IsEquipped then
										Emitting:FireClient(BreedSuccess.Player, 'Breeding', PlayerEquipData.Pet)
									end
								end
							end
						end

						System:Conclude(Player, Arguments.Id)
					else
						for _, BreedingInformation in pairs(BreedingPlayers) do
							BreedHandling:FireClient(BreedingInformation.Player, 'Unconfirm', {Message = Error})

							-- So it only sends to you once
							if Information.Self then
								break
							end
						end

						System:Unconfirm(Object.Player, Arguments.Id)
						return
					end
				elseif MicroAction == 'Decline' then
					if Information.Self then
						BreedHandling:FireClient(Object.Player, 'Unconfirm')
					else
						for _, Client in pairs(Information.Players) do
							if Client.Player == Player then
								BreedHandling:FireClient(Client.Player, 'Unconfirm')
							else
								BreedHandling:FireClient(Client.Player, 'Unconfirm', {Message = Player.Name .. ' has declined the offer.'})
							end
						end
					end					

					System:Unconfirm(Object.Player, Arguments.Id)
					return					
				end
			end
		elseif Action == 'End'	then
			BreedDecline(Player, Arguments)
		end
	end
end)

Players.PlayerRemoving:Connect(function(Player)
	-- First get the session they're immediately in and decline it
	local Id = System:LocatePlayer(Player, true)

	if Id then
		local Current = System:Retrieve(Id)

		if Current then
			if not Current.Self then
				for _, Client in pairs(Current.Players) do
					if Client.Player ~= Player then
						BreedHandling:FireClient(Client.Player, 'Declined', {Message = Player.Name .. ' has left the server.'})
					end
				end
			end

			System:Conclude(Player, Id)
		end
	end

	-- Then get all the other sessions they are in
	local Transactions = System:LocatePlayer(Player)

	if Transactions then
		for _, Transaction in pairs(Transactions) do
			System:Conclude(Player, Transaction)
		end
	end
end)

-- Stresstest this system with thirty people
