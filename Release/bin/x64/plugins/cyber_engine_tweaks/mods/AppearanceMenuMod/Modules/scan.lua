local Scan = {
  possibleSeats = {
    { name = "Front Right", cname = "seat_front_right" },
    { name = "Back Right", cname = "seat_back_right" },
    { name = "Back Left", cname = "seat_back_left" },
    { name = "Front Left", cname = "seat_front_left" },
  },
  vehicleSeats = '',
  selectedSeats = {},
  vehicle = '',
  vehEngine = false,
  drivers = {},
  distanceMin = 0,
  assignedVehicles = {},
  leftBehind = '',
}

function Scan:Draw(AMM, target, style)
  if ImGui.BeginTabItem("Scan") then
    -- Util Popup Helper --
    Util:SetupPopup()

    AMM.UI:DrawCrossHair()

    if Tools.lockTarget then
      target = Tools.currentNPC
      if target.handle and (target.handle:IsNPC() or target.handle:IsVehicle()) and target.options == nil then
        target.options = AMM:GetAppearanceOptions(target.handle)
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

        AMM.UI:Separator()

        AMM.UI:TextColored(tabConfig[target.type].currentTitle)
        ImGui.Text(target.appearance)

        ImGui.Spacing()

        -- Check if Save button should be drawn
        local drawSaveButton = AMM:ShouldDrawSaveButton(target)

        if tabConfig[target.type] ~= nil then
          for _, button in ipairs(tabConfig[target.type].buttons) do
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
        end
      end

      AMM.UI:Separator()

      AMM.UI:TextColored("Possible Actions:")

      ImGui.Spacing()

      if target.name == "Door" then
        if ImGui.SmallButton("  Unlock Door  ") then
          Util:UnlockDoor(target.handle)
        end
      elseif target.handle:IsVehicle() then
        if ImGui.SmallButton("  Unlock Vehicle  ") then
          Util:UnlockVehicle(target.handle)
        end

        ImGui.SameLine()
        if ImGui.SmallButton("  Repair Vehicle  ") then
          Util:RepairVehicle(target.handle)
        end

        if ImGui.SmallButton("  Open/Close Doors  ") then
          Util:ToggleDoors(target.handle)
        end

        ImGui.SameLine()
        if ImGui.SmallButton("  Open/Close Windows  ") then
          Util:ToggleWindows(target.handle)
        end

        if ImGui.SmallButton("  Toggle Engine  ") then
          Scan.vehEngine = not Scan.vehEngine
          Util:ToggleEngine(target.handle, Scan.vehEngine)
        end

        local status, ent = next(AMM.Spawn.spawnedNPCs)
        if status and ent.handle:IsNPC() then
          ImGui.SameLine()
          if ImGui.SmallButton("  Assign Seats  ") then
            if Scan.vehicle == '' or Scan.vehicle.hash ~= target.handle:GetEntityID().hash then
              Scan:GetVehicleSeats(target.handle)
              Scan.vehicle = {handle = target.handle, hash = tostring(target.handle:GetEntityID().hash)}
            end

            ImGui.OpenPopup("Seats")
          end
        else
          Scan.vehicleSeats = ''
        end

        ImGui.SameLine()
      end

      Scan:DrawSeatsPopup()

      if target.handle:IsNPC() then
        local spawnID = AMM:IsSpawnable(target)
        if spawnID ~= nil then
          local favoritesLabels = {"  Add to Spawnable Favorites  ", "  Remove from Spawnable Favorites  "}
          target.id = spawnID
          AMM.Spawn:DrawFavoritesButton(favoritesLabels, target)
          ImGui.Spacing()
        end
      end

      if AMM.userSettings.experimental then
        if ImGui.SmallButton("  Despawn  ") then
          local spawnedNPC = nil
    			for _, spawn in pairs(AMM.Spawn.spawnedNPCs) do
    				if target.id == spawn.id then spawnedNPC = spawn break end
    			end

    			if spawnedNPC then
    				AMM.Spawn:DespawnNPC(spawnedNPC)
    			else
    				Util:Despawn(target.handle)
    			end
        end
      end

      AMM.UI:Separator()

      if target.options ~= nil then
        AMM.UI:TextColored("List of Appearances:")
        ImGui.Spacing()

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
        y = #target.options * 40
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
      end
    else
      ImGui.NewLine()

      ImGui.PushTextWrapPos()
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "No Target! Look at NPC, Vehicle or Object to begin")
      ImGui.PopTextWrapPos()

      ImGui.NewLine()
    end

    ImGui.EndTabItem()
  end
end

function Scan:DrawSeatsPopup()
  if ImGui.BeginPopup("Seats", ImGuiWindowFlags.AlwaysAutoResize) then
    for i, ent in pairs(AMM.Spawn.spawnedNPCs) do
      if ent.handle:IsNPC() then
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
          for i, seat in ipairs(Scan.vehicleSeats) do
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

      for _, seat in pairs(Scan.selectedSeats) do
        if seat.entity and not seat.entity.isPlayerCompanionCached then
          nonCompanions[seat.name] = seat
        end
      end

      if next(nonCompanions) ~= nil then
        Scan:AssignSeats(nonCompanions, true)
      end

      ImGui.CloseCurrentPopup()
    end

    ImGui.EndPopup()
  end
end

function Scan:AssignSeats(entities, instant, unmount)
  local command = 'AIMountCommand'
  if unmount then command = 'AIUnmountCommand' end

  for _, assign in pairs(entities) do
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
    mountData.slotName = CName.new(assign.seat.cname)
    cmd.mountData = mountData
    cmd = cmd:Copy()

    assign.entity:GetAIControllerComponent():SendCommand(cmd)
  end
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
  local playerMountedVehicle = Scan.vehicle.hash

  local counter = 1
  for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
    if ent.handle:IsNPC() then
      local seatsNumber = #Scan.vehicleSeats - 1

      if Scan.selectedSeats[ent.name] then
        if Game.FindEntityByID(Scan.selectedSeats[ent.name].vehicle.handle:GetEntityID()) then
          if Scan.selectedSeats[ent.name].seat.name == "Front Left" then
            Scan.drivers[ent.id] = Scan.selectedSeats[ent.name]
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

return Scan
