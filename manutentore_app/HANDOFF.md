# HANDOFF — Breviario del manutentore

Documento di passaggio per Claude Code. Leggilo prima di scrivere codice.
Se qualcosa qui contraddice ciò che trovi nel repo, **vince il repo** e questo
documento va corretto nello stesso commit.

---

## 1. Cos'è

App mobile (iOS + Android) di calcolo per manutentori elettrici e meccanici:
studenti di indirizzo manutenzione e assistenza tecnica, e professionisti in
campo. Un "breviario" — si apre, si tira fuori un numero difendibile, si
chiude.

Il valore non è l'elenco delle formule (quello è un PDF). È: **calcolatori
interattivi + verdetto esplicito + funziona offline in una cabina senza
segnale**.

Autore: Davide Bertolino. Docente di elettronica e automazione, IIS
Cigna-Baruffi-Garelli (Mondovì, CN). L'app nasce dal suo insegnamento, quindi
la modalità studente non è un contentino: è metà del prodotto.

---

## 2. Stato attuale

```
manutentore/
├── manutentore_core/      Motore di calcolo — Dart puro, COMPLETO
│   ├── lib/src/model.dart       Calculator, FieldSpec, Inputs, CalcResult
│   ├── lib/src/tables.dart      Tabelle normative (portate, passi, ISO 10816…)
│   ├── lib/src/electrical.dart  8 calcolatori
│   ├── lib/src/mechanical.dart  9 calcolatori
│   ├── lib/src/registry.dart    Registro + ricerca + verifica integrità
│   └── test/                    36 test con valori di riferimento verificati
└── manutentore_app/       App Flutter — SCHELETRO FUNZIONANTE
    ├── lib/theme/         Token e temi chiaro/scuro
    ├── lib/state/         impostazioni.dart: modalità, tema, preferiti
    │                      cronologia.dart:  ultimi 50 calcoli + input
    ├── lib/ui/            Home, calcolo generico, cronologia, widget
    ├── assets/fonts/      IBM Plex Sans e Mono (OFL), 5 pesi
    ├── android/ ios/      Scaffold nativo, it.davidebertolino.manutentore
    └── test/              12 test: UI di superficie + cronologia
```

I due package sono **cartelle sorelle**. `manutentore_app/pubspec.yaml`
referenzia il core con `path: ../manutentore_core`. Non spostarli senza
aggiornare quel path.

### Build verde

Il core e l'app sono stati scritti in un ambiente senza Dart né Flutter, e fino
al 2026-08-16 questo documento avvisava che nulla era mai stato compilato. Non
è più così: il primo commit (`c29b763`) porta entrambi i package a build verde.
Stato verificato il 2026-08-16:

| package | `analyze` | test |
|---|---|---|
| `manutentore_core` | pulito | 36 passati |
| `manutentore_app`  | pulito | 12 passati |

```bash
cd manutentore_core && dart pub get && dart analyze && dart test
cd ../manutentore_app && flutter pub get && flutter analyze && flutter test
flutter run
```

Su una macchina nuova, la prima volta: `cd manutentore_app/ios && pod install`.

Se un test del core fallisce, la regola resta: **il sospettato numero uno è il
test, non la formula.** I valori attesi sono stati calcolati e verificati
indipendentemente (in Python) *prima* di essere scritti, quindi ricontrolla il
valore atteso a mano prima di toccare il calcolo. Se una formula è davvero
sbagliata, correggila e annota qui cosa e perché.

Se aggiorni la versione di Flutter, le API che qui hanno già dato problemi e
che vale la pena ricontrollare per prime sono: `DropdownButtonFormField.value`
vs `.initialValue`, `withAlpha` vs `withValues`, `SegmentedButton`,
`ListenableBuilder`, `showDragHandle`.

---

## 3. Architettura e perché è così

### I calcolatori si auto-descrivono

`Calculator` espone `fields` (le `FieldSpec`) e `compute(Inputs) → CalcResult`.
La UI non conosce nessuna formula: legge le specifiche, costruisce il form,
mostra il risultato.

**Conseguenza operativa: `CalcolatorePage` è l'unica schermata di calcolo che
esisterà mai.** Aggiungere un calcolatore = un file nel core + una riga nel
registro. Se ti ritrovi a scrivere una schermata dedicata a un calcolatore
specifico, ti sei perso: il caso particolare va espresso nel modello dati
(un nuovo `FieldType`, un flag su `ResultLine`), non in una schermata a parte.

### Il core non dipende da Flutter

Si testa in millisecondi senza emulatore. Ed è l'unico modo per tenere onesta
la promessa privacy: un package senza dipendenze non può contrabbandare un SDK
di tracciamento.

### Niente state management di terze parti

`ChangeNotifier` + `InheritedNotifier` bastano per modalità, tema, preferiti e
cronologia. Ogni pacchetto in più è un pacchetto da giustificare (vedi §5).

### Cronologia

`Cronologia` (in `state/cronologia.dart`) tiene gli ultimi 50 calcoli con gli
input che li hanno prodotti, in prefs come JSON. Tre scelte da conoscere prima
di toccarla:

- **Si registra all'uscita dalla schermata, non a ogni battuta.** Si ricalcola
  a ogni carattere digitato: salvare ogni passaggio riempirebbe le 50 posizioni
  con gli stati intermedi di un numero solo. Aprire un calcolatore e uscirne
  senza toccare niente non registra nulla.
- **Stesso calcolo con stessi input non occupa due posizioni**: risale in cima.
  È una lista di *cose da cui ripartire*, non un registro cronologico.
- **Serve a ripristinare gli input**, non a rileggere il risultato:
  `CalcolatorePage` accetta `valoriIniziali`. Le chiavi che il calcolatore non
  conosce più vengono ignorate, così una voce vecchia non trascina campi
  orfani.

### Modalità studente / professionista

Stesso motore, due letture. Studente: `theory`, `help` sui campi, `warnings`.
Professionista: campi e risultato, niente prosa. Non sono due codebase: è
l'enum `Modalita` in `state/impostazioni.dart`, globale e persistito nelle
prefs, che si commuta dal foglio impostazioni. Le schermate lo leggono con
`ImpostazioniScope.of(context).isStudente`. Il default è `professionista`.

---

## 4. Design — è già deciso, seguilo

**Tesi**: non è una app di calcolo, è uno strumento da campo. Il riferimento
non sono le calcolatrici, è la **targa dati** che sta su ogni motore e ogni
cuscinetto: l'artefatto che il manutentore già sa leggere.

- **Regola cromatica**: il colore semantico appartiene alla macchina, il giallo
  appartiene all'utente. Verde/arancio/rosso dicono solo cosa succede
  all'impianto — mai decorazione. Il giallo sicurezza (`T.giallo`) marca solo
  ciò che l'utente ha toccato: focus, selezione, preferiti. **Non usare mai il
  giallo per un valore di risultato**, e non usare mai verde/rosso per un
  bordo o un'icona senza significato diagnostico.
- **Tipografia**: superfamiglia IBM Plex. Sans per il testo, **Mono per ogni
  cifra**. Il Mono non è una scelta estetica: le figure tabulari impediscono ai
  numeri di ballare mentre l'utente digita.
- **Elemento firma**: `TargaRisultato`. Valori primari incisi grandi, banda di
  verdetto stampigliata in testa, riferimenti normativi punzonati in fondo in
  Mono 10.5. Se un giorno la app deve essere riconoscibile da uno screenshot,
  è questo.
- **Default scuro**: si lavora in cabina e in quadro. Il tema chiaro serve per
  il sole, non è il caso principale.
- **Raggio 6 px**, non pillole. È una targa, non un bottone di un social.

### Font — fatti
**IBM Plex Sans** e **IBM Plex Mono** sono in `assets/fonts/`, self-hosted e
mai da CDN (§5), con la licenza OFL accanto in `OFL.txt`. Scaricati dalle
release ufficiali IBM/plex (`@ibm/plex-sans@1.1.0`, `@ibm/plex-mono@2.5.0`).

Ci sono **solo i cinque pesi che la UI usa davvero** — Sans 400/500/600, Mono
400/500, nessun corsivo — per circa 950 kB. Non è avarizia: è peso che il
manutentore si scarica, e i pesi non usati non li vede nessuno. Se ti serve un
peso nuovo, aggiungi il `.ttf` *e* la riga in `pubspec.yaml`.

Il ripiego sul font di sistema **non è più silenzioso**: ora che gli asset sono
dichiarati nel `pubspec.yaml`, se un file sparisce `flutter build` si ferma con
*"unable to locate asset entry"*. Verificato togliendo un file apposta. Vale
solo per i cinque dichiarati: se aggiungi un peso al codice senza aggiungerlo
al pubspec, torni al ripiego muto.

---

## 5. Vincoli non negoziabili

L'app rientra nello standard privacy delle app educational di Davide. La
promessa pubblica è: **senza pubblicità, senza account, senza raccolta dati**,
e deve restare vera *e verificabile*.

- **Zero SDK di analytics, ads, crash reporting.** Niente Firebase, AdMob,
  Sentry. Nemmeno "solo per il debug".
- **Zero rete.** L'app non fa richieste HTTP. Se una feature sembra richiederne
  una, ripensala offline-first e chiedi prima di implementare.
- **Zero account, zero backend.**
- **Font self-hosted**, mai Google Fonts da CDN.
- **Permessi di sistema: il minimo**, chiesti al momento dell'uso. Oggi l'app
  non ne richiede nessuno. Se una feature ne introduce uno, va discusso prima.
- **Nuove dipendenze**: prima di aggiungere qualsiasi cosa a `pubspec.yaml`,
  chiedi. Oggi l'unica è `shared_preferences`.
- **Store**: categoria Education o Utilities, mai Medical. Play target audience
  18+. Data safety: nessun dato raccolto.

Questi vincoli non sono affidati alla buona memoria: `tool/verifica_privacy.sh`
**fa fallire la build** se un pacchetto di tracciamento entra fra le
dipendenze. Gira in CI a ogni push ed è pensato per essere lanciato anche a
mano prima di aggiungere qualcosa:

```bash
./tool/verifica_privacy.sh
```

Controlla i `pubspec.yaml` (cosa abbiamo dichiarato) **e i `pubspec.lock`**
(cosa è stato risolto davvero): è quest'ultimo che conta, perché un pacchetto
approvato può tirarsi dietro `firebase_core` senza che nessuno lo scriva mai in
un pubspec. La lista dei nomi vietati sta in cima allo script — se la allarghi,
allarga anche questo elenco. Un secondo controllo in CI verifica che
`manutentore_core` resti **senza dipendenze a runtime**.

Se un pacchetto legittimo finisce nella lista per omonimia, la risposta non è
cancellare la riga di nascosto: è discuterne e, se il pacchetto entra davvero,
aggiornare sia lo script sia questa sezione.

---

## 6. Convenzioni di codice

- **Lingua**: identificatori, commenti, stringhe UI e messaggi d'errore in
  italiano. Le sigle tecniche restano in originale (`Iz`, `BPFO`, `Kv`, `L10h`).
  Nei file del core evita accenti nei commenti e usa l'apostrofo per le vocali
  accentate nelle stringhe (`velocita\'`), come già fatto.
- **`Calculator.id` è immutabile**: è la chiave di preferiti, cronologia e
  futuri deep link. Rinominarlo rompe i dati degli utenti.
- **Errori d'uso → `CalcException`** con messaggio rivolto all'utente, in
  italiano, che dice cosa fare: *"Sezione 11 mm2 non presente. Sezioni
  disponibili: 1.5, 2.5, 4…"*. Mai un'eccezione grezza in faccia all'utente.
- **Ogni campo numerico** ha `min`, `max` e un `value` di default sensato:
  `Registro.verificaIntegrita()` fallisce altrimenti, ed è coperto da test.
- **`references` sempre compilato.** In campo la norma citata è ciò che rende
  il numero difendibile davanti a un cliente o a un collega.
- **`theory` solo dove aggiunge**: è il testo della modalità studente. Deve
  spiegare *perché*, non ripetere la formula.
- **Ogni nuovo calcolatore porta almeno un test** con un valore di riferimento
  verificato a mano, e dove possibile un'**invariante** (es. BPFO + BPFI = n·fr;
  dimezzare il carico su un cuscinetto a sfere moltiplica la vita per 8). Le
  invarianti reggono anche quando i numeri cambiano.

---

## 7. Backlog, in ordine

### Rendere usabile in campo
1. **Persistenza degli input per calcolatore**: riaprendo un calcolatore
   ritrova gli ultimi valori usati. In campo si rifà lo stesso calcolo con una
   variabile diversa.
2. **Rapportino PDF**: compili in campo, esci con un PDF condivisibile via
   share sheet (mai upload). È la funzione che fa scaricare l'app a chi lavora
   davvero. Valuta `pdf` + `printing` — sono da approvare come dipendenze.
3. **Accessibilità e uso con i guanti**: target da 48 dp, contrasto verificato,
   supporto al text scaling fino a 200% senza overflow nella `TargaRisultato`.

### Crescere in contenuto
4. **Altri calcolatori**: sezione da corrente di corto, resistenza di
   isolamento, termocoppie K/J, ISO VG e compatibilità grassi, allineamento
   alberi, tolleranze ISO H7/g6, perdite di carico nelle tubazioni, MTBF/MTTR
   e OEE.
5. **Tabelle di consultazione** (non calcolatori): simbologia CEI/IEC e
   ISO 1219, codici colore, classi IP/IK, coppie di serraggio a colpo d'occhio.
   Serve un nuovo tipo di scheda nel registro — progettalo, non forzarlo dentro
   `Calculator`.
6. **Alberi diagnostici guidati** — *"il motore non parte"*, *"il quadro scatta
   all'avviamento"*, *"cuscinetto rumoroso"*: sequenze di verifiche dove
   l'esito determina il passo successivo. È la parte con più valore didattico
   e la meno banale da modellare: **serve un modello dati nuovo** (nodo,
   esito, ramo, esito terminale), non un `Calculator`. Progettalo insieme a
   Davide prima di implementare.

### Pubblicare
7. Icona, splash, screenshot **senza dati reali**, testi store con
   inquadramento adulto, privacy policy su davidebertolino.it, README con
   sezione privacy.

---

## 8. Trappole già note

- **Le tabelle sono un sottoinsieme.** `kPortateCu` copre 1,5–120 mm² per le
  pose più comuni; `kPassoGrosso` arriva a M48. Se un utente esce dalla
  tabella deve ricevere un errore chiaro con le taglie disponibili, **mai un
  numero interpolato di nascosto**. La funzione `interpola()` è pensata per i
  coefficienti continui (temperatura, raggruppamento), non per le portate.
- **La classe 8.8 cambia Rp0.2 sopra M16** (640 → 660 MPa). È gestito in
  `CoppiaSerraggio`; se aggiungi calcoli sui bulloni, ricordatelo.
- **`If = 1,45·In` vale per i magnetotermici, non per i fusibili gG**
  (≈1,6·In). Oggi è un avviso testuale: se aggiungi il tipo di protezione come
  campo, aggiorna il calcolo, non solo l'avviso.
- **La verifica adiabatica I²t** assume tempo di intervento noto e costante.
  Non è la curva reale dell'interruttore. Non promettere selettività.
- **I campi numerici emettono `String`, non `num`.** `CampoInput` passa il
  testo grezzo, e `Inputs.num_` lo sa leggere — per cui i calcoli funzionano e
  la cosa non si nota. Si nota quando quei valori vanno *altrove*:
  `_formatoIniziale` mostra solo i `num`, quindi la cronologia normalizza a
  numero prima di salvare, altrimenti al ripristino i campi tornerebbero vuoti.
  Se aggiungi una feature che rilegge `_valori`, ricordatene.
- **Non chiamare `notifyListeners()` dentro `dispose()`.** L'albero è bloccato
  durante lo smontaggio e Flutter lancia *"markNeedsBuild called when widget
  tree was locked"*. La cronologia registra proprio lì, quindi rimanda la
  notifica con `scheduleMicrotask`: lo stato cambia subito, la notifica aspetta
  la fine dello smontaggio.
- **Disclaimer**: la app dà un ordine di grandezza verificabile, non sostituisce
  la norma né il progetto firmato da un tecnico abilitato. Va detto **una
  volta**, in impostazioni (già presente) — non a ogni schermata, o smette di
  essere letto.

---

## 9. Come lavorare su questo repo

- Commit piccoli e in italiano, uno per intento.
- Test verdi prima di ogni commit: `dart test` nel core, `flutter test` nell'app.
- Toccare una formula significa toccare anche il test e i `references`.
- Se aggiungi una dipendenza, aggiornala anche in §5 di questo documento.
- Quando questo handoff diventa falso, correggilo. Un documento di passaggio
  scaduto è peggio di nessun documento.
