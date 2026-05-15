require("/objects/wr/automation/wr_automation.lua")

local inputs
local objectPosition
local delta
local activePowerConsumption

local insertItems
local streamItems
local outputCount

function init()
	wr_automation.init()
	objectPosition = object.position()
	targetOutput = config.getParameter("targetOutput") or {}
	inputs = (config.getParameter("matterStreamInput") or {})[1]
	insertItems = config.getParameter("insertItems")
	delta = math.max(config.getParameter("scriptDelta") or 0, 60)
	local fromExporter = config.getParameter("fromExporter")
	activePowerConsumption = config.getParameter("activePowerConsumption")
	message.setHandler("setTargetOutputs", function(_, _, newOutputs)
		targetOutput = newOutputs
		object.setConfigParameter("targetOutput", targetOutput)
		refreshInput(true)
	end)
	message.setHandler("refreshInputs", function (_,_, force)
		refreshInput(force)
	end)
	storage.leftovers = storage.leftovers or {}
	if not insertItems then
		script.setUpdateDelta(0)
		object.setOutputNodeLevel(1, false)
	elseif insertItems and storage.uninitTime and (not fromExporter) and (not (world.type() == "unknown")) then
		local currentTime = world.time()
		local timePassed = math.max(0, currentTime - storage.uninitTime)
		storage.uninitTime = currentTime
		for i, input in ipairs(insertItems) do
			storage.leftovers[i] = (storage.leftovers[i] or 0) + (input.count * timePassed)
		end
	end
end

local wasFull
local loaded
local allowOutputRefresh = true
function update(dt)
	if not loaded then
		loaded = world.regionActive({objectPosition[1]-3,objectPosition[2]-3,objectPosition[1]+3,objectPosition[2]+3})
		if not loaded then return end
	end
	if not insertItems then
		script.setUpdateDelta(0)
		object.setOutputNodeLevel(1, false)
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		return
	end
	if (not wr_automation.checkPowered(activePowerConsumption)) then
		object.setOutputNodeLevel(1, false)
		return
	end

	local insertedAny = false
	local attemptedInsert = false
	local insertedAll = true
	for i, input in ipairs(insertItems) do
		local output = copy(input)
		local total = (input.count * dt) + (storage.leftovers[i] or 0)
		output.count = math.floor(total)
		storage.leftovers[i] = total - output.count
		if output.count > 0 then
			attemptedInsert = true
			local didInsert
			-- containerAddItems returns leftovers it couldn't add to the container
			if output.slot then
				didInsert = (not world.containerPutItemsAt(entity.id(), output, output.slot))
			else
				didInsert = (not world.containerAddItems(entity.id(), output))
			end
			insertedAny = didInsert or insertedAny
			insertedAll = didInsert and insertedAll
		end
	end
	allowOutputRefresh = not insertedAll

	if attemptedInsert then
		-- set the wire node output if the inserter inserted any items on this tick
		object.setOutputNodeLevel(1, insertedAny)
		if (not insertedAny) then
			wasFull = true
			script.setUpdateDelta(0)
			object.setConfigParameter("scriptDelta", 0)
			wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		end
	end
end

function uninit()
	storage.uninitTime = world.time()
end
function refreshInput(force)
	if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
		inputs = nil
		object.setConfigParameter("matterStreamInput", nil)
		script.setUpdateDelta(0)
		object.setOutputNodeLevel(0, false)
		object.setOutputNodeLevel(1, false)
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		return
	end
	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end

	local newInputs, totalItems, fromExporter = wr_automation.countInputs(0, {input = targetOutput, matchInputParameters = true})
	if (not force) and (outputCount == newOutputCount) and (fromExporter == config.getParameter("fromExporter")) and compare(newInputs, inputs) then return end
	object.setConfigParameter("matterStreamInput", {newInputs})
	object.setConfigParameter("fromExporter", fromExporter)
	inputs = newInputs
	outputCount = newOutputCount
	refreshOutput(true)
end
function refreshOutput(force)
	if (not force) and (not allowOutputRefresh) then
		allowOutputRefresh = true
		return
	end
	if not inputs then return end
	insertItems = {}
	streamItems = {}
	for _, input in ipairs(inputs) do
		local inputCopy = copy(input)
		local canfit = false
		if input.slot then
			local itemAt = world.containerItemAt(entity.id(), input.slot)
			if root.itemDescriptorsMatch(itemAt,input,true) then
				local itemConfig = root.itemConfig(input)
				local mergedConfig = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
				local maxStack = mergedConfig.maxStack or root.assetJson("/items/defaultParameters.config:defaultMaxStack")
				canfit = itemAt.count < maxStack
			elseif not itemAt then
				canfit = true
			end
		else
			canfit = world.containerItemsCanFit(entity.id(), input) >= 1
		end

		if canfit then
			if inputCopy.outputTarget and (outputCount > 0) then
				inputCopy.count = math.min(input.count, inputCopy.outputTarget)
				table.insert(streamItems, inputCopy)
				local insertItem = copy(input)
				insertItem.count = input.count - inputCopy.count
				if insertItem.count > 0 then
					table.insert(insertItems, insertItem)
				end
			else
				table.insert(insertItems, inputCopy)
			end
		else
			table.insert(streamItems, inputCopy)
		end
	end
	wr_automation.setOutputs({streamItems})
	sb.logInfo(sb.printJson(streamItems))
	if #insertItems == 0 then
		wasFull = true
		script.setUpdateDelta(0)
		object.setConfigParameter("scriptDelta", 0)
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))

		insertItems = nil
		object.setConfigParameter("insertItems", nil)
		return
	end
	object.setConfigParameter("insertItems", insertItems)
	-- find the fastest input to use it as our tick rate and reset leftover amounts from previous ticks
	local best = 0
	for i, input in ipairs(insertItems) do
		storage.leftovers[i] = 0
		if input.count > best then
			best = input.count
		end
	end
	-- inserters will never tick faster than once per second
	delta = math.max(1 / best, 1) * 60
	script.setUpdateDelta(delta)
	object.setConfigParameter("scriptDelta", delta)
	activePowerConsumption = config.getParameter("activePowerConsumption")
	wr_automation.usePower(activePowerConsumption)
end

function onInputNodeChange()
	refreshInput()
end
function onNodeConnectionChange()
	refreshInput()
end

function containerCallback()
	refreshOutput()
end
