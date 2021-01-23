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

tdbid = ''

function Debug.CreateTab(ScanApp, target)
  if (ImGui.BeginTabItem("Debug")) then
    ScanApp.settings = false

    tdbid = ImGui.InputTextWithHint("TweakDBID", 'Insert TweakDBID to Spawn', tdbid, 100)

    ImGui.SameLine()
    if (ImGui.Button('Spawn')) then
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
  local id = TweakDBID.new(tdbid)
  print("[AMM Debug] "..id)
	local player = Game.GetPlayer()
	local heading = player:GetWorldForward()
	local offsetDir = Vector3.new(heading.x, heading.y, heading.z)
	local spawnTransform = player:GetWorldTransform()
	local spawnPosition = spawnTransform.Position:ToVector4(spawnTransform.Position)
	spawnTransform:SetPosition(spawnTransform, Vector4.new(spawnPosition.x - offsetDir.x, spawnPosition.y - offsetDir.y, spawnPosition.z, spawnPosition.w))
	spawnedID = Game.GetPreventionSpawnSystem():RequestSpawn(id, 1, spawnTransform)
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
