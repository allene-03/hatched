local module = {}

local function isInArray(t, number: number)
	return table.find(t, tonumber(number)) ~= nil
end

local gear_ids = {19}
function module.isAssetTypeGear(asset_type: number)
	return isInArray(gear_ids, asset_type)
end

local body_part_ids = {27, 28, 29, 30, 31}
function module.isAssetTypeBodyPart(asset_type: number)
	return isInArray(body_part_ids, asset_type)
end

local accessory_ids = {8, 41, 42, 43, 44, 45, 46, 47}
function module.isAssetTypeAccessory(asset_type: number)
	return isInArray(accessory_ids, asset_type)
end

function module.getAccessoryType(accessoryInstance)
	local attachment = accessoryInstance.Handle:FindFirstChildOfClass("Attachment")
	if not attachment then return end
	local accessoryType = attachment.Name:match("(.+)Attachment")
	return accessoryType
end

return module