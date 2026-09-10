import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback.dart';
import '../core/ui.dart';
import '../data/case_repository.dart';
import '../domain/analysis.dart';
import '../domain/cutoff.dart';
import '../domain/export.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';
import '../domain/tutor.dart';
import '../viewmodels/session.dart';
import '../widgets/block_views.dart';
import '../widgets/charts.dart';
import 'assessment.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);

    // Reflexión contextual: se presenta en el momento exacto en que el
    // estudiante provocó la consecuencia, no al final de la sesión.
    final pending = s.pendingReflection;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          builder: (_) => ReflectionSheet(prompt: pending),
        );
        s.dismissReflection();
      });
    }

    final pages = <Widget>[
      const _ModelTab(),
      const _CutoffTab(),
      const _ScheduleTab(),
      const _EconomicsTab(),
      const _TutorTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.mineCase.name, style: const TextStyle(fontSize: 16)),
            Text(s.score().role,
                style: const TextStyle(fontSize: 11, color: AppColors.ore)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión de trabajo y evaluar',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () {
              Haptics.tap();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AssessmentScreen(isPost: true)));
            },
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          Haptics.section();
          setState(() => _tab = i);
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.ore.withValues(alpha: 0.22),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined), label: 'Modelo'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Ley corte'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), label: 'Programa'),
          NavigationDestination(
              icon: Icon(Icons.attach_money), label: 'Economía'),
          NavigationDestination(
              icon: Icon(Icons.psychology_alt_outlined), label: 'Tutor'),
        ],
      ),
    );
  }
}

// =====================================================================
// TAB 1 — Modelo de bloques
// =====================================================================
class _ModelTab extends ConsumerStatefulWidget {
  const _ModelTab();

  @override
  ConsumerState<_ModelTab> createState() => _ModelTabState();
}

class _ModelTabState extends ConsumerState<_ModelTab> {
  int _section = 2;
  bool _iso = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final maxNsr = s.maxNsrForSlider();
    final stats = s.reservesAt(s.params.cutoffNsr);
    final int sectionIndex = _section.clamp(0, s.mineCase.model.ny - 1).toInt();

    return ListView(
      padding: EdgeInsets.fromLTRB(
          14, 14, 14, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionTitle('Modelo de bloques',
                  subtitle: 'El material bajo la ley de corte se apaga.'),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Sección')),
                ButtonSegment(value: true, label: Text('3D')),
              ],
              selected: {_iso},
              onSelectionChanged: (v) => setState(() => _iso = v.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_iso)
          IsoView(
            model: s.mineCase.model,
            metals: s.activeMetals,
            cutoffNsr: s.params.cutoffNsr,
            maxNsr: maxNsr,
          )
        else ...[
          SectionView(
            model: s.mineCase.model,
            metals: s.activeMetals,
            cutoffNsr: s.params.cutoffNsr,
            sectionIndex: sectionIndex,
            maxNsr: maxNsr,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Sección',
                  style: TextStyle(fontSize: 11, color: AppColors.textDim)),
              Expanded(
                child: Slider(
                  value: sectionIndex.toDouble(),
                  min: 0,
                  max: (s.mineCase.model.ny - 1).toDouble(),
                  divisions: s.mineCase.model.ny - 1,
                  label: 'Y $sectionIndex',
                  onChanged: (v) => setState(() => _section = v.round()),
                ),
              ),
              Text('${sectionIndex + 1}/${s.mineCase.model.ny}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textDim)),
            ],
          ),
        ],
        const SizedBox(height: 6),
        GradeLegend(maxNsr: maxNsr),
        const SizedBox(height: 18),
        _StatsGrid(stats: stats, session: s),
        const SizedBox(height: 18),
        _InfoBox(
          title: 'Geología del caso',
          body: s.mineCase.geologyNote,
        ),
        const SizedBox(height: 10),
        const _InfoBox(
          title: 'Clasificación de recursos',
          body:
              'Este modelo trata todo el material como recurso medido, lo cual '
              'es una simplificación deliberada. En un proyecto real solo los '
              'recursos medidos e indicados pueden convertirse en reservas y '
              'programarse; los inferidos no pueden sustentar un plan de '
              'producción bajo los estándares de reporte vigentes.',
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final ReserveStats stats;
  final SessionViewModel session;

  const _StatsGrid({required this.stats, required this.session});

  @override
  Widget build(BuildContext context) {
    final primary = session.activeMetals.first;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        KpiTile(
            label: 'MINERAL SOBRE LEY DE CORTE',
            value: Fmt.mt(stats.oreTonnes),
            hint: '${stats.oreBlocks} bloques'),
        KpiTile(
            label: 'LEY MEDIA ${primary.symbol}',
            value: Fmt.grade(
                stats.averageGrades[primary.symbol] ?? 0, primary.gradeSuffix)),
        KpiTile(
            label: 'NSR MEDIO', value: '${Fmt.dollars(stats.averageNsr)} /t'),
        KpiTile(
            label: session.mineCase.method == MiningMethod.openPit
                ? 'RELACIÓN DE DESCAPOTE'
                : 'MATERIAL BAJO LEY',
            value: session.mineCase.method == MiningMethod.openPit
                ? '${stats.stripRatio.toStringAsFixed(2)} : 1'
                : Fmt.mt(stats.wasteTonnes)),
      ],
    );
  }
}

// =====================================================================
// TAB 2 — Ley de corte (el corazón de la app)
// =====================================================================
class _CutoffTab extends ConsumerWidget {
  const _CutoffTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final c = s.cutoffs;
    final primary = s.activeMetals.first;
    final maxNsr = s.maxNsrForSlider();
    final stats = s.reservesAt(s.params.cutoffNsr);
    final scenarios = CaseRepository.scenariosFor(s.mineCase);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          14, 14, 14, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        const SectionTitle('Ley de corte',
            subtitle:
                'Mueve una variable y observa qué le pasa al yacimiento.'),
        const SizedBox(height: 14),

        // --- Lectura principal -----------------------------------------
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ore.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LEY DE CORTE ACTUAL',
                  style: TextStyle(fontSize: 10, color: AppColors.textDim)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.mineCase.isPolymetallic
                        ? '${Fmt.dollars(s.params.cutoffNsr)} /t'
                        : Fmt.grade(
                            CutoffCalculator.nsrToGrade(
                                s.params.cutoffNsr, primary),
                            primary.gradeSuffix),
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ore),
                  ),
                  const SizedBox(width: 10),
                  if (!s.mineCase.isPolymetallic)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('= ${Fmt.dollars(s.params.cutoffNsr)} /t NSR',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textDim)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: s.params.cutoffNsr.clamp(0.0, maxNsr).toDouble(),
                min: 0,
                max: maxNsr,
                onChanged: s.setCutoffNsr,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _CriterionChip(
                    label: 'Breakeven',
                    value: c.breakeven,
                    metal: primary,
                    poly: s.mineCase.isPolymetallic,
                    active: (s.params.cutoffNsr - c.breakeven).abs() < 0.05,
                    onTap: () => s.applyCutoffCriterion('breakeven'),
                  ),
                  _CriterionChip(
                    label: 'Marginal',
                    value: c.marginal,
                    metal: primary,
                    poly: s.mineCase.isPolymetallic,
                    active: (s.params.cutoffNsr - c.marginal).abs() < 0.05,
                    onTap: () => s.applyCutoffCriterion('marginal'),
                  ),
                  _CriterionChip(
                    label: 'Lane',
                    value: s.lane?.cutoffNsr ?? c.lane,
                    metal: primary,
                    poly: s.mineCase.isPolymetallic,
                    active: s.lane != null &&
                        (s.params.cutoffNsr - s.lane!.cutoffNsr).abs() < 0.05,
                    onTap: () => s.applyCutoffCriterion('lane'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _FormulaBox(session: s),

        const SizedBox(height: 18),
        const SectionTitle('Consecuencia inmediata'),
        const SizedBox(height: 10),
        _StatsGrid(stats: stats, session: s),

        const SizedBox(height: 18),
        const SectionTitle('Curva ley-tonelaje',
            subtitle: 'Menos toneladas, mejor ley. Ese es el intercambio.'),
        const SizedBox(height: 8),
        GradeTonnageChart(
            points: s.gradeTonnageCurve(), currentCutoff: s.params.cutoffNsr),

        const SizedBox(height: 20),
        const SectionTitle('Variables del escenario'),
        const SizedBox(height: 8),
        ...s.mineCase.metals.map((m) {
          final range =
              s.mineCase.priceRange[m.symbol] ?? [m.price * 0.6, m.price * 1.6];
          return _SliderRow(
            label: 'Precio ${m.name}',
            value: s.params.prices[m.symbol] ?? m.price,
            min: range[0],
            max: range[1],
            display:
                '${Fmt.dollars(s.params.prices[m.symbol] ?? m.price)} ${m.priceSuffix}',
            onChanged: (v) => s.setPrice(m.symbol, v),
          );
        }),
        ...s.mineCase.metals.map((m) => _SliderRow(
              label: 'Recuperación ${m.symbol}',
              value: s.params.recoveries[m.symbol] ?? m.recovery,
              min: 0.50,
              max: 0.98,
              display: Fmt.pct(s.params.recoveries[m.symbol] ?? m.recovery),
              onChanged: (v) => s.setRecovery(m.symbol, v),
            )),
        _SliderRow(
          label: 'Costo de minado',
          value: s.params.costs.mining,
          min: s.mineCase.costs.mining * 0.5,
          max: s.mineCase.costs.mining * 1.8,
          display: '${Fmt.dollars(s.params.costs.mining)} /t',
          onChanged: (v) => s.setCosts(s.params.costs.copyWith(mining: v)),
        ),
        _SliderRow(
          label: 'Costo de planta',
          value: s.params.costs.processing,
          min: s.mineCase.costs.processing * 0.5,
          max: s.mineCase.costs.processing * 1.8,
          display: '${Fmt.dollars(s.params.costs.processing)} /t',
          onChanged: (v) => s.setCosts(s.params.costs.copyWith(processing: v)),
        ),
        _SliderRow(
          label: 'Tasa de descuento',
          value: s.params.discountRate,
          min: 0.05,
          max: 0.18,
          display: Fmt.pct(s.params.discountRate),
          onChanged: s.setDiscountRate,
        ),

        const SizedBox(height: 18),
        const SectionTitle('Escenarios',
            subtitle: 'Un plan evaluado en un solo escenario es una apuesta.'),
        const SizedBox(height: 8),
        ...scenarios.map((sc) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Haptics.select();
                  s.applyNamedScenario(sc);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceAlt),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sc.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(sc.description,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textDim,
                              height: 1.35)),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _FormulaBox extends StatelessWidget {
  final SessionViewModel session;

  const _FormulaBox({required this.session});

  @override
  Widget build(BuildContext context) {
    final m = session.activeMetals.first;
    final factor =
        m.priceUnit == PriceUnit.perPound ? '22,0462' : '1 / 31,1035';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FÓRMULA EN USO',
              style: TextStyle(fontSize: 10, color: AppColors.textDim)),
          const SizedBox(height: 6),
          Text(
            'ley de corte = Costo (\$/t) ÷ ( $factor × Precio neto × Recuperación )',
            style: const TextStyle(
                fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'La recuperación DIVIDE. Si la planta recupera menos, hace falta '
            'más ley para pagar el mismo costo, así que la ley de corte sube y '
            'las reservas caen. Es el error más frecuente del tema.',
            style:
                TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Precio neto = precio × pagabilidad − cargos de tratamiento '
            '(${Fmt.pct(m.payability, decimals: 1)} y '
            '${Fmt.dollars(m.deduction)} ${m.priceSuffix} en este caso).',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textDim, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CriterionChip extends StatelessWidget {
  final String label;
  final double value;
  final Metal metal;
  final bool poly;
  final bool active;
  final VoidCallback onTap;

  const _CriterionChip({
    required this.label,
    required this.value,
    required this.metal,
    required this.poly,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = poly
        ? '${Fmt.dollars(value)}/t'
        : Fmt.grade(
            CutoffCalculator.nsrToGrade(value, metal), metal.gradeSuffix);
    return InkWell(
      onTap: () {
        Haptics.select();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.ore.withValues(alpha: 0.20)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AppColors.ore : Colors.transparent),
        ),
        child: Text('$label  ·  $text', style: const TextStyle(fontSize: 11.5)),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(display,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ore)),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// =====================================================================
// TAB 3 — Programación de producción
// =====================================================================
class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final r = s.result;
    final primary = s.activeMetals.first;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          14, 14, 14, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        const SectionTitle('Secuencia de extracción',
            subtitle: 'Arrastra para reordenar. El sistema no optimiza por ti: '
                'valida lo que decides.'),
        const SizedBox(height: 10),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: true,
          onReorder: s.reorderPhases,
          children: [
            for (int idx = 0; idx < s.params.phaseOrder.length; idx++)
              _phaseTile(s, idx),
          ],
        ),
        const SizedBox(height: 14),
        _SliderRow(
          label: 'Alimentación a planta',
          value: s.params.throughput,
          min: s.mineCase.millCapacity * 0.35,
          max: s.mineCase.millCapacity,
          display: '${Fmt.mt(s.params.throughput)} /año',
          onChanged: s.setThroughput,
        ),
        Text(
          'Capacidad instalada: ${Fmt.mt(s.mineCase.millCapacity)}/año · '
          'Capacidad de mina: ${Fmt.mt(s.mineCase.mineCapacity)}/año',
          style: const TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
        const SizedBox(height: 16),
        if (r.issues.isNotEmpty) ...[
          const SectionTitle('Validación del plan'),
          const SizedBox(height: 8),
          ...r.issues.map((i) => _IssueTile(issue: i)),
          const SizedBox(height: 12),
        ],
        SectionTitle('Programa de producción',
            subtitle: 'Vida de mina: ${r.lifeYears} años'),
        const SizedBox(height: 8),
        _ScheduleTable(result: r, symbol: primary.symbol, metal: primary),
      ],
    );
  }

  Widget _phaseTile(SessionViewModel s, int position) {
    final idx = s.params.phaseOrder[position];
    final phase = s.mineCase.phases.firstWhere((p) => p.index == idx);
    final blocked = phase.requires
        .any((req) => s.params.phaseOrder.indexOf(req) > position);
    return Container(
      key: ValueKey('phase_$idx'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: blocked ? AppColors.negative : AppColors.surfaceAlt),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor:
                blocked ? AppColors.negative : AppColors.surfaceAlt,
            child:
                Text('${position + 1}', style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phase.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  blocked
                      ? 'Sin acceso físico en esta posición'
                      : phase.description,
                  style: TextStyle(
                      fontSize: 11,
                      color: blocked ? AppColors.negative : AppColors.textDim),
                ),
              ],
            ),
          ),
          const Icon(Icons.drag_handle, color: AppColors.textDim, size: 18),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final ScheduleIssue issue;

  const _IssueTile({required this.issue});

  @override
  Widget build(BuildContext context) {
    final color = issue.severity == IssueSeverity.error
        ? AppColors.negative
        : issue.severity == IssueSeverity.warning
            ? AppColors.warning
            : AppColors.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(issue.title,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 4),
          Text(issue.detail,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textDim, height: 1.4)),
        ],
      ),
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  final ScheduleResult result;
  final String symbol;
  final Metal metal;

  const _ScheduleTable({
    required this.result,
    required this.symbol,
    required this.metal,
  });

  @override
  Widget build(BuildContext context) {
    if (result.periods.isEmpty) {
      return const _InfoBox(
        title: 'Sin programa',
        body: 'No hay material sobre la ley de corte con los parámetros '
            'actuales. Baja la ley de corte o revisa el escenario de precios.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 38,
        columnSpacing: 18,
        columns: [
          const DataColumn(label: Text('Año', style: TextStyle(fontSize: 11))),
          const DataColumn(
              label: Text('Mineral', style: TextStyle(fontSize: 11))),
          const DataColumn(
              label: Text('Desmonte', style: TextStyle(fontSize: 11))),
          DataColumn(
              label: Text('Ley $symbol', style: const TextStyle(fontSize: 11))),
          const DataColumn(
              label: Text('Ingreso', style: TextStyle(fontSize: 11))),
          const DataColumn(
              label: Text('Costo/t', style: TextStyle(fontSize: 11))),
          const DataColumn(label: Text('FCL', style: TextStyle(fontSize: 11))),
        ],
        rows: result.periods
            .map((p) => DataRow(cells: [
                  DataCell(
                      Text('${p.year}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(Fmt.kt(p.oreTonnes),
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text(Fmt.kt(p.wasteTonnes),
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text(
                      Fmt.grade(p.feedGrades[symbol] ?? 0, metal.gradeSuffix),
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text(Fmt.money(p.revenue),
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text(Fmt.dollars(p.unitCost),
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text(Fmt.money(p.freeCashFlow),
                      style: TextStyle(
                          fontSize: 11,
                          color: p.freeCashFlow >= 0
                              ? AppColors.positive
                              : AppColors.negative))),
                ]))
            .toList(),
      ),
    );
  }
}

// =====================================================================
// TAB 4 — Evaluación económica
// =====================================================================
class _EconomicsTab extends ConsumerStatefulWidget {
  const _EconomicsTab();

  @override
  ConsumerState<_EconomicsTab> createState() => _EconomicsTabState();
}

class _EconomicsTabState extends ConsumerState<_EconomicsTab> {
  List<SensitivityBar>? _bars;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final r = s.result;
    final primary = s.activeMetals.first;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          14, 14, 14, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        const SectionTitle('Indicadores del proyecto'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            KpiTile(
              label: 'VAN @ ${Fmt.pct(s.params.discountRate, decimals: 0)}',
              value: Fmt.money(r.npv),
              valueColor: r.npv >= 0 ? AppColors.positive : AppColors.negative,
            ),
            KpiTile(
              label: 'TIR',
              value: r.irr == null ? '—' : Fmt.pct(r.irr!),
              hint: r.irr == null ? 'no recupera la inversión' : null,
              valueColor: r.irr != null && r.irr! >= s.params.discountRate
                  ? AppColors.positive
                  : AppColors.negative,
            ),
            KpiTile(
                label: 'PAYBACK DESCONTADO', value: Fmt.years(r.paybackYears)),
            KpiTile(
                label: 'AISC',
                value: '${Fmt.dollars(r.aisc)} /${primary.containedUnit}'),
            KpiTile(label: 'CAPEX', value: Fmt.money(r.capex)),
            KpiTile(label: 'VIDA DE MINA', value: '${r.lifeYears} años'),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('Flujo de caja',
            subtitle: 'Barras: flujo anual. Línea: VAN acumulado.'),
        const SizedBox(height: 8),
        CashflowChart(result: r, discountRate: s.params.discountRate),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: SectionTitle('Sensibilidad',
                  subtitle: '¿Qué variable mueve más el VAN?'),
            ),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () async {
                      Haptics.tap();
                      setState(() => _busy = true);
                      await Future<void>.delayed(
                          const Duration(milliseconds: 30));
                      final bars = s.tornado();
                      if (mounted) {
                        Haptics.success();
                        setState(() {
                          _bars = bars;
                          _busy = false;
                        });
                      }
                    },
              child: Text(_busy ? 'Calculando…' : 'Calcular'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_bars != null) ...[
          TornadoChart(bars: _bars!),
          const SizedBox(height: 6),
          Text(
            'La variable con mayor amplitud es "${_bars!.first.variable}". '
            'Ese es el riesgo que tendrías que gestionar primero: con '
            'contratos, coberturas o rediseño operativo.',
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textDim, height: 1.4),
          ),
        ] else
          const Text(
            'El tornado corre el plan completo diez veces. Pulsa Calcular '
            'cuando tu plan esté estable.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textDim),
          ),
        const SizedBox(height: 22),
        const SectionTitle('Exportar',
            subtitle:
                'CSV con separador ";" listo para abrir en Excel. Se copia '
                'al portapapeles: funciona sin conexión.'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Programa'),
                onPressed: () => _copy(
                  context,
                  CsvExporter.productionSchedule(
                    mineCase: s.mineCase,
                    params: s.params,
                    result: r,
                  ),
                  'Programa de producción copiado',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.grid_on_outlined, size: 18),
                label: const Text('Bloques'),
                onPressed: () => _copy(
                  context,
                  CsvExporter.blockModel(
                      mineCase: s.mineCase, params: s.params),
                  'Modelo de bloques copiado',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _copy(BuildContext context, String data, String message) {
    Clipboard.setData(ClipboardData(text: data));
    Haptics.success();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// =====================================================================
// TAB 5 — Tutor
// =====================================================================
class _TutorTab extends ConsumerWidget {
  const _TutorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final score = s.score();

    return ListView(
      padding: EdgeInsets.fromLTRB(
          14, 14, 14, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceAlt),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(score.role,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ore)),
                  Text('${score.total.toStringAsFixed(0)} / 100',
                      style: const TextStyle(fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              _ScoreBar('Valor económico', score.valueScore, 35),
              _ScoreBar(
                  'Cumplimiento de restricciones', score.complianceScore, 25),
              _ScoreBar('Robustez ante escenarios', score.robustnessScore, 15),
              _ScoreBar('Comprensión conceptual', score.understandingScore, 25),
              const SizedBox(height: 8),
              Text(score.roleHint,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textDim, height: 1.4)),
              const SizedBox(height: 8),
              const Text(
                'El puntaje no premia solo el VAN. Un plan que maximiza VAN '
                'rompiendo restricciones o sin justificación no aprueba: eso '
                'es exactamente lo que la planificación real castiga.',
                style: TextStyle(
                    fontSize: 10.5, color: AppColors.textDim, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Revisión de tu plan',
            subtitle: 'Diagnóstico local, sin conexión.'),
        const SizedBox(height: 10),
        ...s.findings.map((f) => _FindingCard(finding: f)),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _ScoreBar(this.label, this.value, this.max);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value:
                    max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ore),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${value.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final TutorFinding finding;

  const _FindingCard({required this.finding});

  @override
  Widget build(BuildContext context) {
    final color = switch (finding.level) {
      FindingLevel.critical => AppColors.negative,
      FindingLevel.warning => AppColors.warning,
      FindingLevel.insight => AppColors.info,
      FindingLevel.praise => AppColors.positive,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(finding.title,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          Text(finding.explanation,
              style: const TextStyle(fontSize: 12, height: 1.45)),
          if (finding.question != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.help_outline,
                      size: 15, color: AppColors.textDim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(finding.question!,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text('Concepto: ${finding.concept}',
              style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String body;

  const _InfoBox({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(body,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textDim, height: 1.45)),
        ],
      ),
    );
  }
}
