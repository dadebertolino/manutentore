import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manutentore_core/manutentore_core.dart';
import 'package:printing/printing.dart';

import '../pdf/rapporto.dart';
import '../state/cronologia.dart';
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
  const CalcolatorePage({
    required this.calcolatore,
    this.valoriIniziali,
    super.key,
  });

  final Calculator calcolatore;

  /// Input da cui ripartire, quando si arriva dalla cronologia. Null significa
  /// "usa i default delle [FieldSpec]".
  final Map<String, Object?>? valoriIniziali;

  @override
  State<CalcolatorePage> createState() => _CalcolatorePageState();
}

class _CalcolatorePageState extends State<CalcolatorePage> {
  late final Map<String, Object?> _valori;
  late final Map<String, TextEditingController> _controller;

  /// Presa in `didChangeDependencies`: in `dispose` il context non e' piu'
  /// interrogabile, ma e' li' che sappiamo che il calcolo e' finito.
  Cronologia? _cronologia;

  CalcResult? _risultato;
  String? _errore;

  /// L'utente ha toccato almeno un campo in questa visita.
  ///
  /// Non basta piu' confrontare i valori con i default: da quando si riapre un
  /// calcolatore sugli ultimi valori usati, i valori sono *quasi sempre*
  /// diversi dai default, e senza questo flag il solo aprire e chiudere una
  /// scheda ne aggiornerebbe la posizione e l'ora in cronologia.
  bool _modificato = false;

  @override
  void initState() {
    super.initState();
    final iniziali = widget.valoriIniziali;
    _valori = {
      for (final f in widget.calcolatore.fields)
        // Solo le chiavi che il calcolatore conosce ancora: una voce di
        // cronologia salvata prima che un campo cambiasse nome non deve
        // trascinarsi dietro valori orfani.
        f.key: iniziali != null && iniziali.containsKey(f.key)
            ? iniziali[f.key]
            : f.initial,
    };
    _controller = {
      for (final f in widget.calcolatore.fields)
        if (f.type == FieldType.number)
          f.key: TextEditingController(text: _formatoIniziale(_valori[f.key])),
    };
    _ricalcola();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cronologia = CronologiaScope.of(context);
  }

  @override
  void dispose() {
    _registraInCronologia();
    for (final c in _controller.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Registra il calcolo quando si lascia la schermata.
  ///
  /// Non a ogni battuta: si ricalcola a ogni carattere digitato, e salvare
  /// ogni passaggio riempirebbe le 50 posizioni con gli stati intermedi di un
  /// solo numero. Uscire dalla schermata e' il momento in cui il calcolo e'
  /// quello che l'utente voleva.
  void _registraInCronologia() {
    final r = _risultato;
    final cronologia = _cronologia;
    if (r == null || cronologia == null) return;
    // Aprire un calcolatore e uscirne senza toccare niente non e' un calcolo.
    if (!_modificato) return;
    final primaria = r.lines.firstWhere(
      (l) => l.primary,
      orElse: () =>
          r.lines.isNotEmpty ? r.lines.first : const ResultLine('', ''),
    );
    cronologia.registra(
      VoceCronologia(
        calcId: widget.calcolatore.id,
        // Nessuna conversione: `CampoInput` emette gia' dei `num`.
        valori: Map<String, Object?>.from(_valori),
        quando: DateTime.now(),
        sintesi: primaria.label.isEmpty ? r.verdict : primaria.toString(),
      ),
    );
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
      _modificato = true;
      _valori[chiave] = valore;
      _ricalcola();
    });
  }

  void _reimposta() {
    setState(() {
      _modificato = true;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Calcolo copiato')));
  }

  /// Genera il rapportino e lo passa al foglio di condivisione del sistema.
  ///
  /// Il PDF non viene caricato da nessuna parte: nasce sul telefono e finisce
  /// dove decide l'utente (HANDOFF §5). `sharePdf` di `printing` usa il foglio
  /// nativo, quindi non serve nessun permesso.
  Future<void> _condividiPdf() async {
    final r = _risultato;
    if (r == null) return;
    final calc = widget.calcolatore;
    final quando = DateTime.now();
    final messaggero = ScaffoldMessenger.of(context);
    try {
      final byte = await Rapporto.genera(
        calcolatore: calc,
        valori: _valori,
        risultato: r,
        quando: quando,
      );
      await Printing.sharePdf(
        bytes: byte,
        filename: Rapporto.nomeFile(calc, quando),
      );
    } on Object catch (e) {
      if (!mounted) return;
      messaggero.showSnackBar(
        SnackBar(content: Text('Rapportino non riuscito: $e')),
      );
    }
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
            tooltip: 'Rapportino PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _risultato == null ? null : _condividiPdf,
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
