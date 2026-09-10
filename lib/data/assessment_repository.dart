/// Pregunta de opción múltiple con explicación posterior.
class Question {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String concept;

  const Question({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.concept,
  });
}

/// Pregunta de reflexión que se dispara DENTRO de la simulación, en el
/// momento exacto en que el estudiante acaba de provocar la consecuencia.
/// Esta es la unidad de aprendizaje de la aplicación: sin ella, mover
/// sliders es entretenimiento, no estudio.
class ReflectionPrompt {
  final String id;
  final String trigger;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const ReflectionPrompt({
    required this.id,
    required this.trigger,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class AssessmentRepository {
  /// Se usa idéntico antes y después de la sesión. La pregunta 1 es la que
  /// mide el error conceptual más extendido del tema.
  static const List<Question> diagnostic = [
    Question(
      id: 'q1',
      prompt:
          'La recuperación metalúrgica de la planta baja de 92 % a 85 %. '
          'Manteniendo todo lo demás igual, la ley de corte:',
      options: [
        'Sube: hace falta más ley para pagar el mismo costo',
        'Baja: la planta es menos exigente',
        'No cambia: la recuperación es un tema de planta, no de mina',
        'Depende del método de explotación',
      ],
      correctIndex: 0,
      explanation:
          'La ley de corte se despeja de la igualdad ingreso = costo. La '
          'recuperación está del lado del ingreso, así que al despejar queda '
          'DIVIDIENDO. Menos recuperación significa que cada tonelada rinde '
          'menos metal pagable, y por lo tanto se necesita más ley para cubrir '
          'el mismo costo. La ley de corte SUBE y las reservas caen.',
      concept: 'Ley de corte',
    ),
    Question(
      id: 'q2',
      prompt:
          'En un tajo abierto ya diseñado, un bloque de baja ley está sobre el '
          'camión. Para decidir si va a planta o a botadero, el costo relevante es:',
      options: [
        'El costo total: minado + procesamiento + G&A',
        'Solo procesamiento + G&A',
        'Solo el costo de minado',
        'El costo total más el CAPEX prorrateado',
      ],
      correctIndex: 1,
      explanation:
          'El costo de minado ya se incurrió: el bloque salió del pit de todas '
          'formas. Es costo hundido para esta decisión. Lo único que cambia '
          'según el destino es el costo de procesamiento y G&A. Esa es la ley '
          'de corte marginal.',
      concept: 'Costo hundido',
    ),
    Question(
      id: 'q3',
      prompt: 'Al SUBIR la ley de corte, típicamente ocurre que:',
      options: [
        'Sube el tonelaje y sube la ley media de alimentación',
        'Baja el tonelaje y baja la ley media',
        'Baja el tonelaje y sube la ley media',
        'Sube el tonelaje y baja la ley media',
      ],
      correctIndex: 2,
      explanation:
          'Es el trade-off central de la curva ley-tonelaje: al ser más '
          'exigente se descartan los bloques pobres, así que queda menos '
          'material pero de mejor calidad promedio.',
      concept: 'Curva ley-tonelaje',
    ),
    Question(
      id: 'q4',
      prompt:
          'Un pit óptimo calculado con un precio de cobre de 3,50 \$/lb es:',
      options: [
        'El pit óptimo del yacimiento, independiente del mercado',
        'Óptimo solo para ese precio y esos costos',
        'El pit de máxima extracción de metal',
        'El pit que minimiza la relación de descapote',
      ],
      correctIndex: 1,
      explanation:
          'El pit óptimo no es una propiedad geológica: es una respuesta '
          'económica. Cambia el precio y cambia la geometría del pit. Además, '
          'el óptimo de Lerchs-Grossmann ignora el tiempo, así que ni siquiera '
          'es óptimo en valor presente.',
      concept: 'Optimización de pit',
    ),
    Question(
      id: 'q5',
      prompt:
          'Un proyecto tiene VAN positivo a 8 % y VAN negativo a 12 %. Esto '
          'significa que su TIR está:',
      options: [
        'Por debajo de 8 %',
        'Entre 8 % y 12 %',
        'Por encima de 12 %',
        'No se puede saber',
      ],
      correctIndex: 1,
      explanation:
          'La TIR es la tasa que hace VAN = 0. Si el VAN cambia de signo entre '
          '8 % y 12 %, la TIR está en ese intervalo.',
      concept: 'Indicadores económicos',
    ),
    Question(
      id: 'q6',
      prompt:
          'La razón técnica por la que muchas minas empiezan con leyes de corte '
          'altas y las bajan con los años es:',
      options: [
        'Porque la ley del yacimiento disminuye en profundidad',
        'Porque el costo de oportunidad de la capacidad de planta es mayor al '
            'inicio, cuando queda mucho VAN por delante',
        'Porque las leyes altas se agotan primero por geología',
        'Por exigencias ambientales',
      ],
      correctIndex: 1,
      explanation:
          'Es la teoría de la ley de corte de Lane. Procesar una tonelada '
          'pobre hoy ocupa capacidad de planta que podría usarse para una '
          'tonelada rica; ese costo de oportunidad es proporcional al VAN '
          'remanente, que es máximo al inicio y cae a cero al final de la vida '
          'de la mina.',
      concept: 'Ley de corte de Lane',
    ),
  ];

  /// Reflexiones contextuales. La app las lanza cuando detecta la condición.
  static const List<ReflectionPrompt> reflections = [
    ReflectionPrompt(
      id: 'r_price_down',
      trigger: 'priceDrop',
      prompt:
          'Bajaste el precio y el tonelaje de reservas cayó, pero la ley media '
          'de alimentación SUBIÓ. ¿Por qué?',
      options: [
        'Porque el yacimiento se enriquece cuando cae el precio',
        'Porque la ley de corte subió y se descartaron los bloques más pobres',
        'Porque la planta recupera mejor con menos tonelaje',
        'Es un error de cálculo de la aplicación',
      ],
      correctIndex: 1,
      explanation:
          'El yacimiento no cambió: cambió el umbral. Al subir la ley de corte '
          'se retiran del inventario los bloques de menor ley, y el promedio de '
          'los que quedan sube automáticamente. La geología es la misma; la '
          'economía es otra.',
    ),
    ReflectionPrompt(
      id: 'r_recovery',
      trigger: 'recoveryChange',
      prompt:
          'Moviste la recuperación metalúrgica. ¿Qué le pasó a la ley de corte '
          'y por qué?',
      options: [
        'Bajó, porque la planta procesa menos metal',
        'Subió al bajar la recuperación, porque cada tonelada rinde menos '
            'metal pagable y hace falta más ley para cubrir el costo',
        'No cambió, la recuperación no entra en la ley de corte',
        'Cambió de forma impredecible',
      ],
      correctIndex: 1,
      explanation:
          'La recuperación divide en la fórmula de ley de corte. Es el error '
          'más frecuente del tema: mucha gente la coloca multiplicando, lo que '
          'invierte el sentido del resultado.',
    ),
    ReflectionPrompt(
      id: 'r_marginal',
      trigger: 'belowBreakeven',
      prompt:
          'Bajaste la ley de corte por debajo del costo total pero por encima '
          'del costo de planta. En un tajo abierto, ¿eso es un error?',
      options: [
        'Sí, siempre hay que cubrir el costo total',
        'No: si el bloque ya se mina de todos modos, basta con cubrir el costo '
            'incremental de procesarlo',
        'Sí, porque el VAN siempre baja',
        'Solo es válido en minería subterránea',
      ],
      correctIndex: 1,
      explanation:
          'Es la diferencia entre breakeven y marginal. La breakeven decide si '
          'el proyecto existe; la marginal decide el destino de un bloque que '
          'ya está minado. En subterránea la lógica cambia, porque ahí sí se '
          'elige no extraer.',
    ),
    ReflectionPrompt(
      id: 'r_sequence',
      trigger: 'sequenceChanged',
      prompt:
          'Cambiaste el orden de las fases y el VAN se movió sin que cambiara '
          'ni un gramo de metal contenido. ¿Cómo se explica?',
      options: [
        'Porque cambió la ley de corte',
        'Porque el valor presente depende de CUÁNDO llega la caja, no solo de '
            'cuánta caja hay',
        'Porque la recuperación depende de la secuencia',
        'Es un error de la simulación',
      ],
      correctIndex: 1,
      explanation:
          'El metal total es el mismo, pero adelantar los bloques de mayor '
          'valor adelanta el flujo de caja, y un dólar hoy vale más que un '
          'dólar en el año 8. Esa es toda la razón por la que existe el '
          'secuenciamiento como disciplina.',
    ),
    ReflectionPrompt(
      id: 'r_utilization',
      trigger: 'lowUtilization',
      prompt:
          'Tu ley de corte dejó la planta operando al 60 % de su capacidad. '
          '¿Cuál es el costo real de esa decisión?',
      options: [
        'Ninguno: se procesa solo lo rentable',
        'Los costos fijos se reparten entre menos toneladas y el costo '
            'unitario sube, además de estirar la vida de mina y diferir caja',
        'Solo un costo de imagen ante la gerencia',
        'Aumenta la recuperación metalúrgica',
      ],
      correctIndex: 1,
      explanation:
          'Una planta ociosa sigue costando. Y como el VAN castiga el tiempo, '
          'estirar la vida de mina para procesar el mismo metal casi siempre '
          'destruye valor presente.',
    ),
  ];

  /// Tarea de transferencia: se resuelve SIN la app. Es la única evidencia
  /// real de aprendizaje, porque separa comprender de manejar la interfaz.
  static const String transferTask = '''
Un yacimiento de cobre tiene los siguientes parámetros:

- Costo de minado: 2,80 \$/t movida
- Costo de procesamiento: 9,20 \$/t tratada
- Gastos generales: 1,60 \$/t tratada
- Recuperación metalúrgica: 86 %
- Pagabilidad del concentrado: 96,5 %
- Cargos de tratamiento y refinación: 0,32 \$/lb
- Precio del cobre: 3,80 \$/lb

Sin usar la aplicación, resuelve en papel:

1. Calcula la ley de corte breakeven y la ley de corte marginal.
2. El precio cae a 3,00 \$/lb. Recalcula ambas.
3. Explica en dos frases qué le ocurre al tonelaje de reservas y a la ley
   media de alimentación, y por qué.
4. La planta sufre un problema metalúrgico y la recuperación baja a 79 %.
   ¿La ley de corte sube o baja? Justifica con la fórmula, no de memoria.
''';
}
