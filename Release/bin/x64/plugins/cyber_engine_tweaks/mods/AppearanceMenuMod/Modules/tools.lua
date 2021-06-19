Tools = {}

-- ALIAS for string.format --
local f = string.format
local Util = require('Modules/util.lua')

function Tools:new()

  -- Layout Properties
  Tools.style = {}
  Tools.actionCategories = {}

  -- Time Properties
  Tools.pauseTime = false
  Tools.timeState = true
  Tools.timeValue = nil
  Tools.slowMotionSpeed = 1
  Tools.slowMotionMaxValue = 1
  Tools.slowMotionToggle = false
  Tools.relicEffect = true
  Tools.relicOriginalFlats = Tools:GetRelicFlats()

  -- Teleport Properties
  Tools.lastLocation = nil
  Tools.selectedLocation = {loc_name = "Select Location"}
  Tools.shareLocationName = ''
  Tools.userLocations = {}
  Tools.favoriteLocations = {}
  Tools.useTeleportAnimation = false
  Tools.isTeleporting = false

  -- V Properties --
  Tools.playerVisibility = true
  Tools.godModeToggle = false
  Tools.infiniteOxygen = false
  Tools.makeupToggle = true
  Tools.accessoryToggle = true
  Tools.lookAtLocked = false
  Tools.animatedHead = false
  Tools.invisibleBody = false

  -- Target Properties --
  Tools.protectedNPCs = {}
  Tools.holdingNPC = false
  Tools.frozenNPCs = {}
  Tools.equippedWeaponNPCs = {}
  Tools.forceWeapon = false
  Tools.currentNPC = ''
  Tools.lockTarget = false
  Tools.npcUpDown = 0
  Tools.npcLeftRight = 0
  Tools.npcRotation = 0
  Tools.movingProp = false
  Tools.savedPosition = ''
  Tools.selectedFace = {name = 'Select Expression'}
  Tools.activatedFace = false
  Tools.upperBodyMovement = true
  Tools.lookAtV = true
  Tools.lookAtTarget = nil
  Tools.expressions = AMM:GetPersonalityOptions()
  Tools.photoModePuppet = nil

  return Tools
end

function Tools:Draw(AMM, target)
  if ImGui.BeginTabItem("Tools") then

    Tools.style = {
      buttonHeight = ImGui.GetFontSize() * 2,
      buttonWidth = -1,
      halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
    }

    Tools.actionCategories = {
      { name = "Target Actions", actions = Tools.DrawNPCActions },
      { name = "Teleport Actions", actions = Tools.DrawTeleportActions },
      { name = "Time Actions", actions = Tools.DrawTimeActions },
      { name = "V Actions", actions = Tools.DrawVActions },
    }

    if AMM.playerInMenu and not AMM.playerInPhoto then
      AMM.UI:TextColored("Player In Menu")
      ImGui.Text("Tools only works in game")
    else
      if AMM.playerInPhoto then
        Tools.actionCategories = {
          { name = "V Actions", actions = Tools.DrawVActions },
          { name = "Target Actions", actions = Tools.DrawNPCActions },
          { name = "Time Actions", actions = Tools.DrawTimeActions },
        }
      end

      for _, category in ipairs(Tools.actionCategories) do
        AMM.UI:PushStyleColor(ImGuiCol.Text, "TextColored")
        local treeNode = ImGui.TreeNodeEx(category.name, ImGuiTreeNodeFlags.DefaultOpen + ImGuiTreeNodeFlags.NoTreePushOnOpen)
        ImGui.PopStyleColor(1)

        if treeNode then
          ImGui.Separator()
          AMM.UI:Spacing(6)

          if category.name ~= "Target Actions" then
            category.actions()
          elseif category.name == "Target Actions" and AMM.userSettings.experimental then
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
      Tools:ToggleMakeup()
    end

    ImGui.SameLine()
    if ImGui.Button("Toggle Piercings", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleAccessories()
    end

    local buttonLabel = "Lock Look At Camera"
    if Tools.lookAtLocked then
      buttonLabel = "Unlock Look At Camera"
    end

    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleLookAt()
    end

    ImGui.SameLine()
    if ImGui.Button("Target V", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:SetCurrentTarget(Tools:GetVTarget())
      Tools.lockTarget = true
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

    -- ImGui.Spacing()
    Tools.invisibleBody, invisClicked = ImGui.Checkbox("Invisible V", Tools.invisibleBody)

    if invisClicked then
      Tools:ToggleInvisibleBody(AMM.player)
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

function Tools:ToggleMakeup()
  local target = Tools:GetVTarget()
	Tools.makeupToggle = not Tools.makeupToggle

	local isFemale = Util:GetPlayerGender()
	if isFemale == "_Female" then gender = 'pwa' else gender = 'pma' end

  local makeup
  if gender == "pma" then
    makeup = target.handle:FindComponentByName(CName.new("MorphTargetSkinnedMesh1265"))
  elseif gender == "pwa" then
	   makeup = target.handle:FindComponentByName(CName.new("hx_000_pwa__basehead_makeup_lips_01"))
  end
	if makeup then makeup:Toggle(Tools.makeupToggle) end

	makeup = target.handle:FindComponentByName(CName.new(f("hx_000_%s__basehead_makeup_eyes_01", gender)))
	if makeup then makeup:Toggle(Tools.makeupToggle) end
end

function Tools:ToggleAccessories()
  local target = Tools:GetVTarget()
  Tools.accessoryToggle = not Tools.accessoryToggle

  local isFemale = Util:GetPlayerGender()
	if isFemale == "_Female" then gender = 'pwa' else gender = 'pma' end

  for i = 1, 4 do
    print(f("i1_000_%s__morphs_earring_0%i", gender, i))
    local accessory = target.handle:FindComponentByName(CName.new(f("i1_000_%s__morphs_earring_0%i", gender, i)))
	  if accessory then accessory:Toggle(Tools.accessoryToggle) end
  end
end

function Tools:ToggleInvisibleBody(playerHandle)
  for cname in db:urows("SELECT cname FROM components") do
    local comp = playerHandle:FindComponentByName(CName.new(cname))
	  if comp then comp:Toggle(not(Tools.invisibleBody)) end
  end
end

function Tools:ToggleInvisibility()
  Game.GetPlayer():SetInvisible(Tools.playerVisibility)
  Game.GetPlayer():UpdateVisibility()
  Tools.playerVisibility = not Tools.playerVisibility
end

function Tools:CheckGodModeIsActive()
  -- Check if God Mode is active after reload all mods
  if AMM.player ~= nil then
    local playerID = AMM.player:GetEntityID()
    local currentHP = Game.GetStatsSystem():GetStatValue(playerID, "Health")
    if currentHP < 0 then Tools.godModeToggle = true end
  end
end

function Tools:ToggleGodMode()
  -- Toggle God Mode
  Tools.godModeToggle = not Tools.godModeToggle

  if Tools.godModeToggle then
    hp, o2, weight = -99999, -999999, 9999
  else
    hp, o2, weight = 99999, 999999, -9999
  end

  -- Stat Modifiers
  Game.ModStatPlayer("Health", hp)
  Game.ModStatPlayer("Oxygen", o2)
  Game.ModStatPlayer("CarryCapacity", weight)

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

function Tools:GetVTarget()
  local entity = Tools.photoModePuppet
  if not entity then return nil end
  return AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), AMM:GetNPCName(entity),AMM:GetScanAppearance(entity), nil)
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
  os.remove("User/Locations/"..loc.file_name)
  Tools.selectedLocation = {loc_name = "Select Location"}
end

function Tools:ToggleFavoriteLocation(isFavorite, favIndex)
  if isFavorite then
    table.remove(Tools.favoriteLocations, favIndex)
  else
    table.insert(Tools.favoriteLocations, Tools.selectedLocation)
  end

  AMM:UpdateSettings()
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
        table.insert(userLocations, {file_name = loc.name, loc_name = loc_name, x = x, y = y, z = z, w = w, yaw = yaw})
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

-- Target actions
function Tools:DrawNPCActions()

  AMM.UI:DrawCrossHair()

  if Tools.currentNPC and Tools.currentNPC ~= '' then
    if not Game.FindEntityByID(Tools.currentNPC.handle:GetEntityID()) then
      Tools.currentNPC = ''
    end
  end

  if target ~= nil or Tools.currentNPC ~= '' then

    AMM.UI:TextCenter("Movement", true)

    if not Tools.lockTarget or Tools.currentNPC == '' then
      Tools.lockTarget = false
      if target == nil and Tools.currentNPC ~= '' and Tools.currentNPC.type ~= "Player" then
        Tools.currentNPC = ''
      elseif Tools.currentNPC == '' or (not(Tools.holdingNPC) and (target ~= nil and Tools.currentNPC.handle:GetEntityID().hash ~= target.handle:GetEntityID().hash)) then
        Tools:SetCurrentTarget(target)
      end
    end

    if Tools.currentNPC ~= '' then
      ImGui.Text(Tools.currentNPC.name)
    end

    local buttonLabel = " Lock Target "
    if Tools.lockTarget then
      buttonLabel = " Unlock Target "
    end
    ImGui.SameLine()
    if ImGui.SmallButton(buttonLabel) then
      Tools.lockTarget = not Tools.lockTarget
    end

    ImGui.PushItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Tilt/Rotation "))
    Tools.npcUpDown, upDownUsed = ImGui.DragFloat("Up/Down", Tools.npcUpDown, 0.01)

    if upDownUsed and Tools.currentNPC ~= '' then
      local pos = Tools.currentNPC.handle:GetWorldPosition()
      pos = Vector4.new(pos.x, pos.y, Tools.npcUpDown, pos.w)
      if Tools.currentNPC.type == 'entEntity' then
        if not Tools.movingProp then
          Tools:TeleportPropTo(Tools.currentNPC, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation[1])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    Tools.npcLeftRight, leftRightUsed = ImGui.DragFloat2("X/Y", Tools.npcLeftRight, 0.01)

    if leftRightUsed and Tools.currentNPC ~= '' then
      local pos = Tools.currentNPC.handle:GetWorldPosition()
      pos = Vector4.new(Tools.npcLeftRight[1], Tools.npcLeftRight[2], pos.z, pos.w)
      if Tools.currentNPC.type == 'entEntity' then
        if not Tools.movingProp then
          Tools:TeleportPropTo(Tools.currentNPC, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation[1])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    if Tools.currentNPC ~= '' and (AMM:GetScanClass(Tools.currentNPC.handle) ~= 'entEntity' and Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC()) then
      Tools.npcRotation[1], rotationUsed = ImGui.SliderFloat("Rotation", Tools.npcRotation[1], -180, 180)
    elseif Tools.currentNPC ~= '' then
      Tools.npcRotation, rotationUsed = ImGui.DragFloat3("Tilt/Rotation", Tools.npcRotation, 0.1)
    end

    if rotationUsed and Tools.currentNPC ~= '' then
      local pos = Tools.currentNPC.handle:GetWorldPosition()
      if Tools.currentNPC.type == 'entEntity' then
        if not Tools.movingProp then
          Tools:TeleportPropTo(Tools.currentNPC, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation[1])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    ImGui.PopItemWidth()
    AMM.UI:Spacing(3)

    local buttonLabel = "Save Position"
    if Tools.savedPosition ~= '' then
      buttonLabel = "Restore Position"
    end

    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      if Tools.savedPosition ~= '' then
        Tools:SetTargetPosition(Tools.savedPosition.pos, Tools.savedPosition.angles)
      else
        Tools.savedPosition = {pos = Tools.currentNPC.handle:GetWorldPosition(), angles = GetSingleton('Quaternion'):ToEulerAngles(Tools.currentNPC.handle:GetWorldOrientation())}
      end
    end

    if Tools.savedPosition ~= '' then
      if ImGui.Button("Clear Saved Position", Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools.savedPosition = ''
      end
    end

    ImGui.Spacing()

    if ImGui.Button("Reset Position", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      local pos = AMM.player:GetWorldPosition()
      Tools:SetTargetPosition(pos)
    end

    AMM.UI:Spacing(3)

    if not AMM.playerInPhoto and Tools.currentNPC ~= '' and Tools.currentNPC.type ~= 'entEntity' then

      local buttonLabel = "Pick Up Target"
      if Tools.holdingNPC then
        buttonLabel = "Drop Target"
      end

      local buttonWidth = Tools.style.buttonWidth
      if Tools.currentNPC ~= '' and Tools.currentNPC.handle:IsNPC() then
        buttonWidth = Tools.style.halfButtonWidth
      end

      if ImGui.Button(buttonLabel, buttonWidth, Tools.style.buttonHeight) then
        Tools.holdingNPC = not Tools.holdingNPC
        Tools.lockTarget = not Tools.lockTarget

        if Tools.currentNPC ~= '' then
          local npcHandle = Tools.currentNPC.handle

          if npcHandle:IsNPC() then
            Tools:FreezeNPC(npcHandle, true)
            npcHandle:GetAIControllerComponent():DisableCollider()
          end

          Cron.Every(0.000001, function(timer)
            local pos = AMM.player:GetWorldPosition()
            local heading = AMM.player:GetWorldForward()
            local currentPos = Tools.currentNPC.handle:GetWorldPosition()
            local newPos = Vector4.new(pos.x + (heading.x * 2), pos.y + (heading.y * 2), currentPos.z, pos.w)

            if Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
              Tools:TeleportNPCTo(npcHandle, newPos, Tools.npcRotation[1])
            else
              Game.GetTeleportationFacility():Teleport(npcHandle, newPos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
            end

            if Tools.holdingNPC == false then
              if npcHandle:IsNPC() then
                Tools:FreezeNPC(npcHandle, false)
                npcHandle:GetAIControllerComponent():EnableCollider()
              end
              Cron.Halt(timer)
            end
          end)
        end
      end
    end

    if Tools.currentNPC ~= '' and (Tools.currentNPC.type ~= 'entEntity' and Tools.currentNPC.handle:IsNPC()) then

      if not AMM.playerInPhoto then
        local buttonLabel = " Freeze Target "
        if Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] ~= nil then
          buttonLabel = " Unfreeze Target "
        end
        ImGui.SameLine()
        if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
          if buttonLabel == " Freeze Target " then
            Tools:FreezeNPC(Tools.currentNPC.handle, true)
            -- print(Tools.currentNPC.handle:GetEntityID().hash)
            Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = 'active'
          else
            Tools:FreezeNPC(Tools.currentNPC.handle, false)
            Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = nil
          end
        end
      end

      AMM.UI:Spacing(8)

      local targetIsPlayer = Tools.currentNPC.type == "Player"
      if not AMM.playerInPhoto or (AMM.playerInPhoto and targetIsPlayer and Tools.animatedHead) then
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
          if Tools.lookAtTarget then
            local ent = Game.FindEntityByID(Tools.lookAtTarget.handle:GetEntityID())
            if not ent then Tools.lookAtTarget = nil end
          end
          Tools:ActivateFacialExpression(Tools.currentNPC, Tools.selectedFace, Tools.upperBodyMovement, Tools.lookAtV, Tools.lookAtTarget)
        end

        ImGui.Spacing()

        Tools.upperBodyMovement, clicked = ImGui.Checkbox("Upper Body Movement", Tools.upperBodyMovement)

        if not targetIsPlayer then
          ImGui.SameLine()
          Tools.lookAtV = ImGui.Checkbox("Look At ", Tools.lookAtV)

          ImGui.SameLine()
          local lookAtTargetName = "V"
          if Tools.lookAtTarget ~= nil then
            lookAtTargetName = Tools.lookAtTarget.name
          end

          AMM.UI:TextColored(lookAtTargetName)

          AMM.UI:Spacing(3)

          if ImGui.Button("Change Look At Target", Tools.style.buttonWidth, Tools.style.buttonHeight) then
            if Tools.currentNPC ~= '' then
              Tools.lookAtTarget = Tools.currentNPC
            end
          end

          if ImGui.Button("Reset Look At Target", Tools.style.buttonWidth, Tools.style.buttonHeight) then
            if target ~= nil then
              Tools.lookAtTarget = nil
            end
          end
        elseif targetIsPlayer then
          Tools.lookAtV = false
        end
      end

      if AMM.userSettings.experimental and Tools.currentNPC.handle:IsNPC() then

        local es = Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem"))
        local weapon = es:GetActiveWeaponObject(AMM.player, 39)
        local npcHasWeapon = Tools.currentNPC.handle:HasPrimaryOrSecondaryEquipment()

        if npcHasWeapon or weapon then
          AMM.UI:Spacing(8)
          AMM.UI:TextCenter("Equipment", true)
          ImGui.Spacing()
        end

        if npcHasWeapon then
          if ImGui.Button("Toggle Primary Weapon", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
            local npcHash = tostring(Tools.currentNPC.handle:GetEntityID().hash)
            if Tools.equippedWeaponNPCs[npcHash] == nil then
              Tools.equippedWeaponNPCs[npcHash] = {primary = true, secondary = false}
            else
              Tools.equippedWeaponNPCs[npcHash].primary = not Tools.equippedWeaponNPCs[npcHash].primary
            end

            Util:EquipPrimaryWeaponCommand(Tools.currentNPC.handle, Tools.equippedWeaponNPCs[npcHash].primary)
          end

          ImGui.SameLine()
          if ImGui.Button("Toggle Secondary Weapon", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
            local npcHash = tostring(Tools.currentNPC.handle:GetEntityID().hash)
            if Tools.equippedWeaponNPCs[npcHash] == nil then
              Tools.equippedWeaponNPCs[npcHash] = {primary = false, secondary = true}
            else
              Tools.equippedWeaponNPCs[npcHash].secondary = not Tools.equippedWeaponNPCs[npcHash].secondary
            end

            Util:EquipSecondaryWeaponCommand(Tools.currentNPC.handle, Tools.equippedWeaponNPCs[npcHash].secondary)
          end
        end

        if weapon then
          if ImGui.Button("Give Current Equipped Weapon", Tools.style.buttonWidth, Tools.style.buttonHeight) then
            local weaponTDBID = weapon:GetItemID().tdbid
            Util:EquipGivenWeapon(Tools.currentNPC.handle, weaponTDBID, Tools.forceWeapon)
          end

          if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Note: Out of combat, the NPC will unequip the given weapon immediately.")
          end

          ImGui.Spacing()
          Tools.forceWeapon = ImGui.Checkbox("Force Given Weapon", Tools.forceWeapon)

          if ImGui.IsItemHovered() then
            ImGui.SetTooltip("This will stop the NPC from unequipping your given weapon. Note: the NPC will still unequip at will during combat.")
          end
        end
      end
    elseif Tools.currentNPC ~= '' then

      AMM.UI:Spacing(3)

      local lookAtTargetName = "V"
      if Tools.lookAtTarget ~= nil then
        lookAtTargetName = Tools.lookAtTarget.name
      end

      ImGui.Text("Current Look At Target:")
      ImGui.SameLine()
      AMM.UI:TextColored(lookAtTargetName)

      if ImGui.Button("Change Look At Target", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        if Tools.currentNPC ~= '' then
          Tools.lookAtTarget = Tools.currentNPC
        end
      end

      ImGui.SameLine()
      if ImGui.Button("Reset Look At Target", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        if target ~= nil then
          Tools.lookAtTarget = nil
        end
      end
    end
  else
    ImGui.Text("")
    if AMM.playerInPhoto then
      AMM.UI:TextCenter("Target V or NPC to see More Actions")
    else
      AMM.UI:TextCenter("Target NPC or Prop to see More Actions")
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
      local entities = Util:GetNPCsInRange(30)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          Tools:SetNPCAttitude(ent, "friendly")
        end
      end

      Tools:ClearProtected()
    end

    ImGui.SameLine()
    if ImGui.Button("All Follower", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Util:GetNPCsInRange(10)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          AMM:SetNPCAsCompanion(ent.handle)
        end
      end

      Tools:ClearProtected()
    end

    if ImGui.Button("All Fake Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Util:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          ent.handle:SendAIDeathSignal()
        end
      end

      Tools:ClearProtected()
    end

    ImGui.SameLine()
    if ImGui.Button("All Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Util:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          ent.handle:Kill(ent.handle, false, false)
        end
      end

      Tools:ClearProtected()
    end

    if ImGui.Button("All Despawn", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Util:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          ent.handle:Dispose()
        end
      end

      Tools:ClearProtected()
    end

    ImGui.SameLine()
    if ImGui.Button("Cycle Appearance", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local entities = Util:GetNPCsInRange(20)
      for _, ent in ipairs(entities) do
        if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
          AMM:ChangeScanAppearanceTo(ent, "Cycle")
        end
      end

      Tools:ClearProtected()
    end
  end
end

function Tools:SetTargetPosition(pos, angles)
  if Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
    Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, angles or Tools.npcRotation[1])
  else
    Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, angles or EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
  end

  Cron.After(0.2, function()
    Tools:SetCurrentTarget(Tools.currentNPC)
  end)
end

function Tools:SetCurrentTarget(target)
  local pos, angles
  Tools.currentNPC = target

  if Tools.currentNPC.type == 'entEntity' then
    pos = Tools.currentNPC.parameters[1]
    angles = Tools.currentNPC.parameters[2]
  else
    pos = Tools.currentNPC.handle:GetWorldPosition()
    angles = GetSingleton('Quaternion'):ToEulerAngles(Tools.currentNPC.handle:GetWorldOrientation())
  end

  Tools.npcRotation = {angles.roll, angles.pitch, angles.yaw}
  Tools.npcUpDown = pos.z
  Tools.npcLeftRight = {pos.x, pos.y}
end

function Tools:ActivateFacialExpression(target, face, upperBody, lookAtV, lookAtTarget)
  local lookAtTarget = lookAtTarget and lookAtTarget.handle or AMM.player

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
        stimComp:ActivateReactionLookAt(lookAtTarget, false, true, 1, upperBody)
      end
    end)
  end
end

function Tools:TeleportPropTo(prop, pos, angles)
  prop.handle:Dispose()

  local spawnTransform = AMM.player:GetWorldTransform()
  spawnTransform:SetPosition(pos)
  spawnTransform:SetOrientationEuler(angles)

  prop.entityID = WorldFunctionalTests.SpawnEntity(prop.template, spawnTransform, '')

  Tools.movingProp = true

  Cron.Every(0.1, {tick = 1}, function(timer)
    local entity = Game.FindEntityByID(prop.entityID)
    if entity then
      prop.handle = entity
      prop.parameters = {pos, angles}
      Tools.movingProp = false
      Tools:SetCurrentTarget(prop)
      Cron.Halt(timer)
    end
  end)

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

-- Time actions
function Tools:DrawTimeActions()
  -- AMM.UI:TextColored("Time Actions:")

  if Tools.timeValue == nil then
    Tools.timeValue = Tools:GetCurrentHour()
  end

  Tools.timeValue, changeTimeUsed = ImGui.SliderInt("Time of Day", Tools.timeValue, 0, 23)
  if changeTimeUsed then
    if Tools.relicEffect then
      Tools:SetRelicEffect(false)
      Cron.After(60.0, function()
        Tools:SetRelicEffect(true)
      end)
    end
    Tools:SetTime(Tools.timeValue)
  end

  if not AMM.playerInPhoto then
    Tools.slowMotionSpeed, slowMotionUsed = ImGui.SliderFloat("Slow Motion", Tools.slowMotionSpeed, 0.000001, Tools.slowMotionMaxValue)
    if slowMotionUsed then
      Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
    end

    local buttonLabel = "Pause Time Progression"
    if Tools.pauseTime then
      buttonLabel = "Unpause Time Progression"
    end

    ImGui.Spacing()
    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools.pauseTime = not Tools.pauseTime
      Tools:SetRelicEffect(false)

      Cron.Every(0.1, function(timer)
        Tools:SetTime(Tools.timeValue)
        if not Tools.pauseTime then
          Cron.After(60.0, function()
            Tools:SetRelicEffect(true)
          end)
          Cron.Halt(timer)
        end
      end)
    end

    local buttonLabel = "Unfreeze Time"
    if Tools.timeState then
      buttonLabel = "Freeze Time"
    end

    ImGui.Spacing()
    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:FreezeTime()
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
  Tools:FreezeTime()
  AMM.skipFrame = true
end

function Tools:FreezeTime()
  if Tools.timeState then
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(true)
    Game.SetTimeDilation(0.0000000000001)
  else
    if Tools.slowMotionSpeed ~= 1 then
      Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
    else
      Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(false)
      Game.SetTimeDilation(0)
      Tools.slowMotionSpeed = 1
    end
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

function Tools:SetRelicEffect(state)
  Tools.relicEffect = state
  for flat, og in pairs(Tools.relicOriginalFlats) do
    TweakDB:SetFlat(flat, state and og or CName.new("0"))
  end
end

function Tools:GetRelicFlats()
  local flats = {
    ["BaseStatusEffect.JohnnySicknessMediumQuest_inline2.name"] = CName.new('johnny_sickness_lvl2'),
    ["BaseStatusEffect.JohnnySicknessMedium_inline0.name"] = CName.new('johnny_sickness_lvl2'),
    ["BaseStatusEffect.JohnnySicknessLow_inline0.name"] = CName.new('johnny_sickness_lvl1'),
    ["BaseStatusEffect.JohnnySicknessHeavy_inline0.name"] = CName.new('johnny_sickness_lvl3')
  }

  return flats
end

return Tools:new()
