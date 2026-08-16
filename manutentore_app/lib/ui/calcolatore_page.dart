import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manutentore_core/manutentore_core.dart';

import '../state/impostazioni.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets/campo_input.dart';
import 'widgets/targa_risultato.dart';

/// Una sola schermata per tutti i calcolatori.
///
/// Non conosce nessuna formula: legge [Calculator.fields], costruisce il form
/// e ricalcola a ogni battuta. Aggiungere un calcolatore al registro lo rende
/// disponibile qui senza toccare una riga di UI.
class CalcolatorePage extends StatefulWidget {
  const CalcolatorePage({required this.calcolatore, super.key});

  final Calculator calcolatore;

  @override
  State<CalcolatorePage> createState() => _CalcolatorePageState();
}

class _CalcolatorePageState extends State<CalcolatorePage> {
  late final Map<String, Object?> _valori;
  late final Map<String, TextEditingController> _controller;

  CalcResult? _risultato;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _valori = {
      for (final f in widget.calcolatore.fields) f.key: f.initial,
    };
    _controller = {
      for (final f in widget.calcolatore.fields)
        if (f.type == FieldType.number)
          f.key: TextEditingController(text: _formatoIniziale(f.initial)),
    };
    _ricalcola();
  }

  @override
  void dispose() {
    for (final c in _controller.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _formatoIniziale(Object? v) {
    if (v is! num) return '';
    return v == v.roundToDouble() && v.abs() < 1e9
        ? v.toInt().toString()
        : v.toString();
  }

  void _ricalcola() {
    try {
      final r = widget.calcolatore.compute(
        Inputs(_valori, widget.calcolatore.fields),
      );
      _risultato = r;
      _errore = null;
    } on CalcException catch (e) {
      _risultato = null;
      _errore = e.message;
    } on Object catch (e) {
      _risultato = null;
      _errore = 'Calcolo non riuscito: $e';
    }
  }

  void _aggiorna(String chiave, Object? valore) {
    setState(() {
      _valori[chiave] = valore;
      _ricalcola();
    });
  }

  void _reimposta() {
    setState(() {
      for (final f in widget.calcolatore.fields) {
        _valori[f.key] = f.initial;
        _controller[f.key]?.text = _formatoIniziale(f.initial);
      }
      _ricalcola();
    });
  }

  void _copia() {
    final r = _risultato;
    if (r == null) return;
    final buffer = StringBuffer()
      ..writeln(widget.calcolatore.name)
      ..writeln('');
    for (final f in widget.calcolatore.fields) {
      buffer.writeln('${f.label}: ${_valori[f.key] ?? "-"} ${f.unit}'.trim());
    }
    buffer.writeln('');
    for (final l in r.lines) {
      buffer.writeln(l.toString());
    }
    if (r.verdict != null) buffer.writeln('\n${r.verdict}');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calcolo copiato')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final impostazioni = ImpostazioniScope.of(context);
    final studente = impostazioni.isStudente;
    final calc = widget.calcolatore;
    final c = context.c;

    return Scaffold(
      appBar: AppBar(
        title: Text(calc.name),
        actions: [
          IconButton(
            tooltip: impostazioni.isPreferito(calc.id)
                ? 'Togli dai preferiti'
                : 'Aggiungi ai preferiti',
            icon: Icon(
              impostazioni.isPreferito(calc.id)
                  ? Icons.star
                  : Icons.star_border,
              color: impostazioni.isPreferito(calc.id) ? T.giallo : null,
            ),
            onPressed: () => impostazioni.togglePreferito(calc.id),
          ),
          IconButton(
            tooltip: 'Copia il calcolo',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _risultato == null ? null : _copia,
          ),
          IconButton(
            tooltip: 'Reimposta i valori',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reimposta,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(T.s4, T.s2, T.s4, T.s6),
        children: [
          Text(
            calc.subtitle,
            style: TextStyle(color: c.muted, fontSize: 14, height: 1.35),
          ),
          if (studente && calc.theory != null) ...[
            const SizedBox(height: T.s4),
            _NotaDidattica(testo: calc.theory!),
          ],
          const SizedBox(height: T.s5),
          for (final f in calc.fields) ...[
            CampoInput(
              spec: f,
              valore: _valori[f.key],
              controller: _controller[f.key],
              mostraAiuto: studente,
              onChanged: (v) => _aggiorna(f.key, v),
            ),
            const SizedBox(height: T.s3),
          ],
          const SizedBox(height: T.s3),
          if (_errore != null)
            _Errore(testo: _errore!)
          else if (_risultato != null)
            TargaRisultato(
              risultato: _risultato!,
              riferimenti: calc.references,
              mostraAvvertenze: studente,
            ),
        ],
      ),
    );
  }
}

class _NotaDidattica extends StatelessWidget {
  const _NotaDidattica({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(T.s3),
      decoration: BoxDecoration(
        border: const Border(left: BorderSide(color: T.giallo, width: 3)),
        color: c.plate,
      ),
      child: Text(
        testo,
        style: TextStyle(fontSize: 13.5, height: 1.45, color: c.muted),
      ),
    );
  }
}

class _Errore extends StatelessWidget {
  const _Errore({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(T.s4),
      decoration: BoxDecoration(
        color: c.fail.withAlpha(28),
        borderRadius: BorderRadius.circular(T.radius),
        border: Border.all(color: c.fail.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_gmailerrorred_outlined, color: c.fail, size: 20),
          const SizedBox(width: T.s2),
          Expanded(
            child: Text(
              testo,
              style: TextStyle(color: c.fail, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
