local TweenService = game:GetService('TweenService')
local Replicated = game:GetService('ReplicatedStorage')

local ClientNotify = Replicated:WaitForChild('Remotes'):WaitForChild('Systems'):WaitForChild('Notify')
local ServerNotify = Replicated:WaitForChild('Remotes'):WaitForChild('Systems'):WaitForChild('ServerNotify')

local BreedRemote = Replicated.Remotes:WaitForChild('Breed'):WaitForChild('Handle')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local SystemsCore = script.Parent
local WarningMessage = script:WaitForChild('_Warning')

local BreedUI = SystemsCore:WaitForChild('Breed')
local TradeUI = SystemsCore:WaitForChild('Trade')

local Configurations = {
	WarningImportantColor = Color3.fromRGB(254, 217, 192),
	WarningImportantStrokeColor = Color3.fromRGB(141, 74, 54),
	
	WarningStartTween = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
	WarningEndTween = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- Circ/Expo
}

local Queue, ConnectedEvents = {}, {}

local Servicing = false

local function Clear(Events)
	for _, Event in pairs(Events) do
		Event:Disconnect()
	end
	
	return {}
end

function Tween(Object, Info, Properties)
	local Tween = TweenService:Create(Object, Info, Properties)
	Tween:Play()

	return Tween
end

function CommonTween(Button)
	local Playing = Tween(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Position = Button.Shadow.Position})

	Playing.Completed:Wait()

	Playing = Tween(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Position = UDim2.fromScale(0.5, -0.066)})

	Playing.Completed:Wait()
end

local function Notification(Message, Important)
	local Alert = WarningMessage:Clone()
	
	-- Set text and importance color
	if Important then
		Alert.TextColor3 = Configurations.WarningImportantColor
		Alert.TextStrokeColor3 = Configurations.WarningImportantStrokeColor
	end
	
	Alert.Text = Message
	
	-- Clear out the old alert
	local Current = SystemsCore:FindFirstChild(Alert.Name)

	if Current then
		Current.Parent = nil
	end
	
	-- Set new properties for it 
	local Position, Transparency, StrokeTransparency = Alert.Position, Alert.TextTransparency, Alert.TextStrokeTransparency
	Alert.Position, Alert.TextTransparency, Alert.TextStrokeTransparency = UDim2.fromScale(Position.X.Scale, Position.Y.Scale - 0.03), 1, 2.5
	
	-- Properties
	Alert.Parent = SystemsCore
	
	local Tween = TweenService:Create(Alert, Configurations.WarningStartTween, {Position = Position, TextTransparency = Transparency, TextStrokeTransparency = StrokeTransparency})
	Tween:Play()

	Tween.Completed:Connect(function()
		task.wait(2.5)

		Tween = TweenService:Create(Alert, Configurations.WarningEndTween, {TextTransparency = 1, TextStrokeTransparency = 2.5})
		Tween:Play()
		Tween.Completed:Wait()

		Alert:Destroy()
	end)
end

-- Same for trade
function BreedSequence(Player, BreedId, Queueing)
	Servicing = true
	
	BreedUI.Question.Text = Player.Name .. ' wants to breed with your pets! NOTE: You will both get to keep your pets.'
	BreedUI.Visible = true
	
	print(BreedId)

	table.insert(ConnectedEvents, BreedUI.Confirm.MouseButton1Down:Connect(function()
		CommonTween(BreedUI.Confirm)
		
		Queue = {}
		BreedRemote:FireServer('Respond', {Option = true, Id = BreedId})

		ConnectedEvents = Clear(ConnectedEvents)
		BreedUI.Visible = false
		Servicing = false
	end))

	table.insert(ConnectedEvents, BreedUI.Decline.MouseButton1Down:Connect(function()
		CommonTween(BreedUI.Decline)
		
		if Queueing and Queue[Queueing] then
			table.remove(Queue, Queueing)
		end
				
		BreedRemote:FireServer('Respond', {Option = false, Id = BreedId})

		ConnectedEvents = Clear(ConnectedEvents)
		BreedUI.Visible = false
		Servicing = false
		
		HandleQueue(Queue)
	end))
end

function HandleQueue(Queue)
	local Oldest = Queue[1]
	
	if Oldest then
		if Oldest.Type == 'Breed' then
			if Servicing == false then
				BreedSequence(Oldest.Player, Oldest.Id, 1)
			end
		elseif Oldest.Type == 'Trade' then
			
		end
	end
end

-- Same for trade
BreedRemote.OnClientEvent:Connect(function(Action, Arguments)
	if Action == 'Request' then
		if Servicing == false then
			BreedSequence(Arguments.Player, Arguments.Id)
		else
			table.insert(Queue, {Type = 'Breed', Player = Arguments.Player, Id = Arguments.Id})
		end
	end
end)

ClientNotify.Event:Connect(Notification)
ServerNotify.OnClientEvent:Connect(Notification)
