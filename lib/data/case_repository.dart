import 'dart:math' as math;

import '../domain/models.dart';

/// Generador congruencial lineal: garantiza que el modelo de bloques sea
/// idéntico en todos los dispositivos y en todas las sesiones. Un caso de
/// estudio que cambia entre corridas no es evaluable.
class _Lcg {
  int _state;
  _Lcg(int seed) : _state = seed & 0x7fffffff;

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }

  /// Ruido centrado en 0 con distribución aproximadamente triangular.
  double noise() => (next() + next() - 1.0);
}

/// Los tres casos vienen con parámetros CALIBRADOS: la ley de corte cae
/// dentro del rango de leyes del modelo, de modo que mover el precio cambia
/// realmente el tonelaje económico. Un caso donde todos los bloques son
/// mineral no enseña nada sobre ley de corte.
class CaseRepository {
  static List<MineCase> all() => [
        _goldUnderground(),
        _copperOpenPit(),
        _polymetallic(),
      ];

  static MineCase byId(String id) =>
      all().firstWhere((c) => c.id == id, orElse: () => all().first);

  // ------------------------------------------------------------------
  // CASO 1 — Oro subterráneo (caso de entrada del MVP)
  // ------------------------------------------------------------------
  static MineCase _goldUnderground() {
    const nx = 20, ny = 5, nz = 10;
    const blockSize = 20.0;
    const density = 2.75;
    const tonnage = blockSize * blockSize * blockSize * density; // 22 000 t

    final rng = _Lcg(20240517);
    final blocks = <Block>[];

    for (int k = 0; k < nz; k++) {
      for (int j = 0; j < ny; j++) {
        for (int i = 0; i < nx; i++) {
          // Veta subvertical que buza: su centro en Y se desplaza con la
          // profundidad, y su potencia disminuye hacia abajo.
          final veinCenter = 2.0 + 0.12 * k;
          final halfWidth = 1.35 - 0.05 * k;
          final dist = (j - veinCenter).abs();

          // Clavo mineralizado (ore shoot) concentrado en el centro del rumbo.
          final along = (i - nx / 2 + 1.5) / (nx / 2);
          final shoot = math.exp(-2.2 * along * along);

          double grade;
          if (dist <= halfWidth) {
            grade = 0.9 + 3.0 * shoot * (0.55 + 0.45 * rng.next());
            grade *= 1.0 - 0.025 * k; // ligero empobrecimiento en profundidad
            grade += 0.25 * rng.noise();
          } else {
            // Encajonante con halo de baja ley.
            grade = 0.35 * math.exp(-1.1 * (dist - halfWidth)) +
                0.12 * rng.next();
          }
          grade = grade.clamp(0.02, 6.0).toDouble();

          blocks.add(Block(
            i: i,
            j: j,
            k: k,
            tonnage: tonnage,
            grades: {'Au': double.parse(grade.toStringAsFixed(3))},
            phaseIndex: k < 3
                ? 0
                : k < 6
                    ? 1
                    : k < 8
                        ? 2
                        : 3,
          ));
        }
      }
    }

    return MineCase(
      id: 'au_underground',
      name: 'Veta San Rafael',
      subtitle: 'Oro subterráneo · cámaras y pilares',
      geologyNote:
          'Veta epitermal de cuarzo-oro, subvertical, con un clavo '
          'mineralizado en el centro del rumbo. Potencia de 20 a 30 m que '
          'disminuye en profundidad. Yacimiento ficticio, representativo de '
          'sistemas vetiformes de oro.',
      learningFocus:
          'Ley de corte breakeven vs. marginal. El doré tiene deducciones '
          'de fundición mínimas, así que la fórmula simplificada es fiel a la '
          'realidad: es el caso ideal para entender el concepto sin ruido.',
      method: MiningMethod.underground,
      metals: const [
        Metal(
          symbol: 'Au',
          name: 'Oro',
          gradeUnit: GradeUnit.gramsPerTonne,
          priceUnit: PriceUnit.perOunce,
          price: 1800,
          recovery: 0.92,
          payability: 0.998,
          deduction: 5.0,
        ),
      ],
      costs: const CostStructure(
        mining: 45,
        processing: 35,
        ga: 8,
        sustaining: 6,
      ),
      millCapacity: 800000,
      mineCapacity: 950000,
      discountRate: 0.10,
      capex: 72000000,
      royaltyRate: 0.03,
      taxRate: 0.30,
      model: BlockModel(
        nx: nx,
        ny: ny,
        nz: nz,
        blockSize: blockSize,
        blocks: blocks,
      ),
      phases: const [
        MinePhase(
          index: 0,
          name: 'Nivel 4250',
          description: 'Nivel superior, acceso desde bocamina existente.',
          requires: [],
        ),
        MinePhase(
          index: 1,
          name: 'Nivel 4190',
          description: 'Requiere la rampa desarrollada desde el nivel 4250.',
          requires: [0],
        ),
        MinePhase(
          index: 2,
          name: 'Nivel 4130',
          description: 'Profundización intermedia.',
          requires: [1],
        ),
        MinePhase(
          index: 3,
          name: 'Nivel 4070',
          description: 'Nivel más profundo, potencia reducida.',
          requires: [2],
        ),
      ],
      priceRange: const {
        'Au': [1200, 2600],
      },
    );
  }

  // ------------------------------------------------------------------
  // CASO 2 — Pórfido de cobre a tajo abierto
  // ------------------------------------------------------------------
  static MineCase _copperOpenPit() {
    const nx = 22, ny = 14, nz = 10;
    const blockSize = 30.0;
    const density = 2.62;
    const tonnage = blockSize * blockSize * blockSize * density; // 70 740 t

    final rng = _Lcg(19980312);
    final blocks = <Block>[];
    const cx = 10.5, cy = 6.5;

    for (int k = 0; k < nz; k++) {
      for (int j = 0; j < ny; j++) {
        for (int i = 0; i < nx; i++) {
          final dx = (i - cx) / 7.5;
          final dy = (j - cy) / 5.0;
          final r = math.sqrt(dx * dx + dy * dy);

          // Zonación clásica de pórfido: núcleo de alta ley, halo que decae,
          // y enriquecimiento supergénico en los bancos superiores.
          final supergene = k <= 2 ? 1.28 : (k <= 4 ? 1.08 : 0.92);
          double grade = 1.55 * math.exp(-1.75 * r * r) * supergene;
          grade += 0.055 * rng.next();
          grade += 0.05 * rng.noise();
          grade = grade.clamp(0.015, 2.2).toDouble();

          // Fases (pushbacks): el starter pit es el núcleo; luego dos
          // expansiones laterales independientes; al final la profundización.
          int phase;
          if (k >= 7) {
            phase = 3;
          } else if (r < 0.62) {
            phase = 0;
          } else if (j <= cy) {
            phase = 1;
          } else {
            phase = 2;
          }

          blocks.add(Block(
            i: i,
            j: j,
            k: k,
            tonnage: tonnage,
            grades: {'Cu': double.parse(grade.toStringAsFixed(3))},
            phaseIndex: phase,
          ));
        }
      }
    }

    return MineCase(
      id: 'cu_openpit',
      name: 'Pórfido Alto Chico',
      subtitle: 'Cobre a tajo abierto · pushbacks',
      geologyNote:
          'Pórfido de cobre con núcleo de alta ley, halo de baja ley y '
          'enriquecimiento supergénico en los primeros bancos. El modelo '
          'incluye material estéril (0,02-0,15 % Cu), que es lo que hace que '
          'la ley de corte tenga consecuencia real. Yacimiento ficticio.',
      learningFocus:
          'Costo hundido de minado y ley de corte marginal. Aquí el desmonte '
          'se mina de todas formas: la pregunta no es si se extrae el bloque, '
          'sino a dónde se lleva.',
      method: MiningMethod.openPit,
      metals: const [
        Metal(
          symbol: 'Cu',
          name: 'Cobre',
          gradeUnit: GradeUnit.percent,
          priceUnit: PriceUnit.perPound,
          price: 3.50,
          recovery: 0.88,
          payability: 0.965,
          deduction: 0.30,
        ),
      ],
      costs: const CostStructure(
        mining: 2.5,
        processing: 8.0,
        ga: 1.5,
        sustaining: 1.2,
      ),
      millCapacity: 9000000,
      mineCapacity: 22000000,
      discountRate: 0.10,
      capex: 820000000,
      royaltyRate: 0.03,
      taxRate: 0.32,
      model: BlockModel(
        nx: nx,
        ny: ny,
        nz: nz,
        blockSize: blockSize,
        blocks: blocks,
      ),
      phases: const [
        MinePhase(
          index: 0,
          name: 'Fase 1 · Starter pit',
          description: 'Núcleo de alta ley, menor relación de descapote.',
          requires: [],
        ),
        MinePhase(
          index: 1,
          name: 'Fase 2 · Expansión norte',
          description: 'Requiere el starter pit abierto.',
          requires: [0],
        ),
        MinePhase(
          index: 2,
          name: 'Fase 3 · Expansión sur',
          description: 'Requiere el starter pit abierto.',
          requires: [0],
        ),
        MinePhase(
          index: 3,
          name: 'Fase 4 · Profundización',
          description:
              'Bancos inferiores. Necesita ambas expansiones para tener '
              'ángulo de talud y rampa.',
          requires: [1, 2],
        ),
      ],
      priceRange: const {
        'Cu': [2.20, 5.50],
      },
    );
  }

  // ------------------------------------------------------------------
  // CASO 3 — Polimetálico Zn-Pb-Ag (requiere NSR)
  // ------------------------------------------------------------------
  static MineCase _polymetallic() {
    const nx = 18, ny = 6, nz = 10;
    const blockSize = 20.0;
    const density = 3.15;
    const tonnage = blockSize * blockSize * blockSize * density;

    final rng = _Lcg(20070921);
    final blocks = <Block>[];

    for (int k = 0; k < nz; k++) {
      for (int j = 0; j < ny; j++) {
        for (int i = 0; i < nx; i++) {
          final center = 2.4 + 0.08 * k;
          const halfWidth = 1.5;
          final dist = (j - center).abs();
          final along = (i - nx / 2 + 1.0) / (nx / 2);
          final body = math.exp(-1.8 * along * along);

          double zn, pb, ag;
          if (dist <= halfWidth) {
            zn = 1.2 + 5.2 * body * (0.5 + 0.5 * rng.next());
            // Zonación vertical: el plomo y la plata aumentan hacia arriba.
            pb = (0.25 + 1.7 * body * rng.next()) * (1.25 - 0.05 * k);
            ag = (12 + 70 * body * rng.next()) * (1.20 - 0.045 * k);
          } else {
            final decay = math.exp(-1.4 * (dist - halfWidth));
            zn = 0.9 * decay + 0.15 * rng.next();
            pb = 0.20 * decay + 0.04 * rng.next();
            ag = 8.0 * decay + 3.0 * rng.next();
          }

          blocks.add(Block(
            i: i,
            j: j,
            k: k,
            tonnage: tonnage,
            grades: {
              'Zn': double.parse(zn.clamp(0.05, 9.0).toStringAsFixed(3)),
              'Pb': double.parse(pb.clamp(0.01, 3.5).toStringAsFixed(3)),
              'Ag': double.parse(ag.clamp(1.0, 140.0).toStringAsFixed(1)),
            },
            phaseIndex: k < 3
                ? 0
                : k < 6
                    ? 1
                    : k < 8
                        ? 2
                        : 3,
          ));
        }
      }
    }

    return MineCase(
      id: 'znpbag_poly',
      name: 'Manto Quilcaya',
      subtitle: 'Polimetálico Zn-Pb-Ag · subterránea',
      geologyNote:
          'Cuerpo mantiforme de sulfuros con zonación vertical: la plata y el '
          'plomo se enriquecen hacia los niveles superiores. Yacimiento '
          'ficticio, representativo de polimetálicos andinos.',
      learningFocus:
          'NSR (Net Smelter Return). Con tres metales no existe "una ley de '
          'corte": la decisión se toma sobre el valor neto por tonelada, '
          'descontando pagabilidad y cargos de tratamiento de cada '
          'concentrado. Es donde la fórmula monometálica deja de servir.',
      method: MiningMethod.underground,
      metals: const [
        Metal(
          symbol: 'Zn',
          name: 'Zinc',
          gradeUnit: GradeUnit.percent,
          priceUnit: PriceUnit.perPound,
          price: 1.20,
          recovery: 0.90,
          payability: 0.85,
          deduction: 0.35,
        ),
        Metal(
          symbol: 'Pb',
          name: 'Plomo',
          gradeUnit: GradeUnit.percent,
          priceUnit: PriceUnit.perPound,
          price: 0.90,
          recovery: 0.85,
          payability: 0.95,
          deduction: 0.22,
        ),
        Metal(
          symbol: 'Ag',
          name: 'Plata',
          gradeUnit: GradeUnit.gramsPerTonne,
          priceUnit: PriceUnit.perOunce,
          price: 22.0,
          recovery: 0.75,
          payability: 0.90,
          deduction: 1.5,
        ),
      ],
      costs: const CostStructure(
        mining: 30,
        processing: 18,
        ga: 5,
        sustaining: 5,
      ),
      millCapacity: 1000000,
      mineCapacity: 1150000,
      discountRate: 0.12,
      capex: 55000000,
      royaltyRate: 0.03,
      taxRate: 0.30,
      model: BlockModel(
        nx: nx,
        ny: ny,
        nz: nz,
        blockSize: blockSize,
        blocks: blocks,
      ),
      phases: const [
        MinePhase(
          index: 0,
          name: 'Nivel 1 · Manto superior',
          description: 'Mayor contenido de plata y plomo.',
          requires: [],
        ),
        MinePhase(
          index: 1,
          name: 'Nivel 2',
          description: 'Requiere desarrollo del nivel superior.',
          requires: [0],
        ),
        MinePhase(
          index: 2,
          name: 'Nivel 3',
          description: 'Zona de mayor ley de zinc.',
          requires: [1],
        ),
        MinePhase(
          index: 3,
          name: 'Nivel 4 · Profundo',
          description: 'Menor contenido de plata.',
          requires: [2],
        ),
      ],
      priceRange: const {
        'Zn': [0.70, 2.00],
        'Pb': [0.55, 1.40],
        'Ag': [12.0, 40.0],
      },
    );
  }

  /// Escenarios predefinidos para cada caso.
  static List<NamedScenario> scenariosFor(MineCase c) {
    final base = <String, double>{};
    final rec = <String, double>{};
    for (final m in c.metals) {
      base[m.symbol] = m.price;
      rec[m.symbol] = m.recovery;
    }

    Map<String, double> scale(Map<String, double> src, double f) =>
        src.map((k, v) => MapEntry(k, v * f));

    return [
      NamedScenario(
        id: 'base',
        label: 'Base',
        description: 'Precios de consenso de largo plazo y costos actuales.',
        prices: Map<String, double>.from(base),
        recoveries: Map<String, double>.from(rec),
        costs: c.costs,
      ),
      NamedScenario(
        id: 'pesimista',
        label: 'Pesimista',
        description:
            'Caída de precios del 17 %, costos 12 % arriba y recuperación '
            'tres puntos menor por mineral más duro.',
        prices: scale(base, 0.83),
        recoveries: rec.map((k, v) => MapEntry(k, (v - 0.03).clamp(0.3, 0.99).toDouble())),
        costs: c.costs.copyWith(
          mining: c.costs.mining * 1.12,
          processing: c.costs.processing * 1.12,
          ga: c.costs.ga * 1.10,
        ),
      ),
      NamedScenario(
        id: 'optimista',
        label: 'Optimista',
        description:
            'Ciclo alto de precios (+22 %), costos 8 % abajo y mejora '
            'metalúrgica de dos puntos.',
        prices: scale(base, 1.22),
        recoveries: rec.map((k, v) => MapEntry(k, (v + 0.02).clamp(0.3, 0.99).toDouble())),
        costs: c.costs.copyWith(
          mining: c.costs.mining * 0.92,
          processing: c.costs.processing * 0.92,
          ga: c.costs.ga * 0.95,
        ),
      ),
    ];
  }
}
