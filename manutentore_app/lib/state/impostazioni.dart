import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modalita' di lettura. Stesso motore di calcolo, due pubblici.
///
/// - [studente]: mostra la nota didattica, le avvertenze e tutti i passaggi.
/// - [professionista]: campo, risultato, verdetto. Niente prosa.
enum Modalita { studente, professionista }

enum PreferenzaTema { sistema, chiaro, scuro }

/// Stato globale minimo. Nessun pacchetto di state management: un
/// [ChangeNotifier] esposto via [InheritedNotifier] basta e avanza, e resta
/// una dipendenza in meno da giustificare.
class Impostazioni extends ChangeNotifier {
  Impostazioni(this._prefs)
      : _modalita = _leggiModalita(_prefs),
        _tema = _leggiTema(_prefs),
        _preferiti = _prefs.getStringList(_kPreferiti)?.toSet() ?? <String>{};

  static const _kModalita = 'modalita';
  static const _kTema = 'tema';
  static const _kPreferiti = 'preferiti';

  final SharedPreferences _prefs;
  Modalita _modalita;
  PreferenzaTema _tema;
  final Set<String> _preferiti;

  static Future<Impostazioni> carica() async =>
      Impostazioni(await SharedPreferences.getInstance());

  Modalita get modalita => _modalita;
  PreferenzaTema get tema => _tema;
  Set<String> get preferiti => Set.unmodifiable(_preferiti);
  bool get isStudente => _modalita == Modalita.studente;

  void impostaModalita(Modalita m) {
    if (m == _modalita) return;
    _modalita = m;
    _prefs.setString(_kModalita, m.name);
    notifyListeners();
  }

  void impostaTema(PreferenzaTema t) {
    if (t == _tema) return;
    _tema = t;
    _prefs.setString(_kTema, t.name);
    notifyListeners();
  }

  bool isPreferito(String id) => _preferiti.contains(id);

  void togglePreferito(String id) {
    if (!_preferiti.remove(id)) _preferiti.add(id);
    _prefs.setStringList(_kPreferiti, _preferiti.toList());
    notifyListeners();
  }

  static Modalita _leggiModalita(SharedPreferences p) => Modalita.values
      .firstWhere(
        (m) => m.name == p.getString(_kModalita),
        orElse: () => Modalita.professionista,
      );

  static PreferenzaTema _leggiTema(SharedPreferences p) =>
      PreferenzaTema.values.firstWhere(
        (t) => t.name == p.getString(_kTema),
        orElse: () => PreferenzaTema.scuro,
      );
}

class ImpostazioniScope extends InheritedNotifier<Impostazioni> {
  const ImpostazioniScope({
    required Impostazioni super.notifier,
    required super.child,
    super.key,
  });

  static Impostazioni of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ImpostazioniScope>();
    assert(scope?.notifier != null, 'ImpostazioniScope assente sopra a questo widget');
    return scope!.notifier!;
  }
}
