#!/bin/bash
# Compile tous les scripts (avec autoloads) et affiche les erreurs.
cd "$(dirname "$0")/.." && timeout 180 ${GODOT:-/opt/godot/godot} --headless --path . res://tests/check_all.tscn 2>&1 | grep -E "SCRIPT ERROR|ERROR:|ECHEC|SCRIPTS|at: " | grep -v "ALSA\|audio driver\|ERR_CANT_OPEN\|status < 0" 
