require("/scripts/util.lua")
require("/interface/games/util.lua")
require("/scripts/wr/automation/oreNoise.lua")
function uninit()
end

local visitableParameters
local celestialCoords, isCelestial

local planetOres
local planetOresList = {}

local rarityMap = {}
local totalValidBlocks
local surfaceLayerTop
function init()
	rarityMap = root.assetJson("/interface/wr/automation/rarity.config")
	celestialCoords, isCelestial = player.worldId():gsub("^CelestialWorld%:", "")
	if celestialCoords and (isCelestial > 0) and world.terrestrial() then
		visitableParameters = celestial.visitableParameters(celestialCoords)
		if visitableParameters then
			displayOres()
		end
	end
end
function invalidWorld()
	_ENV.oresScrollArea:addChild({type = "label", color = "FF0000", text = "Resource veins can only be mined on terrestrial worlds with valid celestial coordinates."})
end

local traveseLength = 1
local traversed = 0
local searchPosition = { 0, 0 }
local traverseDirection = 1
local traverseDirections = {
	{ 0, -1 },
	{ 1, 0 },
	{ 0, 1 },
	{ -1, 0}
}
local searching = false
local blocksScanned = 0
local scannedList = {}
function _ENV.search:onClick()
	blocksScanned = 0
	traveseLength = 1
	traversed = 0
	searchPosition = world.entityPosition(player.id())
	searchPosition = { math.floor(searchPosition[1]), math.min(surfaceLayerTop, math.floor(searchPosition[2])) }
	searching = true
	scannedList = {}
end

function cancelSearch()
	if searching then
		_ENV.searchingLabel:setText(("Search Canceled.\n %d Blocks Scanned."):format(blocksScanned))
		searching = false
	end
end

function update()
	if (not visitableParameters) and celestialCoords and (isCelestial > 0) and world.terrestrial() then
		visitableParameters = celestial.visitableParameters(celestialCoords)
		if visitableParameters then
			displayOres()
		end
	elseif not visitableParameters then
		return
	end

	if searching then
		for i = 1, 1000 do -- how many to seach per tick
			blocksScanned = blocksScanned + 1
			if scan(searchPosition) then
				_ENV.searchingLabel:setText(("Found At ^cyan;[^yellow;%d^cyan;, ^yellow;%d^cyan;]^reset;\n %d Blocks Scanned.")
				:format(searchPosition[1],
					searchPosition[2], blocksScanned))
				searching = false
				world.sendEntityMessage(player.id(), "wr_setBeaconPosition", searchPosition, "resource")
				return
			end
			-- local last = copy(searchPosition)
			-- table.insert(scannedList, last)
			searchPosition[1] = searchPosition[1] + traverseDirections[traverseDirection][1]
			searchPosition[2] = searchPosition[2] + traverseDirections[traverseDirection][2]
			-- world.debugLine(last, searchPosition, { 255, 0, 0 })
			traversed = traversed + 1
			if blocksScanned >= totalValidBlocks then
				_ENV.searchingLabel:setText(("Search Failed.\n All %d Blocks Scanned."):format(blocksScanned))
				searching = false
				return
			elseif searchPosition[2] > surfaceLayerTop then
				traverseDirection = 1
				searchPosition[2] = surfaceLayerTop
				searchPosition[1] = searchPosition[1] - traveseLength - 1
				traveseLength = traveseLength + 1
				traversed = traveseLength - traversed
			elseif searchPosition[2] < 0 then
				traverseDirection = 3
				searchPosition[2] = 0
				searchPosition[1] = searchPosition[1] + traveseLength + 1
				traveseLength = traveseLength + 1
				traversed = traveseLength - traversed
			elseif traversed == traveseLength then
				traversed = 0
				traverseDirection = traverseDirection + 1
				if traverseDirection == 2 then
					traveseLength = traveseLength + 1
				elseif traverseDirection == 4 then
					traveseLength = traveseLength + 1
				elseif traverseDirection == 5 then
					traverseDirection = 1
				end
			end
			searchPosition[1] = world.xwrap(searchPosition[1])
		end
		_ENV.searchingLabel:setText(("Searching...\n %d Blocks Scanned."):format(blocksScanned))
	end
	-- for i = 2, #scannedList do
	--     world.debugLine(scannedList[i-1], scannedList[i], { 255, 0, 0 })
	-- end
end

function scan(position)
	for oreId, oreData in pairs(planetOres) do
		if getOreCount(position, oreData.noise) < oreData.amount then
			return false
		end
	end
	return true
end


function displayOres()
	setupPlanetParameters(visitableParameters)

	surfaceLayerTop = visitableParameters.surfaceLayer.layerBaseHeight
	totalValidBlocks = world.size()[1] * surfaceLayerTop
	planetOres = {}
	for _, v in ipairs(celestial.planetOres(celestialCoords, world.threatLevel())) do
		local modConfig = root.modConfig(v)
		if modConfig.config.itemDrop then
			planetOres[modConfig.config.itemDrop] = {
				noise = oreNoise(modConfig.config.itemDrop, celestial.planetSeed(celestialCoords)),
				itemConfig = root.itemConfig(modConfig.config.itemDrop).config,
				modConfig = modConfig.config,
				itemId = modConfig.config.itemDrop,
				amount = 0
			}
			table.insert(planetOresList, planetOres[modConfig.config.itemDrop])
		end
	end
	table.sort(planetOresList, function(a, b)
		local a_rarity = (a.itemConfig.rarity or "common"):lower()
		local b_rarity = (b.itemConfig.rarity or "common"):lower()
		if a_rarity == b_rarity then
			return a.itemConfig.shortdescription < b.itemConfig.shortdescription
		else
			return rarityMap[a_rarity] < rarityMap[b_rarity]
		end
	end)

	_ENV.oresScrollArea:clearChildren()
	for _, oreData in pairs(planetOresList) do
		_ENV.oresScrollArea:addChild({
			type = "panel",
			style = "convex",
			expandMode = { 1, 0 },
			children = {
				{ mode = "v" },
				{
					{ type = "itemSlot", item = {name = oreData.itemId} },
					{
						{ type = "label", text = oreData.itemConfig.shortdescription },
						{
							{ type = "textBox", id = oreData.itemId.."_textBox" },
							{ type = "label", text = "Per Second" }
						},

					}
				}
			},
		})
		local textBox = _ENV[oreData.itemId .. "_textBox"]
		textBox:setText(tostring(oreData.amount))
		function textBox:onTextChanged()
			local number = tonumber(self.text)
			if number and (number >= 0) then
				oreData.amount = number
				self:setColor(nil)
			else
				self:setColor("FF0000")
			end
			cancelSearch()
		end
	end
end
