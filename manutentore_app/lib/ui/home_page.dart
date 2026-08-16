import 'package:flutter/material.dart';
import 'package:manutentore_core/manutentore_core.dart';

import '../state/impostazioni.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'calcolatore_page.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CalcolatorePage(calcolatore: c)),
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
      builder: (_) => SafeArea(
        child: ListenableBuilder(
          listenable: imp,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TitoloSheet('Modalita\''),
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
              const SizedBox(height: T.s5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: T.s4),
                child: Text(
                  'Nessun account, nessuna rete, nessuna raccolta dati. '
                  'I calcoli danno un ordine di grandezza verificabile: non '
                  'sostituiscono la norma ne\' il progetto firmato.',
                  style: TextStyle(
                    color: context.c.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: T.s5),
            ],
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
