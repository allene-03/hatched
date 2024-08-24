-- Written by Inctus and heavily modified by yours truly

local Pathfinder = {}
Pathfinder.__index = Pathfinder

local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Core = require(script.Parent.Core)
local Settings = require(Replicated.Modules.Utility.Settings)

local Event = Replicated.Remotes.Pets.Pathfinding

-- Variables
local ControlConstraint
local MagnitudeBeforeForceTeleport = 50

local LimitInformation = {
	Table = {},
	TimeBeforeRequestReset = 1,
	MaxRequestsWithinTime = 10
}

-- Functions

--[[ Essentially 'anchors' the model so it no longer is subject to conventional physics and can have
its primary part set without interference. Note that we cannot actually anchor the pet as the 
client would no longer have network ownership of said model ]]
local function GetControlConstraint()
	local Control = Instance.new('BodyVelocity')
	Control.P = math.huge
	Control.Velocity = Vector3.new(0, 0, 0)
	Control.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	Control.Name = '_Control'

	return Control
end

local function NormalizeModel(Pet, Root)
	for _, Part in pairs(Pet:GetDescendants()) do
		if Part:IsA('BasePart') then
			Part.Anchored, Part.CanCollide = false, false
			Part.Massless = true
		end
	end
	
	local Control = ControlConstraint:Clone()
	Control.Parent = Pet.PrimaryPart	
	
	Pet.PrimaryPart.CFrame = Root.CFrame
end

local function SetModelOwner(Pet, Player)
	for _, Part in pairs(Pet:GetDescendants()) do
		if Part:IsA('BasePart') then
			Part:SetNetworkOwner(Player)
		end
	end
end

-- Decide whether this is worth the trouble or not while/after testing
local function ServerCheck(Pets)
	for PlayerId, PetInformation in pairs(Pets) do
		local Player = Players:GetPlayerByUserId(PlayerId)
		local Pet = PetInformation.Pet
		
		if (Player and Player.Character) and (Pet) then
			local Root = Player.Character.PrimaryPart

			if (Root and Pet.PrimaryPart) and (Pet.PrimaryPart.Position - Root.Position).Magnitude > MagnitudeBeforeForceTeleport then
				Pet.PrimaryPart.CFrame = Root.CFrame
			end
		end
	end
end

-- This function is essentially a remote event rate limiter for remotes that have variable request rates
-- Add this to settings?
local function RateLimit(Player)
	if (LimitInformation['Table'][Player] or 0) < LimitInformation.MaxRequestsWithinTime then
		LimitInformation['Table'][Player] = LimitInformation['Table'][Player] and LimitInformation['Table'][Player] + 1 or 1
		
		task.spawn(function()
			task.wait(LimitInformation.TimeBeforeRequestReset)
			
			if LimitInformation['Table'][Player] then
				if LimitInformation['Table'][Player] <= 1 then
					LimitInformation['Table'][Player] = nil
				else
					LimitInformation['Table'][Player] = LimitInformation['Table'][Player] - 1
				end
			end
		end)
		
		return true
	end
end

-- Set up the Pathfinder object
function Pathfinder.new()
	local self = setmetatable({}, Pathfinder)
	self.Pets = {}
	
	self.PetReceiveConnection = Event.OnServerEvent:Connect(function(...)
		self:Update(...)
	end)
	
	task.spawn(function()
		while true do
			ServerCheck(self.Pets)
			task.wait(1.5)
		end
	end)
	
	return self
end

-- Handling updates for other clients to play animations
function Pathfinder:Update(Player, ReceivedPetData)
	if RateLimit(Player) then
		local PetData = self.Pets[Player.UserId]
		
		if PetData and (PetData.Pet and PetData.Pet == ReceivedPetData.Pet) and (not PetData.IsDisabled) then
			PetData.State = ReceivedPetData.State
			PetData.JumpValue += (ReceivedPetData.Jump and 1 or 0)
			
			-- We don't need to send the disabled information because only the server uses it
			local UpdatingInformation = {
				State = PetData.State,
				JumpValue = PetData.JumpValue,
				Id = PetData.Id,
				Pet = PetData.Pet,
				Information = PetData.Information
			}
			
			Event:FireAllClients('Update', UpdatingInformation)
		end
	end
end

-- Temporarily disable the pathfinder
function Pathfinder:Disable(Player, PetModel, Action)
	local PetData = self.Pets[Player.UserId]
	
	if PetData then
		local DisabledTable = PetData.DisabledTable
		local Pet = PetData.Pet
		
		if DisabledTable and (Pet and PetModel == Pet) then
			DisabledTable[Action] = true
			
			if (Settings:Length(DisabledTable) >= 1) and (not PetData.IsDisabled) then
				PetData.IsDisabled = true
				
				if Pet.PrimaryPart and Pet.PrimaryPart:FindFirstChild('_Control') then
					Pet.PrimaryPart['_Control']:Destroy()
				end
				
				Event:FireAllClients('Remove', {Id = Player.UserId})
			end
		end
	end
end

-- Re-enable the pathfinder
function Pathfinder:Enable(Player, PetModel, Action)
	local PetData = self.Pets[Player.UserId]

	if PetData then
		local DisabledTable = PetData.DisabledTable
		local Pet = PetData.Pet

		if DisabledTable and (Pet and PetModel == Pet) then
			DisabledTable[Action] = nil
			
			local Character = Player.Character
			
			if (Settings:Length(DisabledTable) <= 0) and (PetData.IsDisabled) and (Character and Character:FindFirstChild('HumanoidRootPart')) then
				PetData.IsDisabled = nil
				
				NormalizeModel(Pet, Character.HumanoidRootPart)
				SetModelOwner(Pet, Player)

				Event:FireAllClients('Add', self.Pets[Player.UserId])
			end
		end
	end
end

-- Don't destroy the model as the main handler will do this
function Pathfinder:Unequip(Player)
	self.Pets[Player.UserId] = nil
	Event:FireAllClients('Remove', {Id = Player.UserId})
end

function Pathfinder:Equip(Player, Model, Information)
	local Character = Player.Character
	
	if Character then
		local Humanoid, Root = Character:FindFirstChild('Humanoid'), Character:FindFirstChild('HumanoidRootPart')
		
		if Root and (Humanoid and Humanoid.Health > 0) then
			local PetTable = {
				Pet = Model,
				Id = Player.UserId,
				State = nil,
				JumpValue = 0,
				IsDisabled = nil,
				DisabledTable = {},
				Information = Information
			}
			
			NormalizeModel(Model, Root)
			SetModelOwner(Model, Player)
			
			self.Pets[Player.UserId] = PetTable
			Event:FireAllClients('Add', PetTable)
			
			return true
		end
	end
end

-- Main sequence
ControlConstraint = GetControlConstraint()
return Pathfinder.new()