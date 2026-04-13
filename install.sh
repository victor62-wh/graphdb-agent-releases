#!/bin/bash
# Install or upgrade graphdb-agent binary.
#
# Supports two sources:
#   1. Local dist/ directory (auto-detected if running from repo root)
#   2. GitHub Releases (remote download)
#
# Usage:
#   # From repo root (uses local dist/ binaries):
#   ./install.sh
#   ./install.sh --version v0.2.0
#
#   # Remote install (from any machine):
#   curl -fsSL https://raw.githubusercontent.com/victor62-wh/graphdb-agent-releases/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --version v0.3.0 --dir /opt/bin
#
# Options:
#   --version VERSION   Specific version (default: latest from dist/ or GitHub)
#   --dir DIR           Install directory (default: /usr/local/bin)
#   --force             Force reinstall even if same version

set -e

REPO="victor62-wh/graphdb-agent-releases"
BINARY_NAME="graphdb-agent"
INSTALL_DIR="/usr/local/bin"
VERSION=""
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --dir)     INSTALL_DIR="$2"; shift 2 ;;
        --force)   FORCE=true; shift ;;
        *)         echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Detect OS and architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Error: unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "Platform: ${OS}/${ARCH}"

# ── Check existing installation ──────────────────────────────────

CURRENT_VERSION=""
TARGET="${INSTALL_DIR}/${BINARY_NAME}"
if [ -x "$TARGET" ]; then
    CURRENT_VERSION=$("$TARGET" -version 2>/dev/null || echo "unknown")
    echo "Current: ${BINARY_NAME} ${CURRENT_VERSION} (${TARGET})"
else
    echo "Current: not installed"
fi

# ── Determine source: local dist/ or GitHub ──────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null || echo ".")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
SOURCE="remote"

# Check if local dist/ has matching binaries
if [ -d "$DIST_DIR" ]; then
    LOCAL_BINS=$(ls "$DIST_DIR"/${BINARY_NAME}-*-${OS}-${ARCH} 2>/dev/null | sort -V)
    if [ -n "$LOCAL_BINS" ]; then
        SOURCE="local"
    fi
fi

# ── Resolve version ──────────────────────────────────────────────

if [ "$SOURCE" = "local" ]; then
    if [ -z "$VERSION" ]; then
        # Pick the latest version from dist/
        LATEST_BIN=$(echo "$LOCAL_BINS" | tail -1)
        VERSION=$(basename "$LATEST_BIN" | sed "s/${BINARY_NAME}-//; s/-${OS}-${ARCH}//")
    fi
    SRC_FILE="${DIST_DIR}/${BINARY_NAME}-${VERSION}-${OS}-${ARCH}"
    if [ ! -f "$SRC_FILE" ]; then
        echo "Error: ${SRC_FILE} not found in dist/"
        echo "Available:"
        ls "$DIST_DIR"/${BINARY_NAME}-*-${OS}-${ARCH} 2>/dev/null || echo "  (none)"
        exit 1
    fi
    echo "Source:  local dist/ (${SRC_FILE})"
else
    # Remote: resolve version from GitHub
    if [ -z "$VERSION" ]; then
        echo "Fetching latest version from GitHub..."
        VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' | head -1 | cut -d'"' -f4)
        if [ -z "$VERSION" ]; then
            echo "Error: could not determine latest version from GitHub."
            echo "Specify manually: install.sh --version v0.2.0"
            exit 1
        fi
    fi
    echo "Source:  GitHub Releases (${REPO})"
fi

echo "Version: ${VERSION}"

# ── Skip if same version (unless --force) ────────────────────────

if [ "$CURRENT_VERSION" = "$BINARY_NAME $VERSION" ] && [ "$FORCE" != true ]; then
    echo ""
    echo "Already up to date (${VERSION}). Use --force to reinstall."
    exit 0
fi

if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "unknown" ]; then
    echo "Action:  upgrade ${CURRENT_VERSION} -> ${VERSION}"
else
    echo "Action:  install ${VERSION}"
fi

# ── Obtain binary ────────────────────────────────────────────────

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

if [ "$SOURCE" = "local" ]; then
    cp "$SRC_FILE" "$TMPFILE"
else
    FILENAME="${BINARY_NAME}-${VERSION}-${OS}-${ARCH}"
    URL="https://github.com/${REPO}/releases/download/${VERSION}/${FILENAME}"
    echo ""
    echo "Downloading ${URL} ..."
    if ! curl -fSL -o "$TMPFILE" "$URL"; then
        echo ""
        echo "Error: download failed."
        echo "Check that version '${VERSION}' exists at:"
        echo "  https://github.com/${REPO}/releases"
        exit 1
    fi
fi

chmod +x "$TMPFILE"

# ── Verify the new binary works ──────────────────────────────────

NEW_VERSION=$("$TMPFILE" -version 2>/dev/null || echo "")
if [ -z "$NEW_VERSION" ]; then
    echo "Error: downloaded binary is not executable on this platform."
    exit 1
fi

# ── Install ──────────────────────────────────────────────────────

echo ""
mkdir -p "$INSTALL_DIR" 2>/dev/null || true

if [ -w "$INSTALL_DIR" ] || [ -w "$TARGET" ]; then
    mv "$TMPFILE" "$TARGET"
else
    echo "Need sudo to write to ${INSTALL_DIR}"
    sudo mv "$TMPFILE" "$TARGET"
fi

# ── Verify ───────────────────────────────────────────────────────

INSTALLED_VERSION=$("$TARGET" -version 2>/dev/null || echo "unknown")
echo "Installed: ${INSTALLED_VERSION}"
echo "Path:     ${TARGET}"
echo ""
echo "Quick start:"
echo "  export ANTHROPIC_API_KEY=sk-ant-..."
echo "  ${BINARY_NAME} -db gqldb -addr localhost:60063 -port 8080"
