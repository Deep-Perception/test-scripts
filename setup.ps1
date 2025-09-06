param(
    [switch]$SkipHailo,
    [Parameter(Mandatory=$false)]
    [string]$InstallLocation = "C:\Hailo-Test"
)

# Display parameters for debugging
Write-Host "Parameters received:" -ForegroundColor Cyan
Write-Host "  SkipHailo: $SkipHailo" -ForegroundColor Yellow
Write-Host "  InstallLocation: $InstallLocation" -ForegroundColor Yellow

# URLs for downloads
$hailoInstallerUrl = "https://storage.googleapis.com/deepperception_public/hailo/h10/hailort_5.0.1_windows_installer.msi"
$modelFileUrl = "https://storage.googleapis.com/deepperception_public/hailo/h10/h10_yolox_l_leaky.hef"

# Function to download file with progress
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        Write-Host "Downloading $(Split-Path $OutputPath -Leaf)..." -ForegroundColor Green
        
        # Use WebClient for progress indication
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        
        Write-Host "Download completed: $OutputPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to download from $Url : $($_.Exception.Message)"
        return $false
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

# Function to install MSI silently
function Install-MSI {
    param(
        [string]$MsiPath
    )
    
    try {
        Write-Host "Installing $(Split-Path $MsiPath -Leaf) silently..." -ForegroundColor Green
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$MsiPath`"", "/quiet", "/norestart" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Installation completed successfully." -ForegroundColor Green
            return $true
        } else {
            Write-Error "Installation failed with exit code: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install MSI: $($_.Exception.Message)"
        return $false
    }
}

# Main script execution
Write-Host "=== Hailo Installation Script ===" -ForegroundColor Cyan

# Create install directory if it doesn't exist
if (!(Test-Path $InstallLocation)) {
    New-Item -ItemType Directory -Path $InstallLocation -Force | Out-Null
    Write-Host "Created directory: $InstallLocation" -ForegroundColor Yellow
}

$success = $true

if (-not $SkipHailo) {
    Write-Host "`nStep 1: Downloading Hailo installer..." -ForegroundColor Cyan
    
    # Download the installer
    $installerPath = Join-Path $InstallLocation "hailort_5.0.1_windows_installer.msi"
    if (Download-File -Url $hailoInstallerUrl -OutputPath $installerPath) {
        
        Write-Host "`nStep 2: Installing Hailo software..." -ForegroundColor Cyan
        
        # Install the MSI
        if (Install-MSI -MsiPath $installerPath) {
            Write-Host "Hailo installation completed successfully." -ForegroundColor Green
        } else {
            $success = $false
        }
        
        # Clean up installer file (optional)
        Write-Host "Cleaning up installer file..." -ForegroundColor Yellow
        Remove-Item $installerPath -ErrorAction SilentlyContinue
    } else {
        $success = $false
    }
} else {
    Write-Host "Skipping Hailo installation (--skip-hailo specified)" -ForegroundColor Yellow
}

# Always download the model file (Step 3)
Write-Host "`nStep 3: Downloading model file..." -ForegroundColor Cyan

$modelPath = Join-Path $InstallLocation "h10_yolox_l_leaky.hef"
if (Download-File -Url $modelFileUrl -OutputPath $modelPath) {
    Write-Host "Model file downloaded successfully to: $modelPath" -ForegroundColor Green
} else {
    $success = $false
}

# Step 4: Create run.ps1 script
Write-Host "`nStep 4: Creating run.ps1 script..." -ForegroundColor Cyan
Write-Host "Target location: $InstallLocation" -ForegroundColor Yellow

$runScriptContent = @'
param(
    [Parameter(Mandatory=$false)]
    [int]$t
)

# Build the hailortcli command
$command = "hailortcli run2 --measure-power --measure-temp"

# Add -t parameter if specified
if ($PSBoundParameters.ContainsKey('t')) {
    $command += " -t $t"
}

# Add the model file and batch size
$command += " set-net .\h10_yolox_l_leaky.hef --batch-size 8"

Write-Host "Executing: $command" -ForegroundColor Green
Invoke-Expression $command
'@

$runScriptPath = Join-Path $InstallLocation "run.ps1"
Write-Host "Creating script at: $runScriptPath" -ForegroundColor Yellow

try {
    # Ensure the directory exists
    if (!(Test-Path $InstallLocation)) {
        New-Item -ItemType Directory -Path $InstallLocation -Force | Out-Null
        Write-Host "Created missing directory: $InstallLocation" -ForegroundColor Yellow
    }
    
    Set-Content -Path $runScriptPath -Value $runScriptContent -Encoding UTF8
    
    # Verify the file was created
    if (Test-Path $runScriptPath) {
        Write-Host "Successfully created run.ps1 script at: $runScriptPath" -ForegroundColor Green
    } else {
        Write-Error "File was not created successfully"
        $success = $false
    }
} catch {
    Write-Error "Failed to create run.ps1 script: $($_.Exception.Message)"
    $success = $false
}

# Final status
Write-Host "`n=== Script Execution Complete ===" -ForegroundColor Cyan
if ($success) {
    Write-Host "All operations completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Some operations failed. Please check the error messages above." -ForegroundColor Red
    exit 1
}

Write-Host "`nFiles location: $InstallLocation" -ForegroundColor Yellow
Write-Host "`nTo run the model, navigate to $InstallLocation and execute:" -ForegroundColor Cyan
Write-Host "  .\run.ps1          # Run with default settings" -ForegroundColor White
Write-Host "  .\run.ps1 -t 100   # Run with -t parameter" -ForegroundColor White