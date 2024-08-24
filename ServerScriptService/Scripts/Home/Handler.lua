local Replicated = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local TextService = game:GetService('TextService')
local Players = game:GetService('Players')

local DataModule = require(ServerScriptService.Modules.Data.Consolidate)
local HomesData = require(Replicated.Modules.Home.Core)
local HomesModule = require(ServerScriptService.Modules.Home.Core)

local Settings = require(Replicated.Modules.Utility.Settings)

local Purchasing = Replicated.Remotes.Home.Purchasing
local Renaming = Replicated.Remotes.Home.Renaming
local Handling = Replicated.Remotes.Home.Handling
local Locking = Replicated.Remotes.Home.Locking
local Coloring = Replicated.Remotes.Home.Coloring

local Notify = Replicated.Remotes.Systems.ServerNotify

local function FormatData(Player, Saved, Corrections)
	if Corrections.NoHomeFolder then
		print('Found no home folder')
		DataModule:Set(Player, 'Set', {
			Directory = Saved,
			Key = 'Homes',
			Value = {}
		})
		
		DataModule:Set(Player, 'Insert', {
			Directory = Saved,
			Key = 'Homes',
			Value = HomesModule:ReturnStarterHome(),
		})
	elseif Corrections.NoOwnedHome then
		print('Found no owned home')
		DataModule:Set(Player, 'Insert', {
			Directory = Saved,
			Key = 'Homes',
			Value = HomesModule:ReturnStarterHome(),
		})
	else
		if Corrections.InvalidHomes then
			print('Found some invalid homes')
			for _, HomeKey in pairs(Corrections.InvalidHomes) do
				DataModule:Set(Player, 'Remove', {
					Directory = Saved.Homes,
					Key = HomeKey,
					Path = {'Homes'}
				})
			end
		end
		
		if Corrections.NoDefaultHome then
			for Index, Home in pairs(Saved.Homes) do
				print('Found no default home')
				DataModule:Set(Player, 'Set', {
					Directory = Saved['Homes'][Index],
					Key = 'Default',
					Value = true,
					Path = DataModule:TableSet('Homes', Index),
				})
				
				break
			end
		end
	end
end

-- Manual: Player manually switches their homes using equipped
-- Forced: Player is forced to switch because they sold their home
local function EquippingHome(Player, Data, Home, Key, Manual, Forced)
	-- If already equipped, don't bother
	if Home.Default then
		return
	end
	
	if Settings:SetDebounce(Player, 'SpawnHome', HomesModule.SpawnCooldown) or Forced then
		-- Remove all other potentially equipped homes
		for Index, Home in pairs(Data.Homes) do
			if Home.Default then
				DataModule:Set(Player, 'Remove', {
					Directory = Data['Homes'][Index],
					Key = 'Default',
					Path = DataModule:TableSet('Homes', Index)
				})
			end
		end

		-- Set the new 'default home'
		DataModule:Set(Player, 'Set', {
			Directory = Data['Homes'][Key],
			Key = 'Default',
			Value = true,
			Path = DataModule:TableSet('Homes', Key)
		})

		-- And now to initialize the actual home object
		HomesModule:SetHome(Player, Data.Homes, Manual)
		return true
	elseif Manual then
		Notify:FireClient(Player, 'Please wait some time before equipping another home.')
	end
end

local function PlayerAdded(Player)
	local PlayerName = Player.Name
	local Saved
	
	repeat
		Saved = DataModule:Get(Player)
		task.wait(1)
	until (Saved or not Players:FindFirstChild(PlayerName))
	
	if Saved then
		FormatData(Player, Saved, HomesModule:Format(Saved.Homes))
		HomesModule:SetHome(Player, Saved.Homes)
	end
end

local function PlayerRemoving(Player)
	HomesModule:ReleaseHome(Player)
end

Purchasing.OnServerInvoke = function(Player, HomeName)
	local HomeDetails = HomesData['Homes'][HomeName]
	
	if not HomeDetails then
		return
	end
	
	local Data = DataModule:Get(Player)
	
	if Data and Settings:SetDebounce(Player, 'PurchaseHome', 0.5) then		
		if Settings:Length(Data.Homes) < HomesModule.PlayerHomeCap then
			local MeritPath, Merit = {'Merit'}, Data.Merit
			
			if (Merit.Currency - HomeDetails.Price) >= 0 then
				DataModule:Set(Player, 'Set', {
					Directory = Merit,
					Key = 'Currency',
					Value = Merit.Currency - HomeDetails.Price,
					Path = MeritPath
				})
				
				local PurchasedHome = HomesModule:ReturnNewHome(HomeName)

				local PurchasedHomeKey = DataModule:Set(Player, 'Insert', {
					Directory = Data,
					Key = 'Homes',
					Value = PurchasedHome,
				})
				
				EquippingHome(Player, Data, PurchasedHome, PurchasedHomeKey)
				return 'Success'
			end
		else
			return 'Excessive'
		end
	end
end

Handling.OnServerInvoke = function(Player, Mode, Key)
	local Data = DataModule:Get(Player)

	if Data then
		if not Key or type(Key) ~= 'string' then
			return
		end
		
		local Home = Data['Homes'][Key]
		
		if Home then
			local HomeDetails = HomesData['Homes'][Home.Type]
			
			if HomeDetails then
				if Mode == 'Selling' then
					if Settings:SetDebounce(Player, 'SellHome', 0.5) then
						if Settings:Length(Data.Homes) > HomesModule.PlayerHomeMinimum then
							local Merit = Data.Merit
							local EquippedHome = Home.Default
							
							-- Now actually destroy the home using the module
							DataModule:Set(Player, 'Set', {
								Directory = Merit,
								Key = 'Currency',
								Value = Merit.Currency + math.round(HomeDetails.Price * HomesData.SellPercentage),
								Path = DataModule:TableSet('Merit')
							})

							DataModule:Set(Player, 'Remove', {
								Directory = Data.Homes,
								Key = Key,
								Path = {'Homes'}
							})
							
							-- Sets to the next available home if that was the home equipped
							if EquippedHome then							
								for Index, Home in pairs(Data.Homes) do
									EquippingHome(Player, Data, Home, Index, false, true)
									break
								end
							end
							
							return true
						else
							Notify:FireClient(Player, "You can't sell your only home.")
						end
					end
				elseif Mode == 'Equipping' then
					return EquippingHome(Player, Data, Home, Key, true)
				end
			end
		end
	end
end

Locking.OnServerInvoke = function(Player)
	local Data = DataModule:Get(Player)
	
	if Data and Settings:SetDebounce(Player, 'LockHome', 0.75) then
		return HomesModule:ToggleLock(Player, Data.Homes)
	end
end

Renaming.OnServerInvoke = function(Player, Key, Name)
	local Data = DataModule:Get(Player)
	
	if Data then
		if not Key or type(Key) ~= 'string' then
			return
		elseif not Name or type(Name) ~= 'string' then
			return
		end
		
		local Home = Data['Homes'][Key]
		
		if Home then
			if Settings:SetDebounce(Player, 'RenameHome', 0.5) then
				if #Name <= HomesModule.RenameTextLimit then
					if #Name:gsub("%s+", "") <= 0 then
						Name = Home.Type
					end
					
					local Filtered

					local Success, Error = pcall(function()
						Filtered = TextService:FilterStringAsync(Name, Player.UserId)
					end)
					
					local FilteredName = Filtered:GetNonChatStringForUserAsync(Player.UserId) or '####'

					if Success then
						DataModule:Set(Player, 'Set', {
							Directory = Data['Homes'][Key],
							Key = 'Name',
							Value = FilteredName,
							Path = DataModule:TableSet('Homes', Key)
						})
						
						return true, FilteredName
					end
				end
			end
		end
	end
end

Coloring.OnServerEvent:Connect(function(Player, Type, Color)
	if not Type or type(Type) ~= 'string' then
		return
	elseif not Color or type(Color) ~= 'userdata' or typeof(Color) ~= 'Color3' then
		return
	end
		
	local Data = DataModule:Get(Player)
	
	if Data and Data.Homes then
		local Key, Default = HomesModule:FetchDefault(Data.Homes)
		
		if Default then
			if HomesData['MutableColors'][Type] and Settings:SetDebounce(Player, 'ColorHome', 0.5) then
				if Default.Colors then
					DataModule:Set(Player, 'Set', {
						Directory = Data['Homes'][Key]['Colors'],
						Key = Type,
						Value = Settings:FromColor(Color),
						Path = DataModule:TableSet('Homes', Key, 'Colors')
					})
				else
					local Colors = {}
					Colors[Type] = Settings:FromColor(Color)
					
					DataModule:Set(Player, 'Set', {
						Directory = Data['Homes'][Key],
						Key = 'Colors',
						Value = Colors,
						Path = DataModule:TableSet('Homes', Key)
					})
				end
				
				HomesModule:RecolorHome(Player, Default.Colors)
			end
		end
	end
end)

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

for _, Player in pairs(Players:GetPlayers()) do
	task.spawn(function()
		PlayerAdded(Player)
	end)
end

--[[
Home Data Formatting:

Home = {
	Type = 'Starter',
	Default = false,
	Name = 'Starter',
	Colors = {
		Interior = {...},
		Exterior = {...}
	},
}
]]
