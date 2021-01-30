local Debug = {
  debugIDs = {},
  sortedDebugIDs = {},
  spawnedIDs = {}
}

grabbed = ''

local function toHex(num)
   local hexstr = '0123456789abcdef'
   local s = ''
   while num > 0 do
       local mod = math.fmod(num, 16)
       s = string.sub(hexstr, mod+1, mod+1) .. s
       num = math.floor(num / 16)
   end
   if s == '' then s = '0' end
   return s
end

local function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

input = ''

function Debug.CreateTab(ScanApp, target)
  if (ImGui.BeginTabItem("Debug")) then
    ScanApp.settings = false

    local clipboard = ImGui.GetClipboardText()
    if clipboard:len() < 50 then
      input = clipboard
    end

    input = ImGui.InputTextWithHint("TweakDBID", 'Insert TweakDBID to Spawn', input, 80)
    tdbid = input

    ImGui.SameLine()
    if (ImGui.Button('Spawn')) then
      if string.find(input, '-') then
        local tdbidCommand = '0x'..input:gsub('-', ',0x')
        ImGui.SetClipboardText(tdbidCommand)
        tdbid = load("return TweakDBID.new("..tdbidCommand..')')()
      elseif string.find(input, '0x') then
        tdbid = load("return TweakDBID.new("..input..")")()
      end

      Debug.SpawnNPC(tdbid)
    end

    ImGui.SameLine()
    if next(Debug.spawnedIDs) ~= nil then
      if (ImGui.Button('Despawn All')) then
        Debug.DespawnAll()
      end
    end

    ImGui.Separator()

    local recordID = tostring(target.handle:GetRecordID())
    local hash = recordID:match("= (%g+),")
    local length = toHex(tonumber(recordID:match("= (%g+) }")))
    local tdbid = hash..",0x"..length
    local app = ScanApp:GetScanAppearance(target.handle)

    ImGui.Spacing()

    ImGui.InputText("ID", tdbid, 100, ImGuiInputTextFlags.ReadOnly)
    ImGui.InputText("AppString", app, 100, ImGuiInputTextFlags.ReadOnly)

    ImGui.Spacing()

    ImGui.SameLine()
    if (ImGui.Button("Cycle")) then
      ScanApp:ChangeScanAppearanceTo(target, 'Cycle')
      app = ScanApp:GetScanAppearance(target.handle)
      Debug.debugIDs[app] = tdbid
      -- Add new ID
      output = {}
      for i,v in pairs(Debug.debugIDs) do
          if output[v] == nil then
              output[v] = {}
          end

          table.insert(output[v], i)
      end

      Debug.sortedDebugIDs = output
    end

    ImGui.SameLine()
    if (ImGui.Button('Class Dump')) then
      print(Dump(target.handle, true))
    end

    ImGui.SameLine()
    if (ImGui.Button('Get Record ID')) then
      local recordID = tostring(target.handle:GetRecordID())
      local hash = recordID:match("= (%g+),")
      local length = toHex(tonumber(recordID:match("= (%g+) }")))
      local tdbid = hash..",0x"..length
      local targetName = target.handle:GetTweakDBFullDisplayName(true)
      print(targetName..": "..tdbid.." -- Added to clipboard")
      ImGui.SetClipboardText("{'"..targetName.."', TweakDBID.new("..tdbid..")},")
    end

    ImGui.SameLine()
    if (ImGui.Button('Get Display Name')) then
      print(tostring(target.handle:GetTweakDBFullDisplayName(true)).." -- Added to clipboard")
      ImGui.SetClipboardText(tostring(target.handle:GetTweakDBFullDisplayName(true)))
    end

    ImGui.Spacing()

    if (ImGui.Button('Get Appearances')) then
      if target.handle:IsNPC() then
        local array = target.handle:GetRecord():CrowdAppearanceNames()
        if array[1] ~= nil then
          print("First appearance: "..tostring(array[1]):match("%[ (%g+) -"))
          print("Number of appearances: "..tostring(target.handle:GetRecord():GetCrowdAppearanceNamesCount()))
        else
          print("This NPC has no crowd appearances.")
        end
      elseif target.handle:IsVehicle() then
        local record = target.handle:GetRecord()
        print("Can't do that for vehicles :(")
      end
    end

    ImGui.SameLine()
    if (ImGui.Button('Dump Properties')) then
      print("IsRevealed:"..tostring(target.handle:IsRevealed()))
      print("GetPuppetRarity:"..tostring(target.handle:GetPuppetRarity()))
      print("GetPuppetRarityEnum:"..tostring(target.handle:GetPuppetRarityEnum()))
      print("GetPuppetReactionPresetType:"..tostring(target.handle:GetPuppetReactionPresetType()))
      print("GetIsIconic:"..tostring(target.handle:GetIsIconic()))
      print("GetCurrentOutline:"..tostring(target.handle:GetCurrentOutline()))
      print("GetBlackboard:"..tostring(target.handle:GetBlackboard()))
      print("IsPlayerAround:"..tostring(target.handle:IsPlayerAround()))
      print("GetSenses:"..tostring(target.handle:GetSenses()))
      print("GetAttitude:"..tostring(target.handle:GetAttitude()))
      print("GetBodyType:"..tostring(target.handle:GetBodyType()))
      print("HasCrowdStaticLOD:"..tostring(target.handle:HasCrowdStaticLOD()))
      print("GetTracedActionName:"..tostring(target.handle:GetTracedActionName()))
      print("GetCurrentContext:"..tostring(target.handle:GetCurrentContext()))
      print("GetPersistentID:"..tostring(target.handle:GetPersistentID()))
      print("GetPSOwnerData:"..tostring(target.handle:GetPSOwnerData()))
      print("GetPSClassName:"..tostring(target.handle:GetPSClassName()))
      print("OnGameAttached:"..tostring(target.handle:OnGameAttached()))
      print("ShouldRegisterToHUD:"..tostring(target.handle:ShouldRegisterToHUD()))
      print("IsInitialized:"..tostring(target.handle:IsInitialized()))
      print("IsLogicReady:"..tostring(target.handle:IsLogicReady()))
      print("IsHostile:"..tostring(target.handle:IsHostile()))
      print("IsPuppet:"..tostring(target.handle:IsPuppet()))
      print("IsPlayer:"..tostring(target.handle:IsPlayer()))
      print("IsReplacer:"..tostring(target.handle:IsReplacer()))
      print("IsVRReplacer:"..tostring(target.handle:IsVRReplacer()))
      print("IsJohnnyReplacer:"..tostring(target.handle:IsJohnnyReplacer()))
      print("IsNPC:"..tostring(target.handle:IsNPC()))
      print("IsContainer:"..tostring(target.handle:IsContainer()))
      print("IsShardContainer:"..tostring(target.handle:IsShardContainer()))
      print("IsActive:"..tostring(target.handle:IsActive()))
      print("CanBeTagged:"..tostring(target.handle:CanBeTagged()))
      print("IsQuest:"..tostring(target.handle:IsQuest()))
    end

    ImGui.SameLine()
    if (ImGui.Button('Save IDs to file')) then
      print("TDBID: "..tdbid.." -- Added to clipboard")
      ImGui.SetClipboardText(tdbid)
      Debug.LogToFile(ScanApp.currentDir)
    end

    ImGui.Spacing()

    if (ImGui.Button('Set Friendly')) then
      local targCompanion = target.handle
      local AIC = targCompanion:GetAIControllerComponent()
    	local targetAttAgent = targCompanion:GetAttitudeAgent()
      local currTime = targCompanion.isPlayerCompanionCachedTimeStamp + 11
      local reactionComp = targCompanion.reactionComponent
      local roleComp = NewObject('handle:AIFollowerRole')
  		roleComp:SetFollowTarget(Game:GetPlayerSystem():GetLocalPlayerControlledGameObject())
  		roleComp:OnRoleSet(targCompanion)
  		roleComp.followerRef = Game.CreateEntityReference("#player", {})

      targCompanion.isPlayerCompanionCached = true
      targCompanion.isPlayerCompanionCachedTimeStamp = currTime

      targetAttAgent:SetAttitudeGroup(CName.new("player"))
      reactionComp:MapReactionPreset(CName.new("Follower"))

      Game['senseComponent::RequestMainPresetChange;GameObjectString'](targCompanion, "Follower")
  		Game['senseComponent::ShouldIgnoreIfPlayerCompanion;EntityEntity'](targCompanion, Game:GetPlayer())
  		Game['NPCPuppet::ChangeStanceState;GameObjectgamedataNPCStanceState'](targCompanion, "Relaxed")

      AIC:SetAIRole(roleComp)
      targCompanion.movePolicies:Toggle(true)
    end

    ImGui.SameLine()
    if (ImGui.Button('Set Hostile')) then
      local targCompanion = target.handle
      local AIC = targCompanion:GetAIControllerComponent()
    	local targetAttAgent = targCompanion:GetAttitudeAgent()
      local npcManager = targCompanion.NPCManager
      local reactionComp = targCompanion.reactionComponent
      local aiRole = NewObject('handle:AIRole')
      aiRole:OnRoleSet(targCompanion)

      targCompanion.isPlayerCompanionCached = false
      targCompanion.isPlayerCompanionCachedTimeStamp = 0

      Game['senseComponent::RequestMainPresetChange;GameObjectString'](targCompanion, "Combat")
      Game['NPCPuppet::ChangeStanceState;GameObjectgamedataNPCStanceState'](targCompanion, "Combat")
      AIC:GetCurrentRole():OnRoleCleared(targCompanion)
      AIC:SetAIRole(aiRole)
      targCompanion.movePolicies:Toggle(true)
      targetAttAgent:SetAttitudeGroup(CName.new("hostile"))
      reactionComp:SetReactionPreset(GetSingleton("gamedataTweakDBInterface"):GetReactionPresetRecord(TweakDBID.new("ReactionPresets.Ganger_Aggressive")))

      if grabbed ~= '' then
        GetSingleton("RPGManager"):ApplyAbilityArray(targCompanion, grabbed.Abilities)
      end

      --npcManager:SetNPCAbilities(grabbed)

      reactionComp:TriggerCombat(Game.GetPlayer())
    end

    ImGui.SameLine()
    if (ImGui.Button('Do stuff')) then
      local targCompanion = target.handle
      grabbed = targCompanion:GetRecord()
      -- local reactionComp = targCompanion.reactionComponent
      -- grabbedReaction = reactionComp:GetReactionPreset()
      print(grabbed.Abilities)

      local ts = Game.GetTransactionSystem()
      hasItems, items = ts:GetItemList(targCompanion)
      print(items[1]:GetItemType())
    end

    if (ImGui.BeginChild("Scrolling")) then
      for id, appArray in pairs(Debug.sortedDebugIDs) do
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

function Debug.SpawnNPC(tdbid)
  if type(tdbid) ~= 'userdata' then
    tdbid = TweakDBID.new(tdbid)
  end
  print("[AMM Debug] "..tostring(tdbid))
	local player = Game.GetPlayer()
	local heading = player:GetWorldForward()
	local offsetDir = Vector3.new(heading.x, heading.y, heading.z)
	local spawnTransform = player:GetWorldTransform()
	local spawnPosition = spawnTransform.Position:ToVector4(spawnTransform.Position)
	spawnTransform:SetPosition(spawnTransform, Vector4.new(spawnPosition.x - offsetDir.x, spawnPosition.y - offsetDir.y, spawnPosition.z, spawnPosition.w))
	spawnedID = Game.GetPreventionSpawnSystem():RequestSpawn(tdbid, 1, spawnTransform)
  table.insert(Debug.spawnedIDs, spawnedID)
end

function Debug.DespawnAll()
  for _, npc in ipairs(Debug.spawnedIDs) do
	   Game.GetPreventionSpawnSystem():RequestDespawn(npc)
  end

  Debug.spawnedIDs = {}
end

function Debug.Log(input)
    print("[AMM_Settings] "..input)
end

function Debug.LogToFile(path)
	print("[AMM_Settings] Saving IDs to file")

	local data = ''

	for i,v in pairs(Debug.sortedDebugIDs) do
	    data = data.."['"..i.."']".." = {'"..table.concat(v,"', '").."'},\n"
	end

	local output = io.open(path.."\\debug_ids.lua", "a")

	output:write(data)
	output:close()
end

return Debug
