local powerStorage
function init()
	world.setExpiryTime(math.max(1, world.expiryTime()))
	message.setHandler("wr_keepAlive", function(_, _, expireTime)
		world.setExpiryTime(math.max(1, expireTime, world.expiryTime()))
	end)

	message.setHandler("wr_refreshInputs", function(_, _, uniqueId, ...)
		world.sendEntityMessage(uniqueId, "refreshInputs", ...)
	end)
	message.setHandler("wr_refreshOutput", function(_, _, uniqueId, ...)
		world.sendEntityMessage(uniqueId, "refreshOutput", ...)
	end)
	message.setHandler("wr_getPowerStorage", function(_, _)
		world.setProperty("wr_powerStorage", powerStorage)
		return powerStorage
	end)

	powerStorage = world.getProperty("wr_powerStorage") or 0
end

function update(dt)
	local powerProduction = world.getProperty("wr_powerProduction") or 0
	local powerConsumption = world.getProperty("wr_powerConsumption") or 0
	local powerStorageCapacity = world.getProperty("wr_powerStorageCapacity") or 0

	powerStorage = math.max(0,math.min(powerStorageCapacity, powerStorage + (dt * (powerProduction - powerConsumption))))
	world.setProperty("wr_powerStorageAvailable", powerStorage > 0)
end

function uninit()
	world.setProperty("wr_powerStorage", powerStorage)
end

function addClient(clientId, isLocal)

end
function removeClient(clientId)

end

function refreshInputs(targetEntity, ...)
	universe.sendWorldMessage(targetEntity.worldId, "wr_refreshInputs", targetEntity.uniqueId, ...)
end

function refreshOutput(targetEntity, ...)
	universe.sendWorldMessage(targetEntity.worldId, "wr_refreshOutput", targetEntity.uniqueId, ...)
end
