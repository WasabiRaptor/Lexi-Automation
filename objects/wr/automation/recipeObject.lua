require("/objects/wr/automation/wr_automation.lua")
local old = {
	init = init or function() end,
	onNodeConnectionChange = onNodeConnectionChange or function() end,
	onInputNodeChange = onInputNodeChange or function() end
}

local recipe
local outputCount
local inputs
function init()
	old.init()
	recipe = config.getParameter("recipe")
	message.setHandler("setRecipe", function(_, _, newRecipe)
		if compare(recipe, newRecipe) then return end
		recipe = newRecipe
		object.setConfigParameter("recipe", newRecipe)
		refreshOutput(true)
	end)
	inputs = config.getParameter("matterStreamInput")
	message.setHandler("refreshInputs", function (_,_)
		refreshOutput()
	end)
end


function refreshOutput(force)
	if (not recipe) or (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		object.setConfigParameter("matterStreamOutput", nil)
		object.setConfigParameter("matterStreamInput", nil)
		object.setOutputNodeLevel(0, false)
		inputs = nil
		return
	end
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	local newInputs = wr_automation.countInputs(0, recipe)
	if (not force) and compare(newInputs, inputs) and (newOutputCount == outputCount) then return end
	object.setConfigParameter("matterStreamInput", newInputs)
	inputs = newInputs
	outputCount = newOutputCount

	local craftingSpeed = config.getParameter("craftingSpeed") or 1
	local maxProductionRate = craftingSpeed / math.max(
		0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
		(config.getParameter("minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	)
	local productionRate = maxProductionRate
	for _, recipeItem in ipairs(recipe.input) do
		for _, inputItem in ipairs(inputs) do
			if root.itemDescriptorsMatch(recipeItem, inputItem, recipe.matchInputParameters) then
				recieved = true
				productionRate = math.min(productionRate, (inputItem.count / ((recipeItem.count or 1) * maxProductionRate)))
				break
			end
		end
	end
	if recipe.output[1] then
		local products = copy(recipe.output)
		for _, product in ipairs(products) do
			product.count = productionRate * (product.count or 1)
		end
		object.setConfigParameter("products", {products})
		wr_automation.setOutputs({products})
	else
		local product = copy(recipe.output)
		product.count = productionRate * (product.count or 1)
		object.setConfigParameter("products", {{product}})
		wr_automation.setOutputs({{product}})
	end
end
function onInputNodeChange(...)
	old.onInputNodeChange(...)
	refreshOutput()
end
function onNodeConnectionChange(...)
	old.onNodeConnectionChange(...)
	refreshOutput()
end
