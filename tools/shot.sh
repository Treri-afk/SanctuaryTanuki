#!/bin/bash
# Usage : tools/shot.sh x y z yaw pitch nom [phase 0-2] [attente]   -> assets/previews/ingame/<nom>.png
G="/c/Users/PA54F/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.."
mkdir -p assets/previews/ingame
"$G" --path . --resolution 1280x720 -- --shot $1 $2 $3 $4 $5 "assets/previews/ingame/$6.png" ${7:-0} ${8:-6} ${9:-} 2>&1 | grep -E "SHOT|SCRIPT ERROR|Parse Error|ERROR: [^RPa]"
