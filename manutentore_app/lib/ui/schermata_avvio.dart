import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../versione.dart';
import 'home_page.dart';

/// Nome, versione e autore, per un attimo, all'apertura.
///
/// Sta poco di proposito: la tesi della app e' "si apre, si tira fuori un
/// numero, si chiude", e uno schermo che si mette in mezzo a ogni avvio la
/// contraddice. Per lo stesso motivo **un tocco la salta**: chi e' sotto un
/// quadro aperto non aspetta.
///
/// Il logo e' disegnato, non un PNG: e' la stessa geometria di
/// `design/icona.svg`, cosi' icona e avvio non possono divergere.
class SchermataAvvio extends StatefulWidget {
  const SchermataAvvio({super.key});

  /// Quanto resta visibile se nessuno la tocca.
  static const durata = Duration(milliseconds: 1400);

  @override
  State<SchermataAvvio> createState() => _SchermataAvvioState();
}

class _SchermataAvvioState extends State<SchermataAvvio> {
  bool _finita = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SchermataAvvio.durata, _prosegui);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _prosegui() {
    _timer?.cancel();
    if (mounted && !_finita) setState(() => _finita = true);
  }

  @override
  Widget build(BuildContext context) {
    // Niente `Navigator.push`: si sostituisce il contenuto, cosi' il tasto
    // indietro non riporta mai al logo.
    if (_finita) return const HomePage();

    final c = context.c;
    return GestureDetector(
      onTap: _prosegui,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Marchio(lato: 96),
              const SizedBox(height: T.s5),
              Text(
                'Breviario',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: T.s1),
              Text(
                'del manutentore',
                style: TextStyle(fontSize: 14, color: c.muted),
              ),
              const SizedBox(height: T.s5),
              Text(
                'Versione $versioneApp ($buildApp)',
                style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: 11.5,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: T.s1),
              Text(
                'Davide Bertolino',
                style: TextStyle(fontSize: 12.5, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Esagono giallo con l'omega ritagliata: l'icona della app, disegnata.
class _Marchio extends StatelessWidget {
  const _Marchio({required this.lato});

  final double lato;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: lato,
    height: lato,
    child: CustomPaint(
      painter: const _Esagono(colore: T.giallo),
      child: Center(
        child: Text(
          'Ω',
          style: TextStyle(
            fontFamily: T.mono,
            fontWeight: FontWeight.w500,
            fontSize: lato * 0.42,
            // Il colore del fondo, non un colore nuovo: l'omega e' un buco
            // nell'esagono, come nell'icona.
            color: Theme.of(context).scaffoldBackgroundColor,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class _Esagono extends CustomPainter {
  const _Esagono({required this.colore});

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    // Stesse proporzioni di design/icona.svg: vertici in alto e in basso,
    // larghezza il 66,7% dell'altezza dei lati verticali.
    final l = size.width;
    final percorso = Path()
      ..moveTo(l * 0.5, 0)
      ..lineTo(l, l * 0.25)
      ..lineTo(l, l * 0.75)
      ..lineTo(l * 0.5, l)
      ..lineTo(0, l * 0.75)
      ..lineTo(0, l * 0.25)
      ..close();
    canvas.drawPath(percorso, Paint()..color = colore);
  }

  @override
  bool shouldRepaint(_Esagono vecchio) => vecchio.colore != colore;
}
