class_name RaceCatalog
## The playable Kaurka subraces and which model each one uses. A race's own mesh is
## `imported_models/**/<mesh_name>.glb`; until it is rigged, the test level plays the race's
## fallback model instead, and the selection screen says so.

const RACES := ["res://data/races/tiemblatierras.tres", "res://data/races/escamaduras.tres",
		"res://data/races/sonrientes.tres"]


static func all() -> Array[RaceData]:
	var out: Array[RaceData] = []
	for path: String in RACES:
		out.append(load(path) as RaceData)
	return out


static func find(id: String) -> RaceData:
	for race in all():
		if race.id == id:
			return race
	return null


## The race's own mesh, or "" if it hasn't been delivered yet.
static func race_mesh(race: RaceData) -> String:
	for path in ModelCatalog.glb_files():
		if path.get_file().get_basename() == race.mesh_name:
			return path
	return ""


## What the selection screen shows: the race's own mesh if there is one, rigged or not.
static func preview_model(race: RaceData) -> String:
	var own := race_mesh(race)
	return own if own != "" else fallback(race)


## What the test level plays: the race's own mesh once it is rigged, else the fallback.
static func playable_model(race: RaceData) -> String:
	var own := race_mesh(race)
	return own if own != "" and ModelCatalog.is_rigged(own) else fallback(race)


static func fallback(race: RaceData) -> String:
	return race.fallback_model if ResourceLoader.exists(race.fallback_model) else ModelCatalog.DEFAULT_MODEL


## Tells the player when the model shown or played isn't the race's own, rigged one yet.
static func notice(race: RaceData) -> String:
	var own := race_mesh(race)
	var stand_in := model_name(fallback(race))
	if own == "":
		return "Aún no hay modelo de %s: se muestra «%s» de forma provisional." % [race.singular, stand_in]
	if not ModelCatalog.is_rigged(own):
		return "Este modelo aún no tiene esqueleto, así que se ve en su pose por defecto. En la escena de pruebas se usará «%s»." % stand_in
	return ""


static func model_name(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ")
