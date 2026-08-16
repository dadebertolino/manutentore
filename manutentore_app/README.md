# Breviario del manutentore — app

App Flutter (iOS + Android) di calcolo per manutentori elettrici e meccanici.
Offline, senza account, senza raccolta dati.

Il motore di calcolo vive in `../manutentore_core` (Dart puro, testabile senza
emulatore). Questa cartella è solo presentazione.

```bash
flutter pub get
flutter test
flutter run
```

Le cartelle native ci sono già (`it.davidebertolino.manutentore`). Su macOS,
la prima volta: `cd ios && pod install`. Stato al 2026-08-16: `flutter analyze`
pulito, 5 test verdi.

**Prima di lavorarci: leggi `HANDOFF.md`.** Contiene architettura, direzione di
design, vincoli privacy non negoziabili e backlog in ordine di priorità.
