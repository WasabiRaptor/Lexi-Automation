require("/objects/wr/automation/wr_automation.lua")
local old = {
	init = init or function() end,
	onNodeConnectionChange = onNodeConnectionChange or function() end,
	onInputNodeChange = onInputNodeChange or function() end
}

local outputCount
local inputs
local exporter
function init()
	old.init()
	wr_automation.init()
	inputs = (config.getParameter("matterStreamInput") or {})[1]
	message.setHandler("refreshInputs", function (_,_, force)
		refreshOutput(force)
	end)
end


function refreshOutput(force)
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		object.setConfigParameter("products", nil)
		object.setConfigParameter("matterStreamInput", nil)
		wr_automation.clearAllOutputs()
		inputs = nil
		object.setConfigParameter("status", "missingInput")
		return
	end
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0)
	if (not force) and (fromExporter == config.getParameter("fromExporter")) and (newOutputCount == outputCount) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	outputCount = newOutputCount
	exporter = fromExporter

	local craftingSpeed = config.getParameter("craftingSpeed") or 1

	if totalItems > craftingSpeed then
		-- too many items being input clogs the machine
		object.setConfigParameter("status", "tooMany")
		wr_automation.clearAllOutputs()
		return
	end
	local nutrientValue = 0
	for _, input in ipairs(inputs) do
		local itemConfig = root.itemConfig(input)
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		if merged.foodValue and merged.foodValue > 0 then
			nutrientValue = nutrientValue + (merged.foodValue * input.count)
		else
			-- an item input wasn't food and clogs the machine
			object.setConfigParameter("status", "badInput")
			wr_automation.clearAllOutputs()
			return
		end
	end
	if nutrientValue > 0 then
		object.setConfigParameter("status", "on")
	else
		object.setConfigParameter("status", "missingInput")
		wr_automation.clearAllOutputs()
		return
	end
	local product = {
		item = "wr/nutrient_paste",
		count = nutrientValue
	}
	object.setConfigParameter("products", {{product}})
	wr_automation.setOutputs({{product}})
end


function onInputNodeChange(...)
	old.onInputNodeChange(...)
	refreshOutput()
end
function onNodeConnectionChange(...)
	old.onNodeConnectionChange(...)
	refreshOutput()
end
