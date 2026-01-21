wr_automation = {}
function wr_automation.countInputs(recipe)
    local recipe = recipe or {matchInputParameters = true, input = {}}
    local inputNodes = object.getInputNodeIds(0)
    local inputs = {}
    for eid, index in pairs(inputNodes) do
        if world.entityExists(eid) then
            for i, newInput in ipairs((world.getObjectParameter(eid, "matterStreamOutput") or {})[index + 1] or {}) do
                newInput.count = newInput.count or 0
                local isNew = true
                for j, input in ipairs(inputs) do
                    if root.itemDescriptorsMatch(input, newInput, recipe.matchInputParameters) then
                        isNew = false
                        input.count = input.count + newInput.count
                        break
                    end
                end
                if isNew then
                    newInput.used = false
                    for _, input in ipairs(recipe.input) do
                        if root.itemDescriptorsMatch(input, newInput, recipe.matchInputParameters) then
                            newInput.used = true
                            break
                        end
                    end
                    table.insert(inputs, newInput)
                end
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
            return (a.name or a.item) < (b.name or b.item)
        else
            return a.used
        end
    end)

    return inputs
end
