---@diagnostic disable: undefined-global

wr_assemblerRecipes["wr/logistics_station"] = function(craftingStation, addon)
	local itemConfig = root.itemConfig(craftingStation)
	local didPath = {}
	local uniqueRecipes = {}
	local function getUniqueRecipes(maybeRecipe)
		if not maybeRecipe then return end
		local maybeRecipeType = type(maybeRecipe)
		if maybeRecipeType == "string" then
			if not didPath[maybeRecipe] then
				didPath[maybeRecipe] = true
				getUniqueRecipes(root.assetJson(maybeRecipe))
			end
		elseif maybeRecipeType == "table" then
			if maybeRecipe[1] then
				for _, v in ipairs(maybeRecipe) do
					getUniqueRecipes(v)
				end
			else
				table.insert(uniqueRecipes, maybeRecipe)
			end
		end
	end
	getUniqueRecipes(itemConfig.config.recipes)
	return itemConfig.config.filter, uniqueRecipes, true, itemConfig.config.recipeTabs
end
