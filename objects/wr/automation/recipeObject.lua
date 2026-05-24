require("/objects/wr/automation/wr_automation.lua")
local old = {
	init = init or function() end,
	onNodeConnectionChange = onNodeConnectionChange or function() end,
	onInputNodeChange = onInputNodeChange or function() end
}

local recipe
local outputCount
local inputs
local passthrough
local powered
function init()
	old.init()
	wr_automation.init()
	recipe = config.getParameter("recipe")
	passthrough = config.getParameter("passthrough")
	local products = config.getParameter("products")
	message.setHandler("setRecipe", function(_, _, newRecipe)
		if compare(recipe, newRecipe) then return end
		recipe = newRecipe
		object.setConfigParameter("recipe", newRecipe)
		refreshOutput(true)
	end)
	inputs = (config.getParameter("matterStreamInput") or {})[1]
	message.setHandler("refreshInputs", function (_,_, force)
		refreshOutput(force)
	end)

	powered = wr_automation.checkPowered(config.getParameter("activePowerConsumption"))
	if products then
		if powered then
			object.setConfigParameter("status", "on")
			wr_automation.playAnimations("on")
		else
			object.setConfigParameter("status", "lowPower")
			wr_automation.playAnimations("lowPower")
		end
	end
end

function die()
	wr_automation.setProducts(nil)
	wr_automation.usePower(0)
	wr_automation.producePower(0)
end

function refreshOutput(force)
	if (not recipe and not passthrough) or (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		wr_automation.addPollution(config.getParameter("idleWasteRadiaton"))
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		wr_automation.producePower(0)
		wr_automation.setProducts(nil)
		object.setConfigParameter("matterStreamInput", nil)
		wr_automation.clearAllOutputs()
		object.setConfigParameter("status", ((not recipe) and "noRecipe") or "missingInput")
		wr_automation.playAnimations("off")
		inputs = nil
		return
	end
	local activePowerConsumption = config.getParameter("activePowerConsumption")
	local newPowered = wr_automation.checkPowered(activePowerConsumption)
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0, recipe)
	if (not force) and (newPowered == powered) and (fromExporter == config.getParameter("fromExporter")) and (newOutputCount == outputCount) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	outputCount = newOutputCount
	powered = newPowered
	if not recipe then
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		wr_automation.producePower(0)
		local outputs, totalItems = wr_automation.setOutputs({inputs})
		object.setConfigParameter("status", "noRecipe")
		wr_automation.playAnimations("off")
		wr_automation.addPollution((outputCount == 0 and totalItems or 0) + (config.getParameter("idlePollution") or 0))
		return
	end
	wr_automation.usePower(activePowerConsumption)

	local products = jarray()
	products[1] = jarray()
	local function addProduct(nodeProducts, item)
		local found = false
		for _, v in ipairs(nodeProducts) do
			if root.itemDescriptorsMatch(v, item, true) then
				v.count = v.count + item.count
				found = true
				break
			end
		end
		if not found then
			table.insert(nodeProducts, item)
		end
	end

	local craftingSpeed = config.getParameter("craftingSpeed") or 1
	local duration = math.max(
		0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
		(config.getParameter("minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	)
	local maxProductionRate = craftingSpeed / duration
	local productionRate = maxProductionRate
	local minimumProductionRate = config.getParameter("minimumProductionRate") or 0

	for _, recipeItem in ipairs(recipe.input) do
		for _, inputItem in ipairs(inputs) do
			if root.itemDescriptorsMatch(recipeItem, inputItem, recipe.matchInputParameters) then
				productionRate = math.min(productionRate,
					(inputItem.count / ((recipeItem.count or 1) * maxProductionRate)) * maxProductionRate
				)
				break
			end
		end
	end
	local pollution = 0
	if productionRate > minimumProductionRate then
		if passthrough then
			products[1] = copy(inputs)
			for _, recipeItem in ipairs(recipe.input) do
				for _, product in ipairs(products[1]) do
					if root.itemDescriptorsMatch(recipeItem, product, recipe.matchInputParameters) then
						product.count = product.count - (recipeItem.count * productionRate)
						break
					end
				end
			end
		else
			for _, input in ipairs(inputs) do
				local used = false
				for _, recipeItem in ipairs(recipe.input) do
					if root.itemDescriptorsMatch(recipeItem, input, recipe.matchInputParameters) then
						pollution = pollution + input.count - (recipeItem.count * productionRate)
						used = true
						break
					end
				end
				if not used then
					pollution = pollution + input.count
				end
			end
		end

		if recipe.output then
			if recipe.output[1] then
				local realProdcuts = copy(recipe.output)
				for _, product in ipairs(realProdcuts) do
					product.count = productionRate * (product.count or 1)
					addProduct(products[1], product)
				end
				wr_automation.setProducts({ realProdcuts })
			else
				local product = copy(recipe.output)
				product.count = productionRate * (product.count or 1)
				wr_automation.setProducts({ { product } })
				addProduct(products[1], product)
			end
		end
		wr_automation.producePower((recipe.producePower or 0) * productionRate)

		if powered then
			object.setConfigParameter("status", "on")
			wr_automation.playAnimations("on")
		else
			object.setConfigParameter("status", "lowPower")
			wr_automation.playAnimations("lowPower")
		end
	elseif passthrough then
		products[1] = copy(inputs)
	else
		pollution = totalItems
		wr_automation.producePower(0)
		wr_automation.setProducts(nil)
		wr_automation.clearAllOutputs()
		object.setConfigParameter("status", "missingInput")
		wr_automation.playAnimations("off")
		return
	end
	local outputs, totalOutputItems = wr_automation.setOutputs(products)
	wr_automation.addPollution((outputCount == 0 and totalOutputItems or pollution) + (config.getParameter("activePollution") or 0))
end
function onInputNodeChange(...)
	old.onInputNodeChange(...)
	refreshOutput()
end
function onNodeConnectionChange(...)
	old.onNodeConnectionChange(...)
	refreshOutput()
end
