@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "ROOT=%~dp0"
set "GODOT="
if defined GODOT_EXECUTABLE if exist "%GODOT_EXECUTABLE%" set "GODOT=%GODOT_EXECUTABLE%"
if not defined GODOT for %%G in ("%ROOT%tools\godot\Godot*_console.exe") do if exist "%%~G" set "GODOT=%%~G"
if not defined GODOT for %%G in (Godot4.exe Godot.exe godot.exe) do (
  for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT set "GODOT=%%P"
)
rem The editor is used only to validate and export; it is never copied into the game.
if not defined GODOT if exist "%ROOT%tools\godot\Godot_v4.5.2-stable_win64.exe" set "GODOT=%ROOT%tools\godot\Godot_v4.5.2-stable_win64.exe"
if not defined GODOT (
  echo RELEASE FAILED: Godot 4.5.2 stable editor executable not found.
  echo Set GODOT_EXECUTABLE or place a console build in tools\godot\.
  exit /b 2
)

echo ============================================================
echo   Echo Village 2.0.0 - Windows Portable Candidate Builder
echo ============================================================
echo [1/4] Running the complete automated test suite...
call run_echo_village.bat --test
if errorlevel 1 goto :failed

echo [2/4] Exporting the Windows game with installed 4.5.2 templates...
if not exist "release\EchoVillage" mkdir "release\EchoVillage"
"%GODOT%" --headless --path . --export-release "Windows Portable" "release\EchoVillage\EchoVillage.exe"
if errorlevel 1 goto :failed

if not exist "release\EchoVillage\EchoVillage.exe" goto :failed
if not exist "release\EchoVillage\EchoVillage.pck" goto :failed

echo [3/4] Assembling the portable notices...
copy /Y "RELEASE_README.txt" "release\EchoVillage\README.txt" >nul
if errorlevel 1 goto :failed
copy /Y "THIRD_PARTY_NOTICES.txt" "release\EchoVillage\THIRD_PARTY_NOTICES.txt" >nul
if errorlevel 1 goto :failed

echo [4/4] Smoke-testing the packaged executable...
set "SMOKE_LOG=%TEMP%\EchoVillage_smoke_%RANDOM%.log"
set "SMOKE_ERROR=%SMOKE_LOG%.err"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\run_godot_bounded.ps1" -Godot "%ROOT%release\EchoVillage\EchoVillage.exe" -ProjectRoot "%ROOT%release\EchoVillage" -StandardOutput "%SMOKE_LOG%" -StandardError "%SMOKE_ERROR%" -TimeoutSeconds 60 --headless --quit-after 120
set "SMOKE_EXIT=%ERRORLEVEL%"
findstr /I /C:"Invalid wrapper executable name" /C:"SCRIPT ERROR" /C:"ERROR:" "%SMOKE_LOG%" "%SMOKE_ERROR%" >nul
if not errorlevel 1 (
  echo RELEASE FAILED: packaged smoke test reported a runtime error.
  type "%SMOKE_LOG%"
  type "%SMOKE_ERROR%"
  del /q "%SMOKE_LOG%" "%SMOKE_ERROR%" >nul 2>nul
  exit /b 1
)
if not "%SMOKE_EXIT%"=="0" (
  echo RELEASE FAILED: packaged smoke test exited with code %SMOKE_EXIT%.
  type "%SMOKE_LOG%"
  type "%SMOKE_ERROR%"
  del /q "%SMOKE_LOG%" "%SMOKE_ERROR%" >nul 2>nul
  exit /b 1
)
del /q "%SMOKE_LOG%" "%SMOKE_ERROR%" >nul 2>nul

echo.
echo RELEASE READY: release\EchoVillage\EchoVillage.exe
echo Automated smoke test passed; clean-machine GUI acceptance is still required.
echo Players can double-click EchoVillage.exe; Godot is not required.
exit /b 0

:failed
echo.
echo RELEASE FAILED. Review the first ERROR or SCRIPT ERROR above.
exit /b 1
