import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui.dart';
import '../data/assessment_repository.dart';
import '../viewmodels/session.dart';

/// Hoja de reflexión contextual.
///
/// Aparece en el momento en que el estudiante provoca la consecuencia, no al
/// final. Sin esta interrupción deliberada, mover sliders es entretenimiento.
class ReflectionSheet extends ConsumerStatefulWidget {
  final ReflectionPrompt prompt;

  const ReflectionSheet({super.key, required this.prompt});

  @override
  ConsumerState<ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends ConsumerState<ReflectionSheet> {
  int? _selected;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.prompt;
    final correct = _selected == p.correctIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('UN MOMENTO',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.ore,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(p.prompt,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 14),
          ...List.generate(p.options.length, (i) {
            final isSel = _selected == i;
            Color border = AppColors.surfaceAlt;
            if (_revealed && i == p.correctIndex) border = AppColors.positive;
            if (_revealed && isSel && i != p.correctIndex) {
              border = AppColors.negative;
            } else if (!_revealed && isSel) {
              border = AppColors.ore;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: _revealed ? null : () => setState(() => _selected = i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bedrock,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Text(p.options[i],
                      style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ),
              ),
            );
          }),
          if (_revealed) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (correct ? AppColors.positive : AppColors.warning)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(correct ? 'Correcto' : 'Revisemos esto',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: correct
                              ? AppColors.positive
                              : AppColors.warning)),
                  const SizedBox(height: 5),
                  Text(p.explanation,
                      style: const TextStyle(fontSize: 12, height: 1.45)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected == null
                  ? null
                  : () {
                      if (!_revealed) {
                        ref
                            .read(sessionProvider)
                            .answerReflection(p.id, _selected!);
                        setState(() => _revealed = true);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
              child: Text(_revealed ? 'Continuar' : 'Responder'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagnóstico (pre) y evaluación de cierre (post) con el mismo banco.
class AssessmentScreen extends ConsumerStatefulWidget {
  final bool isPost;

  const AssessmentScreen({super.key, required this.isPost});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final answers = widget.isPost ? s.postTest : s.preTest;
    final questions = AssessmentRepository.diagnostic;
    final complete = answers.length == questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPost ? 'Evaluación de cierre' : 'Diagnóstico'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Text(
            widget.isPost
                ? 'Las mismas seis preguntas del inicio. Lo que importa no es '
                    'el puntaje absoluto, sino cuánto se movió.'
                : 'Responde antes de simular. No hay penalidad por fallar: '
                    'este diagnóstico existe para medir tu punto de partida.',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textDim, height: 1.45),
          ),
          const SizedBox(height: 18),
          ...questions.map((q) {
            final sel = answers[q.id];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceAlt),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.prompt,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                  const SizedBox(height: 10),
                  ...List.generate(q.options.length, (i) {
                    Color border = AppColors.surfaceAlt;
                    if (_submitted && i == q.correctIndex) {
                      border = AppColors.positive;
                    } else if (_submitted && sel == i) {
                      border = AppColors.negative;
                    } else if (sel == i) {
                      border = AppColors.ore;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: InkWell(
                        onTap: _submitted
                            ? null
                            : () => s.answerDiagnostic(q.id, i,
                                isPost: widget.isPost),
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.bedrock,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: border),
                          ),
                          child: Text(q.options[i],
                              style: const TextStyle(
                                  fontSize: 12, height: 1.35)),
                        ),
                      ),
                    );
                  }),
                  if (_submitted) ...[
                    const SizedBox(height: 6),
                    Text(q.explanation,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textDim,
                            height: 1.45)),
                  ],
                ],
              ),
            );
          }),
          if (!_submitted)
            FilledButton(
              onPressed: complete
                  ? () async {
                      setState(() => _submitted = true);
                      await ProgressStore.saveTestScore(scoreOf(answers),
                          isPost: widget.isPost);
                      if (widget.isPost) {
                        await ProgressStore.saveBestScore(s.score().total);
                      }
                    }
                  : null,
              child: Text(complete
                  ? 'Enviar respuestas'
                  : 'Faltan ${questions.length - answers.length} preguntas'),
            )
          else
            _ResultPanel(isPost: widget.isPost),
        ],
      ),
    );
  }

  int scoreOf(Map<String, int> answers) {
    int c = 0;
    for (final q in AssessmentRepository.diagnostic) {
      if (answers[q.id] == q.correctIndex) c++;
    }
    return c;
  }
}

class _ResultPanel extends ConsumerWidget {
  final bool isPost;

  const _ResultPanel({required this.isPost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final pre = s.scoreOf(s.preTest);
    final post = s.scoreOf(s.postTest);
    final total = AssessmentRepository.diagnostic.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ore.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPost
                    ? 'Diagnóstico $pre/$total  →  Cierre $post/$total'
                    : 'Diagnóstico: $pre/$total',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                isPost
                    ? (post > pre
                        ? 'Mejoraste ${post - pre} respuestas. Ahora viene la '
                            'prueba que de verdad importa: resolverlo sin la app.'
                        : 'El puntaje no subió. Eso no significa que la sesión '
                            'fallara: revisa las explicaciones y vuelve a '
                            'simular el caso con la variable que fallaste.')
                    : 'Guarda este resultado mentalmente. Al terminar la '
                        'simulación repetirás estas preguntas.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textDim, height: 1.45),
              ),
            ],
          ),
        ),
        if (isPost) ...[
          const SizedBox(height: 18),
          const SectionTitle('Tarea de transferencia',
              subtitle:
                  'Se resuelve en papel, sin la aplicación. Es la única '
                  'evidencia real de que aprendiste el concepto y no la '
                  'interfaz.'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceAlt),
            ),
            child: Text(AssessmentRepository.transferTask,
                style: const TextStyle(
                    fontSize: 12, height: 1.55, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Copiar tarea'),
            onPressed: () {
              Clipboard.setData(
                  const ClipboardData(text: AssessmentRepository.transferTask));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tarea copiada')));
            },
          ),
        ],
      ],
    );
  }
}
