# CSV Parsing

The data parser for the game **Afterglow Bytes: Reverie by the Shore**. It is a desktop tool that turns the game's design spreadsheets (exported from Google Sheets as CSV) into the JSON data files the game reads. It contains no gameplay, only the data pipeline and a small editor UI. Built with Godot 4.5.

## Download

Grab the latest `AIO-Parser-windows.zip` from the [Releases page](https://github.com/BlueMiku/csv-parsing/releases/latest), unzip it, and run the exe. It is a single file with nothing to install.

The app checks for new versions at startup. If one is available it shows the release notes and an **Update** button; the app then downloads the new exe, verifies its checksum, replaces itself, and restarts. This only works in the exported Windows build, and the app must live in a folder you can write to (not `Program Files`). The current version is shown in the title bar.

## Using it

1. Click **Browse** and pick a CSV file.
2. The tool detects the file type from its header row and highlights it in the type bar. If the format isn't recognized it says so instead of guessing.
3. Choose where the JSON should be written (it defaults to next to the CSV).
4. Fill in anything the type needs (see the table below), then click **Generate**.

Files with problems still generate; the tool lists the warnings and offers to jump to the affected rows in the built-in JSON viewer/editor. A few warnings are serious enough that the file is not saved automatically so you can review it first.

### Supported file types

| Type | Notes |
|---|---|
| Dialog | Can filter by chapter before generating. |
| Ingredient, Recipe, Beverage, Decoration, Key Item | Treated as "Items". Generating one asks for confirmation, then converts **every Items CSV in that folder** and merges them into a single JSON (Cancel aborts, nothing is written). **Recipe needs the Ingredient CSV in the same folder** to resolve ingredient and seasoning names to ids. Without it those ids become `-1` (a warning is logged). |
| Patron | Works on a whole folder: the Patrons, Story, Orders and IdleTalk CSVs must all be there (they are matched by header, not file name). Pick the character to export from the list. |
| NPC Properties | Reads two files from the same folder, which must be named exactly `Colors.csv` and `NPC Parser Sheet.csv`. |
| Game Settings, SFX, Music, Blip | Straightforward one-file conversions. |
| Area Trigger | Needs an area name; it is filled in from the file name when possible. Output is merged into the existing JSON if one is already there. |
| Game Events, Cutscene Triggers, Shop Sets | One file each. Cutscene triggers are grouped by `Moment` (NewDay, BeforeOpen, AfterClose). |
| Credits, Gallery CG, Gallery Artwork | One file each. |
| Archive Profiles, Archive Profile Content | The master archive list and the per-character content sheets. Archive Profiles can also write a chapter lookup file. |
| Extra Functions | `extra_function_name` becomes the key, and every other column (except `no`) becomes a field in its object. `requested_item` is split into `[type, id, qty]`. |

### JSON viewer / editor

A second screen (reachable from the main window) opens any JSON file as a tree. You can search, expand or collapse, edit values, and add or delete keys, then save.

## Building from source

You need [Godot 4.5](https://godotengine.org/download) (with the Windows export templates for exporting). Open `project.godot` and run, or:

```
godot --path .
```

### Releasing a new version

1. Bump `config/version` in `project.godot`.
2. Commit and push.
3. Run the release script. It exports the Windows build, zips it as `AIO-Parser-windows.zip` (the updater looks for that suffix), and uploads it to GitHub Releases using the `gh` CLI:

```powershell
.\tools\release.ps1 -Publish -Target <commit-sha>
```

Without `-Publish` it creates a draft, which is invisible to the public and has no tag yet. The script's defaults assume Godot at `D:\Godot\4.5`; override with `-GodotExe`.

## How it's put together

```
UI/Main/        Main window, type detection (CSVConfig), orchestration (CSVProcessor), updater
UI/JSON UI/     JSON viewer/editor
Data/           Parsing and transformation, no UI
```

There are two kinds of converters:

- **Schema-driven** (Dialog, Items, SFX, Music, Blip, Game Settings): `Data/DataSchemas.gd` describes each column and `Data/Parser.gd` + `Data/Json_generate.gd` do the work.
- **Dedicated processors** (everything else): one small class per CSV type under `Data/<Name>Manager/`. They read columns by header name, so reordering or adding columns in the sheet is usually safe.

To add a new CSV type, register it in `UI/Main/CSVConfig.gd`, write a processor (copy a small one such as `CreditsProcessor` or `ExtraFunctionsProcessor`), and wire it into `CSVProcessor.gd` and `Main.gd`. More detail on conventions is in [`.github/agents/AGENTS.md`](.github/agents/AGENTS.md).

Code comments and runtime messages are in Bahasa Indonesia.
