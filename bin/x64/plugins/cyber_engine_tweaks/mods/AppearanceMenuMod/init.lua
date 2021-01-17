-- Load Settings
Settings = require("AppearanceMenuMod.Settings.settings")
Settings.Log("Current Keybind: "..Settings.GetCurrentKeybind()[1])

-- Debug Menu --
debugMenu = false
debugIDs = {}
sortedDebugIDs = {}

-- Begin of Target Class
Target = {}
Target.__index = Target

function Target:new(handle, targetType, id, name, app, options)
	local obj = {}
	setmetatable(obj, Target)
	obj.handle = handle
	obj.id = id
	obj.name = name
	obj.appearance = app
	obj.type = targetType
	obj.options = options or nil
	return obj
end
-- End of Target Class

-- Begin of ScanAppMod Class

ScanAppMod = {}
ScanAppMod.__index = ScanAppMod

function ScanAppMod:new()
   local obj = {}
   setmetatable(obj, self)
   obj.npcs, obj.vehicles = obj:GetDB()
   obj.savedApps = obj:GetSavedAppearances()
   return obj
end

function ScanAppMod:GetDB()
	local db = require("AppearanceMenuMod.Database.database")
	return db[1], db[2]
end

function ScanAppMod:GetSavedAppearances()
	local db = require("AppearanceMenuMod.Database.user")
	return db
end

function ScanAppMod:CheckSavedAppearance()
	local player = Game.GetPlayer()
	if player ~= nil and next(self.savedApps) ~= nil then
		local qm = player:GetQuickSlotsManager()
		local entityID = qm.PlayerVehicleID
		if entityID ~= nil then
			local vehicleHandle = Game.FindEntityByID(entityID)
			local vehicleID = tostring(vehicleHandle:GetRecordID()):match("= (%g+),")
			local vehicleApp = self:GetScanAppearance(vehicleHandle)
			local savedApp = self.savedApps[vehicleID]
			if savedApp ~= nil and savedApp ~= vehicleApp then
				vehicleHandle:ScheduleAppearanceChange(savedApp)
			end
		end
	end
end

function ScanAppMod:ClearAllSavedAppearances()
	self.savedApps = {}
	data = 'return {}'
	self:SaveToFile(data)
end

function ScanAppMod:SaveAppearance(t)
	print('[AMM] Saving...')
	local targetID = self:GetScanID(t)
	local currentApp = self:GetScanAppearance(t)

	self.savedApps[targetID] = currentApp

	data = 'return {\n'

	for k,v in pairs(self.savedApps) do
		data = data.."['"..k.."']".." = '"..v.."',\n"
	end

	data = data.."}"

	self:SaveToFile(data)
end

function ScanAppMod:SaveToFile(data)
	local output = io.open("AppearanceMenuMod/Database/user.lua", "w")

	output:write(data)
	output:close()
end

function ScanAppMod:GetNPCName(t)
	n = t:GetTweakDBDisplayName(true)
	return n
end

function ScanAppMod:GetVehicleName(t)
	return tostring(t:GetDisplayName())
end

function ScanAppMod:GetScanID(t)
	return tostring(t:GetRecordID()):match("= (%g+),")
end

function ScanAppMod:GetAppearanceOptions(t)
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

function ScanAppMod:GetScanAppearance(t)
	return tostring(t:GetCurrentAppearanceName()):match("%[ (%g+) -")
end

function ScanAppMod:ChangeScanAppearanceTo(t, newAppearance)
	t:PrefetchAppearanceChange(newAppearance)
	t:ScheduleAppearanceChange(newAppearance)
end

-- End of ScanAppMod Class

ScanApp = ScanAppMod:new()
drawWindow = false
settings = false
windowWidth = 265
currentItem = Settings.GetCurrentKeybind()[1]

function NewTarget()
	if Game.GetPlayer() ~= nil then
		target = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(),false,false)
		if target ~= nil then
			if target:IsNPC() then
				return Target:new(target, "NPC", ScanApp:GetScanID(target), ScanApp:GetNPCName(target),ScanApp:GetScanAppearance(target), ScanApp:GetAppearanceOptions(target))
			elseif target:IsVehicle() then
				return Target:new(target, "Vehicles", ScanApp:GetScanID(target), ScanApp:GetVehicleName(target),ScanApp:GetScanAppearance(target), ScanApp:GetAppearanceOptions(target))
			end
		end
	end

	return nil
end

registerForEvent("onUpdate", function(deltaTime)
    if (ImGui.IsKeyPressed(Settings.GetCurrentKeybind()[2], false)) then
      drawWindow = not drawWindow
    end

		-- Load Saved Appearance --
		if not drawWindow then
			ScanApp:CheckSavedAppearance()
		end
end)

registerForEvent("onConsoleOpen", function()
    drawWindow = true
end)

registerForEvent("onConsoleClose", function()
    drawWindow = false
end)

registerForEvent("onDraw", function()

	ImGui.SetNextWindowPos(500, 500, ImGuiCond.FirstUseEver)

	if debugMenu == true then
		ImGui.SetNextWindowSize(800, 400)
	elseif (target ~= nil) and (target.options ~= nil) or (settings == true) then
		ImGui.SetNextWindowSize(windowWidth, 400)
	else
		ImGui.SetNextWindowSize(windowWidth, 160)
	end

	if(drawWindow) then

			-- Target Setup --
			target = NewTarget()

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
									width = style.buttonWidth,
									action = "Cycle"
								}
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
		    			settings = false

							if target ~= nil and target.type == tab then
					    		ImGui.TextColored(1, 0, 0, 1,tabs[tab].currentTitle)
					    		ImGui.Text(target.appearance)
					    		x, y = ImGui.CalcTextSize(target.appearance)
					    		windowWidth = x + 40

									ImGui.Spacing()

									for _, button in ipairs(tabs[tab].buttons) do
										ImGui.SameLine()
						    		if (ImGui.Button(button.title, button.width, style.buttonHeight)) then
						    			if button.action == "Cycle" then
												ScanApp:ChangeScanAppearanceTo(target.handle, 'Cycle')
											elseif button.action == "Save" then
												ScanApp:SaveAppearance(target.handle)
											end
						    		end
									end

						    	ImGui.NewLine()
									ImGui.Separator()

						    	if target.options ~= nil then
						    		ImGui.TextColored(1, 0, 0, 1, target.name)
							    	if (ImGui.BeginChild("Scrolling")) then
								    	for i, appearance in ipairs(target.options) do
								    		x, y = ImGui.CalcTextSize(appearance)
								    		if (x > windowWidth) then windowWidth = x + 40 end
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

				if (ImGui.BeginTabItem("Settings")) then
					settings = true

					allItems = Settings.GetAllKeybinds()
					if(ImGui.ListBoxHeader("Keybind", Settings.GetNumberOfKeys())) then
						for key, code in pairs(allItems) do
							if (currentItem == key) then selected = true else selected = false end
							if(ImGui.Selectable(key, selected)) then
								currentItem = key
								Settings.Save(key, code)
							end
						end
					end

					ImGui.ListBoxFooter()

					ImGui.Separator()
					ImGui.Spacing()

					if (ImGui.Button("Clear All Saved Appearances")) then
						ScanApp:ClearAllSavedAppearances()
					end

					ImGui.Spacing()

					ImGui.EndTabItem()
				end

				-- DEBUG Tab --
				if debugMenu then
					if (ImGui.BeginTabItem("Debug")) then
					settings = false

						if (ImGui.Button("Cycle")) then
							scanID = target.id
				    	ScanApp:ChangeScanAppearanceTo(target.handle, 'Cycle')
				    	app = ScanApp:GetScanAppearance(target.handle)
							debugIDs[app] = scanID
							-- Add new ID
							output = {}
							for i,v in pairs(debugIDs) do
		   						if output[v] == nil then
		        					output[v] = {}
		    					end

		    					table.insert(output[v], i)
							end

							sortedDebugIDs = output
				    end

				    ImGui.Spacing()

				    ImGui.InputText("ID", scanID, 100, ImGuiInputTextFlags.ReadOnly)
				    ImGui.InputText("AppString", app, 100, ImGuiInputTextFlags.ReadOnly)

				    ImGui.Spacing()

						if (ImGui.Button('Save IDs to file')) then
							print("Scan ID: "..scanID.." -- Added to clipboard")
							ImGui.SetClipboardText(scanID)
							Settings.LogToFile(sortedDebugIDs)
						end

						ImGui.Spacing()

						if (ImGui.BeginChild("Scrolling")) then
							for id, appArray in pairs(sortedDebugIDs) do
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
