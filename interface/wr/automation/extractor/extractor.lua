require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/scripts/wr/automation/oreNoise.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

local materialList
local products
function init()
	materialList = root.assetJson("/interface/wr/automation/extractor/materialList.config")
	products = world.getObjectParameter(pane.sourceEntity(), "products")
	if not products then
		setProducts()
	end
	displayProducts(products, {
		type = "label",
		color = "FF0000",
		text = "Resource veins can only be found on terrestrial worlds with valid celestial coordinates.",
	}, {
		{
			type = "label",
			color = "FF0000",
			text = "No resources found at this position.",
		}
	})
end

function setProducts()
	if not world.terrestrial() then return end
	local celestialCoords, isCelestial = player.worldId():gsub("^CelestialWorld%:", "")
	if not (isCelestial > 0) then return end
	local visitableParameters = celestial.visitableParameters(celestialCoords)
	setupPlanetParameters(visitableParameters)

	local sufaceLayerTop = visitableParameters.surfaceLayer.layerBaseHeight

	local position = world.entityPosition(pane.sourceEntity())

	local multiplier = world.getObjectParameter(pane.sourceEntity(), "multiplier") or 1
	products = jarray()
	products[1] = jarray()
	local function addProduct(nodeProducts, item)
		local found = false
		for _, v in ipairs(nodeProducts) do
			if root.itemDescriptorsMatch(v, item, true) then
				v.count = v.count + item.count
				found = true
				break
			end
		end
		if not found then
			table.insert(nodeProducts, item)
		end
	end

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
			traceCount = math.max(0,(math.ceil(traceCount * world.getObjectParameter(pane.sourceEntity(), "columnMultiplier") * 1000)-500)/1000)
			addProduct(products[1], {
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
			addProduct(products[1], {
				name = materialConfig.config.itemDrop, count = (multiplier),
			})
		end
	end
	products[1] = util.filter(products[1], function (v)
		return v.count > 0
	end)
	table.sort(products[1], function (a, b)
		return a.count > b.count
	end)

	world.sendEntityMessage(pane.sourceEntity(), "setProducts", products)
end
