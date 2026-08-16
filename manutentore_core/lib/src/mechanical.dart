import 'dart:math' as math;

import 'model.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------

/// Coppia di serraggio e precarico di una vite metrica.
class CoppiaSerraggio extends Calculator {
  const CoppiaSerraggio();

  @override
  String get id => 'me.coppia_serraggio';
  @override
  String get name => 'Coppia di serraggio';
  @override
  String get subtitle => 'Precarico e coppia per viti metriche ISO 898-1';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['bulloni', 'viti', 'torque', 'precarico', 'nm'];
  @override
  List<String> get references => [
    'ISO 898-1',
    'VDI 2230 (metodo semplificato)',
  ];
  @override
  String? get theory =>
      'Serrare non serve a "stringere" ma a creare un precarico: la vite si '
      'allunga elasticamente e tiene unite le parti. Solo il 10-15% della '
      'coppia applicata diventa precarico, il resto vince gli attriti: per '
      'questo la lubrificazione cambia tutto.';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'd',
      'Diametro nominale',
      unit: 'mm',
      min: 3,
      max: 48,
      value: 12,
    ),
    FieldSpec.number(
      'passo',
      'Passo',
      unit: 'mm',
      min: 0,
      max: 6,
      value: 0,
      help: '0 = passo grosso da tabella ISO 261.',
    ),
    FieldSpec.select(
      'classe',
      'Classe di resistenza',
      options: [
        SelectOption('4.6', '4.6'),
        SelectOption('5.8', '5.8'),
        SelectOption('8.8', '8.8'),
        SelectOption('10.9', '10.9'),
        SelectOption('12.9', '12.9'),
      ],
      value: '8.8',
    ),
    FieldSpec.select(
      'attrito',
      'Condizione di attrito',
      options: [
        SelectOption(
          'asciutto',
          'Asciutto, non trattato (K=0,20)',
          numeric: 0.20,
        ),
        SelectOption('zincato', 'Zincato asciutto (K=0,22)', numeric: 0.22),
        SelectOption('oliato', 'Leggermente oliato (K=0,16)', numeric: 0.16),
        SelectOption('grasso', 'Ingrassato (K=0,14)', numeric: 0.14),
        SelectOption(
          'mos2',
          'MoS2 / pasta antigrippante (K=0,12)',
          numeric: 0.12,
        ),
      ],
      value: 'asciutto',
    ),
    FieldSpec.number(
      'sfrutt',
      'Sfruttamento del carico di snervamento',
      min: 0.3,
      max: 0.95,
      value: 0.70,
      help: 'Tipico 0,70. Fino a 0,90 con serraggio controllato.',
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final d = i.num_('d');
    var passo = i.num_('passo');
    if (passo <= 0) {
      passo = interpola(kPassoGrosso.map((k, v) => MapEntry(k as num, v)), d);
      if (!kPassoGrosso.containsKey(d)) {
        passo = double.parse(passo.toStringAsFixed(2));
      }
    }
    var classe = i.opt('classe');
    if (classe == '8.8' && d > 16) classe = '8.8>16';
    final rp = kClasseRp[classe]!;
    final rm = kClasseRm[classe]!;
    final k = i.optNum('attrito');
    final nu = i.num_('sfrutt');

    // Sezione resistente ISO 898-1.
    final as_ = 0.7854 * math.pow(d - 0.9382 * passo, 2).toDouble();
    final precarico = nu * rp * as_; // N
    final coppia = k * (d / 1000) * precarico; // Nm
    final sigma = precarico / as_;
    final caricoRottura = rm * as_ / 1000; // kN

    return CalcResult(
      [
        ResultLine.number(
          'Coppia di serraggio',
          coppia,
          unit: 'Nm',
          decimals: 1,
          primary: true,
        ),
        ResultLine.number(
          'Forza di precarico',
          precarico / 1000,
          unit: 'kN',
          decimals: 2,
          primary: true,
        ),
        ResultLine.number(
          'Sezione resistente As',
          as_,
          unit: 'mm2',
          decimals: 2,
        ),
        ResultLine.number('Passo utilizzato', passo, unit: 'mm'),
        ResultLine.number(
          'Tensione nel gambo',
          sigma,
          unit: 'MPa',
          decimals: 0,
          note: 'Snervamento classe: ${rp.toStringAsFixed(0)} MPa',
        ),
        ResultLine.number(
          'Carico di rottura teorico',
          caricoRottura,
          unit: 'kN',
          decimals: 1,
        ),
        ResultLine.number(
          'Coppia con +20% attrito',
          coppia * 1.2,
          unit: 'Nm',
          decimals: 1,
          severity: Severity.warn,
          note: 'Dispersione tipica del serraggio a chiave dinamometrica',
        ),
      ],
      verdict:
          'M${d.toStringAsFixed(0)}x$passo classe ${i.opt('classe')}: '
          '${coppia.toStringAsFixed(0)} Nm',
      verdictSeverity: Severity.ok,
      warnings: const [
        'Valori per filetto e sottotesta nella stessa condizione di attrito.',
        'Se il costruttore indica una coppia, quella prevale sempre.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Foro di preparazione per maschiatura e dati del filetto.
class ForoMaschiatura extends Calculator {
  const ForoMaschiatura();

  @override
  String get id => 'me.foro_maschiatura';
  @override
  String get name => 'Foro per maschiatura';
  @override
  String get subtitle => 'Diametro punta, percentuale filetto, dati ISO';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['maschio', 'filetto', 'tap drill', 'punta'];
  @override
  List<String> get references => ['ISO 261', 'ISO 965-1'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'd',
      'Diametro nominale',
      unit: 'mm',
      min: 2,
      max: 48,
      value: 12,
    ),
    FieldSpec.number(
      'passo',
      'Passo',
      unit: 'mm',
      min: 0,
      max: 6,
      value: 0,
      help: '0 = passo grosso da tabella.',
    ),
    FieldSpec.number(
      'foro',
      'Diametro punta effettivo',
      unit: 'mm',
      min: 0,
      max: 48,
      value: 0,
      help: '0 = usa il valore consigliato.',
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final d = i.num_('d');
    var passo = i.num_('passo');
    if (passo <= 0) {
      passo = interpola(kPassoGrosso.map((k, v) => MapEntry(k as num, v)), d);
      passo = double.parse(passo.toStringAsFixed(2));
    }
    final consigliato = d - passo;
    var foro = i.num_('foro');
    if (foro <= 0) foro = consigliato;
    if (foro >= d) {
      throw const CalcException(
        'Il foro deve essere minore del diametro nominale.',
      );
    }

    final percFiletto = (d - foro) / (1.299 * passo) * 100;
    final d2 = d - 0.6495 * passo; // diametro medio
    final d3 = d - 1.2269 * passo; // diametro di nocciolo
    final d1int = d - 1.0825 * passo; // minore del filetto interno
    final as_ = 0.7854 * math.pow(d - 0.9382 * passo, 2).toDouble();
    final foroPassante =
        d + (d <= 6 ? 0.4 : (d <= 20 ? 1.0 : 2.0)); // serie media

    Severity sev;
    String nota;
    if (percFiletto < 60) {
      sev = Severity.fail;
      nota = 'Filetto troppo scarso: tenuta insufficiente.';
    } else if (percFiletto > 85) {
      sev = Severity.warn;
      nota = 'Filetto molto pieno: alto rischio di rottura del maschio.';
    } else {
      sev = Severity.ok;
      nota = 'Compromesso corretto tra tenuta e sforzo di maschiatura.';
    }

    return CalcResult(
      [
        ResultLine.number(
          'Punta consigliata',
          consigliato,
          unit: 'mm',
          primary: true,
        ),
        ResultLine.number(
          'Percentuale di filetto',
          percFiletto,
          unit: '%',
          decimals: 1,
          primary: true,
          severity: sev,
          note: nota,
        ),
        ResultLine.number('Passo', passo, unit: 'mm'),
        ResultLine.number('Diametro medio d2', d2, unit: 'mm', decimals: 3),
        ResultLine.number(
          'Diametro di nocciolo d3',
          d3,
          unit: 'mm',
          decimals: 3,
        ),
        ResultLine.number(
          'Diametro minore filetto interno',
          d1int,
          unit: 'mm',
          decimals: 3,
        ),
        ResultLine.number(
          'Sezione resistente As',
          as_,
          unit: 'mm2',
          decimals: 2,
        ),
        ResultLine.number(
          'Foro passante (serie media)',
          foroPassante,
          unit: 'mm',
          decimals: 1,
        ),
      ],
      verdict:
          'M${d.toStringAsFixed(0)}x$passo -> punta '
          '${consigliato.toStringAsFixed(2)} mm',
      verdictSeverity: sev,
      warnings: const [
        'Su materiali teneri (alluminio, ottone) conviene stare sul 65-70% '
            'per non strappare il filetto.',
        'Profondita\' utile di avvitamento: 1xd su acciaio, 2xd su alluminio.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Durata nominale di un cuscinetto volvente.
class VitaCuscinetto extends Calculator {
  const VitaCuscinetto();

  @override
  String get id => 'me.vita_cuscinetto';
  @override
  String get name => 'Durata cuscinetto (L10)';
  @override
  String get subtitle => 'Vita nominale in milioni di giri e in ore';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['l10h', 'bearing life', 'durata', 'volvente'];
  @override
  List<String> get references => ['ISO 281'];
  @override
  String? get theory =>
      'L10 e\' la vita raggiunta dal 90% dei cuscinetti identici. Il carico '
      'entra alla terza potenza: dimezzare il carico moltiplica la durata per '
      'otto. Ecco perche\' un disallineamento paga carissimo.';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'c',
      'Coefficiente di carico dinamico C',
      unit: 'kN',
      min: 0.01,
      max: 5000,
      value: 14.0,
    ),
    FieldSpec.number(
      'p',
      'Carico dinamico equivalente P',
      unit: 'kN',
      min: 0.001,
      max: 5000,
      value: 2.5,
    ),
    FieldSpec.number(
      'n',
      'Velocita\' di rotazione',
      unit: 'rpm',
      min: 0.1,
      max: 50000,
      value: 1450,
    ),
    FieldSpec.select(
      'tipo',
      'Tipo di corpo volvente',
      options: [
        SelectOption('sfere', 'Sfere (p=3)', numeric: 3),
        SelectOption('rulli', 'Rulli (p=10/3)', numeric: 3.3333333333333335),
      ],
      value: 'sfere',
    ),
    FieldSpec.number(
      'a1',
      'Fattore di affidabilita\' a1',
      min: 0.05,
      max: 1,
      value: 1,
      help: '1 = 90% (L10). 0,62 = 95%. 0,53 = 96%. 0,33 = 98%.',
    ),
    FieldSpec.number(
      'aiso',
      'Fattore lubrificazione/contaminazione',
      min: 0.05,
      max: 50,
      value: 1,
      help: 'Da grafici del costruttore. 1 = condizioni di riferimento.',
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final c = i.num_('c');
    final p = i.num_('p');
    final n = i.num_('n');
    final esp = i.optNum('tipo');
    final a1 = i.num_('a1');
    final aiso = i.num_('aiso');

    final rapporto = c / p;
    final l10 = math.pow(rapporto, esp).toDouble(); // milioni di giri
    final l10h = 1e6 / (60 * n) * l10;
    final lnmh = l10h * a1 * aiso;
    final anni = lnmh / 8760;
    final cRichiesto = p * math.pow(l10, 1 / esp).toDouble();

    Severity sev;
    if (rapporto < 5) {
      sev = Severity.warn;
    } else {
      sev = Severity.ok;
    }

    return CalcResult(
      [
        ResultLine.number(
          'Vita nominale L10h',
          l10h,
          unit: 'h',
          decimals: 0,
          primary: true,
        ),
        ResultLine.number(
          'Vita corretta Lnmh',
          lnmh,
          unit: 'h',
          decimals: 0,
          primary: true,
        ),
        ResultLine.number('L10 in milioni di giri', l10, decimals: 1),
        ResultLine.number(
          'Rapporto C/P',
          rapporto,
          decimals: 2,
          severity: sev,
          note: sev == Severity.warn
              ? 'C/P basso: cuscinetto molto caricato'
              : null,
        ),
        ResultLine.number('Durata in anni continui', anni, decimals: 2),
        ResultLine.number(
          'C equivalente richiesto',
          cRichiesto,
          unit: 'kN',
          decimals: 2,
        ),
      ],
      verdict: lnmh >= 20000
          ? 'Durata adeguata al servizio continuo'
          : 'Durata limitata: rivedere carico, taglia o lubrificazione',
      verdictSeverity: lnmh >= 20000 ? Severity.ok : Severity.warn,
      warnings: const [
        'La vita reale dipende anche da montaggio, allineamento e tenute: '
            'la maggior parte dei cedimenti precoci non e\' a fatica.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Frequenze caratteristiche di difetto di un cuscinetto.
class FrequenzeCuscinetto extends Calculator {
  const FrequenzeCuscinetto();

  @override
  String get id => 'me.frequenze_cuscinetto';
  @override
  String get name => 'Frequenze difetto cuscinetto';
  @override
  String get subtitle => 'BPFO, BPFI, BSF, FTF per analisi vibrazionale';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => [
    'bpfo',
    'bpfi',
    'bsf',
    'ftf',
    'vibrazioni',
    'spettro',
  ];
  @override
  List<String> get references => ['ISO 13373-3'];
  @override
  String? get theory =>
      'Ogni difetto ha la sua firma in frequenza: se lo spettro mostra un picco '
      'alla BPFO, il difetto e\' sulla pista esterna. Sono frequenze non '
      'sincrone con la rotazione, quindi non si confondono con lo sbilanciamento.';

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'n',
      'Velocita\' albero',
      unit: 'rpm',
      min: 1,
      max: 30000,
      value: 1450,
    ),
    FieldSpec.number(
      'nb',
      'Numero di corpi volventi',
      min: 3,
      max: 60,
      value: 9,
    ),
    FieldSpec.number(
      'd',
      'Diametro corpo volvente',
      unit: 'mm',
      min: 0.5,
      max: 200,
      value: 7.94,
    ),
    FieldSpec.number(
      'dp',
      'Diametro primitivo',
      unit: 'mm',
      min: 2,
      max: 2000,
      value: 39.04,
      help: 'Media tra diametro interno ed esterno se non noto.',
    ),
    FieldSpec.number(
      'alfa',
      'Angolo di contatto',
      unit: 'gradi',
      min: 0,
      max: 45,
      value: 0,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final n = i.num_('n');
    final nb = i.int_('nb');
    final d = i.num_('d');
    final dp = i.num_('dp');
    if (d >= dp) {
      throw const CalcException(
        'Il corpo volvente non puo\' essere piu\' grande del primitivo.',
      );
    }
    final alfa = i.num_('alfa') * math.pi / 180;
    final fr = n / 60;
    final k = d / dp * math.cos(alfa);

    final ftf = fr / 2 * (1 - k);
    final bpfo = nb / 2 * fr * (1 - k);
    final bpfi = nb / 2 * fr * (1 + k);
    final bsf = dp / (2 * d) * fr * (1 - k * k);

    return CalcResult(
      [
        ResultLine.number(
          'Frequenza di rotazione',
          fr,
          unit: 'Hz',
          decimals: 3,
          note: '1x',
        ),
        ResultLine.number(
          'BPFO - pista esterna',
          bpfo,
          unit: 'Hz',
          decimals: 2,
          primary: true,
          note: '${(bpfo / fr).toStringAsFixed(2)}x',
        ),
        ResultLine.number(
          'BPFI - pista interna',
          bpfi,
          unit: 'Hz',
          decimals: 2,
          primary: true,
          note: '${(bpfi / fr).toStringAsFixed(2)}x',
        ),
        ResultLine.number(
          'BSF - corpo volvente',
          bsf,
          unit: 'Hz',
          decimals: 2,
          note: '${(bsf / fr).toStringAsFixed(2)}x',
        ),
        ResultLine.number(
          'FTF - gabbia',
          ftf,
          unit: 'Hz',
          decimals: 3,
          note: '${(ftf / fr).toStringAsFixed(3)}x',
        ),
        ResultLine.number(
          '2x BSF (urto doppio)',
          2 * bsf,
          unit: 'Hz',
          decimals: 2,
        ),
        ResultLine.number(
          'Frequenza massima consigliata analisi',
          math.max(bpfi * 3.5, 10 * fr),
          unit: 'Hz',
          decimals: 0,
          note: 'Impostare Fmax dello strumento almeno a questo valore',
        ),
      ],
      verdict:
          'Difetto interno atteso a ${bpfi.toStringAsFixed(1)} Hz, '
          'esterno a ${bpfo.toStringAsFixed(1)} Hz',
      verdictSeverity: Severity.neutral,
      warnings: const [
        'Le frequenze sono teoriche: lo slittamento reale le sposta '
            'dell\'1-2%. Cercare famiglie di picchi, non il valore esatto.',
        'BPFI compare tipicamente con bande laterali distanti 1x.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Severita' vibrazionale secondo ISO 10816-3.
class SeveritaVibrazioni extends Calculator {
  const SeveritaVibrazioni();

  @override
  String get id => 'me.vibrazioni_iso';
  @override
  String get name => 'Severita\' vibrazioni';
  @override
  String get subtitle => 'Classificazione in zone A-D secondo ISO 10816-3';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['iso 10816', 'mm/s', 'rms', 'diagnostica'];
  @override
  List<String> get references => ['ISO 10816-3', 'ISO 20816-3'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'v',
      'Velocita\' efficace misurata',
      unit: 'mm/s RMS',
      min: 0,
      max: 100,
      value: 3.2,
      help: 'Banda 10-1000 Hz.',
    ),
    FieldSpec.select(
      'gruppo',
      'Taglia macchina',
      options: [
        SelectOption('G1', 'Gruppo 1: oltre 300 kW'),
        SelectOption('G2', 'Gruppo 2: da 15 a 300 kW'),
      ],
      value: 'G2',
    ),
    FieldSpec.select(
      'supporto',
      'Tipo di supporto',
      options: [
        SelectOption('rigido', 'Rigido (basamento in cemento)'),
        SelectOption('flessibile', 'Flessibile (antivibranti, telaio)'),
      ],
      value: 'rigido',
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final v = i.num_('v');
    final chiave = '${i.opt('gruppo')}-${i.opt('supporto')}';
    final soglie = kIso10816[chiave]!;

    final (zona, sev, azione) = switch (v) {
      _ when v <= soglie[0] => (
        'A',
        Severity.ok,
        'Macchina nuova o appena revisionata. Nessun intervento.',
      ),
      _ when v <= soglie[1] => (
        'B',
        Severity.ok,
        'Idonea al servizio continuo illimitato.',
      ),
      _ when v <= soglie[2] => (
        'C',
        Severity.warn,
        'Servizio limitato. Pianificare l\'intervento alla prima fermata.',
      ),
      _ => (
        'D',
        Severity.fail,
        'Danno in corso. Fermare la macchina appena possibile.',
      ),
    };

    return CalcResult(
      [
        ResultLine('Zona', zona, primary: true, severity: sev, note: azione),
        ResultLine.number(
          'Valore misurato',
          v,
          unit: 'mm/s RMS',
          primary: true,
          severity: sev,
        ),
        ResultLine.number('Limite A/B', soglie[0], unit: 'mm/s'),
        ResultLine.number('Limite B/C', soglie[1], unit: 'mm/s'),
        ResultLine.number('Limite C/D', soglie[2], unit: 'mm/s'),
        ResultLine.number(
          'Margine sul limite C/D',
          (soglie[2] - v) / soglie[2] * 100,
          unit: '%',
          decimals: 1,
        ),
      ],
      verdict: 'Zona $zona',
      verdictSeverity: sev,
      warnings: const [
        'La tendenza nel tempo conta piu\' del valore assoluto: un raddoppio '
            'rispetto alla linea di base e\' un allarme anche in zona B.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Cilindro pneumatico: forza e consumo d'aria.
class CilindroPneumatico extends Calculator {
  const CilindroPneumatico();

  @override
  String get id => 'me.cilindro_pneumatico';
  @override
  String get name => 'Cilindro pneumatico';
  @override
  String get subtitle => 'Forza in spinta e tiro, consumo d\'aria';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['pneumatica', 'attuatore', 'aria', 'nl/min'];
  @override
  List<String> get references => ['ISO 6431', 'ISO 8778 (condizioni ANR)'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'alesaggio',
      'Alesaggio',
      unit: 'mm',
      min: 4,
      max: 500,
      value: 50,
    ),
    FieldSpec.number(
      'stelo',
      'Diametro stelo',
      unit: 'mm',
      min: 2,
      max: 250,
      value: 20,
    ),
    FieldSpec.number(
      'corsa',
      'Corsa',
      unit: 'mm',
      min: 1,
      max: 5000,
      value: 200,
    ),
    FieldSpec.number(
      'p',
      'Pressione relativa',
      unit: 'bar',
      min: 0.5,
      max: 20,
      value: 6,
    ),
    FieldSpec.number(
      'rend',
      'Rendimento',
      min: 0.5,
      max: 1,
      value: 0.9,
      help: 'Attriti di tenuta: tipico 0,85-0,95.',
    ),
    FieldSpec.number('cicli', 'Cicli al minuto', min: 0, max: 600, value: 10),
  ];

  @override
  CalcResult compute(Inputs i) {
    final dAl = i.num_('alesaggio');
    final dSt = i.num_('stelo');
    if (dSt >= dAl) {
      throw const CalcException(
        'Lo stelo deve essere piu\' piccolo dell\'alesaggio.',
      );
    }
    final corsa = i.num_('corsa');
    final pBar = i.num_('p');
    final eta = i.num_('rend');
    final cicli = i.num_('cicli');

    final aSpinta = math.pi * dAl * dAl / 4; // mm2
    final aTiro = math.pi * (dAl * dAl - dSt * dSt) / 4;
    final pMpa = pBar * 0.1; // N/mm2
    final fSpinta = pMpa * aSpinta * eta;
    final fTiro = pMpa * aTiro * eta;

    // Volume in litri normali: rapporto di compressione riferito a 1,013 bar.
    final compressione = (pBar + 1.013) / 1.013;
    final volCiclo =
        (aSpinta + aTiro) * corsa / 1e6 * compressione; // litri ANR
    final portata = volCiclo * cicli; // Nl/min

    return CalcResult(
      [
        ResultLine.number(
          'Forza in spinta',
          fSpinta,
          unit: 'N',
          decimals: 0,
          primary: true,
        ),
        ResultLine.number(
          'Forza in tiro',
          fTiro,
          unit: 'N',
          decimals: 0,
          primary: true,
        ),
        ResultLine.number(
          'Massa sollevabile in spinta',
          fSpinta / 9.81,
          unit: 'kg',
          decimals: 1,
        ),
        ResultLine.number('Area di spinta', aSpinta, unit: 'mm2', decimals: 1),
        ResultLine.number('Area di tiro', aTiro, unit: 'mm2', decimals: 1),
        ResultLine.number('Rapporto tiro/spinta', fTiro / fSpinta, decimals: 3),
        ResultLine.number(
          'Consumo per ciclo',
          volCiclo,
          unit: 'Nl',
          decimals: 3,
        ),
        ResultLine.number(
          'Portata richiesta',
          portata,
          unit: 'Nl/min',
          decimals: 1,
          primary: true,
        ),
      ],
      verdict: 'Spinta ${fSpinta.toStringAsFixed(0)} N a $pBar bar',
      verdictSeverity: Severity.ok,
      warnings: const [
        'Dimensionare con un margine del 30-50% sulla forza teorica: '
            'attriti, inerzia e cadute di pressione dinamiche.',
        'Il consumo non include il riempimento di tubi e raccordi.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Coefficiente di portata di una valvola.
class CoefficienteKv extends Calculator {
  const CoefficienteKv();

  @override
  String get id => 'me.valvola_kv';
  @override
  String get name => 'Valvola: Kv e Cv';
  @override
  String get subtitle => 'Coefficiente di portata per liquidi';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['kv', 'cv', 'valvola', 'perdita di carico'];
  @override
  List<String> get references => ['IEC 60534-2-1'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.select(
      'verso',
      'Cosa calcolare',
      options: [
        SelectOption('kv', 'Kv da portata e perdita'),
        SelectOption('q', 'Portata da Kv e perdita'),
        SelectOption('dp', 'Perdita da Kv e portata'),
      ],
      value: 'kv',
    ),
    FieldSpec.number(
      'q',
      'Portata',
      unit: 'm3/h',
      min: 0,
      max: 100000,
      value: 15,
    ),
    FieldSpec.number(
      'dp',
      'Perdita di carico',
      unit: 'bar',
      min: 0,
      max: 500,
      value: 0.8,
    ),
    FieldSpec.number(
      'kv',
      'Kv valvola',
      unit: 'm3/h',
      min: 0,
      max: 100000,
      value: 16.8,
    ),
    FieldSpec.number(
      'densita',
      'Densita\' relativa',
      min: 0.1,
      max: 20,
      value: 1,
      help: 'Acqua = 1. Olio idraulico ~0,87.',
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final rho = i.num_('densita');
    var q = i.num_('q');
    var dp = i.num_('dp');
    var kv = i.num_('kv');

    final verso = i.opt('verso');
    if (verso == 'kv') {
      if (dp <= 0) throw const CalcException('La perdita deve essere > 0.');
      kv = q * math.sqrt(rho / dp);
    } else if (verso == 'q') {
      if (kv <= 0) throw const CalcException('Kv deve essere > 0.');
      q = kv * math.sqrt(dp / rho);
    } else {
      if (kv <= 0) throw const CalcException('Kv deve essere > 0.');
      dp = rho * math.pow(q / kv, 2).toDouble();
    }

    final cv = kv / 0.865;
    final dpMetri = dp * 10.197 / rho;

    return CalcResult(
      [
        ResultLine.number('Kv', kv, unit: 'm3/h', primary: true),
        ResultLine.number('Cv (unita\' imperiali)', cv, decimals: 2),
        ResultLine.number('Portata', q, unit: 'm3/h', primary: true),
        ResultLine.number('Portata', q / 3.6, unit: 'l/s', decimals: 3),
        ResultLine.number('Perdita di carico', dp, unit: 'bar', decimals: 3),
        ResultLine.number(
          'Perdita in colonna d\'acqua',
          dpMetri,
          unit: 'm',
          decimals: 2,
        ),
      ],
      verdict: 'Kv = ${kv.toStringAsFixed(1)} m3/h',
      verdictSeverity: Severity.ok,
      warnings: const [
        'Scegliere la valvola in modo che lavori tra il 20% e l\'80% della '
            'corsa: fuori da questa fascia la regolazione peggiora.',
        'Formula valida per liquidi non cavitanti.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Trasmissione a cinghia o a pulegge.
class TrasmissionePulegge extends Calculator {
  const TrasmissionePulegge();

  @override
  String get id => 'me.trasmissione_pulegge';
  @override
  String get name => 'Trasmissione a pulegge';
  @override
  String get subtitle => 'Rapporto, velocita\', lunghezza cinghia';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['cinghia', 'puleggia', 'rapporto', 'interasse'];
  @override
  List<String> get references => ['ISO 4184'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.number(
      'n1',
      'Velocita\' motrice',
      unit: 'rpm',
      min: 0.1,
      max: 30000,
      value: 1450,
    ),
    FieldSpec.number(
      'd1',
      'Diametro puleggia motrice',
      unit: 'mm',
      min: 5,
      max: 3000,
      value: 100,
    ),
    FieldSpec.number(
      'd2',
      'Diametro puleggia condotta',
      unit: 'mm',
      min: 5,
      max: 5000,
      value: 250,
    ),
    FieldSpec.number(
      'interasse',
      'Interasse',
      unit: 'mm',
      min: 10,
      max: 20000,
      value: 600,
    ),
    FieldSpec.number(
      'p',
      'Potenza trasmessa',
      unit: 'kW',
      min: 0,
      max: 5000,
      value: 7.5,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    final n1 = i.num_('n1');
    final d1 = i.num_('d1');
    final d2 = i.num_('d2');
    final c = i.num_('interasse');
    final p = i.num_('p');

    final rapporto = d2 / d1;
    final n2 = n1 / rapporto;
    final v = math.pi * d1 / 1000 * n1 / 60; // m/s
    final lung =
        2 * c +
        math.pi * (d1 + d2) / 2 +
        math.pow(d2 - d1, 2).toDouble() / (4 * c);
    final abbraccio = 180 - 2 * math.asin((d2 - d1) / (2 * c)) * 180 / math.pi;
    final c1 = p > 0 ? 9550 * p / n1 : 0.0;
    final c2 = p > 0 ? 9550 * p / n2 : 0.0;

    final veloce = v > 30;
    final abbraccioBasso = abbraccio < 120;

    return CalcResult(
      [
        ResultLine.number(
          'Rapporto di trasmissione',
          rapporto,
          decimals: 3,
          primary: true,
        ),
        ResultLine.number(
          'Velocita\' condotta',
          n2,
          unit: 'rpm',
          decimals: 1,
          primary: true,
        ),
        ResultLine.number(
          'Velocita\' periferica',
          v,
          unit: 'm/s',
          severity: veloce ? Severity.warn : Severity.ok,
        ),
        ResultLine.number(
          'Lunghezza primitiva cinghia',
          lung,
          unit: 'mm',
          decimals: 0,
        ),
        ResultLine.number(
          'Angolo di avvolgimento sulla piccola',
          abbraccio,
          unit: 'gradi',
          decimals: 1,
          severity: abbraccioBasso ? Severity.warn : Severity.ok,
        ),
        if (p > 0) ResultLine.number('Coppia motrice', c1, unit: 'Nm'),
        if (p > 0) ResultLine.number('Coppia condotta', c2, unit: 'Nm'),
      ],
      verdict:
          'Riduzione ${rapporto.toStringAsFixed(2)}:1 -> '
          '${n2.toStringAsFixed(0)} rpm',
      verdictSeverity: (veloce || abbraccioBasso) ? Severity.warn : Severity.ok,
      warnings: [
        if (abbraccioBasso)
          'Avvolgimento sotto 120 gradi: rischio di slittamento, aumentare '
              'l\'interasse o usare un rullo tenditore.',
        if (veloce) 'Oltre 30 m/s servono pulegge equilibrate dinamicamente.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Relazione tra potenza, coppia e velocita'.
class PotenzaCoppiaVelocita extends Calculator {
  const PotenzaCoppiaVelocita();

  @override
  String get id => 'me.potenza_coppia';
  @override
  String get name => 'Potenza, coppia, velocita\'';
  @override
  String get subtitle => 'Conversione tra le tre grandezze';
  @override
  Domain get domain => Domain.meccanico;
  @override
  List<String> get tags => ['coppia', 'nm', 'kw', 'rpm', 'torque'];

  @override
  List<FieldSpec> get fields => const [
    FieldSpec.select(
      'incognita',
      'Cosa calcolare',
      options: [
        SelectOption('c', 'Coppia'),
        SelectOption('p', 'Potenza'),
        SelectOption('n', 'Velocita\''),
      ],
      value: 'c',
    ),
    FieldSpec.number(
      'p',
      'Potenza',
      unit: 'kW',
      min: 0,
      max: 100000,
      value: 7.5,
    ),
    FieldSpec.number(
      'n',
      'Velocita\'',
      unit: 'rpm',
      min: 0,
      max: 100000,
      value: 1440,
    ),
    FieldSpec.number(
      'c',
      'Coppia',
      unit: 'Nm',
      min: 0,
      max: 1000000,
      value: 49.7,
    ),
    FieldSpec.number(
      'rend',
      'Rendimento della catena cinematica',
      min: 0.1,
      max: 1,
      value: 1,
    ),
  ];

  @override
  CalcResult compute(Inputs i) {
    var p = i.num_('p');
    var n = i.num_('n');
    var c = i.num_('c');
    final eta = i.num_('rend');

    final incognita = i.opt('incognita');
    if (incognita == 'c') {
      if (n <= 0) throw const CalcException('La velocita\' deve essere > 0.');
      c = 9550 * p / n;
    } else if (incognita == 'p') {
      p = c * n / 9550;
    } else {
      if (c <= 0) throw const CalcException('La coppia deve essere > 0.');
      n = 9550 * p / c;
    }

    final omega = n * 2 * math.pi / 60;
    final pAlbero = p / eta;

    return CalcResult([
      ResultLine.number('Coppia', c, unit: 'Nm', primary: true),
      ResultLine.number('Potenza', p, unit: 'kW', decimals: 3, primary: true),
      ResultLine.number(
        'Velocita\'',
        n,
        unit: 'rpm',
        decimals: 1,
        primary: true,
      ),
      ResultLine.number(
        'Velocita\' angolare',
        omega,
        unit: 'rad/s',
        decimals: 3,
      ),
      ResultLine.number('Potenza in cavalli', p * 1.35962, unit: 'CV'),
      if (eta < 1)
        ResultLine.number(
          'Potenza richiesta a monte',
          pAlbero,
          unit: 'kW',
          decimals: 3,
        ),
    ], verdictSeverity: Severity.ok);
  }
}
