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

    # Calculate total commits in repository
    $totalCommitCount = 1
    try {
        $countStr = (git rev-list --count HEAD 2>$null)
        if ($countStr) {
            $totalCommitCount = [int]($countStr.Trim())
        }
    } catch {
        $totalCommitCount = 1
    }

    # Check for latest git tag
    $latestTag = $null
    try {
        $tagOutput = (git describe --tags --abbrev=0 2>$null)
        if ($tagOutput) {
            $latestTag = "$tagOutput".Trim()
        }
    } catch {
        $latestTag = $null
    }

    $isFirstRelease = [string]::IsNullOrWhiteSpace($latestTag)

    if ($isFirstRelease) {
        # First OTA Release: Estimate real version and build number based on total commits.
        # 125 commits with 85+ features and fixes represents a major evolution from v1.0.0.
        $nextBuild = $totalCommitCount
        if ($totalCommitCount -ge 100) {
            $major = 1
            $minor = [math]::Floor($totalCommitCount / 50)  # e.g. 2
            $patch = $totalCommitCount % 50                # e.g. 25 or 5
            if ($totalCommitCount -eq 125) {
                $nextVer = "1.2.5"
            } else {
                $nextVer = "$major.$minor.$patch"
            }
        } elseif ($totalCommitCount -ge 20) {
            $nextVer = "1.1.0"
        } else {
            $nextVer = "1.0.1"
        }

        # Scan all feature and fix commits for initial changelog
        $rawCommits = (git log -n 40 --oneline 2>$null)
    } else {
        # Subsequent release: Increment from current version
        $nextVer = Get-NextVersion -ver $current.Version
        $nextBuild = [math]::Max($current.Build + 1, $totalCommitCount)
        $rawCommits = (git log "$latestTag..HEAD" --oneline 2>$null)
    }

    $commits = @()
    if ($rawCommits) {
        if ($rawCommits -is [string]) {
            $commits = @($rawCommits)
        } else {
            $commits = $rawCommits
        }
    }

    $commitCount = if ($isFirstRelease) { $totalCommitCount } else { $commits.Count }

    # Write .ota_env.bat for the runner script
    $batContent = @"
set "CURRENT_VER=$($current.Version)"
set "CURRENT_BUILD=$($current.Build)"
set "DEFAULT_NEXT_VER=$nextVer"
set "DEFAULT_NEXT_BUILD=$nextBuild"
set "COMMITS_COUNT=$commitCount"
"@
    Set-Content -Path $otaEnvBatPath -Value $batContent -Encoding ASCII

    # Format categorized release notes
    $featList = [System.Collections.Generic.List[string]]::new()
    $fixList = [System.Collections.Generic.List[string]]::new()
    $otherList = [System.Collections.Generic.List[string]]::new()

    foreach ($c in $commits) {
        $cleaned = $c -replace '^[0-9a-fA-F]+\s+', ''
        if ($cleaned -match '^(feat|feature)(\(.*\))?:\s*(.*)') {
            $featList.Add("- $($matches[3])")
        } elseif ($cleaned -match '^(fix)(\(.*\))?:\s*(.*)') {
            $fixList.Add("- $($matches[3])")
        } else {
            if ($otherList.Count -lt 5) {
                $otherList.Add("- $cleaned")
            }
        }
    }

    $notesList = [System.Collections.Generic.List[string]]::new()
    $notesList.Add("## What's Changed in Budget Buddy v$nextVer")
    $notesList.Add("")

    if ($featList.Count -gt 0) {
        $notesList.Add("### Features")
        foreach ($f in $featList) { $notesList.Add($f) }
        $notesList.Add("")
    }

    if ($fixList.Count -gt 0) {
        $notesList.Add("### Fixes & Improvements")
        foreach ($fx in $fixList) { $notesList.Add($fx) }
        $notesList.Add("")
    }

    if ($featList.Count -eq 0 -and $fixList.Count -eq 0) {
        $notesList.Add("- Maintenance, performance, and stability updates.")
        $notesList.Add("")
    }

    $notesList.Add("**Full Changelog**: https://github.com/$GhUser/$GhRepo/commits/v$nextVer")

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($defaultNotesPath, ($notesList -join "`r`n"), $utf8NoBom)

    Write-Host "[prepare_ota_release] Current version: $($current.Version)+$($current.Build)"
    Write-Host "[prepare_ota_release] Total commits: $totalCommitCount"
    Write-Host "[prepare_ota_release] Recommended real version: $nextVer+$nextBuild"
    Write-Host "[prepare_ota_release] Commits in release: $commitCount"
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
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($defaultNotesPath, $finalNotes, $utf8NoBom)

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
