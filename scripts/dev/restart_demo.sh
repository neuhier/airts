#!/usr/bin/env bash
# Restarts the visual demo stack (virtual X display + VNC + Godot editor)
# so you can playtest the latest code changes without needing the agent.
#
# Usage:
#   bash scripts/dev/restart_demo.sh
#
# What it does:
#   1. Ensures Xvfb (virtual display :99), fluxbox (window manager),
#      x11vnc, and the noVNC websocket proxy are running — starting any
#      that died, leaving healthy ones untouched.
#   2. Kills any running Godot process (editor and/or play instance) so
#      the next launch picks up all recent script/scene edits.
#   3. Relaunches the Godot editor with this project open.
#
# After it finishes, open the noVNC URL in your browser and press F5 in
# the Godot editor to run the game.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISPLAY_NUM=":99"
VNC_PORT=5900
NOVNC_PORT=6080

is_running() {
	pgrep -f "$1" > /dev/null 2>&1
}

echo "== Restarting demo stack for $PROJECT_DIR =="

# 1. Virtual X display
if ! DISPLAY="$DISPLAY_NUM" xdpyinfo > /dev/null 2>&1; then
	echo "Starting Xvfb on $DISPLAY_NUM..."
	sudo mkdir -p /tmp/.X11-unix
	sudo chmod 1777 /tmp/.X11-unix
	rm -f "/tmp/.X${DISPLAY_NUM#:}-lock"
	nohup setsid Xvfb "$DISPLAY_NUM" -screen 0 1600x900x24 -nolisten tcp > /tmp/xvfb.log 2>&1 &
	disown
	sleep 2
else
	echo "Xvfb already running."
fi

# 2. Window manager
if ! is_running "fluxbox"; then
	echo "Starting fluxbox..."
	nohup setsid env DISPLAY="$DISPLAY_NUM" fluxbox > /tmp/fluxbox.log 2>&1 &
	disown
	sleep 1
else
	echo "fluxbox already running."
fi

# 3. VNC server
if ! is_running "x11vnc -display $DISPLAY_NUM"; then
	echo "Starting x11vnc on port $VNC_PORT..."
	nohup setsid x11vnc -display "$DISPLAY_NUM" -forever -shared -nopw -rfbport "$VNC_PORT" -quiet > /tmp/x11vnc.log 2>&1 &
	disown
	sleep 1
else
	echo "x11vnc already running."
fi

# 4. noVNC websocket proxy (browser-facing)
if ! is_running "websockify.*$NOVNC_PORT"; then
	echo "Starting noVNC websocket proxy on port $NOVNC_PORT..."
	nohup setsid websockify --web=/usr/share/novnc "$NOVNC_PORT" "localhost:$VNC_PORT" > /tmp/websockify.log 2>&1 &
	disown
	sleep 1
else
	echo "noVNC proxy already running."
fi

# 5. Kill any existing Godot process (editor + play instances) so the next
#    launch loads all current script/scene changes.
if is_running "godot4"; then
	echo "Stopping existing Godot process(es)..."
	pkill -f "godot4" || true
	sleep 2
fi

# 6. Relaunch the editor with the project open.
echo "Launching Godot editor..."
cd "$PROJECT_DIR"
nohup setsid env DISPLAY="$DISPLAY_NUM" godot4 -e --path "$PROJECT_DIR" > /tmp/godot.log 2>&1 &
disown

sleep 6
if pgrep -f "godot4 -e" > /dev/null 2>&1; then
	echo "== Godot editor is running. Open the noVNC URL, then press F5 to play. =="
else
	echo "== Godot editor did not start — check /tmp/godot.log for details. =="
fi
