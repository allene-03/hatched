local Replicated = game:GetService('ReplicatedStorage')
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local VehicleAssets = Replicated:WaitForChild('Assets'):WaitForChild('Vehicles')

local ClientVehicleModule = {}

-- Forked from SSS[RedactedForPrivacy]Vehicles/Core
function AddCustomization(Vehicle, Folder)
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
					Part.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end
end

local function Design(Vehicle)
	local VehicleType = Vehicle.Type
	local VehicleFolder = if VehicleType then VehicleAssets:FindFirstChild(VehicleType) else false
	
	if VehicleFolder then
		local Model = VehicleFolder.Models.Client:Clone()
		AddCustomization(Model, Vehicle)
		-- Perfect equillibrium between performance and speed
		task.wait(0.075)
		
		return Model
	end
end

-- Add spawning
function ClientVehicleModule:GetData(Vehicle)
	if not Vehicle then
		return
	end

	return {
		Model = Design(Vehicle),
		Folder = VehicleAssets:FindFirstChild(Vehicle.Type)
	}
end

function ClientVehicleModule:GetCamera(Object)	
	local Cframe = Object:GetBoundingBox()
	return Cframe
end

function ClientVehicleModule:ReturnCamera(Button, Details)
	local Camera, Object

	if Details.Model then
		local Picture = Button.Background.Picture

		Object = Details.Model:Clone()
		Object.Parent = Picture

		Camera = Instance.new('Camera')
		Camera.CFrame = ClientVehicleModule:GetCamera(Object)
		Camera.Parent = Picture

		local BackgroundColor = Picture.BackgroundColor3

		Picture.BackgroundColor3 = BackgroundColor
		Picture.Size = UDim2.fromScale(1, 1) -- Remove this line when you actually add camera
		Picture.CurrentCamera = Camera

		return Camera, Object, BackgroundColor
	end
end

return ClientVehicleModule