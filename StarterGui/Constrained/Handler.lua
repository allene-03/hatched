-- REST OF INTERFACE FUNCTIONALITY CONTAINED IN STARTER PLAYER SCRIPTS OR REPLICATED STORAGE

local Tweens = game:GetService('TweenService')

local Replicated = game:GetService('ReplicatedStorage')
local Hide = Replicated:WaitForChild('Remotes'):WaitForChild('Interface'):WaitForChild('Hide')
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Breeding = Replicated:WaitForChild('Remotes'):WaitForChild('Breed'):WaitForChild('Request')
local Upgrading = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('InvokeUpgrade')

local Main = script.Parent

local Buttons = Main:WaitForChild('Buttons')
local Frames = Main:WaitForChild('Frames')

local BreedingPertainsTo, ActionPertainsTo = Buttons.Stash, Buttons.Stash
local BreedingEvents, ActionEvents = {}, {}
local IsBreeding = false

local Interfacing = script:WaitForChild('Interfacing')

local Playing = false

local IncrementZindex = 5

local OpenTweenInfo = TweenInfo.new(
	0.75,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out,
	0,
	false,
	0
)

local CloseTweenInfo = TweenInfo.new(
	0.75,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.In,
	0,
	false,
	0
)

-- Functions
-- Commented out because nasty usage with amount of descendants in Stash
function IncrementZIndex(Ancestor, Value)
	local Descendants = Ancestor:GetDescendants()
	table.insert(Descendants, Ancestor)

	for _, object in pairs(Descendants) do
		if object:IsA("GuiObject") then
			object.ZIndex += Value
		end
	end
end

-- test all three:open Same and close and open dif
-- Check multispam
function Open(Frame, IgnoreTween)
	if Playing == false then
		Playing = true
		
		local New = (Interfacing.Value ~= Frame)
		
		if Interfacing.Value ~= nil then
			-- IncrementZIndex(Interfacing.Value, -IncrementZindex)
			local DefaultPosition = Interfacing.Value.Position

			if not IgnoreTween then				
				local Tween = Tweens:Create(Interfacing.Value, CloseTweenInfo, {
					Position = UDim2.fromScale(DefaultPosition.X.Scale, DefaultPosition.Y.Scale + 1.5)
				})
				Tween:Play()
				Tween.Completed:Wait()
			else
				Interfacing.Value.Position = UDim2.fromScale(DefaultPosition.X.Scale, DefaultPosition.Y.Scale + 1.5)
				task.wait(0.25)
			end
			
			Interfacing.Value.Visible = false
			Interfacing.Value.Position = DefaultPosition
		end
		
		if New and Frame then
			Interfacing.Value = Frame
			-- IncrementZIndex(Frame, IncrementZindex)
			
			local DefaultPosition = Frame.Position
			
			Frame.Position = UDim2.fromScale(DefaultPosition.X.Scale, DefaultPosition.Y.Scale + 1.5)
			Frame.Visible = true
			
			if not IgnoreTween then
				local Tween = Tweens:Create(Interfacing.Value, OpenTweenInfo, {Position = DefaultPosition})
				Tween:Play()
				Tween.Completed:Wait()
			else
				Interfacing.Value.Position = DefaultPosition
				task.wait(0.25)
			end
		else
			Interfacing.Value = nil
		end
		
		Playing = false
	end
end

function Set(Frame)
	Frame.Visible = false
	
	local Button = Buttons:FindFirstChild(Frame.Name) 
	local Exit = Frame:FindFirstChild('Exit', true)
	
	if Button and Button.ClassName == 'ImageButton' then	
		local StandardButtonBehavior = true

		if Button == BreedingPertainsTo then
			StandardButtonBehavior = false

			BreedingEvents[Button] = {
				Event = Button.MouseButton1Down:Connect(function()
					if IsBreeding == false then
						Open(Frame)
					end
				end),

				Frame = Frame
			}
		end
		
		if Button == ActionPertainsTo then
			StandardButtonBehavior = false

			ActionEvents[Button] = {
				Event = Button.MouseButton1Down:Connect(function()
					Open(Frame)
				end),

				Frame = Frame
			}
		end
		
		if StandardButtonBehavior then
			Button.MouseButton1Down:Connect(function()
				Open(Frame)
			end)	
		end

		Hide.Event:Connect(function(Status, Type, List)
			local Mention = Settings:Index(List, Button)

			if Type == 'Except' then
				if Status == 'Hide' then
					if not Mention then
						Button.Visible = false
					end
				else
					if not Mention then
						Button.Visible = true
					end
				end
			elseif Type == 'Including' then
				if Status == 'Hide' then
					if Mention then
						Button.Visible = false
					end
				else
					if Mention then
						Button.Visible = true
					end
				end
			end
		end)
	end
	
	if Exit then
		local StandardExitBehavior = true
		
		if Button == BreedingPertainsTo then
			local StandardExitBehavior = false

			BreedingEvents[Button].ExitEvent = Exit.MouseButton1Down:Connect(function()
				if IsBreeding == false then
					if Interfacing.Value == Frame then
						Open(nil)
					end
				else
					if Interfacing.Value == Frame then
						Open(nil, true)
					end
				end
			end)

			BreedingEvents[Button].Exit = Exit
		end	
		
		if StandardExitBehavior then
			Exit.MouseButton1Down:Connect(function()
				if Interfacing.Value == Frame then
					Open(nil)
				end
			end)
		end
	end
end

for _, Frame in pairs(Frames:GetChildren()) do
	if Frame.ClassName == 'Frame' then
		Set(Frame)
		
		Hide.Event:Connect(function(Status, Type, List)
			local Mention = Settings:Index(List, Frame)

			if Type == 'Except' then
				if Status == 'Hide' and not Mention then
					Frame.Visible = false
					
					if Interfacing.Value == Frame then
						Open(nil)
					end
				end
			elseif Type == 'Including' then
				if Status == 'Hide' and Mention then
					Frame.Visible = false

					if Interfacing.Value == Frame then
						Open(nil)
					end
				end
			end
		end)
	end
end

-- For the breeding module
Breeding.Event:Connect(function(Mode, Paused)
	if Mode == 'Start' or Mode == 'Resume' then
		IsBreeding = true
		Open(nil, true)
	elseif Mode == 'Retrieve' then
		if not Paused then
			for Button, Action in pairs(BreedingEvents) do
				Open(Action.Frame, true)
			end
		end
	elseif Mode == 'Selected' then
		Open(nil, true)
	elseif Mode == 'End' or Mode == 'Pause' then
		IsBreeding = false
	end
end)

-- For the interact module
Upgrading.Event:Connect(function()
	for Button, Action in pairs(BreedingEvents) do
		Open(Action.Frame, true)
	end
end)
