Entity = {}

function Entity:new(ent)
  local obj = {}

  -- Entity Properties
  obj.handle = ent.handle
  obj.name = ent.name
  obj.id = ent.id
  obj.hash = ent.hash
  obj.path = ent.path
  obj.rig = ent.rig
  obj.template = ent.template or nil
  obj.entityID = ent.entityID
  obj.uid = ent.uid or nil
  obj.appearance = ent.appearance
  obj.options = ent.options or nil
  obj.uniqueName = function()
    if ent.uniqueName then
      return ent.uniqueName()
    end

    return nil
  end
  obj.type = ent.type
  obj.archetype = ent.archetype
  obj.parameters = ent.parameters
  obj.canBeCompanion = ent.canBeCompanion or false
  obj.tag = ent.tag or nil
  obj.mappinData = ent.mappinData or nil
  obj.spawned = ent.spawned or false

  obj.pos = ent.pos or Entity:GetPosition()
  obj.angles = ent.angles or Entity:GetAngles()
  obj.scale = ent.scale or nil

  obj.isVehicle = ent.isVehicle or false

  -- Poses Properties
  obj.anim = nil

  -- Movement Controller Properties
  obj.speed = ent.speed or 0.1
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

  obj.rollModifier = false
  obj.pitchModifier = false
  obj.resetAngles = false

  obj.analogForward = 0
  obj.analogBackwards = 0
  obj.analogRight = 0
  obj.analogLeft = 0
  obj.analogUp = 0
  obj.analogDown = 0

  self.__index = self
  return setmetatable(obj, self)
end

function Entity:GetPosition()
  if self.handle then
    return self.handle:GetWorldPosition()
  end
end

function Entity:GetAngles()
  if self.handle then
    local angles = self.handle:GetWorldOrientation():ToEulerAngles()
    return {roll = angles.roll, pitch = angles.pitch, yaw = angles.yaw}
  end
end

function Entity:Despawn()
  -- Handle AMM Object
  if AMM.Tools.directMode then
    AMM.Tools:CheckIfDirectModeShouldBeDisabled(self.hash)
  end

  if AMM.Poses.activeAnims[self.hash] then
    AMM.Poses:StopAnimation(AMM.Poses.activeAnims[self.hash])
  end

  if self.type == "NPCPuppet" or self.type == "Spawn" then
    AMM.Spawn:DespawnNPC(self)
  elseif self.type == "Prop" or self.type == "entEntity" then
    AMM.Props:DespawnProp(self)
  end

  -- Handle Game Entity
  self.handle:Dispose()

  local entity = Game.FindEntityByID(self.handle:GetEntityID())
  if entity then
    entity:GetEntity():Destroy()
  end

  self = nil
end

-- function Entity:Spawn()
--   local spawnTransform = AMM.player:GetWorldTransform()
--   local pos = AMM.player:GetWorldPosition()
--   local heading = AMM.player:GetWorldForward()
--   local frontPlayer = Vector4.new(pos.x + heading.x, pos.y + heading.y, pos.z + 1.5, pos.w)
--   spawnTransform:SetPosition(frontPlayer)

--   self.entityID = exEntitySpawner.Spawn(self.path, spawnTransform, '')

-- 	Cron.Every(0.1, {tick = 1}, function(timer)
-- 		local entity = Game.FindEntityByID(self.entityID)
--     timer.tick = timer.tick + 1
-- 		if entity then
-- 			self.handle = entity
--       self.hash = tostring(entity:GetEntityID().hash)
--       self.component = entity:FindComponentByName("Entity")
--       Cron.Halt(timer)
-- 		elseif timer.tick > 20 then
-- 			Cron.Halt(timer)
-- 		end
--   end)
-- end

-- Original code by keanuWheeze
function Entity:HandleInput(actionName, actionType, action)
  local relevantInputs = {
    MoveX = true,
    MoveY = true,
    UI_MoveUp = true,
    UI_MoveDown = true,
    UI_MoveLeft = true,
    UI_MoveRight = true,
    CameraX = true,
  }

  if actionName == "MoveX" or actionName == "PhotoMode_CameraMovementX" then -- Controller movement
    local x = action:GetValue(action)
    if x < 0 then
        self.currentDirections.left = true
        self.currentDirections.right = false
        self.analogRight = 0
        self.analogLeft = -x
    else
        self.currentDirections.right = true
        self.currentDirections.left = false
        self.analogRight = x
        self.analogLeft = 0
    end
    if x == 0 then
        self.currentDirections.right = false
        self.currentDirections.left = false
        self.analogRight = 0
        self.analogLeft = 0
    end
  elseif actionName == "MoveY" or actionName == "PhotoMode_CameraMovementY" then
    local x = action:GetValue(action)
    if x < 0 then
        self.currentDirections.backwards = true
        self.currentDirections.forward = false
        self.analogForward = 0
        self.analogBackwards = -x
    else
        self.currentDirections.backwards = false
        self.currentDirections.forward = true
        self.analogForward = x
        self.analogBackwards = 0
    end
    if x == 0 then
        self.currentDirections.backwards = false
        self.currentDirections.forward = false
        self.analogForward = 0
        self.analogBackwards = 0        
    end
  elseif actionName == 'UI_MoveUp' or (actionName == "CameraY" or actionName == "PhotoMode_CraneUp") and actionType == "AXIS_CHANGE" then
    local z = action:GetValue(action)
    if z < 0 then
      self.currentDirections.up = false
      self.currentDirections.down = true
      self.analogUp = 0
      self.analogDown = -z
    else
      self.currentDirections.up = true
      self.currentDirections.down = false
      self.analogUp = z
      self.analogDown = 0
    end
    if z == 0 or actionType == 'BUTTON_RELEASED' then
        self.analogUp = 0
        self.currentDirections.up = false
    end
  elseif actionName == 'UI_MoveDown' or (actionName == "CameraY" or actionName == "PhotoMode_CraneDown") and actionType == "AXIS_CHANGE" then
    local z = action:GetValue(action)
    if z == 0 or actionType == 'BUTTON_RELEASED' then
        self.analogDown = 0
        self.currentDirections.down = false
    else
        self.currentDirections.down = true
        self.analogDown = z
    end
  end

  if actionName == 'Forward' then
    if actionType == 'BUTTON_PRESSED' then
        self.currentDirections.forward = true
        self.analogForward = 1
    elseif actionType == 'BUTTON_RELEASED' then
        self.currentDirections.forward = false
        self.analogForward = 0
    end
  elseif actionName == 'Back' then
    if actionType == 'BUTTON_PRESSED' then
        self.currentDirections.backwards = true
        self.analogBackwards = 1
    elseif actionType == 'BUTTON_RELEASED' then
        self.currentDirections.backwards = false
        self.analogBackwards = 0
    end
  elseif actionName == 'Right' then
    if actionType == 'BUTTON_PRESSED' then
        self.currentDirections.right = true
        self.analogRight = 1
    elseif actionType == 'BUTTON_RELEASED' then
        self.currentDirections.right = false
        self.analogRight = 0
    end
  elseif actionName == 'Left' then
    if actionType == 'BUTTON_PRESSED' then
        self.currentDirections.left = true
        self.analogLeft = 1
    elseif actionType == 'BUTTON_RELEASED' then
        self.currentDirections.left = false
        self.analogLeft = 0
    end
  elseif actionName == "CameraX" and actionType == 'AXIS_CHANGE' then
    if action:GetValue(action) < -0.3 then
        self.currentDirections.rotateRight = true
    elseif action:GetValue(action) > 0.3 then
      self.currentDirections.rotateLeft = true
    elseif action:GetValue(action) == 0 then
        self.currentDirections.rotateRight = false
        self.currentDirections.rotateLeft = false
    end
  elseif actionName == "ToggleSprint" or (actionName == "right_trigger" and actionType == 'AXIS_CHANGE') then
    if action:GetValue(action) > 0 then
      self.rollModifier = true
    elseif action:GetValue(action) == 0 then
      self.rollModifier = false
    end
  elseif actionName == 'UI_MoveRight' or actionName == "PhotoMode_Next_Menu" then
    if actionType == 'BUTTON_PRESSED' then
        self.currentDirections.rotateRight = true
    elseif actionType == 'BUTTON_RELEASED' then
        self.currentDirections.rotateRight = false
    end
  elseif actionName == 'UI_MoveLeft' or actionName == "PhotoMode_Prior_Menu" then
    if actionType == 'BUTTON_PRESSED' then
        self.currentDirections.rotateLeft = true
    elseif actionType == 'BUTTON_RELEASED' then
        self.currentDirections.rotateLeft = false
    end
  elseif actionName == 'TagButton' or actionName == "controller_settings" then
    if actionType == 'BUTTON_PRESSED' then
        self.resetAngles = true
    elseif actionType == 'BUTTON_RELEASED' then
        self.resetAngles = false
    end
  end

  self.isMoving = false
  for _, v in pairs(self.currentDirections) do
    if v == true then
        self.isMoving = true
    end
  end

  if not self.isMoving and relevantInputs[actionName] and AMM.Poses.activeAnims[self.hash] then    
    local anim = AMM.Poses.activeAnims[self.hash]
    AMM.Poses:RestartAnimation(anim)
  end
end

function Entity:Move()
  if self.handle then
    local newPos = self.pos or self.handle:GetWorldPosition()
    local rot = self.angles

    if rot == nil then
      self.angles = self:GetAngles()
      rot = self.angles
    end

    for directionKey, state in pairs(self.currentDirections) do
      if state == true then
        self:CalculateNewPos(directionKey, newPos, rot)
      end
    end

    if self.resetAngles then
      self.angles = EulerAngles.new(0, 0, 0)
    end
  
    if self.type ~= "Player" and self.handle:IsNPC() and self.isMoving then
      self.pos = newPos
      self.angles = rot
      Util:TeleportNPCTo(self.handle, self.pos, rot.yaw)  
    else
      Game.GetTeleportationFacility():Teleport(self.handle, newPos, EulerAngles.new(rot.roll, rot.pitch, rot.yaw))
    end
  end
end

function Entity:SetMovementSpeed(v)
  self.speed = v
end

function Entity:CalculateNewPos(direction, newPos, rot)
  local speed = self.speed
  local dir

  if direction == "forward" then
    speed = speed * self.analogForward
  elseif direction == "backwards" then
    speed = speed * self.analogBackwards
  elseif direction == "right" then
    speed = speed * self.analogRight
  elseif direction == "left" then
    speed = speed * self.analogLeft
  elseif direction == "up" then
    speed = speed * self.analogUp
  elseif direction == "down" then
    speed = speed * self.analogDown
  end

  if direction == "forward" or direction == "backwards" then
    dir = Game.GetPlayer():GetWorldForward()
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
    if self.rollModifier then
      rot.pitch = rot.pitch + (100 * speed)
    else
      newPos.z = newPos.z + (0.7 * speed)
    end
  elseif direction == "down" then
    if self.rollModifier then
      rot.pitch = rot.pitch - (100 * speed)
    else
      newPos.z = newPos.z - (0.7 * speed)
    end    
  end
    
  if direction == "rotateLeft" then
    if self.handle then
      if self.rollModifier then
        rot.roll = rot.roll - (100 * speed)
      else
        rot.yaw = rot.yaw - (100 * speed)
      end
    end
  elseif direction == "rotateRight" then
    if self.handle then
      if self.rollModifier then
        rot.roll = rot.roll + (100 * speed)
      else
        rot.yaw = rot.yaw + (100 * speed)
      end
    end
  end
end

function Entity:StartListeners()
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

return Entity
