require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

local products
function init()
	products = world.getObjectParameter(pane.sourceEntity(), "products")
	local status = world.getObjectParameter(pane.sourceEntity(), "status")
	local statusLabels = world.getObjectParameter(pane.sourceEntity(), "statusLabels")
    local machineDesc = world.getObjectParameter(pane.sourceEntity(), "machineDescription")
	if machineDesc then
		_ENV.machineDescLabel:setText(machineDesc)
	end
	if status and statusLabels and statusLabels[status] then
		_ENV.statusLabel.color = statusLabels[status].color
		_ENV.statusLabel:setText(statusLabels[status].text)
	end
	displayProducts(products)
end
