local Players = game:GetService('Players')
local Tweens = game:GetService('TweenService')
local Replicated = game:GetService('ReplicatedStorage')

local Stealing = Replicated:WaitForChild('Remotes'):WaitForChild('Jobs'):WaitForChild('Stealing')
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Safes = workspace:WaitForChild('Safes')

local StealingUI = script.Parent:WaitForChild('Stealing')
local StealingUIClickedEvent

local Player = Players.LocalPlayer

local DoorClosing = {}

local function TweenDoor(Model, Opening)
	local DoorRoot = Model.PrimaryPart
	
	if DoorRoot then
		local Information = TweenInfo.new(1.5, Enum.EasingStyle.Bounce, Opening and Enum.EasingDirection.Out or Enum.EasingDirection.In)
		
		local Tween = Tweens:Create(DoorRoot, Information, {
			CFrame = DoorRoot.CFrame * CFrame.Angles(0, math.rad(Opening and 180 or -180), 0)
		})
		
		Tween:Play()
		
		return Tween
	end
end

for _, Safe in pairs(Safes:GetChildren()) do
	local Door = Safe:WaitForChild('Door')
	local Locked = Safe:WaitForChild('Locked')
	
	local Main = Door:WaitForChild('Main')
	
	local Click = Main:WaitForChild('Open')
	
	if Locked.Value == true then
		TweenDoor(Door, true)
	end
	
	Click.MouseClick:Connect(function()		
		if Locked.Value == false then
			Stealing:FireServer(Safe)
		else
			if StealingUIClickedEvent then
				StealingUIClickedEvent:Disconnect()
				StealingUIClickedEvent = nil
			end

			StealingUI.Message.Text = 'This safe has been open recently, please come back later!'

			StealingUIClickedEvent = StealingUI.Confirm.MouseButton1Down:Connect(function()
				StealingUI.Visible = false
			end)

			StealingUI.Visible = true 
		end
	end)
end

Stealing.OnClientEvent:Connect(function(Action, Door, Information)
	if Action == 'Open' then
		if DoorClosing[Door] then
			repeat
				task.wait(0.5)
			until (not DoorClosing[Door])
		end
		
		TweenDoor(Door, true)
		
		if Information.Player == Player then
			if StealingUIClickedEvent then
				StealingUIClickedEvent:Disconnect()
				StealingUIClickedEvent = nil
			end
			
			StealingUI.Message.Text = Information.Text
			
			StealingUIClickedEvent = StealingUI.Confirm.MouseButton1Down:Connect(function()
				StealingUI.Visible = false
			end)
			
			StealingUI.Visible = true 
		end
	elseif Action == 'Close' then
		DoorClosing[Door] = true
		
		local Tween = TweenDoor(Door)
		Tween.Completed:Wait()
		
		DoorClosing[Door] = false
	end
end)