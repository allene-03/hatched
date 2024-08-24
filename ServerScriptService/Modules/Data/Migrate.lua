local Replicated = game:GetService('ReplicatedStorage')
local Settings = require(Replicated.Modules.Utility.Settings)

local Migrate = {
	-- Storing all the versions for the migration
	Versions = {},
	
	-- This will change as needed by the script
	Latest = 0, 
}

function Migrate:Upgrade(PlayerVersion, Profile)
	local Newest = Migrate.Latest
	local NewVersion
		
	if Newest then
		for CurrentVersion = (PlayerVersion or 0) + 1, Newest do
			local VersionUpgrade = Migrate['Versions'][CurrentVersion]
			
			if VersionUpgrade then
				VersionUpgrade:Update(Profile)
				
				if VersionUpgrade.Intensive then
					task.wait(1)
				end
			else
				warn('Gap in current version at index: ' .. CurrentVersion)
			end
			
			NewVersion = CurrentVersion
		end
	else
		warn('No versions available to upgrade to.')
	end
	
	return NewVersion
end

-- Main thread
local CurrentVersions = script:GetChildren()

for _, CurrentVersion in pairs(CurrentVersions) do
	local String = CurrentVersion.Name
	local _, End = string.find(String, 'Version: ')
	
	if End then
		local Indice = tonumber(string.sub(String, End))
		
		if Indice then
			local Existing = Migrate['Versions'][Indice]
			
			if Existing then
				warn("Existing 'version' already attached for this indice.")
			else
				Migrate['Versions'][Indice] = require(CurrentVersion)
			end
		else
			warn('Failed to identify indice for given version')
		end
	end
end

Migrate.Latest = Settings:iMax(Migrate.Versions) or 0

return Migrate
