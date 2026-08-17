local needsPower = root.assetJson("/wr_automation.config:powerConsumptionEnabled")
function checkPowered()
    if not needsPower then return true end
	local activePowerConsumption = world.getObjectParameter(pane.sourceEntity(), "activePowerConsumption") or 0
	local powerConsumption = world.getObjectParameter(pane.sourceEntity(), "powerConsumption") or 0
	local powerChanged = activePowerConsumption - powerConsumption
	return world.getProperty("wr_powerStorageAvailable")
	or ((powerConsumption == 0) and (newPowerConsumption == 0))
	or ((world.getProperty("wr_powerProduction") or 0) >= ((world.getProperty("wr_powerConsumption") or 0) + powerChanged))
end
