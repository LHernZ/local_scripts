# RustDesk Silent Installer

<div align="center">

![RustDesk](https://img.shields.io/badge/RustDesk-Remote%20Desktop-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A PowerShell script for automated installation and configuration of RustDesk with custom server settings.

[Features](#features) • [Quick Start](#quick-start) • [Usage](#usage) • [Configuration](#configuration) • [Troubleshooting](#troubleshooting)

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Method 1: One-Line Installation](#method-1-one-line-installation)
  - [Method 2: With Parameters](#method-2-with-parameters)
  - [Method 3: Download and Run Locally](#method-3-download-and-run-locally)
- [Configuration](#configuration)
- [Parameters](#parameters)
- [What the Script Does](#what-the-script-does)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

This PowerShell script automates the installation, configuration, and deployment of RustDesk remote desktop software on Windows systems. It's designed for IT administrators and users who need to deploy RustDesk with custom server configurations across multiple machines.

## ✨ Features

- ✅ **Automatic Version Detection** - Fetches and installs the latest RustDesk version from GitHub
- ✅ **Silent Installation** - No user interaction required
- ✅ **Auto-Configuration** - Applies your custom RustDesk server settings
- ✅ **Random Password Generation** - Creates secure 12-character passwords automatically
- ✅ **Update Detection** - Checks if RustDesk is already installed and up-to-date
- ✅ **Service Management** - Ensures RustDesk service is installed and running
- ✅ **Error Handling** - Comprehensive error checking and reporting
- ✅ **Colored Output** - Easy-to-read status messages
- ✅ **Cleanup** - Removes temporary installation files
- ✅ **No Manual Editing Required** - Pass configuration as parameters

## 📦 Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or higher
- Administrator privileges
- Internet connection
- Your RustDesk server configuration string

## 🚀 Quick Start

### Get Your Configuration String

1. Log in to your RustDesk server web portal
2. Navigate to the configuration section
3. Copy your configuration string (usually starts with `config=`)

### Run the Script

**Option 1: Edit the script and run**
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1" -OutFile "install-rustdesk.ps1"

# Edit the ConfigString in the script
notepad install-rustdesk.ps1

# Run it
.\install-rustdesk.ps1
```

**Option 2: Pass config as parameter (recommended)**
```powershell
$config = "your-config-string-here"
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1))) -ConfigString $config
```

## 📖 Usage

### Method 1: One-Line Installation

First, edit the script on GitHub to include your default configuration string, then:
```powershell
iex (irm https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1)
```

### Method 2: With Parameters

**Basic usage with config string:**
```powershell
$config = "config=YOUR_CONFIG_STRING_HERE"

# Using scriptblock execution
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1))) -ConfigString $config
```

**With custom password:**
```powershell
$config = "config=YOUR_CONFIG_STRING_HERE"
$password = "MySecurePassword123!"

& ([scriptblock]::Create((irm https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1))) -ConfigString $config -Password $password
```

### Method 3: Download and Run Locally
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1" -OutFile "install-rustdesk.ps1"

# Run with parameters
.\install-rustdesk.ps1 -ConfigString "your-config-string" -Password "optional-password"
```

## ⚙️ Configuration

### Setting Default Configuration in Script

Edit the `install-rustdesk.ps1` file and replace this line:
```powershell
$ConfigString = "PASTE_YOUR_CONFIG_STRING_HERE"
```

With your actual config string:
```powershell
$ConfigString = "config=YOUR_ACTUAL_CONFIG_STRING"
```

### Configuration String Format

Your configuration string should look similar to:
```
config=example-server.com:21116,Y2xpZW50X2lkPTEyMzQ1Njc4OTAsYXBpX3Rva2VuPXRva2VuMTIzNDU2Nzg5MA==
```

Get this from your RustDesk server web interface.

## 🔧 Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ConfigString` | String | No* | "" | Your RustDesk server configuration string |
| `Password` | String | No | Random | Custom password for RustDesk access |

\* Required if not set in the script itself

## 🔍 What the Script Does

1. **Privilege Check** - Verifies administrator rights (prompts for elevation if needed)
2. **Version Detection** - Queries GitHub for the latest RustDesk release
3. **Installation Check** - Determines if RustDesk is already installed
4. **Download** - Fetches the latest installer if needed
5. **Silent Install** - Runs the installer without user interaction
6. **Service Setup** - Installs and starts the RustDesk service
7. **Configuration** - Applies your server settings
8. **Password Setup** - Sets a random or custom password
9. **Cleanup** - Removes temporary installation files
10. **Output** - Displays the RustDesk ID and password

## 🔒 Security Considerations

- ⚠️ **Store Credentials Securely**: The script outputs the RustDesk ID and password. Save these in a secure password manager.
- ⚠️ **Configuration String**: Your config string may contain sensitive information. Don't commit it to public repositories.
- ⚠️ **Script Source**: Only run scripts from trusted sources. Review the code before execution.
- ⚠️ **HTTPS**: The script uses HTTPS for all downloads to prevent man-in-the-middle attacks.
- ⚠️ **Password Strength**: Default random passwords are 12 characters. For production, consider stronger passwords.

### Best Practices

1. **Use a Private Repository** - If storing your config string in the script
2. **Environment Variables** - Store config in environment variables for automation
3. **Deployment Tools** - Integrate with your existing deployment pipeline
4. **Audit Trail** - Keep records of which machines have RustDesk installed

## 🐛 Troubleshooting

### Common Issues

**Issue: "Configuration string not set"**
```
Solution: Either edit the script to include your config string or pass it as a parameter.
```

**Issue: Script won't run (Execution Policy)**
```powershell
# Check current policy
Get-ExecutionPolicy

# Temporarily bypass (current session only)
Set-ExecutionPolicy Bypass -Scope Process -Force

# Or run with bypass
powershell -ExecutionPolicy Bypass -File .\install-rustdesk.ps1
```

**Issue: "Access Denied" or "Administrator privileges required"**
```
Solution: Right-click PowerShell and select "Run as Administrator"
```

**Issue: Service fails to start**
```powershell
# Check service status
Get-Service RustDesk

# Try manual start
Start-Service RustDesk

# Check service logs
Get-EventLog -LogName Application -Source RustDesk -Newest 10
```

**Issue: Can't connect after installation**
```
Solution: 
1. Verify your config string is correct
2. Check firewall rules allow RustDesk
3. Verify RustDesk service is running
4. Check the RustDesk ID is correct
```

### Logs and Debugging

Enable verbose output:
```powershell
$VerbosePreference = "Continue"
.\install-rustdesk.ps1 -ConfigString "your-config" -Verbose
```

Check RustDesk installation:
```powershell
# Check if installed
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk"

# Check service
Get-Service RustDesk | Format-List *

# Check process
Get-Process rustdesk* | Format-Table
```

## 📚 Examples

### Example 1: Basic Installation
```powershell
# Simple one-liner with embedded config
$config = "config=myserver.com:21116,base64encodedstring"
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1))) -ConfigString $config
```

### Example 2: Mass Deployment with PDQ Deploy
```powershell
# Save as .ps1 file for PDQ Deploy
param(
    [string]$ConfigString = "config=myserver.com:21116,base64encodedstring"
)

$scriptUrl = "https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1"
$script = Invoke-RestMethod -Uri $scriptUrl
$scriptBlock = [scriptblock]::Create($script)

& $scriptBlock -ConfigString $ConfigString
```

### Example 3: Scheduled Task for Multiple Machines
```powershell
# Create scheduled task to install RustDesk
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -Command `"& ([scriptblock]::Create((irm https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1))) -ConfigString 'your-config'`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "Install RustDesk" -Action $action -Trigger $trigger -Principal $principal
```

### Example 4: Group Policy Deployment
```powershell
# Save this as a startup script in Group Policy
# Computer Configuration > Windows Settings > Scripts > Startup

$config = "config=myserver.com:21116,base64encodedstring"
$logFile = "C:\Windows\Temp\rustdesk-install.log"

try {
    $script = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1"
    $scriptBlock = [scriptblock]::Create($script)
    & $scriptBlock -ConfigString $config *>&1 | Tee-Object -FilePath $logFile
}
catch {
    $_ | Out-File -FilePath $logFile -Append
}
```

### Example 5: Intune Deployment
```powershell
# Package as Win32 app for Intune
# Install command:
powershell.exe -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk.ps1'))) -ConfigString 'your-config-string'"

# Detection rule (Registry):
# Path: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk
# Value: DisplayVersion
# Type: String
# Operator: Exists
```

## 🔄 Updating RustDesk

The script automatically detects if an update is available:
```powershell
# Run the script again - it will check for updates
.\install-rustdesk.ps1 -ConfigString "your-config"
```

To force reinstallation:
```powershell
# Uninstall first
$uninstaller = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" | Select-Object -ExpandProperty UninstallString
Start-Process cmd.exe -ArgumentList "/c $uninstaller /S" -Wait

# Then run the script
.\install-rustdesk.ps1 -ConfigString "your-config"
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Ideas for Contributions

- [ ] Add support for custom ports
- [ ] Add logging to file option
- [ ] Create uninstall script
- [ ] Add support for silent configuration updates
- [ ] Add email notification option
- [ ] Create GUI wrapper
- [ ] Add support for custom installation paths

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This script is provided as-is without any warranty. Always test in a non-production environment first. The author is not responsible for any damage or data loss caused by the use of this script.

## 🙏 Acknowledgments

- [RustDesk](https://rustdesk.com/) - The open-source remote desktop software
- Original script inspiration from RustDesk community

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/rustdesk-installer/issues)
- **RustDesk Documentation**: [rustdesk.com/docs](https://rustdesk.com/docs/)
- **RustDesk Community**: [GitHub Discussions](https://github.com/rustdesk/rustdesk/discussions)

---

<div align="center">

Made with ❤️ by [Luis](https://github.com/YOUR_USERNAME)

⭐ Star this repository if you find it helpful!

</div>
