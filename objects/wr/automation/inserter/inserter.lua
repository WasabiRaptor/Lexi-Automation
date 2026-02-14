require("/objects/wr/automation/wr_automation.lua")

local inputs
local outputEntity
local objectPosition
local delta
function init()
	wr_automation.init()
	objectPosition = object.position()
	inputs = (config.getParameter("matterStreamInput") or {})[1]
	delta = math.max(config.getParameter("scriptDelta") or 0, 60)
	local fromExporter = config.getParameter("fromExporter")

	message.setHandler("refreshInputs", function (_,_, force)
		refreshOutput(force)
	end)
	storage.leftovers = storage.leftovers or {}
	if not inputs then
		script.setUpdateDelta(0)
		object.setOutputNodeLevel(0, false)
	elseif inputs and storage.uninitTime and (not fromExporter) and (not (world.type() == "unknown")) then
		local currentTime = world.time()
		local timePassed = currentTime - storage.uninitTime
		storage.uninitTime = currentTime
		for i, input in ipairs(inputs) do
			storage.leftovers[i] = (storage.leftovers[i] or 0) + (input.count * timePassed)
		end
	end
end

local wasFull
local loaded
function update(dt)
	if not loaded then
		loaded = world.regionActive({objectPosition[1]-3,objectPosition[2]-3,objectPosition[1]+3,objectPosition[2]+3})
		if not loaded then return end
	end
	if not inputs then
		script.setUpdateDelta(0)
		object.setOutputNodeLevel(0, false)
		animator.setAnimationState("input", "off")
		return
	end
	if (not outputEntity) or (not world.entityExists(outputEntity)) then
		outputEntity = world.objectAt({ objectPosition[1] + object.direction(), objectPosition[2] })
	end
	if not outputEntity then
		object.setOutputNodeLevel(0, false)
		animator.setAnimationState("input", "off")
		return
	end

	local insertedAny = false
	local attemptedInsert = false
	for i, input in ipairs(inputs) do
		local output = copy(input)
		local total = (input.count * dt) + (storage.leftovers[i] or 0)
		output.count = math.floor(total)
		storage.leftovers[i] = total - output.count
		if output.count > 0 then
			attemptedInsert = true
			-- containerAddItems returns leftovers it couldn't add to the container
			insertedAny = (not world.containerAddItems(outputEntity, output)) or insertedAny
		end
	end

	if attemptedInsert then
		if insertedAny then
			animator.setAnimationState("input", "insert", true)
		else
			animator.setAnimationState("input", "on")
		end
		-- set the wire node output if the inserter inserted any items on this tick
		object.setOutputNodeLevel(0, insertedAny)
		if (not insertedAny) and (not wasFull) then
			wasFull = true
			script.setUpdateDelta(math.max(3600, delta))
		elseif insertedAny and wasFull then
			wasFull = false
			script.setUpdateDelta(delta)
		end
	end
end

function uninit()
	storage.uninitTime = world.time()
end
function refreshOutput(force)
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		inputs = nil
		object.setConfigParameter("matterStreamInput", nil)
		script.setUpdateDelta(0)
		object.setOutputNodeLevel(0, false)
		return
	end
	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0)
	if (not force) and (fromExporter == config.getParameter("fromExporter")) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	local mode = config.getParameter("insertMode")
	local best
	if mode == "fast" then
		-- find the fastest input to use it as our tick rate and reset leftover amounts from previous ticks
		best = 0
		for i, input in ipairs(inputs) do
			storage.leftovers[i] = 0
			if input.count > best then
				best = input.count
			end
		end
	else
		-- find the slowest input to use it as our tick rate and reset leftover amounts from previous ticks
		best = math.huge
		for i, input in ipairs(inputs) do
			storage.leftovers[i] = 0
			if input.count < best then
				best = input.count
			end
		end

	end
	-- inserters will never tick faster than once per second
	delta = math.max(1 / best, 1) * 60
	script.setUpdateDelta(delta)
	object.setConfigParameter("scriptDelta", delta)
end

function onInputNodeChange()
	refreshOutput()
end
function onNodeConnectionChange()
	refreshOutput()
end
