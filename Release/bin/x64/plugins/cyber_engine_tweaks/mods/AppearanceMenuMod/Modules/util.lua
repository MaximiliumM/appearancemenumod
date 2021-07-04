local Util = {
  openPopup = false,
  popup = {},
}

function Util:GetPlayerGender()
  -- True = Female / False = Male
  if string.find(tostring(Game.GetPlayer():GetResolvedGenderName()), "Female") then
		return "_Female"
	else
		return "_Male"
	end
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

function Util:PlayVoiceOver(handle, vo)
  Game["gameObject::PlayVoiceOver;GameObjectCNameCNameFloatEntityIDBool"](handle, CName.new(vo), CName.new(""), 1, handle:GetEntityID(), true)
end

function Util:VectorDistance(pointA, pointB)
  return math.sqrt(((pointA.x - pointB.x)^2) + ((pointA.y - pointB.y)^2) + ((pointA.z - pointB.z)^2))
end

function Util:CheckIfCommandIsActive(handle, cmd)
  return GetSingleton('AIbehaviorUniqueActiveCommandList'):IsActionCommandById(handle:GetAIControllerComponent().activeCommands, cmd.id)
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

function Util:HoldPosition(targetPuppet, duration)
	local holdCmd = NewObject('handle:AIHoldPositionCommand')
	holdCmd.duration = duration or 1.0
	holdCmd.ignoreInCombat = false
	holdCmd.removeAfterCombat = false
	holdCmd.alwaysUseStealth = false

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

	if immortal then
		gs:AddGodMode(entityID, Enum.new("gameGodModeType", "Invulnerable"), CName.new("Default"))
	else
    gs:ClearGodMode(entityID, CName.new("Default"))
    gs:AddGodMode(entityID, Enum.new("gameGodModeType", "Mortal"), CName.new("Default"))
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

  handle:DestructionResetGrid()
  handle:DestructionResetGlass()

  vehPS:RepairVehicle()
  vehVC:ForcePersistentStateChanged()
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

function Util:ToggleEngine(handle, state)
  local vehVC = handle:GetVehicleComponent()
  local vehVCPS = vehVC:GetVehicleControllerPS()

  if state then
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
    "0x15982ADF, 28",
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

return Util
