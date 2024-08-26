local Replicated = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')

local DataModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Data'):WaitForChild('Core'))

local RemotesFolder = Replicated:WaitForChild('Remotes'):WaitForChild('Home')
local HomesModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Home'):WaitForChild('Core'))

local PurchasingRemote = RemotesFolder:FindFirstChild('Purchasing')
local RenamingRemote = RemotesFolder:FindFirstChild('Renaming')
local HandlingRemote = RemotesFolder:FindFirstChild('Handling')

local RootFrame = script.Parent
local TemplatesFolder = script:WaitForChild('Templates')

local PrimaryFrame = RootFrame:FindFirstChild('Primary')
local SelectionFrame = RootFrame:FindFirstChild('Selection')

local OptionsFrame = SelectionFrame:WaitForChild('Body'):WaitForChild('Options')
local PrimarySelectionFrame = PrimaryFrame:WaitForChild('Selection'):WaitForChild('Body')
local PrimaryMainFrame = PrimaryFrame:WaitForChild('Body'):WaitForChild('Main')

local SelectionExitButton = SelectionFrame:WaitForChild('Exit')
local PrimaryExitButton = PrimaryFrame:WaitForChild('Exit')

local OpenButton = RootFrame:WaitForChild('Button')

local BuyButton = OptionsFrame.Parent:WaitForChild('Buy')
local SellButton = PrimarySelectionFrame:WaitForChild('Sell')
local EquipButton = PrimarySelectionFrame:WaitForChild('Equip')

local Notify = Replicated:WaitForChild('Remotes'):WaitForChild('Systems'):WaitForChild('Notify')

local HomeObjects = {}

local SelectedElements = {PurchaseSelection = {}, HomeSelection = {}}
local ConfirmedElements = {PurchaseSelection = false, HomeSelection = false}

local HomeRenameTextLimit = 12

local Templates = {
	Primary = TemplatesFolder:FindFirstChild('Primary'),
	Selection = TemplatesFolder:FindFirstChild('Selection'),
}

local Colors = {
	Primary = {
		Standard = Templates.Primary.Label.BackgroundColor3,
		Selected = Color3.fromRGB(27, 212, 97)
	},
	
	Selection = {
		Standard = Templates.Selection.Label.Border.Color,
		Selected = Color3.fromRGB(27, 212, 97)
	},
	
	Equip = {
		Background = {
			Standard = EquipButton.BackgroundColor3,
			Defaulted = Color3.fromRGB(206, 203, 207)
		},
		
		Text = {
			Standard = EquipButton.Label.TextColor3,
			Defaulted = Color3.fromRGB(152, 150, 153)
		}
	}
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

local function Confirming(Type, Confirm)
	if Confirm then
		if Type == 'Purchase' then
			ConfirmedElements.PurchaseSelection = true
			BuyButton.Label.Text = 'Confirm'
		elseif Type == 'Sell' then
			ConfirmedElements.HomeSelection = true
			SellButton.Label.Text = 'Confirm'
		else
			warn('Confirm type not found.')
		end
	else
		if Type == 'Purchase' then
			ConfirmedElements.PurchaseSelection = false
			BuyButton.Label.Text = 'Purchase'
		elseif Type == 'Sell' then
			ConfirmedElements.HomeSelection = false
			SellButton.Label.Text = 'Sell'
		else
			warn('Confirm type not found.')
		end
	end
end

local function Equipping(Equip)
	if Equip then
		EquipButton.BackgroundColor3 = Colors.Equip.Background.Defaulted
		EquipButton.Label.TextColor3 = Colors.Equip.Text.Defaulted
	else
		EquipButton.BackgroundColor3 = Colors.Equip.Background.Standard
		EquipButton.Label.TextColor3 = Colors.Equip.Text.Standard
	end
end

local function CreateOwnedHomeButton(Index, Home)
	local PrimaryTemplate = Templates['Primary']:Clone()
	PrimaryTemplate.Label.Text = Home.Name
	
	HomeObjects[PrimaryTemplate] = Index

	-- Add icon part here
	PrimaryTemplate.Parent = PrimaryMainFrame

	PrimaryTemplate.MouseButton1Down:Connect(function()
		Confirming('Sell', false)
		SellButton.Price.Text = '$' .. math.round(HomesModule['Homes'][Home.Type]['Price'] * HomesModule.SellPercentage)
		
		if SelectedElements.HomeSelection.Object then
			SelectedElements.HomeSelection.Object.Label.BackgroundColor3 = Colors.Primary.Standard
		end
		
		local LocatedHome
		
		if DataModule['PlayerData']['Homes'] then
			LocatedHome = DataModule['PlayerData']['Homes'][Index]
		end
		
		if LocatedHome and LocatedHome.Default then
			Equipping(true)
		else
			Equipping(false)
		end
		
		SelectedElements.HomeSelection.Object = PrimaryTemplate
		SelectedElements.HomeSelection.Value = Index

		SelectedElements.HomeSelection.Object.Label.BackgroundColor3 = Colors.Primary.Selected
	end)
	
	local SavedText = PrimaryTemplate.Label.Text
	
	PrimaryTemplate.Label.FocusLost:Connect(function()
		local NewText = SavedText
		local Success, Name = RenamingRemote:InvokeServer(Index, NewText)
		
		if Success then
			SavedText = Name
		end
		
		PrimaryTemplate.Label.Text = SavedText
	end)
	
	PrimaryTemplate.Label:GetPropertyChangedSignal('Text'):Connect(function()	
		if #PrimaryTemplate.Label.Text > HomeRenameTextLimit then
			PrimaryTemplate.Label.Text = SavedText
		else
			SavedText = PrimaryTemplate.Label.Text
		end
	end)
end

-- Forked from Constrained/Jobs/Subhandler
local function DisplayedOrderSort(Homes)
	local HomesKeyList = {}

	for Key, Home in pairs(Homes) do
		table.insert(HomesKeyList, {Home = Key, Order = Home.DisplayOrder or HomesModule.DefaultDisplayOrder})
	end

	HomesKeyList = Sort(HomesKeyList)

	for Index, HomeInformation in pairs(HomesKeyList) do
		HomesKeyList[Index] = HomeInformation.Home
	end

	return HomesKeyList
end

local OrganizedHomes = DisplayedOrderSort(HomesModule.Homes)

-- Selection aspect
for _, Name in pairs(OrganizedHomes) do
	local Home = HomesModule['Homes'][Name]
	
	local SelectionTemplate = Templates['Selection']:Clone()
	SelectionTemplate.Label.Text = Name
	SelectionTemplate.Name = Name
	
	-- Add icon part here
	SelectionTemplate.Parent = OptionsFrame
	
	SelectionTemplate.MouseButton1Down:Connect(function()
		Confirming('Purchase', false)
		BuyButton.Price.Text = '$' .. Home.Price
		
		if SelectedElements.PurchaseSelection.Object then
			SelectedElements.PurchaseSelection.Object.Label.Border.Color = Colors.Selection.Standard
		end

		SelectedElements.PurchaseSelection.Object = SelectionTemplate
		SelectedElements.PurchaseSelection.Value = Name

		SelectedElements.PurchaseSelection.Object.Label.Border.Color = Colors.Selection.Selected
	end)
end

BuyButton.MouseButton1Down:Connect(function()
	if SelectedElements.PurchaseSelection.Value then
		if ConfirmedElements.PurchaseSelection == true then
			local Action = PurchasingRemote:InvokeServer(SelectedElements.PurchaseSelection.Value)
			Confirming('Purchase', false)

			if Action == 'Success' then
				if SelectedElements.HomeSelection.Object then
					SelectedElements.HomeSelection.Object.Label.BackgroundColor3 = Colors.Primary.Standard
				end
				
				
				if SelectedElements.PurchaseSelection.Object then
					SelectedElements.PurchaseSelection.Object.Label.Border.Color = Colors.Selection.Standard
				end
				
				-- Already deconfirmed purchase, so just deconfirm sell now
				Confirming('Sell', false)
				Equipping(false)
				
				SelectionFrame.Visible = false
				
				SellButton.Price.Text = ''
				BuyButton.Price.Text = ''

				SelectedElements.HomeSelection = {}
				SelectedElements.PurchaseSelection = {}
			elseif Action == 'Excessive' then
				Notify:Fire('The maximum number of homes you can own at a time is 8.')
			end
		else
			Confirming('Purchase', true)
		end
	else
		Notify:Fire('Please select a home to purchase.')
	end
end)

SelectionExitButton.MouseButton1Down:Connect(function()
	Confirming('Purchase', false)
	SelectionFrame.Visible = false
end)

-- Primary aspect
SellButton.MouseButton1Down:Connect(function()
	if SelectedElements.HomeSelection.Value then
		if ConfirmedElements.HomeSelection then
			Confirming('Sell', false)
			local Sold = HandlingRemote:InvokeServer('Selling', SelectedElements.HomeSelection.Value)
			
			if Sold then
				local SelectedHomeObject = SelectedElements.HomeSelection.Object
				
				-- This is to make sure the deselected item isn't the one we just sold that has it's properties locked
				if SelectedHomeObject and SelectedHomeObject.Parent ~= nil then
					SelectedElements.HomeSelection.Object.Label.BackgroundColor3 = Colors.Primary.Standard
				end
				
				Equipping(false)
				
				SellButton.Price.Text = ''
				SelectedElements.HomeSelection = {}
			end
		else
			Confirming('Sell', true)
		end
	else
		Notify:Fire('Please select a home to sell.')
	end
end)

EquipButton.MouseButton1Down:Connect(function()
	if SelectedElements.HomeSelection.Value then
		local Equipped = HandlingRemote:InvokeServer('Equipping', SelectedElements.HomeSelection.Value)
		
		if Equipped then
			Equipping(true)
		end
	else
		Notify:Fire('Please select a home to equip.')
	end
end)

PrimaryMainFrame.New.MouseButton1Down:Connect(function()
	CommonTween(PrimaryMainFrame.New)
	SelectionFrame.Visible = true
end)

PrimaryExitButton.MouseButton1Down:Connect(function()
	Confirming('Purchase', false)
	Confirming('Sell', false)

	SelectionFrame.Visible = false
	PrimaryFrame.Visible = false
end)

-- Main sequence
OpenButton.MouseButton1Down:Connect(function()
	if PrimaryFrame.Visible == false then
		PrimaryFrame.Visible = true
	else
		Confirming('Purchase', false)
		Confirming('Sell', false)

		SelectionFrame.Visible = false
		PrimaryFrame.Visible = false
	end
end)

BuyButton.Price.Text = ''
SellButton.Price.Text = ''

SelectionFrame.Visible = false
PrimaryFrame.Visible = false

local Homes = DataModule:Wait(DataModule, 'PlayerData', 'Homes')

if Homes then
	for Index, Home in pairs(Homes) do
		CreateOwnedHomeButton(Index, Home)
	end
end

local HomeAdded, HomeRemoved = DataModule:ChildAdded(DataModule.PlayerData, 'Homes'), DataModule:ChildRemoved(DataModule.PlayerData, 'Homes')

HomeAdded.Event:Connect(function(Index, Home)
	CreateOwnedHomeButton(Index, Home)
end)

HomeRemoved.Event:Connect(function()
	for HomeTemplate, HomeIndex in pairs(HomeObjects) do
		if not Homes[HomeIndex] then
			HomeTemplate:Destroy()
		end
	end
end)