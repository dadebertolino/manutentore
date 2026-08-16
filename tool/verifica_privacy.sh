#!/usr/bin/env bash
#
# Deny-list dei pacchetti di tracciamento.
#
# La promessa pubblica dell'app e' "senza pubblicita', senza account, senza
# raccolta dati" (HANDOFF.md §5). Questo script la rende verificabile: fallisce
# se un SDK di analytics, ads o crash reporting entra nelle dipendenze.
#
# Gira in CI a ogni push, ma e' fatto per essere eseguito anche a mano prima di
# aggiungere una dipendenza:
#
#     ./tool/verifica_privacy.sh
#
# Controlla due cose:
#   1. i pubspec.yaml       — cosa abbiamo dichiarato noi;
#   2. i pubspec.lock       — cosa e' stato risolto davvero, dipendenze
#                             transitive comprese. E' il controllo che conta:
#                             un pacchetto approvato puo' tirarsi dietro
#                             firebase_core senza che nessuno lo scriva mai in
#                             un pubspec.yaml. I lock non sono versionati, per
#                             cui questa parte scatta solo dopo un `pub get`
#                             (in CI succede sempre).
#
# Se un pacchetto legittimo finisce nella lista per omonimia, la risposta non e'
# cancellare la riga di nascosto: e' parlarne con Davide e, se il pacchetto
# entra davvero, aggiornare sia questa lista sia HANDOFF.md §5.

set -euo pipefail

cd "$(dirname "$0")/.."

# Sottostringhe cercate nel nome del pacchetto, senza distinzione di maiuscole.
VIETATI=(
  # Analytics e product analytics
  analytics mixpanel amplitude posthog heap_ clevertap smartlook
  # Pubblicita'
  admob google_mobile_ads applovin ironsource unity_ads vungle
  # Attribuzione e marketing
  appsflyer adjust_sdk branch_io onesignal braze airship
  # Crash reporting e APM
  sentry crashlytics bugsnag datadog newrelic instabug
  # Piattaforme che portano tutto quanto sopra
  firebase facebook flurry umeng
)

# Estrae i nomi dei pacchetti da un pubspec.yaml o pubspec.lock.
#
# In entrambi i formati i nomi sono chiavi rientrate di due spazi sotto un
# blocco di primo livello. Filtrare per blocco evita di raccogliere `name:`,
# `version:` e i commenti, che altrimenti darebbero falsi positivi: in
# manutentore_app/pubspec.yaml un commento cita HANDOFF.md, e in HANDOFF.md
# questi nomi compaiono per forza di cose.
nomi_pacchetti() {
  awk '
    /^(dependencies|dev_dependencies|dependency_overrides|packages):[[:space:]]*$/ {
      dentro = 1; next
    }
    /^[^[:space:]#]/ { dentro = 0 }
    dentro && /^  [a-zA-Z_][a-zA-Z0-9_]*:/ {
      riga = $0
      sub(/^  /, "", riga)
      sub(/:.*/, "", riga)
      print tolower(riga)
    }
  ' "$1"
}

trovati=0
esaminati=0

while IFS= read -r file; do
  esaminati=$((esaminati + 1))
  while IFS= read -r pacchetto; do
    [ -z "$pacchetto" ] && continue
    for vietato in "${VIETATI[@]}"; do
      case "$pacchetto" in
        *"$vietato"*)
          echo "BLOCCATO  $file: $pacchetto (corrisponde a \"$vietato\")"
          trovati=$((trovati + 1))
          ;;
      esac
    done
  done < <(nomi_pacchetti "$file")
done < <(find . -name 'pubspec.yaml' -o -name 'pubspec.lock' \
         | grep -v '/build/' | grep -v '/.dart_tool/' | sort)

if [ "$trovati" -eq 0 ]; then
  echo "OK  nessun pacchetto di tracciamento in $esaminati file esaminati."
fi

# --- 2. Nessun permesso di sistema nel manifest che va in produzione ---
#
# HANDOFF §5: "Permessi di sistema: il minimo. Oggi l'app non ne richiede
# nessuno. Se una feature ne introduce uno, va discusso prima." Questo lo rende
# vero e non solo scritto.
#
# Su Android il permesso INTERNET va dichiarato: senza, il sistema operativo
# impedisce ogni richiesta di rete, chiunque sia a provarci — anche una
# dipendenza transitiva. E' la garanzia piu' forte che l'app abbia, e vale la
# pena non perderla per distrazione. I manifest di debug e profile lo
# dichiarano perche' serve a Flutter per l'hot reload, e non vengono spediti.
MANIFEST=manutentore_app/android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  permessi=$(grep -c "uses-permission" "$MANIFEST" || true)
  if [ "$permessi" -gt 0 ]; then
    echo
    echo "BLOCCATO  $MANIFEST dichiara dei permessi:"
    grep "uses-permission" "$MANIFEST" \
      | grep -o 'android:name="[^"]*"' \
      | sed 's/android:name=//; s/"//g; s/^/          /'
    echo "Vanno discussi prima di entrare: vedi HANDOFF.md §5."
    trovati=$((trovati + 1))
  else
    echo "OK  nessun permesso di sistema nel manifest di produzione."
  fi
fi

# --- 3. Il nostro codice non deve fare rete, nemmeno di rimbalzo ---
#
# `printing` porta `http` fra le dipendenze, ma solo per una funzione che non
# usiamo: scaricare font da Google al volo. Noi i font ce li abbiamo in
# assets/fonts/ (§4: self-hosted, mai da CDN). Su Android il permesso mancante
# basterebbe; su iOS non esiste un permesso per la rete, quindi li' l'unica
# garanzia e' che quelle chiamate non compaiano nel nostro codice.
SORGENTI="manutentore_app/lib manutentore_core/lib"
VIETATE_IN_CODICE='package:http/|PdfGoogleFonts|downloadFont|PdfBaseCache'
if colpite=$(grep -rnE "$VIETATE_IN_CODICE" $SORGENTI 2>/dev/null); then
  echo
  echo "BLOCCATO  il codice usa API che fanno rete:"
  echo "$colpite" | sed 's/^/          /'
  echo "I font del PDF si caricano da assets/fonts/: vedi HANDOFF.md §5."
  trovati=$((trovati + 1))
else
  echo "OK  nessuna chiamata di rete nel codice dei due package."
fi

if [ "$trovati" -gt 0 ]; then
  echo
  echo "$trovati problema/i. La promessa privacy dell'app e' pubblica."
  exit 1
fi
