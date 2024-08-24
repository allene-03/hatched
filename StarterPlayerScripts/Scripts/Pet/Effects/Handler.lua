local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Requesting = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Requesting')
local Emitting = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Emitting')

local EffectsModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Pet'):WaitForChild('Effects'))
local LocalPlayer = Players.LocalPlayer

-- Implement so that this ONLY happens if pet is within a range?
local function HandleEffects(Mode, Pet, Properties)
	-- We yield if the VFX occurs when the pet just equips to let the pet initialize it's starting position, which 
	-- happens quicker locally and slower for all other clients
	if (Mode == 'Transitioning' or Mode == 'HighRankTransitioning' or Mode == 'Equipping') then
		if Properties._PlayerId == LocalPlayer.UserId then
			task.wait(0.25)
		else
			task.wait(0.5)
		end
	end
	
	-- Main VFX effect player
	if Mode == 'Leveling' then
		EffectsModule:PlayEffect(Pet, EffectsModule.Types.Leveling, Properties)
	elseif Mode == 'Transitioning' then
		EffectsModule:PlayEffect(Pet, EffectsModule.Types.Transitioning, Properties)
	elseif Mode == 'HighRankTransitioning' then
		EffectsModule:PlayEffect(Pet, EffectsModule.Types.HighRankTransitioning, Properties)
	elseif Mode == 'Breeding' then
		EffectsModule:PlayEffect(Pet, EffectsModule.Types.Breeding)
	elseif Mode == 'Equipping' then
		EffectsModule:PlayEffect(Pet, EffectsModule.Types.Equipping)
	end
end

Emitting.OnClientEvent:Connect(HandleEffects)

local CurrentPets = Requesting:InvokeServer(false)

for _, Table in pairs(CurrentPets) do
	local Pet = Table.Pet
	
	if Pet then
		EffectsModule:ChangeProperties(Table.Pet, {Size = Table.Size}, true)
	end
end

-- Sometimes when the egg to pet transition has occurred, the pet is stuck in the middle of root part for Nonclients
-- Maybe find someway to position at it's starting position first and then remove the beginning waits here