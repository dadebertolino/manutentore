import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manutentore/app.dart';
import 'package:manutentore/state/cronologia.dart';
import 'package:manutentore/state/impostazioni.dart';
import 'package:manutentore_core/manutentore_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La lista della home. Va indicata esplicitamente: il campo di ricerca e' a
/// sua volta scrollabile, quindi `scrollUntilVisible` da solo non sa a quale
/// dei due riferirsi.
final listaHome = find.descendant(
  of: find.byType(ListView),
  matching: find.byType(Scrollable),
);

/// Avvia la app e restituisce la cronologia, per poterla ispezionare nei test.
Future<Cronologia> avvia(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final imp = await Impostazioni.carica();
  final cron = await Cronologia.carica();
  await tester.pumpWidget(BreviarioApp(impostazioni: imp, cronologia: cron));
  await tester.pumpAndSettle();
  return cron;
}

void main() {
  testWidgets('la home elenca i calcolatori per dominio', (tester) async {
    await avvia(tester);
    expect(find.text('Breviario'), findsOneWidget);
    expect(find.text('ELETTRICO'), findsOneWidget);
    expect(find.text('Caduta di tensione'), findsOneWidget);
    // La lista e' pigra: la sezione meccanica non esiste finche' non ci si
    // scrolla sopra.
    await tester.scrollUntilVisible(
      find.text('MECCANICO'),
      300,
      scrollable: listaHome,
    );
    expect(find.text('MECCANICO'), findsOneWidget);
  });

  testWidgets('la ricerca filtra l\'elenco', (tester) async {
    await avvia(tester);
    await tester.enterText(find.byType(TextField).first, 'bpfo');
    await tester.pumpAndSettle();
    expect(find.text('Frequenze difetto cuscinetto'), findsOneWidget);
    expect(find.text('Caduta di tensione'), findsNothing);
  });

  testWidgets('aprire un calcolatore mostra subito un risultato', (
    tester,
  ) async {
    await avvia(tester);
    await tester.scrollUntilVisible(
      find.text('Coppia di serraggio'),
      300,
      scrollable: listaHome,
    );
    await tester.tap(find.text('Coppia di serraggio'));
    await tester.pumpAndSettle();
    // I default calcolano senza che l'utente tocchi nulla.
    expect(find.textContaining('90'), findsWidgets);
  });

  testWidgets('un input non valido mostra un errore leggibile', (tester) async {
    await avvia(tester);
    await tester.tap(find.text('Caduta di tensione'));
    await tester.pumpAndSettle();
    final campoSezione = find.widgetWithText(TextField, 'Sezione conduttore');
    await tester.enterText(campoSezione, '');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sezione'), findsWidgets);
  });

  test('ogni calcolatore del registro è apribile senza eccezioni', () {
    for (final c in Registro.tutti) {
      expect(
        () => c.compute(Inputs.defaults(c.fields)),
        returnsNormally,
        reason: c.id,
      );
    }
  });

  group('cronologia', () {
    testWidgets('un calcolo modificato finisce in cronologia all\'uscita', (
      tester,
    ) async {
      final cron = await avvia(tester);
      await tester.tap(find.text('Caduta di tensione'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Lunghezza linea'),
        '75',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(cron.voci, hasLength(1));
      expect(cron.voci.first.calcId, 'el.caduta_tensione');
      expect(cron.voci.first.valori['lung'], 75);
    });

    testWidgets('aprire e uscire senza toccare niente non registra nulla', (
      tester,
    ) async {
      final cron = await avvia(tester);
      await tester.tap(find.text('Caduta di tensione'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(cron.voci, isEmpty);
    });

    testWidgets('una voce riapre il calcolatore con i suoi input', (
      tester,
    ) async {
      await avvia(tester);
      await tester.tap(find.text('Caduta di tensione'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Lunghezza linea'),
        '75',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cronologia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caduta di tensione'));
      await tester.pumpAndSettle();

      final campo = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Lunghezza linea'),
      );
      expect(campo.controller?.text, '75');
    });

    test('lo stesso calcolo non occupa due posizioni', () async {
      SharedPreferences.setMockInitialValues({});
      final cron = await Cronologia.carica();
      VoceCronologia voce(int lung, DateTime t) => VoceCronologia(
        calcId: 'el.caduta_tensione',
        valori: {'lung': lung},
        quando: t,
      );
      final t0 = DateTime(2026, 1, 1);
      cron.registra(voce(45, t0));
      cron.registra(voce(75, t0.add(const Duration(minutes: 1))));
      cron.registra(voce(45, t0.add(const Duration(minutes: 2))));

      expect(cron.voci, hasLength(2));
      // Il piu' recente e' in cima, anche se era gia' stato fatto prima.
      expect(cron.voci.first.valori['lung'], 45);
    });

    test('oltre il massimo cadono le voci più vecchie', () async {
      SharedPreferences.setMockInitialValues({});
      final cron = await Cronologia.carica();
      for (var i = 0; i < Cronologia.massimo + 10; i++) {
        cron.registra(
          VoceCronologia(
            calcId: 'el.caduta_tensione',
            valori: {'lung': i},
            quando: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          ),
        );
      }
      expect(cron.voci, hasLength(Cronologia.massimo));
      expect(cron.voci.first.valori['lung'], Cronologia.massimo + 9);
    });

    test('le voci sopravvivono a un riavvio', () async {
      SharedPreferences.setMockInitialValues({});
      final prima = await Cronologia.carica();
      prima.registra(
        VoceCronologia(
          calcId: 'me.coppia_serraggio',
          valori: const {'d': 12.0, 'classe': '8.8', 'lubrificato': true},
          quando: DateTime(2026, 1, 1),
          sintesi: 'Coppia: 90 Nm',
        ),
      );

      final dopo = await Cronologia.carica();
      expect(dopo.voci, hasLength(1));
      final v = dopo.voci.first;
      expect(v.calcId, 'me.coppia_serraggio');
      expect(v.valori['d'], 12.0);
      expect(v.valori['classe'], '8.8');
      expect(v.valori['lubrificato'], true);
      expect(v.sintesi, 'Coppia: 90 Nm');
    });

    test('una voce illeggibile non impedisce di leggere le altre', () async {
      SharedPreferences.setMockInitialValues({
        'cronologia': <String>[
          'non è json',
          '{"id":"el.caduta_tensione","v":{"lung":45},"t":1767225600000}',
          '{"manca":"tutto"}',
        ],
      });
      final cron = await Cronologia.carica();
      expect(cron.voci, hasLength(1));
      expect(cron.voci.first.calcId, 'el.caduta_tensione');
    });
  });
}
