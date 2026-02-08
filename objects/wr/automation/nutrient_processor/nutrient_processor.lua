require("/objects/wr/automation/wr_automation.lua")
local old = {
	init = init or function() end,
	onNodeConnectionChange = onNodeConnectionChange or function() end,
	onInputNodeChange = onInputNodeChange or function() end
}

local outputCount
local inputs
function init()
	old.init()
	wr_automation.init()
	inputs = config.getParameter("matterStreamInput")
	message.setHandler("refreshInputs", function (_,_)
		refreshOutput()
	end)
end


function refreshOutput(force)
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		object.setConfigParameter("products", nil)
		object.setConfigParameter("matterStreamOutput", nil)
		object.setConfigParameter("matterStreamInput", nil)
		object.setOutputNodeLevel(0, false)
		inputs = nil
		object.setConfigParameter("status", "missingInput")
		return
	end
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	local newInputs, totalItems = wr_automation.countInputs(0)
	if (not force) and (newOutputCount == outputCount) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", newInputs)
	inputs = newInputs
	outputCount = newOutputCount

	local craftingSpeed = config.getParameter("craftingSpeed") or 1

	if totalItems > craftingSpeed then
		-- too many items being input clogs the machine
		object.setConfigParameter("status", "tooMany")
		object.setConfigParameter("matterStreamOutput", nil)
		object.setOutputNodeLevel(0, false)
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
			object.setConfigParameter("matterStreamOutput", nil)
			object.setOutputNodeLevel(0, false)
			return
		end
	end
	if nutrientValue > 0 then
		object.setConfigParameter("status", "on")
	else
		object.setConfigParameter("status", "missingInput")
		object.setConfigParameter("matterStreamOutput", nil)
		object.setOutputNodeLevel(0, false)
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
