require("/scripts/util.lua")
require("/interface/wr/automation/displayRecipe.lua")
local rarityMap = {}
local currentRecipes = {}
local recipeOutputCache = {}
local recipesPerPage = 50
local searchedRecipes = {}

function uninit()
end

local filter
local requiresBlueprint = true
local uniqueRecipes = {}
local itemRecipes = {}
local stationRecipes = {}
local allRecipes = {}

local activeCoroutine
local currentRecipe
local errorMessage = "Error during initialization"

local raritySort = true
function init()
	inputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "inputNodesConfig")
	outputNodesConfig = world.getObjectParameter(pane.sourceEntity(), "outputNodesConfig")
	craftingSpeed = world.getObjectParameter(pane.sourceEntity(), "craftingSpeed") or 1

	rarityMap = root.assetJson("/interface/wr/automation/rarity.config")

	displayRecipe(world.getObjectParameter(pane.sourceEntity(), "recipe"))
end

function update()
end
