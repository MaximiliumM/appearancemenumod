Light = {}

function Light:NewLight(light)
  local obj = {}
	obj.handle = light.handle
  obj.hash = tostring(light.handle:GetEntityID().hash)
  obj.spawn = light
  obj.isAMMLight = Light:IsAMMLight(light)
  obj.id = light.id

  local components = Light:GetLightComponent(light.handle)

  if components then
    obj.component = components[1]
    obj.marker = light.handle:FindComponentByName("Mesh3185")
    obj.isOn = true
    if obj.component.IsOn then
      obj.isOn = obj.component:IsOn()
    end
    obj.intensity = obj.component.intensity
    obj.radius = obj.component.radius
    obj.color = Light:ConvertColor({obj.component.color.Red, obj.component.color.Green, obj.component.color.Blue, obj.component.color.Alpha})
    obj.innerAngle = obj.component.innerAngle
    obj.outerAngle = obj.component.outerAngle
    obj.lightType = obj.component.type
    obj.shadows = obj.component.contactShadows == rendContactShadowReciever.CSR_All

    -- Movement Properties
    obj.isMoving = false
    obj.currentDirections = {
      forward = false,
      backwards = false,
      right = false,
      left = false,
      up = false,
      down = false,
      rotateLeft = false,
      rotateRight = false,
    }

    obj.analogForward = 0
    obj.analogBackwards = 0
    obj.analogRight = 0
    obj.analogLeft = 0
    obj.analogUp = 0
    obj.analogDown = 0

    -- Original code by keanuWheeze
    function obj:HandleInput(actionName, actionType, action)
      if actionName == "MoveX" or actionName == "PhotoMode_CameraMovementX" then -- Controller movement
        local x = action:GetValue(action)
        if x < 0 then
            obj.currentDirections.left = true
            obj.currentDirections.right = false
            obj.analogRight = 0
            obj.analogLeft = -x
        else
            obj.currentDirections.right = true
            obj.currentDirections.left = false
            obj.analogRight = x
            obj.analogLeft = 0
        end
        if x == 0 then
            obj.currentDirections.right = false
            obj.currentDirections.left = false
            obj.analogRight = 0
            obj.analogLeft = 0
        end
      elseif actionName == "MoveY" or actionName == "PhotoMode_CameraMovementY" then
        local x = action:GetValue(action)
        if x < 0 then
            obj.currentDirections.backwards = true
            obj.currentDirections.forward = false
            obj.analogForward = 0
            obj.analogBackwards = -x
        else
            obj.currentDirections.backwards = false
            obj.currentDirections.forward = true
            obj.analogForward = x
            obj.analogBackwards = 0
        end
        if x == 0 then
            obj.currentDirections.backwards = false
            obj.currentDirections.forward = false
            obj.analogForward = 0
            obj.analogBackwards = 0
        end
      elseif actionName == 'Jump' or (actionName == "right_trigger" or actionName == "PhotoMode_CraneUp") and actionType == "AXIS_CHANGE" then
        local z = action:GetValue(action)
        if z == 0 or actionType == 'BUTTON_RELEASED' then
            obj.analogUp = 0
            obj.currentDirections.up = false
        else
            obj.currentDirections.up = true
            obj.analogUp = z
        end
      elseif actionName == 'ToggleSprint' or (actionName == "left_trigger" or actionName == "PhotoMode_CraneDown") and actionType == "AXIS_CHANGE" then
        local z = action:GetValue(action)
        if z == 0 or actionType == 'BUTTON_RELEASED' then
            obj.analogDown = 0
            obj.currentDirections.down = false
        else
            obj.currentDirections.down = true
            obj.analogDown = z
        end
      end

      if actionName == 'Forward' then
        if actionType == 'BUTTON_PRESSED' then
            obj.currentDirections.forward = true
            obj.analogForward = 1
        elseif actionType == 'BUTTON_RELEASED' then
            obj.currentDirections.forward = false
            obj.analogForward = 0
        end
      elseif actionName == 'Back' then
        if actionType == 'BUTTON_PRESSED' then
            obj.currentDirections.backwards = true
            obj.analogBackwards = 1
        elseif actionType == 'BUTTON_RELEASED' then
            obj.currentDirections.backwards = false
            obj.analogBackwards = 0
        end
      elseif actionName == 'Right' then
        if actionType == 'BUTTON_PRESSED' then
            obj.currentDirections.right = true
            obj.analogRight = 1
        elseif actionType == 'BUTTON_RELEASED' then
            obj.currentDirections.right = false
            obj.analogRight = 0
        end
      elseif actionName == 'Left' then
        if actionType == 'BUTTON_PRESSED' then
            obj.currentDirections.left = true
            obj.analogLeft = 1
        elseif actionType == 'BUTTON_RELEASED' then
            obj.currentDirections.left = false
            obj.analogLeft = 0
        end
      elseif actionName == "character_preview_rotate" and actionType == 'AXIS_CHANGE' then
        if action:GetValue(action) < 0 then
            obj.currentDirections.rotateRight = true
        elseif action:GetValue(action) > 0 then
          obj.currentDirections.rotateLeft = true
        elseif action:GetValue(action) == 0 then
            obj.currentDirections.rotateRight = false
            obj.currentDirections.rotateLeft = false
        end
      elseif actionName == 'DescriptionChange' or actionName == "PhotoMode_Next_Menu" then
        if actionType == 'BUTTON_PRESSED' then
            obj.currentDirections.rotateRight = true
        elseif actionType == 'BUTTON_RELEASED' then
            obj.currentDirections.rotateRight = false
        end
      elseif actionName == 'Ping' or actionName == "PhotoMode_Prior_Menu" then
        if actionType == 'BUTTON_PRESSED' then
            obj.currentDirections.rotateLeft = true
        elseif actionType == 'BUTTON_RELEASED' then
            obj.currentDirections.rotateLeft = false
        end
      end

      obj.isMoving = false
      for _, v in pairs(obj.currentDirections) do
        if v == true then
            obj.isMoving = true
        end
      end
    end

    function obj:Move()
      if obj.handle and Light.camera.handle then
        local newPos = Light.camera.handle:GetWorldPosition()
        local newAngles = Game.GetCameraSystem():GetActiveCameraForward():ToRotation()
        
        newAngles.roll = -newAngles.pitch + 90
        newAngles.pitch = 0
        newAngles.yaw = newAngles.yaw - 90

        for directionKey, state in pairs(obj.currentDirections) do
          if state == true then
            self:CalculateNewPos(directionKey, newPos)
          end
        end

        Game.GetTeleportationFacility():Teleport(obj.handle, newPos, newAngles)
      end
    end

    function obj:CalculateNewPos(direction, newPos)
      local speed = 0.1
      local dir

      if direction == "forward" then
        speed = speed * obj.analogForward
      elseif direction == "backwards" then
        speed = speed * obj.analogBackwards
      elseif direction == "right" then
        speed = speed * obj.analogRight
      elseif direction == "left" then
        speed = speed * obj.analogLeft
      elseif direction == "up" then
        speed = speed * obj.analogUp
      elseif direction == "down" then
        speed = speed * obj.analogDown
      end

      if direction == "forward" or direction == "backwards" then
        dir = Game.GetCameraSystem():GetActiveCameraForward()
      elseif direction == "right" or direction == "left" or direction == "upleft" then
        dir = Game.GetCameraSystem():GetActiveCameraRight()
      end

      if direction == "forward" or direction == "right" then
        newPos.x = newPos.x + (dir.x * speed)
        newPos.y = newPos.y + (dir.y * speed)
        newPos.z = newPos.z + (dir.z * speed)
      elseif direction == "backwards" or direction == "left" then
        newPos.x = newPos.x - (dir.x * speed)
        newPos.y = newPos.y - (dir.y * speed)
        newPos.z = newPos.z - (dir.z * speed)
      elseif direction == "up" then
        newPos.z = newPos.z + (0.7 * speed)
      elseif direction == "down" then
        newPos.z = newPos.z - (0.7 * speed)
      end
    end

    function obj:StartListeners()
      local player = Game.GetPlayer()
      player:UnregisterInputListener(player, 'Forward')
      player:UnregisterInputListener(player, 'Back')
      player:UnregisterInputListener(player, 'Right')
      player:UnregisterInputListener(player, 'Left')

      player:RegisterInputListener(player, 'Forward')
      player:RegisterInputListener(player, 'Back')
      player:RegisterInputListener(player, 'Right')
      player:RegisterInputListener(player, 'Left')
    end

    return obj
  else
    return false
  end
end

function Light:new()

  -- Main Properties
  Light.open = false
  Light.isEditing = false
  Light.activeLight = nil
  Light.disabled = {}
  Light.stickyMode = false
  Light.camera = nil
  Light.activeCameras = {}

  return Light
end

function Light:Setup(light)
  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  if x < ImGui.GetFontSize() * 40 then
    ImGui.SetNextWindowPos(x + (sizeX + 50), y - 40)
  else
    ImGui.SetNextWindowPos(x - (sizeX + 200), y - 40)
  end

  if Light.stickyMode and Light.camera then    
    Light.camera = nil
  end

  Light.activeLight = Light:NewLight(light)

  if Light.stickyMode then
    Light:MoveCameraToLight()
  end
end

function Light:Draw(AMM)
  Light.open = ImGui.Begin("Light Settings", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoCollapse)
  if Light.open then
    -- Check if Light is still in world
    local despawned = true
    if Light.activeLight then
      if Game.FindEntityByID(Light.activeLight.spawn.entityID) then
          despawned = false
      end
    end

    if despawned then Light.open = false end

    Light.isEditing = true
    local color, colorChanged = ImGui.ColorPicker4("Color", Light.activeLight.color)

    if colorChanged then
      if not(color[1] < 0) and not(color[1] > 1)
      and not(color[2] < 0) and not(color[2] > 1)
      and not(color[3] < 0) and not(color[3] > 1)
      and not(color[4] < 0) and not(color[4] > 1) then
        Light.activeLight.color = color
        Light:UpdateColor()
      end
    end

    Light.activeLight.intensity, intensityChanged = ImGui.DragFloat("Intensity", Light.activeLight.intensity, 1.0, 0.0, 10000.0)
    if intensityChanged then
      Light.activeLight.component:SetIntensity(Light.activeLight.intensity)
    end

    if Light.activeLight.lightType == ELightType.LT_Area or Light.activeLight.lightType == ELightType.LT_Area then
      Light.activeLight.radius, radiusChanged = ImGui.DragFloat("Radius", Light.activeLight.radius, 0.1, 0.0, 10000.0)
      if radiusChanged then
        Light.activeLight.component:SetRadius(Light.activeLight.radius)
      end
    end

    if Light.activeLight.lightType == ELightType.LT_Spot then
      local anglesChanged = false
      Light.activeLight.innerAngle, innerUsed = ImGui.DragFloat("Inner Angle", Light.activeLight.innerAngle, 1.0, 0.0, 10000.0)
      Light.activeLight.outerAngle, anglesChanged = ImGui.DragFloat("Outer Angle", Light.activeLight.outerAngle, 1.0, 0.0, 10000.0)

      if innerUsed or anglesChanged then
        Light.activeLight.component:SetAngles(Light.activeLight.innerAngle, Light.activeLight.outerAngle)
      end
    end

    AMM.userSettings.contactShadows, shadowsUsed = ImGui.Checkbox("Local Shadows", AMM.userSettings.contactShadows)

    if shadowsUsed then
      Light:ToggleContactShadows(Light.activeLight)
    end

    if Light.activeLight.isAMMLight then
      ImGui.SameLine()
      Light.stickyMode, stickyUsed = ImGui.Checkbox("Stick To Camera", Light.stickyMode)

      if stickyUsed then
        Light:ToggleStickyMode()
      end

      if not Light.stickyMode then
        if ImGui.Button(" Move Camera To Light ") then
          Light:MoveCameraToLight()
          Light.stickyMode = true
        end
        ImGui.SameLine()
      end
    end

    if Light.activeLight.marker then
      if ImGui.Button(" Toggle Marker ") then
        Light.activeLight.marker:Toggle(not Light.activeLight.marker:IsEnabled())
      end
      ImGui.SameLine()
    end

    if ImGui.Button(" Close Window ") then
      Light.open = false
    end
  end

  ImGui.End()

  if not(Light.open) and Light.isEditing then
    Light.isEditing = false
  end
end

function Light:ToggleLight(light)
  local components = Light:GetLightComponent(light.handle)

  if #components > 0 then
    for i, component in ipairs(components) do
      local savedIntensity = Light.disabled[light.hash..i]
      
      if AMM.playerInPhoto then
        if not savedIntensity then      
          Light.disabled[light.hash..i] = component.intensity
          savedIntensity = 0
        else
          if savedIntensity and savedIntensity < 1 then savedIntensity = 100 end
          Light.disabled[light.hash..i] = nil
        end      
      else
        light.isOn = not light.isOn

        if component.ToggleLight then          
          component:ToggleLight(light.isOn)
        else
          component:Toggle(light.isOn)
        end
      end

      if savedIntensity then
        component:SetIntensity(savedIntensity)
      end
    end
  end
end

function Light:ToggleContactShadows(light)
  local ent = nil
  if light.spawn.uniqueName then
    ent = AMM.Props.spawnedProps[light.spawn.uniqueName()]
  else
    ent = AMM.Props.activeProps[light.spawn.uid]
  end

  local lightData = Light:GetLightData(ent)

  Game.FindEntityByID(ent.entityID):GetEntity():Destroy()

  local lockedTarget = AMM.Tools.lockTarget

  local transform = Game.GetPlayer():GetWorldTransform()
  local pos = ent.handle:GetWorldPosition()
  local angles = GetSingleton('Quaternion'):ToEulerAngles(ent.handle:GetWorldOrientation())
  transform:SetPosition(pos)
  transform:SetOrientationEuler(angles)

  if AMM.userSettings.contactShadows and not string.find(ent.template, "_shadows.ent") then
    ent.template = ent.template:gsub("%.ent", "_shadows.ent")
  elseif not AMM.userSettings.contactShadows and string.find(ent.template, "_shadows.ent") then
    ent.template = ent.template:gsub("_shadows.ent", ".ent")
  end

  ent.entityID = exEntitySpawner.Spawn(ent.template, transform, '')

  Cron.Every(0.1, {tick = 1}, function(timer)
    local entity = Game.FindEntityByID(ent.entityID)

    if entity then
      ent.handle = entity
      ent.hash = tostring(entity:GetEntityID().hash)
      ent.spawned = true

      Light:SetLightData(ent, lightData)
      Light.activeLight = Light:NewLight(ent)
      Light.activeLight.intensity = lightData.intensity

      if lockedTarget then
        AMM.Tools.lockTarget = true
        AMM.Tools:SetCurrentTarget(ent)
      end

      Cron.Halt(timer)
    end
  end)
end

function Light:ToggleStickyMode(systemActivated)
  if systemActivated then
    Light.stickyMode = not Light.stickyMode
  end

  if Light.stickyMode then
    Light:StartCamera()
  else
    Light.camera:Deactivate()
    Light.camera = nil
  end
end

function Light:MoveCameraToLight()
  if not Light.camera then    
    if Light.activeCameras[Light.activeLight.hash] then
      local camera = Light.activeCameras[Light.activeLight.hash]
      Light.camera = camera
      camera:Activate(1)
    else
      local pos = Light.activeLight.handle:GetWorldPosition()
      local lightAngles = Light.activeLight.handle:GetWorldOrientation():ToEulerAngles()
      local angles = EulerAngles.new(0, 0, lightAngles.yaw)
      Light:StartCamera(pos, angles)
    end
  end
end

function Light:StartCamera(pos, angles)
  Light.camera = AMM.Camera:new()

  Light.camera:Spawn(pos, angles)
  Light.camera:StartListeners()

  Cron.Every(0.1, function(timer)
    if Light.camera.handle then
      Light.camera:Activate(1)
      Light.activeCameras[Light.activeLight.hash] = Light.camera

      local cameraPos = Light.camera.handle:GetWorldPosition()
      local cameraAngles = Light.camera.component:GetLocalOrientation():ToEulerAngles()

      Game.GetTeleportationFacility():Teleport(Light.activeLight.handle, cameraPos, cameraAngles)

      Cron.Halt(timer)
    end
  end)
end

function Light:UpdateColor()
  local newColor = NewObject('Color')
  local rgbColor = Light:ConvertToRGB(Light.activeLight.color)
  newColor.Red = rgbColor[1]
  newColor.Green = rgbColor[2]
  newColor.Blue = rgbColor[3]
  newColor.Alpha = rgbColor[4]
  Light.activeLight.component:SetColor(newColor)
end

function Light:ConvertToRGB(color)
  return {math.floor((color[1] * 255) * 100 / 100), math.floor((color[2] * 255) * 100 / 100), math.floor((color[3] * 255) * 100 / 100), math.floor((color[4] * 255) * 100 / 100)}
end

function Light:ConvertColor(color)
  return {color[1] / 255, color[2] / 255, color[3] / 255, color[4] / 255}
end

function Light:GetLightData(light)
  local newLight = Light:NewLight(light)
  if newLight then
    newLight.color = f("{%f, %f, %f, %f}", newLight.color[1], newLight.color[2], newLight.color[3], newLight.color[4])
    newLight.angles = f("{inner = %f, outer = %f}", newLight.innerAngle, newLight.outerAngle)
  end

  return newLight
end

function Light:SetLightData(light, data)
  local components = Light:GetLightComponent(light.handle)

  if components and #components > 0 then
    local component = components[1]
    local angles = loadstring('return '..data.angles, '')()
    local newColor = NewObject('Color')
    local rgbColor = Light:ConvertToRGB(loadstring('return '..data.color, '')())
    newColor.Red = rgbColor[1]
    newColor.Green = rgbColor[2]
    newColor.Blue = rgbColor[3]
    newColor.Alpha = rgbColor[4]
    component:SetColor(newColor)
    component:SetIntensity(data.intensity)
    component:SetRadius(data.radius)
    component:SetAngles(angles.inner, angles.outer)
  else
    Util:AMMError("Light Data is missing:"..light.spawn.name)
  end
end

function Light:GetLightComponent(handle)
  local components = {}

  for comp in db:urows("SELECT cname FROM components WHERE type = 'Lights'") do
    component = handle:FindComponentByName(comp)
    if component then
      table.insert(components, component)
    end
  end

  if #components > 0 then return components else return nil end
end

function Light:IsAMMLight(light)
  local possibleIDs = {
    "0xAFCFDCFF, 37",
    "0xE4351246, 38",
    "0x670133EB, 37",
  }

  for _, id in ipairs(possibleIDs) do
    if light.id == id then
      return true
    end
  end

  return false
end

return Light:new()
