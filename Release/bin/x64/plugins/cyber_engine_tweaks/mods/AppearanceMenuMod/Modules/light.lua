Light = {}

function Light:NewLight(handle)
  local obj = {}
	obj.handle = handle

  obj.component = handle:FindComponentByName("amm_light")
  obj.marker = handle:FindComponentByName("Mesh3185")

  if obj.component then
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
  Light.settings = nil
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

  Light.settings = Light:NewLight(light.handle)
end

function Light:Draw(AMM)
  Light.open = ImGui.Begin("Light Settings", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoCollapse)
  if Light.open then
    Light.isEditing = true
    Light.settings.color, colorChanged = ImGui.ColorPicker4("Color", Light.settings.color)

    if colorChanged then
      Light:UpdateColor()
    end

    Light.settings.intensity, intensityChanged = ImGui.DragFloat("Intensity", Light.settings.intensity, 1.0, 0.0, 10000.0)
    if intensityChanged then
      Light.settings.component:SetIntensity(Light.settings.intensity)
    end

    if Light.settings.lightType == ELightType.LT_Area or Light.settings.lightType == ELightType.LT_Area then
      Light.settings.radius, radiusChanged = ImGui.DragFloat("Radius", Light.settings.radius, 0.1, 0.0, 10000.0)
      if radiusChanged then
        Light.settings.component:SetRadius(Light.settings.radius)
      end
    end

    if Light.settings.lightType == ELightType.LT_Spot then
      local anglesChanged = false
      Light.settings.innerAngle, innerUsed = ImGui.DragFloat("Inner Angle", Light.settings.innerAngle, 1.0, 0.0, 10000.0)
      Light.settings.outerAngle, anglesChanged = ImGui.DragFloat("Outer Angle", Light.settings.outerAngle, 1.0, 0.0, 10000.0)

      if innerUsed or anglesChanged then
        Light.settings.component:SetAngles(Light.settings.innerAngle, Light.settings.outerAngle)
      end
    end

    if ImGui.Button(" Toggle Marker ") then
      Light.settings.marker:Toggle(not Light.settings.marker:IsEnabled())
    end

    ImGui.SameLine()
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
  local component = light.handle:FindComponentByName("amm_light")

  if AMM.playerInPhoto then
    if Light.disabled[tostring(light.handle:GetEntityID().hash)] == nil then
      Light.disabled[tostring(light.handle:GetEntityID().hash)] = component.intensity
      component:SetIntensity(0)
    else
      component:SetIntensity(Light.disabled[tostring(light.handle:GetEntityID().hash)])
      Light.disabled[tostring(light.handle:GetEntityID().hash)] = nil
    end
  else
    if Light.disabled[tostring(light.handle:GetEntityID().hash)] then
      component:SetIntensity(Light.disabled[tostring(light.handle:GetEntityID().hash)])
      Light.disabled[tostring(light.handle:GetEntityID().hash)] = nil
    end
    component:ToggleLight(light.isOn)
  end

  light.isOn = not light.isOn
end

function Light:UpdateColor()
  local newColor = NewObject('Color')
  local rgbColor = Light:ConvertToRGB(Light.settings.color)
  newColor.Red = rgbColor[1]
  newColor.Green = rgbColor[2]
  newColor.Blue = rgbColor[3]
  newColor.Alpha = rgbColor[4]
  Light.settings.component:SetColor(newColor)
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
  local component = light.handle:FindComponentByName('amm_light')
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

return Light:new()
