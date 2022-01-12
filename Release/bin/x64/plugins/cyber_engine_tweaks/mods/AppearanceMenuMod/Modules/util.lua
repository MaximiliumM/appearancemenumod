local Util = {
  openPopup = false,
  popup = {},
}

-- Code Helper Methods
function Util:ShallowCopy(copy, orig)
  local orig_type = type(orig)
  if orig_type == 'table' then
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function Util:GetTableKeys(tab)
  local keyset = {}
  for k,v in pairs(tab) do
    keyset[#keyset + 1] = k
  end
  return keyset
end

function Util:Split(s, delimiter)
  result = {}
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match)
  end
  return result
end

function Util:ParseSearch(query)
  local words = Util:Split(query, " ")
  local r = ""
  for i, word in ipairs(words) do
      r = r..string.format('entity_name LIKE "%%%s%%"', word)
      if i ~= #words then r = r..' AND ' end
  end
  return r
end

function Util:GetPosString(pos, angles)
  local posString = f("{x = %f, y = %f, z = %f, w = %f}", pos.x, pos.y, pos.z, pos.w)
  if angles then
    posString = f("{x = %f, y = %f, z = %f, w = %f, roll = %f, pitch = %f, yaw = %f}", pos.x, pos.y, pos.z, pos.w, angles.roll, angles.pitch, angles.yaw)
  end

  return posString
end

function Util:GetPosFromString(posString)
  local pos = loadstring("return "..posString, '')()
  return Vector4.new(pos.x, pos.y, pos.z, pos.w)
end

function Util:GetAnglesFromString(posString)
  local pos = loadstring("return "..posString, '')()
  return EulerAngles.new(pos.roll, pos.pitch, pos.yaw)
end

-- Game Related Helpers
function Util:GetPlayerGender()
  -- True = Female / False = Male
  if string.find(tostring(Game.GetPlayer():GetResolvedGenderName()), "Female") then
		return "_Female"
	else
		return "_Male"
	end
end

function Util:PlayVoiceOver(handle, vo)
  Game["gameObject::PlayVoiceOver;GameObjectCNameCNameFloatEntityIDBool"](handle, CName.new(vo), CName.new(""), 1, handle:GetEntityID(), true)
end

function Util:VectorDistance(pointA, pointB)
  return math.sqrt(((pointA.x - pointB.x)^2) + ((pointA.y - pointB.y)^2) + ((pointA.z - pointB.z)^2))
end

function Util:CheckIfCommandIsActive(handle, cmd)
  return GetSingleton('AIbehaviorUniqueActiveCommandList'):IsActionCommandById(handle:GetAIControllerComponent().activeCommands, cmd.id)
end

function Util:CancelCommand(handle, cmd)
  handle:GetAIControllerComponent():CancelCommand(cmd)
end

function Util:GetBehindPlayerPosition(distance)
  local pos = AMM.player:GetWorldPosition()
  local heading = AMM.player:GetWorldForward()
  local behindPlayer = Vector4.new(pos.x - (heading.x * distance), pos.y - (heading.y * distance), pos.z, pos.w)
  return behindPlayer
end

function Util:TeleportTo(targetHandle, targetPosition, targetRotation, distanceFromGround)
  local pos = Game.GetPlayer():GetWorldPosition()
  local heading = Game.GetPlayer():GetWorldForward()
  local teleportPosition = Vector4.new(pos.x + heading.x, pos.y + heading.y, (pos.z + heading.z) + distanceFromGround, pos.w + heading.w)

  Game.GetTeleportationFacility():Teleport(targetHandle, targetPosition or teleportPosition, EulerAngles.new(0, 0, targetRotation or 0))
end

function Util:TeleportNPCTo(targetPuppet, targetPosition, targetRotation)
  local pos = Game.GetPlayer():GetWorldPosition()
  local heading = Game.GetPlayer():GetWorldForward()
  local teleportPosition = Vector4.new(pos.x + heading.x, pos.y + heading.y, pos.z + heading.z, pos.w + heading.w)

	local teleportCmd = NewObject('handle:AITeleportCommand')
	teleportCmd.position = targetPosition or teleportPosition
	teleportCmd.rotation = targetRotation or 0.0
	teleportCmd.doNavTest = false

	targetPuppet:GetAIControllerComponent():SendCommand(teleportCmd)

	return teleportCmd, targetPuppet
end

function Util:EquipPrimaryWeaponCommand(targetPuppet, equip)
  local cmd = NewObject("handle:AISwitchToPrimaryWeaponCommand")
  cmd.unEquip = equip
  cmd = cmd:Copy()

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)
end

function Util:EquipSecondaryWeaponCommand(targetPuppet, equip)
  local cmd = NewObject("handle:AISwitchToSecondaryWeaponCommand")
  cmd.unEquip = equip
  cmd = cmd:Copy()

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)
end

function Util:EquipGivenWeapon(targetPuppet, weapon, override)
  local cmd = NewObject("AIEquipCommand")
  cmd.slotId = TweakDBID.new("AttachmentSlots.WeaponRight")
  cmd.itemId = weapon
  cmd.failIfItemNotFound = false
  if override then
    cmd.durationOverride = 99999
  end
  cmd = cmd:Copy()

  target.handle:GetAIControllerComponent():SendCommand(cmd)
end

function Util:MoveTo(targetPuppet, pos, walkType, stealth)
  local dest = NewObject('WorldPosition')

  dest:SetVector4(dest, pos or AMM.player:GetWorldPosition())

  local positionSpec = NewObject('AIPositionSpec')
  positionSpec:SetWorldPosition(positionSpec, dest)

  local cmd = NewObject('handle:AIMoveToCommand')
  cmd.movementTarget = positionSpec
  cmd.rotateEntityTowardsFacingTarget = false
  cmd.ignoreNavigation = false
  cmd.desiredDistanceFromTarget = 2
  cmd.movementType = walkType or "Walk"
  cmd.finishWhenDestinationReached = true
  cmd.alwaysUseStealth = stealth or false

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)

  return cmd, targetPuppet
end

function Util:HoldPosition(targetPuppet, duration)
	local holdCmd = NewObject('handle:AIHoldPositionCommand')
	holdCmd.duration = duration or 5.0
	holdCmd.ignoreInCombat = false
	holdCmd.removeAfterCombat = false
	holdCmd.alwaysUseStealth = true

	targetPuppet:GetAIControllerComponent():SendCommand(holdCmd)

	return holdCmd, targetPuppet
end

function Util:NPCTalk(handle, vo, category, idle)
	local stimComp = handle:GetStimReactionComponent()
	local animComp = handle:GetAnimationControllerComponent()

	if stimComp and animComp then
		local animFeat = NewObject("handle:AnimFeature_FacialReaction")
		animFeat.category = category or 3
		animFeat.idle = idle or 5
		stimComp:ActivateReactionLookAt(Game.GetPlayer(), false, true, 1, true)
		Util:PlayVoiceOver(handle, vo or "greeting")
		animComp:ApplyFeature(CName.new("FacialReaction"), animFeat)
	end
end

function Util:NPCLookAt(handle, target, headSettings, chestSettings)
  local stimComp = handle:GetStimReactionComponent()
  stimComp:DeactiveLookAt()

  local lookAtParts = {}
  local lookAtEvent = LookAtAddEvent.new()
  lookAtEvent:SetEntityTarget(target and target.handle or Game.GetPlayer(), "pla_default_tgt", Vector4.EmptyVector())
  lookAtEvent:SetStyle(animLookAtStyle.Normal)
  lookAtEvent.request.limits.softLimitDegrees = 360.00
  lookAtEvent.request.limits.hardLimitDegrees = 270.00
  lookAtEvent.request.limits.hardLimitDistance = 1000000.000000
  lookAtEvent.request.limits.backLimitDegrees = 210.00
  lookAtEvent.request.calculatePositionInParentSpace = true
  lookAtEvent.bodyPart = "Eyes"

  if headSettings then
    local lookAtPartRequest = LookAtPartRequest.new()
    lookAtPartRequest.partName = "Head"
    lookAtPartRequest.weight = headSettings.weight
    lookAtPartRequest.suppress = headSettings.suppress
    lookAtPartRequest.mode = 0
    table.insert(lookAtParts, lookAtPartRequest)
  end

  if chestSettings then
    local lookAtPartRequest = LookAtPartRequest.new()
    lookAtPartRequest.partName = "Chest"
    lookAtPartRequest.weight = chestSettings.weight
    lookAtPartRequest.suppress = chestSettings.suppress
    lookAtPartRequest.mode = 0
    table.insert(lookAtParts, lookAtPartRequest)
  end

  lookAtEvent:SetAdditionalPartsArray(lookAtParts)
  handle:QueueEvent(lookAtEvent)
  stimComp.lookatEvent = lookAtEvent
end

function Util:GetNPCsInRange(maxDistance)
	local searchQuery = Game["TSQ_NPC;"]()
	searchQuery.maxDistance = maxDistance
	local success, parts = Game.GetTargetingSystem():GetTargetParts(Game.GetPlayer(), searchQuery)
	if success then
		local entities = {}
		for i, v in ipairs(parts) do
			local entity = v:GetComponent(v):GetEntity()
      if entity:IsNPC() then
        entity = AMM:NewTarget(entity, "NPC", AMM:GetScanID(entity), AMM:GetNPCName(entity),AMM:GetScanAppearance(entity), AMM:GetAppearanceOptions(entity))
        table.insert(entities, entity)
      end
	  end

		return entities
	end
end

function Util:SetGodMode(entity, immortal)
  local entityID = entity:GetEntityID()
	local gs = Game.GetGodModeSystem()
  gs:ClearGodMode(entityID, CName.new("Default"))

	if immortal then
		gs:AddGodMode(entityID, gameGodModeType.Immortal, CName.new("Default"))
	else
    gs:AddGodMode(entityID, gameGodModeType.Mortal, CName.new("Default"))
	end
end

function Util:Despawn(handle)
  if handle:IsVehicle() then
    local vehPS = handle:GetVehiclePS()
    vehPS:SetHasExploded(false)
  end
  handle:Dispose()
end

function Util:UnlockDoor(handle)
  local handlePS = handle:GetDevicePS()

  if handlePS:IsLocked() then handlePS:ToggleLockOnDoor() end
  if handlePS:IsSealed() then handlePS:ToggleSealOnDoor() end

  handle:OpenDoor()

end

function Util:RepairVehicle(handle)
  local vehPS = handle:GetVehiclePS()
  local vehVC = handle:GetVehicleComponent()

  if handle then
    handle:DestructionResetGrid()
    handle:DestructionResetGlass()
  end

  if vehVC then vehVC:RepairVehicle() end
  if vehPS then vehPS:ForcePersistentStateChanged() end
end

function Util:ToggleDoors(handle)
  local vehPS = handle:GetVehiclePS()
  local state = vehPS:GetDoorState(1).value

  if state == "Closed" then
    vehPS:OpenAllRegularVehDoors()
  elseif state == "Open" then
    vehPS:CloseAllVehDoors()
  end
end

function Util:ToggleWindows(handle)
  local vehPS = handle:GetVehiclePS()
  local state = vehPS:GetWindowState(1).value

  if state == "Closed" then
    vehPS:OpenAllVehWindows()
  elseif state == "Open" then
    vehPS:CloseAllVehWindows()
  end
end

function Util:ToggleEngine(handle)
  local vehVC = handle:GetVehicleComponent()
  local vehVCPS = vehVC:GetVehicleControllerPS()
  local state = vehVCPS:GetState()

  if state == vehicleEState.Default then
      vehVCPS:SetState(2)
  else
      vehVCPS:SetState(1)
  end
end

function Util:SetupPopup()
  if Util.openPopup then
    if ImGui.BeginPopupModal("Error", ImGuiWindowFlags.AlwaysAutoResize) then
      ImGui.Text(Util.popup.text)
      ImGui.Spacing()

      if ImGui.Button("Ok", -1, 40) then
        Util.openPopup = false
        ImGui.CloseCurrentPopup()
      end

      ImGui.EndPopup()
    end
  end
end

function Util:OpenPopup(popupInfo)
  Util.popup = {}
  Util.popup.text = popupInfo.text
  Util.openPopup = true
  ImGui.OpenPopup("Error")
end

function Util:CheckVByID(id)
  local possibleIDs = {
    "0x2A16D43E, 34", "0x9EDC71E0, 33",
    "0x15982ADF, 28", "0x451222BE, 24",
    "0x9FFA2212, 29", "0x382F94F4, 31",
    "0x55C01D9F, 36",
  }

  for _, possibleID in ipairs(possibleIDs) do
    if id == possibleID then return true end
  end

  return false
end

function Util:GetAllCategoryIDs(categories)
  local t = {}
  for k, v in ipairs(categories) do
      t[#t + 1] = tostring(v.cat_id)
  end
  local catIDs = table.concat(t, ", ")
  catIDs = catIDs..", 31"
  return "("..catIDs..")"
end

function Util:CanBeHostile(t)
	local canBeHostile = t:GetRecord():AbilitiesContains(GetSingleton("gamedataTweakDBInterface"):GetGameplayAbilityRecord(TweakDBID.new("Ability.CanCloseCombat")))
	if not(canBeHostile) then
		canBeHostile = t:GetRecord():AbilitiesContains(GetSingleton("gamedataTweakDBInterface"):GetGameplayAbilityRecord(TweakDBID.new("Ability.HasChargeJump")))
	end

	return canBeHostile
end

function Util:UnlockVehicle(handle)
	handle:GetVehiclePS():UnlockAllVehDoors()
end

function Util:CreateInteractionChoice(action, title)
  local choiceData =  InteractionChoiceData.new()
  choiceData.localizedName = title
  choiceData.inputAction = action

  local choiceType = ChoiceTypeWrapper.new()
  choiceType:SetType(gameinteractionsChoiceType.Blueline)
  choiceData.type = choiceType

  return choiceData
end

function Util:PrepareVisualizersInfo(hub)
  local visualizersInfo = VisualizersInfo.new()
  visualizersInfo.activeVisId = hub.id
  visualizersInfo.visIds = { hub.id }

  return visualizersInfo
end

function Util:SetInteractionHub(title, action, active)
  local choiceHubData =  InteractionChoiceHubData.new()
  choiceHubData.id = -1001
  choiceHubData.active = active
  choiceHubData.flags = EVisualizerDefinitionFlags.Undefined
  choiceHubData.title = title

  local choices = {}
  table.insert(choices, Util:CreateInteractionChoice(action, title))
  choiceHubData.choices = choices

  local visualizersInfo = Util:PrepareVisualizersInfo(choiceHubData)

  local blackboardDefs = Game.GetAllBlackboardDefs()
  local interactionBB = Game.GetBlackboardSystem():Get(blackboardDefs.UIInteractions)
  interactionBB:SetVariant(blackboardDefs.UIInteractions.InteractionChoiceHub, ToVariant(choiceHubData), true)
  interactionBB:SetVariant(blackboardDefs.UIInteractions.VisualizersInfo, ToVariant(visualizersInfo), true)
end

function Util:GetAllInRange(maxDistance, includeSecondaryTargets, ignoreInstigator, action)
  local searchQuery = Game["TSQ_ALL;"]()
	searchQuery.maxDistance = maxDistance
	searchQuery.includeSecondaryTargets = includeSecondaryTargets
	searchQuery.ignoreInstigator = ignoreInstigator
	local success, parts = Game.GetTargetingSystem():GetTargetParts(AMM.player, searchQuery)
	if success then
		for i, v in ipairs(parts) do
			local entity = v:GetComponent(v):GetEntity()
      action(entity)
		end
	end
end

return Util
