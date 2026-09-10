import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/assessment_repository.dart';
import '../data/case_repository.dart';
import '../domain/analysis.dart';
import '../domain/cutoff.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';
import '../domain/tutor.dart';

/// ViewModel de la sesión de trabajo. Concentra el estado del plan que el
/// estudiante está construyendo y recalcula la consecuencia de cada decisión.
///
/// Todo el cálculo es síncrono y local: es lo que permite que la app funcione
/// sin conexión y que el slider se sienta instantáneo.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(MineCase initial) {
    loadCase(initial);
  }

  late MineCase _case;
  late ScenarioParams _params;
  ScheduleResult? _result;
  CutoffSet? _cutoffs;
  LaneResult? _lane;
  List<TutorFinding> _findings = const [];

  final Set<String> _exploredScenarios = <String>{};
  final Map<String, bool> _reflectionResults = <String, bool>{};
  ReflectionPrompt? _pendingReflection;

  final Map<String, int> preTest = <String, int>{};
  final Map<String, int> postTest = <String, int>{};

  MineCase get mineCase => _case;
  ScenarioParams get params => _params;
  ScheduleResult get result => _result!;
  CutoffSet get cutoffs => _cutoffs!;
  LaneResult? get lane => _lane;
  List<TutorFinding> get findings => _findings;
  ReflectionPrompt? get pendingReflection => _pendingReflection;
  int get scenariosExplored => _exploredScenarios.length;
  Map<String, bool> get reflectionResults => _reflectionResults;

  List<Metal> get activeMetals => _params.resolveMetals(_case.metals);

  void loadCase(MineCase c) {
    _case = c;
    final prices = <String, double>{};
    final recs = <String, double>{};
    for (final m in c.metals) {
      prices[m.symbol] = m.price;
      recs[m.symbol] = m.recovery;
    }
    _params = ScenarioParams(
      prices: prices,
      recoveries: recs,
      costs: c.costs,
      discountRate: c.discountRate,
      // Se arranca en la ley de corte breakeven: es la referencia que el
      // estudiante trae del curso, y desde ahí se le muestra que hay más.
      cutoffNsr: c.costs.total,
      phaseOrder: c.phases.map((p) => p.index).toList(),
      throughput: c.millCapacity,
    );
    _lane = null;
    _exploredScenarios.clear();
    _recompute(trigger: null);
  }

  // ---------------------------------------------------------------
  // Decisiones del estudiante
  // ---------------------------------------------------------------

  void setCutoffNsr(double v) {
    final before = _params.cutoffNsr;
    _params = _params.copyWith(cutoffNsr: v.clamp(0.0, _maxNsr()).toDouble());
    String? trigger;
    if (_cutoffs != null &&
        before >= _cutoffs!.breakeven &&
        v < _cutoffs!.breakeven &&
        v > _cutoffs!.marginal) {
      trigger = 'belowBreakeven';
    }
    _recompute(trigger: trigger);
  }

  void setPrice(String symbol, double price) {
    final before = _params.prices[symbol] ?? 0;
    final next = Map<String, double>.from(_params.prices);
    next[symbol] = price;
    _params = _params.copyWith(prices: next);
    _exploredScenarios.add('price_${symbol}_${price.toStringAsFixed(2)}');
    _recompute(trigger: price < before ? 'priceDrop' : null);
  }

  void setRecovery(String symbol, double recovery) {
    final next = Map<String, double>.from(_params.recoveries);
    next[symbol] = recovery.clamp(0.30, 0.99).toDouble();
    _params = _params.copyWith(recoveries: next);
    _exploredScenarios.add('rec_${symbol}_${recovery.toStringAsFixed(2)}');
    _recompute(trigger: 'recoveryChange');
  }

  void setCosts(CostStructure costs) {
    _params = _params.copyWith(costs: costs);
    _exploredScenarios.add('cost_${costs.total.toStringAsFixed(2)}');
    _recompute(trigger: null);
  }

  void setDiscountRate(double r) {
    _params = _params.copyWith(discountRate: r);
    _recompute(trigger: null);
  }

  void setThroughput(double t) {
    _params = _params.copyWith(throughput: t);
    _recompute(trigger: null);
  }

  void reorderPhases(int oldIndex, int newIndex) {
    final list = List<int>.from(_params.phaseOrder);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _params = _params.copyWith(phaseOrder: list);
    _recompute(trigger: 'sequenceChanged');
  }

  void applyNamedScenario(NamedScenario s) {
    _params = _params.copyWith(
      prices: Map<String, double>.from(s.prices),
      recoveries: Map<String, double>.from(s.recoveries),
      costs: s.costs,
    );
    _exploredScenarios.add('named_${s.id}');
    _recompute(trigger: s.id == 'pesimista' ? 'priceDrop' : null);
  }

  /// Aplica la ley de corte que corresponde a cada criterio.
  void applyCutoffCriterion(String criterion) {
    if (_cutoffs == null) return;
    switch (criterion) {
      case 'breakeven':
        setCutoffNsr(_cutoffs!.breakeven);
        break;
      case 'marginal':
        setCutoffNsr(_cutoffs!.marginal);
        break;
      case 'lane':
        solveLane();
        if (_lane != null) setCutoffNsr(_lane!.cutoffNsr);
        break;
    }
  }

  /// Resuelve la ley de corte de Lane. Es costosa (itera el plan completo),
  /// así que se ejecuta solo bajo demanda.
  void solveLane() {
    _lane = LaneOptimizer.solve(mineCase: _case, params: _params);
    notifyListeners();
  }

  List<SensitivityBar> tornado() =>
      SensitivityAnalysis.tornado(mineCase: _case, base: _params);

  // ---------------------------------------------------------------
  // Reflexiones
  // ---------------------------------------------------------------

  void answerReflection(String id, int optionIndex) {
    final prompt =
        AssessmentRepository.reflections.firstWhere((r) => r.id == id);
    _reflectionResults[id] = optionIndex == prompt.correctIndex;
    _pendingReflection = null;
    notifyListeners();
  }

  void dismissReflection() {
    _pendingReflection = null;
    notifyListeners();
  }

  int get reflectionsCorrect =>
      _reflectionResults.values.where((v) => v).length;

  int get reflectionsAnswered => _reflectionResults.length;

  // ---------------------------------------------------------------
  // Evaluación
  // ---------------------------------------------------------------

  void answerDiagnostic(String id, int option, {required bool isPost}) {
    (isPost ? postTest : preTest)[id] = option;
    notifyListeners();
  }

  int scoreOf(Map<String, int> answers) {
    int correct = 0;
    for (final q in AssessmentRepository.diagnostic) {
      if (answers[q.id] == q.correctIndex) correct++;
    }
    return correct;
  }

  ScoreBreakdown score() {
    final reference = _lane?.npv ?? result.npv;
    return ScoringEngine.score(
      result: result,
      referenceNpv: reference <= 0 ? result.npv.abs() + 1 : reference,
      scenariosExplored: scenariosExplored,
      reflectionsCorrect: reflectionsCorrect,
      reflectionsTotal: AssessmentRepository.reflections.length,
    );
  }

  // ---------------------------------------------------------------
  // Núcleo de recálculo
  // ---------------------------------------------------------------

  double _maxNsr() {
    final metals = activeMetals;
    double maxV = 0;
    for (final b in _case.model.blocks) {
      final v = CutoffCalculator.blockNsr(b, metals);
      if (v > maxV) maxV = v;
    }
    return maxV;
  }

  double maxNsrForSlider() => _maxNsr();

  ReserveStats reservesAt(double cutoffNsr) => CutoffCalculator.classify(
        model: _case.model,
        metals: activeMetals,
        cutoffNsr: cutoffNsr,
      );

  List<GradeTonnagePoint> gradeTonnageCurve() =>
      CutoffCalculator.gradeTonnageCurve(
        model: _case.model,
        metals: activeMetals,
        maxNsr: _maxNsr(),
        steps: 36,
      );

  void _recompute({required String? trigger}) {
    final metals = activeMetals;

    _cutoffs = CutoffCalculator.compute(
      costs: _params.costs,
      discountRate: _params.discountRate,
      millCapacity: _params.throughput,
      remainingNpv: _result?.npv ?? 0,
      fixedCostPerYear: _params.costs.ga * _params.throughput * 0.6,
    );

    _result = Scheduler.build(mineCase: _case, params: _params);

    _findings = TutorEngine.analyze(
      mineCase: _case,
      params: _params,
      result: _result!,
      cutoffs: _cutoffs!,
      scenariosExplored: scenariosExplored,
    );

    // Disparo de reflexión contextual.
    String? effective = trigger;
    if (effective == null &&
        _result!.periods.isNotEmpty &&
        _result!.periods.first.oreTonnes < _case.millCapacity * 0.65) {
      effective = 'lowUtilization';
    }
    if (effective != null) {
      for (final r in AssessmentRepository.reflections) {
        if (r.trigger == effective && !_reflectionResults.containsKey(r.id)) {
          _pendingReflection = r;
          break;
        }
      }
    }

    // Se ignora el error de "sin reservas" para no bloquear la exploración:
    // ver un escenario sin proyecto también enseña.
    if (kDebugMode && _result!.periods.isEmpty) {
      debugPrint('Plan sin periodos: revisar ley de corte.');
    }

    notifyListeners();
  }
}

// -------------------------------------------------------------------
// Providers
// -------------------------------------------------------------------

final casesProvider = Provider<List<MineCase>>((ref) => CaseRepository.all());

final sessionProvider = ChangeNotifierProvider<SessionViewModel>(
  (ref) => SessionViewModel(CaseRepository.all().first),
);

/// Persistencia mínima del progreso. Solo guarda resultados propios del
/// estudiante en el dispositivo: no hay cuentas ni envío de datos.
class ProgressStore {
  static const _kBestScore = 'best_score';
  static const _kPreScore = 'pre_score';
  static const _kPostScore = 'post_score';

  static Future<void> saveBestScore(double score) async {
    final p = await SharedPreferences.getInstance();
    final current = p.getDouble(_kBestScore) ?? 0;
    if (score > current) await p.setDouble(_kBestScore, score);
  }

  static Future<double> bestScore() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_kBestScore) ?? 0;
  }

  static Future<void> saveTestScore(int score, {required bool isPost}) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(isPost ? _kPostScore : _kPreScore, score);
  }

  static Future<List<int>> testScores() async {
    final p = await SharedPreferences.getInstance();
    return [p.getInt(_kPreScore) ?? -1, p.getInt(_kPostScore) ?? -1];
  }
}
