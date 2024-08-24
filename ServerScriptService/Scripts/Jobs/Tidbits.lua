local Replicated = game:GetService('ReplicatedStorage')
local TextService = game:GetService('TextService')
local SSS = game:GetService('ServerScriptService')
local Players = game:GetService('Players')

local DataModule = require(SSS.Modules.Data.Consolidate)
local Settings = require(Replicated.Modules.Utility.Settings)

local Models = workspace.Tidbits
local Remote = Replicated.Remotes.Tidbits.Server

local PlayerActions = {}

-- Aerospace
-- Add ragdoll to this soon?
local FloatDuration = 3 -- How long at a time you float
local StasisTime = 1 -- How much time to fall in between cycles
local FloatTimes = 5 -- How many times you float

PlayerActions.Aerospace = {}

local function getModelMass(Model)
	local Total = 0
	
	for _, Part in pairs(Model:GetDescendants()) do
		if Part:IsA('BasePart') then
			Total += Part.Mass
		end
	end
	
	return Total
end

-- Health
local SpeedDuration = 10 -- How long you're faster for
PlayerActions.Health = {}

-- Education
local Whiteboards = Models.Education.Whiteboards
local CharacterCap = 100

local function IndexBoard(Boards, Value)
	for _, Board in pairs(Boards:GetChildren()) do
		if Board:FindFirstChild('Index') and Board.Index.Value == Value then
			return Board
		end
	end
end

local function Distribute(TextFilteredInstance, BoardName)
	if TextFilteredInstance and typeof(TextFilteredInstance) == 'Instance' then
		local Text = TextFilteredInstance:GetNonChatStringForBroadcastAsync()
		Remote:FireAllClients('Education', {Text = Text or '####', Board = BoardName}) -- This should just directly change the board text here
	end
end

Remote.OnServerEvent:Connect(function(Player, Mode, Details)
	if Mode == 'Aerospace' then
		if PlayerActions['Aerospace'][Player] then
			return
		end
		
		local Character = Player.Character
		
		if Character then
			local Root = Character:FindFirstChild('HumanoidRootPart')
			
			if Root then
				PlayerActions['Aerospace'][Player] = true
				
				local Finished = false
				local TemporaryFloatJoint = Settings:Create('Attachment', 'FloatJoint', Root)
				
				local TemporaryAntigravity = Settings:Create('VectorForce', 'Antigravity')
				TemporaryAntigravity.RelativeTo = Enum.ActuatorRelativeTo.World
				TemporaryAntigravity.Force = Vector3.new(0, getModelMass(Character) * workspace.Gravity, 0)
				TemporaryAntigravity.Attachment0 = TemporaryFloatJoint
				
				task.spawn(function()
					while Finished == false do
						local Humanoid = Character:FindFirstChild('Humanoid')
						
						if Humanoid then
							Humanoid.Jump = true
						end
						
						task.wait(0.45)
					end
				end)
				
				for Time = 1, FloatTimes do
					TemporaryAntigravity.Parent = TemporaryFloatJoint.Parent
					
					task.wait(FloatDuration)
					TemporaryAntigravity.Parent = nil
					
					task.wait(StasisTime)
				end
				
				Finished = true
				
				-- This is in case the player has reset
				if TemporaryFloatJoint and TemporaryAntigravity then
					TemporaryFloatJoint:Destroy()
					TemporaryAntigravity:Destroy()
				end
				
				PlayerActions['Aerospace'][Player] = nil
			end
		end
	elseif Mode == 'Health' then
		if PlayerActions['Health'][Player] then
			return
		end

		local Character = Player.Character

		if Character then
			local Humanoid = Character:FindFirstChild('Humanoid')

			if Humanoid and Humanoid.Health > 0  then
				PlayerActions['Health'][Player] = true
				Humanoid.WalkSpeed += 10

				task.wait(SpeedDuration)

				if Humanoid then
					Humanoid.WalkSpeed -= 10
				end

				PlayerActions['Health'][Player] = nil
			end
		end
	elseif Mode == 'Education' then
		if not Details or type(Details) ~= 'table' then
			return
		end
		
		if Details.Name and Details.Text and type(Details.Name) == 'string' and type(Details.Text) == 'string' then
			local FilteredText = Details.Text
			
			if #FilteredText <= CharacterCap and #FilteredText:gsub("%s+", "") > 0 then
				local Board = IndexBoard(Whiteboards, Details.Name)
				
				if Board and Player.Character and ((Player.Character.PrimaryPart and Player.Character.PrimaryPart.Position - Board.Holder.Position).Magnitude <= 50) then
					local Filtered
					
					local Success, Error = pcall(function()
						Filtered = TextService:FilterStringAsync(FilteredText, Player.UserId)
					end)
					
					if Success then
						Distribute(Filtered, Details.Name)
					end
				end
			end
		end
	elseif Mode == 'Label' then
		local Piano, Character = Details.Piano, Player.Character
		
		if Character and Character.PrimaryPart then
			if Piano and Piano.Parent == Models.Label then
				local Seat = Piano:FindFirstChild('Seating') and Piano.Seating:FindFirstChild('Seat')
				
				if Seat and not Seat.Occupant and (Character.PrimaryPart.Position - Seat.Position).Magnitude <= 25 then
					Seat:Sit(Character:FindFirstChild('Humanoid'))
				end
			end
		end
	elseif Mode == 'Law' then
		local Desk, Character = Details.Desk, Player.Character

		if Character and Character.PrimaryPart then
			if Desk and Desk.Parent == Models.Law then
				local Seat = Desk:FindFirstChild('Seating') and Desk.Seating:FindFirstChild('Seat')

				if Seat and not Seat.Occupant and (Character.PrimaryPart.Position - Seat.Position).Magnitude <= 25 then
					Seat:Sit(Character:FindFirstChild('Humanoid'))
				end
			end
		end
	end
end)