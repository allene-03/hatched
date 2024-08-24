local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService('ServerScriptService')
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local DataModule = require(SSS.Modules.Data.Consolidate)

local Remotes = ReplicatedStorage.Remotes.Catalog
local Get, Send, Change = Remotes.GetPlayerNames, Remotes.SendPlayerName, Remotes.ChangeName
local Update = Remotes.UpdateHead

local Filter = {}
local CharacterCap, Offset = 200, 0.175

local Tag = ReplicatedStorage.Assets.Interface.Catalog.Tag
local Settings = require(ReplicatedStorage.Modules.Utility.Settings)

local function applyTag(character, altering)
	local PlayerTag, New
		
	if not character:FindFirstChild('Head') then
		return
	end
	
	local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid")
	
	if not humanoid or not humanoid:IsDescendantOf(workspace) then
		humanoid.AncestryChanged:Wait()
	end
	
	if altering == true then
		if character.Head:FindFirstChild('Tag') then
			PlayerTag = character.Head.Tag
		else
			PlayerTag = Tag:Clone()
			New = true
		end
	else
		if character.Head:FindFirstChild('Tag') then
			return
		end
		
		PlayerTag = Tag:Clone()
		New = true
	end
	
	if humanoid.Health > 0 then
		PlayerTag.StudsOffset = Vector3.new(0, (character.Head.Size.Y + Offset + (PlayerTag.Size.Y.Scale / 2)), 0)
		
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		PlayerTag.Label.Text = New and "" or PlayerTag.Label.Text
		PlayerTag.Parent = character.Head
	end
end

local function Broadcast(Target)
	local Identification = Target.UserId
	local Filtered = Filter[Identification]['Instance']
	
	if not Filtered or typeof(Filtered) ~= 'Instance' then return end
	
	local Name = Filtered:GetNonChatStringForBroadcastAsync()
	Name = Name or "####"

	Send:FireAllClients(Identification, Name)
end

-- Needs to set the error to the Name bar, same for pet names
local function ChangeName(Player, Name, Loading)
	local F_Name = Name:gsub("%s+", "")

	if #F_Name == 0 then
		Name = Player.DisplayName
	end
	
	if Name == "" then
		return false, "You need to enter a name!"
	elseif #Name >= CharacterCap then
		return false, "Your name is too long!"
	end

	local Filtered

	local Success, Error = pcall(function()
		Filtered = TextService:FilterStringAsync(Name, Player.UserId)
	end)

	if not Success then
		print("Failed error")
		return false, "Text filtering routine failed."
	end
	
	if not Loading then
		local Data = DataModule:Get(Player)
		
		if Data then
			DataModule:Set(Player, 'Set', {
				Directory = Data,
				Key = 'Nickname',
				Value = Name,
				Default = 'StringValue',
				Path = {}
			})
		else
			return false, 'Please wait for player data to load.'
		end
	end

	Filter[Player.UserId] = {
		['Instance'] = Filtered,
		['String'] = Name
	}
	
	Broadcast(Player)

	-- return the filtered name to the player to display
	local FilteredName = Filtered:GetNonChatStringForBroadcastAsync() or "####"
	return true, FilteredName
end

Change.OnServerInvoke = function(Player, Name)
	return ChangeName(Player, Name)
end

Update.Event:Connect(function(Character)
	applyTag(Character, true)
end)

Get.OnServerInvoke = function(Player)
	local Names = {}
	
	for Identification, Filtered in pairs(Filter) do
		Filtered = Filtered['Instance']
		
		local FilteredName = Filtered:GetNonChatStringForBroadcastAsync()
		FilteredName = FilteredName or "####"
		Names[tostring(Identification)] = FilteredName
	end

	-- return all player's names filtered for this specific user
	return Names
end

local function PlayerAdded(Player)
	local PlayerName = Player.Name
	local Saved

	Player.CharacterAdded:Connect(function(Character)
		task.wait()
		applyTag(Character)
	end)

	applyTag(Player.Character or Player.CharacterAdded:Wait())

	-- Account for saved information that may be present
	repeat
		Saved = DataModule:Get(Player)
		task.wait(1)
	until (Saved or not Players:FindFirstChild(PlayerName))

	if Saved and Saved.Nickname then
		ChangeName(Player, Saved.Nickname, true)
	end
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(Player)
	-- Remove the player's filtered name from memory to prevent leaks
	Filter[Player.UserId] = nil
end)

for _, Player in pairs(Players:GetPlayers()) do
	task.spawn(function()
		PlayerAdded(Player)
	end)
end