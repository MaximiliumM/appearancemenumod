local Swap = {
  entities = {},
  activeSwaps = {},
  searchQuery = '',
  searchBarWidth = 500,
  savedSwaps = {},
  specialSwap = false,
}

local target = nil

function Swap:Initialize()
  self:LoadSavedSwaps(self.savedSwaps)
end

function Swap:RevertModelSwap(swapID)
  Game.GetPlayer():SetWarningMessage(AMM.LocalizableString("Warn_ReloadSaveUpdateChanges"))
  local swapObj = self.activeSwaps[swapID]
  self:ChangeEntityTemplateTo(swapObj.name, swapObj.id, swapObj.id)
end

function Swap:ClearSavedSwap(swapID)
  self.savedSwaps[swapID] = nil
  self:RevertModelSwap(swapID)
end

function Swap:SaveModelSwap(swapID)
  local swapObj = self.activeSwaps[swapID]
  self.savedSwaps[swapID] = {swapObj.name, swapObj.newID}
end

function Swap:GetSavedSwaps()
  return self.savedSwaps
end

function Swap:LoadSavedSwaps(userData)
  for id, swap in pairs(userData) do
    self:ChangeEntityTemplateTo(swap[1], id, swap[2])
  end
end

function Swap:NewSwap(name, id, template, newID)
  local obj = {}

  obj.name = name
  obj.id = id
  obj.template = template
  obj.newID = newID

  return obj
end

function Swap:Draw(AMM, t)
  if (ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameSwap"))) then
    -- Same dumb fix from Tools tab
    target = t

    AMM.UI:DrawCrossHair()

    if next(Swap.activeSwaps) ~= nil then
      AMM.UI:TextColored(AMM.LocalizableString("Active_Model_Swaps"))

      for swapID, swapObj in pairs(Swap.activeSwaps) do
        local toID = swapObj.newID

        local toName = ''
        for name in db:urows(f("SELECT entity_name FROM entities WHERE entity_id = '%s'", toID)) do
          toName = name
        end

        ImGui.Text(swapObj.name..' --> '..toName)

        -- Swapped NPC Actions --
        if ImGui.SmallButton(AMM.LocalizableString("Button_SmallRevert").."##"..swapID) then
          Swap:RevertModelSwap(swapID)
        end

        ImGui.SameLine()
        local buttonLabel = AMM.LocalizableString("Save")
        if self.savedSwaps[swapID] ~= nil then
          buttonLabel = AMM.LocalizableString("Clear")
        end

        if ImGui.SmallButton(f("  %s  ##", buttonLabel)..swapID) then
          if buttonLabel == AMM.LocalizableString("Save") then self:SaveModelSwap(swapID)
          else self:ClearSavedSwap(swapID) end
        end

        if self:ShouldDrawFavoriteButton(swapObj.newID) then
          local isFavorite = self:CheckIfFavorite(swapObj.newID)
          local buttonLabel = AMM.LocalizableString("Label_Favorite")
          if isFavorite then
            buttonLabel = AMM.LocalizableString("Label_Unfavorite")
          end

          ImGui.SameLine()
          if ImGui.SmallButton(f("  %s ##", buttonLabel)..swapObj.newID) then
            self:ToggleFavorite(isFavorite, swapObj.newID)
          end
        end

        AMM.UI:Separator()
      end
    end

    if target ~= nil and (target.type == 'Player' or (target.handle and target.handle:IsNPC() or target.handle:IsVehicle() or target.handle:IsReplacer())) then
      AMM.UI:TextColored(AMM.LocalizableString("Current_Target"))
      ImGui.Text(target.name)

      AMM.UI:TextColored(AMM.LocalizableString("Target_ID"))
      ImGui.Text(target.id)

      AMM.UI:Separator()

      ImGui.PushItemWidth(Swap.searchBarWidth)
      Swap.searchQuery = ImGui.InputTextWithHint(" ", AMM.LocalizableString("Search"), Swap.searchQuery, 100)
      Swap.searchQuery = Swap.searchQuery:gsub('"', '')
      ImGui.PopItemWidth()

      if Swap.searchQuery ~= '' then
        ImGui.SameLine()
        if ImGui.Button(AMM.LocalizableString("Clear")) then
          Swap.searchQuery = ''
        end
      end

      ImGui.Spacing()

      AMM.UI:TextColored(AMM.LocalizableString("SelectSwap_CurrentTarget"))

      if Swap.searchQuery ~= '' then
        local entities = {}
        local query = "SELECT * FROM entities WHERE is_swappable = 1 AND entity_name LIKE '%"..Swap.searchQuery.."%' ORDER BY entity_name ASC"
        for en in db:nrows(query) do
          table.insert(entities, en)
        end

        if #entities ~= 0 then
          Swap:DrawEntitiesButtons(entities, "ALL")
        else
          ImGui.Text(AMM.LocalizableString("No_Results"))
        end
      else
        if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), ImGui.GetWindowHeight() / 1.5) then
          for _, category in ipairs(AMM.Spawn.categories) do
            local entities = {}

            if Swap.entities[category] == nil or category.cat_name == 'Favorites' then
              if category.cat_name == 'Favorites' then
                local query = "SELECT * FROM favorites_swap"
                for fav in db:nrows(query) do
                  query = f("SELECT * FROM entities WHERE entity_id = '%s'", fav.entity_id)
                  for en in db:nrows(query) do
                    table.insert(entities, en)
                  end
                end
                if #entities == 0 then
                  if ImGui.CollapsingHeader(category.cat_name) then
                    ImGui.Text(AMM.LocalizableString("ItsEmpty"))
                  end
                end
              else
                local query = f("SELECT * FROM entities WHERE is_swappable = 1 AND cat_id == \"%s\" AND cat_id != 22 ORDER BY entity_name ASC", category.cat_id)
                for en in db:nrows(query) do
                  table.insert(entities, en)
                end
              end

              Swap.entities[category] = entities
            end

            if Swap.entities[category] ~= nil and #Swap.entities[category] ~= 0 then
              local headerFlag = ImGuiTreeNodeFlags.None
				      if AMM.userSettings.favoritesDefaultOpen and category == 'Favorites' then headerFlag = ImGuiTreeNodeFlags.DefaultOpen end
              if(ImGui.CollapsingHeader(category.cat_name, headerFlag)) then
                  Swap:DrawEntitiesButtons(Swap.entities[category], category.cat_name)
              end
            end
          end
        end

        ImGui.EndChild()
      end
    else
      ImGui.NewLine()
      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, AMM.LocalizableString("NoNPC_LookNPC"))
      ImGui.PopTextWrapPos()
    end

    AMM.UI:Separator()

    AMM.UI:TextColored(AMM.LocalizableString("Warning"))
    ImGui.PushTextWrapPos()
    ImGui.Text(AMM.LocalizableString("Warn_NeedReloadSaveUpdateChanges"))
    ImGui.PopTextWrapPos()

    ImGui.EndTabItem()
  end
end

function Swap:ShouldDrawFavoriteButton(entityID)
  local isSwappable = 0
  for ent in db:urows(f('SELECT COUNT(1) FROM entities WHERE entity_id = "%s" AND is_swappable = 1', entityID)) do
    isSwappable = ent
  end
  if isSwappable ~= 0 then return true
  else return false end
end

function Swap:CheckIfFavorite(entityID)
  local isFavorite = 0
	for fav in db:urows(f('SELECT COUNT(1) FROM favorites_swap WHERE entity_id = "%s"', entityID)) do
		isFavorite = fav
	end
  if isFavorite ~= 0 then return true
  else return false end
end

function Swap:ToggleFavorite(isFavorite, entityID)
	if not(isFavorite) then
		local command = f("INSERT INTO favorites_swap (entity_id) VALUES ('%s')", entityID)
		db:execute(command)
	else
		local removedIndex = 0
		local query = f("SELECT position FROM favorites_swap WHERE entity_id = '%s'", entityID)
		for i in db:urows(query) do removedIndex = i end

		local command = f("DELETE FROM favorites_swap WHERE entity_id = '%s'", entityID)
		db:execute(command)
		Swap:RearrangeFavoritesIndex(removedIndex)
	end
end

function Swap:RearrangeFavoritesIndex(removedIndex)
	local lastIndex = 0
	query = "SELECT seq FROM sqlite_sequence WHERE name = 'favorites_swap'"
	for i in db:urows(query) do lastIndex = i end

	if lastIndex ~= removedIndex then
		for i = removedIndex, lastIndex - 1 do
			db:execute(f("UPDATE favorites_swap SET position = %i WHERE position = %i", i, i + 1))
		end
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = 'favorites_swap'", lastIndex - 1))
end

function Swap:DrawArrowButton(direction, id, index)
	-- Decide which table to use based on entity type
	local favoriteType = "favorites_swap"

	-- Determine which ImGui arrow to draw, and what the new target index would be
	local dirEnum = (direction == "up") and ImGuiDir.Up or ImGuiDir.Down
	local tempPos = (direction == "up") and (index - 1) or (index + 1)

	-- Get the total number of favorites so we can clamp positions correctly
	local favoritesCount = 0
	for count in db:urows(string.format("SELECT COUNT(1) FROM %s", favoriteType)) do
		 favoritesCount = count
	end

	if ImGui.ArrowButton(direction .. id, dirEnum) then
     -- Fix positions BEFORE doing the swap so the table is clean
     Util:FixPositionsForFavorites(favoriteType)

		 -- Positions are assumed to start at 0, so valid range is [0, favoritesCount - 1]
		 if tempPos >= 0 and tempPos < favoritesCount then
			  -- Fetch the row at the current position (index)
			  local currentRow
			  for row in db:nrows(string.format("SELECT * FROM %s WHERE position = %d", favoriteType, index)) do
					currentRow = row
					break
			  end

			  -- Fetch the row at the target position (tempPos)
			  local swapRow
			  for row in db:nrows(string.format("SELECT * FROM %s WHERE position = %d", favoriteType, tempPos)) do
					swapRow = row
					break
			  end

			  -- Only proceed if we have valid rows for both positions
			  if currentRow and swapRow then
					-- Start a transaction so we don't get a half-updated DB on error
					db:execute("BEGIN TRANSACTION")

					-- Swap: move the current row data into the 'tempPos' slot
					local update1 = string.format([[
						 UPDATE %s
							 SET entity_id   = '%s'								  
						  WHERE position    = %d
					]],
					favoriteType,
					currentRow.entity_id or "NULL",
					tempPos)
					update1 = update1:gsub('"nil"', "NULL")  -- fix "nil" => "NULL"

					-- Swap: move the swapRow data into the 'index' slot
					local update2 = string.format([[
						 UPDATE %s
							 SET entity_id   = '%s'
						  WHERE position    = %d
					]],
					favoriteType,
					swapRow.entity_id or "NULL",
					index)
					update2 = update2:gsub('"nil"', "NULL")

					-- Execute both updates
					db:execute(update1)
					db:execute(update2)

					-- Commit the transaction
					db:execute("COMMIT")
			  end
		 end
	end
end

function Swap:DrawEntitiesButtons(entities, categoryName)
  local style = {
    buttonWidth = ImGui.GetWindowContentRegionWidth(),
    buttonHeight = ImGui.GetFontSize() * 2
  }

  local targetID = AMM:GetScanID(target.handle)

  for i, en in ipairs(entities) do
		name = en.entity_name.."##"..tostring(i)
		id = en.entity_id
		path = en.entity_path

    local favOffset = 0
		if categoryName == 'Favorites' then
			favOffset = 90

			Swap:DrawArrowButton("up", id, i)
			ImGui.SameLine()
		end

		if ImGui.Button(name, style.buttonWidth - favOffset, style.buttonHeight) then
      Game.GetPlayer():SetWarningMessage(AMM.LocalizableString("Warn_ReloadSaveUpdateChanges"))
      if targetID ~= "0x5E611B16, 24" or categoryName ~= "Cameos" or Swap.specialSwap then
        Swap:ChangeEntityTemplateTo(target.name, targetID, id)
      end
    end

    if categoryName == 'Favorites' then
			ImGui.SameLine()
			Swap:DrawArrowButton("down", id, i)
    end
	end
end

function Swap:ChangeEntityTemplateTo(targetName, fromID, toID)
  if targetName == "Replacer" then 
  -- todo: Show this on the GUI somewhere, somehow
    Game.GetPlayer():SetWarningMessage(AMM.LocalizableString("CantSwapReplacer"))
    spdlog.info(AMM.LocalizableString("Warn_ReplacerSwap"))
    return
  end
  if toID == "0x5E611B16, 24" and not Swap.specialSwap then toID = '0xB1B50FFA, 14' end
  
  local toPath = Swap:GetEntityPathFromID(toID)
  local fromPath = Swap:GetEntityPathFromID(fromID)

  local toTemplate

  -- Revert Swap
  if Swap.activeSwaps[toID] ~= nil and fromID == toID then
    toTemplate = Swap:GetSavedOriginalTemplateForEntity(toID)
    Swap.activeSwaps[toID] = nil
    Swap:UpdateEntityTemplate(fromPath, toTemplate)
  else
    toTemplate = Swap:GetTemplateForEntity(toPath)

    local originalTemplate = nil

    -- Save original template to revert later
  	if Swap.activeSwaps[fromID] == nil then
  		if type(fromPath) == "string" and string.find(fromPath, "Player") then
        fromPath = TweakDBID.new(fromPath)
  			originalTemplate = {}
  			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath, ".entityTemplatePath")))
  			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath, ".appearanceName")))
  			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath, ".genders")))
  		else
  			originalTemplate = TweakDB:GetFlat(TweakDBID.new(fromPath, ".entityTemplatePath"))
  		end
  	else
      originalTemplate = Swap:GetSavedOriginalTemplateForEntity(fromID)
    end

    Swap.activeSwaps[fromID] = Swap:NewSwap(targetName, fromID, originalTemplate, toID)

    Swap:UpdateEntityTemplate(fromPath, toTemplate)
  end
end

function Swap:GetSavedOriginalTemplateForEntity(entityID)
  local entityTemplate = Swap.activeSwaps[entityID].template
  return entityTemplate
end

function Swap:GetTemplateForEntity(entityPath)
  local entityTemplate
  if type(entityPath) == "string" and string.find(entityPath, "Player") then
    entityPath = TweakDBID.new(entityPath)
    entityTemplate = {}
    table.insert(entityTemplate, TweakDB:GetFlat(TweakDBID.new(entityPath, ".entityTemplatePath")))
    table.insert(entityTemplate, TweakDB:GetFlat(TweakDBID.new(entityPath, ".appearanceName")))
    table.insert(entityTemplate, TweakDB:GetFlat(TweakDBID.new(entityPath, ".genders")))
    table.insert(entityTemplate, TweakDB:GetFlat(TweakDBID.new(entityPath, ".attachmentSlots")))
  else
    entityTemplate = TweakDB:GetFlat(TweakDBID.new(entityPath, ".entityTemplatePath"))
  end

  return entityTemplate
end

function Swap:UpdateEntityTemplate(entityPath, newTemplate)
  if type(newTemplate) == 'table' then
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath, ".entityTemplatePath"), newTemplate[1])
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath, ".appearanceName"), newTemplate[2])
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath, ".genders"), newTemplate[3])
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath, ".attachmentSlots"), newTemplate[4])
  else
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath, ".entityTemplatePath"), newTemplate)
  end

  TweakDB:Update(entityPath)
end

function Swap:GetEntityPathFromID(id)
  local entityPath = nil

  if Util:CheckVByID(id) then
    if id == '0xBD4D2E74, 21' then
      return "AMM_Character.Player"..Util:GetPlayerGender()
    else
      return "Character.TPP_Player_Cutscene"..Util:GetPlayerGender()
    end
  end

  return loadstring("return TweakDBID.new("..id..")", '')()

  -- for path in db:urows(f("SELECT entity_path FROM entities WHERE entity_id = '%s'", id)) do
  --   entityPath = path
  -- end

  -- if not entityPath then
  --   for path in db:urows(f("SELECT entity_path FROM paths WHERE entity_id = '%s'", id)) do
  --     entityPath = path
  --   end
  -- end

  -- if entityPath then return entityPath else print("[AMM] entity path not found!") end
end

if io.open("specialSwap.lua", "r") then
   Swap.specialSwap = require('specialSwap.lua')
end

return Swap
