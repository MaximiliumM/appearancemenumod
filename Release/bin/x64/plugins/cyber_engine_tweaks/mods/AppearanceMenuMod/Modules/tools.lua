local Tools = {
  -- Style Property
  style = {},

  -- Time Properties
  timeState = true,
  timeValue = nil,
  slowMotionSpeed = 1,
  slowMotionMaxValue = 1,
  slowMotionToggle = false,

  -- Teleport Properties
  lastLocation = nil,
  selectedLocation = {loc_name = "Select Location"},
  shareLocationName = '',
  userLocations = {},
  favoriteLocations = {},
  useTeleportAnimation = false,
  isTeleporting = true,

  -- V Properties --
  playerVisibility = true,
  godModeToggle = false,
  makeupToggle = true,
  accessoryToggle = true,

  -- NPC Properties --
  protectedNPCs = {},
}

-- ALIAS for string.format --
local f = string.format
local Util = require('Modules/util.lua')

function Tools:Draw(AMM, target)
  if ImGui.BeginTabItem("Tools") then

    Tools.style = {
      buttonHeight = ImGui.GetFontSize() * 2,
      buttonWidth = -1,
      halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
    }

    if AMM.playerInMenu and not AMM.playerInPhoto then
      AMM.UI:TextColored("Player In Menu")
      ImGui.Text("Tools only works in game")
    elseif AMM.playerInPhoto then
      if target ~= nil and target.name == 'V' then
        Tools:DrawVActions()
      else
        AMM.UI:TextColored("Player In Photo Mode")
        ImGui.Text("Target V to see available actions")
      end
    else
      Tools:DrawTeleportActions()

      AMM.UI:Separator()

      Tools:DrawTimeActions()

      AMM.UI:Separator()

      Tools:DrawVActions()

      if AMM.userSettings.experimental then

        AMM.UI:Separator()

        Tools:DrawNPCActions()
      end

      if ImGui.InvisibleButton("Speed", 10, 30) then
        Tools.slowMotionMaxValue = 5
      end

      if ImGui.IsItemHovered() then
        ImGui.SetTooltip("What if I click here?")
      end
    end
    ImGui.EndTabItem()
  end
end

-- V actions
function Tools:DrawVActions()
  AMM.UI:TextColored("V Actions:")

  if AMM.playerInPhoto then
    if ImGui.Button("Toggle Makeup", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleMakeup(target)
    end

    ImGui.SameLine()
    if ImGui.Button("Toggle Piercings", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleAccessories(target)
    end
  else
    local buttonLabel = "Disable Invisibility"
    if Tools.playerVisibility then
      buttonLabel = "Enable Invisibility"
    end

    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleInvisibility()
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("Enemies will still attack you if you trigger combat")
    end

    local buttonLabel = "Enable God Mode"
    if Tools.godModeToggle then
      buttonLabel = "Disable God Mode"
    end

    ImGui.SameLine()
    if ImGui.Button(buttonLabel, Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
      Tools:ToggleGodMode()
    end
  end
end

function Tools:ToggleMakeup(target)
	Tools.makeupToggle = not Tools.makeupToggle

	local isFemale = Util:GetPlayerGender()
	if isFemale then gender = 'pwa' else gender = 'pma' end

	local makeup = target.handle:FindComponentByName(CName.new(f("hx_000_%s__basehead_makeup_lips_01", gender)))
	if makeup then makeup:Toggle(Tools.makeupToggle) end

	local makeup = target.handle:FindComponentByName(CName.new(f("hx_000_%s__basehead_makeup_eyes_01", gender)))
	if makeup then makeup:Toggle(Tools.makeupToggle) end
end

function Tools:ToggleAccessories(target)
  Tools.accessoryToggle = not Tools.accessoryToggle

  local isFemale = Util:GetPlayerGender()
	if isFemale then gender = 'pwa' else gender = 'pma' end

  for i = 1, 4 do
    local accessory = target.handle:FindComponentByName(CName.new(f("i1_000_%s__morphs_earring_0%i", gender, i)))
	   if accessory then accessory:Toggle(Tools.accessoryToggle) end
  end
end

function Tools:ToggleInvisibility()
  Game.GetPlayer():SetInvisible(Tools.playerVisibility)
  Game.GetPlayer():UpdateVisibility()
  Tools.playerVisibility = not Tools.playerVisibility
end

function Tools:CheckGodModeIsActive()
  -- Check if God Mode is active after reload all mods
  if Game.GetPlayer() ~= nil then
    local playerID = Game.GetPlayer():GetEntityID()
    local currentHP = Game.GetStatsSystem():GetStatValue(playerID, "Health")
    if currentHP < 0 then Tools.godModeToggle = true end
  end
end

function Tools:ToggleGodMode()
  -- Toggle God Mode
  Tools.godModeToggle = not Tools.godModeToggle

  if Tools.godModeToggle then
    hp, o2 = -99999, -999999
  else
    hp, o2 = 99999, 999999
  end

  -- Stat Modifiers
  Game.ModStatPlayer("Health", hp)
  Game.ModStatPlayer("Oxygen", o2)

  -- Toggles
  local toggle = boolToInt(Tools.godModeToggle)
  Game.InfiniteStamina(Tools.godModeToggle)
  Game.ModStatPlayer("KnockdownImmunity", toggle)
  Game.ModStatPlayer("PoisonImmunity", toggle)
  Game.ModStatPlayer("BurningImmunity", toggle)
  Game.ModStatPlayer("BlindImmunity", toggle)
  Game.ModStatPlayer("BleedingImmunity", toggle)
  Game.ModStatPlayer("FallDamageReduction", toggle)
  Game.ModStatPlayer("ElectrocuteImmunity", toggle)
  Game.ModStatPlayer("StunImmunity", toggle)
end

-- Teleport actions
function Tools:DrawTeleportActions()
  Tools.userLocations = Tools:GetUserLocations()

  AMM.UI:Spacing(3)

  AMM.UI:TextColored("Teleport Actions:")

  if ImGui.BeginCombo("Locations", Tools.selectedLocation.loc_name, ImGuiComboFlags.HeightLarge) then
    for i, location in ipairs(Tools:GetLocations()) do
      if ImGui.Selectable(location.loc_name.."##"..i, (location == Tools.selectedLocation.loc_name)) then
        if location.loc_name:match("%-%-%-%-") == nil then
          Tools.selectedLocation = location
        end
      end
    end
    ImGui.EndCombo()
  end

  ImGui.Spacing()

  if ImGui.Button("Teleport To Location", Tools.style.buttonWidth, Tools.style.buttonHeight) then
    Tools:TeleportToLocation(Tools.selectedLocation)
  end

  ImGui.Spacing()

  local isFavorite, favIndex = Tools:IsFavorite(Tools.selectedLocation)
  local favLabel = "Favorite Selected Location"
  if isFavorite then
    favLabel = "Unfavorite Selected Location"
  end

  if ImGui.Button(favLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
    Tools:ToggleFavoriteLocation(isFavorite, favIndex)
  end

  ImGui.Spacing()

  if ImGui.Button("Share Current Location", Tools.style.buttonWidth, Tools.style.buttonHeight) then
    Tools:GetShareablePlayerLocation()
  end

  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("User locations are saved in AppearanceMenuMod/User/Locations folder")
  end

  ImGui.Spacing()

  if Tools.lastLocation then
    if ImGui.Button("Go Back To Last Location", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:TeleportToLocation(Tools.lastLocation)
    end
  end

  if AMM.TeleportMod ~= '' then
    ImGui.Spacing()
    Tools.useTeleportAnimation, clicked = ImGui.Checkbox("Use Teleport Animation", Tools.useTeleportAnimation)
    if clicked then
      AMM.userSettings.teleportAnimation = Tools.useTeleportAnimation
      AMM:UpdateSettings()
    end
    ImGui.SameLine()
    AMM.UI:TextColored("by GTA Travel")
  end

  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
  ImGui.SetNextWindowSize(400, ImGui.GetFontSize() * 8)

  if ImGui.BeginPopupModal("Share Location") then
    local style = {
        buttonHeight = ImGui.GetFontSize() * 2,
        halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12)
    }

    if Tools.shareLocationName == 'existing' then
      ImGui.TextColored(1, 0.16, 0.13, 0.75, "Existing Name")

      if ImGui.Button("Ok", -1, style.buttonHeight) then
        Tools.shareLocationName = ''
      end
    else
      Tools.shareLocationName = ImGui.InputText("Name", Tools.shareLocationName, 30)

      if ImGui.Button("Save", style.halfButtonWidth + 8, style.buttonHeight) then
        if not(io.open(f("User/Locations/%s.json", Tools.shareLocationName), "r")) then
          local currentLocation = Tools:GetPlayerLocation()
          local newLoc = Tools:NewLocationData(Tools.shareLocationName, currentLocation)
          Tools:SaveLocation(newLoc)
          Tools.userLocations = Tools:GetUserLocations()
          Tools.shareLocationName = ''
          ImGui.CloseCurrentPopup()
        else
          Tools.shareLocationName = 'existing'
        end
      end

      ImGui.SameLine()
      if ImGui.Button("Cancel", style.halfButtonWidth + 8, style.buttonHeight) then
        Tools.shareLocationName = ''
        ImGui.CloseCurrentPopup()
      end
    end
    ImGui.EndPopup()
  end
end

function Tools:GetLocations()
  local separator = false
  local locations = {}

  if next(Tools.favoriteLocations) ~= nil then
    table.insert(locations, {loc_name = '--------- Favorites ----------'})

    for _, loc in ipairs(Tools.favoriteLocations) do
      table.insert(locations, loc)
    end

    separator = true
  end

  if next(Tools.userLocations) ~= nil then
    table.insert(locations, {loc_name = '------- User Locations -------'})

    for _, loc in ipairs(Tools.userLocations) do
      table.insert(locations, loc)
    end

    separator = true
  end

  if separator then
    table.insert(locations, {loc_name = '------------------------------'})
  end

  for loc in db:nrows("SELECT * FROM locations ORDER BY loc_name ASC") do
    table.insert(locations, loc)
  end
  return locations
end

function Tools:TeleportToLocation(loc)
  Tools.lastLocation = Tools:NewLocationData("Previous Location", Tools:GetPlayerLocation())

  if Tools.useTeleportAnimation then
    AMM.TeleportMod.api.requestTravel(Vector4.new(loc.x, loc.y, loc.z, loc.w))
  else
    Game.GetTeleportationFacility():Teleport(Game.GetPlayer(), Vector4.new(loc.x, loc.y, loc.z, loc.w), EulerAngles.new(0, 0, loc.yaw))
    AMM.Tools.isTeleporting = true
  end
end

function Tools:GetPlayerLocation()
  return { pos = Game.GetPlayer():GetWorldPosition(), yaw = Game.GetPlayer():GetWorldYaw() }
end

function Tools:GetShareablePlayerLocation()
  Tools:SetLocationNamePopup()
end

function Tools:NewLocationData(locationName, locationPosition)
  return {
    loc_name = locationName,
    x = locationPosition.pos.x,
    y = locationPosition.pos.y,
    z = locationPosition.pos.z,
    w = locationPosition.pos.w,
    yaw = locationPosition.yaw
  }
end

function Tools:SaveLocation(loc)
  local file = io.open(f("User/Locations/%s.json", loc.loc_name), "w")
  if file then
    local contents = json.encode(loc)
		file:write(contents)
		file:close()
  end
end

function Tools:ToggleFavoriteLocation(isFavorite, favIndex)
  if isFavorite then
    table.remove(Tools.favoriteLocations, favIndex)
  else
    table.insert(Tools.favoriteLocations, Tools.selectedLocation)
  end
end

function Tools:GetFavoriteLocations()
  return Tools.favoriteLocations
end

function Tools:IsFavorite(loc)
  for index, location in ipairs(Tools.favoriteLocations) do
    if location.loc_name == loc.loc_name then
      return true, index
    end
  end

  return false
end

function Tools:GetUserLocations()
  local files = dir("./User/Locations")
  local userLocations = {}
  if #Tools.userLocations ~= #files then
    for _, loc in ipairs(files) do
      if string.find(loc.name, '.json') then
        local loc_name, x, y, z, w, yaw = Tools:LoadLocationData(loc.name)
        table.insert(userLocations, {loc_name = loc.name:gsub(".json", ""), x = x, y = y, z = z, w = w, yaw = yaw})
      end
    end
    return userLocations
  else
    return Tools.userLocations
  end
end

function Tools:LoadLocationData(loc)
  local file = io.open('User/Locations/'..loc, 'r')
  if file then
    local contents = file:read( "*a" )
		local locationData = json.decode(contents)
    file:close()
    return locationData["loc_name"], locationData["x"], locationData["y"], locationData["z"], locationData["w"], locationData["yaw"]
  end
end

function Tools:SetLocationNamePopup()
	Tools.shareLocationName = ''
	ImGui.OpenPopup("Share Location")
end

-- NPC actions
function Tools:DrawNPCActions()
  AMM.UI:TextColored("All NPCs Actions:")

  AMM.UI:DrawCrossHair()

  if ImGui.Button("Protect NPC from Actions", Tools.style.buttonWidth, Tools.style.buttonHeight) then
    if target.handle:IsNPC() then
      Tools:ProtectTarget(target)
    end
  end

  if ImGui.Button("All Friendly", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
    local entities = Tools:GetNPCsInRange(30)
    for _, ent in ipairs(entities) do
      if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
        Tools:SetNPCAttitude(ent, "friendly")
      end
    end

    Tools:ClearProtected()
  end

  ImGui.SameLine()
  if ImGui.Button("All Follower", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
    local entities = Tools:GetNPCsInRange(10)
    for _, ent in ipairs(entities) do
      if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
        AMM:SetNPCAsCompanion(ent.handle)
      end
    end

    Tools:ClearProtected()
  end

  if ImGui.Button("All Fake Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
    local entities = Tools:GetNPCsInRange(20)
    for _, ent in ipairs(entities) do
      if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
        ent.handle:SendAIDeathSignal()
      end
    end

    Tools:ClearProtected()
  end

  ImGui.SameLine()
  if ImGui.Button("All Die", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
    local entities = Tools:GetNPCsInRange(20)
    for _, ent in ipairs(entities) do
      if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
        ent.handle:Kill(ent.handle, false, false)
      end
    end

    Tools:ClearProtected()
  end

  if ImGui.Button("All Despawn", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
    local entities = Tools:GetNPCsInRange(20)
    for _, ent in ipairs(entities) do
      if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
        ent.handle:Dispose()
      end
    end

    Tools:ClearProtected()
  end

  ImGui.SameLine()
  if ImGui.Button("Cycle Appearance", Tools.style.halfButtonWidth, Tools.style.buttonHeight) then
    local entities = Tools:GetNPCsInRange(20)
    for _, ent in ipairs(entities) do
      if Tools.protectedNPCs[ent.handle:GetEntityID().hash] == nil then
        AMM:ChangeScanAppearanceTo(ent, "Cycle")
      end
    end

    Tools:ClearProtected()
  end
end

function Tools:ProtectTarget(t)
  local mappinData = NewObject('gamemappinsMappinData')
  mappinData.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
  mappinData.variant = Enum.new('gamedataMappinVariant', 'QuestGiverVariant')
  mappinData.visibleThroughWalls = true

  local slot = CName.new('poi_mappin')
  local offset = ToVector3{ x = 0, y = 0, z = 2 } -- Move the pin a bit up relative to the target

  local newMappinID = Game.GetMappinSystem():RegisterMappinWithObject(mappinData, t.handle, slot, offset)
  Tools.protectedNPCs[target.handle:GetEntityID().hash] = newMappinID
end

function Tools:ClearProtected()
  for _, mappinID in pairs(Tools.protectedNPCs) do
    Game.GetMappinSystem():UnregisterMappin(mappinID)
  end

  Tools.protectedNPCs = {}
end

function Tools:SetNPCAttitude(entity, attitude)
	local entAttAgent = entity.handle:GetAttitudeAgent()
	entAttAgent:SetAttitudeGroup(CName.new(attitude))
end

function Tools:GetNPCsInRange(maxDistance)
	local searchQuery = Game["TSQ_NPC;"]()
	searchQuery.maxDistance = maxDistance
	local success, parts = Game.GetTargetingSystem():GetTargetParts(Game.GetPlayer(), searchQuery, {})
	if success then
		local entities = {}
		for i, v in ipairs(parts) do
			local entity = v:GetComponent(v):GetEntity()
			entity = AMM:NewTarget(entity, "NPC", AMM:GetScanID(entity), AMM:GetNPCName(entity),AMM:GetScanAppearance(entity), AMM:GetAppearanceOptions(entity))
	    table.insert(entities, entity)
	  end

		return entities
	end
end

-- Time actions
function Tools:DrawTimeActions()
  AMM.UI:TextColored("Time Actions:")

  if Tools.timeValue == nil then
    Tools.timeValue = Tools:GetCurrentHour()
  end

  Tools.timeValue, changeTimeUsed = ImGui.SliderInt("Time of Day", Tools.timeValue, 0, 23)
  if changeTimeUsed then
    Tools:SetTime(Tools.timeValue)
  end

  Tools.slowMotionSpeed, slowMotionUsed = ImGui.SliderFloat("Slow Motion", Tools.slowMotionSpeed, 0.000001, Tools.slowMotionMaxValue)
  if slowMotionUsed then
    Tools:SetSlowMotionSpeed(Tools.slowMotionSpeed)
  end

  local buttonLabel = "Unfreeze Time"
  if Tools.timeState then
    buttonLabel = "Freeze Time"
  end

  ImGui.Spacing()
  if ImGui.Button(buttonLabel, Tools.style.buttonWidth, Tools.style.buttonHeight) then
    Tools:PauseTime()
  end

  if not Tools.timeState then
    ImGui.Spacing()
    if ImGui.Button("Skip Frame", Tools.style.buttonWidth, Tools.style.buttonHeight) then
      Tools:SkipFrame()
    end
  end
end

function Tools:SetSlowMotionSpeed(c)
  Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(c == 1 and false or true)
  if c == 0 then c = 0.0000000000001 elseif c == 1 then c = 0 end
  Game.SetTimeDilation(c)
end

function Tools:SkipFrame()
  Tools:PauseTime()
  AMM.skipFrame = true
end

function Tools:PauseTime()
  if Tools.timeState then
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(true)
    Game.SetTimeDilation(0.0000000000001)
  else
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(false)
    Game.SetTimeDilation(0)
    Tools.slowMotionSpeed = 1
  end

  Tools.timeState = not Tools.timeState
end

function Tools:GetCurrentHour()
  local currentGameTime = Game.GetTimeSystem():GetGameTime()
  return currentGameTime:Hours(currentGameTime)
end

function Tools:SetTime(hour)
  Game.GetTimeSystem():SetGameTimeByHMS(hour, 0, 0)
end

Tools.userLocations = Tools:GetUserLocations()

return Tools
