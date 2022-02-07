Light = {}

function Light:NewLight(handle)
  local obj = {}
	obj.handle = handle
  obj.hash = tostring(handle:GetEntityID().hash)

  local components = Light:GetLightComponent(handle)

  if components then
    obj.component = components[1]
    obj.marker = handle:FindComponentByName("Mesh3185")
    obj.isOn = obj.component:IsOn()
    obj.intensity = obj.component.intensity
    obj.radius = obj.component.radius
    obj.color = Light:ConvertColor({obj.component.color.Red, obj.component.color.Green, obj.component.color.Blue, obj.component.color.Alpha})
    obj.innerAngle = obj.component.innerAngle
    obj.outerAngle = obj.component.outerAngle
    obj.lightType = obj.component.type

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

  Light.activeLight = Light:NewLight(light.handle)
end

function Light:Draw(AMM)
  Light.open = ImGui.Begin("Light Settings", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoCollapse)
  if Light.open then
    -- Check if Light is still in world
    local despawned = true
    for _, prop in ipairs(Props.spawnedPropsList) do
      if prop.hash == Light.activeLight.hash then
        despawned = false
      end
    end

    for _, prop in pairs(Props.activeProps) do
      if prop.hash == Light.activeLight.hash then
        despawned = false
      end
    end

    if despawned then Light.open = false end

    Light.isEditing = true
    Light.activeLight.color, colorChanged = ImGui.ColorPicker4("Color", Light.activeLight.color)

    if colorChanged then
      Light:UpdateColor()
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

  for i, component in ipairs(components) do
    component:ToggleLight(light.isOn)
    if AMM.playerInPhoto then component:SetIntensity(0) end

    if not light.isOn then
      Light.disabled[light.hash..i] = component.intensity
    elseif light.isOn then
      local savedIntensity = Light.disabled[light.hash..i]
      if savedIntensity < 1 then savedIntensity = 100 end
      if savedIntensity then component:SetIntensity(savedIntensity) end
      Light.disabled[light.hash..i] = nil
    end
  end

  light.isOn = not light.isOn
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
  return {math.floor((color[1] * 255) * 100 / 100), math.floor((color[2] * 255) * 100 / 100), math.floor((color[3] * 255) * 100 / 100), color[4]}
end

function Light:ConvertColor(color)
  return {color[1] / 255, color[2] / 255, color[3] / 255, color[4]}
end

function Light:GetLightData(light)
  local newLight = Light:NewLight(light.handle)
  if newLight then
    newLight.color = f("{%f, %f, %f, %f}", newLight.color[1], newLight.color[2], newLight.color[3], newLight.color[4])
    newLight.angles = f("{inner = %f, outer = %f}", newLight.innerAngle, newLight.outerAngle)
  end

  return newLight
end

function Light:SetLightData(light, data)
  local components = Light:GetLightComponent(light.handle)
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

return Light:new()
