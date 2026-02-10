require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/labels.lua")
local targetOutput
local prevOutput
local outputNodesConfig
function uninit()
end

function init()
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	targetOutput = world.getObjectParameter(pane.sourceEntity(), "targetOutput") or jarray()
	prevOutput = copy(targetOutput)

    _ENV.efficencyLabel:setText(
        tostring(math.floor(world.getObjectParameter(pane.sourceEntity(), "efficency") * 100)).."%"
	)
	local position = world.entityPosition(pane.sourceEntity())
	local eid = world.objectAt({position[1], position[2]-1})
	if eid and world.entityExists(eid) then
		local items = world.containerItems(eid)
		for _, item in pairs(items) do
			item.count = 0
			local found = false
			for _, v in ipairs(targetOutput) do
				if root.itemDescriptorsMatch(v, item, true) then
					found = true
					break
				end
			end
			if not found then
				table.insert(targetOutput, item)
			end
		end
	end
	table.sort(targetOutput, sortTargetOutputs)
	displayInputs()
end

function sortTargetOutputs(a, b)
	return (a.name or a.item) < (b.name or b.item)
end

function displayInputs()
	_ENV.exporterScrollArea:clearChildren()
	local rand = sb.makeRandomSource()
	for _, target in ipairs(targetOutput) do

		local timeMultiplier, timeLabel = timeScale(target.count)

		local itemConfig = root.itemConfig(target)
		local hash = rand:randu32()
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		_ENV.exporterScrollArea:addChild({
			type = "panel",
			style = "convex",
			expandMode = { 1, 0 },
			children = {
				{ mode = "h" },
				{ type = "itemSlot", item = sb.jsonMerge(target, { count = 1 }) },
				{
					{ type = "label",   text = merged.shortdescription },
					{
						{ type = "image", file = outputNodesConfig[1].icon },
						{ type = "textBox", align = "center", id = "targetTextBox" .. hash },
						{ type = "label", text = timeLabel}
					}
				}
			},
		})
		local targetTextBox = _ENV["targetTextBox"..hash]

		function targetTextBox:onTextChanged()
			local number = tonumber(self.text)
			if number and (number >= 0) then
				target.count = number / timeMultiplier
				self:setColor("00FF00")
			else
				self:setColor("FF0000")
			end
			setTargetOutputs()
		end

		targetTextBox:setText(tostring(target.count * timeMultiplier))
	end
end
function setTargetOutputs()

	if compare(prevOutput, targetOutput) then return end

	local function filterTargetOutputs(v)
		return v.count > 0
	end
	prevOutput = copy(targetOutput)

	local targetOutputSorted = util.filter(copy(targetOutput),filterTargetOutputs)
	table.sort(targetOutputSorted, sortTargetOutputs)

	world.sendEntityMessage(pane.sourceEntity(), "setTargetOutputs", targetOutputSorted)
end
