local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Tweening = game:GetService('TweenService')

local Player = Players.LocalPlayer
local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Breed')

local Handle = Replicated.Remotes.Breed:WaitForChild('Handle')
local Request = Replicated.Remotes.Breed:WaitForChild('Request')
local Return = Replicated.Remotes.Breed:WaitForChild('Return')
local Notify = Replicated.Remotes:WaitForChild('Systems'):WaitForChild('Notify')

local Rarity = Replicated:WaitForChild('Assets'):WaitForChild('Rarity')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local PetModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Pet'):WaitForChild('Core'))

local Frame = script.Parent
local Main = Frame:WaitForChild('Main')
local Confirmation = Frame:WaitForChild('Confirmation')

local Relative = 'Requestor'
local CurrentId

local CanConfirm, Confirmed = true, false
local Paused, StopWaitingEvent = false, true
local Debounce, DebounceReady = true, true

local Events = {}
local ConfirmationEvents = {}

-- Defaults
local Default = {
	General = '???',
	Color = Color3.fromRGB(47, 229, 90),
	Pet = 'WAITING',

	Confirm = Color3.fromRGB(45, 221, 101),
	ConfirmShadow = Color3.fromRGB(35, 177, 79),

	Box = Color3.fromRGB(224, 0, 58),
	InsideBox = Color3.fromRGB(249, 158, 165),
	TextBox = Color3.fromRGB(184, 0, 47)
}

local Active = {	
	Box = Color3.fromRGB(77, 216, 109),
	InsideBox = Color3.fromRGB(136, 255, 171),
	TextBox = Color3.fromRGB(27, 209, 15),

	Confirm = Color3.fromRGB(240, 123, 9),
	ConfirmShadow = Color3.fromRGB(167, 87, 4),

	LessThanColor = Color3.fromRGB(213, 32, 77),
	LessThan = '(-)',
	EqualToColor = Color3.fromRGB(47, 229, 90),
	EqualTo = '',
	GreaterThanColor = Color3.fromRGB(24, 190, 224),
	GreaterThan = '(+)'
}

local SidesMatrix = {
	Self = {},
	Other = {}
}

local Referring = {
	Self = nil,
	Other = nil
}

-- Functions
local function Clear(Events)
	for _, Event in pairs(Events) do
		Event:Disconnect()
	end

	return {}
end

local function InitializeMatrix()
	for Name, Object in pairs({Self = Main.Self, Other = Main.Other}) do
		for _, Statistic in pairs(Object.Details.Statistics:GetChildren()) do
			if Statistic:IsA('Frame') then
				SidesMatrix[Name][Statistic.Name] = {Object = nil, Interface = Statistic.Label}
			end
		end
	end
end

local function ClearImage(ImageHolder)
	for _, Child in pairs(ImageHolder:GetChildren()) do
		Child:Destroy()
	end

	ImageHolder.CurrentCamera = nil
end

local function Alternate(Button, Confirmed)
	if Confirmed == true then
		Button.Main.ImageColor3 = Active.Confirm
		Button.Main.Label.Text = 'UNREADY'
		Button.Shadow.ImageColor3 = Active.ConfirmShadow
	else
		Button.Main.ImageColor3 = Default.Confirm
		Button.Main.Label.Text = 'READY'
		Button.Shadow.ImageColor3 = Default.ConfirmShadow
	end
end

local function Tween(Image)
	local Playing = Tweening:Create(
		Image.Plus.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Size = UDim2.fromScale(1, 1)})

	Playing:Play()
	Playing.Completed:Wait()

	Playing = Tweening:Create(
		Image.Plus.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Size = UDim2.fromScale(1, 0.935)})

	Playing:Play()
	Playing.Completed:Wait()
end

function CommonTween(Button)
	local Playing = Tweening:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Position = Button.Shadow.Position})

	Playing:Play()
	Playing.Completed:Wait()

	Playing = Tweening:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Position = UDim2.fromScale(0.5, 0)})

	Playing:Play()
	Playing.Completed:Wait()
end

--[[
function HalfTween(Button, Down)
	if Down then
		local Playing = Tweening:Create(
			Button.Main,
			TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
			{Position = Button.Shadow.Position})

		Playing:Play()
		Playing.Completed:Wait()
	else
		local Playing = Tweening:Create(
			Button.Main,
			TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
			{Position = UDim2.fromScale(0.5, 0)})

		Playing:Play()
		Playing.Completed:Wait()
	end
end

function ResetConfirm(Button)
	CanConfirm = false
	HalfTween(Button, true)

	local Original = Button.Main.Label.Text

	for i = 3, 1, -1 do
		Button.Main.Label.Text = Original .. ' (' .. i .. ')'
		task.wait(1)
	end
	
	Button.Main.Label.Text = Original
	HalfTween(Button, false)
	CanConfirm = true
end
]]

local function InitializeTemplate(OtherPlayer)
	local Self, Other, Price, Resulting = Main.Self, Main.Other, Main.Price, Main.Resulting

	-- Reset place
	Relative = 'Requestor'

	-- Refresh matrix
	InitializeMatrix()

	-- First breeding instance
	Referring.Self = nil

	Self.Pet.Text = Default.Pet
	Self.Pet.TextColor3 = Active.Box
	Self.Player.Text = string.upper(Player.Name)

	ClearImage(Self.Image.Background.Picture)
	Self.Image.Background.Visible = false
	Self.Image.Plus.Visible = true
	Self.Image.ImageColor3 = Default.Box

	for _, Attribute in pairs(Self.Details.Standard:GetChildren()) do
		if Attribute.ClassName == 'Frame' then
			if Attribute.Name ~= 'Rarity' then
				Attribute.Label.Text = string.upper(Attribute.Name .. ': ' .. Default.General)
			else
				Attribute.Label.Text = string.upper(Default.General)
			end

			Attribute.Label.TextColor3 = Default.Color
		end
	end

	for _, Attribute in pairs(Self.Details.Statistics:GetChildren()) do
		if Attribute.ClassName == 'Frame' then
			local DisplayAttributeName
			
			if Attribute.Name == 'Self-Chemistry' then
				DisplayAttributeName = 'S-Chemistry'
			elseif Attribute.Name == 'Multi-Chemistry' then
				DisplayAttributeName = 'M-Chemistry'
			else
				DisplayAttributeName = Attribute.Name
			end
			
			Attribute.Label.Text = string.upper(DisplayAttributeName .. ': ' .. Default.General)
			Attribute.Label.TextColor3 = Default.Color
		end
	end

	-- Second breeding instance

	if OtherPlayer then
		Other.Player.Text = string.upper(OtherPlayer.Name)
		Other.Pet.TextColor3 = Default.Box
		Other.Image.Plus.Visible = false
		Other.Image.Background.Visible = true
	else
		Other.Player.Text = string.upper(Player.Name)
		Other.Pet.TextColor3 = Active.Box
		Other.Image.Plus.Visible = true
		Other.Image.Background.Visible = false
	end
	
	Referring.Other = nil
	
	Other.Image.ImageColor3 = Default.Box
	Other.Pet.Text = Default.Pet
	ClearImage(Other.Image.Background.Picture)

	for _, Attribute in pairs(Other.Details.Standard:GetChildren()) do
		if Attribute.ClassName == 'Frame' then
			if Attribute.Name ~= 'Rarity' then
				Attribute.Label.Text = string.upper(Attribute.Name .. ': ' .. Default.General)
			else
				Attribute.Label.Text = string.upper(Default.General)
			end

			Attribute.Label.TextColor3 = Default.Color
		end
	end

	for _, Attribute in pairs(Other.Details.Statistics:GetChildren()) do
		if Attribute.ClassName == 'Frame' then
			local DisplayAttributeName

			if Attribute.Name == 'Self-Chemistry' then
				DisplayAttributeName = 'S-Chemistry'
			elseif Attribute.Name == 'Multi-Chemistry' then
				DisplayAttributeName = 'M-Chemistry'
			else
				DisplayAttributeName = Attribute.Name
			end

			Attribute.Label.Text = string.upper(DisplayAttributeName .. ': ' .. Default.General)
			Attribute.Label.TextColor3 = Default.Color
		end
	end

	-- Price
	Price.Label.Text = Default.General

	-- Resulting
	Resulting.Image.ImageColor3 = Default.Box
	Resulting.Image.Background.ImageColor3 = Default.InsideBox
	Resulting.Image.Background.Title.TextColor3 = Default.TextBox
	Resulting.Image.Background.Title.Label.TextColor3 = Default.TextBox

	-- Confirm
	Confirmation.Visible = false
	Confirmation.Main.Visible = true
	Confirmation.Waiting.Visible = false
end

local function Acclimate(Primary, Added, Confirmed, Price, Valid, Singular)
	local Details = PetModule:GetData(Added)
	
	local Secondary = (Primary.Name == 'Self' and Main.Other) or Main.Self
	local SecondaryPet = Referring[Secondary.Name]

	Referring[Primary.Name] = Added
	Primary.Image.Background.Visible = true
	Primary.Image.Plus.Visible = false

	ClearImage(Primary.Image.Background.Picture)

	if Details.Model then
		PetModule:ReturnCamera(Primary.Image, Details)
	end

	local Standards = Primary.Details.Standard
	Standards.Rarity.Label.Text = string.upper(Added.Reference.Rarity)
	Standards.Gender.Label.Text = string.upper('Gender: ' .. Added.Reference.Gender)
	
	local Generation = Added.Reference.Generation
	
	local GenerationEndSub, GenerationMidSub = string.sub(Generation, -1, -1), string.sub(Generation, -2, -2)
	local GenerationCaption = 'th'
	
	-- To make sure we don't have 212nd or 12nd
	if GenerationMidSub ~= '1' then
		if GenerationEndSub == '1' then
			GenerationCaption = 'st'
		elseif GenerationEndSub == '2' then
			GenerationCaption = 'nd'
		elseif GenerationEndSub == '3' then
			GenerationCaption = 'rd'
		end
	end
	
	Standards.Generation.Label.Text = string.upper('Generation: ' .. Generation .. GenerationCaption)

	local Size = Standards:FindFirstChild('Size')
	Size.Label.Text = string.upper('Size: ' .. PetModule:GetSize(Added.Reference.Size))

	for _, Attribute in pairs(Primary.Details.Statistics:GetChildren()) do
		if Attribute.ClassName == 'Frame' then
			local PetAttribute = Added.Reference.Potential[Attribute.Name]

			if PetAttribute then
				SidesMatrix[Primary.Name][Attribute.Name] = {
					Object = PetAttribute,
					Interface = Attribute.Label
				}
			end
		end
	end

	-- Has to be a better way to do this, lol
	for AttributeName, Attribute in pairs(SidesMatrix[Primary.Name]) do
		local OppositeAttribute = SidesMatrix[Secondary.Name][AttributeName]
		local DisplayAttributeName
		
		if AttributeName == 'Self-Chemistry' then
			DisplayAttributeName = 'S-Chemistry'
		elseif AttributeName == 'Multi-Chemistry' then
			DisplayAttributeName = 'M-Chemistry'
		else
			DisplayAttributeName = AttributeName
		end

		if not Attribute.Object then
			Attribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. Default.General)
			Attribute.Interface.TextColor3 = Active.EqualToColor
			OppositeAttribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. (OppositeAttribute.Object and OppositeAttribute.Object or Default.General))
			OppositeAttribute.Interface.TextColor3 = Active.EqualToColor
		else
			if not OppositeAttribute.Object then
				Attribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. Attribute.Object)
				Attribute.Interface.TextColor3 = Active.EqualToColor
				OppositeAttribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. Default.General)
				OppositeAttribute.Interface.TextColor3 = Active.EqualToColor
			else
				if Attribute.Object > OppositeAttribute.Object then
					Attribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. Attribute.Object .. ' ' .. Active.GreaterThan)
					Attribute.Interface.TextColor3 = Active.GreaterThanColor
					OppositeAttribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. OppositeAttribute.Object .. ' ' .. Active.LessThan)
					OppositeAttribute.Interface.TextColor3 = Active.LessThanColor
				elseif Attribute.Object < OppositeAttribute.Object then
					Attribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. Attribute.Object .. ' ' .. Active.LessThan)
					Attribute.Interface.TextColor3 = Active.LessThanColor
					OppositeAttribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. OppositeAttribute.Object .. ' ' .. Active.GreaterThan)
					OppositeAttribute.Interface.TextColor3 = Active.GreaterThanColor
				else
					Attribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. Attribute.Object .. ' ' .. Active.EqualTo)
					Attribute.Interface.TextColor3 = Active.EqualToColor
					OppositeAttribute.Interface.Text = string.upper(DisplayAttributeName .. ': ' .. OppositeAttribute.Object .. ' ' .. Active.EqualTo)
					OppositeAttribute.Interface.TextColor3 = Active.EqualToColor
				end
			end
		end
	end

	Primary.Pet.Text = string.upper(Added.Reference.Species)

	if Confirmed == true then
		Primary.Pet.TextColor3 = Active.Box
		Primary.Image.ImageColor3 = Active.Box

		if Singular == true then
			Secondary.Pet.TextColor3 = Active.Box			
			Secondary.Image.ImageColor3 = Active.Box
		end
	else
		if Primary.Image.Plus.Visible == false then
			Primary.Pet.TextColor3 = Default.Box
		end

		Primary.Image.ImageColor3 = Default.Box

		if Singular == true then
			if Secondary.Image.Plus.Visible == false then
				Secondary.Pet.TextColor3 = Default.Box
			end
			
			Secondary.Image.ImageColor3 = Default.Box
		end
	end

	if Price then
		Main.Price.Label.Text = Price
	else
		Main.Price.Label.Text = Default.General
	end
	
	local Resulting = Main.Resulting
	
	if Valid then
		Resulting.Image.ImageColor3 = Active.Box
		Resulting.Image.Background.ImageColor3 = Active.InsideBox
		Resulting.Image.Background.Title.TextColor3 = Active.TextBox
		Resulting.Image.Background.Title.Label.TextColor3 = Active.TextBox
	else
		Resulting.Image.ImageColor3 = Default.Box
		Resulting.Image.Background.ImageColor3 = Default.InsideBox
		Resulting.Image.Background.Title.TextColor3 = Default.TextBox
		Resulting.Image.Background.Title.Label.TextColor3 = Default.TextBox
	end
end

local function Unconfirm(OnlyButton)
	ConfirmationEvents = Clear(ConfirmationEvents)

	if not OnlyButton then
		local Self, Other = Main.Self, Main.Other

		if Self.Image.Plus.Visible == false then
			Self.Pet.TextColor3 = Default.Box
		end

		Self.Image.ImageColor3 = Default.Box

		if Other.Image.Plus.Visible == false then
			Other.Pet.TextColor3 = Default.Box
		end

		Other.Image.ImageColor3 = Default.Box
	end
	
	Confirmed, Paused, StopWaitingEvent = false, false, true
	Alternate(Main.Confirm, false)
	
	Confirmation.Visible = false
	Confirmation.Main.Visible, Confirmation.Waiting.Visible = true, false
end

local function Clean(Frame)
	Paused, StopWaitingEvent = false, true
	Frame.Visible, Confirmation.Visible = false, false

	Events = Clear(Events)
	ConfirmationEvents = Clear(ConfirmationEvents)

	Request:Fire('End')
end

Handle.OnClientEvent:Connect(function(Action, Arguments)
	if Action == 'Commence' then
		local Other = Arguments['Other'] and Arguments['Other'][1]
		CurrentId, Confirmed, Paused, StopWaitingEvent = Arguments.Id, false, false, true

		InitializeTemplate(Other)
		Alternate(Main.Confirm, Confirmed)
		Request:Fire('Start')

		Frame.Visible = true

		table.insert(Events, Main.Self.Image.MouseButton1Down:Connect(function()
			if Debounce then
				Debounce = false

				if Main.Self.Image.Plus.Visible then
					Tween(Main.Self.Image)
				end

				Relative = 'Requestor'
				Request:Fire('Retrieve', Paused)

				task.wait(1)
				Debounce = true
			end
		end))

		if not Other then
			table.insert(Events, Main.Other.Image.MouseButton1Down:Connect(function()
				if Debounce then
					Debounce = false

					if Main.Other.Image.Plus.Visible then
						Tween(Main.Other.Image)
					end

					Relative = 'Requested'
					Request:Fire('Retrieve', Paused)

					task.wait(1)
					Debounce = true
				end
			end))
		end

		table.insert(Events, Main.Confirm.MouseButton1Down:Connect(function()
			if DebounceReady then
				DebounceReady = false
				
				task.spawn(function()
					CommonTween(Main.Confirm)
				end)
				
				-- To reduce input lag (can be removed by deleting this and replacing Handle Value parameter with 'not Confirmed')
				Confirmed = not Confirmed
				Alternate(Main.Confirm, Confirmed)
				--
				Handle:FireServer('Confirm', {Id = Arguments.Id, Value = Confirmed, Relative = Relative})

				task.wait(1)
				DebounceReady = true
			end
		end))

		table.insert(Events, Main.Decline.MouseButton1Down:Connect(function()
			CommonTween(Main.Decline)
			Handle:FireServer('End', {Id = Arguments.Id})
		end))
	elseif Action == 'Update' then
		if not Arguments.Items then
			return
		end

		if Arguments.Unconfirming then
			Unconfirm()
		end

		if Arguments.Relative then
			if Arguments.Relative == 'Requestor' then
				Acclimate(Main.Self, Arguments.Items, Arguments.Confirmed, Arguments.Price, Arguments.Valid, true)
			elseif Arguments.Relative == 'Requested' then
				Acclimate(Main.Other, Arguments.Items, Arguments.Confirmed, Arguments.Price, Arguments.Valid, true)
			end

			if Arguments.Confirmed == true or Arguments.Confirmed == false then
				Confirmed = Arguments.Confirmed
				Alternate(Main.Confirm, Confirmed)
			end
		else
			if Arguments.Player == Player then
				Acclimate(Main.Self, Arguments.Items, Arguments.Confirmed, Arguments.Price, Arguments.Valid)

				if Arguments.Confirmed == true or Arguments.Confirmed == false then
					Confirmed = Arguments.Confirmed
					Alternate(Main.Confirm, Confirmed)
				end
			else
				Acclimate(Main.Other, Arguments.Items, Arguments.Confirmed, Arguments.Price, Arguments.Valid)
			end
		end
	elseif Action == 'Preliminary' then
		Paused, StopWaitingEvent = true, true
		Confirmation.Main.Question.Text = 'Are you sure you want to breed for $' .. Main.Price.Label.Text .. '?'
		Confirmation.Main.Visible, Confirmation.Waiting.Visible = true, false
		Confirmation.Visible = true

		table.insert(ConfirmationEvents, Confirmation.Main.Confirm.MouseButton1Down:Connect(function()
			ConfirmationEvents = Clear(ConfirmationEvents)
			CommonTween(Confirmation.Main.Confirm)

			Handle:FireServer('Confirm', {Id = CurrentId, Value = true, Relative = Relative})
			
			StopWaitingEvent = false
			Confirmation.Main.Visible, Confirmation.Waiting.Visible = false, true

			task.spawn(function()
				local Text = "Awaiting other player's confirmation"
				Confirmation.Waiting.Label.Text = Text
				
				task.wait(1)

				while true do
					for i = 1, 3 do
						if StopWaitingEvent == true then
							return
						end
						
						Confirmation.Waiting.Label.Text = Text .. string.rep('.', i)						
						task.wait(1)
					end
				end
			end)
		end))

		table.insert(ConfirmationEvents, Confirmation.Main.Decline.MouseButton1Down:Connect(function()
			CommonTween(Confirmation.Main.Decline)
			
			ConfirmationEvents = Clear(ConfirmationEvents)	
			Handle:FireServer('Confirm', {Id = CurrentId, Value = false, Relative = Relative})
			Paused = false
			Confirmation.Visible = false
		end))
	elseif Action == 'Unconfirm' then
		Unconfirm()
	elseif Action == 'Insufficient' then
		Unconfirm(true)
	elseif Action == 'Declined' then
		Clean(Frame)
	elseif Action == 'Completed' then
		Clean(Frame)
	end
	
	local Message = Arguments and Arguments.Message
	
	if Message then	
		if Arguments.IsMessageImportant then
			Notify:Fire(Message, true)
		else
			Notify:Fire(Message)
		end
	end
end)

Return.Event:Connect(function(Pet)
	Request:Fire('Selected')
	Handle:FireServer('Update', {Pet = Pet, Id = CurrentId, Relative = Relative})
end)

-- Set frame visibility
Frame.Visible = false