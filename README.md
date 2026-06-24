# 🌿 Sylvelinne — projet de jeu (Godot 4.7)

Un RPG 2D en monde ouvert (vue de dessus, carte scrollable) façon Ni no Kuni.
Ce dépôt contient un **squelette jouable** : une carte qui défile + un personnage
qui se déplace (placeholders), prêt à être rempli avec tes propres assets, et
configuré pour **fabriquer l'APK automatiquement sur GitHub**.

---

## 📁 Contenu

```
Sylvelinne/
├── project.godot              # le projet Godot
├── scenes/Main.tscn           # scène principale
├── scripts/world.gd           # carte de test + perso + contrôles
├── icon.svg                   # icône du jeu
├── export_presets.cfg         # réglages d'export Android
├── .github/workflows/         # build automatique de l'APK (GitHub Actions)
├── docs/                      # toute la conception (histoire, assets, specs)
└── assets/                    # ⬅️ TES images/sons vont ici
    ├── characters/  creatures/  buildings/  tilesets/  props/
    ├── items/  weapons/  ui/  vfx/  portraits/  illustrations/
    └── audio/music/  audio/sfx/
```

---

## ✅ Prérequis

- **Godot 4.7** (gratuit) — https://godotengine.org/download
- Pour fabriquer l'APK toi-même en local : **JDK 17** + **Android SDK** (voir Option A).
- Pour la fabrication automatique : un **compte GitHub** (voir Option B).

> ⚠️ **Le piège n°1** des exports Android, c'est le **décalage de versions**.
> L'éditeur Godot, les *export templates* et le JDK doivent correspondre.
> Ici tout vise **Godot 4.7 + JDK 17**. Garde la même version partout.

---

## ▶️ Tester tout de suite sur PC

1. Ouvre **Godot 4.7**, clique **Import**, choisis le fichier `project.godot`.
2. Appuie sur **F5** (Play). Tu peux déplacer le carré aux **flèches** du clavier.

C'est le moment de remplacer les placeholders par tes assets.

---

## 📱 Option A — Fabriquer l'APK en local (le plus fiable)

1. Installe **JDK 17** et l'**Android SDK** (Android Studio l'installe, ou les
   *command-line tools*).
2. Dans Godot : **Éditeur → Réglages de l'éditeur → Export → Android** : indique
   le chemin du **JDK** et du **SDK**.
3. **Projet → Exporter…** : le preset **Android** est déjà là.
4. Bouton **Exporter le projet**, nomme le fichier `Sylvelinne.apk`.
5. Copie l'APK sur ton téléphone, ouvre-le, autorise *"Sources inconnues"*, installe.

> 💡 Encore plus rapide pour tester : branche le téléphone en **USB** (débogage USB
> activé). Une petite **icône Android** apparaît en haut à droite de Godot : un clic
> installe et lance le jeu sur ton téléphone, avec les erreurs en direct.

---

## ☁️ Option B — Fabrication automatique sur GitHub *(ce que tu veux faire)*

Tu pousses le projet, **GitHub construit l'APK pour toi**, tu le télécharges.

1. Crée un dépôt GitHub (**public** de préférence → minutes d'Actions **illimitées** ;
   en privé tu as 2 000 min/mois gratuites, largement suffisant).
2. Envoie le projet dans le dépôt :
   ```bash
   git init
   git add .
   git commit -m "Sylvelinne — squelette jouable"
   git branch -M main
   git remote add origin https://github.com/TON-COMPTE/Sylvelinne.git
   git push -u origin main
   ```
3. Va dans l'onglet **Actions** du dépôt. Le workflow **« Build Android APK »**
   se lance tout seul (ou clique **Run workflow**).
4. Quand c'est vert ✅, ouvre le run → section **Artifacts** → télécharge
   **`Sylvelinne-debug-apk`**. Dézippe → tu obtiens **`Sylvelinne.apk`**.
5. Installe-le sur ton téléphone (autorise *"Sources inconnues"*).

> 🛠️ **Si le build échoue sur le preset d'export** : ouvre une fois le projet dans
> Godot 4.7, va dans **Projet → Exporter…**, laisse Godot réparer/réenregistrer le
> preset, puis recommit + push. (Godot régénère un `export_presets.cfg` parfait.)
>
> 🛠️ **Si le téléchargement de Godot renvoie une erreur 404** : la version a peut-être
> changé. Modifie la ligne `GODOT_VERSION: "4.7"` dans
> `.github/workflows/build-android.yml` (et vérifie le nom exact du fichier sur la
> page des *releases* `godotengine/godot-builds`).

---

## 🎨 Ajouter tes assets

1. Dépose tes fichiers dans le bon dossier de `assets/` (voir l'arborescence).
2. Respecte la **convention de nommage** définie dans
   `docs/Fiches_Techniques_Assets_Sylvelinne_v1.md`
   (ex. `char_aela_walk_down_01.png`, `tile_grass_01.png`, `music_theme_principal.ogg`).
3. Dans Godot, glisse l'asset dans la scène, ou modifie `scripts/world.gd` pour
   l'utiliser à la place des placeholders.

Tailles, prises de vue (4 directions), formats et animations : **tout est dans
`docs/`** — c'est la référence à suivre pour produire les images avec Meshy /
ChatGPT et les musiques avec Suno.

---

## 📚 Conception (dossier `docs/`)

- `Sylvelinne_Bible_Narrative_v1.md` — histoire, monde, personnages, quêtes, énigmes.
- `Liste_Assets_Sylvelinne_v1.md` — inventaire complet des assets à produire.
- `Fiches_Techniques_Assets_Sylvelinne_v1.md` — tailles, formats, vues, nommage.

---

## 🧭 Prochaines étapes possibles

- Une vraie **TileMap** (tuiles 48×48) à la place du fond de test.
- Un **joystick tactile visible** + bouton d'action à l'écran.
- Le **système de dialogues** et le **menu des Esprits**.

Bon développement ! 🌱
