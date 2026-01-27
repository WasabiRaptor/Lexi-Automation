
local oreNoiseConfig
function oreNoise(itemId, worldSeed)
    if not oreNoiseConfig then oreNoiseConfig = root.assetJson("/scripts/wr/automation/oreNoise.config") end
    local itemSeed = sb.staticRandomI32(itemId)
    local itemConfig = root.itemConfig(itemId)
    local parameters = sb.jsonMerge(
        oreNoiseConfig.baseParameters,
        sb.jsonMerge(
            oreNoiseConfig.rarityParameters[(itemConfig.config.rarity or "common"):lower()] or
            oreNoiseConfig.rarityParameters.common,
            itemConfig.config.wr_oreNoiseParameters or {}
        )
    )
    parameters.seed = worldSeed + itemSeed
    return sb.makePerlinSource(parameters)
end
local sufaceLayerTop
local surfaceThickness
local surfaceLayer
local undergroundThickness
local coreLayer
function setupPlanetParameters(visitableParameters)
    sufaceLayerTop = visitableParameters.surfaceLayer.layerBaseHeight
    surfaceThickness = visitableParameters.surfaceLayer.layerBaseHeight - visitableParameters.surfaceLayer.layerMinHeight
    surfaceLayer = visitableParameters.surfaceLayer.layerMinHeight
    coreLayer = visitableParameters.coreLayer.layerBaseHeight
    undergroundThickness = surfaceLayer - coreLayer
end

function getOreCount(position, noise, multiplier)
    local depthMultipler = 1
    if position[2] > sufaceLayerTop then
        depthMultipler = 0
    elseif position[2] > surfaceLayer then
        depthMultipler = (sufaceLayerTop-position[2]) / surfaceThickness
    elseif position[2] > coreLayer then
        depthMultipler = 1 + (surfaceLayer-position[2]) / undergroundThickness
    else
        depthMultipler = 2 + (coreLayer-position[2]) / coreLayer
    end
    local amount = (math.ceil(noise:get(position[1], position[2]) * depthMultipler * (multiplier or 1) * 1000) - 500) / 1000
    return math.max(0, amount)
end
