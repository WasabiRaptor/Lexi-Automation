require("/scripts/util.lua")
require("/interface/games/util.lua")

local leftTargetOutput
local rightTargetOutput
local inputs
function uninit()
end

function init()
    leftTargetOutput = world.getObjectParameter(pane.sourceEntity(), "leftTargetOutput") or jarray()
    rightTargetOutput = world.getObjectParameter(pane.sourceEntity(), "rightTargetOutput") or jarray()
    inputs = world.getObjectParameter(pane.sourceEntity(), "matterStreamInput") or jarray()

    displayInputs()
end

function displayInputs()
    _ENV.splitterScrollArea:clearChildren()
    local rand = sb.makeRandomSource()
    for _, input in ipairs(inputs) do
        local leftTarget
        local rightTarget
        for _, v in ipairs(leftTargetOutput) do
            if root.itemDescriptorsMatch(input, v, true) then
                leftTarget = v
                break
            end
        end
        if not leftTarget then
            leftTarget = copy(input)
            leftTarget.count = 0
            table.insert(leftTargetOutput, leftTarget)
        end
        for _, v in ipairs(rightTargetOutput) do
            if root.itemDescriptorsMatch(input, v, true) then
                rightTarget = v
                break
            end
        end
        if not rightTarget then
            rightTarget = copy(input)
            rightTarget.count = 0
            table.insert(rightTargetOutput, rightTarget)
        end

        local itemConfig = root.itemConfig(input)
        local hash = rand:randu32()
        local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
        _ENV.splitterScrollArea:addChild({
            type = "panel",
            style = "convex",
            expandMode = { 1, 0 },
            children = {
                { mode = "v" },
                {
                    { type = "itemSlot", item = sb.jsonMerge(input, { count = 1 }) },
                    {
                        { type = "label",   text = merged.shortdescription },
                        {
                            { type = "label", text = tostring(input.count), inline = true },
                            { type = "label", text = "Per Second",          inline = true }
                        },

                    }
                },
                {
                    type = "panel",
                    style = "flat",
                    children = {
                        {
                            {{ type = "image", file = "/interface/wr/automation/output.png?hueshift=-20" }},
                            {{ type = "image", file = "/interface/wr/automation/output.png" }},
                            {{ type = "image", file = "/interface/wr/automation/output.png?hueshift=20" }},
                        },
                        {
                            { type = "textBox", align = "center", id = "leftTextBox"..hash },
                            { type = "label",   align = "center", text = "-", inline = true },
                            { type = "label",   align = "center", text = tostring(math.max(0, input.count - leftTarget.count - rightTarget.count)), id = "centerCountLabel"..hash },
                            { type = "label",   align = "center", text = "-", inline = true },
                            { type = "textBox", align = "center", id = "rightTextBox"..hash },
                        },
                    }
                }
            },
        })
        local leftTextBox = _ENV["leftTextBox"..hash]
        local rightTextBox = _ENV["rightTextBox"..hash]
        local centerCountLabel = _ENV["centerCountLabel"..hash]
        function leftTextBox:onTextChanged()
            local number = tonumber(self.text)
            if number and (number >= 0) then
                leftTarget.count = number
                if leftTarget.count <= input.count then
                    self:setColor("00FF00")
                else
                    self:setColor("FFFF00")
                end
                rightTextBox:onTextChanged()
            else
                self:setColor("FF0000")
            end
            setTargetOutputs()
        end

        function rightTextBox:onTextChanged(doNot)
            local number = tonumber(self.text)
            if number and (number >= 0) then
                rightTarget.count = number
                if (rightTarget.count == 0) or rightTarget.count <= (input.count - leftTarget.count) then
                    self:setColor("00FF00")
                else
                    self:setColor("FFFF00")
                end
            else
                self:setColor("FF0000")
            end
            centerCountLabel:setText(tostring(math.max(0, input.count - leftTarget.count - rightTarget.count)))
            setTargetOutputs()
        end

        leftTextBox:setText(tostring(leftTarget.count))
        rightTextBox:setText(tostring(rightTarget.count))
    end
end
local prevLeft
local prevRight
function setTargetOutputs()

    if compare(prevLeft, leftTargetOutput) and compare(prevRight, rightTargetOutput) then return end

    local function filterTargetOutputs(v)
        return v.count > 0
    end
    local function sortTargetOutputs(a, b)
        return (a.name or a.item) < (b.name or b.item)
    end
    prevLeft = copy(leftTargetOutput)
    prevRight = copy(rightTargetOutput)

    local leftTargetOutputSorted = util.filter(copy(leftTargetOutput),filterTargetOutputs)
    local rightTargetOutputSorted = util.filter(copy(rightTargetOutput),filterTargetOutputs)
    table.sort(leftTargetOutputSorted, sortTargetOutputs)
    table.sort(rightTargetOutputSorted, sortTargetOutputs)

    world.sendEntityMessage(pane.sourceEntity(), "setTargetOutputs", leftTargetOutputSorted, rightTargetOutputSorted)
end
