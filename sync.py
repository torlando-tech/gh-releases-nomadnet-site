#!/usr/bin/env python3
"""
GitHub Release Sync Script for NomadNet
Fetches releases from a GitHub repository and downloads assets for NomadNet hosting.

Configuration is read from config.json in the same directory as this script,
or from the path specified in the NOMADNET_RELEASES_CONFIG environment variable.
"""

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Determine config file location
SCRIPT_DIR = Path(__file__).parent.resolve()
CONFIG_FILE = Path(__import__('os').environ.get(
    'NOMADNET_RELEASES_CONFIG',
    SCRIPT_DIR / 'config.json'
))

# NomadNet directories (relative to user's home)
DATA_DIR = Path.home() / ".nomadnetwork" / "data"
FILES_DIR = Path.home() / ".nomadnetwork" / "storage" / "files"
PAGES_DIR = Path.home() / ".nomadnetwork" / "storage" / "pages"


def load_config() -> dict:
    """Load configuration from JSON file."""
    if not CONFIG_FILE.exists():
        print(f"Error: Config file not found: {CONFIG_FILE}")
        sys.exit(1)

    with open(CONFIG_FILE) as f:
        return json.load(f)


def log(message: str):
    """Print timestamped log message."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")


def run_gh_command(args: list):
    """Run gh CLI command and return parsed JSON."""
    cmd = ["gh"] + args
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        if result.returncode != 0:
            log(f"Error running {' '.join(cmd)}: {result.stderr}")
            return None
        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        log(f"Timeout running {' '.join(cmd)}")
        return None
    except json.JSONDecodeError as e:
        log(f"Failed to parse JSON: {e}")
        return None


def get_releases(repo: str, limit: int) -> list:
    """Fetch all releases from GitHub."""
    log(f"Fetching releases from {repo}")
    releases = run_gh_command([
        "release", "list",
        "--repo", repo,
        "--json", "tagName,name,isPrerelease,publishedAt,isLatest",
        "--limit", str(limit * 2)
    ])
    return releases or []


def get_release_details(repo: str, tag: str):
    """Fetch detailed information for a specific release."""
    log(f"Fetching details for {tag}")
    return run_gh_command([
        "release", "view", tag,
        "--repo", repo,
        "--json", "tagName,name,body,isPrerelease,publishedAt,assets"
    ])


def find_matching_asset(assets: list, pattern: str):
    """Find asset matching the pattern (supports *.ext format)."""
    import fnmatch
    for asset in assets:
        name = asset.get("name", "")
        # Skip checksum files
        if name.endswith(".sha256") or name.endswith(".md5"):
            continue
        if fnmatch.fnmatch(name, pattern):
            return asset
    return None


def download_asset(repo: str, tag: str, asset: dict) -> bool:
    """Download asset if not already present."""
    filename = asset["name"]
    filepath = FILES_DIR / filename

    if filepath.exists():
        log(f"Asset already exists: {filename}")
        return True

    size_mb = asset['size'] / 1024 / 1024
    log(f"Downloading {filename} ({size_mb:.1f} MB)")

    try:
        result = subprocess.run(
            [
                "gh", "release", "download", tag,
                "--repo", repo,
                "--pattern", filename,
                "--dir", str(FILES_DIR)
            ],
            capture_output=True,
            text=True,
            timeout=600
        )
        if result.returncode != 0:
            log(f"Download failed: {result.stderr}")
            return False
        log(f"Successfully downloaded {filename}")
        return True
    except subprocess.TimeoutExpired:
        log(f"Download timed out for {filename}")
        return False


def extract_checksum_from_body(body: str, filename: str):
    """Extract checksum from release body."""
    import re
    # Look for SHA256 hash pattern followed by filename
    base_name = Path(filename).stem
    pattern = rf'([a-f0-9]{{64}})\s+.*{re.escape(base_name)}'
    match = re.search(pattern, body, re.IGNORECASE)
    if match:
        return match.group(1)
    return None


def update_latest_symlink(app_name: str, stable_filename: str):
    """Update the latest symlink."""
    symlink_name = f"{app_name.lower()}-latest{Path(stable_filename).suffix}"
    symlink_path = FILES_DIR / symlink_name

    if symlink_path.is_symlink() or symlink_path.exists():
        symlink_path.unlink()

    target_path = FILES_DIR / stable_filename
    if target_path.exists():
        symlink_path.symlink_to(stable_filename)
        log(f"Updated symlink: {symlink_name} -> {stable_filename}")


def install_files(config: dict):
    """Install pages and assets to NomadNet directories."""
    import shutil

    # Copy pages from pages/ directory
    pages_src = SCRIPT_DIR / "pages"
    if pages_src.exists():
        for page_file in pages_src.iterdir():
            if page_file.is_file():
                dst = PAGES_DIR / page_file.name
                shutil.copy(page_file, dst)
                # Make .mu files executable
                if page_file.suffix == ".mu":
                    dst.chmod(0o755)
                log(f"Installed {page_file.name}")

    # Copy ASCII art if configured
    if config.get("ascii_art_file"):
        src = SCRIPT_DIR / config["ascii_art_file"]
        dst = PAGES_DIR / "ascii-art.txt"
        if src.exists():
            shutil.copy(src, dst)
            log(f"Installed ASCII art to {dst}")


def main():
    """Main sync function."""
    config = load_config()

    repo = config["github_repo"]
    app_name = config["app_name"]
    asset_pattern = config.get("asset_pattern", "*")
    max_releases = config.get("max_releases", 10)

    log(f"Starting {app_name} release sync")

    # Ensure directories exist
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    FILES_DIR.mkdir(parents=True, exist_ok=True)
    PAGES_DIR.mkdir(parents=True, exist_ok=True)

    # Install static files
    install_files(config)

    # Fetch release list
    releases = get_releases(repo, max_releases)
    if not releases:
        log("Failed to fetch releases, aborting")
        sys.exit(1)

    # Identify latest stable and pre-release
    latest_stable_tag = None
    latest_prerelease_tag = None

    for release in releases:
        if release.get("isLatest"):
            latest_stable_tag = release["tagName"]
        elif release.get("isPrerelease") and not latest_prerelease_tag:
            latest_prerelease_tag = release["tagName"]

    if not latest_stable_tag:
        for release in releases:
            if not release.get("isPrerelease"):
                latest_stable_tag = release["tagName"]
                break

    log(f"Latest stable: {latest_stable_tag}")
    log(f"Latest prerelease: {latest_prerelease_tag}")

    # Build release data
    data = {
        "config": {
            "app_name": app_name,
            "app_description": config.get("app_description", ""),
            "page_title": config.get("page_title", f"{app_name} Downloads"),
            "ascii_art_file": "ascii-art.txt" if config.get("ascii_art_file") else None,
            "ascii_bg_color": config.get("ascii_bg_color")
        },
        "last_sync": datetime.now(timezone.utc).isoformat(),
        "latest_stable": None,
        "latest_prerelease": None,
        "all_releases": []
    }

    # Process latest stable
    if latest_stable_tag:
        details = get_release_details(repo, latest_stable_tag)
        if details:
            asset = find_matching_asset(details.get("assets", []), asset_pattern)
            if asset and download_asset(repo, latest_stable_tag, asset):
                data["latest_stable"] = {
                    "tag": details["tagName"],
                    "name": details["name"],
                    "published_at": details["publishedAt"],
                    "body": details["body"],
                    "asset_filename": asset["name"],
                    "asset_size": asset["size"],
                    "checksum": extract_checksum_from_body(details["body"], asset["name"])
                }
                update_latest_symlink(app_name, asset["name"])

    # Process latest pre-release
    if latest_prerelease_tag and latest_prerelease_tag != latest_stable_tag:
        details = get_release_details(repo, latest_prerelease_tag)
        if details:
            asset = find_matching_asset(details.get("assets", []), asset_pattern)
            if asset and download_asset(repo, latest_prerelease_tag, asset):
                data["latest_prerelease"] = {
                    "tag": details["tagName"],
                    "name": details["name"],
                    "published_at": details["publishedAt"],
                    "body": details["body"],
                    "asset_filename": asset["name"],
                    "asset_size": asset["size"],
                    "checksum": extract_checksum_from_body(details["body"], asset["name"])
                }

    # Build all releases list
    for release in releases[:max_releases]:
        details = get_release_details(repo, release["tagName"])
        if not details:
            continue

        asset = find_matching_asset(details.get("assets", []), asset_pattern)
        if asset:
            download_asset(repo, release["tagName"], asset)

            data["all_releases"].append({
                "tag": details["tagName"],
                "name": details["name"],
                "is_prerelease": details["isPrerelease"],
                "published_at": details["publishedAt"],
                "body": details["body"],
                "asset_filename": asset["name"],
                "asset_size": asset["size"],
                "checksum": extract_checksum_from_body(details["body"], asset["name"])
            })

    # Write JSON data
    releases_json = DATA_DIR / "releases.json"
    with open(releases_json, 'w') as f:
        json.dump(data, f, indent=2)
    log(f"Wrote release data to {releases_json}")

    log("Sync complete")


if __name__ == "__main__":
    main()
