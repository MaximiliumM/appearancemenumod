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

-- Function to compare two strings for sorting
local function compareStrings(a, b)
  return a < b
end

function Util:ClearTable(tbl)
  local filteredTable = {}
	for key, value in pairs(tbl) do
		if value ~= nil then
			filteredTable[key] = value
		end
	end
  return filteredTable
end

function Util:SortTableAlphabetically(tbl)
  return table.sort(tbl, compareStrings)
end

function Util:IsPrefix(s1, s2)
  return string.sub(s2, 1, string.len(s1)) == s1
end

function Util:GetPrefix(s)
  local i = string.find(s, "_")
  if i then
      return string.sub(s, 1, i-1)
  else
      return s
  end
end

-- Calculate delay based on framerate
function Util:CalculateDelay(base)
  local currentFPS = 1 / AMM.deltaTime
  local targetFPS = 30
  local baseDelay = base
  local maxDelay = base + 10

  -- Calculate the scaling factor
  local scalingFactor = 0.2 -- You can adjust this factor based on your preference

  -- Calculate the adjusted delay
  local adjustedDelay = baseDelay + (currentFPS - targetFPS) * scalingFactor

  -- Ensure the delay is not lower than base delay
  if adjustedDelay < base then
      adjustedDelay = base

  -- Ensure the delay isn't too high
  elseif adjustedDelay > maxDelay then
    adjustedDelay = maxDelay
  end

  return adjustedDelay
end

function Util:FirstToUpper(str)
  return (str:gsub("^%l", string.upper))
end

function Util:StringMatch(s1, s2)
  local len1, len2 = #s1, #s2
  local matrix = {}
  for i = 0, len1 do
      matrix[i] = {[0] = i}
  end
  for j = 0, len2 do
      matrix[0][j] = j
  end
  for i = 1, len1 do
      for j = 1, len2 do
          local cost = s1:sub(i,i) == s2:sub(j,j) and 0 or 1
          matrix[i][j] = math.min(
              matrix[i-1][j] + 1,
              matrix[i][j-1] + 1,
              matrix[i-1][j-1] + cost
          )
      end
  end
  return matrix[len1][len2]
end

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

function Util:CheckIfTableHasValue(tbl, value)
  for k, v in ipairs(tbl) do -- iterate table (for sequential tables only)
    if v == value or (type(v) == "table" and hasValue(v, value)) then -- Compare value from the table directly with the value we are looking for, otherwise if the value is table, check its content for this value.
        return true -- Found in this or nested table
    end
  end
  return false -- Not found
end

function Util:ReverseTable(tab)
  local n, m = #tab, #tab/2
  for i=1, m do
    tab[i], tab[n-i+1] = tab[n-i+1], tab[i]
  end
  return tab
end

function Util:ConcatTables(t1, t2)
  for i=1,#t2 do
      t1[#t1+1] = t2[i]
  end  
  return t1
end

function Util:GetTableKeys(tab)
  local keyset = {}
  for k,v in pairs(tab) do
    keyset[#keyset + 1] = k
  end
  return keyset
end

function Util:GetKeysCount(t)
  local count = 0
  for k, v in pairs(t) do
      count = count + 1
  end
  return count
end

function Util:Split(s, delimiter)
  local result = {}
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match)
  end
  return result
end

function Util:ParseSearch(query, column)
  local words = Util:Split(query, " ")
  local r = ""
  for i, word in ipairs(words) do
      r = r..string.format('%s LIKE "%%%s%%"', column, word)
      if i ~= #words then r = r..' AND ' end
  end
  return r, query
end

function Util:GetPosString(pos, angles)
  local posString = f("{x = %f, y = %f, z = %f, w = %f}", pos.x, pos.y, pos.z, pos.w)
  if angles then
    posString = f("{x = %f, y = %f, z = %f, w = %f, roll = %f, pitch = %f, yaw = %f}", pos.x, pos.y, pos.z, pos.w, angles.roll, angles.pitch, angles.yaw)
  end

  return posString
end

function Util:GetPosFromString(posString)
  local pos = loadstring("return "..posString, '')() or { x=0, y=0, z=0, w=0 }
  return Vector4.new(pos.x, pos.y, pos.z, pos.w)
end

function Util:GetAnglesFromString(posString)
  local pos = loadstring("return "..posString, '')()
  return EulerAngles.new(pos.roll, pos.pitch, pos.yaw)
end

-- Game Related Helpers
function Util:GetDirection(angle)
  return Vector4.RotateAxis(Game.GetPlayer():GetWorldForward(), Vector4.new(0, 0, 1, 0), angle / 180.0 * Pi())
end

function Util:GetPosition(distance, angle)
  local pos = Game.GetPlayer():GetWorldPosition()
  local heading = Util:GetDirection(angle)
  return Vector4.new(pos.x + (heading.x * distance), pos.y + (heading.y * distance), pos.z + heading.z, pos.w + heading.w)
end

function Util:GetOrientation(angle)
  return EulerAngles.ToQuat(Vector4.ToRotation(Util:GetDirection(angle)))
end

function Util:ModStatPlayer(stat, value)
  StrikeExecutor_ModifyStat.new():ModStatPuppet(Game.GetPlayer(), gamedataStatType[stat], StringToFloat(value, 0), Game.GetPlayer())
end

function Util:InfiniteStamina(enable)
  local mod = StatPoolModifier.new()
  local playerID = Game.GetPlayer():GetEntityID()
  local statPoolSys = Game.GetStatPoolsSystem()
  if enable then
    mod.enabled = true
    mod.rangeBegin = 0.00
    mod.rangeEnd = 100.00
    mod.delayOnChange = false
    mod.valuePerSec = 1000000000.00
    statPoolSys:RequestSettingModifier(playerID, gamedataStatPoolType.Stamina, gameStatPoolModificationTypes.Regeneration, mod)
  else
    statPoolSys:RequestResetingModifier(playerID, gamedataStatPoolType.Stamina, gameStatPoolModificationTypes.Regeneration)
  end
end

function Util:AddToInventory(item)
  local equipRequest = EquipRequest.new()
  local itemID = ItemID.FromTDBID(TweakDBID.new(item))
  local quantity = 1

  Game.GetTransactionSystem():GiveItem(Game.GetPlayer(), itemID, quantity)
  equipRequest.owner = Game.GetPlayer()
  Game.GetScriptableSystemsContainer():Get("EquipmentSystem"):QueueRequest(equipRequest)
end

function Util:FreezePlayer()
  local player = Game.GetPlayer()
  if not player then return end

  local pos = player:GetWorldPosition()
  local angles = player:GetWorldOrientation():ToEulerAngles()

  Game.GetTeleportationFacility():Teleport(player, pos, angles)
end

function Util:ApplyEffectOnPlayer(effect)
  local player = Game.GetPlayer()
  if not player then return end

  local effectID = TweakDBID.new(effect)
  Game.GetStatusEffectSystem():ApplyStatusEffect(player:GetEntityID(), effectID, player:GetRecordID(), player:GetEntityID())
end

function Util:RemoveEffectOnPlayer(effect)
  local player = Game.GetPlayer()
  if not player then return end
  
  local effectID = TweakDBID.new(effect)
  Game.GetStatusEffectSystem():RemoveStatusEffect(player:GetEntityID(), effectID, 999)
end

function Util:AddPlayerEffects()
  Util:ApplyEffectOnPlayer("GameplayRestriction.NoMovement")
  Util:ApplyEffectOnPlayer("GameplayRestriction.NoCameraControl")
  Util:ApplyEffectOnPlayer("GameplayRestriction.NoZooming")
  Util:ApplyEffectOnPlayer("GameplayRestriction.FastForwardCrouchLock")
  Util:ApplyEffectOnPlayer("GameplayRestriction.NoCombat")
  Util:ApplyEffectOnPlayer("GameplayRestriction.VehicleNoSummoning")
  Util:ApplyEffectOnPlayer("GameplayRestriction.NoPhone")
end

function Util:RemovePlayerEffects()
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoMovement")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoCameraControl")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoZooming")
  Util:RemoveEffectOnPlayer("GameplayRestriction.FastForwardCrouchLock")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoCombat")
  Util:RemoveEffectOnPlayer("GameplayRestriction.VehicleNoSummoning")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoPhone")
end

function Util:GetPlayerGender()
  playerBodyGender = playerBodyGender or Game.GetPlayer():GetResolvedGenderName()
  return (string.find(tostring(playerBodyGender), "Female") and "_Female") or "_Male"
end

function Util:PlayVoiceOver(handle, vo)
  Game["gameObject::PlayVoiceOver;GameObjectCNameCNameFloatEntityIDBool"](handle, CName.new(vo), CName.new(""), 1, handle:GetEntityID(), true)
end

function Util:VectorDistance(pointA, pointB)
  return math.sqrt(((pointA.x - pointB.x)^2) + ((pointA.y - pointB.y)^2) + ((pointA.z - pointB.z)^2))
end

function Util:CheckIfCommandIsActive(handle, cmd)
  return AIActiveCommandList.IsActionCommandById(handle:GetAIControllerComponent().activeCommands, cmd.id)
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

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)
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
    lookAtEvent:SetEntityTarget(target and target.handle or Game.GetPlayer(), "pla_default_tgt", Vector4.new(0,0,0,0))
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

function Util:SetHostileRole(targetPuppet)
  local AIRole = AIRole.new()
		
  targetPuppet:GetAIControllerComponent():SetAIRole(AIRole)
  targetPuppet:GetAIControllerComponent():OnAttach()

  targetPuppet:GetAttitudeAgent():SetAttitudeGroup('Hostile')
  targetPuppet:GetAttitudeAgent():SetAttitudeTowards(Game.GetPlayer():GetAttitudeAgent(), EAIAttitude.AIA_Hostile)

  for _, ent in pairs(Spawn.spawnedNPCs) do
    if ent.handle.IsNPC and ent.handle:IsNPC() then
      ent.handle:GetAttitudeAgent():SetAttitudeTowards(targetPuppet:GetAttitudeAgent(), EAIAttitude.AIA_Hostile)
    end
  end

  targetPuppet.isPlayerCompanionCached = false
  targetPuppet.isPlayerCompanionCachedTimeStamp = 0
  
  local sensePreset = TweakDBInterface.GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive"))
  targetPuppet.reactionComponent:SetReactionPreset(sensePreset)
  targetPuppet.reactionComponent:TriggerCombat(Game.GetPlayer())
end

function Util:ToggleCompanion(ent)
  local handle = ent.handle
  local currentRole = handle:GetAIControllerComponent():GetAIRole()

  if handle.isPlayerCompanionCached and currentRole:IsA('AIFollowerRole') then
    if handle:IsCrowd() then
      AMM.Spawn:Respawn(ent, true) -- Crowd NPCs can't change roles more than once; Respawn as non companion instead.
    else
      currentRole:OnRoleCleared(handle)

      local noRole = AINoRole.new()
      AIHumanComponent.SetCurrentRole(handle, noRole)

      local sensePreset = handle:GetRecord():SensePreset():GetID()
      SenseComponent.RequestPresetChange(handle, sensePreset, true)

      handle.isPlayerCompanionCached = false
      handle.isPlayerCompanionCachedTimeStamp = 0
    end
  else
    AMM.Spawn:SetNPCAsCompanion(handle)
  end
end

function Util:TriggerCombatAgainst(handle, target)
  target:GetAttitudeAgent():SetAttitudeTowards(Game.GetPlayer():GetAttitudeAgent(), EAIAttitude.AIA_Hostile)
  handle:GetAttitudeAgent():SetAttitudeTowards(target:GetAttitudeAgent(), EAIAttitude.AIA_Hostile)
  local sensePreset = TweakDBInterface.GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive"))
  handle.reactionComponent:SetReactionPreset(sensePreset)
  handle.reactionComponent:TriggerCombat(target)
  target.reactionComponent:TriggerCombat(Game.GetPlayer())
  target:GetAttitudeAgent():SetAttitudeTowards(handle:GetAttitudeAgent(), EAIAttitude.AIA_Hostile)
  target.reactionComponent:TriggerCombat(handle)
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
  if handle.Dispose then
    handle:Dispose()
  end
  if handle.GetEntity then
		handle:GetEntity():Destroy()
	end


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

function Util:ToggleDoorLock(handle)
  local handlePS = handle:GetDevicePS()

  if handlePS:IsSealed() then handlePS:ToggleSealOnDoor() end
  
  handlePS:ToggleLockOnDoor()

  if not handlePS:IsLocked() then
    handle:OpenDoor()
  end
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

function Util:ToggleDoor(vehPS, doorName, open)
  open = not open
  local doorEvent = VehicleDoorOpen.new()
  if not open then doorEvent = VehicleDoorClose.new() end

  doorEvent.slotID = doorName
  doorEvent.forceScene = false
  vehPS:QueuePSEvent(vehPS, doorEvent)
end

function Util:GetDoorState(handle, doorEnum)
  local vehPS = handle:GetVehiclePS()
  local state = vehPS:GetDoorState(doorEnum).value

  if state == "Closed" then
    return false
  elseif state == "Open" then
    return true
  end
end

function Util:GetWindowState(handle, doorEnum)
  local vehPS = handle:GetVehiclePS()
  local state = vehPS:GetWindowState(doorEnum).value

  if state == "Closed" then
    return false
  elseif state == "Open" then
    return true
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

function Util:ToggleWindow(vehPS, doorName, open)
  open = not open
  local doorEvent = VehicleWindowOpen.new()
  if not open then doorEvent = VehicleWindowClose.new() end

  doorEvent.slotID = doorName
  doorEvent.forceScene = false
  vehPS:QueuePSEvent(vehPS, doorEvent)
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

local possibleIDs = {
  ["0x2A16D43E, 34"] = true,
  ["0x9EDC71E0, 33"] = true,
  ["0x15982ADF, 28"] = true,
  ["0x451222BE, 24"] = true,
  ["0x9FFA2212, 29"] = true,
  ["0x382F94F4, 31"] = true,
  ["0x55C01D9F, 36"] = true,
  ["0xBD4D2E74, 21"] = true,
}

function Util:CheckVByID(id)
  return possibleIDs[id]
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
  local record = TweakDB:GetRecord(t.path)
  if record then
    local canBeHostile = record:AbilitiesContains(TweakDBInterface.GetGameplayAbilityRecord("Ability.CanCloseCombat"))
    if not(canBeHostile) then
      canBeHostile = record:AbilitiesContains(TweakDBInterface.GetGameplayAbilityRecord("Ability.HasChargeJump"))
    end

    return canBeHostile
  end

  return false
end

function Util:UnlockVehicle(handle)
  if handle and handle.GetVehiclePS then
	handle:GetVehiclePS():UnlockAllVehDoors()
  end
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
