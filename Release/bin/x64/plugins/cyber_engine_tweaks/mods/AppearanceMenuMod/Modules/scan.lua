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
  drivers = {},
  assignedVehicles = {},
  leftBehind = '',
}

function Scan:Draw(AMM, target, style)
  if ImGui.BeginTabItem("Scan") then

    AMM.UI:DrawCrossHair()

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
            ImGui.SameLine()

            if drawSaveButton == false or target.id == "0x903E76AF, 43" then
              button.width = style.buttonWidth
            end

            if button.action == "Cycle" and target.id ~= "0x903E76AF, 43" then -- Extra Handling for Johnny
              AMM:DrawButton(button.title, button.width, style.buttonHeight, button.action, target)
            end

            if drawSaveButton and button.action == "Save" then
              AMM:DrawButton(button.title, button.width, style.buttonHeight, button.action, target)
            end
          end

          ImGui.Spacing()

          local savedApp = nil
          local query = f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", target.id)
          for app in db:urows(query) do
            savedApp = app
          end

          if savedApp ~= nil then
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
          AMM:UnlockVehicle(target.handle)
        end

        ImGui.SameLine()
        if ImGui.SmallButton("  Repair Vehicle  ") then
          Util:RepairVehicle(target.handle)
        end

        local status, ent = next(AMM.spawnedNPCs)
        if status and ent.handle:IsNPC() then
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
          AMM:DrawFavoritesButton(favoritesLabels, target)
          ImGui.Spacing()
        end
      end

      if AMM.userSettings.experimental then
        if ImGui.SmallButton("  Despawn  ") then
          Util:Despawn(target.handle)
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
    for i, ent in pairs(AMM.spawnedNPCs) do
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
  for _, ent in pairs(AMM.spawnedNPCs) do
    if ent.handle:IsNPC() then
      local seatsNumber = #Scan.vehicleSeats - 1

      if Scan.selectedSeats[ent.name] then
        if Game.FindEntityByID(Scan.selectedSeats[ent.name].vehicle.handle:GetEntityID()) then
          if Scan.selectedSeats[ent.name].seat.name == "Front Left" then
            Scan.drivers[ent.name] = Scan.selectedSeats[ent.name]
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
end

return Scan
