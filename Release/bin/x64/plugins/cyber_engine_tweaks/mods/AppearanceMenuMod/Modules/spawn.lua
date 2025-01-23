Spawn = {}

local _entitySystem
local function getEntitySystem()
	_entitySystem = _entitySystem or Game.GetDynamicEntitySystem()
	return _entitySystem
end

local inspect = require("External/Inspect.lua")

function Spawn:NewSpawn(name, id, parameters, companion, path, template, rig)

	local obj = {}
	if type(id) == 'userdata' then id = tostring(id) end

	obj.name = name
	obj.appearanceName = (parameters or {}).app or "random"
	obj.template = template
	obj.handle = nil
	obj.entitySpec = DynamicEntitySpec.new()

	obj.entitySpec.persistState = false
	obj.entitySpec.persistSpawn = false
	obj.entitySpec.alwaysSpawned = false
	obj.entitySpec.spawnInView = true

	obj.id = id
	obj.parameters = parameters
	obj.canBeCompanion = intToBool(companion or 0)
	obj.path = path
	obj.rig = rig or nil
	obj.type = 'Spawn'

	if string.find(obj.path, "Props") then
		obj.type = 'Prop'
	end

	if obj.parameters == "Player" then
		playerGender = playerGender or Util:GetPlayerGender()
		obj.rig = playerGender == "_Female" and 'woman_base' or 'man_base'
		obj.path = path..playerGender
		obj.parameters = nil
	end

	obj = Entity:new(obj)

	return obj
end

function Spawn:new()

  -- Main Properties
  Spawn.categories = Spawn:GetCategories()
  Spawn.entities = {}
  Spawn.spawnedNPCs = {}
  Spawn.searchQuery = ''
  Spawn.searchBarWidth = 500
  Spawn.currentSpawnedID = nil
  Spawn.entitiesForRespawn = {}

  -- Modal Popup Properties --
  Spawn.currentFavoriteName = ''
  Spawn.popupEntity = ''

  return Spawn
end

function Spawn:Initialize()
	Spawn.categories = Spawn:GetCategories()

	if #Spawn.entitiesForRespawn == 0 then return end
	Spawn.spawnedNPCs = {}
	for _, ent in pairs(AMM:GetSavedSpawnData(Spawn.entitiesForRespawn)) do
		local spawn = AMM.Spawn:NewSpawn(ent.entity_name, ent.entity_id, ent.parameters, ent.can_be_comp, ent.entity_path, ent.template_path, ent.entity_rig)
		Spawn.spawnedNPCs[spawn.uniqueName()] = spawn
	end
end

local _style
function Spawn:Draw(AMM, style)
   _style = style or _style
  if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameSpawn")) then

    if AMM.playerInMenu and not AMM.playerInPhoto then
      AMM.UI:TextColored(AMM.LocalizableString("Warn_PlayerInMenu"))
      ImGui.Text(AMM.LocalizableString("Warn_SpawnWorksInGame"))
    else
      Spawn:DrawActiveSpawns(_style)

      if not AMM.playerInPhoto then
        Spawn:DrawCategories(_style)
      end
    end

    ImGui.EndTabItem()
  end
end

function Spawn:DrawActiveSpawns(style)
  if next(Spawn.spawnedNPCs) ~= nil then
    AMM.UI:TextColored(AMM.LocalizableString("Active_Spawns"))

    for _, spawn in pairs(Spawn.spawnedNPCs) do
      local nameLabel = spawn.name

	  local isVehicle = (spawn.handle or {}).isVehicle and spawn.handle:isVehicle()

	  if Tools.lockTarget and Tools.currentTarget ~= '' and Tools.currentTarget.handle then
        if nameLabel == Tools.currentTarget.name then
          AMM.UI:TextColored(nameLabel)
        else
          ImGui.Text(nameLabel)
        end
      else
        ImGui.Text(nameLabel)
      end

      -- Spawned NPC Actions --
      local favoritesLabels = {AMM.LocalizableString("Label_Favorite"), AMM.LocalizableString("Label_Unfavorite")}
      Spawn:DrawFavoritesButton(favoritesLabels, spawn)

      ImGui.SameLine()
      if spawn and spawn.handle and spawn.handle ~= '' and not(isVehicle) then
        if AMM.UI:SmallButton(AMM.LocalizableString("Button_SmallRespawn").."##"..spawn.name) then
          Spawn:Respawn(Entity:new(spawn))
        end
      end

      ImGui.SameLine()
		local qm = AMM.player:GetQuickSlotsManager()
		local mountedVehicle = qm:GetVehicleObject()

		if spawn.handle then
			if not(mountedVehicle and mountedVehicle:GetEntityID().hash == spawn.handle:GetEntityID().hash) then
				if AMM.UI:SmallButton(AMM.LocalizableString("Button_SmallDespawn").."##"..spawn.name) then					
					spawn:Despawn()
				end
			end
		end


      if spawn.handle then
        ImGui.SameLine()
        if AMM.UI:SmallButton(AMM.LocalizableString("Button_SmallTarget").."##"..spawn.name) then
          AMM.Tools:SetCurrentTarget(spawn)
          AMM.Tools.lockTarget = true
        end
      end

      if spawn.handle and not(spawn.handle:IsVehicle()) and not(spawn.handle:IsDevice()) and not(spawn.handle:IsDead()) and Util:CanBeHostile(spawn) then

			local hostileButtonLabel = AMM.LocalizableString("Button_LabelHostile")
			if not(spawn.handle.isPlayerCompanionCached) then
				hostileButtonLabel = AMM.LocalizableString("Button_LabelFriendly")
			end

			ImGui.SameLine()
			if AMM.UI:SmallButton(hostileButtonLabel.."##"..spawn.name) then
				Spawn:ToggleHostile(spawn)
			end

        ImGui.SameLine()
        if AMM.UI:SmallButton(AMM.LocalizableString("Button_SmallEquipment").."##"..spawn.name) then
          popupDelegate = AMM:OpenPopup(spawn.name.."'s Equipment")
        end

        AMM:BeginPopup(spawn.name.."'s Equipment", spawn, false, popupDelegate, style)
      end
    end

    AMM.UI:Separator()
  elseif AMM.playerInPhoto then
    ImGui.NewLine()
    ImGui.Text(AMM.LocalizableString("NoActiveSpawns"))
    ImGui.NewLine()
  end
end

function Spawn:DrawCategories(style)
  ImGui.PushItemWidth(Spawn.searchBarWidth)
  Spawn.searchQuery = ImGui.InputTextWithHint(" ", AMM.LocalizableString("Search"), Spawn.searchQuery, 100)
  Spawn.searchQuery = Spawn.searchQuery:gsub('"', '')
  ImGui.PopItemWidth()

  if Spawn.searchQuery ~= '' then
    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Clear")) then
      Spawn.searchQuery = ''
    end
  end

  ImGui.Spacing()

  AMM.UI:TextColored(AMM.LocalizableString("Select_To_Spawn"))

  local validCatIDs = Util:GetAllCategoryIDs(Spawn.categories)
  if Spawn.searchQuery ~= '' then
    local entities = {}
	 local parsedSearch = Util:ParseSearch(Spawn.searchQuery, "entity_name")
    local query = 'SELECT * FROM entities WHERE is_spawnable = 1 AND cat_id IN '..validCatIDs..' AND '..parsedSearch..' ORDER BY entity_name ASC'
    for en in db:nrows(query) do
      table.insert(entities, en)
    end

    if #entities ~= 0 then
      Spawn:DrawEntitiesButtons(entities, 'ALL', style)
    else
      ImGui.Text(AMM.LocalizableString("No_Results"))
    end
  else
    local x, y = GetDisplayResolution()
    if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y / 2) then
      for _, category in ipairs(Spawn.categories) do
			local entities = {}

			if Spawn.entities[category] == nil or category.cat_name == 'Favorites' then
				if category.cat_name == 'Favorites' then
					local query = "SELECT * FROM favorites"
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
							ImGui.Text(AMM.LocalizableString("ItsEmpty"))
						end
					end
				else
					local query = f("SELECT * FROM entities WHERE is_spawnable = 1 AND cat_id == \"%s\" ORDER BY entity_name ASC", category.cat_id)
					for en in db:nrows(query) do
						table.insert(entities, en)
					end
				end

				Spawn.entities[category] = entities
			end

			if Spawn.entities[category] ~= nil and #Spawn.entities[category] ~= 0 then
				local headerFlag = ImGuiTreeNodeFlags.None
				if AMM.userSettings.favoritesDefaultOpen and category == 'Favorites' then headerFlag = ImGuiTreeNodeFlags.DefaultOpen end
        		if ImGui.CollapsingHeader(category.cat_name, headerFlag) then
					Spawn:DrawEntitiesButtons(Spawn.entities[category], category.cat_name, style)
				end
      	end
      end
    end

    ImGui.EndChild()
  end
end

function Spawn:DrawEntitiesButtons(entities, categoryName, style)

	AMM.UI:List(categoryName, #entities, style.buttonHeight, function(i)
		local en = entities[i]
		local name = en.entity_name
		local id = en.entity_id
		local path = en.entity_path
		local rig = en.entity_rig
		local companion = en.can_be_comp
		local parameters = en.parameters
		local template = en.template_path

		local newSpawn = Spawn:NewSpawn(name, id, parameters, companion, path, template, rig)
		local uniqueName = newSpawn.uniqueName()
		local buttonLabel = uniqueName..tostring(i)

		local favOffset = 0
		local currentIndex = 0
		local favoriteType = 'favorites'
		if string.find(tostring(newSpawn.path), "Props") then
			favoriteType = 'favorites_props'
		end

		if categoryName == 'Favorites' then
			for index in db:urows(f('SELECT position FROM %s WHERE entity_name = "%s"', favoriteType, name)) do
				currentIndex = index
			end
		end

		if categoryName == 'Favorites' then
			favOffset = 50
			Spawn:DrawArrowButton("up", newSpawn, currentIndex)
			ImGui.SameLine()
		end

		local isFavorite = 0
		for fav in db:urows(f("SELECT COUNT(1) FROM %s WHERE entity_id = '%s'", favoriteType, id)) do
			isFavorite = fav
		end

		if Spawn.spawnedNPCs[newSpawn.uniqueName()] and AMM:IsUnique(newSpawn.id) then
			ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
			AMM:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, "Disabled", nil)
			ImGui.PopStyleColor(3)
		elseif not(Spawn.spawnedNPCs[newSpawn.uniqueName()] ~= nil and AMM:IsUnique(newSpawn.id)) then
			local action = "SpawnNPC"
			if string.find(tostring(newSpawn.path), "Vehicle") then action = "SpawnVehicle" end
			if string.find(tostring(newSpawn.path), "Props") then action = "SpawnProp" end
			AMM:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, action, newSpawn)
		end

		if categoryName == 'Favorites' then
			ImGui.SameLine()
			Spawn:DrawArrowButton("down", newSpawn, currentIndex)
		end
	end)
end

function Spawn:SetFavoriteNamePopup(entity)
	local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
	ImGui.SetNextWindowSize(350, ImGui.GetFontSize() * 9)
	Spawn.currentFavoriteName = entity.name
	Spawn.popupEntity = entity
	ImGui.OpenPopup("Favorite Name")
end

function Spawn:DrawFavoritesButton(buttonLabels, entity, fullButton)
	local style = {
		buttonWidth = -1,
		buttonHeight = ImGui.GetFontSize() * 2,
		halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12)
	}

	local favoriteType = "favorites"
	if entity.type == "Prop" or entity.type == "entEntity" then
		favoriteType = "favorites_props"
	end

	if entity.parameters == nil and not Util:CheckVByID(entity.id) then
		entity['parameters'] = entity.appearance
	end

	local isFavorite = 0
	for fav in db:urows(f('SELECT COUNT(1) FROM %s WHERE entity_name = "%s"', favoriteType, entity.name)) do
		isFavorite = fav
	end
	if isFavorite == 0 and entity.parameters ~= nil then
		for fav in db:urows(f("SELECT COUNT(1) FROM %s WHERE parameters = '%s'", favoriteType, entity.parameters)) do
			isFavorite = fav
		end
	end

	local favoriteButtonLabel = buttonLabels[1].."##"..entity.name
	if isFavorite ~= 0 then
		favoriteButtonLabel = buttonLabels[2].."##"..entity.name
	end

	local button
	if fullButton then
		button = ImGui.Button(favoriteButtonLabel, style.buttonWidth, style.buttonHeight)
	else
		button = AMM.UI:SmallButton(favoriteButtonLabel)
	end

	if button then
		if not(AMM:IsUnique(entity.id)) and isFavorite == 0 then
			Spawn:SetFavoriteNamePopup(entity)
		else
			Spawn:ToggleFavorite(favoriteType, isFavorite, entity)
		end
	end

	if ImGui.BeginPopupModal("Favorite Name") then
		if Spawn.currentFavoriteName == 'existing' then
			ImGui.TextColored(1, 0.16, 0.13, 0.75, AMM.LocalizableString("Existing_Name"))

			if ImGui.Button("Ok", -1, style.buttonHeight) then
				Spawn.currentFavoriteName = ''
			end
		elseif Spawn.popupEntity.name == entity.name then
			Spawn.currentFavoriteName = ImGui.InputText(AMM.LocalizableString("Name"), Spawn.currentFavoriteName, 30)

			if ImGui.Button(AMM.LocalizableString("Button_Save"), style.halfButtonWidth + 8, style.buttonHeight) then
				local isFavorite = 0
				for fav in db:urows(f('SELECT COUNT(1) FROM %s WHERE entity_name = "%s"', favoriteType, Spawn.currentFavoriteName)) do
					isFavorite = fav
				end
				if isFavorite == 0 then
					local newEntity = Entity:new(entity)
					newEntity.name = Spawn.currentFavoriteName
					
					if (entity.type == "Spawn" or entity.type == "NPCPuppet") and not Util:CheckVByID(entity.id) then
						newEntity.parameters = AMM:GetScanAppearance(entity.handle)

						if entity.type == "Spawn" then
							Spawn.spawnedNPCs[entity.uniqueName()] = nil
							Spawn.spawnedNPCs[newEntity.uniqueName()] = newEntity
						end
					end

					Spawn.currentFavoriteName = ''
					Spawn:ToggleFavorite(favoriteType, isFavorite, newEntity)
					AMM.popupIsOpen = false
					ImGui.CloseCurrentPopup()
				else
					Spawn.currentFavoriteName = 'existing'
				end
			end

			if ImGui.Button(AMM.LocalizableString("Button_Cancel"), style.halfButtonWidth + 8, style.buttonHeight) then
				Spawn.currentFavoriteName = ''
				AMM.popupIsOpen = false
				ImGui.CloseCurrentPopup()
			end
		end
		ImGui.EndPopup()
	end
end

function Spawn:DrawArrowButton(direction, entity, index)
	-- Decide which table to use based on entity type
	local favoriteType = (entity.type == "Prop" or entity.type == "entEntity")
		 and "favorites_props"
		 or "favorites"

	-- Determine which ImGui arrow to draw, and what the new target index would be
	local dirEnum = (direction == "up") and ImGuiDir.Up or ImGuiDir.Down
	local tempPos = (direction == "up") and (index - 1) or (index + 1)

	-- Get the total number of favorites so we can clamp positions correctly
	local favoritesCount = 0
	for count in db:urows(string.format("SELECT COUNT(1) FROM %s", favoriteType)) do
		 favoritesCount = count
	end

	if ImGui.ArrowButton(direction .. entity.id, dirEnum) then
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
							 SET entity_id   = '%s',
								  entity_name = '%s',
								  parameters  = "%s"
						  WHERE position    = %d
					]],
					favoriteType,
					currentRow.entity_id or "NULL",
					currentRow.entity_name or "NULL",
					currentRow.parameters or "NULL",
					tempPos)
					update1 = update1:gsub('"nil"', "NULL")  -- fix "nil" => "NULL"

					-- Swap: move the swapRow data into the 'index' slot
					local update2 = string.format([[
						 UPDATE %s
							 SET entity_id   = '%s',
								  entity_name = '%s',
								  parameters  = "%s"
						  WHERE position    = %d
					]],
					favoriteType,
					swapRow.entity_id or "NULL",
					swapRow.entity_name or "NULL",
					swapRow.parameters or "NULL",
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

-- End of Draw Methods

-- Main Methods
function Spawn:SpawnVehicle(spawn)

	local entitySystem = getEntitySystem()

	spawn.entitySpec.recordID = spawn.path
	spawn.entitySpec.tags = { "AMM_CAR" }
	spawn.entitySpec.position = Util:GetPosition(5.5, 0.0)
	spawn.entitySpec.orientation = Util:GetOrientation(90.0)
	spawn.entityID = getEntitySystem():CreateEntity(spawn.entitySpec)

	local timerfunc = function(timer)
		local entity = Game.FindEntityByID(spawn.entityID)
		if entity then
			spawn.handle = entity
			spawn.hash = tostring(entity:GetEntityID().hash)

			Spawn.spawnedNPCs[spawn.uniqueName()] = spawn
			if spawn.id == "0xE09AAEB8, 26" then
				Game.GetGodModeSystem():AddGodMode(spawn.handle:GetEntityID(), 0, "")
			end

			if spawn.parameters ~= nil then
				AMM:ChangeScanAppearanceTo(spawn, spawn.parameters)
			end

			Util:UnlockVehicle(spawn.handle)
			Cron.Halt(timer)
		end
	end


	Cron.Every(0.3, timerfunc)
end


function Spawn:Respawn(spawn, notCompanionOverride)
	spawn:Despawn()

	Cron.After(0.5, function()
		Spawn:SpawnNPC(spawn)
	end)
end

function Spawn:SpawnFavorite()
  local favorites = {}
  for ent in db:nrows("SELECT * FROM entities WHERE entity_id IN (SELECT entity_id FROM favorites)") do
    table.insert(favorites, Spawn:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path, ent.entity_rig))
  end

  for _, spawn in ipairs(favorites) do
    local spawned = false
    for _, ent in pairs(Spawn.spawnedNPCs) do
      if spawn.uniqueName() == ent.uniqueName() then
        spawned = true
        break
      end
    end

    if not spawned then
      Spawn:SpawnNPC(spawn)
      break
    end
  end
end

function Spawn:SpawnNPC(spawn, notCompanionOverride)
	local custom = {}
	if spawn.parameters ~= nil then
		custom = AMM:GetCustomAppearanceParams(spawn, spawn.parameters)
	end

	if AMM.userSettings.weaponizeNPC and not Util:CanBeHostile(spawn) and not Spawn:IsWeaponizeBlacklisted(spawn) then
		TweakDB:SetFlat(spawn.path..".abilities", TweakDB:GetFlat("Character.Judy.abilities"))
		TweakDB:SetFlat(spawn.path..".primaryEquipment", TweakDB:GetFlat("Character.Judy.primaryEquipment"))
		TweakDB:SetFlat(spawn.path..".secondaryEquipment", TweakDB:GetFlat("Character.Judy.secondaryEquipment"))
		TweakDB:SetFlat(spawn.path..".archetypeData", TweakDB:GetFlat("Character.Judy.archetypeData"))
	end

	local path = spawn.path
	if string.find(path, "0x") then
		path = loadstring("return TweakDBID.new("..spawn.path..")", '')()
	end

	spawn.entitySpec.recordID = TweakDBID.new(path)
	spawn.entitySpec.tags = { "AMM_NPC" }
	spawn.entitySpec.position = Util:GetPosition(1, 0)
	spawn.entitySpec.orientation = Util:GetOrientation(-180)

	-- Simple exception when spawning Chimera because it's so big
	if spawn.id == "0xF676721C, 31" then
		spawn.entitySpec.position = Util:GetPosition(6, 0)
	end

	spawn.entityID = getEntitySystem():CreateEntity(spawn.entitySpec)

	while Spawn.spawnedNPCs[spawn.uniqueName()] ~= nil do
		local num = spawn.name:match("|([^|]+)")
		if num then num = tonumber(num) + 1 else num = 1 end
		spawn.name = spawn.name:gsub(" | "..tostring(num - 1), "")
		spawn.name = spawn.name.." | "..tostring(num)
	end

	local timerFunc = function(timer)

		timer.tick = timer.tick + 1

		if timer.tick > 30 then
			Cron.Halt(timer)
		end

		local entity = Game.FindEntityByID(spawn.entityID)
		if entity then
			spawn.handle = entity
			spawn.hash = tostring(entity:GetEntityID().hash)
			spawn.appearance = AMM:GetAppearance(spawn)
			spawn.archetype = Game.NameToString(TweakDB:GetFlat(spawn.path..".archetypeName"))

			Spawn.spawnedNPCs[spawn.uniqueName()] = spawn

			if not Util:CheckVByID(spawn.id) then
				if AMM.userSettings.streamerMode and AMM:CheckAppearanceForBannedWords(spawn.appearance) then
					AMM:ChangeScanAppearanceTo(spawn, 'Cycle')
				elseif (#custom > 0 or spawn.parameters ~= nil) then
					AMM:ChangeAppearanceTo(spawn, spawn.parameters)
				else
					AMM:ChangeScanAppearanceTo(spawn, 'Cycle')
				end
			end

			Cron.After(0.2, function()
				if AMM.userSettings.autoLock then
					AMM.Tools.lockTarget = true
					AMM.Tools:SetCurrentTarget(spawn)

					if AMM.userSettings.floatingTargetTools and AMM.userSettings.autoOpenTargetTools then
						AMM.Tools.movementWindow.isEditing = true
					end
				end
			end)

			if AMM.userSettings.spawnAsCompanion and spawn.canBeCompanion and not notCompanionOverride then
				Spawn:SetNPCAsCompanion(spawn.handle)
			elseif AMM.userSettings.spawnAsFriendly then
				AMM.Tools:SetNPCAttitude(spawn, EAIAttitude.AIA_Friendly)
			end

			AMM:UpdateSettings()
			Cron.Halt(timer)
		end
	end

  	Cron.Every(0.2, {tick = 1}, timerFunc)
end

function Spawn:DespawnVehicle(ent)
	Spawn.spawnedNPCs[ent.uniqueName()] = nil
	AMM:UpdateSettings()
end

function Spawn:DespawnNPC(ent)
	Spawn.spawnedNPCs[ent.uniqueName()] = nil
	AMM:UpdateSettings()
end

function Spawn:DespawnAll()

  for _, ent in pairs(Spawn.spawnedNPCs) do
	ent:Despawn()
  end

  Spawn.spawnedNPCs = {}
  AMM:UpdateSettings()
end

function Spawn:SetNPCAsCompanion(targetPuppet)
	Util:SetGodMode(targetPuppet, AMM.userSettings.isCompanionInvulnerable)
	
	local npcManager = targetPuppet.NPCManager
	npcManager:ScaleToPlayer()

	local currentRole = targetPuppet:GetAIControllerComponent():GetAIRole()

	if currentRole then
		if targetPuppet:IsCrowd() and currentRole:IsA('AIFollowerRole') then
			return true
		end
		
		currentRole:OnRoleCleared(targetPuppet)
	end

	if targetPuppet.isPlayerCompanionCached == false then
		local followerRole = AIFollowerRole.new()
		followerRole.followerRef = Game.CreateEntityReference("#player", {})

		targetPuppet:GetAIControllerComponent():SetAIRole(followerRole)
		targetPuppet:GetAIControllerComponent():OnAttach()

		local player = Game.GetPlayer()
		targetPuppet:GetAttitudeAgent():SetAttitudeGroup(player:GetAttitudeAgent():GetAttitudeGroup())
		targetPuppet:GetAttitudeAgent():SetAttitudeTowards(player:GetAttitudeAgent(), EAIAttitude.AIA_Friendly)

		for _, ent in pairs(Spawn.spawnedNPCs) do
			local isInPlayerGroup = player:GetAttitudeAgent():GetAttitudeGroup() == ent.handle:GetAttitudeAgent():GetAttitudeGroup()
			if ent.handle.IsNPC and ent.handle:IsNPC() then
				if isInPlayerGroup then
					ent.handle:GetAttitudeAgent():SetAttitudeTowards(targetPuppet:GetAttitudeAgent(), EAIAttitude.AIA_Friendly)
				else
					ent.handle:GetAttitudeAgent():SetAttitudeTowards(targetPuppet:GetAttitudeAgent(), EAIAttitude.AIA_Hostile)
				end
			end
		end

		targetPuppet.isPlayerCompanionCached = true
		targetPuppet.isPlayerCompanionCachedTimeStamp = 0

		AMM:UpdateFollowDistance()
	end
end


function Spawn:ToggleHostile(ent)
	local targetPuppet = ent.handle
	local currentRole = targetPuppet:GetAIControllerComponent():GetAIRole()

	Util:SetGodMode(targetPuppet, false)

	if targetPuppet.isPlayerCompanionCached then
		if targetPuppet:IsCrowd() then
			Spawn:Respawn(ent, true) -- Crowd NPCs can't change roles more than once; Respawn as non companion instead.

			Cron.After(2.0, function()
				Util:SetHostileRole(ent.handle)
			end)
		else
			currentRole:OnRoleCleared(targetPuppet)
			Util:SetHostileRole(targetPuppet)
		end
	else
		Spawn:SetNPCAsCompanion(targetPuppet)
	end
end

function Spawn:ToggleFavorite(favoriteType, isFavorite, entity)
	if isFavorite == 0 then
		local parameters = entity.parameters
		if favoriteType == "favorites_props" then parameters = "Prop" end
		local command = f('INSERT INTO %s (entity_id, entity_name, parameters) VALUES ("%s", "%s", "%s")', favoriteType, entity.id, entity.name, parameters)
		command = command:gsub('"nil"', "NULL")
		db:execute(command)
	else
		local removedIndex = 0
		local query = f('SELECT position FROM %s WHERE entity_name = "%s"', favoriteType, entity.name)
		for i in db:urows(query) do removedIndex = i end

		local command = f('DELETE FROM %s WHERE entity_name = "%s"', favoriteType, entity.name)
		db:execute(command)
		Spawn:RearrangeFavoritesIndex(favoriteType, removedIndex)
	end
end

function Spawn:RearrangeFavoritesIndex(favoriteType, removedIndex)
	local lastIndex = 0
	for x in db:urows('SELECT COUNT(1) FROM '..favoriteType) do
		lastIndex = x - 1
	end

	for i = removedIndex, lastIndex do
		db:execute(f("UPDATE %s SET position = %i WHERE position = %i", favoriteType, i, i + 1))
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = '%s'", lastIndex, favoriteType))
end


function Spawn:GetCategories()
	local query = "SELECT * FROM categories WHERE cat_name != 'Props' AND cat_name != 'At Your Own Risk' AND cat_sub IS NULL ORDER BY 3 ASC"
	if AMM.userSettings.experimental then
		query = "SELECT * FROM categories WHERE cat_name != 'Props' AND cat_sub IS NULL ORDER BY 3 ASC"
	end

	local categories = {}
	for category in db:nrows(query) do
		table.insert(categories, {cat_id = category.cat_id, cat_name = category.cat_name})
	end
	return categories
end

function Spawn:IsWeaponizeBlacklisted(ent)
	local blacklist = {
		"0xD47FABFD, 21"
	}

	for _, id in ipairs(blacklist) do
		if id == ent.id then return true end
	end

	return false
end

return Spawn:new()
