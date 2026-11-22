require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/interface/wr/automation/labels.lua")
require("/interface/wr/automation/displayRecipe.lua")
function uninit()
end

local excludedProducts = 0
local totalProducts = 0
local productPrecision = 0
function init()
	craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	productsPossible = world.getObjectParameter(pane.sourceEntity(), "productsPossible") or jarray()
	productPrecision = world.getObjectParameter(pane.sourceEntity(), "productPrecision") or 0
	costAmountMultiplier = world.getObjectParameter(pane.sourceEntity(), "costAmountMultiplier") or 1
	costPriceMultiplier = world.getObjectParameter(pane.sourceEntity(), "costPriceMultiplier") or 1
end

function update()
	if recipeRPC and recipeRPC:finished() then
		recipeRPC = nil
		refreshDisplayedProducts()
	end
end

function refreshDisplayedProducts()
	local recipe = world.getObjectParameter(pane.sourceEntity(), "recipe")

	local productionRate, maxProductionRate = displayRecipeInputs(recipe)

	_ENV.productsScrollArea:clearChildren()
	if recipe then
		countExcludedProducts()
		if totalProducts == 0 then
			_ENV.amountExcludedLabel:setText("0%")
		else
			_ENV.amountExcludedLabel:setText(("%d%%"):format(math.ceil((excludedProducts / totalProducts) * 100)))
		end
		_ENV.maxExcludedLabel:setText(("%d%%"):format(math.ceil((productPrecision) * 100)))
		if #productsPossible > 0 then
			for i, product in ipairs(productsPossible) do
				local itemConfig = root.itemConfig(product)
				local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
				local timeMultiplier, timeLabel = timeScale(product.count * maxProductionRate)
				_ENV.productsScrollArea:addChild({
					type = "panel",
					style = "convex",
					expandMode = { 1, 0 },
					children = {
						{ mode = "v" },
						{
							{ type = "itemSlot", item = sb.jsonMerge(product, { count = 1 }) },
							{
								{ type = "label", text = (merged.shortdescription or product.name or product.item or "") },
								{
									{ type = "checkBox", checked = productsPossible[i].enabled, id = "product"..i.."CheckBox" },
									{ type = "image", file = outputNodesConfig[1].icon or "/interface/wr/automation/output.png" },
									{ type = "label", text = (productsPossible[i].enabled and clipAtThousandth((timeMultiplier * product.count * productionRate))) or "0", inline = true },
									{ type = "label", text = "/", inline = true },
									{ type = "label", text = (productsPossible[i].enabled and clipAtThousandth((timeMultiplier * product.count * maxProductionRate))) or "0",                        inline = true },
									{ type = "label", text = timeLabel,                                                                 inline = true }
								},

							}
						}
					},
				})
				local checkBox = _ENV["product"..i.."CheckBox"]
				function checkBox:onClick()
					if self.checked then
						productsPossible[i].enabled = self.checked
						world.sendEntityMessage(pane.sourceEntity(), "setControlledProducts", productsPossible)
						countExcludedProducts()
						setRecipe()
					else
						if (((excludedProducts + product.count) / totalProducts) > productPrecision) then
							pane.playSound("/sfx/interface/clickon_error.ogg")
							self:setChecked(true)
						else
							productsPossible[i].enabled = self.checked
							world.sendEntityMessage(pane.sourceEntity(), "setControlledProducts", productsPossible)
							countExcludedProducts()
							setRecipe()
						end
					end
				end
			end
		else
			_ENV.productsScrollArea:addChild({
				type = "label",
				color = "FF0000",
				text = _ENV.productsScrollArea.noProductsMessage or "This produces no products.",
			})
		end
	else
		_ENV.productsScrollArea:addChild({
			type = "label",
			text = _ENV.productsScrollArea.noRecipeMessage or "Please insert a recipe target.",
		})
	end
end


function countExcludedProducts()
	totalProducts = 0
	excludedProducts = 0
	for i, v in ipairs(productsPossible) do
		totalProducts = totalProducts + v.count
		if not productsPossible[i].enabled then
			excludedProducts = excludedProducts + v.count
		end
	end
end
