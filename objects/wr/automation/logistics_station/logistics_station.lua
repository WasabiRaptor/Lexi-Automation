function onInteraction()
    -- if root.allRecipes ~= nil then
    --     -- if we have that callback we can use our custom gui
	--     return {"ScriptPane", { gui = { }, scripts = {"/metagui.lua"}, ui = "wr_automation:crafting"}}
    -- end
    --otherwise use the vanilla crafting gui which will have some slightly worse recipes
    return { "OpenCraftingInterface", config.getParameter("interactData")}

end
