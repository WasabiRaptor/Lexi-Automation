require("/objects/wr/automation/wr_automation.lua")

local recipe
local outputCount
local inputs
function init()
    script.setUpdateDelta(0)
    recipe = config.getParameter("recipe")
    message.setHandler("setRecipe", function(_, _, newRecipe)
        if sb.jsonEqual(recipe, newRecipe) then return false end
        recipe = newRecipe
        object.setConfigParameter("recipe", newRecipe)
        refreshOutput(true)
        return true
    end)
    inputs = config.getParameter("matterStreamInput")
    message.setHandler("refreshInputs", function (_,_)
        refreshOutput()
    end)
end


function refreshOutput(force)
    if (not recipe) or (not object.isInputNodeConnected(0)) or (not object.getInputNodeLevel(0)) then
        object.setOutputNodeLevel(0, false)
        object.setConfigParameter("matterStreamOutput", nil)
        inputs = nil
        object.setConfigParameter("matterStreamInput", nil)
        return
    end
    local outputNodes = object.getOutputNodeIds(0)
    local newOutputCount = 0
    for _, _ in pairs(outputNodes) do
        newOutputCount = newOutputCount + 1
    end
    local newInputs = wr_automation.countInputs(recipe)
    if (not force) and sb.jsonEqual(newInputs, inputs) and (newOutputCount == outputCount) then return end
    object.setConfigParameter("matterStreamInput", newInputs)
    inputs = newInputs
    outputCount = newOutputCount

    local craftingSpeed = config.getParameter("craftingSpeed") or 1
    local productionRate = craftingSpeed / math.max(
        0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
        (config.getParameter("minimumDuration") or 0),
        (recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
    )

    for _, recipeItem in ipairs(recipe.input) do
        for _, inputItem in ipairs(inputs) do
            if root.itemDescriptorsMatch(recipeItem, inputItem, recipe.matchInputParameters) then
                recieved = true
                productionRate = math.min(productionRate, (inputItem.count / (recipeItem.count or 1)) * craftingSpeed)
                break
            end
        end
    end
    local producing = productionRate * (recipe.output.count or 1)
    if productionRate > 0 then
        -- count the number of entities the output is connected to so it's split evenly between them
        local output = {
            {sb.jsonMerge(recipe.output, {count = producing / outputCount})}
        }
        if sb.jsonEqual(config.getParameter("matterStreamOutput"), output) then return end

        object.setOutputNodeLevel(0, true)
        object.setConfigParameter("matterStreamOutput", output)
        for eid, _ in pairs(outputNodes) do
            world.sendEntityMessage(eid, "refreshInputs")
        end
    else
        object.setOutputNodeLevel(0, false)
        object.setConfigParameter("matterStreamOutput", nil)
    end

end
function onInputNodeChange()
    refreshOutput()
end
function onNodeConnectionChange()
    refreshOutput()
end
