# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [1.0.5] — 2026-09-10

### Añadido
- Icono propio: tres bancos de un tajo abierto en sección, en el dorado de la
  paleta sobre el fondo de la app. Sustituye al logotipo de Flutter. Incluye
  icono adaptativo para Android 8+ y las cinco densidades. Vive en
  `android_res/` porque `android/` se regenera en cada build; el workflow lo
  copia sobre el andamio recién generado.
- Retroalimentación táctil y sonora (`lib/core/feedback.dart`), sin ninguna
  dependencia nueva: vibración vía `performHapticFeedback` — que no exige el
  permiso VIBRATE — y el clic del sistema, que respeta el ajuste de sonidos
  táctiles del teléfono. La intensidad codifica significado: seleccionar una
  opción vibra más flojo que acertar una reflexión, y fallar vibra distinto.

### Corregido
- El nombre bajo el icono aparecía como «planificamina», el nombre del paquete
  Dart. El workflow ahora fija `android:label` a «PlanificaMina».
- Áreas seguras. La barra de gestos tapaba el final de las listas en Conceptos,
  en el diagnóstico y en las cinco pestañas del espacio de trabajo, y pisaba el
  botón de la hoja de reflexión. Los `ListView` suman el inset inferior a su
  relleno y la hoja suma `viewPadding.bottom` además de `viewInsets.bottom`,
  que solo cubría el teclado.
- Las barras del sistema se declaran transparentes con iconos claros: en modo
  borde a borde, sobre el fondo oscuro de la app, quedaban ilegibles.

## [1.0.4] — 2026-09-10

### Cambiado
- «Build APK» publica un único archivo, `app-release.apk`, en vez de cuatro.
  Se elimina el paso `--split-per-abi`: los APK por arquitectura pesan menos,
  pero obligan a cada estudiante a averiguar cuál le corresponde, y elegir mal
  da un error de instalación difícil de interpretar. El universal se instala
  en cualquier teléfono Android sin preguntas.
- El release de una etiqueta adjunta también ese único APK.

## [1.0.3] — 2026-09-10

### Corregido
- El workflow «Build APK» nunca se había ejecutado: solo se disparaba con
  etiquetas `v*` y el repositorio no tenía ninguna, así que no existía ningún
  APK en ninguna parte. Ahora también se dispara en cada push a `main`.
- En su primera ejecución falló en `flutter test`. La causa: `flutter create`,
  que genera el andamio de Android, repone además los archivos del template
  que falten, y uno es `test/widget_test.dart` — el test del contador, que
  espera un `MyApp` inexistente aquí (la raíz es `PlanificaMinaApp`). Las
  pruebas ahora corren antes de generar el andamio, y ese archivo se borra.
- Las dos insignias del README apuntaban a `USUARIO/REPOSITORIO`, un
  repositorio inexistente: el marcador de la plantilla nunca se sustituyó.
  Igual en `.github/ISSUE_TEMPLATE/config.yml`.

### Añadido
- El README explica cómo descargar el APK desde Actions, advierte que los
  artefactos caducan a los 30 días y exigen sesión iniciada, y avisa del
  `test/widget_test.dart` que `flutter create` deja al generar los andamios.

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
