-- Begin of ScanApp Class

ScanApp = {
	description = "",
}

-- ALIAS for string.format --
local f = string.format

function intToBool(value)
	return value > 0 and true or false
end

function boolToInt(value)
  return value and 1 or 0
end

function ScanApp:new()

   setmetatable(ScanApp, self)
	 self.__index = self

	 -- Load Debug --
	 if io.open("Debug/debug.lua", "r") then
		 ScanApp.Debug = require("Debug/debug.lua")
	 else
		 ScanApp.Debug = ''
	 end

	 -- Themes Properties --
	 ScanApp.Theme = require('Themes/ui.lua')
	 ScanApp.Editor = require('Themes/editor.lua')
	 ScanApp.selectedTheme = 'Default'

	 -- Main Properties --
	 ScanApp.currentVersion = "1.7"
	 ScanApp.updateNotes = require('update_notes.lua')
	 ScanApp.userSettings = ScanApp:PrepareSettings()
	 ScanApp.categories = ScanApp:GetCategories()
	 ScanApp.currentTarget = ''
	 ScanApp.spawnedNPCs = {}
	 ScanApp.entitiesForRespawn = ''
	 ScanApp.allowedNPCs = ScanApp:GetSaveables()
	 ScanApp.searchQuery = ''
	 ScanApp.swappedModels = ScanApp:GetEntityTemplates()
	 ScanApp.equipmentOptions = ScanApp:GetEquipmentOptions()
	 ScanApp.originalVehicles = ''

	 -- Custom Appearance Properties --
	 ScanApp.setCustomApp = ''
	 ScanApp.activeCustomApps = {}

	 -- Modal Popup Properties --
	 ScanApp.currentFavoriteName = ''
	 ScanApp.popupEntity = ''

	 -- Configs --
	 ScanApp.settings = false
	 ScanApp.currentSpawn = ''
	 ScanApp.maxSpawns = 5
	 ScanApp.spawnsCounter = 0
	 ScanApp.spawnAsCompanion = true
	 ScanApp.isCompanionInvulnerable = true
	 ScanApp.shouldCheckSavedAppearance = true

	 registerForEvent("onInit", function()
		 waitTimer = 0.0
		 spamTimer = 0.0
		 respawnTimer = 0.0
		 buttonPressed = false
		 respawnAllPressed = false
		 finishedUpdate = ScanApp:CheckDBVersion()
		 ScanApp:ImportUserData()
		 ScanApp:SetupVehicleData()

		 -- Setup Observers --
		 Observe("PlayerPuppet", "OnGameAttached", function(self)
			 ScanApp.activeCustomApps = {}
			 ScanApp.spawnedNPCs = {}
			 ScanApp.spawnsCounter = 0
		 end)
	 end)

	 registerForEvent("onShutdown", function()
		 ScanApp:RevertTweakDBChanges(false)
		 ScanApp:ExportUserData()
	 end)

	 -- Keybinds
	 registerHotkey("amm_open_overlay", "Open Appearance Menu", function()
	 	drawWindow = not drawWindow
	 end)

	 registerHotkey("amm_cycle", "Cycle Appearance", function()
		local target = ScanApp:GetTarget()
		if target ~= nil then
			waitTimer = 0.0
			ScanApp.shouldCheckSavedAppearance = false
			ScanApp:ChangeScanAppearanceTo(target, 'Cycle')
		end
	 end)

	 registerHotkey("amm_save", "Save Appearance", function()
		local target = ScanApp:GetTarget()
 		if target ~= nil then
			if ScanApp:ShouldDrawSaveButton(target) then
 				ScanApp:SaveAppearance(target)
			end
 		end
	 end)

	 registerHotkey("amm_clear", "Clear Appearance", function()
		local target = ScanApp:GetTarget()
		if target ~= nil then
			ScanApp:ClearSavedAppearance(target)
		end
	 end)

	 registerHotkey("amm_respawn_all", "Respawn All (Experimental Only)", function()
	 	if ScanApp.userSettings.experimental then ScanApp:RespawnAll() end
	 end)

	 registerForEvent("onUpdate", function(deltaTime)
		 if not(ScanApp:IsPlayerInAnyMenu()) then
				if finishedUpdate and Game.GetPlayer() ~= nil then
			 		-- Load Saved Appearance --
			 		if not drawWindow and ScanApp.shouldCheckSavedAppearance then
			 			target = ScanApp:GetTarget()
			 			ScanApp:CheckSavedAppearance(target)
			 		elseif ScanApp.shouldCheckSavedAppearance == false then
						waitTimer = waitTimer + deltaTime

						if waitTimer > 8 then
							waitTimer = 0.0
							ScanApp.shouldCheckSavedAppearance = true
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
						if ScanApp.entitiesForRespawn == '' then
							ScanApp.entitiesForRespawn = {}
							for _, ent in pairs(ScanApp.spawnedNPCs) do
								table.insert(ScanApp.entitiesForRespawn, ent)
							end

							-- for _, ent in ipairs(ScanApp.entitiesForRespawn) do
							-- 	ScanApp:DespawnNPC(ent.uniqueName, ent.entityID)
							-- end
							ScanApp:DespawnAll(true)
						else
							if waitTimer == 0.0 then
								respawnTimer = respawnTimer + deltaTime
							end

							if respawnTimer > 0.5 then
								empty = true
								for _, ent in ipairs(ScanApp.entitiesForRespawn) do
									if Game.FindEntityByID(ent.entityID) then empty = false end
								end

								if empty then
									ent = ScanApp.entitiesForRespawn[1]
									table.remove(ScanApp.entitiesForRespawn, 1)
									ScanApp:SpawnNPC(ent)
									respawnTimer = 0.0
								end

								if #ScanApp.entitiesForRespawn == 0 then
									ScanApp.entitiesForRespawn = ''
									respawnAllPressed = false
								end
							end
						end
					end

					-- After Custom Appearance Set --
					if ScanApp.setCustomApp ~= '' then
						waitTimer = waitTimer + deltaTime
						if waitTimer > 0.1 then
							local handle, customAppearance = ScanApp.setCustomApp[1], ScanApp.setCustomApp[2]
							local currentAppearance = ScanApp:GetScanAppearance(handle)
							if currentAppearance == customAppearance[1].app_base then
								for _, param in ipairs(customAppearance) do
									local appParam = handle:FindComponentByName(CName.new(param.app_param))
									if appParam then appParam:TemporaryHide(not(intToBool(param.app_toggle))) end
								end

								waitTimer = 0.0
								ScanApp.setCustomApp = ''
							end
						end
					end


					-- After Spawn Logic --
					if ScanApp.currentSpawn ~= '' then
						waitTimer = waitTimer + deltaTime
						-- print('trying to set companion')
						if waitTimer > 0.2 then
							local handle
							if string.find(ScanApp.spawnedNPCs[ScanApp.currentSpawn].path, "Vehicle") then
								handle = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(),false,false)
							else
								handle = Game.FindEntityByID(ScanApp.spawnedNPCs[ScanApp.currentSpawn].entityID)
							end
							if handle then
								ScanApp.spawnedNPCs[ScanApp.currentSpawn].handle = handle
								if handle:IsNPC() then
									if ScanApp.spawnedNPCs[ScanApp.currentSpawn].parameters ~= nil then
										ScanApp:ChangeScanAppearanceTo(ScanApp.spawnedNPCs[ScanApp.currentSpawn], ScanApp.spawnedNPCs[ScanApp.currentSpawn].parameters)
									end
									if ScanApp.spawnAsCompanion and ScanApp.spawnedNPCs[ScanApp.currentSpawn].canBeCompanion then
										ScanApp:SetNPCAsCompanion(handle)
									else
										ScanApp.currentSpawn = ''
									end
								elseif handle:IsVehicle() then
									ScanApp:UnlockVehicle(handle)
									waitTimer = 0.0
									ScanApp.currentSpawn = ''
								else
									ScanApp.currentSpawn = ''
								end
							end
						end
					else
						ScanApp.currentSpawn = ''
					end
				end
			end
	 end)

	 registerForEvent("onOverlayOpen", function()
		 if ScanApp.userSettings.openWithOverlay then drawWindow = true end
	 end)

	 registerForEvent("onOverlayClose", function()
		 drawWindow = false
	 end)

	 registerForEvent("onDraw", function()

	 	ImGui.SetNextWindowPos(500, 500, ImGuiCond.FirstUseEver)

		local shouldResize = ImGuiWindowFlags.AlwaysAutoResize
		if not(ScanApp.userSettings.autoResizing) then
			shouldResize = ImGuiWindowFlags.None
		end

	 	if drawWindow then
			-- Load Theme --
			if ScanApp.Theme.currentTheme ~= ScanApp.selectedTheme then
				ScanApp.Theme:Load(ScanApp.selectedTheme)
			end

			ScanApp.Theme:Start()

			if ImGui.Begin("Appearance Menu Mod", shouldResize) then

				if not(finishedUpdate) then
					-- UPDATE NOTES
					ScanApp.Theme:TextColored("UPDATE "..ScanApp.currentVersion)
					ScanApp.Theme:Separator()

					for _, note in ipairs(ScanApp.updateNotes) do
						ScanApp.Theme:TextColored("+ ")
						ImGui.SameLine()
						ImGui.PushTextWrapPos(400)
						ImGui.TextWrapped(note)
						ImGui.PopTextWrapPos()
						ScanApp.Theme:Spacing(3)
					end

					ScanApp.Theme:Separator()
					if ImGui.Button("Cool!", ImGui.GetWindowContentRegionWidth(), 30) then
						ScanApp:FinishUpdate()
					end
				elseif (ScanApp:IsPlayerInAnyMenu() or Game.GetPlayer() == nil) and ScanApp.Debug == '' then
						ScanApp.Theme:TextColored("Player In Menu")
						ImGui.Text("AMM only functions in game")
				else
						-- Target Setup --
						target = ScanApp:GetTarget()

						if (ImGui.BeginTabBar("TABS")) then

		 					local style = {
		 									buttonWidth = ImGui.GetFontSize() * 20.7,
		 									buttonHeight = ImGui.GetFontSize() * 2,
		 									halfButtonWidth = (ImGui.GetFontSize() * 20) / 2
		 							}

		 	    		local tabs = {
		 	    			['NPC'] = {
		 	    				currentTitle = "Current Appearance:",
		 	    				buttons = {
		 								{
		 									title = "Cycle Appearance",
		 									width = style.halfButtonWidth,
		 									action = "Cycle"
		 								},
		 								{
		 									title = "Save Appearance",
		 									width = style.halfButtonWidth,
		 									action = "Save"
		 								},
		 							},
		 	    				errorMessage = "No NPC Found! Look at NPC to begin\n\n"
		 	    			},
		 	    			['Vehicles'] = {
		 	    				currentTitle = "Current Model:",
		 	    				buttons = {
		 								{
		 									title = "Cycle Model",
		 									width = style.halfButtonWidth,
		 									action = "Cycle"
		 								},
		 								{
		 									title = "Save Appearance",
		 									width = style.halfButtonWidth,
		 									action = "Save"
		 								},
		 							},
		 	    				errorMessage = "No Vehicle Found! Look at Vehicle to begin\n\n"
		 	    			}
		 	    		}

		 	    		-- Tab Constructor --
		 	    		tabOrder = {"NPC", "Vehicles"}

		 	    		for _, tab in ipairs(tabOrder) do
		 		    		if (ImGui.BeginTabItem(tab)) then
		 		    			ScanApp.settings = false

		 							if target ~= nil and target.type == tab then
										ScanApp.Theme:Spacing(3)

										ImGui.Text(target.name)

										ScanApp.Theme:Separator()

	 					    		ScanApp.Theme:TextColored(tabs[tab].currentTitle)
	 					    		ImGui.Text(target.appearance)

	 									ImGui.Spacing()

	 									-- Check if Save button should be drawn
	 									local drawSaveButton = ScanApp:ShouldDrawSaveButton(target)

	 									for _, button in ipairs(tabs[tab].buttons) do
	 										ImGui.SameLine()

	 										if drawSaveButton == false then
	 											button.width = style.buttonWidth

	 											if button.action ~= "Save" then
	 												ScanApp:DrawButton(button.title, button.width, style.buttonHeight, button.action, target)
	 											end
	 										else
	 											ScanApp:DrawButton(button.title, button.width, style.buttonHeight, button.action, target)
	 										end
	 									end

	 									ImGui.Spacing()

										local savedApp = nil
										local query = f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", target.id)
										for app in db:urows(query) do
											savedApp = app
										end

	 									if savedApp ~= nil then
	 										ScanApp.Theme:TextColored("Saved Appearance:")
	 						    		ImGui.Text(savedApp)
	 										ScanApp:DrawButton("Clear Saved Appearance", style.buttonWidth, style.buttonHeight, "Clear", target)
	 									end

	 						    	ScanApp.Theme:Separator()

										ScanApp.Theme:TextColored("Possible Actions:")

										ImGui.Spacing()

										if target.handle:IsVehicle() then
											if ImGui.SmallButton("  Unlock Vehicle  ") then
												ScanApp:UnlockVehicle(target.handle)
											end

											if ImGui.SmallButton("  Repair Vehicle  ") then
												target.handle:RepairVehicle()
												target.handle:ForcePersistentStateChanged()
											end
										end

										local spawnID = ScanApp:IsSpawnable(target)
										if spawnID ~= nil then
											local favoritesLabels = {"  Add to Spawnable Favorites  ", "  Remove from Spawnable Favorites  "}
											target.id = spawnID
											ScanApp:DrawFavoritesButton(favoritesLabels, target)
											ImGui.Spacing()
										end

										if ScanApp.userSettings.experimental and not(target.handle:IsVehicle()) then
											if ImGui.SmallButton("  Swap Model  ") then
												popupDelegate = ScanApp:OpenPopup("Model Swap")
											end

											ScanApp:BeginPopup("Model Swap", target.id, false, popupDelegate, style)
											ImGui.SameLine()
										end

										if ScanApp.userSettings.experimental then
											if ImGui.SmallButton("  Despawn  ") then
												target.handle:Dispose()
											end
										end

										ScanApp.Theme:Separator()

										if target.options ~= nil then
											ScanApp.Theme:TextColored("List of Appearances:")
											ImGui.Spacing()

											x = 0
											for _, appearance in ipairs(target.options) do
												local len = ImGui.CalcTextSize(appearance)
												if len > x then x = len end
											end

											y = ImGui.GetFontSize() * 20
	 							    	if ImGui.BeginChild("Scrolling", x + 50, 400) then
	 								    	for i, appearance in ipairs(target.options) do
	 								    		if (ImGui.Button(appearance)) then
														local custom = ScanApp:GetCustomAppearanceParams(appearance)

														if #custom > 0 then
															ScanApp:ChangeScanCustomAppearanceTo(target, custom)
														else
	 								    				ScanApp:ChangeScanAppearanceTo(target, appearance)
														end
	 								    		end
	 								    	end

	 								    end

	 								    ImGui.EndChild()
		 								end
		 							else
		 				    		ImGui.PushTextWrapPos()
		 				    		ImGui.TextColored(1, 0.16, 0.13, 0.75,tabs[tab].errorMessage)
		 				    		ImGui.PopTextWrapPos()
		 				    	end
		 					ImGui.EndTabItem()
		 					end
		 				end
		 				-- End of Tab Constructor --

						-- Spawn Tab --
						if (ImGui.BeginTabItem("Spawn")) then
							ScanApp.settings = true

							ScanApp.searchQuery = ImGui.InputTextWithHint(" ", "Search", ScanApp.searchQuery, 100)

							if ScanApp.searchQuery ~= '' then
								ImGui.SameLine(410)
								if ImGui.Button("Clear") then
									ScanApp.searchQuery = ''
								end
							end

							ImGui.Separator()

							if next(ScanApp.spawnedNPCs) ~= nil then
								ScanApp.Theme:TextColored("Active NPC Spawns "..ScanApp.spawnsCounter.."/"..ScanApp.maxSpawns)

								for _, spawn in pairs(ScanApp.spawnedNPCs) do
									local nameLabel = spawn.name
									ImGui.Text(nameLabel)

									-- Spawned NPC Actions --
									local favoritesLabels = {"Favorite", "Unfavorite"}
									ScanApp:DrawFavoritesButton(favoritesLabels, spawn)

									ImGui.SameLine()
									if spawn.handle ~= '' and not(spawn.handle:IsVehicle()) then
										if ImGui.SmallButton("Respawn##"..spawn.name) then
											ScanApp:DespawnNPC(spawn.uniqueName(), spawn.entityID)
											ScanApp:SpawnNPC(spawn)
										end
									end

									ImGui.SameLine()
									if ImGui.SmallButton("Despawn##"..spawn.name) then
										if spawn.handle ~= '' and spawn.handle:IsVehicle() then
											ScanApp:DespawnVehicle(spawn)
										else
											ScanApp:DespawnNPC(spawn.uniqueName(), spawn.entityID)
										end
									end

									if spawn.handle ~= '' and not(spawn.handle:IsVehicle()) and not(spawn.handle:IsDead()) and ScanApp:CanBeHostile(spawn.handle) then

										local hostileButtonLabel = "Hostile"
										if not(spawn.handle.isPlayerCompanionCached) then
											hostileButtonLabel = "Friendly"
										end

										ImGui.SameLine()
										if ImGui.SmallButton(hostileButtonLabel.."##"..spawn.name) then
											ScanApp:ToggleHostile(spawn)
										end

										ImGui.SameLine()
										if ImGui.SmallButton("Equipment".."##"..spawn.name) then
											popupDelegate = ScanApp:OpenPopup(spawn.name.."'s Equipment")
										end

										ScanApp:BeginPopup(spawn.name.."'s Equipment", spawn.path, false, popupDelegate, style)
									end
								end
							end

							ScanApp.Theme:TextColored("Select To Spawn:")

							if ScanApp.searchQuery ~= '' then
								local entities = {}
								local query = "SELECT * FROM entities WHERE entity_name LIKE '%"..ScanApp.searchQuery.."%' ORDER BY entity_name ASC"
								for en in db:nrows(query) do
									table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path})
								end

								if #entities ~= 0 then
									ScanApp:DrawEntitiesButtons(entities, 'ALL', style)
								else
									ImGui.Text("No Results")
								end
							else
								y = ImGui.GetFontSize() * 40
								if ImGui.BeginChild("Categories", ImGui.GetWindowContentRegionWidth(), y) then
									for _, category in ipairs(ScanApp.categories) do
										if(ImGui.CollapsingHeader(category.cat_name)) then
											local entities = {}
											local noFavorites = true
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

											-- Temporary Johnny and Nibbles workaround
											if category.cat_id == 28 then
												table.insert(entities, {"Johnny Silverhand", "0xC886A091, 29", 0, nil, TweakDBID.new(0xC886A091, 29)})
												table.insert(entities, {"Nibbles", "0x5FAE2DB7, 18", 0, nil, TweakDBID.new(0x5FAE2DB7, 18)})
											end

											local query = f("SELECT * FROM entities WHERE cat_id == '%s' ORDER BY entity_name ASC", category.cat_id)
											for en in db:nrows(query) do
												table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path})
											end

											ScanApp:DrawEntitiesButtons(entities, category.cat_name, style)
										end
									end
								end
								ImGui.EndChild()
							end

							ImGui.EndTabItem()
						end

						-- Settings Tab --
		 				if (ImGui.BeginTabItem("Settings")) then

		 					ImGui.Spacing()

							ScanApp.spawnAsCompanion = ImGui.Checkbox("Spawn As Companion", ScanApp.spawnAsCompanion)
							ScanApp.isCompanionInvulnerable = ImGui.Checkbox("Invulnerable Companion", ScanApp.isCompanionInvulnerable)
							ScanApp.userSettings.openWithOverlay, clicked = ImGui.Checkbox("Open With CET Overlay", ScanApp.userSettings.openWithOverlay)
							ScanApp.userSettings.autoResizing, clicked = ImGui.Checkbox("Auto-Resizing Window", ScanApp.userSettings.autoResizing)
							ScanApp.userSettings.experimental, expClicked = ImGui.Checkbox("Experimental/Fun stuff", ScanApp.userSettings.experimental)

							if ScanApp.userSettings.experimental then
								ImGui.PushItemWidth(139)
								ScanApp.maxSpawns = ImGui.InputInt("Max Spawns", ScanApp.maxSpawns, 1)
								ImGui.PopItemWidth()
							end

							if clicked then ScanApp:UpdateSettings() end

							if expClicked then
								ScanApp:UpdateSettings()
								ScanApp.categories = ScanApp:GetCategories()

								if ScanApp.userSettings.experimental then
									popupDelegate = ScanApp:OpenPopup("Experimental")
								end
							end

							ScanApp.Theme:Separator()

							if ScanApp.userSettings.experimental then
								if (ImGui.Button("Revert All Model Swaps")) then
			 						ScanApp:RevertTweakDBChanges(true)
			 					end

								ImGui.SameLine()
								if (ImGui.Button("Respawn All")) then
			 						ScanApp:RespawnAll()
			 					end
							end


							if (ImGui.Button("Force Despawn All")) then
		 						ScanApp:DespawnAll(true)
		 					end

		 					if (ImGui.Button("Clear All Saved Appearances")) then
								popupDelegate = ScanApp:OpenPopup("Appearances")
		 					end

							if (ImGui.Button("Clear All Favorites")) then
								popupDelegate = ScanApp:OpenPopup("Favorites")
		 					end

							ScanApp:BeginPopup("WARNING", nil, true, popupDelegate, style)

		 					ScanApp.Theme:Separator()

							if ScanApp.settings then
								if ImGui.BeginListBox("Themes") then
			 						for _, theme in ipairs(ScanApp.Theme.userThemes) do
			 							if (ScanApp.selectedTheme == theme.name) then selected = true else selected = false end
			 							if(ImGui.Selectable(theme.name, selected)) then
			 								ScanApp.selectedTheme = theme.name
			 							end
			 						end
		 						end

								ImGui.EndListBox()

								if ImGui.SmallButton("  Create Theme  ") then
									ScanApp.Editor:Setup()
									ScanApp.Editor.isEditing = true
								end

								-- ImGui.SameLine()
								-- if ImGui.SmallButton("  Delete Theme  ") then
								-- 	print(os.remove("test.txt"))
								-- end
							end
							ScanApp.Theme:Separator()

							ImGui.Text("Current Version: "..ScanApp.currentVersion)

							ScanApp.settings = true
		 					ImGui.EndTabItem()
		 				end

						if ScanApp.Editor.isEditing then
							ScanApp.Editor:Draw(ScanApp)
						end

		 				-- DEBUG Tab --
						if ScanApp.Debug ~= '' then
							ScanApp.Debug.CreateTab(ScanApp, target)
		 				end
					end
				end
			end
				ScanApp.Theme:End()
	 	    ImGui.End()
	 	end
	end)

   return ScanApp
end

-- ScanApp Objects
function ScanApp:NewSpawn(name, id, parameters, companion, path)
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
		obj.path = path..self:GetPlayerGender()
		obj.parameters = nil
	end
	return obj
end

function ScanApp:NewTarget(handle, targetType, id, name, app, options)
	local obj = {}
	obj.handle = handle
	obj.id = id
	obj.name = name
	obj.appearance = app
	obj.type = targetType
	obj.options = options or nil

	-- Check if model is swappedModels
	if self.swappedModels[obj.id] ~= nil and self.swappedModels[obj.id] ~= '' then
		obj.id = self.swappedModels[obj.id][1]
	end

	-- Check if custom appearance is active
	if self.activeCustomApps[obj.id] ~= nil then
		obj.appearance = self.activeCustomApps[obj.id]
	end

	return obj
end

-- End Objects --

-- ScanApp Methods --
function ScanApp:CheckDBVersion()
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

function ScanApp:FinishUpdate()
	finishedUpdate = true
	db:execute(f("UPDATE metadata SET current_version = '%s'", self.currentVersion))
end

function ScanApp:ImportUserData()
	local file = io.open("User/user.json", "r")
	if file then
		local contents = file:read( "*a" )
		local userData = json.decode(contents)
		self.selectedTheme = userData['selectedTheme']
		for _, obj in ipairs(userData['settings']) do
			db:execute(f("UPDATE settings SET setting_name = '%s', setting_value = %i WHERE setting_name = '%s'", obj.setting_name, boolToInt( obj.setting_value),  obj.setting_name))
		end
		for _, obj in ipairs(userData['favorites']) do
			local command = f("INSERT INTO favorites (position, entity_id, entity_name, parameters) VALUES (%i, '%s', '%s', '%s')", obj.position, obj.entity_id, obj.entity_name, obj.parameters)
			command = command:gsub("'nil'", "NULL")
			db:execute(command)
		end
		for _, obj in ipairs(userData['saved_appearances']) do
			db:execute(f("INSERT INTO saved_appearances (entity_id, app_name) VALUES ('%s', '%s')", obj.entity_id, obj.app_name))
		end
	end
end

function ScanApp:ExportUserData()
	local file = io.open("User/user.json", "w")
	if file then
		local userData = {}
		userData['settings'] = {}
		for r in db:nrows("SELECT * FROM settings") do
			table.insert(userData['settings'], {setting_name = r.setting_name, setting_value = intToBool(r.setting_value)})
		end
		userData['favorites'] = {}
		for r in db:nrows("SELECT * FROM favorites") do
			table.insert(userData['favorites'], {position = r.position, entity_id = r.entity_id, entity_name = r.entity_name, parameters = r.parameters})
		end
		userData['saved_appearances'] = {}
		for r in db:nrows("SELECT * FROM saved_appearances") do
			table.insert(userData['saved_appearances'], {entity_id = r.entity_id, app_name = r.app_name})
		end
		userData['selectedTheme'] = self.selectedTheme

		local contents = json.encode(userData)
		file:write(contents)
		file:close()
	end
end

function ScanApp:GetCategories()
	local query = "SELECT * FROM categories WHERE cat_name != 'At Your Own Risk' ORDER BY 3 ASC"
	if ScanApp.userSettings.experimental then
		query = "SELECT * FROM categories ORDER BY 3 ASC"
	end

	local categories = {}
	for category in db:nrows(query) do
		table.insert(categories, {cat_id = category.cat_id, cat_name = category.cat_name})
	end
	return categories
end

function ScanApp:GetSaveables()
	local defaults = {
		'0xB1B50FFA, 14', '0xC67F0E01, 15', '0x73C44EBA, 15', '0xA1C78C30, 16', '0x7F65F7F7, 16',
		'0x7B2CB67C, 17', '0x3024F03E, 15', '0x3B6EF8F9, 13', '0x413F60A6, 15', '0x62B8D0FA, 15',
		'0x3143911D, 15', '0xF0F54969, 24', '0x0044E64C, 20', '0xF43B2B48, 18', '0xC111FBAC, 16',
		'0x8DD8F2E0, 35', '0x4106744C, 35', '0xB98FDBB8, 14', '0x6B0544AD, 26', '0x215A57FC, 17'
	}

	return defaults
end

function ScanApp:GetEquipmentOptions()
	local equipments = {
		{name = 'Katana', path = 'Character.afterlife_rare_fmelee3_katana_wa_elite_inline0'},
		{name = 'Mantis Blades', path = 'Character.afterlife_rare_fmelee3_mantis_ma_elite_inline0'},
		{name = 'Machete', path = 'Character.aldecaldos_grunt2_melee2__ma_inline0'},
		{name = 'Hammer', path = 'Character.maelstrom_grunt2_melee2_hammer_wa_inline0'},
		{name = 'Baton', path = 'Character.animals_bouncer1_melee1_baton_mb_inline0'},
		{name = 'Knife', path = 'Character.tyger_claws_gangster1_melee1_knife_wa_inline2'},
		{name = 'Crowbar', path = 'Character.wraiths_grunt2_melee2_crowbar_ma_inline0'},
		{name = 'Baseball Bat', path = 'Character.animals_grunt1_melee1_baseball_mb_inline0'},
		{name = 'Assault Rifle', path = 'Character.afterlife_rare_franged2_ajax_wa_rare_inline0'},
		{name = 'Sidewinder', path = 'Character.tyger_claws_gangster2_ranged2_sidewinder_wa_inline2'},
		{name = 'Sniper Rifle', path = 'Character.afterlife_rare_sniper3_ashura_ma_elite_inline0'},
		{name = 'Shotgun', path = 'Character.afterlife_rare_fshotgun3_zhuo_mb_elite_inline0'},
		{name = 'SMG', path = 'Character.afterlife_rare_franged2_saratoga_ma_rare_inline0'},
		{name = 'Handgun', path = 'Character.afterlife_rare_franged2_overture_wa_rare_inline0'},
	}

	return equipments
end

function ScanApp:GetEntityTemplates()
	local templates = {
		['0xB1B50FFA, 14'] = '', ['0xC67F0E01, 15'] = '',
		['0x7B2CB67C, 17'] = '', ['0xC111FBAC, 16'] = '',
		['0x73C44EBA, 15'] = '', ['0x3B6EF8F9, 13'] = '',
		['0xA1C78C30, 16'] = '', ['0xF43B2B48, 18'] = '',
		['0x3024F03E, 15'] = '', ['0xAD1FC6DE, 15'] = '',
		['0x4106744C, 35'] = '', ['0x8DD8F2E0, 35'] = '',
		['0xC8227C45, 33'] = '', ['0x349E3563, 33'] = '',
		['0x7EE3CE36, 16'] = '', ['0xBF76C44D, 29'] = '',
		['0xA22A7797, 15'] = '', ['0x4FA1C211, 15'] = ''
	}

	return templates
end

function ScanApp:ChangeEntityTemplateTo(fromID, toID)
	toPath = ''
	for path in db:urows(f("SELECT entity_path FROM entities WHERE entity_id = '%s'", toID)) do
		toPath = path
	end
	fromPath = ''
	for path in db:urows(f("SELECT entity_path FROM entities WHERE entity_id = '%s'", fromID)) do
		fromPath = path
	end

	toTemplate = TweakDB:GetFlat(TweakDBID.new(toPath..".entityTemplatePath"))
	if self.swappedModels[toID] ~= '' then
		toTemplate = self.swappedModels[toID][2]
		self.swappedModels[toID] = ''
	else
		originalTemplate = TweakDB:GetFlat(TweakDBID.new(fromPath..".entityTemplatePath"))
		self.swappedModels[fromID] = {toID, originalTemplate}
	end

	TweakDB:SetFlat(TweakDBID.new(fromPath..".entityTemplatePath"), toTemplate)
	TweakDB:Update(TweakDBID.new(fromPath))
end

function ScanApp:RevertTweakDBChanges(userActivated)
	for id, template in pairs(ScanApp.swappedModels) do
		if template ~= '' then
			self:ChangeEntityTemplateTo(id, id)
		end
	end

	if not(userActivated) then
		TweakDB:SetFlat(TweakDBID.new('Vehicle.vehicle_list.list'), ScanApp.originalVehicles)
	end
end

function ScanApp:SetupVehicleData()
	local unlockableVehicles = TweakDB:GetFlat(TweakDBID.new('Vehicle.vehicle_list.list'))
	ScanApp.originalVehicles = unlockableVehicles
	for vehicle in db:urows("SELECT entity_path FROM entities WHERE cat_id = 24") do
		table.insert(unlockableVehicles, TweakDBID.new(vehicle))
	end

	TweakDB:SetFlat(TweakDBID.new('Vehicle.vehicle_list.list'), unlockableVehicles)
end

function ScanApp:UnlockVehicle(handle)
	handle:GetVehiclePS():UnlockAllVehDoors()
end

function ScanApp:SpawnVehicle(spawn)
	local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	vehicleGarageId.recordID = TweakDBID.new(spawn.path)
	Game.GetVehicleSystem():ToggleSummonMode()
	Game.GetVehicleSystem():TogglePlayerActiveVehicle(vehicleGarageId, 'Car', true)
	Game.GetVehicleSystem():SpawnPlayerVehicle('Car')
	Game.GetVehicleSystem():ToggleSummonMode()

	self.spawnedNPCs[spawn.uniqueName()] = spawn
	self.currentSpawn = spawn.uniqueName()
end

function ScanApp:DespawnVehicle(spawn)
	local vehicleGarageId = NewObject('vehicleGarageVehicleID')
	vehicleGarageId.recordID = TweakDBID.new(spawn.path)
	Game.GetVehicleSystem():DespawnPlayerVehicle(vehicleGarageId)
	self.spawnedNPCs[spawn.uniqueName()] = nil
end

function ScanApp:GetNPCTweakDBID(npc)
	if type(npc) == 'userdata' then return npc end
	return TweakDBID.new(npc)
end

function ScanApp:SpawnNPC(spawn)
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

function ScanApp:DespawnNPC(npcName, spawnID)
	--Game.GetPlayer():SetWarningMessage(npcName:match("(.+)##(.+)").." will despawn once you look away")
	self.spawnedNPCs[npcName] = nil
	self.spawnsCounter = self.spawnsCounter - 1
	local handle = Game.FindEntityByID(spawnID)
	if handle then handle:Dispose() end
	Game.GetPreventionSpawnSystem():RequestDespawn(spawnID)
end

function ScanApp:DespawnAll(message)
	if message then Game.GetPlayer():SetWarningMessage("Despawning will occur once you look away") end
	Game.GetPreventionSpawnSystem():RequestDespawnPreventionLevel(-1)
	self.spawnsCounter = 0
	self.spawnedNPCs = {}
end

function ScanApp:RespawnAll()
	 respawnAllPressed = true
end

function ScanApp:PrepareSettings()
	local settings = {}
	for r in db:nrows("SELECT * FROM settings") do
		settings[r.setting_name] = intToBool(r.setting_value)
	end
	return settings
end

function ScanApp:UpdateSettings()
	for name, value in pairs(self.userSettings) do
		db:execute(f("UPDATE settings SET setting_value = %i WHERE setting_name = '%s'", boolToInt(value), name))
	end
end

function ScanApp:CheckSavedAppearance(t)
	local handle, currentApp, savedApp
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
		if count ~= 0 then
			custom = self:GetCustomAppearanceParams(savedApp)
			self:ChangeScanCustomAppearanceTo(t, custom)
		else
			self:ChangeScanAppearanceTo(t, savedApp)
		end
	end
end

function ScanApp:ClearSavedAppearance(t)
	if self.currentTarget ~= '' then
		if t.appearance ~= self.currentTarget.appearance then
			self:ChangeScanAppearanceTo(t, self.currentTarget.appearance)
		end
	end

	db:execute(f("DELETE FROM saved_appearances WHERE entity_id = '%s'", t.id))

end

function ScanApp:ClearAllSavedAppearances()
	db:execute("DELETE FROM saved_appearances")
end

function ScanApp:ClearAllFavorites()
	db:execute("DELETE FROM favorites; UPDATE sqlite_sequence SET seq = 0")
end

function ScanApp:SaveAppearance(t)
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

function ScanApp:GetNPCName(t)
	n = t:GetTweakDBDisplayName(true)
	return n
end

function ScanApp:GetVehicleName(t)
	return tostring(t:GetDisplayName())
end

function ScanApp:GetScanID(t)
	tdbid = t:GetRecordID()
	hash = tostring(tdbid):match("= (%g+),")
	length = tostring(tdbid):match("= (%g+) }")
	return hash..", "..length
end

function ScanApp:SetCurrentTarget(t)
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

function ScanApp:GetAppearanceOptions(t)
	local options = {}

	if t:IsNPC() then
		if t:GetRecord():CrowdAppearanceNames()[1] ~= nil then
			for _, app in ipairs(t:GetRecord():CrowdAppearanceNames()) do
				table.insert(options, tostring(app):match("%[ (%g+) -"))
			end
			return options
		end
	end

	scanID = self:GetScanID(t)
	if self.swappedModels[scanID] ~= nil and self.swappedModels[scanID] ~= '' then
	 	scanID = self.swappedModels[scanID][1]
	end

	for app in db:urows(f("SELECT DISTINCT app_name FROM custom_appearances WHERE entity_id = '%s'", scanID)) do
		table.insert(options, app)
	end

	for app in db:urows(f("SELECT app_name FROM appearances WHERE entity_id = '%s'", scanID)) do
		table.insert(options, app)
	end

	if next(options) ~= nil then
		return options -- array of appearances names
	end

	return nil
end

function ScanApp:GetScanAppearance(t)
	return tostring(t:GetCurrentAppearanceName()):match("%[ (%g+) -")
end

function ScanApp:GetCustomAppearanceParams(appearance)
	local custom = {}
	for app in db:nrows(f("SELECT * FROM custom_appearances WHERE app_name = '%s'", appearance)) do
		table.insert(custom, app)
	end
	return custom
end

function ScanApp:ChangeScanCustomAppearanceTo(t, customAppearance)
	self:ChangeScanAppearanceTo(t, customAppearance[1].app_base)
	self.setCustomApp = {t.handle, customAppearance}
	self.activeCustomApps[t.id] = customAppearance[1].app_name
end

function ScanApp:ChangeScanAppearanceTo(t, newAppearance)
	if not(string.find(t.name, 'Mech')) then
		t.handle:PrefetchAppearanceChange(newAppearance)
		t.handle:ScheduleAppearanceChange(newAppearance)

		if self.activeCustomApps[t.id] ~= nil then
			self.activeCustomApps[t.id] = nil
		end
	end
end

function ScanApp:GetTarget()
	if Game.GetPlayer() then
		target = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(),false,false)
		if target ~= nil then
			if target:IsNPC() then
				t = ScanApp:NewTarget(target, "NPC", ScanApp:GetScanID(target), ScanApp:GetNPCName(target),ScanApp:GetScanAppearance(target), ScanApp:GetAppearanceOptions(target))
			elseif target:IsVehicle() then
				t = ScanApp:NewTarget(target, "Vehicles", ScanApp:GetScanID(target), ScanApp:GetVehicleName(target),ScanApp:GetScanAppearance(target), ScanApp:GetAppearanceOptions(target))
			end

			if t ~= nil then
				ScanApp:SetCurrentTarget(t)
				return t
			end
		end
	end

	return nil
end

function ScanApp:SetGodMode(entityID, immortal)
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

function ScanApp:ToggleHostile(spawn)
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

function ScanApp:ToggleFavorite(isFavorite, entity)
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
		ScanApp:RearrangeFavoritesIndex(removedIndex)
	end
end

function ScanApp:RearrangeFavoritesIndex(removedIndex)
	local lastIndex = 0
	query = "SELECT seq FROM sqlite_sequence"
	for i in db:urows(query) do lastIndex = i end

	if lastIndex ~= removedIndex then
		for i = removedIndex, lastIndex - 1 do
			db:execute(f("UPDATE favorites SET position = %i WHERE position = %i", i, i + 1))
		end
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i", lastIndex - 1))
end

-- Companion methods -- original code by Catmino
function ScanApp:SetNPCAsCompanion(npcHandle)
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
		--Game['AIHumanComponent::SetCurrentRole;GameObjectAIRole'](targCompanion, roleComp)
		targetAttAgent:SetAttitudeGroup(CName.new("player"))
		roleComp.attitudeGroupName = CName.new("player")
		Game['senseComponent::RequestMainPresetChange;GameObjectString'](targCompanion, "Follower")
		Game['senseComponent::ShouldIgnoreIfPlayerCompanion;EntityEntity'](targCompanion, Game:GetPlayer())
		Game['NPCPuppet::ChangeStanceState;GameObjectgamedataNPCStanceState'](targCompanion, "Relaxed")
		targCompanion.isPlayerCompanionCached = true
		targCompanion.isPlayerCompanionCachedTimeStamp = currTime

		AIC:SetAIRole(roleComp)
		targCompanion.movePolicies:Toggle(true)
	end
end

function ScanApp:ChangeNPCEquipment(npcPath, equipmentPath)
	TweakDB:SetFlat(TweakDBID.new(npcPath..".primaryEquipment"), TweakDBID.new(equipmentPath))
	TweakDB:Update(TweakDBID.new(npcPath))
end

-- Helper methods
function ScanApp:IsUnique(npcID)
	for _, v in ipairs(self.allowedNPCs) do
		if npcID == v then
			-- NPC is unique
			return true
		end
	end
end

function ScanApp:CanBeHostile(t)
	local canBeHostile = t:GetRecord():AbilitiesContains(GetSingleton("gamedataTweakDBInterface"):GetGameplayAbilityRecord(TweakDBID.new("Ability.CanCloseCombat")))
	if not(canBeHostile) then
		canBeHostile = t:GetRecord():AbilitiesContains(GetSingleton("gamedataTweakDBInterface"):GetGameplayAbilityRecord(TweakDBID.new("Ability.HasChargeJump")))
	end

	return canBeHostile
end

function ScanApp:IsSpawnable(t)
	local spawnableID = nil

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

function ScanApp:ShouldDrawSaveButton(t)
	if t.handle:IsNPC() then
		local npcID = self:GetScanID(t.handle)
		if ScanApp:IsUnique(npcID) then
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

function ScanApp:OpenPopup(name)
	local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)

	local popupDelegate = {message = '', buttons = {}}
	if string.find(name, "Equipment") then
		ImGui.SetNextWindowSize(400, 520)
		popupDelegate.message = "Select "..name..":"
		for _, equipment in ipairs(self.equipmentOptions) do
			table.insert(popupDelegate.buttons, {label = equipment.name, action = function(fromPath) ScanApp:ChangeNPCEquipment(fromPath, equipment.path) end})
		end
	elseif name == 'Model Swap' then
		ImGui.SetNextWindowSize(400, 520)
		popupDelegate.message = "Select Replacement Model\n\nYou will need to reload your save to update changes."
		local templates = ScanApp:GetEntityTemplates()
		for entityID, template in pairs(templates) do
			for name in db:urows(f("SELECT entity_name FROM entities WHERE entity_id = '%s'", entityID)) do
				table.insert(popupDelegate.buttons, {label = name, action = function(fromID) ScanApp:ChangeEntityTemplateTo(fromID, entityID) end})
			end
		end
	elseif name == "Experimental" then
		ImGui.SetNextWindowSize(400, 140)
		popupDelegate.message = "Are you sure you want to enable experimental features? AMM might not work as expected. Use it at your own risk!"
		table.insert(popupDelegate.buttons, {label = "Yes", action = ''})
		table.insert(popupDelegate.buttons, {label = "No", action = function() ScanApp.userSettings.experimental = false end})
		name = "WARNING"
	elseif name == "Favorites" then
		popupDelegate.message = "Are you sure you want to delete all your favorites?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() ScanApp:ClearAllFavorites() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	elseif name == "Appearances" then
		popupDelegate.message = "Are you sure you want to delete all your saved appearances?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() ScanApp:ClearAllSavedAppearances() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	end

	ImGui.OpenPopup(name)
	return popupDelegate
end

function ScanApp:BeginPopup(popupTitle, popupActionArg, popupModal, popupDelegate, style)
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

function ScanApp:SetFavoriteNamePopup(entity)
	local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
	ImGui.SetNextWindowSize(400, ImGui.GetFontSize() * 8)
	ScanApp.currentFavoriteName = entity.name
	ScanApp.popupEntity = entity
	ImGui.OpenPopup("Favorite Name")
end

function ScanApp:DrawFavoritesButton(buttonLabels, entity)
	if entity.parameters == nil then
		entity['parameters'] = entity.appearance
	end

	local isFavorite = 0
	for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_name = '%s'", entity.name)) do
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
		if not(ScanApp:IsUnique(entity.id)) and isFavorite == 0 then
			ScanApp:SetFavoriteNamePopup(entity)
		else
			ScanApp:ToggleFavorite(isFavorite, entity)
		end
	end

	if ImGui.BeginPopupModal("Favorite Name") then
		local style = {
						buttonHeight = ImGui.GetFontSize() * 2,
						halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12)
				}

		if ScanApp.currentFavoriteName == 'existing' then
			ImGui.TextColored(1, 0.16, 0.13, 0.75, "Existing Name")

			if ImGui.Button("Ok", -1, style.buttonHeight) then
				ScanApp.currentFavoriteName = ''
			end
		elseif ScanApp.popupEntity.name == entity.name then
			ScanApp.currentFavoriteName = ImGui.InputText("Name", ScanApp.currentFavoriteName, 30)

			if ImGui.Button("Save", style.halfButtonWidth + 8, style.buttonHeight) then
				local isFavorite = 0
				for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_name = '%s'", self.currentFavoriteName)) do
					isFavorite = fav
				end
				if isFavorite == 0 then
					if entity.type ~= 'Spawn' then -- Target type
						entity.name = ScanApp.currentFavoriteName
					else -- Spawn type
						ScanApp.spawnedNPCs[entity.uniqueName()] = nil
						entity.name = ScanApp.currentFavoriteName
						entity.parameters = ScanApp:GetScanAppearance(entity.handle)
						ScanApp.spawnedNPCs[entity.uniqueName()] = entity
					end
					ScanApp.currentFavoriteName = ''
					ScanApp:ToggleFavorite(isFavorite, entity)
					ScanApp.popupIsOpen = false
					ImGui.CloseCurrentPopup()
				else
					ScanApp.currentFavoriteName = 'existing'
				end
			end

			ImGui.SameLine()
			if ImGui.Button("Cancel", style.halfButtonWidth + 8, style.buttonHeight) then
				ScanApp.currentFavoriteName = ''
				ScanApp.popupIsOpen = false
				ImGui.CloseCurrentPopup()
			end
		end
		ImGui.EndPopup()
	end
end

function ScanApp:DrawArrowButton(direction, entity, index)
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

function ScanApp:DrawButton(title, width, height, action, target)
	if (ImGui.Button(title, width, height)) then
		if action == "Cycle" then
			ScanApp:ChangeScanAppearanceTo(target, 'Cycle')
		elseif action == "Save" then
			ScanApp:SaveAppearance(target)
		elseif action == "Clear" then
			ScanApp:ClearSavedAppearance(target)
		elseif action == "SpawnNPC" then
			ScanApp:SpawnNPC(target)
			buttonPressed = true
		elseif action == "SpawnVehicle" then
			ScanApp:SpawnVehicle(target)
			buttonPressed = true
		end
	end
end

function ScanApp:DrawEntitiesButtons(entities, categoryName, style)

	for i, entity in ipairs(entities) do
		name = entity[1]
		id = entity[2]
		path = entity[5]
		companion = intToBool(entity[3])
		parameters = entity[4]

		local newSpawn = ScanApp:NewSpawn(name, id, parameters, companion, path)
		local buttonLabel = newSpawn.uniqueName()

		local favOffset = 0
		if categoryName == 'Favorites' then
			favOffset = 40

			ScanApp:DrawArrowButton("up", newSpawn, i)
			ImGui.SameLine()
		end

		local isFavorite = 0
		for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_id = '%s'", id)) do
			isFavorite = fav
		end

		if self.spawnsCounter == self.maxSpawns or (categoryName == 'Favorites' and ScanApp.spawnedNPCs[buttonLabel] and isFavorite ~= 0) then
			ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
			ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
			ScanApp:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, "Disabled", nil)
			ImGui.PopStyleColor(3)
		elseif not(ScanApp.spawnedNPCs[buttonLabel] ~= nil and ScanApp:IsUnique(newSpawn.id)) then
			local action = "SpawnNPC"
			if string.find(tostring(newSpawn.path), "Vehicle") then action = "SpawnVehicle" end
			ScanApp:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, action, newSpawn)
		end

		if categoryName == 'Favorites' then
			ImGui.SameLine()
			ScanApp:DrawArrowButton("down", newSpawn, i)
		end
	end
end

function ScanApp:IsPlayerInAnyMenu()
    blackboard = Game.GetBlackboardSystem():Get(Game.GetAllBlackboardDefs().UI_System)
    uiSystemBB = (Game.GetAllBlackboardDefs().UI_System)
    return(blackboard:GetBool(uiSystemBB.IsInMenu))
end

function ScanApp:GetPlayerGender()
  -- True = Female / False = Male
  if string.find(tostring(Game.GetPlayer():GetResolvedGenderName()), "Female") then
		return "_Female"
	else
		return "_Male"
	end
end

-- End of ScanApp Class

return ScanApp:new()
