local outputNodesConfig
function displayProducts(products, noProducts, noNodeProducts)
	if not outputNodesConfig then
		outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	end
	_ENV.productsScrollArea:clearChildren()
	if products and #products > 0 then
		for nodeIndex, nodeProducts in ipairs(products) do
			if nodeProducts and #nodeProducts > 0 then
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
			else
				if noNodeProducts and noNodeProducts[nodeIndex] then
					_ENV.productsScrollArea:addChild(noNodeProducts[nodeIndex])
				end
			end
		end
	elseif noProducts then
		_ENV.productsScrollArea:addChild(noProducts)
	else
		_ENV.productsScrollArea:addChild({type = "label", color = "FF0000", text = "No products are being made."})
	end
end
