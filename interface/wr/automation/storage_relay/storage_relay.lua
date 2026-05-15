require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/labels.lua")
local targetOutput
local prevOutput
local inputNodesConfig
local containerSize
function uninit()
end

function init()
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	targetOutput = world.getObjectParameter(pane.sourceEntity(), "targetOutput") or jarray()
	prevOutput = copy(targetOutput)
	containerSize = world.containerSize(pane.sourceEntity())

	_ENV.lowPowerLabel:setVisible(not checkPowered())
	_ENV.storageItemGrid:setNumSlots(containerSize)

	local input = world.getObjectParameter(pane.sourceEntity(), "matterStreamInput") or {}
	for _, item in pairs(input[1] or {}) do
		local found = false
		for _, v in ipairs(targetOutput) do
			if root.itemDescriptorsMatch(v, item, true) then
				targetOutput.count = item.count
				found = true
				break
			end
		end
		if not found then
			item.outputTarget = 0
			table.insert(targetOutput, item)
		end
	end
	table.sort(targetOutput, sortTargetOutputs)
	displayInputs()
end

function sortTargetOutputs(a, b)
	return (a.name or a.item) < (b.name or b.item)
end

function displayInputs()
	_ENV.inserterScrollArea:clearChildren()
	local rand = sb.makeRandomSource()
	if (not targetOutput) or (#targetOutput == 0) then
		_ENV.inserterScrollArea:addChild({
			type = "label",
			align = "center",
			text = "Recieving no items.",
		})
		return
	end
	for _, target in ipairs(targetOutput) do

		local timeMultiplier, timeLabel = timeScale(target.count)

		local itemConfig = root.itemConfig(target)
		local hash = rand:randu32()
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		_ENV.inserterScrollArea:addChild({
			type = "panel",
			style = "convex",
			expandMode = { 1, 0 },
			children = {
				{ mode = "v", expandMode = {1,0} },
				{
					{mode = "h", expandMode = {1,0}},
					{ type = "itemSlot", item = sb.jsonMerge(target, { count = 1 }) },
					{
						{ type = "label",   text = (merged.shortdescription or target.name or target.item or "")},
						{
							{ mode = "h", expandMode = {1,0} },
							{ type = "image", file = inputNodesConfig[1].icon },
							{ type = "label", id = "inputAmountLabel"..hash, text = clipAtThousandth((timeMultiplier * (target.count - target.outputTarget))), inline = true,  },
							{ type = "label", text = "/",            inline = true },
							{ type = "label", text = clipAtThousandth((timeMultiplier * target.count)), inline = true,  },
							{ type = "label", text = timeLabel,            inline = true }
						},
					}
				},
				{type = "panel", style = "flat", expandMode = { 1, 0 }, children = {
					{ mode = "v", expandMode = {1,0} },
					{
						{ mode = "h", expandMode = {1,0} },
						{ type = "image", file = outputNodesConfig[1].icon },
						{{expandMode = {0,1}, size = 50},{ type = "textBox", align = "center", id = "targetTextBox" .. hash }},
						{ type = "spacer", size = 8},
						{ type = "label", text = " "..timeLabel, inline = true}

					},
					{
						{ mode = "h", expandMode = {1,0} },
						{ type ="iconButton", id ="decSlotButton"..hash, image = "/interface/pickleft.png", hoverImage="/interface/pickleftover.png"},
						{{expandMode = {0,1}, size = 50},{ type = "textBox", id ="fromSlotTextBox"..hash, text = "Any"}},
						{ type ="iconButton", id ="incSlotButton"..hash, image = "/interface/pickright.png", hoverImage="/interface/pickrightover.png"},
						{ type = "label", text = " Container Slot", inline = true}
					}
				}}
			},
		})
		local targetTextBox = _ENV["targetTextBox"..hash]
		local inputAmountLabel = _ENV["inputAmountLabel"..hash]
		local decSlotButton = _ENV["decSlotButton"..hash]
		local fromSlotTextBox = _ENV["fromSlotTextBox"..hash]
		local incSlotButton = _ENV["incSlotButton"..hash]

		function targetTextBox:onTextChanged()
			local number = tonumber(self.text)
			if number and (number >= 0) then
				target.outputTarget = number / timeMultiplier
				self:setColor("00FF00")
			else
				self:setColor("FF0000")
			end
			inputAmountLabel:setText(tostring(math.max(0,target.count - target.outputTarget)))
			setTargetOutputs()
		end

		targetTextBox:setText(tostring(target.outputTarget * timeMultiplier))

		function decSlotButton:onClick()
			local number = tonumber(fromSlotTextBox.text)
			if not number then number = 0 end
			number = (number - 1) % (containerSize + 1)
			fromSlotTextBox:setText(tostring(number))
		end
		function incSlotButton:onClick()
			local number = tonumber(fromSlotTextBox.text)
			if not number then number = 0 end
			number = (number + 1) % (containerSize + 1)
			fromSlotTextBox:setText(tostring(number))
		end
		function fromSlotTextBox:onTextChanged()
			local number = tonumber(self.text)
			if number then
				if number == 0 then
					self:setText("Any")
					return
				elseif number ~= math.floor(number) then
					self:setText(tostring(math.floor(number)))
					return
				elseif number > containerSize then
					self:setText(tostring(number % containerSize))
					return
				end
				target.slot = number - 1
				self:setColor("00FF00")
			else
				target.slot = nil
				if self.text == "Any" then
					self:setColor("00FF00")
				else
					self:setColor("FF0000")
				end
			end
			setTargetOutputs()
		end
		if target.slot then
			fromSlotTextBox:setText(tostring(target.slot + 1))
		else
			fromSlotTextBox:setText("Any")
		end
	end
end

function setTargetOutputs()

	if compare(prevOutput, targetOutput) then return end

	local function filterTargetOutputs(v)
		return (v.slot ~= nil) or (v.outputTarget ~= 0)
	end
	prevOutput = copy(targetOutput)

	local targetOutputSorted = util.filter(copy(targetOutput),filterTargetOutputs)
	table.sort(targetOutputSorted, sortTargetOutputs)

	world.sendEntityMessage(pane.sourceEntity(), "setTargetOutputs", targetOutputSorted)
end

function checkPowered()
	local activePowerConsumption = world.getObjectParameter(pane.sourceEntity(), "activePowerConsumption") or 0
	local powerConsumption = world.getObjectParameter(pane.sourceEntity(), "powerConsumption") or 0
	local powerChanged = activePowerConsumption - powerConsumption
	return world.getProperty("wr_powerStorageAvailable")
	or ((powerConsumption == 0) and (newPowerConsumption == 0))
	or ((world.getProperty("wr_powerProduction") or 0) >= ((world.getProperty("wr_powerConsumption") or 0) + powerChanged))
end
