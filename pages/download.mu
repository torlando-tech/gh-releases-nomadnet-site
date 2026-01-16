#!/usr/bin/env python3
"""
Download Proxy Page for NomadNet
Tracks download counts and provides the actual download link
"""
import json
import os
from datetime import datetime, timezone
from pathlib import Path

# Page header - no caching
print("#!c=0")

# Get the file parameter from environment (NomadNet prefixes link vars with "var_")
filename = os.environ.get("var_file", "")

# Data paths
data_dir = Path.home() / ".nomadnetwork" / "data"
counts_file = data_dir / "download_counts.json"
releases_file = data_dir / "releases.json"

# Load release data to get file info
release_data = None
try:
    if releases_file.exists():
        with open(releases_file) as f:
            release_data = json.load(f)
except Exception:
    release_data = None

# Get config
config = release_data.get("config", {}) if release_data else {}
app_name = config.get("app_name", "App")

# Find release info for this file
release_info = None
if release_data and filename:
    all_releases = release_data.get("all_releases", [])
    for release in all_releases:
        if release.get("asset_filename") == filename:
            release_info = release
            break


def format_size(size_bytes: int) -> str:
    """Format file size in human-readable form."""
    if size_bytes >= 1024 * 1024:
        return f"{size_bytes / 1024 / 1024:.1f} MB"
    return f"{size_bytes / 1024:.1f} KB"


def load_counts() -> dict:
    """Load download counts from file."""
    try:
        if counts_file.exists():
            with open(counts_file) as f:
                return json.load(f)
    except Exception:
        pass
    return {"counts": {}, "last_updated": None}


def save_counts(data: dict) -> None:
    """Save download counts to file."""
    try:
        data_dir.mkdir(parents=True, exist_ok=True)
        data["last_updated"] = datetime.now(timezone.utc).isoformat()
        with open(counts_file, "w") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass


def increment_count(filename: str) -> int:
    """Increment and return the download count for a file."""
    data = load_counts()
    counts = data.get("counts", {})
    counts[filename] = counts.get(filename, 0) + 1
    data["counts"] = counts
    save_counts(data)
    return counts[filename]


# Title
print(f">{app_name} Download")
print("")

if not filename:
    print("`Ff00Error: No file specified.`f")
    print("")
    print("`F0af`[Back to Downloads`:/page/index.mu]`f")
else:
    # Increment the counter
    count = increment_count(filename)

    if release_info:
        # Show release info
        name = release_info.get("name", filename)
        is_prerelease = release_info.get("is_prerelease", False)
        size = release_info.get("asset_size", 0)
        checksum = release_info.get("checksum", "")

        if is_prerelease:
            print(f"`*{name}`* (Pre-release)")
        else:
            print(f"`!{name}`!")
        print("")

        size_str = format_size(size) if size else "Unknown size"
        print(f"File: `!{filename}`!")
        print(f"Size: {size_str}")
        print(f"Page views: `!{count}`!")
        print("")

        if checksum:
            print(f"`F666SHA256: {checksum}`f")
            print("")

        print("-")
        print("")

        # Actual download link
        if is_prerelease:
            print(f"`Ff80`[Click to Download`:/file/{filename}]`f")
        else:
            print(f"`F0af`[Click to Download`:/file/{filename}]`f")
    else:
        # File not in releases, but still allow download
        print(f"File: `!{filename}`!")
        print(f"Page views: `!{count}`!")
        print("")
        print("-")
        print("")
        print(f"`F0af`[Click to Download`:/file/{filename}]`f")

    print("")
    print("-")
    print("")
    print("`F0af`[Back to Downloads`:/page/index.mu]`f")
    print("`F0af`[View All Releases`:/page/releases.mu]`f")
