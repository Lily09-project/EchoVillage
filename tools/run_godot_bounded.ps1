param(
	[Parameter(Mandatory = $true)] [string] $Godot,
	[Parameter(Mandatory = $true)] [string] $ProjectRoot,
	[Parameter(Mandatory = $true)] [string] $StandardOutput,
	[Parameter(Mandatory = $true)] [string] $StandardError,
	[Parameter(Mandatory = $true)] [int] $TimeoutSeconds,
	[Parameter(ValueFromRemainingArguments = $true)] [string[]] $GodotArguments
)

$ErrorActionPreference = 'Stop'

function Normalize-ProcessPath {
	$environment = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Process)
	$pathKey = @($environment.Keys | Where-Object { [string]$_ -ceq 'Path' } | Select-Object -First 1)
	if ($pathKey.Count -eq 0) {
		$pathKey = @($environment.Keys | Where-Object { [string]$_ -ieq 'Path' } | Select-Object -First 1)
	}
	$pathValue = if ($pathKey.Count -eq 1) { [string]$environment[$pathKey[0]] } else { '' }
	[Environment]::SetEnvironmentVariable('PATH', $null, [EnvironmentVariableTarget]::Process)
	[Environment]::SetEnvironmentVariable('Path', $pathValue, [EnvironmentVariableTarget]::Process)
	$pathKeys = @([Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Process).Keys | Where-Object { [string]$_ -ieq 'Path' })
	if ($pathKeys.Count -ne 1) {
		throw "Could not normalize process Path entries (found $($pathKeys.Count))."
	}
}

try {
	Normalize-ProcessPath
	if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
		throw "Godot executable does not exist: $Godot"
	}
	$process = Start-Process -FilePath $Godot -ArgumentList $GodotArguments -RedirectStandardOutput $StandardOutput -RedirectStandardError $StandardError -PassThru -WindowStyle Hidden -ErrorAction Stop
} catch {
	[Console]::Error.WriteLine("Godot launcher error: $($_.Exception.Message)")
	exit 125
}

if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
	Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
	[Console]::Error.WriteLine("Godot process timed out after $TimeoutSeconds seconds and was terminated.")
	exit 124
}

exit $process.ExitCode
