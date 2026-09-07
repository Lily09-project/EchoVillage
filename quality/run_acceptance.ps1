[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Profile,
    [string]$Manifest,
    [string]$ReportRoot,
    [switch]$List
)

$ErrorActionPreference = "Stop"
$script:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Manifest) {
    $Manifest = Join-Path $script:ScriptDirectory "test-manifest.json"
}
$script:ProjectRoot = (Resolve-Path (Join-Path $script:ScriptDirectory "..")).Path
if (-not $ReportRoot) {
    $ReportRoot = Join-Path $script:ProjectRoot "reports\acceptance"
}

function Assert-CommandArray {
    param($Value, [string]$Label)
    if ($null -eq $Value -or $Value.Count -eq 0) {
        throw "$Label must be a non-empty string array"
    }
    foreach ($item in $Value) {
        if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
            throw "$Label must contain only non-empty strings"
        }
    }
}

function Read-AndValidateManifest {
    param([string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $value = Get-Content -LiteralPath $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($value.schema_version -ne "1.0") { throw "schema_version must be 1.0" }
    if ([string]::IsNullOrWhiteSpace($value.project)) { throw "project must be non-empty" }
    if ($value.profiles.Count -eq 0) { throw "profiles must not be empty" }
    $profiles = @{}
    foreach ($profileName in $value.profiles) {
        if ([string]::IsNullOrWhiteSpace($profileName) -or $profiles.ContainsKey($profileName)) {
            throw "profiles must contain unique non-empty strings"
        }
        $profiles[$profileName] = $true
    }
    $ids = @{}
    foreach ($gate in $value.gates) {
        if ([string]::IsNullOrWhiteSpace($gate.id) -or $ids.ContainsKey($gate.id)) {
            throw "gate ids must be unique and non-empty"
        }
        $ids[$gate.id] = $true
        if ($gate.type -ne "command") { throw "EchoVillage gate '$($gate.id)' must use command type" }
        Assert-CommandArray $gate.command "gate '$($gate.id)'.command"
        if ($gate.timeout_seconds -lt 1 -or $gate.timeout_seconds -gt 7200) {
            throw "gate '$($gate.id)' timeout must be between 1 and 7200"
        }
        if ($gate.required -isnot [bool]) { throw "gate '$($gate.id)' required must be boolean" }
        if ($gate.evidence_freshness -and $gate.evidence_freshness -notin @('existing', 'generated')) {
            throw "gate '$($gate.id)' evidence_freshness must be existing or generated"
        }
        if ($gate.evidence_freshness -eq 'generated' -and @($gate.evidence).Count -eq 0) {
            throw "gate '$($gate.id)' generated evidence requires at least one path"
        }
        foreach ($gateProfile in $gate.profiles) {
            if (-not $profiles.ContainsKey($gateProfile)) {
                throw "gate '$($gate.id)' contains unknown profile '$gateProfile'"
            }
        }
    }
    return @{ Value = $value; Path = $resolved }
}

function ConvertTo-NativeArgument {
    param([string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Expand-Command {
    param($Command, [string]$TempDirectory)
    $expanded = @()
    foreach ($item in $Command) {
        $expanded += $item.Replace("{root}", $script:ProjectRoot).Replace("{temp}", $TempDirectory)
    }
    return ,$expanded
}

function Get-ProjectRelativePath {
    param([string]$Path)
    $rootWithSeparator = $script:ProjectRoot.TrimEnd('\') + '\'
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside project root: $fullPath"
    }
    return $fullPath.Substring($rootWithSeparator.Length).Replace('\', '/')
}

function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Process)
    if ($Process.HasExited) { return }
    & taskkill.exe /PID $Process.Id /T /F *> $null
    try { $Process.WaitForExit(10000) | Out-Null } catch {}
}

function Invoke-Gate {
    param($Gate, [string]$RunDirectory, [string]$TempDirectory)
    $stdoutPath = Join-Path $RunDirectory "$($Gate.id).stdout.log"
    $stderrPath = Join-Path $RunDirectory "$($Gate.id).stderr.log"
    $command = Expand-Command $Gate.command $TempDirectory
    $arguments = @($command | Select-Object -Skip 1 | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = $null
    $failure = $null
    $timedOut = $false
    $process = $null
    $evidenceBefore = @{}
    foreach ($path in @($Gate.evidence)) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $fullEvidencePath = Join-Path $script:ProjectRoot $path
        if (Test-Path -LiteralPath $fullEvidencePath -PathType Leaf) {
            $evidenceBefore[$path] = (Get-Item -LiteralPath $fullEvidencePath).LastWriteTimeUtc.Ticks
        }
    }
    try {
        $process = Start-Process -FilePath $command[0] -ArgumentList $arguments `
            -WorkingDirectory $script:ProjectRoot -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit([int]$Gate.timeout_seconds * 1000)) {
            $timedOut = $true
            $failure = "timed out after $($Gate.timeout_seconds) seconds"
            Stop-ProcessTree $process
        }
        else {
            # A second wait flushes redirected streams on Windows PowerShell 5.1.
            $process.WaitForExit()
            $process.Refresh()
            $exitCode = [int]$process.ExitCode
            if ($exitCode -ne 0) { $failure = "command exited with code $exitCode" }
        }
    }
    catch {
        $failure = "failed to start: $($_.Exception.Message)"
        if (-not (Test-Path -LiteralPath $stdoutPath)) { Set-Content -LiteralPath $stdoutPath -Value "" -Encoding UTF8 }
        Set-Content -LiteralPath $stderrPath -Value $failure -Encoding UTF8
    }
    finally {
        if ($null -ne $process -and -not $process.HasExited) { Stop-ProcessTree $process }
        $timer.Stop()
    }
    $evidence = @()
    foreach ($path in @($Gate.evidence)) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $fullEvidencePath = Join-Path $script:ProjectRoot $path
        $exists = Test-Path -LiteralPath $fullEvidencePath -PathType Leaf
        $entry = [ordered]@{ path = $path; exists = $exists }
        if ($exists) {
            $file = Get-Item -LiteralPath $fullEvidencePath
            $entry['size_bytes'] = [long]$file.Length
            $entry['sha256'] = (Get-FileHash -LiteralPath $fullEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
            $entry['modified_at'] = $file.LastWriteTimeUtc.ToString('o')
            $entry['fresh'] = $(if ($Gate.evidence_freshness -eq 'generated') {
                -not $evidenceBefore.ContainsKey($path) -or $file.LastWriteTimeUtc.Ticks -ne $evidenceBefore[$path]
            } else { $null })
        }
        $evidence += $entry
    }
    $missingEvidence = @($evidence | Where-Object { -not $_.exists } | ForEach-Object { $_.path })
    $staleEvidence = @($evidence | Where-Object { $_.fresh -eq $false } | ForEach-Object { $_.path })
    if ($null -eq $failure -and $missingEvidence.Count -gt 0) {
        $failure = "required evidence missing: $($missingEvidence -join ', ')"
    }
    if ($null -eq $failure -and $staleEvidence.Count -gt 0) {
        $failure = "required evidence not refreshed: $($staleEvidence -join ', ')"
    }
    return [ordered]@{
        id = $Gate.id
        category = $Gate.category
        status = $(if ($null -eq $failure -and $exitCode -eq 0) { "passed" } else { "failed" })
        required = [bool]$Gate.required
        exit_code = $exitCode
        duration_seconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
        timed_out = $timedOut
        stdout_log = Get-ProjectRelativePath $stdoutPath
        stderr_log = Get-ProjectRelativePath $stderrPath
        service_logs = @()
        evidence = $evidence
        failure_reason = $failure
    }
}

try {
    $loaded = Read-AndValidateManifest $Manifest
    $manifestObject = $loaded.Value
}
catch {
    Write-Error "MANIFEST ERROR: $($_.Exception.Message)"
    exit 2
}

if ($List) {
    Write-Output ("profiles: " + ($manifestObject.profiles -join ", "))
    foreach ($gate in $manifestObject.gates) {
        Write-Output ("$($gate.id): " + ($gate.profiles -join ","))
    }
    exit 0
}
if ([string]::IsNullOrWhiteSpace($Profile) -or $manifestObject.profiles -notcontains $Profile) {
    Write-Error ("Profile is required and must be one of: " + ($manifestObject.profiles -join ", "))
    exit 2
}

$runId = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-$PID"
$resolvedReportRoot = [IO.Path]::GetFullPath($ReportRoot)
$runDirectory = Join-Path $resolvedReportRoot $runId
New-Item -ItemType Directory -Path $runDirectory -ErrorAction Stop | Out-Null
$tempDirectory = Join-Path ([IO.Path]::GetTempPath()) "$($manifestObject.project)-$runId"
New-Item -ItemType Directory -Path $tempDirectory -ErrorAction Stop | Out-Null
$startedAt = [DateTime]::UtcNow.ToString("o")
$totalTimer = [Diagnostics.Stopwatch]::StartNew()
$results = @()
$blocked = $false
try {
    foreach ($gate in $manifestObject.gates) {
        if ($gate.profiles -notcontains $Profile) { continue }
        if ($blocked) {
            $results += [ordered]@{
                id = $gate.id; category = $gate.category; status = "skipped"; required = [bool]$gate.required
                exit_code = $null; duration_seconds = 0.0; timed_out = $false
                stdout_log = $null; stderr_log = $null; service_logs = @(); evidence = @()
                failure_reason = "skipped after an earlier required gate failed"
            }
            Write-Output "[SKIPPED] $($gate.id)"
            continue
        }
        $result = Invoke-Gate $gate $runDirectory $tempDirectory
        $results += $result
        Write-Output "[$($result.status.ToUpperInvariant())] $($gate.id) ($($result.duration_seconds)s)"
        if ($result.status -eq "failed" -and $result.required) { $blocked = $true }
    }
}
finally {
    if (Test-Path -LiteralPath $tempDirectory) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
    $totalTimer.Stop()
}

$gitCommit = $null
$gitDirty = $null
try {
    $gitCommit = (& git -c "safe.directory=$script:ProjectRoot" -C $script:ProjectRoot rev-parse HEAD 2>$null).Trim()
    $gitStatus = (& git -c "safe.directory=$script:ProjectRoot" -C $script:ProjectRoot status --porcelain 2>$null) -join "`n"
    $gitDirty = -not [string]::IsNullOrWhiteSpace($gitStatus)
}
catch {}

$passed = @($results | Where-Object { $_.status -eq "passed" }).Count
$failed = @($results | Where-Object { $_.status -eq "failed" }).Count
$skipped = @($results | Where-Object { $_.status -eq "skipped" }).Count
$requiredFailure = @($results | Where-Object { $_.status -eq "failed" -and $_.required }).Count -gt 0
$report = [ordered]@{
    schema_version = "1.0"
    project = $manifestObject.project
    profile = $Profile
    manifest_sha256 = (Get-FileHash -LiteralPath $loaded.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    started_at = $startedAt
    finished_at = [DateTime]::UtcNow.ToString("o")
    duration_seconds = [math]::Round($totalTimer.Elapsed.TotalSeconds, 3)
    status = $(if ($requiredFailure) { "failed" } else { "passed" })
    environment = [ordered]@{
        platform = [Environment]::OSVersion.VersionString
        runtime = $PSVersionTable.PSVersion.ToString()
        git_commit = $gitCommit
        git_dirty = $gitDirty
    }
    summary = [ordered]@{ total = $results.Count; passed = $passed; failed = $failed; skipped = $skipped }
    gates = $results
}
$reportPath = Join-Path $runDirectory "acceptance-report.json"
$temporaryReport = "$reportPath.tmp"
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporaryReport -Encoding UTF8
Move-Item -LiteralPath $temporaryReport -Destination $reportPath -Force
Write-Output "report: $reportPath"
if ($requiredFailure) { exit 1 }
exit 0
