--[[
API.lua
Appearance Menu Mod API

Usage:
## GetAppearancesForEntity function
   local AMM = GetMod("AppearanceMenuMod")
   local possibleAppearances = AMM.API.GetAppearancesForEntity(targetPuppet)

## GetAppearancesForRecord function
   local AMM = GetMod("AppearanceMenuMod")
   local possibleAppearances = AMM.API.GetAppearancesForRecord("Character.Judy", true)
   
## ChangeAppearance function
   local AMM = GetMod("AppearanceMenuMod")
   AMM.API.ChangeAppearance(targetPuppet, "judy_panties")

## GetAMMCharacters function
   local AMM = GetMod("AppearanceMenuMod")
   local characters = AMM.API.GetAMMCharacters()
   local character = characters[1]
   print(character.name, character.record)

## GetAMMProps function
   local AMM = GetMod("AppearanceMenuMod")
   local props = AMM.API.GetAMMProps()
   local prop = props[1]
   print(prop.name, prop.path)

## GetPropByName function
   local AMM = GetMod("AppearanceMenuMod")
   local prop = AMM.API.GetPropByName("Walkie Talkie")
   print(prop.name, prop.path)

## version property
   local AMM = GetMod("AppearanceMenuMod")
   print(AMM.API.version)

Copyright(c) 2022 MaximiliumM
]]


API = {
   version = AMM.currentVersion,
}

-- param entity NPCPuppet or vehicleObject
-- param appearance String
function API.ChangeAppearance(entity, appearance)
   if entity:IsNPC() then
      ent = AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), AMM:GetNPCName(entity),AMM:GetScanAppearance(entity), nil)
   elseif entity:IsVehicle() then
      ent = AMM:NewTarget(entity, 'vehicle', AMM:GetScanID(entity), AMM:GetVehicleName(entity), AMM:GetScanAppearance(entity), nil)
   end

   if ent then
      AMM:ChangeAppearanceTo(ent, appearance)
   end
end

-- param entity NPCPuppet or vehicleObject
-- param custom Boolean optional
-- return table[String] ## List of Appearances
function API.GetAppearancesForEntity(entity, custom)
   if not custom then
      local tdbid = AMM:GetScanID(entity)
      local options = {}
      for app in db:urows(f("SELECT app_name FROM appearances WHERE entity_id = '%s' ORDER BY app_name ASC", tdbid)) do
         table.insert(options, app)
      end

      return options
   end

   return AMM:GetAppearanceOptions(entity)
end

-- param record String
-- param custom Boolean optional
-- return table[String] ## List of Appearances
function API.GetAppearancesForRecord(record, custom)
   local tdbid = AMM:GetScanID(record)

   if not custom then
      local options = {}
      for app in db:urows(f("SELECT app_name FROM appearances WHERE entity_id = '%s' ORDER BY app_name ASC", tdbid)) do
         table.insert(options, app)
      end

      return options
   end

   return AMM:GetAppearanceOptionsWithID(tdbid)
end

-- return table[table[name, record]] ## List of Characters with Names and Records
-- Example: character.name, character.record
function API.GetAMMCharacters()
   local records = {}

   for record in db:nrows("SELECT entity_name, entity_path FROM entities WHERE entity_path LIKE '%_character%' AND entity_path NOT LIKE '%Player%' ORDER BY entity_name ASC") do
      table.insert(records, {name = record.entity_name, record = record.entity_path})
   end

   return records
end

-- return table[table[name, path]] ## List of Props with Names and Paths
-- Example: prop.name, prop.path
function API.GetAMMProps()
   local props = {}

   for prop in db:nrows("SELECT entity_name, template_path FROM entities WHERE entity_path LIKE '%_props%' ORDER BY entity_name ASC") do
      table.insert(props, {name = prop.entity_name, path = prop.template_path})
   end

   return props
end

-- return table[name, path] ## Prop with Name and Path
-- Example: prop.name, prop.path
function API.GetPropByName(propName)
   local path = nil

   for prop in db:urows(f('SELECT template_path FROM entities WHERE entity_name = "%s"', propName)) do
      path = prop
   end

   if path then return {name = propName, path = path}
   else
      print("[AMM Error] Can't find Prop: ", propName)
      return false
   end
end

return API