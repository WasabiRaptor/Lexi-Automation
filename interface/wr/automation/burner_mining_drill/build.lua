cfg = root.assetJson("/interface/wr/automation/burner_mining_drill/burner_mining_drill.ui")
cfg.title = world.getObjectParameter(pane.sourceEntity(), "shortdescription")
cfg.icon = world.getObjectParameter(pane.sourceEntity(), "inventoryIcon")
if not (cfg.icon:sub(1,1) == "/") then
    cfg.icon = root.itemConfig(world.entityName(pane.sourceEntity())).directory .. cfg.icon
end
