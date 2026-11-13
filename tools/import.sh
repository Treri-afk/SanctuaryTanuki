#!/bin/bash
# Importe dans Godot les .glb nouveaux ou modifiés. Un seul import à la fois : les appels simultanés attendent leur tour.
G="/c/Users/PA54F/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.."
LOCK=".godot/import.lock"
mkdir -p .godot
for i in $(seq 1 120); do
  if mkdir "$LOCK" 2>/dev/null; then break; fi
  # verrou abandonné depuis plus de 5 minutes : on le reprend
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then rmdir "$LOCK" 2>/dev/null; fi
  sleep 3
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
"$G" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Error importing|Failed to import" | head -20
echo "IMPORT terminé"
