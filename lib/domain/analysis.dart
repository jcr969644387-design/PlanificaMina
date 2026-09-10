import 'dart:math' as math;

import 'models.dart';
import 'scheduler.dart';

/// Una barra del tornado chart.
class SensitivityBar {
  final String variable;
  final double lowNpv;
  final double highNpv;
  final double baseNpv;
  final String lowLabel;
  final String highLabel;

  const SensitivityBar({
    required this.variable,
    required this.lowNpv,
    required this.highNpv,
    required this.baseNpv,
    required this.lowLabel,
    required this.highLabel,
  });

  /// Amplitud del impacto: es lo que ordena el tornado.
  double get swing => (highNpv - lowNpv).abs();
}

class SensitivityAnalysis {
  /// Variación relativa aplicada a cada variable (±20 % por defecto).
  static List<SensitivityBar> tornado({
    required MineCase mineCase,
    required ScenarioParams base,
    double delta = 0.20,
  }) {
    final baseNpv = Scheduler.build(mineCase: mineCase, params: base).npv;
    final bars = <SensitivityBar>[];

    double npvFor(ScenarioParams p) =>
        Scheduler.build(mineCase: mineCase, params: p).npv;

    // Precio del metal principal.
    final primary = mineCase.primaryMetal.symbol;
    final p0 = base.prices[primary] ?? mineCase.primaryMetal.price;
    bars.add(SensitivityBar(
      variable: 'Precio $primary',
      baseNpv: baseNpv,
      lowNpv: npvFor(base.copyWith(
          prices: {...base.prices, primary: p0 * (1 - delta)})),
      highNpv: npvFor(base.copyWith(
          prices: {...base.prices, primary: p0 * (1 + delta)})),
      lowLabel: '-${(delta * 100).toStringAsFixed(0)}%',
      highLabel: '+${(delta * 100).toStringAsFixed(0)}%',
    ));

    // Costo de procesamiento.
    bars.add(SensitivityBar(
      variable: 'Costo planta',
      baseNpv: baseNpv,
      lowNpv: npvFor(base.copyWith(
          costs: base.costs
              .copyWith(processing: base.costs.processing * (1 - delta)))),
      highNpv: npvFor(base.copyWith(
          costs: base.costs
              .copyWith(processing: base.costs.processing * (1 + delta)))),
      lowLabel: '-${(delta * 100).toStringAsFixed(0)}%',
      highLabel: '+${(delta * 100).toStringAsFixed(0)}%',
    ));

    // Costo de minado.
    bars.add(SensitivityBar(
      variable: 'Costo mina',
      baseNpv: baseNpv,
      lowNpv: npvFor(base.copyWith(
          costs:
              base.costs.copyWith(mining: base.costs.mining * (1 - delta)))),
      highNpv: npvFor(base.copyWith(
          costs:
              base.costs.copyWith(mining: base.costs.mining * (1 + delta)))),
      lowLabel: '-${(delta * 100).toStringAsFixed(0)}%',
      highLabel: '+${(delta * 100).toStringAsFixed(0)}%',
    ));

    // Recuperación metalúrgica (acotada a 99 %).
    final r0 = base.recoveries[primary] ?? mineCase.primaryMetal.recovery;
    bars.add(SensitivityBar(
      variable: 'Recuperación',
      baseNpv: baseNpv,
      lowNpv: npvFor(base.copyWith(recoveries: {
        ...base.recoveries,
        primary: math.max(0.30, r0 * (1 - delta))
      })),
      highNpv: npvFor(base.copyWith(recoveries: {
        ...base.recoveries,
        primary: math.min(0.99, r0 * (1 + delta))
      })),
      lowLabel: '-${(delta * 100).toStringAsFixed(0)}%',
      highLabel: '+${(delta * 100).toStringAsFixed(0)}%',
    ));

    // Tasa de descuento (variación absoluta de 2 puntos).
    bars.add(SensitivityBar(
      variable: 'Tasa descuento',
      baseNpv: baseNpv,
      lowNpv: npvFor(base.copyWith(
          discountRate: math.max(0.02, base.discountRate - 0.02))),
      highNpv: npvFor(base.copyWith(discountRate: base.discountRate + 0.02)),
      lowLabel: '-2 pts',
      highLabel: '+2 pts',
    ));

    bars.sort((a, b) => b.swing.compareTo(a.swing));
    return bars;
  }
}

/// Ley de corte de Lane resuelta por iteración de punto fijo.
///
/// El costo de oportunidad depende del VAN remanente, y el VAN remanente
/// depende de la ley de corte. Se itera hasta que ambas se estabilizan.
/// Este es el concepto que explica por qué las minas reales empiezan con
/// leyes de corte altas y las bajan a lo largo de la vida del yacimiento.
class LaneResult {
  final double cutoffNsr;
  final double npv;
  final int iterations;
  final bool converged;
  final double opportunityCost;

  const LaneResult({
    required this.cutoffNsr,
    required this.npv,
    required this.iterations,
    required this.converged,
    required this.opportunityCost,
  });
}

class LaneOptimizer {
  static LaneResult solve({
    required MineCase mineCase,
    required ScenarioParams params,
    int maxIterations = 25,
    double tolerance = 0.01,
  }) {
    // Costos de tiempo: la porción fija de G&A que corre exista o no producción.
    final fixedPerYear = params.costs.ga * params.throughput * 0.6;
    double cutoff = params.costs.incremental;
    double npv = 0;
    int it = 0;
    bool converged = false;
    double opportunity = 0;

    while (it < maxIterations) {
      it++;
      final result = Scheduler.build(
        mineCase: mineCase,
        params: params.copyWith(cutoffNsr: cutoff),
      );
      npv = result.npv;
      opportunity = params.throughput <= 0
          ? 0
          : (fixedPerYear + params.discountRate * math.max(0.0, npv)) /
              params.throughput;
      final next = params.costs.incremental + opportunity;
      // Amortiguación para evitar oscilación.
      final damped = cutoff + 0.5 * (next - cutoff);
      if ((damped - cutoff).abs() < tolerance) {
        cutoff = damped;
        converged = true;
        break;
      }
      cutoff = damped;
    }

    return LaneResult(
      cutoffNsr: cutoff,
      npv: npv,
      iterations: it,
      converged: converged,
      opportunityCost: opportunity,
    );
  }
}

/// Detección de high-grading: agotar la ley alta al inicio.
/// No es ilegal ni siempre incorrecto — maximiza VAN — pero compromete la
/// vida de la mina, el empleo y la relación con la comunidad. La app lo
/// señala para que el estudiante lo argumente, no para castigarlo.
class PlanDiagnostics {
  static double gradeDeclineIndex(ScheduleResult result, String symbol) {
    final profile = result.feedGradeProfile(symbol);
    if (profile.length < 3) return 0;
    final firstThird = profile.take(math.max(1, profile.length ~/ 3));
    final lastThird =
        profile.skip(profile.length - math.max(1, profile.length ~/ 3));
    final a = firstThird.reduce((x, y) => x + y) / firstThird.length;
    final b = lastThird.reduce((x, y) => x + y) / lastThird.length;
    if (a <= 0) return 0;
    return (a - b) / a;
  }
}
