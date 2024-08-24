-- Around 10,000+ lines worth of scraped JSON entries to be used by the catalog so players could choose custom items, so excluded

return {
	Accessories = require(script.Accessories),
	Clothing = require(script.Clothes),
	Animations = require(script.Animations),
	BodyParts = require(script.Body),
	Gear = {require(script.Gear)},	-- Gear has no categories so wrap it in a table
}