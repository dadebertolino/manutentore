import 'package:flutter/material.dart';
import 'package:manutentore_core/manutentore_core.dart';

import '../state/cronologia.dart';
import '../state/impostazioni.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'calcolatore_page.dart';
import 'cronologia_page.dart';
import 'info_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ricerca = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ricerca.dispose();
    super.dispose();
  }

  void _apri(Calculator c) {
    // Riparte dagli ultimi valori usati, se ce ne sono: la cronologia li ha
    // gia' salvati per calcolatore, qui basta rileggerli.
    final valori = CronologiaScope.of(context).ultimiValori(c.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalcolatorePage(calcolatore: c, valoriIniziali: valori),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final impostazioni = ImpostazioniScope.of(context);
    final cercando = _query.trim().isNotEmpty;
    final risultati = cercando ? Registro.cerca(_query) : const <Calculator>[];
    final preferiti = Registro.tutti
        .where((c) => impostazioni.isPreferito(c.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breviario'),
        actions: [
          IconButton(
            tooltip: 'Cronologia',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CronologiaPage()),
            ),
          ),
          IconButton(
            tooltip: 'Impostazioni',
            icon: const Icon(Icons.tune),
            onPressed: () => _mostraImpostazioni(context, impostazioni),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(T.s4, 0, T.s4, T.s3),
            child: TextField(
              controller: _ricerca,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cerca: coppia, bpfo, cosfi, pt100...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: cercando
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _ricerca.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: cercando
                ? _ElencoPiatto(
                    calcolatori: risultati,
                    onTap: _apri,
                    vuoto: 'Nessun calcolatore per "$_query".',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: T.s6),
                    children: [
                      if (preferiti.isNotEmpty)
                        _Sezione(
                          titolo: 'Preferiti',
                          calcolatori: preferiti,
                          onTap: _apri,
                        ),
                      _Sezione(
                        titolo: 'Elettrico',
                        calcolatori: Registro.byDomain(Domain.elettrico),
                        onTap: _apri,
                      ),
                      _Sezione(
                        titolo: 'Meccanico',
                        calcolatori: Registro.byDomain(Domain.meccanico),
                        onTap: _apri,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _mostraImpostazioni(BuildContext context, Impostazioni imp) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Scorrevole di proposito: il foglio e' alto al massimo una frazione
      // dello schermo, e con il testo di sistema ingrandito, o su un telefono
      // piccolo, il contenuto non ci sta. Meglio scorrere che sfondare.
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListenableBuilder(
          listenable: imp,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TitoloSheet('Modalità'),
                SegmentedButton<Modalita>(
                  segments: const [
                    ButtonSegment(
                      value: Modalita.professionista,
                      label: Text('Professionista'),
                    ),
                    ButtonSegment(
                      value: Modalita.studente,
                      label: Text('Studente'),
                    ),
                  ],
                  selected: {imp.modalita},
                  onSelectionChanged: (s) => imp.impostaModalita(s.first),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(T.s4, T.s2, T.s4, T.s4),
                  child: Text(
                    imp.isStudente
                        ? 'Mostra la spiegazione, gli aiuti sui campi e le avvertenze.'
                        : 'Solo campi e risultato. Niente prosa.',
                    style: TextStyle(color: context.c.muted, fontSize: 13),
                  ),
                ),
                const _TitoloSheet('Aspetto'),
                SegmentedButton<PreferenzaTema>(
                  segments: const [
                    ButtonSegment(
                      value: PreferenzaTema.scuro,
                      label: Text('Scuro'),
                    ),
                    ButtonSegment(
                      value: PreferenzaTema.chiaro,
                      label: Text('Chiaro'),
                    ),
                    ButtonSegment(
                      value: PreferenzaTema.sistema,
                      label: Text('Sistema'),
                    ),
                  ],
                  selected: {imp.tema},
                  onSelectionChanged: (s) => imp.impostaTema(s.first),
                ),
                const SizedBox(height: T.s4),
                // Il disclaimer per esteso sta in InfoPage, in un posto solo
                // (§8): qui c'e' la porta, non una seconda copia.
                ListTile(
                  leading: const Icon(Icons.info_outline, size: 20),
                  title: const Text('Informazioni e licenze'),
                  subtitle: Text(
                    'Versione, privacy, limiti d\'uso',
                    style: TextStyle(color: context.c.muted, fontSize: 12.5),
                  ),
                  onTap: () {
                    // Il navigatore va preso *prima* di chiudere il foglio:
                    // dopo il pop questo context e' disattivato e cercarci
                    // dentro un antenato non e' piu' lecito.
                    final navigatore = Navigator.of(context);
                    navigatore.pop();
                    navigatore.push(
                      MaterialPageRoute<void>(builder: (_) => const InfoPage()),
                    );
                  },
                ),
                const SizedBox(height: T.s3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitoloSheet extends StatelessWidget {
  const _TitoloSheet(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(T.s4, T.s3, T.s4, T.s2),
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

class _Sezione extends StatelessWidget {
  const _Sezione({
    required this.titolo,
    required this.calcolatori,
    required this.onTap,
  });

  final String titolo;
  final List<Calculator> calcolatori;
  final ValueChanged<Calculator> onTap;

  @override
  Widget build(BuildContext context) {
    if (calcolatori.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(T.s4, T.s4, T.s4, T.s2),
          child: Row(
            children: [
              Text(
                titolo.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: context.c.muted,
                ),
              ),
              const SizedBox(width: T.s2),
              Expanded(child: Divider(color: context.c.line)),
              const SizedBox(width: T.s2),
              Text(
                '${calcolatori.length}',
                style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: 11,
                  color: context.c.muted,
                ),
              ),
            ],
          ),
        ),
        for (final c in calcolatori) _Riga(calcolatore: c, onTap: onTap),
      ],
    );
  }
}

class _ElencoPiatto extends StatelessWidget {
  const _ElencoPiatto({
    required this.calcolatori,
    required this.onTap,
    required this.vuoto,
  });

  final List<Calculator> calcolatori;
  final ValueChanged<Calculator> onTap;
  final String vuoto;

  @override
  Widget build(BuildContext context) {
    if (calcolatori.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(T.s5),
          child: Text(
            vuoto,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.c.muted),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: calcolatori.length,
      itemBuilder: (_, i) => _Riga(calcolatore: calcolatori[i], onTap: onTap),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.calcolatore, required this.onTap});

  final Calculator calcolatore;
  final ValueChanged<Calculator> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: () => onTap(calcolatore),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    calcolatore.name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    calcolatore.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
