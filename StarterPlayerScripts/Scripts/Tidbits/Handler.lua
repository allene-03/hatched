local Replicated = game:GetService('ReplicatedStorage')
local ContentProvider = game:GetService('ContentProvider')
local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')

local Randomize = Random.new()

local Models = workspace:WaitForChild('Tidbits')

--This is the same one that catalog module uses :)
local CentralizedGearFunction = Replicated:WaitForChild('Remotes'):WaitForChild('Catalog'):WaitForChild('ChangeAvatar') 

local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Tidbits')
local Client, Server = Remotes:WaitForChild('Client'), Remotes:WaitForChild('Server')

local Interact = require(game.ReplicatedStorage:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Core'))
local Animation = require(Replicated:WaitForChild('Modules'):WaitForChild('Animation'):WaitForChild('Core'))

local LocalPlayer = Players.LocalPlayer

-- Influence:
local Influence = Models:WaitForChild('Influence')
local InfluenceClick = Influence:WaitForChild('Button'):WaitForChild('Click')

local CooldownLength = 3.25
local Cooling = false

-- Probably find new image options (copyright and all)
local Options = {
	Text = {'Gorgeous', 'Slayyy', 'Nice!', 'Omg', 'Show up'},
	Image = {'rbxassetid://7277737820', 'rbxassetid://7277737603', 'rbxassetid://7277737409', 'rbxassetid://7277737158'}
}

local Seperate = '⭐️'

-- Preload the images
ContentProvider:PreloadAsync(Options.Image)

-- Should be the UI interface click thing instead
InfluenceClick.MouseClick:Connect(function()
	if not Cooling then
		Cooling = true
		local ChosenText = Options.Text[Randomize:NextInteger(1, #Options.Text)]
		
		Client:Fire('Influence', {
			Text = Seperate .. ' ' .. ChosenText .. ' ' .. Seperate,
			Image = Options.Image[Randomize:NextInteger(1, #Options.Image)],
			Player = LocalPlayer.Name
		})
		
		task.wait(CooldownLength)
		Cooling = false
	end
end)

-- Aerospace
local Aerospace = Models:WaitForChild('Aerospace')
local AerospaceClick = Aerospace:WaitForChild('Button'):WaitForChild('Click')

AerospaceClick.MouseClick:Connect(function()
	Server:FireServer('Aerospace')
end)

-- Health
local Health = Models:WaitForChild('Health')
local HealthClick = Health:WaitForChild('Button'):WaitForChild('Click')

HealthClick.MouseClick:Connect(function()
	Server:FireServer('Health')
end)

-- Education
local Education = Models:WaitForChild('Education')
local Whiteboards = Education:WaitForChild('Whiteboards')
local ReferencingWhiteboard = Whiteboards:WaitForChild('Whiteboard')

Interact:Listen(Education:WaitForChild('Button'), 'Click', 'Write', function()
	Client:Fire('Education', {Name = ReferencingWhiteboard.Index.Value})
end)

-- Safety
local Safety = Models:WaitForChild('Safety')
local SafetyBaton, SafetyTaser = Safety:WaitForChild('Baton'), Safety:WaitForChild('Taser')

local SafetyClicks = {
	Baton = SafetyBaton:WaitForChild('Click'),
	Taser = SafetyTaser:WaitForChild('Click')
}

for _, Click in pairs(SafetyClicks) do
	local Identification = Click.Parent:WaitForChild('Identification')
	
	Click.MouseClick:Connect(function()
		CentralizedGearFunction:InvokeServer('gear', tonumber(Identification.Value))
	end)
end

-- First response - this is set up to be locally rendered
local FirstResponse = Models:WaitForChild('First Response')
local Sirens = FirstResponse:WaitForChild('Sirens')
local ReferencingSiren = Sirens:FindFirstChild('Light')
local FirstResponseClick = FirstResponse:WaitForChild('Button'):WaitForChild('Click')
local ActiveSirens = {}

local function TweenSiren(Model)
	local DoorRoot = Model.PrimaryPart

	if DoorRoot then
		local Information = TweenInfo.new(0.75, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false)

		local Tween = TweenService:Create(DoorRoot, Information, {
			CFrame = DoorRoot.CFrame * CFrame.Angles(0, math.rad(180), 0)
		})

		Tween:Play()

		return Tween
	end
end

local function ChangeSiren(Siren, Mode)
	if Mode == 'On' then
		Siren.Middle.Color = Color3.new(1, 0, 0)

		for _, Element in pairs(Siren:GetDescendants()) do
			if Element.ClassName == 'SurfaceGui' or Element.ClassName == 'Beam' then
				Element.Enabled = true
			end
		end
		
		ActiveSirens[Siren] = TweenSiren(Siren)
	elseif Mode == 'Off' then
		Siren.Middle.Color = Color3.new(1, 1, 1)
		
		for _, Element in pairs(Siren:GetDescendants()) do
			if Element.ClassName == 'SurfaceGui' or Element.ClassName == 'Beam' then
				Element.Enabled = false
			end
		end
		
		if ActiveSirens[Siren] then
			ActiveSirens[Siren]:Cancel()
			ActiveSirens[Siren] = nil
		end
	end
end

for _, Siren in pairs(Sirens:GetChildren()) do
	ChangeSiren(Siren, 'Off')
end

FirstResponseClick.MouseClick:Connect(function()
	-- This should work if you decide to scale with multiple sirens
	if ActiveSirens[ReferencingSiren] then
		ChangeSiren(ReferencingSiren, 'Off')
	else
		ChangeSiren(ReferencingSiren, 'On')
	end
end)

-- Zoology
local Zoology = Models:WaitForChild('Zoology')
local Bowls = Zoology:WaitForChild('Bowls')
local ReferencingBowl = Bowls:WaitForChild('Bowl')
local ZoologyClick = Zoology:WaitForChild('Button'):WaitForChild('Click')

ZoologyClick.MouseClick:Connect(function()
	ReferencingBowl.Water.Transparency = (ReferencingBowl.Water.Transparency < 1) and 1 or 0
end)

-- Food
local Food = Models:WaitForChild('Food')
local Pizzas = Food:WaitForChild('Pizzas')
local ReferencingPizza = Pizzas:WaitForChild('Pizza')

local FoodComponents = {
	Main = {
		Cheese = ReferencingPizza:WaitForChild('Main'):WaitForChild('Cheese'),
		Pepperoni = ReferencingPizza:WaitForChild('Main'):WaitForChild('Pepperoni')
	},
	
	Representing = {
		Cheese = ReferencingPizza:WaitForChild('Parts'):WaitForChild('Cheese'),
		Pepperoni = ReferencingPizza:WaitForChild('Parts'):WaitForChild('Pepperoni')
	}
}

FoodComponents.Representing.Cheese.Click.MouseClick:Connect(function()
	FoodComponents.Main.Cheese.Transparency = (FoodComponents.Main.Cheese.Transparency < 1) and 1 or 0
end)

FoodComponents.Representing.Pepperoni.Click.MouseClick:Connect(function()
	FoodComponents.Main.Pepperoni.Transparency = (FoodComponents.Main.Pepperoni.Transparency < 1) and 1 or 0
end)

-- Petcare
local Petcare = Models:WaitForChild('Petcare')
local Whistle = Petcare:WaitForChild('Whistle')

local Identification = Whistle:WaitForChild('Identification')
local PetcareClick = Whistle:WaitForChild('Click')

PetcareClick.MouseClick:Connect(function()
	CentralizedGearFunction:InvokeServer('gear', tonumber(Identification.Value))
end)

-- Art
local Art = Models:WaitForChild('Art')

for _, Button in pairs(Art:GetChildren()) do
	local NewAnimation = Button:WaitForChild('Animation')

	Button:WaitForChild('Click').MouseClick:Connect(function()
		Animation:PlayAnimation(LocalPlayer.Character, NewAnimation.Value, {Looped = true})
	end)
end

-- Glamour
local Glamour = Models:WaitForChild('Glamour')
local GlamourClick = Glamour:WaitForChild('Button'):WaitForChild('Click')
local GlamourRemote = Replicated:WaitForChild('Remotes'):WaitForChild('Catalog'):WaitForChild('ClientInteractions')

GlamourClick.MouseClick:Connect(function()
	GlamourRemote:Fire('Makeup')
end)

-- Label
local Label = Models:WaitForChild('Label')
local Piano = Label:WaitForChild('Piano')
local PianoSeat = Piano:WaitForChild('Seating'):WaitForChild('Seat')

Interact:Listen(Label:WaitForChild('Button'), 'Click', 'Play', function()
	Server:FireServer('Label', {Piano = Piano}) -- Add server checks
end)

PianoSeat:GetPropertyChangedSignal('Occupant'):Connect(function()
	local Character, Occupant = LocalPlayer.Character, PianoSeat.Occupant
	
	if Character then
		local Humanoid = Character:FindFirstChild('Humanoid')
		
		if Humanoid then
			if Humanoid == Occupant then
				Animation:PlayAnimation(Character, 'Piano', {Looped = true})
			end
		end
	end
end)

-- Law
local Law = Models:WaitForChild('Law')
local LawClick = Law:WaitForChild('Button'):WaitForChild('Click')
local Desktop = Law:WaitForChild('Desktop')
local DesktopSeat = Desktop:WaitForChild('Seating'):WaitForChild('Seat')

LawClick.MouseClick:Connect(function()
	Server:FireServer('Law', {Desk = Desktop}) -- Add server checks
end)

DesktopSeat:GetPropertyChangedSignal('Occupant'):Connect(function()
	local Character, Occupant = LocalPlayer.Character, DesktopSeat.Occupant

	if Character then
		local Humanoid = Character:FindFirstChild('Humanoid')

		if Humanoid then
			if Humanoid == Occupant then
				Animation:PlayAnimation(Character, 'Typing', {Looped = true})
			end
		end
	end
end)

-- Home
local Home = Models:WaitForChild('Home')
local Plunger = Home:WaitForChild('Plunger')

local Identification = Plunger:WaitForChild('Identification')
local HomeClick = Plunger:WaitForChild('Click')

HomeClick.MouseClick:Connect(function()
	CentralizedGearFunction:InvokeServer('gear', tonumber(Identification.Value))
end)

-- Where reception events are stored
Server.OnClientEvent:Connect(function(Mode, Details)
	if Mode == 'Education' then
		-- Find the corresponding board
		local Found
		
		for _, Board in pairs(Whiteboards:GetChildren()) do
			if Board:FindFirstChild('Index') and Board.Index.Value == Details.Board then
				Found = Board
			end
		end
		
		if Found then
			Found.Holder.Surface.Label.Text = Details.Text
		end
	end
end)