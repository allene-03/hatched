local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService('ServerScriptService')
local ServerStorage = game:GetService("ServerStorage")
local Marketplace = game:GetService("MarketplaceService")
local Insert = game:GetService("InsertService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(ReplicatedStorage.Modules.Utility.Settings)
local utility = require(ReplicatedStorage.CatalogTools.Utility.AssetUtils)
local AssetCheck = require(ReplicatedStorage.CatalogTools.Utility.AssetCheck)
local InstanceUtils = require(ReplicatedStorage.CatalogTools.Utility.InstanceUtils)
local Catalog = require(ReplicatedStorage.CatalogTools.Catalog)
local Categories = require(ReplicatedStorage.CatalogTools.Categories)

local remotes_folder = ReplicatedStorage:WaitForChild("Remotes")
local events_folder = remotes_folder:WaitForChild("Catalog")

local DataModule = require(ServerScriptService.Modules.Data.Consolidate)

local update_avatar_event = events_folder:WaitForChild("UpdateAvatar")
local update_head_event = events_folder:WaitForChild("UpdateHead")
local change_avatar_event = events_folder:WaitForChild("ChangeAvatar")
local Warn = events_folder:WaitForChild("WarnPlayer")

local defaultBodyPartsR15 = ServerStorage.Assets.HumanoidDefaultBodyPartsR15
local empty_humanoid_description = Instance.new("HumanoidDescription")

local HAT_LIMIT = 3
local ACCESSORY_CAP = 15
local GEAR_CAP = 5
local DEFAULT_SHIRT = "rbxassetid://855777285"
local DEFAULT_PANTS = "rbxassetid://867826313"
local DEFAULT_FACE = "rbxasset://textures/face.png"

local REFERENCED_SUB = "IdleAnimation"
local REFERENCED_ANIM = Catalog.Animations[REFERENCED_SUB]

local allowedAssets = {
	["2"] = true, --TShirt
	["8"] = true, -- Hat
	["11"] = true, -- Shirt
	["12"] = true, -- Pants
	["17"] = true, -- Head
	["18"] = true, -- Face
	["27"] = true, -- Torso
	["28"] = true, -- RightArm
	["29"] = true, -- LeftArm
	["30"] = true, -- LeftLeg
	["31"] = true, -- RightLeg
	["41"] = true, -- HairAccessory
	["42"] = true, -- FaceAccessory
	["43"] = true, -- NeckAccessory
	["44"] = true, -- ShoulderAccessory
	["45"] = true, -- FrontAccessory
	["46"] = true, -- BackAccessory
	["47"] = true, -- WaistAccessory
	["48"] = true, -- ClimbAnimation
	["50"] = true, -- FallAnimation
	["51"] = true, -- IdleAnimation
	["52"] = true, -- JumpAnimation
	["53"] = true, -- RunAnimation
	["54"] = true, -- SwimAnimation
	["55"] = true, -- WalkAnimation
	["19"] = true, -- Gear
}

local ageValueTypes = {"BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale"}
local ageNilTypes = {"BodyProportionScale", "BodyTypeScale"}

local playerWearingAssets = {}
local playerAttachmentMap = {}

local function insertToTable(assets, productInfo)
	table.insert(assets, utility.formatProductInfo(productInfo))
end

local function getAnimations(animation)
	local animType
	local newAnimModel = Instance.new('Model')
	
	for _, tbl in pairs(REFERENCED_ANIM) do
		if tbl.id == animation then
			animType = tbl.name
		end
	end
	
	for _, typ in pairs(Catalog.Animations) do
		if type(typ) == 'table' then
			for _, tbl in pairs(typ) do
				if tbl.name == animType then
					local productInfo, items
					
					local success, err = pcall(function()
						productInfo = Marketplace:GetProductInfo(tbl.id)
						items = Insert:LoadAsset(productInfo.AssetId)
					end)
					
					if success then
						local folder = items:GetChildren()[1]
						for i, anim in pairs(folder:GetChildren()) do
							anim.Parent = newAnimModel
						end
					end
				end
			end
		end
	end
	
	return newAnimModel
end

local function getOriginalHeadMesh()
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	local originalSize = Instance.new("Vector3Value")
	originalSize.Name = "OriginalSize"
	originalSize.Value = Vector3.new(1.25, 1.25, 1.25)
	originalSize.Parent = mesh
	return mesh
end

local function getOriginalFace()
	local decal = Instance.new("Decal")
	decal.Texture = DEFAULT_FACE
	return decal
end

local function getOriginalClothing(clothe)
	if clothe == "Shirt" then
		local shirt = Instance.new("Shirt")
		shirt.ShirtTemplate = DEFAULT_SHIRT
		return shirt
	elseif clothe == "Pants" then
		local pants = Instance.new("Pants")
		pants.PantsTemplate = DEFAULT_PANTS
		return pants
	end
end

local function amountOfPlayerHats(characterAppearanceInfo)
	local count = 0
	for _, asset in pairs(characterAppearanceInfo.assets) do
		if asset.assetType.id == 8 then
			count += 1
		end
	end
	return count
end

local function wear(player, id, suppress_client_update)
	suppress_client_update = suppress_client_update or false
	
	if id == nil or not (typeof(id) == "number") then
		return
	end
	
	if not playerWearingAssets[player] then
		return
	end
	
	local characterAppearanceInfo = playerWearingAssets[player]
	local index = nil
	
	for i, asset in ipairs(characterAppearanceInfo.assets) do
		if asset.id == id then
			index = i
			break
		end
	end
	
	local productInfo, items
	
	local success, err = pcall(function()
		productInfo = Marketplace:GetProductInfo(id)
	end)
	
	if not success then
		if index then
			table.remove(characterAppearanceInfo.assets, index)
		end
		return warn(err)
	end
	
	local assetTypeId = tostring(productInfo.AssetTypeId)
	if not allowedAssets[assetTypeId] then
		return warn("not allowed asset type", assetTypeId)
	end
	
	local character = player.Character
	local humanoid: Humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	
	success, err = pcall(function()
		items = Insert:LoadAsset(productInfo.AssetId)
	end)
	if not success then
		if index then
			table.remove(characterAppearanceInfo.assets, index)
		end
		return warn(err) -- This is an error
	end
	for _, descendant in ipairs(items:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("BackpackItem") then
			Debris:AddItem(descendant, 0)
		end
	end
	
	-- if the player already has the asset equipped, save its index for removal later
	local characterAttachmentInfo = {}
	if playerAttachmentMap[player] then
		characterAttachmentInfo = playerAttachmentMap[player][assetTypeId]
	end
	if not characterAttachmentInfo then
		playerAttachmentMap[player][assetTypeId] = {}
		characterAttachmentInfo = playerAttachmentMap[player][assetTypeId]
	end
		
	if AssetCheck.isAssetTypeAccessory(assetTypeId) then
		local accessory = items:GetChildren()[1]
		if not accessory:IsA("Accoutrement") then
			return
		end
		
		local function findAccessory(accessory)
			local children = {}
			for _, child in pairs(character:GetChildren()) do
				if child.Name == accessory.Name then
					table.insert(children, child)
				end
			end
			
			if #children == 0 then
				return nil
			end
			if #children == 1 then
				return children[1]
			end
			
			-- multiple children have been found with the same name
			local accessory_mesh = accessory:FindFirstChildWhichIsA("SpecialMesh", true).MeshId
			for _, child in pairs(children) do
				local mesh = child:FindFirstChildWhichIsA("SpecialMesh", true)
				if mesh and mesh.MeshId == accessory_mesh then
					return child
				end
			end
		end
		
		if assetTypeId == "8" then
			-- print(amountOfPlayerHats(characterAppearanceInfo))
			-- hat, can have up to 3 equipped, after which one will be overwritten
			if index then
				-- already equipped, unequip
				local wearing = findAccessory(accessory)
				if wearing then
					Debris:AddItem(wearing, 0)
					table.remove(characterAppearanceInfo.assets, index)
					for i, v in ipairs(characterAttachmentInfo) do
						if accessory.Name == v.instance_name then
							table.remove(characterAttachmentInfo, i)
							break
						end
					end
				end
			elseif amountOfPlayerHats(characterAppearanceInfo) < HAT_LIMIT then
				-- not equipped and room to equip
				humanoid:AddAccessory(accessory)
				insertToTable(characterAppearanceInfo.assets, productInfo)
				table.insert(characterAttachmentInfo, {instance_name = accessory.Name, product_info = productInfo})
			else
				-- overwrite an already equipped hat
				Warn:FireClient(player, 'hatlimit')
				local wearing
				index = index
				local currently_equipped = characterAttachmentInfo[1]
				
				if currently_equipped then
					for i, asset in ipairs(characterAppearanceInfo.assets) do
						if asset.name == currently_equipped.product_info.Name then
							wearing = character:FindFirstChild(currently_equipped.instance_name)
							index = i
						end
					end
				end
				
				if wearing then
					Debris:AddItem(wearing, 0)
					table.remove(characterAppearanceInfo.assets, index)
					table.remove(characterAttachmentInfo, 1)
				end
				
				humanoid:AddAccessory(accessory)
				insertToTable(characterAppearanceInfo.assets, productInfo)
				table.insert(characterAttachmentInfo, {instance_name = accessory.Name, product_info = productInfo})
			end
		elseif assetTypeId == "44" then
			-- shoulders can have left and right parts, allow for both to be equipped
			local accessory_type = AssetCheck.getAccessoryType(accessory)
			if index then
			-- player is wearing this accessory, so unequip it
				local wearing = findAccessory(accessory)
				if wearing then
					Debris:AddItem(wearing, 0)
					table.remove(characterAppearanceInfo.assets, index)
					characterAttachmentInfo[accessory_type] = nil
				end
			elseif #humanoid:GetAccessories() < ACCESSORY_CAP then
				-- equipping new accessory
				local wearing
				index = nil
				local currently_equipped = characterAttachmentInfo[accessory_type]
				
				if currently_equipped then
					for i, asset in ipairs(characterAppearanceInfo.assets) do
						if asset.name == currently_equipped.product_info.Name then
							wearing = character:FindFirstChild(currently_equipped.instance_name)
							index = i
						end
					end
				end
				
				if wearing then
					Debris:AddItem(wearing, 0)
					table.remove(characterAppearanceInfo.assets, index)
				end
				
				-- equip new accessory
				humanoid:AddAccessory(accessory)
				insertToTable(characterAppearanceInfo.assets, productInfo)
				characterAttachmentInfo[accessory_type] = {instance_name = accessory.Name, product_info = productInfo}
			else
				Warn:FireClient(player, 'accessorylimit')
			end
		elseif assetTypeId == "41" or assetTypeId == "42" or assetTypeId == "43" or assetTypeId == "45" or assetTypeId == "46" or assetTypeId == "47" then
			-- accessory, not hat or shoulder
			local accessory_type = AssetCheck.getAccessoryType(accessory)
			if index then
			-- player is wearing this accessory, so unequip it
				local wearing = findAccessory(accessory)
				if wearing then
					Debris:AddItem(wearing, 0)
					table.remove(characterAppearanceInfo.assets, index)
					characterAttachmentInfo[accessory_type] = nil
				end
			elseif #humanoid:GetAccessories() < ACCESSORY_CAP then
				-- equipping new accessory
				local wearing
				index = nil
				
				-- I use next here as I don't need to worry about there being more than one accessory on a single attachment
				local _, currently_equipped = next(characterAttachmentInfo)
				
				-- unequip old accessory in this slot
				if currently_equipped then
					for i, asset in ipairs(characterAppearanceInfo.assets) do
						if asset.name == currently_equipped.product_info.Name then
							wearing = character:FindFirstChild(currently_equipped.instance_name)
							index = i
						end
					end
				end
				
				if wearing then
					Debris:AddItem(wearing, 0)
					table.remove(characterAppearanceInfo.assets, index)
				end
				
				-- equip new accessory
				humanoid:AddAccessory(accessory)
				insertToTable(characterAppearanceInfo.assets, productInfo)
				characterAttachmentInfo[accessory_type] = {instance_name = accessory.Name, product_info = productInfo}
			else
				Warn:FireClient(player, 'accessorylimit')
			end
		end
	elseif assetTypeId == "2" then
		-- TShirt
		local clothing = items:GetChildren()[1]
		if not clothing:IsA("ShirtGraphic") then
			return
		end
		
		local wearing = character:FindFirstChildWhichIsA(clothing.ClassName)
		if wearing then
			Debris:AddItem(wearing, 0)
		end
		
		if index then
			table.remove(characterAppearanceInfo.assets, index)
		else
			for i, asset in ipairs(characterAppearanceInfo.assets) do
				if productInfo.AssetTypeId == asset.assetType.id then
					table.remove(characterAppearanceInfo.assets, i)
				end
			end
			insertToTable(characterAppearanceInfo.assets, productInfo)
			clothing.Parent = character
		end
		
	elseif assetTypeId == "11" or assetTypeId == "12"  then
		-- Shirt or Pants
		local clothing = items:GetChildren()[1]
		if not clothing:IsA("Clothing") then
			return
		end
		
		local wearing = character:FindFirstChildWhichIsA(clothing.ClassName)
		if wearing then
			Debris:AddItem(wearing, 0)
		end
		
		if index then
			table.remove(characterAppearanceInfo.assets, index)
			getOriginalClothing(clothing.ClassName).Parent = character
		else
			for i, asset in ipairs(characterAppearanceInfo.assets) do
				if productInfo.AssetTypeId == asset.assetType.id then
					table.remove(characterAppearanceInfo.assets, i)
				end
			end
			insertToTable(characterAppearanceInfo.assets, productInfo)
			clothing.Parent = character
		end
	elseif assetTypeId == "48" or assetTypeId == "50" or assetTypeId == "51" or assetTypeId == "52" or assetTypeId == "53" or assetTypeId == "54" or assetTypeId == "55" then
		-- animation
		-- local animationFolder = items:GetChildren()[1]
		local animationFolder = getAnimations(id)
		local animateScript = character:FindFirstChild("Animate")
		
		if index then
			table.remove(characterAppearanceInfo.assets, index)
			--redo here
			for _, value in ipairs(animationFolder:GetChildren()) do -- and for all
				if animateScript:FindFirstChild(value.Name) then
					Debris:AddItem(animateScript[value.Name], 0)
				end
			end
		else
			for i, asset in ipairs(characterAppearanceInfo.assets) do
				if productInfo.AssetTypeId == asset.assetType.id then -- and for all
					table.remove(characterAppearanceInfo.assets, i)
				end
			end
			
			insertToTable(characterAppearanceInfo.assets, productInfo)
			
			if animateScript then
				for _, value in ipairs(animationFolder:GetChildren()) do
					if animateScript:FindFirstChild(value.Name) then
						Debris:AddItem(animateScript[value.Name], 0)
					end
					
					value.Parent = animateScript
				end
			end
		end
	elseif assetTypeId == "18" then
		-- face
		local decal = items:GetChildren()[1]
		if not decal:IsA("Decal") then
			return
		end
		local head = character:FindFirstChild("Head")
		local wearing = head and head:FindFirstChildWhichIsA("Decal")
		if wearing then
			Debris:AddItem(wearing, 0)
		end
		if index then
			table.remove(characterAppearanceInfo.assets, index)
			player:LoadCharacterAppearance(getOriginalFace())
		else
			for i, asset in ipairs(characterAppearanceInfo.assets) do
				if productInfo.AssetTypeId == asset.assetType.id then
					table.remove(characterAppearanceInfo.assets, i)
				end
			end
			insertToTable(characterAppearanceInfo.assets, productInfo)
			decal.Parent = head
		end
	elseif assetTypeId == "17" then
		-- head
		local mesh = items:GetChildren()[1]
		items:Clone().Parent = workspace
		if mesh:IsA("SpecialMesh") or mesh:IsA("CylinderMesh") then
			print('Head')
			-- not a valid head
			local head = character:FindFirstChild("Head")
			local wearing = head and head:FindFirstChildWhichIsA("SpecialMesh")
			if wearing then
				print('Wearing something')
				Debris:AddItem(wearing, 0)
			end
			if index then
				print('Wearing this head')
				table.remove(characterAppearanceInfo.assets, index)
				player:LoadCharacterAppearance(getOriginalHeadMesh())
			else
				print('Equipping new head')
				for i, asset in ipairs(characterAppearanceInfo.assets) do
					if productInfo.AssetTypeId == asset.assetType.id then
						table.remove(characterAppearanceInfo.assets, i)
					end
				end
				insertToTable(characterAppearanceInfo.assets, productInfo)
				player:LoadCharacterAppearance(mesh)
			end
		else
			print('Not valid head')
			table.remove(characterAppearanceInfo.assets, index)
		end
	elseif AssetCheck.isAssetTypeBodyPart(tonumber(assetTypeId)) then
		print('Possible head')
		-- body parts
		local bodyPartFolder = items:FindFirstChild("R15ArtistIntent") or items:FindFirstChild("R15Fixed") or items:FindFirstChild("R15")
		
		if assetTypeId == "28" then
			-- unequip tools to prevent them falling through the floor when the right arm is swapped
			humanoid:UnequipTools()
		end
		
		if not bodyPartFolder then
			if index then
				table.remove(characterAppearanceInfo.assets, index)
			end
			warn("Unable to get body parts for" .. productInfo.Name .. ". Maybe this asset is configured strangely?")
			return
		end
		
		if index then
			table.remove(characterAppearanceInfo.assets, index)
			for _, part in ipairs(bodyPartFolder:GetChildren()) do
				local partInCharacter = character:FindFirstChild(part.Name)
				local bodyPartR15 = partInCharacter and humanoid:GetBodyPartR15(partInCharacter)
				local defaultBodyPart = bodyPartR15 and defaultBodyPartsR15:FindFirstChild(part.Name)
				if defaultBodyPart then
					defaultBodyPart = defaultBodyPart:Clone()
					humanoid:ReplaceBodyPartR15(bodyPartR15, defaultBodyPart)
				end
			end
		else
			for i, asset in ipairs(characterAppearanceInfo.assets) do
				if productInfo.AssetTypeId == asset.assetType.id then
					table.remove(characterAppearanceInfo.assets, i)
				end
			end
			insertToTable(characterAppearanceInfo.assets, productInfo)
			for _, part in ipairs(bodyPartFolder:GetChildren()) do
				local partInCharacter = character:FindFirstChild(part.Name)
				local bodyPartR15 = partInCharacter and humanoid:GetBodyPartR15(partInCharacter)
				if bodyPartR15 then
					humanoid:ReplaceBodyPartR15(bodyPartR15, part)
				end
			end
		end
	end
	
	humanoid:BuildRigFromAttachments()
	Debris:AddItem(items, 0)
	
	-- used to update the client so it knows what assets it's wearing
	if suppress_client_update == false then
		if RunService:IsStudio() then
			-- print(characterAppearanceInfo)
		end
		update_avatar_event:FireClient(player, characterAppearanceInfo)
	end
	
	update_head_event:Fire(character)
end

local function skinTone(player, color)
	if color == nil or not (typeof(color) == "string") then
		return
	end
	if not playerWearingAssets[player] then
		return
	end
	
	local character = player.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	
	local characterAppearanceInfo = playerWearingAssets[player]
	local brickColor = BrickColor.new(color)
	characterAppearanceInfo.bodyColors.headColorId = brickColor.Number
	characterAppearanceInfo.bodyColors.leftArmColorId = brickColor.Number
	characterAppearanceInfo.bodyColors.leftLegColorId = brickColor.Number
	characterAppearanceInfo.bodyColors.rightArmColorId = brickColor.Number
	characterAppearanceInfo.bodyColors.rightLegColorId = brickColor.Number
	characterAppearanceInfo.bodyColors.torsoColorId = brickColor.Number
	
	local bodyColors = character:FindFirstChildWhichIsA("BodyColors")
	bodyColors.HeadColor3 = brickColor.Color
	bodyColors.LeftArmColor3 = brickColor.Color
	bodyColors.LeftLegColor3 = brickColor.Color
	bodyColors.RightArmColor3 = brickColor.Color
	bodyColors.RightLegColor3 = brickColor.Color
	bodyColors.TorsoColor3 = brickColor.Color
	
	update_avatar_event:FireClient(player, characterAppearanceInfo)
end

function Round(Value)
	Value *= 100
	return (math.floor(Value + 0.5) / 100)
end

local function scale(player, name, value)
	if name == nil or not (typeof(name) == "string") then
		return
	end
	if value == nil or not (typeof(value) == "number") then
		return
	end
	if not playerWearingAssets[player] then
		return
	end
	
	local character = player.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	
	local characterAppearanceInfo = playerWearingAssets[player]
	if not characterAppearanceInfo then
		return
	end
	
	if name == "BodyHeightScale" then
		value = math.clamp(value, 50, 120)
		characterAppearanceInfo.scales.height = Round(value/100)
	elseif name == "BodyWidthScale" then
		value = math.clamp(value, 50, 120)
		characterAppearanceInfo.scales.width = Round(value/100)
	elseif name == "HeadScale" then
		value = math.clamp(value, 50, 120)
		characterAppearanceInfo.scales.head = Round(value/100)
	elseif name == "BodyProportionScale" then
		value = math.clamp(value, 0, 100)
		characterAppearanceInfo.scales.proportion = Round(value/100)
	elseif name == "BodyDepthScale" then
		value = math.clamp(value, 0, 100)
		characterAppearanceInfo.scales.depth = Round(value/100)
	elseif name == "BodyTypeScale" then
		value = math.clamp(value, 0, 100)
		characterAppearanceInfo.scales.bodyType = Round(value/100)
	else
		return
	end
	
	local scaleValue = humanoid and humanoid:FindFirstChild(name)
	
	if not scaleValue then
		return
	end
		
	scaleValue.Value = Round(value/100)
end

local function age(player, indx)
	local characterAppearanceInfo = playerWearingAssets[player]
	
	if not characterAppearanceInfo then
		return
	end
	
	local value = Catalog.BodyParts.CharacterAge[indx]
	
	if value then
		if not value.value and value.name then
			return
		end
		
		characterAppearanceInfo.age = value.name or ''
		value = value.value * 100
		
		for _, typ in pairs(ageValueTypes) do
			scale(player, typ, value)
		end
		
		for _, typ in pairs(ageNilTypes) do
			scale(player, typ, 0)
		end
		
		update_avatar_event:FireClient(player, characterAppearanceInfo)
		return characterAppearanceInfo
	end
end

local function gear(player, id)
	if id == nil or type(id) ~= "number" then
		return
	end
	
	local allowed
	
	for _, item in pairs(Catalog.Gear[1]) do
		if item.id == id then
			allowed = true
		end
	end
	
	if not allowed then
		return
	end
	
	local characterAppearanceInfo = playerWearingAssets[player]
	
	if not characterAppearanceInfo then
		return
	end
	
	local product_info, items, item
	
	local success, err = pcall(function()
		product_info = Marketplace:GetProductInfo(id)
	end)
	
	if not success then
		warn(err)
		return
	end
	
	if not product_info then
		warn("unable to get product info for id:", id)
		return
	end
	
	success, err = pcall(function()
		items = Insert:LoadAsset(id)
	end)
	
	if not success then
		warn(err)
		return
	end
	
	if not items then
		warn("unable to load asset into game:", product_info.Name)
		return
	end
	
	if not product_info.AssetTypeId == 19 then
		return
	end
	
	local backpack = player:WaitForChild("Backpack")
	local index = nil
	for i, asset in pairs(characterAppearanceInfo.gear) do
		if asset.id == id then
			index = i
			break
		end
	end
	
	-- asset is definitely a valid gear
	item = items:GetChildren()[1]
	local character = player.Character
	
	if index then
		-- player already has this gear equipped
		
		-- find currently equipped gear instance on player
		local name = product_info.Name
		local wearing = backpack:FindFirstChild(name)
		
		if not wearing and character then
			wearing = character:FindFirstChild(name)
		end
		
		if wearing then
			wearing:Destroy()
		end
		
		table.remove(characterAppearanceInfo.gear, index)
	elseif #characterAppearanceInfo.gear < GEAR_CAP then
		-- item not already equipped and we have room to equip it
		
		-- we don't want any of the original scripts to exist to prevent player killing
		if utility.removeScriptsFromInstance(item) then
			--local gear_info = {instance_name = item.Name, product_info = product_info}
			-- equip new
			item.Name = product_info.Name
			item.Parent = backpack
			--table.insert(characterAppearanceInfo.gear, gear_info)
			insertToTable(characterAppearanceInfo.gear, product_info)
		end
	else
		-- no room, replace oldest gear with current
		local popValue
		
		for i, v in pairs(characterAppearanceInfo.gear) do
			popValue = i
			break
		end
		
		print(characterAppearanceInfo.gear)
		
		local removing = table.remove(characterAppearanceInfo.gear, popValue)
		local wearing = backpack:FindFirstChild(removing.name)
		
		--print(removing.name)
		--print(backpack:GetChildren())
		
		if not wearing and character then
			wearing = character:FindFirstChild(removing.name)
		end
		
		if wearing then
			wearing:Destroy()
		end
		
		-- we don't want any of the original scripts to exist to prevent player killing
		if utility.removeScriptsFromInstance(item) then
			item.Name = product_info.Name
			item.Parent = backpack
			
			-- local gear_info = {instance_name = item.Name, product_info = product_info}
			-- table.insert(characterAppearanceInfo.gear, gear_info)
			insertToTable(characterAppearanceInfo.gear, product_info)
		end
	end
	
	update_avatar_event:FireClient(player, characterAppearanceInfo)
end

local function resetAppearance(player: Player)
	-- reset assets and humanoid properties
	local characterAppearanceInfo = playerWearingAssets[player]
	local temporary_humanoid_description = utility.getHumanoidDescriptionFromCharacterAppearance(characterAppearanceInfo)
	
	characterAppearanceInfo = utility.getCharacterAppearanceInfo(player)
	playerWearingAssets[player] = characterAppearanceInfo
	playerAttachmentMap[player] = utility.getAccessoryAttachmentInfoFromAssets(characterAppearanceInfo.assets)
	
	local character = player.Character
	if not character then
		-- no need to update player's character
		update_avatar_event:FireClient(player, characterAppearanceInfo)
		return
	end
	
	-- reset the character's appearance. animations and bodyparts don't seem to be effected.
	local humanoid = character:FindFirstChild("Humanoid")
	
	if humanoid then
		-- we need to equip the empty humanoid description in order to clear the humanoid's cache
		-- this way accessories will be automatically re-added
		local humanoidDescription = utility.getHumanoidDescriptionFromCharacterAppearance(characterAppearanceInfo)
		humanoid:UnequipTools()
		
		-- put currently equipped assets in cache
		humanoid:ApplyDescription(temporary_humanoid_description)
		-- clear all cached items
		humanoid:ApplyDescription(empty_humanoid_description)
	
		-- remove accessories
		for _, accessory in ipairs(InstanceUtils.GetDescendantsWhichAreA(character, "Accoutrement")) do
			accessory:Destroy()
		end
		
		-- delete clothes to prevent duplication from humanoid description
		local clothes = {
			character:FindFirstChildOfClass("Shirt"),
			character:FindFirstChildOfClass("Pants"),
			character:FindFirstChildOfClass("ShirtGraphic"),
		}
		
		for i = 1, 3 do
			if clothes[i] then
				clothes[i]:Destroy()
			end
		end
		
		-- finally, replace all assets
		humanoid:ApplyDescription(humanoidDescription)
	end
	
	
	-- now that all changes have been applied, let the client know
	update_avatar_event:FireClient(player, characterAppearanceInfo)
end

local function productInfoFromCatalogAsset(asset, asset_type)
	return {
		assetType = {
			id = Categories.asset_type_map[asset_type],
			name = asset_type
		},
		id = asset.id,
		name = asset.name
	}
end

local function randomiseAppearance(player)
	local characterAppearanceInfo = playerWearingAssets[player]
	if not characterAppearanceInfo then return end
	
	local temporary_humanoid_description = utility.getHumanoidDescriptionFromCharacterAppearance(characterAppearanceInfo)

	-- random body colour
	local random_colour = BrickColor.new(utility.getRandomSkinTone())
	
	local body_colours = {
		headColorId = random_colour.Number,
		leftArmColorId = random_colour.Number,
		leftLegColorId = random_colour.Number,
		rightArmColorId = random_colour.Number,
		rightLegColorId = random_colour.Number,
		torsoColorId = random_colour.Number,
	}
	
	local assets = {}
	local count = 0
	-- 0 to 3 hats
	count = math.random(0, HAT_LIMIT)
	if count > 0 then
		for _ = 1, count do
			local random_asset = utility.getRandomAsset("Accessories", "Hat")
			local t = productInfoFromCatalogAsset(random_asset, "Hat")
			table.insert(assets, t)
		end
	end
	
	-- 0 to 1 accessory in each category
	for subcategory, _ in pairs(Catalog.Accessories) do
		count = math.random(0, 1)
		if count > 0 and subcategory ~= 'Default' then
			local random_asset = utility.getRandomAsset("Accessories", subcategory)
			local t = productInfoFromCatalogAsset(random_asset, subcategory)
			table.insert(assets, t)
		end
	end
	
	-- random shirt and pants
	for subcategory, _ in pairs({Pants = Catalog.Clothing.Pants, Shirt = Catalog.Clothing.Shirt}) do
		local random_asset = utility.getRandomAsset("Clothing", subcategory)
		local t = productInfoFromCatalogAsset(random_asset, subcategory)
		table.insert(assets, t)
	end
	
	local age = age(player, math.random(1, #Catalog.BodyParts.CharacterAge))
	
	-- 0 to 1 random t-shirts
	--[[ count = math.random(0, 1)
	if count > 0 then
		for _ = 1, count do
			local random_asset = utility.getRandomAsset("Clothing", "T-Shirt")
			local t = productInfoFromCatalogAsset(random_asset, "T-Shirt")
			table.insert(assets, t)
		end
	end]]
	
	--[[ random body parts
	for subcategory, _ in pairs(Catalog.BodyParts) do
		if subcategory ~= 'Default' then
			local random_asset = utility.getRandomAsset("BodyParts", subcategory)
			local t = productInfoFromCatalogAsset(random_asset, subcategory)
			table.insert(assets, t)
		end
	end]]
	
	-- random face
	local random_asset = utility.getRandomAsset("BodyParts", "Face")
	local t = productInfoFromCatalogAsset(random_asset, "Face")
	table.insert(assets, t)
	
	-- random animations
	local random_asset = REFERENCED_ANIM[math.random(1, #REFERENCED_ANIM)]
	local t = productInfoFromCatalogAsset(random_asset, REFERENCED_SUB)
	table.insert(assets, t)

	--[[for subcategory, _ in pairs(Catalog.Animations) do
		if subcategory ~= 'Default' then
			local random_asset = utility.getRandomAsset("Animations", subcategory)
			local t = productInfoFromCatalogAsset(random_asset, subcategory)
			table.insert(assets, t)
		end
	end]]
	
	
	local t = {
		scales = age.scales,
		age = age.age,
		bodyColors = body_colours,
		assets = assets,
		gear = characterAppearanceInfo.gear,
	}
	characterAppearanceInfo = t
	playerWearingAssets[player] = characterAppearanceInfo
	playerAttachmentMap[player] = utility.getAccessoryAttachmentInfoFromAssets(characterAppearanceInfo.assets)
	
	local character = player.Character
	
	if not character then
		-- no need to update player's character
		update_avatar_event:FireClient(player, characterAppearanceInfo)
		return
	end
	
	-- reset the character's appearance. animations and bodyparts don't seem to be effected.
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		-- we need to equip the empty humanoid description in order to clear the humanoid's cache
		-- this way accessories will be automatically re-added
		local humanoidDescription = utility.getHumanoidDescriptionFromCharacterAppearance(characterAppearanceInfo)
		humanoid:UnequipTools()
		
		-- put currently equipped assets in cache
		humanoid:ApplyDescription(temporary_humanoid_description)
		-- clear all cached items
		humanoid:ApplyDescription(empty_humanoid_description)
	
		-- remove accessories
		for _, accessory in ipairs(InstanceUtils.GetDescendantsWhichAreA(character, "Accoutrement")) do
			accessory:Destroy()
		end
		
		-- delete clothes to prevent duplication from humanoid description
		local clothes = {
			character:FindFirstChildOfClass("Shirt"),
			character:FindFirstChildOfClass("Pants"),
			character:FindFirstChildOfClass("ShirtGraphic"),
		}
		
		for i = 1, 3 do
			if clothes[i] then
				clothes[i]:Destroy()
			end
		end
		
		task.wait()
		
		-- finally, replace all assets
		humanoid:ApplyDescription(humanoidDescription)
	end
	
	t.gear = characterAppearanceInfo.gear or {}
	playerWearingAssets[player] = t
	
	-- now that all changes have been applied, let the client know
	update_avatar_event:FireClient(player, characterAppearanceInfo)
end

local customisation_enabled = {}

-- limit how often the client can fire
local function onServerInvoke(player, action, id)
	local info = customisation_enabled[player]
	
	if not info or (info and info.locked) then
		return
	end
	
	if action == "wear" then
		if type(id) == 'number' then
			wear(player, id)
		elseif type(id) == 'table' then
			for i, item in pairs(id) do
				wear(player, item)
			end
		end
	elseif action == "skintone" then
		skinTone(player, id)
	elseif action == "age" then
		age(player, type(id) == 'number' and id)
	elseif action == "gear" then
		gear(player, id)
	elseif action == "default" then
		info.locked = true
		resetAppearance(player)
		info.locked = false
	elseif action == "random" then
		info.locked = true
		randomiseAppearance(player)
		info.locked = false
	end
	
	local Data, Appearance = DataModule:Get(player), playerWearingAssets[player]
	
	if Data and Appearance then 		
		DataModule:Set(player, 'Set', {
			Directory = Data,
			Key = 'Clothing',
			Value = playerWearingAssets[player],
			NoUpdate = true,
			Path = {}
		})
	end
end

local function playerAdded(player)
	local function characterAdded(character)
		local characterAppearanceInfo = playerWearingAssets[player]
		
		if characterAppearanceInfo then
			local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid")
			local humanoidDescription = utility.getHumanoidDescriptionFromCharacterAppearance(characterAppearanceInfo)
			
			if not humanoid or not humanoid:IsDescendantOf(workspace) then
				humanoid.AncestryChanged:Wait()
			end
			
			if humanoid.Health > 0 and humanoidDescription then
				pcall(function()
					humanoid:ApplyDescription(humanoidDescription)
				end)
				
				local gears = {}
				
				for i, obj in pairs(characterAppearanceInfo.gear) do
					local items, item, success, err
					
					success, err = pcall(function()
						items = Insert:LoadAsset(obj.id)
					end)
					
					if not success then
						warn(err)
						continue
					elseif not items then
						warn("unable to load asset into game:", obj.Name)
						continue
					end
					
					item = items:GetChildren()[1]
					item.Name = obj.name

					if utility.removeScriptsFromInstance(item) then
						table.insert(gears, item)
					end
				end
				
				for i, item in pairs(gears) do
					item.Parent = player.Backpack
				end

			end
		end
	end
	
	local PlayerName = player.Name
	local Loaded
	
	repeat
		Loaded = DataModule:Get(player)
		task.wait(1)
	until (Loaded or not Players:FindFirstChild(PlayerName))
		
	if Loaded then
		local characterAppearanceInfo
		
		-- If you can find the loaded data and the table isn't empty
		if Loaded.Clothing and (type(Loaded.Clothing) == 'table' and Settings:Length(Loaded.Clothing) > 0) then
			print('Clothing loaded successfully.')
			local Clothing = Loaded.Clothing
			Clothing.gear = {}
			characterAppearanceInfo = Clothing
		else
			characterAppearanceInfo = utility.getCharacterAppearanceInfo(player)
			
			-- If they don't have appearance we have nothing to start off so this wont function
			if not characterAppearanceInfo or Settings:Length(characterAppearanceInfo) == 0 then
				return
			end
		end
		
		playerWearingAssets[player] = characterAppearanceInfo
		update_avatar_event:FireClient(player, characterAppearanceInfo)
				
		customisation_enabled[player] = {locked = false}
		
		-- initialise playerAttachmentMap with currently wearing assets
		playerAttachmentMap[player] = utility.getAccessoryAttachmentInfoFromAssets(characterAppearanceInfo.assets)
		
		player.CharacterAdded:Connect(characterAdded)
		characterAdded(player.Character or player.CharacterAdded:Wait())
	end
end

local function playerRemoved(player)	
	if customisation_enabled[player] then
		customisation_enabled[player] = nil
	end
	
	if playerAttachmentMap[player] then 
		playerAttachmentMap[player] = nil
	end
	
	if playerWearingAssets[player] then
		playerWearingAssets[player] = nil
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	coroutine.wrap(playerAdded)(player)
end

Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoved)
change_avatar_event.OnServerInvoke = onServerInvoke

-- Get UGC permissions/credit them