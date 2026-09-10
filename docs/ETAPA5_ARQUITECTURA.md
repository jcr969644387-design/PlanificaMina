# Etapa 5 — Arquitectura técnica

*Mobile App Architect · PlanificaMina*

El alcance lo fijó la Etapa 4. Este documento traduce ese alcance en decisiones técnicas y justifica cada una, incluidas las alternativas descartadas.

---

## 1. Arquitectura general

Tres capas, sin nada más:

```
┌─────────────────────────────────────────┐
│  PRESENTACIÓN   screens/ · widgets/     │
│  Widgets sin lógica de negocio          │
└───────────────┬─────────────────────────┘
                │ observa (Riverpod)
┌───────────────▼─────────────────────────┐
│  VIEWMODEL      viewmodels/session.dart │
│  Estado del plan + orquestación         │
└───────────────┬─────────────────────────┘
                │ invoca (funciones puras)
┌───────────────▼─────────────────────────┐
│  DOMINIO        domain/                 │
│  models · cutoff · scheduler · analysis │
│  tutor · export                         │
│  Dart puro, sin una sola importación    │
│  de Flutter                             │
└───────────────┬─────────────────────────┘
                │ lee
┌───────────────▼─────────────────────────┐
│  DATOS          data/                   │
│  Casos y banco de evaluación (en código)│
└─────────────────────────────────────────┘
```

**La regla que sostiene todo:** `domain/` no importa Flutter. Eso permite testear el 100 % de la matemática sin levantar un widget, y es lo que hace posible la suite de regresión pedagógica descrita más abajo.

Flujo de información en una interacción típica:

```
Slider (precio) → SessionViewModel.setPrice()
   → recalcula CutoffSet
   → Scheduler.build() reconstruye el plan completo
   → TutorEngine.analyze() rediagnostica
   → evalúa si corresponde disparar una reflexión
   → notifyListeners() → se repintan sección, KPIs y gráficos
```

Todo síncrono, en un solo frame.

---

## 2. Diseño técnico

| Componente | Decisión | Justificación |
|---|---|---|
| Frontend | Flutter | Una base de código para Android e iOS, y `CustomPainter` da control total del renderizado sin dependencias gráficas externas |
| Backend | **Ninguno** | La app no tiene cuentas, ni contenido remoto, ni datos compartidos. Un backend sería infraestructura que mantener sin función |
| Base de datos | **Ninguna**; `shared_preferences` para el progreso | Los modelos de bloques se *generan*, no se almacenan: 3.000 bloques deterministas ocupan menos como algoritmo que como tabla |
| APIs externas | Ninguna | Requisito de operación offline |
| Almacenamiento local | Clave-valor (puntaje, pre/post test) | Es todo lo que hay que persistir |
| Exportación | CSV al portapapeles | Cero dependencias, cero permisos, funciona sin conexión |

**Alternativas descartadas y por qué:**

- **SQLite / Hive para el modelo de bloques.** El generador congruencial lineal produce el mismo modelo en todos los dispositivos, siempre. Persistirlo agregaría migraciones, tamaño de APK y una fuente de divergencia entre estudiantes. Un caso de estudio que cambia entre corridas no es evaluable.
- **Firebase.** Aportaría ranking y sincronización; ambos fueron descartados por producto (el ranking por VAN es pedagógicamente nocivo) y traería costo, cuentas de usuario y datos de menores de edad en la nube.
- **`share_plus` / `path_provider` para exportar.** Dos dependencias más y permisos de almacenamiento en Android, a cambio de algo que el portapapeles resuelve.

---

## 3. Arquitectura de desarrollo

**MVVM con Riverpod**, no Clean Architecture completa.

Clean Architecture (entidades, casos de uso, repositorios, mappers por capa) tiene sentido cuando hay múltiples fuentes de datos, equipos paralelos y reglas de negocio que cambian por cliente. Aquí no hay ninguna de las tres. Aplicarla produciría cuatro archivos por cada operación de un cálculo que cabe en una función pura.

MVVM encaja porque el problema es exactamente el que MVVM resuelve: **un estado central (el plan) que muchas vistas observan simultáneamente**. La sección del yacimiento, la curva ley-tonelaje, los KPI y el tutor son cinco proyecciones del mismo estado.

`ChangeNotifierProvider` en lugar de `StateNotifier` o generación de código: el ViewModel muta muchos campos relacionados en cada interacción, la superficie de API es mínima y estable, y no hace falta `build_runner`.

**Repository Pattern** aplicado solo donde aporta: `CaseRepository` y `AssessmentRepository` aíslan el contenido del código de dominio, de modo que agregar un cuarto caso no toca la lógica.

---

## 4. Experiencia móvil

**Rendimiento.** Es la restricción de diseño dominante: cada movimiento del slider reconstruye el plan completo.

| Operación | Coste | Estrategia |
|---|---|---|
| Clasificar 3.080 bloques | O(n) | Recorrido directo, sin asignaciones |
| Construir el programa | O(n log n) por ordenamiento por fase | Aceptable a 60 fps en gama media |
| Curva ley-tonelaje | 36 clasificaciones | Se recalcula solo al repintar el gráfico |
| **Tornado** | 10 planes completos | **Bajo demanda, con botón explícito** |
| **Ley de corte de Lane** | hasta 25 planes | **Bajo demanda** |

Las dos operaciones caras están detrás de una acción del usuario. Es una decisión consciente: mejor un botón "Calcular" que un slider que se traba.

**Renderizado.** Se descartó el 3D con GPU. La vista isométrica dibuja únicamente la **cáscara** del cuerpo económico: un bloque cuyos seis vecinos también son mineral no se ve y no se dibuja, lo que reduce típicamente entre un 60 % y un 75 % la carga de pintado. Con `CustomPainter` esto corre fluido sin `flutter_gl`, sin WebView y sin un paquete 3D de madurez incierta — que era el mayor riesgo de cronograma identificado en la Etapa 1.

**Offline.** Total. No hay una sola llamada de red en el proyecto. Esto no es una característica añadida: es consecuencia de haber dejado el tutor LLM fuera del alcance (ver Etapa 6).

**Batería y datos.** Cero consumo de datos. La paleta oscura reduce consumo en pantallas OLED. El coste de CPU se concentra en interacciones cortas, no en bucles de animación continuos.

---

## 5. Seguridad

El mejor control de seguridad de esta app es **no recolectar nada**.

- **Sin autenticación.** No hay cuentas porque no hay nada que proteger ni sincronizar.
- **Sin datos personales.** La app no pide nombre, correo, universidad ni edad. Es relevante porque parte de los usuarios pueden ser menores de edad, y cualquier recolección activaría obligaciones de protección de datos que un proyecto educativo pequeño no está preparado para cumplir.
- **Sin telemetría.** Ningún evento sale del dispositivo.
- **Almacenamiento local.** `shared_preferences` guarda tres enteros de progreso. No es cifrado, y no necesita serlo: un puntaje de práctica no es dato sensible. Debe seguir siendo así — si alguna vez se guardan resultados evaluados formalmente, corresponde migrar a almacenamiento cifrado.
- **Superficie de ataque.** Sin red, sin deep links, sin WebView y sin dependencias que ejecuten código remoto, la superficie es esencialmente nula.

**Si en el futuro se agrega un tutor con LLM**, esto cambia por completo: aparecen envío de texto del estudiante a un tercero, gestión de claves de API (que **nunca** deben ir en el cliente) y consentimiento informado. Esa es una razón adicional para no incorporarlo antes de validar el aprendizaje.

---

## 6. Escalabilidad

Las decisiones de hoy que habilitan el crecimiento:

1. **Contenido separado del motor.** Un caso nuevo es un método en `CaseRepository`. Ninguna otra parte del código cambia. Agregar un cuarto o décimo yacimiento es trabajo de contenido, no de ingeniería.
2. **NSR como moneda interna.** El motor trabaja siempre en \$/t, incluso con un solo metal. Un yacimiento con cinco metales ya funciona sin tocar el cálculo.
3. **Dominio libre de Flutter.** El mismo motor puede alimentar una versión web (`flutter build web`), un backend de corrección automática o una herramienta de escritorio.
4. **Tutor por reglas con interfaz estable.** `TutorEngine.analyze()` devuelve una lista de hallazgos. Añadir una capa LLM en el futuro significa agregar hallazgos a esa misma lista, no rediseñar la pantalla.
5. **Fases declarativas.** La precedencia se declara como datos (`requires: [1, 2]`), así que un método de explotación con precedencias distintas no requiere código nuevo.

**Lo que NO escala con esta arquitectura, y hay que decirlo:** cualquier funcionalidad multiusuario (aulas, ranking, entrega de tareas al docente, seguimiento de cohortes) exige backend, cuentas y una política de datos. Es un salto de categoría, no una extensión — y debe evaluarse como proyecto propio.

---

## 7. Selección tecnológica

| Tecnología | Alternativa descartada | Razón de la elección |
|---|---|---|
| **Flutter 3.x** | React Native | `CustomPainter` da control de píxel sin puente nativo; el renderizado de miles de bloques es el requisito dominante y RN obligaría a un módulo nativo o a WebGL |
| **Dart puro en el dominio** | Rust vía FFI | Innecesario: el perfilado indica que la carga cabe holgadamente en Dart; FFI agregaría compilación cruzada y complejidad de build |
| **flutter_riverpod 2.x** | Bloc, Provider, GetX | Bloc impone eventos y estados por cada interacción, lo que aquí serían decenas de clases para mover un slider. GetX mezcla responsabilidades. Riverpod da inyección testeable con API mínima |
| **shared_preferences** | Hive, Isar, SQLite | Se persisten tres valores. Cualquier otra cosa sería sobreingeniería |
| **CustomPainter** | three_dart, flutter_gl, WebView + three.js | Ninguno de los paquetes 3D de Flutter tiene madurez verificable para producción, y un WebView rompería el rendimiento y el modo offline limpio |
| **Sin backend** | Firebase, Supabase | No hay caso de uso que lo requiera en este alcance |

**Dependencias totales: dos.** `flutter_riverpod` y `shared_preferences`. Cada dependencia es una deuda de mantenimiento y un riesgo de ruptura en actualizaciones; un proyecto educativo con equipo pequeño debe minimizarlas agresivamente.

---

## 8. Complejidad técnica por versión

**MVP (implementado en este repositorio).**
Complejidad: **media-baja**. Sin red, sin base de datos, sin autenticación. Lo único no trivial es el motor de cálculo, que es Dart puro y está cubierto por pruebas. Un desarrollador con experiencia media en Flutter lo mantiene sin dificultad.

**Añadidos ya incluidos por encima del MVP mínimo** (porque el motor los soportaba sin costo estructural): ley de corte de Lane, NSR polimetálico, tornado, isométrico, exportación CSV, tres casos.

**V2 — complejidad adicional esperada.**

| Funcionalidad | Complejidad | Riesgo técnico |
|---|---|---|
| Optimización de pit (Lerchs-Grossmann / pseudoflow) | Alta | Implementación correcta del cierre máximo en grafo; conviene aislarla y testearla contra casos de referencia publicados |
| Dilución y recuperación minera | Media | Es más un problema de modelado que de código |
| Incertidumbre geológica (múltiples realizaciones) | Alta | Multiplica el coste de cálculo por el número de simulaciones; exigiría `compute()` en isolate |
| Modo docente / aula | **Muy alta** | Backend, cuentas, protección de datos de estudiantes. Cambio de categoría del proyecto |

**V3 — tutor con LLM.** Complejidad media en código, alta en operación: proxy propio para no exponer claves, control de costo por sesión, manejo de latencia y degradación sin conexión, y validación académica de las respuestas generadas. El detalle está en la Etapa 6.

---

## Estructura de archivos

```
lib/
├── main.dart
├── core/ui.dart                    tema, formato, componentes compartidos
├── domain/                         Dart puro, sin Flutter
│   ├── models.dart                 metales, bloques, casos, escenarios
│   ├── cutoff.dart                 NSR, breakeven, marginal, Lane, curva ley-tonelaje
│   ├── scheduler.dart              precedencia, capacidad, flujo de caja, VAN/TIR/payback
│   ├── analysis.dart               tornado, Lane iterativo, detección de high-grading
│   ├── tutor.dart                  motor de reglas y puntaje compuesto
│   └── export.dart                 CSV
├── data/
│   ├── case_repository.dart        3 casos + generador determinista
│   └── assessment_repository.dart  diagnóstico, reflexiones, tarea de transferencia
├── viewmodels/session.dart         ViewModel + providers + persistencia
├── widgets/
│   ├── block_views.dart            sección 2D e isométrico
│   └── charts.dart                 ley-tonelaje, tornado, flujo de caja
└── screens/
    ├── home.dart · workspace.dart · assessment.dart · theory.dart
test/domain_test.dart               incluye regresión pedagógica
```
