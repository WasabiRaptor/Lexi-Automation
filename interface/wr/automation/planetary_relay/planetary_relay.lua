require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/scripts/messageutil.lua")

function uninit()
end

local channel
local channelProperty = _ENV.metagui.inputData.channelProperty
local swapper = {
	["wr_matterStreamInputUUID."] = "wr_matterStreamOutputUUID.",
	["wr_matterStreamOutputUUID."] = "wr_matterStreamInputUUID."
}

local promises = PromiseKeeper.new()
function init()
	channel = world.getObjectParameter(pane.sourceEntity(), "channel") or ""
	_ENV.channelTextBox:setText(channel)
	if world.getObjectParameter(pane.sourceEntity(), "fromExporter") then
		_ENV.channelStatusLabel.color = "FFFF00"
		_ENV.channelStatusLabel:setText("Cannot be downstream from an Exporter.")
	end
end

function _ENV.channelTextBox:onTextChanged()
	local used = world.getProperty(channelProperty .. self.text)
	if self.text == "" then
		_ENV.channelStatusLabel.color = nil
		_ENV.channelStatusLabel:setText("Input a channel name.")
	elseif used and (world.entityUniqueId(pane.sourceEntity()) ~= used) then
		_ENV.channelStatusLabel.color = "FF0000"
		_ENV.channelStatusLabel:setText("Channel is already in use.")
		promises:add(
			world.findUniqueEntity(used),
			function(pos) -- on success
				_ENV.channelStatusLabel:setText(("^#FF0000; Channel is already in use at: [%d,%d]"):format(pos[1],pos[2]))
			end,
			function() -- on failure
				world.setProperty(channelProperty .. self.text, nil)
				_ENV.channelTextBox:onTextChanged()
			end
		)
	else
		channel = self.text
		_ENV.channelStatusLabel.color = "00FF00"
		_ENV.channelStatusLabel:setText("Channel is available."..(
			checkPowered() and "" or "\n^#FF0000;Not enough power available to transport matter."
		))
		world.sendEntityMessage(pane.sourceEntity(), "setChannel", channel)
		local paired = world.getProperty(swapper[channelProperty] .. self.text)
		if paired then
			promises:add(
				world.findUniqueEntity(paired),
				function(pos) -- on success
					_ENV.channelStatusLabel:setText(("^#00FF00;Paired with ^#FFFF00;[%d,%d]"):format(pos[1],pos[2])..(
						checkPowered() and "" or "\n^#FF0000;Not enough power available to transport matter."
					))
				end,
				function() -- on failure
				end
			)
		end
	end
end

function update()
	promises:update()
end

function checkPowered()
	local activePowerConsumption = world.getObjectParameter(pane.sourceEntity(), "activePowerConsumption") or 0
	local powerConsumption = world.getObjectParameter(pane.sourceEntity(), "powerConsumption") or 0
	local powerChanged = activePowerConsumption - powerConsumption
	return world.getProperty("wr_powerStorageAvailable")
	or ((powerConsumption == 0) and (newPowerConsumption == 0))
	or ((world.getProperty("wr_powerProduction") or 0) >= ((world.getProperty("wr_powerConsumption") or 0) + powerChanged))
end
