#!/bin/zsh

#
# RustDesk Silent Installation Script for macOS
#
# Description:
#   Automatically downloads, installs, and configures RustDesk with a random password.
#   Designed to be run directly from GitHub for easy deployment.
#
# Usage:
#   zsh <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk-mac.sh)
#
# With custom config:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/rustdesk-installer/main/install-rustdesk-mac.sh | zsh -s -- --config "your-config-string"
#
# Author: Luis
# Requires: macOS 10.13+ and sudo privileges
#

# ============================================================================
# CONFIGURATION SECTION
# ============================================================================

# Default configuration string (edit this or pass as parameter)
CONFIG_STRING=""

# Custom password (leave empty for random generation)
CUSTOM_PASSWORD=""

# Installation settings
TEMP_DIR="/tmp/rustdesk-install"
INSTALL_TIMEOUT=60
SERVICE_TIMEOUT=30

# ============================================================================
# COLOR OUTPUT FUNCTIONS
# ============================================================================

log_info() {
    echo -e "\033[0;36m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

generate_random_password() {
    local length=${1:-12}
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

get_latest_rustdesk_version() {
    log_info "Fetching latest RustDesk version information..."
    
    # Detect architecture
    local arch=$(uname -m)
    local arch_filter=""
    
    if [[ "$arch" == "arm64" ]] || [[ "$arch" == "aarch64" ]]; then
        arch_filter="aarch64"
        log_info "Detected Apple Silicon (ARM64)"
    else
        arch_filter="x86_64"
        log_info "Detected Intel (x86_64)"
    fi
    
    # Try GitHub API first
    local api_response
    api_response=$(curl -fsSL "https://api.github.com/repos/rustdesk/rustdesk/releases/latest" 2>/dev/null || echo "")
    
    if [[ -n "$api_response" ]]; then
        local version
        local download_url
        
        version=$(echo "$api_response" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        if [[ "$arch_filter" == "aarch64" ]]; then
            download_url=$(echo "$api_response" | grep '"browser_download_url":.*\.dmg"' | grep -E 'aarch64|arm64' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
        else
            download_url=$(echo "$api_response" | grep '"browser_download_url":.*\.dmg"' | grep -v 'aarch64' | grep -v 'arm64' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
        fi
        
        if [[ -n "$version" ]] && [[ -n "$download_url" ]]; then
            echo "$version|$download_url"
            return 0
        fi
    fi
    
    # Fallback to scraping releases page
    log_warning "GitHub API failed, trying fallback method..."
    
    local page_content
    page_content=$(curl -fsSL "https://github.com/rustdesk/rustdesk/releases/latest" 2>/dev/null || echo "")
    
    if [[ -n "$page_content" ]]; then
        local download_url
        
        if [[ "$arch_filter" == "aarch64" ]]; then
            download_url=$(echo "$page_content" | grep -o 'href="[^"]*rustdesk-[^"]*\.dmg"' | grep -E 'aarch64|arm64' | head -1 | sed 's/href="//;s/"$//')
        else
            download_url=$(echo "$page_content" | grep -o 'href="[^"]*rustdesk-[^"]*\.dmg"' | grep -v 'arm64\|aarch64' | head -1 | sed 's/href="//;s/"$//')
        fi
        
        if [[ "$download_url" == //* ]]; then
            download_url="https://github.com${download_url}"
        fi
        
        local version
        version=$(echo "$download_url" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        
        if [[ -n "$version" ]] && [[ -n "$download_url" ]]; then
            echo "$version|$download_url"
            return 0
        fi
    fi
    
    log_error "Could not determine latest version"
    return 1
}

check_rustdesk_installed() {
    if [[ -d "/Applications/RustDesk.app" ]]; then
        local version=""
        if [[ -f "/Applications/RustDesk.app/Contents/Info.plist" ]]; then
            version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/RustDesk.app/Contents/Info.plist" 2>/dev/null || echo "unknown")
        fi
        echo "installed|$version"
    else
        echo "not_installed|"
    fi
}

stop_rustdesk_processes() {
    log_info "Stopping any running RustDesk processes..."
    
    pkill -f "RustDesk" 2>/dev/null || true
    sleep 2
}

wait_for_rustdesk_installation() {
    local timeout=${1:-60}
    log_info "Waiting for RustDesk installation to complete..."
    
    local elapsed=0
    local check_interval=2
    
    while [[ $elapsed -lt $timeout ]]; do
        if [[ -d "/Applications/RustDesk.app" ]] && [[ -f "/Applications/RustDesk.app/Contents/MacOS/RustDesk" ]]; then
            log_success "RustDesk installation detected"
            return 0
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        if [[ $((elapsed % 10)) -eq 0 ]]; then
            log_info "Still waiting... ($elapsed seconds elapsed)"
        fi
    done
    
    return 1
}

mount_dmg() {
    local dmg_path="$1"
    log_info "Mounting DMG file..."
    
    local mount_output
    mount_output=$(hdiutil attach "$dmg_path" -nobrowse -quiet 2>&1)
    
    local mount_point
    mount_point=$(echo "$mount_output" | grep "/Volumes" | tail -1 | awk '{print $3}')
    
    if [[ -z "$mount_point" ]]; then
        # Try alternative method
        mount_point=$(hdiutil attach "$dmg_path" -nobrowse 2>/dev/null | grep "/Volumes" | tail -1 | sed 's/.*\(\/Volumes\/.*\)/\1/')
    fi
    
    if [[ -n "$mount_point" ]]; then
        echo "$mount_point"
        return 0
    fi
    
    return 1
}

unmount_dmg() {
    local mount_point="$1"
    if [[ -n "$mount_point" ]] && [[ -d "$mount_point" ]]; then
        log_info "Unmounting DMG..."
        hdiutil detach "$mount_point" -quiet 2>/dev/null || true
    fi
}

install_rustdesk_from_dmg() {
    local dmg_path="$1"
    
    local mount_point
    mount_point=$(mount_dmg "$dmg_path")
    
    if [[ -z "$mount_point" ]]; then
        log_error "Failed to mount DMG"
        return 1
    fi
    
    log_info "Copying RustDesk.app to Applications..."
    
    # Remove existing installation
    if [[ -d "/Applications/RustDesk.app" ]]; then
        rm -rf "/Applications/RustDesk.app"
    fi
    
    # Copy the app
    if [[ -d "$mount_point/RustDesk.app" ]]; then
        cp -R "$mount_point/RustDesk.app" /Applications/
        log_success "RustDesk copied to Applications"
    else
        log_error "RustDesk.app not found in DMG"
        unmount_dmg "$mount_point"
        return 1
    fi
    
    unmount_dmg "$mount_point"
    
    # Fix permissions and remove quarantine
    chmod -R 755 /Applications/RustDesk.app
    xattr -cr /Applications/RustDesk.app 2>/dev/null || true
    
    log_success "Permissions and quarantine attributes fixed"
    
    return 0
}

configure_rustdesk() {
    local config="$1"
    local password="$2"
    
    local rustdesk_bin="/Applications/RustDesk.app/Contents/MacOS/RustDesk"
    
    if [[ ! -f "$rustdesk_bin" ]]; then
        log_error "RustDesk binary not found"
        return 1
    fi
    
    log_info "Applying configuration and password..."
    
    # Apply configuration
    "$rustdesk_bin" --config "$config" >/dev/null 2>&1 || true
    sleep 2
    
    # Set password
    "$rustdesk_bin" --password "$password" >/dev/null 2>&1 || true
    sleep 2
    
    # Get RustDesk ID
    local rustdesk_id
    rustdesk_id=$("$rustdesk_bin" --get-id 2>/dev/null | head -1 || echo "")
    
    if [[ -z "$rustdesk_id" ]]; then
        log_warning "Could not retrieve RustDesk ID immediately, retrying..."
        sleep 3
        rustdesk_id=$("$rustdesk_bin" --get-id 2>/dev/null | head -1 || echo "Check RustDesk app")
    fi
    
    echo "$rustdesk_id"
}

setup_launch_agent() {
    log_info "Setting up RustDesk launch agent..."
    
    local plist_path="/Library/LaunchAgents/com.carriez.rustdesk_service.plist"
    
    cat > "$plist_path" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.carriez.rustdesk_service</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/RustDesk.app/Contents/MacOS/RustDesk</string>
        <string>--server</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

    chmod 644 "$plist_path"
    
    # Unload if already loaded
    launchctl unload "$plist_path" 2>/dev/null || true
    
    # Load the launch agent
    launchctl load "$plist_path" 2>/dev/null || true
    
    log_success "Launch agent configured"
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_STRING="$2"
                shift 2
                ;;
            --password)
                CUSTOM_PASSWORD="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat <<'EOF'
RustDesk Installation Script for macOS

Usage:
    zsh install-rustdesk-mac.sh [OPTIONS]

Options:
    --config CONFIG_STRING    Your RustDesk server configuration string
    --password PASSWORD       Custom password (optional, random if not provided)
    --help, -h               Show this help message

Examples:
    # Run with config string
    sudo zsh install-rustdesk-mac.sh --config "config=server.com:21116,base64string"
    
    # Run with config and custom password
    sudo zsh install-rustdesk-mac.sh --config "config=server.com:21116,base64string" --password "MyPassword123"
    
    # Run directly from GitHub
    zsh <(curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install-rustdesk-mac.sh)
    
    # Run from GitHub with parameters
    curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install-rustdesk-mac.sh | sudo zsh -s -- --config "your-config"

EOF
}

# ============================================================================
# MAIN INSTALLATION LOGIC
# ============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  RustDesk Installation Script (macOS)"
    echo "========================================"
    echo ""
    
    # Check for root privileges first
    if [[ $EUID -ne 0 ]]; then
        log_warning "This script requires sudo privileges"
        log_info "Please run with sudo:"
        echo ""
        echo "  sudo zsh $0 $@"
        echo ""
        exit 1
    fi
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Validate configuration string
    if [[ -z "$CONFIG_STRING" ]] || [[ "$CONFIG_STRING" == "PASTE_YOUR_CONFIG_STRING_HERE" ]]; then
        log_error "Configuration string not set!"
        log_error "Please pass --config parameter or edit the script"
        echo ""
        show_help
        exit 1
    fi
    
    # Generate or use provided password
    if [[ -z "$CUSTOM_PASSWORD" ]]; then
        RUSTDESK_PASSWORD=$(generate_random_password 12)
        log_info "Generated random password"
    else
        RUSTDESK_PASSWORD="$CUSTOM_PASSWORD"
        log_info "Using provided password"
    fi
    
    # Get latest version info
    local version_info
    version_info=$(get_latest_rustdesk_version)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to fetch RustDesk version information"
        exit 1
    fi
    
    local latest_version=${version_info%%|*}
    local download_url=${version_info##*|}
    
    log_info "Latest version: $latest_version"
    log_info "Download URL: $download_url"
    
    # Check current installation
    local install_info
    install_info=$(check_rustdesk_installed)
    local install_status=${install_info%%|*}
    local current_version=${install_info##*|}
    
    if [[ "$install_status" == "installed" ]]; then
        log_info "Current version: $current_version"
        
        if [[ "$current_version" == "$latest_version" ]]; then
            log_success "RustDesk is already up to date!"
            
            # Stop processes and reconfigure
            stop_rustdesk_processes
            
            log_info "Applying configuration..."
            local rustdesk_id
            rustdesk_id=$(configure_rustdesk "$CONFIG_STRING" "$RUSTDESK_PASSWORD")
            
            echo ""
            echo "========================================"
            echo "  Configuration Updated"
            echo "========================================"
            echo "RustDesk ID: $rustdesk_id"
            echo "Password: $RUSTDESK_PASSWORD"
            echo "========================================"
            echo ""
            
            exit 0
        else
            log_info "Updating to version $latest_version..."
        fi
    else
        log_info "RustDesk not installed. Installing version $latest_version..."
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download installer
    local dmg_file="$TEMP_DIR/rustdesk.dmg"
    log_info "Downloading RustDesk installer..."
    
    if ! curl -fL "$download_url" -o "$dmg_file"; then
        log_error "Failed to download RustDesk"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    log_success "Download completed"
    
    # Stop any running processes
    stop_rustdesk_processes
    
    # Install RustDesk
    log_info "Installing RustDesk..."
    
    if ! install_rustdesk_from_dmg "$dmg_file"; then
        log_error "Installation failed"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Verify installation
    sleep 2
    if [[ ! -d "/Applications/RustDesk.app" ]]; then
        log_error "RustDesk installation verification failed"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    log_success "Installation completed successfully"
    
    # Setup launch agent for auto-start
    setup_launch_agent
    
    # Give it a moment to initialize
    sleep 3
    
    # Configure RustDesk
    local rustdesk_id
    rustdesk_id=$(configure_rustdesk "$CONFIG_STRING" "$RUSTDESK_PASSWORD")
    
    # Clean up
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    
    # Display results
    echo ""
    echo "========================================"
    echo "  Installation Completed Successfully"
    echo "========================================"
    echo "RustDesk ID: $rustdesk_id"
    echo "Password: $RUSTDESK_PASSWORD"
    echo "Version: $latest_version"
    echo "========================================"
    echo ""
    log_warning "Save these credentials in a secure location!"
    echo ""
    log_info "RustDesk has been installed and configured"
    log_info "The service will start automatically on login"
    echo ""
}

# Run main function
main "$@"
