require "/scripts/vec2.lua"

local old = {
	init = init or function() end,
	update = update or function() end,
	uninit = uninit or function() end
}
local wr = {}
local beaconPosition
local beaconFlashTimer = 0
local beaconFlashTime = 0.75
local beaconKind
function init()
	old.init()
	message.setHandler("wr_setBeaconPosition", function(_, _, position, kind)
		beaconKind = kind
		beaconPosition = position
	end)

end

function update(dt)
	old.update(dt)
	if beaconPosition then
		wr.drawBeacon(dt)
		wr.checkBeacon()
	end
end

function wr.drawBeacon(dt)
	beaconFlashTimer = (beaconFlashTimer + dt) % beaconFlashTime
	local beaconFlash = (beaconFlashTimer / beaconFlashTime) < 0.5
	local beaconVec = world.distance(beaconPosition, entity.position())
	if vec2.mag(beaconVec) > 15 then
		local arrowAngle = vec2.angle(beaconVec)
		local arrowOffset = vec2.withAngle(arrowAngle, 5)
		localAnimator.addDrawable({
			image = beaconVec[1] > 0 and "/scripts/wr/automation/deployment/beaconarrowright.png" or
			"/scripts/wr/automation/deployment/beaconarrowleft.png",
			rotation = arrowAngle,
			position = arrowOffset,
			fullbright = true,
			centered = true,
			color = { 255, 255, 255, beaconFlash and 150 or 50 }
		}, "overlay")
	else
		localAnimator.addDrawable({
			image = "/scripts/wr/automation/deployment/beaconarrowclose.png",
			position = vec2.add(vec2.sub(beaconPosition, entity.position()), {0.5,0.5}),
			fullbright = true,
			centered = true,
			color = { 255, 255, 255, beaconFlash and 150 or 50 }
		}, "overlay")
	end

end

function wr.checkBeacon()
	if beaconKind == "resource" then
		local object = world.objectAt(beaconPosition)
		if object then
			if world.getObjectParameter(object, "isExtractor") then
				beaconPosition = nil
				beaconKind = nil
			end
		end
	end
end
