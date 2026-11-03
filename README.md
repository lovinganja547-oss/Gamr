# Patouille — compagnons virtuels (Android)

Jeu original de simulation d'animaux de compagnie, Godot 4.5.1 (GDScript, rendu GL Compatibility).
Modèles 3D, animations, sons et musiques 100 % procéduraux et originaux (aucune ressource externe).

## Installer
APK prêt : `dist/Patouille.apk` (release signée, arm64-v8a + armeabi-v7a, Android 7.0+).
```
adb install -r dist/Patouille.apk
```
ou copier l'APK sur le téléphone et l'ouvrir (autoriser « sources inconnues »).

## Reconstruire
Prérequis : Godot 4.5.1 + modèles d'export 4.5.1, Android SDK (platform-tools, build-tools 35.0.1, platforms;android-35), JDK 17+.
```
GODOT=/chemin/godot ANDROID_HOME=/chemin/sdk tools/build_apk.sh
```
Produit `build/Patouille-debug.apk` et `build/Patouille.apk` (clés générées dans `build/`, non versionnées).
Régénérer sons / icône : `python3 tools/gen_audio.py` ; `python3 tools/gen_icon.py` (numpy, Pillow).
Régénérer les modèles 3D : `python3 tools/gen_models.py` puis `godot --headless --path . -s tools/convert_models.gd` (maillages sculptés par champs de distance, 2 niveaux de détail).

## Tests
- `tests/check.sh` : compilation de tous les scripts.
- `tests/run_unit.sh` : 51 tests de logique (besoins, hors-ligne, économie, dressage, concours, objectifs, sauvegarde/corruption, gestes, voix).
- `tests/run_e2e.sh` : parcours complet rendu sous xvfb (adoption → soins → bain → dressage → balle → recherche → promenade → agilité → concours → photo → sauvegarde/rechargement) avec captures.

## Contenu
- 6 animaux (Labrador, Shiba Inu, Caniche, Berger allemand, Beagle, Chat), pelages, yeux, sexe, collier, accessoire, tempérament.
- Besoins : faim, soif, propreté, énergie, humeur, santé, affection ; évolution hors ligne plafonnée (48 h, plancher 20, santé ≥ 10, jamais de mort).
- Interactions : caresses (glisser), tapes (tête/corps), appel, toucher le sol, nourrir, eau, bain, friandises, lancer, photo, Bravo/Non.
- Dressage : 9 ordres, démonstration par une monitrice, geste tactile / bouton / voix, chance selon compétence, motivation, caractère, relation, fatigue de séance.
- Activités : lancer de balle (score), agilité (chrono/pénalités), recherche (5 niveaux), promenade (trouvailles, rencontres, fontaine).
- Concours : obéissance, agilité, recherche, dressage avancé × 4 niveaux, conditions d'entrée, 7 rivaux, podium, trophées.
- Économie : pièces, boutique (repas, friandises, soins, jouets, colliers, accessoires, déco, lieux), niveau joueur, relation, 22 succès, 3 objectifs/jour.
- Lieux : maison (décorable, 8 emplacements), jardin, parc, plage, centre de dressage, refuge.
- Réglages : volumes général/musique/effets, qualité Faible/Moyen/Élevé (MSAA, échelle de rendu, FPS 30/45/60, ombres, densité), vibrations, voix, recommencer.
- Sauvegarde : JSON + empreinte SHA-256, écriture atomique, copie de secours, validation complète, sauvegarde auto 30 s et à la mise en pause/fermeture.

## Limites connues
- Commandes vocales : reconnaissance hors ligne dépendante du locuteur (on enregistre sa voix par ordre, comparaison DTW). Pas de reconnaissance « native » Android (nécessiterait un plugin Gradle). Non testée sur micro réel ici.
- Pas de test sur appareil/émulateur : l'environnement de build n'a pas de KVM. Tests faits sur bureau (xvfb, OpenGL logiciel).
- Langue : jeu entièrement en français, forcé quelle que soit la langue du téléphone (architecture `tr()` conservée pour une future traduction).
