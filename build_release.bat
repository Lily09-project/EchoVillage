@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo   Echo Village 1.2.0 - Windows Portable Release Builder
echo ============================================================
echo [1/4] Running the complete automated test suite...
call run_echo_village.bat --test
if errorlevel 1 goto :failed

echo [2/4] Building the PCK game package...
if not exist "release\EchoVillage" mkdir "release\EchoVillage"
"tools\godot\Godot_v4.5.2-stable_win64_console.exe" --headless --path . --export-pack "Windows Portable" "release\EchoVillage\EchoVillage.pck"
if errorlevel 1 goto :failed

echo [3/4] Assembling the portable runtime and notices...
copy /Y "tools\godot\Godot_v4.5.2-stable_win64.exe" "release\EchoVillage\EchoVillage.exe" >nul
copy /Y "RELEASE_README.txt" "release\EchoVillage\README.txt" >nul
copy /Y "THIRD_PARTY_NOTICES.txt" "release\EchoVillage\THIRD_PARTY_NOTICES.txt" >nul
if errorlevel 1 goto :failed

echo [4/4] Smoke-testing the packaged executable...
"release\EchoVillage\EchoVillage.exe" --headless --quit-after 120
if errorlevel 1 goto :failed

echo.
echo RELEASE READY: release\EchoVillage\EchoVillage.exe
echo Players can double-click EchoVillage.exe; Godot is not required.
exit /b 0

:failed
echo.
echo RELEASE FAILED. Review the first ERROR or SCRIPT ERROR above.
exit /b 1
