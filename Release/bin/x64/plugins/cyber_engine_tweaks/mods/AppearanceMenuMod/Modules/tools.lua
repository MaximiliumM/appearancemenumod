local Tools = {
  -- Time Properties
  timeState = true,
  timeValue = nil,
  slowMotionSpeed = 1,
  slowMotionMaxValue = 1,

  -- Teleport Properties
  selectedLocation = {loc_name = "Select Location"},
  shareLocationName = '',
  userLocations = {},
  favoriteLocations = {},
}

-- ALIAS for string.format --
local f = string.format
local Util = require('Modules/util.lua')

function Tools:Draw(AMM, target)
  if ImGui.BeginTabItem("Tools") then

    Tools.userLocations = Tools:GetUserLocations()

    AMM.Theme:Spacing(3)

    AMM.Theme:TextColored("Teleport Actions:")

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

    if ImGui.Button("Teleport To Location", -1, 40) then
      Tools:TeleportToLocation(Tools.selectedLocation)
    end

    ImGui.Spacing()

    local isFavorite, favIndex = Tools:IsFavorite(Tools.selectedLocation)
    local favLabel = "Favorite Selected Location"
    if isFavorite then
      favLabel = "Unfavorite Selected Location"
    end

    if ImGui.Button(favLabel, -1, 40) then
      Tools:ToggleFavoriteLocation(isFavorite, favIndex)
    end

    ImGui.Spacing()

    if ImGui.Button("Share Current Location", -1, 40) then
      Tools:GetShareablePlayerLocation()
    end

    if ImGui.IsItemHovered() then
      ImGui.SetTooltip("User locations are saved in AppearanceMenuMod/User/Locations folder")
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

    AMM.Theme:Separator()

    AMM.Theme:TextColored("Time Actions:")

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
    if ImGui.Button(buttonLabel, -1, 40) then
      Tools:PauseTime()
    end

    if not Tools.timeState then
      ImGui.Spacing()
      if ImGui.Button("Skip Frame", -1, 40) then
        Tools:SkipFrame()
      end
    end

    if AMM.userSettings.experimental then

      AMM.Theme:Separator()

      AMM.Theme:TextColored("All NPCs Actions:")

      if ImGui.Button("All Friendly") then
        local entities = Tools:GetNPCsInRange(30)
        for _, ent in ipairs(entities) do
          Tools:SetNPCAttitude(ent, "friendly")
        end
      end

      ImGui.SameLine()
      if ImGui.Button("All Follower") then
        local entities = Tools:GetNPCsInRange(10)
        for _, ent in ipairs(entities) do
          AMM:SetNPCAsCompanion(ent.handle)
        end
      end

      ImGui.SameLine()
      if ImGui.Button("All Fake Die") then
        local entities = Tools:GetNPCsInRange(20)
        for _, ent in ipairs(entities) do
          ent.handle:SendAIDeathSignal()
        end
      end

      if ImGui.Button("All Die") then
        local entities = Tools:GetNPCsInRange(20)
        for _, ent in ipairs(entities) do
          ent.handle:Kill(ent.handle, false, false)
        end
      end

      ImGui.SameLine()
      if ImGui.Button("All Despawn") then
        local entities = Tools:GetNPCsInRange(20)
        for _, ent in ipairs(entities) do
          ent.handle:Dispose()
        end
      end

      ImGui.SameLine()
      if ImGui.Button("Cycle Appearance") then
        local entities = Tools:GetNPCsInRange(20)
        for _, ent in ipairs(entities) do
          AMM:ChangeScanAppearanceTo(ent, "Cycle")
        end
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

-- Teleport actions
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
  Game.GetTeleportationFacility():Teleport(Game.GetPlayer(), Vector4.new(loc.x, loc.y, loc.z, loc.w), EulerAngles.new(0, 0, loc.yaw))
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
        local x, y, z, w, yaw = Tools:LoadLocationData(loc.name)
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
    return locationData["x"], locationData["y"], locationData["z"], locationData["w"], locationData["yaw"]
  end
end

function Tools:SetLocationNamePopup()
	Tools.shareLocationName = ''
	ImGui.OpenPopup("Share Location")
end

-- NPC actions
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
function Tools:SetSlowMotionSpeed(c)
  Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(true)
  Game.SetTimeDilation(c == 0 and 0.0000000000001 or c)
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
