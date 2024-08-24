local Jump = {}
Jump.__index = Jump

function Jump.new(height, length)
	local self = setmetatable({}, Jump)
	
	self.Height = height
	self.Length = length
	self.StartTime = 0
	self.Active = false
	self.CT = 0
	
	return self
end

function Jump:Start()
	self.Active = true
	self.StartTime = tick()
	self.CT = self.CT + 1
	
	local ct = self.CT
	
	coroutine.wrap(function()
		task.wait(self.Length)
		
		if ct == self.CT then
			self.Active = false
		end
	end)()
end

function Jump:GetPosition()
	local x = tick() - self.StartTime
	local l = self.Length
	
	if x <= l then
		return ((-4 * self.Height)/(l ^ 2)) * (x - l) * x
	else
		return 0
	end
end

return Jump