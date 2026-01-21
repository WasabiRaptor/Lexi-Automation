require("/scripts/util.lua")

function uninit()
    local craftingItem = _ENV.craftingItemSlot:item()
    local craftingStation = _ENV.craftingStationSlot:item()
    local craftingAddon = _ENV.craftingAddonSlot:item()
    if craftingItem then player.giveItem(craftingItem) end
    if craftingStation then player.giveItem(craftingStation) end
    if craftingAddon then player.giveItem(craftingAddon) end
end

function init()
    refreshCurrentRecipes()
    displayRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))
end
local currentRecipes = {}
function refreshCurrentRecipes()
    currentRecipes = {}
    _ENV.craftingAddonSlot:setVisible(_ENV.craftingAddonSlot:item() ~= nil)

    local craftingItem = _ENV.craftingItemSlot:item()
    local craftingStation = _ENV.craftingStationSlot:item()

    local filter = world.getObjectParameter(pane.sourceEntity(), "filter")
    if craftingStation then
        local itemConfig = root.itemConfig(craftingStation)
        local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
        local interactData

        local craftingAddon = _ENV.craftingAddonSlot:item()
        local craftingAddonConfig
        local craftingAddonMerged
        if craftingAddon then
            craftingAddonConfig = root.itemConfig(craftingAddon)
            craftingAddonMerged = sb.jsonMerge(craftingAddonConfig.config, craftingAddonConfig.parameters)
        end
        local function doAddons(usesAddons)
            _ENV.craftingAddonSlot:setVisible(true)
            if craftingAddon then
                for _, addon in ipairs((craftingAddonMerged.addonConfig or {}).isAddons or {}) do
                    for _, addonConfig in ipairs(usesAddons) do
                        if addon.name == addonConfig.name then
                            interactData = sb.jsonMerge(interactData, addonConfig.addonData.interactData)
                        end
                    end
                end
            end
        end
        if merged.interactAction == "OpenCraftingInterface" then
            interactData = merged.interactData
        elseif merged.upgradeStages then
            local upgradeData = merged.upgradeStages[(merged.scriptStorage or {}).currentStage or merged.startingUpgradeStage]
            interactData = upgradeData.interactData
            if upgradeData.addonConfig and upgradeData.addonConfig.usesAddons then
                doAddons(upgradeData.addonConfig.usesAddons)
            end
        elseif merged.addonConfig and merged.addonConfig.usesAddons then
            _ENV.craftingAddonSlot:setVisible(true)
            doAddons(merged.addonConfig.usesAddons)
        end

        if interactData then
            filter = interactData.filter
            if interactData.recipes then
                for _, v in ipairs(filterRecipes(filter, interactData.recipes)) do
                    table.insert(currentRecipes, v)
                end
            end

        end
    end
    if craftingItem then
        currentRecipes = util.filter(currentRecipes, function(v)
            return (v.output.item or v.output.name) == (craftingItem.name or craftingItem.item)
        end)
        for _, v in ipairs(filterRecipes(filter, root.recipesForItem(craftingItem.name or craftingItem.item))) do
            table.insert(currentRecipes, v)
        end
    elseif filter and (root.allRecipes ~= nil) then
        for _, v in ipairs(root.allRecipes(filter)) do
            table.insert(currentRecipes, v)
        end
    end

    table.sort(currentRecipes, function (a, b)
        local a_config = root.itemConfig(a.output)
        local a_merged = sb.jsonMerge(a_config.config, a_config.parameters)
        local b_config = root.itemConfig(b.output)
        local b_merged = sb.jsonMerge(b_config.config, b_config.parameters)
        if sb.stripEscapeCodes ~= nil then
            return sb.stripEscapeCodes(a_merged.shortdescription) < sb.stripEscapeCodes(b_merged.shortdescription)
        else
            return a_merged.shortdescription:gsub("%b^;") < b_merged.shortdescription:gsub("%b^;")
        end
   end)

    refreshDisplayedRecipes()
end
function refreshDisplayedRecipes()
    _ENV.recipeSearchScrollArea:clearChildren()

    local searchText = _ENV.searchBox.text:lower()
    for _, recipe in ipairs(currentRecipes) do
        local id = (recipe.output.item or recipe.output.name)
        local itemConfig = root.itemConfig(recipe.output)
        local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
        if (searchText == "") or id:find(searchText) or merged.shortdescription:lower():find(searchText) then
            local ingredientSlots = {
                {mode = "h", scissoring = false}
            }
            for _, input in ipairs(recipe.input) do
                table.insert(ingredientSlots, {
                    type = "itemSlot",
                    item = input
                })
            end
            local listItem = _ENV.recipeSearchScrollArea:addChild({
                type = "listItem",
                selectionGroup = "recipeSelect",
                value = recipe,
                expandMode = {1,0},
                children = {
                    {type = "panel", style = "convex", children = {
                            { mode = "v"},
                            {
                                { type = "itemSlot", item = recipe.output },
                                { type = "label", text = merged.shortdescription}
                            },
                            {type = "panel", style = "flat", children = ingredientSlots}
                        }
                    }
                }
            })
            function listItem:onClick()
                displayRecipe(recipe)
                world.sendEntityMessage(pane.sourceEntity(), "setRecipe", recipe)
            end

        end
    end

end
function filterRecipes(filter, recipes)
    return util.filter(recipes, function (v)
        if not filter then return true end
        for _, filterGroup in ipairs(filter) do
            for _, recipeGroup in ipairs(v.groups or {}) do
                if recipeGroup == filterGroup then return true end
            end
        end
    end)
end

function displayRecipe(recipe)
    if not recipe then return end
    _ENV.outputSlot:setItem(recipe.output)
    local itemConfig = root.itemConfig(recipe.output)
    local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
    _ENV.outputLabel:setText(merged.shortdescription)

    local inputs = world.getObjectParameter(pane.sourceEntity(), "matterStreamInput") or {}
    for _, newInput in ipairs(inputs) do
        newInput.used = false
        for _, input in ipairs(recipe.input) do
            if root.itemDescriptorsMatch(input, newInput, recipe.matchInputParameters) then
                newInput.used = true
                break
            end
        end
    end
    for _, recipeItem in ipairs(recipe.input) do
        local recieved = false
        for _, inputItem in ipairs(inputs) do
            if root.itemDescriptorsMatch(recipeItem, inputItem, recipe.matchInputParameters) then
                recieved = true
                break
            end
        end
        if not recieved then
            table.insert(inputs, sb.jsonMerge(recipeItem, {count = 0, used = true}))
        end
    end

    table.sort(inputs, function(a, b)
        if a.used == b.used then
            local a_config = root.itemConfig(a)
            local a_merged = sb.jsonMerge(a_config.config, a_config.parameters)
            local b_config = root.itemConfig(b)
            local b_merged = sb.jsonMerge(b_config.config, b_config.parameters)
            if sb.stripEscapeCodes ~= nil then
                return sb.stripEscapeCodes(a_merged.shortdescription) < sb.stripEscapeCodes(b_merged.shortdescription)
            else
                return a_merged.shortdescription:gsub("%b^;") < b_merged.shortdescription:gsub("%b^;")
            end
        else
            return a.used
        end
    end)

    local craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
    local productionRate = craftingSpeed / math.max(
        0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
        (world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
        (recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
    )
    local maxProductionRate = productionRate

    _ENV.maxProductionRate:setText(tostring(maxProductionRate))

    _ENV.recipeInputsScrollArea:clearChildren()
    for _, input in ipairs(inputs) do
        local itemConfig = root.itemConfig(input)
        local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
        local productionLabels
        if input.used then
            local production = input.count * craftingSpeed
            local productionTarget
            for _, recipeItem in ipairs(recipe.input) do
                if root.itemDescriptorsMatch(input, recipeItem, recipe.matchInputParameters) then
                    productionTarget = (recipeItem.count or 1) * craftingSpeed
                    productionRate = math.min(productionRate, (input.count / (recipeItem.count or 1)) * craftingSpeed)
                    break
                end
            end
            local color
            if production <= 0 then
                color = "FF0000"
            elseif production >= productionTarget then
                color = "00FF00"
            elseif production < productionTarget then
                color = "FFFF00"
            end

            productionLabels = {
                { type = "label", text = tostring(production),       color = color, inline = true },
                { type = "label", text = "/",                        inline = true },
                { type = "label", text = tostring(productionTarget), inline = true },
                { type = "label", text = "Per Second",               inline = true }
            }
        else
            productionLabels = {
                { type = "label", text = tostring(input.count), color = "FF00FF", inline = true },
                { type = "label", text = "Per Second",          inline = true }
            }
        end
        if input.used or (input.count > 0) then
            _ENV.recipeInputsScrollArea:addChild({
                type = "panel",
                style = "convex",
                expandMode = {1,0},
                children = {
                    { mode = "v" },
                    {
                        { type = "itemSlot", item = sb.jsonMerge(input, { count = 1 }) },
                        {
                            { type = "label", text = merged.shortdescription},
                            productionLabels
                        }
                    }
                },
            })
        end
    end
    local color
    if productionRate <= 0 then
        color = "FF0000"
    elseif productionRate >= maxProductionRate then
        color = "00FF00"
    elseif productionRate < maxProductionRate then
        color = "FFFF00"
    end
    _ENV.productionRate.color = (color)
    _ENV.productionRate:setText(tostring(productionRate))

end
function _ENV.craftingItemSlot:onItemModified()
    refreshCurrentRecipes()
end
function _ENV.craftingStationSlot:onItemModified()
    refreshCurrentRecipes()
end
function _ENV.craftingAddonSlot:onItemModified()
    refreshCurrentRecipes()
end

function _ENV.searchBox:onTextChanged()
    refreshDisplayedRecipes()
end
