local module = {}

function module.mergeArrays(...)
	local t = {}
	
	for _, v in ipairs({...}) do
		for _, j in ipairs(v) do
			table.insert(t, j)
		end
	end
	
	return t
end

function module.getDictionarySize(t: table)
	local c = 0
	
	for _, _ in pairs(t) do
		c += 1
	end
	
	return c
end

function module.getTableSize(t)
		local length = #t
		
		if length == 0 then
			length = module.getDictionarySize(t)
		end
		
		return length
end

function module.getLengthOfTables(...)
	local c = 0
	
	for _, t in pairs({...}) do
		c += module.getTableSize(t)
	end
	
	return c
end

return module