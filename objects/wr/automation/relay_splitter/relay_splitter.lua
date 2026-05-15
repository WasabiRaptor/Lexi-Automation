require("/objects/wr/automation/wr_automation.lua")

local leftOutputCount
local rightOutputCount
local defaultOutputCount
local inputs
local leftTargetOutput
local rightTargetOutput
local outputs, totalItems, nodeItemCounts
local leftState
local rightState
local prevLeftNodeValue
local prevRightNodeValue
local anyTargetOutput = jarray()
local powered
function init()
	wr_automation.init()
	inputs = (config.getParameter("matterStreamInput") or {})[1]
	outputs = config.getParameter("matterStreamOutput")
	leftTargetOutput = config.getParameter("leftTargetOutput") or jarray()
	rightTargetOutput = config.getParameter("rightTargetOutput") or jarray()
	util.appendLists(anyTargetOutput, leftTargetOutput)
	local function appendRightTargetOutput()
		for i, newItem in ipairs(rightTargetOutput) do
			local isNew = true
			for j, input in ipairs(inputs) do
				if root.itemDescriptorsMatch(input, newItem, recipe.matchInputParameters) then isNew = false break end
			end
			if isNew then table.insert(anyTargetOutput, newItem) end
		end
	end

	message.setHandler("refreshInputs", function (_,_,force)
		refreshOutput(force)
	end)
	message.setHandler("setTargetOutputs", function(_, _, left, right)
		local forceRefresh = false
		if not compare(left, leftTargetOutput) then
			object.setConfigParameter("leftTargetOutput", left)
			leftTargetOutput = left
			forceRefresh = true
		end
		if not compare(right, rightTargetOutput) then
			object.setConfigParameter("rightTargetOutput", right)
			rightTargetOutput = right
			forceRefresh = true
		end
		if not forceRefresh then return end
		anyTargetOutput = jarray()
		util.appendLists(anyTargetOutput, leftTargetOutput)
		appendRightTargetOutput()
		refreshOutput(forceRefresh)
	end)
	leftState = (object.direction() == 1) and "left" or "right"
	rightState = (object.direction() == 1) and "right" or "left"
	prevLeftNodeValue = object.getInputNodeLevel(1)
	prevRightNodeValue = object.getInputNodeLevel(2)
	powered = wr_automation.checkPowered(config.getParameter("activePowerConsumption"))
	if object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
		animator.setAnimationState("input", powered and "on" or "off", true)
		if outputs then
			animator.setAnimationState("center", powered and (#outputs[1] > 0) and "on" or "off", true)
			animator.setAnimationState(leftState, powered and (#outputs[2] > 0) and "on" or "off", true)
			animator.setAnimationState(rightState, powered and (#outputs[3] > 0) and "on" or "off", true)
		end
	end
	animator.setAnimationState(leftState.."Logic", (prevLeftNodeValue) and "on" or "off")
	animator.setAnimationState(rightState.."Logic", (prevRightNodeValue) and "on" or "off")
end

function update(dt)

end

function uninit()

end
function die()
	wr_automation.usePower(0)
end
function refreshOutput(force)
	local activePowerConsumption = config.getParameter("activePowerConsumption")
	local newPowered = wr_automation.checkPowered(activePowerConsumption)
	local leftNodeValue = object.getInputNodeLevel(1) or not object.isInputNodeConnected(1)
	local rightNodeValue = object.getInputNodeLevel(2) or not object.isInputNodeConnected(2)

	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		wr_automation.addWasteRadiation(config.getParameter("idleWasteRadiaton"))
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		object.setConfigParameter("matterStreamInput", nil)
		wr_automation.clearAllOutputs()
		animator.setAnimationState("input", "off")
		animator.setAnimationState("center", "off")
		animator.setAnimationState("left", "off")
		animator.setAnimationState("right", "off")
		inputs = nil
		powered = newPowered
		return
	end
	animator.setAnimationState("input", powered and "on" or "off", true)

	local leftOutputNodes = object.getOutputNodeIds(1)
	local newLeftOutputCount = 0
	for _, _ in pairs(leftOutputNodes) do
		newLeftOutputCount = newLeftOutputCount + 1
	end
	local rightOutputNodes = object.getOutputNodeIds(2)
	local newRightOutputCount = 0
	for _, _ in pairs(rightOutputNodes) do
		newRightOutputCount = newRightOutputCount + 1
	end
	local defaultOutputNodes = object.getOutputNodeIds(0)
	local newDefaultOutputCount = 0
	for _, _ in pairs(defaultOutputNodes) do
		newDefaultOutputCount = newDefaultOutputCount + 1
	end

	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0, {input = anyTargetOutput, matchInputParameters = true})
	if (not force)
		and (powered == newPowered)
		and (fromExporter == config.getParameter("fromExporter"))
		and (newDefaultOutputCount == defaultOutputCount)
		and (newLeftOutputCount == leftOutputCount)
		and (newRightOutputCount == rightOutputCount)
		and (leftNodeValue == prevLeftNodeValue)
		and (rightNodeValue == prevRightNodeValue)
		and compare(newInputs, inputs)
	then
		return
	end
	wr_automation.usePower(activePowerConsumption)
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	leftOutputCount = newLeftOutputCount
	rightOutputCount = newRightOutputCount
	defaultOutputCount = newDefaultOutputCount
	prevLeftNodeValue = leftNodeValue
	prevRightNodeValue = rightNodeValue
	powered = newPowered

	local defaultOutput = copy(inputs)

	local leftOutput = jarray()
	if leftNodeValue then
		for _, targetOutput in ipairs(leftTargetOutput) do
			for _, defaultOutputItem in ipairs(defaultOutput) do
				if root.itemDescriptorsMatch(targetOutput, defaultOutputItem, true) then
					local outputItem = copy(targetOutput)
					if targetOutput.count > defaultOutputItem.count then
						outputItem.count = defaultOutputItem.count
						defaultOutputItem.count = 0
					else
						defaultOutputItem.count = defaultOutputItem.count - targetOutput.count
					end
					if outputItem.count > 0 then
						table.insert(leftOutput, outputItem)
					end
					break
				end
			end
		end
	end
	local rightOutput = jarray()
	if rightNodeValue then
		for _, targetOutput in ipairs(rightTargetOutput) do
			for _, defaultOutputItem in ipairs(defaultOutput) do
				if root.itemDescriptorsMatch(targetOutput, defaultOutputItem, true) then
					local outputItem = copy(targetOutput)
					if targetOutput.count > defaultOutputItem.count then
						outputItem.count = defaultOutputItem.count
						defaultOutputItem.count = 0
					else
						defaultOutputItem.count = defaultOutputItem.count - targetOutput.count
					end
					if outputItem.count > 0 then
						table.insert(rightOutput, outputItem)
					end
					break
				end
			end
		end
	end
	outputs, totalItems, nodeItemCounts = wr_automation.setOutputs({defaultOutput, leftOutput, rightOutput})
	animator.setAnimationState("center", powered and (#outputs[1] > 0) and "on" or "off")
	animator.setAnimationState(leftState, powered and (#outputs[2] > 0) and "on" or "off")
	animator.setAnimationState(rightState, powered and (#outputs[3] > 0) and "on" or "off")
	animator.setAnimationState(leftState.."Logic", (leftNodeValue) and "on" or "off")
	animator.setAnimationState(rightState.."Logic", (rightNodeValue) and "on" or "off")
	wr_automation.addWasteRadiation(
		(config.getParameter("activeWasteRadiation") or 0)
		+ (defaultOutputCount == 0 and nodeItemCounts[1] or 0)
		+ (leftOutputCount == 0 and nodeItemCounts[2] or 0)
		+ (rightOutputCount == 0 and nodeItemCounts[3] or 0)
	)
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
