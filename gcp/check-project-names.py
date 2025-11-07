#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.7"
# dependencies = [
#     "google-cloud-resource-manager",
# ]
# ///
"""
check_gcp_projects.py

Check if Google Cloud project IDs are already taken.

Usage:
    python check_gcp_projects.py                    # uses default 'project-names.txt'
    python check_gcp_projects.py my-wordlist.txt    # custom wordlist
    python check_gcp_projects.py -h                 # show help
"""

import argparse
import sys
import time
from typing import List

from google.cloud import resourcemanager_v3

# Default wordlist if none provided
DEFAULT_WORDLIST = "project-names.txt"

def read_project_names(filename: str) -> List[str]:
    """Read project IDs from file, one per line. Strips whitespace and skips empty lines/comments."""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            names = [
                line.strip()
                for line in f
                if line.strip() and not line.strip().startswith('#')
            ]
        print(f"[+] Loaded {len(names)} project name(s) from '{filename}'")
        return names
    except FileNotFoundError:
        print(f"[-] Error: File '{filename}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"[-] Error reading file: {e}")
        sys.exit(1)

def project_exists(client: resourcemanager_v3.ProjectsClient, project_id: str) -> bool:
    """Check if a project ID already exists in GCP (globally unique)."""
    try:
        client.get_project(name=f"projects/{project_id}")
        return True
    except Exception as e:
        # 404 = not found, 403 = permission denied (still means it exists or you can't see it)
        # For availability checking, both mean "you can't use this ID"
        if hasattr(e, 'status') and e.status in (404, 403):
            return False
        else:
            # Unexpected error (e.g., network, rate limit)
            print(f"[!] Unexpected error checking '{project_id}': {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description="Check availability of GCP project IDs")
    parser.add_argument(
        'wordlist',
        nargs='?',  # optional positional argument
        default=DEFAULT_WORDLIST,
        help=f"Path to wordlist file (default: {DEFAULT_WORDLIST})"
    )
    parser.add_argument(
        '--delay', '-d',
        type=float,
        default=0.2,
        help="Delay between requests in seconds (default: 0.2) to respect rate limits"
    )

    args = parser.parse_args()

    print("[*] GCP Project ID Availability Checker")
    print("[*] Make sure you have authenticated with: gcloud auth application-default login")
    print()

    # Initialize client
    try:
        client = resourcemanager_v3.ProjectsClient()
    except Exception as e:
        print(f"[-] Failed to initialize GCP client: {e}")
        print("    Run: gcloud auth application-default login")
        sys.exit(1)

    project_names = read_project_names(args.wordlist)

    if not project_names:
        print("[-] No project names to check.")
        sys.exit(0)

    available = []
    taken = []

    print(f"[*] Checking {len(project_names)} project ID(s)...\n")

    for i, name in enumerate(project_names, 1):
        # GCP project IDs must be lowercase, 6-30 chars, letters/numbers/hyphens
        if not (6 <= len(name) <= 30 and name.replace('-', '').isalnum() and name[0].isalpha()):
            print(f"[{i}/{len(project_names)}] ❌ INVALID: {name} (does not meet GCP naming rules)")
            continue

        exists = project_exists(client, name.lower())
        status = "TAKEN" if exists else "AVAILABLE"
        emoji = "❌" if exists else "✅"

        print(f"[{i}/{len(project_names)}] {emoji} {name.lower():30} → {status}")

        if not exists:
            available.append(name.lower())
        else:
            taken.append(name.lower())

        time.sleep(args.delay)  # Be nice to the API

    # Summary
    print("\n" + "="*50)
    print("SUMMARY")
    print("="*50)
    print(f"Total checked : {len(project_names)}")
    print(f"Available     : {len(available)}")
    print(f"Taken         : {len(taken)}")

    if available:
        print("\n🎉 AVAILABLE PROJECT IDs:")
        for a in available:
            print(f"   • {a}")

    if not available:
        print("\n😢 No available project IDs found.")

if __name__ == "__main__":
    main()
