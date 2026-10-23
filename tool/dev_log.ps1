<#
.SYNOPSIS
    Runs the app and mirrors every log line into <project>/flutter.log.

.DESCRIPTION
    This is the development counterpart to the in-app log viewer.

    A build running on a phone or emulator is sandboxed to the device and
    physically cannot write into your project folder. So the file has to be
    produced here on the host by capturing the app's stdout. AppLogger already
    mirrors everything to the console in debug mode, so capturing stdout
    captures the whole log.

.EXAMPLE
    .\tool\dev_log.ps1
    Run on the default device, tail <project>\flutter.log live.

.EXAMPLE
    .\tool\dev_log.ps1 -Device chrome
    Run in Chrome.

.EXAMPLE
    .\tool\dev_log.ps1 -Attach
    Do not build; just tail an already-running app (use after `flutter run`
    in another terminal, or when debugging a real device).
#>
param(
    # Target passed to `flutter run`. Omit to let Flutter pick.
    [string]$Device,

    # Skip launching; capture logs from an app already running on a device.
    [switch]$Attach,

    # Truncate the log before starting instead of appending.
    [switch]$Truncate,

    # Pass extra args straight through to `flutter run`.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$logFile = Join-Path $projectRoot 'flutter.log'

Write-Host "Project : $projectRoot" -ForegroundColor DarkGray
Write-Host "Log file: $logFile" -ForegroundColor DarkGray

if ($Truncate -and (Test-Path -LiteralPath $logFile)) {
    Remove-Item -LiteralPath $logFile -Force
    Write-Host 'Existing log cleared.' -ForegroundColor DarkGray
}

# Strip ANSI colour codes so the file stays greppable, and drop the blank
# lines Flutter's hot-reload banner sprays out.
function Format-LogLine {
    param([string]$Line)
    $clean = $Line -replace "`e\[[0-9;]*[A-Za-z]", ''
    if ($clean.Trim().Length -eq 0) { return $null }
    return $clean
}

function Write-Banner {
    param([string]$Text)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    "[$ts] ===== $Text ====="
}

if ($Attach) {
    Write-Host 'Attaching to running app. Press Ctrl+C to stop.' -ForegroundColor Yellow
    $flutterArgs = @('logs')
    if ($Device) { $flutterArgs += @('-d', $Device) }
}
else {
    $flutterArgs = @('run')
    if ($Device) { $flutterArgs += @('-d', $Device) }
    if ($FlutterArgs) { $flutterArgs += $FlutterArgs }
}

Write-Host "Running: flutter $($flutterArgs -join ' ')" -ForegroundColor Cyan
Write-Host 'Tail it in a second window:  Get-Content flutter.log -Wait' -ForegroundColor DarkGray

Add-Content -LiteralPath $logFile -Value (Write-Banner 'session start') -Encoding utf8

# Order matters: strip ANSI and drop blanks FIRST, then Tee once. Teeing and
# also Add-Contenting would write every line to the file twice.
# Tee-Object is last so it both writes the file and echoes live to this window.
& flutter @flutterArgs 2>&1 |
    ForEach-Object { Format-LogLine -Line "$_" } |
    Where-Object { $null -ne $_ } |
    Tee-Object -FilePath $logFile -Append

Add-Content -LiteralPath $logFile -Value (Write-Banner 'session end') -Encoding utf8
Write-Host "Done. Full log at: $logFile" -ForegroundColor Green