local Players = game:GetService('Players')
local PhysicsService = game:GetService('PhysicsService')

local CollisionHandler = {}

-- Functions
local function DisableCollisions(Descendant, Group)
	if Descendant:IsA('BasePart') then
		PhysicsService:SetPartCollisionGroup(Descendant, Group)
	end
end

local function EnableCollisions(Descendant)
	if Descendant:IsA('BasePart') then
		PhysicsService:SetPartCollisionGroup(Descendant, 'Default')
	end
end

-- Handle player collisions
function CollisionHandler:HandleDescendantsAndAdded(Object, Group)
	for _, Descendant in pairs(Object:GetDescendants()) do
		DisableCollisions(Descendant, Group)
	end
	
	Object.DescendantAdded:Connect(function(Descendant)
		DisableCollisions(Descendant, Group)
	end)
end

function CollisionHandler:HandleSelf(Object, Group)
	DisableCollisions(Object, Group)
end

-- Establish player constraints
PhysicsService:CreateCollisionGroup('Character')
PhysicsService:CollisionGroupSetCollidable('Character', 'Character', false)

-- Establish car constraints
PhysicsService:CreateCollisionGroup('Body')
PhysicsService:CollisionGroupSetCollidable('Body', 'Character', false)
PhysicsService:CollisionGroupSetCollidable('Body', 'Body', false) -- Change this to true if you want vehicles to collide

PhysicsService:CreateCollisionGroup('Wheels')
PhysicsService:CollisionGroupSetCollidable('Wheels', 'Character', false)
PhysicsService:CollisionGroupSetCollidable('Wheels', 'Body', false)
PhysicsService:CollisionGroupSetCollidable('Wheels', 'Wheels', false)

return CollisionHandler