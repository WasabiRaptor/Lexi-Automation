require("/objects/wr/automation/wr_automation.lua")

local outputCount
local inputs
local channel
function init()
	if not entity.uniqueId() then
		object.setUniqueId(sb.makeUuid())
	end

	script.setUpdateDelta(0)
	inputs = config.getParameter("matterStreamInput")
	channel = config.getParameter("channel") or ""
	message.setHandler("refreshInputs", function (_,_)
		refreshOutput()
	end)
	message.setHandler("setChannel", function(_, _, newChannel)
		if newChannel == channel then return end
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
	if channel == "" then return end
	world.setProperty("wr_matterStreamOutput."..channel, nil)
end
function refreshOutput(force)
	local inputUUID = world.getProperty("wr_matterStreamInputUUID."..channel)
	local newInputs = world.getProperty("wr_matterStreamOutput."..channel)

	if (not inputUUID) or (not newInputs) or (channel == "") then
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
	if (not force) and compare(newInputs, inputs) and (newOutputCount == outputCount) then return end
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
