local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local StarterGui = game:GetService('StarterGui')
local Replicated = game:GetService('ReplicatedStorage')

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local ChatScroller = PlayerGui:WaitForChild('Chat'):WaitForChild('Frame'):WaitForChild('ChatChannelParentFrame'):WaitForChild("Frame_MessageLogDisplay"):WaitForChild('Scroller')

local ServerChat = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('ServerChat')

local PendingRainbowText = {}
local RainbowLabels = {}
local CurrentRainbowColor = Color3.fromRGB(0, 0, 0)

-- Functions
function coreCall(method, ...) -- From DevForum
	local result = {}

	for retries = 1, 10 do
		result = {pcall(StarterGui[method], StarterGui, ...)}
		
		if result[1] then
			break
		end

		RunService.Stepped:Wait()
	end

	return unpack(result)
end

-- Functions
local function HandleTextLabel(Label)
	local Index = Settings:Index(PendingRainbowText, Label.Text) 

	if Index then
		PendingRainbowText[Index] = nil -- So it doesn't interfere with ongoing for loops when indexing
		table.insert(RainbowLabels, Label)
	end
end

-- Events
ChatScroller.ChildAdded:Connect(function(Added)
	if Added:IsA('Frame') then
		local Label = Added:WaitForChild('TextLabel')
		
		-- If it has a text button then it's not a server setCore message
		if not Label:WaitForChild('TextButton', 0.5) then
			HandleTextLabel(Label)

			Label:GetPropertyChangedSignal('Text'):Connect(function()
				HandleTextLabel(Label)
			end)
		end
	end
end)

ServerChat.OnClientEvent:Connect(function(Properties)
	if not Properties.Text then
		return
	end
	
	if Properties.Rainbow then
		table.insert(PendingRainbowText, Properties.Text)
		Properties.Color = CurrentRainbowColor
	end
	
	coreCall('SetCore', 'ChatMakeSystemMessage', {
		Text = Properties.Text,
		Color = Properties.Color
	})
end)

-- Main rainbow loop handler
task.spawn(function()
	while true do
		for Index = 0, 1, (1 / 150) do
			CurrentRainbowColor = Color3.fromHSV(Index, 1, 1)
			
			for Index, Label in pairs(RainbowLabels) do
				if not Label.Parent then
					RainbowLabels[Index] = nil
				else
					Label.TextColor3 = CurrentRainbowColor
				end
			end
			
			task.wait(0.1)
		end
	end
end)