require("/scripts/util.lua")
require("/interface/wr/automation/labels.lua")

local rarityMap = {}
local currentRecipes = {}
local recipeOutputCache = {}
local recipesPerPage = 50
local searchedRecipes = {}

function uninit()
end

local filter
local requiresBlueprint = true
local uniqueRecipes = {}
local stationRecipes = {}
local allRecipes = {}
local recipeRPC
local activeCoroutine
local recipeTabs

local currentRecipe
local raritySort = true
function init()
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")

	rarityMap = root.assetJson("/interface/wr/automation/rarity.config")

	local didPath = {}
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
	getUniqueRecipes(world.getObjectParameter(pane.sourceEntity(), "recipes"))
	refreshCurrentRecipes()
	displayRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))
end
function update()
	if activeCoroutine and coroutine.status(activeCoroutine) == "suspended" then
		local success, error = coroutine.resume(activeCoroutine, 2000)
		if not success then
			local itemPrintout = sb.printJson(currentRecipe, 2)
			sb.logError("[wr_automation] %s\n%s\n%s", errorMessage, itemPrintout, error)
			_ENV.recipeListLayout:clearChildren()
			_ENV.recipeListLayout:addChild({
				type = "label", text = errorMessage, align = "center", color = "FF0000"
			})
			_ENV.recipeListLayout:addChild({
				type = "label", text = itemPrintout, color = "FF7F00"
			})
			_ENV.recipeListLayout:addChild({
				type = "label", text = error:gsub("\t","  "), color = "FFFF00"
			})
		end
	end
	if recipeRPC and recipeRPC:finished() then
		recipeRPC = nil
		displayRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))
	end
end

function refreshCurrentRecipes()
	_ENV.recipeListLayout:clearChildren()
	_ENV.recipeListLayout:addChild({
		type = "label", text = "Loading Recipes...", align = "center"
	})
	filter = world.getObjectParameter(pane.sourceEntity(), "filter")
	recipeTabs = world.getObjectParameter(pane.sourceEntity(), "recipeTabs")

	itemRecipes = {}
	if root.allRecipes ~= nil then
		allRecipes = root.allRecipes(filter)
	end
	activeCoroutine = coroutine.create(loadRecipes)
end

function compareRecipes(a, a_cache, b, b_cache)
	if (not raritySort) or a_cache.rarity == b_cache.rarity then
		return a_cache.name < b_cache.name
	else
		return a_cache.rarity > b_cache.rarity
	end
end

function loadRecipes(amount)
	errorMessage = "Error while loading recipes."
	currentRecipes = {}

	local function insertRecipe(recipe)
		currentRecipe = recipe
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		local cache = {}
		if recipe.output[1] then
			cache.output = {}
			cache.rarity = 0
			if sb.stripEscapeCodes ~= nil then
				cache.name = sb.stripEscapeCodes(recipe.recipeName)
			else
				cache.name = recipe.recipeName:gsub("%b^;")
			end
			for i, product in ipairs(recipe.output) do
				cache.output[i] = {}
				cache.output[i].itemConfig = root.itemConfig(product)
				cache.output[i].mergedConfig = sb.jsonMerge(cache.output[i].itemConfig.config, cache.output[i].itemConfig.parameters)
				if sb.stripEscapeCodes ~= nil then
					cache.output[i].name = sb.stripEscapeCodes(cache.output[i].mergedConfig.shortdescription)
				else
					cache.output[i].name = cache.output[i].mergedConfig.shortdescription:gsub("%b^;")
				end
				cache.output[i].rarity = rarityMap[(cache.output[i].mergedConfig.rarity or "common"):lower()] or 0

				sb.logInfo("%s, %s", cache.output[i].mergedConfig.rarity, sb.printJson(cache.output[i].mergedConfig))
				cache.rarity = cache.rarity + cache.output[i].rarity
			end
		else
			cache.itemConfig = root.itemConfig(recipe.output)
			cache.mergedConfig = sb.jsonMerge(cache.itemConfig.config, cache.itemConfig.parameters)
			if sb.stripEscapeCodes ~= nil then
				cache.name = sb.stripEscapeCodes(cache.mergedConfig.shortdescription)
			else
				cache.name = cache.mergedConfig.shortdescription:gsub("%b^;")
			end
			cache.rarity = rarityMap[(cache.mergedConfig.rarity or "common"):lower()] or 0
		end
		local upperBounds = #currentRecipes + 1
		local lowerBounds = 1
		while true do
			if (upperBounds == lowerBounds) then
				table.insert(currentRecipes, upperBounds, recipe)
				table.insert(recipeOutputCache, upperBounds, cache)
				return
			end
			local index = math.floor((upperBounds - lowerBounds) / 2) + lowerBounds
			local b = currentRecipes[index]
			local b_cache = recipeOutputCache[index]
			if compareRecipes(recipe, cache, b, b_cache) then
				upperBounds = index
			else
				lowerBounds = index + 1
			end
			amount = amount - 1
			if amount == 0 then coroutine.yield() end
		end
	end

	local function validateRecipe(recipe)
		for _, input in ipairs(recipe.input) do
			if not root.itemConfig(input) then return end
		end
		if recipe.output[1] then -- this is the only case where we have multiple
			if recipe.recipeBlueprint and requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(recipe.recipeBlueprint)) then return end
			for _, product in ipairs(recipe.output) do
				if not root.itemConfig(product) then return end
				if (not recipe.recipeBlueprint) and requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(product)) then return end
			end
			insertRecipe(recipe)
		elseif root.itemConfig(recipe.output) then
			if requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(recipe.output)) then return end
			insertRecipe(recipe)
		end
	end
	for _, recipe in ipairs(uniqueRecipes) do
		validateRecipe(recipe)
	end
	for _, recipe in ipairs(stationRecipes) do
		validateRecipe(recipe)
	end
	for _, recipe in ipairs(allRecipes) do
		validateRecipe(recipe)
	end
	currentRecipe = nil
	activeCoroutine = coroutine.create(searchRecipes)
	return true
end
function sortRecipes(amount)
	errorMessage = "Error while sorting recipes."
	local oldRecipes = currentRecipes
	local oldOutputCache = recipeOutputCache
	currentRecipes = {}
	recipeOutputCache = {}
	local function insertRecipe(recipe, cache)
		currentRecipe = recipe
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		local upperBounds = #currentRecipes + 1
		local lowerBounds = 1
		while true do
			if (upperBounds == lowerBounds) then
				table.insert(currentRecipes, upperBounds, recipe)
				table.insert(recipeOutputCache, upperBounds, cache)
				return
			end
			local index = math.floor((upperBounds - lowerBounds) / 2) + lowerBounds
			local b = currentRecipes[index]
			local b_cache = recipeOutputCache[index]
			if compareRecipes(recipe, cache, b, b_cache) then
				upperBounds = index
			else
				lowerBounds = index + 1
			end
			amount = amount - 1
			if amount == 0 then coroutine.yield() end
		end
	end
	for i, v in ipairs(oldRecipes) do
		insertRecipe(v, oldOutputCache[i])
	end
	currentRecipe = nil
	activeCoroutine = coroutine.create(searchRecipes)
	return true
end
function searchRecipes(amount)
	errorMessage = "Error while searching recipes."
	_ENV.recipeListLayout:clearChildren()
	_ENV.recipeListLayout:addChild({
		type = "label", text = "Searching Recipes...", align = "center"
	})
	local searchText = _ENV.searchBox.text:lower()
	local function isRecipeSearched(i, recipe)
		currentRecipe = recipe
		local cache = recipeOutputCache[i]
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		if recipe.output[1] then
			if recipe.recipeName:lower():find(searchText) then
				return table.insert(searchedRecipes, recipe)
			end
			for j, item in ipairs(recipe.output) do
				local id = (item.item or item.name)
				local cache = cache[j]
				if id:lower():find(searchText) or cache.name:lower():find(searchText) then
					return table.insert(searchedRecipes, recipe)
				end
			end
		else
			local id = (recipe.output.item or recipe.output.name)
			if id:lower():find(searchText) or cache.name:lower():find(searchText) then
				return table.insert(searchedRecipes, recipe)
			end
		end
	end
	recipePage = 0
	if searchText == "" then
		searchedRecipes = currentRecipes
	else
		searchedRecipes = {}
		for i, recipe in ipairs(currentRecipes) do
			isRecipeSearched(i, recipe)
		end
	end
	currentRecipe = nil
	activeCoroutine = coroutine.create(refreshDisplayedRecipes)
	return true
end
function refreshDisplayedRecipes(amount)
	errorMessage = "Error while listing recipes."
	_ENV.recipeListLayout:clearChildren()
	if #currentRecipes == 0 then
		local craftingItem = _ENV.craftingItemSlot:item()
		if not craftingItem then
			_ENV.recipeListLayout:addChild({
				type = "label",
				text = "Insert an item to list its recipes."
			})
		else
			if _ENV.craftingStationSlot.visible then
				_ENV.recipeListLayout:addChild({
					type = "label",
					text = ("No recipes found.\nInsert a crafting station with a recipe for the desired item.")
				})
			else
				_ENV.recipeListLayout:addChild({
					type = "label",
					text = ("No recipes found.")
				})
			end
		end
		return true
	elseif #searchedRecipes == 0 then
		_ENV.recipeListLayout:addChild({
			type = "label",
			text = ("No search results.")
		})
		return true
	end
	local tabField = _ENV.recipeListLayout:addChild({
		type = "tabField",
		layout = "horizontal",
		tabs = {}
	})
	local rand = sb.makeRandomSource()
	local function listRecipe(layout, recipe)
		currentRecipe = recipe
		amount = amount - 1
		if amount == 0 then coroutine.yield() end

		local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
		local duration = math.max(
			0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
			(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
			(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
		) / craftingSpeed
		local divisor, timeLabel = durationLabel(duration)
		local outputLayout
		local productSlotsId = tostring(rand:randu32())
		if recipe.output[1] then

			local outputSlots = {
				{ mode = "h", scissoring = false, expandMode = { 1, 0 } }
			}
			outputLayout = {
				{ mode = "v",     expandMode = { 1, 0 } },
				{ type = "label", text = recipe.recipeName },
				{
					{ type = "label", text = clipAtThousandth(duration / divisor), inline = true },
					{ type = "label", text = timeLabel,                            inline = true }
				},
				{
					type = "panel",
					style = "flat",
					children = {
						{ mode = "v",     expandMode = { 1, 0 } },
						{ type = "label", text = "Products" },
						{ type = "itemGrid", id = productSlotsId, slots = 0, autoInteract = false}
					},
				}
			}
		else
			local itemConfig = root.itemConfig(recipe.output)
			local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
			outputLayout = {
				{ mode = "h",        scissoring = false },
				{ type = "itemSlot", item = recipe.output },
				{
					{ type = "label", text = merged.shortdescription },
					{
						{ type = "label", text = clipAtThousandth(duration / divisor), inline = true },
						{ type = "label", text = timeLabel,                            inline = true }
					},

				},
			}
		end
		local ingredientSlotsId = tostring(rand:randu32())
		local listItem = layout:addChild({
			type = "listItem",
			selectionGroup = "recipeSelect",
			value = recipe,
			expandMode = { 1, 0 },
			children = {
				{
					type = "panel",
					style = "convex",
					children = {
						{ mode = "v", expandMode = { 1, 0 } },
						outputLayout,
						{
							type = "panel",
							style = "flat",
							children = {
								{ mode = "v",     expandMode = { 1, 0 }, scissoring = false },
								{ type = "label", text = "Ingredients" },
								{ type = "itemGrid", id = ingredientSlotsId, slots = 0, autoInteract = false}
							},
						}
					}
				}
			}
		})
		for _, input in ipairs(recipe.input) do
			_ENV[ingredientSlotsId]:addSlot(input)
		end
		if recipe.output[1] then
			for _, input in ipairs(recipe.output) do
				_ENV[productSlotsId]:addSlot(input)
			end
		end

		function listItem:onClick()
			recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
		end
	end

	if recipeTabs then
		for _, tabData in ipairs(recipeTabs) do
			local hash = tostring(rand:randu32())
			local tab = tabField:newTab({
				id = tabData.id,
				title = tabData.title or "",
				icon = tabData.icon,
				contents = {
					{
						type = "panel",
						style = "concave",
						expandMode = { 2, 2 },
						children = {
							{
								type = "scrollArea",
								id = hash,
								expandMode = { 2, 2 },
								scrollDirectons = { 0, 1 },
								children = {}
							}
						},
					}
				}
			})
			local tabScrollArea = _ENV[hash]
			for _, recipe in ipairs(currentRecipes) do
				for _, v in ipairs(tabData.filter) do
					for _, group in ipairs(recipe.groups) do
						if group == v then
							listRecipe(tabScrollArea, recipe)
							break
						end
					end
				end
			end
		end
	else
		for j = 1, math.ceil(#currentRecipes / recipesPerPage) do
			local hash = tostring(rand:randu32())
			local tab = tabField:newTab({
				id = tostring(j),
				title = ("  %d  "):format(j),
				contents = {
					{
						type = "panel",
						style = "concave",
						expandMode = { 2, 2 },
						children = {
							{
								type = "scrollArea",
								id = hash,
								expandMode = { 2, 2 },
								scrollDirectons = { 0, 1 },
								children = {}
							}
						},
					}
				}
			})
			local tabScrollArea = _ENV[hash]

			for i = 1, recipesPerPage do
				local recipe = searchedRecipes[i + ((j - 1) * recipesPerPage)]
				if recipe then
					listRecipe(tabScrollArea, recipe)
				else
					break
				end
			end
		end
	end
	currentRecipe = nil
	return true
end

function displayRecipe(recipe)
	if not recipe then return end


	local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
	local duration = math.max(
		0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
		(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	) / craftingSpeed


	_ENV.outputPanel:clearChildren()
	if recipe.output[1] then
		local outputSlots = {
			{mode = "h", scissoring = false, expandMode = {1,0}}
		}
		for _, output in ipairs(recipe.output) do
			table.insert(outputSlots, {
				type = "itemSlot",
				item = output
			})
		end
		local divisor, timeLabel = durationLabel(duration)

		_ENV.outputPanel:addChild({ type = "layout", mode = "v", expandMode = { 1, 0 }, children = {
			{ type = "label", text = recipe.recipeName },
			{
				{ type = "label", text = clipAtThousandth(duration/divisor), inline = true },
				{ type = "label", text = timeLabel,               inline = true }
			},
			{
				type = "panel",
				style = "flat",
				children = {
					{ mode = "v", expandMode = {1,0} },
					{ type = "label", text = "Products"},
					outputSlots
				},
			}
		}})

	else
		local itemConfig = root.itemConfig(recipe.output)
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)

		local divisor, timeLabel = durationLabel(duration)
		_ENV.outputPanel:addChild({
			type = "layout",
			mode = "h",
			scissoring = false,
			children = {
				{type= "itemSlot", autoInteract= false, glyph= "output.png", item = recipe.output},
				{
					{type= "label", text= merged.shortdescription},
					{
						{ type = "label", text = clipAtThousandth(duration/divisor), inline = true },
						{ type = "label", text = timeLabel,               inline = true }
					}
				}
			},
		})
	end
end

function _ENV.searchBox:onTextChanged()
	activeCoroutine = coroutine.create(searchRecipes)
end
