local _init = init or function () end
function init()
    _init()
	message.setHandler("setControlledProducts", function (_,_,...)
		setControlledProducts(...)
	end)
end

function setControlledProducts(products)
	object.setConfigParameter("productsPossible", products)
end
