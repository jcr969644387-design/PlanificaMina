# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [1.0.2] — 2026-09-10

### Cambiado
- Todo `lib/` y `test/` pasado por `dart format` (Dart 3.13.3, la misma
  versión que trae Flutter 3.47.3 en el runner). Solo saltos de línea y
  sangrado: ningún token cambia. El paso «Verificar formato» del CI, que era
  informativo y salía en rojo, ahora pasa sin diferencias.

  El estilo resultante es el «short» clásico, no el «tall» de Dart 3.7+,
  porque la versión de lenguaje del paquete la fija `environment: sdk` en
  `pubspec.yaml`. Si se sube ese límite a 3.7 o más, `dart format` reescribirá
  el proyecto entero con el estilo nuevo.

## [1.0.1] — 2026-09-10

### Corregido
- `Economics.irr` buscaba la raíz desde −95 %, así que devolvía una TIR
  fuertemente negativa para proyectos que nunca recuperan la inversión, en vez
  del `null` que la interfaz ya interpretaba como «no recupera la inversión».
  Ahora la búsqueda parte de 0 %.
- `ScoringEngine.compute` producía un `num` donde se esperaba un `double`, y
  un `SectionTitle` constante interpolaba un valor de runtime: ambos rompían
  el análisis estático.
- Imports y variables locales sin usar en `analysis.dart` y `session.dart`.

### Cambiado
- `Color.withOpacity()` migrado a `Color.withValues(alpha:)`, lo que fija el
  requisito mínimo en Flutter 3.27 / Dart 3.6.

## [1.0.0] — 2026-09-10

### Añadido
- Motor de cálculo en Dart puro: NSR, ley de corte breakeven, marginal y de Lane,
  curva ley-tonelaje, programación con precedencias, VAN, TIR, payback y AISC.
- Tres casos de estudio calibrados: oro subterráneo, pórfido de cobre a tajo
  abierto y polimetálico Zn-Pb-Ag.
- Visor de sección 2D con el cuerpo económico redibujándose en vivo, y vista
  isométrica que renderiza solo la cáscara del sólido.
- Tutor por reglas con 9 diagnósticos, sin conexión.
- Puntaje compuesto y progresión de roles.
- Diagnóstico pre/post de 6 preguntas, reflexiones contextuales y tarea de
  transferencia en papel.
- Análisis de sensibilidad (tornado) y exportación CSV para Excel.
- Suite de pruebas con regresión pedagógica.

### Corregido respecto de la especificación original
- Fórmula de ley de corte: la recuperación divide, no multiplica.
- Casos degenerados donde todos los bloques resultaban mineral.
- Fórmula monometálica aplicada al caso polimetálico, sustituida por NSR.
- Ranking por VPN sustituido por puntaje compuesto.

Detalle completo en `docs/CORRECCIONES_APLICADAS.md`.
