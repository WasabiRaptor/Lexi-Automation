require("/objects/wr/automation/wr_automation.lua")

local outputCount
local inputs
function init()
	wr_automation.init()
	inputs = config.getParameter("matterStreamInput")
	message.setHandler("refreshInputs", function (_,_)
		refreshOutput()
	end)
	if object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
		animator.setAnimationState("input", "on", true)
	end
end

function update(dt)

end

function uninit()

end
function refreshOutput(force)
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		object.setConfigParameter("matterStreamOutput", nil)
		object.setConfigParameter("matterStreamInput", nil)
		object.setOutputNodeLevel(0, false)
		animator.setAnimationState("input", "off")
		inputs = nil
		return
	end
	animator.setAnimationState("input", "on", true)
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	local newInputs = wr_automation.countInputs()
	if (not force) and (newOutputCount == outputCount) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", newInputs)
	inputs = newInputs
	outputCount = newOutputCount
	wr_automation.setOutputs({inputs})
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
