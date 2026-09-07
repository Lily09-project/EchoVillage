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
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\run_godot_bounded.ps1') `
        -Godot $godot -ProjectRoot $root -StandardOutput $stdout -StandardError $stderr `
        -TimeoutSeconds 600 --headless --path $root --scene 'res://tests/SoakRunner.tscn' --log-file $engineLog
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
    foreach ($forbidden in @('SCRIPT ERROR', 'ERROR: Failed to load script', 'ObjectDB instances leaked')) {
        if ($combined -match [regex]::Escape($forbidden)) { $result = 1 }
    }
    exit $result
}
finally {
    foreach ($path in @($stdout, $stderr, $engineLog)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}
