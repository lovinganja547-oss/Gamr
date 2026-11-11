#!/bin/bash
# Banc de mesure de la détection vocale sur signaux de synthèse (headless, plusieurs minutes).
# Options : BENCH_QUICK=1 (rapide), BENCH_SPEAKERS=0,1,2, BENCH_VERBOSE=1, BENCH_SEED=n, BENCH_DUMP=chemin.
cd "$(dirname "$0")/.." && timeout 3000 ${GODOT:-/opt/godot/godot} --headless --path . res://tests/voice_bench.tscn 2>&1 | grep -E "BANC|SCRIPT ERROR|ERROR|  (appr|capt|lent|reco|FAUX)|at: " | grep -v "ALSA\|audio driver\|ERR_CANT_OPEN\|status < 0"
