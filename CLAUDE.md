# ROTM

Godot 4.7.2 third-person action RPG prototype. Playable race: the Kaurkas (lizardmen),
with a Valheim-style low-poly pixel-texture look and a dark, brutal tone.
The user writes in Spanish; reply in Spanish.

## Where to look

- **Art direction** (graphics, colour, lighting, environments, gore): `docs/arte/estilo_artistico.md`,
  with style reference images in `docs/arte/referencias/`. Read it before any visual change.
  Core rule: retro look (low poly, pixelated textures, Valheim / Risk of Rain 2,
  Torchlight 2 colours), modern feel (fluid animation, terrain-aware interaction).
- **Lore and creature design** (races, subraces, anatomy, behaviour):
  `docs/lore/kaurkas.md`. Read it before any character design, model, animation or
  art-direction change. The written text overrides the reference images.
- **Reference images**, one folder per subrace. Look at them, together with the lore
  doc, whenever a design or animation change concerns that subrace:
  - Tiemblatierras: `docs/lore/tiemblatierras/`
  - Escamaduras: `docs/lore/escamaduras/`
  - Sonrientes: `docs/lore/sonrientes/`
- **Character-creator variations** the player can pick for each subrace (body type, bony
  protrusions, etc.): `variaciones.md` inside each subrace folder above. Update it when the
  user decides a new selectable trait.
- **Player movement**, environment interaction and tunable parameters:
  `docs/movimiento_jugador.md`. Read it before working on the player, and update it when
  movement capabilities change.

Keep these docs current: when the user settles a design question or adds a capability,
update the matching doc in the same session.

## Meshes

- One folder per subrace mesh, named `imported_models/mesh_<subraza>/mesh_<subraza>.glb`
  (`mesh_escamadura`, `mesh_tiemblatierra`, ...). Keep this naming for new meshes.
- `imported_models/saurian-test-dummy-proxy/` is the rigged test dummy the game uses now.
- From now on the user delivers meshes **already rigged** (with a skeleton). When a new one
  arrives, check its bone names against `scripts/saurus_pose.gd` (expects Mixamo-style
  `mixamorig_*` names), its animations, scale, orientation and vertex count before wiring it in.
  Repose or edit using that skeleton, never a hand-made one.
- Mesh edits are done in Blender (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`);
  never overwrite an original mesh.

## Tools

- Godot executable: `C:\Users\Rolan\godot\Godot_v4.7.2-stable_win64_console.exe`.
- Gait regression test: `--headless --path . -s res://tools/gait_test.gd`.
