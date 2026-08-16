import 'package:flutter/material.dart';
import 'package:manutentore_core/manutentore_core.dart';

import '../state/cronologia.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'calcolatore_page.dart';

/// Gli ultimi calcoli, dal piu' recente.
///
/// Toccare una voce riapre il calcolatore **con quegli input**: e' il motivo
/// per cui la cronologia esiste, non la rilettura del risultato.
class CronologiaPage extends StatelessWidget {
  const CronologiaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cronologia = CronologiaScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronologia'),
        actions: [
          ListenableBuilder(
            listenable: cronologia,
            builder: (context, _) => IconButton(
              tooltip: 'Svuota la cronologia',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: cronologia.isEmpty
                  ? null
                  : () => _confermaSvuota(context, cronologia),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: cronologia,
        builder: (context, _) {
          final voci = cronologia.voci;
          if (voci.isEmpty) return const _Vuota();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: T.s6),
            itemCount: voci.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) =>
                _Voce(voce: voci[i], cronologia: cronologia),
          );
        },
      ),
    );
  }

  Future<void> _confermaSvuota(BuildContext context, Cronologia c) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Svuotare la cronologia?'),
        content: const Text(
          'Le voci salvate su questo telefono vengono cancellate. '
          'Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Svuota'),
          ),
        ],
      ),
    );
    if (conferma ?? false) c.svuota();
  }
}

class _Voce extends StatelessWidget {
  const _Voce({required this.voce, required this.cronologia});

  final VoceCronologia voce;
  final Cronologia cronologia;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Il calcolatore potrebbe non esistere piu': gli id sono immutabili per
    // contratto, ma una voce vecchia di due versioni non deve far crashare la
    // lista.
    final calc = Registro.tutti.where((x) => x.id == voce.calcId).firstOrNull;
    if (calc == null) {
      return ListTile(
        title: Text(
          'Calcolatore non più disponibile',
          style: TextStyle(color: c.muted),
        ),
        subtitle: Text(
          voce.calcId,
          style: TextStyle(fontFamily: T.mono, fontSize: 12, color: c.muted),
        ),
        trailing: IconButton(
          tooltip: 'Rimuovi',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => cronologia.rimuovi(voce),
        ),
      );
    }

    return ListTile(
      title: Text(calc.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (voce.sintesi != null)
            Text(
              voce.sintesi!,
              style: TextStyle(
                fontFamily: T.mono,
                fontSize: 12.5,
                color: c.muted,
              ),
            ),
          Text(
            _quando(voce.quando),
            style: TextStyle(fontSize: 11.5, color: c.muted),
          ),
        ],
      ),
      isThreeLine: voce.sintesi != null,
      trailing: IconButton(
        tooltip: 'Rimuovi dalla cronologia',
        icon: const Icon(Icons.close, size: 18),
        onPressed: () => cronologia.rimuovi(voce),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              CalcolatorePage(calcolatore: calc, valoriIniziali: voce.valori),
        ),
      ),
    );
  }

  /// Data relativa finche' e' utile, poi assoluta. In campo "3 ore fa" dice
  /// piu' di un timestamp; dopo qualche giorno vale il contrario.
  static String _quando(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'adesso';
    if (d.inMinutes < 60) return '${d.inMinutes} min fa';
    if (d.inHours < 24) return '${d.inHours} h fa';
    if (d.inDays < 7) return '${d.inDays} g fa';
    final gg = t.day.toString().padLeft(2, '0');
    final mm = t.month.toString().padLeft(2, '0');
    return '$gg/$mm/${t.year}';
  }
}

class _Vuota extends StatelessWidget {
  const _Vuota();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(T.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 40, color: c.muted),
            const SizedBox(height: T.s3),
            Text(
              'Nessun calcolo ancora.',
              style: TextStyle(color: c.muted, fontSize: 14),
            ),
            const SizedBox(height: T.s2),
            Text(
              'I calcoli fatti restano qui, su questo telefono, '
              'con gli input da cui ripartire.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
