local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local LocalPlayer = Players.LocalPlayer
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

-- Variables
local MaintainingAnimations = false -- Prevent thead overlapping

local CoreAnimation = {
	CurrentIds = {
		['Dancing'] = {
			Id = 7542211943,
			Type = 'Standard'
		},
		
		['Acting'] = {
			Id = 7542210391,
			Type = 'Standard'
		},
		
		['Singing'] = {
			Id = 7542211173,
			Type = 'Standard'
		},
		
		['Piano'] = {
			Id = 7542518770,
			Type = 'Standard'
		},
		
		['Typing'] = {
			Id = 7558404447,
			Type = 'Standard'
		},
		
		['Carrying'] = {
			Id = 7958089490,
			Type = 'Sticky'
		}
	},
	
	PlayingAnimations = {}
}

local function ClearAnimation(Index, AnimationInfo)
	if not AnimationInfo then
		return
	end
	
	-- Stop the animation before destroying the object
	if AnimationInfo.Animation then
		AnimationInfo.Animation:Stop()
	end
	
	if AnimationInfo.Object then
		AnimationInfo.Object:Destroy()
	end

	-- Don't use table.remove as that screws with the for loop in ClearAnimation
	CoreAnimation['PlayingAnimations'][Index] = nil
end

local function RefreshAnimations(Character)
	if not MaintainingAnimations then
		MaintainingAnimations = true
		
		for Index, AnimationInfo in pairs(CoreAnimation.PlayingAnimations) do
			if AnimationInfo.Type ~= 'Sticky' then
				ClearAnimation(Index, AnimationInfo)
			end
		end
		
		MaintainingAnimations = false
	end
end

local function PlayerAdded(Player)
	local function CharacterAdded(Character)
		if not Character then
			return
		end
		
		local Humanoid = Character:WaitForChild('Humanoid')
		
		if Humanoid then
			Humanoid:GetPropertyChangedSignal('MoveDirection'):Connect(function()
				if not Humanoid.SeatPart then
					RefreshAnimations(Character)
				end
			end)
			
			Humanoid:GetPropertyChangedSignal('Jump'):Connect(function()
				RefreshAnimations(Character)
			end)
		end
	end
	
	CharacterAdded(Player.Character)
	Player.CharacterAdded:Connect(CharacterAdded)
end

function CoreAnimation:PlayAnimation(Character, Animation, Properties)
	Properties = Properties or {}
	
	if Character then
		local Humanoid = Character:FindFirstChild('Humanoid')

		if Humanoid then			
			local AnimationDetails = CoreAnimation['CurrentIds'][Animation]
			RefreshAnimations(Character)

			if AnimationDetails then
				local NewAnimation = Instance.new('Animation')
				NewAnimation.AnimationId = 'rbxassetid://' .. AnimationDetails.Id
				
				local AnimationPlayer = Humanoid:LoadAnimation(NewAnimation)
				AnimationPlayer.Looped = Properties.Looped or false
				AnimationPlayer:Play()
				
				AnimationPlayer:AdjustWeight(Properties.Weight or 1)
				
				table.insert(CoreAnimation.PlayingAnimations, {
					Object = NewAnimation,
					Animation = AnimationPlayer,
					Type = AnimationDetails.Type,
					Name = Animation
				})
			end
		end
	end
end

-- Stop all animations matching that animationName
function CoreAnimation:StopAnimation(Animation)
	for Index, AnimationInfo in pairs(CoreAnimation.PlayingAnimations) do
		if AnimationInfo and AnimationInfo.Name == Animation then
			ClearAnimation(Index, AnimationInfo)
		end
	end
end

PlayerAdded(LocalPlayer)

return CoreAnimation