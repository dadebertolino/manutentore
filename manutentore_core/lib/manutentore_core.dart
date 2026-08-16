/// Motore di calcolo del breviario del manutentore.
///
/// Package Dart puro: nessuna dipendenza esterna, nessun accesso di rete,
/// nessuno stato persistente. Tutto il dominio vive qui; la UI Flutter
/// consuma [Registro] e [Calculator] senza conoscere le formule.
library;

export 'src/model.dart';
export 'src/registry.dart';
export 'src/tables.dart';
export 'src/electrical.dart';
export 'src/mechanical.dart';
