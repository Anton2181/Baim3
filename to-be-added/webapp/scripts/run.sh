#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBAPP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${WEBAPP_DIR}/.venv/bin/activate"
python "${WEBAPP_DIR}/app/app.py"
