Tools = {}

-- ALIAS for string.format --
local f = string.format
local Util = require('Modules/util.lua')

function Tools:new()

  -- Layout Properties
  Tools.style = {}
  Tools.actionCategories = {}
  Tools.movementWindow = {open = false, isEditing = false}
  Tools.scaleWidth = nil

  -- Time Properties
  Tools.pauseTime = false
  Tools.timeState = true
  Tools.timeValue = nil
  Tools.slowMotionSpeed = 1
  Tools.slowMotionMaxValue = 1
  Tools.slowMotionToggle = false
  Tools.relicEffect = true
  Tools.relicOriginalFlats = nil

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
  Tools.tppHead = false
  Tools.TPPCamera = false
  Tools.TPPCameraBeforeVehicle = false
  Tools.selectedTPPCamera = 1
  Tools.TPPCameraOptions = nil

  -- Target Properties --
  Tools.protectedNPCs = {}
  Tools.holdingNPC = false
  Tools.frozenNPCs = {}
  Tools.equippedWeaponNPCs = {}
  Tools.forceWeapon = false
  Tools.currentNPC = ''
  Tools.lockTarget = false
  Tools.lockTargetPinID = nil
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
  Tools.lookAtActiveNPCs = {}
  Tools.lookAtTarget = nil
  Tools.expressions = AMM:GetPersonalityOptions()
  Tools.photoModePuppet = nil
  Tools.currentTargetComponents = nil

  -- PME Properties --
  Tools.selectedLookAt = nil
  Tools.lookAtOptions = nil
  Tools.defaultAperture = 4
  Tools.defaultFOV = 60
  Tools.headStiffness = 0.0
  Tools.headPoseOverride = 1.0
  Tools.chestStiffness = 0.1
  Tools.chestPoseOverride = 0.5
  Tools.lookAtSpeed = 140.0
  Tools.cursorController = nil
  Tools.cursorDisabled = false
  Tools.cursorStateLock = false

  return Tools
end

function Tools:Initialize()
  -- Setup TPP Camera Options --
  Tools.TPPCameraOptions = {
    {name = "Left", vec = Vector4.new(-0.5, -2, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = "Left Close", vec = Vector4.new(-0.4, -1.5, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = "Right", vec = Vector4.new(0.5, -2, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = "Right Close", vec = Vector4.new(0.4, -1.5, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = "Center Close", vec = Vector4.new(0, -2, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = "Center Far", vec = Vector4.new(0, -4, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = "Front Close", vec = Vector4.new(0, 2, 0, 0), rot = Quaternion.new(50.0, 0.0, 4000.0, 0.0)},
    {name = "Front Far", vec = Vector4.new(0, 4, 0, 0), rot = Quaternion.new(50.0, 0.0, 4000.0, 0.0)},
  }

  Tools.lookAtOptions = {
    {name = "All", parts = {'LookatPreset.PhotoMode_LookAtCamera_inline0', 'LookatPreset.PhotoMode_LookAtCamera_inline1'}},
    {name = "Head Only", parts = {'LookatPreset.PhotoMode_LookAtCamera_inline0'}},
    {name = "Eyes Only", parts = {}},
  }

  Tools.selectedLookAt = Tools.lookAtOptions[1]
end

function Tools:Draw(AMM, target)
  Tools.style = {
    buttonHeight = ImGui.GetFontSize() * 2,
    buttonWidth = ImGui.GetWindowContentRegionWidth(),
    halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
  }

  -- Util Popup Helper --
  Util:SetupPopup()  

  if ImGui.BeginTabItem("Tools") then

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
          { name = "Photo Mode Enhancements", actions = Tools.DrawPhotoModeEnhancements },
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

  if AMM.playerInPhoto or Util:CheckVByID(Tools.currentNPC.id) then
    if ImGui.Button("Toggle Makeup", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleMakeup()
    end

    ImGui.SameLine()
    if ImGui.Button("Toggle Piercings", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleAccessories()
    end

    local buttonWidth = Tools.style.halfButtonWidth
    if not AMM.playerInPhoto then
      buttonWidth = Tools.style.buttonWidth
    end

    if ImGui.Button("Toggle Seamfix", buttonWidth, Tools.style.buttonHeight) then
      Tools:ToggleSeamfix()
    end

    if AMM.playerInPhoto then
      ImGui.SameLine()
      if ImGui.Button("Target V", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        Tools:SetCurrentTarget(Tools:GetVTarget())
        Tools.lockTarget = true
      end

      local buttonLabel = "Lock Look At Camera"
      if Tools.lookAtLocked then
        buttonLabel = "Unlock Look At Camera"
      end

      if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        Tools:ToggleLookAt()
      end

      ImGui.SameLine()
      if ImGui.Button("Target Nibbles", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        Tools:SetCurrentTarget(Tools:GetNibblesTarget())
        Tools.lockTarget = true
      end

      Tools.savePhotoModeToggles = ImGui.Checkbox("Save Toggles State", Tools.savePhotoModeToggles)

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip("This will save Makeup, Piercing and Seamfix toggles state until you close the game.")
      end
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
      Tools:ToggleHead(true)
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
            AMM:UpdateSettings()
          end
        end
        ImGui.EndCombo()
      end
    end

    ImGui.Spacing()

    Tools.animatedHead, clicked = ImGui.Checkbox("Animated Head in Photo Mode", Tools.animatedHead)

    if clicked then
      Tools:ToggleAnimatedHead(Tools.animatedHead)
      AMM:UpdateSettings()
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

  if GetVersion() == "v1.15.0" then
    local isFemale = Util:GetPlayerGender()
    if isFemale == "_Female" then gender = 'wa' else gender = 'ma' end
    if animated then mode = "tpp" else mode = "photomode" end

    local headItem = f("player_%s_%s_head", gender, mode)

    TweakDB:SetFlat(f("Items.Player%sPhotomodeHead.entityName", gender:gsub("^%l", string.upper)), headItem)
  else
    local mode = "TPP_photomode"
    if animated then mode = "TPP" end

    TweakDB:SetFlat("Items.PlayerMaPhotomodeHead.appearanceName", mode)
    TweakDB:SetFlat("Items.PlayerWaPhotomodeHead.appearanceName", mode)
  end
end

function Tools:ToggleTPPCamera()
  AMM.Tools.TPPCamera = not AMM.Tools.TPPCamera

  if Tools.TPPCamera then
    Cron.After(0.1, function()
      Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Tools.TPPCameraOptions[Tools.selectedTPPCamera].vec)
      Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Tools.TPPCameraOptions[Tools.selectedTPPCamera].rot)
    end)

    Cron.Every(0.1, function(timer)
      if Tools.TPPCamera then
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Tools.TPPCameraOptions[Tools.selectedTPPCamera].vec)
        Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Tools.TPPCameraOptions[Tools.selectedTPPCamera].rot)
        Game.GetPlayer():GetFPPCameraComponent().pitchMax = 80
        Game.GetPlayer():GetFPPCameraComponent().pitchMin = -80
        Game.GetPlayer():GetFPPCameraComponent().yawMaxRight = -360
        Game.GetPlayer():GetFPPCameraComponent().yawMaxLeft = 360
      else
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0, 0, 1.0))
        Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 0.0, 1.0))
        Cron.Halt(timer)
      end
    end)
  end

  Tools:ToggleHead()
end

function Tools:ToggleHead(userActivated)
  if AMM.playerInVehicle and userActivated then
    return
  end

  Tools.tppHead = not Tools.tppHead

  local isFemale = Util:GetPlayerGender()
  if isFemale == "_Female" then gender = 'Wa' else gender = 'Ma' end

  local headItem = f("Items.CharacterCustomization%sHead", gender)

  local ts = Game.GetTransactionSystem()
  local tdbid = TweakDBID.new(headItem)
  local itemID = ItemID.FromTDBID(tdbid)

  if ts:HasItem(Game.GetPlayer(), itemID) == false then
    Game.AddToInventory(headItem, 1)
  end

  -- ts:AddItemToSlot(AMM.player, EquipmentSystem.GetPlacementSlot(itemID), itemID)

  if Tools.tppHead then
    Cron.Every(0.001, { tick = 1 }, function(timer)

      timer.tick = timer.tick + 1

      if timer.tick > 20 then
        Cron.Halt(timer)
      end

      Cron.After(0.01, function()
        ts:RemoveItemFromSlot(AMM.player, TweakDBID.new('AttachmentSlots.TppHead'), true, true, true)
      end)

      Cron.After(0.1, function()
        Game.EquipItemOnPlayer(headItem, "TppHead")
      end)
    end)
  else
    if ts:GetItemInSlot(AMM.player, TweakDBID.new("AttachmentSlots.TppHead")) ~= nil then
      ts:RemoveItemFromSlot(AMM.player, TweakDBID.new('AttachmentSlots.TppHead'), true, true, true)
      Game.EquipItemOnPlayer("Items.PlayerFppHead", "TppHead")
    end
  end
end

function Tools:GetNibblesTarget()
  local nibbles

  Util:GetAllInRange(30, true, true, function(entity)
    if entity then
      local entityID = AMM:GetScanID(entity)
      if entityID and Util:CheckNibblesByID(entityID) then
        nibbles = entity
      end
    end
	end)

  if not nibbles then
    if Util:CheckNibblesByID(Tools.currentNPC.id) then
      return Tools.currentNPC
    else
      return nil
    end
  end

  return AMM:NewTarget(nibbles, "NPCPuppet", AMM:GetScanID(nibbles), AMM:GetNPCName(nibbles),AMM:GetScanAppearance(nibbles), nil)
end

function Tools:GetVTarget()
  local entity = Tools.photoModePuppet
  if not entity then
    if Util:CheckVByID(Tools.currentNPC.id) then
      return Tools.currentNPC
    else
      return nil
    end
  end

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

  if AMM.TeleportMod then
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
      Tools.shareLocationName = ImGui.InputText("Name", Tools.shareLocationName, 50)

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

  for loc in db:nrows([[SELECT * FROM locations ORDER BY loc_name ASC]]) do
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

  if target ~= nil or (Tools.currentNPC and Tools.currentNPC ~= '') then

    if not AMM.userSettings.floatingTargetTools then
      AMM.UI:TextCenter("Movement", true)
    end

    if AMM.userSettings.floatingTargetTools then
      local buttonLabel = "Open Target Tools"
      if Tools.movementWindow.open then
        buttonLabel = "Close Target Tools"
      end

      if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
        if Tools.movementWindow.open then
          Tools.movementWindow.open = false
          Tools.movementWindow.isEditing = false
        else
          Tools:OpenMovementWindow()
        end
      end
    else
      Tools.movementWindow.open = true
      Tools:DrawMovementWindow()
    end
  else
    AMM.UI:Spacing(3)

    if AMM.playerInPhoto then
      AMM.UI:TextCenter("Target V or NPC to see More Actions")
    else
      AMM.UI:TextCenter("Target NPC or Prop to see More Actions")
    end

    AMM.UI:Spacing(4)
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
      Tools:UseGeneralAction(function(ent) Tools:SetNPCAttitude(ent, "friendly") end, 10)
    end

    ImGui.SameLine()
    if ImGui.Button("All Follower", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) AMM.Spawn:SetNPCAsCompanion(ent.handle) end, 10)
    end

    if ImGui.Button("All Fake Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) ent.handle:SendAIDeathSignal() end, 20)
    end

    ImGui.SameLine()
    if ImGui.Button("All Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) ent.handle:Kill(ent.handle, false, false) end, 20)
    end

    if ImGui.Button("All Despawn", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) ent.handle:Dispose() end, 20)
    end

    ImGui.SameLine()
    if ImGui.Button("Cycle Appearance", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) AMM:ChangeScanAppearanceTo(ent, "Cycle") end, 20)
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

function Tools:SetCurrentTarget(target, systemActivated)
  local pos, angles
  target.appearance = AMM:GetAppearance(target)
  Tools.currentNPC = target

  if not systemActivated then
    local light = AMM.Light:GetLightData(target)
    local workspotMarker = Util:IsCustomWorkspot(target.handle)

    if Tools.lockTargetPinID ~= nil then
      Game.GetMappinSystem():UnregisterMappin(Tools.lockTargetPinID)
    end

    if drawWindow and not workspotMarker and not light and Tools.lockTarget and target.type ~= 'entEntity' then
      Tools.lockTargetPinID = Util:SetMarkerOverObject(target.handle, gamedataMappinVariant.FastTravelVariant)
    end
  end

  local npcHash = tostring(Tools.currentNPC.handle:GetEntityID().hash)

  if Tools.lookAtActiveNPCs[npcHash] then
    local lookAtSettings = Tools.lookAtActiveNPCs[npcHash]
    Tools.selectedLookAt = lookAtSettings.mode

    if lookAtSettings.headSettings then
      Tools.headStiffness = lookAtSettings.headSettings.weight
      Tools.headPoseOverride = lookAtSettings.headSettings.suppress
    end

    if lookAtSettings.chestSettings then
      Tools.chestStiffness = lookAtSettings.chestSettings.weight
      Tools.chestPoseOverride = lookAtSettings.chestSettings.suppress
    end
  else
    Tools:ResetLookAt()
  end

  Tools.currentTargetComponents = nil

  if Tools.currentNPC.type == 'entEntity' then
    pos = Tools.currentNPC.parameters[1]
    angles = Tools.currentNPC.parameters[2]
  else
    pos = Tools.currentNPC.handle:GetWorldPosition()
    angles = GetSingleton('Quaternion'):ToEulerAngles(Tools.currentNPC.handle:GetWorldOrientation())
  end

  Tools.npcRotation = {angles.roll, angles.pitch, angles.yaw}

  if Tools.relativeMode then
    Tools.npcLeft = 0
    Tools.npcRight = 0
    Tools.npcUpDown = 0
  else
    Tools.npcLeft = pos.x
    Tools.npcRight = pos.y
    Tools.npcUpDown = pos.z
  end
end

function Tools:ActivateFacialExpression(target, face)

  Tools.activatedFace = true

  local stimComp = target.handle:FindComponentByName("ReactionManager")
  local animComp = target.handle:FindComponentByName("AnimationControllerComponent")

  if stimComp and animComp then
    stimComp:ResetFacial(0)

    Cron.After(0.5, function()
      local animFeat = NewObject("handle:AnimFeature_FacialReaction")
      animFeat.category = face.category
      animFeat.idle = face.idle
      animComp:ApplyFeature(CName.new("FacialReaction"), animFeat)
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
    Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = true
  else
    handle:SetIndividualTimeDilation(CName.new("AMM"), 1.0, 2.5, CName.new(""), CName.new(""), false)
    Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] = nil
  end
end

function Tools:PickupTarget(target)
  Tools.holdingNPC = not Tools.holdingNPC
  Tools.lockTarget = true

  if target then
    Tools:SetCurrentTarget(target)

    local handle = target.handle

    if handle:IsNPC() then
      Tools:FreezeNPC(handle, true)
      handle:GetAIControllerComponent():DisableCollider()
    end

    Cron.Every(0.000001, function(timer)
      local pos = AMM.player:GetWorldPosition()
      local heading = AMM.player:GetWorldForward()
      local currentPos = Tools.currentNPC.handle:GetWorldPosition()
      local offset = 1
      if handle:IsNPC() then offset = 2 end
      local newPos = Vector4.new(pos.x + (heading.x * offset), pos.y + (heading.y * offset), currentPos.z, pos.w)

      if Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC() then
        Tools:TeleportNPCTo(handle, newPos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(handle, newPos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end

      if Tools.holdingNPC == false then
        if handle:IsNPC() then
          Tools:FreezeNPC(handle, false)
          handle:GetAIControllerComponent():EnableCollider()
        end
        Cron.Halt(timer)
      end
    end)
  end
end

function Tools:ProtectTarget(t)
  local newMappinID = Util:SetMarkerOverObject(t.handle, gamemappinVariant.QuestGiverVariant)
  Tools.protectedNPCs[target.handle:GetEntityID().hash] = newMappinID
end

function Tools:UseGeneralAction(action, range)
  local entities = Util:GetNPCsInRange(range)
  for _, ent in ipairs(entities) do
    if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
      action(ent)
    end
  end

  Tools:ClearProtected()
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

function Tools:OpenMovementWindow()
  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  if x < ImGui.GetFontSize() * 40 then
    ImGui.SetNextWindowPos(x + (sizeX + 50), y - 40)
  else
    ImGui.SetNextWindowPos(x - (sizeX + 200), y - 40)
  end

  Tools.movementWindow.isEditing = true
end

function Tools:DrawMovementWindow()
  if AMM.userSettings.floatingTargetTools then
    Tools.movementWindow.open = ImGui.Begin("Target Tools", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoCollapse)
  end

  if Tools.movementWindow.open then
    Tools.movementWindow.isEditing = true

    if not Tools.lockTarget or Tools.currentNPC == '' then
      Tools.lockTarget = false
      if target == nil and Tools.currentNPC ~= '' and Tools.currentNPC.type ~= "Player" then
        Tools.currentNPC = ''
      elseif Tools.currentNPC == '' or (not(Tools.holdingNPC) and (target ~= nil and Tools.currentNPC.handle:GetEntityID().hash ~= target.handle:GetEntityID().hash)) then
        Tools:SetCurrentTarget(target, true)
      end

      Tools.currentTargetComponents = nil
    end

    if Tools.currentNPC and Tools.currentNPC ~= '' then
      ImGui.PushTextWrapPos(300)
      ImGui.TextWrapped(Tools.currentNPC.name)
      ImGui.PopTextWrapPos()

      if AMM.playerInPhoto and AMM.playerInVehicle and Tools.currentNPC.type == "Player" then
        local mountedVehicle = Util:GetMountedVehicleTarget()
        if mountedVehicle then Tools.currentNPC.handle = mountedVehicle.handle end
      end
    end

    local buttonLabel = " Lock Target "
    if Tools.lockTarget then
      buttonLabel = " Unlock Target "
    end

    ImGui.SameLine()
    if ImGui.SmallButton(buttonLabel) then
      Tools.lockTarget = not Tools.lockTarget
      Tools:SetCurrentTarget(Tools.currentNPC)
    end

    if AMM.userSettings.floatingTargetTools then
      ImGui.SameLine(500)
      if ImGui.Button(" Close Window ") then
        Tools.movementWindow.open = false
      end
    end

    local adjustmentValue = 0.01
    if Tools.precisonMode then adjustmentValue = 0.001 end

    local width = ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Tilt/Rotation ")
    ImGui.PushItemWidth(width)
    Tools.npcUpDown, upDownUsed = ImGui.DragFloat("Up/Down", Tools.npcUpDown, adjustmentValue)
    ImGui.PopItemWidth()

    if Tools.relativeMode and ImGui.IsItemDeactivatedAfterEdit() then
      Tools.npcUpDown = 0
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
    local up = {x = 0, y = 0, z = 0}
    local pos = nil

    if Tools.currentNPC ~= '' then
      if Tools.relativeMode then
        forward = Tools.currentNPC.handle:GetWorldForward()
        right = Tools.currentNPC.handle:GetWorldRight()
        up = Tools.currentNPC.handle:GetWorldUp()
      end

      pos = Tools.currentNPC.handle:GetWorldPosition()

      if upDownUsed then
        local z = Tools.npcUpDown
        local targetZ = Tools.npcUpDown

        if Tools.relativeMode then
          targetZ = pos.z
        end

        pos = Vector4.new(pos.x + (up.x * z), pos.y + (up.y * z), targetZ + (up.z * z), pos.w)
      end

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

    if upDownUsed and Tools.currentNPC ~= '' then
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

    if (leftUsed or rightUsed) and Tools.currentNPC ~= '' then
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

    if Tools.currentNPC ~= '' and (Tools.currentNPC.type ~= 'Prop' and Tools.currentNPC.type ~= 'entEntity' and Tools.currentNPC.type ~= 'Player' and Tools.currentNPC.handle:IsNPC()) then
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
        Tools.npcUpDown = 0
      else
        local pos = Tools.currentNPC.handle:GetWorldPosition()
        Tools.npcLeft = pos.x
        Tools.npcRight = pos.y
        Tools.npcUpDown = pos.z
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

      if Tools.currentNPC.type == "vehicle" then
        local heading = AMM.player:GetWorldForward()
        pos = Vector4.new(pos.x + (heading.x * 2), pos.y + (heading.y * 2), pos.z + heading.z, pos.w + heading.w)
      end

      Tools:SetTargetPosition(pos)
    end

    AMM.UI:Spacing(3)

    if not AMM.playerInPhoto and Tools.currentNPC ~= '' and Tools.currentNPC.type ~= 'entEntity' then

      local buttonLabel = "Pick Up Target"
      if Tools.holdingNPC then
        buttonLabel = "Drop Target"
      end

      local buttonWidth = Tools.style.buttonWidth
      if Tools.currentNPC.handle:IsNPC() then
        buttonWidth = Tools.style.halfButtonWidth
      end

      if ImGui.Button(buttonLabel, buttonWidth, Tools.style.buttonHeight) then
        Tools:PickupTarget(Tools.currentNPC)
      end

      ImGui.SameLine()
    end

    if Tools.currentNPC ~= '' and (Tools.currentNPC.type ~= 'Prop' and Tools.currentNPC.type ~= 'entEntity'
    and Tools.currentNPC.handle:IsNPC()) then

      if not AMM.playerInPhoto or AMM.userSettings.freezeInPhoto then
        local buttonLabel = " Freeze Target "
        if Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] then
          buttonLabel = " Unfreeze Target "
        end

        local buttonWidth = Tools.style.halfButtonWidth
        if AMM.playerInPhoto then buttonWidth = Tools.style.buttonWidth end

        if ImGui.Button(buttonLabel, buttonWidth, Tools.style.buttonHeight) then
          local frozen = not(Tools.frozenNPCs[tostring(Tools.currentNPC.handle:GetEntityID().hash)] == true)
          Tools:FreezeNPC(Tools.currentNPC.handle, frozen)
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
                  for _, spawn in pairs(AMM.Spawn.spawnedNPCs) do
                    if currentNPC.id == spawn.id or Util:CheckVByID(currentNPC.id) then currentNPC = spawn break end
                  end
                end

                Tools.currentNPC = ''
                AMM.Spawn:DespawnNPC(currentNPC)

                Cron.After(0.5, function()
                  AMM.Spawn:SpawnNPC(currentNPC)
                end)
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
          Tools:ActivateFacialExpression(Tools.currentNPC, Tools.selectedFace)
        end

        ImGui.Spacing()

        if not AMM.playerInPhoto and Tools.currentNPC ~= '' then

          AMM.UI:Spacing(4)

          local npcHash = tostring(Tools.currentNPC.handle:GetEntityID().hash)

          AMM.UI:TextCenter("Look At", true)
          for _, option in ipairs(Tools.lookAtOptions) do
            if ImGui.RadioButton(option.name, Tools.selectedLookAt.name == option.name) then
              Tools.selectedLookAt = option
              if Tools.lookAtActiveNPCs[npcHash] then Tools:ActivateLookAt() end
            end

            ImGui.SameLine()
          end

          ImGui.Dummy(20, 20)

          ImGui.SameLine()

          local reset = false
          if ImGui.SmallButton("Reset") then
            Tools:ResetLookAt()
            reset = true
          end

          ImGui.Spacing()

          if Tools.selectedLookAt.name ~= "Eyes Only" then
            Tools.headStiffness, used = ImGui.SliderFloat("Head Stiffness", Tools.headStiffness, 0.0, 1.0, "%.1f")
            if Tools.lookAtActiveNPCs[npcHash] and (used or reset) then Tools:ActivateLookAt() end

            Tools.headPoseOverride, used = ImGui.SliderFloat("Head Pose Override", Tools.headPoseOverride, 0.0, 1.0, "%.1f")
            if Tools.lookAtActiveNPCs[npcHash] and (used or reset) then Tools:ActivateLookAt() end
          end

          if Tools.selectedLookAt.name == "All" then
            Tools.chestStiffness, used = ImGui.SliderFloat("Chest Stiffness", Tools.chestStiffness, 0.0, 2.0, "%.1f")
            if Tools.lookAtActiveNPCs[npcHash] and (used or reset) then Tools:ActivateLookAt() end

            Tools.chestPoseOverride, used = ImGui.SliderFloat("Chest Pose Override", Tools.chestPoseOverride, 0.0, 2.0, "%.1f")
            if Tools.lookAtActiveNPCs[npcHash] and (used or reset) then Tools:ActivateLookAt() end
          end

          AMM.UI:Spacing(4)

          ImGui.Text("Current Target:")

          ImGui.SameLine()
          local lookAtTargetName = "V"
          if Tools.lookAtTarget ~= nil then
            lookAtTargetName = Tools.lookAtTarget.name
          end

          AMM.UI:TextColored(lookAtTargetName)

          AMM.UI:Spacing(3)

          local availableTargets = {}

          table.insert(availableTargets, {name = "V", handle = Game.GetPlayer()})

          for _, spawned in pairs(AMM.Spawn.spawnedNPCs) do
            if Tools.currentNPC.hash ~= spawned.hash then
              table.insert(availableTargets, spawned)
            elseif Tools.currentNPC.hash == spawned.hash then
              Tools.currentNPC = spawned
            end
          end

          if Tools.currentNPC ~= '' then
            table.insert(availableTargets, Tools.currentNPC)
          end

          if ImGui.BeginCombo("Look At Target", lookAtTargetName) then
            for i, t in ipairs(availableTargets) do
              if ImGui.Selectable(t.name.."##"..i, (t.name == lookAtTargetName)) then
                lookAtTargetName = t.name
                Tools.lookAtTarget = t
              end
            end
            ImGui.EndCombo()
          end

          local buttonLabel = "Activate Look At"
          if Tools.lookAtActiveNPCs[npcHash] then
            buttonLabel = "Deactivate Look At"
          end

          if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then

            if Tools.lookAtActiveNPCs[npcHash] == nil then
              Tools:ActivateLookAt()
            else
              Tools.lookAtActiveNPCs[npcHash] = nil
              local stimComp = Tools.currentNPC.handle:GetStimReactionComponent()
              stimComp:DeactiveLookAt()
            end
          end

          if ImGui.Button("Reset Target", Tools.style.buttonWidth, Tools.style.buttonHeight) then
            if target ~= nil then
              Tools.lookAtTarget = nil
            end
          end
        end
      end

      if AMM.userSettings.experimental and Tools.currentNPC ~= '' and Tools.currentNPC.handle:IsNPC() then

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
    elseif Tools.currentNPC and Tools.currentNPC ~= '' then

      if Tools.currentTargetComponents == nil then
        Tools.currentTargetComponents = AMM.Props:CheckForValidComponents(Tools.currentNPC.handle)
      end

      local components = Tools.currentTargetComponents

      AMM.UI:Spacing(8)

      AMM.UI:TextCenter("Scale", true)

      if components then

        local scaleChanged = false
        if Tools.scaleWidth == nil or Tools.scaleWidth < 50 then
          Tools.scaleWidth = ImGui.GetWindowContentRegionWidth()
        end

        if Tools.proportionalMode then
          ImGui.PushItemWidth(Tools.scaleWidth)
          Tools.currentNPC.scale.x, scaleChanged = ImGui.DragFloat("##scale", Tools.currentNPC.scale.x, 0.1)
          ImGui.PopItemWidth()

          if scaleChanged then
            Tools.currentNPC.scale.y = Tools.currentNPC.scale.x
            Tools.currentNPC.scale.z = Tools.currentNPC.scale.x
          end
        else
          ImGui.PushItemWidth((Tools.scaleWidth / 3) - 8)
          Tools.currentNPC.scale.x, used = ImGui.DragFloat("##scaleX", Tools.currentNPC.scale.x, 0.1)
          if used then scaleChanged = true end
          ImGui.SameLine()
          Tools.currentNPC.scale.y, used = ImGui.DragFloat("##scaleY", Tools.currentNPC.scale.y, 0.1)
          if used then scaleChanged = true end
          ImGui.SameLine()
          Tools.currentNPC.scale.z, used = ImGui.DragFloat("##scaleZ", Tools.currentNPC.scale.z, 0.1)
          if used then scaleChanged = true end
          ImGui.PopItemWidth()
        end

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

    if Tools.currentNPC and Tools.currentNPC ~= '' then
      if AMM.Light:GetLightComponent(Tools.currentNPC.handle) then
        AMM.UI:Spacing(8)

        AMM.UI:TextCenter("Light Control", true)

        if ImGui.Button("Toggle Light", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
          if AMM.Props.hiddenProps[Tools.currentNPC.hash] then
            AMM.Props.hiddenProps[Tools.currentNPC.hash] = nil
          end
          AMM.Light:ToggleLight(AMM.Light:GetLightData(Tools.currentNPC))
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
    end
  end

  if AMM.userSettings.floatingTargetTools then
    ImGui.End()
  end

  if not(Tools.movementWindow.open) and Tools.movementWindow.isEditing then
    Tools.movementWindow.isEditing = false
  end
end

-- Time actions
function Tools:DrawTimeActions()
  -- AMM.UI:TextColored("Time Actions:")

  local gameTime = Tools:GetCurrentHour()
  Tools.timeValue = Tools:ConvertTime(gameTime)

  ImGui.PushItemWidth((ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Time of Day ")) - 82)

  Tools.timeValue, changeTimeUsed = ImGui.SliderInt("##", Tools.timeValue, 0, 1440, "")

  ImGui.PopItemWidth()

  ImGui.SameLine()

  if ImGui.Button("-", 32, 32) then
    if Tools.timeValue < 0 then
      Tools.timeValue = 1440
    end

    Tools.timeValue = Tools.timeValue - 1
    changeTimeUsed = true
  end

  ImGui.SameLine()

  if ImGui.Button("+", 32, 32) then
    if Tools.timeValue > 1440 then
      Tools.timeValue = 0
    end

    Tools.timeValue = Tools.timeValue + 2
    changeTimeUsed = true
  end

  ImGui.SameLine()

  ImGui.Text("Time of Day")

  if changeTimeUsed then
    if Tools.relicEffect then
      Tools:SetRelicEffect(false)
      Cron.After(60.0, function()
        Tools:SetRelicEffect(true)
      end)
    end

    Tools:SetTime(Tools.timeValue)
  end

  ImGui.PushItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Time of Day "))

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
      Cron.Every(5, function(timer)
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
  if Tools.relicOriginalFlats == nil then
    Tools.relicOriginalFlats = Tools:GetRelicFlats()
  end

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

-- Photo Mode Enhancements
function Tools:DrawPhotoModeEnhancements()

  if AMM.CETVersion >= 18 and AMM.userSettings.photoModeEnhancements then
    Tools.defaultAperture = ImGui.SliderFloat("Default Aperture", Tools.defaultAperture, 1.2, 16, "%.1f")
    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("Requires game restart to take effect")
    end

    Tools.defaultFOV = ImGui.SliderInt("Default Field of View", Tools.defaultFOV, 15, 90)
    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("Requires game restart to take effect")
    end

    AMM.UI:Spacing(4)
  end

  AMM.UI:TextColored("Look At Camera:")
  for _, option in ipairs(Tools.lookAtOptions) do
    if ImGui.RadioButton(option.name, Tools.selectedLookAt.name == option.name) then
      Tools.selectedLookAt = option
      TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.lookAtParts', Tools.selectedLookAt.parts)
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("Turn Look At Camera option OFF once after changing this setting")
    end

    ImGui.SameLine()
  end

  ImGui.Dummy(20, 20)

  ImGui.SameLine()

  local reset = false
  if ImGui.SmallButton("Reset") then
    TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.lookAtParts', Tools.selectedLookAt.parts)
    Tools:ResetLookAt()
    reset = true
  end

  ImGui.Spacing()

  Tools.lookAtSpeed, used = ImGui.SliderFloat("Movement Speed", Tools.lookAtSpeed, 0.0, 140.0, "%.1f")
  if used or reset then
    TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.outTransitionSpeed', Tools.lookAtSpeed)
    TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.transitionSpeed', Tools.lookAtSpeed)
  end

  if Tools.selectedLookAt.name ~= "Eyes Only" then
    Tools.headStiffness, used = ImGui.SliderFloat("Head Stiffness", Tools.headStiffness, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline0.weight', Tools.headStiffness) end

    Tools.headPoseOverride, used = ImGui.SliderFloat("Head Pose Override", Tools.headPoseOverride, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline0.suppress', Tools.headPoseOverride) end
  end

  if Tools.selectedLookAt.name == "All" then
    Tools.chestStiffness, used = ImGui.SliderFloat("Chest Stiffness", Tools.chestStiffness, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline1.weight', Tools.chestStiffness) end

    Tools.chestPoseOverride, used = ImGui.SliderFloat("Chest Pose Override", Tools.chestPoseOverride, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline1.suppress', Tools.chestPoseOverride) end
  end

  ImGui.Spacing()

  AMM.UI:TextWrappedWithColor("Disable 'Look At Camera' in Photo Mode once to take effect", "ButtonActive")

  AMM.UI:Spacing(3)

  Tools.cursorDisabled, clicked = ImGui.Checkbox("Disable Photo Mode Cursor", Tools.cursorDisabled)
  if clicked then
    Tools:ToggleCursor()
  end

  if Tools.cursorDisabled then
    ImGui.SameLine()
    Tools.cursorStateLock = ImGui.Checkbox("Lock State", Tools.cursorStateLock)
  end
end

-- Utilities
function Tools:ToggleCursor(systemActivated)
  if systemActivated then
    Tools.cursorDisabled = not Tools.cursorDisabled
  end

  if Tools.cursorController then
    local context = "Show"
    if Tools.cursorDisabled then context = "Hide" end
    Tools.cursorController:ProcessCursorContext(CName.new(context), nil)
  end
end

function Tools:ToggleLookAtMarker(active)
  if Tools.lockTargetPinID ~= nil then
    Game.GetMappinSystem():SetMappinActive(Tools.lockTargetPinID, active)
  end
end

function Tools:ResetLookAt()
  Tools.selectedLookAt = Tools.lookAtOptions[1]
  Tools.headStiffness = 0.0
  Tools.headPoseOverride = 1.0
  Tools.chestStiffness = 0.1
  Tools.chestPoseOverride = 0.5
  Tools.lookAtSpeed = 140.0
end

function Tools:ActivateLookAt()
  local headSettings = nil
  local chestSettings = nil

  if Tools.selectedLookAt.name ~= "Eyes Only" then
    headSettings = {weight = Tools.headStiffness, suppress = Tools.headPoseOverride}
  end

  if Tools.selectedLookAt.name == "All" then
    chestSettings = {weight = Tools.chestStiffness, suppress = Tools.chestPoseOverride}
  end

  local npcHash = tostring(Tools.currentNPC.handle:GetEntityID().hash)

  if Tools.lookAtActiveNPCs[npcHash] == nil then
    Tools.lookAtActiveNPCs[npcHash] = {
      mode = Tools.selectedLookAt,
      headSettings = headSettings,
      chestSettings = chestSettings
    }
  end

  Util:NPCLookAt(Tools.currentNPC.handle, Tools.lookAtTarget, headSettings, chestSettings)
end

function Tools:ShouldCrouchButtonAppear(spawn)
  if spawn.type == 'Spawn' then return true end

  for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
    if ent.hash == spawn.hash then return true end
  end

  return false
end

function Tools:EnterPhotoMode()

  if AMM.Director.activeCamera then
    AMM.Director.activeCamera:Deactivate(0)
    AMM.Director.activeCamera = nil
  end

  Cron.Every(0.1, { tick = 1 }, function(timer)

    if AMM.playerInVehicle or Util:GetMountedVehicleTarget() then
      AMM.playerInVehicle = true
      Tools.photoModePuppet = Game.GetPlayer()
    end

    if Tools.photoModePuppet then
      AMM.playerInPhoto = true
      Game.SetTimeDilation(0)
      
      if Tools.cursorStateLock then
        Tools:ToggleCursor(true)
      end

      Cron.Halt(timer)
    end

    timer.tick = timer.tick + 1

    if timer.tick > 10 then
      Cron.Halt(timer)
    end
  end)

  if Tools.savePhotoModeToggles then
    Cron.After(1.0, function()
      if not Tools.makeupToggle then
        Tools.makeupToggle = true
        Tools:ToggleMakeup()
      end
      if not Tools.accessoryToggle then
        Tools.accessoryToggle = true
        Tools:ToggleAccessories()
      end
      if not Tools.seamfixToggle then
        Tools.seamfixToggle = true
        Tools:ToggleSeamfix()
      end
    end)
  end

  if Tools.invisibleBody then
    Cron.After(1.0, function()
      local v = Tools:GetVTarget()
      Tools:ToggleInvisibleBody(v.handle)
    end)
  end
end

function Tools:ExitPhotoMode()
  AMM.playerInPhoto = false
  Tools.photoModePuppet = nil
  Tools.cursorDisabled = false

  -- Trigger User Data save in case the user changed FOV and Aperture defaults
  AMM:UpdateSettings()

  if Tools.lookAtLocked then
    Tools:ToggleLookAt()
  end

  if not Tools.savePhotoModeToggles then
  Tools.makeupToggle = true
  Tools.accessoryToggle = true
  Tools.seamfixToggle = true
  end

  if next(AMM.Props.hiddenProps) ~= nil then
    for _, prop in pairs(AMM.Props.hiddenProps) do  
      AMM.Props:ToggleHideProp(prop.ent)
    end
  end

  local c = Tools.slowMotionSpeed
  if c ~= 1 then
    Tools:SetSlowMotionSpeed(c)
  else
    if Tools.timeState == false then
      Tools:SetSlowMotionSpeed(0)
    else
      Tools:SetSlowMotionSpeed(1)
    end
  end
end

return Tools:new()
