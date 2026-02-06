require("/scripts/util.lua")
require("/interface/wr/automation/labels.lua")

local rarityMap = {}
local currentRecipes = {}
local recipePage = 0
local recipesPerPage = 50
local searchedRecipes = {}
local recipePages = 1
local inputNodesConfig
local outputNodesConfig

function uninit()
	local craftingItem = _ENV.craftingItemSlot:item()
	local craftingStation = _ENV.craftingStationSlot:item()
	local craftingAddon = _ENV.craftingAddonSlot:item()
	if craftingItem then player.giveItem(craftingItem) end
	if craftingStation then player.giveItem(craftingStation) end
	if craftingAddon then player.giveItem(craftingAddon) end
end

local filter
local uniqueRecipes = {}
local recipeRPC
function init()
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")

	rarityMap = root.assetJson("/interface/wr/automation/rarity.config")
	filter = world.getObjectParameter(pane.sourceEntity(), "filter")

	if world.getObjectParameter(pane.sourceEntity(), "lockRecipes") then
		_ENV.craftingStationSlot:setVisible(false)
		_ENV.craftingAddonSlot:setVisible(false)
	end
	uniqueRecipes = world.getObjectParameter(pane.sourceEntity(), "uniqueRecipes") or {}
	if type(uniqueRecipes) == "string" then
		uniqueRecipes = root.assetJson(uniqueRecipes)
	end
	if type(uniqueRecipes[1]) == "string" then
		local recipeConfigList = uniqueRecipes
		uniqueRecipes = jarray()
		for _, path in ipairs(recipeConfigList) do
			for _, recipe in ipairs(root.assetJson(path)) do
				table.insert(uniqueRecipes, recipe)
			end
		end
	end

	refreshCurrentRecipes()
	displayRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))
end
function update()
	if recipeRPC and recipeRPC:finished() then
		recipeRPC = nil
		displayRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))
	end
end

function refreshCurrentRecipes()
	currentRecipes = copy(uniqueRecipes)
	_ENV.craftingAddonSlot:setVisible(_ENV.craftingAddonSlot:item() ~= nil)

	local craftingItem = _ENV.craftingItemSlot:item()
	local craftingStation = _ENV.craftingStationSlot:item()

	local filter = filter
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
		if merged.interactAction == "OpenCraftingInterface" then
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
				for _, v in ipairs(interactData.recipes) do
					table.insert(currentRecipes, v)
				end
			end
		end
	end
	if craftingItem then
		currentRecipes = util.filter(currentRecipes, function(v)
			if v.output[1] then
				for _, item in ipairs(v.output) do
					if (item.item or item.name) == (craftingItem.name or craftingItem.item) then return true end
				end
			end
			return (v.output.item or v.output.name) == (craftingItem.name or craftingItem.item)
		end)
		for _, v in ipairs(filterRecipes(filter, root.recipesForItem(craftingItem.name or craftingItem.item))) do
			table.insert(currentRecipes, v)
		end
	elseif filter and (root.allRecipes ~= nil) then
		for _, v in ipairs(root.allRecipes(filter)) do
			table.insert(currentRecipes, v)
		end
	end
	currentRecipes = util.filter(currentRecipes, function(v)
		-- filter to make sure all listed recipes result in real items that do exist
		if v.output[1] then
			for _, product in ipairs(v.output) do
				if not root.itemConfig(product) then return false end
			end
		elseif not root.itemConfig(v.output) then return false end
		return v.output ~= nil
	end)

	table.sort(currentRecipes, function(a, b)
		if a.output[1] and b.output[1] then
			return a.recipeName < b.recipeName
		elseif a.output[1] then
			return true
		elseif b.output[1] then
			return false
		end
		local a_config = root.itemConfig(a.output)
		local a_merged = sb.jsonMerge(a_config.config, a_config.parameters)
		local a_rarity = rarityMap[(a_merged.rarity or "common"):lower()] or 0
		local b_config = root.itemConfig(b.output)
		local b_merged = sb.jsonMerge(b_config.config, b_config.parameters)
		local b_rarity = rarityMap[(b_merged.rarity or "common"):lower()] or 0
		if a_rarity == b_rarity then
			if sb.stripEscapeCodes ~= nil then
				return sb.stripEscapeCodes(a_merged.shortdescription) < sb.stripEscapeCodes(b_merged.shortdescription)
			else
				return a_merged.shortdescription:gsub("%b^;") < b_merged.shortdescription:gsub("%b^;")
			end
		else
			return a_rarity > b_rarity
		end
	end)
	searchRecipes()
	refreshDisplayedRecipes()
end
function searchRecipes()
	recipePage = 0
	local searchText = _ENV.searchBox.text:lower()
	searchedRecipes = util.filter(currentRecipes, function(recipe)
		if searchText == "" then return true end
		if recipe.output[1] then
			if recipe.recipeName:lower():find(searchText) then return true end
			for _, item in ipairs(recipe.output) do
				local id = (item.item or item.name)
				local itemConfig = root.itemConfig(item)
				local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
				if id:lower():find(searchText) or merged.shortdescription:lower():find(searchText) then return true end
			end
		else
			local id = (recipe.output.item or recipe.output.name)
			local itemConfig = root.itemConfig(recipe.output)
			local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
			return id:lower():find(searchText) or merged.shortdescription:lower():find(searchText)
		end
	end)
	recipePages = math.ceil(#searchedRecipes/recipesPerPage)
end
function refreshDisplayedRecipes()
	_ENV.recipeSearchScrollArea:clearChildren()
	if #currentRecipes == 0 then
		local craftingItem = _ENV.craftingItemSlot:item()
		if not craftingItem then
			_ENV.recipeSearchScrollArea:addChild({
				type = "label",
				text = "Insert an item to list its recipes."
			})
		else
			if _ENV.craftingStationSlot.visible then
				_ENV.recipeSearchScrollArea:addChild({
					type = "label",
					text = ("No recipes found.\nInsert a crafting station with a recipe for the desired item.")
				})
			else
				_ENV.recipeSearchScrollArea:addChild({
					type = "label",
					text = ("No recipes found.")
				})
			end

		end
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
			recipePage = recipePage - 1
			if recipePage < 0 then
				recipePage = recipePages
			end
			refreshDisplayedRecipes()
		end
		function _ENV.recipePageNextTopButton:onClick()
			recipePage = recipePage + 1
			if recipePage > recipePages then
				recipePage = 0
			end
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
					{ type = "label", text = merged.shortdescription}
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
									{ mode = "v", expandMode = {1,0} },
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
			recipePage = recipePage - 1
			if recipePage < 0 then
				recipePage = recipePages
			end
			refreshDisplayedRecipes()
		end
		function _ENV.recipePageNextBottomButton:onClick()
			recipePage = recipePage + 1
			if recipePage > recipePages then
				recipePage = 0
			end
			refreshDisplayedRecipes()
		end
	end

end
function filterRecipes(filter, recipes)
	return util.filter(recipes, function (v)
		if not filter then return true end
		for _, filterGroup in ipairs(filter) do
			for _, recipeGroup in ipairs(v.groups or {}) do
				if recipeGroup == filterGroup then return true end
			end
		end
	end)
end

function displayRecipe(recipe)
	if not recipe then return end

	local inputs = world.getObjectParameter(pane.sourceEntity(), "matterStreamInput") or {}
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
	local maxProductionRate = craftingSpeed / math.max(
		0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
		(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	)
	local productionRate
	local minimumProductionRate = world.getObjectParameter(pane.sourceEntity(), "minimumProductionRate") or 0
	local balanced = true
	for _, input in ipairs(inputs) do
		if input.used then
			for _, recipeItem in ipairs(recipe.input) do
				if root.itemDescriptorsMatch(input, recipeItem, recipe.matchInputParameters) then
					local rate = (input.count / ((recipeItem.count or 1) * maxProductionRate))
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
					inputRate = (input.count / inputTarget)
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
			local timeMultiplier, timeLabel = timeScale(input.count)
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
		local timeMultiplier, timeLabel = timeScale(productionRate)

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

		local timeMultiplier, timeLabel = timeScale(productionRate)

		_ENV.outputPanel:addChild({
			type = "layout",
			mode = "h",
			scissoring = false,
			children = {
				{type= "itemSlot", autoInteract= false, glyph= "output.png", item = recipe.output},
				{
					{type= "label", text= merged.shortdescription},
					{
						{type = "image", file = outputNodesConfig[1].icon },
						{type= "label", text= clipAtThousandth((timeMultiplier * (productionRate or 0))), color= color, inline= true},
						{type= "label", text= "/", inline= true},
						{type= "label", text= clipAtThousandth((timeMultiplier * maxProductionRate)), inline= true},
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
	searchRecipes()
	refreshDisplayedRecipes()
end
