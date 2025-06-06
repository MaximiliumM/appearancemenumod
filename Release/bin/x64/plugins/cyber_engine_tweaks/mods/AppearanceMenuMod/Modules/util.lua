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

-------------------------------------------------------------------
-- This function fixes the 'position' column by:
--   1) Reading all rows in ascending order of 'position'.
--   2) Deleting them from the table.
--   3) Re-inserting them with new positions 0..(N-1),
--      removing duplicate entity_name rows.
--   4) Adjusting the sqlite_sequence so seq = N-1 for that table.
-------------------------------------------------------------------
function Util:FixPositionsForFavorites(tableName)
  -- Gather all rows, ordered by position ascending
  local rows = {}
  for row in db:nrows(string.format("SELECT * FROM %s ORDER BY position ASC", tableName)) do
      table.insert(rows, row)
  end

  -- We'll need to handle "favorites_swap" specially, because it has a different schema.
  local isSwap = (tableName == "favorites_swap")

  -- 1) Build a filtered list of rows without duplicates.
  --    We'll keep the first occurrence of a given entity_name (in ascending position order).
  local filtered = {}
  local seenNames = {}
  for _, row in ipairs(rows) do
      local nameKey = row.entity_name or ""  -- or use row.entity_id if you prefer
      if not seenNames[nameKey] then
          seenNames[nameKey] = true
          table.insert(filtered, row)
      else
          -- We've already seen this entity_name, so skip it (dupe removal).
      end
  end

  -- Rewrite the table in a single transaction
  db:execute("BEGIN TRANSACTION")

  -- 2) Delete all existing rows
  db:execute("DELETE FROM " .. tableName)

  -- 3) Re-insert them with normalized positions, skipping duplicates
  for newIndex, row in ipairs(filtered) do
      local normalizedPos = newIndex - 1

      local sql
      if isSwap then
          -- 'favorites_swap' has only (position, entity_id)
          sql = string.format([[
              INSERT INTO %s (position, entity_id)
              VALUES (%d, '%s')
          ]],
          tableName,
          normalizedPos,
          row.entity_id or "")
      else
          -- Normal favorites table
          -- Normalize the 'parameters' value
          local p = row.parameters or ""
          if p == "" or p == "nil" or p == "NULL" then
              -- Store as an actual SQL NULL (no quotes in VALUES)
              p = "NULL"
              sql = string.format([[
                  INSERT INTO %s (position, entity_id, entity_name, parameters)
                  VALUES (%d, '%s', '%s', %s)
              ]],
              tableName,
              normalizedPos,
              row.entity_id or "",
              row.entity_name or "",
              p)
          else
              -- Otherwise, use a quoted string
              sql = string.format([[
                  INSERT INTO %s (position, entity_id, entity_name, parameters)
                  VALUES (%d, '%s', '%s', '%s')
              ]],
              tableName,
              normalizedPos,
              row.entity_id or "",
              row.entity_name or "",
              p)
          end
      end

      -- Fix any literal "nil" => "NULL"
      sql = sql:gsub('"nil"', "NULL")
      db:execute(sql)
  end

  -- 4) Update the sqlite_sequence to match the new highest position
  local newSeq = #filtered - 1  -- if 8 rows => highest position is 7
  if newSeq < 0 then
      newSeq = 0  -- if empty table
  end
  db:execute(string.format(
      "UPDATE sqlite_sequence SET seq=%d WHERE name='%s'",
      newSeq, tableName
  ))

  db:execute("COMMIT")
end

-- Code Helper Methods
function Util:SelectRandomPair(tbl)
  local keys = {} -- Store all keys
  for key in pairs(tbl) do
      table.insert(keys, key)
  end

  -- Select a random key
  if #keys > 0 then
      local randomKey = keys[math.random(#keys)]
      return randomKey, tbl[randomKey] -- Return key and value
  else
      return nil, nil -- Return nil if the table is empty
  end
end

function Util:GenerateRandomSequence(maxNumber)
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
function Util:CalculateDelay(base, scalingFactor)
  local currentFPS = 1 / AMM.deltaTime
  local targetFPS = 60
  local baseDelay = base
  local maxDelay = base + 10
  scalingFactor = scalingFactor or 0.92 -- Default scaling factor

  -- Calculate the difference between current FPS and target FPS
  local fpsDelta = math.abs(currentFPS - targetFPS)

  -- Adjust the scaling effect to minimize sensitivity near the target FPS
  local adjustmentFactor = math.min(fpsDelta / targetFPS, 1) * scalingFactor

  -- Calculate the adjusted delay
  local adjustedDelay = baseDelay + (currentFPS < targetFPS and adjustmentFactor or -adjustmentFactor)

  -- Clamp the delay within bounds
  if adjustedDelay < base then
    adjustedDelay = base
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

-----------------------------------------------------------------------
-- A per-token partial credit function
-----------------------------------------------------------------------
function Util:DynamicTokenMatchScore(tokenA, tokenB)
  local dist   = Util:StringMatch(tokenA, tokenB)  -- e.g. Levenshtein
  local maxLen = math.max(#tokenA, #tokenB)

  -- If either token is very short, require an exact match
  if #tokenA <= 3 or #tokenB <= 3 then
    if dist == 0 then
      return 1.0
    else
      return 0.0
    end
  end

  -- For longer tokens, do partial credit
  local score = 1.0 - (dist / maxLen)
  if score < 0.0 then 
    score = 0.0
  end
  return score
end

-----------------------------------------------------------------------
-- A function that splits the string on both underscores and spaces,
-- then tries to match each token in A to its best token in B.
-----------------------------------------------------------------------
function Util:CompareStringsTokenWise(strA, strB)
  if (not strA or strA == "") or (not strB or strB == "") then
    return 0.0
  end

  -- 1) Lowercase
  local a = strA:lower()
  local b = strB:lower()

  -- 2) Replace underscores with spaces, split on spaces
  local function tokenize(input)
    input = input:gsub("_", " ")
    local tokens = {}
    for t in input:gmatch("%S+") do
      table.insert(tokens, t)
    end
    return tokens
  end

  local tokensA = tokenize(a)
  local tokensB = tokenize(b)
  if #tokensA == 0 or #tokensB == 0 then
    return 0.0
  end

  -- We'll attempt to match each A token to the best B token and remove it from the pool
  local poolB = {}
  for _, tB in ipairs(tokensB) do
    table.insert(poolB, tB)
  end

  local sumScore = 0.0
  local matchedCount = 0

  for _, tokenA in ipairs(tokensA) do
    local bestScore = 0.0
    local bestIdx   = nil
    for i, tokenB in ipairs(poolB) do
      local score = Util:DynamicTokenMatchScore(tokenA, tokenB)
      if score > bestScore then
        bestScore = score
        bestIdx   = i
      end
    end

    -- If bestIdx is found and bestScore>0, we have some partial credit
    if bestIdx and bestScore > 0 then
      sumScore = sumScore + bestScore
      matchedCount = matchedCount + 1
      table.remove(poolB, bestIdx)  -- consume the B token
    end
  end

  -- e.g. ratio = (2 * sumScore) / (|A| + |B|)
  -- but you could do (sumScore / math.max(#tokensA, #tokensB)) if you prefer.
  local denom = (#tokensA + #tokensB)
  if denom == 0 then
    return 0.0
  end

  local ratio = (2.0 * sumScore) / denom
  return ratio
end

function Util:DeepCopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[Util:DeepCopy(orig_key)] = Util:DeepCopy(orig_value)
    end
    setmetatable(copy, Util:DeepCopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
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
  -- Iterate over both array and dictionary style keys
  for _, v in pairs(tbl) do
    -- Direct match
    if v == value then
      return true
    end

    -- If the entry is a table, recurse into it
    if type(v) == "table" and Util:CheckIfTableHasValue(v, value) then
      return true
    end
  end

  return false
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
  Util:ApplyEffectOnPlayer("GameplayRestriction.NoDriving")
end

function Util:RemovePlayerEffects()
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoMovement")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoCameraControl")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoZooming")
  Util:RemoveEffectOnPlayer("GameplayRestriction.FastForwardCrouchLock")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoCombat")
  Util:RemoveEffectOnPlayer("GameplayRestriction.VehicleNoSummoning")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoPhone")
  Util:RemoveEffectOnPlayer("GameplayRestriction.NoDriving")
end

function Util:GetPlayerGender()
  local playerBodyGender = Game.GetPlayer():GetResolvedGenderName()
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
  handle:GetAIControllerComponent():StopExecutingCommand(cmd, true)
  return handle:GetAIControllerComponent():CancelCommand(cmd)
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

function Util:GetPlayerWeapon()
  local es = Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem"))
  return es:GetActiveWeaponObject(Game.GetPlayer(), 40)
end

function Util:EquipPrimaryWeaponCommand(targetPuppet)
  local cmd = NewObject("handle:AISwitchToPrimaryWeaponCommand")
  cmd.unEquip = false
  cmd = cmd:Copy()

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)

  return cmd, targetPuppet
end

function Util:EquipSecondaryWeaponCommand(targetPuppet)
  local cmd = NewObject("handle:AISwitchToSecondaryWeaponCommand")
  cmd.unEquip = false
  cmd = cmd:Copy()

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)

  return cmd, targetPuppet
end

function Util:EquipGivenWeapon(targetPuppet, weapon, override)
  local cmd = NewObject("AIEquipCommand")
  cmd.slotId = TweakDBID.new("AttachmentSlots.WeaponRight")
  cmd.itemId = weapon
  cmd.failIfItemNotFound = false
  cmd.durationOverride = 1

  cmd = cmd:Copy()

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)
end

function Util:FollowTarget(targetPuppet, target, distance, walkType)

  local cmd = NewObject('handle:AIFollowTargetCommand')
  cmd.desiredDistance = distance or 2
  cmd.matchSpeed = true
  cmd.stopWhenDestinationReached = false
  cmd.target = target
  cmd.movementType = walkType or "Walk"
  cmd.teleport = false
  cmd.tolerance = 2
  cmd.lookAtTarget = target

  targetPuppet:GetAIControllerComponent():SendCommand(cmd)

  return cmd, targetPuppet
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

function Util:RotateTo(targetPuppet, pos)

  local dest = NewObject('WorldPosition')
  dest:SetVector4(dest, pos or AMM.player:GetWorldPosition())
  
  local positionSpec = NewObject('AIPositionSpec')
  positionSpec:SetWorldPosition(positionSpec, dest)

  local cmd = NewObject('handle:AIRotateToCommand')
  cmd.target = positionSpec
  cmd.angleOffset = 50
  cmd.angleTolerance = 180
  cmd.speed = 1

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
      lookAtPartRequest.weight = headSettings.weight or 0
      lookAtPartRequest.suppress = headSettings.suppress or 1
      lookAtPartRequest.mode = 0
      table.insert(lookAtParts, lookAtPartRequest)
    end

    if chestSettings then
      local lookAtPartRequest = LookAtPartRequest.new()
      lookAtPartRequest.partName = "Chest"
      lookAtPartRequest.weight = chestSettings.weight or 0.1
      lookAtPartRequest.suppress = chestSettings.suppress or 0.5
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
    vehPS:OpenAllRegularVehDoors(true)
  elseif state == "Open" then
    vehPS:CloseAllVehDoors(true)
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

function Util:CheckForPhotoComponent(ent)
  if ent:FindComponentByName("PhotoModePlayerEntity") ~= nil then
    return true
  end

  return false
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
