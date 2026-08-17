/// Versione mostrata nella pagina informazioni.
///
/// E' scritta a mano perche' leggerla a runtime richiederebbe un plugin, e una
/// dipendenza in piu' va giustificata (HANDOFF §5). Il rischio di scordarsi di
/// aggiornarla e' coperto da un test che la confronta con `pubspec.yaml`: se
/// le due divergono, la build diventa rossa.
const versioneApp = '0.1.0';

/// Numero di build, la parte dopo il `+` in `pubspec.yaml`.
const buildApp = 1;
