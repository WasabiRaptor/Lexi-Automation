local materialList = jarray()
for _, path in ipairs(assets.byExtension("material")) do
    local materialConfig = assets.json(path)
    materialList[materialConfig.materialId] = materialConfig.materialName
end
assets.add("/interface/wr/automation/extractor/materialList.config", sb.printJson(materialList))
