import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:manutentore_core/manutentore_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Costruisce il rapportino di un calcolo, pronto per il foglio di
/// condivisione.
///
/// **Il PDF non e' la app su carta.** In app il fondo e' scuro perche' si
/// lavora in cabina; qui il fondo e' la carta, e una targa nera sarebbe
/// toner sprecato e illeggibile in fotocopia. Restano invece le due cose che
/// portano significato: il **Mono per le cifre** e i **colori del verdetto**,
/// che dicono cosa succede all'impianto. Il giallo non compare: marca cio' che
/// l'utente tocca, e su un foglio non si tocca niente.
///
/// Genera i byte e basta: chi li condivide, e come, non lo decide questo file.
class Rapporto {
  Rapporto._();

  /// I font sono gli stessi della app, letti da `assets/fonts/`.
  ///
  /// Mai `PdfGoogleFonts`: scaricherebbe da rete, e la promessa e' che l'app
  /// non ne faccia (HANDOFF §5). C'e' un controllo che lo impedisce.
  static _Caratteri? _caratteri;

  static Future<_Caratteri> _caricaCaratteri() async {
    if (_caratteri != null) return _caratteri!;
    Future<pw.Font> leggi(String nome) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$nome.ttf'));
    _caratteri = _Caratteri(
      testo: await leggi('IBMPlexSans-Regular'),
      forte: await leggi('IBMPlexSans-SemiBold'),
      cifre: await leggi('IBMPlexMono-Regular'),
      cifreForti: await leggi('IBMPlexMono-Medium'),
    );
    return _caratteri!;
  }

  static Future<Uint8List> genera({
    required Calculator calcolatore,
    required Map<String, Object?> valori,
    required CalcResult risultato,
    required DateTime quando,
  }) async {
    final f = await _caricaCaratteri();
    final documento = pw.Document(
      title: calcolatore.name,
      author: 'Breviario del manutentore',
      creator: 'Breviario del manutentore',
    );

    documento.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
        theme: pw.ThemeData.withFont(base: f.testo, bold: f.forte),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _intestazione(calcolatore, quando, f),
            pw.SizedBox(height: 18),
            _sezione('DATI INSERITI'),
            pw.SizedBox(height: 6),
            _tabellaInput(calcolatore, valori, f),
            pw.SizedBox(height: 18),
            _sezione('RISULTATO'),
            pw.SizedBox(height: 6),
            if (risultato.verdict != null) ...[
              _bandaVerdetto(risultato, f),
              pw.SizedBox(height: 8),
            ],
            _tabellaRisultato(risultato, f),
            if (risultato.warnings.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              _avvertenze(risultato, f),
            ],
            pw.Spacer(),
            _piede(calcolatore, f),
          ],
        ),
      ),
    );
    return documento.save();
  }

  /// Nome del file. Finisce nel foglio di condivisione e poi nella cartella di
  /// chi lo riceve, quindi porta gia' con se' cosa e' e di quando.
  static String nomeFile(Calculator calcolatore, DateTime quando) {
    final titolo = calcolatore.name
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâä]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final d = quando;
    final data =
        '${d.year}${_due(d.month)}${_due(d.day)}-${_due(d.hour)}${_due(d.minute)}';
    return 'breviario-$titolo-$data.pdf';
  }

  static String _due(int n) => n.toString().padLeft(2, '0');

  static pw.Widget _intestazione(
    Calculator calcolatore,
    DateTime quando,
    _Caratteri f,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'BREVIARIO DEL MANUTENTORE',
            style: pw.TextStyle(font: f.cifre, fontSize: 8, color: _grigio),
          ),
          pw.Text(
            '${_due(quando.day)}/${_due(quando.month)}/${quando.year}  '
            '${_due(quando.hour)}:${_due(quando.minute)}',
            style: pw.TextStyle(font: f.cifre, fontSize: 8, color: _grigio),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        calcolatore.name,
        style: pw.TextStyle(font: f.forte, fontSize: 20),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        calcolatore.subtitle,
        style: const pw.TextStyle(fontSize: 10.5, color: _grigio),
      ),
      pw.SizedBox(height: 10),
      pw.Divider(height: 1, color: _linea),
    ],
  );

  static pw.Widget _sezione(String titolo) => pw.Text(
    titolo,
    style: const pw.TextStyle(fontSize: 8, color: _grigio, letterSpacing: 1),
  );

  static pw.Widget _tabellaInput(
    Calculator calcolatore,
    Map<String, Object?> valori,
    _Caratteri f,
  ) => pw.Column(
    children: [
      for (final campo in calcolatore.fields)
        _riga(
          campo.label,
          _valoreLeggibile(campo, valori[campo.key]),
          campo.unit,
          f,
        ),
    ],
  );

  static pw.Widget _tabellaRisultato(CalcResult risultato, _Caratteri f) =>
      pw.Column(
        children: [
          for (final l in risultato.lines)
            _riga(
              l.label,
              l.value,
              l.unit,
              f,
              forte: l.primary,
              colore: _coloreSeverita(l.severity),
              nota: l.note,
            ),
        ],
      );

  static pw.Widget _riga(
    String etichetta,
    String valore,
    String unita,
    _Caratteri f, {
    bool forte = false,
    PdfColor? colore,
    String? nota,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                etichetta,
                style: const pw.TextStyle(fontSize: 10, color: _grigio),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              unita.isEmpty ? valore : '$valore $unita',
              style: pw.TextStyle(
                font: forte ? f.cifreForti : f.cifre,
                fontSize: forte ? 12 : 10,
                color: colore ?? PdfColors.black,
              ),
            ),
          ],
        ),
        if (nota != null)
          pw.Text(nota, style: const pw.TextStyle(fontSize: 8, color: _grigio)),
      ],
    ),
  );

  static pw.Widget _bandaVerdetto(CalcResult risultato, _Caratteri f) {
    final colore =
        _coloreSeverita(risultato.verdictSeverity) ?? PdfColors.black;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        // Tinta leggera invece del fondo pieno: in fotocopia in bianco e nero
        // un blocco saturo diventa una macchia e il testo sparisce.
        color: _tinta(colore),
        border: pw.Border(left: pw.BorderSide(color: colore, width: 3)),
      ),
      child: pw.Text(
        risultato.verdict!,
        style: pw.TextStyle(font: f.forte, fontSize: 12, color: colore),
      ),
    );
  }

  static pw.Widget _avvertenze(CalcResult risultato, _Caratteri f) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sezione('AVVERTENZE'),
      pw.SizedBox(height: 4),
      for (final a in risultato.warnings)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text('- $a', style: const pw.TextStyle(fontSize: 9)),
        ),
    ],
  );

  static pw.Widget _piede(Calculator calcolatore, _Caratteri f) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Divider(height: 1, color: _linea),
      pw.SizedBox(height: 6),
      if (calcolatore.references.isNotEmpty)
        pw.Text(
          calcolatore.references.join('  ·  '),
          style: pw.TextStyle(font: f.cifre, fontSize: 8, color: _grigio),
        ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Ordine di grandezza verificabile: non sostituisce la norma né il '
        'progetto firmato da un tecnico abilitato. Calcolato e salvato sul '
        'telefono, senza inviare nulla in rete.',
        style: const pw.TextStyle(fontSize: 7.5, color: _grigio),
      ),
    ],
  );

  /// Per i `select` la chiave salvata non e' quello che l'utente ha letto a
  /// schermo: sul rapportino va l'etichetta, non `G2-rigido`.
  static String _valoreLeggibile(FieldSpec campo, Object? valore) {
    if (campo.type == FieldType.select) {
      final scelta = valore is String ? valore : campo.initial as String?;
      for (final o in campo.options) {
        if (o.value == scelta) return o.label;
      }
      return scelta ?? '-';
    }
    if (campo.type == FieldType.toggle) {
      return (valore is bool ? valore : campo.initial == true) ? 'si' : 'no';
    }
    if (valore is num) {
      return valore == valore.roundToDouble() && valore.abs() < 1e9
          ? valore.toInt().toString()
          : valore.toString();
    }
    return valore?.toString() ?? '-';
  }

  static PdfColor? _coloreSeverita(Severity s) => switch (s) {
    Severity.ok => const PdfColor.fromInt(0xFF2E7D46),
    Severity.warn => const PdfColor.fromInt(0xFFB35A12),
    Severity.fail => const PdfColor.fromInt(0xFFB32B24),
    Severity.neutral => null,
  };

  /// Schiarisce il colore mescolandolo col bianco.
  ///
  /// Non si usa il canale alfa: nel PDF non viene composto sullo sfondo come
  /// ci si aspetterebbe, e il risultato era una banda a tinta piena con sopra
  /// il testo dello stesso colore, cioe' un verdetto invisibile. I test non se
  /// ne accorgevano: i byte erano un PDF valido lo stesso.
  static PdfColor _tinta(PdfColor c) => PdfColor(
    c.red + (1 - c.red) * 0.88,
    c.green + (1 - c.green) * 0.88,
    c.blue + (1 - c.blue) * 0.88,
  );

  static const _grigio = PdfColor.fromInt(0xFF5C666F);
  static const _linea = PdfColor.fromInt(0xFFC6CDD3);
}

class _Caratteri {
  const _Caratteri({
    required this.testo,
    required this.forte,
    required this.cifre,
    required this.cifreForti,
  });

  final pw.Font testo;
  final pw.Font forte;
  final pw.Font cifre;
  final pw.Font cifreForti;
}
