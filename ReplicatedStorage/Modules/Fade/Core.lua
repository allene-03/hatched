local TweenService = game:GetService('TweenService')
local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild('PlayerGui')

local Repository = Settings:Create('ScreenGui', 'Fading')

local ZoomingInTweenInfo = TweenInfo.new(0.875, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
local ZoomingOutTweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0)
local SpinningTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 2, false)

local FadeEffect = {
	TweeningFromColor = script.Fade.BackgroundColor3,
	TweeningToColor = Color3.new(1, 1, 1)
}

local function EndTween(Fader, FadeFromColor)
	local SpinningTween = TweenService:Create(Fader, SpinningTweenInfo, {Rotation = Fader.Rotation - 180})
	local ZoomingOutTween = TweenService:Create(Fader, ZoomingOutTweenInfo, {Size = UDim2.fromScale(0, 0), BackgroundColor3 = FadeFromColor or FadeEffect.TweeningFromColor, Transparency = 0.75})

	SpinningTween:Play()
	ZoomingOutTween:Play()

	ZoomingOutTween.Completed:Wait()
	SpinningTween:Cancel()

	Fader:Destroy()
end

function FadeEffect:StartTween(FadeFromColor, FadeToColor)
	local AwaitingCompletion
	local DoneSpinning = false

	local Fader = script.Fade:Clone()
	Fader.Visible = true
	Fader.Transparency = 0.7
	Fader.BackgroundColor3 = FadeFromColor or FadeEffect.TweeningFromColor
	Fader.Size = UDim2.fromScale(0, 0)
	Fader.Parent = Repository

	local SpinningTween = TweenService:Create(Fader, SpinningTweenInfo, {Rotation = 180})
	local ZoomingInTween = TweenService:Create(Fader, ZoomingInTweenInfo, {Size = UDim2.fromScale(2.5, 2.5), BackgroundColor3 = FadeToColor or FadeEffect.TweeningToColor, Transparency = 0})

	SpinningTween:Play()
	ZoomingInTween:Play()

	AwaitingCompletion = SpinningTween.Completed:Connect(function()
		AwaitingCompletion:Disconnect()
		DoneSpinning = true
	end)

	ZoomingInTween.Completed:Wait()
	repeat task.wait() until (DoneSpinning)		

	return function()
		EndTween(Fader, FadeFromColor)
	end
end

-- Main sequence
Repository.DisplayOrder = 99 -- We don't want it to surpass the LoadGui
Repository.ResetOnSpawn = false
Repository.ZIndexBehavior = Enum.ZIndexBehavior.Global
Repository.Parent = PlayerGui

return FadeEffect