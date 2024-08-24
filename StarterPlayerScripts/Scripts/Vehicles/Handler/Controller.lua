-- Services
local PhysicsService = game:GetService("PhysicsService")

-- References
local AV = 'AngularVelocity'
local AS = 'AngularSpeed'
local MT = 'MaxTorque'

-- Controller module
local Controller = {}

-- Set the constraints in use
function Controller:SetConstraints(SteerConstraint, DriveConstraint)
	self.SteerConstraint = SteerConstraint
	self.DriveConstraint = DriveConstraint
end

-- Turn wheel
function Controller:TurnWheel(Direction)
	self.SteerConstraint[AS] = Direction
end

-- Spins wheel
function Controller:SpinWheel(Direction, Speed)
	self.DriveConstraint[AV] = Direction * Speed
end

-- Set steer actuator type
function Controller:SetSteerType(Type)
	self.SteerConstraint.ActuatorType = Type
	self.SteerType = Type
end

-- Set drive actuator type
function Controller:SetDriveType(Type)
	self.DriveConstraint.ActuatorType = Type
	self.DriveType = Type
end

-- Set angle for steering
function Controller:SetSteerAngle(Angle)
	self.SteerConstraint.TargetAngle = Angle
end

-- Sets max torque for steer
function Controller:SetSteerTorque(Torque)
	self.SteerConstraint[self.SteerType .. MT] = Torque
end

-- Sets max torque for drive
function Controller:SetDriveTorque(Torque)
	self.DriveConstraint[self.DriveType .. MT] = Torque
end

return Controller