local Bobber = {}
Bobber.__index = Bobber

function Bobber.new(Amplitude, Frequency)
	local self = setmetatable({}, Bobber)
	
	self.K = Amplitude
	self.L = Frequency
	
	self.Start = tick()
	
	return self
end

function Bobber:GetPosition(Now)
	Now = Now or tick()
	local elapsed = (Now - self.Start) % (math.pi * 2 / self.L)
	
	return self.K * math.sin(self.L * elapsed)
end

return Bobber