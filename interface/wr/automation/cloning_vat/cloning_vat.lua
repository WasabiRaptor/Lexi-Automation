
_ENV.productsScrollArea.noRecipeMessage = "Insert a capture pod."
_ENV.productsScrollArea.noProductsMessage = "This life-form does not produce any resources."

function _ENV.inputItemSlot:acceptsItem(item)
	if not root.monsterConfig then return false end
	return item and item.parameters and item.parameters.pets and item.parameters.pets[1] ~= nil
end

local initial = true
function update()
	if initial and _ENV.inputItemSlot:item() then
		local item = _ENV.inputItemSlot:item()
		initial = false
		displayMonster(item.parameters.pets[1].portrait, item.parameters.pets[1].description, item.parameters.tooltipFields.subtitle)
		refreshDisplayedProducts()
	end
end

function displayMonster(portrait, description, name)
	local canvas = widget.bindCanvas(_ENV.creaturePortraitCanvas.backingWidget)
	canvas:clear()

	if portrait then
		canvas:drawJsonDrawables(portrait, {25,25})
	end
	_ENV.inputItemLabel:setText(name or "")
	_ENV.creatureDescLabel:setText(description or "")
end

function _ENV.inputItemSlot:onItemModified()
	initial = false
	local item = self:item()
	if item then
		setProducts(item)
		displayMonster(item.parameters.tooltipFields.objectImage, item.parameters.description, item.parameters.tooltipFields.subtitle)
	else
		setProducts()
		displayMonster()
	end
end

local treasureRolls = 100
function setProducts(item)
	if not item then
		recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", nil)
		return
	end
	if not (item.parameters.currentPets and item.parameters.currentPets[1] and item.parameters.currentPets[1].status)  then
		_ENV.productsScrollArea:clearChildren()
		_ENV.productsScrollArea:addChild({type = "label", color = "FFFF00", text = "Please activate pod at least once to refresh status.", align = "center"})
		return
	end
	productsPossible = jarray()

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
	local function addTreasurePool(pool, level, rand)
		if not root.isTreasurePool(pool) then return end
		for i = 1, treasureRolls do
			for _, treasure in ipairs(root.createTreasure(pool, level, rand:randu32())) do
				treasure.count = treasure.count / treasureRolls
				addProduct(productsPossible, treasure)
			end
		end
	end
	local function handleDropPools(dropPools, level, rand)
		if not dropPools then return end
		if type(dropPools) == "table" and dropPools[1] then
			dropPools = dropPools[rand:randf(1, #dropPools)]
		end
		if type(dropPools) == "table" then
			for k, v in pairs(dropPools) do
				addTreasurePool(v, level, rand)
			end
		elseif type(dropPools) == "string" then
			addTreasurePool(dropPools, level, rand)
		end
	end
	for i, pet in ipairs(item.parameters.currentPets) do
		local monsterParameters = sb.jsonMerge(root.monsterParameters(pet.config.type, pet.config.parameters.seed), pet.config.parameters)
		local monsterConfig = root.monsterConfig(pet.config.type)
		local seed = pet.config.parameters.seed
		local level = pet.config.parameters.level
		local rand = sb.makeRandomSource(sb.staticRandomI32(seed))

		handleDropPools(sb.jsonMerge(monsterConfig.dropPools, monsterParameters.dropPools), level, rand)
		handleDropPools(monsterParameters.landedTreasurePool, level, rand)
	end

	if #productsPossible == 0 then
		world.sendEntityMessage(pane.sourceEntity(), "setControlledProducts", productsPossible)
		recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", nil)
		return
	end

	table.sort(productsPossible, function(a, b)
		return a.count > b.count
	end)

	for i, v in ipairs(productsPossible) do
		productsPossible[i].enabled = true
	end
	world.sendEntityMessage(pane.sourceEntity(), "setControlledProducts", productsPossible)
	setRecipe()
end

function setRecipe()
	local item = _ENV.inputItemSlot:item()
	if not item then return end
	local products = jarray()
	local recipeCost = 0
	local itemCount = 0
	local totalHealth = 0
	for i, pet in ipairs(item.parameters.currentPets) do
		totalHealth = totalHealth + pet.status.stats.maxHealth
	end
	totalHealth = math.ceil(totalHealth)
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

	local recipe = {
		input = {
			{ item = "wr/nutrient_paste", count = totalHealth + (recipeCost * costPriceMultiplier) + (itemCount * costAmountMultiplier)}
		},
		output = products,
		duration = totalHealth
	}
	recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
end
