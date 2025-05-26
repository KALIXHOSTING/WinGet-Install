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

# --- Download Winget and dependencies from GitHub ---

$wingetVersion = "v1.10.390"
$githubBase = "https://github.com/microsoft/winget-cli/releases/download/$wingetVersion"

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

foreach ($file in $filesToDownload) {
    $outputPath = Join-Path -Path $terminalPath -ChildPath $file.FileName
    if (Test-Path -Path $outputPath) {
        Write-Host "File already exists: $($file.FileName)" -ForegroundColor Yellow
        continue
    }
    try {
        Write-Host "Downloading $($file.FileName)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $file.Url -OutFile $outputPath -UseBasicParsing
        Write-Host "Download completed: $($file.FileName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download $($file.FileName)" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Pause
    }
}

# --- Extract dependencies ZIP and copy required files ---

$zipPath = Join-Path -Path $terminalPath -ChildPath "DesktopAppInstaller_Dependencies.zip"
$extractPath = Join-Path -Path $terminalPath -ChildPath "Dependencies"
if (-not (Test-Path -Path $extractPath)) {
    try {
        Write-Host "Extracting dependencies ZIP..." -ForegroundColor Cyan
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractPath)
        Write-Host "Extraction completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to extract dependencies ZIP." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Pause
    }
} else {
    Write-Host "Dependencies already extracted." -ForegroundColor Yellow
}

# Copy required .appx files from x64 subfolder
$depX64Path = Join-Path -Path $extractPath -ChildPath "x64"
$appxFiles = @(
    "Microsoft.UI.Xaml.2.8_8.2501.31001.0_x64.appx",
    "Microsoft.VCLibs.140.00.UWPDesktop_14.0.33728.0_x64.appx"
)
foreach ($appx in $appxFiles) {
    $src = Join-Path -Path $depX64Path -ChildPath $appx
    $dst = Join-Path -Path $terminalPath -ChildPath $appx
    if (-not (Test-Path -Path $dst)) {
        try {
            Copy-Item -Path $src -Destination $dst -Force
            Write-Host "Copied $appx to $terminalPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to copy $appx" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            Pause
        }
    } else {
        Write-Host "$appx already exists in $terminalPath" -ForegroundColor Yellow
    }
}

# --- Verify all files are present ---

$allNeededFiles = @(
    "Microsoft.UI.Xaml.2.8_8.2501.31001.0_x64.appx",
    "Microsoft.VCLibs.140.00.UWPDesktop_14.0.33728.0_x64.appx",
    "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle",
    "e53e159d00e04f729cc2180cffd1c02e_License1.xml"
)
$missingFiles = @()
foreach ($file in $allNeededFiles) {
    $filePath = Join-Path -Path $terminalPath -ChildPath $file
    if (-not (Test-Path -Path $filePath)) {
        $missingFiles += $file
    }
}
if ($missingFiles.Count -gt 0) {
    Write-Host "Missing files:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    Pause
}

# --- Install dependencies and Winget ---

$appx1Path = Join-Path -Path $terminalPath -ChildPath "Microsoft.UI.Xaml.2.8_8.2501.31001.0_x64.appx"
$appx2Path = Join-Path -Path $terminalPath -ChildPath "Microsoft.VCLibs.140.00.UWPDesktop_14.0.33728.0_x64.appx"
$msixwingetPath = Join-Path -Path $terminalPath -ChildPath "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
$wingetLicPath = Join-Path -Path $terminalPath -ChildPath "e53e159d00e04f729cc2180cffd1c02e_License1.xml"

try {
    Write-Host "Installing Microsoft.UI.Xaml package..." -ForegroundColor Cyan
    Add-AppxPackage -Path $appx1Path -ErrorAction Stop
    Write-Host "Microsoft.UI.Xaml package installed successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to install Microsoft.UI.Xaml package" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Pause
}

try {
    Write-Host "Installing Microsoft.VCLibs package..." -ForegroundColor Cyan
    Add-AppxPackage -Path $appx2Path -ErrorAction Stop
    Write-Host "Microsoft.VCLibs package installed successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to install Microsoft.VCLibs package" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Pause
}

# --- OS detection and Winget install logic ---
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

if ($isWin10) {
    # Windows 10: Use Add-AppxPackage for current user
    try {
        Write-Host "Detected Windows 10. Installing Winget package for current user..." -ForegroundColor Cyan
        Add-AppxPackage -Path $msixwingetPath -ErrorAction Stop
        Write-Host "Winget installed successfully (per-user)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install Winget package on Windows 10" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Try manually installing the msixbundle or updating Windows 10." -ForegroundColor Yellow
        Pause
    }
} else {
    # Windows 11/Server: Use Add-AppxProvisionedPackage for all users
    try {
        Write-Host "Provisioning Winget package for all users..." -ForegroundColor Cyan
        Add-AppxProvisionedPackage -Online -PackagePath $msixwingetPath -LicensePath $wingetLicPath -ErrorAction Stop
        Write-Host "Winget provisioned successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to provision Winget package" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Pause
    }
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
