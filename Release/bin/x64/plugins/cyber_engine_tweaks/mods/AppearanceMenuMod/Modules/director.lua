local Director = {

  -- Layout Properties
  sizeX = 0,

  -- Main Properties
  activeTab = '',
  scripts = {},
  triggers = '',
  selectedTrigger = {title = "Select Trigger"},
  selectedActor = '',
  selectedNode = '',
  lastSelectedNode = {name = ''},
  lastSelectedTrigger = {title = ''},
  lastSelectedActor = {name = ''},
  newNode = '',  
  activeTriggers = {},
  activeScripts = {},
  activeActors = {},
  selectedScript = {title = "Select Script"},
  searchQuery = '',
  savePressed = true,
  stopPressed = false,
  showNodes = false,
  showTrigger = false,
  movementTypes = {"Walk", "Sprint"},
  teleportCommand = '',
  expressions = AMM:GetPersonalityOptions(),
  voData = AMM:GetPossibleVOs(),

  -- Camera Properites
  cameras = {},
  activeCamera = nil,

  -- Cron Callback Properties
  finishedSpawning = false,
}

function Director:NewTrigger(title, pos)
  local obj = {}

  obj.title = title
  obj.pos = pos or nil
  obj.script = ''
  obj.repeatable = false
  obj.radius = 1
  obj.activated = false
  obj.type = "Trigger"
  obj.mappinData = nil

  return obj
end

function Director:NewScript(title)
  local obj = {}

  obj.title = title
  obj.actors = {}
  obj.loop = false
  obj.repeatable = false
  obj.isRunning = false
  obj.trigger = nil
  obj.spawnLevel = 0
  obj.timer = nil
  obj.done = false

  return obj
end

function Director:NewActor(name)
  local obj = {}

  obj.name = name
  obj.uniqueName = name.."##"..tostring(os.clock())
  obj.id = ''
  obj.nodes = {}
  obj.entityID = ''
  obj.handle = ''
  obj.team = ''
  obj.autoTalk = false
  obj.talking = false
  obj.isMoving = false
  obj.currentNode = 1
  obj.activeCommand = ''
  obj.sequence = ''
  obj.sequenceType = "Sequential"
  obj.timer = nil
  obj.done = false

  return obj
end

function Director:NewNode(name)
  local obj = {}

  obj.name = name or nil
  obj.pos = nil
  obj.yaw = 0
  obj.startApp = nil
  obj.endApp = nil
  obj.holdDuration = 1
  obj.movementType = "Walk"
  obj.goTo = nil
  obj.attackTarget = nil
  obj.lookAt = nil
  obj.playVO = nil
  obj.playedVO = false
  obj.expression = nil
  obj.mappinData = nil
  obj.type = "Node"
  obj.done = false

  return obj
end

function Director:AdjustActiveCameraFOV(value)
  if Director.activeCamera then
    local newFOV = Director.activeCamera.fov + value
    Director.activeCamera:SetFOV(newFOV)
  end
end

function Director:AdjustActiveCameraZoom(value)
  if Director.activeCamera then
    local newZoom = Director.activeCamera.zoom + value
    Director.activeCamera:SetZoom(newZoom)
  end
end

function Director:DespawnActiveCamera()
  if Director.activeCamera then
    Director.activeCamera:Despawn()
  end
end

function Director:ToggleActiveCamera()
  if Director.activeCamera then
    Director.activeCamera:Toggle()
  end
end

function Director:StopAll()
  if Director.selectedScript.isRunning then
    Director:StopScript(Director.selectedScript)
  end
end

function Director:DeactivateTrigger(trigger)
  Director:StopScript(Director.selectedScript)
end

function Director:ActivateTrigger(trigger)
  local title = trigger.script
  local script = Director:GetScriptByTitle(title)
  if not script.isRunning then
    if trigger.repeatable then script.repeatable = true end
    script.trigger = trigger
    Director:PlayScript(script)
  end
end

function Director:SenseNPCTalk()
  for _, script in ipairs(Director.scripts) do
    if script.isRunning and Director.teleportCommand ~= '' and not(Util:CheckIfCommandIsActive(Director.teleportCommand[1].handle, Director.teleportCommand[2])) then
      local playerPos = Game.GetPlayer():GetWorldPosition()
      local actors = Director:GetActors(script)
      for _, actor in ipairs(actors) do
        if not actor.talking and actor.autoTalk then
          local actorPos = actor.handle:GetWorldPosition()
          local dist = Util:VectorDistance(playerPos, actorPos)
          if dist <= 4 then
            Cron.After(0.5, function()
              actor.talking = true
              Util:NPCTalk(actor.handle)
            end)

            Cron.After(2.0, function()
              local stimComp = actor.handle:GetStimReactionComponent()
              if stimComp then
                stimComp:DeactiveLookAt(false)
              end
            end)

            Cron.After(60.0, function()
              actor.talking = false
            end)
          end
        end
      end
    end
  end
end

function Director:SenseTriggers()
  if AMM.userSettings.directorTriggers and Director.triggers ~= '' then
    local playerPos = Game.GetPlayer():GetWorldPosition()
    local dist
    for _, trigger in ipairs(Director.triggers) do
      dist = Util:VectorDistance(playerPos, trigger.pos)

      if dist <= trigger.radius then
        if not trigger.activated then
          trigger.activated = true
          Director:ActivateTrigger(trigger)
        end
      end

      if trigger.activated and dist >= 60 then
        trigger.activated = false
        Director:DeactivateTrigger(trigger)
      end
    end
  end
end

function Director:Draw(AMM)
  Director.scripts = Director:GetScripts()

  if #Director.triggers == 0 then
    Director.triggers = Director:GetTriggers()
  end

  if (ImGui.BeginTabItem("Director")) then

    AMM.UI:TextColored("Director Mode")
    local description = "Create Scripts to add, dress and direct Actors to perform for machinima, screenshots and roleplay."

    if Director.activeTab == "Triggers" then
      description = "Create Triggers to activate pre-made Scripts on contact."
    elseif Director.activeTab == "Cameras" then
      description = "Create Cameras to move around freely, set different field of views and zoom levels."
    end

    ImGui.TextWrapped(description)

    AMM.UI:Spacing(2)

    if Director.sizeX == 0 then
      Director.sizeX = ImGui.GetWindowContentRegionWidth()
    end

    local offSet = Director.sizeX - ImGui.CalcTextSize("Triggers On/Off")
    ImGui.Dummy(offSet - 70, 10)
    ImGui.SameLine()
    AMM.UI:TextColored("Triggers On/Off")
    ImGui.SameLine()
    AMM.userSettings.directorTriggers = ImGui.Checkbox(" ", AMM.userSettings.directorTriggers)

    if AMM.playerInPhoto then
      if ImGui.BeginTabBar("Director Tabs") then
        Director:DrawCamerasTab()

        ImGui.EndTabBar()
      end
    elseif AMM.playerInMenu then
      AMM.UI:TextColored("Player In Menu")
      ImGui.Text("Director only works in game")
    else
      if ImGui.BeginTabBar("Director Tabs") then

        Director:DrawScriptTab()
        Director:DrawTriggerTab()
        Director:DrawCamerasTab()

        local running = false
        for _, script in ipairs(Director.scripts) do
          if script.isRunning then
            running = true
            break
          end
        end

        if running then
          Director:DrawRunningTab()
        end

        ImGui.EndTabBar()
      end
    end

    ImGui.EndTabItem()
  end
end

function Director:DrawRunningTab()
  if ImGui.BeginTabItem("Running") then

    AMM.UI:Spacing(2)

    for _, script in ipairs(Director.scripts) do
      if script.isRunning then
        ImGui.InputText(" ", script.title, 100, ImGuiInputTextFlags.ReadOnly)
        local buttonLabel = "Stop Script##"..script.title
        if Director.stopPressed then
          if script.isRunning then buttonLabel = "Stopping..." end
          ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
          ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
          ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
        end

        local stopPressed = Director.stopPressed
        if ImGui.Button(buttonLabel) then
          Director:StopScript(script)
        end

        if stopPressed then
          ImGui.PopStyleColor(3)
        end

        ImGui.SameLine()
        ImGui.TextDisabled("Script Running...")

        AMM.UI:Spacing(3)
      end
    end

    ImGui.EndTabItem()
  end
end

function Director:DrawCamerasTab()
  if ImGui.BeginTabItem("Cameras") then
    Director.activeTab = "Cameras"

    AMM.UI:Spacing(6)

    if ImGui.Button("New Camera", -1, 40) then
      local camera = AMM.Camera:new()
      camera:Spawn()
      camera:StartListeners()

      table.insert(Director.cameras, camera)
      Director.activeCamera = camera
      
      Cron.Every(0.1, function(timer)
				if AMM.Director.activeCamera.handle then
					AMM.Director.activeCamera:Activate(1)
					Cron.Halt(timer)
				end
			end)
    end

    AMM.UI:Separator()

    if #Director.cameras > 0 then
      for i, camera in ipairs(Director.cameras) do
        if ImGui.CollapsingHeader("Camera "..i.."##"..i) then

          local buttonLabel = "Activate"      
          if Director.activeCamera and Director.activeCamera.hash == camera.hash then
            buttonLabel = "Deactivate"
          end

          local buttonWidth = AMM.UI.style.halfButtonWidth - 10

          if ImGui.Button(buttonLabel.."##"..i, buttonWidth, 30) then
            if buttonLabel == "Activate" then
              Director.activeCamera = camera
              camera:Activate(1)
            else
              Director.activeCamera = nil
              camera:Deactivate(1)
            end
          end

          ImGui.SameLine()

          camera.fov, fovUsed = ImGui.DragInt("FOV##"..i, camera.fov, 1, 1, 175)

          if fovUsed then
            camera:SetFOV(camera.fov)
          end

          if ImGui.Button("Toggle Marker".."##"..i, buttonWidth, 30) then
            if camera.mappinID then
              Game.GetMappinSystem():UnregisterMappin(camera.mappinID)
              camera.mappinID = nil
            else
              camera.mappinID = Util:SetMarkerOverObject(camera.handle, gamedataMappinVariant.CustomPositionVariant, 0)
            end
          end

          ImGui.SameLine()

          camera.zoom, zoomUsed = ImGui.DragFloat("Zoom##"..i, camera.zoom, 0.1, 1, 175, "%.1f")

          if zoomUsed then
            camera:SetZoom(camera.zoom)
          end

          if ImGui.Button("Despawn".."##"..i, buttonWidth, 30) then
            if Director.activeCamera and Director.activeCamera.hash == camera.hash then
              Director.activeCamera = nil
            end

            camera:Despawn()
            table.remove(Director.cameras, i)
          end

          ImGui.SameLine()

          local speed = camera.speed * 100
          speed = ImGui.DragFloat("Speed##"..i, speed, 1, 1, 100, "%.0f")
          camera.speed = speed / 100
        end
      end

      AMM.UI:Separator()

      AMM.UI:TextColored("WARNING:")
      ImGui.SameLine()
      ImGui.Text("Close the menu to be able to move the camera")
    end

    ImGui.EndTabItem()
  end
end

function Director:DrawTriggerTab()
  if ImGui.BeginTabItem("Triggers") then
    Director.activeTab = "Triggers"

    AMM.UI:Spacing(6)

    if ImGui.Button("New Trigger", -1, 40) then
      local newTrigger = Director:NewTrigger("New Trigger")

      table.insert(Director.triggers, newTrigger)
      Director.selectedTrigger = newTrigger
    end

    AMM.UI:Separator()

    if #Director.triggers ~= 0 then
      if ImGui.BeginCombo("Triggers", Director.selectedTrigger.title, ImGuiComboFlags.HeightLarge) then
        for i, trigger in ipairs(Director.triggers) do
          if ImGui.Selectable(trigger.title, (trigger.title == Director.selectedTrigger.title)) then

            local selectionChange = false
            if Director.lastSelectedTrigger.title ~= trigger.title then
              Director.lastSelectedTrigger = trigger
              selectionChange = true
            end

            if Director.showTrigger and selectionChange then
              Director:RemoveNodeMarks({Director.selectedTrigger})
              Director:ShowNodes({trigger})
            end

            Director.selectedTrigger = trigger

            if trigger.script ~= '' then
              Director.selectedScript = Director:GetScriptByTitle(trigger.script)
            elseif Director.selectedScript == '' and #Director.scripts ~= 0 then
              Director.selectedScript = Director.scripts[1]
            end
          end
        end
        ImGui.EndCombo()
      end

      if Director.selectedTrigger.title ~= "Select Trigger" then
        Director.showTrigger, used = ImGui.Checkbox("Show Trigger", Director.showTrigger)

        if used then
          if Director.showTrigger then
            Director:ShowNodes({Director.selectedTrigger})
          else
            Director:RemoveNodeMarks(Director.triggers)
          end
        end

        AMM.UI:Separator()

        Director.selectedTrigger.title = ImGui.InputText("Title", Director.selectedTrigger.title, 30)

        ImGui.Spacing()

        if #Director.scripts ~= 0 then

          if ImGui.BeginCombo("Scripts", Director.selectedScript.title, ImGuiComboFlags.HeightLarge) then
            for i, script in ipairs(Director.scripts) do
              if ImGui.Selectable(script.title, (script.title == Director.selectedScript.title)) then
                Director.selectedScript = script
                _, actor = next(script.actors)
                Director.selectedActor = actor or ''
              end
            end
            ImGui.EndCombo()
          end

          if Director.selectedScript.title ~= "Select Script" then

            Director.selectedTrigger.repeatable = ImGui.Checkbox("Repeat In Loop", Director.selectedTrigger.repeatable)
            Director.selectedTrigger.radius = ImGui.InputInt("Activation Radius", Director.selectedTrigger.radius, 1)

            ImGui.Spacing()

            if ImGui.Button("Save Trigger", -1, 30) then
              if not Director.selectedTrigger.pos then
                local pos = Game.GetPlayer():GetWorldPosition()
                Director.selectedTrigger.pos = pos
                Director.selectedTrigger.mappinData = Director:CreateNodeMark(Director.selectedTrigger.pos, true)
              end

              if not Director.showTrigger then
                Director:RemoveNodeMarks({Director.selectedTrigger})
              end

              Director.selectedTrigger.script = Director.selectedScript.title
              Director:SaveTriggers()
              Director.selectedTrigger.title = "Select Trigger"
            end

            if ImGui.Button("Delete Trigger", -1, 30) then
              for i, trigger in ipairs(Director.triggers) do
                if trigger.title == Director.selectedTrigger.title then
                  if Director.showTrigger then
                    Director:RemoveNodeMarks({trigger})
                  end
                  table.remove(Director.triggers, i)
                  Director:SaveTriggers()
                end
              end
              Director.selectedTrigger.title = "Select Trigger"
            end
          end
        end
      end
    end

    ImGui.EndTabItem()
  end
end

function Director:DrawScriptTab()
  if ImGui.BeginTabItem("Scripts") then
    Director.activeTab = "Scripts"

    AMM.UI:Spacing(6)

    if ImGui.Button("New Script", -1, 40) then
      local newScript = Director:NewScript("New Script")

      table.insert(Director.scripts, newScript)
      Director.selectedScript = newScript
      Director.selectedActor = ''
      Director.selectedNode = ''

      Director:SaveScript(newScript)
    end

    AMM.UI:Separator()

    if #Director.scripts ~= 0 then

      if Director.selectedScript.isRunning then
        ImGui.InputText("Scripts", Director.selectedScript.title, 100, ImGuiInputTextFlags.ReadOnly)
      else
        if ImGui.BeginCombo("Scripts", Director.selectedScript.title, ImGuiComboFlags.HeightLarge) then
          for i, script in ipairs(Director.scripts) do
            if ImGui.Selectable(script.title, (script.title == Director.selectedScript.title)) then
              Director.selectedScript = script
              _, actor = next(script.actors)
              Director.selectedActor = actor or ''
            end
          end
          ImGui.EndCombo()
        end
      end

      if Director.selectedScript.title ~= "Select Script" then

        ImGui.Spacing()

        local buttonLabel = "Play Script"
        if Director.stopPressed then
          if Director.selectedScript.isRunning then buttonLabel = "Stopping..."
          elseif Director.selectedScript.done then buttonLabel = "Restarting..." end
          ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
          ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
          ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
        elseif Director.selectedScript.isRunning then
          buttonLabel = "Stop Script"
        end

        local stopPressed = Director.stopPressed
        if ImGui.Button(buttonLabel) then
          if Director.selectedScript.isRunning then
            Director:StopScript(Director.selectedScript)
          else
            Director:PlayScript(Director.selectedScript)
          end
        end

        if stopPressed then
          ImGui.PopStyleColor(3)
        end

        if Director.selectedScript.isRunning then
          ImGui.SameLine()
          ImGui.TextDisabled("Script Running...")
        else
          ImGui.SameLine()
          if ImGui.Button("Delete Script") then
            popupDelegate = {title = 'WARNING', message = '', buttons = {}}
            popupDelegate.message = "Are you sure you want to delete this script?"
            table.insert(popupDelegate.buttons, {label = "Yes", action = function(script) Director:DeleteScript(script) end})
            table.insert(popupDelegate.buttons, {label = "No", action = ''})
            popupDelegate.actionArg = Director.selectedScript
            ImGui.OpenPopup(popupDelegate.title)
          end

          AMM.UI:Separator()

          AMM.UI:TextCenter("Editing", true)

          Director.selectedScript.title = ImGui.InputText("Title", Director.selectedScript.title, 30)

          ImGui.Spacing()

          if ImGui.BeginListBox("Current Actors") then
            for i, actor in pairs(Director.selectedScript.actors) do

              local selectedName = Director.selectedActor.uniqueName or ''
              local currentName = actor.uniqueName

              if actor.team ~= '' then
                selectedName = selectedName:gsub(actor.name, actor.name.." ("..actor.team..")")
                currentName = currentName:gsub(actor.name, actor.name.." ("..actor.team..")")
              end

              if (selectedName == currentName) then selected = true else selected = false end
              if(ImGui.Selectable(currentName, selected)) then
                Director.selectedActor = actor

                if Director.lastSelectedActor.name ~= actor.name then

                  if #Director.selectedActor.nodes ~= 0 then
                    Director.selectedNode = Director.selectedActor.nodes[1]
                  else
                    Director.selectedNode = ''
                  end

                  if Director.showNodes then
                    Director:RemoveNodeMarks(Director.lastSelectedActor.nodes)
                    Director:ShowNodes(Director.selectedActor.nodes)
                  end
                  Director.lastSelectedActor = actor
                end
              end
            end
            ImGui.EndListBox()
          end

          if ImGui.Button("Add Actor") then
            Director.selectedActor = ''
            ImGui.OpenPopup("Actors")
          end

          ImGui.SameLine()
          if ImGui.Button("Remove Actor") then
            Director:RemoveActorFromScript(Director.selectedScript, Director.selectedActor.uniqueName)
          end

          if Director.selectedActor ~= '' then
            ImGui.SameLine()
            if ImGui.Button("Change Actor") then
              ImGui.OpenPopup("Actors")
            end

            AMM.UI:Spacing(3)

            AMM.UI:TextColored("Marks Sequence:")
            if ImGui.RadioButton("Only One", Director.selectedActor.sequenceType == "OnlyOne") then
              Director.selectedActor.sequenceType = "OnlyOne"
              Director:SaveScript(Director.selectedScript)
            end

            if ImGui.IsItemHovered() then
              ImGui.SetTooltip("Actor will stay on a single Mark")
            end

            ImGui.SameLine()
            if ImGui.RadioButton("Random", Director.selectedActor.sequenceType == "Random") then
              Director.selectedActor.sequenceType = "Random"
              Director:SaveScript(Director.selectedScript)
            end

            if ImGui.IsItemHovered() then
              ImGui.SetTooltip("Actor will randomly move between Marks")
            end

            ImGui.SameLine()
            if ImGui.RadioButton("Sequential", Director.selectedActor.sequenceType == "Sequential") then
              Director.selectedActor.sequenceType = "Sequential"
              Director:SaveScript(Director.selectedScript)
            end

            if ImGui.IsItemHovered() then
              ImGui.SetTooltip("Actor will move between Marks in numerical order")
            end

            AMM.UI:Spacing(3)

            Director.showNodes, used = ImGui.Checkbox("Show Marks", Director.showNodes)

            if ImGui.IsItemHovered() then
              ImGui.SetTooltip("Displays a visible icon at Mark locations")
            end

            if used and Director.selectedActor ~= '' then
              if Director.showNodes then
                Director:ShowNodes(Director.selectedActor.nodes)
              else
                Director:RemoveNodeMarks(Director.selectedActor.nodes)
              end
            end

            ImGui.SameLine()
            Director.selectedActor.autoTalk, used = ImGui.Checkbox("Auto Talk", Director.selectedActor.autoTalk)

            if ImGui.IsItemHovered() then
              ImGui.SetTooltip("This will make NPCs talk once every minute when within range (voiced NPCs only)")
            end

            if ImGui.BeginListBox("Actor Marks") then
              for i, node in pairs(Director.selectedActor.nodes) do
                if (Director.selectedNode.name == node.name) then selected = true else selected = false end
                node.name = node.name:gsub("%d+", tostring(i))
                if(ImGui.Selectable(node.name, selected)) then
                  Director.selectedNode = node

                  local selectionChange = false
                  if Director.lastSelectedNode.name ~= node.name then
                    Director.lastSelectedNode = node
                    selectionChange = true
                  end

                  if Director.showNodes and selectionChange then
                    Director:RemoveNodeMarks(Director.selectedActor.nodes)
                    Director:CreateNodeMark(node.pos, false)
                  end
                end
              end
              ImGui.EndListBox()
            end

            if ImGui.Button("New Mark") then
              Director.selectedNode = ''
              ImGui.OpenPopup("Node View")
            end

            if ImGui.IsItemHovered() then
              ImGui.SetTooltip("Create Mark at current Player position to move and direct Actors")
            end

            ImGui.SameLine()
            if ImGui.Button("Remove Mark") then
              Director:RemoveNodeFromActor(Director.selectedActor, Director.selectedNode)
              if #Director.selectedActor.nodes ~= 0 then
                Director.selectedNode = Director.selectedActor.nodes[1]
              else
                Director.selectedNode = ''
              end
              Director:SaveScript(Director.selectedScript)
            end

            if Director.selectedNode ~= '' then
              ImGui.SameLine()
              if ImGui.Button("Edit Mark") then
                ImGui.OpenPopup("Node View")
              end
            end
          end
        end
      end
    end

    Director:DrawActorsPopup()
    Director:DrawNodesPopup()
    Director:DrawWarningPopup(popupDelegate)

    ImGui.EndTabItem()
  end
end

function Director:ShowNodes(nodes)
  for _, node in ipairs(nodes) do
    if node.pos then
      local isTrigger = true
      if node.type == "Node" then isTrigger = false end
      node.mappinData = Director:CreateNodeMark(node.pos, isTrigger)
    end
  end
end

function Director:RemoveNodeMarks(nodes)
  for _, node in ipairs(nodes) do
    Game.GetMappinSystem():UnregisterMappin(node.mappinData)
  end
end

function Director:RemoveNodeFromActor(actor, node)
  Game.GetMappinSystem():UnregisterMappin(node.mappinData)
  local nodeNumber = tonumber(node.name:match("%d"))
  table.remove(actor.nodes, nodeNumber)
end

function Director:RemoveActorFromScript(script, actorName)
  if Director.showNodes then
    Director:RemoveNodeMarks(Director.selectedActor.nodes)
  end

  script.actors[actorName] = nil

  if next(script.actors) ~= nil then
    local _, actor = next(script.actors)
    Director.selectedActor = actor
  else
    Director.selectedActor = ''
  end
end

function Director:GetActors(script)
  local actors = {}
  for _, actor in pairs(script.actors) do
    table.insert(actors, actor)
  end
  return actors
end

function Director:GetActorsNames(script, nameToRemove, includeV)
  local names = {}

  table.insert(names, "No Target")
  table.insert(names, "Team A")
  table.insert(names, "Team B")

  if includeV then
    table.insert(names, "V")
  end

  for _, actor in pairs(script.actors) do
    if nameToRemove ~= actor.name then
      table.insert(names, actor.name)
    end
  end
  return names
end

function Director:GetActorByName(script, name)
  local actor
  if name == "V" then
    return {handle = Game.GetPlayer()}
  end

  for _, act in pairs(script.actors) do
    if name == act.name then actor = act break end
  end
  return actor
end

function Director:GetScriptByTitle(title)
  for _, script in ipairs(Director.scripts) do
    if script.title == title then
      return script
    end
  end

  return ''
end

function Director:StopScript(script)
  if script and not script.done then
    local pos = Game.GetPlayer():GetWorldPosition()
    local heading = Game.GetPlayer():GetWorldForward()
    local behindPlayer = Vector4.new(pos.x - (heading.x * 2), pos.y - (heading.y * 2), pos.z, pos.w)
    for _, actor in pairs(script.actors) do
      Director:TeleportActorTo(actor, behindPlayer)
      actor.handle:Dispose()
    end

    Game.GetPreventionSpawnSystem():RequestDespawnPreventionLevel(script.spawnLevel * -1)

    Cron.Halt(script.timer)

    script.done = true
    Director.stopPressed = true

    if script.trigger then
      script.trigger.activated = false
    end

    Cron.Every(0.1, { tick = 1 }, function(timer)
      local allGone = true
      for _, actor in pairs(script.actors) do
        Cron.Halt(actor.timer)
        local entity = Game.FindEntityByID(actor.entityID)
        if entity then allGone = false end
      end

      timer.tick = timer.tick + 1

      if timer.tick == 50 then
        Game.GetPlayer():SetWarningMessage("Stopping requires looking away from Actors")
      end

      if allGone then
        script = Util:ShallowCopy(script, Director:LoadScriptData(script.title..".json"))

        Director.stopPressed = false
        Director.allowTalk = false

        Cron.Halt(timer)
      end
    end)
  end
end

function Director:RestartScript(script)
  Director.finishedSpawning = true

  for _, actor in pairs(script.actors) do
    local entity = Game.FindEntityByID(actor.entityID)
    if entity == nil then
      Director.finishedSpawning = false
      Game.GetPreventionSpawnSystem():RequestDespawnPreventionLevel(script.spawnLevel * -1)
      break
    end
  end

  if not Director.finishedSpawning then
    script = Util:ShallowCopy(script, Director:LoadScriptData(script.title..".json"))
  else
    local actors = Director:GetActors(script)
    for _, actor in ipairs(actors) do
      Director:GenerateSequence(actor)
      actor.done = false
    end

    script.loop = false
    script.done = false
  end

  Director:PlayScript(script, Director.finishedSpawning)
end

function Director:PlayScript(script, systemActivated)
  -- New seed to avoid same sequence
  math.randomseed(os.time())

  local systemActivated = systemActivated or false

  Director:SaveScript(script)
  table.insert(Director.activeScripts, script)
  script.spawnLevel = #Director.activeScripts
  script.isRunning = true

  local actors = Director:GetActors(script)

  if not systemActivated then
    Director:SpawnActors(script, actors)
  end

  Cron.Every(0.1, function(timer)
    if Director.finishedSpawning then
      Cron.Halt(timer)
      Director.finishedSpawning = false
      Director:MoveActors(script, actors)
    end
  end)
end

function Director:MoveActors(script, actors)

  for _, actor in ipairs(actors) do
    Cron.Every(0.1, { tick = 1 }, function(timer)
      actor.timer = timer

      if not actor.done then
        local node
        if actor.sequenceType == "OnlyOne" then
          node = actor.sequence[1]
        elseif actor.sequenceType == "Random" then
          node = actor.sequence[actor.currentNode]
        elseif actor.sequenceType == "Sequential" then
          node = actor.nodes[actor.currentNode]
        else
          print("[AMM] ERROR: couldn't retrieve node; sequence type invalid")
        end

        if actor.activeCommand == '' then
          if actor.sequenceType == "OnlyOne" or actor.currentNode == 1 and not script.loop then
            local pos = node.pos
            local yaw = node.yaw
            local cmd = Director:TeleportActorTo(actor, pos, yaw)

            if actor.autoTalk then
              Director.teleportCommand = {actor, cmd}
            end
          end

          local stimComp = actor.handle:GetStimReactionComponent()
          if stimComp then
            stimComp:DeactiveLookAt(false)
          end

          if node.startApp ~= nil then
            AMM:ChangeAppearanceTo(actor, node.startApp)
          end

          Cron.After(0.2, function()
            if node.expression ~= nil then
              Director:SetFacialExpression(actor.handle, node.expression)
            end
          end)

          if actor.activeCommand ~= 'attack' then
            local cmd = Director:GetMoveCommand(script, node)
            Director:SendCommand(actor, cmd)
          end

        elseif Director:NodeIsDone(script, actor, node) then
          if node.endApp ~= nil then
            AMM:ChangeAppearanceTo(actor, node.endApp)
          end

          Cron.After(0.2, function()
            if node.expression ~= nil then
              Director:SetFacialExpression(actor.handle, node.expression)
            end
          end)
        elseif actor.activeCommand == 'done' then
          if timer.tick > (node.holdDuration * 10) then
            if node.attackTarget then
              actor.activeCommand = 'attack'
            else
              actor.activeCommand = ''
            end
            if actor.sequenceType == "OnlyOne" then
              actor.currentNode = #actor.nodes + 1
            else
              actor.currentNode = actor.currentNode + 1
            end
            timer.tick = 1
          else
            timer.tick = timer.tick + 1
          end
        end

        if script.repeatable then
          script.loop = true
        end

        if actor.currentNode > #actor.nodes then
          actor.currentNode = 1

          if not script.repeatable then
            actor.done = true
          elseif actor.sequenceType == "OnlyOne" then
            Director:GenerateSequence(actor)
          end
        end
      else
        Cron.Halt(timer)
      end
    end)
  end

  Cron.Every(0.1, function(timer)
    script.timer = timer

    if Director:CheckIfAllDone(actors) then

      if script.trigger then
        script.trigger.activated = false
      end

      Director:StopScript(script)
    end
  end)
end

function Director:GenerateSequence(actor)
  if actor.sequenceType == "Random" then
    local randomSequence = Director:GenerateRandomSequence(#actor.nodes)
    actor.sequence = {}
    for _, num in ipairs(randomSequence) do
      table.insert(actor.sequence, actor.nodes[num])
    end
  elseif actor.sequenceType == "OnlyOne" then
    actor.sequence = {actor.nodes[math.random(1, #actor.nodes)]}
  elseif actor.sequenceType == "Sequential" then
    actor.sequence = ''
  else
    print("[AMM] ERROR: sequence type invalid")
  end
end

function Director:GenerateRandomSequence(maxNumber)
  local tbl = {}
  for i = 1, maxNumber do
    table.insert(tbl, i)
  end

  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function Director:CheckIfAllDone(actors)
  local allDone = true
  for _, actor in ipairs(actors) do
    if not actor.done then allDone = false end
  end
  return allDone
end

function Director:NodeIsDone(script, actor, node)
  local isDone = false
  if actor.handle ~= '' and actor.activeCommand ~= "done" then
    isDone = not Util:CheckIfCommandIsActive(actor.handle, actor.activeCommand)

    if isDone then
      actor.activeCommand = "done"

      if node.lookAt then
        Cron.After(0.2, function()
          local lookAtActor = Director:GetActorByName(script, node.lookAt)
          local stimComp = actor.handle:GetStimReactionComponent()
          stimComp:ActivateReactionLookAt(lookAtActor.handle, false, true, 1, true)
        end)
      end

      if node.playVO then
        if not node.playedVO then
          node.playedVO = true
          Util:PlayVoiceOver(actor.handle, node.playVO.param)
        end
      end

      if node.attackTarget then
        script.repeatable = true
        Cron.After(0.2, function()
          if node.attackTarget == "Team A" or node.attackTarget == "Team B" then
            local oppositeTeam = node.attackTarget == "Team A" and "Team B" or "Team A"
            local targetActor = Director:GetRandomActorFromTeam(script, oppositeTeam)
            Director:SetHostileTowards(actor.handle, targetActor.handle, node.attackTarget)
          else
            local attackTargetActor = Director:GetActorByName(script, node.attackTarget)
            Director:SetHostileTowards(actor.handle, attackTargetActor.handle)
          end
        end)
      end
    end
  end

  return isDone
end

function Director:SendCommand(actor, cmd)
  if actor.handle ~= '' then
    AIComponent = actor.handle:GetAIControllerComponent()
    if (AIComponent == nil) then
      print('npc::AIComponent not found')
    else
      AIComponent:SendCommand(cmd)
    end

    actor.activeCommand = cmd
  end
end

function Director:GetMoveCommand(script, node)
	local dest = NewObject('WorldPosition')
  if node.goTo then
    local actor = Director:GetActorByName(script, node.goTo)
    local pos = actor.handle:GetWorldPosition()
    local heading = actor.handle:GetWorldForward()
    local targetFront = Vector4.new(pos.x + heading.x, pos.y + heading.y, pos.z + heading.z, pos.w + heading.w)
    dest:SetVector4(dest, targetFront)
  else
    dest:SetVector4(dest, node.pos)
  end

  local positionSpec = NewObject('AIPositionSpec')
  positionSpec:SetWorldPosition(positionSpec, dest)

  local cmd = NewObject('handle:AIMoveToCommand')
  cmd.movementTarget = positionSpec
  cmd.rotateEntityTowardsFacingTarget = false
  cmd.ignoreNavigation = false
  cmd.desiredDistanceFromTarget = 2
  cmd.movementType = node.movementType
  cmd.finishWhenDestinationReached = true
  return cmd
end

function Director:SpawnActors(script, actors)
  local counter = #actors
  local spawned = 0

  Cron.Every(0.5, function(timer)
    if counter == 0 then
      Director.finishedSpawning = true
      Cron.Halt(timer)
    else
      if spawned ~= #actors then
        spawned = spawned + 1
        local actor = actors[spawned]
        local actorPath
        for en in db:nrows(f('SELECT * FROM entities WHERE entity_name = "%s"', actor.name)) do
          actorPath = en.entity_path
          actorID = en.entity_id

          if en.parameters == "Player" then
          	actorPath = actorPath..Util:GetPlayerGender()
          end
        end

        local player = Game.GetPlayer()
        local heading = player:GetWorldForward()
        local spawnTransform = player:GetWorldTransform()
        local spawnPosition = GetSingleton('WorldPosition'):ToVector4(spawnTransform.Position)
        spawnTransform:SetPosition(spawnTransform, Vector4.new(spawnPosition.x - heading.x, spawnPosition.y - heading.y, spawnPosition.z, spawnPosition.w))
        local entityID = Game.GetPreventionSpawnSystem():RequestSpawn(TweakDBID.new(actorPath), script.spawnLevel * -1, spawnTransform)
        script.actors[actor.uniqueName].entityID = entityID
        script.actors[actor.uniqueName].id = actorID
      end

      local actor = actors[counter]
      if actor.handle == '' then
        if actor.entityID ~= '' then
          local entity = Game.FindEntityByID(actor.entityID)
          if entity then
            Util:SetGodMode(entity, true)
            entity:GetAttitudeAgent():SetAttitudeTowards(AMM.player:GetAttitudeAgent(), Enum.new("EAIAttitude", "AIA_Friendly"))
            actor.handle = entity
            Director:GenerateSequence(actor)
            counter = counter - 1
          end
        end
      end
    end
  end)
end

function Director:TeleportActorTo(actor, pos, rotation)
	local cmd = NewObject('handle:AITeleportCommand')
	cmd.position = pos
	cmd.rotation = rotation or 0.0
	cmd.doNavTest = false

  actor.handle:GetAIControllerComponent():SendCommand(cmd)

  return cmd
end

function Director:SetFacialExpression(handle, expression)
  local stimComp = handle:GetStimReactionComponent()
  if stimComp then
    stimComp:ResetFacial(0)

    Cron.After(0.5, function()
      local animComp = handle:GetAnimationControllerComponent()

    	if animComp then
    		local animFeat = NewObject("handle:AnimFeature_FacialReaction")
    		animFeat.category = expression.category
    		animFeat.idle = expression.idle
    		animComp:ApplyFeature(CName.new("FacialReaction"), animFeat)
    	end
    end)
  end
end

function Director:GetRandomActorFromTeam(script, team)
  local actors = Director:GetActors(script)
  local randomSequence = Director:GenerateRandomSequence(#actors)
  local teamActors = {}
  for _, actor in ipairs(actors) do
    if actor.team == team then
      table.insert(teamActors, actor)
    end
  end

  return teamActors[randomSequence[math.random(1, #randomSequence)]]
end

function Director:SetHostileTowards(handle, target, group)
  Util:SetGodMode(handle, false)

  local AIC = handle:GetAIControllerComponent()
  local targetAttAgent = handle:GetAttitudeAgent()
  local reactionComp = handle.reactionComponent

  local aiRole = NewObject('handle:AIRole')
  aiRole:OnRoleSet(handle)

  Game['senseComponent::RequestMainPresetChange;GameObjectString'](handle, "Combat")
  Game['NPCPuppet::ChangeStanceState;GameObjectgamedataNPCStanceState'](handle, "Combat")
  AIC:SetAIRole(aiRole)
  handle.movePolicies:Toggle(true)

  if group == "Team A" then
    targetAttAgent:SetAttitudeGroup(CName.new("judy"))
    Game.GetAttitudeSystem():SetAttitudeRelationFromTweak(TweakDBID.new("Attitudes.Group_Judy"), TweakDBID.new("Attitudes.Group_Panam"), Enum.new("EAIAttitude", "AIA_Hostile"))
  elseif group == "Team B" then
    targetAttAgent:SetAttitudeGroup(CName.new("panam"))
    Game.GetAttitudeSystem():SetAttitudeRelationFromTweak(TweakDBID.new("Attitudes.Group_Panam"), TweakDBID.new("Attitudes.Group_Judy"), Enum.new("EAIAttitude", "AIA_Hostile"))
  end

  reactionComp:SetReactionPreset(GetSingleton("gamedataTweakDBInterface"):GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive")))

  targetAttAgent:SetAttitudeTowardsAgentGroup(targetAttAgent, targetAttAgent, Enum.new("EAIAttitude", "AIA_Friendly"))
  targetAttAgent:SetAttitudeTowards(target:GetAttitudeAgent(), Enum.new("EAIAttitude", "AIA_Hostile"))
  reactionComp:TriggerCombat(target)
end

function Director:CreateNodeMark(pos, isTrigger)
  local variant = 'FastTravelVariant'
  if isTrigger then
    variant = 'DefaultInteractionVariant'
  end

  local mappinData = NewObject('gamemappinsMappinData')
  mappinData.mappinType = TweakDBID.new('Mappins.QuestDynamicMappinDefinition')
  mappinData.variant = Enum.new('gamedataMappinVariant', variant)
  mappinData.visibleThroughWalls = true

  return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
end

function Director:DrawNodesPopup()
  local popup = ImGui.BeginPopup("Node View", ImGuiWindowFlags.AlwaysAutoResize)
  if popup then

    if Director.selectedNode ~= '' and Director.newNode == '' then
      Director.newNode = Director:NewNode()
      Director.newNode = Util:ShallowCopy(Director.newNode, Director.selectedNode)
    elseif Director.newNode == '' then
      Director.newNode = Director:NewNode()
      Director.newNode.name = "Mark "..tostring(#Director.selectedActor.nodes + 1)
      Director.newNode.pos = Game.GetPlayer():GetWorldPosition()
      Director.newNode.yaw = Game.GetPlayer():GetWorldYaw()
    end

    local actorID
    for enID in db:urows(f('SELECT entity_id FROM entities WHERE entity_name = "%s"', Director.selectedActor.name)) do
      actorID = enID
    end

    local appearances = AMM:GetAppearanceOptionsWithID(actorID)
    if appearances then
      local startApp = 'Select Appearance'
      if Director.newNode.startApp ~= nil then
        startApp = Director.newNode.startApp
      end

      if ImGui.BeginCombo("Start Appearance", startApp, ImGuiComboFlags.HeightLarge) then
        for i, app in ipairs(appearances) do
          if ImGui.Selectable(app, (app == Director.newNode.startApp)) then
            Director.newNode.startApp = app
          end
        end
        ImGui.EndCombo()
      end

      ImGui.Spacing()

      local endApp = 'Select Appearance'
      if Director.newNode.endApp ~= nil then
        endApp = Director.newNode.endApp
      end

      if ImGui.BeginCombo("End Appearance", endApp, ImGuiComboFlags.HeightLarge) then
        for i, app in ipairs(appearances) do
          if ImGui.Selectable(app, (app == Director.newNode.endApp)) then
            Director.newNode.endApp = app
          end
        end
        ImGui.EndCombo()
      end

      AMM.UI:Spacing(3)
    end

    Director.newNode.holdDuration = ImGui.InputInt("Hold Duration", Director.newNode.holdDuration, 1)

    AMM.UI:Spacing(3)
    AMM.UI:TextColored("Movement:")
    if ImGui.BeginCombo("Type", Director.newNode.movementType) then
      for i, moveType in ipairs(Director.movementTypes) do
        if ImGui.Selectable(moveType, (moveType == Director.newNode.movementType)) then
          Director.newNode.movementType = moveType
        end
      end
      ImGui.EndCombo()
    end

    ImGui.Spacing()

    local actors = Director:GetActorsNames(Director.selectedScript, Director.selectedActor.name, true)

    if ImGui.BeginCombo("Go To Target", Director.newNode.goTo or "No Target") then
      for i, actor in ipairs(actors) do
        if i == 2 or i == 3 then else
          if ImGui.Selectable(actor, (actor == (Director.newNode.goTo or "No Target"))) then
            if actor == "No Target" then
              Director.newNode.goTo = false
            else
              Director.newNode.goTo = actor
            end
          end
        end
      end
      ImGui.EndCombo()
    end

    AMM.UI:Spacing(3)
    AMM.UI:TextColored("Actions:")

    if ImGui.BeginCombo("Look At", Director.newNode.lookAt or "No Target") then
      for i, actor in ipairs(actors) do
        if i == 2 or i == 3 then else
          if ImGui.Selectable(actor, (actor == (Director.newNode.lookAt or "No Target"))) then
            if actor == "No Target" then
              Director.newNode.lookAt = false
            else
              Director.newNode.lookAt = actor
            end
          end
        end
      end
      ImGui.EndCombo()
    end

    ImGui.Spacing()

    if ImGui.BeginCombo("Play Voice", Director.newNode.playVO and Director.newNode.playVO.label or "No Target", ImGuiComboFlags.HeightLarge) then
      for _, vo in ipairs(Director.voData) do
        if ImGui.Selectable(vo.label, (vo.label == (Director.newNode.playVO and Director.newNode.playVO.label or "No Target"))) then
          if vo.label == "No Target" then
            Director.newNode.playVO = false
          else
            Director.newNode.playVO = vo
          end
        end
      end
      ImGui.EndCombo()
    end

    ImGui.Spacing()

    if ImGui.BeginCombo("Attack", Director.newNode.attackTarget or "No Target") then
      for i, actor in ipairs(actors) do
        if ImGui.Selectable(actor, (actor == (Director.newNode.attackTarget or "No Target"))) then
          if actor == "No Target" then
            Director.newNode.attackTarget = false
            Director.selectedActor.team = ''
          else
            Director.newNode.attackTarget = actor
            if string.find(actor, "Team") then
              Director.selectedActor.team = actor
            end
          end
        end
      end
      ImGui.EndCombo()
    end

    AMM.UI:Spacing(3)
    AMM.UI:TextColored("Facial Expression:")
    if ImGui.BeginCombo(" ", Director.newNode.expression and Director.newNode.expression.name or "Select Expression") then
      for i, face in ipairs(Director.expressions) do
        if ImGui.Selectable(face.name, (face.name == (Director.newNode.expression and Director.newNode.expression.name))) then
          Director.newNode.expression = face
        end
      end
      ImGui.EndCombo()
    end

    AMM.UI:Separator()

    local buttonLabel = "Add Mark"
    if Director.selectedNode ~= '' then buttonLabel = "Save with New Position" end

    if ImGui.Button(buttonLabel, -1, 30) then
      if Director.selectedNode ~= '' then
        Director:RemoveNodeMarks({Director.newNode})
        Director.newNode.pos = Game.GetPlayer():GetWorldPosition()
        Director.newNode.yaw = Game.GetPlayer():GetWorldYaw()
      end

      Director.newNode.name = Director.newNode.name:gsub("%b()", "")
      if Director.newNode.goTo then
        Director.newNode.name = Director.newNode.name..f(" (Go to %s) ", Director.newNode.goTo)
      end

      if Director.newNode.pos then
        Director.newNode.mappinData = Director:CreateNodeMark(Director.newNode.pos, false)
        if not Director.showNodes then
          Director:RemoveNodeMarks({Director.newNode})
        end
      end

      if Director.selectedNode ~= '' then
        Director:RemoveNodeFromActor(Director.selectedActor, Director.selectedNode)
        Director.selectedNode = Util:ShallowCopy(Director.selectedNode, Director.newNode)
      end

      table.insert(Director.selectedActor.nodes, Director.newNode)
      Director.selectedNode = Director.newNode

      Director:SaveScript(Director.selectedScript)
      ImGui.CloseCurrentPopup()
    end

    if Director.selectedNode ~= '' then
      if ImGui.Button("Save Changes Only", -1, 30) then
        Director.selectedNode = Util:ShallowCopy(Director.selectedNode, Director.newNode)
        Director:SaveScript(Director.selectedScript)
        ImGui.CloseCurrentPopup()
      end
    end

    ImGui.EndPopup()
  else
    Director.newNode = ''
  end
end

function Director:DrawActorsPopup()
  if ImGui.BeginPopup("Actors", ImGuiWindowFlags.AlwaysAutoResize) then
    if Director.selectedActor ~= '' then
      AMM.UI:TextColored("Select Actor To Replace:")
    else
      AMM.UI:TextColored("Add Actor To Current Script:")
    end

    if Director.searchQuery ~= '' then
      local entities = {}
      local query = "SELECT * FROM entities WHERE is_spawnable = 1 AND entity_name LIKE '%"..Director.searchQuery.."%' ORDER BY entity_name ASC"
      for en in db:nrows(query) do
        table.insert(entities, {en.entity_name, en.entity_id, en.entity_path})
      end

      if #entities ~= 0 then
        Director:DrawEntitiesButtons(entities, "ALL")
      else
        ImGui.Text("No Results")
      end
    else
      for _, category in ipairs(AMM.Spawn.categories) do
        local entities = {}
        if category.cat_name == 'Favorites' then
          local query = "SELECT * FROM favorites"
          for fav in db:nrows(query) do
            query = f("SELECT * FROM entities WHERE entity_id = '%s' AND cat_id != 22", fav.entity_id)
            for en in db:nrows(query) do
              table.insert(entities, {en.entity_name, en.entity_id, en.entity_path})
            end
          end
        end

        local query = f("SELECT * FROM entities WHERE is_spawnable = 1 AND cat_id != 22 AND cat_id == '%s' ORDER BY entity_name ASC", category.cat_id)
        for en in db:nrows(query) do
          table.insert(entities, {en.entity_name, en.entity_id, en.entity_path})
        end

        if #entities ~= 0 or category.cat_name == 'Favorites' then
          if(ImGui.CollapsingHeader(category.cat_name)) then
            if #entities == 0 then
              ImGui.Text("It's empty :(")
            else
              Director:DrawEntitiesButtons(entities, category.cat_name)
            end
          end
        end
      end
    end
    ImGui.EndPopup()
  end
end

function Director:DrawEntitiesButtons(entities, categoryName)
  local style = {
    buttonWidth = ImGui.GetWindowContentRegionWidth(),
    buttonHeight = ImGui.GetFontSize() * 2
  }

  for i, entity in ipairs(entities) do
		name = entity[1]
		id = entity[2]
		path = entity[3]

    local favOffset = 0
		if categoryName == 'Favorites' then
			favOffset = 90

			Director:DrawArrowButton("up", id, i)
			ImGui.SameLine()
		end

		if ImGui.Button(name.."##"..tostring(i), style.buttonWidth - favOffset, style.buttonHeight) then
      local newActor = Director:NewActor(name)
      if Director.selectedActor == '' then
        -- Add new actor
        Director.selectedScript.actors[newActor.uniqueName] = newActor
        Director.selectedActor = newActor

        Director:SaveScript(Director.selectedScript)
      else
        -- Copy selected actor data to new actor
        newActor.nodes = Director.selectedActor.nodes
        newActor.sequenceType = Director.selectedActor.sequenceType

        -- Reset selected appearances
        for _, node in ipairs(newActor.nodes) do
          node.startApp = nil
          node.endApp = nil
        end

        Director:RemoveActorFromScript(Director.selectedScript, Director.selectedActor.uniqueName)

        -- Add new actor
        Director.selectedScript.actors[newActor.uniqueName] = newActor
        Director.selectedActor = newActor

        Director:SaveScript(Director.selectedScript)
      end

      ImGui.CloseCurrentPopup()
    end

    if categoryName == 'Favorites' then
			ImGui.SameLine()
			Director:DrawArrowButton("down", id, i)
    end
	end
end

function Director:DrawArrowButton(direction, entityID, index)
	local dirEnum, tempPos
	if direction == "up" then
		dirEnum = ImGuiDir.Up
		tempPos = index - 1
	else
		dirEnum = ImGuiDir.Down
		tempPos = index + 1
	end

	local query = "SELECT COUNT(1) FROM favorites"
	for x in db:urows(query) do favoritesLength = x end

	if ImGui.ArrowButton(direction..entityID, dirEnum) then
		if not(tempPos < 1 or tempPos > favoritesLength) then
			local query = f("SELECT * FROM favorites WHERE position = %i", tempPos)
			for fav in db:nrows(query) do temp = fav end

			db:execute(f("UPDATE favorites SET entity_id = '%s' WHERE position = %i", entityID, tempPos))
			db:execute(f("UPDATE favorites SET entity_id = '%s' WHERE position = %i", temp.entity_id, index))
		end
	end
end

function Director:DrawWarningPopup(popupDelegate)
  local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
  ImGui.SetNextWindowSize(400, 140)
	if ImGui.BeginPopupModal("WARNING", ImGuiWindowFlags.AlwaysAutoResize) then
		ImGui.TextWrapped(popupDelegate.message)
		for _, button in ipairs(popupDelegate.buttons) do
			if ImGui.Button(button.label, ImGui.GetWindowContentRegionWidth() / 2, 30) then
				if button.action ~= '' then button.action(popupDelegate.actionArg) end
				ImGui.CloseCurrentPopup()
			end
      ImGui.SameLine()
		end
		ImGui.EndPopup()
	end
end

function Director:PrepareExportData(script)
  local exportScript = {}
  exportScript.title = script.title
  exportScript.actors = {}

  for _, actor in pairs(script.actors) do
    local exportNodes = {}
    for _, node in ipairs(actor.nodes) do
      local exportNode = {}
      exportNode.name = node.name
      exportNode.pos = {x = node.pos.x, y = node.pos.y, z = node.pos.z, w = node.pos.w}
      exportNode.yaw = node.yaw
      exportNode.holdDuration = node.holdDuration
      exportNode.goTo = node.goTo
      exportNode.attackTarget = node.attackTarget
      exportNode.lookAt = node.lookAt
      exportNode.playVO = node.playVO
      exportNode.expression = node.expression
      exportNode.movementType = node.movementType

      if node.startApp then
        exportNode.startApp = node.startApp
      end

      if node.endApp then
        exportNode.endApp = node.endApp
      end

      table.insert(exportNodes, exportNode)
    end

    table.insert(exportScript.actors, {name = actor.name, uniqueName = actor.uniqueName, team = actor.team, sequenceType = actor.sequenceType, nodes = exportNodes, autoTalk = boolToInt(actor.autoTalk)})
  end

  return exportScript
end

function Director:SaveScript(script)
  local file = io.open(f("User/Scripts/%s.json", script.title), "w")
  if file then
    local exportData = Director:PrepareExportData(script)
    local contents = json.encode(exportData)
		file:write(contents)
		file:close()
  end
end

function Director:LoadScriptData(title)
  local file = io.open('User/Scripts/'..title, 'r')
  if file then
    local contents = file:read( "*a" )
		local scriptData = json.decode(contents)
    file:close()
    local newScript = Director:NewScript(scriptData["title"])

    -- Migrating old script
    local migrate = {}
    for i, actorData in pairs(scriptData["actors"]) do
      if type(i) == 'number' then break end

      actorData.name = i
      table.insert(migrate, actorData)
    end

    if #migrate > 0 then scriptData['actors'] = migrate end

    for i, actorData in ipairs(scriptData["actors"]) do
      local newActor = Director:NewActor(actorData.name)
      newActor.sequenceType = actorData.sequenceType
      newActor.autoTalk = intToBool(actorData.autoTalk or 0)
      newActor.team = actorData.team or ''
      newActor.uniqueName = actorData.uniqueName or (actorData.name.."##"..i..tostring(os.clock()))

      for _, node in ipairs(actorData.nodes) do
        local newNode = Director:NewNode(node.name)
        newNode.pos = Vector4.new(node.pos.x, node.pos.y, node.pos.z, node.pos.w)
        newNode.yaw = node.yaw
        newNode.holdDuration = node.holdDuration
        newNode.startApp = node.startApp or nil
        newNode.endApp = node.endApp or nil
        newNode.goTo = node.goTo or nil
        newNode.attackTarget = node.attackTarget or nil
        newNode.lookAt = node.lookAt or nil
        newNode.playVO = node.playVO or nil
        newNode.expression = node.expression or nil
        newNode.movementType = node.movementType or "Walk"
        table.insert(newActor.nodes, newNode)
      end

      newScript.actors[newActor.uniqueName] = newActor
    end

    return newScript
  end
end

function Director:SaveTriggers()
  local file = io.open("User/triggers.json", "w")
  if file then
    local triggers = {}
    for _, trigger in ipairs(Director.triggers) do
      local tri = {}
      tri.title = trigger.title
      tri.pos = {x = trigger.pos.x, y = trigger.pos.y, z = trigger.pos.z, w = trigger.pos.w}
      tri.script = trigger.script
      tri.repeatable = boolToInt(trigger.repeatable)
      tri.radius = trigger.radius
      table.insert(triggers, tri)
    end

    local contents = json.encode(triggers)
    file:write(contents)
    file:close()
  end

  Director.triggers = Director:GetTriggers()
end

function Director:GetTriggers()
  local file = io.open("User/triggers.json", "r")
  if file then
    local contents = file:read( "*a" )
		local triData = json.decode(contents)
    file:close()

    local triggers = {}
    for _, tri in ipairs(triData) do
      local newTrigger = Director:NewTrigger(tri.title)
      newTrigger.pos = Vector4.new(tri.pos.x, tri.pos.y, tri.pos.z, tri.pos.w)
      newTrigger.script = tri.script
      newTrigger.repeatable = intToBool(tri.repeatable)
      newTrigger.radius = tri.radius or 1
      table.insert(triggers, newTrigger)
    end

    return triggers
  else
    local triggers = {}
    local newTrigger = Director:NewTrigger('Mansion')
    newTrigger.pos = Vector4.new(-1341.8415527344, 1230.8139648438, 111.10000610352, 1)
    newTrigger.script = "Judy and Nibbles - Mansion"
    newTrigger.repeatable = true
    newTrigger.radius = 3
    table.insert(triggers, newTrigger)
    return triggers
  end
end

function Director:GetScripts()
  local files = dir("./User/Scripts")
  local scripts = {}

  if #Director.scripts ~= #files then
    for _, script in ipairs(files) do
      if string.find(script.name, '.json') then
        table.insert(scripts, Director:LoadScriptData(script.name))
      end
    end
    return scripts
  else
    return Director.scripts
  end
end

function Director:DeleteScript(script)
  if Director.showNodes and Director.selectedActor ~= '' then
    Director:RemoveNodeMarks(Director.selectedActor.nodes)
  end
  os.remove("User/Scripts/"..script.title..".json")
  Director.scripts = Director:GetScripts()
  Director.selectedScript = {title = "Select Script"}
end

return Director
