import 'dart:math' as math;

/// Constantes metalúrgicas.
/// 1 tonelada métrica = 2204.62 lb  ->  1 % de ley = 22.0462 lb de metal por tonelada.
const double kLbPerTonnePerPercent = 22.0462;

/// 1 onza troy = 31.1035 gramos.
const double kGramsPerTroyOunce = 31.1035;

enum GradeUnit { percent, gramsPerTonne }

enum PriceUnit { perPound, perOunce }

enum MiningMethod { openPit, underground }

/// Un metal pagable dentro del yacimiento, con su economía asociada.
///
/// El valor de un bloque se calcula como NSR (Net Smelter Return): el ingreso
/// que efectivamente llega a la mina después de recuperación metalúrgica,
/// pagabilidad del concentrado y cargos de tratamiento/refinación.
class Metal {
  final String symbol;
  final String name;
  final GradeUnit gradeUnit;
  final PriceUnit priceUnit;

  /// Precio de referencia ($/lb o $/oz).
  final double price;

  /// Recuperación metalúrgica (0-1).
  final double recovery;

  /// Fracción del metal que la fundición paga (0-1).
  final double payability;

  /// Cargos de tratamiento y refinación expresados en $/lb o $/oz.
  final double deduction;

  const Metal({
    required this.symbol,
    required this.name,
    required this.gradeUnit,
    required this.priceUnit,
    required this.price,
    required this.recovery,
    required this.payability,
    required this.deduction,
  });

  Metal copyWith({double? price, double? recovery}) => Metal(
        symbol: symbol,
        name: name,
        gradeUnit: gradeUnit,
        priceUnit: priceUnit,
        price: price ?? this.price,
        recovery: recovery ?? this.recovery,
        payability: payability,
        deduction: deduction,
      );

  /// Valor en $/t por cada unidad de ley (1 % o 1 g/t).
  ///
  /// ATENCIÓN PEDAGÓGICA: la recuperación MULTIPLICA aquí porque este término
  /// es un ingreso. Cuando se despeja la ley de corte, la recuperación pasa
  /// dividiendo. Ver [CutoffCalculator].
  double get valuePerUnitGrade {
    final netPrice = price * payability - deduction;
    if (netPrice <= 0) return 0;
    switch (priceUnit) {
      case PriceUnit.perPound:
        return netPrice * kLbPerTonnePerPercent * recovery;
      case PriceUnit.perOunce:
        return (netPrice / kGramsPerTroyOunce) * recovery;
    }
  }

  String get gradeSuffix => gradeUnit == GradeUnit.percent ? '%' : 'g/t';

  String get priceSuffix => priceUnit == PriceUnit.perPound ? r'$/lb' : r'$/oz';

  /// Metal contenido en una tonelada de mineral, en lb u oz.
  double containedPerTonne(double grade) {
    switch (priceUnit) {
      case PriceUnit.perPound:
        return grade * kLbPerTonnePerPercent;
      case PriceUnit.perOunce:
        return grade / kGramsPerTroyOunce;
    }
  }

  String get containedUnit => priceUnit == PriceUnit.perPound ? 'lb' : 'oz';
}

/// Estructura de costos operativos, en $/t.
class CostStructure {
  /// Costo de minado por tonelada movida (mineral + desmonte).
  final double mining;

  /// Costo de procesamiento por tonelada tratada en planta.
  final double processing;

  /// Gastos generales y administrativos por tonelada tratada.
  final double ga;

  /// Capital de sostenimiento por tonelada tratada (entra en el AISC).
  final double sustaining;

  const CostStructure({
    required this.mining,
    required this.processing,
    required this.ga,
    this.sustaining = 0,
  });

  double get total => mining + processing + ga;

  /// Costos que se incurren SOLO si el material va a planta.
  /// Es la base de la ley de corte marginal.
  double get incremental => processing + ga;

  CostStructure copyWith({
    double? mining,
    double? processing,
    double? ga,
    double? sustaining,
  }) =>
      CostStructure(
        mining: mining ?? this.mining,
        processing: processing ?? this.processing,
        ga: ga ?? this.ga,
        sustaining: sustaining ?? this.sustaining,
      );
}

/// Un bloque del modelo geológico.
class Block {
  final int i;
  final int j;
  final int k;

  /// Tonelaje del bloque (t).
  final double tonnage;

  /// Leyes por símbolo de metal.
  final Map<String, double> grades;

  /// Índice de la fase / nivel al que pertenece.
  final int phaseIndex;

  const Block({
    required this.i,
    required this.j,
    required this.k,
    required this.tonnage,
    required this.grades,
    required this.phaseIndex,
  });

  double grade(String symbol) => grades[symbol] ?? 0;
}

/// Modelo de bloques regular.
class BlockModel {
  final int nx;
  final int ny;
  final int nz;
  final double blockSize;
  final List<Block> blocks;

  const BlockModel({
    required this.nx,
    required this.ny,
    required this.nz,
    required this.blockSize,
    required this.blocks,
  });

  int get count => blocks.length;

  double get totalTonnage =>
      blocks.fold<double>(0, (sum, b) => sum + b.tonnage);

  /// Devuelve la sección vertical en el índice [jIndex] del eje Y.
  /// El resultado es una matriz [nz][nx]; null donde no hay bloque.
  List<List<Block?>> sectionY(int jIndex) {
    final grid = List<List<Block?>>.generate(
      nz,
      (_) => List<Block?>.filled(nx, null),
    );
    for (final b in blocks) {
      if (b.j == jIndex) grid[b.k][b.i] = b;
    }
    return grid;
  }

  /// Devuelve el plano horizontal (banco / nivel) en el índice [kIndex].
  List<List<Block?>> levelZ(int kIndex) {
    final grid = List<List<Block?>>.generate(
      ny,
      (_) => List<Block?>.filled(nx, null),
    );
    for (final b in blocks) {
      if (b.k == kIndex) grid[b.j][b.i] = b;
    }
    return grid;
  }

  double gradeMin(String symbol) => blocks
      .map((b) => b.grade(symbol))
      .fold<double>(double.infinity, math.min);

  double gradeMax(String symbol) =>
      blocks.map((b) => b.grade(symbol)).fold<double>(0, math.max);
}

/// Una fase de explotación: pushback en tajo abierto, nivel en subterránea.
/// El estudiante decide en qué orden se extraen.
class MinePhase {
  final int index;
  final String name;
  final String description;

  /// Fases que deben haberse completado antes de iniciar esta.
  final List<int> requires;

  const MinePhase({
    required this.index,
    required this.name,
    required this.description,
    required this.requires,
  });
}

/// Caso de estudio completo.
class MineCase {
  final String id;
  final String name;
  final String subtitle;
  final String geologyNote;
  final String learningFocus;
  final MiningMethod method;
  final List<Metal> metals;
  final CostStructure costs;

  /// Capacidad de planta (t/año).
  final double millCapacity;

  /// Capacidad de movimiento total de mina (t/año, mineral + desmonte).
  final double mineCapacity;

  final double discountRate;
  final double capex;

  /// Regalía sobre el ingreso neto (0-1).
  final double royaltyRate;

  /// Impuesto sobre la utilidad (0-1).
  final double taxRate;

  final BlockModel model;
  final List<MinePhase> phases;

  /// Rangos permitidos para los sliders de escenario.
  final Map<String, List<double>> priceRange;

  const MineCase({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.geologyNote,
    required this.learningFocus,
    required this.method,
    required this.metals,
    required this.costs,
    required this.millCapacity,
    required this.mineCapacity,
    required this.discountRate,
    required this.capex,
    required this.royaltyRate,
    required this.taxRate,
    required this.model,
    required this.phases,
    required this.priceRange,
  });

  bool get isPolymetallic => metals.length > 1;

  Metal get primaryMetal => metals.first;
}

/// Parámetros que el estudiante manipula. Es el "escenario" vivo.
class ScenarioParams {
  final Map<String, double> prices;
  final Map<String, double> recoveries;
  final CostStructure costs;
  final double discountRate;

  /// Ley de corte expresada en NSR ($/t). Funciona para mono y polimetálico.
  final double cutoffNsr;

  /// Orden en que el estudiante decide extraer las fases.
  final List<int> phaseOrder;

  /// Alimentación anual a planta elegida por el estudiante (t/año).
  final double throughput;

  const ScenarioParams({
    required this.prices,
    required this.recoveries,
    required this.costs,
    required this.discountRate,
    required this.cutoffNsr,
    required this.phaseOrder,
    required this.throughput,
  });

  ScenarioParams copyWith({
    Map<String, double>? prices,
    Map<String, double>? recoveries,
    CostStructure? costs,
    double? discountRate,
    double? cutoffNsr,
    List<int>? phaseOrder,
    double? throughput,
  }) =>
      ScenarioParams(
        prices: prices ?? this.prices,
        recoveries: recoveries ?? this.recoveries,
        costs: costs ?? this.costs,
        discountRate: discountRate ?? this.discountRate,
        cutoffNsr: cutoffNsr ?? this.cutoffNsr,
        phaseOrder: phaseOrder ?? this.phaseOrder,
        throughput: throughput ?? this.throughput,
      );

  /// Aplica los precios y recuperaciones del escenario a la lista de metales.
  List<Metal> resolveMetals(List<Metal> base) => base
      .map((m) => m.copyWith(
            price: prices[m.symbol] ?? m.price,
            recovery: recoveries[m.symbol] ?? m.recovery,
          ))
      .toList();
}

/// Escenario predefinido (base / pesimista / optimista).
class NamedScenario {
  final String id;
  final String label;
  final String description;
  final Map<String, double> prices;
  final Map<String, double> recoveries;
  final CostStructure costs;

  const NamedScenario({
    required this.id,
    required this.label,
    required this.description,
    required this.prices,
    required this.recoveries,
    required this.costs,
  });
}
