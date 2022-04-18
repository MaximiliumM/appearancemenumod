Camera = {}

function Camera:new()
  local obj = {}

  -- Entity Properties
  obj.handle = nil
  obj.hash = nil
  obj.component = nil
  obj.fov = 60
  obj.zoom = 1
  obj.speed = 0.5
  obj.path = "base\\entities\\cameras\\simple_free_camera.ent"
  obj.mappinID = nil

  -- Main Properties
  obj.isMoving = false
  obj.currentDirections = {
    forward = false,
    backwards = false,
    right = false,
    left = false,
    up = false,
    down = false
  }

  obj.lastReload = 0
  obj.lastSprint = 0
  obj.lastToggled = 0
  obj.time = 0

  obj.analogForward = 0
  obj.analogBackwards = 0
  obj.analogRight = 0
  obj.analogLeft = 0
  obj.analogUp = 0
  obj.analogDown = 0

  self.__index = self
  return setmetatable(obj, self)
end

function Camera:Activate(blendTime)
  if self.handle then
    Game.ApplyEffectOnPlayer("GameplayRestriction.NoMovement")
    Game.ApplyEffectOnPlayer("GameplayRestriction.NoCameraControl")
    Game.ApplyEffectOnPlayer("GameplayRestriction.NoZooming")
    Game.ApplyEffectOnPlayer("GameplayRestriction.FastForwardCrouchLock")
    Game.ApplyEffectOnPlayer("GameplayRestriction.NoCombat")
    Game.ApplyEffectOnPlayer("GameplayRestriction.VehicleNoSummoning")
    Game.ApplyEffectOnPlayer("GameplayRestriction.NoPhone")

    if not AMM.playerInVehicle then
      AMM.Tools:ToggleHead()
    end

    self.component:Activate(blendTime, false)
  end
end

function Camera:Deactivate(blendTime)
  if self.handle then
    Game.RemoveEffectPlayer("GameplayRestriction.NoMovement")
    Game.RemoveEffectPlayer("GameplayRestriction.NoCameraControl")
    Game.RemoveEffectPlayer("GameplayRestriction.NoZooming")
    Game.RemoveEffectPlayer("GameplayRestriction.FastForwardCrouchLock")
    Game.RemoveEffectPlayer("GameplayRestriction.NoCombat")
    Game.RemoveEffectPlayer("GameplayRestriction.VehicleNoSummoning")
    Game.RemoveEffectPlayer("GameplayRestriction.NoPhone")
    
    if not AMM.playerInVehicle and AMM.Tools.tppHead then
      AMM.Tools:ToggleHead()
    end

    self.component:Deactivate(blendTime, false)
  end
end

function Camera:SetFOV(value)
  self.component:SetFOV(value)
  self.fov = value
end

function Camera:SetZoom(value)
  self.component:SetZoom(value)
  self.zoom = value
end

function Camera:Despawn()
  self:Deactivate(0)
  self.handle:Dispose()
end

function Camera:Spawn()
  local spawnTransform = AMM.player:GetWorldTransform()
  local pos = AMM.player:GetWorldPosition()
  local heading = AMM.player:GetWorldForward()
  local frontPlayer = Vector4.new(pos.x + heading.x, pos.y + heading.y, pos.z + 1.5, pos.w)
  spawnTransform:SetPosition(frontPlayer)

  self.entityID = exEntitySpawner.Spawn(self.path, spawnTransform, '')

	Cron.Every(0.1, {tick = 1}, function(timer)
		local entity = Game.FindEntityByID(self.entityID)
    timer.tick = timer.tick + 1
		if entity then
			self.handle = entity
      self.hash = tostring(entity:GetEntityID().hash)
      self.component = entity:FindComponentByName("camera")
      Cron.Halt(timer)
		elseif timer.tick > 20 then
			Cron.Halt(timer)
		end
  end)
end

-- Original code by keanuWheeze
function Camera:HandleInput(actionName, actionType, action)
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
  elseif (actionName == "right_trigger" or actionName == "PhotoMode_CraneUp") and actionType == "AXIS_CHANGE" then
    local z = action:GetValue(action)
    if z == 0 then
        self.analogUp = 0
        self.currentDirections.up = false
    else
        self.currentDirections.up = true
        self.analogUp = z
    end
  elseif (actionName == "left_trigger" or actionName == "PhotoMode_CraneDown") and actionType == "AXIS_CHANGE" then
    local z = action:GetValue(action)
    if z == 0 then
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
  end

  local rot = nil
  if actionName == "CameraMouseX" or actionName == "CameraX"
  or actionName == "PhotoMode_CameraMouseX" or actionName == "PhotoMode_CameraRotationX" then
    local x = action:GetValue(action)
    local factor = 0.5
    if actionName == "CameraMouseX" or actionName == "PhotoMode_CameraMouseX" then factor = 45 end

    if self.component then
      rot = self.component:GetLocalOrientation():ToEulerAngles() -- Get the local orientation of the cam
      rot.yaw = rot.yaw - (x / factor) -- Change its yaw
    end
  end
  if actionName == "CameraMouseY" or actionName == "CameraY"
  or actionName == "PhotoMode_CameraMouseY" or actionName == "PhotoMode_CameraRotationY" then
    local y = action:GetValue(action)
    local factor = 0.5
    if actionName == "CameraMouseY" or actionName == "PhotoMode_CameraMouseY" then factor = 45 end

    if self.component then
      rot = self.component:GetLocalOrientation():ToEulerAngles()      
      rot.pitch = rot.pitch + (y / factor)
    end
  end
  if actionName == "CameraMouseX" or actionName == "CameraMouseY"
  or actionName == "CameraY" or actionName == "CameraX" 
  or actionName == "PhotoMode_CameraMouseY" or actionName == "PhotoMode_CameraMouseX" 
  or actionName == "PhotoMode_CameraRotationX" or actionName == "PhotoMode_CameraRotationY" then
    if self.component then
      self.component:SetLocalOrientation(rot:ToQuat()) -- Set the local orientation
    end
  end

  self.isMoving = false
  for _, v in pairs(self.currentDirections) do
    if v == true then
        self.isMoving = true
    end
  end
end

function Camera:Move()
  local newPos = self.handle:GetWorldPosition()

  for directionKey, state in pairs(self.currentDirections) do
    if state == true then
      self:CalculateNewPos(directionKey, newPos)
    end
  end

  Game.GetTeleportationFacility():Teleport(self.handle, newPos, self.handle:GetWorldOrientation():ToEulerAngles())
end

function Camera:CalculateNewPos(direction, newPos)
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
    dir = Game.GetCameraSystem():GetActiveCameraForward()
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
    newPos.z = newPos.z + (0.7 * speed)
  elseif direction == "down" then
    newPos.z = newPos.z - (0.7 * speed)
  end
end

function Camera:StartListeners()
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

return Camera
