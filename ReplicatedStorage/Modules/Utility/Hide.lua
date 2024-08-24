local Hide = {
	-- CURRENT:
}

--[[ EXAMPLE USAGE:

local Main = script.Parent

local Replicated = game:GetService('ReplicatedStorage')
local Hide = Replicated:WaitForChild('Remotes'):WaitForChild('Interface'):WaitForChild('Hide')

Hide.Event:Connect(function(Status, Type, List)
	local Mention = Settings:Index(List, Main)
	
	if Type == 'Except' then
		if Status == 'Hide' then
			if not Mention then
				Main.Visible = false
			end
		else
			if not Mention then
				Main.Visible = true
			end
		end
	elseif Type == 'Including' then
		if Status == 'Hide' then
			if Mention then
				Main.Visible = false
			end
		else
			if Mention then
				Main.Visible = true
			end
		end
	end
end)
]]--

local Replicated = game:GetService('ReplicatedStorage')
local Event = Replicated:WaitForChild('Remotes'):WaitForChild('Interface'):WaitForChild('Hide')

function Hide:HideInterface(ExclusionList)
	Event:Fire('Hide', 'Except', ExclusionList or {})
end

function Hide:HideInterfaceWithoutNickname(ExclusionList)
	table.insert(ExclusionList, 'Nickname')
	Event:Fire('Hide', 'Except', ExclusionList or {})
end

function Hide:HideElements(List)
	Event:Fire('Hide', 'Including', List or {})
end

function Hide:ShowInterface(ExclusionList)
	Event:Fire('Show', 'Except', ExclusionList or {})
end

function Hide:ShowElements(List)
	Event:Fire('Show', 'Including', List or {})
end

return Hide
