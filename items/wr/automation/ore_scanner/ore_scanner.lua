require "/scripts/vec2.lua"
require("/scripts/wr/automation/oreNoise.lua")
local planetData
local pingSpeed
local pingRange
local aimAngle
local aimDirection
function init()
	pingRange = config.getParameter("pingRange")
	pingSpeed = config.getParameter("pingSpeed")

	local detectConfig = config.getParameter("pingDetectConfig")
	detectConfig.maxRange = pingRange
	activeItem.setScriptedAnimationParameter("pingDetectConfig", sb.jsonMerge(root.assetJson("/items/active/unsorted/oredetector/oredetector.activeitem:pingDetectConfig"), detectConfig))
	activeItem.setScriptedAnimationParameter("pingLocation", nil)

end

function uninit()

end

local pinging = false
local outerRadius = 0
function update(dt, fireMode, shiftHeld)
	updateAim()
	if not planetData then
		planetData = world.sendEntityMessage(player.id(), "wr_oreScannerData"):result()
		activeItem.setScriptedAnimationParameter("planetData", planetData)
	end

	if pinging then
		if outerRadius < pingRange then
			outerRadius = math.min(pingRange, outerRadius + (pingSpeed * dt))
		else
			pinging = false
			activeItem.setScriptedAnimationParameter("pingLocation", nil)
		end

		activeItem.setScriptedAnimationParameter("pingOuterRadius", outerRadius)
	end
end

function activate(fireMode, shiftHeld)
	if shiftHeld then
		player.interact("ScriptPane", { gui = {}, scripts = { "/metagui.lua" }, ui = "wr_automation:scanner" })
		return
	end
	if ready() then
		outerRadius = 0
		pinging = true
		local pingOffset = animator.partPoint("detector", "pingPosition")
		pingOffset[1] = pingOffset[1] * aimDirection
		local pingLocation = vec2.floor(vec2.add(mcontroller.position(), pingOffset))
		activeItem.setScriptedAnimationParameter("pingLocation", pingLocation)
		animator.playSound("ping")
	end
end

function updateAim()
	aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
	activeItem.setFacingDirection(aimDirection)
end

function ready()
	return not pinging
end
