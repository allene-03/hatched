-- Core products module table

local CoreProductsModule = {
	Assets = {
		Gamepasses = {
			[25935037] = {
				Core = {
					Name = 'Ludicrous Mode',
					Price = 150,
				},

				Interface = {
					Type = 'Default',
					Icon = 'rbxassetid://8217866295',
					DisplayOrder = 1,

					Description = "Unleash your vehicles' speed demon.",
				}
			},
		},

		DevProducts = {
			-- Main
			
			-- Cash
			[1232162956] = {
				Core = {
					Name = '100 Cash',
					Price = 50,
				},

				Interface = {
					Type = 'Cash',
					Icon = '',
					DisplayOrder = 1,
					
					Title = '100',
					SpecialAesthetics = false,
				},

				-- Fire some bindable to consolidated pass handler place
				Callback = function(Profile)
					print('Product successfully purchased for 100 cash.')
				end
			},
			
			[1232162966] = {
				Core = {
					Name = '250 Cash',
					Price = 100,
				},

				Interface = {
					Type = 'Cash',
					Icon = '',
					DisplayOrder = 2,

					Title = '250',
					SpecialAesthetics = false,
				},

				-- Fire some bindable to consolidated pass handler place
				Callback = function(Profile)
					print('Product successfully purchased for 100 cash.')
				end
			},
			
			[1232162975] = {
				Core = {
					Name = '500 Cash',
					Price = 150,
				},

				Interface = {
					Type = 'Cash',
					Icon = '',
					DisplayOrder = 3,

					Title = '500',
					SpecialAesthetics = true,
				},

				-- Fire some bindable to consolidated pass handler place
				Callback = function(Profile)
					print('Product successfully purchased for 100 cash.')
				end
			},

			-- Offers
			[25935039] = {
				Core = {
					Name = 'Starter Pack',
					Price = 95,
				},

				Interface = {
					Type = 'Default',
					Icon = 'rbxassetid://8217866295',
					DisplayOrder = 0,

					Description = 'Bundle to get started.',
				},

				-- Fire some bindable to consolidated pass handler place
				Callback = function(Profile)
					print('Product successfully purchased for the starter pack.')
				end
			},
			
			-- Others
			[25935032] = {
				Core = {
					Name = 'Hatch Now',
					Price = 100,
				},

				Interface = {
					Disabled = true
				},

				-- Fire some bindable to consolidated pass handler place
				Callback = function(Profile)
					print('Product successfully purchased for Hatch Now.')
				end
			},
		},
	},
}

-- Functions
function CoreProductsModule:FetchProductId(ProductType, ProductName)
	for ProductId, Product in pairs(CoreProductsModule['Assets'][ProductType]) do
		local ProductCoreData = Product.Core

		if ProductCoreData and ProductCoreData.Name == ProductName then
			return ProductId
		end
	end
end

function CoreProductsModule:FetchProductData(ProductType, ProductId)
	local ProductTypeData = CoreProductsModule['Assets'][ProductType]

	if ProductTypeData then
		return ProductTypeData[ProductId]
	end
end

return CoreProductsModule