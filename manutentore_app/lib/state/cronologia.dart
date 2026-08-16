import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un calcolo gia' fatto, con gli input che lo hanno prodotto.
///
/// In campo lo stesso calcolo si rifa' spesso cambiando una variabile sola:
/// quello che serve non e' rileggere il risultato, e' **ripartire da quegli
/// input**. Per questo la voce porta con se' [valori] e non solo la [sintesi].
@immutable
class VoceCronologia {
  const VoceCronologia({
    required this.calcId,
    required this.valori,
    required this.quando,
    this.sintesi,
  });

  /// Id del calcolatore. E' immutabile per contratto (HANDOFF.md §6), per cui
  /// regge anche fra un aggiornamento e l'altro.
  final String calcId;

  /// Input cosi' come erano al momento del calcolo.
  final Map<String, Object?> valori;

  final DateTime quando;

  /// Riga primaria del risultato, per capire la voce senza riaprirla.
  final String? sintesi;

  /// Stesso calcolatore e stessi input. Serve a non accumulare doppioni.
  bool stessoCalcoloDi(VoceCronologia a) {
    if (a.calcId != calcId || a.valori.length != valori.length) return false;
    for (final e in valori.entries) {
      if (!a.valori.containsKey(e.key)) return false;
      if (a.valori[e.key] != e.value) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => {
    'id': calcId,
    'v': valori,
    't': quando.millisecondsSinceEpoch,
    if (sintesi != null) 's': sintesi,
  };

  /// Ritorna null invece di lanciare: una voce illeggibile (formato vecchio,
  /// prefs manomesse) non deve impedire di aprire l'app.
  static VoceCronologia? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final valori = raw['v'];
    final t = raw['t'];
    if (id is! String || valori is! Map || t is! int) return null;
    return VoceCronologia(
      calcId: id,
      valori: valori.map((k, v) => MapEntry(k.toString(), v)),
      quando: DateTime.fromMillisecondsSinceEpoch(t),
      sintesi: raw['s'] is String ? raw['s'] as String : null,
    );
  }
}

/// Cronologia locale degli ultimi calcoli.
///
/// Stesso pattern dei preferiti in `Impostazioni`: [ChangeNotifier] piu'
/// `shared_preferences`, nessuna dipendenza in piu' e niente che esca dal
/// telefono.
class Cronologia extends ChangeNotifier {
  Cronologia(this._prefs) : _voci = _leggi(_prefs);

  static const _kVoci = 'cronologia';

  /// Oltre questa soglia le voci piu' vecchie cadono.
  static const massimo = 50;

  final SharedPreferences _prefs;
  final List<VoceCronologia> _voci;

  static Future<Cronologia> carica() async =>
      Cronologia(await SharedPreferences.getInstance());

  /// Dalla piu' recente alla piu' vecchia.
  List<VoceCronologia> get voci => List.unmodifiable(_voci);

  bool get isEmpty => _voci.isEmpty;

  /// Registra un calcolo, portandolo in cima.
  ///
  /// Se lo stesso calcolo con gli stessi input c'e' gia', viene spostato in
  /// cima invece di essere duplicato: rifare due volte la stessa verifica non
  /// deve consumare due delle 50 posizioni.
  void registra(VoceCronologia voce) {
    _voci.removeWhere(voce.stessoCalcoloDi);
    _voci.insert(0, voce);
    if (_voci.length > massimo) _voci.removeRange(massimo, _voci.length);
    _salva();
    // La registrazione avviene mentre la schermata di calcolo viene smontata,
    // e in quel momento l'albero dei widget e' bloccato: notificare subito
    // farebbe "markNeedsBuild called when widget tree was locked". Lo stato e'
    // gia' aggiornato in modo sincrono, chi legge `voci` vede il nuovo valore;
    // e' solo la notifica che aspetta la fine dello smontaggio.
    scheduleMicrotask(notifyListeners);
  }

  void rimuovi(VoceCronologia voce) {
    if (!_voci.remove(voce)) return;
    _salva();
    notifyListeners();
  }

  void svuota() {
    if (_voci.isEmpty) return;
    _voci.clear();
    _salva();
    notifyListeners();
  }

  void _salva() {
    _prefs.setStringList(
      _kVoci,
      _voci.map((v) => jsonEncode(v.toJson())).toList(),
    );
  }

  static List<VoceCronologia> _leggi(SharedPreferences p) {
    final grezzo = p.getStringList(_kVoci) ?? const <String>[];
    final voci = <VoceCronologia>[];
    for (final riga in grezzo) {
      try {
        final v = VoceCronologia.fromJson(jsonDecode(riga));
        if (v != null) voci.add(v);
      } on FormatException {
        // Voce illeggibile: si scarta e si va avanti.
      }
    }
    return voci;
  }
}

class CronologiaScope extends InheritedNotifier<Cronologia> {
  const CronologiaScope({
    required Cronologia super.notifier,
    required super.child,
    super.key,
  });

  static Cronologia of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CronologiaScope>();
    assert(
      scope?.notifier != null,
      'CronologiaScope assente sopra a questo widget',
    );
    return scope!.notifier!;
  }
}
