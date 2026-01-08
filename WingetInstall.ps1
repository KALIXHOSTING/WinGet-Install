<#
.SYNOPSIS
    Automated installation script for Windows Terminal dependencies, Winget, and Chocolatey
.DESCRIPTION
    This script downloads and installs Windows Terminal dependencies, Winget, and Chocolatey
    with proper verification at each step.
.NOTES
    File Name      : Install-WingetDependencies.ps1
    Prerequisite   : PowerShell 5.1 or later (run as Administrator)
#>

#Requires -RunAsAdministrator

Clear-Host
Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

# Create Windows Terminal directory if it doesn't exist
$terminalPath = "C:\Windows\Windows Terminal"
if (-not (Test-Path -Path $terminalPath)) {
    try {
        New-Item -Path $terminalPath -ItemType Directory -Force | Out-Null
        Write-Host "Created directory: $terminalPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create directory: $terminalPath" -ForegroundColor Red
        Pause
    }
}

# --- Download and install Visual C++ Redistributables ---

$vcRedists = @(
    @{
        Url = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        FileName = "vc_redist.x86.exe"
    },
    @{
        Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        FileName = "vc_redist.x64.exe"
    }
)

foreach ($vc in $vcRedists) {
    $vcPath = Join-Path -Path $terminalPath -ChildPath $vc.FileName
    if (-not (Test-Path -Path $vcPath)) {
        try {
            Write-Host "Downloading $($vc.FileName)..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $vc.Url -OutFile $vcPath -UseBasicParsing
            Write-Host "Download completed: $($vc.FileName)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to download $($vc.FileName)" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            Pause
        }
    } else {
        Write-Host "File already exists: $($vc.FileName)" -ForegroundColor Yellow
    }

    # Install the redistributable silently
    try {
        Write-Host "Installing $($vc.FileName)..." -ForegroundColor Cyan
        $process = Start-Process -FilePath $vcPath -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "Installation failed for $($vc.FileName) with exit code $($process.ExitCode)" -ForegroundColor Red
            Pause
        } else {
            Write-Host "$($vc.FileName) installed successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Failed to install $($vc.FileName)" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Pause
    }
}

# --- OS detection logic (Moved up for use in loop) ---
$osVersion = (Get-CimInstance Win32_OperatingSystem).Version
$isWin10 = $false
if ($osVersion.StartsWith("10.0")) {
    $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($osCaption -like "*Windows 10*") {
        $isWin10 = $true
    }
}

# Check Windows 10 build number for minimum compatibility (1809/17763 or later)
$buildNumber = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
if ($isWin10 -and $buildNumber -lt 17763) {
    Write-Host "Your Windows 10 build ($buildNumber) is too old for Winget. Please update to at least 1809 (build 17763) or later." -ForegroundColor Red
    Pause
}

# --- Download and Install Winget (with Fallback) ---

$wingetVersions = @("v1.12.440", "v1.10.390")
$installSuccess = $false

foreach ($wingetVersion in $wingetVersions) {
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Attempting to install Winget version: $wingetVersion" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

    try {
        $githubBase = "https://github.com/microsoft/winget-cli/releases/download/$wingetVersion"
        
        # Use a version-specific subdirectory to avoid file conflicts
        $versionDir = Join-Path -Path $terminalPath -ChildPath $wingetVersion
        if (-not (Test-Path -Path $versionDir)) {
            New-Item -Path $versionDir -ItemType Directory -Force | Out-Null
        }

        $filesToDownload = @(
            @{
                Url = "$githubBase/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
                FileName = "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            },
            @{
                Url = "$githubBase/e53e159d00e04f729cc2180cffd1c02e_License1.xml"
                FileName = "e53e159d00e04f729cc2180cffd1c02e_License1.xml"
            },
            @{
                Url = "$githubBase/DesktopAppInstaller_Dependencies.zip"
                FileName = "DesktopAppInstaller_Dependencies.zip"
            }
        )

        # 1. Download Files
        foreach ($file in $filesToDownload) {
            $outputPath = Join-Path -Path $versionDir -ChildPath $file.FileName
            if (Test-Path -Path $outputPath) {
                Write-Host "File already exists: $($file.FileName)" -ForegroundColor Yellow
            } else {
                Write-Host "Downloading $($file.FileName)..." -ForegroundColor Cyan
                Invoke-WebRequest -Uri $file.Url -OutFile $outputPath -UseBasicParsing
                Write-Host "Download completed: $($file.FileName)" -ForegroundColor Green
            }
        }

        # 2. Extract Dependencies
        $zipPath = Join-Path -Path $versionDir -ChildPath "DesktopAppInstaller_Dependencies.zip"
        $extractPath = Join-Path -Path $versionDir -ChildPath "Dependencies"
        
        if (-not (Test-Path -Path $extractPath)) {
            Write-Host "Extracting dependencies ZIP..." -ForegroundColor Cyan
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractPath)
            Write-Host "Extraction completed." -ForegroundColor Green
        } else {
            Write-Host "Dependencies already extracted." -ForegroundColor Yellow
        }

        # 3. Copy .appx files (Optional step, but kept for structure consistency or direct install from extracted location)
        # We can actually install directly from the extracted folder to keep it clean
        $depX64Path = Join-Path -Path $extractPath -ChildPath "x64"
        $appxFiles = Get-ChildItem -Path $depX64Path -Filter "*.appx"

        if ($appxFiles.Count -eq 0) {
            throw "No .appx files found in $depX64Path"
        }

        # 4. Install Dependencies
        # Install VCLibs first
        $vclibs = $appxFiles | Where-Object { $_.Name -like "*VCLibs*" }
        foreach ($pkg in $vclibs) {
            Write-Host "Installing $($pkg.Name)..." -ForegroundColor Cyan
            Add-AppxPackage -Path $pkg.FullName -ErrorAction Stop
            Write-Host "$($pkg.Name) installed successfully" -ForegroundColor Green
        }

        # Install other dependencies
        $others = $appxFiles | Where-Object { $_.Name -notlike "*VCLibs*" }
        foreach ($pkg in $others) {
            Write-Host "Installing $($pkg.Name)..." -ForegroundColor Cyan
            Add-AppxPackage -Path $pkg.FullName -ErrorAction Stop
            Write-Host "$($pkg.Name) installed successfully" -ForegroundColor Green
        }

        # 5. Install Main Winget Package
        $msixwingetPath = Join-Path -Path $versionDir -ChildPath "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $wingetLicPath = Join-Path -Path $versionDir -ChildPath "e53e159d00e04f729cc2180cffd1c02e_License1.xml"

        if ($isWin10) {
            # Windows 10: Use Add-AppxPackage for current user
            Write-Host "Detected Windows 10. Installing Winget package for current user..." -ForegroundColor Cyan
            Add-AppxPackage -Path $msixwingetPath -ErrorAction Stop
            Write-Host "Winget installed successfully (per-user)" -ForegroundColor Green
        } else {
            # Windows 11/Server: Use Add-AppxProvisionedPackage for all users
            Write-Host "Provisioning Winget package for all users..." -ForegroundColor Cyan
            Add-AppxProvisionedPackage -Online -PackagePath $msixwingetPath -LicensePath $wingetLicPath -ErrorAction Stop
            Write-Host "Winget provisioned successfully" -ForegroundColor Green
        }

        # If we got here, everything succeeded
        $installSuccess = $true
        break
    }
    catch {
        Write-Host "Failed to install Winget version $wingetVersion" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Attempting fallback to next version (if available)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

if (-not $installSuccess) {
    Write-Host "All Winget installation attempts failed." -ForegroundColor Red
    Write-Host "Proceeding to Chocolatey installation..." -ForegroundColor Yellow
    # We don't pause here, just let it fall through to Chocolatey check
}

# Install Chocolatey
try {
    if (-not (Test-Path "$env:ProgramData\chocolatey\choco.exe")) {
        Write-Host "Installing Chocolatey package manager..." -ForegroundColor Cyan
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Write-Host "Chocolatey installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Chocolatey is already installed" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Failed to install Chocolatey" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Pause
}

# Verify Winget installation and fall back to Chocolatey if needed
$wingetInstalled = $false
try {
    Write-Host "Verifying Winget installation..." -ForegroundColor Cyan
    $wingetCheck = Get-Command winget -ErrorAction Stop
    Write-Host "Winget is installed successfully!" -ForegroundColor Green
    $wingetInstalled = $true

    # Run winget upgrade if Winget is available
    try {
        Write-Host "Running winget upgrade --all..." -ForegroundColor Cyan
        winget upgrade --all
        Write-Host "Winget upgrade completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Winget upgrade failed" -ForegroundColor Yellow
        Write-Host "Error: $_" -ForegroundColor Yellow
        Pause
    }
}
catch {
    Write-Host "Winget is not installed correctly" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Attempting to install Winget via Chocolatey..." -ForegroundColor Yellow
    try {
        choco install winget -y
        # Try again to verify
        $wingetCheck = Get-Command winget -ErrorAction Stop
        Write-Host "Winget installed successfully via Chocolatey!" -ForegroundColor Green
        $wingetInstalled = $true
    }
    catch {
        Write-Host "Failed to install Winget via Chocolatey." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Pause
    }
}

Write-Host "All installations completed (with or without errors). Please review any messages above." -ForegroundColor Green
Pause
