local SSS = game:GetService('ServerScriptService')
local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local DataModule = require(SSS.Modules.Data.Consolidate)

local Settings = require(Replicated.Modules.Utility.Settings)
local Jobs = require(Replicated.Modules.Jobs.Core)

local Requesting = Replicated.Remotes.Jobs.Requesting
local Stealing = Replicated.Remotes.Jobs.Stealing

local SafeCooldown = {} 
local Safes = workspace.Safes

local DefaultJob = Jobs.Fields[Jobs.Default]
local CriminalJob = Jobs.Fields[Jobs.Criminal]

local Randomize =  Random.new()

local function IndexJob(FieldList, JobName)
	for _, Job in pairs(FieldList) do
		if Job.Name == JobName then
			return Job
		end
	end
end

local function CheckJobLocked(JobFolder)
	local CurrentField = Jobs['Fields'][JobFolder.Field]

	if CurrentField then
		local CurrentJob = IndexJob(CurrentField.List, JobFolder.Name)

		if CurrentJob and CurrentField.Locked then
			if JobFolder.LockedFor > 0 then
				return true, JobFolder.LockedFor
			end
		end
	end
end

local function PlayerCaught(Chance)
	-- Forked from SSS/Modules/Pet/Choice
	
	-- Spin = the lowest indice (Spin = 0.5 means 9.5, 10 | Spin = 0.1 means 9.1, 9.9 | Spin 1 means 9, 11)
	-- Maximum: The max percentage, default 100. If 200, 3.5% rate would translate to 7.0%
	local Spin, Maximum = 1, 100
	local New = Maximum / Spin
	
	local RandomNumber = Randomize:NextInteger(1, New)
	
	if Chance >= RandomNumber then
		return true
	end
end

-- Global paycheck function
local function GlobalPaycheck()
	while true do
		task.wait(Randomize:NextInteger(Jobs.Payment.Frequency.Minimum, Jobs.Payment.Frequency.Maximum))
		
		for _, Player in pairs(Players:GetPlayers()) do
			task.spawn(function()
				local Data = DataModule:Get(Player)
				
				if Data then
					local JobFolder = Data.Job
					
					if JobFolder then
						local CurrentField = Jobs['Fields'][JobFolder.Field]
						
						if CurrentField then
							local Merit, MeritPath = Data.Merit, DataModule:TableSet('Merit')
							
							-- If the job is not payless, or your lock time is over - receive payment
							if (not CurrentField.Payless) or (not CheckJobLocked(JobFolder)) then								
								DataModule:Set(Player, 'Set', {
									Directory = Merit,
									Key = 'Currency',
									Value = Merit.Currency + Jobs.Payment.Amount,
									Path = MeritPath
								})
							end
						end
					end
				end
			end)
		end
	end
end

-- Global safe cooldown function
local function GlobalSafeCooldown()
	local Cooldown = Jobs.Stealing.Cooldown
	
	while true do
		for Safe, Time in pairs(SafeCooldown) do
			if (os.time() - Time) >= Cooldown then
				Stealing:FireAllClients('Close', Safe.Door)
				Safe.Locked.Value = false
				SafeCooldown[Safe] = nil
			end
		end
		
		task.wait(5) -- Check around every two seconds
	end
end

-- Instead of using os.time(), we manually subtract the amount so the player can't leave to
-- evade cooldown
local function GlobalCriminalCooldown()
	local Rate = 30 -- How frequently is checked before removing that amount of time
	
	while true do
		task.wait(Rate)
		
		for Player, PlayerProfileData in pairs(DataModule.Profiles) do
			local Data = PlayerProfileData.Data
			
			if Data then
				local Job, JobPath = Data.Job, {'Job'}

				-- At 0 seconds, should it auto-switch you to default of unemployed?
				if (Job and Job.Field == Jobs.Criminal and Job.LockedFor > 0) then
					local NewLockedTime = Job.LockedFor - Rate
					NewLockedTime = NewLockedTime > 0 and NewLockedTime or 0

					DataModule:Set(Player, 'Set', {
						Directory = Job, 
						Key = 'LockedFor',
						Value = NewLockedTime,
						Default = 'IntValue',
						Path = JobPath
					})
				end
			end
		end
	end
end

local function PlayerAdded(Player)	
	local PlayerName = Player.Name
	local Saved
	
	repeat
		Saved = DataModule:Get(Player)
		task.wait(1)
	until (Saved or not Players:FindFirstChild(PlayerName))
	
	if Saved then
		if not Saved.Job then
			DataModule:Set(Player, 'Set', {
				Directory = Saved,
				Key = 'Job',
				Value = {Field = Jobs.Default, Name = IndexJob(DefaultJob.List, 'Default')['Name']},
			})
		else
			-- If their job doesn't exist then set it to the default
			local FoundField = Jobs['Fields'][Saved.Job.Field]
			
			if FoundField then
				local FoundJob = IndexJob(FoundField.List, Saved.Job.Name)
				
				if not FoundJob then
					DataModule:Set(Player, 'Set', {
						Directory = Saved,
						Key = 'Job',
						Value = {Field = Jobs.Default, Name = IndexJob(DefaultJob.List, 'Default')['Name']},
					})
				end
			else
				DataModule:Set(Player, 'Set', {
					Directory = Saved,
					Key = 'Job',
					Value = {Field = Jobs.Default, Name = IndexJob(DefaultJob.List, 'Default')['Name']},
				})
			end
		end
	end
end

Requesting.OnServerEvent:Connect(function(Player, Field, Job)
	local Data = DataModule:Get(Player)
	
	if Data then		
		local CurrentJobFolder = Data.Job
		
		if CurrentJobFolder then			
			-- If they are requesting for the same job, then return
			if CurrentJobFolder.Field == Field and CurrentJobFolder.Name == Job then
				return
			end
			
			local Locked, Time = CheckJobLocked(CurrentJobFolder)
			
			if Locked then
				Requesting:FireClient(Player, "You are a criminal and cannot change jobs for " .. Settings:Round(Time / 60) .. ' minutes.')
				return
			end
		end
		
		local ChosenField = Jobs['Fields'][Field]
				
		if ChosenField then
			if not ChosenField.NoSelect then
				local ChosenJob = IndexJob(ChosenField.List, Job)
				
				if ChosenJob then
					
					DataModule:Set(Player, 'Set', {
						Directory = Data,
						Key = 'Job',
						Value = {Field = Field, Name = Job},
					})
				end
			else
				Requesting:FireClient(Player, 'This job cannot be manually assigned.')
				return
			end
		end
	end
end)

Stealing.OnServerEvent:Connect(function(Player, Safe)
	if not Settings:SetDebounce(Player, 'RobSafe', Jobs.Stealing.PlayerCooldown) then
		return
	end
	
	local PreliminaryCheck = (Safe.Parent == Safes and Safe.Locked.Value == false)
	
	if PreliminaryCheck then
		local Character = Player.Character
		
		if Character then
			local Humanoid = Character:FindFirstChild('Humanoid')
			local CharacterRoot = Character.PrimaryPart
			
			-- Check if player is alive and if the player is close enough to prevent exploits
			if (Humanoid and Humanoid.Health > 0) and (CharacterRoot and (CharacterRoot.Position - Safe.Door.Main.Position).Magnitude <= Safe.Door.Main.Open.MaxActivationDistance) then
				local Data = DataModule:Get(Player)

				if Data then
					if not Data.Job then
						return
					end
					
					if Safe.Locked.Value == false then
						-- Lock the safe and establish the cooldown
						Safe.Locked.Value = true
						SafeCooldown[Safe] = os.time()
						
						local Caught, Text = PlayerCaught(Jobs.Stealing.CaughtChance), ''
						
						if Caught then
							-- Adds additional time, but adheres to cap
							if Data.Job.Field == Jobs.Criminal then
								local Job, JobPath = Data.Job, {'Job'}
								
								local NewLockedTime = Job.LockedFor + Jobs.Stealing.LockedTime
								NewLockedTime = (NewLockedTime > Jobs.Stealing.MaxLockedTime and Jobs.Stealing.MaxLockedTime) or NewLockedTime
								
								DataModule:Set(Player, 'Set', {
									Directory = Job,
									Key = 'LockedFor',
									Value = NewLockedTime,
									Default = 'IntValue',
									Path = JobPath
								})
								
								Text = "You've been caught stealing and are barred from receiving paychecks for an additional " .. Settings:Round(Jobs.Stealing.LockedTime / 60) .. " minutes. You have " .. Settings:Round(NewLockedTime / 60) .. " minutes before you will receive paychecks."
							else
								DataModule:Set(Player, 'Set', {
									Directory = Data,
									Key = 'Job',
									Value = {
										Field = Jobs.Criminal,
										Name = IndexJob(CriminalJob.List, 'Default')['Name'],
										LockedFor = Jobs.Stealing.LockedTime
									}
								})
								
								Text = "You've been caught stealing and are now a criminal for " .. Settings:Round(Jobs.Stealing.LockedTime / 60) .. " minutes. You will not receive paychecks during this time."
							end
						else
							local Giving = Randomize:NextInteger(Jobs.Stealing.Amount.Minimum, Jobs.Stealing.Amount.Maximum)
							local Merit, MeritPath = Data.Merit, DataModule:TableSet('Merit')

							DataModule:Set(Player, 'Set', {
								Directory = Merit,
								Key = 'Currency',
								Value = Merit.Currency + Giving,
								Path = MeritPath
							})
							
							Text = "You've successfully stolen " .. Giving .. " cash!"
						end
						
						Stealing:FireAllClients('Open', Safe.Door, {Player = Player, Text = Text})
					end
				end 
			end
		end
	end
end)

task.spawn(GlobalPaycheck)
task.spawn(GlobalSafeCooldown)
task.spawn(GlobalCriminalCooldown)

Players.PlayerAdded:Connect(PlayerAdded)

for _, Player in pairs(Players:GetPlayers()) do
	task.spawn(function()
		PlayerAdded(Player)
	end)
end

--[[ Data shape (visual purposes):
Job = {
	Field = nil,
	Name = nil,
	LockedFor = nil, -- Only if you're are a criminal
}