require("/scripts/util.lua")
require("/interface/wr/automation/labels.lua")

local rarityMap = {}
local currentRecipes = {}
local recipeOutputCache = {}
local recipePage = 0
local recipesPerPage = 50
local searchedRecipes = {}
local recipePages = 1
local inputNodesConfig
local outputNodesConfig

function uninit()
end

local filter
local requiresBlueprint = true
local uniqueRecipes = {}
local itemRecipes = {}
local stationRecipes = {}
local allRecipes = {}
local recipeRPC
local loadingCoroutine
local searchCoroutine

local currentlySorting
local currentlySearching
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
	if loadingCoroutine and coroutine.status(loadingCoroutine) == "suspended" then
		local success, error = coroutine.resume(loadingCoroutine, 2000)
		if not success then
			local itemPrintout = sb.printJson(currentlySorting, 2)
			sb.logError("[wr_automation] Error while loading recipes.\n%s\n%s", itemPrintout, error)
			_ENV.recipeSearchScrollArea:clearChildren()
			_ENV.recipeSearchScrollArea:addChild({
				type = "label", text = "Error While Loading Recipes", align = "center", color = "FF0000"
			})
			_ENV.recipeSearchScrollArea:addChild({
				type = "label", text = itemPrintout, color = "FF7F00"
			})
			_ENV.recipeSearchScrollArea:addChild({
				type = "label", text = error:gsub("\t","  "), color = "FFFF00"
			})
		end
	elseif searchCoroutine and coroutine.status(searchCoroutine) == "suspended" then
		local success, error = coroutine.resume(searchCoroutine, 2000)
		if not success then
			local itemPrintout = sb.printJson(currentlySearching, 2)
			sb.logError("[wr_automation] Error while searching recipes.\n%s\n%s", itemPrintout, error)
			_ENV.recipeSearchScrollArea:clearChildren()
			_ENV.recipeSearchScrollArea:addChild({
				type = "label", text = "Error While Searching Recipes.", align = "center", color = "FF0000"
			})
			_ENV.recipeSearchScrollArea:addChild({
				type = "label", text = itemPrintout, color = "FF7F00"
			})
			_ENV.recipeSearchScrollArea:addChild({
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
	_ENV.recipeSearchScrollArea:clearChildren()
	_ENV.recipeSearchScrollArea:addChild({
		type = "label", text = "Loading Recipes...", align = "center"
	})
	filter = world.getObjectParameter(pane.sourceEntity(), "filter")

	itemRecipes = {}
	if root.allRecipes~= nil then
		allRecipes = root.allRecipes(filter)
	end
	loadingCoroutine = coroutine.create(loadRecipes)
end
function loadRecipes(amount)
	currentRecipes = {}
	local function compareRecipes(a, a_cache, b, b_cache)
		if a_cache.rarity == b_cache.rarity then
			return a_cache.name < b_cache.name
		else
			return a_cache.rarity > b_cache.rarity
		end
	end
	local function insertRecipe(recipe)
		currentlySorting = recipe
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		local cache = {}
		if recipe.output[1] then
			if recipe.recipeBlueprint and requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(recipe.recipeBlueprint)) then return end
			cache.output = {}
			cache.rarity = 0
			if sb.stripEscapeCodes ~= nil then
				cache.name = sb.stripEscapeCodes(recipe.recipeName)
			else
				cache.name = recipe.recipeName:gsub("%b^;")
			end
			for i, product in ipairs(recipe.output) do
				if (not recipe.recipeBlueprint) and requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(product)) then return end
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
			if requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(recipe.output)) then return end
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
			for _, product in ipairs(recipe.output) do
				if not root.itemConfig(product) then return end
			end
			insertRecipe(recipe)
		elseif root.itemConfig(recipe.output) then
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
	searchCoroutine = coroutine.create(searchRecipes)
	return true
end
function searchRecipes(amount)
	_ENV.recipeSearchScrollArea:clearChildren()
	_ENV.recipeSearchScrollArea:addChild({
		type = "label", text = "Searching Recipes...", align = "center"
	})
	local searchText = _ENV.searchBox.text:lower()
	local function isRecipeSearched(i, recipe)
		currentlySearching = recipe
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
	recipePages = math.ceil(#searchedRecipes / recipesPerPage)
	coroutine.yield()
	refreshDisplayedRecipes()
	return true
end
function refreshDisplayedRecipes()
	_ENV.recipeSearchScrollArea:clearChildren()
	if #currentRecipes == 0 then
		_ENV.recipeSearchScrollArea:addChild({
			type = "label",
			text = ("No recipes found.")
		})
	elseif #searchedRecipes == 0 then
		_ENV.recipeSearchScrollArea:addChild({
			type = "label",
			text = ("No search results.")
		})
	end
	if #searchedRecipes > recipesPerPage then
		_ENV.recipeSearchScrollArea:addChild({
			type = "panel",
			style = "flat",
			children = {
				{ mode = "h" },
				{ type = "button", caption = "<-", id = "recipePageBackTopButton"},
				{ type = "label", text = ("%d of %d"):format(recipePage+1, recipePages), align = "center"},
				{ type = "button", caption = "->", id = "recipePageNextTopButton"}
			}
		})
		function _ENV.recipePageBackTopButton:onClick()
			recipePage = (recipePage - 1) % recipePages
			refreshDisplayedRecipes()
		end
		function _ENV.recipePageNextTopButton:onClick()
			recipePage = (recipePage + 1) % recipePages
			refreshDisplayedRecipes()
		end
	end
	for i = 1, recipesPerPage do
		local recipe = searchedRecipes[i + recipePage * recipesPerPage]
		if recipe then
			local ingredientSlots = {
				{mode = "h", scissoring = false, expandMode = {1,0}}
			}
			for _, input in ipairs(recipe.input) do
				table.insert(ingredientSlots, {
					type = "itemSlot",
					item = input
				})
			end
			local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
			local duration = math.max(
				0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
				(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
				(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
			) / craftingSpeed
			local divisor, timeLabel = durationLabel(duration)
			local outputLayout
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
				outputLayout = {
					{ mode = "v", expandMode = { 1, 0 } },
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
				}
			else
				local itemConfig = root.itemConfig(recipe.output)
				local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
				outputLayout = {
					{ mode = "h", scissoring = false },
					{ type = "itemSlot", item = recipe.output },
					{
						{ type = "label", text = merged.shortdescription},
						{
							{ type = "label", text = clipAtThousandth(duration/divisor), inline = true },
							{ type = "label", text = timeLabel,               inline = true }
						},

					},
				}
			end
			local listItem = _ENV.recipeSearchScrollArea:addChild({
				type = "listItem",
				selectionGroup = "recipeSelect",
				value = recipe,
				expandMode = {1,0},
				children = {
					{
						type = "panel",
						style = "convex",
						children = {
							{ mode = "v", expandMode = {1,0} },
							outputLayout,
							{
								type = "panel",
								style = "flat",
								children = {
									{ mode = "v", expandMode = {1,0}, scissoring = false },
									{ type = "label", text = "Ingredients"},
									ingredientSlots
								},
							}
						}
					}
				}
			})
			function listItem:onClick()
				recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
			end
		else
			break
		end
	end
	if #searchedRecipes > recipesPerPage then
		_ENV.recipeSearchScrollArea:addChild({
			type = "panel",
			style = "flat",
			children = {
				{ mode = "h" },
				{ type = "button", caption = "<-", id = "recipePageBackBottomButton"},
				{ type = "label", text = ("%d of %d"):format(recipePage+1, recipePages), align = "center"},
				{ type = "button", caption = "->", id = "recipePageNextBottomButton"}
			}
		})
		function _ENV.recipePageBackBottomButton:onClick()
			recipePage = (recipePage - 1) % recipePages
			refreshDisplayedRecipes()
		end
		function _ENV.recipePageNextBottomButton:onClick()
			recipePage = (recipePage + 1) % recipePages
			refreshDisplayedRecipes()
		end
	end
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
	searchCoroutine = coroutine.create(searchRecipes)
end
