# General Purpose
This system is designed to be extremely flexible and is primarily data driven. Any object can interface with the system by having a few config parameters set on an object.

```json
"inputNodes" : [
	[0, 0]
],
"inputNodesConfig" : [
	{
		"color" : "#1c8eff",
		"icon" : "/interface/wr/automation/input.png"
	}
],
"outputNodes" : [
	[0, 1]
],
"outputNodesConfig" : [
	{
		"color" : "#1c8eff",
		"icon" : "/interface/wr/automation/output.png"
	}
]
```
My system uses wire nodes, and with OSB wire nodes can have unique colors for their wires and icons defined, the index in `"inputNodesConfig"`/`"outputNodesConfig"` corresponding to the index of the relevant node in the `"inputNodes"`/`"outputNodes"` list. We will be seeing many config parameters regarding I/O nodes which are a list where the index corresponds to the node. Above is the parameters that should be used for consistency to indicate wire nodes compatible with this system.

In the case a machine may have multiple I/O nodes I would reccommend adding a `?hueshift=20` directive to the icon's path adding or subtracting in increments of 20 for each additional node in that group.

```json
"matterStreamReciever" : [
	true
]
```
This is the config parameter that allows other objects to know if an input node at that index can recieve a matter stream, if this table doesn't exist, or the value at the index isn't true, then it won't be counted for dividing the output and the stream can effectively be used as a logic wire for whether the machine is active or not.

```json
"matterStreamOutput" : [
	[
		{"item":"perfectlygenericitem", "count":0.5, "parameters":{}}
	]
]
```
This is the config parameter that is checked when any input is connected to another object's output. The recieving object will check if the input node is positive, what node index it is connected to on the output object, and if the output object has a `"matterStreamOutput"` parameter. If it exists, it will use the output node index to index to check for a list of items in `"matterStreamOutput"` at that node index. It does this for each object connected to the input node, adding to a list of input items and increasing their count if it matches items already in the list.

Do take note of the `0.5` count used in this example, that is normally not possible for a real item in starbound, that is because this is not a "real" item that currently exists, the count here is actually the rate per second that each object the output is connected to is recieving, not the total amount being output overall. So it is best to use scripts to set this parameter to evenly distribute the total output, which I already have a premade function for.

While less important, after getting the inputs, it is wise to set the `"matterStreamInput"` parameter to that in the same spec as the output to keep track of it since some GUIs and possibly other objects will fetch it.

```json
"fromExporter":false
```
This bool controls whether the matter stream being recieved has recieved any items from an exporter at any point upstream. This bool is used to control whether machine operations could be done while unloaded, since the exporter needs to be loaded to consume items. This bool also controls whether the stream can connect to the input of a planetary/universal relay as they are set to not relay the output if they are downstream from an exporter.

# Scripts

## Utility Script
`/objects/wr/automation/wr_automation.lua`
This is the general utility script that should be used by any object attempting to interface with this system, it is automatically required by the scripts below.

### wr_automation.init()
Setup function that should be called during init, loads the animation configuration and determines if the machine's animations should be "offset"

### wr_automation.playAnimations(state)
Attempts to set animation states depending on data defined in the object's config parameters.

```json
"stateAnimations" : {
	"on" : {
		"animations" : {"producing": ["on"]}
	},
	"on_offset" : {
		"animations" : {"producing": ["on_offset"]}
	},
	"off" : {
		"animations" : {"producing": ["off"]}
	}
}
```
All of the object scripts below use this to trigger animation states depending on the status of the machine, for now, the most important ones are `"on"` and `"off"` of course. however take note of `"on_offset"` this is used to have animations with offset timing for machines stacked on top of eachother, whenever a state is triggered, if the machine is an odd number in a stack and there is an `_offset` animation data defined for the state, then that will be used.

The state data will control things such as animation states in the animator and turning lights or particle emitters on or off.

### wr_automation.countInputs(nodeIndex, recipe)
Creates a list of all the items being recieved by the node index, with an optional argument for sorting the output list according to a recipe. The recipe will determine if items without matching parameters are combined or not, the default behavior is to not combine items with different parameters.

This will also check the `"fromExporter"` parameter from the objects it is recieving from, and it will return true any of them were recieving from an exporter as the third return value.

This function will return the resulting list, and the total count of items being recieved, and whether it is recieving from an exporter.

### wr_automation.setOutputs(products, forceRefresh)
Products is an array that corresponds to the exact same spec as `"matterStreamOutput"` but this time the actual total amount produced. This function is what will set the `"matterStreamOutput"` parameter to evently distribute the total products amongst its outputs.

If the new products for a node are different from the previous products, or the number of inputs that output is connected to changed, then the function will send a `"refreshInputs"` message to the objects connected to that node. This message will then effectively cascade downstream for any objects who would then subsequently have had their output change because of the change in inputs. The cascade will stop when an object would not have had its outputs effected or it reaches the end of the chain.

Returns the value that was set to `"matterStreamOutput"` and the total amount of items being output.

### wr_automation.clearAllOutputs()
Clears all outputs that were set by `wr_automation.setOutputs()` and sets their node to false.

## Production Object
`/objects/wr/automation/productionObject.lua`
Is the general use script for any object that will simply be producing an infinite amount of certain items at a certain rate.

This script does not have an update function so it is reccommended to make it not tick.

```json
"scriptDelta" : 0,
"products" : [
	[
		{"item":"perfectlygenericitem", "count":1, "parameters":{}}
	]
],
```
Products is the total amount of items being produced by each output node, that will then be evenly divided between the number of outputs for that node and then set to `"matterStreamOutput"`.

This script also includes a message handler `"setProducts"` which is used to set the config parameter for the products and refresh the outputs. This is intended for attached GUIs to change what is being produced.


## Recipe Object
`/objects/wr/automation/recipeObject.lua`
Is the general use script for any object that will take input items, and then produce output items.

This scripts assume all inputs and outputs are at the first input and output node.

This script does not have an update function so it is reccommended to make it not tick.

```json
"scriptDelta" : 0,
"recipe" : {
	"input":[
		{"item":"money", "count":9999, "parameters":{}}
	],
	"output":{"item":"perfectlygenericitem", "count":1, "parameters":{}},
	"duration" : 1, // how long it takes to craft this recipe
	"matchInputParameters" : false // do the input item parameters need to exactly match
},
"minimumProductionRate" : 0 // the minimum production rate that must be met for it to produce items
"minimumDuration" : 1, // the minimum duration to craft a recipe
"craftingSpeed" : 1, // the amount of times it crafts a recipe per cycle, effectively a multiplier
"passthrough" : false, // passes unused ingrredients through it's output

```
Most of these parameters control how fast the machine is capable of running. If the minimum production rate is met, it will start producing the recipe output, and it will set the `"products"` and then `"matterStreamOutput"` parameters much like a production object, with a slight difference. In the case of `"passthrough"` being true, the output will also have unused inputs split evenly in the output, these unused inputs will not be reported in the `"products"` parameter as they were not created by this object.

The recipe object uses the same spec for it's recipes as starbound's own recipes, with one main difference...
```json
"recipe" : {
	"recipeName" : "Simple Metal Casting",
	"input":[
		{"item":"liquidlava", "count":50, "parameters":{}}
	],
	"output":[
		{"item":"ironbar", "count":1, "parameters":{}},
		{"item":"copperbar", "count":1, "parameters":{}}
	],
	"duration" : 1, // how long it takes to craft this recipe
	"matchInputParameters" : false
},
```
In that recipes can support a list of output items, rather than one single output! However in this case, you should also give this recipe a `"recipeName"` so it can get listed nicely in the assembler GUI. Be aware, such recipes should ONLY ever be defined within the config parameters for objects using these scripts, and not in a standard `.recipe` file because it's not supported by the base game's recipe spec!

This script has the `"setRecipe"` message handler, which sets the recipe on the object and refreshes the outputs if it needs to change.

This script is used by almost every object that has varied inputs and outputs, it may not look like it, but the hydroponics and cloning vat are both recipe objects that have special GUI that creates and sets the recipe for the object, the object itself behaves no different from the assembler.

The assembler GUI is more multi purpose, for generalized crafting stations that have multiple recipes, and can be added to an object like so.

```json
"interactAction" : "ScriptPane",
"interactData" : { "gui" : { }, "scripts" : ["/metagui.lua"], "ui" : "wr_automation:assembler" },
"filter" : ["craftinganvil", "emptyhands"],
"recipes" : ["/path/to/recipeList.config"],
"lockRecipes" : false // hides the crafting station slot
```

The filter can be changed to any crafting station groups to have their recipes be listed without putting a crafting station into the crafting station slot. `"lockRecipes"` can be used to hide the slot for a crafting station, therefore limiting the recipes of the object to the crafting groups in the filter, as well as any recipes defined in `"uniqueRecipes"`.

Unique recipes are where one defines the recipes unique to this object, this can either be the list of recipes itself, a string for an asset path to a list of recipes, or a list of paths to lists of recipes. I highly reccommend making it be a list of paths, as it is guarded against recursion and will therefore enforce no recipe configs ever get loaded twice. This is the best place to put recipes that have multiple output items.

To make a crafting station compatible with being put into the assembler GUI there are three ways.
- 1 Have your station simply be using the `"interactAction": "OpenCraftingInterface"` from vanilla starbound, the assembler already knows how to handle these.
- 2 Use the same upgradeable crafting station scripts the stations in vanilla starbound use, the assembler already knows how to handle these.
- 3 Create a script the assmbler will load to fetch the recipes for your object, example below.

First, create a new lua script, by copying what's below.
```lua
wr_assemblerRecipes["your_object_id_here"] = function(craftingStation, addon)
	local filter = {}
	local recipes = {}
	local requiresBlueprint = true
	return filter, recipes, requiresBlueprint
end
```
The assembler GUI will load your scripts, then call a function in the `wr_assemblerRecipes` table at your object's ID, passing the itemDescriptor for it, and an addon if its in the addon slot.

You can do anything here, I reccommend just using `root.itemConfig` or `root.assetJson` to fetch your recipes/filters and pass them in the return, recipes passed here can support the expanded recipe spec that allows multiple output items.

Now set a parameter in the object config like so.
```json
  "wr_assemblerRecipeScripts" : ["/absolute/path/to/script.lua"]
```
