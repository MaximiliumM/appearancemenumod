Poses = {}

function Poses:new()
  Poses.anims = {}
  Poses.categories = nil
  Poses.specialCategories = nil
  Poses.sceneAnimsInstalled = false
  Poses.searchQuery = ''
  Poses.searchBarWidth = 500
  Poses.historyEnabled = false
  
  Poses.activeAnims = {}
  Poses.historyAnims = {}
  Poses.history = {}
  Poses.historyCategories = {}

  Poses.rigs = {
    ["man_base"] = "Man Average",
    ["man_big"] = "Man Big",
    ["man_child"] = "Man Child",
    ["man_fat"] = "Man Fat",
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

  if #Poses.history > 0 then
    Poses.historyAnims, Poses.historyCategories = Poses:GetAnimationsForListOfIDs(Poses.history)
  end
end

function Poses:Draw(AMM, target)
  if (ImGui.BeginTabItem("Poses")) then

    AMM.UI:DrawCrossHair()

    if AMM.Tools.lockTarget then
      if AMM.Tools.currentTarget.handle:IsNPC() then
        target = AMM.Tools.currentTarget
      end
    end

    if next(Poses.activeAnims) ~= nil then
      AMM.UI:TextColored("Active Animations")

      for hash, anim in pairs(Poses.activeAnims) do

        ImGui.Text(anim.target.name)
        local name = anim.name:gsub("_", " ")
        name = name:gsub("__", " ")
        ImGui.Text(name)

        if ImGui.SmallButton("  Stop  ##"..hash) then
          Poses:StopAnimation(anim)
        end

        ImGui.SameLine()
        local isFavorite = anim.fav
        local buttonLabel = 'Favorite'
        if isFavorite then
          buttonLabel = 'Unfavorite'
        end

        ImGui.SameLine()
        if ImGui.SmallButton(f("  %s ##", buttonLabel)..hash) then
          Poses:ToggleFavorite(not isFavorite, anim)
        end

        AMM.UI:Separator()
      end
    end

    if target == nil and AMM.userSettings.animPlayerSelfTarget then
      local entity = Game.GetPlayer()
      target = AMM:NewTarget(entity, "Player", AMM:GetScanID(entity), "V", nil, nil)
    end

    if target ~= nil and (target.type == 'Player' or target.handle:IsNPC() or target.handle:IsReplacer()) then
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
      
      local anims = {}

      if Poses.searchQuery ~= '' then
        local parsedSearch = Util:ParseSearch(Poses.searchQuery, "anim_name")
        anims = Poses:GetAnimationsForSearch(parsedSearch)
      end

      if Poses.searchQuery ~= '' and next(anims) == nil then
        ImGui.Text("No Results")
      else
        local resX, resY = GetDisplayResolution()
        local y = resY / 3

        if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y) then
          local categories = Poses.categories
          local specials = Poses.specialCategories[target.name]

          local rig = Poses:CheckTargetRig(target)

          if rig and target.type ~= 'Player' then
            categories = rig
          end

          if specials and not Util:CheckIfTableHasValue(categories, target.name) then
            table.insert(categories, target.name)
          end          

          for _, category in ipairs(categories) do
            local gender = Util:GetPlayerGender()

            if target.type == "Player" and AMM.userSettings.animPlayerSelfTarget then
              if gender == "_Female" then gender = "Player Woman" else gender = "Player Man" end
              if category == gender then gender = true else gender = false end       
            end

            if category == 'Favorites' then
              local query = "SELECT * FROM workspots WHERE anim_fav = 1 ORDER BY anim_name ASC"
              Poses.anims['Favorites'] = {}

              for ws in db:nrows(query) do
                table.insert(Poses.anims['Favorites'], {name = ws.anim_name, rig = ws.anim_rig, comp = ws.anim_comp, ent = ws.anim_ent, fav = intToBool(ws.anim_fav)})       
              end              
            end

            if next(anims) == nil then
              anims = Poses.anims
            end
            
            if not gender and category ~= 'Favorites' then goto skip end
            if (category == "Player Woman" or category == "Player Man")
            and AMM.userSettings.animPlayerSelfTarget and target.type ~= "Player" then goto skip end
            
            if anims[category] ~= nil and next(anims[category]) ~= nil or category == 'Favorites' then
              if(ImGui.CollapsingHeader(category)) then
                if ImGui.BeginChild(category, ImGui.GetWindowContentRegionWidth(), ImGui.GetWindowHeight() / 1.5) then
                  if category == 'Favorites' and #Poses.anims['Favorites'] == 0 then
                    ImGui.Text("It's empty :(")
                  else                
                    Poses:DrawAnimsButton(target, anims[category])
                  end
                end
                ImGui.EndChild()
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
                    Poses:DrawAnimsButton(target, Poses.historyAnims[category])
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
end

function Poses:DrawAnimsButton(target, anims)
  local style = {
    buttonWidth = ImGui.GetWindowContentRegionWidth(),
    buttonHeight = ImGui.GetFontSize() * 2
  }

  for i, anim in ipairs(anims) do
    local name = anim.name:gsub("_", " ")
    name = name:gsub("__", " ")
		name = name.."##"..tostring(i)

		if ImGui.Button(name, style.buttonWidth, style.buttonHeight) then
      Poses:PlayAnimationOnTarget(target, anim)
      Poses:AddAnimationToHistory(anim)
    end
	end
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

function Poses:StopAnimation(anim)
  Game.GetWorkspotSystem():StopInDevice(anim.target.handle)

  if anim.handle then
    exEntitySpawner.Despawn(anim.handle)
    anim.handle:Dispose()
  end

  Poses.activeAnims[anim.hash] = nil
end

function Poses:AddAnimationToHistory(anim)
  if #Poses.history > 50 then
    table.remove(Poses.history, 1)
  end

  table.insert(Poses.history, anim.id)
  Poses.historyAnims, Poses.historyCategories = Poses:GetAnimationsForListOfIDs(Poses.history)
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
	for workspot in db:nrows(query) do
    if anims[workspot.anim_rig] == nil then
      anims[workspot.anim_rig] = {}
    end

		table.insert(anims[workspot.anim_rig], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	end
	return anims
end

function Poses:GetAllAnimations()
  local query = "SELECT * FROM workspots"

	local anims = {}
	for workspot in db:nrows(query) do
    if anims[workspot.anim_rig] == nil then
      anims[workspot.anim_rig] = {}
    end

		table.insert(anims[workspot.anim_rig], {id = workspot.anim_id, name = workspot.anim_name, rig = workspot.anim_rig, comp = workspot.anim_comp, ent = workspot.anim_ent, fav = intToBool(workspot.anim_fav or 0)})
	end
	return anims
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

	for workspot in db:nrows(query) do
		table.insert(categories, workspot.anim_rig)
	end
	return categories
end

function Poses:ExportFavorites()
  local query = "SELECT anim_id FROM workspots WHERE anim_fav = 1"
  local favs = {}

  for ws in db:nrows(query) do
    table.insert(favs, ws)
  end

  return favs
end

function Poses:ImportFavorites(favs)
  for _, fav in ipairs(favs) do
    db:execute(f("UPDATE workspots SET anim_fav = 1 WHERE anim_id = %i", fav))
  end
end

function Poses:CheckTargetRig(target)
  if target.rig then
    return {Poses.rigs[target.rig], Poses.rigs[target.rig].." Scenes"}
  else
    local rigs = {
      ["fx_woman_base"] = "Woman",
      ["fx_man_base"] = "Man"
    }

    for _, rig in ipairs(Util:GetTableKeys(rigs)) do
      local comp = target.handle:FindComponentByName(rig)
      if comp then
        local gender = rigs[rig]
        local categories = {}
        for _, cat in ipairs(Poses.categories) do
          if string.find(cat, gender) then
            if string.find(cat, "Player") and target.type ~= "Player" then
            else
              table.insert(categories, cat)
            end
          end
        end
  
        return categories
      end
    end
  end

  return false
end

return Poses:new()
