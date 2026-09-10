import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../domain/analysis.dart';
import '../domain/cutoff.dart';
import '../domain/scheduler.dart';

TextPainter _label(String text, {double size = 10, Color? color}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: color ?? AppColors.textDim),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp;
}

/// Curva ley-tonelaje con la posición actual del estudiante marcada.
/// Es el gráfico que hace visible el trade-off: menos toneladas, mejor ley.
class GradeTonnageChart extends StatelessWidget {
  final List<GradeTonnagePoint> points;
  final double currentCutoff;

  const GradeTonnageChart({
    super.key,
    required this.points,
    required this.currentCutoff,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return CustomPaint(
        size: Size(c.maxWidth, 170),
        painter: _GtPainter(points, currentCutoff),
      );
    });
  }
}

class _GtPainter extends CustomPainter {
  final List<GradeTonnagePoint> points;
  final double cutoff;

  _GtPainter(this.points, this.cutoff);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const padL = 38.0, padR = 40.0, padT = 12.0, padB = 22.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    final maxCut = points.last.cutoffNsr;
    final maxTon = points.map((p) => p.oreTonnes).fold<double>(0, math.max);
    final maxGrade = points.map((p) => p.averageNsr).fold<double>(0, math.max);
    if (maxTon <= 0 || maxCut <= 0) return;

    final axis = Paint()
      ..color = AppColors.surfaceAlt
      ..strokeWidth = 1;
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + h), axis);
    canvas.drawLine(
        Offset(padL, padT + h), Offset(padL + w, padT + h), axis);

    Offset ptTon(GradeTonnagePoint p) => Offset(
          padL + w * p.cutoffNsr / maxCut,
          padT + h * (1 - p.oreTonnes / maxTon),
        );
    Offset ptGrade(GradeTonnagePoint p) => Offset(
          padL + w * p.cutoffNsr / maxCut,
          padT + h * (1 - (maxGrade <= 0 ? 0 : p.averageNsr / maxGrade)),
        );

    final tonPath = Path()..moveTo(ptTon(points.first).dx, ptTon(points.first).dy);
    final gradePath =
        Path()..moveTo(ptGrade(points.first).dx, ptGrade(points.first).dy);
    for (final p in points.skip(1)) {
      tonPath.lineTo(ptTon(p).dx, ptTon(p).dy);
      gradePath.lineTo(ptGrade(p).dx, ptGrade(p).dy);
    }

    canvas.drawPath(
        tonPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.info);
    canvas.drawPath(
        gradePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.ore);

    // Marcador de la ley de corte actual.
    final x = padL + w * (cutoff / maxCut).clamp(0.0, 1.0).toDouble();
    canvas.drawLine(
        Offset(x, padT),
        Offset(x, padT + h),
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..strokeWidth = 1.2);

    _label('Tonelaje', color: AppColors.info)
        .paint(canvas, Offset(padL + 4, padT - 2));
    _label('Ley media', color: AppColors.ore)
        .paint(canvas, Offset(padL + w - 52, padT - 2));
    _label('Ley de corte (NSR \$/t) →')
        .paint(canvas, Offset(padL, padT + h + 6));
  }

  @override
  bool shouldRepaint(covariant _GtPainter old) =>
      old.cutoff != cutoff || old.points != points;
}

/// Tornado chart: qué variable mueve más el VAN.
class TornadoChart extends StatelessWidget {
  final List<SensitivityBar> bars;

  const TornadoChart({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return CustomPaint(
        size: Size(c.maxWidth, 42.0 * bars.length + 16),
        painter: _TornadoPainter(bars),
      );
    });
  }
}

class _TornadoPainter extends CustomPainter {
  final List<SensitivityBar> bars;

  _TornadoPainter(this.bars);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const padL = 96.0, padR = 8.0;
    final w = size.width - padL - padR;
    final base = bars.first.baseNpv;

    double maxDev = 0;
    for (final b in bars) {
      maxDev = math.max(maxDev, (b.lowNpv - base).abs());
      maxDev = math.max(maxDev, (b.highNpv - base).abs());
    }
    if (maxDev <= 0) maxDev = 1;

    final zero = padL + w / 2;
    canvas.drawLine(
        Offset(zero, 8),
        Offset(zero, size.height - 8),
        Paint()
          ..color = AppColors.textDim.withOpacity(0.5)
          ..strokeWidth = 1);

    for (int i = 0; i < bars.length; i++) {
      final b = bars[i];
      final y = 12.0 + i * 42.0;
      final xLow = zero + (b.lowNpv - base) / maxDev * (w / 2);
      final xHigh = zero + (b.highNpv - base) / maxDev * (w / 2);

      canvas.drawRect(
        Rect.fromLTRB(math.min(zero, xLow), y, math.max(zero, xLow), y + 12),
        Paint()..color = AppColors.negative.withOpacity(0.85),
      );
      canvas.drawRect(
        Rect.fromLTRB(math.min(zero, xHigh), y + 14, math.max(zero, xHigh),
            y + 26),
        Paint()..color = AppColors.positive.withOpacity(0.85),
      );

      _label(b.variable, size: 11, color: AppColors.text)
          .paint(canvas, Offset(4, y + 6));
      _label('Δ ${(b.swing / 1e6).toStringAsFixed(0)} M')
          .paint(canvas, Offset(4, y + 20));
    }
  }

  @override
  bool shouldRepaint(covariant _TornadoPainter old) => old.bars != bars;
}

/// Flujo de caja anual con la curva acumulada descontada.
class CashflowChart extends StatelessWidget {
  final ScheduleResult result;
  final double discountRate;

  const CashflowChart({
    super.key,
    required this.result,
    required this.discountRate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return CustomPaint(
        size: Size(c.maxWidth, 180),
        painter: _CashPainter(result, discountRate),
      );
    });
  }
}

class _CashPainter extends CustomPainter {
  final ScheduleResult result;
  final double rate;

  _CashPainter(this.result, this.rate);

  @override
  void paint(Canvas canvas, Size size) {
    final periods = result.periods;
    if (periods.isEmpty) return;
    const padL = 44.0, padR = 8.0, padT = 10.0, padB = 20.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    final cum = <double>[];
    double acc = -result.capex;
    for (int i = 0; i < periods.length; i++) {
      acc += periods[i].freeCashFlow / math.pow(1 + rate, i + 1);
      cum.add(acc);
    }

    double maxV = math.max(
      periods.map((p) => p.freeCashFlow).fold<double>(0, math.max),
      cum.fold<double>(0, math.max),
    );
    double minV = math.min(
      0.0,
      math.min(
        periods.map((p) => p.freeCashFlow).fold<double>(0.0, math.min),
        cum.fold<double>(0.0, math.min),
      ),
    );
    if (maxV - minV <= 0) return;

    double toY(double v) => padT + h * (1 - (v - minV) / (maxV - minV));

    canvas.drawLine(
        Offset(padL, toY(0)),
        Offset(padL + w, toY(0)),
        Paint()
          ..color = AppColors.textDim.withOpacity(0.5)
          ..strokeWidth = 1);

    final bw = w / periods.length;
    for (int i = 0; i < periods.length; i++) {
      final v = periods[i].freeCashFlow;
      final x = padL + i * bw + bw * 0.18;
      final rect = Rect.fromLTRB(
        x,
        math.min(toY(v), toY(0)),
        x + bw * 0.64,
        math.max(toY(v), toY(0)),
      );
      canvas.drawRect(
          rect,
          Paint()
            ..color = v >= 0
                ? AppColors.positive.withOpacity(0.8)
                : AppColors.negative.withOpacity(0.8));
    }

    final path = Path();
    for (int i = 0; i < cum.length; i++) {
      final x = padL + i * bw + bw / 2;
      final y = toY(cum[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.ore);

    _label('VAN acumulado', color: AppColors.ore)
        .paint(canvas, Offset(padL + 2, padT));
    _label('${(maxV / 1e6).toStringAsFixed(0)} M')
        .paint(canvas, Offset(2, padT));
    _label('${(minV / 1e6).toStringAsFixed(0)} M')
        .paint(canvas, Offset(2, padT + h - 10));
    _label('Año 1 … ${periods.length}')
        .paint(canvas, Offset(padL, padT + h + 6));
  }

  @override
  bool shouldRepaint(covariant _CashPainter old) =>
      old.result != result || old.rate != rate;
}
