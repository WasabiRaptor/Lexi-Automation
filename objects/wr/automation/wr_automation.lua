require("/interface/games/util.lua")
wr_automation = {}
function wr_automation.countInputs(nodeIndex, recipe)
	local recipe = recipe or {matchInputParameters = true, input = {}}
	local inputNodes = object.getInputNodeIds(nodeIndex or 0)
	local inputs = {}
	local totalItems = 0
	for eid, index in pairs(inputNodes) do
		if world.entityExists(eid) then
			for i, newInput in ipairs((world.getObjectParameter(eid, "matterStreamOutput") or {})[index + 1] or {}) do
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
					for _, input in ipairs(recipe.input) do
						if root.itemDescriptorsMatch(input, newInput, recipe.matchInputParameters) then
							newInput.used = true
							break
						end
					end
					table.insert(inputs, newInput)
				end
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
			return (a.name or a.item) < (b.name or b.item)
		else
			return a.used
		end
	end)

	return inputs, totalItems
end

function wr_automation.setOutputs(products)
	local outputs = jarray()
	local outputNodes = {}
	local totalItems = 0
	for nodeIndex, nodeProducts in ipairs(products) do
		-- count the number of entities the output is connected to so it's split evenly between them
		local outputCount = 0
		local nodes = object.getOutputNodeIds(nodeIndex - 1)
		for _, _ in pairs(nodes) do
			outputCount = outputCount + 1
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
	if compare(config.getParameter("matterStreamOutput"), outputs) then return outputs end
	object.setConfigParameter("matterStreamOutput", outputs)
	for nodeIndex, nodes in ipairs(outputNodes) do
		object.setOutputNodeLevel(nodeIndex-1, #outputs[nodeIndex] > 0)
		for eid, _ in pairs(nodes) do
			world.sendEntityMessage(eid, "refreshInputs")
		end
	end
	return outputs, totalItems
end
