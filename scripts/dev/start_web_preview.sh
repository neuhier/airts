#!/usr/bin/env bash
# Export and serve the game directly in a browser. This is the preferred
# playtest path on tablets because it does not depend on remote desktop input.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT=8080
OUTPUT_DIR="$PROJECT_DIR/build/web"

mkdir -p "$OUTPUT_DIR"

if ! godot4 --headless --path "$PROJECT_DIR" --export-release Web "$OUTPUT_DIR/index.html"; then
	echo "Web export failed. Ensure Godot export templates are installed." >&2
	exit 1
fi

# A service restart must replace the previous preview server so the browser
# always receives the freshly exported game.
pkill -f "web_preview_server.py $PORT" || true

cd "$OUTPUT_DIR"
exec python3 "$PROJECT_DIR/scripts/dev/web_preview_server.py" "$PORT"
