local Players = game:GetService('Players')
local Replicated = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')

local HomesFolder = workspace:WaitForChild('Homes')

local RemotesFolder = Replicated:WaitForChild('Remotes'):WaitForChild('Home')
local LockingRemote = RemotesFolder:FindFirstChild('Locking')

local LocalPlayer = Players.LocalPlayer

local TweenOpenInformation = TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local TweenCloseInformation = TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local RootFrame = script.Parent

local Buttons = RootFrame.Parent.Parent:WaitForChild('Buttons')

local ColorButton, LockButton = Buttons:WaitForChild('Color'), Buttons:WaitForChild('Lock')
local ColorFrame = RootFrame:WaitForChild('Color')

local Information = {
	Lock = {
		Color = {
			Unlocked = {
				Outline = LockButton.Stroke.Color,
				Inside = LockButton.BackgroundColor3,
				TextStroke = LockButton.Label.TextStrokeColor3,
				Text = 'LOCK'
			},
			
			Locked = {
				Outline = Color3.fromRGB(227, 0, 17),
				Inside = Color3.fromRGB(254, 172, 169),
				TextStroke = Color3.fromRGB(252, 0, 17),
				Text = 'OPEN'
			}
		},
		Position = LockButton.Position
	},
	
	Color = {
		Position = ColorButton.Position
	}
}

local function TweenButton(Mode)	
	if Mode == 'Open' then
		if ColorButton.Position.X.Scale <= 0 then
			local Tween = TweenService:Create(ColorButton, TweenOpenInformation, {Position = Information.Color.Position})
			Tween:Play()
		end
		
		if LockButton.Position.X.Scale <= 0 then
			local Tween = TweenService:Create(LockButton, TweenOpenInformation, {Position = Information.Lock.Position})
			Tween:Play()
		end
	else
		if ColorButton.Position.X.Scale > 0 then
			local Tween = TweenService:Create(ColorButton, TweenCloseInformation, {Position = UDim2.fromScale(Information.Color.Position.X.Scale - 0.25, Information.Color.Position.Y.Scale)})
			Tween:Play()
		end

		if LockButton.Position.X.Scale > 0 then
			local Tween = TweenService:Create(LockButton, TweenCloseInformation, {Position = UDim2.fromScale(Information.Lock.Position.X.Scale - 0.25, Information.Lock.Position.Y.Scale)})
			Tween:Play()
		end
	end
end

local function GetHome()
	for _, Home in pairs(HomesFolder:GetChildren()) do
		local Owner = Home:FindFirstChild('Owner')
		
		if Owner and Owner.Value == LocalPlayer.Name then
			return Home
		end
	end
end

-- Events
ColorButton.MouseButton1Down:Connect(function()
	ColorFrame.Visible = not ColorFrame.Visible
end)

LockButton.MouseButton1Down:Connect(function()
	local Success, LockedStatus = LockingRemote:InvokeServer()
	
	if Success then
		if LockedStatus == true then
			LockButton.BackgroundColor3 = Information.Lock.Color.Locked.Inside
			LockButton.Stroke.Color = Information.Lock.Color.Locked.Outline
			LockButton.Icon.ImageColor3 = Information.Lock.Color.Locked.Outline
			LockButton.Label.TextStrokeColor3 = Information.Lock.Color.Locked.TextStroke
			LockButton.Label.Text = Information.Lock.Color.Locked.Text
		else
			LockButton.BackgroundColor3 = Information.Lock.Color.Unlocked.Inside
			LockButton.Stroke.Color = Information.Lock.Color.Unlocked.Outline
			LockButton.Icon.ImageColor3 = Information.Lock.Color.Unlocked.Outline
			LockButton.Label.TextStrokeColor3 = Information.Lock.Color.Unlocked.TextStroke
			LockButton.Label.Text = Information.Lock.Color.Unlocked.Text
		end
	end
end)

-- Main sequence
local HomeObject = GetHome()
TweenButton('Close')

RootFrame.Visible = true

while true do
	-- Allocate your base
	if HomeObject and HomeObject.Parent == HomesFolder then
		local Exterior, Interior = HomeObject:FindFirstChild('Exterior'), HomeObject:FindFirstChild('Interior')
		
		if Exterior and Interior then
			local Character = LocalPlayer.Character
			
			if Character then
				local CharacterRoot = Character:FindFirstChild('HumanoidRootPart')
				
				if CharacterRoot and ((CharacterRoot.Position - Exterior.PrimaryPart.Position).Magnitude <= 150 or (CharacterRoot.Position - Interior.PrimaryPart.Position).Magnitude <= 150) then
					TweenButton('Open')
				else
					TweenButton('Close')
				end
			end
		else
			warn('Cannot find the interior and exterior for place.')
		end
	else
		HomeObject = GetHome()
	end
	
	task.wait(1.5)
end