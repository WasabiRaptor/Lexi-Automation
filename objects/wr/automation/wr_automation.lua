require("/interface/games/util.lua")
require("/scripts/poly.lua")
require("/scripts/rect.lua")
require("/scripts/vec2.lua")
require("/scripts/util.lua")
wr_automation = {}

local stateAnimations
local isOffset
local matterStreamOutput
function wr_automation.init()
	stateAnimations = config.getParameter("stateAnimations") or {}
	matterStreamOutput = config.getParameter("matterStreamOutput")
	local position = object.position()
	local size = vec2.add(rect.size(poly.boundBox(object.spaces())), 1)
	isOffset = (position[2] % (size[2] * 2)) < size[2]
	wr_automation.setProducts(config.getParameter("products"))
	wr_automation.usePower(config.getParameter("powerConsumption"))
	wr_automation.producePower(config.getParameter("powerProduction"))
end
function wr_automation.countInputs(nodeIndex, recipe)
	local recipe = recipe or {matchInputParameters = true, input = {}}
	local inputNodes = object.getInputNodeIds(nodeIndex or 0)
	local inputs = {}
	local totalItems = 0
	local fromExporter = false
	local function sortInputs(a, b)
		if a.used == b.used then
			return (a.name or a.item) < (b.name or b.item)
		else
			return a.used
		end
	end
	for _, recipeItem in ipairs(recipe.input) do
		wr_automation.binaryInsert(inputs, sb.jsonMerge(recipeItem, {count = 0, used = true}), sortInputs)
	end
	for eid, index in pairs(inputNodes) do
		if world.entityExists(eid) then
			for i, newInput in ipairs((world.getObjectParameter(eid, "matterStreamOutput") or {})[index + 1] or {}) do
				fromExporter = fromExporter or world.getObjectParameter(eid, "fromExporter")
				newInput.count = newInput.count or 0
				totalItems = totalItems + newInput.count
				local isNew = true
				for j, input in ipairs(inputs) do
					if root.itemDescriptorsMatch(input, newInput, recipe.matchInputParameters) then
						isNew = false
						input.count = input.count + newInput.count
						break
					end
				end
				if isNew then
					newInput.used = false
					wr_automation.binaryInsert(inputs, newInput, sortInputs)
				end
			end
		end
	end
	return inputs, totalItems, fromExporter
end

function wr_automation.binaryInsert(t, v, comp)
	local upperBounds = #t + 1
	local lowerBounds = 1
	while true do
		if (upperBounds == lowerBounds) then
			table.insert(t, upperBounds, v)
			return
		end
		local index = math.floor((upperBounds - lowerBounds) / 2) + lowerBounds
		if comp(t[index], v) then
			lowerBounds = index + 1
		else
			upperBounds = index
		end
	end
end

function wr_automation.setOutputs(products, forceRefresh)
	local outputs = jarray()
	local outputNodes = {}
	local totalItems = 0
	local fromExporter = config.getParameter("fromExporter")
	for nodeIndex, nodeProducts in ipairs(products) do
		-- count the number of entities the output is connected to so it's split evenly between them
		local outputCount = 0
		local nodes = object.getOutputNodeIds(nodeIndex - 1)
		for eid, inputIndex in pairs(nodes) do
			local matterStreamReciever = world.getObjectParameter(eid, "matterStreamReciever")
			if matterStreamReciever and matterStreamReciever[inputIndex+1] then
				forceRefresh = forceRefresh or (fromExporter and not world.getObjectParameter(eid, "fromExporter"))
				outputCount = outputCount + 1
			else
				nodes[eid] = nil -- remove it from the table so we're not sending it a message later
			end
		end
		local output = jarray()
		for _, v in ipairs(nodeProducts) do
			local outputItem = copy(v)
			totalItems = totalItems + outputItem.count
			outputItem.count = outputItem.count / math.max(1, outputCount)
			if outputItem.count > 0 then
				table.insert(output, outputItem)
			end
		end
		outputs[nodeIndex] = output
		outputNodes[nodeIndex] = nodes
	end
	if (not forceRefresh) and compare(matterStreamOutput, outputs) then return outputs, totalItems end
	matterStreamOutput = outputs
	object.setConfigParameter("matterStreamOutput", outputs)
	for nodeIndex, nodes in ipairs(outputNodes) do
		object.setOutputNodeLevel(nodeIndex-1, #outputs[nodeIndex] > 0)
		for eid, _ in pairs(nodes) do
			world.sendEntityMessage(eid, "refreshInputs")
		end
	end
	return outputs, totalItems
end

function wr_automation.clearAllOutputs()
	object.setConfigParameter("matterStreamOutput", nil)
	if matterStreamOutput then
		for nodeIndex, nodeProducts in ipairs(matterStreamOutput) do
			object.setOutputNodeLevel(nodeIndex - 1, false)
		end
		matterStreamOutput = nil
	end
end

function wr_automation.playAnimations(state)
	local animationData = (isOffset and stateAnimations[state.."_offset"]) or stateAnimations[state]
	if not animationData then return end
	for k, v in pairs(animationData.animations or {}) do
		animator.setAnimationState(k, table.unpack(v))
	end
	for k, v in pairs(animationData.lights or {}) do
		animator.setLightActive(k,v)
	end
	for k, v in pairs(animationData.lightColors or {}) do
		animator.setLightColor(k,v)
	end
	for k, v in pairs(animationData.particleEmitters or {}) do
		animator.setParticleEmitterActive(k,v)
	end
end

function wr_automation.checkPowered()
	return world.getProperty("wr_powerStorageAvailable") or ((config.getParameter("powerConsumption") or 0) == 0) or ((world.getProperty("wr_powerProduction") or 0) >= (world.getProperty("wr_powerConsumption") or 0))
end

function wr_automation.usePower(powerConsumption)
	local resetTime = world.getProperty("wr_productionResetTime")
	local reportedTime = config.getParameter("powerConsumedTime")
	local powerConsumed = config.getParameter("powerConsumption") or 0
	if (not reportedTime) or (resetTime and (resetTime > reportedTime)) then
		powerConsumed = 0
	end

	local powerChanged = (powerConsumption or 0) - powerConsumed
	if powerChanged == 0 then return end
	local globalPowerConsumption = world.getProperty("wr_powerConsumption") or 0
	object.setConfigParameter("powerConsumption", powerConsumption)
	object.setConfigParameter("powerConsumedTime", world.time())
	world.setProperty("wr_powerConsumption", math.max(0,globalPowerConsumption + powerChanged))
end

function wr_automation.producePower(powerProduction)
	local resetTime = world.getProperty("wr_productionResetTime")
	local reportedTime = config.getParameter("powerProducedTime")
	local powerProduced = config.getParameter("powerProduction") or 0
	if (not reportedTime) or (resetTime and (resetTime > reportedTime)) then
		powerProduced = 0
	end

	local powerChanged = (powerProduction or 0) - powerProduced
	if powerChanged == 0 then return end
	local globalPowerProduction = world.getProperty("wr_powerProduction") or 0
	object.setConfigParameter("powerProduction", powerProduction)
	object.setConfigParameter("powerProducedTime", world.time())
	world.setProperty("wr_powerProduction", math.max(0,globalPowerProduction + powerChanged))
end

function wr_automation.addPowerStorage(powerStorage)
	local resetTime = world.getProperty("wr_productionResetTime")
	local reportedTime = config.getParameter("powerStorageTime")
	local powerStored = config.getParameter("powerStorage") or 0
	if (not reportedTime) or (resetTime and (resetTime > reportedTime)) then
		powerStored = 0
	end

	local powerChanged = (powerStorage or 0) - powerStored
	if powerChanged == 0 then return end
	local globalPowerStorage = world.getProperty("wr_powerStorage") or 0
	object.setConfigParameter("powerStorage", powerStorage)
	object.setConfigParameter("powerStorageTime", world.time())
	world.setProperty("wr_powerStorage", math.max(0,globalPowerStorage + powerChanged))
end

function wr_automation.setProducts(products)
	local oldProducts = config.getParameter("products")
	local resetTime = world.getProperty("wr_productionResetTime")
	local reportedTime = config.getParameter("productsReportedTime")
	if (not reportedTime) or (resetTime and (resetTime > reportedTime)) then
		oldProducts = nil
	end
	if compare(oldProducts, products) then return end

	object.setConfigParameter("productsReportedTime", world.time())
	object.setConfigParameter("products", products)

	local productsChanged = {}
	for node, items in ipairs(oldProducts or {}) do
		for _, item in ipairs(items) do
			local found = false
			for _, changedItem in ipairs(productsChanged) do
				if root.itemDescriptorsMatch(item, changedItem, true) then
					found = true
					changedItem.count = changedItem.count - item.count
					break
				end
			end
			if not found then
				local changedItem = copy(item)
				changedItem.count = -item.count
				table.insert(productsChanged, changedItem)
			end
		end
	end
	for node, items in ipairs(products or {}) do
		for _, item in ipairs(items) do
			local found = false
			for _, changedItem in ipairs(productsChanged) do
				if root.itemDescriptorsMatch(item, changedItem, true) then
					found = true
					changedItem.count = changedItem.count + item.count
					break
				end
			end
			if not found then
				table.insert(productsChanged, copy(item))
			end
		end
	end
	local productKeys = world.getProperty("wr_productKeys") or {}
	local productKeysUpdated = false
	for _, changedItem in ipairs(productsChanged) do
		if changedItem.count ~= 0 then
			local itemConfig = root.itemConfig(changedItem)
			local mergedConfig = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
			-- we want to take parameters into account for differentiating variations of items, however iterating over a list to find a unique matching entry might take too long
			-- instead we make an assumption based on if the shortdescription for variations to be good enough to differentiate different products for the production report
			local productKey = (changedItem.name or changedItem.item).."."..mergedConfig.shortdescription or (input.name or input.item)
			local producing = math.max(0,(world.getProperty("wr_productProduced."..productKey) or 0) + changedItem.count)
			local exampleProduct = world.getProperty("wr_product."..productKey)

			world.setProperty("wr_productProduced."..productKey, producing)
			if producing == 0 then
				world.setProperty("wr_product."..productKey, nil)
			else
				if not productKeys[productKey] then
					productKeysUpdated = true
					productKeys[productKey] = true
				end
				if not exampleProduct then
					world.setProperty("wr_product."..productKey, changedItem)
				end
			end
		end
	end
	if productKeysUpdated then
		-- this only sends update packets if the value actually changed, and while it will get larger for each new product, it only needs to update once for each new product added
		-- and its better to only attempt to set it if we actually updated it
		world.setProperty("wr_productKeys", productKeys)
	end
end
