#!/bin/bash
# Install script for gh-releases-nomadnet-site
# Sets up NomadNet pages and systemd timer for automatic syncing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOMADNET_PAGES="$HOME/.nomadnetwork/storage/pages"
SYSTEMD_USER="$HOME/.config/systemd/user"

echo "Installing gh-releases-nomadnet-site..."

# Create directories
mkdir -p "$HOME/.nomadnetwork/data"
mkdir -p "$NOMADNET_PAGES"
mkdir -p "$SYSTEMD_USER"

# Copy pages
echo "Installing pages to $NOMADNET_PAGES..."
cp "$SCRIPT_DIR/pages/index.mu" "$NOMADNET_PAGES/"
cp "$SCRIPT_DIR/pages/releases.mu" "$NOMADNET_PAGES/"
chmod +x "$NOMADNET_PAGES/index.mu"
chmod +x "$NOMADNET_PAGES/releases.mu"

# Copy ASCII art if present
if [ -f "$SCRIPT_DIR/ascii-art.txt" ]; then
    cp "$SCRIPT_DIR/ascii-art.txt" "$NOMADNET_PAGES/"
fi

# Install systemd units
echo "Installing systemd units..."
sed "s|%h/repos/gh-releases-nomadnet-site|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/systemd/gh-releases-sync.service" > "$SYSTEMD_USER/gh-releases-sync.service"
cp "$SCRIPT_DIR/systemd/gh-releases-sync.timer" "$SYSTEMD_USER/"

# Reload and enable timer
echo "Enabling systemd timer..."
systemctl --user daemon-reload
systemctl --user enable gh-releases-sync.timer
systemctl --user start gh-releases-sync.timer

# Run initial sync
echo "Running initial sync..."
python3 "$SCRIPT_DIR/sync.py"

echo ""
echo "Installation complete!"
echo ""
echo "Pages installed:"
echo "  - $NOMADNET_PAGES/index.mu"
echo "  - $NOMADNET_PAGES/releases.mu"
echo ""
echo "Timer status:"
systemctl --user status gh-releases-sync.timer --no-pager || true
echo ""
echo "View your page in NomadNet at: :/page/index.mu"
