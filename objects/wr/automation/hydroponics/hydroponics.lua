local plantImages
function init()
	plantImages = config.getParameter("plantImages")
	animator.setPartTag("leftPlant", "partImage", storage.plantImage or "")
	animator.setPartTag("leftPlant", "variant", tostring(storage.leftPlantVariant or 1))
	animator.setPartTag("rightPlant", "partImage", storage.plantImage or "")
	animator.setPartTag("rightPlant", "variant", tostring(storage.leftPlantVariant or 1))
end

function containerCallback()
	local item = world.containerItemAt(1)
	if item then
		if plantImages[item.name] then
			storage.plantImage = plantImages[item.name].image
			storage.leftPlantVariant = math.random(plantImages[item.name].variants)
			storage.rightPlantVariant = math.random(plantImages[item.name].variants)
		else
			storage.plantImage = "animationParts/default.png"
			storage.leftPlantVariant = math.random(5)
			storage.rightPlantVariant = math.random(5)
		end
	else
		storage.plantImage = ""
		storage.leftPlantVariant = 1
		storage.rightPlantVariant = 1
	end
	animator.setPartTag("leftPlant", "partImage", storage.plantImage or "")
	animator.setPartTag("leftPlant", "variant", tostring(storage.leftPlantVariant or 1))
	animator.setPartTag("rightPlant", "partImage", storage.plantImage or "")
	animator.setPartTag("rightPlant", "variant", tostring(storage.leftPlantVariant or 1))
end
