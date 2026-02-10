require("/interface/games/util.lua")
require("/scripts/poly.lua")
require("/scripts/rect.lua")
require("/scripts/vec2.lua")
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
end
function wr_automation.countInputs(nodeIndex, recipe)
	local recipe = recipe or {matchInputParameters = true, input = {}}
	local inputNodes = object.getInputNodeIds(nodeIndex or 0)
	local inputs = {}
	local totalItems = 0
	local fromExporter = false
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

	return inputs, totalItems, fromExporter
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
end
