local Swap = {
  activeSwaps = {},
  searchQuery = '',
  searchBarWidth = 530,
  savedSwaps = {}
}

-- ALIAS for string.format --
local f = string.format
local Util = require('Modules/util.lua')

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
    self.savedSwaps[id] = {swap[1], swap[2]}
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

function Swap:Draw(ScanApp, target)
  if (ImGui.BeginTabItem("Swap")) then

    if next(Swap.activeSwaps) ~= nil then
      ScanApp.Theme:TextColored("Active Model Swaps")

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
        ScanApp.Theme:Separator()
      end
    end

    if target ~= nil then
      ScanApp.Theme:TextColored("Current Target:")
      ImGui.Text(target.name)

      ScanApp.Theme:Separator()

      ImGui.PushItemWidth(Swap.searchBarWidth)
      Swap.searchQuery = ImGui.InputTextWithHint(" ", "Search", Swap.searchQuery, 100)
      ImGui.PopItemWidth()

      if Swap.searchQuery ~= '' then
        ImGui.SameLine()
        if ImGui.Button("Clear") then
          Swap.searchQuery = ''
        end
      end

      ImGui.Spacing()

      ScanApp.Theme:TextColored("Select To Swap With Current Target:")

      if Swap.searchQuery ~= '' then
        local entities = {}
        local query = "SELECT * FROM entities WHERE is_swappable = 1 AND entity_name LIKE '%"..Swap.searchQuery.."%' ORDER BY entity_name ASC"
        for en in db:nrows(query) do
          table.insert(entities, {en.entity_name, en.entity_id, en.entity_path})
        end

        if #entities ~= 0 then
          Swap:DrawEntitiesButtons(entities)
        else
          ImGui.Text("No Results")
        end
      else
        y = ImGui.GetFontSize() * 20
        if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y) then
          for _, category in ipairs(ScanApp.categories) do
            if category.cat_name ~= "Favorites" then
              local entities = {}

              local query = f("SELECT * FROM entities WHERE is_swappable = 1 AND cat_id == '%s' ORDER BY entity_name ASC", category.cat_id)
              for en in db:nrows(query) do
                table.insert(entities, {en.entity_name, en.entity_id, en.entity_path})
              end

              if #entities ~= 0 then
                if(ImGui.CollapsingHeader(category.cat_name)) then
                  Swap:DrawEntitiesButtons(entities)
                end
              end
            end
          end
        end
        ImGui.EndChild()
      end
    else
      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "No NPC Found! Look at NPC to begin\n\n")
      ImGui.PopTextWrapPos()
    end

    ScanApp.Theme:Separator()

    ScanApp.Theme:TextColored("WARNING")
    ImGui.Text("You will need to reload your save to update changes.")

    ImGui.EndTabItem()
  end
end

function Swap:DrawEntitiesButtons(entities)
  local style = {
    buttonWidth = -1,
    buttonHeight = ImGui.GetFontSize() * 2
  }

  for i, entity in ipairs(entities) do
		name = entity[1]
		id = entity[2]
		path = entity[3]

		if ImGui.Button(name, style.buttonWidth, style.buttonHeight) then
      Game.GetPlayer():SetWarningMessage("Reload your save game to update changes!")
      if target.id ~= "0x903E76AF, 43" then
        Swap:ChangeEntityTemplateTo(target.name, target.id, id)
      end
    end
	end
end

function Swap:ChangeEntityTemplateTo(targetName, fromID, toID)
  if toID == "0x903E76AF, 43" then toID = '0xB1B50FFA, 14' end

	toPath = ''
	for path in db:urows(f("SELECT entity_path FROM paths WHERE entity_id = '%s'", toID)) do
		toPath = path
	end
	fromPath = ''
	for path in db:urows(f("SELECT entity_path FROM paths WHERE entity_id = '%s'", fromID)) do
		fromPath = path
	end

	local player = string.find(toPath, "Player")
	if player then
		toPath = toPath..Util:GetPlayerGender()
		toTemplate = {}
		table.insert(toTemplate, TweakDB:GetFlat(TweakDBID.new(toPath..".entityTemplatePath")))
		table.insert(toTemplate, TweakDB:GetFlat(TweakDBID.new(toPath..".appearanceName")))
		table.insert(toTemplate, TweakDB:GetFlat(TweakDBID.new(toPath..".genders")))
	else
		toTemplate = TweakDB:GetFlat(TweakDBID.new(toPath..".entityTemplatePath"))
	end

	if Swap.activeSwaps[toID] ~= nil then
		toTemplate = Swap.activeSwaps[toID].template
		Swap.activeSwaps[toID] = nil
	else
		if player then
			originalTemplate = {}
			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath..".entityTemplatePath")))
			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath..".appearanceName")))
			table.insert(originalTemplate, TweakDB:GetFlat(TweakDBID.new(fromPath..".genders")))
		else
			originalTemplate = TweakDB:GetFlat(TweakDBID.new(fromPath..".entityTemplatePath"))
		end

		Swap.activeSwaps[fromID] = Swap:NewSwap(targetName, fromID, originalTemplate, toID)
	end

	if type(toTemplate) == 'table' then
		TweakDB:SetFlat(TweakDBID.new(fromPath..".entityTemplatePath"), toTemplate[1])
		TweakDB:SetFlat(TweakDBID.new(fromPath..".appearanceName"), toTemplate[2])
		TweakDB:SetFlat(TweakDBID.new(fromPath..".genders"), toTemplate[3])
	else
		TweakDB:SetFlat(TweakDBID.new(fromPath..".entityTemplatePath"), toTemplate)
	end

	TweakDB:Update(TweakDBID.new(fromPath))
end

return Swap
