#Requires -RunAsAdministrator

# --- Display Banner ---
Write-Host @"
__        ___                  _     ___           _        _ _           
\ \      / (_)_ __   __ _  ___| |_  |_ _|_ __  ___| |_ __ _| | | ___ _ __ 
 \ \ /\ / /| | '_ \ / _` |/ _ \ __|  | || '_ \/ __| __/ _` | | |/ _ \ '__|
  \ V  V / | | | | | (_| |  __/ |_   | || | | \__ \ || (_| | | |  __/ |   
   \_/\_/  |_|_| |_|\__, |\___|\__| |___|_| |_|___/\__\__,_|_|_|\___|_|   
                    |___/           
					
 --- Made by NOXHosting ---
"@ -ForegroundColor Cyan
Write-Host "" # Add a blank line for spacing


# --- Configuration ---
# Stop script on any error within the try block for the primary method.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"


# --- Primary Method: Install Latest Version from GitHub ---
try {
    Write-Host "--- Attempting to install/update WinGet from GitHub (Primary Method) ---" -ForegroundColor Green

    $githubRepo = "microsoft/winget-cli"
    $tempDir = Join-Path -Path $env:TEMP -ChildPath "winget-install-latest"

    # 1. Fetch the latest STABLE release from GitHub (ignores previews)
    Write-Host "Fetching the latest stable release information..."
    $releasesUrl = "https://api.github.com/repos/$githubRepo/releases"
    $releases = Invoke-RestMethod -Uri $releasesUrl
    $latestStableRelease = $releases | Where-Object { -not $_.prerelease } | Sort-Object -Property created_at -Descending | Select-Object -First 1

    if (-not $latestStableRelease) {
        throw "No stable releases were found for the '$githubRepo' repository."
    }
    $latestVersion = $latestStableRelease.tag_name
    Write-Host "Found latest stable version: $latestVersion"

    # 2. Prepare for Download
    if (Test-Path -Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory | Out-Null

    $msixBundleAsset = $latestStableRelease.assets | Where-Object { $_.name -like "*.msixbundle" }
    $licenseAsset = $latestStableRelease.assets | Where-Object { $_.name -like "*License1.xml" }
    $dependenciesAsset = $latestStableRelease.assets | Where-Object { $_.name -like "*Dependencies.zip" }

    if (-not ($msixBundleAsset -and $licenseAsset -and $dependenciesAsset)) {
        throw "Could not find all required installation assets in the release '$latestVersion'."
    }

    # 3. Download All Required Files
    Write-Host "Downloading required files..."
    $msixBundlePath = Join-Path -Path $tempDir -ChildPath $msixBundleAsset.name
    $licensePath = Join-Path -Path $tempDir -ChildPath $licenseAsset.name
    $dependenciesPath = Join-Path -Path $tempDir -ChildPath $dependenciesAsset.name

    Invoke-WebRequest -Uri $msixBundleAsset.browser_download_url -OutFile $msixBundlePath
    Invoke-WebRequest -Uri $licenseAsset.browser_download_url -OutFile $licensePath
    Invoke-WebRequest -Uri $dependenciesAsset.browser_download_url -OutFile $dependenciesPath

    # 4. Install Dependencies
    Write-Host "Installing App Installer dependencies..."
    Expand-Archive -Path $dependenciesPath -DestinationPath $tempDir -Force
    Get-ChildItem -Path $tempDir -Filter "*.appx" | ForEach-Object {
        Add-AppxPackage -Path $_.FullName
    }

    # 5. Install the WinGet CLI for all users
    Write-Host "Installing WinGet CLI..."
    Add-AppxProvisionedPackage -Online -PackagePath $msixBundlePath -LicensePath $licensePath

    Write-Host "--- WinGet CLI ($latestVersion) installed successfully from GitHub. ---" -ForegroundColor Green

    # 6. Cleanup
    Write-Host "Cleaning up temporary installation files..."
    Remove-Item -Path $tempDir -Recurse -Force
}
catch {
    # --- Fallback Method: Install from Chocolatey ---
    Write-Warning "Primary (GitHub) installation failed. Error: $($_.Exception.Message)"
    Write-Host "--- Attempting to install prerequisites and WinGet from Chocolatey (Fallback Method) ---" -ForegroundColor Yellow

    $ErrorActionPreference = "Continue" # Relax error handling for the fallback

    # 1. Check/Install Chocolatey
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not found. Installing Chocolatey..."
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { throw "Chocolatey installation failed." }
            Write-Host "Chocolatey installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install Chocolatey. Cannot proceed. Error: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Host "Chocolatey is already installed."
    }

    # 2. Install VC++ Redistributables via Chocolatey
    Write-Host "Installing Visual C++ Redistributables..."
    choco install vcredist14 -y --force
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Visual C++ Redistributables installed successfully." -ForegroundColor Green
    } else {
        Write-Warning "Could not install Visual C++ Redistributables."
    }

    # 3. Install WinGet via Chocolatey
    Write-Host "Installing WinGet using Chocolatey..."
    choco install winget -y --force

    # 4. Verify Final Installation
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "--- WinGet installed successfully using Chocolatey. ---" -ForegroundColor Green
    } else {
        Write-Error "Failed to install WinGet using Chocolatey. Both methods have failed."
        exit 1
    }
}

Write-Host "Script finished."
