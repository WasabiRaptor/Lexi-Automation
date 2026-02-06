local plantImages
function init()
	message.setHandler("setPlantImage", function (_,_,...)
		setPlantImage(...)
	end)
	plantImages = config.getParameter("plantImages")
	animator.setPartTag("leftPlant", "partImage", storage.plantImage or "")
	animator.setPartTag("leftPlant", "variant", tostring(storage.leftPlantVariant or 1))
	animator.setPartTag("rightPlant", "partImage", storage.plantImage or "")
	animator.setPartTag("rightPlant", "variant", tostring(storage.rightPlantVariant or 1))
	if (storage.plantImage == "animationParts/plants/default.png") and storage.plantName and plantImages[storage.plantName] then
		setPlantImage(storage.plantName)
	end
end

function setPlantImage(plantName)
	storage.plantName = plantName
	if plantName then
		if plantImages[plantName] then
			storage.plantImage = plantImages[plantName].image
			storage.leftPlantVariant = math.random(plantImages[plantName].variants)
			storage.rightPlantVariant = math.random(plantImages[plantName].variants)
		else
			storage.plantImage = "animationParts/plants/default.png"
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
	animator.setPartTag("rightPlant", "variant", tostring(storage.rightPlantVariant or 1))
end
