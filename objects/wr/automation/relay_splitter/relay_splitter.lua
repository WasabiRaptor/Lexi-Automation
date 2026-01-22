require("/objects/wr/automation/wr_automation.lua")

local leftOutputCount
local rightOutputCount
local defaultOutputCount
local inputs
local leftTargetOutput
local rightTargetOutput
function init()
    script.setUpdateDelta(0)
    inputs = config.getParameter("matterStreamInput")
    leftTargetOutput = config.getParameter("leftTargetOutput") or jarray()
    rightTargetOutput = config.getParameter("rightTargetOutput") or jarray()
    message.setHandler("refreshInputs", function (_,_)
        refreshOutput()
    end)
    message.setHandler("setTargetOutputs", function(_, _, left, right)
        local forceRefresh = false
        if not compare(left, leftTargetOutput) then
            object.setConfigParameter("leftTargetOutput", left)
            leftTargetOutput = left
            forceRefresh = true
        end
        if not compare(right, rightTargetOutput) then
            object.setConfigParameter("rightTargetOutput", right)
            rightTargetOutput = right
            forceRefresh = true
        end
        refreshOutput(forceRefresh)
    end)
end

function update(dt)

end

function uninit()

end
function refreshOutput(force)
    if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
        object.setOutputNodeLevel(0, false)
        object.setOutputNodeLevel(1, false)
        object.setOutputNodeLevel(2, false)
        object.setConfigParameter("matterStreamOutput", nil)
        inputs = nil
        object.setConfigParameter("matterStreamInput", nil)
        return
    end
    local leftOutputNodes = object.getOutputNodeIds(1)
    local newLeftOutputCount = 0
    for _, _ in pairs(leftOutputNodes) do
        newLeftOutputCount = newLeftOutputCount + 1
    end
    local rightOutputNodes = object.getOutputNodeIds(2)
    local newRightOutputCount = 0
    for _, _ in pairs(rightOutputNodes) do
        newRightOutputCount = newRightOutputCount + 1
    end
    local defaultOutputNodes = object.getOutputNodeIds(0)
    local newDefaultOutputCount = 0
    for _, _ in pairs(defaultOutputNodes) do
        newDefaultOutputCount = newDefaultOutputCount + 1
    end

    local newInputs = wr_automation.countInputs()
    if (not force) and compare(newInputs, inputs)
        and (newDefaultOutputCount == defaultOutputCount)
        and (newLeftOutputCount == leftOutputCount)
        and (newRightOutputCount == rightOutputCount)
    then
        return
    end

    object.setConfigParameter("matterStreamInput", newInputs)
    inputs = newInputs
    leftOutputCount = newLeftOutputCount
    rightOutputCount = newRightOutputCount
    defaultOutputCount = newDefaultOutputCount
    local defaultOutput = copy(inputs)

    local leftOutput = jarray()
    for _, targetOutput in ipairs(leftTargetOutput) do
        for _, defaultOutputItem in ipairs(defaultOutput) do
            if root.itemDescriptorsMatch(targetOutput, defaultOutputItem, true) then
                local outputItem = copy(targetOutput)
                if targetOutput.count > defaultOutputItem.count then
                    outputItem.count = defaultOutputItem.count
                    defaultOutputItem.count = 0
                else
                    defaultOutputItem.count = defaultOutputItem.count - targetOutput.count
                end
                outputItem.count = outputItem.count / math.max(1, leftOutputCount)
                if outputItem.count > 0 then
                    table.insert(leftOutput, outputItem)
                end
                break
            end
        end
    end
    local rightOutput = jarray()
    for _, targetOutput in ipairs(rightTargetOutput) do
        for _, defaultOutputItem in ipairs(defaultOutput) do
            if root.itemDescriptorsMatch(targetOutput, defaultOutputItem, true) then
                local outputItem = copy(targetOutput)
                if targetOutput.count > defaultOutputItem.count then
                    outputItem.count = defaultOutputItem.count
                    defaultOutputItem.count = 0
                else
                    defaultOutputItem.count = defaultOutputItem.count - targetOutput.count
                end
                outputItem.count = outputItem.count / math.max(1, leftOutputCount)
                if outputItem.count > 0 then
                    table.insert(rightOutput, outputItem)
                end
                break
            end
        end
    end

    local finalOutput = jarray()
    -- split our remaining outputs in the default stream evenly
    for _, outputItem in ipairs(defaultOutput) do
        outputItem.count = outputItem.count / math.max(1, defaultOutputCount)
        if outputItem.count > 0 then
            table.insert(finalOutput, outputItem)
        end
    end
    if compare(config.getParameter("matterStreamOutput"), {finalOutput, leftOutput, rightOutput}) then return end

    object.setOutputNodeLevel(0, #finalOutput > 0)
    object.setOutputNodeLevel(1, #leftOutput > 0)
    object.setOutputNodeLevel(2, #rightOutput > 0)
    object.setConfigParameter("matterStreamOutput", {finalOutput, leftOutput, rightOutput})
    for eid, _ in pairs(leftOutputNodes) do
        world.sendEntityMessage(eid, "refreshInputs")
    end
    for eid, _ in pairs(rightOutputNodes) do
        world.sendEntityMessage(eid, "refreshInputs")
    end
    for eid, _ in pairs(defaultOutputNodes) do
        world.sendEntityMessage(eid, "refreshInputs")
    end

end

function onInputNodeChange()
    refreshOutput()
end
function onNodeConnectionChange()
    refreshOutput()
end
