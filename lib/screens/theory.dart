import 'package:flutter/material.dart';

import '../core/ui.dart';

/// Los límites del modelo son CONTENIDO, no un descargo legal escondido al
/// final. Un estudiante que sale creyendo que existe "un" pit óptimo aprendió
/// algo peor que nada.
class TheoryScreen extends StatelessWidget {
  const TheoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conceptos y límites')),
      // El AppBar ya descuenta la barra de estado. Lo que falta es el borde
      // inferior: sin sumar el inset del sistema, la barra de gestos tapa el
      // final de la lista.
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 30 + MediaQuery.paddingOf(context).bottom),
        children: const [
          _Concept(
            title: 'Ley de corte breakeven',
            formula:
                'ley = Costo total ÷ (factor × Precio neto × Recuperación)',
            body: 'Costo total = minado + procesamiento + G&A. Responde si el '
                'yacimiento en su conjunto paga. El factor de unidades es '
                '22,0462 para leyes en % con precio en \$/lb, y 1/31,1035 para '
                'leyes en g/t con precio en \$/oz.',
          ),
          _Concept(
            title: 'Ley de corte marginal',
            formula:
                'ley = (Procesamiento + G&A) ÷ (factor × Precio neto × Recuperación)',
            body:
                'Excluye el minado porque, en un tajo ya diseñado, ese costo se '
                'incurre igual: el bloque sale del pit vaya a planta o a '
                'botadero. Es la referencia correcta para decidir el DESTINO '
                'de un bloque ya minado. En subterránea el razonamiento cambia, '
                'porque ahí sí puedes decidir no extraerlo.',
          ),
          _Concept(
            title: 'Ley de corte de Lane',
            formula:
                'ley = (Costos incrementales + costo de oportunidad) ÷ valor unitario',
            body: 'El costo de oportunidad es (costos de tiempo + tasa × VAN '
                'remanente) ÷ capacidad del cuello de botella. Procesar una '
                'tonelada pobre hoy ocupa capacidad que podría usar una '
                'tonelada rica. Como el VAN remanente es máximo al inicio y '
                'cae a cero al final, la ley de corte óptima empieza alta y '
                'baja con los años. Esta es la razón técnica de un '
                'comportamiento que suele explicarse mal como "la geología se '
                'empobrece".',
          ),
          _Concept(
            title: 'NSR (Net Smelter Return)',
            formula:
                'NSR = Σ ley × (precio × pagabilidad − cargos) × factor × recuperación',
            body:
                'Con más de un metal no existe "una ley de corte": la decisión '
                'se toma sobre el valor neto por tonelada. La app usa NSR '
                'internamente incluso en los casos monometálicos, y luego lo '
                'convierte a ley para mostrarlo. Por eso el caso polimetálico '
                'muestra la ley de corte directamente en \$/t.',
          ),
          _Concept(
            title: 'VAN, TIR y payback',
            formula: 'VAN = −CAPEX + Σ FCLₜ ÷ (1+i)ᵗ',
            body: 'La TIR es la tasa que anula el VAN; la app la resuelve por '
                'bisección y devuelve "sin valor" cuando el proyecto nunca '
                'recupera la inversión, que es lo correcto: en flujos no '
                'convencionales la TIR puede no existir o ser múltiple.',
          ),
          SizedBox(height: 14),
          _Limits(),
        ],
      ),
    );
  }
}

class _Concept extends StatelessWidget {
  final String title;
  final String formula;
  final String body;

  const _Concept({
    required this.title,
    required this.formula,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bedrock,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(formula,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: AppColors.ore,
                    height: 1.4)),
          ),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textDim, height: 1.5)),
        ],
      ),
    );
  }
}

class _Limits extends StatelessWidget {
  const _Limits();

  @override
  Widget build(BuildContext context) {
    const items = [
      'No existe "el" pit óptimo. Un pit calculado a 3,50 \$/lb es óptimo '
          'solo a ese precio, y además ignora el tiempo: no es óptimo en valor '
          'presente.',
      'Los modelos de bloques son sintéticos y determinísticos. No hay '
          'incertidumbre geológica ni estimación por kriging: en la realidad, '
          'la ley de cada bloque es una estimación con error asociado.',
      'Todo el material se trata como recurso medido. En un proyecto real, '
          'solo los recursos medidos e indicados se convierten en reservas y '
          'pueden sustentar un plan de producción.',
      'El secuenciamiento se valida, no se optimiza. La programación óptima '
          'de bloques es un problema NP-duro que ningún teléfono resuelve.',
      'La fiscalidad está simplificada a una regalía sobre ingreso y un '
          'impuesto plano. No incluye escalas progresivas, depreciación, '
          'arrastre de pérdidas ni participación de trabajadores.',
      'No se modelan dilución ni recuperación minera, que en subterránea '
          'pueden cambiar el resultado de forma decisiva.',
      'No se modelan aspectos ambientales, sociales ni de cierre de mina, '
          'que en la práctica condicionan o cancelan proyectos con VAN '
          'positivo.',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lo que este modelo NO representa',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning)),
          const SizedBox(height: 10),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('· ',
                        style: TextStyle(color: AppColors.warning)),
                    Expanded(
                      child: Text(t,
                          style: const TextStyle(fontSize: 11.5, height: 1.5)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
