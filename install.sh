#!/bin/bash

set -e

REPO="Maraoui21/simpleLogin_releases"
INSTALL_DIR="/opt/SimpleLogin"
APP_DIR="$INSTALL_DIR/app"
DATA_DIR="$INSTALL_DIR/data"
VENV_DIR="$INSTALL_DIR/venv"
VERSION_FILE="$INSTALL_DIR/.version"

# ── Helpers ───────────────────────────────────────────────────────────────────

get_latest_version() {
    curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep '"tag_name"' \
        | sed 's/.*"tag_name": *"\(.*\)".*/\1/'
}

get_installed_version() {
    [ -f "$VERSION_FILE" ] && cat "$VERSION_FILE" || echo "none"
}

install_system_deps() {
    echo "[+] Installing system dependencies..."
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv python3-dev \
        python3-gi python3-gi-cairo \
        libgtk-3-0 libglib2.0-0 \
        unzip curl

    # WebKitGTK — 4.1 on Ubuntu 22.04+, 4.0 on older
    if apt-cache show libwebkit2gtk-4.1-0 2>/dev/null | grep -q "^Package:"; then
        apt-get install -y --no-install-recommends \
            gir1.2-webkit2-4.1 libwebkit2gtk-4.1-0
    else
        apt-get install -y --no-install-recommends \
            gir1.2-webkit2-4.0 libwebkit2gtk-4.0-37
    fi
    echo "[✓] System dependencies installed"
}

download_and_install() {
    local version=$1
    local url="https://github.com/$REPO/releases/download/$version/SimpleLogin-linux.zip"

    echo "[+] Downloading SimpleLogin $version..."
    curl -fsSL "$url" -o /tmp/SimpleLogin-linux.zip

    echo "[+] Extracting..."
    rm -rf /tmp/SimpleLogin-extract && mkdir -p /tmp/SimpleLogin-extract
    unzip -q /tmp/SimpleLogin-linux.zip -d /tmp/SimpleLogin-extract

    inner=$(find /tmp/SimpleLogin-extract -name "main.py" -type f | head -1)
    inner_dir=$(dirname "$inner")

    rm -rf "$APP_DIR"
    mkdir -p "$DATA_DIR"
    mv "$inner_dir" "$APP_DIR"
    rm -rf /tmp/SimpleLogin-extract /tmp/SimpleLogin-linux.zip

    echo "[+] Setting up Python environment..."
    # --system-site-packages so pywebview can use the system gi/GTK bindings
    python3 -m venv --system-site-packages "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    "$VENV_DIR/bin/pip" install --quiet -r "$APP_DIR/requirements.txt"

    echo "$version" > "$VERSION_FILE"
    echo "[✓] SimpleLogin $version installed"
}

create_launcher() {
    cat > /usr/local/bin/simplelogin <<EOF
#!/bin/bash
export SIMPLELOGIN_DATA=$DATA_DIR
cd $APP_DIR
exec $VENV_DIR/bin/python main.py "\$@"
EOF
    chmod +x /usr/local/bin/simplelogin
    echo "[✓] Launcher created — run with: simplelogin"
}

create_desktop_entry() {
    local icon="$APP_DIR/static/icon.svg"
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
    install_system_deps
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
    pkill -f "python.*main.py" 2>/dev/null || true
    download_and_install "$latest"
    echo "[✓] Update complete — run with: simplelogin"
}

cmd_remove() {
    echo "=== SimpleLogin Uninstaller ==="
    pkill -f "python.*main.py" 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/simplelogin
    rm -f /usr/share/applications/simplelogin.desktop
    update-desktop-database /usr/share/applications 2>/dev/null || true
    echo "[✓] SimpleLogin removed"
}

# ── Entry point ───────────────────────────────────────────────────────────────

case "${1:-install}" in
    install) cmd_install ;;
    update)  cmd_update  ;;
    remove)  cmd_remove  ;;
    *)
        echo "Usage: $0 [install|update|remove]"
        exit 1
        ;;
esac