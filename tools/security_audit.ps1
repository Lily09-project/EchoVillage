param(
	[string]$RootPath = (Split-Path -Parent $PSScriptRoot),
	[string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $RootPath).Path
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
	$ReportPath = Join-Path $root 'tests\security_audit_report.json'
} elseif (-not [IO.Path]::IsPathRooted($ReportPath)) {
	$ReportPath = Join-Path $root $ReportPath
}

$findings = New-Object System.Collections.Generic.List[object]
$tracked = @(& git -C $root ls-files)
if ($LASTEXITCODE -ne 0) { throw "Unable to enumerate tracked files under $root" }

function Add-Finding([string]$rule, [string]$path) {
	$findings.Add([ordered]@{ rule = $rule; path = $path })
}

$forbiddenExtensions = @('.exe','.dll','.zip','.pck','.pem','.key','.p12','.pfx')
$textExtensions = @('.bat','.cfg','.gd','.json','.md','.ps1','.txt','.yml','.yaml','.example')
$secretPatterns = [ordered]@{
	private_key = '-----BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY-----'
	github_token = '(?i)\b(?:ghp_|github_pat_)[A-Za-z0-9_]{20,}\b'
	aws_access_key = '\bAKIA[0-9A-Z]{16}\b'
	openai_key = '(?i)\bsk-[A-Za-z0-9]{20,}\b'
	secret_assignment = '(?im)\b(?:api[_-]?key|access[_-]?token|password|secret)\b\s*[:=]\s*[A-Za-z0-9_\-+/=]{12,}'
}

foreach ($relative in $tracked) {
	$normalized = ([string]$relative).Replace('\','/')
	$lower = $normalized.ToLowerInvariant()
	$extension = [IO.Path]::GetExtension($normalized).ToLowerInvariant()
	$fullPath = Join-Path $root $relative

	if ($lower -match '(^|/)(\.env|\.env\..+)$' -and $lower -ne '.env.example') { Add-Finding 'tracked_env_file' $normalized }
	if ($lower -match '(^|/)(\.godot|\.import|release)(/|$)') { Add-Finding 'tracked_generated_or_release_directory' $normalized }
	if ($lower -match '(^|/)echo_village_(save|preferences)\.json$') { Add-Finding 'tracked_user_save_or_preferences' $normalized }
	if ($forbiddenExtensions -contains $extension) { Add-Finding 'tracked_binary_or_private_key_artifact' $normalized }

	if ($textExtensions -contains $extension -and (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
		$length = (Get-Item -LiteralPath $fullPath).Length
		if ($length -le 5242880) {
			$content = [IO.File]::ReadAllText($fullPath)
			foreach ($rule in $secretPatterns.Keys) {
				if ([regex]::IsMatch($content,[string]$secretPatterns[$rule])) { Add-Finding $rule $normalized }
			}
		}
	}
}

$reportDirectory = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $reportDirectory)) { New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null }
$commit = ((git -C $root rev-parse --short HEAD) -join '').Trim()
$report = @{}
$report['project'] = 'Echo Village'
$report['timestamp'] = [DateTime]::UtcNow.ToString('o')
$report['commit'] = $commit
$report['tracked_files'] = $tracked.Count
$report['finding_count'] = $findings.Count
$report['passed'] = ($findings.Count -eq 0)
$report['findings'] = $findings.ToArray()
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($findings.Count -gt 0) {
	Write-Error ("Security audit failed with {0} finding(s). See report: {1}" -f $findings.Count,$ReportPath)
	exit 1
}
Write-Output ("PASS: security audit scanned {0} tracked files; no secret or release artifact findings. Report: {1}" -f $tracked.Count,$ReportPath)
