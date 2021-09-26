Spawn = {}

function Spawn:NewSpawn(name, id, parameters, companion, path, template)
  local obj = {}
	if type(id) == 'userdata' then id = tostring(id) end
	obj.handle = ''
	obj.name = name
	obj.id = id
	obj.hash = ''
  	obj.appearance = ''
	obj.uniqueName = function() return obj.name.."##"..obj.id end
	obj.parameters = parameters
	obj.canBeCompanion = intToBool(companion or 0)
	obj.path = path
	obj.template = template or ''
	obj.type = 'Spawn'
	obj.entityID = ''

	if string.find(obj.path, "Props") then
		obj.type = 'Props'
	end

	if obj.parameters == "Player" then
		obj.path = path..Util:GetPlayerGender()
		obj.parameters = nil
	end
	return obj
end

function Spawn:new()

  -- Main Properties
  Spawn.categories = Spawn:GetCategories()
  Spawn.spawnedNPCs = {}
  Spawn.searchQuery = ''
  Spawn.searchBarWidth = 500

  -- Modal Popup Properties --
  Spawn.currentFavoriteName = ''
  Spawn.popupEntity = ''

  return Spawn
end

function Spawn:Draw(AMM, style)
  if ImGui.BeginTabItem("Spawn") then

    if AMM.playerInMenu and not AMM.playerInPhoto then
      AMM.UI:TextColored("Player In Menu")
      ImGui.Text("Spawning only works in game")
    else
      Spawn:DrawActiveSpawns(style)

      if not AMM.playerInPhoto then
        Spawn:DrawCategories(style)
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

	  if Tools.lockTarget and Tools.currentNPC ~= '' and Tools.currentNPC.handle then
        if nameLabel == Tools.currentNPC.name then
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
      if spawn.handle ~= '' and not(spawn.handle:IsVehicle()) then
        if ImGui.SmallButton("Respawn##"..spawn.name) then
          Spawn:DespawnNPC(spawn)
          Cron.After(0.2, function()
            Spawn:SpawnNPC(spawn)
          end)
        end
      end

      ImGui.SameLine()
      if ImGui.SmallButton("Despawn##"..spawn.name) then
        if spawn.handle ~= '' and spawn.handle:IsVehicle() then
          Spawn:DespawnVehicle(spawn)
        elseif spawn.handle ~= '' then
          Spawn:DespawnNPC(spawn)
        end
      end


      if spawn.handle ~= '' then
        ImGui.SameLine()
        if ImGui.SmallButton("Target".."##"..spawn.name) then

          AMM.Tools:SetCurrentTarget(spawn)
          AMM.Tools.lockTarget = true
        end
      end

      if spawn.handle ~= '' and not(spawn.handle:IsVehicle()) and not(spawn.handle:IsDevice()) and not(spawn.handle:IsDead()) and Util:CanBeHostile(spawn.handle) then

		if AMM.userSettings.spawnAsCompanion then
			local hostileButtonLabel = "Hostile"
			if not(spawn.handle.isPlayerCompanionCached) then
			hostileButtonLabel = "Friendly"
			end

			ImGui.SameLine()
			if ImGui.SmallButton(hostileButtonLabel.."##"..spawn.name) then
			Spawn:ToggleHostile(spawn.handle)
			end
		end

        ImGui.SameLine()
        if ImGui.SmallButton("Equipment".."##"..spawn.name) then
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
    local query = 'SELECT * FROM entities WHERE is_spawnable = 1 AND cat_id IN '..validCatIDs..' AND entity_name LIKE "%'..Spawn.searchQuery..'%" ORDER BY entity_name ASC'
    for en in db:nrows(query) do
      table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path, en.template_path})
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
         if category.cat_name == 'Favorites' then
         	local query = "SELECT * FROM favorites"
            for fav in db:nrows(query) do
              query = f("SELECT * FROM entities WHERE entity_id = '%s' AND cat_id IN %s", fav.entity_id, validCatIDs)
              for en in db:nrows(query) do
                if fav.parameters ~= nil then en.parameters = fav.parameters end
                table.insert(entities, {fav.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path, en.template_path})
              end
            end
            if #entities == 0 then
					if ImGui.CollapsingHeader(category.cat_name) then
            		ImGui.Text("It's empty :(")
					end
            end
         end

         local query = f("SELECT * FROM entities WHERE is_spawnable = 1 AND cat_id == '%s' ORDER BY entity_name ASC", category.cat_id)
         for en in db:nrows(query) do
         	table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path, en.template_path})
         end

			if #entities ~= 0 then
        		if ImGui.CollapsingHeader(category.cat_name) then
					Spawn:DrawEntitiesButtons(entities, category.cat_name, style)
				end
      	end
      end
    end
    ImGui.EndChild()
  end
end

function Spawn:DrawEntitiesButtons(entities, categoryName, style)

	for i, entity in ipairs(entities) do
		name = entity[1]
		id = entity[2]
		path = entity[5]
		companion = entity[3]
		parameters = entity[4]
		template = entity[6]

		local newSpawn = Spawn:NewSpawn(name, id, parameters, companion, path, template)
		local uniqueName = newSpawn.uniqueName()
		local buttonLabel = uniqueName..tostring(i)

		local favOffset = 0
		if categoryName == 'Favorites' then
			favOffset = 40
			local currentIndex = 0
			for index in db:urows(f("SELECT position FROM favorites WHERE entity_name = '%s'", name)) do
				currentIndex = index
			end

			Spawn:DrawArrowButton("up", newSpawn, currentIndex, i)
			ImGui.SameLine()
		end

		local isFavorite = 0
		for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_id = '%s'", id)) do
			isFavorite = fav
		end

		if Spawn.spawnedNPCs[uniqueName] and isFavorite ~= 0 then
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
			local currentIndex = 0
			for index in db:urows(f("SELECT position FROM favorites WHERE entity_name = '%s'", name)) do
				currentIndex = index
			end

			ImGui.SameLine()
			Spawn:DrawArrowButton("down", newSpawn, currentIndex, i)
		end
	end
end

function Spawn:SetFavoriteNamePopup(entity)
	local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
	ImGui.SetNextWindowSize(400, ImGui.GetFontSize() * 8)
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

	if entity.parameters == nil then
		entity['parameters'] = entity.appearance
	end

	local isFavorite = 0
	for fav in db:urows(f('SELECT COUNT(1) FROM favorites WHERE entity_name = "%s"', entity.name)) do
		isFavorite = fav
	end
	if isFavorite == 0 and entity.parameters ~= nil then
		for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE parameters = '%s'", entity.parameters)) do
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
		button = ImGui.SmallButton(favoriteButtonLabel)
	end

	if button then
		if not(AMM:IsUnique(entity.id)) and isFavorite == 0 then
			Spawn:SetFavoriteNamePopup(entity)
		else
			Spawn:ToggleFavorite(isFavorite, entity)
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
				for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_name = '%s'", Spawn.currentFavoriteName)) do
					isFavorite = fav
				end
				if isFavorite == 0 then
					entity.name = Spawn.currentFavoriteName

					if entity.type == "Props" or entity.type == "entEntity" then
						entity.parameters = 'Prop'
					elseif entity.type == "Spawn" then
						Spawn.spawnedNPCs[entity.uniqueName()] = nil
						entity.parameters = AMM:GetScanAppearance(entity.handle)
						Spawn.spawnedNPCs[entity.uniqueName()] = entity
					end

					Spawn.currentFavoriteName = ''
					Spawn:ToggleFavorite(isFavorite, entity)
					AMM.popupIsOpen = false
					ImGui.CloseCurrentPopup()
				else
					Spawn.currentFavoriteName = 'existing'
				end
			end

			ImGui.SameLine()
			if ImGui.Button("Cancel", style.halfButtonWidth + 8, style.buttonHeight) then
				Spawn.currentFavoriteName = ''
				AMM.popupIsOpen = false
				ImGui.CloseCurrentPopup()
			end
		end
		ImGui.EndPopup()
	end
end

function Spawn:DrawArrowButton(direction, entity, index, localIndex)
	local dirEnum, tempPos
	if direction == "up" then
		dirEnum = ImGuiDir.Up
		tempPos = index - 1
		localIndex = localIndex - 1
	else
		dirEnum = ImGuiDir.Down
		tempPos = index + 1
		localIndex = localIndex + 1
	end

	if ImGui.ArrowButton(direction..entity.id, dirEnum) then

		local condition = " WHERE parameters != 'Prop'"
		if entity.type == "Props" then condition = " WHERE parameters = 'Prop'" end
		local query = "SELECT COUNT(1) FROM favorites"..condition
		for x in db:urows(query) do favoritesLength = x end

		local temp
		local query = f("SELECT * FROM favorites WHERE position = %i", tempPos)
		for fav in db:nrows(query) do temp = fav end
		if type(entity.parameters) == 'table' then entity.parameters = 'Prop' end

		if direction == "up" and temp.parameters == 'Prop' and entity.parameters ~= 'Prop' then
			while temp.parameters == 'Prop' and entity.parameters ~= 'Prop' do
				tempPos = tempPos - 1
				local query = f("SELECT * FROM favorites WHERE position = %i", tempPos)
				for fav in db:nrows(query) do temp = fav end
			end

			tempPos = tempPos + 1
			local query = f("SELECT * FROM favorites WHERE position = %i", tempPos)
			for fav in db:nrows(query) do temp = fav end
		end

		if not(localIndex < 1 or localIndex > favoritesLength) then
			db:execute(f("UPDATE favorites SET entity_id = '%s', entity_name = '%s', parameters = '%s' WHERE position = %i", entity.id, entity.name, entity.parameters, tempPos))
			db:execute(f("UPDATE favorites SET entity_id = '%s', entity_name = '%s', parameters = '%s' WHERE position = %i", temp.entity_id, temp.entity_name, temp.parameters, index))
		end
	end
end

-- End of Draw Methods

-- Main Methods
function Spawn:SpawnVehicle(spawn)
	local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	vehicleGarageId.recordID = TweakDBID.new(spawn.path)
	Game.GetVehicleSystem():ToggleSummonMode()
	Game.GetVehicleSystem():TogglePlayerActiveVehicle(vehicleGarageId, 'Car', true)
	Game.GetVehicleSystem():SpawnPlayerVehicle('Car')
	Game.GetVehicleSystem():ToggleSummonMode()

	Cron.Every(0.1, function(timer)
		local vehicleSummonDef = Game.GetAllBlackboardDefs().VehicleSummonData
		local vehicleSummonBB = Game.GetBlackboardSystem():Get(vehicleSummonDef)
		local vehicleEntID = vehicleSummonBB:GetEntityID(vehicleSummonDef.SummonedVehicleEntityID)

		spawn.handle = Game.FindEntityByID(vehicleEntID)

		if spawn.handle then

			Cron.After(0.2, function() 
				local floatFix = 1
				if type(spawn.parameters) == "number" then floatFix = 0 end
				
				local pos = spawn.handle:GetWorldPosition()
				local angles = GetSingleton('Quaternion'):ToEulerAngles(spawn.handle:GetWorldOrientation())
				local teleportPosition = Vector4.new(pos.x, pos.y, pos.z - floatFix, pos.w)
				Game.GetTeleportationFacility():Teleport(spawn.handle, teleportPosition, angles)
			end)

			Spawn.spawnedNPCs[spawn.uniqueName()] = spawn
      	Util:UnlockVehicle(spawn.handle)

			if spawn.parameters ~= nil then
				AMM:ChangeScanAppearanceTo(spawn, spawn.parameters)
			end

			local components = AMM.Props:CheckForValidComponents(spawn.handle)
			if components then
				spawn.defaultScale = {
					x = components[1].visualScale.x * 100,
					y = components[1].visualScale.x * 100,
					z = components[1].visualScale.x * 100,
				}
				spawn.scale = {
					x = components[1].visualScale.x * 100,
					y = components[1].visualScale.y * 100,
					z = components[1].visualScale.z * 100,
				}
			end

			Cron.Halt(timer)
		end
	end)
end

function Spawn:DespawnVehicle(spawn)
	local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	vehicleGarageId.recordID = TweakDBID.new(spawn.path)
	Game.GetVehicleSystem():DespawnPlayerVehicle(vehicleGarageId)
	Spawn.spawnedNPCs[spawn.uniqueName()] = nil
end

function Spawn:SpawnFavorite()
  local favorites = {}
  for ent in db:nrows("SELECT * FROM entities WHERE entity_id IN (SELECT entity_id FROM favorites)") do
    table.insert(favorites, Spawn:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path))
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

function Spawn:SpawnNPC(spawn)
	local spawnTransform = AMM.player:GetWorldTransform()
	local pos = AMM.player:GetWorldPosition()
	local heading = AMM.player:GetWorldForward()
	-- local newPos = Vector4.new(pos.x + heading.x, pos.y + heading.y, pos.z + heading.z, pos.w + heading.w)
	local newPos = Vector4.new(pos.x - heading.x, pos.y - heading.y, pos.z - heading.z, pos.w - heading.w)
	spawnTransform:SetPosition(newPos)

	local custom = {}
	if spawn.parameters ~= nil then
		custom = AMM:GetCustomAppearanceParams(spawn, spawn.parameters)
	end

	local favoriteApp = false

	if not AMM.userSettings.spawnAsCompanion and spawn.id ~= '0x55C01D9F, 36' then
		if spawn.parameters ~= nil and #custom == 0 then
			favoriteApp = true
			spawn.entityID = exEntitySpawner.SpawnRecord(spawn.path, spawnTransform, spawn.parameters)
		else
			spawn.entityID = exEntitySpawner.SpawnRecord(spawn.path, spawnTransform)
		end
	else
		spawn.entityID = Game.GetPreventionSpawnSystem():RequestSpawn(AMM:GetNPCTweakDBID(spawn.path), -99, spawnTransform)
	end

	while Spawn.spawnedNPCs[spawn.uniqueName()] ~= nil do
		local num = spawn.name:match("|([^|]+)")
		if num then num = tonumber(num) + 1 else num = 1 end
		spawn.name = spawn.name:gsub(" | "..tostring(num - 1), "")
		spawn.name = spawn.name.." | "..tostring(num)
	end

  	Cron.Every(0.1, {tick = 1}, function(timer)
		local entity = Game.FindEntityByID(spawn.entityID)

		timer.tick = timer.tick + 1
		
		if timer.tick > 30 then
			Cron.Halt(timer)
		end

		if entity then
			spawn.handle = entity
			Spawn.spawnedNPCs[spawn.uniqueName()] = spawn

			spawn.appearance = AMM:GetAppearance(spawn)

			if #custom > 0 or spawn.parameters ~= nil then
				AMM:ChangeAppearanceTo(spawn, spawn.parameters)
			elseif not favoriteApp then
				AMM:ChangeScanAppearanceTo(spawn, 'Cycle')
			end

			Cron.After(0.2, function() 
				if not(string.find(spawn.name, "Drone")) then
					Util:TeleportNPCTo(spawn.handle)
				end
			end)

			if AMM.userSettings.spawnAsCompanion and spawn.canBeCompanion then
				Spawn:SetNPCAsCompanion(spawn.handle)
			end

			Cron.Halt(timer)
		end
  	end)
end

function Spawn:DespawnNPC(ent)
	Spawn.spawnedNPCs[ent.uniqueName()] = nil
	exEntitySpawner.Despawn(ent.handle)

	local spawnID = ent.entityID
	local handle = Game.FindEntityByID(spawnID)
	if handle then
		if handle:IsNPC() then
			Util:TeleportNPCTo(handle, Util:GetBehindPlayerPosition(2))
		end
	end
	Game.GetPreventionSpawnSystem():RequestDespawn(spawnID)
end

function Spawn:DespawnAll()
  for _, ent in pairs(Spawn.spawnedNPCs) do
	if ent.handle and ent.handle ~= '' then
    	exEntitySpawner.Despawn(ent.handle)
	end
  end

  Spawn.spawnedNPCs = {}
end

function Spawn:SetNPCAsCompanion(npcHandle)
	if not(self.isCompanionInvulnerable) then
		Util:SetGodMode(npcHandle, false)
	end

	local targCompanion = npcHandle
	local AIC = targCompanion:GetAIControllerComponent()
	local targetAttAgent = targCompanion:GetAttitudeAgent()
	local currTime = targCompanion.isPlayerCompanionCachedTimeStamp + 11

	if targCompanion.isPlayerCompanionCached == false then
		local roleComp = NewObject('handle:AIFollowerRole')
		roleComp:SetFollowTarget(Game.GetPlayerSystem():GetLocalPlayerControlledGameObject())
		roleComp:OnRoleSet(targCompanion)
		roleComp.followerRef = Game.CreateEntityReference("#player", {})
		targetAttAgent:SetAttitudeGroup(CName.new("player"))
		roleComp.attitudeGroupName = CName.new("player")
		Game['senseComponent::RequestMainPresetChange;GameObjectString'](targCompanion, "Follower")
		targCompanion.isPlayerCompanionCached = true
		targCompanion.isPlayerCompanionCachedTimeStamp = currTime

		AIC:SetAIRole(roleComp)
		targCompanion.movePolicies:Toggle(true)

		AMM:UpdateFollowDistance()
	end
end


function Spawn:ToggleHostile(spawnHandle)
	Util:SetGodMode(spawnHandle, false)

	local handle = spawnHandle

	if handle.isPlayerCompanionCached then
		local AIC = handle:GetAIControllerComponent()
		local targetAttAgent = handle:GetAttitudeAgent()
		local reactionComp = handle.reactionComponent

		local aiRole = NewObject('handle:AIRole')
		aiRole:OnRoleSet(handle)

		handle.isPlayerCompanionCached = false
		handle.isPlayerCompanionCachedTimeStamp = 0

		Game['senseComponent::RequestMainPresetChange;GameObjectString'](handle, "Combat")
		AIC:GetCurrentRole():OnRoleCleared(handle)
		AIC:SetAIRole(aiRole)
		handle.movePolicies:Toggle(true)
		targetAttAgent:SetAttitudeGroup(CName.new("hostile"))
		reactionComp:SetReactionPreset(GetSingleton("gamedataTweakDBInterface"):GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive")))
		reactionComp:TriggerCombat(AMM.player)
	else
		Spawn:SetNPCAsCompanion(handle)
	end
end

function Spawn:ToggleFavorite(isFavorite, entity)
	if isFavorite == 0 then
		local command = f("INSERT INTO favorites (entity_id, entity_name, parameters) VALUES ('%s', '%s', '%s')", entity.id, entity.name, entity.parameters)
		command = command:gsub("'nil'", "NULL")
		db:execute(command)
	else
		local removedIndex = 0
		local query = f("SELECT position FROM favorites WHERE entity_name = '%s'", entity.name)
		for i in db:urows(query) do removedIndex = i end

		local command = f("DELETE FROM favorites WHERE entity_name = '%s' OR parameters = '%s'", entity.name, entity.parameters)
		command = command:gsub("'nil'", "NULL")
		db:execute(command)
		Spawn:RearrangeFavoritesIndex(removedIndex)
	end
end

function Spawn:RearrangeFavoritesIndex(removedIndex)
	local lastIndex = 0
	query = "SELECT seq FROM sqlite_sequence WHERE name = 'favorites'"
	for i in db:urows(query) do lastIndex = i end

	if lastIndex ~= removedIndex then
		for i = removedIndex, lastIndex - 1 do
			db:execute(f("UPDATE favorites SET position = %i WHERE position = %i", i, i + 1))
		end
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = 'favorites'", lastIndex - 1))
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

return Spawn:new()
