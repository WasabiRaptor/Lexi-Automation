require("/objects/wr/automation/wr_automation.lua")

local outputs
local exportEntity
local objectPosition
local delta
local efficency
local targetPosition
function init()
	wr_automation.init()
	objectPosition = object.position()
	targetPosition = vec2.add(objectPosition, config.getParameter("targetOffset"))
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
		exportEntity = world.objectAt(targetPosition)
	end
	if (not exportEntity) or (not wr_automation.checkPowered()) then
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
		-- check if we're actually consuming items this tick
		if consume.count > 0 then
			-- check if we can consume the desired amount of items or not
			local available
			if consume.slot then
				local containerItem = world.containerItemAt(exportEntity, consume.slot)
				if root.itemDescriptorsMatch(consume, containerItem, true) then
					available = math.floor(containerItem.count/consume.count)
				else
					available = 0
				end
			else
				available = world.containerAvailable(exportEntity, consume)
			end
			if not (available > 0) then
				canConsume = false
			else
				table.insert(toConsume, consume)
			end
		end
		if not canConsume then break end
	end
	if canConsume then
		animator.setAnimationState("output", "output", true)
		for i, consume in ipairs(toConsume) do
			if consume.slot then
				if world.containerConsumeAt(exportEntity, consume.slot, consume.count) then
					storage.leftovers[i] = consume.count - consume.totalAmount
				end
			elseif world.containerConsume(exportEntity, consume) then
				storage.leftovers[i] = consume.count - consume.totalAmount
			end
		end
		if not isOutputting then
			isOutputting = true
			wr_automation.setOutputs({outputs})
			wr_automation.usePower(config.getParameter("activePowerConsumption"))
		end
	else
		animator.setAnimationState("output", "on")
		isOutputting = false
		wr_automation.clearAllOutputs()
		wr_automation.usePower(0)
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
		wr_automation.usePower(0)
		script.setUpdateDelta(0)
		return
	end
	if object.isInputNodeConnected(0) then
		if object.getInputNodeLevel(0) then
			if isOutputting then
				wr_automation.usePower(config.getParameter("activePowerConsumption"))
				wr_automation.setOutputs({ outputs })
			else
				wr_automation.usePower(0)
			end
			script.setUpdateDelta(delta)
		else
			animator.setAnimationState("output", "off")
			isOutputting = false
			wr_automation.clearAllOutputs()
			script.setUpdateDelta(0)
			wr_automation.usePower(0)
		end
	else
		if isOutputting then
			wr_automation.usePower(config.getParameter("activePowerConsumption"))
			wr_automation.setOutputs({ outputs })
		else
			wr_automation.usePower(0)
		end
		script.setUpdateDelta(delta)
	end
end

function setOutputs(newOutputs)
	outputs = newOutputs
	object.setConfigParameter("targetOutput", outputs)
	if not outputs then
		script.setUpdateDelta(0)
		return
	end
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
