# Rapport de validation — Neon Rush 1.0.0

Environnement : conteneur Linux, JDK 21, Gradle 8.14.3, AGP 8.7.3, Android SDK 35.
**Pas d'émulateur ni d'appareil disponible** (pas de KVM) : l'APK n'a pas pu être installé ni lancé sur un vrai Android.
Tout ce qui suit a été réellement exécuté.

## Compilation
| Test | Résultat |
|---|---|
| `assembleDebug` | OK |
| `assembleRelease` (R8 + shrink resources) | OK — 85 Ko |
| Signature `apksigner verify` | OK (schéma v2) |
| `aapt2 dump badging` | package `com.neonrush.game`, minSdk 26, targetSdk 35, permission unique `VIBRATE` |
| `lintRelease` | 0 erreur, 0 avertissement (4 règles d'orientation/redimensionnement désactivées volontairement : portrait imposé) |

## Tests automatisés (`./gradlew testDebugUnitTest`) — 7/7 OK

### Gameplay (JVM pur, `GameplayTest`)
- **Franchissabilité des motifs** : un pilote automatique à anticipation (1,1 s, mêmes règles de déplacement que le joueur)
  joue 40 parties de 4 minutes sur 40 graines différentes. Résultat : moyenne 238 s, minimum 187 s, **0 mort avant 60 s**
  → aucun motif impossible n'est généré, y compris à vitesse maximale.
- Joueur immobile : meurt (les obstacles couvrent bien le terrain).
- Génération déterministe pour une même graine.
- Primitives de collision (rectangle, segment) et cycle laser off/alerte/actif.
- Bouclier : absorbe exactement un choc.
- Pas de fuite d'objets (bornes sur obstacles/bonus actifs).

### Application (Robolectric 4.14, rendu graphique natif, `ScreensRenderTest`)
Parcours complet piloté par événements tactiles simulés :
menu → JOUER → démarrage par toucher → partie pilotée par glissements (45 s) → pause → REPRENDRE (décompte)
→ mort → écran de fin → MENU → BOUTIQUE (sélection + achat PULSAR, débit vérifié, équipement)
→ défilement de la grille → retour → STATS → DÉFIS → RÉGLAGES (bascule musique aller/retour) → retour
→ retour sur le menu = quitter.
- Défis : 2 défis validés et récompensés pendant la partie test.
- **Persistance** : un nouveau `Profile` relu depuis SharedPreferences retrouve monnaie, record, parties, skin acheté et équipé.
- Chaque écran rendu est vérifié non vide ; captures dans `docs/screenshots/`.
- Rendu des 14 skins : `docs/screenshots/13_skins.png`.

## Non testé (nécessite un téléphone)
- Installation et lancement réels de l'APK, fluidité 60 FPS mesurée.
- Sortie audio réelle (la synthèse et l'initialisation SoundPool/AudioTrack s'exécutent sans erreur sous Robolectric, mais le son n'a pas été écouté).
- Vibration réelle, encoche/insets, mise en arrière-plan réelle de l'appli (pause auto).

À vérifier en premier sur le téléphone : son, vibration, ressenti de la sensibilité (Réglages → Sensibilité).
