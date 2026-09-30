#!/usr/bin/env bash
# Install (or update) hlabtop from the latest release on GitHub.
#
#   curl -fsSL https://raw.githubusercontent.com/RVP-Techworks/hlabtop/main/install.sh | bash
#
# Uses the Flatpak when flatpak is installed, otherwise the single-file binary in
# ~/.local/bin plus an app-menu entry. Options (after `bash -s --` when piped):
#   --flatpak     install the Flatpak
#   --binary      install the single-file binary
#   --uninstall   remove whichever of them is installed
# Nothing is installed system-wide and no sudo is needed.
set -euo pipefail

REPO="RVP-Techworks/hlabtop"
APP_ID="io.github.RVP_Techworks.hlabtop"
API="${HLABTOP_API:-https://api.github.com/repos/$REPO/releases/latest}"
RAW="${HLABTOP_RAW:-https://raw.githubusercontent.com/$REPO/main}"
BIN_DIR="$HOME/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { printf 'hlabtop install: %s\n' "$*" >&2; exit 1; }

fetch() {  # fetch URL [OUTPUT]
    if command -v curl >/dev/null; then
        if [ $# -eq 2 ]; then curl -fL --progress-bar -o "$2" "$1"; else curl -fsSL "$1"; fi
    elif command -v wget >/dev/null; then
        if [ $# -eq 2 ]; then wget -q --show-progress -O "$2" "$1"; else wget -qO- "$1"; fi
    else
        die "needs curl or wget"
    fi
}

uninstall() {
    local removed=""
    if command -v flatpak >/dev/null && flatpak info --user "$APP_ID" >/dev/null 2>&1; then
        flatpak uninstall --user -y --noninteractive "$APP_ID" && removed=1
    fi
    if [ -e "$BIN_DIR/hlabtop" ]; then
        rm -f "$BIN_DIR/hlabtop" "$DATA_DIR/applications/hlabtop.desktop" \
            "$DATA_DIR/icons/hicolor/256x256/apps/hlabtop.png"
        removed=1
    fi
    if [ -n "$removed" ]; then
        say "hlabtop removed. (Saved connections and workspaces in ~/.config/hlabtop are kept.)"
    else
        say "hlabtop isn't installed (by this script)."
    fi
}

mode=""
for arg in "$@"; do
    case "$arg" in
        --flatpak) mode=flatpak ;;
        --binary) mode=binary ;;
        --uninstall) uninstall; exit 0 ;;
        -h|--help) sed -n '2,11p' "$0" 2>/dev/null || true; exit 0 ;;
        *) die "unknown option: $arg" ;;
    esac
done

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) ;;
    Linux-*) die "the downloads are for x86_64 PCs; $(uname -m) (e.g. a Raspberry Pi) isn't supported yet" ;;
    *) die "this installs the Linux version; for Windows and macOS, download from https://github.com/$REPO/releases/latest" ;;
esac

if [ -z "$mode" ]; then
    if command -v flatpak >/dev/null; then mode=flatpak; else mode=binary; fi
fi

say "Finding the latest hlabtop release..."
release="$(fetch "$API")" || die "couldn't reach GitHub ($API)"
version="$(printf '%s' "$release" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"\(v[^"]*\)"/\1/')"
asset() { printf '%s' "$release" | grep -o "\"browser_download_url\": *\"[^\"]*$1\"" | head -1 | sed 's/.*"\(http[^"]*\)"/\1/'; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [ "$mode" = flatpak ]; then
    command -v flatpak >/dev/null || die "flatpak isn't installed; run with --binary instead"
    url="$(asset 'x86_64\.flatpak')"
    [ -n "$url" ] || die "no Flatpak in release ${version:-?}"
    say "Downloading hlabtop ${version} (Flatpak)..."
    fetch "$url" "$tmp/hlabtop.flatpak"
    # The runtime it needs comes from Flathub.
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    # A bundle can't be installed over itself: remove the old one first (its saved
    # connections and workspaces live in ~/.config/hlabtop, so they're kept).
    if flatpak info --user "$APP_ID" >/dev/null 2>&1; then
        flatpak uninstall --user -y --noninteractive "$APP_ID" >/dev/null
    fi
    flatpak install --user -y --noninteractive "$tmp/hlabtop.flatpak"
    say "Installed hlabtop ${version}. Open it from your app menu, or run: flatpak run $APP_ID"
else
    url="$(asset 'linux-x86_64')"
    [ -n "$url" ] || die "no Linux binary in release ${version:-?}"
    say "Downloading hlabtop ${version}..."
    fetch "$url" "$tmp/hlabtop"
    mkdir -p "$BIN_DIR" "$DATA_DIR/applications" "$DATA_DIR/icons/hicolor/256x256/apps"
    install -m 755 "$tmp/hlabtop" "$BIN_DIR/hlabtop"
    fetch "$RAW/icon.png" "$DATA_DIR/icons/hicolor/256x256/apps/hlabtop.png" 2>/dev/null || true
    cat > "$DATA_DIR/applications/hlabtop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=hlabtop
GenericName=Remote system monitor
Comment=htop, GPU and system graphs from remote machines over SSH
Exec=$BIN_DIR/hlabtop
Icon=hlabtop
Terminal=false
Categories=System;Monitor;
StartupWMClass=Hlabtop
EOF
    command -v update-desktop-database >/dev/null && update-desktop-database -q "$DATA_DIR/applications" || true
    say "Installed hlabtop ${version} to $BIN_DIR/hlabtop, with an app-menu entry."
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) echo "To run it by name from a terminal, add $BIN_DIR to your PATH." ;;
    esac
fi
echo "Run this again any time to update; add --uninstall to remove it."
