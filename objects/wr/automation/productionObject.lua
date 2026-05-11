require("/objects/wr/automation/wr_automation.lua")
local old = {
	init = init or function() end,
	onNodeConnectionChange = onNodeConnectionChange or function() end
}

local outputCount
local products
function init()
	old.init()
	wr_automation.init()
	products = config.getParameter("products")
	message.setHandler("setProducts", function(_, _, newProducts)
		if compare(products, newProducts) then return end
		products = newProducts
		wr_automation.setProducts(newProducts)
		refreshOutput(true)
	end)

	if products then
		if wr_automation.checkPowered() then
			object.setConfigParameter("status", "on")
			wr_automation.playAnimations("on")
		else
			object.setConfigParameter("status", "lowPower")
			wr_automation.playAnimations("lowPower")
		end
	end
end

function die()
	wr_automation.setProducts(nil)
	wr_automation.usePower(0)
	wr_automation.producePower(0)
end

function refreshOutput(force)
	if not products then
		wr_automation.usePower(0)
		wr_automation.clearAllOutputs()
		object.setConfigParameter("status", "off")
		wr_automation.playAnimations("off")
		return
	end
	wr_automation.usePower(config.getParameter("activePowerConsumption"))

	if wr_automation.checkPowered() then
		object.setConfigParameter("status", "on")
		wr_automation.playAnimations("on")
	else
		object.setConfigParameter("status", "lowPower")
		wr_automation.playAnimations("lowPower")
	end

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
