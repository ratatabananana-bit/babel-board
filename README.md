# Table Helper

A phone app for playing board games you can't read. Table Helper itself has no games built
in: each game is a **module**, data only (cards, pictures, rules text, and screens made from a
fixed set of blocks). Modules install from a private repository, a link, or a file.

Version 3.0.0. Android APK (sideloaded) plus a web preview.

## Layout

| Folder | What's there |
|---|---|
| `lib/module_format/` | Pure-Dart module model, path/filter language and validator (shared with `tool/`). |
| `lib/modules/` | Loading a module from disk, HTTP or memory; per-module saved state. |
| `lib/blocks/` | The fixed block catalog: gallery, board, zone, card list, flow, step, text. |
| `lib/library/` | Module store (install/update/uninstall), repository client, Library screen, migration. |
| `modules/` | `MODULE_SPEC.md`, `AI_INSTRUCTIONS.md`, `module.schema.json`, and the two games as modules. |
| `tool/` | `validate.dart`, `pack.dart`, `screenshot_test.dart`, and the one-off `convert_legacy.dart`. |

## Writing a module

Read `modules/MODULE_SPEC.md`. On the phone, the Library's ⋮ menu has **Copy instructions for
AI**: paste that into Claude or ChatGPT with "write me a module for *Heat*", save the JSON it
replies with, and open it with Table Helper (or use **Install from file**).

Check a module before publishing:

```bash
dart run tool/validate.dart modules/vale-of-eternity
```

## Making modules

See [docs/CREATING_MODULES.md](docs/CREATING_MODULES.md): the quick way (paste the
copied instructions into an AI, install the JSON it answers with) and the full way (a module
folder, the validator, packing a repository for friends).

## Publishing to the private repository

The repository is a private GitHub repo holding static files: zips, icons and `index.json`.

1. Pack every module into a checkout of the private repo:

   ```bash
   dart run tool/pack.dart modules ../table-helper-modules --name "Benny's games"
   ```

2. Commit and push that checkout. Raise a module's `version` in its `module.json` before
   packing, or the app won't offer the update.
3. On GitHub, create a **fine-grained personal access token** for that one repository with
   **Contents: Read-only** and nothing else.
4. On the phone: Library → ⋮ → **Add repository**. Paste the raw link to the index, e.g.
   `https://raw.githubusercontent.com/<owner>/<repo>/main/index.json`, and the token. Save
   checks the connection and says what's wrong if it can't read it.

The token is kept in Android's secure storage and only sent to the index's own host. Raw
GitHub links can take a few minutes to show a fresh push.

## Rolling out 3.0.0 (from 2.x with built-in games)

1. Publish both modules to the private repository first (steps above).
2. Install the new APK. The Library opens empty; add the repository.
3. Install Vale of Eternity and Magical Athlete from it. Saved progress (tracked cards, the
   race lineup, round/flow position) moves into each module the first time it's installed,
   and the app reopens the last game you played.

## Building

```bash
flutter build apk --release --split-per-abi
```

The arm64 APK is copied to `TableHelper.apk` for sideloading.

Web preview (shows the modules from `modules/`, no installing):

```bash
flutter build web --release
```

```bash
dart run tool/pack.dart modules build/web/modules --unpacked
```

## Tests and screenshots

```bash
flutter test
```

```bash
flutter test tool/screenshot_test.dart
```

Screenshots land in `design/screenshots/`.
