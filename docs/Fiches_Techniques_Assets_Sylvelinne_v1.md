# Fiches techniques des assets — *Sylvelinne*
### Étape 3 — Specs de production · version 1

> **Choix techniques retenus** (modifiables) : jeu **2D**, vue **de dessus 3/4** (type Zelda/Stardew), moteur **Godot**, viewport de référence **1920×1080** (paysage). Style **illustré/peint** (pas pixel art).

---

## Tableau récapitulatif (l'essentiel)

| Catégorie | Taille de base (px) | Prises de vue | Animations | Outil conseillé |
|---|---|---|---|---|
| Héroïne / PNJ humains | 64×96 | **4 directions** (bas, haut, gauche, droite) | immobile, marche (+ parler & action pour les héros) | **Meshy** |
| Enfants / petits PNJ | 48×72 | 4 directions | immobile, marche | Meshy |
| Petits Esprits (Bourru…) | 48×48 | face seule | flottement | Meshy |
| Créatures moyennes | 96×96 | 4 directions | immobile, déplacement, capacité, touché | Meshy |
| Grands Esprits / boss | 192×192 et + | face (ou 4 dir) | immobile, attaques, touché | Meshy |
| Bâtiments | multiples de 48 | 3/4 dessus (**1 vue**) | — (toit parfois séparé) | Meshy ou ChatGPT |
| Tuiles de sol (tilesets) | **48×48** (raccordables) | dessus | eau : 2–4 frames | ChatGPT |
| Props de décor | 48×48 à 96×96 | 3/4 (1 vue) | parfois (coffre qui s'ouvre) | ChatGPT / Meshy |
| Objet — sprite au sol | 48×48 | 1 vue | — | ChatGPT / Meshy |
| Objet — icône d'inventaire | 96×96 (carré) | 1 vue | — | ChatGPT / Meshy |
| Arme — icône | 96×96 | 1 vue | — | Meshy |
| UI : boutons / icônes | 96×96 | — | états (normal / pressé) | ChatGPT |
| UI : panneaux (dialogue…) | redimensionnable (**9-slice**) | — | — | ChatGPT |
| Portraits de dialogue | 512×640 (buste) | face | 2–4 expressions | ChatGPT ou Meshy |
| Splash / illustrations | 1920×1080 | — | — | ChatGPT |
| VFX | spritesheet 6–12 frames / textures 64×64 | — | oui | ChatGPT |

*La colonne « prises de vue » répond à ta question : pour les êtres vivants, on produit **4 angles** (bas/haut/gauche/droite). Astuce : le profil **gauche peut être le miroir** du droit, ça divise le travail par deux. Décors, bâtiments et objets = **une seule vue** en 3/4.*

---

## Conventions globales

- **Format images** : `PNG-24` avec **transparence (alpha)**. Sprites sur **fond transparent**. Tilesets aussi en PNG.
- **Style** : illustré/peint, cohérent (palette commune, lumière venant **du haut**, contour optionnel mais constant).
- **Unité de base** : la **tuile = 48×48 px**. Toutes les tailles sont pensées en multiples de 48.
- **Pivot des personnages** : pieds centrés en bas du cadre (pour bien poser le perso sur la carte).
- **Cohérence (le point clé avec l'IA)** : toujours réutiliser des **images de référence** et un **prompt fixe** par personnage/créature pour garder le même style sur tous les angles. C'est là que **Meshy** brille (un seul modèle 3D → tous les angles identiques).

---

## Convention de nommage des fichiers

Tout en **minuscules**, **sans accents ni espaces**, séparé par des `_`.

**Préfixes par type :**
`char_` (héros), `npc_` (PNJ), `creature_`, `build_` (bâtiment), `tile_`, `prop_`, `item_`, `weap_`, `ui_`, `vfx_`, `port_` (portrait), `illus_`, `music_`, `sfx_`.

**Animations** — soit en images séparées, soit en spritesheet (grille régulière) ; Godot lit les deux.
- Séparées : `char_aela_walk_down_01.png`, `_02.png`…
- Spritesheet : `char_aela_walk.png` (grille régulière, frames de taille égale).

**Directions** : `down`, `up`, `left`, `right` (le `left` peut être le `right` en miroir).

Exemples : `creature_mousseline_idle_down_01.png` · `tile_grass_01.png` · `build_vaylor_auberge.png` · `ui_button_action_pressed.png` · `port_come_sourire.png`.

---

## Fiches par catégorie (nuances)

**Personnages** — 4 directions. Héros (Aëla, Côme) : immobile (2–4 frames), marche (4–6 frames/dir), + parler et action. PNJ secondaires : immobile + marche suffisent.

**Créatures / Esprits** — petits flottants : une vue face animée (flottement). Moyens : 4 directions + capacité + touché. Boss : grande taille, face, plusieurs attaques.

**Bâtiments** — une vue 3/4 dessus, base alignée sur la grille de 48. Pour les bâtiments où l'on entre, fournir le **toit en calque séparé** (il s'efface quand le perso entre).

**Tilesets (sols)** — tuiles **raccordables** (seamless) de 48×48, livrées par famille (herbe, terre, pierre, eau, neige, marais, cendre). Prévoir des **bords/coins** ou me prévenir : Godot peut générer les transitions (autotile). Eau = 2–4 frames d'animation.

**Props de décor** — PNG transparents, 3/4. Coffres : 2 états (fermé/ouvert).

**Objets** — **deux livrables** par objet : le **sprite au sol** (48×48) ET l'**icône d'inventaire** (96×96, cadrage carré cohérent).

**Armes & équipement** — icône 96×96 obligatoire ; sprite « en main » optionnel (par direction) si l'arme est visible sur le perso.

**UI / HUD** — conçue pour **1920×1080**. Icônes/boutons 96×96 avec 2 états (normal/pressé). Panneaux (boîte de dialogue, fenêtres) en **9-slice** (une petite image étirable) pour s'adapter à toutes les tailles. Joystick virtuel ~200 px.

**VFX** — animations en **spritesheet** (6–12 frames) pour les pouvoirs/impacts, ou petites **textures douces 64×64** pour les particules (pétales, flocons…). La **transition de saison** et le **Grand Silence** se font surtout *dans le moteur* (teinte + particules) → peu d'images à fournir.

**Portraits** — buste 512×640, fond transparent, **2 à 4 expressions** par personnage important (neutre, joie, surprise, tristesse).

**Illustrations** — splash/écran-titre et cutscènes en **1920×1080**.

---

## Audio (Suno)

- **Musiques** : format **OGG** de préférence (bonnes boucles), **MP3** accepté. Durée **60–120 s** en **boucle**. À produire : thème principal, un thème par région, combat, boss, émotion, victoire.
- **Effets sonores** : **WAV** ou OGG, courts (pas, menu, attaque, cri d'Esprit, énigme résolue, ramassage, level-up).
- Nommage : `music_theme_principal.ogg`, `music_region_vaylor.ogg`, `sfx_pickup.wav`…

---

## Aperçu de l'arborescence (préparation de l'étape 4)

```
Sylvelinne/
└── assets/
    ├── characters/
    ├── creatures/
    ├── buildings/
    ├── tilesets/
    ├── props/
    ├── items/
    ├── weapons/
    ├── ui/
    ├── vfx/
    ├── portraits/
    ├── illustrations/
    └── audio/
        ├── music/
        └── sfx/
```

C'est exactement cette structure que je te livrerai en **zip** à l'étape 4 — il te suffira d'y déposer tes fichiers au bon endroit, en respectant le nommage ci-dessus.

---

## Étape suivante (4)

Je peux te monter dès maintenant le **squelette du projet Godot** avec cette arborescence (et même un petit niveau de test jouable), pour que tu n'aies plus qu'à **glisser tes assets** au fur et à mesure. Tu testes, ça tourne, et on remplit petit à petit.
