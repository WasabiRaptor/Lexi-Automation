require("/objects/wr/automation/wr_automation.lua")

local inputs
local channel
local outputTarget
local powered
function init()
	wr_automation.init()
	if not entity.uniqueId() then
		object.setUniqueId(sb.makeUuid())
	end
	object.setInteractive(true)
	inputs = (config.getParameter("matterStreamInput") or {})[1]
	channel = config.getParameter("channel") or ""
	outputTarget = config.getParameter("outputTarget")
	selfTarget = config.getParameter("selfTarget")

	message.setHandler("refreshInputs", function (_,_, force)
		world.setExpiryTime(math.max(5,world.expiryTime()))
		refreshOutput(force)
	end)
	message.setHandler("refreshOutput", function(_, _, targetEntity)
		world.setExpiryTime(math.max(5,world.expiryTime()))
		outputTarget = targetEntity
		object.setConfigParameter("outputTarget", outputTarget)
		refreshOutput(true)
	end)
	message.setHandler("setChannel", function(_, _, newChannel, targetEntity, newSelfTarget)
		world.setExpiryTime(math.max(5,world.expiryTime()))
		if (newChannel == channel) and compare(targetEntity, outputTarget) then return end
		if outputTarget then
			world.callScriptContext("wr_automation", "refreshInputs", outputTarget)
		end
		channel = newChannel
		outputTarget = targetEntity
		selfTarget = newSelfTarget
		object.setConfigParameter("outputTarget", outputTarget)
		object.setConfigParameter("channel", channel)
		object.setConfigParameter("selfTarget", selfTarget)
		refreshOutput(true)
	end)
	message.setHandler("remove", function (_,_)
		object.smash()
	end)
	powered = wr_automation.checkPowered(config.getParameter("activePowerConsumption"))
	if inputs and powered and (not config.getParameter("fromExporter")) and object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
		animator.setAnimationState("input", "on", true)
	end

end

function update(dt)

end

function uninit()

end
function onInteraction(request)
	if request.sourceId then
		if world.entityUniqueId(request.sourceId) ~= config.getParameter("owner") then
			return {}
		end
	end
	return {"ScriptPane", { gui = { }, scripts = {"/metagui.lua"}, ui = "wr_automation:universal_relay", data = {channelProperty = "input", supported = world.callScriptContext ~= nil} }}
end

function die()
	wr_automation.usePower(0)
end
function refreshOutput(force)
	local activePowerConsumption = config.getParameter("activePowerConsumption")
	local newPowered = wr_automation.checkPowered(activePowerConsumption)
	if (not powered) or (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) or (channel == "") then
		powered = newPowered
		inputs = nil
		wr_automation.addWasteRadiation(config.getParameter("idleWasteRadiaton"))
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		object.setConfigParameter("matterStreamInput", nil)
		animator.setAnimationState("input", "off")
		if outputTarget and selfTarget then
			world.callScriptContext("wr_automation", "refreshInputs", outputTarget, force, inputs, selfTarget)
		end
		return
	end
	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0)
	animator.setAnimationState("input", fromExporter and "off" or "on", true)
	if (not force) and (powered == newPowered) and (fromExporter == config.getParameter("fromExporter")) and compare(newInputs, inputs) then return end
	wr_automation.usePower(activePowerConsumption)
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	powered = newPowered
	if fromExporter then
		if outputTarget and selfTarget then
			world.callScriptContext("wr_automation", "refreshInputs", outputTarget, force, false, selfTarget)
		end
	else
		if outputTarget and selfTarget then
			world.callScriptContext("wr_automation", "refreshInputs", outputTarget, force, inputs, selfTarget)
		end
	end
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
