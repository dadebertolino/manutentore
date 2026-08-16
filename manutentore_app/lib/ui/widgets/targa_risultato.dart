import 'package:flutter/material.dart';
import 'package:manutentore_core/manutentore_core.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// La targa.
///
/// Elemento firma dell'interfaccia: il risultato e' presentato come la targa
/// dati di una macchina, l'artefatto che il manutentore gia' sa leggere.
/// Valori primari incisi grandi, banda di verdetto stampigliata in testa,
/// riferimenti normativi punzonati in fondo.
class TargaRisultato extends StatelessWidget {
  const TargaRisultato({
    required this.risultato,
    required this.riferimenti,
    this.mostraAvvertenze = true,
    super.key,
  });

  final CalcResult risultato;
  final List<String> riferimenti;
  final bool mostraAvvertenze;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final primari = risultato.lines.where((l) => l.primary).toList();
    final secondari = risultato.lines.where((l) => !l.primary).toList();

    return Container(
      decoration: BoxDecoration(
        color: c.plate,
        borderRadius: BorderRadius.circular(T.radius),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (risultato.verdict != null)
            _BandaVerdetto(
              testo: risultato.verdict!,
              severita: risultato.verdictSeverity,
            ),
          Padding(
            padding: const EdgeInsets.all(T.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in primari) ...[
                  _ValorePrimario(riga: l),
                  const SizedBox(height: T.s3),
                ],
                if (primari.isNotEmpty && secondari.isNotEmpty) ...[
                  Divider(color: c.line),
                  const SizedBox(height: T.s2),
                ],
                for (final l in secondari) _RigaSecondaria(riga: l),
              ],
            ),
          ),
          if (mostraAvvertenze && risultato.warnings.isNotEmpty)
            _Avvertenze(testi: risultato.warnings),
          if (riferimenti.isNotEmpty) _Punzonatura(riferimenti: riferimenti),
        ],
      ),
    );
  }
}

Color coloreSeverita(BuildContext context, Severity s) => switch (s) {
      Severity.ok => context.c.ok,
      Severity.warn => context.c.warn,
      Severity.fail => context.c.fail,
      Severity.neutral => context.c.muted,
    };

class _BandaVerdetto extends StatelessWidget {
  const _BandaVerdetto({required this.testo, required this.severita});

  final String testo;
  final Severity severita;

  @override
  Widget build(BuildContext context) {
    final colore = coloreSeverita(context, severita);
    final icona = switch (severita) {
      Severity.ok => Icons.check_circle_outline,
      Severity.warn => Icons.error_outline,
      Severity.fail => Icons.cancel_outlined,
      Severity.neutral => Icons.info_outline,
    };
    return Container(
      color: colore.withAlpha(36),
      padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
      child: Row(
        children: [
          Icon(icona, size: 20, color: colore),
          const SizedBox(width: T.s2),
          Expanded(
            child: Text(
              testo,
              style: TextStyle(
                color: colore,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValorePrimario extends StatelessWidget {
  const _ValorePrimario({required this.riga});

  final ResultLine riga;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colore = riga.severity == Severity.neutral
        ? Theme.of(context).colorScheme.onSurface
        : coloreSeverita(context, riga.severity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          riga.label.toUpperCase(),
          style: TextStyle(
            color: c.muted,
            fontSize: 11,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: SelectableText(
                riga.value,
                style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  height: 1.05,
                  color: colore,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (riga.unit.isNotEmpty) ...[
              const SizedBox(width: T.s2),
              Text(
                riga.unit,
                style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: 15,
                  color: c.muted,
                ),
              ),
            ],
          ],
        ),
        if (riga.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              riga.note!,
              style: TextStyle(color: c.muted, fontSize: 12, height: 1.3),
            ),
          ),
      ],
    );
  }
}

class _RigaSecondaria extends StatelessWidget {
  const _RigaSecondaria({required this.riga});

  final ResultLine riga;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colore = riga.severity == Severity.neutral
        ? Theme.of(context).colorScheme.onSurface
        : coloreSeverita(context, riga.severity);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  riga.label,
                  style: TextStyle(fontSize: 14, color: c.muted, height: 1.3),
                ),
              ),
              const SizedBox(width: T.s3),
              SelectableText(
                riga.unit.isEmpty ? riga.value : '${riga.value} ${riga.unit}',
                style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: 14,
                  color: colore,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (riga.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                riga.note!,
                style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avvertenze extends StatelessWidget {
  const _Avvertenze({required this.testi});

  final List<String> testi;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(T.s4, T.s3, T.s4, T.s3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in testi)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('—', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  const SizedBox(width: T.s2),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Punzonatura extends StatelessWidget {
  const _Punzonatura({required this.riferimenti});

  final List<String> riferimenti;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(T.s4, T.s2, T.s4, T.s3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Text(
        riferimenti.join('  ·  '),
        style: TextStyle(
          fontFamily: T.mono,
          fontSize: 10.5,
          color: c.muted,
          letterSpacing: 0.3,
          height: 1.4,
        ),
      ),
    );
  }
}
