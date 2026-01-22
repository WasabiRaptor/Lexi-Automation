require("/scripts/util.lua")
require("/interface/games/util.lua")

function uninit()
end

local materialList
local producing
function init()
    materialList = root.assetJson("/interface/wr/automation/extractor/materialList.config")
    producing = world.getObjectParameter(pane.sourceEntity(), "producing")
    if not producing then
        setOutput()
    end
    displayOutputs()
end

function setOutput()
    if not world.terrestrial() then return end
    local celestialCoords, isCelestial = player.worldId():gsub("^CelestialWorld%:", "")
    if not isCelestial then return end

    producing = jarray()
    for _, v in ipairs(celestial.planetOres(celestialCoords, world.threatLevel())) do
        local modConfig = root.modConfig(v)
        if modConfig.config.itemDrop then
            table.insert(producing, {
                name = modConfig.config.itemDrop, count = 1,
            })
        end
    end
    for _, v in ipairs(world.biomeBlocksAt(world.entityPosition(pane.sourceEntity()))) do
        local materialConfig = root.materialConfig(materialList[v])
        if materialConfig.config.itemDrop then
            table.insert(producing, {
                name = materialConfig.config.itemDrop, count = 1,
            })
        end
    end
    world.sendEntityMessage(pane.sourceEntity(), "setOutput", producing)
end

function displayOutputs()
    _ENV.extractorScrollArea:clearChildren()
    sb.logInfo(sb.printJson(producing,2))
    for _, product in ipairs(producing) do
        local itemConfig = root.itemConfig(product)
        local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
        _ENV.extractorScrollArea:addChild({
            type = "panel",
            style = "convex",
            expandMode = { 1, 0 },
            children = {
                { mode = "v" },
                {
                    { type = "itemSlot", item = sb.jsonMerge(product, { count = 1 }) },
                    {
                        { type = "label", text = merged.shortdescription },
                        {
                            { type = "label", text = tostring(product.count), inline = true },
                            { type = "label", text = "Per Second",          inline = true }
                        },

                    }
                }
            },
        })
    end
end

function _ENV.resetOutput:onClick()
    setOutput()
    displayOutputs()
end
