local Tools = {
  -- Style Property
  style = {},
  actionCategories = {},

  -- Time Properties
  timeState = true,
  timeValue = nil,
  slowMotionSpeed = 1,
  slowMotionMaxValue = 1,
  slowMotionToggle = false,

  -- Teleport Properties
  lastLocation = nil,
  selectedLocation = {loc_name = "Select Location"},
  shareLocationName = '',
  userLocations = {},
  favoriteLocations = {},
  useTeleportAnimation = false,
  isTeleporting = false,

  -- V Properties --
  playerVisibility = true,
  godModeToggle = false,
  infiniteOxygen = false,
  makeupToggle = true,
  accessoryToggle = true,
  lookAtLocked = false,
  animatedHead = false,

  -- NPC Properties --
  protectedNPCs = {},
  holdingNPC = false,
  frozenNPCs = {},
  currentNPC = '',
  npcUpDown = 0,
  npcLeftRight = 0,
  npcRotation = 0,
  selectedFace = {name = 'Select Expression'},
  activatedFace = false,
  upperBodyMovement = true,
  lookAtV = true,
  expressions = AMM:GetPersonalityOptions()
}

-- ALIAS for string.format --
local f = string.format
local Util = require('Modules/util.lua')

function Tools:Draw(AMM, target)
  if ImGui.BeginTabItem("Tools") then

    Tools.style = {
      buttonHeight = ImGui.GetFontSize() * 2,
      buttonWidth = -1,
      halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
    }

    Tools.actionCategories = {
      { name = "Teleport Actions", actions = Tools.DrawTeleportActions },
      { name = "Time Actions", actions = Tools.DrawTimeActions },
      { name = "V Actions", actions = Tools.DrawVActions },
      { name = "NPC Actions", actions = Tools.DrawNPCActions },
    }

    if AMM.playerInMenu and not AMM.playerInPhoto then
      AMM.UI:TextColored("Player In Menu")
      ImGui.Text("Tools only works in game")
    else
      if AMM.playerInPhoto then
        if target ~= nil and target.name == 'V' then
          Tools.actionCategories = {
            { name = "V Actions", actions = Tools.DrawVActions },
            { name = "Time Actions", actions = Tools.DrawTimeActions },
            { name = "NPC Actions", actions = Tools.DrawNPCActions },
          }
        else
          AMM.UI:TextColored("Player In Photo Mode")
          ImGui.Text("Target V to see available actions")
          AMM.UI:Spacing(6)
          Tools.actionCategories = {
            { name = "Time Actions", actions = Tools.DrawTimeActions },
            { name = "NPC Actions", actions = Tools.DrawNPCActions },
          }
        end
      end

      for _, category in ipairs(Tools.actionCategories) do
        AMM.UI:PushStyleColor(ImGuiCol.Text, "TextColored")
        local treeNode = ImGui.TreeNodeEx(category.name, ImGuiTreeNodeFlags.DefaultOpen + ImGuiTreeNodeFlags.NoTreePushOnOpen)
        ImGui.PopStyleColor(1)

        if treeNode then
          ImGui.Separator()
          AMM.UI:Spacing(6)

          if category.name ~= "NPC Actions" then
            category.actions()
          elseif category.name == "NPC Actions" and AMM.userSettings.experimental then
            category.actions()
          end

          AMM.UI:Spacing(6)
        end
        if not treeNode then ImGui.Separator() end
      end

      if ImGui.InvisibleButton("Speed", 10, 30) then
        Tools.slowMotionMaxValue = 5
      end

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip("What if I click here?")
      end
    end
    ImGui.EndTabItem()
  end
end

-- V actions
function Tools:DrawVActions()
  -- AMM.UI:TextColored("V Actions:")

  if AMM.playerInPhoto then
    if ImGui.Button("Toggle Makeup", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleMakeup(target)
    end

    ImGui.SameLine()
    if ImGui.Button("Toggle Piercings", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleAccessories(target)
    end

    local buttonLabel = "Lock Look At Camera"
    if Tools.lookAtLocked then
      buttonLabel = "Unlock Look At Camera"
    end

    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:ToggleLookAt()
    end
  else
    local buttonLabel = "Disable Invisibility"
    if Tools.playerVisibility then
      buttonLabel = "Enable Invisibility"
    end

    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleInvisibility()
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("Enemies will still attack you if you trigger combat")
    end

    local buttonLabel = "Enable God Mode"
    if Tools.godModeToggle then
      buttonLabel = "Disable God Mode"
    end

    ImGui.SameLine()
    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleGodMode()
    end

    local buttonLabel = "Infinite Oxygen"
    local isInfiniteOxygenEnabled = Tools.infiniteOxygen
    if isInfiniteOxygenEnabled then
      buttonLabel = "Reload To Disable"
      ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
    end

    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      if not Tools.infiniteOxygen then
        Tools.infiniteOxygen = not Tools.infiniteOxygen
        Game.ModStatPlayer("CanBreatheUnderwater", "1")
      end
    end

    if isInfiniteOxygenEnabled then
      ImGui.PopStyleColor(3)
    end

    ImGui.SameLine()
    if ImGui.Button("Toggle V Head", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleHead()
    end

    ImGui.Spacing()
    Tools.animatedHead, clicked = ImGui.Checkbox("Animated Head in Photo Mode", Tools.animatedHead)

    if clicked then
      Tools:ToggleAnimatedHead()
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("Photo mode expressions won't work while Animated Head is enabled.")
    end
  end
end

function Tools:ToggleLookAt()
  Tools.lookAtLocked = not Tools.lookAtLocked

  if AMM.playerInPhoto then
    if Tools.lookAtLocked then
      print("[AMM] Setting Value (CET limitation - can't remove this message)")
      GameOptions.SetFloat("LookAt", "MaxIterationsCount", 0.9)
    else
      print("[AMM] Setting Value (CET limitation - can't remove this message)")
      GameOptions.SetFloat("LookAt", "MaxIterationsCount", 1.0)
    end
  else
    print("[AMM] Setting Value (CET limitation - can't remove this message)")
    GameOptions.SetFloat("LookAt", "MaxIterationsCount", 3.0)
  end
end

function Tools:ToggleMakeup(target)
	Tools.makeupToggle = not Tools.makeupToggle

	local isFemale = Util:GetPlayerGender()
	if isFemale == "_Female" then gender = 'pwa' else gender = 'pma' end

	local makeup = target.handle:FindComponentByName(CName.new(f("hx_000_%s__basehead_makeup_lips_01", gender)))
	if makeup then makeup:Toggle(Tools.makeupToggle) end

	local makeup = target.handle:FindComponentByName(CName.new(f("hx_000_%s__basehead_makeup_eyes_01", gender)))
	if makeup then makeup:Toggle(Tools.makeupToggle) end
end

function Tools:ToggleAccessories(target)
  Tools.accessoryToggle = not Tools.accessoryToggle

  local isFemale = Util:GetPlayerGender()
	if isFemale then gender = 'pwa' else gender = 'pma' end

  for i = 1, 4 do
    local accessory = target.handle:FindComponentByName(CName.new(f("i1_000_%s__morphs_earring_0%i", gender, i)))
	   if accessory then accessory:Toggle(Tools.accessoryToggle) end
  end
end

function Tools:ToggleInvisibility()
  Game.GetPlayer():SetInvisible(Tools.playerVisibility)
  Game.GetPlayer():UpdateVisibility()
  Tools.playerVisibility = not Tools.playerVisibility
end

function Tools:CheckGodModeIsActive()
  -- Check if God Mode is active after reload all mods
  if Game.GetPlayer() ~= nil then
    local playerID = Game.GetPlayer():GetEntityID()
    local currentHP = Game.GetStatsSystem():GetStatValue(playerID, "Health")
    if currentHP < 0 then Tools.godModeToggle = true end
  end
end

function Tools:ToggleGodMode()
  -- Toggle God Mode
  Tools.godModeToggle = not Tools.godModeToggle

  if Tools.godModeToggle then
    hp, o2 = -99999, -999999
  else
    hp, o2 = 99999, 999999
  end

  -- Stat Modifiers
  Game.ModStatPlayer("Health", hp)
  Game.ModStatPlayer("Oxygen", o2)

  -- Toggles
  local toggle = boolToInt(Tools.godModeToggle)
  Game.InfiniteStamina(Tools.godModeToggle)
  Game.ModStatPlayer("KnockdownImmunity", toggle)
  Game.ModStatPlayer("PoisonImmunity", toggle)
  Game.ModStatPlayer("BurningImmunity", toggle)
  Game.ModStatPlayer("BlindImmunity", toggle)
  Game.ModStatPlayer("BleedingImmunity", toggle)
  Game.ModStatPlayer("FallDamageReduction", toggle)
  Game.ModStatPlayer("ElectrocuteImmunity", toggle)
  Game.ModStatPlayer("StunImmunity", toggle)
end

function Tools:ToggleAnimatedHead()

  local isFemale = Util:GetPlayerGender()
  if isFemale == "_Female" then gender = 'wa' else gender = 'ma' end
  if Tools.animatedHead then mode = "tpp" else mode = "photomode" end

  local headItem = f("player_%s_%s_head", gender, mode)

  TweakDB:SetFlat(f("Items.Player%sPhotomodeHead.entityName", gender:gsub("^%l", string.upper)), headItem)
end

function Tools:ToggleHead()

  local isFemale = Util:GetPlayerGender()
	if isFemale == "_Female" then gender = 'Wa' else gender = 'Ma' end

  local headItem = f("Items.CharacterCustomization%sHead", gender)

  local ts = Game.GetTransactionSystem()
  local gameItemID = GetSingleton('gameItemID')
  local tdbid = TweakDBID.new(headItem)
  local itemID = gameItemID:FromTDBID(tdbid)

  if ts:HasItem(Game.GetPlayer(), itemID) == false then
    Game.AddToInventory(headItem, 1)
  end

  Game.EquipItemOnPlayer(headItem, "TppHead")
end

-- Teleport actions
function Tools:DrawTeleportActions()
  Tools.userLocations = Tools:GetUserLocations()

  -- AMM.UI:TextColored("Teleport Actions:")

  if ImGui.BeginCombo("Locations", Tools.selectedLocation.loc_name, ImGuiComboFlags.HeightLarge) then
    for i, location in ipairs(Tools:GetLocations()) do
      if ImGui.Selectable(location.loc_name.."##"..i, (location == Tools.selectedLocation.loc_name)) then
        if location.loc_name:match("%-%-%-%-") == nil then
          Tools.selectedLocation = location
        end
      end
    end
    ImGui.EndCombo()
  end

  ImGui.Spacing()

  if Tools.selectedLocation.loc_name ~= "Select Location" then

    if ImGui.Button("Teleport To Location", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:TeleportToLocation(Tools.selectedLocation)
    end

    ImGui.Spacing()

    local isFavorite, favIndex = Tools:IsFavorite(Tools.selectedLocation)
    local favLabel = "Favorite Selected Location"
    if isFavorite then
      favLabel = "Unfavorite Selected Location"
    end

    if ImGui.Button(favLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:ToggleFavoriteLocation(isFavorite, favIndex)
    end

    ImGui.Spacing()
  end

  if ImGui.Button("Share Current Location", Tools.style.buttonWidth, Tools.style.buttonHeight) then
    Tools:GetShareablePlayerLocation()
  end

  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("User locations are saved in AppearanceMenuMod/User/Locations folder")
  end

  ImGui.Spacing()

  if Tools.lastLocation then
    if ImGui.Button("Go Back To Last Location", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:TeleportToLocation(Tools.lastLocation)
    end
  end

  if Tools:IsUserLocation(Tools.selectedLocation) then
    if ImGui.Button("Delete Selected User Location", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:DeleteLocation(Tools.selectedLocation)
    end
  end

  if AMM.TeleportMod ~= '' then
    ImGui.Spacing()
    Tools.useTeleportAnimation, clicked = ImGui.Checkbox("Use Teleport Animation", Tools.useTeleportAnimation)
    if clicked then
      AMM.userSettings.teleportAnimation = Tools.useTeleportAnimation
      AMM:UpdateSettings()
    end
    ImGui.SameLine()
    AMM.UI:TextColored("by GTA Travel")
  end

  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
  ImGui.SetNextWindowSize(400, ImGui.GetFontSize() * 8)

  if ImGui.BeginPopupModal("Share Location") then
    local style = {
        buttonHeight = ImGui.GetFontSize() * 2,
        halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12)
    }

    if Tools.shareLocationName == 'existing' then
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "Existing Name")

      if ImGui.Button("Ok", -1, style.buttonHeight) then
        Tools.shareLocationName = ''
      end
    else
      Tools.shareLocationName = ImGui.InputText("Name", Tools.shareLocationName, 30)

      if ImGui.Button("Save", style.halfButtonWidth + 8, style.buttonHeight) then
        if not(io.open(f("User/Locations/%s.json", Tools.shareLocationName), "r")) then
          local currentLocation = Tools:GetPlayerLocation()
          local newLoc = Tools:NewLocationData(Tools.shareLocationName, currentLocation)
          Tools:SaveLocation(newLoc)
          Tools.userLocations = Tools:GetUserLocations()
          Tools.shareLocationName = ''
          ImGui.CloseCurrentPopup()
        else
          Tools.shareLocationName = 'existing'
        end
      end

      ImGui.SameLine()
      if ImGui.Button("Cancel", style.halfButtonWidth + 8, style.buttonHeight) then
        Tools.shareLocationName = ''
        ImGui.CloseCurrentPopup()
      end
    end
    ImGui.EndPopup()
  end
end

function Tools:GetLocations()
  local separator = false
  local locations = {}

  if next(Tools.favoriteLocations) ~= nil then
    table.insert(locations, {loc_name = '--------- Favorites ----------'})

    for _, loc in ipairs(Tools.favoriteLocations) do
      table.insert(locations, loc)
    end

    separator = true
  end

  if next(Tools.userLocations) ~= nil then
    table.insert(locations, {loc_name = '------- User Locations -------'})

    for _, loc in ipairs(Tools.userLocations) do
      table.insert(locations, loc)
    end

    separator = true
  end

  if separator then
    table.insert(locations, {loc_name = '------------------------------'})
  end

  for loc in db:nrows("SELECT * FROM locations ORDER BY loc_name ASC") do
    table.insert(locations, loc)
  end
  return locations
end

function Tools:TeleportToLocation(loc)
  Tools.lastLocation = Tools:NewLocationData("Previous Location", Tools:GetPlayerLocation())

  if Tools.useTeleportAnimation then
    AMM.TeleportMod.api.requestTravel(Vector4.new(loc.x, loc.y, loc.z, loc.w))
  else
    Game.GetTeleportationFacility():Teleport(Game.GetPlayer(), Vector4.new(loc.x, loc.y, loc.z, loc.w), EulerAngles.new(0, 0, loc.yaw))
    AMM.Tools.isTeleporting = true
  end
end

function Tools:GetPlayerLocation()
  return { pos = Game.GetPlayer():GetWorldPosition(), yaw = Game.GetPlayer():GetWorldYaw() }
end

function Tools:GetShareablePlayerLocation()
  Tools:SetLocationNamePopup()
end

function Tools:NewLocationData(locationName, locationPosition)
  return {
    loc_name = locationName,
    x = locationPosition.pos.x,
    y = locationPosition.pos.y,
    z = locationPosition.pos.z,
    w = locationPosition.pos.w,
    yaw = locationPosition.yaw
  }
end

function Tools:SaveLocation(loc)
  local file = io.open(f("User/Locations/%s.json", loc.loc_name), "w")
  if file then
    local contents = json.encode(loc)
		file:write(contents)
		file:close()
  end
end

function Tools:IsUserLocation(loc)
  for _, location in ipairs(Tools.userLocations) do
    if loc.loc_name == location.loc_name then return true end
  end

  return false
end

function Tools:DeleteLocation(loc)
  os.remove("User/Locations/"..loc.loc_name..".json")
end

function Tools:ToggleFavoriteLocation(isFavorite, favIndex)
  if isFavorite then
    table.remove(Tools.favoriteLocations, favIndex)
  else
    table.insert(Tools.favoriteLocations, Tools.selectedLocation)
  end
end

function Tools:GetFavoriteLocations()
  return Tools.favoriteLocations
end

function Tools:IsFavorite(loc)
  for index, location in ipairs(Tools.favoriteLocations) do
    if location.loc_name == loc.loc_name then
      return true, index
    end
  end

  return false
end

function Tools:GetUserLocations()
  local files = dir("./User/Locations")
  local userLocations = {}
  if #Tools.userLocations ~= #files then
    for _, loc in ipairs(files) do
      if string.find(loc.name, '.json') then
        local loc_name, x, y, z, w, yaw = Tools:LoadLocationData(loc.name)
        table.insert(userLocations, {loc_name = loc_name, x = x, y = y, z = z, w = w, yaw = yaw})
      end
    end
    return userLocations
  else
    return Tools.userLocations
  end
end

function Tools:LoadLocationData(loc)
  local file = io.open('User/Locations/'..loc, 'r')
  if file then
    local contents = file:read( "*a" )
		local locationData = json.decode(contents)
    file:close()
    return locationData["loc_name"], locationData["x"], locationData["y"], locationData["z"], locationData["w"], locationData["yaw"]
  end
end

function Tools:SetLocationNamePopup()
	Tools.shareLocationName = ''
	ImGui.OpenPopup("Share Location")
end

-- NPC actions
function Tools:DrawNPCActions()
  -- AMM.UI:TextColored("NPC Actions:")

  AMM.UI:DrawCrossHair()

  if Tools.currentNPC ~= '' then
    if not Game.FindEntityByID(Tools.currentNPC.handle:GetEntityID()) then
      Tools.currentNPC = ''
    end
  end

  if target ~= nil and target.handle:IsNPC() or Tools.currentNPC ~= '' then

    AMM.UI:TextCenter("Movement", true)

    if Tools.currentNPC == '' or (not(Tools.holdingNPC) and target ~= nil and target.handle:IsNPC() and Tools.currentNPC ~= '' and Tools.currentNPC.handle:GetEntityID().hash ~= target.handle:GetEntityID().hash) then
      Tools.currentNPC = target

      local pos = Tools.currentNPC.handle:GetWorldPosition()
      local angles = GetSingleton('Quaternion'):ToEulerAngles(Tools.currentNPC.handle:GetWorldOrientation())
      Tools.npcRotation = angles.roll
      Tools.npcUpDown = pos.z
      Tools.npcLeftRight = {pos.x, pos.y}
    end

    ImGui.Text(Tools.currentNPC.name)

    ImGui.PushItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Rotation "))
    Tools.npcUpDown, upDownUsed = ImGui.DragFloat("Up/Down", Tools.npcUpDown, 0.01)

    if upDownUsed then
      local pos = Tools.currentNPC.handle:GetWorldPosition()
      pos = Vector4.new(pos.x, pos.y, Tools.npcUpDown, pos.w)
      if Tools.currentNPC.name == "V" then
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(0, 0, Tools.npcRotation))
      else
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation)
      end
    end

    Tools.npcLeftRight, leftRightUsed = ImGui.DragFloat2("X/Y", Tools.npcLeftRight, 0.01)

    if leftRightUsed then
      local pos = Tools.currentNPC.handle:GetWorldPosition()
      pos = Vector4.new(Tools.npcLeftRight[1], Tools.npcLeftRight[2], pos.z, pos.w)
      if Tools.currentNPC.name == "V" then
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(0, 0, Tools.npcRotation))
      else
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation)
      end
    end

    Tools.npcRotation, rotationUsed = ImGui.SliderFloat("Rotation", Tools.npcRotation, -180, 180)

    if rotationUsed then
      local pos = Tools.currentNPC.handle:GetWorldPosition()
      if Tools.currentNPC.name == "V" then
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(0, 0, Tools.npcRotation))
      else
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation)
      end
    end

    ImGui.PopItemWidth()
    AMM.UI:Spacing(3)

    if not AMM.playerInPhoto then

      local buttonLabel = "Pick Up NPC"
      if Tools.holdingNPC then
        buttonLabel = "Drop NPC"
      end
      if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        Tools.holdingNPC = not Tools.holdingNPC
        local npcHandle = Tools.currentNPC.handle
        npcHandle:GetAIControllerComponent():DisableCollider()

        Cron.Every(0.000001, function(timer)
          local pos = Game.GetPlayer():GetWorldPosition()
          local heading = Game.GetPlayer():GetWorldForward()
          local newPos = Vector4.new(pos.x + (heading.x * 2), pos.y + (heading.y * 2), pos.z, pos.w)

          Tools:TeleportNPCTo(npcHandle, newPos, Tools.npcRotation)

          if Tools.holdingNPC == false then
            npcHandle:GetAIControllerComponent():EnableCollider()
            Cron.Halt(timer)
          end
        end)
      end
    end

    if not AMM.playerInPhoto then
      local buttonLabel = " Freeze Target "
      if Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] ~= nil then
        buttonLabel = " Unfreeze Target "
      end
      ImGui.SameLine()
      if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        if buttonLabel == " Freeze Target " then
          Tools:FreezeNPC(Tools.currentNPC.handle, true)
          print(Tools.currentNPC.handle:GetEntityID().hash)
          Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = 'active'
        else
          Tools:FreezeNPC(Tools.currentNPC.handle, false)
          Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = nil
        end
      end

      AMM.UI:Spacing(8)

      AMM.UI:TextCenter("Facial Expression", true)
      ImGui.Spacing()

      local isSelecting = false

      if ImGui.BeginCombo("Expressions", Tools.selectedFace.name) then
        for i, face in ipairs(Tools.expressions) do
          if ImGui.Selectable(face.name, (face.name == Tools.selectedFace.name)) then
            Tools.selectedFace = face
            Tools.activatedFace = false
            isSelecting = true
          end
        end
        ImGui.EndCombo()
      end

      if not isSelecting and Tools.selectedFace.name ~= "Select Expression" and not Tools.activatedFace then
        Tools:ActivateFacialExpression(Tools.currentNPC, Tools.selectedFace, Tools.upperBodyMovement, Tools.lookAtV)
      end

      ImGui.Spacing()

      Tools.upperBodyMovement, clicked = ImGui.Checkbox("Upper Body Movement", Tools.upperBodyMovement)
      ImGui.SameLine()
      Tools.lookAtV = ImGui.Checkbox("Look At V", Tools.lookAtV)
    end
  else
    ImGui.Text("")
    if AMM.playerInPhoto then
      AMM.UI:TextCenter("Target V or NPC to see More Actions")
    else
      AMM.UI:TextCenter("Target NPC to see More Actions")
    end
  end

  if not AMM.playerInPhoto then
    AMM.UI:Spacing(8)

    AMM.UI:TextCenter("General Actions", true)
    ImGui.Spacing()

    if ImGui.Button("Protect NPC from Actions", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      if target.handle:IsNPC() then
        Tools:ProtectTarget(target)
      end
    end

    if ImGui.Button("All Friendly", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Tools:GetNPCsInRange(30)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          Tools:SetNPCAttitude(ent, "friendly")
        end
      end

      Tools:ClearProtected()
    end

    ImGui.SameLine()
    if ImGui.Button("All Follower", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Tools:GetNPCsInRange(10)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          AMM:SetNPCAsCompanion(ent.handle)
        end
      end

      Tools:ClearProtected()
    end

    if ImGui.Button("All Fake Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Tools:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          ent.handle:SendAIDeathSignal()
        end
      end

      Tools:ClearProtected()
    end

    ImGui.SameLine()
    if ImGui.Button("All Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Tools:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          ent.handle:Kill(ent.handle, false, false)
        end
      end

      Tools:ClearProtected()
    end

    if ImGui.Button("All Despawn", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Tools:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          ent.handle:Dispose()
        end
      end

      Tools:ClearProtected()
    end

    ImGui.SameLine()
    if ImGui.Button("Cycle Appearance", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Tools:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          AMM:ChangeScanAppearanceTo(ent, "Cycle")
        end
      end

      Tools:ClearProtected()
    end
  end
end

function Tools:ActivateFacialExpression(target, face, upperBody, lookAtV)
  Tools.activatedFace = true
  local stimComp = target.handle:GetStimReactionComponent()
  if stimComp then
    stimComp:DeactiveLookAt()
    stimComp:ResetFacial(0)

    Cron.After(0.5, function()
      local animCon = target.handle:GetAnimationControllerComponent()
      local animFeat = NewObject("handle:AnimFeature_FacialReaction")
      animFeat.category = face.category
      animFeat.idle = face.idle
      animCon:ApplyFeature(CName.new("FacialReaction"), animFeat)
      if lookAtV then
        stimComp:ActivateReactionLookAt(Game.GetPlayer(), false, true, 1, upperBody)
      end
    end)
  end
end

function Tools:TeleportNPCTo(targetPuppet, targetPosition, targetRotation)
	local teleportCmd = NewObject('handle:AITeleportCommand')
	teleportCmd.position = targetPosition
	teleportCmd.rotation = targetRotation or 0.0
	teleportCmd.doNavTest = false

	targetPuppet:GetAIControllerComponent():SendCommand(teleportCmd)

	return teleportCmd, targetPuppet
end

function Tools:FreezeNPC(handle, freeze)
  if freeze then
    -- (reason: CName, dilation: Float, duration: Float, easeInCurve: CName, easeOutCurve: CName, ignoreGlobalDilation: Bool),
    handle:SetIndividualTimeDilation(CName.new("AMM"), 0.00001, 2.5, CName.new(""), CName.new(""), true)
  else
    handle:SetIndividualTimeDilation(CName.new("AMM"), 1.0, 2.5, CName.new(""), CName.new(""), false)
  end
end


function Tools:ProtectTarget(t)
  local mappinData = NewObject('gamemappinsMappinData')
  mappinData.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
  mappinData.variant = Enum.new('gamedataMappinVariant', 'QuestGiverVariant')
  mappinData.visibleThroughWalls = true

  local slot = CName.new('poi_mappin')
  local offset = ToVector3{ x = 0, y = 0, z = 2 } -- Move the pin a bit up relative to the target

  local newMappinID = Game.GetMappinSystem():RegisterMappinWithObject(mappinData, t.handle, slot, offset)
  Tools.protectedNPCs[target.handle:GetEntityID().hash] = newMappinID
end

function Tools:ClearProtected()
  for _, mappinID in pairs(Tools.protectedNPCs) do
    Game.GetMappinSystem():UnregisterMappin(mappinID)
  end

  Tools.protectedNPCs = {}
end

function Tools:SetNPCAttitude(entity, attitude)
	local entAttAgent = entity.handle:GetAttitudeAgent()
	entAttAgent:SetAttitudeGroup(CName.new(attitude))
end

function Tools:GetNPCsInRange(maxDistance)
	local searchQuery = Game["TSQ_NPC;"]()
	searchQuery.maxDistance = maxDistance
	local success, parts = Game.GetTargetingSystem():GetTargetParts(Game.GetPlayer(), searchQuery, {})
	if success then
		local entities = {}
		for i, v in ipairs(parts) do
			local entity = v:GetComponent(v):GetEntity()
			entity = AMM:NewTarget(entity, "NPC", AMM:GetScanID(entity), AMM:GetNPCName(entity),AMM:GetScanAppearance(entity), AMM:GetAppearanceOptions(entity))
	    table.insert(entities, entity)
	  end

		return entities
	end
end

-- Time actions
function Tools:DrawTimeActions()
  -- AMM.UI:TextColored("Time Actions:")

  if Tools.timeValue == nil then
    Tools.timeValue = Tools:GetCurrentHour()
  end

  Tools.timeValue, changeTimeUsed = ImGui.SliderInt("Time of Day", Tools.timeValue, 0, 23)
  if changeTimeUsed then
    Tools:SetTime(Tools.timeValue)
  end

  if not AMM.playerInPhoto then
    Tools.slowMotionSpeed, slowMotionUsed = ImGui.SliderFloat("Slow Motion", Tools.slowMotionSpeed, 0.000001, Tools.slowMotionMaxValue)
    if slowMotionUsed then
      Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
    end

    local buttonLabel = "Unfreeze Time"
    if Tools.timeState then
      buttonLabel = "Freeze Time"
    end

    ImGui.Spacing()
    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:PauseTime()
    end

    if not Tools.timeState then
      ImGui.Spacing()
      if ImGui.Button("Skip Frame", Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools:SkipFrame()
      end
    end
  end
end

function Tools:SetSlowMotionSpeed(c)
  Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(c == 1 and false or true)
  if c == 0 then c = 0.0000000000001 elseif c == 1 then c = 0 end
  Game.SetTimeDilation(c)
end

function Tools:SkipFrame()
  Tools:PauseTime()
  AMM.skipFrame = true
end

function Tools:PauseTime()
  if Tools.timeState then
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(true)
    Game.SetTimeDilation(0.0000000000001)
  else
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(false)
    Game.SetTimeDilation(0)
    Tools.slowMotionSpeed = 1
  end

  Tools.timeState = not Tools.timeState
end

function Tools:GetCurrentHour()
  local currentGameTime = Game.GetTimeSystem():GetGameTime()
  return currentGameTime:Hours(currentGameTime)
end

function Tools:SetTime(hour)
  Game.GetTimeSystem():SetGameTimeByHMS(hour, 0, 0)
end

Tools.userLocations = Tools:GetUserLocations()

return Tools
