require("/objects/wr/automation/wr_automation.lua")

local outputCount
local inputs
function init()
    script.setUpdateDelta(0)
    inputs = config.getParameter("matterStreamInput")
    message.setHandler("refreshInputs", function (_,_)
        refreshOutput()
    end)
    if object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
        animator.setAnimationState("input", "on", true)
    end
end

function update(dt)

end

function uninit()

end
function refreshOutput(force)
    if (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
        object.setOutputNodeLevel(0, false)
        object.setConfigParameter("matterStreamOutput", nil)
        inputs = nil
        object.setConfigParameter("matterStreamInput", nil)
        animator.setAnimationState("input", "off")
        return
    end
    animator.setAnimationState("input", "on", true)
    local outputNodes = object.getOutputNodeIds(0)
    local newOutputCount = 0
    for _, _ in pairs(outputNodes) do
        newOutputCount = newOutputCount + 1
    end
    local newInputs = wr_automation.countInputs()
    if (not force) and compare(newInputs, inputs) and (newOutputCount == outputCount) then return end
    object.setConfigParameter("matterStreamInput", newInputs)
    inputs = newInputs
    outputCount = newOutputCount

    -- count the number of entities the output is connected to so it's split evenly between them
    local output = {}
    for _, v in ipairs(inputs) do
        local outputItem = copy(v)
        outputItem.count = outputItem.count / math.max(1, outputCount)
        table.insert(output, outputItem)
    end
    if compare(config.getParameter("matterStreamOutput"), {output}) then return end

    object.setOutputNodeLevel(0, true)
    object.setConfigParameter("matterStreamOutput", {output})
    for eid, _ in pairs(outputNodes) do
        world.sendEntityMessage(eid, "refreshInputs")
    end

end

function onInputNodeChange()
    refreshOutput()
end
function onNodeConnectionChange()
    refreshOutput()
end
