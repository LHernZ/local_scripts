<#
.SYNOPSIS
    RustDesk Silent Installation Script with Auto-Configuration

.DESCRIPTION
    Automatically downloads, installs, and configures RustDesk with a random password.
    Designed to be run directly from GitHub for easy deployment.

.PARAMETER ConfigString
    Your RustDesk server configuration string from your web portal

.PARAMETER Password
    Optional custom password. If not provided, a random 12-character password is generated

.EXAMPLE
    # Run directly from GitHub
    iex (irm https://raw.githubusercontent.com/yourusername/yourrepo/main/install-rustdesk.ps1)

.EXAMPLE
    # Run with custom config
    $config = "your-config-string-here"
    iex "& { $(irm https://raw.githubusercontent.com/yourusername/yourrepo/main/install-rustdesk.ps1) } -ConfigString '$config'"

.NOTES
    Author: Luis
    Requires: PowerShell 5.1+ and Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigString = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Password = ""
)

$ErrorActionPreference = 'Stop'

#region Configuration
# ============================================================================
# CONFIGURATION SECTION - Edit these values or pass as parameters
# ============================================================================

# If not passed as parameter, set your config string here
if ([string]::IsNullOrEmpty($ConfigString)) {
    $ConfigString = "PASTE_YOUR_CONFIG_STRING_HERE"
}

# Temporary directory for downloads
$TempDir = "C:\Temp"

# Installation timeout settings (in seconds)
$InstallTimeout = 30
$ServiceTimeout = 30

#endregion

#region Helper Functions
# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $color = switch($Type) {
        'Info'    { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    
    $prefix = switch($Type) {
        'Info'    { '[INFO]' }
        'Success' { '[SUCCESS]' }
        'Warning' { '[WARNING]' }
        'Error'   { '[ERROR]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedProcess {
    Write-ColorOutput "Requesting administrator privileges..." -Type Warning
    
    $scriptPath = $MyInvocation.PSCommandPath
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $scriptPath = [System.IO.Path]::Combine($env:TEMP, "rustdesk-install.ps1")
        $MyInvocation.MyCommand.ScriptBlock | Out-File -FilePath $scriptPath -Encoding UTF8
    }
    
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    if (-not [string]::IsNullOrEmpty($ConfigString) -and $ConfigString -ne "PASTE_YOUR_CONFIG_STRING_HERE") {
        $arguments += " -ConfigString '$ConfigString'"
    }
    if (-not [string]::IsNullOrEmpty($Password)) {
        $arguments += " -Password '$Password'"
    }
    
    Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
    Exit
}

function Get-LatestRustDeskVersion {
    Write-ColorOutput "Fetching latest RustDesk version information..." -Type Info
    
    try {
        $releasesUrl = 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest'
        $release = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
        
        $version = $release.tag_name
        $asset = $release.assets | Where-Object { $_.name -match 'rustdesk-.+-x86_64\.exe$' } | Select-Object -First 1
        
        if ($null -eq $asset) {
            throw "Could not find x86_64 installer in latest release"
        }
        
        return @{
            Version = $version
            DownloadUrl = $asset.browser_download_url
            FileName = $asset.name
        }
    }
    catch {
        Write-ColorOutput "Failed to fetch version info from GitHub API, trying fallback method..." -Type Warning
        
        # Fallback to original method
        $page = Invoke-WebRequest -Uri 'https://github.com/rustdesk/rustdesk/releases/latest' -UseBasicParsing
        $downloadLink = ($page.Links | Where-Object { 
            $_.href -match '(.)+\/rustdesk\/rustdesk\/releases\/download\/\d+\.\d+\.\d+(.*)\/rustdesk(.)+x86_64\.exe' 
        } | Select-Object -First 1).href
        
        if ($downloadLink -match './rustdesk/rustdesk/releases/download/(?<version>.*)/(?<filename>rustdesk-(.)+x86_64\.exe)') {
            $downloadLink = $downloadLink.Replace('about:', 'https://github.com')
            return @{
                Version = $matches['version']
                DownloadUrl = $downloadLink
                FileName = $matches['filename']
            }
        }
        
        throw "Could not determine latest version"
    }
}

function Test-RustDeskInstalled {
    try {
        $installed = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" -ErrorAction SilentlyContinue
        if ($installed) {
            return @{
                Installed = $true
                Version = $installed.Version
            }
        }
    }
    catch {
        # Not installed
    }
    
    return @{
        Installed = $false
        Version = $null
    }
}

function New-RandomPassword {
    param(
        [int]$Length = 12
    )
    
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
    $password = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

#endregion

#region Main Installation Logic
# ============================================================================
# MAIN INSTALLATION LOGIC
# ============================================================================

try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  RustDesk Installation Script" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Check for administrator privileges
    if (-not (Test-Administrator)) {
        Start-ElevatedProcess
    }
    
    # Validate configuration string
    if ([string]::IsNullOrEmpty($ConfigString) -or $ConfigString -eq "PASTE_YOUR_CONFIG_STRING_HERE") {
        Write-ColorOutput "Configuration string not set!" -Type Error
        Write-ColorOutput "Please edit the script or pass -ConfigString parameter" -Type Error
        Read-Host "Press Enter to exit"
        Exit 1
    }
    
    # Generate or use provided password
    if ([string]::IsNullOrEmpty($Password)) {
        $Password = New-RandomPassword -Length 12
        Write-ColorOutput "Generated random password" -Type Info
    }
    else {
        Write-ColorOutput "Using provided password" -Type Info
    }
    
    # Check current installation
    $currentInstall = Test-RustDeskInstalled
    $latestVersion = Get-LatestRustDeskVersion
    
    Write-ColorOutput "Latest version: $($latestVersion.Version)" -Type Info
    
    if ($currentInstall.Installed) {
        Write-ColorOutput "Current version: $($currentInstall.Version)" -Type Info
        
        if ($currentInstall.Version -eq $latestVersion.Version) {
            Write-ColorOutput "RustDesk is already up to date!" -Type Success
            
            # Still configure it with the provided settings
            Write-ColorOutput "Applying configuration..." -Type Info
            $rustdeskPath = Join-Path $env:ProgramFiles "RustDesk\rustdesk.exe"
            
            if (Test-Path $rustdeskPath) {
                & $rustdeskPath --config $ConfigString
                & $rustdeskPath --password $Password
                $rustdeskId = & $rustdeskPath --get-id
                
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "  Configuration Updated" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "RustDesk ID: $rustdeskId" -ForegroundColor Yellow
                Write-Host "Password: $Password" -ForegroundColor Yellow
                Write-Host "========================================" -ForegroundColor Green
                Write-Host ""
            }
            
            Exit 0
        }
        else {
            Write-ColorOutput "Updating to version $($latestVersion.Version)..." -Type Info
        }
    }
    else {
        Write-ColorOutput "RustDesk not installed. Installing version $($latestVersion.Version)..." -Type Info
    }
    
    # Create temp directory
    if (-not (Test-Path $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        Write-ColorOutput "Created temporary directory: $TempDir" -Type Info
    }
    
    # Download installer
    $installerPath = Join-Path $TempDir $latestVersion.FileName
    Write-ColorOutput "Downloading RustDesk installer..." -Type Info
    Write-ColorOutput "URL: $($latestVersion.DownloadUrl)" -Type Info
    
    Invoke-WebRequest -Uri $latestVersion.DownloadUrl -OutFile $installerPath -UseBasicParsing
    Write-ColorOutput "Download completed" -Type Success
    
    # Install RustDesk
    Write-ColorOutput "Installing RustDesk (this may take a moment)..." -Type Info
    Start-Process -FilePath $installerPath -ArgumentList "--silent-install" -Wait -NoNewWindow
    Start-Sleep -Seconds 5
    
    Write-ColorOutput "Installation completed" -Type Success
    
    # Verify and start service
    $serviceName = 'RustDesk'
    $rustdeskPath = Join-Path $env:ProgramFiles "RustDesk\rustdesk.exe"
    
    Write-ColorOutput "Configuring RustDesk service..." -Type Info
    
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    
    if ($null -eq $service) {
        Write-ColorOutput "Installing RustDesk service..." -Type Info
        Start-Process -FilePath $rustdeskPath -ArgumentList "--install-service" -Wait -NoNewWindow
        Start-Sleep -Seconds 5
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    }
    
    if ($null -eq $service) {
        throw "RustDesk service not found after installation"
    }
    
    # Start service if not running
    $timeout = 0
    while ($service.Status -ne 'Running' -and $timeout -lt $ServiceTimeout) {
        Write-ColorOutput "Starting RustDesk service..." -Type Info
        Start-Service -Name $serviceName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $service.Refresh()
        $timeout += 2
    }
    
    if ($service.Status -ne 'Running') {
        Write-ColorOutput "Warning: Service did not start within timeout period" -Type Warning
    }
    else {
        Write-ColorOutput "RustDesk service is running" -Type Success
    }
    
    # Configure RustDesk
    Write-ColorOutput "Applying configuration and password..." -Type Info
    
    & $rustdeskPath --config $ConfigString
    Start-Sleep -Seconds 2
    
    & $rustdeskPath --password $Password
    Start-Sleep -Seconds 2
    
    # Get RustDesk ID
    $rustdeskId = & $rustdeskPath --get-id
    
    # Clean up
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "Cleaned up installation files" -Type Info
    }
    
    # Display results
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Completed Successfully" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "RustDesk ID: $rustdeskId" -ForegroundColor Yellow
    Write-Host "Password: $Password" -ForegroundColor Yellow
    Write-Host "Version: $($latestVersion.Version)" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-ColorOutput "Save these credentials in a secure location!" -Type Warning
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-ColorOutput "Installation failed: $($_.Exception.Message)" -Type Error
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" -Type Error
    Write-Host ""
    Read-Host "Press Enter to exit"
    Exit 1
}

#endregion
