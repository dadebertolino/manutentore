import 'package:manutentore_core/manutentore_core.dart';
import 'package:test/test.dart';

/// Confronto con tolleranza relativa.
void quasi(double atteso, double ottenuto, {double tol = 1e-3}) {
  expect(ottenuto, closeTo(atteso, atteso.abs() * tol + 1e-9));
}

void main() {
  group('Registro', () {
    test('integrità del registro', () {
      expect(Registro.verificaIntegrita(), isEmpty);
    });

    test('ogni calcolatore ha id, nome e campi', () {
      for (final c in Registro.tutti) {
        expect(c.id, contains('.'));
        expect(c.name, isNotEmpty);
        expect(c.fields, isNotEmpty);
      }
    });

    test('ricerca per nome, tag e sinonimo', () {
      expect(Registro.cerca('coppia').first.id, 'me.coppia_serraggio');
      expect(
        Registro.cerca('bpfo').map((c) => c.id),
        contains('me.frequenze_cuscinetto'),
      );
      expect(
        Registro.cerca('cosfi').map((c) => c.id),
        contains('el.rifasamento'),
      );
      expect(Registro.cerca('zzzz'), isEmpty);
    });

    test('la ricerca ignora gli accenti', () {
      // I nomi dei calcolatori portano l'accento vero ("Severità
      // vibrazioni"), ma in campo si digita senza. Chi tocca _normalizza
      // deve far cadere questo test, non accorgersene dagli utenti.
      expect(
        Registro.cerca('severita').map((c) => c.id),
        contains('me.vibrazioni_iso'),
      );
      expect(
        Registro.cerca('severità').map((c) => c.id),
        contains('me.vibrazioni_iso'),
      );
      expect(
        Registro.cerca('velocita').map((c) => c.id),
        contains('me.potenza_coppia'),
      );
    });

    test('input non numerico produce messaggio utile', () {
      expect(
        () => const CadutaDiTensione().run({
          'sistema': 'tri',
          'un': 400.0,
          'ib': 32.0,
          'lung': 45.0,
          'sez': 'abc',
          'mat': 'Cu',
          'cosphi': 0.9,
          'temp': 70.0,
          'reatt': 0.08,
          'limite': 4.0,
        }),
        throwsA(
          predicate((e) => e is CalcException && e.message.contains('Sezione')),
        ),
      );
    });
  });

  group('Elettrico', () {
    test('caduta di tensione trifase 32 A, 45 m, 10 mm2 Cu', () {
      final r = const CadutaDiTensione().run({
        'sistema': 'tri',
        'un': 400.0,
        'ib': 32.0,
        'lung': 45.0,
        'sez': 10.0,
        'mat': 'Cu',
        'cosphi': 0.9,
        'temp': 70.0,
        'reatt': 0.08,
        'limite': 4.0,
      });
      quasi(4.7176, r.numeric('Caduta di tensione'));
      quasi(1.1794, r.numeric('Caduta percentuale'));
      expect(r.verdictSeverity, Severity.ok);
    });

    test('caduta oltre il limite viene segnalata', () {
      final r = const CadutaDiTensione().run({
        'sistema': 'tri',
        'un': 400.0,
        'ib': 32.0,
        'lung': 400.0,
        'sez': 4.0,
        'mat': 'Cu',
        'cosphi': 0.9,
        'temp': 70.0,
        'reatt': 0.08,
        'limite': 4.0,
      });
      expect(r.verdictSeverity, Severity.fail);
      expect(r.numeric('Caduta percentuale'), greaterThan(4));
    });

    test('portata cavo con declassamento termico e di fascio', () {
      final r = const PortataCavo().run({
        'sez': 10.0,
        'iso': 'PVC',
        'posa': 'B1',
        'ncond': '3',
        'tamb': 40.0,
        'circuiti': 4.0,
        'ib': 32.0,
      });
      quasi(50, r.numeric('Portata a 30 C (Iz0)'));
      quasi(0.87, r.numeric('k1 temperatura'));
      quasi(0.65, r.numeric('k2 raggruppamento'));
      quasi(28.275, r.numeric('Portata effettiva Iz'));
      expect(r.verdictSeverity, Severity.fail);
    });

    test('sezione non in tabella genera errore esplicito', () {
      expect(
        () => const PortataCavo().run({'sez': 11.0}),
        throwsA(isA<CalcException>()),
      );
    });

    test('sezione minima al cortocircuito', () {
      final r = const CoordinamentoProtezione().run({
        'ib': 28.0,
        'in': 32.0,
        'iz': 42.9,
        'sez': 10.0,
        'k': 'Cu-PVC',
        'icc': 6000.0,
        'tint': 0.1,
      });
      quasi(16.4988, r.numeric('Sezione minima al cortocircuito'));
      expect(r.line('Ib <= In').severity, Severity.ok);
      expect(r.verdictSeverity, Severity.fail); // 10 mm2 insufficienti
    });

    test('anello di guasto entro il limite', () {
      final r = const AnelloDiGuasto().run({
        'u0': 230.0,
        'in': 32.0,
        'curva': 'C',
        'zsMis': 0.45,
        'cmin': 0.95,
      });
      quasi(320, r.numeric('Corrente di intervento Ia'));
      quasi(0.6828, r.numeric('Zs massima ammessa'));
      expect(r.verdictSeverity, Severity.ok);
    });

    test('rifasamento 30 kW da 0,75 a 0,95', () {
      final r = const Rifasamento().run({
        'p': 30.0,
        'cos1': 0.75,
        'cos2': 0.95,
        'un': 400.0,
      });
      quasi(16.597, r.numeric('Potenza reattiva necessaria'));
      quasi(
        110.06,
        r.numeric('Capacità per fase (triangolo, 50 Hz)'),
        tol: 2e-3,
      );
      quasi(21.05, r.numeric('Riduzione di corrente'), tol: 5e-3);
    });

    test('rifasamento in senso inverso è rifiutato', () {
      expect(
        () => const Rifasamento().run({
          'p': 30.0,
          'cos1': 0.95,
          'cos2': 0.75,
          'un': 400.0,
        }),
        throwsA(isA<CalcException>()),
      );
    });

    test('motore 7,5 kW 4 poli', () {
      final r = const MotoreAsincrono().run({
        'pn': 7.5,
        'un': 400.0,
        'cosphi': 0.85,
        'rend': 0.88,
        'freq': 50.0,
        'poli': 4.0,
        'ngiri': 1440.0,
        'rapporto': 6.5,
      });
      quasi(14.4724, r.numeric('Corrente nominale'));
      quasi(49.7396, r.numeric('Coppia nominale'));
      quasi(1500, r.numeric('Velocità di sincronismo'));
      quasi(4.0, r.numeric('Scorrimento'));
      quasi(94.07, r.numeric('Corrente di spunto (diretto)'), tol: 2e-3);
    });

    test('poli dispari rifiutati', () {
      expect(
        () => const MotoreAsincrono().run({
          'pn': 7.5,
          'un': 400.0,
          'cosphi': 0.85,
          'rend': 0.88,
          'freq': 50.0,
          'poli': 3.0,
          'ngiri': 1440.0,
          'rapporto': 6.5,
        }),
        throwsA(isA<CalcException>()),
      );
    });

    test('scaling 4-20 mA', () {
      final r = const SegnaleAnalogico().run({
        'tipo': '4-20',
        'verso': 's2p',
        'val': 12.8,
        'pvMin': 0.0,
        'pvMax': 250.0,
        'bit': 12.0,
      });
      quasi(137.5, r.numeric('Grandezza di processo'));
      quasi(55.0, r.numeric('Percentuale scala'));
      quasi(2252, r.numeric('Conteggi ADC a 12 bit'), tol: 1e-3);
    });

    test('4-20 mA: conversione inversa coerente', () {
      final r = const SegnaleAnalogico().run({
        'tipo': '4-20',
        'verso': 'p2s',
        'val': 137.5,
        'pvMin': 0.0,
        'pvMax': 250.0,
        'bit': 12.0,
      });
      quasi(12.8, r.numeric('Segnale'));
    });

    test('rottura linea sotto 3,6 mA', () {
      final r = const SegnaleAnalogico().run({
        'tipo': '4-20',
        'verso': 's2p',
        'val': 2.0,
        'pvMin': 0.0,
        'pvMax': 250.0,
        'bit': 12.0,
      });
      expect(r.verdictSeverity, Severity.fail);
    });

    test('PT100 a 119,4 ohm', () {
      final r = const TermoresistenzaPt().run({
        'tipo': 'pt100',
        'verso': 'r2t',
        'val': 119.4,
        'rCavo': 0.0,
      });
      quasi(50.0075, r.numeric('Temperatura'));
    });

    test('PT100 andata e ritorno coerenti anche sotto zero', () {
      final diretta = const TermoresistenzaPt().run({
        'tipo': 'pt100',
        'verso': 't2r',
        'val': -40.0,
        'rCavo': 0.0,
      });
      final r = diretta.numeric('Resistenza sensore');
      final inversa = const TermoresistenzaPt().run({
        'tipo': 'pt100',
        'verso': 'r2t',
        'val': r,
        'rCavo': 0.0,
      });
      quasi(-40.0, inversa.numeric('Temperatura'), tol: 1e-4);
    });

    test('PT1000 scala di dieci volte', () {
      final r = const TermoresistenzaPt().run({
        'tipo': 'pt1000',
        'verso': 't2r',
        'val': 100.0,
        'rCavo': 0.0,
      });
      quasi(1385.055, r.numeric('Resistenza sensore'), tol: 1e-4);
    });
  });

  group('Meccanico', () {
    test('coppia M12 classe 8.8 asciutto', () {
      final r = const CoppiaSerraggio().run({
        'd': 12.0,
        'passo': 0.0,
        'classe': '8.8',
        'attrito': 'asciutto',
        'sfrutt': 0.70,
      });
      quasi(84.2666, r.numeric('Sezione resistente As'));
      quasi(37.75, r.numeric('Forza di precarico'), tol: 2e-3);
      quasi(90.6, r.numeric('Coppia di serraggio'), tol: 2e-3);
      quasi(1.75, r.numeric('Passo utilizzato'));
    });

    test('la 8.8 sopra M16 usa Rp maggiorato', () {
      final r = const CoppiaSerraggio().run({
        'd': 20.0,
        'passo': 0.0,
        'classe': '8.8',
        'attrito': 'asciutto',
        'sfrutt': 0.70,
      });
      quasi(462, r.numeric('Tensione nel gambo'), tol: 2e-3);
    });

    test('lubrificazione riduce la coppia', () {
      double coppia(String attrito) => const CoppiaSerraggio()
          .run({
            'd': 12.0,
            'passo': 0.0,
            'classe': '8.8',
            'attrito': attrito,
            'sfrutt': 0.70,
          })
          .numeric('Coppia di serraggio');
      expect(coppia('mos2'), lessThan(coppia('asciutto')));
      quasi(0.6, coppia('mos2') / coppia('asciutto'));
    });

    test('foro maschiatura M12', () {
      final r = const ForoMaschiatura().run({
        'd': 12.0,
        'passo': 0.0,
        'foro': 0.0,
      });
      quasi(10.25, r.numeric('Punta consigliata'));
      quasi(76.98, r.numeric('Percentuale di filetto'), tol: 2e-3);
      expect(r.verdictSeverity, Severity.ok);
    });

    test('foro troppo grande segnala filetto scarso', () {
      final r = const ForoMaschiatura().run({
        'd': 12.0,
        'passo': 1.75,
        'foro': 11.2,
      });
      expect(r.verdictSeverity, Severity.fail);
    });

    test('durata cuscinetto 6205', () {
      final r = const VitaCuscinetto().run({
        'c': 14.0,
        'p': 2.5,
        'n': 1450.0,
        'tipo': 'sfere',
        'a1': 1.0,
        'aiso': 1.0,
      });
      quasi(175.616, r.numeric('L10 in milioni di giri'));
      quasi(2018.57, r.numeric('Vita nominale L10h'), tol: 1e-3);
    });

    test('dimezzare il carico moltiplica la vita per otto', () {
      double vita(double p) => const VitaCuscinetto()
          .run({
            'c': 14.0,
            'p': p,
            'n': 1450.0,
            'tipo': 'sfere',
            'a1': 1.0,
            'aiso': 1.0,
          })
          .numeric('L10 in milioni di giri');
      quasi(8.0, vita(1.25) / vita(2.5));
    });

    test('frequenze di difetto 6205 a 1450 rpm', () {
      final r = const FrequenzeCuscinetto().run({
        'n': 1450.0,
        'nb': 9.0,
        'd': 7.94,
        'dp': 39.04,
        'alfa': 0.0,
      });
      quasi(24.1667, r.numeric('Frequenza di rotazione'));
      quasi(86.632, r.numeric('BPFO - pista esterna'));
      quasi(130.868, r.numeric('BPFI - pista interna'));
      quasi(56.955, r.numeric('BSF - corpo volvente'));
      quasi(9.626, r.numeric('FTF - gabbia'));
    });

    test('BPFO + BPFI = nb x fr', () {
      final r = const FrequenzeCuscinetto().run({
        'n': 1450.0,
        'nb': 9.0,
        'd': 7.94,
        'dp': 39.04,
        'alfa': 0.0,
      });
      quasi(
        9 * 24.1667,
        r.numeric('BPFO - pista esterna') + r.numeric('BPFI - pista interna'),
      );
    });

    test('severità vibrazioni ISO 10816', () {
      final r = const SeveritaVibrazioni().run({
        'v': 3.2,
        'gruppo': 'G2',
        'supporto': 'rigido',
      });
      expect(r.line('Zona').value, 'C');
      expect(r.verdictSeverity, Severity.warn);

      final grave = const SeveritaVibrazioni().run({
        'v': 8.0,
        'gruppo': 'G2',
        'supporto': 'rigido',
      });
      expect(grave.line('Zona').value, 'D');
      expect(grave.verdictSeverity, Severity.fail);

      final buona = const SeveritaVibrazioni().run({
        'v': 1.0,
        'gruppo': 'G2',
        'supporto': 'rigido',
      });
      expect(buona.line('Zona').value, 'A');
    });

    test('cilindro 50/20 a 6 bar', () {
      final r = const CilindroPneumatico().run({
        'alesaggio': 50.0,
        'stelo': 20.0,
        'corsa': 200.0,
        'p': 6.0,
        'rend': 0.9,
        'cicli': 10.0,
      });
      quasi(1963.495, r.numeric('Area di spinta'));
      quasi(1060.29, r.numeric('Forza in spinta'), tol: 2e-3);
      quasi(890.64, r.numeric('Forza in tiro'), tol: 2e-3);
      quasi(5.002, r.numeric('Consumo per ciclo'));
      quasi(50.02, r.numeric('Portata richiesta'), tol: 2e-3);
    });

    test('stelo più grande dell\'alesaggio è rifiutato', () {
      expect(
        () => const CilindroPneumatico().run({
          'alesaggio': 20.0,
          'stelo': 50.0,
          'corsa': 100.0,
          'p': 6.0,
          'rend': 0.9,
          'cicli': 0.0,
        }),
        throwsA(isA<CalcException>()),
      );
    });

    test('Kv da portata e perdita', () {
      final r = const CoefficienteKv().run({
        'verso': 'kv',
        'q': 15.0,
        'dp': 0.8,
        'kv': 0.0,
        'densita': 1.0,
      });
      quasi(16.7705, r.numeric('Kv'));
      quasi(19.388, r.numeric('Cv (unità imperiali)'));
    });

    test('Kv: i tre versi sono coerenti', () {
      final kv = const CoefficienteKv()
          .run({'verso': 'kv', 'q': 15.0, 'dp': 0.8, 'kv': 0.0, 'densita': 1.0})
          .numeric('Kv');
      final q = const CoefficienteKv()
          .run({'verso': 'q', 'q': 0.0, 'dp': 0.8, 'kv': kv, 'densita': 1.0})
          .numeric('Portata');
      quasi(15.0, q);
      final dp = const CoefficienteKv()
          .run({'verso': 'dp', 'q': 15.0, 'dp': 0.0, 'kv': kv, 'densita': 1.0})
          .numeric('Perdita di carico');
      quasi(0.8, dp);
    });

    test('trasmissione a pulegge 100/250', () {
      final r = const TrasmissionePulegge().run({
        'n1': 1450.0,
        'd1': 100.0,
        'd2': 250.0,
        'interasse': 600.0,
        'p': 7.5,
      });
      quasi(2.5, r.numeric('Rapporto di trasmissione'));
      quasi(580.0, r.numeric('Velocità condotta'));
      quasi(7.5922, r.numeric('Velocità periferica'));
      quasi(1759.15, r.numeric('Lunghezza primitiva cinghia'), tol: 1e-3);
      quasi(
        165.64,
        r.numeric('Angolo di avvolgimento sulla piccola'),
        tol: 2e-3,
      );
    });

    test('potenza-coppia-velocità invertibile', () {
      final c = const PotenzaCoppiaVelocita()
          .run({'incognita': 'c', 'p': 7.5, 'n': 1440.0, 'c': 0.0, 'rend': 1.0})
          .numeric('Coppia');
      quasi(49.7396, c);
      final p = const PotenzaCoppiaVelocita()
          .run({'incognita': 'p', 'p': 0.0, 'n': 1440.0, 'c': c, 'rend': 1.0})
          .numeric('Potenza');
      quasi(7.5, p);
      final n = const PotenzaCoppiaVelocita()
          .run({'incognita': 'n', 'p': 7.5, 'n': 0.0, 'c': c, 'rend': 1.0})
          .numeric('Velocità');
      quasi(1440.0, n);
    });
  });
}
