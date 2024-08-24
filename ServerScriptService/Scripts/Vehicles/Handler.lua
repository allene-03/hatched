-- Services
local Replicated = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local PhysicsService = game:GetService('PhysicsService')
local MarketplaceService = game:GetService('MarketplaceService')
local Players = game:GetService('Players')

-- Modules
local DataModule = require(ServerScriptService.Modules.Data.Consolidate)
local Inventory = require(ServerScriptService.Modules.Inventory.Core)
local Core = require(ServerScriptService.Modules.Vehicles.Core)

local Settings = require(Replicated.Modules.Utility.Settings)
local Products = require(Replicated.Modules.Products.Core)
local CollisionHandler = require(Replicated.Modules.Utility.Collisions)
local Utility = require(Replicated.Modules.Vehicles.Utility)
local VehiclesData = require(Replicated.Modules.Vehicles.Core)

-- Remotes
local Handling = Replicated.Remotes.Vehicles.Handling
local Exchanging = Replicated.Remotes.Vehicles.Exchanging
local Notify = Replicated.Remotes.Systems.ServerNotify

-- Assets
local FlipGyro = Replicated.Assets.Physics.Vehicles.Gyro
local HeadlightLights = Replicated.Assets.Lighting.Vehicles.Headlights
local Vehicles = Replicated.Assets.Vehicles --remove

-- Other
local Repository = Settings:Create('Folder', 'Vehicles', workspace)
local Buildings, Homes = workspace:WaitForChild('Buildings'), workspace:WaitForChild('Homes')

-- Stored data table
local OwnsLudicrous = {}
local TrackingVehicles = {}

-- Server-client functions
local function PerformChecks(Player, Arguments, CheckIfInSeat)	
	if type(Arguments) == 'table' and Arguments.Vehicle and typeof(Arguments.Vehicle) == 'Instance' then
		local TrackedVehicle = TrackingVehicles[Player]
		
		if (TrackedVehicle and TrackedVehicle.Vehicle and TrackedVehicle.Vehicle == Arguments.Vehicle) then
			local Character, Vehicle = Player.Character, TrackedVehicle.Vehicle
			
			if (Character and Character.PrimaryPart) and (Vehicle:FindFirstChild('Seat') and (Vehicle.Seat.Position - Character.PrimaryPart.Position).Magnitude <= 50) then
				if CheckIfInSeat then
					local Humanoid = Character:FindFirstChild('Humanoid')
					
					if Humanoid then
						if Vehicle.Seat.Occupant == Humanoid then
							return TrackedVehicle
						end
					end
				else
					return TrackedVehicle
				end
			end
		end
	end
end

local function PerformPassengerChecks(Player, Arguments)
	if (type(Arguments) == 'table') and (Arguments.Seat and typeof(Arguments.Seat) == 'Instance' and Arguments.Seat.ClassName == 'Seat' and Arguments.Seat.Parent) then
		local Character, Seat = Player.Character, Arguments.Seat
		local Passengers = Seat.Parent
		local TrackedVehicle

		-- We find the matching vehicle from the trackingVehicles list		
		for _, TrackingVehicle in pairs(TrackingVehicles) do
			if (TrackingVehicle.Vehicle and Passengers.Parent) and (Passengers.Parent == TrackingVehicle.Vehicle) then
				TrackedVehicle = TrackingVehicle
				break
			end
		end
		
		if (TrackedVehicle) and (Character and Character.PrimaryPart) and (Character.PrimaryPart.Position - Seat.Position).Magnitude <= 50 then
			return TrackedVehicle, Seat
		end
	end
end

-- Functions
local function DeactiveDriverSeat(VehicleSeat)
	-- Look for weld to destroy
	local SeatWeld = VehicleSeat:FindFirstChild('SeatWeld') or VehicleSeat:FindFirstChildOfClass('Weld')

	if SeatWeld then
		SeatWeld:Destroy()
	end
end

local function DeactivatePassengerSeat(Seat)
	local SeatWeld = Seat:FindFirstChild('SeatWeld') or Seat:FindFirstChildOfClass('Weld')

	if SeatWeld then
		SeatWeld:Destroy()
	end
end

local function SetModelMassless(Model, Massless)
	if not Model then
		return
	end
	
	for _, Object in pairs(Model:GetDescendants()) do
		if Object:IsA('BasePart') then
			Object.Massless = Massless
		end
	end
end

local function SetOwnership(Vehicle, Player)
	if not Vehicle or not Vehicle:FindFirstChild('Seat') or not Vehicle.Parent then
		return
	end
	
	Vehicle.Seat:SetNetworkOwner(Player or nil)
end

local function CheckBuildingCollisions(Building, ModelCFrame, ModelSize)
	local Interior, Exterior = Building:FindFirstChild('Interior'), Building:FindFirstChild('Exterior')
	local Checking
	
	if Interior and Exterior then
		Checking = {Interior, Exterior}
	else
		warn('Home does not have interior and exterior.')
		Checking = {Building}
	end
	
	for _, CheckingArea in pairs(Checking) do
		local CheckingAreaCFrame, CheckingAreaSize = CheckingArea:GetBoundingBox()
		
		if Settings:CheckPartCollision(ModelCFrame, ModelSize, CheckingAreaCFrame, CheckingAreaSize) then
			print(1, CheckingArea)
			return false
		end
	end
	
	return true
end

local function CheckIfPositionAvailable(Model)
	local ModelCFrame, ModelSize = Model:GetBoundingBox()
	
	for _, Home in pairs(Homes:GetChildren()) do
		if not CheckBuildingCollisions(Home, ModelCFrame, ModelSize) then
			print(2)
			return false
		end
	end
	
	for _, Building in pairs(Buildings:GetChildren()) do
		if not CheckBuildingCollisions(Building, ModelCFrame, ModelSize) then
			print(3)
			return false
		end
	end
	
	return true
end

local function SetupVehicle(Vehicle, Configuration)
	local Body = Vehicle.Body
	local Mechs = Vehicle.Mechs
	local Seat = Vehicle.Seat
	local WheelTexture = Vehicle.WheelTexture
	
	-- Set it's primary part to something
	Vehicle.PrimaryPart = Vehicle.Primary

	for _, Part in pairs(Body:GetDescendants()) do
		if Part:IsA("BasePart") then
			Utility.SetBaseProperties(Part, Configuration.BodyProperties)
			Utility.Weld(Part, Vehicle.Primary)
		end
	end
	
	-- Set the wheels base properties
	if WheelTexture.ClassName == 'Model' then
		for _, Part in pairs(WheelTexture:GetDescendants()) do
			if Part:IsA('BasePart') then
				Utility.SetBaseProperties(Part, Configuration.WheelConfiguration)
			end
		end
	else
		Utility.SetBaseProperties(WheelTexture, Configuration.WheelConfiguration)
	end
	
	-- Replace the wheels
	for _, Mech in pairs(Mechs:GetChildren()) do
		local Wheel = Mech.Wheel
		Wheel.Transparency = 1
				
		Utility.ApplyWheelTexture(Wheel, WheelTexture)
		Utility.PhysicalFromTable(Configuration.WheelProperties, Wheel)
		
		CollisionHandler:HandleSelf(Wheel, 'Wheels')
	end
	
	-- Turn off seat collisions
	local Passengers = Vehicle:FindFirstChild('Passengers')
	
	if Passengers then
		for _, Passenger in pairs(Passengers:GetChildren()) do
			Passenger.Disabled = true
			Passenger.CanCollide = false
		end
	end
	
	-- Handle the seating
	Seat.CanCollide = false
	Seat.Disabled = true
	Seat.HeadsUpDisplay = false
	
	-- Add the lighting for the headlights
	if Body:FindFirstChild('Headlights') then
		for _, Part in pairs(Body.Headlights:GetChildren()) do
			if Part:IsA('BasePart') then
				local Light = HeadlightLights:Clone()
				Light.Name = 'HeadlightLights'
				Light.Enabled = false
				Light.Parent = Part
			end
		end
	end
	
	-- Add the gyro and position for flipping the vehicle
	local Gyro = FlipGyro:Clone()
	Gyro.Name = 'FlipGyro'
	Gyro.MaxTorque = Vector3.new(0, 0, 0)
	Gyro.Parent = Vehicle.PrimaryPart
	
	-- Collision group of body and destroy wheel texture
	CollisionHandler:HandleDescendantsAndAdded(Body, 'Body')
	WheelTexture:Destroy()
end

local function HandleClientEvents(Player, Mode, Arguments)
	if Mode == 'Equipping' then
		if not Settings:SetDebounce(Player, 'EquipVehicle', 7.5) then
			Notify:FireClient(Player, 'Please wait a couple seconds before spawning another vehicle.')
			return
		end
		
		local PlayerData = DataModule:Get(Player)

		if not PlayerData then
			return
		end

		local VehicleInventory, VehicleInventoryPath = PlayerData.Inventory.Vehicles, DataModule:TableSet('Inventory', 'Vehicles')
		local VehicleFolder = Core:Confirm(VehicleInventory, VehicleInventoryPath, Arguments)

		if VehicleFolder then
			local Character = Player.Character

			if not Character or not Character:FindFirstChild('HumanoidRootPart') then
				return
			end
			
			local VehicleModel, Vehicle = Core:Spawn(VehicleFolder)
			local Root = Character:FindFirstChild('HumanoidRootPart')

			-- This needs to go before the CheckIfPositionAvailable
			if Root and VehicleModel then
				VehicleModel:SetPrimaryPartCFrame(CFrame.new((Root.Position) + (Root.CFrame.LookVector * 1.5) + (Root.CFrame.UpVector * 2)))
			else
				VehicleModel:Destroy()
				return
			end
			
			-- Check that it's position is available
			if not CheckIfPositionAvailable(VehicleModel) then
				Notify:FireClient(Player, 'Your vehicle cannot be spawned in this area.')
				VehicleModel:Destroy()
				return
			end

			-- Unequip the old car
			HandleClientEvents(Player, 'Unequipping')

			-- Set the player to tracking owner
			local TrackingVehicle = {
				Vehicle = VehicleModel,
				Folder = VehicleFolder,
				Position = VehicleModel.Seat.Position,

				LastInSeat = tick(),
				Time = tick(),

				Headlights = false,
				Ludicrous = false,
				Flipping = false,
				Locked = false,
			}
			
			TrackingVehicles[Player] = TrackingVehicle
			
			-- Parent this
			VehicleModel.Parent = Repository

			-- Set ownership
			SetOwnership(VehicleModel)

			-- Setup vehicle events
			local CurrentDriver, CurrentDriverCharacter
			local CurrentPassengers = {}
			
			-- Ancestry changed events
			VehicleModel.AncestryChanged:Connect(function()
				SetOwnership(VehicleModel)

				if not VehicleModel:IsDescendantOf(game) then
					for _, Passenger in pairs(CurrentPassengers) do
						Handling:FireClient(Passenger.Player, 'Sitting')
						SetModelMassless(Passenger.Character)
					end
					
					if CurrentDriver then
						TrackingVehicle.LastInSeat = tick()

						Handling:FireClient(CurrentDriver, 'Driving')
						SetModelMassless(CurrentDriverCharacter) -- not CurrenDriver.Character as that would set a perhaps respawned player to massless
					end

					CurrentDriver, CurrentDriverCharacter = nil, nil
					CurrentPassengers = nil
				end
			end)
			
			local Passengers = VehicleModel:FindFirstChild('Passengers')
			
			if Passengers then
				for _, Passenger in pairs(Passengers:GetChildren()) do					
					Passenger:GetPropertyChangedSignal('Occupant'):Connect(function()
						local PassengerTable = CurrentPassengers[Passenger]
						
						if PassengerTable then
							Handling:FireClient(PassengerTable.Player, 'Sitting')
							SetModelMassless(PassengerTable.Character)
						end
						
						CurrentPassengers[Passenger] = nil
						
						-- Before checking for another, make sure the model exists
						if not Passenger.Parent then
							return
						end

						local Occupant = Passenger.Occupant

						if Occupant then
							local Sitting = Players:GetPlayerFromCharacter(Occupant.Parent)
							CurrentPassengers[Passenger] = {Player = Sitting, Character = Sitting.Character}
							
							SetModelMassless(Sitting.Character, true)
							Handling:FireClient(Sitting, 'Sitting', {Vehicle = VehicleModel})
						end
					end)
				end
			end

			VehicleModel.Seat:GetPropertyChangedSignal('Occupant'):Connect(function()				
				if CurrentDriver then
					TrackingVehicle.LastInSeat = tick()
					Handling:FireClient(CurrentDriver, 'Driving')
					SetModelMassless(CurrentDriverCharacter)
				end

				SetOwnership(VehicleModel)
				CurrentDriver, CurrentDriverCharacter = nil, nil
				
				-- Before checking for another, make sure the model exists
				if not VehicleModel:FindFirstChild('Seat') then
					return
				end

				local Occupant = VehicleModel.Seat.Occupant

				if Occupant then
					local Driver = Players:GetPlayerFromCharacter(Occupant.Parent)

					if (Driver == Player) then
						CurrentDriver, CurrentDriverCharacter = Driver, Driver.Character
						TrackingVehicle.LastInSeat = nil

						SetModelMassless(CurrentDriverCharacter, true)
						SetOwnership(VehicleModel, CurrentDriver)

						Handling:FireClient(CurrentDriver, 'Driving', {Vehicle = VehicleModel, Identifier = Arguments.Vehicle, Configuration = Vehicle.Configuration})
					else
						DeactiveDriverSeat(VehicleModel.Seat)
					end
				end
			end)
			
			-- Let the know they own the vehicle
			Handling:FireClient(Player, 'Spawned', {Vehicle = VehicleModel})

			-- Now place the player in the car since they spawned it
			local Humanoid = Character:FindFirstChild('Humanoid')

			if Humanoid then
				task.wait(0.75)

				-- Make sure they haven't despawned in that short time
				if VehicleModel and VehicleModel:FindFirstChild('Seat') then
					VehicleModel.Seat:Sit(Humanoid)
				end
			end
		end
	elseif Mode == 'Unequipping' then
		if TrackingVehicles[Player] then
			if TrackingVehicles[Player]['Vehicle'] then
				-- Let the client know it's been removed and destroy
				Handling:FireClient(Player, 'Despawned', {Vehicle = TrackingVehicles[Player]['Vehicle']})
				TrackingVehicles[Player]['Vehicle']:Destroy()
			end

			TrackingVehicles[Player] = nil

			-- Wait so it's not so bad latency-wise
			task.wait(0.5)
		end
	elseif Mode == 'Driving' then
		local TrackedVehicle = PerformChecks(Player, Arguments)

		if TrackedVehicle then
			local Character = Player.Character 

			if Character then
				local Humanoid = Character:FindFirstChild('Humanoid')

				if Humanoid and (TrackedVehicle.Vehicle and TrackedVehicle.Vehicle:FindFirstChild('Seat')) then
					TrackedVehicle.Vehicle.Seat:Sit(Humanoid)
				end
			end
		end			
	elseif Mode == 'Locking' then
		local TrackedVehicle = PerformChecks(Player, Arguments, true)

		if TrackedVehicle then
			TrackedVehicle.Locked = not TrackedVehicle.Locked
			
			if TrackedVehicle.Locked then
				local Passengers = TrackedVehicle.Vehicle:FindFirstChild('Passengers')

				if Passengers then
					for _, Passenger in pairs(Passengers:GetChildren()) do
						local Occupant = Passenger.Occupant
						
						if Occupant and Occupant.Parent then
							local Player = Players:GetPlayerFromCharacter(Occupant.Parent)
							
							if Player then
								Notify:FireClient(Player, 'The owner of this vehicle has locked it.')
							end
							
							DeactivatePassengerSeat(Passenger)
						end
					end
				end
			end
		end
	elseif Mode == 'Headlights' then
		local TrackedVehicle = PerformChecks(Player, Arguments, true)

		if TrackedVehicle then
			local VehicleBody = TrackedVehicle.Vehicle and TrackedVehicle.Vehicle:FindFirstChild('Body')

			if VehicleBody then
				local Headlights = VehicleBody:FindFirstChild('Headlights')

				if Headlights then
					TrackedVehicle.Headlights = not TrackedVehicle.Headlights

					for _, Part in pairs(Headlights:GetChildren()) do
						if TrackedVehicle.Headlights and Part.Material ~= Enum.Material.Neon then
							Part.Material = Enum.Material.Neon
						elseif Part.Material ~= Enum.Material.SmoothPlastic then
							Part.Material = Enum.Material.SmoothPlastic
						end

						if Part:FindFirstChild('HeadlightLights') then
							Part.HeadlightLights.Enabled = TrackedVehicle.Headlights
						end
					end
				end
			end
		end
	elseif Mode == 'Sitting' then
		local TrackedVehicle, Seat = PerformPassengerChecks(Player, Arguments)
		
		-- If it's the same player and it's locked then it's fine
		if (TrackedVehicle) and (Seat and not Seat.Occupant) then
			if (not TrackedVehicle.Locked) or (TrackingVehicles[Player] == TrackedVehicle) then
				local Character = Player.Character

				if Character then
					local Humanoid = Character:FindFirstChild('Humanoid')

					if Humanoid then
						Seat:Sit(Humanoid)
					end
				end
			else
				Notify:FireClient(Player, 'This vehicle is locked.')
			end
		end
	elseif Mode == 'Flipping' then
		local TrackedVehicle = PerformChecks(Player, Arguments, true)

		if TrackedVehicle and not TrackedVehicle.Flipping then
			local Primary = TrackedVehicle.Vehicle and TrackedVehicle.Vehicle.PrimaryPart

			if Primary then
				local Gyro = Primary:FindFirstChild('FlipGyro')

				if Gyro then
					TrackedVehicle.Flipping = true
					
					Gyro.CFrame = CFrame.new(Primary.Position, Primary.Position + Vector3.new(Primary.CFrame.LookVector.X, 0, Primary.CFrame.LookVector.Z))
					Gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
				
					task.wait(2)
					Gyro.MaxTorque = Vector3.new(0, 0, 0)
					task.wait(2)

					-- Ensures that the table hasn't been GCed
					if TrackedVehicle then
						TrackedVehicle.Flipping = false
					end
				end
			end
		end
	elseif Mode == 'Ludicrous' then
		local TrackedVehicle = PerformChecks(Player, Arguments, true)

		if TrackedVehicle then
			-- This segment does the setting of the ludicrous to true if the player actually owns the pass
			if not OwnsLudicrous[Player] then
				local LudicrousPassId = Products:FetchProductId('Gamepasses', 'Ludicrous Mode')
				local Success, OwnsPass = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, LudicrousPassId)

				if Success then
					if OwnsPass then
						OwnsLudicrous[Player] = true
					else
						Handling:FireClient(Player, 'Ludicrous', {Action = 'Purchase', Id = LudicrousPassId})
					end
				end
			end

			-- Handles ludicrous toggle after set by previous segment
			if OwnsLudicrous[Player] then
				if TrackedVehicle.Ludicrous then
					TrackedVehicle.Ludicrous = false
				else
					TrackedVehicle.Ludicrous = true
				end

				Handling:FireClient(Player, 'Ludicrous', {Action = 'Activate', Ludicrous = TrackedVehicle.Ludicrous})
			end
		end
	end
end

-- Longterm events
Exchanging.OnServerInvoke = function(Player, Mode, Arguments)
	local PlayerData = DataModule:Get(Player)
	
	if not PlayerData then
		return
	end
	
	if Mode == 'Purchasing' then
		if type(Arguments) == 'table' and Arguments.Value and type(Arguments.Value) == 'string' then
			local VehicleInfo = VehiclesData['Vehicles'][Arguments.Value]
			
			if VehicleInfo then
				local Merit = PlayerData.Merit

				if Merit.Currency >= VehicleInfo.Price then
					if Inventory:CheckRequirements(PlayerData.Inventory.Vehicles) then
						DataModule:Set(Player, 'Set', {
							Directory = Merit,
							Key = 'Currency',
							Value = Merit.Currency - VehicleInfo.Price,
							Default = 'IntValue',
							Path = {'Merit'}
						})

						Inventory:Add(Player, 'Vehicles', Core:Create(VehicleInfo.Folder))
					else
						Notify:FireClient(Player, 'The maximum number of vehicles you can store is ' .. tostring(Inventory.Settings.MaxItemsPerCategory) .. '.')
					end
				end
			end
		end
	elseif Mode == 'Selling' then
		local VehicleInventory, VehicleInventoryPath = PlayerData.Inventory.Vehicles, DataModule:TableSet('Inventory', 'Vehicles')
		local VehicleFolder = Core:Confirm(VehicleInventory, VehicleInventoryPath, Arguments)
		
		if VehicleFolder then
			local Merit, MeritPath = PlayerData.Merit, {'Merit'}
			local VehicleValue = VehiclesData['Vehicles'][VehicleFolder.Type]
			
			if VehicleValue then
				local ResaleValue = math.round(VehicleValue.Price * VehiclesData.SellPercentage)
				local IsEquipped = TrackingVehicles[Player] and (TrackingVehicles[Player]['Folder'] == VehicleFolder)
				
				if IsEquipped then
					HandleClientEvents(Player, 'Unequipping')
				end
				
				local Index = Settings:Index(VehicleInventory, VehicleFolder)

				if Index then
					DataModule:Set(Player, 'Remove', {
						Directory = VehicleInventory,
						Key = Index,
						Path = VehicleInventoryPath
					})

					DataModule:Set(Player, 'Set', {
						Directory = Merit,
						Key = 'Currency',
						Value = Merit.Currency + ResaleValue,
						Default = 'IntValue',
						Path = MeritPath
					})

					return true
				end
			end
		end
	elseif Mode == 'Customizing' then
		local VehicleInventory, VehicleInventoryPath = PlayerData.Inventory.Vehicles, DataModule:TableSet('Inventory', 'Vehicles')
		local VehicleFolder = Core:Confirm(VehicleInventory, VehicleInventoryPath, {Vehicle = Arguments.Identifier})
		local TrackedVehicle = PerformChecks(Player, {Vehicle = Arguments.Vehicle}, true)
		
		if TrackedVehicle and VehicleFolder then
			local VehicleCustomized, VehicleCustomizedPath = VehicleFolder.Customized, DataModule:TableInsert(VehicleInventoryPath, Arguments.Identifier, 'Customized')
			local Changes = Arguments.Customize
			
			if type(Changes) == 'table' then
				local MainVehicleBody = TrackedVehicle.Vehicle:FindFirstChild('Body') and TrackedVehicle.Vehicle.Body:FindFirstChild('Main')
				
				local ConfirmedChanges = {Color = {}, Glow = nil}
				local Price = 0
				
				-- Handle color stuff
				if (Changes.Color and type(Changes.Color) == 'table') then	
					for ColorGroup, Color in pairs(Changes.Color) do
						-- Preliminary check to ensure that color is a color and that the color group exists on vehicle
						if typeof(Color) == 'Color3' and MainVehicleBody:FindFirstChild(ColorGroup) then
							Price += math.round(VehiclesData.Customize.ColorCostPercentage * VehiclesData['Vehicles'][VehicleFolder.Type]['Price'])
							ConfirmedChanges['Color'][ColorGroup] = Color
						end
					end
				end
				
				-- Handle glow stuff
				if Changes.Glow then
					if not VehicleCustomized.Glow then
						Price += math.round(VehiclesData.Customize.GlowCostPercentage * VehiclesData['Vehicles'][VehicleFolder.Type]['Price'])
					end
					
					ConfirmedChanges.Glow = true
				else
					Price += 0
					ConfirmedChanges.Glow = nil
				end
				
				-- Finally we actually set the data
				local Merit = PlayerData.Merit
				
				if (Merit and Merit.Currency) and (Merit.Currency >= Price) then
					DataModule:Set(Player, 'Set', {
						Directory = Merit,
						Key = 'Currency',
						Value = Merit.Currency - Price,
						Path = {'Merit'}
					})
					
					for Group, Color in pairs(ConfirmedChanges.Color) do
						DataModule:Set(Player, 'Set', {
							Directory = VehicleCustomized.Color,
							Key = Group,
							Value = Settings:FromColor(Color),
							Path = DataModule:TableInsert(VehicleCustomizedPath, 'Color')
						})
					end
					
					DataModule:Set(Player, 'Set', {
						Directory = VehicleCustomized,
						Key = 'Glow',
						Value = ConfirmedChanges.Glow,
						Path = VehicleCustomizedPath
					})
					
					Core:AddCustomization(TrackedVehicle.Vehicle, VehicleFolder)
				end
			end
		end
	end
end

-- Added Events
local function CharacterAdded(Player)
	-- When they die/respawn, remove their vehicle. This can be removed later on if it gets frustrating
	if TrackingVehicles[Player] then
		HandleClientEvents(Player, 'Unequipping')
	end
end

local function PlayerAdded(Player)
	CharacterAdded(Player)
	
	Player.CharacterAdded:Connect(function()
		CharacterAdded(Player)
	end)
end

-- Runtime Events
Handling.OnServerEvent:Connect(HandleClientEvents)
Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(Player)
	-- Unequip on leave
	HandleClientEvents(Player, 'Unequipping')
	OwnsLudicrous[Player] = nil
end)

-- Server checks and despawner
task.spawn(function()
	while true do
		for Player, VehicleTable in pairs(TrackingVehicles) do
			local VehicleSeat = VehicleTable.Vehicle:FindFirstChild('Seat')
			
			if VehicleSeat then
				local CurrentPosition, CurrentTime = VehicleSeat.Position, tick()
				
				-- NOTE: We don't check for VehicleTable.Ludicrous as the check would kick them out of their vehicle
				-- as it toggles off immediately and it takes a lot longer to slow down to non-ludicrous speeds. Instead,
				-- we just check if they own it, which takes care of this issue
				local MaximumVehicleSpeed = (Core.Restrictions.MaximumVehicleSpeed) * ((OwnsLudicrous[Player] and 2) or 1)
				
				-- Kick them out of seat if violated, revoking network ownership in another thread
				if (CurrentPosition - VehicleTable.Position).Magnitude / (CurrentTime - VehicleTable.Time) >= MaximumVehicleSpeed then
					DeactiveDriverSeat(VehicleSeat)
				end
				
				-- Set new table values
				VehicleTable.Position = CurrentPosition
				VehicleTable.Time = CurrentTime
				
				-- After setting, check if they are despawning. This goes last as it sets all the previous values 
				-- above to nil if successful
				if VehicleTable.LastInSeat and (CurrentTime - VehicleTable.LastInSeat) >= Core.DespawnTime then
					HandleClientEvents(Player, 'Unequipping')
				end
			end
		end
		
		task.wait(1 / Core.Restrictions.CheckRate)
	end
end)

-- Main sequence
for _, Vehicle in pairs(Vehicles:GetChildren()) do
	local VehicleModel, VehicleConfig = Vehicle.Models.Main, Vehicle.Configuration
	SetupVehicle(VehicleModel, require(VehicleConfig))
end

-- Debounce for each remote action

-- Lag thing when you jump outta car:
--		Could setNetworkOwnershipAuto after (but that would allow players to exploit without getting kicked from seat)
--		If you did that, you could make it so that on punishment it unequips vehicle

-- Don't have to do this, but you could initialize a bounding box for each home/building on initialization and added,
-- use these boxes for the Zone (of homes), and perform GetPartBoundsInBox() with isDescendantOf(Homes, Buildings) to
-- see if it's spawning in a home instead of iterating thru every home/building interior and exterior