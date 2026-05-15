#!/bin/bash

set -e

REPO="Maraoui21/simpleLogin_releases"
INSTALL_DIR="/opt/SimpleLogin"
VERSION_FILE="$INSTALL_DIR/.version"
BINARY="$INSTALL_DIR/SimpleLogin"

# ── Helpers ───────────────────────────────────────────────────────────────────

get_latest_version() {
    curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep '"tag_name"' \
        | sed 's/.*"tag_name": *"\(.*\)".*/\1/'
}

get_installed_version() {
    [ -f "$VERSION_FILE" ] && cat "$VERSION_FILE" || echo "none"
}

install_chrome() {
    if command -v google-chrome &>/dev/null || command -v chromium-browser &>/dev/null || command -v chromium &>/dev/null; then
        echo "[✓] Chrome/Chromium already installed"
        return
    fi
    echo "[+] Installing Google Chrome..."
    curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
    apt-get install -y /tmp/chrome.deb 2>/dev/null || dpkg -i /tmp/chrome.deb && apt-get -f install -y
    rm -f /tmp/chrome.deb
    echo "[✓] Chrome installed"
}

download_and_install() {
    local version=$1
    local url="https://github.com/$REPO/releases/download/$version/SimpleLogin-linux.zip"

    echo "[+] Downloading SimpleLogin $version..."
    curl -fsSL "$url" -o /tmp/SimpleLogin-linux.zip

    echo "[+] Installing to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    unzip -q /tmp/SimpleLogin-linux.zip -d "$INSTALL_DIR"

    # flatten any nested dist/SimpleLogin structure
    if [ ! -f "$BINARY" ]; then
        inner=$(find "$INSTALL_DIR" -name "SimpleLogin" -type f | head -1)
        if [ -n "$inner" ]; then
            inner_dir=$(dirname "$inner")
            if [ "$inner_dir" != "$INSTALL_DIR" ]; then
                mv "$inner_dir"/* "$INSTALL_DIR/"
                rm -rf "$INSTALL_DIR/dist" 2>/dev/null || true
            fi
        fi
    fi

    chmod +x "$BINARY"
    echo "$version" > "$VERSION_FILE"
    rm -f /tmp/SimpleLogin-linux.zip
    echo "[✓] SimpleLogin $version installed"
}

create_launcher() {
    cat > /usr/local/bin/simplelogin <<'EOF'
#!/bin/bash
cd /opt/SimpleLogin
./SimpleLogin "$@"
EOF
    chmod +x /usr/local/bin/simplelogin
    echo "[✓] Launcher created — run with: simplelogin"
}

create_desktop_entry() {
    local icon="$INSTALL_DIR/_internal/static/icon.svg"
    [ ! -f "$icon" ] && icon="application-x-executable"

    cat > /usr/share/applications/simplelogin.desktop <<EOF
[Desktop Entry]
Name=SimpleLogin
Comment=Facebook Groups Automation
Exec=/usr/local/bin/simplelogin
Icon=$icon
Type=Application
Categories=Utility;Network;
StartupNotify=true
Terminal=false
EOF

    update-desktop-database /usr/share/applications 2>/dev/null || true
    echo "[✓] Desktop shortcut created"
}

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_install() {
    echo "=== SimpleLogin Installer ==="
    install_chrome
    local latest
    latest=$(get_latest_version)
    echo "[i] Latest version: $latest"
    download_and_install "$latest"
    create_launcher
    create_desktop_entry
    echo ""
    echo "Done! Run the app with: simplelogin"
}

cmd_update() {
    echo "=== SimpleLogin Updater ==="
    local latest installed
    latest=$(get_latest_version)
    installed=$(get_installed_version)
    echo "[i] Installed: $installed"
    echo "[i] Latest:    $latest"
    if [ "$latest" = "$installed" ]; then
        echo "[✓] Already up to date"
        exit 0
    fi
    echo "[+] Updating $installed → $latest..."
    download_and_install "$latest"
    echo "[✓] Update complete"
}

# ── Entry point ───────────────────────────────────────────────────────────────

case "${1:-install}" in
    install) cmd_install ;;
    update)  cmd_update ;;
    *)
        echo "Usage: $0 [install|update]"
        exit 1
        ;;
esac
