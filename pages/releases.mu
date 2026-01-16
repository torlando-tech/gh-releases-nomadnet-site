#!/usr/bin/env python3
"""
All Releases Page for NomadNet
Dynamic page showing release history - reads config from releases.json
"""
import json
from datetime import datetime
from pathlib import Path

# Page header
print("#!c=0")

# Read release data (includes config)
data_file = Path.home() / ".nomadnetwork" / "data" / "releases.json"
data = None

try:
    if data_file.exists():
        with open(data_file) as f:
            data = json.load(f)
except Exception:
    data = None

# Get config from data or use defaults
if data:
    config = data.get("config", {})
else:
    config = {}

app_name = config.get("app_name", "App")

# Title
print(f">{app_name} Release History")
print("")

# Navigation
print("`F0af`[Back to Downloads`:/page/index.mu]`f")
print("")
print("-")
print("")


def format_size(size_bytes: int) -> str:
    """Format file size in human-readable form."""
    if size_bytes >= 1024 * 1024:
        return f"{size_bytes / 1024 / 1024:.1f} MB"
    return f"{size_bytes / 1024:.1f} KB"


def format_date(iso_date: str) -> str:
    """Format ISO date to readable form."""
    try:
        dt = datetime.fromisoformat(iso_date.replace('Z', '+00:00'))
        return dt.strftime("%Y-%m-%d")
    except Exception:
        return iso_date[:10] if iso_date else "Unknown"


def get_download_count(filename: str) -> int:
    """Get download count for a file."""
    counts_file = Path.home() / ".nomadnetwork" / "data" / "download_counts.json"
    try:
        if counts_file.exists():
            with open(counts_file) as f:
                counts_data = json.load(f)
                return counts_data.get("counts", {}).get(filename, 0)
    except Exception:
        pass
    return 0


if data is None:
    print("`Ff00Error: Release data not available.`f")
else:
    releases = data.get("all_releases", [])

    if not releases:
        print("No releases found.")
    else:
        # Separate stable and pre-releases
        stable_releases = [r for r in releases if not r.get("is_prerelease")]
        prereleases = [r for r in releases if r.get("is_prerelease")]

        # Stable releases
        if stable_releases:
            print(">>Stable Releases")
            print("")

            for release in stable_releases:
                name = release['name']
                date_str = format_date(release['published_at'])
                size_str = format_size(release['asset_size'])

                print(f"`!{name}`! - {date_str}")
                dl_count = get_download_count(release['asset_filename'])
                print(f"  `F0af`[Download ({size_str})`:/page/download.mu`file={release['asset_filename']}]`f  `F888({dl_count} views)`f")

                if release.get('checksum'):
                    print(f"  `F666SHA256: {release['checksum']}`f")

                if release.get('body'):
                    print("")
                    for line in release['body'].split('\n'):
                        print(line)
                print("")
                print("-")
                print("")

        # Pre-releases
        if prereleases:
            print("-")
            print("")
            print(">>Pre-releases")
            print("")

            for release in prereleases:
                name = release['name']
                date_str = format_date(release['published_at'])
                size_str = format_size(release['asset_size'])

                print(f"`*{name}`* - {date_str}")
                dl_count = get_download_count(release['asset_filename'])
                print(f"  `Ff80`[Download ({size_str})`:/page/download.mu`file={release['asset_filename']}]`f  `F888({dl_count} views)`f")

                if release.get('checksum'):
                    print(f"  `F666SHA256: {release['checksum']}`f")

                if release.get('body'):
                    print("")
                    for line in release['body'].split('\n'):
                        print(line)
                print("")
                print("-")
                print("")

print("-")
print("")

# Footer
if data:
    last_sync = data.get("last_sync", "Unknown")
    total = len(data.get("all_releases", []))
    print(f"`F666{total} releases | Last synced: {format_date(last_sync)}`f")
