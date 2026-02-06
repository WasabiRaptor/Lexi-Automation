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
local stateAnimations
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
	inputs = config.getParameter("matterStreamInput")
	message.setHandler("refreshInputs", function (_,_)
		refreshOutput()
	end)

	if products then
		object.setConfigParameter("status", "on")
		wr_automation.playAnimations( "on")
	end
end


function refreshOutput(force)
	if (not recipe and not passthrough) or (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		object.setConfigParameter("products", nil)
		object.setConfigParameter("matterStreamOutput", nil)
		object.setConfigParameter("matterStreamInput", nil)
		object.setOutputNodeLevel(0, false)
		object.setConfigParameter("status", ((not recipe) and "noRecipe") or "missingInput")
		wr_automation.playAnimations(stateAnimations[((not recipe) and "noRecipe") or "missingInput"] or "off")
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
	if not recipe then
		wr_automation.setOutputs({inputs})
		object.setConfigParameter("status", "noRecipe")
		wr_automation.playAnimations("off")
		return
	end

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
	local maxProductionRate = craftingSpeed / math.max(
		0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
		(config.getParameter("minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	)
	local productionRate = maxProductionRate

	for _, recipeItem in ipairs(recipe.input) do
		for _, inputItem in ipairs(inputs) do
			if inputItem.used and root.itemDescriptorsMatch(recipeItem, inputItem, recipe.matchInputParameters) then
				productionRate = math.min(productionRate,
					(inputItem.count / ((recipeItem.count or 1) * maxProductionRate)))
				break
			end
		end
	end
	if passthrough then
		products[1] = copy(inputs)
		for _, product in ipairs(products[1]) do
			if product.used then
				for _, recipeItem in ipairs(recipe.input) do
					if root.itemDescriptorsMatch(recipeItem, product, recipe.matchInputParameters) then
						product.count = product.count - (recipeItem.count * productionRate)
						break
					end
				end
			end
		end
	end
	if productionRate > 0 then
		if recipe.output[1] then
			local realProdcuts = copy(recipe.output)
			for _, product in ipairs(realProdcuts) do
				product.count = productionRate * (product.count or 1)
				addProduct(products[1], product)
			end
			object.setConfigParameter("products", { realProdcuts })
		else
			local product = copy(recipe.output)
			product.count = productionRate * (product.count or 1)
			object.setConfigParameter("products", { { product } })
			addProduct(products[1], product)
		end
		object.setConfigParameter("status", "on")
		wr_automation.playAnimations("on")
	else
		object.setConfigParameter("products", nil)
		object.setConfigParameter("matterStreamOutput", nil)
		object.setOutputNodeLevel(0, false)
		object.setConfigParameter("status", "missingInput")
		wr_automation.playAnimations("off")
		return
	end
	wr_automation.setOutputs(products)
end
function onInputNodeChange(...)
	old.onInputNodeChange(...)
	refreshOutput()
end
function onNodeConnectionChange(...)
	old.onNodeConnectionChange(...)
	refreshOutput()
end
