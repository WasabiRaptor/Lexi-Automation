require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

local products
function init()
	products = world.getObjectParameter(pane.sourceEntity(), "matterStreamInput")
	displayProducts(products, {
		type = "label",
		align = "center",
		text = "Recieving no items.",
	})
end
