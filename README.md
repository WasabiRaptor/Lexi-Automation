# Lexi Automation
Lag friendly automation mod for starbound

## Requirements
- [Stardust Core Lite](https://steamcommunity.com/sharedfiles/filedetails/?id=2512589532) or [Stardust Core](https://steamcommunity.com/sharedfiles/filedetails/?id=764887546)
- [OpenStarbound](https://github.com/OpenStarbound/OpenStarbound) Nightly of 2/3/2026 or forward, some machines will not function without certain functions inaccsessible in retail Starbound.


## About
The primary goal of this mod was to introduce an extremely flexible, yet lag friendly means of automation into starbound. Some parts of this mod will function without OpenStarbound if possible, but it will require it for certain machines to function.

So why is this mod lag friendly?

Starbound's container object inventories are networked between client and server, and therefore, need to have data sent every single time an item in the inventory is changed, additionally, the game needs to iterate over inventory slots when searching for a place to add or remove items from an inventory. This is the major source of lag with other existing automation mods, every single update tick for these machines, items are being removed and consumed and inserted into inventories, additionally, they might be running a large amount of calculations in their update script every single tick to determine what the machine is doing. This obviously, will get very intensive once a player has placed down the hundreds of machines needed to create a large factory.

This mod gets around that with a rather simple solution, most of its machines do not have an inventory, and do not tick on update.

How does it work then?

The machines in this mod only need to do their calculations **once**, for the most part. The machines in this mod majorly fall into two categories, Production Objects, and Recipe Objects.

Production Objects will produce an infinite amount of an item, they will produce it at a 100% consistent rate, their production may be affected by where they're placed in the world or configued to do, but their output is then consitent and unchanging, the only further calculations to be done is when connecting and disconnecting wire nodes to split the output rate evenly, and that of course, only ever happens when those connections change.

Recipe Objects are configured to craft a recipe, or do something with an input item and output a different item. Much like Production Objects they only need to do the calculation for their recipe **once** when inputs or outputs are connected or disconnected to determine what items they are outputting and splitting evenly amongst their outputs. After such calculations are complete, they are simply outputting that item.

Neither of the above type of object are inventories, as far as the server is concerned they never contain any items. They are simply performing math based on input rates and output rates, and only doing the calculation when needed. The rest of the time they're simply existing and not taking up valuable lua processing time from the server or needlessly sending out inventory updates.

One of the few machines in the system that does run an update tick is the Inserter. Placing this next to an inventory will have it insert items into that inventory at the rate calculated by its wired input, and because it knows the exact rate items are being input, it can ajust it's update tick rate accordingly to never tick faster than it needs to, however I limit it to never tick more than once per second, because it never reasonably needs to. If items are being produced faster than a second it'll simply be inserting multiple items when it does tick. And another incredible boon to the fact that the entire system is already calculated, this means that the world doesn't even need to be loaded for the system to run. Inserters will record the world time when they un-load and then when they load back in, they will calculate the difference to the current world time, and insert as many items accordingly. Additionally, once an inserter detects it couldn't insert an item and assumes the inventory is full, it reduces it's tick rate to once per minute (if that was slower than its input rate) and will only return to it's faster rate once items have been removed and the inventory has space again.

Another boon of the pre-caluculated input and output rates not needing the world to be loaded, is systems can be linked through special nodes set to a channel to transport the output elsewhere on the planet, and in the case OpenStarbound is installed, there are even ones that can handle inter-planetary item transport. Your factory can span the entire universe and you will still only need the immediate chunks surrounding you to be loaded for it to function.

## The Machines

### Burner Mining Drill
- wr/burner_mining_drill

This won't look like a matter manipulator once it has it's own sprites. Place it down and activate it for it to start mining resources found at that location. Meant to be used for early game automated ore mining, similar to the Extractor except less efficient, requires fuel, and inserts into its own inventory.

### Matter Extractor
- wr/extractor_mk1

It's a big Matter Manipulator! Place it down and activate it for it to start mining resources found at that location. It will output them as a matter stream. Resources are calculated using a planet's celestial data and a noise map! All resources are found beneath the surface of a planet, and become richer the deeper you go.

### Resource Vein Scanner
- wr/ore_scanner

A handheld item used to view the richness of resource veins for the Matter Extractor. The scanner can even search for a vein with specific yeilds and point out the position for you. Extractors will also get trace amounts of ores further down in the column from where it's placed.

### Ground Pump
- wr/ground_pump_mk1

It's another big Matter Manipulator (for now). Place it down for it to pump fluids found at that layer of the planet. It will output them as a matter stream. Fluids are calculated from a planet's celestial data and the machine's Y position. Pumps will output much more fluid when placed beneath a layer's "ocean" level.

### Hydroponics
- wr/hydroponics_mk1

To grow plants with! Takes water as an input and uses it to grow a harvestable plant who's seed has been placed inside. It will output harvested crops as a matter stream. Calculates the crop yeilds using the machine's position as the seed.

### Cloning Vat
- wr/cloning_vat_mk1

(This requires OSB as monster drop pool configs cannot be retrieved from simply having the monster ID and seed in retail)
To get mob drops with! Place a capture pod inside and feed the machine nutrient paste. It will output the monster's drops as a matter stream. Calculates the drops using the monster's seed.

### Nutrient Processor
- wr/nutrient_processor_mk1

Converts food into nutrient paste. Input any item with a food value, and it will output the corresponding amount of nutrient paste. Inputting incorrect items or too many items at once can clog the machine.

### Matter Assembler
- wr/assembler_mk1

Can be programmed with the recipes of **any** crafting station, however there may be specialized crafting machines in the future that may be more efficient! Simply place the desired crafting station inside, and search for the desired recipe and select it (Without OSB you will also need to place the desired result item to list its recipes). Once a recipe has been selected, the machine will output the item as a matter stream once its ingredients are all being input.

Input rates will display as different colors depending on different factors.

Green: All input rates are balanced for the recipe, or input is exactly meeting the maxium rate of the machine.
Yellow: Items are being input, but they are not balanced.
Red: Input rate does not meet the minimum production rate of the machine.
Cyan: More items are being input than the machine can consume.
Magenta: Items not included in the recipe are being input.

### Inserter
- wr/inserter_mk1
- wr/inserter_mk2

Inserts items into the attached inventory.
MK1 Inserters will insert at the rate of their slowest input.
MK2 Inserters will insert at the rate of their fastest input.

### Relay
- wr/relay_mk1

Takes its input and repeats it to its output, used to extend ranges of wire nodes, or combine multiple inputs into one output line.

### Relay Splitter
- wr/relay_splitter_mk1

Can be used to filter items in specific rates to its left and right outputs, items not filtered will be sent through the center output. Logic wire nodes can be used to disable the left and right outputs temporarily. Be aware using these will cause the line downstream to re-calculate its outputs!

### Planetary Relay
- wr/planetary_relay_input_mk1
- wr/planetary_relay_output_mk1

Similar to the relay, but come in pairs of seperate input/output objects, placing one down allows one to set a channel name. Setting a pair to the same channel on the same planet will cause the input to be transported to the output. Channels are in pairs, there can not be more than one input or output per channel on a planet.

### Universal Relay
- wr/universal_relay_input_mk1
- wr/universal_relay_output_mk1

(Requires OSB for universe wide entity messaging)
Similar to the Planetary relay with a few differences. Channels are player specific, not planet specific. One player's Channel "A" input will never connect to a different player's Channel "A" output. Universal Relays are also unbreakable, the only way to remove them is to open their interface and press the "remove" button, and only the player that placed it is allowed to open its interface. Universal Relays cannot be placed on player ships, as player ships can move between different universes (servers).

### Infinity Crate
- wr/infinity_crate

An unobtainable debug item that must be spawned in. Simply outputs its contents as an infinite matter stream. Does not split its outputs evenly.
