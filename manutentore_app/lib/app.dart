import 'package:flutter/material.dart';

import 'state/cronologia.dart';
import 'state/impostazioni.dart';
import 'theme/app_theme.dart';
import 'ui/home_page.dart';

class BreviarioApp extends StatelessWidget {
  const BreviarioApp({
    required this.impostazioni,
    required this.cronologia,
    super.key,
  });

  final Impostazioni impostazioni;
  final Cronologia cronologia;

  @override
  Widget build(BuildContext context) {
    return ImpostazioniScope(
      notifier: impostazioni,
      child: CronologiaScope(
        notifier: cronologia,
        // Solo le impostazioni rifanno il MaterialApp: cambiano tema e
        // modalita', che riguardano tutta la app. La cronologia si aggiorna di
        // continuo e ricostruire tutto a ogni calcolo non servirebbe a niente
        // — se la ascolta chi la mostra, basta.
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
      ),
    );
  }
}
