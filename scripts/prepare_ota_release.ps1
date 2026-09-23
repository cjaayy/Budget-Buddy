[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("scan", "apply")]
    [string]$Action,

    [string]$NewVersion,
    [int]$NewBuild,
    [string]$GhUser = "cjaayy",
    [string]$GhRepo = "Budget-Buddy",
    [string]$ReleaseNotesFile
)

$ErrorActionPreference = "Stop"

# Determine project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path (Join-Path $scriptDir "..\pubspec.yaml")) {
    $projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
} elseif (Test-Path (Join-Path $scriptDir "pubspec.yaml")) {
    $projectRoot = $scriptDir
} else {
    Write-Error "Could not locate pubspec.yaml in project root."
    exit 1
}

$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$versionJsonPath = Join-Path $projectRoot "version.json"
$otaEnvBatPath = Join-Path $scriptDir ".ota_env.bat"
$defaultNotesPath = Join-Path $scriptDir ".release_notes.txt"

function Get-CurrentVersionFromPubspec {
    $content = Get-Content -Path $pubspecPath -Raw
    if ($content -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?') {
        $ver = $matches[1]
        $bld = if ($matches[2]) { [int]$matches[2] } else { 1 }
        return @{ Version = $ver; Build = $bld }
    }
    return @{ Version = "1.0.0"; Build = 1 }
}

function Get-NextVersion {
    param([string]$ver)
    $parts = $ver.Split('.')
    if ($parts.Length -eq 3) {
        $patch = [int]$parts[2] + 1
        return "$($parts[0]).$($parts[1]).$patch"
    }
    return "$ver.1"
}

if ($Action -eq "scan") {
    $current = Get-CurrentVersionFromPubspec
    $nextVer = Get-NextVersion -ver $current.Version
    $nextBuild = $current.Build + 1

    # Check git commits since last tag
    $commits = @()
    try {
        $latestTag = (git describe --tags --abbrev=0 2>$null)
        if ($latestTag) {
            $rawCommits = (git log "$latestTag..HEAD" --oneline 2>$null)
        } else {
            $rawCommits = (git log -n 10 --oneline 2>$null)
        }

        if ($rawCommits) {
            if ($rawCommits -is [string]) {
                $commits = @($rawCommits)
            } else {
                $commits = $rawCommits
            }
        }
    } catch {
        $commits = @()
    }

    $commitCount = $commits.Count

    # Write .ota_env.bat
    $batContent = @"
set "CURRENT_VER=$($current.Version)"
set "CURRENT_BUILD=$($current.Build)"
set "DEFAULT_NEXT_VER=$nextVer"
set "DEFAULT_NEXT_BUILD=$nextBuild"
set "COMMITS_COUNT=$commitCount"
"@
    Set-Content -Path $otaEnvBatPath -Value $batContent -Encoding ASCII

    # Format release notes markdown
    $notesList = [System.Collections.Generic.List[string]]::new()
    $notesList.Add("## What's Changed in v$nextVer")
    $notesList.Add("")
    if ($commits.Count -gt 0) {
        foreach ($c in $commits) {
            # Strip commit hash if present
            $cleaned = $c -replace '^[0-9a-fA-F]+\s+', ''
            $notesList.Add("- $cleaned")
        }
    } else {
        $notesList.Add("- Maintenance and performance updates.")
    }
    $notesList.Add("")
    $notesList.Add("**Full Changelog**: https://github.com/$GhUser/$GhRepo/releases/tag/v$nextVer")

    Set-Content -Path $defaultNotesPath -Value ($notesList -join "`r`n") -Encoding UTF8

    Write-Host "[prepare_ota_release] Current version: $($current.Version)+$($current.Build)"
    Write-Host "[prepare_ota_release] Next recommended: $nextVer+$nextBuild"
    Write-Host "[prepare_ota_release] Commits scanned: $commitCount"
    exit 0
}

if ($Action -eq "apply") {
    if (-not $NewVersion) {
        Write-Error "NewVersion parameter is required for Action apply."
        exit 1
    }
    if (-not $NewBuild) {
        $NewBuild = 1
    }

    Write-Host "[prepare_ota_release] Updating pubspec.yaml to $NewVersion+$NewBuild..."
    $pubspecRaw = Get-Content -Path $pubspecPath -Raw
    $updatedPubspec = $pubspecRaw -replace 'version:\s*[^\r\n]+', "version: $NewVersion+$NewBuild"
    Set-Content -Path $pubspecPath -Value $updatedPubspec -Encoding UTF8

    # Determine notes
    $finalNotes = ""
    if ($ReleaseNotesFile -and (Test-Path $ReleaseNotesFile)) {
        $customRaw = Get-Content -Path $ReleaseNotesFile -Raw
        if (-not [string]::IsNullOrWhiteSpace($customRaw)) {
            $finalNotes = $customRaw.Trim()
        }
    }

    if (-not $finalNotes -and (Test-Path $defaultNotesPath)) {
        $finalNotes = (Get-Content -Path $defaultNotesPath -Raw).Trim()
    }

    if (-not $finalNotes) {
        $finalNotes = "Budget Buddy v$NewVersion release."
    }

    # Ensure default notes file has the final content
    Set-Content -Path $defaultNotesPath -Value $finalNotes -Encoding UTF8

    Write-Host "[prepare_ota_release] Updating version.json..."
    $downloadUrl = "https://github.com/$GhUser/$GhRepo/releases/download/v$NewVersion/app-release.apk"
    $pubDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    $versionObj = [ordered]@{
        app_name      = "Budget Buddy"
        package_name  = "com.budgetbuddy.app"
        version       = $NewVersion
        build_number  = $NewBuild
        tag_name      = "v$NewVersion"
        title         = "Budget Buddy v$NewVersion"
        release_notes = $finalNotes
        download_url  = $downloadUrl
        published_at  = $pubDate
        mandatory     = $false
    }

    $jsonContent = $versionObj | ConvertTo-Json -Depth 4
    Set-Content -Path $versionJsonPath -Value $jsonContent -Encoding UTF8

    Write-Host "[prepare_ota_release] Version files successfully updated to v$NewVersion+$NewBuild."
    exit 0
}
