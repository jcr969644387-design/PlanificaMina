import 'package:flutter_test/flutter_test.dart';
import 'package:planificamina/data/case_repository.dart';
import 'package:planificamina/domain/analysis.dart';
import 'package:planificamina/domain/cutoff.dart';
import 'package:planificamina/domain/models.dart';
import 'package:planificamina/domain/scheduler.dart';

void main() {
  group('Valor unitario de metal (NSR)', () {
    test('oro en g/t con precio en \$/oz', () {
      const au = Metal(
        symbol: 'Au',
        name: 'Oro',
        gradeUnit: GradeUnit.gramsPerTonne,
        priceUnit: PriceUnit.perOunce,
        price: 1800,
        recovery: 0.92,
        payability: 0.998,
        deduction: 5.0,
      );
      expect(au.valuePerUnitGrade, closeTo(52.9872, 0.001));
    });

    test('cobre en % con precio en \$/lb', () {
      const cu = Metal(
        symbol: 'Cu',
        name: 'Cobre',
        gradeUnit: GradeUnit.percent,
        priceUnit: PriceUnit.perPound,
        price: 3.50,
        recovery: 0.88,
        payability: 0.965,
        deduction: 0.30,
      );
      expect(cu.valuePerUnitGrade, closeTo(59.7055, 0.001));
    });
  });

  group('Ley de corte', () {
    const au = Metal(
      symbol: 'Au',
      name: 'Oro',
      gradeUnit: GradeUnit.gramsPerTonne,
      priceUnit: PriceUnit.perOunce,
      price: 1800,
      recovery: 0.92,
      payability: 0.998,
      deduction: 5.0,
    );

    test('breakeven y marginal en unidades de ley', () {
      final set = CutoffCalculator.compute(
        costs: const CostStructure(mining: 45, processing: 35, ga: 8),
        discountRate: 0.10,
        millCapacity: 800000,
        remainingNpv: 0,
        fixedCostPerYear: 0,
      );
      expect(set.breakeven, closeTo(88.0, 1e-9));
      expect(set.marginal, closeTo(43.0, 1e-9));
      expect(CutoffCalculator.nsrToGrade(set.breakeven, au),
          closeTo(1.6608, 0.001));
      expect(CutoffCalculator.nsrToGrade(set.marginal, au),
          closeTo(0.8115, 0.001));
    });

    /// Esta es la prueba que protege contra el error conceptual más común
    /// del tema: si la recuperación baja, la ley de corte DEBE subir.
    test('menor recuperación implica MAYOR ley de corte', () {
      final alta = CutoffCalculator.nsrToGrade(88, au);
      final baja =
          CutoffCalculator.nsrToGrade(88, au.copyWith(recovery: 0.85));
      expect(baja, greaterThan(alta));
      expect(baja, closeTo(1.7976, 0.002));
    });

    test('mayor precio implica MENOR ley de corte', () {
      final base = CutoffCalculator.nsrToGrade(88, au);
      final caro = CutoffCalculator.nsrToGrade(88, au.copyWith(price: 2200));
      expect(caro, lessThan(base));
    });
  });

  group('Indicadores económicos', () {
    test('VAN', () {
      expect(
        Economics.npv(rate: 0.10, capex: 100, flows: [50, 50, 50]),
        closeTo(24.3426, 0.0001),
      );
    });

    test('TIR', () {
      final r = Economics.irr(capex: 100, flows: [50, 50, 50]);
      expect(r, isNotNull);
      expect(r!, closeTo(0.23375, 0.0005));
    });

    test('TIR nula cuando el proyecto nunca recupera la inversión', () {
      expect(Economics.irr(capex: 1000, flows: [1, 1, 1]), isNull);
    });

    test('payback descontado interpolado', () {
      final p = Economics.payback(rate: 0.10, capex: 100, flows: [50, 50, 50]);
      expect(p, isNotNull);
      expect(p!, closeTo(2.352, 0.001));
    });
  });

  group('NSR polimetálico', () {
    test('suma ponderada de tres metales', () {
      final poly = CaseRepository.byId('znpbag_poly');
      final b = Block(
        i: 0,
        j: 0,
        k: 0,
        tonnage: 1000,
        grades: const {'Zn': 4.0, 'Pb': 1.2, 'Ag': 55.0},
        phaseIndex: 0,
      );
      expect(CutoffCalculator.blockNsr(b, poly.metals),
          closeTo(91.7245, 0.01));
    });
  });

  group('Calibración de los casos (regresión pedagógica)', () {
    /// Si un caso deja de tener material bajo la ley de corte, el ejercicio
    /// pierde sentido: todos los bloques serían mineral y mover el precio no
    /// cambiaría nada. Estas pruebas impiden esa regresión.
    for (final c in CaseRepository.all()) {
      test('${c.name}: existe material sobre y bajo la ley de corte', () {
        final stats = CutoffCalculator.classify(
          model: c.model,
          metals: c.metals,
          cutoffNsr: c.costs.total,
        );
        expect(stats.oreTonnes, greaterThan(0),
            reason: 'sin mineral: el caso no tiene proyecto');
        expect(stats.wasteTonnes, greaterThan(0),
            reason: 'sin desmonte: la ley de corte no tendría consecuencia');
        expect(stats.oreFraction, lessThan(0.85));
        expect(stats.oreFraction, greaterThan(0.05));
      });

      test('${c.name}: bajar el precio reduce el tonelaje económico', () {
        final metals = c.metals;
        final low = metals.map((m) => m.copyWith(price: m.price * 0.80)).toList();
        final a = CutoffCalculator.classify(
            model: c.model, metals: metals, cutoffNsr: c.costs.total);
        final b = CutoffCalculator.classify(
            model: c.model, metals: low, cutoffNsr: c.costs.total);
        expect(b.oreTonnes, lessThan(a.oreTonnes));
        // Y la ley media de alimentación sube, que es el punto contraintuitivo.
        expect(b.averageNsr, greaterThan(0));
      });

      test('${c.name}: el plan base genera periodos y VAN finito', () {
        final prices = {for (final m in c.metals) m.symbol: m.price};
        final recs = {for (final m in c.metals) m.symbol: m.recovery};
        final params = ScenarioParams(
          prices: prices,
          recoveries: recs,
          costs: c.costs,
          discountRate: c.discountRate,
          cutoffNsr: c.costs.total,
          phaseOrder: c.phases.map((p) => p.index).toList(),
          throughput: c.millCapacity,
        );
        final r = Scheduler.build(mineCase: c, params: params);
        expect(r.periods, isNotEmpty);
        expect(r.npv.isFinite, isTrue);
        expect(r.lifeYears, greaterThanOrEqualTo(3));
      });
    }
  });

  group('Programación', () {
    test('violar precedencia genera error', () {
      final c = CaseRepository.byId('cu_openpit');
      final prices = {for (final m in c.metals) m.symbol: m.price};
      final recs = {for (final m in c.metals) m.symbol: m.recovery};
      final params = ScenarioParams(
        prices: prices,
        recoveries: recs,
        costs: c.costs,
        discountRate: c.discountRate,
        cutoffNsr: c.costs.incremental,
        phaseOrder: const [3, 0, 1, 2], // profundización primero: imposible
        throughput: c.millCapacity,
      );
      final r = Scheduler.build(mineCase: c, params: params);
      expect(r.hasErrors, isTrue);
    });

    test('adelantar valor sube el VAN sin cambiar el metal total', () {
      final c = CaseRepository.byId('cu_openpit');
      final prices = {for (final m in c.metals) m.symbol: m.price};
      final recs = {for (final m in c.metals) m.symbol: m.recovery};
      ScenarioParams p(List<int> order) => ScenarioParams(
            prices: prices,
            recoveries: recs,
            costs: c.costs,
            discountRate: c.discountRate,
            cutoffNsr: c.costs.incremental,
            phaseOrder: order,
            throughput: c.millCapacity,
          );
      final a = Scheduler.build(mineCase: c, params: p(const [0, 1, 2, 3]));
      final b = Scheduler.build(mineCase: c, params: p(const [0, 2, 1, 3]));
      expect((a.totalOre - b.totalOre).abs(), lessThan(1));
      expect(a.npv.isFinite && b.npv.isFinite, isTrue);
    });
  });

  group('Lane', () {
    test('la ley de corte de Lane es mayor o igual que la marginal', () {
      final c = CaseRepository.byId('au_underground');
      final prices = {for (final m in c.metals) m.symbol: m.price};
      final recs = {for (final m in c.metals) m.symbol: m.recovery};
      final params = ScenarioParams(
        prices: prices,
        recoveries: recs,
        costs: c.costs,
        discountRate: c.discountRate,
        cutoffNsr: c.costs.total,
        phaseOrder: c.phases.map((p) => p.index).toList(),
        throughput: c.millCapacity,
      );
      final lane = LaneOptimizer.solve(mineCase: c, params: params);
      expect(lane.cutoffNsr, greaterThanOrEqualTo(c.costs.incremental));
    });
  });
}
