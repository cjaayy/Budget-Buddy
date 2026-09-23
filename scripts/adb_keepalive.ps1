[CmdletBinding()]
param (
    [string]$DeviceId,
    [string]$SavedIp,
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = "SilentlyContinue"

if (-not (Test-Path $AdbPath)) {
    $whereAdb = (Get-Command adb -ErrorAction SilentlyContinue).Source
    if ($whereAdb) { $AdbPath = $whereAdb }
}

if (-not (Test-Path $AdbPath)) {
    exit 1
}

while ($true) {
    Start-Sleep -Seconds 12

    if ($DeviceId) {
        $state = (& "$AdbPath" -s $DeviceId get-state 2>$null)
        if ($LASTEXITCODE -ne 0 -or $state -ne "device") {
            if ($SavedIp) {
                & "$AdbPath" connect "$SavedIp:5555" >$null 2>&1
            }
        } else {
            # Keep alive ping
            & "$AdbPath" -s $DeviceId shell "settings put global wifi_sleep_policy 2" >$null 2>&1
        }
    }
}
