local Jobs = {
	Fields = {
		['Unemployed'] = {
			List = {
				{Name = 'Default', Image = 'rbxassetid://7256574955'},
			},
			
			Description = 'A task for the truly lazy and jobless human beings.',
			Image = 'rbxassetid://7256929064',
			Color = Color3.fromRGB(255,99,71),
			DisplayOrder = 1,
		},
		
		['Criminal'] = {
			List = {
				{Name = 'Default', Image = 'rbxassetid://7256574955'}
			},

			Description = "Some people deserved to be punished, I'm afraid.",
			Image = 'rbxassetid://7256931614',
			Color = Color3.fromRGB(144,238,144),
			DisplayOrder = 999,
			
			Payless = true,
			NoSelect = true,
			Locked = true
		},
		
		['Influence'] = {
			List = {
				{Name = 'Youtuber', Image = 'rbxassetid://7256570950'},
				{Name = 'TikToker', Image = 'rbxassetid://7256571369'},
				{Name = 'Streamer', Image = 'rbxassetid://7256572301'}
			},

			Description = "You've got a bright smile and a brrrrilliant personality.",
			Image = 'rbxassetid://7256930562',
			Color = Color3.fromRGB(32,178,170),
			DisplayOrder = 3,
		},
		
		['Aerospace'] = {
			List = {
				{Name = 'Astronaut', Image = 'rbxassetid://7256565753'},
				{Name = 'Technician', Image = 'rbxassetid://7256571568'},
				{Name = 'Researcher', Image = 'rbxassetid://7256573069'}
			},

			Description = "Fly to space, my beautiful child (and remember to come back).",
			Image = 'rbxassetid://7256931871',
			Color = Color3.fromRGB(147,112,219),
			DisplayOrder = 4,
		},
		
		['Health'] = {
			List = {
				{Name = 'Doctor', Image = 'rbxassetid://7256575696'},
				{Name = 'Surgeon', Image = 'rbxassetid://7256572027'},
				{Name = 'Assistant', Image = 'rbxassetid://7256574231'}
			},

			Description = "'He's supposed to be breathing!'",
			Image = 'rbxassetid://7256930910',
			Color = Color3.fromRGB(210, 43, 119),
		},
		
		['Education'] = {
			List = {
				{Name = 'Teacher', Image = 'rbxassetid://7256571735'},
				{Name = 'Custodian', Image = 'rbxassetid://7256576217'},
				{Name = 'Principal', Image = 'rbxassetid://7256574001'}
			},

			Description = "YOU CAN'T FAIL ALL THE STUDENTS!",
			Image = 'rbxassetid://7256931515',
			Color = Color3.fromRGB(176,196,222),
		},
		
		['Safety'] = {
			List = {
				{Name = 'Police', Image = 'rbxassetid://7256574106'},
				{Name = 'SWAT', Image = 'rbxassetid://7256571889'},
				{Name = 'Sheriff', Image = 'rbxassetid://7256572433'}
			},

			Description = "Are you gonna let those kids call you pigs???",
			Image = 'rbxassetid://7256929310',
			Color = Color3.fromRGB(45, 139, 218),
		},
		
		['Art'] = {
			List = {
				{Name = 'Dancer', Image = 'rbxassetid://7259882335'},
				{Name = 'Singer', Image = 'rbxassetid://7256929189'},
				{Name = 'Actor', Image = 'rbxassetid://7254798034'}
				-- Rapper
			},

			Description = "Ohhhh, you sure are an artsy little bunch, aren't you?",
			Image = 'rbxassetid://7256931744',
			Color = Color3.fromRGB(185, 136, 219),
			DisplayOrder = 2,
		},
		
		['1st Response'] = {
			List = {
				{Name = 'Firefighter', Image = 'rbxassetid://7256575318'},
				{Name = 'Lieutenant', Image = 'rbxassetid://7256575589'},
			},

			Description = "Run very very fast, my friend. Keep that dirt out your socks.",
			Image = 'rbxassetid://7256931980',
			Color = Color3.fromRGB(215, 123, 11),
		},
		
		['Zoology'] = {
			List = {
				{Name = 'Zookeeper', Image = 'rbxassetid://7256570738'},
				{Name = 'Trainer', Image = 'rbxassetid://7256571182'},
				{Name = 'Lion Tamer', Image = 'rbxassetid://7256574678'},

			},

			Description = "You really must like those furry creatures, huh?",
			Image = 'rbxassetid://7256928808',
			Color = Color3.fromRGB(51, 223, 137),
			DisplayOrder = 5,
		},
		
		['Food'] = {
			List = {
				{Name = 'Chef', Image = 'rbxassetid://7256576400'},
				{Name = 'Server', Image = 'rbxassetid://7256572645'},
				{Name = 'Host', Image = 'rbxassetid://7256575065'},

			},

			Description = "Nom, nom, leathery... wait is that hair?",
			Image = 'rbxassetid://7256931387',
			Color = Color3.fromRGB(194, 247, 132),
		},
		
		['Law'] = {
			List = {
				{Name = 'Lawyer', Image = 'rbxassetid://7256997625'},
				{Name = 'Paralegal', Image = 'rbxassetid://7256929870'},
				{Name = 'Judge', Image = 'rbxassetid://7256930413'},

			},

			Description = "You were trying wayyyyy too hard in school. Relax.",
			Image = 'rbxassetid://7256930168',
			Color = Color3.fromRGB(54, 139, 133),
		},
		
		['Glamour'] = {
			List = {
				{Name = 'Makeup', Image = 'rbxassetid://7256574419'},
				{Name = 'Diva', Image = 'rbxassetid://7256576017'},
				{Name = 'Stylist', Image = 'rbxassetid://7256572147'},

			},

			Description = "Make me look stylish, queeeen.",
			Image = 'rbxassetid://7256931248',
			Color = Color3.fromRGB(115, 0, 229),
			DisplayOrder = 6,
		},
		
		['Home'] = {
			List = {
				{Name = 'Maid', Image = 'rbxassetid://7256574531'},
				{Name = 'Butler', Image = 'rbxassetid://7256576516'},
				{Name = 'Babysitter', Image = 'rbxassetid://7256576605'},

			},

			Description = "I made a little spill, right th- yeah, right there.",
			Image = 'rbxassetid://7256930751',
			Color = Color3.fromRGB(15, 128, 203),
		},
		
		['Petcare'] = {
			List = {
				{Name = 'Pet Trainer', Image = 'rbxassetid://7256571182'},
				{Name = 'Groomer', Image = 'rbxassetid://7256931065'},
				{Name = 'Pet Sitter', Image = 'rbxassetid://7256929590'},

			},

			Description = "Take care of the animals, my friend, or they'll take care of you >:)",
			Image = 'rbxassetid://7256929467',
			Color = Color3.fromRGB(188, 219, 198),
		},
		
		['Label'] = {
			List = {
				{Name = 'DJ', Image = 'rbxassetid://7259917295'},
				{Name = 'Mixer', Image = 'rbxassetid://7256574345'},
				{Name = 'Producer', Image = 'rbxassetid://7256573845'},

			},

			Description = "Uh, what-cha, what-cha, what-cha, wow.",
			Image = 'rbxassetid://7256930290',
			Color = Color3.fromRGB(226, 189, 129),
		},
	},
	
	-- These amounts / stealing amount need to be enhanced (not so much that it allows people
	-- to go AFK farming, but no so little that it's intolerable)
	Payment = {
		-- How frequently you get paid (between min/max)
		Frequency = {
			Minimum = 60 * 8,
			Maximum = 60 * 10,
		},
		
		Amount = 200 -- Up to change
	},
	
	-- Stealing should be an equally viable source of income as standard payment
	Stealing = {
		CaughtChance = 35, -- Chances of getting caught (out of 100) this number must be whole w/ no decimals
		
		LockedTime = 60 * 3, -- How long you're 'locked' from getting another job for each time caught
		MaxLockedTime = 60 * 45, -- Maximum amount of time you can be 'locked' for
		
		Amount = {
			Minimum = 10,
			Maximum = 15
		},
		
		PlayerCooldown = 5, -- In preventing teleporting exploits, how long they need to wait before stealing again
		Cooldown = 180 -- How long before they can steal from one safe again | Not sure about this number, do the math
	},
	
	Default = 'Unemployed',
	Criminal = 'Criminal',
	
	DefaultDisplayOrder = 10 -- The display order that jobs non-assigned with will have
}

return Jobs
