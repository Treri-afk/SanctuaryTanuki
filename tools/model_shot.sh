#!/bin/bash
# Rend un modèle seul avec le vrai rendu toon du jeu -> assets/previews/toon/<nom><suffixe>.png
# Usage : tools/model_shot.sh nom [yaw=35] [pitch=18] [zoom=1] [suffixe]     (lancer tools/import.sh avant si le .glb a changé)
G="/c/Users/PA54F/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.."
"$G" --path . --resolution 1000x1000 --script res://tools/model_view.gd -- "$1" "${2:-35}" "${3:-18}" "${4:-1}" "${5:-}" 2>&1 | grep -E "MODEL_SHOT|SCRIPT ERROR|Parse Error"
