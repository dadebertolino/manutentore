/// Tabelle di riferimento.
///
/// Sottoinsieme delle taglie piu' ricorrenti in manutenzione industriale e
/// civile. Non sostituisce la consultazione della norma: i valori servono a
/// dare un ordine di grandezza verificabile in campo.
library;

// dart format off
//
// I letterali qui sotto sono tabelle e vanno lette come tabelle: una riga per
// posa, una colonna per sezione, come stanno nella norma da cui sono
// trascritte. Il formatter le spezzerebbe a un valore per riga, rendendo
// impraticabile il confronto a vista con la CEI-UNEL o la ISO, che e'
// esattamente l'operazione che serve quando si sospetta un errore di
// trascrizione. Il resto del repo e' formattato e la CI lo verifica: questa e'
// l'unica eccezione, e finisce prima di `interpola()`.

// ---------------------------------------------------------------------------
// ELETTRICO
// ---------------------------------------------------------------------------

/// Sezioni normalizzate rame (mm^2).
const kSezioni = <double>[
  1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240
];

/// Portate Iz0 in aria a 30 C, conduttori in rame.
/// Chiave: '<isolante>|<posa>|<n conduttori attivi>'.
/// Rif. IEC 60364-5-52 / CEI-UNEL 35024-1.
final kPortateCu = <String, Map<double, double>>{
  'PVC|B1|2': {
    1.5: 17.5, 2.5: 24, 4: 32, 6: 41, 10: 57, 16: 76,
    25: 101, 35: 125, 50: 151, 70: 192, 95: 232, 120: 269
  },
  'PVC|B1|3': {
    1.5: 15.5, 2.5: 21, 4: 28, 6: 36, 10: 50, 16: 68,
    25: 89, 35: 110, 50: 134, 70: 171, 95: 207, 120: 239
  },
  'PVC|B2|2': {
    1.5: 16.5, 2.5: 23, 4: 30, 6: 38, 10: 52, 16: 69,
    25: 90, 35: 111, 50: 133, 70: 168, 95: 201, 120: 232
  },
  'PVC|B2|3': {
    1.5: 15, 2.5: 20, 4: 27, 6: 34, 10: 46, 16: 62,
    25: 80, 35: 99, 50: 118, 70: 149, 95: 179, 120: 206
  },
  'PVC|C|2': {
    1.5: 19.5, 2.5: 27, 4: 36, 6: 46, 10: 63, 16: 85,
    25: 112, 35: 138, 50: 168, 70: 213, 95: 258, 120: 299
  },
  'PVC|C|3': {
    1.5: 17.5, 2.5: 24, 4: 32, 6: 41, 10: 57, 16: 76,
    25: 96, 35: 119, 50: 144, 70: 184, 95: 223, 120: 259
  },
  'PVC|E|2': {
    1.5: 22, 2.5: 30, 4: 40, 6: 51, 10: 70, 16: 94,
    25: 119, 35: 148, 50: 180, 70: 232, 95: 282, 120: 328
  },
  'PVC|E|3': {
    1.5: 18.5, 2.5: 25, 4: 34, 6: 43, 10: 60, 16: 80,
    25: 101, 35: 126, 50: 153, 70: 196, 95: 238, 120: 276
  },
  'XLPE|B1|2': {
    1.5: 23, 2.5: 31, 4: 42, 6: 54, 10: 75, 16: 100,
    25: 133, 35: 164, 50: 198, 70: 253, 95: 306, 120: 354
  },
  'XLPE|B1|3': {
    1.5: 20, 2.5: 28, 4: 37, 6: 48, 10: 66, 16: 88,
    25: 117, 35: 144, 50: 175, 70: 222, 95: 269, 120: 312
  },
  'XLPE|B2|2': {
    1.5: 22, 2.5: 30, 4: 40, 6: 51, 10: 69, 16: 91,
    25: 119, 35: 146, 50: 175, 70: 221, 95: 265, 120: 305
  },
  'XLPE|B2|3': {
    1.5: 19.5, 2.5: 26, 4: 35, 6: 44, 10: 60, 16: 80,
    25: 105, 35: 128, 50: 154, 70: 194, 95: 233, 120: 268
  },
  'XLPE|C|2': {
    1.5: 26, 2.5: 36, 4: 49, 6: 63, 10: 86, 16: 115,
    25: 149, 35: 185, 50: 225, 70: 289, 95: 352, 120: 410
  },
  'XLPE|C|3': {
    1.5: 23, 2.5: 32, 4: 42, 6: 54, 10: 75, 16: 100,
    25: 127, 35: 158, 50: 192, 70: 246, 95: 298, 120: 346
  },
  'XLPE|E|2': {
    1.5: 30, 2.5: 41, 4: 55, 6: 70, 10: 96, 16: 129,
    25: 163, 35: 202, 50: 245, 70: 316, 95: 385, 120: 448
  },
  'XLPE|E|3': {
    1.5: 25, 2.5: 34, 4: 45, 6: 58, 10: 80, 16: 107,
    25: 138, 35: 171, 50: 209, 70: 269, 95: 328, 120: 382
  },
};

/// Fattore correttivo per temperatura ambiente (posa in aria).
const kTempAria = <String, Map<int, double>>{
  'PVC': {
    10: 1.22, 15: 1.17, 20: 1.12, 25: 1.06, 30: 1.00,
    35: 0.94, 40: 0.87, 45: 0.79, 50: 0.71, 55: 0.61, 60: 0.50
  },
  'XLPE': {
    10: 1.15, 15: 1.12, 20: 1.08, 25: 1.04, 30: 1.00,
    35: 0.96, 40: 0.91, 45: 0.87, 50: 0.82, 55: 0.76, 60: 0.71
  },
};

/// Fattore di raggruppamento per circuiti affiancati in fascio.
const kRaggruppamento = <int, double>{
  1: 1.00, 2: 0.80, 3: 0.70, 4: 0.65, 5: 0.60, 6: 0.57,
  7: 0.54, 8: 0.52, 9: 0.50, 12: 0.45, 16: 0.41, 20: 0.38
};

/// Coefficiente K per la verifica adiabatica I^2 t <= K^2 S^2.
const kAdiabatico = <String, double>{
  'Cu-PVC': 115,
  'Cu-XLPE': 143,
  'Al-PVC': 76,
  'Al-XLPE': 94,
};

/// Resistivita' a 20 C in ohm*mm^2/m e coefficiente di temperatura.
const kResistivita = <String, double>{'Cu': 0.017241, 'Al': 0.028264};
const kAlfaTemp = <String, double>{'Cu': 0.00393, 'Al': 0.00403};

/// Correnti nominali normalizzate degli interruttori magnetotermici (A).
const kInNominali = <double>[
  6, 10, 13, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250
];

/// Moltiplicatore di intervento magnetico istantaneo per curva.
const kCurve = <String, double>{'B': 5, 'C': 10, 'D': 20};

// ---------------------------------------------------------------------------
// MECCANICO
// ---------------------------------------------------------------------------

/// Passo grosso ISO 261 (mm) per diametro nominale.
final kPassoGrosso = <double, double>{
  3: 0.5, 4: 0.7, 5: 0.8, 6: 1.0, 8: 1.25, 10: 1.5, 12: 1.75,
  14: 2.0, 16: 2.0, 18: 2.5, 20: 2.5, 22: 2.5, 24: 3.0,
  27: 3.0, 30: 3.5, 33: 3.5, 36: 4.0, 42: 4.5, 48: 5.0
};

/// Carico di snervamento Rp0.2 (MPa) per classe di resistenza ISO 898-1.
/// Per la 8.8 il valore dipende dal diametro (soglia 16 mm).
const kClasseRp = <String, double>{
  '4.6': 240,
  '5.8': 400,
  '8.8': 640,
  '8.8>16': 660,
  '10.9': 940,
  '12.9': 1100,
};

/// Carico di rottura Rm (MPa) per classe.
const kClasseRm = <String, double>{
  '4.6': 400, '5.8': 500, '8.8': 800, '8.8>16': 830,
  '10.9': 1040, '12.9': 1220
};

/// Soglie ISO 10816-3, velocita' efficace mm/s RMS, banda 10-1000 Hz.
/// Ordine: limite A/B, B/C, C/D.
const kIso10816 = <String, List<double>>{
  'G1-rigido': [2.3, 4.5, 7.1],
  'G1-flessibile': [3.5, 5.6, 11.0],
  'G2-rigido': [1.4, 2.8, 4.5],
  'G2-flessibile': [2.3, 4.5, 7.1],
};

/// Gradi di viscosita' ISO 3448 (cSt a 40 C, valore nominale).
const kIsoVg = <int, double>{
  22: 22, 32: 32, 46: 46, 68: 68, 100: 100, 150: 150, 220: 220, 320: 320
};

// dart format on

/// Interpola linearmente su una mappa chiave->valore ordinata.
double interpola(Map<num, double> tabella, double x) {
  final chiavi = tabella.keys.map((e) => e.toDouble()).toList()..sort();
  if (x <= chiavi.first) return tabella[_key(tabella, chiavi.first)]!;
  if (x >= chiavi.last) return tabella[_key(tabella, chiavi.last)]!;
  for (var i = 0; i < chiavi.length - 1; i++) {
    final a = chiavi[i], b = chiavi[i + 1];
    if (x >= a && x <= b) {
      final va = tabella[_key(tabella, a)]!, vb = tabella[_key(tabella, b)]!;
      return va + (vb - va) * (x - a) / (b - a);
    }
  }
  return tabella[_key(tabella, chiavi.last)]!;
}

num _key(Map<num, double> m, double v) =>
    m.keys.firstWhere((k) => k.toDouble() == v);
