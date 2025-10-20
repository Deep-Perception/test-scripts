<#
.SYNOPSIS
    Installs Podman on Windows with WSL2 backend
.DESCRIPTION
    This script enables WSL features, configures WSL for Podman, downloads and installs Podman silently
#>

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Yellow
    
    # Relaunch the script with elevated privileges
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
    exit
}

Write-Host "=== Podman Installation Script ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check and enable WSL features
Write-Host "Step 1: Checking WSL features..." -ForegroundColor Yellow

function Get-WindowsFeatureState {
    param([string]$FeatureName)
    
    $feature = dism.exe /online /get-featureinfo /featurename:$FeatureName
    $state = $feature | Select-String "State : (\w+)" | ForEach-Object { $_.Matches.Groups[1].Value }
    return $state
}

$wslState = Get-WindowsFeatureState -FeatureName "Microsoft-Windows-Subsystem-Linux"
$vmState = Get-WindowsFeatureState -FeatureName "VirtualMachinePlatform"

$needsReboot = $false

if ($wslState -ne "Enabled") {
    Write-Host "Enabling Windows Subsystem for Linux..." -ForegroundColor Green
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    $needsReboot = $true
}
else {
    Write-Host "[OK] Windows Subsystem for Linux is already enabled" -ForegroundColor Green
}

if ($vmState -ne "Enabled") {
    Write-Host "Enabling Virtual Machine Platform..." -ForegroundColor Green
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    $needsReboot = $true
}
else {
    Write-Host "[OK] Virtual Machine Platform is already enabled" -ForegroundColor Green
}

if ($needsReboot) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "SYSTEM REBOOT REQUIRED" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "WSL features have been enabled." -ForegroundColor Yellow
    Write-Host "Please restart your computer and run this script again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

Write-Host ""

# Step 2: Configure WSL for Podman
Write-Host "Step 2: Configuring WSL..." -ForegroundColor Yellow

# Set WSL 2 as default
Write-Host "Setting WSL 2 as default version..." -ForegroundColor Green
wsl --set-default-version 2

# Check if any WSL distro is installed
$distros = wsl -l -q 2>$null
if (-not $distros -or $distros.Count -eq 0) {
    Write-Host "No WSL distribution found. Installing Ubuntu..." -ForegroundColor Green
    wsl --install -d Ubuntu --no-launch
    Write-Host "[OK] Ubuntu installed" -ForegroundColor Green
}
else {
    Write-Host "[OK] WSL distribution(s) already installed" -ForegroundColor Green
}

Write-Host ""

# Step 3: Download and install Podman
Write-Host "Step 3: Downloading and installing Podman..." -ForegroundColor Yellow

# Get latest Podman release
Write-Host "Fetching latest Podman release information..." -ForegroundColor Green
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/containers/podman/releases/latest"
$version = $releases.tag_name -replace 'v', ''
$installerUrl = $releases.assets | Where-Object { $_.name -like "podman-*-setup.exe" } | Select-Object -ExpandProperty browser_download_url

if (-not $installerUrl) {
    Write-Host "Error: Could not find Podman installer URL" -ForegroundColor Red
    exit 1
}

Write-Host "Latest version: $version" -ForegroundColor Green
Write-Host "Downloading from: $installerUrl" -ForegroundColor Green

$installerPath = "$env:TEMP\podman-setup.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

Write-Host "Installing Podman silently..." -ForegroundColor Green
Start-Process -FilePath $installerPath -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow

Remove-Item $installerPath -Force
Write-Host "[OK] Podman installed successfully" -ForegroundColor Green

Write-Host ""

# Step 4: Configure environment
Write-Host "Step 4: Configuring Podman environment..." -ForegroundColor Yellow

# Update WSL to latest version
Write-Host "Updating WSL to latest version..." -ForegroundColor Green
wsl --update
Write-Host "[OK] WSL updated" -ForegroundColor Green

# Reset Podman machine
Write-Host "Resetting Podman machine..." -ForegroundColor Green
& "C:\Program Files\RedHat\Podman\podman.exe" machine reset -f 2>$null

# Initialize Podman machine
Write-Host "Initializing Podman machine..." -ForegroundColor Green
& "C:\Program Files\RedHat\Podman\podman.exe" machine init

Write-Host "Starting Podman machine..." -ForegroundColor Green
& "C:\Program Files\RedHat\Podman\podman.exe" machine start

Write-Host "Configuring Podman machine to start on boot..." -ForegroundColor Green
$action = New-ScheduledTaskAction -Execute "C:\Program Files\RedHat\Podman\podman.exe" -Argument "machine start"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "Podman Machine Startup" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "[OK] Podman machine configured to start automatically on boot" -ForegroundColor Green

Write-Host ""
Write-Host "=== Verifying Installation ===" -ForegroundColor Cyan
Write-Host ""

# Verify Podman installation
Write-Host "Running verification test..." -ForegroundColor Green
Write-Host "Executing: podman run quay.io/podman/hello" -ForegroundColor Gray
Write-Host ""

$output = & "C:\Program Files\RedHat\Podman\podman.exe" run quay.io/podman/hello 2>&1 | Out-String
Write-Host $output

if ($output -match "Hello Podman World") {
    Write-Host ""
    Write-Host "[SUCCESS] Verification successful! Podman is working correctly." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "[FAILED] Verification test failed. Podman may not be configured correctly." -ForegroundColor Red
    Write-Host "Please try running manually: podman run quay.io/podman/hello" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Podman has been installed successfully!" -ForegroundColor Green
Write-Host "You may need to restart your terminal to use podman commands." -ForegroundColor Yellow
Write-Host ""
Write-Host "Quick start commands:" -ForegroundColor Cyan
Write-Host "  podman --version" -ForegroundColor Gray
Write-Host "  podman machine list" -ForegroundColor Gray
Write-Host "  podman run quay.io/podman/hello" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

