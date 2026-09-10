import 'models.dart';

/// Resultado de clasificar el modelo de bloques contra una ley de corte.
class ReserveStats {
  final double oreTonnes;
  final double wasteTonnes;
  final double averageNsr;
  final Map<String, double> averageGrades;
  final Map<String, double> recoveredMetal;
  final int oreBlocks;
  final int wasteBlocks;

  const ReserveStats({
    required this.oreTonnes,
    required this.wasteTonnes,
    required this.averageNsr,
    required this.averageGrades,
    required this.recoveredMetal,
    required this.oreBlocks,
    required this.wasteBlocks,
  });

  double get totalTonnes => oreTonnes + wasteTonnes;

  /// Relación de descapote (t desmonte / t mineral).
  double get stripRatio => oreTonnes <= 0 ? 0 : wasteTonnes / oreTonnes;

  double get oreFraction => totalTonnes <= 0 ? 0 : oreTonnes / totalTonnes;
}

/// Punto de la curva ley-tonelaje.
class GradeTonnagePoint {
  final double cutoffNsr;
  final double oreTonnes;
  final double averageNsr;

  const GradeTonnagePoint(this.cutoffNsr, this.oreTonnes, this.averageNsr);
}

/// Los tres criterios de ley de corte que la aplicación enseña.
class CutoffSet {
  /// Cubre el costo total (minado + procesamiento + G&A).
  /// Responde: ¿el yacimiento en su conjunto es económico?
  final double breakeven;

  /// Cubre solo los costos incrementales (procesamiento + G&A).
  /// Responde: dado que el bloque YA se va a minar, ¿lo mando a planta?
  final double marginal;

  /// Ley de corte de Lane con costo de oportunidad, limitada por planta.
  /// Responde: ¿conviene procesar este material AHORA o dejar la capacidad
  /// de planta libre para material mejor?
  final double lane;

  const CutoffSet({
    required this.breakeven,
    required this.marginal,
    required this.lane,
  });
}

class CutoffCalculator {
  /// Valor NSR de un bloque en $/t.
  static double blockNsr(Block block, List<Metal> metals) {
    double v = 0;
    for (final m in metals) {
      v += block.grade(m.symbol) * m.valuePerUnitGrade;
    }
    return v;
  }

  /// Convierte una ley de corte expresada en NSR ($/t) a ley de corte
  /// expresada en unidades del metal principal.
  ///
  /// Fórmula despejada (caso monometálico):
  ///
  ///   ley de corte = Costo ($/t) / (factor · Precio neto · Recuperación)
  ///
  /// La recuperación DIVIDE. Si la planta recupera menos, hace falta MÁS ley
  /// para pagar el mismo costo, así que la ley de corte SUBE.
  static double nsrToGrade(double nsr, Metal metal) {
    final v = metal.valuePerUnitGrade;
    if (v <= 0) return double.infinity;
    return nsr / v;
  }

  static double gradeToNsr(double grade, Metal metal) =>
      grade * metal.valuePerUnitGrade;

  /// Ley de corte breakeven y marginal en NSR ($/t).
  ///
  /// [remainingNpv] y [millCapacity] alimentan el término de costo de
  /// oportunidad de Lane. Si [remainingNpv] es 0 la ley de Lane colapsa
  /// a la marginal más los costos de tiempo, que es exactamente lo que
  /// ocurre al final de la vida de la mina.
  static CutoffSet compute({
    required CostStructure costs,
    required double discountRate,
    required double millCapacity,
    required double remainingNpv,
    required double fixedCostPerYear,
  }) {
    final breakeven = costs.total;
    final marginal = costs.incremental;
    final opportunity = millCapacity <= 0
        ? 0.0
        : (fixedCostPerYear + discountRate * remainingNpv) / millCapacity;
    return CutoffSet(
      breakeven: breakeven,
      marginal: marginal,
      lane: marginal + opportunity,
    );
  }

  /// Clasifica todo el modelo contra una ley de corte NSR.
  ///
  /// En tajo abierto todo el material se mina, así que el desmonte suma
  /// tonelaje movido. En subterránea el material bajo ley simplemente no se
  /// extrae (minado selectivo), por lo que no genera costo de minado.
  static ReserveStats classify({
    required BlockModel model,
    required List<Metal> metals,
    required double cutoffNsr,
    List<int>? phaseFilter,
  }) {
    double ore = 0;
    double waste = 0;
    double nsrTonnes = 0;
    int oreBlocks = 0;
    int wasteBlocks = 0;
    final gradeTonnes = <String, double>{};
    for (final m in metals) {
      gradeTonnes[m.symbol] = 0;
    }

    for (final b in model.blocks) {
      if (phaseFilter != null && !phaseFilter.contains(b.phaseIndex)) continue;
      final nsr = blockNsr(b, metals);
      if (nsr >= cutoffNsr && cutoffNsr >= 0) {
        ore += b.tonnage;
        oreBlocks++;
        nsrTonnes += nsr * b.tonnage;
        for (final m in metals) {
          gradeTonnes[m.symbol] =
              gradeTonnes[m.symbol]! + b.grade(m.symbol) * b.tonnage;
        }
      } else {
        waste += b.tonnage;
        wasteBlocks++;
      }
    }

    final avgGrades = <String, double>{};
    final recovered = <String, double>{};
    for (final m in metals) {
      final g = ore <= 0 ? 0.0 : gradeTonnes[m.symbol]! / ore;
      avgGrades[m.symbol] = g;
      recovered[m.symbol] = m.containedPerTonne(g) * ore * m.recovery;
    }

    return ReserveStats(
      oreTonnes: ore,
      wasteTonnes: waste,
      averageNsr: ore <= 0 ? 0 : nsrTonnes / ore,
      averageGrades: avgGrades,
      recoveredMetal: recovered,
      oreBlocks: oreBlocks,
      wasteBlocks: wasteBlocks,
    );
  }

  /// Curva ley-tonelaje: cómo cae el tonelaje y sube la ley media al
  /// endurecer la ley de corte. Es el gráfico que hace visible el trade-off.
  static List<GradeTonnagePoint> gradeTonnageCurve({
    required BlockModel model,
    required List<Metal> metals,
    required double maxNsr,
    int steps = 40,
  }) {
    final points = <GradeTonnagePoint>[];
    for (int s = 0; s <= steps; s++) {
      final cut = maxNsr * s / steps;
      final stats = classify(model: model, metals: metals, cutoffNsr: cut);
      points.add(GradeTonnagePoint(cut, stats.oreTonnes, stats.averageNsr));
    }
    return points;
  }
}
