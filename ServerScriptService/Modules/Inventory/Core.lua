local Players = game:GetService('Players')
local Replicated = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

local Settings = require(Replicated.Modules.Utility.Settings)
local DataModule = require(ServerScriptService.Modules.Data.Consolidate)

local InventoryCoreModule = {
	Settings = {
		MaxItemsPerCategory = 200
	},
}

-- Functions 
local function GetHighestIdAndLength(InventoryCategory)
	local HighestId, Length = 0, 0
	
	for _, Object in pairs(InventoryCategory) do
		HighestId = ((Object.InventoryId or 0) > HighestId and (Object.InventoryId or 0)) or HighestId
		Length += 1
	end
	
	return HighestId, Length
end

-- Module functions
function InventoryCoreModule:CheckRequirements(Category)
	local HighestInventoryId, Size = GetHighestIdAndLength(Category)
	local ReturningData = {InventoryId = HighestInventoryId + 1}
	
	if Size < InventoryCoreModule.Settings.MaxItemsPerCategory then
		return true, ReturningData
	else
		return false, ReturningData
	end
end

-- The manner in which this module and this function should be used is as such.
-- First, check they have enough cash, then use the CheckRequirements() function, then
-- subtract the cash, lastly use the Add() function. This is to prevent exploitation of this system

function InventoryCoreModule:Add(Player, CategoryName, Adding, IgnoreRequirements)
	local PlayerData = DataModule:Get(Player)

	if PlayerData then
		local Category = PlayerData['Inventory'][CategoryName]
		
		if Category then
			local Success, Data = InventoryCoreModule:CheckRequirements(Category)
			
			if Success or IgnoreRequirements then
				Adding.InventoryId = Data.InventoryId
				
				return true, DataModule:Set(Player, 'Insert', {
					Directory = PlayerData.Inventory,
					Key = CategoryName,
					Value = Adding,
					Path = {'Inventory'}
				})
			else
				return Success, Data
			end
		end
	end
end

function InventoryCoreModule:UpdateInventoryId(Player, CategoryName, UpdatingKey)
	local PlayerData = DataModule:Get(Player)
	
	if PlayerData then
		local Category = PlayerData['Inventory'][CategoryName]

		if Category then
			local Updating = Category[UpdatingKey]
			
			if Updating then
				local _, Data = InventoryCoreModule:CheckRequirements(Category)
				
				DataModule:Set(Player, 'Set', {
					Directory = Updating,
					Key = 'InventoryId',
					Value = Data.InventoryId,
					Path = DataModule:TableSet('Inventory', CategoryName, UpdatingKey)
				})
			end
		end
	end
end

return InventoryCoreModule