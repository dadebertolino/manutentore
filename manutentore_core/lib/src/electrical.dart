import 'dart:math' as math;

import 'model.dart';
import 'tables.dart';

const _optMateriale = [
  SelectOption('Cu', 'Rame'),
  SelectOption('Al', 'Alluminio'),
];

const _optSistema = [
  SelectOption('tri', 'Trifase', numeric: 1.7320508075688772),
  SelectOption('mono', 'Monofase', numeric: 2),
  SelectOption('cc', 'Corrente continua', numeric: 2),
];

double _resistenzaSpecifica(String materiale, double tempC, double sezione) {
  final rho20 = kResistivita[materiale]!;
  final alfa = kAlfaTemp[materiale]!;
  return rho20 * (1 + alfa * (tempC - 20)) / sezione; // ohm/m
}

// ---------------------------------------------------------------------------

/// Caduta di tensione su una linea.
class CadutaDiTensione extends Calculator {
  const CadutaDiTensione();

  @override
  String get id => 'el.caduta_tensione';
  @override
  String get name => 'Caduta di tensione';
  @override
  String get subtitle => 'Verifica del limite 4% su linea in cavo';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => ['dv', 'delta v', 'voltage drop', 'linea', 'cavo'];
  @override
  List<String> get references => ['CEI 64-8/5 art. 525', 'CEI-UNEL 35023'];
  @override
  String? get theory =>
      'La caduta è dovuta alla resistenza del conduttore e, sulle sezioni '
      'grandi, anche alla reattanza. Raddoppiare la lunghezza raddoppia la '
      'caduta; raddoppiare la sezione la dimezza (finché domina la parte '
      'resistiva).';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.select('sistema', 'Sistema', options: _optSistema, value: 'tri'),
    FieldSpec.number(
      'un',
      'Tensione nominale',
      unit: 'V',
      min: 1,
      max: 1000,
      value: 400,
    ),
    FieldSpec.number(
      'ib',
      'Corrente di impiego',
      unit: 'A',
      min: 0.01,
      max: 2000,
      value: 32,
    ),
    FieldSpec.number(
      'lung',
      'Lunghezza linea',
      unit: 'm',
      min: 0.1,
      max: 5000,
      value: 45,
    ),
    FieldSpec.number(
      'sez',
      'Sezione conduttore',
      unit: 'mm2',
      min: 0.5,
      max: 630,
      value: 10,
    ),
    FieldSpec.select('mat', 'Materiale', options: _optMateriale, value: 'Cu'),
    FieldSpec.number(
      'cosphi',
      'Fattore di potenza',
      min: 0.1,
      max: 1,
      value: 0.9,
    ),
    FieldSpec.number(
      'temp',
      'Temperatura conduttore',
      unit: 'C',
      min: 20,
      max: 120,
      value: 70,
      help: '70 C per PVC, 90 C per EPR/XLPE a pieno carico.',
    ),
    FieldSpec.number(
      'reatt',
      'Reattanza specifica',
      unit: 'mohm/m',
      min: 0,
      max: 1,
      value: 0.08,
      help: 'Trascurabile sotto i 16 mm2. Cavi multipolari ~0,08.',
    ),
    FieldSpec.number(
      'limite',
      'Limite ammesso',
      unit: '%',
      min: 0.5,
      max: 20,
      value: 4,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final sistema = i.opt('sistema');
    final k = i.optNum('sistema');
    final un = i.num_('un');
    final ib = i.num_('ib');
    final l = i.num_('lung');
    final s = i.num_('sez');
    final cos = sistema == 'cc' ? 1.0 : i.num_('cosphi');
    final sin = math.sqrt(math.max(0, 1 - cos * cos));
    final r = _resistenzaSpecifica(i.opt('mat'), i.num_('temp'), s);
    final x = sistema == 'cc' ? 0.0 : i.num_('reatt') / 1000;
    final limite = i.num_('limite');

    final dv = k * ib * l * (r * cos + x * sin);
    final perc = dv / un * 100;
    final vFinale = un - dv;
    final perdite = k / 2 * (sistema == 'tri' ? 3 : 2) * ib * ib * r * l;

    final ok = perc <= limite;
    // Sezione minima teorica per rientrare nel limite (parte resistiva).
    final rMax = (limite / 100 * un / (k * ib * l) - x * sin) / cos;
    final sMin = rMax > 0
        ? _resistenzaSpecifica(i.opt('mat'), i.num_('temp'), 1) / rMax
        : double.infinity;

    return CalcResult(
      [
        ResultLine.number('Caduta di tensione', dv, unit: 'V', primary: true),
        ResultLine.number(
          'Caduta percentuale',
          perc,
          unit: '%',
          primary: true,
          severity: ok ? Severity.ok : Severity.fail,
        ),
        ResultLine.number('Tensione a fine linea', vFinale, unit: 'V'),
        ResultLine.number(
          'Resistenza specifica',
          r * 1000,
          unit: 'mohm/m',
          decimals: 4,
        ),
        ResultLine.number(
          'Perdite di potenza',
          perdite,
          unit: 'W',
          decimals: 1,
        ),
        if (sMin.isFinite)
          ResultLine.number(
            'Sezione minima per il limite',
            sMin,
            unit: 'mm2',
            note: _prossimaSezione(sMin),
          ),
      ],
      verdict: ok
          ? 'Entro il limite del ${limite.toStringAsFixed(1)}%'
          : 'Caduta eccessiva: aumentare la sezione',
      verdictSeverity: ok ? Severity.ok : Severity.fail,
      warnings: [
        if (s < 16 && i.num_('reatt') > 0)
          'Sotto i 16 mm2 la reattanza è trascurabile: il contributo è minimo.',
      ],
    );
  }

  static String? _prossimaSezione(double sMin) {
    for (final s in kSezioni) {
      if (s >= sMin) return 'Prima sezione normalizzata utile: $s mm2';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------

/// Portata effettiva Iz di un cavo con fattori correttivi.
class PortataCavo extends Calculator {
  const PortataCavo();

  @override
  String get id => 'el.portata_cavo';
  @override
  String get name => 'Portata cavo (Iz)';
  @override
  String get subtitle => 'Iz0 da tabella con correzione temperatura e fascio';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => ['ampacita', 'iz', 'ampacity', 'declassamento'];
  @override
  List<String> get references => [
    'IEC 60364-5-52 tab. B.52.4 / B.52.14 / B.52.17',
    'CEI-UNEL 35024-1',
  ];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'sez',
      'Sezione',
      unit: 'mm2',
      min: 1.5,
      max: 120,
      value: 10,
    ),
    FieldSpec.select(
      'iso',
      'Isolante',
      options: [
        SelectOption('PVC', 'PVC (70 C)'),
        SelectOption('XLPE', 'EPR / XLPE (90 C)'),
      ],
      value: 'PVC',
    ),
    FieldSpec.select(
      'posa',
      'Metodo di posa',
      options: [
        SelectOption('B1', 'B1 - unipolari in tubo/canale'),
        SelectOption('B2', 'B2 - multipolare in tubo/canale'),
        SelectOption('C', 'C - a parete o su passerella non forata'),
        SelectOption('E', 'E - multipolare in aria libera'),
      ],
      value: 'B1',
    ),
    FieldSpec.select(
      'ncond',
      'Conduttori attivi',
      options: [
        SelectOption('2', '2 (monofase)'),
        SelectOption('3', '3 (trifase)'),
      ],
      value: '3',
    ),
    FieldSpec.number(
      'tamb',
      'Temperatura ambiente',
      unit: 'C',
      min: 10,
      max: 60,
      value: 30,
    ),
    FieldSpec.number(
      'circuiti',
      'Circuiti raggruppati',
      min: 1,
      max: 20,
      value: 1,
    ),
    FieldSpec.number(
      'ib',
      'Corrente di impiego',
      unit: 'A',
      min: 0,
      max: 2000,
      value: 32,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final iso = i.opt('iso');
    final chiave = '$iso|${i.opt('posa')}|${i.opt('ncond')}';
    final tabella = kPortateCu[chiave];
    if (tabella == null) {
      throw const CalcException('Combinazione isolante/posa non in tabella.');
    }
    final sez = i.num_('sez');
    final iz0 = tabella[sez];
    if (iz0 == null) {
      throw CalcException(
        'Sezione $sez mm2 non presente. Sezioni disponibili: '
        '${tabella.keys.join(", ")}.',
      );
    }
    final k1 = interpola(
      kTempAria[iso]!.map((k, v) => MapEntry(k as num, v)),
      i.num_('tamb'),
    );
    final nCirc = i.int_('circuiti');
    final k2 = interpola(
      kRaggruppamento.map((k, v) => MapEntry(k as num, v)),
      nCirc.toDouble(),
    );
    final iz = iz0 * k1 * k2;
    final ib = i.num_('ib');
    final ok = ib <= iz;

    return CalcResult(
      [
        ResultLine.number('Portata a 30 C (Iz0)', iz0, unit: 'A', decimals: 1),
        ResultLine.number('k1 temperatura', k1, decimals: 3),
        ResultLine.number('k2 raggruppamento', k2, decimals: 3),
        ResultLine.number(
          'Portata effettiva Iz',
          iz,
          unit: 'A',
          decimals: 1,
          primary: true,
          severity: ok ? Severity.ok : Severity.fail,
        ),
        ResultLine.number('Margine su Ib', iz - ib, unit: 'A', decimals: 1),
        ResultLine.number('Utilizzo', ib / iz * 100, unit: '%', decimals: 1),
      ],
      verdict: ok ? 'Cavo idoneo (Ib <= Iz)' : 'Cavo sottodimensionato',
      verdictSeverity: ok ? Severity.ok : Severity.fail,
      warnings: [
        if (nCirc > 1)
          'Il fattore di raggruppamento presuppone circuiti ugualmente caricati.',
        if (i.num_('tamb') > 40)
          'Sopra i 40 C valutare EPR/XLPE o una posa più ventilata.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Coordinamento cavo-protezione e verifica termica al cortocircuito.
class CoordinamentoProtezione extends Calculator {
  const CoordinamentoProtezione();

  @override
  String get id => 'el.coordinamento';
  @override
  String get name => 'Coordinamento cavo-protezione';
  @override
  String get subtitle => 'Ib <= In <= Iz, If <= 1,45 Iz e verifica I2t';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => ['selettivita', 'magnetotermico', 'i2t', 'k2s2'];
  @override
  List<String> get references => ['CEI 64-8/4 art. 433 e 434'];
  @override
  String? get theory =>
      'Tre condizioni: la protezione deve lasciar passare il carico (In >= Ib), '
      'non deve superare la portata del cavo (In <= Iz) e deve intervenire '
      'prima che il cavo si danneggi termicamente (I2t <= K2 S2).';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'ib',
      'Corrente di impiego',
      unit: 'A',
      min: 0.1,
      max: 2000,
      value: 28,
    ),
    FieldSpec.number(
      'in',
      'Corrente nominale protezione',
      unit: 'A',
      min: 0.1,
      max: 2000,
      value: 32,
    ),
    FieldSpec.number(
      'iz',
      'Portata del cavo Iz',
      unit: 'A',
      min: 0.1,
      max: 2000,
      value: 42.9,
    ),
    FieldSpec.number(
      'sez',
      'Sezione conduttore',
      unit: 'mm2',
      min: 0.5,
      max: 630,
      value: 10,
    ),
    FieldSpec.select(
      'k',
      'Conduttore/isolante',
      options: [
        SelectOption('Cu-PVC', 'Rame - PVC (K=115)', numeric: 115),
        SelectOption('Cu-XLPE', 'Rame - EPR/XLPE (K=143)', numeric: 143),
        SelectOption('Al-PVC', 'Alluminio - PVC (K=76)', numeric: 76),
        SelectOption('Al-XLPE', 'Alluminio - EPR/XLPE (K=94)', numeric: 94),
      ],
      value: 'Cu-PVC',
    ),
    FieldSpec.number(
      'icc',
      'Corrente di cortocircuito',
      unit: 'A',
      min: 1,
      max: 100000,
      value: 6000,
    ),
    FieldSpec.number(
      'tint',
      'Tempo di intervento',
      unit: 's',
      min: 0.001,
      max: 5,
      value: 0.1,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final ib = i.num_('ib');
    final inProt = i.num_('in');
    final iz = i.num_('iz');
    final s = i.num_('sez');
    final k = i.optNum('k');
    final icc = i.num_('icc');
    final t = i.num_('tint');

    final cond1 = ib <= inProt;
    final cond2 = inProt <= iz;
    final iF = 1.45 * inProt; // magnetotermici: If = 1,45 In
    final cond3 = iF <= 1.45 * iz;

    final i2t = icc * icc * t;
    final k2s2 = k * k * s * s;
    final cond4 = i2t <= k2s2;
    final sMin = icc * math.sqrt(t) / k;
    final tMax = k2s2 / (icc * icc);

    final tutteOk = cond1 && cond2 && cond3 && cond4;

    return CalcResult(
      [
        ResultLine(
          'Ib <= In',
          cond1 ? 'verificata' : 'NON verificata',
          severity: cond1 ? Severity.ok : Severity.fail,
          note: '${ib.toStringAsFixed(1)} <= ${inProt.toStringAsFixed(1)} A',
        ),
        ResultLine(
          'In <= Iz',
          cond2 ? 'verificata' : 'NON verificata',
          severity: cond2 ? Severity.ok : Severity.fail,
          note: '${inProt.toStringAsFixed(1)} <= ${iz.toStringAsFixed(1)} A',
        ),
        ResultLine(
          'If <= 1,45 Iz',
          cond3 ? 'verificata' : 'NON verificata',
          severity: cond3 ? Severity.ok : Severity.fail,
          note: 'If = ${iF.toStringAsFixed(1)} A',
        ),
        ResultLine.number(
          'Energia specifica I2t',
          i2t,
          unit: 'A2s',
          decimals: 0,
        ),
        ResultLine.number(
          'Sopportata dal cavo K2S2',
          k2s2,
          unit: 'A2s',
          decimals: 0,
          severity: cond4 ? Severity.ok : Severity.fail,
        ),
        ResultLine.number(
          'Sezione minima al cortocircuito',
          sMin,
          unit: 'mm2',
          primary: true,
        ),
        ResultLine.number(
          'Tempo massimo ammesso',
          tMax,
          unit: 's',
          decimals: 3,
        ),
      ],
      verdict: tutteOk
          ? 'Coordinamento verificato'
          : 'Coordinamento NON verificato',
      verdictSeverity: tutteOk ? Severity.ok : Severity.fail,
      warnings: const [
        'If = 1,45 In vale per i magnetotermici. Per i fusibili gG usare '
            'If dalla curva (tipicamente 1,6 In).',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Impedenza dell'anello di guasto e protezione contro i contatti indiretti.
class AnelloDiGuasto extends Calculator {
  const AnelloDiGuasto();

  @override
  String get id => 'el.anello_guasto';
  @override
  String get name => 'Anello di guasto (Zs)';
  @override
  String get subtitle => 'Verifica Zs <= U0/Ia in sistema TN';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => ['tn', 'tt', 'contatti indiretti', 'loop', 'terra'];
  @override
  List<String> get references => ['CEI 64-8/4 art. 411', 'CEI 64-8/6'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'u0',
      'Tensione verso terra U0',
      unit: 'V',
      min: 50,
      max: 500,
      value: 230,
    ),
    FieldSpec.number(
      'in',
      'In protezione',
      unit: 'A',
      min: 0.5,
      max: 2000,
      value: 32,
    ),
    FieldSpec.select(
      'curva',
      'Curva magnetotermico',
      options: [
        SelectOption('B', 'B (5 In)', numeric: 5),
        SelectOption('C', 'C (10 In)', numeric: 10),
        SelectOption('D', 'D (20 In)', numeric: 20),
      ],
      value: 'C',
    ),
    FieldSpec.number(
      'zsMis',
      'Zs misurato',
      unit: 'ohm',
      min: 0,
      max: 100,
      value: 0.45,
      help: 'Valore letto dallo strumento di verifica.',
    ),
    FieldSpec.number(
      'cmin',
      'Coefficiente c',
      min: 0.5,
      max: 1,
      value: 0.95,
      help: 'Riduzione della tensione a vuoto in condizioni di guasto.',
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final u0 = i.num_('u0');
    final inProt = i.num_('in');
    final molt = i.optNum('curva');
    final ia = inProt * molt;
    final c = i.num_('cmin');
    final zsMax = c * u0 / ia;
    final zsMis = i.num_('zsMis');
    final ok = zsMis <= zsMax;
    final iccPresunta = c * u0 / math.max(zsMis, 1e-6);

    return CalcResult(
      [
        ResultLine.number(
          'Corrente di intervento Ia',
          ia,
          unit: 'A',
          decimals: 0,
        ),
        ResultLine.number(
          'Zs massima ammessa',
          zsMax,
          unit: 'ohm',
          decimals: 3,
          primary: true,
        ),
        ResultLine.number(
          'Zs misurata',
          zsMis,
          unit: 'ohm',
          decimals: 3,
          primary: true,
          severity: ok ? Severity.ok : Severity.fail,
        ),
        ResultLine.number(
          'Corrente di guasto presunta',
          iccPresunta,
          unit: 'A',
          decimals: 0,
        ),
        ResultLine.number(
          'Margine',
          (zsMax - zsMis) / zsMax * 100,
          unit: '%',
          decimals: 1,
        ),
      ],
      verdict: ok
          ? 'Protezione garantita dal magnetotermico'
          : 'Zs troppo alta: serve un differenziale o una linea più corta',
      verdictSeverity: ok ? Severity.ok : Severity.fail,
      warnings: const [
        'In sistema TT la protezione è affidata al differenziale: '
            'verificare Ra x Idn <= 50 V.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Rifasamento di un impianto o di un motore.
class Rifasamento extends Calculator {
  const Rifasamento();

  @override
  String get id => 'el.rifasamento';
  @override
  String get name => 'Rifasamento';
  @override
  String get subtitle => 'Potenza reattiva per portare cosphi al valore voluto';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => ['cosfi', 'condensatori', 'kvar', 'power factor'];
  @override
  List<String> get references => ['CEI 0-16', 'Delibera ARERA penali cosphi'];
  @override
  String? get theory =>
      'I condensatori forniscono localmente la potenza reattiva che il carico '
      'induttivo assorbe, così la rete trasporta solo la parte attiva: meno '
      'corrente, meno perdite, meno penali.';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'p',
      'Potenza attiva',
      unit: 'kW',
      min: 0.1,
      max: 100000,
      value: 30,
    ),
    FieldSpec.number(
      'cos1',
      'cosphi attuale',
      min: 0.05,
      max: 0.999,
      value: 0.75,
    ),
    FieldSpec.number(
      'cos2',
      'cosphi desiderato',
      min: 0.1,
      max: 1,
      value: 0.95,
    ),
    FieldSpec.number(
      'un',
      'Tensione concatenata',
      unit: 'V',
      min: 100,
      max: 1000,
      value: 400,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final p = i.num_('p');
    final cos1 = i.num_('cos1');
    final cos2 = i.num_('cos2');
    if (cos2 <= cos1) {
      throw const CalcException(
        'Il cosphi desiderato deve essere maggiore di quello attuale.',
      );
    }
    final un = i.num_('un');
    final tan1 = math.tan(math.acos(cos1));
    final tan2 = math.tan(math.acos(cos2));
    final qc = p * (tan1 - tan2);

    final s1 = p / cos1, s2 = p / cos2;
    final i1 = s1 * 1000 / (math.sqrt(3) * un);
    final i2 = s2 * 1000 / (math.sqrt(3) * un);
    // Capacita' per fase, collegamento a triangolo.
    final cTri = qc * 1000 / (2 * math.pi * 50 * un * un) * 1e6 / 3;

    return CalcResult(
      [
        ResultLine.number(
          'Potenza reattiva necessaria',
          qc,
          unit: 'kvar',
          primary: true,
        ),
        ResultLine.number('Potenza apparente prima', s1, unit: 'kVA'),
        ResultLine.number('Potenza apparente dopo', s2, unit: 'kVA'),
        ResultLine.number('Corrente prima', i1, unit: 'A', decimals: 1),
        ResultLine.number(
          'Corrente dopo',
          i2,
          unit: 'A',
          decimals: 1,
          severity: Severity.ok,
        ),
        ResultLine.number(
          'Riduzione di corrente',
          (1 - i2 / i1) * 100,
          unit: '%',
          decimals: 1,
        ),
        ResultLine.number(
          'Capacità per fase (triangolo, 50 Hz)',
          cTri,
          unit: 'uF',
          decimals: 1,
        ),
      ],
      verdict:
          'Batteria da ${qc.ceil()} kvar (arrotondare al taglio commerciale)',
      verdictSeverity: Severity.ok,
      warnings: const [
        'In presenza di armoniche prevedere reattanze di sbarramento.',
        'Non rifasare oltre cosphi 0,98: rischio di sovracompensazione.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Lettura targa e grandezze di un motore asincrono trifase.
class MotoreAsincrono extends Calculator {
  const MotoreAsincrono();

  @override
  String get id => 'el.motore_asincrono';
  @override
  String get name => 'Motore asincrono trifase';
  @override
  String get subtitle => 'Corrente, coppia, scorrimento, avviamento Y/D';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => [
    'targa',
    'asincrono',
    'scorrimento',
    'stella triangolo',
  ];
  @override
  List<String> get references => ['IEC 60034-1', 'CEI EN 60947-4-1'];
  @override
  String? get theory =>
      'La velocità di sincronismo dipende solo da frequenza e numero di poli. '
      'Il rotore insegue sempre in ritardo: quel ritardo (scorrimento) è ciò '
      'che genera la coppia.';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'pn',
      'Potenza resa',
      unit: 'kW',
      min: 0.01,
      max: 5000,
      value: 7.5,
    ),
    FieldSpec.number(
      'un',
      'Tensione nominale',
      unit: 'V',
      min: 100,
      max: 1000,
      value: 400,
    ),
    FieldSpec.number(
      'cosphi',
      'cosphi di targa',
      min: 0.3,
      max: 1,
      value: 0.85,
    ),
    FieldSpec.number('rend', 'Rendimento', min: 0.3, max: 1, value: 0.88),
    FieldSpec.number(
      'freq',
      'Frequenza',
      unit: 'Hz',
      min: 10,
      max: 400,
      value: 50,
    ),
    FieldSpec.number(
      'poli',
      'Numero di poli',
      min: 2,
      max: 24,
      value: 4,
      help: 'Sempre pari: 2, 4, 6, 8...',
    ),
    FieldSpec.number(
      'ngiri',
      'Velocità di targa',
      unit: 'rpm',
      min: 1,
      max: 30000,
      value: 1440,
    ),
    FieldSpec.number('rapporto', 'Rapporto Ia/In', min: 1, max: 15, value: 6.5),
  ];

  @override
  CalcResult compute(Inputs i) {
    final pn = i.num_('pn');
    final un = i.num_('un');
    final cos = i.num_('cosphi');
    final eta = i.num_('rend');
    final f = i.num_('freq');
    final poli = i.int_('poli');
    if (poli.isOdd) {
      throw const CalcException('Il numero di poli deve essere pari.');
    }
    final n = i.num_('ngiri');
    final rapp = i.num_('rapporto');

    final inom = pn * 1000 / (math.sqrt(3) * un * cos * eta);
    final ns = 120 * f / poli;
    final s = (ns - n) / ns * 100;
    final coppia = 9550 * pn / n;
    final pAss = pn / eta;
    final iSpunto = inom * rapp;
    final iSpuntoY = iSpunto / 3;
    final coppiaSpuntoY = 'un terzo di quella a triangolo';

    final sSospetto = s < 0 || s > 12;

    return CalcResult(
      [
        ResultLine.number(
          'Corrente nominale',
          inom,
          unit: 'A',
          decimals: 2,
          primary: true,
        ),
        ResultLine.number(
          'Coppia nominale',
          coppia,
          unit: 'Nm',
          decimals: 2,
          primary: true,
        ),
        ResultLine.number(
          'Velocità di sincronismo',
          ns,
          unit: 'rpm',
          decimals: 0,
        ),
        ResultLine.number(
          'Scorrimento',
          s,
          unit: '%',
          severity: sSospetto ? Severity.warn : Severity.ok,
        ),
        ResultLine.number('Potenza assorbita', pAss, unit: 'kW'),
        ResultLine.number('Potenza persa', pAss - pn, unit: 'kW'),
        ResultLine.number(
          'Corrente di spunto (diretto)',
          iSpunto,
          unit: 'A',
          decimals: 1,
        ),
        ResultLine.number(
          'Corrente di spunto (stella)',
          iSpuntoY,
          unit: 'A',
          decimals: 1,
          note: 'Coppia di spunto: $coppiaSpuntoY',
        ),
        ResultLine.number('Coppie di poli', poli / 2, unit: '', decimals: 0),
      ],
      verdict:
          'Motore a $poli poli, ${ns.toStringAsFixed(0)} rpm di sincronismo',
      verdictSeverity: sSospetto ? Severity.warn : Severity.ok,
      warnings: [
        if (sSospetto)
          'Scorrimento fuori dal range tipico (1-8%): controllare il numero '
              'di poli o la velocità di targa.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Conversione segnale analogico di processo.
class SegnaleAnalogico extends Calculator {
  const SegnaleAnalogico();

  @override
  String get id => 'el.segnale_analogico';
  @override
  String get name => 'Segnale 4-20 mA / 0-10 V';
  @override
  String get subtitle => 'Da segnale a grandezza di processo e viceversa';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => ['trasmettitore', 'scaling', 'plc', 'analogico'];
  @override
  List<String> get references => ['IEC 60381-1'];
  @override
  String? get theory =>
      'Lo zero vivo a 4 mA serve a distinguere "misura zero" da "cavo '
      'interrotto": sotto i 3,6 mA la diagnostica segnala guasto.';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.select(
      'tipo',
      'Tipo di segnale',
      options: [
        SelectOption('4-20', '4-20 mA'),
        SelectOption('0-20', '0-20 mA'),
        SelectOption('0-10', '0-10 V'),
        SelectOption('2-10', '2-10 V'),
      ],
      value: '4-20',
    ),
    FieldSpec.select(
      'verso',
      'Direzione',
      options: [
        SelectOption('s2p', 'Segnale -> grandezza'),
        SelectOption('p2s', 'Grandezza -> segnale'),
      ],
      value: 's2p',
    ),
    FieldSpec.number('val', 'Valore da convertire', value: 12.8),
    FieldSpec.number('pvMin', 'Fondo scala minimo', value: 0),
    FieldSpec.number('pvMax', 'Fondo scala massimo', value: 250),
    FieldSpec.number(
      'bit',
      'Risoluzione ADC',
      unit: 'bit',
      min: 8,
      max: 24,
      value: 12,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final tipo = i.opt('tipo');
    final (sMin, sMax, unit) = switch (tipo) {
      '4-20' => (4.0, 20.0, 'mA'),
      '0-20' => (0.0, 20.0, 'mA'),
      '0-10' => (0.0, 10.0, 'V'),
      _ => (2.0, 10.0, 'V'),
    };
    final pvMin = i.num_('pvMin');
    final pvMax = i.num_('pvMax');
    if (pvMax == pvMin) {
      throw const CalcException('Il fondo scala non può essere nullo.');
    }
    final val = i.num_('val');
    final bit = i.int_('bit');

    double segnale, pv;
    if (i.opt('verso') == 's2p') {
      segnale = val;
      pv = pvMin + (segnale - sMin) / (sMax - sMin) * (pvMax - pvMin);
    } else {
      pv = val;
      segnale = sMin + (pv - pvMin) / (pvMax - pvMin) * (sMax - sMin);
    }
    final perc = (segnale - sMin) / (sMax - sMin) * 100;
    final conteggi = (perc / 100 * (math.pow(2, bit) - 1)).roundToDouble();
    final risoluzione = (pvMax - pvMin) / (math.pow(2, bit) - 1);
    final fuoriRange = segnale < sMin || segnale > sMax;
    final rotturaLinea = tipo == '4-20' && segnale < 3.6;

    return CalcResult(
      [
        ResultLine.number('Grandezza di processo', pv, primary: true),
        ResultLine.number(
          'Segnale',
          segnale,
          unit: unit,
          decimals: 3,
          primary: true,
        ),
        ResultLine.number(
          'Percentuale scala',
          perc,
          unit: '%',
          decimals: 2,
          severity: fuoriRange ? Severity.warn : Severity.neutral,
        ),
        ResultLine.number('Conteggi ADC a $bit bit', conteggi, decimals: 0),
        ResultLine.number(
          'Risoluzione',
          risoluzione,
          decimals: 4,
          note: 'Minima variazione distinguibile',
        ),
        if (tipo == '4-20')
          ResultLine.number(
            'Caduta su resistenza 250 ohm',
            segnale * 0.25,
            unit: 'V',
            decimals: 3,
          ),
      ],
      verdict: rotturaLinea
          ? 'Sotto 3,6 mA: sospetta interruzione del circuito'
          : (fuoriRange ? 'Segnale fuori range' : 'Segnale nel range'),
      verdictSeverity: rotturaLinea
          ? Severity.fail
          : (fuoriRange ? Severity.warn : Severity.ok),
    );
  }
}

// ---------------------------------------------------------------------------

/// Termoresistenza al platino: da ohm a gradi e viceversa.
class TermoresistenzaPt extends Calculator {
  const TermoresistenzaPt();

  static const _a = 3.9083e-3;
  static const _b = -5.775e-7;
  static const _c = -4.183e-12;

  @override
  String get id => 'el.pt100';
  @override
  String get name => 'PT100 / PT1000';
  @override
  String get subtitle =>
      'Conversione resistenza-temperatura (Callendar-Van Dusen)';
  @override
  Domain get domain => Domain.elettrico;
  @override
  List<String> get tags => ['rtd', 'termoresistenza', 'sonda', 'pt1000'];
  @override
  List<String> get references => ['IEC 60751 (classe A/B)'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.select(
      'tipo',
      'Sensore',
      options: [
        SelectOption('pt100', 'PT100', numeric: 100),
        SelectOption('pt1000', 'PT1000', numeric: 1000),
      ],
      value: 'pt100',
    ),
    FieldSpec.select(
      'verso',
      'Direzione',
      options: [
        SelectOption('r2t', 'Resistenza -> temperatura'),
        SelectOption('t2r', 'Temperatura -> resistenza'),
      ],
      value: 'r2t',
    ),
    FieldSpec.number('val', 'Valore da convertire', value: 119.4),
    FieldSpec.number(
      'rCavo',
      'Resistenza di linea (2 fili)',
      unit: 'ohm',
      min: 0,
      max: 50,
      value: 0,
      help: 'Somma andata+ritorno. A 3/4 fili lasciare 0.',
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final r0 = i.optNum('tipo');
    final val = i.num_('val');
    final rCavo = i.num_('rCavo');

    final verso = i.opt('verso');
    double t, r;
    if (verso == 'r2t') {
      r = val - rCavo;
      t = _resistenzaATemp(r, r0);
    } else {
      t = val;
      r = _tempAResistenza(t, r0);
    }
    final errCavo = (rCavo > 0 && verso == 'r2t')
        ? _resistenzaATemp(val, r0) - t
        : 0.0;
    final tollB = 0.30 + 0.005 * t.abs();
    final tollA = 0.15 + 0.002 * t.abs();

    return CalcResult(
      [
        ResultLine.number('Temperatura', t, unit: 'C', primary: true),
        ResultLine.number(
          'Resistenza sensore',
          r,
          unit: 'ohm',
          decimals: 3,
          primary: true,
        ),
        ResultLine.number('Tolleranza classe A', tollA, unit: 'C', decimals: 2),
        ResultLine.number('Tolleranza classe B', tollB, unit: 'C', decimals: 2),
        if (rCavo > 0 && verso == 'r2t')
          ResultLine.number(
            'Errore da resistenza di linea',
            errCavo,
            unit: 'C',
            decimals: 2,
            severity: Severity.warn,
          ),
      ],
      verdict: (rCavo > 0 && verso == 'r2t')
          ? 'Collegamento a 2 fili: errore sistematico in eccesso'
          : 'Conversione secondo IEC 60751',
      verdictSeverity: (rCavo > 0 && verso == 'r2t')
          ? Severity.warn
          : Severity.ok,
      warnings: [
        if (rCavo > 0 && verso == 'r2t')
          'Passare a 3 o 4 fili elimina l\'errore di linea.',
        if (t < -200 || t > 850) 'Fuori dal campo di validità IEC 60751.',
      ],
    );
  }

  static double _tempAResistenza(double t, double r0) => t >= 0
      ? r0 * (1 + _a * t + _b * t * t)
      : r0 * (1 + _a * t + _b * t * t + _c * (t - 100) * t * t * t);

  static double _resistenzaATemp(double r, double r0) {
    final ratio = r / r0;
    if (ratio >= 1) {
      final disc = _a * _a - 4 * _b * (1 - ratio);
      return (-_a + math.sqrt(disc)) / (2 * _b);
    }
    // Sotto zero: inversione iterativa (Newton-Raphson).
    var t = (ratio - 1) / (_a);
    for (var k = 0; k < 50; k++) {
      final f = _tempAResistenza(t, r0) - r;
      final d =
          (_tempAResistenza(t + 1e-4, r0) - _tempAResistenza(t - 1e-4, r0)) /
          2e-4;
      final step = f / d;
      t -= step;
      if (step.abs() < 1e-9) break;
    }
    return t;
  }
}
