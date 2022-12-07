local Theme = json.decode(io.open('Themes/Default.json', 'r'):read("*a"))
local UI = {
  currentTheme = '',
  userThemes = {},
  style = {
    buttonWidth = nil,
    buttonHeight = nil,
    halfButtonWidth = nil,
  },
}

function UI:Preload(theme)
  local file = io.open('Themes/'..theme, 'r') or io.open('User/Themes/'..theme, 'r')
  if file then
    local contents = file:read( "*a" )
		local data = json.decode(contents)
    file:close()
    if data.theme then
      data.theme.ScrollbarSize = data.scrollbarSize
      return data.theme
    else
      return data
    end
  end
end

function UI:SetThemeData(data)
  Theme = data
end

function UI:Load(selectedTheme)
  for _, theme in ipairs(UI.userThemes) do
    if theme.name == selectedTheme then
      self.currentTheme = selectedTheme
      self:SetThemeData(theme.style)
    end
  end
end

function UI:DeleteTheme(theme)
  if theme ~= "Default" then
    os.remove("User/Themes/"..theme..".json")
    UI.userThemes = UI:UserThemes()
  end
end

function UI:UserThemes()
  local userThemes = {}
  local files = dir("./User/Themes")
  for _, theme in ipairs(files) do
    if string.find(theme.name, '.json') then
      table.insert(userThemes, {name = theme.name:gsub(".json", ""), style = UI:Preload(theme.name)})
    end
  end
  local files = dir("./Themes")
  for _, theme in ipairs(files) do
    if string.find(theme.name, '.json') then
      table.insert(userThemes, {name = theme.name:gsub(".json", ""), style = UI:Preload(theme.name)})
    end
  end
  return userThemes
end

function UI:TextCenter(text, colored)
  local textWidth = ImGui.CalcTextSize(text)
  local x = ImGui.GetWindowSize()
  ImGui.SameLine(x / 2 - textWidth + (textWidth / 2))
  if colored then
    UI:TextColored(text)
  else
    ImGui.Text(text)
  end
end

function UI:TextWrappedWithColor(text, color)
  local color = Theme[color]
  UI:PushStyleColor(ImGuiCol.Text, color)
  ImGui.TextWrapped(text)
  ImGui.PopStyleColor(1)
end

function UI:TextColored(text)
  local color = Theme.TextColored
  ImGui.TextColored(color[1] / 255, color[2] / 255, color[3] / 255, color[4], text)
end

function UI:TextError(text)
  ImGui.TextColored(1, 0.16, 0.13, 0.75, text)
end

function UI:PushStyleColor(style, color)
  if type(color) ~= "table" then
    color = Theme[color]
  end
	ImGui.PushStyleColor(style, color[1] / 255, color[2] / 255, color[3] / 255, color[4])
end

function UI:Start()
  UI.style.buttonWidth = ImGui.GetWindowContentRegionWidth()
  UI.style.buttonHeight = ImGui.GetFontSize() * 2
  UI.style.halfButtonWidth = ((ImGui.GetWindowContentRegionWidth() / 2) - 5)

	UI:PushStyleColor(ImGuiCol.TitleBg,				     Theme.TitleBg)
	UI:PushStyleColor(ImGuiCol.TitleBgCollapsed,		 Theme.TitleBgCollapsed)
	UI:PushStyleColor(ImGuiCol.TitleBgActive,		   Theme.TitleBgActive)
	UI:PushStyleColor(ImGuiCol.Border,				       Theme.Border)
  UI:PushStyleColor(ImGuiCol.WindowBg,				     Theme.WindowBg)
  UI:PushStyleColor(ImGuiCol.PopupBg,				     Theme.PopupBg)
	UI:PushStyleColor(ImGuiCol.ResizeGrip, 			   Theme.ResizeGrip)
	UI:PushStyleColor(ImGuiCol.ResizeGripHovered, 	 Theme.ResizeGripHovered)
	UI:PushStyleColor(ImGuiCol.ResizeGripActive,		 Theme.ResizeGripActive)
	UI:PushStyleColor(ImGuiCol.Header,		    		   Theme.Header)
	UI:PushStyleColor(ImGuiCol.HeaderHovered,		   Theme.HeaderHovered)
	UI:PushStyleColor(ImGuiCol.HeaderActive,		     Theme.HeaderActive)
	UI:PushStyleColor(ImGuiCol.Text,					       Theme.Text)
	UI:PushStyleColor(ImGuiCol.Tab,					       Theme.Tab)
	UI:PushStyleColor(ImGuiCol.TabHovered,			     Theme.TabHovered)
	UI:PushStyleColor(ImGuiCol.TabActive,			     Theme.TabActive)
	UI:PushStyleColor(ImGuiCol.FrameBg,				     Theme.FrameBg)
	UI:PushStyleColor(ImGuiCol.FrameBgHovered,	     Theme.FrameBgHovered)
	UI:PushStyleColor(ImGuiCol.FrameBgActive,		   Theme.FrameBgActive)
	UI:PushStyleColor(ImGuiCol.Button,				       Theme.Button)
	UI:PushStyleColor(ImGuiCol.ButtonHovered,		   Theme.ButtonHovered)
	UI:PushStyleColor(ImGuiCol.ButtonActive,			   Theme.ButtonActive)
  UI:PushStyleColor(ImGuiCol.CheckMark,			   Theme.CheckMark)
  UI:PushStyleColor(ImGuiCol.ScrollbarBg,			   Theme.FrameBg)
  UI:PushStyleColor(ImGuiCol.ScrollbarGrab,			   Theme.ButtonActive)

	ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 15, 15)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0)
  ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 5, 5)
  ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 5, 5)
  ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, Theme.ScrollbarSize or 0)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 1)

  local x, y = GetDisplayResolution()
  ImGui.SetNextWindowSizeConstraints(570, 100, 700, y / 1.2)
end

function UI:End()
  ImGui.PopStyleVar(6)
  ImGui.PopStyleColor(23)
end

function UI:Spacing(amount)
	if not amount then amount = 1 end

	for i = 1, amount do
		ImGui.Spacing()
	end
end

function UI:Separator()
	UI:Spacing(4)
	ImGui.Separator()
	UI:Spacing(2)
end

function UI:DrawCrossHair()
  if AMM.userSettings.scanningReticle then
    local resX, resY = GetDisplayResolution()
    ImGui.SetNextWindowPos((resX / 2) - 20, (resY / 2) - 20)
    ImGui.SetNextWindowSize(40, 40)
    ImGui.SetNextWindowSizeConstraints(40, 40, 40, 40)
    UI:CrossHairStyling()
    ImGui.Begin("Crosshair", ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoCollapse + ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoResize)
    ImGui.End()
    UI:EndCrossHairStyling()
  end
end

function UI:CrossHairStyling()
  local bgColor = Theme.WindowBg
  local color = {bgColor[1], bgColor[2], bgColor[3], 0.5}
  UI:PushStyleColor(ImGuiCol.WindowBg, color)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 10)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 5)
end

function UI:EndCrossHairStyling()
  ImGui.PopStyleVar(2)
  ImGui.PopStyleColor(1)
end

UI.userThemes = UI:UserThemes()

return UI
