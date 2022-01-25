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
	 AMM.currentVersion = "1.12.4"
	 AMM.CETVersion = tonumber(GetVersion():match("1.(%d+)."))
	 AMM.updateNotes = require('update_notes.lua')
	 AMM.credits = require("credits.lua")
	 AMM.updateLabel = "WHAT'S NEW"
	 AMM.userSettings = AMM:PrepareSettings()
	 AMM.player = nil
	 AMM.currentTarget = ''
	 AMM.entitiesForRespawn = ''
	 AMM.allowedNPCs = AMM:GetSaveables()
	 AMM.equipmentOptions = AMM:GetEquipmentOptions()
	 AMM.followDistanceOptions = AMM:GetFollowDistanceOptions()
	 AMM.companionAttackMultiplier = 0
	 AMM.originalVehicles = ''
	 AMM.displayInteractionPrompt = false
	 AMM.archives = nil
	 AMM.archivesInfo = {missing = false, optional = true}

	 -- Hotkeys Properties --
	 AMM.selectedHotkeys = {}

	 -- Custom Appearance Properties --
	 AMM.collabs = AMM:SetupCollabAppearances()
	 AMM.setCustomApp = ''
	 AMM.activeCustomApps = {}
	 AMM.customAppDefaults = AMM:GetCustomAppearanceDefaults()
	 AMM.customAppOptions = {"Top", "Bottom", "Off"}
	 AMM.customAppPosition = "Top"

	 -- Custom Entities Properties --
	 AMM.modders = {}
	 AMM.customNames = {}

	 -- Configs --
	 AMM.playerAttached = false
	 AMM.playerInMenu = true
	 AMM.playerInPhoto = false
	 AMM.playerInVehicle = false
	 AMM.settings = false
	 AMM.ignoreAllWarnings = false
	 AMM.shouldCheckSavedAppearance = true
	 AMM.importInProgress = false

	 -- Load Modules --
	 AMM.Spawn = require('Modules/spawn.lua')
	 AMM.Scan = require('Modules/scan.lua')
	 AMM.Swap = require('Modules/swap.lua')
	 AMM.Tools = require('Modules/tools.lua')
	 AMM.Props = require('Modules/props.lua')
	 AMM.Director = require('Modules/director.lua')
	 AMM.Light = require('Modules/light.lua')

	 AMM:ImportUserData()

	 registerForEvent("onInit", function()
		 waitTimer = 0.0
		 spamTimer = 0.0
		 respawnTimer = 0.0
		 delayTimer = 0.0
		 bbTested = false
		 buttonPressed = false
		 finishedUpdate = AMM:CheckDBVersion()

		 if AMM.Debug ~= '' then
			AMM.player = Game.GetPlayer()
		 end

		 AMM:SetupCustomProps()
		 AMM:SetupAMMCharacters()
		 AMM:SetupCustomEntities()
		 AMM:SetupVehicleData()

		 -- Update after importing user data
		 AMM.Spawn.categories = AMM.Spawn:GetCategories()
		 AMM.Scan:Initialize()
		 AMM.Tools:Initialize()
		 AMM.Swap:Initialize()
		 AMM.Props:Initialize()
		 AMM.Props:Update()

		 -- Check if user is in-game using WorldPosition --
		 -- Only way to set player attached if user reload all mods --
		 local player = Game.GetPlayer()
		 if player then
			 local playerPosition = player:GetWorldPosition()

			 if math.floor(playerPosition.z) ~= 0 then
				 AMM.player = player
				 AMM.playerAttached = true
				 AMM.playerInMenu = false

				 if next(AMM.Spawn.spawnedNPCs) ~= nil and AMM.userSettings.respawnOnLaunch then
				 	AMM:RespawnAll()
				 end
			 end
		 end

		 -- Setup GameSession --
		 GameSession.OnStart(function()
			 AMM.player = Game.GetPlayer()
			 AMM.playerAttached = true

			 AMM.Tools:CheckGodModeIsActive()

			 if next(AMM.Spawn.spawnedNPCs) ~= nil then
				if AMM.userSettings.respawnOnLaunch then
			 		AMM:RespawnAll()
				else
					AMM.Spawn.spawnedNPCs = {}
				end
			 end
			 
			 AMM.Tools:ToggleAnimatedHead(Tools.animatedHead)

			 AMM.Props.activeProps = {}
			 AMM.Props.playerLastPos = ''

			 AMM.Scan:ResetSavedDespawns()

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
			 Props:BackupPreset(Props.activePreset)
		 end)

		 -- Setup Observers and Overrides --
		 Observe('DamageSystem', 'ProcessRagdollHit', function(self, hitEvent)
			if AMM.companionAttackMultiplier ~= 0 then
				AMM:ProcessCompanionAttack(hitEvent)
			end
		 end)


		 Observe('SimpleSwitchControllerPS', 'OnToggleON', function(self)
			-- if self.switchAction == ESwitchAction.ToggleOn then
			-- 	self.switchAction = ESwitchAction.ToggleActivate
			-- else
			-- 	self.switchAction = ESwitchAction.ToggleOn
			-- end

			AMM.Props:ToggleAllActiveLights()
		 end)

		 Observe('FastTravelSystem', 'OnLoadingScreenFinished', function(self)
			if next(AMM.Spawn.spawnedNPCs) ~= nil then
				AMM:TeleportAll()
			end
		 end)

		 local vehicleMap = {}
		 Observe('VehicleObject', 'OnRequestComponents', function(self, ri)
			EntityRequestComponentsInterface.RequestComponent(ri, "AIComponent", "AIVehicleAgent", false)
		 end)
		 
		 Observe('VehicleObject', 'OnTakeControl', function(self, ri)
			local vehicleAI = EntityResolveComponentsInterface.GetComponent(ri, "AIComponent")
			vehicleMap[tostring(self:GetEntityID().hash)] = vehicleAI
		 end)

		local fastTravelScenario
      Observe("MenuScenario_HubMenu", "GetMenusState", function(self)
			if self:IsA("MenuScenario_HubMenu") then
				fastTravelScenario = self
			else
				fastTravelScenario = nil
			end
      end)

		Observe("gameuiWorldMapMenuGameController", "TryFastTravel", function(self)
			if self.selectedMappin and AMM.Scan.companionDriver then
				if fastTravelScenario and fastTravelScenario:IsA("MenuScenario_HubMenu") then
					if tostring(self.selectedMappin:GetMappinVariant()) == "gamedataMappinVariant : FastTravelVariant (51)" then
						AMM.Scan:SetVehicleDestination(self, vehicleMap)
						fastTravelScenario:GotoIdleState()
						fastTravelScenario:GotoIdleState()
					end
				end
			end
		end)

		 Observe('PhotoModePlayerEntityComponent', 'ListAllItems', function(self)
			 AMM.Tools.photoModePuppet = self.fakePuppet
		 end)

		 Observe("VehicleComponent", "OnVehicleStartedMountingEvent", function(self, event)
			 if AMM.Scan.drivers[AMM:GetScanID(event.character)] ~= nil then
				 local driver = AMM.Scan.drivers[AMM:GetScanID(event.character)]
				 if AMM.Scan.vehicle.hash ~= driver.vehicle.hash then
				 	AMM.Scan:SetDriverVehicleToFollow(driver)
				 else
					AMM.Scan.companionDriver = driver

					if AMM.TeleportMod ~= '' then
						AMM.TeleportMod.api.modBlocked = true
					end
					
					Cron.After(5, function()
						if not AMM.Scan.isDriving then
							AMM.player:SetWarningMessage("Select a Fast Travel point on your map to get going")
						end
					end)
				 end
		 	 elseif event.character:IsPlayer() then
				 AMM.playerInVehicle = not AMM.playerInVehicle

				 if AMM.Tools.TPPCameraBeforeVehicle and not AMM.playerInVehicle then
					Cron.After(1, function()
					  AMM.Tools:ToggleTPPCamera()
					  AMM.Tools.TPPCameraBeforeVehicle = false
					end)
				end

				 if AMM.Tools.TPPCamera then
					 AMM.Tools:ToggleTPPCamera()
					 AMM.Tools.TPPCameraBeforeVehicle = true
				 end

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

						 if AMM.TeleportMod ~= '' then
							AMM.TeleportMod.api.modBlocked = false
						end
					 end

					 AMM.Scan.carCam = false
					 AMM.Scan.vehicle = ''
				 elseif AMM.playerInVehicle and next(AMM.Spawn.spawnedNPCs) ~= nil and AMM.userSettings.spawnAsCompanion then
					 local target = Game.GetTargetingSystem():GetLookAtObject(AMM.player, false, false)
					 if target ~= nil and target:IsVehicle() then
						 AMM.Scan.vehicle = AMM:NewTarget(target, 'vehicle', AMM:GetScanID(target), AMM:GetVehicleName(target),AMM:GetScanAppearance(target), AMM:GetAppearanceOptions(target))
						 AMM.Scan:AutoAssignSeats()
					 end
				 end
			 end
		 end)

		Observe("EquipCycleInitEvents", "OnEnter", function(self, script)
			if AMM.Tools.TPPCamera then
				AMM.Tools:ToggleTPPCamera()
				AMM.Tools.TPPCameraBeforeVehicle = true
			end
		end)
		
		Observe("UnequippedEvents", "OnExit", function(self, script)
			if AMM.Tools.TPPCameraBeforeVehicle and not AMM.playerInVehicle then
				AMM.Tools.TPPCameraBeforeVehicle = false

				Cron.After(0.1, function()
					AMM.Tools:ToggleTPPCamera()
				end)
			end
		end)

		Observe("PlayerPuppet", "OnAction", function(self, action)
			local actionName = Game.NameToString(action:GetName(action))
			local actionType = action:GetType(action).value

			if actionName == 'TogglePhotoMode' then
	        	if actionType == 'BUTTON_RELEASED' then
					AMM.Tools:EnterPhotoMode()
				end
			elseif actionName == 'ExitPhotoMode' then
				if actionType == 'BUTTON_RELEASED' then
					AMM.Tools:ExitPhotoMode()
         	end
			elseif actionName == 'Choice1' then
				if actionType == 'BUTTON_RELEASED' then
					AMM:BusPromptAction()
				end
       	end
		 end)

		Observe("PlayerPuppet", "OnGameAttached", function(self)
			
			if GetVersion() == "v1.16.0" then
				self:RegisterInputListener(self, 'TogglePhotoMode')
				self:RegisterInputListener(self, 'ExitPhotoMode')
				self:RegisterInputListener(self, 'Choice1')
			end

			AMM.activeCustomApps = {}

			-- Disable God mode if previously active
			AMM.Tools.godModeToggle = false

			-- Disable Invisiblity if previously active
			AMM.Tools.playerVisibility = true
		end)

		Observe('PlayerPuppet', 'OnDetach', function(self)
			if not self:IsReplacer() then
				vehicleMap = {}
				collectgarbage()
			end
	  	end)
	 end)

	 registerForEvent("onShutdown", function()
		 AMM:ExportUserData()
		 AMM:RevertTweakDBChanges(false)
	 end)

	 -- TweakDB Changes
	 if AMM.CETVersion >= 18 and AMM.userSettings.photoModeEnhancements then
		registerForEvent('onTweak', function()

			-- Adjust Prevention System Total Entities Limit --
			TweakDB:SetFlat('PreventionSystem.setup.totalEntitiesLimit', 50)

			-- Adjust Photomode Defaults
			TweakDB:SetFlat('photo_mode.attributes.dof_aperture_default', AMM.Tools.defaultAperture)
			TweakDB:SetFlat('photo_mode.camera.default_fov', AMM.Tools.defaultFOV)
			TweakDB:SetFlat('photo_mode.camera.min_fov', 1.0)
			TweakDB:SetFlat('photo_mode.camera.max_roll', 180)
			TweakDB:SetFlat('photo_mode.camera.min_roll', -180)
			TweakDB:SetFlat('photo_mode.camera.max_dist', 100)
			TweakDB:SetFlat('photo_mode.character.collision_radius', 0)
			TweakDB:SetFlat('photo_mode.character.max_position_adjust', 100)
			-- TweakDB:SetFlat('photo_mode.general.force_lod0_characters_dist', 0)
			-- TweakDB:SetFlat('photo_mode.general.force_lod0_vehicles_dist', 0)
			TweakDB:SetFlat('photo_mode.general.onlyFPPPhotoModeInPlayerStates', {})
			TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.followingSpeedFactorOverride', 1200.0)

			for pose in db:urows("SELECT pose_name FROM photomode_poses") do
				TweakDB:SetFlat('PhotoModePoses.'..pose..'.disableLookAtForGarmentTags', {})
				TweakDB:SetFlat('PhotoModePoses.'..pose..'.filterOutForGarmentTags', {})
				TweakDB:SetFlat('PhotoModePoses.'..pose..'.poseStateConfig', 'POSE_STATE_GROUND_AND_AIR')
				TweakDB:SetFlat('PhotoModePoses.'..pose..'.lookAtPreset', 'LookatPreset.PhotoMode_LookAtCamera')
			end
		end)
	 end

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
		 AMM.Spawn:SpawnFavorite()
	 end)

	 registerHotkey("amm_spawn_target", "Spawn Target", function()
		local target = AMM:GetTarget()
		if target ~= nil and target.handle:IsNPC() then
			local spawnableID = AMM:IsSpawnable(target)

			if spawnableID ~= nil then

				local spawn = nil
				for ent in db:nrows(f("SELECT * FROM entities WHERE entity_id = '%s'", spawnableID)) do
					spawn = AMM.Spawn:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path)
				end

				if spawn ~= nil then
					target.handle:Dispose()
					AMM.Spawn:SpawnNPC(spawn)
				end
			end
		end
	 end)

	 registerHotkey("amm_despawn_target", "Despawn Target", function()
		local target = AMM:GetTarget()
		if target ~= nil then
			local spawnedNPC = nil
			for _, spawn in pairs(AMM.Spawn.spawnedNPCs) do
				if target.id == spawn.id then spawnedNPC = spawn break end
			end

			if spawnedNPC then
				AMM.Spawn:DespawnNPC(spawnedNPC)
			else
				Util:Despawn(target.handle)
			end
		end
	 end)

	 registerHotkey("amm_respawn_all", "Respawn All", function()
		buttonPressed = true
	 	AMM:RespawnAll()
	 end)

	 registerHotkey("amm_toggle_vehicle_camera", "Toggle Vehicle Camera", function()
		local qm = AMM.player:GetQuickSlotsManager()
		mountedVehicle = qm:GetVehicleObject()
		if AMM.Scan.companionDriver ~= '' and mountedVehicle then
			AMM.Scan:ToggleVehicleCamera()
		end
	 end)

	 registerHotkey("amm_toggle_station", "Toggle Radio", function()
		local qm = AMM.player:GetQuickSlotsManager()
		mountedVehicle = qm:GetVehicleObject()
		if mountedVehicle then
			mountedVehicle:ToggleRadioReceiver(not mountedVehicle:IsRadioReceiverActive())
		end
	 end)

	 registerHotkey("amm_next_station", "Next Radio Station", function()
		local qm = AMM.player:GetQuickSlotsManager()
		mountedVehicle = qm:GetVehicleObject()
		if mountedVehicle and mountedVehicle:IsRadioReceiverActive() then
			mountedVehicle:NextRadioReceiverStation()
		end
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

	 registerHotkey("amm_last_expression", "Last Expression Used", function()
		local target = AMM:GetTarget()
		if Tools.lockTarget and Tools.currentNPC ~= '' and Tools.currentNPC.handle
		and Tools.currentNPC.type ~= 'entEntity' and Tools.currentNPC.type ~= 'gameObject' then
			target = Tools.currentNPC
		end

		if Tools.lookAtTarget then
            local ent = Game.FindEntityByID(Tools.lookAtTarget.handle:GetEntityID())
            if not ent then Tools.lookAtTarget = nil end
        end

		local face = Tools.selectedFace
		if Tools.selectedFace.name == 'Select Expression' then
			face = {name = "Joy", idle = 5, category = 3}
		end

		Tools:ActivateFacialExpression(target, face)
	 end)

	 registerHotkey("amm_npc_talk", "NPC Talk", function()
		local target = AMM:GetTarget()
 		if target ~= nil and target.handle:IsNPC() then
			Util:NPCTalk(target.handle)
		end
	 end)

	 registerHotkey("amm_npc_hold", "NPC Hold Position", function()
		local target = AMM:GetTarget()
 		if target ~= nil and target.handle:IsNPC() then
			Util:HoldPosition(target.handle)
		end
	 end)

	 registerHotkey("amm_npc_all_hold", "All Hold Position", function()
		if next(AMM.Spawn.spawnedNPCs) ~= nil then
			for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
				Util:HoldPosition(ent.handle, 10)
			end
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

	 registerHotkey("amm_toggle_tpp", "Toggle TPP Camera", function()
		AMM.Tools:ToggleTPPCamera()
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

		 if AMM.playerAttached and (not(AMM.playerInMenu) or AMM.playerInPhoto) then
				if not AMM.archivesInfo.missing and finishedUpdate and AMM.player ~= nil then
					-- Check Custom Defaults --
					local target = AMM:GetTarget()
					AMM:CheckCustomDefaults(target)
			 		-- Load Saved Appearance --
			 		if not drawWindow and AMM.shouldCheckSavedAppearance then
						local count = 0
						for x in db:urows("SELECT COUNT(1) FROM saved_appearances UNION ALL SELECT COUNT(1) FROM blacklist_appearances") do
							count = count + x
						end

						if count ~= 0 then
			 				AMM:CheckSavedAppearance(target)
							AMM.shouldCheckSavedAppearance = false
						end
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
						AMM.Scan:SenseSavedDespawns()
					end

					-- Travel Animation Done Check --
					if AMM.TeleportMod ~= '' and AMM.TeleportMod.api.done then
						if next(AMM.Spawn.spawnedNPCs) ~= nil then
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
							if next(AMM.Spawn.spawnedNPCs) ~= nil then
					      	AMM:TeleportAll()
					    	end
						end
					end

					-- Check if Locked Target is gone --
					if Tools.lockTarget then
						if Tools.currentNPC.handle and Tools.currentNPC.handle ~= '' then
							local ent = Game.FindEntityByID(Tools.currentNPC.handle:GetEntityID())
							if not ent then Tools:ClearTarget() end
						else
							Tools:ClearTarget()
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

	local archives = AMM:CheckMissingArchives()

	if ImGui.Begin("Appearance Menu Mod", shouldResize) then

		if archives.missing and not archives.optional then
			AMM:DrawArchives()
		else
			if (not(finishedUpdate) or AMM.playerAttached == false) then
				
				if archives.missing then
					AMM:DrawArchives()
				else
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
					AMM.Spawn:Draw(AMM, style)

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

						-- Util Popup Helper --
						Util:SetupPopup()

						ImGui.Spacing()

						local settingChanged = false
						AMM.userSettings.spawnAsCompanion, clicked = ImGui.Checkbox("Spawn As Companion", AMM.userSettings.spawnAsCompanion)
						if clicked then settingChanged = true end

						AMM.userSettings.isCompanionInvulnerable, clicked = ImGui.Checkbox("Invulnerable Companion", AMM.userSettings.isCompanionInvulnerable)
						if clicked then 
							settingChanged = true 
							AMM:RespawnAll()
						end

						AMM.userSettings.respawnOnLaunch, clicked = ImGui.Checkbox("Respawn On Launch", AMM.userSettings.respawnOnLaunch)
						if clicked then settingChanged = true end

						if ImGui.IsItemHovered() then
							ImGui.SetTooltip("This setting will enable/disable respawn previously saved NPCs on game load. AMM automatically saves your spawned NPCs when you exit the game.")
						end

						if AMM.CETVersion >= 18 then
							AMM.userSettings.photoModeEnhancements, clicked = ImGui.Checkbox("Photo Mode Enhancements", AMM.userSettings.photoModeEnhancements)
							if clicked then settingChanged = true end
						end

						AMM.userSettings.godModeOnLaunch, clicked = ImGui.Checkbox("God Mode On Launch", AMM.userSettings.godModeOnLaunch)
						if clicked then settingChanged = true end

						AMM.userSettings.openWithOverlay, clicked = ImGui.Checkbox("Open With CET Overlay", AMM.userSettings.openWithOverlay)
						if clicked then settingChanged = true end

						AMM.userSettings.autoResizing, clicked = ImGui.Checkbox("Auto-Resizing Window", AMM.userSettings.autoResizing)
						if clicked then settingChanged = true end

						AMM.userSettings.scanningReticle, clicked = ImGui.Checkbox("Scanning Reticle", AMM.userSettings.scanningReticle)
						if clicked then settingChanged = true end

						AMM.userSettings.experimental, expClicked = ImGui.Checkbox("Experimental/Fun stuff", AMM.userSettings.experimental)

						if AMM.userSettings.experimental then
							AMM.userSettings.freezeInPhoto, clicked = ImGui.Checkbox("Enable Freeze Target In Photo Mode", AMM.userSettings.freezeInPhoto)
							if clicked then settingChanged = true end

							if ImGui.IsItemHovered() then
								ImGui.BeginTooltip()
								ImGui.PushTextWrapPos(500)
								ImGui.TextWrapped("This setting is meant to help freeze animations from mods that add custom animation to Photo Mode poses or when you unpause using IGCS.")
								ImGui.PopTextWrapPos()
								ImGui.EndTooltip()
						end
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

						AMM.UI:TextColored("Companion Damage:")

						ImGui.PushItemWidth(200)
						AMM.companionAttackMultiplier = ImGui.InputFloat("x Damage", AMM.companionAttackMultiplier, 0.5, 50, "%.1f")
						ImGui.PopItemWidth()

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

						if settingChanged then AMM:UpdateSettings() end

						if expClicked then
							AMM:UpdateSettings()
							AMM.Spawn.categories = AMM.Spawn:GetCategories()

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
						if ImGui.Button("Clear Favorites", style.halfButtonWidth, style.buttonHeight) then
							popupDelegate = AMM:OpenPopup("Favorites")
						end

						if ImGui.Button("Clear All Saved Appearances", style.buttonWidth, style.buttonHeight) then
							popupDelegate = AMM:OpenPopup("Appearances")
						end

						if ImGui.Button("Clear All Blacklisted Appearances", style.buttonWidth, style.buttonHeight) then
							popupDelegate = AMM:OpenPopup("Blacklist")
						end

						if AMM.userSettings.experimental then
							if ImGui.Button("Clear All Saved Despawns", style.buttonWidth, style.buttonHeight) then
								popupDelegate = AMM:OpenPopup("Saved Despawns")
							end
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

						ImGui.SameLine()
						if ImGui.InvisibleButton("Machine Gun", 20, 30) then
							local popupInfo = {text = "You found it! Heavy Machine Gun was added to Equipments."}
							Util:OpenPopup(popupInfo)
							AMM.equipmentOptions = AMM:GetEquipmentOptions(true)
						end
				
						if ImGui.IsItemHovered() then
							ImGui.SetTooltip("Clicking here does nothing!")
						end

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
	end
	ImGui.End()

	if AMM.Light.isEditing then
		AMM.Light:Draw(AMM)
	 end
  
	 if AMM.Tools.movementWindow.isEditing and (target ~= nil or (AMM.Tools.currentNPC and AMM.Tools.currentNPC ~= '')) then
		AMM.Tools:DrawMovementWindow()
	 end
end

-- AMM Objects
function AMM:NewTarget(handle, targetType, id, name, app, options)
	local obj = {}
	obj.handle = handle
	obj.id = id
	obj.hash = tostring(handle:GetEntityID().hash)
	obj.name = name
	obj.uniqueName = function() return obj.name.."##"..obj.id end
	obj.entityID = handle:GetEntityID()
	obj.appearance = app
	obj.type = targetType
	obj.options = options or nil

	local components = self.Props:CheckForValidComponents(handle)
	if components then
		obj.defaultScale = {
			x = components[1].visualScale.x * 100,
			y = components[1].visualScale.x * 100,
			z = components[1].visualScale.x * 100,
		 }
		obj.scale = {
			x = components[1].visualScale.x * 100,
			y = components[1].visualScale.y * 100,
			z = components[1].visualScale.z * 100,
		 }
	end

	-- Check if target is Custom Entity
	if AMM.customNames[id] then
		obj.name = AMM.customNames[id]
	end

	-- Check if target is V
	if obj.name == "V" or Util:CheckVByID(obj.id) then
		obj.name = "V"
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

	-- Check if object is spawnedProp
	if next(AMM.Props.spawnedProps) ~= nil then
		for _, prop in pairs(AMM.Props.spawnedProps) do
			if tostring(prop.entityID.hash) == tostring(obj.entityID.hash) then
				obj = prop
				break
			end
		end
	end

	function obj:Despawn()
		if obj.type == "NPCPuppet" then
			AMM.Spawn:DespawnNPC(obj)
		elseif obj.type == "Prop" then
			AMM.Props:DespawnProp(obj)
		else
			Util:Despawn(obj.handle)
		end
	end

	return obj
end

-- End Objects --

-- AMM Methods --
function AMM:CheckMissingArchives()

	if AMM.CETVersion < 18 and AMM.playerAttached and not(bbTested) then
		bbTested = true
		local spawnTransform = AMM.player:GetWorldTransform()
		local entityID = exEntitySpawner.Spawn([[base\amm_props\entity\bbpod_a.ent]], spawnTransform, '')

		Cron.Every(0.1, function(timer)
			local entity = Game.FindEntityByID(entityID)
			if entity then
				exEntitySpawner.Despawn(entity)
				Cron.Halt(timer)
			end
		end)
	end

	if AMM.CETVersion >= 18 then
		if AMM.archives == nil then
			AMM.archives = {
				{name = "basegame_AMM_Props", desc = "Adds props, characters and vehicles. AMM won't launch without this.", active = true, optional = false},
				{name = "basegame_AMM_requirement", desc = "Adds and fixes appearances for many characters.\nYou should install this.", active = true, optional = true},
				{name = "basegame_johnny_companion", desc = "Adds Johnny Silverhand as a spawnable character.", active = true, optional = false},
				{name = "basegame_AMM_KerryPP", desc = "Adds a new naked appearance.", active = true, optional = true},
				{name = "basegame_AMM_BenjaminStonePP", desc = "Adds a new naked appearance.", active = true, optional = true},
				{name = "basegame_AMM_RiverPP", desc = "Adds a new naked appearance.", active = true, optional = true},
				{name = "basegame_AMM_YorinobuPP", desc = "Adds a new naked appearance.", active = true, optional = true},
				{name = "basegame_AMM_LizzyIncognito", desc = "Adds a new appearance.", active = true, optional = true},
				{name = "basegame_AMM_MeredithXtra", desc = "Adds a new appearance.", active = true, optional = true},
				{name = "basegame_AMM_Delamain_Fix", desc = "Adds full body to Delamain", active = true, optional = true},
				{name = "basegame_texture_Cheri_SkinColorFix", desc = "Fixes Cheri's skin color.", active = true, optional = true},
				{name = "basegame_texture_HanakoNoMakeup", desc = "Allows AMM to remove Hanako's makeup when using Custom Appearance.", active = true, optional = true},
				{name = "basegame_AMM_JudyBodyRevamp", desc = "Replaces Judy's body with a new improved one.", active = true, optional = true},
				{name = "basegame_AMM_PanamBodyRevamp", desc = "Replaces Panam's body with a new improved one.", active = true, optional = true},
				{name = "_1_Ves_HanakoFixedBodyNaked", desc = "Replaces Hanako's body with a new improved one.", active = true, optional = true},
				{name = "PinkyDude_ANIM_FacialExpressions_FemaleV", desc = "Enables facial expressions tools on Female V", active = true, optional = true},
				{name = "PinkyDude_ANIM_FacialExpressions_MaleV", desc = "Enables facial expressions tools on Male V", active = true, optional = true},
			}

			for _, archive in ipairs(AMM.archives) do
				if not ModArchiveExists(archive.name..".archive") then
					archive.active = false
					AMM.archivesInfo.missing = true

					if not archive.optional then AMM.archivesInfo.optional = false end
				end
			end
		end
	end

	if AMM.archivesInfo.missing then
		local ignoreArchives = false
		for v in db:urows("SELECT ignore_archives FROM metadata") do
			ignoreArchives = intToBool(v)
		end

		if ignoreArchives and AMM.archivesInfo.optional then
			AMM.archivesInfo = {missing = false, optional = true}
		end
	end

	return AMM.archivesInfo
end

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
	AMM:UpdateOldFavorites()

	if self.currentVersion == "1.11.1b" then
		AMM:ResetAllPropsScale()
		AMM.Props:Update()
	elseif self.currentVersion == "1.11.4b" then
		if AMM.Tools.godModeToggle then
			AMM.Tools:ToggleGodMode()
		end
	end

	db:execute(f("UPDATE metadata SET current_version = '%s'", self.currentVersion))
end

function AMM:ImportUserData()
	AMM.importInProgress = true

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
					self.Spawn.spawnedNPCs = self:PrepareImportSpawnedData(userData['spawnedNPCs'])
				end
				if userData['savedSwaps'] ~= nil then
					self.Swap.savedSwaps = userData['savedSwaps']
				end
				if userData['followDistance'] ~= nil then
					self.followDistance = userData['followDistance']
				end
				if userData['activePreset'] ~= nil then
					self.Props.activePreset = userData['activePreset']
					spdlog.info('During import '..tostring(self.Props.activePreset))
				end
				if userData['homeTags'] ~= nil then
					self.Props.homeTags = userData['homeTags']
				end

				self.customAppPosition = userData['customAppPosition'] or "Top"
				self.selectedTheme = userData['selectedTheme'] or "Default"
				self.selectedHotkeys = userData['selectedHotkeys'] or {}
				self.Tools.selectedTPPCamera = userData['selectedTPPCamera'] or 1
				self.Tools.defaultFOV = userData['defaultFOV'] or 60
				self.Tools.defaultAperture = userData['defaultAperture'] or 4
				self.companionAttackMultiplier = userData['companionAttackMultiplier'] or 0

				if userData['settings'] ~= nil then
					for _, obj in ipairs(userData['settings']) do
						db:execute(f("UPDATE settings SET setting_name = '%s', setting_value = %i WHERE setting_name = '%s'", obj.setting_name, boolToInt(obj.setting_value),  obj.setting_name))
					end

					AMM.userSettings = AMM:PrepareSettings()
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
				if userData['favorites_props'] ~= nil then
					for _, obj in ipairs(userData['favorites_props']) do
						local command = f("INSERT INTO favorites_props (position, entity_id, entity_name, parameters) VALUES (%i, '%s', '%s', '%s')", obj.position, obj.entity_id, obj.entity_name, obj.parameters)
						command = command:gsub("'nil'", "NULL")
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
				if userData['saved_despawns'] ~= nil then
					for _, obj in ipairs(userData['saved_despawns']) do
						db:execute(f("INSERT INTO saved_despawns (entity_hash, position) VALUES ('%s', '%s')", obj.entity_hash, obj.position))
					end
				end
				if userData['saved_props'] ~= nil then
					local newPreset = {file_name = "My Preset.json", name = "My Preset", props = userData['saved_props']}
					AMM.Props:SavePreset(newPreset)
					AMM.Props.activePreset = newPreset.file_name
					userData['saved_props'] = nil
				end
			end
		end
	end

	AMM.importInProgress = false
end

function AMM:ExportUserData()
	if not AMM.importInProgress then
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
		userData['favorites_props'] = {}
		for r in db:nrows("SELECT * FROM favorites_props") do
			table.insert(userData['favorites_props'], {position = r.position, entity_id = r.entity_id, entity_name = r.entity_name, parameters = r.parameters})
		end
		userData['saved_appearances'] = {}
		for r in db:nrows("SELECT * FROM saved_appearances") do
			table.insert(userData['saved_appearances'], {entity_id = r.entity_id, app_name = r.app_name})
		end
		userData['blacklist_appearances'] = {}
		for r in db:nrows("SELECT * FROM blacklist_appearances") do
			table.insert(userData['blacklist_appearances'], {entity_id = r.entity_id, app_name = r.app_name})
		end
		userData['saved_despawns'] = {}
		for r in db:nrows("SELECT * FROM saved_despawns") do
			table.insert(userData['saved_despawns'], {entity_hash = r.entity_hash, position = r.position})
		end

		if self.userSettings.respawnOnLaunch then
			userData['spawnedNPCs'] = self:PrepareExportSpawnedData()
		end
		
		userData['selectedTheme'] = self.selectedTheme
		userData['savedSwaps'] = self.Swap:GetSavedSwaps()
		userData['favoriteLocations'] = self.Tools:GetFavoriteLocations()
		userData['followDistance'] = self.followDistance
		userData['customAppPosition'] = self.customAppPosition
		userData['selectedHotkeys'] = self.selectedHotkeys
		userData['activePreset'] = self.Props.activePreset.file_name or ''
		userData['homeTags'] = Util:GetTableKeys(self.Props.homes)
		userData['selectedTPPCamera'] = self.Tools.selectedTPPCamera
		userData['defaultFOV'] = self.Tools.defaultFOV
		userData['defaultAperture'] = self.Tools.defaultAperture
		userData['companionDamageMultiplier'] = self.companionAttackMultiplier

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
			spawn = AMM.Spawn:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path)
			table.insert(savedEntities, spawn)
		end
	end

	return savedEntities
end

function AMM:PrepareExportSpawnedData()
	local spawnedEntities = {}

	for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
		table.insert(spawnedEntities, ent.id)
	end

	return spawnedEntities
end

function AMM:IsApproved(modder, path)
	local path = path:match("%\\(%a+)%\\")

	if path then
		local id = AMM:GetScanID(modder..path)

		local possibleIDs = {
			"0xB12C810A, 20", "0x83384354, 12", "0x86B91A0E, 11"
		}

		for _, possibleID in ipairs(possibleIDs) do
			if id == possibleID then return 1 end
		end
	end

	return 0
end

function AMM:GetSaveables()
	local defaults = {
		'0xB1B50FFA, 14', '0xC67F0E01, 15', '0x73C44EBA, 15', '0xA1C78C30, 16', '0x7F65F7F7, 16',
		'0x7B2CB67C, 17', '0x3024F03E, 15', '0x3B6EF8F9, 13', '0x413F60A6, 15', '0x62B8D0FA, 15',
		'0x3143911D, 15', '0xF0F54969, 24', '0x0044E64C, 20', '0xF43B2B48, 18', '0xC111FBAC, 16',
		'0x8DD8F2E0, 35', '0x4106744C, 35', '0xB98FDBB8, 14', '0x6B0544AD, 26', '0x215A57FC, 17',
		'0x903E76AF, 43', '0x451222BE, 24'
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
		{name = "Neutral", idle = 2, category = 2},
        {name = "Joy", idle = 5, category = 3},
        {name = "Smile", idle = 6, category = 3},
        {name = "Sad", idle = 3, category = 3},
        {name = "Surprise", idle = 8, category = 3},
        {name = "Aggressive", idle = 2, category = 3},
        {name = "Anger", idle = 1, category = 3},
        {name = "Interested", idle = 3, category = 1},
        {name = "Disinterested", idle = 6, category = 1},        
        {name = "Disappointed", idle = 4, category = 3},
        {name = "Disgust", idle = 7, category = 3},
        {name = "Exertion", idle = 1, category = 1},
        {name = "Nervous", idle = 10, category = 3},
        {name = "Fear", idle = 11, category = 3},
        {name = "Terrified", idle = 9, category = 3},
        {name = "Pain", idle = 2, category = 1},
        {name = "Sleepy", idle = 5, category = 1},
        {name = "Unconscious", idle = 4, category = 1},
        {name = "Dead", idle = 1, category = 2},
	}

	return personalities
end

function AMM:GetEquipmentOptions(HMG)
	local equipments = {
		{name = 'Fists', path = 'Character.wraiths_strongarms_hmelee3_fists_mb_elite_inline0'},
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

	if HMG then
		table.insert(equipments, {name = 'Machine Gun', path = 'Character.militech_enforcer3_gunner3_HMG_mb_elite_inline2'})
	end
	
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
	local customs = {}

	if #AMM.collabs > 0 then
		for _, collab in ipairs(AMM.collabs) do
			if collab.disabledByDefault then
				for _, default in ipairs(collab.disabledByDefault) do
					for _, app in ipairs(default.allowedApps) do
						if not customs[default.component] then
							customs[default.component] = {}
						end
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

function AMM:ResetAllPropsScale()
	db:execute("UPDATE saved_props SET scale = NULL")
end

function AMM:UpdateOldFavorites()
	db:execute("UPDATE favorites SET parameters = NULL WHERE parameters = 'None' OR parameters = 'TPP_Body' OR parameters = 'nil';")
	db:execute("UPDATE favorites SET entity_id = '0xCD70BCE4, 20' WHERE entity_id = '0xC111FBAC, 16';")
	db:execute("UPDATE favorites_swap SET entity_id = '0xCD70BCE4, 20' WHERE entity_id = '0xC111FBAC, 16';")
	db:execute("UPDATE favorites SET entity_id = '0x5E611B16, 24' WHERE entity_id = '0x903E76AF, 43';")
	db:execute("DELETE FROM favorites WHERE parameters LIKE '%table%'")

	-- Move Props from favorites to favorites_props
	local index = 0
	for prop in db:nrows("SELECT * FROM favorites WHERE parameters = 'Prop'") do
		index = index + 1
		local tables = '(position, entity_id, entity_name, parameters)'
		local values = f('(%i, "%s", "%s", "%s")', index, prop.entity_id, prop.entity_name, prop.parameters)
		db:execute(f('INSERT INTO favorites_props %s VALUES %s', tables, values))
		db:execute(f('DELETE FROM favorites WHERE position = %i', prop.position))
	end

	local count = 0
	for x in db:urows('SELECT COUNT(1) FROM favorites') do
		count = x
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = 'favorites'", count))

	for x in db:urows('SELECT COUNT(1) FROM favorites_props') do
		count = x
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = 'favorites_props'", count))
end

function AMM:SetupAMMCharacters()
	local ents = {
		{og = "Character.TPP_Player_Cutscene_Male", tdbid = "AMM_Character.Player_Male", path = "player_ma_tpp"},
		{og = "Character.TPP_Player_Cutscene_Female", tdbid = "AMM_Character.Player_Female", path = "player_wa_tpp"},
		{og = "Character.TPP_Player_Cutscene_Male", tdbid = "AMM_Character.TPP_Player_Male", path = "player_ma_tpp_walking"},
		{og = "Character.TPP_Player_Cutscene_Female", tdbid = "AMM_Character.TPP_Player_Female", path = "player_wa_tpp_walking"},
		{og = "Character.Takemura", tdbid = "AMM_Character.Silverhand", path = "silverhand"},
		{og = "Character.Hanako", tdbid = "AMM_Character.Hanako", path = "hanako"},
		{og = "Character.generic_netrunner_netrunner_chao_wa_rare_ow_city_scene", tdbid = "AMM_Character.Songbird", path = "songbird"},
		{og = "Character.q116_v_female", tdbid = "AMM_Character.E3_V_Female", path = "e3_v_female"},
		{og = "Character.q116_v_male", tdbid = "AMM_Character.E3_V_Male", path = "e3_v_male"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Sit", path = "nibbles_sit"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Test", path = "nibbles_test"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Get_Pet", path = "nibbles_get_pet"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Jump_Down", path = "nibbles_jump_down"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Self_Clean", path = "nibbles_self_clean"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Sleeping", path = "nibbles_sleep"},
		{og = "Character.q105_jigjig_hologram", tdbid = "AMM_Character.Wa_Holograms_Dance", path = "wa_holograms_redlight_dance"},
		{og = "Vehicle.av_rayfield_excalibur", tdbid = "AMM_Vehicle.Docworks_Excalibus", path = "doc_excalibus"},
	}

	for _, ent in ipairs(ents) do
		local tdbid, path = ent.tdbid, ent.path
    	TweakDB:CloneRecord(tdbid, ent.og)

		if string.find(tdbid, "Vehicle") then
			TweakDB:SetFlat(tdbid..".entityTemplatePath", "base\\amm_vehicles\\entity\\"..path..".ent")
		else
    		TweakDB:SetFlat(tdbid..".entityTemplatePath", "base\\amm_characters\\entity\\"..path..".ent")
		end
  	end

	-- Setup TweakDB Records
	TweakDB:SetFlat("AMM_Character.TPP_Player_Female.fullDisplayName", TweakDB:GetFlat("Character.TPP_Player.displayName"))
	TweakDB:SetFlat("AMM_Character.TPP_Player_Male.fullDisplayName", TweakDB:GetFlat("Character.TPP_Player.displayName"))

	TweakDB:SetFlats("AMM_Character.Silverhand",{
		voiceTag = TweakDB:GetFlat("Character.Silverhand.voiceTag"),
		displayName = TweakDB:GetFlat("Character.Silverhand.displayName"),
		alternativeDisplayName = TweakDB:GetFlat("Character.Silverhand.alternativeDisplayName"),
		alternativeFullDisplayName = TweakDB:GetFlat("Character.Silverhand.alternativeFullDisplayName"),
		fullDisplayName = TweakDB:GetFlat("Character.Silverhand.fullDisplayName"),
		affiliation =  TweakDB:GetFlat("Character.Silverhand.affiliation"),
		statPools =  TweakDB:GetFlat("Character.Silverhand.statPools"),
	})

	TweakDB:SetFlats("AMM_Character.Hanako",{
		primaryEquipment = TweakDB:GetFlat('Character.Judy.primaryEquipment'),
		secondaryEquipment = TweakDB:GetFlat('Character.Judy.secondaryEquipment'),
		abilities = TweakDB:GetFlat('Character.Judy.abilities')
	})

	TweakDB:SetFlats("AMM_Character.E3_V_Female",{
		primaryEquipment = TweakDB:GetFlat('Character.afterlife_rare_fmelee3_mantis_wa_elite.primaryEquipment'),
		secondaryEquipment = TweakDB:GetFlat('Character.arr_ncpd_inspector_ranged1_lexington_ma.primaryEquipment'),
		abilities = TweakDB:GetFlat('Character.afterlife_rare_fmelee3_mantis_wa_elite.abilities')
	})

	TweakDB:SetFlats("AMM_Character.E3_V_Male",{
		primaryEquipment = TweakDB:GetFlat('Character.afterlife_rare_fmelee3_mantis_ma_elite.primaryEquipment'),
		secondaryEquipment = TweakDB:GetFlat('Character.arr_ncpd_inspector_ranged1_lexington_ma.primaryEquipment'),
		abilities = TweakDB:GetFlat('Character.Takemura.abilities')
	})

	TweakDB:SetFlats("AMM_Character.Songbird",{
		fullDisplayName = TweakDB:GetFlat("Character.q110_vdb_elder_1.fullDisplayName"),
		displayName = TweakDB:GetFlat("Character.jpn_tygerclaw_gangster3_netrunner_nue_wa_rare.displayName"),
		reactionPreset = TweakDB:GetFlat("Character.Judy.reactionPreset"),
		baseAttitudeGroup = "judy",
		abilities = TweakDB:GetFlat("Character.jpn_tygerclaw_gangster3_netrunner_nue_wa_rare.abilities"),
		statModifierGroups = TweakDB:GetFlat("Character.jpn_tygerclaw_gangster3_netrunner_nue_wa_rare.statModifierGroups"),
	})

	TweakDB:SetFlats("Character.lizzies_bouncer",{
		primaryEquipment = TweakDB:GetFlat('Character.the_mox_1_melee2_baseball_wa.primaryEquipment'),
		secondaryEquipment = TweakDB:GetFlat('Character.the_mox_1_melee2_baseball_wa.secondaryEquipment'),
		abilities = TweakDB:GetFlat("Character.the_mox_1_melee2_baseball_wa.abilities"),
		statModifierGroups = TweakDB:GetFlat("Character.the_mox_1_melee2_baseball_wa.statModifierGroups"),
	})

	AMM.customNames['0x69E1384D, 22'] = 'Songbird'
	AMM.customNames['0xE09AAEB8, 26'] = 'Mahir MT28 Coach'
end

function AMM:SetupCustomEntities()

	local files = dir("./Collabs/Custom Entities")
	if #files > 0 then
	  	for _, mod in ipairs(files) do
	    	if string.find(mod.name, '.lua') then
				local data = require("Collabs/Custom Entities/"..mod.name)
				local modder = data.modder
				local uid = data.unique_identifier
				local entity = data.entity_info
				local appearances = data.appearances
				local attributes = data.attributes

				AMM.modders[uid] = modder

				local ent = entity.path:match("[^\\]*.ent$"):gsub(".ent", "")
				local entity_path = "Custom_"..uid.."_"..entity.type.."."..ent

				local check = 0
				for count in db:urows(f("SELECT COUNT(1) FROM entities WHERE entity_path = '%s'", entity_path)) do
					check = count
				end

				if check == 0 then
					local check = 0
					for count in db:urows(f("SELECT COUNT(1) FROM entities WHERE entity_name = '%s'", entity.name)) do
						check = count
					end

					if check ~= 0 then
						entity.name = uid.." "..entity.name
					end

					local entity_id = AMM:GetScanID(entity_path)
					local swappable = AMM:IsApproved(modder, entity.path)
					local canBeComp = 1
					local category = 55
					if entity.type == "Vehicle" then
						canBeComp = 0
						swappable = 1
						category = 56
					end

					local tables = '(entity_id, entity_name, cat_id, parameters, can_be_comp, entity_path, is_spawnable, is_swappable, template_path)'
					local values = f('("%s", "%s", %i, %s, "%s", "%s", "%s", "%s", "%s")', entity_id, entity.name, category, nil, canBeComp, entity_path, 1, swappable, entity.path)
					values = values:gsub('nil', "NULL")
					db:execute(f('INSERT INTO entities %s VALUES %s', tables, values))

					if entity.customName then
						AMM.customNames[entity_id] = entity.name
					end

					-- Setup Appearances
					if appearances ~= nil then
						for _, app in ipairs(appearances) do
							db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
						end
					end

					-- Setup TweakDB Records
					if entity.record ~= nil then
						TweakDB:CloneRecord(entity_path, entity.record)
					else
						TweakDB:CloneRecord(entity_path, "Character.CitizenRichFemaleCasual")
					end

    				TweakDB:SetFlat(entity_path..".entityTemplatePath", entity.path)

					 if attributes ~= nil then
						local newAttributes = {}
						for attr, value in pairs(attributes) do
							newAttributes[attr] = TweakDB:GetFlat(value)
						end
						TweakDB:SetFlats(entity_path, newAttributes)
					 end
				end
			end
		end
	end
end

function AMM:SetupCustomProps()
	db:execute("DELETE FROM entities WHERE entity_path LIKE '%Custom_%'")

	local files = dir("./Collabs/Custom Props")
	if #files > 0 then
	  	for _, mod in ipairs(files) do
	    	if string.find(mod.name, '.lua') then
				local data = require("Collabs/Custom Props/"..mod.name)
				local modder = data.modder
				local uid = data.unique_identifier
				local props = data.props

				AMM.modders[uid] = modder

				for _, prop in ipairs(props) do

					local ent = prop.path:match("[^\\]*.ent$"):gsub(".ent", "")
					local entity_path = "Custom_"..uid.."_Props."..ent

					local check = 0
					for count in db:urows(f("SELECT COUNT(1) FROM entities WHERE entity_path = '%s'", entity_path)) do
						check = count
					end

					if check == 0 then
						local check = 0
						for count in db:urows(f("SELECT COUNT(1) FROM entities WHERE entity_name = '%s'", prop.name)) do
							check = count
						end

						if check ~= 0 then
							prop.name = uid.." "..prop.name
						end

						local entity_id = AMM:GetScanID(entity_path)
						local category = 48
						for cat_id in db:urows(f("SELECT cat_id FROM categories WHERE cat_name = '%s'", prop.category)) do
			      		category = cat_id
			      	end

						local tables = '(entity_id, entity_name, cat_id, parameters, can_be_comp, entity_path, is_spawnable, is_swappable, template_path)'
						local values = f('("%s", "%s", %i, %s, "%s", "%s", "%s", "%s", "%s")', entity_id, prop.name, category, prop.distanceFromGround, 0, entity_path, 1, 0, prop.path)
						values = values:gsub('nil', "NULL")
						db:execute(f('INSERT INTO entities %s VALUES %s', tables, values))
					end
				end
			end
		end
	end
end

function AMM:SetupCollabAppearances()
	db:execute("DELETE FROM appearances WHERE collab_tag IS NOT NULL")

	-- Check for old files in Collabs root
	local files = dir("./Collabs")
	if #files > 0 then
		for _, mod in ipairs(files) do
			if string.find(mod.name, '.lua') then
				os.rename("./Collabs/"..mod.name, "./Collabs/Custom Appearances/"..mod.name)
			end
		end
	end

	local files = dir("./Collabs/Custom Appearances")
	local collabs = {}
	if #files > 0 then
	  	for _, mod in ipairs(files) do
	    	if string.find(mod.name, '.lua') then
				local collab = require("Collabs/Custom Appearances/"..mod.name)
				local metadata = collab.metadata
		
				if metadata == nil then
					local entity_id = collab.entity_id
					local uid = collab.unique_identifier
					local appearances = collab.appearances

					-- Setup Appearances
					for _, app in ipairs(appearances) do
						db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
					end
				else

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
	end

	return collabs
end

function AMM:SetupVehicleData()
	local unlockableVehicles = TweakDB:GetFlat(TweakDBID.new('Vehicle.vehicle_list.list'))
	AMM.originalVehicles = unlockableVehicles
	for vehicle in db:urows("SELECT entity_path FROM entities WHERE cat_id = 24 OR cat_id = 25 OR cat_id = 56 AND entity_path LIKE '%Vehicle%'") do
		table.insert(unlockableVehicles, TweakDBID.new(vehicle))
	end

	TweakDB:SetFlat(TweakDBID.new('Vehicle.vehicle_list.list'), unlockableVehicles)
end

function AMM:GetNPCTweakDBID(npc)
	if type(npc) == 'userdata' then return npc end
	return TweakDBID.new(npc)
end

function AMM:DespawnAll(message)
	if message then AMM.player:SetWarningMessage("Despawning will occur once you look away") end
	for i = 0, 99 do
		Game.GetPreventionSpawnSystem():RequestDespawnPreventionLevel(i * -1)
	end

	AMM.Spawn:DespawnAll()
end

function AMM:TeleportAll()
	for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
		if ent.handle:IsNPC() then
			Util:TeleportNPCTo(ent.handle, Util:GetBehindPlayerPosition(2))
		end
	end
end

function AMM:RespawnAll()
	if AMM.entitiesForRespawn == '' then
		AMM.entitiesForRespawn = {}
		for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
			if not(string.find(ent.path, "Vehicle")) then
				if ent.handle and ent.handle ~= '' then					
					if ent.handle:IsNPC() then
						Util:TeleportNPCTo(ent.handle, Util:GetBehindPlayerPosition(2))
					end
				end
				table.insert(AMM.entitiesForRespawn, ent)
			end
		end

		AMM:DespawnAll(buttonPressed)
		if buttonPressed then buttonPressed = false end
	end

	Cron.Every(0.5, function(timer)
		local ent = AMM.entitiesForRespawn[1]
		local entity = nil
	
		if ent then
			if ent.entityID ~= '' then entity = Game.FindEntityByID(ent.entityID) end
			if entity == nil then
				table.remove(AMM.entitiesForRespawn, 1)
				AMM.Spawn:SpawnNPC(ent)
			end
		end

		if #AMM.entitiesForRespawn == 0 or AMM.entitiesForRespawn == '' then
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
	for name, value in pairs(AMM.userSettings) do
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

	Util:GetAllInRange(10, false, true, function(entity)
		local ent = nil

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
	end)
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

function AMM:ClearAllBlacklistedAppearances()
	db:execute("DELETE FROM blacklist_appearances")
end

function AMM:ClearAllSavedDespawns()
	db:execute("DELETE FROM saved_despawns")
end

function AMM:ClearAllFavorites()
	db:execute("DELETE FROM favorites; UPDATE sqlite_sequence SET seq = 0")
end

function AMM:ClearAllSwapFavorites()
	db:execute("DELETE FROM favorites_swap; UPDATE sqlite_sequence SET seq = 0")
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
	local tdbid
	local hasRecord
	if type(t) == 'userdata' then
		hasRecord, tdbid = pcall(function() return t:GetRecordID() end)
		if not hasRecord then
			print("[AMM Debug] No Record ID Available For This Target")
		end
	else
		tdbid = tostring(TweakDBID.new(t))
	end
	local hash = tostring(tdbid):match("= (%g+),")
	local length = tostring(tdbid):match("= (%g+) }")
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

function AMM:GetAppearanceOptions(t, id)
	local options = {}

	local scanID = id or self:GetScanID(t)
	return self:GetAppearanceOptionsWithID(scanID, t)
end

function AMM:GetAppearanceOptionsWithID(id, t)
	local options = {}

	if self.Swap.activeSwaps[id] ~= nil then
	 	id = self.Swap.activeSwaps[id].newID
	end

	if self.customAppPosition == "Top" then
		options = self:LoadCustomAppearances(options, id)
	end

	if self.Swap.activeSwaps[id] == nil then
		if t ~= nil and t:IsNPC() and t:GetRecord():CrowdAppearanceNames()[1] ~= nil then
			for _, app in ipairs(t:GetRecord():CrowdAppearanceNames()) do
				table.insert(options, tostring(app):match("%[ (%g+) -"))
			end
		else
			for app in db:urows(f("SELECT app_name FROM appearances WHERE entity_id = '%s' ORDER BY app_name ASC", id)) do
				table.insert(options, app)
			end
		end
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

function AMM:GetAppearance(t)
	if t and t ~= '' and t.hash == '' then
		t.hash = tostring(t.handle:GetEntityID().hash)
	end

	-- Check if custom appearance is active
	if self.activeCustomApps[t.hash] ~= nil then
		return self.activeCustomApps[t.hash]
	else
		return self:GetScanAppearance(t.handle)
	end
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
			for count in db:urows(f("SELECT COUNT(1) FROM custom_appearances WHERE entity_id = '%s' AND app_name = '%s' AND collab_tag = '%s'", target.id, appearance, collab.tag)) do
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

function AMM:ShouldCycleAppearance(appearance)
	local keywordsToBlock = {
		" No ", " With ", "Underwear", "Naked"
	}

	for _, keyword in ipairs(keywordsToBlock) do
		if string.find(appearance, keyword) then
			return false
		end
	end

	return true
end

function AMM:ChangeAppearanceTo(entity, appearance)
	-- local appearance, reverse = AMM:CheckForReverseCustomAppearance(appearance, entity)
	if entity.type == "Prop" then
		AMM.Props:ChangePropAppearance(entity, appearance)
	else
		-- Check if custom app is active
		local activeApp = nil

		if next(self.activeCustomApps) ~= nil and self.activeCustomApps[entity.hash] ~= nil then
			activeApp = self.activeCustomApps[entity.hash]
		end

		local custom = AMM:GetCustomAppearanceParams(entity, appearance)

		if (activeApp and #custom == 0) or (#custom > 0 and AMM:ShouldCycleAppearance(appearance)) then
			AMM:ChangeScanAppearanceTo(entity, "Cycle")
		end

		Cron.After(0.15, function()
			if #custom > 0 then
				AMM:ChangeScanCustomAppearanceTo(entity, custom)
			else
				AMM:ChangeScanAppearanceTo(entity, appearance)
			end

			Cron.After(0.2, function()
				entity.appearance = AMM:GetAppearance(entity)
			end)
		end)
	end
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
					t = AMM:NewTarget(target, AMM:GetScanClass(target), "None", AMM:GetObjectName(target),AMM:GetScanAppearance(target), nil)
				end
			end

			if t ~= nil and t.name ~= "gameuiWorldMapGameObject" and t.name ~= "ScriptedWeakspotObject" then
				AMM:SetCurrentTarget(t)
				AMM:CreateBusInteractionPrompt(t)				
				return t
			end
		end
	end

	-- Disables Prompt if active
	if AMM.displayInteractionPrompt and GetVersion() ~= "v1.15.0" then
		Util:SetInteractionHub("Enter Bus", "Choice1", false)
		AMM.displayInteractionPrompt = false
	end
	
	return nil
end

function AMM:UpdateFollowDistance()
	local spawnsCounter = 0
	for _ in pairs(AMM.Spawn.spawnedNPCs) do spawnsCounter = spawnsCounter + 1 end

	if spawnsCounter < 3 then
		self:SetFollowDistance(AMM.followDistance[2])
	elseif spawnsCounter == 3 then
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

function AMM:ProcessCompanionAttack(hitEvent)
	local instigatorNPC = hitEvent.attackData:GetInstigator()
	local dmgType = hitEvent.attackComputed:GetDominatingDamageType()

	if instigatorNPC and instigatorNPC:IsPlayerCompanion() then
		hitEvent.attackComputed:MultAttackValue(AMM.companionAttackMultiplier, dmgType)
	end
end

-- Helper methods
function AMM:CreateBusInteractionPrompt(t)
	if GetVersion() ~= "v1.15.0" then
		if t.id == '0xE09AAEB8, 26' then
			local pos = t.handle:GetWorldPosition()
			local playerPos = AMM.player:GetWorldPosition()
			local dist = Util:VectorDistance(pos, playerPos)

			if dist < 6 and not AMM.displayInteractionPrompt then
				AMM.displayInteractionPrompt = true
				Util:SetInteractionHub("Enter Bus", "Choice1", true)
			elseif dist > 6 and AMM.displayInteractionPrompt then
				Util:SetInteractionHub("Enter Bus", "Choice1", false)
				AMM.displayInteractionPrompt = false
			end
		end
	end
end

function AMM:BusPromptAction()
	local target = Game.GetTargetingSystem():GetLookAtObject(AMM.player, false, false)
	if target ~= nil and target:IsVehicle() and AMM.displayInteractionPrompt then
		local seat = "seat_front_left"
		if AMM.Scan.selectedSeats["Player"] then seat = AMM.Scan.selectedSeats["Player"].seat.cname end
		AMM.Scan:MountPlayer(seat, target)
		Util:SetInteractionHub("Enter Bus", "Choice1", false)
	end
end

function AMM:IsUnique(npcID)
	for _, v in ipairs(self.allowedNPCs) do
		if npcID == v then
			-- NPC is unique
			return true
		end
	end
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
		popupDelegate.message = "If you are sure you want to delete all your favorites, select which one below:"
		table.insert(popupDelegate.buttons, {label = "Spawn Favorites", action = function() AMM:ClearAllFavorites() end})
		table.insert(popupDelegate.buttons, {label = "Swap Favorites", action = function() AMM:ClearAllSwapFavorites() end})
		table.insert(popupDelegate.buttons, {label = "Cancel", action = ''})
		name = "WARNING"
	elseif name == "Appearances" then
		ImGui.SetNextWindowSize(400, 140)
		popupDelegate.message = "Are you sure you want to delete all your saved appearances?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() AMM:ClearAllSavedAppearances() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	elseif name == "Blacklist" then
		ImGui.SetNextWindowSize(400, 140)
		popupDelegate.message = "Are you sure you want to delete all your blacklisted appearances?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() AMM:ClearAllBlacklistedAppearances() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	elseif name == "Saved Despawns" then
		ImGui.SetNextWindowSize(400, 140)
		popupDelegate.message = "Are you sure you want to delete all your saved despawns?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() AMM:ClearAllSavedDespawns() end})
		table.insert(popupDelegate.buttons, {label = "No", action = ''})
		name = "WARNING"
	elseif name == "Preset" then
		ImGui.SetNextWindowSize(400, 140)
		popupDelegate.message = "Are you sure you want to delete your current active preset?"
		table.insert(popupDelegate.buttons, {label = "Yes", action = function() AMM.Props:DeletePreset(AMM.Props.activePreset) end})
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
			AMM.Spawn:SpawnNPC(target)
			buttonPressed = true
		elseif action == "SpawnVehicle" then
			AMM.Spawn:SpawnVehicle(target)
			buttonPressed = true
		elseif action == "SpawnProp" then
			AMM.Props:SpawnProp(target)
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

function AMM:DrawArchives()
	AMM.UI:TextColored("AMM Needs Attention")

	AMM.UI:Spacing(8)
	AMM.UI:TextCenter(" MISSING ARCHIVES ")
	ImGui.Spacing()
	AMM.UI:TextCenter("AMM Version: "..AMM.currentVersion, true)
	ImGui.Spacing()
	AMM.UI:TextCenter("CET Version: "..GetVersion(), true)
	ImGui.Spacing()
	AMM.UI:TextCenter("Game Version: "..Game.GetSystemRequestsHandler():GetGameVersion(), true)
	AMM.UI:Separator()

	local missingRequired = false

	for _, archive in ipairs(AMM.archives) do
		AMM.UI:TextColored(archive.name)

		if not archive.active then
			ImGui.SameLine()
			AMM.UI:TextError(" MISSING")
		end

		if not archive.optional and not archive.active then
			ImGui.SameLine()
			AMM.UI:TextError("REQUIRED")
			missingRequired = true
		end

		ImGui.TextWrapped(archive.desc)

		AMM.UI:Spacing(4)
	end

	AMM.UI:Separator()

	AMM.UI:TextColored("WARNING")

	if missingRequired then
		ImGui.TextWrapped("AMM is missing one or more required archives. Please install any missing required archive in your archive/pc/mod folder.")
	else
		ImGui.TextWrapped("AMM is missing one or more archives. These are optional but add functionality to AMM. You may ignore these warnings, but AMM might not work properly.")

		AMM.UI:Spacing(4)

		if ImGui.Button("Ignore warnings for this version!", ImGui.GetWindowContentRegionWidth(), 40) then
			db:execute("UPDATE metadata SET ignore_archives = 1")
		end
	end
end

-- End of AMM Class

return AMM:new()
