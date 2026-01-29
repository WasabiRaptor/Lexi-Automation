require("/scripts/util.lua")
require("/interface/games/util.lua")

function uninit()
end

local channel
local channelProperty = _ENV.metagui.inputData.channelProperty
function init()
    channel = world.getObjectParameter(pane.sourceEntity(), "channel") or ""
    _ENV.channelTextBox:setText(channel)
end

function _ENV.channelTextBox:onTextChanged()
    local used = world.getProperty(channelProperty .. self.text)
    if self.text == "" then
        _ENV.channelStatusLabel.color = nil
        _ENV.channelStatusLabel:setText("Input a channel name.")
    elseif used and (world.entityUniqueId(pane.sourceEntity()) ~= used) then
        _ENV.channelStatusLabel.color = "FF0000"
        _ENV.channelStatusLabel:setText("Channel is already in use.")
    else
        channel = self.text
        _ENV.channelStatusLabel.color = "00FF00"
        _ENV.channelStatusLabel:setText("Channel is available.")
        world.sendEntityMessage(pane.sourceEntity(), "setChannel", channel)
    end
end
