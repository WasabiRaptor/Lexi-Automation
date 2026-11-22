require("/scripts/util.lua")
require("/interface/games/util.lua")
function uninit()
end
_ENV.productsScrollArea.noRecipeMessage = "Insert a seed."
_ENV.productsScrollArea.noProductsMessage = "This seed does not produce any resources."

local initial = true
function update()
	if initial and _ENV.inputItemSlot:item() then
		initial = false
		refreshDisplayedProducts()
	end
end

function _ENV.inputItemSlot:onItemModified()
    initial = false
	setProducts()
end

function _ENV.inputItemSlot:acceptsItem(item)
	local itemConfig = root.itemConfig(item)
	return itemConfig.config.objectType == "farmable"
end

local treasureRolls = 100
function setProducts()
	local item = _ENV.inputItemSlot:item()

	if not item then
		recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", nil)
		world.sendEntityMessage(pane.sourceEntity(), "setPlantImage", nil)
		return
	end
	local position = world.entityPosition(pane.sourceEntity())
	local itemConfig = root.itemConfig(item)
	local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)

	local seed = sb.staticRandomI32((item.name or item.item)) + sb.staticRandomI32(sb.printJson(position))
	local itemCount = 0
	productsPossible = jarray()
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
			for _, treasure in ipairs(root.createTreasure(pool, world.threatLevel(), rand:randu32())) do
				treasure.count = treasure.count / treasureRolls
				addProduct(productsPossible, treasure)
			end
		end
	end
	for i = 1, #merged.stages do
		for j = 1, i do
			local stage = merged.stages[j]
			if stage.harvestPool and j == i then
				addTreasurePool(stage.harvestPool)
			end
		end
	end

	for _, v in ipairs(productsPossible) do
		itemCount = itemCount + v.count
	end

	table.sort(productsPossible, function(a, b)
		return a.count > b.count
    end)

	for i, v in ipairs(productsPossible) do
		productsPossible[i].enabled = true
	end

	world.sendEntityMessage(pane.sourceEntity(), "setControlledProducts", productsPossible)
	setRecipe()
	world.sendEntityMessage(pane.sourceEntity(), "setPlantImage", (item.item or item.name))
end

function setRecipe()
	local item = _ENV.inputItemSlot:item()
	if not item then return end
	local products = jarray()
	local recipeCost = 0
    local itemCount = 0
	local itemConfig = root.itemConfig(item)
	local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
	local position = world.entityPosition(pane.sourceEntity())
	local seed = sb.staticRandomI32((item.name or item.item)) + sb.staticRandomI32(sb.printJson(position))
	local rand = sb.makeRandomSource(seed)
	local duration = 0
	for i = 1, #merged.stages do
		-- we're getting the best duration for harvesting at each stage
		local harvestDuration = 0
		for j = 1, i do
			local stage = merged.stages[j]
			if stage.harvestPool and j == i then
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


	for i, v in ipairs(productsPossible) do
		if productsPossible[i].enabled then
			table.insert(products,v)
		end
	end
	for _, v in ipairs(products) do
		local itemConfig = root.itemConfig(v)
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		recipeCost = recipeCost + ((merged.price or 0) * v.count)
		itemCount = itemCount + v.count
	end

	local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
	local recipe = {
		input = {
			{ item = "liquidwater", count = #merged.stages * (duration / craftingSpeed) + (recipeCost * costPriceMultiplier) + (itemCount * costAmountMultiplier) }
		},
		output = productsPossible,
		duration = duration
	}

	recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
end
