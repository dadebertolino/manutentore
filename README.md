# Breviario del manutentore

[![CI](https://github.com/dadebertolino/manutentore/actions/workflows/ci.yml/badge.svg)](https://github.com/dadebertolino/manutentore/actions/workflows/ci.yml)

Calcolatori per diagnostica e riparazione, elettrici e meccanici, per studenti
di manutenzione e assistenza tecnica e per professionisti in campo.
Offline, senza account, senza raccolta dati.

```
manutentore/
├── manutentore_core/   Motore di calcolo — Dart puro, zero dipendenze
└── manutentore_app/    App Flutter (iOS + Android)
```

Le due cartelle devono restare **sorelle**: l'app referenzia il core con
`path: ../manutentore_core`.

## Primi passi

Le cartelle native ci sono già (`it.davidebertolino.manutentore`) e sono
versionate: non serve nessuno scaffold.

```bash
# Prima il core: si testa in due secondi, senza emulatore
cd manutentore_core && dart pub get && dart analyze && dart test

# Poi l'app
cd ../manutentore_app && flutter pub get && flutter analyze && flutter test
flutter run
```

Su macOS, la prima volta: `cd manutentore_app/ios && pod install`.

Stato al 2026-08-16: `analyze` pulito su entrambi i package, 36 test verdi nel
core e 5 nell'app.

## Attenzione

I valori attesi nei test del core sono stati calcolati e verificati
indipendentemente prima di essere scritti nei test, non estratti dal codice.
Se un test del core fallisce, **il sospettato numero uno è il test, non la
formula**: ricontrolla il valore atteso a mano prima di toccare il calcolo.

I font IBM Plex non sono ancora nel repo. Manca in silenzio: l'app ripiega sul
font di sistema senza segnalare nulla, e le cifre smettono di essere tabulari.
Vedi `HANDOFF.md` §4.

## Privacy

Nessuna pubblicità, nessun account, nessuna raccolta dati, nessuna richiesta di
rete. Non è una dichiarazione d'intenti: `tool/verifica_privacy.sh` fa fallire
la build se un SDK di analytics, ads o crash reporting entra fra le dipendenze,
**anche in modo transitivo**, e gira in CI a ogni push. Puoi lanciarlo a mano:

```bash
./tool/verifica_privacy.sh
```

Il motore di calcolo (`manutentore_core`) non ha dipendenze a runtime, ed è la
CI a verificarlo: un package senza dipendenze non può contrabbandare un SDK di
tracciamento.

## Documentazione

- `manutentore_app/HANDOFF.md` — architettura, direzione di design, vincoli
  privacy non negoziabili, backlog in ordine. **Leggerlo prima di scrivere
  codice.**
- `manutentore_core/README.md` — elenco dei 17 calcolatori e come aggiungerne.
