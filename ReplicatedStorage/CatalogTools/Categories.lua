-- How to convert names:
--	Convert category_sub_map & Subcategory to New, category_asset_type_map format is New = Old 
--	Since there's already a Face, FaceAccesories are now ['Face']

local Category = {
	Featured = 0,
	All = 1,
	Collectibles = 2,
	Clothing = 3,
	BodyParts = 4,
	Gear = 5,
	Accessories = 11,
	AvatarAnimations = 12,
	CommunityCreations = 13,
}

-- I kind of regret doing it this way but I'm too far in
local Subcategory = {
	Featured = 0,
	All = 1,
	Collectibles = 2,
	Clothing = 3,
	BodyParts = 4,
	Gear = 5,
	Hats = 9,
	Faces = 10,
	Shirts = 12,
	TShirts = 13,
	Pants = 14,
	Heads = 15,
	Accessories = 19,
	Hair = 20,
	['Face'] = 21,
	Neck = 22,
	Shoulder = 23,
	Front = 24,
	Back = 25,
	Waist = 26,
	AvatarAnimations = 27,
	-- Bundles = 37,
	AnimationBundles = 38,
	EmoteAnimations = 39,
	CommunityCreations = 40,
	Melee = 41,
	Ranged = 42,
	Explosive = 43,
	PowerUp = 44,
	Navigation = 45,
	Musical = 46,
	Social = 47,
	Building = 48,
	Transport = 49,
	Climb = 1000,
	DeathAnimation = 1001,
	Fall = 1002,
	Idle = 1003,
	Jump = 1004,
	Run = 1005,
	Swim = 1006,
	Walk = 1007,
	PoseAnimation = 1008,
	EmoteAnimation = 1009,
	Chest = 2000,
	['L. Arm'] = 2001,
	['R. Arm'] = 2002,
	['L. Leg'] = 2003,
	['R. Leg'] = 2004,
	Bundles = 1337,
}

local asset_type_map = {
	["T-Shirt"] = 2,
	Hat = 8,
	Shirt = 11,
	Pants = 12,
	Head = 17,
	Face = 18,
	Gear = 19,
	Arms = 25,
	Legs = 26,
	Torso = 27,
	RightArm = 28,
	LeftArm = 29,
	LeftLeg = 30,
	RightLeg = 31,
	Bundles = 37,
	HairAccessory = 41,
	FaceAccessory = 42,
	NeckAccessory = 43,
	ShoulderAccessory = 44,
	FrontAccessory = 45,
	BackAccessory = 46,
	WaistAccessory = 47,
	ClimbAnimation = 48,
	DeathAnimation = 49,
	FallAnimation = 50,
	IdleAnimation = 51,
	JumpAnimation = 52,
	RunAnimation = 53,
	SwimAnimation = 54,
	WalkAnimation = 55,
	PoseAnimation = 56,
	EmoteAnimation = 61,
}

local category_asset_type_map = {
	Hats = "Hat",
	Shirts = "Shirt",
	["TShirts"] = "T-Shirt",
	Hair = "HairAccessory",
	['Face'] = "FaceAccessory",
	Neck = "NeckAccessory",
	Front = "FrontAccessory",
	Shoulder = "ShoulderAccessory",
	Back = "BackAccessory",
	Waist = "WaistAccessory",
	Faces = "Face",
	Heads = "Head",
	Chest = 'Torso',
	['L. Arm'] = "LeftArm",
	['R. Arm'] = "RightArm",
	['L. Leg'] = "LeftLeg",
	['R. Leg'] = "RightLeg",
	Idle = "IdleAnimation",
	Walk = "WalkAnimation",
	Run = "RunAnimation",
	Climb = "ClimbAnimation",
	Fall = "FallAnimation",
	Jump = "JumpAnimation",
	Swim = "SwimAnimation"
}

local category_subcategory_map = {
	[Category.Featured] = {},
	[Category.All] = {},
	[Category.Collectibles] = {},
	["Clothing"] = {
		Subcategory.Shirts,
		Subcategory.Pants,
		Subcategory.TShirts,
	},
	["BodyParts"] = {
		"Age",
		Subcategory.Faces,
		Subcategory.Heads,
		Subcategory.Bundles,
		-- Subcategory.Chest,
		-- Subcategory['L. Arm'],
		-- Subcategory['R. Arm'],
		-- Subcategory['L. Leg'],
		-- Subcategory['R. Leg'],
		"SkinTone",
	},
	["Gear"] = {
		-- no categories here since gear can have multiple categories on a single asset
		-- which would require searching through a lot of tables zzz
	},
	["Accessories"] = {
		Subcategory.Hats,
		Subcategory.Hair,
		Subcategory['Face'],
		Subcategory.Neck,
		Subcategory.Shoulder,
		Subcategory.Front,
		Subcategory.Back,
		Subcategory.Waist,
	},
	["Animations"] = {
		Subcategory.Idle,
		-- Subcategory.Walk,
		-- Subcategory.Run,
		-- Subcategory.Climb,
		-- Subcategory.Fall,
		-- Subcategory.Jump,
		-- Subcategory.Swim,
		-- Subcategory.DeathAnimation,
		-- Subcategory.PoseAnimation,
		-- Subcategory.EmoteAnimation,
	},
}

local function copyTable(t)
	local tbl = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			tbl[k] = copyTable(v)
		else
			tbl[k] = v
		end
	end
	return tbl
end

local function invertTable(t)
	local new_table = copyTable(t)
	for k, v in pairs(t) do
		new_table[v] = k
	end
	return new_table
end

-- so we can get the category names from category number
Category = invertTable(Category)
Subcategory = invertTable(Subcategory)
asset_type_map = invertTable(asset_type_map)

return {
	Category = Category,
	Subcategory = Subcategory,
	category_subcategory_map = category_subcategory_map,
	asset_type_map = asset_type_map,
	category_asset_type_map = category_asset_type_map,
}
