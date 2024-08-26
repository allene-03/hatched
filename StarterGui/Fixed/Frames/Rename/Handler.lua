-- Services
local TweenService = game:GetService('TweenService')
local Replicated = game:GetService('ReplicatedStorage')

-- Instances
local Frame = script.Parent
local Remotes = Replicated:WaitForChild('Remotes')

local Buttons = Frame:WaitForChild('Buttons')
local Holder = Frame:WaitForChild('Holder')

local Change = Buttons:WaitForChild('Change')
local Cancel = Buttons:WaitForChild('Cancel')

local Limit = Holder:WaitForChild('Limit')
local Box = Holder:WaitForChild('Box')

-- Remotes
local OnRenameInvoked = Remotes:WaitForChild('Other'):WaitForChild('InvokeRename')
local Handling = Remotes:WaitForChild('Pets'):WaitForChild('Handling')

-- Variables
local Identifier
local ModifyingPlaceholderText = false
local SavedText, TextCap = '', 50

-- Configurations
local Configurations = {
	InitialPlaceholder = Box.PlaceholderText
}

-- Functions
function CommonTween(Button)
	local Playing = TweenService:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Position = Button.Shadow.Position})
	
	Playing:Play()
	Playing.Completed:Wait()

	Playing = TweenService:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Position = UDim2.fromScale(0.5, 0)})
	
	Playing:Play()
	Playing.Completed:Wait()
end

-- Events
Box:GetPropertyChangedSignal('Text'):Connect(function()	
	if #Box.Text > TextCap then
		Box.Text = SavedText
	else
		SavedText = Box.Text
	end

	Limit.Text = #Box.Text .. ' / ' .. TextCap .. ' chars'
end)

Change.MouseButton1Down:Connect(function()
	CommonTween(Change)
	local Success, Error = Handling:InvokeServer('Renaming', {Pet = Identifier, Name = Box.Text})
	
	if Success then
		Frame.Visible = false
	else
		SavedText, Box.Text = '', ''
		
		if not ModifyingPlaceholderText and Error then
			ModifyingPlaceholderText = true
			
			Box.PlaceholderText = Error
			task.wait(1.5)
			Box.PlaceholderText = Configurations.InitialPlaceholder
			
			ModifyingPlaceholderText = false
		end	
	end
end)

Cancel.MouseButton1Down:Connect(function()
	CommonTween(Cancel)
	Frame.Visible = false
end)

OnRenameInvoked.Event:Connect(function(NewIdentifier)
	task.wait()
	print(Identifier, NewIdentifier)
	Identifier = NewIdentifier
	SavedText, Box.Text = '', ''
	Frame.Visible = true
end)

-- Main sequence
Frame.Visible = false
Limit.Text = #Box.Text .. ' / ' .. TextCap .. ' chars'