$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$builder = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'build_release.bat')
if ($builder -notmatch '--export-release "Windows Portable"') {
    throw 'Portable delivery must use the Windows release exporter.'
}
if ($builder -match '--export-pack|copy /Y "%RUNTIME%"|set "RUNTIME=') {
    throw 'Do not rename an arbitrary editor/runtime executable as the game.'
}
if ($builder -notmatch 'run_godot_bounded.ps1' -or $builder -notmatch '-TimeoutSeconds 60') {
    throw 'The packaged smoke test must have a bounded timeout.'
}
foreach ($source in @('RELEASE_README.txt', 'THIRD_PARTY_NOTICES.txt')) {
    $pattern = '(?m)^copy /Y "' + [regex]::Escape($source) + '"[^\r\n]*\r?\nif errorlevel 1 goto :failed'
    if ($builder -notmatch $pattern) { throw "Notice copy must fail immediately: $source" }
}
Write-Output 'PASS: release export, bounded smoke and notice-copy contracts.'

$preset = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'export_presets.cfg')
if ($preset -notmatch 'include_filter="\*\.json"') { throw 'Export must include game JSON data.' }
foreach ($folder in @('tests', 'docs', 'tools', 'quality', 'release')) {
    if ($preset -notmatch ([regex]::Escape($folder + '/*'))) { throw "Export must exclude $folder artifacts." }
}
