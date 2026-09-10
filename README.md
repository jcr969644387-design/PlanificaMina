# PlanificaMina

[![CI](https://github.com/jcr969644387-design/PlanificaMina/actions/workflows/ci.yml/badge.svg)](https://github.com/jcr969644387-design/PlanificaMina/actions/workflows/ci.yml)
[![Build APK](https://github.com/jcr969644387-design/PlanificaMina/actions/workflows/build-apk.yml/badge.svg)](https://github.com/jcr969644387-design/PlanificaMina/actions/workflows/build-apk.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-E0A343.svg)](LICENSE)

Simulador educativo de planeamiento minero para estudiantes de Ingeniería de Minas.

La aplicación existe para romper una confusión concreta: **el estudiante trata la ley de corte como un dato del yacimiento cuando es una decisión económica.** Todo lo demás — programación de producción, evaluación económica, sensibilidad — orbita alrededor de ese bucle.

Proyecto Flutter completo, sin backend, sin cuentas y **100 % funcional sin conexión**.

---

## Compilar

Requiere Flutter 3.10 o superior.

```bash
cd planificamina

flutter pub get          # descarga las dos dependencias
flutter test             # ejecuta la suite del motor de cálculo
flutter run              # ejecuta en un dispositivo o emulador conectado
```

**Generar el APK instalable:**

```bash
flutter build apk --release
# el archivo queda en build/app/outputs/flutter-apk/app-release.apk
```

APK más liviano, separado por arquitectura:

```bash
flutter build apk --split-per-abi
```

Si el proyecto no trae carpetas `android/` e `ios/` en tu copia, genéralas con:

```bash
flutter create --platforms=android,ios .
```

Esto conserva `lib/`, `test/` y `pubspec.yaml`, y solo añade los andamios de plataforma.

> **Ojo:** `flutter create` también repone los archivos del template que falten,
> y uno de ellos es `test/widget_test.dart` — el test del contador de ejemplo.
> Ese archivo espera un `MyApp` que aquí no existe (la raíz es
> `PlanificaMinaApp`), así que rompe `flutter test`. Bórralo después de generar
> los andamios:
>
> ```bash
> rm test/widget_test.dart
> ```

**Versión web** (útil para mostrarla sin instalar nada):

```bash
flutter build web
```

---

## Verificar que funciona

`flutter test` no solo comprueba aritmética: incluye **pruebas de regresión pedagógica**. Si alguien recalibra un caso de estudio y lo deja degenerado — todos los bloques por encima de la ley de corte, sin decisión que tomar — la suite falla. Fue el error más grave del brief original y no debe reaparecer.

```
✓ menor recuperación implica MAYOR ley de corte
✓ Veta San Rafael: existe material sobre y bajo la ley de corte
✓ Pórfido Alto Chico: bajar el precio reduce el tonelaje económico
✓ violar precedencia genera error
```

---

## Los tres casos

| Caso | Método | Qué enseña |
|---|---|---|
| **Veta San Rafael** · Au | Subterránea | Breakeven vs. marginal. El doré tiene deducciones mínimas, así que la fórmula simplificada es fiel: es el caso limpio para entender el concepto |
| **Pórfido Alto Chico** · Cu | Tajo abierto | Costo hundido. El desmonte se mina igual: la pregunta no es si extraer el bloque, sino a dónde llevarlo |
| **Manto Quilcaya** · Zn-Pb-Ag | Subterránea | NSR. Con tres metales la fórmula monometálica deja de servir |

Los tres son yacimientos ficticios, generados por un algoritmo determinista: idénticos en todos los dispositivos y en todas las sesiones.

---

## Estructura

```
lib/
├── main.dart
├── core/ui.dart                    tema, formato, componentes
├── domain/                         Dart puro, sin Flutter — testeable al 100 %
│   ├── models.dart                 metales, bloques, casos, escenarios
│   ├── cutoff.dart                 NSR, breakeven, marginal, Lane, ley-tonelaje
│   ├── scheduler.dart              precedencia, capacidad, VAN / TIR / payback
│   ├── analysis.dart               tornado, Lane iterativo, high-grading
│   ├── tutor.dart                  motor de reglas + puntaje compuesto
│   └── export.dart                 CSV para Excel
├── data/                           casos y banco de evaluación
├── viewmodels/session.dart         MVVM sobre Riverpod
├── widgets/                        sección 2D, isométrico, gráficos
└── screens/                        inicio, espacio de trabajo, evaluación, teoría
```

**Dos dependencias en total:** `flutter_riverpod` y `shared_preferences`. Cada dependencia es deuda de mantenimiento; un proyecto educativo pequeño debe minimizarlas.

---

## Subirlo a tu repositorio

Los pasos completos están en `docs/VINCULAR_REPOSITORIO.md`. En resumen:

```bash
flutter create --platforms=android,ios --project-name planificamina .
git init && git add . && git commit -m "PlanificaMina 1.0.0"
git branch -M main
git remote add origin https://github.com/USUARIO/REPOSITORIO.git
git push -u origin main
```

El repositorio trae dos workflows listos: **CI** corre análisis y pruebas en cada
push, y **Build APK** compila el instalador.

### Descargar el APK sin compilar nada

**Build APK** se ejecuta en cada push a `main`. Para bajar el instalador:

1. Entra en la pestaña **Actions** del repositorio.
2. Abre la última ejecución de **Build APK** que aparezca en verde.
3. Al final de la página, en **Artifacts**, descarga `planificamina-apk`.

Es un `.zip` con el APK universal (`app-release.apk`) y los tres APK separados
por arquitectura, que son bastante más livianos. Los artefactos caducan a los
30 días y **solo se pueden descargar con la sesión de GitHub iniciada**.

Para un enlace público y permanente, crea una etiqueta de versión: eso publica
un release con los APK adjuntos, descargables por cualquiera sin cuenta.

```bash
git tag v1.0.3
git push origin v1.0.3
```

---

## Documentación

| Documento | Contenido |
|---|---|
| `docs/VINCULAR_REPOSITORIO.md` | Guía completa de GitHub, CI y firma del APK |
| `docs/ETAPA3_EXPERIENCIA_EDUCATIVA.md` | Flujo de aprendizaje, interacción, evaluación en tres niveles |
| `docs/ETAPA5_ARQUITECTURA.md` | Decisiones técnicas y alternativas descartadas |
| `docs/ETAPA6_IA.md` | Por qué el MVP no lleva IA generativa y cuándo tendría sentido |
| `docs/CORRECCIONES_APLICADAS.md` | Errores del brief original y su corrección, con verificación numérica |

---

## Qué NO es esta aplicación

Un modelo educativo simplificado. No sustituye software profesional de planeamiento ni un estudio de factibilidad, y no debe usarse para decisiones de inversión.

Los límites están dentro de la app, en la pantalla de Conceptos, como contenido y no como descargo legal escondido. El más importante: **no existe "el" pit óptimo.** Un pit calculado a 3,50 \$/lb es óptimo solo a ese precio, e ignora el tiempo.
