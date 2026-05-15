require("/objects/wr/automation/wr_automation.lua")
function init()
    wr_automation.init()
    wr_automation.addPowerStorage(config.getParameter("powerStorage"))
end

function die()
    wr_automation.addPowerStorage(0)
end
