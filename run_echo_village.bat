@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "GODOT="

if defined GODOT_EXECUTABLE if exist "%GODOT_EXECUTABLE%" set "GODOT=%GODOT_EXECUTABLE%"
if defined GODOT goto :found

for %%G in ("%ROOT%\tools\godot\Godot*.exe") do (
  if exist "%%~G" set "GODOT=%%~G"
  if defined GODOT goto :found
)

for %%G in (Godot4.exe Godot.exe godot.exe) do (
  where %%G >nul 2>nul && set "GODOT=%%G"
  if defined GODOT goto :found
)
for %%G in ("%ProgramFiles%\Godot\Godot_v4.exe" "%ProgramFiles%\Godot\Godot.exe" "%ProgramFiles(x86)%\Godot\Godot.exe") do (
  if exist "%%~G" set "GODOT=%%~G"
  if defined GODOT goto :found
)
echo.
echo Echo Village cannot find its bundled Godot engine.
echo Expected engine: tools\godot\Godot_v4.5.2-stable_win64.exe
if /I "%~1"=="--test" exit /b 2
pause
exit /b 2

:found
if /I "%~1"=="--test" (
	rem Prefer the console build so parser failures never hide behind a GUI process.
	for %%G in ("%ROOT%\tools\godot\Godot*_console.exe") do (
	  if exist "%%~G" set "GODOT=%%~G"
	)
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\tools\validate_project.ps1"
  set "VALIDATION_RESULT=!ERRORLEVEL!"
  if not "!VALIDATION_RESULT!"=="0" (
    echo Structural validation failed with exit code !VALIDATION_RESULT!.
    exit /b !VALIDATION_RESULT!
  )
  set "PREFLIGHT_LOG=%ROOT%\tests\.godot_preflight_output.log"
  set "PREFLIGHT_ERROR_LOG=%ROOT%\tests\.godot_preflight_error.log"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\tools\run_godot_bounded.ps1" -Godot "%GODOT%" -ProjectRoot "%ROOT%" -StandardOutput "!PREFLIGHT_LOG!" -StandardError "!PREFLIGHT_ERROR_LOG!" -TimeoutSeconds 60 --headless --editor --path "%ROOT%" --import --quit
  set "PREFLIGHT_RESULT=!ERRORLEVEL!"
  type "!PREFLIGHT_LOG!"
  type "!PREFLIGHT_ERROR_LOG!"
  findstr /C:"SCRIPT ERROR" /C:"ERROR: Failed to load script" "!PREFLIGHT_LOG!" "!PREFLIGHT_ERROR_LOG!" >nul && set "PREFLIGHT_RESULT=1"
  del /q "!PREFLIGHT_LOG!" "!PREFLIGHT_ERROR_LOG!" >nul 2>nul
  if not "!PREFLIGHT_RESULT!"=="0" (
    echo Parser/bootstrap preflight failed with exit code !PREFLIGHT_RESULT!.
    exit /b !PREFLIGHT_RESULT!
  )
  set "TEST_LOG=%ROOT%\tests\.godot_test_output.log"
  set "TEST_ERROR_LOG=%ROOT%\tests\.godot_test_error.log"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\tools\run_godot_bounded.ps1" -Godot "%GODOT%" -ProjectRoot "%ROOT%" -StandardOutput "!TEST_LOG!" -StandardError "!TEST_ERROR_LOG!" -TimeoutSeconds 120 --headless --path "%ROOT%" --scene res://tests/TestRunner.tscn
  set "RESULT=!ERRORLEVEL!"
  type "!TEST_LOG!"
  type "!TEST_ERROR_LOG!"
  findstr /C:"SCRIPT ERROR" /C:"ERROR: Failed to load script" "!TEST_LOG!" "!TEST_ERROR_LOG!" >nul && set "RESULT=1"
  del /q "!TEST_LOG!" "!TEST_ERROR_LOG!" >nul 2>nul
  echo.
  echo Test process exit code: !RESULT!.
  exit /b !RESULT!
)
start "Echo Village" "%GODOT%" --path "%ROOT%"
exit /b 0
