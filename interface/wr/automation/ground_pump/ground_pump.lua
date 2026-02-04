require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

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
		align = "center",
		text = "Liquids only be pumped on terrestrial worlds with valid celestial coordinates.",
	},{
		{
			type = "label",
			color = "FF0000",
			align = "center",
			text = "No liquids found in this planetary layer.",
		}
	})
end

local layerOrder = {
	"spaceLayer",
	"atmosphereLayer",
	"surfaceLayer",
	"subsurfaceLayer",
	"undergroundLayers",
	"coreLayer"
}
function setProducts()
	if not world.terrestrial() then return end
	local celestialCoords, isCelestial = player.worldId():gsub("^CelestialWorld%:", "")
	if not (isCelestial > 0) then return end
	local visitableParameters = celestial.visitableParameters(celestialCoords)
	local position = world.entityPosition(pane.sourceEntity())
	local multiplier = world.getObjectParameter(pane.sourceEntity(), "multiplier") or 1

	local layers = {}
	for _, layerName in ipairs(layerOrder) do
		if layerName == "undergroundLayers" then
			for _, v in ipairs(visitableParameters.undergroundLayers) do
				table.insert(layers, v)
			end
		else
			table.insert(layers, visitableParameters[layerName])
		end
	end
	local currentLayer
	for _, layer in ipairs(layers) do
		if position[2] >= layer.layerMinHeight then
			currentLayer = layer
			break
		end
	end
	if not currentLayer then return end

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
	local function addLiquid(liquidid, regionMultiplier)
		local liquidConfig = root.liquidConfig(liquidid)
		if liquidConfig.config.itemDrop and not liquidConfig.config.wr_ignoreItemDrop then
			addProduct(products[1], {
				item = liquidConfig.config.itemDrop, count = regionMultiplier * multiplier
			})
		end
		for _, v in ipairs(liquidConfig.config.wr_groundPumpItems or {}) do
			v.count = v.count * regionMultiplier * multiplier
			addProduct(products[1], v)
		end
	end

	local function addRegionLiquids(region)
		if region.oceanLiquid ~= 0 then
			if position[2] <= region.oceanLiquidLevel then
				addLiquid(region.oceanLiquid, 10)
			end
		end
		if region.caveLiquid ~= 0 then
			addLiquid(region.caveLiquid, region.caveLiquidSeedDensity)
		end
	end
	addRegionLiquids(currentLayer.primaryRegion)
	addRegionLiquids(currentLayer.primarySubRegion)
	for _, region in ipairs(currentLayer.secondaryRegions) do
		addRegionLiquids(region)
	end
	for _, region in ipairs(currentLayer.secondarySubRegions) do
		addRegionLiquids(region)
	end
	if (position[2] >= visitableParameters.subsurfaceLayer.layerBaseHeight)
		and (position[2] < visitableParameters.atmosphereLayer.layerMinHeight) then
		if visitableParameters.surfaceLiquid ~= 0 then
			addLiquid(visitableParameters.surfaceLiquid, 1)
		end
	end
	for _, v in ipairs(products[1]) do
		v.count = (math.ceil(v.count * 1000) - 500) / 1000
	end

	products[1] = util.filter(products[1], function (v)
		return v.count > 0
	end)
	table.sort(products[1], function (a, b)
		return a.count > b.count
	end)

	world.sendEntityMessage(pane.sourceEntity(), "setProducts", products)
end
