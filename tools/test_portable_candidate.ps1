$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$package = Join-Path $root 'release/EchoVillage'
$files = @('EchoVillage.exe', 'EchoVillage.pck', 'README.txt', 'THIRD_PARTY_NOTICES.txt')
foreach ($name in $files) {
    $path = Join-Path $package $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
        throw "Portable candidate is missing a nonempty file: $name"
    }
}
$extra = @(Get-ChildItem -LiteralPath $package -File | Where-Object { $_.Name -notin ($files + @('candidate-manifest.json', 'SHA256SUMS.txt')) })
if ($extra.Count -gt 0) { throw 'Portable package contains unexpected files.' }


# License texts must travel in the actual portable package, not only the source tree.
$notices = [IO.File]::ReadAllText((Join-Path $package 'THIRD_PARTY_NOTICES.txt'))
$fontLicense = [IO.File]::ReadAllText((Join-Path $root 'assets/fonts/OFL.txt')).Trim()
if (-not $notices.Contains($fontLicense)) { throw 'Portable notices omit the bundled Noto Sans TC font license.' }
$engineNotices = [IO.File]::ReadAllText((Join-Path $root 'GODOT_COPYRIGHT.txt')).Trim()
if (-not $notices.Contains($engineNotices)) { throw 'Portable notices omit Godot bundled third-party copyright/license texts.' }

# A unique directory outside the checkout proves the EXE finds its adjacent PCK.
# This is an automated startup check, not human GUI acceptance.
$isolated = Join-Path $env:RUNNER_TEMP ('echo-portable-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $isolated | Out-Null
foreach ($name in $files) { Copy-Item -LiteralPath (Join-Path $package $name) -Destination (Join-Path $isolated $name) }
$stdout = Join-Path $isolated 'startup.log'
$stderr = Join-Path $isolated 'startup.err'
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $isolated 'user-roaming'
    $env:LOCALAPPDATA = Join-Path $isolated 'user-local'
    New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'run_godot_bounded.ps1') -Godot (Join-Path $isolated 'EchoVillage.exe') -ProjectRoot $isolated -StandardOutput $stdout -StandardError $stderr -TimeoutSeconds 60 --headless --quit-after 120
    if ($LASTEXITCODE -ne 0) { throw "Isolated packaged startup exited with $LASTEXITCODE." }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
$log = (Get-Content -Raw -LiteralPath $stdout) + (Get-Content -Raw -LiteralPath $stderr)
if ($log -match 'SCRIPT ERROR|ERROR:|Invalid wrapper executable name') { throw "Isolated startup reported errors: $log" }

$records = @($files | ForEach-Object {
    $path = Join-Path $package $_
    [ordered]@{ name = $_; bytes = (Get-Item -LiteralPath $path).Length; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$sourceSha = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceSha -notmatch '^[0-9a-f]{40}$') { throw 'Could not identify candidate source commit.' }
$manifest = [ordered]@{
    schema_version = 1
    source_sha = $sourceSha
    godot_version = '4.5.2.stable'
    export_template_sha256 = 'ea50e5183f057d42b22120d0d0340205b98f51f8ff13c33c70fd4ac9077d2019'
    automated_startup = 'passed'
    human_gui_acceptance = 'pending'
    release_approved = $false
    files = $records
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $package 'candidate-manifest.json') -Encoding utf8
$sumNames = $files + @('candidate-manifest.json')
$sums = @($sumNames | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath (Join-Path $package $_) -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $_"
})
$sums | Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Encoding ascii
Write-Output 'PASS: isolated portable startup and checksums; human GUI acceptance remains pending.'
