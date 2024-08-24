local Lerper = {}
Lerper.__index = Lerper

function Lerper.new(position)
	local self = setmetatable({}, Lerper)
	
	self.Position = position
	self.Speed = 1
	
	self.CurrentLerp = {}
	self.CurrentLerp.Target = Vector3.new()
	self.CurrentLerp.StartTime = 0
	self.CurrentLerp.HeuristicTime = 0
	
	return self
end

function Lerper:LerpToAsync(position)
	self.Active = true
	self.CurrentLerp.StartTime = tick()
	self.CurrentLerp.Target = position
	self.CurrentLerp.HeuristicTime = (position - self.Position).Magnitude / self.Speed
	
	task.wait(self.CurrentLerp.HeuristicTime)
	
	self.Position = position
	self.Active = false
end

function Lerper:GetPosition(Now)
	Now = Now or tick()
	local alpha = math.clamp((Now - self.CurrentLerp.StartTime) / self.CurrentLerp.HeuristicTime, 0, 1)
	
	return (self.CurrentLerp.Target * alpha) + (self.Position * (1 - alpha))
end

return Lerper