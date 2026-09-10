import 'dart:math' as math;

import 'cutoff.dart';
import 'models.dart';

enum IssueSeverity { error, warning, info }

class ScheduleIssue {
  final IssueSeverity severity;
  final String title;
  final String detail;

  const ScheduleIssue(this.severity, this.title, this.detail);
}

/// Resultado de un periodo (año) del plan de producción.
class PeriodResult {
  final int year;
  final double oreTonnes;
  final double wasteTonnes;
  final Map<String, double> feedGrades;
  final Map<String, double> recoveredMetal;
  final double revenue;
  final double miningCost;
  final double processingCost;
  final double gaCost;
  final double sustainingCost;
  final double royalty;
  final double tax;
  final double freeCashFlow;
  final List<int> activePhases;

  const PeriodResult({
    required this.year,
    required this.oreTonnes,
    required this.wasteTonnes,
    required this.feedGrades,
    required this.recoveredMetal,
    required this.revenue,
    required this.miningCost,
    required this.processingCost,
    required this.gaCost,
    required this.sustainingCost,
    required this.royalty,
    required this.tax,
    required this.freeCashFlow,
    required this.activePhases,
  });

  double get totalMoved => oreTonnes + wasteTonnes;

  double get operatingCost =>
      miningCost + processingCost + gaCost;

  double get ebitda => revenue - operatingCost;

  /// Costo operativo unitario por tonelada tratada.
  double get unitCost => oreTonnes <= 0 ? 0 : operatingCost / oreTonnes;
}

/// Plan completo con sus indicadores.
class ScheduleResult {
  final List<PeriodResult> periods;
  final List<ScheduleIssue> issues;
  final ReserveStats reserves;
  final double npv;
  final double? irr;
  final double? paybackYears;
  final double aisc;
  final double capex;
  final Map<String, double> totalRecovered;

  const ScheduleResult({
    required this.periods,
    required this.issues,
    required this.reserves,
    required this.npv,
    required this.irr,
    required this.paybackYears,
    required this.aisc,
    required this.capex,
    required this.totalRecovered,
  });

  int get lifeYears => periods.length;

  bool get hasErrors =>
      issues.any((i) => i.severity == IssueSeverity.error);

  double get totalOre =>
      periods.fold<double>(0, (s, p) => s + p.oreTonnes);

  double get totalWaste =>
      periods.fold<double>(0, (s, p) => s + p.wasteTonnes);

  /// Perfil de ley de alimentación, útil para detectar high-grading.
  List<double> feedGradeProfile(String symbol) =>
      periods.map((p) => p.feedGrades[symbol] ?? 0).toList();
}

class Economics {
  /// VAN con flujos a fin de periodo y CAPEX en el año 0.
  static double npv({
    required double rate,
    required double capex,
    required List<double> flows,
  }) {
    double v = -capex;
    for (int i = 0; i < flows.length; i++) {
      v += flows[i] / math.pow(1 + rate, i + 1);
    }
    return v;
  }

  /// TIR por bisección. Devuelve null si no hay cambio de signo en el rango,
  /// lo que ocurre cuando el proyecto nunca recupera la inversión.
  static double? irr({
    required double capex,
    required List<double> flows,
    double low = -0.95,
    double high = 5.0,
  }) {
    double f(double r) => npv(rate: r, capex: capex, flows: flows);
    double fl = f(low);
    double fh = f(high);
    if (fl.isNaN || fh.isNaN) return null;
    if (fl * fh > 0) return null;
    double lo = low;
    double hi = high;
    for (int n = 0; n < 200; n++) {
      final mid = (lo + hi) / 2;
      final fm = f(mid);
      if (fm.abs() < 1e-6) return mid;
      if (fl * fm <= 0) {
        hi = mid;
        fh = fm;
      } else {
        lo = mid;
        fl = fm;
      }
    }
    return (lo + hi) / 2;
  }

  /// Periodo de recuperación descontado, interpolado dentro del año.
  static double? payback({
    required double rate,
    required double capex,
    required List<double> flows,
  }) {
    double acc = -capex;
    for (int i = 0; i < flows.length; i++) {
      final disc = flows[i] / math.pow(1 + rate, i + 1);
      if (acc + disc >= 0) {
        final fraction = disc == 0 ? 0.0 : (-acc) / disc;
        return i + fraction;
      }
      acc += disc;
    }
    return null;
  }
}

class Scheduler {
  /// Construye el plan de producción a partir de las decisiones del estudiante.
  ///
  /// La lógica es deliberadamente transparente: se recorren las fases en el
  /// orden elegido, se alimenta la planta hasta su capacidad cada año y se
  /// arrastra el material restante al año siguiente. No hay optimizador — el
  /// estudiante decide y el sistema muestra la consecuencia.
  static ScheduleResult build({
    required MineCase mineCase,
    required ScenarioParams params,
    int maxYears = 30,
  }) {
    final metals = params.resolveMetals(mineCase.metals);
    final issues = <ScheduleIssue>[];

    // --- Validación de precedencia -------------------------------------
    final order = params.phaseOrder;
    final seen = <int>{};
    for (final idx in order) {
      final phase = mineCase.phases.firstWhere((p) => p.index == idx);
      for (final req in phase.requires) {
        if (!seen.contains(req)) {
          final reqName =
              mineCase.phases.firstWhere((p) => p.index == req).name;
          issues.add(ScheduleIssue(
            IssueSeverity.error,
            'Precedencia violada: ${phase.name}',
            'No se puede acceder a ${phase.name} sin haber completado antes '
                '$reqName. En una mina real ese material no tiene acceso físico.',
          ));
        }
      }
      seen.add(idx);
    }

    // --- Validación de capacidad ---------------------------------------
    if (params.throughput > mineCase.millCapacity * 1.0001) {
      issues.add(ScheduleIssue(
        IssueSeverity.error,
        'Capacidad de planta excedida',
        'Programaste ${(params.throughput / 1e6).toStringAsFixed(2)} Mt/año '
            'contra una capacidad instalada de '
            '${(mineCase.millCapacity / 1e6).toStringAsFixed(2)} Mt/año.',
      ));
    }

    // --- Clasificación de bloques por fase ------------------------------
    final oreByPhase = <int, List<Block>>{};
    final wasteByPhase = <int, double>{};
    for (final b in mineCase.model.blocks) {
      final nsr = CutoffCalculator.blockNsr(b, metals);
      if (nsr >= params.cutoffNsr) {
        oreByPhase.putIfAbsent(b.phaseIndex, () => <Block>[]).add(b);
      } else {
        wasteByPhase[b.phaseIndex] =
            (wasteByPhase[b.phaseIndex] ?? 0) + b.tonnage;
      }
    }

    final reserves = CutoffCalculator.classify(
      model: mineCase.model,
      metals: metals,
      cutoffNsr: params.cutoffNsr,
    );

    if (reserves.oreTonnes <= 0) {
      issues.add(const ScheduleIssue(
        IssueSeverity.error,
        'No hay reservas sobre la ley de corte',
        'Con esta combinación de precio, costos y ley de corte no queda un '
            'solo bloque económico. El proyecto no existe en este escenario.',
      ));
    }

    // --- Recorrido de fases ---------------------------------------------
    final periods = <PeriodResult>[];
    final queue = <int>[...order];
    final pending = <int, List<Block>>{};
    for (final idx in queue) {
      pending[idx] = List<Block>.from(oreByPhase[idx] ?? const <Block>[]);
      // Dentro de una fase, el material se toma en orden descendente de valor:
      // es el supuesto de minado selectivo dentro del pushback.
      pending[idx]!.sort((a, b) => CutoffCalculator.blockNsr(b, metals)
          .compareTo(CutoffCalculator.blockNsr(a, metals)));
    }
    final wasteRemaining = <int, double>{};
    for (final idx in queue) {
      wasteRemaining[idx] = wasteByPhase[idx] ?? 0;
    }

    int year = 1;
    int cursor = 0;
    while (cursor < queue.length && year <= maxYears) {
      double oreYear = 0;
      double wasteYear = 0;
      final gradeTonnes = <String, double>{};
      for (final m in metals) {
        gradeTonnes[m.symbol] = 0;
      }
      final active = <int>[];

      while (oreYear < params.throughput - 1 && cursor < queue.length) {
        final idx = queue[cursor];
        final list = pending[idx]!;
        if (list.isEmpty) {
          // Al cerrar la fase se mueve el desmonte que quedó asociado.
          wasteYear += wasteRemaining[idx] ?? 0;
          wasteRemaining[idx] = 0;
          cursor++;
          continue;
        }
        if (!active.contains(idx)) active.add(idx);
        final b = list.first;
        final room = params.throughput - oreYear;
        final take = math.min(b.tonnage, room);
        oreYear += take;
        for (final m in metals) {
          gradeTonnes[m.symbol] =
              gradeTonnes[m.symbol]! + b.grade(m.symbol) * take;
        }
        // Desmonte proporcional al avance de la fase.
        final phaseOre = (oreByPhase[idx] ?? const <Block>[])
            .fold<double>(0, (s, x) => s + x.tonnage);
        if (phaseOre > 0) {
          final share = take / phaseOre;
          final w = (wasteByPhase[idx] ?? 0) * share;
          wasteYear += w;
          wasteRemaining[idx] = math.max(0.0, (wasteRemaining[idx] ?? 0) - w);
        }
        if (take >= b.tonnage - 1e-9) {
          list.removeAt(0);
        } else {
          pending[idx]![0] = Block(
            i: b.i,
            j: b.j,
            k: b.k,
            tonnage: b.tonnage - take,
            grades: b.grades,
            phaseIndex: b.phaseIndex,
          );
        }
      }

      if (oreYear <= 0) break;

      final feed = <String, double>{};
      final recovered = <String, double>{};
      double revenue = 0;
      for (final m in metals) {
        final g = gradeTonnes[m.symbol]! / oreYear;
        feed[m.symbol] = g;
        final rec = m.containedPerTonne(g) * oreYear * m.recovery;
        recovered[m.symbol] = rec;
        revenue += g * m.valuePerUnitGrade * oreYear;
      }

      // En subterránea el desmonte bajo ley no se extrae (minado selectivo).
      final movedForMining = mineCase.method == MiningMethod.openPit
          ? oreYear + wasteYear
          : oreYear;

      final miningCost = movedForMining * params.costs.mining;
      final processingCost = oreYear * params.costs.processing;
      final gaCost = oreYear * params.costs.ga;
      final sustaining = oreYear * params.costs.sustaining;
      final royalty = revenue * mineCase.royaltyRate;
      final ebit =
          revenue - miningCost - processingCost - gaCost - royalty;
      final tax = ebit > 0 ? ebit * mineCase.taxRate : 0.0;
      final fcf = ebit - tax - sustaining;

      periods.add(PeriodResult(
        year: year,
        oreTonnes: oreYear,
        wasteTonnes: wasteYear,
        feedGrades: feed,
        recoveredMetal: recovered,
        revenue: revenue,
        miningCost: miningCost,
        processingCost: processingCost,
        gaCost: gaCost,
        sustainingCost: sustaining,
        royalty: royalty,
        tax: tax,
        freeCashFlow: fcf,
        activePhases: active,
      ));

      // Chequeo de capacidad de mina (movimiento total).
      if (movedForMining > mineCase.mineCapacity * 1.0001) {
        issues.add(ScheduleIssue(
          IssueSeverity.warning,
          'Año $year: capacidad de mina superada',
          'Se requieren ${(movedForMining / 1e6).toStringAsFixed(2)} Mt de '
              'movimiento contra una flota dimensionada para '
              '${(mineCase.mineCapacity / 1e6).toStringAsFixed(2)} Mt/año. '
              'Necesitarías más equipos o diferir material.',
        ));
      }

      year++;
    }

    if (year > maxYears) {
      issues.add(ScheduleIssue(
        IssueSeverity.warning,
        'Vida de mina truncada',
        'El plan supera $maxYears años y se truncó. Considera aumentar la '
            'alimentación de planta o subir la ley de corte.',
      ));
    }

    final flows = periods.map((p) => p.freeCashFlow).toList();
    final npv = Economics.npv(
      rate: params.discountRate,
      capex: mineCase.capex,
      flows: flows,
    );
    final irr = Economics.irr(capex: mineCase.capex, flows: flows);
    final payback = Economics.payback(
      rate: params.discountRate,
      capex: mineCase.capex,
      flows: flows,
    );

    final totalRecovered = <String, double>{};
    for (final m in metals) {
      totalRecovered[m.symbol] = periods.fold<double>(
          0, (s, p) => s + (p.recoveredMetal[m.symbol] ?? 0));
    }

    // AISC referido al metal principal.
    final primary = metals.first;
    final totalCost = periods.fold<double>(
        0,
        (s, p) =>
            s + p.operatingCost + p.sustainingCost + p.royalty);
    final primaryUnits = totalRecovered[primary.symbol] ?? 0;
    final aisc = primaryUnits <= 0 ? 0.0 : totalCost / primaryUnits;

    return ScheduleResult(
      periods: periods,
      issues: issues,
      reserves: reserves,
      npv: npv,
      irr: irr,
      paybackYears: payback,
      aisc: aisc,
      capex: mineCase.capex,
      totalRecovered: totalRecovered,
    );
  }
}
