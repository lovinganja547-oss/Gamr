# Patouille — Rapport d'analyse initial (refonte majeure)

Date : 03/11/2026 · Version analysée : commit `60f4d33` (+ collier agrandi, non compilé)

## 1. Architecture existante

| Élément | Valeur |
|---|---|
| Moteur | Godot 4.5.1, GDScript (7 800 lignes, 27 scripts) |
| Rendu | GL Compatibility (GLES3), portrait 720×1280, étirement `canvas_items` |
| Export | APK non-Gradle (modèles officiels), arm64-v8a + armeabi-v7a, minSdk 24, targetSdk 35, `fr.patouille.compagnons` |
| Ressources | 100 % procédurales : maillages SDF (`tools/gen_models.py` → `.res`), sons/musiques (`tools/gen_audio.py`), icône (`tools/gen_icon.py`) |
| Tests | `tests/check.sh` (compilation), `tests/run_unit.sh` (51 tests logiques), `tests/run_e2e.sh` (parcours complet rendu sous xvfb, 30 captures) |

Organisation :
- `scripts/autoload/` : `GameData` (données statiques), `GameState` (état, besoins, économie, sauvegarde), `Audio`, `Voice`.
- `scripts/main.gd` : monde 3D, caméra, écrans, panneaux modaux, entrées tactiles, photo.
- `scripts/pet/` : `PetModel` (maillage, IK des pattes, postures, yeux/paupières, poils par couches), `PetController` (IA, déplacement en ligne droite, réactions, ordres).
- `scripts/world/` : `WorldBuilder` (6 lieux construits en primitives), `CameraRig` (orbite).
- `scripts/ui/` : `UiKit` (thème), `TitleScreen`, `AdoptScreen`, `HomeHud`, `Panels` (14 panneaux).
- `scripts/activities/` : `Activity` (base), bain, balle, agilité, recherche, promenade, dressage, concours.
- Sauvegarde : JSON + SHA-256, écriture atomique, copie de secours, validation (`sanitize`), sauvegarde auto 30 s + pause/fermeture.

## 2. Fonctionnalités opérationnelles (testées en e2e)
Adoption 6 races + personnalisation, besoins avec évolution hors ligne plafonnée, caresses/tapes, repas/eau, bain, friandises, 9 ordres (geste/bouton), balle, agilité, recherche (5 niveaux), promenade (joystick, trouvailles, rencontres), 4 concours × 4 niveaux, boutique, sac, déco maison, album photo, succès, objectifs du jour, paramètres, qualité graphique, sauvegarde/rechargement/corruption.

## 3. À corriger (défauts constatés)
1. **Chien dans le canapé au repas** — cause exacte : la gamelle est posée en (-0,8 ; -1,9), à l'intérieur de l'emprise du canapé (x -2,55…-0,65, z -2,3…-1,5). Aucun système d'obstacles : déplacement en ligne droite, aucune collision avec les meubles.
2. **Cadrage du bain** : distance fixe 2,0 m, n'adapte pas à la taille de l'animal → chien coupé.
3. **Fatigue trop rapide** : 8 pts/h de base + coûts fixes lourds (promenade -15, agilité -12, concours -15 à -27, balle -3/lancer) ; sieste forcée sous 18 → 3 à 4 activités par session.
4. **Agilité trop difficile** : fenêtre de geste courte, geste à faire en courant, pénalité 5 s, un seul tracé ovale.
5. **Voix** : enregistrement dans un menu Paramètres séparé, caractéristiques trop grossières (6 bandes), pas d'écoute de contrôle ni de contrôle qualité, non testé sur micro réel.
6. **Emojis partout** (≈ 210 occurrences : HUD, menus, besoins, objets) → interdits par le cahier des charges ; rendu dépendant de la police système.
7. Expérience **globale au joueur** (pas par animal) ; pas de déblocages par niveau d'animal.
8. Caméra : pas de bouton de recentrage, pas d'anti-traversée des murs/meubles.
9. Collier partiellement masqué par les poils (corrigé dans le source, pas encore dans l'APK).

## 4. À améliorer
Repas (approche, gamelle qui se vide), bain (zones du corps, eau, propreté visible sur le pelage), cœurs de caresse discrets, fenêtre des besoins (icônes, %, couleurs), recherche (cachettes contextuelles, objets variés, indices de flair), promenade (itinéraires, laisse, retour maison), boutique (vente), objets (icônes illustrées), textures des meubles/sols, éclairage intérieur, personnalités (6 demandées vs 6 actuelles différentes), sauvegarde (migration de versions).

## 5. À ajouter
Besoin « sortir », niveau/XP par animal + déblocages, ordre « Reste », tir à la corde, brossage, repos/câlin, mode photo complet, forêt + terrain d'entraînement, itinéraires de promenade, laisse physique, besoins naturels, événements de promenade, vente d'objets, collection (album des animaux, catalogue des races, trophées, records), tournois avec records, accessibilité (taille du texte, réduction des animations, sensibilité), politique de confidentialité, écran de démarrage, AAB.

## 6. Risques techniques
| Risque | Impact | Parade |
|---|---|---|
| Reconnaissance vocale : Godot n'a pas de STT | Fonction clé | Voir question 1 |
| AAB : exige l'export Gradle (téléchargements Gradle/AGP) | Livraison Play Store | Activer le gabarit Gradle, tester le build |
| Poils par couches : 163 k primitives / image en qualité Moyen | FPS sur appareils modestes | 0 couche en Faible, LOD, couches limitées au chien actif |
| Pas d'émulateur/appareil (pas de KVM) | Aucun test réel Android | Tests bureau + test utilisateur sur téléphone |
| Clé de signature release dans `build/` non versionnée | Mise à jour Play impossible si perdue | Sauvegarde hors dépôt par le propriétaire, Play App Signing |
| Public enfants (programme Familles) | Contraintes Play strictes | Voir question 2 |

## 7. Plan d'implémentation recommandé (phases livrables, APK à chaque phase)
1. **Fondations** : navigation avec obstacles (grille + évitement), repas corrigé, caméra (recentrage, collision, zoom), cadrage auto du bain, équilibrage énergie, XP/niveau par animal + migration de sauvegarde v2.
2. **Interface** : jeu d'icônes vectorielles (SVG originaux) remplaçant tous les emojis, fenêtre des besoins refaite (+ « sortir »), illustrations d'objets, accessibilité.
3. **Interactions** : cœurs, réactions selon humeur/personnalité, brossage, tir à la corde, repos/câlin, mode photo.
4. **Dressage vocal** intégré (architecture selon question 1), ordre « Reste », progression multi-séances.
5. **Agilité** refaite : 5 niveaux, 8 obstacles, plusieurs tracés, contrôles contextuels, médailles/records.
6. **Recherche** refaite : 6 lieux (forêt, terrain), cachettes contextuelles, objets variés et rares.
7. **Promenades** : itinéraires, laisse, besoins naturels, événements, boutique de promenade + vente, retour maison.
8. **Progression long terme** : missions quotidiennes par niveau, déblocages (races, pelages, objets, lieux), collection, tournois et records.
9. **Graphismes** : textures procédurales haute résolution (bois, tissu, sols), éclairage intérieur, cohérence DA.
10. **Publication** : AAB, écran de démarrage, politique de confidentialité, rapport de tests final.
