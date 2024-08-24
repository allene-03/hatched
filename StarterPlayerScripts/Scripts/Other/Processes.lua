local Replicated = game:GetService('ReplicatedStorage')
local Starter = game:GetService("StarterGui")

local Hide = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Hide'))
local Player = game.Players.LocalPlayer

local PlayerMod = require(Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local Control = PlayerMod:GetControls()

local DisableEvent = Replicated:WaitForChild("Remotes"):WaitForChild("Other"):WaitForChild('Disable')
local Character = Player.Character or Player.CharacterAdded:Wait(0.03)

Starter:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

-- Or show specific elements, like nickname?
Player.CharacterAdded:Connect(function()
	Hide:ShowInterface()
end)

-- If you reset and call control disable, you break CAS - SO, need to add in a construct that only executes once
DisableEvent.Event:Connect(function(Disabling)
	if Disabling == true then
		Control:Disable()
	else
		Control:Enable()
	end
end)

Hide:ShowInterface()

