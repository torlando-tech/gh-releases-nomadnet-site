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

def get_assets(release: dict) -> list:
    """Asset list for a release; compatible with the old single-asset schema."""
    assets = release.get("assets")
    if assets:
        return assets
    if release.get("asset_filename"):
        return [{
            "filename": release["asset_filename"],
            "size": release.get("asset_size", 0),
            "checksum": release.get("checksum")
        }]
    return []


def variant_labels(assets: list) -> dict:
    """Short display label per asset: filename minus the prefix and suffix
    shared by all assets of the release (e.g. 'official-rns-py-arm64-v8a')."""
    names = [a["filename"] for a in assets]
    labels = {}
    if len(names) <= 1:
        return {n: "" for n in names}
    pref = names[0]
    for n in names[1:]:
        while pref and not n.startswith(pref):
            pref = pref[:-1]
    suff = names[0]
    for n in names[1:]:
        while suff and not n.endswith(suff):
            suff = suff[1:]
    for n in names:
        if len(n) > len(pref) + len(suff):
            mid = n[len(pref):len(n) - len(suff)]
        else:
            mid = ""
        labels[n] = mid if mid else n
    return labels


def asset_link(filename: str, label: str, size: int, count: int, color: str, verb: str) -> None:
    """Print a download link line for one asset."""
    size_str = format_size(size)
    text = f"{verb} {label} ({size_str})" if label else f"{verb} ({size_str})"
    print(f"`F{color}`[{text}`:/page/download.mu`file={filename}]`f  `F888({count} views)`f")

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
                assets = get_assets(release)
                labels = variant_labels(assets)
                for asset in assets:
                    asset_link(asset["filename"], labels.get(asset["filename"], ""), asset["size"],
                               get_download_count(asset["filename"]), "0af", "Download")

                if release.get('body'):
                    print("")
                    for line in release['body'].split('\n'):
                        print(line)
                print("")
                print("-")
                print("")

        # Pre-releases
        if prereleases:
            if stable_releases:
                print("-")
                print("")
            print(">>Pre-releases")
            print("")

            for release in prereleases:
                name = release['name']
                date_str = format_date(release['published_at'])
                assets = get_assets(release)
                labels = variant_labels(assets)
                for asset in assets:
                    asset_link(asset["filename"], labels.get(asset["filename"], ""), asset["size"],
                               get_download_count(asset["filename"]), "f80", "Download")

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
