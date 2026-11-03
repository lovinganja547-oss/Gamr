#!/bin/bash
# Tests unitaires de la logique (headless).
cd "$(dirname "$0")/.." && timeout 120 ${GODOT:-/opt/godot/godot} --headless --path . res://tests/unit_tests.tscn 2>&1 | grep -E "ECHEC|TESTS|SCRIPT ERROR"
