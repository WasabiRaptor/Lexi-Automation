require("/objects/wr/automation/wr_automation.lua")

local outputCount
local inputs
local powered
function init()
	wr_automation.init()
	inputs = (config.getParameter("matterStreamInput") or {})[1]
	message.setHandler("refreshInputs", function (_,_,force)
		refreshOutput(force)
	end)
	powered =  wr_automation.checkPowered(config.getParameter("activePowerConsumption"))
	if object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
		animator.setAnimationState("input", powered and "on" or "off", true)
	end
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
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		wr_automation.addWasteRadiation(config.getParameter("idleWasteRadiaton"))
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		object.setConfigParameter("matterStreamInput", nil)
		wr_automation.clearAllOutputs()
		animator.setAnimationState("input", "off")
		inputs = nil
		powered = newPowered
		return
	end
	animator.setAnimationState("input", newPowered and "on" or "off", true)
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0)
	if (not force) and (powered == newPowered) and (fromExporter == config.getParameter("fromExporter")) and (newOutputCount == outputCount) and compare(newInputs, inputs) then return end
	wr_automation.usePower(activePowerConsumption)
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	outputCount = newOutputCount
	powered = newPowered
	local outputs, totalItems = wr_automation.setOutputs({inputs})
	wr_automation.addWasteRadiation((outputCount == 0 and totalItems or 0) + (config.getParameter("activeWasteRadiation") or 0))
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
