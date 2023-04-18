Poses = {}

function Poses:new()
  Poses.anims = {}
  Poses.categories = nil
  Poses.specialCategories = nil
  Poses.sceneAnimsInstalled = false
  Poses.searchQuery = ''
  Poses.lastSearchQuery = ''
  Poses.searchBarWidth = 500
  Poses.historyEnabled = false
  
  Poses.activeAnims = {}
  Poses.historyAnims = {}
  Poses.history = {}
  Poses.historyCategories = {}

  Poses.currentAnims = {}

  Poses.rigs = {
    ["man_base"] = "Man Average",
    ["man_big"] = "Big",
    ["man_child"] = "Child",
    ["man_fat"] = "Fat",
    ["man_massive"] = "Man Massive",
    ["woman_base"] = "Woman Average",
    ["player_man_skeleton"] =  "Player Man",
    ["player_woman_skeleton"] = "Player Woman"
  }

  return Poses
end

function Poses:Initialize()
  Poses.anims = Poses:GetAllAnimations()
  Poses.categories = Poses:GetCategories()
  Poses.specialCategories = Poses:GetSpecialCategories()
  Poses.collabAnims, Poses.collabCategories = Poses:GetCollabAnimations()

  if #Poses.history > 0 then
    Poses.historyAnims, Poses.historyCategories = Poses:GetAnimationsForListOfIDs(Poses.history)
  end
end

function Poses:Draw(AMM, target)
  if (ImGui.BeginTabItem("Poses")) then

    AMM.UI:DrawCrossHair()

    if AMM.Tools.lockTarget and AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '' then
      if AMM.Tools.currentTarget.handle.IsNPC and AMM.Tools.currentTarget.handle:IsNPC() then
        target = AMM.Tools.currentTarget
      end
    end

    if next(Poses.activeAnims) ~= nil then
      AMM.UI:TextColored("Active Animations")

      for hash, anim in pairs(Poses.activeAnims) do

        local nameLabel = anim.target.name
        if Tools.lockTarget and Tools.currentTarget ~= '' and Tools.currentTarget.handle then
          if nameLabel == Tools.currentTarget.name then
            AMM.UI:TextColored(nameLabel)
          else
            ImGui.Text(nameLabel)
          end
        else
          ImGui.Text(nameLabel)
        end
        
        local name = anim.name:gsub("_", " ")
        name = name:gsub("__", " ")
        ImGui.Text(name)

        local buttonLabel = IconGlyphs.Pause or "  Pause  "
        if Tools.currentTarget ~= '' and Tools.currentTarget.handle and 
        (Tools.frozenNPCs[tostring(Tools.currentTarget.handle:GetEntityID().hash)] or not Game.GetWorkspotSystem():IsActorInWorkspot(Tools.currentTarget.handle)) then
          buttonLabel = IconGlyphs.Play or "  Play  "
        end

        if AMM.UI:SmallButton(buttonLabel.."##"..hash) then
          local frozen = Tools.frozenNPCs[tostring(Tools.currentTarget.handle:GetEntityID().hash)] == true
          if not Game.GetWorkspotSystem():IsActorInWorkspot(Tools.currentTarget.handle) and not frozen then
            Poses:RestartAnimation(anim)
          else
            Tools:FreezeNPC(Tools.currentTarget.handle, not(frozen))
          end
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton((IconGlyphs.Stop or "  Stop  ").."##"..hash) then
          Poses:StopAnimation(anim, true)
        end

        local isFavorite = anim.fav
        local buttonLabel = 'Favorite'
        if isFavorite then
          buttonLabel = 'Unfavorite'
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton(f("%s##", buttonLabel)..hash) then
          Poses:ToggleFavorite(not isFavorite, anim)
        end

        if anim.target.handle ~= '' then
          ImGui.SameLine()
          if AMM.UI:SmallButton("Target".."##"..anim.target.name) then
            AMM.Tools:SetCurrentTarget(anim.target)
            AMM.Tools.lockTarget = true
          end
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton("  Copy To Clipboard  ##"..hash) then
          ImGui.SetClipboardText(name)
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton((IconGlyphs.CloseThick or "  Remove  ").."##"..hash) then
          Poses:StopAnimation(anim)
        end

        AMM.UI:Separator()
      end
    end

    if target == nil and AMM.userSettings.animPlayerSelfTarget then
      local entity = Game.GetPlayer()
      target = AMM:NewTarget(entity, "Player", AMM:GetScanID(entity), "V", nil, nil)
    end

    if target ~= nil and (target.type == 'Player' or (target.handle.IsNPC and target.handle:IsNPC()) or (target.handle.IsReplacer and target.handle:IsReplacer())) then
      AMM.UI:TextColored("Current Target:")
      ImGui.Text(target.name)

      AMM.UI:Separator()

      ImGui.PushItemWidth(Poses.searchBarWidth)
      Poses.searchQuery = ImGui.InputTextWithHint(" ", "Search", Poses.searchQuery, 100)
      Poses.searchQuery = Poses.searchQuery:gsub('"', '')
      ImGui.PopItemWidth()

      if Poses.searchQuery ~= '' then
        ImGui.SameLine()
        if ImGui.Button("Clear") then
          Poses.searchQuery = ''
        end
      end

      if next(Poses.historyAnims) ~= nil then
        Poses.historyEnabled = ImGui.Checkbox("Show History", Poses.historyEnabled)
      end

      ImGui.Spacing()

      AMM.UI:TextColored("Select Pose For Current Target:")
      
      local anims = Poses.currentAnims

      if Poses.searchQuery ~= '' and Poses.searchQuery ~= Poses.lastSearchQuery then
        local parsedSearch = Util:ParseSearch(Poses.searchQuery, "anim_name")
        Poses.currentAnims = Poses:GetAnimationsForSearch(parsedSearch)
        Poses.lastSearchQuery = Poses.searchQuery
      elseif Poses.searchQuery ~= Poses.lastSearchQuery then
        Poses.currentAnims = {}
      end

      if Poses.searchQuery ~= '' and next(anims) == nil then
        ImGui.Text("No Results")
      else
        local resX, resY = GetDisplayResolution()
        local y = resY / 3

        if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y) then
          local categories = Poses.categories
          local specials = Poses.specialCategories[target.name]
          local collabs = Poses.collabCategories

          local rig = Poses:CheckTargetRig(target)

          if rig then
            categories = Poses:GetCategoriesForRig(rig)
          end

          if specials and not Util:CheckIfTableHasValue(categories, target.name) then
            table.insert(categories, target.name)
          end

          if next(anims) == nil then
            anims = Util:ShallowCopy({}, Poses.anims)
          end

          if collabs then
            local newCategories = Util:ShallowCopy({}, categories)
            for _, cat in ipairs(collabs) do
              local addedAnim = false
              
              for _, r in pairs(Poses.rigs) do
                if r == Poses.rigs[rig] or rig == false then
                  local collabAnims = Poses.collabAnims[cat][r]
                  if collabAnims then
                    for _, workspot in ipairs(collabAnims) do
                      if anims[cat] == nil then
                        anims[cat] = {}
                      end

                      addedAnim = true
                      table.insert(anims[cat], workspot)
                    end
                  end
                end
              end

              if addedAnim then table.insert(newCategories, cat) end
            end

            categories = newCategories
          end

          for _, category in ipairs(categories) do
            local gender = Util:GetPlayerGender()

            if target.type == "Player" and AMM.userSettings.animPlayerSelfTarget then
              if gender == "_Female" then gender = "Player Woman" else gender = "Player Man" end
              if category == gender then gender = true else gender = false end
            end
            
            if not gender and category ~= 'Favorites' then goto skip end
            if (category == "Player Woman" or category == "Player Man")
            and AMM.userSettings.animPlayerSelfTarget and target.type ~= "Player" then goto skip end
            
            if anims[category] ~= nil and next(anims[category]) ~= nil or (category == 'Favorites' and Poses.searchQuery == '') then
              if(ImGui.CollapsingHeader(category)) then                
                if category == 'Favorites' and #Poses.anims['Favorites'] == 0 then
                  ImGui.Text("It's empty :(")
                else
                  Poses:DrawAnimsButton(target, category, anims[category])
                end
              end
            end

            ::skip::
          end
        end
        ImGui.EndChild()

        if Poses.historyEnabled then
          ImGui.SetNextWindowSize(600, 700)
          if ImGui.Begin("Last Used Poses", ImGuiWindowFlags.AlwaysAutoResize) then        
            if next(Poses.historyAnims) ~= nil then
              for _, category in ipairs(Poses.historyCategories) do
                if Poses.historyAnims[category] ~= nil and next(Poses.historyAnims[category]) ~= nil and category ~= 'Favorites' then
                  if(ImGui.CollapsingHeader(category.."##History")) then        
                    Poses:DrawAnimsButton(target, category, Poses.historyAnims[category])
                  end
                end                
              end

              AMM.UI:Separator()

              if ImGui.Button("Clear History", ImGui.GetWindowContentRegionWidth(), 40) then
                Poses.history = {}
                Poses.historyEnabled = false
              end
            end
          end
          ImGui.End()
        end        
      end
    else
      ImGui.NewLine()
      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "No NPC Found! Look at NPC to begin")
      ImGui.PopTextWrapPos()

      AMM.UI:Spacing(3)
    end

    ImGui.EndTabItem()
  end
end

function Poses:ToggleFavorite(isFavorite, anim)
	db:execute(f("UPDATE workspots SET anim_fav = %i WHERE anim_name = '%s' AND anim_rig = '%s'", boolToInt(isFavorite), anim.name, anim.rig))
  anim.fav = isFavorite
  Poses.anims['Favorites'] = Poses:GetFavorites()
end

function Poses:DrawAnimsButton(target, category, anims)
  local style = {
    buttonWidth = ImGui.GetWindowContentRegionWidth(),
    buttonHeight = ImGui.GetFontSize() * 2
  }

  AMM.UI:List(category, #anims, style.buttonHeight, function(i)
    local name = anims[i].name:gsub("_", " ")
      name = name:gsub("__", " ")
      name = name.."##"..tostring(i)

      if ImGui.Button(name, style.buttonWidth, style.buttonHeight) then
        Poses:PlayAnimationOnTarget(target, anims[i])
        Poses:AddAnimationToHistory(anims[i])
      end
  end)
end

function Poses:PlayAnimationOnTarget(target, anim, instant)
  if Poses.activeAnims[target.hash] then
    Game.GetWorkspotSystem():StopInDevice(target.handle)

    local activeAnim = Poses.activeAnims[target.hash]
    if activeAnim.handle then
      exEntitySpawner.Despawn(activeAnim.handle)
      activeAnim.handle:Dispose()
    end
  end

  if AMM.userSettings.animPlayerSelfTarget and (anim.rig == "Player Woman" or anim.rig == "Player Man") then
    local entity = Game.GetPlayer()
    target = AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), "V", nil, nil)
  end

  local spawnTransform = target.handle:GetWorldTransform()
  spawnTransform:SetPosition(target.handle:GetWorldPosition())
  local angles = target.handle:GetWorldOrientation():ToEulerAngles()
  angles.yaw = angles.yaw + 180
  spawnTransform:SetOrientationEuler(EulerAngles.new(0, 0, angles.yaw))

  local entityID = exEntitySpawner.Spawn(anim.ent, spawnTransform, '')

  Cron.Every(0.1, {tick = 1}, function(timer)
    local ent = Game.FindEntityByID(entityID)
    if ent then
      anim.handle = ent
      anim.hash = target.hash
      anim.target = target
      Poses.activeAnims[target.hash] = anim
      
      Game.GetWorkspotSystem():PlayInDeviceSimple(anim.handle, target.handle, false, anim.comp)
      Game.GetWorkspotSystem():SendJumpToAnimEnt(target.handle, anim.name, true)
       
      Cron.Halt(timer)
    end
  end)
end

function Poses:RestartAnimation(anim)
  local target = {handle = anim.target.handle, hash = tostring(anim.target.handle:GetEntityID().hash), name = anim.target.name}
  
  Game.GetWorkspotSystem():StopInDevice(target.handle)

  if anim.handle then
    exEntitySpawner.Despawn(anim.handle)
    anim.handle:Dispose()
    anim.handle = nil
  end

  Cron.After(0.3, function()
    Poses:PlayAnimationOnTarget(target, anim, true)
  end)
end

function Poses:StopAnimation(anim, shouldKeep)
  Game.GetWorkspotSystem():StopInDevice(anim.target.handle)

  if not shouldKeep then
    if anim.handle then
      exEntitySpawner.Despawn(anim.handle)
      anim.handle:Dispose()
    end

    Poses.activeAnims[anim.hash] = nil
  end
end

function Poses:AddAnimationToHistory(anim)
  if #Poses.history > 50 then
    table.remove(Poses.history, 1)
  end

  table.insert(Poses.history, anim.id)
  Poses.historyAnims, Poses.historyCategories = Poses:GetAnimationsForListOfIDs(Poses.history)
end

function Poses:GetFavorites(search)
  local query = "SELECT * FROM workspots WHERE anim_fav = 1 ORDER BY anim_name ASC"
  if search then query = "SELECT * FROM workspots WHERE "..search.." AND anim_fav = 1 ORDER BY anim_name ASC" end
  local anims = {}

  for ws in db:nrows(query) do
    table.insert(anims, {name = ws.anim_name, rig = ws.anim_rig, comp = ws.anim_comp, ent = ws.anim_ent, fav = intToBool(ws.anim_fav)})
  end

  return anims
end

function Poses:GetAnimationsForListOfIDs(ids)
  local parsedIDs = "("..table.concat(ids, ", ")..")"
  local orderCase = " ORDER BY CASE anim_id"
  for i, id in ipairs(ids) do
    orderCase = orderCase..f(" WHEN %i THEN %i", id, i)
  end
  orderCase = orderCase.." END"

  local query = 'SELECT * FROM workspots WHERE anim_id in '..parsedIDs..orderCase

	local anims = {}
  local categories = {}
	for workspot in db:nrows(query) do
    if anims[workspot.anim_rig] == nil then
      anims[workspot.anim_rig] = {}
      table.insert(categories, workspot.anim_rig)
    end

		table.insert(anims[workspot.anim_rig], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	end
	return anims, categories
end

function Poses:GetAnimationsForSearch(parsedSearch)
  local query = 'SELECT * FROM workspots WHERE '..parsedSearch..' ORDER BY anim_name ASC'

	local anims = {}

  local favs = Poses:GetFavorites(parsedSearch)
  if #favs == 0 then favs = nil end
  anims['Favorites'] = favs

	for workspot in db:nrows(query) do
    if anims[workspot.anim_rig] == nil then
      anims[workspot.anim_rig] = {}
    end

		table.insert(anims[workspot.anim_rig], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	end
	return anims
end

function Poses:GetAllAnimations()
  local query = "SELECT * FROM workspots WHERE anim_cat IS NULL"

	local anims = {}
	for workspot in db:nrows(query) do
    local category = workspot.anim_rig
    if anims[category] == nil then
      anims[category] = {}
    end

		table.insert(anims[category], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	end

  anims['Favorites'] = Poses:GetFavorites()

	return anims
end

function Poses:GetCollabAnimations()
  local query = "SELECT * FROM workspots WHERE anim_cat IS NOT NULL"

	local anims = {}
  local categories = {}
  local alreadyAdded = {}

	for workspot in db:nrows(query) do
    local rig = workspot.anim_rig
    local category = workspot.anim_cat

    if alreadyAdded[category] == nil then
      alreadyAdded[category] = true
      table.insert(categories, category)
    end

    if anims[category] == nil then
      anims[category] = {}
    end

    if anims[category][rig] == nil then
      anims[category][rig] = {}
    end

		table.insert(anims[category][rig], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	end

	if next(anims) ~= nil and #categories > 0 then return anims, categories end

  return nil, nil
end

function Poses:GetSpecialCategories()
  local query = "SELECT DISTINCT anim_rig FROM workspots WHERE anim_comp = 'amm_workspot_specialnpc' ORDER BY anim_rig ASC"

	local categories = {}

	for workspot in db:nrows(query) do
		categories[workspot.anim_rig] = true
	end
	return categories
end

function Poses:GetCategories()
  local query = "SELECT DISTINCT anim_rig FROM workspots WHERE anim_comp = 'amm_workspot_base' ORDER BY anim_rig ASC"

  if Poses.sceneAnimsInstalled then
    query = "SELECT DISTINCT anim_rig FROM workspots WHERE anim_comp = 'amm_workspot_base' OR anim_comp = 'amm_workspot_custom_base' ORDER BY anim_rig ASC"
  end

	local categories = {}

  table.insert(categories, "Favorites")

	for anim_rig in db:urows(query) do
		table.insert(categories, anim_rig)
	end

  return categories
end

function Poses:ExportFavorites()
  local query = "SELECT anim_id FROM workspots WHERE anim_fav = 1"
  local favs = {}

  for ws in db:urows(query) do
    table.insert(favs, ws)
  end

  return favs
end

function Poses:ImportFavorites(favs)
  for _, fav in ipairs(favs) do
    db:execute(f("UPDATE workspots SET anim_fav = 1 WHERE anim_id = %i", fav))
  end
end

function Poses:GetCategoriesForRig(rig)
  if Poses.rigs[rig] then
    if Poses.sceneAnimsInstalled then
      return {"Favorites", Poses.rigs[rig], Poses.rigs[rig].." Scenes"}
    end

    return {"Favorites", Poses.rigs[rig]}
  end

  local categories = {}
  
  table.insert(categories, "Favorites")

  for _, cat in ipairs(Poses.categories) do
    if string.find(cat, rig) then
      if string.find(cat, "Player") then
      else
        table.insert(categories, cat)
      end
    end
  end

  return categories
end

function Poses:CheckTargetRig(target)
  if target.rig then
    return target.rig
  else
    local rigs = {
      ["fx_woman_base"] = "Woman",
      ["fx_man_base"] = "Man"
    }

    for _, rig in ipairs(Util:GetTableKeys(rigs)) do
      local comp = target.handle:FindComponentByName(rig)
      if comp then
        return rigs[rig]
      end
    end
  end

  return false
end

return Poses:new()
