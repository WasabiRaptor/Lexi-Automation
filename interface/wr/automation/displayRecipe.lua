require("/interface/wr/automation/labels.lua")
function displayRecipe(recipe)
	if not recipe then return end

	local inputs = (world.getObjectParameter(pane.sourceEntity(), "matterStreamInput") or {})[1] or {}
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
				return a_merged.shortdescription:gsub("%b^;", "") < b_merged.shortdescription:gsub("%b^;", "")
			end
		else
			return a.used
		end
	end)
	local duration = math.max(
		0.1, -- to ensure all recipes always have a craft time so things aren't produced infinitely fast
		(world.getObjectParameter(pane.sourceEntity(), "minimumDuration") or 0),
		(recipe.duration or root.assetJson("/items/defaultParameters.config:defaultCraftDuration") or 0)
	)
	local maxProductionRate = craftingSpeed / duration
	local productionRate
	local minimumProductionRate = world.getObjectParameter(pane.sourceEntity(), "minimumProductionRate") or 0
	local balanced = true
	for _, input in ipairs(inputs) do
		if input.used then
			for _, recipeItem in ipairs(recipe.input) do
				if root.itemDescriptorsMatch(input, recipeItem, recipe.matchInputParameters) then
					local rate = (input.count / ((recipeItem.count or 1) * maxProductionRate)) * maxProductionRate
					if not productionRate then
						balanced = rate <= maxProductionRate
						productionRate = math.min(maxProductionRate, rate)
					else
						balanced = balanced and (rate == productionRate)
						productionRate = math.min(productionRate, rate)
					end
					break
				end
			end
		end
	end

	_ENV.recipeInputsScrollArea:clearChildren()
	for _, input in ipairs(inputs) do
		local itemConfig = root.itemConfig(input)
		local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
		local productionLabels
		if input.used then
			local inputRate = 0
			local inputTarget = 0
			for _, recipeItem in ipairs(recipe.input) do
				if root.itemDescriptorsMatch(input, recipeItem, recipe.matchInputParameters) then
					inputTarget = ((recipeItem.count or 1) * maxProductionRate)
					inputRate = (input.count / inputTarget) * maxProductionRate
					break
				end
			end
			local color
			if not (inputRate > minimumProductionRate) then
				color = "FF0000"
			elseif (inputRate == maxProductionRate) or balanced then
				color = "00FF00"
			elseif inputRate > maxProductionRate then
				color = "00FFFF"
			elseif inputRate < maxProductionRate then
				color = "FFFF00"
			end
			local timeMultiplier, timeLabel = timeScale(inputTarget)
			productionLabels = {
				{ type = "image", file = inputNodesConfig[1].icon },
				{ type = "label", text = clipAtThousandth((timeMultiplier * input.count)),       color = color, inline = true },
				{ type = "label", text = "/",                        inline = true },
				{ type = "label", text = clipAtThousandth((timeMultiplier * inputTarget)), inline = true },
				{ type = "label", text = timeLabel,               inline = true }
			}
		else
			local timeMultiplier, timeLabel = timeScale(input.count)
			productionLabels = {
				{ type = "image", file = inputNodesConfig[1].icon },
				{ type = "label", text = clipAtThousandth((timeMultiplier * input.count)), color = "FF00FF", inline = true },
				{ type = "label", text = timeLabel,          inline = true }
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
	if not (productionRate > minimumProductionRate) then
		color = "FF0000"
	elseif (productionRate >= maxProductionRate) or balanced then
		color = "00FF00"
	elseif productionRate < maxProductionRate then
		color = "FFFF00"
	end

	_ENV.outputPanel:clearChildren()
	local powerPanel
	if recipe.producePower then
		local powerScale, shortLabel, longLabel = kilowattScale(recipe.producePower * maxProductionRate)
		powerPanel = {
			type = "panel",
			style = "flat",
			expandMode = { 1, 0 },
			children = {
				{mode = "v"},
				{
					{mode = "h", expandMode = {0,0}},
					{type= "label", text= "+"..clipAtThousandth((powerScale * (productionRate or 0) * recipe.producePower)), color = color, inline= true},
					{type= "label", text= "/", inline= true},
					{type= "label", text= clipAtThousandth((powerScale * maxProductionRate * recipe.producePower)), inline= true},
					{type= "label", text= shortLabel, inline= true}

				}
			},
		}
	end
	if recipe.output then
		if recipe.output[1] then
			local outputSlots = {
				{mode = "h", scissoring = false, expandMode = {1,0}}
			}
			for _, output in ipairs(recipe.output) do
				table.insert(outputSlots, {
					type = "itemSlot",
					item = output
				})
			end
			local timeMultiplier, timeLabel = timeScale(maxProductionRate)

			_ENV.outputPanel:addChild({ type = "layout", mode = "v", expandMode = { 1, 0 }, children = {
				{ type = "label", text = recipe.recipeName },
				{
					{type = "image", file = outputNodesConfig[1].icon },
					{type= "label", text= clipAtThousandth((timeMultiplier * (productionRate or 0))), color= color, inline= true},
					{type= "label", text= "/", inline= true},
					{type= "label", text= clipAtThousandth((timeMultiplier * maxProductionRate)), inline= true},
					{type= "label", text=timeLabel, inline= true}
				},
				{
					type = "panel",
					style = "flat",
					children = {
						{ mode = "v", expandMode = {1,0} },
						{ type = "label", text = "Products", align = "center"},
						{ type = "itemGrid", id = "recipeProductsItemGrid", slots = 0, autoInteract = false}
					},
				},
				powerPanel
			}})
			for _, input in ipairs(recipe.output) do
				_ENV.recipeProductsItemGrid:addSlot(input)
			end

		else
			local itemConfig = root.itemConfig(recipe.output)
			local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)

			local timeMultiplier, timeLabel = timeScale(maxProductionRate * recipe.output.count)
			local outputDisplay = copy(recipe.output)
			outputDisplay.count = 1

			_ENV.outputPanel:addChild({
				type = "layout",
				mode = "v",
				scissoring = false,
				children = {
					{
						{type= "itemSlot", autoInteract= false, glyph= "output.png", item = outputDisplay},
						{
							{type= "label", text= merged.shortdescription},
							{
								{type = "image", file = outputNodesConfig[1].icon },
								{type= "label", text= clipAtThousandth((timeMultiplier * recipe.output.count * (productionRate or 0))), color= color, inline= true},
								{type= "label", text= "/", inline= true},
								{type= "label", text= clipAtThousandth((timeMultiplier * recipe.output.count * maxProductionRate)), inline= true},
								{type= "label", text=timeLabel, inline= true}
							}
						},
					},
					powerPanel
				},
			})
		end
	else
		_ENV.outputPanel:addChild({ type = "layout", mode = "v", expandMode = { 1, 0 }, children = {
			{ type = "label", text = recipe.recipeName, align = "center" },
			powerPanel
		}})
	end

end
