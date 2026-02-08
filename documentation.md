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
My system uses wire nodes, and with OSB wire nodes can have unique colors for their wires and icons defined, the index in `"inputNodesConfig"`/`"outputNodesConfig"` corresponding to the index of the relevant node in the `"inputNodes"`/`"outputNodes"` list. We will be seeing many config parameters regarding I/O nodes which are a list where the index corresponds to the node. Above is the parameters that should be used for consistency to indicate wire nodes compatible with my mod. In the case a machine may have multiple I/O nodes I would reccommend adding a `?hueshift=20` directive to the icon's path adding or subtracting in increments of 20 for each additional node in that group.

```json
"matterStreamOutput" : [
	[
		{"item":"perfectlygenericitem", "count":0.5, "parameters":{}}
	]
]
```
This is the config parameter that is checked when any input is connected to another object's output. The object will check if the input is positive, what node index it is connected to on the output object, and if the output object has a `"matterStreamOutput"` parameter. If it exists, it will use the output node index to index to check for a list of items in `"matterStreamOutput"` at that node index. It does this for each object connected to the input node, adding to a list of input items and increasing their count if it matches items already in the list.

Do take note of the `0.5` count used in this example, that is normally not possible for a real item in starbound, that is because this is not a "real" item that currently exists, the count here is actually the rate of the item being output per second. One thing of note here! This is the rate that each object the output is connected to is recieving, not the total amount being output overall. So it is best to use scripts to set this paramter to evenly distribute the output to connected objects, which I already have a premade function for.

While less important, after building their list of inputs, it is wise to set the `"matterStreamInput"` parameter to that list to keep track of it since some GUIs and possibly other objects will fetch it in the future.

# Scripts

## Utility Script
`/objects/wr/automation/wr_automation.lua`
This is the general utility script that should be used by any object attempting to interface with this system, it is automatically required by the scripts below.

### wr_automation.init()
Setup function that should be called during init, loads the animation configuration and determines if the machine's animations should be "offset"

### wr_automation.playAnimations(state)
Attempts to set animation states depending on data defined in the object's config paramters.

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
Creates a list of all the items being recieved by the node index, with an optional argument for sorting the output list according to a recipe. The recipe will determine if items without matching paramters are combined or not, the default behavior is to not combine items with different paramters.

This function will return the resulting list, and the total count of items being recieved.

### wr_automation.setOutputs(products)
Products is an array that corresponds to the exact same spec as `"matterStreamOutput"` being a list of lists of items. As this function is what will set the `"matterStreamOutput"` paramter accordingly to evently distribute the total products the object is producing evenly amongst its outputs.

If the new products for a node are different from the previous products, or the number of inputs that output is connected to changed, then the function will send a `"refreshInputs"` message to the objects connected to that node. This message will then effectively cascade downstream for any objects who would then subsequently have had their output change because of the change in inputs. The cascade would stop if when an object would not have had its outputs effected.

Returns the value that was set to `"matterStreamOutput"` and the total amount of items being output.


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

This script also includes a message handler for the message `"setProducts"` which is used to set the config paramter for the products and refresh the outputs. This is intended for attached GUIs to change what is being produced.

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
Most of these paramters control how fast the machine is capable of running. If the minimum production rate is met, it will start producing the recipe output, and it will set the `"products"` and then `"matterStreamOutput"` parameters much like a production object, with a slight difference. In the case of `"passthrough"` being true, the output will also have unused inputs split evenly in the output, these unused inputs will not be reported in the `"products"` parameter as they were not created by this object.

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

This script has the `"setRecipe"` message handler, which as expected, sets the recipe on the object and refreshes the outputs if it needs to change.

This script is used by almost every object that has varied inputs and outputs, it may not look like it, but the hydroponics and cloning vat are both recipe objects that have special GUI that creates and sets the recipe for the object.

The assembler GUI is more multi purpose, for generalized crafting stations that have multiple recipes, and can be added to an object like so.
```json
"interactAction" : "ScriptPane",
"interactData" : { "gui" : { }, "scripts" : ["/metagui.lua"], "ui" : "wr_automation:assembler" },
"filter" : ["craftinganvil", "emptyhands"],
"uniqueRecipes" : ["/path/to/recipeList.config"],
"lockRecipes" : false // hides the crafting station slot
```
The filter can be changed to any crafting station groups to have their recipes be listed by the object without putting a station into the slot. `"lockRecipes"` can be used to hide the slots where one can input any crafting station, therefore limiting the recipes of the object to the crafting groups in the filter, as well as any recipes defined in `"uniqueRecipes"`.

Unique recipes are where one defines the recipes unique to this object, this can either be the list of recipes itself, a string for an asset path to a list of recipes, or a list of paths to lists of recipes. I highly reccommend making it be a list of paths. This is the best place to put recipes that have multiple output items.
