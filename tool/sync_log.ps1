<#
.SYNOPSIS
    Mirrors the running app's log from the device into <project>/flutter.log.

.DESCRIPTION
    This is the automatic counterpart to `dev_log.ps1`.

    An app running on a phone or emulator is sandboxed to the device and cannot
    write into your project folder. But its log file lives at a known path
    inside the app sandbox:

        app_flutter/logs/flutter.log

    `adb exec-out run-as` can read that straight out of a debuggable build, so
    we copy it to the project root. The big advantage over `dev_log.ps1` is
    that it does NOT take over `flutter run` — so you can keep using plain
    `flutter run`, VS Code's debugger and hot reload exactly as you do now, and
    flutter.log updates in the background at the same time.

    Requires a debuggable build (flutter run / profile). Release builds are not
    debuggable, so `run-as` is refused by the OS there.

.EXAMPLE
    .\tool\sync_log.ps1
    One-shot copy.

.EXAMPLE
    .\tool\sync_log.ps1 -Watch
    Keep copying every 2s until Ctrl+C. Run this alongside `flutter run`.

.EXAMPLE
    .\tool\sync_log.ps1 -Watch -IntervalSeconds 1
    Same, but poll faster.
#>
param(
    # Poll interval for -Watch.
    [int]$IntervalSeconds = 2,

    # adb serial, if more than one device is attached.
    [string]$Device,

    # Android applicationId.
    [string]$Package = 'com.zumimo.seller',

    # Keep syncing until interrupted.
    [switch]$Watch,

    # Delete the local copy first, then mirror the device log again. Note the
    # device file is the source of truth, so this does NOT truncate history —
    # use the in-app "Futa log" button to clear the log at its origin.
    [switch]$Clear
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$localLog = Join-Path $projectRoot 'flutter.log'
$remoteLog = 'app_flutter/logs/flutter.log'

function Write-Info($msg) { Write-Host $msg -ForegroundColor DarkGray }

function Get-TargetDevice {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        throw 'adb not found on PATH. Install Android platform-tools.'
    }

    $lines = & adb devices 2>&1
    $attached = @(
        $lines |
            Select-String -Pattern '^(\S+)\s+device$' |
            ForEach-Object { $_.Matches[0].Groups[1].Value }
    )

    if ($Device) {
        if ($attached -notcontains $Device) {
            throw "Device '$Device' is not attached."
        }
        return $Device
    }

    if ($attached.Count -eq 0) {
        throw 'No Android device attached. Plug one in or start an emulator.'
    }
    if ($attached.Count -gt 1) {
        throw "Multiple devices attached ($($attached -join ', ')). Re-run with -Device <serial>."
    }
    return $attached[0]
}

function Invoke-Pull {
    param([string]$Serial, [string]$Remote)

    # Read stdout as RAW BYTES and hand back the byte array untouched.
    #
    # The obvious version — read to a string, then write it out — silently
    # corrupts the log: PowerShell decodes native output using the ANSI/OEM
    # codepage, so UTF-8 characters in the log (the → and ── separators) come
    # out as mojibake. Copying the byte stream avoids the round-trip entirely.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'adb'
    $psi.Arguments = "-s $Serial exec-out run-as $Package cat $Remote"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)

    # Drain stderr concurrently so a full pipe buffer cannot deadlock the
    # stdout copy.
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    $buffer = New-Object System.IO.MemoryStream
    $proc.StandardOutput.BaseStream.CopyTo($buffer)
    $proc.WaitForExit()
    $bytes = $buffer.ToArray()

    if ($proc.ExitCode -ne 0) {
        throw "adb pull failed (exit $($proc.ExitCode)): $($stderrTask.Result.Trim())"
    }

    return $bytes
}

Write-Info "Project : $projectRoot"
Write-Info "Log file: $localLog"

if ($Clear -and (Test-Path -LiteralPath $localLog)) {
    Remove-Item -LiteralPath $localLog -Force
    Write-Info 'Local copy deleted; will re-mirror from the device.' -ForegroundColor DarkGray
}

try {
    $serial = Get-TargetDevice
    Write-Info "Device  : $serial" -ForegroundColor DarkGray
    Write-Info "Package : $Package" -ForegroundColor DarkGray
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}

# Tracks the last copy so we only write when the content actually changed,
# otherwise file watchers and open editor tabs reload for no reason.
$script:lastHash = $null

function Sync-Once {
    param([string]$Serial)

    try {
        $bytes = Invoke-Pull -Serial $Serial -Remote $remoteLog
    }
    catch {
        Write-Host "Pull failed: $_" -ForegroundColor Red
        return $false
    }

    if ($bytes.Length -eq 0) {
        # Normal before the app has logged anything.
        return $false
    }

    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($bytes))

    if ($hash -eq $script:lastHash) { return $true }

    [System.IO.File]::WriteAllBytes($localLog, $bytes)
    $script:lastHash = $hash

    # Decode only for counting, never for writing.
    $lineCount = ([System.Text.Encoding]::UTF8.GetString($bytes) -split "`n").Count
    Write-Host ("[{0}] synced {1} lines ({2} KB)" -f (Get-Date -Format 'HH:mm:ss'), $lineCount, [math]::Round($bytes.Length / 1KB, 1)) -ForegroundColor Green
    return $true
}

if (-not $Watch) {
    if (Sync-Once -Serial $serial) {
        Write-Host "Log mirrored to: $localLog" -ForegroundColor Green
    } else {
        Write-Host 'Nothing to copy yet. Run the app first with `flutter run`.' -ForegroundColor Yellow
    }
    exit 0
}

Write-Host 'Watching for log changes. Press Ctrl+C to stop.' -ForegroundColor Cyan
Write-Host 'You can now start the app however you like (flutter run, VS Code, Android Studio).' -ForegroundColor DarkGray

$misses = 0
while ($true) {
    $ok = Sync-Once -Serial $serial
    if (-not $ok) {
        $misses++
        if ($misses -eq 1) {
            Write-Host 'Waiting for the app to produce a log…' -ForegroundColor Yellow
        }
    } else {
        $misses = 0
    }
    Start-Sleep -Seconds $IntervalSeconds
}