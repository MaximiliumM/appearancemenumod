Tools = {}

-- ALIAS for string.format --
local f = string.format
local Util = require('Modules/util.lua')

-- Hacky Fix cause I'm dumb --
-- I was using it as global from int.lua when I first built this
-- Now that I properly made it as local, it broke everything
local target = nil

-- Constant --
local PLAYER_TRIGGER_DIST = 5

function Tools:new()

  -- Layout Properties
  Tools.isOpen = false
  Tools.style = {}
  Tools.actionCategories = {}
  Tools.movementWindow = {open = false, isEditing = false, shouldDraw = false}
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
  Tools.locationSearch = ''
  Tools.lastLocationSearch = ''
  Tools.selectedLocation = {loc_name = "Select Location"}
  Tools.shareLocationName = ''
  Tools.locations = {}
  Tools.defaultLocations = {}
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
  Tools.currentTarget = ''
  Tools.lockTarget = false
  Tools.lockTargetPinID = nil
  Tools.precisionMode = false
  Tools.relativeMode = false
  Tools.directMode = false
  Tools.proportionalMode = true
  Tools.isCrouching = false
  Tools.npcUpDown = 0
  Tools.npcLeft = 0
  Tools.npcRight = 0
  Tools.npcRotation = 0
  Tools.advRotationRoll = 90
  Tools.advRotationPitch = 90
  Tools.advRotationYaw = 90
  Tools.movingProp = false
  Tools.savedPosition = ''
  Tools.selectedFace = {name = 'Select Expression'}
  Tools.activatedFace = false
  Tools.lookAtActiveNPCs = {}
  Tools.lookAtTarget = nil
  Tools.expressions = AMM:GetPersonalityOptions()
  Tools.photoModePuppet = nil
  Tools.currentTargetComponents = nil
  Tools.enablePropsInLookAtTarget = false

  -- Axis Indicator Properties --
  Tools.axisIndicator = nil
  Tools.axisIndicatorToggle = false

  -- Nibbles Replacer Properties --
  Tools.cachedReplacerOptions = nil
  Tools.nibblesOG = nil
  Tools.selectedNibblesEntity = 1
  Tools.replacer = require("Collabs/Photomode_NPCs_AMM.lua")
  Tools.nibblesEntityOptions = {}

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

  -- Do not put in cron - will cause stutters or even crashes with >200 locations
    Tools.locations = Tools:GetLocations()
  
  -- Set Target Tools to Open on Launch
  if AMM.userSettings.floatingTargetTools and AMM.userSettings.autoOpenTargetTools then
    Tools.movementWindow.open = true
  end

  -- Set Default for Axis Indicator --
  if AMM.userSettings.axisIndicatorByDefault then
    Tools.axisIndicatorToggle = true
  end

  -- Setup Nibbles Replacer --
  if Tools.replacer then
    Tools.nibblesEntityOptions = Tools.replacer.entityOptions
    Tools:SetupReplacerAppearances()

    local selectedEntity = Tools.nibblesEntityOptions[Tools.selectedNibblesEntity]
    Tools:UpdateNibblesEntity(selectedEntity.ent)
  end
end

function Tools:Draw(AMM, t)
  -- Setting target to local variable
  target = t

  Tools.style = {
    buttonHeight = ImGui.GetFontSize() * 2,
    buttonWidth = ImGui.GetWindowContentRegionWidth(),
    halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 8)
  }

  -- Util Popup Helper --
  Util:SetupPopup()

  -- Tools Tab State --
  Tools.isOpen = false

  if ImGui.BeginTabItem("Tools") then

    Tools.isOpen = true

    if AMM.nibblesReplacer then
      Tools.actionCategories = {
        { name = "Photo Mode Nibbles Replacer", actions = Tools.DrawNibblesReplacer },
        { name = "Target Actions", actions = Tools.DrawNPCActions },
        { name = "Teleport Actions", actions = Tools.DrawTeleportActions },
        { name = "Time Actions", actions = Tools.DrawTimeActions },
        { name = "V Actions", actions = Tools.DrawVActions },
      }
    else
      Tools.actionCategories = {
        { name = "Target Actions", actions = Tools.DrawNPCActions },
        { name = "Teleport Actions", actions = Tools.DrawTeleportActions },
        { name = "Time Actions", actions = Tools.DrawTimeActions },
        { name = "V Actions", actions = Tools.DrawVActions },
      }
    end

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
          AMM.UI:Spacing(3)

          category.actions()

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

  if AMM.playerInPhoto or Util:CheckVByID(Tools.currentTarget.id) then
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
      local buttonLabel = "Target Nibbles"
      if Tools.selectedNibblesEntity ~= 1 then buttonLabel = "Target Replacer" end
      if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
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
        
        if Tools.infiniteOxygen then
          Game.GetStatPoolsSystem():RequestRemovingStatPool(Game.GetPlayer():GetEntityID(), gamedataStatPoolType.Oxygen)
        else
          Game.GetStatPoolsSystem():RequestAddingStatPool(Game.GetPlayer():GetEntityID(), TweakDBID.new("BaseStatPools.Player_Oxygen_Base"), true)
        end
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
    Game.GetStatPoolsSystem():RequestRemovingStatPool(Game.GetPlayer():GetEntityID(), gamedataStatPoolType.Health)
    Game.GetStatPoolsSystem():RequestRemovingStatPool(Game.GetPlayer():GetEntityID(), gamedataStatPoolType.Oxygen)
    Game.GetStatPoolsSystem():RequestRemovingStatPool(Game.GetPlayer():GetEntityID(), gamedataStatPoolType.Stamina)
    Util:ApplyEffectOnPlayer("GameplayRestriction.NoEncumbrance")
  else
    Game.GetStatPoolsSystem():RequestAddingStatPool(Game.GetPlayer():GetEntityID(), TweakDBID.new("BaseStatPools.Player_Health_Base"), true)
    Game.GetStatPoolsSystem():RequestAddingStatPool(Game.GetPlayer():GetEntityID(), TweakDBID.new("BaseStatPools.Player_Oxygen_Base"), true)
    Game.GetStatPoolsSystem():RequestAddingStatPool(Game.GetPlayer():GetEntityID(), TweakDBID.new("BaseStatPools.Player_Stamina_Base"), true)
    Util:RemoveEffectOnPlayer("GameplayRestriction.NoEncumbrance")
  end
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
  local slot = TweakDBID.new("AttachmentSlots.TppHead")

  local fppHead = ItemID.FromTDBID(TweakDBID.new("Items.PlayerFppHead"))

  if ts:HasItem(Game.GetPlayer(), itemID) == false then
    Util:AddToInventory(headItem)
  end

  ts:AddItemToSlot(Game.GetPlayer(), slot, itemID)

  if Tools.tppHead then
    Cron.Every(0.001, { tick = 1 }, function(timer)

      timer.tick = timer.tick + 1

      if timer.tick > 20 then
        Cron.Halt(timer)
      end

      Cron.After(0.01, function()
        ts:RemoveItemFromSlot(Game.GetPlayer(), slot, true, true, true)
      end)

      Cron.After(0.1, function()
        ts:AddItemToSlot(Game.GetPlayer(), slot, itemID)
      end)
    end)
  else
    if ts:GetItemInSlot(Game.GetPlayer(), slot) ~= nil then
      ts:RemoveItemFromSlot(Game.GetPlayer(), slot, true, true, true)
      ts:AddItemToSlot(Game.GetPlayer(), slot, fppHead)
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
    if Util:CheckNibblesByID(Tools.currentTarget.id) then
      return Tools.currentTarget
    else
      return nil
    end
  end

  return AMM:NewTarget(nibbles, "NPCPuppet", AMM:GetScanID(nibbles), AMM:GetNPCName(nibbles),AMM:GetScanAppearance(nibbles), nil)
end

function Tools:GetVTarget()
  local entity = Tools.photoModePuppet
  if not entity then
    if Util:CheckVByID(Tools.currentTarget.id) then
      return Tools.currentTarget
    else
      return nil
    end
  end

  return AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), AMM:GetNPCName(entity),AMM:GetScanAppearance(entity), nil)
end

local locationRefreshDebounce = false
local function refreshLocationListDebounced()
  -- don't refresh if semaphore is set
  if locationRefreshDebounce then return end
  
  -- set variable, refresh tools
  locationRefreshDebounce = true  
  Tools.locations = Tools:GetLocations()
  
  -- unset variable in 10 seconds
  Cron.After(10, function()
    locationRefreshDebounce = false
  end)
end

-- Teleport actions
function Tools:DrawTeleportActions()

  ImGui.PushItemWidth(250)
  Tools.locationSearch = ImGui.InputTextWithHint(" ", "Filter Locations", Tools.locationSearch, 100)
  Tools.locationSearch = Tools.locationSearch:gsub('"', '')
  ImGui.PopItemWidth()

  if (Tools.locationSearch ~= '' or Tools.locationSearch == '') and Tools.locationSearch ~= Tools.lastLocationSearch then
    Tools.lastLocationSearch = Tools.locationSearch
    Tools.locations = Tools:GetLocations()
  end

  ImGui.SameLine()
  
  if ImGui.BeginCombo("Locations", Tools.selectedLocation.loc_name, ImGuiComboFlags.HeightLarge) then
    for i, location in ipairs(Tools.locations) do
      if location.loc_name then
        if ImGui.Selectable(location.loc_name.."##"..i, (location == Tools.selectedLocation.loc_name)) then
          if location.loc_name:match("%-%-%-%-") == nil then
            Tools.selectedLocation = location
          end
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
    refreshLocationListDebounced()
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
        if not(io.open(f("./User/Locations/%s.json", Tools.shareLocationName), "r")) then
          local currentLocation = Tools:GetPlayerLocation()
          local newLoc = Tools:NewLocationData(Tools.shareLocationName, currentLocation)
          Tools:SaveLocation(newLoc)
          Tools.locations = Tools:GetLocations()
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

  Tools.userLocations = Tools:GetUserLocations()

  local separator = false
  local locations = {}

  if next(Tools.favoriteLocations) ~= nil then
    table.insert(locations, {loc_name = '--------- Favorites ----------'})

    for _, loc in ipairs(Tools.favoriteLocations) do
      if Tools.locationSearch ~= '' and string.find(loc.loc_name, Tools.locationSearch) then
        table.insert(locations, loc)
      elseif Tools.locationSearch == '' then
        table.insert(locations, loc)
      end
    end

    separator = true
  end

  if next(Tools.userLocations) ~= nil then
    table.insert(locations, {loc_name = '------- User Locations -------'})

    for _, loc in ipairs(Tools.userLocations) do
      if Tools.locationSearch ~= '' and string.find(loc.loc_name, Tools.locationSearch) then
        table.insert(locations, loc)
      elseif Tools.locationSearch == '' then
        table.insert(locations, loc)
      end
    end

    separator = true
  end

  if separator then
    table.insert(locations, {loc_name = '----------- Default ----------'})
  end

  if #Tools.defaultLocations > 0 then
    for _, loc in ipairs(Tools.defaultLocations) do
      if Tools.locationSearch ~= '' and string.find(loc.loc_name, Tools.locationSearch) then
        table.insert(locations, loc)
      elseif Tools.locationSearch == '' then
        table.insert(locations, loc)
      end
    end
  else
    for loc in db:nrows([[SELECT * FROM locations ORDER BY loc_name ASC]]) do
      table.insert(locations, loc)
      table.insert(Tools.defaultLocations, loc)
    end
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
  local file = io.open(f("./User/Locations/%s.json", loc.loc_name), "w")
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
  os.remove("./User/Locations/"..loc.file_name)
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
  local filesCount = #files

  for _, file in ipairs(files) do
    if string.find(file.name, '.txt') then
      filesCount = filesCount - 1
    end
  end

  if #Tools.userLocations ~= filesCount then
    local userLocations = {}
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
  local file = io.open('./User/Locations/'..loc, 'r')
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

  if Tools.currentTarget and Tools.currentTarget ~= '' and Tools.currentTarget.handle then
    if not Game.FindEntityByID(Tools.currentTarget.handle:GetEntityID()) then
      Tools.currentTarget = ''
    end
  end

  if target ~= nil or (Tools.currentTarget and Tools.currentTarget ~= '') then

    if not AMM.userSettings.floatingTargetTools then
      AMM.UI:TextCenter("Movement", true)
    end

    if AMM.userSettings.floatingTargetTools then
      local buttonLabel = "Open Target Tools"
      if Tools.movementWindow.shouldDraw then
        buttonLabel = "Close Target Tools"
      end

      if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
        if Tools.movementWindow.shouldDraw then
          Tools.movementWindow.shouldDraw = false
          Tools.movementWindow.open = false
        else
          Tools:OpenMovementWindow()
        end
      end
    else
      Tools.movementWindow.shouldDraw = true
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
    AMM.UI:Spacing(4)

    AMM.UI:TextCenter("General Actions", true)
    ImGui.Spacing()

    if ImGui.Button("Protect NPC from Actions", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      if target.handle:IsNPC() then
        Tools:ProtectTarget(target)
      end
    end

    if ImGui.Button("All Friendly", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) Tools:SetNPCAttitude(ent, EAIAttitude.AIA_Friendly) end, 10)
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
  if Tools.currentTarget.type == 'entEntity' then
    if not Tools.movingProp then
      Tools:TeleportPropTo(Tools.currentTarget, pos, angles or EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
    end
  elseif Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() then
    local yaw = Tools.npcRotation[3]
    if angles then yaw = angles.yaw end
    Tools:TeleportNPCTo(Tools.currentTarget.handle, pos, yaw)
  else
    Game.GetTeleportationFacility():Teleport(Tools.currentTarget.handle, pos, angles or EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
  end

  Cron.After(0.2, function()
    local hash = Tools.currentTarget.hash
    if AMM.Poses.activeAnims[hash] then
      local anim = AMM.Poses.activeAnims[hash]
      AMM.Poses:RestartAnimation(anim)
    end

    Tools:SetCurrentTarget(Tools.currentTarget)
  end)
end

function Tools:ClearTarget()
  Tools.lockTarget = false
  Tools.currentTarget = ''

  if Tools.lockTargetPinID ~= nil then
    Game.GetMappinSystem():UnregisterMappin(Tools.lockTargetPinID)
  end
end

function Tools:SetCurrentTarget(target, systemActivated)
  if not target and systemActivated and Tools.axisIndicator then
    Tools:ToggleAxisIndicator()
    return
  end
  local pos, angles
  target.appearance = AMM:GetAppearance(target)
  Tools.currentTarget = AMM.Entity:new(target)

  if Tools.axisIndicatorToggle and not systemActivated then
    local timerFunc = function(timer)
      if Tools.currentTarget and Tools.currentTarget.handle then
        local entity = Game.FindEntityByID(Tools.currentTarget.entityID)
        timer.tick = timer.tick + 1
        if entity then
          if Tools.axisIndicator then
            Tools:UpdateAxisIndicatorPosition()
          elseif not Tools.axisIndicator then
            Tools:ToggleAxisIndicator()
          end    
          Cron.Halt(timer)
        elseif timer.tick > 20 then
          Cron.Halt(timer)
        end
      end
    end
  
    Cron.Every(0.1, {tick = 1}, timerFunc)
  end
  
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

  local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)

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

  if Tools.currentTarget.type == 'entEntity' then
    pos = Tools.currentTarget.parameters[1]
    angles = Tools.currentTarget.parameters[2]
  else
    pos = Tools.currentTarget.handle:GetWorldPosition()
    angles = GetSingleton('Quaternion'):ToEulerAngles(Tools.currentTarget.handle:GetWorldOrientation())
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
      
      -- Update Spawned Props dict just in case
      if prop.uniqueName then
        AMM.Props.spawnedProps[prop.uniqueName()] = prop
      end

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
    if AMM.Poses.activeAnims[tostring(handle:GetEntityID().hash)] then
      Game.GetWorkspotSystem():StopInDevice(handle)
    end

    -- (reason: CName, dilation: Float, duration: Float, easeInCurve: CName, easeOutCurve: CName, ignoreGlobalDilation: Bool),
    handle:SetIndividualTimeDilation(CName.new("AMM"), 0.0000000000001, 99, CName.new(""), CName.new(""), true)
    Tools.frozenNPCs[tostring(handle:GetEntityID().hash)] = true
  else
    handle:SetIndividualTimeDilation(CName.new("AMM"), 1.0, 2.5, CName.new(""), CName.new(""), false)
    Tools.frozenNPCs[tostring(handle:GetEntityID().hash)] = nil

    if AMM.Poses.activeAnims[tostring(handle:GetEntityID().hash)] then
      local anim = AMM.Poses.activeAnims[tostring(handle:GetEntityID().hash)]
      
      Cron.Every(0.1, {tick = 1}, function(timer)
        if not Game.GetWorkspotSystem():IsActorInWorkspot(handle) then
          Game.GetWorkspotSystem():PlayInDeviceSimple(anim.handle, handle, false, anim.comp, nil, nil, 0, 1, nil)
          Game.GetWorkspotSystem():SendJumpToAnimEnt(handle, anim.name, true)
        end
        
        Cron.Halt(timer)
      end)
    end
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
      local pos = Game.GetPlayer():GetWorldPosition()
      local heading = Game.GetPlayer():GetWorldForward()
      local currentPos = handle:GetWorldPosition()
      local offset = 1
      if handle:IsNPC() then offset = 2 end
      local newPos = Vector4.new(pos.x + (heading.x * offset), pos.y + (heading.y * offset), currentPos.z, pos.w)

      if Tools.currentTarget.type ~= 'Player' and handle:IsNPC() then
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
  Tools.protectedNPCs[t.handle:GetEntityID().hash] = newMappinID
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
  entity.handle:GetAttitudeAgent():SetAttitudeGroup(Game.GetPlayer():GetAttitudeAgent():GetAttitudeGroup())
	entity.handle:GetAttitudeAgent():SetAttitudeTowards(Game.GetPlayer():GetAttitudeAgent(), attitude)
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

  Tools.movementWindow.open = true
end

function Tools:DrawMovementWindow()
  if AMM.userSettings.floatingTargetTools then
    Tools.movementWindow.open, Tools.movementWindow.shouldDraw = ImGui.Begin("Target Tools", Tools.movementWindow.open, ImGuiWindowFlags.AlwaysAutoResize)
  end

  if Tools.movementWindow.shouldDraw then

    if not Tools.lockTarget or Tools.currentTarget == '' then
      Tools.lockTarget = false
      if target == nil and Tools.currentTarget ~= '' and Tools.currentTarget.type ~= "Player" then
        Tools.currentTarget = ''
      elseif Tools.currentTarget == '' or (not(Tools.holdingNPC) and ((target.handle ~= nil and Tools.currentTarget.handle) and Tools.currentTarget.handle:GetEntityID().hash ~= target.handle:GetEntityID().hash)) then
        Tools:SetCurrentTarget(target, true)
      end

      Tools.currentTargetComponents = nil
    end

    if Tools.currentTarget and Tools.currentTarget ~= '' then
      ImGui.PushTextWrapPos(300)
      ImGui.TextWrapped(Tools.currentTarget.name)
      ImGui.PopTextWrapPos()

      if AMM.playerInPhoto and AMM.playerInVehicle and Tools.currentTarget.type == "Player" then
        local mountedVehicle = Util:GetMountedVehicleTarget()
        if mountedVehicle then Tools.currentTarget.handle = mountedVehicle.handle end
      end
    end

    local buttonLabel = " Lock Target "
    if Tools.lockTarget then
      buttonLabel = " Unlock Target "
    end

    ImGui.SameLine()
    if ImGui.SmallButton(buttonLabel) then
      Tools.lockTarget = not Tools.lockTarget
      Tools:SetCurrentTarget(Tools.currentTarget)
    end

    if AMM.userSettings.experimental then
      ImGui.SameLine()
      if ImGui.SmallButton(" Despawn ") then
        Tools.currentTarget:Despawn()
      end
    end

    ImGui.Spacing()

    local adjustmentValue = 0.01
    if Tools.relativeMode then adjustmentValue = 0.005 end
    if Tools.precisionMode then adjustmentValue = 0.001 end

    local upDownRowWidth = ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("Tilt/Rotation ")

    if Tools.axisIndicator then
      if Tools.relativeMode then
        AMM.UI:PushStyleColor(ImGuiCol.FrameBg, {217, 212, 122, 1})
      else
        AMM.UI:PushStyleColor(ImGuiCol.FrameBg, {227, 42, 21, 1})
      end

      AMM.UI:PushStyleColor(ImGuiCol.Text, {0, 0, 0, 1})
    end

    local surfaceWiseRowWidth = (upDownRowWidth / 3) - 6

    ImGui.PushItemWidth(surfaceWiseRowWidth)
    Tools.npcLeft, leftUsed = ImGui.DragFloat("", Tools.npcLeft, adjustmentValue)

    if Tools.axisIndicator then
      ImGui.PopStyleColor(2)
    end

    if ImGui.IsItemDeactivatedAfterEdit() then
      local hash = Tools.currentTarget.hash
      if AMM.Poses.activeAnims[hash] then
        local anim = AMM.Poses.activeAnims[hash]
        AMM.Poses:RestartAnimation(anim)
      end

      if Tools.axisIndicator then
        Tools:UpdateAxisIndicatorPosition()
      end
    end

    if Tools.relativeMode and ImGui.IsItemDeactivatedAfterEdit() then
      Tools.npcLeft = 0
    end

    if Tools.axisIndicator then
      if Tools.relativeMode then
        AMM.UI:PushStyleColor(ImGuiCol.FrameBg, {227, 42, 21, 1})
      else
        AMM.UI:PushStyleColor(ImGuiCol.FrameBg, {217, 212, 122, 1})
      end

      AMM.UI:PushStyleColor(ImGuiCol.Text, {0, 0, 0, 1})
    end

    ImGui.SameLine()
    Tools.npcRight, rightUsed = ImGui.DragFloat("##Y", Tools.npcRight, adjustmentValue)

    if Tools.axisIndicator then
      ImGui.PopStyleColor(2)
    end

    if ImGui.IsItemDeactivatedAfterEdit() then
      local hash = Tools.currentTarget.hash
      if AMM.Poses.activeAnims[hash] then
        local anim = AMM.Poses.activeAnims[hash]
        AMM.Poses:RestartAnimation(anim)
      end

      if Tools.axisIndicator then
        Tools:UpdateAxisIndicatorPosition()
      end
    end

    if Tools.relativeMode and ImGui.IsItemDeactivatedAfterEdit() then
      Tools.npcRight = 0
    end

    local sliderLabel = "X / Y / Z"
    if Tools.relativeMode then
      sliderLabel = "U-D/F-B/L-R"
    end

    if Tools.axisIndicator then
      AMM.UI:PushStyleColor(ImGuiCol.FrameBg, {79, 169, 195, 1})
      AMM.UI:PushStyleColor(ImGuiCol.Text, {0, 0, 0, 1})

      sliderLabel = "##Z"
    end

    ImGui.SameLine()    

    Tools.npcUpDown, upDownUsed = ImGui.DragFloat(sliderLabel, Tools.npcUpDown, adjustmentValue)

    if Tools.axisIndicator then
      ImGui.PopStyleColor(2)
    end

    if ImGui.IsItemDeactivatedAfterEdit() then
      local hash = Tools.currentTarget.hash
      if AMM.Poses.activeAnims[hash] then
        local anim = AMM.Poses.activeAnims[hash]
        AMM.Poses:RestartAnimation(anim)
      end

      if Tools.axisIndicator then
        Tools:UpdateAxisIndicatorPosition()
      end

      if Tools.axisIndicator then
        Tools:UpdateAxisIndicatorPosition()
      end
    end

    if Tools.relativeMode and ImGui.IsItemDeactivatedAfterEdit() then
      Tools.npcUpDown = 0
    end

    ImGui.PopItemWidth() -- surfaceWiseRowidth

    local forward = {x = 0, y = 0, z = 0}
    local right = {x = 0, y = 0, z = 0}
    local up = {x = 0, y = 0, z = 0}
    local pos = nil

    if Tools.currentTarget ~= '' then
      if Tools.relativeMode then
        forward = Tools.currentTarget.handle:GetWorldForward()
        right = Tools.currentTarget.handle:GetWorldRight()
        up = Tools.currentTarget.handle:GetWorldUp()
      end

      pos = Tools.currentTarget.handle:GetWorldPosition()

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

    if upDownUsed and Tools.currentTarget ~= '' then
      if Tools.currentTarget.type == 'entEntity' then
        if not Tools.movingProp then          
          Tools:TeleportPropTo(Tools.currentTarget, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentTarget.handle, pos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentTarget.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    if (leftUsed or rightUsed) and Tools.currentTarget ~= '' then
      if Tools.currentTarget.type == 'entEntity' then
        if not Tools.movingProp then
          Tools:TeleportPropTo(Tools.currentTarget, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentTarget.handle, pos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentTarget.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end
    end

    local completelyMystifyingAdjustmentToKeepSlidersInBounds = 2
    local rotationRowWidth = upDownRowWidth - completelyMystifyingAdjustmentToKeepSlidersInBounds
    ImGui.PushItemWidth(rotationRowWidth)

    local rotationValue = 0.1
    if Tools.precisionMode then rotationValue = 0.01 end

    local isNPC = false
    if Tools.currentTarget ~= '' and (Tools.currentTarget.type ~= 'Prop' and Tools.currentTarget.type ~= 'entEntity' and Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC()) then
      Tools.npcRotation[3], rotationUsed = ImGui.SliderFloat("Rotation", Tools.npcRotation[3], -180, 180)
      isNPC = true
    elseif Tools.currentTarget ~= '' then
      Tools.npcRotation, rotationUsed = ImGui.DragFloat3("Tilt/Rotation", Tools.npcRotation, 0.1)
    end

    ImGui.PopItemWidth() -- rotationRowWidth

    if ImGui.IsItemDeactivatedAfterEdit() then
      local hash = Tools.currentTarget.hash
      if AMM.Poses.activeAnims[hash] then
        local anim = AMM.Poses.activeAnims[hash]
        AMM.Poses:RestartAnimation(anim)
      end
    end

    local usedRoll, usedPitch, usedYaw = false, false, false

    if AMM.userSettings.advancedRotation then

      if not isNPC then
        ImGui.PushItemWidth((rotationRowWidth / 3) - 82)
      else
        ImGui.PushItemWidth((rotationRowWidth) - 78)
      end

      if not isNPC then
        if AMM.UI:GlyphButton(IconGlyphs.Restore) then
          Tools.npcRotation[1] = Tools.npcRotation[1] - Tools.advRotationRoll
          usedRoll = true
        end

        ImGui.SameLine()

        Tools.advRotationRoll = ImGui.DragInt("##Roll", Tools.advRotationRoll, 1, 0, 360)
        
        ImGui.SameLine()

        if AMM.UI:GlyphButton(IconGlyphs.Reload.."##Roll") then
          Tools.npcRotation[1] = Tools.npcRotation[1] + Tools.advRotationRoll
          usedRoll = true
        end

        ImGui.SameLine()

        if AMM.UI:GlyphButton(IconGlyphs.Restore.."##Roll") then
          Tools.npcRotation[2] = Tools.npcRotation[2] - Tools.advRotationPitch
          usedPitch = true
        end

        ImGui.SameLine()

        Tools.advRotationPitch = ImGui.DragInt("##Pitch", Tools.advRotationPitch, 1, 0, 360)
        
        ImGui.SameLine()

        if AMM.UI:GlyphButton(IconGlyphs.Reload.."##Pitch") then
          Tools.npcRotation[2] = Tools.npcRotation[2] + Tools.advRotationPitch
          usedPitch = true
        end

        ImGui.SameLine()
      end

        if AMM.UI:GlyphButton(IconGlyphs.Restore.."##Yaw") then
          Tools.npcRotation[3] = Tools.npcRotation[3] - Tools.advRotationYaw
          usedYaw = true
        end

        ImGui.SameLine()

        Tools.advRotationYaw = ImGui.DragInt("##Yaw", Tools.advRotationYaw, 1, 0, 360)
        
        ImGui.SameLine()

        if AMM.UI:GlyphButton(IconGlyphs.Reload.."##Yaw") then
          Tools.npcRotation[3] = Tools.npcRotation[3] + Tools.advRotationYaw
          usedYaw = true
        end

        ImGui.PopItemWidth() -- rotationRowWidth / 3
    end

    if (usedRoll or usedPitch or usedYaw or rotationUsed)
    and Tools.currentTarget ~= '' then
      local pos = Tools.currentTarget.handle:GetWorldPosition()
      if Tools.currentTarget.type == 'entEntity' then
        if not Tools.movingProp then
          Tools:TeleportPropTo(Tools.currentTarget, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
        end
      elseif Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() then
        Tools:TeleportNPCTo(Tools.currentTarget.handle, pos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentTarget.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end

      if Tools.axisIndicator then
        Tools:UpdateAxisIndicatorPosition()
      end
    end

    ImGui.Spacing()

    AMM.UI:TextColored("Mode:  ")

    ImGui.SameLine()
    Tools.precisionMode = AMM.UI:SmallCheckbox(Tools.precisionMode, "Precision")

    ImGui.SameLine()
    Tools.relativeMode, relativeToggle = AMM.UI:SmallCheckbox(Tools.relativeMode, "Relative")

    ImGui.SameLine()
    Tools.directMode, directToggle = AMM.UI:SmallCheckbox(Tools.directMode, "Direct")

    ImGui.SameLine()
    AMM.userSettings.advancedRotation = AMM.UI:SmallCheckbox(AMM.userSettings.advancedRotation, "Adv. Rotation")

    ImGui.SameLine()
    Tools.axisIndicatorToggle, axisToggle = AMM.UI:SmallCheckbox(Tools.axisIndicatorToggle, IconGlyphs.AxisArrow)

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("Show X, Y and Z arrows for easier orientation when moving the target.")
    end
    
    if axisToggle then
      Tools:ToggleAxisIndicator()
    end

    if relativeToggle then
      if Tools.axisIndicator then
        Tools:UpdateAxisIndicatorPosition()
      end

      if Tools.relativeMode then
        Tools.npcLeft = 0
        Tools.npcRight = 0
        Tools.npcUpDown = 0
      else
        local pos = Tools.currentTarget.handle:GetWorldPosition()
        Tools.npcLeft = pos.x
        Tools.npcRight = pos.y
        Tools.npcUpDown = pos.z
      end
    end

    if directToggle then
      Tools:ToggleDirectMode()
    end

    if Tools.directMode then
      local speed = Tools.currentTarget.speed * 1000
      speed = ImGui.DragFloat("Movement Speed", speed, 1, 1, 1000, "%.0f")
      Tools.currentTarget.speed = speed / 1000
    end

    AMM.UI:Spacing(3)

    local hash = Tools.currentTarget.hash
    if AMM.Poses.activeAnims[hash] then
      Tools.slowMotionSpeed, slowMotionUsed = ImGui.SliderFloat("Slow Motion", Tools.slowMotionSpeed, 0.000001, Tools.slowMotionMaxValue)
      if slowMotionUsed then
        Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
      end
    end

    AMM.UI:Spacing(3)

    AMM.UI:TextCenter("Position", true)

    local buttonLabel = "Save"
    if Tools.savedPosition ~= '' then
      buttonLabel = "Restore"
    end

    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      if Tools.savedPosition ~= '' then
        Tools:SetTargetPosition(Tools.savedPosition.pos, Tools.savedPosition.angles)
        local components = AMM.Props:CheckForValidComponents(Tools.currentTarget.handle)
        if components then
          Tools:SetScale(components, Tools.savedPosition.scale, Tools.proportionalMode)
          Tools.currentTarget.scale = Util:ShallowCopy({}, Tools.savedPosition.scale)
        end
      else
        Tools.savedPosition = { 
          pos = Tools.currentTarget.handle:GetWorldPosition(),
          angles = GetSingleton('Quaternion'):ToEulerAngles(Tools.currentTarget.handle:GetWorldOrientation()),
          scale = Util:ShallowCopy({}, Tools.currentTarget.scale)
        }
      end
    end    

    ImGui.SameLine()

    if ImGui.Button("Reset To Player", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local pos = AMM.player:GetWorldPosition()

      if Tools.currentTarget.type == "vehicle" then
        local heading = AMM.player:GetWorldForward()
        pos = Vector4.new(pos.x + (heading.x * 2), pos.y + (heading.y * 2), pos.z + heading.z, pos.w + heading.w)
      end

      Tools:SetTargetPosition(pos)
    end

    if Tools.savedPosition ~= '' then
      if ImGui.Button("Clear Saved", Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools.savedPosition = ''
      end
    end

    ImGui.Spacing()

    if not AMM.playerInPhoto and Tools.currentTarget ~= '' and Tools.currentTarget.type ~= 'entEntity' then

      local buttonLabel = "Pick Up Target"
      if Tools.holdingNPC then
        buttonLabel = "Drop Target"
      end

      local buttonWidth = Tools.style.buttonWidth
      if Tools.currentTarget.handle:IsNPC() then
        buttonWidth = Tools.style.halfButtonWidth
      end

      if ImGui.Button(buttonLabel, buttonWidth, Tools.style.buttonHeight) then
        Tools:PickupTarget(Tools.currentTarget)
      end

      ImGui.SameLine()
    end

    if Tools.currentTarget ~= '' and (Tools.currentTarget.type ~= 'Prop' and Tools.currentTarget.type ~= 'entEntity'
    and Tools.currentTarget.handle:IsNPC()) then

      if not AMM.playerInPhoto or AMM.userSettings.freezeInPhoto then
        local buttonLabel = " Freeze Target "
        if Tools.frozenNPCs[tostring(Tools.currentTarget.handle:GetEntityID().hash)] then
          buttonLabel = " Unfreeze Target "
        end

        local buttonWidth = Tools.style.halfButtonWidth
        if AMM.playerInPhoto then buttonWidth = Tools.style.buttonWidth end

        if ImGui.Button(buttonLabel, buttonWidth, Tools.style.buttonHeight) then
          local frozen = not(Tools.frozenNPCs[tostring(Tools.currentTarget.handle:GetEntityID().hash)] == true)
          Tools:FreezeNPC(Tools.currentTarget.handle, frozen)
        end

        if AMM.playerInPhoto then
          if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.PushTextWrapPos(500)
            ImGui.TextWrapped("In Photo Mode, Unfreeze Target will skip frames in animated poses. For the full (un)freeze functionality, you need to use Otis Camera Tools (IGCS).")
            ImGui.PopTextWrapPos()
            ImGui.EndTooltip()
          end
        end

        if not AMM.playerInPhoto and not Tools.currentTarget.handle.isPlayerCompanionCached then

          if Tools:ShouldCrouchButtonAppear(Tools.currentTarget) then
            local buttonLabel = " Change To Crouch Stance "
            if Tools.isCrouching then
              buttonLabel = " Change To Stand Stance "
            end

            if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
              Tools.isCrouching = not Tools.isCrouching

              local handle = Tools.currentTarget.handle

              if Tools.isCrouching then
                local pos = handle:GetWorldPosition()
                pos = Vector4.new(pos.x, pos.y, pos.z, pos.w) 
                Util:MoveTo(handle, pos, nil, true)
              else
                Tools.currentTarget.parameters = AMM:GetAppearance(Tools.currentTarget)

                local currentTarget = Tools.currentTarget
                if currentTarget.type ~= 'Spawn' then
                  for _, spawn in pairs(AMM.Spawn.spawnedNPCs) do
                    if currentTarget.id == spawn.id or Util:CheckVByID(currentTarget.id) then currentTarget = spawn break end
                  end
                end

                Tools.currentTarget = ''
                currentTarget:Despawn()

                Cron.After(0.5, function()
                  AMM.Spawn:SpawnNPC(currentTarget)
                end)
              end
            end
          end
        end
      end

      AMM.UI:Spacing(8)

      local targetIsPlayer = Tools.currentTarget.type == "Player"
      if not AMM.playerInPhoto or AMM.userSettings.allowLookAtForNPCs or (AMM.playerInPhoto and targetIsPlayer and Tools.animatedHead) then
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
          Tools:ActivateFacialExpression(Tools.currentTarget, Tools.selectedFace)
        end

        ImGui.Spacing()

        if (not AMM.playerInPhoto or AMM.userSettings.allowLookAtForNPCs) and Tools.currentTarget ~= '' then

          AMM.UI:Spacing(4)

          local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)

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
          if ImGui.SmallButton("  Reset  ") then
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

          -- AMM.UI:TextColored("Look At Target")

          -- Start with V selected
          -- This should come before the combo box
          local lookAtTargetName = "Player V"
          if Tools.lookAtTarget ~= nil then
            lookAtTargetName = Tools.lookAtTarget.name
          end

          local availableTargets = {}

          table.insert(availableTargets, {name = "Player V", handle = Game.GetPlayer()})

          if Tools.currentTarget ~= '' then
            table.insert(availableTargets, Tools.currentTarget)
          end          

          for _, spawned in pairs(AMM.Spawn.spawnedNPCs) do
            if Tools.currentTarget.hash ~= spawned.hash then
              table.insert(availableTargets, spawned)
            end
          end
          
          -- Enable this to have spawned props
          -- in Look At Target dropdown menu
          if Tools.enablePropsInLookAtTarget then
            for _, spawned in pairs(AMM.Props.spawnedProps) do
              if Tools.currentTarget.hash ~= spawned.hash then
                table.insert(availableTargets, spawned)
              end
            end
          end

          ImGui.Text("Current Target:")

          if ImGui.BeginCombo("##LookAt", lookAtTargetName) then
            for i, t in ipairs(availableTargets) do
              if ImGui.Selectable(t.name.."##"..i, (t.name == lookAtTargetName)) then
                lookAtTargetName = t.name
                Tools.lookAtTarget = t
              end
            end
            ImGui.EndCombo()
          end

          ImGui.SameLine()
          local buttonLabel = "   Activate   "
          if Tools.lookAtActiveNPCs[npcHash] then
            buttonLabel = "  Deactivate  "
          end

          if ImGui.SmallButton(buttonLabel) then

            if Tools.lookAtActiveNPCs[npcHash] == nil then
              Tools:ActivateLookAt()
            else
              Tools.lookAtActiveNPCs[npcHash] = nil
              local stimComp = Tools.currentTarget.handle:GetStimReactionComponent()
              stimComp:DeactiveLookAt()
            end
          end

          ImGui.SameLine()

          if ImGui.SmallButton("   Reset   ") then
            if target ~= nil then
              Tools.lookAtTarget = nil
            end
          end
          
          Tools.enablePropsInLookAtTarget = ImGui.Checkbox("Enable Spawned Props", Tools.enablePropsInLookAtTarget)
        end
      end

      if AMM.userSettings.experimental and Tools.currentTarget ~= '' and Tools.currentTarget.handle:IsNPC() then

        local es = Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem"))
        local weapon = es:GetActiveWeaponObject(AMM.player, 39)
        local npcHasWeapon = Tools.currentTarget.handle:HasPrimaryOrSecondaryEquipment()

        if npcHasWeapon or weapon then
          AMM.UI:Spacing(4)
          AMM.UI:TextCenter("Equipment", true)
          ImGui.Spacing()
        end

        if npcHasWeapon then
          if ImGui.Button("Toggle Primary Weapon", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
            local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)
            if Tools.equippedWeaponNPCs[npcHash] == nil then
              Tools.equippedWeaponNPCs[npcHash] = {primary = true, secondary = false}
            else
              Tools.equippedWeaponNPCs[npcHash].primary = not Tools.equippedWeaponNPCs[npcHash].primary
            end

            Util:EquipPrimaryWeaponCommand(Tools.currentTarget.handle, Tools.equippedWeaponNPCs[npcHash].primary)
          end

          ImGui.SameLine()
          if ImGui.Button("Toggle Secondary Weapon", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
            local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)
            if Tools.equippedWeaponNPCs[npcHash] == nil then
              Tools.equippedWeaponNPCs[npcHash] = {primary = false, secondary = true}
            else
              Tools.equippedWeaponNPCs[npcHash].secondary = not Tools.equippedWeaponNPCs[npcHash].secondary
            end

            Util:EquipSecondaryWeaponCommand(Tools.currentTarget.handle, Tools.equippedWeaponNPCs[npcHash].secondary)
          end
        end

        if weapon then
          if ImGui.Button("Give Current Equipped Weapon", Tools.style.buttonWidth, Tools.style.buttonHeight) then
            local weaponTDBID = weapon:GetItemID().tdbid
            Util:EquipGivenWeapon(Tools.currentTarget.handle, weaponTDBID, Tools.forceWeapon)
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
    elseif Tools.currentTarget and Tools.currentTarget ~= '' then

      if Tools.currentTargetComponents == nil then
        Tools.currentTargetComponents = AMM.Props:CheckForValidComponents(Tools.currentTarget.handle)
      end

      local components = Tools.currentTargetComponents
            
      if components and Tools.currentTarget.scale then
        AMM.UI:Spacing(4)
        AMM.UI:TextCenter("Scale", true)

        Tools.currentTarget.scale = Tools.currentTarget.scale or { x = 1, y = 1, z = 1 }

        local scaleChanged = false
        if Tools.scaleWidth == nil or Tools.scaleWidth < 50 then
          Tools.scaleWidth = ImGui.GetWindowContentRegionWidth()
        end

        if Tools.proportionalMode then
          ImGui.PushItemWidth(Tools.scaleWidth)
          Tools.currentTarget.scale.x, scaleChanged = ImGui.DragFloat("##scale", Tools.currentTarget.scale.x, 0.1)
          ImGui.PopItemWidth()

          if scaleChanged then
            Tools.currentTarget.scaleHasChanged = true
            Tools.currentTarget.scale.y = Tools.currentTarget.scale.x
            Tools.currentTarget.scale.z = Tools.currentTarget.scale.x
          end
        else
          ImGui.PushItemWidth((Tools.scaleWidth / 3) - 8)
          Tools.currentTarget.scale.x, used = ImGui.DragFloat("##scaleX", Tools.currentTarget.scale.x, 0.1)
          if used then scaleChanged = true end
          ImGui.SameLine()
          Tools.currentTarget.scale.y, used = ImGui.DragFloat("##scaleY", Tools.currentTarget.scale.y, 0.1)
          if used then scaleChanged = true end
          ImGui.SameLine()
          Tools.currentTarget.scale.z, used = ImGui.DragFloat("##scaleZ", Tools.currentTarget.scale.z, 0.1)
          if used then scaleChanged = true end
          ImGui.PopItemWidth()
        end

        if scaleChanged then
          Tools:SetScale(components, Tools.currentTarget.scale, Tools.proportionalMode)
        end

        Tools.proportionalMode, proportionalModeChanged = ImGui.Checkbox("Proportional Mode", Tools.proportionalMode)

        if proportionalModeChanged then
          Tools:SetScale(components, Tools.currentTarget.scale, Tools.proportionalMode)
        end

        if ImGui.Button("Reset Scale", Tools.style.buttonWidth, Tools.style.buttonHeight) then
          Tools:SetScale(components, Tools.currentTarget.defaultScale, true)
          Tools.currentTarget.scaleHasChanged = false
          Tools.currentTarget.scale = {
            x = Tools.currentTarget.defaultScale.x,
            y = Tools.currentTarget.defaultScale.y,
            z = Tools.currentTarget.defaultScale.z,
          }
        end
      end

      AMM.UI:Spacing(4)

      local lookAtTargetName = "V"
      if Tools.lookAtTarget ~= nil then
        lookAtTargetName = Tools.lookAtTarget.name
      end

      ImGui.Text("Current Target:")
      ImGui.SameLine()
      AMM.UI:TextColored(lookAtTargetName)

      if ImGui.Button("Show As Look At Target", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        if Tools.currentTarget ~= '' then
          Tools.lookAtTarget = Tools.currentTarget
        end
      end

      ImGui.SameLine()
      if ImGui.Button("Reset Look At Target", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        if target ~= nil then
          Tools.lookAtTarget = nil
        end
      end
    end

    if Tools.currentTarget and Tools.currentTarget ~= '' then      
      local appOptions = Tools.currentTarget.options or AMM:GetAppearanceOptions(Tools.currentTarget.handle, Tools.currentTarget.id)

      if appOptions then
        AMM.UI:Spacing(4)

        AMM.UI:TextCenter("List of Appearances", true)

        local selectedApp = Tools.currentTarget.appearance
        if ImGui.BeginCombo("##Appearances", selectedApp, ImGuiComboFlags.HeightLarge) then
          for i, app in ipairs(appOptions) do
            if ImGui.Selectable(app, (app == selectedApp)) then
              if Tools.currentTarget.appearance ~= app then
                AMM:ChangeAppearanceTo(Tools.currentTarget, app)
              end
            end
          end
          ImGui.EndCombo()
        end
      end

      ImGui.Spacing()

      if AMM.Light:GetLightComponent(Tools.currentTarget.handle) then
        AMM.UI:Spacing(4)

        AMM.UI:TextCenter("Light Control", true)

        if ImGui.Button("Toggle Light", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
          if AMM.Props.hiddenProps[Tools.currentTarget.hash] then
            AMM.Props.hiddenProps[Tools.currentTarget.hash] = nil
          end
          AMM.Light:ToggleLight(AMM.Light:GetLightData(Tools.currentTarget))
        end

        ImGui.SameLine()
        local buttonLabel ="Open Light Settings"
        if AMM.Light.isEditing then
          buttonLabel = "Update Light Target"
        end

        if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
          AMM.Light:Setup(Tools.currentTarget)
          AMM.Light.isEditing = true
        end
      end
    end
  end

  if AMM.userSettings.floatingTargetTools then
    ImGui.End()
  end

  if not(Tools.movementWindow.open) then
    Tools.movementWindow.open = false
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

  if AMM.UI:GlyphButton(IconGlyphs.MinusCircle or "-", true) then
    if Tools.timeValue < 0 then
      Tools.timeValue = 1440
    end

    Tools.timeValue = Tools.timeValue - 1
    changeTimeUsed = true
  end

  ImGui.SameLine()

  if AMM.UI:GlyphButton(IconGlyphs.PlusCircle or "+", true) then
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
  if c == 1 then
    Game.GetTimeSystem():UnsetTimeDilation("consoleCommand")
  else
    if c == 0 then c = 0.0000000000001 end

    Game.GetTimeSystem():SetTimeDilation("consoleCommand", c)
  end
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
    Game.GetTimeSystem():SetTimeDilation("consoleCommand", 0.0000000000001)
  else
    if Tools.slowMotionSpeed ~= 1 then
      Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
    else
      Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(false)
      Game.GetTimeSystem():SetTimeDilation("consoleCommand", 1)
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

-- Nibbles Replacer
function Tools:DrawNibblesReplacer()
  if not Tools.replacer then
    ImGui.Spacing()
    ImGui.Text("Photomode_NPCs_AMM.lua")
    ImGui.SameLine()
    AMM.UI:TextError("file not found in Collabs folder")
  else
    for i, option in ipairs(Tools.nibblesEntityOptions) do
      local selectedEntity = Tools.nibblesEntityOptions[Tools.selectedNibblesEntity]
      if ImGui.RadioButton(option.name, selectedEntity.name == option.name) then
        Tools.selectedNibblesEntity = i
        Tools.cachedReplacerOptions = nil
        Tools:UpdateNibblesEntity(option.ent)
      end

      if option.ent then
        ImGui.SameLine()
      end
    end
  end
end

function Tools:UpdateNibblesEntity(ent)
  if not Tools.nibblesOG then
    Tools.nibblesOG = {
      ent = TweakDB:GetFlat('Character.Nibbles_Puppet_Photomode.entityTemplatePath'),
      --poses = TweakDB:GetFlat("photo_mode.character.quadrupedPoses"),
    }
  end
  
  if ent then
    TweakDB:SetFlat('Character.Nibbles_Puppet_Photomode.entityTemplatePath', f([[base\characters\entities\photomode_replacer\%s.ent]], ent))
    --TweakDB:SetFlat('photo_mode.character.quadrupedPoses', Tools.replacer[ent]) -- this can't be done for now
  else
    TweakDB:SetFlat('Character.Nibbles_Puppet_Photomode.entityTemplatePath', Tools.nibblesOG.ent)
    --TweakDB:SetFlat('photo_mode.character.quadrupedPoses', Tools.nibblesOG.poses)
  end
end

local allCharacters = {}

function Tools:PrepareCategoryHeadersForNibblesReplacer(options)
  if not Tools.cachedReplacerOptions then
    local selectedEntity = Tools.nibblesEntityOptions[Tools.selectedNibblesEntity]
    local query = f("SELECT app_name FROM favorites_apps WHERE entity_id = '%s'", AMM:GetScanID(selectedEntity.ent))
    local favorites = {}
    for app in db:urows(query) do
      favorites[app] = true
    end

    local categories = {}
    for _, app in ipairs(options) do
      local index = string.find(app, "_")
      local name = app
      if index then name = string.sub(app, 1, index-1) end      
      
      if #allCharacters == 0 then
        for n in db:urows("SELECT entity_name FROM entities WHERE entity_path LIKE '%%Character.%%'") do
          table.insert(allCharacters, n)
        end
      end

      name = Util:FirstToUpper(name)

      name = Tools:RecursivelyScoreDistance(name, 6)

      if categories[name] == nil then
        categories[name] = {}
      end

      if favorites[app] then
        favorites[app] = nil
        favorites[name] = true
      end

      table.insert(categories[name], app)
    end

    local headers = {}

    for k, v in pairs(favorites) do
      if v then table.insert(headers, {name = k, options = categories[k]}) end
    end

    for k, v in pairs(categories) do
      if not(favorites[k]) then
        table.insert(headers, {name = k, options = v})
      end
    end

    Tools.cachedReplacerOptions = headers
  end

  return Tools.cachedReplacerOptions
end

function Tools:SetupReplacerAppearances()
  local appearances = Tools.replacer.appearances
  if appearances ~= nil then
    for ent, apps in pairs(appearances) do
      for _, app in ipairs(apps) do
        db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', AMM:GetScanID(ent), app, "Replacer"))
      end
    end
  end
end

function Tools:RecursivelyScoreDistance(name, length)
  if length < 3 then
    return name
  end

  local lastScore = 9999
  local lastName = nil
  local firstLettersFromName = string.sub(name, 1, math.min(length, string.len(name)))

  for _, character in ipairs(allCharacters) do
    local noSpacesName = character:gsub("%s+", "")
    local firstLettersFromCharacter = string.sub(noSpacesName, 1, math.min(length, string.len(noSpacesName)))
    local currentScore = Util:StringMatch(firstLettersFromName, firstLettersFromCharacter)
    if lastScore > currentScore then
      lastScore = currentScore
      lastName = character
    end
  end

  if lastScore == 0 then
    return lastName
  end

  return Tools:RecursivelyScoreDistance(name, length - 3)
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
function Tools:SpawnHelper(ent, pos, angles)
  local heading = AMM.player:GetWorldForward()
	local offsetDir = Vector3.new(heading.x * 2, heading.y * 2, heading.z)
	local spawnTransform = AMM.player:GetWorldTransform()
	local spawnPosition = GetSingleton('WorldPosition'):ToVector4(spawnTransform.Position)
	local newPosition = Vector4.new(spawnPosition.x  + offsetDir.x, spawnPosition.y + offsetDir.y, spawnPosition.z, spawnPosition.w)
	spawnTransform:SetPosition(spawnTransform, pos or newPosition)
	spawnTransform:SetOrientationEuler(spawnTransform, angles or EulerAngles.new(0, 0, 0))
	  
  ent.entityID = exEntitySpawner.Spawn(ent.template, spawnTransform, '')

  local timerFunc = function(timer)
		local entity = Game.FindEntityByID(ent.entityID)
    timer.tick = timer.tick + 1
		if entity then
			ent.handle = entity
      ent.hash = tostring(entity:GetEntityID().hash)
      ent.appearance = AMM:GetAppearance(ent)
      ent.spawned = true
      ent.type = "Prop"
      
      local components = Props:CheckForValidComponents(entity)
      if components then
        local visualScale = Props:CheckDefaultScale(components)
        ent.defaultScale = {
          x = visualScale.x * 100,
          y = visualScale.x * 100,
          z = visualScale.x * 100,
         }

        if ent.scale and ent.scale ~= nilString then
          AMM.Tools:SetScale(components, ent.scale)
        else
          ent.scale = {
            x = visualScale.x * 100,
            y = visualScale.y * 100,
            z = visualScale.z * 100,
           }
        end
      end

			Cron.Halt(timer)
		elseif timer.tick > 20 then
			Cron.Halt(timer)
		end
	end

	Cron.Every(0.1, {tick = 1}, timerFunc)
end

function Tools:UpdateAxisIndicatorPosition()
  local targetPosition = Tools.currentTarget.handle:GetWorldPosition()
  local targetAngles = nil
  if Tools.relativeMode then
    targetAngles = Tools.currentTarget.handle:GetWorldOrientation():ToEulerAngles()
  end

  Game.GetTeleportationFacility():Teleport(Tools.axisIndicator.handle, targetPosition, targetAngles)
end

function Tools:ToggleAxisIndicator()
  if not Tools.axisIndicator and drawWindow then
    Tools.axisIndicator = {}
    Tools.axisIndicator.template = "base\\amm_props\\entity\\axis_indicator.ent"
    Tools.axisIndicator = AMM.Entity:new(Tools.axisIndicator)

    local targetPosition = Tools.currentTarget.handle:GetWorldPosition()
    local targetAngles = nil
    if Tools.relativeMode then
      targetAngles = Tools.currentTarget.handle:GetWorldOrientation():ToEulerAngles()
    end

    Tools:SpawnHelper(Tools.axisIndicator, targetPosition, targetAngles)
  elseif Tools.axisIndicator then
    Tools.axisIndicator.handle:Dispose()
    Tools.axisIndicator = nil
  end
end

function Tools:CheckIfDirectModeShouldBeDisabled(hash)
  if hash == Tools.currentTarget.hash then
    Tools:ToggleDirectMode(true)
  end
end

function Tools:ToggleDirectMode(systemActivated)
  if systemActivated then
    Tools.directMode = not Tools.directMode
  end

  Tools.lockTarget = true
  Tools.currentTarget:StartListeners()

  if Tools.directMode then
    Util:AddPlayerEffects()
  elseif not Tools.directMode then
    Util:RemovePlayerEffects()
  end
end

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

  local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)

  if Tools.lookAtActiveNPCs[npcHash] == nil then
    Tools.lookAtActiveNPCs[npcHash] = {
      mode = Tools.selectedLookAt,
      headSettings = headSettings,
      chestSettings = chestSettings
    }
  end

  Util:NPCLookAt(Tools.currentTarget.handle, Tools.lookAtTarget, headSettings, chestSettings)
end

function Tools:RestartLookAt()
  if Tools.activatedFace then
    Tools:ActivateFacialExpression(Tools.currentTarget.handle, Tools.selectedFace)
  end

  local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)
  if Tools.lookAtActiveNPCs[npcHash] then
    Tools:ActivateLookAt()
  end
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
      
      if Tools.cursorStateLock or AMM.userSettings.disablePhotoModeCursor then
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
