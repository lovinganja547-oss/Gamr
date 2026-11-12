# Truffe & Co 2.0 — Rapport final de la refonte

Date : 9 novembre 2026. Branche `ccr-2c3a8767-t3it8t`.

## 1. Livrables
| Élément | Emplacement |
|---|---|
| APK release signé (2.0.0, code 2) | `dist/TruffeEtCo.apk` (61 Mo, arm64-v8a + armeabi-v7a, minSdk 24, targetSdk 35) |
| App Bundle Play Store (signé) | `dist/TruffeEtCo.aab` (61 Mo) |
| Code source | dépôt, branche ci-dessus |
| Politique de confidentialité | `docs/POLITIQUE_CONFIDENTIALITE.md` |
| Instructions de compilation | `README.md` |
| Captures de suivi | `docs/captures/` |

## 2. Fonctionnalités ajoutées ou refondues (par phase)
1. **Fondations** : navigation A* contournant les meubles et décors (fin des passages dans le canapé), repas réaliste (approche par un côté libre, gamelle qui se vide, faim mise à jour progressivement, sécurité si chemin bloqué), caméra (bouton Centrer, cadrage automatique selon la taille de l'animal, pas de traversée des murs ni des obstacles), bain par zones (tête, dos, ventre et pattes, queue) avec mousse, douche, éclaboussures et saleté visible sur le pelage, énergie rééquilibrée (activités calmes / modérées / intenses, endurance, caractère), besoin « Sortir », niveau et expérience propres à chaque animal, sauvegarde v2 puis v3 avec migrations, nom Truffe & Co.
2. **Interface** : 212 icônes vectorielles originales (plus aucun emoji), fenêtre des besoins avec icône, pourcentage et couleur d'état, une icône par objet, accessibilité (taille du texte, réduction des animations, sensibilité de la caméra).
3. **Interactions** : cœurs discrets (4 au maximum), réactions selon l'humeur et 6 personnalités (joueur, calme, curieux, énergique, affectueux, timide), brossage, tir à la corde, moment câlin, jeu spontané avec le jouet, mode photo (poses, expressions, accessoires, décors, interface masquable).
4. **Dressage vocal** : apprentissage du mot pendant la séance (mot libre, contrôle qualité, réécoute, recommencer, validation), empreinte vocale hors ligne (MFCC par FFT + DTW), modèles par animal, fiabilité progressive, ordre « Reste ».
5. **Agilité** : 5 niveaux (Initiation à Expert), obstacles haies, tunnels, slaloms, cerceaux, plateformes, passerelles, zones d'arrêt et combinés, plusieurs tracés, gros bouton d'action contextuel, recommencer, médailles et records.
6. **Cache-cache** : lieu Forêt, cachettes propres à chaque lieu (coussins, cartons, paniers, sous un meuble, buissons, tas de feuilles, rochers, troncs, sable, caisses, pneus), 27 objets de collection dont des rares, jouets et accessoires à trouver, flair limité avec cachettes en surbrillance, queue qui s'agite près d'un objet, défi du jour, 5 niveaux.
7. **Promenades** : 7 itinéraires (distance, durée, difficulté, trouvailles), parcours balisé en boucle, laisse visible, joystick, besoins naturels (crottes à ramasser), événements (rencontre, défi de dressage, trésor rare, point d'eau), énergie affichée avec alerte, retour à la maison obligatoire pour la récompense finale, boutique accessible pendant la promenade avec vente des trouvailles.
8. **Progression** : missions du jour adaptées au niveau (paliers, bonus des 3 missions), récompense de connexion sur 7 jours, déblocages par niveau (races, pelages, yeux, objets, lieux, activités), écran Collection (animaux, races, objets, accessoires, trophées, records), 5e concours « Défi de promenade », classements locaux.
9. **Graphismes** : textures 512 px raccordables (parquet, tissu, plâtre, herbe, sable, sol forestier, terre), meubles arrondis sculptés (canapé, couchages, niche, banc, coffre, gamelles, pot), brouillard de profondeur, éclairage intérieur chaud, ombre douce sous l'animal.
10. **Publication** : écran de démarrage, version 2.0.0, politique de confidentialité, APK release, préréglage AAB.

## 3. Tests réellement exécutés (sur bureau Linux, rendu logiciel sous xvfb)
| Test | Résultat |
|---|---|
| Compilation des 35 scripts (`tests/check.sh`) | 0 échec |
| Tests unitaires (`tests/run_unit.sh`) | **93 / 93 OK** |
| Parcours complet rendu (`tests/run_e2e.sh`, environ 50 captures) | **0 erreur de script**. Repas : 0 image dans un obstacle. Corde, câlin, brossage, mode photo terminés. Vocal : enregistrement, réécoute, reconnaissance et mot inconnu rejeté. Balle : 163 points. Cache-cache : 2/2 objets. Promenade : 18/18 points de passage, 282 m, 4 trouvailles. Agilité : médaille, record 71,2. Concours : classement. Sauvegarde puis rechargement identiques. |
| Scénario cache-cache en forêt | 2/2 objets, partie terminée, objets ajoutés au sac |
| Scénario progression | missions, connexion, collection, défi de promenade (podium, classement local enregistré) |
| Contenu du paquet exporté | modèles, métadonnées, meubles, textures, icônes, shaders, sons présents. Lancement depuis le .pck exporté sans ressource manquante. |

## 4. Performances mesurées (scène Parc, animal + décor, moniteurs Godot)
| Qualité | Appels de rendu | Primitives | Mémoire vidéo | Mémoire |
|---|---|---|---|---|
| Faible | 218 | 39 000 | 35 Mo | 69 Mo |
| Moyen | 351 | 140 000 | 48 Mo | 70 Mo |
| Élevé | 415 | 279 000 | 68 Mo | 70 Mo |
Images par seconde : **non mesurées sur téléphone** (le rendu logiciel du serveur de test n'est pas représentatif).

## 5. Limitations restantes (honnêtes)
- **Aucun test sur téléphone ou émulateur Android** : l'environnement de build n'a pas de virtualisation (KVM). Tout a été testé sur bureau.
- **Reconnaissance vocale** : validée uniquement avec des signaux de synthèse et des enregistrements simulés, jamais avec un vrai micro. Elle reconnaît la voix de la personne qui a enregistré les mots.
- Images par seconde réelles inconnues : à mesurer sur un appareil modeste (régler la qualité sur Faible si besoin).
- La qualité Élevé (279 000 primitives) vise les téléphones récents.
- Adresse de contact à compléter dans la politique de confidentialité avant publication.

## 6. App Bundle (AAB)
Compilé via l'export Gradle (Gradle 8.11.1, gabarit Android de Godot 4.5.1 dans `android/build`, non versionné). Signature vérifiée (`jar verified`). Le premier essai a échoué sur une limitation temporaire du serveur Maven (HTTP 429), le second a réussi. Pour le Play Store, activer Play App Signing et conserver la clé d'importation `build/truffeco-release.keystore` hors du dépôt.

## 7. Recommandations pour la suite
1. Tester l'APK sur 2 ou 3 téléphones (un modeste, un récent) : FPS, micro, reprise après mise en veille.
2. Ajuster l'équilibrage (énergie, prix, récompenses) d'après des sessions réelles.
3. Fusionner les décors statiques (MultiMesh / maillages combinés) pour réduire les appels de rendu.
4. Ajouter une traduction anglaise (architecture `tr()` déjà en place).
5. Préparer la fiche Play Store (captures, description, classification du contenu, sécurité des données : « aucune donnée collectée »).

## 8. Version 2.2.0 — refonte graphique et carte agrandie (12 novembre 2026)
- **Rendu** : ciel dégradé à nuages ombrés et soleil, ambiances lumineuses par lieu (matin, midi, après-midi, heure dorée, sous-bois), brouillard d'horizon, collines et silhouettes d'arbres au loin, ombres portées réglées (biais, fondu, portée 20 à 26 m).
- **Sols** : herbe, chemins, pavés et sable fondus par un masque peint (bords irréguliers, variation de teinte à grande échelle, ombres de contact sous arbres et bâtiments).
- **Textures** : 13 matières 512 px avec relief (pavés, briques, dalles, tuiles, écorce, pierre, roche, feuillage, herbe, sable, terre, sous-bois, plâtre), mipmaps et compression GPU activés (fin du scintillement à distance).
- **Végétation** : arbres, sapins, buissons, haies, rochers, souches sculptés ; herbe et fleurs animées par le vent ; eau animée avec écume (mer, rivière, étangs, fontaine).
- **Bâtiments** : maisons détaillées (soubassement en pierre, colombages, tuiles, cheminée, fenêtres à volets et jardinières, portes, auvents rayés, enseignes), fusionnées en un seul maillage par lieu.
- **Lieux refaits** : maison (papier peint, soubassement, fenêtres à rideaux, tapis à motifs), jardin, parc, forêt, plage, terrain de concours, refuge, grand pré, quartier.
- **Carte** : 22 lieux (boulangerie, marché, café, toiletteur, vétérinaire, école du chiot, étang, ferme, belvédère, phare…), rivière et ponts, endurance de 450 m (+80 m par niveau), actions propres à chaque lieu dont 4 quotidiennes.
- **Interface** : boutons en relief, socle des actions, carte illustrée.
- **Tests** : 154 tests unitaires OK, parcours complet sans erreur de script. Quartier, par qualité : Faible 183 appels / 142 000 primitives, Moyen 313 / 471 000, Élevé 377 / 618 000. Non mesuré sur téléphone.

## Version 2.5.0

- Nom : « Truffe & Compagnie ». Écran de chargement illustré (`scenes/boot.tscn`, `scripts/boot.gd`) : toutes les ressources sont chargées une seule fois et gardées en mémoire, les shaders sont précompilés avant l'écran titre.
- Nouvelle icône (classique + adaptative), image de démarrage et logo : `tools/gen_brand.py` à partir des rendus `tools/art/`.
- Police d'interface Nunito ExtraBold et logo en Baloo 2 (licence SIL OFL, textes dans `assets/fonts/` et `tools/art/`).
- 69 accessoires (`scripts/pet/accessories.gd`), placés à partir des mesures de chaque race ; planche de contrôle : `tests/acc_sheet.tscn -- <race> [angle]`.
- Maison : 17 objets de décoration supplémentaires, mobilier refait, étagère à trophées déplacée hors de la fenêtre.
- Missions et objectifs quotidiens et hebdomadaires, tirés uniquement parmi les fonctions débloquées.
- Balades : carte, espacement des drapeaux et endurance augmentés de 50 %.
- Interfaces habillées (cadres, bandeaux, boutons texturés).
