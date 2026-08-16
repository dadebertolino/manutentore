import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manutentore/app.dart';
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

Future<void> avvia(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final imp = await Impostazioni.carica();
  await tester.pumpWidget(BreviarioApp(impostazioni: imp));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la home elenca i calcolatori per dominio', (tester) async {
    await avvia(tester);
    expect(find.text('Breviario'), findsOneWidget);
    expect(find.text('ELETTRICO'), findsOneWidget);
    expect(find.text('Caduta di tensione'), findsOneWidget);
    // La lista e' pigra: la sezione meccanica non esiste finche' non ci si
    // scrolla sopra.
    await tester.scrollUntilVisible(find.text('MECCANICO'), 300,
        scrollable: listaHome);
    expect(find.text('MECCANICO'), findsOneWidget);
  });

  testWidgets('la ricerca filtra l\'elenco', (tester) async {
    await avvia(tester);
    await tester.enterText(find.byType(TextField).first, 'bpfo');
    await tester.pumpAndSettle();
    expect(find.text('Frequenze difetto cuscinetto'), findsOneWidget);
    expect(find.text('Caduta di tensione'), findsNothing);
  });

  testWidgets('aprire un calcolatore mostra subito un risultato',
      (tester) async {
    await avvia(tester);
    await tester.scrollUntilVisible(find.text('Coppia di serraggio'), 300,
        scrollable: listaHome);
    await tester.tap(find.text('Coppia di serraggio'));
    await tester.pumpAndSettle();
    // I default calcolano senza che l'utente tocchi nulla.
    expect(find.textContaining('90'), findsWidgets);
  });

  testWidgets('un input non valido mostra un errore leggibile',
      (tester) async {
    await avvia(tester);
    await tester.tap(find.text('Caduta di tensione'));
    await tester.pumpAndSettle();
    final campoSezione = find.widgetWithText(TextField, 'Sezione conduttore');
    await tester.enterText(campoSezione, '');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sezione'), findsWidgets);
  });

  test('ogni calcolatore del registro e\' apribile senza eccezioni', () {
    for (final c in Registro.tutti) {
      expect(() => c.compute(Inputs.defaults(c.fields)), returnsNormally,
          reason: c.id);
    }
  });
}
