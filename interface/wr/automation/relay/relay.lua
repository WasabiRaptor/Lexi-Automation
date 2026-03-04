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

local cdt = 0
function update()
	cdt = cdt + script.updateDt()
	if cdt > 1 then
		cdt = 0
		local newInput = world.getObjectParameter(pane.sourceEntity(), "matterStreamInput")
		if not compare(products, newInput) then
			products = newInput
			displayProducts(products, {
				type = "label",
				align = "center",
				text = "Recieving no items.",
			})
		end
	end
end
