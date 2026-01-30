local outputNodesConfig
function displayProducts(products)
	if not outputNodesConfig then
		outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	end
	_ENV.productsScrollArea:clearChildren()
	if products then
		for nodeIndex, nodeProducts in ipairs(products) do
			for _, product in ipairs(nodeProducts) do
				local itemConfig = root.itemConfig(product)
				local merged = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
				_ENV.productsScrollArea:addChild({
					type = "panel",
					style = "convex",
					expandMode = { 1, 0 },
					children = {
						{ mode = "v" },
						{
							{ type = "itemSlot", item = sb.jsonMerge(product, { count = 1 }) },
							{
								{ type = "label", text = merged.shortdescription },
								{
									{ type = "image", file = outputNodesConfig[nodeIndex].icon },
									{ type = "label", text = tostring(product.count), inline = true },
									{ type = "label", text = "Per Second",            inline = true }
								},

							}
						}
					},
				})
			end
		end
	else
		-- _ENV.productsScrollArea:addChild({type = "label", color = "FF0000", text = "Resource veins can only be found on terrestrial worlds with valid celestial coordinates."})
	end
end
