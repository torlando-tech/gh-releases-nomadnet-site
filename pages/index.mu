#!/usr/bin/env python3
"""
GitHub Releases Home Page for NomadNet
Dynamic page showing latest releases - reads config from releases.json
"""
import json
import os
from datetime import datetime
from pathlib import Path

# Page header - no caching for fresh data
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
app_description = config.get("app_description", "")
page_title = config.get("page_title", f"{app_name} Downloads")
ascii_art_file = config.get("ascii_art_file")
ascii_bg_color = config.get("ascii_bg_color")  # e.g. "b6d" for light purple

# Title
print(f">{page_title}")
print("")

# ASCII art header
if ascii_art_file:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ascii_path = os.path.join(script_dir, ascii_art_file)
    if os.path.exists(ascii_path):
        with open(ascii_path) as f:
            lines = f.read().splitlines()
            # Strip empty lines from top and bottom
            while lines and not lines[0].strip():
                lines.pop(0)
            while lines and not lines[-1].strip():
                lines.pop()
            # Find max width and pad all lines to make a square
            max_width = max(len(line) for line in lines) if lines else 0
            # Print each line with background color (reset at end of each line for square effect)
            for line in lines:
                padded = line.ljust(max_width)
                if ascii_bg_color:
                    print(f"`B{ascii_bg_color}{padded}`b")
                else:
                    print(padded)
        print("")

print(f"`!{app_name}`!")
print("")
if app_description:
    print(app_description)
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
    print("-")
    print("")
    print("`Ff00Error: Release data not available.`f")
    print("Run the sync script to fetch release information.")
else:
    # Latest Stable Release
    print("-")
    print("")
    stable = data.get("latest_stable")
    if stable:
        print(">>Latest Stable Release")
        print("")
        print(f"`!{stable['name']}`!")
        print(f"`F888Released: {format_date(stable['published_at'])}`f")
        print("")

        labels = variant_labels(get_assets(stable))
        for asset in get_assets(stable):
            asset_link(asset["filename"], labels.get(asset["filename"], ""), asset["size"],
                       get_download_count(asset["filename"]), "0af", "Download")
        print("")

        body = stable.get('body_micron') or stable.get('body', '')
        if body:
            print("`!Release Notes:`!")
            print("")
            for line in body.split('\n'):
                print(line)
            print("")
    else:
        print("No stable release available.")
        print("")

    # Latest Pre-release
    prerelease = data.get("latest_prerelease")
    if prerelease:
        print("-")
        print("")
        print(">>Latest Pre-release")
        print("")
        print(f"`*{prerelease['name']}`*")
        print(f"`F888Released: {format_date(prerelease['published_at'])}`f")
        print("")

        labels = variant_labels(get_assets(prerelease))
        for asset in get_assets(prerelease):
            asset_link(asset["filename"], labels.get(asset["filename"], ""), asset["size"],
                       get_download_count(asset["filename"]), "f80", "Download Beta")
        print("")

        body = prerelease.get('body_micron') or prerelease.get('body', '')
        if body:
            print("`!Release Notes:`!")
            print("")
            for line in body.split('\n'):
                print(line)
            print("")

    # Navigation
    print("-")
    print("")
    print("`F0af`[View All Releases`:/page/releases.mu]`f")
    print("")

    # Footer
    print("-")
    print("")
    last_sync = data.get("last_sync", "Unknown")
    print(f"`F666Last synced: {format_date(last_sync)}`f")
