import 'package:flutter/material.dart';

import 'app.dart';
import 'state/cronologia.dart';
import 'state/impostazioni.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final impostazioni = await Impostazioni.carica();
  final cronologia = await Cronologia.carica();
  runApp(BreviarioApp(impostazioni: impostazioni, cronologia: cronologia));
}
