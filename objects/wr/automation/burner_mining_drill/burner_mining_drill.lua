require("/interface/games/util.lua")

local products
local initTick = false
local wasFull
local active

function init()
	products = config.getParameter("products")
	message.setHandler("setProducts", function(_, _, newOutput)
		setProducts(newOutput)
	end)
	message.setHandler("addFuel", function(_, _, fuelAmount)
		return {addFuel(fuelAmount)}
	end)

	storage.leftovers = storage.leftovers or {}
	storage.fuel = storage.fuel or 0

	if products and products[1] and storage.uninitTime and (not (world.type() == "unknown")) then
		if storage.fuel > 0 then
			animator.setAnimationState("extractor", "on")
			initTick = true
		end
		local currentTime = world.time()
		local timePassed = math.min(currentTime - storage.uninitTime, storage.fuel)
		storage.uninitTime = currentTime
		storage.fuel = math.max(0, storage.fuel - timePassed)
		for i, product in ipairs(products[1]) do
			storage.leftovers[i] = (storage.leftovers[i] or 0) + (product.count * timePassed)
		end
	end
end
function uninit()
	storage.uninitTime = world.time()
end

function update(dt)
	if not world.entityExists(entity.id()) then return end
	if (not products) or (not products[1]) or ((storage.fuel <= 0) and not initTick) then
		if products then
			object.setConfigParameter("status", "noFuel")
		else
			object.setConfigParameter("status", "invalid")
		end
		script.setUpdateDelta(0)
		object.setOutputNodeLevel(0, false)
		animator.setAnimationState("extractor", "off")
		active = false
		return
	end
	initTick = false

	local insertedAny = false
	local attemptedInsert = false
	for i, product in ipairs(products[1]) do
		local output = copy(product)
		local total = (product.count * dt) + (storage.leftovers[i] or 0)
		output.count = math.floor(total)
		storage.leftovers[i] = total - output.count
		if output.count > 0 then
			attemptedInsert = true
			-- containerAddItems returns leftovers it couldn't add to the container
			insertedAny = (not world.containerAddItems(entity.id(), output)) or insertedAny
		end
	end
	if attemptedInsert then
		animator.setAnimationState("extractor", insertedAny and "on" or "off")
		storage.fuel = math.max(0, storage.fuel - ((insertedAny and dt) or 0))
		-- set the wire node output if the inserter inserted any items on this tick
		object.setOutputNodeLevel(0, insertedAny)
		if (not insertedAny) and (not wasFull) then
			object.setConfigParameter("status", "full")
			wasFull = true
			script.setUpdateDelta(math.max(3600, config.getParameter("scriptDelta") or 60))
		elseif insertedAny and wasFull then
			wasFull = false
			script.setUpdateDelta(config.getParameter("scriptDelta") or 60)
		elseif insertedAny then
			object.setConfigParameter("status", "active")
			active = true
		end
		if (storage.fuel <= 0) then
			object.setConfigParameter("status", "noFuel")
		end
	end
end


function setProducts(newOutput)
	if compare(products, newOutput) then return end
	products = newOutput
	object.setConfigParameter("products", products)
	if (not products) or (not products[1]) then return end
	-- find the fastest product to use it as our tick rate and reset leftover amounts from previous ticks
	best = 0
	for i, product in ipairs(products[1]) do
		storage.leftovers[i] = 0
		if product.count > best then
			best = product.count
		end
	end
	-- drills will never tick faster than once per second
	local delta = math.max(1 / best, 1) * 60
	script.setUpdateDelta(delta)
	object.setConfigParameter("scriptDelta", delta)
end


function addFuel(fuel)
	local maxFuel = config.getParameter("maxFuel")
	local consume = maxFuel - storage.fuel
	if fuel >= consume then
		storage.fuel = maxFuel
	else
		storage.fuel = storage.fuel + fuel
		consume = fuel
	end
	if not active and (storage.fuel > 0) then
		object.setConfigParameter("status", "warming")
		script.setUpdateDelta(config.getParameter("scriptDelta") or 60)
	end
	return consume, storage.fuel
end
