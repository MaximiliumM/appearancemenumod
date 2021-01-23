-- Begin of ScanApp Class

ScanApp = {
	description = "",
	rootPath = "AppearanceMenuMod."
}

function ScanApp:new()

   setmetatable(ScanApp, self)
	 self.__index = self

	 -- Load Settings
	 ScanApp.Settings = require(ScanApp.rootPath.."Settings.settings")

	 -- Configs
	 ScanApp.currentDir = ScanApp:GetFolderPath()
	 ScanApp.settings = false
	 ScanApp.windowWidth = 320
	 ScanApp.roleComp = ''
	 ScanApp.spawnID = ''
	 ScanApp.maxSpawns = 6
	 ScanApp.spawnsCounter = 0

	 -- Debug Menu --
	 ScanApp.debugMenu = false
	 ScanApp.debugIDs = {}
	 ScanApp.sortedDebugIDs = {}

	 -- Main Properties --
   ScanApp.npcs, ScanApp.vehicles = ScanApp:GetDB()
   ScanApp.savedApps = ScanApp:GetSavedAppearances()
	 ScanApp.currentTarget = ''
	 ScanApp.spawnedNPCs = {}
	 ScanApp.spawnIDs = {
		 'Judy', 'Panam', 'Rogue', 'Alt', 'Claire', 'Evelyn',
		 'Jackie', 'Nancy', 'Denny', 'Henry', 'Kerry', 'Tbug',
		 'Saul', 'Misty', 'Nix', 'Mitch', 'Carol', 'Cassidy',
		 'Ozob'}
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

	 registerForEvent("onUpdate", function(deltaTime)

		 		-- Load Saved Appearance --
		 		if not drawWindow then
		 			target = ScanApp:GetTarget()
		 			ScanApp:CheckSavedAppearance(target)
		 		end

				if drawWindow then
					if ScanApp:ShouldDraw() and ScanApp.roleComp == '' then
						ScanApp:GetFollowerRole()
					end
				end

				if buttonPressed then
					spamTimer = spamTimer + deltaTime

					if spamTimer > 0.5 then
						buttonPressed = false
						spamTimer = 0.0
					end
				end

				if ScanApp.spawnID ~= '' then
					waitTimer = waitTimer + deltaTime
					-- print('trying to set companion')
					if waitTimer > 0.2 then
						local npcHandle = Game.FindEntityByID(ScanApp.spawnID)
						if npcHandle then
							ScanApp:SetNPCAsCompanion(npcHandle)
						end
					end
				end
	 end)

	 registerForEvent("onOverlayOpen", function()
	     drawWindow = true
	 end)

	 registerForEvent("onOverlayClose", function()
	     drawWindow = false
	 end)

	 registerForEvent("onDraw", function()

	 	ImGui.SetNextWindowPos(500, 500, ImGuiCond.FirstUseEver)

	 	if ScanApp.debugMenu == true then
	 		ImGui.SetNextWindowSize(800, 400)
	 	elseif (target ~= nil) and (target.options ~= nil) or (ScanApp.settings == true) then
	 		ImGui.SetNextWindowSize(ScanApp.windowWidth, 400)
	 	else
	 		ImGui.SetNextWindowSize(ScanApp.windowWidth, 160)
	 	end

	 	if(drawWindow) then

	 			-- Target Setup --
	 			target = ScanApp:GetTarget()
	 			ScanApp:SetCurrentTarget(target)

	 			ImGui.PushStyleColor(ImGuiCol.Border, 0.56, 0.06, 0.03, 1)
	 			ImGui.PushStyleColor(ImGuiCol.Tab, 1, 0.2, 0.2, 0.5)
	 	    ImGui.PushStyleColor(ImGuiCol.TabHovered, 1, 0.2, 0.2, 0.85)
	 	    ImGui.PushStyleColor(ImGuiCol.TabActive, 1, 0.2, 0.2, 1)
	 	    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0.56, 0.06, 0.03, 0.5)
	 	    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0.56, 0.06, 0.03, 1)
	 	    ImGui.PushStyleColor(ImGuiCol.TitleBgCollapsed, 0.56, 0.06, 0.03, 0.25)
	 	    ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.06, 0.03, 0.6)
	 	    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.56, 0.06, 0.03, 0.75)
	 	    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.06, 0.03, 1)
	 	    ImGui.PushStyleColor(ImGuiCol.ResizeGrip, 0.56, 0.06, 0.03, 0.6)
	 	    ImGui.PushStyleColor(ImGuiCol.ResizeGripHovered, 0.56, 0.06, 0.03, 0.75)
	 	    ImGui.PushStyleColor(ImGuiCol.ResizeGripActive, 0.56, 0.06, 0.03, 1)

	 	    if (ImGui.Begin("Appearance Menu Mod")) then

	 	    	ImGui.SetWindowFontScale(1.2)

	 	    	if (ImGui.BeginTabBar("TABS")) then

	 					local style = {
	 									buttonWidth = -1,
	 									buttonHeight = 20,
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
	 					    		ImGui.TextColored(1, 0, 0, 1,tabs[tab].currentTitle)
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

	 									local savedApp = ScanApp.savedApps[target.type][target.id]
	 									if savedApp ~= nil then
	 										ImGui.TextColored(1, 0, 0, 1, "Saved Appearance:")
	 						    		ImGui.Text(savedApp)
	 										ScanApp:DrawButton("Clear Saved Appearance", style.buttonWidth, style.buttonHeight, "Clear", target)
	 									end

	 						    	ImGui.NewLine()
	 									ImGui.Separator()

	 						    	if target.options ~= nil then
	 						    		ImGui.TextColored(1, 0, 0, 1, target.name)
	 							    	if (ImGui.BeginChild("Scrolling")) then
	 								    	for i, appearance in ipairs(target.options) do
	 								    		x, y = ImGui.CalcTextSize(appearance)
	 								    		if (x > self.windowWidth) then self.windowWidth = x + 40 end
	 								    		if (ImGui.Button(appearance)) then
	 								    			ScanApp:ChangeScanAppearanceTo(target.handle, appearance)
	 								    		end
	 								    	end

	 								    end

	 								    ImGui.EndChild()
	 								end
	 							else
	 				    		ImGui.PushTextWrapPos()
	 				    		ImGui.TextColored(1, 0, 0, 1, tabs[tab].errorMessage)
	 				    		ImGui.PopTextWrapPos()
	 				    	end
	 					ImGui.EndTabItem()
	 					end
	 				end
	 				-- End of Tab Constructor --


					if (ImGui.BeginTabItem("Spawn NPC")) then
						ScanApp.settings = true
						ImGui.TextColored(1, 0, 0, 1, "Select NPC to spawn:")

						for _, char in ipairs(ScanApp.spawnIDs) do
							if ScanApp.spawnedNPCs[char] == nil then
								ScanApp:DrawButton(char, style.buttonWidth, style.buttonHeight, "Spawn", char)
							end
						end

						if next(ScanApp.spawnedNPCs) ~= nil then
							ImGui.TextColored(1, 0, 0, 1, "Select NPC to despawn:")
							for npcName, npcID in pairs(ScanApp.spawnedNPCs) do
								ScanApp:DrawButton(npcName, style.buttonWidth, style.buttonHeight, "Despawn", npcID)
							end
						end

						ImGui.EndTabItem()
					end

	 				if (ImGui.BeginTabItem("Settings")) then
	 					ScanApp.settings = true

	 					ImGui.Spacing()

	 					if (ImGui.Button("Clear All Saved Appearances")) then
	 						ScanApp:ClearAllSavedAppearances()
	 					end

	 					ImGui.Spacing()

	 					ImGui.EndTabItem()
	 				end

	 				-- DEBUG Tab --
	 				if ScanApp.debugMenu then
	 					if (ImGui.BeginTabItem("Debug")) then
	 					ScanApp.settings = false

	 						if (ImGui.Button("Cycle")) then
	 							scanID = target.id
	 				    	ScanApp:ChangeScanAppearanceTo(target.handle, 'Cycle')
	 				    	app = ScanApp:GetScanAppearance(target.handle)
	 							ScanApp.debugIDs[app] = scanID
	 							-- Add new ID
	 							output = {}
	 							for i,v in pairs(ScanApp.debugIDs) do
	 		   						if output[v] == nil then
	 		        					output[v] = {}
	 		    					end

	 		    					table.insert(output[v], i)
	 							end

	 							ScanApp.sortedDebugIDs = output
	 				    end

	 				    ImGui.Spacing()

	 				    ImGui.InputText("ID", scanID, 100, ImGuiInputTextFlags.ReadOnly)
	 				    ImGui.InputText("AppString", app, 100, ImGuiInputTextFlags.ReadOnly)

	 				    ImGui.Spacing()

	 						if (ImGui.Button('Save IDs to file')) then
	 							print("Scan ID: "..scanID.." -- Added to clipboard")
	 							ImGui.SetClipboardText(scanID)
	 							ScanApp.Settings.LogToFile(ScanApp.sortedDebugIDs)
	 						end

	 						ImGui.Spacing()

	 						if (ImGui.BeginChild("Scrolling")) then
	 							for id, appArray in pairs(ScanApp.sortedDebugIDs) do
	 					    		if(ImGui.CollapsingHeader(id)) then
	 					    			for _, app in pairs(appArray) do
	 					    				if (ImGui.Button(app)) then
	 					    					print("AppString: "..app.." -- Added to clipboard")
	 					    					ImGui.SetClipboardText(app)
	 					    				end
	 					    			end
	 					    		end
	 					    	end
	 						end

	 						ImGui.EndChild()
	 						ImGui.EndTabItem()
	 					end
	 				end
	 		   end
	 		end

	 	    ImGui.End()
	 	    ImGui.PopStyleColor(13)
	 	end
	 end)

   return ScanApp
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
	return db[1], db[2]
end

function ScanApp:GetNPCTweakDBID(npc)
	return TweakDBID.new('Character.'..npc)
end

function ScanApp:SpawnNPC(npcName)
	if self.spawnsCounter ~= self.maxSpawns and not buttonPressed then
		local player = Game.GetPlayer()
		local heading = player:GetWorldForward()
		local offsetDir = Vector3.new(heading.x, heading.y, heading.z)
		local spawnTransform = player:GetWorldTransform()
		local spawnPosition = spawnTransform.Position:ToVector4(spawnTransform.Position)
		spawnTransform:SetPosition(spawnTransform, Vector4.new(spawnPosition.x - offsetDir.x, spawnPosition.y - offsetDir.y, spawnPosition.z, spawnPosition.w))
		self.spawnID = Game.GetPreventionSpawnSystem():RequestSpawn(self:GetNPCTweakDBID(npcName), 1, spawnTransform)
		self.spawnedNPCs[npcName] = self.spawnID
		self.spawnsCounter = self.spawnsCounter + 1
	else
		Game.GetPlayer():SetWarningMessage("Spawn limit reached!")
	end
end

function ScanApp:DespawnNPC(npcName, spawnID)
	Game.GetPlayer():SetWarningMessage(npcName.." will despawn once you look away")
	self.spawnedNPCs[npcName] = nil
	self.spawnsCounter = self.spawnsCounter - 1
	Game.GetPreventionSpawnSystem():RequestDespawn(spawnID)
end

function ScanApp:GetSavedAppearances()
		return require("AppearanceMenuMod.Database.user")
end

function ScanApp:CheckSavedAppearance(t)
	if next(self.savedApps) ~= nil then
		local handle, currentApp, savedApp
		if t ~= nil then
			handle = t.handle
			currentApp = t.appearance
			savedApp = self.savedApps[t.type][t.id]
		else
			local qm = Game.GetPlayer():GetQuickSlotsManager()
			handle = qm:GetVehicleObject()
			if handle ~= nil then
				local vehicleID = tostring(handle:GetRecordID()):match("= (%g+),")
				currentApp = self:GetScanAppearance(handle)
				savedApp = self.savedApps['Vehicles'][vehicleID]
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

	self.savedApps[t.type][t.id] = nil
	self:SaveToFile()

end

function ScanApp:ClearAllSavedAppearances()
	self.savedApps = {NPC = {}, Vehicles = {}}
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
	print('[AMM] Saving...')
	self.savedApps[t.type][t.id] = t.appearance
	self:SaveToFile()
end


function ScanApp:SaveToFile()
	data = 'return {\n'

	for i, j in pairs(self.savedApps) do
		data = data..i.." = {"
		for k,v in pairs(j) do
			data = data.."['"..k.."']".." = '"..v.."',"
		end
		data = data.."},\n"
	end

	data = data.."}"

	if self.debugMenu == true then
		print(data)
	end

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
		if self.npcs[scanID] ~= nil then
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
	t:PrefetchAppearanceChange(newAppearance)
	t:ScheduleAppearanceChange(newAppearance)
end

function ScanApp:GetTarget()
	if Game.GetPlayer() then
		target = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(),false,false)
		if target ~= nil then
			if target:IsNPC() then
				return ScanApp:NewTarget(target, "NPC", ScanApp:GetScanID(target), ScanApp:GetNPCName(target),ScanApp:GetScanAppearance(target), ScanApp:GetAppearanceOptions(target))
			elseif target:IsVehicle() then
				return ScanApp:NewTarget(target, "Vehicles", ScanApp:GetScanID(target), ScanApp:GetVehicleName(target),ScanApp:GetScanAppearance(target), ScanApp:GetAppearanceOptions(target))
			end
		end
	end

	return nil
end

-- Companion methods -- original code by Catmino
function ScanApp:GetFollowerRole()
	-- print('getting follower role')
	local ssc = Game.GetScriptableSystemsContainer()
	local scs = ssc:Get(CName.new('SubCharacterSystem'))
	local gcs = Game.GetCompanionSystem()
	scs:AddFlathead()
	Game.SpawnFlathead()
	local flathead = scs:GetFlathead()
	local flatheadAIC = flathead:GetAIControllerComponent()
	local flatheadAIR = flatheadAIC:GetCurrentRole()
	self.roleComp = flatheadAIR
	Game.DespawnFlathead()
	-- print('get follower role succeded')
end

function ScanApp:SetNPCAsCompanion(npcHandle)
	if self.roleComp == '' then
		self:GetFollowerRole()
	end

	waitTimer = 0.0
	self.spawnID = ''

	local targCompanion = npcHandle
	local AIC = targCompanion:GetAIControllerComponent()
	local targetAttAgent = targCompanion:GetAttitudeAgent()
	local currTime = targCompanion.isPlayerCompanionCachedTimeStamp + 11

	if targCompanion.isPlayerCompanionCached == false then
		self.roleComp:SetFollowTarget(Game:GetPlayerSystem():GetLocalPlayerControlledGameObject())
		self.roleComp:OnRoleSet(targCompanion)
		self.roleComp.followerRef = Game.CreateEntityReference("#player", {})
		--Game['AIHumanComponent::SetCurrentRole;GameObjectAIRole'](targCompanion, self.roleComp)
		targetAttAgent:SetAttitudeGroup(CName.new("player"))
		self.roleComp.attitudeGroupName = CName.new("player")
		Game['senseComponent::RequestMainPresetChange;GameObjectString'](targCompanion, "Follower")
		Game['senseComponent::ShouldIgnoreIfPlayerCompanion;EntityEntity'](targCompanion, Game:GetPlayer())
		Game['NPCPuppet::ChangeStanceState;GameObjectgamedataNPCStanceState'](targCompanion, "Relaxed")
		targCompanion.isPlayerCompanionCached = true
		targCompanion.isPlayerCompanionCachedTimeStamp = currTime

		AIC:SetAIRole(self.roleComp)
	end
end

-- Helper methods
function ScanApp:DrawButton(title, width, height, action, target)
	if (ImGui.Button(title, width, height)) then
		if action == "Cycle" then
			ScanApp:ChangeScanAppearanceTo(target.handle, 'Cycle')
		elseif action == "Save" then
			ScanApp:SaveAppearance(target)
		elseif action == "Clear" then
			ScanApp:ClearSavedAppearance(target)
		elseif action == "Spawn" then
			ScanApp:SpawnNPC(target)
			buttonPressed = true
		elseif action == "Despawn" then
			ScanApp:DespawnNPC(title, target)
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
