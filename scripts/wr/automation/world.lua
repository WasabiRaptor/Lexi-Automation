local pendingMessages = {}
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
end

function update(dt)
    local i = 1
    while i <= #pendingMessages do
        local message = pendingMessages[i]
        if universe.isWorldActive(message[1]) then
            universe.sendWorldMessage(table.unpack(message))
            table.remove(pendingMessages, i)
        else
            universe.sendWorldMessage(message[1], "wr_keepAlive", 5)
            i = i + 1
        end
    end
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
