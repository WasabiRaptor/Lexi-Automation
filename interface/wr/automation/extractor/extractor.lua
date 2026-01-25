require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/scripts/wr/automation/oreNoise.lua")
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
    setupPlanetParameters(celestial.visitableParameters(celestialCoords))

    local position = world.entityPosition(pane.sourceEntity())

    producing = jarray()
    for _, v in ipairs(celestial.planetOres(celestialCoords, world.threatLevel())) do
        local modConfig = root.modConfig(v)
        if modConfig.config.itemDrop then
            local noise = oreNoise(modConfig.config.itemDrop, celestial.planetSeed(celestialCoords))
            table.insert(producing, {
                name = modConfig.config.itemDrop, count = getOreCount(position, noise),
            })
        end
    end
    for _, v in ipairs(world.biomeBlocksAt(position)) do
        local materialConfig = root.materialConfig(materialList[v])
        if materialConfig.config.itemDrop then
            local item =  {
                name = materialConfig.config.itemDrop, count = 1,
            }
            local found = false
            for _, v in ipairs(producing) do
                if root.itemDescriptorsMatch(v, item, true) then
                    v.count = v.count + 1
                    found = true
                    break
                end
            end
            if not found then
                table.insert(producing, {
                    name = materialConfig.config.itemDrop, count = 1,
                })
            end
        end
    end
    producing = util.filter(producing, function (v)
        return v.count > 0
    end)
    table.sort(producing, function (a, b)
        return a.count > b.count
    end)

    world.sendEntityMessage(pane.sourceEntity(), "setOutput", producing)
end

function displayOutputs()
    _ENV.extractorScrollArea:clearChildren()
    if producing then
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
                                { type = "label", text = "Per Second",            inline = true }
                            },

                        }
                    }
                },
            })
        end
    else
        _ENV.extractorScrollArea:addChild({type = "label", color = "FF0000", text = "Resource veins can only be found on terrestrial worlds with valid celestial coordinates."})
    end
end

function _ENV.resetOutput:onClick()
    setOutput()
    displayOutputs()
end
