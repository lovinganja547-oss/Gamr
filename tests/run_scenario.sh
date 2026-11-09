#!/bin/bash
# Scénario unique rendu sous xvfb : tests/run_scenario.sh <nom>
cd "$(dirname "$0")/.."
export E2E_OUT=${E2E_OUT:-/tmp/truffe_scenario}
mkdir -p "$E2E_OUT"
timeout 600 xvfb-run -a -s "-screen 0 720x1280x24" ${GODOT:-/opt/godot/godot} --path . --rendering-driver opengl3 --resolution 720x1280 res://tests/scenario.tscn -- "$1" 2>&1 | grep -v "ALSA\|alsa"
