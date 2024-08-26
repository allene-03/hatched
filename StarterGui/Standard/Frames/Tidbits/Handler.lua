local Replicated = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')

local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Tidbits')
local ClientBindable, ServerRemote = Remotes:WaitForChild('Client'), Remotes:WaitForChild('Server')

local Tidbits = script.Parent
local LocalPlayer = Players.LocalPlayer

-- Shared functions

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
		{Position = UDim2.fromScale(0.5, 0)})

	Playing.Completed:Wait()
end

-- Influence:
local InfluenceFlashUI = script:WaitForChild('Influence'):WaitForChild('Flash')
local InfluenceUI = script.Influence:WaitForChild('Main')

local InfluenceModel = InfluenceUI:WaitForChild('Picture'):WaitForChild('Model')
local InfluenceModelCFrame = (InfluenceModel.PrimaryPart or InfluenceModel:WaitForChild('HumanoidRootPart')).CFrame

InfluenceModel:Destroy()
InfluenceModel = nil

local InfluenceTween = {
	MainOut = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	MainIn = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	FlashIn = TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	FlashOut = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
}

local ImageLength = 3

-- Education:
local EducationUI = script:WaitForChild('Education'):WaitForChild('Whiteboard')
local EducationWrite, EducationDelete = EducationUI:WaitForChild('Main'):WaitForChild('Write'), EducationUI:WaitForChild('Main'):WaitForChild('Delete')

local EducationLimit = EducationUI:WaitForChild('Main'):WaitForChild('Holder'):WaitForChild('Limit')
local EducationBox = EducationLimit.Parent:WaitForChild('Box')

local BoardReferencing
local SavedText = ''
local TextCap = 100

EducationLimit.Text = #EducationBox.Text .. ' / ' .. TextCap .. ' chars'

EducationBox:GetPropertyChangedSignal('Text'):Connect(function()	
	if #EducationBox.Text > TextCap then
		EducationBox.Text = SavedText
	else
		SavedText = EducationBox.Text
	end
	
	EducationLimit.Text = #EducationBox.Text .. ' / ' .. TextCap .. ' chars'
end)

EducationWrite.MouseButton1Down:Connect(function()
	CommonTween(EducationWrite)
	ServerRemote:FireServer('Education', {Name = BoardReferencing, Text = EducationBox.Text})
	EducationUI.Parent = script.Education
end)

EducationDelete.MouseButton1Down:Connect(function()
	CommonTween(EducationDelete)
	EducationUI.Parent = script.Education
end)

ClientBindable.Event:Connect(function(Mode, Details)
	if Mode == 'Influence' then
		local Player = Players:FindFirstChild(Details.Player)
		
		if Player and Player.Character and Player.Character:FindFirstChild('Humanoid') and Player.Character.Humanoid.Health > 0 then
			local Setup = InfluenceUI:Clone()		
			local Existing = Tidbits:FindFirstChild(Setup.Name)
			
			if Existing then
				Existing.Parent = nil
			end
			
			-- Add the flash sequence
			local Flash = InfluenceFlashUI:Clone()
			Flash.Parent = Tidbits
			
			local Tween = TweenService:Create(Flash, InfluenceTween.FlashOut, {Transparency = 0})
			Tween:Play()
			Tween.Completed:Wait()
			
			Tween = TweenService:Create(Flash, InfluenceTween.FlashIn, {Transparency = 1})
			Tween:Play()	
			Tween.Completed:Wait()
			
			Flash:Destroy()
			
			-- Start the main sequence
			Player.Character.Archivable = true
			
			local Character = Player.Character:Clone()
			Character:SetPrimaryPartCFrame(InfluenceModelCFrame) 
			Character.Humanoid.DisplayDistanceType = 'None'
			Character.Parent = Setup.Picture
					
			Setup.Image = Details.Image
			Setup.Label.Text = string.upper(Details.Text)
			
			local Size = Setup.Size
			Setup.Size = UDim2.fromScale(0, 0)
			
			Setup.Parent = Tidbits
			
			TweenService:Create(Setup, InfluenceTween.MainOut, {Size = Size}):Play()
					
			task.wait(ImageLength)
			
			local Tween = TweenService:Create(Setup, InfluenceTween.MainIn, {Size = UDim2.fromScale(0, 0)})
			Tween:Play()
			
			Tween.Completed:Connect(function()
				Setup:Destroy()
			end)
		end
	elseif Mode == 'Education' then
		BoardReferencing = Details.Name
		EducationUI.Parent = Tidbits
	end
end)