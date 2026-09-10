import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback.dart';
import '../core/ui.dart';
import '../domain/models.dart';
import '../viewmodels/session.dart';
import 'assessment.dart';
import 'theory.dart';
import 'workspace.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(casesProvider);
    final session = ref.watch(sessionProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const Text('PlanificaMina',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 6),
            const Text(
              'Simulador de decisiones de planeamiento minero. Aquí la ley de '
              'corte no es un dato: es una decisión que tiene consecuencias '
              'que puedes ver.',
              style: TextStyle(color: AppColors.textDim, height: 1.4),
            ),
            const SizedBox(height: 22),
            _ActionCard(
              title: 'Diagnóstico inicial',
              subtitle:
                  '6 preguntas. Responde antes de simular; las repetirás al '
                  'final para medir qué cambió.',
              icon: Icons.checklist_rtl,
              done: session.preTest.length == 6,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AssessmentScreen(isPost: false))),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              title: 'Conceptos y límites del modelo',
              subtitle:
                  'Las fórmulas que usa la app y, sobre todo, lo que este '
                  'modelo NO representa.',
              icon: Icons.menu_book_outlined,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TheoryScreen())),
            ),
            const SizedBox(height: 26),
            const SectionTitle('Casos de estudio',
                subtitle:
                    'Yacimientos ficticios calibrados: en los tres, la ley de '
                    'corte cae dentro del rango de leyes del modelo.'),
            const SizedBox(height: 12),
            ...cases.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CaseCard(
                    mineCase: c,
                    selected: session.mineCase.id == c.id,
                    onTap: () {
                      session.loadCase(c);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const WorkspaceScreen()));
                    },
                  ),
                )),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceAlt),
              ),
              child: const Text(
                'Aplicación educativa. Los modelos de bloques son sintéticos y '
                'los cálculos económicos están simplificados. No sustituye '
                'software profesional de planeamiento ni un estudio de '
                'factibilidad, y no debe usarse para decisiones de inversión.',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textDim, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceAlt),
        ),
        child: Row(
          children: [
            Icon(icon, color: done ? AppColors.positive : AppColors.ore),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textDim,
                          height: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final MineCase mineCase;
  final bool selected;
  final VoidCallback onTap;

  const _CaseCard({
    required this.mineCase,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.ore : AppColors.surfaceAlt,
              width: selected ? 1.4 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(mineCase.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${mineCase.model.count} bloques',
                    style:
                        const TextStyle(fontSize: 10, color: AppColors.textDim),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(mineCase.subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.ore)),
            const SizedBox(height: 8),
            Text(mineCase.learningFocus,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textDim, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
