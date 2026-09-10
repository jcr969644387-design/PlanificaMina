import 'dart:math' as math;

import 'analysis.dart';
import 'cutoff.dart';
import 'models.dart';
import 'scheduler.dart';

enum FindingLevel { critical, warning, insight, praise }

class TutorFinding {
  final FindingLevel level;
  final String title;
  final String explanation;

  /// Pregunta socrática: el tutor no entrega la respuesta, la provoca.
  final String? question;
  final String concept;

  const TutorFinding({
    required this.level,
    required this.title,
    required this.explanation,
    required this.concept,
    this.question,
  });
}

/// Motor de diagnóstico determinista. Funciona 100 % offline.
///
/// Decisión de diseño (Etapa 6): las reglas cubren los errores conocidos de
/// planeamiento. Un LLM solo se justifica para preguntas abiertas fuera de
/// este catálogo, y como capa opcional, nunca como dependencia.
class TutorEngine {
  static List<TutorFinding> analyze({
    required MineCase mineCase,
    required ScenarioParams params,
    required ScheduleResult result,
    required CutoffSet cutoffs,
    required int scenariosExplored,
  }) {
    final findings = <TutorFinding>[];
    final metals = params.resolveMetals(mineCase.metals);
    final primary = metals.first;

    // 1. Ley de corte por debajo de la marginal: destruye valor por tonelada.
    if (params.cutoffNsr < cutoffs.marginal - 0.01) {
      findings.add(TutorFinding(
        level: FindingLevel.critical,
        title: 'Estás procesando material que pierde dinero',
        explanation:
            'Tu ley de corte equivale a ${params.cutoffNsr.toStringAsFixed(2)} '
            r'$/t de NSR, pero procesar una tonelada cuesta '
            '${cutoffs.marginal.toStringAsFixed(2)} \$/t solo en planta y G&A. '
            'Cada tonelada bajo ese umbral destruye valor aunque el bloque ya '
            'esté minado.',
        question:
            '¿Qué deberías hacer con un bloque cuyo NSR está entre 0 y la ley '
            'de corte marginal: procesarlo, botarlo a desmonte o dejarlo in situ?',
        concept: 'Ley de corte marginal',
      ));
    }

    // 2. Tajo abierto usando breakeven cuando el minado ya es costo hundido.
    if (mineCase.method == MiningMethod.openPit &&
        params.cutoffNsr > cutoffs.marginal + 0.5 &&
        params.cutoffNsr >= cutoffs.breakeven - 0.5) {
      findings.add(TutorFinding(
        level: FindingLevel.insight,
        title: 'Estás aplicando ley de corte breakeven dentro del tajo',
        explanation:
            'La breakeven (${cutoffs.breakeven.toStringAsFixed(2)} \$/t) sirve '
            'para decidir si el proyecto existe. Pero una vez que el tajo está '
            'definido, el costo de minado se incurre igual: ese material sale '
            'del pit tanto si va a planta como si va a botadero. Para decidir '
            'el destino del bloque, la referencia es la marginal '
            '(${cutoffs.marginal.toStringAsFixed(2)} \$/t).',
        question:
            'Si el bloque ya está arriba del camión, ¿qué costo es relevante '
            'para decidir a dónde lo llevas?',
        concept: 'Costo hundido vs. costo incremental',
      ));
    }

    // 3. Ley de corte muy por encima de Lane: capacidad ociosa.
    if (params.cutoffNsr > cutoffs.lane * 1.6 && result.periods.isNotEmpty) {
      final util = result.periods.first.oreTonnes / mineCase.millCapacity;
      if (util < 0.85) {
        findings.add(TutorFinding(
          level: FindingLevel.warning,
          title: 'Planta subutilizada al ${(util * 100).toStringAsFixed(0)} %',
          explanation:
              'Tu ley de corte es tan alta que no hay suficiente mineral para '
              'llenar la planta. Los costos fijos se reparten entre menos '
              'toneladas y el costo unitario sube.',
          question:
              '¿Cuál es el costo real de dejar capacidad de planta ociosa un año?',
          concept: 'Cuello de botella y utilización',
        ));
      }
    }

    // 4. Precedencia.
    for (final issue in result.issues) {
      if (issue.severity == IssueSeverity.error &&
          issue.title.contains('Precedencia')) {
        findings.add(TutorFinding(
          level: FindingLevel.critical,
          title: issue.title,
          explanation: issue.detail,
          question:
              '¿Cómo llegaría físicamente un equipo a esa zona con el diseño '
              'que propusiste?',
          concept: 'Secuenciamiento y accesibilidad',
        ));
      }
    }

    // 5. High-grading.
    final decline = PlanDiagnostics.gradeDeclineIndex(result, primary.symbol);
    if (decline > 0.35 && result.lifeYears >= 4) {
      findings.add(TutorFinding(
        level: FindingLevel.insight,
        title: 'Tu plan concentra la ley alta al inicio',
        explanation:
            'La ley de alimentación cae ${(decline * 100).toStringAsFixed(0)} % '
            'entre el primer tercio y el último tercio de la vida de mina. Esto '
            'sube el VAN porque adelanta caja, y es una estrategia real. Pero '
            'deja los últimos años con margen delgado y el proyecto queda '
            'expuesto si el precio cae al final.',
        question:
            '¿Cómo defenderías este perfil ante un directorio que pregunta por '
            'la sostenibilidad del empleo en los últimos cinco años?',
        concept: 'High-grading y costo de oportunidad (Lane)',
      ));
    }

    // 6. VAN negativo.
    if (result.npv < 0) {
      findings.add(TutorFinding(
        level: FindingLevel.critical,
        title: 'El proyecto destruye valor: VAN negativo',
        explanation:
            'Con esta configuración el VAN es '
            '${_money(result.npv)} a una tasa del '
            '${(params.discountRate * 100).toStringAsFixed(1)} %. Antes de '
            'ajustar la ley de corte, revisa si el problema es de escala '
            '(alimentación de planta), de costos o simplemente de precio.',
        question:
            '¿El problema de este proyecto es geológico, operativo o de mercado?',
        concept: 'Evaluación económica',
      ));
    }

    // 7. TIR por debajo de la tasa de descuento.
    if (result.irr != null &&
        result.npv >= 0 &&
        result.irr! < params.discountRate + 0.02) {
      findings.add(TutorFinding(
        level: FindingLevel.warning,
        title: 'Margen estrecho entre TIR y tasa de descuento',
        explanation:
            'La TIR es ${(result.irr! * 100).toStringAsFixed(1)} % contra una '
            'tasa exigida de ${(params.discountRate * 100).toStringAsFixed(1)} %. '
            'Un movimiento adverso pequeño en precio o costos vuelve el '
            'proyecto inviable.',
        question: '¿Qué variable tendrías que cubrir o contratar a futuro?',
        concept: 'Riesgo y sensibilidad',
      ));
    }

    // 8. No exploró escenarios.
    if (scenariosExplored < 3) {
      findings.add(const TutorFinding(
        level: FindingLevel.warning,
        title: 'Todavía no probaste escenarios alternativos',
        explanation:
            'Un plan de mina evaluado en un solo escenario de precio no es un '
            'plan: es una apuesta. Corre al menos el escenario pesimista antes '
            'de presentar a gerencia.',
        question: '¿A qué precio de metal tu plan deja de ser rentable?',
        concept: 'Análisis de escenarios',
      ));
    }

    // 9. Reconocimiento cuando el plan está bien construido.
    if (findings.isEmpty ||
        findings.every((f) => f.level == FindingLevel.insight)) {
      findings.add(TutorFinding(
        level: FindingLevel.praise,
        title: 'Plan coherente',
        explanation:
            'Respeta precedencias, no excede capacidad y genera un VAN de '
            '${_money(result.npv)} con una vida de ${result.lifeYears} años. '
            'Ahora el siguiente nivel de exigencia es la robustez: cómo se '
            'comporta ante el escenario pesimista.',
        concept: 'Integración',
      ));
    }

    return findings;
  }

  static String _money(double v) {
    final m = v / 1e6;
    return '${m >= 0 ? '' : '-'}\$${m.abs().toStringAsFixed(1)} M';
  }
}

/// Puntuación compuesta.
///
/// Decisión de diseño (Etapa 1): NO se rankea por VAN puro, porque premia
/// exactamente el comportamiento que la planificación real castiga. El VAN
/// pesa, pero comparte peso con el cumplimiento de restricciones, la
/// robustez ante escenarios y la comprensión conceptual demostrada.
class ScoreBreakdown {
  final double valueScore;
  final double complianceScore;
  final double robustnessScore;
  final double understandingScore;

  const ScoreBreakdown({
    required this.valueScore,
    required this.complianceScore,
    required this.robustnessScore,
    required this.understandingScore,
  });

  double get total =>
      valueScore + complianceScore + robustnessScore + understandingScore;

  String get role {
    if (total >= 75) return 'Gerente de Operaciones';
    if (total >= 45) return 'Jefe de Planeamiento';
    return 'Planificador Junior';
  }

  String get roleHint {
    if (total >= 75) {
      return 'Nivel máximo: se desbloquean CAPEX, regalías y la comparación '
          'tajo abierto vs. subterránea.';
    }
    if (total >= 45) {
      return 'Se desbloquean las restricciones de flota y el secuenciamiento '
          'por fases.';
    }
    return 'Domina primero la ley de corte antes de programar producción.';
  }
}

class ScoringEngine {
  /// [referenceNpv] es el VAN del plan de referencia calculado con la ley de
  /// corte de Lane. Se usa como escala, no como respuesta correcta única.
  static ScoreBreakdown score({
    required ScheduleResult result,
    required double referenceNpv,
    required int scenariosExplored,
    required int reflectionsCorrect,
    required int reflectionsTotal,
  }) {
    // Valor económico: 35 puntos, saturado en el 100 % de la referencia.
    double value = 0;
    if (referenceNpv > 0) {
      value = 35 * math.min(1.0, math.max(0.0, result.npv / referenceNpv));
    } else if (result.npv > 0) {
      value = 35;
    }

    // Cumplimiento de restricciones: 25 puntos, penalizado por incidencia.
    double compliance = 25;
    for (final i in result.issues) {
      if (i.severity == IssueSeverity.error) compliance -= 12;
      if (i.severity == IssueSeverity.warning) compliance -= 4;
    }
    compliance = math.max(0.0, compliance);

    // Robustez: 15 puntos por explorar escenarios.
    final robustness = 15 * math.min(1.0, scenariosExplored / 4.0);

    // Comprensión conceptual: 25 puntos por respuestas de reflexión.
    final understanding = reflectionsTotal <= 0
        ? 0.0
        : 25 * (reflectionsCorrect / reflectionsTotal);

    return ScoreBreakdown(
      valueScore: value,
      complianceScore: compliance,
      robustnessScore: robustness,
      understandingScore: understanding,
    );
  }
}
