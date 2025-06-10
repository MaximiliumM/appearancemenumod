local Scan = {

  -- Main properties
  searchQuery = '',
  searchBarWidth = 500,
  minimalUI = false,

  -- Target Info
  currentAppIsFavorite = nil,
  currentAppIsBlacklisted = nil,
  currentSavedApp = nil,
  currentApp = nil,

  -- Companion Drive properties
  possibleSeats = {},
  TPPCameraOptions = {},
  vehicleSeats = '',
  selectedSeats = {},
  vehicle = '',
  drivers = {},
  distanceMin = 0,
  assignedVehicles = {},
  leftBehind = {},
  companionDriver = nil,
  isDriving = false,
  carCam = false,
  currentCam = 1,
  keepAssigned = false,

  -- AI Driver
  AIDriver = false,

  -- Saved Despawn properties
  savedDespawns = {},
  savedDespawnsActive = true,

  -- Appearance Trigger properties
  lastAppTriggers = {},
  selectedAppTrigger = nil,
  appTriggerOptions = {},
  shouldSenseOnce = false,
}

-- Keep track of last target
local lastTarget = nil

-- Hack to fix dumb stuff as well
local style = nil

function Scan:Initialize()

  Scan.possibleSeats = {
    { name = AMM.LocalizableString("Seat_FrontLeft"), cname = "seat_front_left", enum = 0},
    { name = AMM.LocalizableString("Seat_FrontRight"), cname = "seat_front_right", enum = 1},
    { name = AMM.LocalizableString("Seat_BackLeft"), cname = "seat_back_left", enum = 2},
    { name = AMM.LocalizableString("Seat_BackRight"), cname = "seat_back_right", enum = 3},
  }
  
  Scan.TPPCameraOptions = {
    { name = AMM.LocalizableString("Close"), vec = Vector4.new(0, -8, 0.5, 0)},
    { name = AMM.LocalizableString("Far"), vec = Vector4.new(0, -12, 0.5, 0)},
  }

  Scan.appTriggerOptions = {
    { name = AMM.LocalizableString("None"), type = 1},
    { name = AMM.LocalizableString("Default"), type = 2},
    { name = AMM.LocalizableString("Combat"), type = 3},
    { name = AMM.LocalizableString("Zone"), type = 4},
    { name = AMM.LocalizableString("Area"), type = 5},
    { name = AMM.LocalizableString("Position"), type = 6},
  }

  Scan.selectedAppTrigger = Scan.appTriggerOptions[1]

  Scan.savedDespawns = Scan:LoadSavedDespawns()
end

function Scan:Draw(AMM, target, s)
  if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameScan")) then
    style = s

    -- Util Popup Helper --
    Util:SetupPopup()

    -- Reset Should Sense
    Scan.shouldSenseOnce = true

    -- Sense Zone and Area triggers once
    if Scan.shouldSenseOnce then
      Scan:ActivateAppTriggerForType('area')
      Scan:ActivateAppTriggerForType('zone')
      Scan.shouldSenseOnce = false
    end

    AMM.UI:DrawCrossHair()

    if Tools.lockTarget then
      if Tools.currentTarget.type ~= 'entEntity' and Tools.currentTarget.type ~= 'gameObject' then
        target = Tools.currentTarget

        if target.handle and target.handle ~= '' then
          target.options = AMM:GetAppearanceOptions(target.handle, target.id)

          if target.type == "Spawn" and target.handle:IsNPC() then
            target.type = "NPCPuppet"
          end
        end
      end
    end

    AMM.settings = false

    if target ~= nil then

      if lastTarget and lastTarget.id ~= target.id then
        lastTarget = target
        Scan.currentSavedApp = nil
      elseif lastTarget == nil then
        lastTarget = target
      end

      ImGui.Spacing()

      ImGui.Text(target.name)

      local buttonLabel = AMM.LocalizableString("Button_LabelLockTarget")
        if Tools.lockTarget then
          buttonLabel = AMM.LocalizableString("Button_LabelUnlockTarget")
        end

        ImGui.SameLine()
        if ImGui.SmallButton(buttonLabel) then
          Tools.lockTarget = not Tools.lockTarget
          Tools:SetCurrentTarget(target)
        end

        if AMM.userSettings.experimental then
          ImGui.SameLine()
          if ImGui.SmallButton(AMM.LocalizableString("Button_SmallDespawn_WithSpace")) then
            target:Despawn()
          end
        end

      -- Check if target is V
      if target.appearance ~= nil and target.appearance ~= "None" then

        local categories = {
          { name = AMM.LocalizableString("List_of_Appearances"), actions = function(target) return Scan:DrawListOfAppearances(target) end },
          { name = AMM.LocalizableString("Target_Info"), actions = function(target, tabConfig) return Scan:DrawTargetInfo(target) end },
        }

        if not AMM.playerInPhoto then
          table.insert(categories, { name = AMM.LocalizableString("Target_Actions"), actions = function(target) return Scan:DrawTargetActions(target) end })
        end
    
        if Scan:TargetIsSpawn(target) then
          table.insert(categories, { name = AMM.LocalizableString("Appearance_Trigger"), actions = function(target) return Scan:DrawAppearanceTrigger(target) end })
        end

        AMM.UI:Spacing(3)
    
        for _, category in ipairs(categories) do
          AMM.UI:PushStyleColor(ImGuiCol.Text, "TextColored")
          local treeNode = ImGui.TreeNodeEx(category.name, ImGuiTreeNodeFlags.DefaultOpen + ImGuiTreeNodeFlags.NoTreePushOnOpen)
          ImGui.PopStyleColor(1)
    
          if treeNode then
            ImGui.Separator()

            category.actions(target)

            AMM.UI:Spacing(3)
          end
          if not treeNode then ImGui.Separator() end
        end
      end
    else
      ImGui.NewLine()

      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, AMM.LocalizableString("Warning_NoTarget_Desc"))
      ImGui.PopTextWrapPos()

      ImGui.NewLine()

      AMM.UI:Separator()

      local mountedVehicle = Util:GetMountedVehicleTarget()
      if mountedVehicle then
        if ImGui.Button(AMM.LocalizableString("Button_TargetMountedVehicle"), style.buttonWidth, style.buttonHeight) then
          Tools:SetCurrentTarget(mountedVehicle)
          Tools.lockTarget = true
        end
      end
    end

    ImGui.EndTabItem()
  end
end

function Scan:DrawTargetInfo(target)
  if target.id ~= nil and target.id ~= "None" then
    AMM.UI:TextColored("ID:")
    ImGui.InputText("", target.id, 50, ImGuiInputTextFlags.ReadOnly)
    ImGui.SameLine()
    if ImGui.SmallButton(AMM.LocalizableString("Button_SmallCopy")) then      
      ImGui.SetClipboardText(target.id)
    end
  end

  ImGui.Spacing()

  AMM.UI:TextColored(AMM.LocalizableString("Current_Appearance"))
  ImGui.Text(target.appearance or "default")

  if target.type == "NPCPuppet" or target.type == "vehicle" then

    ImGui.Spacing()

    AMM:DrawButton(AMM.LocalizableString("Button_CyclesAppearances"), style.halfButtonWidth, style.buttonHeight, "Cycle", target)

    if Scan.currentSavedApp == nil or Scan.currentApp ~= target.appearance then
      local query = f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", target.id)
      for app in db:urows(query) do
        Scan.currentSavedApp = app
      end
    end

    ImGui.SameLine()

    AMM:DrawButton(AMM.LocalizableString("Button_SavesAppearance"), style.halfButtonWidth, style.buttonHeight, "Save", target)

    if Scan.currentAppIsFavorite == nil or Scan.currentApp ~= target.appearance then
      local query = f("SELECT COUNT(1) FROM favorites_apps WHERE entity_id = \"%s\" AND app_name = '%s'", target.id, target.appearance)
      local check = 0
      for count in db:urows(query) do
        check = count
      end

      if check ~= 0 then
        Scan.currentAppIsFavorite = true
      else
        Scan.currentAppIsFavorite = false
      end
    end

    local favorite = {label = AMM.LocalizableString("Favorite_Appearance"), action = 'Favorite'}
    if Scan.currentAppIsFavorite then
      favorite = {label = AMM.LocalizableString("Unfavorite_Appearance"), action = 'Favorite'}
    end

    AMM:DrawButton(favorite.label, style.halfButtonWidth, style.buttonHeight, favorite.action, target)

    if Scan.currentAppIsBlacklisted == nil or Scan.currentApp ~= target.appearance then
      local query = f("SELECT COUNT(1) FROM blacklist_appearances WHERE app_name = '%s'", target.appearance)
      local check = 0
      for count in db:urows(query) do
        check = count
      end

      if check ~= 0 then
        Scan.currentAppIsBlacklisted = true
      else
        Scan.currentAppIsBlacklisted = false
      end
    end

    local blacklist = {label = AMM.LocalizableString("Blacklist_Appearance"), action = 'Blacklist'}
    if Scan.currentAppIsBlacklisted then
      blacklist = {label = AMM.LocalizableString("Unblacklist_Appearance"), action = 'Unblacklist'}
    end

    ImGui.SameLine()

    AMM:DrawButton(blacklist.label, style.halfButtonWidth, style.buttonHeight, blacklist.action, target)

    if Scan.currentSavedApp then
      AMM.UI:Spacing(3)
      AMM.UI:TextColored(AMM.LocalizableString("Saved_Appearance"))
      ImGui.Text(Scan.currentSavedApp)
      AMM:DrawButton(AMM.LocalizableString("Button_ClearSavedAppearance"), style.buttonWidth, style.buttonHeight, "Clear", target)
    end

    Scan.currentApp = target.appearance
  end
end

function Scan:DrawAppearanceTrigger(target)
  local existingTrigger = nil
  for x in db:nrows(f("SELECT * FROM appearance_triggers WHERE appearance = '%s'", target.appearance)) do
    existingTrigger = x
  end

  if existingTrigger then
    if existingTrigger.type == 5 and not AMM.playerCurrentDistrict then
      -- Avoid loading Area type if user reloaded all mods
    else
      Scan.selectedAppTrigger = Scan.appTriggerOptions[existingTrigger.type]
    end
  else
    Scan.selectedAppTrigger = Scan.appTriggerOptions[1]
  end

  for _, option in ipairs(Scan.appTriggerOptions) do

    if option.name == "Area" and AMM.playerCurrentDistrict == nil then
      Util:AMMError(AMM.LocalizableString("WarnText_DontReloadMods"))
    else
      if ImGui.RadioButton(option.name, Scan.selectedAppTrigger.name == option.name) then
        Scan.selectedAppTrigger = option

        if option.type == 1 then
          Scan:RemoveTrigger(target)
        else
          Scan:AddTrigger(target, option.type)
        end
      end
    end

    if option.name ~= "None" then ImGui.SameLine() end
  end

  ImGui.Spacing()

  local currentTrigger = Scan.selectedAppTrigger.name
  if currentTrigger == "Area" or currentTrigger == "Zone" then
    ImGui.Text(AMM.LocalizableString("Current_")..Scan.selectedAppTrigger.name..": ")

    local currentArea = AMM.playerCurrentDistrict
    if currentTrigger == "Zone" then currentArea = AMM.player:GetCurrentSecurityZoneType(AMM.player).value end
    ImGui.SameLine()
    AMM.UI:TextColored(currentArea)

    local shouldDrawSavedArea = existingTrigger ~= nil and (existingTrigger.type == 4 or existingTrigger.type == 5)
    if shouldDrawSavedArea then
      local area = existingTrigger.args        
      if area ~= currentArea then
        ImGui.Text(AMM.LocalizableString("Saved_")..Scan.selectedAppTrigger.name..": ")
        ImGui.SameLine()
        AMM.UI:TextColored(area)
      end
    end
  end
end

function Scan:DrawTargetActions(target)
  if target.name == "Door" then
    if ImGui.Button(AMM.LocalizableString("Button_UnlockDoor"), style.buttonWidth, style.buttonHeight - 5) then
      Util:ToggleDoorLock(target.handle)
    end
  elseif target.name == "ElevatorFloorTerminal" then
    if ImGui.Button(AMM.LocalizableString("Button_RestoreAccess"), style.buttonWidth, style.buttonHeight - 5) then
      Util:RestoreElevator(target.handle)
    end
  elseif target.handle:IsVehicle() then
    if ImGui.Button(AMM.LocalizableString("Button_UnlockVehicle"), style.buttonWidth, style.buttonHeight - 5) then
      Util:UnlockVehicle(target.handle)
    end

    -- ImGui.SameLine()
    -- if ImGui.Button(AMM.LocalizableString("Button_RepairVehicle"), style.halfButtonWidth, style.buttonHeight - 5) then
    --   Util:RepairVehicle(target.handle)
    -- end

    local vehicleSeats = {}

    -- vehicleSeats is created by doubling the seats in possibleSeats
    -- Since the UI has to be organized in the following manner:
    -- [Doors][Windows]
    -- [Doors][Windows]
    -- I had to adjust the offset after index 3 to avoid seats not being inserted
    -- since the index position would already be occupied by another seat
    for i, seat in ipairs(Scan.possibleSeats) do
      if Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName'](target.handle, CName.new(seat.cname)) then
        table.insert(vehicleSeats, seat)
        local offset = 2
        if i >= 3 then offset = 4 end
        vehicleSeats[i + offset] = seat
      end
    end

    if #vehicleSeats > 1 then
      for i, seat in ipairs(vehicleSeats) do
        local doorState = Util:GetDoorState(target.handle, seat.enum)
        local doorGlyph = IconGlyphs.Close
        if doorState then doorGlyph = IconGlyphs.CheckBold end

        local windowState = Util:GetWindowState(target.handle, seat.enum)
        local windowGlyph = IconGlyphs.Close
        if windowState then windowGlyph = IconGlyphs.CheckBold end

        if i == 1 or i == 2 or i == 5 or i == 6 then
          if ImGui.Button(doorGlyph.." "..AMM.LocalizableString("Label_Door").." "..seat.name, style.halfButtonWidth, style.buttonHeight - 5) then
            Util:ToggleDoor(target.handle:GetVehiclePS(), seat.cname, doorState)
          end
        else
          if ImGui.Button(windowGlyph.." "..AMM.LocalizableString("Label_Window").." "..seat.name, style.halfButtonWidth, style.buttonHeight - 5) then
            Util:ToggleWindow(target.handle:GetVehiclePS(), seat.cname, windowState)
          end
        end

        if i % 2 ~= 0 and i ~= #vehicleSeats then
          ImGui.SameLine()
        end
      end
    end

    -- if ImGui.Button(AMM.LocalizableString("Button_OpenCloseDoors"), style.halfButtonWidth, style.buttonHeight - 5) then
    --   Util:ToggleDoors(target.handle)
    -- end

    -- ImGui.SameLine()
    -- if ImGui.Button(AMM.LocalizableString("Button_OpenCloseWindows"), style.halfButtonWidth, style.buttonHeight - 5) then
    --   Util:ToggleWindows(target.handle)
    -- end

    local qm = AMM.player:GetQuickSlotsManager()
    local mountedVehicle = qm:GetVehicleObject()
    local shouldAssignSeats = Scan:ShouldDisplayAssignSeatsButton()
    local width = style.buttonWidth
    local isDelamain = false
    if mountedVehicle then
      local vehicleID = AMM:GetScanID(mountedVehicle)
      isDelamain = vehicleID == "0xC4C260DB, 25" or vehicleID == "0xF74C2EA3, 52"
    end

    if shouldAssignSeats or isDelamain then
      width = style.halfButtonWidth
    end

    if ImGui.Button(AMM.LocalizableString("Button_ToggleEngine"), width, style.buttonHeight - 5) then
      Util:ToggleEngine(target.handle)
    end

    if isDelamain then
      ImGui.SameLine()
      if ImGui.Button(AMM.LocalizableString("Button_ToggleAIDriver"), width, style.buttonHeight - 5) then
        Scan.AIDriver = not Scan.AIDriver
        Util:ToggleEngine(mountedVehicle)

        if Scan.AIDriver then
          AMM.player:SetWarningMessage(AMM.LocalizableString("WarnTextAI_FastTravel"))
          Scan.vehicle = {handle = target.handle, hash = tostring(target.handle:GetEntityID().hash)}
          Scan.companionDriver = {vehicle = {handle = mountedVehicle}}
        else
          Scan.companionDriver = nil
          Scan.vehicle = nil
        end
      end
    end

    if Scan.companionDriver and mountedVehicle then
      ImGui.SameLine()
      if ImGui.Button(AMM.LocalizableString("Button_ToggleCamera"), style.halfButtonWidth, style.buttonHeight - 5) then
        Scan:ToggleVehicleCamera()
      end

      if ImGui.Button(AMM.LocalizableString("Button_ToggleRadio"), style.halfButtonWidth, style.buttonHeight - 5) then
        mountedVehicle:ToggleRadioReceiver(not mountedVehicle:IsRadioReceiverActive())
      end

      ImGui.SameLine()
      if mountedVehicle:IsRadioReceiverActive() then
        if ImGui.Button(AMM.LocalizableString("Button_NextRadioStation"), style.halfButtonWidth, style.buttonHeight - 5) then
          mountedVehicle:NextRadioReceiverStation()
        end
      end
    end

    if shouldAssignSeats and not mountedVehicle then
      ImGui.SameLine()
      if ImGui.Button(AMM.LocalizableString("Button_AssignSeats"), style.halfButtonWidth, style.buttonHeight - 5) then
        if Scan.vehicle == '' or Scan.vehicle.hash ~= target.handle:GetEntityID().hash then
          Scan:GetVehicleSeats(target.handle)
          Scan.vehicle = {handle = target.handle, hash = tostring(target.handle:GetEntityID().hash)}
        end

        ImGui.OpenPopup("Seats")
      end
    else
      Scan.vehicleSeats = ''
    end
  end

  Scan:DrawSeatsPopup()

  if target.handle:IsNPC() then
    local spawnID = AMM:IsSpawnable(target)
    if spawnID ~= nil then
      local favoritesLabels = {AMM.LocalizableString("Label_AddToSpawnFavs"), AMM.LocalizableString("Label_RemoveFromSpawnFavs")}
      local newTarget = Util:ShallowCopy({}, target)
      newTarget.id = spawnID
      AMM.Spawn:DrawFavoritesButton(favoritesLabels, newTarget, true)
    end

    local buttonStyle = style.buttonWidth
    if AMM.userSettings.experimental then buttonStyle = style.halfButtonWidth end
    local buttonLabel = AMM.LocalizableString("Button_Label_Follower")
    if target.handle.isPlayerCompanionCached then buttonLabel = AMM.LocalizableString("Button_Label_Unfollower") end
    if ImGui.Button(buttonLabel, buttonStyle, style.buttonHeight - 5) then
      Util:ToggleCompanion(target)
    end

    if AMM.userSettings.experimental then
      ImGui.SameLine()

      if ImGui.Button(AMM.LocalizableString("Button_FakeDie"), style.halfButtonWidth, style.buttonHeight - 5) then
        target.handle:SendAIDeathSignal()
      end
    end
  end

  if AMM.userSettings.experimental and not mountedVehicle then
    local buttonWidth = style.buttonWidth
    local shouldAllowSaveDespawn = not(target.handle:IsNPC() or target.handle:IsVehicle())

    if shouldAllowSaveDespawn then buttonWidth = style.halfButtonWidth end

    if shouldAllowSaveDespawn then
      local hash = tostring(target.handle:GetEntityID().hash)
      local buttonLabel = AMM.LocalizableString("Button_Label_SaveDespawn")
      if Scan.savedDespawns[hash] then buttonLabel = AMM.LocalizableString("Button_Label_ClearSavedDespawn") end
      if ImGui.Button(buttonLabel, style.buttonWidth, style.buttonHeight - 5) then
        if buttonLabel == AMM.LocalizableString("Button_Label_SaveDespawn") then
          Scan:SaveDespawn(target)
        else
          Scan:ClearSavedDespawn(hash)
        end
      end
    end

    if next(Scan.savedDespawns) ~= nil then
      Scan.savedDespawnsActive = ImGui.Checkbox(AMM.LocalizableString("Checkbox_SavedDespawnsActive"), Scan.savedDespawnsActive)

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip(AMM.LocalizableString("ToolTip_DisableCheckboxReloadSave_AbleTotargetClearSavedDespawns"))
      end
    end
  end
end

function Scan:DrawListOfAppearances(target)
  ImGui.PushItemWidth(Spawn.searchBarWidth)
  Scan.searchQuery = ImGui.InputTextWithHint(" ", AMM.LocalizableString("Search"), Scan.searchQuery, 100)
  Scan.searchQuery = Scan.searchQuery:gsub('"', '')
  ImGui.PopItemWidth()

  local usedClear = false
  if Scan.searchQuery ~= '' then
    AMM.Tools.cachedReplacerOptions = nil
    ImGui.SameLine()
    if ImGui.Button(AMM.LocalizableString("Clear")) then
      usedClear = true
      AMM.cachedAppearanceOptions[target.id] = nil
      Scan.searchQuery = ''
    end
  end

  ImGui.Spacing()

  if target.options ~= nil then
    if AMM.CETVersion < 34 then
      local selectedEntity = AMM.Tools.nibblesEntityOptions[AMM.Tools.selectedNibblesEntity]
      if AMM.nibblesReplacer and selectedEntity and selectedEntity.ent and target.id == AMM:GetScanID(selectedEntity.ent) then
        local categories = AMM.Tools:PrepareCategoryHeadersForNibblesReplacer(target.options)
        for i, category in ipairs(categories) do
          local categoryHeader = ImGui.CollapsingHeader(category.name.."##"..i)
    
          if categoryHeader then
            Scan:DrawAppearanceOptions(target, category.options, i)
          end
        end
      else
        Scan:DrawAppearanceOptions(target, target.options)
      end
    else
      Scan:DrawAppearanceOptions(target, target.options)
    end
  else
    ImGui.TextColored(1, 0.16, 0.13, 0.75, AMM.LocalizableString("No_Appearances"))
  end

  if usedClear then AMM.Tools.cachedReplacerOptions = nil end
end

function Scan:DrawAppearanceOptions(target, options, categoryIndex)
  AMM.UI:List(''..'##'..(categoryIndex or 1), #options, AMM.UI.style.buttonHeight, function(i)
    local appearance = options[i]
    if (ImGui.Button(appearance)) then
      AMM:ChangeAppearanceTo(target, appearance)
    end
  end)
end

function Scan:DrawMinimalUI()
  
  AMM.UI:DrawCrossHair()

  ImGui.SetNextWindowSize(250, 180)

  Scan.minimalUI = ImGui.Begin(AMM.LocalizableString("Build_Mode"), ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoCollapse)

  if Scan.minimalUI then
    local target = AMM:GetTarget()
    if target == nil and (AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '') then
      target = AMM.Tools.currentTarget
    end
    
    if target ~= nil then
      ImGui.Text(target.name)
      AMM.UI:TextColored(target.type)
      ImGui.Spacing()
      ImGui.Text(AMM.LocalizableString("Speed"))
      ImGui.SameLine()
      AMM.UI:TextColored(tostring(target.speed * 1000))
    else
      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, AMM.LocalizableString("No_Target"))
      ImGui.PopTextWrapPos()
    end

  end

  ImGui.End()
end

function Scan:DrawSeatsPopup()
  if ImGui.BeginPopup("Seats", ImGuiWindowFlags.AlwaysAutoResize) then
    local entities = {}
    for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
      table.insert(entities, ent)
    end

    -- Insert Player entity
    table.insert(entities, {name = "Player", handle = AMM.player})

    for i, ent in ipairs(entities) do
      if ent.handle:IsNPC() or ent.handle:IsPlayer() then
        ImGui.Text(ent.name)
        ImGui.SameLine()
        ImGui.Dummy(20, 20)

        local comboLabel = nil
        if Scan.selectedSeats[ent.name] == nil or Scan.selectedSeats[ent.name].vehicle.hash ~= Scan.vehicle.hash then
          comboLabel = AMM.LocalizableString("Select_Seat")
        else
          comboLabel = Scan.selectedSeats[ent.name].seat.name
        end

        ImGui.SameLine()
        if ImGui.BeginCombo("##"..tostring(i), comboLabel) then
          for _, seat in ipairs(Scan.vehicleSeats) do
              local isSelected = (Scan.selectedSeats[ent.name] and Scan.selectedSeats[ent.name].seat.name == seat.name)
              if ImGui.Selectable(seat.name, isSelected) then
                  -- Update selected seat
                  Scan.selectedSeats[ent.name] = {name = ent.name, entity = ent.handle, seat = seat, vehicle = Scan.vehicle}
                  -- Update comboLabel to reflect the new selection
                  comboLabel = seat.name
              end
      
              -- Ensure the current selected item stays highlighted
              if isSelected then
                  ImGui.SetItemDefaultFocus()
              end
          end
          ImGui.EndCombo()
        end      

        ImGui.Spacing()
      end
    end

    Scan.keepAssigned = ImGui.Checkbox(AMM.LocalizableString("Checkbox_KeepAssigned"), Scan.keepAssigned)

    AMM.UI:Separator()

    if ImGui.Button(AMM.LocalizableString("Button_Assign"), -1, style.buttonHeight) then
      Scan.assignedVehicles[Scan.vehicle.hash] = 'active'

      local nonCompanions = {}

      for _, assign in pairs(Scan.selectedSeats) do
        if assign.entity and (not assign.entity:IsPlayer() and not assign.entity.isPlayerCompanionCached) then
          nonCompanions[assign.name] = assign
        end
      end

      if next(nonCompanions) ~= nil then
        Scan:AssignSeats(nonCompanions, true)
      end

      if GetVersion() == "v1.15.0" then
        AMM.displayInteractionPrompt = true
        AMM:BusPromptAction()
      end

      ImGui.CloseCurrentPopup()
    end

    if ImGui.Button(AMM.LocalizableString("Button_Reset"), -1, style.buttonHeight) then
      Scan.selectedSeats = {}
    end

    ImGui.EndPopup()
  end
end

function Scan:AssignSeats(entities, instant, unmount)
  local command = 'AIMountCommand'
  if unmount then command = 'AIUnmountCommand' end

  for _, assign in pairs(entities) do
    if not assign.entity:IsPlayer() then
      local cmd = NewObject(command)
      local mountData = MountEventData.new()
      mountData.mountParentEntityId = assign.vehicle.handle:GetEntityID()
      mountData.isInstant = instant
      mountData.setEntityVisibleWhenMountFinish = true
      mountData.removePitchRollRotationOnDismount = false
      mountData.ignoreHLS = false
      mountData.mountEventOptions = NewObject('handle:gameMountEventOptions')
      mountData.mountEventOptions.silentUnmount = false
      mountData.mountEventOptions.entityID = assign.vehicle.handle:GetEntityID()
      mountData.mountEventOptions.alive = true
      mountData.mountEventOptions.occupiedByNeutral = true
      mountData.slotName = assign.seat.cname
      cmd.mountData = mountData
      cmd = cmd:Copy()

      assign.entity:GetAIControllerComponent():SendCommand(cmd)
    elseif assign.entity:IsPlayer() then
      -- Scan:MountPlayer(assign.seat.cname, assign.vehicle.handle)
    end
  end
end

function Scan:MountPlayer(seat, vehicleHandle)
  local player = Game.GetPlayer()
  local entID = vehicleHandle:GetEntityID()

  local data = NewObject('handle:gameMountEventData')
  data.isInstant = false
  data.slotName = seat
  data.mountParentEntityId = entID
  data.entryAnimName = "forcedTransition"

  local slotID = NewObject('gamemountingMountingSlotId')
  slotID.id = seat

  local mountingInfo = NewObject('gamemountingMountingInfo')
  mountingInfo.childId = player:GetEntityID()
  mountingInfo.parentId = entID
  mountingInfo.slotId = slotID

  local mountEvent = NewObject('handle:gamemountingMountingRequest')
  mountEvent.lowLevelMountingInfo = mountingInfo
  mountEvent.mountData = data

  Game.GetMountingFacility():Mount(mountEvent)
end

function Scan:GetVehicleSeats(vehicle)
  Scan.vehicleSeats = {}

  -- Hard code fix for Claire's vehicle
  if AMM:GetScanID(vehicle) == '0x04201D05, 47' then
    Scan.vehicleSeats = {
      { name = AMM.LocalizableString("Seat_FrontRight"), cname = "seat_front_right" },
      { name = AMM.LocalizableString("Seat_BackLeft"), cname = "seat_back_left" },
      { name = AMM.LocalizableString("Seat_FrontLeft"), cname = "seat_front_left" },
    }
  else
    for _, seat in ipairs(Scan.possibleSeats) do
      if Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName'](vehicle, CName.new(seat.cname)) then
        table.insert(Scan.vehicleSeats, seat)
      end
    end
  end
end

function Scan:AutoAssignSeats()
  -- Get all vehicle seats for the new vehicle
  Scan:GetVehicleSeats(Scan.vehicle.handle)

  local keepAssignedValid = true
  if Scan.keepAssigned then
    -- Check each assigned seat (except front_left, which we skip)
    for entName, seatAssignment in pairs(Scan.selectedSeats) do
      if seatAssignment.seat.cname ~= "seat_front_left" then
        local found = false
        for _, seat in ipairs(Scan.vehicleSeats) do
          if seat.cname == seatAssignment.seat.cname then
            found = true
            break
          end
        end
        if not found then
          keepAssignedValid = false
          break
        end
      end
    end
  end

  if Scan.keepAssigned and keepAssignedValid then
    -- Update vehicle reference for seats that aren't front_left
    for entName, seatInfo in pairs(Scan.selectedSeats) do
      if seatInfo.seat.cname ~= "seat_front_left" then
        seatInfo.vehicle = Scan.vehicle
      elseif seatInfo.seat.cname == "seat_front_left" then
        Scan.drivers[AMM:GetScanID(seatInfo.entity)] = seatInfo
      end
    end
  else
    -- For non-front_left seats, clear assignments from previous vehicles
    for entName, seatAssignment in pairs(Scan.selectedSeats) do
      if seatAssignment.seat.cname ~= "seat_front_left" then
        if not (seatAssignment.vehicle and seatAssignment.vehicle.hash == Scan.vehicle.hash) then
          Scan.selectedSeats[entName] = nil
        end
      end
    end

    -- Calculate available seats dynamically by filtering out occupied seats in the new vehicle
    local availableSeats = {}
    local occupiedSeatNames = {}
    
    for _, seatAssignment in pairs(Scan.selectedSeats) do
      if seatAssignment.vehicle and seatAssignment.vehicle.hash == Scan.vehicle.hash then
        occupiedSeatNames[seatAssignment.seat.cname] = true
      end
    end

    for _, seat in ipairs(Scan.vehicleSeats) do
      if not occupiedSeatNames[seat.cname] then
        table.insert(availableSeats, seat)
      end
    end

    -- Reassign seats to NPCs that don't have a valid assignment in the new vehicle
    for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
      if ent.handle:IsNPC() then
        local currentAssignment = Scan.selectedSeats[ent.name]
        if currentAssignment then
          -- Check if the stored entity handle is stale by comparing entity hashes
          local newHash = ent.hash
          local storedHash = tostring(currentAssignment.entity:GetEntityID().hash)
          if newHash ~= storedHash then
            -- Update the stored entity handle with the new one
            currentAssignment.entity = ent.handle
          end

          -- For front_left, keep the assignment as is and register as driver
          if currentAssignment.seat.cname == "seat_front_left" then
            Scan.drivers[AMM:GetScanID(ent.handle)] = currentAssignment
          end

          -- Otherwise, if the vehicle reference is not current, clear for reassignment
          if currentAssignment.seat.cname ~= "seat_front_left" and (not currentAssignment.vehicle or currentAssignment.vehicle.hash ~= Scan.vehicle.hash) then
            Scan.selectedSeats[ent.name] = nil
          end
        end

        if not Scan.selectedSeats[ent.name] then
          local currentSeat = availableSeats[1]
          if currentSeat then
            if currentSeat.cname == "seat_front_left" then
              -- Skip front_left for auto assignment
              table.remove(availableSeats, 1)
              currentSeat = availableSeats[1]
            end

            if currentSeat then
              Scan.selectedSeats[ent.name] = {
                name = ent.name,
                entity = ent.handle,
                seat = currentSeat,
                vehicle = Scan.vehicle
              }
              table.remove(availableSeats, 1)
            end
          else
            -- If no seat is available, add the NPC to leftBehind
            table.insert(Scan.leftBehind, {
              ent = ent.handle,
              cmd = Util:HoldPosition(ent.handle, 99999)
            })
          end
        end
      end
    end
  end

  -- Finally, assign all selected seats
  Scan:AssignSeats(Scan.selectedSeats, false)
end


function Scan:UnmountDrivers()
  Scan:AssignSeats(Scan.drivers, false, true)

  for _, driver in pairs(Scan.drivers) do
    local vehComp = driver.vehicle.handle:GetVehicleComponent()
    vehComp.mappinID = nil
    vehComp:CreateMappin()
  end

  Scan.drivers = {}
  Scan.companionDriver = nil
  Scan.distanceMin = 0
end

function Scan:SetDriverVehicleToFollow(driver)
  local vehicleClass = AMM:GetScanClass(driver.vehicle.handle)
  if vehicleClass == "vehicleBikeBaseObject" and AMM.spawnsCounter == 1 then
    Scan.distanceMin = Scan.distanceMin + 3
  else
    Scan.distanceMin = Scan.distanceMin + 8
  end

  local cmd = NewObject("handle:AIVehicleFollowCommand")
  cmd.target = AMM.player
  cmd.distanceMin = Scan.distanceMin
  cmd.stopWhenTargetReached = false
  cmd.needDriver = true
  cmd.useTraffic = false
  cmd.useKinematic = true
  cmd = cmd:Copy()

  local event = NewObject("handle:AINPCCommandEvent")
  event.command = cmd
  driver.vehicle.handle:QueueEvent(event)

  local vehComp = driver.vehicle.handle:GetVehicleComponent()
  vehComp:DestroyMappin()
end

function Scan:SetDriverVehicleToGoTo(driver, destination, needDriver)
  local cmd = NewObject("handle:AIVehicleToNodeCommand")
  cmd.needDriver = needDriver
  cmd.nodeRef = destination
  cmd.stopAtPathEnd = true
  cmd.useTraffic = true
  cmd.speedInTraffic = 100
  cmd.forceGreenLights = true
  cmd = cmd:Copy()
  
  local event = NewObject("handle:AINPCCommandEvent")
  event.command = cmd
  driver.vehicle.handle:QueueEvent(event)

  return cmd
end

function Scan:SetVehicleDestination(worldMap, vehicleMap)
  local mappin = worldMap.selectedMappin:GetMappin()
  local mappinPos = mappin:GetWorldPosition()
  local mappinNodeRef = mappin:GetPointData():GetMarkerRef()

  local cmd = Scan:SetDriverVehicleToGoTo(Scan.companionDriver, mappinNodeRef, not Scan.AIDriver)
  Scan.isDriving = true

  Cron.Every(1, function(timer)
    if Scan.vehicle ~= '' then
      local playerPos = AMM.player:GetWorldPosition()
      local dist = Util:VectorDistance(playerPos, mappinPos)

      if dist < 45 and vehicleMap[tostring(Scan.companionDriver.vehicle.handle:GetEntityID().hash)] ~= nil then
        vehicleMap[tostring(Scan.companionDriver.vehicle.handle:GetEntityID().hash)]:StopExecutingCommand(cmd, true)
        Scan.isDriving = false
        Cron.Halt(timer)
      end
    else
      Scan.isDriving = false
      Cron.Halt(timer)
    end
  end)
end

function Scan:ToggleVehicleCamera()
  if Scan.carCam and Scan.currentCam < #Scan.TPPCameraOptions then
    Scan.currentCam = Scan.currentCam + 1
  elseif not Scan.carCam then
    if AMM.Tools.TPPCamera then
      AMM.Tools:ToggleTPPCamera()
    end

    Scan.carCam = true

    AMM.Tools:ToggleHead()
    Cron.Every(0.1, function(timer)
      if Scan.carCam then
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Scan.TPPCameraOptions[Scan.currentCam].vec)
        Game.GetPlayer():GetFPPCameraComponent().pitchMax = 80
        Game.GetPlayer():GetFPPCameraComponent().pitchMin = -80
        Game.GetPlayer():GetFPPCameraComponent().yawMaxRight = -360
        Game.GetPlayer():GetFPPCameraComponent().yawMaxLeft = 360
      else
        AMM.Tools:ToggleHead()
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0, 0, 1.0))
        Cron.Halt(timer)
      end
    end)
  else
    Scan.currentCam = 1
    Scan.carCam = false
  end
end

function Scan:ShouldDisplayAssignSeatsButton()
  for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
    if ent.handle:IsNPC() then return true end
  end

  return false
end

function Scan:TargetIsSpawn(target)
  if next(AMM.Spawn.spawnedNPCs) ~= nil then
		for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
			if ent.hash == target.hash then
				return true
			end
		end

    return false
	end
end

function Scan:ToggleAppearanceAsFavorite(target)
  local query = f("SELECT COUNT(1) FROM favorites_apps WHERE entity_id = \"%s\" AND app_name = '%s'", target.id, target.appearance)
  local count = 0
  for check in db:urows(query) do
    count = check
  end

  if count ~= 0 then
    db:execute(f("DELETE FROM favorites_apps WHERE entity_id = \"%s\" AND app_name = '%s'", target.id, target.appearance))
  else
    db:execute(f("INSERT INTO favorites_apps (entity_id, app_name) VALUES ('%s', '%s')", target.id, target.appearance))
  end

  AMM:ReloadCustomAppearances()
end

-- Save Despawn methods
function Scan:LoadSavedDespawns()
  local despawns = {}
  
  for r in db:nrows("SELECT * FROM saved_despawns") do
    despawns[r.entity_hash] = {pos = r.position, removed = false}
  end

  return despawns
end

function Scan:ClearSavedDespawn(hash)
  Scan.savedDespawns[hash] = nil
  db:execute(f('DELETE FROM saved_despawns WHERE entity_hash = "%s"', hash))
end

function Scan:SaveDespawn(target)
  local hash = tostring(target.handle:GetEntityID().hash)
  local playerPos = Util:GetPosString(Game.GetPlayer():GetWorldPosition())

  Scan.savedDespawns[hash] = {pos = playerPos, removed = false}
  db:execute(f('INSERT INTO saved_despawns (entity_hash, position) VALUES ("%s", "%s")', hash, playerPos))
end

function Scan:ResetSavedDespawns()
  for hash, ent in pairs(Scan.savedDespawns) do
    ent.removed = false
  end
end

function Scan:SenseSavedDespawns()
  if Scan.savedDespawnsActive then

    if next(Scan.savedDespawns) ~= nil then
      local playerPos = Game.GetPlayer():GetWorldPosition()
      for hash, ent in pairs(Scan.savedDespawns) do        
        if ent.removed == false then
          local dist = Util:VectorDistance(playerPos, Util:GetPosFromString(ent.pos))

          if dist <= 30 then
            Scan:FindEntityByHash(hash)
          end
        end
      end
    end
  end
end

function Scan:FindEntityByHash(hash)
  Util:GetAllInRange(30, true, true, function(entity)
    local entityHash = tostring(entity:GetEntityID().hash)
		if entity and entityHash == hash then
			entity:Dispose()
      Scan.savedDespawns[hash].removed = true
		end
	end)
end

-- App Trigger methods
function Scan:RemoveTrigger(target)
  db:execute(f("DELETE FROM appearance_triggers WHERE appearance = '%s'", target.appearance))
end

function Scan:RemoveTriggerByType(target, triggerType)
  db:execute(f("DELETE FROM appearance_triggers WHERE entity_id = \"%s\" AND type = %i", target.id, triggerType))
end

function Scan:RemoveTriggerByArgs(target, triggerType, args)
  db:execute(f('DELETE FROM appearance_triggers WHERE entity_id = "%s" AND type = %i AND args = "%s"', target.id, triggerType, args))
end

function Scan:RemoveTriggerByPosition(target, playerPos)
  local check = nil
  for pos in db:urows(f('SELECT args FROM appearance_triggers WHERE entity_id = "%s" AND type = 6', target.id)) do
    local dist = Util:VectorDistance(Util:GetPosFromString(pos), playerPos)
    if dist < 20 then
      db:execute(f("DELETE FROM appearance_triggers WHERE entity_id = \"%s\" AND args = '%s'", target.id, pos))
    end
  end
end

function Scan:AddTrigger(target, triggerType)
  local args = nil
  if triggerType == 4 then
    args = AMM.playerCurrentZone or AMM.player:GetCurrentSecurityZoneType(AMM.player).value
    Scan:RemoveTriggerByArgs(target, triggerType, args)
  elseif triggerType == 5 then
    args = AMM.playerCurrentDistrict
    Scan:RemoveTriggerByArgs(target, triggerType, args)
  elseif triggerType == 6 then
    local playerPos = AMM.player:GetWorldPosition()
    Scan:RemoveTriggerByPosition(target, playerPos)
    args = Util:GetPosString(playerPos)
  else
    Scan:RemoveTriggerByType(target, triggerType)
  end

  Scan:RemoveTrigger(target)

  local command = (f('INSERT INTO appearance_triggers (entity_id, appearance, type, args) VALUES ("%s", "%s", %i, "%s")', target.id, target.appearance, triggerType, args))
  command = command:gsub('"nil"', "NULL")
  db:execute(command)
end

function Scan:ActivateAppTriggerForType(triggerType)
  local typeNum = {
    default = 2,
    combat = 3,
    zone = 4,
    area = 5,
    position = 6
  }

  local currentType = typeNum[triggerType]

  if next(AMM.Spawn.spawnedNPCs) ~= nil then
    for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
      if ent and ent.handle and type(ent.handle) == 'userdata' and ent.handle:IsNPC() then
        local triggers = {}
        for x in db:nrows(f('SELECT * FROM appearance_triggers WHERE entity_id = "%s" AND type = %i', ent.id, currentType)) do
          table.insert(triggers, x)
        end

        local lastApp = Scan.lastAppTriggers[ent.id] or nil

        if triggers then
          Scan.lastAppTriggers[ent.id] = ent.appearance

          for _, trigger in ipairs(triggers) do
            if (triggerType == "area" and trigger.args == AMM.playerCurrentDistrict)
            or (triggerType == "zone" and trigger.args == AMM.playerCurrentZone) then
              AMM:ChangeAppearanceTo(ent, trigger.appearance)
            elseif triggerType == "combat" or triggerType == "default" then
              AMM:ChangeAppearanceTo(ent, trigger.appearance)
            end
          end
        elseif lastApp then
          AMM:ChangeAppearanceTo(ent, lastApp)
        end
      end
    end
  end
end

function Scan:SenseAppTriggers()
  if next(AMM.Spawn.spawnedNPCs) ~= nil then
    for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
      if ent.handle:IsNPC() then
        local triggers = {}
        for x in db:nrows(f('SELECT * FROM appearance_triggers WHERE entity_id = "%s" AND type = 6', ent.id)) do
          table.insert(triggers, x)
        end

        if #triggers > 0 then
          for _, trigger in ipairs(triggers) do
            local dist = Util:VectorDistance(Game.GetPlayer():GetWorldPosition(), Util:GetPosFromString(trigger.args))
            if dist <= 60 then
              AMM:ChangeAppearanceTo(ent, trigger.app)
            end
          end
        end
      end
    end
  end
end

return Scan
