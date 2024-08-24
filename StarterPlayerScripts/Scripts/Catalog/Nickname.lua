local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Hide = Replicated:WaitForChild('Remotes'):WaitForChild('Interface'):WaitForChild('Hide')
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Remotes = Replicated:WaitForChild("Remotes"):WaitForChild("Catalog")
local Send, Get = Remotes:WaitForChild("SendPlayerName"), Remotes:WaitForChild("GetPlayerNames")

local Local = Players.LocalPlayer

local HideFilter, Hiding, Filter = 'Nickname', false, {}

local function Apply(Identification)
	local Player = Players:GetPlayerByUserId(Identification)
	local Name = Filter[Identification]
		
	if not Player.Character then
		return
	elseif not Name then
		Filter[Identification] = Player.DisplayName
		Name = Filter[Identification]
	end
	
	if not Player.Character:FindFirstChild('Humanoid') or Player.Character.Humanoid.Health <= 0 then
		return
	end
	
	local Head = Player.Character.Head
	local Tag = Head:WaitForChild('Tag')
	
	Tag:WaitForChild('Label')

	if Player == Local then
		Tag.AlwaysOnTop = true
		
		Tag.Label.TextTransparency = 0.5
		Tag.Label.TextStrokeTransparency = 1
	end
	
	Tag.Label.Text = Name
end

local function Hidden(notVisible)
	for _, Player in pairs(game.Players:GetPlayers()) do
		local Character = Player.Character
		
		if Character then
			local Head = Character:FindFirstChild('Head')

			if Head then
				local Tag = Head:FindFirstChild('Tag')

				if Tag then
					local Label = Tag:FindFirstChild('Label')

					if Label then
						Label.Visible =  not notVisible
					end
				end
			end
		end
	end
end

local function onCharacterAdded(Character)
	Character:WaitForChild('Head')
	Character:WaitForChild('Humanoid')
	
	local Player = Players:GetPlayerFromCharacter(Character)
	Apply(Player.UserId)
	
	if Hiding == true then
		Hidden(true)
	end
end

Send.OnClientEvent:Connect(function(Identification, Name)
	Identification = tonumber(Identification)
	Filter[Identification] = Name
	Apply(Identification)
end)

Players.PlayerAdded:Connect(function(Player)
	Player.CharacterAdded:Connect(onCharacterAdded)
end)

Players.PlayerRemoving:Connect(function(Player)
	Filter[Player.UserId] = nil
end)

Local.CharacterAdded:Connect(onCharacterAdded)

local StartingFilters = Get:InvokeServer()

-- Loaded names end up firing first so we prefer this behavior
for Identification, Name in pairs(StartingFilters) do
	if not Filter[Identification] then
		Identification = tonumber(Identification)
		Filter[Identification] = Name
	end
end

for _, Player in pairs(game.Players:GetPlayers()) do
	if Player.Character then
		onCharacterAdded(Player.Character)
	end
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