local Swap = {
  entities = {},
  activeSwaps = {},
  searchQuery = '',
  searchBarWidth = 500,
  savedSwaps = {},
  specialSwap = false,
}

function Swap:Initialize()
  self:LoadSavedSwaps(self.savedSwaps)
end

function Swap:RevertModelSwap(swapID)
  Game.GetPlayer():SetWarningMessage("Reload your save game to update changes!")
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

function Swap:Draw(AMM, target)
  if (ImGui.BeginTabItem("Swap")) then

    AMM.UI:DrawCrossHair()

    if next(Swap.activeSwaps) ~= nil then
      AMM.UI:TextColored("Active Model Swaps")

      for swapID, swapObj in pairs(Swap.activeSwaps) do
        local toID = swapObj.newID

        local toName = ''
        for name in db:urows(f("SELECT entity_name FROM entities WHERE entity_id = '%s'", toID)) do
          toName = name
        end

        ImGui.Text(swapObj.name..' --> '..toName)

        -- Swapped NPC Actions --
        if ImGui.SmallButton("  Revert  ##"..swapID) then
          Swap:RevertModelSwap(swapID)
        end

        ImGui.SameLine()
        local buttonLabel = "Save"
        if self.savedSwaps[swapID] ~= nil then
          buttonLabel = "Clear"
        end

        if ImGui.SmallButton(f("  %s  ##", buttonLabel)..swapID) then
          if buttonLabel == "Save" then self:SaveModelSwap(swapID)
          else self:ClearSavedSwap(swapID) end
        end

        if self:ShouldDrawFavoriteButton(swapObj.newID) then
          local isFavorite = self:CheckIfFavorite(swapObj.newID)
          local buttonLabel = 'Favorite'
          if isFavorite then
            buttonLabel = 'Unfavorite'
          end

          ImGui.SameLine()
          if ImGui.SmallButton(f("  %s ##", buttonLabel)..swapObj.newID) then
            self:ToggleFavorite(isFavorite, swapObj.newID)
          end
        end

        AMM.UI:Separator()
      end
    end

    if target ~= nil and (target.type == 'Player' or target.handle:IsNPC() or target.handle:IsVehicle() or target.handle:IsReplacer()) then
      AMM.UI:TextColored("Current Target:")
      ImGui.Text(target.name)

      AMM.UI:TextColored("Target ID:")
      ImGui.Text(target.id)

      AMM.UI:Separator()

      ImGui.PushItemWidth(Swap.searchBarWidth)
      Swap.searchQuery = ImGui.InputTextWithHint(" ", "Search", Swap.searchQuery, 100)
      Swap.searchQuery = Swap.searchQuery:gsub('"', '')
      ImGui.PopItemWidth()

      if Swap.searchQuery ~= '' then
        ImGui.SameLine()
        if ImGui.Button("Clear") then
          Swap.searchQuery = ''
        end
      end

      ImGui.Spacing()

      AMM.UI:TextColored("Select To Swap With Current Target:")

      if Swap.searchQuery ~= '' then
        local entities = {}
        local query = "SELECT * FROM entities WHERE is_swappable = 1 AND entity_name LIKE '%"..Swap.searchQuery.."%' ORDER BY entity_name ASC"
        for en in db:nrows(query) do
          table.insert(entities, en)
        end

        if #entities ~= 0 then
          Swap:DrawEntitiesButtons(entities, "ALL")
        else
          ImGui.Text("No Results")
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
                    ImGui.Text("It's empty :(")
                  end
                end
              else
                local query = f("SELECT * FROM entities WHERE is_swappable = 1 AND cat_id == '%s' AND cat_id != 22 ORDER BY entity_name ASC", category.cat_id)
                for en in db:nrows(query) do
                  table.insert(entities, en)
                end
              end

              Swap.entities[category] = entities
            end

            if Swap.entities[category] ~= nil and #Swap.entities[category] ~= 0 then
              if(ImGui.CollapsingHeader(category.cat_name)) then
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
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "No NPC Found! Look at NPC to begin")
      ImGui.PopTextWrapPos()
    end

    AMM.UI:Separator()

    AMM.UI:TextColored("WARNING")
    ImGui.PushTextWrapPos()
    ImGui.Text("You will need to reload your save to update changes.")
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

function Swap:DrawArrowButton(direction, entityID, index)
	local dirEnum, tempPos
	if direction == "up" then
		dirEnum = ImGuiDir.Up
		tempPos = index - 1
	else
		dirEnum = ImGuiDir.Down
		tempPos = index + 1
	end

	local query = "SELECT COUNT(1) FROM favorites_swap"
	for x in db:urows(query) do favoritesLength = x end

	if ImGui.ArrowButton(direction..entityID, dirEnum) then
		if not(tempPos < 1 or tempPos > favoritesLength) then
			local query = f("SELECT * FROM favorites_swap WHERE position = %i", tempPos)
			for fav in db:nrows(query) do temp = fav end

			db:execute(f("UPDATE favorites_swap SET entity_id = '%s' WHERE position = %i", entityID, tempPos))
			db:execute(f("UPDATE favorites_swap SET entity_id = '%s' WHERE position = %i", temp.entity_id, index))
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
      Game.GetPlayer():SetWarningMessage("Reload your save game to update changes!")
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
  		if player then
  			originalTemplate = {}
  			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath..".entityTemplatePath")))
  			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath..".appearanceName")))
  			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath..".genders")))
  		else
  			originalTemplate = TweakDB:GetFlat(TweakDBID.new(fromPath..".entityTemplatePath"))
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
  local player = string.find(entityPath, "Player")
  if player then
    entityPath = entityPath..Util:GetPlayerGender()
    entityTemplate = {}
    table.insert(entityTemplate, TweakDB:GetFlat(TweakDBID.new(entityPath..".entityTemplatePath")))
    table.insert(entityTemplate, TweakDB:GetFlat(TweakDBID.new(entityPath..".appearanceName")))
    table.insert(entityTemplate, TweakDB:GetFlat(TweakDBID.new(entityPath..".genders")))
  else
    entityTemplate = TweakDB:GetFlat(TweakDBID.new(entityPath..".entityTemplatePath"))
  end

  return entityTemplate
end

function Swap:UpdateEntityTemplate(entityPath, newTemplate)
  if type(newTemplate) == 'table' then
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath..".entityTemplatePath"), newTemplate[1])
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath..".appearanceName"), newTemplate[2])
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath..".genders"), newTemplate[3])
  else
    TweakDB:SetFlatNoUpdate(TweakDBID.new(entityPath..".entityTemplatePath"), newTemplate)
  end

  TweakDB:Update(TweakDBID.new(entityPath))
end

function Swap:GetEntityPathFromID(id)
  local entityPath = nil

  if Util:CheckVByID(id) then
    return "Character.TPP_Player_Cutscene"..Util:GetPlayerGender()
  end

  for path in db:urows(f("SELECT entity_path FROM entities WHERE entity_id = '%s'", id)) do
    entityPath = path
  end

  if not entityPath then
    for path in db:urows(f("SELECT entity_path FROM paths WHERE entity_id = '%s'", id)) do
      entityPath = path
    end
  end

  if entityPath then return entityPath else print("[AMM] entity path not found!") end
end

if io.open("specialSwap.lua", "r") then
   Swap.specialSwap = require('specialSwap.lua')
end

return Swap
