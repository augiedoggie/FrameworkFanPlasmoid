#!/usr/bin/env bash
# install.sh — installs the Framework Fan Control Plasma widget
set -euo pipefail

WIDGET_ID="org.kde.fwfanctrl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_DIR="$SCRIPT_DIR/$WIDGET_ID"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"

echo "=== Framework Fan Control — Plasma 6 Widget Installer ==="
echo ""

# ── Sanity checks ──────────────────────────────────────────────────────────
if ! command -v fw-fanctrl &>/dev/null; then
    echo "⚠  WARNING: 'fw-fanctrl' was not found in PATH."
    echo "   Install it from: https://github.com/FrameworkComputer/fw-fanctrl"
    echo "   The widget will not work until fw-fanctrl is available."
    echo ""
fi

if [[ ! -d "$WIDGET_DIR" ]]; then
    echo "ERROR: Widget source directory not found: $WIDGET_DIR"
    exit 1
fi

# ── Install ────────────────────────────────────────────────────────────────
echo "Installing widget to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$WIDGET_DIR"/. "$INSTALL_DIR/"

# ── Install icon into the user icon theme ──────────────────────────────────
ICON_SRC="$WIDGET_DIR/contents/icons/framework.svg"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
echo "Installing icon to: $ICON_DIR"
mkdir -p "$ICON_DIR"
cp "$ICON_SRC" "$ICON_DIR/framework.svg"

# Rebuild the icon cache and KDE's service cache so Plasma sees the new icon
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &>/dev/null || true
fi
if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 &>/dev/null || true
fi

echo ""
echo "✔ Widget installed successfully."
echo ""

# ── Reload Plasma ─────────────────────────────────────────────────────────
if command -v plasmashell &>/dev/null; then
    echo "Reloading Plasma shell to pick up the new widget…"
    # kquitapp6 gracefully restarts plasmashell
    if command -v kquitapp6 &>/dev/null; then
        kquitapp6 plasmashell && kstart plasmashell &
    else
        plasmashell --replace &>/dev/null &
    fi
    echo "✔ Plasma shell reloaded."
else
    echo "ℹ  Could not auto-reload Plasma. Please log out and back in,"
    echo "   or run:  plasmashell --replace &"
fi

echo ""
echo "=== How to add the widget to your system tray ==="
echo "  1. Right-click the system tray (bottom-right panel area)."
echo "  2. Choose 'Configure System Tray…'."
echo "  3. Go to the 'Entries' tab."
echo "  4. Enable 'Framework Fan Control' in the list."
echo ""
