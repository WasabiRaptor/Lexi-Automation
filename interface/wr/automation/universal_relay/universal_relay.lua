require("/scripts/util.lua")
require("/interface/games/util.lua")

function uninit()
end

local channel
local channelProperty = _ENV.metagui.inputData.channelProperty
local serverChannels
local serverUuid
local swapper = {
	input = "output",
	output = "input"
}
function init()
	channel = world.getObjectParameter(pane.sourceEntity(), "channel") or ""
	serverUuid = player.serverUuid()
	serverChannels = player.getProperty("wr_serverRelayChannels") or {}
	serverChannels[serverUuid] = serverChannels[serverUuid] or {}

	_ENV.channelTextBox:setText(channel)
	if not _ENV.metagui.inputData.supported then
		_ENV.channelStatusLabel.color = "FFFF00"
		_ENV.channelStatusLabel:setText("This feature requires OpenStarbound.")
	elseif not world.terrestrial() then
		_ENV.channelStatusLabel.color = "FFFF00"
		_ENV.channelStatusLabel:setText("Must be placed on a terrestrial world.")
	elseif world.getObjectParameter(pane.sourceEntity(), "fromExporter") then
		_ENV.channelStatusLabel.color = "FFFF00"
		_ENV.channelStatusLabel:setText("Cannot be downstream from an Exporter.")
	end
end

function _ENV.channelTextBox:onTextChanged()
	if (not _ENV.metagui.inputData.supported) or not world.terrestrial() then
		return
	end
	if self.text == "" then
		_ENV.channelStatusLabel.color = nil
		_ENV.channelStatusLabel:setText("Input a channel name.")
	else
		serverChannels[serverUuid][self.text] = serverChannels[serverUuid][self.text] or {}
		if (serverChannels[serverUuid][self.text][channelProperty] ~= nil) and (
			(player.worldId() ~= serverChannels[serverUuid][self.text][channelProperty].worldId)
			or (world.entityUniqueId(pane.sourceEntity()) ~= serverChannels[serverUuid][self.text][channelProperty].uniqueId)
		)
		then
			_ENV.channelStatusLabel.color = "FF0000"
			_ENV.channelStatusLabel:setText("Channel is already in use.")
		else
			if serverChannels[serverUuid][channel] and (channel ~= self.text) then
				serverChannels[serverUuid][channel][channelProperty] = nil
				if not (serverChannels[serverUuid][channel].input and serverChannels[serverUuid][channel].output) then
					serverChannels[serverUuid][channel] = nil
				end
			end
			serverChannels[serverUuid][self.text][channelProperty] = {
				uniqueId = world.entityUniqueId(pane.sourceEntity()),
				worldId = player.worldId()
			}
			_ENV.channelStatusLabel.color = "00FF00"
			_ENV.channelStatusLabel:setText("Channel is available.")
			world.sendEntityMessage(
				pane.sourceEntity(),
				"setChannel",
				self.text,
				serverChannels[serverUuid][self.text][swapper[channelProperty]],
				serverChannels[serverUuid][self.text][channelProperty]
			)
			player.setProperty("wr_serverRelayChannels", serverChannels)
			channel = self.text
		end
	end
end

function _ENV.removeButton:onClick()
	if channel ~= "" then
		serverChannels[serverUuid][channel][channelProperty] = nil
	end
	player.setProperty("wr_serverRelayChannels", serverChannels)
	world.sendEntityMessage(pane.sourceEntity(), "remove")
	pane.dismiss()
end
