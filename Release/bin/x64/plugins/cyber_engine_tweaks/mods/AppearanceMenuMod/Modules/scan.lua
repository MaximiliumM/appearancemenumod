local Scan = {

  -- Main properties
  searchQuery = '',
  searchBarWidth = 500,
  minimalUI = false,

  -- Companion Drive properties
  possibleSeats = {
    { name = "Front Right", cname = "seat_front_right" },
    { name = "Back Right", cname = "seat_back_right" },
    { name = "Back Left", cname = "seat_back_left" },
    { name = "Front Left", cname = "seat_front_left" },
  },
  TPPCameraOptions = {},
  vehicleSeats = '',
  selectedSeats = {},
  vehicle = '',
  drivers = {},
  distanceMin = 0,
  assignedVehicles = {},
  leftBehind = '',
  companionDriver = nil,
  isDriving = false,
  carCam = false,
  currentCam = 1,

  -- Saved Despawn properties
  savedDespawns = {},
  savedDespawnsActive = true,

  -- Appearance Trigger properties
  lastAppTriggers = {},
  selectedAppTrigger = nil,
  appTriggerOptions = {},
  shouldSenseOnce = false,
}

function Scan:Initialize()
  Scan.TPPCameraOptions = {
    { name = "Close", vec = Vector4.new(0, -8, 0.5, 0)},
    { name = "Far", vec = Vector4.new(0, -12, 0.5, 0)},
  }

  Scan.appTriggerOptions = {
    { name = "None", type = 1},
    { name = "Default", type = 2},
    { name = "Combat", type = 3},
    { name = "Zone", type = 4},
    { name = "Area", type = 5},
    { name = "Position", type = 6},
  }

  Scan.selectedAppTrigger = Scan.appTriggerOptions[1]

  Scan.savedDespawns = Scan:LoadSavedDespawns()
end

function Scan:Draw(AMM, target, style)
  if ImGui.BeginTabItem("Scan") then
    
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

    local tabConfig = {
      ['NPCPuppet'] = {
        currentTitle = "Current Appearance:",
        buttons = {
          {
            title = "Cycle Appearance",
            width = style.halfButtonWidth,
            action = "Cycle"
          },
          {
            title = "Save Appearance",
            width = style.halfButtonWidth,
            action = "Save"
          },
          {
            title = "Blacklist Appearance",
            width = style.buttonWidth,
            action = "Blacklist"
          },
        },
      },
      ['vehicle'] = {
        currentTitle = "Current Model:",
        buttons = {
          {
            title = "Cycle Model",
            width = style.halfButtonWidth,
            action = "Cycle"
          },
          {
            title = "Save Appearance",
            width = style.halfButtonWidth,
            action = "Save"
          },
        },
      }
    }

    AMM.settings = false

    if target ~= nil then
      -- Generic Objects Setup for Tab
      if tabConfig[target.type] == nil then
        tabConfig[target.type] = {
          currentTitle = "Current Appearance:",
          buttons = {}
        }
      end

      AMM.UI:Spacing(3)

      ImGui.Text(target.name)

      -- Check if target is V
      if target.appearance ~= nil and target.appearance ~= "None" then

        local buttonLabel = " Lock Target "
        if Tools.lockTarget then
          buttonLabel = " Unlock Target "
        end

        ImGui.SameLine()
        if ImGui.SmallButton(buttonLabel) then
          Tools.lockTarget = not Tools.lockTarget
          Tools:SetCurrentTarget(target)
        end

        AMM.UI:Separator()

        if target.id ~= nil and target.id ~= "None" then
          AMM.UI:TextColored("Target ID:")
          ImGui.InputText("", target.id, 50, ImGuiInputTextFlags.ReadOnly)
          ImGui.SameLine()
          if ImGui.SmallButton("Copy") then
            ImGui.SetClipboardText(target.id)
          end
        end

        ImGui.Spacing()

        AMM.UI:TextColored(tabConfig[target.type].currentTitle)
        ImGui.Text(target.appearance or "default")

        ImGui.Spacing()

        local buttons = tabConfig[target.type].buttons

        if tabConfig[target.type] ~= nil and #buttons > 0 then
          
          -- Check if Save button should be drawn
          local drawSaveButton = AMM:ShouldDrawSaveButton(target)

          for _, button in ipairs(buttons) do
            repeat
            if button.action ~= "Blacklist" and button.action ~= "Cycle" then
              ImGui.SameLine()
            end

            if button.action == "Cycle" and target.id == "0x903E76AF, 43" then -- Extra Handling for Johnny
              do break end
            end

            if not drawSaveButton and button.action == "Save" then
              do break end
            end

            AMM:DrawButton(button.title, button.width, style.buttonHeight, button.action, target)

            until true
          end

          local check = nil
          local query = f("SELECT COUNT(1) FROM blacklist_appearances WHERE app_name = '%s'", target.appearance)
          for count in db:urows(query) do
            check = count
          end

          if check ~= 0 then
            AMM:DrawButton("Remove Appearance From Blacklist", style.buttonWidth, style.buttonHeight, "Unblack", target)
          end

          local savedApp = nil
          local query = f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", target.id)
          for app in db:urows(query) do
            savedApp = app
          end

          if savedApp ~= nil then
            AMM.UI:Spacing(3)
            AMM.UI:TextColored("Saved Appearance:")
            ImGui.Text(savedApp)
            AMM:DrawButton("Clear Saved Appearance", style.buttonWidth, style.buttonHeight, "Clear", target)
          end

          AMM.UI:Spacing(3)

          if Scan:TargetIsSpawn(target) then
            AMM.UI:TextColored("Appearance Trigger:")

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
                Util:AMMError("Don't use Reload All Mods.\nPlease reload your save game or move to a different area.")
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
              ImGui.Text("Current "..Scan.selectedAppTrigger.name..": ")

              local currentArea = AMM.playerCurrentDistrict
              if currentTrigger == "Zone" then currentArea = AMM.player:GetCurrentSecurityZoneType(AMM.player).value end
              ImGui.SameLine()
              AMM.UI:TextColored(currentArea)

              local shouldDrawSavedArea = existingTrigger ~= nil and (existingTrigger.type == 4 or existingTrigger.type == 5)
              if shouldDrawSavedArea then
                local area = existingTrigger.args        
                if area ~= currentArea then
                  ImGui.Text("Saved "..Scan.selectedAppTrigger.name..": ")
                  ImGui.SameLine()
                  AMM.UI:TextColored(area)
                end
              end
            end
          end
        end
      end

      AMM.UI:Separator()

      AMM.UI:TextColored("Possible Actions:")

      ImGui.Spacing()

      if target.name == "Door" then
        if ImGui.Button("  Unlock Door  ", style.buttonWidth, style.buttonHeight - 5) then
          Util:UnlockDoor(target.handle)
        end
      elseif target.name == "ElevatorFloorTerminal" then
        if ImGui.Button("  Restore Access  ", style.buttonWidth, style.buttonHeight - 5) then
          Util:RestoreElevator(target.handle)
        end
      elseif target.handle:IsVehicle() then
        if ImGui.Button("  Unlock Vehicle  ", style.halfButtonWidth, style.buttonHeight - 5) then
          Util:UnlockVehicle(target.handle)
        end

        ImGui.SameLine()
        if ImGui.Button("  Repair Vehicle  ", style.halfButtonWidth, style.buttonHeight - 5) then
          Util:RepairVehicle(target.handle)
        end

        if ImGui.Button("  Open/Close Doors  ", style.halfButtonWidth, style.buttonHeight - 5) then
          Util:ToggleDoors(target.handle)
        end

        ImGui.SameLine()
        if ImGui.Button("  Open/Close Windows  ", style.halfButtonWidth, style.buttonHeight - 5) then
          Util:ToggleWindows(target.handle)
        end

        local qm = AMM.player:GetQuickSlotsManager()
		 	  mountedVehicle = qm:GetVehicleObject()
        local shouldAssignSeats = Scan:ShouldDisplayAssignSeatsButton()
        local width = style.buttonWidth
        if (GetVersion() == "v1.15.0" or shouldAssignSeats) then width = style.halfButtonWidth end
        if ImGui.Button("  Toggle Engine  ", width, style.buttonHeight - 5) then
          Util:ToggleEngine(target.handle)
        end

        if Scan.companionDriver ~= '' and mountedVehicle then
          ImGui.SameLine()
          if ImGui.Button("  Toggle Camera  ", style.halfButtonWidth, style.buttonHeight - 5) then
            Scan:ToggleVehicleCamera()
          end

          if ImGui.Button("  Toggle Radio  ", style.halfButtonWidth, style.buttonHeight - 5) then
            mountedVehicle:ToggleRadioReceiver(not mountedVehicle:IsRadioReceiverActive())
          end

          ImGui.SameLine()
          if mountedVehicle:IsRadioReceiverActive() then
            if ImGui.Button("  Next Radio Station  ", style.halfButtonWidth, style.buttonHeight - 5) then
              mountedVehicle:NextRadioReceiverStation()
            end
          end
        end

        if (GetVersion() == "v1.15.0" or shouldAssignSeats) and not mountedVehicle then
          ImGui.SameLine()
          if ImGui.Button("  Assign Seats  ", style.halfButtonWidth, style.buttonHeight - 5) then
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
          local favoritesLabels = {"  Add to Spawnable Favorites  ", "  Remove from Spawnable Favorites  "}
          local newTarget = Util:ShallowCopy({}, target)
          newTarget.id = spawnID
          AMM.Spawn:DrawFavoritesButton(favoritesLabels, target, true)
        end

        local buttonStyle = style.buttonWidth
        if AMM.userSettings.experimental then buttonStyle = style.halfButtonWidth end
        local buttonLabel = "  Follower  "
        if target.handle.isPlayerCompanionCached then buttonLabel = "  Unfollower  " end
        if ImGui.Button(buttonLabel, buttonStyle, style.buttonHeight - 5) then
          if target.handle.isPlayerCompanionCached then
            Util:ToggleCompanion(target.handle)
          else
            AMM.Spawn:SetNPCAsCompanion(target.handle)
          end
        end

        if AMM.userSettings.experimental then
          ImGui.SameLine()

          if ImGui.Button("  Fake Die  ", style.halfButtonWidth, style.buttonHeight - 5) then
            target.handle:SendAIDeathSignal()
          end
        end
      end

      if AMM.userSettings.experimental and not mountedVehicle then
        local buttonWidth = style.buttonWidth
        local shouldAllowSaveDespawn = not(target.handle:IsNPC() or target.handle:IsVehicle())

        if shouldAllowSaveDespawn then buttonWidth = style.halfButtonWidth end

        if ImGui.Button("  Despawn  ", buttonWidth, style.buttonHeight - 5) then
          target:Despawn()
        end

        if shouldAllowSaveDespawn then
          ImGui.SameLine()
          local hash = tostring(target.handle:GetEntityID().hash)
          local buttonLabel = "  Save Despawn  "
          if Scan.savedDespawns[hash] then buttonLabel = "Clear Saved Despawn" end
          if ImGui.Button(buttonLabel, style.halfButtonWidth, style.buttonHeight - 5) then
            if buttonLabel == "  Save Despawn  " then
              Scan:SaveDespawn(target)
            else
              Scan:ClearSavedDespawn(hash)
            end
          end
        end

        if next(Scan.savedDespawns) ~= nil then
          Scan.savedDespawnsActive = ImGui.Checkbox("Saved Despawns Active", Scan.savedDespawnsActive)

          if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Disable this checkbox and reload your save to be able to target and Clear Saved Despawns")
          end
        end
      end

      AMM.UI:Separator()

      AMM.UI:TextColored("List of Appearances:")
      ImGui.Spacing()

      ImGui.PushItemWidth(Spawn.searchBarWidth)
      Scan.searchQuery = ImGui.InputTextWithHint(" ", "Search", Scan.searchQuery, 100)
      Scan.searchQuery = Scan.searchQuery:gsub('"', '')
      ImGui.PopItemWidth()

      if Scan.searchQuery ~= '' then
        ImGui.SameLine()
        if ImGui.Button("Clear") then
          Scan.searchQuery = ''
        end
      end

      ImGui.Spacing()

      if target.options ~= nil then
        x = 0
        for _, appearance in ipairs(target.options) do
          local len = ImGui.CalcTextSize(appearance)
          if len > x then x = len end
        end

        x = x + 50
        if x < ImGui.GetWindowContentRegionWidth() then
          x = ImGui.GetWindowContentRegionWidth()
        end

        resX, resY = GetDisplayResolution()
        y = #target.options * 60
        if y > resY - (resY / 2) then
          y = resY / 3
        end

        if ImGui.BeginChild("Scrolling", x, y) then
          for i, appearance in ipairs(target.options) do
            if (ImGui.Button(appearance)) then
              AMM:ChangeAppearanceTo(target, appearance)
            end
          end
        end
        ImGui.EndChild()
      else
        ImGui.TextColored(1, 0.16, 0.13, 0.75, "No Appearances")
      end
    else
      ImGui.NewLine()

      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "No Target! Look at NPC, Vehicle or Object to begin")
      ImGui.PopTextWrapPos()

      ImGui.NewLine()

      AMM.UI:Separator()

      local mountedVehicle = Util:GetMountedVehicleTarget()
      if mountedVehicle then
        if ImGui.Button("Target Mounted Vehicle", style.buttonWidth, style.buttonHeight) then
          Tools:SetCurrentTarget(mountedVehicle)
          Tools.lockTarget = true
        end
      end
    end

    ImGui.EndTabItem()
  end
end

function Scan:DrawMinimalUI()
  
  AMM.UI:DrawCrossHair()

  ImGui.SetNextWindowSize(250, 180)

  Scan.minimalUI = ImGui.Begin("Build Mode", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoCollapse)

  if Scan.minimalUI then
    local target = AMM:GetTarget()
    if target == nil and (AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '') then
      target = AMM.Tools.currentTarget
    end
    
    if target ~= nil then
      ImGui.Text(target.name)
      AMM.UI:TextColored(target.type)
      ImGui.Spacing()
      ImGui.Text("Speed:")
      ImGui.SameLine()
      AMM.UI:TextColored(tostring(target.speed * 1000))
    else
      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "No Target")
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
          comboLabel = "Select Seat"
        else
          comboLabel = Scan.selectedSeats[ent.name].seat.name
        end

        ImGui.SameLine()
        if ImGui.BeginCombo("##"..tostring(i), comboLabel) then
          for _, seat in ipairs(Scan.vehicleSeats) do
            if ImGui.Selectable(seat.name, (seat.name == comboLabel)) then
              Scan.selectedSeats[ent.name] = {name = ent.name, entity = ent.handle, seat = seat, vehicle = Scan.vehicle}
            end
          end
          ImGui.EndCombo()
        end

        ImGui.Spacing()
      end
    end

    AMM.UI:Separator()

    if ImGui.Button("Assign", -1, 30) then
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

    if ImGui.Button("Reset", -1, 30) then
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
      local mountData = NewObject('handle:gameMountEventData')
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
      { name = "Front Right", cname = "seat_front_right" },
      { name = "Back Left", cname = "seat_back_left" },
      { name = "Front Left", cname = "seat_front_left" },
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
  Scan:GetVehicleSeats(Scan.vehicle.handle)

  local counter = 1
  for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
    if ent.handle:IsNPC() then
      local seatsNumber = #Scan.vehicleSeats - 1

      if Scan.selectedSeats[ent.name] then
        if Game.FindEntityByID(Scan.selectedSeats[ent.name].vehicle.handle:GetEntityID()) then
          if Scan.selectedSeats[ent.name].seat.name == "Front Left" then
            Scan.drivers[AMM:GetScanID(ent.handle)] = Scan.selectedSeats[ent.name]
          end
        else
          Scan.selectedSeats[ent.name] = nil
        end
      elseif counter <= seatsNumber then
        if Scan.selectedSeats[ent.name] == nil then
          Scan.selectedSeats[ent.name] = {name = ent.name, entity = ent.handle, seat = Scan.vehicleSeats[counter], vehicle = Scan.vehicle}
        end
      elseif counter > seatsNumber then
        if Scan.leftBehind == '' then
          Scan.leftBehind = {}
        end

        table.insert(Scan.leftBehind, { ent = ent.handle, cmd = Util:HoldPosition(ent.handle, 99999) })
      end

      counter = counter + 1
    end
  end

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
  cmd.needDriver = needDriver or true
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

  local cmd = Scan:SetDriverVehicleToGoTo(Scan.companionDriver, mappinNodeRef)
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
  db:execute(f("DELETE FROM appearance_triggers WHERE entity_id = '%s' AND type = %i", target.id, triggerType))
end

function Scan:RemoveTriggerByArgs(target, triggerType, args)
  db:execute(f('DELETE FROM appearance_triggers WHERE entity_id = "%s" AND type = %i AND args = "%s"', target.id, triggerType, args))
end

function Scan:RemoveTriggerByPosition(target, playerPos)
  local check = nil
  for pos in db:urows(f('SELECT args FROM appearance_triggers WHERE entity_id = "%s" AND type = 6', target.id)) do
    local dist = Util:VectorDistance(Util:GetPosFromString(pos), playerPos)
    if dist < 20 then
      db:execute(f("DELETE FROM appearance_triggers WHERE entity_id = '%s' AND args = '%s'", target.id, pos))
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
