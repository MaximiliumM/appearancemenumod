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
local psyUnh = false

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
  Tools.weatherSystem = nil
  Tools.weatherOptions = {}
  Tools.selectedWeather = 1

  -- Teleport Properties
  Tools.lastLocation = nil
  Tools.locationSearch = ''
  Tools.lastLocationSearch = ''
  Tools.selectedLocation = {loc_name = AMM.LocalizableString("Select_Location")}
  Tools.shareLocationName = ''
  Tools.allLocations = {}
  Tools.locations = {}
  Tools.defaultLocations = {}
  Tools.userLocations = {}
  Tools.favoriteLocations = {}
  Tools.useTeleportAnimation = false
  Tools.selectedLocationCategory = AMM.LocalizableString("Select_Category")
  Tools.selectedCatIDForSaving = 11       -- default to 11 (UserLocations) 
  Tools.editingLocation = nil            -- nil means "new" by default
  Tools.currentPopupTitle = nil
  Tools.locationTagInput = ''
  Tools.availableTags = {}
  Tools.tagFilters    = {}  -- e.g. { ["safe"] = true, ["loot"] = false, ... }

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
  Tools.advX = 100
  Tools.advY = 100
  Tools.advZ = 100
  Tools.npcRotation = 0
  Tools.advRotationRoll = 90
  Tools.advRotationPitch = 90
  Tools.advRotationYaw = 90
  Tools.movingProp = false
  Tools.savedPosition = ''  
  Tools.lookAtActiveNPCs = {}
  Tools.lookAtTarget = nil
  Tools.photoModePuppet = nil
  Tools.currentTargetComponents = nil
  Tools.enablePropsInLookAtTarget = false
  Tools.listOfPuppets = {}
  Tools.puppetsIDs = {}
  Tools.updatedPosition = {}
  Tools.cyberpsychoMode = false

  -- Facial Expression Properties --
  Tools.selectedFace = {name = AMM.LocalizableString("Select_Expression")}
  Tools.activatedFace = false
  Tools.selectedCategory = AMM.LocalizableString("Select_Category")
  Tools.lastActivatedFace = {name = "No Active Face"}
  Tools.favoriteExpressions = {}
  Tools.mergedExpressions = {}

  -- Axis Indicator Properties --
  Tools.axisIndicator = nil
  Tools.axisIndicatorToggle = false

  -- Nibbles Replacer Properties --
  Tools.cachedReplacerOptions = nil
  Tools.nibblesOG = nil
  Tools.selectedNibblesEntity = 1

  Tools.replacer = nil

  if AMM.CETVersion < 34 then
    Tools.replacer = require("Collabs/Photomode_NPCs_AMM.lua")
  end

  Tools.replacerVersion = nil
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
  -- Initialize Strings here to be able to change localization language
  Tools.selectedLocation = {loc_name = AMM.LocalizableString("Select_Location")}
  Tools.selectedFace = {name = AMM.LocalizableString("Select_Expression")}

  if AMM.extraExpressionsInstalled then
    Tools.mergedExpressions = AMM:GetAllExpressionsMerged()
  end
  
  Tools.playerVisibility = AMM.userSettings.passiveModeOnLaunch or true
  if not Tools.playerVisibility then
    Tools:ToggleInvisibility()
  end

  -- Weather Options --
  Tools.weatherOptions = {
    {name = AMM.LocalizableString("Default"), cname = "reset"},
    {name = AMM.LocalizableString("Rain"), cname = "24h_weather_rain"},
    {name = AMM.LocalizableString("Light_Rain"), cname = "q302_light_rain"},
    {name = AMM.LocalizableString("Cloudy"), cname = "24h_weather_cloudy"},
    {name = AMM.LocalizableString("Fog"), cname = "24h_weather_fog"},
    {name = AMM.LocalizableString("Heavy_Clouds"), cname = "24h_weather_heavy_clouds"},
    {name = AMM.LocalizableString("Light_Clouds"), cname = "24h_weather_light_clouds"},
    {name = AMM.LocalizableString("Pollution"), cname = "24h_weather_pollution"},
    {name = AMM.LocalizableString("Sandstorm"), cname = "24h_weather_sandstorm"},
    {name = AMM.LocalizableString("Sunny"), cname = "24h_weather_sunny"},
    {name = AMM.LocalizableString("Toxic_Rain"), cname = "24h_weather_toxic_rain"},
    {name = AMM.LocalizableString("Deep_Blue"), cname = "q302_deep_blue"},
    {name = AMM.LocalizableString("Squat_Morning"), cname = "q302_squat_morning"},
    {name = AMM.LocalizableString("Cloudy_Morning"), cname = "q306_epilogue_cloudy_morning"},
    {name = AMM.LocalizableString("Rainy_Night"), cname = "q306_rainy_night"},
    {name = AMM.LocalizableString("Courier_Clouds"), cname = "sa_courier_clouds"},
  }

  -- Initialize Weather System
  Tools.weatherSystem = Game.GetWeatherSystem()

  -- Setup TPP Camera Options --
  Tools.TPPCameraOptions = {
    {name = AMM.LocalizableString("Left"), vec = Vector4.new(-0.5, -2, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = AMM.LocalizableString("Left_Close"), vec = Vector4.new(-0.4, -1.5, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = AMM.LocalizableString("Right"), vec = Vector4.new(0.5, -2, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = AMM.LocalizableString("Right_Close"), vec = Vector4.new(0.4, -1.5, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = AMM.LocalizableString("Center_Close"), vec = Vector4.new(0, -2, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = AMM.LocalizableString("Center_Far"), vec = Vector4.new(0, -4, 0, 1.0), rot = Quaternion.new(0.0, 0.0, 0.0, 1.0)},
    {name = AMM.LocalizableString("Front_Close"), vec = Vector4.new(0, 2, 0, 0), rot = Quaternion.new(50.0, 0.0, 4000.0, 0.0)},
    {name = AMM.LocalizableString("Front_Far"), vec = Vector4.new(0, 4, 0, 0), rot = Quaternion.new(50.0, 0.0, 4000.0, 0.0)},
  }

  Tools.lookAtOptions = {
    {name = AMM.LocalizableString("All"), parts = {'LookatPreset.PhotoMode_LookAtCamera_inline0', 'LookatPreset.PhotoMode_LookAtCamera_inline1'}},
    {name = AMM.LocalizableString("Head_Only"), parts = {'LookatPreset.PhotoMode_LookAtCamera_inline0'}},
    {name = AMM.LocalizableString("Eyes_Only"), parts = {}},
  }

  Tools.selectedLookAt = Tools.lookAtOptions[1]

  -- Do not put in cron - will cause stutters or even crashes with >200 locations
  Tools:LoadAllLocations()
  
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

    -- Check if Replacer appearances are in the database
    local check = 0
		for count in db:urows([[SELECT COUNT(1) FROM appearances WHERE collab_tag = "Replacer"]]) do
			check = count
		end

    -- If appearances are available, check if version has changed
    if check ~= 0 then
      if (Tools.replacerVersion and Tools.replacer.version and Tools.replacer.version > Tools.replacerVersion) then
        -- Delete appearances if version has changed
        db:execute("DELETE FROM appearances WHERE collab_tag = 'Replacer'")
        Tools:SetupReplacerAppearances()
      end
    else -- appearances aren't available so setup them
      Tools:SetupReplacerAppearances()
    end
    
    Tools.replacerVersion = Tools.replacer.version
    Tools.nibblesEntityOptions = Tools.replacer.entityOptions

    local selectedEntity = Tools.nibblesEntityOptions[Tools.selectedNibblesEntity]
    Tools:UpdateNibblesEntity(selectedEntity.ent)
  else
    -- Delete appearances in case the Replacer was uninstalled
    db:execute("DELETE FROM appearances WHERE collab_tag = 'Replacer'")
  end
end

function Tools:Draw(AMM, t)
  -- Setting target to local variable
  target = t

  Tools.style = {
    buttonHeight = ImGui.GetFontSize() * 2,
    buttonWidth = (ImGui.GetWindowContentRegionWidth() - 8),
    halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 8)
  }

  -- Util Popup Helper --
  Util:SetupPopup()

  -- Tools Tab State --
  Tools.isOpen = false

  if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabTools")) then

    Tools.isOpen = true

    Tools.actionCategories = {
      { name = AMM.LocalizableString("Target_Actions"), actions = Tools.DrawNPCActions },
      { name = AMM.LocalizableString("Teleport_Actions"), actions = Tools.DrawTeleportActions },
      { name = AMM.LocalizableString("Time_Actions"), actions = Tools.DrawTimeActions },
      { name = AMM.LocalizableString("V_Actions"), actions = Tools.DrawVActions },
    }

    if AMM.playerInMenu and not AMM.playerInPhoto then
      AMM.UI:TextColored(AMM.LocalizableString("Warn_PlayerInMenu"))
      ImGui.Text(AMM.LocalizableString("Warn_ToolsOnly_WorksIngame"))
    else
      if AMM.playerInPhoto then
        Tools.actionCategories = {
          { name = AMM.LocalizableString("V_Actions"), actions = Tools.DrawVActions },
          { name = AMM.LocalizableString("Target_Actions"), actions = Tools.DrawNPCActions },
          { name = AMM.LocalizableString("Time_Actions"), actions = Tools.DrawTimeActions },
          { name = AMM.LocalizableString("PhotoModeEnhancements"), actions = Tools.DrawPhotoModeEnhancements },
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

      if ImGui.InvisibleButton(AMM.LocalizableString("Button_InvSpeed2"), 10, 30) then
        local popupInfo = {text = AMM.LocalizableString("Warn_InvButton_Info")}
				Util:OpenPopup(popupInfo)
        Tools.slowMotionMaxValue = 5
      end

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip(AMM.LocalizableString("InvButtonTip"))
      end
    end
    ImGui.EndTabItem()
  end
end

-- define these in file scope to prevent leaking
local clicked, gender, invisClicked, mode, leftUsed, rightUsed, rotationUsed, axisToggle, relativeToggle, directToggle, upDownUsed, used, proportionalModeChanged

-- V actions
function Tools:DrawVActions()
  -- AMM.UI:TextColored("V Actions:")

  if AMM.playerInPhoto or Util:CheckVByID(Tools.currentTarget.id) then
    if ImGui.Button(AMM.LocalizableString("Button_ToggleMakeup"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleMakeup()
    end

    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Button_TogglePiercings"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleAccessories()
    end

    local buttonWidth = Tools.style.halfButtonWidth
    if not AMM.playerInPhoto then
      buttonWidth = Tools.style.buttonWidth
    end

    if ImGui.Button(AMM.LocalizableString("Button_ToggleSeamfix"), buttonWidth, Tools.style.buttonHeight) then
      Tools:ToggleSeamfix()
    end

    if AMM.playerInPhoto then
      ImGui.SameLine()
      local buttonLabel = AMM.LocalizableString("LockLook_AtCamera")
      if Tools.lookAtLocked then
        buttonLabel = AMM.LocalizableString("UnlockLook_AtCamera")
      end

      if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        Tools:ToggleLookAt()
      end

      if AMM.CETVersion < 34 then
        local buttonLabel = AMM.LocalizableString("Target_Nibbles")
        if Tools.selectedNibblesEntity ~= 1 then buttonLabel = AMM.LocalizableString("Target_Replacer") end
        if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
          Tools:SetCurrentTarget(Tools:GetNibblesTarget())
          Tools.lockTarget = true
        end
      end

      Tools.savePhotoModeToggles = ImGui.Checkbox(AMM.LocalizableString("Save_Toggles_State"), Tools.savePhotoModeToggles)

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip(AMM.LocalizableString("Warn_SeamfixPiercingToggle_Info"))
      end
    end
  else
    local buttonLabel = AMM.LocalizableString("DisablePassiveMode")
    if Tools.playerVisibility then
      buttonLabel = AMM.LocalizableString("EnablePassiveMode")
    end

    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleInvisibility()
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(AMM.LocalizableString("Warn_PassiveMode_Info"))
    end

    local buttonLabel = AMM.LocalizableString("EnableGodMode")
    if Tools.godModeToggle then
      buttonLabel = AMM.LocalizableString("DisableGodMode")
    end

    ImGui.SameLine()
    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleGodMode()
      AMM:UpdateSettings()
    end

    if ImGui.Button(AMM.LocalizableString("Infinite_Oxygen"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      if not Tools.infiniteOxygen then
        Tools.infiniteOxygen = not Tools.infiniteOxygen
        
        if Tools.infiniteOxygen then
          Game.GetStatPoolsSystem():RequestRemovingStatPool(Game.GetPlayer():GetEntityID(), gamedataStatPoolType.Oxygen)
        else
          Game.GetStatPoolsSystem():RequestAddingStatPool(Game.GetPlayer():GetEntityID(), TweakDBID.new("BaseStatPools.Player_Oxygen_Base"), true)
        end
      end
    end

    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Toggle_V_Head"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleHead(true)
    end

    if AMM.userSettings.experimental then
      if ImGui.Button(AMM.LocalizableString("Toggle_TPP_Camera"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools:ToggleTPPCamera()
      end

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip(AMM.LocalizableString("Warn_TppCameraGameplay_Info"))
      end

      local selectedCamera = Tools.TPPCameraOptions[Tools.selectedTPPCamera]
      if ImGui.BeginCombo(AMM.LocalizableString("TPPCamera_Position"), selectedCamera.name) then
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

    Tools.animatedHead, clicked = ImGui.Checkbox(AMM.LocalizableString("AnimatedHeadin_PhotoMode"), Tools.animatedHead)

    if clicked then
      Tools:ToggleAnimatedHead(Tools.animatedHead)
      AMM:UpdateSettings()
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(AMM.LocalizableString("Warn_AnimatedHead_PhotoMode_Info"))
    end

    -- ImGui.Spacing()
    Tools.invisibleBody, invisClicked = ImGui.Checkbox(AMM.LocalizableString("Invisible_V"), Tools.invisibleBody)

    if invisClicked then
      Tools:ToggleInvisibleBody(AMM.player)
    end
  end
end

function Tools:ToggleSeamfix()
  local target = Tools:GetVTarget()
  if not target then return end
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
  if not target then return end
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
  if not target then return end
  Tools.accessoryToggle = not Tools.accessoryToggle

  local isFemale = Util:GetPlayerGender()
	if isFemale == "_Female" then gender = 'pwa' else gender = 'pma' end

  for i = 1, 4 do
    local accessory = target.handle:FindComponentByName(CName.new(f("i1_000_%s__morphs_earring_0%i", gender, i)))
	  if accessory then accessory:Toggle(Tools.accessoryToggle) end
  end
end

function Tools:ToggleInvisibleBody(playerHandle)
  local player = Game.GetPlayer()
  local components = player:GetComponents()
  for _, comp in ipairs(components) do
    if string.find(NameToString(comp:GetClassName()), "Mesh") then
	    comp:Toggle(not(Tools.invisibleBody))
    end
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

  local hp, o2, weight

  if Tools.godModeToggle then
    hp, o2, weight = -99999, -999999, 9999
  else
    hp, o2, weight = 99999, 999999, -9999
  end

  -- Stat Modifiers
  Util:ModStatPlayer("Health", hp)
  Util:ModStatPlayer("Oxygen", o2)
  Util:ModStatPlayer("CarryCapacity", weight)

  -- Toggles
  local toggle = boolToInt(Tools.godModeToggle)
  -- Util:InfiniteStamina(Tools.godModeToggle)
  Util:ModStatPlayer("KnockdownImmunity", toggle)
  Util:ModStatPlayer("PoisonImmunity", toggle)
  Util:ModStatPlayer("BurningImmunity", toggle)
  Util:ModStatPlayer("BlindImmunity", toggle)
  Util:ModStatPlayer("BleedingImmunity", toggle)
  Util:ModStatPlayer("FallDamageReduction", toggle)
  Util:ModStatPlayer("ElectrocuteImmunity", toggle)
  Util:ModStatPlayer("StunImmunity", toggle)
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

local toggleHeadInProgress = false

function Tools:ToggleTPPCamera(userActivated)

  if (AMM.playerInVehicle or toggleHeadInProgress) and userActivated then
    return
  end

  AMM.Tools.TPPCamera = not AMM.Tools.TPPCamera

  Tools:ToggleHead()

  if Tools.TPPCamera then
    Cron.Every(0.1, function(timer)
      if not toggleHeadInProgress then
        Cron.After(0.1, function()
          Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Tools.TPPCameraOptions[Tools.selectedTPPCamera].vec)
          Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Tools.TPPCameraOptions[Tools.selectedTPPCamera].rot)
        end)

        Cron.Halt(timer)
      end
    end)

    Cron.Every(0.1, function(timer)
      if Tools.TPPCamera and not toggleHeadInProgress then
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Tools.TPPCameraOptions[Tools.selectedTPPCamera].vec)
        Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Tools.TPPCameraOptions[Tools.selectedTPPCamera].rot)
        Game.GetPlayer():GetFPPCameraComponent().pitchMax = 80
        Game.GetPlayer():GetFPPCameraComponent().pitchMin = -80
        Game.GetPlayer():GetFPPCameraComponent().yawMaxRight = -360
        Game.GetPlayer():GetFPPCameraComponent().yawMaxLeft = 360
      elseif not Tools.TPPCamera then
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0, 0, 1.0))
        Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 0.0, 1.0))
        Cron.Halt(timer)
      end
    end)
  end
end

function Tools:ToggleHead(userActivated)
 
  if (AMM.playerInVehicle or toggleHeadInProgress) and userActivated then
    return
  end

  toggleHeadInProgress = true

  local playerIsLeavingVehicle = AMM.Tools.TPPCameraBeforeVehicle
  local delay = Util:CalculateDelay(5)

  if playerIsLeavingVehicle then
    delay = Util:CalculateDelay(20)
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

  if AMM.playerInVehicle then
    ts:ChangeItemAppearanceByName(Game.GetPlayer(), itemID, "default&TPP")
  end

  ts:RemoveItemFromSlot(Game.GetPlayer(), slot, true, true, true)

  if Tools.tppHead then
    Cron.Every(0.001, { tick = 1 }, function(timer)
      timer.tick = timer.tick + 1

      if timer.tick > delay or not Tools.tppHead then
        Cron.After(0.1, function()
          toggleHeadInProgress = false
          Cron.Halt(timer)
        end)
      end

      Cron.After(0.001, function()
          ts:RemoveItemFromSlot(Game.GetPlayer(), slot, true, true, true)
      end)

      Cron.After(0.1, function()
        if ts:GetItemInSlot(Game.GetPlayer(), slot) == nil then
          ts:AddItemToSlot(Game.GetPlayer(), slot, itemID)
        end

      end)
    end)
  else
    Cron.Every(0.001, { tick = 1 }, function(timer)
      ts:ChangeItemAppearanceByName(Game.GetPlayer(), itemID, "default&FPP")
      
      timer.tick = timer.tick + 1
      
      if timer.tick > delay then
        toggleHeadInProgress = false
        Cron.Halt(timer)
      end

      Cron.After(0.001, function()
        ts:RemoveItemFromSlot(Game.GetPlayer(), slot, true, true, true)
      end)

      Cron.After(0.1, function()
        if ts:GetItemInSlot(Game.GetPlayer(), slot) == nil then
          ts:AddItemToSlot(Game.GetPlayer(), slot, fppHead)
          ts:ChangeItemAppearanceByName(Game.GetPlayer(), fppHead, "default&FPP")
        end
      end)
    end)
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
  local entity = Tools.listOfPuppets[1]

  if not entity then
    if Util:CheckVByID(Tools.currentTarget.id) then
      return Tools.currentTarget
    else
      return nil
    end
  end

  return entity
end

-- Table to track active timers for puppets
Tools.activeTimers = {}

function Tools:ResetPuppetsPosition()
    -- Validate list of puppets
    if not Tools.listOfPuppets or #Tools.listOfPuppets == 0 then
        log("No puppets in the list!")
        return
    end

    for _, puppet in ipairs(Tools.listOfPuppets) do
        -- Validate puppet and handle
        if not puppet or not puppet.handle then
            log("Invalid puppet or missing handle!")
            goto continue
        end

        -- Localize saved positions and angles
        local savedPuppetPos = tostring(puppet.pos)
        local savedPuppetAngles = tostring(puppet.angles)

        -- Stop any active timer for this puppet before starting a new one
        if Tools.activeTimers[puppet.hash] then
            Cron.Halt(Tools.activeTimers[puppet.hash])
            Tools.activeTimers[puppet.hash] = nil
        end

        -- Start a new timer and track it
        Tools.activeTimers[puppet.hash] = Tools:CheckPuppetPosition(puppet, savedPuppetPos, savedPuppetAngles)

        ::continue::
    end
end

function Tools:CheckPuppetPosition(puppet, savedPuppetPos, savedPuppetAngles)
    -- Cron logic to monitor changes in position
    return Cron.Every(0.001, { tick = 1 }, function(timer)
        timer.tick = timer.tick + 1

        if timer.tick > 10 then
          Tools.activeTimers[puppet.hash] = nil -- Clear the active timer
            Cron.Halt(timer)
            return
        end

        -- Validate puppet handle inside Cron
        if puppet.handle then
            local puppetPos = tostring(puppet.handle:GetWorldPosition())
            local puppetAngles = tostring(puppet.handle:GetWorldOrientation():ToEulerAngles())

            -- Check if position or angles have changed
            if puppetPos ~= savedPuppetPos or puppetAngles ~= savedPuppetAngles then
                if Tools.updatedPosition[puppet.hash] then
                    Tools:SetTargetPosition(puppet.pos, puppet.angles, puppet)
                    Cron.Halt(timer)
                    Tools.activeTimers[puppet.hash] = nil -- Clear the active timer
                end
            end
        else
            log("Invalid handle for puppet during Cron.Every!")
            Tools.activeTimers[puppet.hash] = nil -- Clear the active timer
            Cron.Halt(timer)
        end
    end)
end

function Tools:AddNewPuppet(ent)
  Cron.Every(0.1, { tick = 1 }, function(timer)
    timer.tick = timer.tick + 1

    if timer.tick > 10 then
      Cron.Halt(timer)
    end

    local puppetID = ent:GetEntityID()
    local puppetHash = tostring(puppetID.hash)

    if Game.FindEntityByID(puppetID) then
      if not Tools.puppetsIDs[puppetHash] then
        local entity = ent
        local newTarget = AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), AMM:GetNPCName(entity), AMM:GetScanAppearance(entity), AMM:GetAppearanceOptions(entity))
        table.insert(Tools.listOfPuppets, newTarget)
        Tools.puppetsIDs[puppetHash] = puppetID
        Tools.photoModePuppet = ent
        puppetSpawned = false
        Cron.Halt(timer)
      end
    end
  end)
end

function Tools:ClearListOfPuppets()

  for puppetHash, puppetID in pairs(Tools.puppetsIDs) do
    if not Game.FindEntityByID(puppetID) then
      for i, puppet in ipairs(Tools.listOfPuppets) do
        if puppet.hash == puppetHash then
          table.remove(Tools.listOfPuppets, i)
          Tools.puppetsIDs[puppetHash] = nil
        end
      end
    end
  end
end

local locationRefreshDebounce = false
local function refreshLocationListDebounced()
  -- don't refresh if semaphore is set
  if locationRefreshDebounce then return end
  
  -- set variable, refresh tools
  locationRefreshDebounce = true  
  Tools:LoadAllLocations()
  
  -- unset variable in 10 seconds
  Cron.After(10, function()
    locationRefreshDebounce = false
  end)
end

-- Teleport actions
function Tools:DrawTeleportActions()

  Tools:DrawLocationsDropdown()

  ImGui.Spacing()

  if Tools.selectedLocation.loc_name ~= AMM.LocalizableString("Select_Location") then

    if ImGui.Button(AMM.LocalizableString("Button_TeleportToLocation"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:TeleportToLocation(Tools.selectedLocation)
    end

    ImGui.Spacing()

    local isFavorite, favIndex = Tools:IsFavorite(Tools.selectedLocation)
    local favLabel = AMM.LocalizableString("Favorite_Selected_Location")
    if isFavorite then
      favLabel = AMM.LocalizableString("Unfavorite_Selected_Location")
    end

    if ImGui.Button(favLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:ToggleFavoriteLocation(isFavorite, favIndex)
    end

    -- Check if file_name is not nil (meaning it's a user file)
    if Tools.selectedLocation.file_name and Tools.selectedLocation.cat_id ~= 12 then
      if ImGui.Button(AMM.LocalizableString("Edit_Selected_Location"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools:OpenLocationPopup(true)
      end
      ImGui.Spacing()
    end
  end

  if ImGui.Button(AMM.LocalizableString("Button_ShareCurrentLocation"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
    Tools:OpenLocationPopup()
  end

  if ImGui.IsItemHovered() then
    refreshLocationListDebounced()
    ImGui.SetTooltip(AMM.LocalizableString("Warn_UserLocationsFolder_Info"))
  end

  ImGui.Spacing()

  if Tools.lastLocation then
    if ImGui.Button(AMM.LocalizableString("Button_GoBackToLastLocation"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:TeleportToLocation(Tools.lastLocation)
    end
  end

  if Tools:IsUserLocation(Tools.selectedLocation) then
    if ImGui.Button(AMM.LocalizableString("Button_DeleteSelectedUserLocation"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:DeleteLocation(Tools.selectedLocation)
    end
  end

  if AMM.TeleportMod then
    ImGui.Spacing()
    Tools.useTeleportAnimation, clicked = ImGui.Checkbox(AMM.LocalizableString("Use_Teleport_Animation"), Tools.useTeleportAnimation)
    if clicked then
      AMM.userSettings.teleportAnimation = Tools.useTeleportAnimation
      AMM:UpdateSettings()
    end
    ImGui.SameLine()
    AMM.UI:TextColored(AMM.LocalizableString("LikeGTA_byGTATravel"))
  end

  Tools:DrawLocationPopup()
end

local function DrawTagsInFlow(tagList)
  local contentWidth = ImGui.GetWindowContentRegionWidth() - 20

  local spacing = ImGui.GetStyle().ItemSpacing.x   -- default horizontal spacing between items
  local xOffset = 0                                -- tracks how wide the current row is so far
  local removeIndex = nil                          -- used to remove a tag if user clicks on it

  -- We do a single pass, collecting any user-clicked removal in removeIndex
  -- and removing it after the loop to avoid skipping items.
  for i, tag in ipairs(tagList) do
    ImGui.PushID(i)  -- push a unique ID so each button has a distinct ID

    -- We'll measure the button text size to see if it fits in the current row
    local textSize = ImGui.CalcTextSize(tag)
    -- Add some extra padding for the button widget
    local buttonWidth = textSize + ImGui.GetStyle().FramePadding.x * 2

    -- If adding this button would exceed the contentWidth, start a new line
    if (xOffset + buttonWidth + spacing) > contentWidth then
      ImGui.NewLine()
      xOffset = 0
    end

    -- Draw the button. If user clicks, we mark removeIndex.
    if ImGui.Button(tag) then
      removeIndex = i
    end

    -- Advance the row offset
    xOffset = xOffset + buttonWidth + spacing

    -- Put subsequent items on same line (until we call NewLine())
    ImGui.SameLine()
    ImGui.PopID()
  end

  -- End the final line so subsequent UI draws beneath the buttons
  ImGui.NewLine()

  -- If the user clicked a tag, remove it from the list
  if removeIndex then
    table.remove(tagList, removeIndex)
  end
end

function Tools:DrawTaggingField()
  -- We'll keep Tools.locationTagInput as the field where user types a new tag
  Tools.locationTagInput = Tools.locationTagInput or ""

  ImGui.PushItemWidth(200)
  Tools.locationTagInput = ImGui.InputText("##TagInput", Tools.locationTagInput, 50)
  ImGui.PopItemWidth()

  ImGui.SameLine()
  if ImGui.Button(AMM.LocalizableString("Button_AddTag")) then
    local newTag = Tools.locationTagInput:gsub("^%s+", ""):gsub("%s+$", "")
    if newTag ~= "" then
      -- If editing an existing location
      if Tools.editingLocation then
        if not Tools.editingLocation.tags then
          Tools.editingLocation.tags = {}
        end
        -- Avoid duplicates
        local alreadyHasIt = false
        for _, t in ipairs(Tools.editingLocation.tags) do
          if t:lower() == newTag:lower() then
            alreadyHasIt = true
            break
          end
        end
        if not alreadyHasIt then
          table.insert(Tools.editingLocation.tags, newTag)
        end
      else
        -- If creating new location
        if not newLoc.tags then
          newLoc.tags = {}
        end
        local alreadyHasIt = false
        for _, t in ipairs(newLoc.tags) do
          if t:lower() == newTag:lower() then
            alreadyHasIt = true
            break
          end
        end
        if not alreadyHasIt then
          table.insert(newLoc.tags, newTag)
        end
      end
    end
    Tools.locationTagInput = ""  -- clear
  end

  -- Next, show the existing tags as small buttons
  ImGui.Spacing()

  local tagList = {}
  if Tools.editingLocation then
    tagList = Tools.editingLocation.tags or {}
  end

  -- Draw them using our helper:
  DrawTagsInFlow(tagList)
end

function Tools:GatherAllTagsForLocations(locList)
  local tagsSet = {}
  for _, loc in ipairs(locList) do
    if loc.tags and #loc.tags > 0 then
      for _, t in ipairs(loc.tags) do
        tagsSet[t] = true
      end
    end
  end

  -- Build a sorted array
  local result = {}
  for tag, _ in pairs(tagsSet) do
    table.insert(result, tag)
  end
  table.sort(result)

  return result
end

function Tools:ApplyTagFilters(locList)
  -- gather a list of tags that must be present:
  local requiredTags = {}
  for tag, isOn in pairs(Tools.tagFilters) do
    if isOn then
      table.insert(requiredTags, tag)
    end
  end

  if #requiredTags == 0 then
    -- No active tag filter => return original list
    return locList
  end

  -- Otherwise we do an AND approach: location must contain *all* requiredTags
  local filtered = {}
  for _, loc in ipairs(locList) do
    local hasAll = true
    if loc.tags == nil then
      hasAll = false
    else
      for _, reqTag in ipairs(requiredTags) do
        if not Tools:LocationHasTag(loc, reqTag) then
          hasAll = false
          break
        end
      end
    end
    if hasAll then
      table.insert(filtered, loc)
    end
  end

  return filtered
end

function Tools:LocationHasTag(loc, tag)
  if not loc.tags then return false end
  for _, t in ipairs(loc.tags) do
    if t:lower() == tag:lower() then
      return true
    end
  end
  return false
end

function Tools:DrawTagFilterPopup()
  ImGui.SetNextWindowSizeConstraints(300, 100, 400, 900)

  if ImGui.BeginPopup("TagFilterPopup") then
    ImGui.Text(AMM.LocalizableString("Button_FilterByTags")..":")
    ImGui.Spacing()

    -- If we have more than 10 tags, we’ll constrain them in a scrolling child
    local contentWidth = ImGui.GetWindowContentRegionWidth() - 20
    local childActive = false
    if #Tools.availableTags > 10 then
      childActive = true
      local childWidth = 300
      local childHeight = 200
      ImGui.BeginChild("TagFilterScroll", childWidth, childHeight, true)
      contentWidth = childWidth - 20
    end

    local spacing = ImGui.GetStyle().ItemSpacing.x
    local xOffset = 0

    for i, tag in ipairs(Tools.availableTags) do
      -- default to false if we haven't touched this tagFilter yet
      if Tools.tagFilters[tag] == nil then
        Tools.tagFilters[tag] = false
      end

      local state = (Tools.tagFilters[tag] == true)

      -- We measure how wide the label is, so we can decide whether to wrap
      local textSize = ImGui.CalcTextSize(tag)
      local padX = ImGui.GetStyle().FramePadding.x
      -- +20 is a rough guess for the checkbox box itself
      local checkboxWidth = textSize + (padX * 2) + 20

      -- If the next checkbox won't fit horizontally, wrap
      if (xOffset + checkboxWidth + spacing) > contentWidth then
        ImGui.NewLine()
        xOffset = 0
      end

      -- Draw the checkbox
      ImGui.PushID(i)
      local newVal, changed = ImGui.Checkbox(tag, state)
      ImGui.PopID()

      if changed then
        Tools.tagFilters[tag] = newVal
      end

      -- Advance row offset
      xOffset = xOffset + checkboxWidth + spacing
      ImGui.SameLine(150)
    end

    -- End the final line
    ImGui.NewLine()

    -- If we used a scroll child, close it
    if childActive then
      ImGui.EndChild()
    end

    AMM.UI:Separator()

    -----------------------------------------------------------------------
    -- Add a “Reset All” button to turn all checkboxes off:
    -----------------------------------------------------------------------
    if ImGui.Button(AMM.LocalizableString("Button_Reset")) then
      for _, tag in ipairs(Tools.availableTags) do
        Tools.tagFilters[tag] = false
      end
    end

    ImGui.SameLine()

    if ImGui.Button(AMM.LocalizableString("Button_Close")) then
      ImGui.CloseCurrentPopup()
    end

    ImGui.EndPopup()
  end
end

local function renameLocation(oldName, newName)
  -- check collision if newName already exists, etc.

  local oldPath = f("./User/Locations/%s.json", oldName)
  local newPath = f("./User/Locations/%s.json", newName)

  local oldFile = io.open(oldPath, "r")
  if oldFile then
    local contents = oldFile:read("*a")
    oldFile:close()

    local newFile = io.open(newPath, "w")
    if newFile then
      newFile:write(contents)
      newFile:close()

      -- remove old
      os.remove(oldPath)
    else
      print("Failed to open new file for writing")
    end
  else
    print("Failed to open old file for reading")
  end
end

function Tools:DrawLocationPopup()
  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
  ImGui.SetNextWindowSizeConstraints(400, -1, 400, 900)

  local popupTitle = Tools.currentPopupTitle or AMM.LocalizableString("Share_Location")

  if ImGui.BeginPopupModal(popupTitle, ImGuiWindowFlags.AlwaysAutoResize) then
    local style = {
        buttonHeight = ImGui.GetFontSize() * 2,
        halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12)
    }
  
    -- If the user tried to save with an already existing name, show a short error and "Ok" button
    if Tools.shareLocationName == 'existing' then
      ImGui.TextColored(1, 0.16, 0.13, 0.75, AMM.LocalizableString("Existing_Name"))
  
      if ImGui.Button("Ok", -1, style.buttonHeight) then
        Tools.shareLocationName = ''
      end
  
    else
      ----------------------------------------------------------------------
      -- 1) "Location Name" text input
      ----------------------------------------------------------------------
      Tools.shareLocationName = ImGui.InputText(
        AMM.LocalizableString("Name"),
        Tools.shareLocationName,
        50
      )

      ----------------------------------------------------------------------
      -- 2) Category dropdown
      ----------------------------------------------------------------------
      local catIDs = {}
      for cat_id = 1, 10 do
        table.insert(catIDs, cat_id)
      end

      local currentCatLabel = Tools:GetCategoryNameForLocationID(Tools.selectedCatIDForSaving)
      if ImGui.BeginCombo("##LocationsCategoryComboPopup", currentCatLabel) then
        for _, cat_id in ipairs(catIDs) do
          local label = Tools:GetCategoryNameForLocationID(cat_id)
          if ImGui.Selectable(label, (cat_id == Tools.selectedCatIDForSaving)) then
            Tools.selectedCatIDForSaving = cat_id
          end
        end
        ImGui.EndCombo()
      end

      ----------------------------------------------------------------------
      -- 3) Tags UI
      ----------------------------------------------------------------------
      Tools:DrawTaggingField()  -- This function reads/writes Tools.editingLocation.tags

      ImGui.Separator()
      AMM.UI:Spacing(2)

      ----------------------------------------------------------------------
      -- 4) "Save" + "Cancel" Buttons
      ----------------------------------------------------------------------
      if ImGui.Button(AMM.LocalizableString("Save"), style.halfButtonWidth + 8, style.buttonHeight) then
        local loc = Tools.editingLocation
        local oldName = loc.loc_name
        local newName = Tools.shareLocationName

        loc.loc_name = newName
        loc.cat_id   = Tools.selectedCatIDForSaving

        -- Are we creating a brand-new location or editing an existing one?
        if loc.isNew then

          -- check if file already exists:
          if io.open(f("./User/Locations/%s.json", newName), "r") then
            -- The name is taken
            Tools.shareLocationName = 'existing'
            goto skipClose
          else
            -- Fill in position from GetPlayerLocation(), if not set
            if not loc.x then
              local curPos = Tools:GetPlayerLocation()  -- returns pos + yaw
              loc.x   = curPos.pos.x
              loc.y   = curPos.pos.y
              loc.z   = curPos.pos.z
              loc.w   = curPos.pos.w
              loc.yaw = curPos.yaw
            end

            -- remove 'isNew' so we don't write it to JSON
            loc.isNew = nil

            Tools:SaveLocation(loc)
            Tools:LoadAllLocations()
            Tools.selectedLocation = loc
            Tools.shareLocationName = ''
            Tools.editingLocation   = nil

            ImGui.CloseCurrentPopup()
          end

        else
          -- Editing an existing location
          if oldName ~= newName then
            -- user changed the name, check for collisions
            if io.open(f("./User/Locations/%s.json", newName), "r") then
              Tools.shareLocationName = 'existing'
              goto skipClose
            else
              renameLocation(oldName, newName)
            end
          end

          -- remove 'isNew' if leftover
          loc.isNew = nil

          Tools:SaveLocation(loc)
          Tools:LoadAllLocations()
          Tools.selectedLocation = loc
          Tools.shareLocationName = ''
          Tools.editingLocation   = nil

          ImGui.CloseCurrentPopup()
        end

        ::skipClose::
      end

      ImGui.SameLine()
      if ImGui.Button(AMM.LocalizableString("Button_Cancel"), style.halfButtonWidth + 8, style.buttonHeight) then
        Tools.shareLocationName = ''
        Tools.selectedCatIDForSaving = 11
        Tools.editingLocation   = nil
        ImGui.CloseCurrentPopup()
      end
    end
    ImGui.EndPopup()
  end
end

function Tools:DrawLocationsDropdown()

  Tools.locationSearch = Tools.locationSearch or ""
  Tools.selectedLocationCategory = Tools.selectedLocationCategory or AMM.LocalizableString("Select_Category")
  Tools.selectedLocation = Tools.selectedLocation or { loc_name = AMM.LocalizableString("Select_Location") }

  -- 1) The search field
  ImGui.PushItemWidth(270)
  Tools.locationSearch = ImGui.InputTextWithHint(
                            " ",
                            AMM.LocalizableString("Filter_Locations"),
                            Tools.locationSearch,
                            100
                          )
  Tools.locationSearch = Tools.locationSearch:gsub('"', "")
  ImGui.PopItemWidth()

  -- If there's text, show "Clear" button
  if Tools.locationSearch ~= "" then
    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Clear")) then
      Tools.locationSearch = ""
    end
  end
  
  -- Re-fetch if text changed
  if Tools.locationSearch ~= Tools.lastLocationSearch then
    Tools.lastLocationSearch = Tools.locationSearch
    Tools.locations = Tools:GetLocations()
  end

  -- Gather all tags from the current Tools.locations
  Tools.availableTags = Tools:GatherAllTagsForLocations(Tools.locations or {})

  -- If we have tags, show "Filter by Tag" button
  if #Tools.availableTags > 0 and Tools.locationSearch == "" then
    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Button_FilterByTags")) then
      ImGui.OpenPopup("TagFilterPopup")
    end
    Tools:DrawTagFilterPopup()
  end

  --------------------------------------------------------
  -- 2) Build categories -> matching locations
  --------------------------------------------------------
  local filteredByCategory = {}
  local locList = Tools.locations or {}

  -- Apply the tag filter logic to locList:
  locList = Tools:ApplyTagFilters(locList)

  for _, loc in ipairs(locList) do
    local catName = Tools:GetCategoryNameForLocationID(loc.cat_id)
    filteredByCategory[catName] = filteredByCategory[catName] or {}
    table.insert(filteredByCategory[catName], loc)
  end

  -- We want Favorites (cat_id=12) at the top. So if there's a category "Favorites," we handle that first.
  local categories = {}
  for catName, arrayOfLocs in pairs(filteredByCategory) do
    table.insert(categories, catName)
  end
  table.sort(categories)

  -- If "Favorites" is among them, we move it to front:
  local iFav = nil
  for i, catName in ipairs(categories) do
    if catName == AMM.LocalizableString("Favorites") then
      iFav = i
      break
    end
  end
  if iFav then
    -- remove from that position
    local favCat = table.remove(categories, iFav)
    -- insert it at position 1
    table.insert(categories, 1, favCat)
  end

  -- If user’s selectedCategory is no longer present, reset it
  local function categoryExists(cname)
    for _, c in ipairs(categories) do
      if c == cname then return true end
    end
    return false
  end
  if Tools.selectedLocationCategory ~= AMM.LocalizableString("Select_Category") 
     and not categoryExists(Tools.selectedLocationCategory) 
  then
    Tools.selectedLocationCategory = AMM.LocalizableString("Select_Category")
    Tools.selectedLocation = { loc_name = AMM.LocalizableString("Select_Location") }
  end

  --------------------------------------------------------
  -- 3) If no categories, show "No Results"
  --------------------------------------------------------
  if #categories == 0 then
    ImGui.Text(AMM.LocalizableString("No_Results"))
    return
  end

  --------------------------------------------------------
  -- 4) Category combo
  --------------------------------------------------------
  if ImGui.BeginCombo("##LocationsCategoryCombo", Tools.selectedLocationCategory) then
    for _, catName in ipairs(categories) do
      if ImGui.Selectable(catName, (catName == Tools.selectedLocationCategory)) then
        Tools.selectedLocationCategory = catName
        Tools.selectedLocation = { loc_name = AMM.LocalizableString("Select_Location") }
      end
    end
    ImGui.EndCombo()
  end

  ImGui.SameLine()

  --------------------------------------------------------
  -- 5) Location combo
  --------------------------------------------------------
  if Tools.selectedLocationCategory ~= AMM.LocalizableString("Select_Category") then
    if ImGui.BeginCombo("##LocationsCombo", Tools.selectedLocation.loc_name) then
      local matchedLocs = filteredByCategory[Tools.selectedLocationCategory] or {}
      for i, location in ipairs(matchedLocs) do
        local displayName = location.loc_name
        local isSelected = (Tools.selectedLocation.loc_name == displayName)
        if ImGui.Selectable(displayName.."##"..i, isSelected) then
          Tools.selectedLocation = location
        end
        if isSelected then
          ImGui.SetItemDefaultFocus()
        end
      end
      ImGui.EndCombo()
    end
  end
end

function Tools:GetCategoryNameForLocationID(cat_id)
  local locationCategories = {
    [1] = "Residences",
    [2] = "ArasakaAndCorpo",
    [3] = "ClubsAndBars",
    [4] = "HotelsAndPleasure",
    [5] = "UndergroundAndCrime",
    [6] = "GovernmentAndSecurity",
    [7] = "StoryAndUnique",
    [8] = "Ripperdocs",
    [9] = "LandmarksAndOpenWorld",
    [10] = "SpoilersAndHidden",
    [11] = "UserLocations",
    [12] = "Favorites",
  }

  local catKey = locationCategories[cat_id]
  if catKey then
    return AMM.LocalizableString(catKey)
  else
    -- Fallback if ID not in table
    return "Unknown Category"
  end
end

function Tools:LoadAllLocations()
  -- 1) Create an empty table
  local allLocs = {}

  ---------------------------------------------------------------------
  -- 2) Load Favorites
  ---------------------------------------------------------------------
  -- Suppose Tools.favoriteLocations is already a table of [loc_name,x,y,z,w,yaw,...]
  -- We want to mark them with cat_id=12 so that they show in the "Favorites" category.
  if Tools.favoriteLocations and #Tools.favoriteLocations > 0 then
    for _, fav in ipairs(Tools.favoriteLocations) do
      table.insert(allLocs, {
        loc_name = fav.loc_name,
        x        = fav.x,
        y        = fav.y,
        z        = fav.z,
        w        = fav.w,
        yaw      = fav.yaw,
        cat_id   = 12,        -- Favorites
        file_name= fav.file_name or nil,
        -- any other fields you might want...
      })
    end
  end

  ---------------------------------------------------------------------
  -- 3) Load user-locations from JSON
  ---------------------------------------------------------------------
  -- If the user-loc JSON includes cat_id, read it; else default to 11
  local userLocs = Tools:GetUserLocations()
  if userLocs and #userLocs > 0 then
    for _, uloc in ipairs(userLocs) do

      -- If the JSON doesn’t specify a cat_id, default it to 11.
      local cat_id = uloc.cat_id
      if not cat_id then
        cat_id = 11
      end

      table.insert(allLocs, {
        loc_name = uloc.loc_name,
        x        = uloc.x,
        y        = uloc.y,
        z        = uloc.z,
        w        = uloc.w,
        yaw      = uloc.yaw,
        cat_id   = cat_id,
        file_name= uloc.file_name,
        tags     = uloc.tags,
      })
    end
  end

  ---------------------------------------------------------------------
  -- 4) Load default DB-locations
  ---------------------------------------------------------------------
  -- This is your standard DB approach. 
  -- Each DB row presumably has cat_id among its columns.
  local query = "SELECT * FROM locations ORDER BY loc_name ASC"
  for row in db:nrows(query) do
    -- row.loc_name, row.x, row.y, row.z, row.cat_id, etc.
    table.insert(allLocs, row)
  end

  -- 5) Cache the result
  Tools.allLocations = allLocs
  Tools.locations = Tools:GetLocations()
end

function Tools:GetLocations()
  local results = {}
  local lowerSearch = (Tools.locationSearch or ""):lower()

  for _, loc in ipairs(Tools.allLocations) do
    local lName = (loc.loc_name or ""):lower()
    
    -- Convert the tags to a single big string or iterate them
    local tagsCombined = ""
    if loc.tags and #loc.tags > 0 then
      tagsCombined = table.concat(loc.tags, " "):lower()
    end

    if lowerSearch == "" then
      table.insert(results, loc)
    else
      -- Check if location name or ANY of the tags contain the substring
      if lName:find(lowerSearch, 1, true)
         or tagsCombined:find(lowerSearch, 1, true)
      then
        table.insert(results, loc)
      end
    end
  end

  return results
end

function Tools:TeleportToLocation(loc)
  Tools.lastLocation = Tools:NewLocationData("Previous Location", Tools:GetPlayerLocation())

  if Tools.useTeleportAnimation then
    AMM.TeleportMod.api.requestTravel(Vector4.new(loc.x, loc.y, loc.z, loc.w))
  else
    Game.GetTeleportationFacility():Teleport(Game.GetPlayer(), Vector4.new(loc.x, loc.y, loc.z, loc.w), EulerAngles.new(0, 0, loc.yaw))
  end

  -- Teleport Companions with you if you have any spawned
  if next(AMM.Spawn.spawnedNPCs) ~= nil then
    local lastPos = Game.GetPlayer():GetWorldPosition()
    local teleportIsDone = false

    Cron.Every(0.1, { tick = 1 }, function(timer)

      timer.tick = timer.tick + 1

      if timer.tick > 10 then
        Cron.Halt(timer)
      end

      -- Travel Animation Done Check --
      if AMM.TeleportMod and AMM.TeleportMod.api.done then
        teleportIsDone = true
        AMM.TeleportMod.api.done = false
      end

      -- Regular Teleport Check --
      local currentPos = Game.GetPlayer():GetWorldPosition()
      if Util:VectorDistance(lastPos, currentPos) > 1 then
        teleportIsDone = true
      end

      if teleportIsDone then
        AMM:TeleportAll()
        Cron.Halt(timer)
      end
    end)
  end
end

function Tools:GetPlayerLocation()
  return { pos = Game.GetPlayer():GetWorldPosition(), yaw = Game.GetPlayer():GetWorldYaw() }
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

-- Join a table of strings into "tag1,tag2"
local function tagsToString(tagTable)
  if not tagTable or #tagTable == 0 then
    return ""
  end
  -- Join them with commas
  return table.concat(tagTable, ",")
end

function Tools:SaveLocation(loc)
  -- `loc` is a table that we are about to encode as JSON
  -- If we have `loc.tags` as a Lua table, we need to turn it into a string
  local tagString = tagsToString(loc.tags)
  loc.tags = tagString  -- store the CSV in the table so it writes properly

  local file = io.open(f("./User/Locations/%s.json", loc.loc_name), "w")
  if file then
    local contents = json.encode(loc)
    file:write(contents)
    file:close()
  end

  -- revert it so we keep a table in memory
  if tagString ~= "" then
    local splitted = {}
    for t in string.gmatch(tagString, "([^,]+)") do
      table.insert(splitted, t)
    end
    loc.tags = splitted
  else
    loc.tags = {}
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
  Tools.selectedLocation = {loc_name = AMM.LocalizableString("Select_Location")}
end

function Tools:ToggleFavoriteLocation(isFavorite, favIndex)
  if isFavorite then
    table.remove(Tools.favoriteLocations, favIndex)
  else
    table.insert(Tools.favoriteLocations, Tools.selectedLocation)
  end

  AMM:UpdateSettings()
  Cron.After(1.0, function() 
    Tools:LoadAllLocations()
  end)
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
    for _, locFile in ipairs(files) do
      if string.find(locFile.name, '.json') then
        local data = Tools:LoadLocationData(locFile.name)
        if data and data.loc_name then
          -- If no cat_id, default to 11 (UserLocations)
          data.cat_id = data.cat_id or 11

          -- Parse tags (if any) into a table
          local tagList = {}
          if data.tags then
            -- e.g. "safe,hidden" => { "safe", "hidden" }
            for tag in string.gmatch(data.tags, "([^,]+)") do
              local trimmed = tag:gsub("^%s+", ""):gsub("%s+$", "")
              table.insert(tagList, trimmed)
            end
          end

          local entry = {
            file_name = locFile.name,
            loc_name  = data.loc_name,
            x         = data.x,
            y         = data.y,
            z         = data.z,
            w         = data.w,
            yaw       = data.yaw,
            cat_id    = data.cat_id,
            -- Store tags as a table
            tags      = tagList
          }
          table.insert(userLocations, entry)
        else
          Util:AMMError(f("The file %s does not have location data", locFile.name))
        end
      end
    end
    return userLocations
  else
    return Tools.userLocations
  end
end

function Tools:LoadLocationData(fileName)
  local file = io.open('./User/Locations/'..fileName, 'r')
  if file then
    local contents = file:read("*a")
    file:close()
    local locationData = json.decode(contents)
    -- locationData includes:
    -- {
    --   "loc_name": "MyCustomLocation",
    --   "x": 123.45, "y": 678.90, "z": 1.0, "w": 1.0, "yaw": 90.0,
    --   "cat_id": 11
    -- }
    return locationData
  end
end

function Tools:OpenLocationPopup(isEditing)
  if isEditing then
    -- Prepare the popup for editing
    Tools.editingLocation = Util:DeepCopy(Tools.selectedLocation)
    Tools.editingLocation.isNew = false

    -- Pre-fill the text field with current name
    Tools.shareLocationName = Tools.editingLocation.loc_name or ""

    -- Pre-fill the category ID
    if Tools.editingLocation.cat_id then
      Tools.selectedCatIDForSaving = Tools.editingLocation.cat_id
    else
      Tools.selectedCatIDForSaving = 11  -- default fallback
    end
    
    Tools.currentPopupTitle = AMM.LocalizableString("Edit_Location")
  else
    Tools.editingLocation = {}
    Tools.editingLocation.isNew = true
    Tools.editingLocation.cat_id = 11       -- default to 11 (UserLocations)
    Tools.editingLocation.tags   = {}       -- empty tags

    Tools.shareLocationName      = ""       -- so the user sees an empty name field
    Tools.selectedCatIDForSaving = 11

    Tools.currentPopupTitle = AMM.LocalizableString("Share_Location")
  end

  ImGui.OpenPopup(Tools.currentPopupTitle)
end

-- Target actions
function Tools:DrawNPCActions()

  AMM.UI:DrawCrossHair()

  if AMM.playerInPhoto then

    local nibbles = Tools:GetNibblesTarget()
    if nibbles and not Tools.puppetsIDs[nibbles.hash] then
      Tools.puppetsIDs[nibbles.hash] = nibbles.entityID
      table.insert(Tools.listOfPuppets, nibbles)
    end

    local buttonWidth = Tools.style.buttonWidth
    if #Tools.listOfPuppets > 1 then buttonWidth = Tools.style.halfButtonWidth end

    Tools:ClearListOfPuppets()

    if #Tools.listOfPuppets > 0 then
      for i, puppet in ipairs(Tools.listOfPuppets) do        
        if i % 2 == 0 then
          ImGui.SameLine()
        end

        if ImGui.Button(f(AMM.LocalizableString("Button_Target").."%s##%i", puppet.name, i), buttonWidth, Tools.style.buttonHeight) then
          if AMM.userSettings.resetPositionTargetPhotoMode and puppet.pos then
            Tools.updatedPosition[puppet.hash] = true
            Tools:SetTargetPosition(puppet.pos, puppet.angles, puppet)
          end

          Tools:SetCurrentTarget(puppet)
          Tools.lockTarget = true
        end
      end
    end

    AMM.UI:Spacing(2)
  end

  if Tools.currentTarget and Tools.currentTarget ~= '' and Tools.currentTarget.handle then
    if not Game.FindEntityByID(Tools.currentTarget.handle:GetEntityID()) then
      Tools.currentTarget = ''
    end
  end

  if target ~= nil or (Tools.currentTarget and Tools.currentTarget ~= '') then

    if not AMM.userSettings.floatingTargetTools then
      AMM.UI:TextCenter(AMM.LocalizableString("Movement"), true)
    end

    if AMM.userSettings.floatingTargetTools then
      local buttonLabel = AMM.LocalizableString("Button_Label_OpenTargetTools")
      if Tools.movementWindow.open then
        buttonLabel = AMM.LocalizableString("Button_Label_CloseTargetTools")
      end

      if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools.movementWindow.open = not Tools.movementWindow.open
      end
    else
      Tools.movementWindow.open = true
      Tools:DrawMovementWindow()
    end
  else
    AMM.UI:Spacing(3)

    if AMM.playerInPhoto then
      AMM.UI:TextCenter(AMM.LocalizableString("Warn_SeeMoreAction_Info"))
    else
      AMM.UI:TextCenter(AMM.LocalizableString("Warn_SeeMoreActionProp_Info"))
    end

    AMM.UI:Spacing(4)
  end

  if not AMM.playerInPhoto then
    if ImGui.InvisibleButton("Fun Mode", 100, 20) then
      psyUnh = true
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(AMM.LocalizableString("InvButtonTip3"))
    end

    AMM.UI:Spacing(4)

    AMM.UI:TextCenter(AMM.LocalizableString("General_Actions"), true)
    ImGui.Spacing()

    if Tools.cyberpsychoMode then
      -- Push the style color for Button, ButtonHovered, and ButtonActive
      ImGui.PushStyleColor(ImGuiCol.Button, 1.0, 0.0, 0.0, 1.0)          -- Bright red button
      ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 1.0, 0.2, 0.2, 1.0)   -- Lighter red when hovered
      ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.8, 0.0, 0.0, 1.0)    -- Slightly darker red when active

       -- Text Color (Black)
      ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.0, 0.0, 1.0)
    end
    
    if psyUnh then
      if ImGui.Button(AMM.LocalizableString("Button_Cyberpsycho"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools.cyberpsychoMode = not Tools.cyberpsychoMode

        if Tools.cyberpsychoMode == true then

          Cron.Every(1, { tick = 1 }, function(timer)
            -- Check if there are spawned NPCs
            if next(AMM.Spawn.spawnedNPCs) ~= nil then
                local _, spawn = Util:SelectRandomPair(AMM.Spawn.spawnedNPCs)
                if spawn then
                    psycho = spawn.handle -- Assign the random psycho
                end
            end
        
            -- If psycho is assigned, proceed with the rest of the logic
            if psycho ~= nil then
                Cron.Halt(timer) -- Stop this Cron
        
                -- Run the rest of your logic here
                local function runCyberpsycho()
                    local targets = {}
                    Tools:UseGeneralAction(function(ent) 
                        Tools:SetNPCAttitude(ent, EAIAttitude.AIA_Neutral, nil, CName.new("panam"))
                        table.insert(targets, ent.handle)
                    end, 30)
        
                    Tools:SetCyberpsycho(psycho, targets)
                end
        
                runCyberpsycho()
        
                -- Setup a 3-second recurring Cron for cyberpsycho behavior
                Cron.Every(3, { tick = 1 }, function(timer)
                    timer.tick = timer.tick + 1
        
                    if timer.tick > 60 or Tools.cyberpsychoMode == false then
                        AMM.Spawn:SetNPCAsCompanion(psycho)
                        Cron.Halt(timer)
                    else
                        runCyberpsycho()
                    end
                end)
            end
        
            -- Stop if we've hit the maximum allowed ticks
            if timer.tick >= 30 then
                Cron.Halt(timer)
            else
                timer.tick = timer.tick + 1
            end
          end)
        end
      end

      if Tools.cyberpsychoMode then
        -- Pop the styles to restore previous colors
        ImGui.PopStyleColor(4)
      end
    end

    if ImGui.Button(AMM.LocalizableString("Button_ProtectNPCfromActions"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      if target and target.handle and target.handle.IsNPC and target.handle:IsNPC() then
        Tools:ProtectTarget(target)
      end
    end

    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Button_AllFollower"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) AMM.Spawn:SetNPCAsCompanion(ent.handle) end, 10)
    end

    if ImGui.Button(AMM.LocalizableString("Button_AllFriendly"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) Tools:SetNPCAttitude(ent, EAIAttitude.AIA_Friendly) end, 10)
    end

    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Button_AllHostile"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) Tools:SetNPCAttitude(ent, EAIAttitude.AIA_Hostile) end, 10)
    end

    if ImGui.Button(AMM.LocalizableString("Button_AllFakeDie"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) ent.handle:SendAIDeathSignal() end, 20)
    end

    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Button_AllDie"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) ent.handle:Kill(ent.handle, false, false) end, 20)
    end

    if ImGui.Button(AMM.LocalizableString("Button_AllDespawn"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) ent.handle:Dispose() end, 20)
    end

    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Button_CyclesAppearances"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:UseGeneralAction(function(ent) AMM:ChangeScanAppearanceTo(ent, "Cycle") end, 20)
    end
  end
end

function Tools:UpdateTargetPosition(target)
  local t = Tools.currentTarget
  if target then t = target end

  Tools.updatedPosition[t.hash] = true

  if t.type ~= 'Player' and t.name ~= 'Replacer' and t.handle.IsNPC and t.handle:IsNPC() and not t.isPuppet then
    Cron.After(0.2, function()
      if t.UpdatePosition then
        t:UpdatePosition()
      end
      
      if Tools.axisIndicator then
        Tools:UpdateAxisIndicatorPosition()
      end
    end)
  else
    -- This flag is used to check if the user is using t Tools
    -- If they are, we reset puppets position when the PM UI is used
    Tools.updatedPosition[t.hash] = true

    if t.UpdatePosition then
      t:UpdatePosition()
    end
    
    if Tools.axisIndicator then
      Tools:UpdateAxisIndicatorPosition()
    end
  end
end

function Tools:SetTargetPosition(pos, angles, target)
  local t = Tools.currentTarget
  if target then t = target end

  if t.type == 'entEntity' then
    if not Tools.movingProp then
      Tools:TeleportPropTo(t, pos, angles or EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
    end
  elseif t.type ~= 'Player' and t.name ~= 'Replacer' and t.handle:IsNPC() and not t.isPuppet then
    local yaw = Tools.npcRotation[3]
    if angles then yaw = angles.yaw end
    Tools:TeleportNPCTo(t.handle, pos, yaw)
  else
    Game.GetTeleportationFacility():Teleport(t.handle, pos, angles or EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
  end

  Cron.After(0.2, function()
    local hash = t.hash
    if AMM.Poses.activeAnims[hash] then
      local anim = AMM.Poses.activeAnims[hash]
      AMM.Poses:RestartAnimation(anim)
    end

    Tools:UpdateTargetPosition(t)

    if not target then
      Tools:SetCurrentTarget(t)
    end
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
  Tools.currentTarget = target

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

function Tools:ResetFacialExpression(target)
  local stimComp = target.handle:FindComponentByName("ReactionManager")

  if stimComp then
    stimComp:ResetFacial(0)
    Tools.activatedFace = false
  end
end

function Tools:ActivateFacialExpression(target, face)

  local stimComp = target.handle:FindComponentByName("ReactionManager")
  local animComp = target.handle:FindComponentByName("AnimationControllerComponent")

  if stimComp and animComp then
    stimComp:ResetFacial(0)

    Cron.After(0.5, function()
      local animFeat = NewObject("handle:AnimFeature_FacialReaction")
      animFeat.category = face.category
      animFeat.idle = face.idle
      animComp:ApplyFeature(CName.new("FacialReaction"), animFeat)

      Tools.activatedFace = true
      Tools.lastActivatedFace = face
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

    TimeDilationHelper.SetIndividualTimeDilation(handle, CName.new("radialMenu"), 0.0)
    Tools.frozenNPCs[tostring(handle:GetEntityID().hash)] = true
  else
    TimeDilationHelper.UnsetIndividualTimeDilation(handle)
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

local cyberpsychoEffects = {}
function Tools:SpawnCyberpsychoEffects(entity)
  if #cyberpsychoEffects == 0 then
    local spawnTransform = Game.GetPlayer():GetWorldTransform()
    spawnTransform:SetPosition(entity:GetWorldPosition())
    spawnTransform:SetOrientationEuler(entity:GetWorldOrientation():ToEulerAngles())

    entityID = exEntitySpawner.Spawn([[base\amm_particles\entity\heat_haze_large.ent]], spawnTransform, CName.new('default'), '')
    table.insert(cyberpsychoEffects, entityID)

    entityID = exEntitySpawner.Spawn([[base\amm_effects\entity\alt_background.ent]], spawnTransform, CName.new('default'), '')
    table.insert(cyberpsychoEffects, entityID)

    local shouldDespawn = false

    Cron.Every(0.01, function(timer)
      if Tools.cyberpsychoMode == false or not Game.FindEntityByID(entity:GetEntityID()) then
        shouldDespawn = true
      end

      for i, entID in ipairs(cyberpsychoEffects) do
        local ent = Game.FindEntityByID(entID)
        if ent then
          if shouldDespawn then
            ent:Dispose()
            table.remove(cyberpsychoEffects, i)
          else
            Game.GetTeleportationFacility():Teleport(ent, entity:GetWorldPosition(), entity:GetWorldOrientation():ToEulerAngles())
          end
        end
      end

      if shouldDespawn and #cyberpsychoEffects == 0 then
        Tools.cyberpsychoMode = false
        Cron.Halt(timer)
      end
    end)
  end
end

function Tools:SetCyberpsycho(entity, targets)
  if entity then
    local currentRole = entity:GetAIControllerComponent():GetAIRole()
    currentRole:OnRoleCleared(entity)

    local AIRole = AIRole.new()
		
    entity:GetAIControllerComponent():SetAIRole(AIRole)
    entity:GetAIControllerComponent():OnAttach()

    entity:GetAttitudeAgent():SetAttitudeGroup(CName.new("judy"))
    entity:GetAttitudeAgent():SetAttitudeTowards(Game.GetPlayer():GetAttitudeAgent(), EAIAttitude.AIA_Neutral)
    Game.GetAttitudeSystem():SetAttitudeRelationFromTweak(TweakDBID.new("Attitudes.Group_Judy"), TweakDBID.new("Attitudes.Group_Panam"), EAIAttitude.AIA_Hostile)

    if targets and #targets > 0 then
      local randomSequence = Util:GenerateRandomSequence(#targets)
      local target = targets[randomSequence[math.random(1, #randomSequence)]]

      local sensePreset = TweakDBInterface.GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive"))
      entity.reactionComponent:SetReactionPreset(sensePreset)
      entity.reactionComponent:TriggerCombat(target)
      Tools:SpawnCyberpsychoEffects(entity)
    end
  end
end

function Tools:SetNPCAttitude(entity, attitude, target, group)
  if entity then
    local t = Game.GetPlayer()
    if target then t = target end

    local targetGroup = t:GetAttitudeAgent():GetAttitudeGroup()
    if group then targetGroup = group end

    entity.handle:GetAttitudeAgent():SetAttitudeGroup(targetGroup)
    entity.handle:GetAttitudeAgent():SetAttitudeTowards(t:GetAttitudeAgent(), attitude)
  end
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
    Tools.movementWindow.open, Tools.movementWindow.shouldDraw = ImGui.Begin(AMM.LocalizableString("Target_Tools").."##Floating", Tools.movementWindow.open, ImGuiWindowFlags.AlwaysAutoResize)
  end

  if Tools.movementWindow.shouldDraw then

    if not Tools.lockTarget or Tools.currentTarget == '' then
      Tools.lockTarget = false
      if target == nil and Tools.currentTarget ~= '' and Tools.currentTarget.type ~= "Player" then
        Tools.currentTarget = ''
      elseif Tools.currentTarget == '' or (not(Tools.holdingNPC) and (target and (target.handle ~= nil and Tools.currentTarget.handle) and Tools.currentTarget.handle:GetEntityID().hash ~= target.handle:GetEntityID().hash)) then
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

    local buttonLabel = AMM.LocalizableString("Button_LabelLockTarget")
    if Tools.lockTarget then
      buttonLabel = AMM.LocalizableString("Button_LabelUnlockTarget")
    end

    ImGui.SameLine()
    if ImGui.SmallButton(buttonLabel) then
      Tools.lockTarget = not Tools.lockTarget
      Tools:SetCurrentTarget(Tools.currentTarget)
    end

    if AMM.userSettings.experimental then
      ImGui.SameLine()
      if ImGui.SmallButton(AMM.LocalizableString("Button_SmallDespawn_WithSpace")) then
        Tools.currentTarget:Despawn()
      end
    end

    ImGui.Spacing()

    local adjustmentValue = 0.01
    if Tools.relativeMode then adjustmentValue = 0.005 end
    if Tools.precisionMode then adjustmentValue = 0.001 end

    local upDownRowWidth = ImGui.GetWindowContentRegionWidth() - (ImGui.CalcTextSize(AMM.LocalizableString("Tilt_Rotation")) + 10)

    if Tools.axisIndicator then
      if Tools.relativeMode then
        AMM.UI:PushStyleColor(ImGuiCol.FrameBg, {217, 212, 122, 1})
      else
        AMM.UI:PushStyleColor(ImGuiCol.FrameBg, {227, 42, 21, 1})
      end

      AMM.UI:PushStyleColor(ImGuiCol.Text, {0, 0, 0, 1})
    end

    local surfaceWiseRowWidth = (upDownRowWidth / 3) - 6
    local leftUsed, rightUsed, upDownUsed = false, false, false

    ImGui.PushItemWidth(surfaceWiseRowWidth)
    Tools.npcLeft, leftUsed = ImGui.DragFloat("##X", Tools.npcLeft, adjustmentValue)

    if Tools.axisIndicator then
      ImGui.PopStyleColor(2)
    end

    if ImGui.IsItemDeactivatedAfterEdit() then
      local hash = Tools.currentTarget.hash
      if AMM.Poses.activeAnims[hash] then
        local anim = AMM.Poses.activeAnims[hash]
        AMM.Poses:RestartAnimation(anim)
      end

      Tools:UpdateTargetPosition()
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

      Tools:UpdateTargetPosition()
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

    ImGui.PopItemWidth() -- surfaceWiseRowidth

    if Tools.axisIndicator then
      ImGui.PopStyleColor(2)
    end

    if ImGui.IsItemDeactivatedAfterEdit() then
      local hash = Tools.currentTarget.hash
      if AMM.Poses.activeAnims[hash] then
        local anim = AMM.Poses.activeAnims[hash]
        AMM.Poses:RestartAnimation(anim)
      end

      Tools:UpdateTargetPosition()
    end

    if Tools.relativeMode and ImGui.IsItemDeactivatedAfterEdit() then
      Tools.npcUpDown = 0
    end

    if AMM.userSettings.advancedRotation then
      ImGui.PushItemWidth((upDownRowWidth / 3) - 82)
      
      if AMM.UI:GlyphButton(IconGlyphs.MinusThick.."##X") then
        Tools.npcLeft = Tools.npcLeft - (Tools.advX / 10000)
        leftUsed = true
      end

      ImGui.SameLine()

      Tools.advX = ImGui.DragInt("##advX", Tools.advX, 1, 0, 360)
      
      ImGui.SameLine()

      if AMM.UI:GlyphButton(IconGlyphs.PlusThick.."##X") then
        Tools.npcLeft = Tools.npcLeft + (Tools.advX / 10000)
        leftUsed = true
      end

      ImGui.SameLine()

      if AMM.UI:GlyphButton(IconGlyphs.MinusThick.."##Y") then
        Tools.npcRight = Tools.npcRight - (Tools.advY / 10000)
        rightUsed = true
      end

      ImGui.SameLine()

      Tools.advY = ImGui.DragInt("##advY", Tools.advY, 1, 0, 360)
      
      ImGui.SameLine()

      if AMM.UI:GlyphButton(IconGlyphs.PlusThick.."##Y") then
        Tools.npcRight = Tools.npcRight + (Tools.advY / 10000)
        rightUsed = true
      end

      ImGui.SameLine()

      if AMM.UI:GlyphButton(IconGlyphs.MinusThick.."##Z") then
        Tools.npcUpDown = Tools.npcUpDown - (Tools.advZ / 10000)
        upDownUsed = true
      end

      ImGui.SameLine()

      Tools.advZ = ImGui.DragInt("##advZ", Tools.advZ, 1, 0, 360)
      
      ImGui.SameLine()

      if AMM.UI:GlyphButton(IconGlyphs.PlusThick.."##Z") then
        Tools.npcUpDown = Tools.npcUpDown + (Tools.advZ / 10000)
        upDownUsed = true
      end

      ImGui.PopItemWidth()
    end
   

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
      elseif Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() and not Tools.currentTarget.isPuppet then
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
      elseif Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() and not Tools.currentTarget.isPuppet then
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
    if Tools.currentTarget ~= '' and (Tools.currentTarget.type ~= 'Prop' and Tools.currentTarget.type ~= 'entEntity' and Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() and not Tools.currentTarget.isPuppet) then
      Tools.npcRotation[3], rotationUsed = ImGui.SliderFloat(AMM.LocalizableString("Rotation"), Tools.npcRotation[3], -180, 180)
      isNPC = true
    elseif Tools.currentTarget ~= '' then
      Tools.npcRotation, rotationUsed = ImGui.DragFloat3(AMM.LocalizableString("Tilt_Rotation"), Tools.npcRotation, rotationValue)
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
      elseif Tools.currentTarget.type ~= 'Player' and Tools.currentTarget.name ~= 'Replacer' and Tools.currentTarget.handle:IsNPC() and not Tools.currentTarget.isPuppet then
        Tools:TeleportNPCTo(Tools.currentTarget.handle, pos, Tools.npcRotation[3])
      else
        Game.GetTeleportationFacility():Teleport(Tools.currentTarget.handle, pos, EulerAngles.new(Tools.npcRotation[1], Tools.npcRotation[2], Tools.npcRotation[3]))
      end

      Tools:UpdateTargetPosition()    
    end

    ImGui.Spacing()

    AMM.UI:TextColored(AMM.LocalizableString("Mode"))

    ImGui.SameLine()
    Tools.precisionMode = AMM.UI:SmallCheckbox(Tools.precisionMode, AMM.LocalizableString("Precision"))

    ImGui.SameLine()
    Tools.relativeMode, relativeToggle = AMM.UI:SmallCheckbox(Tools.relativeMode, AMM.LocalizableString("Relative"))

    ImGui.SameLine()
    Tools.directMode, directToggle = AMM.UI:SmallCheckbox(Tools.directMode, AMM.LocalizableString("Direct"))

    ImGui.SameLine()
    AMM.userSettings.advancedRotation = AMM.UI:SmallCheckbox(AMM.userSettings.advancedRotation, AMM.LocalizableString("AdvMovement"))

    ImGui.SameLine()
    Tools.axisIndicatorToggle, axisToggle = AMM.UI:SmallCheckbox(Tools.axisIndicatorToggle, IconGlyphs.AxisArrow)

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(AMM.LocalizableString("Warn_ShowXYZ_Orientation_Info"))
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
      speed = ImGui.DragFloat(AMM.LocalizableString("Drag_MovementSpeed"), speed, 1, 1, 1000, "%.0f")
      Tools.currentTarget.speed = speed / 1000
    end

    AMM.UI:Spacing(3)

    local hash = Tools.currentTarget.hash
    if AMM.Poses.activeAnims[hash] or Tools.activatedFace then
      ImGui.PushItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(AMM.LocalizableString("Slider_SlowMotion")) - 10)
      Tools.slowMotionSpeed, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_SlowMotion"), Tools.slowMotionSpeed, 0.000001, Tools.slowMotionMaxValue)
      if used then
        Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
      end
      ImGui.PopItemWidth()
    end

    AMM.UI:Spacing(3)

    AMM.UI:TextCenter(AMM.LocalizableString("Position"), true)

    local buttonLabel = AMM.LocalizableString("Save")
    if Tools.savedPosition ~= '' then
      buttonLabel = AMM.LocalizableString("Restore")
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

    if ImGui.Button(AMM.LocalizableString("Button_ResetToPlayer"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      local pos = AMM.player:GetWorldPosition()

      if Tools.currentTarget.type == "vehicle" then
        local heading = AMM.player:GetWorldForward()
        pos = Vector4.new(pos.x + (heading.x * 2), pos.y + (heading.y * 2), pos.z + heading.z, pos.w + heading.w)
      end

      Tools:SetTargetPosition(pos)
    end

    if Tools.savedPosition ~= '' then
      if ImGui.Button(AMM.LocalizableString("Button_ClearSaved"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
        Tools.savedPosition = ''
      end
    end

    ImGui.Spacing()

    if not AMM.playerInPhoto and Tools.currentTarget ~= '' and Tools.currentTarget.type ~= 'entEntity' then

      local buttonLabel = AMM.LocalizableString("Button_Label_PickUpTarget")
      if Tools.holdingNPC then
        buttonLabel = AMM.LocalizableString("Button_Label_DropTarget")
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
        local buttonLabel = AMM.LocalizableString("Button_Label_FreezeTarget")
        if Tools.frozenNPCs[tostring(Tools.currentTarget.handle:GetEntityID().hash)] then
          buttonLabel = AMM.LocalizableString("Button_Label_UnfreezeTarget")
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
            ImGui.TextWrapped(AMM.LocalizableString("Warn_Photomode_UnfreezeSkipFrames_Info"))
            ImGui.PopTextWrapPos()
            ImGui.EndTooltip()
          end
        end

        if not AMM.playerInPhoto and not Tools.currentTarget.handle.isPlayerCompanionCached then

          if Tools:ShouldCrouchButtonAppear(Tools.currentTarget) then
            local buttonLabel = AMM.LocalizableString("Button_Label_ChangeToCrouchStance")
            if Tools.isCrouching then
              buttonLabel = AMM.LocalizableString("Button_Label_ChangeToStandStance")
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
        AMM.UI:TextCenter(AMM.LocalizableString("Facial_Expression"), true)
        ImGui.Spacing()

        Tools:DrawFacialExpressionDropdown()

        ImGui.SameLine()

        if Tools.activatedFace and ImGui.SmallButton(AMM.LocalizableString("Button_SmallReset")) then
          Tools:ResetFacialExpression(Tools.currentTarget)
        end

        ImGui.Spacing()
        
        if (not AMM.playerInPhoto or AMM.userSettings.allowLookAtForNPCs) and Tools.currentTarget ~= '' then

          AMM.UI:Spacing(4)

          local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)

          AMM.UI:TextCenter(AMM.LocalizableString("Look_At"), true)
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
          if ImGui.SmallButton(AMM.LocalizableString("Button_SmallReset")) then
            Tools:ResetLookAt()
            reset = true
          end

          ImGui.Spacing()

          if Tools.selectedLookAt.name ~= AMM.LocalizableString("Eyes_Only") then
            Tools.headStiffness, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_HeadStiffness"), Tools.headStiffness, 0.0, 1.0, "%.1f")
            if Tools.lookAtActiveNPCs[npcHash] and (used or reset) then Tools:ActivateLookAt() end

            Tools.headPoseOverride, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_HeadPoseOverride"), Tools.headPoseOverride, 0.0, 1.0, "%.1f")
            if Tools.lookAtActiveNPCs[npcHash] and (used or reset) then Tools:ActivateLookAt() end
          end

          if Tools.selectedLookAt.name == AMM.LocalizableString("All") then
            Tools.chestStiffness, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_ChestStiffness"), Tools.chestStiffness, 0.0, 2.0, "%.1f")
            if Tools.lookAtActiveNPCs[npcHash] and (used or reset) then Tools:ActivateLookAt() end

            Tools.chestPoseOverride, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_ChestPoseOverride"), Tools.chestPoseOverride, 0.0, 2.0, "%.1f")
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

          ImGui.Text(AMM.LocalizableString("Current_Target"))

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
          local buttonLabel = AMM.LocalizableString("Button_Label_Activate")
          if Tools.lookAtActiveNPCs[npcHash] then
            buttonLabel = AMM.LocalizableString("Button_Label_Deactivate")
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

          if ImGui.SmallButton(AMM.LocalizableString("Button_SmallReset")) then
            if target ~= nil then
              Tools.lookAtTarget = nil
            end
          end
          
          Tools.enablePropsInLookAtTarget = ImGui.Checkbox(AMM.LocalizableString("EnableSpawnedProps"), Tools.enablePropsInLookAtTarget)
        end
      end

      if AMM.userSettings.experimental and Tools.currentTarget ~= '' and Tools.currentTarget.handle:IsNPC() then
         
        local weapon = Util:GetPlayerWeapon()
        local npcHasWeapon = Tools.currentTarget.handle:HasPrimaryOrSecondaryEquipment()

        if npcHasWeapon or weapon then
          AMM.UI:Spacing(4)
          AMM.UI:TextCenter(AMM.LocalizableString("Equipment"), true)
          ImGui.Spacing()
        end

        if npcHasWeapon then
          if ImGui.Button(AMM.LocalizableString("Button_TogglePrimaryWeapon"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
            -- Toggle Weapons doesn't seem to work anymore
            -- equippedWeaponNPCs isn't doing anything right now
            -- I will leave it here in case I find a solution for UnequipWeapon
            local npcHash = Tools.currentTarget.hash
            if Tools.equippedWeaponNPCs[npcHash] == nil then
              Tools.equippedWeaponNPCs[npcHash] = {primary = false, secondary = false}
            else
              Tools.equippedWeaponNPCs[npcHash].primary = not Tools.equippedWeaponNPCs[npcHash].primary
            end            

            AMM:ResetFollowCommandAfterAction(Tools.currentTarget, function(handle)
              Util:EquipPrimaryWeaponCommand(handle)
            end)            
          end

          ImGui.SameLine()
          if ImGui.Button(AMM.LocalizableString("Button_ToggleSecondaryWeapon"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
            local npcHash = tostring(Tools.currentTarget.handle:GetEntityID().hash)
            if Tools.equippedWeaponNPCs[npcHash] == nil then
              Tools.equippedWeaponNPCs[npcHash] = {primary = false, secondary = false}
            else
              Tools.equippedWeaponNPCs[npcHash].secondary = not Tools.equippedWeaponNPCs[npcHash].secondary
            end

            AMM:ResetFollowCommandAfterAction(Tools.currentTarget, function(handle) 
              Util:EquipSecondaryWeaponCommand(handle)
            end)
          end
        end

        if weapon then
          if ImGui.Button(AMM.LocalizableString("Button_GiveCurrentEquippedWeapon"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
            local npcHash = Tools.currentTarget.hash
            if Tools.equippedWeaponNPCs[npcHash] == nil then
              Tools.equippedWeaponNPCs[npcHash] = {primary = false, secondary = false}
            else
              Tools.equippedWeaponNPCs[npcHash].primary = not Tools.equippedWeaponNPCs[npcHash].primary
            end
            
            local weaponTDBID = weapon:GetItemID().tdbid
            Util:EquipGivenWeapon(Tools.currentTarget.handle, weaponTDBID, Tools.forceWeapon)

            AMM:ResetFollowCommandAfterAction(Tools.currentTarget, function(handle)
              Util:EquipPrimaryWeaponCommand(handle)
            end)
          end

          if ImGui.IsItemHovered() then
            ImGui.SetTooltip(AMM.LocalizableString("Warn_OutOfCombat_NpcUnequip_Info"))
          end

          -- Disabled Force Given since it is freezing the NPC in place
          -- ImGui.Spacing()
          -- Tools.forceWeapon = ImGui.Checkbox(AMM.LocalizableString("ForceGivenWeapon"), Tools.forceWeapon)

          -- if ImGui.IsItemHovered() then
          --   ImGui.SetTooltip(AMM.LocalizableString("Warn_StopNpc_UnequipWeapon_Info"))
          -- end
        end
      end
    elseif Tools.currentTarget and Tools.currentTarget ~= '' then

      if Tools.currentTargetComponents == nil then
        Tools.currentTargetComponents = AMM.Props:CheckForValidComponents(Tools.currentTarget.handle)
      end

      local components = Tools.currentTargetComponents
            
      if components and Tools.currentTarget.scale then
        AMM.UI:Spacing(4)
        AMM.UI:TextCenter(AMM.LocalizableString("Scale"), true)

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

        Tools.proportionalMode, proportionalModeChanged = ImGui.Checkbox(AMM.LocalizableString("ProportionalMode"), Tools.proportionalMode)

        if proportionalModeChanged then
          Tools:SetScale(components, Tools.currentTarget.scale, Tools.proportionalMode)
        end

        if ImGui.Button(AMM.LocalizableString("Button_ResetScale"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
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

      ImGui.Text(AMM.LocalizableString("Current_Target"))
      ImGui.SameLine()
      AMM.UI:TextColored(lookAtTargetName)

      if ImGui.Button(AMM.LocalizableString("Button_ShowAsLookAtTarget"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        if Tools.currentTarget ~= '' then
          Tools.lookAtTarget = Tools.currentTarget
        end
      end

      ImGui.SameLine()
      if ImGui.Button(AMM.LocalizableString("Button_ResetLookAtTarget"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
        if target ~= nil then
          Tools.lookAtTarget = nil
        end
      end
    end

    if Tools.currentTarget and Tools.currentTarget ~= '' then
      local appOptions = Tools.currentTarget.options or AMM:GetAppearanceOptions(Tools.currentTarget.handle, Tools.currentTarget.id)

      if appOptions then
        AMM.UI:Spacing(4)

        AMM.UI:TextCenter(AMM.LocalizableString("List_of_Appearances"), true)

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

        AMM.UI:TextCenter(AMM.LocalizableString("LightControl"), true)

        if ImGui.Button(AMM.LocalizableString("Button_ToggleLight"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
          if AMM.Props.hiddenProps[Tools.currentTarget.hash] then
            AMM.Props.hiddenProps[Tools.currentTarget.hash] = nil
          end
          AMM.Light:ToggleLight(AMM.Light:GetLightData(Tools.currentTarget))
        end

        ImGui.SameLine()
        local buttonLabel = AMM.LocalizableString("Button_Label_OpenLightSettings")
        if AMM.Light.isEditing then
          buttonLabel = AMM.LocalizableString("Button_Label_UpdateLightTarget")
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

  if AMM.CodewareVersion >= 4 and Tools.weatherSystem then
    local selectedWeatherOption = Tools.weatherOptions[Tools.selectedWeather]
    if ImGui.BeginCombo(AMM.LocalizableString("BeginCombo_WeatherControl"), selectedWeatherOption.name) then
      for i, weather in ipairs(Tools.weatherOptions) do
        if ImGui.Selectable(weather.name.."##"..i, (weather == selectedWeatherOption.name)) then
          Tools.selectedWeather = i
          
          if weather.cname == "reset" then
            Tools.weatherSystem:ResetWeather(true)
          else
            Tools.weatherSystem:SetWeather(weather.cname, 10.0, 5)
          end
        end
      end
      ImGui.EndCombo()
    end

    ImGui.SameLine()

    if Tools.selectedWeather ~= 1 then
      if ImGui.SmallButton(AMM.LocalizableString("Button_Reset")) then
        Tools.selectedWeather = 1
        Tools.weatherSystem:ResetWeather(true)
      end
    end
  else
    AMM.UI:TextError(AMM.LocalizableString("Warn_WeatherControl_RequireCodeware"))
  end

  AMM.UI:Spacing(3)

  local gameTime = Tools:GetCurrentHour()
  Tools.timeValue = Tools:ConvertTime(gameTime)

  ImGui.PushItemWidth(ImGui.GetWindowContentRegionWidth() - (ImGui.CalcTextSize(AMM.LocalizableString("TimeofDay")) + 90))

  Tools.timeValue, used = ImGui.SliderInt("##", Tools.timeValue, 0, 1440, "")

  ImGui.PopItemWidth()

  if ImGui.IsItemDeactivatedAfterEdit() then
    if Tools.selectedWeather ~= 1 then
      Tools.weatherSystem:SetWeather(Tools.weatherOptions[Tools.selectedWeather], 10.0, 5)
    end
  end

  ImGui.SameLine()

  if AMM.UI:GlyphButton(IconGlyphs.MinusCircle or "-", true) then
    if Tools.timeValue < 0 then
      Tools.timeValue = 1440
    end

    Tools.timeValue = Tools.timeValue - 1
    used = true
  end

  ImGui.SameLine()

  if AMM.UI:GlyphButton(IconGlyphs.PlusCircle or "+", true) then
    if Tools.timeValue > 1440 then
      Tools.timeValue = 0
    end

    Tools.timeValue = Tools.timeValue + 2
    used = true
  end

  ImGui.SameLine()

  ImGui.Text(AMM.LocalizableString("TimeofDay"))

  if used then
    -- if Tools.relicEffect then
    --   Tools:SetRelicEffect(false)
    --   Cron.After(60.0, function()
    --     Tools:SetRelicEffect(true)
    --   end)
    -- end

    Tools:SetTime(Tools.timeValue)
  end

  ImGui.PushItemWidth(ImGui.GetWindowContentRegionWidth() - (ImGui.CalcTextSize(AMM.LocalizableString("Slider_SlowMotion")) + 10))

  ImGui.SameLine(250)
  ImGui.Text(f("%02d:%02d", gameTime.hour, gameTime.minute))

  if not AMM.playerInPhoto or AMM.userSettings.freezeInPhoto then
    Tools.slowMotionSpeed, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_SlowMotion"), Tools.slowMotionSpeed, 0.000001, Tools.slowMotionMaxValue)
    if used then
      Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
    end

    if AMM.playerInPhoto then
      if ImGui.IsItemHovered() then
        ImGui.SetTooltip(AMM.LocalizableString("Warn_SlowMotion_PhotoMode_Info"))
      end
    end
  end

  ImGui.PopItemWidth()

  if not AMM.playerInPhoto then

    local buttonLabel = AMM.LocalizableString("Button_Label_PauseTimeProgression")
    if Tools.pauseTime then
      buttonLabel = AMM.LocalizableString("Button_Label_UnpauseTimeProgression")
    end

    ImGui.Spacing()
    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools.pauseTime = not Tools.pauseTime
      Game.GetTimeSystem():SetPausedState(Tools.pauseTime, "consoleCommand")

      -- Tools:SetRelicEffect(false)

      -- local currentTime = Tools.timeValue
      -- Cron.Every(5, function(timer)
      --   Tools:SetTime(currentTime)
      --   if not Tools.pauseTime then
      --     Cron.After(60.0, function()
      --       Tools:SetRelicEffect(true)
      --     end)
      --     Cron.Halt(timer)
      --   end
      -- end)
    end

    local buttonLabel = AMM.LocalizableString("Button_Label_UnfreezeTime")
    if Tools.timeState then
      buttonLabel = AMM.LocalizableString("Button_Label_FreezeTime")
    end

    ImGui.Spacing()
    if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:FreezeTime()
    end

    if not Tools.timeState then
      ImGui.Spacing()
      if ImGui.Button(AMM.LocalizableString("Button_SkipFrame"), Tools.style.buttonWidth, Tools.style.buttonHeight) then
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
    Game.GetTimeSystem():SetTimeDilation(CName.new("pause"), 0.0)
		TimeDilationHelper.SetTimeDilationWithProfile(Game.GetPlayer(), "radialMenu", true, true)
		TimeDilationHelper.SetIgnoreTimeDilationOnLocalPlayerZero(Game.GetPlayer(), true)
  else
    if Tools.slowMotionSpeed ~= 1 then
      Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
    else
      Game.GetTimeSystem():UnsetTimeDilation(CName.new("pause"), "None")
      TimeDilationHelper.SetTimeDilationWithProfile(Game.GetPlayer(), "radialMenu", false, true)
		  TimeDilationHelper.SetIgnoreTimeDilationOnLocalPlayerZero(Game.GetPlayer(), false)
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

-- Facial Expressions UI
function Tools:ToggleFavoriteExpression(idle)
  local found = false
  for i, value in ipairs(Tools.favoriteExpressions) do
    if value == idle then
      table.remove(Tools.favoriteExpressions, i)
      found = true
      break
    end
  end
  if not found then
    table.insert(Tools.favoriteExpressions, idle)
  end

  AMM:UpdateSettings()
end

function Tools:DrawFacialExpressionDropdown()

  -- Keep a local or persistent search string for expressions:
  Tools.searchExpression = Tools.searchExpression or ""

  -- If the user has no “extra expression pack” installed:
  if not AMM.extraExpressionsInstalled then
    -- Single combo (OG expressions only)
    if ImGui.BeginCombo(AMM.LocalizableString("Expressions"), Tools.selectedFace.name) then
      for _, face in ipairs(AMM:GetPersonalityOptions()) do
        if ImGui.Selectable(face.name, (face.name == Tools.selectedFace.name)) then
          Tools.activatedFace  = false
          Tools.selectedFace   = face
        end
      end
      ImGui.EndCombo()
    end

    if (Tools.selectedFace.name ~= AMM.LocalizableString("Select_Expression")) 
       and (not Tools.activatedFace) 
       and Tools.selectedFace.name ~= Tools.lastActivatedFace.name 
    then
      Tools:ActivateFacialExpression(Tools.currentTarget, Tools.selectedFace)
    end

  else
    -- ========== Extra expressions installed! ==========    

    -- 1) Search field
    ImGui.PushItemWidth(500)  -- or your variable Tools.searchBarWidth
    Tools.searchExpression = ImGui.InputTextWithHint(
                              " ", 
                              AMM.LocalizableString("Search"), 
                              Tools.searchExpression, 
                              100
                            )
    Tools.searchExpression = Tools.searchExpression:gsub('"', "")  -- strip quotes if needed
    ImGui.PopItemWidth()

    if Tools.searchExpression ~= "" then
      ImGui.SameLine()
      if ImGui.Button(AMM.LocalizableString("Clear")) then
        Tools.searchExpression = ""
      end
    end

    ImGui.Spacing()

    -- 2) Build filteredByCategory
    local lowerSearch = Tools.searchExpression:lower()
    local filteredByCategory = {}  -- e.g. {["OG Expressions"] = { ... }, ["Negative Emotions"] = { ... }}

    for _, face in ipairs(Tools.mergedExpressions) do
      local match = true
      if lowerSearch ~= "" then
        local faceNameLower = face.name:lower()
        if not faceNameLower:find(lowerSearch, 1, true) then
          match = false
        end
      end
      if match then
        filteredByCategory[face.cat_name] = filteredByCategory[face.cat_name] or {}
        table.insert(filteredByCategory[face.cat_name], face)
      end
    end

    -- categories that actually have results
    local categories = {}

    for catName, faces in pairs(filteredByCategory) do
      if #faces > 0 then
        table.insert(categories, catName)
      end
    end
    table.sort(categories)

    -- Add Favorites to the top of the categories list
    if #Tools.favoriteExpressions > 0 then
      table.insert(categories, 1, AMM.LocalizableString("Favorites"))
    end

    -- If user’s selectedCategory is now empty, reset it
    local isFavorites = (Tools.selectedCategory == AMM.LocalizableString("Favorites"))
    if Tools.selectedCategory 
      and (Tools.selectedCategory ~= AMM.LocalizableString("Select_Category"))
      and (
          (isFavorites and (#Tools.favoriteExpressions == 0))
          or (not isFavorites and (not filteredByCategory[Tools.selectedCategory] or #filteredByCategory[Tools.selectedCategory] == 0))
      )
    then
      Tools.selectedCategory = AMM.LocalizableString("Select_Category")
      Tools.selectedFace = { name = AMM.LocalizableString("Select_Expression") }
    end

    -- Change dropdown width
    ImGui.PushItemWidth(210)

    -- 3) If categories is empty, show "No Results" label instead of combos
    if #categories == 0 then
      ImGui.Text(AMM.LocalizableString("No_Results"))
    else
      -- Show category combo
      if ImGui.BeginCombo("##ExpressionsCategoryCombo", Tools.selectedCategory or AMM.LocalizableString("Select_Category")) then
        for _, catName in ipairs(categories) do
          if ImGui.Selectable(catName, (catName == Tools.selectedCategory)) then
            Tools.activatedFace    = false
            Tools.selectedCategory = catName
            Tools.selectedFace     = { name = AMM.LocalizableString("Select_Expression") }
          end
        end
        ImGui.EndCombo()
      end

      ImGui.SameLine()

      -- Show expression combo if a valid category is selected
      if Tools.selectedCategory 
        and Tools.selectedCategory ~= AMM.LocalizableString("Select_Category") 
      then
        if ImGui.BeginCombo("##ExpressionsCombo", Tools.selectedFace.name) then
          local facesInCat = {}
          if Tools.selectedCategory == AMM.LocalizableString("Favorites") then
            for _, face in ipairs(Tools.mergedExpressions) do
              for _, favIdle in ipairs(Tools.favoriteExpressions) do
                if face.idle == favIdle then
                  table.insert(facesInCat, face)
                  break
                end
              end
            end
          else
            facesInCat = filteredByCategory[Tools.selectedCategory] or {}
          end

          for _, face in ipairs(facesInCat) do
            if ImGui.Selectable(face.name, (face.name == Tools.selectedFace.name)) then
              Tools.selectedFace = face
              Tools.activatedFace = false
            end
          end
          ImGui.EndCombo()
        end
      end

      -- Pop the item width
      ImGui.PopItemWidth()
      
      if Tools.selectedFace and Tools.selectedFace.name ~= AMM.LocalizableString("Select_Expression") then
        -- Determine if the expression is favorited
        local isFav = false
        for _, favIdle in ipairs(Tools.favoriteExpressions) do
          if Tools.selectedFace.idle == favIdle then
            isFav = true
            break
          end
        end

        -- Draw the favorite button
        local favLabel = isFav and AMM.LocalizableString("Label_Unfavorite") or AMM.LocalizableString("Label_Favorite")
        ImGui.SameLine()
        if ImGui.SmallButton(favLabel .. "##" .. Tools.selectedFace.idle) then
          Tools:ToggleFavoriteExpression(Tools.selectedFace.idle)
        end
      end

      -- 4) Activation
      if (Tools.selectedFace.name ~= AMM.LocalizableString("Select_Expression")) 
         and (not Tools.activatedFace) 
         and Tools.selectedFace.name ~= Tools.lastActivatedFace.name 
      then
        Tools:ActivateFacialExpression(Tools.currentTarget, Tools.selectedFace)
      end
    end
  end
end


-- Nibbles Replacer
function Tools:DrawNibblesReplacer()
  if not Tools.replacer then
    ImGui.Spacing()
    ImGui.Text("Photomode_NPCs_AMM.lua")
    ImGui.SameLine()
    AMM.UI:TextError(AMM.LocalizableString("Warn_FileNotFound_CollabsFolder_Error"))
  else
    for i, option in ipairs(Tools.nibblesEntityOptions) do
      local selectedEntity = Tools.nibblesEntityOptions[Tools.selectedNibblesEntity]
      if ImGui.RadioButton(option.name, selectedEntity.name == option.name) then
        Tools.selectedNibblesEntity = i
        Tools.cachedReplacerOptions = nil
        Tools:UpdateNibblesEntity(option.ent)
      end

      if option.ent and i ~= 4 and i ~= 8 then
        ImGui.SameLine()
      end
    end

    AMM.UI:Spacing(3)

    if ImGui.Button(AMM.LocalizableString("Button_ResetReplacerDatabase"), Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      db:execute("DELETE FROM appearances WHERE collab_tag = 'Replacer'")
      Tools:SetupReplacerAppearances()
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
      
      if Tools.replacer.version == nil then
        if #allCharacters == 0 then
          for n in db:urows("SELECT entity_name FROM entities WHERE entity_path LIKE '%%Character.%%'") do
            table.insert(allCharacters, n)
          end
        end

        name = Util:FirstToUpper(name)

        name = Tools:RecursivelyScoreDistance(name, 6)
      end

      if name and categories[name] == nil then
        categories[name] = {}
      end

      if name and favorites[app] then
        favorites[app] = nil
        favorites[name] = true
      end

      table.insert(categories[name], app)
    end

    local headers = {}

    for k, v in pairs(favorites) do
      if v then table.insert(headers, {name = k, options = categories[k]}) end
    end

    local headersWithoutFavorites = {}

    for k, v in pairs(categories) do
      if not(favorites[k]) then
        table.insert(headersWithoutFavorites, {name = k, options = v})
      end
    end

    -- Sort headers alphabetically
    table.sort(headersWithoutFavorites, function(a, b) return a.name < b.name end)

    -- Merge headers without favorites and favorites
    for _, category in ipairs(headersWithoutFavorites) do
      table.insert(headers, category)
    end

    Tools.cachedReplacerOptions = headers
  end

  return Tools.cachedReplacerOptions
end

local seen = {}
local duplicates = {}

function Tools:SetupReplacerAppearances()
  log('Setting up Replacer')

  local appearances = Tools.replacer.appearances
  if appearances ~= nil then
    for ent, apps in pairs(appearances) do
      if not seen[ent] then
        seen[ent] = {}
      end

      local valueList = {}
      for _, app in ipairs(apps) do
        if seen[ent][app] then
          table.insert(duplicates, app)
        else
          seen[ent][app] = true
          table.insert(valueList, f("('%s', '%s', '%s')", AMM:GetScanID(ent), app, "Replacer"))
        end
      end
      
      local sql = f("INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES " .. table.concat(valueList, ","))
      local result = db:execute(sql)
    end
  end

  if #duplicates > 0 then
    print("[AMM Info] Found duplicates in Nibbles Replacer file")
    for _, item in ipairs(duplicates) do
      print("Duplicate found: " .. item)
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
    Tools.defaultAperture = ImGui.SliderFloat(AMM.LocalizableString("Slider_DefaultAperture"), Tools.defaultAperture, 1.2, 16, "%.1f")
    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(AMM.LocalizableString("Warn_RequiresRestart_Info"))
    end

    Tools.defaultFOV = ImGui.SliderInt(AMM.LocalizableString("Slider_DefaultFieldofView"), Tools.defaultFOV, 15, 90)
    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(AMM.LocalizableString("Warn_RequiresRestart_Info"))
    end

    AMM.UI:Spacing(4)
  end

  AMM.UI:TextColored(AMM.LocalizableString("Look_At_Camera"))
  for _, option in ipairs(Tools.lookAtOptions) do
    if ImGui.RadioButton(option.name, Tools.selectedLookAt.name == option.name) then
      Tools.selectedLookAt = option
      TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.lookAtParts', Tools.selectedLookAt.parts)
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(AMM.LocalizableString("Warn_LookAtCamera_OptionOff_Info"))
    end

    ImGui.SameLine()
  end

  ImGui.Dummy(20, 20)

  ImGui.SameLine()

  local reset = false
  if ImGui.SmallButton(AMM.LocalizableString("Button_Reset")) then
    TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.lookAtParts', Tools.selectedLookAt.parts)
    Tools:ResetLookAt()
    reset = true
  end

  ImGui.Spacing()

  Tools.lookAtSpeed, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_MovementSpeed"), Tools.lookAtSpeed, 0.0, 140.0, "%.1f")
  if used or reset then
    TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.outTransitionSpeed', Tools.lookAtSpeed)
    TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.transitionSpeed', Tools.lookAtSpeed)
  end

  if Tools.selectedLookAt.name ~= "Eyes Only" then
    Tools.headStiffness, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_HeadStiffness"), Tools.headStiffness, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline0.weight', Tools.headStiffness) end

    Tools.headPoseOverride, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_HeadPoseOverride"), Tools.headPoseOverride, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline0.suppress', Tools.headPoseOverride) end
  end

  if Tools.selectedLookAt.name == "All" then
    Tools.chestStiffness, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_ChestStiffness"), Tools.chestStiffness, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline1.weight', Tools.chestStiffness) end

    Tools.chestPoseOverride, used = ImGui.SliderFloat(AMM.LocalizableString("Slider_ChestPoseOverride"), Tools.chestPoseOverride, 0.0, 1.0, "%.1f")
    if used or reset then TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera_inline1.suppress', Tools.chestPoseOverride) end
  end

  ImGui.Spacing()

  AMM.UI:TextWrappedWithColor(AMM.LocalizableString("Warn_DisableLookAtCamera_PhotoMode_Info"), "ButtonActive")

  AMM.UI:Spacing(3)

  Tools.cursorDisabled, clicked = ImGui.Checkbox(AMM.LocalizableString("DisablePhotoModeCursor"), Tools.cursorDisabled)
  if clicked then
    Tools:ToggleCursor()
  end

  if Tools.cursorDisabled then
    ImGui.SameLine()
    Tools.cursorStateLock = ImGui.Checkbox(AMM.LocalizableString("Cursor_LockState"), Tools.cursorStateLock)
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

function Tools:UpdateAxisIndicatorPosition(pos, yaw)
  -- Make sure we have an axis indicator to move
  if not Tools.axisIndicator or not Tools.axisIndicator.handle then return end

  local axis = Tools.axisIndicator.handle
  local targetPosition
  local targetAngles = EulerAngles.new(0, 0, 0)

  if pos then
    -- Use the provided position
    targetPosition = pos

    if yaw then
      targetAngles = EulerAngles.new(0, 0, yaw)
    end

  elseif Tools.currentTarget and Tools.currentTarget.handle then
    -- If pos not provided, fall back to the existing logic
    targetPosition = Tools.currentTarget.handle:GetWorldPosition()
    if Tools.relativeMode then
      targetAngles = Tools.currentTarget.handle:GetWorldOrientation():ToEulerAngles()
    end
  else
    -- No pos given, no valid handle to get a position from,
    -- so we can't do anything. Just return.
    return
  end

  -- Teleport the axis indicator to the chosen position/angles
  Game.GetTeleportationFacility():Teleport(axis, targetPosition, targetAngles)
end

function Tools:ToggleAxisIndicator(handle)
  if not Tools.axisIndicator and drawWindow then
    if not handle then handle = Tools.currentTarget.handle end
    
    Tools.axisIndicator = {}
    Tools.axisIndicator.template = "base\\amm_props\\entity\\axis_indicator.ent"
    Tools.axisIndicator = AMM.Entity:new(Tools.axisIndicator)

    local targetPosition = handle:GetWorldPosition()
    local targetAngles = nil
    if Tools.relativeMode then
      targetAngles = handle:GetWorldOrientation():ToEulerAngles()
    end

    Tools:SpawnHelper(Tools.axisIndicator, targetPosition, targetAngles)
  elseif Tools.axisIndicator and Tools.axisIndicator.handle then
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

    timer.tick = timer.tick + 1

    if timer.tick > 10 then
      Cron.Halt(timer)
    end

    if AMM.playerInVehicle or Util:GetMountedVehicleTarget() then
      AMM.playerInVehicle = true
      Tools.photoModePuppet = Game.GetPlayer()
    end

    -- if not Tools.photoModePuppet then
      -- Tools.photoModePuppet = Game.GetPlayerSystem():GetPhotoPuppet()
      -- print('player system')
      -- print(Tools.photoModePuppet)
    -- end

    if timer.tick > 2 and not Tools.photoModePuppet then
      Tools.photoModePuppet = Game.GetPlayer()
    end

    if Tools.photoModePuppet then
      AMM.playerInPhoto = true

      Cron.After(Util:CalculateDelay(0.5), function()
        if Tools.listOfPuppets[1] then
          Tools.listOfPuppets[1]:UpdatePosition()
        end
      end)
      
      if Tools.cursorStateLock or AMM.userSettings.disablePhotoModeCursor then
        Tools:ToggleCursor(true)
      end

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
      if v then Tools:ToggleInvisibleBody(v.handle) end
    end)
  end
end

function Tools:ExitPhotoMode()
  AMM.playerInPhoto = false
  Tools.photoModePuppet = nil
  Tools.cursorDisabled = false
  Tools.updatedPosition = {}
  Tools.listOfPuppets = {}
  Tools.puppetsIDs = {}

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
