function init()

    message.setHandler("wr_oreScannerData", function()
        local scannerData = {}
        local celestialCoords, isCelestial = player.worldId():gsub("^CelestialWorld%:", "")
        if isCelestial > 0 then
            scannerData.celestialCoords = celestialCoords
            scannerData.planetOres = celestial.planetOres(celestialCoords, world.threatLevel())
            scannerData.planetSeed = celestial.planetSeed(celestialCoords)
            scannerData.planetParameters = celestial.planetParameters(celestialCoords)
            scannerData.visitableParameters = celestial.visitableParameters(celestialCoords)
        end
        return scannerData
    end)
end
