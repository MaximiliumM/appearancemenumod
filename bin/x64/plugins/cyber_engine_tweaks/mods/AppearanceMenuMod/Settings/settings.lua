local Settings = {}

local function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

local function getKeyStringFromKeycode(keycode)
	local allKeybinds = Settings.GetAllKeybinds()
	for key, value in pairs(allKeybinds) do
		if keycode == value then
		    return key
		end
	end
end

local function getTutorialString(key, keycode)
	return string.format([[
--------------------------------------------------------
-- To change the keybind, replace the text "115 -- F4 Key "
-- by copy and pasting the code from the list below.
-- For example, to use the G key, copy and paste
-- the text "0x47 -- G key" over "115 -- F4 Key",
-- changing it to AMM_Keybind = 0x47 -- G key
--------------------------------------------------------
AMM_Keybind = %s -- %s Key
--------------------------------------------------------
-- 115 -- F4 Key
--------------------------------------------------------
-- 0x35 = 5 key (Not Numpad 5)
-- 0x36 = 6 key (Not Numpad 6)
-- 0x37 = 7 key (Not Numpad 7)
-- 0x38 = 8 key (Not Numpad 8)
-- 0x39 = 9 key (Not Numpad 9)
-- 0x30 = 0 key (Not Numpad 0)
--------------------------------------------------------
-- 0x47 -- G key
-- 0x48 -- H Key
-- 0x55 -- U Key
-- 0x59 -- Y Key
--------------------------------------------------------

-- If you need to add your own, the full list is available from
-- https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

return AMM_Keybind
]], keycode, key)
end

function Settings.Save(key, keycode)
	local data = getTutorialString(key, keycode)
	local output = io.open("AppearanceMenuMod/Settings/keybind.lua", "w")

	output:write(data)
	output:close()
end

function Settings.GetCurrentKeybind()
	local AMM_Keybind = require("AppearanceMenuMod.Settings.keybind")
	local keyString = getKeyStringFromKeycode(AMM_Keybind)
	return {keyString, AMM_Keybind}
end

function Settings.GetAllKeybinds()
	return {
	['F4'] = 0x73, -- F4 key
	['5'] = 0x35, -- 5 key (Not Numpad 5)
	['6'] = 0x36, -- 6 key (Not Numpad 6)
	['7'] = 0x37, -- 7 key (Not Numpad 7)
	['8'] = 0x38, -- 8 key (Not Numpad 8)
	['9'] = 0x39, -- 9 key (Not Numpad 9)
	['0'] = 0x30, -- 0 key (Not Numpad 0)
	['G'] = 0x47, -- G key
	['H'] = 0x48, -- H Key
	['U'] = 0x55, -- U Key
	['Y'] = 0x59  -- Y Key
	}
end

function Settings.GetNumberOfKeys()
	return getTableSize(Settings.GetAllKeybinds())
end

-- function Settings.GetAllKeys()
-- 	local keyset = {}
--   	for k,v in pairs(getAllKeybinds()) do
--     	keyset[#keyset + 1] = k
--   	end
--   	return keyset
-- end

function Settings.Log(input)
    print("[AMM_Settings] "..input)
end

function Settings.LogToFile(input)
	print("[AMM_Settings] Saving IDs to file")

	local data = ''

	for i,v in pairs(input) do
	    data = data.."['"..i.."']".." = {'"..table.concat(v,"', '").."'}\n"
	end

	local output = io.open("AppearanceMenuMod/debug_ids.lua", "a")

	output:write(data)
	output:close()
end

return Settings
