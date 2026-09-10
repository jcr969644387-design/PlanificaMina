import 'package:flutter/material.dart';

/// Paleta: tierra y roca, no el azul corporativo genérico. La escala de
/// leyes usa un gradiente frío→cálido que es legible en pantalla pequeña y
/// bajo luz de campo.
class AppColors {
  static const bedrock = Color(0xFF1B1D21);
  static const surface = Color(0xFF24272C);
  static const surfaceAlt = Color(0xFF2E3238);
  static const ore = Color(0xFFE0A343);
  static const oreDeep = Color(0xFFC97B2B);
  static const waste = Color(0xFF4A5058);
  static const positive = Color(0xFF5BB98C);
  static const negative = Color(0xFFD9534F);
  static const warning = Color(0xFFE8B04B);
  static const info = Color(0xFF6FA8DC);
  static const text = Color(0xFFECEDEF);
  static const textDim = Color(0xFF9BA1AA);

  /// Escala de color por ley normalizada (0-1).
  static Color gradeColor(double t) {
    final v = t.clamp(0.0, 1.0).toDouble();
    if (v < 0.5) {
      return Color.lerp(
          const Color(0xFF2E4159), const Color(0xFF7C8F5A), v / 0.5)!;
    }
    return Color.lerp(
        const Color(0xFF7C8F5A), const Color(0xFFF2C14E), (v - 0.5) / 0.5)!;
  }
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bedrock,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.ore,
      secondary: AppColors.info,
      surface: AppColors.surface,
      error: AppColors.negative,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bedrock,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.ore,
      thumbColor: AppColors.ore,
      inactiveTrackColor: AppColors.surfaceAlt,
      trackHeight: 3,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}

/// Formateo consistente. Los estudiantes se confunden con notaciones mixtas,
/// así que toda la app usa las mismas unidades: Mt, M$, %.
class Fmt {
  static String money(double v, {int decimals = 1}) {
    final m = v / 1e6;
    final sign = m < 0 ? '-' : '';
    return '$sign\$${m.abs().toStringAsFixed(decimals)} M';
  }

  static String dollars(double v, {int decimals = 2}) =>
      '\$${v.toStringAsFixed(decimals)}';

  static String mt(double tonnes, {int decimals = 2}) =>
      '${(tonnes / 1e6).toStringAsFixed(decimals)} Mt';

  static String kt(double tonnes) => '${(tonnes / 1e3).toStringAsFixed(0)} kt';

  static String pct(double fraction, {int decimals = 1}) =>
      '${(fraction * 100).toStringAsFixed(decimals)} %';

  static String grade(double g, String suffix) =>
      '${g.toStringAsFixed(suffix == '%' ? 3 : 2)} $suffix';

  static String years(double? y) =>
      y == null ? '—' : '${y.toStringAsFixed(1)} años';
}

/// Ficha de indicador reutilizable.
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textDim, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.text)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? subtitle;

  const SectionTitle(this.text, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
        ],
      ],
    );
  }
}
