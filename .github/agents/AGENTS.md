# AGENTS.md — CSV Parsing Tool (Godot 4.5)

## Project Overview
A Godot 4.5 desktop tool that converts game data CSV spreadsheets into JSON files. Built for the game Afterglow Bytes: Reverie by the Shore. No gameplay logic — only data pipeline and editor UI.

## Architecture

```
UI/Main/          → Godot Control scenes + UI managers (no parsing logic)
Data/             → Pure parsing/transformation (no UI nodes)
Data/PatronManager/ → Isolated patron-specific pipeline
GlobalData.gd     → Autoload singleton: inter-scene data transfer only
```

**Core pipeline:**
`CSV file` → `CSVParser` (`Data/Parser.gd`) → `JSONGenerator` (`Data/Json_generate.gd`) → `.json` output

**Patron pipeline** (separate, folder-based):
`folder/ (4 CSVs)` → `PatronDataLoader` → `PatronValidator` → `PatronParser` → `PatronTransformer` → `.json`

## CSV Types & Auto-Detection
All supported types are declared in `CSVConfig.CSVType` enum (`UI/Main/CSVConfig.gd`). Type is **auto-detected from CSV headers** via `TYPE_CONFIGS[type].header_patterns`. Never hardcode a type — let `CSVConfig.detect_type(path)` resolve it.

Supported: `DIALOG`, `INGREDIENT`, `RECIPE`, `BEVERAGE`, `DECORATION`, `KEY_ITEM`, `PATRON`, `NPC_PROPERTIES`, `GAME_SETTINGS`, `SFX`, `MUSIC`.

## Schema-Driven Pattern
Every CSV type has a schema in `Data/DataSchemas.gd`:
```gdscript
"fieldKey": {"header_name": "CSV Column Name", "type": "string|int|float|bool|array|...", "default": ..., "is_id": true}
```
`FieldTransformers.transform()` handles all type conversions. **Add new field types there**, not inline.

To add a new CSV type: add schema + key_order + config in `DataSchemas.gd`, add type entry in `CSVConfig.TYPE_CONFIGS`, add `configure_for_X()` in `JSONGenerator`, wire in `CSVConfig.configure_all()`.

## Builder Pattern (CSVParser & JSONGenerator)
Both use method chaining — all setters return `self`. Never set properties directly.
```gdscript
parser.set_schema(schema).set_group_header("chapter").set_start_row(4)
```
Use `CSVConfig.configure_all(_parser, _json_generator, csv_type)` to configure both at once.

## ParseMode
`CSVParser.ParseMode.STRUCTURE_ONLY` — fast, used only to load chapter/group names for UI checkboxes.  
`CSVParser.ParseMode.FULL_VALIDATION` — used for actual generation; populates `parsing_errors`, `warning_row_ids`, `warning_details`, `fatal_warnings`.

## Errors vs Warnings
- `parsing_errors` → hard fail, block generation  
- `warning_details` (`Array[Dictionary{id, column}]`) → soft, generation proceeds, opens JSON editor  
- `fatal_warnings` → generation proceeds but **prevents auto-save** (`prevent_auto_save: true`)

The `processing_warning` signal on `CSVProcessor` carries all warning data to the UI layer.

## GlobalData Autoload
Used **only** to pass data from `Main.gd` to `JsonUI` scene (different scene). Always call `get_and_clear_pending_data()` after reading — it clears state. Don't use it for intra-scene communication.

## NPC Properties — Special Case
`NPCProperties.gd` reads **two CSV files from a directory** (`Colors.csv` + `NPC Parser Sheet.csv`), not a single file. It does not use `CSVParser`; it has its own internal parsing logic.

## MergeSystem
`UI/MergeSystem.gd` merges multiple JSON files by appending array values under matching root keys. Used for Items-type CSVs (`INGREDIENT`, `RECIPE`, `BEVERAGE`, `DECORATION`, `KEY_ITEM`) — these prompt a merge confirmation before writing.

## Conventions
- **Comments and variable names are in Bahasa Indonesia** — maintain this in all new code.
- `class_name` is declared on every reusable script; `extends Node` for scripts added as children, `extends RefCounted` for pure-logic classes.
- `print("[ClassName] ...")` for debug logs — always prefix with class name in brackets.
- Key files: `Data/DataSchemas.gd` (source of truth for schemas), `UI/Main/CSVConfig.gd` (type registry), `UI/Main/CSVProcessor.gd` (orchestration).

