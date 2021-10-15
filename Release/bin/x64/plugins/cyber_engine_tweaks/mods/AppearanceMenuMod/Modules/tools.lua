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
  Tools.invisibleBody = false
  Tools.seamfixToggle = false
  Tools.savePhotoModeToggles = false
  Tools.animatedHead = AMM.userSettings.animatedHead
  Tools.TPPCamera = false
  Tools.TPPCameraBeforeVehicle = false
  Tools.selectedTPPCamera = 1
  Tools.TPPCameraOptions = {
    {name = "Left", vec = Vector4.new(-0.5, -2, 0, 1.0)},
    {name = "Right", vec = Vector4.new(0.5, -2, 0, 1.0)},
    {name = "Center Close", vec = Vector4.new(0, -2, 0, 1.0)},
    {name = "Center Far", vec = Vector4.new(0, -4, 0, 1.0)},
  }

  -- Target Properties --
  Tools.protectedNPCs = {}
  Tools.holdingNPC = false
  Tools.frozenNPCs = {}
  Tools.equippedWeaponNPCs = {}
  Tools.forceWeapon = false
  Tools.currentNPC = ''
  Tools.lockTarget = false
  Tools.precisonMode = false
  Tools.relativeMode = false
  Tools.proportionalMode = true
  Tools.isCrouching = false
  Tools.npcUpDown = 0
  Tools.npcLeft = 0
  Tools.npcRight = 0
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
  Tools.currentTargetComponents = nil

  return Tools
end

function Tools:Draw(AMM, target)
  if ImGui.BeginTabItem("Tools") then

    -- Util Popup Helper --
    Util:SetupPopup()

    if AMM.Light.isEditing then
      AMM.Light:Draw(AMM)
    end

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
          elseif category.name == "Target Actions" then
            category.actions()
          end

          AMM.UI:Spacing(6)
        end
        if not treeNode then ImGui.Separator() end
      end

      if ImGui.InvisibleButton("Speed", 10, 30) then
        local popupInfo = {text = "You found it! Fast Motion is now available."}
				Util:OpenPopup(popupInfo)
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

    if ImGui.Button("Toggle Seamfix", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleSeamfix()
    end

    ImGui.SameLine()
    if ImGui.Button("Target V", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:SetCurrentTarget(Tools:GetVTarget())
      Tools.lockTarget = true
    end

    local buttonLabel = "Lock Look At Camera"
    if Tools.lookAtLocked then
      buttonLabel = "Unlock Look At Camera"
    end

    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:ToggleLookAt()
    end

    Tools.savePhotoModeToggles = ImGui.Checkbox("Save Toggles State", Tools.savePhotoModeToggles)

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("This will save Makeup, Piercing and Seamfix toggles state until you close the game.")
    end
  else
    local buttonLabel = "Disable Passive Mode"
    if Tools.playerVisibility then
      buttonLabel = "Enable Passive Mode"
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

    if AMM.userSettings.experimental then
      if ImGui.Button("Toggle TPP Camera", Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools:ToggleTPPCamera()
      end

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip("TPP Camera is not suited for regular gameplay, but it's fun for a walk ;)")
      end

      local selectedCamera = Tools.TPPCameraOptions[Tools.selectedTPPCamera]
      if ImGui.BeginCombo("TPP Camera Position", selectedCamera.name) then
        for i, cam in ipairs(Tools.TPPCameraOptions) do
          if ImGui.Selectable(cam.name.."##"..i, (cam == selectedCamera.name)) then
            Tools.selectedTPPCamera = i
          end
        end
        ImGui.EndCombo()
      end
    end

    ImGui.Spacing()
    
    if GetVersion() == "v1.15.0" then
      Tools.animatedHead, clicked = ImGui.Checkbox("Animated Head in Photo Mode", Tools.animatedHead)

      if clicked then
        Tools:ToggleAnimatedHead(Tools.animatedHead)
        AMM:UpdateSettings()
      end

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Photo mode expressions won't work while Animated Head is enabled.")
      end
    end

    -- ImGui.Spacing()
    Tools.invisibleBody, invisClicked = ImGui.Checkbox("Invisible V", Tools.invisibleBody)

    if invisClicked then
      Tools:ToggleInvisibleBody(AMM.player)
    end
  end
end

function Tools:ToggleSeamfix()
  local target = Tools:GetVTarget()

  Tools.seamfixToggle = not Tools.seamfixToggle
  for cname in db:urows("SELECT cname FROM components WHERE cname LIKE '%seamfix%'") do
    local comp = target.handle:FindComponentByName(CName.new(cname))
	  if comp then comp:Toggle(not(Tools.seamfixToggle)) end
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
    local accessory = target.handle:FindComponentByName(CName.new(f("i1_000_%s__morphs_earring_0%i", gender, i)))
	  if accessory then accessory:Toggle(Tools.accessoryToggle) end
  end
end

function Tools:ToggleInvisibleBody(playerHandle)
  for cname in db:urows("SELECT cname FROM components WHERE cname NOT LIKE '%hh_%'") do
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
    if currentHP < 0 then Tools.godModeToggle = true 
    elseif AMM.userSettings.godModeOnLaunch then
      Tools:ToggleGodMode()
    end
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

function Tools:ToggleAnimatedHead(animated)

  Tools.animatedHead = animated
  AMM.userSettings.animatedHead = animated

  local isFemale = Util:GetPlayerGender()
  if isFemale == "_Female" then gender = 'wa' else gender = 'ma' end
  if animated then mode = "tpp" else mode = "photomode" end

  local headItem = f("player_%s_%s_head", gender, mode)

  TweakDB:SetFlat(f("Items.Player%sPhotomodeHead.entityName", gender:gsub("^%l", string.upper)), headItem)
end

function Tools:ToggleTPPCamera()
  AMM.Tools.TPPCamera = not AMM.Tools.TPPCamera

  if Tools.TPPCamera then
    Cron.After(0.1, function()
      Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Tools.TPPCameraOptions[Tools.selectedTPPCamera].vec)
    end)

    Cron.Every(0.1, function(timer)
      if Tools.TPPCamera then
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Tools.TPPCameraOptions[Tools.selectedTPPCamera].vec)
        Game.GetPlayer():GetFPPCameraComponent().pitchMax = 80
        Game.GetPlayer():GetFPPCameraComponent().pitchMin = -80
        Game.GetPlayer():GetFPPCameraComponent().yawMaxRight = -360
        Game.GetPlayer():GetFPPCameraComponent().yawMaxLeft = 360
      else
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0, 0, 1.0))
        Cron.Halt(timer)
      end
    end)
  end

  Tools:ToggleHead()
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

  if ts:GetItemInSlot(AMM.player, TweakDBID.new("AttachmentSlots.TppHead")) ~= nil then
    ts:RemoveItemFromSlot(AMM.player, TweakDBID.new('AttachmentSlots.TppHead'), true, true, true)
    Game.EquipItemOnPlayer("Items.PlayerFppHead", "TppHead")
  else
    Game.EquipItemOnPlayer(headItem, "TppHead")
  end
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

  if Tools.currentNPC and Tools.currentNPC ~= '' and Tools.currentNPC.handle then
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

      Tools.currentTargetComponents = nil
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

    local adjustmentValue = 0.01
    if Tools.precisonMode then adjustmentValue = 0.001 end

    local width = ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Tilt/Rotation ")
    ImGui.PushItemWidth(width)
    Tools.npcUpDown, upDownUsed = ImGui.DragFloat("Up/Down", Tools.npcUpDown, adjustmentValue)
    ImGui.PopItemWidth()

    if upDownUsed and Tools.currentNPC ~= '' then
      local pos = Tools.currentNPC.handle:GetWorldPosition()
      pos = Vector4.new(pos.x, pos.y, Tools.npcUpDown, pos.w)
      if Tools.currentNPC.type == 'entEntity' then
        if not Tools.movingProp then
          Tools:TeleportPropTo(Tools.currentNPC, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    ImGui.PushItemWidth((width / 2) - 4)
    Tools.npcLeft, leftUsed = ImGui.DragFloat("", Tools.npcLeft, adjustmentValue)

    if Tools.relativeMode and ImGui.IsItemDeactivatedAfterEdit() then
      Tools.npcLeft = 0
    end

    local sliderLabel = "X/Y"

    if Tools.relativeMode then
      sliderLabel = "F-B/L-R"
    end

    ImGui.SameLine()
    Tools.npcRight, rightUsed = ImGui.DragFloat(sliderLabel, Tools.npcRight, adjustmentValue)

    if Tools.relativeMode and ImGui.IsItemDeactivatedAfterEdit() then
      Tools.npcRight = 0
    end

    ImGui.PopItemWidth()

    local forward = {x = 0, y = 0, z = 0}
    local right = {x = 0, y = 0, z = 0}
    local pos = nil

    if Tools.currentNPC ~= '' then
      if Tools.relativeMode then
        forward = Tools.currentNPC.handle:GetWorldForward()
        right = Tools.currentNPC.handle:GetWorldRight()
      end

      pos = Tools.currentNPC.handle:GetWorldPosition()

      if leftUsed then
        local x = Tools.npcLeft
        local targetX = Tools.npcLeft

        if Tools.relativeMode then
          targetX = pos.x
        end

        pos = Vector4.new(targetX + (forward.x * x), pos.y + (forward.y * x), pos.z + (forward.z * x), pos.w)
      end

      if rightUsed then
        local y = Tools.npcRight
        local targetY = Tools.npcRight

        if Tools.relativeMode then
          targetY = pos.y
        end

        pos = Vector4.new(pos.x + (right.x * y), targetY + (right.y * y), pos.z + (right.z * y), pos.w)
      end
    end

    if leftUsed or rightUsed and Tools.currentNPC ~= '' then
      if Tools.currentNPC.type == 'entEntity' then
        if not Tools.movingProp then
          Tools:TeleportPropTo(Tools.currentNPC, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    ImGui.PushItemWidth(width)

    local rotationValue = 0.1
    if Tools.precisonMode then rotationValue = 0.01 end

    if Tools.currentNPC ~= '' and (Tools.currentNPC.type ~= 'entEntity' and Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC()) then
      Tools.npcRotation[3], rotationUsed = ImGui.SliderFloat("Rotation", Tools.npcRotation[3], -180, 180)
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
        Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    ImGui.Spacing()
    Tools.precisonMode = ImGui.Checkbox("Precision Mode", Tools.precisonMode)

    ImGui.SameLine()
    Tools.relativeMode, modeChange = ImGui.Checkbox("Relative Mode", Tools.relativeMode)

    if modeChange then
      if Tools.relativeMode then
        Tools.npcLeft = 0
        Tools.npcRight = 0
      else
        local pos = Tools.currentNPC.handle:GetWorldPosition()
        Tools.npcLeft = pos.x
        Tools.npcRight = pos.y
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
              Tools:TeleportNPCTo(npcHandle, newPos, Tools.npcRotation[3])
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

      ImGui.SameLine()
    end

    if Tools.currentNPC ~= '' and (Tools.currentNPC.type ~= 'entEntity' and Tools.currentNPC.handle:IsNPC()) then

      if not AMM.playerInPhoto or AMM.userSettings.freezeInPhoto then
        local buttonLabel = " Freeze Target "
        if Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] ~= nil then
          buttonLabel = " Unfreeze Target "
        end

        local buttonWidth = Tools.style.halfButtonWidth
        if AMM.playerInPhoto then buttonWidth = Tools.style.buttonWidth end

        if ImGui.Button(buttonLabel, buttonWidth, Tools.style.buttonHeight) then
          if buttonLabel == " Freeze Target " then
            Tools:FreezeNPC(Tools.currentNPC.handle, true)
            Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = 'active'
          else
            Tools:FreezeNPC(Tools.currentNPC.handle, false)              
            Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = nil
          end
        end

        if AMM.playerInPhoto then
          if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.PushTextWrapPos(500)
            ImGui.TextWrapped("Unfreeze Target will skip frames for custom animation mods in Photo Mode if not using IGCS. For full Freeze/Unfreeze functionality unpause using IGCS.")
            ImGui.PopTextWrapPos()
            ImGui.EndTooltip()
          end
        end

        if not AMM.playerInPhoto and not Tools.currentNPC.handle.isPlayerCompanionCached then

          if Tools:ShouldCrouchButtonAppear(Tools.currentNPC) then
            local buttonLabel = " Change To Crouch Stance "
            if Tools.isCrouching then
              buttonLabel = " Change To Stand Stance "
            end

            if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
              Tools.isCrouching = not Tools.isCrouching

              local handle = Tools.currentNPC.handle

              if Tools.isCrouching then
                local pos = handle:GetWorldPosition()
                pos = Vector4.new(pos.x, pos.y, pos.z, pos.w)
                Util:MoveTo(handle, pos, nil, true)
              else
                Tools.currentNPC.parameters = AMM:GetAppearance(Tools.currentNPC)

                local currentNPC = Tools.currentNPC
                if currentNPC.type ~= 'Spawn' then
                  for _, spawn in pairs(Spawn.spawnedNPCs) do
                    if currentNPC.id == spawn.id then currentNPC = spawn break end
                  end
                end

                AMM.Spawn:DespawnNPC(currentNPC)
                AMM.Spawn:SpawnNPC(currentNPC)
              end
            end
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

        if not AMM.playerInPhoto then

          Tools.upperBodyMovement, clicked = ImGui.Checkbox("Upper Body Movement", Tools.upperBodyMovement)

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

      if Tools.currentNPC.handle:FindComponentByName("amm_light") then
        AMM.UI:Spacing(8)

        AMM.UI:TextCenter("Light Control", true)

        if ImGui.Button("Toggle Light", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
          AMM.Light:ToggleLight(Tools.currentNPC)
        end

        ImGui.SameLine()
        local buttonLabel ="Open Light Settings"
        if AMM.Light.isEditing then
          buttonLabel = "Update Light Target"
        end

        if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
          AMM.Light:Setup(Tools.currentNPC)
          AMM.Light.isEditing = true
        end
      end

      if Tools.currentTargetComponents == nil then
        Tools.currentTargetComponents = AMM.Props:CheckForValidComponents(Tools.currentNPC.handle)
      end

      local components = Tools.currentTargetComponents

      AMM.UI:Spacing(8)

      AMM.UI:TextCenter("Scale", true)
      
      if components then
        
        local scaleChanged = false
        local scaleWidth = ImGui.GetWindowContentRegionWidth()
        if Tools.proportionalMode then
          ImGui.PushItemWidth(scaleWidth)
          Tools.currentNPC.scale.x, scaleChanged = ImGui.DragFloat("##scale", Tools.currentNPC.scale.x, 0.1)

          if scaleChanged then 
            Tools.currentNPC.scale.y = Tools.currentNPC.scale.x
            Tools.currentNPC.scale.z = Tools.currentNPC.scale.x
          end
        else
          ImGui.PushItemWidth((scaleWidth / 3) - 4)
          Tools.currentNPC.scale.x, used = ImGui.DragFloat("##scaleX", Tools.currentNPC.scale.x, 0.1)
          if used then scaleChanged = true end
          ImGui.SameLine()
          Tools.currentNPC.scale.y, used = ImGui.DragFloat("##scaleY", Tools.currentNPC.scale.y, 0.1)
          if used then scaleChanged = true end
          ImGui.SameLine()
          Tools.currentNPC.scale.z, used = ImGui.DragFloat("##scaleZ", Tools.currentNPC.scale.z, 0.1)
          if used then scaleChanged = true end
        end

        ImGui.PopItemWidth()

        if scaleChanged then
          Tools:SetScale(components, Tools.currentNPC.scale, Tools.proportionalMode)
        end

        Tools.proportionalMode, proportionalModeChanged = ImGui.Checkbox("Proportional Mode", Tools.proportionalMode)

        if proportionalModeChanged then
          Tools:SetScale(components, Tools.currentNPC.scale, Tools.proportionalMode)
        end

        if ImGui.Button("Reset Scale", Tools.style.buttonWidth, Tools.style.buttonHeight) then
          Tools:SetScale(components, Tools.currentNPC.defaultScale, true)
          Tools.currentNPC.scale = {
            x = Tools.currentNPC.defaultScale.x,
            y = Tools.currentNPC.defaultScale.y,
            z = Tools.currentNPC.defaultScale.z,
          }
        end
      else
        AMM.UI:Spacing(3)
        AMM.UI:TextCenter("Scaling Not Available")
      end

      AMM.UI:Spacing(8)

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
  if Tools.currentNPC.type == 'entEntity' then
    if not Tools.movingProp then
      Tools:TeleportPropTo(Tools.currentNPC, pos, angles or EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
    end
  elseif Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
    Tools:TeleportNPCTo(Tools.currentNPC.handle, pos, angles or Tools.npcRotation[3])
  else
    Game.GetTeleportationFacility():Teleport(Tools.currentNPC.handle, pos, angles or EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
  end

  Cron.After(0.2, function()
    Tools:SetCurrentTarget(Tools.currentNPC)
  end)
end

function Tools:ClearTarget()
  Tools.lockTarget = false
  Tools.currentNPC = ''
end

function Tools:SetCurrentTarget(target)
  local pos, angles
  Tools.currentNPC = target

  Tools.currentTargetComponents = nil

  if Tools.currentNPC.type == 'entEntity' then
    pos = Tools.currentNPC.parameters[1]
    angles = Tools.currentNPC.parameters[2]
  else
    pos = Tools.currentNPC.handle:GetWorldPosition()
    angles = GetSingleton('Quaternion'):ToEulerAngles(Tools.currentNPC.handle:GetWorldOrientation())
  end

  Tools.npcRotation = {angles.roll, angles.pitch, angles.yaw}
  Tools.npcUpDown = pos.z

  if Tools.relativeMode then
    Tools.npcLeft = 0
    Tools.npcRight = 0  
  else
    Tools.npcLeft = pos.x
    Tools.npcRight = pos.y
  end
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
  
  local lastScale = nil
  if prop.scale and prop.scale ~= "nil" then
    lastScale = prop.scale
  end

  local spawnTransform = AMM.player:GetWorldTransform()
  spawnTransform:SetPosition(pos)
  spawnTransform:SetOrientationEuler(angles)

  prop.entityID = exEntitySpawner.Spawn(prop.template, spawnTransform, '')

  Tools.movingProp = true

  Cron.Every(0.1, {tick = 1}, function(timer)
    local entity = Game.FindEntityByID(prop.entityID)
    if entity then
      prop.handle = entity
      prop.parameters = {pos, angles}

      if lastScale then
        local components = AMM.Props:CheckForValidComponents(entity)
        Tools:SetScale(components, lastScale)
      end

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

function Tools:SetScale(components, values, proportional)
  local n = values
  local newScale = Vector3.new(n.x / 100, n.y / 100, n.z / 100)
  if proportional then newScale = Vector3.new(n.x / 100, n.x / 100, n.x / 100) end
  for _, comp in ipairs(components) do
    comp.visualScale = newScale
    comp:Toggle(false)
    comp:Toggle(true)
  end
end

-- Time actions
function Tools:DrawTimeActions()
  -- AMM.UI:TextColored("Time Actions:")

  local gameTime = Tools:GetCurrentHour()
  Tools.timeValue = Tools:ConvertTime(gameTime)

  ImGui.PushItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Time of Day "))

  Tools.timeValue, changeTimeUsed = ImGui.SliderInt("Time of Day", Tools.timeValue, 0, 1440, "")

  if changeTimeUsed then
    if Tools.relicEffect then
      Tools:SetRelicEffect(false)
      Cron.After(60.0, function()
        Tools:SetRelicEffect(true)
      end)
    end

    Tools:SetTime(Tools.timeValue)
  end

  ImGui.SameLine(250)
  ImGui.Text(f("%02d:%02d", gameTime.hour, gameTime.minute))

  if not AMM.playerInPhoto or AMM.userSettings.freezeInPhoto then
    Tools.slowMotionSpeed, slowMotionUsed = ImGui.SliderFloat("Slow Motion", Tools.slowMotionSpeed, 0.000001, Tools.slowMotionMaxValue)
    if slowMotionUsed then
      Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
    end

    if AMM.playerInPhoto then
      if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Slow Motion in Photo Mode only works if you unpause using IGCS")
      end
    end
  end

  ImGui.PopItemWidth()

  if not AMM.playerInPhoto then

    local buttonLabel = "Pause Time Progression"
    if Tools.pauseTime then
      buttonLabel = "Unpause Time Progression"
    end

    ImGui.Spacing()
    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools.pauseTime = not Tools.pauseTime
      Tools:SetRelicEffect(false)

      local currentTime = Tools.timeValue
      Cron.Every(0.1, function(timer)
        Tools:SetTime(currentTime)
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

  Cron.After(0.1, function() 
    Tools:FreezeTime()
  end)
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
  local time = {
    hour = currentGameTime:Hours(currentGameTime),
    minute = currentGameTime:Minutes(currentGameTime)
  }
  return time
end

function Tools:ConvertTime(time)
  return (time.hour * 60) + time.minute
end

function Tools:SetTime(time)
  local hour = math.floor(time / 60)
  local minute = math.floor(math.fmod(time / 60, 1) * 60)
  Game.GetTimeSystem():SetGameTimeByHMS(hour, minute, 0)
end

function Tools:SetRelicEffect(state)
  Tools.relicEffect = state
  for flat, og in pairs(Tools.relicOriginalFlats) do
    TweakDB:SetFlat(flat, state and og or CName.new("0"))
  end
end

function Tools:GetRelicFlats()
  local flats = {
    ["BaseStatusEffect.JohnnySicknessMediumQuest_inline2.name"] = TweakDB:GetFlat("BaseStatusEffect.JohnnySicknessMediumQuest_inline2.name"),
    ["BaseStatusEffect.JohnnySicknessMedium_inline0.name"] = TweakDB:GetFlat("BaseStatusEffect.JohnnySicknessMedium_inline0.name"),
    ["BaseStatusEffect.JohnnySicknessLow_inline0.name"] = TweakDB:GetFlat("BaseStatusEffect.JohnnySicknessLow_inline0.name"),
    ["BaseStatusEffect.JohnnySicknessHeavy_inline0.name"] = TweakDB:GetFlat("BaseStatusEffect.JohnnySicknessHeavy_inline0.name")
  }

  return flats
end

function Tools:ShouldCrouchButtonAppear(spawn)
  if spawn.type == 'Spawn' then return true end

  for _, ent in pairs(Spawn.spawnedNPCs) do
    if ent.hash == spawn.hash then return true end
  end

  return false
end

return Tools:new()
