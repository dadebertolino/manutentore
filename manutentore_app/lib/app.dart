import 'package:flutter/material.dart';

import 'state/impostazioni.dart';
import 'theme/app_theme.dart';
import 'ui/home_page.dart';

class BreviarioApp extends StatelessWidget {
  const BreviarioApp({required this.impostazioni, super.key});

  final Impostazioni impostazioni;

  @override
  Widget build(BuildContext context) {
    return ImpostazioniScope(
      notifier: impostazioni,
      child: ListenableBuilder(
        listenable: impostazioni,
        builder: (context, _) => MaterialApp(
          title: 'Breviario del manutentore',
          debugShowCheckedModeBanner: false,
          theme: temaChiaro(),
          darkTheme: temaScuro(),
          themeMode: switch (impostazioni.tema) {
            PreferenzaTema.chiaro => ThemeMode.light,
            PreferenzaTema.scuro => ThemeMode.dark,
            PreferenzaTema.sistema => ThemeMode.system,
          },
          home: const HomePage(),
        ),
      ),
    );
  }
}
