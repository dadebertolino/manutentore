import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app.dart';
import 'state/cronologia.dart';
import 'state/impostazioni.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registraLicenzaFont();
  final impostazioni = await Impostazioni.carica();
  final cronologia = await Cronologia.carica();
  runApp(BreviarioApp(impostazioni: impostazioni, cronologia: cronologia));
}

/// Mette la OFL di IBM Plex nell'elenco licenze di sistema.
///
/// I font sono ridistribuiti dentro la app, e la licenza chiede che il testo
/// viaggi con loro. Averlo in `assets/fonts/OFL.txt` non basta se poi non lo
/// vede nessuno: qui finisce in `showLicensePage`, insieme a quelle dei
/// pacchetti. Il testo si legge dagli asset, non da una copia incollata nel
/// codice che poi diverge da quella distribuita.
void registraLicenzaFont() {
  LicenseRegistry.addLicense(() async* {
    final testo = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['IBM Plex'], testo);
  });
}
