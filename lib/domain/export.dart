import 'models.dart';
import 'scheduler.dart';

/// Exportación a CSV con separador de punto y coma, que es el que Excel
/// espera en configuraciones regionales en español. Se entrega por
/// portapapeles: cero dependencias, funciona sin conexión y sin permisos
/// de almacenamiento.
class CsvExporter {
  static String _n(double v, [int d = 2]) =>
      v.toStringAsFixed(d).replaceAll('.', ',');

  static String productionSchedule({
    required MineCase mineCase,
    required ScenarioParams params,
    required ScheduleResult result,
  }) {
    final metals = params.resolveMetals(mineCase.metals);
    final b = StringBuffer();
    b.writeln('PlanificaMina - Programa de produccion');
    b.writeln('Caso;${mineCase.name}');
    b.writeln('Ley de corte (NSR \$/t);${_n(params.cutoffNsr)}');
    b.writeln('Alimentacion planta (t/a);${_n(params.throughput, 0)}');
    b.writeln('Tasa de descuento;${_n(params.discountRate * 100)}%');
    b.writeln('');

    final header =
        StringBuffer('Anio;Mineral (t);Desmonte (t);Total movido (t)');
    for (final m in metals) {
      header.write(';Ley ${m.symbol} (${m.gradeSuffix})');
    }
    for (final m in metals) {
      header.write(';${m.symbol} recuperado (${m.containedUnit})');
    }
    header.write(';Ingreso NSR (US\$);Costo mina (US\$);Costo planta (US\$);'
        'G&A (US\$);Regalia (US\$);Impuesto (US\$);Sostenimiento (US\$);'
        'Flujo de caja libre (US\$);Costo unitario (US\$/t)');
    b.writeln(header.toString());

    for (final p in result.periods) {
      final row = StringBuffer(
          '${p.year};${_n(p.oreTonnes, 0)};${_n(p.wasteTonnes, 0)};'
          '${_n(p.totalMoved, 0)}');
      for (final m in metals) {
        row.write(';${_n(p.feedGrades[m.symbol] ?? 0, 3)}');
      }
      for (final m in metals) {
        row.write(';${_n(p.recoveredMetal[m.symbol] ?? 0, 0)}');
      }
      row.write(';${_n(p.revenue, 0)};${_n(p.miningCost, 0)};'
          '${_n(p.processingCost, 0)};${_n(p.gaCost, 0)};${_n(p.royalty, 0)};'
          '${_n(p.tax, 0)};${_n(p.sustainingCost, 0)};'
          '${_n(p.freeCashFlow, 0)};${_n(p.unitCost)}');
      b.writeln(row.toString());
    }

    b.writeln('');
    b.writeln('INDICADORES');
    b.writeln('CAPEX (US\$);${_n(result.capex, 0)}');
    b.writeln('VAN (US\$);${_n(result.npv, 0)}');
    b.writeln(
        'TIR;${result.irr == null ? "n/a" : "${_n(result.irr! * 100)}%"}');
    b.writeln('Payback descontado (anios);'
        '${result.paybackYears == null ? "n/a" : _n(result.paybackYears!)}');
    b.writeln('AISC (US\$/${metals.first.containedUnit});${_n(result.aisc)}');
    b.writeln('Vida de mina (anios);${result.lifeYears}');
    b.writeln('Mineral total (t);${_n(result.totalOre, 0)}');
    b.writeln('Desmonte total (t);${_n(result.totalWaste, 0)}');
    b.writeln('Relacion de descapote;${_n(result.reserves.stripRatio)}');
    b.writeln('');
    b.writeln(
        'Modelo educativo simplificado. No sustituye software profesional '
        'de planeamiento ni un estudio de factibilidad.');
    return b.toString();
  }

  static String blockModel({
    required MineCase mineCase,
    required ScenarioParams params,
  }) {
    final metals = params.resolveMetals(mineCase.metals);
    final b = StringBuffer();
    final header = StringBuffer('i;j;k;Tonelaje');
    for (final m in metals) {
      header.write(';${m.symbol} (${m.gradeSuffix})');
    }
    header.write(';NSR (US\$/t);Fase;Clasificacion');
    b.writeln(header.toString());

    for (final blk in mineCase.model.blocks) {
      double nsr = 0;
      for (final m in metals) {
        nsr += blk.grade(m.symbol) * m.valuePerUnitGrade;
      }
      final row =
          StringBuffer('${blk.i};${blk.j};${blk.k};${_n(blk.tonnage, 0)}');
      for (final m in metals) {
        row.write(';${_n(blk.grade(m.symbol), 3)}');
      }
      row.write(';${_n(nsr)};${blk.phaseIndex};'
          '${nsr >= params.cutoffNsr ? "Mineral" : "Desmonte"}');
      b.writeln(row.toString());
    }
    return b.toString();
  }
}
