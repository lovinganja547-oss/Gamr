#!/bin/bash
# Portraits de contrôle de chaque race (nécessite xvfb-run).
cd "$(dirname "$0")/.."
for b in labrador shiba poodle shepherd beagle cat; do
  timeout 120 xvfb-run -a -s "-screen 0 720x1280x24" ${GODOT:-/opt/godot/godot} --path . --rendering-driver opengl3 --resolution 720x1280 res://tests/model_test.tscn -- ${1:-stand} $b 2>&1 | grep -E "SCRIPT ERROR" 
done
