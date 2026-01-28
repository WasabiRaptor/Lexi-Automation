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
    local fuelValueList = {}
    for k, v in pairs(fuelValues) do
        itemConfig = root.itemConfig(k)
        if itemConfig then
            table.insert(fuelValueList, { itemConfig.config.shortdescription, v })
        end
    end
    table.sort(fuelValueList, function(a, b)
        if a[2] == b[2] then
            return a[1] < b[1]
        end
        return a[2] < b[2]
    end)
    local fuelValueTooltip = {}
    for _, v in ipairs(fuelValueList) do
        table.insert(fuelValueTooltip, ("%s^reset;: %s Seconds^reset;"):format(table.unpack(v)))
    end
    _ENV.fuelSlot.toolTip = fuelValueTooltip

    fuelRPC = world.sendEntityMessage(pane.sourceEntity(), "addFuel", 0)
    refreshStatus()
end
function _ENV.addFuelButton:onClick()
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

local maxFuelValue = 1
local totalFuel = 0
function update()
    if fuelRPC and fuelRPC:finished() then
        local consumedFuelValue
        consumedFuelValue, totalFuel = table.unpack(fuelRPC:result())
        if item then
            local consumed = math.ceil(consumedFuelValue / fuelValues[(item.item or item.name)])
            local item = _ENV.fuelSlot:item()
            item.count = item.count - consumed
            if item.count <= 0 then
                _ENV.fuelSlot:setItem(nil)
            else
                _ENV.fuelSlot:setItem(item)
            end
        end
        maxFuelValue = world.getObjectParameter(pane.sourceEntity(), "maxFuel")
        fuelRPC = nil
    end
    _ENV.fuelPercentageLabel:setText(("%d%%"):format(math.ceil((totalFuel / maxFuelValue) * 100)))
    totalFuel = math.max(0, totalFuel - script.updateDt())
    refreshStatus()
end
