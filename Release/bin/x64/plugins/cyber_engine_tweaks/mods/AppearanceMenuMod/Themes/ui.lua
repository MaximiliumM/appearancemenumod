local Theme = json.decode(io.open('Themes/Default.json', 'r'):read("*a"))
local UI = {
  currentTheme = '',
  userThemes = {}
}

function UI:Preload(theme)
  local file = io.open('Themes/'..theme, 'r')
  if file then
    local contents = file:read( "*a" )
		local themeData = json.decode(contents)
    file:close()
    return themeData
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

function UI:UserThemes()
  local files = dir("./Themes")
  local userThemes = {}
  for _, theme in ipairs(files) do
    if string.find(theme.name, '.json') then
      table.insert(userThemes, {name = theme.name:gsub(".json", ""), style = UI:Preload(theme.name)})
    end
  end
  return userThemes
end

function UI:TextColored(text)
  local color = Theme.TextColored
  ImGui.TextColored(color[1] / 255, color[2] / 255, color[3] / 255, color[4], text)
end

function UI:PushStyleColor(style, color)
	ImGui.PushStyleColor(style, color[1] / 255, color[2] / 255, color[3] / 255, color[4])
end

function UI:Start()

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

	ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 15, 15)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0)
  ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 5, 5)
  ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 5, 5)
  ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 5)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 1)
end

function UI:End()
	ImGui.PopStyleColor(22)
	ImGui.PopStyleVar(6)
end

function UI:Spacing(amount)
	if not amount then amount = 1 end

	for i = 1, amount do
		ImGui.Spacing()
	end
end

function UI:Separator()
	UI:Spacing(8)
	ImGui.Separator()
	UI:Spacing(2)
end

UI.userThemes = UI:UserThemes()

return UI
