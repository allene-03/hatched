local Replicated = game:GetService('ReplicatedStorage')
local Settings = require(Replicated.Modules.Utility.Settings)
local Vehicles = Replicated.Assets.Vehicles

local CoreVehicleModule = {
	Restrictions = {
		CheckRate = 3, -- = (1 / CheckRate),
		MaximumVehicleSpeed = 1000, -- Punishes at speeds 1000+ per sec
	},
	
	DespawnTime = 180, -- Amount of time inactive before the vehicle despawns
}

-- To confirm that vehicles clients have sent over are legitimate
function CoreVehicleModule:Confirm(PlayerOwnedVehicles, OwnedPath, Arguments)	
	if Arguments and type(Arguments) == 'table' and Arguments.Vehicle then
		return PlayerOwnedVehicles[Arguments.Vehicle]
	end
end

function CoreVehicleModule:AddCustomization(Vehicle, Folder)
	local Customized = Folder.Customized
	local VehicleBody = Vehicle:FindFirstChild('Body')
	
	if VehicleBody then
		local VehicleMain = VehicleBody:FindFirstChild('Main')
		
		-- Adding the color group on
		for ColorGroup, ColorValue in pairs(Customized.Color) do
			local VehicleColorGroup = VehicleMain:FindFirstChild(ColorGroup)
			
			if VehicleColorGroup then
				local ConvertedColor = Settings:ToColor(ColorValue)
				
				for _, Part in pairs(VehicleColorGroup:GetDescendants()) do
					if Part:IsA('BasePart') then
						Part.Color = ConvertedColor
					end
				end
			else
				warn('Color group not found.')
			end
		end
		
		-- Adding the glow on
		for _, Object in pairs(VehicleBody:GetDescendants()) do
			if Object.ClassName == 'BoolValue' and Object.Name == 'NeonInclusion' then
				local Part = Object.Parent
				
				if Customized.Glow then
					Part.Material = Enum.Material.Neon
				else
					-- This should convert it to the original texture, but don't remove the else part 
					-- because it makes sure that the glow is taken off after customizing from yes to no
					Part.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end
end

function CoreVehicleModule:Spawn(Folder)
	local VehicleAsset = Folder.Type and Vehicles:FindFirstChild(Folder.Type)

	if VehicleAsset then
		local VehicleModel = VehicleAsset.Models.Main:Clone()
		CoreVehicleModule:AddCustomization(VehicleModel, Folder)
		VehicleModel.Name = Folder.Type

		return VehicleModel, VehicleAsset
	end
end

function CoreVehicleModule:Create(Vehicle)	
	if Vehicle then
		local Folder = {}
		
		-- Convert the data folder to a table and parent it to reference table
		for Name, Child in pairs(Settings:ConvertFolderToTable(Vehicle.Data)) do
			Folder[Name] = Child
		end
		
		-- Set the vehicle type
		Folder.Customized = {Color = {}, Glow = nil}
		Folder.Type = Vehicle.Name
		
		return Folder
	end
end

return CoreVehicleModule