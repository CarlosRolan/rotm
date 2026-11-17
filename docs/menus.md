# Menús: portada y selección de raza

Cómo se entra al juego, cómo funciona la pantalla de selección de raza y dónde está cada
cosa. El lore de las razas está en `docs/lore/kaurkas.md` y la dirección de arte en
`docs/arte/estilo_artistico.md`.

## Flujo

```text
Portada (start_menu)
  ├─ Start ─► Selección de raza ─► Entrar ─► Escena de pruebas con el modelo de esa raza
  ├─ Debug ─────────────────────────────► Escena de pruebas con el modelo de siempre
  └─ Salir
```

- **La portada es la escena principal del proyecto.** Al darle a Play en Godot se abre la
  portada.
- **Debug** entra con el último modelo elegido en el menú Tab de la escena de pruebas, o el
  Crystal Sentinel por defecto.
- **En la escena de pruebas, Tab** abre el menú de modelos, que tiene un botón **Menú
  principal** para volver a la portada.
- Para abrir la escena de pruebas directamente (F6 en el editor), se comporta como Debug.

## Pantalla de selección de raza

- **Izquierda:** las tres subrazas: Tiemblatierras, Escamaduras y Sonrientes.
- **Centro:** el visor del modelo, sobre un fondo propio de cada raza.
- **Derecha:** nombre, epíteto, descripción de lore, altura y en qué destaca.
- **Abajo:**
  - las animaciones del modelo, o "pose por defecto" si no tiene;
  - **Volver** (o Esc) para ir a la portada;
  - **Entrar** para ir a la escena de pruebas.

### Visor

- **Arrastrar con el ratón** gira el modelo **80° a cada lado** (160° en total) e inclina la
  cámara **15° arriba o abajo**. Ni un grado más.
- **Tamaño:** el modelo se escala a la altura de su raza: Tiemblatierras 2,15 m,
  Escamaduras 2,0 m y Sonrientes 1,65 m.
- **Encuadre:** la cámara se ajusta a esa altura.
- **Animaciones:**
  - Si el `.glb` trae animaciones, se reproduce la primera en bucle y hay un botón para
    cada una.
  - Si no trae ninguna, el modelo se queda en su pose por defecto.
- **Cambio de raza:** se hace con un fundido a negro corto.

### Qué modelo se usa en cada raza

Cada raza busca su malla propia por nombre en cualquier carpeta de `imported_models/`:

| Raza | Malla propia | Modelo provisional |
|---|---|---|
| Tiemblatierras | `mesh_tiemblatierra.glb` | Crystal Sentinel |
| Escamaduras | `mesh_escamadura.glb` | saurian-test-dummy-proxy (el lore lo da por prototipo de Escamadura) |
| Sonrientes | `mesh_sonriente.glb` (aún no existe) | Crystal Sentinel |

- **Visor:** enseña la malla propia si existe, aunque no tenga esqueleto. Si no existe,
  enseña el modelo provisional.
- **Escena de pruebas:** usa la malla propia **solo si tiene esqueleto Mixamo**, porque la
  locomoción la necesita. Si no, usa el modelo provisional.
- **Avisos:** cuando el modelo no es el definitivo, la selección lo indica en naranja, y la
  escena de pruebas también al entrar.
- **Al llegar las mallas con rig:** basta con dejar `mesh_<subraza>.glb` en
  `imported_models/mesh_<subraza>/` y la raza la usa sin tocar código.
- **Cambiar los modelos provisionales:** en `fallback_model` de cada `data/races/*.tres`.

### Fondos

Todos están hechos en Godot con geometría low poly, texturas pixeladas (`PixelTex`), luces
de color, niebla y partículas.

- **Escamaduras:** campamento de guerra en un cañón de roca roja al atardecer, en la
  superficie.
  - Estrado de piedra, empalizada de estacas afiladas con calaveras de bestia en la puerta y
    choza con techo de pieles flanqueada por colmillos.
  - Costillar de una gran presa, braseros con fuego y ascuas, y estandartes rojos que
    ondean.
  - Polvo en el aire y mesetas que se pierden en la calima.
- **Tiemblatierras:** poblado tipo tauren, pero dentro de una gran caverna en vez de en una
  pradera.
  - Tiendas de piel pintadas, tótems tallados con alas y una hoguera.
  - Prado de hierba que se mece.
  - Cristales púrpura y hongos verdes luminosos.
  - Estalactitas y un haz de luz que entra por una grieta del techo.
- **Sonrientes:** pantano al anochecer.
  - Gran sauce con cientos de ramas colgantes que se mecen.
  - Charcas oscuras con reflejos, nenúfares, lenteja de agua, juncos y espadañas.
  - Árboles muertos en la niebla verde y bulbos púrpura luminosos.
  - Luciérnagas y nubes de mosquitos sobre el agua.

## Estructura de archivos

```text
scenes/menus/
  start_menu.tscn                         portada
  race_select/
    race_select.tscn                      selección de raza
    backgrounds/
      escamaduras_bg.tscn
      tiemblatierras_bg.tscn
      sonrientes_bg.tscn
scripts/menus/
  start_menu.gd
  menu_theme.gd                           estilo común de los menús (paneles, botones, textos)
  scene_paths.gd                          rutas de las escenas del flujo
  race_select/
    race_select.gd                        pantalla, cámara, interfaz y fundido
    model_preview.gd                      visor: escala, giro y animaciones
    backgrounds/
      race_background.gd                  base de los fondos: materiales, fuego, luces, partículas
      escamaduras_bg.gd / tiemblatierras_bg.gd / sonrientes_bg.gd
scripts/races/
  race_data.gd                            recurso RaceData (los datos de una raza)
  race_catalog.gd                         lista de razas y qué modelo usa cada una
scripts/world/low_poly.gd                 generador de geometría low poly (rocas, tubos, terreno...)
scripts/session.gd                        autoload Session: la raza elegida al cambiar de escena
shaders/foliage_sway.gdshader             vegetación que se mece (sauce, juncos, hierba)
data/races/                               una ficha .tres por raza
```

### Cambiar textos o añadir una raza

- **Textos:** nombre, epíteto, lore, altura y fortaleza están en `data/races/<raza>.tres`, y
  se pueden editar en el Inspector de Godot. Deben seguir el canon de
  `docs/lore/kaurkas.md`.
- **Nueva raza:**
  1. Crear su `.tres`.
  2. Crear su fondo: un script que herede de `RaceBackground` y su escena.
  3. Añadir la ruta en `RaceCatalog.RACES`.

## Herramientas de prueba

- **Captura de cualquier escena:**
  `Godot_console.exe --path . -s res://tools/scene_shot.gd -- <escena.tscn> <salida.png> [fotogramas]`.
- **Opciones de la selección de raza**, que se añaden detrás:
  - `--race=<id>`: raza inicial.
  - `--shot-yaw=<grados>` y `--shot-pitch=<grados>`: vista inicial.
  - `--anim=<nombre|pose>`: animación inicial.
  - `--no-ui`: ocultar los paneles para ver el fondo entero.
