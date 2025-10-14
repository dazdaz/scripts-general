# macOS Configuration Script Documentation

## Overview

This Bash script (`setup-macos-config.sh`) automates the configuration of macOS system preferences for macOS Sequoia (15.x) and compatible versions. It modifies Finder settings, trackpad behavior, login screen display, security settings, and privacy options using a combination of `defaults` commands and `PlistBuddy` for reliable configuration management.

---

## Features

* **Finder Enhancements**: Shows the user's Library folder, all file extensions, and the path bar. Sets the default search scope to the current folder.
* **Trackpad & Mouse**: Enables "Tap to click" for the trackpad and user account. Configures tracking speed for both trackpad and mouse.
* **Login & Screen**: Displays a detailed login screen with hostname, system version, and time. Sets a custom login screen message.
* **Security Hardening**: Activates the stealth mode for the application firewall (`AF`).
* **Privacy Controls**: Disables the creation of `.DS_Store` files on network volumes to prevent metadata leakage.
* **System UI**: Configures the Dock to automatically hide and show.



---

## Prerequisites

* **Operating System**: macOS Sequoia (15.x) or a compatible recent version (e.g., Sonoma, Ventura).
* **Permissions**: Administrative (sudo) privileges are required to modify system-level settings.
* **Backup**: It is **highly recommended** to back up your system using Time Machine or another backup utility before running the script.

---

## Usage

1.  **Download the Script**:
    Save the script code as `setup-macos-config.sh`.

2.  **Make the Script Executable**:
    Open the Terminal application and navigate to the directory where you saved the script. Run the following command:
    ```bash
    chmod +x setup-macos-config.sh
    ```

3.  **Run the Script**:
    Execute the script with `sudo` to grant it the necessary administrative privileges:
    ```bash
    sudo ./setup-macos-config.sh
    ```
    You will be prompted to enter your administrator password.

---

## Script Breakdown

The script is organized into logical sections, each targeting a specific area of the macOS configuration.

### 1. Finder Settings

This section modifies how the Finder displays files and handles searches.

* **Show Library Folder**: Makes the `~/Library` folder visible.
    ```bash
    chflags nohidden ~/Library
    ```
* **Show All File Extensions**: Forces Finder to show all file extensions (e.g., `.txt`, `.jpg`).
    ```bash
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    ```
* **Show Path Bar**: Displays the file path at the bottom of the Finder window.
    ```bash
    defaults write com.apple.finder ShowPathbar -bool true
    ```
* **Default Search Scope**: Changes the default search to scan the current folder instead of "This Mac".
    ```bash
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    ```

### 2. Trackpad & Mouse Settings

These commands adjust the behavior of pointing devices.

* **Enable Tap to Click**: Activates single-tap clicking for the trackpad.
    ```bash
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    ```
* **Set Tracking Speed**: Adjusts the cursor speed. The value `2.0` is a moderate speed; you can change it as needed.
    ```bash
    defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0
    defaults write NSGlobalDomain com.apple.mouse.scaling -float 2.0
    ```

### 3. Login Screen Configuration

This part uses `PlistBuddy` to modify the login window preferences file, which requires higher privileges.

* **Set Detailed Info**: Configures the login screen to show system details.
    ```bash
    /usr/libexec/PlistBuddy -c "Set :LoginwindowText 'Hostname: %H | macOS: %S %V | Time: %T'" /Library/Preferences/com.apple.loginwindow.plist
    ```
* **Show Detailed Status**: Enables the display of the information set above.
    ```bash
    defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
    ```

### 4. Security & Privacy

These settings enhance system security and user privacy.

* **Enable Firewall Stealth Mode**: Prevents the Mac from responding to probing requests or pings, making it less visible on networks.
    ```bash
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 2
    sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1
    ```
* **Disable .DS\_Store on Network Drives**: Stops macOS from creating metadata files on shared network volumes, which can be useful in mixed-OS environments.
    ```bash
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    ```

### 5. Applying Changes

After setting all the preferences, the script restarts key system processes to apply the changes without requiring a full system reboot.

```bash
killall Finder
killall Dock
```

⚠️ Disclaimer
This script modifies system-level configuration files. While the commands used are standard and generally safe, running scripts with sudo carries inherent risks. The author is not responsible for any data loss or system instability that may occur. Please review the script's commands and ensure you understand their function before execution.

---

# macOS Configuration & Git Setup Scripts

A collection of scripts to streamline the setup and configuration of a new macOS environment, from system tweaks to secure Git authentication.

***

## Table of Contents

-   [GitHub PAT Setup for macOS](#github-pat-setup-for-macos)
-   [macOS System Configuration Script](#macos-system-configuration-script)
