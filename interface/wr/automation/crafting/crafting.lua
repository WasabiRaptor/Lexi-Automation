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
local activeCoroutine
local recipeTabs
local selectedRecipe
local craftAmount = 1
local crafting = false
local craftTimer = 0

local craftingSpeed
local currentRecipe
local raritySort = true
function init()
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")

	craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1

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
	selectRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))

	_ENV.amountTextBox:setText("1")
end


function update()
	if activeCoroutine and coroutine.status(activeCoroutine) == "suspended" then
		local success, error = coroutine.resume(activeCoroutine, 2000)
		if not success then
			local itemPrintout = sb.printJson(currentRecipe, 2)
			sb.logError("[wr_automation] %s\n%s\n%s", errorMessage, itemPrintout, error)
			_ENV.recipeListLayout:clearChildren()
			_ENV.recipeListLayout:addChild({
				type = "scrollArea",
				expandMode = { 2, 2 },
				scrollDirectons = { 0, 1 },
				children = {
					{
						type = "label", text = errorMessage, align = "center", color = "FF0000"
					},{
						type = "label", text = itemPrintout, color = "FF7F00"
					},{
						type = "label", text = error:gsub("\t", "  "), color = "FFFF00"
					}
				}
			})
		end
	end
	if crafting and selectedRecipe then
		craftRecipe()
	end
end

function craftRecipe()
	craftTimer = craftTimer + script.updateDt()
	local duration = (selectedRecipe.duration / craftingSpeed)
	if craftTimer >= duration then
		for _, v in ipairs(selectedRecipe.input) do
			if (player.hasCountOfItem(v, selectedRecipe.matchInputParameters) < v.count) and not player.isAdmin() then
				crafting = false
				craftAmount = 0
				craftTimer = 0
				return
			end
		end
		for currency, value in pairs(selectedRecipe.currencyInputs or {}) do
			if (player.currency(currency) < value) and not player.isAdmin() then
				crafting = false
				craftAmount = 0
				craftTimer = 0
				return
			end
		end

		if not player.isAdmin() then
			for _, v in ipairs(selectedRecipe.input) do
				player.consumeItem(v, false, selectedRecipe.matchInputParameters)
			end
			for currency, v in pairs(selectedRecipe.currencyInputs or {}) do
				player.consumeCurrency(currency, v)
			end
		end
		if selectedRecipe.output[1] then
			for _, v in ipairs(selectedRecipe.output) do
				player.giveItem(v)
			end
		else
			player.giveItem(selectedRecipe.output)
		end
		craftAmount = craftAmount - 1
		craftTimer = craftTimer - duration
		if craftAmount == 0 then
			crafting = false
		end
		local craftItem = _ENV.craftItemSlot:item()
		craftItem.count = math.max(1,craftAmount)
		_ENV.craftItemSlot:setItem(craftItem)
		widget.setItemSlotProgress(_ENV.craftItemSlot.subWidgets.slot, 0)
	else
		widget.setItemSlotProgress(_ENV.craftItemSlot.subWidgets.slot, craftTimer / duration)
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
	errorMessage = "Error while loading recipes."
	currentRecipes = {}

	local function insertRecipe(recipe)
		currentRecipe = recipe
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		local cache = {}
		cache.input = {}
		cache.inputRarity = 0
		cache.inputNames = ""
		for i, input in ipairs(recipe.input) do
			cache.input[i] = {}
			local inputCache = cache.input[i]
			inputCache.itemConfig = root.itemConfig(input)
			inputCache.mergedConfig = sb.jsonMerge(inputCache.itemConfig.config, inputCache.itemConfig.parameters)
			if sb.stripEscapeCodes ~= nil then
				inputCache.name = sb.stripEscapeCodes(inputCache.mergedConfig.shortdescription)
			else
				inputCache.name = inputCache.mergedConfig.shortdescription:gsub("%b^;")
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
				cache.name = recipe.recipeName:gsub("%b^;")
			end
			for i, product in ipairs(recipe.output) do
				cache.output[i] = {}
				local outputCache = cache.output[i]
				outputCache.itemConfig = root.itemConfig(product)
				outputCache.mergedConfig = sb.jsonMerge(outputCache.itemConfig.config, outputCache.itemConfig.parameters)
				if sb.stripEscapeCodes ~= nil then
					outputCache.name = sb.stripEscapeCodes(outputCache.mergedConfig.shortdescription)
				else
					outputCache.name = outputCache.mergedConfig.shortdescription:gsub("%b^;")
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
				cache.name = cache.mergedConfig.shortdescription:gsub("%b^;")
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
	local function insertSearchedRecipe(i, recipe)
		currentRecipe = recipe
		local cache = recipeOutputCache[i]
		amount = amount - 1
		if amount == 0 then coroutine.yield() end
		if _ENV.materialsAvailableCheckBox.checked then
			for _, v in ipairs(recipe.input) do
				if (player.hasCountOfItem(v, recipe.matchInputParameters) < v.count) and not player.isAdmin() then
					return
				end
			end
			for currency, value in pairs(recipe.currencyInputs or {}) do
				if (player.currency(currency) < value) and not player.isAdmin() then
					return
				end
			end
		end
		if searchText == "" then return table.insert(searchedRecipes, recipe) end
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
	if (searchText == "") and (not _ENV.materialsAvailableCheckBox.checked) then
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
			0, -- It's fine to let people craft instantly here
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
		for currency, value in pairs(recipe.currencyInputs or {}) do
			_ENV[ingredientSlotsId]:addSlot({item = currency, count = value})
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
	crafting = false
	craftAmount = 0
	craftTimer = 0
	_ENV.recipeOutputScrollArea:clearChildren()
	_ENV.recipeMaterialsGrid:setNumSlots(0)
	widget.setItemSlotProgress(_ENV.craftItemSlot.subWidgets.slot, 0)
	selectedRecipe = recipe
	if not recipe then
		_ENV.craftTimeDurationLabel:setText("")
		_ENV.craftTimeScaleLabel:setText("")
		_ENV.craftItemSlot:setItem(nil)
		return
	end

	local duration = math.max(
		0, -- It's fine to let people craft instantly here
		(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	) / craftingSpeed

	local divisor, timeLabel = durationLabel(duration)
	local function addProduct(item)
		local itemConfig = root.itemConfig(item)
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		_ENV.recipeOutputScrollArea:addChild({
			type = "panel",
			style = "convex",
			expandMode = {1,0},
			children = {
				{mode = "v", expandMode = {1,0}},
				{
					{ mode = "h" },
					{ type = "itemSlot", item = item, autoInteract = false },
					{ type = "label", text = merged.shortdescription },
				},
				{ type = "label", text = merged.description },
			}
		})

	end
	_ENV.craftTimeDurationLabel:setText(clipAtThousandth(duration / divisor))
	_ENV.craftTimeScaleLabel:setText(timeLabel)
	if recipe.output[1] then
		local craftItem = copy(recipe.output[1])
		craftItem.count = 1
		_ENV.craftItemSlot:setItem(craftItem)
		for _, product in ipairs(recipe.output) do
			addProduct(product)
		end
	else
		local craftItem = copy(recipe.output)
		craftItem.count = 1
		_ENV.craftItemSlot:setItem(craftItem)
		addProduct(recipe.output)
	end
	for _, v in ipairs(recipe.input) do
		_ENV.recipeMaterialsGrid:addSlot(v)
	end
	for currency, value in pairs(recipe.currencyInputs or {}) do
		_ENV.recipeMaterialsGrid:addSlot({item = currency, count = value})
	end
end

function _ENV.searchBox:onTextChanged()
	activeCoroutine = coroutine.create(searchRecipes)
end

function _ENV.amountTextBox:onTextChanged()
	local number = tonumber(self.text)
	if number and (number >= 0) then
		self:setColor("00FF00")
	else
		self:setColor("FF0000")
	end
end

function _ENV.decAmountButton:onClick()
	local number = tonumber(_ENV.amountTextBox.text)
	number = math.max(1, number - 1)
	_ENV.amountTextBox:setText(tostring(number))
end
function _ENV.incAmountButton:onClick()
	local number = tonumber(_ENV.amountTextBox.text)
	number = math.max(1, number + 1)
	_ENV.amountTextBox:setText(tostring(number))
end

function _ENV.craftButton:onClick()
	for _, v in ipairs(selectedRecipe.input) do
		if (player.hasCountOfItem(v, selectedRecipe.matchInputParameters) < v.count) and not player.isAdmin() then
			return
		end
	end

	local number = tonumber(_ENV.amountTextBox.text)
	if number and (number >= 0) then
		craftAmount = craftAmount + number
		local craftItem = _ENV.craftItemSlot:item()
		craftItem.count = craftAmount
		_ENV.craftItemSlot:setItem(craftItem)
	end
	crafting = true
end

function _ENV.materialsAvailableCheckBox:onClick()
	activeCoroutine = coroutine.create(searchRecipes)
end
