require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

local recipeRPC
function init()
end
local initial = true
function update()
	if initial and _ENV.capturePodSlot:item() then
		local item = _ENV.capturePodSlot:item()
		initial = false
		displayMonster(item.parameters.pets[1].portrait, item.parameters.pets[1].description, item.parameters.tooltipFields.subtitle)
		refreshDisplayedProducts()
	end
	if recipeRPC and recipeRPC:finished() then
		recipeRPC = nil
		refreshDisplayedProducts()
	end
end

function refreshDisplayedProducts()
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

		if inputs and inputs[1] and ((inputs[1].item or inputs[1].name) == "wr/nutrient_paste") then
			productionRate = inputs[1].count / maxAmount
			_ENV.inputAmountLabel.color = (inputs[1].count > maxAmount) and "00FFFF" or "00FF00"
			_ENV.inputAmountLabel:setText(tostring(inputs[1].count))
		else
			_ENV.inputAmountLabel.color = "FF0000"
			_ENV.inputAmountLabel:setText("0")
		end
		_ENV.inputMaxAmountLabel:setText(tostring(maxAmount))

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
		text = "Insert a capture pod.",
	}, {
		{
			type = "label",
			color = "FF0000",
			text = "This life-form does not produce any resources.",
		}
	})
end

local treasureRolls = 100
function setProducts(dropPools, seed, level)
	if not dropPools then
		recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", nil)
		return
	end

	local recipeCost = 0
	local itemCount = 0
	local products = jarray()
	local rand = sb.makeRandomSource(seed)

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
			for _, treasure in ipairs(root.createTreasure(pool, level, rand:randu32())) do
				addProduct(products, treasure)
			end
		end
	end

	if type(dropPools) == "table" and dropPools[1] then
		dropPools = dropPools[rand:randf(1, #dropPools)]
	end
	if type(dropPools) == "table" then
		for k, v in pairs(dropPools) do
			addTreasurePool(v)
		end
	elseif type(dropPools) == "string" then
		addTreasurePool(dropPools)
	end
	for _, v in ipairs(products) do
		v.count = (math.ceil(v.count / treasureRolls * 1000) - 500) / 1000
		if v.count > 0 then
			local itemConfig = root.itemConfig(v)
			local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
			recipeCost = recipeCost + ((merged.price or 0) * v.count)
			itemCount = itemCount + v.count
		end
	end

	products = util.filter(products, function(v)
		return (v.count > 0)
	end)
	table.sort(products, function(a, b)
		return a.count > b.count
	end)

	local recipe = {
		input = {
			{ item = "wr/nutrient_paste", count = (math.max(recipeCost,0) + itemCount) * 10 }
		},
		output = products,
		duration = 1
	}

	recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
	world.sendEntityMessage(pane.sourceEntity(), "setCapturePod", _ENV.capturePodSlot:item())
end
function displayMonster(portrait, description, name)
	local canvas = widget.bindCanvas(_ENV.creaturePortraitCanvas.backingWidget)
	canvas:clear()

	if portrait then
		canvas:drawJsonDrawables(portrait, {25,25})
	end
	_ENV.creatureNameLabel:setText(name or "")
	_ENV.creatureDescLabel:setText(description or "")
end

function _ENV.capturePodSlot:onItemModified()
	initial = false
	local item = self:item()
	if item then
		local monsterParameters = sb.jsonMerge(root.monsterParameters(item.parameters.pets[1].config.type, item.parameters.pets[1].config.parameters.seed), item.parameters.pets[1].config.parameters)
		local monsterConfig = root.monsterConfig(item.parameters.pets[1].config.type)
		local seed = item.parameters.pets[1].config.parameters.seed
		local level = item.parameters.pets[1].config.parameters.level
		local dropPools = sb.jsonMerge(monsterConfig.dropPools, monsterParameters.dropPools)
		setProducts(dropPools, seed, level)
		displayMonster(item.parameters.pets[1].portrait, item.parameters.pets[1].description, item.parameters.tooltipFields.subtitle)
	else
		setProducts()
		displayMonster()
	end
end

function _ENV.capturePodSlot:acceptsItem(item)
	if not root.monsterConfig then return false end
	return item and item.parameters and item.parameters.pets and item.parameters.pets[1] ~= nil
end
