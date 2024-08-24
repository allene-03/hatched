local Replicated = game:GetService('ReplicatedStorage')

local Remotes = Replicated.Remotes.Data
local Update = Remotes.Update

local Settings = require(Replicated.Modules.Utility.Settings)

local Replication = {}

function Replication:InitializeClient(Player, Recipients, Arguments)
	-- Send initial data
	Update:FireClient(Player, 'Initialize', {Value = Arguments.Value})
	
	-- Initialize other clients with your shared data
	for _, Recipient in pairs(Recipients) do
		if Recipient ~= Player then
			Update:FireClient(Recipient, 'Set', {
				Shared = true,
				Path = {},
				Key = tostring(Player.Name),
				Value = Arguments.PlayerValue,
			})
		end
	end
	
	-- Send shared data in a seperate remote from other update
	Update:FireClient(Player, 'Initialize', {Shared = true, Value = Arguments.SharedValue})
end

function Replication:RemoveClient(Player, Recipients)
	for _, Recipient in pairs(Recipients) do
		if Recipient ~= Player then
			Update:FireClient(Recipient, 'Remove', {
				Shared = true,
				Path = {},
				Key = tostring(Player.Name),
			})
		end
	end
end

function Replication:ReplicateClient(Player, Mode, Arguments)	
	Update:FireClient(Player, Mode, {
		Path = Arguments.Path,
		Key = Arguments.Key,
		InsertKey = Arguments.InsertKey,
		Value = Arguments.Value,
	})
end

function Replication:ReplicateShared(Player, Mode, Recipients, Arguments)
	if not Arguments.NoPlayerInsert then
		table.insert(Arguments.Path, 1, tostring(Player.Name))
	end
	
	for _, Recipient in pairs(Recipients) do
		Update:FireClient(Recipient, Mode, {
			Shared = true,
			Path = Arguments.Path, 
			Key = Arguments.Key,
			InsertKey = Arguments.InsertKey,
			Value = Arguments.Value
		})
	end
end

return Replication

