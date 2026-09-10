import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../domain/cutoff.dart';
import '../domain/models.dart';

/// Sección vertical del modelo de bloques.
///
/// Decisión de diseño (Etapa 3/5): se descartó el renderizado 3D con GPU.
/// Una sección coloreada por ley, donde el material bajo la ley de corte se
/// apaga en vivo, transmite el concepto con la misma fuerza y sin el riesgo
/// de cronograma de un motor 3D. La rotación isométrica cubre la intuición
/// espacial que falta.
class SectionView extends StatelessWidget {
  final BlockModel model;
  final List<Metal> metals;
  final double cutoffNsr;
  final int sectionIndex;
  final double maxNsr;

  const SectionView({
    super.key,
    required this.model,
    required this.metals,
    required this.cutoffNsr,
    required this.sectionIndex,
    required this.maxNsr,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final grid = model.sectionY(sectionIndex);
      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxWidth * 0.62),
        painter: _SectionPainter(
          grid: grid,
          metals: metals,
          cutoffNsr: cutoffNsr,
          maxNsr: maxNsr,
          nx: model.nx,
          nz: model.nz,
        ),
      );
    });
  }
}

class _SectionPainter extends CustomPainter {
  final List<List<Block?>> grid;
  final List<Metal> metals;
  final double cutoffNsr;
  final double maxNsr;
  final int nx;
  final int nz;

  _SectionPainter({
    required this.grid,
    required this.metals,
    required this.cutoffNsr,
    required this.maxNsr,
    required this.nx,
    required this.nz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / nx;
    final ch = size.height / nz;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int k = 0; k < nz; k++) {
      for (int i = 0; i < nx; i++) {
        final b = grid[k][i];
        if (b == null) continue;
        final nsr = CutoffCalculator.blockNsr(b, metals);
        final isOre = nsr >= cutoffNsr;
        final t = maxNsr <= 0 ? 0.0 : (nsr / maxNsr).clamp(0.0, 1.0).toDouble();

        if (isOre) {
          paint.color = AppColors.gradeColor(t);
        } else {
          // El desmonte no desaparece: se apaga. El estudiante debe seguir
          // viendo que el material existe, solo que no es económico.
          paint.color = Color.lerp(
              AppColors.waste, AppColors.gradeColor(t), 0.18)!;
        }
        final rect = Rect.fromLTWH(i * cw, k * ch, cw + 0.6, ch + 0.6);
        canvas.drawRect(rect, paint);
      }
    }

    // Contorno del cuerpo económico: la línea que se mueve al cambiar la
    // ley de corte. Es el elemento visual que enseña el concepto.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.ore.withValues(alpha: 0.95);

    for (int k = 0; k < nz; k++) {
      for (int i = 0; i < nx; i++) {
        final b = grid[k][i];
        if (b == null) continue;
        if (CutoffCalculator.blockNsr(b, metals) < cutoffNsr) continue;
        bool ore(int ii, int kk) {
          if (ii < 0 || ii >= nx || kk < 0 || kk >= nz) return false;
          final n = grid[kk][ii];
          if (n == null) return false;
          return CutoffCalculator.blockNsr(n, metals) >= cutoffNsr;
        }

        final x0 = i * cw, y0 = k * ch, x1 = x0 + cw, y1 = y0 + ch;
        if (!ore(i, k - 1)) canvas.drawLine(Offset(x0, y0), Offset(x1, y0), outline);
        if (!ore(i, k + 1)) canvas.drawLine(Offset(x0, y1), Offset(x1, y1), outline);
        if (!ore(i - 1, k)) canvas.drawLine(Offset(x0, y0), Offset(x0, y1), outline);
        if (!ore(i + 1, k)) canvas.drawLine(Offset(x1, y0), Offset(x1, y1), outline);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SectionPainter old) =>
      old.cutoffNsr != cutoffNsr ||
      old.grid != grid ||
      old.maxNsr != maxNsr ||
      old.metals != metals;
}

/// Vista isométrica del cuerpo económico. Solo dibuja los bloques de la
/// superficie del sólido, lo que la mantiene fluida sin GPU.
class IsoView extends StatefulWidget {
  final BlockModel model;
  final List<Metal> metals;
  final double cutoffNsr;
  final double maxNsr;

  const IsoView({
    super.key,
    required this.model,
    required this.metals,
    required this.cutoffNsr,
    required this.maxNsr,
  });

  @override
  State<IsoView> createState() => _IsoViewState();
}

class _IsoViewState extends State<IsoView> {
  double _angle = 0.6;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          return GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() => _angle += d.delta.dx * 0.012);
            },
            child: CustomPaint(
              size: Size(c.maxWidth, c.maxWidth * 0.72),
              painter: _IsoPainter(
                model: widget.model,
                metals: widget.metals,
                cutoffNsr: widget.cutoffNsr,
                maxNsr: widget.maxNsr,
                angle: _angle,
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        const Text(
          'Arrastra horizontalmente para rotar el cuerpo económico.',
          style: TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _IsoPainter extends CustomPainter {
  final BlockModel model;
  final List<Metal> metals;
  final double cutoffNsr;
  final double maxNsr;
  final double angle;

  _IsoPainter({
    required this.model,
    required this.metals,
    required this.cutoffNsr,
    required this.maxNsr,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ore = <int, Block>{};
    int key(int i, int j, int k) =>
        (k * model.ny + j) * model.nx + i;

    for (final b in model.blocks) {
      if (CutoffCalculator.blockNsr(b, metals) >= cutoffNsr) {
        ore[key(b.i, b.j, b.k)] = b;
      }
    }
    if (ore.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Sin material económico en este escenario',
          style: TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2));
      return;
    }

    // Solo la cáscara del sólido: si un bloque tiene sus seis vecinos
    // dentro del cuerpo económico, no se ve y no se dibuja.
    final shell = <Block>[];
    for (final b in ore.values) {
      final hidden = ore.containsKey(key(b.i - 1, b.j, b.k)) &&
          ore.containsKey(key(b.i + 1, b.j, b.k)) &&
          ore.containsKey(key(b.i, b.j - 1, b.k)) &&
          ore.containsKey(key(b.i, b.j + 1, b.k)) &&
          ore.containsKey(key(b.i, b.j, b.k - 1)) &&
          ore.containsKey(key(b.i, b.j, b.k + 1));
      if (!hidden) shell.add(b);
    }

    final ca = math.cos(angle), sa = math.sin(angle);
    final cx = model.nx / 2.0, cy = model.ny / 2.0, cz = model.nz / 2.0;

    double px(double x, double y) => (x - cx) * ca - (y - cy) * sa;
    double py(double x, double y, double z) =>
        ((x - cx) * sa + (y - cy) * ca) * 0.52 + (z - cz) * 0.86;

    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    for (final b in shell) {
      for (final dx in const [0.0, 1.0]) {
        for (final dy in const [0.0, 1.0]) {
          for (final dz in const [0.0, 1.0]) {
            final X = px(b.i + dx, b.j + dy);
            final Y = py(b.i + dx, b.j + dy, b.k + dz);
            minX = math.min(minX, X);
            maxX = math.max(maxX, X);
            minY = math.min(minY, Y);
            maxY = math.max(maxY, Y);
          }
        }
      }
    }
    final spanX = math.max(1e-6, maxX - minX);
    final spanY = math.max(1e-6, maxY - minY);
    final scale =
        math.min(size.width * 0.9 / spanX, size.height * 0.9 / spanY);
    final offX = size.width / 2 - (minX + maxX) / 2 * scale;
    final offY = size.height / 2 - (minY + maxY) / 2 * scale;

    Offset proj(double x, double y, double z) =>
        Offset(px(x, y) * scale + offX, py(x, y, z) * scale + offY);

    // Pintor: de atrás hacia adelante.
    shell.sort((a, b) {
      final da = py(a.i.toDouble(), a.j.toDouble(), a.k.toDouble());
      final db = py(b.i.toDouble(), b.j.toDouble(), b.k.toDouble());
      return da.compareTo(db);
    });

    final paint = Paint()..style = PaintingStyle.fill;
    for (final b in shell) {
      final nsr = CutoffCalculator.blockNsr(b, metals);
      final t = maxNsr <= 0 ? 0.0 : (nsr / maxNsr).clamp(0.0, 1.0).toDouble();
      final base = AppColors.gradeColor(t);
      final i = b.i.toDouble(), j = b.j.toDouble(), k = b.k.toDouble();

      // Cara superior.
      final top = Path()
        ..moveTo(proj(i, j, k).dx, proj(i, j, k).dy)
        ..lineTo(proj(i + 1, j, k).dx, proj(i + 1, j, k).dy)
        ..lineTo(proj(i + 1, j + 1, k).dx, proj(i + 1, j + 1, k).dy)
        ..lineTo(proj(i, j + 1, k).dx, proj(i, j + 1, k).dy)
        ..close();
      paint.color = base;
      canvas.drawPath(top, paint);

      // Cara frontal.
      final front = Path()
        ..moveTo(proj(i, j + 1, k).dx, proj(i, j + 1, k).dy)
        ..lineTo(proj(i + 1, j + 1, k).dx, proj(i + 1, j + 1, k).dy)
        ..lineTo(proj(i + 1, j + 1, k + 1).dx, proj(i + 1, j + 1, k + 1).dy)
        ..lineTo(proj(i, j + 1, k + 1).dx, proj(i, j + 1, k + 1).dy)
        ..close();
      paint.color = Color.lerp(base, Colors.black, 0.30)!;
      canvas.drawPath(front, paint);

      // Cara lateral.
      final side = Path()
        ..moveTo(proj(i + 1, j, k).dx, proj(i + 1, j, k).dy)
        ..lineTo(proj(i + 1, j + 1, k).dx, proj(i + 1, j + 1, k).dy)
        ..lineTo(proj(i + 1, j + 1, k + 1).dx, proj(i + 1, j + 1, k + 1).dy)
        ..lineTo(proj(i + 1, j, k + 1).dx, proj(i + 1, j, k + 1).dy)
        ..close();
      paint.color = Color.lerp(base, Colors.black, 0.50)!;
      canvas.drawPath(side, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IsoPainter old) =>
      old.cutoffNsr != cutoffNsr ||
      old.angle != angle ||
      old.metals != metals ||
      old.maxNsr != maxNsr;
}

/// Leyenda de la escala de leyes.
class GradeLegend extends StatelessWidget {
  final double maxNsr;

  const GradeLegend({super.key, required this.maxNsr});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('NSR 0',
            style: TextStyle(fontSize: 10, color: AppColors.textDim)),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: [
                AppColors.gradeColor(0),
                AppColors.gradeColor(0.5),
                AppColors.gradeColor(1),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('\$${maxNsr.toStringAsFixed(0)}/t',
            style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
      ],
    );
  }
}
