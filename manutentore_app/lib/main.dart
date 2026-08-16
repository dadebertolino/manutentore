import 'package:flutter/material.dart';

import 'app.dart';
import 'state/impostazioni.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final impostazioni = await Impostazioni.carica();
  runApp(BreviarioApp(impostazioni: impostazioni));
}
