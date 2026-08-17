import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../versione.dart';

/// Chi ha fatto la app, cosa promette, e a quali condizioni.
///
/// E' anche **l'unico posto dove sta il disclaimer** (HANDOFF §8): ripeterlo a
/// ogni schermata lo renderebbe invisibile, e il punto e' che venga letto una
/// volta e resti reperibile.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      appBar: AppBar(title: const Text('Informazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(T.s4, T.s2, T.s4, T.s6),
        children: [
          Text(
            'Breviario del manutentore',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: T.s1),
          Text(
            'Versione $versioneApp ($buildApp)',
            style: TextStyle(
              fontFamily: T.mono,
              fontSize: 12.5,
              color: c.muted,
            ),
          ),
          const SizedBox(height: T.s4),
          Text(
            'Calcolatori per diagnostica e riparazione, elettrici e meccanici. '
            'Pensato per il campo: si apre, si tira fuori un numero '
            'difendibile, si chiude.',
            style: TextStyle(fontSize: 14, height: 1.45, color: c.muted),
          ),
          const SizedBox(height: T.s5),

          const _Titolo('Autore'),
          Text(
            'Davide Bertolino, docente di elettronica e automazione\n'
            'IIS Cigna-Baruffi-Garelli, Mondovì (CN)',
            style: TextStyle(fontSize: 14, height: 1.45, color: c.muted),
          ),
          const SizedBox(height: T.s5),

          const _Titolo('Privacy'),
          Text(
            'Nessuna pubblicità, nessun account, nessuna raccolta dati, '
            'nessuna richiesta di rete. I calcoli, i preferiti e la cronologia '
            'restano su questo telefono e non vengono inviati da nessuna '
            'parte. I rapportini PDF nascono qui e li condividi tu, se e '
            'quando vuoi.',
            style: TextStyle(fontSize: 14, height: 1.45, color: c.muted),
          ),
          const SizedBox(height: T.s5),

          const _Titolo('Limiti d\'uso'),
          Container(
            padding: const EdgeInsets.all(T.s3),
            decoration: BoxDecoration(
              border: const Border(left: BorderSide(color: T.giallo, width: 3)),
              color: c.plate,
            ),
            child: Text(
              'I risultati danno un ordine di grandezza verificabile e citano '
              'la norma di riferimento, ma non sostituiscono la consultazione '
              'della norma né il progetto firmato da un tecnico abilitato. '
              'Le tabelle coprono le taglie più ricorrenti, non tutte: fuori '
              'da quelle l\'app lo dice invece di interpolare di nascosto.',
              style: TextStyle(fontSize: 13.5, height: 1.45, color: c.muted),
            ),
          ),
          const SizedBox(height: T.s5),

          const _Titolo('Licenze'),
          Text(
            'I caratteri sono IBM Plex Sans e IBM Plex Mono, distribuiti con '
            'SIL Open Font License 1.1 e inclusi nella app, mai scaricati.',
            style: TextStyle(fontSize: 14, height: 1.45, color: c.muted),
          ),
          const SizedBox(height: T.s3),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Licenze del software'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Breviario del manutentore',
              applicationVersion: '$versioneApp ($buildApp)',
              applicationLegalese: '© Davide Bertolino',
            ),
          ),
        ],
      ),
    );
  }
}

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: T.s2),
    child: Text(
      testo.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
        color: context.c.muted,
      ),
    ),
  );
}
