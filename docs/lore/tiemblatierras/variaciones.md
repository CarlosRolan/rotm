# Tiemblatierras: variaciones del creador de personajes

Rasgos que el jugador puede elegir al crear un Tiemblatierra. Todas las variantes deben
seguir siendo reconocibles como Tiemblatierra: mole con piernas de pilar, cabeza baja con
placa ósea y pies de elefante. Diseño base en `docs/lore/kaurkas.md`.

## Confirmadas

| Variación | Rango | Referencia |
|---|---|---|
| **Complexión** (en el lore varía según el individuo) | De **barrigudo** (barriga grande y blanda) a **definido** (pecho y abdomen marcados) | Barrigudo: `tiemblatierra_boca_brazos.png`. Definido: `tiemblatierra_protuberancias_oaseas.webp` |
| **Protuberancias óseas** (cantidad y tamaño) | Desde placas hexagonales lisas y planas hasta láminas superpuestas acabadas en punta: corona de hueso en la cabeza, hombreras óseas en los hombros y puntas óseas en codos y antebrazos | Mínimo: `tiemblatierra_boca_brazos.png`. Máximo: `tiemblatierra_protuberancias_oaseas.webp` |

Se pueden combinar libremente: por ejemplo, barrigudo con muchas protuberancias, o definido
con placas lisas.

## Propuestas (pendientes de confirmar)

| Variación | Rango propuesto |
|---|---|
| Altura | 2,0 – 2,3 m (el rango del canon) |
| Color de piel y de placas | Tierras cálidas: ocre, naranja quemado, arcilla, gris piedra |
| Zonas con protuberancias | Elegir por zona: cabeza, hombros, brazos, lomo, cola |
| Longitud y grosor de la cola | Dentro de "prominente, pero menor que brazos y piernas" |

## Notas técnicas

- Complexión y protuberancias encajan bien como **blend shapes** (deformadores del modelo)
  para la barriga y el tamaño de las placas, más **piezas opcionales** para la corona de hueso y las
  hombreras grandes.
- Las protuberancias grandes cambian la silueta: tenerlo en cuenta en las colisiones de la
  cabeza y los hombros, y en el desmembramiento (ver `docs/arte/estilo_artistico.md`).
