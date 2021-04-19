local Util = {}

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
  Game["gameObject::PlayVoiceOver;GameObjectCNameCNameFloatEntityIDBool"](handle, CName.new(vo), CName.new(""), 1)
end

function Util:VectorDistance(pointA, pointB)
  return math.sqrt(((pointA.x - pointB.x)^2) + ((pointA.y - pointB.y)^2) + ((pointA.z - pointB.z)^2))
end

function Util:CheckIfCommandIsActive(handle, cmd)
  return GetSingleton('AIbehaviorUniqueActiveCommandList'):IsActionCommandById(handle:GetAIControllerComponent().activeCommands, cmd.id)
end

function Util:TeleportNPCTo(targetPuppet, targetPosition, targetRotation)
  local pos = Game.GetPlayer():GetWorldPosition()
  local heading = Game.GetPlayer():GetWorldForward()
  local playerFront = Vector4.new(pos.x + heading.x, pos.y + heading.y, pos.z + heading.z, pos.w + heading.w)
	local teleportCmd = NewObject('handle:AITeleportCommand')
	teleportCmd.position = targetPosition or playerFront
	teleportCmd.rotation = targetRotation or 0.0
	teleportCmd.doNavTest = false

	targetPuppet:GetAIControllerComponent():SendCommand(teleportCmd)

	return teleportCmd, targetPuppet
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
	local success, parts = Game.GetTargetingSystem():GetTargetParts(Game.GetPlayer(), searchQuery, {})
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
    vehPS:SetHasExploded(true)
  end
  handle:Dispose()
end

return Util
