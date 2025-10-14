# GitHub PAT Setup for macOS

## Overview 📜

This script (`setup_github_pat.sh`) provides a simple and secure way for **macOS users** to configure their Git command-line interface to use a GitHub Personal Access Token (PAT).

It automates the process of setting up the `git-credential-osxkeychain` helper, which stores your PAT securely in the native macOS Keychain. Once configured, you will no longer need to enter your username or token for `git push`, `git pull`, or `git clone` operations on GitHub repositories.

---

## Features ✨

-   **Secure Storage**: Stores your GitHub PAT in the encrypted macOS Keychain, not in plaintext files.
-   **Automatic Configuration**: Sets the global Git `credential.helper` configuration to `osxkeychain`.
-   **Input Validation**: Tests the PAT against the GitHub API to ensure it's valid before saving.
-   **Prerequisite Checks**: Verifies that you are on macOS and that `git` and the `git-credential-osxkeychain` helper are available.
-   **Credential Management**: Allows you to add, update (`--force`), and remove credentials (`--remove`).
-   **User-Friendly**: Provides interactive prompts if the username or token are not supplied as arguments.
-   **Helpful Troubleshooting**: If the `osxkeychain` helper is missing, the script provides clear, actionable instructions on how to install it.

---

## Requirements 📋

> [!NOTE]
> **Before you begin, ensure you have:**
> * A computer running **macOS**.
> * **Git** installed on your system.
> * A valid **GitHub Personal Access Token (PAT)**. You can generate one from your GitHub settings: [**github.com/settings/tokens**](https://github.com/settings/tokens).

---

## Usage 🚀

1.  Save the script to a file (e.g., `setup_github_pat.sh`).
2.  Make the script executable from your terminal:
    ```bash
    chmod +x setup_github_pat.sh
    ```
3.  Run the script using one of the methods below.

### Command-Line Options

| Option             | Description                                                   |
| ------------------ | ------------------------------------------------------------- |
| `-h`, `--help`     | Display the help message and exit.                            |
| `-u`, `--username` | Your GitHub username.                                         |
| `-t`, `--token`    | Your GitHub Personal Access Token (PAT).                      |
| `-f`, `--force`    | Force update credentials, even if they already exist.         |
| `-r`, `--remove`   | Remove existing GitHub credentials from the Keychain and exit. |

### Examples

**Interactive Setup (Recommended)**
```bash
./setup_github_pat.sh
```

Non-Interactive Setup
```Bash
./setup_github_pat.sh -u your-username -t ghp_YourPersonalAccessToken
```

Update Existing Credentials
```Bash
./setup_github_pat.sh -u your-username -t ghp_YourPersonalAccessToken --force
```

Remove Stored Credentials
```Bash
./setup_github_pat.sh --remove
```

## How It Works ⚙️
The script performs the following steps:

System Checks: Verifies it's running on macOS and git is installed.

Finds Credential Helper: Locates the git-credential-osxkeychain executable.

Configures Git: Runs git config --global credential.helper osxkeychain to tell Git to use the macOS Keychain.

Stores Credentials: Passes your username and PAT to git-credential-osxkeychain to be stored securely.

Verification: Attempts to retrieve the credentials to confirm the process was successful.
