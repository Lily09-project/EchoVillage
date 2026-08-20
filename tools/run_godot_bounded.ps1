param(
	[Parameter(Mandatory = $true)] [string] $Godot,
	[Parameter(Mandatory = $true)] [string] $ProjectRoot,
	[Parameter(Mandatory = $true)] [string] $StandardOutput,
	[Parameter(Mandatory = $true)] [string] $StandardError,
	[Parameter(Mandatory = $true)] [int] $TimeoutSeconds,
	[Parameter(ValueFromRemainingArguments = $true)] [string[]] $GodotArguments
)

$ErrorActionPreference = 'Stop'

function ConvertTo-ProcessArgument {
	param([string] $Argument)
	if ($null -eq $Argument) { return '' }
	if ($Argument -notmatch '[\s"]') { return $Argument }
	# The runner only passes paths and switches (never embedded quotes). Escaping
	# backslashes before a closing quote keeps Windows argument parsing stable.
	return '"' + $Argument.Replace('"', '\"') + '"'
}

function New-IsolatedProcessStartInfo {
	param(
		[string] $FilePath,
		[string[]] $Arguments,
		[string] $WorkingDirectory
	)
	$info = New-Object System.Diagnostics.ProcessStartInfo
	$info.FileName = $FilePath
	$info.WorkingDirectory = $WorkingDirectory
	$info.Arguments = (($Arguments | ForEach-Object { ConvertTo-ProcessArgument ([string]$_) }) -join ' ')
	$info.UseShellExecute = $false
	$info.CreateNoWindow = $true
	$info.RedirectStandardOutput = $true
	$info.RedirectStandardError = $true

	# ProcessStartInfo avoids Start-Process' duplicate Path/PATH serialization
	# failure while preserving the caller's environment for Godot user data.
	return $info
}

function Stop-ProcessTree {
	param([int] $ProcessId)

	# Godot's editor bootstrap can spawn a second process (for example when it
	# imports the project cache). Stopping only the direct child leaves that
	# process behind and makes a one-command test appear hung on the next run.
	try {
		& "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>$null | Out-Null
	} catch {
		Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
	}
}

try {
	if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
		throw "Godot executable does not exist: $Godot"
	}
	if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
		throw "Godot project root does not exist: $ProjectRoot"
	}
	$startInfo = New-IsolatedProcessStartInfo -FilePath $Godot -Arguments $GodotArguments -WorkingDirectory $ProjectRoot
	$process = [System.Diagnostics.Process]::new()
	$process.StartInfo = $startInfo
	if (-not $process.Start()) { throw "Process.Start returned false for $Godot" }
	$stdoutTask = $process.StandardOutput.ReadToEndAsync()
	$stderrTask = $process.StandardError.ReadToEndAsync()
} catch {
	[Console]::Error.WriteLine("Godot launcher error: $($_.Exception.Message)")
	exit 125
}

if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
	Stop-ProcessTree -ProcessId $process.Id
	$process.WaitForExit()
	[System.IO.File]::WriteAllText($StandardOutput, $stdoutTask.Result)
	[System.IO.File]::WriteAllText($StandardError, $stderrTask.Result)
	[Console]::Error.WriteLine("Godot process timed out after $TimeoutSeconds seconds and was terminated.")
	exit 124
}

[System.IO.File]::WriteAllText($StandardOutput, $stdoutTask.Result)
[System.IO.File]::WriteAllText($StandardError, $stderrTask.Result)
exit $process.ExitCode
