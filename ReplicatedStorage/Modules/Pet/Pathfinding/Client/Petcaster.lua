--<< MODULE >>
local Petcaster = {}

--<< SERVICES >>
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PetStorage = workspace:WaitForChild('Pets')

--<< MODULES >>
local Raycast = require(script.Raycast)
local Spring = require(script.Parent.Spring)

local JUMPCHECKS = 4
local JUMPDEPTH = 1
local MAXJUMPDISTANCE = 5

--<< TRACKING LIST >>
local CharactersInWorkspace = {}

--<< SETTINGS >>
local PetDistanceIdeal = 5
local PetWidth = 2

--<< PERM-SETTINGS >>
-- PetDistanceMinimum: When the pet raycasts to the side and the side is blocked, if the distance between
-- the character and the ray is greater than this obstacle it will try to dodge the obstacle instead of going
-- to the next direction priority (back). In short, the lower this number is, the more attempts it will try
-- to dodge by going to the other side versus switching direction priorities. 
local PetDistanceMinimum = 2.15

local Directions = {
	Right = Vector3.new(1, 0, 0);
	Back = Vector3.new(0, 0, 1);
	Left = Vector3.new(-1, 0, 0);
	Front = Vector3.new(0, 0, -1);
}

local DirectionPriorities = {"Right", "Back"}

local RaycastDepth = 10
local DownDepth = Vector3.new(0, -RaycastDepth, 0)

--<< GLOBALS>>
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer

local Character = Player.Character or Player.CharacterAdded:Wait()
local Parameters

--<< UTILITY >>
local function Index(Table, Value)
	for Item, Val in pairs(Table) do
		if Val == Value then
			return Item, Val
		end
	end
end

--<< MODULE >>
local function RefreshParameters(Characters)
	local FilteredInstances = {}
	
	-- Add all the different instances to the new filtered list
	for _, FilteringChar in pairs(Characters) do
		table.insert(FilteredInstances, FilteringChar)
	end
	
	table.insert(FilteredInstances, Character)
	table.insert(FilteredInstances, PetStorage)
		
	-- Set the parameters
	Parameters = RaycastParams.new()
	Parameters.FilterDescendantsInstances = FilteredInstances
	Parameters.FilterType = Enum.RaycastFilterType.Blacklist
	Parameters.IgnoreWater = true
	
	-- Update the parameters
	Raycast.UpdateParams(Parameters)
end

local function CharacterAdded(AddedChar)
	if not AddedChar then
		return
	end

	if AddedChar == Player.Character then
		Character = AddedChar
	else
		table.insert(CharactersInWorkspace, AddedChar)
	end

	RefreshParameters(CharactersInWorkspace)
end

local function CharacterRemoving(AddedChar)
	local IndexCharacter = Index(CharactersInWorkspace, AddedChar)

	if IndexCharacter then
		table.remove(CharactersInWorkspace, IndexCharacter)
	end

	RefreshParameters(CharactersInWorkspace)
end

local function PlayerAdded(Player)
	Player.CharacterAdded:Connect(CharacterAdded)
	Player.CharacterRemoving:Connect(CharacterRemoving)

	CharacterAdded(Player.Character)
end

local function PlayerRemoving(Player)
	local RemovingChar = Player.Character

	if not RemovingChar then
		return
	end

	local IndexCharacter = Index(CharactersInWorkspace, RemovingChar)

	if IndexCharacter then
		table.remove(CharactersInWorkspace, IndexCharacter)
	end

	RefreshParameters(CharactersInWorkspace)
end

local function GetDirection(side_ray, down_ray, path_ray, opposite_path_ray, pet_spring)
	local root = Character.PrimaryPart
	local pathfinding = {flag = false, goal = nil}
	
	if not root then
		return "Idle"
	end
	
	for _, direction_name in ipairs(DirectionPriorities) do
		local direction = Directions[direction_name]
		local side_origin = root.CFrame
		local side_result = side_ray:LocalCast(side_origin, (PetDistanceIdeal+PetWidth)*direction)
		local down_origin;
		
		if side_result and (side_result.Position-root.Position).Magnitude >= PetDistanceMinimum then
			down_origin = side_result.Position - ((root.CFrame - root.Position)*(direction * PetWidth * 1.5)) -- this is somehow issue
		elseif not side_result then
			down_origin = side_origin * ((PetDistanceIdeal+PetWidth)*direction)
		else
			continue
		end
		
		local down_result = down_ray:Cast(down_origin, DownDepth)
		
		if down_result then
			local goal = down_result.Position + Vector3.new(0, 1/2, 0)
			
			local path_origin = goal
			local path_result = path_ray:Cast(path_origin, pet_spring.Position-goal)
			
			local opp_path_origin = pet_spring.Position
			local opp_path_result = opposite_path_ray:Cast(opp_path_origin, goal-pet_spring.Position)

			if (not path_result or not path_result.Instance) and (not opp_path_result or not opp_path_result.Instance) then
				return "Active", goal
			else
				if not pathfinding.flag then
					pathfinding.flag = true
					pathfinding.goal = goal
				end
				
				continue
			end
		end
	end
	
	if pathfinding.flag then
		return 'Pathfinding', pathfinding.goal
	else
		return 'Idle'
	end
end

function Petcaster.TakeGlobals(pdi, pw)
	PetDistanceIdeal = pdi
	PetWidth = pw
end

function Petcaster.Bind(pet_spring, update, rate)
	local side_ray = Raycast.new("SideRay", Parameters)
	local down_ray = Raycast.new("DownRay", Parameters)
	local path_ray = Raycast.new("PathRay", Parameters)
	local opposite_path_ray = Raycast.new("OppPathRay", Parameters)
	local jump_ray = Raycast.new("JumpRay")
	
	local time_elapsed_between_update = 0
	local idling_start = 0
	local prev_pos = Vector3.new()
	
	local conn; conn = RunService.Heartbeat:Connect(function(dt)
		time_elapsed_between_update = time_elapsed_between_update + dt
		
		if time_elapsed_between_update >= 1 / rate then
			time_elapsed_between_update = 0
			
			if Character and Character:FindFirstChildOfClass("Humanoid") and Character:FindFirstChildOfClass("Humanoid").Health > 0 and Character.PrimaryPart then
				
				local state, goal = GetDirection(side_ray, down_ray, path_ray, opposite_path_ray, pet_spring)
				local jump = false
				
				if goal then
					if (goal - pet_spring.Position).Magnitude < 0.1 then
						state = "Idle"
					end
				end

				if state == "Active" then
					if idling_start ~= 0 then
						idling_start = 0
					end
					
					for i = 1,JUMPCHECKS do
						local jump_origin = pet_spring.Position:Lerp(goal, i/(JUMPCHECKS+1))
						local jump_result = jump_ray:Cast(jump_origin, Vector3.new(0,-JUMPDEPTH,0))

						if not jump_result then
							jump = true
							break
						end
					end
				end

				if state == "Idle" then
					idling_start = tick()
				else
					idling_start = 0
				end

				update(state, goal, jump)
			end
			
		end
	end)
	
	return {
	 	Unbind = function()
			conn:Disconnect()
		end;
		
		GetPosition = function()
			local state, goal = GetDirection(side_ray, down_ray, path_ray, opposite_path_ray, pet_spring)
			return goal
		end;
		
		GetCharLookVec = function()
			if Character and Character.PrimaryPart then
				return Character.PrimaryPart.CFrame.LookVector
			else
				return false
			end
		end,
	}
end

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

-- Main sequence
for _, Player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		PlayerAdded(Player)
	end)
end

RefreshParameters(CharactersInWorkspace)

return Petcaster