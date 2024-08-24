local Replicated = game:GetService('ReplicatedStorage')
local Settings = require(script.Parent.Settings)

local Nonclient = {}
Nonclient.__index = Nonclient

function Nonclient:SetupSettings(PetData)
	local Configuration = PetData:FindFirstChild('Configuration') and require(PetData.Configuration) or {}
	local Animations = PetData:FindFirstChild('Animations')

	self.Settings = {
		Fly = Configuration.Fly or false;
		WalkAnimationSpeed = Configuration.WalkAnimationSpeed or 1;
		
		PassiveYieldTime = Settings.PassiveYieldTime,
		
		Animations = {
			Jump = Animations:FindFirstChild('Jump');
			Walk = Animations:FindFirstChild('Walk');
			Idle = Animations:FindFirstChild('Idle');
			Passive = Animations:FindFirstChild('Passive') or Animations:FindFirstChild('Idle'); -- If no passive, just play idle
		};
	}
end

function Nonclient:ConfigureAnimations()
	self.Animations = {}
	self.AnimationsThread = 0
	self.AnimationController = self.Model:WaitForChild("AnimationController")
	
	for Name, Animation in pairs(self.Settings.Animations) do
		local LoadingAnimation = Animation:Clone()
		
		local AnimationTrack = self.AnimationController:LoadAnimation(LoadingAnimation)
		AnimationTrack.Looped = true
		
		if Name == 'Walk' then
			self['Animations']['Active'] = AnimationTrack
		else
			self['Animations'][Name] = AnimationTrack
		end
	end
	
	-- Set the non-looping animations
	self.Animations.Passive.Looped = false
	
	if self.Animations.Jump then
		self.Animations.Jump.Looped = false
	end
	
	-- Initialize when passive should be played // copied directly from Client
	local AnimationsThread = self.AnimationsThread
	local TimeSinceIdleStarted = tick()
	local PassiveThreadActive = false

	self.Animations.Idle.DidLoop:Connect(function()
		if AnimationsThread ~= self.AnimationsThread then
			-- If did loop has fired that means idle has already played once, so subract time
			TimeSinceIdleStarted = tick() - self.Animations.Idle.Length
			AnimationsThread = self.AnimationsThread
		end

		if ((tick() - TimeSinceIdleStarted) >= self.Settings.PassiveYieldTime) and (not PassiveThreadActive) then
			-- We fork it in case self.AnimationsThread is incremented and AnimationsThread is updated out of scope
			local CurrentAnimationsThread = AnimationsThread
			PassiveThreadActive = true

			local PassiveStopped; PassiveStopped = self.Animations.Passive.Stopped:Connect(function()
				PassiveStopped:Disconnect()

				-- If we're in the same thread then we need to resume the idle animations, but prevent from playing passive again
				-- immediately
				if CurrentAnimationsThread == self.AnimationsThread then
					self.AnimationsThread += 1
					self.Animations.Idle:Play()
				end

				-- So it can now be used again
				PassiveThreadActive = false
			end)

			self.Animations.Passive:Play()
			self.Animations.Idle:Stop()
		end
	end)
end

function Nonclient.new(pet_model, petData)
	local self = setmetatable({}, Nonclient)
	
	self.Model = pet_model
	
	self:SetupSettings(petData)
	self:ConfigureAnimations()	
	
	self.JumpNumber = false
	self.State = nil
	
	return self
end

function Nonclient:Update(NewState, JumpValue)	
	if self.State ~= NewState then
		if self.Animations[self.State] then
			if self.State == 'Idle' then
				if self.Animations.Idle.IsPlaying then
					self.Animations.Idle:Stop()
				end
				
				if self.Animations.Passive.IsPlaying then
					self.Animations.Passive:Stop()
				end
			elseif self.Animations[self.State].IsPlaying then
				self.Animations[self.State]:Stop()
			end
		end
		
		self.State = NewState
		
		if self.Animations[self.State] then
			self.AnimationsThread += 1

			if self.State == 'Active' then
				self.Animations[self.State]:Play(nil, nil, self.Settings.WalkAnimationSpeed)
			else
				self.Animations[self.State]:Play()
			end
		end
	end
	
	if JumpValue ~= self.JumpNumber then
		self.JumpNumber = JumpValue
		
		if not self.Settings.Fly then
			self.AnimationsThread += 1
			self.Animations.Jump:Play()
		end
	end
end

function Nonclient:Unbind()
	for _, Animation in pairs(self.Animations) do
		Animation:Stop()
		Animation:Destroy()
	end
end

return Nonclient