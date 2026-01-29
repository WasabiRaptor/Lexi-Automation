require "/scripts/vec2.lua"
require "/scripts/util.lua"
require("/scripts/wr/automation/oreNoise.lua")

local planetOres = {}
local planetData
local detectConfig
function init()
	self.colorCache = {}
end

local lastPingColors = {}
function update()
	localAnimator.clearDrawables()

	if not detectConfig then
		detectConfig = animationConfig.animationParameter("pingDetectConfig")
	end

	if not planetData then
		planetData = animationConfig.animationParameter("planetData")
		if planetData and planetData.planetOres and planetData.planetSeed and planetData.visitableParameters then
			setupPlanetParameters(planetData.visitableParameters)
			for _, v in ipairs(planetData.planetOres) do
				local modConfig = root.modConfig(v)
				if modConfig.config.itemDrop then
					local itemConfig = root.itemConfig(modConfig.config.itemDrop)
					math.randomseed(sb.staticRandomI32(modConfig.config.itemDrop))
					if not detectConfig.colors[v] then
						sb.logWarn("[wr_automation] Resource '%s' does not have color defined for scanning.")
					end
					planetOres[modConfig.config.itemDrop] = {
						noise = oreNoise(modConfig.config.itemDrop, planetData.planetSeed),
						color = detectConfig.colors[v] or {math.random(255), math.random(255), math.random(255), 255 },
						modConfig = modConfig.config,
						itemConfig = itemConfig.config
					}
				end
			end
		end
	end

	local pingLocation = animationConfig.animationParameter("pingLocation")
	if pingLocation then
		if not self.pingLocation or not vec2.eq(pingLocation, self.pingLocation) then
			self.pingLocation = pingLocation
		end
		lastPingColors = {}
		local outerRadius = math.ceil(animationConfig.animationParameter("pingOuterRadius"))
		local edgeRadius = outerRadius - detectConfig.edge

		local searchRange = math.min(detectConfig.maxRange, outerRadius)
		local srsq = searchRange ^ 2
		local new, cached = 0, 0
		for x = -searchRange, searchRange do
			for y = -searchRange, searchRange do
				local distSquared = x ^ 2 + y ^ 2
				if distSquared <= srsq then
					local position = world.xwrap({x + pingLocation[1], y + pingLocation[2]})

					local cacheKey = position[1]..","..position[2]
					if not self.colorCache[cacheKey] then
						new = new + 1
						local best
						local bestAmount = 0
						local totalAmount = 0
						local count = 0
						for oreId, oreData in pairs(planetOres) do
							local amount = getOreCount(position, oreData.noise)
							if amount > 0 then
								count = count + 1
								totalAmount = amount + totalAmount
								if (amount > bestAmount) then
									bestAmount = amount
									best = oreData
								end
							end
						end
						if best then
							self.colorCache[cacheKey] = {
								best.color[1],
								best.color[2],
								best.color[3],
								util.lerp(math.min(1, totalAmount/1),50, 255),
							}
						else
							self.colorCache[cacheKey] = detectConfig.colors.none
						end
					else
						cached = cached + 1
					end

					local color = copy(self.colorCache[cacheKey])

					local dist = math.sqrt(distSquared)
					local fadeFactor = 1
					if dist > edgeRadius then
						fadeFactor = (detectConfig.edge - (dist - edgeRadius)) / detectConfig.edge
					end

					color[4] = color[4] * fadeFactor

					lastPingColors[cacheKey] = {color = color, position = position}
					local variant = math.random(1, detectConfig.variants)
					localAnimator.addDrawable({
							image = detectConfig.image:gsub("<variant>", variant),
							fullbright = true,
							position = position,
							centered = false,
							color = color
						},
						"overlay"
					)
				end
			end
		end
	else
		for _, v in pairs(lastPingColors) do
			v.color[4] = math.max(0, v.color[4] - 2)
			local variant = math.random(1, detectConfig.variants)
			localAnimator.addDrawable({
					image = detectConfig.image:gsub("<variant>", variant),
					fullbright = true,
					position = v.position,
					centered = false,
					color = v.color
				},
				"overlay"
			)
		end
		self.pingLocation = nil
	end
end
