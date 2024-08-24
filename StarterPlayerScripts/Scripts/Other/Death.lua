local Replicated = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local StarterGui = game:GetService('StarterGui')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local FadeEffect = require(Replicated:WaitForChild('Modules'):WaitForChild('Fade'):WaitForChild('Core'))

local DeathRemote = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('Death')
local ResetBindable = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('InvokeDeath')

local MaxRetries = 10
local MaxYieldTime = 5

local Resetting = false

-- Functions
function coreCall(method, ...) -- From DevForum
	local result = {}

	for retries = 1, 10 do
		result = {pcall(StarterGui[method], StarterGui, ...)}
		if result[1] then
			break
		end

		RunService.Stepped:Wait()
	end

	return unpack(result)
end

-- Connections
ResetBindable.Event:Connect(function()
	if Resetting then
		return
	end
	
	Resetting = true
	
	local EndFadeEffect = FadeEffect:StartTween(Color3.fromRGB(253, 136, 145))
	
	-- Disable red flash effect
	coreCall('SetCore', Enum.CoreGuiType.Health, false)
	
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	
	local Ended
	
	-- Spawn max-yield remote for race condition
	task.spawn(function()
		local Counted = 0
		
		repeat
			Counted += task.wait()
		until (Ended or Counted >= MaxYieldTime)
		
		Ended = true
	end)
	
	-- Death event
	task.spawn(function()
		DeathRemote:InvokeServer()
		Ended = true
	end)
	
	repeat
		task.wait()
	until (Ended)
	
	-- Re-enable red flash effect in case used later
	coreCall('SetCore', Enum.CoreGuiType.Health, true)
	EndFadeEffect()
	
	Resetting = false
end)

-- Main sequence
coreCall('SetCore', 'ResetButtonCallback', ResetBindable)


-- Check this for errors, as you may know errors here are gamebreaking bugs.