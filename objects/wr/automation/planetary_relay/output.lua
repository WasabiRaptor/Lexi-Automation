require("/objects/wr/automation/wr_automation.lua")

local outputCount
local inputs
local channel
function init()
	wr_automation.init()
	if not entity.uniqueId() then
		object.setUniqueId(sb.makeUuid())
	end

	inputs = (config.getParameter("matterStreamInput") or {})[1]
	channel = config.getParameter("channel") or ""
	message.setHandler("refreshInputs", function (_,_, force)
		refreshOutput(force)
	end)
	message.setHandler("setChannel", function(_, _, newChannel)
		if newChannel == channel then return end
		if channel ~= "" then
			world.setProperty("wr_matterStreamOutputUUID."..channel, nil)
		end
		channel = newChannel
		object.setConfigParameter("channel", channel)
		world.setProperty("wr_matterStreamOutputUUID."..channel, entity.uniqueId())
		refreshOutput(true)
	end)
	if inputs and (#inputs > 0) then
		animator.setAnimationState("input", "on", true)
	end
end

function update(dt)

end

function uninit()

end
function die()
	wr_automation.usePower(0)
	if channel == "" then return end
	world.setProperty("wr_matterStreamOutput."..channel, nil)
	world.setProperty("wr_matterStreamOutputUUID."..channel, nil)
end
function refreshOutput(force)
	local inputUUID = world.getProperty("wr_matterStreamInputUUID."..channel)
	local newInputs = world.getProperty("wr_matterStreamOutput."..channel)

	if (not inputUUID) or (not newInputs) or (channel == "") then
		wr_automation.addWasteRadiation(config.getParameter("idleWasteRadiaton"))
		object.setConfigParameter("matterStreamInput", nil)
		wr_automation.clearAllOutputs()
		animator.setAnimationState("input", "off")
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		inputs = nil
		return
	end
	animator.setAnimationState("input", "on", true)
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	if (not force) and (newOutputCount == outputCount) and compare(newInputs, inputs) then return end
	wr_automation.usePower(config.getParameter("activePowerConsumption"))
	object.setConfigParameter("matterStreamInput", {newInputs})
	inputs = newInputs
	outputCount = newOutputCount
	local outputs, totalItems = wr_automation.setOutputs({inputs})
	wr_automation.addWasteRadiation((outputCount == 0 and totalItems or 0) + (config.getParameter("activeWasteRadiation") or 0))
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
