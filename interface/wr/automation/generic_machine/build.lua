cfg = root.assetJson("/interface/wr/automation/generic_machine/generic_machine.ui")
cfg.title = world.getObjectParameter(pane.sourceEntity(), "shortdescription")
cfg.icon = world.getObjectParameter(pane.sourceEntity(), "inventoryIcon")
if not (cfg.icon:sub(1,1) == "/") then
    cfg.icon = root.itemConfig(world.entityName(pane.sourceEntity())).directory .. cfg.icon
end
