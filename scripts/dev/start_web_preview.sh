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

if command -v gitpod > /dev/null 2>&1; then
	gitpod environment port open "$PORT" --admission creator_only --name "Game web preview" --protocol http
fi

cd "$OUTPUT_DIR"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
