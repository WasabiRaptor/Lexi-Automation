function onNodeConnectionChange()
	local containerItems = world.containerItems(entity.id())
	local products = jarray()
	for _, item in pairs(containerItems) do
		table.insert(products, item)
	end
	object.setAllOutputNodes(#products > 0)
	object.setConfigParameter("matterStreamOutput", {products})
	for eid, _ in pairs(object.getOutputNodeIds(0)) do
		world.sendEntityMessage(eid, "refreshInputs")
	end
end

function containerCallback()
	onNodeConnectionChange()
end
