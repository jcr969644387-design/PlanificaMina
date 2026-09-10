# Correcciones aplicadas al brief original

Este documento deja constancia de los errores detectados en la especificación inicial y de cómo quedaron resueltos en el código. Se conserva porque un error de contenido en una app educativa llega al estudiante con autoridad de sistema: si no queda trazado, reaparece.

---

## 1. Fórmula de ley de corte invertida — **crítico**

**Lo que decía el brief:**

```
Ley de corte = (Costo total / Precio) × Recuperación
```

**Por qué está mal.** La recuperación pertenece al lado del ingreso de la igualdad *ingreso = costo*. Al despejar la ley, pasa **dividiendo**. Multiplicando, la fórmula invierte el sentido físico: predice que una planta que recupera menos metal necesita **menos** ley para ser rentable. Faltaba además el factor de conversión de unidades, sin el cual el resultado no tiene dimensiones coherentes.

**Fórmula correcta implementada** (`domain/models.dart`, `domain/cutoff.dart`):

```
valor unitario ($/t por unidad de ley):
  metal en %  con precio en $/lb :  (P·pagabilidad − cargos) × 22,0462 × recuperación
  metal en g/t con precio en $/oz:  (P·pagabilidad − cargos) ÷ 31,1035 × recuperación

ley de corte = Costo ($/t) ÷ valor unitario
```

**Protección contra regresión** (`test/domain_test.dart`):

```dart
test('menor recuperación implica MAYOR ley de corte', () {
  final alta = CutoffCalculator.nsrToGrade(88, au);              // 1,6608 g/t
  final baja = CutoffCalculator.nsrToGrade(88, au.copyWith(recovery: 0.85));
  expect(baja, greaterThan(alta));                               // 1,7976 g/t
});
```

Este error se convirtió además en **contenido**: es la pregunta 1 del diagnóstico y la reflexión `r_recovery`, porque es el error conceptual más extendido del tema.

---

## 2. Casos de estudio degenerados — **crítico**

**El problema.** Con los parámetros del brief, en el caso de cobre y en el polimetálico la ley de corte caía muy por debajo del rango de leyes del modelo de bloques: **todos** los bloques resultaban mineral. El ejercicio de ley de corte no tenía decisión — mover el precio no cambiaba nada.

**Cómo quedó.** Los tres modelos se calibraron numéricamente para que la ley de corte caiga dentro del rango de leyes y para que los escenarios pesimista y optimista produzcan cambios materiales:

| Caso | Rango de leyes | Ley de corte según escenario | Mineral sobre ley | Vida de mina |
|---|---|---|---|---|
| Veta San Rafael (Au) | 0,04 – 3,88 g/t | 1,36 → 1,66 → 1,98 g/t | 21 % – 33 % | 5,7 – 9,0 años |
| Pórfido Alto Chico (Cu) | 0,015 – 1,99 % | 0,130 → 0,159 → 0,204 % | 49 % – 61 % | 12 – 15 años |
| Manto Quilcaya (Zn-Pb-Ag) | NSR 2,8 – 142 \$/t | ley de corte 53 \$/t NSR | 15 % – 37 % | 4,1 – 12,3 años |

**Calibración económica** (VAN base ajustado a propósito, para que el escenario pesimista sea capaz de volverlo negativo):

| Caso | CAPEX | VAN base | TIR base | VAN pesimista |
|---|---|---|---|---|
| Au subterráneo | 72 M\$ | ≈ +11 M\$ | ≈ 14 % | negativo |
| Cu tajo abierto | 820 M\$ | ≈ +83 M\$ | ≈ 12 % | negativo |
| Polimetálico | 55 M\$ | ≈ +27 M\$ | ≈ 23 % | ≈ −30 M\$ |

**Protección contra regresión:** para cada caso, la suite exige que exista material **sobre y bajo** la ley de corte, que la fracción de mineral esté entre 5 % y 85 %, y que bajar el precio reduzca el tonelaje económico. Si alguien recalibra un caso y lo vuelve degenerado, la prueba falla.

---

## 3. Caso polimetálico con fórmula monometálica — **grave**

Con tres metales no existe "una ley de corte": la decisión se toma sobre el **NSR**, el valor neto por tonelada después de pagabilidad y cargos de tratamiento de cada concentrado.

El motor trabaja **siempre** en NSR (\$/t), incluso en los casos monometálicos, y solo convierte a unidades de ley para mostrarlo en pantalla. En el caso polimetálico la ley de corte se muestra directamente en \$/t, que es como se expresa en la práctica profesional.

---

## 4. Ranking por VPN — **de diseño**

El brief proponía rankear estudiantes por VPN. El VPN se maximiza con **high-grading**: agotar la ley alta al inicio. Es una estrategia legítima en ciertos contextos, pero premiarla como único criterio enseña lo contrario de lo que la planificación real exige.

**Sustituido por puntaje compuesto** (`domain/tutor.dart`):

| Componente | Puntos |
|---|---|
| Valor económico | 35 |
| Cumplimiento de restricciones | 25 |
| Comprensión conceptual demostrada | 25 |
| Robustez ante escenarios | 15 |

Los roles (Planificador Junior → Jefe de Planeamiento → Gerente de Operaciones) se conservan porque cada nivel corresponde a un aumento real de complejidad decisional. El ranking entre estudiantes se eliminó.

La app además **detecta** el high-grading (`PlanDiagnostics.gradeDeclineIndex`) y no lo castiga: pide al estudiante que lo argumente.

---

## 5. Vacío conceptual: faltaba Lane — **de contenido**

El brief prometía enseñar el trade-off temporal del planeamiento, pero solo incluía ley de corte breakeven. El concepto que responde ese trade-off es la **ley de corte de Lane**, con costo de oportunidad de la capacidad del cuello de botella.

Implementada en `domain/analysis.dart` por iteración de punto fijo amortiguada (la ley de corte depende del VAN remanente y el VAN remanente depende de la ley de corte). Es lo que explica que las minas reales empiecen con leyes de corte altas y las bajen con los años — comportamiento que suele explicarse mal como "la geología se empobrece".

---

## 6. Alcance del "MVP" — **de producto**

El brief llamaba MVP a un producto de siete subsistemas. El análisis de la Etapa 4 lo redujo a uno: el bucle de ley de corte.

La aplicación entregada **excede** ese MVP mínimo, porque una vez construido el motor determinista varias funciones salían casi sin costo estructural (Lane, NSR, tornado, isométrico, exportación, tres casos). Lo que **no** se incorporó, y sigue fuera por decisión razonada: optimización de pit, incertidumbre geológica, modo docente con backend y tutor con LLM.

---

## 7. Otras correcciones menores

- **Segmento "pequeños mineros" eliminado.** Un modelo educativo simplificado no debe orientarse a decisiones de inversión reales. La app lleva ese aviso en pantalla, no escondido.
- **Minas reales sustituidas por yacimientos ficticios.** Nombrar operaciones existentes con parámetros inventados es incorrecto y expone al proyecto.
- **Límites del modelo convertidos en contenido.** Siete limitaciones explícitas en la pantalla de Conceptos, incluida la más importante: *no existe "el" pit óptimo*. Un estudiante que sale creyendo que sí, aprendió algo peor que nada.
- **Clasificación de recursos advertida.** El modelo trata todo el material como recurso medido; la app señala que en un proyecto real solo los medidos e indicados pueden sustentar un plan de producción.

---

## Verificación numérica

Toda la matemática fue replicada de forma independiente antes de escribirla en Dart, y los valores esperados quedaron fijados en la suite de pruebas:

| Magnitud | Valor verificado |
|---|---|
| Valor unitario Au (1800 \$/oz, rec 92 %, pag 99,8 %, ded 5 \$/oz) | 52,9872 \$/t por g/t |
| Valor unitario Cu (3,50 \$/lb, rec 88 %, pag 96,5 %, ded 0,30 \$/lb) | 59,7055 \$/t por 1 % |
| Ley de corte breakeven Au (costo 88 \$/t) | 1,6608 g/t |
| Ley de corte marginal Au (costo 43 \$/t) | 0,8115 g/t |
| NSR polimetálico (Zn 4 %, Pb 1,2 %, Ag 55 g/t) | 91,72 \$/t |
| VAN (10 %, CAPEX 100, flujos 50/50/50) | 24,3426 |
| TIR (CAPEX 100, flujos 50/50/50) | 23,375 % |
| Payback descontado | 2,352 años |
