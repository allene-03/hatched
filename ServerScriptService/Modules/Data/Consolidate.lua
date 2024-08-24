-- Services
local Replicated = game:GetService('ReplicatedStorage')
local HTTPService = game:GetService('HttpService')
local Players = game:GetService('Players')

-- Modules
local ProfileService = require(script.ProfileService)
local Settings = require(Replicated.Modules.Utility.Settings)
local Replication = require(script.Replication)
local Migrate = require(script.Parent.Migrate)

-- Remotes 
local UpdateRemote = Replicated.Remotes.Data.Update
local ClientReadyRemote = Replicated.Remotes.Data.Ready

-- Module data
local Consolidate = {
	Settings = {
		KeyFormatting = 'Key: ',
	},
	
	-- Stores the players ready to receive their initialized data
	Ready = {},
	
	-- Stores all the cached data that's going to be saved per player session
	Profiles = {},

	-- Stores all the data that's going to be shared / replicated to all clients
	Shared = {},
	
	Template = function()
		return {
			-- Inventory data and categories
			Inventory = {
				Pets = {},
				Vehicles = {},
				Accessories = {}
			},
			
			-- Where money and other value-based objects are stored
			Merit = {
				Currency = 0,
			},
			
			-- Where all home data is stored
			Homes = {},
			
			-- Where job data is stored in a table
			Job = nil,
			
			-- Character customization data
			Clothing = nil,
			Nickname = nil,
			
			-- Will be set to false later, but used to initialize intro data
		}
	end,
}

-- Data profile
local ProfileStore = ProfileService.GetProfileStore(
	"Testing31",
	Consolidate['Template']() -- Template folder in use
)

-- Utility functions
local function GetAvailableKey(Directory)
	local Unique

	repeat
		Unique = HTTPService:GenerateGUID(false)
		local Available = true

		for Key, _ in pairs(Directory) do
			if Key == Unique then
				Available = false
				break
			end
		end
	until (Available == true)

	return Unique
end

-- Data functions
local function GetPlayersWithProfiles()
	local ProfiledPlayers = {}

	for Player, _ in pairs(Consolidate.Profiles) do
		table.insert(ProfiledPlayers, Player)
	end

	return ProfiledPlayers
end

-- Utility module functions
function Consolidate:TableSet(...)
	return {...}
end

function Consolidate:TableInsert(Table, ...)
	local Forked = Settings:DeepCopy(Table)

	for _, Value in pairs({...}) do
		table.insert(Forked, Value)
	end

	return Forked
end

-- Data module functions
function Consolidate:Get(Player, GetProfile)
	local PlayerProfileData = Consolidate['Profiles'][Player]
	
	-- Retry until found or player leaves
	while not PlayerProfileData and Player:IsDescendantOf(Players) do
		PlayerProfileData = Consolidate['Profiles'][Player]
		task.wait(0.5)
	end
	
	-- If data allocated, pick specific aspect
	if PlayerProfileData then
		return (GetProfile and PlayerProfileData.Profile or PlayerProfileData.Data)
	end
end

function Consolidate:GetShared(Player, All)
	return (All and Consolidate['Shared'] or Consolidate['Shared'][Player and Player.Name])
end

function Consolidate:Set(Player, Mode, Arguments)
	local PlayerData = Consolidate:Get(Player)
	
	if PlayerData then
		local Returning
		
		if Mode == 'Set' then
			Arguments.Directory[Arguments.Key] = Arguments.Value
		elseif Mode == 'Insert' then
			Arguments.InsertKey = GetAvailableKey(Arguments.Directory[Arguments.Key])
			Arguments.Directory[Arguments.Key][Arguments.InsertKey] = Arguments.Value
			
			-- Return the insert key if 'inserting'
			Returning = Arguments.InsertKey
		elseif Mode == 'Remove' then
			Arguments.Directory[Arguments.Key] = nil
		elseif Mode == 'Update' then
			-- Doesn't actually set the value to anything, sets the parameter the client will see to whatever (only displays)
			Mode = 'Set'
			Arguments.Value = Arguments.Directory[Arguments.Key]
		end
		
		if not Arguments.NoUpdate then
			if Arguments.Shared then
				Replication:ReplicateShared(Player, Mode, GetPlayersWithProfiles(), Arguments)
			else
				Replication:ReplicateClient(Player, Mode, Arguments)
			end
		end
		
		return Returning
	end
end

-- Initialization function
local function WaitToReplicateData(Profile, Shared, Player)	
	if not Consolidate['Ready'][Player] then
		repeat
			task.wait(1)
		until (not Player:IsDescendantOf(Players) or Consolidate['Ready'][Player])
	end
	
	-- Sanity check in case the player has left, we send this once to be network efficient
	if (Player:IsDescendantOf(Players) and Consolidate['Ready'][Player]) then
		Replication:InitializeClient(Player, GetPlayersWithProfiles(), {Value = Profile.Data, PlayerValue = Shared, SharedValue = Consolidate.Shared})
	end
end

-- Main functions
local function PlayerAdded(Player)
	local Profile = ProfileStore:LoadProfileAsync(
		Consolidate.Settings.KeyFormatting .. Player.UserId,
		"ForceLoad"
	)
	
	if Profile ~= nil then
		Profile:AddUserId(Player.UserId) -- Comply with GDPR
		
		-- Set up event for when the profile gets released
		Profile:ListenToRelease(function()
			-- Clear out profile cache
			Consolidate.Profiles[Player] = nil

			-- Clear out shared data if it's there
			Consolidate['Shared'][Player.Name] = nil
			
			-- Remove the client from those it's replicating to
			Replication:RemoveClient(Player, GetPlayersWithProfiles())
			
			-- Kick the player if they are still present
			Player:Kick("Your profile has been loaded remotely. Please rejoin.")
		end)
				
		-- If the player is here after retrieval of data, we start the versioning sequence
		if Player:IsDescendantOf(Players) then
			-- Now we adjust the versioning, if it's a new profile then it will default to the newest version otherwise if 
			-- existing it will check for updates
			local ProfileIsInitialized = Profile:GetMetaTag('ProfileIsInitialized')

			if ProfileIsInitialized then
				print('Existing profile detected, checking for latest version.')
				
				local CurrentVersion = Profile:GetMetaTag('CurrentVersion')
				
				if (not CurrentVersion) or (CurrentVersion < Migrate.Latest) then
					print('Existing profile is not at the latest version, updating.')
					
					local NewestVersion = Migrate:Upgrade(CurrentVersion, Profile)
					Profile:SetMetaTag('CurrentVersion', NewestVersion)
				end
			else
				print('New profile detected, assigning latest version.')
				
				Profile:SetMetaTag('DateInitialized', os.time())
				Profile:SetMetaTag('CurrentVersion', Migrate.Latest)
				
				Profile:SetMetaTag('ErrorLogData', {})
				Profile:SetMetaTag('InformationLogData', {})

				-- Lastly, we assign whether or not the data is at it's first time being retrieved for metric purposes
				Profile:SetMetaTag('ProfileIsInitialized', true)
			end

			-- Now we check again if the player is here after updating data before replicating the data
			if Player:IsDescendantOf(Players) then
				-- Set the player profile data to existing
				local PlayerProfileData = {Profile = Profile, Data = Profile.Data}
				Consolidate.Profiles[Player] = PlayerProfileData
				
				-- Set the shared player data to blank
				local SharedData = {}
				Consolidate.Shared[Player.Name] = SharedData
				
				-- Now replicate data to the player
				WaitToReplicateData(Profile, SharedData, Player)
			else
				Profile:Release() -- Player has left so you can release it
			end
		else
			Profile:Release()
		end
	else
		Player:Kick('Failed to retrieve saved data, please rejoin!')
	end
end

local function PlayerRemoving(Player)
	local PlayerProfileData = Consolidate.Profiles[Player]
	
	if PlayerProfileData and PlayerProfileData.Profile then
		PlayerProfileData.Profile:Release()
	end
	
	Consolidate['Ready'][Player] = nil
end

-- Main sequence
for _, Player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, Player)
end

-- Set up events AFTER sequence
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

-- When it receives a request, it will set it to true
ClientReadyRemote.OnServerEvent:Connect(function(Player)	
	if Player:IsDescendantOf(Players) then
		Consolidate['Ready'][Player] = true
	end
end)

-- This can be removed later, but is for testing purposes
task.spawn(function()
	while true do
		for Player, PlayerProfileData in pairs(Consolidate.Profiles) do
			print(Player.Name .. "'s data is sized at " .. #HTTPService:JSONEncode(PlayerProfileData.Data) .. ".")
		end
		
		task.wait(180)
	end
end)

return Consolidate