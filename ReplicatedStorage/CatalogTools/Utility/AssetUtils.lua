local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Modules.Utility.Settings)

local AssetCheck = require(ReplicatedStorage.CatalogTools.Utility.AssetCheck)
local Catalog = require(ReplicatedStorage.CatalogTools.Catalog)
local TableUtilties = require(ReplicatedStorage.CatalogTools.Utility.TableUtility)

local EXCLUDED_ANIM = {48, 50, 52, 53, 54, 55} -- Everything but Idle (51)
local REFERENCED_ANIM = Catalog.Animations.IdleAnimation

local module = {}
local AssetTypeEnumLookup = {}

for _, enumItem in ipairs(Enum.AssetType:GetEnumItems()) do
	AssetTypeEnumLookup[enumItem.Value] = enumItem
end

function module.getRandomSkinTone()
	local t = {}
	for k, _ in pairs(Catalog.BodyParts.SkinTone) do
		table.insert(t, k)
	end
	-- return Catalog.Appearance.SkinTone[t[math.random(1, #t)]]
	return t[math.random(1, #t)]
end

function module.getRandomAsset(category, subcategory)
	local catalog_category = Catalog[category]
	if not catalog_category then
		print("category", category, "does not exist")
		return
	end
	
	local catalog_subcategory = catalog_category[subcategory]
	if not catalog_subcategory then
		print("subcategory", subcategory, "does not exist")
		return
	end
	
	return catalog_subcategory[math.random(1, #catalog_subcategory)]
end

function module.removeScriptsFromInstance(instance: Instance)
	for _, v in ipairs(instance:GetDescendants()) do
		if v:IsA("Script") or v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA('LocalScript') then
			-- print("Deleting " .. v.ClassName .. ":", v.Name)
			v:Destroy()
		end
	end
	
	if instance:IsA('Tool') then
		instance.CanBeDropped = false
		instance.ToolTip = instance.Name
		
		return true
	end
end

function module.formatProductInfo(t)
	return {
		id = t.AssetId,
		assetType = {
			name = AssetTypeEnumLookup[t.AssetTypeId].Name,
			id = t.AssetTypeId,
		},
		name = t.Name
	}
end

function module.getCharacterAppearanceInfo(player: Player)
	local t
	
	local success = pcall(function()
		t = Players:GetCharacterAppearanceInfoAsync(player.UserId)
		t.age, t.gear, t.locked = '', {}, false
	end)
	
	if not success or not t then
		-- generate default data here?
		warn("Unable to get CharacterAppearanceInfo for", player.Name)
		return {}
	end
	
	-- could be problematic if indexing
	for i, item in pairs(t.assets) do
		if item.assetType and Settings:Index(EXCLUDED_ANIM, item.assetType.id) then
			t.assets[i] = nil
		end
	end
		
	return t or {}
end

local function getAnimations(animation)
	local animType
	local newAnims = {}

	for _, tbl in pairs(REFERENCED_ANIM) do
		if tbl.id == animation then
			animType = tbl.name
		end
	end

	for i, typ in pairs(Catalog.Animations) do
		if type(typ) == 'table' then
			for _, tbl in pairs(typ) do
				if tbl.name == animType then
					newAnims[i] = tbl.id
				end
			end
		end
	end

	return newAnims
end

function Round(Value)
	Value *= 100
	return (math.floor(Value + 0.5) / 100)
end

-- theres gotta be a better way
function module.getHumanoidDescriptionFromCharacterAppearance(characterAppearanceInfo)
	local humanoidDescription = Instance.new("HumanoidDescription")
	humanoidDescription.BodyTypeScale = Round(characterAppearanceInfo.scales.bodyType)
	humanoidDescription.DepthScale = Round(characterAppearanceInfo.scales.depth)
	humanoidDescription.HeadScale = Round(characterAppearanceInfo.scales.head)
	humanoidDescription.HeightScale = Round(characterAppearanceInfo.scales.height)
	humanoidDescription.ProportionScale = Round(characterAppearanceInfo.scales.proportion)
	humanoidDescription.WidthScale = Round(characterAppearanceInfo.scales.width)
	humanoidDescription.HeadColor = BrickColor.new(characterAppearanceInfo.bodyColors.headColorId).Color
	humanoidDescription.LeftArmColor = BrickColor.new(characterAppearanceInfo.bodyColors.leftArmColorId).Color
	humanoidDescription.LeftLegColor = BrickColor.new(characterAppearanceInfo.bodyColors.leftLegColorId).Color
	humanoidDescription.RightArmColor = BrickColor.new(characterAppearanceInfo.bodyColors.rightArmColorId).Color
	humanoidDescription.RightLegColor = BrickColor.new(characterAppearanceInfo.bodyColors.rightLegColorId).Color
	humanoidDescription.TorsoColor = BrickColor.new(characterAppearanceInfo.bodyColors.torsoColorId).Color
	for _, asset in ipairs(characterAppearanceInfo.assets) do
		if asset.assetType.name == "Hat" then
			humanoidDescription.HatAccessory = humanoidDescription.HatAccessory .. "," .. asset.id
		elseif asset.assetType.name == "BackAccessory" or asset.assetType.name == "Back Accessory" then
			humanoidDescription.BackAccessory = humanoidDescription.BackAccessory .. "," .. asset.id
		elseif asset.assetType.name == "FaceAccessory" or asset.assetType.name == "Face Accessory" then
			humanoidDescription.FaceAccessory = humanoidDescription.FaceAccessory .. "," .. asset.id
		elseif asset.assetType.name == "FrontAccessory" or asset.assetType.name == "Front Accessory" then
			humanoidDescription.FrontAccessory = humanoidDescription.FrontAccessory .. "," .. asset.id
		elseif asset.assetType.name == "HairAccessory" or asset.assetType.name == "Hair Accessory" then
			humanoidDescription.HairAccessory = humanoidDescription.HairAccessory .. "," .. asset.id
		elseif asset.assetType.name == "NeckAccessory" or asset.assetType.name == "Neck Accessory" then
			humanoidDescription.NeckAccessory = humanoidDescription.NeckAccessory .. "," .. asset.id
		elseif asset.assetType.name == "ShoulderAccessory" or asset.assetType.name == "Shoulder Accessory" then
			humanoidDescription.ShouldersAccessory = humanoidDescription.ShouldersAccessory .. "," .. asset.id
		elseif asset.assetType.name == "WaistAccessory" or asset.assetType.name == "Waist Accessory" then
			humanoidDescription.WaistAccessory = humanoidDescription.WaistAccessory .. "," .. asset.id
		elseif asset.assetType.name == "Face" then
			humanoidDescription.Face = asset.id
		elseif asset.assetType.name == "Shirt" then
			humanoidDescription.Shirt = asset.id
		elseif asset.assetType.name == "TeeShirt" or asset.assetType.name == "T-Shirt" then
			humanoidDescription.GraphicTShirt = asset.id
		elseif asset.assetType.name == "Pants" then
			humanoidDescription.Pants = asset.id
		elseif asset.assetType.name == "Head" then
			humanoidDescription.Head = asset.id
		elseif asset.assetType.name == "LeftArm" or asset.assetType.name == "Left Arm" then
			humanoidDescription.LeftArm = asset.id
		elseif asset.assetType.name == "LeftLeg" or asset.assetType.name == "Left Leg" then
			humanoidDescription.LeftLeg = asset.id
		elseif asset.assetType.name == "RightArm" or asset.assetType.name == "Right Arm" then
			humanoidDescription.RightArm = asset.id
		elseif asset.assetType.name == "RightLeg" or asset.assetType.name == "Right Leg" then
			humanoidDescription.RightLeg = asset.id
		elseif asset.assetType.name == "Torso" then
			humanoidDescription.Torso = asset.id
		elseif asset.assetType.name == "IdleAnimation" or asset.assetType.name == "Idle Animation" then
			local anims = getAnimations(asset.id)
			
			for typ, id in pairs(anims) do
				humanoidDescription[typ] = id
			end
			
		--[[elseif asset.assetType.name == "ClimbAnimation" or asset.assetType.name == "Climb Animation" then
			humanoidDescription.ClimbAnimation = asset.id
		elseif asset.assetType.name == "FallAnimation" or asset.assetType.name == "Fall Animation" then
			humanoidDescription.FallAnimation = asset.id
		elseif asset.assetType.name == "IdleAnimation" or asset.assetType.name == "Idle Animation" then
			humanoidDescription.IdleAnimation = asset.id
		elseif asset.assetType.name == "JumpAnimation" or asset.assetType.name == "Jump Animation" then
			humanoidDescription.JumpAnimation = asset.id
		elseif asset.assetType.name == "RunAnimation" or asset.assetType.name == "Run Animation" then
			humanoidDescription.RunAnimation = asset.id
		elseif asset.assetType.name == "SwimAnimation" or asset.assetType.name == "Swim Animation" then
			humanoidDescription.SwimAnimation = asset.id
		elseif asset.assetType.name == "WalkAnimation" or asset.assetType.name == "Walk Animation" then
			humanoidDescription.WalkAnimation = asset.id]]
		end
	end
	if humanoidDescription.Shirt == 0 then
		humanoidDescription.Shirt = 855777286
	end
	if humanoidDescription.Pants == 0 then
		humanoidDescription.Pants = 855782781
	end
	return humanoidDescription
end

local asset_type_map = {
	[8] = "Hat",
	[41] = "Hair",
	[42] = "Face",
	[43] = "Neck",
	[44] = "Shoulder",
	[45] = "Front",
	[46] = "Back",
	[47] = "Waist",
}
function module.getAccessoryAttachmentInfoFromAssets(assets)
	local t = {}
	if assets then
		for _, asset in ipairs(assets) do
			
			-- only add accessories to the table
			if not asset_type_map[asset.assetType.id] then
				continue
			end
			
			local items, productInfo
			local success = pcall(function()
				items = InsertService:LoadAsset(asset.id)
			end)
			
			if success and items then
				local item = items:GetChildren()[1]
				
				local asset_table = t[tostring(asset.assetType.id)]
				if not asset_table then
					t[tostring(asset.assetType.id)] = {}
					asset_table = t[tostring(asset.assetType.id)]
				end
				
				success = pcall(function()
					productInfo = MarketplaceService:GetProductInfo(asset.id)
				end)
				
				if success and productInfo then
					if asset.assetType.id == 8 then
						table.insert(asset_table, {instance_name = item.Name, product_info = productInfo})
					else
						asset_table[AssetCheck.getAccessoryType(item)] = {instance_name = item.Name, product_info = productInfo}
					end
				end
			end
		end
	end
	
	return t
end

return module