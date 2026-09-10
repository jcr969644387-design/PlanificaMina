# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

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
