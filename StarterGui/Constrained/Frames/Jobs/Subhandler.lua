local TweenService = game:GetService('TweenService')
local Replicated = game:GetService('ReplicatedStorage')

local JobsModule = require(Replicated.Modules:WaitForChild('Jobs'):WaitForChild('Core'))
local DataModule = require(Replicated.Modules:WaitForChild('Data'):WaitForChild('Core'))

local Requesting = Replicated:WaitForChild('Remotes'):WaitForChild('Jobs'):WaitForChild('Requesting')
local Notify = Replicated.Remotes:WaitForChild('Systems'):WaitForChild('Notify')

local Frame = script.Parent
local Primary = Frame:WaitForChild('Primary')

local TemplatesFolder = script:WaitForChild('Templates')
local Side, Main = Primary:WaitForChild('Side'), Primary:WaitForChild('Main')

local Listing = Side:WaitForChild('Listing')
local Viewing

-- Stores interacted button for each Main tab
local ButtonMatrix = {}
local SelectedJob

local Templates = {
	Side = TemplatesFolder:WaitForChild('Side'),
	Main = TemplatesFolder:WaitForChild('Main'),
	Listing = TemplatesFolder:WaitForChild('Listing')
}

local Colors = {
	Selected = Color3.fromRGB(67, 236, 164),
	Interacted = Color3.fromRGB(48, 189, 233)
}

-- Forked from Modules/Utility/Settings
function Sort(Table)
	local Gap = math.floor(#Table / 2)

	while Gap > 0 do 
		for Iteration = Gap, #Table do
			local Temp = Table[Iteration]
			local Switch = Iteration

			while (Switch > Gap and Table[Switch - Gap]['Order'] > Temp['Order']) do
				Table[Switch] = Table[Switch - Gap]
				Switch -= Gap
			end

			Table[Switch] = Temp
		end

		Gap = math.floor(Gap / 2)
	end

	return Table
end

local function Tween(Object, Info, Properties)
	local Tween = TweenService:Create(Object, Info, Properties)
	Tween:Play()

	return Tween
end

local function CommonTween(Button)
	local Playing = Tween(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Position = Button.Shadow.Position})

	Playing.Completed:Wait()

	Playing = Tween(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Position = UDim2.fromScale(0.5, 0)})

	Playing.Completed:Wait()
end

local function Switch(Button)
	if Button == Viewing then
		return
	end
	
	for _, Frame in pairs(Main:GetChildren()) do
		Frame.Visible = false
	end
	
	local Frame = Main[Button.Name]
	Frame.Visible = true
	
	Viewing = Button
end

local function Interact(Button, Frame)	
	for _, Button in pairs(Frame.Display.Listing:GetChildren()) do
		if Button.ClassName == 'TextButton' then
			if SelectedJob ~= Button then
				local Default = Button.Picture.Icon.ImageColor3
				
				Button.Title.TextColor3 = Default
				Button.Picture.Shadow.BackgroundColor3 = Default
			end
		end
	end
	
	-- Deselect on clicked again
	if Button and Button ~= ButtonMatrix[Frame]['Interact'] then
		if SelectedJob ~= Button then
			Button.Title.TextColor3 = Colors.Interacted
			Button.Picture.Shadow.BackgroundColor3 = Colors.Interacted
		end
		
		ButtonMatrix[Frame]['Interact'] = Button
	else
		ButtonMatrix[Frame]['Interact'] = nil
	end
end

local function Select(Button, Field)
	if not Button or Button.ClassName ~= 'TextButton' then
		return
	end
	
	Requesting:FireServer(Field, Button.Name)
end

local function DisplayedOrderSort(Fields)
	local FieldsKeyList = {}
	
	for Key, Field in pairs(Fields) do
		table.insert(FieldsKeyList, {Field = Key, Order = Field.DisplayOrder or JobsModule.DefaultDisplayOrder})
	end
	
	FieldsKeyList = Sort(FieldsKeyList)
	
	for Index, FieldInformation in pairs(FieldsKeyList) do
		FieldsKeyList[Index] = FieldInformation.Field
	end
	
	return FieldsKeyList
end

Requesting.OnClientEvent:Connect(function(Warning)
	Notify:Fire(Warning)
end)

-- Establish the job sorting and initialization
local OrganizedJobs = DisplayedOrderSort(JobsModule.Fields)

for _, Name in pairs(OrganizedJobs) do	
	local Field = JobsModule['Fields'][Name]
	
	local Color = Field.Color
	local Light, Dark, Midlight = Color:Lerp(Color3.new(1, 1, 1), 0.25), Color:Lerp(Color3.new(0, 0, 0), 0.25), Color:Lerp(Color3.new(1, 1, 1), 0.1)
	
	local SideTemplate = Templates.Side:Clone()
	
	SideTemplate.Name = Name
	SideTemplate.Main.BackgroundColor3 = Color
	
	SideTemplate.Main.Title.Text = string.upper(Name)
	SideTemplate.Main.Title.TextColor3 = Dark
	
	SideTemplate.Shadow.BackgroundColor3 = Dark
	
	SideTemplate.Main.Picture.BackgroundColor3 = Light
	
	SideTemplate.Main.Picture.Icon.ImageColor3 = Dark
	SideTemplate.Main.Picture.Icon.Image = Field.Image
	
	SideTemplate.Main.Picture.Selected.Visible = false
	
	SideTemplate.Parent = Listing
	
	local MainTemplate = Templates.Main:Clone()
	MainTemplate.Shadow.BackgroundColor3 = Dark
	MainTemplate.Name = Name
	
	ButtonMatrix[MainTemplate] = {}

	local Display = MainTemplate.Display
	Display.BackgroundColor3 = Midlight
	
	Display.Title.Text = string.upper(Name)
	Display.Title.TextColor3 = Dark
	
	Display.Description.Text = Field.Description
	Display.Description.TextColor3 = Dark
	
	Display.Border.TextColor3 = Dark
	
	Display.Icon.Image = Field.Image
	Display.Icon.ImageColor3 = Dark
	
	-- Establish event event to select new button
	Display.Select.MouseButton1Down:Connect(function()
		Select(ButtonMatrix[MainTemplate]['Interact'], Name)
	end)
	
	-- Set up the job options
	for _, Job in pairs(Field.List) do
		local Name, Image = Job.Name, Job.Image
		local ListingTemplate = Templates.Listing:Clone()
		
		ListingTemplate.Picture.BackgroundColor3 = Light
		ListingTemplate.Picture.Shadow.BackgroundColor3 = Dark
		
		ListingTemplate.Picture.Icon.Image = Image
		ListingTemplate.Picture.Icon.ImageColor3 = Dark

		ListingTemplate.Picture.Selected.Visible = false
		
		ListingTemplate.Title.Text = string.upper(Name)
		ListingTemplate.Title.TextColor3 = Dark
		
		ListingTemplate.Name = Name
		
		ListingTemplate.MouseButton1Down:Connect(function()
			Interact(ListingTemplate, MainTemplate)
		end)
		
		ListingTemplate.Parent = Display.Listing
	end
		
	MainTemplate.Visible = false
	MainTemplate.Parent = Main
	
	-- Establish event to switch to the new tab
	SideTemplate.MouseButton1Down:Connect(function()
		CommonTween(SideTemplate)
		Switch(SideTemplate)
	end)
	
	-- Get the 'default' button to set it to
	if not Viewing then
		Switch(SideTemplate)
	end
end

-- Wait for the player's job and then set... also set event for when job switches
local JobTable = DataModule:Wait(DataModule, 'PlayerData', 'Job')

if JobTable and JobTable.Field and JobTable.Name then
	local Frame = Main:FindFirstChild(JobTable.Field)

	if Frame then
		local Button = Frame['Display']['Listing']:FindFirstChild(JobTable.Name)
		
		if Button then
			-- This will rawset the items (Convert this to function and call for this and select)
			Button.Title.TextColor3 = Colors.Selected
			Button.Picture.Selected.Visible = true
			Button.Picture.Shadow.BackgroundColor3 = Colors.Selected

			Listing[JobTable.Field].Main.Picture.Selected.Visible = true

			SelectedJob = Button
		end
	end
end

local JobChanged = DataModule:Changed(DataModule.PlayerData, 'Job')

JobChanged.Event:Connect(function()
	local Data = DataModule.PlayerData.Job
	
	if Data then
		if SelectedJob and SelectedJob.ClassName == 'TextButton' then
			local Default = SelectedJob.Picture.Icon.ImageColor3

			SelectedJob.Title.TextColor3 = Default
			SelectedJob.Picture.Selected.Visible = false
			SelectedJob.Picture.Shadow.BackgroundColor3 = Default

			local Sidebar = Listing[SelectedJob.Parent.Parent.Parent.Name]
			Sidebar.Main.Picture.Selected.Visible = false
		end

		local NewSidebar = Listing:WaitForChild(Data.Field)
		local NewMain = Main:WaitForChild(Data.Field)['Display']['Listing']:WaitForChild(Data.Name)

		-- Setting the interact field to nil
		Interact(nil, Main[Data.Field])

		NewMain.Title.TextColor3 = Colors.Selected
		NewMain.Picture.Selected.Visible = true
		NewMain.Picture.Shadow.BackgroundColor3 = Colors.Selected

		NewSidebar.Main.Picture.Selected.Visible = true

		SelectedJob = NewMain
	end
end)

