require("/interface/games/util.lua")

local outputCount
local producing
function init()
    script.setUpdateDelta(0)
    producing = config.getParameter("producing")
    message.setHandler("setOutput", function (_,_,newOutput)
        producing = newOutput
        object.setConfigParameter("producing", producing)
        setOutput(true)
    end)
end


function setOutput(force)
    if not producing then
        object.setOutputNodeLevel(0, false)
        return
    end

    local outputNodes = object.getOutputNodeIds(0)
    local newOutputCount = 0
    for _, _ in pairs(outputNodes) do
        newOutputCount = newOutputCount + 1
    end
    if (not force) and (newOutputCount == outputCount) then return end
    outputCount = newOutputCount

    -- count the number of entities the output is connected to so it's split evenly between them
    local output = {}
    for _, v in ipairs(producing) do
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

function onNodeConnectionChange()
    setOutput()
end
