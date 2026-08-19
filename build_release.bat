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
if not defined GODOT (
  echo RELEASE FAILED: Godot 4.2+ executable not found.
  echo Set GODOT_EXECUTABLE or place a console build in tools\godot\.
  exit /b 2
)
set "RUNTIME="
if defined GODOT_RUNTIME if exist "%GODOT_RUNTIME%" set "RUNTIME=%GODOT_RUNTIME%"
if not defined RUNTIME if exist "%ROOT%tools\godot\Godot_v4.5.2-stable_win64.exe" set "RUNTIME=%ROOT%tools\godot\Godot_v4.5.2-stable_win64.exe"
if not defined RUNTIME (
  echo RELEASE FAILED: GUI export runtime not found.
  echo Set GODOT_RUNTIME to a Godot Windows export runtime or place one in tools\godot\.
  echo GODOT_EXECUTABLE is used for tests and PCK export; it is not a packaged GUI runtime.
  exit /b 3
)
if not exist "%RUNTIME%" (
  echo RELEASE FAILED: configured GODOT_RUNTIME does not exist: %RUNTIME%
  exit /b 3
)

echo ============================================================
echo   Echo Village 1.2.0 - Windows Portable Release Builder
echo ============================================================
echo [1/4] Running the complete automated test suite...
call run_echo_village.bat --test
if errorlevel 1 goto :failed

echo [2/4] Building the PCK game package...
if not exist "release\EchoVillage" mkdir "release\EchoVillage"
"%GODOT%" --headless --path . --export-pack "Windows Portable" "release\EchoVillage\EchoVillage.pck"
if errorlevel 1 goto :failed

echo [3/4] Assembling the portable runtime and notices...
copy /Y "%RUNTIME%" "release\EchoVillage\EchoVillage.exe" >nul
copy /Y "RELEASE_README.txt" "release\EchoVillage\README.txt" >nul
copy /Y "THIRD_PARTY_NOTICES.txt" "release\EchoVillage\THIRD_PARTY_NOTICES.txt" >nul
if errorlevel 1 goto :failed

echo [4/4] Smoke-testing the packaged executable...
set "SMOKE_LOG=%TEMP%\EchoVillage_smoke_%RANDOM%.log"
"release\EchoVillage\EchoVillage.exe" --headless --quit-after 120 > "%SMOKE_LOG%" 2>&1
set "SMOKE_EXIT=%ERRORLEVEL%"
findstr /I /C:"Invalid wrapper executable name" /C:"SCRIPT ERROR" /C:"ERROR:" "%SMOKE_LOG%" >nul
if not errorlevel 1 (
  echo RELEASE FAILED: packaged smoke test reported a runtime error.
  type "%SMOKE_LOG%"
  del /q "%SMOKE_LOG%" >nul 2>nul
  exit /b 1
)
if not "%SMOKE_EXIT%"=="0" (
  echo RELEASE FAILED: packaged smoke test exited with code %SMOKE_EXIT%.
  type "%SMOKE_LOG%"
  del /q "%SMOKE_LOG%" >nul 2>nul
  exit /b 1
)
del /q "%SMOKE_LOG%" >nul 2>nul

echo.
echo RELEASE READY: release\EchoVillage\EchoVillage.exe
echo Players can double-click EchoVillage.exe; Godot is not required.
exit /b 0

:failed
echo.
echo RELEASE FAILED. Review the first ERROR or SCRIPT ERROR above.
exit /b 1
