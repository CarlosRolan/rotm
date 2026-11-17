# Movimiento del jugador: estado actual

Qué sabe hacer hoy el personaje (el Saurus), cómo está montado y qué se puede ajustar.
Sirve para retomar el trabajo en cada sesión sin leer el chat. Si algo cambia, actualiza
este documento.

Proyecto: Godot 4.7.2, física Jolt. Juego en tercera persona tipo Dark Souls / Valheim,
con aspecto pixelado de baja poligonización como Valheim y tono oscuro y brutal.
Protagonistas: hombres lagarto (tipo Saurus de Warhammer) que escapan del subsuelo.

---

## 1. Qué sabe hacer el muñeco

| Capacidad | Cómo se ve / cómo funciona |
|---|---|
| **Andar / correr / esprintar** | Andar 2 m/s, correr 4,5 m/s (por defecto), esprintar 7 m/s. Cada ritmo tiene su cadencia, largo de paso, inclinación del cuerpo, bote y balanceo de brazos. |
| **Pies que se adaptan al terreno** ("efecto Elden Ring") | Cada pie busca el suelo real con un rayo y se planta ahí: piedra, escalón o rampa. Si un pie pisa más bajo, la cadera baja para que llegue. Los pies no se deslizan ni atraviesan el suelo. |
| **Levantar la pierna sobre obstáculos** | Al dar un paso, la pierna sube lo justo para pasar por encima de lo que haya entre el pie de atrás y el de delante (p. ej. una piedra). |
| **Pasitos al pararse o girar** | Parado, si un pie queda mal colocado tras girar o frenar, da un paso corto para recolocarse. |
| **Reacción al moverse** | Se inclina hacia delante al acelerar, hacia atrás al frenar y hacia dentro en las curvas. La cola se levanta al correr y oscila. Parado respira y mira alrededor. |
| **Subir escalones** | Escalones de hasta 0,45 m los sube solo, andando. |
| **Encaramarse** (bordes bajos) | Bordes de 0,45 a 1,5 m sobre los pies: pulsa **Espacio** delante y se sube con las manos. |
| **Saltar** | **Espacio** donde no hay borde que escalar. En el aire encoge las piernas y estira hacia abajo al caer. Al aterrizar absorbe el golpe. |
| **Agarrarse a cornisas y colgarse** | Saltando contra un muro alto, se agarra solo al borde (hasta 2,6 m sobre los pies en el momento del agarre): manos en la cornisa, pies contra la pared. |
| **Incorporarse desde colgado** | Colgado: **W** o **Espacio** para subir (tira con los brazos, sube una rodilla y se pone de pie arriba). **S** para soltarse. |
| **Cámara estilo Valheim** | Órbita libre con el ratón por encima del hombro, rueda para zoom. El personaje gira hacia donde se mueve. |

### Controles

| Tecla | Acción |
|---|---|
| WASD / flechas | Moverse (relativo a la cámara) |
| Shift (mantener) | Esprintar |
| C | Activar / desactivar andar |
| Espacio | Saltar / encaramarse / subir desde colgado |
| S (colgado) | Soltarse de la cornisa |
| Ratón / rueda | Cámara / zoom |
| Esc / clic | Soltar / capturar el ratón |
| Tab | Menú de modelos y vuelta al menú principal (pausa el juego) |

---

## 2. Parámetros regulables (lo que me puedes pedir ajustar)

### Adherencia de los pies ("pie ventosa" / "pie camaleón")

La facilidad con que un pie se agarra a una superficie inclinada **es regulable**. Ahora
está limitada para que el andar sea normal. Antes el pie se pegaba al costado de las rocas
"como un camaleón o una rana con ventosas".

| Parámetro (en `SaurusRig`, visible en el Inspector) | Valor | Qué hace |
|---|---|---|
| `max_foothold_angle_deg` | 35° | Superficie más empinada en la que se planta un pie. Si es más inclinada, busca un sitio más plano cerca. |
| `max_foot_tilt_deg` | 25° | Cuánto puede inclinarse el pie para adaptarse al suelo. |

**Idea pendiente:** una subraza de lagarto trepador o camaleón cuyos pies se peguen a los
obstáculos más cercanos al andar o trepar. Para conseguirlo, sube los dos valores hacia
90° y haz que `_foothold()` prefiera la superficie más cercana en vez de la más plana.

### Movimiento y escalada (en `Player`, visible en el Inspector)

| Parámetro | Valor | Qué hace |
|---|---|---|
| `walk_speed` / `run_speed` / `sprint_speed` | 2 / 4,5 / 7 m/s | Velocidades |
| `acceleration` / `deceleration` | 8 / 10 | Rapidez al arrancar / frenar |
| `turn_speed` | 9 | Rapidez de giro del cuerpo |
| `jump_velocity` | 5 | Altura del salto (~1,3 m) |
| `air_control` | 2 | Control de dirección en el aire |
| `max_step_height` | 0,45 m | Escalón máximo que sube solo |
| `mantle_min` / `mantle_max` | 0,45 / 1,5 m | Alturas de borde para encaramarse con Espacio |
| `hang_max` | 2,6 m | Cornisa más alta que puede agarrar en el aire |
| `hang_drop` | 2,1 m | Cuánto cuelga el cuerpo por debajo del borde |
| `climb_time` / `mantle_time` | 1,3 / 0,8 s | Duración de subir desde colgado / encaramarse |

### Cómo anda (constantes al principio de `scripts/saurus_rig.gd`)

Cada tabla tiene tres valores, para **andar, correr y esprintar**; entre medias se mezclan
según la velocidad.

| Constante | Valores | Qué cambia |
|---|---|---|
| `STEP_LENGTH` | 0,55 / 0,95 / 1,3 m | Largo de cada paso (más corto = cadencia más rápida) |
| `SWING_FRACTION` | 0,42 / 0,6 / 0,66 | Parte del ciclo que cada pie pasa en el aire (por encima de 0,5 hay fase de vuelo) |
| `FOOT_LIFT` | 0,1 / 0,18 / 0,24 m | Cuánto levanta el pie |
| `CROUCH` | −0,08 / −0,12 / −0,16 m | Cuánto baja la cadera (rodillas flexionadas) |
| `BOB` | 0,03 / 0,06 / 0,07 m | Bote del cuerpo en cada pisada |
| `LEAN` | 0,14 / 0,26 / 0,4 rad | Inclinación hacia delante |
| `ARM_SWING` / `ELBOW_BEND` | — | Balanceo de brazos / flexión de codos |
| `STANCE_HALF_WIDTH` | 0,16 m | Separación de los pies |
| `MAX_FOOT_REACH` | 0,9 m | Si un pie plantado se aleja más, da un paso de emergencia |
| `MAX_FOOT_RISE` | 0,6 m | Un apoyo más alto que esto se considera pared, no escalón |
| `RUN_CLIP_BLEND` | 2,8 / 3,8 m/s | Velocidades entre las que entra la animación de correr del modelo |

Control de "en el aire" (en `scripts/player.gd`): `COYOTE_TIME` (0,25 s) y
`GROUND_TOLERANCE` (0,7 m). Mientras haya suelo cerca, no cuenta como aire. Así se evita
que las piernas "se traben" al rebotar sobre rocas.

---

## 3. Cómo está montado

```
scenes/test_level.tscn   nivel de pruebas (escena principal)
  Player (CharacterBody3D)              scripts/player.gd
    Collision (cápsula 0,45 x 2,2 m)
    SaurusRig (Node3D)                  scripts/saurus_rig.gd
      [modelo GLB] / Skeleton3D
        SaurusPose (SkeletonModifier3D) scripts/saurus_pose.gd
    CameraYaw / CameraPitch / SpringArm / Camera
```

- **`player.gd` decide dónde va el cuerpo.** Estados: `GROUND`, `AIR`, `HANG` (colgado) y
  `CLIMB` (encaramándose o subiendo). Gestiona la subida automática de escalones
  (`_try_step_up`), la detección de cornisas (`_find_ledge`) y la secuencia de subida
  (`_climb_pose`).
- **`saurus_rig.gd` decide cómo se mueven las extremidades.**
  - Planifica los pasos en el mundo: cada pie tiene una ventana en el ciclo de la marcha
    y la fase manda, así que ningún pie puede quedarse atrás.
  - Busca los apoyos con rayos (`_foothold`), calcula el arco del paso para salvar
    obstáculos (`_clearance`) y fija la altura de la cadera y las variables de la pose:
    inclinación, giro, brazos, cola, cabeza.
- **`saurus_pose.gd` aplica la pose al esqueleto en cada fotograma.** Usa IK de dos huesos
  para piernas y brazos (`_solve_two_bone`), alinea los pies con el suelo y mueve columna,
  cabeza y cola. El esqueleto es de tipo Mixamo.
- **`pixel_tex.gd` genera las texturas pixeladas** (sin suavizado, proyección triplanar).
  Se usan en el escenario; los personajes no llevan textura.
- **`model_catalog.gd` lista los modelos disponibles** y **`model_menu.gd` es el menú**
  (Tab) para cambiar de modelo en pleno juego.

### Los modelos

- **Cómo se elige el modelo:**
  - **Desde la selección de raza** (portada → Start): el de la raza elegida. Ver
    `docs/menus.md`.
  - **Desde Debug:** el último elegido en el menú Tab.
  - **Menú Tab:** solo se abre con Tab. Pausa el juego, recuerda la última elección entre
    partidas (`user://test_model.cfg`) y tiene un botón para volver al menú principal.
- **Detección automática:** aparece cualquier `.glb` dentro de `imported_models/` que tenga
  esqueleto con huesos Mixamo (`mixamorig_Hips`, piernas y pies). Las mallas sin rig no
  salen. Para añadir un modelo basta con meterlo en esa carpeta.
- **Ajuste automático al cargar** (`SaurusRig.load_model`):
  - Centra el modelo en la cadera, lo orienta mirando hacia delante y lo escala ×1,1.
  - Mide la altura del tobillo de cada modelo.
  - Baja los brazos según la pose de reposo: el dummy está en pose A y el Sentinel en
    pose T.
  - No le pone ninguna textura: cada modelo se ve con su propio material (los de Meshy sin
    textura salen en gris liso).
  - La cola es opcional.
- **Por defecto: `Crystal_Sentinel`** (Meshy, unos 89.000 vértices, pose T, sin texturas ni
  UVs; tiene cola en la malla pero sin huesos propios). Trae la animación `Running`, que se usa al correr (ver abajo).
- **`saurian-test-dummy-proxy`**: el muñeco anterior (pose A, con cola, unos 85.000
  vértices). Trae solo `Jump_Run`.
- **Línea de comandos:** `-- --model=<nombre del glb>` fuerza un modelo; sirve también
  con las capturas y la prueba de marcha.
- **Animaciones:** quieto, andar, saltar y trepar son procedurales. Para atacar, morir,
  etc. hay que exportar desde Meshy con esas animaciones.

### Correr con la animación del modelo + pies corregidos

Si el modelo trae una animación cuyo nombre empieza por "run" (el Sentinel trae
`Running`), se usa al correr, con los pies corregidos sobre el terreno (estilo Elden Ring):

- **Mezcla por velocidad:** procedural por debajo de 2,8 m/s y la animación por encima de
  3,8 m/s; entre medias se mezclan (`RUN_CLIP_BLEND` en `saurus_rig.gd`). En el aire,
  colgado o trepando vuelve a lo procedural.
- **Sin patinar:** al cargar el modelo se mide a qué velocidad retrocede el pie apoyado en
  la animación (Sentinel: 5,7 m/s) y la animación se reproduce más rápida o más lenta
  según la velocidad real.
- **Sincronizada con la marcha procedural:** se mide en qué momento despega el pie
  izquierdo, así la mezcla nunca cruza las piernas.
- **Corrección de pies:** debajo de cada pie animado se lanza un rayo al suelo. El pie
  sube o baja esa diferencia con IK, conservando la flexión de rodilla de la animación, y
  se inclina según la pendiente cuando está cerca del suelo. La cadera baja lo necesario
  para que el pie más bajo llegue.
- Código: `_update_run_clip` en `saurus_rig.gd` (mezcla y rayos) y `_apply_clip` /
  `_prepare_clip` en `saurus_pose.gd` (pose, IK y medición).
- **Los modelos están en `.gitignore`**: el proyecto no funciona en otro ordenador sin
  ellos.

---

## 4. Nivel de pruebas

Aparición en el centro, mirando al norte (−Z). Cada zona tiene un cartel.

| Zona | Dónde | Para probar |
|---|---|---|
| Rampas 10°, 20°, 30°, 40°, 50° | Este | Andar y correr en pendiente (la de 50° no se puede subir: el límite es 46°) |
| Escaleras de 0,2 m y 0,4 m | Noreste | Subida automática de escalones |
| Calzadas de piedras: baja, media y alta | Oeste | Pies sobre piedras a distintas alturas |
| Campo de 170 rocas | Norte, tras la puerta | Andar y correr por terreno muy irregular |
| Muros de 0,6 / 1,0 / 1,4 / 2,0 / 2,6 / 3,2 m | Sur, tras las ruinas | Encaramarse, agarrarse y subir |
| Túnel, ruinas, colinas | Varios | Escala y cámara |

---

## 5. Herramientas de prueba

- **Prueba automática de la marcha:**
  `Godot_console.exe --headless --path . -s res://tools/gait_test.gd`
  - Conduce al personaje con sprints, giros de 180°, zigzags, paradas, rocas, calzada y
    rampas, e imprime métricas por tramo.
  - Valores sanos: distancia pie–cadera < 0,9 m, 0 pies fuera de alcance, apoyos
    ≤ 35° e inclinación del pie ≤ 25°.
- **Capturas automáticas:** se arranca el juego con `-- --screenshot=archivo.png` y
  opciones para colocar la cámara, hacerlo andar, saltar en ciertos fotogramas o sacar
  ráfagas. La lista completa está al principio de `scripts/test_level.gd`.
- **Hoja de contactos:** `tools/contact_sheet.gd` junta una ráfaga de capturas en una sola
  imagen.

---

## 6. Limitaciones conocidas y siguientes pasos

- **La textura "resbala" un poco** sobre brazos y piernas al moverse, porque el modelo no
  tiene UVs y se usa proyección triplanar.
- **Durante el colgado la cámara puede quedarse detrás del muro.**
- **No hay desplazamiento lateral colgado** (shimmy) ni caídas con voltereta.
- **Pendiente:** ataques, esquiva, muerte, etc. Requieren animaciones reales o hacerlas
  procedurales. Se puede mezclar clips de animación con la IK de pies quitando
  `reset_bone_poses()` en `saurus_pose.gd`.
- **Ideas guardadas:** la subraza de pies adherentes (ver sección 2).
