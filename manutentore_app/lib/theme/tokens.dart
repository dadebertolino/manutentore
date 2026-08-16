import 'package:flutter/material.dart';

/// Token di design.
///
/// Regola cromatica: **il colore semantico appartiene alla macchina, il giallo
/// appartiene all'utente.** Verde/arancio/rosso dicono cosa sta succedendo
/// all'impianto e non vanno mai usati per decorare. Il giallo sicurezza marca
/// solo cio' che l'utente ha toccato o selezionato.
class T {
  T._();

  // --- Scuro (default: si lavora in cabina, in quadro, in officina) ---
  static const groundDark = Color(0xFF171A1D);
  static const surfaceDark = Color(0xFF1F2429);
  static const plateDark = Color(0xFF262C32); // la "targa"
  static const lineDark = Color(0xFF3A434B);
  static const textDark = Color(0xFFE9EDF0);
  static const mutedDark = Color(0xFF919CA6);

  // --- Chiaro (sole, tetto, esterni) ---
  static const groundLight = Color(0xFFF2F3F4);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const plateLight = Color(0xFFE9ECEE);
  static const lineLight = Color(0xFFC6CDD3);
  static const textLight = Color(0xFF1A1E22);
  static const mutedLight = Color(0xFF5C666F);

  /// Interazione: selezione, focus, preferiti. Mai un risultato.
  static const giallo = Color(0xFFF2C230);

  /// Semantica del verdetto. Non riusare altrove.
  static const ok = Color(0xFF3DA35D);
  static const warn = Color(0xFFE07B2A);
  static const fail = Color(0xFFD6453D);

  static const sans = 'IBMPlexSans';

  /// Usato per ogni cifra: le figure tabulari non ballano mentre si digita.
  static const mono = 'IBMPlexMono';

  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;

  static const radius = 6.0; // targa incisa, non pillola
}
