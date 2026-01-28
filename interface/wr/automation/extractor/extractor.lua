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
		producing = setOutput()
	end
	displayOutputs()
end

function setOutput()
	if not world.terrestrial() then return end
	local celestialCoords, isCelestial = player.worldId():gsub("^CelestialWorld%:", "")
	if not isCelestial then return end
	local visitableParameters = celestial.visitableParameters(celestialCoords)
	setupPlanetParameters(visitableParameters)

	local sufaceLayerTop = visitableParameters.surfaceLayer.layerBaseHeight

	local position = world.entityPosition(pane.sourceEntity())

	local multiplier = world.getObjectParameter(pane.sourceEntity(), "multiplier")
	producing = jarray()
	for _, v in ipairs(celestial.planetOres(celestialCoords, world.threatLevel())) do
		local modConfig = root.modConfig(v)
		if modConfig.config.itemDrop then
			local noise = oreNoise(modConfig.config.itemDrop, celestial.planetSeed(celestialCoords))
			-- get count at current position
			local count = getOreCount(position, noise, multiplier)
			-- get trace amounts of ores below in the column
			local traceCount = 0
			for i = math.min(position[2] - 1, sufaceLayerTop), 0, -1 do
				traceCount = traceCount + getOreCount({ position[1], i }, noise, 1)
			end
			traceCount = (math.ceil(traceCount * world.getObjectParameter(pane.sourceEntity(), "columnMultiplier") * 1000)-500)/1000
			table.insert(producing, {
				name = modConfig.config.itemDrop, count = count + traceCount,
			})
		end
	end
	for _, v in ipairs(world.biomeBlocksAt(position)) do
		local success, materialConfig = pcall(root.materialConfig, v) -- this will accept the ID if OSB is installed
		if not success then
			success, materialConfig = pcall(root.materialConfig, materialList[v]) -- if OSB isn't installed, then we try putting it into this map of materials
		end
		if success and materialConfig.config.itemDrop then
			local item =  {
				name = materialConfig.config.itemDrop, count = (1 * multiplier),
			}
			local found = false
			for _, v in ipairs(producing) do
				if root.itemDescriptorsMatch(v, item, true) then
					v.count = v.count + (1 * multiplier)
					found = true
					break
				end
			end
			if not found then
				table.insert(producing, item)
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
	displayOutputs()
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

-- function _ENV.resetOutput:onClick()
--     setOutput()
--     displayOutputs()
-- end
