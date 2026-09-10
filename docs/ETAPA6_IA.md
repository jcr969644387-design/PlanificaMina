# Etapa 6 — Integración de inteligencia artificial

*AI Integration Specialist · PlanificaMina*

---

## 1. Oportunidad de IA

**Conclusión adelantada: el MVP no debe llevar IA generativa, y la app implementada no la lleva.**

El brief original pedía un "tutor IA que analice el plan y sugiera mejoras". Al desglosar qué hace realmente ese tutor, aparecen cuatro funciones distintas:

| Función pedida | ¿Necesita IA? | Cómo se resolvió |
|---|---|---|
| Detectar errores de planeamiento | **No** | Motor de reglas determinista, 9 reglas |
| Explicar por qué es un error | **No** | Explicaciones escritas y validables por un docente |
| Sugerir la mejora concreta | **No** | La app calcula Lane y compara contra el plan del estudiante |
| Responder preguntas abiertas del estudiante fuera del catálogo | **Sí** | Único caso genuino; queda para v3 |

Tres de las cuatro funciones se resuelven mejor sin IA: más rápido, sin conexión, sin costo por consulta y con respuestas auditables. **La cuarta es la única oportunidad real de IA en este producto.**

Un motor de reglas tiene además una ventaja pedagógica que un LLM no puede igualar en este contexto: es **determinista**. Dos estudiantes con el mismo error reciben exactamente la misma explicación, y un docente puede revisar de antemano el catálogo completo de lo que la app va a decir. Eso importa cuando el contenido va a ser evaluado en un curso.

---

## 2. Problema educativo que resuelve

El problema que quedaría sin resolver sin IA es concreto y acotado:

> El estudiante formula una pregunta que el catálogo de reglas no anticipó — *"¿por qué mi VAN sube si dejo mineral sin extraer?"*, *"¿esto se parece a lo que hacen en la mina donde hice prácticas?"* — y no hay nadie a quien preguntarle a las 11 de la noche antes de la práctica calificada.

Ese vacío es real. Pero es un problema de **cobertura de casos raros**, no del núcleo del aprendizaje. Resolverlo primero, antes de que el núcleo funcione, sería invertir el orden.

Hay además un problema que la IA **no** resuelve y conviene decirlo: si el estudiante no entiende la ley de corte, un chatbot que se la explique otra vez con otras palabras no cambia nada. Lo que cambia el entendimiento es la manipulación del modelo con la consecuencia a la vista, y eso ya lo hace la app sin IA.

---

## 3. Caso de uso propuesto

**Un único caso de uso, y estrictamente acotado: asistente de preguntas abiertas sobre el plan que el estudiante tiene en pantalla.**

Características obligatorias del diseño:

- **Con contexto del plan.** El prompt incluye el estado real: ley de corte, escenario, secuencia, VAN, hallazgos del motor de reglas. Un chatbot sin ese contexto daría respuestas genéricas de libro de texto, que es exactamente lo que el estudiante ya tiene.
- **Como capa, no como reemplazo.** El motor de reglas corre siempre. El LLM solo atiende lo que las reglas no cubren.
- **Degradable.** Sin conexión, la app funciona idéntica menos ese botón. Nunca puede ser una dependencia.
- **Socrático por diseño.** Debe devolver preguntas y pistas, no soluciones. Un tutor que entrega la respuesta correcta convierte la app en una calculadora con voz.

**Casos de uso explícitamente rechazados:**

| Propuesta | Por qué se rechaza |
|---|---|
| Generación automática de casos de estudio | Un yacimiento mal generado enseña geología falsa. La calidad debe ser garantizada, no probable |
| Corrección automática de respuestas abiertas para nota | Requiere fiabilidad que no se puede garantizar, y traslada al modelo una responsabilidad académica que es del docente |
| Chatbot conversacional general | Sin propósito educativo definido; compite con el bucle de manipulación directa que sí funciona |
| Personalización adaptativa con ML | No hay datos. Y con 30 estudiantes nunca los habrá en cantidad suficiente para entrenar nada |
| Predicción del rendimiento del estudiante | Riesgo de etiquetado, valor educativo nulo |

---

## 4. Tipo de IA recomendada

**Para el MVP: sistema experto por reglas.** Está implementado en `domain/tutor.dart`: 9 reglas que evalúan el plan y emiten hallazgos con nivel, explicación, pregunta socrática y concepto asociado. Es la tecnología correcta porque el dominio tiene **errores conocidos y enumerables**, que es precisamente la condición bajo la cual un sistema experto supera a un modelo estadístico.

**Para v3: LLM de propósito general vía API**, no un modelo entrenado ni afinado.

- *Fine-tuning*: descartado. Requiere miles de ejemplos de calidad que no existen, y quedaría obsoleto con cada mejora del modelo base.
- *Modelo local en el dispositivo*: descartado. Tamaño de APK, consumo de batería y calidad insuficiente en razonamiento técnico en español.
- *RAG sobre bibliografía de planeamiento*: es la extensión natural del LLM por API, pero solo tiene sentido una vez que haya un corpus curado y con derechos de uso resueltos.

**No corresponden a este producto:** visión artificial, reconocimiento de voz, sistemas de recomendación, análisis predictivo.

---

## 5. Beneficio esperado

Beneficio del **motor de reglas ya implementado** (esto es lo que la app entrega hoy):

- Retroalimentación específica e inmediata sobre el plan real, sin conexión y sin costo marginal.
- Cobertura garantizada de los errores conceptuales de mayor frecuencia: recuperación mal aplicada, confusión breakeven/marginal, violación de precedencia, high-grading no argumentado, planta subutilizada, VAN negativo mal diagnosticado.
- Auditabilidad: el docente puede leer las 9 reglas antes de usar la app en clase.

Beneficio **incremental** que aportaría el LLM en v3: atender el ~10–20 % de preguntas fuera del catálogo. Es una mejora de cobertura, no un salto de capacidad. Debe evaluarse contra su costo.

---

## 6. Riesgos

| Riesgo | Gravedad | Mitigación |
|---|---|---|
| **Respuesta incorrecta con autoridad de sistema** | Crítica | El LLM nunca calcula: los números vienen del motor determinista. El modelo solo explica. Y se marca visiblemente como generado |
| **Dependencia excesiva** | Alta | Diseño socrático obligatorio; límite de consultas por sesión; el botón no aparece hasta que el estudiante haya intentado el diagnóstico de reglas |
| **Privacidad** | Alta | El texto del estudiante saldría a un tercero. Requiere consentimiento explícito y atención especial si hay menores de edad. Hoy la app no envía nada, y esa es una propiedad valiosa que se perdería |
| **Claves de API expuestas** | Crítica | Jamás en el cliente. Obliga a un proxy propio, es decir, a un backend que hoy no existe |
| **Costo operativo** | Media | Sin patrocinio, cada consulta cuesta. Requiere límites duros y monitoreo |
| **Latencia y offline** | Media | Degradación explícita: la app completa debe seguir funcionando |
| **Pérdida de control académico** | Alta | Revisión docente de los prompts y muestreo periódico de respuestas reales |
| **IA como excusa para no resolver el diseño** | Alta | Es el riesgo más subestimado: agregar un chatbot es más fácil que diseñar buena retroalimentación, y produce mucho menos aprendizaje |

**Cuándo la IA perjudicaría la experiencia:** si responde antes de que el estudiante piense; si sus explicaciones contradicen al motor determinista; si su latencia rompe el bucle de decisión-consecuencia que es el corazón de la app; o si su presencia hace que la app deje de funcionar en un aula sin señal.

---

## 7. Estrategia MVP

**Nivel 1 — MVP sin IA (implementado).**
Motor de reglas, cálculo determinista, funcionamiento offline completo. La app es plenamente útil en este estado. **Además, este nivel cumple una segunda función: recolectar los errores reales de los estudiantes** a través de las reflexiones contextuales. Sin ese corpus, cualquier tutor de v3 estaría construido contra errores imaginados.

**Nivel 2 — IA inicial (v2, opcional y condicionada).**
Un solo punto de entrada: botón *"Preguntar sobre mi plan"* dentro de la pestaña Tutor, con el estado del plan como contexto, respuesta socrática, marcado como generado por IA, y degradación limpia sin conexión.

*Condiciones para activarlo — las tres, no una:*
1. La validación con estudiantes muestra mejora en la tarea de transferencia.
2. Existe un corpus documentado de preguntas que las reglas no cubrieron.
3. Hay un docente dispuesto a revisar periódicamente muestras de respuestas.

Si alguna falta, no se incorpora.

**Nivel 3 — IA futura (v3).**
Explicación adaptada al historial del estudiante; generación de variantes numéricas de la tarea de transferencia (con validación automática de que el ejercicio tenga solución no degenerada); asistencia al docente para resumir los errores frecuentes de una cohorte. Todo sobre un backend propio con control de costo y consentimiento resuelto.

---

## 8. Evolución futura y medición de impacto

**Datos necesarios y su origen:**

| Dato | Origen | Quién valida |
|---|---|---|
| Catálogo de errores conceptuales | Literatura + docentes + reflexiones del MVP | Docente de planeamiento |
| Explicaciones correctas | Escritas y revisadas | Docente de planeamiento |
| Preguntas fuera de catálogo | Registro local durante la validación | Equipo de producto |
| Parámetros económicos de los casos | Rangos públicos de mercado | Docente + revisión de orden de magnitud |

Riesgo de calidad principal: contenido escrito por quien desarrolla y no revisado por un especialista. Ya ocurrió una vez — la fórmula de ley de corte del brief original estaba invertida. **La revisión académica no es opcional.**

**Cómo medir si la IA aporta (cuando exista):**

- Comparación A/B con y sin acceso al asistente, midiendo **desempeño en la tarea de transferencia**, no satisfacción.
- Proporción de consultas que el motor de reglas ya cubría (si es alta, el LLM sobra).
- Cambio en el tiempo hasta corregir un error conceptual tras la primera detección.
- Tasa de respuestas marcadas como incorrectas por revisión docente.

**Métricas prohibidas como evidencia de éxito:** número de consultas al asistente, tiempo en pantalla, "engagement", satisfacción declarada. Un chatbot muy usado puede ser exactamente el síntoma de que los estudiantes dejaron de pensar por su cuenta.

---

## Síntesis

> **¿Sería PlanificaMina significativamente mejor con IA generativa?**
> Hoy, no. El valor educativo está en el bucle decisión-consecuencia-reflexión, que no requiere IA y que funciona mejor sin latencia y sin conexión.
>
> La IA tiene un lugar legítimo pero acotado: cubrir las preguntas que el catálogo de reglas no anticipa. Ese lugar se gana después de demostrar aprendizaje, no antes — y el propio MVP es el instrumento que genera los datos para construirla bien.
