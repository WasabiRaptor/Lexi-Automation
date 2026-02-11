require("/objects/wr/automation/wr_automation.lua")

local outputs
local exportEntity
local objectPosition
local delta
local efficency
function init()
	wr_automation.init()
	objectPosition = object.position()
	outputs = config.getParameter("targetOutput")
	delta = math.max(config.getParameter("scriptDelta") or 0, 60)
	efficency = config.getParameter("efficency")

	message.setHandler("setTargetOutputs", function(_, _, newOutputs)
		setOutputs(newOutputs)
		refreshOutput()
	end)

	storage.leftovers = storage.leftovers or {}

	if not outputs then
		script.setUpdateDelta(0)
	else
		script.setUpdateDelta(delta)
	end
	wr_automation.clearAllOutputs()
end

local isOutputting
function update(dt)
	if not loaded then
		loaded = world.regionActive({objectPosition[1]-3,objectPosition[2]-3,objectPosition[1]+3,objectPosition[2]+3})
		if not loaded then return end
	end
	if (not object.isOutputNodeConnected(0)) or (not outputs) then
		script.setUpdateDelta(0)
		wr_automation.clearAllOutputs()
		return
	end
	if (not exportEntity) or (not world.entityExists(exportEntity)) then
		local position = object.position()
		exportEntity = world.objectAt({ position[1], position[2] -1 })
	end
	if not exportEntity then
		object.setOutputNodeLevel(0, false)
		animator.setAnimationState("output", "off")
		wr_automation.clearAllOutputs()
		return
	end

	local toConsume = {}
	local canConsume = true
	for i, output in ipairs(outputs) do
		local consume = copy(output)
		consume.totalAmount = ((consume.count / efficency) * dt) - (storage.leftovers[i] or 0)
		consume.count = math.ceil(consume.totalAmount)
		local available = world.containerAvailable(exportEntity, consume)
		if (available > 0) or (consume.count <= 0) then
			-- check if we can consume the desired amount of items or not
			if consume.count > 0 then
				table.insert(toConsume, consume)
			end
		else
			canConsume = false
			break
		end
	end
	if canConsume then
		animator.setAnimationState("output", "output", true)
		for i, consume in ipairs(toConsume) do
			if world.containerConsume(exportEntity, consume) then
				storage.leftovers[i] = consume.count - consume.totalAmount
			end
		end
		if not isOutputting then
			isOutputting = true
			wr_automation.setOutputs({outputs})
		end
	else
		animator.setAnimationState("output", "on")
		isOutputting = false
		wr_automation.clearAllOutputs()
	end
end

function uninit()
	wr_automation.clearAllOutputs() -- when unloaded it can't consume items to clear the outputs
end

function onInputNodeChange()
	refreshOutput()
end

function onNodeConnectionChange()
	refreshOutput()
end

function refreshOutput()
	if not object.isOutputNodeConnected(0) then
		script.setUpdateDelta(0)
		return
	end
	if object.isInputNodeConnected(0) then
		if object.getInputNodeLevel(0) then
			if isOutputting then
				wr_automation.setOutputs({ outputs })
			end
			script.setUpdateDelta(delta)
		else
			animator.setAnimationState("output", "off")
			isOutputting = false
			wr_automation.clearAllOutputs()
			script.setUpdateDelta(0)
		end
	else
		if isOutputting then
			wr_automation.setOutputs({ outputs })
		end
		script.setUpdateDelta(delta)
	end
end

function setOutputs(newOutputs)
	outputs = newOutputs
	if not outputs then
		script.setUpdateDelta(0)
		return
	end
	object.setConfigParameter("targetOutput", outputs)
	best = 0
	for i, input in ipairs(outputs) do
		storage.leftovers[i] = 0
		if input.count > best then
			best = input.count
		end
	end
	-- exporters will never tick faster than once per second
	delta = math.max(1 / best, 1) * 60
	script.setUpdateDelta(delta)
	object.setConfigParameter("scriptDelta", delta)
end
