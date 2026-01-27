require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/scripts/wr/automation/oreNoise.lua")
function uninit()
    local fuel = _ENV.fuelSlot:item()
    if fuel then player.giveItem(fuel) end
end
local fuelValues = {}
local fuelRPC

function init()
    fuelValues = world.getObjectParameter(pane.sourceEntity(), "fuelValues")
    refreshStatus()
end
function _ENV.addFuel:onClick()
    if fuelRPC then return end
    local item = _ENV.fuelSlot:item()
    if item then
        fuelRPC = world.sendEntityMessage(pane.sourceEntity(), "addFuel", item.count * fuelValues[(item.item or item.name)])
    end
    refreshStatus()
end

function _ENV.fuelSlot:acceptsItem(item)
    return fuelValues[(item.item or item.name)] ~= nil
end

function refreshStatus()
    status = world.getObjectParameter(pane.sourceEntity(), "status")
    if status == "active" then
        _ENV.statusLabel.color = "00FF00"
        _ENV.statusLabel:setText("Active")
    elseif status == "noFuel" then
        _ENV.statusLabel.color = "FF0000"
        _ENV.statusLabel:setText("Out Of Fuel")
    elseif status == "full" then
        _ENV.statusLabel.color = "FFFF00"
        _ENV.statusLabel:setText("Inventory Full")
    elseif status == "warming" then
        _ENV.statusLabel.color = "FFFF00"
        _ENV.statusLabel:setText("Warming Up")
    elseif status == "invalid" then
        _ENV.statusLabel.color = "FF0000"
        _ENV.statusLabel:setText("Invalid Location")
    end
end

function update()
    if fuelRPC and fuelRPC:finished() then
        if item then
            local consumed = math.ceil(fuelRPC:result() / fuelValues[(item.item or item.name)])
            local item = _ENV.fuelSlot:item()
            item.count = item.count - consumed
            if item.count <= 0 then
                _ENV.fuelSlot:setItem(nil)
            else
                _ENV.fuelSlot:setItem(item)
            end
        end
        fuelRPC = nil
    end
    refreshStatus()
end
