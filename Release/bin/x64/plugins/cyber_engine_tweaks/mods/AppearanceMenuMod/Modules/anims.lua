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
  if (ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabPoses"))) then

    AMM.UI:DrawCrossHair()

    if AMM.Tools.lockTarget and AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '' then
      if AMM.Tools.currentTarget.handle.IsNPC and AMM.Tools.currentTarget.handle:IsNPC() then
        target = AMM.Tools.currentTarget
      end
    end

    if next(Poses.activeAnims) ~= nil then
      AMM.UI:TextColored(AMM.LocalizableString("Active_Animations"))

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
        if anim.target.handle ~= '' and
        (Tools.frozenNPCs[hash] or not Game.GetWorkspotSystem():IsActorInWorkspot(anim.target.handle)) then
          buttonLabel = IconGlyphs.Play or "  Play  "
        end

        if AMM.UI:SmallButton(buttonLabel.."##"..hash) then
          local frozen = anim.target.handle and Tools.frozenNPCs[hash] == true
          if not Game.GetWorkspotSystem():IsActorInWorkspot(anim.target.handle) and not frozen then
            Poses:RestartAnimation(anim)
          else
            Tools:FreezeNPC(anim.target.handle, not(frozen))
          end
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton((IconGlyphs.Stop or "  Stop  ").."##"..hash) then
          local frozen = anim.target.handle and Tools.frozenNPCs[hash] == true
          if frozen then
            Tools:FreezeNPC(anim.target.handle, not(frozen))
          end

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
          if AMM.UI:SmallButton(AMM.LocalizableString("Button_SmallTarget").."##"..hash) then
            AMM.Tools:SetCurrentTarget(anim.target)
            AMM.Tools.lockTarget = true
          end
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton(AMM.LocalizableString("Button_SmallCopyClipboard").."##"..hash) then
          ImGui.SetClipboardText(name)
        end

        ImGui.SameLine()
        if AMM.UI:SmallButton((IconGlyphs.CloseThick or "  Remove  ").."##"..hash) then
          local frozen = anim.target.handle and Tools.frozenNPCs[hash] == true
          if frozen then
            Tools:FreezeNPC(anim.target.handle, not(frozen))
          end

          Poses:StopAnimation(anim)
        end

        AMM.UI:Separator()
      end
    end

    if target == nil and AMM.userSettings.animPlayerSelfTarget then
      local entity = Game.GetPlayer()
      target = AMM:NewTarget(entity, "Player", AMM:GetScanID(entity), "V", nil, nil)
      if AMM.playerGender == "_Female" then target.rig = 'player_woman_skeleton' else target.rig = 'player_man_skeleton' end
    end

    if target ~= nil and (target.type == 'Player' or (target.handle.IsNPC and target.handle:IsNPC()) or (target.handle.IsReplacer and target.handle:IsReplacer())) then
      AMM.UI:TextColored(AMM.LocalizableString("Current_Target"))
      ImGui.Text(target.name)

      AMM.UI:Separator()

      ImGui.PushItemWidth(Poses.searchBarWidth)
      Poses.searchQuery = ImGui.InputTextWithHint(" ", AMM.LocalizableString("Search"), Poses.searchQuery, 100)
      Poses.searchQuery = Poses.searchQuery:gsub('"', '')
      ImGui.PopItemWidth()

      if Poses.searchQuery ~= '' then
        ImGui.SameLine()
        if ImGui.Button(AMM.LocalizableString("Clear")) then
          Poses.searchQuery = ''
        end
      end

      if next(Poses.historyAnims) ~= nil then
        Poses.historyEnabled = ImGui.Checkbox(AMM.LocalizableString("ShowHistory"), Poses.historyEnabled)
      end

      ImGui.Spacing()

      AMM.UI:TextColored(AMM.LocalizableString("SelectPoseForCurrentTarget"))

      local anims = Poses.currentAnims

      -- could do with or {}, but let's be verbose
      if not anims then
        spdlog.info("anims not set")
        anims = {}
      end

      if Poses.searchQuery ~= '' and Poses.searchQuery ~= Poses.lastSearchQuery then
        local parsedSearch = Util:ParseSearch(Poses.searchQuery, "anim_name")
        Poses.currentAnims = Poses:GetAnimationsForSearch(parsedSearch)
        Poses.lastSearchQuery = Poses.searchQuery
      elseif Poses.searchQuery ~= Poses.lastSearchQuery then
        Poses.currentAnims = {}
      end

      if Poses.searchQuery ~= '' and next(anims) == nil then
        ImGui.Text(AMM.LocalizableString("No_Results"))
      else
        local resX, resY = GetDisplayResolution()
        local y = resY / 3

        if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y) then
          local categories = Util:ShallowCopy({}, Poses.categories)
          local specials = Poses.specialCategories[target.name]

          local rigs = Poses:CheckTargetRig(target)

          if rigs then
            categories = Poses:GetCategoriesForRig(rigs)
          end

          if specials and not Util:CheckIfTableHasValue(categories, target.name) then
            table.insert(categories, target.name)
          end

          -- no need to do the lookup here, this was initialized during
          -- Poses.collabAnims, Poses.collabCategories = Poses:GetCollabAnimations()
          -- athough collabAnims seems to be falsy? Maybe we can optimize some more here

          for _, collabCategory in ipairs(Poses.collabCategories or {}) do
            table.insert(categories, collabCategory)
          end

          if next(anims) == nil then
            anims = Util:ShallowCopy({}, Poses.anims)
          end

          for _, category in ipairs(categories) do
            if anims[category] ~= nil and next(anims[category]) ~= nil or (category == 'Favorites' and Poses.searchQuery == '') then
              if anims[category][1] == nil and category ~= 'Favorites' then -- This means it's a Collab category
                if (ImGui.CollapsingHeader(category)) then
                  local count = 0
                  local usableRig = nil
                  for _, rig in ipairs(categories) do
                    if anims[category][rig] then
                      count = count + 1
                      usableRig = rig
                    end
                  end

                  -- direct matches from categories
                  if count > 1 then
                    for _, rig in ipairs(categories) do
                      if anims[category][rig] then
                        if (ImGui.CollapsingHeader(rig.."##"..category)) then
                          Poses:DrawAnimsButton(target, category, anims[category][rig])
                        end
                      end
                    end
                  -- the collab has tables nested by human-readable rig name
                  elseif usableRig then
                    Poses:DrawAnimsButton(target, category, anims[category][usableRig])
                  end
                end
              else -- it's not a collab category
                if (ImGui.CollapsingHeader(category)) then
                  if category == 'Favorites' and #Poses.anims['Favorites'] == 0 then
                    ImGui.Text(AMM.LocalizableString("ItsEmpty"))
                  else
                    Poses:DrawAnimsButton(target, category, anims[category])
                  end
                end
              end
            end
          end
        end
        ImGui.EndChild()

        if Poses.historyEnabled then
          ImGui.SetNextWindowSize(600, 700)
          if ImGui.Begin(AMM.LocalizableString("LastUsedPoses"), ImGuiWindowFlags.AlwaysAutoResize) then
            if next(Poses.historyAnims) ~= nil then
              for _, category in ipairs(Poses.historyCategories) do
                if Poses.historyAnims[category] ~= nil and next(Poses.historyAnims[category]) ~= nil and category ~= 'Favorites' then
                  if(ImGui.CollapsingHeader(category.."##History")) then        
                    Poses:DrawAnimsButton(target, category, Poses.historyAnims[category])
                  end
                end                
              end

              AMM.UI:Separator()

              if ImGui.Button(AMM.LocalizableString("ClearHistory"), ImGui.GetWindowContentRegionWidth(), 40) then
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
      ImGui.TextColored(1, 0.16, 0.13, 0.75, AMM.LocalizableString("NoNPC_LookNPC"))
      ImGui.PopTextWrapPos()

      AMM.UI:Spacing(3)
    end

    ImGui.EndTabItem()
  end
end

function Poses:ToggleFavorite(isFavorite, anim)
	db:execute(f("UPDATE workspots SET anim_fav = %i WHERE anim_name = \"%s\" AND anim_rig = '%s'", boolToInt(isFavorite), anim.name, anim.rig))
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
      name = name.."##"..category..tostring(i)

      if ImGui.Button(name, style.buttonWidth, style.buttonHeight) then
        Poses:PlayAnimationOnTarget(target, anims[i])
        Poses:AddAnimationToHistory(anims[i])
      end
  end)
end

function Poses:PlayAnimationOnTarget(t, anim, instant)
  if Poses.activeAnims[t.hash] then
    Game.GetWorkspotSystem():StopInDevice(t.handle)

    local activeAnim = Poses.activeAnims[t.hash]
    if activeAnim.handle then
      exEntitySpawner.Despawn(activeAnim.handle)
      activeAnim.handle:Dispose()
    end
  end

  if AMM.userSettings.animPlayerSelfTarget and (anim.rig == "Player Woman" or anim.rig == "Player Man") then
    local entity = Game.GetPlayer()
    t = AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), "V", nil, nil)
  end

  local spawnTransform = t.handle:GetWorldTransform()
  spawnTransform:SetPosition(t.handle:GetWorldPosition())
  local angles = t.handle:GetWorldOrientation():ToEulerAngles()
  angles.yaw = angles.yaw + 180
  spawnTransform:SetOrientationEuler(EulerAngles.new(0, 0, angles.yaw))

  local entityID = exEntitySpawner.Spawn(anim.ent, spawnTransform, '')

  Cron.Every(0.1, {tick = 1}, function(timer)
    local ent = Game.FindEntityByID(entityID)
    if ent then
      anim.handle = ent
      anim.hash = t.hash
      anim.target = t
      Poses.activeAnims[t.hash] = anim
      
      Game.GetWorkspotSystem():PlayInDeviceSimple(anim.handle, t.handle, false, anim.comp, nil, nil, 0, 1, nil)
      Game.GetWorkspotSystem():SendJumpToAnimEnt(t.handle, anim.name, instant)
       
      Cron.Halt(timer)
    end
  end)
end

function Poses:RestartAnimation(anim)
  local target = anim.target
  
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
  if search then query = f("SELECT * FROM workspots WHERE %s AND anim_fav = 1 ORDER BY anim_name ASC", search) end
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
    local category = workspot.anim_rig
    -- if workspot.anim_cat then category = workspot.anim_cat end

    if anims[category] == nil then
      anims[category] = {}
      table.insert(categories, category)
    end

		table.insert(anims[category], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
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
    local category = workspot.anim_rig
    if workspot.anim_cat then category = workspot.anim_cat end

    if anims[category] == nil then
      anims[category] = {}
    end

    if workspot.anim_cat and anims[category][workspot.anim_rig] == nil then
      anims[category][workspot.anim_rig] = {}
    end

    if workspot.anim_cat then
      table.insert(anims[category][workspot.anim_rig], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
    else
      table.insert(anims[category], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	  end
  end

	return anims
end

function Poses:GetAllAnimations()
  local query = "SELECT * FROM workspots"

	local anims = {}
	for workspot in db:nrows(query) do
    local category = workspot.anim_rig
    if workspot.anim_cat then category = workspot.anim_cat end

    if anims[category] == nil then
      anims[category] = {}
    end

    if workspot.anim_cat and anims[category][workspot.anim_rig] == nil then
      anims[category][workspot.anim_rig] = {}
    end

    if workspot.anim_cat then
      table.insert(anims[category][workspot.anim_rig], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
    else
      table.insert(anims[category], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	  end
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

  -- not completely sure what the check is doing :D Shouldn't we just create empty tables?
  -- that way, we can always iterate, and if there's no data, we'll get a log message here
	if next(anims) ~= nil and #categories > 0 then
    return anims, categories
  end

  spdlog.info("No custom poses found")
  return {}, {}
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

function Poses:GetCategoriesForRig(rigs)
  local categories = {}

  table.insert(categories, "Favorites")

  for _, r in ipairs(rigs) do
    if Poses.rigs[r] then -- I have no idea why this can be nil, but https://discord.com/channels/420406569872916480/1145732822896758785/1145750991677952030
      table.insert(categories, Poses.rigs[r])
      if Poses.sceneAnimsInstalled then
        table.insert(categories, Poses.rigs[r].." Scenes")
      end
    end
  end

  return categories
end

function Poses:CheckTargetRig(target)
  if target.rig then
    if AMM.userSettings.allowPlayerAnimationOnNPCs then
      local prefix = Util:GetPrefix(target.rig)
      return {target.rig, "player_"..prefix.."_skeleton"}
    end
    
    return {target.rig}
  else
    local rigs = {
      ["fx_woman_base"] = "woman",
      ["fx_man_base"] = "man"
    }

    local compRig = nil
    local possibleRigs = {}

    for _, rig in ipairs(Util:GetTableKeys(rigs)) do
      local comp = target.handle:FindComponentByName(rig)
      if comp then
        compRig = rigs[rig]
        break
      end
    end

    if compRig then
      for _, cat in ipairs(Util:GetTableKeys(Poses.rigs)) do
        if Util:IsPrefix(compRig, cat) or (Util:IsPrefix("player_"..compRig, cat) and AMM.userSettings.allowPlayerAnimationOnNPCs) then
          table.insert(possibleRigs, cat)
        end
      end

      return possibleRigs
    end
  end

  return false
end

return Poses:new()
