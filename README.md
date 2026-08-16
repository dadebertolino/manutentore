# Breviario del manutentore

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

Il progetto Flutter non contiene ancora le cartelle native: vanno generate.

```bash
# 1. Scaffold nativo in una cartella temporanea
flutter create --org it.davidebertolino --platforms=android,ios \
  --project-name manutentore _scaffold

# 2. Travasa solo le parti native
mv _scaffold/android manutentore_app/
mv _scaffold/ios     manutentore_app/
rm -rf _scaffold

# 3. Prima il core: si testa in due secondi, senza emulatore
cd manutentore_core && dart pub get && dart analyze && dart test

# 4. Poi l'app
cd ../manutentore_app && flutter pub get && flutter analyze && flutter test
flutter run
```

Su macOS, la prima volta: `cd manutentore_app/ios && pod install`.

## Attenzione

**Nulla è mai stato compilato.** I valori attesi nei test del core sono stati
calcolati e verificati indipendentemente prima di essere scritti, quindi la
matematica è affidabile; il codice non ha mai visto un compilatore. Aspettati
errori di sintassi e API Flutter cambiate di versione.

Se un test del core fallisce, **il sospettato numero uno è il test, non la
formula**: ricontrolla il valore atteso a mano prima di toccare il calcolo.

## Documentazione

- `manutentore_app/HANDOFF.md` — architettura, direzione di design, vincoli
  privacy non negoziabili, backlog in ordine. **Leggerlo prima di scrivere
  codice.**
- `manutentore_core/README.md` — elenco dei 17 calcolatori e come aggiungerne.
