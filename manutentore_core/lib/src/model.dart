/// Modello dati del motore di calcolo.
///
/// Ogni calcolatore si auto-descrive: la UI non conosce le formule, legge
/// [Calculator.fields] e costruisce il form, poi mostra [CalcResult].
library;

enum Domain { elettrico, meccanico, trasversale }

enum FieldType { number, select, toggle }

/// Gravita' di una riga di risultato o di un verdetto.
enum Severity { neutral, ok, warn, fail }

class SelectOption {
  final String value;
  final String label;

  /// Valore numerico associato all'opzione (coefficiente, fattore, ecc.).
  final double? numeric;
  const SelectOption(this.value, this.label, {this.numeric});
}

/// Descrizione di un campo di input.
class FieldSpec {
  final String key;
  final String label;
  final String unit;
  final FieldType type;
  final double? min;
  final double? max;
  final Object? initial;
  final String? help;
  final List<SelectOption> options;

  const FieldSpec.number(
    this.key,
    this.label, {
    this.unit = '',
    this.min,
    this.max,
    double? value,
    this.help,
  })  : type = FieldType.number,
        options = const [],
        initial = value;

  const FieldSpec.select(
    this.key,
    this.label, {
    required this.options,
    String? value,
    this.help,
  })  : type = FieldType.select,
        unit = '',
        min = null,
        max = null,
        initial = value;

  const FieldSpec.toggle(
    this.key,
    this.label, {
    bool value = false,
    this.help,
  })  : type = FieldType.toggle,
        unit = '',
        min = null,
        max = null,
        options = const [],
        initial = value;
}

/// Errore di calcolo con messaggio destinato all'utente finale.
class CalcException implements Exception {
  final String message;
  const CalcException(this.message);
  @override
  String toString() => message;
}

/// Accesso tipizzato agli input, con validazione.
class Inputs {
  final Map<String, Object?> _raw;
  final Map<String, FieldSpec> _specs;

  Inputs(this._raw, List<FieldSpec> fields)
      : _specs = {for (final f in fields) f.key: f};

  /// Costruisce gli input di default a partire dalle specifiche.
  static Inputs defaults(List<FieldSpec> fields) => Inputs(
        {for (final f in fields) f.key: f.initial},
        fields,
      );

  double num_(String key) {
    final spec = _specs[key];
    final v = _raw[key];
    final label = spec?.label ?? key;
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim().replaceAll(',', '.'));
    }
    if (d == null || d.isNaN || d.isInfinite) {
      throw CalcException('Valore non valido per "$label".');
    }
    if (spec?.min != null && d < spec!.min!) {
      throw CalcException('"$label" deve essere >= ${_fmt(spec.min!)}.');
    }
    if (spec?.max != null && d > spec!.max!) {
      throw CalcException('"$label" deve essere <= ${_fmt(spec.max!)}.');
    }
    return d;
  }

  /// Valore intero, con controllo di interezza.
  int int_(String key) {
    final d = num_(key);
    if ((d - d.roundToDouble()).abs() > 1e-9) {
      throw CalcException('"${_specs[key]?.label ?? key}" deve essere intero.');
    }
    return d.round();
  }

  /// Chiave dell'opzione selezionata.
  String opt(String key) {
    final v = _raw[key];
    if (v is String && v.isNotEmpty) return v;
    final spec = _specs[key];
    final init = spec?.initial;
    if (init is String) return init;
    if (spec != null && spec.options.isNotEmpty) return spec.options.first.value;
    throw CalcException('Selezione mancante per "${spec?.label ?? key}".');
  }

  /// Valore numerico associato all'opzione selezionata.
  double optNum(String key) {
    final sel = opt(key);
    final spec = _specs[key];
    final o = spec?.options.where((e) => e.value == sel);
    if (o == null || o.isEmpty || o.first.numeric == null) {
      throw CalcException('Opzione "$sel" priva di valore numerico.');
    }
    return o.first.numeric!;
  }

  bool flag(String key) {
    final v = _raw[key];
    if (v is bool) return v;
    final init = _specs[key]?.initial;
    return init is bool ? init : false;
  }

  bool has(String key) => _raw[key] != null;

  Inputs copyWith(Map<String, Object?> overrides) =>
      Inputs({..._raw, ...overrides}, _specs.values.toList());
}

/// Una riga del risultato.
class ResultLine {
  final String label;
  final String value;
  final String unit;
  final Severity severity;
  final String? note;

  /// Riga primaria: evidenziata dalla UI.
  final bool primary;

  const ResultLine(
    this.label,
    this.value, {
    this.unit = '',
    this.severity = Severity.neutral,
    this.note,
    this.primary = false,
  });

  factory ResultLine.number(
    String label,
    double value, {
    String unit = '',
    int decimals = 2,
    Severity severity = Severity.neutral,
    String? note,
    bool primary = false,
  }) =>
      ResultLine(
        label,
        _fmt(value, decimals),
        unit: unit,
        severity: severity,
        note: note,
        primary: primary,
      );

  @override
  String toString() => '$label: $value $unit'.trim();
}

class CalcResult {
  final List<ResultLine> lines;

  /// Esito sintetico (es. "Conforme", "Sezione insufficiente").
  final String? verdict;
  final Severity verdictSeverity;

  /// Avvertenze non bloccanti.
  final List<String> warnings;

  const CalcResult(
    this.lines, {
    this.verdict,
    this.verdictSeverity = Severity.neutral,
    this.warnings = const [],
  });

  /// Recupera una riga per etichetta (usato dai test).
  ResultLine line(String label) => lines.firstWhere(
        (l) => l.label == label,
        orElse: () => throw StateError('Riga "$label" assente'),
      );

  double numeric(String label) =>
      double.parse(line(label).value.replaceAll(',', '.'));
}

/// Interfaccia comune a tutti i calcolatori.
abstract class Calculator {
  const Calculator();

  /// Identificativo stabile: usato per deep link e preferiti. Non cambiarlo.
  String get id;
  String get name;
  String get subtitle;
  Domain get domain;

  /// Termini di ricerca aggiuntivi (sinonimi, gergo di cantiere, inglese).
  List<String> get tags => const [];

  /// Norme e fonti di riferimento, mostrate in fondo alla scheda.
  List<String> get references => const [];

  /// Nota didattica: mostrata solo in modalita' studente.
  String? get theory => null;

  List<FieldSpec> get fields;

  CalcResult compute(Inputs i);

  /// Scorciatoia comoda per test e per l'esecuzione da mappa grezza.
  CalcResult run(Map<String, Object?> raw) => compute(Inputs(raw, fields));
}

String _fmt(double v, [int decimals = 2]) {
  if (v.abs() >= 1e6 || (v != 0 && v.abs() < 1e-4)) {
    return v.toStringAsExponential(2);
  }
  return v.toStringAsFixed(decimals);
}
