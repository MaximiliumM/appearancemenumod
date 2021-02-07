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

	 -- Load DB --
	 ScanApp.currentVersion = "1.6.1"
	 ScanApp.DBUpdateCounter = 0
	 ScanApp.DBTotalCount = 8166
	 ScanApp.DBHasChanges = false
	 ScanApp.DBUpdateContent = {}
	 ScanApp:CheckDB()

	 -- Load Debug --
	 if io.open("debug.lua", "r") then
		 ScanApp.Debug = require("debug.lua")
	 else
		 ScanApp.Debug = ''
	 end

	 -- Main Properties --
	 ScanApp.userSettings = ScanApp:PrepareSettings()
	 ScanApp.categories = ScanApp:GetCategories()
	 ScanApp.currentTarget = ''
	 ScanApp.spawnedNPCs = {}
	 ScanApp.entitiesForRespawn = ''
	 ScanApp.allowedNPCs = ScanApp:GetSaveables()
	 ScanApp.searchQuery = ''

	 -- Configs --
	 ScanApp.settings = false
	 ScanApp.windowWidth = 600
	 ScanApp.roleComp = ''
	 ScanApp.currentSpawn = ''
	 ScanApp.maxSpawns = 5
	 ScanApp.spawnsCounter = 0
	 ScanApp.spawnAsCompanion = true
	 ScanApp.isCompanionInvulnerable = true
	 ScanApp.IsJohnny = false
	 ScanApp.shouldCheckSavedAppearance = true

	 registerForEvent("onInit", function()
		 waitTimer = 0.0
		 spamTimer = 0.0
		 respawnTimer = 0.0
		 buttonPressed = false
		 respawnAllPressed = false
		 finishedUpdate = true
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
		 		-- Populate DB Changes --
				ScanApp:UpdateDB()

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

					if buttonPressed then
						spamTimer = spamTimer + deltaTime

						if spamTimer > 0.5 then
							buttonPressed = false
							spamTimer = 0.0
						end
					end

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

					if ScanApp.currentSpawn ~= '' and not(ScanApp.IsJohnny) then
						waitTimer = waitTimer + deltaTime
						-- print('trying to set companion')
						if waitTimer > 0.2 then
							local handle = Game.FindEntityByID(ScanApp.spawnedNPCs[ScanApp.currentSpawn].entityID)
							if handle then
								ScanApp.spawnedNPCs[ScanApp.currentSpawn].handle = handle
								if handle:IsNPC() then
									if ScanApp.spawnedNPCs[ScanApp.currentSpawn].parameters ~= nil then
										ScanApp:ChangeScanAppearanceTo(ScanApp.spawnedNPCs[ScanApp.currentSpawn], ScanApp.spawnedNPCs[ScanApp.currentSpawn].parameters)
									end
									if ScanApp.spawnAsCompanion then
										ScanApp:SetNPCAsCompanion(handle)
									else
										ScanApp.currentSpawn = ''
									end
								elseif handle:IsVehicle() then
									handle:GetVehiclePS():UnlockAllVehDoors()
									waitTimer = 0.0
									ScanApp.currentSpawn = ''
								else
									ScanApp.currentSpawn = ''
								end
							end
						end
					else
						ScanApp.IsJohnny = false
						ScanApp.currentSpawn = ''
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

		local shouldResize = ImGuiCond.None
		if not(ScanApp.userSettings.autoResizing) then
			shouldResize = ImGuiCond.Appearing
		end

	 	if drawWindow then
			if ScanApp.Debug ~= '' then
				ImGui.SetNextWindowSize(600, 700)
			elseif (target ~= nil) and (target.options ~= nil) or (ScanApp.settings == true) then
				ImGui.SetNextWindowSize(ScanApp.windowWidth, 700, shouldResize)
			else
				ImGui.SetNextWindowSize(ScanApp.windowWidth, 160, shouldResize)
			end

			ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.7, 0.3, 0.7)
			ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.06, 0.04, 0.06, 0.85)
			ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.57, 0.17, 0.16, 0.5)
 			ImGui.PushStyleColor(ImGuiCol.Border, 0.8, 0.7, 0.2, 0.4)
 			ImGui.PushStyleColor(ImGuiCol.Tab, 0.8, 0.54, 0.2, 0.55)
 	    ImGui.PushStyleColor(ImGuiCol.TabHovered, 0.66, 0.16, 0.13, 0.75)
 	    ImGui.PushStyleColor(ImGuiCol.TabActive, 0.60, 0.44, 0.2, 1)
 	    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0.06, 0.04, 0.06, 0.8)
 	    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0.8, 0.54, 0.2, 0.5)
 	    ImGui.PushStyleColor(ImGuiCol.TitleBgCollapsed, 0.56, 0.06, 0.03, 0.25)
 	    ImGui.PushStyleColor(ImGuiCol.Button, 0.8, 0.54, 0.2, 0.5)
 	    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.66, 0.16, 0.13, 0.75)
 	    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 1)
 	    ImGui.PushStyleColor(ImGuiCol.ResizeGrip, 0, 0, 0, 0)
 	    ImGui.PushStyleColor(ImGuiCol.ResizeGripHovered, 0.8, 0.7, 0.2, 0.5)
 	    ImGui.PushStyleColor(ImGuiCol.ResizeGripActive, 0.56, 0.06, 0.03, 1)
			ImGui.PushStyleColor(ImGuiCol.CheckMark, 0.70, 0.54, 0.2, 1)
			ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 1)

			if (ImGui.Begin("Appearance Menu Mod")) then

				if not(finishedUpdate) then
					ImGui.Text("Updating Database. Please wait...")
					ImGui.ProgressBar(((ScanApp.DBUpdateCounter * 100) / ScanApp.DBTotalCount) / 100, ScanApp.windowWidth, 25)
				else
						-- Target Setup --
						target = ScanApp:GetTarget()

						ImGui.SetWindowFontScale(1)

						if (ImGui.BeginTabBar("TABS")) then

		 					local style = {
		 									buttonWidth = -1,
		 									buttonHeight = 30,
		 									halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 12)
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
		 	    				errorMessage = "No NPC Found! Look at NPC to begin"
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
		 	    				errorMessage = "No Vehicle Found! Look at Vehicle to begin"
		 	    			}
		 	    		}

		 	    		-- Tab Constructor --
		 	    		tabOrder = {"NPC", "Vehicles"}

		 	    		for _, tab in ipairs(tabOrder) do
		 		    		if (ImGui.BeginTabItem(tab)) then
		 		    			ScanApp.settings = false

		 							if target ~= nil and target.type == tab then
		 					    		ImGui.TextColored(0.3, 0.5, 0.7, 1, tabs[tab].currentTitle)
		 					    		ImGui.Text(target.appearance)
		 					    		x, y = ImGui.CalcTextSize(target.appearance)
		 									if x > 150 then
		 					    			windowWidth = x + 40
		 									end

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
		 										ImGui.TextColored(0.3, 0.5, 0.7, 1, "Saved Appearance:")
		 						    		ImGui.Text(savedApp)
		 										ScanApp:DrawButton("Clear Saved Appearance", style.buttonWidth, style.buttonHeight, "Clear", target)
		 									end

		 						    	ImGui.NewLine()
		 									ImGui.Separator()
											ImGui.Spacing()

		 						    	if target.options ~= nil then
		 						    		ImGui.TextColored(0.3, 0.5, 0.7, 1, target.name.."   ")

												ImGui.Spacing()

												local spawnID = ScanApp:IsSpawnable(target)
												if spawnID ~= nil then
													local favoritesLabels = {"  Add to Spawnable Favorites  ", "  Remove from Spawnable Favorites  "}
													target.id = spawnID
													ScanApp:DrawFavoritesButton(favoritesLabels, target)
												end

												ImGui.Spacing()
												ImGui.Separator()


		 							    	if (ImGui.BeginChild("Scrolling")) then
		 								    	for i, appearance in ipairs(target.options) do
		 								    		x, y = ImGui.CalcTextSize(appearance)
		 								    		if (x > self.windowWidth) then self.windowWidth = x + 40 end
		 								    		if (ImGui.Button(appearance)) then
		 								    			ScanApp:ChangeScanAppearanceTo(target, appearance)
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

							ImGui.Separator()

							if next(ScanApp.spawnedNPCs) ~= nil then
								ImGui.TextColored(0.3, 0.5, 0.7, 1, "Active Spawns "..ScanApp.spawnsCounter.."/"..ScanApp.maxSpawns)

								for _, spawn in pairs(ScanApp.spawnedNPCs) do
									local nameLabel = spawn.name
									if spawn.parameters ~= "Vehicles" and not(spawn.canBeCompanion) then nameLabel = spawn.name:match("(.+) %((.+)") end
									ImGui.Text(nameLabel)

									local favoritesLabels = {"Favorite", "Unfavorite"}
									ScanApp:DrawFavoritesButton(favoritesLabels, spawn)

									ImGui.SameLine()
									if ImGui.SmallButton("Respawn##"..spawn.name) then
										ScanApp:DespawnNPC(spawn.uniqueName, spawn.entityID)
										ScanApp:SpawnNPC(spawn)
									end

									ImGui.SameLine()
									if ImGui.SmallButton("Despawn##"..spawn.name) then
										ScanApp:DespawnNPC(spawn.uniqueName, spawn.entityID)
									end

									if spawn.handle ~= '' and not(spawn.handle:IsDead()) and ScanApp:CanBeHostile(spawn.handle) then

										local hostileButtonLabel = "Hostile"
										if not(spawn.handle.isPlayerCompanionCached) then
											hostileButtonLabel = "Friendly"
										end

										ImGui.SameLine()
										if ImGui.SmallButton(hostileButtonLabel.."##"..spawn.name) then
											ScanApp:ToggleHostile(spawn)
										end
									end
								end
							end

							ImGui.TextColored(0.3, 0.5, 0.7, 1, "Select To Spawn:")

							if ScanApp.searchQuery ~= '' then
								local entities = {}
								local query = "SELECT * FROM entities WHERE entity_name LIKE '"..ScanApp.searchQuery.."%' ORDER BY entity_name ASC"
								for en in db:nrows(query) do
									table.insert(entities, {en.entity_name, en.entity_path, en.can_be_comp, en.parameters})
								end

								if #entities ~= 0 then
									ScanApp:DrawEntitiesButtons(entities, 'ALL', style)
								else
									ImGui.Text("No Results")
								end
							else
								for categoryID, categoryName in pairs(ScanApp.categories) do
									if(ImGui.CollapsingHeader(categoryName)) then
										local entities = {}
										local noFavorites = true
										if categoryName == 'Favorites' then
											local query = "SELECT * FROM favorites"
											for fav in db:nrows(query) do
												query = f("SELECT * FROM entities WHERE entity_id = '%s'", fav.entity_id)
												for en in db:nrows(query) do
													if fav.parameters ~= nil then en.parameters = fav.parameters end
													table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path})
												end
											end
											if #entities == 0 then
												ImGui.Text("It's empty :(")
											end
										end

										local query = f("SELECT * FROM entities WHERE cat_id == '%s' ORDER BY entity_name ASC", categoryID)
										for en in db:nrows(query) do
											table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path})
										end

										-- Temporary Johnny and Nibbles workaround
										if categoryID == 2 then
											table.insert(entities, {"Johnny (can't be companion)", TweakDBID.new(0xC886A091,0x1D), 0, nil})
											table.insert(entities, {"Nibbles (can't be companion)", TweakDBID.new(0x5FAE2DB7,0x12), 0, nil})
										end

										ScanApp:DrawEntitiesButtons(entities, categoryName, style)
									end
								end
							end

							ImGui.EndTabItem()
						end

						-- Settings Tab --
		 				if (ImGui.BeginTabItem("Settings")) then
		 					ScanApp.settings = true

		 					ImGui.Spacing()

							ScanApp.spawnAsCompanion = ImGui.Checkbox("Spawn As Companion", ScanApp.spawnAsCompanion)
							ScanApp.isCompanionInvulnerable = ImGui.Checkbox("Invulnerable Companion", ScanApp.isCompanionInvulnerable)
							ScanApp.userSettings.openWithOverlay, clicked = ImGui.Checkbox("Open With CET Overlay", ScanApp.userSettings.openWithOverlay)
							ScanApp.userSettings.autoResizing, clicked = ImGui.Checkbox("Auto-Resizing Window", ScanApp.userSettings.autoResizing)
							ScanApp.userSettings.experimental, expClicked = ImGui.Checkbox("Experimental/Fun stuff", ScanApp.userSettings.experimental)

							if ScanApp.userSettings.experimental then
								ImGui.PushItemWidth(95)
								ScanApp.maxSpawns = ImGui.InputInt("Max Spawns", ScanApp.maxSpawns, 1)
								ImGui.PopItemWidth()
							end

							if clicked then ScanApp:UpdateSettings() end

							if expClicked then
								ScanApp:UpdateSettings()
								ScanApp.categories = ScanApp:GetCategories()

								if ScanApp.userSettings.experimental then
									local sizeX = ImGui.GetWindowSize()
									local x, y = ImGui.GetWindowPos()
									ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)
									ImGui.SetNextWindowSize(400, 200)
									ImGui.OpenPopup("WARNING")
								end
							end

							if ImGui.BeginPopupModal("WARNING") then
								ImGui.TextWrapped("Are you sure you want to enable experimental features? AMM might not work as expected. Use it at your own risk!")
								if ImGui.Button("Yes", style.halfButtonWidth - 192, style.buttonHeight) then
									ImGui.CloseCurrentPopup()
								end
								ImGui.SameLine()
								if ImGui.Button("No", style.halfButtonWidth - 192, style.buttonHeight) then
									ScanApp.userSettings.experimental = false
									ImGui.CloseCurrentPopup()
								end
								ImGui.EndPopup()
							end

							ImGui.Separator()
							ImGui.Spacing()
							if ScanApp.userSettings.experimental then
								if (ImGui.Button("Respawn All")) then
			 						ScanApp:RespawnAll()
			 					end

								ImGui.SameLine()
							end


							if (ImGui.Button("Force Despawn All")) then
		 						ScanApp:DespawnAll(true)
		 					end


		 					if (ImGui.Button("Clear All Saved Appearances")) then
		 						ScanApp:ClearAllSavedAppearances()
		 					end

		 					ImGui.Spacing()
							ImGui.Separator()

							ImGui.Text("Current Version: "..ScanApp.currentVersion)

		 					ImGui.EndTabItem()
		 				end

		 				-- DEBUG Tab --
						if ScanApp.Debug ~= '' then
							ScanApp.Debug.CreateTab(ScanApp, target)
		 				end
					end
				end
			end

	 	    ImGui.End()
	 	    ImGui.PopStyleColor(17)
				ImGui.PopStyleVar(1)
	 	end
	end)

   return ScanApp
end

function ScanApp:NewSpawn(name, id, parameters, companion, path)
	local obj = {}
	if type(id) == 'userdata' then id = tostring(id) end
	obj.handle = ''
	obj.uniqueName = name.."##"..id
	obj.name = name
	obj.id = id
	obj.parameters = parameters
	obj.canBeCompanion = companion
	obj.path = path
	obj.entityID = ''
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
	return obj
end

function ScanApp:CheckDB()

	-- Check if DB exists
	local check = db:execute("SELECT COUNT(1) FROM metadata")
	if check ~= 0 then
		local setupScript = require("Database/db_setup.lua")
		print("[AMM] First Time User: Creating DB...")
		db:execute(setupScript)

		ScanApp.DBHasChanges = true
	else
		local DBCurrentVersion = ''
		for r in db:urows("SELECT current_version FROM metadata") do
			DBCurrentVersion = r
		end

		if self.currentVersion ~= DBCurrentVersion then
			ScanApp.DBHasChanges = true
		end
	end
end

function ScanApp:UpdateDB()
	if ScanApp.DBHasChanges then
		local DBTables = {}
		local DBStrings = {'categories', 'entities', 'appearances'}
		for _, str in ipairs(DBStrings) do
			local file = io.open("Database/"..str..".json", "r")
			if file then DBTables[str] = json.decode(file:read("*a")) end
			file:close()
		end

		ScanApp.DBUpdateContent = DBTables
		ScanApp.DBHasChanges = false
		finishedUpdate = false
	elseif not(finishedUpdate) and next(ScanApp.DBUpdateContent) ~= nil then
		local tableName, obj = next(ScanApp.DBUpdateContent)
    if obj[1] ~= nil then
        local nextObj = obj[1]
        local fields = {}
        local values = {}
        for k, v in pairs(nextObj) do
            table.insert(fields, k)
            table.insert(values, "'"..v.."'")
        end
        db:execute(f("INSERT INTO %s (%s) VALUES (%s)", tableName, table.concat(fields, ", "), table.concat(values, ", ")))
        table.remove(obj, 1)
				ScanApp.DBUpdateCounter = ScanApp.DBUpdateCounter + 1
    else
        ScanApp.DBUpdateContent[tableName] = nil
    end
	elseif not(finishedUpdate) then
		finishedUpdate = true
		-- Set current version to DB
		db:execute(f("UPDATE metadata SET current_version = '%s'", self.currentVersion))
		ScanApp.categories = ScanApp:GetCategories()
		ScanApp:MigrateUserData()
	end
end

function ScanApp:MigrateUserData()
	if io.open("Database/user.lua", "r") then
		print("[AMM] Found User data. Migrating...")
		-- do migration
		local userPref = require("Database/user.lua")
		local settings = userPref['Settings']
		for k, v in pairs(settings) do
			db:execute(f("UPDATE settings SET setting_name = '%s', setting_value = %i WHERE setting_name = '%s'", k, boolToInt(v), k))
		end
		local favorites = userPref['Favorites']
		for k, v in pairs(favorites) do
			local tdbid = self:GetNPCTweakDBID(v[2])
			hash = tostring(tdbid):match("= (%g+),")
			length = tostring(tdbid):match("= (%g+) }")
			db:execute(f("INSERT INTO favorites (entity_id) VALUES ('%s')", hash..", "..length))
		end
		local savedApps = {}
		for k, v in pairs(userPref['NPC']) do savedApps[k] = v end
		for k, v in pairs(userPref['Vehicles']) do savedApps[k] = v end
		for k, v in pairs(savedApps) do
			for entityID in db:urows("SELECT entity_id FROM entities WHERE entity_id LIKE '%"..k.."%'") do
				db:execute(f("INSERT INTO saved_appearances (entity_id, app_name) VALUES ('%s', '%s')", entityID, v))
			end
		end

		print("[AMM] Finished migration. Delete user.lua from Appearance Menu Mod folder.")
	end
end

function ScanApp:GetCategories()
	local query = "SELECT * FROM categories WHERE cat_name != 'At Your Own Risk'"
	if ScanApp.userSettings.experimental then
		query = "SELECT * FROM categories"
	end

	local categories = {}
	for category in db:nrows(query) do
		categories[category.cat_id] = category.cat_name
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

		if spawn.canBeCompanion == false then
			self.IsJohnny = true
		end

		if spawn.parameters == "Vehicles" then
			distanceFromPlayer = -15
		elseif type(spawn.parameters) == 'table' then
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
		self.currentSpawn = spawn.uniqueName
		self.spawnsCounter = self.spawnsCounter + 1
		self.spawnedNPCs[spawn.uniqueName] = spawn
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
		self:ChangeScanAppearanceTo(t, savedApp)
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
	scanID = self:GetScanID(t)
	local options = {}

	if t:IsNPC() then
		if t:GetRecord():CrowdAppearanceNames()[1] ~= nil then
			for _, app in ipairs(t:GetRecord():CrowdAppearanceNames()) do
				table.insert(options, tostring(app):match("%[ (%g+) -"))
			end
			return options
		end
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

function ScanApp:ChangeScanAppearanceTo(t, newAppearance)
	if not(string.find(t.name, 'Mech')) then
		t.handle:PrefetchAppearanceChange(newAppearance)
		t.handle:ScheduleAppearanceChange(newAppearance)
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
		local command = f("INSERT INTO favorites (entity_id, parameters) VALUES ('%s', '%s')", entity.id, entity.parameters)
		command = command:gsub("'nil'", "NULL")
		db:execute(command)
	else
		local removedIndex = 0
		local query = f("SELECT position FROM favorites WHERE entity_id = '%s'", entity.id)
		for i in db:urows(query) do removedIndex = i end

		local command = f("DELETE FROM favorites WHERE entity_id = '%s' OR parameters = '%s'", entity.id, entity.parameters)
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

-- Helper methods
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
				query = f("SELECT COUNT(1) FROM favorites WHERE entity_ID = '%s'", pEntID)
				for found in db:urows(query) do
					count = found
				end

				if count == 0 then
					query = f("SELECT entity_id FROM entities WHERE entity_ID = '%s'", pEntID)
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
		for _, v in ipairs(self.allowedNPCs) do
			if npcID == v then
				-- NPC is unique
				return true
			end
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

function ScanApp:DrawFavoritesButton(buttonLabels, entity)
	if entity.parameters == nil then
		entity['parameters'] = entity.appearance
	end

	local isFavorite = 0
	for fav in db:urows(f("SELECT COUNT(1) FROM favorites WHERE entity_id = '%s'", entity.id)) do
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
		ScanApp:ToggleFavorite(isFavorite, entity)
	end
end

function ScanApp:DrawArrowButton(direction, id, index)
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

	if ImGui.ArrowButton(direction..id, dirEnum) then
		if not(tempPos < 1 or tempPos > favoritesLength) then
			local query = f("SELECT entity_id FROM favorites WHERE position = %i", tempPos)
			for favID in db:urows(query) do tempID = favID end

			db:execute(f("UPDATE favorites SET entity_id = '%s' WHERE position = %i", id, tempPos))
			db:execute(f("UPDATE favorites SET entity_id = '%s' WHERE position = %i", tempID, index))
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
		elseif action == "Spawn" then
			ScanApp:SpawnNPC(target)
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
		if categoryName == "Vehicles" then
			parameters = "Vehicles"
		else
			parameters = entity[4]
		end

		local newSpawn = ScanApp:NewSpawn(name, id, parameters, companion, path)
		local buttonLabel = newSpawn.uniqueName

		local favOffset = 0
		if categoryName == 'Favorites' then
			favOffset = 40

			ScanApp:DrawArrowButton("up", id, i)
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
			ScanApp:DrawButton(buttonLabel, style.buttonWidth - favOffset, style.buttonHeight, "Disabled", nil)
			ImGui.PopStyleColor(3)
		elseif ScanApp.spawnedNPCs[buttonLabel] == nil then
			ScanApp:DrawButton(buttonLabel, style.buttonWidth - favOffset, style.buttonHeight, "Spawn", newSpawn)
		end

		if categoryName == 'Favorites' then
			ImGui.SameLine()
			ScanApp:DrawArrowButton("down", id, i)
		end
	end
end

function ScanApp:ShouldDraw()
	if Game.GetPlayer() then
		newVelocity = Game.GetPlayer():GetVelocity().z
		if newVelocity == oldVelocity and newVelocity ~= 0 then -- pause menu
			oldVelocity = newVelocity
			return false
		elseif math.abs(newVelocity) < 0.00001 and newVelocity ~= 0 then -- main menu
			oldVelocity = newVelocity
			return false
		else
			oldVelocity = newVelocity
			return true
		end
	end
end

-- End of ScanApp Class

return ScanApp:new()
