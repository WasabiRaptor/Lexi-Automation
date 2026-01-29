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
	end
end

function _ENV.channelTextBox:onTextChanged()
	if (not _ENV.metagui.inputData.supported) or not world.terrestrial() then
		return
	end
	serverChannels[serverUuid][self.text] = serverChannels[serverUuid][self.text] or {}
	local used = serverChannels[serverUuid][self.text]
	if self.text == "" then
		_ENV.channelStatusLabel.color = nil
		_ENV.channelStatusLabel:setText("Input a channel name.")
	elseif used and used[channelProperty] and ((player.worldId() ~= used[channelProperty].worldId) or (world.entityUniqueId(pane.sourceEntity()) ~= used[channelProperty].uniqueId)) then
		_ENV.channelStatusLabel.color = "FF0000"
		_ENV.channelStatusLabel:setText("Channel is already in use.")
	else
		used[channelProperty] = {
			uniqueId = world.entityUniqueId(pane.sourceEntity()),
			worldId = player.worldId()
		}
		if channel ~= "" then
			serverChannels[serverUuid][channel][channelProperty] = nil
		end
		channel = self.text
		_ENV.channelStatusLabel.color = "00FF00"
		_ENV.channelStatusLabel:setText("Channel is available.")
		world.sendEntityMessage(pane.sourceEntity(), "setChannel", channel, used[swapper[channelProperty]], used[channelProperty])
		player.setProperty("wr_serverRelayChannels", serverChannels)
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
