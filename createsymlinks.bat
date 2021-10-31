@echo off
setlocal enabledelayedexpansion

:: adjust these
set cpInstallPath="C:\GOG Games\Cyberpunk 2077"
set overwriteArchiveFiles=0

:: ATTENTION! WILL NUKE YOUR PREFERENCES!
set overwriteModDirectory=1

set cpInstallPath=%cpInstallPath:"=%



if not exist ".\Release\archive\pc\mod" (
	echo please execute script from root of github repository
)

pushd ".\Release\archive\pc\mod"
for %%x in (*.archive) do (
	call :symlinkArchive %%~nxx
)
popd


call :checkOverwriteModDirectory
if not exist "%cpInstallPath%\bin\x64\plugins\cyber_engine_tweaks\mods\AppearanceMenuMod" (
	mklink /d "%cpInstallPath%\bin\x64\plugins\cyber_engine_tweaks\mods\AppearanceMenuMod" "%CD%\Release\bin\x64\plugins\cyber_engine_tweaks\mods\AppearanceMenuMod"
)

goto :eof 

:symlinkArchive
	set filename=%*
	
	:: Recreate
	if exist "%cpInstallPath%\archive\pc\mod\%filename%" (
		if 1 EQU %overwriteArchiveFiles% (
			echo overwriting %filename%...
			del /s /q "%cpInstallPath%\archive\pc\mod\%filename%" > nul
		) else (
			echo %filename% already exists. skipping...
		)
	)

	if not exist "%cpInstallPath%\archive\pc\mod\%filename%" (
		mklink /h "%cpInstallPath%\archive\pc\mod\%filename%"  "%filename%" > nul
	)
	
	goto :eof
	
:: check plugin directory now
:checkOverwriteModDirectory	
	if exist "%cpInstallPath%\bin\x64\plugins\cyber_engine_tweaks\mods\AppearanceMenuMod" (	
		if 1 EQU %overwriteModDirectory% (
			call :start
		) else (
			echo "%cpInstallPath%\bin\x64\plugins\cyber_engine_tweaks\mods\AppearanceMenuMod" already exists. Not linking again...
		)
	)
	goto :eof
	
:start
	SET choice=
	SET /p choice=Overwrite all settings? Y/N [N]: 
	IF NOT '%choice%'=='' SET choice=%choice:~0,1%
	IF '%choice%'=='Y' GOTO yes
	IF '%choice%'=='y' GOTO yes
	IF '%choice%'=='N' GOTO no
	IF '%choice%'=='n' GOTO no
	IF '%choice%'=='' GOTO no
	ECHO "%choice%" is not valid. Please press Y/N/enter
	ECHO.
	GOTO start

:no
	ECHO Not overwriting
	goto :eof

:yes	
	echo overwriting %cpInstallPath%\bin\x64\plugins\cyber_engine_tweaks\mods\AppearanceMenuMod...
	RMDIR /S /Q "%cpInstallPath%\bin\x64\plugins\cyber_engine_tweaks\mods\AppearanceMenuMod"
	goto :eof
	
popd