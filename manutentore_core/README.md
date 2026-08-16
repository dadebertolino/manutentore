# manutentore_core

Motore di calcolo del "breviario del manutentore". Dart puro, **zero
dipendenze a runtime**, nessun accesso di rete, nessuno stato persistente.
Tutta la logica di dominio vive qui: la app Flutter (iOS/Android) è solo
presentazione.

## Perché un package separato

- I calcoli si testano senza far girare un emulatore.
- La UI non conosce le formule: legge `Calculator.fields`, costruisce il form,
  mostra `CalcResult`. **Una sola schermata** renderizza tutti i calcolatori.
- Aggiungere un calcolatore costa un file e una riga nel registro. La UI non si
  tocca mai.
- Il deny-list in CI sul `pubspec.yaml` resta banale da mantenere: qui non
  entra nulla.

## Uso

```dart
import 'package:manutentore_core/manutentore_core.dart';

final calc = Registro.byId('el.caduta_tensione');
final r = calc.run({
  'sistema': 'tri', 'un': 400.0, 'ib': 32.0, 'lung': 45.0,
  'sez': 10.0, 'mat': 'Cu', 'cosphi': 0.9, 'temp': 70.0,
  'reatt': 0.08, 'limite': 4.0,
});

print(r.verdict);                 // Entro il limite del 4,0%
print(r.numeric('Caduta percentuale')); // 1.18
```

Ricerca e navigazione:

```dart
Registro.byDomain(Domain.elettrico);   // elenco per sezione
Registro.cerca('bpfo');                // tollerante ad accenti e sinonimi
Registro.verificaIntegrita();          // deve restituire [] (usato dai test)
```

## Calcolatori disponibili (17)

**Elettrico**

| id | Cosa fa |
|---|---|
| `el.caduta_tensione` | ΔV in V e %, sezione minima per rientrare nel limite |
| `el.portata_cavo` | Iz0 da tabella IEC 60364-5-52 con k1 termico e k2 di fascio |
| `el.coordinamento` | Ib ≤ In ≤ Iz, If ≤ 1,45 Iz, verifica adiabatica I²t ≤ K²S² |
| `el.anello_guasto` | Zs ammessa vs misurata, corrente di guasto presunta |
| `el.rifasamento` | kvar necessari, riduzione di corrente, µF per fase |
| `el.motore_asincrono` | Corrente, coppia, scorrimento, spunto diretto e Y/Δ |
| `el.segnale_analogico` | Scaling 4-20 mA / 0-10 V nei due versi, conteggi ADC |
| `el.pt100` | Callendar-Van Dusen, PT100/PT1000, errore da linea a 2 fili |

**Meccanico**

| id | Cosa fa |
|---|---|
| `me.coppia_serraggio` | Coppia e precarico ISO 898-1, effetto della lubrificazione |
| `me.foro_maschiatura` | Punta consigliata, % di filetto, dati ISO 261 |
| `me.vita_cuscinetto` | L10, L10h, Lnmh con fattori a1 e a_ISO |
| `me.frequenze_cuscinetto` | BPFO, BPFI, BSF, FTF + ordini rispetto a 1x |
| `me.vibrazioni_iso` | Zona A-D secondo ISO 10816-3 |
| `me.cilindro_pneumatico` | Forza spinta/tiro, consumo Nl/ciclo e Nl/min |
| `me.valvola_kv` | Kv, Cv, portata, perdita di carico (tre versi) |
| `me.trasmissione_pulegge` | Rapporto, velocità periferica, lunghezza cinghia, avvolgimento |
| `me.potenza_coppia` | Conversione P ↔ C ↔ n |

## Aggiungere un calcolatore

1. Implementa `Calculator` in `lib/src/electrical.dart` o `mechanical.dart`
   (o un nuovo file di dominio).
2. Registralo in `Registro.tutti`.
3. Aggiungi un test con un valore di riferimento verificato a mano.

Regole:

- `id` **immutabile**: è la chiave di preferiti, cronologia e deep link.
- Ogni campo numerico ha `min`, `max` e un `value` di default sensato: la
  verifica di integrità fallisce altrimenti.
- Errori d'uso → `CalcException` con messaggio in italiano rivolto all'utente,
  mai un'eccezione grezza.
- `references` sempre compilato: in campo la norma citata è ciò che rende il
  numero difendibile.
- `theory` solo dove serve: è il testo che la modalità studente mostra e la
  modalità professionista nasconde.

## Test

```bash
dart pub get
dart test
```

I valori attesi sono stati verificati indipendentemente prima di scriverli
(non estratti dal codice stesso). I test coprono: valori di riferimento,
invertibilità delle conversioni, invarianti fisiche (BPFO + BPFI = n·fr;
dimezzare il carico su un cuscinetto a sfere moltiplica la vita per 8),
gestione degli errori e integrità del registro.

## Attenzione

Le tabelle sono un sottoinsieme delle taglie più ricorrenti, pensato per dare
un ordine di grandezza verificabile in campo. Non sostituiscono la
consultazione della norma né il progetto firmato da un tecnico abilitato.
Questo va detto anche nella app, una volta, non a ogni schermata.

## Privacy

Nessun account, nessuna rete, nessuna raccolta dati. Il package non ha
dipendenze: non c'è modo che ne entri una di tracciamento.
