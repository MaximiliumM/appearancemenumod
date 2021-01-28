-- Begin of ScanApp Class

ScanApp = {
	description = "",
	rootPath = "AppearanceMenuMod."
}

-- Hack: Forces required lua files to reload when using hot reload
-- Thanks, Architect!
for k, _ in pairs(package.loaded) do
    if string.match(k, ScanApp.rootPath .. ".*") then
        package.loaded[k] = nil
    end
end

function loadrequire(module)
    success, result = pcall(require, module)
    if success then
			return result
    else
			return ''
		end
end

function ScanApp:new()

   setmetatable(ScanApp, self)
	 self.__index = self

	 -- Load Settings --
	 ScanApp.Debug = loadrequire(ScanApp.rootPath.."debug")

	 -- User Settings --
	 ScanApp.openWithOverlay = true
	 ScanApp.autoResizing = true

	 -- Configs --
	 ScanApp.currentDir = ScanApp:GetFolderPath()
	 ScanApp.settings = false
	 ScanApp.windowWidth = 500
	 ScanApp.roleComp = ''
	 ScanApp.spawnID = ''
	 ScanApp.maxSpawns = 6
	 ScanApp.spawnsCounter = 0
	 ScanApp.spawnAsCompanion = true
	 ScanApp.IsJohnny = false
	 ScanApp.shouldCheckSavedAppearance = true

	 -- Main Properties --
   ScanApp.npcs, ScanApp.vehicles, ScanApp.spawnIDs = ScanApp:GetDB()
   ScanApp.userData = ScanApp:GetUserData()
	 ScanApp.currentTarget = ''
	 ScanApp.spawnedNPCs = {}
	 ScanApp.allowedNPCs = {
		 '0xB1B50FFA', '0xC67F0E01', '0x73C44EBA', '0xAD1FC6DE', '0x7F65F7F7',
		 '0x7B2CB67C', '0x3024F03E', '0x3B6EF8F9', '0x413F60A6', '0x62B8D0FA',
		 '0x3143911D', '0xA1C78C30', '0x0044E64C', '0xF43B2B48', '0xC111FBAC',
		 '0x8DD8F2E0', '0x4106744C', '0xB98FDBB8'
	 }

	 registerForEvent("onInit", function()
		 waitTimer = 0.0
		 spamTimer = 0.0
		 buttonPressed = false
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
			if ScanApp:ShouldDrawSaveButton(target.handle) then
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

	 registerForEvent("onUpdate", function(deltaTime)

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

				if ScanApp.spawnID ~= '' and not(ScanApp.IsJohnny) then
					waitTimer = waitTimer + deltaTime
					-- print('trying to set companion')
					if waitTimer > 0.2 then
						local handle = Game.FindEntityByID(ScanApp.spawnID)
						if handle then
							if handle:IsNPC() and ScanApp.spawnAsCompanion then
								ScanApp:SetNPCAsCompanion(handle)
							else
								handle:GetVehiclePS():UnlockAllVehDoors()
							end
						end
					end
				else
					ScanApp.IsJohnny = false
					ScanApp.spawnID = ''
				end
	 end)

	 registerForEvent("onOverlayOpen", function()
		 if ScanApp.openWithOverlay then drawWindow = true end
	 end)

	 registerForEvent("onOverlayClose", function()
		 drawWindow = false
	 end)

	 registerForEvent("onDraw", function()

	 	ImGui.SetNextWindowPos(500, 500, ImGuiCond.FirstUseEver)

		local shouldResize = ImGuiCond.None
		if not(ScanApp.autoResizing) then
			shouldResize = ImGuiCond.Appearing
		end

	 	if ScanApp.Debug ~= '' then
	 		ImGui.SetNextWindowSize(800, 400)
	 	elseif (target ~= nil) and (target.options ~= nil) or (ScanApp.settings == true) then
	 		ImGui.SetNextWindowSize(ScanApp.windowWidth, 400, shouldResize)
	 	else
	 		ImGui.SetNextWindowSize(ScanApp.windowWidth, 160, shouldResize)
	 	end

	 	if(drawWindow) then

	 			-- Target Setup --
	 			target = ScanApp:GetTarget()

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
	 									local drawSaveButton = ScanApp:ShouldDrawSaveButton(target.handle)

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

	 									local savedApp = ScanApp.userData[target.type][target.id]
	 									if savedApp ~= nil then
	 										ImGui.TextColored(0.3, 0.5, 0.7, 1, "Saved Appearance:")
	 						    		ImGui.Text(savedApp)
	 										ScanApp:DrawButton("Clear Saved Appearance", style.buttonWidth, style.buttonHeight, "Clear", target)
	 									end

	 						    	ImGui.NewLine()
	 									ImGui.Separator()

	 						    	if target.options ~= nil then
	 						    		ImGui.TextColored(0.3, 0.5, 0.7, 1, target.name)
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

						if next(ScanApp.spawnedNPCs) ~= nil then
							ImGui.TextColored(0.3, 0.5, 0.7, 1, "Active Spawns")

							for _, spawn in pairs(ScanApp.spawnedNPCs) do
								ImGui.Text(spawn.name)
								ImGui.SameLine()

								local favoriteButtonLabel = "Favorite"
								if ScanApp.userData['Favorites'] ~= nil and ScanApp.userData['Favorites'][spawn.name] then
									favoriteButtonLabel = "Unfavorite"
								end

								if ImGui.SmallButton(favoriteButtonLabel) then
									ScanApp:ToggleFavorite(favoriteButtonLabel, spawn.name, spawn.id, spawn.companion)
								end

								ImGui.SameLine()

								if ImGui.SmallButton("Despawn") then
									ScanApp:DespawnNPC(spawn.uniqueName, spawn.entityID)
								end
							end

						end

						ImGui.TextColored(0.3, 0.5, 0.7, 1, "Select To Spawn:")

						categoryOrder = ScanApp.spawnIDs['Category Order']

						for _, category in ipairs(categoryOrder) do

							if(ImGui.CollapsingHeader(category)) then
								local categoryIDs = {}
								if self.userData['Favorites'] and next(self.userData['Favorites']) and category == 'Favorites' then
									for _, fav in pairs(ScanApp.userData['Favorites']) do
										table.insert(categoryIDs, fav)
									end
								else
									categoryIDs = ScanApp.spawnIDs[category]
								end

								if categoryIDs then
									for _, spawnArray in ipairs(categoryIDs) do
										if type(spawnArray) == 'table' then
											name = spawnArray[1]
											id = spawnArray[2]
											companion = spawnArray[3] or false
											if category == 'Vehicles' then
												companion = 'Vehicle'
											end
										end

										local newSpawn = ScanApp:NewSpawn(name, id, companion)
										local buttonLabel = newSpawn.uniqueName

										if category == 'Favorites' and ScanApp.spawnedNPCs[buttonLabel] and ScanApp.userData['Favorites'][name] then
											ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.25)
											ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.25)
											ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 0.25)
											ScanApp:DrawButton(buttonLabel, style.buttonWidth, style.buttonHeight, "Disabled", nil)
											ImGui.PopStyleColor(3)
										elseif ScanApp.spawnedNPCs[buttonLabel] == nil then
											ScanApp:DrawButton(buttonLabel, style.buttonWidth, style.buttonHeight, "Spawn", newSpawn)
										end
									end
								else
										ImGui.Text("It's empty :(")
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
						ScanApp.openWithOverlay = ImGui.Checkbox("Open With CET Overlay", ScanApp.openWithOverlay)
						ScanApp.autoResizing = ImGui.Checkbox("Auto-Resizing Window", ScanApp.autoResizing)

						ImGui.Spacing()
						ImGui.Separator()

						if (ImGui.Button("Force Despawn All")) then
	 						ScanApp:DespawnAll()
	 					end


	 					if (ImGui.Button("Clear All Saved Appearances")) then
	 						ScanApp:ClearAllSavedAppearances()
	 					end

	 					ImGui.Spacing()

	 					ImGui.EndTabItem()
	 				end

	 				-- DEBUG Tab --
	 				if ScanApp.Debug ~= '' then
						ScanApp.Debug.CreateTab(ScanApp, target)
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

function ScanApp:NewSpawn(name, id, companion)
	local obj = {}
	obj.uniqueName = name.."##"..id
	obj.name = name
	obj.id = id
	obj.companion = companion
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

function ScanApp:GetFolderPath()
	local path = io.popen"cd":read'*l'
	if not string.find(path, "plugins") then
		return path.."\\plugins\\cyber_engine_tweaks\\mods"
	else
		return path
	end
end

function ScanApp:GetDB()
	local db = require("AppearanceMenuMod.Database.database")
	return db[1], db[2], db[3]
end

function ScanApp:GetNPCTweakDBID(npc)
	if type(npc) == 'userdata' then return TweakDBID.new(npc) end
	return TweakDBID.new(npc)
end

function ScanApp:SpawnNPC(spawn)
	if self.spawnsCounter ~= self.maxSpawns and not buttonPressed then
		local distanceFromPlayer = 1

		if spawn.companion == 'Vehicle' then
			distanceFromPlayer = -15
		elseif spawn.companion then
			self.IsJohnny = true
		end

		local player = Game.GetPlayer()
		local heading = player:GetWorldForward()
		local offsetDir = Vector3.new(heading.x * distanceFromPlayer, heading.y * distanceFromPlayer, heading.z)
		local spawnTransform = player:GetWorldTransform()
		local spawnPosition = spawnTransform.Position:ToVector4(spawnTransform.Position)
		spawnTransform:SetPosition(spawnTransform, Vector4.new(spawnPosition.x - offsetDir.x, spawnPosition.y - offsetDir.y, spawnPosition.z, spawnPosition.w))
		self.spawnID = Game.GetPreventionSpawnSystem():RequestSpawn(self:GetNPCTweakDBID(spawn.id), -1, spawnTransform)
		self.spawnsCounter = self.spawnsCounter + 1
		spawn.entityID = self.spawnID
		self.spawnedNPCs[spawn.uniqueName] = spawn
		table.insert(self.spawnedHistory, self.spawnID)
	else
		Game.GetPlayer():SetWarningMessage("Spawn limit reached!")
	end
end

function ScanApp:DespawnNPC(npcName, spawnID)
	Game.GetPlayer():SetWarningMessage(npcName:match("(.+)##(.+)").." will despawn once you look away")
	self.spawnedNPCs[npcName] = nil
	self.spawnsCounter = self.spawnsCounter - 1
	Game.GetPreventionSpawnSystem():RequestDespawn(spawnID)
end

function ScanApp:DespawnAll()
	Game.GetPlayer():SetWarningMessage("All NPCs will despawn once you look away")
	Game.GetPreventionSpawnSystem():RequestDespawnPreventionLevel(-1)
	self.spawnsCounter = 0
	self.spawnedNPCs = {}
end

function ScanApp:GetUserData()
		local userPref = loadrequire("AppearanceMenuMod.Database.user")
		if userPref ~= '' then return userPref end
		return {NPC = {}, Vehicles = {}, Favorites = {}}
end

function ScanApp:CheckSavedAppearance(t)
	if next(self.userData) ~= nil then
		local handle, currentApp, savedApp
		if t ~= nil then
			handle = t.handle
			currentApp = t.appearance
			savedApp = self.userData[t.type][t.id]
		else
			local qm = Game.GetPlayer():GetQuickSlotsManager()
			handle = qm:GetVehicleObject()
			if handle ~= nil then
				local vehicleID = tostring(handle:GetRecordID()):match("= (%g+),")
				currentApp = self:GetScanAppearance(handle)
				savedApp = self.userData['Vehicles'][vehicleID]
			end
		end

		if savedApp ~= nil and savedApp ~= currentApp then
			handle:ScheduleAppearanceChange(savedApp)
		end
	end
end

function ScanApp:ClearSavedAppearance(t)
	if self.currentTarget ~= '' then
		if t.appearance ~= self.currentTarget.appearance then
			t.handle:ScheduleAppearanceChange(self.currentTarget.appearance)
		end
	end

	self.userData[t.type][t.id] = nil
	self:SaveToFile()

end

function ScanApp:ClearAllSavedAppearances()
	self.userData = {NPC = {}, Vehicles = {}, Favorites = {}}
	self:SaveToFile()
end

function ScanApp:ShouldDrawSaveButton(t)
	if t:IsNPC() then
		local npcID = self:GetScanID(t)
		for i, v in ipairs(self.allowedNPCs) do
			if npcID == v then
				-- NPC is unique
				return true
			end
		end
		-- NPC isn't unique
		return false

	elseif t:IsVehicle() and t:IsPlayerVehicle() then
		return true
	end

	return false
end

function ScanApp:SaveAppearance(t)
	self.userData[t.type][t.id] = t.appearance
	self:SaveToFile()
end


function ScanApp:SaveToFile()
	print('[AMM] Saving...')
	data = 'return {\n'

	for i, j in pairs(self.userData) do
		data = data..i.." = {"
		for k,v in pairs(j) do
			if type(v) == 'table' then
				data = data.."['"..k.."']".." = {"
				for _, l in ipairs(v) do
					if type(l) == 'string' then data = data.."'"..l.."'"..","
					else data = data..tostring(l).."," end
				end
				data = data.."},"
			else
				data = data.."['"..k.."']".." = '"..v.."',"
			end
		end
		data = data.."},\n"
	end

	data = data.."}"

	print(data)
	local output = io.open(self.currentDir.."\\AppearanceMenuMod\\Database\\user.lua", "w")

	output:write(data)
	output:close()
end

function ScanApp:GetNPCName(t)
	n = t:GetTweakDBDisplayName(true)
	return n
end

function ScanApp:GetVehicleName(t)
	return tostring(t:GetDisplayName())
end

function ScanApp:GetScanID(t)
	return tostring(t:GetRecordID()):match("= (%g+),")
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

	if t:IsNPC() then
		if t:GetRecord():CrowdAppearanceNames()[1] ~= nil then
			local options = {}
			for _, app in ipairs(t:GetRecord():CrowdAppearanceNames()) do
				table.insert(options, tostring(app):match("%[ (%g+) -"))
			end
			return options
		elseif self.npcs[scanID] ~= nil then
			return self.npcs[scanID] -- array of appearances names
		end
	elseif t:IsVehicle() then
		if self.vehicles[scanID] ~= nil then
			return self.vehicles[scanID]
		end
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

function ScanApp:ToggleFavorite(sender, name, id, companion)
	if sender == 'Favorite' then
		if self.userData['Favorites'] == nil then self.userData['Favorites'] = {} end
		self.userData['Favorites'][name] = {name, id, companion}
	else
		self.userData['Favorites'][name] = nil
	end

	self:SaveToFile()
end

-- Companion methods -- original code by Catmino
function ScanApp:SetNPCAsCompanion(npcHandle)

	waitTimer = 0.0
	self.spawnID = ''

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
