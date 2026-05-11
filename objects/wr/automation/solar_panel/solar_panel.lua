require("/objects/wr/automation/wr_automation.lua")
local activeTimeRange
function init()
	wr_automation.init()
	activeTimeRange = config.getParameter("activeTimeRange") or {0,1}
end


function update(dt)
	local pos = object.position()
	if world.underground(pos) or world.lineTileCollision(pos, {pos[1],pos[2]+20}) then
		animator.setAnimationState("sensorState", "min")
		object.setOutputNodeLevel(0, false)
		wr_automation.producePower(0)
		return
	end
	local timeOfDay = world.timeOfDay()
	if ((timeOfDay > activeTimeRange[1]) and (timeOfDay < activeTimeRange[2]))
	or ((activeTimeRange[1] > activeTimeRange[2]) and ((timeOfDay > activeTimeRange[1]) or (timeOfDay < activeTimeRange[2])))
	then
		object.setOutputNodeLevel(0, true)
		animator.setAnimationState("sensorState", "max")
		wr_automation.producePower(config.getParameter("peakPower"))
	else
		object.setOutputNodeLevel(0, false)
		animator.setAnimationState("sensorState", "med")
		wr_automation.producePower(config.getParameter("lowPower"))
	end
end

function die()
	wr_automation.producePower(0)
end
