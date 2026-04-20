#!/usr/bin/env python3
"""
GitHub Username Availability Checker

Reads a text file containing potential GitHub usernames (one per line),
checks which ones are NOT registered (i.e., available),
and saves the available ones to an output file.

Usage:
    python check_github_usernames.py usernames.txt
    python check_github_usernames.py usernames.txt -o available.txt

Requirements:
    pip install requests
"""

import argparse
import requests
import time
import sys
from datetime import datetime

def is_valid_github_username(username: str) -> bool:
    """Basic validation for GitHub username rules."""
    if not username or len(username) > 39 or len(username) < 1:
        return False
    if username[0] == '-' or username[-1] == '-':
        return False
    if not all(c.isalnum() or c == '-' for c in username):
        return False
    return True

def check_username_availability(username: str, session: requests.Session) -> bool | None:
    """
    Check if a GitHub username is available.
    Returns:
        True  -> available (404)
        False -> taken (200)
        None  -> error or rate limited
    """
    url = f"https://api.github.com/users/{username}"
    headers = {
        "User-Agent": "GitHub-Username-Availability-Checker/1.0",
        "Accept": "application/vnd.github.v3+json"
    }

    try:
        response = session.get(url, headers=headers, timeout=10)

        # Check rate limit headers
        remaining = response.headers.get("X-RateLimit-Remaining")
        reset_time = response.headers.get("X-RateLimit-Reset")

        if remaining is not None and int(remaining) < 5:
            if reset_time:
                reset_timestamp = int(reset_time)
                wait_seconds = max(0, reset_timestamp - int(time.time()) + 5)
                print(f"\n⚠️  Rate limit low ({remaining} remaining). Waiting {wait_seconds}s until reset...")
                time.sleep(wait_seconds)

        if response.status_code == 404:
            return True   # Available!
        elif response.status_code == 200:
            return False  # Taken
        elif response.status_code == 403:
            print(f"\n🚫 Rate limited on {username}. Waiting 65 seconds...")
            time.sleep(65)
            return check_username_availability(username, session)  # Retry once
        else:
            print(f"\n⚠️  Unexpected status {response.status_code} for {username}")
            return None

    except requests.exceptions.RequestException as e:
        print(f"\n❌ Network error checking {username}: {e}")
        return None
    except Exception as e:
        print(f"\n❌ Error checking {username}: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(
        description="Check which GitHub usernames from a file are still available (not registered).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python check_github_usernames.py my_names.txt
  python check_github_usernames.py names.txt -o free_usernames.txt --delay 2
        """
    )
    parser.add_argument(
        "input_file",
        help="Text file with one GitHub username per line (comments starting with # are ignored)"
    )
    parser.add_argument(
        "-o", "--output",
        default="available_usernames.txt",
        help="Output file for available usernames (default: available_usernames.txt)"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.5,
        help="Delay in seconds between requests (default: 1.5, helps avoid rate limits)"
    )
    parser.add_argument(
        "--no-validate",
        action="store_true",
        help="Skip basic username format validation"
    )

    args = parser.parse_args()

    # Read usernames
    try:
        with open(args.input_file, "r", encoding="utf-8") as f:
            raw_lines = f.readlines()
    except FileNotFoundError:
        print(f"❌ Error: Input file '{args.input_file}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error reading file: {e}")
        sys.exit(1)

    usernames = []
    for line in raw_lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if not args.no_validate and not is_valid_github_username(line):
            print(f"⚠️  Skipping invalid username format: {line}")
            continue
        usernames.append(line)

    if not usernames:
        print("No valid usernames found in the input file.")
        sys.exit(0)

    print(f"🔍 Found {len(usernames)} usernames to check in '{args.input_file}'")
    print(f"📁 Results will be saved to '{args.output}'")
    print(f"⏱️  Delay between checks: {args.delay}s")
    print("-" * 60)

    session = requests.Session()
    available = []
    taken = 0
    errors = 0

    start_time = time.time()

    for i, username in enumerate(usernames, 1):
        print(f"[{i:3d}/{len(usernames)}] Checking {username:<30}", end=" ", flush=True)

        is_available = check_username_availability(username, session)

        if is_available is True:
            print("✅ AVAILABLE")
            available.append(username)
        elif is_available is False:
            print("❌ taken")
            taken += 1
        else:
            print("⚠️  error (skipped)")
            errors += 1

        # Respectful delay
        if i < len(usernames):
            time.sleep(args.delay)

    # Save results
    try:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(f"# Available GitHub usernames (checked on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')})\n")
            f.write(f"# Total checked: {len(usernames)} | Available: {len(available)} | Taken: {taken} | Errors: {errors}\n\n")
            for name in available:
                f.write(name + "\n")
        print("-" * 60)
        print(f"✅ Done! {len(available)} available usernames saved to '{args.output}'")
        print(f"   Taken: {taken} | Errors: {errors}")
        print(f"   Total time: {time.time() - start_time:.1f} seconds")
    except Exception as e:
        print(f"❌ Failed to write output file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
