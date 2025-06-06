-- Begin of AMM Class

AMM = {
	description = "",
}

-- Global for Error Tracking --
local initializationComplete = false

-- ALIAS for spdlog.error --
log = spdlog.error

-- ALIAS for string.format --
f = string.format

-- Helper global function --
function count(tbl)
	local count = 0
	for _ in pairs(tbl) do
			count = count + 1
	end
	return count
end

function printTable(t)
	if #t == 0 then
		for k,v in pairs(t) do
			 print(k .. " : " .. tostring(v))
		end
  else
		for i,v in ipairs(t) do
			 print(i .. " : " .. tostring(v))
		end
  end
end

local buttonPressed, finishedUpdate = false, false
local waitTimer, spamTimer, delayTimer = 0.0, 0.0, 0.0


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

local function parseVersion(str)
	local major, minor = str:match("1.(%d+)%.*(%d*)")
	if major then
		minor = minor or "0" -- If minor is not present, assume it's "0"
		local result = major .. "." .. minor
		return tonumber(result) -- This will return "5.0" for "1.5"
	else
		print("Version format not recognized")
	end
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
	 AMM.TeleportMod = nil
	 AMM.UniqueVRig = false
	 AMM.nibblesReplacer = false
	 AMM.photoModeNPCsExtended = false
	 AMM.extraExpressionsInstalled = false

	 -- Main Properties --
	 AMM.currentVersion = "2.11.2"
	 AMM.CETVersion = parseVersion(GetVersion())
	 AMM.CodewareVersion = 0
	 AMM.updateNotes = require('update_notes.lua')
	 AMM.credits = require("credits.lua")
	 AMM.updateLabel = "WHAT'S NEW"
	 AMM.userSettings = AMM:PrepareSettings()
	 AMM.player = nil
	 AMM.currentTarget = ''
	 AMM.allowedNPCs = AMM:GetSaveables()
	 AMM.equipmentOptions = AMM:GetEquipmentOptions()
	 AMM.followDistanceOptions = AMM:GetFollowDistanceOptions()
	 AMM.companionAttackMultiplier = 0
	 AMM.companionResistanceMultiplier = 0
	 AMM.originalVehicles = ''
	 AMM.displayInteractionPrompt = false
	 AMM.archives = nil
	 AMM.archivesInfo = {missing = false, optional = true, sounds = true}
	 AMM.collabArchives = {}
	 AMM.savedAppearanceCheckCache = {}
	 AMM.blacklistAppearanceCheckCache = {}
	 AMM.cachedEntities = {}
	 AMM.bannedWords = {"naked", "nude", "pp", "xxx", "penis", "birthday_suit", "shower"}
	 AMM.cachedAppearanceOptions = {}

	 -- Songbird Properties --
	 AMM.SBInWorld = false
	 AMM.SBLocations = nil
	 AMM.SBLookAt = false
	 AMM.SBItems = nil
	 AMM.playerLastPos = ''

	 -- Hotkeys Properties --
	 AMM.selectedHotkeys = {}

	 -- Custom Appearance Properties --
	 AMM.collabs = nil
	 AMM.setCustomApp = ''
	 AMM.activeCustomApps = {}
	 AMM.customAppDefaults = nil
	 AMM.customAppOptions = {"Top", "Bottom", "Off"}
	 AMM.customAppPosition = "Top"

	 -- Custom Entities Properties --
	 AMM.modders = {}
	 AMM.customNames = {}
	 AMM.hasCustomProps = false

	 -- Configs --
	 AMM.playerAttached = false
	 AMM.playerInMenu = true
	 AMM.playerInPhoto = false
	 AMM.playerInVehicle = false
	 AMM.playerInCombat = false
	 AMM.playerCurrentDistrict = nil
	 AMM.playerCurrentZone = nil
	 AMM.playerGender = nil
	 AMM.settings = false
	 AMM.ignoreAllWarnings = false
	 AMM.shouldCheckSavedAppearance = true
	 AMM.importInProgress = false
	 AMM.deltaTime = 0

	 -- Load Localization Files
	 AMM.currentLanguage = require("Localization/en_US.lua")
	 AMM.availableLanguages = AMM:GetLocalizationLanguages()
	 AMM.selectedLanguage = AMM:GetLanguageIndex("en_US")

	 -- Load Modules --
	 AMM.API = require("Collabs/API.lua")
	 AMM.Spawn = require('Modules/spawn.lua')
	 AMM.Scan = require('Modules/scan.lua')
	 AMM.Swap = require('Modules/swap.lua')
	 AMM.Tools = require('Modules/tools.lua')
	 AMM.Props = require('Modules/props.lua')
	 AMM.Director = require('Modules/director.lua')
	 AMM.Poses = require('Modules/anims.lua')

	 -- Loads Objects --
	 AMM.Light = require('Modules/light.lua')
	 AMM.Camera = require('Modules/camera.lua')
	 AMM.Entity = require('Modules/entity.lua')

	 AMM:ImportUserData()

	 registerForEvent("onInit", function()
		 waitTimer = 0.0
		 spamTimer = 0.0
		 delayTimer = 0.0
		 buttonPressed = false
		 finishedUpdate = AMM:CheckDBVersion()

		 if Codeware then
		 	AMM.CodewareVersion = parseVersion(Codeware.Version())
		 else
			log("Codeware isn't loaded.")
		 end

		 if AMM.Debug ~= '' then
			AMM.player = Game.GetPlayer()
		 end

		 -- Setup Extra Facial Expressions --
		 if ModArchiveExists("AMM_Expressions_MEGA_PACK.archive") then
			AMM.extraExpressionsInstalled = true
		 end

		 -- Setup Unique V Framework --
		 if ModArchiveExists("zz_johnson_Framework_Unique_V_Body_Shape.archive") then
			AMM.UniqueVRig = true
		 end

		 -- Setup Nibbles Replacer --
		 if ModArchiveExists("Photomode_NPCs_AMM.archive") then
			AMM.nibblesReplacer = true
		 end

		 -- Setup Photo Mode NPCs Extended
		 if ModArchiveExists('Photomode_NPCs_Extended_xBaebsae.archive') then
			AMM.photoModeNPCsExtended = true
			local pattern = "photomode_appearance"
			local query = f("DELETE FROM appearances WHERE app_name LIKE '%%%s%%';", pattern)
			db:execute(query)
		 end

		 -- Setup content that requires specific archives
		 AMM.archivesInfo = AMM:CheckMissingArchives()
		 AMM:SetupExtraFromArchives()
		 
		 -- Setup AMM Characters and Collab features
		 AMM:SetupCollabs()		 
		 AMM:SetupAMMCharacters()
		 AMM.collabs = AMM:SetupCollabAppearances()
		 AMM.customAppDefaults = AMM:GetCustomAppearanceDefaults()

		 -- Initialization
		 AMM.Spawn:Initialize()
		 AMM.Scan:Initialize()
		 AMM.Tools:Initialize()
		 AMM.Swap:Initialize()
		 AMM.Props:Initialize()
		 AMM.Props:Update()
		 AMM.Director:Initialize()
		 AMM:SBInitialize()

		 -- Poses should be initialized after extra archives
		 AMM.Poses:Initialize()

		 initializationComplete = true

		 -- Check if user is in-game using WorldPosition --
		 -- Only way to set player attached if user reload all mods --
		 local player = AMM.player or Game.GetPlayer()
		 if player then
			 local playerPosition = player:GetWorldPosition()

			 if math.floor(playerPosition.z) ~= 0 then
				 AMM.player = player
				 AMM.playerAttached = true
				 AMM.playerGender = Util:GetPlayerGender()
				 AMM.playerInMenu = false

				 if AMM.userSettings.respawnOnLaunch and next(AMM.Spawn.spawnedNPCs) ~= nil then
				 	AMM:RespawnAll()
				 end
			 end
		 end

		 -- Setup GameSession --
		 GameSession.OnStart(function()
			 AMM.player = Game.GetPlayer()
			 AMM.playerAttached = true
			 AMM.playerGender = Util:GetPlayerGender()

			 AMM.Tools:CheckGodModeIsActive()

			 if StatusEffectSystem.ObjectHasStatusEffectWithTag(Game.GetPlayer(), 'NoCameraControl') then
				Util:RemovePlayerEffects()
			 end

			 if next(AMM.Spawn.spawnedNPCs) ~= nil then
				if AMM.userSettings.respawnOnLaunch then
			 		AMM:RespawnAll()
				else
					AMM.Spawn.spawnedNPCs = {}
				end
			 end

			 AMM.Tools:ToggleAnimatedHead(Tools.animatedHead)

			 AMM.Poses.activeAnims = {}
			 AMM.Props.activeProps = {}
			 AMM.playerLastPos = ''
			 Util.playerLastPos = ''

			 AMM.Scan:ResetSavedDespawns()

			 AMM.Director:StopAll()
		 end)

		 GameSession.OnEnd(function()
			 AMM.playerAttached = false
			 AMM.player = nil
			 AMM.savedAppearanceCheckCache = {}
			 AMM.Tools.axisIndicator = nil
			 AMM.Tools.currentTarget = ''
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
			 if Props.activePreset and Props.activePreset ~= '' then
			 	Props:BackupPreset(Props.activePreset)
			 end
		 end)

		 -- Setup Observers and Overrides --

		--  Observe('ElevatorInkGameController', 'OnChangeFloor', function(this)
		-- 	AMM:StartCompanionsFollowElevator()
	 	--  end)

		 local puppetSpawned = false
		 ObserveAfter('PhotoModePlayerEntityComponent', 'SetupInventory', function(self)
			local isV = AMM:GetNPCName(self.fakePuppet) == "V"

			if puppetSpawned or isV then
				AMM.Tools:ClearListOfPuppets()
				AMM.Tools:AddNewPuppet(self.fakePuppet)
			end
		 end)

		 Observe('gameuiPhotoModeMenuController', 'OnSetNpcImage', function(this)
			puppetSpawned = true
	 	 end)
		 
		 Observe('PhotoModeMenuListItem', 'OnSliderHandleReleased', function(this)
			for _, puppet in ipairs(AMM.Tools.listOfPuppets) do
				local currentPos = tostring(puppet.handle:GetWorldPosition())
				local savedPos = tostring(puppet.pos)
				local currentAngles = tostring(puppet.handle:GetWorldOrientation():ToEulerAngles())
				local savedAngles = tostring(puppet.angles)

				if AMM.Tools.updatedPosition[puppet.hash] and (currentPos ~= savedPos or currentAngles ~= savedAngles) then
					AMM.Tools.updatedPosition[puppet.hash] = nil
				end
			end
	 	end)

		 Observe('PhotoModeMenuListItem', 'StartArrowClickedEffect', function(this)

				-- local attribute = this:GetData().attributeKey
				-- local delay = 0.01
				-- if attribute == 5 or attribute == 65 or attribute == 68 then delay = 0.03 end

				AMM.Tools:ResetPuppetsPosition()
		 end)

		 ObserveAfter('gameuiPhotoModeMenuController', 'OnSetCategoryEnabled', function(this)
			this.topButtonsController:SetToggleEnabled(0, not(AMM.userSettings.disableCameraTab))
			this.topButtonsController:SetToggleEnabled(1, not(AMM.userSettings.disableDOFTab))

			if AMM.CETVersion < 34 then
				this.topButtonsController:SetToggleEnabled(3, not(AMM.userSettings.disableEffectTab))
				this.topButtonsController:SetToggleEnabled(4, not(AMM.userSettings.disableStickersTab))
				this.topButtonsController:SetToggleEnabled(5, not(AMM.userSettings.disableLoadSaveTab))
			else
				this.topButtonsController:SetToggleEnabled(5, not(AMM.userSettings.disableEffectTab))
				this.topButtonsController:SetToggleEnabled(6, not(AMM.userSettings.disableStickersTab))
				this.topButtonsController:SetToggleEnabled(7, not(AMM.userSettings.disableLoadSaveTab))
			end
		 end)

		 Override("CursorGameController", "ProcessCursorContext", function(self, context, data, force, wrapped)
			AMM.Tools.cursorController = self

			if AMM.Tools.cursorDisabled then
				wrapped(CName.new("Hide"), data, force)
			else
				wrapped(context, data, force)
			end
		 end)

		 Observe('PlayerPuppet', 'OnZoneChange', function(self, enum)
			AMM.playerCurrentZone = enum.value
			AMM.Scan:ActivateAppTriggerForType("zone")
		 end)

		 Observe('PlayerPuppet', 'OnCombatStateChanged', function(self, newState)
			if newState == 1 then
				AMM.playerInCombat = true
			end

			if AMM.playerInCombat and newState == 2 then
				AMM.Scan:ActivateAppTriggerForType("default")
			elseif AMM.playerInCombat then
				AMM.Scan:ActivateAppTriggerForType("combat")
			end

			if newState ~= 1 then
				AMM.playerInCombat = false
			end
		 end)


		 local previousDistrict = nil
		 Observe('DistrictManager', 'PushDistrict', function(self, request)
			if self then
				local currentDistrict = self:GetCurrentDistrict()
				if currentDistrict then
					local previousDistrictRecord = TweakDB:GetRecord(currentDistrict:GetDistrictID())
					previousDistrict = Game.GetLocalizedText(previousDistrictRecord:LocalizedName())
				end

				local districtRecord = TweakDB:GetRecord(request.district)
				AMM.playerCurrentDistrict = Game.GetLocalizedText(districtRecord:LocalizedName())
				AMM.Scan:ActivateAppTriggerForType("area")
			end
		 end)


		 Observe('DistrictManager', 'PopDistrict', function(self, request)
			local districtRecord = TweakDB:GetRecord(request.district)
			local districtName = Game.GetLocalizedText(districtRecord:LocalizedName())

			if AMM.playerCurrentDistrict == districtName and previousDistrict ~= districtName then
				AMM.playerCurrentDistrict = previousDistrict
		 	end

			AMM.Scan:ActivateAppTriggerForType("area")
		 end)


		 Observe('DamageSystem', 'ProcessRagdollHit', function(self, hitEvent)
			AMM:ProcessCompanionAttack(hitEvent)
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

		Override("gameuiWorldMapMenuGameController", "IsFastTravelEnabled", function(self, wrappedMethod)
			if AMM.Scan.companionDriver then
				return true
			else
				return wrappedMethod()
			end
		end)

		Override("gameuiWorldMapMenuGameController", "TryFastTravel", function(self, wrappedMethod)
			if self.selectedMappin and AMM.Scan.companionDriver then
				if fastTravelScenario and fastTravelScenario:IsA("MenuScenario_HubMenu") then
					if tostring(self.selectedMappin:GetMappinVariant()) == "gamedataMappinVariant : FastTravelVariant (51)" then
						AMM.Scan:SetVehicleDestination(self, vehicleMap)
						fastTravelScenario:GotoIdleState()
						fastTravelScenario:GotoIdleState()
					end
				end
			else
				wrappedMethod()
			end
		end)

		ObserveBefore("VehicleComponent", "OnVehicleStartedMountingEvent", function(self, event)
			if event.character:IsPlayer() then
				local vehicle = self:GetVehicle()
				local beforeApp = AMM:GetScanAppearance(vehicle)
				vehicleTarget = AMM:NewTarget(vehicle, 'vehicle', AMM:GetScanID(vehicle), AMM:GetVehicleName(vehicle), currentApp, nil)

				Cron.Every(0.0001, { tick = 10 }, function(timer)

					timer.tick = timer.tick + 1

					if timer.tick > 100 then
						Cron.Halt(timer)
					end

					local currentApp = AMM:GetScanAppearance(vehicle)
					if currentApp ~= beforeApp then
						AMM:ChangeScanAppearanceTo(vehicleTarget, beforeApp)
						beforeApp = nil
						Cron.Halt(timer)
					end
				end)
			end
		end)

		 Observe("VehicleComponent", "OnVehicleStartedMountingEvent", function(self, event)
			 if AMM.Scan.drivers[AMM:GetScanID(event.character)] ~= nil then
				 local driver = AMM.Scan.drivers[AMM:GetScanID(event.character)]
				 if AMM.Scan.vehicle.hash ~= driver.vehicle.hash then
				 	AMM.Scan:SetDriverVehicleToFollow(driver)
				 else
					AMM.Scan.companionDriver = driver

					if AMM.TeleportMod then
						AMM.TeleportMod.api.modBlocked = true
					end

					Cron.After(5, function()
						if not AMM.Scan.isDriving then
							AMM.player:SetWarningMessage(AMM.LocalizableString("WarnTextAI_FastTravel"))
						end
					end)
				 end
		 	 elseif event.character:IsPlayer() then
				 AMM.playerInVehicle = event.isMounting				 

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
					 if AMM.Scan.companionDriver then
						AMM.Scan.companionDriver = nil
					 end

					 if AMM.Scan.AIDriver then
						AMM.Scan.AIDriver = false
					 end

					 if #AMM.Scan.leftBehind > 0 then
						 for _, lost in ipairs(AMM.Scan.leftBehind) do
						 	lost.ent:GetAIControllerComponent():StopExecutingCommand(lost.cmd, true)
							Util:TeleportNPCTo(lost.ent, Util:GetBehindPlayerPosition(5))
						 end

						 AMM.Scan.leftBehind = {}
					 end

					 if next(AMM.Scan.drivers) ~= nil then
						 AMM.Scan:UnmountDrivers()

						 if AMM.TeleportMod then
							AMM.TeleportMod.api.modBlocked = false
						end
					 end

					 if next(AMM.Spawn.spawnedNPCs) ~= nil then
						AMM:UpdateFollowDistance()
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

		Observe("EquipCycleInitEvents", "OnEnter", function(_self, script)
			if AMM.Tools.TPPCamera then
				AMM.Tools:ToggleTPPCamera()
				AMM.Tools.TPPCameraBeforeVehicle = true
			end
		end)

		Observe("UnequippedEvents", "OnExit", function(_self, script)
			if AMM.Tools.TPPCameraBeforeVehicle and not AMM.playerInVehicle then
				AMM.Tools.TPPCameraBeforeVehicle = false

				Cron.After(0.1, function()
					AMM.Tools:ToggleTPPCamera()
				end)
			end
		end)

		Observe("PlayerPuppet", "OnAction", function(_self, action)
			local actionName = Game.NameToString(action:GetName(action))
			local actionType = action:GetType(action).value

			if AMM.Director.activeCamera then
				AMM.Director.activeCamera:HandleInput(actionName, actionType, action)
			end

			if AMM.Tools.directMode and (AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '') then
				AMM.Tools.currentTarget:HandleInput(actionName, actionType, action)
			end

			if AMM.Light.stickyMode and AMM.Light.activeLight and AMM.Light.activeLight.isAMMLight then
				AMM.Light.activeLight:HandleInput(actionName, actionType, action)
				AMM.Light.camera:HandleInput(actionName, actionType, action)
			end

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
			elseif actionName == 'DescriptionChange'
			and (AMM.Props.buildMode or AMM.Tools.directMode) then
				if actionType == 'BUTTON_RELEASED' then
					AMM.Tools:ToggleDirectMode(true)
				end
			elseif actionName == 'track_quest' and AMM.Props.buildMode then
				if actionType == 'BUTTON_RELEASED' then
					local newTarget = AMM:GetTarget()
					if newTarget then
						if AMM.Tools.lockTarget and AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '' then
							AMM.Tools:ClearTarget()
							AMM.Tools:ToggleDirectMode(true)
						else
							AMM.Tools:SetCurrentTarget(newTarget)
							AMM.Tools.lockTarget = true
						end
					else
						AMM.Tools:ClearTarget()
					end
				end
			elseif actionName == 'Reload'
			and AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '' then
				if actionType == 'BUTTON_RELEASED' or actionType == "BUTTON_HOLD_COMPLETE" then
					if AMM.Tools.currentTarget.speed <= 1 then
						AMM.Tools.currentTarget.speed = AMM.Tools.currentTarget.speed + 0.01
					end
				end
			elseif actionName == 'Jump'
			and AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '' then
				if actionType == 'BUTTON_RELEASED' or actionType == "BUTTON_HOLD_COMPLETE" then
					if AMM.Tools.currentTarget.speed > 0.01 then
						AMM.Tools.currentTarget.speed = AMM.Tools.currentTarget.speed - 0.01
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

		Observe('PlayerPuppet', 'OnDetach', function(self)
			if not self:IsReplacer() then
				vehicleMap = {}
				collectgarbage()
			end
	  	end)
	 end)

	 registerForEvent("onShutdown", function()
		 AMM.Director:DespawnActiveCamera()

		 if StatusEffectSystem.ObjectHasStatusEffectWithTag(Game.GetPlayer(), 'NoCameraControl') then
			Util:RemovePlayerEffects()
		 end

		 AMM:ExportUserData()
	 end)

	 -- TweakDB Changes
	 if AMM.CETVersion >= 18 then
		registerForEvent('onTweak', function()

			-- Nibbles Replacer LocKey Update --
			if AMM.CETVersion < 34 and AMM.Tools.replacer then
				TweakDB:SetFlat('photo_mode.general.localizedNameForPhotoModePuppet', {"LocKey#48683", "LocKey#34414", 'Replacer'})
				-- TweakDB:SetFlat('photo_mode.character.quadrupedPoses', AMM.Tools.replacer.poses)
			end

			-- Fix Record Names for Photo Mode Puppets (CDPR, :facepalm:)
			TweakDB:SetFlat('Character.AdamSmasher_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Smasher.displayName'))
			TweakDB:SetFlat('Character.AltJohnny_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Silverhand.displayName'))
			TweakDB:SetFlat('Character.Alt_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Alt.displayName'))
			TweakDB:SetFlat('Character.BlueMoon_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.sq017_blue_moon.displayName'))
			TweakDB:SetFlat('Character.Evelyn_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Evelyn.displayName'))
			TweakDB:SetFlat('Character.Goro_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Takemura.displayName'))
			TweakDB:SetFlat('Character.Hanako_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Hanako.displayName'))
			TweakDB:SetFlat('Character.Jackie_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Jackie.displayName'))
			TweakDB:SetFlat('Character.JohnnyNPC_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Silverhand.displayName'))
			TweakDB:SetFlat('Character.Johnny_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Silverhand.displayName'))
			TweakDB:SetFlat('Character.Judy_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Judy.displayName'))
			TweakDB:SetFlat('Character.Kerry_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Kerry.displayName'))
			TweakDB:SetFlat('Character.Kurt_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.kurtz.displayName'))
			TweakDB:SetFlat('Character.Lizzy_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Lizzy_Wizzy.displayName'))
			TweakDB:SetFlat('Character.Meredith_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Stout.displayName'))
			TweakDB:SetFlat('Character.Myers_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.myers.displayName'))
			TweakDB:SetFlat('Character.Nibbles_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.q003_cat.displayName'))
			TweakDB:SetFlat('Character.Panam_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Panam.displayName'))
			TweakDB:SetFlat('Character.PurpleForce_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.sq017_purple_force.displayName'))
			TweakDB:SetFlat('Character.RedMenace_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.sq017_red_menace.displayName'))
			TweakDB:SetFlat('Character.Reed_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.reed.displayName'))
			TweakDB:SetFlat('Character.River_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Sobchak.displayName'))
			TweakDB:SetFlat('Character.RogueOld_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Rogue.displayName'))
			TweakDB:SetFlat('Character.RogueYoung_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Rogue.displayName'))
			TweakDB:SetFlat('Character.Songbird_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.songbird.displayName'))
			TweakDB:SetFlat('Character.Viktor_Puppet_Photomode.displayName', TweakDB:GetFlat('Character.Victor_Vector.displayName'))

			if AMM.userSettings.photoModeEnhancements then
				-- Adjust Photomode Defaults
				TweakDB:SetFlat('photo_mode.attributes.dof_aperture_default', AMM.Tools.defaultAperture)
				TweakDB:SetFlat('photo_mode.camera.default_fov', AMM.Tools.defaultFOV)
				TweakDB:SetFlat('photo_mode.camera.min_fov', 1.0)
				TweakDB:SetFlat('photo_mode.camera.max_roll', 180)
				TweakDB:SetFlat('photo_mode.camera.min_roll', -180)
				TweakDB:SetFlat('photo_mode.general.onlyFPPPhotoModeInPlayerStates', {})
				TweakDB:SetFlat('LookatPreset.PhotoMode_LookAtCamera.followingSpeedFactorOverride', 1200.0)
				-- TweakDB:SetFlat('photo_mode.character.max_position_adjust', 100)
				-- TweakDB:SetFlat('photo_mode.camera.max_dist', 1000)
				-- TweakDB:SetFlat('photo_mode.camera.min_dist', 0.2)
				-- TweakDB:SetFlat('photo_mode.camera.max_dist_up_down', 1000)
				-- TweakDB:SetFlat('photo_mode.camera.max_dist_left_right', 1000)
				-- TweakDB:SetFlat('photo_mode.general.collisionRadiusForPhotoModePuppet', {0, 0, 0})
				-- TweakDB:SetFlat('photo_mode.general.collisionRadiusForNpcs', 0)
				-- TweakDB:SetFlat('photo_mode.general.force_lod0_characters_dist', 0)
				-- TweakDB:SetFlat('photo_mode.general.force_lod0_vehicles_dist', 0)

				for pose in db:nrows("SELECT * FROM photomode_poses") do
					local poseID = 'PhotoModePoses.'..pose.pose_name

					if not TweakDB:GetRecord(poseID) then
						Util:AMMError(pose.pose_name.." doesn't exist.")
						db:execute(f("DELETE FROM photomode_poses WHERE pose_name = '%s'", pose.pose_name))
					end

					TweakDB:SetFlat('PhotoModePoses.'..pose.pose_name..'.disableLookAtForGarmentTags', {})
					TweakDB:SetFlat('PhotoModePoses.'..pose.pose_name..'.filterOutForGarmentTags', {})
					TweakDB:SetFlat('PhotoModePoses.'..pose.pose_name..'.lookAtPreset', 'LookatPreset.PhotoMode_LookAtCamera')

					if not pose.ignore then
						TweakDB:SetFlat('PhotoModePoses.'..pose.pose_name..'.poseStateConfig', 'POSE_STATE_GROUND_AND_AIR')
					end
				end
			end
		end)
	 end

	 -- Keybinds
	 registerInput("amm_open_overlay", "Open Appearance Menu", function(down)
		if down then
	 		drawWindow = not drawWindow
		end
	 end)

	 registerInput("amm_cycle", "Cycle Appearance", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil then
				delayTimer = 0.0
				AMM.shouldCheckSavedAppearance = false
				buttonPressed = true
				AMM:ChangeScanAppearanceTo(target, 'Cycle')
			end
		end
	 end)

	 registerInput("amm_save", "Save Appearance", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil then
				AMM:SaveAppearance(target)
			end
		end
	 end)

	--  registerInput("amm_show_target_tools", "Show Target Tools", function(down)
 	-- 	AMM:ShowTargetTools()
	--  end)

	 registerInput("amm_clear", "Clear Appearance", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil then
				AMM:ClearSavedAppearance(target)
			end
		end
	 end)

	 registerInput("amm_spawn_favorite", "Spawn Favorite", function(down)
		if down then AMM.Spawn:SpawnFavorite() end
	 end)

	 registerInput("amm_spawn_target", "Spawn Target", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsNPC() then
				local spawnableID = AMM:IsSpawnable(target)

				if spawnableID ~= nil then

					local spawn = nil
					for ent in db:nrows(f("SELECT * FROM entities WHERE entity_id = '%s'", spawnableID)) do
						spawn = AMM.Spawn:NewSpawn(ent.entity_name, ent.entity_id, ent.entity_parameters, ent.can_be_comp, ent.entity_path, ent.template_path, ent.entity_rig)
					end

					if spawn ~= nil then
						target.handle:Dispose()
						AMM.Spawn:SpawnNPC(spawn)
					end
				end
			end
		end
	 end)

	 registerInput("amm_despawn_target", "Despawn Target", function(down)
		if down then
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
		end
	 end)

	 registerInput("amm_pickup_target", "Pick Up Target", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil then
				AMM.Tools:PickupTarget(target)
			elseif AMM.Tools.holdingNPC then
				AMM.Tools:PickupTarget()
			end
		end
	 end)

	 registerInput("amm_respawn_all", "Respawn All", function(down)
		if down then
			buttonPressed = true
			AMM:RespawnAll()
		end
	 end)

	 registerInput("amm_toggle_companions", "Toggle Companions", function(down)
		if down and next(AMM.Spawn.spawnedNPCs) ~= nil then
			for _, spawn in pairs(AMM.Spawn.spawnedNPCs) do
				Util:ToggleCompanion(spawn)
			end
		end
	 end)

	 registerInput("amm_toggle_vehicle_camera", "Toggle Vehicle Camera", function(down)
		if down then
			local qm = AMM.player:GetQuickSlotsManager()
			mountedVehicle = qm:GetVehicleObject()
			if AMM.Scan.companionDriver and mountedVehicle then
				AMM.Scan:ToggleVehicleCamera()
			end
		end
	 end)

	 registerInput("amm_toggle_station", "Toggle Radio", function(down)
		if down then
			local qm = AMM.player:GetQuickSlotsManager()
			mountedVehicle = qm:GetVehicleObject()
			if mountedVehicle then
				mountedVehicle:ToggleRadioReceiver(not mountedVehicle:IsRadioReceiverActive())
			end
		end
	 end)

	 registerInput("amm_next_station", "Next Radio Station", function(down)
		if down then
			local qm = AMM.player:GetQuickSlotsManager()
			mountedVehicle = qm:GetVehicleObject()
			if mountedVehicle and mountedVehicle:IsRadioReceiverActive() then
				mountedVehicle:NextRadioReceiverStation()
			end
		end
	 end)

	 registerInput("amm_repair_vehicle", "Repair Vehicle", function(down)
		if down then
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
		end
	 end)

	 registerInput("amm_toggle_doors", "Toggle Doors", function(down)
		if down then
			local handle
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsVehicle() then
				handle = target.handle
			else
				local qm = AMM.player:GetQuickSlotsManager()
				handle = qm:GetVehicleObject()
			end
	
			if handle ~= nil then
				Util:ToggleDoors(handle)
			end
		end
  	 end)

	registerInput("amm_toggle_windows", "Toggle Windows", function(down)
		if down then
			local handle
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsVehicle() then
				 handle = target.handle
			else
				 local qm = AMM.player:GetQuickSlotsManager()
				 handle = qm:GetVehicleObject()
			end
	  
			if handle ~= nil then
				 Util:ToggleWindows(handle)
			end
		end
	  end)

	  
	registerInput("amm_toggle_engine", "Toggle Engine", function(down)
		if down then
			local handle
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsVehicle() then
				handle = target.handle
			else
				local qm = AMM.player:GetQuickSlotsManager()
				handle = qm:GetVehicleObject()
			end
	
			if handle ~= nil then
				Util:ToggleEngine(handle)
			end
		end
  	 end)
  
	local SEAT_FRONT_LEFT = 1
	local SEAT_FRONT_RIGHT = 2
	local SEAT_BACK_LEFT = 3
	local SEAT_BACK_RIGHT = 4
	
	-- Toggle Front Left Door
	registerInput("amm_toggle_front_left_door", "Toggle Front Left Door", function(down)
		if down then
			local handle
			local target = AMM:GetTarget()
			if target and target.handle:IsVehicle() then
				handle = target.handle
			else
				local qm = AMM.player:GetQuickSlotsManager()
				handle = qm:GetVehicleObject()
			end
	
			if handle then
				local seat = AMM.Scan.possibleSeats[SEAT_FRONT_LEFT]  -- Index 1
				if Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName'](handle, CName.new(seat.cname)) then
					local doorState = Util:GetDoorState(handle, seat.enum)
					Util:ToggleDoor(handle:GetVehiclePS(), seat.cname, doorState)
				else
					log("This vehicle does not have a Front Left door.")
				end
			else
				log("No vehicle handle found.")
			end
		end
	end)
	
	-- Toggle Front Right Door
	registerInput("amm_toggle_front_right_door", "Toggle Front Right Door", function(down)
		if down then
			local handle
			local target = AMM:GetTarget()
			if target and target.handle:IsVehicle() then
				handle = target.handle
			else
				local qm = AMM.player:GetQuickSlotsManager()
				handle = qm:GetVehicleObject()
			end
	
			if handle then
				local seat = AMM.Scan.possibleSeats[SEAT_FRONT_RIGHT]  -- Index 2
				if Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName'](handle, CName.new(seat.cname)) then
					local doorState = Util:GetDoorState(handle, seat.enum)
					Util:ToggleDoor(handle:GetVehiclePS(), seat.cname, doorState)
				else
					log("This vehicle does not have a Front Right door.")
				end
			else
				log("No vehicle handle found.")
			end
		end
	end)
	
	-- Toggle Back Left Door
	registerInput("amm_toggle_back_left_door", "Toggle Back Left Door", function(down)
		if down then
			local handle
			local target = AMM:GetTarget()
			if target and target.handle:IsVehicle() then
				handle = target.handle
			else
				local qm = AMM.player:GetQuickSlotsManager()
				handle = qm:GetVehicleObject()
			end
	
			if handle then
				local seat = AMM.Scan.possibleSeats[SEAT_BACK_LEFT]  -- Index 3
				if Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName'](handle, CName.new(seat.cname)) then
					local doorState = Util:GetDoorState(handle, seat.enum)
					Util:ToggleDoor(handle:GetVehiclePS(), seat.cname, doorState)
				else
					log("This vehicle does not have a Back Left door.")
				end
			else
				log("No vehicle handle found.")
			end
		end
	end)
	
	-- Toggle Back Right Door
	registerInput("amm_toggle_back_right_door", "Toggle Back Right Door", function(down)
		if down then
			local handle
			local target = AMM:GetTarget()
			if target and target.handle:IsVehicle() then
				handle = target.handle
			else
				local qm = AMM.player:GetQuickSlotsManager()
				handle = qm:GetVehicleObject()
			end
	
			if handle then
				local seat = AMM.Scan.possibleSeats[SEAT_BACK_RIGHT]  -- Index 4
				if Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName'](handle, CName.new(seat.cname)) then
					local doorState = Util:GetDoorState(handle, seat.enum)
					Util:ToggleDoor(handle:GetVehiclePS(), seat.cname, doorState)
				else
					log("This vehicle does not have a Back Right door.")
				end
			else
				log("No vehicle handle found.")
			end
		end
	end)
  

	 registerInput("amm_last_expression", "Last Expression Used", function(down)
		if down then
			local target = AMM:GetTarget()
			if Tools.lockTarget and Tools.currentTarget and Tools.currentTarget ~= '' and Tools.currentTarget.handle
			and Tools.currentTarget.type ~= 'entEntity' and Tools.currentTarget.type ~= 'gameObject' then
				target = Tools.currentTarget
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
		end
	 end)

	 registerInput("amm_npc_talk", "NPC Talk", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsNPC() then
				Util:NPCTalk(target.handle)
			end
		end
	 end)

	 registerInput("amm_npc_move_to_v", "NPC Move To V", function(down)
		if down and next(AMM.Spawn.spawnedNPCs) ~= nil then
			for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
				if ent.handle:IsNPC() and ent.handle.isPlayerCompanionCached then
					local pos = AMM.player:GetWorldPosition()
					local heading = AMM.player:GetWorldForward()
					local frontPlayer = Vector4.new(pos.x + heading.x, pos.y + heading.y, pos.z, pos.w)
					Util:MoveTo(ent.handle, frontPlayer)
				end
			end
		end
	 end)

	 registerInput("amm_npc_move", "NPC Move To Position", function(down)
		if down and next(AMM.Spawn.spawnedNPCs) ~= nil then
			local spatialQuery = Game.GetSpatialQueriesSystem()
			local cameraSystem = Game.GetCameraSystem()
			local playerPos = Game.GetPlayer():GetWorldPosition()
			playerPos = Vector4.new(playerPos.x, playerPos.y, playerPos.z + 1.7, playerPos.w)
			local heading = Vector4.Normalize(cameraSystem:GetActiveCameraForward())
			local point = Vector4.new(playerPos.x + (heading.x * 100), playerPos.y + (heading.y * 100), playerPos.z + (heading.z * 100), playerPos.w)

			local collision, result = spatialQuery:SyncRaycastByCollisionGroup(playerPos, point, "Static", true, true)
			local pos = Vector4.new(result.position.x, result.position.y, result.position.z, 1)

			if collision then
				for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
					if ent.handle:IsNPC() and ent.handle.isPlayerCompanionCached then
						Util:MoveTo(ent.handle, pos)
						local mappinID = Util:SetMarkerAtPosition(pos)

						Cron.After(2, function()
							Game.GetMappinSystem():UnregisterMappin(mappinID)
						end)
					end
				end
			end
		end
	 end)

	 registerInput("amm_npc_attack", "NPC Attack Target", function(down)
		if down and next(AMM.Spawn.spawnedNPCs) ~= nil then
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsNPC() then
				for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
					Util:TriggerCombatAgainst(ent.handle, target.handle)
				end
			end
		end
	 end)

	 registerInput("amm_npc_hold", "NPC Hold Position", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsNPC() then
				Util:HoldPosition(target.handle)
			end
		end
	 end)

	 registerInput("amm_npc_all_hold", "All Hold Position", function(down)
		if down then
			if next(AMM.Spawn.spawnedNPCs) ~= nil then
				for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
					Util:HoldPosition(ent.handle, 10)
				end
			end
		end
	 end)

	 registerInput("amm_give_weapon", "Give Weapon", function(down)
		if down then
			local target = AMM:GetTarget()
			if not target then target = AMM.currentTarget end
			if target ~= nil and target.handle:IsNPC() then
				local weapon = Util:GetPlayerWeapon()

				if weapon then
					local weaponTDBID = weapon:GetItemID().tdbid
					Util:EquipGivenWeapon(target.handle, weaponTDBID, AMM.Tools.forceWeapon)
					AMM:ResetFollowCommandAfterAction(target, function(handle)
						Util:EquipPrimaryWeaponCommand(handle)
					end)
				end
			end
		end
	 end)

	 registerInput("amm_slow_time", "Slow Time", function(down)
		if down then
			AMM.Tools.slowMotionToggle = not AMM.Tools.slowMotionToggle
			if AMM.Tools.slowMotionToggle then
				AMM.Tools:SetSlowMotionSpeed(0.1)
			else
				AMM.Tools:SetSlowMotionSpeed(0.0)
			end
		end
	 end)

	 registerInput("amm_freeze_time", "Freeze Time", function(down)
	 	if down then AMM.Tools:FreezeTime() end
	 end)

	 registerInput("amm_skip_frame", "Skip Frame", function(down)
	 	if down then AMM.Tools:SkipFrame() end
	 end)

	 registerInput("amm_freeze_target", "Freeze Target", function(down)
		if down then
			local target = AMM:GetTarget()
			if target ~= nil and target.handle:IsNPC() then
				local frozen = not(AMM.Tools.frozenNPCs[tostring(target.handle:GetEntityID().hash)] == true)
				AMM.Tools:FreezeNPC(target.handle, frozen)
			end
		end
	end)

	registerInput("amm_pm_disable_cursor", "Disable Photo Mode Cursor", function(down)		
		if down then AMM.Tools:ToggleCursor() end
	end)

	 registerInput("amm_toggle_lookAt", "Toggle Photo Mode Look At Camera", function(down)
	 	if down then AMM.Tools:ToggleLookAt() end
	 end)

	 registerInput('amm_toggle_head', 'Toggle V Head', function(down)
		if down then AMM.Tools:ToggleHead() end
	 end)

	 registerInput("amm_toggle_tpp", "Toggle TPP Camera", function(down)
		if down then AMM.Tools:ToggleTPPCamera() end
	 end)

	 registerInput("amm_toggle_god", "Toggle God Mode", function(down)
		if down then AMM.Tools:ToggleGodMode() end
	 end)

	registerInput("amm_toggle_build", "Toggle Build Mode", function(down)
		if down then AMM.Props:ToggleBuildMode() end
	end)

	registerInput("amm_toggle_direct", "Toggle Direct Mode", function(down)
		if down then AMM.Tools:ToggleDirectMode(true) end
	end)

	registerInput("amm_toggle_lights", "Toggle All Decor Lights", function(down)
		if down then AMM.Props:ToggleAllActiveLights() end
	 end)

	 registerInput('amm_toggle_hud', 'Toggle HUD', function(down)
		if down then
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
			GameSettings.Toggle('/interface/hud/crouch_indicator')
			GameSettings.Toggle('/interface/hud/hud_markers')
		end
	 end)

	 for i = 1, 3 do
		 registerInput(f('amm_appearance_hotkey%i', i), f('Appearance Hotkey %i', i), function(down)
			if down then
				local target = AMM:GetTarget()
		 		if target ~= nil and AMM.selectedHotkeys[target.id][i] ~= '' then
		 			delayTimer = 0.0
		 			AMM.shouldCheckSavedAppearance = false
		 			buttonPressed = true
		 			AMM:ChangeAppearanceTo(target, AMM.selectedHotkeys[target.id][i])
		 		end
			end
		 end)
	 end

	 registerInput("amm_new_camera", "Spawn New Camera", function(down)
		if down then
			if AMM.Director.activeCamera then
				AMM.Director.activeCamera:Deactivate(1)
				AMM.Director.activeCamera = nil
			else
				local camera = AMM.Camera:new()
				camera:Spawn()
				camera:StartListeners()

				AMM.Director.activeCamera = camera
				table.insert(AMM.Director.cameras, camera)

				Cron.Every(0.1, function(timer)
					if AMM.Director.activeCamera.handle then
						AMM.Director.activeCamera:Activate(1)
						Cron.Halt(timer)
					end
				end)
			end
		end
	 end)

	 registerInput("amm_despawn_camera", "Despawn Active Camera", function(down)
		if down then AMM.Director:DespawnActiveCamera() end
	 end)

	 registerInput("amm_toggle_camera", "Toggle Active Camera", function(down)
		if down then AMM.Director:ToggleActiveCamera() end
	 end)

	 registerInput("amm_increase_fov_camera", "Increase Active Camera FOV", function(down)
		if down then AMM.Director:AdjustActiveCameraFOV(1) end
	 end)

	 registerInput("amm_decrease_fov_camera", "Decrease Active Camera FOV", function(down)
		if down then AMM.Director:AdjustActiveCameraFOV(-1) end
	 end)

	 registerInput("amm_increase_zoom_camera", "Increase Active Camera Zoom", function(down)
		if down then AMM.Director:AdjustActiveCameraZoom(1) end
	 end)

	 registerInput("amm_decrease_zoom_camera", "Decrease Active Camera Zoom", function(down)
		if down then AMM.Director:AdjustActiveCameraZoom(-1) end
	 end)

	 local frameCounter = 0

	 registerForEvent("onUpdate", function(deltaTime)
		 AMM.deltaTime = deltaTime

		 -- Setup Travel Mod API --
		 local mod = GetMod("gtaTravel")
		 if mod ~= nil and AMM.TeleportMod == nil then
			 AMM.TeleportMod = mod
			 AMM.Tools.useTeleportAnimation = AMM.userSettings.teleportAnimation
		 end

		 -- This is required for Cron to function
     	Cron.Update(deltaTime)

		 if AMM.playerAttached and (not(AMM.playerInMenu) or AMM.playerInPhoto) then

				frameCounter = frameCounter + 1

				if frameCounter >= 2 then
					AMM.currentTarget = AMM:GetTarget()
					frameCounter = 0
					
					if not AMM.archivesInfo.missing and finishedUpdate and AMM.player ~= nil then
						-- Check Custom Defaults --
						local target = AMM.currentTarget
						AMM:CheckCustomDefaults(target)
							-- Load Saved Appearance --
						if not drawWindow and AMM.shouldCheckSavedAppearance then
							local count = 0
							for x in db:urows("SELECT COUNT(1) FROM saved_appearances UNION ALL SELECT COUNT(1) FROM blacklist_appearances") do
								count = count + x
								break
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
					end


					-- Trigger Sensing Check --
					if not drawWindow and AMM.playerAttached then
						AMM.Director:SenseNPCTalk()
						AMM.Director:SenseTriggers()
						AMM.Scan:SenseSavedDespawns()

						local playerPos = Game.GetPlayer():GetWorldPosition()
						local playerPosChanged = Util:PlayerPositionChangedSignificantly(playerPos)

						AMM:SenseSBTriggers()

						if playerPosChanged then
							AMM.Props:SensePropsTriggers()
							AMM.Scan:SenseAppTriggers()
						end
					end
				end

				-- Freeze Player while Decor preset is loading
				if AMM.Props.presetLoadInProgress then
					Util:FreezePlayer()

					Cron.After(5, function()
						AMM.Props.presetLoadInProgress = false
						Util:RemovePlayerEffects()
					end)
				end

				-- Camera Movement --
				if AMM.Director.activeCamera then
					AMM.Director.activeCamera:Move()
				end

				-- Light Movement --
				if AMM.Light.stickyMode and AMM.Light.activeLight and AMM.Light.activeLight.isAMMLight then
					AMM.Light.activeLight:Move()
					AMM.Light.camera:Move()
				end

				-- Entity Movement --
				if AMM.Tools.directMode and AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '' then
					AMM.Tools.currentTarget:Move()
				end

				-- Disable Photo Mode Restriction --
				if AMM.userSettings.photoModeEnhancements then
					if StatusEffectSystem.ObjectHasStatusEffectWithTag(Game.GetPlayer(), 'NoPhotoMode') then
						Util:RemoveEffectOnPlayer('GameplayRestriction.NoPhotoMode')
					end
				end

				-- Check if Locked Target is gone --
				if Tools.lockTarget then
					if Tools.currentTarget.handle and Tools.currentTarget.handle ~= '' then
						local ent = Game.FindEntityByID(Tools.currentTarget.handle:GetEntityID())
						if not ent or (not Tools.currentTarget.spawned and Tools.currentTarget.type == 'entEntity') 
						or (Tools.currentTarget.type == 'Player' and not AMM.playerInPhoto) then
							Tools:ClearTarget()
						end
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
			end
	 end)

	 registerForEvent("onOverlayOpen", function()
		 if AMM.userSettings.openWithOverlay then drawWindow = true end

		 if drawWindow and AMM.playerAttached then
			Util.playerLastPos = ''
			AMM.savedAppearanceCheckCache = {}
		 end

		 -- Toggle Marker With AMM Window --
		 AMM.Tools:ToggleLookAtMarker(drawWindow)

		 -- Toggle Axis Indicator --
		 if not AMM.Tools.axisIndicator and AMM.Tools.axisIndicatorToggle 
		 and AMM.Tools.currentTarget ~= '' and AMM.Tools.currentTarget.handle then
			AMM.Tools:ToggleAxisIndicator()
		end

		 -- Update Tools Locations --
		 -- This causes stutters if the user has too many locations installed
		 -- AMM.Tools.locations = AMM.Tools:GetLocations()

		 -- Update Presets List --
		 AMM.Props.presets = AMM.Props:LoadPresets()
	 end)

	 registerForEvent("onOverlayClose", function()
		 drawWindow = false

		 -- Toggle Marker With AMM Window --
		 AMM.Tools:ToggleLookAtMarker(drawWindow)

		 -- Toggle Axis Indicator --
		 if AMM.Tools.axisIndicator and AMM.Tools.axisIndicatorToggle then
			AMM.Director.wasPopupOpen_MoveMark = false
		 	AMM.Tools:ToggleAxisIndicator()
		 end

		 -- Backup Decor Preset if active --
		--  if AMM.Props.activePreset ~= '' then
		--  	AMM.Props:BackupPreset(AMM.Props.activePreset)
		--  end
	 end)

	 registerForEvent("onDraw", function()

	 	ImGui.SetNextWindowPos(500, 500, ImGuiCond.FirstUseEver)

		if drawWindow or AMM.Props.buildMode then
			-- Load Theme --
			if AMM.UI.currentTheme ~= AMM.selectedTheme then
				AMM.UI:Load(AMM.selectedTheme)
				AMM:UpdateSettings()
			end

			AMM.UI:Start()
		end

	 	if drawWindow then
			AMM:Begin()
	 	end

		if AMM.Props.buildMode then
			AMM.Scan:DrawMinimalUI()
		end

		if drawWindow or AMM.Props.buildMode then
			AMM.UI:End()
		end
	end)

   return AMM
end

-- Table to cache strings that have already been logged
local loggedStrings = {}

function AMM.LocalizableString(str)
    -- If localized, return immediately.
    if AMM.currentLanguage[str] then
        return AMM.currentLanguage[str]
    end

    -- Check for nil and empty strings; log them only once.
    if str == nil then
        if not loggedStrings["nil"] then
            loggedStrings["nil"] = true
            log("[AMM Debug] The string is nil")
        end
        return "AMM_ERROR"
    elseif str == "" then
        if not loggedStrings["empty"] then
            loggedStrings["empty"] = true
            log("[AMM Debug] The string is an empty string ('')")
        end
        return "AMM_ERROR"
    end

    -- Log non-localized strings only once.
    if not loggedStrings[str] then
        loggedStrings[str] = true
        log("[AMM Error] Non-localized string found: " .. str)
    end

    return "AMM_ERROR"
end

function AMM:InitializeModules()
	AMM.Scan:Initialize()
	AMM.Tools:Initialize()
	AMM.Director:Initialize()
end

-- Running On Draw
function AMM:Begin()
	local shouldResize = ImGuiWindowFlags.AlwaysAutoResize
	if not(AMM.userSettings.autoResizing) then
		shouldResize = ImGuiWindowFlags.None
	end

	local archives = AMM.archivesInfo

	if ImGui.Begin("Appearance Menu Mod", shouldResize + ImGuiWindowFlags.NoScrollbar) then

		if archives.missing and not archives.optional then
			AMM:DrawArchives()
		else
			if (not(finishedUpdate) or AMM.playerAttached == false) then

				if archives.missing then
					AMM:DrawArchives()
				else
					local notes = AMM.updateNotes

					if finishedUpdate and AMM.playerAttached == false then
						if initializationComplete == false then
							AMM.UI:TextColored(AMM.LocalizableString("Warn_InitError"))
							ImGui.Text(AMM.LocalizableString("Warn_InitError_Info"))
						else
							AMM.UI:TextColored(AMM.LocalizableString("Warn_PlayerInMenu"))
							ImGui.Text(AMM.LocalizableString("Warn_AMMonlyfunctions_ingame"))
						end

						if AMM.updateLabel ~= AMM.LocalizableString("CREDITS") then
							AMM.updateLabel = AMM.LocalizableString("UPDATE_HISTORY")
							notes = AMM.updateNotes
						else
							notes = AMM.credits
						end

						ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(AMM.LocalizableString("Updates")))

						local buttonLabel = AMM.LocalizableString("Button_Credits")
						if AMM.updateLabel == AMM.LocalizableString("CREDITS") then
							buttonLabel = AMM.LocalizableString("Updates")
						end
						if ImGui.SmallButton(buttonLabel) then
							if AMM.updateLabel == AMM.LocalizableString("CREDITS") then
								AMM.updateLabel = AMM.LocalizableString("UPDATE_HISTORY")
							else
								AMM.updateLabel = AMM.LocalizableString("CREDITS")
							end
						end

						AMM.UI:Separator()
					end

					-- UPDATE NOTES
					AMM.UI:Spacing(4)
					AMM.UI:TextCenter(AMM.updateLabel, true)
					if AMM.updateLabel == AMM.LocalizableString("WHATS_NEW") then
						ImGui.Spacing()
						AMM.UI:TextCenter(AMM.currentVersion, false)
					end
					AMM.UI:Separator()

					if not(finishedUpdate) then
						AMM.UI:Spacing(2)
						if ImGui.Button(AMM.LocalizableString("Button_Cool"), ImGui.GetWindowContentRegionWidth(), 40) then
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
										AMM.UI:Spacing(2)
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
									ImGui.Spacing()
								end
							end

							ImGui.Spacing()
							ImGui.TreePop()
						end
					end
				end
			else
				-- Target Setup --
				local target = AMM.currentTarget

				if ImGui.BeginTabBar("TABS") then
					-- Setup Style --
					AMM.UI.style.buttonWidth = -1
					AMM.UI.style.buttonHeight = ImGui.GetFontSize() * 2
					AMM.UI.style.halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)
					
					local style = AMM.UI.style

					-- Scan Tab --
					AMM.Scan:Draw(AMM, target, style)

					-- Spawn Tab --
					AMM.Spawn:Draw(AMM, style)

					-- Swap Tab --
					AMM.Swap:Draw(AMM, target)

					-- Props Tab --
					AMM.Props:Draw(AMM)

					-- Poses Tab --
					AMM.Poses:Draw(AMM, target)

					-- Tools Tab --
					AMM.Tools:Draw(AMM, target)

					-- Director Tab --
					AMM.Director:Draw(AMM)

					-- Settings Tab --
					if (ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameSettings"))) then

						-- Util Popup Helper --
						Util:SetupPopup()

						AMM.UI:Spacing(2)


						if ImGui.BeginTabBar("Settings Tabs") then

							AMM:DrawGeneralSettingsTab(style)
							AMM:DrawCompanionsSettingsTab(style)
							AMM:DrawUISettingsTab(style)
							AMM:DrawPhotoModeSettingsTab(style)
							AMM:DrawExperimentalSettingsTab(style)

							if AMM.CETVersion < 34 and Tools.replacer then
								if ImGui.BeginTabItem("Photo Mode Nibbles Replacer") then
									AMM.Tools.DrawNibblesReplacer()
									ImGui.EndTabItem()
								end
							end

							ImGui.EndTabBar()
						end			
						
						AMM.UI:Separator()

						local CETVersion = GetVersion()
						local CodewareVersion = Codeware.Version()

						ImGui.Text(AMM.LocalizableString("AMM_Version"))
						ImGui.SameLine()
						AMM.UI:TextColored(AMM.currentVersion)
						ImGui.SameLine()						
						ImGui.Text(AMM.LocalizableString("CET_Version"))
						ImGui.SameLine()
						AMM.UI:TextColored(CETVersion)
						ImGui.SameLine()						
						ImGui.Text(AMM.LocalizableString("Codeware_Version"))
						ImGui.SameLine()
						AMM.UI:TextColored(CodewareVersion)

						ImGui.SameLine()
						if ImGui.InvisibleButton(AMM.LocalizableString("Button_InvMachineGun"), 20, 30) then
							local popupInfo = {text = AMM.LocalizableString("Warn_InvButtonMachineGun_Info")}
							Util:OpenPopup(popupInfo)
							AMM.equipmentOptions = AMM:GetEquipmentOptions(true)
						end

						if ImGui.IsItemHovered() then
							ImGui.SetTooltip(AMM.LocalizableString("InvButtonTip2"))
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

	 if AMM.userSettings.floatingTargetTools and AMM.Tools.movementWindow.open and (target ~= nil or (AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '')) then
		AMM.Tools:DrawMovementWindow()
	 end
end

function AMM:DrawGeneralSettingsTab(style)
	if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameGeneral")) then
		local settingChanged = false
		
		AMM.userSettings.autoLock, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_LockTargetAfterSpawn"), AMM.userSettings.autoLock)
		if clicked then settingChanged = true end

		if AMM.userSettings.autoLock then
			AMM.userSettings.autoOpenTargetTools, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_OpenTargetToolsAfterSpawn"), AMM.userSettings.autoOpenTargetTools)
			if clicked then settingChanged = true end
		end

		AMM.userSettings.axisIndicatorByDefault, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_DisplayAxisIndicatorByDefault"), AMM.userSettings.axisIndicatorByDefault)
		if clicked then settingChanged = true end

		if AMM.CETVersion >= 18 then
			AMM.userSettings.photoModeEnhancements, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_PhotoModeEnhancements"), AMM.userSettings.photoModeEnhancements)
			if clicked then settingChanged = true end
		end

		AMM.userSettings.godModeOnLaunch, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_GodModeOnLaunch"), AMM.userSettings.godModeOnLaunch)
		if clicked then settingChanged = true end

		AMM.userSettings.passiveModeOnLaunch, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_PassiveModeOnLaunch"), AMM.userSettings.passiveModeOnLaunch)
		if clicked then settingChanged = true end

		AMM.userSettings.streamerMode, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_StreamerMode"), AMM.userSettings.streamerMode)
		if clicked then settingChanged = true end

		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(AMM.LocalizableString("Warn_BannedWords_Info"))
		end

		if settingChanged then AMM:UpdateSettings() end

		AMM.UI:Spacing(3)

		AMM.UI:TextColored(AMM.LocalizableString("SavedAppearancesHotkeys"))

		local target = AMM.currentTarget
		if target ~= nil and (target.type == "NPCPuppet" or target.type == "vehicle") then
			AMM:DrawHotkeySelection(target)
		else
			AMM.UI:Spacing(3)
			AMM.UI:TextCenter(AMM.LocalizableString("Warn_TargetNpcVehicleHotkey"))
		end	

		AMM.UI:Separator()

		if AMM.userSettings.experimental then
			if ImGui.Button(AMM.LocalizableString("Button_RevertAllModelSwaps"), style.halfButtonWidth, style.buttonHeight) then
				AMM:RevertTweakDBChanges(true)
			end

			ImGui.SameLine()
			if ImGui.Button(AMM.LocalizableString("Button_RespawnAll"), style.halfButtonWidth, style.buttonHeight) then
				AMM:RespawnAll()
			end
		end


		if ImGui.Button(AMM.LocalizableString("Button_ForceDespawnAll"), style.halfButtonWidth, style.buttonHeight) then
			AMM:DespawnAll(true)
		end

		ImGui.SameLine()
		if ImGui.Button(AMM.LocalizableString("Button_ClearFavorites"), style.halfButtonWidth, style.buttonHeight) then
			popupDelegate = AMM:OpenPopup("Favorites")
		end

		if ImGui.Button(AMM.LocalizableString("Button_ClearAllSavedAppearances"), style.buttonWidth, style.buttonHeight) then
			popupDelegate = AMM:OpenPopup("Appearances")
		end

		if ImGui.Button(AMM.LocalizableString("Button_ClearAllBlacklistedAppearances"), style.buttonWidth, style.buttonHeight) then
			popupDelegate = AMM:OpenPopup("Blacklist")
		end

		if ImGui.Button(AMM.LocalizableString("Button_ClearAllAppearanceTriggers"), style.buttonWidth, style.buttonHeight) then
			popupDelegate = AMM:OpenPopup("Appearance Triggers")
		end

		if AMM.userSettings.experimental then
			if ImGui.Button(AMM.LocalizableString("Button_ClearAllSavedDespawns"), style.buttonWidth, style.buttonHeight) then
				popupDelegate = AMM:OpenPopup("Saved Despawns")
			end
		end

		if ImGui.Button(AMM.LocalizableString("Button_ReloadAppearances"), style.buttonWidth, style.buttonHeight) then
			AMM:ReloadCustomAppearances()
		end

		AMM:BeginPopup(AMM.LocalizableString("Warning"), nil, true, popupDelegate, style)
		ImGui.EndTabItem()
  end
end

function AMM:DrawCompanionsSettingsTab(style)
	if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameCompanions")) then
		local settingChanged = false
		AMM.userSettings.spawnAsCompanion, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_SpawnAsCompanion"), AMM.userSettings.spawnAsCompanion)
		if clicked then settingChanged = true end

		if not AMM.userSettings.spawnAsCompanion then
			AMM.userSettings.spawnAsFriendly, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_SpawnAsFriendly"), AMM.userSettings.spawnAsFriendly)
			if clicked then settingChanged = true end
		end

		AMM.userSettings.isCompanionInvulnerable, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_InvulnerableCompanion"), AMM.userSettings.isCompanionInvulnerable)
		if clicked then
			settingChanged = true
			AMM:RespawnAll()
		end

		AMM.userSettings.respawnOnLaunch, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_RespawnOnLaunch"), AMM.userSettings.respawnOnLaunch)
		if clicked then settingChanged = true end

		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(AMM.LocalizableString("Warn_RespawnOnLaunch_Info"))
		end

		if settingChanged then AMM:UpdateSettings() end

		AMM.UI:TextColored(AMM.LocalizableString("Companion_Damage"))

		ImGui.PushItemWidth(200)
		AMM.companionAttackMultiplier = ImGui.InputFloat(AMM.LocalizableString("xDamage").."##attack", AMM.companionAttackMultiplier, 0.5, 50, "%.1f")
		if AMM.companionAttackMultiplier < 0 then AMM.companionAttackMultiplier = 0 end
		ImGui.PopItemWidth()

		AMM.UI:Spacing(3)

		AMM.UI:TextColored(AMM.LocalizableString("Companion_Resistance"))

		ImGui.PushItemWidth(200)
		AMM.companionResistanceMultiplier = ImGui.InputFloat(AMM.LocalizableString("xResistance").."##resist", AMM.companionResistanceMultiplier, 0.5, 50, "%.1f")
		if AMM.companionResistanceMultiplier < 0 then AMM.companionResistanceMultiplier = 0 end
		if AMM.companionResistanceMultiplier > 100 then AMM.companionResistanceMultiplier = 100 end
		ImGui.PopItemWidth()

		AMM.UI:Spacing(3)

		AMM.UI:TextColored(AMM.LocalizableString("Companion_Distance"))

		for _, option in ipairs(AMM.followDistanceOptions) do
			if ImGui.RadioButton(option[1], AMM.followDistance[1] == option[1]) then
				AMM.followDistance = option
				AMM:UpdateFollowDistance()
			end

			ImGui.SameLine()
		end

		AMM.UI:Spacing(3)

		ImGui.EndTabItem()
  end
end

function AMM:DrawUISettingsTab(style)
	if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameUI")) then
		local settingsChanged = false
		
		AMM.userSettings.openWithOverlay, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_OpenWCETOverlay"), AMM.userSettings.openWithOverlay)
		if clicked then settingChanged = true end

		AMM.userSettings.autoResizing, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_AutoResizingWindow"), AMM.userSettings.autoResizing)
		if clicked then settingChanged = true end

		AMM.userSettings.scanningReticle, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_ScanningReticle"), AMM.userSettings.scanningReticle)
		if clicked then settingChanged = true end

		AMM.userSettings.floatingTargetTools, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_FloatingTargetTools"), AMM.userSettings.floatingTargetTools)
		if clicked then settingChanged = true end

		AMM.userSettings.tabDescriptions, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_TabHeaderDescriptions"), AMM.userSettings.tabDescriptions)
		if clicked then settingChanged = true end

		AMM.userSettings.favoritesDefaultOpen, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_ExpandFavoritesByDefault"), AMM.userSettings.favoritesDefaultOpen)
		if clicked then settingChanged = true end

		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(AMM.LocalizableString("Warn_FirstLaunchDecideTabsExpand_Info"))
		end

		AMM.userSettings.scrollBarEnabled, scrollBarClicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_EnableScrollBars"), AMM.userSettings.scrollBarEnabled)

		if scrollBarClicked then
			settingChanged = true
			if AMM.userSettings.scrollBarEnabled then
				AMM.UI.style.scrollBarSize = 10
			else
				AMM.UI.style.scrollBarSize = 0
			end
		end

		AMM.UI.style.listScaleFactor, used = ImGui.SliderFloat(AMM.LocalizableString("List_Height"), AMM.UI.style.listScaleFactor, -2, 2, "%.1f")


		if #AMM.availableLanguages > 1 then
			AMM.UI:Spacing(3)

			AMM.UI:TextColored(AMM.LocalizableString("Interface_Language"))

			local selectedLanguage = AMM.availableLanguages[AMM.selectedLanguage]
			if ImGui.BeginCombo(" ##Interface Language", selectedLanguage.name) then
				for i, lang in ipairs(AMM.availableLanguages) do
					if ImGui.Selectable(lang.name.."##"..i, (lang == selectedLanguage.name)) then
						AMM.selectedLanguage = i
						AMM.currentLanguage = lang.strings
						AMM:InitializeModules()
						AMM:UpdateSettings()
					end
				end
				ImGui.EndCombo()
			end
		end

		AMM.UI:Spacing(3)

		AMM.UI:TextColored(AMM.LocalizableString("Custom_Appearances"))

		for _, option in ipairs(AMM.customAppOptions) do
			if ImGui.RadioButton(option, AMM.customAppPosition == option) then
				AMM.customAppPosition = option
				AMM.cachedAppearanceOptions = {}
			end

			ImGui.SameLine()
		end

		if settingChanged then AMM:UpdateSettings() end

		AMM.UI:Separator()

		if AMM.settings then
			if ImGui.BeginListBox(AMM.LocalizableString("Listbox_Themes")) then
				for _, theme in ipairs(AMM.UI.userThemes) do
					if (AMM.selectedTheme == theme.name) then selected = true else selected = false end
					if(ImGui.Selectable(theme.name, selected)) then
						AMM.selectedTheme = theme.name
					end
				end
				ImGui.EndListBox()
			end

			if ImGui.SmallButton(AMM.LocalizableString("Button_SmallCreateTheme")) then
				AMM.Editor:Setup()
				AMM.Editor.isEditing = true
			end

			ImGui.SameLine()
			if ImGui.SmallButton("  Delete Theme  ") then
				AMM.UI:DeleteTheme(AMM.selectedTheme)
				AMM.selectedTheme = "Default"
			end
		end

		ImGui.EndTabItem()
	end
end

function AMM:DrawPhotoModeSettingsTab(style)
	if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNamePhotoMode")) then

		local settingsChanged = false

		AMM.UI:TextColored(AMM.LocalizableString("PhotoModeAdjustments"))
		AMM.userSettings.disablePhotoModeCursor, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_AlwaysDisablePhotoModeCursor"), AMM.userSettings.disablePhotoModeCursor)
		if clicked then settingChanged = true end

		AMM.userSettings.resetPositionTargetPhotoMode, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_ResetTargetPositionPM"), AMM.userSettings.resetPositionTargetPhotoMode)
		if clicked then settingsChanged = true end

		AMM.UI:Spacing(3)

		AMM.UI:TextColored(AMM.LocalizableString("DisablePhotoModeTabs"))
		AMM.userSettings.disableCameraTab, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_Camera"), AMM.userSettings.disableCameraTab)
		if clicked then settingChanged = true end

		ImGui.SameLine()

		AMM.userSettings.disableDOFTab, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_DepthOfField"), AMM.userSettings.disableDOFTab)
		if clicked then settingChanged = true end

		ImGui.SameLine()

		AMM.userSettings.disableEffectTab, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_Effect"), AMM.userSettings.disableEffectTab)
		if clicked then settingChanged = true end

		ImGui.SameLine()

		AMM.userSettings.disableStickersTab, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_Stickers"), AMM.userSettings.disableStickersTab)
		if clicked then settingChanged = true end

		ImGui.SameLine()

		AMM.userSettings.disableLoadSaveTab, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_LoadSave"), AMM.userSettings.disableLoadSaveTab)
		if clicked then settingChanged = true end

		if settingChanged then AMM:UpdateSettings() end
		ImGui.EndTabItem()
	end
end

function AMM:DrawExperimentalSettingsTab(style)
	if ImGui.BeginTabItem(AMM.LocalizableString("BeginItem_TabNameExperimental")) then

		ImGui.TextWrapped(AMM.LocalizableString("Warn_ExperimentalTabDesc_Info"))

		local settingsChanged = false

		AMM.userSettings.experimental, expClicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_ExperimentalFunstuff"), AMM.userSettings.experimental)

		if AMM.userSettings.experimental then
			AMM.userSettings.freezeInPhoto, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_EnableFreezeTargetInPhotoMode"), AMM.userSettings.freezeInPhoto)
			if clicked then settingChanged = true end

			if ImGui.IsItemHovered() then
				ImGui.BeginTooltip()
				ImGui.PushTextWrapPos(500)
				ImGui.TextWrapped(AMM.LocalizableString("Warn_FreezeTargetPhotoMode_Info"))
				ImGui.PopTextWrapPos()
				ImGui.EndTooltip()
			end


			AMM.userSettings.weaponizeNPC, weapClicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_WeaponizeCompanions"), AMM.userSettings.weaponizeNPC)

			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(AMM.LocalizableString("Warn_WeaponizeCompanions_Info"))
			end

			AMM.userSettings.animPlayerSelfTarget, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_AllowPlayerToBeTargetedinPosestab"), AMM.userSettings.animPlayerSelfTarget)
			if clicked then settingChanged = true end

			AMM.userSettings.allowPlayerAnimationOnNPCs, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_AllowPlayerAnimationsonNPCs"), AMM.userSettings.allowPlayerAnimationOnNPCs)
			if clicked then settingChanged = true end

			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(AMM.LocalizableString("Warn_PlayerAnimsOnNpc_Info"))
			end

			AMM.userSettings.allowLookAtForNPCs, clicked = ImGui.Checkbox(AMM.LocalizableString("Checkbox_AllowExpressionOnNpcPM"), AMM.userSettings.allowLookAtForNPCs)
			if clicked then settingChanged = true end

			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(AMM.LocalizableString("Warn_UnpauseRequiresIGSC"))
			end
		end

		if expClicked then
			AMM:UpdateSettings()
			AMM.Spawn.categories = AMM.Spawn:GetCategories()

			if AMM.userSettings.experimental then
				popupDelegate = AMM:OpenPopup("Experimental")
			end
		end

		if weapClicked then
			settingChanged = true

			if AMM.userSettings.weaponizeNPC then
				popupDelegate = AMM:OpenPopup("Weaponize")
			end
		end

		if settingChanged then AMM:UpdateSettings() end
		ImGui.EndTabItem()
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

	obj.isPuppet = Util:CheckForPhotoComponent(handle)

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

	-- Check if target is Nibbles
	if obj.name == "Nibbles" or Util:CheckNibblesByID(obj.id) then
		if AMM.CETVersion < 34 and AMM.nibblesReplacer then
			local selectedEntity = AMM.Tools.nibblesEntityOptions[AMM.Tools.selectedNibblesEntity]
			if selectedEntity.ent then
				obj.name = "Replacer"
				obj.id = AMM:GetScanID(selectedEntity.ent)
				obj.options = AMM:GetAppearanceOptions(handle, obj.id)
				obj.type = "NPCPuppet"
			end
		else
			obj.name = "Nibbles"
			obj.type = "Player"
		end
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

	-- Check if object is current target
	if AMM.Tools.currentTarget and AMM.Tools.currentTarget ~= '' then
		if AMM.Tools.currentTarget.hash == obj.hash then
			AMM.Tools.currentTarget.options = obj.options
			obj = AMM.Tools.currentTarget
		end
	end

	-- Check if object is spawnedProp
	if next(AMM.Props.spawnedProps) ~= nil then
		for _, prop in pairs(AMM.Props.spawnedProps) do
			if prop.hash == obj.hash then
				obj = prop
				break
			end
		end
	end

	-- Check if object is activeProp
	if next(AMM.Props.cachedActivePropsByHash) ~= nil then
		if AMM.Props.cachedActivePropsByHash[obj.hash] then
			obj = AMM.Props.cachedActivePropsByHash[obj.hash]
			obj.options = AMM:GetAppearanceOptions(handle, obj.id)
		end
	end

	obj = Entity:new(obj)

	return obj
end

-- End Objects --

-- AMM Methods --
function AMM:SaveFileFromACM(filename, data)
	
	-- Open the file for writing
	local file = io.open("Collabs/Custom Appearances/"..filename, "w")

	if file then
		-- Write the Lua code to the file
		file:write(data)

		-- Close the file
		file:close()

		AMM:ReloadCustomAppearances()
	else
		log("[AMM Error] Unable to open the file for writing.")
	end
end

function AMM:ReloadCustomAppearances()
	db:execute("DELETE FROM custom_appearances WHERE collab_tag IS NOT NULL AND collab_tag != 'AMM'")
	AMM.collabs = AMM:SetupCollabAppearances()
	AMM.cachedAppearanceOptions = {}
end

function AMM:CheckMissingArchives()

	if AMM.CETVersion >= 18 then
		if AMM.archives == nil then
			AMM.archives = {
				{name = "basegame_AMM_Props", desc = AMM.LocalizableString("AMM_Props_Desc"), active = true, optional = false},
				{name = "basegame_johnny_companion", desc = AMM.LocalizableString("AMM_JohnnyCompanion_Desc"), active = true, optional = false},

				-- Optional Archives
				{name = "basegame_AMM_ScenesPack", desc = AMM.LocalizableString("AMM_ScenesPack_Desc"), active = true, optional = true, extra = true},
				{name = "basegame_AMM_SoundEffects", desc = AMM.LocalizableString("AMM_SoundPack_Desc"), active = true, optional = true},
				{name = "basegame_AMM_LizzyIncognito", desc = AMM.LocalizableString("AMM_LizzyIncognito_Desc"), active = true, optional = true},
				{name = "basegame_AMM_MeredithXtra", desc = AMM.LocalizableString("AMM_MeredithXtra_Desc"), active = true, optional = true},
				{name = "basegame_AMM_Delamain_Fix", desc = AMM.LocalizableString("AMM_DelamainFix_Desc"), active = true, optional = true},
				{name = "basegame_texture_HanakoNoMakeup", desc = AMM.LocalizableString("AMM_HanakoNoMakeup_Desc"), active = true, optional = true},
				{name = "basegame_AMM_JudyBodyRevamp", desc = AMM.LocalizableString("AMM_JudyBodyRevamp_Desc"), active = true, optional = true},
				{name = "basegame_AMM_PanamBodyRevamp", desc = AMM.LocalizableString("AMM_PanamBodyRevamp_Desc"), active = true, optional = true},
				{name = "basegame_AMM_MistyBodyRevamp", desc = AMM.LocalizableString("AMM_MistyBodyRevamp_Desc"), active = true, optional = true, extra = true},
				{name = "_1_Ves_HanakoFixedBodyNaked", desc = AMM.LocalizableString("AMM_1VesHanakoFixedBodyNaked_Desc"), active = true, optional = true},
				{name = "PinkyDude_ANIM_FacialExpressions_FemaleV", desc = AMM.LocalizableString("AMM_PinkyDudeANIMFacialExpressionsFemV_Desc"), active = true, optional = true},
				{name = "PinkyDude_ANIM_FacialExpressions_MaleV", desc = AMM.LocalizableString("AMM_PinkyDudeANIMFacialExpressionsMaleV_Desc"), active = true, optional = true},
				{name = "AMM_Dino_TattooFix", desc = AMM.LocalizableString("AMM_DinoTattooFixArchive_Desc"), active = true, optional = true},
				{name = "AMM_Songbird_BodyFix", desc = AMM.LocalizableString("AMM_SongbirdBodyFixArchive_Desc"), active = true, optional = true},
				{name = "AMM_RitaWheeler_CombatEnabler", desc = AMM.LocalizableString("AMM_RitaWheelerCombatEnablerArchive_Desc"), active = true, optional = true},
				{name = "basegame_AMM_KerryPP", desc = AMM.LocalizableString("AMM_KerryPP_Desc"), active = true, optional = true, extra = true},
				{name = "basegame_AMM_BenjaminStonePP", desc = AMM.LocalizableString("AMM_BenjaminStonePP_Desc"), active = true, optional = true, extra = true},
				{name = "basegame_AMM_RiverPP", desc = AMM.LocalizableString("AMM_RiverPP_Desc"), active = true, optional = true, extra = true},
				{name = "basegame_AMM_YorinobuPP", desc = AMM.LocalizableString("AMM_YorinobuPP_Desc"), active = true, optional = true, extra = true},
				{name = "AMM_Cheri_Appearances", desc = AMM.LocalizableString("AMM_CheriAppearances_Desc"), active = true, optional = true, extra = true},
				{name = "AMM_Bryce_Naked", desc = AMM.LocalizableString("AMM_BryceNaked_Desc"), active = true, optional = true, extra = true},
				{name = "AMM_Saburo_Appearances", desc = AMM.LocalizableString("AMM_SaburoAppearances_Desc"), active = true, optional = true, extra = true},
				{name = "AMM_TBug_Appearances", desc = AMM.LocalizableString("AMM_TbugAppearances_Desc"), active = true, optional = true, extra = true},
				{name = "AMM_8ug8ear_Appearances", desc = AMM.LocalizableString("AMM_8ug8eagAppearances_Desc"), active = true, optional = true, extra = true},
			}

			if #AMM.collabArchives > 0 then
				for _, archive in ipairs(AMM.collabArchives) do
					table.insert(AMM.archives, archive)
				end
			end

			for _, archive in ipairs(AMM.archives) do
				if not ModArchiveExists(archive.name..".archive") then
					archive.active = false

					if not archive.extra then
						AMM.archivesInfo.missing = true
					end

					if archive.name == "basegame_AMM_SoundEffects" then
						AMM.archivesInfo.sounds = false
					end

					if not archive.optional then AMM.archivesInfo.optional = false end
				end
			end
		end
	end

	if AMM.archivesInfo.missing then
		for v in db:urows("SELECT ignore_archives FROM metadata") do
			AMM.ignoreAllWarnings = intToBool(v)
		end

		if AMM.ignoreAllWarnings and AMM.archivesInfo.optional then
			AMM.archivesInfo = {missing = false, optional = true, sounds = AMM.archivesInfo.sounds}
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

	if AMM.playerAttached then
		AMM.Props:SensePropsTriggers()
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
				if userData['favoriteAnims'] ~= nil then
					self.Poses:ImportFavorites(userData['favoriteAnims'])
				end
				if userData['spawnedNPCs'] ~= nil then
					self.Spawn.entitiesForRespawn = userData['spawnedNPCs']
				end
				if userData['savedSwaps'] ~= nil then
					self.Swap.savedSwaps = userData['savedSwaps']
				end
				if userData['followDistance'] ~= nil then
					self.followDistance = userData['followDistance']
				end
				if userData['activePreset'] ~= nil then
					self.Props.activePreset = userData['activePreset']
					pcall(function() spdlog.info('During import '..tostring(self.Props.activePreset)) end)
				end
				if userData['homeTags'] ~= nil then
					self.Props.homeTags = userData['homeTags']
				end
				if userData['savedPropsDisplayMode'] ~= nil then
					self.Props.savedPropsDisplayMode = userData['savedPropsDisplayMode']
				end

				self.customAppPosition = userData['customAppPosition'] or "Top"
				self.selectedTheme = userData['selectedTheme'] or "Default"
				self.selectedHotkeys = userData['selectedHotkeys'] or {}
				self.Tools.selectedTPPCamera = userData['selectedTPPCamera'] or 1
				self.Tools.defaultFOV = userData['defaultFOV'] or 60
				self.Tools.defaultAperture = userData['defaultAperture'] or 4
				self.companionAttackMultiplier = userData['companionDamageMultiplier'] or 0
				self.companionResistanceMultiplier = userData['companionResistanceMultiplier'] or 0
				self.Poses.history = userData['posesHistory'] or {}
				self.Tools.selectedNibblesEntity = userData['selectedNibblesEntity'] or 1
				self.Tools.replacerVersion = userData['replacerVersion']
				self.selectedLanguage = self:GetLanguageIndex(userData['selectedLanguage'] or "en_US")
				self.UI.style.listScaleFactor = userData['listScaleFactor'] or 0
				self.Props.presetTriggerDistance = userData['presetTriggerDistance'] or 60
				self.Tools.favoriteExpressions = userData['favoriteExpressions'] or {}

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
				if userData['favorites_apps'] ~= nil then
					for _, obj in ipairs(userData['favorites_apps']) do
						local command = f("INSERT INTO favorites_apps (entity_id, app_name) VALUES ('%s', '%s')", obj.entity_id, obj.app_name)
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
				if userData['appTriggers'] ~= nil then
					for _, obj in ipairs(userData['appTriggers']) do
						local command = f("INSERT INTO appearance_triggers (entity_id, appearance, type, args) VALUES ('%s', '%s', %i, '%s')", obj.entity_id, obj.appearance, obj.type, obj.args)
						command = command:gsub("'nil'", "NULL")
						db:execute(command)
					end
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
		userData['favorites_apps'] = {}
		for r in db:nrows("SELECT * FROM favorites_apps") do
			table.insert(userData['favorites_apps'], {entity_id = r.entity_id, app_name = r.app_name})
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
		userData['appTriggers'] = {}
		for r in db:nrows("SELECT * FROM appearance_triggers") do
			table.insert(userData['appTriggers'], {entity_id = r.entity_id, appearance = r.appearance, type = r.type, args = r.args})
		end

		if self.userSettings.respawnOnLaunch then
			userData['spawnedNPCs'] = self:PrepareExportSpawnedData()
		end

		userData['favoriteLocations'] = self.Tools:GetFavoriteLocations()
		userData['favoriteAnims'] = self.Poses:ExportFavorites()
		userData['selectedTheme'] = self.selectedTheme
		userData['savedSwaps'] = self.Swap:GetSavedSwaps()
		userData['followDistance'] = self.followDistance
		userData['customAppPosition'] = self.customAppPosition
		userData['selectedHotkeys'] = self:ExportSelectedHotkeys()
		userData['activePreset'] = self.Props.activePreset.file_name or ''
		userData['homeTags'] = Util:GetTableKeys(self.Props.homes)
		userData['selectedTPPCamera'] = self.Tools.selectedTPPCamera
		userData['defaultFOV'] = self.Tools.defaultFOV
		userData['defaultAperture'] = self.Tools.defaultAperture
		userData['companionDamageMultiplier'] = self.companionAttackMultiplier
		userData['companionResistanceMultiplier'] = self.companionResistanceMultiplier
		userData['posesHistory'] = self.Poses.history
		userData['savedPropsDisplayMode'] = self.Props.savedPropsDisplayMode
		userData['selectedNibblesEntity'] = self.Tools.selectedNibblesEntity
		userData['replacerVersion'] = self.Tools.replacerVersion
		userData['selectedLanguage'] = self.availableLanguages[self.selectedLanguage].name or "en_US"
		userData['listScaleFactor'] = self.UI.style.listScaleFactor
		userData['presetTriggerDistance'] = self.Props.presetTriggerDistance
		userData['favoriteExpressions'] = self.Tools.favoriteExpressions

		local validJson, contents = pcall(function() return json.encode(userData) end)
		if validJson and contents ~= nil then
			local file = io.open("User/user.json", "w")
			if file then
				file:write(contents)
				file:close()
			end
		else
			Util:AMMError("Failed to export user data.\n"..contents, true)
		end
	end
end

function AMM:GetSavedSpawnData(savedIDs)
	local savedEntities = {}

	for _, id in ipairs(savedIDs) do
		for ent in db:nrows(f("SELECT * FROM entities WHERE entity_id = '%s'", id)) do
			table.insert(savedEntities, ent)
		end
	end

	return savedEntities
end

function AMM:PrepareExportSpawnedData()
	local spawnedEntities = {}

	for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
		-- Need to replace V and Hover V ID with the one included in the database
		if Util:CheckVByID(ent.id) then
			if string.find("Hover", ent.name) then
				ent.id = "0x55C01D9F, 36"
			else
				ent.id = "0x451222BE, 24"
			end
		end

		table.insert(spawnedEntities, ent.id)
	end

	return spawnedEntities
end

function AMM:ExportSelectedHotkeys()
	local selectedHotkeys = {}
	for id, hotkeys in pairs(AMM.selectedHotkeys) do
		for _, hotkey in ipairs(hotkeys) do
			if hotkey ~= '' then
				selectedHotkeys[id] = hotkeys
				break
			end
		end
	end

	return selectedHotkeys
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
		{label = AMM.LocalizableString("Label_GreetV"), param = "greeting"},
		{label = AMM.LocalizableString("Label_FearFoll"), param = "fear_foll"},
		{label = AMM.LocalizableString("Label_FearToll"), param = "fear_toll"},
		{label = AMM.LocalizableString("Label_FearBeg"), param = "fear_beg"},
		{label = AMM.LocalizableString("Label_FearRun"), param = "fear_run"},
		{label = AMM.LocalizableString("Label_StealthSearch"), param = "stlh_search"},
		{label = AMM.LocalizableString("Label_StealthDeath"), param = "stlh_death"},
		{label = AMM.LocalizableString("Label_StealthRestore"), param = "stealth_restored"},
		{label = AMM.LocalizableString("Label_StealthEnd"), param = "stealth_ended"},
		{label = AMM.LocalizableString("Label_CuriousGrunt"), param = "stlh_curious_grunt"},
		{label = AMM.LocalizableString("Label_GrappleGrunt"), param = "grapple_grunt"},
		{label = AMM.LocalizableString("Label_Bump"), param = "bump"},
		{label = AMM.LocalizableString("Label_VehicleBump"), param = "vehicle_bump"},
		{label = AMM.LocalizableString("Label_TurretWarning"), param = "turret_warning"},
		{label = AMM.LocalizableString("Label_OctantWarning"), param = "octant_warning"},
		{label = AMM.LocalizableString("Label_DroneWarning"), param = "drones_warning"},
		{label = AMM.LocalizableString("Label_MechWarning"), param = "mech_warning"},
		{label = AMM.LocalizableString("Label_EliteWarning"), param = "elite_warning"},
		{label = AMM.LocalizableString("Label_CameraWarning"), param = "camera_warning"},
		{label = AMM.LocalizableString("Label_EnemyWarning"), param = "enemy_warning"},
		{label = AMM.LocalizableString("Label_HeavyWarning"), param = "heavy_warning"},
		{label = AMM.LocalizableString("Label_SniperWarning"), param = "sniper_warning"},
		{label = AMM.LocalizableString("Label_AnyDamage"), param = "vo_any_damage_hit"},
		{label = AMM.LocalizableString("Label_Danger"), param = "danger"},
		{label = AMM.LocalizableString("Label_CombatStart"), param = "start_combat"},
		{label = AMM.LocalizableString("Label_CombatEnd"), param = "combat_ended"},
		{label = AMM.LocalizableString("Label_CombatTargetHit"), param = "combat_target_hit"},
		{label = AMM.LocalizableString("Label_PedestrianHit"), param = "pedestrian_hit"},
		{label = AMM.LocalizableString("Label_LightHit"), param = "hit_reaction_light"},
		{label = AMM.LocalizableString("Label_Curse"), param = "battlecry_curse"},
		{label = AMM.LocalizableString("Label_Irritated"), param = "coop_irritation"},
		{label = AMM.LocalizableString("Label_GrenadeThrow"), param = "grenade_throw"},
		{label = AMM.LocalizableString("Label_Gotakill"), param = "coop_reports_kill"},
	}

	return VOs
end

function AMM:GetPersonalityOptions()
	local personalities = {
	  -- OG Expressions
	  { name = AMM.LocalizableString("Neutral"),      idle = 2,  category = 2, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Joy"),          idle = 5,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Smile"),        idle = 6,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Sad"),          idle = 3,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Surprise"),     idle = 8,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Aggressive"),   idle = 2,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Anger"),        idle = 1,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Interested"),   idle = 3,  category = 1, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Disinterested"),idle = 6,  category = 1, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Disappointed"), idle = 4,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Disgust"),      idle = 7,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Exertion"),     idle = 1,  category = 1, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Nervous"),      idle = 10, category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Fear"),         idle = 11, category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Terrified"),    idle = 9,  category = 3, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Pain"),         idle = 2,  category = 1, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Sleepy"),       idle = 5,  category = 1, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Unconscious"),  idle = 4,  category = 1, cat_name = "OG Expressions" },
	  { name = AMM.LocalizableString("Dead"),         idle = 1,  category = 2, cat_name = "OG Expressions" },
	}
 
	return personalities
end

function AMM:GetExtraPersonalityOptions()
	local data = require('Collabs/Extra_Expressions_AMM.lua')
	local personalities = data.personalities

	for i, personality in ipairs(personalities) do
		local localizedName = AMM.LocalizableString(personality.name)
		if localizedName == "AMM_ERROR" then
			personality.name = AMM:ParsePersonalityName(personality.name)
		else
			personality.name = localizedName
		end

		local localizedCatName = AMM.LocalizableString(personality.cat_name)
		if localizedCatName == "AMM_ERROR" then
			personality.cat_name = AMM:ParsePersonalityName(personality.cat_name)
		else
			personality.cat_name = localizedCatName
		end
	end

	return personalities
end

function AMM:ParsePersonalityName(name)
	-- First replace the special pattern _N_ with " & "
	local parsedName = string.gsub(name, "_N_", " & ")
	-- Replace remaining underscores with spaces
	parsedName = string.gsub(parsedName, "_", " ")
	-- Then insert a space before any uppercase letter that follows a lowercase letter
	parsedName = string.gsub(parsedName, "([a-z])([A-Z])", "%1 %2")
	return parsedName
end

-- Sort the merged expressions by category and then by expression name.
function AMM:GetAllExpressionsMerged()
	local merged = {}

	-- Insert OG first
	for _, item in ipairs(self:GetPersonalityOptions()) do
		 table.insert(merged, item)
	end

	-- Insert Extra next
	for _, item in ipairs(self:GetExtraPersonalityOptions()) do
		 table.insert(merged, item)
	end

	table.sort(merged, function(a, b)
		 if a.cat_name == b.cat_name then
			  return a.name < b.name
		 else
			  return a.cat_name < b.cat_name
		 end
	end)

	return merged
end

-- Extract and sort unique categories
function AMM:GetSortedCategories()
	local merged = self:GetAllExpressionsMerged()
	local categoriesSet = {}
	for _, face in ipairs(merged) do
		 categoriesSet[face.cat_name] = true
	end
	local categoriesList = {}
	for cat, _ in pairs(categoriesSet) do
		 table.insert(categoriesList, cat)
	end
	table.sort(categoriesList)
	return categoriesList
end

function AMM:GetEquipmentOptions(HMG)
	local equipments = {
		{name = 'Fists', path = 'Character.wraiths_strongarms_hmelee3_fists_mb_elite_inline0'},
		{name = 'Katana', path = 'Character.afterlife_rare_fmelee3_katana_wa_elite_inline0'},
		{name = 'Mantis Blades', path = 'Character.afterlife_rare_fmelee3_mantis_ma_elite_inline2'},
		{name = 'Neon Red Mantis Blades', path = 'Character.main_boss_oda_inline0'},
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

function AMM:GetCustomAppearanceDefaults()
	if AMM.collabs and #AMM.collabs > 0 then
		local customs = {}
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

		return customs
	end

	return nil
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
	db:execute("UPDATE favorites_props SET parameters = NULL WHERE parameters = 'Prop';")
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

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = 'favorites'", count - 1))

	for x in db:urows('SELECT COUNT(1) FROM favorites_props') do
		count = x
	end

	db:execute(f("UPDATE sqlite_sequence SET seq = %i WHERE name = 'favorites_props'", count - 1))
end

function AMM:SetupExtraFromArchives()

	db:execute("DELETE FROM custom_appearances WHERE collab_tag IS NOT NULL")
	db:execute("DELETE FROM appearances WHERE collab_tag IS NOT NULL AND collab_tag IS NOT 'Replacer'")

	for _, archive in ipairs(AMM.archives) do
		-- Setup Misty appearances
		if archive.name == "basegame_AMM_MistyBodyRevamp" and archive.active then
			local appearances = {"misty_dress", "misty_naked", "misty_underwear"}
			local entity_id = "0xA22A7797, 15"
			local uid = "AMM"
			for _, app in ipairs(appearances) do
				db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
			end

			db:execute([[INSERT INTO custom_appearances (entity_id, app_name, app_base, app_param, app_toggle, mesh_app, mesh_type, mesh_mask, mesh_path, collab_tag) VALUES ('0xA22A7797, 15', 'Custom Misty Naked No Choker', 'misty_naked', 'i1_048_wa_neck__ckoker', '0', NULL, 'item', NULL, NULL, 'AMM')]])
			db:execute([[INSERT INTO custom_appearances (entity_id, app_name, app_base, app_param, app_toggle, mesh_app, mesh_type, mesh_mask, mesh_path, collab_tag) VALUES ('0xA22A7797, 15', 'Custom Misty Naked No Necklace', 'misty_naked', 'i1_001_wa_neck__misty0455', '0', NULL, 'item', NULL, NULL, 'AMM')]])

		-- Setup Cheri appearances
		elseif archive.name == "AMM_Cheri_Appearances" and archive.active then
			local appearances = {"service__sexworker_wa_cheri_casual", "service__sexworker_wa_cheri_home", "service__sexworker_wa_cheri_panties", "service__sexworker_wa_cheri_date", "service__sexworker_wa_cheri_party"}
			local entity_id = "0xBF76C44D, 29"
			local uid = "AMM"
			local valueList = {}
			for _, app in ipairs(appearances) do
				table.insert(valueList, f('("%s", "%s", "%s")', entity_id, app, uid))
			end

			db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ' .. table.concat(valueList, ",")))
			

		-- Setup Bryce appearances
		elseif archive.name == "AMM_Bryce_Naked" and archive.active then
			local entity_id = "0x8EB4F79A, 29"
			local uid = "AMM"

			local sql = [[
				INSERT INTO custom_appearances (entity_id, app_name, app_base, app_param, app_toggle, mesh_app, mesh_type, mesh_mask, mesh_path, collab_tag)
				VALUES
					('0x8EB4F79A, 29', 'Custom Bryce Topless', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 't1_001_ma_shirt__netwatch_agent', '0', NULL, 'torso', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce Topless', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 't0_001_ma_body__netwatch_agent', '0', NULL, 'body', '18446742011118124815ULL', NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce No Pants', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 'l1_001_ma_pants__netwatch_agent0430', '0', NULL, 'legs', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce No Pants', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 't0_001_ma_body__netwatch_agent', '0', NULL, 'body', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce No Shoes', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 's1_010_ma_shoe__elegant5827', '0', NULL, 'feet', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce No Shoes', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 't0_001_ma_body__netwatch_agent', '0', NULL, 'body', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce Naked', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 's1_010_ma_shoe__elegant5827', '0', NULL, 'feet', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce Naked', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 'l1_001_ma_pants__netwatch_agent0430', '0', NULL, 'legs', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce Naked', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 't1_001_ma_shirt__netwatch_agent', '0', NULL, 'torso', NULL, NULL, 'AMM'),
					('0x8EB4F79A, 29', 'Custom Bryce Naked', 'corpo__netwatch_ma__q110__bryce_mosley_naked', 't0_001_ma_body__netwatch_agent', '0', NULL, 'body', NULL, NULL, 'AMM')
			]]

			db:execute(sql)

		elseif archive.name == "basegame_AMM_RiverPP" and archive.active then
			local appearances = {"river_ward_naked_erect"}
			local entity_id = "0x7B2CB67C, 17"
			local uid = "AMM"
			for _, app in ipairs(appearances) do
				db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
			end

		elseif archive.name == "basegame_AMM_YorinobuPP" and archive.active then
			local appearances = {"yorinobu_arasaka_naked", "yorinobu_arasaka_yorinobu_arasaka_kimono", "yorinobu_arasaka_yorinobu_kimono"}
			local entity_id = "0x8D34B4F2, 18"
			local uid = "AMM"
			for _, app in ipairs(appearances) do
				db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
			end

		elseif archive.name == "basegame_AMM_KerryPP" and archive.active then
			local appearances = {"kerry_eurodyne_young_naked", "kerry_eurodyne_young_2013_naked"}
			local entity_id = "0x3024F03E, 15"
			local uid = "AMM"
			for _, app in ipairs(appearances) do
				db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
			end

		elseif archive.name == "AMM_8ug8ear_Appearances" and archive.active then
			local appearances = {"8ug8ear_casual", "8ug8ear_naked"}
			local entity_id = "0x5F7049F1, 31"
			local uid = "AMM"
			for _, app in ipairs(appearances) do
				db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
			end

		elseif archive.name == "AMM_TBug_Appearances" and archive.active then
			local appearances = {"t_bug_casual"}
			local entity_id = "0xB1CC84D0, 14"
			local uid = "AMM"
			for _, app in ipairs(appearances) do
				db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
			end

			local sql = [[
				INSERT INTO custom_appearances (entity_id, app_name, app_base, app_param, app_toggle, mesh_app, mesh_type, mesh_mask, mesh_path, collab_tag)
				VALUES
					('0xB1CC84D0, 14', 'Custom T-Bug Jacket Only', 't_bug_casual', 'g1_008_wa_gloves__fingerless_l', '0', NULL, 'hands', NULL, NULL, NULL, 'AMM'),
					('0xB1CC84D0, 14', 'Custom T-Bug Jacket Only', 't_bug_casual', 'g1_008_wa_gloves__fingerless_r', '0', NULL, 'hands', NULL, NULL, 'AMM'),
					('0xB1CC84D0, 14', 'Custom T-Bug Jacket Only', 't_bug_casual', 't0_004_wa__c_base_h3119', '0', NULL, 'body', NULL, NULL, 'AMM'),
					('0xB1CC84D0, 14', 'Custom T-Bug Jacket Only', 't_bug_casual', 's1_048_wa_boot__straps7816', '0', NULL, 'feet', NULL, NULL, 'AMM'),
					('0xB1CC84D0, 14', 'Custom T-Bug Jacket Only', 't_bug_casual', 't0_001_wa_body__t_bug0211', '0', NULL, 'torso', NULL, NULL, 'AMM')
			]]

			db:execute(sql)

		elseif archive.name == "AMM_Evelyn_Naked" and archive.active and AMM.CodewareVersion < 4.2 then
			local appearances = {"evelyn_naked"}
			local entity_id = "0x7F65F7F7, 16"
			local uid = "AMM"

			for _, app in ipairs(appearances) do
				db:execute(f('INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")', entity_id, app, uid))
			end

			sql = [[
				INSERT INTO custom_appearances (entity_id, app_name, app_base, app_param, app_toggle, mesh_app, mesh_type, mesh_mask, mesh_path, collab_tag)
				VALUES
					('0x7F65F7F7, 16', 'Custom Evelyn Panties', 'evelyn_naked', 'l1_075_wa_shorts__strap_pants6116', '1', NULL, 'legs', NULL, NULL, 'AMM'),
					('0x7F65F7F7, 16', 'Custom Evelyn With Jacket', 'evelyn_naked', 'SkinnedCloth5670', '1', NULL, 'torso', NULL, NULL, 'AMM'),
					('0x7F65F7F7, 16', 'Custom Evelyn With Jacket', 'evelyn_naked', 't2_001_wa_jacket__evelyn_coat_fur0527', '1', NULL, 'torso', NULL, NULL, 'AMM'),
					('0x7F65F7F7, 16', 'Custom Evelyn No Fur', 'evelyn_naked', 't2_001_wa_jacket__evelyn_coat_fur0527', '0', NULL, 'torso', NULL, NULL, 'AMM'),
					('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_naked', 't1_001_wa_dress__evelyn4160', '1', NULL, 'torso', NULL, NULL, 'AMM'),
					('0x7F65F7F7, 16', 'Custom Evelyn With Gloves', 'evelyn_naked', 'g1_001_wa_gloves__evelyn5247', '1', NULL, 'hands', NULL, NULL, 'AMM'),
					('0x7F65F7F7, 16', 'Custom Evelyn With Necklace', 'evelyn_naked', 'i1_082_wa_neck__clair_plate0241', '1', NULL, 'item', NULL, NULL, 'AMM'),
					('0x7F65F7F7, 16', 'Custom Evelyn No Fur', 'evelyn_naked', 'SkinnedCloth5670', '1', NULL, 'torso', NULL, NULL, 'AMM')
			]]

			db:execute(sql)

		-- Enable Scenes if archive exists
		elseif archive.name == "basegame_AMM_ScenesPack" and archive.active then
			AMM.Poses.sceneAnimsInstalled = true
		end
	end

end

function AMM:SetupAMMCharacters()
	db:execute("DELETE FROM entities WHERE entity_path LIKE '%Test_Character%'")

	local uniqueV = ''
	if AMM.UniqueVRig then
		uniqueV = "_unique"
	end

	local ents = {
		{og = "Character.TPP_Player_Cutscene_Male", tdbid = "AMM_Character.Player_Male", path = "player_ma_tpp"..uniqueV},
		{og = "Character.TPP_Player_Cutscene_Female", tdbid = "AMM_Character.Player_Female", path = "player_wa_tpp"..uniqueV},
		{og = "Character.TPP_Player_Cutscene_Male", tdbid = "AMM_Character.TPP_Player_Male", path = "player_ma_tpp_walking"..uniqueV},
		{og = "Character.TPP_Player_Cutscene_Female", tdbid = "AMM_Character.TPP_Player_Female", path = "player_wa_tpp_walking"..uniqueV},
		{og = "Character.Takemura", tdbid = "AMM_Character.Silverhand", path = "silverhand"},
		{og = "Character.Hanako", tdbid = "AMM_Character.Hanako", path = "hanako"},
		{og = "Character.songbird", tdbid = "AMM_Character.Songbird", path = "songbird"},
		{og = "Character.mq030_melisa", tdbid = "AMM_Character.E3_V_Female", path = "e3_v_female"},
		{og = "Character.afterlife_rare_fmelee3_mantis_ma_elite", tdbid = "AMM_Character.E3_V_Male", path = "e3_v_male"},
		{og = "Character.Voodoo_Queen", tdbid = "AMM_Character.Rache_Bartmoss", path = "rache_bartmoss"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Sit", path = "nibbles_sit"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Test", path = "nibbles_test"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Get_Pet", path = "nibbles_get_pet"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Jump_Down", path = "nibbles_jump_down"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Self_Clean", path = "nibbles_self_clean"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Sleeping", path = "nibbles_sleep"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Sleeping_01", path = "nibbles_sleep_01"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Sleeping_02", path = "nibbles_sleep_02"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Sleeping_Belly_Up", path = "nibbles_sleep_belly_up"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Scratch", path = "nibbles_scratch"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles_Lie", path = "nibbles_lie"},
		{og = "Character.q003_cat", tdbid = "AMM_Character.Nibbles", path = "nibbles"},
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
	-- TweakDB:SetFlat("AMM_Character.TPP_Player_Female.attachmentSlots", TweakDB:GetFlat("Character.Player_Puppet_Photomode.attachmentSlots"))

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
		fullDisplayName = TweakDB:GetFlat('Character.q116_v_female.fullDisplayName'),
		displayName = TweakDB:GetFlat('Character.q116_v_female.displayName'),
		reactionPreset = TweakDB:GetFlat('Character.q116_v_female.reactionPreset'),
		sensePreset = TweakDB:GetFlat('Character.q116_v_female.sensePreset'),
		secondaryEquipment = TweakDB:GetFlat('Character.arr_ncpd_inspector_ranged1_lexington_ma.primaryEquipment'),
		affiliation = TweakDB:GetFlat('Character.afterlife_rare_fmelee3_mantis_ma_elite.affiliation'),
	})

	TweakDB:SetFlats("AMM_Character.E3_V_Male",{
		fullDisplayName = TweakDB:GetFlat('Character.q116_v_male.fullDisplayName'),
		displayName = TweakDB:GetFlat('Character.q116_v_male.displayName'),
		reactionPreset = TweakDB:GetFlat('Character.q116_v_male.reactionPreset'),
		sensePreset = TweakDB:GetFlat('Character.q116_v_male.sensePreset'),
		secondaryEquipment = TweakDB:GetFlat('Character.arr_ncpd_inspector_ranged1_lexington_ma.primaryEquipment'),
	})

	TweakDB:SetFlats("AMM_Character.Songbird",{
		fullDisplayName = TweakDB:GetFlat("Character.q110_vdb_elder_1.fullDisplayName"),
		displayName = TweakDB:GetFlat("Character.jpn_tygerclaw_gangster3_netrunner_nue_wa_rare.displayName"),
	})

	TweakDB:SetFlats("AMM_Character.Rache_Bartmoss",{
		fullDisplayName = TweakDB:GetFlat("Character.q110_vdb_elder_1.fullDisplayName"),
		affiliation = TweakDB:GetFlat('Character.generic_netrunner_netrunner_chao_wa_rare_ow_city_scene.affiliation'),
	})

	TweakDB:SetFlats("Character.lizzies_bouncer",{
		primaryEquipment = TweakDB:GetFlat('Character.the_mox_1_melee2_baseball_wa.primaryEquipment'),
		secondaryEquipment = TweakDB:GetFlat('Character.the_mox_1_melee2_baseball_wa.secondaryEquipment'),
		abilities = TweakDB:GetFlat("Character.the_mox_1_melee2_baseball_wa.abilities"),
		statModifierGroups = TweakDB:GetFlat("Character.the_mox_1_melee2_baseball_wa.statModifierGroups"),
	})

	AMM.customNames['0x69E1384D, 22'] = 'So Ri'
	AMM.customNames['0xB54D1804, 28'] = 'Rache Bartmoss'
	AMM.customNames['0xE09AAEB8, 26'] = 'Mahir MT28 Coach'

	-- Temporary placement for new Custom Appearances based on Codeware 1.4.2
	-- Adds Evelyn Custom Appearances if user has Codeware 1.4.2 installed
	if AMM.CodewareVersion >= 4.2 then
		local sql = [[
			INSERT INTO custom_appearances (entity_id, app_name, app_base, app_param, app_toggle, mesh_app, mesh_type, mesh_mask, mesh_path, collab_tag)
			VALUES
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 't1_001_wa_dress__evelyn4160', '1', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'l1_075_wa_shorts__strap_pants6116', '0', NULL, 'legs', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 's1_001_wa_boot__evelyn3572', '0', NULL, 'feet', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'SkinnedCloth5670', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'g1_001_wa_gloves__evelyn5247', '0', NULL, 'hands', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'i1_082_wa_neck__clair_plate0241', '0', NULL, 'item', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 't0_001_wa_body__evelyn1732', '0', NULL, 'body', NULL, 'base\characters\main_npc\evelyn\t0_002_wa_body__evelyn.mesh', 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 't2_001_wa_jacket__evelyn_coat_fur0527', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'l1_075_wa_shorts__strap_pants6116', '0', NULL, 'legs', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 's1_001_wa_boot__evelyn3572', '0', NULL, 'feet', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'SkinnedCloth5670', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'g1_001_wa_gloves__evelyn5247', '0', NULL, 'hands', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 'i1_082_wa_neck__clair_plate0241', '0', NULL, 'item', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 't0_001_wa_body__evelyn1732', '0', NULL, 'body', NULL, 'base\characters\main_npc\evelyn\t0_002_wa_body__evelyn.mesh', 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Dress Only', 'evelyn_default', 't2_001_wa_jacket__evelyn_coat_fur0527', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn With Jacket', 'evelyn_default', 'SkinnedCloth5670', '1', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn With Jacket', 'evelyn_default', 't2_001_wa_jacket__evelyn_coat_fur0527', '1', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn With Gloves', 'evelyn_default', 'g1_001_wa_gloves__evelyn5247', '1', NULL, 'hands', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn With Necklace', 'evelyn_default', 'i1_082_wa_neck__clair_plate0241', '1', NULL, 'item', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn No Fur', 'evelyn_default', 't2_001_wa_jacket__evelyn_coat_fur0527', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn No Fur', 'evelyn_default', 'SkinnedCloth5670', '1', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 't1_001_wa_dress__evelyn4160', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 's1_001_wa_boot__evelyn3572', '0', NULL, 'feet', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 'SkinnedCloth5670', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 'g1_001_wa_gloves__evelyn5247', '0', NULL, 'hands', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 'i1_082_wa_neck__clair_plate0241', '0', NULL, 'item', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 't0_001_wa_body__evelyn1732', '0', NULL, 'body', NULL, 'base\characters\main_npc\evelyn\t0_002_wa_body__evelyn.mesh', 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 't2_001_wa_jacket__evelyn_coat_fur0527', '0', NULL, 'torso', NULL, NULL, 'AMM'),
				('0x7F65F7F7, 16', 'Custom Evelyn Naked', 'evelyn_default', 'l1_075_wa_shorts__strap_pants6116', '0', NULL, 'legs', NULL, NULL, 'AMM')
		]]

		db:execute(sql)
	end
end

--------------------------------------------------------------------------------
-- 1) Directory scanning helper (unchanged except for minor style adjustments)
--------------------------------------------------------------------------------
local typeDirectory = 'directory'
local extensionLua  = '.lua$'

local function getFilesRecursively(_dir, tbl)
  tbl = tbl or {}
  local files = dir(_dir)
  if #files == 0 then return tbl end

  for _, file in ipairs(files) do
    -- if it's a directory: recurse
    if file.type == typeDirectory then
      getFilesRecursively(_dir .. '/' .. file.name, tbl)

    -- if it's a lua file: add to return list
    elseif string.find(file.name, extensionLua) then
      table.insert(tbl, _dir .. '/' .. file.name)
    end
  end

  return tbl
end

--------------------------------------------------------------------------------
-- 2) Common DB helper functions
--------------------------------------------------------------------------------

-- Simple helper to get a single integer count from the database
local function getCount(db, query)
  -- Example usage:
  -- local c = getCount(db, 'SELECT COUNT(1) FROM entities WHERE ...')
  for c in db:urows(query) do
    return c
  end
  return 0
end

-- Checks if an entity_path (or any other path) exists
local function recordExists(db, tableName, columnName, value)
  local query = string.format('SELECT COUNT(1) FROM %s WHERE %s = "%s"', tableName, columnName, value)
  return getCount(db, query) > 0
end

-- Insert with a simple format, returning any replaced "nil"/"NULL" fixes
local function sanitizedInsert(db, tableName, columnsString, valuesString)
  -- columnsString = '(a, b, c)'
  -- valuesString  = '("valA", "valB", "valC")'
  local cleanedValues = valuesString:gsub('"nil"', "NULL"):gsub('""', "NULL")
  local sql = string.format('INSERT INTO %s %s VALUES %s', tableName, columnsString, cleanedValues)
  db:execute(sql)
end

function AMM:GatherCustomCollabsPaths()
	local foundPaths = {}
 
	----------------------------------------------------------------------------
	-- A) Scan Custom Entities folder
	----------------------------------------------------------------------------
	local entityFiles = getFilesRecursively("./Collabs/Custom Entities", {})
	for _, filePath in ipairs(entityFiles) do
	  local data = require(filePath)
	  if data and data.entity_info and data.entity_info.path then
		 foundPaths[data.entity_info.path] = true
	  end
	end
 
	----------------------------------------------------------------------------
	-- B) Scan Custom Props folder
	----------------------------------------------------------------------------
	local propFiles = getFilesRecursively("./Collabs/Custom Props", {})
	for _, filePath in ipairs(propFiles) do
	  local data = require(filePath)
	  if data and data.props then
		 for _, prop in ipairs(data.props) do
			if prop.path then
			  foundPaths[prop.path] = true
			end
		 end
	  end
	end

	----------------------------------------------------------------------------
  -- C) Scan Custom Poses folder
  ----------------------------------------------------------------------------
  local poseFiles = getFilesRecursively("./Collabs/Custom Poses", {})
  for _, filePath in ipairs(poseFiles) do
    local data = require(filePath)
    -- typically data.entity_path is how your pose references the entity
    -- if data.entity_path exists, track it
    if data and data.entity_path then
      foundPaths[data.entity_path] = true
    end
  end
 
	return foundPaths
 end

--------------------------------------------------------------------------------
-- 2) Cleanup any stale entries (entities, props, AND poses)
--------------------------------------------------------------------------------
function AMM:CleanupMissingCustomDBEntries(foundPaths)
	db:execute("BEGIN TRANSACTION")
 
	----------------------------------------------------------------------------
	-- A) Entities / Props
	----------------------------------------------------------------------------
	local sql = [[
	  SELECT entity_id, entity_path, template_path
	  FROM entities
	  WHERE entity_path LIKE 'Custom_%'
	]]
	for entity_id, entity_path, tPath in db:urows(sql) do
	  -- If we never saw this templatePath while scanning collab folders,
	  -- it likely means the user removed/changed the mod file.
	  if not foundPaths[tPath] then
		 local delEntSQL = string.format("DELETE FROM entities WHERE entity_id = '%s'", entity_id)
		 db:execute(delEntSQL)
 
		 local delAppSQL = string.format("DELETE FROM appearances WHERE entity_id = '%s'", entity_id)
		 db:execute(delAppSQL)
 
		 spdlog.info(string.format("Removed stale custom DB entry: %s (template: %s)", entity_path, tPath))
	  end
	end
 
	----------------------------------------------------------------------------
	-- B) Poses in workspots
	----------------------------------------------------------------------------
	local animCompType = "amm_workspot_collab"
	local sqlPoses = string.format(
	  "SELECT anim_id, anim_ent FROM workspots WHERE anim_comp = '%s'",
	  animCompType
	)
	for anim_id, anim_ent in db:urows(sqlPoses) do
	  -- If anim_ent is not in foundPaths, remove it
	  if not foundPaths[anim_ent] then
		 local deleteSQL = string.format("DELETE FROM workspots WHERE anim_id = '%d'", anim_id)
		 db:execute(deleteSQL)
		 spdlog.info(string.format("Removed stale custom pose from DB: %s", anim_ent))
	  end
	end
 
	db:execute("COMMIT")
end 

function AMM:SetupCollabs()
	-- 1) Gather all known template_paths across Entities & Props
	local foundPaths = self:GatherCustomCollabsPaths()
	
	-- 2) Cleanup the DB of anything not in foundPaths
	self:CleanupMissingCustomDBEntries(foundPaths)

	AMM:SetupCustomEntities()
	AMM:SetupCustomProps()
	AMM:SetupCustomPoses()

end

--------------------------------------------------------------------------------
-- 3) Setup Custom Entities
--------------------------------------------------------------------------------
function AMM:SetupCustomEntities()
	local folder = "./Collabs/Custom Entities"
	local files  = getFilesRecursively(folder, {})
 
	if #files == 0 then return end
 
	db:execute("BEGIN TRANSACTION")
 
	for _, modFilePath in ipairs(files) do
	  local data = require(modFilePath)
	  if data then
		 local modder      = data.modder
		 local uid         = data.unique_identifier or "MISSING_UID"
		 local archive     = data.archive
		 local entity      = data.entity_info
		 local appearances = data.appearances
		 local attributes  = data.attributes
 
		 AMM.modders[uid] = modder
 
		 if archive then
			table.insert(AMM.collabArchives, {
			  name    = archive.name,
			  desc    = archive.description,
			  active  = true,
			  optional= false
			})
		 end
 
		 -- Figure out "Custom_xxx" entity_path
		 local entFile = (entity.path or ""):match("[^\\]*%.ent$") or "Unknown"
		 local entName = entFile:gsub("%.ent", "")
		 local entity_path = string.format("Custom_%s_%s.%s", uid, entity.type, entName)
		 local entity_id = AMM:GetScanID(entity_path)
 
		 -- If not in DB, insert it
		 if not recordExists(db, "entities", "entity_path", entity_path) then
			-- rename if entity_name is already taken
			if recordExists(db, "entities", "entity_name", entity.name) then
			  entity.name = uid .. " " .. entity.name
			end

			local canBeComp = (entity.type == "Vehicle") and 0 or 1
			local category  = (entity.type == "Vehicle") and 56 or 55
			local params    = nil
 
			local columns = '(entity_id, entity_name, cat_id, parameters, can_be_comp,' ..
								 ' entity_path, is_spawnable, is_swappable, template_path, entity_rig)'
			local vals    = string.format(
			  '("%s", "%s", %i, "%s", "%s", "%s", "%s", "%s", "%s", "%s")',
			  entity_id,
			  entity.name,
			  category,
			  params,
			  canBeComp,
			  entity_path,
			  1,
			  1,
			  entity.path,  -- <--- stored as template_path in DB
			  entity.rig
			)
			sanitizedInsert(db, "entities", columns, vals)
 
			-- optional
			if entity.customName then
			  AMM.customNames[entity_id] = entity.name
			end			
		 end

		 -- appearances
		 if appearances then
			for _, app in ipairs(appearances) do
			  local appearanceSQL = string.format(
				 'INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")',
				 entity_id, app, uid
			  )
			  db:execute(appearanceSQL)
			end
		 end
 
		 -- TweakDB: always do it
		 if not TweakDB:GetRecord(entity_path) then
			if entity.record then
			  TweakDB:CloneRecord(entity_path, entity.record)
			else
			  TweakDB:CloneRecord(entity_path, "Character.CitizenRichFemaleCasual")
			end
		 end
 
		 TweakDB:SetFlat(entity_path..".entityTemplatePath", entity.path)
 
		 if attributes then
			local newAttributes = {}
			for attr, value in pairs(attributes) do
			  newAttributes[attr] = TweakDB:GetFlat(value)
			end
			TweakDB:SetFlats(entity_path, newAttributes)
		 end
 
	  else
		 spdlog.error(string.format("Failed to read file: %s", modFilePath))
	  end
	end
 
	db:execute("COMMIT")
 end

--------------------------------------------------------------------------------
-- 4) Setup Custom Props
--------------------------------------------------------------------------------
function AMM:SetupCustomProps()

  local files = getFilesRecursively("./Collabs/Custom Props", {})
  if #files == 0 then return end

  db:execute("BEGIN TRANSACTION")

  for _, mod in ipairs(files) do
    local data = require(mod)
    if not data then
      spdlog.error(string.format("Failed to read file %s", mod))
    else
      local modder  = data.modder
      local uid     = data.unique_identifier
      local archive = data.archive
      local props   = data.props

      AMM.modders[uid] = modder
      AMM.hasCustomProps = true

      if archive then
        table.insert(AMM.collabArchives, {
          name = archive.name,
          desc = archive.description,
          active = true,
          optional = false
        })
      end

      for _, prop in ipairs(props) do
        prop          = prop or {}
        local propPath= (prop.path or ''):match("[^\\]*.ent$") or ''
        local ent     = propPath:gsub(".ent", "")
        local epath   = string.format("Custom_%s_Props.%s", uid, ent)
		  local entity_id = AMM:GetScanID(epath)
		  local category  = 48

        -- If it doesn't already exist, insert
        if not recordExists(db, "entities", "entity_path", epath) then
          -- rename if entity_name is taken
          if recordExists(db, "entities", "entity_name", prop.name) then
            prop.name = string.format("%s %s", uid, prop.name)
          end

          local queryCat  = string.format('SELECT cat_id FROM categories WHERE cat_name = "%s"', prop.category)
          for cat_id in db:urows(queryCat) do
            category = cat_id
          end

          local columns = '(entity_id, entity_name, cat_id, parameters, can_be_comp, entity_path, is_spawnable, is_swappable, template_path)'
          local vals    = string.format(
            '("%s", "%s", %i, %s, "%s", "%s", "%s", "%s", "%s")',
            entity_id,
            prop.name,
            category,
            prop.distanceFromGround,
            0,
            epath,
            1,
            0,
            prop.path
          )
          sanitizedInsert(db, "entities", columns, vals)          
        end

		  -- Setup Appearances
		  if prop.appearances then
			for _, app in ipairs(prop.appearances) do
			  local q = string.format(
				 'INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")',
				 entity_id, app, uid
			  )
			  db:execute(q)
			end
		 end
      end
    end
  end

  db:execute("COMMIT")
end

--------------------------------------------------------------------------------
-- 5) Setup Collab Appearances
--------------------------------------------------------------------------------
function AMM:SetupCollabAppearances()
  local files   = getFilesRecursively("./Collabs/Custom Appearances", {})
  local collabs = {}
  if #files == 0 then return collabs end

  db:execute("BEGIN TRANSACTION")

  local function addCollab(mod)
    local collab = require(mod)
    if not collab then
      spdlog.error(string.format("Failed to parse file: %s", mod))
      return
    end

    local metadata = collab.metadata

    -- No metadata => classic approach
    if not metadata then
      local entity_id   = collab.entity_id
      local archive     = collab.archive
      local uid         = collab.unique_identifier
      local appearances = collab.appearances
      local attributes  = collab.attributes

      if archive then
        table.insert(AMM.collabArchives, {
          name = archive.name,
          desc = archive.description,
          active = true,
          optional = false
        })
      end

      -- Insert appearances
      if appearances then
        for _, app in ipairs(appearances) do
          local ins = string.format(
            'INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES ("%s", "%s", "%s")',
            entity_id, app, uid
          )
          db:execute(ins)
        end
      end

      -- Possibly update TweakDB attributes
      if attributes then
        local entity_path = nil
        local sql         = string.format("SELECT entity_path FROM entities WHERE entity_id = '%s'", entity_id)
        for path in db:urows(sql) do
          entity_path = path
          break
        end

        if entity_path then
          local newAttributes = {}
          for attr, value in pairs(attributes) do
            newAttributes[attr] = TweakDB:GetFlat(value)
          end
          TweakDB:SetFlats(entity_path, newAttributes)
        end
      end

    else
      -- With metadata => handle new custom_appearances
      for _, newApp in ipairs(metadata) do
        newApp.disabledByDefault = collab.disabledByDefault
        table.insert(collabs, newApp)

        local customApps = collab.customApps[newApp.tag]
        if customApps then
          local c = getCount(db, string.format(
            "SELECT COUNT(1) FROM custom_appearances WHERE collab_tag = '%s'",
            newApp.tag
          ))
          if c ~= 0 then
            db:execute(string.format(
              "DELETE FROM custom_appearances WHERE collab_tag = '%s'",
              newApp.tag
            ))
          end

          for _, customApp in ipairs(customApps) do
            local columns = '("entity_id", "app_name", "app_base", "app_param", "app_toggle", "mesh_app", "mesh_type", "mesh_mask", "mesh_path", "collab_tag")'
            local vals    = string.format(
              '("%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s")',
              newApp.entity_id,
              customApp.app_name,
              newApp.appearance,
              customApp.app_param,
              customApp.app_toggle,
              customApp.mesh_app,
              customApp.mesh_type,
              customApp.mesh_mask,
              customApp.mesh_path,
              newApp.tag
            )
            sanitizedInsert(db, "custom_appearances", columns, vals)
          end
        end
      end
    end
  end

  for _, mod in ipairs(files) do
    addCollab(mod)
  end

  db:execute("COMMIT")
  return collabs
end

--------------------------------------------------------------------------------
-- 6) Setup Custom Poses
--------------------------------------------------------------------------------
function AMM:SetupCustomPoses()
	local animCompType = "amm_workspot_collab"
	local folder       = "./Collabs/Custom Poses"
 
	local files = getFilesRecursively(folder, {})
	if #files == 0 then return end
 
	-- Returned table of collabs
	local collabs               = {}
	-- Local table to track duplicates in a single run
	local alreadyRegisteredPoses = {}
 
	db:execute("BEGIN TRANSACTION")
	-- ensures the autoincrement is at least up-to-date
	db:execute('UPDATE sqlite_sequence SET seq = (SELECT MAX(anim_id) FROM workspots) WHERE name = "workspots"')
 
	for _, modFilePath in ipairs(files) do
	  local data = require(modFilePath)
	  if not data then
		 spdlog.error(string.format("%s: invalid file!", modFilePath))
	  else
		 local category   = data.category   or 'INVALID'
		 local entityPath = data.entity_path or 'INVALID'
		 local anims      = data.anims      or {}
		 local modder     = data.modder     or 'INVALID'
 
		 -- If category is already in the table, rename it
		 local catExists = getCount(db, string.format(
			[[SELECT COUNT(1) FROM workspots WHERE anim_cat = "%s"]],
			category
		 ))
		 if catExists ~= 0 then
			category = string.format("[%s] %s", modder, category)
		 end
 
		 alreadyRegisteredPoses[modder] = alreadyRegisteredPoses[modder] or {}
		 collabs[modder]               = collabs[modder] or {}
 
		 for rig, animsForRig in pairs(anims) do
			alreadyRegisteredPoses[modder][rig] = alreadyRegisteredPoses[modder][rig] or {}
			collabs[modder][rig]               = collabs[modder][rig] or {}
 
			table.insert(collabs[modder][rig], entityPath)
 
			for _, animName in ipairs(animsForRig) do
			  -- 1) Check duplicates in the same run
			  if alreadyRegisteredPoses[modder][rig][animName] then
				 spdlog.error(string.format(
					"%s: custom animation %s for rig %s is already registered (this run)!",
					modder, animName, rig
				 ))
			  else
				 -- 2) Also check if it already exists in DB from a previous run
				 local checkSQL = string.format([[
					SELECT COUNT(1) 
					FROM workspots 
					WHERE anim_name = "%s"
					  AND anim_rig  = "%s" 
					  AND anim_ent  = "%s" 
					  AND anim_comp = "%s"
				 ]],
				 animName, rig, entityPath, animCompType)
 
				 local count = getCount(db, checkSQL)
				 if count > 0 then
					-- Already in DB => skip or log
					spdlog.error(string.format(
					  "%s: custom animation %s for rig %s already exists in DB!",
					  modder, animName, rig
					))
				 else
					-- Not in DB => Insert it
					local columns = '(anim_name, anim_rig, anim_comp, anim_ent, anim_cat)'
					local vals    = string.format(
					  '("%s", "%s", "%s", "%s", "%s")',
					  animName, rig, animCompType, entityPath, category
					)
					sanitizedInsert(db, "workspots", columns, vals)
 
					-- Mark it as inserted for this run
					alreadyRegisteredPoses[modder][rig][animName] = true
				 end
			  end
			end
		 end
	  end
	end
 
	db:execute("COMMIT")
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
	AMM.Spawn:DespawnAll()
end

function AMM:TeleportAll()
	for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
		if ent.handle:IsNPC() then

			Util:TeleportNPCTo(ent.handle, Util:GetBehindPlayerPosition(2))

			Cron.Every(0.1, { tick = 1 }, function(timer)

				timer.tick = timer.tick + 1
		
				if timer.tick > 600 then
					Cron.Halt(timer)
				end
				
				local entity = Game.FindEntityByID(ent.entityID)

				if entity then
					ent.handle = entity
					AMM:ChangeAppearanceTo(ent, ent.appearance)
					
					Cron.Halt(timer)
				end
			end)
		end
	end
end

function AMM:RespawnAll()
	local entitiesForRespawn = {}
	for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
		if not(string.find(ent.path, "Vehicle")) then
			table.insert(entitiesForRespawn, ent)
		end
	end

	AMM:DespawnAll()

	Cron.Every(0.5, { tick = 1 }, function(timer)

		timer.tick = timer.tick + 1
		
		if timer.tick > 30 then
			Cron.Halt(timer)
		end

		local ent = entitiesForRespawn[1]
		local entity = nil

		if ent then
			if ent.entityID ~= '' then entity = Game.FindEntityByID(ent.entityID) end
			if entity == nil then
				table.remove(entitiesForRespawn, 1)
				AMM.Spawn:SpawnNPC(ent)
			end
		end

		if #entitiesForRespawn == 0 then
			Cron.Halt(timer)
		end
	end)
end

-- Elevator Teleportation Attempt for Companions
-- It does work, but it's janky as hell and we need a better teleport function
function AMM:StartCompanionsFollowElevator()

	local lastVPosition = Game.GetPlayer():GetWorldPosition()

	Cron.Every(0.1, { tick = 1 }, function(timer)

		timer.tick = timer.tick + 1

		if timer.tick > 600 then
			Cron.Halt(timer)
		end
		
		local currentVPosition = Game.GetPlayer():GetWorldPosition()

		Cron.After(2.5, function()

			if lastVPosition.z ~= currentVPosition.z then

				lastVPosition = currentVPosition
	
				for _, ent in pairs(AMM.Spawn.spawnedNPCs) do
					if ent.handle and ent.handle.IsNPC and ent.handle:IsNPC() then
						local currentPos = ent.handle:GetWorldPosition()
						local currentAngles = ent.handle:GetWorldOrientation():ToEulerAngles()
						local newPos = Vector4.new(currentPos.x, currentPos.y, currentVPosition.z, currentPos.w)
						Util:TeleportNPCTo(ent.handle, newPos, currentAngles.yaw)
					end
				end
			else
				Cron.Halt(timer)
			end
		end)
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

function AMM:CheckAppearanceForBannedWords(appearance)
	for _, word in ipairs(AMM.bannedWords) do
		if string.find(appearance, word) then
			return true
		end
	end

	return false
end

function AMM:CheckCustomDefaults(target)
	if AMM.customAppDefaults and target ~= nil and target.handle.IsNPC and target.handle:IsNPC() then
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
		if not AMM.savedAppearanceCheckCache[target.hash] then
			AMM.savedAppearanceCheckCache[target.hash] = target.appearance
			if AMM:CheckSavedAppearanceForEntity(target) then return end
		end
	end

	if AMM:CheckSavedAppearanceForMountedVehicle() then return end

	Util:GetAllInRange(10, false, true, function(entity)
		local ent = nil
		
		if entity.IsNPC and entity:IsNPC() then
			ent = AMM:NewTarget(entity, "NPCPuppet", AMM:GetScanID(entity), AMM:GetNPCName(entity), AMM:GetScanAppearance(entity), nil)
		elseif entity.IsVehicle and entity:IsVehicle() and entity:IsPlayerVehicle() then
			ent = AMM:NewTarget(entity, 'vehicle', AMM:GetScanID(entity), AMM:GetVehicleName(entity), AMM:GetScanAppearance(entity), nil)
		end

		if ent ~= nil and (not AMM.savedAppearanceCheckCache[ent.hash] or AMM.savedAppearanceCheckCache[ent.hash] ~= ent.appearance
		or not AMM.blacklistAppearanceCheckCache[ent.hash] or AMM.blacklistAppearanceCheckCache[ent.hash] == ent.appearance) then			
			AMM.savedAppearanceCheckCache[ent.hash] = ent.appearance
			AMM.blacklistAppearanceCheckCache[ent.hash] = ent.appearance
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

	if savedApp ~= nil then
		local custom = {}
		for app in db:urows(f("SELECT app_param FROM custom_appearances WHERE app_name = '%s'", savedApp)) do
			table.insert(custom, app)
		end

		if #custom > 0 then
			for _, component in ipairs(custom) do
				local comp = ent.handle:FindComponentByName(component)
				if comp and tostring(comp.chunkMask) ~= "0ULL" then
					AMM:ChangeToSavedAppearance(ent, savedApp)
					return true
				end
			end
		elseif currentApp ~= savedApp then
			AMM:ChangeToSavedAppearance(ent, savedApp)
			return true
		end
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

		if check == 0 then return end
    
		local newApp = nil
		local query = f("SELECT app_name FROM appearances WHERE app_name NOT IN (SELECT app_name FROM blacklist_appearances WHERE entity_id = '%s') AND app_name != '%s' AND entity_id = '%s' ORDER BY RANDOM() LIMIT 1", ent.id, ent.appearance, ent.id)
		for app in db:urows(query) do
			newApp = app
		end

		if newApp then
			AMM:ChangeScanAppearanceTo(ent, newApp)
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
			self:ChangeAppearanceTo(ent, savedApp)
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


-- TODO: CET won't allow mouse cursor for the time being
function AMM:ShowTargetTools()
	if not Tools 
		or not AMM.userSettings.floatingTargetTools 
		or Tools.movementWindow.open
	then return end
	
	drawWindow = true
	Tools:OpenMovementWindow()
end

function AMM:ClearAllSavedAppearances()
	db:execute("DELETE FROM saved_appearances")
	AMM:UpdateSettings()
end

function AMM:ClearAllFavoriteAppearances()
	db:execute("DELETE FROM favorites_apps")
	AMM:UpdateSettings()
end

function AMM:ClearAllBlacklistedAppearances()
	db:execute("DELETE FROM blacklist_appearances")
	AMM:UpdateSettings()
end

function AMM:ClearAllSavedDespawns()
	db:execute("DELETE FROM saved_despawns")
	AMM:UpdateSettings()
end

function AMM:ClearAllAppearanceTriggers()
	db:execute("DELETE FROM appearance_triggers")
	AMM:UpdateSettings()
end

function AMM:ClearAllFavorites()
	db:execute("DELETE FROM favorites; UPDATE sqlite_sequence SET seq = 0")
	AMM:UpdateSettings()
end

function AMM:ClearAllSwapFavorites()
	db:execute("DELETE FROM favorites_swap; UPDATE sqlite_sequence SET seq = 0")
	AMM:UpdateSettings()
end

function AMM:SaveAppearance(t)
	local check = 0
	for count in db:urows(f("SELECT COUNT(1) FROM blacklist_appearances WHERE app_name = '%s'", t.appearance)) do
		check = count
	end

	if check ~= 0 then
		local popupInfo = {text = AMM.LocalizableString("Warn_CantSave_BlacklistedAppearance")}
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
	local n
	if t and t.GetTweakDBDisplayName then
		n = t:GetTweakDBDisplayName(true)
	end

	return n
end

function AMM:GetVehicleName(t)
	return tostring(t:GetDisplayName())
end

function AMM:GetObjectName(t)
	return self:GetScanClass(t)
end

function AMM:GetScanID(t)
	if not t then
		log('Error while trying to get tdbid from entity: GetScanID parameter t is nil')
		return
	end

	local tdbid
	local hasRecord
	if type(t) == 'userdata' then
		hasRecord, tdbid = pcall(function() return t:GetRecordID() end)
		if not hasRecord then
			Util:AMMDebug("No Record ID Available For This Target")
			return nil
		end
	else
		tdbid = tostring(TweakDBID.new(t))
	end
	local hash = tostring(tdbid):match("hash%s*=%s*(%g+),")
	local length = tostring(tdbid):match("length%s*=%s*(%d+)")

	if hash == nil or length == nil then
		local msg = f("Target (%s) has strange tweakdbid, this may fail later: %s tostr: %s", t, tdbid, tostring(tdbid))
		spdlog.error(msg)
	end

	-- This should actually maybe error
	local safeHash = hash or ""
	local safeLength = length or 0

	return safeHash..", "..safeLength
end

function AMM:GetScanClass(t)
	local className = t:GetClassName()
	return tostring(className):match("%[ (%g+) -")
end

function AMM:SetCurrentTarget(t)
	if not t then return end

	if self.currentTarget ~= '' then
		if t.id ~= self.currentTarget.id then
			self.currentTarget = t
		end
	else
		self.currentTarget = t
	end
end

function AMM:GetFavoritesAppearances(id)
	local favorites = {}

	local query = f("SELECT app_name FROM favorites_apps WHERE entity_id = '%s' ORDER BY app_name ASC", id)
	for app in db:urows(query) do
		table.insert(favorites, app)
	end

	return favorites
end

local entitiesChecked = {}

function AMM:GetAppearancesFromEntity(id, target, onComplete)
	log("Appearances From Entity: " .. id)
	entitiesChecked[id] = true
	local isPuppet = false
	local collabTag = nil
	local newAppearancesAdded = false

	-- Check for photo mode components
	if AMM.photoModeNPCsExtended and target then
		isPuppet = Util:CheckForPhotoComponent(target)
		collabTag = 'Replacer'
	end

	-- Get entity template path
	local recordID = loadstring("return TweakDBID.new(" .. id .. ")", '')()
	local path = TweakDB:GetFlat(TweakDBID.new(recordID, '.entityTemplatePath'))
	if path then
		local token = Game.GetResourceDepot():LoadResource(path)
		Cron.Every(0.1, { tick = 1 }, function(timer)
			timer.tick = timer.tick + 1

			-- Timeout after 10 ticks (1 second)
			if timer.tick > 10 then
				Cron.Halt(timer)
				if onComplete then onComplete(false) end -- Notify no new appearances were added
			end

			-- If the token is valid, load appearances
			if token then
				local template = token:GetResource()
				local valueList = {}

				-- Prepare appearance insertions
				for _, appearance in ipairs(template.appearances) do
					local appName = NameToString(appearance.name)

					-- Check if appearance already exists in the database
					local query = f("SELECT COUNT(1) FROM appearances WHERE entity_id = '%s' AND app_name = '%s'", id, appName)
					local exists = false

					for count in db:urows(query) do
						if count > 0 then
							exists = true
							break
						end
					end

					-- Add appearance to the insertion list if not already in the database
					if not exists then
						local collabTagValue = collabTag and f("'%s'", collabTag) or "NULL"
						table.insert(valueList, f("('%s', '%s', %s)", id, appName, collabTagValue))
						newAppearancesAdded = true
					end
				end

				-- Insert new appearances into the database
				if #valueList > 0 then
					db:execute(f("INSERT INTO appearances (entity_id, app_name, collab_tag) VALUES " .. table.concat(valueList, ",")))
				end

				-- Stop the timer and invoke the callback
				if onComplete then onComplete(newAppearancesAdded) end
				Cron.Halt(timer)
			end
		end)
	else
		-- If no path, directly call the callback with no new appearances
		if onComplete then onComplete(false) end
	end
end

function AMM:GetAppearanceOptions(t, id)
	if drawWindow then
		local options = {}

		local scanID = id or self:GetScanID(t)
		return self:GetAppearanceOptionsWithID(scanID, t)
	end

	return nil
end

function AMM:GetAppearanceOptionsWithID(id, t)
	local options = {}

	if self.Swap.activeSwaps[id] ~= nil then
		id = self.Swap.activeSwaps[id].newID
	end

	-- Return cached appearance options if available
	if AMM.cachedAppearanceOptions[id] and AMM.Scan.searchQuery == '' then
		return AMM.cachedAppearanceOptions[id]
	end

	-- Skip players or specific entities
	if (t and t.IsPlayer and t:IsPlayer()) or Util:CheckVByID(id) then
		return nil
	end

	-- Separate tables for custom and database appearances
	local customOptions = {}
	local dbOptions = {}

	-- Load database appearances
	if self.Swap.activeSwaps[id] == nil then
		 local searchQuery = ""
		 if AMM.Scan.searchQuery ~= "" then
			  searchQuery = "app_name LIKE '%" .. AMM.Scan.searchQuery .. "%' AND "
		 end

		 local query = f("SELECT app_name FROM appearances WHERE %sentity_id = '%s' AND app_name NOT IN (SELECT app_name FROM favorites_apps WHERE entity_id = '%s') ORDER BY app_name ASC", searchQuery, id, id)

		 if AMM.userSettings.streamerMode then
			  local sql = "SELECT app_name FROM appearances WHERE "
			  local tb = {}
			  for _, word in ipairs(AMM.bannedWords) do
					table.insert(tb, f("app_name NOT LIKE '%%%s%%'", word))
			  end

			  local concatBannedWords = table.concat(tb, " AND ")
			  query = sql .. concatBannedWords .. f(" AND %sentity_id = '%s' ORDER BY app_name ASC", searchQuery, id)
		 end

		 for app in db:urows(query) do
			  table.insert(dbOptions, app)
		 end

		 -- Call GetAppearancesFromEntity if no appearances are found in the database
		 if next(dbOptions) == nil and t ~= nil and ((t.IsNPC and t:IsNPC()) or (t.IsVehicle and t:IsVehicle())) and not entitiesChecked[id] then
			  AMM:GetAppearancesFromEntity(id, t, function(newAppearancesAdded)
					if newAppearancesAdded then
						 AMM.cachedAppearanceOptions[id] = nil
					end
			  end)
		 end
	end

	-- Load custom appearances
	customOptions = self:LoadCustomAppearances({}, id, t)
	
	local favoriteOptions = AMM:GetFavoritesAppearances(id)
	
	-- Combine appearances based on the setting
	if self.customAppPosition == "Top" then
		options = Util:ConcatTables(favoriteOptions, Util:ConcatTables(customOptions, dbOptions)) -- Favorites > Custom > DB
	elseif self.customAppPosition == "Bottom" then
		options = Util:ConcatTables(Util:ConcatTables(dbOptions, customOptions), favoriteOptions) -- DB > Custom > Favorites
	else
		options = Util:ConcatTables(favoriteOptions, dbOptions) -- Favorites > DB (default behavior)
	end

	-- Cache options if the search query is empty
	if next(options) ~= nil then
		if AMM.Scan.searchQuery == '' then
			AMM.cachedAppearanceOptions[id] = options
		end
		return options -- Array of appearance names
	end

	return nil
end

function AMM:GetTweakDBIDFromName(name)
	local id

	for entity_id in db:urows(f("SELECT entity_id FROM entities WHERE entity_name LIKE '%%%s%%' AND entity_path LIKE '%%Character.%%'", name)) do
		id = entity_id
		break
	end

	if id then return id end

	return nil
end

function AMM:GetAppearance(t)
	if t and t ~= '' and t.hash == '' then
		t.hash = tostring(t.handle:GetEntityID().hash)
	end

	-- Check if custom appearance is active
	if t and t ~= '' and self.activeCustomApps[t.hash] ~= nil then
		return self.activeCustomApps[t.hash]
	elseif t and t ~= '' then
		return self:GetScanAppearance(t.handle)
	end
end

function AMM:GetScanAppearance(t)
	if t and t.GetCurrentAppearanceName then
		return NameToString(t:GetCurrentAppearanceName())
	end

	log("[AMM Error] Target was invalid while trying to get appearance")
	return nil
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

--------------------------------------------------------------------------------
-- 1) A helper function to check if a custom appearance base is actually valid
--    for the current entity. If puppet, do FindEquivalentAppearanceInRegularEntity.
--------------------------------------------------------------------------------
function AMM:IsValidCustomAppearanceForEntity(entityID, target, appBase)
	-- Edge case: no base? Just fail it.
	if not appBase or appBase == "" then
	  return false
	end
 
	-- Possibly fetch or refresh the "non puppets" appearances from the DB for this entity
	-- so we can see if "appBase" is even in the entity’s normal list.
	local possibleAppearances = {}
 
	for appearance in db:urows(string.format("SELECT app_name FROM appearances WHERE entity_id = '%s'", entityID)) do
	  table.insert(possibleAppearances, appearance)
	end
 
	-- If this is a puppet, we need to see if there’s an equivalent base in the “real” entity’s appearances
	if target and Util:CheckForPhotoComponent(target) then
	  local found = AMM:FindEquivalentAppearanceInRegularEntity(possibleAppearances, appBase, AMM:GetNPCName(target))
	  return (found ~= nil)  -- true if we found a match
	else
	  -- For a normal entity, just see if appBase is actually in its appearance list
	  for _, ap in ipairs(possibleAppearances) do
		 if ap == appBase then
			return true
		 end
	  end
	  return false
	end
 end
 
 --------------------------------------------------------------------------------
 -- 2) Refactored LoadCustomAppearances:
 --    - We SELECT both app_name and app_base
 --    - We check if app_base is valid for this entity before adding to 'options'
 --------------------------------------------------------------------------------
 function AMM:LoadCustomAppearances(options, id, t)
	local originalID = id

	local searchQuery = ""
	if AMM.Scan.searchQuery ~= "" then
	  searchQuery = "app_name LIKE '%"..AMM.Scan.searchQuery.."%' AND "
	end
 
	------------------------------------------------------------------------------
	-- Because some puppet NPCs have IDs that differ from their 'real' entity,
	-- we do the usual fallback to TweakDB ID if needed.
	------------------------------------------------------------------------------
	
	local inClauseIDs = { id }
	
	if t and Util:CheckForPhotoComponent(t) then
		local name  = AMM:GetNPCName(t)
		local tdbid = AMM:GetTweakDBIDFromName(name)
		if tdbid and tdbid ~= id then
   		table.insert(inClauseIDs, tdbid)
   	end
	end

	-- Build the final "('ID1','ID2',...)" string for SQL
  local entityIDs = "('" .. table.concat(inClauseIDs, "','") .. "')"
 
	------------------------------------------------------------------------------
	-- If we have collabs, we first load appearances that match collab tags/metadata
	------------------------------------------------------------------------------
	if #AMM.collabs ~= 0 then
	  -- Build an IN-list for "app_base NOT IN (...)"
	  local collabsAppBase = "("
	  for i, collab in ipairs(AMM.collabs) do
		 collabsAppBase = collabsAppBase .. string.format("'%s'", collab.appearance)
		 if i ~= #AMM.collabs then 
			collabsAppBase = collabsAppBase .. ", " 
		 end
 
		 -- The old code used a separate query just for that collab. 
		 -- Let's unify that so we can also get app_base in the same pass.
		 local sqlCollab = string.format(
			"SELECT DISTINCT app_name, app_base "
			.."FROM custom_appearances "
			.."WHERE %scollab_tag = '%s' AND entity_id IN %s "
			.."ORDER BY app_name ASC",
			searchQuery, collab.tag, entityIDs
		 )
 
		 for appName, base in db:urows(sqlCollab) do
			-- Check if base is actually valid for this entity
			if AMM:IsValidCustomAppearanceForEntity(originalID, t, base) then
			  table.insert(options, appName)
			end
		 end
	  end
	  collabsAppBase = collabsAppBase .. ")"
 
	  ----------------------------------------------------------------------------
	  -- Then we get leftover "AMM" or nil collab_tag appearances
	  ----------------------------------------------------------------------------
	  local leftoverSQL = string.format(
		 "SELECT DISTINCT app_name, app_base "
		 .."FROM custom_appearances "
		 .."WHERE %s(collab_tag IS NULL OR collab_tag = 'AMM') "
		 .."AND entity_id IN %s "
		 .."ORDER BY app_name ASC",
		 searchQuery, entityIDs
	  )
 
	  for appName, base in db:urows(leftoverSQL) do
		 if AMM:IsValidCustomAppearanceForEntity(originalID, t, base) then
			table.insert(options, appName)
		 end
	  end
 
	------------------------------------------------------------------------------
	-- If we have NO collabs, just load 'AMM' or nil collab_tag
	------------------------------------------------------------------------------
	else
	  local leftoverSQL = string.format(
		 "SELECT DISTINCT app_name, app_base "
		 .."FROM custom_appearances "
		 .."WHERE %s(collab_tag IS NULL OR collab_tag = 'AMM') "
		 .."AND entity_id IN %s "
		 .."ORDER BY app_name ASC",
		 searchQuery, entityIDs
	  )
 
	  for appName, base in db:urows(leftoverSQL) do
		 if AMM:IsValidCustomAppearanceForEntity(originalID, t, base) then
			table.insert(options, appName)
		 end
	  end
	end
 
	return options
 end
 
 --------------------------------------------------------------------------------
 -- 3) GetCustomAppearanceParams remains mostly the same. However, it also tries
 --    to validate puppet appearances by calling FindEquivalentAppearanceInRegularEntity.
 --    This is good! Now both LoadCustomAppearances() and GetCustomAppearanceParams()
 --    enforce that "the entity can actually use that custom appearance."
 --------------------------------------------------------------------------------
 function AMM:GetCustomAppearanceParams(target, appearance, reverse)
	local collabTag
	local targetID = target.id
	local inClauseIDs = { targetID }

	if target.isPuppet then
		local name  = AMM:GetNPCName(target.handle)
		local tdbid = AMM:GetTweakDBIDFromName(name)
		if tdbid and tdbid ~= targetID then
   		table.insert(inClauseIDs, tdbid)
   	end
	end

	-- Build the final "('ID1','ID2',...)" string for SQL
  local entityIDs = "('" .. table.concat(inClauseIDs, "','") .. "')"
 
	-- Figure out which collab tag (if any) this custom appearance belongs to
	if #AMM.collabs > 0 then
	  for _, collab in ipairs(AMM.collabs) do
		 local check = 0
		 for count in db:urows(string.format(
			"SELECT COUNT(1) FROM custom_appearances "
			.."WHERE entity_id IN %s AND app_name = '%s' AND collab_tag = '%s'",
			entityIDs, appearance, collab.tag
		 )) do
			check = count
			break
		 end
		 if check ~= 0 then
			collabTag = collab.tag
			break
		 end
	  end
	end
 
	-- If not found, see if it belongs to 'AMM'
	if collabTag == nil then
	  local check = 0
	  for count in db:urows(string.format(
		 "SELECT COUNT(1) FROM custom_appearances "
		 .."WHERE entity_id IN %s AND app_name = '%s' AND collab_tag = 'AMM'",
		 entityIDs, appearance
	  )) do
		 check = count
		 break
	  end
	  if check ~= 0 then
		 collabTag = 'AMM'
	  end
	end
 
	------------------------------------------------------------------------------
	-- Now gather all rows that match this entity, app_name, and collabTag
	------------------------------------------------------------------------------
	local custom = {}
	local query = string.format(
	  "SELECT * FROM custom_appearances "
	  .."WHERE app_name = '%s' AND entity_id IN %s AND collab_tag IS '%s'",
	  appearance, entityIDs, collabTag
	)
	query = query:gsub("'nil'", "NULL")  -- patch any leftover 'nil'
 
	for app in db:nrows(query) do
	  app.app_toggle = intToBool(app.app_toggle)
 
	  -- If target is puppet, let's see if the entity has standard appearances at all
	  if target.isPuppet then
		 local cnt = 0
		 for c in db:urows(string.format("SELECT COUNT(1) FROM appearances WHERE entity_id = '%s'", target.id)) do
			cnt = c
			break
		 end
 
		 if cnt == 0 then
			AMM:GetAppearancesFromEntity(target.id, target.handle)
		 end
 
		 local possibleAppearances = {}
		 for a in db:urows(string.format("SELECT app_name FROM appearances WHERE entity_id = '%s'", target.id)) do
			table.insert(possibleAppearances, a)
		 end
 
		 local found = nil
		 if #possibleAppearances > 0 then
			found = AMM:FindEquivalentAppearanceInRegularEntity(possibleAppearances, app.app_base, target.name)
		 end
 
		 if found then
			app.app_base = found
		 else
			log(string.format("[AMM Error] No equivalent appearance found for NPC: %s", target.name))
		 end
	  end
 
	  table.insert(custom, app)
	end
 
	return custom
 end

function AMM:CheckSingleTokenOverride(puppetTokens, realTokens)
	-- If real side has exactly 1 token
	if #realTokens == 1 then
		local puppetLast = puppetTokens[#puppetTokens]
		if puppetLast == realTokens[1] then
			-- CASE A: Both sides single token => perfect match
			if #puppetTokens == 1 then
				return 1.0
			else
				-- CASE B: Puppet has multiple tokens, real side is single token
				-- but the last puppet token matches exactly => partial override
				return 0.8  -- you can adjust this value
			end
		end
	end

	return nil
end 

function AMM:AddEndingTokenBonus(strA, strB, oldRatio)
	-- Convert underscores to spaces, split into tokens, grab the last token
	local function getTokens(s)
	  if not s or s == "" then return {} end
	  s = s:lower():gsub("_+", " ")
	  local tokens = {}
	  for word in s:gmatch("%S+") do
		 table.insert(tokens, word)
	  end
	  return tokens
	end
 
	local tokensA = getTokens(strA)
	local tokensB = getTokens(strB)
	if #tokensA == 0 or #tokensB == 0 then
	  return oldRatio
	end
 
	local lastA = tokensA[#tokensA]
	local lastB = tokensB[#tokensB]
 
	-- If they exactly match, give a small bonus
	if lastA == lastB then
	  local newRatio = math.min(1.0, oldRatio + 0.2)
	  return newRatio
	end
 
	return oldRatio
 end 

 function AMM:RemoveNpcNamePrefix(appearanceName, npcName)
	if not appearanceName or appearanceName == "" then return appearanceName end
	if not npcName or npcName == "" then return appearanceName end
 
	-- both to lower
	local aLower = appearanceName:lower()
	local nLower = npcName:lower()
 
	-- if it starts with e.g. "judy_"
	-- note we also remove trailing underscores if multiple
	if aLower:find("^" .. nLower .. "_+") then
	  -- substring from the length of npcName + 2 onward
	  local offset = #npcName + 2
	  return appearanceName:sub(offset)
	end
 
	return appearanceName
 end

 -- Special Cases for Appearances that are too hard to match
local SPECIAL_OVERRIDES = {
	["songbird_paradise"] = "Dress",
	["songbird__q304__exhausted"] = "Exhausted",
	["songbird__q306__exhausted"] = "Exhausted 2",
	['songbird_blendable'] = 'Past Self',
 } 

function AMM:FindEquivalentAppearanceInRegularEntity(possibleAppearances, app_base, npcName)

	if not possibleAppearances or #possibleAppearances == 0 
		or not app_base or app_base == "" then
	  return nil
	end

	-- Check manual overrides first
	local manualTarget = SPECIAL_OVERRIDES[app_base]
	if manualTarget then
		return manualTarget
	end
 
	if npcName and npcName ~= "" then
	  app_base = self:RemoveNpcNamePrefix(app_base, npcName)
	end
 
	local bestMatch  = nil
	local bestRatio  = 0.0
	local threshold  = 0.6  -- tune as needed
 
	-- We'll pre‐tokenize puppet side once
	local function tokenize(s)
	  s = s:lower():gsub("_+", " ")
	  local tokens = {}
	  for word in s:gmatch("%S+") do
		 table.insert(tokens, word)
	  end
	  return tokens
	end

	local puppetTokens = tokenize(app_base)
	for _, realApp in ipairs(possibleAppearances) do
	  if not realApp:lower():match("^custom") then
 
		 -- a) tokenize real side
		 local realTokens = tokenize(realApp)
 
		 -- b) single‐token override check
		 local overrideRatio = self:CheckSingleTokenOverride(puppetTokens, realTokens)
		 local ratio = 0.0
 
		 if overrideRatio then
			-- If override is 1.0, no need to do fuzzy
			if overrideRatio == 1.0 then
			  ratio = 1.0
			else
			  -- partial override (e.g. 0.8) => do multi‐token too, pick bigger
			  local fuzzy = Util:CompareStringsTokenWise(app_base, realApp)
			  local finalFuzzy = self:AddEndingTokenBonus(app_base, realApp, fuzzy)
			  ratio = math.max(overrideRatio, finalFuzzy)
			end
		 else
			-- c) no override => just do the fuzzy approach
			local fuzzy = Util:CompareStringsTokenWise(app_base, realApp)
			ratio = self:AddEndingTokenBonus(app_base, realApp, fuzzy)
		 end
 
		 -- d) track the best ratio
		 if ratio > bestRatio then
			bestRatio = ratio
			bestMatch = realApp			
		 end
	  end
	end
 
	-- if best ratio < threshold => no match
	if bestRatio < threshold then
	  return nil
	end
	
	return bestMatch
end
 
function AMM:ChangeScanCustomAppearanceTo(t, customAppearance)
	-- First, set the base appearance as usual
	self:ChangeScanAppearanceTo(t, customAppearance[1].app_base)

	-- Update activeCustomApps tracking (optional usage)
	if self.activeCustomApps[t.hash] ~= 'reverse' then
		 self.activeCustomApps[t.hash] = customAppearance[1].app_name
	else
		 self.activeCustomApps[t.hash] = nil
	end

	Cron.After(0.1, function()
		local handle = t.handle
		local currentAppearance = self:GetScanAppearance(handle)

		if currentAppearance == customAppearance[1].app_base then

			 -- Gather all components from this entity
			 local components = handle:GetComponents()

			 -- Outer loop: go through every component
			 for _, comp in ipairs(components) do
				  local compName = NameToString(comp:GetName())

				  -- 1) If the comp name is AppearanceProxyMesh, toggle it off
				  if compName == "AppearanceProxyMesh" then
						comp:Toggle(false)
				  end

				  -- 2) If LODMode property exists, force AlwaysVisible
				  if comp.LODMode ~= nil then
						comp.LODMode = entMeshComponentLODMode.AlwaysVisible
				  end

				  -- Inner loop: compare this component with each appearance param
				  for _, param in ipairs(customAppearance) do
						if compName == param.app_param then
							 --------------------------------------------------------------
							 -- Resource change section
							 --------------------------------------------------------------
							 if param.mesh_path and comp.ChangeResource then
								  comp:ChangeResource(param.mesh_path, true)
							 end

							 --------------------------------------------------------------
							 -- Mesh appearance section
							 --------------------------------------------------------------
							 if param.mesh_app then
								  comp.meshAppearance = CName.new(param.mesh_app)
								  if comp.LoadAppearance then
										comp:LoadAppearance(true)
								  end
							 end

							 --------------------------------------------------------------
							 -- Mesh mask logic
							 --------------------------------------------------------------
							 if param.mesh_mask ~= 'no_change'
								 and comp.chunkMask ~= param.mesh_mask
								 and not string.find(param.app_name, "Underwear") then

								  if param.mesh_mask then
										param.mesh_mask = loadstring("return "..param.mesh_mask, '')()

										if param.app_toggle then
											 comp.chunkMask = param.mesh_mask
										elseif comp.chunkMask ~= 18446744073709551615ULL then
											 comp.chunkMask = bit32.bor(param.mesh_mask, comp.chunkMask)
										else
											 comp.chunkMask = 18446744073709551615ULL
										end
								  else
										if param.mesh_type ~= "body" and not param.app_toggle then
											 comp.chunkMask = 0
										else
											 comp.chunkMask = 18446744073709551615ULL
										end
								  end
							 end

							 --------------------------------------------------------------
							 -- Toggling / visibility logic
							 --------------------------------------------------------------
							 local isSkinned = string.find(param.app_param, "SkinnedCloth")
							 if isSkinned and not param.app_toggle then
								  comp.physicsSimulationType = physicsSimulationType.Static
								  Cron.After(0.2, function()
										comp:TemporaryHide(true)
								  end)
							 else
								  comp:Toggle(false)
								  if param.app_toggle or param.mesh_type == "body" then
										comp:TemporaryHide(false)
										comp:Toggle(true)
								  else
										comp:TemporaryHide(true)
								  end
							 end

							 -- Found a param match—stop checking other params for this component
							 break
						end -- if compName == param.app_param
				  end -- for each param
			 end -- for each component
		end -- if currentAppearance == ...
  end) -- Cron.After
end

function AMM:ChangeScanAppearanceTo(t, newAppearance)
	if t.archetype ~= "mech" then

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
	if entity.type == "Prop" and not entity.handle:IsNPC() and not entity.isVehicle then
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

				if AMM.userSettings.streamerMode and AMM:CheckAppearanceForBannedWords(entity.appearance) then
					AMM:ChangeAppearanceTo(entity, 'Cycle')
				end
			end)
		end)
	end
end

function AMM:GetTarget()
	local player = Game.GetPlayer()
	
	if player then
		local target = Game.GetTargetingSystem():GetLookAtObject(player, true, false) or Game.GetTargetingSystem():GetLookAtObject(player, false, false)
		local t = nil

		if target ~= nil then

			-- Checking ID of that stupid explosive car that for some reason crashes the game when AMM calls NewTarget() on it
			local id = AMM:GetScanID(target)
			if id == "0x62701058, 29" then return nil end

			if target:IsNPC() or target:IsReplacer() then
				t = AMM:NewTarget(target, AMM:GetScanClass(target), AMM:GetScanID(target), AMM:GetNPCName(target), AMM:GetScanAppearance(target), AMM:GetAppearanceOptions(target))
			elseif target:IsVehicle() then
				t = AMM:NewTarget(target, 'vehicle', AMM:GetScanID(target), AMM:GetVehicleName(target), AMM:GetScanAppearance(target), AMM:GetAppearanceOptions(target))
			else
				t = AMM:NewTarget(target, AMM:GetScanClass(target), "None", AMM:GetObjectName(target), AMM:GetScanAppearance(target), nil)
			end

			if t ~= nil and t.name ~= "gameuiWorldMapGameObject" and t.name ~= "ScriptedWeakspotObject" then
				-- AMM:SetCurrentTarget(t)
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

function AMM:GetFollowDistanceOptions()
	local options = {
		{"Close", 1, 2, 3},
		{"Nearby", 3, 5, 6},
		{"Default", 99, 99, 99},
	}

	-- Set Default
	AMM.followDistance = options[3]
	return options
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
	for _, companion in pairs(AMM.Spawn.spawnedNPCs) do
		if companion.handle.isPlayerCompanionCached then
			if followDistance == 99 and companion.activeCommand then
				Util:CancelCommand(companion.handle, companion.activeCommand)
				companion.activeCommand = nil
			elseif followDistance ~= 99 then
				companion.activeCommand, _ = Util:FollowTarget(companion.handle, Game.GetPlayer(), followDistance)
			end
		end
	end
end

function AMM:ResetFollowCommandAfterAction(ent, action)
	local companionFollowCommand = ent.activeCommand
	if companionFollowCommand then
		if not Util:CancelCommand(ent.handle, ent.activeCommand) then

			action(ent.handle, param)

			Cron.After(3.0, function()
				AMM:UpdateFollowDistance()
			end)
		end
	else
		action(ent.handle, param)
	end
end

function AMM:CheckCompanionDistances()
  Cron.Every(1.0, function()
    if next(AMM.Spawn.spawnedNPCs) == nil then
      return
    end

    local player = Game.GetPlayer()
    if not player then return end

    local playerPos = player:GetWorldPosition()

    for _, spawn in pairs(AMM.Spawn.spawnedNPCs) do
      if spawn.entityID and spawn.handle and spawn.handle:IsNPC() then
        local npcPos = spawn.handle:GetWorldPosition()
        local distance = Util:VectorDistance(playerPos, npcPos)

        if distance > 3 then
          if not spawn.farDistance then
            spawn.farDistance = true
				AMM:UpdateFollowDistance()
          end
        else
          -- They are now within 3 meters
          if spawn.farDistance then
            spawn.farDistance = false
            Util:RotateTo(spawn.handle)
          end
        end
      end
    end
  end)
end

 function AMM:RefreshAppearance(spawn)
	-- Sanity checks
	if not spawn or not spawn.handle or spawn.handle == '' then return end
 
	-- Use the stored appearance:
	local currentAppearance = spawn.appearance or "default"
	self:ChangeAppearanceTo(spawn, currentAppearance)
 end
 

function AMM:ChangeNPCEquipment(ent, equipmentPath)
	local npcPath = ent.path
	TweakDB:SetFlat(TweakDBID.new(npcPath..".primaryEquipment"), TweakDBID.new(equipmentPath))
	
	AMM:ResetFollowCommandAfterAction(ent, function(handle)
		Util:EquipPrimaryWeaponCommand(handle)
	end)

	-- AMM.Spawn:Respawn(ent)

	-- New Approach: Inventory
	-- local equipmentItems = TweakDB:GetFlat(equipmentPath..".equipmentItems")
	-- local primaryEquipRecord = TweakDB:GetFlat(TweakDBID.new(equipmentItems[1], ".item"))
	-- local weaponTDBID = TweakDB:GetRecord(primaryEquipRecord)
	-- local itemID = ItemID.FromTDBID(weaponTDBID.tdbid)
  	-- local quantity = 1

  	-- Game.GetTransactionSystem():GiveItem(ent.handle, itemID, quantity)
   -- Util:EquipGivenWeapon(ent.handle, weaponTDBID, true)
end

function AMM:ProcessCompanionAttack(hitEvent)
	local instigatorNPC = hitEvent.attackData:GetInstigator()
	local dmgType = hitEvent.attackComputed:GetDominatingDamageType()

	if instigatorNPC then
		if instigatorNPC.IsPlayerCompanion and instigatorNPC:IsPlayerCompanion() then
			if hitEvent.target and hitEvent.target:IsPlayer() then return end
			if AMM.companionAttackMultiplier ~= 0 then
				hitEvent.attackComputed:MultAttackValue(AMM.companionAttackMultiplier, dmgType)
			end
		else -- Attacker is not companion
			if hitEvent.target and ((hitEvent.target.IsPlayerCompanion and hitEvent.target:IsPlayerCompanion()) or hitEvent.target.isPlayerCompanionCached) then
				if AMM.companionResistanceMultiplier ~= 0 then
					local multiplier = 1 - (AMM.companionResistanceMultiplier / 100) -- Invert the multiplier
					hitEvent.attackComputed:MultAttackValue(multiplier, dmgType)
				end
			end
		end
	end
end

-- Helper methods
function AMM:CreateBusInteractionPrompt(t)
	if GetVersion() == "v1.15.0" or AMM.playerInVehicle then return end
  
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

function AMM:BusPromptAction()
	if AMM.playerInVehicle then return end
	local target = Game.GetTargetingSystem():GetLookAtObject(AMM.player, false, false)

	if target == nil or not target:IsVehicle() or not AMM.displayInteractionPrompt then return end

	local seat = "seat_front_left"
	if AMM.Scan.selectedSeats["Player"] then seat = AMM.Scan.selectedSeats["Player"].seat.cname end
	AMM.Scan:MountPlayer(seat, target)
	Util:SetInteractionHub("Enter Bus", "Choice1", false)
end

function AMM:IsUnique(npcID)
	for _, v in ipairs(self.allowedNPCs) do
		if npcID == v then
			-- NPC is unique
			return true
		end
	end
end

local stringConstNone = "None"

function AMM:IsSpawnable(t)
	local spawnableID = nil

	if t.appearance == stringConstNone then -- check if "None"
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

function AMM:OpenPopup(name)
	local sizeX = ImGui.GetWindowSize()
	local x, y = ImGui.GetWindowPos()

	-- Calculate position
	ImGui.SetNextWindowPos(x + ((sizeX / 2) - 200), y - 40)

	-- Prepare a popup delegate
	local popupDelegate = {message = '', buttons = {}}
	local popupWidth = 0
	local popupHeight = 0

	if string.find(name, "Equipment") then
		popupDelegate.message = "Select " .. name .. ":"
		for _, equipment in ipairs(self.equipmentOptions) do
			table.insert(popupDelegate.buttons, {
				label = equipment.name,
				action = function(ent) AMM:ChangeNPCEquipment(ent, equipment.path) end
			})
		end
	elseif name == "Experimental" then
		popupDelegate.message = AMM.LocalizableString("Warn_ConfirmEnableExperimentalAndSave_Info")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = ''})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = function() AMM.userSettings.experimental = false end})
		name = AMM.LocalizableString("Warning")
	elseif name == "Favorites" then
		popupDelegate.message = AMM.LocalizableString("Warn_DeleteFavoritesAskWhichOne_Info")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Label_SpawnFavorites"), action = function() AMM:ClearAllFavorites() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Label_SwapFavorites"), action = function() AMM:ClearAllSwapFavorites() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Label_FavoriteAppearances"), action = function() AMM:ClearAllFavoriteAppearances() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Label_Cancel"), action = ''})
		name = AMM.LocalizableString("Warning")
	elseif name == "Appearances" then
		popupDelegate.message = AMM.LocalizableString("Warn_ConfirmDeleteSavedAppearances")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = function() AMM:ClearAllSavedAppearances() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = ''})
		name = AMM.LocalizableString("Warning")
	elseif name == "Blacklist" then
		popupDelegate.message = AMM.LocalizableString("Warn_ConfirmDeleteBlacklistedAppearances")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = function() AMM:ClearAllBlacklistedAppearances() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = ''})
		name = AMM.LocalizableString("Warning")name = AMM.LocalizableString("Warning")
	elseif name == "Saved Despawns" then
		popupDelegate.message = AMM.LocalizableString("Warn_ConfirmDeleteSavedDespawns")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = function() AMM:ClearAllSavedDespawns() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = ''})
		name = AMM.LocalizableString("Warning")
	elseif name == "Appearance Triggers" then
		popupDelegate.message = AMM.LocalizableString("Warn_ConfirmDeleteAppearanceTriggers")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = function() AMM:ClearAllAppearanceTriggers() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = ''})
		name = AMM.LocalizableString("Warning")
	elseif name == "Preset" then
		popupDelegate.message = AMM.LocalizableString("Warn_ConfirmDeleteCurrentAppearance")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = function() AMM.Props:DeletePreset(AMM.Props.activePreset) end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = ''})
		name = AMM.LocalizableString("Warning")
	elseif name == "Weaponize" then
		popupDelegate.message = AMM.LocalizableString("Warn_WeaponizeNpcAnimationIssues")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = ''})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = function() AMM.userSettings.weaponizeNPC = false end})
		name = AMM.LocalizableString("Warning")
	elseif name == "Despawn All" then
		popupDelegate.message = AMM.LocalizableString("Warn_DespawnAllProps")
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_Yes"), action = function() AMM.Props:DespawnAllSpawnedProps() end})
		table.insert(popupDelegate.buttons, {label = AMM.LocalizableString("Button_No"), action = ''})
		name = AMM.LocalizableString("Warning")
	end

	-- Dynamically calculate width based on button text
	local messageWidth = ImGui.CalcTextSize(popupDelegate.message) + 40
	local buttonWidth = 0

	for _, button in ipairs(popupDelegate.buttons) do
		buttonWidth = math.max(buttonWidth, ImGui.CalcTextSize(button.label) + 20)
	end

	popupWidth = math.max(messageWidth, buttonWidth)
	popupHeight = 40 + (#popupDelegate.buttons * 66)

	 -- Adjust the popup size dynamically
    popupWidth = math.max(popupWidth, 300) -- Minimum width
    popupHeight = math.max(popupHeight, 140) -- Minimum height
    ImGui.SetNextWindowSize(popupWidth, popupHeight)

	ImGui.OpenPopup(name)
	return popupDelegate
end

function AMM:BeginPopup(popupTitle, popupActionArg, popupModal, popupDelegate, style)
	local popup
	if popupModal then
		popup = ImGui.BeginPopupModal(popupTitle, ImGuiWindowFlags.NoResize)
	else
		popup = ImGui.BeginPopup(popupTitle, ImGuiWindowFlags.NoResize)
	end
	if popup then
		 -- Display the message
		 ImGui.TextWrapped(popupDelegate.message)

		-- Add an invisible spacer to stabilize the layout
		local spacerWidth = ImGui.GetWindowContentRegionWidth()
		ImGui.Dummy(spacerWidth, 0)

		-- Display buttons
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
			AMM:ChangeAppearanceTo(target, 'Cycle')
		elseif action == "Save" then
			AMM:SaveAppearance(target)
			AMM.Scan.currentSavedApp = nil
		elseif action == "Clear" then
			AMM:ClearSavedAppearance(target)
			AMM.Scan.currentSavedApp = nil
		elseif action == "Blacklist" then
			AMM:BlacklistAppearance(target)
			AMM.Scan.currentAppIsBlacklisted = nil
		elseif action == "Unblacklist" then
			AMM:RemoveFromBlacklist(target)
			AMM.Scan.currentAppIsBlacklisted = nil
		elseif action == "SpawnNPC" then
			AMM.Spawn:SpawnNPC(target)
			buttonPressed = true
		elseif action == "SpawnVehicle" then
			AMM.Spawn:SpawnVehicle(target)
			buttonPressed = true
		elseif action == "SpawnProp" then
			AMM.Props:SpawnProp(target)
		elseif action == "Favorite" then
			AMM.Scan:ToggleAppearanceAsFavorite(target)
			AMM.Scan.currentAppIsFavorite = nil
		end
	end
end

function AMM:DrawHotkeySelection(target)
	if AMM.selectedHotkeys[target.id] == nil then
		AMM.selectedHotkeys[target.id] = {'', '', ''}
	end

	for i, hotkey in ipairs(AMM.selectedHotkeys[target.id]) do
		local app = hotkey ~= '' and hotkey or AMM.LocalizableString("NoAppearanceSet")
		ImGui.InputText(f(AMM.LocalizableString("Hotkey_i"), i), app, 100, ImGuiInputTextFlags.ReadOnly)

		ImGui.SameLine()

		if ImGui.SmallButton(AMM.LocalizableString("Button_SmallSet").."##"..i) then
			AMM.selectedHotkeys[target.id][i] = target.appearance
		end
	end
end

function AMM:DrawArchives()
	AMM.UI:TextColored(AMM.LocalizableString("AMMNeedsAttention"))

	if not Codeware then
		ImGui.TextWrapped(AMM.LocalizableString("Warning_MissingCodeware"))
	else
		local missingRequired = not AMM.archivesInfo.optional
		
		if missingRequired then
			ImGui.TextWrapped(AMM.LocalizableString("Warning_MissingRequiredArchives"))
		else
			ImGui.TextWrapped(AMM.LocalizableString("Warning_MissingOptionalArchives"))
		end
	end

	AMM.UI:Separator()

	local GameVersion = Game.GetSystemRequestsHandler():GetGameVersion()

	AMM.UI:TextCenter(AMM.LocalizableString("VERSION_INFORMATION"))
	ImGui.Spacing()
	AMM.UI:TextCenter(AMM.LocalizableString("AMM_Version"), true)
	ImGui.SameLine()
	ImGui.Text(AMM.currentVersion)
	ImGui.Spacing()
	AMM.UI:TextCenter(AMM.LocalizableString("CET_Version"), true)
	ImGui.SameLine()
	ImGui.Text(GetVersion())
	ImGui.Spacing()
	if Codeware then
		AMM.UI:TextCenter(AMM.LocalizableString("Codeware_Version"), true)
		ImGui.SameLine()
		ImGui.Text(Codeware.Version())
	else
		AMM.UI:TextCenter(AMM.LocalizableString("Codeware_Version"), true)
		ImGui.SameLine()
		AMM.UI:TextError(AMM.LocalizableString("Warn_NotInstalled"))
	end
	ImGui.Spacing()
	AMM.UI:TextCenter(AMM.LocalizableString("Game_Version")..Game.GetSystemRequestsHandler():GetGameVersion(), true)
	
	AMM.UI:Separator()

	if not missingRequired and Codeware then
		if ImGui.Button(AMM.LocalizableString("Button_Ignorewarningsforthisversion"), ImGui.GetWindowContentRegionWidth(), 40) then
			db:execute("UPDATE metadata SET ignore_archives = 1")
			AMM:CheckMissingArchives()
		end
		AMM.UI:Separator()
	end


	for _, archive in ipairs(AMM.archives) do
		AMM.UI:TextColored(archive.name)

		if not archive.active then
			ImGui.SameLine()
			AMM.UI:TextError(AMM.LocalizableString(" MISSING"))

			if not archive.optional then
				ImGui.SameLine()
				AMM.UI:TextError(AMM.LocalizableString("REQUIRED"))
				missingRequired = true
			else
				ImGui.SameLine()
				AMM.UI:TextError(AMM.LocalizableString("OPTIONAL"))
			end
		end

		ImGui.TextWrapped(archive.desc)

		AMM.UI:Spacing(4)
	end	
end

function AMM:GetLanguageIndex(langStr)

	if #AMM.availableLanguages == 0 then
		AMM.availableLanguages = AMM:GetLocalizationLanguages()
	end

	for i, lang in ipairs(AMM.availableLanguages) do
		if lang.name == langStr then
			AMM.currentLanguage = lang.strings
			return i
		end
	end

	-- Instead of always defaulting to 1, check if "en_US" exists
	for i, lang in ipairs(AMM.availableLanguages) do
		if lang.name == "en_US" then
			AMM.currentLanguage = lang.strings
			return i
		end
	end
	
  	-- If "en_US" is somehow missing, return the first available language
	return 1
end

function AMM:GetLocalizationLanguages()
	local languages = {}
	local files = dir("./Localization")

	-- Ensure files are always sorted alphabetically
	table.sort(files, function(a, b)
		return a.name < b.name
  	end)

	for _, loc in ipairs(files) do
		if string.find(loc.name, '.lua') then
			local localizableStrings = AMM:PreloadLanguage(loc.name)
			if localizableStrings then
				table.insert(languages, {name = loc.name:gsub(".lua", ""), strings = localizableStrings})
			end
		end
	end

	return languages
end

function AMM:PreloadLanguage(lang)
	local strings = require("Localization/"..lang)
	if not strings then
		print("Language file is invalid: "..lang)
		return false
	end
	return strings
end

-- Songbird Immersion Methods
function AMM:SBInitialize()
	AMM.SBLocations = {
		{
		-- Red Dirt
			locs = {
				{ent = 'songbird_lean', pos = Vector4.new(-733.955, -1007.806, 8.004, 1), angles = EulerAngles.new(0, 0, 55.759), apps = {'default', 'casual', 'casual_alt'}},
				{ent = 'songbird_sit_stool', pos = Vector4.new(-730.423, -1009.008, 8.204, 1), angles = EulerAngles.new(0, 0, -55.010), apps = {'default', 'casual', 'casual_alt'}},
			},

			pos = Vector4.new(-733.955, -1007.806, 8.004, 1),
			time = {startTime = 18, endTime = 23},
			chance = 50,
		},
		-- Empathy
		{
			locs = {
				{ent = 'songbird_lean', pos = Vector4.new(-1638.851, 381.142, 8.115, 1), angles = EulerAngles.new(0, 0, 180), apps = {'casual', 'night_out'}},
				{ent = 'songbird_dance', pos = Vector4.new(-1630.422, 386.515, 7.697, 1), angles = EulerAngles.new(0, 0, 180), apps = {'casual', 'night_out'}},
				{ent = 'songbird_sit_stool_lean_left', pos = Vector4.new(-1639.469, 384.896, 8.101, 1), angles = EulerAngles.new(0, 0, -96.923), apps = {'casual', 'night_out'}},
			},

			pos = Vector4.new(-1630.422, 386.515, 7.697, 1),
			time = {startTime = 21, endTime = 28},
			chance = 30,
		},
		-- Charter Hill
		{
			locs = {
				{ent = 'songbird_lean', pos = Vector4.new(22.314, -43.276, 14.829, 1), angles = EulerAngles.new(0, 0, -123.118), apps = {'casual', 'casual_alt', 'sport'}},
				{ent = 'songbird_lean_rail_look_around', pos = Vector4.new(24.711, -46.334, 14.841, 1), angles = EulerAngles.new(0, 0, -112.640), apps = {'casual', 'casual_alt', 'sport'}},
			},

			pos = Vector4.new(22.314, -43.276, 14.829, 1),
			time = {startTime = 14, endTime = 18},
			chance = 60,
		},
		-- Pond
		{
			locs = {
				{ent = 'songbird_lie_sunbed', pos = Vector4.new(-1555.949, -373.895, -13.022, 1), angles = EulerAngles.new(0, 0, 180), apps = {'sport'}},	
			},

			pos = Vector4.new(-1555.949, -373.895, -13.022, 1),
			time = {startTime = 10, endTime = 12},
			chance = 40,
		},
		-- Netrunner
		{
			locs = {
				{ent = 'songbird_lie_netrunner', pos = Vector4.new(-346.525, 1366.207, 42.568, 1), angles = EulerAngles.new(0, 0, 114.000), apps = {'netrunner'}, npcs = {'0x3AC2B288, 41'}},	
			},

			pos = Vector4.new(-345.980, 1366.422, 42.898, 1),
			time = {startTime = 23, endTime = 26},
			chance = 20,
		},
		-- Wakako
		{
			locs = {
				{ent = 'songbird_sit_couch_rh_couch', pos = Vector4.new(-670.729, 825.584, 19.522, 1), angles = EulerAngles.new(0, 0, 180), apps = {'casual', 'casual_alt', 'default', 'home'}},
				{
					ent = 'songbird_lie_sunbed', pos = Vector4.new(-670.090, 825.754, 19.592, 1), angles = EulerAngles.new(0, 0, -167.277), apps = {'casual', 'casual_alt'}, 
					chunkMask = {"s1_058_wa_boot__rogue4857"}, items = {
						{ent = [[base\characters\garment\citizen_casual\feet\s1_058_wa_boot__rogue.ent]], pos = Vector4.new(-670.745, 825.371, 19.420, 1), angles = EulerAngles.new(-88.700, 5.200, 223.270)},
						{ent = [[base\characters\garment\citizen_casual\feet\s1_058_wa_boot__rogue.ent]], pos = Vector4.new(-670.565, 825.457, 19.426, 1), angles = EulerAngles.new(57.200, 0.600, 189.070)},
					},
				},
			},

			pos = Vector4.new(-670.150, 825.804, 19.592, 1),
			time = {startTime = 5, endTime = 10},
			chance = 20,
		},
		-- Afterlife
		{
			locs = {
				{ent = 'songbird_sit_couch_rh_couch', pos = Vector4.new(-1433.596, 1000.027, 16.917, 1), angles = EulerAngles.new(0, 0, -99.168), apps = {'casual', 'casual_alt', 'default'}},	
			},

			pos = Vector4.new(-345.980, 1366.422, 42.898, 1),
			time = {startTime = 19, endTime = 22},
			chance = 20,
		},
	}
end

function AMM:SenseSBTriggers()
	local distFromLastPos = 60

	if AMM.playerLastPos ~= '' then
		distFromLastPos = Util:VectorDistance(Game.GetPlayer():GetWorldPosition(), AMM.playerLastPos)
	end

	if AMM.SBInWorld then
		local SB = Game.FindEntityByID(AMM.SBInWorld)

		if SB then
			local dist = Util:VectorDistance(Game.GetPlayer():GetWorldPosition(), SB:GetWorldPosition())
			
			if dist >= 50 then
				SB:Dispose()
				AMM.SBInWorld = false
				
				for _, itemID in ipairs(AMM.SBItems) do
					local handle = Game.FindEntityByID(itemID)
					if handle then handle:Dispose() end
				end
				
				AMM.SBItems = nil
			else
				if SB:GetStimReactionComponent().playerProximity then
					if not AMM.SBLookAt then
						Util:NPCTalk(SB)
						AMM.SBLookAt = true
					end
				else
					SB:GetStimReactionComponent():DeactiveLookAt()
					AMM.SBLookAt = false
				end
			end
		end
	elseif distFromLastPos >= 20 then
   	AMM.playerLastPos = Game.GetPlayer():GetWorldPosition()
		for _, trigger in ipairs(AMM.SBLocations) do
			local dist = Util:VectorDistance(Game.GetPlayer():GetWorldPosition(), trigger.pos)

			if dist <= 50 then
				local chance = math.random(100)

				Util:AMMDebug(chance, true)

				if chance < trigger.chance or (AMM.Debug ~= '' and AMM.Debug.SBTest) then
					local time = AMM.Tools:GetCurrentHour()
					
					if time.hour >= 0 and time.hour <= 4 then
						time.hour = time.hour + 24
					end

					if time.hour >= trigger.time.startTime and time.hour <= trigger.time.endTime then
						local location = trigger.locs[math.random(#trigger.locs)]
						AMM:SpawnSBInPosition(location)
					end
				end
			end
		end
	end
end

function AMM:SpawnSBInPosition(location)
	local spawnTransform = Game.GetPlayer():GetWorldTransform()
	spawnTransform:SetPosition(location.pos)
	spawnTransform:SetOrientationEuler(location.angles)

	local randomApp = location.apps[math.random(#location.apps)]
	local ent = 'base\\amm_characters\\entity\\'..location.ent..'.ent'

	AMM.SBInWorld = exEntitySpawner.Spawn(ent, spawnTransform, 'songbird_'..randomApp, 'AMM_Character.Songbird')

	if location.items then
		if not AMM.SBItems then AMM.SBItems = {} end

		for _, item in ipairs(location.items) do
			spawnTransform:SetPosition(item.pos)
			spawnTransform:SetOrientationEuler(item.angles)

			local itemID = exEntitySpawner.Spawn(item.ent, spawnTransform, '')
			table.insert(AMM.SBItems, itemID)
		end
	end

	if location.npcs then
		local entities = Util:GetNPCsInRange(40)
		for _, ent in ipairs(entities) do
			for _, npcID in ipairs(location.npcs) do
				if ent.id == npcID then
					local pos = ent.handle:GetWorldPosition()
					local dist = Util:VectorDistance(location.pos, pos)
					if dist < 2 then ent.handle:Dispose() end
				end
			end
		end
	end

	Cron.Every(0.1, {tick = 1}, function(timer)

		local entity = Game.FindEntityByID(AMM.SBInWorld)

		timer.tick = timer.tick + 1

		if timer.tick > 30 then
			Cron.Halt(timer)
		end

		if entity then
			local stimComp = entity:GetStimReactionComponent()
			local role = AIRole.new()

			if location.chunkMask then
				for _, comp in ipairs(location.chunkMask) do
					local c = entity:FindComponentByName(comp)
					if c then
						c:TemporaryHide(true)
					end
				end
			end

			entity:GetAttitudeAgent():SetAttitudeGroup(CName.new("friendly"))

			entity:GetAIControllerComponent():SetAIRole(role)
			entity:GetAIControllerComponent():OnAttach()

			stimComp:SetReactionPreset(TweakDBInterface.GetReactionPresetRecord("ReactionPresets.NoReaction"))
			Cron.Halt(timer)
		end
	end)
end

-- End of AMM Class

return AMM:new()
