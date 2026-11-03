#!/bin/bash
# Parcours complet avec rendu (nécessite xvfb-run). Captures dans $E2E_OUT.
cd "$(dirname "$0")/.."
export E2E_OUT=${E2E_OUT:-/tmp/patouille_e2e}
mkdir -p "$E2E_OUT"
timeout 900 xvfb-run -a -s "-screen 0 720x1280x24" ${GODOT:-/opt/godot/godot} --path . --rendering-driver opengl3 --resolution 720x1280 res://tests/e2e.tscn
