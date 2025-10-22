local definitions = {
	{
		id = "appleTycoon",
		titleKey = "achievements_definitions.appleTycoon.title",
		descriptionKey = "achievements_definitions.appleTycoon.description",
		icon = "fruit1000",
		goal = 1000,
		stat = "totalApplesEaten",
		category = "progress",
		categoryOrder = 1,
		order = 40,
	},
	{
		id = "dailyFunDabbler",
		titleKey = "achievements_definitions.dailyFunDabbler.title",
		descriptionKey = "achievements_definitions.dailyFunDabbler.description",
		icon = "Default",
		goal = 1,
		stat = "dailyChallengesCompleted",
		category = "progress",
		categoryOrder = 1,
		order = 140,
	},
	{
		id = "dailyFunChampion",
		titleKey = "achievements_definitions.dailyFunChampion.title",
		descriptionKey = "achievements_definitions.dailyFunChampion.description",
		icon = "Default",
		goal = 30,
		stat = "dailyChallengesCompleted",
		category = "progress",
		categoryOrder = 1,
		order = 160,
	},
	{
		id = "comboSpark",
		titleKey = "achievements_definitions.comboSpark.title",
		descriptionKey = "achievements_definitions.comboSpark.description",
		icon = "Apple",
		goal = 3,
		stat = "bestComboStreak",
		category = "skill",
		categoryOrder = 2,
		order = 12,
	},
	{
		id = "comboSurge",
		titleKey = "achievements_definitions.comboSurge.title",
		descriptionKey = "achievements_definitions.comboSurge.description",
		icon = "Apple",
		goal = 6,
		stat = "bestComboStreak",
		category = "skill",
		categoryOrder = 2,
		order = 14,
	},
	{
		id = "comboInferno",
		titleKey = "achievements_definitions.comboInferno.title",
		descriptionKey = "achievements_definitions.comboInferno.description",
		icon = "Apple",
		goal = 10,
		stat = "bestComboStreak",
		category = "skill",
		categoryOrder = 2,
		order = 16,
	},
	{
		id = "shieldlessWonder",
		titleKey = "achievements_definitions.shieldlessWonder.title",
		descriptionKey = "achievements_definitions.shieldlessWonder.description",
		icon = "Apple",
		goal = 1,
		category = "skill",
		categoryOrder = 2,
		order = 19,
		hidden = true,
		progressFn = function(state)
			if (state.runFloorsCleared or 0) >= 3 and (state.runShieldsSaved or 0) == 0 then
				return 1
			end
			return 0
		end,
		condition = function(state)
			return (state.runFloorsCleared or 0) >= 3 and (state.runShieldsSaved or 0) == 0
		end,
	},
	{
		id = "dragonComboFusion",
		titleKey = "achievements_definitions.dragonComboFusion.title",
		descriptionKey = "achievements_definitions.dragonComboFusion.description",
		icon = "Apple",
		goal = 1,
		category = "skill",
		categoryOrder = 2,
		order = 55,
		hidden = true,
		progressFn = function(state)
			if (state.runDragonfruitEaten or 0) > 0 and (state.runBestComboStreak or 0) >= 8 then
				return 1
			end
			return 0
		end,
		condition = function(state)
			return (state.runDragonfruitEaten or 0) > 0 and (state.runBestComboStreak or 0) >= 8
		end,
	},
	{
		id = "wallRicochet",
		titleKey = "achievements_definitions.wallRicochet.title",
		descriptionKey = "achievements_definitions.wallRicochet.description",
		icon = "Apple",
		goal = 1,
		stat = "shieldWallBounces",
		category = "skill",
		categoryOrder = 2,
		order = 60,
	},
	{
		id = "rockShatter",
		titleKey = "achievements_definitions.rockShatter.title",
		descriptionKey = "achievements_definitions.rockShatter.description",
		icon = "Apple",
		goal = 1,
		stat = "shieldRockBreaks",
		category = "skill",
		categoryOrder = 2,
		order = 70,
	},
	{
		id = "rockCrusher",
		titleKey = "achievements_definitions.rockCrusher.title",
		descriptionKey = "achievements_definitions.rockCrusher.description",
		icon = "Apple",
		goal = 25,
		stat = "shieldRockBreaks",
		category = "skill",
		categoryOrder = 2,
		order = 75,
	},
	{
		id = "sawParry",
		titleKey = "achievements_definitions.sawParry.title",
		descriptionKey = "achievements_definitions.sawParry.description",
		icon = "Apple",
		goal = 1,
		stat = "shieldSawParries",
		category = "skill",
		categoryOrder = 2,
		order = 80,
	},
	{
		id = "sawAnnihilator",
		titleKey = "achievements_definitions.sawAnnihilator.title",
		descriptionKey = "achievements_definitions.sawAnnihilator.description",
		icon = "Apple",
		goal = 25,
		stat = "shieldSawParries",
		category = "skill",
		categoryOrder = 2,
		order = 82,
	},
	{
		id = "shieldTriad",
		titleKey = "achievements_definitions.shieldTriad.title",
		descriptionKey = "achievements_definitions.shieldTriad.description",
		icon = "Apple",
		goal = 3,
		category = "skill",
		categoryOrder = 2,
		order = 85,
		progressFn = function(state)
			local count = 0
			local keys = {
				"runShieldWallBounces",
				"runShieldRockBreaks",
				"runShieldSawParries",
			}

			for _, key in ipairs(keys) do
				if (state[key] or 0) > 0 then
					count = count + 1
				end
			end

			return count
		end,
		condition = function(state)
			local progress = 0
			local keys = {
				"runShieldWallBounces",
				"runShieldRockBreaks",
				"runShieldSawParries",
			}

			for _, key in ipairs(keys) do
				if (state[key] or 0) > 0 then
					progress = progress + 1
				end
			end

			return progress >= 3
		end,
	},
	{
		id = "dragonHunter",
		titleKey = "achievements_definitions.dragonHunter.title",
		descriptionKey = "achievements_definitions.dragonHunter.description",
		icon = "Apple",
		goal = 1,
		stat = "totalDragonfruitEaten",
		category = "collection",
		categoryOrder = 3,
		order = 10,
	},
	{
		id = "dragonConnoisseur",
		titleKey = "achievements_definitions.dragonConnoisseur.title",
		descriptionKey = "achievements_definitions.dragonConnoisseur.description",
		icon = "Apple",
		goal = 10,
		stat = "totalDragonfruitEaten",
		category = "collection",
		categoryOrder = 3,
		order = 20,
	},
}

return definitions
