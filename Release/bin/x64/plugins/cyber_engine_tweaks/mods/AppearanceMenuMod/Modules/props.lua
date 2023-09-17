Props = {}

-- Flags --
local despawnInProgress = false
local saveAllInProgress = false

-- Constant: how far from a trigger should V be before it becomes active? E.g., Jamie sets 200 here
-- TODO: Might hook that up to a user configurable setting.
local PLAYER_TRIGGER_DIST = 60

-- Constant: how many backups of each individual preset should we keep before deleting the oldest?
-- TODO: Might hook that up to a user configurable setting.
local NUM_TOTAL_BACKUPS = 5

function Props:NewProp(uid, id, name, template, posString, scale, app, tag)
  local obj = {}
	obj.handle = ''
  obj.hash = ''
  obj.uid = uid
	obj.id = id
  obj.category = Props:GetPropCategory(id)
	obj.name = name
  obj.parameters = Props:GetParameters(template)
  obj.path = Props:GetEntityPath(template)
	obj.template = template
  obj.appearance = app
  obj.tag = tag
  obj.entityID = ''
  obj.mappinData = nil
  obj.spawned = false

  local pos = loadstring("return "..posString, '')()
  obj.pos = Vector4.new(pos.x, pos.y, pos.z, pos.w)
  obj.angles = EulerAngles.new(pos.roll, pos.pitch, pos.yaw)
  obj.scale = loadstring("return "..scale, '')()
	obj.type = "Prop"
  obj.isVehicle = Props:CheckIfVehicle(id)

  return AMM.Entity:new(obj)
end

function Props:NewTrigger(triggerString)
  local obj = {}

  obj.str = triggerString
	obj.pos = Util:GetPosFromString(triggerString)
	obj.type = "Trigger"

  return obj
end

function Props:NewPreset(name)
  local obj = {}

  obj.name = (name or 'My Preset'):gsub(".json", "")
  obj.props = {}
  obj.lights = {}
  obj.customIncluded = false

  while io.open(f("./User/Decor/%s.json", obj.name), "r") do
		local num = obj.name:match("%((%g+)%)")
		if num then num = tonumber(num) + 1 else num = 1 end
		obj.name = obj.name:gsub(" %("..tostring(num - 1).."%)", "")
		obj.name = obj.name.." ("..tostring(num)..")"
	end

  return obj
end

function Props:new()

  -- Main Properties
  Props.presets = {}
  Props.entities = {}
  Props.spawnedPropsList = {}
  Props.spawnedProps = {}
  Props.hiddenProps = {}
  Props.savedProps = {}
  Props.currentSavedProps = {}
  Props.triggers = {}
  Props.tags = {}
  Props.homes = {}
  Props.homeTags = nil
  Props.categories = {}
  Props.categoriesNames = {}
  Props.savingProp = ''
  Props.editingTags = {}
  Props.activeProps = {}
  Props.activeLights = {}
  Props.cachedActivePropsByHash = {}
  Props.presetLoadInProgress = false
  Props.activePreset = ''
  Props.selectedPreset = {name = "No Preset Available"}
  Props.removingFromTag = ''
  Props.savingPreset = ''
  Props.searchQuery = ''
  Props.savedPropsSearchQuery = ''
  Props.searchBarWidth = 500
  Props.lastSearchQuery = nil
  Props.moddersList = {}
  Props.filterByType = false
  Props.showLightsOnly = false
  Props.showTargetOnly = false
  Props.showNearbyOnly = false
  Props.showNearbyRange = 3
  Props.showCustomizableOnly = false
  Props.showCustomPropsOnly = false
  Props.showSaveToTag = false
  local txt = Props.saveToTag or ''
  Props.saveToTag = nil
  Props.buildMode = false
  Props.modesStatesBeforeBuild = {}
  Props.sizeX = 0
  Props.total = 0
  Props.totalPerTag = {}
  Props.cachedTagPosStrings = {}
  Props.cachedFilteredByCategoryProps = {}
  Props.savedPropsDisplayMode = "Tags"
  Props.displayModeOptions = {"Tags", "Categories", "Both"}

  return Props
end

function Props:Initialize()

  Props.modesStatesBeforeBuild = {god = AMM.Tools.godMode, passive = AMM.Tools.playerVisibility}

  if Props.activePreset ~= '' then
    Props:LoadPreset(Props.activePreset)
  end

  Props.savedProps = {}
  Props.savedProps['all_props'] = Props:GetProps()
  Props.triggers = Props:GetTriggers()
  Props.tags = Props:GetTags()
  Props.categories, Props.categoriesNames = Props:GetCategories()

  if Props.homeTags then
    Props:LoadHomes(Props.homeTags)
  end
end

function Props:Update()
  if Props.activePreset ~= '' then
    Props.presets = Props:LoadPresets()
    Props.moddersList = {}
    Props.activePreset.customIncluded = false
    Props.activePreset.props, Props.activePreset.lights = Props:GetPropsForPreset()
    Props.savedProps = {}
    Props.savedProps['all_props'] = Props:GetProps()
    Props.activeLights = {}
    Props.currentSavedProps = {}
    Props.lastSearchQuery = ''
    Props.triggers = Props:GetTriggers()
    Props.tags = Props:GetTags()
    Util.playerLastPos = ''
    spdlog.info(f('during update of %s', Props.activePreset))
    Props:SavePreset(Props.activePreset)
  else
    Props.savedProps = {}
    Props.savedProps['all_props'] = {}
    Props.tags = {}
  end

  Props.total = Props:GetPropsCount()
end

function Props:Draw(AMM)
  if ImGui.BeginTabItem("Decor") then

    Props.style = {
      buttonHeight = ImGui.GetFontSize() * 2,
      buttonWidth = -1,
      halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 8)
    }

    if Props.sizeX == 0 then
      Props.sizeX = ImGui.GetWindowContentRegionWidth()
    end

    if AMM.userSettings.tabDescriptions then
      AMM.UI:TextColored("Decorating")
      ImGui.TextWrapped("Spawn Props to decorate your house or anywhere you want to your heart's content! Save Props to make them persist!")
      AMM.UI:Spacing(2)
      Props:DrawBuildModeCheckbox()
    end

    if not AMM.userSettings.tabDescriptions then
      AMM.UI:Spacing(2)
      ImGui.Dummy(1, 1)
      ImGui.SameLine(520)
      Props:DrawBuildModeCheckbox()
      ImGui.SameLine(12)
    end

    if ImGui.BeginTabBar("Decor Tabs") then      

      Props:DrawSpawnTab()

      if #Props.savedProps['all_props'] > 0 then
        Props:DrawSavedPropsTab()
      end

      -- If presets > 0
      Props:DrawPresetsTab()

      ImGui.EndTabBar()      
    end

    ImGui.EndTabItem()
  end
end

function Props:DrawSpawnTab()
  if ImGui.BeginTabItem("Spawn") then
    Props:DrawSpawnedProps()
    Props:DrawCategories()
    ImGui.EndTabItem()
  end
end

function Props:DrawSavedPropsTab()
  if ImGui.BeginTabItem("Saved Props") then
    Props:DrawHeaders()
    ImGui.EndTabItem()
  end
end

function Props:DrawPresetsTab()
  if ImGui.BeginTabItem("Presets") then
    Props:DrawPresetConfig()
    ImGui.EndTabItem()
  end
end

-- put it into a local function to unbundle it from the logic
local function drawSpawnedPropsList()
  for i, spawn in ipairs(Props.spawnedPropsList) do
      local spawn = Props.spawnedProps[spawn.uniqueName()]
      local nameLabel = spawn.name
      
      if Tools.lockTarget and Tools.currentTarget ~= '' and Tools.currentTarget.handle then
        if nameLabel == Tools.currentTarget.name then
          AMM.UI:TextColored(nameLabel)
        else
          ImGui.Text(nameLabel)
        end
      else
        ImGui.Text(nameLabel)
      end

      if spawn.appearance and spawn.appearance ~= '' and spawn.appearance ~= "default" then
        ImGui.SameLine()
        ImGui.Text(" -  "..spawn.appearance)
      end

      local favoritesLabels = {"Favorite", "Unfavorite"}
      AMM.Spawn:DrawFavoritesButton(favoritesLabels, spawn)

      ImGui.SameLine()

      if Props.savingProp == spawn.name then
        AMM.UI:TextColored(f("Moving %s to Saved Props", nameLabel))
      else

        if AMM.UI:SmallButton(" Save ##"..spawn.name) then
          -- Cron.Halt()
          if spawn.handle ~= '' then
            Props:SavePropPosition(spawn)
            Props.savingProp = spawn.name
          end
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton("Despawn##"..spawn.name) then
          if spawn.handle ~= '' then
            spawn:Despawn()
          end
        end

        if spawn.handle ~= '' then
                    
          local buttonLabel = " Hide "
          local entID = tostring(spawn.handle:GetEntityID().hash)
          if Props.hiddenProps[entID] ~= nil then
            buttonLabel = " Unhide "
          end

          ImGui.SameLine()
          if AMM.UI:SmallButton(buttonLabel.."##"..spawn.name) then
            Props:ToggleHideProp(spawn)
          end

          ImGui.SameLine()
          if AMM.UI:SmallButton("Target".."##"..spawn.name) then
            AMM.Tools.lockTarget = true
            AMM.Tools:SetCurrentTarget(spawn)
          end

          ImGui.SameLine()
          if AMM.UI:SmallButton("Clone".."##"..spawn.name) then
            Props:DuplicateProp(spawn)
          end
        end
      end
    end
end

function Props:DrawSpawnedProps()
  if #Props.spawnedPropsList > 0 then
    AMM.UI:TextColored("Spawned Props")    
    local buttonLength = ImGui.CalcTextSize("  Save All  ")
    ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - buttonLength)
    
    if AMM.UI:SmallButton("  Save All  ") then
      Props.savingProp = 'all'
      Props:SaveAllProps()
    end

    if saveAllInProgress then
      ImGui.Spacing()
      AMM.UI:TextColored("Moving all Props to Saved Props")
    else
      drawSpawnedPropsList()
    end

    AMM.UI:Separator()
  end
end

function Props:DrawCategories()
  ImGui.PushItemWidth(Props.searchBarWidth)
  Props.searchQuery = ImGui.InputTextWithHint(" ", "Search", Props.searchQuery, 100)
  Props.searchQuery = Props.searchQuery:gsub('"', '')
  ImGui.PopItemWidth()

  if Props.searchQuery ~= '' then
    ImGui.SameLine()
    if ImGui.Button("Clear") then
      Props.searchQuery = ''
    end
  end

  ImGui.Spacing()

  Props.showCustomizableOnly, used = ImGui.Checkbox("Show Customizable Only", Props.showCustomizableOnly)
  if used then Props.entities = {} end

  if AMM.hasCustomProps then
    ImGui.SameLine()

    Props.showCustomPropsOnly, used = ImGui.Checkbox("Show Custom Props Only", Props.showCustomPropsOnly)
    if used then Props.entities = {} end
  end

  ImGui.Spacing()

  AMM.UI:TextColored("Select Prop To Spawn:")

  local validCatIDs = Util:GetAllCategoryIDs(Props.categories)
  local customizableIDs = " AND entity_id IN (SELECT entity_id FROM appearances)"
  if not Props.showCustomizableOnly then customizableIDs = '' end
  local customProps = ' AND entity_path LIKE "%%Custom_%%"'
  if not Props.showCustomPropsOnly then customProps = '' end

  if Props.searchQuery ~= '' then
    local entities = {}
    local parsedSearch = Util:ParseSearch(Props.searchQuery, "entity_name")
    local query = 'SELECT * FROM entities WHERE is_spawnable = 1'..customizableIDs..customProps..' AND cat_id IN '..validCatIDs..' AND '..parsedSearch..' ORDER BY entity_name ASC'
    for en in db:nrows(query) do
      table.insert(entities, en)
    end

    if #entities ~= 0 then
      AMM.Spawn:DrawEntitiesButtons(entities, "ALL", Props.style)
    else
      ImGui.Text("No Results")
    end
  else
    local x, y = GetDisplayResolution()
    if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y / 2) then
      for _, category in ipairs(Props.categories) do
        local entities = {}

        if Props.entities[category] == nil or category.cat_name == 'Favorites' then
          if category.cat_name == 'Favorites' then
            local query = "SELECT * FROM favorites_props"
            for fav in db:nrows(query) do
              query = f("SELECT * FROM entities WHERE entity_id = \"%s\" AND cat_id IN %s", fav.entity_id, validCatIDs)
              for en in db:nrows(query) do
                if fav.parameters ~= nil then en.parameters = fav.parameters end
                en.entity_name = fav.entity_name
                table.insert(entities, en)
              end
            end
            if #entities == 0 then
              if ImGui.CollapsingHeader(category.cat_name) then
                ImGui.Text("It's empty :(")
              end
            end
          else
            local query = f('SELECT * FROM entities WHERE is_spawnable = 1 '..customizableIDs..customProps..' AND cat_id == "%s" ORDER BY entity_name ASC', category.cat_id)
            for en in db:nrows(query) do
              if string.find(tostring(en.entity_path), "Vehicle") then
                en.parameters = {veh = true, dist = 6}
                en.entity_path = en.entity_path:gsub("Vehicle", "Props")
              end

              table.insert(entities, en)
            end            
          end

          Props.entities[category] = entities
        end

        if Props.entities[category] ~= nil and #Props.entities[category] ~= 0 then
          local headerFlag = ImGuiTreeNodeFlags.None
				  if AMM.userSettings.favoritesDefaultOpen and category == 'Favorites' then headerFlag = ImGuiTreeNodeFlags.DefaultOpen end
          if ImGui.CollapsingHeader((IconGlyphs[category.cat_icon] or " ").." "..category.cat_name, headerFlag) then
            AMM.Spawn:DrawEntitiesButtons(Props.entities[category], category.cat_name, Props.style)
          end
        end
      end
    end
    ImGui.EndChild()
  end
end

function Props:FilterByCategory(props, tag)
  if next(Props.cachedFilteredByCategoryProps) and not tag then
    return Props.cachedFilteredByCategoryProps.categories, Props.cachedFilteredByCategoryProps.props
  end

  if tag and Props.cachedFilteredByCategoryProps[tag] ~= nil then
    return Props.cachedFilteredByCategoryProps[tag].categories, Props.cachedFilteredByCategoryProps[tag].props
  end

  local propsForDrawing = {}
  local categories = {}
  local categoriesNames = Props.categoriesNames

  for _, prop in ipairs(props) do
    if not propsForDrawing[categoriesNames[prop.category]] then
      propsForDrawing[categoriesNames[prop.category]] = {}
      table.insert(categories, categoriesNames[prop.category])
    end

    table.insert(propsForDrawing[categoriesNames[prop.category]], prop)
  end

  if next(Props.cachedFilteredByCategoryProps) == nil then
    if tag then
      Props.cachedFilteredByCategoryProps[tag] = {categories = categories, props = propsForDrawing}
    else
      Props.cachedFilteredByCategoryProps = {categories = categories, props = propsForDrawing}
    end
  end

  return categories, propsForDrawing
end

function Props:FilterProps(props)
  local propsForDrawing = {}
  for _, prop in ipairs(props) do
    if Props.showTargetOnly then
      if Tools.currentTarget.handle and Tools.currentTarget.handle ~= '' and Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' 
      and Props.activeProps[prop.uid].handle:GetEntityID().hash == Tools.currentTarget.handle:GetEntityID().hash then
        table.insert(propsForDrawing, prop)
      end
    elseif Props.showNearbyOnly then
      local playerPos = AMM.player:GetWorldPosition()
      if Props.activeProps[prop.uid] and Props.activeProps[prop.uid].handle and Props.activeProps[prop.uid].handle ~= '' then
        local propPos = Props.activeProps[prop.uid].handle:GetWorldPosition()
        local distanceFromPlayer = Util:VectorDistance(playerPos, propPos)
        if Props.activeProps[prop.uid].handle ~= '' and distanceFromPlayer < Props.showNearbyRange then
          table.insert(propsForDrawing, prop)
        end
      end
    else
      table.insert(propsForDrawing, prop)
    end
  end

  return propsForDrawing
end

function Props:DrawCategoryHeaders(props, tag)
  local categories, props = Props:FilterByCategory(props, tag)

  if #categories > 0 then
    for _, category in ipairs(categories) do
      local categoryHeader = ImGui.CollapsingHeader(category.."##"..(tag or ''))

      if categoryHeader then
        Props:DrawProps(props[category], category)
      end
    end
  end
end

function Props:DrawProps(props, category)
  AMM.UI:List(category or '', #props, Props.style.buttonHeight + 15, function(i)
    Props:DrawSavedProp(props[i])
  end)
end

function Props:DrawSavedProp(prop)
  if Tools.currentTarget.handle and Tools.currentTarget.handle ~= '' and Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' 
  and Props.activeProps[prop.uid].handle:GetEntityID().hash == Tools.currentTarget.handle:GetEntityID().hash then
    AMM.UI:TextColored(prop.name)
  else
    ImGui.Text(prop.name)
  end

  if Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' then
    ImGui.SameLine()
    AMM.UI:TextColored("  In World")
  end

  if AMM.UI:SmallButton("Remove##"..prop.uid) then    
    Props:RemoveProp(prop)
  end

  ImGui.SameLine()
  if AMM.UI:SmallButton("Rename##"..prop.uid) then
    Props.rename = ''
	  ImGui.OpenPopup("Rename Prop##"..prop.uid)
  end

  Props:RenamePropPopup(prop)

  if Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' then
    ImGui.SameLine()
    if AMM.UI:SmallButton("Update##"..prop.uid) then
      Props:SavePropPosition(Props.activeProps[prop.uid])
    end

    local buttonLabel = " Hide "
    local entID = tostring(Props.activeProps[prop.uid].handle:GetEntityID().hash)
    if Props.hiddenProps[entID] ~= nil then
      buttonLabel = " Unhide "
    end
    ImGui.SameLine()
    if AMM.UI:SmallButton(buttonLabel.."##"..prop.uid) then
      Props:ToggleHideProp(Props.activeProps[prop.uid])
    end

    ImGui.SameLine()
    if AMM.UI:SmallButton("Clone".."##"..prop.uid) then
      Props:DuplicateProp(Props.activeProps[prop.uid])
    end

    ImGui.SameLine()
    if AMM.UI:SmallButton("Target".."##"..prop.uid) then      
      AMM.Tools:SetCurrentTarget(Props.activeProps[prop.uid])    
      AMM.Tools.lockTarget = true

      Props:SavePreset(Props.activePreset)
    end    

    if Props.editingTags[prop.uid] == nil then
      Props.editingTags[prop.uid] = prop.tag
    end

    ImGui.PushItemWidth(248)
    Props.editingTags[prop.uid] = ImGui.InputText(" ##"..prop.uid, Props.editingTags[prop.uid], 100)
    ImGui.PopItemWidth()

    ImGui.SameLine(272)

    if AMM.UI:SmallButton(" Move To Tag ##"..prop.uid) and Props.editingTags[prop.uid] ~= '' then
      Props:UpdatePropTag(prop, Props.editingTags[prop.uid])

      Props:Update()
      Props.editingTags[i] = nil
    end

    ImGui.SameLine()

    local buttonLabel = "Show On Map"
    if Props.activeProps[prop.uid].mappinData ~= nil then
      buttonLabel = "Hide From Map"
    end

    if AMM.UI:SmallButton(buttonLabel.."##"..prop.uid) then
      if Props.activeProps[prop.uid].mappinData ~= nil then
        Props:RemoveFromMap(Props.activeProps[prop.uid].mappinData)
        Props.activeProps[prop.uid].mappinData = nil
      else
        Props.activeProps[prop.uid].mappinData = Props:ShowOnMap(prop.pos)
      end
    end
  end

  AMM.UI:Spacing(4)
end

function Props:DrawPresetConfig()
  if #Props.presets == 0 then
    Props.presets = Props:LoadPresets()
  end

  if Props.activePreset == '' and #Props.presets ~= 0 then
    Props.selectedPreset = Props.presets[1]
    Props:ActivatePreset(Props.selectedPreset)
  elseif Props.activePreset ~= '' then
    Props.selectedPreset = Props.activePreset
  end

  if despawnInProgress then
    ImGui.Spacing()
    ImGui.Text("Despawn In Progress. Please Wait.")
    ImGui.Spacing()
  elseif ImGui.BeginCombo("Presets", Props.selectedPreset.name, ImGuiComboFlags.HeightLarge) then
    for i, preset in ipairs(Props.presets) do
      if ImGui.Selectable(f("%s##%s", preset.name, i), (preset.name == Props.selectedPreset.name)) then
        Props.selectedPreset = preset

        if Props.selectedPreset.name ~= Props.activePreset.name then
          Props:ActivatePreset(Props.selectedPreset)
        end
      end
    end
    ImGui.EndCombo()
  end

  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("User presets are saved in AppearanceMenuMod/User/Decor folder")
  end

  ImGui.Spacing()

  if Props.activePreset.customIncluded then
    ImGui.Text("This preset includes Custom Props")

    ImGui.SameLine()
    AMM.UI:SmallButton(" ? ")

    if ImGui.IsItemHovered() then
      local modders = {}
      for k, _ in pairs(Props.moddersList) do
        table.insert(modders, k)
      end

      ImGui.BeginTooltip()
      ImGui.PushTextWrapPos(500)
      ImGui.TextWrapped("Custom Props made by: \n"..table.concat(modders, "\n"))
      ImGui.PopTextWrapPos()
      ImGui.EndTooltip()
    end

    AMM.UI:Spacing(8)
  end

  if ImGui.Button("New Preset", Props.style.buttonWidth, Props.style.buttonHeight) then
    if #Props.savedProps['all_props'] > 0 then
      Props:SavePreset(Props.activePreset)
    end

    Props:DespawnAllSavedProps()
    Props:DeleteAll()
    Props.activePreset = Props:NewPreset()
    Props.selectedPreset = Props.activePreset
    Props:Update()
  end

  if Props.activePreset ~= '' then

    if ImGui.Button("Save", Props.style.buttonWidth, Props.style.buttonHeight) then        
      Props:SavePreset(Props.activePreset, nil, true)
    end

    if ImGui.Button("Rename", Props.style.buttonWidth, Props.style.buttonHeight) then        
      Props.rename = ''
      ImGui.OpenPopup("Rename Preset")
    end

    if ImGui.Button("Delete", Props.style.buttonWidth, Props.style.buttonHeight) then
      popupDelegate = AMM:OpenPopup("Preset")
    end

    if ImGui.Button("Backup", Props.style.buttonWidth, Props.style.buttonHeight) then
      Props:BackupPreset(Props.activePreset)
    end
  end

  local style = {
    buttonHeight = ImGui.GetFontSize() * 2,
    halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12),
    buttonWidth = -1,
  }

  AMM:BeginPopup("WARNING", nil, true, popupDelegate, style)

  Props:RenamePresetPopup(style)
end

function Props:DrawBuildModeCheckbox()
  local offSet = Props.sizeX - ImGui.CalcTextSize("Build Mode")

  if AMM.userSettings.tabDescriptions then
    ImGui.Dummy(offSet - 70, 10)
    ImGui.SameLine()
  end

  AMM.UI:TextColored("Build Mode")
  ImGui.SameLine()
  
  Props.buildMode, modeChange = AMM.UI:SmallCheckbox(Props.buildMode)

  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("This allows better integration with Direct mode when using gamepad. It also enables a small information window that sticks around.")
  end

  if modeChange then
    AMM.Props:ToggleBuildMode(true)
  end
end

function Props:DrawHeaders()
  if #Props.savedProps['all_props'] > 0 then

    ImGui.PushItemWidth(Props.searchBarWidth)
    Props.savedPropsSearchQuery = ImGui.InputTextWithHint(" ", "Search", Props.savedPropsSearchQuery, 100)
    Props.savedPropsSearchQuery = Props.savedPropsSearchQuery:gsub('"', '')
    ImGui.PopItemWidth()

    if Props.savedPropsSearchQuery ~= '' and Props.savedPropsSearchQuery ~= Props.lastSearchQuery then
      local parsedSearch, originalQuery = Util:ParseSearch(Props.savedPropsSearchQuery, "name")
      Props.lastSearchQuery = Props.savedPropsSearchQuery
      Props.currentSavedProps = Props:GetProps({parsedSearch, originalQuery})
    elseif Props.savedPropsSearchQuery ~= Props.lastSearchQuery then
      Props.currentSavedProps = {}
    end

    if Props.savedPropsSearchQuery ~= '' then
      ImGui.SameLine()
      if ImGui.Button("Clear") then
        Props.savedPropsSearchQuery = ''
      end
    end

    ImGui.Spacing()

    local filtersChanged = false

    Props.showNearbyOnly, clicked = ImGui.Checkbox("Show Nearby Only", Props.showNearbyOnly)    
    if clicked then filtersChanged = true end

    if Props.showNearbyOnly then
      ImGui.SameLine()
      ImGui.PushItemWidth(200)
      Props.showNearbyRange = ImGui.InputFloat("Distance", Props.showNearbyRange, 0.5, 10, "%.1f")
      ImGui.PopItemWidth()
      
      ImGui.Spacing()
    end

    if not Props.showNearbyOnly then
      ImGui.SameLine(300)
    end
    Props.showLightsOnly, clicked = ImGui.Checkbox("Show Lights Only", Props.showLightsOnly)
    if clicked then filtersChanged = true end


    if Props.showLightsOnly then
      Props.currentSavedProps = Props:GetAllLights(Props.currentSavedProps)
    end
    
    if Tools.lockTarget then
      if Props.showNearbyOnly then
        ImGui.SameLine(300)
      end
      ImGui.Spacing()
      Props.showTargetOnly, clicked = ImGui.Checkbox("Show Locked Target Only", Props.showTargetOnly)      
      if clicked then filtersChanged = true end
    else
      Props.showTargetOnly = false
    end

    if filtersChanged then
      Props.cachedFilteredByCategoryProps = {}
      Props.currentSavedProps = {}
    end

    ImGui.Spacing()

    Props.showSaveToTag = ImGui.Checkbox("Save To Specific Tag", Props.showSaveToTag)

    if Props.showSaveToTag then
      ImGui.SameLine()
      local txt = Props.saveToTag or ''
      ImGui.PushItemWidth(400)
      txt = ImGui.InputTextWithHint(" ##"..'saveToTag', "Type Tag here", txt, 100)
      ImGui.PopItemWidth()
      if txt ~= '' then 
        Props.saveToTag = txt
      else
        Props.saveToTag = nil
      end
    else
      Props.saveToTag = nil
    end

    ImGui.Spacing()

    for _, option in ipairs(Props.displayModeOptions) do
    	if ImGui.RadioButton(option, Props.savedPropsDisplayMode == option) then
    		Props.cachedFilteredByCategoryProps = {}
        Props.savedPropsDisplayMode = option
    	end

    	ImGui.SameLine()
    end

    ImGui.Spacing()

    AMM.UI:TextColored("Saved Props:")

    ImGui.Spacing()

    local shouldShowNoPropsLabel = true

    if #Props.currentSavedProps ~= 0 then
      local props = Props:FilterProps(Props.currentSavedProps)
      if #props > 0 then
        shouldShowNoPropsLabel = false

        if Props.filterByType then
          Props:DrawCategoryHeaders(props)
        else
          Props:DrawProps(props)
        end
      end
    elseif #Props.currentSavedProps == 0 and Props.savedPropsSearchQuery == '' then  
      if Props.savedPropsDisplayMode == "Categories" then
        local props = Props:FilterProps(Props.savedProps['all_props'])

        if #props > 0 then
          shouldShowNoPropsLabel = false
          Props:DrawCategoryHeaders(props)
        end
      else
        for _, tag in ipairs(Props.tags) do
          if Props.savedProps[tag] == nil then
            Props.savedProps[tag] = Props:GetProps(nil, tag)
          end

          local propsForTag = Props:FilterProps(Props.savedProps[tag])

          if #propsForTag > 0 then
            shouldShowNoPropsLabel = false

            local tagHeader = ImGui.CollapsingHeader(tag.."##tagHeader")
            local countLength = ImGui.CalcTextSize(tostring(Props.totalPerTag[tag]))
            ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - countLength)
            AMM.UI:TextColored(tostring(Props.totalPerTag[tag]))

            if tagHeader then               
              Props:DrawTagActions(Props.savedProps[tag], tag)

              if Props.savedPropsDisplayMode == "Both" then -- Both means Tags + Categories
                Props:DrawCategoryHeaders(propsForTag, tag)
                AMM.UI:Separator()
              else -- Tags only
                Props:DrawProps(propsForTag, tag)
              end
            end
          end
        end
      end
    end

    if shouldShowNoPropsLabel then
      AMM.UI:TextError("No Props With These Conditions")
    end

    AMM.UI:Spacing(3)

    ImGui.Text("Total Props: "..Props.total)
  end
end

function Props:DrawTagActions(props, tag)

  AMM.UI:Spacing(3)
  
  tag = tag or 'Misc'

  if Props.editingTags[tag] == nil then
    Props.editingTags[tag] = tag
  end

  Props.editingTags[tag] = ImGui.InputText("Tag##"..tag, Props.editingTags[tag], 100)

  if AMM.UI:SmallButton("  Update Tag  ##"..tag) and Props.editingTags[tag] ~= '' then
    for _, prop in ipairs(props) do
      Props:UpdatePropTag(prop, Props.editingTags[tag])
    end

    Props:Update()
    Props.editingTags[tag] = nil
  end

  ImGui.SameLine()
  if Props.removingFromTag == tag then
    ImGui.Text("Removing all Props from tag...")

    ImGui.SameLine()
    if AMM.UI:SmallButton(" Cancel ##"..tag) then
      Props.removingFromTag = "cancel"
    end
  else
    if AMM.UI:SmallButton("  Remove All Props  ##"..tag) then
      Props.removingFromTag = tag

      Cron.After(3.0, function()
        if Props.removingFromTag ~= 'cancel' then
          for _, prop in ipairs(props) do
            Props:RemoveProp(prop)
          end
        end

        Props.removingFromTag = ''
      end)
    end
  end

  AMM.UI:Spacing(3)

  local buttonLabel = " Add Home Marker To Map "

  if Props.homes[tag] ~= nil then
    buttonLabel = " Remove Home Marker From Map "
  end

  if ImGui.Button(buttonLabel.."##"..tag, Props.style.halfButtonWidth, Props.style.buttonHeight) then
    if buttonLabel == " Add Home Marker To Map " then
      Props.homes[tag] = Props:AddHomeMarker(tag)  
    else
      Props:RemoveFromMap(Props.homes[tag])
      Props.homes[tag] = nil
    end
  end

  ImGui.SameLine()

  if ImGui.Button("Teleport To Location", Props.style.halfButtonWidth, Props.style.buttonHeight) then
    Props:TeleportToTag(tag)
  end

  if ImGui.Button("Update Tag Location", Props.style.halfButtonWidth, Props.style.buttonHeight) then
    Props:UpdateTagLocation(tag)    
  end

  ImGui.SameLine()
  if Props.savingPreset == '' then
    if ImGui.Button("Share Preset With This Tag Only", Props.style.halfButtonWidth, Props.style.buttonHeight) then
      Props:SharePresetWithTag(tag)
      Props.savingPreset = tag
    end
  elseif Props.savingPreset == tag then
    AMM.UI:TextCenter("Saved Preset to AppearanceMenuMod/User/Decor folder")

    Cron.After(3.0, function()
      Props.savingPreset = ''
    end)
  end

  if Props.cachedTagPosStrings[tag] == nil then
    local selectStr = f("SELECT DISTINCT trigger FROM saved_props WHERE tag = \"%s\"", tag)
    for triggerStr in db:urows(selectStr) do
      Props.cachedTagPosStrings[tag] = triggerStr
    end
  end

  if Props.cachedTagPosStrings[tag] then
    ImGui.Spacing()
    local pos = loadstring("return "..Props.cachedTagPosStrings[tag], '')()
    ImGui.Text("x:")
    ImGui.SameLine()
    AMM.UI:TextColored(tostring(pos.x))
    ImGui.SameLine()
    ImGui.Text("y:")
    ImGui.SameLine()
    AMM.UI:TextColored(tostring(pos.y))
    ImGui.SameLine()
    ImGui.Text("z:")
    ImGui.SameLine()
    AMM.UI:TextColored(tostring(pos.z))
  end

  AMM.UI:Separator()
end

function Props:RenamePresetPopup(style)
  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
  ImGui.SetNextWindowSize(400, ImGui.GetFontSize() * 10)

  if ImGui.BeginPopupModal("Rename Preset") then
    
    if Props.rename == 'existing' then
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "Existing Name")

      if ImGui.Button("Ok", -1, style.buttonHeight) then
        Props.rename = ''
      end
    else
      if Props.rename == '' then
        Props.rename = Props.activePreset.name
      end

      Props.rename = ImGui.InputText("Name", Props.rename, 30):gsub(".json", "")

      AMM.UI:Spacing(8)

      if ImGui.Button("Save", style.buttonWidth, style.buttonHeight) then
        if not(io.open(f("./User/Decor/%s.json", Props.rename), "r")) then
          local fileName = (Props.activePreset.file_name or Props.activePreset.name):gsub(".json", "")..".json"
          os.remove("./User/Decor/"..fileName)
          Props.activePreset.name = Props.rename
          Props.activePreset.file_name = Props.rename..".json"
          Props:SavePreset(Props.activePreset)
          Props.rename = ''
          ImGui.CloseCurrentPopup()
        else
          Props.rename = 'existing'
        end
      end

      if ImGui.Button("Cancel", style.buttonWidth, style.buttonHeight) then
        Props.rename = ''
        ImGui.CloseCurrentPopup()
      end
    end
    ImGui.EndPopup()
  end
end

function Props:RenamePropPopup(prop)
  local style = {
    buttonHeight = ImGui.GetFontSize() * 2,
    halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12),
    buttonWidth = -1,
  }

  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
  ImGui.SetNextWindowSize(400, ImGui.GetFontSize() * 10)

  if ImGui.BeginPopupModal("Rename Prop##"..prop.uid) then
    
    if Props.rename == '' then
      Props.rename = prop.name
    end

    Props.rename = ImGui.InputText("Name", Props.rename, 50)

    AMM.UI:Spacing(3)

    if ImGui.Button("Save", style.buttonWidth, style.buttonHeight) then
      prop.name = Props.rename

      db:execute(f('UPDATE saved_props SET name = "%s" WHERE uid = %i', Props.rename, prop.uid))

      Props.rename = ''
      ImGui.CloseCurrentPopup()
    end

    if ImGui.Button("Cancel", style.buttonWidth, style.buttonHeight) then
      Props.rename = ''
      ImGui.CloseCurrentPopup()
    end

    ImGui.EndPopup()
  end
end

function Props:SensePropsTriggers()
  local player = Game.GetPlayer()
  if not player then return end
  for _, trigger in ipairs(Props.triggers) do
    local dist = Util:VectorDistance(player:GetWorldPosition(), trigger.pos)

    if dist <= PLAYER_TRIGGER_DIST then
      local props = Props:GetPropsToSpawn(trigger)
      if #props > 0 then
        for _, prop in ipairs(props) do
          if Props.activeProps[prop.uid] == nil then
            Props:SpawnSavedProp(prop)
          end
        end
      end
    end
  end
end

function Props:GetPropsToSpawn(trigger)
  local props = {}
  for prop in db:nrows(f("SELECT * FROM saved_props WHERE trigger = '%s'", trigger.str)) do
    table.insert(props, Props:NewProp(prop.uid, prop.entity_id, prop.name, prop.template_path, prop.pos, prop.scale, prop.app, prop.tag))
  end

  return props
end

function Props:SpawnSavedProp(ent)
  local spawn = Props:SpawnPropInPosition(ent, ent.pos, ent.angles)
  Props.activeProps[ent.uid] = spawn

  if not Props.presetLoadInProgress then
    Cron.After(Props.total / 800, function()
      Props.presetLoadInProgress = false
      Util:RemovePlayerEffects()
    end)
  end

  if Props.total > 500 then
    Props.presetLoadInProgress = true
    Util:AddPlayerEffects()
  end
end

local typeEntEntity = 'entEntity'
local typeEntGameEntity = 'entGameEntity'
local typeProp = 'Prop'
local typeTable = 'table'
local nilString = "nil"
local selectSaveLightsFormat = 'SELECT * FROM saved_lights WHERE uid = %i'

function Props:SpawnPropInPosition(ent, pos, angles)
  local spawnTransform = Game.GetPlayer():GetWorldTransform()
  spawnTransform:SetPosition(pos)
  spawnTransform:SetOrientationEuler(angles)

  local record = ''
  if ent.parameters and type(ent.parameters) == 'string' and string.find(ent.parameters, '{') then
    ent.parameters = loadstring('return '..ent.parameters, '')()

    if ent.parameters.veh then
      local entName = ent.path:match("Props.(.*)")
      record = 'Vehicle.'..entName
    end

    if ent.parameters.rec then
      record = ent.parameters.rec
    end
  end

  if ent.isVehicle then
    record = ent.path
  end

  ent.entityID = exEntitySpawner.Spawn(ent.template, spawnTransform, ent.appearance, record)

  local timerFunc = function(timer)
    local entity = Game.FindEntityByID(ent.entityID)
    if entity then
      ent.handle = entity
      ent.hash = tostring(entity:GetEntityID().hash)
      ent.parameters = {pos, angles}
      ent.spawned = true

      Props.cachedActivePropsByHash[ent.hash] = ent

      if AMM:GetScanClass(ent.handle) == typeEntEntity then -- 'entEntity'
        ent.type = typeEntEntity
      else
        ent.type = typeProp
      end

      if ent.uid then
        for light in db:nrows(f(selectSaveLightsFormat, ent.uid)) do -- 'SELECT * FROM saved_lights WHERE uid = %i'
          AMM.Light:SetLightData(ent, light)
        end
      end

      local components = Props:CheckForValidComponents(ent.handle)
      if components then
        ent.defaultScale = {
          x = components[1].visualScale.x * 100,
          y = components[1].visualScale.x * 100,
          z = components[1].visualScale.x * 100,
         }

        if ent.scale and ent.scale ~= nilString then
          AMM.Tools:SetScale(components, ent.scale)
        else
          ent.scale = {
            x = components[1].visualScale.x * 100,
            y = components[1].visualScale.y * 100,
            z = components[1].visualScale.z * 100,
           }
        end
      end

      Cron.Halt(timer)
    end
  end

  Cron.Every(0.1, {tick = 1}, timerFunc)

  return ent
end

local locationNamePattern = "%-%-%-%-"
function Props:GetTagBasedOnLocation()
  if not AMM.Tools then return end
  
  local playerPos = AMM.player:GetWorldPosition()
  for _, loc in ipairs(AMM.Tools:GetLocations()) do
    if loc.loc_name:match(locationNamePattern) == nil then -- "%-%-%-%-"
      local pos = Vector4.new(loc.x, loc.y, loc.z, loc.w)
      local dist = Util:VectorDistance(playerPos, pos)

      if dist <= 200 and loc and loc.loc_name then
        loc.loc_name
      end
    end
  end

  return "Misc"
end

function Props:LoadHomes(userHomes)
  for _, tag in ipairs(userHomes) do
    Props.homes[tag] = Props:AddHomeMarker(tag)
  end
end

function Props:UpdateTagLocation(tag)
  local currentPlayerLocation = Game.GetPlayer():GetWorldPosition()
  local posStr = Util:GetPosString(currentPlayerLocation)
  db:execute(f("UPDATE saved_props SET trigger = \"%s\" WHERE tag = '%s'", posStr, tag))
  Props:Update()
end

function Props:TeleportToTag(tag)
  local loc = nil
  tag = tag or 'Misc'

  for trigger in db:urows(f('SELECT DISTINCT trigger FROM saved_props WHERE tag = "%s"', tag)) do
    local newTrigger = Props:NewTrigger(trigger)
    loc = AMM.Tools:NewLocationData(tag, {pos = newTrigger.pos, yaw = Game.GetPlayer():GetWorldYaw()})
  end

  AMM.Tools:TeleportToLocation(loc)
end

function Props:AddHomeMarker(tag)
  local pos = nil
  tag = tag or 'Misc'

  for trigger in db:urows(f('SELECT DISTINCT trigger FROM saved_props WHERE tag = "%s"', tag)) do
    local newTrigger = Props:NewTrigger(trigger)
    pos = newTrigger.pos
  end

  if pos then
    local mappinData = gamemappinsMappinData.new()
    mappinData.mappinType = TweakDBID.new('Mappins.FastTravelStaticMappin')
    mappinData.variant = gamedataMappinVariant.ApartmentVariant

    return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
  end
end

function Props:ShowOnMap(pos)
  local variant = 'FastTravelVariant'

  local mappinData = NewObject('gamemappinsMappinData')
  mappinData.mappinType = TweakDBID.new('Mappins.QuestDynamicMappinDefinition')
  mappinData.variant = Enum.new('gamedataMappinVariant', variant)
  mappinData.visibleThroughWalls = true

  return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
end

function Props:RemoveFromMap(mappinData)
  Game.GetMappinSystem():UnregisterMappin(mappinData)
end

function Props:UpdatePropTag(prop, newTag)
  local newTagTrigger = nil
  newTag = newTag or 'Misc'
  for trigger in db:urows(f("SELECT trigger FROM saved_props WHERE tag = '%s'", newTag)) do
    newTagTrigger = trigger
  end
  
  db:execute(f('UPDATE saved_props SET tag = "%s", trigger = "%s" WHERE uid = %i', newTag, newTagTrigger, prop.uid))
end

function Props:ToggleAllActiveLights()
  local lights = Props:GetAllActiveLights()

  if lights then
    for _, light in ipairs(lights) do
      AMM.Light:ToggleLight(light)
    end
  end
end

function Props:ToggleHideProp(ent)  
  local hash = tostring(ent.handle:GetEntityID().hash)
  local components = Props:CheckForValidComponents(ent.handle)
  if Props.hiddenProps[hash] ~= nil then
    if AMM.Light:IsAMMLight(ent) then
      local light = AMM.Light:GetLightData(ent)
      AMM.Light:ToggleLight(light)
    elseif components then
      for _, comp in ipairs(components) do
        comp:Toggle(true)
      end
    else
      local prop = Props.hiddenProps[hash]
      local spawn = Props:SpawnPropInPosition(prop.ent, prop.pos, prop.angles)
      if ent.type ~= typeProp or ent.type ~= typeEntEntity and spawn.uniqueName then
        Props.spawnedProps[spawn.uniqueName()] = spawn
      end
    end

    Props.hiddenProps[hash] = nil
  else
    local pos = ent.handle:GetWorldPosition()
    local angles = GetSingleton('Quaternion'):ToEulerAngles(ent.handle:GetWorldOrientation())
    
    if AMM.Light:IsAMMLight(ent) then
      local light = AMM.Light:GetLightData(ent)
      AMM.Light:ToggleLight(light)
    elseif components then
      for _, comp in ipairs(components) do
        comp:Toggle(false)
      end
    else
      if pos == nil then
        pos = ent.parameters[1]
        angles = ent.parameters[2]
      end

      exEntitySpawner.Despawn(ent.handle)
    end

    Props.hiddenProps[hash] = {ent = ent, pos = pos, angles = angles}
  end
end

function Props:SaveAllProps()
  saveAllInProgress = true
  Props:BackupPreset(Props.activePreset)

  Cron.After(1.0, function()
    for _, spawn in ipairs(Props.spawnedPropsList) do
      if spawn.handle ~= '' then        
        Props:SavePropPosition(spawn)
      end
    end
    
    Cron.After(1.0, function()    
      saveAllInProgress = false
    end)

    Props:Update()
    Props:SensePropsTriggers()
    AMM:UpdateSettings()
  end)
end

function Props:SavePropPosition(ent)
  local pos = ent.handle:GetWorldPosition()
  local angles = GetSingleton('Quaternion'):ToEulerAngles(ent.handle:GetWorldOrientation())
	if pos == nil then
		pos = ent.parameters[1]
    angles = ent.parameters[2]
	end

  local app = AMM:GetAppearance(ent)

  local tag = Props.saveToTag or Props:GetTagBasedOnLocation()

  local trigger = Util:GetPosString(Props:CheckForTriggersNearby(pos))
  pos = Util:GetPosString(pos, angles)

  local scale = nil
  if ent.scale and ent.scale ~= nilString then
    scale = Props:GetScaleString(ent.scale)
  end

  local light = AMM.Light:GetLightData(ent)

  if ent.uid then
    
    db:execute(f('UPDATE saved_props SET template_path = "%s", pos = "%s", scale = "%s", app = "%s" WHERE uid = %i', ent.template, pos, scale, app, ent.uid))
    if light then
      db:execute(f('UPDATE saved_lights SET color = "%s", intensity = %f, radius = %f, angles = "%s" WHERE uid = %i', light.color, light.intensity, light.radius, light.angles, ent.uid))
    end
  else
	  db:execute(f('INSERT INTO saved_props (entity_id, name, template_path, pos, trigger, scale, app, tag) VALUES ("%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s")', ent.id, ent.name, ent.template, pos, trigger, scale, app, tag))

    if light then
      for uid in db:urows(f('SELECT uid FROM saved_props ORDER BY uid DESC LIMIT 1')) do
        db:execute(f('INSERT INTO saved_lights (uid, entity_id, color, intensity, radius, angles) VALUES (%i, "%s", "%s", %f, %f, "%s")', uid, ent.id, light.color, light.intensity, light.radius, light.angles))
      end
    end
  end
  
  Cron.After(0.5, function()
    if not ent.uid then
      ent:Despawn()    
    end

    if not saveAllInProgress then
      local preset = Props.activePreset
      if preset == '' then
        preset = Props:NewPreset(tag)
        Props.activePreset = preset
      end

      if Props.savingProp ~= '' then
        Props.savingProp = ''
      end

      Props:Update()
      Props:SensePropsTriggers()
      AMM:UpdateSettings()
    end
  end)

  return true
end

function Props:ToggleBuildMode(systemActivated)
  if not systemActivated then
    Props.buildMode = not Props.buildMode
  end
end

function Props:CheckForTriggersNearby(pos)
  local closestTriggerPos = pos
  for _, trigger in ipairs(Props.triggers) do
    if Util:VectorDistance(pos, trigger.pos) < PLAYER_TRIGGER_DIST then
      closestTriggerPos = trigger.pos
    end
  end

  return closestTriggerPos
end

function Props:CheckDefaultScale(components)
  local defaultScale = components[1].visualScale
  for _, comp in ipairs(components) do
    if comp.visualScale.x ~= 1 then
      defaultScale = comp.visualScale
    end
  end

  return defaultScale
end

local typeEntPhysicalSkinnedMeshComponent = 'entPhysicalSkinnedMeshComponent'
local typeEntSkinnedMeshComponent = 'entSkinnedMeshComponent'

function Props:CheckForValidComponents(handle)
  if handle then
    local components = {}

    for comp in db:urows("SELECT cname FROM components WHERE type = 'Props'") do
      local c = handle:FindComponentByName(CName.new(comp))
      if c and NameToString(c:GetClassName()) ~= typeEntPhysicalSkinnedMeshComponent -- 'entPhysicalSkinnedMeshComponent'
      and NameToString(c:GetClassName()) ~= typeEntSkinnedMeshComponent then -- 'entSkinnedMeshComponent'
        table.insert(components, c)
      end
    end

    if #components > 0 then return components end
  end

  return false
end

function Props:RemoveProp(ent)
  if Props.activeProps[ent.uid] and Props.activeProps[ent.uid].handle ~= '' then Props:DespawnProp(ent) end
  db:execute(f("DELETE FROM saved_props WHERE uid = '%i'", ent.uid))
  db:execute(f("DELETE FROM saved_lights WHERE uid = '%i'", ent.uid))
  Props:Update()
end

function Props:ChangePropAppearance(ent, app)
  Game.FindEntityByID(ent.entityID):GetEntity():Destroy()
  Props.cachedActivePropsByHash[ent.hash] = nil

  local lockedTarget = AMM.Tools.lockTarget

  local transform = Game.GetPlayer():GetWorldTransform()
  local pos = ent.handle:GetWorldPosition()
  local angles = GetSingleton('Quaternion'):ToEulerAngles(ent.handle:GetWorldOrientation())
  transform:SetPosition(pos)
  transform:SetOrientationEuler(angles)

  ent.entityID = exEntitySpawner.Spawn(ent.template, transform, app)
  
  local timerFunc = function(timer)
    local entity = Game.FindEntityByID(ent.entityID)

    if entity then
      ent.handle = entity
      ent.hash = tostring(entity:GetEntityID().hash)
      if app and "default" ~= app then -- no need to set if it's default, the game files have that covered
        ent.appearance = app
      end
      ent.spawned = true

      if ent.uniqueName then
        Props.spawnedProps[ent.uniqueName()] = ent
        
        for i, prop in ipairs(Props.spawnedPropsList) do
          if ent.name == prop.name then
            Props.spawnedPropsList[i] = ent
          end
        end
      end

      if ent.uid and Props.activeProps[ent.uid] then
        Props.activeProps[ent.uid] = ent
        Props.cachedActivePropsByHash[ent.hash] = ent
      end

      local components = Props:CheckForValidComponents(entity)
      if components then
        local visualScale = Props:CheckDefaultScale(components)
        ent.defaultScale = {
          x = visualScale.x * 100,
          y = visualScale.x * 100,
          z = visualScale.x * 100,
         }

         if ent.scale and ent.scale ~= nilString then
          if not ent.scaleHasChanged then
            AMM.Tools:SetScale(components, ent.defaultScale)
            ent.scale = Util:ShallowCopy({}, ent.defaultScale)
          else
            AMM.Tools:SetScale(components, ent.scale)
          end
        else
          ent.scale = {
            x = visualScale.x * 100,
            y = visualScale.y * 100,
            z = visualScale.z * 100,
           }
        end
      end

      if lockedTarget then
        AMM.Tools.lockTarget = true
        AMM.Tools:SetCurrentTarget(ent)
      end
      
      Cron.Halt(timer)
    end
  end

  Cron.Every(0.1, {tick = 1}, timerFunc)
end

function Props:DuplicateProp(spawn)
  local pos = spawn.handle:GetWorldPosition()
  local angles = GetSingleton('Quaternion'):ToEulerAngles(spawn.handle:GetWorldOrientation())
  local newSpawn = AMM.Spawn:NewSpawn(spawn.name, spawn.id, spawn.parameters, spawn.companion, spawn.path, spawn.template, spawn.rig)
  newSpawn.handle = spawn.handle
  newSpawn.scale = Util:ShallowCopy({}, spawn.scale)
  newSpawn.parameters = {app = spawn.appearance}
  Props:SpawnProp(newSpawn, pos, angles)
end

function Props:SpawnProp(spawn, pos, angles)
  local app = ''
  local record = ''
	local offSetSpawn = 0
	local distanceFromPlayer = 1
  local rotation = 180
	local playerAngles = GetSingleton('Quaternion'):ToEulerAngles(AMM.player:GetWorldOrientation())
	local distanceFromGround = tonumber(spawn.parameters) or 0

  if spawn.parameters and type(spawn.parameters) == 'string' and string.find(spawn.parameters, '{') then
    spawn.parameters = loadstring('return '..spawn.parameters, '')()
  end

	if spawn.parameters and type(spawn.parameters) == typeTable then
    if spawn.parameters.dist then
		  distanceFromPlayer = tonumber(spawn.parameters.dist)
    end

    if spawn.parameters.rot then
      rotation = tonumber(spawn.parameters.rot)
    end

    if spawn.parameters.up then
      distanceFromGround = tonumber(spawn.parameters.up)
    end

    if spawn.parameters.veh then
      local entName = spawn.path:match("Props.(.*)")
      record = 'Vehicle.'..entName
      spawn.isVehicle = true
    end

    if spawn.parameters.rec then
      record = spawn.parameters.rec
    end

    if spawn.parameters.app then
      app = spawn.parameters.app
    end
	end

  if AMM.Light:IsAMMLight(spawn) and AMM.userSettings.contactShadows and not string.find(spawn.template, "_shadows.ent") then
    spawn.template = spawn.template:gsub("%.ent", "_shadows.ent")
  end

  local lightData = nil
  if spawn.handle and spawn.handle ~= '' then
    lightData = AMM.Light:GetLightData(spawn)
  end

  if AMM.Tools.savedPosition ~= '' then
    pos = AMM.Tools.savedPosition.pos
    angles = AMM.Tools.savedPosition.angles
  end

	local heading = AMM.player:GetWorldForward()
	local offsetDir = Vector3.new(heading.x * distanceFromPlayer, heading.y * distanceFromPlayer, heading.z)
	local spawnTransform = AMM.player:GetWorldTransform()
	local spawnPosition = GetSingleton('WorldPosition'):ToVector4(spawnTransform.Position)
	local newPosition = Vector4.new((spawnPosition.x - offSetSpawn) + offsetDir.x, (spawnPosition.y - offSetSpawn) + offsetDir.y, spawnPosition.z + distanceFromGround, spawnPosition.w)
	spawnTransform:SetPosition(spawnTransform, pos or newPosition)
	spawnTransform:SetOrientationEuler(spawnTransform, angles or EulerAngles.new(0, 0, playerAngles.yaw - rotation))
	  
  spawn.entityID = exEntitySpawner.Spawn(spawn.template, spawnTransform, app, record)

  local timerFunc = function(timer)
		local entity = Game.FindEntityByID(spawn.entityID)
    timer.tick = timer.tick + 1
		if entity then
			spawn.handle = entity
      spawn.hash = tostring(entity:GetEntityID().hash)
      local appearance = AMM:GetAppearance(spawn)
      if appearance and "default" ~= appearance then  -- no need to set if it's default, the game files have that covered
        spawn.appearance = appearance
      end
      spawn.spawned = true

      if AMM.playerInPhoto then
        local light = AMM.Light:NewLight(spawn)
        if light then light.component:SetIntensity(50.0) end
      end

      local workspotMarker = Util:IsCustomWorkspot(entity)
      if workspotMarker then
        workspotMarker:Toggle(true)
      end

      if lightData then
        Light:SetLightData(spawn, lightData)
      end
      
      local components = Props:CheckForValidComponents(entity)
      if components then
        local visualScale = Props:CheckDefaultScale(components)
        spawn.defaultScale = {
          x = visualScale.x * 100,
          y = visualScale.x * 100,
          z = visualScale.x * 100,
         }

        if spawn.scale and spawn.scale ~= nilString then
          AMM.Tools:SetScale(components, spawn.scale)
        else
          spawn.scale = {
            x = visualScale.x * 100,
            y = visualScale.y * 100,
            z = visualScale.z * 100,
           }
        end
      end

			if AMM:GetScanClass(spawn.handle) == typeEntEntity or AMM:GetScanClass(spawn.handle) == typeEntGameEntity then -- entEntity, entGameEntity
				spawn.type = typeEntEntity
      else
        spawn.type = typeProp
      end

      spawn.parameters = {newPosition, GetSingleton('Quaternion'):ToEulerAngles(AMM.player:GetWorldOrientation())}

      if AMM.userSettings.autoLock then
        AMM.Tools.lockTarget = true
        AMM.Tools:SetCurrentTarget(spawn)

        if AMM.userSettings.floatingTargetTools and AMM.userSettings.autoOpenTargetTools then
          AMM.Tools.movementWindow.isEditing = true
				end
      end

			Cron.Halt(timer)
		elseif timer.tick > 20 then
			spawn.parameters = {newPosition, GetSingleton('Quaternion'):ToEulerAngles(AMM.player:GetWorldOrientation())}
			Cron.Halt(timer)
		end
	end
	Cron.Every(0.1, {tick = 1}, timerFunc)

	while Props.spawnedProps[spawn.uniqueName()] ~= nil do
    local num = spawn.name:match("|([^|]+)")
    if num then num = tonumber(num) + 1 else num = 1 end
    spawn.name = spawn.name:gsub(" | "..tostring(num - 1), "")
    spawn.name = spawn.name.." | "..tostring(num)
	end

	Props.spawnedProps[spawn.uniqueName()] = spawn
  table.insert(Props.spawnedPropsList, spawn)
end

function Props:DespawnProp(ent)
  if ent.uid then
    exEntitySpawner.Despawn(Props.activeProps[ent.uid].handle)
    Props.activeProps[ent.uid].handle:Dispose()
    Props.activeProps[ent.uid] = nil
  else
    ent.spawned = false 
    Props.spawnedProps[ent.uniqueName()] = nil
    
    for i, prop in ipairs(Props.spawnedPropsList) do
      if ent.name == prop.name then
        table.remove(Props.spawnedPropsList, i)
      end
    end
  end
  
end

function Props:despawnEntity(ent)
  if not ent or not ent.handle then return end
    
  if ent.handle.Dispose then 
    ent.handle:Dispose()
    return
  end

  if not ent.handle.GetEntityID then return end

  local entity = Game.FindEntityByID(ent.handle:GetEntityID())

  if not entity or not entity.GetEntity then return end
  
  local entEntity = entity:GetEntity()
  if entEntity and entEntity.Destroy then
    entEntity:Destroy()
  end
end

function Props:DespawnAllSavedProps()
  despawnInProgress = true
  local ent = nil
  
  for _, ent in pairs(Props.activeProps) do
    if ent and ent.handle ~= '' then 
      if type(ent.handle) == typeEntEntity then
        exEntitySpawner.Despawn(ent.handle)
       else
         Props:despawnEntity(ent)
      end
    end
  end

  Props.activeProps = {}
  Props.activeLights = {}
  despawnInProgress = false
end

function Props:DeleteAll()
  db:execute("DELETE FROM saved_props")
  db:execute("DELETE FROM saved_lights")
  db:execute("UPDATE sqlite_sequence SET seq = 0 WHERE name = 'saved_props'")
  db:execute("UPDATE sqlite_sequence SET seq = 0 WHERE name = 'saved_lights'")
end

function Props:ActivatePreset(preset)
  if Props.activePreset == '' then
    Props.activePreset = preset
  end

  local savedProps =  Util:ShallowCopy({}, preset.props)
  local savedLights =  Util:ShallowCopy({}, preset.lights)
  pcall(function() spdlog.info('Before saving '..Props.activePreset.file_name or "no file name") end)

  -- Probably don't need to save here
  -- The preset is already saved if the user made any changes
  -- Props:SavePreset(Props.activePreset)
  Props:DespawnAllSavedProps()
  Props:DeleteAll()
  
  local timerFunc = function(timer)

    if not despawnInProgress then
      local props = {}
      local lights = {}
      for i, prop in ipairs(savedProps) do
        local scale = prop.scale
        if scale == -1 then scale = { x = 1, y = 1, z = 1 } end
        if type(scale) == "table" then scale = Props:GetScaleString(scale) end
        prop.uid = prop.uid or i
        table.insert(props, f('(%i, "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s")', prop.uid, prop.entity_id, prop.name, prop.template_path, prop.pos, prop.trigger, scale, prop.app, prop.tag))
      end

      for _, light in ipairs(savedLights) do
        table.insert(lights, f('(%i, "%s", "%s", %f, %f, "%s")', light.uid, light.entity_id, light.color, light.intensity, light.radius, light.angles))
      end

      db:execute(f('INSERT INTO saved_props (uid, entity_id, name, template_path, pos, trigger, scale, app, tag) VALUES %s', table.concat(props, ", ")))
      db:execute(f('INSERT INTO saved_lights (uid, entity_id, color, intensity, radius, angles) VALUES %s', table.concat(lights, ", ")))

      Props.activePreset = preset

      pcall(function() spdlog.info('After setting variable '..Props.activePreset.file_name or "no file name") end)

      Props:Update()
      Props:SensePropsTriggers()
      Cron.Halt(timer)

      pcall(function() spdlog.info('After update '..Props.activePreset.file_name or "no file name") end)
    end
  end

  Cron.Every(0.1, timerFunc)
end

function Props:BackupPreset(preset)
  if not preset.name then return end -- do not back up a preset with no name
  pcall(function() spdlog.info(f("Backing up preset %s", preset.name)) end)
  
  -- only get backups for the current preset
  local matchingFiles = {}
  for _, file in pairs(dir("./User/Decor/Backup")) do
    if string.find(file.name or 'FILENAME', preset.name) then
      table.insert(matchingFiles, file.name)
    end
  end
   
  -- sort them by timestamp (first day, then time)
  local sortFunction = function(a, b)
    local aDay, aTime = string.match(a, "([^%-]+)%-(.+)")
    local bDay, bTime = string.match(b, "([^%-]+)%-(.+)")
    return aDay == bDay and aTime < bTime or aDay < bDay
  end
  table.sort(matchingFiles, sortFunction)
  
  -- if there are more files than NUM_TOTAL_BACKUPS, delete the first one
  if #matchingFiles > NUM_TOTAL_BACKUPS then
    os.remove("./User/Decor/Backup/"..tostring(matchingFiles[1])) -- nil-proof it
  end

  local props = {}
  for prop in db:nrows('SELECT * FROM saved_props') do
    table.insert(props, prop)
  end

  local lights = {}
  for light in db:nrows('SELECT * FROM saved_lights') do
    table.insert(lights, light)
  end

  if #props > 0 then
    local presetName = preset.name or 'Preset'
    local backupName = presetName.."-backup-"..os.date('%Y%m%d-%H%M%S')
    local newPreset = Props:NewPreset(backupName)
    newPreset.props = props
    newPreset.lights = lights
    Props:SavePreset(newPreset, "./User/Decor/Backup/%s")
  end
end

function Props:SharePresetWithTag(tag)
  local props = {}
  local lights = {}
  for prop in db:nrows(f('SELECT * FROM saved_props WHERE tag = "%s"', tag)) do
    table.insert(props, prop)

    for light in db:nrows(f('SELECT * FROM saved_lights WHERE uid = %i', prop.uid)) do
      table.insert(lights, light)
    end
  end

  local newPreset = Props:NewPreset(tag)
  newPreset.props = props
  newPreset.lights = lights
  Props:SavePreset(newPreset)
end

function Props:LoadPreset(fileName)
  if fileName ~= '' then
    local name, props, lights = Props:LoadPresetData(fileName)
    if name then
      if string.find(name, 'backup') then
        name = name:match("[^-backup-]+")
      end
      Props.activePreset = {file_name = fileName, name = name, props = props, lights = lights}
      Props:ActivatePreset(Props.activePreset)
    else
      Props.activePreset = ''
    end
  end
end

function Props:LoadPresetData(preset)
  local file = io.open('./User/Decor/'..preset, 'r')
  if file then
    local contents = file:read( "*a" )
		local presetData = json.decode(contents)
    file:close()
    return presetData['name'], presetData['props'], presetData['lights'] or {}
  end

  return false
end

function Props:LoadPresets()
  local files = dir("./User/Decor")
  local presets = {}
  if #Props.presets ~= #files - 2 then
    for _, preset in ipairs(files) do
      if string.find(preset.name, '.json') then
        local name, props, lights = Props:LoadPresetData(preset.name)
        table.insert(presets, {file_name = preset.name, name = name, props = props, lights = lights})
      end
    end
    return presets
  else
    return Props.presets
  end
end

function Props:DeletePreset(preset)
  -- make sure we have the file extension only one
  local presetName = (preset.file_name or preset.name or ''):gsub(".json", "")
  
  os.remove(f("./User/Decor/%s.json",presetName))
  Props.activePreset = ''
  Props.presets = Props:LoadPresets()

  if #Props.presets ~= 0 then
    Props.selectedPreset = Props.presets[1]
    Props:ActivatePreset(Props.selectedPreset)
  else
    Props.selectedPreset = {name = "No Preset Available"}
    Props:DespawnAllSavedProps()
    Props:DeleteAll()
    Props:Update()
  end
end

-- suppress that first error message, as the preset will be invalid at that point
local isInitialSave = true

function Props:SavePreset(preset, path, fromDB)
  
  -- suppress error message when trying to serialize a preset that wasn't yet loaded
  if isInitialSave then 
    isInitialSave = false
    return
  end
  
  spdlog.info(f('Saving preset %s', preset.name))

  if fromDB then
    local props = {}
    for prop in db:nrows('SELECT * FROM saved_props') do
      table.insert(props, prop)
    end

    local lights = {}
    for light in db:nrows('SELECT * FROM saved_lights') do
      table.insert(lights, light)
    end

    local presetFromDB = Props:NewPreset(preset.name or 'Preset'):gsub(".json", "") -- make sure we have json only once
    presetFromDB.props = props
    presetFromDB.lights = lights
    presetFromDB.file_name = preset.name..".json"
    presetFromDB.name = preset.name or presetFromDB.name

    preset = presetFromDB
  end

  local contents = json.encode(preset)
  local bouncedPreset = json.decode(contents)

  local invalidOriginalPreset = #preset.props == 0 and #preset.lights == 0
  local invalidBouncedPreset = #bouncedPreset.props == 0 and #bouncedPreset.lights == 0


  
  if invalidOriginalPreset or invalidBouncedPreset then
    local reason = (invalidBouncedPreset and not invalidOriginalPreset) and "preset serialization to JSON failed" or "preset props and lights are both empty"

    local errorTitle = "Preset Saving Failed"
    local errorMessage = f('Cannot save preset because %s and saving it would result in an invalid JSON file. Preset: %s %s', reason, preset.name or "<no preset name set>", preset.file_name or "<no preset file name set>")

    spdlog.error(errorMessage)

    return false
  end

  local filename = f("%s.json", (preset.file_name or preset.name):gsub(".json", "")) -- make sure we have the extension only once
  local filepath = path or "./User/Decor/%s"
  
  local file = io.open(f(filepath, filename), "w")

  if file then
        file:write(contents)
        file:close()
    return true
  end
end

function Props:GetPropsCount(tag)
  local query = 'SELECT COUNT(1) FROM saved_props'
  if tag then query = f('SELECT COUNT(1) FROM saved_props WHERE tag = "%s"', tag) end
  local count = 0
  for x in db:urows(query) do
    count = x
  end
  return count
end

function Props:GetPropsForPreset()
  local dbQuery = 'SELECT * FROM saved_props ORDER BY name ASC'
  if query then dbQuery = 'SELECT * FROM saved_props WHERE name LIKE "%'..query..'%" OR tag LIKE "%'..query..'%" ORDER BY name ASC' end
  local props = {}
  local lights = {}
  for prop in db:nrows(dbQuery) do
    table.insert(props, prop)

    for light in db:nrows(f('SELECT * FROM saved_lights WHERE uid = %i', prop.uid)) do
      table.insert(lights, light)
    end
  end

  return props, lights
end

function Props:GetProps(query, tag)
  local dbQuery = 'SELECT * FROM saved_props ORDER BY name ASC'
  if tag then dbQuery = 'SELECT * FROM saved_props WHERE tag = "'..tag..'" ORDER BY name ASC' end
  if query then dbQuery = 'SELECT * FROM saved_props WHERE '..query[1]..' OR tag LIKE "%'..query[2]..'%" ORDER BY name ASC' end
  local props = {}
  for prop in db:nrows(dbQuery) do
    for path in db:urows(f("SELECT entity_path FROM entities WHERE entity_id = '%s'", prop.entity_id)) do
      local uid = path:match("(.+)_Props.(.+)")
      if uid then
        uid = uid:gsub("Custom_", "")
        if Props.activePreset ~= '' and uid ~= "AMM" and next(AMM.modders) ~= nil then
          Props.activePreset.customIncluded = true
          Props.moddersList[" - "..AMM.modders[uid]] = ''
        end
      end
    end

    table.insert(props, Props:NewProp(prop.uid, prop.entity_id, prop.name, prop.template_path, prop.pos, prop.scale, prop.app, prop.tag))
  end

  return props
end

function Props:GetTriggers()
  local triggers = {}
  for trigger in db:urows("SELECT DISTINCT trigger FROM saved_props") do
    table.insert(triggers, Props:NewTrigger(trigger))
  end

  return triggers
end

function Props:GetTags()
  local tags = {}
  for tag in db:urows("SELECT DISTINCT tag FROM saved_props") do
    tag = tag or 'default'
    table.insert(tags, tag)
    Props.totalPerTag[tag] = Props:GetPropsCount(tag)
  end

  return tags
end

function Props:GetCategories()
  local query = "SELECT * FROM categories WHERE cat_sub IS NOT NULL ORDER BY 3 ASC"

  local categories = {}
  local categoriesNames = {}

  -- Insert Favorites first
  table.insert(categories, {cat_id = 1, cat_name = "Favorites", cat_icon = "Star"})
  categoriesNames[1] = "Favorites"

  for category in db:nrows(query) do
    if category.cat_id == 58 and not AMM.archivesInfo.sounds then
      -- User doesn't have the Sound Effects archive installed
    else
      categoriesNames[category.cat_id] = category.cat_name
      table.insert(categories, {cat_id = category.cat_id, cat_name = category.cat_name, cat_icon = category.cat_icon})
    end
  end

  -- Insert Vehicles category
  table.insert(categories, {cat_id = 24, cat_name = "Vehicles", cat_icon = "CarConvertible"})
  categoriesNames[24] = "Vehicles"

  return categories, categoriesNames
end

function Props:GetPropCategory(id)
  local query = f("SELECT cat_id FROM entities WHERE entity_id = '%s'", id)

  for cat_id in db:urows(query) do
    return cat_id
  end

  return 48
end

function Props:GetAllLights(filteredLights)

  local savedLights = {}
  local validUIDs = {}
  for uid in db:urows("SELECT uid FROM saved_lights") do
    table.insert(savedLights, uid)
    validUIDs[uid] = true
  end

  if filteredLights and #filteredLights ~= 0 then
    local t = {}
    for _, v in ipairs(filteredLights) do
      if validUIDs[v.uid] then
        t[#t + 1] = tostring(v.uid)
      end
    end
    savedLights = t
  end

  local lightsUID = table.concat(savedLights, ", ")
  savedLights = "("..lightsUID..")"

  local lights = {}
  for prop in db:nrows("SELECT * FROM saved_props WHERE uid IN "..savedLights.." ORDER BY name ASC") do
    table.insert(lights, Props:NewProp(prop.uid, prop.entity_id, prop.name, prop.template_path, prop.pos, prop.scale, prop.app, prop.tag))
  end

  return lights
end

function Props:GetAllActiveLights()
  if #Props.activeLights == 0 then
    local lights = {}
    for _, prop in pairs(Props.activeProps) do
      local light = AMM.Light:GetLightData(prop)

      if light then
        table.insert(lights, prop)
      end
    end

    if #lights > 0 then Props.activeLights = lights else return nil end
  end

  return Props.activeLights
end

function Props:GetParameters(templatePath)
  local parameters = nil

  for r in db:urows(f("SELECT parameters FROM entities WHERE template_path = '%s'", templatePath)) do
    parameters = r
  end

  return parameters
end

function Props:GetEntityPath(templatePath)
  local entityPath = nil

  for path in db:urows(f("SELECT entity_path FROM entities WHERE template_path = '%s'", templatePath)) do
    entityPath = path
  end

  return entityPath
end

function Props:GetScaleString(scale)
  if type(scale) == "table" then
    return f("{x = %f, y = %f, z = %f}", scale.x, scale.y, scale.z)
  end
end

function Props:CheckIfVehicle(id)
  local count = 0
  local query = f("SELECT COUNT(1) FROM entities WHERE entity_id = '%s'", id)
  for check in db:urows(query) do
    count = check
  end

  if count ~= 0 then return true else return false end
end

return Props:new()
