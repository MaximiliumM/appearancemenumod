local Theme = ''
local Editor = {
  errorMessage = '',
  isEditing = false,
  open = false,
  newThemeName = ''
}

function Editor:ConvertColor(color)
  return {color[1] / 255, color[2] / 255, color[3] / 255, color[4]}
end

function Editor:RevertColor(color)
  return {math.floor((color[1] * 255) * 100) / 100, math.floor((color[2] * 255) * 100) / 100, math.floor((color[3] * 255) * 100) / 100, color[4]}
end

function Editor:ConvertToRGB(t)
  local theme = {}
  for color, values in pairs(t) do
    theme[color] = Editor:RevertColor(values)
  end

  return theme
end

function Editor:CheckIfThemeExists()
  for _, theme in ipairs(AMM.UI.userThemes) do
    if theme.name == Editor.newThemeName then
      return true
    end
  end

  return false
end

function Editor:UpdateTheme(t)
  local theme = self:ConvertToRGB(t)
  AMM.UI:SetThemeData(theme)
end

function Editor:SetCurrentTheme(t)

  for color, values in pairs(t) do
    t[color] = Editor:ConvertColor(values)
  end

  Theme = t
end

function Editor:Setup()
  local sizeX = ImGui.GetWindowSize()
  local x, y = ImGui.GetWindowPos()
  if x < ImGui.GetFontSize() * 40 then
    ImGui.SetNextWindowPos(x + (sizeX + 50), y - 40)
  else
    ImGui.SetNextWindowPos(x - (sizeX + 200), y - 40)
  end
end

function Editor:Draw(AMM)
  Editor.open = ImGui.Begin("Theme Editor", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoCollapse)
  if Editor.open then
    if Theme == '' then
      Editor.isEditing = true
      Editor:SetCurrentTheme(AMM.UI:Preload(AMM.selectedTheme..".json"))
    end

    Editor.newThemeName = ImGui.InputTextWithHint("Theme Name", "Insert New Theme Name",Editor.newThemeName, 30)

    if ImGui.SmallButton("  Save  ") then
      if Editor.newThemeName ~= '' then
        if Editor:CheckIfThemeExists() then
          Editor.errorMessage = "Theme name already exists"
          ImGui.OpenPopup("Error")
        else
          local file = io.open("User/Themes/"..Editor.newThemeName..".json", "w")
          if file then
            local contents = json.encode(Editor:ConvertToRGB(Theme))
        		file:write(contents)
            file:close()
          end
          AMM.UI.userThemes = AMM.UI:UserThemes()
          AMM.selectedTheme = Editor.newThemeName
          ImGui.CloseCurrentPopup()
        end
      end
    end

    ImGui.SameLine()
    if ImGui.SmallButton("  Cancel  ") then
      Editor.open = false
    end

    ImGui.Spacing()
    ImGui.Separator()

    Theme.Text = ImGui.ColorEdit4("Text", Theme.Text)
    Theme.TextColored = ImGui.ColorEdit4("TextColored", Theme.TextColored)
    Theme.WindowBg = ImGui.ColorEdit4("WindowBg", Theme.WindowBg)
    Theme.Border = ImGui.ColorEdit4("Border", Theme.Border)
    Theme.FrameBg = ImGui.ColorEdit4("FrameBg", Theme.FrameBg)
    Theme.FrameBgHovered = ImGui.ColorEdit4("FrameBgHovered", Theme.FrameBgHovered)
    Theme.FrameBgActive = ImGui.ColorEdit4("FrameBgActive", Theme.FrameBgActive)
    Theme.Header = ImGui.ColorEdit4("Header", Theme.Header)
    Theme.HeaderHovered = ImGui.ColorEdit4("HeaderHovered", Theme.HeaderHovered)
    Theme.HeaderActive = ImGui.ColorEdit4("HeaderActive", Theme.HeaderActive)
    Theme.TitleBg = ImGui.ColorEdit4("TitleBg", Theme.TitleBg)
    Theme.TitleBgActive = ImGui.ColorEdit4("TitleBgActive", Theme.TitleBgActive)
    Theme.TitleBgCollapsed = ImGui.ColorEdit4("TitleBgCollapsed", Theme.TitleBgCollapsed)
    Theme.CheckMark = ImGui.ColorEdit4("CheckMark", Theme.CheckMark)
    Theme.Button = ImGui.ColorEdit4("Button", Theme.Button)
    Theme.ButtonHovered = ImGui.ColorEdit4("ButtonHovered", Theme.ButtonHovered)
    Theme.ButtonActive = ImGui.ColorEdit4("ButtonActive", Theme.ButtonActive)
    Theme.Tab = ImGui.ColorEdit4("Tab", Theme.Tab)
    Theme.TabHovered = ImGui.ColorEdit4("TabHovered", Theme.TabHovered)
    Theme.TabActive = ImGui.ColorEdit4("TabActive", Theme.TabActive)
    Theme.ResizeGrip = ImGui.ColorEdit4("ResizeGrip", Theme.ResizeGrip)
    Theme.ResizeGripHovered = ImGui.ColorEdit4("ResizeGripHovered", Theme.ResizeGripHovered)
    Theme.ResizeGripActive = ImGui.ColorEdit4("ResizeGripActive", Theme.ResizeGripActive)

    if ImGui.BeginPopupModal("Error") then
      ImGui.Text(Editor.errorMessage)
      if ImGui.SmallButton("  Ok  ") then
        ImGui.CloseCurrentPopup()
      end
      ImGui.EndPopup()
    end

    Editor:UpdateTheme(Theme)
  end
  ImGui.End()

  if not(Editor.open) and Editor.isEditing then
    Theme = ''
    Editor.newThemeName = ''
    Editor.isEditing = false
    AMM.UI.currentTheme = 'reset'
  end
end

return Editor
