local Debug = {
  debugIDs = {},
  sortedDebugIDs = {},
  spawnedIDs = {}
}

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

    input = ImGui.InputTextWithHint("TweakDBID", 'Insert TweakDBID to Spawn', input, 100)
    tdbid = input

    ImGui.SameLine()
    if (ImGui.Button('Spawn')) then
      if string.find(input, '0x') then tdbid = load("return TweakDBID.new("..input..")")() end
      Debug.SpawnNPC(tdbid)
    end

    ImGui.SameLine()
    if next(Debug.spawnedIDs) ~= nil then
      if (ImGui.Button('Despawn All')) then
        Debug.DespawnAll()
      end
    end

    ImGui.Separator()

    scanID = target.id
    app = ScanApp:GetScanAppearance(target.handle)

    ImGui.Spacing()

    ImGui.InputText("ID", scanID, 100, ImGuiInputTextFlags.ReadOnly)
    ImGui.InputText("AppString", app, 100, ImGuiInputTextFlags.ReadOnly)

    ImGui.Spacing()

    ImGui.SameLine()
    if (ImGui.Button("Cycle")) then
      ScanApp:ChangeScanAppearanceTo(target.handle, 'Cycle')
      app = ScanApp:GetScanAppearance(target.handle)
      Debug.debugIDs[app] = scanID
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
      print(tostring(target.handle:GetRecordID()).." -- Added to clipboard")
      ImGui.SetClipboardText(tostring(target.handle:GetRecordID()))
    end

    ImGui.SameLine()
    if (ImGui.Button('Get Display Name')) then
      print(tostring(target.handle:GetTweakDBFullDisplayName(true)).." -- Added to clipboard")
      ImGui.SetClipboardText(tostring(target.handle:GetTweakDBFullDisplayName(true)))
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
      print("Scan ID: "..scanID.." -- Added to clipboard")
      ImGui.SetClipboardText(scanID)
      Debug.LogToFile(ScanApp.currentDir)
    end

    ImGui.Spacing()

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
	    data = data.."['"..i.."']".." = {'"..table.concat(v,"', '").."'}\n"
	end

	local output = io.open(path.."\\AppearanceMenuMod\\debug_ids.lua", "a")

	output:write(data)
	output:close()
end

return Debug
