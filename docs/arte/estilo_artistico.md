# Estilo artístico

Dirección artística del proyecto. Se aplica a personajes, escenarios, iluminación,
texturas, efectos e interfaz. Si una decisión visual contradice este documento, se
corrige el documento o la decisión, pero no se deja la contradicción.

Imágenes de referencia de estilo: `docs/arte/referencias/`.
Diseño de cada raza: `docs/lore/kaurkas.md`.

---

## La idea en una frase

**Aspecto retro, sensación moderna.** Se tiene que ver como Valheim (low poly, texturas
pixeladas), pero jugarse como un juego actual: animaciones fluidas, pies que se adaptan al
terreno, interacciones físicas creíbles. Nadie debería pensar que las animaciones o la
interacción con el entorno tienen 10 años.

## Referencias

| Juego | Qué tomamos de él |
|---|---|
| **Valheim** | El referente principal: el *game feel*, el low poly con texturas pixeladas y la iluminación atmosférica |
| **Risk of Rain 2** | Formas limpias y legibles, low poly estilizado, criaturas reconocibles por su silueta |
| **Torchlight 2** | La gama cromática: colores saturados y vivos, contraste de luces de color |

Zonas concretas de Valheim que marcan el tono de color:
- **Pantano:** luces verdes y púrpuras, niebla, ambiente húmedo y venenoso.
- **Criptas del Bosque Negro** (tumbas de los esqueletos): penumbra con luces de color y
  piedra antigua.
- **Pradera:** verdes cálidos y luminosos, sensación acogedora.

---

## Pilares

### 1. Retro en el aspecto
- **Low poly / poligonización media**, como Valheim: siluetas claras, sin detalle
  microscópico.
- **Texturas pixeladas:** texturas pequeñas pintadas a mano, con color irregular y sombras
  pintadas, y sin suavizado al ampliarlas (*nearest*). Ver el goblin de Valheim como
  referencia de personaje.
- **Resolución de pantalla completa:** lo pixelado son las superficies, no la imagen entera.
  No es "pixel art 3D" a baja resolución.

### 2. Moderno en la sensación
- **Las animaciones son la prioridad del proyecto.** Fluidas, con peso, con anticipación y
  reacción.
- **Interacción con el entorno actual:** IK de pies sobre el terreno, cuerpo que reacciona al
  acelerar, frenar y girar, encaramarse y agarrarse a cornisas (ya implementado, ver
  `docs/movimiento_jugador.md`).
- **Iluminación y atmósfera modernas** cuando lleguemos a ello: sombras, luces de color,
  niebla volumétrica, partículas, como Valheim.

### 3. Color vivo, no oscuridad
- Aunque la mayoría del juego ocurre **bajo tierra**, el juego **no es oscuro**, al menos no
  la mayor parte del tiempo.
- **Colores jurásicos:** verdes de jungla, tierras, piedra.
- **Las luces púrpuras y verdes son muy importantes** (bioluminiscencia, cristales, hongos,
  agua venenosa), como en el pantano y las criptas de Valheim.
- Contraste entre zonas acogedoras y luminosas, tipo pradera, y zonas inquietantes de luz
  púrpura y verde.

### 4. Brutal en el tono
- Narrativa y violencia para adultos: **nada de PEGI 13**.
- **Previsto para el futuro:** desmembramientos, decapitaciones y gore en el combate. Esto
  condiciona cómo se preparan los modelos (ver "Implicaciones técnicas").
- La brutalidad está en lo que pasa, no en volver el mundo gris y apagado. Colores vivos y
  violencia cruda pueden convivir (Risk of Rain 2, Torchlight 2).

---

## Escenarios

- **Bajo tierra, sobre todo:** cavernas, y **grandes cavernas con techos enormes que albergan
  junglas**.
- El techo de la caverna puede funcionar como un "cielo": iluminación de cristales,
  bioluminiscencia, aberturas a la superficie.
- La superficie existe: los Kaurkas escapan del subsuelo hacia ella. El contraste
  subsuelo/superficie es parte de la historia.

---

## Implicaciones técnicas

**Estado actual del prototipo:**
- Texturas procedurales pixeladas (`scripts/pixel_tex.gd`), siempre con filtrado *nearest*
  con mipmaps.
- Densidad de texel: **20 píxeles por metro** en el mundo y **32 px/m** en personajes. Los
  personajes tienen algo más de detalle que el mundo, como en Valheim.
- Proyección triplanar (no requiere UVs). MSAA 2× para bordes limpios.
- Iluminación provisional: sol + cielo, tonemap Filmic. **Todavía no hay** niebla, luces de
  color, partículas ni post-proceso; está pendiente.

**Para modelos futuros:**
- Poligonización baja-media; con texturas pequeñas pintadas, del orden de 128–512 px por
  personaje.
- **Preparar el desmembramiento desde el principio:** separar el modelo por partes (cabeza,
  brazos, piernas, cola) o marcar zonas de corte, con "tapas" de muñón e interior de color
  carne o hueso. Es mucho más fácil hacerlo al modelar que añadirlo después.
- Esqueleto compatible con la IK actual (tipo Mixamo).

**Para la iluminación futura:**
- Luces de color (púrpura, verde, ámbar) como protagonistas en cavernas.
- Niebla volumétrica y partículas en suspensión.
- Bloom suave para la bioluminiscencia.

---

## Qué evitar

- Un juego **oscuro y embarrado** de colores apagados por estar bajo tierra.
- Un aspecto **infantil o "familiar"** que contradiga la brutalidad.
- **Animaciones rígidas o anticuadas:** pies que se deslizan, transiciones bruscas, falta de
  peso.
- Pixel art a baja resolución de toda la pantalla: lo pixelado son las texturas.
- Exceso de detalle o realismo en modelos y texturas.

---

## Preguntas abiertas

1. **Interfaz:** ¿estilo Valheim (minimalista, rúnico) o algo propio de los Kaurkas?
2. **Cámara:** ¿mantener la cámara libre tipo Valheim o acercarla en combate, tipo Souls?
3. **Gore:** ¿nivel de detalle? ¿Sangre de color realista o distinta para los Kaurkas?
4. **Superficie:** ¿qué aspecto tiene el mundo de arriba comparado con las cavernas?
