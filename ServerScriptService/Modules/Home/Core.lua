local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Settings = require(Replicated.Modules.Utility.Settings)
local Zone = require(Replicated.Modules.Utility.Zone)
local HomesData = require(Replicated.Modules.Home.Core)

local HomeAssets = Replicated.Assets.Homes

local Notify = Replicated.Remotes.Systems.ServerNotify
local BuildingAdded = Replicated.Remotes.Buildings.Added -- Everytime they spawn a new home

local Plots = workspace.Plots

local Home = {
	HomesFolder = Settings:Create('Folder', 'Homes', workspace),
	
	Plots = {}, -- Where all plots will be stored and availablity statistics
	StoredHomes = {}, -- Where all homes and associated data will be store
	PlayerConnections = {}, -- Where player spawn connections are stored
	
	PlayerHomeCap = 8, -- The maximum number of homes a player can have at a time
	PlayerHomeMinimum = 1, -- The minimum number of homes a player can have at a time
	
	DefaultPlotOrder = 10, -- The default order relevance for a plot that doesn't have an order value
	AlternateTeleportLocation = workspace.Map.Main.Baseplates.Mainplate, -- Another teleport location if there is no spawn in your plot
	SpawnCooldown = 90, -- How long it takes before you respawn another home
	
	RenameTextLimit = 12, -- The maximum amount of text a home rename can be
}

-- Forked from Modules/Utility/Settings
function Sort(Table)
	local Gap = math.floor(#Table / 2)

	while Gap > 0 do 
		for Iteration = Gap, #Table do
			local Temp = Table[Iteration]
			local Switch = Iteration

			while (Switch > Gap and Table[Switch - Gap]['Order'] > Temp['Order']) do
				Table[Switch] = Table[Switch - Gap]
				Switch -= Gap
			end

			Table[Switch] = Temp
		end

		Gap = math.floor(Gap / 2)
	end

	return Table
end

-- Forked and modified from Constrained/Jobs/Subandler
local function OrderedSort(Plots)
	local PlotsKeyList = {}

	for Key, Plot in pairs(Plots) do
		table.insert(PlotsKeyList, {
			Plot = Plot,
			Order = (Plot:FindFirstChild('Order') and Plot.Order.Value) or Home.DefaultPlotOrder,
		})
	end

	PlotsKeyList = Sort(PlotsKeyList)

	for Index, PlotInformation in pairs(PlotsKeyList) do
		PlotsKeyList[Index] = PlotInformation.Plot
	end

	return PlotsKeyList
end

local function InformClient(Home)
	BuildingAdded:FireAllClients(Home.Interior.Door)
	BuildingAdded:FireAllClients(Home.Exterior.Door)
end

local function SpawnCharacter(Character, Home)
	if not Character or not Home then
		return
	end
	
	local _, CharacterSize = Character:GetBoundingBox()
	local NewLocation = Home.Interior:FindFirstChild('Spawn') or Home.Interior.PrimaryPart
	local ObjectAngle = NewLocation.CFrame:toEulerAnglesXYZ()

	local TeleportTo = CFrame.new(Vector3.new(NewLocation.Position.X, NewLocation.Position.Y + (CharacterSize.Y / 2) + (NewLocation.Size.Y / 2), NewLocation.Position.Z, Vector3.new(ObjectAngle)))
	Character.PrimaryPart.CFrame = TeleportTo
end

local function GrantPlot()
	for _, Plot in pairs(Home.Plots) do
		if Plot.Taken == false then
			Plot.Taken = true
			return Plot
		end
	end
end

local function Recolor(HomeModel, Colors)
	-- Change interior colors
	for _, Part in pairs(HomeModel.Interior:GetDescendants()) do
		if Part:FindFirstChild('Recolorable') then
			local Color = Colors and Colors.Interior and Settings:ToColor(Colors.Interior)
			Part.Color = Color or Part.Color
		end
	end

	-- Change exterior colors
	for _, Part in pairs(HomeModel.Exterior:GetDescendants()) do
		if Part:FindFirstChild('Recolorable') then
			local Color = Colors and Colors.Exterior and Settings:ToColor(Colors.Exterior)
			Part.Color = Color or Part.Color
		end
	end
end

local function KickPlayers(Zone, Plot, Excluding)
	local PlayersInHome = Zone:getPlayers()
	local TeleportLocation = Plot and Plot.Object.Spawn or Home.AlternateTeleportLocation
	
	for _, Player in pairs(PlayersInHome) do
		if Excluding and Settings:Index(Excluding, Player) then
			continue
		end
		
		local Character = Player.Character

		if Character then
			local _, CharacterSize = Character:GetBoundingBox()
			local ObjectAngle = TeleportLocation.CFrame:toEulerAnglesXYZ()

			local TeleportTo = CFrame.new(Vector3.new(TeleportLocation.Position.X, TeleportLocation.Position.Y + (CharacterSize.Y / 2) + (TeleportLocation.Size.Y / 2), TeleportLocation.Position.Z, Vector3.new(ObjectAngle)))
			Character.PrimaryPart.CFrame = TeleportTo
		end
	end
	
	return PlayersInHome or {}
end

local function EquipHome(Player, HomeDetails, Plot, ManualSwitch)
	if HomeDetails then
		local StoredHomes = Home['StoredHomes']
		
		if not Plot then
			local StoredHome = StoredHomes[Player.Name]
			Plot = StoredHome and StoredHome.Plot
		end
		
		if Plot then
			local PlotObject = Plot.Object.Main
			local HomeType = HomesData['Homes'][HomeDetails.Type]
			local HomeTypeModel = HomeType['Model']
			
			if HomeTypeModel then
				local HomeModel = HomeTypeModel:Clone()
				local InteriorPosition = Vector3.new(0, 0, 50000 + (5000 * Plot.InteriorOrder))
				local PlayerWasInHome = false
				
				if StoredHomes[Player.Name] and StoredHomes[Player.Name]['Home'] then
					if StoredHomes[Player.Name]['Zone'] then
						local InsidePlayers = KickPlayers(StoredHomes[Player.Name]['Zone'], StoredHomes[Player.Name]['Plot'])
						
						for _, InsidePlayer in pairs(InsidePlayers) do
							if InsidePlayer then
								if InsidePlayer == Player then
									PlayerWasInHome = true
									
									if ManualSwitch then
										Notify:FireClient(InsidePlayer, "You've successfully switched homes.")
									end
								else
									Notify:FireClient(InsidePlayer, 'The owner of this home switched homes.')
								end
							end
						end
						
						StoredHomes[Player.Name]['Zone']:destroy()
					end
					
					StoredHomes[Player.Name]['Home']:Destroy()
					StoredHomes[Player.Name]['Home'] = HomeModel
				else
					-- Establish starter values
					StoredHomes[Player.Name] = {Home = HomeModel, Plot = Plot, Locked = false}
				end
				
				-- Set home locations and values
				HomeModel.Exterior:SetPrimaryPartCFrame(PlotObject.CFrame)
				HomeModel.Interior:SetPrimaryPartCFrame(
					CFrame.new(InteriorPosition) * 
						(HomeModel.Interior.PrimaryPart.CFrame - HomeModel.Interior.PrimaryPart.Position) -- Get it's angle
				)
				
				Settings:Create('StringValue', 'Owner', HomeModel).Value = Player.Name
				Settings:Create('BoolValue', 'Locked', HomeModel).Value = StoredHomes[Player.Name]['Locked']
				
				-- Recolor the home
				Recolor(HomeModel, HomeDetails.Colors)
				
				-- Parent home
				HomeModel.Parent = Home.HomesFolder
				
				-- Set up a new zone for it
				local ZoneCFrame, ZoneSize = HomeModel.Interior:GetBoundingBox()
				StoredHomes[Player.Name]['Zone'] = Zone.fromRegion(ZoneCFrame, ZoneSize)
				
				-- If the player was in the home before, put them back in the home
				if PlayerWasInHome then
					SpawnCharacter(Player.Character, HomeModel)
				end

				-- Remove old connections and set new
				if Home['PlayerConnections'][Player.Name] then
					Home['PlayerConnections'][Player.Name]:Disconnect()
				end
				
				Home['PlayerConnections'][Player.Name] = Player.CharacterAdded:Connect(function(Character)
					task.wait()
					SpawnCharacter(Character, HomeModel)
				end)

				InformClient(HomeModel)
			end
		end
	end
end

function Home:FetchDefault(Homes)
	for Key, Home in pairs(Homes) do
		if Home.Default then
			return Key, Home
		end
	end
end

function Home:Format(Homes)
	local Corrections = {}
	
	if (not Homes) or (not type(Homes) == 'table') then
		Corrections.NoHomeFolder = true
	elseif (Settings:Length(Homes) < 1) then
		Corrections.NoOwnedHome = true
	else
		local InvalidHomes = {}
		local Default
		
		for Index, Home in pairs(Homes) do
			if not HomesData['Homes'][Home.Type] then
				table.insert(InvalidHomes, Index)
			end
			
			if Home.Default then
				Default = true
			end
		end
		
		if #InvalidHomes > 0 then
			Corrections.InvalidHomes = InvalidHomes
		end
		
		if not Default then
			Corrections.NoDefaultHome = true
		end
	end
	
	return Corrections
end

function Home:ReturnStarterHome()
	return {
		Type = HomesData.StarterHome,
		Name = HomesData.StarterHome,
		Default = true
	}
end

function Home:ReturnNewHome(HomeName)
	return {
		Type = HomeName,
		Name = HomeName
	}
end

function Home:ToggleLock(Player, Homes)
	if Homes then
		local StoredHomes = Home.StoredHomes
		local PlayerHomeData = StoredHomes[Player.Name]
		
		if PlayerHomeData then			
			if PlayerHomeData then
				PlayerHomeData.Locked = not PlayerHomeData.Locked
				PlayerHomeData.Home.Locked.Value = PlayerHomeData.Locked
				
				if PlayerHomeData.Locked then
					-- zone for exterior and interior seperate
					local InsidePlayers = KickPlayers(StoredHomes[Player.Name]['Zone'], StoredHomes[Player.Name]['Plot'], {Player})
					
					for _, InsidePlayer in pairs(InsidePlayers) do
						if InsidePlayer and InsidePlayer ~= Player then
							Notify:FireClient(InsidePlayer, 'This home is locked.')
						end
					end
				end
			
				return true, PlayerHomeData.Locked
			end
		end
	end
end

function Home:RecolorHome(Player, Colors)
	local StoredHome = Home['StoredHomes'][Player.Name]

	if StoredHome then
		local HomeModel = StoredHome.Home
		
		if HomeModel then
			Recolor(HomeModel, Colors)
		end
	end	
end

function Home:SetHome(Player, Homes, ManualSwitch)
	local _, Default = Home:FetchDefault(Homes)
	local StoredHomes = Home['StoredHomes']
	
	if not StoredHomes[Player.Name] or not StoredHomes[Player.Name]['Plot'] then
		local Plot = GrantPlot()
		EquipHome(Player, Default, Plot, ManualSwitch)
		
		if Player and Players:FindFirstChild(Player.Name) then
			Player:LoadCharacter()
		end
	else
		EquipHome(Player, Default, nil, ManualSwitch)
	end
end

function Home:ReleaseHome(Player)
	local StoredHomes = Home['StoredHomes']
	
	if StoredHomes[Player.Name] then
		if StoredHomes[Player.Name]['Zone'] then
			local InsidePlayers = KickPlayers(StoredHomes[Player.Name]['Zone'], StoredHomes[Player.Name]['Plot'])
			
			for _, InsidePlayer in pairs(InsidePlayers) do
				if InsidePlayer then
					Notify:FireClient(InsidePlayer, 'The owner of this home left the game.')
				end
			end
			
			StoredHomes[Player.Name]['Zone']:destroy()
		end
		
		StoredHomes[Player.Name]['Home']:Destroy()
		
		StoredHomes[Player.Name]['Plot']['Taken'] = false
		StoredHomes[Player.Name] = nil
		
		local PlayerConnections = Home['PlayerConnections']
		PlayerConnections[Player.Name]:Disconnect()
		PlayerConnections[Player.Name] = nil
	end
end

-- Setting up the plots
-- The reason it's ordered sorted is so that players are gradually spawned around the map in aesthetically pleasing way
-- The InteriorOrder determines where interiors are spawned, no need to modify
local ArrangedKeyPlots = OrderedSort(Plots:GetChildren())
local InteriorOrderCounter = 0

for _, Plot in pairs(ArrangedKeyPlots) do
	-- Add them to the centralized table in the ordered manner so new players iterate through it first
	table.insert(Home.Plots, {
		Object = Plot,
		Taken = false,
		InteriorOrder = InteriorOrderCounter
	})
	
	InteriorOrderCounter += 1
end

-- Set all buildings with teleport things
for _, Home in pairs(HomeAssets:GetChildren()) do
	local Interior, Exterior = Home:FindFirstChild('Interior'), Home:FindFirstChild('Exterior')
	
	if Interior and Exterior then
		local InteriorComponents = {
			Door = Interior:FindFirstChild('Door'),
			Pad = Interior:FindFirstChild('Pad'),
		}
		
		local ExteriorComponents = {
			Door = Exterior:FindFirstChild('Door'),
			Pad = Exterior:FindFirstChild('Pad'),
			Primary = Exterior:FindFirstChild('Plotmesh')
		}
		
		if InteriorComponents.Door and InteriorComponents.Pad and ExteriorComponents.Door and ExteriorComponents.Pad then
			-- Set them to teleport to one another
			local InteriorTeleportation = Settings:Create('ObjectValue', 'Teleportation', InteriorComponents.Door)
			InteriorTeleportation.Value = ExteriorComponents.Pad
			Interior.PrimaryPart = InteriorComponents.Pad
			
			local ExteriorTeleportation = Settings:Create('ObjectValue', 'Teleportation', ExteriorComponents.Door)
			ExteriorTeleportation.Value = InteriorComponents.Pad
			Exterior.PrimaryPart = ExteriorComponents.Primary
		end
	end
end

return Home