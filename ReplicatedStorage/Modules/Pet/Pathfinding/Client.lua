-- If there are any bugs made by animations, for instance passive, it needs to be adjusted on Nonclient as well

--<< SERVICES >>
local PathfindingService = game:GetService("PathfindingService")
local Replicated = game:GetService('ReplicatedStorage')

--<< SUBMODULES >>

local Jumper = require(script.Jump)
local Bobber = require(script.Bobber)
local Lerper = require(script.Lerper)
local Petcaster = require(script.Petcaster)
local Spring = require(script.Spring)
local States = require(script.States)
local Settings = require(script.Parent.Settings)

--<< PET CODE >>

local Pet = {}
Pet.__index = Pet

--<< SETUP >>

function Pet:SetupSettings(PetData)
	local Configuration = PetData:FindFirstChild('Configuration') and require(PetData.Configuration) or {}
	local Animations = PetData:FindFirstChild('Animations')
	
	local ModelCFrame, ModelSize = self.Model:GetBoundingBox()
	
	self.Settings = {
		-- Commonly shared settings between all pets
		Speed = Settings.Speed,
		TurnSpeed = Settings.TurnSpeed,

		JumpTime = Settings.JumpTime,
		JumpHeight = Settings.JumpHeight,

		IdealDistance = Settings.IdealDistance - ModelSize.X / 2,
		
		PathfindingTimeout = Settings.PathfindingTimeout,
		RefreshRate = Settings.RefreshRate,
		TeleportRetryComputationRate = Settings.TeleportRetryComputationRate,
		
		PassiveYieldTime = Settings.PassiveYieldTime,
		
		-- Dynamic settings adjusted
		Width = ModelSize.X,
		Height = ModelSize.Y,
		
		-- Pet stored animation tracks
		Animations = {
			Jump = Animations:FindFirstChild('Jump');
			Walk = Animations:FindFirstChild('Walk');
			Idle = Animations:FindFirstChild('Idle');
			Passive = Animations:FindFirstChild('Passive') or Animations:FindFirstChild('Idle'); -- If no passive, just play idle
		};
		
		-- Individually pet determined configurations
		Fly = Configuration.Fly or false;
		Bob = Configuration.Bob or false;
		FlyHeight = Configuration.FlyHeight or 2;
		FlyBobAmp = Configuration.FlyBobAmplitude or 2;
		FlyBobFre = Configuration.FlyBobFrequency or 4;
		
		WalkAnimationSpeed = Configuration.WalkAnimationSpeed or 1;
	}
end

function Pet:SetupAnimations()
	self.Animations = {}
	self.AnimationsThread = 0
	self.AnimationController = self.Model:WaitForChild("AnimationController")
	
	-- Initialize the actual animations
	for Name, Animation in pairs(self.Settings.Animations) do
		local LoadingAnimation = Animation:Clone()
		
		local AnimationTrack = self.AnimationController:LoadAnimation(LoadingAnimation)
		AnimationTrack.Looped = true
		
		self['Animations'][Name] = AnimationTrack
	end
	
	-- Set the non-looping animations
	self.Animations.Passive.Looped = false
	
	if self.Animations.Jump then
		self.Animations.Jump.Looped = false
	end
	
	-- Initialize when passive should be played
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

function Pet:SetupPathfinding()
	self.Pathfinding = {}
	
	self.Pathfinding.IsPathfinding = false
	self.Pathfinding.ThreadNumber = 0
	
	self.Pathfinding.Path = PathfindingService:CreatePath({
		AgentRadius = math.clamp(self.Settings.Width, 0, 3),
		AgentHeight = math.clamp(self.Settings.Height, 0, 4),
		AgentCanJump = true
	})
end

function Pet:SetupSubmodules(start_position)
	self.Springs = {}
	
	function self.Springs.CapVelocity(spring, max)
		max = max or spring.Speed
		
		if spring.Velocity.Magnitude > max then
			spring.Velocity = spring.Velocity.Unit * max
		end
	end
	
	function self.Springs.CapXYVelocity(spring, max)
		max = max or spring.Speed
		local copy = Vector2.new(spring.Velocity.X, spring.Velocity.Z)
		
		if copy.Magnitude > max then
			copy = copy.Unit * max
			spring.Velocity = Vector3.new(copy.X, spring.Velocity.Y, copy.Y)
		end
	end

	self.Springs.Location = Spring.new(start_position)
	self.Springs.Location.Speed = self.Settings.Speed
	self.Springs.Location.Damper = 0.8

	self.Springs.Direction = Spring.new(Vector3.new())
	self.Springs.Direction.Speed = self.Settings.TurnSpeed

	self.Lerper = Lerper.new(start_position)
	self.Lerper.Speed = self.Settings.Speed
	
	self.Jumper = Jumper.new(self.Settings.JumpHeight, self.Settings.JumpTime)
	
	if self.Settings.Bob then
		self.Bobber = Bobber.new(self.Settings.FlyBobAmp, self.Settings.FlyBobFre)
	end
end

function Pet:Setup(petData, start_position)
	self.StateChangedEvent = Instance.new("BindableEvent")
	self.StateChanged = self.StateChangedEvent.Event
	self.JumpEvent = Instance.new("BindableEvent")
	self.Jumped = self.JumpEvent.Event
	
	self:SetupSettings(petData)
	self:SetupAnimations()
	self:SetupPathfinding()
	self:SetupSubmodules(start_position)
end

--<< ANIMATIONS >>

function Pet:PlayIdleAnimation()	
	if not (self.Animations.Idle.IsPlaying or self.Animations.Passive.IsPlaying) then
		self.AnimationsThread += 1
		self.Animations.Idle:Play()
		
		self.State = States.Idle
		self.StateChangedEvent:Fire(States.Idle)
	end
	
	if self.Animations.Walk.IsPlaying then
		self.Animations.Walk:Stop()
	end
end

function Pet:PlayWalkAnimation()
	if not self.Animations.Walk.IsPlaying then
		self.AnimationsThread += 1
		self.Animations.Walk:Play(nil, nil, self.Settings.WalkAnimationSpeed)

		self.State = States.Active
		self.StateChangedEvent:Fire(States.Active)
	end
	
	if self.Animations.Passive.IsPlaying then
		self.Animations.Passive:Stop()
	end
	
	if self.Animations.Idle.IsPlaying then
		self.Animations.Idle:Stop()
	end
end

--<< PATHFINDING >>
function Pet:StartPathfinding(goal)
	coroutine.wrap(function()
		local cur_thread = self.Pathfinding.ThreadNumber
		local current_waypoint_index = 0
		local pathfinding_start = tick()
		
		self.Pathfinding.IsPathfinding = true
		
		-- Check that it's pathfinding and in the right thread
		local function check_is_live()
			return self.Pathfinding.ThreadNumber == cur_thread and self.Pathfinding.IsPathfinding
		end
		
		-- Check that pathfinding session hasn't timed out
		local function check_time()
			if (tick() - pathfinding_start) > self.Settings.PathfindingTimeout then
				local possible = self.GetDesiredLocation()
				
				if not possible then
					repeat task.wait(1 / self.Settings.RefreshRate)
						possible = self.GetDesiredLocation()
					until (possible or not check_is_live())
				end
				
				-- Teleports the pet to the new location and ends the pathfinding session
				if check_is_live() then
					self:Update(States.Teleporting, possible, true) -- Change last argument to false if you don't want it to jump when teleporting
				end
			else
				return true
			end
		end
		
		self.Pathfinding.Path:ComputeAsync(self.Springs.Location.Position, goal)
		
		-- Will keep looking for a path within time limit and if still PFing if path not originally found
		while check_is_live() and self.Pathfinding.Path.Status == Enum.PathStatus.NoPath and check_time() do
			self.Pathfinding.Path:ComputeAsync(self.Springs.Location.Position, goal) 
			task.wait(1 / self.Settings.TeleportRetryComputationRate)
		end
		
		if not check_is_live() then
			return
		end
		
		self.Lerper.Position = self.Springs.Location.Position
		local waypoints = self.Pathfinding.Path:GetWaypoints()
		
		-- Navigates through the waypoints
		while check_is_live() and current_waypoint_index < #self.Pathfinding.Path:GetWaypoints() do
			if current_waypoint_index > 0 then
				self.Lerper.Position = waypoints[current_waypoint_index].Position
				self.Springs.Direction.Target = (waypoints[current_waypoint_index+1].Position - waypoints[current_waypoint_index].Position)*Vector3.new(1,0,1)
				self:PlayWalkAnimation()	
			end
			
			if waypoints[current_waypoint_index + 1].Action == Enum.PathWaypointAction.Jump then
				self:Update('Pathfinding', Vector3.new(), true)
			end
			
			self.Lerper:LerpToAsync(waypoints[current_waypoint_index+1].Position)
			current_waypoint_index = current_waypoint_index + 1
		end
		
		if not check_is_live() then
			return
		end
		
		self:EndPathfinding()
	end)()
end

function Pet:EndPathfinding()
	self.Pathfinding.IsPathfinding = false
	self.Pathfinding.ThreadNumber = self.Pathfinding.ThreadNumber + 1
end

--<< CONSTRUCTOR >>

function Pet.new(pet_model, petData)
	local self = setmetatable({}, Pet)
	
	self.Model = pet_model
	self.State = States.Idle
	
	self:Setup(petData, Vector3.new())
	self:Bind()
	
	return self
end

function Pet:Update(new_state, new_position, jump)
	if new_state == States.Idle and self.Pathfinding.IsPathfinding then
		return
	end
	
	if new_state ~= States.Pathfinding and self.Pathfinding.IsPathfinding then
		self:EndPathfinding()
	end
	
	if new_state == States.Idle then
		self:PlayIdleAnimation()
	else
		self:PlayWalkAnimation()
		
		if not self.Pathfinding.IsPathfinding then
			self.Springs.Direction.Target = self.Springs.Location.Velocity * Vector3.new(1, 0, 1)
		end
		
		if new_state == States.Active then
			if new_position then
				self.Springs.Location.Target = new_position
				self.Springs.CapXYVelocity(self.Springs.Location)
			end
		elseif new_state == States.Teleporting then
			self.Springs.Location.Position = new_position
			self.Springs.Location.Target = new_position
			self.Springs.CapXYVelocity(self.Springs.Location)
		elseif new_state == States.Pathfinding and not self.Pathfinding.IsPathfinding then
			self:StartPathfinding(new_position)
		end
	end
		
	if jump and (not self.Settings.Fly) and not self.Jumper.Active then
		self.AnimationsThread += 1
		self.Animations.Jump:Play()
		
		self.Jumper:Start()
		self.JumpEvent:Fire()
	end
end 

function Pet:Edit(Pet)	
	if self.Model and self.Model == Pet then
		local _, ModelSize = self.Model:GetBoundingBox()
		
		self.Settings.Width = ModelSize.X
		self.Settings.Height = ModelSize.Y
		self.Settings.IdealDistance = Settings.IdealDistance - ModelSize.X / 2
		
		Petcaster.TakeGlobals(self.Settings.IdealDistance, self.Settings.Width)
	end
end

function Pet:UpdateVisualisation()
	self.Springs.CapXYVelocity(self.Springs.Location)
	
	if self.Pathfinding.IsPathfinding and self.Lerper.Active then
		self.Springs.Location.Position = self.Lerper:GetPosition()
		self.Springs.Location.Target = self.Springs.Location.Position
	end
	
	local location = self.Springs.Location.Position
	
	if not self.Settings.Fly then
		location = location + Vector3.new(0, self.Jumper:GetPosition() - 1/2, 0)
	else
		local y_pos = (self.Settings.Bob) and (self.Settings.FlyHeight + self.Bobber:GetPosition()) or (self.Settings.FlyHeight)
		location = location + Vector3.new(0, y_pos, 0)
	end
	
	local default = self.GetCharacterOrientation() or Vector3.new()
	local direction = location + default + self.Springs.Direction.Position * Vector3.new(1, 0, 1)
	
	if (direction).Magnitude ~= 0 and direction.Magnitude ~= math.huge then
		self.Model.PrimaryPart.CFrame = CFrame.lookAt(location, direction, Vector3.new(0, 1, 0))
	end
end

function Pet:Bind()
	local info = Petcaster.Bind(
		self.Springs.Location, 
		
		function(...)
			self:Update(...)
		end,
		
		self.Settings.RefreshRate
	)
	
	Petcaster.TakeGlobals(self.Settings.IdealDistance, self.Settings.Width)
	
	self.UnbindRaycaster = info.Unbind
	self.GetDesiredLocation = info.GetPosition
	self.GetCharacterOrientation = info.GetCharLookVec
end

--<< EXTERNAL FUNCTIONS >>

function Pet:Unbind()
	self.UnbindRaycaster()
	
	-- Remove the animations
	for _, Animation in pairs(self.Animations) do
		Animation:Stop()
		Animation:Destroy()
	end
	
	-- Remove the events
	self.JumpEvent:Destroy()
	self.StateChangedEvent:Destroy()
end

return Pet
