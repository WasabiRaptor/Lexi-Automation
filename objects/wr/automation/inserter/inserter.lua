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
        object.setOutputNodeLevel(0, false)
    else
        local timePassed = world.time() - (storage.uninitTime or 0)
        for i, input in ipairs(inputs) do
            leftovers[i] = (input.count * timePassed)
        end
    end
end

local wasFull
function update(dt)
    if not inputs then
        script.setUpdateDelta(0)
        object.setOutputNodeLevel(0, false)
        return
    end
    if (not outputEntity) or (not world.entityExists(outputEntity)) then
        local position = object.position()
        outputEntity = world.objectAt({ position[1] + object.direction(), position[2] })
    end
    if not outputEntity then
        object.setOutputNodeLevel(0, false)
        return
    end

    local insertedAny = false
    for i, input in ipairs(inputs) do
        local total = (input.count * dt) + leftovers[i]
        local outputCount = math.floor(total)
        leftovers[i] = total - outputCount
        if outputCount > 0 then
            -- containerAddItems returns leftovers it couldn't add to the container
            insertedAny = insertedAny or (not world.containerAddItems(outputEntity, sb.jsonMerge(input, { count = outputCount })))
        end
    end
    -- set the wire node output if the inserter inserted any items on this tick
    object.setOutputNodeLevel(0, insertedAny)

    if (not insertedAny) and (not wasFull) then
        wasFull = true
        script.setUpdateDelta(math.max(3600, config.getParameter("scriptDelta") or 60))
    elseif insertedAny and wasFull then
        script.setUpdateDelta(config.getParameter("scriptDelta") or 60)
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
    local newInputs = wr_automation.countInputs()
    if sb.jsonEqual(newInputs, inputs) then return end
    object.setConfigParameter("matterStreamInput", newInputs)
    inputs = newInputs
    local mode = config.getParameter("insertMode")
    local best
    if mode == "fast" then
        -- find the fastest input to use it as our tick rate and reset leftover amounts from previous ticks
        best = 0
        for i, input in ipairs(inputs) do
            leftovers[i] = 0
            if input.count > best then
                best = input.count
            end
        end
    else
        -- find the slowest input to use it as our tick rate and reset leftover amounts from previous ticks
        best = math.huge
        for i, input in ipairs(inputs) do
            leftovers[i] = 0
            if input.count < best then
                best = input.count
            end
        end

    end
    -- inserters will never tick faster than once per second
    local delta = math.max(1 / best, 1) * 60
    script.setUpdateDelta(delta)
    object.setConfigParameter("scriptDelta", delta)
end

function onInputNodeChange()
    refreshOutput()
end
function onNodeConnectionChange()
    refreshOutput()
end
