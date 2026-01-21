require("/objects/wr/automation/wr_automation.lua")

local inputs
local leftovers = {}
local outputEntity
function init()
    inputs = config.getParameter("matterStreamInput")
    message.setHandler("refreshInputs", function (_,_)
        refreshOutput()
    end)
    if not inputs then
        script.setUpdateDelta(0)
        return
    else
        local timePassed = world.time() - (storage.uninitTime or 0)
        for i, input in ipairs(inputs) do
            leftovers[i] = (input.count * timePassed)
        end
    end
end

function update(dt)
    if not inputs then
        script.setUpdateDelta(0)
        return
    end
    if (not outputEntity) or (not world.entityExists(outputEntity)) then
        local position = object.position()
        outputEntity = world.objectAt({ position[1] + object.direction(), position[2] })
    end
    if not outputEntity then return end

    for i, input in ipairs(inputs) do
        local total = (input.count * dt) + leftovers[i]
        local outputCount = math.floor(total)
        leftovers[i] = total - outputCount
        if outputCount > 0 then
            world.containerAddItems(outputEntity, sb.jsonMerge(input, {count = outputCount}))
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
        return
    end
    local newInputs = wr_automation.countInputs()
    if sb.jsonEqual(newInputs, inputs) then return end
    object.setConfigParameter("matterStreamInput", newInputs)
    inputs = newInputs
    -- find the slowest input to use it as our tick rate and reset leftover amounts from previous ticks
    local best = math.huge
    for i, input in ipairs(inputs) do
        leftovers[i] = 0
        if input.count < best then
            best = input.count
        end
    end
    -- inserters will never tick faster than once per second
    script.setUpdateDelta(math.max(1 / best, 1) * 60)
end

function onInputNodeChange()
    refreshOutput()
end
function onNodeConnectionChange()
    refreshOutput()
end

function stopOutput()

end
