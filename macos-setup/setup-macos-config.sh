#!/bin/bash
# Log file for debugging
LOG_FILE=~/macos-config-setup.log
echo "Starting configuration script at $(date)" > "$LOG_FILE"

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
    echo "Fixed permissions for $plist_file" >> "$LOG_FILE"
}

# Function to find the correct ByHost plist for NSGlobalDomain
find_byhost_plist() {
    local domain="$1"
    local plist_file=$(ls ~/Library/Preferences/ByHost/"$domain".*.plist 2>/dev/null | head -n 1)
    if [ -z "$plist_file" ]; then
        echo "No ByHost plist found for $domain. Creating one..." | tee -a "$LOG_FILE"
        plist_file=~/Library/Preferences/ByHost/"$domain".$(uuidgen).plist
        touch "$plist_file" 2>>"$LOG_FILE"
        /usr/libexec/PlistBuddy -c "Save" "$plist_file" 2>>"$LOG_FILE"
    fi
    echo "$plist_file"
}

# Function to apply settings with PlistBuddy for Finder, defaults for others
apply_setting() {
    local domain="$1"
    local key="$2"
    local value="$3"
    local type="$4"
    local current_host="$5" # Optional: -currentHost or empty
    local plist_file=~/Library/Preferences/"$domain".plist
    local command_prefix="defaults write"
    local read_prefix="defaults read"
    if [ "$current_host" = "-currentHost" ]; then
        command_prefix="defaults -currentHost write"
        read_prefix="defaults -currentHost read"
        plist_file=$(find_byhost_plist "$domain")
    fi
    echo "Setting $domain $key to $value (type: $type)..." | tee -a "$LOG_FILE"
    # Clear defaults cache and Finder
    killall cfprefsd 2>/dev/null
    killall Finder 2>/dev/null
    sleep 1 # Wait for processes to terminate
    # Normalize type for PlistBuddy
    local plist_type="$type"
    [ "$type" = "-bool" ] && plist_type="bool"
    [ "$type" = "-int" ] && plist_type="integer"
    # Use PlistBuddy for Finder settings, defaults for others
    if [ "$domain" = "com.apple.finder" ]; then
        fix_permissions "$plist_file"
        /usr/libexec/PlistBuddy -c "Add :$key $plist_type $value" "$plist_file" 2>>"$LOG_FILE" || \
        /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_file" 2>>"$LOG_FILE"
        if [ $? -eq 0 ]; then
            echo "Successfully set $key with PlistBuddy." | tee -a "$LOG_FILE"
            killall Finder 2>/dev/null
            sleep 1
        else
            echo "Error setting $key with PlistBuddy. Resetting plist and retrying..." | tee -a "$LOG_FILE"
            mv "$plist_file" "${plist_file}.bak" 2>>"$LOG_FILE"
            touch "$plist_file" 2>>"$LOG_FILE"
            fix_permissions "$plist_file"
            /usr/libexec/PlistBuddy -c "Add :$key $plist_type $value" "$plist_file" 2>>"$LOG_FILE"
            if [ $? -eq 0 ]; then
                echo "Success after resetting plist." | tee -a "$LOG_FILE"
                killall Finder 2>/dev/null
                sleep 1
            else
                echo "Failed to set $key. Check $LOG_FILE for details." | tee -a "$LOG_FILE"
                exit 1
            fi
        fi
    else
        fix_permissions "$plist_file"
        $command_prefix "$domain" "$key" "$type" "$value" 2>>"$LOG_FILE"
        if [ $? -eq 0 ]; then
            echo "Successfully set $key with defaults." | tee -a "$LOG_FILE"
        else
            echo "Error setting $key with defaults. Trying PlistBuddy..." | tee -a "$LOG_FILE"
            /usr/libexec/PlistBuddy -c "Add :$key $plist_type $value" "$plist_file" 2>>"$LOG_FILE" || \
            /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_file" 2>>"$LOG_FILE"
            if [ $? -eq 0 ]; then
                echo "Successfully set $key with PlistBuddy." | tee -a "$LOG_FILE"
            else
                echo "Failed to set $key. Check $LOG_FILE for details." | tee -a "$LOG_FILE"
                exit 1
            fi
        fi
    fi
    # Verify setting
    echo "Verifying $key..." | tee -a "$LOG_FILE"
    local read_output
    read_output=$($read_prefix "$domain" "$key" 2>>"$LOG_FILE")
    echo "defaults read output: $read_output" >> "$LOG_FILE"
    # Normalize expected value for verification
    local expected_value="$value"
    [ "$value" = "true" ] && expected_value="1"
    [ "$value" = "false" ] && expected_value="0"
    if echo "$read_output" | grep -q "^$expected_value$"; then
        echo "Verified $key is set to $value." | tee -a "$LOG_FILE"
    else
        echo "Warning: $key verification failed. Expected $value, got: $read_output" | tee -a "$LOG_FILE"
    fi
}

# Stop Finder and clear defaults cache
killall Finder 2>/dev/null
killall cfprefsd 2>/dev/null

# Enable Hard Disks and Connected Servers on Desktop (Finder General)
apply_setting com.apple.finder ShowHardDrivesOnDesktop true -bool
apply_setting com.apple.finder ShowMountedServersOnDesktop true -bool

# Enable Home in Sidebar (Movies, Music, Pictures auto-appear under Favorites)
apply_setting com.apple.finder ShowHomeFolderInSidebar true -bool
apply_setting com.apple.finder _FXShowPosixPathInTitle true -bool
# Note: If Movies/Music/Pictures don't show, enable manually in Finder > Preferences > Sidebar

# Enable Show All Filename Extensions (Finder Advanced)
apply_setting NSGlobalDomain AppleShowAllExtensions true -bool

# Show System Info (Hostname) on Login Screen (System-wide)
echo "Setting login screen info (requires sudo)..." | tee -a "$LOG_FILE"
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName 2>>"$LOG_FILE"
if [ $? -eq 0 ]; then
    echo "Login screen info set successfully." | tee -a "$LOG_FILE"
else
    echo "Failed to set login screen info. Check sudo permissions." | tee -a "$LOG_FILE"
    exit 1
fi

# Add Quit Option to Finder Menu
apply_setting com.apple.finder QuitMenuItem true -bool

# Enable Trackpad Secondary Click in Bottom Right Corner
apply_setting com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick 2 -int
apply_setting com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick true -bool
apply_setting NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior 1 -int -currentHost
apply_setting NSGlobalDomain com.apple.trackpad.enableSecondaryClick true -bool -currentHost
# For non-Bluetooth trackpads (e.g., MacBook built-in)
apply_setting com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick 2 -int
apply_setting com.apple.AppleMultitouchTrackpad TrackpadRightClick true -bool

# Disable Gatekeeper (requires sudo)
echo "Disabling Gatekeeper (requires sudo)..." | tee -a "$LOG_FILE"
sudo spctl --master-disable 2>>"$LOG_FILE"
if [ $? -eq 0 ]; then
    echo "Gatekeeper disabled successfully." | tee -a "$LOG_FILE"
else
    echo "Failed to disable Gatekeeper. On macOS Sequoia, you may need to confirm this change manually." | tee -a "$LOG_FILE"
    echo "Please go to System Settings > Privacy & Security and approve the change to allow apps from anywhere." | tee -a "$LOG_FILE"
fi

# Verify Gatekeeper status
spctl --status 2>>"$LOG_FILE" | grep -q "assessments disabled"
if [ $? -eq 0 ]; then
    echo "Verified Gatekeeper is disabled." | tee -a "$LOG_FILE"
else
    echo "Warning: Gatekeeper verification failed. Check System Settings > Privacy & Security to confirm." | tee -a "$LOG_FILE"
fi

# Disable Apple Intelligence (Privacy & Security)
apply_setting com.apple.assistant.support "AIConsentStatus" false -bool

# Disable Personalized Ads (Privacy & Security)
apply_setting com.apple.AdLib "allowApplePersonalizedAdvertising" false -bool

# === Added: Create 'subl' command-line symlink for Sublime Text ===
echo "Creating command-line symlink for Sublime Text..." | tee -a "$LOG_FILE"

# Ensure /usr/local/bin exists and is writable (it usually is on macOS)
if [ ! -d "/usr/local/bin" ]; then
    echo "Creating /usr/local/bin directory..." | tee -a "$LOG_FILE"
    sudo mkdir -p /usr/local/bin 2>>"$LOG_FILE"
fi

# Check if the symlink already exists
if [ -L "/usr/local/bin/subl" ]; then
    echo "Symlink /usr/local/bin/subl already exists. Skipping creation." | tee -a "$LOG_FILE"
elif [ -e "/usr/local/bin/subl" ]; then
    echo "A non-symlink file exists at /usr/local/bin/subl. Backing up and replacing..." | tee -a "$LOG_FILE"
    sudo mv /usr/local/bin/subl /usr/local/bin/subl.bak 2>>"$LOG_FILE"
fi

# Create the symlink (requires sudo because /usr/local/bin is system-protected)
sudo ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl 2>>"$LOG_FILE"

if [ $? -eq 0 ]; then
    echo "Successfully created 'subl' command-line tool." | tee -a "$LOG_FILE"
else
    echo "Failed to create 'subl' symlink. Check permissions or whether Sublime Text is installed." | tee -a "$LOG_FILE"
fi

# Verify the command works
if command -v subl >/dev/null 2>&1; then
    echo "Verified: 'subl' command is now available in Terminal." | tee -a "$LOG_FILE"
else
    echo "Warning: 'subl' command is not in PATH or not working." | tee -a "$LOG_FILE"
fi

# Restart Finder to apply changes
killall Finder 2>/dev/null

echo "Configuration applied! Check $LOG_FILE for details. Reboot recommended for trackpad, login screen, and Gatekeeper changes." | tee -a "$LOG_FILE"
