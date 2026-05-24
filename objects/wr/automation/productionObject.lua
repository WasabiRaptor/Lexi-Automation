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
		if wr_automation.checkPowered(config.getParameter("activePowerConsumption")) then
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
		wr_automation.addPollution(config.getParameter("idleWasteRadiaton"))
		wr_automation.usePower(config.getParameter("idlePowerConsumption"))
		wr_automation.clearAllOutputs()
		object.setConfigParameter("status", "off")
		wr_automation.playAnimations("off")
		return
	end
	local activePowerConsumption = config.getParameter("activePowerConsumption")
	wr_automation.usePower(activePowerConsumption)
	if wr_automation.checkPowered(activePowerConsumption) then
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
	local outputs, totalItems = wr_automation.setOutputs(products)
	wr_automation.addPollution((outputCount == 0 and totalItems or 0) + (config.getParameter("activePollution") or 0))
end

function onNodeConnectionChange(...)
	old.onNodeConnectionChange(...)
	refreshOutput()
end
