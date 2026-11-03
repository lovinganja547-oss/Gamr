#!/bin/bash
# Construit les APK Android (debug + release signés).
# Prérequis : Godot 4.5.1 + modèles d'export, Android SDK (build-tools 35), JDK 17+.
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/opt/godot/godot}
SDK=${ANDROID_HOME:-/opt/android-sdk}
JAVA=${JAVA_HOME:-$(dirname $(dirname $(readlink -f $(which javac))))}
mkdir -p build
KS=build/truffeco-release.keystore
DKS=build/debug.keystore
[ -f "$DKS" ] || keytool -genkeypair -v -keystore "$DKS" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
[ -f "$KS" ] || keytool -genkeypair -v -keystore "$KS" -storepass truffeco -alias truffeco -keypass truffeco -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=TruffeEtCo,O=TruffeEtCo,C=FR" >/dev/null 2>&1
CFG=~/.config/godot; mkdir -p $CFG
cat > $CFG/editor_settings-4.5.tres <<EOT
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA"
export/android/debug_keystore = "$(pwd)/$DKS"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOT
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(pwd)/$KS"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=truffeco
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=truffeco
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-debug "Android" build/TruffeEtCo-debug.apk
"$GODOT" --headless --path . --export-release "Android" build/TruffeEtCo.apk
ls -la build/*.apk
