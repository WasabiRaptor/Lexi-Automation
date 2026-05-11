require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

local products
function init()
	local powerProduction = world.getProperty("wr_powerProduction") or 0
	local powerConsumption = world.getProperty("wr_powerConsumption") or 0
	_ENV.powerProductionLabel:setText(tostring(clipAtThousandth(powerProduction)))
	_ENV.powerConsumptionLabel:setText(tostring(clipAtThousandth(powerConsumption)))

	if powerProduction > 0 then
		_ENV.powerConsumptionPercentageLabel:setText(("%d%%"):format(math.ceil((powerConsumption / powerProduction) * 100)))
	end

	products = {}
	-- foreseeing this becoming very large later so doing a binary sort insert for better performance
	local function insertProduct(product)
		local upperBounds = #products + 1
		local lowerBounds = 1
		while true do
			if (upperBounds == lowerBounds) then
				table.insert(products, upperBounds, product)
				return
			end
			local index = math.floor((upperBounds - lowerBounds) / 2) + lowerBounds
			if products[index].count > product.count then
				lowerBounds = index + 1
			else
				upperBounds = index
			end
		end
	end
	for productKey, _ in pairs(world.getProperty("wr_productKeys") or {}) do
		local product = world.getProperty("wr_product."..productKey)
		if product then
			product.count = world.getProperty("wr_productProduced."..productKey) or 0
			if product.count > 0 then
				insertProduct(product)
			end
		end
	end
	displayProducts({products}, {
		type = "label",
		align = "center",
		text = "Producing no items.",
	})
end

function _ENV.resetButton:onClick()
	for productKey, _ in pairs(world.getProperty("wr_productKeys") or {}) do
		world.setProperty("wr_product."..productKey, nil)
		world.setProperty("wr_productProduced."..productKey, nil)
	end
	world.setProperty("wr_powerProduction",0)
	world.setProperty("wr_powerConsumption",0)
	world.setProperty("wr_powerStorage",0)
	world.setProperty("wr_productKeys", {})
	world.setProperty("wr_productionResetTime", os.time())
end
