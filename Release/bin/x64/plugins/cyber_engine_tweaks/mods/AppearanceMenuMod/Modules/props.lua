Props = {}

function Props:NewProp(uid, id, name, template, posString, tag)
  local obj = {}
	obj.handle = ''
  obj.uid = uid
	obj.id = id
	obj.name = name
	obj.template = template
  obj.tag = tag
  obj.entityID = ''
  obj.mappinData = nil

  local pos = loadstring("return "..posString, '')()
  obj.pos = Vector4.new(pos.x, pos.y, pos.z, pos.w)
  obj.angles = EulerAngles.new(pos.roll, pos.pitch, pos.yaw)
	obj.type = "Prop"

  return obj
end

function Props:NewTrigger(triggerString)
  local obj = {}

  local trig = loadstring("return "..triggerString, '')()
  obj.str = triggerString
	obj.pos = Vector4.new(trig.x, trig.y, trig.z, trig.w)
	obj.type = "Trigger"

  return obj
end

function Props:new()

  -- Main Properties
  Props.savedProps = Props:GetProps()
  Props.triggers = Props:GetTriggers()
  Props.tags = Props:GetTags()
  Props.activeProps = {}
  Props.removingFromTag = ''
  Props.playerLastPos = ''
  Props.searchQuery = ''
  Props.searchBarWidth = 500

  return Props
end

function Props:Update()
  Props.savedProps = Props:GetProps()
  Props.triggers = Props:GetTriggers()
  Props.tags = Props:GetTags()
end

function Props:Draw(AMM)
  if ImGui.BeginTabItem("Decor") then

    Props.style = {
      buttonHeight = ImGui.GetFontSize() * 2,
      buttonWidth = -1,
      halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
    }

    Props:DrawHeaders()

    ImGui.EndTabItem()
  end
end

function Props:DrawProps(props)
  for _, prop in ipairs(props) do
    ImGui.Text(prop.name)

    if Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' then
      ImGui.SameLine()
      AMM.UI:TextColored("In World")
    end

    if ImGui.SmallButton("Remove##"..prop.name) then
      Props:RemoveProp(prop)
    end

    if Props.activeProps[prop.uid] ~= nil and Props.activeProps[prop.uid].handle ~= '' then
      ImGui.SameLine()
      if ImGui.SmallButton("Update Position##"..prop.name) then
        Props:SavePropPosition(Props.activeProps[prop.uid])
      end

      ImGui.SameLine()
      if ImGui.SmallButton("Target".."##"..prop.name) then
        AMM.Tools:SetCurrentTarget(Props.activeProps[prop.uid])
        AMM.Tools.lockTarget = true
      end

      local buttonLabel = "Show On Map"
      if prop.mappinData ~= nil then
        buttonLabel = "Hide From Map"
      end

      ImGui.SameLine()
      if ImGui.SmallButton(buttonLabel.."##"..prop.name) then
        if prop.mappinData ~= nil then
          Props:HideFromMap(prop.mappinData)
          prop.mappinData = nil
        else
          prop.mappinData = Props:ShowOnMap(prop.pos)
        end
      end

      local newTag, used = ImGui.InputText(" ##"..prop.name, prop.tag, 100)

      if used and newTag ~= '' then
        Props:UpdatePropTag(prop, newTag)
      end
    end

    AMM.UI:Spacing(4)
  end
end

function Props:DrawHeaders()
  if #Props.savedProps > 0 then

    local props = {}

    ImGui.PushItemWidth(Props.searchBarWidth)
    Props.searchQuery = ImGui.InputTextWithHint(" ", "Search", Props.searchQuery, 100)
    Props.searchQuery = Props.searchQuery:gsub('"', '')
    ImGui.PopItemWidth()

    if Props.searchQuery ~= '' then
      props = Props:GetProps(Props.searchQuery)

      ImGui.SameLine()
      if ImGui.Button("Clear") then
        Props.searchQuery = ''
      end
    end

    ImGui.Spacing()

    AMM.UI:TextColored("Saved Props")

    ImGui.Spacing()

    if #props ~= 0 then
      Props:DrawProps(props)
    else
      for _, tag in ipairs(Props.tags) do
        if ImGui.CollapsingHeader(tag) then

          props = Props:GetProps(tag)

          Props:DrawTagActions(props, tag)
          Props:DrawProps(props)
        end
      end
    end
  else
    AMM.UI:TextColored("Decorating")
    ImGui.TextWrapped("Spawn Props using Spawn tab and decorate your house or anywhere you want to your heart content! Use Save Position to move Props to this tab.")
  end
end

function Props:DrawTagActions(props, tag)

  AMM.UI:Spacing(8)

  local newTag, used = ImGui.InputText("Tag##"..tag, tag, 100)

  if used then
    for _, prop in ipairs(props) do
      Props:UpdatePropTag(prop, newTag)
    end
  end

  if ImGui.SmallButton(" Update Tag ##"..tag) and newTag ~= '' then
    Props:Update()
  end

  ImGui.SameLine()
  if Props.removingFromTag == tag then
    ImGui.Text("Removing all Props from tag...")

    ImGui.SameLine()
    if ImGui.SmallButton(" Cancel ##"..tag) then
      Props.removingFromTag = "cancel"
    end
  else
    if ImGui.SmallButton(" Remove All Props ##"..tag) then
      Props.removingFromTag = tag

      Cron.After(3.0, function()
        if Props.removingFromTag ~= 'cancel' then
          for _, prop in ipairs(props) do
            Props:RemoveProp(prop)
          end
        end

        Props.removingFromTag = ''
      end)
    end
  end

  AMM.UI:Separator()
end

function Props:SensePropsTriggers()
  local playerPos = AMM.player:GetWorldPosition()
  local distFromLastPos = 0

  if Props.playerLastPos ~= '' then
    distFromLastPos = Util:VectorDistance(playerPos, Props.playerLastPos)
  end

  if distFromLastPos <= 60 then
    Props.playerLastPos = Game.GetPlayer():GetWorldPosition()

    for _, trigger in ipairs(Props.triggers) do
      local dist = Util:VectorDistance(playerPos, trigger.pos)

      if dist <= 60 then
        local props = Props:GetPropsToSpawn(trigger)
        if #props > 0 then
          for _, prop in ipairs(props) do
            if Props.activeProps[prop.uid] == nil then
              Props:SpawnProp(prop)
            end
          end
        end
      end
    end
  end
end

function Props:GetPropsToSpawn(trigger)
  local props = {}
  for prop in db:nrows(f("SELECT * FROM saved_props WHERE trigger = '%s'", trigger.str)) do
    table.insert(props, Props:NewProp(prop.uid, prop.entity_id, prop.name, prop.template_path, prop.pos, prop.tag))
  end

  return props
end

function Props:SpawnProp(ent)
  local spawnTransform = AMM.player:GetWorldTransform()
  spawnTransform:SetPosition(ent.pos)
  spawnTransform:SetOrientationEuler(ent.angles)

  ent.entityID = WorldFunctionalTests.SpawnEntity(ent.template, spawnTransform, '')

  Cron.Every(0.1, {tick = 1}, function(timer)
    local entity = Game.FindEntityByID(ent.entityID)
    if entity then
      ent.handle = entity
      ent.parameters = {ent.pos, ent.angles}
      if AMM:GetScanClass(ent.handle) == 'entEntity' then
				ent.type = 'entEntity'
			end
      Cron.Halt(timer)
    end
  end)

  Props.activeProps[ent.uid] = ent
end

function Props:GetTagBasedOnLocation()
  if AMM.Tools then
    local playerPos = AMM.player:GetWorldPosition()
    for _, loc in ipairs(AMM.Tools:GetLocations()) do
      if loc.loc_name:match("%-%-%-%-") == nil then
        local pos = Vector4.new(loc.x, loc.y, loc.z, loc.w)
        local dist = Util:VectorDistance(playerPos, pos)

        if dist <= 60 then
          return loc.loc_name
        end
      end
    end

    return "Misc"
  end
end

function Props:ShowOnMap(pos)
  local variant = 'FastTravelVariant'

  local mappinData = NewObject('gamemappinsMappinData')
  mappinData.mappinType = TweakDBID.new('Mappins.QuestDynamicMappinDefinition')
  mappinData.variant = Enum.new('gamedataMappinVariant', variant)
  mappinData.visibleThroughWalls = true

  return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
end

function Props:HideFromMap(mappinData)
  Game.GetMappinSystem():UnregisterMappin(mappinData)
end

function Props:UpdatePropTag(prop, newTag)
  db:execute(f('UPDATE saved_props SET tag = "%s" WHERE uid = %i', newTag, prop.uid))
end

function Props:SavePropPosition(ent)
  local pos = ent.handle:GetWorldPosition()
  local angles = GetSingleton('Quaternion'):ToEulerAngles(ent.handle:GetWorldOrientation())
	if pos == nil then
		pos = ent.parameters[1]
    angles = ent.parameters[2]
	end

  local tag = Props:GetTagBasedOnLocation()

  local trigger = Props:GetPosString(Props:CheckForTriggersNearby(pos))
  pos = Props:GetPosString(pos, angles)

  if ent.uid then
    db:execute(f('UPDATE saved_props SET pos = "%s" WHERE uid = %i', pos, ent.uid))
  else
	  db:execute(f('INSERT INTO saved_props (entity_id, name, template_path, pos, trigger, tag) VALUES ("%s", "%s", "%s", "%s", "%s", "%s")', ent.id, ent.name, ent.template, pos, trigger, tag))
  end

  Props.playerLastPos = ''
  Props:SensePropsTriggers()
  Props:Update()
  AMM:UpdateSettings()

  Cron.After(2.0, function()
    AMM:DespawnProp(ent)
  end)
end

function Props:CheckForTriggersNearby(pos)
  local closestTriggerPos = pos
  for _, trigger in ipairs(Props.triggers) do
    if Util:VectorDistance(pos, trigger.pos) < 60 then
      closestTriggerPos = trigger.pos
    end
  end

  return closestTriggerPos
end

function Props:RemoveProp(ent)
  if Props.activeProps[ent.uid] and Props.activeProps[ent.uid].handle ~= '' then Props:DespawnProp(ent) end
  db:execute(f("DELETE FROM saved_props WHERE uid = '%i'", ent.uid))
  Props:Update()
end

function Props:DespawnProp(ent)
	WorldFunctionalTests.DespawnEntity(Props.activeProps[ent.uid].handle)
	Props.activeProps[ent.uid] = nil
end

function Props:GetProps(query)
  local dbQuery = 'SELECT * FROM saved_props ORDER BY name ASC'
  if query then dbQuery = 'SELECT * FROM saved_props WHERE name LIKE "%'..query..'%" OR tag LIKE "%'..query..'%" ORDER BY name ASC' end
  local props = {}
  for prop in db:nrows(dbQuery) do
    table.insert(props, Props:NewProp(prop.uid, prop.entity_id, prop.name, prop.template_path, prop.pos, prop.tag))
  end

  return props
end

function Props:GetTriggers()
  local triggers = {}
  for trigger in db:urows("SELECT DISTINCT trigger FROM saved_props") do
    table.insert(triggers, Props:NewTrigger(trigger))
  end

  return triggers
end

function Props:GetTags()
  local tags = {}
  for tag in db:urows("SELECT DISTINCT tag FROM saved_props") do
    table.insert(tags, tag)
  end

  return tags
end

function Props:GetPosString(pos, angles)
  local posString = f("{x = %f, y = %f, z = %f, w = %f}", pos.x, pos.y, pos.z, pos.w)
  if angles then
    posString = f("{x = %f, y = %f, z = %f, w = %f, roll = %f, pitch = %f, yaw = %f}", pos.x, pos.y, pos.z, pos.w, angles.roll, angles.pitch, angles.yaw)
  end

  return posString
end

return Props:new()
