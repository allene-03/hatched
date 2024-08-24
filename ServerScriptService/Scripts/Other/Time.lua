-- SOURCE:
-- https://devforum.roblox.com/t/a-guide-to-a-better-looking-and-more-realistic-day-night-cycle/392643/39

-- Services
local Lighting = game:GetService('Lighting')
local Replicated = game:GetService('ReplicatedStorage')

-- Modules
local Settings = require(Replicated.Modules.Utility.Settings)

-- Variables
local Pi = math.pi

-- Independents
local MinutesAfterMidnight
local Reference
local Ambience
local Red, Green, Blue

-- Mutables
local Shift = 1 -- The minutes you shift every 'tick', essentially speed... default = 3.2
local Time = 36 -- 36, The total minute value for the entire cycle (Pretty much the only value that should be edited)
local Total = math.floor(((60 * 24) / Shift) + 0.5) -- Don't change
local Cycle = ((Time * 60) / Total)

-- Brightness Settings
local AmplitudeBrightness = 1
local OffsetBrightness = 2

-- OutdoorAmbience Settings
local AmplitudeOutdoorAmbience = 20
local OffsetOutdoorAmbience = 100

-- ShadowSoftness Settings
local AmplitudeShadowSoftness = 0.2
local OffsetShadowSoftness = 0.8

-- Predefined sequence of colors for 24-hour shift
local RedList = {0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0}
local GreenList = {165, 165, 165, 165, 165, 255, 215, 230, 255, 255, 255, 255, 255, 255, 255, 245, 230, 215, 255, 165, 165, 165, 165, 165}
local BlueList = {255, 255, 255, 255, 255, 255, 110, 135, 255, 255, 255, 255, 255, 255, 255, 215, 135, 110, 255, 255, 255, 255, 255, 255}

while true do
	MinutesAfterMidnight = Lighting:GetMinutesAfterMidnight() + Shift
	Lighting:SetMinutesAfterMidnight(math.floor(MinutesAfterMidnight + 0.5))
	MinutesAfterMidnight /= 60
	
	Lighting.Brightness = AmplitudeBrightness * math.cos(MinutesAfterMidnight * (Pi / 12) + Pi) + OffsetBrightness

	Ambience = AmplitudeOutdoorAmbience * math.cos(MinutesAfterMidnight * (Pi / 12) + Pi) + OffsetOutdoorAmbience
	Lighting.OutdoorAmbient = Color3.fromRGB(Ambience, Ambience, Ambience)

	Lighting.ShadowSoftness = AmplitudeShadowSoftness * math.cos(MinutesAfterMidnight * (Pi / 6)) + OffsetShadowSoftness

	Reference = math.clamp(math.ceil(MinutesAfterMidnight), 1, 24)
	
	Red = ((RedList[Reference % 24 + 1] - RedList[Reference]) * (MinutesAfterMidnight - Reference + 1)) + RedList[Reference]
	Green = ((GreenList[Reference % 24 + 1] - GreenList[Reference]) * (MinutesAfterMidnight - Reference + 1)) + GreenList[Reference]
	Blue = ((BlueList[Reference % 24 + 1] - BlueList[Reference]) * (MinutesAfterMidnight - Reference + 1)) + BlueList[Reference]
	
	Lighting.ColorShift_Top = Color3.fromRGB(Red, Green, Blue)

	task.wait(Cycle)
end
