import 'electrical.dart';
import 'mechanical.dart';
import 'model.dart';

/// Registro unico dei calcolatori disponibili.
///
/// Aggiungere un calcolatore = implementare [Calculator] e inserirlo qui.
/// La UI non va toccata.
class Registro {
  static const List<Calculator> tutti = [
    // Elettrico
    CadutaDiTensione(),
    PortataCavo(),
    CoordinamentoProtezione(),
    AnelloDiGuasto(),
    Rifasamento(),
    MotoreAsincrono(),
    SegnaleAnalogico(),
    TermoresistenzaPt(),
    // Meccanico
    CoppiaSerraggio(),
    ForoMaschiatura(),
    VitaCuscinetto(),
    FrequenzeCuscinetto(),
    SeveritaVibrazioni(),
    CilindroPneumatico(),
    CoefficienteKv(),
    TrasmissionePulegge(),
    PotenzaCoppiaVelocita(),
  ];

  static Calculator byId(String id) => tutti.firstWhere(
        (c) => c.id == id,
        orElse: () => throw ArgumentError('Calcolatore "$id" non registrato'),
      );

  static List<Calculator> byDomain(Domain d) =>
      tutti.where((c) => c.domain == d).toList();

  /// Ricerca tollerante su nome, sottotitolo e tag.
  static List<Calculator> cerca(String query) {
    final q = _normalizza(query);
    if (q.isEmpty) return tutti;
    final termini = q.split(RegExp(r'\s+'));
    final risultati = <Calculator, int>{};

    for (final c in tutti) {
      final nome = _normalizza(c.name);
      final testo = _normalizza('${c.name} ${c.subtitle} ${c.tags.join(" ")}');
      var punteggio = 0;
      for (final t in termini) {
        if (nome.startsWith(t)) {
          punteggio += 10;
        } else if (nome.contains(t)) {
          punteggio += 6;
        } else if (testo.contains(t)) {
          punteggio += 2;
        } else {
          punteggio = -1000;
        }
      }
      if (punteggio > 0) risultati[c] = punteggio;
    }

    final ordinati = risultati.keys.toList()
      ..sort((a, b) {
        final d = risultati[b]!.compareTo(risultati[a]!);
        return d != 0 ? d : a.name.compareTo(b.name);
      });
    return ordinati;
  }

  /// Verifica di integrita': id univoci, chiavi campo univoche, default validi.
  /// Eseguita dai test, non a runtime.
  static List<String> verificaIntegrita() {
    final problemi = <String>[];
    final visti = <String>{};
    for (final c in tutti) {
      if (!visti.add(c.id)) problemi.add('id duplicato: ${c.id}');
      final chiavi = <String>{};
      for (final f in c.fields) {
        if (!chiavi.add(f.key)) {
          problemi.add('${c.id}: campo duplicato "${f.key}"');
        }
        if (f.type == FieldType.number && f.initial == null) {
          problemi.add('${c.id}: campo "${f.key}" senza valore iniziale');
        }
        if (f.type == FieldType.select && f.options.isEmpty) {
          problemi.add('${c.id}: select "${f.key}" senza opzioni');
        }
      }
      try {
        final r = c.compute(Inputs.defaults(c.fields));
        if (r.lines.isEmpty) problemi.add('${c.id}: nessun risultato');
      } on Object catch (e) {
        problemi.add('${c.id}: i default non calcolano ($e)');
      }
    }
    return problemi;
  }

  static String _normalizza(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
      .trim();
}
