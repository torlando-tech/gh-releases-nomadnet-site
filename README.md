# GitHub Releases NomadNet Site

Host GitHub releases on your NomadNet node. Downloads release assets locally for offline distribution over Reticulum.

## Features

- Syncs releases from any GitHub repository
- Downloads assets (APKs, binaries, etc.) locally
- Dynamic NomadNet pages showing latest stable and pre-release
- Release history page with all versions
- Automatic sync via systemd timer
- Configurable for any project

## Requirements

- Python 3.8+
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- NomadNet installed and configured
- systemd (for automatic sync)

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/torlando-tech/gh-releases-nomadnet-site.git
   cd gh-releases-nomadnet-site
   ```

2. Edit `config.json` with your repository details:
   ```json
   {
     "app_name": "YourApp",
     "app_description": "Description of your application.",
     "github_repo": "owner/repo",
     "asset_pattern": "*.apk",
     "max_releases": 10
   }
   ```

3. (Optional) Add ASCII art to `ascii-art.txt`

4. Run the install script:
   ```bash
   ./install.sh
   ```

5. View your page in NomadNet at `:/page/index.mu`

## Configuration

Edit `config.json` to customize:

| Field | Description | Example |
|-------|-------------|---------|
| `app_name` | Display name for your app | `"Columba"` |
| `app_description` | Short description | `"A messaging app..."` |
| `github_repo` | GitHub repository | `"owner/repo"` |
| `asset_pattern` | Glob pattern for assets | `"*.apk"`, `"*.deb"`, `"*linux*"` |
| `max_releases` | Number of releases to track | `10` |
| `sync_interval_hours` | How often to sync | `6` |
| `ascii_art_file` | ASCII art filename | `"ascii-art.txt"` |
| `ascii_bg_color` | Background color for ASCII art (3-digit hex) | `"b6d"` (light purple) |
| `page_title` | Page title | `"My Downloads"` |

## Manual Usage

Run sync manually:
```bash
./sync.py
```

Check timer status:
```bash
systemctl --user status gh-releases-sync.timer
```

View sync logs:
```bash
journalctl --user -u gh-releases-sync.service
```

## File Structure

```
gh-releases-nomadnet-site/
├── config.json          # Your configuration
├── sync.py              # Sync script
├── install.sh           # Installation script
├── ascii-art.txt        # Optional ASCII art
├── pages/
│   ├── index.mu         # Home page (latest releases)
│   └── releases.mu      # All releases page
└── systemd/
    ├── gh-releases-sync.service
    └── gh-releases-sync.timer
```

After install, files are placed in:
- Pages: `~/.nomadnetwork/storage/pages/`
- Downloads: `~/.nomadnetwork/storage/files/`
- Data: `~/.nomadnetwork/data/releases.json`

## License

MIT
