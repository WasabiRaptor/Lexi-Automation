require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/displayProducts.lua")
function uninit()
end

local products
function init()
	local powerProduction = world.getProperty("wr_powerProduction") or 0
	local powerConsumption = world.getProperty("wr_powerConsumption") or 0
	local wasteRadiation = world.getProperty("wr_wasteRadiation") or 0
	local powerScale, shortLabel, longLabel = kilowattScale(powerProduction)

	if powerProduction > 0 then
		local percentage = (powerConsumption / powerProduction)
		local color = ("%02x%02x%02x"):format(hsv2rgb(util.lerp(math.min(percentage,1),.25,0),1,1))
		_ENV.powerConsumptionPercentageLabel.color = color
		_ENV.powerConsumptionLabel.color = color
		_ENV.powerConsumptionPercentageLabel:setText(("%d%%"):format(math.ceil( percentage * 100)))
	end
	_ENV.powerProductionLabel:setText(tostring(clipAtThousandth(powerProduction * powerScale)))
	_ENV.powerConsumptionLabel:setText(tostring(clipAtThousandth(powerConsumption * powerScale)))
	_ENV.powerScaleLabel:setText(shortLabel)

	_ENV.radiationLabel:setText(tostring(clipAtThousandth(wasteRadiation)))
	_ENV.resetButton:setVisible(player.isAdmin())

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
	world.setProperty("wr_wasteRadiation",0)
	world.setProperty("wr_powerProduction",0)
	world.setProperty("wr_powerConsumption",0)
	world.setProperty("wr_powerStorage",0)
	world.setProperty("wr_productKeys", {})
	world.setProperty("wr_productionResetTime", world.time())
end

function hsv2rgb(h, s, v)
	local C = v * s
	local m = v - C
	local r, g, b = m, m, m
	if h == h then
		local h_ = (h % 1.0) * 6
		local X = C * (1 - math.abs(h_ % 2 - 1))
		C, X = C + m, X + m
		if h_ < 1 then
			r, g, b = C, X, m
		elseif h_ < 2 then
			r, g, b = X, C, m
		elseif h_ < 3 then
			r, g, b = m, C, X
		elseif h_ < 4 then
			r, g, b = m, X, C
		elseif h_ < 5 then
			r, g, b = X, m, C
		else
			r, g, b = C, m, X
		end
	end
	return math.ceil(r * 255), math.ceil(g * 255), math.ceil(b *255)
end
