local module = {}

function module.GetDescendantsWhichAreA(instance: Instance, class_name: string)
	local t = {}
	for _, v in ipairs(instance:GetDescendants()) do
		if v:IsA(class_name) then
			table.insert(t, v)
		end
	end
	return t
end

function module.GetDescendantsOfClass(instance: Instance, class_name: string)
	local t = {}
	for _, v in ipairs(instance:GetDescendants()) do
		if v.ClassName == class_name then
			table.insert(t, v)
		end
	end
	return t
end

return module