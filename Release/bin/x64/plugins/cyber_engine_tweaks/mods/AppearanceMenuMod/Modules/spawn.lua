Spawn = {}

local _entitySystem
local function getEntitySystem()
	_entitySystem = _entitySystem or Game.GetDynamicEntitySystem()
	return _entitySystem
end

local inspect = require("external/Inspect.lua")

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

	-- Check if model is swappedModels
	if AMM.Swap.activeSwaps[obj.id] ~= nil then
		obj.id = AMM.Swap.activeSwaps[obj.id].newID
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
  if ImGui.BeginTabItem("Spawn") then

    if AMM.playerInMenu and not AMM.playerInPhoto then
      AMM.UI:TextColored("Player In Menu")
      ImGui.Text("Spawning only works in game")
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
    AMM.UI:TextColored("Active Spawns ")

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
      local favoritesLabels = {"Favorite", "Unfavorite"}
      Spawn:DrawFavoritesButton(favoritesLabels, spawn)

      ImGui.SameLine()
      if spawn and spawn.handle and spawn.handle ~= '' and not(isVehicle) then
        if AMM.UI:SmallButton("Respawn##"..spawn.name) then
          Spawn:Respawn(spawn)
        end
      end

      ImGui.SameLine()
		local qm = AMM.player:GetQuickSlotsManager()
		local mountedVehicle = qm:GetVehicleObject()

		if spawn.handle then
			if not(mountedVehicle and mountedVehicle:GetEntityID().hash == spawn.handle:GetEntityID().hash) then
				if AMM.UI:SmallButton("Despawn##"..spawn.name) then					
					spawn:Despawn()
				end
			end
		end


      if spawn.handle then
        ImGui.SameLine()
        if AMM.UI:SmallButton("Target".."##"..spawn.name) then
          AMM.Tools:SetCurrentTarget(spawn)
          AMM.Tools.lockTarget = true
        end
      end

      if spawn.handle and not(spawn.handle:IsVehicle()) and not(spawn.handle:IsDevice()) and not(spawn.handle:IsDead()) and Util:CanBeHostile(spawn) then

			local hostileButtonLabel = "Hostile"
			if not(spawn.handle.isPlayerCompanionCached) then
				hostileButtonLabel = "Friendly"
			end

			ImGui.SameLine()
			if AMM.UI:SmallButton(hostileButtonLabel.."##"..spawn.name) then
				Spawn:ToggleHostile(spawn)
			end

        ImGui.SameLine()
        if AMM.UI:SmallButton("Equipment".."##"..spawn.name) then
          popupDelegate = AMM:OpenPopup(spawn.name.."'s Equipment")
        end

        AMM:BeginPopup(spawn.name.."'s Equipment", spawn.path, false, popupDelegate, style)		  
      end
    end

    AMM.UI:Separator()
  elseif AMM.playerInPhoto then
    ImGui.NewLine()
    ImGui.Text("No Active Spawns")
    ImGui.NewLine()
  end
end

function Spawn:DrawCategories(style)
  ImGui.PushItemWidth(Spawn.searchBarWidth)
  Spawn.searchQuery = ImGui.InputTextWithHint(" ", "Search", Spawn.searchQuery, 100)
  Spawn.searchQuery = Spawn.searchQuery:gsub('"', '')
  ImGui.PopItemWidth()

  if Spawn.searchQuery ~= '' then
    ImGui.SameLine()
    if ImGui.Button("Clear") then
      Spawn.searchQuery = ''
    end
  end

  ImGui.Spacing()

  AMM.UI:TextColored("Select To Spawn:")

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
      ImGui.Text("No Results")
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
							ImGui.Text("It's empty :(")
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

		if Spawn.spawnedNPCs[uniqueName] and AMM:IsUnique(newSpawn.id) then
			ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
			AMM:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, "Disabled", nil)
			ImGui.PopStyleColor(3)
		elseif not(Spawn.spawnedNPCs[uniqueName] ~= nil and AMM:IsUnique(newSpawn.id)) then
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
			ImGui.TextColored(1, 0.16, 0.13, 0.75, "Existing Name")

			if ImGui.Button("Ok", -1, style.buttonHeight) then
				Spawn.currentFavoriteName = ''
			end
		elseif Spawn.popupEntity.name == entity.name then
			Spawn.currentFavoriteName = ImGui.InputText("Name", Spawn.currentFavoriteName, 30)

			if ImGui.Button("Save", style.halfButtonWidth + 8, style.buttonHeight) then
				local isFavorite = 0
				for fav in db:urows(f('SELECT COUNT(1) FROM %s WHERE entity_name = "%s"', favoriteType, Spawn.currentFavoriteName)) do
					isFavorite = fav
				end
				if isFavorite == 0 then
					entity.name = Spawn.currentFavoriteName

					if entity.type == "Spawn" and not Util:CheckVByID(entity.id) then
						Spawn.spawnedNPCs[entity.uniqueName()] = nil
						entity.parameters = AMM:GetScanAppearance(entity.handle)
						Spawn.spawnedNPCs[entity.uniqueName()] = entity
					end

					Spawn.currentFavoriteName = ''
					Spawn:ToggleFavorite(favoriteType, isFavorite, entity)
					AMM.popupIsOpen = false
					ImGui.CloseCurrentPopup()
				else
					Spawn.currentFavoriteName = 'existing'
				end
			end

			if ImGui.Button("Cancel", style.halfButtonWidth + 8, style.buttonHeight) then
				Spawn.currentFavoriteName = ''
				AMM.popupIsOpen = false
				ImGui.CloseCurrentPopup()
			end
		end
		ImGui.EndPopup()
	end
end

function Spawn:DrawArrowButton(direction, entity, index)
	local favoriteType = "favorites"
	if entity.type == "Prop" or entity.type == "entEntity" then
		favoriteType = "favorites_props"
	end

	local dirEnum, tempPos
	if direction == "up" then
		dirEnum = ImGuiDir.Up
		tempPos = index - 1
	else
		dirEnum = ImGuiDir.Down
		tempPos = index + 1
	end

	local favoritesLength = 0
	local query = "SELECT COUNT(1) FROM "..favoriteType
	for x in db:urows(query) do favoritesLength = x end

	if ImGui.ArrowButton(direction..entity.id, dirEnum) then
		if not(tempPos < 1 or tempPos > favoritesLength) then
			local query = f("SELECT * FROM %s WHERE position = %i", favoriteType, tempPos)
			for fav in db:nrows(query) do temp = fav end

			db:execute(f("UPDATE %s SET entity_id = '%s', entity_name = '%s', parameters = \"%s\" WHERE position = %i", favoriteType, entity.id, entity.name, entity.parameters, tempPos))
			db:execute(f("UPDATE %s SET entity_id = '%s', entity_name = '%s', parameters = \"%s\" WHERE position = %i", favoriteType, temp.entity_id, temp.entity_name, temp.parameters, index))
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

	-- local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	-- vehicleGarageId.recordID = TweakDBID.new(spawn.path)
	-- Game.GetVehicleSystem():ToggleSummonMode()
	-- Game.GetVehicleSystem():TogglePlayerActiveVehicle(vehicleGarageId, 'Car', true)
	-- Game.GetVehicleSystem():SpawnPlayerVehicle('Car')
	-- Game.GetVehicleSystem():ToggleSummonMode()

	-- Cron.Every(0.1, function(timer)
	-- 	local vehicleSummonDef = Game.GetAllBlackboardDefs().VehicleSummonData
	-- 	local vehicleSummonBB = Game.GetBlackboardSystem():Get(vehicleSummonDef)
	-- 	local vehicleEntID = vehicleSummonBB:GetEntityID(vehicleSummonDef.SummonedVehicleEntityID)

	-- 	spawn.handle = Game.FindEntityByID(vehicleEntID)

	-- 	if spawn.handle then

	-- 		Cron.After(0.2, function()
	-- 			local floatFix = 1
	-- 			if type(spawn.parameters) == "number" then floatFix = 0 end
				
	-- 			local pos = spawn.handle:GetWorldPosition()
	-- 			local angles = GetSingleton('Quaternion'):ToEulerAngles(spawn.handle:GetWorldOrientation())
	-- 			local teleportPosition = Vector4.new(pos.x, pos.y, pos.z - floatFix, pos.w)
	-- 			Game.GetTeleportationFacility():Teleport(spawn.handle, teleportPosition, angles)
	-- 		end)

	-- 		Spawn.spawnedNPCs[spawn.uniqueName] = spawn
    --   	Util:UnlockVehicle(spawn.handle)

	-- 		if spawn.id == "0xE09AAEB8, 26" then
	-- 			Game.GetGodModeSystem():AddGodMode(spawn.handle:GetEntityID(), 0, "")
	-- 		end

	-- 		if spawn.parameters ~= nil then
	-- 			AMM:ChangeScanAppearanceTo(spawn, spawn.parameters)
	-- 		end

	-- 		local components = AMM.Props:CheckForValidComponents(spawn.handle)
	-- 		if components then
	-- 			spawn.defaultScale = {
	-- 				x = components[1].visualScale.x * 100,
	-- 				y = components[1].visualScale.x * 100,
	-- 				z = components[1].visualScale.x * 100,
	-- 			}
	-- 			spawn.scale = {
	-- 				x = components[1].visualScale.x * 100,
	-- 				y = components[1].visualScale.y * 100,
	-- 				z = components[1].visualScale.z * 100,
	-- 			}
	-- 		end

	-- 		Cron.Halt(timer)
	-- 	end
	-- end)
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

			if AMM.userSettings.streamerMode and AMM:CheckAppearanceForBannedWords(spawn.appearance) then
				AMM:ChangeScanAppearanceTo(spawn, 'Cycle')
			elseif (#custom > 0 or spawn.parameters ~= nil) and not Util:CheckVByID(spawn.id) then
				AMM:ChangeAppearanceTo(spawn, spawn.parameters)
			elseif not Util:CheckVByID(spawn.id) then
				AMM:ChangeScanAppearanceTo(spawn, 'Cycle')
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

	-- local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	-- vehicleGarageId.recordID = TweakDBID.new(ent.path)
	-- Game.GetVehicleSystem():DespawnPlayerVehicle(vehicleGarageId)

	-- New system below

	-- local handle = Game.FindEntityByID(ent.entityID)
	-- if handle then
	-- 	if handle:IsVehicle() then
	-- 		Util:TeleportTo(handle, Util:GetBehindPlayerPosition(2))
	-- 	end
	-- end

	-- Game.GetPreventionSpawnSystem():RequestDespawn(ent.entityID)
	-- ent.handle:Dispose()
	-- AMM:UpdateSettings()
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
			if ent.handle.IsNPC and ent.handle:IsNPC() then
				ent.handle:GetAttitudeAgent():SetAttitudeTowards(targetPuppet:GetAttitudeAgent(), EAIAttitude.AIA_Friendly)
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
		lastIndex = x
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
