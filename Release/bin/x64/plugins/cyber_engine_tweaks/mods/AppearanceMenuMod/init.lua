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

	 -- External Mods API --
	 AMM.TeleportMod = ''

	 -- Main Properties --
	 AMM.currentVersion = "1.9.7e"
	 AMM.updateNotes = require('update_notes.lua')
	 AMM.credits = require("credits.lua")
	 AMM.updateLabel = "WHAT'S NEW"
	 AMM.userSettings = AMM:PrepareSettings()
	 AMM.categories = AMM:GetCategories()
	 AMM.player = nil
	 AMM.currentTarget = ''
	 AMM.spawnedNPCs = {}
	 AMM.spawnedProps = {}
	 AMM.entitiesForRespawn = ''
	 AMM.allowedNPCs = AMM:GetSaveables()
	 AMM.searchQuery = ''
	 AMM.searchBarWidth = 500
	 AMM.equipmentOptions = AMM:GetEquipmentOptions()
	 AMM.followDistanceOptions = AMM:GetFollowDistanceOptions()
	 AMM.originalVehicles = ''
	 AMM.skipFrame = false

	 -- Hotkeys Properties --
	 AMM.selectedHotkeys = {}

	 -- Custom Appearance Properties --
	 AMM.collabs = AMM:SetupCollabAppearances()
	 AMM.setCustomApp = ''
	 AMM.activeCustomApps = {}
	 AMM.customAppDefaults = AMM:GetCustomAppearanceDefaults()
	 AMM.customAppOptions = {"Top", "Bottom", "Off"}
	 AMM.customAppPosition = "Top"

	 -- Modal Popup Properties --
	 AMM.currentFavoriteName = ''
	 AMM.popupEntity = ''

	 -- Configs --
	 AMM.playerAttached = false
	 AMM.playerInMenu = true
	 AMM.playerInPhoto = false
	 AMM.playerInVehicle = false
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
		 delayTimer = 0.0
		 buttonPressed = false
		 importInProgress = false
		 finishedUpdate = AMM:CheckDBVersion()

		 -- Load Modules --
		 AMM.Scan = require('Modules/scan.lua')
		 AMM.Swap = require('Modules/swap.lua')
		 AMM.Tools = require('Modules/tools.lua')
		 AMM.Props = require('Modules/props.lua')
		 AMM.Director = require('Modules/director.lua')

		 AMM:ImportUserData()
		 AMM:SetupVehicleData()
		 AMM:SetupJohnny()

		 -- Update after importing user data
		 AMM.Props:Update()

		 -- Adjust Prevention System Total Entities Limit --
		 TweakDB:SetFlat("PreventionSystem.setup.totalEntitiesLimit", 20)

		 AMM.player = Game.GetPlayer()

		 -- Check if user is in-game using WorldPosition --
		 -- Only way to set player attached if user reload all mods --
		 if AMM.player then
			 local playerPosition = AMM.player:GetWorldPosition()
			 if math.floor(playerPosition.z) ~= 0 then
				 AMM.playerAttached = true
				 AMM.playerInMenu = false

				 if next(AMM.spawnedNPCs) ~= nil then
				 	AMM:RespawnAll()
				 end
			 end
		 end

		 -- Setup GameSession --
		 GameSession.OnStart(function()
			 AMM.player = Game.GetPlayer()
			 AMM.playerAttached = true

			 AMM.Tools:CheckGodModeIsActive()

			 if next(AMM.spawnedNPCs) ~= nil then
			 	AMM:RespawnAll()
			 end

			 AMM.Props.activeProps = {}
			 AMM.Props.playerLastPos = ''

			 AMM.Director:StopAll()
		 end)

		 GameSession.OnEnd(function()
			 AMM.playerAttached = false
			 AMM.player = nil
		 end)

		 GameSession.OnPause(function()
			 AMM.playerInMenu = true
     end)

		 GameSession.OnResume(function()
			 AMM.playerInMenu = false
		 end)

		 -- Setup Cron to Export User data every 10 minutes --
		 Cron.Every(600, function()
			 AMM:ExportUserData()
		 end)

		 -- Setup Observers --
		 Observe('PhotoModePlayerEntityComponent', 'ListAllItems', function(self)
			 AMM.Tools.photoModePuppet = self.fakePuppet
		 end)

		 Observe("VehicleComponent", "OnVehicleStartedMountingEvent", function(self, event)
			 if AMM.Scan.drivers[AMM:GetScanID(event.character)] ~= nil then
				 local driver = AMM.Scan.drivers[AMM:GetScanID(event.character)]
				 AMM.Scan:SetDriverVehicleToFollow(driver)
		 	 elseif event.character:IsPlayer() then
				 AMM.playerInVehicle = not AMM.playerInVehicle

				 if not AMM.playerInVehicle then
					 if AMM.Scan.leftBehind ~= '' then
						 for _, lost in ipairs(AMM.Scan.leftBehind) do
						 	lost.ent:GetAIControllerComponent():StopExecutingCommand(lost.cmd, true)
							Util:TeleportNPCTo(lost.ent, Util:GetBehindPlayerPosition(5))
						 end

						 AMM.Scan.leftBehind = ''
					 end

					 if next(AMM.Scan.drivers) ~= nil then
						 AMM.Scan:UnmountDrivers()
					 end
				 elseif AMM.playerInVehicle and next(AMM.spawnedNPCs) ~= nil then
					 local target = Game.GetTargetingSystem():GetLookAtObject(AMM.player, false, false)
					 if target ~= nil and target:IsVehicle() then
						 AMM.Scan.vehicle = {handle = target, hash = tostring(target:GetEntityID().hash)}
						 AMM.Scan:AutoAssignSeats()
					 end
				 end
			 end
		 end)

		 Observe("PlayerPuppet", "OnAction", function(self, action)
		   local actionName = Game.NameToString(action:GetName(action))
       local actionType = action:GetType(action).value

       if actionName == 'TogglePhotoMode' then
	        if actionType == 'BUTTON_RELEASED' then
					 AMM.playerInPhoto = true
	         Game.SetTimeDilation(0)

					 if AMM.Tools.invisibleBody then
						Cron.After(1.0, function()
							local v = AMM.Tools:GetVTarget()
							AMM.Tools:ToggleInvisibleBody(v.handle)
						end)
					 end
					end
			 elseif actionName == 'ExitPhotoMode' then
				 if actionType == 'BUTTON_RELEASED' then
					 AMM.playerInPhoto = false

					 if AMM.Tools.lookAtLocked then
						 AMM.Tools:ToggleLookAt()
					 end

					 AMM.Tools.makeupToggle = true
					 AMM.Tools.accessoryToggle = true

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
			delayTimer = 0.0
			AMM.shouldCheckSavedAppearance = false
			buttonPressed = true
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

	 registerHotkey("amm_spawn_favorite", "Spawn Favorite", function()
		 if AMM.currentSpawn == '' then
			 local favorites = {}
			 for ent in db:nrows("SELECT * FROM entities WHERE entity_id IN (SELECT entity_id FROM favorites)") do
				 table.insert(favorites, AMM:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path))
			 end

			 for _, spawn in ipairs(favorites) do
				 local spawned = false
				 for _, ent in pairs(AMM.spawnedNPCs) do
					 if spawn.uniqueName() == ent.uniqueName() then
						 spawned = true
						 break
					 end
				 end

				 if not spawned then
					 AMM:SpawnNPC(spawn)
					 break
				 end
			 end
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
					spawn = AMM:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path)
				end

				if spawn ~= nil then
					AMM:SpawnNPC(spawn)
				end
			end
		end
	 end)

	 registerHotkey("amm_despawn_target", "Despawn Target", function()
		local target = AMM:GetTarget()
		if target ~= nil then
			local spawnedNPC = nil
			for _, spawn in pairs(AMM.spawnedNPCs) do
				if target.id == spawn.id then spawnedNPC = spawn break end
			end

			if spawnedNPC then
				AMM:DespawnNPC(spawnedNPC.uniqueName(), spawnedNPC.entityID)
			else
				Util:Despawn(target.handle)
			end
		end
	 end)

	 registerHotkey("amm_respawn_all", "Respawn All", function()
		buttonPressed = true
	 	AMM:RespawnAll()
	 end)

	 registerHotkey("amm_repair_vehicle", "Repair Vehicle", function()
		 local handle
		 local target = AMM:GetTarget()
  	 if target ~= nil and target.handle:IsVehicle() then
 			 handle = target.handle
		 else
			 local qm = AMM.player:GetQuickSlotsManager()
		 	 handle = qm:GetVehicleObject()
 		 end

		 if handle ~= nil then
		 	Util:RepairVehicle(handle)
		 end
	 end)

	 registerHotkey("amm_npc_talk", "NPC Talk", function()
		local target = AMM:GetTarget()
 		if target ~= nil and target.handle:IsNPC() then
			Util:NPCTalk(target.handle)
		end
	 end)

	 registerHotkey("amm_give_weapon", "Give Weapon", function()
		local target = AMM:GetTarget()
 		if target ~= nil and target.handle:IsNPC() then
			local es = Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem"))
      local weapon = es:GetActiveWeaponObject(AMM.player, 39)

      if weapon then
				local weaponTDBID = weapon:GetItemID().tdbid
				Util:EquipGivenWeapon(target.handle, weaponTDBID, AMM.Tools.forceWeapon)
			end
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
	 	AMM.Tools:FreezeTime()
	 end)

	 registerHotkey("amm_skip_frame", "Skip Frame", function()
	 	AMM.Tools:SkipFrame()
	 end)

	 registerHotkey("amm_toggle_lookAt", "Toggle Look At", function()
	 	AMM.Tools:ToggleLookAt()
	 end)

	 registerHotkey('amm_toggle_head', 'Toggle V Head', function()
		 AMM.Tools:ToggleHead()
	 end)

	 registerHotkey('amm_toggle_hud', 'Toggle HUD', function()
	    GameSettings.Toggle('/interface/hud/action_buttons')
	    GameSettings.Toggle('/interface/hud/activity_log')
	    GameSettings.Toggle('/interface/hud/ammo_counter')
	    GameSettings.Toggle('/interface/hud/healthbar')
	    GameSettings.Toggle('/interface/hud/input_hints')
	    GameSettings.Toggle('/interface/hud/johnny_hud')
	    GameSettings.Toggle('/interface/hud/minimap')
	    GameSettings.Toggle('/interface/hud/npc_healthbar')
	    GameSettings.Toggle('/interface/hud/quest_tracker')
	    GameSettings.Toggle('/interface/hud/stamina_oxygen')
	 end)

	 for i = 1, 3 do
		 registerHotkey(f('amm_appearance_hotkey%i', i), f('Appearance Hotkey %i', i), function()
				local target = AMM:GetTarget()
		 		if target ~= nil and AMM.selectedHotkeys[target.id][i] ~= '' then
		 			delayTimer = 0.0
		 			AMM.shouldCheckSavedAppearance = false
		 			buttonPressed = true
		 			AMM:ChangeAppearanceTo(target, AMM.selectedHotkeys[target.id][i])
		 		end
		 end)
	 end

	 registerForEvent("onUpdate", function(deltaTime)
		 -- Setup Travel Mod API --
		 local mod = GetMod("gtaTravel")
		 if mod ~= nil and AMM.TeleportMod == '' then
			 AMM.TeleportMod = mod
			 AMM.Tools.useTeleportAnimation = AMM.userSettings.teleportAnimation
		 end

		 -- This is required for Cron to function
     Cron.Update(deltaTime)

		 if AMM.playerAttached and not(AMM.playerInMenu) then
				if finishedUpdate and AMM.player ~= nil then
					-- Check Custom Defaults --
					local target = AMM:GetTarget()
					AMM:CheckCustomDefaults(target)
			 		-- Load Saved Appearance --
			 		if not drawWindow and AMM.shouldCheckSavedAppearance then
			 			AMM:CheckSavedAppearance(target)
						AMM.shouldCheckSavedAppearance = false
			 		elseif AMM.shouldCheckSavedAppearance == false then
						delayTimer = delayTimer + deltaTime
						delay = 1.0

						if buttonPressed then delay = 8 end

						if delayTimer > delay then
							delayTimer = 0.0
							AMM.shouldCheckSavedAppearance = true
							if buttonPressed then buttonPressed = false end
						end
					end

					-- Trigger Sensing Check --
					if not drawWindow and AMM.playerAttached then
						AMM.Director:SenseNPCTalk()
						AMM.Director:SenseTriggers()
						AMM.Props:SensePropsTriggers()
					end

					-- Travel Animation Done Check --
					if AMM.TeleportMod ~= '' and AMM.TeleportMod.api.done then
						if next(AMM.spawnedNPCs) ~= nil then
							AMM:TeleportAll()
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
					      AMM:TeleportAll()
					    end
						end
					end


					-- Tools Skip Frame Logic --
					if AMM.skipFrame then
						waitTimer = waitTimer + deltaTime

						if waitTimer > 0.01 then
							AMM.skipFrame = false
							AMM.Tools:FreezeTime()
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

					-- After Custom Appearance Set --
					if AMM.setCustomApp ~= '' then
						waitTimer = waitTimer + deltaTime
						if waitTimer > 0.1 then
							local handle, customAppearance = AMM.setCustomApp[1], AMM.setCustomApp[2]
							local currentAppearance = AMM:GetScanAppearance(handle)
							if currentAppearance == customAppearance[1].app_base then
								for _, param in ipairs(customAppearance) do
									local appParam = handle:FindComponentByName(CName.new(param.app_param))
									if param.mesh_type == "body" then
										if param.mesh_app then
											appParam.meshAppearance = CName.new(param.mesh_app)
										end

										if appParam.chunkMask ~= param.mesh_mask and not(string.find(param.app_name, "Underwear")) then
											appParam.chunkMask = 18446744073709551615ULL
											if param.mesh_mask then
												appParam.chunkMask = loadstring("return "..param.mesh_mask, '')()
											end
										end

										appParam:Toggle(false)
										appParam:Toggle(true)
										appParam:TemporaryHide(false)
									elseif appParam then
										if not param.app_toggle then
											appParam.chunkMask = 18446744073709551615ULL
											appParam:Toggle(false)
											appParam:Toggle(true)
											appParam:TemporaryHide(false)
										else
											appParam:TemporaryHide(true)
										end
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
						if waitTimer > 0.2 and waitTimer < 30.0 then
							local handle
							if AMM.spawnedNPCs[AMM.currentSpawn] ~= nil and string.find(AMM.spawnedNPCs[AMM.currentSpawn].path, "Vehicle") then
								handle = Game.GetTargetingSystem():GetLookAtObject(AMM.player, false, false)
							elseif AMM.spawnedNPCs[AMM.currentSpawn] ~= nil then
								handle = Game.FindEntityByID(AMM.spawnedNPCs[AMM.currentSpawn].entityID)
							end
							if handle then
								AMM.spawnedNPCs[AMM.currentSpawn].handle = handle
								AMM.spawnedNPCs[AMM.currentSpawn].hash = tostring(handle:GetEntityID().hash)
								if handle:IsNPC() then
									if not(string.find(AMM.spawnedNPCs[AMM.currentSpawn].name, "Drone")) then
										Util:TeleportNPCTo(handle)
									end
									if AMM.spawnedNPCs[AMM.currentSpawn].parameters ~= nil then
										if AMM.spawnedNPCs[AMM.currentSpawn].parameters == "special__vr_tutorial_ma_dummy_light" then -- Extra Handling for Johnny
											AMM:ChangeScanCustomAppearanceTo(AMM.spawnedNPCs[AMM.currentSpawn], AMM:GetCustomAppearanceParams(AMM.spawnedNPCs[AMM.currentSpawn], 'silverhand_default'))
										else
											AMM:ChangeScanAppearanceTo(AMM.spawnedNPCs[AMM.currentSpawn], AMM.spawnedNPCs[AMM.currentSpawn].parameters)
										end
									end
									if AMM.spawnAsCompanion and AMM.spawnedNPCs[AMM.currentSpawn].canBeCompanion then
										AMM:SetNPCAsCompanion(handle)
									else
										waitTimer = 0.0
										AMM.currentSpawn = ''
									end
								elseif handle:IsVehicle() then
									if AMM.spawnedNPCs[AMM.currentSpawn].parameters ~= nil then
										AMM:ChangeScanAppearanceTo(AMM.spawnedNPCs[AMM.currentSpawn], AMM.spawnedNPCs[AMM.currentSpawn].parameters)
									end
									AMM:UnlockVehicle(handle)
									waitTimer = 0.0
									AMM.currentSpawn = ''
								else
									waitTimer = 0.0
									AMM.currentSpawn = ''
								end
							end
						elseif waitTimer > 30.0 then
							waitTimer = 0.0
							AMM.currentSpawn = ''
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
				AMM:UpdateSettings()
			end

			AMM.UI:Start()

			AMM:Begin()

			AMM.UI:End()
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
			local notes = AMM.updateNotes

			if finishedUpdate and AMM.playerAttached == false then
				AMM.UI:TextColored("Player In Menu")
				ImGui.Text("AMM only functions in game")

				if AMM.updateLabel ~= "CREDITS" then
					AMM.updateLabel = 'UPDATE HISTORY'
					notes = AMM.updateNotes
				else
					notes = AMM.credits
				end

				ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(" Updates "))

				local buttonLabel = " Credits "
				if AMM.updateLabel == "CREDITS" then
					buttonLabel = " Updates "
				end
				if ImGui.SmallButton(buttonLabel) then
					if AMM.updateLabel == "CREDITS" then
						AMM.updateLabel = 'UPDATE HISTORY'
					else
						AMM.updateLabel = "CREDITS"
					end
				end

				AMM.UI:Separator()
			end

			-- UPDATE NOTES
			AMM.UI:Spacing(8)
			AMM.UI:TextCenter(AMM.updateLabel, true)
			if AMM.updateLabel == "WHAT'S NEW" then
				ImGui.Spacing()
				AMM.UI:TextCenter(AMM.currentVersion, false)
			end
			AMM.UI:Separator()

			if not(finishedUpdate) then
				AMM.UI:Spacing(4)
				if ImGui.Button("Cool!", ImGui.GetWindowContentRegionWidth(), 40) then
					AMM:FinishUpdate()
				end
				AMM.UI:Separator()
			end

			for i, versionArray in ipairs(notes) do
				local treeNode = ImGui.TreeNodeEx(versionArray[1], ImGuiTreeNodeFlags.DefaultOpen + ImGuiTreeNodeFlags.NoTreePushOnOpen + ImGuiTreeNodeFlags.Framed)
				local releaseDate = versionArray[2]
				local dateLength = ImGui.CalcTextSize(releaseDate)
				ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - dateLength)
				AMM.UI:TextColored(releaseDate)

				if treeNode then
					ImGui.TreePush(tostring(i))
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

					AMM.UI:Spacing(3)
					ImGui.TreePop()
				end
			end
		else
			-- Target Setup --
			target = AMM:GetTarget()

			if ImGui.BeginTabBar("TABS") then

				local style = {
	        buttonWidth = -1,
	        buttonHeight = ImGui.GetFontSize() * 2,
	        halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
		    }

				-- Scan Tab --
				AMM.Scan:Draw(AMM, target, style)

				-- Spawn Tab --
				if (ImGui.BeginTabItem("Spawn")) then

					if AMM.playerInMenu and not AMM.playerInPhoto then
						AMM.UI:TextColored("Player In Menu")
						ImGui.Text("Spawning only works in game")
					else
						if next(AMM.spawnedNPCs) ~= nil then
							AMM.UI:TextColored("Active Spawns "..AMM.spawnsCounter.."/"..AMM.maxSpawns)

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
										Cron.After(0.2, function()
											AMM:SpawnNPC(spawn)
										end)
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


								if spawn.handle ~= '' then
									ImGui.SameLine()
									if ImGui.SmallButton("Target".."##"..spawn.name) then
										AMM.Tools:SetCurrentTarget(spawn)
										AMM.Tools.lockTarget = true
									end
								end

								if spawn.handle ~= '' and not(spawn.handle:IsVehicle()) and not(spawn.handle:IsDevice()) and not(spawn.handle:IsDead()) and AMM:CanBeHostile(spawn.handle) then

									local hostileButtonLabel = "Hostile"
									if not(spawn.handle.isPlayerCompanionCached) then
										hostileButtonLabel = "Friendly"
									end

									ImGui.SameLine()
									if ImGui.SmallButton(hostileButtonLabel.."##"..spawn.name) then
										AMM:ToggleHostile(spawn.handle)
									end

									ImGui.SameLine()
									if ImGui.SmallButton("Equipment".."##"..spawn.name) then
										popupDelegate = AMM:OpenPopup(spawn.name.."'s Equipment")
									end

									AMM:BeginPopup(spawn.name.."'s Equipment", spawn.path, false, popupDelegate, style)
								end
							end

							AMM.UI:Separator()
						elseif AMM.playerInPhoto then
							ImGui.NewLine()
							ImGui.Text("No Active Spawns")
							ImGui.NewLine()
						end

						if next(AMM.spawnedProps) ~= nil then
							AMM.UI:TextColored("Active Props ")

							for _, spawn in pairs(AMM.spawnedProps) do
								local nameLabel = spawn.name
								ImGui.Text(nameLabel)

								local favoritesLabels = {"Favorite", "Unfavorite"}
								AMM:DrawFavoritesButton(favoritesLabels, spawn)

								ImGui.SameLine()

								if AMM.savingProp == spawn.name then
									AMM.UI:TextColored("Moving "..nameLabel.." to Decor tab")

									Cron.After(2.0, function()
										AMM.savingProp = ''
									end)
								else

									if ImGui.SmallButton("Save Prop##"..spawn.name) then
										if spawn.handle ~= '' then
											AMM.Props:SavePropPosition(spawn)
											AMM.savingProp = spawn.name
										end
									end

									ImGui.SameLine()
									if ImGui.SmallButton("Despawn##"..spawn.name) then
										if spawn.handle ~= '' then
											AMM:DespawnProp(spawn)
										end
									end

									-- if spawn.handle ~= '' and AMM:GetScanClass(spawn.handle) ~= 'entEntity' then
									if spawn.handle ~= '' then
										ImGui.SameLine()
										if ImGui.SmallButton("Target".."##"..spawn.name) then
											AMM.Tools:SetCurrentTarget(spawn)
											AMM.Tools.lockTarget = true
										end
									end
								end
							end

							AMM.UI:Separator()
						end

						if not AMM.playerInPhoto then

							ImGui.PushItemWidth(AMM.searchBarWidth)
							AMM.searchQuery = ImGui.InputTextWithHint(" ", "Search", AMM.searchQuery, 100)
							AMM.searchQuery = AMM.searchQuery:gsub('"', '')
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
									table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path, en.template_path})
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
										if ImGui.CollapsingHeader(category.cat_name) then
											local entities = {}
											if category.cat_name == 'Favorites' then
												local query = "SELECT * FROM favorites"
												for fav in db:nrows(query) do
													query = f("SELECT * FROM entities WHERE entity_id = '%s'", fav.entity_id)
													for en in db:nrows(query) do
														if fav.parameters ~= nil then en.parameters = fav.parameters end
														table.insert(entities, {fav.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path, en.template_path})
													end
												end
												if #entities == 0 then
													ImGui.Text("It's empty :(")
												end
											end

											local query = f("SELECT * FROM entities WHERE is_spawnable = 1 AND cat_id == '%s' ORDER BY entity_name ASC", category.cat_id)
											for en in db:nrows(query) do
												table.insert(entities, {en.entity_name, en.entity_id, en.can_be_comp, en.parameters, en.entity_path, en.template_path})
											end

											AMM:DrawEntitiesButtons(entities, category.cat_name, style)
										end
									end
								end
								ImGui.EndChild()
							end
						end
					end

					ImGui.EndTabItem()
				end

				-- Swap Tab --
				AMM.Swap:Draw(AMM, target)

				-- Props Tab --
				AMM.Props:Draw(AMM)

				-- Tools Tab --
				AMM.Tools:Draw(AMM, target)

				-- Director Tab --
				AMM.Director:Draw(AMM)

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

					AMM.UI:Spacing(3)

					AMM.UI:TextColored("Companion Distance:")

					for _, option in ipairs(AMM.followDistanceOptions) do
						if ImGui.RadioButton(option[1], AMM.followDistance[1] == option[1]) then
							AMM.followDistance = option
							AMM:UpdateFollowDistance()
						end

						ImGui.SameLine()
					end

					AMM.UI:Spacing(3)

					AMM.UI:TextColored("Custom Appearances:")

					for _, option in ipairs(AMM.customAppOptions) do
						if ImGui.RadioButton(option, AMM.customAppPosition == option) then
							AMM.customAppPosition = option
						end

						ImGui.SameLine()
					end

					AMM.UI:Spacing(3)

					AMM.UI:TextColored("Saved Appearances Hotkeys:")

					if target ~= nil and (target.type == "NPCPuppet" or target.type == "vehicle") then
						AMM:DrawHotkeySelection()
					else
						AMM.UI:Spacing(3)
						AMM.UI:TextCenter("Target NPC or Vehicle to Set Hotkeys")
					end

					ImGui.Spacing()

					if clicked then AMM:UpdateSettings() end

					if expClicked then
						AMM:UpdateSettings()
						AMM.categories = AMM:GetCategories()

						if AMM.userSettings.experimental then
							popupDelegate = AMM:OpenPopup("Experimental")
						end
					end

					AMM.UI:Separator()

					ImGui.Spacing()

					AMM.UI:TextColored("Reset Actions:")

					if AMM.userSettings.experimental then
						if ImGui.Button("Revert All Model Swaps", style.halfButtonWidth, style.buttonHeight) then
							AMM:RevertTweakDBChanges(true)
						end

						ImGui.SameLine()
						if ImGui.Button("Respawn All", style.halfButtonWidth, style.buttonHeight) then
							AMM:RespawnAll()
						end
					end


					if ImGui.Button("Force Despawn All", style.halfButtonWidth, style.buttonHeight) then
						AMM:DespawnAll(true)
					end

					ImGui.SameLine()
					if ImGui.Button("Clear All Favorites", style.halfButtonWidth, style.buttonHeight) then
						popupDelegate = AMM:OpenPopup("Favorites")
					end

					if ImGui.Button("Clear All Saved Appearances", style.buttonWidth, style.buttonHeight) then
						popupDelegate = AMM:OpenPopup("Appearances")
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
							ImGui.EndListBox()
						end

						if ImGui.SmallButton("  Create Theme  ") then
							AMM.Editor:Setup()
							AMM.Editor.isEditing = true
						end

						ImGui.SameLine()
						if ImGui.SmallButton("  Delete Theme  ") then
							AMM.UI:DeleteTheme(AMM.selectedTheme)
							AMM.selectedTheme = "Default"
						end
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
				ImGui.EndTabBar()
			end
		end
	end
	ImGui.End()
end

-- AMM Objects
function AMM:NewSpawn(name, id, parameters, companion, path, template)
	local obj = {}
	if type(id) == 'userdata' then id = tostring(id) end
	obj.handle = ''
	obj.name = name
	obj.id = id
	obj.hash = ''
	obj.uniqueName = function() return obj.name.."##"..obj.id end
	obj.parameters = parameters
	obj.canBeCompanion = intToBool(companion)
	obj.path = path
	obj.template = template or ''
	obj.type = 'Spawn'
	obj.entityID = ''

	if string.find(obj.path, "Props") then
		obj.type = 'Props'
	end

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
	obj.hash = tostring(handle:GetEntityID().hash)
	obj.name = name
	obj.appearance = app
	obj.type = targetType
	obj.options = options or nil

	-- Check if target is V
	if obj.name == "V" or Util:CheckVByID(obj.id) then
		obj.type = "Player"
	end

	-- Check if model is swappedModels
	if self.Swap.activeSwaps[obj.id] ~= nil then
		obj.id = self.Swap.activeSwaps[obj.id].newID
	end

	-- Check if custom appearance is active
	if self.activeCustomApps[obj.hash] ~= nil then
		obj.appearance = self.activeCustomApps[obj.hash]
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
	importInProgress = true

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
				if userData['followDistance'] ~= nil then
					self.followDistance = userData['followDistance']
				end

				self.customAppPosition = userData['customAppPosition'] or "Top"
				self.selectedTheme = userData['selectedTheme'] or "Default"
				self.selectedHotkeys = userData['selectedHotkeys'] or {}

				if userData['settings'] ~= nil then
					for _, obj in ipairs(userData['settings']) do
						db:execute(f("UPDATE settings SET setting_name = '%s', setting_value = %i WHERE setting_name = '%s'", obj.setting_name, boolToInt( obj.setting_value),  obj.setting_name))
					end
				end
				if userData['favorites'] ~= nil then
					for _, obj in ipairs(userData['favorites']) do
						local command = f("INSERT INTO favorites (position, entity_id, entity_name, parameters) VALUES (%i, '%s', '%s', '%s')", obj.position, obj.entity_id, obj.entity_name, obj.parameters)
						command = command:gsub("'nil'", "NULL")
						db:execute(command)
					end
				end
				if userData['favorites_swap'] ~= nil then
					for _, obj in ipairs(userData['favorites_swap']) do
						local command = f("INSERT INTO favorites_swap (position, entity_id) VALUES (%i, '%s')", obj.position, obj.entity_id)
						db:execute(command)
					end
				end
				if userData['saved_appearances'] ~= nil then
					for _, obj in ipairs(userData['saved_appearances']) do
						db:execute(f("INSERT INTO saved_appearances (entity_id, app_name) VALUES ('%s', '%s')", obj.entity_id, obj.app_name))
					end
				end
				if userData['blacklist_appearances'] ~= nil then
					for _, obj in ipairs(userData['blacklist_appearances']) do
						db:execute(f("INSERT INTO blacklist_appearances (entity_id, app_name) VALUES ('%s', '%s')", obj.entity_id, obj.app_name))
					end
				end
				if userData['saved_props'] ~= nil then
					for i, obj in ipairs(userData['saved_props']) do
						db:execute(f('INSERT INTO saved_props (uid, entity_id, name, template_path, pos, trigger, tag) VALUES (%i, "%s", "%s", "%s", "%s", "%s", "%s")', obj.uid or i, obj.entity_id, obj.name, obj.template_path, obj.pos, obj.trigger, obj.tag))
					end
				end
			end
		end
	end

	importInProgress = false
end

function AMM:ExportUserData()
	if not importInProgress then
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
		userData['blacklist_appearances'] = {}
		for r in db:nrows("SELECT * FROM blacklist_appearances") do
			table.insert(userData['blacklist_appearances'], {entity_id = r.entity_id, app_name = r.app_name})
		end
		userData['saved_props'] = {}
		for r in db:nrows("SELECT * FROM saved_props") do
			table.insert(userData['saved_props'], {uid = r.uid, entity_id = r.entity_id, name = r.name, template_path = r.template_path, pos = r.pos, trigger = r.trigger, tag = r.tag})
		end
		userData['selectedTheme'] = self.selectedTheme
		userData['spawnedNPCs'] = self:PrepareExportSpawnedData()
		userData['savedSwaps'] = self.Swap:GetSavedSwaps()
		userData['favoriteLocations'] = self.Tools:GetFavoriteLocations()
		userData['followDistance'] = self.followDistance
		userData['customAppPosition'] = self.customAppPosition
		userData['selectedHotkeys'] = self.selectedHotkeys

		local validJson, contents = pcall(function() return json.encode(userData) end)
		if validJson and contents ~= nil then
			local file = io.open("User/user.json", "w")
			if file then
				file:write(contents)
				file:close()
			end
		end
	end
end

function AMM:PrepareImportSpawnedData(savedIDs)
	local savedEntities = {}

	for _, id in ipairs(savedIDs) do
		for ent in db:nrows(f("SELECT * FROM entities WHERE entity_id = '%s'", id)) do
			spawn = AMM:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path)
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

function AMM:GetPossibleVOs()
	local VOs = {
		{label = "Greet V", param = "greeting"},
		{label = "Fear Foll", param = "fear_foll"},
		{label = "Fear Toll", param = "fear_toll"},
		{label = "Fear Beg", param = "fear_beg"},
		{label = "Fear Run", param = "fear_run"},
		{label = "Stealth Search", param = "stlh_search"},
		{label = "Stealth Death", param = "stlh_death"},
		{label = "Stealth Restore", param = "stealth_restored"},
		{label = "Stealth End", param = "stealth_ended"},
		{label = "Curious Grunt", param = "stlh_curious_grunt"},
		{label = "Grapple Grunt", param = "grapple_grunt"},
		{label = "Bump", param = "bump"},
		{label = "Vehicle Bump", param = "vehicle_bump"},
		{label = "Turret Warning", param = "turret_warning"},
		{label = "Octant Warning", param = "octant_warning"},
		{label = "Drone Warning", param = "drones_warning"},
		{label = "Mech Warning", param = "mech_warning"},
		{label = "Elite Warning", param = "elite_warning"},
		{label = "Camera Warning", param = "camera_warning"},
		{label = "Enemy Warning", param = "enemy_warning"},
		{label = "Heavy Warning", param = "heavy_warning"},
		{label = "Sniper Warning", param = "sniper_warning"},
		{label = "Any Damage", param = "vo_any_damage_hit"},
		{label = "Danger", param = "danger"},
		{label = "Combat Start", param = "start_combat"},
		{label = "Combat End", param = "combat_ended"},
		{label = "Combat Target Hit", param = "combat_target_hit"},
		{label = "Pedestrian Hit", param = "pedestrian_hit"},
		{label = "Light Hit", param = "hit_reaction_light"},
		{label = "Curse", param = "battlecry_curse"},
		{label = "Irritated", param = "coop_irritation"},
		{label = "Grenade Throw", param = "grenade_throw"},
		{label = "Got a kill!", param = "coop_reports_kill"},
	}

	return VOs
end

function AMM:GetPersonalityOptions()
	local personalities = {
		{name = "Default", idle = 2, category = 2},
		{name = "Joy", idle = 5, category = 3},
		{name = "Aggressive", idle = 1, category = 3},
		{name = "Fury", idle = 2, category = 3},
		{name = "Curiosity", idle = 3, category = 1},
		{name = "Disgust", idle = 7, category = 3},
		{name = "Fear", idle = 10, category = 3},
		{name = "Sad", idle = 3, category = 3},
		{name = "Surprise", idle = 8, category = 3},
		{name = "Are You Serious?", idle = 2, category = 1},
		{name = "Drunk", idle = 4, category = 1},
		{name = "Sleepy", idle = 5, category = 1},
		{name = "Bored", idle = 6, category = 1},
		{name = "Fake Smile", idle = 6, category = 3},
		{name = "Pissed", idle = 7, category = 3},
		{name = "Terrified", idle = 9, category = 3},
		{name = "Shocked", idle = 11, category = 3},
	}

	return personalities
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

function AMM:GetFollowDistanceOptions()
	local options = {
		{"Close", -0.8, 2, 2.5},
		{"Default", 1, 2, 2.5},
		{"Far", 1.5, 2.5, 3},
	}

	-- Set Default
	AMM.followDistance = options[2]
	return options
end

function AMM:GetCustomAppearanceDefaults()
	local customs = {
		['hx_001_ma_c__kerry_eurodyne_old_pimples_01'] = {
			['kerry_eurodyne_nude'] = true,
			['kerry_eurodyne__q203__shower'] = true,
			['Custom Young Kerry Naked'] = true,
			['Custom Young Kerry 2013 Naked'] = true,
		},

		['hx_001_ma_a__yorinobu_arasaka_pimples_01'] = {
			['Custom Yorinobu Naked'] = true,
			['Custom Yorinobu Kimono Naked'] = true,
		},

		['hx_793_mb_c__ma_758_pimples_01'] = {
			['Custom Benjamin Stone Naked'] = true,
		},
	}

	if #AMM.collabs > 0 then
		for _, collab in ipairs(AMM.collabs) do
			if collab.disabledByDefault then
				for _, default in ipairs(collab.disabledByDefault) do
					for _, app in ipairs(default.allowedApps) do
						customs[default.component][app] = true
					end
				end
			end
		end
	end

	return customs
end

function AMM:RevertTweakDBChanges(userActivated)
	if next(self.Swap.activeSwaps) ~= nil then
		for swapID, swapObj in pairs(self.Swap.activeSwaps) do
			self.Swap:ChangeEntityTemplateTo(swapObj.name, swapID, swapID)
		end
	end

	if not(userActivated) then
		TweakDB:SetFlat(TweakDBID.new('Vehicle.vehicle_list.list'), self.originalVehicles)
	end
end

function AMM:SetupCustomProps()
	-- for prop in db:nrows("SELECT * FROM entities WHERE entity_path LIKE '%AMM_Props%'") do
	-- 	TweakDB:CloneRecord(prop.entity_path, "Props.prop_test")
	-- 	TweakDB:SetFlat(prop.entity_path..".entityTemplatePath", prop.template_path)
	-- end
end

function AMM:SetupCollabAppearances()
	local files = dir("./Collabs")
  local collabs = {}
	if #files > 0 then
	  for _, mod in ipairs(files) do
	    if string.find(mod.name, '.lua') then
				local collab = require("Collabs/"..mod.name)
				local metadata = collab.metadata

				for _, newApp in ipairs(metadata) do
					newApp.disabledByDefault = collab.disabledByDefault
					table.insert(collabs, newApp)

					local customApps = collab.customApps[newApp.tag]

					if customApps then

						local check = 0
						for count in db:urows(f("SELECT COUNT(1) FROM custom_appearances WHERE collab_tag = '%s'", newApp.tag)) do
							check = count
						end

						if check ~= 0 then
							db:execute(f("DELETE FROM custom_appearances WHERE collab_tag = '%s'", newApp.tag))
						end

						for _, customApp in ipairs(customApps) do
							local tables = '("entity_id", "app_name", "app_base", "app_param", "app_toggle", "mesh_app", "mesh_type", "mesh_mask", "collab_tag")'
							local values = f('("%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s")', newApp.entity_id, customApp.app_name, newApp.appearance, customApp.app_param, customApp.app_toggle, customApp.mesh_app, customApp.mesh_type, customApp.mesh_mask, newApp.tag)
							values = values:gsub('"nil"', "NULL")
							db:execute(f('INSERT INTO custom_appearances %s VALUES %s', tables, values))
						end
					end
				end
	    end
	  end
	end

	return collabs
end

function AMM:SetupJohnny()
	TweakDB:SetFlat("Character.TPP_Player_Cutscene_Female.fullDisplayName", TweakDB:GetFlat("Character.TPP_Player.displayName"))
	TweakDB:SetFlat("Character.TPP_Player_Cutscene_Male.fullDisplayName", TweakDB:GetFlat("Character.TPP_Player.displayName"))
	TweakDB:SetFlatNoUpdate(TweakDBID.new("Character.q000_tutorial_course_01_patroller.voiceTag"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.voiceTag")))
	TweakDB:SetFlatNoUpdate(TweakDBID.new("Character.q000_tutorial_course_01_patroller.displayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.displayName")))
	TweakDB:SetFlatNoUpdate(TweakDBID.new("Character.q000_tutorial_course_01_patroller.alternativeDisplayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.alternativeDisplayName")))
	TweakDB:SetFlatNoUpdate(TweakDBID.new("Character.q000_tutorial_course_01_patroller.alternativeFullDisplayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.alternativeFullDisplayName")))
	TweakDB:SetFlatNoUpdate(TweakDBID.new("Character.q000_tutorial_course_01_patroller.fullDisplayName"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.fullDisplayName")))
	TweakDB:SetFlatNoUpdate(TweakDBID.new("Character.q000_tutorial_course_01_patroller.affiliation"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.affiliation")))
	TweakDB:SetFlatNoUpdate(TweakDBID.new("Character.q000_tutorial_course_01_patroller.statPools"), TweakDB:GetFlat(TweakDBID.new("Character.Silverhand.statPools")))
	TweakDB:Update(TweakDBID.new("Character.q000_tutorial_course_01_patroller"))
end

function AMM:SetupVehicleData()
	local unlockableVehicles = TweakDB:GetFlat(TweakDBID.new('Vehicle.vehicle_list.list'))
	AMM.originalVehicles = unlockableVehicles
	for vehicle in db:urows("SELECT entity_path FROM entities WHERE cat_id = 24 OR cat_id = 25 AND entity_path LIKE '%Vehicle%'") do
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
		local distanceFromGround = tonumber(spawn.parameters) or 0

		if spawn.parameters and string.find(spawn.parameters, "dist") then
			distanceFromPlayer = spawn.parameters:match("%d+")
		end

		local player = AMM.player
		local heading = player:GetWorldForward()
		local offsetDir = Vector3.new(heading.x * distanceFromPlayer, heading.y * distanceFromPlayer, heading.z)
		local spawnTransform = player:GetWorldTransform()
		local spawnPosition = GetSingleton('WorldPosition'):ToVector4(spawnTransform.Position)
		local newPosition = Vector4.new((spawnPosition.x - offSetSpawn) - offsetDir.x, (spawnPosition.y - offSetSpawn) - offsetDir.y, spawnPosition.z + distanceFromGround, spawnPosition.w)

		-- if spawn.type == "Props" then
		-- 	newPosition = Vector4.new((spawnPosition.x - offSetSpawn) + offsetDir.x, (spawnPosition.y - offSetSpawn) + offsetDir.y, spawnPosition.z + distanceFromGround, spawnPosition.w)
		-- end

		spawnTransform:SetPosition(spawnTransform, newPosition)
		spawn.entityID = Game.GetPreventionSpawnSystem():RequestSpawn(self:GetNPCTweakDBID(spawn.path), -99, spawnTransform)
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
		AMM.player:SetWarningMessage("Spawn limit reached!")
	end
end

function AMM:DespawnNPC(npcName, spawnID)
	--AMM.player:SetWarningMessage(npcName:match("(.+)##(.+)").." will despawn once you look away")
	self.spawnedNPCs[npcName] = nil
	self.spawnsCounter = self.spawnsCounter - 1
	local handle = Game.FindEntityByID(spawnID)
	if handle then
		if handle:IsNPC() then
			Util:TeleportNPCTo(handle, Util:GetBehindPlayerPosition(2))
		end
	end
	Game.GetPreventionSpawnSystem():RequestDespawn(spawnID)
end

function AMM:SpawnProp(spawn)
	local offSetSpawn = 0
	local distanceFromPlayer = 1
	local angles = GetSingleton('Quaternion'):ToEulerAngles(AMM.player:GetWorldOrientation())
	local distanceFromGround = tonumber(spawn.parameters) or 0

	if spawn.parameters and string.find(spawn.parameters, "dist") then
		distanceFromPlayer = spawn.parameters:match("%d+")
	end

	if spawn.parameters and string.find(spawn.parameters, "rot") then
		rotation = tonumber(spawn.parameters:match("%d+"))
	end

	local heading = AMM.player:GetWorldForward()
	local offsetDir = Vector3.new(heading.x * distanceFromPlayer, heading.y * distanceFromPlayer, heading.z)
	local spawnTransform = AMM.player:GetWorldTransform()
	local spawnPosition = GetSingleton('WorldPosition'):ToVector4(spawnTransform.Position)
	local newPosition = Vector4.new((spawnPosition.x - offSetSpawn) + offsetDir.x, (spawnPosition.y - offSetSpawn) + offsetDir.y, spawnPosition.z + distanceFromGround, spawnPosition.w)
	spawnTransform:SetPosition(spawnTransform, newPosition)
	spawnTransform:SetOrientationEuler(spawnTransform, EulerAngles.new(0, 0, angles.yaw - 180))

	spawn.entityID = WorldFunctionalTests.SpawnEntity(spawn.template, spawnTransform, '')

	Cron.Every(0.1, {tick = 1}, function(timer)
		local entity = Game.FindEntityByID(spawn.entityID)
		if entity then
			spawn.handle = entity
			spawn.parameters = {newPosition, GetSingleton('Quaternion'):ToEulerAngles(AMM.player:GetWorldOrientation())}
			if AMM:GetScanClass(spawn.handle) == 'entEntity' then
				spawn.type = 'entEntity'
			end
			Cron.Halt(timer)
		elseif tick > 20 then
			spawn.parameters = {newPosition, GetSingleton('Quaternion'):ToEulerAngles(AMM.player:GetWorldOrientation())}
			Cron.Halt(timer)
		end
	end)

	while self.spawnedProps[spawn.uniqueName()] ~= nil do
		local num = spawn.name:match("%((%g+)%)")
		if num then num = tonumber(num) + 1 else num = 1 end
		spawn.name = spawn.name:gsub(" %("..tostring(num - 1).."%)", "")
		spawn.name = spawn.name.." ("..tostring(num)..")"
	end

	self.spawnedProps[spawn.uniqueName()] = spawn
end

function AMM:DespawnProp(ent)
	WorldFunctionalTests.DespawnEntity(ent.handle)
	self.spawnedProps[ent.uniqueName()] = nil
end

function AMM:DespawnAll(message)
	if message then AMM.player:SetWarningMessage("Despawning will occur once you look away") end
	for i = 0, 99 do
		Game.GetPreventionSpawnSystem():RequestDespawnPreventionLevel(i * -1)
	end
	self.spawnsCounter = 0
	self.spawnedNPCs = {}
end

function AMM:TeleportAll()
	for _, ent in pairs(AMM.spawnedNPCs) do
		Util:TeleportNPCTo(ent.handle, Util:GetBehindPlayerPosition(2))
	end
end

function AMM:RespawnAll()
	if AMM.entitiesForRespawn == '' then
		AMM.entitiesForRespawn = {}
		for _, ent in pairs(AMM.spawnedNPCs) do
			if not(string.find(ent.path, "Vehicle")) then
				table.insert(AMM.entitiesForRespawn, ent)
			end
		end

		AMM:DespawnAll(buttonPressed)
		if buttonPressed then buttonPressed = false end
	end

	Cron.Every(0.5, function(timer)
		local entity = Game.FindEntityByID(AMM.entitiesForRespawn[1].entityID)
		if entity == nil then
			ent = AMM.entitiesForRespawn[1]
			table.remove(AMM.entitiesForRespawn, 1)
			AMM:SpawnNPC(ent)
		end

		if #AMM.entitiesForRespawn == 0 then
			AMM.entitiesForRespawn = ''
			Cron.Halt(timer)
		end
	end)
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

	AMM:ExportUserData()
end

function AMM:CheckCustomDefaults(target)
	if target ~= nil and target.type == "NPCPuppet" then
		for component, apps in pairs(AMM.customAppDefaults) do
			local appParam = target.handle:FindComponentByName(CName.new(component))
			if appParam then
				if not apps[target.appearance] then
					-- print(target.appearance)
					appParam:Toggle(false)
				else
					appParam:Toggle(true)
				end
			end
		end
	end
end

function AMM:CheckSavedAppearance(target)
	if target ~= nil and (target.type == "NPCPuppet" or target.type == "vehicle") then
		if AMM:CheckSavedAppearanceForEntity(target) then return end
	end

	if AMM:CheckSavedAppearanceForMountedVehicle() then return end

	local searchQuery = Game["TSQ_ALL;"]()
	searchQuery.maxDistance = 10
	searchQuery.includeSecondaryTargets = false
	searchQuery.ignoreInstigator = true
	local success, parts = Game.GetTargetingSystem():GetTargetParts(AMM.player, searchQuery)
	if success then
		for i, v in ipairs(parts) do
			local ent = nil
			local entity = v:GetComponent(v):GetEntity()

			if entity:IsNPC() then
				ent = AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), AMM:GetNPCName(entity),AMM:GetScanAppearance(entity), nil)
			elseif entity:IsVehicle() and entity:IsPlayerVehicle() then
				ent = AMM:NewTarget(entity, 'vehicle', AMM:GetScanID(entity), AMM:GetVehicleName(entity), AMM:GetScanAppearance(entity), nil)
			end

			if ent ~= nil then
				AMM:CheckCustomDefaults(ent)
				AMM:CheckSavedAppearanceForEntity(ent)
				AMM:CheckBlacklistAppearance(ent)
			end
		end
	end
end

function AMM:CheckSavedAppearanceForEntity(ent)
	local currentApp, savedApp = nil, nil

	if ent ~= nil then
		currentApp = ent.appearance
		for app in db:urows(f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", ent.id)) do
			savedApp = app
		end
	end

	if savedApp ~= nil and currentApp ~= savedApp then
		AMM:ChangeToSavedAppearance(ent, savedApp)
		return true
	end

	return false
end

function AMM:CheckSavedAppearanceForMountedVehicle()
	local ent, currentApp, savedApp = nil, nil, nil
	local qm = AMM.player:GetQuickSlotsManager()
	ent = qm:GetVehicleObject()
	if ent ~= nil then
		ent = AMM:NewTarget(ent, 'vehicle', AMM:GetScanID(ent), AMM:GetVehicleName(ent), AMM:GetScanAppearance(ent), nil)
		currentApp = ent.appearance
		for app in db:urows(f("SELECT app_name FROM saved_appearances WHERE entity_id = '%s'", ent.id)) do
			savedApp = app
		end
	end

	if savedApp ~= nil and savedApp ~= currentApp then
		self:ChangeScanAppearanceTo(ent, savedApp)
		return true
	end

	return false
end

function AMM:CheckBlacklistAppearance(ent)
	local currentApp, check = nil, nil

	if ent ~= nil then
		for count in db:urows(f("SELECT COUNT(1) FROM blacklist_appearances WHERE app_name = '%s'", ent.appearance)) do
			check = count
		end

		local newApp = nil
		if check ~= 0 then
			local query = f("SELECT app_name FROM appearances WHERE app_name NOT IN (SELECT app_name FROM blacklist_appearances WHERE entity_id = '%s') AND app_name != '%s' AND entity_id = '%s' ORDER BY RANDOM() LIMIT 1", ent.id, ent.appearance, ent.id)
			for app in db:urows(query) do
				newApp = app
			end

			if newApp then
				AMM:ChangeScanAppearanceTo(ent, newApp)
			end
		end
	end
end

function AMM:ChangeToSavedAppearance(ent, savedApp)
	local check = 0
	for count in db:urows(f("SELECT COUNT(1) FROM custom_appearances WHERE app_name = '%s'", savedApp)) do
		check = count
	end
	if check ~= 0 then
		custom = self:GetCustomAppearanceParams(ent, savedApp)
		self:ChangeScanCustomAppearanceTo(ent, custom)
	else
		local check = 0
		for count in db:urows(f("SELECT COUNT(1) FROM appearances WHERE app_name = '%s'", savedApp)) do
			check = count
		end
		if check ~= 0 then
			self:ChangeScanAppearanceTo(ent, savedApp)
		else
			-- This is a custom renamed appearance
			self:ClearSavedAppearance(ent)
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
	for count in db:urows(f("SELECT COUNT(1) FROM blacklist_appearances WHERE app_name = '%s'", t.appearance)) do
		check = count
	end

	if check ~= 0 then
		local popupInfo = {text = "You can't save a blacklisted appearance!"}
		Util:OpenPopup(popupInfo)
	else
		check = 0
		for count in db:urows(f("SELECT COUNT(1) FROM saved_appearances WHERE entity_id = '%s'", t.id)) do
			check = count
		end
		if check ~= 0 then
			db:execute(f("UPDATE saved_appearances SET app_name = '%s' WHERE entity_id = '%s'", t.appearance, t.id))
		else
			db:execute(f("INSERT INTO saved_appearances (entity_id, app_name) VALUES ('%s', '%s')", t.id, t.appearance))
		end
	end
end

function AMM:BlacklistAppearance(t)
	db:execute(f("INSERT INTO blacklist_appearances (entity_id, app_name) VALUES ('%s', '%s')", t.id, t.appearance))
end

function AMM:RemoveFromBlacklist(t)
	db:execute(f("DELETE FROM blacklist_appearances WHERE app_name = '%s'", t.appearance))
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

	return self:GetAppearanceOptionsWithID(scanID)
end

function AMM:GetAppearanceOptionsWithID(id)
	local options = {}

	if self.Swap.activeSwaps[id] ~= nil then
	 	id = self.Swap.activeSwaps[id].newID
	end

	if self.customAppPosition == "Top" then
		options = self:LoadCustomAppearances(options, id)
	end

	for app in db:urows(f("SELECT app_name FROM appearances WHERE entity_id = '%s' ORDER BY app_name ASC", id)) do
		table.insert(options, app)
	end

	if self.customAppPosition == "Bottom" then
		options = self:LoadCustomAppearances(options, id)
	end

	if next(options) ~= nil then
		return options -- array of appearances names
	end

	return nil
end

function AMM:LoadCustomAppearances(options, id)
	if #AMM.collabs ~= 0 then
		local collabsAppBase = '('
		for i, collab in ipairs(AMM.collabs) do
			collabsAppBase = collabsAppBase..f("'%s'", collab.appearance)
			if i ~= #AMM.collabs then collabsAppBase = collabsAppBase..", " end
			for app in db:urows(f("SELECT DISTINCT app_name FROM custom_appearances WHERE collab_tag = '%s' AND entity_id = '%s' ORDER BY app_base ASC", collab.tag, id)) do
				table.insert(options, app)
			end
		end
		collabsAppBase = collabsAppBase..")"

		for app in db:urows(f("SELECT DISTINCT app_name FROM custom_appearances WHERE collab_tag IS NULL AND app_base NOT IN %s AND entity_id = '%s' ORDER BY app_base ASC", collabsAppBase, id)) do
			table.insert(options, app)
		end
	else
		for app in db:urows(f("SELECT DISTINCT app_name FROM custom_appearances WHERE collab_tag IS NULL AND entity_id = '%s' ORDER BY app_base ASC", id)) do
			table.insert(options, app)
		end
	end

	return options
end

function AMM:GetScanAppearance(t)
	return tostring(t:GetCurrentAppearanceName()):match("%[ (%g+) -")
end

function AMM:CheckForReverseCustomAppearance(appearance, target)
	-- Check if custom app is active
	local activeApp = nil

	if next(self.activeCustomApps) ~= nil and self.activeCustomApps[target.hash] ~= nil then
		activeApp = self.activeCustomApps[target.hash]
	end

	local reverse = false
	if target ~= nil and activeApp ~= nil and activeApp ~= appearance and target.id ~= "0x903E76AF, 43" then
		for app_base in db:urows(f("SELECT app_base FROM custom_appearances WHERE app_name = '%s' AND app_base = '%s' AND entity_id = '%s'", activeApp, appearance, target.id)) do
			reverse = true
			self.activeCustomApps[target.hash] = 'reverse'
		end
	end

	if reverse then appearance = activeApp end

	return appearance, reverse
end

function AMM:GetCustomAppearanceParams(target, appearance, reverse)
	local collabTag

	if #AMM.collabs > 0 then
		for _, collab in ipairs(AMM.collabs) do
			local check = 0
			for count in db:urows(f("SELECT COUNT(1) FROM custom_appearances WHERE app_name = '%s' AND collab_tag = '%s'", appearance, collab.tag)) do
				check = count
			end

			if check ~= 0 then
				collabTag = collab.tag
				break
			end
		end
	end

	local custom = {}
	local query = f("SELECT * FROM custom_appearances WHERE app_name = '%s' AND entity_id = '%s' AND collab_tag IS '%s'", appearance, target.id, collabTag)
	query = query:gsub("'nil'", "NULL")
	for app in db:nrows(query) do
		app.app_toggle = not(intToBool(app.app_toggle))
		if reverse then app.app_toggle = not app.app_toggle end
		table.insert(custom, app)
	end
	return custom
end

function AMM:ChangeScanCustomAppearanceTo(t, customAppearance)
	self:ChangeScanAppearanceTo(t, customAppearance[1].app_base)
	self.setCustomApp = {t.handle, customAppearance}
	if self.activeCustomApps[t.hash] ~= 'reverse' then
		self.activeCustomApps[t.hash] = customAppearance[1].app_name
	else
		self.activeCustomApps[t.hash] = nil
	end
end

function AMM:ChangeScanAppearanceTo(t, newAppearance)
	if not(string.find(t.name, 'Mech')) then
		t.handle:PrefetchAppearanceChange(newAppearance)
		t.handle:ScheduleAppearanceChange(newAppearance)

		if self.activeCustomApps[t.hash] ~= nil and self.activeCustomApps[t.hash] ~= 'reverse' then
			self.activeCustomApps[t.hash] = nil
		end
	end
end

function AMM:ChangeAppearanceTo(entity, appearance)
	-- local appearance, reverse = AMM:CheckForReverseCustomAppearance(appearance, entity)
	local custom = AMM:GetCustomAppearanceParams(entity, appearance)

	if (not string.find(appearance, " No ")) and (not string.find(appearance, " With ")) and (not string.find(appearance, "Underwear")) and (not string.find(appearance, "Naked")) then
		AMM:ChangeScanAppearanceTo(entity, "Cycle")
	end

	Cron.After(0.1, function()
		if #custom > 0 then
			AMM:ChangeScanCustomAppearanceTo(entity, custom)
		else
			AMM:ChangeScanAppearanceTo(entity, appearance)
		end
	end)
end

function AMM:GetTarget()
	if AMM.player then
		target = Game.GetTargetingSystem():GetLookAtObject(AMM.player, true, false) or Game.GetTargetingSystem():GetLookAtObject(AMM.player, false, false)

		if target ~= nil then
			if target:IsNPC() or target:IsReplacer() then
				t = AMM:NewTarget(target, AMM:GetScanClass(target), AMM:GetScanID(target), AMM:GetNPCName(target),AMM:GetScanAppearance(target), AMM:GetAppearanceOptions(target))
			elseif target:IsVehicle() then
				t = AMM:NewTarget(target, 'vehicle', AMM:GetScanID(target), AMM:GetVehicleName(target),AMM:GetScanAppearance(target), AMM:GetAppearanceOptions(target))
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

function AMM:ToggleHostile(spawnHandle)
	Util:SetGodMode(spawnHandle, false)

	local handle = spawnHandle

	if handle.isPlayerCompanionCached then
		local AIC = handle:GetAIControllerComponent()
		local targetAttAgent = handle:GetAttitudeAgent()
		local reactionComp = handle.reactionComponent

		local aiRole = NewObject('handle:AIRole')
		aiRole:OnRoleSet(handle)

		handle.isPlayerCompanionCached = false
		handle.isPlayerCompanionCachedTimeStamp = 0

		Game['senseComponent::RequestMainPresetChange;GameObjectString'](handle, "Combat")
		AIC:GetCurrentRole():OnRoleCleared(handle)
		AIC:SetAIRole(aiRole)
		handle.movePolicies:Toggle(true)
		targetAttAgent:SetAttitudeGroup(CName.new("hostile"))
		reactionComp:SetReactionPreset(GetSingleton("gamedataTweakDBInterface"):GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive")))
		reactionComp:TriggerCombat(AMM.player)
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
		Util:SetGodMode(npcHandle, false)
	end

	waitTimer = 0.0
	self.currentSpawn = ''

	local targCompanion = npcHandle
	local AIC = targCompanion:GetAIControllerComponent()
	local targetAttAgent = targCompanion:GetAttitudeAgent()
	local currTime = targCompanion.isPlayerCompanionCachedTimeStamp + 11

	if targCompanion.isPlayerCompanionCached == false then
		local roleComp = NewObject('handle:AIFollowerRole')
		roleComp:SetFollowTarget(Game.GetPlayerSystem():GetLocalPlayerControlledGameObject())
		roleComp:OnRoleSet(targCompanion)
		roleComp.followerRef = Game.CreateEntityReference("#player", {})
		targetAttAgent:SetAttitudeGroup(CName.new("player"))
		roleComp.attitudeGroupName = CName.new("player")
		Game['senseComponent::RequestMainPresetChange;GameObjectString'](targCompanion, "Follower")
		targCompanion.isPlayerCompanionCached = true
		targCompanion.isPlayerCompanionCachedTimeStamp = currTime

		AIC:SetAIRole(roleComp)
		targCompanion.movePolicies:Toggle(true)

		AMM:UpdateFollowDistance()
	end
end

function AMM:UpdateFollowDistance()
	if self.spawnsCounter < 3 then
		self:SetFollowDistance(AMM.followDistance[2])
	elseif self.spawnsCounter == 3 then
		self:SetFollowDistance(AMM.followDistance[3])
	else
		self:SetFollowDistance(AMM.followDistance[4])
	end
end

function AMM:SetFollowDistance(followDistance)
 TweakDB:SetFlatNoUpdate(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.distance'), followDistance)

TweakDB:SetFlatNoUpdate(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.avoidObstacleWithinTolerance'), true)
TweakDB:SetFlatNoUpdate(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.ignoreCollisionAvoidance'), false)
TweakDB:SetFlatNoUpdate(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.ignoreSpotReservation'), false)

 TweakDB:SetFlatNoUpdate(TweakDBID.new('FollowerActions.FollowCloseMovePolicy.tolerance'), 0.0)

 TweakDB:SetFlatNoUpdate(TweakDBID.new('FollowerActions.FollowStayPolicy.distance'), followDistance)
 TweakDB:SetFlatNoUpdate(TweakDBID.new('FollowerActions.FollowGetOutOfWayMovePolicy.distance'), 0.0)

 TweakDB:Update(TweakDBID.new('FollowerActions.FollowCloseMovePolicy'))
 TweakDB:Update(TweakDBID.new('FollowerActions.FollowStayPolicy'))
 TweakDB:Update(TweakDBID.new('FollowerActions.FollowGetOutOfWayMovePolicy'))
end

function AMM:ChangeNPCEquipment(npcPath, equipmentPath)
	TweakDB:SetFlat(TweakDBID.new(npcPath..".primaryEquipment"), TweakDBID.new(equipmentPath))
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
		ImGui.SetNextWindowSize(400, 140)
		popupDelegate.message = "Are you sure you want to delete all your favorites?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() AMM:ClearAllFavorites() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	elseif name == "Appearances" then
		ImGui.SetNextWindowSize(400, 140)
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
		elseif action == "Blacklist" then
			AMM:BlacklistAppearance(target)
		elseif action == "Unblack" then
			AMM:RemoveFromBlacklist(target)
		elseif action == "SpawnNPC" then
			AMM:SpawnNPC(target)
			buttonPressed = true
		elseif action == "SpawnVehicle" then
			AMM:SpawnVehicle(target)
			buttonPressed = true
		elseif action == "SpawnProp" then
			AMM:SpawnProp(target)
			buttonPressed = true
		end
	end
end

function AMM:DrawEntitiesButtons(entities, categoryName, style)

	for i, entity in ipairs(entities) do
		name = entity[1]
		id = entity[2]
		path = entity[5]
		companion = entity[3]
		parameters = entity[4]
		template = entity[6]

		local newSpawn = AMM:NewSpawn(name, id, parameters, companion, path, template)
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
			if string.find(tostring(newSpawn.path), "Props") then action = "SpawnProp" end
			AMM:DrawButton(buttonLabel, -1 - favOffset, style.buttonHeight, action, newSpawn)
		end

		if categoryName == 'Favorites' then
			ImGui.SameLine()
			AMM:DrawArrowButton("down", newSpawn, i)
		end
	end
end

function AMM:DrawHotkeySelection()
	if AMM.selectedHotkeys[target.id] == nil then
		AMM.selectedHotkeys[target.id] = {'', '', ''}
	end

	for i, hotkey in ipairs(AMM.selectedHotkeys[target.id]) do
		local app = hotkey ~= '' and hotkey or "No Appearance Set"
		ImGui.InputText(f("Hotkey %i", i), app, 100, ImGuiInputTextFlags.ReadOnly)

		ImGui.SameLine()

		if ImGui.SmallButton("Set##"..i) then
			AMM.selectedHotkeys[target.id][i] = target.appearance
		end
	end
end

-- End of AMM Class

return AMM:new()
