require("/objects/wr/automation/wr_automation.lua")

local inputs
local channel
local outputTarget
function init()
	wr_automation.init()
	if not entity.uniqueId() then
		object.setUniqueId(sb.makeUuid())
	end
	object.setInteractive(true)
	inputs = config.getParameter("matterStreamInput")
    channel = config.getParameter("channel") or ""
	outputTarget = config.getParameter("outputTarget")
	selfTarget = config.getParameter("selfTarget")

	message.setHandler("refreshInputs", function (_,_, force)
		world.setExpiryTime(math.max(5,world.expiryTime()))
		refreshOutput(force)
	end)
	message.setHandler("refreshOutput", function(_, _, targetEntity)
		world.setExpiryTime(math.max(5,world.expiryTime()))
		if compare(targetEntity, outputTarget) then return end
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
	if object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
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
end
function refreshOutput(force)
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) or (channel == "") then
		inputs = nil
		object.setConfigParameter("matterStreamInput", nil)
		animator.setAnimationState("input", "off")
		if outputTarget and selfTarget then
			world.callScriptContext("wr_automation", "refreshInputs", outputTarget, force, inputs, selfTarget)
		end
		return
	end
	animator.setAnimationState("input", "on", true)
	local newInputs = wr_automation.countInputs()
	if (not force) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", newInputs)
    inputs = newInputs
	if outputTarget and selfTarget then
		world.callScriptContext("wr_automation", "refreshInputs", outputTarget, force, inputs, selfTarget)
	end
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
