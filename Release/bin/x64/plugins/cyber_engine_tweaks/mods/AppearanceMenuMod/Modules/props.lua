Props = {}

function Props:NewProp(uid, id, name, template, posString, scale, app, tag)
  local obj = {}
	obj.handle = ''
  obj.hash = ''
  obj.uid = uid
	obj.id = id
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
  obj.isVehicle = false

  return obj
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

  obj.name = name or 'My Preset'
  obj.props = {}
  obj.lights = {}
  obj.customIncluded = false

  while io.open(f("User/Decor/%s.json", obj.name), "r") do
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
  Props.triggers = {}
  Props.tags = {}
  Props.homes = {}
  Props.homeTags = nil
  Props.categories = {}
  Props.savingProp = ''
  Props.editingTags = {}
  Props.activeProps = {}
  Props.activeLights = {}
  Props.cachedActivePropsByHash = {}
  Props.activePreset = ''
  Props.selectedPreset = {name = "No Preset Available"}
  Props.removingFromTag = ''
  Props.savingPreset = ''
  Props.searchQuery = ''
  Props.savedPropsSearchQuery = ''
  Props.searchBarWidth = 500
  Props.moddersList = {}
  Props.showTargetOnly = false
  Props.showNearbyOnly = false
  Props.showCustomizableOnly = false
  Props.showCustomPropsOnly = false
  Props.buildMode = false
  Props.modesStatesBeforeBuild = {}
  Props.sizeX = 0

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
  Props.categories = Props:GetCategories()

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
    Props.triggers = Props:GetTriggers()
    Props.tags = Props:GetTags()
    Util.playerLastPos = ''
    spdlog.info('during update')
    Props:SavePreset(Props.activePreset)
  else
    Props.savedProps = {}
    Props.savedProps['all_props'] = {}
    Props.tags = {}
  end
end

function Props:Draw(AMM)
  if ImGui.BeginTabItem("Decor") then

    Props.style = {
      buttonHeight = ImGui.GetFontSize() * 2,
      buttonWidth = -1,
      halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
    }

    AMM.UI:TextColored("Decorating")
    ImGui.TextWrapped("Spawn Props to decorate your house or anywhere you want to your heart's content! Save Props to make them persist!")

    AMM.UI:Spacing(2)

    if Props.sizeX == 0 then
      Props.sizeX = ImGui.GetWindowContentRegionWidth()
    end

    local offSet = Props.sizeX - ImGui.CalcTextSize("Build Mode")
    ImGui.Dummy(offSet - 70, 10)
    ImGui.SameLine()
    AMM.UI:TextColored("Build Mode")
    ImGui.SameLine()
    Props.buildMode, modeChange = ImGui.Checkbox(" ", Props.buildMode)

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("This allows better integration with Direct mode when using gamepad. It also enables a small information window that sticks around.")
    end

    if modeChange then
      AMM.Props:ToggleBuildMode(true)
    end

    AMM.UI:Separator()

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

function Props:DrawSpawnedProps()
  if #Props.spawnedPropsList > 0 then
    AMM.UI:TextColored("Spawned Props")

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

      local favoritesLabels = {"Favorite", "Unfavorite"}
      AMM.Spawn:DrawFavoritesButton(favoritesLabels, spawn)

      ImGui.SameLine()

      if Props.savingProp == spawn.name then
        AMM.UI:TextColored("Moving "..nameLabel.." to Saved Props")

        Cron.After(2.0, function()
          Props.savingProp = ''
        end)
      else

        if ImGui.SmallButton("Save Prop##"..spawn.name) then
          -- Cron.Halt()
          if spawn.handle ~= '' then
            Props:SavePropPosition(spawn)
            Props.savingProp = spawn.name
          end
        end

        ImGui.SameLine()
        if ImGui.SmallButton("Despawn##"..spawn.name) then
          if spawn.handle ~= '' then
            spawn:Despawn()
          end
        end

        if spawn.handle ~= '' then

          if AMM.playerInPhoto then
            local buttonLabel = "Hide"
            local entID = tostring(spawn.handle:GetEntityID().hash)
            if Props.hiddenProps[entID] ~= nil then
              buttonLabel = "Unhide"
            end

            ImGui.SameLine()
            if ImGui.SmallButton(buttonLabel.."##"..spawn.name) then
              Props:ToggleHideProp(spawn)
            end
          end

          ImGui.SameLine()
          if ImGui.SmallButton("Target".."##"..spawn.name) then
            AMM.Tools.lockTarget = true
            AMM.Tools:SetCurrentTarget(spawn)
          end

          ImGui.SameLine()
          if ImGui.SmallButton("Duplicate".."##"..spawn.name) then
            Props:DuplicateProp(spawn)
          end
        end
      end
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
              query = f("SELECT * FROM entities WHERE entity_id = '%s' AND cat_id IN %s", fav.entity_id, validCatIDs)
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
          if ImGui.CollapsingHeader(category.cat_name) then
            AMM.Spawn:DrawEntitiesButtons(Props.entities[category], category.cat_name, Props.style)
          end
        end
      end
    end
    ImGui.EndChild()
  end
end

function Props:DrawProps(props)
  for i, prop in ipairs(props) do
    if Props.showTargetOnly then
      if Tools.currentTarget.handle and Tools.currentTarget.handle ~= '' and Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' 
      and Props.activeProps[prop.uid].handle:GetEntityID().hash == Tools.currentTarget.handle:GetEntityID().hash then
        Props:DrawSavedProp(prop, i)
      end
    elseif Props.showNearbyOnly then
      local playerPos = AMM.player:GetWorldPosition()
      if Props.activeProps[prop.uid] and Props.activeProps[prop.uid].handle and Props.activeProps[prop.uid].handle ~= '' then
        local propPos = Props.activeProps[prop.uid].handle:GetWorldPosition()
        local distanceFromPlayer = Util:VectorDistance(playerPos, propPos)
        if Props.activeProps[prop.uid].handle ~= '' and distanceFromPlayer < 3 then
          Props:DrawSavedProp(prop, i)
        end
      end
    else
      Props:DrawSavedProp(prop, i)
    end
  end
end

function Props:DrawSavedProp(prop, i)
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

  if ImGui.SmallButton("Remove##"..i) then
    Props:RemoveProp(prop)
  end

  ImGui.SameLine()
  if ImGui.SmallButton("Rename##"..i) then
    Props.rename = ''
	  ImGui.OpenPopup("Rename Prop##"..prop.name)
  end

  Props:RenamePropPopup(prop)

  if Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' then
    ImGui.SameLine()
    if ImGui.SmallButton("Update Prop##"..i) then
      Props:SavePropPosition(Props.activeProps[prop.uid])
    end

    ImGui.SameLine()
    local buttonLabel = "Hide Prop"
    local entID = tostring(Props.activeProps[prop.uid].handle:GetEntityID().hash)
    if Props.hiddenProps[entID] ~= nil then
      buttonLabel = "Unhide Prop"
    end
    if ImGui.SmallButton(buttonLabel.."##"..i) then
      Props:ToggleHideProp(Props.activeProps[prop.uid])
    end

    ImGui.SameLine()
    if ImGui.SmallButton("Target".."##"..i) then
      AMM.Tools:SetCurrentTarget(Props.activeProps[prop.uid])
      AMM.Tools.lockTarget = true
    end

    local buttonLabel = " Show On Map "
    if Props.activeProps[prop.uid].mappinData ~= nil then
      buttonLabel = "Hide From Map"
    end

    ImGui.SameLine()
    if ImGui.SmallButton(buttonLabel.."##"..i) then
      if Props.activeProps[prop.uid].mappinData ~= nil then
        Props:RemoveFromMap(Props.activeProps[prop.uid].mappinData)
        Props.activeProps[prop.uid].mappinData = nil
      else
        Props.activeProps[prop.uid].mappinData = Props:ShowOnMap(prop.pos)
      end
    end

    if Props.editingTags[i] == nil then
      Props.editingTags[i] = prop.tag
    end

    Props.editingTags[i] = ImGui.InputText(" ##"..i, Props.editingTags[i], 100)

    ImGui.SameLine(394)
    if ImGui.SmallButton(" Update Tag ##"..i) and Props.editingTags[i] ~= '' then
      Props:UpdatePropTag(prop, Props.editingTags[i])

      Props:Update()
      Props.editingTags[i] = nil
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

  if ImGui.BeginCombo("Presets", Props.selectedPreset.name, ImGuiComboFlags.HeightLarge) then
    for i, preset in ipairs(Props:LoadPresets()) do
      if ImGui.Selectable(preset.name.."##"..i, (preset.name == Props.selectedPreset.name)) then
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
    ImGui.SmallButton(" ? ")

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

function Props:DrawHeaders()
  if #Props.savedProps['all_props'] > 0 then

    local props = {}

    ImGui.PushItemWidth(Props.searchBarWidth)
    Props.savedPropsSearchQuery = ImGui.InputTextWithHint(" ", "Search", Props.savedPropsSearchQuery, 100)
    Props.savedPropsSearchQuery = Props.savedPropsSearchQuery:gsub('"', '')
    ImGui.PopItemWidth()

    if Props.savedPropsSearchQuery ~= '' then
      props = Props:GetProps(Props.savedPropsSearchQuery)

      ImGui.SameLine()
      if ImGui.Button("Clear") then
        Props.savedPropsSearchQuery = ''
      end
    end

    ImGui.Spacing()

    Props.showNearbyOnly = ImGui.Checkbox("Show Nearby Only", Props.showNearbyOnly)
    ImGui.Spacing()

    if Tools.lockTarget then
      Props.showTargetOnly = ImGui.Checkbox("Show Locked Target Only", Props.showTargetOnly)
      ImGui.Spacing()
    end

    AMM.UI:TextColored("Saved Props:")

    ImGui.Spacing()

    if #props ~= 0 then
      Props:DrawProps(props)
    else
      for _, tag in ipairs(Props.tags) do
        if ImGui.CollapsingHeader(tag) then

          if Props.savedProps[tag] == nil then
            Props.savedProps[tag] = Props:GetProps(nil, tag)
          end

          Props:DrawTagActions(Props.savedProps[tag], tag)
          Props:DrawProps(Props.savedProps[tag])
        end
      end

      AMM.UI:Spacing(3)

      local count = 0
      for x in db:urows('SELECT COUNT(1) FROM saved_props') do
        count = x
      end
      ImGui.Text("Total Props: "..count)
    end
  end
end

function Props:DrawTagActions(props, tag)

  AMM.UI:Spacing(8)

  if Props.editingTags[tag] == nil then
    Props.editingTags[tag] = tag
  end

  Props.editingTags[tag] = ImGui.InputText("Tag##"..tag, Props.editingTags[tag], 100)

  if ImGui.SmallButton(" Update Tag ##"..tag) and Props.editingTags[tag] ~= '' then
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
    if ImGui.SmallButton(" Cancel ##"..tag) then
      Props.removingFromTag = "cancel"
    end
  else
    if ImGui.SmallButton(" Remove All Props ##"..tag) then
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

  local buttonLabel = " Add Home Marker To Map "

  if Props.homes[tag] ~= nil then
    buttonLabel = " Remove Home Marker From Map "
  end

  if ImGui.SmallButton(buttonLabel.."##"..tag) then
    if buttonLabel == " Add Home Marker To Map " then
      Props.homes[tag] = Props:AddHomeMarker(tag)  
    else
      Props:RemoveFromMap(Props.homes[tag])
      Props.homes[tag] = nil
    end
  end

  AMM.UI:Spacing(8)

  if ImGui.Button("Teleport To Location", -1, 40) then
    Props:TeleportToTag(tag)
  end

  if Props.savingPreset == '' then
    if ImGui.Button("Share Preset With This Tag Only", -1, 40) then
      Props:SharePresetWithTag(tag)
      Props.savingPreset = tag
    end
  elseif Props.savingPreset == tag then
    AMM.UI:TextCenter("Saved Preset to AppearanceMenuMod/User/Decor folder")

    Cron.After(3.0, function()
      Props.savingPreset = ''
    end)
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

      Props.rename = ImGui.InputText("Name", Props.rename, 30)

      AMM.UI:Spacing(8)

      if ImGui.Button("Save", style.buttonWidth, style.buttonHeight) then
        if not(io.open(f("User/Decor/%s.json", Props.rename), "r")) then
          local fileName = Props.activePreset.file_name or Props.activePreset.name..".json"
          os.remove("User/Decor/"..fileName)
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

  if ImGui.BeginPopupModal("Rename Prop##"..prop.name) then
    
    if Props.rename == '' then
      Props.rename = prop.name
    end

    Props.rename = ImGui.InputText("Name", Props.rename, 50)

    AMM.UI:Spacing(8)

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
  for _, trigger in ipairs(Props.triggers) do
    local dist = Util:VectorDistance(Game.GetPlayer():GetWorldPosition(), trigger.pos)

    if dist <= 60 then
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
end

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

  ent.entityID = exEntitySpawner.Spawn(ent.template, spawnTransform, ent.appearance, record)

  Cron.Every(0.1, {tick = 1}, function(timer)
    local entity = Game.FindEntityByID(ent.entityID)
    if entity then
      ent.handle = entity
      ent.hash = tostring(entity:GetEntityID().hash)
      ent.parameters = {pos, angles}
      ent.spawned = true

      Props.cachedActivePropsByHash[ent.hash] = ent

      if AMM:GetScanClass(ent.handle) == 'entEntity' then
				ent.type = 'entEntity'
      else
        ent.type = 'Prop'
      end

      if ent.uid then
        for light in db:nrows(f('SELECT * FROM saved_lights WHERE uid = %i', ent.uid)) do
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

        if ent.scale and ent.scale ~= "nil" then
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
  end)

  return ent
end

function Props:GetTagBasedOnLocation()
  if AMM.Tools then
    local playerPos = AMM.player:GetWorldPosition()
    for _, loc in ipairs(AMM.Tools:GetLocations()) do
      if loc.loc_name:match("%-%-%-%-") == nil then
        local pos = Vector4.new(loc.x, loc.y, loc.z, loc.w)
        local dist = Util:VectorDistance(playerPos, pos)

        if dist <= 60 then
          return loc.loc_name
        end
      end
    end

    return "Misc"
  end
end

function Props:LoadHomes(userHomes)
  for _, tag in ipairs(userHomes) do
    Props.homes[tag] = Props:AddHomeMarker(tag)
  end
end

function Props:TeleportToTag(tag)
  local loc = nil

  for trigger in db:urows(f('SELECT DISTINCT trigger FROM saved_props WHERE tag = "%s"', tag)) do
    local newTrigger = Props:NewTrigger(trigger)
    loc = AMM.Tools:NewLocationData(tag, {pos = newTrigger.pos, yaw = Game.GetPlayer():GetWorldYaw()})
  end

  AMM.Tools:TeleportToLocation(loc)
end

function Props:AddHomeMarker(tag)
  local pos = nil

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
  db:execute(f('UPDATE saved_props SET tag = "%s" WHERE uid = %i', newTag, prop.uid))
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
  local light = AMM.Light:GetLightData(ent)
  local hash = tostring(ent.handle:GetEntityID().hash)
  local components = Props:CheckForValidComponents(ent.handle)
  if Props.hiddenProps[hash] ~= nil then
    if light then
      AMM.Light:ToggleLight(light)
    elseif components then
      for _, comp in ipairs(components) do
        comp:Toggle(true)
      end
    else
      local prop = Props.hiddenProps[hash]
      local spawn = Props:SpawnPropInPosition(prop.ent, prop.pos, prop.angles)
      if ent.type ~= "Prop" or ent.type ~= "entEntity" then
        Props.spawnedProps[spawn.uniqueName()] = spawn
      end
    end

    Props.hiddenProps[hash] = nil
  else
    local pos = ent.handle:GetWorldPosition()
    local angles = GetSingleton('Quaternion'):ToEulerAngles(ent.handle:GetWorldOrientation())
    
    if light then
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

function Props:SavePropPosition(ent)
  local pos = ent.handle:GetWorldPosition()
  local angles = GetSingleton('Quaternion'):ToEulerAngles(ent.handle:GetWorldOrientation())
	if pos == nil then
		pos = ent.parameters[1]
    angles = ent.parameters[2]
	end

  local app = AMM:GetAppearance(ent)

  local tag = Props:GetTagBasedOnLocation()

  local trigger = Util:GetPosString(Props:CheckForTriggersNearby(pos))
  pos = Util:GetPosString(pos, angles)

  local scale = nil
  if ent.scale and ent.scale ~= "nil" then
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

  Cron.After(2.0, function()
    if not ent.uid then
      ent:Despawn()
    end

    local preset = Props.activePreset
    if preset == '' then
      preset = Props:NewPreset(tag)
      Props.activePreset = preset
    end

    Props:Update()
    Props:SensePropsTriggers()
    AMM:UpdateSettings()
  end)
end

function Props:ToggleBuildMode(systemActivated)
  if not systemActivated then
    Props.buildMode = not Props.buildMode
  end
end

function Props:CheckForTriggersNearby(pos)
  local closestTriggerPos = pos
  for _, trigger in ipairs(Props.triggers) do
    if Util:VectorDistance(pos, trigger.pos) < 60 then
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

function Props:CheckForValidComponents(handle)
  if handle then
    local components = {}

    for comp in db:urows("SELECT cname FROM components WHERE type = 'Props'") do
      local c = handle:FindComponentByName(CName.new(comp))
      if c and NameToString(c:GetClassName()) ~= 'entPhysicalSkinnedMeshComponent'
      and NameToString(c:GetClassName()) ~= 'entSkinnedMeshComponent' then
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

  Cron.Every(0.1, {tick = 1}, function(timer)
    local entity = Game.FindEntityByID(ent.entityID)

    if entity then
      ent.handle = entity
      ent.hash = tostring(entity:GetEntityID().hash)
      ent.appearance = app
      ent.spawned = true

      if ent.uniqueName then
        Props.spawnedProps[ent.uniqueName()] = ent
      end

      if ent.uid and Props.activeProps[ent.uid] then
        Props.activeProps[ent.uid] = ent
        Props.cachedActivePropsByHash[ent.hash] = ent
      end

      if lockedTarget then
        AMM.Tools.lockTarget = true
        AMM.Tools:SetCurrentTarget(ent)
      end
      
      Cron.Halt(timer)
    end
  end)
end

function Props:DuplicateProp(spawn)
  local pos = spawn.handle:GetWorldPosition()
  local angles = GetSingleton('Quaternion'):ToEulerAngles(spawn.handle:GetWorldOrientation())
  local newSpawn = AMM.Spawn:NewSpawn(spawn.name, spawn.id, spawn.parameters, spawn.companion, spawn.path, spawn.template, spawn.rig)
  newSpawn.handle = spawn.handle
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

	if spawn.parameters and type(spawn.parameters) == 'table' then
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

	Cron.Every(0.1, {tick = 1}, function(timer)
		local entity = Game.FindEntityByID(spawn.entityID)
    timer.tick = timer.tick + 1
		if entity then
			spawn.handle = entity
      spawn.hash = tostring(entity:GetEntityID().hash)
      spawn.appearance = AMM:GetAppearance(spawn)
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
        spawn.scale = {
          x = visualScale.x * 100,
          y = visualScale.y * 100,
          z = visualScale.z * 100,
        }
      end

			if AMM:GetScanClass(spawn.handle) == 'entEntity' or AMM:GetScanClass(spawn.handle) == 'entGameEntity' then
				spawn.type = 'entEntity'
      else
        spawn.type = 'Prop'
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
	end)

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

function Props:DespawnAllSavedProps()
  for _, ent in pairs(Props.activeProps) do
    if ent.handle then
      exEntitySpawner.Despawn(ent.handle)
    end
  end

  Props.activeProps = {}
  Props.activeLights = {}
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

  pcall(function() spdlog.info('Before saving '..Props.activePreset.file_name or "no file name") end)

  -- Probably don't need to save here
  -- The preset is already saved if the user made any changes
  -- Props:SavePreset(Props.activePreset)
  Props:DespawnAllSavedProps()
  Props:DeleteAll()

  local values = {}
  local lights = {}
  for i, prop in ipairs(preset.props) do
    local scale = prop.scale
    if scale == -1 then scale = nil end
    if type(scale) == "table" then scale = Props:GetScaleString(scale) end
    prop.uid = prop.uid or i
    table.insert(values, f('(%i, "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s")', prop.uid, prop.entity_id, prop.name, prop.template_path, prop.pos, prop.trigger, scale, prop.app, prop.tag))
  end

  for _, light in ipairs(preset.lights) do
    table.insert(lights, f('(%i, "%s", "%s", %f, %f, "%s")', light.uid, light.entity_id, light.color, light.intensity, light.radius, light.angles))
  end

  db:execute(f('INSERT INTO saved_props (uid, entity_id, name, template_path, pos, trigger, scale, app, tag) VALUES %s', table.concat(values, ", ")))
  db:execute(f('INSERT INTO saved_lights (uid, entity_id, color, intensity, radius, angles) VALUES %s', table.concat(lights, ", ")))

  Props.activePreset = preset

  pcall(function() spdlog.info('After setting variable '..Props.activePreset.file_name or "no file name") end)

  Props:Update()
  Props:SensePropsTriggers()

  pcall(function() spdlog.info('After update '..Props.activePreset.file_name or "no file name") end)
end

function Props:BackupPreset(preset)
  local files = dir("./User/Decor/Backup")
  if #files > 30 then
    os.remove("User/Decor/Backup/"..files[1].name)
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
    Props:SavePreset(newPreset, "User/Decor/Backup/%s")
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
    end
  end
end

function Props:LoadPresetData(preset)
  local file = io.open('User/Decor/'..preset, 'r')
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
  local presetName = preset.file_name or preset.name..".json"
  os.remove("User/Decor/"..presetName)
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

function Props:SavePreset(preset, path, fromDB)
  spdlog.info('Saving preset...')

  if fromDB then
    local props = {}
    for prop in db:nrows('SELECT * FROM saved_props') do
      table.insert(props, prop)
    end

    local lights = {}
    for light in db:nrows('SELECT * FROM saved_lights') do
      table.insert(lights, light)
    end

    local presetFromDB = Props:NewPreset(preset.name or 'Preset')
    presetFromDB.props = props
    presetFromDB.lights = lights
    presetFromDB.file_name = preset.name..".json"

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

  local file = io.open(f(path or "User/Decor/%s", preset.file_name or preset.name..".json"), "w")

  if file then
        file:write(contents)
        file:close()
    return true
  end
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
  if query then dbQuery = 'SELECT * FROM saved_props WHERE name LIKE "%'..query..'%" OR tag LIKE "%'..query..'%" ORDER BY name ASC' end
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
    table.insert(tags, tag)
  end

  return tags
end

function Props:GetCategories()
  local query = "SELECT * FROM categories WHERE cat_sub IS NOT NULL ORDER BY 3 ASC"

  local categories = {}

  -- Insert Favorites first
  table.insert(categories, {cat_id = 1, cat_name = "Favorites"})

  for category in db:nrows(query) do
    if category.cat_id == 58 and not AMM.archivesInfo.sounds then
      -- User doesn't have the Sound Effects archive installed
    else
      table.insert(categories, {cat_id = category.cat_id, cat_name = category.cat_name})
    end
  end

  -- Insert Vehicles category
  table.insert(categories, {cat_id = 24, cat_name = "Vehicles"})

  return categories
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

return Props:new()
