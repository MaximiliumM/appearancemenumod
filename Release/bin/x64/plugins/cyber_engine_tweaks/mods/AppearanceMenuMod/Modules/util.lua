local Util = {
  errorDisplayed = false,
  openPopup = false,
  popup = {},
  playerLastPos = '',
}

-- AMM Helper Methods
function Util:AMMError(msg, reset)
  if reset then
    Util.errorDisplayed = false
  end

  if not Util.errorDisplayed then
    print('[AMM Error] '..msg)
    Util.errorDisplayed = true
  end
end

function Util:AMMDebug(msg, reset)
  if AMM.Debug ~= '' then
    if reset then
      Util.errorDisplayed = false
    end

    if not Util.errorDisplayed then
      print('[AMM Debug] '..msg)
      Util.errorDisplayed = true
    end
  end
end

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
function Util:AddPlayerEffects()
  Game.ApplyEffectOnPlayer("GameplayRestriction.NoMovement")
  Game.ApplyEffectOnPlayer("GameplayRestriction.NoCameraControl")
  Game.ApplyEffectOnPlayer("GameplayRestriction.NoZooming")
  Game.ApplyEffectOnPlayer("GameplayRestriction.FastForwardCrouchLock")
  Game.ApplyEffectOnPlayer("GameplayRestriction.NoCombat")
  Game.ApplyEffectOnPlayer("GameplayRestriction.VehicleNoSummoning")
  Game.ApplyEffectOnPlayer("GameplayRestriction.NoPhone")
end

function Util:RemovePlayerEffects()
  Game.RemoveEffectPlayer("GameplayRestriction.NoMovement")
  Game.RemoveEffectPlayer("GameplayRestriction.NoCameraControl")
  Game.RemoveEffectPlayer("GameplayRestriction.NoZooming")
  Game.RemoveEffectPlayer("GameplayRestriction.FastForwardCrouchLock")
  Game.RemoveEffectPlayer("GameplayRestriction.NoCombat")
  Game.RemoveEffectPlayer("GameplayRestriction.VehicleNoSummoning")
  Game.RemoveEffectPlayer("GameplayRestriction.NoPhone")
end
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
  return AIbehaviorUniqueActiveCommandList.IsActionCommandById(handle:GetAIControllerComponent().activeCommands, cmd.id)
end

function Util:CancelCommand(handle, cmd)
  handle:GetAIControllerComponent():CancelCommand(cmd)
end

function Util:PlayerPositionChangedSignificantly(playerPos)
  local distFromLastPos = 60

  if Util.playerLastPos ~= '' then
    distFromLastPos = Util:VectorDistance(playerPos, Util.playerLastPos)
  end

  if distFromLastPos >= 60 then
    Util.playerLastPos = Game.GetPlayer():GetWorldPosition()

    return true
  end

  return false
end

function Util:GetBehindPlayerPosition(distance)
  local player = Game.GetPlayer()
  local pos = player:GetWorldPosition()
  local heading = player:GetWorldForward()
  local d = distance or 1
  local behindPlayer = Vector4.new(pos.x - (heading.x * d), pos.y - (heading.y * d), pos.z, pos.w)
  return behindPlayer
end

function Util:TeleportTo(targetHandle, targetPosition, targetRotation, distanceFromGround, distanceFromPlayer)
  local pos = Game.GetPlayer():GetWorldPosition()
  local heading = Game.GetPlayer():GetWorldForward()
  local d = distanceFromPlayer or 1
  local teleportPosition = Vector4.new(pos.x + (heading.x * d), pos.y + (heading.y * d), (pos.z + heading.z) + (distanceFromGround or 0), pos.w + heading.w)

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

function Util:NPCTalk(handle, vo, category, idle, upperBody)
	local stimComp = handle:GetStimReactionComponent()
	local animComp = handle:GetAnimationControllerComponent()

	if stimComp and animComp then
		local animFeat = NewObject("handle:AnimFeature_FacialReaction")
		animFeat.category = category or 3
		animFeat.idle = idle or 5
		stimComp:ActivateReactionLookAt(Game.GetPlayer(), false, 1, upperBody or true, true)
		Util:PlayVoiceOver(handle, vo or "greeting")
		animComp:ApplyFeature(CName.new("FacialReaction"), animFeat)
	end
end

function Util:NPCApplyFeature(handle, input, value)
  local evt = AnimInputSetterAnimFeature.new()
  evt.key = input
  evt.value = value
  handle:QueueEvent(evt)
end

function Util:NPCLookAt(handle, target, headSettings, chestSettings)
  local stimComp = handle:FindComponentByName("ReactionManager")

  if stimComp then

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
  else
    log("Couldn't find ReactionManager")
  end
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

function Util:SetMarkerAtPosition(pos, variant)
  local mappinData = NewObject('gamemappinsMappinData')
  mappinData.mappinType = TweakDBID.new('Mappins.QuestDynamicMappinDefinition')
  mappinData.variant = Enum.new('gamedataMappinVariant', variant or 'FastTravelVariant')
  mappinData.visibleThroughWalls = true

  return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
end

function Util:SetMarkerOverObject(handle, variant, offset)
  local mappinData = NewObject('gamemappinsMappinData')
  mappinData.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
  mappinData.variant = variant or 'FastTravelVariant'
  mappinData.visibleThroughWalls = true

  local zOffset = offset or 1
  local _, isNPC = pcall(function() return handle:IsNPC() end)
  if isNPC then zOffset = 2 end
  local offset = ToVector3{ x = 0, y = 0, z = zOffset } -- Move the pin a bit up relative to the target
  local slot = CName.new('poi_mappin')

  return Game.GetMappinSystem():RegisterMappinWithObject(mappinData, handle, slot, offset)
end

function Util:ToggleCompanion(handle)
  if handle.isPlayerCompanionCached then
		local AIC = handle:GetAIControllerComponent()
		local targetAttAgent = handle:GetAttitudeAgent()
		local reactionComp = handle.reactionComponent

		local aiRole = NewObject('handle:AIRole')
		aiRole:OnRoleSet(handle)

		handle.isPlayerCompanionCached = false
		handle.isPlayerCompanionCachedTimeStamp = 0

    senseComponent.RequestMainPresetChange(handle, "Neutral")

    local currentRole = AIC:GetCurrentRole()
		if currentRole then currentRole:OnRoleCleared(handle) end
    
		AIC:SetAIRole(aiRole)
		handle.movePolicies:Toggle(true)
  else
    AMM.Spawn:SetNPCAsCompanion(handle)
  end
end

-- Not working
function Util:TriggerCombatAgainst(handle, target)
  local reactionComp = handle.reactionComponent
  handle:GetAttitudeAgent():SetAttitudeTowards(target:GetAttitudeAgent(), Enum.new("EAIAttitude", "AIA_Hostile"))
  reactionComp:TriggerCombat(target)
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

function Util:RestoreElevator(handle)
  if handle and handle:IsExactlyA("ElevatorFloorTerminal") then
    for _, parent in ipairs(handle:GetDevicePS():GetImmediateParents()) do
      if parent and parent:IsExactlyA("LiftControllerPS") then
        parent:TurnAuthorizationModuleOFF()
        parent:ForceEnableDevice()
        parent:ForceDeviceON()

        for _, elevatorPS in ipairs(parent:GetImmediateSlaves()) do
            if elevatorPS and elevatorPS:IsExactlyA("ElevatorFloorTerminalControllerPS") then
                elevatorPS:PowerDevice()
                elevatorPS:ForceDeviceON()
                elevatorPS:ForceEnableDevice()
                elevatorPS:TurnAuthorizationModuleOFF()
            end
        end

        for i = 0, #parent:GetFloors() do
            local actionShowFloor = parent:ActionQuestShowFloor()
            local actionActiveFloor = parent:ActionQuestSetFloorActive()

            actionShowFloor:SetProperties(i)
            actionActiveFloor:SetProperties(i)

            Game.GetPersistencySystem():QueuePSDeviceEvent(actionShowFloor)
            Game.GetPersistencySystem():QueuePSDeviceEvent(actionActiveFloor)
        end

        parent:ForceEnableDevice()
        parent:ForceDeviceON()
        parent:WakeUpDevice()
      end
    end
  end
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
    vehPS:OpenAllRegularVehDoors(false)
  elseif state == "Open" then
    vehPS:CloseAllVehDoors(false)
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
      handle:TurnVehicleOn(true)  
  else
      handle:TurnVehicleOn(false)
  end
end

function Util:GetMountedVehicleTarget()
  local vehicle = nil
  local qm = AMM.player:GetQuickSlotsManager()
  vehicle = qm:GetVehicleObject()

  if vehicle then
    return AMM:NewTarget(vehicle, 'vehicle', AMM:GetScanID(vehicle), AMM:GetVehicleName(vehicle),AMM:GetScanAppearance(vehicle), AMM:GetAppearanceOptions(vehicle))
  end

  return nil
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

function Util:CheckNibblesByID(id)
  local possibleIDs = {
    "0xA1166EF4, 34"
  }

  for _, possibleID in ipairs(possibleIDs) do
    if id == possibleID then return true end
  end

  return false
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

function Util:IsCustomWorkspot(handle)
  return handle:FindComponentByName("amm_marker")
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
  local canBeHostile = TweakDB:GetRecord(t.path):AbilitiesContains(TweakDBInterface.GetGameplayAbilityRecord("Ability.CanCloseCombat"))
	if not(canBeHostile) then
		canBeHostile = TweakDB:GetRecord(t.path):AbilitiesContains(TweakDBInterface.GetGameplayAbilityRecord("Ability.HasChargeJump"))
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

    local target = Game.GetTargetingSystem():GetLookAtObject(AMM.player, true, false) or Game.GetTargetingSystem():GetLookAtObject(AMM.player, false, false)
    if target then action(target) end
  end
end

return Util
