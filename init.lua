-- Begin of AMM Class

AMM = {
	description = "",
}

-- ALIAS for string.format --
f = string.format

-- Load Util Module Globally --
Util = require('Modules/util.lua')

-- Load External Modules --
GameSettings = require('External/GameSettings.lua')
GameSession = require('External/GameSession.lua')
Cron = require('External/Cron.lua')

function intToBool(value)
	return value > 0 and true or false
end

function boolToInt(value)
  return value and 1 or 0
end

function AMM:new()

   setmetatable(AMM, self)
	 self.__index = self

	 -- Load Debug --
	 if io.open("Debug/debug.lua", "r") then
		 AMM.Debug = require("Debug/debug.lua")
	 else
		 AMM.Debug = ''
	 end

	 -- Themes Properties --
	 AMM.UI = require('Themes/ui.lua')
	 AMM.Editor = require('Themes/editor.lua')
	 AMM.selectedTheme = 'Default'

	 -- Load Modules --
	 AMM.Scan = require('Modules/scan.lua')
	 AMM.Swap = require('Modules/swap.lua')
	 AMM.Tools = require('Modules/tools.lua')

	 -- External Mods API --
	 AMM.TeleportMod = ''

	 -- Main Properties --
	 AMM.currentVersion = "1.8.3"
	 AMM.updateNotes = require('update_notes.lua')
	 AMM.userSettings = AMM:PrepareSettings()
	 AMM.categories = AMM:GetCategories()
	 AMM.currentTarget = ''
	 AMM.spawnedNPCs = {}
	 AMM.entitiesForRespawn = ''
	 AMM.allowedNPCs = AMM:GetSaveables()
	 AMM.searchQuery = ''
	 AMM.searchBarWidth = 500
	 AMM.equipmentOptions = AMM:GetEquipmentOptions()
	 AMM.originalVehicles = ''
	 AMM.skipFrame = false

	 -- Custom Appearance Properties --
	 AMM.setCustomApp = ''
	 AMM.activeCustomApps = {}

	 -- Modal Popup Properties --
	 AMM.currentFavoriteName = ''
	 AMM.popupEntity = ''

	 -- Configs --
	 AMM.playerAttached = false
	 AMM.playerInMenu = true
	 AMM.playerInPhoto = false
	 AMM.settings = false
	 AMM.currentSpawn = ''
	 AMM.maxSpawns = 5
	 AMM.spawnsCounter = 0
	 AMM.spawnAsCompanion = true
	 AMM.isCompanionInvulnerable = true
	 AMM.shouldCheckSavedAppearance = true

	 registerForEvent("onInit", function()
		 waitTimer = 0.0
		 spamTimer = 0.0
		 respawnTimer = 0.0
		 buttonPressed = false
		 respawnAllPressed = false
		 finishedUpdate = AMM:CheckDBVersion()
		 AMM:ImportUserData()
		 AMM:SetupVehicleData()
		 AMM:SetupJohnny()

		 -- Check if user is in-game using WorldPosition --
		 -- Only way to set player attached if user reload all mods --
		 if Game.GetPlayer() then
			 local playerPosition = Game.GetPlayer():GetWorldPosition()
			 if math.floor(playerPosition.z) ~= 0 then
				 AMM.playerAttached = true
				 AMM.playerInMenu = false
			 end
		 end

		 -- Setup GameSession --
		 GameSession.OnStart(function()
			 AMM.playerAttached = true
			 AMM.playerInMenu = false

			 AMM.Tools:CheckGodModeIsActive()

			 if next(AMM.spawnedNPCs) ~= nil then
			 	AMM:RespawnAll()
			 end
		 end)

		 GameSession.OnEnd(function()
			 AMM.playerAttached = false
			 AMM.playerInMenu = true
		 end)

		 GameSession.Listen(function(state)
			 	if state.isLoaded then
					AMM.playerAttached = true
				end

				if state.isPaused then
					AMM.playerInMenu = true
				elseif state.wasPaused then
					AMM.playerInMenu = false
				end
     end)

		 -- Setup Cron to Export User data every 10 minutes --
		 Cron.Every(600, function()
			 AMM:ExportUserData()
		 end)

		 -- Setup Travel Mod API --
		 local mod = GetMod("gtaTravel")
		 if mod ~= nil then
			 AMM.TeleportMod = mod
			 AMM.Tools.useTeleportAnimation = AMM.userSettings.teleportAnimation
		 end

		 -- Setup Observers --
		 Observe("PlayerPuppet", "OnAction", function(action)
		   local actionName = Game.NameToString(action:GetName(action))
       local actionType = action:GetType(action).value

       if actionName == 'TogglePhotoMode' then
	        if actionType == 'BUTTON_RELEASED' then
					 AMM.playerInMenu = true
					 AMM.playerInPhoto = true
	         AMM.Tools:SetSlowMotionSpeed(1)
					end
			 elseif actionName == 'ExitPhotoMode' then
				 if actionType == 'BUTTON_RELEASED' then
					 AMM.Tools.makeupToggle = true
					 AMM.Tools.accessoryToggle = true
					 AMM.playerInMenu = false
					 AMM.playerInPhoto = false
					 local c = AMM.Tools.slowMotionSpeed
					 if c ~= 1 then
						 AMM.Tools:SetSlowMotionSpeed(c)
					 else
						 if AMM.Tools.timeState == false then
           		 AMM.Tools:SetSlowMotionSpeed(0)
						 else
							 AMM.Tools:SetSlowMotionSpeed(1)
						 end
					 end
         end
       end
		 end)

		 Observe("PlayerPuppet", "OnGameAttached", function(self)
			 AMM.activeCustomApps = {}

			 -- Disable God mode if previously active
			 AMM.Tools.godModeToggle = false

			 -- Disable Invisiblity if previously active
			 AMM.Tools.playerVisibility = true

			 if next(AMM.spawnedNPCs) ~= nil then
			 	AMM:RespawnAll()
			 end
		 end)
	 end)

	 registerForEvent("onShutdown", function()
		 AMM:ExportUserData()
		 -- AMM:RevertTweakDBChanges(false)
	 end)

	 -- Keybinds
	 registerHotkey("amm_open_overlay", "Open Appearance Menu", function()
	 	drawWindow = not drawWindow
	 end)

	 registerHotkey("amm_cycle", "Cycle Appearance", function()
		local target = AMM:GetTarget()
		if target ~= nil then
			waitTimer = 0.0
			AMM.shouldCheckSavedAppearance = false
			AMM:ChangeScanAppearanceTo(target, 'Cycle')
		end
	 end)

	 registerHotkey("amm_save", "Save Appearance", function()
		local target = AMM:GetTarget()
 		if target ~= nil then
			if AMM:ShouldDrawSaveButton(target) then
 				AMM:SaveAppearance(target)
			end
 		end
	 end)

	 registerHotkey("amm_clear", "Clear Appearance", function()
		local target = AMM:GetTarget()
		if target ~= nil then
			AMM:ClearSavedAppearance(target)
		end
	 end)

	 registerHotkey("amm_spawn_target", "Spawn Target", function()
		local target = AMM:GetTarget()
		if target ~= nil and target.handle:IsNPC() then
			local spawnableID = AMM:IsSpawnable(target)

			if spawnableID ~= nil then
				target.handle:Dispose()

				local spawn = nil
				for ent in db:nrows(f("SELECT * FROM entities WHERE entity_id = '%s'", spawnableID)) do
					spawn = AMM:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path)
				end

				if spawn ~= nil then
					AMM:SpawnNPC(spawn)
				end
			end
		end
	 end)

	 registerHotkey("amm_respawn_all", "Respawn All", function()
		buttonPressed = true
	 	AMM:RespawnAll()
	 end)

	 registerHotkey("amm_npc_talk", "NPC Talk", function()
		local target = AMM:GetTarget()
 		if target ~= nil and target.handle:IsNPC() then
	 		target.handle:GetStimReactionComponent():TriggerFacialLookAtReaction(false, true)
		end
	 end)

	 registerHotkey("amm_slow_time", "Slow Time", function()
		AMM.Tools.slowMotionToggle = not AMM.Tools.slowMotionToggle
		if AMM.Tools.slowMotionToggle then
	 		AMM.Tools:SetSlowMotionSpeed(0.1)
		else
			AMM.Tools:SetSlowMotionSpeed(0.0)
		end
	 end)

	 registerHotkey("amm_freeze_time", "Freeze Time", function()
	 	AMM.Tools:PauseTime()
	 end)

	 registerHotkey("amm_skip_frame", "Skip Frame", function()
	 	AMM.Tools:SkipFrame()
	 end)

	 registerHotkey('amm_toggle_hud', 'Toggle HUD', function()
	    GameSettings.Toggle('/interface/hud/action_buttons')
	    GameSettings.Toggle('/interface/hud/activity_log')
	    GameSettings.Toggle('/interface/hud/ammo_counter')
	    GameSettings.Toggle('/interface/hud/chatters')
	    GameSettings.Toggle('/interface/hud/healthbar')
	    GameSettings.Toggle('/interface/hud/input_hints')
	    GameSettings.Toggle('/interface/hud/johnny_hud')
	    GameSettings.Toggle('/interface/hud/minimap')
	    GameSettings.Toggle('/interface/hud/npc_healthbar')
	    GameSettings.Toggle('/interface/hud/quest_tracker')
	    GameSettings.Toggle('/interface/hud/stamina_oxygen')
	 end)

	 registerForEvent("onUpdate", function(deltaTime)
		 -- This is required for Cron to function
     Cron.Update(deltaTime)

		 if AMM.playerAttached and not(AMM.playerInMenu) then
				if finishedUpdate and Game.GetPlayer() ~= nil then
			 		-- Load Saved Appearance --
			 		if not drawWindow and AMM.shouldCheckSavedAppearance then
			 			target = AMM:GetTarget()
			 			AMM:CheckSavedAppearance(target)
			 		elseif AMM.shouldCheckSavedAppearance == false then
						waitTimer = waitTimer + deltaTime

						if waitTimer > 8 then
							waitTimer = 0.0
							AMM.shouldCheckSavedAppearance = true
						end
					end

					-- Travel Animation Done Check --
					if AMM.TeleportMod ~= '' and AMM.TeleportMod.api.done then
						if next(AMM.spawnedNPCs) ~= nil then
							AMM:RespawnAll()
						end
						AMM.TeleportMod.api.done = false
					end

					-- Regular Teleport Wait Timer --
					if AMM.Tools.isTeleporting then
						waitTimer = waitTimer + deltaTime

						if waitTimer > 8 then
							waitTimer = 0.0
							AMM.Tools.isTeleporting = false
							if next(AMM.spawnedNPCs) ~= nil then
					      AMM:RespawnAll()
					    end
						end
					end


					-- Tools Skip Frame Logic --
					if AMM.skipFrame then
						waitTimer = waitTimer + deltaTime

						if waitTimer > 0.01 then
							AMM.skipFrame = false
							AMM.Tools:PauseTime()
							waitTimer = 0.0
						end
					end

					-- Button Spamming Block --
					if buttonPressed then
						spamTimer = spamTimer + deltaTime

						if spamTimer > 0.5 then
							buttonPressed = false
							spamTimer = 0.0
						end
					end

					-- Respawn All Logic --
					if respawnAllPressed then
						if AMM.entitiesForRespawn == '' then
							AMM.entitiesForRespawn = {}
							for _, ent in pairs(AMM.spawnedNPCs) do
								table.insert(AMM.entitiesForRespawn, ent)
							end

							AMM:DespawnAll(buttonPressed)
							if buttonPressed then buttonPressed = false end
						else
							if waitTimer == 0.0 then
								respawnTimer = respawnTimer + deltaTime
							end

							if respawnTimer > 0.5 then
								empty = true
								for _, ent in ipairs(AMM.entitiesForRespawn) do
									if Game.FindEntityByID(ent.entityID) then empty = false end
								end

								if empty then
									ent = AMM.entitiesForRespawn[1]
									table.remove(AMM.entitiesForRespawn, 1)
									AMM:SpawnNPC(ent)
									respawnTimer = 0.0
								end

								if #AMM.entitiesForRespawn == 0 then
									AMM.entitiesForRespawn = ''
									respawnAllPressed = false
								end
							end
						end
					end

					-- After Custom Appearance Set --
					if AMM.setCustomApp ~= '' then
						waitTimer = waitTimer + deltaTime
						if waitTimer > 0.1 then
							local handle, customAppearance = AMM.setCustomApp[1], AMM.setCustomApp[2]
							local currentAppearance = AMM:GetScanAppearance(handle)
							if currentAppearance == customAppearance[1].app_base then
								for _, param in ipairs(customAppearance) do
									local appParam = handle:FindComponentByName(CName.new(param.app_param))
									if appParam then
										appParam:TemporaryHide(param.app_toggle)
									end
								end

								waitTimer = 0.0
								AMM.setCustomApp = ''
							end
						end
					end


					-- After Spawn Logic --
					if AMM.currentSpawn ~= '' then
						waitTimer = waitTimer + deltaTime
						-- print('trying to set companion')
						if waitTimer > 0.2 then
							local handle
							if AMM.spawnedNPCs[AMM.currentSpawn] ~= nil and string.find(AMM.spawnedNPCs[AMM.currentSpawn].path, "Vehicle") then
								handle = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(), false, false)
							elseif AMM.spawnedNPCs[AMM.currentSpawn] ~= nil then
								handle = Game.FindEntityByID(AMM.spawnedNPCs[AMM.currentSpawn].entityID)
							end
							if handle then
								AMM.spawnedNPCs[AMM.currentSpawn].handle = handle
								if handle:IsNPC() then
									if AMM.spawnedNPCs[AMM.currentSpawn].parameters ~= nil then
										if AMM.spawnedNPCs[AMM.currentSpawn].parameters == "special__vr_tutorial_ma_dummy_light" then -- Extra Handling for Johnny
											AMM:ChangeScanCustomAppearanceTo(AMM.spawnedNPCs[AMM.currentSpawn], AMM:GetCustomAppearanceParams('silverhand_default'))
										else
											AMM:ChangeScanAppearanceTo(AMM.spawnedNPCs[AMM.currentSpawn], AMM.spawnedNPCs[AMM.currentSpawn].parameters)
										end
									end
									if AMM.spawnAsCompanion and AMM.spawnedNPCs[AMM.currentSpawn].canBeCompanion then
										AMM:SetNPCAsCompanion(handle)
									else
										AMM.currentSpawn = ''
									end
								elseif handle:IsVehicle() then
									AMM:UnlockVehicle(handle)
									waitTimer = 0.0
									AMM.currentSpawn = ''
								else
									AMM.currentSpawn = ''
								end
							end
						end
					else
						AMM.currentSpawn = ''
					end
				end
			end
	 end)

	 registerForEvent("onOverlayOpen", function()
		 if AMM.userSettings.openWithOverlay then drawWindow = true end
	 end)

	 registerForEvent("onOverlayClose", function()
		 drawWindow = false
	 end)

	 registerForEvent("onDraw", function()

	 	ImGui.SetNextWindowPos(500, 500, ImGuiCond.FirstUseEver)

	 	if drawWindow then
			-- Load Theme --
			if AMM.UI.currentTheme ~= AMM.selectedTheme then
				AMM.UI:Load(AMM.selectedTheme)
			end

			AMM.UI:Start()

			if AMM.Debug == '' then
				pcall(function()
					AMM:Begin()
				end)
			else
				AMM:Begin()
			end
	 	end
	end)

   return AMM
end

-- Running On Draw
function AMM:Begin()
	local shouldResize = ImGuiWindowFlags.AlwaysAutoResize
	if not(AMM.userSettings.autoResizing) then
		shouldResize = ImGuiWindowFlags.None
	end

	if ImGui.Begin("Appearance Menu Mod", shouldResize) then

		if (not(finishedUpdate) or AMM.playerAttached == false) then
			local updateLabel = "WHAT'S NEW"

			if finishedUpdate and AMM.playerAttached == false then
				AMM.UI:TextColored("Player In Menu")
				ImGui.Text("AMM only functions in game")
				AMM.UI:Separator()
				updateLabel = 'UPDATE HISTORY'
			end

			-- UPDATE NOTES
			AMM.UI:Spacing(8)
			AMM.UI:TextCenter(updateLabel, true)
			AMM.UI:Separator()

			for i, versionArray in ipairs(AMM.updateNotes) do
				local treeNode = ImGui.TreeNodeEx(versionArray[1], ImGuiTreeNodeFlags.DefaultOpen + ImGuiTreeNodeFlags.NoTreePushOnOpen + ImGuiTreeNodeFlags.Framed)
				local releaseDate = versionArray[2]
				local dateLength = ImGui.CalcTextSize(releaseDate)
				ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - dateLength)
				AMM.UI:TextColored(releaseDate)

				if treeNode then
					for j, note in ipairs(versionArray) do
						if j == 1 or j == 2 then else
							local color = "ButtonActive"
							if note:match("%-%-") == nil then
								AMM.UI:Spacing(4)
								AMM.UI:TextColored("+ ")
								color = nil
							else
								note = note:gsub('%-%- ', '')
								ImGui.Dummy(20, 20)
								ImGui.SameLine()
								AMM.UI:TextColored('--')
							end

							ImGui.SameLine()
							ImGui.PushTextWrapPos(500)
							if color then AMM.UI:TextWrappedWithColor(note, color)
							else ImGui.TextWrapped(note) end
							ImGui.PopTextWrapPos()
							AMM.UI:Spacing(3)
						end
					end

					if i == 1 then
						if not(finishedUpdate) then
							AMM.UI:Separator()
							AMM.UI:Spacing(4)
							if ImGui.Button("Cool!", ImGui.GetWindowContentRegionWidth(), 40) then
								AMM:FinishUpdate()
							end
							AMM.UI:Separator()
						end
					end
				end
			end
		else
			-- Target Setup --
			target = AMM:GetTarget()

			if ImGui.BeginTabBar("TABS") then
				local style = {
		        buttonWidth = ImGui.GetFontSize() * 20.7,
		        buttonHeight = ImGui.GetFontSize() * 2,
		        halfButtonWidth = (ImGui.GetFontSize() * 20) / 2
		    }

				-- Scan Tab --
				AMM.Scan:Draw(AMM, target, style)

				-- Spawn Tab --
				if (ImGui.BeginTabItem("Spawn")) then

					if AMM.playerInMenu then
						AMM.UI:TextColored("Player In Menu")
						ImGui.Text("Spawning only works in game")
					else
						if next(AMM.spawnedNPCs) ~= nil then
							AMM.UI:TextColored("Active NPC Spawns "..AMM.spawnsCounter.."/"..AMM.maxSpawns)

							for _, spawn in pairs(AMM.spawnedNPCs) do
								local nameLabel = spawn.name
								ImGui.Text(nameLabel)

								-- Spawned NPC Actions --
								local favoritesLabels = {"Favorite", "Unfavorite"}
								AMM:DrawFavoritesButton(favoritesLabels, spawn)

								ImGui.SameLine()
								if spawn.handle ~= '' and not(spawn.handle:IsVehicle()) then
									if ImGui.SmallButton("Respawn##"..spawn.name) then
										AMM:DespawnNPC(spawn.uniqueName(), spawn.entityID)
										AMM:SpawnNPC(spawn)
									end
								end

								ImGui.SameLine()
								if ImGui.SmallButton("Despawn##"..spawn.name) then
									if spawn.handle ~= '' and spawn.handle:IsVehicle() then
										AMM:DespawnVehicle(spawn)
									else
										AMM:DespawnNPC(spawn.uniqueName(), spawn.entityID)
									end
								end

								if spawn.handle ~= '' and not(spawn.handle:IsVehicle()) and not(spawn.handle:IsDead()) and AMM:CanBeHostile(spawn.handle) then

									local hostileButtonLabel = "Hostile"
									if not(spawn.handle.isPlayerCompanionCached) then
										hostileButtonLabel = "Friendly"
									end

									ImGui.SameLine()
									if ImGui.SmallButton(hostileButtonLabel.."##"..spawn.name) then
										AMM:ToggleHostile(spawn)
									end

									ImGui.SameLine()
									if ImGui.SmallButton("Equipment".."##"..spawn.name) then
										popupDelegate = AMM:OpenPopup(spawn.name.."'s Equipment")
									end

									AMM:BeginPopup(spawn.name.."'s Equipment", spawn.path, false, popupDelegate, style)
								end
							end

							AMM.UI:Separator()
						end

						ImGui.PushItemWidth(AMM.searchBarWidth)
						AMM.searchQuery = ImGui.InputTextWithHint(" ", "Search", AMM.searchQuery, 100)
						ImGui.PopItemWidth()

						if AMM.searchQuery ~= '' then
							ImGui.SameLine()
							if ImGui.Button("Clear") then
								AMM.searchQuery = ''
							end
						end

						ImGui.Spacing()

						AMM.UI:TextColored("Select To Spawn:")

						if AMM.searchQuery ~= '' then
							local entities = {}
							local query = 'SELECT * FROM entities WHERE is_spawnable = 1 AND entity_name LIKE "%'..AMM.searchQuery..'%" ORDER BY entity_name ASC'
							for en in db:nrows(query) do
								table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path})
							end

							if #entities ~= 0 then
								AMM:DrawEntitiesButtons(entities, 'ALL', style)
							else
								ImGui.Text("No Results")
							end
						else
							local x, y = GetDisplayResolution()
							if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y / 2) then
								for _, category in ipairs(AMM.categories) do
									if(ImGui.CollapsingHeader(category.cat_name)) then
										local entities = {}
										if category.cat_name == 'Favorites' then
											local query = "SELECT * FROM favorites"
											for fav in db:nrows(query) do
												query = f("SELECT * FROM entities WHERE entity_id = '%s'", fav.entity_id)
												for en in db:nrows(query) do
													if fav.parameters ~= nil then en.parameters = fav.parameters end
													table.insert(entities, {fav.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path})
												end
											end
											if #entities == 0 then
												ImGui.Text("It's empty :(")
											end
										end

										local query = f("SELECT * FROM entities WHERE is_spawnable = 1 AND cat_id == '%s' ORDER BY entity_name ASC", category.cat_id)
										for en in db:nrows(query) do
											table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path})
										end

										AMM:DrawEntitiesButtons(entities, category.cat_name, style)
									end
								end
							end
							ImGui.EndChild()
						end
					end

					ImGui.EndTabItem()
				end

				-- Swap Tab --
				if AMM.userSettings.experimental then
					AMM.Swap:Draw(AMM, target)
				end

				-- Tools Tab --
				AMM.Tools:Draw(AMM, target)

				-- Settings Tab --
				if (ImGui.BeginTabItem("Settings")) then

					ImGui.Spacing()

					AMM.spawnAsCompanion = ImGui.Checkbox("Spawn As Companion", AMM.spawnAsCompanion)
					AMM.isCompanionInvulnerable = ImGui.Checkbox("Invulnerable Companion", AMM.isCompanionInvulnerable)
					AMM.userSettings.openWithOverlay, clicked = ImGui.Checkbox("Open With CET Overlay", AMM.userSettings.openWithOverlay)
					AMM.userSettings.autoResizing, clicked = ImGui.Checkbox("Auto-Resizing Window", AMM.userSettings.autoResizing)
					AMM.userSettings.scanningReticle, clicked = ImGui.Checkbox("Scanning Reticle", AMM.userSettings.scanningReticle)
					AMM.userSettings.experimental, expClicked = ImGui.Checkbox("Experimental/Fun stuff", AMM.userSettings.experimental)

					if AMM.userSettings.experimental then
						ImGui.PushItemWidth(139)
						AMM.maxSpawns = ImGui.InputInt("Max Spawns", AMM.maxSpawns, 1)
						ImGui.PopItemWidth()
					end

					if clicked then AMM:UpdateSettings() end

					if expClicked then
						AMM:UpdateSettings()
						AMM.categories = AMM:GetCategories()

						if AMM.userSettings.experimental then
							popupDelegate = AMM:OpenPopup("Experimental")
						end
					end

					AMM.UI:Separator()

					if AMM.userSettings.experimental then
						if (ImGui.Button("Revert All Model Swaps")) then
							AMM:RevertTweakDBChanges(true)
						end

						ImGui.SameLine()
						if (ImGui.Button("Respawn All")) then
							AMM:RespawnAll()
						end
					end


					if (ImGui.Button("Force Despawn All")) then
						AMM:DespawnAll(true)
					end

					if (ImGui.Button("Clear All Saved Appearances")) then
						popupDelegate = AMM:OpenPopup("Appearances")
					end

					if (ImGui.Button("Clear All Favorites")) then
						popupDelegate = AMM:OpenPopup("Favorites")
					end

					AMM:BeginPopup("WARNING", nil, true, popupDelegate, style)

					AMM.UI:Separator()

					if AMM.settings then
						if ImGui.BeginListBox("Themes") then
							for _, theme in ipairs(AMM.UI.userThemes) do
								if (AMM.selectedTheme == theme.name) then selected = true else selected = false end
								if(ImGui.Selectable(theme.name, selected)) then
									AMM.selectedTheme = theme.name
								end
							end
						end

						ImGui.EndListBox()

						if ImGui.SmallButton("  Create Theme  ") then
							AMM.Editor:Setup()
							AMM.Editor.isEditing = true
						end

						-- ImGui.SameLine()
						-- if ImGui.SmallButton("  Delete Theme  ") then
						-- 	print(os.remove("test.txt"))
						-- end
					end
					AMM.UI:Separator()

					ImGui.Text("Current Version: "..AMM.currentVersion)

					AMM.settings = true
					ImGui.EndTabItem()
				end

				if AMM.Editor.isEditing then
					AMM.Editor:Draw(AMM)
				end

				-- DEBUG Tab --
				if AMM.Debug ~= '' then
					AMM.Debug.CreateTab(AMM, target)
				end
			end
		end
	end
		AMM.UI:End()
		ImGui.End()
end

-- AMM Objects
function AMM:NewSpawn(name, id, parameters, companion, path)
	local obj = {}
	if type(id) == 'userdata' then id = tostring(id) end
	obj.handle = ''
	obj.name = name
	obj.id = id
	obj.uniqueName = function() return obj.name.."##"..obj.id end
	obj.parameters = parameters
	obj.canBeCompanion = companion
	obj.path = path
	obj.type = 'Spawn'
	obj.entityID = ''

	if obj.parameters == "Player" then
		obj.path = path..Util:GetPlayerGender()
		obj.parameters = nil
	end
	return obj
end

function AMM:NewTarget(handle, targetType, id, name, app, options)
	local obj = {}
	obj.handle = handle
	obj.id = id
	obj.name = name
	obj.appearance = app
	obj.type = targetType
	obj.options = options or nil

	-- Check if model is swappedModels
	if self.Swap.activeSwaps[obj.id] ~= nil then
		obj.id = self.Swap.activeSwaps[obj.id].newID
	end

	-- Check if custom appearance is active
	if self.activeCustomApps[obj.id] ~= nil then
		obj.appearance = self.activeCustomApps[obj.id]
	end

	return obj
end

-- End Objects --

-- AMM Methods --
function AMM:CheckDBVersion()
	local DBVersion = ''
	for v in db:urows("SELECT current_version FROM metadata") do
		DBVersion = v
	end

	if DBVersion ~= self.currentVersion then
		return false
	else
		return true
	end
end

function AMM:FinishUpdate()
	finishedUpdate = true
	db:execute(f("UPDATE metadata SET current_version = '%s'", self.currentVersion))
end

function AMM:ImportUserData()
	local file = io.open("User/user.json", "r")
	if file then
		local contents = file:read( "*a" )
		if contents == nil and contents == '' and contents:len() == 0 then
			local backup = io.open("User/user-old.json", "r")
			contents = backup:read( "*a" )
		end

		if contents ~= nil and contents ~= '' and contents:len() > 0 then
			local validJson, userData = pcall(function() return json.decode(contents) end)

			if validJson then
				if userData['favoriteLocations'] ~= nil then
					self.Tools.favoriteLocations = userData['favoriteLocations']
				end
				if userData['spawnedNPCs'] ~= nil then
					self.spawnedNPCs = self:PrepareImportSpawnedData(userData['spawnedNPCs'])
				end
				if userData['savedSwaps'] ~= nil then
					self.Swap:LoadSavedSwaps(userData['savedSwaps'])
				end

				self.selectedTheme = userData['selectedTheme']
				for _, obj in ipairs(userData['settings']) do
					db:execute(f("UPDATE settings SET setting_name = '%s', setting_value = %i WHERE setting_name = '%s'", obj.setting_name, boolToInt( obj.setting_value),  obj.setting_name))
				end
				for _, obj in ipairs(userData['favorites']) do
					local command = f("INSERT INTO favorites (position, entity_id, entity_name, parameters) VALUES (%i, '%s', '%s', '%s')", obj.position, obj.entity_id, obj.entity_name, obj.parameters)
					command = command:gsub("'nil'", "NULL")
					db:execute(command)
				end
				if userData['favorites_swap'] ~= nil then
					for _, obj in ipairs(userData['favorites_swap']) do
						local command = f("INSERT INTO favorites_swap (position, entity_id) VALUES (%i, '%s')", obj.position, obj.entity_id)
						db:execute(command)
					end
				end
				for _, obj in ipairs(userData['saved_appearances']) do
					db:execute(f("INSERT INTO saved_appearances (entity_id, app_name) VALUES ('%s', '%s')", obj.entity_id, obj.app_name))
				end
			end
		end
	end
end

function AMM:ExportUserData()
	local backupData = io.open("User/user.json", "r")
	if backupData then
		local contents = backupData:read( "*a" )
		local validJson = pcall(function() json.decode(contents) end)
		if validJson and contents ~= nil and contents ~= '' and contents:len() > 0 then
			local backup = io.open("User/user-old.json", "w")
			if backup then
				backup:write(contents)
				backup:close()
			end
		end
	end

	-- Prepare User Data --
	local userData = {}
	userData['settings'] = {}
	for r in db:nrows("SELECT * FROM settings") do
		table.insert(userData['settings'], {setting_name = r.setting_name, setting_value = intToBool(r.setting_value)})
	end
	userData['favorites'] = {}
	for r in db:nrows("SELECT * FROM favorites") do
		table.insert(userData['favorites'], {position = r.position, entity_id = r.entity_id, entity_name = r.entity_name, parameters = r.parameters})
	end
	userData['favorites_swap'] = {}
	for r in db:nrows("SELECT * FROM favorites_swap") do
		table.insert(userData['favorites_swap'], {position = r.position, entity_id = r.entity_id})
	end
	userData['saved_appearances'] = {}
	for r in db:nrows("SELECT * FROM saved_appearances") do
		table.insert(userData['saved_appearances'], {entity_id = r.entity_id, app_name = r.app_name})
	end
	userData['selectedTheme'] = self.selectedTheme
	userData['spawnedNPCs'] = self:PrepareExportSpawnedData()
	userData['savedSwaps'] = self.Swap:GetSavedSwaps()
	userData['favoriteLocations'] = self.Tools:GetFavoriteLocations()

	local validJson, contents = pcall(function() return json.encode(userData) end)
	if validJson and contents ~= nil then
		local file = io.open("User/user.json", "w")
		if file then
			file:write(contents)
			file:close()
		end
	end
end

function AMM:PrepareImportSpawnedData(savedIDs)
	local savedEntities = {}

	for _, id in ipairs(savedIDs) do
		for ent in db:nrows(f("SELECT * FROM entities WHERE entity_id = '%s'", id)) do
			spawn = AMM:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path)
			table.insert(savedEntities, spawn)
		end
	end

	return savedEntities
end

function AMM:PrepareExportSpawnedData()
	local spawnedEntities = {}

	for _, ent in pairs(self.spawnedNPCs) do
		table.insert(spawnedEntities, ent.id)
	end

	return spawnedEntities
end

function AMM:GetCategories()
	local query = "SELECT * FROM categories WHERE cat_name != 'At Your Own Risk' ORDER BY 3 ASC"
	if AMM.userSettings.experimental then
		query = "SELECT * FROM categories ORDER BY 3 ASC"
	end

	local categories = {}
	for category in db:nrows(query) do
		table.insert(categories, {cat_id = category.cat_id, cat_name = category.cat_name})
	end
	return categories
end

function AMM:GetSaveables()
	local defaults = {
		'0xB1B50FFA, 14', '0xC67F0E01, 15', '0x73C44EBA, 15', '0xA1C78C30, 16', '0x7F65F7F7, 16',
		'0x7B2CB67C, 17', '0x3024F03E, 15', '0x3B6EF8F9, 13', '0x413F60A6, 15', '0x62B8D0FA, 15',
		'0x3143911D, 15', '0xF0F54969, 24', '0x0044E64C, 20', '0xF43B2B48, 18', '0xC111FBAC, 16',
		'0x8DD8F2E0, 35', '0x4106744C, 35', '0xB98FDBB8, 14', '0x6B0544AD, 26', '0x215A57FC, 17',
		'0x903E76AF, 43', '0x55C01D9F, 36'
	}

	return defaults
end

function AMM:GetEquipmentOptions()
	local equipments = {
		{name = 'Katana', path = 'Character.afterlife_rare_fmelee3_katana_wa_elite_inline0'},
		{name = 'Mantis Blades', path = 'Character.afterlife_rare_fmelee3_mantis_ma_elite_inline0'},
		{name = 'Machete', path = 'Character.aldecaldos_grunt2_melee2__ma_inline0'},
		{name = 'Hammer', path = 'Character.maelstrom_grunt2_melee2_hammer_wa_inline0'},
		{name = 'Baton', path = 'Character.animals_bouncer1_melee1_baton_mb_inline0'},
		{name = 'Knife', path = 'Character.tyger_claws_gangster1_melee1_knife_wa_inline2'},
		{name = 'Crowbar', path = 'Character.wraiths_grunt2_melee2_crowbar_ma_inline0'},
		{name = 'Baseball Bat', path = 'Character.animals_grunt1_melee1_baseball_mb_inline0'},
		{name = 'Assault Rifle', path = 'Character.arasaka_ranger1_ranged2_masamune_ma_inline2'},
		{name = 'Sidewinder', path = 'Character.tyger_claws_gangster2_ranged2_sidewinder_wa_inline2'},
		{name = 'Sniper Rifle', path = 'Character.afterlife_rare_sniper3_ashura_ma_elite_inline0'},
		{name = 'Shotgun', path = 'Character.afterlife_rare_fshotgun3_zhuo_mb_elite_inline0'},
		{name = 'SMG', path = 'Character.afterlife_rare_franged2_saratoga_ma_rare_inline0'},
		{name = 'Handgun', path = 'Character.afterlife_rare_franged2_overture_wa_rare_inline0'},
	}

	return equipments
end

function AMM:RevertTweakDBChanges(userActivated)
	for swapID, swapObj in pairs(self.Swap.activeSwaps) do
		self.Swap:ChangeEntityTemplateTo(swapObj.name, swapID, swapID)
	end

	if not(userActivated) then
		TweakDB:SetFlat(TweakDBID.new('Vehicle.vehicle_list.list'), self.originalVehicles)
	end
end

function AMM:SetupJohnny()
	TweakDB:SetFlat(TweakDBID.new("Character.q000_tutorial_course_01_patroller.voiceTag"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.voiceTag")))
	TweakDB:SetFlat(TweakDBID.new("Character.q000_tutorial_course_01_patroller.displayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.displayName")))
	TweakDB:SetFlat(TweakDBID.new("Character.q000_tutorial_course_01_patroller.alternativeDisplayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.alternativeDisplayName")))
	TweakDB:SetFlat(TweakDBID.new("Character.q000_tutorial_course_01_patroller.alternativeFullDisplayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.alternativeFullDisplayName")))
	TweakDB:SetFlat(TweakDBID.new("Character.q000_tutorial_course_01_patroller.fullDisplayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.fullDisplayName")))
	TweakDB:SetFlat(TweakDBID.new("Character.q000_tutorial_course_01_patroller.affiliation"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.affiliation")))
	TweakDB:SetFlat(TweakDBID.new("Character.q000_tutorial_course_01_patroller.statPools"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.statPools")))
	TweakDB:Update(TweakDBID.new("Character.q000_tutorial_course_01_patroller"))
end

function AMM:SetupVehicleData()
	local unlockableVehicles = TweakDB:GetFlat(TweakDBID.new('Vehicle.vehicle_list.list'))
	AMM.originalVehicles = unlockableVehicles
	for vehicle in db:urows("SELECT entity_path FROM entities WHERE cat_id = 24") do
		table.insert(unlockableVehicles, TweakDBID.new(vehicle))
	end

	TweakDB:SetFlat(TweakDBID.new('Vehicle.vehicle_list.list'), unlockableVehicles)
end

function AMM:UnlockVehicle(handle)
	handle:GetVehiclePS():UnlockAllVehDoors()
end

function AMM:SpawnVehicle(spawn)
	local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	vehicleGarageId.recordID = TweakDBID.new(spawn.path)
	Game.GetVehicleSystem():ToggleSummonMode()
	Game.GetVehicleSystem():TogglePlayerActiveVehicle(vehicleGarageId, 'Car', true)
	Game.GetVehicleSystem():SpawnPlayerVehicle('Car')
	Game.GetVehicleSystem():ToggleSummonMode()

	self.spawnedNPCs[spawn.uniqueName()] = spawn
	self.currentSpawn = spawn.uniqueName()
end

function AMM:DespawnVehicle(spawn)
	local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	vehicleGarageId.recordID = TweakDBID.new(spawn.path)
	Game.GetVehicleSystem():DespawnPlayerVehicle(vehicleGarageId)
	self.spawnedNPCs[spawn.uniqueName()] = nil
end

function AMM:GetNPCTweakDBID(npc)
	if type(npc) == 'userdata' then return npc end
	return TweakDBID.new(npc)
end

function AMM:SpawnNPC(spawn)
	if self.spawnsCounter ~= self.maxSpawns and not buttonPressed then
		-- local offSetSpawn = self.spawnsCounter % 2 == 0 and self.spawnsCounter / 2 or -self.spawnsCounter / 2
		local offSetSpawn = self.spawnsCounter % 2 == 0 and self.spawnsCounter / 4 or -self.spawnsCounter / 4

		local distanceFromPlayer = 1
		local distanceFromGround = 0

		if type(spawn.parameters) == 'table' then
			distanceFromPlayer = -15
			distanceFromGround = spawn.parameters.distance or 0
		end

		local player = Game.GetPlayer()
		local heading = player:GetWorldForward()
		local offsetDir = Vector3.new(heading.x * distanceFromPlayer, heading.y * distanceFromPlayer, heading.z)
		local spawnTransform = player:GetWorldTransform()
		local spawnPosition = spawnTransform.Position:ToVector4(spawnTransform.Position)
		spawnTransform:SetPosition(spawnTransform, Vector4.new((spawnPosition.x - offSetSpawn) - offsetDir.x, (spawnPosition.y - offSetSpawn) - offsetDir.y, spawnPosition.z + distanceFromGround, spawnPosition.w))
		spawn.entityID = Game.GetPreventionSpawnSystem():RequestSpawn(self:GetNPCTweakDBID(spawn.path), -1, spawnTransform)
		self.spawnsCounter = self.spawnsCounter + 1
		while self.spawnedNPCs[spawn.uniqueName()] ~= nil do
			local num = spawn.name:match("%((%g+)%)")
			if num then num = tonumber(num) + 1 else num = 1 end
			spawn.name = spawn.name:gsub(" %("..tostring(num - 1).."%)", "")
			spawn.name = spawn.name.." ("..tostring(num)..")"
		end
		self.spawnedNPCs[spawn.uniqueName()] = spawn
		self.currentSpawn = spawn.uniqueName()
	else
		Game.GetPlayer():SetWarningMessage("Spawn limit reached!")
	end
end

function AMM:DespawnNPC(npcName, spawnID)
	--Game.GetPlayer():SetWarningMessage(npcName:match("(.+)##(.+)").." will despawn once you look away")
	self.spawnedNPCs[npcName] = nil
	self.spawnsCounter = self.spawnsCounter - 1
	local handle = Game.FindEntityByID(spawnID)
	if handle then handle:Dispose() end
	Game.GetPreventionSpawnSystem():RequestDespawn(spawnID)
end

function AMM:DespawnAll(message)
	if message then Game.GetPlayer():SetWarningMessage("Despawning will occur once you look away") end
	Game.GetPreventionSpawnSystem():RequestDespawnPreventionLevel(-1)
	self.spawnsCounter = 0
	self.spawnedNPCs = {}
end

function AMM:RespawnAll()
	 respawnAllPressed = true
end

function AMM:PrepareSettings()
	local settings = {}
	for r in db:nrows("SELECT * FROM settings") do
		settings[r.setting_name] = intToBool(r.setting_value)
	end
	return settings
end

function AMM:UpdateSettings()
	for name, value in pairs(self.userSettings) do
		db:execute(f("UPDATE settings SET setting_value = %i WHERE setting_name = '%s'", boolToInt(value), name))
	end
end

function AMM:CheckSavedAppearance(t)
	local handle, currentApp, savedApp = nil, nil, nil
	if t ~= nil then
		handle = t.handle
		currentApp = t.appearance
		for app in db:urows(f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", t.id)) do
			savedApp = app
		end
	else
		local qm = Game.GetPlayer():GetQuickSlotsManager()
		handle = qm:GetVehicleObject()
		if handle ~= nil then
			local vehicleID = self:GetScanID(handle)
			currentApp = self:GetScanAppearance(handle)
			for app in db:urows(f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", vehicleID)) do
				savedApp = app
			end
		end
	end

	if savedApp ~= nil and savedApp ~= currentApp then
		local check = 0
		for count in db:urows(f("SELECT COUNT(1) FROM custom_appearances WHERE app_name = '%s'", savedApp)) do
			check = count
		end
		if check ~= 0 then
			custom = self:GetCustomAppearanceParams(savedApp)
			self:ChangeScanCustomAppearanceTo(t, custom)
		else
			local check = 0
			for count in db:urows(f("SELECT COUNT(1) FROM appearances WHERE app_name = '%s'", savedApp)) do
				check = count
			end
			if check ~= 0 then
				self:ChangeScanAppearanceTo(t, savedApp)
			else
				-- This is a custom renamed appearance
				self:ClearSavedAppearance(t)
			end
		end
	end
end

function AMM:ClearSavedAppearance(t)
	if self.currentTarget ~= '' then
		if t.appearance ~= self.currentTarget.appearance then
			self:ChangeScanAppearanceTo(t, self.currentTarget.appearance)
		end
	end

	db:execute(f("DELETE FROM saved_appearances WHERE entity_id = '%s'", t.id))

end

function AMM:ClearAllSavedAppearances()
	db:execute("DELETE FROM saved_appearances")
end

function AMM:ClearAllFavorites()
	db:execute("DELETE FROM favorites; UPDATE sqlite_sequence SET seq = 0")
end

function AMM:SaveAppearance(t)
	local check = 0
	for count in db:urows(f("SELECT COUNT(1) FROM saved_appearances WHERE entity_id = '%s'", t.id)) do
		check = count
	end
	if check ~= 0 then
		db:execute(f("UPDATE saved_appearances SET app_name = '%s' WHERE entity_id = '%s'", t.appearance, t.id))
	else
		db:execute(f("INSERT INTO saved_appearances (entity_id, app_name) VALUES ('%s', '%s')", t.id, t.appearance))
	end
end

function AMM:GetNPCName(t)
	local n = t:GetTweakDBDisplayName(true)
	return n
end

function AMM:GetVehicleName(t)
	return tostring(t:GetDisplayName())
end

function AMM:GetObjectName(t)
	return self:GetScanClass(t)
end

function AMM:GetScanID(t)
	tdbid = t:GetRecordID()
	hash = tostring(tdbid):match("= (%g+),")
	length = tostring(tdbid):match("= (%g+) }")
	return hash..", "..length
end

function AMM:GetScanClass(t)
	local className = t:GetClassName()
	return tostring(className):match("%[ (%g+) -")
end

function AMM:SetCurrentTarget(t)
	if t ~= nil then
		if self.currentTarget ~= '' then
			if t.id ~= self.currentTarget.id then
				self.currentTarget = t
			end
		else
			self.currentTarget = t
		end
	end
end

function AMM:GetAppearanceOptions(t)
	local options = {}

	local scanID = self:GetScanID(t)

	if t:IsNPC() and self.Swap.activeSwaps[scanID] == nil then
		if t:GetRecord():CrowdAppearanceNames()[1] ~= nil then
			for _, app in ipairs(t:GetRecord():CrowdAppearanceNames()) do
				table.insert(options, tostring(app):match("%[ (%g+) -"))
			end
			return options
		end
	end

	if self.Swap.activeSwaps[scanID] ~= nil then
	 	scanID = self.Swap.activeSwaps[scanID].newID
	end

	for app in db:urows(f("SELECT DISTINCT app_name FROM custom_appearances WHERE entity_id = '%s' ORDER BY app_base ASC", scanID)) do
		table.insert(options, app)
	end

	for app in db:urows(f("SELECT app_name FROM appearances WHERE entity_id = '%s' ORDER BY app_name ASC", scanID)) do
		table.insert(options, app)
	end

	if next(options) ~= nil then
		return options -- array of appearances names
	end

	return nil
end

function AMM:GetScanAppearance(t)
	return tostring(t:GetCurrentAppearanceName()):match("%[ (%g+) -")
end

function AMM:CheckForReverseCustomAppearance(appearance, target)
	-- Check if custom app is active
	local activeApp = nil

	if next(self.activeCustomApps) ~= nil and self.activeCustomApps[target.id] ~= nil then
		activeApp = self.activeCustomApps[target.id]
	end

	local reverse = false
	if target ~= nil and activeApp ~= nil and activeApp ~= appearance and target.id ~= "0x903E76AF, 43" then
		for app_base in db:urows(f("SELECT app_base FROM custom_appearances WHERE app_name = '%s' AND app_base = '%s' AND entity_id = '%s'", activeApp, appearance, target.id)) do
			reverse = true
			self.activeCustomApps[target.id] = 'reverse'
		end
	end

	if reverse then appearance = activeApp end

	return appearance, reverse
end

function AMM:GetCustomAppearanceParams(appearance, reverse)
	local custom = {}
	for app in db:nrows(f("SELECT * FROM custom_appearances WHERE app_name = '%s' AND entity_id = '%s'", appearance, target.id)) do
		app.app_toggle = not(intToBool(app.app_toggle))
		if reverse then app.app_toggle = not app.app_toggle end
		table.insert(custom, app)
	end
	return custom
end

function AMM:ChangeScanCustomAppearanceTo(t, customAppearance)
	self:ChangeScanAppearanceTo(t, customAppearance[1].app_base)
	self.setCustomApp = {t.handle, customAppearance}
	if self.activeCustomApps[t.id] ~= 'reverse' then
		self.activeCustomApps[t.id] = customAppearance[1].app_name
	else
		self.activeCustomApps[t.id] = nil
	end
end

function AMM:ChangeScanAppearanceTo(t, newAppearance)
	if not(string.find(t.name, 'Mech')) then
		t.handle:PrefetchAppearanceChange(newAppearance)
		t.handle:ScheduleAppearanceChange(newAppearance)

		if self.activeCustomApps[t.id] ~= nil and self.activeCustomApps[t.id] ~= 'reverse' then
			self.activeCustomApps[t.id] = nil
		end
	end
end

function AMM:GetTarget()
	if Game.GetPlayer() then
		target = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(), true, false) or Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(), false, false)

		if target ~= nil then
			if target:IsNPC() or target:IsReplacer() then
				t = AMM:NewTarget(target, AMM:GetScanClass(target), AMM:GetScanID(target), AMM:GetNPCName(target),AMM:GetScanAppearance(target), AMM:GetAppearanceOptions(target))
			elseif target:IsVehicle() then
				t = AMM:NewTarget(target, AMM:GetScanClass(target), AMM:GetScanID(target), AMM:GetVehicleName(target),AMM:GetScanAppearance(target), AMM:GetAppearanceOptions(target))
			else
				if AMM.userSettings.experimental then
					t = AMM:NewTarget(target, AMM:GetScanClass(target), 'None', AMM:GetObjectName(target),AMM:GetScanAppearance(target), nil)
				end
			end

			if t ~= nil and t.name ~= "gameuiWorldMapGameObject" then
				AMM:SetCurrentTarget(t)
				return t
			end
		end
	end

	return nil
end

function AMM:SetGodMode(entityID, immortal)
	local gs = Game.GetGodModeSystem()

	-- print("setting god mode")

	if immortal then
		gs:AddGodMode(entityID, 4, CName.new("Default"))
	else

		modes = {1, 2, 3, 4, 5}

		for _, mode in ipairs(modes) do
			if gs:HasGodMode(entityID, mode) then
				gs:ClearGodMode(entityID, CName.new("Default"))
			end
		end
	end

end

function AMM:ToggleHostile(spawn)
	self:SetGodMode(spawn.entityID, false)

	local handle = spawn.handle

	if handle.isPlayerCompanionCached then
		local AIC = handle:GetAIControllerComponent()
		local targetAttAgent = handle:GetAttitudeAgent()
		local reactionComp = handle.reactionComponent

		local aiRole = NewObject('handle:AIRole')
		aiRole:OnRoleSet(handle)

		handle.isPlayerCompanionCached = false
		handle.isPlayerCompanionCachedTimeStamp = 0

		Game['senseComponent::RequestMainPresetChange;GameObjectString'](handle, "Combat")
		Game['NPCPuppet::ChangeStanceState;GameObjectgamedataNPCStanceState'](handle, "Combat")
		AIC:GetCurrentRole():OnRoleCleared(handle)
		AIC:SetAIRole(aiRole)
		handle.movePolicies:Toggle(true)
		targetAttAgent:SetAttitudeGroup(CName.new("hostile"))
		reactionComp:SetReactionPreset(GetSingleton("gamedataTweakDBInterface"):GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive")))
		reactionComp:TriggerCombat(Game.GetPlayer())
	else
		self:SetNPCAsCompanion(handle)
	end
end

function AMM:ToggleFavorite(isFavorite, entity)
	if isFavorite == 0 then
		local command = f("INSERT INTO favorites (entity_id, entity_name, parameters) VALUES ('%s', '%s', '%s')", entity.id, entity.name, entity.parameters)
		command = command:gsub("'nil'", "NULL")
		db:execute(command)
	else
		local removedIndex = 0
		local query = f("SELECT position FROM favorites WHERE entity_name = '%s'", entity.name)
		for i in db:urows(query) do removedIndex = i end

		local command = f("DELETE FROM favorites WHERE entity_name = '%s' OR parameters = '%s'", entity.name, entity.parameters)
		command = command:gsub("'nil'", "NULL")
		db:execute(command)
		AMM:RearrangeFavoritesIndex(removedIndex)
	end
end

function AMM:RearrangeFavoritesIndex(removedIndex)
	local lastIndex = 0
	query = "SELECT seq FROM sqlite_sequence WHERE name = 'favorites'"
	for i in db:urows(query) do lastIndex = i end

	if lastIndex ~= removedIndex then
		for i = removedIndex, lastIndex - 1 do
			db:execute(f("UPDATE favorites SET position = %i WHERE position = %i", i, i + 1))
		end
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = 'favorites'", lastIndex - 1))
end

-- Companion methods -- original code by Catmino
function AMM:SetNPCAsCompanion(npcHandle)
	-- print("setting companion")
	if not(self.isCompanionInvulnerable) then
		self:SetGodMode(npcHandle:GetEntityID(), false)
	end

	waitTimer = 0.0
	self.currentSpawn = ''

	local targCompanion = npcHandle
	local AIC = targCompanion:GetAIControllerComponent()
	local targetAttAgent = targCompanion:GetAttitudeAgent()
	local currTime = targCompanion.isPlayerCompanionCachedTimeStamp + 11

	if targCompanion.isPlayerCompanionCached == false then
		local roleComp = NewObject('handle:AIFollowerRole')
		roleComp:SetFollowTarget(Game:GetPlayerSystem():GetLocalPlayerControlledGameObject())
		roleComp:OnRoleSet(targCompanion)
		roleComp.followerRef = Game.CreateEntityReference("#player", {})
		targetAttAgent:SetAttitudeGroup(CName.new("player"))
		roleComp.attitudeGroupName = CName.new("player")
		Game['senseComponent::RequestMainPresetChange;GameObjectString'](targCompanion, "Follower")
		Game['senseComponent::ShouldIgnoreIfPlayerCompanion;EntityEntity'](targCompanion, Game:GetPlayer())
		Game['NPCPuppet::ChangeStanceState;GameObjectgamedataNPCStanceState'](targCompanion, "Relaxed")
		targCompanion.isPlayerCompanionCached = true
		targCompanion.isPlayerCompanionCachedTimeStamp = currTime

		AIC:SetAIRole(roleComp)
		targCompanion.movePolicies:Toggle(true)

		if self.spawnsCounter < 3 then
			self:SetFollowDistance(-0.8)
		elseif self.spawnsCounter == 3 then
			self:SetFollowDistance(1)
		else
			self:SetFollowDistance(2)
		end
	end
end

function AMM:SetFollowDistance(followDistance)
 TweakDB:SetFlat(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.distance'), followDistance)

TweakDB:SetFlat(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.avoidObstacleWithinTolerance'), true)
TweakDB:SetFlat(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.ignoreCollisionAvoidance'), false)
TweakDB:SetFlat(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.ignoreSpotReservation'), false)

 TweakDB:SetFlat(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.tolerance'), 0.0)

 TweakDB:SetFlat(TweakDBID.new('FollowerActions.FollowStayPolicy.distance'), followDistance)
 TweakDB:SetFlat(TweakDBID.new('FollowerActions.FollowGetOutOfWayMovePolicy.distance'), 0.0)

 TweakDB:Update(TweakDBID.new('FollowerActions.FollowCloseMovePolicy'))
 TweakDB:Update(TweakDBID.new('FollowerActions.FollowStayPolicy'))
 TweakDB:Update(TweakDBID.new('FollowerActions.FollowGetOutOfWayMovePolicy'))
end

function AMM:ChangeNPCEquipment(npcPath, equipmentPath)
	TweakDB:SetFlat(TweakDBID.new(npcPath..".primaryEquipment"), TweakDBID.new(equipmentPath))
	TweakDB:Update(TweakDBID.new(npcPath))
end

-- Helper methods
function AMM:IsUnique(npcID)
	for _, v in ipairs(self.allowedNPCs) do
		if npcID == v then
			-- NPC is unique
			return true
		end
	end
end

function AMM:CanBeHostile(t)
	local canBeHostile = t:GetRecord():AbilitiesContains(GetSingleton("gamedataTweakDBInterface"):GetGameplayAbilityRecord(TweakDBID.new("Ability.CanCloseCombat")))
	if not(canBeHostile) then
		canBeHostile = t:GetRecord():AbilitiesContains(GetSingleton("gamedataTweakDBInterface"):GetGameplayAbilityRecord(TweakDBID.new("Ability.HasChargeJump")))
	end

	return canBeHostile
end

function AMM:IsSpawnable(t)
	local spawnableID = nil

	if t.appearance == "None" then
		return spawnableID
	end

	if t.handle:IsNPC() then
		query = f("SELECT entity_id FROM entities WHERE entity_id = '%s'", t.id)
		for entID in db:urows(query) do
			spawnableID = entID
		end

		local possibleEntities = {}
		if spawnableID == nil then
			query = f("SELECT entity_id FROM appearances WHERE app_name = '%s'", t.appearance)
			for entID in db:urows(query) do
				table.insert(possibleEntities, entID)
			end
		end

		if #possibleEntities ~= 0 then
			for _, pEntID in ipairs(possibleEntities) do
				local count = 0
				query = f("SELECT COUNT(1) FROM favorites WHERE entity_id = '%s'", pEntID)
				for found in db:urows(query) do
					count = found
				end

				if count == 0 then
					query = f("SELECT entity_id FROM entities WHERE entity_id = '%s'", pEntID)
					for entID in db:urows(query) do
						spawnableID = entID
					end
				end
			end
		end

		return spawnableID
	end
end

function AMM:ShouldDrawSaveButton(t)
	if t.handle:IsNPC() then
		local npcID = self:GetScanID(t.handle)
		if AMM:IsUnique(npcID) then
			return true
		end

		local query = "SELECT entity_id FROM favorites"
		for favID in db:urows(query) do
			if t.id == favID then
				-- NPC is user's favorites
				return true
			end
		end

		-- NPC isn't unique
		return false

	elseif t.handle:IsVehicle() and t.handle:IsPlayerVehicle() then
		return true
	end

	return false
end

function AMM:OpenPopup(name)
	local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)

	local popupDelegate = {message = '', buttons = {}}
	if string.find(name, "Equipment") then
		ImGui.SetNextWindowSize(400, 520)
		popupDelegate.message = "Select "..name..":"
		for _, equipment in ipairs(self.equipmentOptions) do
			table.insert(popupDelegate.buttons, {label = equipment.name, action = function(fromPath) AMM:ChangeNPCEquipment(fromPath, equipment.path) end})
		end
	elseif name == "Experimental" then
		ImGui.SetNextWindowSize(400, 140)
		popupDelegate.message = "Are you sure you want to enable experimental features? AMM might not work as expected. Use it at your own risk!"
		table.insert(popupDelegate.buttons, {label = "Yes", action = ''})
		table.insert(popupDelegate.buttons, {label = "No", action = function() AMM.userSettings.experimental = false end})
		name = "WARNING"
	elseif name == "Favorites" then
		popupDelegate.message = "Are you sure you want to delete all your favorites?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() AMM:ClearAllFavorites() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	elseif name == "Appearances" then
		popupDelegate.message = "Are you sure you want to delete all your saved appearances?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() AMM:ClearAllSavedAppearances() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	end

	ImGui.OpenPopup(name)
	return popupDelegate
end

function AMM:BeginPopup(popupTitle, popupActionArg, popupModal, popupDelegate, style)
	local popup
	if popupModal then
		popup = ImGui.BeginPopupModal(popupTitle, ImGuiWindowFlags.AlwaysAutoResize)
	else
		popup = ImGui.BeginPopup(popupTitle)
	end
	if popup then
		ImGui.TextWrapped(popupDelegate.message)
		for _, button in ipairs(popupDelegate.buttons) do
			if ImGui.Button(button.label, style.buttonWidth, style.buttonHeight) then
				if button.action ~= '' then button.action(popupActionArg) end
				ImGui.CloseCurrentPopup()
			end
		end
		ImGui.EndPopup()
	end
end

function AMM:SetFavoriteNamePopup(entity)
	local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
	ImGui.SetNextWindowSize(400, ImGui.GetFontSize() * 8)
	AMM.currentFavoriteName = entity.name
	AMM.popupEntity = entity
	ImGui.OpenPopup("Favorite Name")
end

function AMM:DrawFavoritesButton(buttonLabels, entity)
	if entity.parameters == nil then
		entity['parameters'] = entity.appearance
	end

	local isFavorite = 0
	for fav in db:urows(f('SELECT COUNT(1) FROM favorites WHERE entity_name = "%s"', entity.name)) do
		isFavorite = fav
	end
	if isFavorite == 0 and entity.parameters ~= nil then
		for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE parameters = '%s'", entity.parameters)) do
			isFavorite = fav
		end
	end

	local favoriteButtonLabel = buttonLabels[1].."##"..entity.name
	if isFavorite ~= 0 then
		favoriteButtonLabel = buttonLabels[2].."##"..entity.name
	end

	if ImGui.SmallButton(favoriteButtonLabel) then
		if not(AMM:IsUnique(entity.id)) and isFavorite == 0 then
			AMM:SetFavoriteNamePopup(entity)
		else
			AMM:ToggleFavorite(isFavorite, entity)
		end
	end

	if ImGui.BeginPopupModal("Favorite Name") then
		local style = {
						buttonHeight = ImGui.GetFontSize() * 2,
						halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12)
				}

		if AMM.currentFavoriteName == 'existing' then
			ImGui.TextColored(1, 0.16, 0.13, 0.75, "Existing Name")

			if ImGui.Button("Ok", -1, style.buttonHeight) then
				AMM.currentFavoriteName = ''
			end
		elseif AMM.popupEntity.name == entity.name then
			AMM.currentFavoriteName = ImGui.InputText("Name", AMM.currentFavoriteName, 30)

			if ImGui.Button("Save", style.halfButtonWidth + 8, style.buttonHeight) then
				local isFavorite = 0
				for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_name = '%s'", self.currentFavoriteName)) do
					isFavorite = fav
				end
				if isFavorite == 0 then
					if entity.type ~= 'Spawn' then -- Target type
						entity.name = AMM.currentFavoriteName
					else -- Spawn type
						AMM.spawnedNPCs[entity.uniqueName()] = nil
						entity.name = AMM.currentFavoriteName
						entity.parameters = AMM:GetScanAppearance(entity.handle)
						AMM.spawnedNPCs[entity.uniqueName()] = entity
					end
					AMM.currentFavoriteName = ''
					AMM:ToggleFavorite(isFavorite, entity)
					AMM.popupIsOpen = false
					ImGui.CloseCurrentPopup()
				else
					AMM.currentFavoriteName = 'existing'
				end
			end

			ImGui.SameLine()
			if ImGui.Button("Cancel", style.halfButtonWidth + 8, style.buttonHeight) then
				AMM.currentFavoriteName = ''
				AMM.popupIsOpen = false
				ImGui.CloseCurrentPopup()
			end
		end
		ImGui.EndPopup()
	end
end

function AMM:DrawArrowButton(direction, entity, index)
	local dirEnum, tempPos
	if direction == "up" then
		dirEnum = ImGuiDir.Up
		tempPos = index - 1
	else
		dirEnum = ImGuiDir.Down
		tempPos = index + 1
	end

	local query = "SELECT COUNT(1) FROM favorites"
	for x in db:urows(query) do favoritesLength = x end

	if ImGui.ArrowButton(direction..entity.id, dirEnum) then
		if not(tempPos < 1 or tempPos > favoritesLength) then
			local query = f("SELECT * FROM favorites WHERE position = %i", tempPos)
			for fav in db:nrows(query) do temp = fav end

			db:execute(f("UPDATE favorites SET entity_id = '%s', entity_name = '%s', parameters = '%s' WHERE position = %i", entity.id, entity.name, entity.parameters, tempPos))
			db:execute(f("UPDATE favorites SET entity_id = '%s', entity_name = '%s', parameters = '%s' WHERE position = %i", temp.entity_id, temp.entity_name, temp.parameters, index))
		end
	end
end

function AMM:DrawButton(title, width, height, action, target)
	if (ImGui.Button(title, width, height)) then
		if action == "Cycle" then
			AMM:ChangeScanAppearanceTo(target, 'Cycle')
		elseif action == "Save" then
			AMM:SaveAppearance(target)
		elseif action == "Clear" then
			AMM:ClearSavedAppearance(target)
		elseif action == "SpawnNPC" then
			AMM:SpawnNPC(target)
			buttonPressed = true
		elseif action == "SpawnVehicle" then
			AMM:SpawnVehicle(target)
			buttonPressed = true
		end
	end
end

function AMM:DrawEntitiesButtons(entities, categoryName, style)

	for i, entity in ipairs(entities) do
		name = entity[1]
		id = entity[2]
		path = entity[5]
		companion = intToBool(entity[3])
		parameters = entity[4]

		local newSpawn = AMM:NewSpawn(name, id, parameters, companion, path)
		local uniqueName = newSpawn.uniqueName()
		local buttonLabel = uniqueName..tostring(i)

		local favOffset = 0
		if categoryName == 'Favorites' then
			favOffset = 40

			AMM:DrawArrowButton("up", newSpawn, i)
			ImGui.SameLine()
		end

		local isFavorite = 0
		for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_id = '%s'", id)) do
			isFavorite = fav
		end

		if self.spawnsCounter == self.maxSpawns or (AMM.spawnedNPCs[uniqueName] and isFavorite ~= 0) then
			ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
			AMM:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, "Disabled", nil)
			ImGui.PopStyleColor(3)
		elseif not(AMM.spawnedNPCs[uniqueName] ~= nil and AMM:IsUnique(newSpawn.id)) then
			local action = "SpawnNPC"
			if string.find(tostring(newSpawn.path), "Vehicle") then action = "SpawnVehicle" end
			AMM:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, action, newSpawn)
		end

		if categoryName == 'Favorites' then
			ImGui.SameLine()
			AMM:DrawArrowButton("down", newSpawn, i)
		end
	end
end

-- End of AMM Class

return AMM:new()
