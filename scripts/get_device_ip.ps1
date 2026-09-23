[CmdletBinding()]
param (
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string]$DeviceId
)

$ErrorActionPreference = "SilentlyContinue"

if (-not (Test-Path $AdbPath)) {
    $whereAdb = (Get-Command adb -ErrorAction SilentlyContinue).Source
    if ($whereAdb) { $AdbPath = $whereAdb }
}

if (-not (Test-Path $AdbPath)) {
    exit 1
}

# Determine target device if not specified
if (-not $DeviceId) {
    $rawDevices = & "$AdbPath" devices 2>$null
    $deviceList = @()
    foreach ($rawLine in $rawDevices) {
        $line = "$rawLine".Trim()
        if ($line -and $line -notmatch '^List of' -and $line -match '\s+device$') {
            $id = ($line -split '\s+')[0]
            $deviceList += $id
        }
    }

    # Prefer USB device (doesn't contain colon or tcp/tls)
    $usbDevice = $deviceList | Where-Object { $_ -notmatch ':\d+' -and $_ -notmatch '_tcp' } | Select-Object -First 1
    if ($usbDevice) {
        $DeviceId = $usbDevice
    } elseif ($deviceList.Count -gt 0) {
        $DeviceId = $deviceList[0]
    }
}

$adbArgs = if ($DeviceId) { @("-s", $DeviceId) } else { @() }

# Method 1: Check ip -f inet addr show wlan0
$wlanOutput = & "$AdbPath" @adbArgs shell ip -f inet addr show wlan0 2>$null
foreach ($line in $wlanOutput) {
    if ("$line".Trim() -match 'inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)') {
        $ip = $matches[1]
        if ($ip -ne "127.0.0.1" -and $ip -ne "0.0.0.0") {
            Write-Output $ip
            exit 0
        }
    }
}

# Method 2: Check ip route
$routeOutput = & "$AdbPath" @adbArgs shell ip route 2>$null
foreach ($line in $routeOutput) {
    $trimmed = "$line".Trim()
    if ($trimmed -match 'dev\s+wlan0\s+.*src\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' -or
        $trimmed -match 'src\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*dev\s+wlan0' -or
        $trimmed -match 'src\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)') {
        $ip = $matches[1]
        if ($ip -ne "127.0.0.1" -and $ip -notmatch '^172\.(1[6-9]|2[0-9]|3[0-1])\.' -and $ip -ne "0.0.0.0") {
            Write-Output $ip
            exit 0
        }
    }
}

# Method 3: dhcp.wlan0.ipaddress property
$propIp = (& "$AdbPath" @adbArgs shell getprop dhcp.wlan0.ipaddress 2>$null)
if ($propIp) {
    $cleanProp = "$propIp".Trim()
    if ($cleanProp -match '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$') {
        Write-Output $cleanProp
        exit 0
    }
}

# Method 4: ifconfig wlan0
$ifcfg = & "$AdbPath" @adbArgs shell ifconfig wlan0 2>$null
foreach ($line in $ifcfg) {
    if ("$line".Trim() -match 'inet addr:\s*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)') {
        Write-Output $matches[1]
        exit 0
    }
}

exit 1
