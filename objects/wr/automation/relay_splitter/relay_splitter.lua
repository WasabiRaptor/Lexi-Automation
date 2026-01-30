require("/objects/wr/automation/wr_automation.lua")

local leftOutputCount
local rightOutputCount
local defaultOutputCount
local inputs
local leftTargetOutput
local rightTargetOutput
local outputs
local leftState
local rightState
function init()
    script.setUpdateDelta(0)
    inputs = config.getParameter("matterStreamInput")
    outputs = config.getParameter("matterStreamOutput")
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
    leftState = (object.direction() == 1) and "left" or "right"
    rightState = (object.direction() == 1) and "right" or "left"
    if object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
        animator.setAnimationState("input", "on", true)
        if outputs then
            animator.setAnimationState("center", (#outputs[1] > 0) and "on" or "off", true)
            animator.setAnimationState(leftState, (#outputs[2] > 0) and "on" or "off", true)
            animator.setAnimationState(rightState, (#outputs[3] > 0) and "on" or "off", true)
        end
    end
end

function update(dt)

end

function uninit()

end
function refreshOutput(force)
    if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
        object.setConfigParameter("matterStreamOutput", nil)
        object.setConfigParameter("matterStreamInput", nil)
        object.setOutputNodeLevel(0, false)
        object.setOutputNodeLevel(1, false)
        object.setOutputNodeLevel(2, false)
        animator.setAnimationState("input", "off")
        animator.setAnimationState("center", "off")
        animator.setAnimationState("left", "off")
        animator.setAnimationState("right", "off")
        inputs = nil
        return
    end
    animator.setAnimationState("input", "on", true)

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
                if outputItem.count > 0 then
                    table.insert(rightOutput, outputItem)
                end
                break
            end
        end
    end

    outputs = wr_automation.setOutputs({defaultOutput, leftOutput, rightOutput})
    animator.setAnimationState("center", (#outputs[1] > 0) and "on" or "off")
    animator.setAnimationState(leftState, (#outputs[2] > 0) and "on" or "off")
    animator.setAnimationState(rightState, (#outputs[3] > 0) and "on" or "off")
end

function onInputNodeChange()
    refreshOutput()
end
function onNodeConnectionChange()
    refreshOutput()
end
