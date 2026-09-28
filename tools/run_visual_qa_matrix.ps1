param(
    [string]$GodotExecutable = "",
    [string]$OutputRoot = "",
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

function Get-PngDimensions {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 24 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 0x4E -or $bytes[3] -ne 0x47) {
        throw "Visual QA capture is not a valid PNG: $Path"
    }
    $width = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
    $height = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]
    return @{ width = $width; height = $height }
}
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_EXECUTABLE)) {
        $GodotExecutable = $env:GODOT_EXECUTABLE
    } else {
        $GodotExecutable = Join-Path $root 'tools\godot\Godot_v4.5.2-stable_win64.exe'
    }
}
if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot GUI runtime was not found: $GodotExecutable"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $root 'reports\visual_qa\matrix'
}

$captures = @(
    'storybook_intro.png', 'storybook_explore_dawn.png', 'storybook_explore_noon.png',
    'npc_decision_explanation.png', 'storybook_explore_night.png', 'storybook_event_danger.png',
    'quest_in_progress.png', 'forest_echo_complete.png', 'consumer_main_menu.png',
    'consumer_settings.png', 'consumer_trade.png', 'village_progression.png',
    'story_arc_active.png', 'relationship_history.png', 'consumer_onboarding.png'
)
$resolutions = @(
    @{ name = 'desktop-1280x720'; argument = '1280x720'; width = 1280; height = 720 },
    @{ name = 'compact-1024x576'; argument = '1024x576'; width = 1024; height = 576 },
    @{ name = 'small-800x450'; argument = '800x450'; width = 800; height = 450 },
    @{ name = 'large-1600x900'; argument = '1600x900'; width = 1600; height = 900 }
)

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$resolutionReports = @()
foreach ($resolution in $resolutions) {
    $directory = Join-Path $OutputRoot $resolution.name
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $stdout = Join-Path $directory 'runtime.stdout.log'
    $stderr = Join-Path $directory 'runtime.stderr.log'
    $env:ECHO_VILLAGE_VISUAL_QA = '1'
    $env:ECHO_VILLAGE_VISUAL_QA_OUTPUT_DIR = $directory

    & (Join-Path $root 'tools\run_godot_bounded.ps1') `
        -Godot $GodotExecutable `
        -ProjectRoot $root `
        -StandardOutput $stdout `
        -StandardError $stderr `
        -TimeoutSeconds $TimeoutSeconds `
        --audio-driver Dummy --path $root --resolution $resolution.argument
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Visual QA runtime failed at $($resolution.argument) with exit code $exitCode. See $stderr"
    }

    $files = @()
    foreach ($capture in $captures) {
        $path = Join-Path $directory $capture
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Missing visual QA capture at $($resolution.argument): $capture"
        }
        $dimensions = Get-PngDimensions -Path $path
        if ($dimensions.width -ne $resolution.width -or $dimensions.height -ne $resolution.height) {
            throw "Unexpected capture dimensions at $($resolution.argument): $capture ($($dimensions.width)x$($dimensions.height))"
        }
        $files += [ordered]@{
            name = $capture
            width = [int]$resolution.width
            height = [int]$resolution.height
            size_bytes = [int64](Get-Item -LiteralPath $path).Length
        }
    }
    $resolutionReports += [ordered]@{
        name = $resolution.name
        resolution = $resolution.argument
        captures = $files
    }
}

$report = [ordered]@{
    schema_version = '1.0'
    status = 'passed'
    project = 'EchoVillage'
    capture_count = $captures.Count
    resolutions = $resolutionReports
}
$reportPath = Join-Path $OutputRoot 'matrix-report.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
Write-Output "PASS: $($captures.Count) captures × $($resolutions.Count) resolutions"
Write-Output "REPORT: $reportPath"
