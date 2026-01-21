local recipe
local outputs
function init()
    script.setUpdateDelta(0)
    object.setOutputNodeLevel(0,true)
end


function onNodeConnectionChange()
    -- if (not recipe) or (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
    --     object.setOutputNodeLevel(0, false)
    --     object.setConfigParameter("matterStreamOutput", nil)
    --     return
    -- end
    -- local inputs = object.getInputNodeIds(0)
    -- for k, v in pairs(inputs) do
    --     sb.logInfo("%s %s", k, v)
    -- end
    -- local rate = 1 / math.max(
    --     config.getParameter("minimumDuration") or 0.1,
    --     (recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration")) / config.getParameter("craftingSpeed")
    -- )


end
onInputNodeChange = onNodeConnectionChange
