require("/objects/wr/automation/wr_automation.lua")
local old = {
	init = init or function() end,
	onNodeConnectionChange = onNodeConnectionChange or function() end
}

local outputCount
local products
function init()
	old.init()
	products = config.getParameter("products")
	message.setHandler("setProducts", function(_, _, newProducts)
		if compare(products, newProducts) then return end
		products = newProducts
		object.setConfigParameter("products", products)
		refreshOutput(true)
	end)

	if products then
		animator.setAnimationState("producing", "on")
	end
end


function refreshOutput(force)
	if not products then
		object.setConfigParameter("matterStreamOutput", nil)
		object.setAllOutputNodes(false)
		animator.setAnimationState("producing", "off")
		return
	end
	animator.setAnimationState("producing", "on")

	local outputNodes = object.getOutputNodeIds(0)
	local newOutputCount = 0
	for _, _ in pairs(outputNodes) do
		newOutputCount = newOutputCount + 1
	end
	if (not force) and (newOutputCount == outputCount) then return end
	outputCount = newOutputCount
	wr_automation.setOutputs(products)
end

function onNodeConnectionChange(...)
	old.onNodeConnectionChange(...)
	refreshOutput()
end
