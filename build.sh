#!/usr/bin/env bash
set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

echo -e "\n${BOLD}=== Word-to-PDF Converter — Build & Setup ===${RESET}\n"

# ─── Locate project root (directory containing this script) ───────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
info "Working directory: $SCRIPT_DIR"

# ─── 1. Check Python 3.8+ ─────────────────────────────────────────────────────
info "Checking Python version..."
if ! command -v python3 &>/dev/null; then
    error "python3 not found. Please install Python 3.8 or newer."
fi

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)

if [[ "$PY_MAJOR" -lt 3 || ( "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 8 ) ]]; then
    error "Python 3.8+ required, found $PY_VER"
fi
success "Python $PY_VER found"

# ─── 2. Install LibreOffice Writer (system package) ───────────────────────────
info "Checking for LibreOffice Writer..."

if dpkg -s libreoffice-writer &>/dev/null 2>&1; then
    LO_VER=$(libreoffice --version 2>/dev/null | awk '{print $2}' || echo "unknown")
    success "LibreOffice Writer already installed (v$LO_VER)"
else
    if [[ $EUID -ne 0 ]]; then
        warn "LibreOffice Writer is not installed. Re-running apt-get with sudo..."
        SUDO="sudo"
    else
        SUDO=""
    fi

    info "Installing LibreOffice Writer via apt..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y libreoffice-writer
    success "LibreOffice Writer installed"
fi

# ─── 3. Create virtual environment ────────────────────────────────────────────
VENV_DIR="$SCRIPT_DIR/.venv"

if [[ -d "$VENV_DIR" ]]; then
    success "Virtual environment already exists at .venv"
else
    info "Creating Python virtual environment at .venv ..."
    python3 -m venv "$VENV_DIR"
    success "Virtual environment created"
fi

# Activate venv for the rest of the script
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

# ─── 4. Upgrade pip silently ──────────────────────────────────────────────────
info "Upgrading pip..."
pip install --upgrade pip --quiet
success "pip up to date"

# ─── 5. Install Python dependencies ──────────────────────────────────────────
info "Installing Python dependencies from requirements.txt..."
pip install -r requirements.txt --quiet
success "Python dependencies installed"

# ─── 6. Smoke-test the app imports ────────────────────────────────────────────
info "Verifying application imports..."
python3 -c "
import flask, subprocess, tempfile, uuid, pathlib
result = subprocess.run(['libreoffice', '--version'], capture_output=True, text=True, timeout=10)
assert result.returncode == 0, 'LibreOffice not callable'
print('All imports and runtime checks passed.')
"
success "Application verified"

# ─── 7. Print run instructions ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}Build complete!${RESET}"
echo ""
echo -e "  To start the server:"
echo -e "    ${CYAN}source .venv/bin/activate${RESET}"
echo -e "    ${CYAN}python app.py${RESET}"
echo ""
echo -e "  Then open: ${BOLD}http://localhost:5000${RESET}"
echo ""
