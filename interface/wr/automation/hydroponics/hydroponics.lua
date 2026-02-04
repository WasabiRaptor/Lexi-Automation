require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

local recipeRPC
local inputNodesConfig
function init()
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	_ENV.inputIconWidget:setFile(inputNodesConfig[1].icon)
end
local initial = true
function update()
	if initial and _ENV.inputItemSlot:item() then
		initial = false
		refreshDisplayedProducts()
	end
	if recipeRPC and recipeRPC:finished() then
		recipeRPC = nil
		refreshDisplayedProducts()
	end
end

function refreshDisplayedProducts()
	local item = _ENV.inputItemSlot:item()
	if item then
		local itemConfig = root.itemConfig(item)
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		_ENV.inputItemLabel:setText(merged.shortdescription or "")
	else
		_ENV.inputItemLabel:setText("")
	end
	local products
	local recipe = world.getObjectParameter(pane.sourceEntity(), "recipe")
	if recipe then
		local inputs = world.getObjectParameter(pane.sourceEntity(), "matterStreamInput")
		local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
		local maxProductionRate = craftingSpeed / math.max(
			0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
			(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
			(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
		)
		local productionRate = 0
		local maxAmount = recipe.input[1].count * maxProductionRate
		local timeMultiplier, timeLabel = timeScale(productionRate)

		if inputs and inputs[1] and ((inputs[1].item or inputs[1].name) == "liquidwater") then
			productionRate = math.min(maxProductionRate, (inputs[1].count / maxAmount))
			_ENV.inputAmountLabel.color = (inputs[1].count > maxAmount) and "00FFFF" or "00FF00"
			_ENV.inputAmountLabel:setText(clipAtThousandth((inputs[1].count * timeMultiplier)))
		else
			_ENV.inputAmountLabel.color = "FF0000"
			_ENV.inputAmountLabel:setText("0")
		end
		_ENV.inputMaxAmountLabel:setText(clipAtThousandth((maxAmount * timeMultiplier)))
		_ENV.inputTimeScaleLabel:setText(timeLabel)

		products = jarray()
		products[1] = copy(recipe.output)
		for _, product in ipairs(products[1]) do
			product.count = product.count * productionRate
		end
	else
		_ENV.inputAmountLabel.color = "FF0000"
		_ENV.inputAmountLabel:setText("0")
		_ENV.inputMaxAmountLabel:setText("0")
	end

	displayProducts(products, {
		type = "label",
		text = "Insert a harvestable plant.",
	}, {
		{
			type = "label",
			color = "FF0000",
			text = "This plant does not produce any resources.",
		}
	})
end

local treasureRolls = 100
function setProducts()
	local item = _ENV.inputItemSlot:item()

	if not item then
		recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", nil)
		return
	end
	local position = world.entityPosition(pane.sourceEntity())
	local itemConfig = root.itemConfig(item)
	local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)

	local seed = sb.staticRandomI32((item.name or item.item)) + sb.staticRandomI32(sb.printJson(position))
	local itemCount = 0
	local products = jarray()
	local rand = sb.makeRandomSource(seed)

	local duration = 0


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

	local function addTreasurePool(pool)
		if not root.isTreasurePool(pool) then return end
		for i = 1, treasureRolls do
			for _, treasure in ipairs(root.createTreasure(pool, world.threatLevel(), rand:randu32())) do
				treasure.count = treasure.count / treasureRolls
				addProduct(products, treasure)
			end
		end
	end
	for i = 1, #merged.stages do
		-- we're getting the best duration for harvesting at each stage
		local harvestDuration = 0
		for j = 1, i do
			local stage = merged.stages[j]
			if stage.harvestPool and j == i then
				addTreasurePool(stage.harvestPool)
				if stage.resetToStage then
					harvestDuration = 0
					for j = stage.resetToStage + 1, i - 1 do
						local stage = merged.stages[j]
						if stage.duration then
							harvestDuration = harvestDuration + rand:randf(stage.duration[1], stage.duration[2])
						end
					end
				end
				duration = duration + harvestDuration
			elseif stage.duration then
				harvestDuration = harvestDuration + rand:randf(stage.duration[1], stage.duration[2])
			end
		end
	end
	duration = math.floor(duration)

	for _, v in ipairs(products) do
		itemCount = itemCount + v.count
	end

	products = util.filter(products, function(v)
		return (v.count > 0)
	end)
	table.sort(products, function(a, b)
		return a.count > b.count
	end)

	local recipe = {
		input = {
			{ item = "liquidwater", count = (itemCount + #merged.stages) * duration }
		},
		output = products,
		duration = duration
	}
	sb.logInfo(duration)

	recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
	world.sendEntityMessage(pane.sourceEntity(), "setCapturePod", _ENV.inputItemSlot:item())
end

function _ENV.inputItemSlot:onItemModified()
	initial = false
	setProducts()
end

function _ENV.inputItemSlot:acceptsItem(item)
	local itemConfig = root.itemConfig(item)
	return itemConfig.config.objectType == "farmable"
end
