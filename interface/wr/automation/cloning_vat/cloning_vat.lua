require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/labels.lua")
function uninit()
end

local outputNodesConfig
local recipeRPC
local inputNodesConfig
local cloningProducts
local cloningEnabled
local excludedProducts = 0
local totalProducts = 0
local cloningPrecision = 0
function init()
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	cloningProducts = world.getObjectParameter(pane.sourceEntity(), "cloningProducts")
	cloningEnabled = world.getObjectParameter(pane.sourceEntity(), "cloningEnabled")
	cloningPrecision = world.getObjectParameter(pane.sourceEntity(), "cloningPrecision") or 0
	cloningCountMultiplier = world.getObjectParameter(pane.sourceEntity(), "cloningCountMultiplier") or 1
	cloningPriceMultiplier = world.getObjectParameter(pane.sourceEntity(), "cloningPriceMultiplier") or 1
	_ENV.inputIconWidget:setFile(inputNodesConfig[1].icon)
	if root.monsterConfig ~= nil then
		_ENV.creatureDescLabel:setText("")
	end
end
local initial = true
function update()
	if initial and _ENV.inputItemSlot:item() then
		local item = _ENV.inputItemSlot:item()
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
	local recipe = world.getObjectParameter(pane.sourceEntity(), "recipe")
	local productionRate = 0
	if recipe then
		local inputs = (world.getObjectParameter(pane.sourceEntity(), "matterStreamInput") or {})[1] or {}
		local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
		local duration = math.max(
			0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
			(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
			(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
		)
		local maxProductionRate = craftingSpeed / duration
		local maxAmount = recipe.input[1].count * maxProductionRate
		local timeMultiplier, timeLabel = timeScale(productionRate)

		if inputs and inputs[1] and ((inputs[1].item or inputs[1].name) == "wr/nutrient_paste") then
			productionRate = math.min(maxProductionRate, (inputs[1].count / maxAmount) * maxProductionRate)
			_ENV.inputAmountLabel.color = (inputs[1].count > maxAmount) and "00FFFF" or "00FF00"
			_ENV.inputAmountLabel:setText(clipAtThousandth(inputs[1].count * timeMultiplier))
		else
			_ENV.inputAmountLabel.color = "FF0000"
			_ENV.inputAmountLabel:setText("0")
		end
		_ENV.inputMaxAmountLabel:setText(clipAtThousandth(maxAmount * timeMultiplier))
		_ENV.inputTimeScaleLabel:setText(timeLabel)
	else
		_ENV.inputAmountLabel.color = "FF0000"
		_ENV.inputAmountLabel:setText("0")
		_ENV.inputMaxAmountLabel:setText("0")
	end

	_ENV.productsScrollArea:clearChildren()
	if cloningProducts and cloningEnabled then
		countExcludedProducts()
		if totalProducts == 0 then
			_ENV.amountExcludedLabel:setText("0%")
		else
			_ENV.amountExcludedLabel:setText(("%d%%"):format(math.ceil((excludedProducts / totalProducts) * 100)))
		end
		_ENV.maxExcludedLabel:setText(("%d%%"):format(math.ceil((cloningPrecision) * 100)))
		if #cloningProducts > 0 then
			for i, product in ipairs(cloningProducts) do
				local itemConfig = root.itemConfig(product)
				local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
				local timeMultiplier, timeLabel = timeScale(product.count)
				_ENV.productsScrollArea:addChild({
					type = "panel",
					style = "convex",
					expandMode = { 1, 0 },
					children = {
						{ mode = "v" },
						{
							{ type = "itemSlot", item = sb.jsonMerge(product, { count = 1 }) },
							{
								{ type = "label", text = (merged.shortdescription or product.name or product.item or "") },
								{
									{ type = "checkBox", checked = cloningEnabled[i], id = "cloningProduct"..i.."CheckBox" },
									{ type = "image", file = outputNodesConfig[1].icon or "/interface/wr/automation/output.png" },
									{ type = "label", text = clipAtThousandth((timeMultiplier * product.count * productionRate)), inline = true },
									{ type = "label", text = "/", inline = true },
									{ type = "label", text = clipAtThousandth((timeMultiplier * product.count)),                        inline = true },
									{ type = "label", text = timeLabel,                                                                 inline = true }
								},

							}
						}
					},
				})
				local checkBox = _ENV["cloningProduct"..i.."CheckBox"]
				function checkBox:onClick()
					if self.checked then
						cloningEnabled[i] = self.checked
						world.sendEntityMessage(pane.sourceEntity(), "setCloningProducts", cloningProducts, cloningEnabled)
						countExcludedProducts()
						setRecipe()
					else
						if (((excludedProducts + product.count) / totalProducts) > cloningPrecision) then
							pane.playSound("/sfx/interface/clickon_error.ogg")
							self:setChecked(true)
						else
							cloningEnabled[i] = self.checked
							world.sendEntityMessage(pane.sourceEntity(), "setCloningProducts", cloningProducts, cloningEnabled)
							countExcludedProducts()
							setRecipe()
						end
					end
				end
			end
		else
			_ENV.productsScrollArea:addChild({
				type = "label",
				color = "FF0000",
				text = "This life-form does not produce any resources.",
			})
		end
	else
		_ENV.productsScrollArea:addChild({
			type = "label",
			text = "Insert a capture pod.",
		})
	end
end

local treasureRolls = 100
function setProducts(item)
	cloningProducts = nil
	cloningEnabled = nil
	if not item then
		recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", nil)
		return
	end
	if not (item.parameters.currentPets and item.parameters.currentPets[1] and item.parameters.currentPets[1].status)  then
		_ENV.productsScrollArea:clearChildren()
		_ENV.productsScrollArea:addChild({type = "label", color = "FFFF00", text = "Please activate pod at least once to refresh status.", align = "center"})
		return
	end
	cloningProducts = jarray()
	cloningEnabled = jarray()

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
				addProduct(cloningProducts, treasure)
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

	if #cloningProducts == 0 then
		world.sendEntityMessage(pane.sourceEntity(), "setCloningProducts", cloningProducts, cloningEnabled)
		recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", nil)
		return
	end

	table.sort(cloningProducts, function(a, b)
		return a.count > b.count
	end)

	for i, v in ipairs(cloningProducts) do
		cloningEnabled[i] = true
	end
	world.sendEntityMessage(pane.sourceEntity(), "setCloningProducts", cloningProducts, cloningEnabled)
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
	for i, v in ipairs(cloningProducts) do
		if cloningEnabled[i] then
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
			{ item = "wr/nutrient_paste", count = totalHealth + (recipeCost * cloningPriceMultiplier) + (itemCount * cloningCountMultiplier)}
		},
		output = products,
		duration = totalHealth
	}
	recipeRPC = world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
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

function _ENV.inputItemSlot:acceptsItem(item)
	if not root.monsterConfig then return false end
	return item and item.parameters and item.parameters.pets and item.parameters.pets[1] ~= nil
end

function countExcludedProducts()
	totalProducts = 0
	excludedProducts = 0
	for i, v in ipairs(cloningProducts) do
		totalProducts = totalProducts + v.count
		if not cloningEnabled[i] then
			excludedProducts = excludedProducts + v.count
		end
	end
end
