#!/bin/bash
# macOS Configuration Script + Dock Cleanup
# Log file for debugging
LOG_FILE=~/macos-config-setup.log
echo "Starting configuration script at $(date)" > "$LOG_FILE"

# ========================
# Check for Homebrew (do NOT install automatically)
# ========================
check_homebrew() {
    echo "Checking for Homebrew..." | tee -a "$LOG_FILE"
    
    if command -v brew >/dev/null 2>&1; then
        echo "Homebrew is installed." | tee -a "$LOG_FILE"
        eval "$(brew shellenv)" 2>>"$LOG_FILE"
        return 0
    else
        echo "WARNING: Homebrew is NOT installed." | tee -a "$LOG_FILE"
        echo "Dock cleanup (dockutil) will be skipped." | tee -a "$LOG_FILE"
        echo ""
        echo "To enable Dock cleanup, install Homebrew manually with:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        return 1
    fi
}

# Function to check and fix permissions
fix_permissions() {
    local plist_file="$1"
    if [ ! -f "$plist_file" ]; then
        echo "Creating $plist_file..." | tee -a "$LOG_FILE"
        touch "$plist_file" 2>>"$LOG_FILE"
        /usr/libexec/PlistBuddy -c "Save" "$plist_file" 2>>"$LOG_FILE"
    fi
    chmod 600 "$plist_file" 2>>"$LOG_FILE"
    chown $USER:staff "$plist_file" 2>>"$LOG_FILE"
}

# Function to apply general settings
apply_setting() {
    local domain="$1"
    local key="$2"
    local value="$3"
    local type="$4"
    local current_host="${5:-}"

    local plist_file=~/Library/Preferences/"$domain".plist
    local command_prefix="defaults write"
    local read_prefix="defaults read"

    if [ "$current_host" = "-currentHost" ]; then
        command_prefix="defaults -currentHost write"
        read_prefix="defaults -currentHost read"
        plist_file=$(ls ~/Library/Preferences/ByHost/"$domain".*.plist 2>/dev/null | head -n 1)
        if [ -z "$plist_file" ]; then
            plist_file=~/Library/Preferences/ByHost/"$domain".$(uuidgen).plist
            touch "$plist_file"
        fi
    fi

    echo "Setting $domain : $key = $value ..." | tee -a "$LOG_FILE"
    killall cfprefsd 2>/dev/null
    sleep 1

    local plist_type="$type"
    [ "$type" = "-bool" ] && plist_type="bool"
    [ "$type" = "-int" ] && plist_type="integer"

    if [ "$domain" = "com.apple.finder" ]; then
        fix_permissions "$plist_file"
        /usr/libexec/PlistBuddy -c "Add :$key $plist_type $value" "$plist_file" 2>>"$LOG_FILE" || \
        /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_file" 2>>"$LOG_FILE"
    else
        $command_prefix "$domain" "$key" "$type" "$value" 2>>"$LOG_FILE" || \
        /usr/libexec/PlistBuddy -c "Add :$key $plist_type $value" "$plist_file" 2>>"$LOG_FILE" || \
        /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_file" 2>>"$LOG_FILE"
    fi
}

# ========================
# Disable Fn/Globe key popup ("Press 🌐 key to" → "Do Nothing")
# ========================
disable_globe_key_popup() {
    echo "Disabling Fn/Globe key popup (setting to 'Do Nothing')..." | tee -a "$LOG_FILE"
    
    defaults write com.apple.HIToolbox AppleFnUsageType -int 0 2>>"$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        echo "Successfully set AppleFnUsageType to 0." | tee -a "$LOG_FILE"
    else
        local plist=~/Library/Preferences/com.apple.HIToolbox.plist
        fix_permissions "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleFnUsageType integer 0" "$plist" 2>>"$LOG_FILE" || \
        /usr/libexec/PlistBuddy -c "Set :AppleFnUsageType 0" "$plist" 2>>"$LOG_FILE"
    fi

    killall cfprefsd SystemUIServer 2>/dev/null
    sleep 2
}

# ========================
# Main Configuration
# ========================
echo "=== Starting macOS Setup ===" | tee -a "$LOG_FILE"

# Check Homebrew (no auto-install)
check_homebrew
HOMEBREW_INSTALLED=$?

# Clear cache
killall Finder cfprefsd 2>/dev/null
sleep 1

# Apply Globe key fix (always runs)
disable_globe_key_popup

# System & Finder tweaks
apply_setting com.apple.finder ShowHardDrivesOnDesktop true -bool
apply_setting com.apple.finder ShowMountedServersOnDesktop true -bool
apply_setting com.apple.finder ShowHomeFolderInSidebar true -bool
apply_setting com.apple.finder _FXShowPosixPathInTitle true -bool
apply_setting NSGlobalDomain AppleShowAllExtensions true -bool
apply_setting com.apple.finder QuitMenuItem true -bool

# Login screen
echo "Setting hostname on login screen..." | tee -a "$LOG_FILE"
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName 2>>"$LOG_FILE"

# Trackpad right-click
apply_setting com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick 2 -int
apply_setting com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick true -bool
apply_setting NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior 1 -int -currentHost
apply_setting NSGlobalDomain com.apple.trackpad.enableSecondaryClick true -bool -currentHost
apply_setting com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick 2 -int
apply_setting com.apple.AppleMultitouchTrackpad TrackpadRightClick true -bool

# Disable Gatekeeper
echo "Disabling Gatekeeper..." | tee -a "$LOG_FILE"
sudo spctl --master-disable 2>>"$LOG_FILE"

# Disable AI & personalized ads
apply_setting com.apple.assistant.support AIConsentStatus false -bool
apply_setting com.apple.AdLib allowApplePersonalizedAdvertising false -bool

# Sublime Text CLI
echo "Creating 'subl' command..." | tee -a "$LOG_FILE"
sudo ln -sf "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl 2>>"$LOG_FILE"

# ========================
# Dock Cleanup (only if Homebrew + dockutil is available)
# ========================
if [ $HOMEBREW_INSTALLED -eq 0 ] && command -v dockutil >/dev/null 2>&1; then
    echo "=== Cleaning up Dock ===" | tee -a "$LOG_FILE"
    
    echo "Removing default apps from Dock..." | tee -a "$LOG_FILE"
    dockutil --remove "Messages" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Mail" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Maps" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Photos" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "FaceTime" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Phone" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Calendar" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Contacts" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Reminders" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Notes" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Keynote" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Numbers" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Pages" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "Games" --allhomes 2>>"$LOG_FILE"
    dockutil --remove "iPhone Mirroring" --allhomes 2>>"$LOG_FILE"

    killall Dock 2>>"$LOG_FILE"
    echo "Dock cleanup completed." | tee -a "$LOG_FILE"
else
    echo "Skipping Dock cleanup (Homebrew or dockutil not available)." | tee -a "$LOG_FILE"
fi

# Final cleanup
killall Finder 2>/dev/null

echo "=== macOS Configuration Script Finished! ===" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Reboot is recommended for all changes to take full effect." | tee -a "$LOG_FILE"
