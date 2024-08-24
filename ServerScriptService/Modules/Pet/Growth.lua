local SSS = game:GetService('ServerScriptService')
local Storage = game:GetService('ServerStorage')
local Replicated = game:GetService('ReplicatedStorage')

local Core = require(script.Parent.Core)
local Settings = require(Replicated.Modules.Utility.Settings)
local DataModule = require(SSS.Modules.Data.Consolidate)
local Inventory = require(SSS.Modules.Inventory.Core)

local Emitting = Replicated.Remotes.Pets.Emitting
local ServerChat = Replicated.Remotes.Other.ServerChat
local Rarities = Replicated.Assets.Rarity

local Stop = Storage.Bindables.Pet.Stunt
local PetFolder = Core.PetRepository

local PetGrowthModule = {}
local HighestRarity

local function GetHighestRarity(Rarities)
	local HighestRank = -1
	
	for _, Rarity in pairs(Rarities:GetChildren()) do
		local Rank = Rarity.Rank.Value
		
		if Rank > HighestRank then
			HighestRank, HighestRarity = Rank, Rarity.Name
		end
	end
end

local function Gather(PetPotential)
	local Total = 0

	for Name, Potential in pairs(PetPotential) do
		Total += Potential
	end
	
	return Total
end

local function Share(Player, Changing)
	local Shared = DataModule:GetShared(Player)

	if Shared then
		local Equipped = Shared[Core.EquippedShareKey]

		if Equipped then
			DataModule:Set(Player, 'Update', {
				Shared = true,
				Directory = Equipped.Data,
				Key = Changing,
				Path = {Core.EquippedShareKey, 'Data'}
			})
		end
	end
end

-- Do a global function instead of 1 by 1
function PetGrowthModule:Grow(Player, PlayerData, Pet, PetPath)
	local Active = true
	PetGrowthModule:Stunt(Player)
	
	Stop.Event:Connect(function(StoppedPlayer)
		Active = (StoppedPlayer ~= Player)
	end)
	
	while true do
		task.wait(1) -- Consider rate variable and every 2 or 3 seconds
		
		local Equipped = Core['EquippedPets'][Player]
		
		if Active == true and (Equipped and Equipped.Pet and Equipped.Pet.Parent == PetFolder) then
			local Data, DataPath = Pet.Data, DataModule:TableInsert(PetPath, 'Data') -- Errored for not finding data after leveling up
			
			DataModule:Set(Player, 'Set', {
				Directory = Data,
				Key = 'Experience',
				Value = Data.Experience + 1,
				Default = 'IntValue',
				Path = DataPath
			})
			
			Share(Player, 'Experience')
			
			if not Core.Stages[Data.Stage].Experience then
				print('This pet is an adult.')
				-- Either something has gone horribly wrong or it's an adult
				DataModule:Set(Player, 'Set', {
					Directory = Data,
					Key = 'Experience',
					Value = 0,
					Default = 'IntValue',
					Path = DataPath,
				})
				
				Share(Player, 'Experience')

				local Max, Min = Settings:iMax(Core.Stages), Settings:iMin(Core.Stages)
				
				if Data.Stage > Max then
					Data.Stage = Max
				elseif Data.Stage < Min then
					Data.Stage = Min
				end
				
				return
			elseif Data.Experience >= Settings:Round((Core.Stages[Data.Stage].Experience / 100) * Core.Experience[Pet.Reference.Rarity]) then
				local IsAnEgg = (Core['Stages'][Data.Stage]['Stage'] == 'Egg')
				
				-- We update the inventory id first so by the time the client re-renders the egg as a pet it is already set, 
				-- if we placed this after the stage changes it would lead to race conditions
				if IsAnEgg then
					Inventory:UpdateInventoryId(Player, 'Pets', PetPath[#PetPath])
				end
				
				DataModule:Set(Player, 'Set', {
					Directory = Data,
					Key = 'Experience',
					Value = 0,
					Default = 'IntValue',
					Path = DataPath
				})
				
				Share(Player, 'Experience')

				DataModule:Set(Player, 'Set', {
					Directory = Data,
					Key = 'Stage',
					Value = Data.Stage + 1,
					Default = 'IntValue',
					Path = DataPath
				})
				
				Share(Player, 'Stage')
				
				-- Assign them their points
				local Attributing
				
				if Data.Stage == Settings:iMax(Core.Stages) then
					Attributing = Data.Points.Total -- Give them the rest essentially
				else
					Attributing = math.floor(Gather(Pet.Reference.Potential) / (Settings:Length(Core.Stages) - 1))
				end
			
				DataModule:Set(Player, 'Set', {
					Directory = Data.Points,
					Key = 'Current',
					Value = Data.Points.Current + Attributing,
					Default = 'IntValue',
					Path = DataModule:TableInsert(DataPath, 'Points')
				})
				
				DataModule:Set(Player, 'Set', {
					Directory = Data.Points,
					Key = 'Total',
					Value = Data.Points.Total - Attributing,
					Default = 'IntValue',
					Path = DataModule:TableInsert(DataPath, 'Points')
				})
				
				-- Give them money for their pet leveling up | This needs aesthetics for the money
				local Merit = PlayerData.Merit
				
				DataModule:Set(Player, 'Set', {
					Directory = Merit,
					Key = 'Currency',
					Value = Merit.Currency + (10 * (Data.Stage - 1)), -- You can randomize this a bit too and is the stage part correct? / handle aesthetics
					Default = 'IntValue',
					Path = {'Merit'}
				})
				
				if IsAnEgg then
					local Rarity = Pet.Reference.Rarity
					local Nickname = Pet.Variables.Nickname
					local Egg = Pet.Reference.Egg
					
					-- Name needs to be change BEFORE transition occurs so it replicates to all the clients. If they haven't changed their name
					-- since an egg, we change it to the species name
					if (string.lower(Nickname) == string.lower(Egg)) then
						local Species = Pet.Reference.Species

						DataModule:Set(Player, 'Set', {
							Directory = Pet.Variables,
							Key = 'Nickname',
							Value = Species,
							Path = DataModule:TableInsert(PetPath, 'Variables')
						})
					end
					
					-- Make the physical transition, we yield until it's completed and then send the remote
					local Model = Core.EggTransitionBindable:Invoke(Player, PetPath[#PetPath])
										
					-- Send remote to transition on the clients and notify the client if they just hatched a legendary
					if (Rarity == HighestRarity) then
						local Generation = Pet.Reference.Generation

						if (Generation <= 1) then
							ServerChat:FireAllClients({
								Text = Player.Name .. ' just hatched a ' .. Rarity .. ' pet!',
								Rainbow = true
							})
						end
						
						Emitting:FireAllClients('HighRankTransitioning', Model, {_PlayerId = Player.UserId, Species = Pet.Reference.Species})
					else
						Emitting:FireAllClients('Transitioning', Model, {_PlayerId = Player.UserId, Species = Pet.Reference.Species})
					end
				else
					-- This might need to be corrected and tested with new system
					local StageSizing = {
						Current = Core.Stages[Data.Stage].Size,
						Previous = Core.Stages[Data.Stage - 1].Size
					}

					local GeneticsSized = (Core.Constraints.Minimum + (Pet.Reference.Size / 100))
					local GeneticsBased = GeneticsSized <= Core.Constraints.Maximum and GeneticsSized or Core.Constraints.Maximum

					local Size = Core:Rescale((math.pow(Core:Rescale(1), -1) / (StageSizing.Previous * GeneticsBased)) * (GeneticsBased * StageSizing.Current))
					Equipped.Size *= Size
					
					Emitting:FireAllClients('Leveling', Equipped.Pet, {Size = Size, Species = Pet.Reference.Species})
				end
			end
		else
			return
		end
	end
end

function PetGrowthModule:Stunt(Player)
	Stop:Fire(Player)
end

-- Main sequence
GetHighestRarity(Rarities)

-- Optimization? Probably by holding all pets in a list and doing all at once
return PetGrowthModule