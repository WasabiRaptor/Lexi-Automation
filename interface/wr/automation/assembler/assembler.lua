require("/scripts/util.lua")
require("/interface/wr/automation/labels.lua")
require("/interface/wr/automation/displayRecipe.lua")

local rarityMap = {}
local currentRecipes = {}
local recipeOutputCache = {}
local recipesPerPage = 50
local searchedRecipes = {}

wr_assemblerRecipes = {} -- for scripted crafting stations to have scripts to tell the assembler what recipes it has
require("/interface/wr/automation/assembler/assemblerRecipes.lua")

function uninit()
	local craftingItem = _ENV.craftingItemSlot:item()
	local craftingStation = _ENV.craftingStationSlot:item()
	local craftingAddon = _ENV.craftingAddonSlot:item()
	if craftingItem then player.giveItem(craftingItem) end
	if craftingStation then player.giveItem(craftingStation) end
	if craftingAddon then player.giveItem(craftingAddon) end
end

local filter
local requiresBlueprint = true
local uniqueRecipes = {}
local itemRecipes = {}
local stationRecipes = {}
local allRecipes = {}
local recipeRPC
local recipeTabs

local activeCoroutine
local currentRecipe
local errorMessage = "Error during initialization"

local raritySort = true
function init()
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1

	rarityMap = root.assetJson("/interface/wr/automation/rarity.config")

	if world.getObjectParameter(pane.sourceEntity(), "lockRecipes") then
		_ENV.craftingStationSlot:setVisible(false)
		_ENV.craftingAddonSlot:setVisible(false)
	end
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

local function errorPrintout(error)
	sb.logError("[wr_automation] %s\n%s\n%s", errorMessage, sb.printJson(currentRecipe, 2), error)
end

function update()
	if activeCoroutine and coroutine.status(activeCoroutine) == "suspended" then
		local success, error = coroutine.resume(activeCoroutine, 2000)
		if not success then
			errorPrintout(error)
			_ENV.recipeListLayout:clearChildren()
			_ENV.recipeListLayout:addChild({
				type = "scrollArea",
				expandMode = { 2, 2 },
				scrollDirectons = { 0, 1 },
				children = {
					{
						type = "label", text = errorMessage, align = "center", color = "FF0000"
					},{
						type = "label", text = sb.printJson(currentRecipe, 2), color = "FF7F00"
					},{
						type = "label", text = error:gsub("\t", "  "), color = "FFFF00"
					}
				}
			})
		end
	end
	if recipeRPC and recipeRPC:finished() then
		recipeRPC = nil
		displayRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))
	end
end

function refreshCurrentRecipes()
	_ENV.craftingAddonSlot:setVisible(_ENV.craftingAddonSlot:item() ~= nil)
	_ENV.recipeListLayout:clearChildren()
	_ENV.recipeListLayout:addChild({
		type = "label", text = "Loading Recipes...", align = "center"
	})

	local craftingItem = _ENV.craftingItemSlot:item()

	getCraftingStationRecipes()

	if craftingItem then
		itemRecipes = root.recipesForItem(craftingItem.name or craftingItem.item)
		allRecipes = {}
	elseif filter and (root.allRecipes ~= nil) then
		itemRecipes = {}
		allRecipes = root.allRecipes(filter)
	else
		itemRecipes = {}
		allRecipes = {}
	end
	activeCoroutine = coroutine.create(loadRecipes)
	return true
end

function getCraftingStationRecipes()
	local craftingStation = _ENV.craftingStationSlot:item()
	if not craftingStation then
		filter = world.getObjectParameter(pane.sourceEntity(), "filter")
		recipeTabs = world.getObjectParameter(pane.sourceEntity(), "recipeTabs")
		requiresBlueprint = true
		return
	end
	local itemConfig = root.itemConfig(craftingStation)
	local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)

	local interactData
	local craftingAddon = _ENV.craftingAddonSlot:item()
	local craftingAddonConfig
	local craftingAddonMerged
	if craftingAddon then
		craftingAddonConfig = root.itemConfig(craftingAddon)
		craftingAddonMerged = sb.jsonMerge(craftingAddonConfig.config, craftingAddonConfig.parameters)
	end
	local function doAddons(usesAddons)
		_ENV.craftingAddonSlot:setVisible(true)
		if craftingAddon then
			for _, addon in ipairs((craftingAddonMerged.addonConfig or {}).isAddons or {}) do
				for _, addonConfig in ipairs(usesAddons) do
					if addon.name == addonConfig.name then
						interactData = sb.jsonMerge(interactData, addonConfig.addonData.interactData)
					end
				end
			end
		end
	end
	for _, v in ipairs(merged.wr_assemblerRecipeScripts or {}) do
		require(v)
	end
	if type(wr_assemblerRecipes[(craftingStation.item or craftingStation.name)]) == "function" then
		filter, stationRecipes, requiresBlueprint, recipeTabs = wr_assemblerRecipes
			[(craftingStation.item or craftingStation.name)](craftingStation, craftingAddon)
		return
	elseif merged.recipeGroup and (merged.objectType == "container") then -- for refinery type objects
		filter = { merged.recipeGroup }
		recipeTabs = nil
		requiresBlueprint = false
		return
	elseif merged.interactAction == "OpenCraftingInterface" then
		interactData = merged.interactData
	end
	if merged.upgradeStages then
		local upgradeData = merged.upgradeStages
			[(merged.scriptStorage or {}).currentStage or merged.startingUpgradeStage]
		interactData = sb.jsonMerge(interactData, upgradeData.interactData)
		if upgradeData.addonConfig and upgradeData.addonConfig.usesAddons then
			doAddons(upgradeData.addonConfig.usesAddons)
		end
	elseif merged.addonConfig and merged.addonConfig.usesAddons then
		_ENV.craftingAddonSlot:setVisible(true)
		doAddons(merged.addonConfig.usesAddons)
	end

	if interactData then
		if interactData.config then
			interactData = sb.jsonMerge(root.assetJson(interactData.config), interactData)
		end
		filter = interactData.filter
		if interactData.recipes then
			stationRecipes = interactData.recipes
		end
		if interactData.requiresBlueprint ~= nil then
			requiresBlueprint = interactData.requiresBlueprint
		else
			requiresBlueprint = true
		end
	end
end

function compareRecipes(a, a_cache, b, b_cache)
	if (not raritySort) or a_cache.rarity == b_cache.rarity then
		if a_cache.name == b_cache.name then
			if a_cache.count == b_cache.count then
				if a_cache.inputRarity == b_cache.inputRarity then
					return a_cache.inputNames < b_cache.inputNames
				end
				return a_cache.inputRarity < b_cache.inputRarity
			end
			return a_cache.count > b_cache.count
		end
		return a_cache.name < b_cache.name
	end
	return a_cache.rarity > b_cache.rarity
end

function loadRecipes(amount)
	errorMessage = "Error while loading recipe."
	currentRecipes = {}
	local item = _ENV.craftingItemSlot:item()
	local craftingStation = _ENV.craftingStationSlot:item()

	local function insertRecipe(recipe)
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		local cache = {}
		for currency, value in pairs(recipe.currencyInputs or {}) do
			table.insert(recipe.input, { item = currency, count = value })
		end
		recipe.currencyInputs = nil

		cache.input = {}
		cache.inputRarity = 0
		cache.inputNames = ""
		for i, input in ipairs(recipe.input) do
			cache.input[i] = {}
			local inputCache = cache.input[i]
			inputCache.itemConfig = root.itemConfig(input)
			inputCache.mergedConfig = sb.jsonMerge(inputCache.itemConfig.config, inputCache.itemConfig.parameters)
			inputCache.mergedConfig.shortdescription = inputCache.mergedConfig.shortdescription or (input.name or input.item)
			if sb.stripEscapeCodes ~= nil then
				inputCache.name = sb.stripEscapeCodes(inputCache.mergedConfig.shortdescription)
			else
				inputCache.name = inputCache.mergedConfig.shortdescription:gsub("%b^;", "")
			end
			inputCache.rarity = rarityMap[(inputCache.mergedConfig.rarity or "common"):lower()] or 0

			cache.inputRarity = cache.inputRarity + inputCache.rarity
			cache.inputNames = cache.inputNames .. inputCache.name
		end

		if recipe.output[1] then
			cache.output = {}
			cache.rarity = 0
			cache.count = 0
			if sb.stripEscapeCodes ~= nil then
				cache.name = sb.stripEscapeCodes(recipe.recipeName)
			else
				cache.name = recipe.recipeName:gsub("%b^;", "")
			end
			for i, product in ipairs(recipe.output) do
				cache.output[i] = {}
				local outputCache = cache.output[i]
				outputCache.itemConfig = root.itemConfig(product)
				outputCache.mergedConfig = sb.jsonMerge(outputCache.itemConfig.config, outputCache.itemConfig.parameters)
				outputCache.mergedConfig.shortdescription = outputCache.mergedConfig.shortdescription or (product.name or product.item)
				if sb.stripEscapeCodes ~= nil then
					outputCache.name = sb.stripEscapeCodes(outputCache.mergedConfig.shortdescription)
				else
					outputCache.name = outputCache.mergedConfig.shortdescription:gsub("%b^;", "")
				end
				outputCache.rarity = rarityMap[(outputCache.mergedConfig.rarity or "common"):lower()] or 0

				cache.rarity = cache.rarity + outputCache.rarity
				cache.count = cache.count + (product.count or 1)
			end
		else
			cache.itemConfig = root.itemConfig(recipe.output)
			cache.mergedConfig = sb.jsonMerge(cache.itemConfig.config, cache.itemConfig.parameters)
			if sb.stripEscapeCodes ~= nil then
				cache.name = sb.stripEscapeCodes(cache.mergedConfig.shortdescription)
			else
				cache.name = cache.mergedConfig.shortdescription:gsub("%b^;", "")
			end
			cache.rarity = rarityMap[(cache.mergedConfig.rarity or "common"):lower()] or 0
			cache.count = recipe.output.count or 1
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

	local function validateRecipeForItem(recipe)
		currentRecipe = recipe
		for _, input in ipairs(recipe.input) do
			if not root.itemConfig(input) then return end
		end

		if recipe.output[1] then -- this is the only case where we have multiple
			if recipe.recipeBlueprint and requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(recipe.recipeBlueprint)) then return end
			local isItemRecipe = false
			for _, product in ipairs(recipe.output) do
				isItemRecipe = isItemRecipe or ((product.name or product.item) == item.name)
				if not root.itemConfig(product) then return end
				if (not recipe.recipeBlueprint) and requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(product)) then return end
			end
			if isItemRecipe then
				insertRecipe(recipe)
			end
		elseif (recipe.output.name or recipe.output.item) == item.name then
			if requiresBlueprint and not (player.isAdmin() or player.blueprintKnown(recipe.output)) then return end
			insertRecipe(recipe)
		end
	end
	local function validateRecipe(recipe)
		currentRecipe = recipe
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
	if item then
		if not craftingStation then
			for _, recipe in ipairs(uniqueRecipes) do
				local success, error = pcall(validateRecipeForItem, recipe)
				if not success then
					errorPrintout(error)
				end
			end
		end
		for _, recipe in ipairs(stationRecipes) do
			local success, error = pcall(validateRecipeForItem, recipe)
			if not success then
				errorPrintout(error)
			end
		end
		for _, recipe in ipairs(itemRecipes) do
			currentRecipe = recipe
			if filter then
				for _, group in ipairs(filter) do
					local matched = false
					for _, recipeGroup in ipairs(recipe.groups) do
						if group == recipeGroup then
							local success, error = pcall(insertRecipe, recipe)
							if not success then
								errorPrintout(error)
							end
							matched = true
							break
						end
					end
					if matched then break end
				end
			else
				local success, error = pcall(insertRecipe, recipe)
				if not success then
					errorPrintout(error)
				end
			end
		end
	else
		if not craftingStation then
			for _, recipe in ipairs(uniqueRecipes) do
				local success, error = pcall(validateRecipe, recipe)
				if not success then
					errorPrintout(error)
				end
			end
		end
		for _, recipe in ipairs(stationRecipes) do
			local success, error = pcall(validateRecipe, recipe)
			if not success then
				errorPrintout(error)
			end
		end
		for _, recipe in ipairs(allRecipes) do
			local success, error = pcall(validateRecipe, recipe)
			if not success then
				errorPrintout(error)
			end
		end
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
	local function insertSearchedRecipe(i, recipe)
		currentRecipe = recipe
		local cache = recipeOutputCache[i]
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		if recipe.output[1] then
			if cache.name:lower():find(searchText) then
				return table.insert(searchedRecipes, recipe)
			end
			for j, item in ipairs(recipe.output) do
				local id = (item.item or item.name)
				local cache = cache.output[j]
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
	if searchText == "" then
		searchedRecipes = currentRecipes
	else
		searchedRecipes = {}
		for i, recipe in ipairs(currentRecipes) do
			insertSearchedRecipe(i, recipe)
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
				text = "Insert an item to list its recipes.",
				align = "center"
			})
		else
			if _ENV.craftingStationSlot.visible then
				_ENV.recipeListLayout:addChild({
					type = "label",
					text = ("No recipes found.\nInsert a crafting station with a recipe for the desired item."),
					align = "center"
				})
			else
				_ENV.recipeListLayout:addChild({
					type = "label",
					text = ("No recipes found."),
					align = "center"
				})
			end
		end
		return true
	elseif #searchedRecipes == 0 then
		_ENV.recipeListLayout:addChild({
			type = "label",
			text = ("No search results."),
			align = "center"
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

		local duration = math.max(
			0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
			(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
			(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
		) / craftingSpeed
		local divisor, timeLabel = durationLabel(duration)
		local outputLayout
		local productSlotsId = tostring(rand:randu32())
		if recipe.output[1] then
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
						{ type = "label", text = "Products", align = "center" },
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
								{ type = "label", text = "Materials", align = "center" },
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
			selectRecipe(recipe)
		end
	end

	if recipeTabs then
		local firstTab
		for _, tabData in ipairs(recipeTabs) do
			local hash = tostring(rand:randu32())
			local tab = tabField:newTab({
				id = tabData.id,
				title = tabData.title or "",
				icon = tabData.icon,
				visible = false,
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
			local found = false
			local tabScrollArea = _ENV[hash]
			for _, recipe in ipairs(searchedRecipes) do
				for _, v in ipairs(tabData.filter) do
					for _, group in ipairs(recipe.groups) do
						if group == v then
							listRecipe(tabScrollArea, recipe)
							found = true
							break
						end
					end
				end
			end
			tab:setVisible(found)
			if found and not firstTab then
				firstTab = tab
			end
		end
		if firstTab then
			firstTab:select()
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

function selectRecipe(recipe)
	recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
end

function _ENV.craftingItemSlot:onItemModified()
	refreshCurrentRecipes()
end
function _ENV.craftingStationSlot:onItemModified()
	refreshCurrentRecipes()
end
function _ENV.craftingAddonSlot:onItemModified()
	refreshCurrentRecipes()
end

function _ENV.searchBox:onTextChanged()
	activeCoroutine = coroutine.create(searchRecipes)
end
