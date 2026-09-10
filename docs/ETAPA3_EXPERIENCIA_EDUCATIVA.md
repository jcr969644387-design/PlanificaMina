# Etapa 3 — Diseño de experiencia educativa

*Educational UX Designer · PlanificaMina*

---

## 1. Objetivo educativo

Que el estudiante deje de tratar la ley de corte como un dato del yacimiento y empiece a tratarla como una decisión económica con consecuencias físicas visibles.

Competencia profesional que fortalece: **determinar y defender una ley de corte y una secuencia de extracción ante variaciones de precio, costo y recuperación.**

Criterio de logro: el estudiante resuelve el problema en papel, sin la app, una semana después.

---

## 2. Usuario

Estudiante de Ingeniería de Minas de 4.º–5.º año, cursando Planeamiento Minero o Evaluación de Proyectos. Usa la app en el móvil, en sesiones de 15–40 minutos, muchas veces en clase o antes de una práctica calificada. Trae de la teoría una fórmula memorizada — con frecuencia mal memorizada — y ninguna intuición sobre cómo se comporta.

---

## 3. Flujo de aprendizaje

```
Diagnóstico (6 preguntas, 5 min)
        │  mide el punto de partida; sin penalidad
        ▼
Elección de caso  ──►  Modelo de bloques
        │                     │ ve el yacimiento antes de tocar economía
        ▼                     ▼
   LEY DE CORTE  ◄──────── ciclo principal
        │
        │  mueve una variable → el cuerpo económico cambia en la sección
        │  → los KPI se recalculan → aparece la REFLEXIÓN
        │
        ▼
  Programación ──► Economía ──► Tutor
        │             │            │ diagnóstico de reglas + puntaje
        ▼             ▼            ▼
        Evaluación de cierre (mismas 6 preguntas)
                      │
                      ▼
            Tarea de transferencia (en papel, sin app)
```

El ciclo principal es deliberadamente corto: **decisión → consecuencia visible → pregunta**. Todo lo demás orbita alrededor de ese bucle.

---

## 4. Módulos

| Módulo | Propósito educativo | Por qué existe |
|---|---|---|
| **Modelo** | Anclar la economía en un objeto físico | Sin ver el yacimiento, la ley de corte es aritmética abstracta |
| **Ley de corte** | Módulo núcleo: el bucle de decisión | Es el 60 % del valor educativo de la app |
| **Programa** | Introducir el tiempo y las restricciones | Convierte un número en un plan |
| **Economía** | Cerrar el ciclo en VAN, TIR y sensibilidad | Conecta la decisión técnica con el lenguaje de gerencia |
| **Tutor** | Devolver diagnóstico y puntaje | Cierra el bucle de retroalimentación |

Ninguna pantalla es informativa pura. La única pantalla de lectura (Conceptos y límites) existe porque **los límites del modelo son contenido**, no un descargo legal.

---

## 5. Interacción

**Acción principal:** arrastrar un control y observar. La app está construida alrededor de que esa acción se sienta instantánea; por eso todo el cálculo es local y síncrono.

**Retroalimentación en tres capas simultáneas:**
1. *Espacial* — el cuerpo económico se apaga o se enciende en la sección.
2. *Numérica* — tonelaje, ley media, NSR y VAN se recalculan.
3. *Conceptual* — la hoja de reflexión interrumpe y pregunta por qué.

**Decisiones de interacción deliberadas:**

- **El desmonte se apaga, no desaparece.** El estudiante debe seguir viendo que el material existe; solo dejó de ser económico. Ocultarlo enseñaría que la ley de corte cambia la geología.
- **El contorno del cuerpo económico se dibuja en vivo.** Es el elemento visual que carga el concepto: es una línea que se mueve cuando cambia el mercado.
- **El sistema no optimiza el secuenciamiento: lo valida.** Cuando el estudiante rompe una precedencia, la app no corrige el orden — marca la fase en rojo y explica que no hay acceso físico. Corregir automáticamente eliminaría el aprendizaje.
- **Los criterios de ley de corte son botones, no un menú.** Breakeven, marginal y Lane están uno al lado del otro con su valor numérico visible, de modo que la diferencia entre ellos sea perceptible antes de ser explicada.
- **Una sola pregunta a la vez.** La hoja de reflexión bloquea el resto de la interfaz: es la única interrupción que la app se permite.

**Prevención de errores:** no se impide llegar a estados "malos" — un VAN negativo o una planta al 50 % son estados legítimos y educativos. Lo que la app impide es *no darse cuenta*.

---

## 6. Evaluación

Tres niveles, de menor a mayor validez:

| Nivel | Instrumento | Qué mide realmente |
|---|---|---|
| 1 | Reflexiones contextuales (5) | Comprensión en el momento, con la consecuencia a la vista |
| 2 | Diagnóstico / cierre (6 preguntas) | Cambio conceptual pre-post |
| 3 | **Tarea de transferencia en papel** | Si aprendió el concepto o aprendió la interfaz |

**El nivel 3 es el que decide.** Un estudiante puede subir de 2/6 a 6/6 en el post-test simplemente por haber visto las explicaciones, y aun así ser incapaz de calcular una ley de corte en un examen. Por eso la app entrega la tarea de transferencia con datos distintos y sin herramientas.

Métricas que la app **no** usa como evidencia de aprendizaje: tiempo en pantalla, número de escenarios corridos, satisfacción declarada, descargas.

---

## 7. Mejoras UX

**Gamificación — solo la que se justifica.**

- *Progresión de roles* (Planificador Junior → Jefe de Planeamiento → Gerente de Operaciones): **se mantiene**, porque cada nivel corresponde a un aumento real de complejidad decisional, no a un título cosmético.
- *Ranking por VAN*: **eliminado**. Premia el high-grading, que es exactamente lo que la planificación real castiga. Se sustituye por un **puntaje compuesto** (valor 35 / restricciones 25 / robustez 15 / comprensión 25) donde maximizar VAN rompiendo restricciones no aprueba.
- *Puntos e insignias sueltas*: descartados. No resuelven ningún problema de aprendizaje identificado.

**Personalización.** El tutor de reglas adapta el diagnóstico al estado real del plan: quien nunca baja de la breakeven recibe la explicación de costo hundido; quien agota la alta ley al inicio recibe la de Lane. No hay dos sesiones con la misma retroalimentación.

**Diseño móvil.**
- Paleta oscura de roca: legible con brillo bajo, ahorra batería en OLED y no compite con la escala de leyes.
- Navegación de cinco destinos fijos, sin jerarquías anidadas: el estudiante nunca se pierde.
- Todos los números en las mismas unidades (Mt, M\$, %) en toda la app.
- Orientación vertical bloqueada: la sección y los controles están diseñados para una mano.
- La tabla de producción es el único elemento con desplazamiento horizontal, y es deliberado: obliga a leerla como lo que es, una planilla.

**Accesibilidad pendiente (v2):** contraste verificado contra WCAG AA, escalado de texto del sistema, y una alternativa a la codificación por color de la escala de leyes para daltonismo — hoy el color es el único canal que transmite la ley, lo cual es una debilidad real del diseño actual.
