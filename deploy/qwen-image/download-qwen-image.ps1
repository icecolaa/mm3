[CmdletBinding()]
param(
    [string]$TargetRoot = "D:\LocalAI\image",

    [ValidateSet("recommended", "turbo", "classic", "edit2509", "all")]
    [string]$Bundle = "recommended",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) {
        return ("{0:N2} GiB" -f ($Bytes / 1GB))
    }
    if ($Bytes -ge 1MB) {
        return ("{0:N1} MiB" -f ($Bytes / 1MB))
    }
    return ("{0} B" -f $Bytes)
}

function Get-SelectedFiles {
    param($Manifest, [string]$BundleName)

    $allFiles = @($Manifest.files)
    $selected = @()
    foreach ($file in $allFiles) {
        if ($BundleName -eq "all") {
            $selected += $file
            continue
        }
        if (@($file.bundles) -contains $BundleName) {
            $selected += $file
        }
    }

    $seen = @{}
    $unique = @()
    foreach ($file in $selected) {
        $key = [string]$file.target
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $unique += $file
        }
    }
    return $unique
}

try {
    $manifestPath = Join-Path $PSScriptRoot "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        Write-Fail "manifest.json not found next to this script: $manifestPath"
        exit 1
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $plan = @(Get-SelectedFiles -Manifest $manifest -BundleName $Bundle)

    if ($plan.Count -eq 0) {
        Write-Fail "Bundle '$Bundle' selected zero files. Check manifest.json."
        exit 1
    }

    $totalBytes = [long]0
    foreach ($file in $plan) {
        if (-not $file.url -or -not $file.target -or -not $file.size_bytes) {
            throw "Manifest entry '$($file.id)' is missing url/target/size_bytes."
        }
        $totalBytes += [long]$file.size_bytes
    }

    Write-Host ""
    Write-Host "Qwen image deployment package - download only" -ForegroundColor White
    Write-Host "Bundle     : $Bundle"
    Write-Host "TargetRoot : $TargetRoot"
    Write-Host "Files      : $($plan.Count)"
    Write-Host "Download   : $(Format-Bytes $totalBytes) ($totalBytes bytes)"
    Write-Host ""

    if ($DryRun) {
        Write-Host "=== DRY RUN: no network requests, no directories or files will be created ===" -ForegroundColor Magenta
        foreach ($file in $plan) {
            $targetPath = Join-Path $TargetRoot $file.target
            Write-Host ("- {0}" -f $file.filename) -ForegroundColor White
            Write-Host ("  role   : {0}" -f $file.role)
            Write-Host ("  size   : {0} ({1} bytes)" -f (Format-Bytes ([long]$file.size_bytes)), $file.size_bytes)
            Write-Host ("  target : {0}" -f $targetPath)
            Write-Host ("  source : {0}" -f $file.repository)
            Write-Host ("  url    : {0}" -f $file.url)
        }
        Write-Host ""
        Write-Host "DRY RUN complete. Nothing was downloaded; no network request was made." -ForegroundColor Magenta
        exit 0
    }

    $curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -eq $curlCommand) {
        Write-Fail "curl.exe was not found. Windows 10/11 normally ships it in C:\Windows\System32."
        exit 1
    }

    if (-not (Test-Path -LiteralPath $TargetRoot)) {
        New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
    }

    $downloaded = 0
    $skipped = 0
    $failed = 0

    foreach ($file in $plan) {
        $targetPath = Join-Path $TargetRoot $file.target
        $targetDir = Split-Path -Parent $targetPath
        if (-not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }

        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $existingSize = (Get-Item -LiteralPath $targetPath).Length
            if ($existingSize -eq [long]$file.size_bytes) {
                Write-Ok "SKIP (already exists, size matches): $targetPath"
                $skipped++
            }
            else {
                Write-WarnLine "SKIP (already exists, size differs: $existingSize vs expected $($file.size_bytes)): $targetPath"
                Write-WarnLine "Delete the file yourself if you want to download it again."
                $skipped++
            }
            continue
        }

        $partPath = $targetPath + ".part"

        if (Test-Path -LiteralPath $partPath -PathType Leaf) {
            $partSize = (Get-Item -LiteralPath $partPath).Length
            if ($partSize -eq [long]$file.size_bytes) {
                Move-Item -LiteralPath $partPath -Destination $targetPath -Force
                Write-Ok "Recovered complete partial download: $targetPath"
                $downloaded++
                continue
            }
            Write-Info "Found partial file, will resume: $partPath ($(Format-Bytes $partSize))"
        }

        $urls = @($file.url)
        if ($file.alt_urls) {
            $urls += @($file.alt_urls)
        }

        $ok = $false
        foreach ($url in $urls) {
            Write-Info "Downloading $($file.filename) from $url"
            $curlArgs = @(
                "-L",
                "--fail",
                "--retry", "3",
                "--retry-delay", "3",
                "--connect-timeout", "20",
                "--progress-bar",
                "-C", "-",
                "--output", $partPath,
                $url
            )
            & curl.exe @curlArgs
            $curlExit = $LASTEXITCODE
            if ($curlExit -eq 0) {
                $ok = $true
                break
            }
            Write-WarnLine "curl.exe exited with code $curlExit for $url"
        }

        if (-not $ok) {
            Write-Fail "Download failed for $($file.filename). Partial file kept for resume: $partPath"
            $failed++
            continue
        }

        if (-not (Test-Path -LiteralPath $partPath -PathType Leaf)) {
            Write-Fail "curl.exe reported success but the output file is missing: $partPath"
            $failed++
            continue
        }

        $actualSize = (Get-Item -LiteralPath $partPath).Length
        if ($actualSize -ne [long]$file.size_bytes) {
            Write-Fail "Size mismatch for $($file.filename): got $actualSize, expected $($file.size_bytes)."
            Write-Fail "Partial file kept for inspection/resume: $partPath"
            $failed++
            continue
        }

        Move-Item -LiteralPath $partPath -Destination $targetPath -Force
        Write-Ok "Downloaded: $targetPath"
        $downloaded++
    }

    Write-Host ""
    Write-Host "Summary" -ForegroundColor White
    Write-Host "  Downloaded : $downloaded"
    Write-Host "  Skipped    : $skipped"
    Write-Host "  Failed     : $failed"

    if ($failed -gt 0) {
        Write-Fail "One or more downloads failed. Re-run the same command to resume partial files."
        exit 1
    }

    Write-Ok "All selected files are present."
    exit 0
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
