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
			world.setProperty("wr_matterStreamInputUUID."..channel, nil)
			world.setProperty("wr_matterStreamOutput." .. channel, nil)
			local outputUUID = world.getProperty("wr_matterStreamOutputUUID."..channel)
			if outputUUID then
				world.sendEntityMessage(outputUUID,"refreshInputs")
			end
		end
		channel = newChannel
		object.setConfigParameter("channel", channel)
		world.setProperty("wr_matterStreamInputUUID."..channel, entity.uniqueId())
		refreshOutput(true)
	end)
	if inputs and (not config.getParameter("fromExporter")) and object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
		animator.setAnimationState("input", "on", true)
	end

end

function update(dt)

end

function uninit()

end
function die()
	if channel == "" then return end
	world.setProperty("wr_matterStreamInputUUID."..channel, nil)
	world.setProperty("wr_matterStreamOutput."..channel, nil)
	local outputUUID = world.getProperty("wr_matterStreamOutputUUID."..channel)
	if outputUUID then
		world.sendEntityMessage(outputUUID,"refreshInputs")
	end
end
function refreshOutput(force)
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) or (channel == "") then
		inputs = nil
		object.setConfigParameter("matterStreamInput", nil)
		animator.setAnimationState("input", "off")
		return
	end
	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0)
	animator.setAnimationState("input", fromExporter and "off" or "on", true)
	if (not force) and (fromExporter == config.getParameter("fromExporter")) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	if fromExporter then
		world.setProperty("wr_matterStreamOutput."..channel, nil)
	else
		world.setProperty("wr_matterStreamOutput."..channel, newInputs)
	end

	local outputUUID = world.getProperty("wr_matterStreamOutputUUID."..channel)
	if outputUUID then
		world.sendEntityMessage(outputUUID,"refreshInputs")
	end
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
