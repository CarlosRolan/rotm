class_name RaceData
extends Resource
## One playable Kaurka subrace, as shown on the race-selection screen. The instances live
## in `res://data/races/`; the canon behind the texts is `docs/lore/kaurkas.md`.

@export var id := ""
@export var display_name := ""  ## plural, as the race is named ("Escamaduras")
@export var singular := ""  ## one of them ("Escamadura")
@export var epithet := ""
@export_multiline var lore := ""  ## BBCode allowed
@export var height_text := ""
@export var strength := ""
## Height (metres) the viewer scales the model to, inside the canon range.
@export var height_m := 2.0
## File name (without .glb) of the race's own mesh anywhere under `imported_models/`.
@export var mesh_name := ""
## Rigged model used until the race's own mesh is rigged (and shown if it doesn't exist).
@export_file("*.glb") var fallback_model := ""
@export var background: PackedScene
@export var accent := Color.WHITE
