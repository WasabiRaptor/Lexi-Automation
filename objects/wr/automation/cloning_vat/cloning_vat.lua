function init()
	message.setHandler("setCloningProducts", function (_,_,...)
		setCloningProducts(...)
	end)
end

function setCloningProducts(products, targetAmounts)
	object.setConfigParameter("cloningProducts", products)
	object.setConfigParameter("cloningEnabled", targetAmounts)
end
