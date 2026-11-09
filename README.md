# Truffe & Co — compagnons virtuels (Android)

Jeu original de simulation canine (et féline), Godot 4.5.1 / GDScript, rendu GL Compatibility, 100 % hors ligne.
Modèles 3D, poils, meubles, textures, icônes, sons et musiques sont générés par les outils du dépôt (aucune ressource externe).

## Installer
- APK release signé : `dist/TruffeEtCo.apk` (Android 7.0+, arm64-v8a + armeabi-v7a).
- `adb install -r dist/TruffeEtCo.apk`, ou copier l'APK sur le téléphone et l'ouvrir (autoriser les sources inconnues).
- Identifiant : `fr.truffeco.compagnons`, version 2.0.0 (code 2).

## Reconstruire
Prérequis : Godot 4.5.1 + modèles d'export 4.5.1, Android SDK (platform-tools, build-tools 35.0.1, platforms;android-35), JDK 17+.
```
GODOT=/chemin/godot ANDROID_HOME=/chemin/sdk tools/build_apk.sh      # APK debug + release
```
App Bundle (Play Store) : export Gradle, préréglage « Android AAB » :
```
godot --headless --path . --install-android-build-template   # ou dézipper android_source.zip dans android/build
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=... GODOT_ANDROID_KEYSTORE_RELEASE_USER=... GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
  godot --headless --path . --export-release "Android AAB" build/TruffeEtCo.aab
```
La clé de signature release (`build/truffeco-release.keystore`) n'est pas versionnée : **la conserver hors du dépôt** (ou utiliser Play App Signing), sinon les mises à jour seront impossibles.

Régénérer les ressources :
| Ressource | Commande |
|---|---|
| Sons, musiques | `python3 tools/gen_audio.py` |
| Icône, écran de démarrage | `python3 tools/gen_icon.py` ; `python3 tools/gen_splash.py` |
| Icônes d'interface (SVG) | `python3 tools/gen_ui_icons.py` |
| Textures | `python3 tools/gen_textures.py` |
| Animaux / meubles 3D | `python3 tools/gen_models.py` ; `python3 tools/gen_props.py` puis `godot --headless --path . -s tools/convert_models.gd` |

## Tests
- `tests/check.sh` : compilation de tous les scripts.
- `tests/run_unit.sh` : 93 tests de logique (besoins, hors ligne, économie, dressage, voix, missions, connexion, classements, déblocages, vente, migrations de sauvegarde, gestes).
- `tests/run_e2e.sh` : parcours complet rendu sous xvfb avec captures (adoption, soins, bain, brossage, câlin, corde, mode photo, dressage vocal, Reste, balle, cache-cache, promenade, agilité, concours, photo, sauvegarde/rechargement).
- `tests/run_scenario.sh <search|progress|visuals|perf>` : scénarios ciblés rapides.
- `tests/portraits.sh` : portraits de contrôle des 6 races.

## Architecture
- `scripts/autoload/` : `GameData` (données), `GameState` (état, besoins, économie, progression, sauvegarde v3 + migrations), `Audio`, `Voice` (empreinte vocale MFCC + DTW).
- `scripts/main.gd` : monde 3D, navigation, caméra, écrans, panneaux, entrées tactiles, photo.
- `scripts/pet/` : `PetModel` (maillages sculptés, IK des pattes, postures, yeux/paupières, poils par couches), `PetController` (IA, navigation A*, réactions, ordres).
- `scripts/world/` : `WorldBuilder` (7 lieux), `NavGrid` (A* avec obstacles), `CameraRig`.
- `scripts/ui/` : `UiKit` (thème, icônes `[i:nom]`), écrans titre / refuge / HUD, `Panels`, `VoicePanel`.
- `scripts/activities/` : bain, brossage, câlin, corde, mode photo, balle, cache-cache, promenade, agilité, dressage, concours.

Documentation : `docs/RAPPORT_FINAL.md`, `docs/POLITIQUE_CONFIDENTIALITE.md`, `docs/RAPPORT_INITIAL.md`, captures dans `docs/captures/`.
