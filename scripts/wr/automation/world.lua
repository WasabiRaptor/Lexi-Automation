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

	storage.powerStorage = storage.powerStorage or 0
end

function update(dt)
	local powerProduction = world.getProperty("wr_powerProduction") or 0
	local powerConsumption = world.getProperty("wr_powerConsumption") or 0
	local powerStorage = world.getProperty("wr_powerStorage") or 0

	-- storage.powerStorage = math.max(0,math.min(powerStorage, storage.powerStorage + (dt * (powerProduction - powerConsumption))))
	-- world.setProperty("wr_powerStorageAvailable", storage.powerStorage > 0)
end

function uninit()

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
