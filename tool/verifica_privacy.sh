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

if [ "$trovati" -gt 0 ]; then
  echo
  echo "$trovati dipendenza/e di tracciamento in $esaminati file esaminati."
  echo "La promessa privacy dell'app e' pubblica: vedi HANDOFF.md §5."
  exit 1
fi

echo "OK  nessun pacchetto di tracciamento in $esaminati file esaminati."
