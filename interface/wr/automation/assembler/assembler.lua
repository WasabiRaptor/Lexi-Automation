require("/scripts/util.lua")
require("/interface/wr/automation/labels.lua")

local rarityMap = {}
local currentRecipes = {}
local recipeOutputCache = {}
local recipesPerPage = 50
local searchedRecipes = {}
local inputNodesConfig
local outputNodesConfig

wr_assemblerRecipes = {} -- for scripted crafting stations to have scripts to tell the assembler what recipes it has

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
	_ENV.craftingAddonSlot:setVisible(_ENV.craftingAddonSlot:item() ~= nil)
	_ENV.recipeListLayout:clearChildren()
	_ENV.recipeListLayout:addChild({
		type = "label", text = "Loading Recipes...", align = "center"
	})

	local craftingItem = _ENV.craftingItemSlot:item()
	local craftingStation = _ENV.craftingStationSlot:item()

	filter = nil

	if craftingStation then
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
		if merged.wr_assemblerRecipeScripts then
			for _, v in ipairs(merged.wr_assemblerRecipeScripts) do
				require(v)
			end
			filter, stationRecipes, requiresBlueprint, recipeTabs = wr_assemblerRecipes
				[(craftingStation.item or craftingStation.name)](craftingStation, craftingAddon)
		elseif merged.interactAction == "OpenCraftingInterface" then
			interactData = merged.interactData
		elseif merged.upgradeStages then
			local upgradeData = merged.upgradeStages
				[(merged.scriptStorage or {}).currentStage or merged.startingUpgradeStage]
			interactData = upgradeData.interactData
			if upgradeData.addonConfig and upgradeData.addonConfig.usesAddons then
				doAddons(upgradeData.addonConfig.usesAddons)
			end
		elseif merged.addonConfig and merged.addonConfig.usesAddons then
			_ENV.craftingAddonSlot:setVisible(true)
			doAddons(merged.addonConfig.usesAddons)
		end

		if interactData then
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
	else
		filter = world.getObjectParameter(pane.sourceEntity(), "filter")
		recipeTabs = world.getObjectParameter(pane.sourceEntity(), "recipeTabs")
		requiresBlueprint = true
	end
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
	local item = _ENV.craftingItemSlot:item()
	local craftingStation = _ENV.craftingStationSlot:item()

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

	local function validateRecipeForItem(recipe)
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
				validateRecipeForItem(recipe)
			end
		end
		for _, recipe in ipairs(stationRecipes) do
			validateRecipeForItem(recipe)
		end
		for _, recipe in ipairs(itemRecipes) do
			if filter then
				for _, group in ipairs(filter) do
					local matched = true
					for _, recipeGroup in ipairs(recipe.groups) do
						if group == recipeGroup then
							insertRecipe(recipe)
							matched = true
							break
						end
					end
					if matched then break end
				end
			else
				insertRecipe(recipe)
			end
		end
	else
		if not craftingStation then
			for _, recipe in ipairs(uniqueRecipes) do
				validateRecipe(recipe)
			end
		end
		for _, recipe in ipairs(stationRecipes) do
			validateRecipe(recipe)
		end
		for _, recipe in ipairs(allRecipes) do
			validateRecipe(recipe)
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

	local inputs = (world.getObjectParameter(pane.sourceEntity(), "matterStreamInput") or {})[1] or {}
	for _, newInput in ipairs(inputs) do
		newInput.used = false
		for _, input in ipairs(recipe.input) do
			if root.itemDescriptorsMatch(input, newInput, recipe.matchInputParameters) then
				newInput.used = true
				break
			end
		end
	end
	for _, recipeItem in ipairs(recipe.input) do
		local recieved = false
		for _, inputItem in ipairs(inputs) do
			if root.itemDescriptorsMatch(recipeItem, inputItem, recipe.matchInputParameters) then
				recieved = true
				break
			end
		end
		if not recieved then
			table.insert(inputs, sb.jsonMerge(recipeItem, {count = 0, used = true}))
		end
	end

	table.sort(inputs, function(a, b)
		if a.used == b.used then
			local a_config = root.itemConfig(a)
			local a_merged = sb.jsonMerge(a_config.config, a_config.parameters)
			local b_config = root.itemConfig(b)
			local b_merged = sb.jsonMerge(b_config.config, b_config.parameters)
			if sb.stripEscapeCodes ~= nil then
				return sb.stripEscapeCodes(a_merged.shortdescription) < sb.stripEscapeCodes(b_merged.shortdescription)
			else
				return a_merged.shortdescription:gsub("%b^;") < b_merged.shortdescription:gsub("%b^;")
			end
		else
			return a.used
		end
	end)

	local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
	local duration = math.max(
		0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
		(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	)
	local maxProductionRate = craftingSpeed / duration
	local productionRate
	local minimumProductionRate = world.getObjectParameter(pane.sourceEntity(), "minimumProductionRate") or 0
	local balanced = true
	for _, input in ipairs(inputs) do
		if input.used then
			for _, recipeItem in ipairs(recipe.input) do
				if root.itemDescriptorsMatch(input, recipeItem, recipe.matchInputParameters) then
					local rate = (input.count / ((recipeItem.count or 1) * maxProductionRate)) * maxProductionRate
					if not productionRate then
						balanced = rate <= maxProductionRate
						productionRate = math.min(maxProductionRate, rate)
					else
						balanced = balanced and (rate == productionRate)
						productionRate = math.min(productionRate, rate)
					end
					break
				end
			end
		end
	end

	_ENV.recipeInputsScrollArea:clearChildren()
	for _, input in ipairs(inputs) do
		local itemConfig = root.itemConfig(input)
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		local productionLabels
		if input.used then
			local inputRate = 0
			local inputTarget = 0
			for _, recipeItem in ipairs(recipe.input) do
				if root.itemDescriptorsMatch(input, recipeItem, recipe.matchInputParameters) then
					inputTarget = ((recipeItem.count or 1) * maxProductionRate)
					inputRate = (input.count / inputTarget) * maxProductionRate
					break
				end
			end
			local color
			if not (inputRate > minimumProductionRate) then
				color = "FF0000"
			elseif (inputRate == maxProductionRate) or balanced then
				color = "00FF00"
			elseif inputRate > maxProductionRate then
				color = "00FFFF"
			elseif inputRate < maxProductionRate then
				color = "FFFF00"
			end
			local timeMultiplier, timeLabel = timeScale(inputTarget)
			productionLabels = {
				{ type = "image", file = inputNodesConfig[1].icon },
				{ type = "label", text = clipAtThousandth((timeMultiplier * input.count)),       color = color, inline = true },
				{ type = "label", text = "/",                        inline = true },
				{ type = "label", text = clipAtThousandth((timeMultiplier * inputTarget)), inline = true },
				{ type = "label", text = timeLabel,               inline = true }
			}
		else
			local timeMultiplier, timeLabel = timeScale(input.count)
			productionLabels = {
				{ type = "image", file = inputNodesConfig[1].icon },
				{ type = "label", text = clipAtThousandth((timeMultiplier * input.count)), color = "FF00FF", inline = true },
				{ type = "label", text = timeLabel,          inline = true }
			}
		end
		if input.used or (input.count > 0) then
			_ENV.recipeInputsScrollArea:addChild({
				type = "panel",
				style = "convex",
				expandMode = {1,0},
				children = {
					{ mode = "v" },
					{
						{ type = "itemSlot", item = sb.jsonMerge(input, { count = 1 }) },
						{
							{ type = "label", text = merged.shortdescription},
							productionLabels
						}
					}
				},
			})
		end
	end
	local color
	if not (productionRate > minimumProductionRate) then
		color = "FF0000"
	elseif (productionRate >= maxProductionRate) or balanced then
		color = "00FF00"
	elseif productionRate < maxProductionRate then
		color = "FFFF00"
	end

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
		local timeMultiplier, timeLabel = timeScale(maxProductionRate)

		_ENV.outputPanel:addChild({ type = "layout", mode = "v", expandMode = { 1, 0 }, children = {
			{ type = "label", text = recipe.recipeName },
			{
				{type = "image", file = outputNodesConfig[1].icon },
				{type= "label", text= clipAtThousandth((timeMultiplier * (productionRate or 0))), color= color, inline= true},
				{type= "label", text= "/", inline= true},
				{type= "label", text= clipAtThousandth((timeMultiplier * maxProductionRate)), inline= true},
				{type= "label", text=timeLabel, inline= true}
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

		local timeMultiplier, timeLabel = timeScale(maxProductionRate * recipe.output.count)
		local outputDisplay = copy(recipe.output)
		outputDisplay.count = 1

		_ENV.outputPanel:addChild({
			type = "layout",
			mode = "h",
			scissoring = false,
			children = {
				{type= "itemSlot", autoInteract= false, glyph= "output.png", item = outputDisplay},
				{
					{type= "label", text= merged.shortdescription},
					{
						{type = "image", file = outputNodesConfig[1].icon },
						{type= "label", text= clipAtThousandth((timeMultiplier * recipe.output.count * (productionRate or 0))), color= color, inline= true},
						{type= "label", text= "/", inline= true},
						{type= "label", text= clipAtThousandth((timeMultiplier * recipe.output.count * maxProductionRate)), inline= true},
						{type= "label", text=timeLabel, inline= true}
					}
				}
			},
		})
	end
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
