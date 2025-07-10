# Install-WingetDependencies.ps1

## Overview

**Install-WingetDependencies.ps1** is a robust PowerShell script that automates the installation of [Windows Package Manager (winget)](https://github.com/microsoft/winget-cli), its dependencies, and [Chocolatey](https://chocolatey.org/) on Windows systems.  
It is designed to work seamlessly on Windows 10, Windows 11, Windows Server 2022, and Windows Server 2025.

The script ensures all required dependencies are present, handles OS-specific installation logic, and provides clear feedback and troubleshooting pauses if any step fails.

---

## Features

- **Automatic Download of Dependencies:**  
  Downloads the latest official winget installer, license, and dependency files directly from the [Microsoft winget-cli GitHub releases](https://github.com/microsoft/winget-cli/releases).

- **Dependency Extraction:**  
  Extracts the required `.appx` files from the dependencies ZIP and prepares them for installation.

- **Visual C++ Redistributables:**  
  Downloads and installs both x86 and x64 Visual C++ Redistributable packages.

- **OS Detection and Smart Installation:**  
  Detects your Windows version and build, and uses the correct method to install winget:
  - **Windows 10:** Installs winget for the current user.
  - **Windows 11/Server:** Provisions winget for all users.

- **Chocolatey Installation:**  
  Installs Chocolatey if it is not already present.

- **Winget Verification and Fallback:**  
  Verifies that winget is available after installation. If not, attempts to install winget via Chocolatey as a fallback.

- **Error Handling and Troubleshooting:**  
  The script pauses on errors, allowing you to review and troubleshoot issues before proceeding.

---

## Quick Start

### **Recommended: One-Line Install**

Open an **elevated PowerShell window** (Run as Administrator) and run:

```powershell
irm "https://scripts.noxhosting.io/winget22/" | iex
