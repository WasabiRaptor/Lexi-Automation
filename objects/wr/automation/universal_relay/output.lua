require("/objects/wr/automation/wr_automation.lua")

local outputCount
local inputs
local channel
local inputTarget
function init()
	wr_automation.init()
	if not entity.uniqueId() then
		object.setUniqueId(sb.makeUuid())
	end
	object.setInteractive(true)
	inputs = config.getParameter("matterStreamInput")
	channel = config.getParameter("channel") or ""
	inputTarget = config.getParameter("inputTarget")
	selfTarget = config.getParameter("selfTarget")

	message.setHandler("refreshInputs", function(_, _, force, newInputs, targetEntity)
		world.setExpiryTime(math.max(5,world.expiryTime()))
		inputTarget = targetEntity
		object.setConfigParameter("inputTarget", inputTarget)
		refreshOutput(force, newInputs)
	end)
	message.setHandler("setChannel", function(_, _, newChannel, targetEntity, newSelfTarget)
		world.setExpiryTime(math.max(5,world.expiryTime()))
		if (newChannel == channel) and compare(targetEntity, inputTarget) then return end
		if inputTarget then
			world.callScriptContext("wr_automation", "refreshOutput", inputTarget)
		end
		channel = newChannel
		inputTarget = targetEntity
		selfTarget = newSelfTarget
		object.setConfigParameter("inputTarget", inputTarget)
		object.setConfigParameter("selfTarget", selfTarget)
		object.setConfigParameter("channel", channel)
		if inputTarget and selfTarget then
			world.callScriptContext("wr_automation", "refreshOutput", inputTarget, selfTarget)
		end
		refreshOutput(true)
	end)
	message.setHandler("remove", function (_,_)
		object.smash()
	end)
	if inputs and (#inputs > 0) then
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
	return {"ScriptPane", { gui = { }, scripts = {"/metagui.lua"}, ui = "wr_automation:universal_relay", data = {channelProperty = "output", supported = world.callScriptContext ~= nil} }}
end
function die()
end

function refreshOutput(force, newInputs)
	if (not inputTarget) or (not newInputs) or (channel == "") then
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
	refreshOutput(false, inputs)
end
function onNodeConnectionChange()
	refreshOutput(false, inputs)
end
