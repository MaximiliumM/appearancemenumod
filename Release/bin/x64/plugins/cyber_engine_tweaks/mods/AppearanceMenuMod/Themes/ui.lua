local Theme = json.decode(io.open('Themes/Default.json', 'r'):read("*a"))
local UI = {
  currentTheme = '',
  userThemes = {},
  style = {
    buttonWidth = nil,
    buttonHeight = nil,
    halfButtonWidth = nil,
    scrollBarSize = 0,
    listScaleFactor = 0,
  },
}

local heightConstraint = nil
local childViews = {}

local function calculateWidthConstraint(fontSize)
  -- You can adjust the multiplier value as needed to fit your requirements
  local multiplier = 100
  
  -- Calculate the minimum width constraint
  local widthConstraint = fontSize * multiplier
  
  -- Make sure the width constraint is at least a certain minimum value
  local minimumWidthConstraint = math.max(widthConstraint, 700)
  
  return minimumWidthConstraint
end

local function calculateChildViewHeight(itemCount, itemHeight)
  local windowHeight = ImGui.GetWindowHeight()
  local availableSpace = heightConstraint - windowHeight
  local additionalItems = math.floor(availableSpace / itemHeight)
  if additionalItems > 4 then
    additionalItems = 4
  end

  itemCount = itemCount + 2

  if itemCount > 9 and availableSpace > 0 then
    if not(itemCount < (additionalItems + 9)) then
      itemCount = 9
      itemCount = itemCount + additionalItems
    end
  end

  local childViewHeight = itemCount * itemHeight
  if childViewHeight > windowHeight then
      childViewHeight = windowHeight
  end

  return childViewHeight + 10
end

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
  ImGui.Dummy(10, 1)
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

function UI:TextCenterError(text)
  local textWidth = ImGui.CalcTextSize(text)
  local x = ImGui.GetWindowSize()
  ImGui.SameLine(x / 2 - textWidth + (textWidth / 2))
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

  if AMM.userSettings.scrollBarEnabled then
    UI.style.scrollBarSize = 10
  end

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
  ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 6, 8)
  ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 8)
  ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 5, 5)
  ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, Theme.ScrollbarSize or UI.style.scrollBarSize)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 1)

  local x, y = GetDisplayResolution()
  local widthConstraint = calculateWidthConstraint(ImGui.GetFontSize())
  heightConstraint = y / 1.2
  ImGui.SetNextWindowSizeConstraints(650, 100, widthConstraint, heightConstraint)
end

function UI:End()
  ImGui.PopStyleVar(7)
  ImGui.PopStyleColor(25)
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

function UI:GlyphButton(label, transparent)
  if not IconGlyphs then
    return ImGui.Button(label, 30, 40)
  end

  if transparent then
    UI:PushStyleColor(ImGuiCol.ButtonHovered, Theme.Text)
    UI:PushStyleColor(ImGuiCol.Text, Theme.ButtonHovered)
    ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
  end

  ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
  ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 0, 0)
  local button = ImGui.Button(label, 30, 40)
  ImGui.PopStyleVar(2)

  if transparent then
    ImGui.PopStyleColor(3)
  end

  return button
end

function UI:SmallCheckbox(state, label)
  local modeChange = nil
  ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 4, 4)
  ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 4)
  state, modeChange = ImGui.Checkbox(label or " ", state)
  ImGui.PopStyleVar(2)
  return state, modeChange
end

function UI:SmallButton(buttonLabel, padding)
  local paddingString = "##"
  if padding then
    if padding == 0 then
      paddingString = ""
    else      
      for i = 1, padding do 
        paddingString = paddingString .. " "
      end
    end
  end

  local label = string.gsub(buttonLabel, "##.*", paddingString)
  local x = ImGui.CalcTextSize(label)
  ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
  local button = ImGui.Button(buttonLabel, x, 33)
  ImGui.PopStyleVar()
  return button
end

function UI:List(id, itemCount, baseItemHeight, func)

  -- Adjust size to avoid the area being too small
  if itemCount == 1 or itemCount == 2 then baseItemHeight = baseItemHeight * 2 end
  if itemCount == 3 or itemCount == 4 then baseItemHeight = baseItemHeight * 1.5 end

  -- Apply user scale factor
  local sliderValue = UI.style.listScaleFactor

  -- Map slider value to the output range
  local fractionOfWindow = 0.7 + (sliderValue * 0.3)

  local padding = 4
  local scaledItemHeight  = baseItemHeight + padding

  -- How big is the window’s remaining vertical space?
  local available         = ImGui.GetContentRegionAvail()

  -- How much height would we need if we showed all items at once?
  local totalNeeded       = itemCount * scaledItemHeight
  local maxHeight         = available * fractionOfWindow

  -- The final child height is either the full item list or that fraction of the window, whichever is smaller
  local childHeight       = math.min(totalNeeded + padding, maxHeight)

  if ImGui.BeginChild("List##"..id, -1, childHeight, true) then
    local clipper = ImGuiListClipper.new()
    -- Pass scaledItemHeight to match the actual item size
    clipper:Begin(itemCount, scaledItemHeight)

    while (clipper:Step()) do
      for i = clipper.DisplayStart + 1, clipper.DisplayEnd do
        func(i)
      end
    end
  end
  ImGui.EndChild()
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
