local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Settings = require(Replicated.Modules.Utility.Settings)

local CoreSystem = {
	Configuration = {
		Breed = {
			Expiration = 45,
			Blacklist = 20,
			MaxItems = 1,
			NeedsAnItem = true,
			Self = true,
		},
		
		Trade = {
			Expiration = 45,
			Blacklist = 20,
			MaxItems = 5,
			NeedsAnItem = false,
			Self = false,
		},
	},
	
	Servicing = {
		-- Will contain list of things
	},
	
	Blacklist = {
		-- Will contain blacklist: spawned to remove
	},
	
	Key = 0,
}

local function IndexId(Id)
	for Index, Action in pairs(CoreSystem.Servicing) do
		if Action.Id == Id then
			return Index
		end
	end
end

-- Ehh??? Or works?
local function GetToggle(Id, Type)
	local Found = CoreSystem:Retrieve(Id)

	if Found then
		for _, Object in pairs(Found.Players) do
			if Object['Confirmed'][Type] ~= true then
				return
			end
		end
		
		return true
	end
end

local function Toggle(Id, Type, Value)
	local Found = CoreSystem:Retrieve(Id)

	if Found then
		for _, Object in pairs(Found.Players) do
			Object['Confirmed'][Type] = Value
		end
	end
end

function CoreSystem:GetRequestor(Id, Info)
	local Found = CoreSystem:Retrieve(Id)
	
	if Found then
		for _, Object in pairs(Found.Players) do
			if Object.Role == 'Requestor' then
				return (Info and Object) or Object.Player
			end
		end
	end
end

function CoreSystem:GetRequested(Id, Info)
	local Found = CoreSystem:Retrieve(Id)

	if Found then
		for _, Object in pairs(Found.Players) do
			if Object.Role == 'Requested' then
				return (Info and Object) or Object.Player
			end
		end
	end
end

function CoreSystem:SetBlacklist(Requestor, Requested, Type)
	if Requestor ~= Requested then
		table.insert(CoreSystem.Blacklist, {Requestor = Requestor, Requested = Requested, Time = os.time(), Type = Type})
	end
end

function CoreSystem:OnBlacklist(Requestor, Requested, Type)
	for Index, Transaction in pairs(CoreSystem.Blacklist) do
		if Transaction.Requestor == Requestor and Transaction.Requested == Requested and Transaction.Type == Type then
			if (os.time() - Transaction.Time) >= CoreSystem.Configuration.Breed.Blacklist then
				table.remove(CoreSystem.Blacklist, Index)
				return false
			else
				return true, CoreSystem.Configuration.Breed.Blacklist - (os.time() - Transaction.Time)
			end
		end
	end
	
	return false
end

function CoreSystem:GetPlayerInformation(Id, Player)
	local Found = CoreSystem:Retrieve(Id)

	if Found then
		if Found then
			for _, Object in pairs(Found.Players) do
				if Object.Player == Player then
					return Object
				end
			end
		end
	end
end

function CoreSystem:LocatePlayer(Player, Accepted)
	local Transactions = {}
	
	for _, Transaction in pairs(CoreSystem.Servicing) do
		for _, Found in pairs(Transaction.Players) do
			if Found.Player == Player then
				if Accepted then
					if Transaction.Accepted == true then
						return Transaction.Id
					end
				else
					table.insert(Transactions, Transaction.Id)
				end
			end
		end
	end
	
	return #Transactions >= 1 and Transactions
end

function CoreSystem:Create(Player, Other, Type)
	local SystemId = CoreSystem.Key
	CoreSystem.Key += 1
	
	local Configuration = CoreSystem['Configuration'][Type]
	local Same = (Player == Other) or nil
	
	if not Configuration then
		return
	end
	
	if Same == true and not Configuration.Self then
		return
	end
		
	local Information = {
		Players = {		
			One = {
				Confirmed = {
					Preliminary = false,
					Completed = 'None'
				},
				
				Items = CoreSystem['Configuration'][Type]['MaxItems'] > 1 and {},
				Player = Player,
				Role = 'Requestor'
			},
			
			Two = {
				Confirmed = {
					Preliminary = false,
					Completed = 'None'
				},

				Items = CoreSystem['Configuration'][Type]['MaxItems'] > 1 and {},
				Player = Other,
				Role = 'Requested'
			},
		},

		Time = os.time(),
		Action = Type,
		Id = SystemId,
		Accepted = (Same and true) or false,
	}
	
	if Same then
		Information.Self = {
			Confirmed = {
				Preliminary = false,
				Completed = 'None'
			},

			Player = Player,
		}
	end
	
	table.insert(CoreSystem.Servicing, Information)
	return Information
end

function CoreSystem:Retrieve(Id)
	local Found = IndexId(Id)
	
	if Found then
		local Pertaining = CoreSystem.Servicing[Found]
		return Pertaining
	end
end

function CoreSystem:Conclude(Player, Id)	
	local Found = IndexId(Id)

	if Found then
		local Valid = CoreSystem:GetPlayerInformation(Id, Player)

		if Valid then
			local Requested, Requestor, Self = CoreSystem:GetRequested(Id), CoreSystem:GetRequestor(Id), CoreSystem.Servicing[Found].Self
			table.remove(CoreSystem.Servicing, Found)

			return {Requested = Requested, Requestor = Requestor, Self = Self}
		end
	end
end

function CoreSystem:Commence(Player, Id)
	local Found = CoreSystem:Retrieve(Id)
	
	if Found then
		-- Only requested player can start
		local Requested = CoreSystem:GetRequested(Id)
		
		if (Requested == Player) or (Found.Self and Found.Self.Player == Player) then
			if Found.Accepted == false or Found.Self then
				local Current = os.time()
				
				if Current - Found.Time > CoreSystem.Configuration[Found.Action].Expiration then
					CoreSystem:Conclude(Player, Id)
					return 0, Requested
				else
					Found.Accepted = true
					return 1, Found
				end
			else
				return -2
			end
		end
	else
		return -1
	end
end

function CoreSystem:Check(Player, Id)
	local Found = CoreSystem:Retrieve(Id)
	
	if Found then
		local Valid = CoreSystem:GetPlayerInformation(Id, Player)

		if Valid then
			for _, Client in pairs(Found.Players) do
				local Located = CoreSystem:LocatePlayer(Client.Player, true)
				
				if Located and Located ~= Id then
					CoreSystem:Conclude(Player, Id)
					return true, Client.Player
				end
			end
		end
	end
end


function CoreSystem:Add(Player, Items, Id, Relative, SetMultiple)
	local Found = CoreSystem:Retrieve(Id)
	
	if Found then
		local Valid = CoreSystem:GetPlayerInformation(Id, Player)
		
		if Valid then
			local Multiple = CoreSystem['Configuration'][Found.Action]['MaxItems'] > 1
			
			if Found.Self then
				local Role
				
				if Relative == 'Requestor' then
					Role = CoreSystem:GetRequestor(Id, true)	
				elseif Relative == 'Requested' then
					Role = CoreSystem:GetRequested(Id, true)	
				end
				
				if Role.Player == Valid.Player then
					Valid = Role
				end
			end
			
			-- Check if duplicates work given different pointers for tables / Redo or test duplicates
			if Items then
				if Multiple then
					if SetMultiple then
						local Duplicates = false
						
						for MainIndex, MainItem in pairs(Items) do
							for Index, Item in pairs(Items) do
								if MainItem == Item and MainIndex ~= Index then
									Duplicates = true
									break
								end
							end
						end
						
						if not Duplicates then
							CoreSystem:Unconfirm(Player, Id)
							Valid.Items = Items
						else
							return Valid, Found, false
						end
					else
						local Duplicates = false
						
						for Index, Item in pairs(Valid.Items) do
							if Item == Items then
								Duplicates = true
								break
							end
						end
						
						if not Duplicates then
							CoreSystem:Unconfirm(Player, Id)
							table.insert(Valid.Items, Items)
						else
							return Valid, Found, false
						end
					end
					
					-- Pop the first items until it's in range of maximum
					for i = 1, #Valid.Items - CoreSystem.Configuration[Found.Action].MaxItems do
						table.remove(Valid.Items, 1)
					end
				else
					local Duplicates = false
					Items = Items or (SetMultiple and Items[1])
					
					if Found.Self then	
						for Index, Player in pairs(Found.Players) do
							-- If the player has duplicate items and
							-- the player isn't themselves (which means
							-- they are just placing the same item)
							if Player.Items == Items and Player ~= Valid then
								Duplicates = true
								break
							end
						end
					end

					if Items then
						if not Duplicates then
							CoreSystem:Unconfirm(Player, Id)
							Valid.Items = Items
						else
							return Valid, Found, false
						end					
					end
				end
			end
			
			return Valid, Found, true
		end
	end
end

function CoreSystem:Confirm(Player, Confirming, Id)
	local Found = CoreSystem:Retrieve(Id)

	if Found then
		local Valid = CoreSystem:GetPlayerInformation(Id, Player)

		if Valid then
			if Found.Self then
				-- For one player:
				local First = (Found.Self.Confirmed.Preliminary == true)

				if First then
					local Completed = (Confirming and true) or false

					if Completed then
						local CanConfirm = true
						
						for _, Object in pairs(Found.Players) do
							local Items = Object.Items
							
							-- Not sure if this is right, just saying
							local Multiple = CoreSystem['Configuration'][Found.Action]['MaxItems'] > 1

							if CoreSystem.Configuration[Found.Action].NeedsAnItem and (not Items or (Multiple and #Items < 1)) then
								CanConfirm = false
								break
							end	
						end
						
						if CanConfirm then
							Found.Self.Confirmed.Completed = Completed

							if (Found.Self.Confirmed.Completed == true) then
								return 'Completed', Valid, Found
							end
						else
							return 'Insufficient', Valid, Found
						end
					else
						CoreSystem:Unconfirm(Player, Id)
						return 'Decline', Valid, Found
					end
				else
					local CanConfirm = true

					for _, Object in pairs(Found.Players) do
						local Items = Object.Items

						-- Not sure if this is right, just saying
						local Multiple = CoreSystem['Configuration'][Found.Action]['MaxItems'] > 1
						
						if CoreSystem.Configuration[Found.Action].NeedsAnItem and (not Items or (Multiple and #Items < 1)) then
							CanConfirm = false
							break
						end	
					end
					
					if CanConfirm then
						Found.Self.Confirmed.Preliminary = (Confirming and true) or false

						if (Found.Self.Confirmed.Preliminary == true) then
							return 'Preliminary', Valid, Found
						end
					else
						return 'Insufficient', Valid, Found
					end
				end

				return 'Update', Valid, Found
			else
				-- For multiple players:
				local First = GetToggle(Id, 'Preliminary')
				
				if First then
					local Completed = (Confirming and true) or false
					
					if Completed then
						local Items = Valid.Items
						local Multiple = CoreSystem['Configuration'][Found.Action]['MaxItems'] > 1
						
						if not CoreSystem.Configuration[Found.Action].NeedsAnItem or (Items and not (Multiple and #Items < 1)) then
							Valid.Confirmed.Completed = Completed
							
							if GetToggle(Id, 'Completed') then
								return 'Completed', Valid, Found
							end
						else
							return 'Insufficient', Valid, Found
						end
					else
						CoreSystem:Unconfirm(Player, Id)
						return 'Decline', Valid, Found
					end
				else
					local Items = Valid.Items
					local Multiple = CoreSystem['Configuration'][Found.Action]['MaxItems'] > 1

					if not CoreSystem.Configuration[Found.Action].NeedsAnItem or (Items and not (Multiple and #Items < 1)) then
						Valid.Confirmed.Preliminary = (Confirming and true) or false

						if GetToggle(Id, 'Preliminary') then
							return 'Preliminary', Valid, Found
						end
					else
						return 'Insufficient', Valid, Found
					end
				end
				
				return 'Update', Valid, Found
			end
		end
	end
end

function CoreSystem:Unconfirm(Player, Id)
	local Found = CoreSystem:Retrieve(Id)
	
	if Found then
		local Valid = CoreSystem:GetPlayerInformation(Id, Player)
		
		if Valid then
			if Found.Self then
				Found.Self.Confirmed.Preliminary = false
				Found.Self.Confirmed.Completed = 'None'
			else
				for _, Players in pairs(Found.Players) do
					Players.Confirmed.Preliminary = false
					Players.Confirmed.Completed = 'None'
				end
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(Player)
	for Index, Transaction in pairs(CoreSystem.Blacklist) do
		if Transaction.Requestor == Player or Transaction.Requested == Player then
			table.remove(CoreSystem.Blacklist, Index)
		end
	end
end)

return CoreSystem
