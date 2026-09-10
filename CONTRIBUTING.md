# Cómo contribuir

## La regla que gobierna todo

Una funcionalidad entra si mejora el aprendizaje, no si es técnicamente atractiva. Antes de proponer cualquier cosa, responde: **¿qué concepto entiende mejor el estudiante gracias a esto?** Si la respuesta es floja, la propuesta se cierra sin evaluar.

Esto aplica especialmente a 3D, realidad aumentada, IA generativa y gamificación. Las tres primeras están explícitamente fuera del alcance actual, y la razón está documentada en `docs/ETAPA5_ARQUITECTURA.md` y `docs/ETAPA6_IA.md`.

---

## Prioridad de los issues

1. **Errores de contenido técnico o educativo.** Máxima prioridad, siempre. Una fórmula incorrecta en una app educativa llega al estudiante con autoridad de sistema y no la cuestiona. Ya ocurrió una vez con la ley de corte.
2. Errores de software que impiden usar la app.
3. Todo lo demás.

---

## Antes de abrir un Pull Request

```bash
flutter pub get
flutter analyze
flutter test
```

Los tres tienen que pasar. El workflow de CI los ejecuta igual, pero descubrirlo localmente es más rápido.

---

## Si tocas el motor de cálculo

`lib/domain/` es Dart puro, sin una sola importación de Flutter. Esa regla no se rompe: es lo que permite testear el 100 % de la matemática sin levantar un widget.

Toda modificación al cálculo necesita pruebas en `test/domain_test.dart`, y los valores esperados deben verificarse **de forma independiente** — a mano, en una hoja de cálculo o en un script aparte. Verificar la implementación contra sí misma no comprueba nada.

Convenciones del motor:

- El cálculo trabaja **siempre en NSR (\$/t)**, incluso con un solo metal. La conversión a unidades de ley ocurre solo al mostrar en pantalla.
- La recuperación metalúrgica **divide** al despejar la ley de corte. Hay un test que falla si esto se invierte; no lo elimines.
- Factores de unidades: `22,0462` para leyes en % con precio en \$/lb, `31,1035` para g/t con \$/oz. Están como constantes nombradas en `models.dart`.

---

## Si añades o recalibras un caso de estudio

Un caso vive en `lib/data/case_repository.dart` y se genera con un algoritmo determinista, para que sea idéntico en todos los dispositivos. Nunca uses un generador aleatorio sin semilla fija: un caso que cambia entre corridas no es evaluable.

El caso debe cumplir, con los parámetros base:

- Existe material **sobre y bajo** la ley de corte.
- La fracción de mineral queda entre 5 % y 85 %.
- El escenario pesimista cambia el resultado de forma material.
- La vida de mina es de al menos 3 años.

La suite de regresión pedagógica verifica esto automáticamente. Si tu caso la hace fallar, el caso está degenerado y no enseña ley de corte.

Los yacimientos son **ficticios**. No uses nombres de operaciones reales con parámetros inventados.

---

## Si tocas contenido educativo

Preguntas, explicaciones, reglas del tutor y textos de la pantalla de Conceptos son contenido académico. Idealmente los revisa alguien con formación en planeamiento minero antes de fusionar. Si no es posible, indícalo en el PR para que quede constancia.

Los **límites del modelo** (`lib/screens/theory.dart`) son contenido, no un descargo legal. No los recortes por espacio.

---

## Estilo

`dart format` sobre `lib/` y `test/`. Comentarios en español, explicando el *porqué* de una decisión, no el *qué* hace el código.

Las dependencias son dos y esa es una decisión de diseño. Añadir una tercera requiere justificarlo en el PR: cada dependencia es deuda de mantenimiento y riesgo de ruptura en actualizaciones.

---

## Ramas

- `main` — estable, siempre compilable.
- `develop` — integración.
- `feat/…`, `fix/…`, `content/…` — trabajo puntual.

Las etiquetas `v*` disparan la compilación del APK y su publicación como release.
