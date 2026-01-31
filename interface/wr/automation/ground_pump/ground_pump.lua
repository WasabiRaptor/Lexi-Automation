require("/scripts/util.lua")
require("/interface/games/util.lua")
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
		text = "Liquids only be pumped on terrestrial worlds with valid celestial coordinates.",
	},{
		{
			type = "label",
			color = "FF0000",
			text = "No liquids found in this planetary layer.",
		}
	})
end

function setProducts()
	if not world.terrestrial() then return end
	local celestialCoords, isCelestial = player.worldId():gsub("^CelestialWorld%:", "")
	if not (isCelestial > 0) then return end
	local visitableParameters = celestial.visitableParameters(celestialCoords)
	local position = world.entityPosition(pane.sourceEntity())
	local multiplier = world.getObjectParameter(pane.sourceEntity(), "multiplier")

	sb.logInfo(sb.printJson(visitableParameters,2))

    products = jarray()
	products[1] = jarray()

	products[1] = util.filter(products[1], function (v)
		return v.count > 0
	end)
	table.sort(products[1], function (a, b)
		return a.count > b.count
	end)

	world.sendEntityMessage(pane.sourceEntity(), "setProducts", products)
end
