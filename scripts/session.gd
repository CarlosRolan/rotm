extends Node
## Autoload "Session": what the player chose before entering the test level, kept across
## scene changes. Empty when the level was opened from Debug, which then uses the model
## picked in the level's own menu (see ModelCatalog.initial).

var race: RaceData
var model_path := ""
## Shown in the test level when the race's own model isn't playable yet.
var notice := ""


func choose_race(chosen: RaceData) -> void:
	race = chosen
	model_path = RaceCatalog.playable_model(chosen)
	notice = ""
	if model_path != RaceCatalog.race_mesh(chosen):
		notice = "Modelo provisional: «%s» (los %s aún no tienen un modelo con esqueleto)." % [
				RaceCatalog.model_name(model_path), chosen.display_name]


func clear() -> void:
	race = null
	model_path = ""
	notice = ""
