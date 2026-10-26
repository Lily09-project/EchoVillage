$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = $null

if ($env:GODOT_EXECUTABLE -and (Test-Path -LiteralPath $env:GODOT_EXECUTABLE -PathType Leaf)) {
    $godot = $env:GODOT_EXECUTABLE
}
if (-not $godot) {
    $bundled = Get-ChildItem -LiteralPath (Join-Path $root 'tools\godot') -Filter 'Godot*_console.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $bundled) { $bundled = Get-ChildItem -LiteralPath (Join-Path $root 'tools\godot') -Filter 'Godot*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($bundled) { $godot = $bundled.FullName }
}
if (-not $godot) {
    foreach ($name in @('Godot4.exe', 'Godot.exe', 'godot.exe')) {
        $candidate = Get-Command $name -ErrorAction SilentlyContinue
        if ($candidate) { $godot = $candidate.Source; break }
    }
}
if (-not $godot) { Write-Error 'Echo Village cannot find a Godot executable for the nightly soak.'; exit 2 }

$tag = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + "-$PID"
$stdout = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_stdout_$tag.log"
$stderr = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_stderr_$tag.log"
$engineLog = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_engine_$tag.log"
$preflightStdout = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_preflight_stdout_$tag.log"
$preflightStderr = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_preflight_stderr_$tag.log"
$preflightEngineLog = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_preflight_engine_$tag.log"
$verifyStdout = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_verify_stdout_$tag.log"
$verifyStderr = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_verify_stderr_$tag.log"
$verifyEngineLog = Join-Path ([IO.Path]::GetTempPath()) "EchoVillage_soak_verify_engine_$tag.log"

try {
    Write-Output 'SOAK_PREFLIGHT started=true timeout_seconds=90'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\run_godot_bounded.ps1') `
        -Godot $godot -ProjectRoot $root -StandardOutput $preflightStdout -StandardError $preflightStderr `
        -TimeoutSeconds 90 --headless --editor --path $root --import --quit --log-file $preflightEngineLog
    $preflightResult = $LASTEXITCODE
    $preflightCombined = ''
    foreach ($path in @($preflightStdout, $preflightStderr, $preflightEngineLog)) {
        if (Test-Path -LiteralPath $path) {
            $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            Write-Output $text
            $preflightCombined += "`n$text"
        }
    }
    if (-not (Test-Path -LiteralPath $preflightEngineLog -PathType Leaf)) {
        throw 'Godot import/parser preflight did not produce an engine log.'
    }

    $firstPassErrors = @($preflightCombined -split '\r?\n' | Where-Object { $_ -match 'ERROR:|SCRIPT ERROR' })
    $unexpectedFirstPassErrors = @($firstPassErrors | Where-Object {
        $_ -notmatch 'No loader found for resource: res://assets/fonts/NotoSansTC-EchoVillage.ttf' -and
        $_ -notmatch "Error loading custom project font 'res://assets/fonts/NotoSansTC-EchoVillage.ttf'"
    })
    $expectedFontCacheBootstrap = (
        $preflightCombined -match 'No loader found for resource: res://assets/fonts/NotoSansTC-EchoVillage.ttf' -and
        $preflightCombined -match "Error loading custom project font 'res://assets/fonts/NotoSansTC-EchoVillage.ttf'" -and
        $preflightCombined -match '\[ DONE \] reimport'
    )
    if ($unexpectedFirstPassErrors.Count -gt 0) {
        throw 'Godot first import reported an unexpected parser or resource error.'
    }
    if ($preflightResult -ne 0 -and -not $expectedFontCacheBootstrap) {
        throw "Godot import/parser preflight failed with exit code $preflightResult."
    }
    if ($preflightResult -ne 0) {
        Write-Output 'SOAK_PREFLIGHT first_import=completed expected_font_cache_bootstrap=true'
    }

    Write-Output 'SOAK_PREFLIGHT verifying_import=true timeout_seconds=30'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\run_godot_bounded.ps1') `
        -Godot $godot -ProjectRoot $root -StandardOutput $verifyStdout -StandardError $verifyStderr `
        -TimeoutSeconds 30 --headless --editor --path $root --import --quit --log-file $verifyEngineLog
    $verifyResult = $LASTEXITCODE
    $verifyCombined = ''
    foreach ($path in @($verifyStdout, $verifyStderr, $verifyEngineLog)) {
        if (Test-Path -LiteralPath $path) {
            $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            Write-Output $text
            $verifyCombined += "`n$text"
        }
    }
    if (-not (Test-Path -LiteralPath $verifyEngineLog -PathType Leaf)) { $verifyResult = 1 }
    foreach ($forbidden in @('SCRIPT ERROR', 'ERROR:', 'No loader found for resource', 'Error loading custom project font')) {
        if ($verifyCombined -match [regex]::Escape($forbidden)) { $verifyResult = 1 }
    }
    if ($verifyResult -ne 0) { throw "Godot import/parser verification failed with exit code $verifyResult." }
    Write-Output 'SOAK_PREFLIGHT passed=true'

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\run_godot_bounded.ps1') `
        -Godot $godot -ProjectRoot $root -StandardOutput $stdout -StandardError $stderr `
        -TimeoutSeconds 900 --headless --path $root --scene 'res://tests/SoakRunner.tscn' --log-file $engineLog
    $result = $LASTEXITCODE
    $combined = ''
    foreach ($path in @($stdout, $stderr, $engineLog)) {
        if (Test-Path -LiteralPath $path) {
            $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            Write-Output $text
            $combined += "`n$text"
        }
    }
    if ($result -eq 0 -and $combined -notmatch 'SOAK_RESULT passed=true') { $result = 1 }
    foreach ($forbidden in @('SCRIPT ERROR', 'ERROR: Failed to load script', 'No loader found for resource', 'Error loading custom project font', 'ObjectDB instances leaked')) {
        if ($combined -match [regex]::Escape($forbidden)) { $result = 1 }
    }
    exit $result
}
finally {
    foreach ($path in @($preflightStdout, $preflightStderr, $preflightEngineLog, $verifyStdout, $verifyStderr, $verifyEngineLog, $stdout, $stderr, $engineLog)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}
